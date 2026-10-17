//! win-draft: the shipped draft model (src/core/score.zig, Options defaults since 17 Oct)
//! as a candidate, so lab terms can be measured beyond what the site and app already use.
//! A copy, as a candidate imports only std and api: keep in step with score.zig's
//! Context.base, pairDelta and draftTerms, and with its Options defaults.
//!   base:    champion-role win rate as log-odds, pulled to 50% by base_prior games
//!   duo:     each ally pair's smoothed log-odds minus the two bases' sum
//!   matchup: each cross-team pair's smoothed log-odds minus base minus base; lane
//!            opponents (same role) weighted apart from the rest
//! Blue's terms minus red's, weighted; no side intercept (the shipped model has none)

const std = @import("std");
const api = @import("api");

pub const name = "win-draft";
pub const scope: api.Scope = .champ_select;

const base_prior: f64 = 50;
const pair_prior: f64 = 3200;
const w_base: f64 = 0.943;
const w_duo: f64 = 0.765;
const w_lane: f64 = 2.025;
const w_matchup: f64 = 1.009;

const Counts = struct { games: f64 = 0, wins: f64 = 0 };
const Map = std.AutoHashMapUnmanaged(u64, Counts);

pub const Model = struct {
    base: Map = .empty,
    ally: Map = .empty,
    /// From the first champion's side
    enemy: Map = .empty,
};

fn cell(c: u32, r: usize) u64 {
    return (@as(u64, @intCast(r)) << 16) | c;
}

fn pair(a: u64, b: u64) u64 {
    return (a << 32) | b;
}

fn add(gpa: std.mem.Allocator, m: *Map, k: u64, won: f64) !void {
    const e = try m.getOrPut(gpa, k);
    if (!e.found_existing) e.value_ptr.* = .{};
    e.value_ptr.games += 1;
    e.value_ptr.wins += won;
}

pub fn fit(gpa: std.mem.Allocator, train: *const api.Train, _: api.Options) !Model {
    // Blue's result per game, from any row of it
    const blue = try gpa.alloc(f32, train.games.len);
    defer gpa.free(blue);
    @memset(blue, std.math.nan(f32));
    for (train.rows) |r| {
        const y = r.y[api.outcomeIndex(.win)];
        if (std.math.isNan(y)) continue;
        blue[r.game] = if (r.side == 0) y else 1 - y;
    }
    var m: Model = .{};
    errdefer deinit(&m, gpa);
    for (train.games, blue) |g, b| {
        if (std.math.isNan(b)) continue;
        for (0..2) |s| {
            const won: f64 = if (s == 0) b else 1 - b;
            for (g.teams[s], 0..) |c, r| {
                if (c == 0) continue;
                const a = cell(c, r);
                try add(gpa, &m.base, a, won);
                for (g.teams[s][r + 1 ..], r + 1..) |c2, r2| if (c2 != 0) {
                    try add(gpa, &m.ally, pair(a, cell(c2, r2)), won);
                };
                for (g.teams[1 - s], 0..) |e, re| if (e != 0) {
                    try add(gpa, &m.enemy, pair(a, cell(e, re)), won);
                };
            }
        }
    }
    return m;
}

fn logit(p: f64) f64 {
    const q = std.math.clamp(p, 1e-6, 1 - 1e-6);
    return @log(q / (1 - q));
}

fn sigmoid(x: f64) f64 {
    return 1 / (1 + @exp(-x));
}

fn base(m: *const Model, a: u64) f64 {
    const n = m.base.get(a) orelse Counts{};
    return logit((n.wins + 0.5 * base_prior) / (n.games + base_prior));
}

fn delta(n: Counts, expected: f64) f64 {
    const games = n.games + pair_prior;
    return logit((n.wins + pair_prior * sigmoid(expected)) / games) - expected;
}

/// Blue's log-odds, weighted as score.draftWin
pub fn blueLogit(m: *const Model, teams: [2][5]u32) f64 {
    var t: f64 = 0;
    for (0..2) |s| {
        const sign: f64 = if (s == 0) 1 else -1;
        for (teams[s], 0..) |c, r| {
            if (c == 0) continue;
            const a = cell(c, r);
            const ba = base(m, a);
            t += sign * w_base * ba;
            for (teams[s][r + 1 ..], r + 1..) |c2, r2| if (c2 != 0) {
                const b = cell(c2, r2);
                const n = m.ally.get(pair(a, b)) orelse Counts{};
                t += sign * w_duo * delta(n, ba + base(m, b));
            };
        }
    }
    for (teams[0], 0..) |c, r| {
        if (c == 0) continue;
        const a = cell(c, r);
        const ba = base(m, a);
        for (teams[1], 0..) |e, re| if (e != 0) {
            const b = cell(e, re);
            const n = m.enemy.get(pair(a, b)) orelse Counts{};
            const w = if (r == re) w_lane else w_matchup;
            t += w * delta(n, ba - base(m, b));
        };
    }
    return t;
}

pub fn predict(m: *const Model, q: *const api.Query) api.Prediction {
    var out: api.Prediction = api.no_opinion;
    const p = sigmoid(blueLogit(m, q.teams));
    out[api.outcomeIndex(.win)] = @floatCast(if (q.side == 0) p else 1 - p);
    return out;
}

pub fn deinit(m: *Model, gpa: std.mem.Allocator) void {
    m.base.deinit(gpa);
    m.ally.deinit(gpa);
    m.enemy.deinit(gpa);
}

test "an unseen draft is even and sides mirror" {
    const gpa = std.testing.allocator;
    const games = [_]api.Game{.{
        .start = 0,
        .patch = 0,
        .platform = 0,
        .teams = .{ .{ 1, 2, 3, 4, 5 }, .{ 6, 7, 8, 9, 10 } },
        .ranks = @splat(@splat(null)),
        .exp = @splat(@splat(.{})),
    }};
    var y: [api.outcome_count]f32 = @splat(std.math.nan(f32));
    y[api.outcomeIndex(.win)] = 1;
    const rows = [_]api.Row{.{ .game = 0, .side = 0, .role = .top, .champion = 1, .rank = null, .exp = .{}, .y = y }};
    var m = try fit(gpa, &.{ .games = &games, .rows = &rows }, .{});
    defer deinit(&m, gpa);
    try std.testing.expectApproxEqAbs(0, blueLogit(&m, .{ @splat(20), @splat(21) }), 1e-12);
    const t = games[0].teams;
    try std.testing.expect(blueLogit(&m, t) > 0);
    try std.testing.expectApproxEqAbs(blueLogit(&m, t), -blueLogit(&m, .{ t[1], t[0] }), 1e-9);
}
