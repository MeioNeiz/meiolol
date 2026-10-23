//! `meiolol api`: the dynamic service behind "Your games" (docs/your-games.md). JSON
//! over HTTP on localhost, behind nginx at /api/ on the website's host. Lookups queue a
//! job for the fetcher (fetch.zig, the only Riot caller) and return at once; the page
//! polls until the job is done.
//!
//!   GET  /api/games?id=Name%23TAG   state, player, report (game.zig); &refresh=1 checks
//!                                   for new games sooner than a visit does
//!   POST /api/forget?id=Name%23TAG  objection: issue a profile icon; &check=1 checks it
//!   GET  /api/forget?id=Name%23TAG  the objection's state
//!   GET  /api/health                queue length
//!   POST /api/daily?n=N&pick=I&side=S  a finished Daily Draft puzzle's answers (option
//!                                   index 0-3, side 0 blue or 1 red), counted; returns
//!                                   the counts as GET does
//!   GET  /api/daily?n=N             how many picked each option and each side

const std = @import("std");
const Io = std.Io;
const store = @import("store");
const core = @import("core");
const ddragon = @import("../ddragon.zig");
const httpd = @import("../httpd.zig");
pub const cache = @import("cache.zig");
pub const fetch = @import("fetch.zig");
pub const game = @import("game.zig");
pub const example = @import("example.zig");

const Allocator = std.mem.Allocator;
const log = std.log.scoped(.api);

pub const Options = struct {
    /// api.db
    db_path: [:0]const u8,
    /// Directory with curves-<patch>.bin files (`meiolol curves`); may be empty
    curves_dir: []const u8,
    host: []const u8 = "127.0.0.1",
    port: u16 = 8090,
    /// Access-Control-Allow-Origin, for a page served from another origin in testing
    cors: ?[]const u8 = null,
    fetch: fetch.Options = .{},
    /// A visit refreshes a player's games when the last refresh is older than this
    refresh_after_s: i64 = 5 * 60,
    /// "Check for new games" (&refresh=1) does when it is older than this. Riot lists a
    /// game a few minutes after it ends, so the page repeats the check for a while
    check_after_s: i64 = 60,
    /// Retry an unknown Riot ID after this long
    not_found_s: i64 = 24 * 60 * 60,
    /// More queued lookups than this and new ones are refused (503) until it drains
    max_jobs: i64 = 30,
    /// Games in a report, newest first
    max_games: u32 = 100,
};

/// Newest curves files served: the box pushes two (web-loop.sh push_curves)
const max_curve_files = 2;

const Context = struct {
    gpa: Allocator,
    io: Io,
    opts: Options,
    curves: game.CurveSet,
};

pub fn run(gpa: Allocator, io: Io, opts: Options) !void {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var ctx: Context = .{ .gpa = gpa, .io = io, .opts = opts, .curves = try loadCurveSet(arena, io, opts.curves_dir) };

    const db = try cache.open(opts.db_path);
    defer db.close();
    var fetcher: fetch.Fetcher = .{ .gpa = gpa, .io = io, .db = db, .opts = opts.fetch };
    defer fetcher.deinit();

    const address = try Io.net.IpAddress.parse(opts.host, opts.port);
    var server = try address.listen(io, .{ .reuse_address = true });
    defer server.deinit(io);
    log.info("api on http://{s}:{d}/api/, {d} curves files, Riot via {s}", .{
        opts.host, opts.port, ctx.curves.files.len, opts.fetch.proxy orelse "this process's key",
    });

    var worker = try io.concurrent(work, .{&fetcher});
    defer worker.cancel(io);
    serve(&ctx, &server);
}

fn serve(ctx: *Context, server: *Io.net.Server) void {
    httpd.accept(.api, ctx.io, server, ctx, connection);
}

test "idle keep-alive connections do not hold up the next request" {
    // No pool threads for async: what a 1-2 core host has once a request or two run
    var threaded: Io.Threaded = .init(std.testing.allocator, .{ .async_limit = .nothing });
    defer threaded.deinit();
    const io = threaded.io();
    var ctx: Context = .{ .gpa = std.testing.allocator, .io = io, .opts = .{ .db_path = "", .curves_dir = "" }, .curves = .{} };
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
    // Item lists change little between patches: the newest curves patch's serves all
    if (set.files.len > 0) {
        const label = set.files[0].label;
        const patch = label[if (std.mem.indexOfScalar(u8, label, '-')) |d| d + 1 else 0..];
        if (ddragon.legendaries(arena, io, patch)) |ids| {
            set.legendaries = ids;
        } else |err| log.warn("legendary items for {s}: {t}; first items left out", .{ patch, err });
    }
    return set;
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

fn connection(ctx: *Context, stream: Io.net.Stream) void {
    // The query holds the Riot ID: the path only
    httpd.requests(.api, ctx.io, stream, ctx, handle, .path);
}

const Status = std.http.Status;

fn handle(ctx: *Context, request: *std.http.Server.Request) !void {
    var arena_state: std.heap.ArenaAllocator = .init(ctx.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const target = request.head.target;
    const q = std.mem.indexOfScalar(u8, target, '?') orelse target.len;
    const path = target[0..q];
    const query = if (q < target.len) target[q + 1 ..] else "";
    const method = request.head.method;

    if (std.mem.eql(u8, path, "/api/games") and method == .GET) {
        const db = try cache.open(ctx.opts.db_path);
        defer db.close();
        const r = try games(ctx, arena, db, query);
        return send(ctx, request, r.status, r.body);
    }
    if (std.mem.eql(u8, path, "/api/forget") and (method == .POST or method == .GET)) {
        const db = try cache.open(ctx.opts.db_path);
        defer db.close();
        const r = try forget(ctx, arena, db, query, method == .POST);
        return send(ctx, request, r.status, r.body);
    }
    if (std.mem.eql(u8, path, "/api/daily") and (method == .POST or method == .GET)) {
        const db = try cache.open(ctx.opts.db_path);
        defer db.close();
        const r = try daily(arena, db, query, method == .POST);
        return send(ctx, request, r.status, r.body);
    }
    if (std.mem.eql(u8, path, "/api/health") and method == .GET) {
        const db = try cache.open(ctx.opts.db_path);
        defer db.close();
        const jobs = try db.scalar("SELECT count(*) FROM jobs", .{}) orelse 0;
        return send(ctx, request, .ok, try arena.print("{{\"ok\":true,\"jobs\":{d}}}", .{jobs}));
    }
    return send(ctx, request, .not_found, "{\"error\":\"not found\"}");
}

fn send(ctx: *Context, request: *std.http.Server.Request, status: Status, body: []const u8) !void {
    var headers: [3]std.http.Header = undefined;
    var n: usize = 0;
    headers[n] = .{ .name = "content-type", .value = "application/json" };
    n += 1;
    headers[n] = .{ .name = "cache-control", .value = "no-store" };
    n += 1;
    if (ctx.opts.cors) |origin| {
        headers[n] = .{ .name = "access-control-allow-origin", .value = origin };
        n += 1;
    }
    try request.respond(body, .{ .status = status, .extra_headers = headers[0..n] });
}

const Reply = struct { status: Status, body: []const u8 };

fn errorReply(arena: Allocator, status: Status, state: []const u8, message: []const u8) !Reply {
    return .{ .status = status, .body = try std.json.Stringify.valueAlloc(arena, .{ .state = state, .@"error" = message }, .{}) };
}

pub const daily_options = 4;
/// Puzzle numbers past this are refused, so junk can't grow the table without bound
const max_daily = 100_000;

pub const DailyOut = struct {
    n: u32,
    /// Players who finished it, and how many picked each option and each side
    players: i64,
    picks: [daily_options]i64,
    sides: [2]i64,
};

/// Daily Draft answer counts. The page sends a puzzle's once per browser when finished
/// (daily.js); a repeat or a script can add more, which nginx's rate limit bounds
fn daily(arena: Allocator, db: store.Db, query: []const u8, post: bool) !Reply {
    const n = try intParam(arena, query, "n", max_daily) orelse
        return errorReply(arena, .bad_request, "error", "expected ?n=puzzle");
    if (n == 0) return errorReply(arena, .bad_request, "error", "expected ?n=puzzle");
    if (post) {
        const pick = try intParam(arena, query, "pick", daily_options - 1);
        const side = try intParam(arena, query, "side", 1);
        if (pick == null or side == null) return errorReply(arena, .bad_request, "error", "expected &pick=0-3&side=0-1");
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
        const eq = std.mem.indexOfScalar(u8, pair, '=') orelse continue;
        if (!std.mem.eql(u8, pair[0..eq], name)) continue;
        const v = try arena.dupe(u8, pair[eq + 1 ..]);
        return std.Uri.percentDecodeInPlace(v);
    }
    return null;
}

/// The lower case Riot ID key from ?id=Name#TAG
fn riotIdParam(arena: Allocator, query: []const u8) !?[]const u8 {
    const id = try param(arena, query, "id") orelse return null;
    const hash = std.mem.lastIndexOfScalar(u8, id, '#') orelse return null;
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
    const now = std.Io.Clock.real.now(ctx.io).toSeconds();

    // Every read statement is finished before a write (see fetch.cachedSummary)
    const acct = try account(arena, db, key);
    if (acct == null or (acct.?.puuid == null and now - acct.?.checked > ctx.opts.not_found_s)) {
        if (!try enqueue(ctx, db, key, now)) return busy(arena);
        return reply(arena, try progress(db, key, .{ .state = "queued" }));
    }
    const puuid = acct.?.puuid orelse return .{
        .status = .not_found,
        .body = try std.json.Stringify.valueAlloc(arena, GamesOut{ .state = "not_found" }, .{}),
    };
    if (try db.scalar("SELECT 1 FROM blocked WHERE puuid = ?", .{puuid}) != null) {
        return reply(arena, .{ .state = "opted_out" });
    }
    const player = try loadPlayer(arena, db, puuid) orelse {
        if (!try enqueue(ctx, db, key, now)) return busy(arena);
        return reply(arena, try progress(db, key, .{ .state = "queued" }));
    };
    try db.run("UPDATE players SET looked_up = ? WHERE puuid = ?", .{ now, puuid });
    // A job for this player under either key: the Riot ID while resolving, else PUUID
    const job_key = if (try db.scalar("SELECT 1 FROM jobs WHERE key = ?", .{key}) != null) key else puuid;
    const asked = try param(arena, query, "refresh") != null;
    const gate = if (asked) ctx.opts.check_after_s else ctx.opts.refresh_after_s;
    if (now - player.refreshed > gate and !try enqueue(ctx, db, job_key, now) and asked) return busy(arena);

    var out = try progress(db, job_key, .{ .state = "ready", .player = player });
    out.check_at = player.refreshed + ctx.opts.check_after_s;
    out.report = try report(ctx, arena, db, puuid, .{ .tier = player.tier, .division = player.division, .lp = player.lp });
    return reply(arena, out);
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
fn enqueue(ctx: *Context, db: store.Db, key: []const u8, now: i64) !bool {
    if (try db.scalar("SELECT 1 FROM jobs WHERE key = ?", .{key}) != null) return true;
    const jobs = try db.scalar("SELECT count(*) FROM jobs", .{}) orelse 0;
    if (jobs >= ctx.opts.max_jobs) return false;
    try db.run("INSERT OR IGNORE INTO jobs (key, requested) VALUES (?, ?)", .{ key, now });
    return true;
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

fn report(ctx: *Context, arena: Allocator, db: store.Db, puuid: []const u8, rank: game.Rank) !game.Report {
    var q = try db.prepare(
        \\SELECT pg.match_id, pg.slot, m.summary, m.timeline
        \\FROM player_games pg JOIN matches m USING (match_id)
        \\WHERE pg.puuid = ? ORDER BY pg.start_ms DESC LIMIT ?
    );
    defer q.deinit();
    try q.bind(.{ puuid, ctx.opts.max_games });
    var inputs: std.ArrayList(game.Input) = .empty;
    while (try q.step()) {
        const r = q.row(struct {
            match_id: []const u8,
            slot: u8,
            summary: []const u8,
            timeline: ?[]const u8,
        });
        const summary = fetch.readSummary(arena, r.summary) catch |err| {
            log.warn("{s}: summary {t}", .{ r.match_id, err });
            continue;
        };
        if (r.slot >= summary.players.len) continue;
        const t = if (r.timeline) |bytes| fetch.readTimeline(arena, bytes) catch |err| blk: {
            log.warn("{s}: timeline {t}", .{ r.match_id, err });
            break :blk null;
        } else null;
        const platform = r.match_id[0 .. std.mem.indexOfScalar(u8, r.match_id, '_') orelse 0];
        try inputs.append(arena, .{
            .summary = summary,
            .slot = r.slot,
            .timeline = t,
            .platform = try arena.dupe(u8, platform),
            .riot_ids = try riotIds(arena, db, r.match_id, summary.players.len),
        });
    }
    return game.report(arena, inputs.items, rank, ctx.curves);
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
            const jobs = try db.scalar("SELECT count(*) FROM jobs", .{}) orelse 0;
            if (jobs >= ctx.opts.max_jobs) return busy(arena);
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
    var ctx: Context = .{ .gpa = std.testing.allocator, .io = io, .opts = .{ .db_path = ":memory:", .curves_dir = "" }, .curves = .{} };
    const db = try cache.open(":memory:");
    defer db.close();
    const now = std.Io.Clock.real.now(io).toSeconds();
    try db.run("INSERT INTO accounts VALUES ('a#1', 'p', ?)", .{now});
    try db.run("INSERT INTO players (puuid, game_name, tag_line, platform, refreshed) VALUES ('p', 'A', '1', 'EUW1', ?)", .{now - 120});

    const visit = try games(&ctx, arena, db, "id=A%231");
    try std.testing.expectEqual(@as(?i64, 0), try db.scalar("SELECT count(*) FROM jobs", .{}));
    try std.testing.expect(std.mem.indexOf(u8, visit.body, "\"state\":\"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, visit.body, try arena.print("\"check_at\":{d}", .{now - 60})) != null);

    const check = try games(&ctx, arena, db, "id=A%231&refresh=1");
    try std.testing.expectEqual(@as(?i64, 1), try db.scalar("SELECT count(*) FROM jobs WHERE key = 'p'", .{}));
    try std.testing.expect(std.mem.indexOf(u8, check.body, "\"state\":\"queued\"") != null);

    try db.run("DELETE FROM jobs", .{});
    try db.run("UPDATE players SET refreshed = ?", .{now - 30});
    _ = try games(&ctx, arena, db, "id=A%231&refresh=1");
    try std.testing.expectEqual(@as(?i64, 0), try db.scalar("SELECT count(*) FROM jobs", .{}));
}

test "daily: counts a finished puzzle's answers, refuses junk" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const db = try cache.open(":memory:");
    defer db.close();
    _ = try daily(arena, db, "n=3&pick=2&side=0", true);
    _ = try daily(arena, db, "n=3&pick=2&side=1", true);
    _ = try daily(arena, db, "n=3&pick=0&side=1", true);
    _ = try daily(arena, db, "n=4&pick=1&side=1", true);
    const got = try daily(arena, db, "n=3", false);
    try std.testing.expectEqualStrings("{\"n\":3,\"players\":3,\"picks\":[1,0,2,0],\"sides\":[1,2]}", got.body);
    for ([_][]const u8{ "n=3&pick=4&side=0", "n=3&pick=1&side=2", "n=3&pick=-1&side=0", "n=0&pick=1&side=0", "n=100001&pick=1&side=0", "n=3&pick=1", "pick=1&side=0" }) |bad| {
        try std.testing.expectEqual(Status.bad_request, (try daily(arena, db, bad, true)).status);
    }
    try std.testing.expectEqual(@as(?i64, 4), try db.scalar("SELECT sum(count) FROM daily_answers", .{}));
}

test {
    std.testing.refAllDecls(@This());
}
