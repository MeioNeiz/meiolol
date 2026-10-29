//! `meiolol serve`: HTTP server for the website. Serves a generated site directory
//! (`<file>.gz`, written by `meiolol site`, when the client accepts gzip); with `render`
//! it renders pages on request from loaded data first (site.Loaded), the files being the
//! fallback. `meiolol render` renders only, its data replaced as it reloads (Rendered);
//! `meiolol dev` adds live reload (Dev).

const std = @import("std");
const Io = std.Io;
const site = @import("site/root.zig");
const site_admin = @import("site/adminpage.zig");
const store = @import("store");
const httpd = @import("net").server;
const client = @import("net").client;
pub const admin_api = @import("admin_api.zig");
const notes = @import("api/notes.zig");

const log = std.log.scoped(.serve);

/// Largest file served; the model file is the biggest at ~12 MB
const max_file = 64 * 1024 * 1024;

pub const Options = struct {
    /// Site directory; null serves rendered pages only
    root: ?[]const u8 = null,
    host: []const u8 = "127.0.0.1",
    port: u16 = 8080,
    render: ?*Rendered = null,
    dev: ?Dev = null,
    /// Written once listening: deploy/render-swap.sh waits for it. With `render`, it holds
    /// the served data's version (Rendered.writeReady)
    ready: ?[]const u8 = null,
    /// /admin/api/ (`meiolol render`), for requests nginx gave the admin token
    admin: ?*admin_api.Api = null,
};

/// The loaded site pages render from, replaced whole by `swap`: a request keeps the one
/// it started with, freed after its last request
pub const Rendered = struct {
    gpa: std.mem.Allocator,
    io: Io,
    mutex: Io.Mutex = .init,
    current: *Entry,

    const Entry = struct {
        loaded: *site.Loaded,
        /// Holds what loaded's options point into; freed with it
        arena: ?*std.heap.ArenaAllocator,
        /// Load time (ns): new at each start and swap
        version: u64,
        users: usize = 0,
        retired: bool = false,

        fn free(e: *Entry, gpa: std.mem.Allocator) void {
            e.loaded.deinit();
            if (e.arena) |a| {
                a.deinit();
                gpa.destroy(a);
            }
            gpa.destroy(e);
        }
    };

    /// Owns `loaded`, and `arena` when set
    pub fn init(gpa: std.mem.Allocator, io: Io, loaded: *site.Loaded, arena: ?*std.heap.ArenaAllocator) !*Rendered {
        const r = try gpa.create(Rendered);
        errdefer gpa.destroy(r);
        const e = try gpa.create(Entry);
        e.* = .{ .loaded = loaded, .arena = arena, .version = loadVersion(io) };
        r.* = .{ .gpa = gpa, .io = io, .current = e };
        return r;
    }

    /// After the server has stopped
    pub fn deinit(r: *Rendered) void {
        r.current.free(r.gpa);
        r.gpa.destroy(r);
    }

    /// Replaces the site new requests render from, as `init`
    pub fn swap(r: *Rendered, loaded: *site.Loaded, arena: ?*std.heap.ArenaAllocator) !void {
        const e = try r.gpa.create(Entry);
        e.* = .{ .loaded = loaded, .arena = arena, .version = loadVersion(r.io) };
        r.mutex.lockUncancelable(r.io);
        const old = r.current;
        r.current = e;
        old.retired = true;
        const unused = old.users == 0;
        r.mutex.unlock(r.io);
        if (unused) old.free(r.gpa);
    }

    /// `path` holding the served data's version, 16 hex digits: jomify's nginx keeps its
    /// cache by it (deploy/cache-version.sh), so a swap or reload shows at once
    pub fn writeReady(r: *Rendered, path: []const u8) !void {
        r.mutex.lockUncancelable(r.io);
        const version = r.current.version;
        r.mutex.unlock(r.io);
        var buf: [16]u8 = undefined;
        const hex = std.mem.print(&buf, "{x:0>16}", .{version}) catch unreachable;
        try Io.Dir.cwd().writeFile(r.io, .{ .sub_path = path, .data = hex });
    }

    fn loadVersion(io: Io) u64 {
        return @intCast(Io.Clock.real.now(io).toNanoseconds());
    }

    fn acquire(r: *Rendered) *Entry {
        r.mutex.lockUncancelable(r.io);
        defer r.mutex.unlock(r.io);
        r.current.users += 1;
        return r.current;
    }

    fn release(r: *Rendered, e: *Entry) void {
        r.mutex.lockUncancelable(r.io);
        e.users -= 1;
        const done = e.retired and e.users == 0;
        r.mutex.unlock(r.io);
        if (done) e.free(r.gpa);
    }
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
    /// Where /api/ goes, as nginx sends it on the site: `meiolol api --fixture`'s default
    api: []const u8 = "http://127.0.0.1:8090",
    /// /api/notes answered here (notes.zig) without a login: the notes tool runs on its own
    notes_db: [:0]const u8 = "",

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

/// nginx renders through here with a 15 s wait for pages and 120 s for /admin/api/
const limits: httpd.Limits = .{ .connections = 256, .handle = .fromSeconds(180) };

pub fn run(gpa: std.mem.Allocator, io: Io, opts: Options) !void {
    const address = try Io.net.IpAddress.parse(opts.host, opts.port);
    var server = try address.listen(io, .{ .reuse_address = true });
    defer server.deinit(io);
    log.info("serving {s} on http://{s}:{d}/", .{ opts.root orelse "rendered pages", opts.host, opts.port });
    if (opts.ready) |path| if (opts.render) |r| try r.writeReady(path) else try Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = "" });

    var ctx: Context = .{ .gpa = gpa, .io = io, .opts = opts, .started = Io.Clock.real.now(io).toNanoseconds() };
    var group: Io.Group = .init;
    defer group.cancel(io);
    if (opts.dev) |d| group.async(io, watchBinary, .{ io, d });
    httpd.accept(.serve, io, &server, limits, &ctx, connection);
}

fn proxyApi(ctx: *Context, d: Dev, request: *std.http.Server.Request) !void {
    var arena_state: std.heap.ArenaAllocator = .init(ctx.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const method = request.head.method;
    const url = try std.mem.concat(arena, u8, &.{ d.api, request.head.target });
    var body_buf: [256]u8 = undefined;
    const payload: ?[]const u8 = if (method == .POST)
        try (try request.readerExpectContinue(&body_buf)).allocRemaining(arena, .limited(4096))
    else
        null;
    var http: std.http.Client = .{ .allocator = ctx.gpa, .io = ctx.io };
    defer http.deinit();
    const res = client.get(&http, arena, .{ .url = url, .method = method, .payload = payload }) catch |err| {
        log.warn("{s}: {t}", .{ url, err });
        return request.respond("{\"state\":\"error\",\"message\":\"no local API: meiolol api --fixture\"}", .{
            .status = .bad_gateway,
            .extra_headers = &.{.{ .name = "content-type", .value = "application/json" }},
        });
    };
    // client.get keeps no headers: the API answers JSON or ui.data binary
    const json = res.body.len > 0 and res.body[0] == '{';
    return request.respond(res.body, .{
        .status = res.status,
        .extra_headers = &.{.{ .name = "content-type", .value = if (json) "application/json" else "application/octet-stream" }},
    });
}

const dev_marker_on = site.notes.dev_cookie ++ "=1; Path=/; SameSite=Lax";
const dev_marker_off = site.notes.dev_cookie ++ "=; Path=/; Max-Age=0";

fn notesMarked(request: *std.http.Server.Request) bool {
    var it = request.iterateHeaders();
    while (it.next()) |h| {
        if (std.ascii.eqlIgnoreCase(h.name, "cookie") and site.notes.marked(h.value)) return true;
    }
    return false;
}

fn isNotes(target: []const u8) bool {
    const path = target[0 .. std.mem.findScalar(u8, target, '?') orelse target.len];
    return std.mem.eql(u8, path, "/api/notes") or std.mem.eql(u8, path, "/api/notes/tool");
}

/// The site's /api/notes into the dev file, as user "dev"
fn devNotes(ctx: *Context, d: Dev, request: *std.http.Server.Request) !void {
    var arena_state: std.heap.ArenaAllocator = .init(ctx.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const method: notes.Method = switch (request.head.method) {
        .GET => .GET,
        .POST => .POST,
        .PATCH => .PATCH,
        else => return request.respond("method not allowed\n", .{ .status = .method_not_allowed, .keep_alive = false }),
    };
    // Reading the body invalidates the head's strings
    const target = try arena.dupe(u8, request.head.target);
    const query = if (std.mem.findScalar(u8, target, '?')) |q| target[q + 1 ..] else "";
    // The site's marker toggle, as the dev server's cookie
    if (std.mem.startsWith(u8, target, "/api/notes/tool")) {
        const on = std.mem.eql(u8, query, "on=1");
        return request.respond("{\"ok\":true}", .{ .extra_headers = &.{
            .{ .name = "content-type", .value = "application/json" },
            .{ .name = "set-cookie", .value = if (on) dev_marker_on else dev_marker_off },
        } });
    }
    var body: []const u8 = "";
    if (method != .GET) {
        var body_buf: [1024]u8 = undefined;
        const r = try request.readerExpectContinue(&body_buf);
        body = r.allocRemaining(arena, .limited(notes.max_body)) catch |err| switch (err) {
            error.StreamTooLong => return request.respond("too long\n", .{ .status = .payload_too_large, .keep_alive = false }),
            else => return err,
        };
    }
    const db = try store.Db.open(d.notes_db);
    defer db.close();
    try notes.setUp(db);
    const r = try notes.handle(arena, db, method, query, body, "dev", Io.Clock.real.now(ctx.io).toSeconds());
    return request.respond(r.body, .{
        .status = r.status,
        .extra_headers = &.{
            .{ .name = "content-type", .value = if (r.binary) "application/octet-stream" else "application/json" },
            .{ .name = "cache-control", .value = "no-store" },
        },
    });
}

test isNotes {
    try std.testing.expect(isNotes("/api/notes"));
    try std.testing.expect(isNotes("/api/notes?path=/a"));
    try std.testing.expect(isNotes("/api/notes/tool?on=1"));
    try std.testing.expect(!isNotes("/api/notesx"));
    try std.testing.expect(!isNotes("/api/games?id=a"));
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

fn connection(ctx: *Context, conn: httpd.Connection) void {
    httpd.requests(.serve, ctx.io, conn, ctx, respond, .path);
}

fn respond(ctx: *Context, request: *std.http.Server.Request) !void {
    // Without the token, /admin/api/ falls through to the answers any path gets
    if (ctx.opts.admin) |api| {
        if (ctx.opts.render) |r| if (std.mem.eql(u8, request.head.target, "/admin/api/pages.txt") and
            request.head.method == .GET and admin_api.allowed(api, request)) return pages(ctx, r, request);
        if (try admin_api.handle(api, request)) return;
    }
    if (ctx.opts.dev) |d| if (d.notes_db.len > 0 and isNotes(request.head.target)) return devNotes(ctx, d, request);
    if (ctx.opts.dev) |d| if (std.mem.startsWith(u8, request.head.target, "/api/")) return proxyApi(ctx, d, request);
    if (request.head.method != .GET and request.head.method != .HEAD) {
        return request.respond("method not allowed\n", .{ .status = .method_not_allowed, .keep_alive = false });
    }
    var path_buf: [512]u8 = undefined;
    const path = resolve(&path_buf, request.head.target) orelse return notFound(request);

    var gzip = false;
    var it = request.iterateHeaders();
    while (it.next()) |h| {
        if (std.ascii.eqlIgnoreCase(h.name, "accept-encoding") and
            std.mem.find(u8, h.value, "gzip") != null) gzip = true;
    }

    if (ctx.opts.dev) |d| if (std.mem.eql(u8, path, "__dev")) {
        var buf: [64]u8 = undefined;
        const v = try std.mem.print(&buf, "{d}-{d}", .{ ctx.started, staticVersion(ctx.io, d.static_dir) });
        return request.respond(v, .{ .extra_headers = &.{.{ .name = "cache-control", .value = "no-store" }} });
    };

    // The component gallery, from fixtures: no data needed
    if (ctx.opts.dev != null) {
        if (std.mem.eql(u8, path, "gallery")) {
            var arena_state: std.heap.ArenaAllocator = .init(ctx.gpa);
            defer arena_state.deinit();
            const arena = arena_state.allocator();
            const body = try std.mem.concat(arena, u8, &.{ try site.gallery.page(arena), reload_script });
            return request.respond(body, .{ .extra_headers = &.{.{ .name = "content-type", .value = "text/html; charset=utf-8" }} });
        }
        if (std.mem.eql(u8, path, "gallery.css")) {
            return request.respond(site.gallery.css, .{ .extra_headers = &.{.{ .name = "content-type", .value = "text/css; charset=utf-8" }} });
        }
        // The notes tool (site/notes.zig): its files, and the marker that adds its tag
        if (std.mem.startsWith(u8, path, "private/")) if (site.notes.file(path["private/".len..])) |data| {
            return request.respond(data, .{ .extra_headers = &.{
                .{ .name = "content-type", .value = contentType(path) },
                .{ .name = "cache-control", .value = "no-cache" },
            } });
        };
        if (std.mem.eql(u8, path, "__notes/on") or std.mem.eql(u8, path, "__notes/off")) {
            const on = std.mem.endsWith(u8, path, "on");
            return request.respond("", .{ .status = .found, .extra_headers = &.{
                .{ .name = "location", .value = "/" },
                .{ .name = "set-cookie", .value = if (on) dev_marker_on else dev_marker_off },
            } });
        }
        if (std.mem.eql(u8, path, "admin/notes")) {
            var arena_state: std.heap.ArenaAllocator = .init(ctx.gpa);
            defer arena_state.deinit();
            return request.respond(try site.notes.adminPage(arena_state.allocator()), .{ .extra_headers = &.{.{ .name = "content-type", .value = "text/html; charset=utf-8" }} });
        }
        if (std.mem.startsWith(u8, path, "admin/") or std.mem.startsWith(u8, path, "auth/")) {
            var arena_state: std.heap.ArenaAllocator = .init(ctx.gpa);
            defer arena_state.deinit();
            if (try devAdmin(arena_state.allocator(), path)) |body| {
                const page = std.mem.eql(u8, path, "admin/new");
                return request.respond(body, .{ .extra_headers = &.{.{ .name = "content-type", .value = if (page) contentType(".html") else contentType(path) }} });
            }
        }
    }

    var arena_state: std.heap.ArenaAllocator = .init(ctx.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const query = queryOf(request.head.target);
    const names = try candidates(arena, path, viewDir(query));
    if (ctx.opts.render) |rendered| {
        const entry = rendered.acquire();
        defer rendered.release(entry);
        for (names) |name| {
            const got = entry.loaded.get(arena, name) catch |err| switch (err) {
                // `meiolol render` just started: nginx serves its cached copy if it has one
                error.Loading => return request.respond("This page is being updated. Try again in a minute.\n", .{
                    .status = .service_unavailable,
                    .extra_headers = &.{
                        .{ .name = "content-type", .value = "text/plain; charset=utf-8" },
                        .{ .name = "retry-after", .value = "30" },
                    },
                }),
                else => return err,
            };
            var body = got orelse continue;
            if (ctx.opts.dev != null and std.mem.endsWith(u8, name, ".html")) {
                if (std.mem.findLast(u8, body, "</body>")) |at| {
                    const notes_tag = if (notesMarked(request)) site.notes.tag else "";
                    body = try std.mem.concat(arena, u8, &.{ body[0..at], reload_script, notes_tag, body[at..] });
                }
            }
            // As the static build's .gz twins: jomify's nginx compresses only HTML itself
            // (stats.bin is ~12 MB raw, ~0.5 MB gzipped), and caches one copy per
            // Accept-Encoding by Vary
            const compress = gzip and body.len >= 1024 and !std.mem.eql(u8, std.fs.path.extension(name), ".woff2");
            if (compress) {
                const window = try arena.alloc(u8, store.raw.window_len);
                body = try store.raw.compressWith(arena, window, body);
            }
            const headers: [4]std.http.Header = .{
                .{ .name = "content-type", .value = contentType(name) },
                .{ .name = "cache-control", .value = "no-cache" },
                .{ .name = "vary", .value = "Accept-Encoding" },
                .{ .name = "content-encoding", .value = "gzip" },
            };
            return request.respond(body, .{ .extra_headers = headers[0..if (compress) 4 else 3] });
        }
    }
    if (ctx.opts.root != null) for (names) |name| {
        if (try serveFile(ctx, request, name, gzip)) return;
    };
    // Art not made yet: Data Dragon's own, as nginx
    if (try site.ui.art.remote(arena, request.head.target)) |to| return redirect(request, .found, to);
    if (path.len > 0 and path[path.len - 1] == '/') {
        return redirect(request, .moved_permanently, try std.mem.concat(arena, u8, &.{ "/", std.mem.trimEnd(u8, path, "/"), query }));
    }
    // A mistyped capital: the lowercase page, when there is one
    if (std.mem.findAny(u8, path, "ABCDEFGHIJKLMNOPQRSTUVWXYZ") != null) {
        const lower = try std.ascii.allocLowerString(arena, path);
        if (try exists(ctx, arena, try candidates(arena, lower, viewDir(query)))) {
            return redirect(request, .moved_permanently, try std.mem.concat(arena, u8, &.{ "/", lower, query }));
        }
    }
    if (ctx.opts.render) |rendered| return notFoundPage(ctx, rendered, request);
    return notFound(request);
}

/// The site's own 404 page, status kept: nginx passes it through (@render intercepts
/// only 5xx), and a reviewer's mistyped URL gets the site, not a line of text
fn notFoundPage(ctx: *Context, rendered: *Rendered, request: *std.http.Server.Request) !void {
    const entry = rendered.acquire();
    defer rendered.release(entry);
    var arena_state: std.heap.ArenaAllocator = .init(ctx.gpa);
    defer arena_state.deinit();
    const body = entry.loaded.notFound(arena_state.allocator()) catch |err| switch (err) {
        error.Loading => return notFound(request),
        else => return err,
    };
    try request.respond(body, .{
        .status = .not_found,
        .extra_headers = &.{
            .{ .name = "content-type", .value = "text/html; charset=utf-8" },
            .{ .name = "cache-control", .value = "no-cache" },
        },
    });
}

/// Loaded.pageList, a URL a line
fn pages(ctx: *Context, rendered: *Rendered, request: *std.http.Server.Request) !void {
    const entry = rendered.acquire();
    defer rendered.release(entry);
    var arena_state: std.heap.ArenaAllocator = .init(ctx.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var out: std.ArrayList(u8) = .empty;
    for (try entry.loaded.pageList(arena)) |p| try out.print(arena, "{s}\n", .{try site.urlOf(arena, p)});
    return request.respond(out.items, .{ .extra_headers = &.{
        .{ .name = "content-type", .value = "text/plain; charset=utf-8" },
        .{ .name = "cache-control", .value = "no-store" },
    } });
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

/// "?region=all" of the target, "" without a query
fn queryOf(target: []const u8) []const u8 {
    const end = std.mem.findScalar(u8, target, '#') orelse target.len;
    const at = std.mem.findScalar(u8, target[0..end], '?') orelse return "";
    return target[at..end];
}

/// The view tree the query picks (html.View.dir): nginx's $meiolol_view
fn viewDir(query: []const u8) []const u8 {
    var v: site.html.View = .{ .region = .euw, .period = .days30 };
    var it = std.mem.splitScalar(u8, if (query.len > 0) query[1..] else "", '&');
    while (it.next()) |kv| {
        if (std.mem.eql(u8, kv, "region=all")) v.region = .all;
        if (std.mem.eql(u8, kv, "period=patch")) v.period = .patch;
    }
    return v.dir();
}

/// The files `path` may be, first found wins: /champions/top is champions/top.html, in
/// the query's view tree first, then at the site root (shared and champion pages, files)
fn candidates(arena: std.mem.Allocator, path: []const u8, dir: []const u8) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    // Home is "/" only, its file never a URL (nginx: location = /index.html internal)
    if (std.mem.eql(u8, path, "index") or std.mem.eql(u8, path, "index.html")) return out.items;
    const page = if (path.len == 0) "index.html" else if (std.fs.path.extension(path).len == 0 and path[path.len - 1] != '/')
        try std.mem.concat(arena, u8, &.{ path, ".html" })
    else {
        try out.append(arena, path);
        return out.items;
    };
    if (dir.len > 0) try out.append(arena, try std.mem.concat(arena, u8, &.{ dir, page }));
    try out.append(arena, page);
    return out.items;
}

/// Whether any of `names` is a page or file
fn exists(ctx: *Context, arena: std.mem.Allocator, names: []const []const u8) !bool {
    if (ctx.opts.render) |rendered| {
        const entry = rendered.acquire();
        defer rendered.release(entry);
        for (names) |name| if ((entry.loaded.get(arena, name) catch null) != null) return true;
    }
    if (ctx.opts.root) |r| for (names) |name| {
        const full = try std.mem.concat(arena, u8, &.{ r, "/", name });
        if (Io.Dir.cwd().statFile(ctx.io, full, .{})) |_| return true else |_| {}
    };
    return false;
}

fn redirect(request: *std.http.Server.Request, status: std.http.Status, to: []const u8) !void {
    return request.respond("", .{ .status = status, .extra_headers = &.{.{ .name = "location", .value = to }} });
}

/// The request target as a path relative to the site root; null for anything that
/// could escape it
fn resolve(buf: []u8, target: []const u8) ?[]const u8 {
    const raw = target[0 .. std.mem.findAny(u8, target, "?#") orelse target.len];
    if (raw.len == 0 or raw[0] != '/' or raw.len > buf.len) return null;
    const path = raw[1..];
    if (std.mem.findAny(u8, path, "\\%\x00") != null) return null;
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
    const gz_name = try std.mem.print(&gz_buf, "{s}.gz", .{name});
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

    const headers: [3]std.http.Header = .{
        .{ .name = "content-type", .value = contentType(name) },
        .{ .name = "cache-control", .value = "public, max-age=3600" },
        .{ .name = "content-encoding", .value = "gzip" },
    };
    try request.respond(body, .{ .extra_headers = headers[0..if (encoded) 3 else 2] });
    return true;
}

fn read(ctx: *Context, name: []const u8) ![]u8 {
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = try std.mem.print(&buf, "{s}/{s}", .{ ctx.opts.root.?, name });
    return Io.Dir.cwd().readFileAlloc(ctx.io, path, ctx.gpa, .limited(max_file));
}

fn notFound(request: *std.http.Server.Request) !void {
    try request.respond("not found\n", .{
        .status = .not_found,
        .extra_headers = &.{.{ .name = "content-type", .value = "text/plain; charset=utf-8" }},
    });
}

/// The new admin page on its fixtures (ui.adminpage.Demo): the page, its files, and what
/// it fetches. No accounts API here, so its writes fail
fn devAdmin(a: std.mem.Allocator, path: []const u8) !?[]const u8 {
    const ui = site.ui;
    const demo = ui.adminpage.Demo;
    if (std.mem.eql(u8, path, "admin/new")) return try site_admin.page(a);
    if (std.mem.startsWith(u8, path, "admin/")) if (site_admin.file(path["admin/".len..])) |f| return f;
    var out: std.ArrayList(u8) = .empty;
    if (std.mem.eql(u8, path, "admin/admin.bin")) {
        try ui.data.encode(a, ui.admindata.Snapshot, demo.snap, &out);
    } else if (std.mem.eql(u8, path, "admin/api/live.bin")) {
        try ui.data.encode(a, ui.admindata.Live, ui.adminops.Demo.live, &out);
    } else if (std.mem.eql(u8, path, "admin/api/traffic.bin")) {
        try ui.data.encode(a, ui.admindata.Traffic, ui.admintraffic.Demo.data, &out);
    } else if (std.mem.eql(u8, path, "admin/api/log")) {
        return ui.adminops.Demo.log;
    } else if (std.mem.eql(u8, path, "admin/models.bin")) {
        try ui.data.encode(a, ui.modelsdata.Models, ui.adminmodels.Demo.models, &out);
    } else if (std.mem.eql(u8, path, "admin/training/training.bin")) {
        try ui.data.encode(a, ui.modelsdata.Training, ui.adminmodels.Demo.training, &out);
    } else if (std.mem.eql(u8, path, "auth/me.bin")) {
        try ui.data.encode(a, ui.accountsdata.Me, demo.me, &out);
    } else if (std.mem.eql(u8, path, "auth/accounts.bin")) {
        try ui.data.encode(a, ui.accountsdata.Accounts, demo.accounts, &out);
    } else return null;
    return out.items;
}

fn contentType(name: []const u8) []const u8 {
    const types = [_]struct { []const u8, []const u8 }{
        .{ ".html", "text/html; charset=utf-8" },
        .{ ".css", "text/css; charset=utf-8" },
        .{ ".js", "text/javascript; charset=utf-8" },
        .{ ".json", "application/json" },
        .{ ".wasm", "application/wasm" },
        .{ ".svg", "image/svg+xml" },
        .{ ".jpg", "image/jpeg" },
        .{ ".woff2", "font/woff2" },
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

test "clean URLs: the query's view tree first, then the site root" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const eq = std.testing.expectEqualDeep;
    try eq(@as([]const []const u8, &.{"index.html"}), try candidates(a, "", viewDir("")));
    try eq(@as([]const []const u8, &.{ "_v/all/index.html", "index.html" }), try candidates(a, "", viewDir("?region=all")));
    try eq(@as([]const []const u8, &.{ "_v/all-patch/champions/top.html", "champions/top.html" }), try candidates(a, "champions/top", viewDir("?period=patch&region=all")));
    try eq(@as([]const []const u8, &.{"learn.html"}), try candidates(a, "learn", viewDir("?x=1")));
    try eq(@as([]const []const u8, &.{"_v/patch/data/tiers.bin"}), try candidates(a, "_v/patch/data/tiers.bin", viewDir("?period=patch")));
    try eq(@as([]const []const u8, &.{}), try candidates(a, "index", ""));
    try eq(@as([]const []const u8, &.{"champions/"}), try candidates(a, "champions/", ""));
    try std.testing.expectEqualStrings("?region=all", queryOf("/x?region=all#role=mid"));
    try std.testing.expectEqualStrings("", queryOf("/x#a?b"));
}

test "Rendered: a swapped-out site is freed after its last request" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    const db = try store.schema.memory();
    defer db.close();
    const opts: site.Options = .{ .out_dir = "", .patches = &.{}, .since_ms = 0, .all_platforms = &.{}, .contact = "", .updated = "" };
    const r = try Rendered.init(gpa, io, try site.Loaded.init(gpa, io, db, opts), null);
    defer r.deinit();
    const first = r.acquire();
    try r.swap(try site.Loaded.init(gpa, io, db, opts), null);
    try std.testing.expect(first.retired and r.current != first);
    try std.testing.expect(r.current.version != first.version);
    // Freed by this release, not by the swap: the testing allocator reports a double
    // free for one and a leak for none
    r.release(first);
    const second = r.acquire();
    r.release(second);
    try std.testing.expect(!second.retired);
}

test {
    _ = admin_api;
}
