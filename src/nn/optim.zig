//! Optimisers over flat parameter and gradient slices: Adam with decoupled (AdamW) or
//! coupled (L2) decay, set per segment of the parameters, and global gradient-norm
//! clipping.

const std = @import("std");

/// A run of consecutive parameters sharing decay and trainability. Segments are laid end
/// to end from index 0; together they cover the parameters handed to `Adam.step`.
pub const Segment = struct {
    len: usize,
    /// Decay coefficient: the AdamW weight decay or the L2 penalty, by `Adam.Config.decay`
    decay: f32 = 0,
    /// Left unchanged by steps (its moments still update, so unfreezing resumes smoothly)
    frozen: bool = false,
};

/// Adam (Kingma and Ba) with bias correction. Holds the two moment vectors and the step
/// count; parameters and gradients stay with the caller.
pub const Adam = struct {
    cfg: Config,
    m: []f32,
    v: []f32,
    t: u64 = 0,

    pub const Decay = enum {
        /// AdamW (Loshchilov and Hutter): x -= lr * (m^ / (sqrt(v^) + eps) + decay * x)
        decoupled,
        /// L2 inside the gradient: g += decay * x, then x -= lr * m^ / (sqrt(v^) + eps)
        coupled,
    };

    pub const Config = struct {
        lr: f32 = 1e-3,
        /// f64 so that 1 - beta rounds to the f32 nearest the decimal (0.1, not
        /// 1 - 0.9f = 0.10000002)
        beta1: f64 = 0.9,
        beta2: f64 = 0.999,
        eps: f32 = 1e-8,
        decay: Decay = .decoupled,
    };

    /// One step's constants, from `begin`
    pub const Step = struct {
        lr: f32,
        b1: f32,
        b2: f32,
        r1: f32,
        r2: f32,
        /// Bias corrections 1 - beta^t
        c1: f32,
        c2: f32,
        eps: f32,
        decay: Decay,
    };

    /// Moments for n parameters, zeroed
    pub fn init(gpa: std.mem.Allocator, n: usize, cfg: Config) !Adam {
        const buf = try gpa.alloc(f32, 2 * n);
        @memset(buf, 0);
        return .{ .cfg = cfg, .m = buf[0..n], .v = buf[n..] };
    }

    pub fn deinit(o: *Adam, gpa: std.mem.Allocator) void {
        gpa.free(o.m.ptr[0 .. 2 * o.m.len]);
        o.* = undefined;
    }

    /// Back to step 0 with zero moments
    pub fn reset(o: *Adam) void {
        @memset(o.m, 0);
        @memset(o.v, 0);
        o.t = 0;
    }

    /// Counts a step and returns its constants. For splitting one step across threads:
    /// call once, then `update` each thread's index range.
    pub fn begin(o: *Adam) Step {
        o.t += 1;
        const b1: f32 = @floatCast(o.cfg.beta1);
        const b2: f32 = @floatCast(o.cfg.beta2);
        return .{
            .lr = o.cfg.lr,
            .b1 = b1,
            .b2 = b2,
            .r1 = @floatCast(1 - o.cfg.beta1),
            .r2 = @floatCast(1 - o.cfg.beta2),
            .c1 = 1 - std.math.pow(f32, b1, @floatFromInt(o.t)),
            .c2 = 1 - std.math.pow(f32, b2, @floatFromInt(o.t)),
            .eps = o.cfg.eps,
            .decay = o.cfg.decay,
        };
    }

    /// Updates parameters lo..hi with gradients g and one decay coefficient. p and g are
    /// the whole parameter and gradient slices (indices match the moments).
    pub fn update(o: *const Adam, s: Step, p: []f32, g: []const f32, lo: usize, hi: usize, decay: f32) void {
        std.debug.assert(p.len == o.m.len and g.len == o.m.len and lo <= hi and hi <= p.len);
        switch (s.decay) {
            .decoupled => for (p[lo..hi], g[lo..hi], o.m[lo..hi], o.v[lo..hi]) |*x, gi, *m, *v| {
                m.* = s.b1 * m.* + s.r1 * gi;
                v.* = s.b2 * v.* + s.r2 * gi * gi;
                x.* -= s.lr * ((m.* / s.c1) / (@sqrt(v.* / s.c2) + s.eps) + decay * x.*);
            },
            .coupled => for (p[lo..hi], g[lo..hi], o.m[lo..hi], o.v[lo..hi]) |*x, g0, *m, *v| {
                const gi = g0 + decay * x.*;
                m.* = s.b1 * m.* + s.r1 * gi;
                v.* = s.b2 * v.* + s.r2 * gi * gi;
                x.* -= s.lr * (m.* / s.c1) / (@sqrt(v.* / s.c2) + s.eps);
            },
        }
    }

    /// Moments only, for frozen parameters
    fn moments(o: *const Adam, s: Step, p: []const f32, g: []const f32, lo: usize, hi: usize, decay: f32) void {
        for (p[lo..hi], g[lo..hi], o.m[lo..hi], o.v[lo..hi]) |x, g0, *m, *v| {
            const gi = if (s.decay == .coupled) g0 + decay * x else g0;
            m.* = s.b1 * m.* + s.r1 * gi;
            v.* = s.b2 * v.* + s.r2 * gi * gi;
        }
    }

    /// One step over all parameters, segment by segment
    pub fn step(o: *Adam, p: []f32, g: []const f32, segments: []const Segment) void {
        const s = o.begin();
        var at: usize = 0;
        for (segments) |seg| {
            if (seg.frozen) o.moments(s, p, g, at, at + seg.len, seg.decay) else o.update(s, p, g, at, at + seg.len, seg.decay);
            at += seg.len;
        }
        std.debug.assert(at == p.len);
    }
};

/// Scales g down to Euclidean norm max_norm when it is longer (max_norm <= 0: never).
/// Returns the norm before clipping.
pub fn clipGradNorm(g: []f32, max_norm: f32) f32 {
    var sq: f32 = 0;
    for (g) |x| sq += x * x;
    const norm = @sqrt(sq);
    if (max_norm > 0 and norm > max_norm) for (g) |*x| {
        x.* *= max_norm / norm;
    };
    return norm;
}

const testing = std.testing;

test "adam: first step moves each parameter by lr against its gradient's sign" {
    const gpa = testing.allocator;
    var o: Adam = try .init(gpa, 3, .{ .lr = 0.01 });
    defer o.deinit(gpa);
    var p = [_]f32{ 1, 2, 3 };
    o.step(&p, &.{ 0.5, -4, 0 }, &.{.{ .len = 3 }});
    // m^ / sqrt(v^) = sign(g) on step 1
    try testing.expectApproxEqAbs(@as(f32, 0.99), p[0], 1e-6);
    try testing.expectApproxEqAbs(@as(f32, 2.01), p[1], 1e-6);
    try testing.expectEqual(@as(f32, 3), p[2]);
    try testing.expectEqual(@as(u64, 1), o.t);
}

test "adam: 1 - beta rounds as the decimal" {
    const gpa = testing.allocator;
    var o: Adam = try .init(gpa, 1, .{});
    defer o.deinit(gpa);
    const s = o.begin();
    try testing.expectEqual(@as(f32, 0.1), s.r1);
    try testing.expectEqual(@as(f32, 0.001), s.r2);
    try testing.expectEqual(@as(f32, 0.9), s.b1);
}

test "adam: decoupled decay shrinks by lr * decay, coupled decay acts through the moments" {
    const gpa = testing.allocator;
    var o: Adam = try .init(gpa, 2, .{ .lr = 0.1 });
    defer o.deinit(gpa);
    var p = [_]f32{ 2, 2 };
    // Zero gradient: only the decayed segment moves, by lr * decay * x
    o.step(&p, &.{ 0, 0 }, &.{ .{ .len = 1 }, .{ .len = 1, .decay = 0.5 } });
    try testing.expectEqual(@as(f32, 2), p[0]);
    try testing.expectApproxEqAbs(@as(f32, 1.9), p[1], 1e-6);

    var c: Adam = try .init(gpa, 1, .{ .lr = 0.1, .decay = .coupled });
    defer c.deinit(gpa);
    var q = [_]f32{2};
    // The penalty's gradient decay * x = 1 makes a normalised step of lr
    c.step(&q, &.{0}, &.{.{ .len = 1, .decay = 0.5 }});
    try testing.expectApproxEqAbs(@as(f32, 1.9), q[0], 1e-6);
}

test "adam: frozen segments keep their values, threads' ranges equal one step" {
    const gpa = testing.allocator;
    var a: Adam = try .init(gpa, 4, .{});
    defer a.deinit(gpa);
    var b: Adam = try .init(gpa, 4, .{});
    defer b.deinit(gpa);
    var pa = [_]f32{ 1, -1, 0.5, 2 };
    var pb = pa;
    const g = [_]f32{ 0.3, -0.2, 0.1, 0.7 };
    for (0..3) |_| {
        a.step(&pa, &g, &.{ .{ .len = 1, .frozen = true }, .{ .len = 3, .decay = 0.1 } });
        const s = b.begin();
        b.moments(s, &pb, &g, 0, 1, 0);
        b.update(s, &pb, &g, 1, 2, 0.1);
        b.update(s, &pb, &g, 2, 4, 0.1);
    }
    try testing.expectEqual(@as(f32, 1), pa[0]);
    try testing.expectEqualSlices(f32, &pa, &pb);
    try testing.expectEqualSlices(f32, a.m, b.m);
}

test "adam: minimises a quadratic" {
    const gpa = testing.allocator;
    var o: Adam = try .init(gpa, 2, .{ .lr = 0.05 });
    defer o.deinit(gpa);
    var p = [_]f32{ 3, -2 };
    var g: [2]f32 = undefined;
    for (0..2000) |_| {
        // (x - 1)^2 + (y + 0.5)^2
        g = .{ 2 * (p[0] - 1), 2 * (p[1] + 0.5) };
        o.step(&p, &g, &.{.{ .len = 2 }});
    }
    try testing.expectApproxEqAbs(@as(f32, 1), p[0], 1e-3);
    try testing.expectApproxEqAbs(@as(f32, -0.5), p[1], 1e-3);
    o.reset();
    try testing.expectEqual(@as(u64, 0), o.t);
    try testing.expectEqual(@as(f32, 0), o.m[0]);
}

test "clip: scales to max norm only when longer, returns the norm before" {
    var g = [_]f32{ 3, 4 };
    try testing.expectEqual(@as(f32, 5), clipGradNorm(&g, 10));
    try testing.expectEqualSlices(f32, &.{ 3, 4 }, &g);
    try testing.expectEqual(@as(f32, 5), clipGradNorm(&g, 1));
    try testing.expectApproxEqAbs(@as(f32, 0.6), g[0], 1e-7);
    try testing.expectApproxEqAbs(@as(f32, 0.8), g[1], 1e-7);
    var h = [_]f32{ 3, 4 };
    _ = clipGradNorm(&h, 0);
    try testing.expectEqualSlices(f32, &.{ 3, 4 }, &h);
}
