//! `meiolol serve`: HTTP server for the website. Serves a generated site directory
//! (`<file>.gz`, written by `meiolol site`, when the client accepts gzip); with `render`
//! it renders pages on request from loaded data first (site.Loaded), the files being the
//! fallback. `meiolol dev` adds live reload (Dev).

const std = @import("std");
const Io = std.Io;
const site = @import("site/root.zig");

const log = std.log.scoped(.serve);

/// Largest file served; the model file is the biggest at ~12 MB
const max_file = 64 * 1024 * 1024;

pub const Options = struct {
    /// Site directory; null serves rendered pages only
    root: ?[]const u8 = null,
    host: []const u8 = "127.0.0.1",
    port: u16 = 8080,
    render: ?*site.Loaded = null,
    dev: ?Dev = null,
};

/// Every HTML page gets a script polling /__dev, which answers with the process start
/// and the static files' latest change, and reloads when that moves. The process
/// replaces itself with its binary once a rebuild (zig build --watch) replaced the file
pub const Dev = struct {
    /// argv[0] is the binary's absolute path
    argv: []const []const u8,
    /// Front-end files served from disk (site.Options.static_dir)
    static_dir: []const u8,
    /// The binary's at process start: a rebuild during the data load still restarts
    mtime: i96,

    pub fn init(gpa: std.mem.Allocator, io: Io, argv: []const []const u8, static_dir: []const u8) !Dev {
        const args = try gpa.dupe([]const u8, argv);
        args[0] = try std.process.executablePathAlloc(io, gpa);
        return .{ .argv = args, .static_dir = static_dir, .mtime = mtime(io, Io.Dir.cwd(), args[0]) };
    }
};

const reload_script =
    \\<script>(()=>{let v;const p=async()=>{try{const t=await(await fetch("/__dev",{cache:"no-store"})).text();
    \\if(v&&t!==v)location.reload();v=t}catch(e){}setTimeout(p,400)};p()})()</script>
    \\
;

/// The root is opened by path per request: a rebuilt site may be swapped in by renaming
/// directories
const Context = struct {
    gpa: std.mem.Allocator,
    io: Io,
    opts: Options,
    started: i96,
};

pub fn run(gpa: std.mem.Allocator, io: Io, opts: Options) !void {
    const address = try Io.net.IpAddress.parse(opts.host, opts.port);
    var server = try address.listen(io, .{ .reuse_address = true });
    defer server.deinit(io);
    log.info("serving {s} on http://{s}:{d}/", .{ opts.root orelse "rendered pages", opts.host, opts.port });

    var ctx: Context = .{ .gpa = gpa, .io = io, .opts = opts, .started = Io.Clock.real.now(io).toNanoseconds() };
    var group: Io.Group = .init;
    defer group.cancel(io);
    if (opts.dev) |d| group.async(io, watchBinary, .{ io, d });
    while (true) {
        const stream = try server.accept(io);
        group.async(io, connection, .{ &ctx, stream });
    }
}

fn mtime(io: Io, dir: Io.Dir, path: []const u8) i96 {
    const st = dir.statFile(io, path, .{}) catch return 0;
    return st.mtime.toNanoseconds();
}

fn watchBinary(io: Io, dev: Dev) void {
    var last = dev.mtime;
    while (true) {
        io.sleep(.fromMilliseconds(300), .awake) catch return;
        const now = mtime(io, Io.Dir.cwd(), dev.argv[0]);
        // Same as last look: the build has finished writing it
        if (now != dev.mtime and now != 0 and now == last) {
            log.info("rebuilt: restarting", .{});
            const err = std.process.replace(io, .{ .argv = dev.argv });
            log.warn("restart: {t}", .{err});
        }
        last = now;
    }
}

fn connection(ctx: *Context, stream: Io.net.Stream) void {
    const io = ctx.io;
    defer stream.close(io);
    var recv_buffer: [8192]u8 = undefined;
    var send_buffer: [16 * 1024]u8 = undefined;
    var conn_reader = stream.reader(io, &recv_buffer);
    var conn_writer = stream.writer(io, &send_buffer);
    var server = std.http.Server.init(&conn_reader.interface, &conn_writer.interface);
    while (server.reader.state == .ready) {
        var request = server.receiveHead() catch |err| switch (err) {
            error.HttpConnectionClosing => return,
            else => return log.debug("closing connection: {t}", .{err}),
        };
        respond(ctx, &request) catch |err| {
            log.warn("{s}: {t}", .{ request.head.target, err });
            return;
        };
    }
}

fn respond(ctx: *Context, request: *std.http.Server.Request) !void {
    if (request.head.method != .GET and request.head.method != .HEAD) {
        // A bodyless POST has neither length nor encoding, and respond() asserts on one
        // when it discards the body
        if (request.head.transfer_encoding == .none and request.head.content_length == null) {
            request.head.content_length = 0;
        }
        return request.respond("method not allowed\n", .{ .status = .method_not_allowed, .keep_alive = false });
    }
    var path_buf: [512]u8 = undefined;
    const path = resolve(&path_buf, request.head.target) orelse return notFound(request);

    var gzip = false;
    var it = request.iterateHeaders();
    while (it.next()) |h| {
        if (std.ascii.eqlIgnoreCase(h.name, "accept-encoding") and
            std.mem.indexOf(u8, h.value, "gzip") != null) gzip = true;
    }

    if (ctx.opts.dev) |d| if (std.mem.eql(u8, path, "__dev")) {
        var buf: [64]u8 = undefined;
        const v = try std.fmt.bufPrint(&buf, "{d}-{d}", .{ ctx.started, staticVersion(ctx.io, d.static_dir) });
        return request.respond(v, .{ .extra_headers = &.{.{ .name = "cache-control", .value = "no-store" }} });
    };

    // Clean URLs: /about serves about.html, /tier/ serves tier/index.html
    var candidates: [3][]const u8 = undefined;
    var n: usize = 0;
    var html_buf: [520]u8 = undefined;
    var index_buf: [530]u8 = undefined;
    if (path.len == 0 or path[path.len - 1] == '/') {
        candidates[n] = try std.fmt.bufPrint(&index_buf, "{s}index.html", .{path});
        n += 1;
    } else {
        candidates[n] = path;
        n += 1;
        if (std.fs.path.extension(path).len == 0) {
            candidates[n] = try std.fmt.bufPrint(&html_buf, "{s}.html", .{path});
            n += 1;
        }
    }
    if (ctx.opts.render) |loaded| {
        var arena_state: std.heap.ArenaAllocator = .init(ctx.gpa);
        defer arena_state.deinit();
        const arena = arena_state.allocator();
        for (candidates[0..n]) |name| {
            var body = try loaded.get(arena, name) orelse continue;
            if (ctx.opts.dev != null and std.mem.endsWith(u8, name, ".html")) {
                if (std.mem.lastIndexOf(u8, body, "</body>")) |at| {
                    body = try std.mem.concat(arena, u8, &.{ body[0..at], reload_script, body[at..] });
                }
            }
            return request.respond(body, .{ .extra_headers = &.{
                .{ .name = "content-type", .value = contentType(name) },
                .{ .name = "cache-control", .value = "no-cache" },
            } });
        }
    }
    if (ctx.opts.root != null) for (candidates[0..n]) |name| {
        if (try serveFile(ctx, request, name, gzip)) return;
    };
    return notFound(request);
}

/// Latest change among the static files, so CSS and JS edits reload the page too
fn staticVersion(io: Io, path: []const u8) i96 {
    var dir = Io.Dir.cwd().openDir(io, path, .{ .iterate = true }) catch return 0;
    defer dir.close(io);
    var latest: i96 = 0;
    var it = dir.iterate();
    while (it.next(io) catch null) |e| latest = @max(latest, mtime(io, dir, e.name));
    return latest;
}

/// The request target as a path relative to the site root; null for anything that
/// could escape it
fn resolve(buf: []u8, target: []const u8) ?[]const u8 {
    const raw = target[0 .. std.mem.indexOfAny(u8, target, "?#") orelse target.len];
    if (raw.len == 0 or raw[0] != '/' or raw.len > buf.len) return null;
    const path = raw[1..];
    if (std.mem.indexOfAny(u8, path, "\\%\x00") != null) return null;
    var parts = std.mem.splitScalar(u8, path, '/');
    while (parts.next()) |part| {
        if (part.len > 0 and part[0] == '.') return null;
    }
    @memcpy(buf[0..path.len], path);
    return buf[0..path.len];
}

/// False when there is no such file
fn serveFile(ctx: *Context, request: *std.http.Server.Request, name: []const u8, gzip: bool) !bool {
    const gpa = ctx.gpa;
    var gz_buf: [600]u8 = undefined;
    const gz_name = try std.fmt.bufPrint(&gz_buf, "{s}.gz", .{name});
    var encoded = gzip;
    const body = blk: {
        if (gzip) {
            if (read(ctx, gz_name)) |b| break :blk b else |err| switch (err) {
                error.FileNotFound => {},
                else => return err,
            }
        }
        encoded = false;
        break :blk read(ctx, name) catch |err| switch (err) {
            error.FileNotFound, error.IsDir => return false,
            else => return err,
        };
    };
    defer gpa.free(body);

    var headers: [3]std.http.Header = undefined;
    var n: usize = 0;
    headers[n] = .{ .name = "content-type", .value = contentType(name) };
    n += 1;
    headers[n] = .{ .name = "cache-control", .value = "public, max-age=3600" };
    n += 1;
    if (encoded) {
        headers[n] = .{ .name = "content-encoding", .value = "gzip" };
        n += 1;
    }
    try request.respond(body, .{ .extra_headers = headers[0..n] });
    return true;
}

fn read(ctx: *Context, name: []const u8) ![]u8 {
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = try std.fmt.bufPrint(&buf, "{s}/{s}", .{ ctx.opts.root.?, name });
    return Io.Dir.cwd().readFileAlloc(ctx.io, path, ctx.gpa, .limited(max_file));
}

fn notFound(request: *std.http.Server.Request) !void {
    try request.respond("not found\n", .{
        .status = .not_found,
        .extra_headers = &.{.{ .name = "content-type", .value = "text/plain; charset=utf-8" }},
    });
}

fn contentType(name: []const u8) []const u8 {
    const types = [_]struct { []const u8, []const u8 }{
        .{ ".html", "text/html; charset=utf-8" },
        .{ ".css", "text/css; charset=utf-8" },
        .{ ".js", "text/javascript; charset=utf-8" },
        .{ ".json", "application/json" },
        .{ ".wasm", "application/wasm" },
        .{ ".svg", "image/svg+xml" },
        .{ ".txt", "text/plain; charset=utf-8" },
    };
    const ext = std.fs.path.extension(name);
    for (types) |t| if (std.mem.eql(u8, ext, t[0])) return t[1];
    return "application/octet-stream";
}

test "resolve" {
    var buf: [512]u8 = undefined;
    try std.testing.expectEqualStrings("", resolve(&buf, "/").?);
    try std.testing.expectEqualStrings("tier/mid.html", resolve(&buf, "/tier/mid.html?x=1").?);
    try std.testing.expectEqualStrings("riot.txt", resolve(&buf, "/riot.txt").?);
    try std.testing.expectEqual(null, resolve(&buf, "/../etc/passwd"));
    try std.testing.expectEqual(null, resolve(&buf, "/tier/../../x"));
    try std.testing.expectEqual(null, resolve(&buf, "/%2e%2e/x"));
    try std.testing.expectEqual(null, resolve(&buf, "/.env"));
    try std.testing.expectEqual(null, resolve(&buf, "relative"));
}
