//! `meiolol curves`: lane matchup curves (core/curvesfile.zig) from the compact match
//! timelines in timeline.db. One pass over the patch's games, like stats.zig.

const std = @import("std");
const store = @import("store");
const core = @import("core");
const timeline = @import("riot/timeline.zig");
const stats = @import("stats.zig");

const Role = core.Role;
const curvesfile = core.curvesfile;
const Lane = curvesfile.Lane;
const max_minutes = curvesfile.max_minutes;

const log = std.log.scoped(.curves);

pub const Summary = struct {
    games: u32,
    /// Timelines that did not decode or games without all ten positions
    skipped: u32,
};

/// Every ranked solo game with a timeline on `chosen` patches and `platforms` (no
/// remakes, a winner, all ten positions). Caller owns the builder.
pub fn build(
    gpa: std.mem.Allocator,
    db: store.Db,
    chosen: []const []const u8,
    platforms: []const []const u8,
) !struct { builder: curvesfile.Builder, summary: Summary } {
    var b: curvesfile.Builder = .{ .gpa = gpa };
    errdefer b.deinit();
    const patch_json = try std.json.Stringify.valueAlloc(gpa, chosen, .{});
    defer gpa.free(patch_json);
    const platform_json = try std.json.Stringify.valueAlloc(gpa, platforms, .{});
    defer gpa.free(platform_json);

    var q = try db.prepare(
        \\SELECT m.match_id, m.winning_team, t.data
        \\FROM matches m JOIN timeline.timelines t USING (match_id)
        \\WHERE m.patch IN (SELECT value FROM json_each(?)) AND m.queue_id = ?
        \\  AND m.platform IN (SELECT value FROM json_each(?))
        \\  AND m.remake = 0 AND m.winning_team IS NOT NULL
    );
    defer q.deinit();
    try q.bind(.{ patch_json, stats.ranked_solo, platform_json });
    var players = try db.prepare(
        \\SELECT pa.slot, pa.team_id, pa.position, pa.champion_id, pl.tier
        \\FROM participants pa LEFT JOIN players pl USING (puuid)
        \\WHERE pa.match_id = ?
    );
    defer players.deinit();

    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    var summary: Summary = .{ .games = 0, .skipped = 0 };
    while (try q.step()) {
        _ = arena_state.reset(.retain_capacity);
        const arena = arena_state.allocator();
        const blue_won = q.int(1) == 100;
        const t = decode(arena, q.bytes(2)) catch |err| {
            log.warn("{s}: {t}", .{ q.bytes(0), err });
            summary.skipped += 1;
            continue;
        };
        try players.bind(.{q.bytes(0)});
        const game = try readGame(&players) orelse {
            summary.skipped += 1;
            continue;
        };
        for (Role.all) |r| try b.addLane(lane(t, game, r, blue_won));
        b.addGame();
        summary.games += 1;
    }
    return .{ .builder = b, .summary = summary };
}

fn decode(arena: std.mem.Allocator, blob: []const u8) !timeline.Timeline {
    return timeline.decode(arena, try store.raw.decompress(arena, blob));
}

pub const Game = struct {
    /// Participant id (slot + 1) and champion per side and role
    ids: [2][5]u8,
    champions: [2][5]u32,
    bracket: ?curvesfile.Bracket,
};

/// Null unless every position is filled exactly once per side
fn readGame(players: *store.sqlite.Stmt) !?Game {
    var g: Game = .{ .ids = undefined, .champions = undefined, .bracket = null };
    var seen: [2][5]bool = @splat(@splat(false));
    var ranks: [10]usize = undefined;
    var n_ranks: usize = 0;
    var rows: usize = 0;
    while (try players.step()) : (rows += 1) {
        const side: usize = if (players.int(1) == 100) 0 else 1;
        const r = @intFromEnum(Role.fromLcu(players.bytes(2)) orelse return null);
        const slot = players.int(0);
        if (seen[side][r] or slot < 0 or slot >= timeline.max_participants) return null;
        seen[side][r] = true;
        g.ids[side][r] = @intCast(slot + 1);
        g.champions[side][r] = @intCast(players.int(3));
        if (!players.isNull(4) and n_ranks < ranks.len) {
            if (curvesfile.tierRank(players.bytes(4))) |rank| {
                ranks[n_ranks] = rank;
                n_ranks += 1;
            }
        }
    }
    if (rows != 10) return null;
    if (curvesfile.medianRank(ranks[0..n_ranks])) |rank| g.bracket = .ofRank(rank);
    return g;
}

/// Blue's laner in `r` as a, red's as b
pub fn lane(t: timeline.Timeline, g: Game, r: Role, blue_won: bool) Lane {
    const pa = g.ids[0][@intFromEnum(r)];
    const pb = g.ids[1][@intFromEnum(r)];
    // Frame k is minute k; the last frame is the game's end, part of a minute
    const full = if (t.frames.len >= 2) t.frames.len - 2 else 0;
    var l: Lane = .{
        .role = r,
        .bracket = g.bracket,
        .a = g.champions[0][@intFromEnum(r)],
        .b = g.champions[1][@intFromEnum(r)],
        .a_won = blue_won,
        .minutes = @intCast(@min(full, max_minutes)),
    };
    if (pa > t.participants or pb > t.participants) {
        l.minutes = 0;
        return l;
    }
    for (0..l.minutes) |i| {
        const f = t.frames[i + 1];
        l.gold[i] = diff(f.get(pa, .total_gold), f.get(pb, .total_gold));
        l.xp[i] = diff(f.get(pa, .xp), f.get(pb, .xp));
        l.cs[i] = diff(cs(f, pa), cs(f, pb));
    }
    for (t.events) |e| switch (e.data) {
        .champion_kill => |k| {
            const phase = phaseOf(e.t_ms);
            if (k.victim == pb and involved(k, pa)) l.a_kills_b[phase] = true;
            if (k.victim == pa and involved(k, pb)) l.b_kills_a[phase] = true;
        },
        .level_up => |u| if (u.level == 6) {
            const secs: u16 = @intCast(@min(@divFloor(e.t_ms, 1000), std.math.maxInt(u16)));
            if (u.participant == pa and l.level6_a == 0) l.level6_a = secs;
            if (u.participant == pb and l.level6_b == 0) l.level6_b = secs;
        },
        else => {},
    };
    return l;
}

fn cs(f: timeline.Frame, p: u8) i32 {
    return f.get(p, .minions) + f.get(p, .jungle_minions);
}

fn diff(a: i32, b: i32) i16 {
    return @intCast(std.math.clamp(a - b, std.math.minInt(i16), std.math.maxInt(i16)));
}

fn phaseOf(t_ms: i64) usize {
    const minute = @divFloor(t_ms, 60_000);
    for (curvesfile.phase_ends, 0..) |end, i| if (minute < end) return i;
    return curvesfile.phase_ends.len;
}

fn involved(k: anytype, p: u8) bool {
    return k.killer == p or std.mem.indexOfScalar(u8, k.assists, p) != null;
}

const testing = std.testing;

test "curves from a real timeline" {
    const gpa = testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const json = try store.raw.decompress(arena, @embedFile("riot/testdata/timeline.json.gz"));
    const t = try timeline.fromJson(arena, json);
    const blob = try store.raw.compress(arena, try timeline.encode(arena, t));

    const db = try store.schema.memory();
    defer db.close();
    const positions = [_][]const u8{ "TOP", "JUNGLE", "MIDDLE", "BOTTOM", "UTILITY" };
    for (0..2) |g| {
        const id = try std.fmt.allocPrint(arena, "EUW1_{d}", .{g});
        try db.run("INSERT INTO matches VALUES (?,'t','EUW1',420,'16.20','',0,1600,100,0)", .{id});
        const data: store.Blob = .{ .bytes = blob };
        try db.run("INSERT INTO timeline.timelines VALUES (?,26,0,?)", .{ id, data });
        for (0..10) |slot| {
            const team: i64 = if (slot < 5) 100 else 200;
            try db.run(
                \\INSERT INTO participants
                \\  (match_id, slot, team_id, puuid, champion_id, position, win)
                \\VALUES (?,?,?,'p',?,?,0)
            , .{ id, slot, team, 10 * (slot + 1), positions[slot % 5] });
        }
    }
    try db.run("INSERT INTO players (puuid, tier, source) VALUES ('p','EMERALD','t')", .{});

    var r = try build(gpa, db, &.{"16.20"}, &.{"EUW1"});
    defer r.builder.deinit();
    try testing.expectEqual(Summary{ .games = 2, .skipped = 0 }, r.summary);
    try testing.expectEqual(10, r.builder.lanes.items.len);
    var aw: std.Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();
    try r.builder.write(&aw.writer, "16.20", 2);
    var c: curvesfile.Curves = try .parse(gpa, aw.written());
    defer c.deinit(gpa);

    // Top: participant 1 (champion 10) against 6 (champion 60), blue won
    const top = c.get(.top, .all, 10, 60).?;
    try testing.expectEqual(2, top.games());
    try testing.expectEqual(2, top.wins());
    try testing.expect(c.get(.top, .mid, 10, 60) != null);
    const f14 = t.frames[14];
    const m14 = top.minute(13);
    try testing.expectEqual(2, m14.n);
    try testing.expectEqual(f14.get(1, .total_gold) - f14.get(6, .total_gold), m14.gold.p50);
    try testing.expectEqual(f14.get(1, .xp) - f14.get(6, .xp), m14.xp.p50);
    // 26 frames: minutes 1..24 complete, the 25th frame ends the game
    try testing.expectEqual(0, top.minute(24).n);
    try testing.expectEqual(2, top.minute(23).n);
    const l6 = top.level6();
    try testing.expect(l6[0] > 5 * 60 and l6[0] < 12 * 60);

    // The first kill: 9 (red bot) on 4 (blue bot) with 10's assist, under a minute in
    const bot = c.get(.bottom, .all, 40, 90).?;
    try testing.expectEqual(2, bot.deaths(0));
    try testing.expectEqual(0, bot.kills(0));
    try testing.expect(c.get(.utility, .all, 100, 50).?.flipped);
}
