//! L2-penalised logistic regression on sparse rows, by Newton's method with a dense
//! Hessian (Cholesky). For up to a few thousand features: champion-role ratings and
//! draft features, trained on the box. Feature 0 is the intercept, not penalised.

const std = @import("std");

pub const Feature = struct { i: u32, v: f64 };

/// Few features per game (10 champion slots plus extras)
pub const max_row = 32;

pub const Row = struct {
    feats: [max_row]Feature = undefined,
    n: u8 = 0,
    y: f64,
    /// Added to the linear predictor, not learned (eg another model's log-odds)
    offset: f64 = 0,

    pub fn add(r: *Row, i: u32, v: f64) void {
        r.feats[r.n] = .{ .i = i, .v = v };
        r.n += 1;
    }

    pub fn dot(r: *const Row, w: []const f64) f64 {
        var s = r.offset;
        for (r.feats[0..r.n]) |f| s += w[f.i] * f.v;
        return s;
    }
};

/// Weights for `d` features (caller frees). `l2` per feature (not the intercept)
pub fn fit(gpa: std.mem.Allocator, d: usize, rows: []const Row, l2: f64) ![]f64 {
    const w = try gpa.alloc(f64, d);
    errdefer gpa.free(w);
    @memset(w, 0);
    const hess = try gpa.alloc(f64, d * d);
    defer gpa.free(hess);
    const grad = try gpa.alloc(f64, d);
    defer gpa.free(grad);

    var prev = std.math.inf(f64);
    for (0..25) |_| {
        @memset(hess, 0);
        @memset(grad, 0);
        var loss: f64 = 0;
        for (rows) |*r| {
            const x = r.dot(w);
            const p = sigmoid(x);
            loss += softplus(x) - r.y * x;
            const h = p * (1 - p);
            for (r.feats[0..r.n]) |a| {
                grad[a.i] += (p - r.y) * a.v;
                for (r.feats[0..r.n]) |b| hess[a.i * d + b.i] += h * a.v * b.v;
            }
        }
        for (1..d) |i| {
            loss += 0.5 * l2 * w[i] * w[i];
            grad[i] += l2 * w[i];
            hess[i * d + i] += l2;
        }
        // Features never seen keep a zero row: make them solvable (they stay 0)
        for (0..d) |i| if (hess[i * d + i] == 0) {
            hess[i * d + i] = 1;
        };
        if (prev - loss < 1e-9 * @max(1, @abs(loss))) break;
        prev = loss;
        try cholesky(hess, d);
        solveInPlace(hess, d, grad);
        for (w, grad) |*wi, g| wi.* -= g;
    }
    return w;
}

/// Standard error of each weight from `fit`: square roots of the inverse penalised
/// Hessian's diagonal (caller frees)
pub fn stdErrors(gpa: std.mem.Allocator, d: usize, rows: []const Row, w: []const f64, l2: f64) ![]f64 {
    const hess = try factoredHessian(gpa, d, rows, w, l2);
    defer gpa.free(hess);
    const se = try gpa.alloc(f64, d);
    errdefer gpa.free(se);
    const e = try gpa.alloc(f64, d);
    defer gpa.free(e);
    for (se, 0..) |*s, i| {
        @memset(e, 0);
        e[i] = 1;
        solveInPlace(hess, d, e);
        s.* = @sqrt(e[i]);
    }
    return se;
}

/// As stdErrors, but rows with the same `cluster` (adjacent) may depend on each other,
/// like the ten player rows of one game: sandwich H^-1 M H^-1, M the sum over clusters
/// of the outer product of each cluster's summed score (caller frees)
pub fn clusteredStdErrors(gpa: std.mem.Allocator, d: usize, rows: []const Row, cluster: []const u32, w: []const f64, l2: f64) ![]f64 {
    std.debug.assert(cluster.len == rows.len);
    const hess = try factoredHessian(gpa, d, rows, w, l2);
    defer gpa.free(hess);
    const meat = try gpa.alloc(f64, d * d);
    defer gpa.free(meat);
    @memset(meat, 0);
    const score = try gpa.alloc(f64, d);
    defer gpa.free(score);
    @memset(score, 0);
    const seen = try gpa.alloc(bool, d);
    defer gpa.free(seen);
    @memset(seen, false);
    var touched: std.ArrayList(u32) = .empty;
    defer touched.deinit(gpa);
    var i: usize = 0;
    while (i < rows.len) {
        const c = cluster[i];
        while (i < rows.len and cluster[i] == c) : (i += 1) {
            const r = &rows[i];
            const g = sigmoid(r.dot(w)) - r.y;
            for (r.feats[0..r.n]) |f| {
                if (!seen[f.i]) try touched.append(gpa, f.i);
                seen[f.i] = true;
                score[f.i] += g * f.v;
            }
        }
        for (touched.items) |a| for (touched.items) |b| {
            meat[a * d + b] += score[a] * score[b];
        };
        for (touched.items) |a| {
            score[a] = 0;
            seen[a] = false;
        }
        touched.clearRetainingCapacity();
    }

    const se = try gpa.alloc(f64, d);
    errdefer gpa.free(se);
    const e = try gpa.alloc(f64, d);
    defer gpa.free(e);
    for (se, 0..) |*s, k| {
        @memset(e, 0);
        e[k] = 1;
        solveInPlace(hess, d, e);
        var v: f64 = 0;
        for (0..d) |a| {
            if (e[a] == 0) continue;
            var t: f64 = 0;
            for (0..d) |b| t += meat[a * d + b] * e[b];
            v += e[a] * t;
        }
        s.* = @sqrt(v);
    }
    return se;
}

/// The penalised Hessian of the loss at `w`, Cholesky-factored (caller frees)
fn factoredHessian(gpa: std.mem.Allocator, d: usize, rows: []const Row, w: []const f64, l2: f64) ![]f64 {
    const hess = try gpa.alloc(f64, d * d);
    errdefer gpa.free(hess);
    @memset(hess, 0);
    for (rows) |*r| {
        const p = sigmoid(r.dot(w));
        const h = p * (1 - p);
        for (r.feats[0..r.n]) |a| {
            for (r.feats[0..r.n]) |b| hess[a.i * d + b.i] += h * a.v * b.v;
        }
    }
    for (1..d) |i| hess[i * d + i] += l2;
    for (0..d) |i| if (hess[i * d + i] == 0) {
        hess[i * d + i] = 1;
    };
    try cholesky(hess, d);
    return hess;
}

/// Lower-triangular L with L L^T = a, in place (a is symmetric positive definite)
fn cholesky(a: []f64, d: usize) !void {
    for (0..d) |j| {
        var s = a[j * d + j];
        for (0..j) |k| s -= a[j * d + k] * a[j * d + k];
        if (s <= 0) return error.NotPositiveDefinite;
        const l = @sqrt(s);
        a[j * d + j] = l;
        for (j + 1..d) |i| {
            var t = a[i * d + j];
            for (0..j) |k| t -= a[i * d + k] * a[j * d + k];
            a[i * d + j] = t / l;
        }
    }
}

/// x = (L L^T)^-1 x, with L from cholesky
fn solveInPlace(l: []const f64, d: usize, x: []f64) void {
    for (0..d) |i| {
        var s = x[i];
        for (0..i) |k| s -= l[i * d + k] * x[k];
        x[i] = s / l[i * d + i];
    }
    var i = d;
    while (i > 0) {
        i -= 1;
        var s = x[i];
        for (i + 1..d) |k| s -= l[k * d + i] * x[k];
        x[i] = s / l[i * d + i];
    }
}

pub fn sigmoid(x: f64) f64 {
    return 1 / (1 + @exp(-x));
}

fn softplus(x: f64) f64 {
    return if (x > 30) x else std.math.log1p(@exp(x));
}

const testing = std.testing;

test "recovers ratings" {
    const gpa = testing.allocator;
    // Champion 1 beats champion 2 80% of the time from either side; 3 is never seen
    var rows: [1000]Row = undefined;
    for (&rows, 0..) |*r, i| {
        const one_blue = i % 2 == 0;
        const one_won = (i / 2) % 5 != 0;
        r.* = .{ .y = if (one_blue == one_won) 1 else 0 };
        r.add(0, 1);
        r.add(1, if (one_blue) 1 else -1);
        r.add(2, if (one_blue) -1 else 1);
    }
    const w = try fit(gpa, 4, &rows, 1);
    defer gpa.free(w);
    // Logit of 80% is 1.386, split between the two; no side advantage
    try testing.expectApproxEqAbs(1.386, w[1] - w[2], 0.02);
    try testing.expectApproxEqAbs(0, w[0], 0.01);
    try testing.expectEqual(0, w[3]);
}

test "clustered errors count a copied row once" {
    const gpa = testing.allocator;
    var once: [400]Row = undefined;
    var twice: [800]Row = undefined;
    var singles: [400]u32 = undefined;
    var pairs: [800]u32 = undefined;
    for (&once, &singles, 0..) |*r, *c, i| {
        const x: f64 = @floatFromInt(i % 7);
        r.* = .{ .y = if ((i * 37) % 10 < 3 + i % 7) 1 else 0 };
        r.add(0, 1);
        r.add(1, x - 3);
        c.* = @intCast(i);
        twice[2 * i] = r.*;
        twice[2 * i + 1] = r.*;
        pairs[2 * i] = @intCast(i);
        pairs[2 * i + 1] = @intCast(i);
    }
    const w = try fit(gpa, 2, &once, 0);
    defer gpa.free(w);
    const naive = try stdErrors(gpa, 2, &twice, w, 0);
    defer gpa.free(naive);
    const copied = try clusteredStdErrors(gpa, 2, &twice, &pairs, w, 0);
    defer gpa.free(copied);
    const single = try clusteredStdErrors(gpa, 2, &once, &singles, w, 0);
    defer gpa.free(single);
    // Copies add no information: the clustered error matches the data seen once, while
    // the naive one shrinks by sqrt(2)
    try testing.expectApproxEqRel(single[1], copied[1], 1e-9);
    try testing.expect(copied[1] > 1.3 * naive[1]);
}
