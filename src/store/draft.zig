//! Draft table, kept forever: one compact row per stored ranked game, for draft models
//! (synergy, good picks) that need millions of games pooled over patches, more than the
//! `--keep-days` window keeps. The prune never touches it.
//!
//! Nothing in a row leads back to a player: no PUUID, Riot ID or match id (the Riot API
//! turns a match id back into the ten players), and the game's day, not its start time.
//! So `meiolol forget` has nothing to find here (docs/data-safety.md).
//!
//! Dedupe without a key: the crawler's writer adds the row in the transaction that first
//! inserts the match. Matches stored before the table existed wait in draft_backfill
//! (their ids, transient) for `meiolol draft-backfill`; the prune keeps those matches
//! until it has run.

const std = @import("std");
const sqlite = @import("sqlite.zig");
const schema = @import("schema.zig");

/// platform: Riot's id (EUW1). day: unix day (UTC) of the game start. rank: median
/// ladder rank snapshot (schema.packRank, 0 = Challenger I) of the players with a known
/// one, NULL under 5 known; ranked: how many are known. picks: 10 x u16 LE, blue's five
/// then red's in participant order, champion id | (role + 1) << 13, role 0..4 in Riot
/// teamPosition order (core.Role), 0 when unknown. bans: 10 x u16 LE champion ids,
/// blue's then red's in pick turn order, 0 for none. minutes: game length in whole
/// minutes, at most 255 (last: added after the table went live, NULL in a few rows).
/// id: insertion order, so backups copy new rows by range and a restore keeps them
pub const ddl =
    \\CREATE TABLE IF NOT EXISTS drafts (
    \\    id INTEGER PRIMARY KEY,
    \\    platform TEXT NOT NULL,
    \\    queue INTEGER NOT NULL,
    \\    patch TEXT NOT NULL,
    \\    day INTEGER NOT NULL,
    \\    rank INTEGER,
    \\    ranked INTEGER NOT NULL,
    \\    blue_win INTEGER NOT NULL,
    \\    picks BLOB NOT NULL,
    \\    bans BLOB NOT NULL,
    \\    minutes INTEGER
    \\);
    \\CREATE TABLE IF NOT EXISTS draft_backfill (match_id TEXT PRIMARY KEY) WITHOUT ROWID;
    \\
;

/// Ranked solo and flex
pub const queues = [_]i64{ 420, 440 };

/// Riot teamPosition names in core.Role order
const positions = [_][]const u8{ "TOP", "JUNGLE", "MIDDLE", "BOTTOM", "UTILITY" };

/// Champion ids fit 13 bits (the highest is under 1000)
const role_shift = 13;
const max_champion = (1 << role_shift) - 1;

/// Fewer known ranks give no rank: as curves and the Daily Draft
const min_ranked = 5;

pub const Pick = struct { champion: u16, role: ?u3 };

pub const Draft = struct {
    /// Borrowed: valid until the next read
    platform: []const u8,
    queue: u16,
    /// Borrowed: valid until the next read
    patch: []const u8,
    day: i32,
    rank: ?u8,
    ranked: u8,
    blue_win: bool,
    /// Whole minutes, at most 255; null in rows from before the column
    minutes: ?u8,
    /// 0-4 blue, 5-9 red, each in participant order
    picks: [10]Pick,
    /// 0-4 blue's, 5-9 red's, in pick turn order; 0 for none
    bans: [10]u16,
};

pub fn encodePicks(picks: [10]Pick) [20]u8 {
    var out: [20]u8 = undefined;
    for (picks, 0..) |p, i| {
        const role: u16 = if (p.role) |r| @as(u16, r) + 1 else 0;
        std.mem.writeInt(u16, out[i * 2 ..][0..2], p.champion | role << role_shift, .little);
    }
    return out;
}

pub fn decodePicks(bytes: []const u8) error{BadDraft}![10]Pick {
    if (bytes.len != 20) return error.BadDraft;
    var picks: [10]Pick = undefined;
    for (&picks, 0..) |*p, i| {
        const v = std.mem.readInt(u16, bytes[i * 2 ..][0..2], .little);
        const role = v >> role_shift;
        if (role > positions.len) return error.BadDraft;
        p.* = .{ .champion = v & max_champion, .role = if (role == 0) null else @intCast(role - 1) };
    }
    return picks;
}

pub fn encodeBans(bans: [10]u16) [20]u8 {
    var out: [20]u8 = undefined;
    for (bans, 0..) |b, i| std.mem.writeInt(u16, out[i * 2 ..][0..2], b, .little);
    return out;
}

pub fn decodeBans(bytes: []const u8) error{BadDraft}![10]u16 {
    if (bytes.len != 20) return error.BadDraft;
    var bans: [10]u16 = undefined;
    for (&bans, 0..) |*b, i| b.* = std.mem.readInt(u16, bytes[i * 2 ..][0..2], .little);
    return bans;
}

/// Median of known packed ranks, the better of the middle two for an even count (as
/// curvesfile.medianRank); null under min_ranked. Sorts `ranks`
pub fn medianRank(ranks: []u8) ?u8 {
    if (ranks.len < min_ranked) return null;
    std.mem.sort(u8, ranks, {}, std.sort.asc(u8));
    return ranks[(ranks.len - 1) / 2];
}

/// Builds a match's row from matches, participants and bans, as the crawler leaves them
/// (ranks included). Statements prepared once: the writer calls it for every match
pub const Builder = struct {
    db: sqlite.Db,
    match: sqlite.Stmt,
    players: sqlite.Stmt,
    bans: sqlite.Stmt,
    insert: sqlite.Stmt,
    take: sqlite.Stmt,

    pub fn init(db: sqlite.Db) !Builder {
        var match = try db.prepare(
            \\SELECT platform, queue_id, patch, game_start, winning_team, remake, duration_s
            \\FROM matches WHERE match_id = ?
        );
        errdefer match.deinit();
        var players = try db.prepare(
            \\SELECT team_id, position, champion_id, tier, division
            \\FROM participants WHERE match_id = ? ORDER BY slot
        );
        errdefer players.deinit();
        var bans = try db.prepare(
            "SELECT team_id, champion_id FROM bans WHERE match_id = ? ORDER BY team_id, pick_turn",
        );
        errdefer bans.deinit();
        var insert = try db.prepare(
            \\INSERT INTO drafts (platform, queue, patch, day, rank, ranked, blue_win, picks, bans,
            \\    minutes) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        );
        errdefer insert.deinit();
        const take = try db.prepare("DELETE FROM draft_backfill WHERE match_id = ?");
        return .{ .db = db, .match = match, .players = players, .bans = bans, .insert = insert, .take = take };
    }

    pub fn deinit(b: *Builder) void {
        inline for (.{ &b.match, &b.players, &b.bans, &b.insert, &b.take }) |s| s.deinit();
    }

    /// Off the backfill list; true when it was there (its row is still owed)
    pub fn taken(b: *Builder, match_id: []const u8) !bool {
        try b.take.exec(.{match_id});
        return b.db.changes() > 0;
    }

    /// Add the match's row; false when it is not a complete ranked 5v5 game with a
    /// winner (or not stored)
    pub fn write(b: *Builder, match_id: []const u8) !bool {
        try b.match.bind(.{match_id});
        defer b.match.reset();
        if (!try b.match.step()) return false;
        const m = b.match.row(struct {
            platform: []const u8,
            queue: i64,
            patch: []const u8,
            game_start: i64,
            winner: ?i64,
            remake: i64,
            duration_s: i64,
        });
        if (std.mem.findScalar(i64, &queues, m.queue) == null) return false;
        if (m.remake != 0) return false;
        const winner = m.winner orelse return false;
        if (winner != 100 and winner != 200) return false;

        var picks: [10]Pick = undefined;
        var per_team = [2]usize{ 0, 0 };
        var ranks: [10]u8 = undefined;
        var ranked: usize = 0;
        try b.players.bind(.{match_id});
        defer b.players.reset();
        while (try b.players.step()) {
            const p = b.players.row(struct {
                team: i64,
                position: ?[]const u8,
                champion: i64,
                tier: ?[]const u8,
                division: ?[]const u8,
            });
            const t = team(p.team) orelse return false;
            if (per_team[t] == 5) return false;
            if (p.champion <= 0 or p.champion > max_champion) return false;
            const role: ?u3 = for (positions, 0..) |name, i| {
                if (std.mem.eql(u8, name, p.position orelse break null)) break @intCast(i);
            } else null;
            picks[t * 5 + per_team[t]] = .{ .champion = @intCast(p.champion), .role = role };
            per_team[t] += 1;
            const tier = p.tier orelse continue;
            const division = p.division orelse continue;
            if (schema.packRank(tier, division)) |r| {
                ranks[ranked] = @intCast(r);
                ranked += 1;
            }
        }
        if (per_team[0] != 5 or per_team[1] != 5) return false;

        var bans: [10]u16 = @splat(0);
        var bans_per_team = [2]usize{ 0, 0 };
        try b.bans.bind(.{match_id});
        defer b.bans.reset();
        while (try b.bans.step()) {
            const ban = b.bans.row(struct { team: i64, champion: i64 });
            const t = team(ban.team) orelse continue;
            if (bans_per_team[t] == 5 or ban.champion <= 0) continue;
            if (ban.champion > std.math.maxInt(u16)) continue;
            bans[t * 5 + bans_per_team[t]] = @intCast(ban.champion);
            bans_per_team[t] += 1;
        }

        const pick_bytes = encodePicks(picks);
        const ban_bytes = encodeBans(bans);
        try b.insert.exec(.{
            m.platform,
            m.queue,
            m.patch,
            @divFloor(m.game_start, std.time.ms_per_day),
            medianRank(ranks[0..ranked]),
            ranked,
            winner == 100,
            sqlite.Blob{ .bytes = &pick_bytes },
            sqlite.Blob{ .bytes = &ban_bytes },
            @min(@divTrunc(@max(m.duration_s, 0), 60), 255),
        });
        return true;
    }

    fn team(id: i64) ?usize {
        return switch (id) {
            100 => 0,
            200 => 1,
            else => null,
        };
    }
};

pub const Chunk = struct { taken: usize, written: usize };

/// Up to `n` matches off the backfill list into drafts, in one transaction. Short, so
/// the crawler's writer gets the lock between chunks
pub fn backfillChunk(gpa: std.mem.Allocator, db: sqlite.Db, b: *Builder, n: usize) !Chunk {
    var ids: std.ArrayList([]u8) = .empty;
    defer {
        for (ids.items) |id| gpa.free(id);
        ids.deinit(gpa);
    }
    try db.begin();
    errdefer db.rollback();
    {
        var q = try db.prepare("SELECT match_id FROM draft_backfill LIMIT ?");
        defer q.deinit();
        try q.bind(.{n});
        while (try q.step()) {
            const id = try gpa.dupe(u8, q.bytes(0));
            errdefer gpa.free(id);
            try ids.append(gpa, id);
        }
    }
    var c: Chunk = .{ .taken = ids.items.len, .written = 0 };
    for (ids.items) |id| {
        _ = try b.taken(id);
        if (try b.write(id)) c.written += 1;
    }
    try db.commit();
    return c;
}

pub const Filter = struct {
    /// null: every patch
    patches: ?[]const []const u8 = null,
    /// null: every platform
    platforms: ?[]const []const u8 = null,
    /// Games from this unix day on
    since_day: i64 = 0,
    queue: i64 = 420,
};

/// Rows in insertion order. For stats and eval once they move off matches/participants
pub const Reader = struct {
    gpa: std.mem.Allocator,
    q: sqlite.Stmt,
    patch_json: ?[]u8,
    platform_json: ?[]u8,

    pub fn init(gpa: std.mem.Allocator, db: sqlite.Db, f: Filter) !Reader {
        const patch_json = if (f.patches) |p| try std.json.Stringify.valueAlloc(gpa, p, .{}) else null;
        errdefer if (patch_json) |j| gpa.free(j);
        const platform_json = if (f.platforms) |p| try std.json.Stringify.valueAlloc(gpa, p, .{}) else null;
        errdefer if (platform_json) |j| gpa.free(j);
        var q = try db.prepare(
            \\SELECT platform, queue, patch, day, rank, ranked, blue_win, picks, bans, minutes
            \\FROM drafts
            \\WHERE (?1 IS NULL OR patch IN (SELECT value FROM json_each(?1)))
            \\  AND (?2 IS NULL OR platform IN (SELECT value FROM json_each(?2)))
            \\  AND day >= ?3 AND queue = ?4
            \\ORDER BY id
        );
        errdefer q.deinit();
        try q.bind(.{ patch_json, platform_json, f.since_day, f.queue });
        return .{ .gpa = gpa, .q = q, .patch_json = patch_json, .platform_json = platform_json };
    }

    pub fn deinit(r: *Reader) void {
        r.q.deinit();
        if (r.patch_json) |j| r.gpa.free(j);
        if (r.platform_json) |j| r.gpa.free(j);
    }

    pub fn next(r: *Reader) !?Draft {
        if (!try r.q.step()) return null;
        const d = r.q.row(struct {
            platform: []const u8,
            queue: u16,
            patch: []const u8,
            day: i32,
            rank: ?u8,
            ranked: u8,
            blue_win: bool,
            picks: []const u8,
            bans: []const u8,
            minutes: ?u8,
        });
        return .{
            .platform = d.platform,
            .queue = d.queue,
            .patch = d.patch,
            .day = d.day,
            .rank = d.rank,
            .ranked = d.ranked,
            .blue_win = d.blue_win,
            .minutes = d.minutes,
            .picks = try decodePicks(d.picks),
            .bans = try decodeBans(d.bans),
        };
    }
};

const testing = std.testing;

/// Fixture match: blue wins; slot 5 has no position, slot 9 no rank
fn fixture(db: sqlite.Db, id: []const u8) !void {
    try db.run("INSERT INTO matches VALUES (?1, 'riot', 'EUW1', 420, '16.20', '16.20.1', " ++
        "1760000000000, 1800, 100, 0)", .{id});
    const tiers = [_]?[]const u8{
        "GOLD", "GOLD", "PLATINUM", "SILVER",  "EMERALD",
        "GOLD", "GOLD", "PLATINUM", "DIAMOND", null,
    };
    for (0..10) |slot| {
        const pos: ?[]const u8 = if (slot == 5) null else positions[slot % 5];
        try db.run(
            \\INSERT INTO participants (match_id, slot, team_id, puuid, champion_id, position, win,
            \\    tier, division) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'II')
        , .{ id, slot, if (slot < 5) @as(i64, 100) else 200, "puuid", 100 + slot, pos, slot < 5, tiers[slot] });
    }
    try db.run("INSERT INTO bans VALUES (?1, 100, 2, 55), (?1, 100, 1, 54), (?1, 200, 6, 66)", .{id});
}

test "a match's row: teams, roles, bans, median rank; nothing else" {
    const db = try schema.memory();
    defer db.close();
    var b: Builder = try .init(db);
    defer b.deinit();
    try fixture(db, "EUW1_1");
    try testing.expect(try b.write("EUW1_1"));
    try testing.expect(!try b.write("EUW1_404"));

    var r: Reader = try .init(testing.allocator, db, .{ .platforms = &.{"EUW1"}, .patches = &.{"16.20"} });
    defer r.deinit();
    const d = (try r.next()).?;
    try testing.expectEqualStrings("EUW1", d.platform);
    try testing.expectEqualStrings("16.20", d.patch);
    try testing.expectEqual(@as(i32, 20370), d.day);
    try testing.expect(d.blue_win);
    try testing.expectEqual(@as(u8, 9), d.ranked);
    // Known, best first: D2 E2 P2 P2 G2 G2 G2 G2 S2; the fifth is Gold II
    try testing.expectEqual(schema.packRank("GOLD", "II").?, d.rank.?);
    try testing.expectEqual(Pick{ .champion = 100, .role = 0 }, d.picks[0]);
    try testing.expectEqual(Pick{ .champion = 105, .role = null }, d.picks[5]);
    try testing.expectEqual(Pick{ .champion = 109, .role = 4 }, d.picks[9]);
    try testing.expectEqualSlices(u16, &.{ 54, 55, 0, 0, 0, 66, 0, 0, 0, 0 }, &d.bans);
    try testing.expectEqual(@as(?u8, 30), d.minutes);
    try testing.expectEqual(null, try r.next());

    // Length caps at 255 minutes (one byte)
    try db.exec("UPDATE matches SET duration_s = 99999");
    try testing.expect(try b.write("EUW1_1"));
    try testing.expectEqual(@as(?i64, 255), try db.scalar("SELECT max(minutes) FROM drafts", .{}));

    var none: Reader = try .init(testing.allocator, db, .{ .platforms = &.{"KR"} });
    defer none.deinit();
    try testing.expectEqual(null, try none.next());

    // No column holds an identifier: the table's columns are exactly these
    var cols = try db.prepare("SELECT group_concat(name) FROM pragma_table_info('drafts')");
    defer cols.deinit();
    try testing.expect(try cols.step());
    const want = "id,platform,queue,patch,day,rank,ranked,blue_win,picks,bans,minutes";
    try testing.expectEqualStrings(want, cols.bytes(0));
}

test "remakes, no winner, other queues and short teams give no row" {
    const db = try schema.memory();
    defer db.close();
    var b: Builder = try .init(db);
    defer b.deinit();
    for ([_][]const u8{ "A", "B", "C", "D" }) |id| try fixture(db, id);
    try db.exec(
        \\UPDATE matches SET remake = 1 WHERE match_id = 'A';
        \\UPDATE matches SET winning_team = NULL WHERE match_id = 'B';
        \\UPDATE matches SET queue_id = 450 WHERE match_id = 'C';
        \\DELETE FROM participants WHERE match_id = 'D' AND slot = 9;
    );
    for ([_][]const u8{ "A", "B", "C", "D" }) |id| try testing.expect(!try b.write(id));
    try testing.expectEqual(@as(?i64, 0), try db.scalar("SELECT count(*) FROM drafts", .{}));
}

test "median rank needs five known" {
    var four = [_]u8{ 1, 2, 3, 4 };
    try testing.expectEqual(null, medianRank(&four));
    var six = [_]u8{ 30, 1, 20, 2, 10, 3 };
    try testing.expectEqual(@as(?u8, 3), medianRank(&six));
}

test "picks round trip" {
    var picks: [10]Pick = undefined;
    for (&picks, 0..) |*p, i| {
        p.* = .{ .champion = @intCast(900 + i), .role = if (i == 3) null else @intCast(i % 5) };
    }
    try testing.expectEqualDeep(picks, try decodePicks(&encodePicks(picks)));
    try testing.expectError(error.BadDraft, decodePicks("short"));
}

test "backfill: listed matches only, in chunks" {
    const gpa = testing.allocator;
    const db = try schema.memory();
    defer db.close();
    var b: Builder = try .init(db);
    defer b.deinit();
    for ([_][]const u8{ "A", "B", "C" }) |id| try fixture(db, id);
    try db.exec("INSERT INTO draft_backfill VALUES ('A'), ('B'), ('gone')");
    try testing.expectEqual(Chunk{ .taken = 2, .written = 2 }, try backfillChunk(gpa, db, &b, 2));
    try testing.expectEqual(Chunk{ .taken = 1, .written = 0 }, try backfillChunk(gpa, db, &b, 2));
    try testing.expectEqual(Chunk{ .taken = 0, .written = 0 }, try backfillChunk(gpa, db, &b, 2));
    try testing.expectEqual(@as(?i64, 2), try db.scalar("SELECT count(*) FROM drafts", .{}));
}

test "bytes per row" {
    // A table of drafts alone, as many rows of realistic values: page bytes per row
    const db = try sqlite.Db.open(":memory:");
    defer db.close();
    try db.exec(ddl);
    var ins = try db.prepare(
        \\INSERT INTO drafts (platform, queue, patch, day, rank, ranked, blue_win, picks, bans,
        \\    minutes) VALUES ('EUW1', 420, '16.20', ?, ?, 10, ?, ?, ?, ?)
    );
    defer ins.deinit();
    var prng: std.Random.DefaultPrng = .init(1);
    const rand = prng.random();
    const n = 20_000;
    for (0..n) |i| {
        var picks: [10]Pick = undefined;
        for (&picks, 0..) |*p, s| p.* = .{ .champion = rand.intRangeAtMost(u16, 1, 950), .role = @intCast(s % 5) };
        var bans: [10]u16 = undefined;
        for (&bans) |*x| x.* = rand.intRangeAtMost(u16, 1, 950);
        const pb = encodePicks(picks);
        const bb = encodeBans(bans);
        try ins.exec(.{
            20370 + i / 5000,            rand.intRangeAtMost(u8, 8, 30), rand.boolean(),
            sqlite.Blob{ .bytes = &pb }, sqlite.Blob{ .bytes = &bb },    rand.intRangeAtMost(u8, 15, 45),
        });
    }
    const pages = (try db.scalar("PRAGMA page_count", .{})).?;
    const page_size = (try db.scalar("PRAGMA page_size", .{})).?;
    const per_row = @divTrunc(pages * page_size, n);
    // 74 when measured (2026-10-11): 10M games ~0.7 GB
    try testing.expect(per_row >= 40 and per_row <= 80);
}
