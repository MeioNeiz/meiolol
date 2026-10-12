//! `meiolol status`: row counts and crawl queue state. Read-only and cheap by default,
//! so it runs on the box beside the crawler: the big tables get estimates (marked ~),
//! everything else exact counts over small indexes. --exact counts every row.

const std = @import("std");
const store = @import("store");
const ep = @import("riot/endpoints.zig");

const Count = struct {
    n: i64,
    estimate: bool = false,

    pub fn format(c: Count, w: *std.Io.Writer) std.Io.Writer.Error!void {
        try w.print("{s}{d}", .{ if (c.estimate) "~" else "", c.n });
    }
};

const Group = struct { label: []const u8, n: Count };

/// PUUIDs are uniform over 64 base64url characters (checked on the box, 2026-10-12: each
/// first character within 0.5% of 1/64), so the 4 from A to D are a 1/16 sample that
/// reads 1/16 of the players b-tree. GROUP BY the bare column: the exact count then
/// walks players_region_check instead of sorting 9M rows
const puuid_sample = "puuid >= 'A' AND puuid < 'E'";
const puuid_scale = 16;

/// ranks and rank_history keys are Wyhash(PUUID), uniform over i64, so keys from 0 to
/// 2^58 are a 1/64 sample read off the primary key
const key_sample = "key >= 0 AND key < 288230376151711744";
const key_scale = 64;

pub const Options = struct {
    exact: bool = false,
    /// Fewer sampled players than this: count them all, it's cheap (and PUUIDs that
    /// aren't Riot's, like the snapshot's p1, p2, ..., miss the sample)
    min_sample: i64 = 1000,
};

pub fn write(arena: std.mem.Allocator, db: store.Db, out: *std.Io.Writer, o: Options) !void {
    const exact = o.exact;
    var players = try groups(arena, db, "SELECT coalesce(region, '?'), count(*) FROM players WHERE " ++
        puuid_sample ++ " GROUP BY region ORDER BY 2 DESC", puuid_scale);
    if (exact or sum(players).n < o.min_sample * puuid_scale) {
        players = try groups(arena, db, "SELECT coalesce(region, '?'), count(*) FROM players GROUP BY region ORDER BY 2 DESC", 1);
    }
    const match_queue = try groups(arena, db, "SELECT region || ' ' || status, count(*) FROM match_queue GROUP BY 1 ORDER BY 1", 1);
    const timeline_queue = try groups(arena, db, "SELECT region || ' ' || status, count(*) FROM timeline_queue GROUP BY 1 ORDER BY 1", 1);
    const ranks = sum(try byKey(arena, db, "SELECT '', count(*) FROM ranks", "", o));
    const history = sum(try byKey(arena, db, "SELECT '', count(*) FROM rank_history", "", o));
    // No day index: the newest days from the same sample, sorted in memory
    const history_days = try byKey(arena, db, "SELECT date(day * 86400, 'unixepoch'), count(*) FROM rank_history", " GROUP BY day ORDER BY day DESC LIMIT 3", o);
    const by_patch = try groups(arena, db, "SELECT patch, count(*) FROM matches GROUP BY 1 ORDER BY 1 DESC", 1);
    const matches = sum(by_patch);

    try out.print("players: {f}\n", .{sum(players)});
    try out.print("ladder_pages: {f}\n", .{try count(db, "ladder_pages")});
    try out.print("ranks: {f}\n", .{ranks});
    try out.print("rank_history: {f}\n", .{history});
    try out.print("match_queue: {f}\n", .{sum(match_queue)});
    try out.print("matches: {f}\n", .{matches});
    // Every stored match has its 10 participants: the writer and prune keep them together
    try out.print("participants: {f}\n", .{if (exact)
        try count(db, "participants")
    else
        Count{ .n = matches.n * 10, .estimate = true }});
    if (exact) try out.print("bans: {f}\n", .{try count(db, "bans")});
    inline for (.{ "mastery", "champions", "raw.raw_docs" }) |t| {
        try out.print(t ++ ": {f}\n", .{try count(db, t)});
    }
    try out.print("timeline_queue: {f}\n", .{sum(timeline_queue)});
    // Rowid tables with no index to count over (timelines: KBs of blob a row, so few
    // rows a page). Ids are appended, so the range is the count less any deleted rows
    try out.print("timeline.timelines: {f}\n", .{try rowidRange(db, "timeline.timelines", exact)});
    try out.print("raw.timeline_docs: {f}\n", .{try count(db, "raw.timeline_docs")});
    try out.print("drafts: {f}\n", .{try rowidRange(db, "drafts", exact)});
    try out.print("draft_backfill: {f}\n", .{try count(db, "draft_backfill")});

    try print(out, "queue:", match_queue);
    try print(out, "\nby patch:", by_patch[0..@min(by_patch.len, 6)]);
    try print(out, "\nby platform:", try byPlatform(arena, db));
    try print(out, "\ntimelines:", timeline_queue);
    try print(out, "\nplayers:", players);
    try print(out, "\nrank_history by day:", history_days);
    try out.writeAll("\n");
    if (!exact) try out.writeAll("~ estimate: players from 1/16 of PUUIDs, ranks and " ++
        "rank_history from 1/64 of keys, participants 10 per match, timelines and drafts " ++
        "from the rowid range; --exact counts every row\n");
}

fn count(db: store.Db, comptime table: []const u8) !Count {
    return .{ .n = try db.scalar("SELECT count(*) FROM " ++ table, .{}) orelse 0 };
}

fn rowidRange(db: store.Db, comptime table: []const u8, exact: bool) !Count {
    if (exact) return count(db, table);
    // Two subqueries: min and max in one select would scan the table
    const n = try db.scalar("SELECT coalesce((SELECT max(rowid) FROM " ++ table ++
        ") - (SELECT min(rowid) FROM " ++ table ++ ") + 1, 0)", .{});
    return .{ .n = n orelse 0, .estimate = true };
}

/// `select` ++ `rest` over the key sample, or every row when exact or the sample is small
fn byKey(arena: std.mem.Allocator, db: store.Db, comptime select: []const u8, comptime rest: []const u8, o: Options) ![]Group {
    if (!o.exact) {
        const gs = try groups(arena, db, select ++ " WHERE " ++ key_sample ++ rest, key_scale);
        if (sum(gs).n >= o.min_sample * key_scale) return gs;
    }
    return groups(arena, db, select ++ rest, 1);
}

/// Rows of (label, count), counts times `scale` (> 1: an estimate from a sample)
fn groups(arena: std.mem.Allocator, db: store.Db, sql: []const u8, scale: i64) ![]Group {
    var q = try db.prepare(sql);
    defer q.deinit();
    var list: std.ArrayList(Group) = .empty;
    while (try q.step()) {
        const r = q.row(struct { label: []const u8, n: i64 });
        try list.append(arena, .{
            .label = try arena.dupe(u8, r.label),
            .n = .{ .n = r.n * scale, .estimate = scale > 1 },
        });
    }
    return list.items;
}

fn sum(gs: []const Group) Count {
    var total: Count = .{ .n = 0 };
    for (gs) |g| {
        total.n += g.n.n;
        total.estimate = total.estimate or g.n.estimate;
    }
    return total;
}

/// Exact, from match id prefixes over the primary key index: the table has no index on
/// platform, and a scan of it reads every row
fn byPlatform(arena: std.mem.Allocator, db: store.Db) ![]Group {
    var q = try db.prepare("SELECT count(*) FROM matches WHERE match_id >= ? || '_' AND match_id < ? || '`'");
    defer q.deinit();
    var list: std.ArrayList(Group) = .empty;
    for (ep.platforms) |p| {
        q.reset();
        try q.bind(.{ p.id, p.id });
        const n = if (try q.step()) q.int(0) else 0;
        if (n > 0) try list.append(arena, .{ .label = p.id, .n = .{ .n = n } });
    }
    std.mem.sort(Group, list.items, {}, struct {
        fn more(_: void, a: Group, b: Group) bool {
            return a.n.n > b.n.n;
        }
    }.more);
    return list.items;
}

fn print(out: *std.Io.Writer, label: []const u8, gs: []const Group) !void {
    try out.writeAll(label);
    for (gs) |g| try out.print(" {s}={f}", .{ g.label, g.n });
}

const testing = std.testing;

fn fixture() !store.Db {
    const db = try store.schema.memory();
    errdefer db.close();
    // One player per PUUID first character: the 1/16 sample scales back to all 64
    const alphabet = "-0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz";
    var ins = try db.prepare("INSERT INTO players (puuid, source, region) VALUES (? || 'x', 'ladder', ?)");
    defer ins.deinit();
    for (alphabet, 0..) |_, i| try ins.exec(.{ alphabet[i..][0..1], if (i % 4 == 0) "asia" else "europe" });
    try db.exec(
        \\INSERT INTO matches VALUES ('EUW1_1', 'riot', 'EUW1', 420, '16.1', '16.1.1', 1, 1, 100, 0);
        \\INSERT INTO matches VALUES ('EUW1_2', 'riot', 'EUW1', 420, '16.2', '16.2.1', 1, 1, 100, 0);
        \\INSERT INTO matches VALUES ('EUN1_3', 'riot', 'EUN1', 420, '16.2', '16.2.1', 1, 1, 100, 0);
        \\INSERT INTO matches VALUES ('KR_4', 'riot', 'KR', 420, '16.2', '16.2.1', 1, 1, 200, 0);
        \\INSERT INTO match_queue (match_id, discovered_at, region) VALUES ('EUW1_9', 1, 'europe');
        \\INSERT INTO timeline_queue (match_id, region, queued_at) VALUES ('EUW1_1', 'europe', 1);
        \\INSERT INTO timeline.timelines VALUES ('EUW1_1', 26, 0, x'01'), ('EUW1_2', 26, 0, x'01');
        \\INSERT INTO draft_backfill VALUES ('KR_4');
    );
    // One key per 64th of the key space, so the sample holds exactly one
    var r = try db.prepare("INSERT INTO ranks (key, rank, seen_day) VALUES (? * 288230376151711744, 1, 20000)");
    defer r.deinit();
    var h = try db.prepare("INSERT INTO rank_history VALUES (? * 288230376151711744, 20000, 1, 0, 1, 1)");
    defer h.deinit();
    for (0..64) |i| {
        try r.exec(.{@as(i64, @intCast(i)) - 32});
        try h.exec(.{@as(i64, @intCast(i)) - 32});
    }
    var p = try db.prepare("INSERT INTO participants (match_id, slot, team_id, champion_id, win) SELECT match_id, ?, 100, 1, 1 FROM matches");
    defer p.deinit();
    for (0..10) |slot| try p.exec(.{@as(i64, @intCast(slot))});
    return db;
}

test "estimates match exact counts on uniform data" {
    const db = try fixture();
    defer db.close();
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    var cheap: std.Io.Writer.Allocating = .init(testing.allocator);
    defer cheap.deinit();
    try write(arena_state.allocator(), db, &cheap.writer, .{ .min_sample = 0 });
    try testing.expectEqualStrings(
        \\players: ~64
        \\ladder_pages: 0
        \\ranks: ~64
        \\rank_history: ~64
        \\match_queue: 1
        \\matches: 4
        \\participants: ~40
        \\mastery: 0
        \\champions: 0
        \\raw.raw_docs: 0
        \\timeline_queue: 1
        \\timeline.timelines: ~2
        \\raw.timeline_docs: 0
        \\drafts: ~0
        \\draft_backfill: 1
        \\queue: europe pending=1
        \\by patch: 16.2=3 16.1=1
        \\by platform: EUW1=2 KR=1 EUN1=1
        \\timelines: europe pending=1
        \\players: europe=~48 asia=~16
        \\rank_history by day: 2024-10-04=~64
        \\~ estimate: players from 1/16 of PUUIDs, ranks and rank_history from 1/64 of keys, participants 10 per match, timelines and drafts from the rowid range; --exact counts every row
        \\
    , cheap.written());

    var full: std.Io.Writer.Allocating = .init(testing.allocator);
    defer full.deinit();
    try write(arena_state.allocator(), db, &full.writer, .{ .exact = true });
    try testing.expectEqualStrings(
        \\players: 64
        \\ladder_pages: 0
        \\ranks: 64
        \\rank_history: 64
        \\match_queue: 1
        \\matches: 4
        \\participants: 40
        \\bans: 0
        \\mastery: 0
        \\champions: 0
        \\raw.raw_docs: 0
        \\timeline_queue: 1
        \\timeline.timelines: 2
        \\raw.timeline_docs: 0
        \\drafts: 0
        \\draft_backfill: 1
        \\queue: europe pending=1
        \\by patch: 16.2=3 16.1=1
        \\by platform: EUW1=2 KR=1 EUN1=1
        \\timelines: europe pending=1
        \\players: europe=48 asia=16
        \\rank_history by day: 2024-10-04=64
        \\
    , full.written());
}

test "the samples read index ranges, not whole tables" {
    const db = try store.schema.memory();
    defer db.close();
    const cases = .{
        .{ "SELECT count(*) FROM players WHERE " ++ puuid_sample, "SEARCH players USING PRIMARY KEY" },
        .{ "SELECT count(*) FROM matches WHERE match_id >= 'KR_' AND match_id < 'KR`'", "SEARCH matches USING COVERING INDEX sqlite_autoindex_matches_1" },
        .{ "SELECT (SELECT max(rowid) FROM drafts) - (SELECT min(rowid) FROM drafts)", "SEARCH drafts" },
        .{ "SELECT count(*) FROM rank_history WHERE " ++ key_sample, "SEARCH rank_history USING PRIMARY KEY (key>? AND key<?)" },
        .{ "SELECT count(*) FROM ranks WHERE " ++ key_sample, "SEARCH ranks USING INTEGER PRIMARY KEY (rowid>? AND rowid<?)" },
    };
    inline for (cases) |case| {
        var q = try db.prepare("EXPLAIN QUERY PLAN " ++ case[0]);
        defer q.deinit();
        var plan: std.ArrayList(u8) = .empty;
        defer plan.deinit(testing.allocator);
        while (try q.step()) try plan.appendSlice(testing.allocator, q.bytes(3));
        if (std.mem.indexOf(u8, plan.items, case[1]) == null) {
            std.debug.print("{s}\n  plan: {s}\n", .{ case[0], plan.items });
            return error.TestUnexpectedResult;
        }
    }
}

test "a small sample falls back to counting every player" {
    const db = try fixture();
    defer db.close();
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    var w: std.Io.Writer.Allocating = .init(testing.allocator);
    defer w.deinit();
    try write(arena_state.allocator(), db, &w.writer, .{});
    try testing.expect(std.mem.startsWith(u8, w.written(), "players: 64\n"));
    try testing.expect(std.mem.indexOf(u8, w.written(), "players: europe=48 asia=16\n") != null);
}
