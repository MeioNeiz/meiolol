//! Forward and backward passes for the common layers, written once, on plain slices.
//! Backward functions add into gradient buffers (zero them per batch) so several uses of a
//! layer, or several rows of a batch, accumulate.

const std = @import("std");

/// Sum of a[i] * b[i], 8 lanes at a time then the tail
pub fn dot(a: []const f32, b: []const f32) f32 {
    std.debug.assert(a.len == b.len);
    const V = @Vector(8, f32);
    var acc: V = @splat(0);
    var i: usize = 0;
    while (i + 8 <= a.len) : (i += 8) acc += @as(V, a[i..][0..8].*) * @as(V, b[i..][0..8].*);
    var s = @reduce(.Add, acc);
    while (i < a.len) : (i += 1) s += a[i] * b[i];
    return s;
}

/// y += s * x
pub fn axpy(y: []f32, s: f32, x: []const f32) void {
    std.debug.assert(y.len == x.len);
    for (y, x) |*a, b| a.* += s * b;
}

/// A dense layer, out = w in + b, w row-major out x in
pub const linear = struct {
    /// b null: no bias
    pub fn forward(w: []const f32, b: ?[]const f32, in: []const f32, out: []f32) void {
        std.debug.assert(w.len == out.len * in.len);
        for (out, 0..) |*o, j| o.* = dot(w[j * in.len ..][0..in.len], in) + if (b) |x| x[j] else 0;
    }

    /// Adds dout's gradients: gw += dout in^T, gb += dout, din += w^T dout (din null:
    /// the input needs none). Units with dout 0 are skipped (ReLU or dropout zeroed them).
    pub fn backward(w: []const f32, in: []const f32, dout: []const f32, gw: []f32, gb: ?[]f32, din: ?[]f32) void {
        std.debug.assert(w.len == dout.len * in.len and gw.len == w.len);
        for (dout, 0..) |d, j| {
            if (d == 0) continue;
            if (gb) |g| g[j] += d;
            axpy(gw[j * in.len ..][0..in.len], d, in);
            if (din) |x| axpy(x, d, w[j * in.len ..][0..in.len]);
        }
    }
};

/// ReLU with inverted dropout: units drop with chance 1 - keep and survivors scale by
/// 1 / keep, so evaluation (rnd null) needs no rescaling
pub const relu = struct {
    /// h = relu(z), dropped with rnd. With rnd, draws one float per unit in order,
    /// dropped or not, so the stream doesn't depend on the activations.
    pub fn forward(z: []const f32, h: []f32, keep: f32, rnd: ?std.Random) void {
        std.debug.assert(z.len == h.len);
        for (z, h) |x, *o| {
            const kept = if (rnd) |r| r.float(f32) < keep else true;
            o.* = if (x > 0 and kept) (if (rnd != null) x / keep else x) else 0;
        }
    }

    /// dz from dh, through the units forward kept (h != 0); keep as in forward (1 for a
    /// pass without dropout)
    pub fn backward(h: []const f32, dh: []const f32, keep: f32, dz: []f32) void {
        std.debug.assert(h.len == dh.len and dz.len == h.len);
        for (h, dh, dz) |x, d, *o| o.* = if (x == 0) 0 else d / keep;
    }
};

/// Lookup of ids' rows in an embedding table (row-major, dim wide)
pub const embedding = struct {
    pub fn row(table: anytype, dim: usize, id: usize) @TypeOf(table[0..dim]) {
        return table[id * dim ..][0..dim];
    }

    /// out[k * dim ..] = table row ids[k], concatenated
    pub fn forward(table: []const f32, dim: usize, ids: []const u32, out: []f32) void {
        std.debug.assert(out.len == ids.len * dim);
        for (ids, 0..) |id, k| @memcpy(out[k * dim ..][0..dim], row(table, dim, id));
    }

    /// Adds dout's slices to the gradient rows of ids (repeated ids accumulate)
    pub fn backward(gtable: []f32, dim: usize, ids: []const u32, dout: []const f32) void {
        std.debug.assert(dout.len == ids.len * dim);
        for (ids, 0..) |id, k| axpy(row(gtable, dim, id), 1, dout[k * dim ..][0..dim]);
    }
};

/// Mean over n rows of width dim, rows laid end to end in x: the sum of each row times
/// 1 / n
pub const meanPool = struct {
    pub fn forward(x: []const f32, dim: usize, out: []f32) void {
        std.debug.assert(out.len == dim and x.len % dim == 0 and x.len > 0);
        const inv = 1 / @as(f32, @floatFromInt(x.len / dim));
        @memset(out, 0);
        var i: usize = 0;
        while (i < x.len) : (i += dim) axpy(out, inv, x[i..][0..dim]);
    }

    /// Adds dout / n to every row's gradient
    pub fn backward(dx: []f32, dim: usize, dout: []const f32) void {
        std.debug.assert(dout.len == dim and dx.len % dim == 0 and dx.len > 0);
        const inv = 1 / @as(f32, @floatFromInt(dx.len / dim));
        var i: usize = 0;
        while (i < dx.len) : (i += dim) axpy(dx[i..][0..dim], inv, dout);
    }
};

const testing = std.testing;

test "dot and axpy: tails past the 8 lanes" {
    var a: [11]f32 = undefined;
    var b: [11]f32 = undefined;
    for (&a, &b, 0..) |*x, *y, i| {
        x.* = @floatFromInt(i);
        y.* = 2;
    }
    try testing.expectEqual(@as(f32, 110), dot(&a, &b));
    axpy(&b, 0.5, &a);
    try testing.expectEqual(@as(f32, 7), b[10]);
}

test "linear: forward, backward adds gradients and skips zero units" {
    const w = [_]f32{ 1, 2, 3, 4, 5, 6 };
    const b = [_]f32{ 0.5, -1 };
    const in = [_]f32{ 1, 0, -1 };
    var out: [2]f32 = undefined;
    linear.forward(&w, &b, &in, &out);
    try testing.expectEqualSlices(f32, &.{ -1.5, -3 }, &out);
    linear.forward(&w, null, &in, &out);
    try testing.expectEqualSlices(f32, &.{ -2, -2 }, &out);
    var gw: [6]f32 = @splat(0);
    var gb = [_]f32{ 1, 1 };
    var din: [3]f32 = @splat(0);
    linear.backward(&w, &in, &.{ 2, 0 }, &gw, &gb, &din);
    try testing.expectEqualSlices(f32, &.{ 2, 0, -2, 0, 0, 0 }, &gw);
    try testing.expectEqualSlices(f32, &.{ 3, 1 }, &gb);
    try testing.expectEqualSlices(f32, &.{ 2, 4, 6 }, &din);
}

test "relu: dropout keeps about keep, rescales survivors, backward through kept units" {
    var z: [1000]f32 = undefined;
    for (&z, 0..) |*x, i| x.* = if (i % 2 == 0) 1 else -1;
    var h: [1000]f32 = undefined;
    relu.forward(&z, &h, 1, null);
    try testing.expectEqual(@as(f32, 1), h[0]);
    try testing.expectEqual(@as(f32, 0), h[1]);
    var rng: std.Random.DefaultPrng = .init(9);
    relu.forward(&z, &h, 0.8, rng.random());
    var kept: usize = 0;
    for (h, 0..) |x, i| if (x != 0) {
        try testing.expect(i % 2 == 0);
        try testing.expectEqual(@as(f32, 1) / @as(f32, 0.8), x);
        kept += 1;
    };
    try testing.expect(kept > 360 and kept < 440);
    var dz: [1000]f32 = undefined;
    var dh: [1000]f32 = undefined;
    @memset(&dh, 1);
    relu.backward(&h, &dh, 0.8, &dz);
    for (h, dz) |x, d| try testing.expectEqual(if (x == 0) @as(f32, 0) else @as(f32, 1) / @as(f32, 0.8), d);
}

test "embedding and mean pool: rows in, gradients back to the ids' rows" {
    const table = [_]f32{ 0, 1, 10, 11, 20, 21 };
    var out: [6]f32 = undefined;
    embedding.forward(&table, 2, &.{ 2, 0, 2 }, &out);
    try testing.expectEqualSlices(f32, &.{ 20, 21, 0, 1, 20, 21 }, &out);
    var g: [6]f32 = @splat(0);
    embedding.backward(&g, 2, &.{ 2, 0, 2 }, &.{ 1, 2, 3, 4, 5, 6 });
    try testing.expectEqualSlices(f32, &.{ 3, 4, 0, 0, 6, 8 }, &g);
    var m: [2]f32 = undefined;
    meanPool.forward(&out, 2, &m);
    try testing.expectApproxEqAbs(@as(f32, 40.0 / 3.0), m[0], 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 43.0 / 3.0), m[1], 1e-5);
    var dx: [6]f32 = @splat(0);
    meanPool.backward(&dx, 2, &.{ 3, 6 });
    try testing.expectEqualSlices(f32, &.{ 1, 2, 1, 2, 1, 2 }, &dx);
}
