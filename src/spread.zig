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

pub const Options = struct {
    /// Players with fewer games on the champion are left out
    min_games: u32 = 10,
    /// Fewer players and the page says more data is needed
    min_players: u32 = 20,
};

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

/// Players by whole-percent win rate, per champion by stats index
pub const Tally = struct {
    /// [c * 101 + percent]
    players: []u32,

    pub fn init(gpa: Allocator, n: usize) !Tally {
        const p = try gpa.alloc(u32, n * 101);
        @memset(p, 0);
        return .{ .players = p };
    }

    pub fn deinit(t: *Tally, gpa: Allocator) void {
        gpa.free(t.players);
    }

    /// One player's games on champion index `c`
    pub fn add(t: *Tally, c: usize, games: u32, wins: u32, opts: Options) void {
        if (games < opts.min_games or games == 0) return;
        t.players[c * 101 + (200 * wins + games) / (2 * games)] += 1;
    }
};

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

pub fn make(arena: Allocator, t: *const Tally, st: *const Stats, opts: Options) !Spread {
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
        };
        for (by_pct, 0..) |n, p| ch.bins[(p + 5) / 10] += n;
        try list.append(arena, ch);
    }
    return .{ .min_games = opts.min_games, .min_players = opts.min_players, .champions = list.items };
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
    const opts: Options = .{};
    t.add(c, 10, 5, opts);
    t.add(c, 10, 6, opts);
    t.add(c, 20, 9, opts); // 45%: rounds into the 50% bin
    t.add(c, 12, 2, opts); // 17%
    t.add(c, 9, 9, opts); // too few games
    const s = try make(arena, &t, &st, opts);
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
