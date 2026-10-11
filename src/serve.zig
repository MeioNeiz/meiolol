//! `meiolol serve`: static file server for the generated website (data/site) on the
//! box, behind a Cloudflare Tunnel. Serves `<file>.gz` (written by `meiolol site`)
//! when the client accepts gzip.

const std = @import("std");
const Io = std.Io;

const log = std.log.scoped(.serve);

/// Largest file served; the model file is the biggest at ~12 MB
const max_file = 64 * 1024 * 1024;

/// The root is opened by path per request: `deploy/box.sh web` swaps in a rebuilt site
/// by renaming directories
const Context = struct { gpa: std.mem.Allocator, io: Io, root: []const u8 };

pub fn run(gpa: std.mem.Allocator, io: Io, root_path: []const u8, host: []const u8, port: u16) !void {
    const address = try Io.net.IpAddress.parse(host, port);
    var server = try address.listen(io, .{ .reuse_address = true });
    defer server.deinit(io);
    log.info("serving {s} on http://{s}:{d}/", .{ root_path, host, port });

    var ctx: Context = .{ .gpa = gpa, .io = io, .root = root_path };
    var group: Io.Group = .init;
    defer group.cancel(io);
    while (true) {
        const stream = try server.accept(io);
        group.async(io, connection, .{ &ctx, stream });
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
    for (candidates[0..n]) |name| {
        if (try serveFile(ctx, request, name, gzip)) return;
    }
    return notFound(request);
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
    const path = try std.fmt.bufPrint(&buf, "{s}/{s}", .{ ctx.root, name });
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
