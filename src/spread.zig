//! Players' win rates on a champion: how widely they spread, for the champion pages.
//! Each player's ranked solo games on the champion in the crawl (all roles; a view's
//! region and period, pool.zig), counted once they have min_games. A fixed-width picture that doesn't
//! narrow as players come in: bar heights are shares of the tallest bin.
//!
//! With 10 to 20 games a player's rate swings on luck alone (docs/learned.md: on EUW
//! the whole spread is about what luck gives), so the pages say so. Aggregate only.

const std = @import("std");
const core = @import("core");

const Stats = core.Stats;
const Allocator = std.mem.Allocator;

/// Players with fewer games on the champion are left out
const min_games = 10;
/// Fewer players and the page says more data is needed
const min_players = 20;

/// Bins centred on 0%, 10%, ... 100%: a 10-game player's rate is a multiple of 10%, so
/// edges between them keep 50% in the middle of its bin
pub const bin_count = 11;

/// The champions table's shape: players' win rates smoothed, as offsets from their mean
/// every shape_step points from -shape_reach to +shape_reach. The table centres it on
/// the champion's own win rate: players seen in 10+ games win more than the champion's
/// games overall (the crawl follows climbing ladder players), so their mean would sit
/// right of it. Reach past the track's ends (25% to 75%) for champions from 39% to
/// 61%, so the edge fade hides the shape's ends instead of them stopping on the track
pub const shape_reach = 36;
pub const shape_step = 2;
pub const shape_points = 2 * shape_reach / shape_step + 1;
/// Smoothing, in points of win rate: a 10-game player's rate is a multiple of 10%, so
/// less leaves a comb
const shape_bandwidth = 5.0;

/// Players with more games count as this many for the luck reference: few play that
/// much, and luck at 100 games is already small beside the 10-game players'
const luck_games = 100;
const by_games_len = luck_games - min_games + 1;

/// Players by whole-percent win rate, per champion by stats index
pub const Tally = struct {
    /// [c * 101 + percent]
    players: []u32,
    /// [c * by_games_len + games - min_games], games capped at luck_games
    by_games: []u32,
    /// Counted players' games and wins together, per champion
    games: []u64,
    wins: []u64,

    pub fn init(gpa: Allocator, n: usize) !Tally {
        const p = try gpa.alloc(u32, n * 101);
        errdefer gpa.free(p);
        const g = try gpa.alloc(u32, n * by_games_len);
        errdefer gpa.free(g);
        const sums = try gpa.alloc(u64, 2 * n);
        @memset(p, 0);
        @memset(g, 0);
        @memset(sums, 0);
        return .{ .players = p, .by_games = g, .games = sums[0..n], .wins = sums[n..] };
    }

    pub fn deinit(t: *Tally, gpa: Allocator) void {
        gpa.free(t.players);
        gpa.free(t.by_games);
        gpa.free(t.games.ptr[0 .. 2 * t.games.len]);
    }

    /// One player's games on champion index `c`
    pub fn add(t: *Tally, c: usize, games: u32, wins: u32) void {
        if (games < min_games) return;
        t.players[c * 101 + pctOf(wins, games)] += 1;
        t.by_games[c * by_games_len + @min(games, luck_games) - min_games] += 1;
        t.games[c] += games;
        t.wins[c] += wins;
    }
};

fn pctOf(wins: u32, games: u32) usize {
    return (200 * wins + games) / (2 * games);
}

pub const Champion = struct {
    id: u32,
    players: u32,
    /// Players per bin_count bin
    bins: [bin_count]u32,
    /// Win rate in whole percent of the players a quarter, half and three quarters up
    p25: u8,
    p50: u8,
    p75: u8,
    /// How many players sit near each shape point, 255 at the most
    shape: [shape_points]u8,
    /// What luck alone gives: players per bin, and its quartiles, had every player the
    /// players' pooled win rate over their own games. Near bins and p25/p75 when the
    /// champion's players differ little beyond luck (learned.md, 15 Oct)
    luck_bins: [bin_count]f32,
    luck_p25: u8,
    luck_p75: u8,
};

pub const Spread = struct {
    min_games: u32 = 0,
    min_players: u32 = 0,
    /// Champions with any player counted, in stats order
    champions: []const Champion = &.{},

    pub fn get(s: *const Spread, id: u32) ?Champion {
        for (s.champions) |c| if (c.id == id) return c;
        return null;
    }
};

pub fn make(arena: Allocator, t: *const Tally, st: *const Stats) !Spread {
    var list: std.ArrayList(Champion) = .empty;
    for (0..st.n) |c| {
        const by_pct = t.players[c * 101 ..][0..101];
        var players: u32 = 0;
        for (by_pct) |n| players += n;
        if (players == 0) continue;
        var ch: Champion = .{
            .id = st.ids[c],
            .players = players,
            .bins = @splat(0),
            .p25 = percentile(by_pct, players, 1, 4),
            .p50 = percentile(by_pct, players, 1, 2),
            .p75 = percentile(by_pct, players, 3, 4),
            .shape = shape(by_pct, players),
            .luck_bins = @splat(0),
            .luck_p25 = 0,
            .luck_p75 = 0,
        };
        for (by_pct, 0..) |n, p| ch.bins[(p + 5) / 10] += n;
        const luck_pct = luck(t.by_games[c * by_games_len ..][0..by_games_len], ratio(t.wins[c], t.games[c]));
        for (luck_pct, 0..) |n, p| ch.luck_bins[(p + 5) / 10] += @floatCast(n);
        ch.luck_p25 = percentileF(&luck_pct, 1, 4);
        ch.luck_p75 = percentileF(&luck_pct, 3, 4);
        try list.append(arena, ch);
    }
    return .{ .min_games = min_games, .min_players = min_players, .champions = list.items };
}

/// Gaussian kernel density at the shape points, scaled to its peak
fn shape(by_pct: *const [101]u32, players: u32) [shape_points]u8 {
    var sum: f64 = 0;
    for (by_pct, 0..) |n, p| sum += @as(f64, @floatFromInt(n * p));
    const mean = sum / @as(f64, @floatFromInt(players));
    var d: [shape_points]f64 = undefined;
    var peak: f64 = 0;
    for (&d, 0..) |*v, k| {
        const at = mean + @as(f64, @floatFromInt(shape_step * k)) - shape_reach;
        v.* = 0;
        for (by_pct, 0..) |n, p| {
            const z = (at - @as(f64, @floatFromInt(p))) / shape_bandwidth;
            v.* += @as(f64, @floatFromInt(n)) * @exp(-0.5 * z * z);
        }
        peak = @max(peak, v.*);
    }
    var out: [shape_points]u8 = @splat(0);
    if (peak == 0) return out;
    for (d, &out) |v, *o| o.* = @round(255 * v / peak);
    return out;
}

fn ratio(a: u64, b: u64) f64 {
    return @as(f64, @floatFromInt(a)) / @as(f64, @floatFromInt(@max(b, 1)));
}

/// Expected players by whole-percent win rate when each plays their games at rate `p`:
/// a binomial per game count, rounded to percents as Tally.add rounds
fn luck(by_games: *const [by_games_len]u32, p_in: f64) [101]f64 {
    var out: [101]f64 = @splat(0);
    // Away from 0 and 1 so the odds ratio below stays finite
    const p = std.math.clamp(p_in, 1e-6, 1 - 1e-6);
    for (by_games, min_games..) |players, games| {
        if (players == 0) continue;
        const n: u32 = @intCast(games);
        var pmf = std.math.pow(f64, 1 - p, @floatFromInt(n));
        for (0..n + 1) |k| {
            out[pctOf(@intCast(k), n)] += @as(f64, @floatFromInt(players)) * pmf;
            pmf *= @as(f64, @floatFromInt(n - k)) / @as(f64, @floatFromInt(k + 1)) * p / (1 - p);
        }
    }
    return out;
}

/// The percent num/den of the way up an expected count
fn percentileF(by_pct: *const [101]f64, num: f64, den: f64) u8 {
    var total: f64 = 0;
    for (by_pct) |n| total += n;
    const rank = total * num / den;
    var seen: f64 = 0;
    for (by_pct, 0..) |n, p| {
        seen += n;
        if (seen >= rank) return @intCast(p);
    }
    return 100;
}

/// The rate of the player num/den of the way up (nearest rank)
fn percentile(by_pct: *const [101]u32, players: u32, num: u32, den: u32) u8 {
    const rank = @max(1, (players * num + den - 1) / den);
    var seen: u32 = 0;
    for (by_pct, 0..) |n, p| {
        seen += n;
        if (seen >= rank) return @intCast(p);
    }
    return 100;
}

const testing = std.testing;

test "luck: one 10-game player at 50%" {
    var by_games: [by_games_len]u32 = @splat(0);
    by_games[0] = 1;
    const l = luck(&by_games, 0.5);
    try testing.expectApproxEqAbs(252.0 / 1024.0, l[50], 1e-9);
    try testing.expectEqual(0, l[45]);
    try testing.expectEqual(40, percentileF(&l, 1, 4));
    try testing.expectEqual(60, percentileF(&l, 3, 4));
    // 100 and more games count as 100: narrower
    by_games = @splat(0);
    by_games[by_games_len - 1] = 1;
    const wide = luck(&by_games, 0.5);
    try testing.expectEqual(47, percentileF(&wide, 1, 4));
}

test "bins, percentiles, players under min_games left out" {
    const gpa = testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    var champs: std.ArrayList(core.statsfile.Champion) = .empty;
    for ([_]u32{ 10, 60 }) |id| try champs.append(arena, .{ .id = id, .name = "x" });
    var b: core.statsfile.Builder = try .init(arena, champs.items);
    var aw: std.Io.Writer.Allocating = .init(arena);
    try b.write(&aw.writer, "16.20");
    const st: Stats = try .parse(arena, aw.written());

    var t: Tally = try .init(gpa, st.n);
    defer t.deinit(gpa);
    const c = st.index(10).?;
    t.add(c, 10, 5);
    t.add(c, 10, 6);
    t.add(c, 20, 9); // 45%: rounds into the 50% bin
    t.add(c, 12, 2); // 17%
    t.add(c, 9, 9); // too few games
    const s = try make(arena, &t, &st);
    try testing.expectEqual(1, s.champions.len);
    const got = s.get(10).?;
    try testing.expectEqual(4, got.players);
    try testing.expectEqual(1, got.bins[2]);
    try testing.expectEqual(2, got.bins[5]);
    try testing.expectEqual(1, got.bins[6]);
    try testing.expectEqual(17, got.p25);
    try testing.expectEqual(45, got.p50);
    try testing.expectEqual(50, got.p75);
    try testing.expectEqual(null, s.get(60));
    // Luck at the pooled 22 of 52: the four players again, spread around 42%
    var luck_players: f32 = 0;
    for (got.luck_bins) |n| luck_players += n;
    try testing.expectApproxEqAbs(4, luck_players, 1e-4);
    try testing.expect(got.luck_p25 < 42 and got.luck_p75 > 42);
    // Mean 39.75%: peak near +6 (45% to 50%), a bump at -24 (the 17% player), less at
    // +24 (64%, past the 60% player)
    const at = struct {
        fn k(off: i32) usize {
            return @intCast(@divExact(off + shape_reach, shape_step));
        }
    }.k;
    try testing.expectEqual(255, std.mem.max(u8, &got.shape));
    const peak = std.mem.findMax(u8, &got.shape);
    try testing.expect(peak >= at(4) and peak <= at(10));
    try testing.expect(got.shape[at(-24)] > 0 and got.shape[at(-24)] < 255);
    try testing.expect(got.shape[at(24)] < got.shape[at(-24)]);
}
