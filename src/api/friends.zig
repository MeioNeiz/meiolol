//! Who a player plays with, from their cached games (the last 60 days, fetch.zig): every
//! teammate seen in `min_together` games or more, the player's record with and without
//! each, champion and role pairs, and, once the friend's own games are cached too, the
//! friend's record with and without the player. Facts with their games and a range,
//! never verdicts (docs/your-games.md "Friends").

const std = @import("std");
const core = @import("core");
const game = @import("game.zig");

const Allocator = std.mem.Allocator;
const Role = core.Role;

/// Two random teammates in 60 days happen; three rarely do
pub const min_together = 3;
pub const max_friends = 20;
const top_pairs = 3;

pub const Record = struct {
    games: u32 = 0,
    wins: u32 = 0,

    fn add(r: *Record, win: bool) void {
        r.games += 1;
        r.wins += @intFromBool(win);
    }

    fn minus(r: Record, o: Record) Record {
        return .{ .games = r.games - o.games, .wins = r.wins - o.wins };
    }

    /// One win and one loss added, so 0 of 3 has a spread
    fn smoothed(r: Record) f64 {
        return (@as(f64, @floatFromInt(r.wins)) + 1) / (@as(f64, @floatFromInt(r.games)) + 2);
    }
};

/// A player's record with someone against their record apart, in the queues they shared:
/// friends play flex and normals together and solo/duo alone, so a plain "without" would
/// compare queues, not company. `apart_rate` is each queue's win rate apart weighted by
/// the games together in it; `diff` is the rate together minus it, in points, `lo` to
/// `hi` its 95% range
pub const Effect = struct {
    with: Record,
    apart: Record,
    apart_rate: f64,
    diff: f64,
    lo: f64,
    hi: f64,
};

pub const ChampionPair = struct { mine: u32, theirs: u32, games: u32, wins: u32 };
pub const RolePair = struct { mine: []const u8, theirs: []const u8, games: u32, wins: u32 };

pub const Friend = struct {
    /// As at the newest game together
    riot_id: []const u8,
    /// Your record on their team and against them
    together: Record,
    against: Record,
    last_ms: i64,
    /// Yours with them against apart; null when no shared queue has games apart
    you: ?Effect,
    /// Theirs with you against apart, from their own games; null until those are cached
    them: ?Effect = null,
    /// Their games cached, 0 when nobody has looked them up
    their_games: u32 = 0,
    champions: []const ChampionPair,
    roles: []const RolePair,
};

pub const Out = struct {
    /// Games counted, remakes left out
    games: u32,
    /// Older games still to fetch (fetch.zig backlog)
    waiting: u32 = 0,
    /// Your games with at least one listed friend on your team, and with none
    with_friends: Record,
    alone: Record,
    friends: []const Friend,
};

pub const Game = struct {
    summary: game.Summary,
    slot: u8,
    /// By slot; null where none is kept (blocked players)
    riot_ids: []const ?[]const u8,
};

/// One player's games, tallied by everyone they met
pub const Tally = struct {
    games: u32 = 0,
    by_queue: Queues = .empty,
    others: std.StringArrayHashMapUnmanaged(Other) = .empty,

    const Queues = std.AutoArrayHashMapUnmanaged(i64, Record);

    const Other = struct {
        riot_id: ?[]const u8 = null,
        together: Record = .{},
        against: Record = .{},
        last_ms: i64 = 0,
        by_queue: Queues = .empty,
        champions: std.AutoArrayHashMapUnmanaged([2]u32, Record) = .empty,
        roles: std.AutoArrayHashMapUnmanaged([2]Role, Record) = .empty,
    };
};

/// `games` newest first, so each name is the newest
pub fn tally(arena: Allocator, games: []const Game) !Tally {
    var t: Tally = .{};
    for (games) |g| {
        const s = g.summary;
        if (s.remake or g.slot >= s.players.len) continue;
        const me = s.players[g.slot];
        t.games += 1;
        try addTo(arena, &t.by_queue, s.queue, me.win);
        for (s.players, 0..) |p, i| {
            if (i == g.slot) continue;
            const gop = try t.others.getOrPut(arena, p.hash);
            if (!gop.found_existing) gop.value_ptr.* = .{};
            const o = gop.value_ptr;
            if (o.riot_id == null and i < g.riot_ids.len) o.riot_id = g.riot_ids[i];
            o.last_ms = @max(o.last_ms, s.start_ms);
            if (p.team != me.team) {
                o.against.add(me.win);
                continue;
            }
            o.together.add(me.win);
            try addTo(arena, &o.by_queue, s.queue, me.win);
            const c = try o.champions.getOrPutValue(arena, .{ me.champion, p.champion }, .{});
            c.value_ptr.add(me.win);
            if (Role.fromLcu(me.position)) |mine| if (Role.fromLcu(p.position)) |theirs| {
                const r = try o.roles.getOrPutValue(arena, .{ mine, theirs }, .{});
                r.value_ptr.add(me.win);
            };
        }
    }
    return t;
}

fn addTo(arena: Allocator, queues: *Tally.Queues, queue: i64, win: bool) !void {
    const gop = try queues.getOrPutValue(arena, queue, .{});
    gop.value_ptr.add(win);
}

/// `t`'s record with `other` (a hash) against apart; null when they never shared a team
/// in a queue `t` also played apart
pub fn effect(t: *const Tally, other: []const u8) ?Effect {
    const o = t.others.getPtr(other) orelse return null;
    var with: Record = .{};
    var apart: Record = .{};
    for (o.by_queue.keys(), o.by_queue.values()) |q, w| {
        const a = t.by_queue.get(q).?.minus(w);
        if (a.games == 0) continue;
        with.games += w.games;
        with.wins += w.wins;
        apart.games += a.games;
        apart.wins += a.wins;
    }
    if (with.games == 0) return null;
    const n: f64 = @floatFromInt(with.games);
    var rate: f64 = 0;
    var variance: f64 = 0;
    for (o.by_queue.keys(), o.by_queue.values()) |q, w| {
        const a = t.by_queue.get(q).?.minus(w);
        if (a.games == 0) continue;
        const weight = @as(f64, @floatFromInt(w.games)) / n;
        const games_apart: f64 = @floatFromInt(a.games);
        rate += weight * @as(f64, @floatFromInt(a.wins)) / games_apart;
        const p = a.smoothed();
        variance += weight * weight * p * (1 - p) / games_apart;
    }
    const p = with.smoothed();
    variance += p * (1 - p) / n;
    const diff = 100 * (@as(f64, @floatFromInt(with.wins)) / n - rate);
    const half = 100 * 1.96 * @sqrt(variance);
    return .{ .with = with, .apart = apart, .apart_rate = 100 * rate, .diff = diff, .lo = diff - half, .hi = diff + half };
}

pub const Built = struct {
    out: Out,
    /// Each friend's hash, in `out.friends` order
    hashes: []const []const u8,
};

/// Friends from one player's games, most games together first
pub fn build(arena: Allocator, games: []const Game) !Built {
    const t = try tally(arena, games);
    const Entry = struct { hash: []const u8, o: *const Tally.Other };
    var list: std.ArrayList(Entry) = .empty;
    for (t.others.keys(), t.others.values()) |hash, *o| {
        if (o.together.games >= min_together and o.riot_id != null) try list.append(arena, .{ .hash = hash, .o = o });
    }
    std.mem.sort(Entry, list.items, {}, struct {
        fn more(_: void, a: Entry, b: Entry) bool {
            if (a.o.together.games != b.o.together.games) return a.o.together.games > b.o.together.games;
            return a.o.last_ms > b.o.last_ms;
        }
    }.more);
    const kept = list.items[0..@min(list.items.len, max_friends)];
    const friends = try arena.alloc(Friend, kept.len);
    const hashes = try arena.alloc([]const u8, kept.len);
    for (kept, friends, hashes) |e, *f, *h| {
        h.* = e.hash;
        f.* = .{
            .riot_id = e.o.riot_id.?,
            .together = e.o.together,
            .against = e.o.against,
            .last_ms = e.o.last_ms,
            .you = effect(&t, e.hash),
            .champions = try topChampions(arena, e.o),
            .roles = try topRoles(arena, e.o),
        };
    }

    var listed: std.StringHashMapUnmanaged(void) = .empty;
    for (hashes) |h| try listed.put(arena, h, {});
    var with_friends: Record = .{};
    var alone: Record = .{};
    for (games) |g| {
        const s = g.summary;
        if (s.remake or g.slot >= s.players.len) continue;
        const me = s.players[g.slot];
        const any = for (s.players, 0..) |p, i| {
            if (i == g.slot or p.team != me.team) continue;
            if (listed.contains(p.hash)) break true;
        } else false;
        (if (any) &with_friends else &alone).add(me.win);
    }
    return .{
        .out = .{ .games = t.games, .with_friends = with_friends, .alone = alone, .friends = friends },
        .hashes = hashes,
    };
}

fn topChampions(arena: Allocator, o: *const Tally.Other) ![]const ChampionPair {
    var out = try arena.alloc(ChampionPair, o.champions.count());
    for (o.champions.keys(), o.champions.values(), out) |k, r, *c| c.* = .{ .mine = k[0], .theirs = k[1], .games = r.games, .wins = r.wins };
    std.mem.sort(ChampionPair, out, {}, morePair(ChampionPair));
    return out[0..@min(out.len, top_pairs)];
}

fn topRoles(arena: Allocator, o: *const Tally.Other) ![]const RolePair {
    var out = try arena.alloc(RolePair, o.roles.count());
    for (o.roles.keys(), o.roles.values(), out) |k, r, *c| c.* = .{ .mine = k[0].label(), .theirs = k[1].label(), .games = r.games, .wins = r.wins };
    std.mem.sort(RolePair, out, {}, morePair(RolePair));
    return out[0..@min(out.len, top_pairs)];
}

fn morePair(comptime T: type) fn (void, T, T) bool {
    return struct {
        fn more(_: void, a: T, b: T) bool {
            if (a.games != b.games) return a.games > b.games;
            return a.wins > b.wins;
        }
    }.more;
}

const testing = std.testing;

/// A 5v5 game: `me` in slot 0 on team 100 with `mates` (hashes) in slots 1-4, the rest
/// strangers on team 200
fn fixture(arena: Allocator, queue: i64, start_ms: i64, win: bool, mates: []const []const u8, against: []const []const u8) !Game {
    const players = try arena.alloc(game.Summary.Player, 10);
    const ids = try arena.alloc(?[]const u8, 10);
    const positions = [_][]const u8{ "TOP", "JUNGLE", "MIDDLE", "BOTTOM", "UTILITY" };
    for (players, ids, 0..) |*p, *id, i| {
        const blue = i < 5;
        const hash = if (i == 0) "me" else if (blue and i - 1 < mates.len) mates[i - 1] else if (!blue and i - 5 < against.len) against[i - 5] else try arena.print("stranger-{d}-{d}", .{ start_ms, i });
        p.* = .{ .hash = hash, .team = if (blue) 100 else 200, .position = positions[i % 5], .champion = @intCast(i + 1), .win = win == blue, .kills = 0, .deaths = 0, .assists = 0 };
        id.* = try arena.print("{s}#EUW", .{hash});
    }
    return .{ .summary = .{ .patch = "16.20", .queue = queue, .start_ms = start_ms, .duration_s = 1800, .remake = false, .players = players }, .slot = 0, .riot_ids = ids };
}

test "build: friends from three games together, the rate apart in the same queues" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var games: std.ArrayList(Game) = .empty;
    // With ana in flex: 3 wins of 4. Flex apart: 1 of 4. Solo apart: 4 of 4, ignored
    for (0..4) |i| try games.append(arena, try fixture(arena, 440, @intCast(100 - i), i != 3, &.{"ana"}, &.{}));
    for (0..4) |i| try games.append(arena, try fixture(arena, 440, @intCast(50 - i), i == 0, &.{}, &.{"ana"}));
    for (0..4) |i| try games.append(arena, try fixture(arena, 420, @intCast(20 - i), true, &.{}, &.{}));
    // bo twice only: no friend
    for (0..2) |i| try games.append(arena, try fixture(arena, 420, @intCast(10 - i), false, &.{"bo"}, &.{}));

    const b = try build(arena, games.items);
    try testing.expectEqual(1, b.out.friends.len);
    const ana = b.out.friends[0];
    try testing.expectEqualStrings("ana#EUW", ana.riot_id);
    try testing.expectEqual(Record{ .games = 4, .wins = 3 }, ana.together);
    try testing.expectEqual(Record{ .games = 4, .wins = 1 }, ana.against);
    try testing.expectEqual(100, ana.last_ms);
    const you = ana.you.?;
    try testing.expectEqual(Record{ .games = 4, .wins = 3 }, you.with);
    try testing.expectEqual(Record{ .games = 4, .wins = 1 }, you.apart);
    try testing.expectApproxEqAbs(25, you.apart_rate, 1e-9);
    try testing.expectApproxEqAbs(50, you.diff, 1e-9);
    try testing.expect(you.lo < you.diff and you.hi > you.diff);
    try testing.expectEqual(Record{ .games = 4, .wins = 3 }, b.out.with_friends);
    try testing.expectEqual(Record{ .games = 10, .wins = 5 }, b.out.alone);
    try testing.expectEqual(1, ana.roles.len);
    try testing.expectEqualStrings("top", ana.roles[0].mine);
    try testing.expectEqualStrings("jungle", ana.roles[0].theirs);
    try testing.expectEqual(ChampionPair{ .mine = 1, .theirs = 2, .games = 4, .wins = 3 }, ana.champions[0]);
}

test "effect: null without games apart in a shared queue; a remake counts nowhere" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var games: std.ArrayList(Game) = .empty;
    for (0..3) |i| try games.append(arena, try fixture(arena, 400, @intCast(10 - i), true, &.{"cy"}, &.{}));
    var remake = try fixture(arena, 400, 1, true, &.{}, &.{});
    remake.summary.remake = true;
    try games.append(arena, remake);
    const b = try build(arena, games.items);
    try testing.expectEqual(3, b.out.games);
    try testing.expectEqual(null, b.out.friends[0].you);
}

test "effect: a friend without a kept Riot ID is left out" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var games: std.ArrayList(Game) = .empty;
    for (0..3) |i| {
        var g = try fixture(arena, 420, @intCast(10 - i), true, &.{"hidden"}, &.{});
        const ids = try arena.dupe(?[]const u8, g.riot_ids);
        ids[1] = null;
        g.riot_ids = ids;
        try games.append(arena, g);
    }
    try testing.expectEqual(0, (try build(arena, games.items)).out.friends.len);
}
