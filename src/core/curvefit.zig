//! Lane curve estimation (research/questions/curve-statistics-method.md), per role,
//! metric and minute, all closed form:
//! 1. Champion baseline: b_AB = e_A - e_B, ridge least squares on the pairs' means
//!    weighted by games; the ridge (sigma^2 / tau_e^2) by method of moments
//! 2. Each matchup's own mean shrunk toward it by k = sigma^2 / tau^2 pseudo-games;
//!    tau^2 by unweighted method of moments over pairs with 2+ games, each with its
//!    own variance (rare pairs vary more than common ones), floored
//! 3. Brackets, then experienced-only curves: the same shrink, nested, toward the
//!    curve one level up
//! 4. Whittaker smoother across minutes, strength chosen by a split-half test: fit on
//!    half the games, score against the other half's raw means
//! Per-minute errors of one curve are strongly correlated (gold is cumulative), so
//! leave-one-minute-out would pick too little smoothing; whole-game halves do not.

const std = @import("std");
const curvesfile = @import("curvesfile.zig");

const Lane = curvesfile.Lane;
const Bracket = curvesfile.Bracket;
const Experience = curvesfile.Experience;
const max_minutes = curvesfile.max_minutes;
const metrics = curvesfile.metrics;

/// Cap on k: tau^2 is floored at sigma^2 / max_k, since a point estimate near zero
/// would claim the champions explain everything
pub const max_k = 100;
const tau_floor: f64 = 1.0 / @as(f64, max_k);
/// Smoothing strengths tried, relative to a curve's mean minute weight
pub const lambdas = [_]f64{ 0, 0.1, 0.3, 1, 3, 10, 30, 100, 300 };
/// The minute the split-half report scores predictors at
pub const report_minute = curvesfile.lane_minute;
/// Pairs with at least this many games in the fitting half are "thick" in the report
pub const thick_games = 50;

/// Running sums of one metric at one minute over a set of games
pub const Stat = struct {
    n: f64 = 0,
    sum: f64 = 0,
    sumsq: f64 = 0,

    fn add(s: *Stat, x: f64) void {
        s.n += 1;
        s.sum += x;
        s.sumsq += x * x;
    }

    pub fn mean(s: Stat) f64 {
        return s.sum / s.n;
    }

    /// Sum of squares about the mean
    fn ss(s: Stat) f64 {
        return @max(0, s.sumsq - s.sum * s.sum / s.n);
    }

    fn remove(s: *Stat, o: Stat) void {
        s.n -= o.n;
        s.sum -= o.sum;
        s.sumsq -= o.sumsq;
    }

    /// Sample variance; n at least 2
    fn variance(s: Stat) f64 {
        return s.ss() / (s.n - 1);
    }
};

pub const Cells = [metrics][max_minutes]Stat;

/// Variance parameters of one level, metric and minute; k = sigma2 / tau2
pub const Param = extern struct {
    /// Game-to-game variance within a matchup (pooled)
    sigma2: f32 = 0,
    /// Variance of true matchup means around their prior (method of moments)
    tau2: f32 = 0,

    pub fn k(p: Param) f32 {
        return if (p.tau2 > 0) p.sigma2 / p.tau2 else 0;
    }
};

/// [bracket][level: all games, experienced][metric][minute]
pub const Params = [Bracket.count][2][metrics][max_minutes]Param;

/// One curve's estimate at one minute
pub const Point = struct {
    /// Games at this minute
    n: f32 = 0,
    mean: f32 = 0,
    /// Posterior variance of the mean
    @"var": f32 = 0,
    /// What the curve was shrunk toward
    prior: f32 = 0,
};

pub const Est = [metrics][max_minutes]Point;

/// Which games of a matchup a curve counts
pub const Filter = struct {
    bracket: Bracket = .all,
    experience: Experience = .any,
    half: Half = .both,
};

/// Split by a hash of the game, so a game's five lanes fall in the same half
pub const Half = enum { both, first, second };

fn inHalf(l: Lane, h: Half) bool {
    if (h == .both) return true;
    const first = std.hash.int(l.game) & 1 == 0;
    return first == (h == .first);
}

pub fn keeps(f: Filter, l: Lane) bool {
    if (f.bracket != .all and l.bracket != f.bracket) return false;
    if (f.experience == .a and !l.experienced_a) return false;
    if (f.experience == .b and !l.experienced_b) return false;
    return inHalf(l, f.half);
}

pub fn accumulate(lanes: []const Lane, f: Filter) Cells {
    var c: Cells = @splat(@splat(.{}));
    for (lanes) |l| {
        if (!keeps(f, l)) continue;
        for (0..l.minutes) |i| {
            c[0][i].add(@floatFromInt(l.gold[i]));
            c[1][i].add(@floatFromInt(l.xp[i]));
            c[2][i].add(@floatFromInt(l.cs[i]));
        }
    }
    return c;
}

/// A matchup within a role: champions as dense indices, lanes as a range
pub const Group = struct {
    start: u32,
    end: u32,
    a: u32,
    b: u32,

    fn mirror(g: Group) bool {
        return g.a == g.b;
    }
};

/// Split-half scores at report_minute: mean over pairs of (prediction - other half's
/// mean)^2, gold^2 etc. The other half's own noise (sigma^2 / n) is in every
/// predictor's score alike; `noise` is its mean
pub const Report = struct {
    pairs: usize = 0,
    lambda: [metrics]f64 = @splat(0),
    /// Pairs scored (games in both halves) and those thick in the fitting half
    scored: [metrics]usize = @splat(0),
    scored_thick: [metrics]usize = @splat(0),
    /// [metric][predictor]; predictors: 0 (role mean), baseline, raw mean, shrunk,
    /// shrunk and smoothed
    mse: [metrics][predictors]f64 = @splat(@splat(0)),
    mse_thick: [metrics][predictors]f64 = @splat(@splat(0)),
    noise: [metrics]f64 = @splat(0),
    noise_thick: [metrics]f64 = @splat(0),

    pub const predictors = 5;
    pub const names = [predictors][]const u8{ "zero", "baseline", "raw", "shrunk", "smoothed" };
};

pub const RoleFit = struct {
    params: Params = @splat(@splat(@splat(@splat(.{})))),
    lambda: [metrics]f64 = @splat(0),
    report: Report = .{},
    /// Per group x bracket x experience: index into ests, or none
    index: []u32,
    ests: std.ArrayList(Est) = .empty,

    const none = std.math.maxInt(u32);
    const per_group = Bracket.count * 3;

    pub fn deinit(f: *RoleFit, gpa: std.mem.Allocator) void {
        gpa.free(f.index);
        f.ests.deinit(gpa);
    }

    pub fn get(f: *const RoleFit, group: usize, bracket: Bracket, experience: Experience) ?*const Est {
        const i = f.index[slot(group, bracket, experience)];
        return if (i == none) null else &f.ests.items[i];
    }

    fn slot(group: usize, bracket: Bracket, experience: Experience) usize {
        return group * per_group + @as(usize, @intFromEnum(bracket)) * 3 + @intFromEnum(experience);
    }

    fn put(f: *RoleFit, gpa: std.mem.Allocator, group: usize, bracket: Bracket, experience: Experience, e: Est) !void {
        f.index[slot(group, bracket, experience)] = @intCast(f.ests.items.len);
        try f.ests.append(gpa, e);
    }
};

/// Estimates every curve of one role. `lanes` sorted by matchup, `groups` their ranges
/// with champions numbered 0..champions
pub fn fitRole(
    gpa: std.mem.Allocator,
    lanes: []const Lane,
    groups: []const Group,
    champions: usize,
) !RoleFit {
    var f: RoleFit = .{ .index = try gpa.alloc(u32, groups.len * RoleFit.per_group) };
    errdefer f.deinit(gpa);
    @memset(f.index, RoleFit.none);
    f.report.pairs = groups.len;

    const cells = try gpa.alloc(Cells, groups.len);
    defer gpa.free(cells);
    const est = try gpa.alloc(Est, groups.len);
    defer gpa.free(est);
    var params: [metrics][max_minutes]Param = undefined;

    // Smoothing strength from halves; also the report
    {
        const other = try gpa.alloc(Cells, groups.len);
        defer gpa.free(other);
        for (groups, cells, other) |g, *c, *o| {
            c.* = accumulate(lanes[g.start..g.end], .{ .half = .first });
            o.* = accumulate(lanes[g.start..g.end], .{ .half = .second });
        }
        try fitTop(gpa, groups, cells, champions, &params, est);
        chooseLambda(&f, groups, cells, other, est, &params);
    }

    for (groups, cells) |g, *c| c.* = accumulate(lanes[g.start..g.end], .{});
    try fitTop(gpa, groups, cells, champions, &f.params[0][0], est);
    for (est, 0..) |*e, gi| {
        smooth(e, f.lambda);
        try f.put(gpa, gi, .all, .any, e.*);
    }

    // Nested levels: units are (group, filter) with games, parents already fitted
    var units: std.ArrayList(Unit) = .empty;
    defer units.deinit(gpa);
    var unit_cells: std.ArrayList(Cells) = .empty;
    defer unit_cells.deinit(gpa);
    var rest_cells: std.ArrayList(Cells) = .empty;
    defer rest_cells.deinit(gpa);
    var unit_est: std.ArrayList(Est) = .empty;
    defer unit_est.deinit(gpa);
    for ([_]bool{ false, true }) |experienced| {
        for (std.enums.values(Bracket)) |bracket| {
            if (!experienced and bracket == .all) continue;
            units.clearRetainingCapacity();
            unit_cells.clearRetainingCapacity();
            rest_cells.clearRetainingCapacity();
            const kinds: []const Experience = if (experienced) &.{ .a, .b } else &.{.any};
            for (groups, 0..) |g, gi| for (kinds) |kind| {
                const filter: Filter = .{ .bracket = bracket, .experience = kind };
                if (!anyGames(lanes[g.start..g.end], filter)) continue;
                const c = accumulate(lanes[g.start..g.end], filter);
                // Brackets shrink toward all ranks, experienced toward their bracket
                const up: Filter = .{ .bracket = if (experienced) bracket else .all };
                const parent = f.get(gi, up.bracket, .any).?;
                try units.append(gpa, .{ .group = @intCast(gi), .experience = kind, .parent = parent.* });
                try unit_cells.append(gpa, c);
                var rest = accumulate(lanes[g.start..g.end], up);
                for (&rest, c) |*row, child| for (row, child) |*x, y| x.remove(y);
                try rest_cells.append(gpa, rest);
            };
            try unit_est.resize(gpa, units.items.len);
            nested(units.items, unit_cells.items, rest_cells.items, &f.params[@intFromEnum(bracket)][@intFromBool(experienced)], unit_est.items);
            for (units.items, unit_est.items) |u, *e| {
                smooth(e, f.lambda);
                try f.put(gpa, u.group, bracket, u.experience, e.*);
            }
        }
    }
    return f;
}

/// A lane that ended before its first minute still counts as a game of the curve
fn anyGames(lanes: []const Lane, f: Filter) bool {
    for (lanes) |l| if (keeps(f, l)) return true;
    return false;
}

const Unit = struct { group: u32, experience: Experience, parent: Est };

/// Top level: baseline from champion effects, each pair shrunk toward it
fn fitTop(
    gpa: std.mem.Allocator,
    groups: []const Group,
    cells: []const Cells,
    champions: usize,
    params: *[metrics][max_minutes]Param,
    est: []Est,
) !void {
    const effects = try gpa.alloc(f64, champions);
    defer gpa.free(effects);
    const games = try gpa.alloc(f64, champions);
    defer gpa.free(games);
    const matrix = try gpa.alloc(f64, champions * champions);
    defer gpa.free(matrix);

    for (0..metrics) |mi| for (0..max_minutes) |t| {
        const sigma2 = pooled(cells, mi, t);
        // A first fit with a token ridge only fixes the level (effects sum to ~0)
        championEffects(groups, cells, mi, t, 1, matrix, effects, games) catch unreachable;
        var tau_e: f64 = 0;
        var counted: f64 = 0;
        for (effects, games) |e, n| if (n > 0) {
            tau_e += e * e - sigma2 / n;
            counted += 1;
        };
        tau_e = @max(tau_floor * sigma2, if (counted > 0) tau_e / counted else 0);
        if (sigma2 > 0) championEffects(groups, cells, mi, t, @max(sigma2 / tau_e, 1), matrix, effects, games) catch unreachable;

        var tau2: f64 = 0;
        var pairs: f64 = 0;
        for (groups, cells) |g, c| {
            const s = c[mi][t];
            if (g.mirror() or s.n < 2) continue;
            const r = s.mean() - (effects[g.a] - effects[g.b]);
            tau2 += r * r - s.variance() / s.n;
            pairs += 1;
        }
        tau2 = @max(tau_floor * sigma2, if (pairs > 0) tau2 / pairs else 0);
        params[mi][t] = .{ .sigma2 = @floatCast(sigma2), .tau2 = @floatCast(tau2) };
        for (groups, cells, est) |g, c, *e| {
            const prior = if (g.mirror()) 0 else effects[g.a] - effects[g.b];
            e[mi][t] = shrink(c[mi][t], prior, 0, sigma2, tau2);
        }
    };
}

/// Nested level: each unit shrunk toward its parent curve (after smoothing). tau^2
/// compares a unit with the rest of its parent's games (`rest`), not the parent
/// itself, which holds the unit's own games: a bracket with most of a matchup's games
/// would otherwise look like its parent and get no room of its own
fn nested(
    units: []const Unit,
    cells: []const Cells,
    rest: []const Cells,
    params: *[metrics][max_minutes]Param,
    est: []Est,
) void {
    for (0..metrics) |mi| for (0..max_minutes) |t| {
        const sigma2 = pooled(cells, mi, t);
        var tau2: f64 = 0;
        var counted: f64 = 0;
        for (cells, rest) |c, o| {
            const s = c[mi][t];
            const r = o[mi][t];
            if (s.n < 2 or r.n < 2) continue;
            const d = s.mean() - r.mean();
            tau2 += d * d - s.variance() / s.n - r.variance() / r.n;
            counted += 1;
        }
        tau2 = @max(tau_floor * sigma2, if (counted > 0) tau2 / counted else 0);
        params[mi][t] = .{ .sigma2 = @floatCast(sigma2), .tau2 = @floatCast(tau2) };
        for (units, cells, est) |u, c, *e| {
            const p = u.parent[mi][t];
            e[mi][t] = shrink(c[mi][t], p.mean, p.@"var", sigma2, tau2);
        }
    };
}

/// Posterior mean and variance of a unit's true mean: prior N(prior, tau2 +
/// prior_var), games N(true, sigma2 / n)
fn shrink(s: Stat, prior: f64, prior_var: f64, sigma2: f64, tau2: f64) Point {
    const spread = tau2 + prior_var;
    if (s.n == 0) return .{ .mean = @floatCast(prior), .@"var" = @floatCast(spread), .prior = @floatCast(prior) };
    if (sigma2 == 0) return .{ .n = @floatCast(s.n), .mean = @floatCast(s.mean()), .prior = @floatCast(prior) };
    const precision = s.n / sigma2 + 1 / spread;
    const weight = (s.n / sigma2) / precision;
    return .{
        .n = @floatCast(s.n),
        .mean = @floatCast(prior + weight * (s.mean() - prior)),
        .@"var" = @floatCast(1 / precision),
        .prior = @floatCast(prior),
    };
}

/// Within-matchup variance: sums of squares about each mean over sum of (n - 1)
fn pooled(cells: []const Cells, mi: usize, t: usize) f64 {
    var ss: f64 = 0;
    var df: f64 = 0;
    for (cells) |c| {
        const s = c[mi][t];
        if (s.n < 2) continue;
        ss += s.ss();
        df += s.n - 1;
    }
    return if (df > 0) ss / df else 0;
}

/// Effects minimising sum over pairs of n (mean - e_a + e_b)^2 + ridge sum e^2
fn championEffects(
    groups: []const Group,
    cells: []const Cells,
    mi: usize,
    t: usize,
    ridge: f64,
    matrix: []f64,
    effects: []f64,
    games: []f64,
) !void {
    const c_n = effects.len;
    @memset(matrix, 0);
    @memset(effects, 0);
    @memset(games, 0);
    for (groups, cells) |g, c| {
        const s = c[mi][t];
        if (g.mirror() or s.n == 0) continue;
        matrix[g.a * c_n + g.a] += s.n;
        matrix[g.b * c_n + g.b] += s.n;
        matrix[g.a * c_n + g.b] -= s.n;
        matrix[g.b * c_n + g.a] -= s.n;
        effects[g.a] += s.sum;
        effects[g.b] -= s.sum;
        games[g.a] += s.n;
        games[g.b] += s.n;
    }
    for (0..c_n) |i| matrix[i * c_n + i] += ridge;
    try cholSolve(matrix, effects);
}

/// Solves a x = b in place for symmetric positive definite a (n x n, row major); a
/// is overwritten by its Cholesky factor
pub fn cholSolve(a: []f64, b: []f64) error{NotPositiveDefinite}!void {
    const n = b.len;
    for (0..n) |j| {
        var d = a[j * n + j];
        for (0..j) |k| d -= a[j * n + k] * a[j * n + k];
        if (d <= 0) return error.NotPositiveDefinite;
        d = @sqrt(d);
        a[j * n + j] = d;
        for (j + 1..n) |i| {
            var s = a[i * n + j];
            for (0..j) |k| s -= a[i * n + k] * a[j * n + k];
            a[i * n + j] = s / d;
        }
    }
    for (0..n) |i| {
        var s = b[i];
        for (0..i) |k| s -= a[i * n + k] * b[k];
        b[i] = s / a[i * n + i];
    }
    var i = n;
    while (i > 0) {
        i -= 1;
        var s = b[i];
        for (i + 1..n) |k| s -= a[k * n + i] * b[k];
        b[i] = s / a[i * n + i];
    }
}

/// Minutes a curve has games at (games only drop out as they end)
fn reach(e: *const Est, mi: usize) usize {
    var last: usize = 0;
    while (last < max_minutes and e[mi][last].n > 0) last += 1;
    return last;
}

fn smooth(e: *Est, lambda: [metrics]f64) void {
    for (0..metrics) |mi| {
        const last = reach(e, mi);
        if (last < 3 or lambda[mi] == 0) continue;
        var y: [max_minutes]f64 = undefined;
        var w: [max_minutes]f64 = undefined;
        var z: [max_minutes]f64 = undefined;
        for (0..last) |t| {
            y[t] = e[mi][t].mean;
            w[t] = 1 / @max(e[mi][t].@"var", 1e-6);
        }
        whittaker(y[0..last], w[0..last], lambda[mi], z[0..last]);
        for (0..last) |t| e[mi][t].mean = @floatCast(z[t]);
    }
}

/// Solves (W + lambda D'D) z = W y, D the second-difference matrix, weights scaled to
/// mean 1 so lambda means the same for every curve. At most max_minutes points
pub fn whittaker(y: []const f64, w: []const f64, lambda: f64, z: []f64) void {
    const n = y.len;
    std.debug.assert(n <= max_minutes and w.len == n and z.len == n);
    var total: f64 = 0;
    for (w) |x| total += x;
    const scale = @as(f64, @floatFromInt(n)) / total;
    var a: [max_minutes * max_minutes]f64 = @splat(0);
    for (0..n) |i| {
        a[i * n + i] = w[i] * scale;
        z[i] = w[i] * scale * y[i];
    }
    if (n >= 3) for (0..n - 2) |i| {
        const d = [3]f64{ 1, -2, 1 };
        for (0..3) |p| for (0..3) |q| {
            a[(i + p) * n + i + q] += lambda * d[p] * d[q];
        };
    };
    cholSolve(a[0 .. n * n], z) catch @memcpy(z, y);
}

fn chooseLambda(
    f: *RoleFit,
    groups: []const Group,
    fit: []const Cells,
    other: []const Cells,
    est: []const Est,
    params: *const [metrics][max_minutes]Param,
) void {
    const r = &f.report;
    for (0..metrics) |mi| {
        var best: f64 = std.math.inf(f64);
        for (lambdas) |lambda| {
            var score: f64 = 0;
            for (groups, est, other) |g, e, o| {
                if (g.mirror()) continue;
                var one = e;
                var only: [metrics]f64 = @splat(0);
                only[mi] = lambda;
                smooth(&one, only);
                for (0..max_minutes) |t| {
                    const s = o[mi][t];
                    const sigma2: f64 = params[mi][t].sigma2;
                    if (s.n == 0 or one[mi][t].n == 0 or sigma2 == 0) continue;
                    const d = one[mi][t].mean - s.mean();
                    // Per sigma^2, so late minutes do not outweigh early ones
                    score += (d * d - sigma2 / s.n) / sigma2;
                }
            }
            if (score < best) {
                best = score;
                f.lambda[mi] = lambda;
            }
        }
        r.lambda[mi] = f.lambda[mi];

        const t = report_minute - 1;
        const sigma2: f64 = params[mi][t].sigma2;
        for (groups, fit, other, est) |g, c, o, e| {
            const sa = c[mi][t];
            const sb = o[mi][t];
            if (g.mirror() or sa.n == 0 or sb.n == 0) continue;
            var smoothed = e;
            var only: [metrics]f64 = @splat(0);
            only[mi] = f.lambda[mi];
            smooth(&smoothed, only);
            const p = e[mi][t];
            const preds = [Report.predictors]f64{ 0, p.prior, sa.mean(), p.mean, smoothed[mi][t].mean };
            const thick = sa.n >= thick_games;
            r.scored[mi] += 1;
            r.noise[mi] += sigma2 / sb.n;
            if (thick) {
                r.scored_thick[mi] += 1;
                r.noise_thick[mi] += sigma2 / sb.n;
            }
            for (preds, 0..) |x, pi| {
                const d = x - sb.mean();
                r.mse[mi][pi] += d * d;
                if (thick) r.mse_thick[mi][pi] += d * d;
            }
        }
        if (r.scored[mi] > 0) {
            const n: f64 = @floatFromInt(r.scored[mi]);
            for (&r.mse[mi]) |*x| x.* /= n;
            r.noise[mi] /= n;
        }
        if (r.scored_thick[mi] > 0) {
            const n: f64 = @floatFromInt(r.scored_thick[mi]);
            for (&r.mse_thick[mi]) |*x| x.* /= n;
            r.noise_thick[mi] /= n;
        }
    }
}

const testing = std.testing;

test "cholesky solve" {
    var a = [_]f64{ 4, 2, 2, 3 };
    var b = [_]f64{ 2, 1 };
    try cholSolve(&a, &b);
    try testing.expectApproxEqAbs(0.5, b[0], 1e-9);
    try testing.expectApproxEqAbs(0, b[1], 1e-9);
}

test "whittaker: lambda 0 keeps the data, large lambda fits a line" {
    const y = [_]f64{ 0, 3, 1, 4, 2, 5 };
    const w: [6]f64 = @splat(1);
    var z: [6]f64 = undefined;
    whittaker(&y, &w, 0, &z);
    for (y, z) |a, b| try testing.expectApproxEqAbs(a, b, 1e-9);
    whittaker(&y, &w, 1e9, &z);
    // Least squares line through the points: 5/7 + 5/7 t
    for (z, 0..) |b, t| try testing.expectApproxEqAbs(5.0 / 7.0 * (1 + @as(f64, @floatFromInt(t))), b, 1e-3);
}

test "shrink" {
    var s: Stat = .{};
    for ([_]f64{ 100, 300 }) |x| s.add(x);
    // n 2, sigma2 400, tau2 100: k 4, weight 1/3 toward the mean 200 from prior 50
    const p = shrink(s, 50, 0, 400, 100);
    try testing.expectApproxEqAbs(100, p.mean, 1e-4);
    try testing.expectApproxEqAbs(400.0 / 6.0, p.@"var", 1e-3);
    try testing.expectEqual(50, shrink(.{}, 50, 0, 400, 100).mean);
}

test "a thin matchup leans on the champions' baseline, a thick one on its games" {
    const gpa = testing.allocator;
    // Champion effects at every minute: 0 -> +300, 1 -> 0, 2 -> -300; game noise +-400
    const effect = [_]i16{ 300, 0, -300 };
    var lanes: std.ArrayList(Lane) = .empty;
    defer lanes.deinit(gpa);
    var groups: std.ArrayList(Group) = .empty;
    defer groups.deinit(gpa);
    // (a, b, games, extra matchup effect)
    const pairs = [_]struct { u32, u32, u32, i16 }{ .{ 0, 1, 400, 0 }, .{ 0, 2, 400, 100 }, .{ 1, 2, 400, -100 }, .{ 1, 2, 1, 0 } };
    var game: u32 = 0;
    for (pairs, 0..) |p, pi| {
        const start: u32 = @intCast(lanes.items.len);
        for (0..p[2]) |i| {
            var l: Lane = .{ .role = .top, .bracket = .mid, .a = p[0], .b = p[1], .a_won = true, .minutes = 15, .game = game };
            game += 1;
            const noise: i16 = if (i % 2 == 0) 400 else -400;
            // The lone game of the last "pair" is an outlier
            const value: i16 = if (pi == 3) 3000 else effect[p[0]] - effect[p[1]] + p[3] + noise;
            for (0..15) |t| {
                l.gold[t] = value;
                l.xp[t] = value;
                l.cs[t] = @divTrunc(value, 100);
            }
            try lanes.append(gpa, l);
        }
        try groups.append(gpa, .{ .start = start, .end = @intCast(lanes.items.len), .a = p[0], .b = p[1] });
    }
    var f = try fitRole(gpa, lanes.items, groups.items, 3);
    defer f.deinit(gpa);
    const t = report_minute - 1;
    const p = f.params[0][0][0][t];
    try testing.expectApproxEqRel(400 * 400, p.sigma2, 0.01);
    // True matchup effects 0, 100, -100 around the baseline: tau ~ 80
    try testing.expect(p.tau2 > 50 * 50 and p.tau2 < 120 * 120);
    // Thick: close to its own mean (600 + 100)
    try testing.expectApproxEqAbs(700, f.get(1, .all, .any).?[0][t].mean, 40);
    // Thin: an outlier of 3000 pulled most of the way to the 1-2 baseline (~300)
    const thin = f.get(3, .all, .any).?[0][t];
    try testing.expect(thin.mean < 600);
    try testing.expectEqual(1, thin.n);
    try testing.expect(f.get(0, .low, .any) == null);
    try testing.expect(f.get(0, .mid, .any) != null);
}
