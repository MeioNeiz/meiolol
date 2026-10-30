//! `meiolol api`: the dynamic service behind "Your games" (docs/your-games.md). JSON
//! over HTTP on localhost, behind nginx at /api/ on the website's host. Lookups queue a
//! job for the fetcher (fetch.zig, the only Riot caller) and return at once; the page
//! polls until the job is done.
//!
//!   GET  /api/games?id=Name%23TAG   state, player, report (game.zig); &refresh=1 checks
//!                                   for new games sooner than a visit does
//!   GET  /api/list?id=Name%23TAG    /api/games as your.html's binary data
//!                                   (ui.yourlist.Lookup); &refresh=1 the same
//!   GET  /api/game?id=Name%23TAG&start=MS  one of the report's games with its detail, as
//!                                   the game page's binary data (ui.gamedata.Data)
//!   GET  /api/friends?id=Name%23TAG who the player plays with (friends.zig), from the
//!                                   games /api/games fetched; fetches nothing itself
//!   GET  /api/friends.bin?id=..     the same as ui.yourfriends.Friends (ui.data)
//!   POST /api/forget?id=Name%23TAG  objection: issue a profile icon; &check=1 checks it
//!   GET  /api/forget?id=Name%23TAG  the objection's state
//!   GET  /api/squad?s=TOKEN         a squad and its games together as ui.squad.Data
//!                                   (squads.zig)
//!   POST /api/squad/check?id=..&do=create&name=N | do=join&s=T | do=leave&s=T  a squad
//!                                   icon check; &k=KEY&check=1 checks it
//!   GET  /api/squad/check?id=..&k=KEY  its state (and a new squad's token)
//!   GET  /api/health                queue length
//!   POST /api/daily?n=N&pick=I&side=S  a finished Daily Draft puzzle's answers (option
//!                                   index 0-5, side 0 blue or 1 red), counted; returns
//!                                   the counts as GET does
//!   GET  /api/daily?n=N             how many picked each option and each side
//!   /api/notes                      notes on the live site (notes.zig), for a login with
//!                                   take_notes
//!   POST /api/notes/tool?on=0|1     the tool on pages in this browser or not (its marker
//!                                   cookie), for the same login

const std = @import("std");
const Io = std.Io;
const store = @import("store");
const core = @import("core");
const ddragon = @import("../ddragon.zig");
const daily_today = @import("../daily.zig").todayNumber;
const httpd = @import("net").server;
pub const cache = @import("cache.zig");
pub const fetch = @import("fetch.zig");
pub const game = @import("game.zig");
pub const example = @import("example.zig");
pub const accounts = @import("accounts.zig");
pub const roles = @import("roles.zig");
pub const pagedata = @import("pagedata.zig");
pub const devfixture = @import("devfixture.zig");
const ui = @import("ui");
pub const friends = @import("friends.zig");
pub const notes = @import("notes.zig");
pub const squads = @import("squads.zig");

const Allocator = std.mem.Allocator;
const log = std.log.scoped(.api);

pub const Options = struct {
    /// api.db
    db_path: [:0]const u8,
    /// accounts.db (accounts.zig)
    accounts_path: [:0]const u8 = "",
    /// Directory with curves-<patch>.bin files (`meiolol curves`); may be empty
    curves_dir: []const u8,
    host: []const u8 = "127.0.0.1",
    port: u16 = 8090,
    /// Access-Control-Allow-Origin, for a page served from another origin in testing
    cors: ?[]const u8 = null,
    fetch: fetch.Options = .{},
    /// devfixture's players in `db_path`, emptied first (a file: each request opens its own
    /// connection), run from the repo root; the fetcher doesn't run, so no Riot call and no
    /// key
    fixture: bool = false,
};

/// A visit refreshes a player's games when the last refresh is older than this
const refresh_after_s: i64 = 5 * 60;
/// "Check for new games" (&refresh=1) does when it is older than this. Riot lists a game
/// a few minutes after it ends, so the page repeats the check for a while
const check_after_s: i64 = 60;
/// Retry an unknown Riot ID after this long
const not_found_s: i64 = 24 * 60 * 60;
/// More queued lookups than this and new ones are refused (503) until it drains
const max_jobs: i64 = 30;
/// Games in a report, newest first
const max_games = 100;

/// Newest curves files served: the box pushes two (web-loop.sh push_curves)
const max_curve_files = 2;

const Context = struct {
    gpa: Allocator,
    io: Io,
    opts: Options,
    curves: game.CurveSet,
    accounts: accounts.Service,
    /// For the binary answers; empty when Data Dragon was down at start (names then
    /// show as ids, icons empty)
    shown: Shown = .{},
};

const Shown = struct {
    names: pagedata.Names = .{},
    champs: []const ddragon.Named = &.{},

    fn champ(s: *const Shown, id: u32) anyerror!ui.champ.Champ {
        const c = ddragon.find(s.champs, id) orelse return .{ .name = "", .src = "" };
        return .{ .name = c.name, .src = c.icon };
    }
};

pub fn run(gpa: Allocator, io: Io, opts: Options) !void {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var ctx: Context = .{
        .gpa = gpa,
        .io = io,
        .opts = opts,
        .curves = try loadCurves(arena, io, opts.curves_dir),
        .accounts = .{ .gpa = gpa, .io = io, .db_path = opts.accounts_path },
    };
    const patch = newestCurvesPatch(ctx.curves);
    if (loadShown(gpa, arena, io, patch)) |sh| {
        ctx.shown = sh.shown;
        ctx.curves.legendaries = sh.legendary;
    } else |err| log.warn("Data Dragon for {s}: {t}; first items, names and icons left out", .{ patch, err });
    defer ctx.accounts.deinit();
    // Schema now, so a broken accounts.db stops the service at start, not at a login
    (try accounts.open(opts.accounts_path)).close();

    if (opts.fixture) for ([_][]const u8{ "", "-wal", "-shm" }) |ext| {
        const path = try std.mem.concat(arena, u8, &.{ opts.db_path, ext });
        Io.Dir.cwd().deleteFile(io, path) catch |err| if (err != error.FileNotFound) return err;
    };
    const db = try cache.open(opts.db_path);
    defer db.close();
    if (opts.fixture) try devfixture.seed(
        arena,
        db,
        try Io.Dir.cwd().readFileAlloc(io, devfixture.match_path, arena, .limited(1 << 20)),
        try Io.Dir.cwd().readFileAlloc(io, devfixture.timeline_path, arena, .limited(1 << 20)),
        Io.Clock.real.now(io).toSeconds(),
    );
    var fetcher: fetch.Fetcher = .{ .gpa = gpa, .io = io, .db = db, .opts = opts.fetch };
    defer fetcher.deinit();

    const address = try Io.net.IpAddress.parse(opts.host, opts.port);
    var server = try address.listen(io, .{ .reuse_address = true });
    defer server.deinit(io);
    log.info("api on http://{s}:{d}/api/, {d} curves files, Riot via {s}", .{
        opts.host,                                                                               opts.port, ctx.curves.files.len,
        if (opts.fixture) "nothing (fixture)" else opts.fetch.proxy orelse "this process's key",
    });

    if (opts.fixture) return serve(&ctx, &server);
    var worker = try io.concurrent(work, .{&fetcher});
    defer worker.cancel(io);
    serve(&ctx, &server);
}

/// Behind nginx's: it caps bodies at 1 KB (/api/) and 4 KB (/auth/) and waits 30 s for
/// an answer
const limits: httpd.Limits = .{};

fn serve(ctx: *Context, server: *Io.net.Server) void {
    httpd.accept(.api, ctx.io, server, limits, ctx, connection);
}

test "idle keep-alive connections do not hold up the next request" {
    // No pool threads for async: what a 1-2 core host has once a request or two run
    var threaded: Io.Threaded = .init(std.testing.allocator, .{ .async_limit = .nothing });
    defer threaded.deinit();
    const io = threaded.io();
    var ctx: Context = .{ .gpa = std.testing.allocator, .io = io, .opts = .{ .db_path = "", .curves_dir = "" }, .curves = .{}, .accounts = .{ .gpa = std.testing.allocator, .io = io, .db_path = "" } };
    const address = try Io.net.IpAddress.parse("127.0.0.1", 0);
    var server = try address.listen(io, .{ .reuse_address = true });
    defer server.deinit(io);
    var serving = try io.concurrent(serve, .{ &ctx, &server });
    defer serving.cancel(io);

    var idle: [4]Io.net.Stream = undefined;
    for (&idle) |*c| c.* = try server.socket.address.connect(io, .{ .mode = .stream });
    defer for (idle) |c| c.close(io);
    const c = try server.socket.address.connect(io, .{ .mode = .stream });
    defer c.close(io);
    var buf: [256]u8 = undefined;
    var w = c.writer(io, &buf);
    try w.interface.writeAll("GET /api/none HTTP/1.1\r\nHost: x\r\n\r\n");
    try w.interface.flush();
    var got: [256]u8 = undefined;
    const msg = try c.socket.receiveTimeout(io, &got, .{ .duration = .{ .raw = .fromSeconds(5), .clock = .awake } });
    try std.testing.expectStringStartsWith(msg.data, "HTTP/1.1 404");
}

/// Without the fetcher the service only serves stale caches: exit, so systemd restarts
/// it, except on a rejected key (exit 3, as the crawler; the unit does not restart on 3)
fn work(f: *fetch.Fetcher) void {
    f.run() catch |err| switch (err) {
        error.Canceled => return,
        error.KeyRejected => {
            log.err("Riot rejected the API key", .{});
            std.process.exit(3);
        },
        else => {
            log.err("fetcher stopped: {t}", .{err});
            std.process.exit(1);
        },
    };
}

/// The newest curves files in `dir_path` with the legendary items for first-item timing
pub fn loadCurveSet(arena: Allocator, io: Io, dir_path: []const u8) !game.CurveSet {
    var set = try loadCurves(arena, io, dir_path);
    if (set.files.len > 0) {
        const patch = newestCurvesPatch(set);
        if (ddragon.legendaries(arena, io, patch)) |ids| {
            set.legendaries = ids;
        } else |err| log.warn("legendary items for {s}: {t}; first items left out", .{ patch, err });
    }
    return set;
}

/// Item lists change little between patches: the newest curves patch's serves all. ""
/// (Data Dragon's newest) without curves
fn newestCurvesPatch(set: game.CurveSet) []const u8 {
    if (set.files.len == 0) return "";
    const label = set.files[0].label;
    return label[if (std.mem.findScalar(u8, label, '-')) |d| d + 1 else 0..];
}

/// Data Dragon's names and icons and the legendary items, kept in `arena` without the
/// JSON they came from (a few MB parsed)
fn loadShown(gpa: Allocator, arena: Allocator, io: Io, patch: []const u8) !struct { shown: Shown, legendary: []const u32 } {
    var tmp_state: std.heap.ArenaAllocator = .init(gpa);
    defer tmp_state.deinit();
    const tmp = tmp_state.allocator();
    const d = try ddragon.buildData(gpa, tmp, io, patch);
    const champs = try ddragon.champions(gpa, tmp, io, d.version);
    const keep = struct {
        fn f(a: Allocator, list: []const ddragon.Named) ![]const ddragon.Named {
            const out = try a.alloc(ddragon.Named, list.len);
            for (list, out) |x, *o| o.* = .{ .id = x.id, .name = try a.dupe(u8, x.name), .icon = try a.dupe(u8, x.icon) };
            return out;
        }
    }.f;
    return .{
        .shown = .{
            .names = .{
                .version = try arena.dupe(u8, d.version),
                .items = try keep(arena, d.items),
                .spells = try keep(arena, d.spells),
                .runes = try keep(arena, d.runes),
            },
            .champs = try keep(arena, champs),
        },
        .legendary = try arena.dupe(u32, d.legendary),
    };
}

/// curves-<label>.bin files, newest patch first, at most max_curve_files. Mapped, not
/// read: pages load as lookups touch them and the kernel can drop them again, so files
/// of any size fit the unit's MemoryMax. The mappings live as long as the process (a new
/// curves file restarts it: meiolol-api-reload.path)
fn loadCurves(arena: Allocator, io: Io, dir_path: []const u8) !game.CurveSet {
    var dir = Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => {
            log.warn("no curves directory {s}: games show without typical curves", .{dir_path});
            return .{};
        },
        else => return err,
    };
    defer dir.close(io);
    var names: std.ArrayList([]const u8) = .empty;
    var it = dir.iterate();
    while (try it.next(io)) |e| {
        if (e.kind != .file or !std.mem.startsWith(u8, e.name, "curves-") or !std.mem.endsWith(u8, e.name, ".bin")) continue;
        try names.append(arena, try arena.dupe(u8, e.name));
    }
    std.mem.sort([]const u8, names.items, {}, struct {
        fn newer(_: void, a: []const u8, b: []const u8) bool {
            return newestPatch(a) > newestPatch(b);
        }
    }.newer);
    var files: std.ArrayList(game.CurveSet.File) = .empty;
    for (names.items) |name| {
        if (files.items.len == max_curve_files) break;
        const curves = core.curvesfile.Curves.map(arena, io, dir, name) catch |err| {
            log.warn("{s}: {t}", .{ name, err });
            continue;
        };
        const label = name["curves-".len .. name.len - ".bin".len];
        try files.append(arena, .{ .label = label, .curves = curves });
        log.info("{s}: {d} curves, {d} MB mapped", .{ name, curves.curves.len, curves.bytes.len >> 20 });
    }
    return .{ .files = files.items };
}

test "loadCurves: the newest files, newest patch first" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir = try arena.print(".zig-cache/tmp/{s}", .{&tmp.sub_path});
    var b: core.curvesfile.Builder = .{ .gpa = std.testing.allocator };
    defer b.deinit();
    var aw: std.Io.Writer.Allocating = .init(arena);
    try b.write(&aw.writer, "16.20", 1);
    for ([_][]const u8{ "curves-16.19.bin", "curves-16.21.bin", "curves-16.20.bin" }) |name| {
        try tmp.dir.writeFile(io, .{ .sub_path = name, .data = aw.written() });
    }

    const set = try loadCurves(arena, io, dir);
    defer for (set.files) |f| {
        var c = f.curves;
        c.unmap(arena, io);
    };
    try std.testing.expectEqual(2, set.files.len);
    try std.testing.expectEqualStrings("16.21", set.files[0].label);
    try std.testing.expectEqualStrings("16.20", set.files[1].label);
    try std.testing.expectEqualStrings("16.20", set.files[0].curves.patch());
}

/// "curves-16.19-16.20.bin" -> 1620; 0 when unreadable
fn newestPatch(name: []const u8) u32 {
    if (name.len < "curves-.bin".len) return 0;
    const label = name["curves-".len .. name.len - ".bin".len];
    const r = game.CurveSet.patchRange(label) orelse return 0;
    return r[1];
}

test newestPatch {
    try std.testing.expect(newestPatch("curves-17.10.bin") > newestPatch("curves-17.9.bin"));
    try std.testing.expectEqual(1620, newestPatch("curves-16.19-16.20.bin"));
    try std.testing.expectEqual(0, newestPatch("curves-x.bin"));
}

fn connection(ctx: *Context, conn: httpd.Connection) void {
    // The query holds the Riot ID: the path only
    httpd.requests(.api, ctx.io, conn, ctx, handle, .path);
}

const Status = std.http.Status;

fn handle(ctx: *Context, request: *std.http.Server.Request) !void {
    var arena_state: std.heap.ArenaAllocator = .init(ctx.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const target = request.head.target;
    const q = std.mem.findScalar(u8, target, '?') orelse target.len;
    const path = target[0..q];
    const query = if (q < target.len) target[q + 1 ..] else "";
    const method = request.head.method;

    if (std.mem.startsWith(u8, path, "/auth/")) return ctx.accounts.handle(request);
    if (std.mem.eql(u8, path, "/api/games") and method == .GET) {
        const db = try cache.open(ctx.opts.db_path);
        defer db.close();
        const r = try games(ctx, arena, db, query);
        return send(ctx, request, r);
    }
    if (std.mem.eql(u8, path, "/api/list") and method == .GET) {
        const db = try cache.open(ctx.opts.db_path);
        defer db.close();
        const r = try listOf(ctx, arena, db, query);
        return send(ctx, request, r);
    }
    if (std.mem.eql(u8, path, "/api/game") and method == .GET) {
        const db = try cache.open(ctx.opts.db_path);
        defer db.close();
        const r = try oneGame(ctx, arena, db, query);
        return send(ctx, request, r);
    }
    if (std.mem.eql(u8, path, "/api/friends") and method == .GET) {
        const db = try cache.open(ctx.opts.db_path);
        defer db.close();
        const r = try friendsOf(arena, db, query);
        return send(ctx, request, r);
    }
    if (std.mem.eql(u8, path, "/api/friends.bin") and method == .GET) {
        const db = try cache.open(ctx.opts.db_path);
        defer db.close();
        const r = try friendsBin(ctx, arena, db, query);
        return send(ctx, request, r);
    }
    if (std.mem.eql(u8, path, "/api/forget") and (method == .POST or method == .GET)) {
        const db = try cache.open(ctx.opts.db_path);
        defer db.close();
        const r = try forget(ctx, arena, db, query, method == .POST);
        return send(ctx, request, r);
    }
    if (std.mem.eql(u8, path, "/api/squad") and method == .GET) {
        const db = try cache.open(ctx.opts.db_path);
        defer db.close();
        const r = try squadRead(ctx, arena, db, query);
        return send(ctx, request, r);
    }
    if (std.mem.eql(u8, path, "/api/squad/check") and (method == .POST or method == .GET)) {
        const db = try cache.open(ctx.opts.db_path);
        defer db.close();
        const r = try squadCheck(ctx, arena, db, query, method == .POST);
        return send(ctx, request, r);
    }
    if (std.mem.eql(u8, path, "/api/daily") and (method == .POST or method == .GET)) {
        const db = try cache.open(ctx.opts.db_path);
        defer db.close();
        const r = try daily(arena, db, query, method == .POST, daily_today(ctx.io));
        return send(ctx, request, r);
    }
    if (std.mem.eql(u8, path, "/api/notes") or std.mem.eql(u8, path, "/api/notes/tool")) return notesRequest(ctx, arena, request, path, query);
    if (std.mem.eql(u8, path, "/api/health") and method == .GET) {
        const db = try cache.open(ctx.opts.db_path);
        defer db.close();
        const jobs = try db.scalar("SELECT count(*) FROM jobs", .{}) orelse 0;
        return send(ctx, request, .{ .status = .ok, .body = try arena.print("{{\"ok\":true,\"jobs\":{d}}}", .{jobs}) });
    }
    return send(ctx, request, .{ .status = .not_found, .body = "{\"error\":\"not found\"}" });
}

/// /api/notes and /api/notes/tool for a login with take_notes; a write also needs
/// X-Meiolol-Action: 1, which a cross-site form can't send
fn notesRequest(ctx: *Context, arena: Allocator, request: *std.http.Server.Request, path: []const u8, query_head: []const u8) !void {
    const tool = std.mem.endsWith(u8, path, "/tool");
    const method: notes.Method = switch (request.head.method) {
        .GET => if (tool) return send(ctx, request, try errorReply(arena, .method_not_allowed, "error", "method not allowed")) else .GET,
        .POST => .POST,
        .PATCH => .PATCH,
        else => return send(ctx, request, try errorReply(arena, .method_not_allowed, "error", "method not allowed")),
    };
    // Reading the body invalidates the head's strings
    const query = try arena.dupe(u8, query_head);
    const action = if (accounts.header(request, "x-meiolol-action")) |v| std.mem.eql(u8, v, "1") else false;
    const now = Io.Clock.real.now(ctx.io).toSeconds();
    const who = who: {
        const token = accounts.cookieToken(request) orelse
            return send(ctx, request, try errorReply(arena, .unauthorized, "error", "not signed in"));
        const db = try accounts.open(ctx.opts.accounts_path);
        defer db.close();
        break :who try accounts.session(db, arena, token, now) orelse
            return send(ctx, request, try errorReply(arena, .unauthorized, "error", "not signed in"));
    };
    if (!who.role.can(.take_notes)) return send(ctx, request, try errorReply(arena, .forbidden, "error", "your role cannot take notes"));
    if (method != .GET and !action) return send(ctx, request, try errorReply(arena, .forbidden, "error", "missing X-Meiolol-Action"));
    if (tool) {
        const on = try param(arena, query, "on") orelse "";
        if (!std.mem.eql(u8, on, "0") and !std.mem.eql(u8, on, "1")) return send(ctx, request, try errorReply(arena, .bad_request, "error", "expected ?on=0|1"));
        return request.respond("{\"ok\":true}", .{ .extra_headers = &.{
            .{ .name = "content-type", .value = "application/json" },
            .{ .name = "cache-control", .value = "no-store" },
            .{ .name = "set-cookie", .value = if (on[0] == '1') accounts.marker_on else accounts.marker_off },
        } });
    }
    var body: []const u8 = "";
    if (method != .GET) {
        var body_buf: [1024]u8 = undefined;
        const r = try request.readerExpectContinue(&body_buf);
        body = r.allocRemaining(arena, .limited(notes.max_body)) catch |err| switch (err) {
            error.StreamTooLong => return send(ctx, request, try errorReply(arena, .payload_too_large, "error", "too long")),
            else => return err,
        };
    }
    const db = try cache.open(ctx.opts.db_path);
    defer db.close();
    const r = try notes.handle(arena, db, method, query, body, who.username, now);
    return send(ctx, request, .{ .status = r.status, .body = r.body, .binary = r.binary });
}

/// JSON, or ui.data's binary when 200 from a binary call (errors stay JSON)
fn send(ctx: *Context, request: *std.http.Server.Request, r: Reply) !void {
    var headers: [3]std.http.Header = undefined;
    var n: usize = 0;
    headers[n] = .{ .name = "content-type", .value = if (r.binary) "application/octet-stream" else "application/json" };
    n += 1;
    headers[n] = .{ .name = "cache-control", .value = "no-store" };
    n += 1;
    if (ctx.opts.cors) |origin| {
        headers[n] = .{ .name = "access-control-allow-origin", .value = origin };
        n += 1;
    }
    try request.respond(r.body, .{ .status = r.status, .extra_headers = headers[0..n] });
}

const Reply = struct { status: Status, body: []const u8, binary: bool = false };

fn errorReply(arena: Allocator, status: Status, state: []const u8, message: []const u8) !Reply {
    return .{ .status = status, .body = try std.json.Stringify.valueAlloc(arena, .{ .state = state, .@"error" = message }, .{}) };
}

/// Ranked puzzles have four, pro ones six (ui.dailydata.Puzzle.options)
pub const daily_options = 6;

pub const DailyOut = struct {
    n: u32,
    /// Players who finished it, and how many picked each option and each side
    players: i64,
    picks: [daily_options]i64,
    sides: [2]i64,
};

/// Daily Draft answer counts, sent once per browser when a puzzle is finished; a repeat or
/// a script can add more, which nginx's rate limit bounds. Puzzles past tomorrow (`today`
/// + 1, as the site's pages) are refused, so none can be seeded before it is out and junk
/// can't grow the table. ui.dailydays sends and shows them
fn daily(arena: Allocator, db: store.Db, query: []const u8, post: bool, today: u32) !Reply {
    const n = try intParam(arena, query, "n", today + 1) orelse
        return errorReply(arena, .bad_request, "error", "expected ?n=puzzle");
    if (n == 0) return errorReply(arena, .bad_request, "error", "expected ?n=puzzle");
    if (post) {
        const pick = try intParam(arena, query, "pick", daily_options - 1);
        const side = try intParam(arena, query, "side", 1);
        if (pick == null or side == null) return errorReply(arena, .bad_request, "error", "expected &pick=0-5&side=0-1");
        try db.run("INSERT INTO daily_answers VALUES (?, ?, ?, 1) ON CONFLICT DO UPDATE SET count = count + 1", .{ n, pick.?, side.? });
    }
    var out: DailyOut = .{ .n = n, .players = 0, .picks = @splat(0), .sides = @splat(0) };
    var q = try db.prepare("SELECT pick, side, count FROM daily_answers WHERE n = ?");
    defer q.deinit();
    try q.bind(.{n});
    while (try q.step()) {
        const r = q.row(struct { pick: i64, side: i64, count: i64 });
        out.players += r.count;
        out.picks[@intCast(r.pick)] += r.count;
        out.sides[@intCast(r.side)] += r.count;
    }
    return .{ .status = .ok, .body = try std.json.Stringify.valueAlloc(arena, out, .{}) };
}

/// A whole number from 0 to `max` in ?name=; null when absent or not one
fn intParam(arena: Allocator, query: []const u8, name: []const u8, max: u32) !?u32 {
    const v = try param(arena, query, name) orelse return null;
    const x = std.fmt.parseInt(u32, v, 10) catch return null;
    return if (x <= max) x else null;
}

/// Value of `name` in a query string, percent-decoded; null when absent
pub fn param(arena: Allocator, query: []const u8, name: []const u8) !?[]const u8 {
    var it = std.mem.splitScalar(u8, query, '&');
    while (it.next()) |pair| {
        const eq = std.mem.findScalar(u8, pair, '=') orelse continue;
        if (!std.mem.eql(u8, pair[0..eq], name)) continue;
        const v = try arena.dupe(u8, pair[eq + 1 ..]);
        return std.Uri.percentDecodeInPlace(v);
    }
    return null;
}

/// The lower case Riot ID key from ?id=Name#TAG
fn riotIdParam(arena: Allocator, query: []const u8) !?[]const u8 {
    const id = try param(arena, query, "id") orelse return null;
    const hash = std.mem.findScalarLast(u8, id, '#') orelse return null;
    const buf = try arena.alloc(u8, id.len);
    return cache.riotIdKey(buf, id[0..hash], id[hash + 1 ..]);
}

pub const PlayerOut = struct {
    name: []const u8,
    tag: []const u8,
    platform: []const u8,
    tier: ?[]const u8,
    division: ?[]const u8,
    lp: ?i64,
    /// Unix seconds; 0 before the first refresh
    refreshed: i64,
    @"error": ?[]const u8,
};

pub const GamesOut = struct {
    /// queued: waiting for the fetcher; fetching: in progress; ready; not_found
    state: []const u8,
    /// 2: /api/list and /api/game answer. Absent from the API before them, so pages
    /// served beside either can tell (your.js links a game's page only from 2)
    api: u8 = 2,
    /// Jobs ahead in the queue
    ahead: ?i64 = null,
    /// Games left to fetch and in this refresh
    pending: ?i64 = null,
    total: ?i64 = null,
    player: ?PlayerOut = null,
    report: ?game.Report = null,
    /// Unix seconds from which &refresh=1 starts a refresh
    check_at: ?i64 = null,
};

fn games(ctx: *Context, arena: Allocator, db: store.Db, query: []const u8) !Reply {
    const key = try riotIdParam(arena, query) orelse
        return errorReply(arena, .bad_request, "error", "expected ?id=Name#TAG");
    const l = try lookUp(ctx, arena, db, key, try param(arena, query, "refresh") != null);
    if (l.status == .service_unavailable) return busy(arena);
    var out = l.out;
    if (l.puuid) |p| out.report = try report(ctx, arena, db, p, rankOf(out.player.?), false, max_games);
    return .{ .status = l.status, .body = try gamesJson(arena, out) };
}

/// /api/games for a page with no JSON parser: always 200 but for a bad query, the state
/// says the rest. Each game's detail too, for its CS and level. &n=N: the newest N games.
/// &cached=1: the cache only, as a glance and not a visit (Home's player bar): nothing
/// queued, looked_up untouched, state none when the cache doesn't know the player
fn listOf(ctx: *Context, arena: Allocator, db: store.Db, query: []const u8) !Reply {
    const bad = "expected ?id=Name#TAG[&n=1..100][&cached=1][&refresh=1]";
    const key = try riotIdParam(arena, query) orelse return errorReply(arena, .bad_request, "error", bad);
    const n: u32 = if (try param(arena, query, "n") == null) max_games else switch (try intParam(arena, query, "n", max_games) orelse 0) {
        0 => return errorReply(arena, .bad_request, "error", bad),
        else => |x| x,
    };
    const l = if (try param(arena, query, "cached") != null)
        try cachedLookUp(arena, db, key)
    else
        try lookUp(ctx, arena, db, key, try param(arena, query, "refresh") != null);
    const o = l.out;
    const small = struct {
        fn f(v: ?i64) ?u16 {
            return if (v) |x| @intCast(std.math.clamp(x, 0, std.math.maxInt(u16))) else null;
        }
    }.f;
    var out: ui.yourlist.Lookup = .{
        .state = std.meta.stringToEnum(ui.yourlist.Lookup.State, o.state) orelse return error.UnknownState,
        .ahead = small(o.ahead),
        .pending = small(o.pending),
        .total = small(o.total),
        .check_at = o.check_at,
    };
    if (l.puuid) |puuid| {
        const p = o.player.?;
        out.failed = p.@"error";
        const r = try report(ctx, arena, db, puuid, rankOf(p), true, n);
        const who: pagedata.Who = .{ .name = p.name, .tag = p.tag, .platform = p.platform, .tier = p.tier, .division = p.division, .lp = p.lp, .refreshed = p.refreshed };
        var list = try pagedata.list(arena, who, r.games, ctx.shown.names, &ctx.shown, Shown.champ);
        // Rows link by start (/api/game), not into a page's file
        const rows = try arena.dupe(ui.yourlist.Game, list.games);
        for (rows) |*g| g.page = null;
        list.games = rows;
        out.list = list;
    }
    var bytes: std.ArrayList(u8) = .empty;
    try ui.data.encode(arena, ui.yourlist.Lookup, out, &bytes);
    return .{ .status = .ok, .body = bytes.items, .binary = true };
}

/// lookUp from the cache alone: none, opted_out or ready, whatever the refresh's age
fn cachedLookUp(arena: Allocator, db: store.Db, key: []const u8) !Looked {
    const none: Looked = .{ .out = .{ .state = "none" } };
    const acct = try account(arena, db, key) orelse return none;
    const puuid = acct.puuid orelse return none;
    if (try db.scalar("SELECT 1 FROM blocked WHERE puuid = ?", .{puuid}) != null) {
        return .{ .out = .{ .state = "opted_out" } };
    }
    const player = try loadPlayer(arena, db, puuid) orelse return none;
    return .{ .out = .{ .state = "ready", .player = player, .check_at = player.refreshed + check_after_s }, .puuid = puuid };
}

/// A lookup's state; the report is the caller's to make, for `puuid` when ready
const Looked = struct { status: Status = .ok, out: GamesOut, puuid: ?[]const u8 = null };

/// Queues a refresh as a visit or a check (`asked`) calls for. 503 busy when the queue
/// is full
fn lookUp(ctx: *Context, arena: Allocator, db: store.Db, key: []const u8, asked: bool) !Looked {
    const now = std.Io.Clock.real.now(ctx.io).toSeconds();
    const busy_now: Looked = .{ .status = .service_unavailable, .out = .{ .state = "busy" } };

    // Every read statement is finished before a write (see fetch.cachedSummary)
    const acct = try account(arena, db, key);
    if (acct == null or (acct.?.puuid == null and now - acct.?.checked > not_found_s)) {
        if (!try enqueue(db, key, now)) return busy_now;
        return .{ .out = try progress(db, key, .{ .state = "queued" }) };
    }
    const puuid = acct.?.puuid orelse return .{ .status = .not_found, .out = .{ .state = "not_found" } };
    if (try db.scalar("SELECT 1 FROM blocked WHERE puuid = ?", .{puuid}) != null) {
        return .{ .out = .{ .state = "opted_out" } };
    }
    const player = try loadPlayer(arena, db, puuid) orelse {
        if (!try enqueue(db, key, now)) return busy_now;
        return .{ .out = try progress(db, key, .{ .state = "queued" }) };
    };
    try db.run("UPDATE players SET looked_up = ? WHERE puuid = ?", .{ now, puuid });
    // A job for this player under either key: the Riot ID while resolving, else PUUID
    const job_key = if (try db.scalar("SELECT 1 FROM jobs WHERE key = ?", .{key}) != null) key else puuid;
    const gate = if (asked) check_after_s else refresh_after_s;
    if (now - player.refreshed > gate and !try enqueue(db, job_key, now) and asked) return busy_now;

    var out = try progress(db, job_key, .{ .state = "ready", .player = player });
    out.check_at = player.refreshed + check_after_s;
    return .{ .out = out, .puuid = puuid };
}

fn rankOf(p: PlayerOut) game.Rank {
    return .{ .tier = p.tier, .division = p.division, .lp = p.lp };
}

fn account(arena: Allocator, db: store.Db, key: []const u8) !?struct { puuid: ?[]const u8, checked: i64 } {
    var q = try db.prepare("SELECT puuid, checked FROM accounts WHERE riot_id = ?");
    defer q.deinit();
    try q.bind(.{key});
    if (!try q.step()) return null;
    const r = q.row(struct { puuid: ?[]const u8, checked: i64 });
    return .{ .puuid = if (r.puuid) |v| try arena.dupe(u8, v) else null, .checked = r.checked };
}

fn loadPlayer(arena: Allocator, db: store.Db, puuid: []const u8) !?PlayerOut {
    var p = try db.prepare(
        \\SELECT game_name, tag_line, platform, tier, division, lp, refreshed, error
        \\FROM players WHERE puuid = ?
    );
    defer p.deinit();
    try p.bind(.{puuid});
    if (!try p.step()) return null;
    const r = p.row(struct {
        name: []const u8,
        tag: []const u8,
        platform: []const u8,
        tier: ?[]const u8,
        division: ?[]const u8,
        lp: ?i64,
        refreshed: i64,
        @"error": ?[]const u8,
    });
    return .{
        .name = try arena.dupe(u8, r.name),
        .tag = try arena.dupe(u8, r.tag),
        .platform = try arena.dupe(u8, r.platform),
        .tier = if (r.tier) |v| try arena.dupe(u8, v) else null,
        .division = if (r.division) |v| try arena.dupe(u8, v) else null,
        .lp = r.lp,
        .refreshed = r.refreshed,
        .@"error" = if (r.@"error") |v| try arena.dupe(u8, v) else null,
    };
}

fn reply(arena: Allocator, out: GamesOut) !Reply {
    return .{ .status = .ok, .body = try gamesJson(arena, out) };
}

/// GET /api/games' body, also `meiolol your-example`'s file
pub fn gamesJson(arena: Allocator, out: GamesOut) ![]u8 {
    return std.json.Stringify.valueAlloc(arena, out, .{ .emit_null_optional_fields = false });
}

fn busy(arena: Allocator) !Reply {
    return errorReply(arena, .service_unavailable, "busy", "too many lookups queued; try again in a few minutes");
}

/// False when the queue is full. A key already queued keeps its place
fn enqueue(db: store.Db, key: []const u8, now: i64) !bool {
    if (try db.scalar("SELECT 1 FROM jobs WHERE key = ?", .{key}) != null) return true;
    if (try queued(db) >= max_jobs) return false;
    try db.run("INSERT OR IGNORE INTO jobs (key, requested) VALUES (?, ?)", .{ key, now });
    return true;
}

/// Jobs someone waits on: history steps (fetch.zig) run behind them and are left out
fn queued(db: store.Db) !i64 {
    return try db.scalar("SELECT count(*) FROM jobs WHERE NOT key LIKE ? || '%'", .{cache.history_prefix}) orelse 0;
}

/// `out` with the job's place and progress when one is queued
fn progress(db: store.Db, key: []const u8, out: GamesOut) !GamesOut {
    var o = out;
    var q = try db.prepare("SELECT requested, pending, total FROM jobs WHERE key = ?");
    defer q.deinit();
    try q.bind(.{key});
    if (!try q.step()) return o;
    const r = q.row(struct { requested: i64, pending: ?i64, total: ?i64 });
    o.ahead = try db.scalar("SELECT count(*) FROM jobs WHERE requested < ?", .{r.requested});
    o.pending = r.pending;
    o.total = r.total;
    o.state = if (o.pending != null) "fetching" else "queued";
    return o;
}

/// The newest `n` games; `detail`: each game's Game.detail too
fn report(ctx: *Context, arena: Allocator, db: store.Db, puuid: []const u8, rank: game.Rank, detail: bool, n: u32) !game.Report {
    var q = try db.prepare(
        \\SELECT pg.match_id, pg.slot, m.summary, m.timeline
        \\FROM player_games pg JOIN matches m USING (match_id)
        \\WHERE pg.puuid = ? ORDER BY pg.start_ms DESC LIMIT ?
    );
    defer q.deinit();
    try q.bind(.{ puuid, n });
    var inputs: std.ArrayList(game.Input) = .empty;
    while (try q.step()) {
        var in = try input(arena, db, q.row(GameRow)) orelse continue;
        in.detail = detail;
        try inputs.append(arena, in);
    }
    return game.report(arena, inputs.items, rank, ctx.curves);
}

const GameRow = struct {
    match_id: []const u8,
    slot: u8,
    summary: []const u8,
    timeline: ?[]const u8,
};

/// Null when the summary is unreadable
fn input(arena: Allocator, db: store.Db, r: GameRow) !?game.Input {
    const summary = fetch.readSummary(arena, r.summary) catch |err| {
        log.warn("{s}: summary {t}", .{ r.match_id, err });
        return null;
    };
    if (r.slot >= summary.players.len) return null;
    const t = if (r.timeline != null and r.timeline.?.len > 0) fetch.readTimeline(arena, r.timeline.?) catch |err| blk: {
        log.warn("{s}: timeline {t}", .{ r.match_id, err });
        break :blk null;
    } else null;
    const platform = r.match_id[0 .. std.mem.findScalar(u8, r.match_id, '_') orelse 0];
    return .{
        .summary = summary,
        .slot = r.slot,
        .timeline = t,
        .platform = try arena.dupe(u8, platform),
        .riot_ids = try riotIds(arena, db, r.match_id, summary.players.len),
    };
}

/// One game of a looked-up player's report (by `Game.start_ms`) with its detail, as
/// game.html reads it. The cache only: the player's lookup fetched it
fn oneGame(ctx: *Context, arena: Allocator, db: store.Db, query: []const u8) !Reply {
    const key = try riotIdParam(arena, query) orelse
        return errorReply(arena, .bad_request, "error", "expected ?id=Name#TAG&start=ms");
    const start = std.fmt.parseInt(i64, try param(arena, query, "start") orelse "", 10) catch
        return errorReply(arena, .bad_request, "error", "expected ?id=Name#TAG&start=ms");
    const none = try errorReply(arena, .not_found, "none", "no such game: look the player up first");
    const acct = try account(arena, db, key) orelse return none;
    const puuid = acct.puuid orelse return none;
    if (try db.scalar("SELECT 1 FROM blocked WHERE puuid = ?", .{puuid}) != null) {
        return errorReply(arena, .not_found, "opted_out", "this player opted out");
    }
    const player = try loadPlayer(arena, db, puuid) orelse return none;
    var q = try db.prepare(
        \\SELECT pg.match_id, pg.slot, m.summary, m.timeline
        \\FROM player_games pg JOIN matches m USING (match_id)
        \\WHERE pg.puuid = ? AND pg.start_ms = ? LIMIT 1
    );
    defer q.deinit();
    try q.bind(.{ puuid, start });
    if (!try q.step()) return none;
    var in = try input(arena, db, q.row(GameRow)) orelse return none;
    in.detail = true;
    const g = try game.analyse(arena, in, rankOf(player), ctx.curves);
    const d = try pagedata.data(arena, ctx.shown.names, &.{g}, &ctx.shown, Shown.champ);
    if (d.games.len == 0) return errorReply(arena, .not_found, "none", "no timeline for this game");
    var bytes: std.ArrayList(u8) = .empty;
    try ui.data.encode(arena, ui.gamedata.Data, d, &bytes);
    return .{ .status = .ok, .body = bytes.items, .binary = true };
}

pub const FriendsOut = struct {
    /// none: not looked up (ask /api/games first); ready
    state: []const u8,
    friends: ?friends.Out = null,
};

fn friendsOf(arena: Allocator, db: store.Db, query: []const u8) !Reply {
    const key = try riotIdParam(arena, query) orelse
        return errorReply(arena, .bad_request, "error", "expected ?id=Name#TAG");
    return switch (try findFriends(arena, db, key)) {
        .none => .{ .status = .ok, .body = "{\"state\":\"none\"}" },
        .opted_out => .{ .status = .ok, .body = "{\"state\":\"opted_out\"}" },
        .ready => |out| .{ .status = .ok, .body = try std.json.Stringify.valueAlloc(arena, FriendsOut{ .state = "ready", .friends = out }, .{}) },
    };
}

/// friendsOf as ui.yourfriends.Friends, for the Your games page's Friends view
fn friendsBin(ctx: *Context, arena: Allocator, db: store.Db, query: []const u8) !Reply {
    const key = try riotIdParam(arena, query) orelse
        return errorReply(arena, .bad_request, "error", "expected ?id=Name#TAG");
    const yf = ui.yourfriends;
    var out: yf.Friends = .{ .state = .none };
    switch (try findFriends(arena, db, key)) {
        .none => {},
        .opted_out => out.state = .opted_out,
        .ready => |o| {
            var ids: std.ArrayList(u32) = .empty;
            const rec = struct {
                fn f(r: friends.Record) yf.Record {
                    return .{ .games = r.games, .wins = r.wins };
                }
            }.f;
            const eff = struct {
                fn f(e: ?friends.Effect) ?yf.Effect {
                    const x = e orelse return null;
                    return .{ .together = rec(x.with), .apart = rec(x.apart), .apart_rate = @floatCast(x.apart_rate), .diff = @floatCast(x.diff), .ci = @floatCast((x.hi - x.lo) / 2) };
                }
            }.f;
            const list = try arena.alloc(yf.Friend, o.friends.len);
            for (list, o.friends) |*f, x| {
                const pairs = try arena.alloc(yf.Pair, x.champions.len);
                for (pairs, x.champions) |*p, c| p.* = .{ .mine = try champIndex(arena, &ids, c.mine), .theirs = try champIndex(arena, &ids, c.theirs), .games = c.games, .wins = c.wins };
                var rs: std.ArrayList(yf.Roles) = .empty;
                for (x.roles) |r| try rs.append(arena, .{
                    .mine = std.meta.stringToEnum(ui.role.Role, r.mine) orelse continue,
                    .theirs = std.meta.stringToEnum(ui.role.Role, r.theirs) orelse continue,
                    .games = r.games,
                    .wins = r.wins,
                });
                f.* = .{ .riot_id = x.riot_id, .together = rec(x.together), .against = rec(x.against), .last_ms = x.last_ms, .you = eff(x.you), .them = eff(x.them), .their_games = x.their_games, .pairs = pairs, .roles = rs.items };
            }
            const champs = try arena.alloc(ui.champ.Champ, ids.items.len);
            for (champs, ids.items) |*c, id| c.* = try ctx.shown.champ(id);
            out = .{ .state = .ready, .games = o.games, .waiting = o.waiting, .with_friends = rec(o.with_friends), .alone = rec(o.alone), .champs = champs, .friends = list };
        },
    }
    var bytes: std.ArrayList(u8) = .empty;
    try ui.data.encode(arena, ui.yourfriends.Friends, out, &bytes);
    return .{ .status = .ok, .body = bytes.items, .binary = true };
}

fn champIndex(arena: Allocator, ids: *std.ArrayList(u32), id: u32) !u16 {
    const at = std.mem.findScalar(u32, ids.items, id) orelse blk: {
        try ids.append(arena, id);
        break :blk ids.items.len - 1;
    };
    return @intCast(at);
}

const Found = union(enum) { none, opted_out, ready: friends.Out };

fn findFriends(arena: Allocator, db: store.Db, key: []const u8) !Found {
    const acct = try account(arena, db, key) orelse return .none;
    const puuid = acct.puuid orelse return .none;
    if (try db.scalar("SELECT 1 FROM blocked WHERE puuid = ?", .{puuid}) != null) return .opted_out;
    if (try db.scalar("SELECT 1 FROM players WHERE puuid = ?", .{puuid}) == null) return .none;
    var built = try friends.build(arena, try friendGames(arena, db, puuid));
    var out = &built.out;
    out.waiting = @intCast(try db.scalar("SELECT count(*) FROM backlog WHERE puuid = ?", .{puuid}) orelse 0);
    var mine_buf: [game.hash_len]u8 = undefined;
    const mine = game.hashPuuid(&mine_buf, puuid);
    const list = try arena.dupe(friends.Friend, out.friends);
    for (list, built.hashes) |*f, hash| {
        const theirs = try cachedPlayer(arena, db, f.riot_id, hash) orelse continue;
        const games_ = try friendGames(arena, db, theirs);
        f.their_games = @intCast(games_.len);
        const t = try friends.tally(arena, games_);
        f.them = friends.effect(&t, mine);
    }
    out.friends = list;
    return .{ .ready = out.* };
}

/// Every cached game of a player, newest first, summaries and names only
fn friendGames(arena: Allocator, db: store.Db, puuid: []const u8) ![]const friends.Game {
    var q = try db.prepare(
        \\SELECT pg.match_id, pg.slot, m.summary
        \\FROM player_games pg JOIN matches m USING (match_id)
        \\WHERE pg.puuid = ? ORDER BY pg.start_ms DESC
    );
    defer q.deinit();
    try q.bind(.{puuid});
    var out: std.ArrayList(friends.Game) = .empty;
    while (try q.step()) {
        const r = q.row(struct { match_id: []const u8, slot: u8, summary: []const u8 });
        const summary = fetch.readSummary(arena, r.summary) catch |err| {
            log.warn("{s}: summary {t}", .{ r.match_id, err });
            continue;
        };
        if (r.slot >= summary.players.len) continue;
        try out.append(arena, .{
            .summary = summary,
            .slot = r.slot,
            .riot_ids = try riotIds(arena, db, r.match_id, summary.players.len),
        });
    }
    return out.items;
}

/// The PUUID of a looked-up player by the Riot ID seen in a game, when it is still the
/// same account (`hash`): names change hands
fn cachedPlayer(arena: Allocator, db: store.Db, riot_id: []const u8, hash: []const u8) !?[]const u8 {
    const sep = std.mem.findScalarLast(u8, riot_id, '#') orelse return null;
    const buf = try arena.alloc(u8, riot_id.len);
    const key = cache.riotIdKey(buf, riot_id[0..sep], riot_id[sep + 1 ..]) orelse return null;
    const acct = try account(arena, db, key) orelse return null;
    const puuid = acct.puuid orelse return null;
    var hash_buf: [game.hash_len]u8 = undefined;
    if (!std.mem.eql(u8, game.hashPuuid(&hash_buf, puuid), hash)) return null;
    if (try db.scalar("SELECT 1 FROM players WHERE puuid = ?", .{puuid}) == null) return null;
    return puuid;
}

/// By slot, null where none is kept (blocked, or not yet backfilled)
fn riotIds(arena: Allocator, db: store.Db, match_id: []const u8, players: usize) ![]const ?[]const u8 {
    const out = try arena.alloc(?[]const u8, players);
    @memset(out, null);
    var q = try db.prepare("SELECT slot, riot_id FROM match_names WHERE match_id = ?");
    defer q.deinit();
    try q.bind(.{match_id});
    while (try q.step()) {
        const r = q.row(struct { slot: u8, riot_id: []const u8 });
        if (r.slot < players) out[r.slot] = try arena.dupe(u8, r.riot_id);
    }
    return out;
}

/// A squad as ui.squad.Data, state none for an unknown token. At most every
/// squads.refresh_s per squad (not per read, so reloads and a leaked link can't multiply
/// Riot calls) a read counts as a lookup of each member and queues their refreshes
fn squadRead(ctx: *Context, arena: Allocator, db: store.Db, query: []const u8) !Reply {
    const token = try param(arena, query, "s") orelse "";
    var out: ui.squad.Data = .{ .state = .none };
    if (squads.validToken(token)) if (try squadData(ctx, arena, db, token)) |d| {
        out = d;
    };
    var bytes: std.ArrayList(u8) = .empty;
    try ui.data.encode(arena, ui.squad.Data, out, &bytes);
    return .{ .status = .ok, .body = bytes.items, .binary = true };
}

fn squadData(ctx: *Context, arena: Allocator, db: store.Db, token: []const u8) !?ui.squad.Data {
    const sq = blk: {
        var q = try db.prepare("SELECT id, name, refreshed FROM squads WHERE token = ?");
        defer q.deinit();
        try q.bind(.{token});
        if (!try q.step()) return null;
        const r = q.row(struct { id: i64, name: []const u8, refreshed: i64 });
        break :blk .{ .id = r.id, .name = try arena.dupe(u8, r.name), .refreshed = r.refreshed };
    };
    const now = std.Io.Clock.real.now(ctx.io).toSeconds();
    var puuids: std.ArrayList([]const u8) = .empty;
    var members: std.ArrayList(ui.squad.Member) = .empty;
    {
        var q = try db.prepare(
            \\SELECT p.puuid, p.game_name, p.tag_line, p.refreshed,
            \\  (SELECT count(*) FROM player_games g WHERE g.puuid = p.puuid)
            \\FROM squad_members m JOIN players p USING (puuid) WHERE m.squad = ? ORDER BY m.joined, p.puuid
        );
        defer q.deinit();
        try q.bind(.{sq.id});
        while (try q.step()) {
            const r = q.row(struct { puuid: []const u8, name: []const u8, tag: []const u8, refreshed: i64, games: i64 });
            try puuids.append(arena, try arena.dupe(u8, r.puuid));
            try members.append(arena, .{ .riot_id = try arena.print("{s}#{s}", .{ r.name, r.tag }), .games = @intCast(r.games) });
        }
    }
    if (now - sq.refreshed >= squads.refresh_s) {
        try db.run("UPDATE squads SET refreshed = ? WHERE id = ?", .{ now, sq.id });
        for (puuids.items) |puuid| {
            try db.run("UPDATE players SET looked_up = ? WHERE puuid = ?", .{ now, puuid });
            if (try db.scalar("SELECT 1 FROM players WHERE puuid = ? AND refreshed < ?", .{ puuid, now - squads.refresh_s }) != null)
                _ = try enqueue(db, puuid, now);
        }
    }
    for (members.items, puuids.items) |*m, puuid| {
        m.waiting = try db.scalar("SELECT 1 FROM jobs WHERE key = ?1 OR key = ?2 || ?1", .{ puuid, cache.history_prefix }) != null;
    }

    // Only matches two or more members share
    const by_member = try arena.alloc(std.ArrayList(squads.Seen), puuids.items.len);
    @memset(by_member, .empty);
    var summaries: std.StringHashMapUnmanaged(game.Summary) = .empty;
    var q = try db.prepare(
        \\SELECT sm.puuid, pg.match_id, pg.slot, m.summary
        \\FROM squad_members sm JOIN player_games pg USING (puuid) JOIN matches m USING (match_id)
        \\WHERE sm.squad = ?1 AND pg.match_id IN (
        \\  SELECT g.match_id FROM squad_members s JOIN player_games g USING (puuid)
        \\  WHERE s.squad = ?1 GROUP BY g.match_id HAVING count(*) >= 2)
    );
    defer q.deinit();
    try q.bind(.{sq.id});
    while (try q.step()) {
        const r = q.row(struct { puuid: []const u8, match_id: []const u8, slot: u8, summary: []const u8 });
        const at = for (puuids.items, 0..) |p, i| {
            if (std.mem.eql(u8, p, r.puuid)) break i;
        } else continue;
        const e = try summaries.getOrPut(arena, r.match_id);
        if (!e.found_existing) {
            e.key_ptr.* = try arena.dupe(u8, r.match_id);
            e.value_ptr.* = fetch.readSummary(arena, r.summary) catch |err| {
                log.warn("{s}: summary {t}", .{ r.match_id, err });
                _ = summaries.remove(r.match_id);
                continue;
            };
        }
        try by_member[at].append(arena, .{ .match_id = e.key_ptr.*, .slot = r.slot, .summary = e.value_ptr.* });
    }
    const lists = try arena.alloc([]const squads.Seen, by_member.len);
    for (lists, by_member) |*l, b| l.* = b.items;
    const together = try squads.together(arena, lists);

    var ids: std.ArrayList(u32) = .empty;
    const out_games = try arena.alloc(ui.squad.Game, together.len);
    for (out_games, together) |*g, t| {
        const seats = try arena.alloc(ui.squad.Seat, t.seats.len);
        for (seats, t.seats) |*s, x| {
            const p = t.summary.players[x.slot];
            s.* = .{
                .member = x.member,
                .champ = try champIndex(arena, &ids, p.champion),
                .role = if (core.Role.fromLcu(p.position)) |r| ui.role.Role.all[@backingInt(r)] else null,
                .k = @intCast(std.math.clamp(p.kills, 0, std.math.maxInt(u16))),
                .d = @intCast(std.math.clamp(p.deaths, 0, std.math.maxInt(u16))),
                .a = @intCast(std.math.clamp(p.assists, 0, std.math.maxInt(u16))),
            };
        }
        g.* = .{
            .start_ms = t.summary.start_ms,
            .queue = ui.yourlist.queueOf(t.summary.queue),
            .duration_s = @intCast(std.math.clamp(t.summary.duration_s, 0, std.math.maxInt(u32))),
            .win = t.summary.players[t.seats[0].slot].win,
            .seats = seats,
        };
    }
    const champs = try arena.alloc(ui.champ.Champ, ids.items.len);
    for (champs, ids.items) |*c, id| c.* = try ctx.shown.champ(id);
    return .{ .state = .ready, .name = sq.name, .members = members.items, .champs = champs, .games = out_games };
}

/// A squad's start, join or leave behind the profile icon check (squads.post, the
/// fetcher's squadCheck); GET and a repeat POST answer the check's state for its key
fn squadCheck(ctx: *Context, arena: Allocator, db: store.Db, query: []const u8, post: bool) !Reply {
    const key = try riotIdParam(arena, query) orelse
        return errorReply(arena, .bad_request, "error", "expected ?id=Name#TAG");
    const k = try param(arena, query, "k") orelse "";
    if (post) {
        const action = if (try param(arena, query, "do")) |d| std.meta.stringToEnum(squads.Action, d) else null;
        const check = try param(arena, query, "check") != null;
        const room = try queued(db) < max_jobs;
        switch (try squads.post(db, ctx.io, key, action, try param(arena, query, "s"), try param(arena, query, "name"), k, check, room, fetch.challenge_s)) {
            .started => |t| return .{ .status = .ok, .body = try arena.print("{{\"state\":\"pending\",\"k\":\"{s}\"}}", .{&t}) },
            .bad => |why| return errorReply(arena, .bad_request, "error", why),
            .busy => return busy(arena),
            .waiting => {},
        }
    }
    const now = std.Io.Clock.real.now(ctx.io).toSeconds();
    return .{ .status = .ok, .body = try squads.checkJson(arena, db, key, k, now) };
}

/// Objection and removal, gated by the profile icon check (docs/your-games.md).
/// POST starts a challenge (or, with &check=1, checks the icon); GET reports its state.
/// The fetcher does the Riot calls: the page polls GET until the state settles
fn forget(ctx: *Context, arena: Allocator, db: store.Db, query: []const u8, post: bool) !Reply {
    const key = try riotIdParam(arena, query) orelse
        return errorReply(arena, .bad_request, "error", "expected ?id=Name#TAG");
    const now = std.Io.Clock.real.now(ctx.io).toSeconds();
    if (post) {
        const check = try param(arena, query, "check") != null;
        const state = blk: {
            var q = try db.prepare("SELECT state, expires FROM challenges WHERE riot_id = ?");
            defer q.deinit();
            try q.bind(.{key});
            if (!try q.step()) break :blk "";
            const r = q.row(struct { state: []const u8, expires: i64 });
            if (r.expires <= now) break :blk "";
            break :blk try arena.dupe(u8, r.state);
        };
        const waiting = std.mem.eql(u8, state, "issued") or std.mem.eql(u8, state, "mismatch");
        const busy_already = std.mem.eql(u8, state, "pending") or std.mem.eql(u8, state, "checking");
        if ((check and waiting) or !(waiting or busy_already)) {
            // Room first: a challenge row with no job behind it would hang until expiry
            if (try queued(db) >= max_jobs) return busy(arena);
            if (check and waiting) {
                try db.run("UPDATE challenges SET state = 'checking' WHERE riot_id = ?", .{key});
            } else {
                try db.run("INSERT OR REPLACE INTO challenges VALUES (?, NULL, NULL, ?, 'pending')", .{ key, now + fetch.challenge_s });
            }
            var buf: [128]u8 = undefined;
            const job = try std.mem.print(&buf, "{s}{s}", .{ fetch.verify_prefix, key });
            // requested 0: ahead of every lookup, someone is waiting on the page
            try db.run("INSERT OR REPLACE INTO jobs (key, requested) VALUES (?, 0)", .{job});
        }
    }
    var q = try db.prepare("SELECT state, icon, expires FROM challenges WHERE riot_id = ?");
    defer q.deinit();
    try q.bind(.{key});
    if (!try q.step()) return .{ .status = .ok, .body = "{\"state\":\"none\"}" };
    const r = q.row(struct { state: []const u8, icon: ?i64, expires: i64 });
    const expired = r.expires <= now and !std.mem.eql(u8, r.state, "done");
    return .{ .status = .ok, .body = try std.json.Stringify.valueAlloc(arena, .{
        .state = if (expired) "expired" else r.state,
        .icon = r.icon,
        .expires = r.expires,
    }, .{}) };
}

test param {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const v = (try param(arena, "x=1&id=Hide%20on%20bush%23KR1", "id")).?;
    try std.testing.expectEqualStrings("Hide on bush#KR1", v);
    try std.testing.expect(try param(arena, "x=1", "id") == null);
}

test "games: a visit refreshes after refresh_after_s, a check after check_after_s" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = std.testing.io;
    var ctx: Context = .{ .gpa = std.testing.allocator, .io = io, .opts = .{ .db_path = ":memory:", .curves_dir = "" }, .curves = .{}, .accounts = .{ .gpa = std.testing.allocator, .io = io, .db_path = "" } };
    const db = try cache.open(":memory:");
    defer db.close();
    const now = std.Io.Clock.real.now(io).toSeconds();
    try db.run("INSERT INTO accounts VALUES ('a#1', 'p', ?)", .{now});
    try db.run("INSERT INTO players (puuid, game_name, tag_line, platform, refreshed) VALUES ('p', 'A', '1', 'EUW1', ?)", .{now - 120});

    const visit = try games(&ctx, arena, db, "id=A%231");
    try std.testing.expectEqual(@as(?i64, 0), try db.scalar("SELECT count(*) FROM jobs", .{}));
    try std.testing.expect(std.mem.find(u8, visit.body, "\"state\":\"ready\"") != null);
    try std.testing.expect(std.mem.find(u8, visit.body, try arena.print("\"check_at\":{d}", .{now - 60})) != null);

    const check = try games(&ctx, arena, db, "id=A%231&refresh=1");
    try std.testing.expectEqual(@as(?i64, 1), try db.scalar("SELECT count(*) FROM jobs WHERE key = 'p'", .{}));
    try std.testing.expect(std.mem.find(u8, check.body, "\"state\":\"queued\"") != null);

    try db.run("DELETE FROM jobs", .{});
    try db.run("UPDATE players SET refreshed = ?", .{now - 30});
    _ = try games(&ctx, arena, db, "id=A%231&refresh=1");
    try std.testing.expectEqual(@as(?i64, 0), try db.scalar("SELECT count(*) FROM jobs", .{}));
}

test "squad: games together, a refresh at most every refresh_s, a check's key" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = std.testing.io;
    var ctx: Context = .{ .gpa = std.testing.allocator, .io = io, .opts = .{ .db_path = ":memory:", .curves_dir = "" }, .curves = .{}, .accounts = .{ .gpa = std.testing.allocator, .io = io, .db_path = "" } };
    const db = try cache.open(":memory:");
    defer db.close();
    const now = std.Io.Clock.real.now(io).toSeconds();
    try db.run("INSERT INTO players (puuid, game_name, tag_line, platform, refreshed) VALUES ('pa', 'A', '1', 'EUW1', 0), ('pb', 'B', '1', 'EUW1', ?), ('pc', 'C', '1', 'EUW1', 0)", .{now});
    try db.run("INSERT INTO squads (id, token, name, created) VALUES (1, 'AbCdEfGhIjKlMnOpQrStUv', 'Duo', 0)", .{});
    try db.run("INSERT INTO squad_members VALUES (1, 'pa', 1), (1, 'pb', 2)", .{});
    // Games 0-2 A and B together, 3 A alone; C (no member) in game 0
    for (0..4) |i| {
        const players = try arena.alloc(game.Summary.Player, 10);
        for (players, 0..) |*p, slot| p.* = .{ .hash = "", .team = if (slot < 5) 100 else 200, .position = "MIDDLE", .champion = 1, .win = (i != 1) == (slot < 5), .kills = 2, .deaths = 1, .assists = 3 };
        const summary: game.Summary = .{ .patch = "16.20", .queue = 440, .start_ms = @intCast(100 - i), .duration_s = 1800, .remake = false, .players = players };
        const json = try std.json.Stringify.valueAlloc(arena, summary, .{});
        const id = try arena.print("EUW1_{d}", .{i});
        try db.run("INSERT INTO matches VALUES (?, 0, ?, NULL)", .{ id, store.Blob{ .bytes = try store.raw.compress(arena, json) } });
        try db.run("INSERT INTO player_games VALUES ('pa', ?, ?, 0)", .{ id, summary.start_ms });
        if (i < 3) try db.run("INSERT INTO player_games VALUES ('pb', ?, ?, 1)", .{ id, summary.start_ms });
        if (i == 0) try db.run("INSERT INTO player_games VALUES ('pc', ?, ?, 2)", .{ id, summary.start_ms });
    }
    const r = try squadRead(&ctx, arena, db, "s=AbCdEfGhIjKlMnOpQrStUv");
    const d = try ui.data.decode(arena, ui.squad.Data, r.body);
    try std.testing.expectEqual(.ready, d.state);
    try std.testing.expectEqualStrings("Duo", d.name);
    try std.testing.expectEqual(2, d.members.len);
    try std.testing.expectEqualStrings("A#1", d.members[0].riot_id);
    try std.testing.expectEqual(4, d.members[0].games);
    try std.testing.expectEqual(3, d.games.len);
    try std.testing.expect(d.games[0].win and !d.games[1].win);
    try std.testing.expectEqual(.flex, d.games[0].queue);
    try std.testing.expectEqual(2, d.games[0].seats.len);
    try std.testing.expectEqual(ui.role.Role.mid, d.games[0].seats[1].role.?);
    // A was stale and is queued, B fresh is not; both count as looked up
    try std.testing.expectEqual(@as(?i64, 1), try db.scalar("SELECT count(*) FROM jobs", .{}));
    try std.testing.expect(d.members[0].waiting and !d.members[1].waiting);
    try std.testing.expectEqual(@as(?i64, 2), try db.scalar("SELECT count(*) FROM players WHERE looked_up >= ?", .{now}));
    try db.run("DELETE FROM jobs", .{});
    _ = try squadRead(&ctx, arena, db, "s=AbCdEfGhIjKlMnOpQrStUv");
    try std.testing.expectEqual(@as(?i64, 0), try db.scalar("SELECT count(*) FROM jobs", .{}));

    const unknown = try ui.data.decode(arena, ui.squad.Data, (try squadRead(&ctx, arena, db, "s=nope")).body);
    try std.testing.expectEqual(.none, unknown.state);

    const started = try squadCheck(&ctx, arena, db, "id=C%231&do=join&s=AbCdEfGhIjKlMnOpQrStUv", true);
    const k = (try std.json.parseFromSliceLeaky(struct { state: []const u8, k: []const u8 }, arena, started.body, .{})).k;
    try std.testing.expectEqual(@as(?i64, 1), try db.scalar("SELECT count(*) FROM jobs WHERE key = 'squad:c#1'", .{}));
    const mine = try squadCheck(&ctx, arena, db, try arena.print("id=C%231&k={s}", .{k}), false);
    try std.testing.expect(std.mem.find(u8, mine.body, "\"state\":\"pending\"") != null);
    try std.testing.expectEqualStrings("{\"state\":\"none\"}", (try squadCheck(&ctx, arena, db, "id=C%231", false)).body);
    try std.testing.expectEqual(.bad_request, (try squadCheck(&ctx, arena, db, "id=C%231&do=create&name=", true)).status);

    // An erasure takes the member out; the last one out deletes the squad
    try cache.forget(db, "pa", now);
    try cache.forget(db, "pb", now);
    try std.testing.expectEqual(@as(?i64, 0), try db.scalar("SELECT count(*) FROM squads", .{}));
}

test "friends: a friend's record with and without the player once both are looked up" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const db = try cache.open(":memory:");
    defer db.close();
    try db.run("INSERT INTO accounts VALUES ('a#1', 'pa', 0), ('b#1', 'pb', 0)", .{});
    try db.run("INSERT INTO players (puuid, game_name, tag_line, platform) VALUES ('pa', 'A', '1', 'EUW1'), ('pb', 'B', '1', 'EUW1')", .{});
    var ha: [game.hash_len]u8 = undefined;
    var hb: [game.hash_len]u8 = undefined;
    const a = game.hashPuuid(&ha, "pa");
    const b = game.hashPuuid(&hb, "pb");
    // Games 0-3 together (3 won), 4-5 A alone (1 won), 6-7 B alone (none won)
    for (0..8) |i| {
        const players = try arena.alloc(game.Summary.Player, 10);
        const win = i < 3 or i == 4;
        for (players, 0..) |*p, slot| {
            const hash = switch (slot) {
                0 => if (i < 6) a else try arena.print("x{d}", .{i}),
                1 => if (i < 4 or i >= 6) b else try arena.print("y{d}", .{i}),
                else => try arena.print("s{d}-{d}", .{ i, slot }),
            };
            p.* = .{ .hash = hash, .team = if (slot < 5) 100 else 200, .position = "", .champion = 1, .win = win == (slot < 5), .kills = 0, .deaths = 0, .assists = 0 };
        }
        const summary: game.Summary = .{ .patch = "16.20", .queue = 420, .start_ms = @intCast(100 - i), .duration_s = 1800, .remake = false, .players = players };
        const json = try std.json.Stringify.valueAlloc(arena, summary, .{});
        const id = try arena.print("EUW1_{d}", .{i});
        try db.run("INSERT INTO matches VALUES (?, 0, ?, NULL)", .{ id, store.Blob{ .bytes = try store.raw.compress(arena, json) } });
        if (i < 6) try db.run("INSERT INTO player_games VALUES ('pa', ?, ?, 0)", .{ id, summary.start_ms });
        if (i < 4 or i >= 6) try db.run("INSERT INTO player_games VALUES ('pb', ?, ?, 1)", .{ id, summary.start_ms });
        try db.run("INSERT INTO match_names VALUES (?, 0, ?, 'A#1'), (?, 1, ?, 'B#1')", .{ id, players[0].hash, id, players[1].hash });
    }
    const r = try friendsOf(arena, db, "id=A%231");
    const got = try std.json.parseFromSliceLeaky(FriendsOut, arena, r.body, .{});
    const f = got.friends.?.friends[0];
    try std.testing.expectEqualStrings("B#1", f.riot_id);
    try std.testing.expectEqual(friends.Record{ .games = 4, .wins = 3 }, f.together);
    try std.testing.expectEqual(friends.Record{ .games = 2, .wins = 1 }, f.you.?.apart);
    try std.testing.expectEqual(6, f.their_games);
    try std.testing.expectEqual(friends.Record{ .games = 4, .wins = 3 }, f.them.?.with);
    try std.testing.expectEqual(friends.Record{ .games = 2, .wins = 0 }, f.them.?.apart);

    try db.run("INSERT INTO blocked VALUES ('pa', 0)", .{});
    try std.testing.expectEqualStrings("{\"state\":\"opted_out\"}", (try friendsOf(arena, db, "id=A%231")).body);
    try std.testing.expectEqualStrings("{\"state\":\"none\"}", (try friendsOf(arena, db, "id=C%231")).body);
}

test "game: one looked-up game with its detail as the game page's data" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var ctx = testContext();
    defer ctx.accounts.deinit();
    ctx.shown.champs = &.{.{ .id = 3, .name = "Annie", .icon = "annie.png" }};
    const db = try cache.open(":memory:");
    defer db.close();
    const raw = try store.raw.decompress(arena, @embedFile("../riot/testdata/timeline.json.gz"));
    const t = try @import("../riot/root.zig").timeline.fromJson(arena, raw);
    const players = try arena.alloc(game.Summary.Player, 10);
    const positions = [_][]const u8{ "TOP", "JUNGLE", "MIDDLE", "BOTTOM", "UTILITY" };
    for (players, 0..) |*p, i| {
        p.* = .{ .hash = "", .team = if (i < 5) 100 else 200, .position = positions[i % 5], .champion = @intCast(i + 1), .win = i < 5, .kills = 0, .deaths = 0, .assists = 0 };
    }
    const summary: game.Summary = .{ .patch = "16.20", .queue = 420, .start_ms = 1791720000000, .duration_s = 1800, .remake = false, .players = players };
    const json = try std.json.Stringify.valueAlloc(arena, summary, .{});
    try db.run("INSERT INTO matches VALUES ('EUW1_1', 0, ?, ?)", .{
        store.Blob{ .bytes = try store.raw.compress(arena, json) },
        store.Blob{ .bytes = try store.raw.compress(arena, try @import("../riot/root.zig").timeline.encode(arena, t)) },
    });
    try db.run("INSERT INTO accounts VALUES ('a#1', 'p', 0)", .{});
    try db.run("INSERT INTO players (puuid, game_name, tag_line, platform) VALUES ('p', 'A', '1', 'EUW1')", .{});
    try db.run("INSERT INTO player_games VALUES ('p', 'EUW1_1', 1791720000000, 7)", .{});
    try db.run("INSERT INTO match_names VALUES ('EUW1_1', 2, '', 'C#1')", .{});

    const r = try oneGame(&ctx, arena, db, "id=A%231&start=1791720000000");
    try std.testing.expectEqual(Status.ok, r.status);
    try std.testing.expect(r.binary);
    const d = try ui.data.decode(arena, ui.gamedata.Data, r.body);
    try std.testing.expectEqual(1, d.games.len);
    const g = d.games[0];
    try std.testing.expectEqual(7, g.you);
    try std.testing.expect(g.kills.len > 0 and g.wc.len > 1);
    try std.testing.expectEqualStrings("C#1", g.seats[2].riot_id);
    try std.testing.expectEqualStrings("Annie", d.champs[g.seats[2].champ].name);
    // Not in Data Dragon's list: no name, no icon
    try std.testing.expectEqualStrings("", d.champs[g.seats[0].champ].name);

    try std.testing.expectEqual(Status.not_found, (try oneGame(&ctx, arena, db, "id=A%231&start=1")).status);
    try std.testing.expectEqual(Status.not_found, (try oneGame(&ctx, arena, db, "id=B%231&start=1791720000000")).status);
    try std.testing.expectEqual(Status.bad_request, (try oneGame(&ctx, arena, db, "id=A%231")).status);
    try db.run("INSERT INTO blocked VALUES ('p', 0)", .{});
    const out = try oneGame(&ctx, arena, db, "id=A%231&start=1791720000000");
    try std.testing.expect(!out.binary and std.mem.find(u8, out.body, "opted_out") != null);
}

test "list: the lookup's state, then its games as your.html reads them" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var ctx = testContext();
    defer ctx.accounts.deinit();
    const db = try cache.open(":memory:");
    defer db.close();
    const decode = struct {
        fn f(a: Allocator, r: Reply) !ui.yourlist.Lookup {
            try std.testing.expect(r.binary and r.status == .ok);
            return ui.data.decode(a, ui.yourlist.Lookup, r.body);
        }
    }.f;

    const first = try decode(arena, try listOf(&ctx, arena, db, "id=A%231"));
    try std.testing.expectEqual(.queued, first.state);
    try std.testing.expectEqual(0, first.ahead.?);
    try std.testing.expectEqual(null, first.list);

    const now = std.Io.Clock.real.now(std.testing.io).toSeconds();
    try db.run("DELETE FROM jobs", .{});
    try db.run("INSERT INTO accounts VALUES ('a#1', 'p', ?)", .{now});
    try db.run("INSERT INTO players (puuid, game_name, tag_line, platform, tier, division, lp, refreshed) VALUES ('p', 'A', '1', 'EUW1', 'GOLD', 'II', 40, ?)", .{now});
    const players = try arena.alloc(game.Summary.Player, 10);
    for (players, 0..) |*p, i| {
        p.* = .{ .hash = "", .team = if (i < 5) 100 else 200, .position = "MIDDLE", .champion = @intCast(i + 1), .win = i < 5, .kills = 2, .deaths = 1, .assists = 3 };
    }
    const summary: game.Summary = .{ .patch = "16.20", .queue = 440, .start_ms = 1791720000000, .duration_s = 1800, .remake = false, .players = players };
    const json = try std.json.Stringify.valueAlloc(arena, summary, .{});
    try db.run("INSERT INTO matches VALUES ('EUW1_1', 0, ?, NULL)", .{store.Blob{ .bytes = try store.raw.compress(arena, json) }});
    try db.run("INSERT INTO player_games VALUES ('p', 'EUW1_1', 1791720000000, 0)", .{});

    const ready = try decode(arena, try listOf(&ctx, arena, db, "id=A%231"));
    try std.testing.expectEqual(.ready, ready.state);
    const l = ready.list.?;
    try std.testing.expectEqualStrings("GOLD", l.player.tier.?);
    try std.testing.expectEqual(1, l.games.len);
    try std.testing.expectEqual(1791720000000, l.games[0].start_ms);
    try std.testing.expectEqual(.flex, l.games[0].queue);
    try std.testing.expectEqual(null, l.games[0].page);

    // A glance: the cache only, nothing queued, looked_up kept
    try db.run("UPDATE players SET looked_up = 5, refreshed = 0", .{});
    const glance = try decode(arena, try listOf(&ctx, arena, db, "id=A%231&cached=1&n=20"));
    try std.testing.expectEqual(.ready, glance.state);
    try std.testing.expectEqual(1, glance.list.?.games.len);
    try std.testing.expectEqual(@as(?i64, 5), try db.scalar("SELECT looked_up FROM players", .{}));
    try std.testing.expectEqual(@as(?i64, 0), try db.scalar("SELECT count(*) FROM jobs", .{}));
    try std.testing.expectEqual(.none, (try decode(arena, try listOf(&ctx, arena, db, "id=B%231&cached=1"))).state);
    try std.testing.expectEqual(@as(?i64, 0), try db.scalar("SELECT count(*) FROM jobs", .{}));
    for ([_][]const u8{ "id=A%231&n=0", "id=A%231&n=101", "id=A%231&n=x", "x=1" }) |bad| {
        try std.testing.expectEqual(Status.bad_request, (try listOf(&ctx, arena, db, bad)).status);
    }

    try db.run("INSERT INTO blocked VALUES ('p', 0)", .{});
    try std.testing.expectEqual(.opted_out, (try decode(arena, try listOf(&ctx, arena, db, "id=A%231"))).state);
    try std.testing.expectEqual(.opted_out, (try decode(arena, try listOf(&ctx, arena, db, "id=A%231&cached=1"))).state);
}

test {
    _ = devfixture;
}

test "daily: counts a finished puzzle's answers, refuses junk and puzzles not out yet" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const db = try cache.open(":memory:");
    defer db.close();
    const today = 3;
    _ = try daily(arena, db, "n=3&pick=2&side=0", true, today);
    _ = try daily(arena, db, "n=3&pick=2&side=1", true, today);
    _ = try daily(arena, db, "n=3&pick=5&side=1", true, today);
    // Tomorrow's: out for a viewer a timezone ahead
    _ = try daily(arena, db, "n=4&pick=1&side=1", true, today);
    const got = try daily(arena, db, "n=3", false, today);
    try std.testing.expectEqualStrings("{\"n\":3,\"players\":3,\"picks\":[0,0,2,0,0,1],\"sides\":[1,2]}", got.body);
    for ([_][]const u8{ "n=3&pick=6&side=0", "n=3&pick=1&side=2", "n=3&pick=-1&side=0", "n=0&pick=1&side=0", "n=5&pick=1&side=0", "n=100001&pick=1&side=0", "n=3&pick=1", "pick=1&side=0" }) |bad| {
        try std.testing.expectEqual(Status.bad_request, (try daily(arena, db, bad, true, today)).status);
    }
    try std.testing.expectEqual(Status.bad_request, (try daily(arena, db, "n=5", false, today)).status);
    try std.testing.expectEqual(@as(?i64, 4), try db.scalar("SELECT sum(count) FROM daily_answers", .{}));
}

/// One request on its own connection, as nginx passes it on; the answer's bytes
fn notesCall(ctx: *Context, arena: Allocator, method: []const u8, query: []const u8, token: ?[]const u8, action: bool, body: []const u8) ![]const u8 {
    var req: Io.Writer.Allocating = .init(arena);
    try req.writer.print("{s} /api/notes{s} HTTP/1.1\r\nHost: x\r\nContent-Length: {d}\r\n", .{ method, query, body.len });
    if (token) |t| try req.writer.print("Cookie: a=b; " ++ accounts.cookie_name ++ "={s}\r\n", .{t});
    if (action) try req.writer.writeAll("X-Meiolol-Action: 1\r\n");
    try req.writer.print("\r\n{s}", .{body});
    var out: Io.Writer.Allocating = .init(arena);
    serveBytes(ctx, req.written(), &out.writer);
    return out.written();
}

test "/api/notes: a take_notes login only, and a write needs X-Meiolol-Action" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var ctx = testContext();
    defer ctx.accounts.deinit();
    ctx.opts.db_path = try arena.printSentinel(".zig-cache/tmp/{s}/api.db", .{&tmp.sub_path}, 0);
    ctx.opts.accounts_path = try arena.printSentinel(".zig-cache/tmp/{s}/accounts.db", .{&tmp.sub_path}, 0);
    const now = Io.Clock.real.now(io).toSeconds();
    const adb = try accounts.open(ctx.opts.accounts_path);
    defer adb.close();
    const admin = try accounts.startSession(adb, io, try accounts.create(adb, "jacob", "x", .admin, now), now);
    const private = try accounts.startSession(adb, io, try accounts.create(adb, "friend", "x", .private, now), now);
    var new: std.ArrayList(u8) = .empty;
    try ui.data.encode(arena, ui.notesdata.New, .{ .path = "/a", .text = "Too wide" }, &new);
    const big: [notes.max_body + 1]u8 = @splat(0);

    const refused = [_]struct { []const u8, ?[]const u8, bool, []const u8, []const u8 }{
        .{ "GET", null, false, "", "401" },
        .{ "GET", &private, false, "", "403" },
        .{ "POST", &private, true, new.items, "403" },
        .{ "POST", &admin, false, new.items, "403" },
        .{ "PUT", &admin, true, new.items, "405" },
        .{ "POST", &admin, true, &big, "413" },
    };
    for (refused) |c| {
        const out = try notesCall(&ctx, arena, c[0], "?path=/a", c[1], c[2], c[3]);
        try std.testing.expectStringStartsWith(out, try arena.print("HTTP/1.1 {s} ", .{c[4]}));
    }
    try std.testing.expectStringStartsWith(try notesCall(&ctx, arena, "POST", "", &admin, true, new.items), "HTTP/1.1 200 ");
    const off = try notesCall(&ctx, arena, "POST", "/tool?on=0", &admin, true, "");
    try std.testing.expectStringStartsWith(off, "HTTP/1.1 200 ");
    try std.testing.expect(std.mem.find(u8, off, accounts.marker_off) != null);
    try std.testing.expect(std.mem.find(u8, try notesCall(&ctx, arena, "POST", "/tool?on=1", &admin, true, ""), accounts.marker_on) != null);
    try std.testing.expectStringStartsWith(try notesCall(&ctx, arena, "POST", "/tool?on=1", &private, true, ""), "HTTP/1.1 403 ");
    try std.testing.expectStringStartsWith(try notesCall(&ctx, arena, "POST", "/tool?on=1", &admin, false, ""), "HTTP/1.1 403 ");
    try std.testing.expectStringStartsWith(try notesCall(&ctx, arena, "POST", "/tool?on=2", &admin, true, ""), "HTTP/1.1 400 ");
    const got = try notesCall(&ctx, arena, "GET", "?path=/a", &admin, false, "");
    try std.testing.expectStringStartsWith(got, "HTTP/1.1 200 ");
    const at = std.mem.find(u8, got, "\r\n\r\n") orelse return error.TestUnexpectedResult;
    const list = try ui.data.decode(arena, ui.notesdata.List, got[at + 4 ..]);
    try std.testing.expectEqual(1, list.notes.len);
    try std.testing.expectEqualStrings("jacob", list.notes[0].author);
    try std.testing.expectEqualStrings("Too wide", list.notes[0].text);
}

const fuzz_token: accounts.Token = @splat('A');

/// What nginx passes on, each followed by a second request on the same connection
const fuzz_requests = [_][]const u8{
    "GET /api/games?id=A%231&refresh=1 HTTP/1.1\r\nHost: x\r\n\r\n",
    "POST /api/forget?id=Hide%20on%20bush%23KR1&check=1 HTTP/1.1\r\nHost: x\r\n\r\n",
    "GET /api/forget?id=A%231 HTTP/1.1\r\nHost: x\r\n\r\n",
    "POST /api/daily?n=3&pick=2&side=0 HTTP/1.1\r\nHost: x\r\nContent-Length: 0\r\n\r\n",
    "GET /api/daily?n=3 HTTP/1.1\r\nHost: x\r\n\r\n",
    "GET /api/notes?path=/a HTTP/1.1\r\nHost: x\r\nCookie: " ++ accounts.cookie_name ++ "=" ++ fuzz_token ++ "\r\n\r\n",
    "PATCH /api/notes?id=1 HTTP/1.1\r\nHost: x\r\nX-Meiolol-Action: 1\r\nContent-Length: 3\r\n\r\nabc",
    "GET /api/game?id=A%231&start=1791720000000 HTTP/1.1\r\nHost: x\r\n\r\n",
    "GET /api/list?id=A%231&refresh=1 HTTP/1.1\r\nHost: x\r\n\r\n",
    "GET /api/list?id=A%231&cached=1&n=20 HTTP/1.1\r\nHost: x\r\n\r\n",
    "POST /auth/login HTTP/1.1\r\nHost: x\r\nX-Meiolol-Action: 1\r\nContent-Length: 42\r\n\r\n" ++
        "{\"username\":\"owner\",\"password\":\"12345678\"}",
    "POST /auth/signup HTTP/1.1\r\nHost: x\r\nX-Meiolol-Action: 1\r\nContent-Length: 50\r\n\r\n" ++
        "{\"link\":\"x\",\"email\":\"a@b.c\",\"password\":\"12345678\"}",
    "GET /auth/check/view_paid HTTP/1.1\r\nHost: x\r\nCookie: a=b; " ++ accounts.cookie_name ++ "=" ++ fuzz_token ++
        "\r\n\r\n",
    "GET /auth/me HTTP/1.1\r\nHost: x\r\nExpect: 100-continue\r\n\r\n",
};

/// A Context on fresh databases: the fuzzer checks each input for leaks, and the login
/// throttle keeps keys
fn testContext() Context {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    return .{
        .gpa = gpa,
        .io = io,
        .opts = .{ .db_path = ":memory:", .curves_dir = "" },
        .curves = .{},
        .accounts = .{ .gpa = gpa, .io = io, .db_path = "", .hasher = .{ .params = .{ .t = 1, .m = 64, .p = 1 } } },
    };
}

/// `bytes` as one connection's requests, as httpd.requests reads them, where a refusal
/// ends the connection
fn serveBytes(ctx: *Context, bytes: []const u8, out: *Io.Writer) void {
    var in: Io.Reader = .fixed(bytes);
    var server = std.http.Server.init(&in, out);
    while (server.reader.state == .ready) {
        var request = server.receiveHead() catch return;
        if (httpd.admit(&request, limits)) |_| return;
        handle(ctx, &request) catch return;
    }
}

fn fuzzRequest(_: void, s: *std.testing.Smith) !void {
    var ctx = testContext();
    defer ctx.accounts.deinit();
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const valid = try std.mem.concat(arena, u8, &.{ fuzz_requests[s.index(fuzz_requests.len)], fuzz_requests[4] });
    var buf: [1024]u8 = undefined;
    var out: Io.Writer.Discarding = .init(&buf);
    serveBytes(&ctx, try core.fuzz.mutate(s, arena, valid), &out.writer);
}

test "fuzz: a damaged request is answered or dropped, never crashes the service" {
    try std.testing.fuzz({}, fuzzRequest, .{});
}

test "a body cut short is answered, then the connection closes" {
    var ctx = testContext();
    defer ctx.accounts.deinit();
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    // backend-fuzz's first find: respond() drained the unread body and asserted it whole
    for ([_][]const u8{ "POST /api/daily?n=3&pick=1&side=0", "GET /auth/me" }) |line| {
        var out: Io.Writer.Allocating = .init(arena);
        const bytes = try arena.print("{s} HTTP/1.1\r\nHost: x\r\nContent-Length: 10\r\n\r\nabc", .{line});
        serveBytes(&ctx, bytes, &out.writer);
        try std.testing.expectStringStartsWith(out.written(), "HTTP/1.1 ");
        try std.testing.expect(std.mem.find(u8, out.written(), "connection: close") != null);
    }
}

test {
    std.testing.refAllDecls(@This());
}
