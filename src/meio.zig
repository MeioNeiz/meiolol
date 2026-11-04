//! Meio, the estimate mode (docs/plan/estimates.md E3-E6, J34): one number per cell from
//! every game, old patches moved by what the newest patch changed, every rank and region
//! adjusted to the one picked. E2's truth test (src/truth.zig) calls fit() per origin day
//! and rate() per cell; a cell kind ships only once it beats both raw windows there.
//!
//! E3, champion-role win rate, per champion-role on the logit scale:
//!   a (shared across patches) + d[patch] + b[bracket] + g (EUW1)
//! each a random effect shrunk to 0 with one variance per term kind, estimated from the
//! fit (MacKay's fixed point, as src/additive.zig and patch-transfer A2, which beat the
//! changed-champion prior and the warm start on 16.21: docs/model.md "The latest patch
//! day by day on 16.21"). A champion-role's terms touch only its own games, so each is
//! a tiny Newton fit (Laplace posterior); the variances couple them. The newest patch's
//! number is a + d[0]: on day 0 d[0] is 0 and the shared term carries it, and d[0] takes
//! over as the patch's games arrive. Older games can weigh less (half_life)

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const no_gold = std.math.minInt(i32);

/// Every cell kind truth scores; the order keeps truth's keys stable. Rank is the bracket
/// dimension of every kind, not a kind
pub const Kind = enum(u3) {
    /// Champion-role win rate
    champion,
    /// Win rate against the lane opponent (b: opponent cr)
    matchup,
    /// Bottom with its support, win rate (b: support cr)
    duo,
    /// Lane gold difference at 14 against the opponent (an average; b: opponent cr)
    gold14,
    /// Share of a champion-role's games with a finished item (b: item)
    build,
    /// Win rate with a finished item (b: item)
    item,
    /// Win rate with a keystone (b: keystone)
    keystone,
    /// Share of a champion-role's games with a keystone (b: keystone)
    rune,

    pub const count = 8;
};

/// One player in one game
pub const Row = struct {
    /// Days since the newest patch's start, floored
    day: i16,
    /// champion | role << 13
    cr: u16,
    /// The lane opponent's cr; 0 none
    opp: u16 = 0,
    /// A bottom's support's cr; 0 none
    ally: u16 = 0,
    keystone: u16 = 0,
    gold: i32 = no_gold,
    items: [6]u16 = @splat(0),
    win: bool,
    euw: bool,
    /// 0 the newest patch, 1 the one before, ...
    patch: u8,
    /// 0 unknown, else curvesfile.Bracket (1 low, 2 mid, 3 high)
    bracket: u2,
};

pub const Options = struct {
    /// A game's weight halves every this many days before the origin; 0: all weigh 1
    half_life: f64 = 0,
    /// Patch slots: the newest, the one before, ...; older patches share the last
    patches: u8 = 3,
    /// Prior sds on the logit scale, by term; 0: estimated from the fit
    sd: [n_terms]f64 = @splat(0),
    rounds: u8 = 40,
};

/// Term kinds, one variance each
pub const Term = enum { main, patch, bracket, euw };
const n_terms = 4;
const max_patches = 6;
const max_k = 1 + max_patches + 3 + 1;

/// 80% interval
const z80 = 1.2815515655446004;

pub const Estimate = struct {
    p: f64,
    lo: f64,
    hi: f64,
    /// Games in the cell's own slice (newest patch, this region and bracket), unweighted
    own: f64,
};

/// Weighted games and wins of one champion-role, by patch slot, bracket and EUW1
const Counts = struct {
    n: [max_patches][4][2]f64 = @splat(@splat(@splat(0))),
    k: [max_patches][4][2]f64 = @splat(@splat(@splat(0))),
    /// Unweighted games, the newest patch only
    own: [4][2]f64 = @splat(@splat(0)),
};

const Fitted = struct {
    theta: [max_k]f64 = @splat(0),
    cov: [max_k * max_k]f64 = @splat(0),
};

pub const Model = struct {
    patches: u8,
    sd: [n_terms]f64,
    index: std.AutoHashMapUnmanaged(u16, u32) = .empty,
    counts: []Counts = &.{},
    fitted: []Fitted = &.{},

    pub fn deinit(m: *Model, gpa: Allocator) void {
        m.index.deinit(gpa);
        gpa.free(m.counts);
        gpa.free(m.fitted);
    }

    /// The newest patch's number for a cell; region 1 is EUW1, bracket 0 all ranks. null:
    /// a kind not estimated yet, or a champion-role with no games
    pub fn rate(m: *const Model, kind: Kind, region: u1, bracket: u2, a: u16, b: u32) ?Estimate {
        _ = b;
        if (kind != .champion) return null;
        const i = m.index.get(a) orelse return null;
        const k = nParams(m.patches);
        var x: [max_k]f64 = @splat(0);
        design(m.patches, 0, bracket, region, &x);
        const f = &m.fitted[i];
        var eta: f64 = 0;
        var v: f64 = 0;
        for (0..k) |r| {
            eta += x[r] * f.theta[r];
            for (0..k) |c| v += x[r] * f.cov[r * k + c] * x[c];
        }
        const c = &m.counts[i];
        var own: f64 = 0;
        for (0..4) |br| {
            if (bracket != 0 and br != bracket) continue;
            own += c.own[br][1];
            if (region == 0) own += c.own[br][0];
        }
        const s = @sqrt(@max(v, 0));
        return .{
            // Averaged over the posterior (probit approximation), not the mean's rate
            .p = sigmoid(eta / @sqrt(1 + std.math.pi * v / 8)),
            .lo = sigmoid(eta - z80 * s),
            .hi = sigmoid(eta + z80 * s),
            .own = own,
        };
    }
};

fn nParams(patches: u8) usize {
    return 1 + patches + 3 + 1;
}

fn termOf(patches: u8, j: usize) Term {
    if (j == 0) return .main;
    if (j <= patches) return .patch;
    if (j <= patches + 3) return .bracket;
    return .euw;
}

fn design(patches: u8, patch: usize, bracket: usize, euw: usize, x: *[max_k]f64) void {
    x.* = @splat(0);
    x[0] = 1;
    x[1 + patch] = 1;
    if (bracket != 0) x[patches + bracket] = 1;
    if (euw != 0) x[patches + 4] = 1;
}

pub fn sigmoid(z: f64) f64 {
    return 1 / (1 + @exp(-z));
}

/// Fits on every row with day < before_day
pub fn fit(gpa: Allocator, rows: []const Row, before_day: i32, opts: Options) !Model {
    std.debug.assert(opts.patches >= 1 and opts.patches <= max_patches);
    var m: Model = .{ .patches = opts.patches, .sd = opts.sd };
    errdefer m.deinit(gpa);
    var counts: std.ArrayList(Counts) = .empty;
    defer counts.deinit(gpa);
    const ln2 = @log(2.0);
    for (rows) |r| {
        if (r.day >= before_day) continue;
        const e = try m.index.getOrPut(gpa, r.cr);
        if (!e.found_existing) {
            e.value_ptr.* = @intCast(counts.items.len);
            try counts.append(gpa, .{});
        }
        const c = &counts.items[e.value_ptr.*];
        const age: f64 = @floatFromInt(before_day - 1 - r.day);
        const w = if (opts.half_life > 0) @exp(-ln2 * age / opts.half_life) else 1;
        const p = @min(r.patch, opts.patches - 1);
        const euw: usize = @intFromBool(r.euw);
        c.n[p][r.bracket][euw] += w;
        if (r.win) c.k[p][r.bracket][euw] += w;
        if (r.patch == 0) c.own[r.bracket][euw] += 1;
    }
    m.counts = try counts.toOwnedSlice(gpa);
    m.fitted = try gpa.alloc(Fitted, m.counts.len);
    @memset(m.fitted, .{});

    var sd: [n_terms]f64 = undefined;
    for (&sd, opts.sd) |*s, o| s.* = if (o > 0) o else 0.1;
    const k = nParams(opts.patches);
    for (0..opts.rounds) |_| {
        var sum_sq: [n_terms]f64 = @splat(0);
        var gamma: [n_terms]f64 = @splat(0);
        for (m.counts, m.fitted) |*c, *f| {
            newton(c, f, opts.patches, sd);
            for (0..k) |j| {
                const t = @backingInt(termOf(opts.patches, j));
                sum_sq[t] += f.theta[j] * f.theta[j];
                gamma[t] += 1 - f.cov[j * k + j] / (sd[t] * sd[t]);
            }
        }
        var moved: f64 = 0;
        for (&sd, opts.sd, sum_sq, gamma) |*s, o, q, g| {
            if (o > 0) continue;
            // A floor keeps a term that the data can't see from collapsing to exactly 0
            const new = @max(@sqrt(q / @max(g, 1e-9)), 1e-4);
            moved = @max(moved, @abs(new - s.*) / s.*);
            s.* = new;
        }
        if (moved < 1e-4) break;
    }
    for (m.counts, m.fitted) |*c, *f| newton(c, f, opts.patches, sd);
    m.sd = sd;
    return m;
}

/// Newton steps on one champion-role's penalised log likelihood from its current terms;
/// leaves the posterior covariance (inverse Hessian) in f.cov
fn newton(c: *const Counts, f: *Fitted, patches: u8, sd: [n_terms]f64) void {
    const k = nParams(patches);
    var prec: [max_k]f64 = undefined;
    for (0..k) |j| {
        const s = sd[@backingInt(termOf(patches, j))];
        prec[j] = 1 / (s * s);
    }
    var x: [max_k]f64 = undefined;
    for (0..8) |_| {
        var grad: [max_k]f64 = @splat(0);
        var hess: [max_k * max_k]f64 = @splat(0);
        for (0..k) |j| {
            grad[j] = -prec[j] * f.theta[j];
            hess[j * k + j] = prec[j];
        }
        for (0..patches) |p| for (0..4) |br| for (0..2) |e| {
            const n = c.n[p][br][e];
            if (n == 0) continue;
            design(patches, p, br, e, &x);
            var eta: f64 = 0;
            for (0..k) |j| eta += x[j] * f.theta[j];
            const q = sigmoid(eta);
            const r = c.k[p][br][e] - n * q;
            const wt = n * q * (1 - q);
            for (0..k) |i| {
                if (x[i] == 0) continue;
                grad[i] += r;
                for (0..k) |j| hess[i * k + j] += wt * x[j];
            }
        };
        invert(hess[0 .. k * k], k, f.cov[0 .. k * k]);
        var step: f64 = 0;
        for (0..k) |i| {
            var s: f64 = 0;
            for (0..k) |j| s += f.cov[i * k + j] * grad[j];
            f.theta[i] += s;
            step = @max(step, @abs(s));
        }
        if (step < 1e-10) break;
    }
}

/// out = a^-1 for a symmetric positive definite k x k matrix (Gauss-Jordan; a is
/// overwritten)
fn invert(a: []f64, k: usize, out: []f64) void {
    @memset(out, 0);
    for (0..k) |i| out[i * k + i] = 1;
    for (0..k) |col| {
        const pivot = a[col * k + col];
        for (0..k) |j| {
            a[col * k + j] /= pivot;
            out[col * k + j] /= pivot;
        }
        for (0..k) |r| {
            if (r == col) continue;
            const f = a[r * k + col];
            if (f == 0) continue;
            for (0..k) |j| {
                a[r * k + j] -= f * a[col * k + j];
                out[r * k + j] -= f * out[col * k + j];
            }
        }
    }
}

fn testRow(cr: u16, day: i16, patch: u8, bracket: u2, win: bool) Row {
    return .{ .day = day, .cr = cr, .win = win, .euw = false, .patch = patch, .bracket = bracket };
}

test "invert" {
    var a = [_]f64{ 4, 2, 2, 3 };
    var out: [4]f64 = undefined;
    invert(&a, 2, &out);
    // [[4,2],[2,3]]^-1 = [[3,-2],[-2,4]] / 8
    for ([_]f64{ 3.0 / 8.0, -2.0 / 8.0, -2.0 / 8.0, 4.0 / 8.0 }, out) |want, got| {
        try std.testing.expectApproxEqAbs(want, got, 1e-12);
    }
}

test "the newest patch's games pull its number away from the old patch" {
    const gpa = std.testing.allocator;
    var rows: std.ArrayList(Row) = .empty;
    defer rows.deinit(gpa);
    // 40 champion-roles at 50% on the old patch; on the new one champions 1-10 move to
    // 60% or 40% in turn, the rest stay
    var prng: std.Random.DefaultPrng = .init(7);
    const rand = prng.random();
    for (1..41) |ch| {
        const cr: u16 = @intCast(ch);
        for (0..2000) |_| try rows.append(gpa, testRow(cr, -5, 1, 2, rand.float(f64) < 0.5));
        const p: f64 = if (ch > 10) 0.5 else if (ch % 2 == 1) 0.6 else 0.4;
        for (0..1000) |_| try rows.append(gpa, testRow(cr, 0, 0, 2, rand.float(f64) < p));
    }
    // Day 0: no newest-patch games yet, so champion 1 reads as the old 50%
    var before = try fit(gpa, rows.items, 0, .{});
    defer before.deinit(gpa);
    const e0 = before.rate(.champion, 0, 0, 1, 0).?;
    try std.testing.expectApproxEqAbs(0.5, e0.p, 0.03);
    try std.testing.expectEqual(@as(f64, 0), e0.own);
    // Day 1: its 1000 new games move it most of the way to 60%
    var after = try fit(gpa, rows.items, 1, .{});
    defer after.deinit(gpa);
    const e1 = after.rate(.champion, 0, 0, 1, 0).?;
    try std.testing.expect(e1.p > 0.56 and e1.p < 0.62);
    try std.testing.expect(e1.lo < e1.p and e1.p < e1.hi);
    try std.testing.expectEqual(@as(f64, 1000), e1.own);
    // Kinds not estimated yet give null
    // An unmoved one lands between its old and new raw rates
    const c20 = after.counts[after.index.get(20).?];
    const old = c20.k[1][2][0] / c20.n[1][2][0];
    const new = c20.k[0][2][0] / c20.n[0][2][0];
    const e20 = after.rate(.champion, 0, 2, 20, 0).?.p;
    try std.testing.expect((e20 - old) * (new - e20) > 0);
    try std.testing.expectEqual(@as(?Estimate, null), after.rate(.matchup, 0, 0, 1, 2));
    try std.testing.expectEqual(@as(?Estimate, null), after.rate(.champion, 0, 0, 99, 0));
    // The planted moves are 0.41 on the logit for a quarter of them: sd about 0.2
    const sd = after.sd[@backingInt(Term.patch)];
    try std.testing.expect(sd > 0.12 and sd < 0.3);
}
