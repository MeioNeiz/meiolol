//! Rank at game time (participants.rank_start, drafts.rank_start): a seat's ladder rank
//! as last seen on a UTC day before the game's. The stored tier is the rank when the
//! match was stored, after the game, so it knows the result (docs/learned.md).
//!
//! Sightings: ranks when its seen_day is before the game day (the player's newest), else
//! rank_history's newest change before it (a row per day the ladder showed a change,
//! from 2026-10-12). A sighting on the game's own day may follow the game, so it never
//! counts. Over max_age_days older than the game day: unknown, which catches players who
//! fell below the ladder walk (Platinum) and the 11 Oct walk's lower tiers. Change days
//! only overstate the age for a player seen daily without a change, so a game stored on
//! its own day (ranks seen yesterday) can be known where the backfill later says unknown

const std = @import("std");
const sqlite = @import("sqlite.zig");
const schema = @import("schema.zig");

pub const max_age_days = 7;

/// 2026-10-13: the first game day with rank_history (from 12 Oct) before it
pub const first_day = 20739;

pub const Sighting = struct { day: i64, rank: i64 };

/// The packed rank (schema.packRank) the game's seat had, or null. `current`: the
/// player's ranks row; `before`: their newest rank_history row before `day`; max_age
/// null for no cap (the lab's rank_start)
pub fn pick(current: ?Sighting, before: ?Sighting, day: i64, max_age: ?i64) ?i64 {
    const s = if (current) |c| (if (c.day < day) c else before) else before;
    const seen = s orelse return null;
    if (max_age) |m| if (day - seen.day > m) return null;
    return seen.rank;
}

/// Point lookups for one seat at a time (writer, backfill)
pub const Lookup = struct {
    current: sqlite.Stmt,
    history: sqlite.Stmt,

    pub fn init(db: sqlite.Db) !Lookup {
        var current = try db.prepare("SELECT seen_day, rank FROM ranks WHERE key = ?");
        errdefer current.deinit();
        const history = try db.prepare(
            "SELECT day, rank FROM rank_history WHERE key = ?1 AND day < ?2 ORDER BY day DESC LIMIT 1",
        );
        return .{ .current = current, .history = history };
    }

    pub fn deinit(l: *Lookup) void {
        l.current.deinit();
        l.history.deinit();
    }

    pub fn rankStart(l: *Lookup, key: i64, day: i64) !?i64 {
        try l.current.bind(.{key});
        defer l.current.reset();
        const current: ?Sighting = if (try l.current.step()) .{ .day = l.current.int(0), .rank = l.current.int(1) } else null;
        return l.after(current, key, day);
    }

    /// For a caller that read the ranks row already
    pub fn after(l: *Lookup, current: ?Sighting, key: i64, day: i64) !?i64 {
        if (current) |c| if (c.day < day) return pick(c, null, day, max_age_days);
        try l.history.bind(.{ key, day });
        defer l.history.reset();
        const before: ?Sighting = if (try l.history.step()) .{ .day = l.history.int(0), .rank = l.history.int(1) } else null;
        return pick(current, before, day, max_age_days);
    }
};

pub const Chunk = struct {
    /// Last match rowid read; the next chunk starts after it
    last: i64,
    games: usize,
    seats: usize,
    known: usize,
};

/// rank_start for up to `n` matches after rowid `after` whose game day is first_day or
/// later, in one short transaction (the crawler's writer gets the lock between chunks).
/// Fills only seats still NULL: rerunning changes nothing, and a writer's answer (which
/// may know a sighting the history doesn't) stays. Matches stored before the column
/// waited for this; new ones the writer fills
pub fn backfillChunk(db: sqlite.Db, l: *Lookup, after_rowid: i64, n: usize) !Chunk {
    var games = try db.prepare(
        \\SELECT rowid, match_id, game_start FROM matches
        \\WHERE rowid > ?1 AND game_start >= ?2 ORDER BY rowid LIMIT ?3
    );
    defer games.deinit();
    var seats = try db.prepare(
        "SELECT slot, puuid FROM participants WHERE match_id = ? AND rank_start IS NULL AND puuid IS NOT NULL",
    );
    defer seats.deinit();
    var set = try db.prepare("UPDATE participants SET rank_start = ? WHERE match_id = ? AND slot = ?");
    defer set.deinit();
    try db.begin();
    errdefer db.rollback();
    var c: Chunk = .{ .last = after_rowid, .games = 0, .seats = 0, .known = 0 };
    try games.bind(.{ after_rowid, first_day * std.time.ms_per_day, n });
    while (try games.step()) {
        c.last = games.int(0);
        c.games += 1;
        const id = games.bytes(1);
        const day = @divFloor(games.int(2), std.time.ms_per_day);
        try seats.bind(.{id});
        defer seats.reset();
        while (try seats.step()) {
            c.seats += 1;
            const key = schema.puuidKey(seats.bytes(1));
            const start = try l.rankStart(key, day) orelse continue;
            try set.exec(.{ start, id, seats.int(0) });
            c.known += 1;
        }
    }
    try db.commit();
    return c;
}

const testing = std.testing;

test "pick: before the game day only, newest first, capped" {
    const day = 100;
    // ranks seen the day before: it wins over older history
    try testing.expectEqual(@as(?i64, 5), pick(.{ .day = 99, .rank = 5 }, .{ .day = 90, .rank = 9 }, day, 7));
    // seen on the game day (maybe after the game): history instead
    try testing.expectEqual(@as(?i64, 9), pick(.{ .day = 100, .rank = 5 }, .{ .day = 95, .rank = 9 }, day, 7));
    try testing.expectEqual(@as(?i64, 9), pick(.{ .day = 103, .rank = 5 }, .{ .day = 93, .rank = 9 }, day, 7));
    // 8 days old: unknown with the cap, known without
    try testing.expectEqual(@as(?i64, null), pick(.{ .day = 92, .rank = 5 }, null, day, 7));
    try testing.expectEqual(@as(?i64, 5), pick(.{ .day = 92, .rank = 5 }, null, day, null));
    try testing.expectEqual(@as(?i64, null), pick(.{ .day = 101, .rank = 5 }, null, day, 7));
    try testing.expectEqual(@as(?i64, null), pick(null, null, day, null));
    try testing.expectEqual(@as(?i64, 3), pick(null, .{ .day = 99, .rank = 3 }, day, 7));
}

test "Lookup reads ranks and rank_history" {
    const db = try schema.memory();
    defer db.close();
    try db.exec(
        \\INSERT INTO ranks (key, rank, seen_day) VALUES (1, 20, 99), (2, 20, 100), (3, 20, 100);
        \\INSERT INTO rank_history VALUES (2, 95, 24, 0, 1, 1), (2, 100, 20, 0, 2, 1),
        \\    (3, 80, 24, 0, 1, 1);
    );
    var l: Lookup = try .init(db);
    defer l.deinit();
    try testing.expectEqual(@as(?i64, 20), try l.rankStart(1, 100));
    try testing.expectEqual(@as(?i64, 24), try l.rankStart(2, 100));
    try testing.expectEqual(@as(?i64, null), try l.rankStart(3, 100));
    try testing.expectEqual(@as(?i64, null), try l.rankStart(4, 100));
}

test "backfillChunk: from first_day, NULL seats only, rerun changes nothing" {
    const db = try schema.memory();
    defer db.close();
    const ms = std.time.ms_per_day;
    try db.run(
        \\INSERT INTO matches VALUES ('EUW1_old', 'riot', 'EUW1', 420, '16.20', '16.20.1', ?1, 1800, 100, 0),
        \\    ('EUW1_new', 'riot', 'EUW1', 420, '16.21', '16.21.1', ?2, 1800, 100, 0)
    , .{ (first_day - 1) * ms, (first_day + 1) * ms + 5 });
    for ([_][]const u8{ "EUW1_old", "EUW1_new" }) |id| try db.run(
        \\INSERT INTO participants (match_id, slot, team_id, puuid, champion_id, win)
        \\VALUES (?1, 0, 100, 'a', 1, 1), (?1, 1, 100, 'b', 2, 1), (?1, 2, 100, NULL, 3, 1)
    , .{id});
    try db.run("INSERT INTO ranks (key, rank, seen_day) VALUES (?, 20, ?), (?, 24, ?)", .{
        // b seen on the game day only: unknown
        schema.puuidKey("a"), first_day - 2, schema.puuidKey("b"), first_day + 1,
    });
    var l: Lookup = try .init(db);
    defer l.deinit();
    const c = try backfillChunk(db, &l, 0, 1000);
    try testing.expectEqual(@as(usize, 1), c.games);
    try testing.expectEqual(@as(usize, 2), c.seats);
    try testing.expectEqual(@as(usize, 1), c.known);
    try testing.expectEqual(@as(?i64, 20), try db.scalar("SELECT rank_start FROM participants WHERE match_id = 'EUW1_new' AND slot = 0", .{}));
    try testing.expectEqual(@as(?i64, 0), try db.scalar("SELECT count(rank_start) FROM participants WHERE match_id = 'EUW1_old'", .{}));
    // Rerun from the start: the known seat is not read again, nothing changes
    const again = try backfillChunk(db, &l, 0, 1000);
    try testing.expectEqual(@as(usize, 1), again.seats);
    try testing.expectEqual(@as(usize, 0), again.known);
    try testing.expectEqual(@as(?i64, 1), try db.scalar("SELECT count(rank_start) FROM participants", .{}));
    // Past the last rowid: empty
    try testing.expectEqual(@as(usize, 0), (try backfillChunk(db, &l, again.last, 1000)).games);
}
