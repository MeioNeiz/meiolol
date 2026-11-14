//! `meiolol rank-backfill`: participants.rank_start of games stored before the column,
//! alongside the crawler. Every sighting and game day sits in memory, seats are read in
//! primary-key order with no lock held, and only the updates run in a write transaction.
//! Point lookups inside one (store.rankstart.backfillChunk, 14 Nov on the box): ~10 cold
//! page reads a game under the write lock, 22 games/s, crawler commits waiting 15-22 s

const std = @import("std");
const store = @import("store");
const main = @import("../main.zig");
const Cmd = main.Cmd;
const rankstart = store.rankstart;

pub const usage =
    \\  rank-backfill  fill participants.rank_start (rank before the game) of games
    \\              from 2026-10-13 stored before the column; alongside the crawler.
    \\              Rerun after a restore (segments hold the rows as first stored)
    \\              --chunk N        games per write transaction (default 500)
    \\              --pause-ms MS    between chunks at least (default 500); always
    \\                               twice the chunk's own time
    \\              --wal-mb N       wait while meiolol.db-wal is over N MB (default
    \\                               1024)
    \\              --after ID       start after this match id (a run logs where it is)
    \\              --games N        stop after about N games (to size a run)
    \\
;

/// ranks and rank_history whole: ~45M rows in under 1 GB
const Sightings = struct {
    const Current = struct { day: u16, rank: u8 };
    const Change = struct { key: i64, day: u16, rank: u8 };

    current: std.AutoHashMapUnmanaged(i64, Current) = .empty,
    /// In rank_history's key order (key, day)
    changes: std.MultiArrayList(Change) = .empty,

    fn load(gpa: std.mem.Allocator, db: store.Db) !Sightings {
        var s: Sightings = .{};
        errdefer s.deinit(gpa);
        {
            var q = try db.prepare("SELECT key, seen_day, rank FROM ranks");
            defer q.deinit();
            try q.bind(.{});
            while (try q.step()) try s.current.put(gpa, q.int(0), .{
                .day = std.math.lossyCast(u16, q.int(1)),
                .rank = std.math.lossyCast(u8, q.int(2)),
            });
        }
        var q = try db.prepare("SELECT key, day, rank FROM rank_history ORDER BY key, day");
        defer q.deinit();
        try q.bind(.{});
        while (try q.step()) try s.changes.append(gpa, .{
            .key = q.int(0),
            .day = std.math.lossyCast(u16, q.int(1)),
            .rank = std.math.lossyCast(u8, q.int(2)),
        });
        return s;
    }

    fn deinit(s: *Sightings, gpa: std.mem.Allocator) void {
        s.current.deinit(gpa);
        s.changes.deinit(gpa);
    }

    /// As rankstart.Lookup.rankStart
    fn rankStart(s: *const Sightings, key: i64, day: i64) ?i64 {
        const current: ?rankstart.Sighting =
            if (s.current.get(key)) |c| .{ .day = c.day, .rank = c.rank } else null;
        return rankstart.pick(current, s.before(key, day), day, rankstart.max_age_days);
    }

    /// The player's newest change before `day`
    fn before(s: *const Sightings, key: i64, day: i64) ?rankstart.Sighting {
        const keys = s.changes.items(.key);
        const days = s.changes.items(.day);
        var lo: usize = 0;
        var hi: usize = keys.len;
        while (lo < hi) {
            const mid = lo + (hi - lo) / 2;
            const below = keys[mid] < key or (keys[mid] == key and days[mid] < day);
            if (below) lo = mid + 1 else hi = mid;
        }
        if (lo == 0 or keys[lo - 1] != key) return null;
        return .{ .day = days[lo - 1], .rank = s.changes.items(.rank)[lo - 1] };
    }
};

/// Matches from rankstart.first_day, sorted by id as participants' key is
const Games = struct {
    const Game = struct { off: u32, len: u8, day: u16 };

    ids: std.ArrayList(u8) = .empty,
    list: std.ArrayList(Game) = .empty,

    fn load(gpa: std.mem.Allocator, db: store.Db) !Games {
        var g: Games = .{};
        errdefer g.deinit(gpa);
        // The whole table front to back: matches_start would fetch each row on its own
        var q = try db.prepare(
            "SELECT match_id, game_start FROM matches NOT INDEXED WHERE game_start >= ?",
        );
        defer q.deinit();
        try q.bind(.{rankstart.first_day * std.time.ms_per_day});
        while (try q.step()) {
            const match_id = q.bytes(0);
            try g.list.append(gpa, .{
                .off = @intCast(g.ids.items.len),
                .len = @intCast(match_id.len),
                .day = @intCast(@divFloor(q.int(1), std.time.ms_per_day)),
            });
            try g.ids.appendSlice(gpa, match_id);
        }
        std.mem.sortUnstable(Game, g.list.items, &g, lessThan);
        return g;
    }

    fn deinit(g: *Games, gpa: std.mem.Allocator) void {
        g.ids.deinit(gpa);
        g.list.deinit(gpa);
    }

    fn idOf(g: *const Games, game: Game) []const u8 {
        return g.ids.items[game.off..][0..game.len];
    }

    fn id(g: *const Games, i: usize) []const u8 {
        return g.idOf(g.list.items[i]);
    }

    // SQLite's BINARY collation: bytes, then the shorter first
    fn lessThan(g: *const Games, a: Game, b: Game) bool {
        return std.mem.order(u8, g.idOf(a), g.idOf(b)) == .lt;
    }

    /// Index of the first game after `match_id`
    fn firstAfter(g: *const Games, match_id: []const u8) usize {
        var lo: usize = 0;
        var hi: usize = g.list.items.len;
        while (lo < hi) {
            const mid = lo + (hi - lo) / 2;
            if (std.mem.order(u8, g.id(mid), match_id) == .gt) hi = mid else lo = mid + 1;
        }
        return lo;
    }
};

const Fill = struct {
    const Update = struct { game: u32, slot: u8, rank: u8 };

    gpa: std.mem.Allocator,
    db: store.Db,
    sightings: *const Sightings,
    games: *const Games,
    seats: store.Stmt,
    set: store.Stmt,
    updates: std.ArrayList(Update) = .empty,

    fn init(gpa: std.mem.Allocator, db: store.Db, s: *const Sightings, g: *const Games) !Fill {
        var seats = try db.prepare(
            \\SELECT match_id, slot, puuid FROM participants
            \\WHERE match_id >= ?1 AND match_id <= ?2 AND rank_start IS NULL AND puuid IS NOT NULL
            \\ORDER BY match_id, slot
        );
        errdefer seats.deinit();
        // A seat the crawler's writer filled since the read keeps its answer (it may
        // know a sighting the history doesn't)
        const set = try db.prepare(
            "UPDATE participants SET rank_start = ?1 WHERE match_id = ?2 AND slot = ?3 AND rank_start IS NULL",
        );
        return .{ .gpa = gpa, .db = db, .sightings = s, .games = g, .seats = seats, .set = set };
    }

    fn deinit(f: *Fill) void {
        f.seats.deinit();
        f.set.deinit();
        f.updates.deinit(f.gpa);
    }

    /// The empty seats of games[from..to] into `updates`, with no lock held; the count
    /// read. The id range also holds older games and ones stored since the list was
    /// read: skipped
    fn read(f: *Fill, from: usize, to: usize) !usize {
        f.updates.clearRetainingCapacity();
        try f.seats.bind(.{ f.games.id(from), f.games.id(to - 1) });
        // Ends the read snapshot: one left open pins the WAL
        defer f.seats.reset();
        var g = from;
        var n: usize = 0;
        while (try f.seats.step()) {
            const match_id = f.seats.bytes(0);
            while (g < to and std.mem.order(u8, f.games.id(g), match_id) == .lt) g += 1;
            if (g == to or !std.mem.eql(u8, f.games.id(g), match_id)) continue;
            n += 1;
            const key = store.schema.puuidKey(f.seats.bytes(2));
            const rank = f.sightings.rankStart(key, f.games.list.items[g].day) orelse continue;
            try f.updates.append(f.gpa, .{
                .game = @intCast(g),
                .slot = @intCast(f.seats.int(1)),
                .rank = @intCast(rank),
            });
        }
        return n;
    }

    /// One short transaction (the pages are warm from the read); the ms it held the
    /// write lock
    fn write(f: *Fill, io: std.Io) !i64 {
        if (f.updates.items.len == 0) return 0;
        try f.db.begin();
        errdefer f.db.rollback();
        const held = nowMs(io);
        for (f.updates.items) |u| try f.set.exec(.{ u.rank, f.games.id(u.game), u.slot });
        try f.db.commit();
        return nowMs(io) - held;
    }
};

/// Resumable with --after; seats already filled are skipped anyway
pub fn cmdRankBackfill(c: *Cmd) !u8 {
    var chunk: usize = 500;
    var pause_ms: i64 = 500;
    var wal_mb: u64 = 1024;
    var after: ?[]const u8 = null;
    var max_games: usize = std.math.maxInt(usize);
    while (c.next()) |_| {
        if (c.is("--chunk")) {
            chunk = try c.int(usize);
            if (chunk == 0) return error.Usage;
        } else if (c.is("--pause-ms")) {
            pause_ms = try c.int(u32);
        } else if (c.is("--wal-mb")) {
            wal_mb = try c.int(u32);
        } else if (c.is("--after")) {
            after = try c.value();
        } else if (c.is("--games")) {
            max_games = try c.int(usize);
        } else return error.Usage;
    }
    const io = c.init.io;
    const gpa = c.init.gpa;
    const db = try c.open();
    defer db.close();
    const start = nowMs(io);
    var sightings: Sightings = try .load(gpa, db);
    defer sightings.deinit(gpa);
    var games: Games = try .load(gpa, db);
    defer games.deinit(gpa);
    std.log.info("{d} ranks, {d} rank changes, {d} games from 2026-10-13, read in {d} s", .{
        sightings.current.count(),
        sightings.changes.len,
        games.list.items.len,
        @divTrunc(nowMs(io) - start, 1000),
    });
    var f: Fill = try .init(gpa, db, &sightings, &games);
    defer f.deinit();
    const wal_path = try c.arena.print("{s}/meiolol.db-wal", .{c.data_dir});

    const filling = nowMs(io);
    var from: usize = if (after) |match_id| games.firstAfter(match_id) else 0;
    const end = @min(games.list.items.len, from +| max_games);
    var t: struct {
        games: usize = 0,
        seats: usize = 0,
        known: usize = 0,
        chunks: usize = 0,
        busy: usize = 0,
        read_ms: i64 = 0,
        held_ms: i64 = 0,
        longest_held_ms: i64 = 0,
        wal_wait_s: usize = 0,
        wal_peak: u64 = 0,
    } = .{};
    while (from < end) {
        const to = @min(end, from + chunk);
        const t0 = nowMs(io);
        t.seats += try f.read(from, to);
        const t1 = nowMs(io);
        const held = while (true) {
            break f.write(io) catch |err| switch (err) {
                // The crawler's writer or a backup held the lock past the busy timeout
                error.Busy => {
                    t.busy += 1;
                    try io.sleep(.fromMilliseconds(pause_ms), .awake);
                    continue;
                },
                else => return err,
            };
        };
        const t2 = nowMs(io);
        t.games += to - from;
        t.known += f.updates.items.len;
        t.chunks += 1;
        t.read_ms += t1 - t0;
        t.held_ms += held;
        t.longest_held_ms = @max(t.longest_held_ms, held);
        from = to;
        if (t.chunks % 20 == 0 or from == end) {
            std.log.info("after {s}: {d} games, {d} seats read, {d} known", .{
                games.id(from - 1), t.games, t.seats, t.known,
            });
            std.log.info("  read {d} s, write lock {d} s, longest {d} ms, {d} busy", .{
                @divTrunc(t.read_ms, 1000), @divTrunc(t.held_ms, 1000), t.longest_held_ms, t.busy,
            });
            std.log.info("  WAL peak {d} MB, {d} s waiting for it", .{ t.wal_peak / (1024 * 1024), t.wal_wait_s });
        }
        if (from == end) break;
        // At most a third of the time is the backfill's: the crawler shares the disk
        try io.sleep(.fromMilliseconds(@max(pause_ms, 2 * (t2 - t0))), .awake);
        while (true) {
            const wal = walBytes(io, wal_path);
            t.wal_peak = @max(t.wal_peak, wal);
            if (wal <= wal_mb * 1024 * 1024) break;
            t.wal_wait_s += 1;
            try io.sleep(.fromMilliseconds(1000), .awake);
        }
    }
    const s = @max(1, @divTrunc(nowMs(io) - filling, 1000));
    std.log.info("done: {d} games in {d} s ({d} games/s)", .{ t.games, s, t.games / @as(usize, @intCast(s)) });
    return 0;
}

fn nowMs(io: std.Io) i64 {
    return std.Io.Clock.awake.now(io).toMilliseconds();
}

fn walBytes(io: std.Io, path: []const u8) u64 {
    const st = std.Io.Dir.cwd().statFile(io, path, .{}) catch return 0;
    return st.size;
}

const testing = std.testing;

test "rank-backfill: from first_day, empty seats only, as the point lookups" {
    const gpa = testing.allocator;
    const db = try store.schema.memory();
    defer db.close();
    const ms = std.time.ms_per_day;
    const first = rankstart.first_day;
    try db.run(
        \\INSERT INTO matches VALUES ('EUW1_95', 'riot', 'EUW1', 420, '16.20', '16.20.1', ?1, 1800, 100, 0),
        \\    ('EUW1_9', 'riot', 'EUW1', 420, '16.21', '16.21.1', ?2, 1800, 100, 0),
        \\    ('KR_5', 'riot', 'KR', 420, '16.21', '16.21.1', ?3, 1800, 100, 0)
    , .{ (first - 1) * ms, (first + 1) * ms + 5, (first + 5) * ms });
    for ([_][]const u8{ "EUW1_95", "EUW1_9", "KR_5" }) |match_id| try db.run(
        \\INSERT INTO participants (match_id, slot, team_id, puuid, champion_id, win)
        \\VALUES (?1, 0, 100, 'a', 1, 1), (?1, 1, 100, 'b', 2, 1), (?1, 2, 100, NULL, 3, 1),
        \\    (?1, 3, 100, 'c', 4, 1)
    , .{match_id});
    const key = store.schema.puuidKey;
    // a: seen two days before the first game. b: seen on its day only, a change before
    // it; another's rows around b's in the history. c: never seen
    try db.run("INSERT INTO ranks (key, rank, seen_day) VALUES (?, 20, ?), (?, 24, ?)", .{
        key("a"), first - 1, key("b"), first + 1,
    });
    try db.run("INSERT INTO rank_history VALUES (?1, ?3, 25, 0, 1, 1), (?1, ?4, 24, 0, 2, 1), (?2, ?3, 9, 0, 1, 1)", .{
        key("b"), key("b") +% 1, first, first + 1,
    });
    // The writer's own answer stays
    try db.exec("UPDATE participants SET rank_start = 3 WHERE match_id = 'KR_5' AND slot = 0");

    var sightings: Sightings = try .load(gpa, db);
    defer sightings.deinit(gpa);
    var games: Games = try .load(gpa, db);
    defer games.deinit(gpa);
    try testing.expectEqual(@as(usize, 2), games.list.items.len);
    try testing.expectEqualStrings("EUW1_9", games.id(0));
    try testing.expectEqual(@as(usize, 0), games.firstAfter("EUW1_8"));
    try testing.expectEqual(@as(usize, 1), games.firstAfter("EUW1_9"));
    try testing.expectEqual(@as(usize, 1), games.firstAfter("EUW1_95"));
    try testing.expectEqual(@as(usize, 2), games.firstAfter("KR_5"));
    var f: Fill = try .init(gpa, db, &sightings, &games);
    defer f.deinit();
    // EUW1_95 sorts inside the range and is from before first_day: not read
    try testing.expectEqual(@as(usize, 5), try f.read(0, 2));
    _ = try f.write(testing.io);
    var l: rankstart.Lookup = try .init(db);
    defer l.deinit();
    var q = try db.prepare(
        \\SELECT p.match_id, p.puuid, m.game_start / 86400000, p.rank_start
        \\FROM participants p JOIN matches m USING (match_id) ORDER BY p.match_id, p.slot
    );
    defer q.deinit();
    try q.bind(.{});
    var known: usize = 0;
    while (try q.step()) {
        const match_id = q.bytes(0);
        if (std.mem.eql(u8, match_id, "EUW1_95") or q.isNull(1)) {
            try testing.expectEqual(@as(?i64, null), q.optInt(3));
        } else if (std.mem.eql(u8, match_id, "KR_5") and std.mem.eql(u8, q.bytes(1), "a")) {
            try testing.expectEqual(@as(?i64, 3), q.optInt(3));
        } else {
            try testing.expectEqual(try l.rankStart(key(q.bytes(1)), q.int(2)), q.optInt(3));
            known += @intFromBool(!q.isNull(3));
        }
    }
    // EUW1_9: a 20, b 25 (its change before the game day). KR_5: b 24
    try testing.expectEqual(@as(usize, 3), known);
    try testing.expectEqual(@as(?i64, 25), try db.scalar("SELECT rank_start FROM participants WHERE match_id = 'EUW1_9' AND slot = 1", .{}));
    // Rerun: the unknown seats are read again, nothing changes
    try testing.expectEqual(@as(usize, 2), try f.read(0, 2));
    try testing.expectEqual(@as(usize, 0), f.updates.items.len);
}
