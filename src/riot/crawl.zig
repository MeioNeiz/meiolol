//! EUW ranked solo crawler. Two threads on separate Riot rate limit buckets:
//! - platform (euw1): ladder seeding for every tier, then mastery with spare budget
//! - regional (europe): match ids per player, then match details, newest first
//! Each thread owns its DB connection, HTTP client and limiter.

const std = @import("std");
const store = @import("store");
const Client = @import("client.zig").Client;
const ep = @import("endpoints.zig");
const match = @import("match.zig");

const log = std.log.scoped(.crawl);

const tiers = [_][]const u8{
    "CHALLENGER", "GRANDMASTER", "MASTER", "DIAMOND", "EMERALD",
    "PLATINUM",   "GOLD",        "SILVER", "BRONZE",  "IRON",
};
const divisions = [_][]const u8{ "I", "II", "III", "IV" };
const pending_low = 300;
const detail_batch = 40;

pub const Options = struct {
    data_dir: []const u8,
    key: []const u8,
    since_days: i64 = 14,
    ladder_refresh_s: i64 = 24 * 3600,
    recheck_s: i64 = 12 * 3600,
    mastery: bool = true,
    hours: ?f64 = null,
};

const Counters = struct {
    matches: std.atomic.Value(u64) = .init(0),
    ids_calls: std.atomic.Value(u64) = .init(0),
    ladder_pages: std.atomic.Value(u64) = .init(0),
    mastery: std.atomic.Value(u64) = .init(0),
    requests: std.atomic.Value(u64) = .init(0),
};

pub const Crawler = struct {
    gpa: std.mem.Allocator,
    io: std.Io,
    opts: Options,
    stop: std.atomic.Value(bool) = .init(false),
    counters: Counters = .{},
    failure: ?anyerror = null,
    failure_lock: std.Io.Mutex = .init,

    pub fn run(c: *Crawler) !void {
        const platform = try std.Thread.spawn(.{}, worker, .{ c, Worker.Kind.platform });
        const regional = try std.Thread.spawn(.{}, worker, .{ c, Worker.Kind.regional });
        const started = c.nowS();
        var last_report = started;
        while (!c.stop.load(.acquire)) {
            c.io.sleep(.fromSeconds(1), .awake) catch break;
            const now = c.nowS();
            if (c.opts.hours) |h| {
                if (@as(f64, @floatFromInt(now - started)) > h * 3600) c.stop.store(true, .release);
            }
            if (now - last_report >= 60) {
                last_report = now;
                c.report(now - started);
            }
        }
        c.stop.store(true, .release);
        platform.join();
        regional.join();
        c.report(c.nowS() - started);
        if (c.failure) |err| return err;
    }

    fn report(c: *Crawler, elapsed_s: i64) void {
        const n = c.counters.matches.load(.monotonic);
        const per_day = if (elapsed_s > 0) n * 86400 / @as(u64, @intCast(elapsed_s)) else 0;
        log.info("matches {d} | ids calls {d} | ladder pages {d} | mastery {d} | " ++
            "{d} req | {d} matches/day", .{
            n,                                        c.counters.ids_calls.load(.monotonic),
            c.counters.ladder_pages.load(.monotonic), c.counters.mastery.load(.monotonic),
            c.counters.requests.load(.monotonic),     per_day,
        });
    }

    fn nowS(c: *Crawler) i64 {
        return std.Io.Clock.real.now(c.io).toSeconds();
    }

    fn fail(c: *Crawler, err: anyerror) void {
        c.failure_lock.lockUncancelable(c.io);
        defer c.failure_lock.unlock(c.io);
        if (c.failure == null) c.failure = err;
        c.stop.store(true, .release);
    }

    fn worker(c: *Crawler, kind: Worker.Kind) void {
        var w = Worker.init(c, kind) catch |err| return c.fail(err);
        defer w.deinit();
        w.loop() catch |err| {
            if (err != error.Stopping) {
                log.err("{t} worker: {t}", .{ kind, err });
                c.fail(err);
            }
        };
    }
};

const Worker = struct {
    c: *Crawler,
    kind: Kind,
    db: store.Db,
    client: Client,

    const Kind = enum { platform, regional };

    fn init(c: *Crawler, kind: Kind) !Worker {
        const db = try store.open(c.gpa, c.opts.data_dir);
        errdefer db.close();
        return .{ .c = c, .kind = kind, .db = db, .client = try .init(c.gpa, c.io, c.opts.key) };
    }

    fn deinit(w: *Worker) void {
        _ = w.c.counters.requests.fetchAdd(w.client.requests.load(.monotonic), .monotonic);
        w.client.deinit();
        w.db.close();
    }

    fn loop(w: *Worker) !void {
        while (true) {
            try w.check();
            switch (w.kind) {
                .platform => {
                    if (try w.seedLadder() > 0) continue;
                    if (w.c.opts.mastery and try w.fetchMasteries(50) > 0) continue;
                    try w.nap(60);
                },
                .regional => try w.matchStep(),
            }
        }
    }

    fn check(w: *Worker) !void {
        if (w.c.stop.load(.acquire)) return error.Stopping;
    }

    fn nap(w: *Worker, seconds: u32) !void {
        for (0..seconds) |_| {
            try w.check();
            try w.c.io.sleep(.fromSeconds(1), .awake);
        }
    }

    fn now(w: *Worker) i64 {
        return w.c.nowS();
    }

    fn seedLadder(w: *Worker) !u32 {
        var fetched: u32 = 0;
        for (tiers) |tier| {
            const apex = std.mem.eql(u8, tier, "MASTER") or std.mem.eql(u8, tier, "GRANDMASTER") or
                std.mem.eql(u8, tier, "CHALLENGER");
            for (if (apex) divisions[0..1] else divisions[0..]) |division| {
                var page: u32 = 1;
                while (true) : (page += 1) {
                    try w.check();
                    var fresh = try w.db.prepare("SELECT entries, fetched_at FROM ladder_pages" ++
                        " WHERE tier = ? AND division = ? AND page = ?");
                    defer fresh.deinit();
                    try fresh.bind(.{ tier, division, page });
                    if (try fresh.step() and fresh.int(1) > w.now() - w.c.opts.ladder_refresh_s) {
                        if (fresh.int(0) == 0) break;
                        continue;
                    }
                    const entries = try w.fetchLadderPage(tier, division, page);
                    fetched += 1;
                    _ = w.c.counters.ladder_pages.fetchAdd(1, .monotonic);
                    if (entries == 0) break;
                }
            }
        }
        return fetched;
    }

    fn fetchLadderPage(w: *Worker, tier: []const u8, division: []const u8, page: u32) !usize {
        const body = try ep.leagueEntries(&w.client, tier, division, page) orelse "[]";
        defer if (body.len > 2) w.c.gpa.free(body);
        var arena: std.heap.ArenaAllocator = .init(w.c.gpa);
        defer arena.deinit();
        const entries = try ep.parse([]const ep.LeagueEntry, arena.allocator(), body);

        const t = w.now();
        try w.db.begin();
        errdefer w.db.rollback();
        var up = try w.db.prepare(
            \\INSERT INTO players (puuid, tier, division, lp, wins, losses, rank_seen_at, source)
            \\VALUES (?,?,?,?,?,?,?,'ladder')
            \\ON CONFLICT (puuid) DO UPDATE SET
            \\    tier = excluded.tier, division = excluded.division, lp = excluded.lp,
            \\    wins = excluded.wins, losses = excluded.losses,
            \\    rank_seen_at = excluded.rank_seen_at, source = 'ladder'
        );
        defer up.deinit();
        for (entries) |e| {
            const puuid = e.puuid orelse continue;
            try up.exec(.{ puuid, e.tier, e.rank, e.leaguePoints, e.wins, e.losses, t });
        }
        try w.db.run("INSERT OR REPLACE INTO ladder_pages VALUES (?,?,?,?,?)", .{
            tier, division, page, entries.len, t,
        });
        try w.db.commit();
        return entries.len;
    }

    fn fetchMasteries(w: *Worker, n: u32) !u32 {
        var arena: std.heap.ArenaAllocator = .init(w.c.gpa);
        defer arena.deinit();
        const puuids = try w.column(arena.allocator(),
            \\SELECT p.puuid FROM players p
            \\WHERE p.source = 'ladder' AND NOT EXISTS
            \\    (SELECT 1 FROM mastery m WHERE m.puuid = p.puuid)
            \\ORDER BY p.puuid LIMIT ?
        , .{n});
        for (puuids) |puuid| {
            try w.check();
            const body = try ep.masteries(&w.client, puuid) orelse continue;
            defer w.c.gpa.free(body);
            const rows = try ep.parse([]const ep.Mastery, arena.allocator(), body);
            const t = w.now();
            try w.db.begin();
            errdefer w.db.rollback();
            try putRaw(w.c.gpa, w.db, "riot_mastery", puuid, body, t);
            var ins = try w.db.prepare("INSERT OR REPLACE INTO mastery VALUES (?,?,?,?,?,?)");
            defer ins.deinit();
            for (rows) |m| {
                try ins.exec(.{ puuid, m.championId, m.championLevel, m.championPoints, m.lastPlayTime, t });
            }
            // Marks the player as done even with no masteries
            if (rows.len == 0) try ins.exec(.{ puuid, 0, null, null, null, t });
            try w.db.commit();
            _ = w.c.counters.mastery.fetchAdd(1, .monotonic);
        }
        return @intCast(puuids.len);
    }

    fn matchStep(w: *Worker) !void {
        const pending = try w.db.scalar("SELECT count(*) FROM match_queue WHERE status = 'pending'", .{}) orelse 0;
        if (pending < pending_low) {
            const scanned = try w.scanPlayers(10);
            if (scanned == 0 and pending == 0) return w.nap(15);
        }
        var arena: std.heap.ArenaAllocator = .init(w.c.gpa);
        defer arena.deinit();
        const batch = try w.column(arena.allocator(),
            \\SELECT match_id FROM match_queue WHERE status = 'pending'
            \\ORDER BY match_id DESC LIMIT ?
        , .{detail_batch});
        for (batch) |id| {
            try w.check();
            try w.fetchMatch(id);
        }
    }

    /// Never-scanned players first, then the stalest. PUUIDs are random, so ordering
    /// by them samples players without favouring any rank or activity.
    fn scanPlayers(w: *Worker, n: u32) !u32 {
        var arena: std.heap.ArenaAllocator = .init(w.c.gpa);
        defer arena.deinit();
        var s = try w.db.prepare(
            \\SELECT puuid, matches_checked_at FROM players
            \\WHERE matches_checked_at IS NULL OR matches_checked_at < ?
            \\ORDER BY matches_checked_at IS NOT NULL, matches_checked_at, puuid
            \\LIMIT ?
        );
        defer s.deinit();
        try s.bind(.{ w.now() - w.c.opts.recheck_s, n });
        const Player = struct { puuid: []const u8, checked_at: ?i64 };
        var players: std.ArrayList(Player) = .empty;
        while (try s.step()) {
            try players.append(arena.allocator(), .{
                .puuid = try arena.allocator().dupe(u8, s.bytes(0)),
                .checked_at = s.optInt(1),
            });
        }
        for (players.items) |p| {
            try w.check();
            try w.scanPlayer(p.puuid, p.checked_at);
        }
        return @intCast(players.items.len);
    }

    fn scanPlayer(w: *Worker, puuid: []const u8, checked_at: ?i64) !void {
        const end = w.now();
        const start_time = @max(checked_at orelse 0, end - w.c.opts.since_days * 86400);
        var start: u32 = 0;
        while (true) : (start += 100) {
            const body = try ep.matchIds(&w.client, puuid, start_time, end, start) orelse "[]";
            defer if (body.len > 2) w.c.gpa.free(body);
            _ = w.c.counters.ids_calls.fetchAdd(1, .monotonic);
            var arena: std.heap.ArenaAllocator = .init(w.c.gpa);
            defer arena.deinit();
            const ids = try ep.parse([]const []const u8, arena.allocator(), body);
            try w.db.begin();
            errdefer w.db.rollback();
            var ins = try w.db.prepare("INSERT OR IGNORE INTO match_queue (match_id, discovered_at) VALUES (?, ?)");
            defer ins.deinit();
            for (ids) |id| try ins.exec(.{ id, end });
            try w.db.commit();
            if (ids.len < 100) break;
        }
        try w.db.run("UPDATE players SET matches_checked_at = ? WHERE puuid = ?", .{ end, puuid });
    }

    fn fetchMatch(w: *Worker, id: []const u8) !void {
        const body = ep.match(&w.client, id) catch |err| switch (err) {
            error.KeyRejected, error.OutOfMemory => return err,
            else => {
                log.warn("match {s}: {t}", .{ id, err });
                return w.db.run(
                    \\UPDATE match_queue SET attempts = attempts + 1,
                    \\    status = CASE WHEN attempts >= 2 THEN 'failed' ELSE status END
                    \\WHERE match_id = ?
                , .{id});
            },
        } orelse {
            return w.db.run("UPDATE match_queue SET status = 'missing' WHERE match_id = ?", .{id});
        };
        defer w.c.gpa.free(body);

        var arena: std.heap.ArenaAllocator = .init(w.c.gpa);
        defer arena.deinit();
        const doc = match.parse(arena.allocator(), body) catch |err| {
            log.warn("match {s} did not parse: {t}", .{ id, err });
            return w.db.run("UPDATE match_queue SET status = 'failed' WHERE match_id = ?", .{id});
        };
        try w.db.begin();
        errdefer w.db.rollback();
        try putRaw(w.c.gpa, w.db, "riot_match", id, body, w.now());
        try match.storeRows(w.db, doc, "riot");
        var ins = try w.db.prepare("INSERT OR IGNORE INTO players (puuid, source) VALUES (?, 'participant')");
        defer ins.deinit();
        for (doc.metadata.participants) |puuid| try ins.exec(.{puuid});
        try w.db.run("UPDATE match_queue SET status = 'done' WHERE match_id = ?", .{id});
        try w.db.commit();
        _ = w.c.counters.matches.fetchAdd(1, .monotonic);
    }

    /// First column of every row, copied into `arena`
    fn column(w: *Worker, arena: std.mem.Allocator, sql: []const u8, args: anytype) ![]const []const u8 {
        var s = try w.db.prepare(sql);
        defer s.deinit();
        try s.bind(args);
        var out: std.ArrayList([]const u8) = .empty;
        while (try s.step()) try out.append(arena, try arena.dupe(u8, s.bytes(0)));
        return out.items;
    }
};

pub fn putRaw(gpa: std.mem.Allocator, db: store.Db, source: []const u8, key: []const u8, body: []const u8, t: i64) !void {
    const blob = try store.raw.compress(gpa, body);
    defer gpa.free(blob);
    try db.run("INSERT OR REPLACE INTO raw.raw_docs VALUES (?,?,?,?)", .{
        source, key, t, store.Blob{ .bytes = blob },
    });
}
