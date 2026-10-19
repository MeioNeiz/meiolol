//! Finite-difference gradient checking: compares an analytic gradient with central
//! differences of the loss, one parameter at a time.

const std = @import("std");

pub const Options = struct {
    /// Step for (L(x + h) - L(x - h)) / 2h
    h: f32 = 1e-3,
    /// Allowed |numeric - analytic|
    tol: f64 = 2e-3,
};

pub const Mismatch = struct { index: usize, numeric: f64, analytic: f64 };

/// For each index i (null: all), moves params[i] by +-h, calls loss(ctx) and compares the
/// central difference with grad[i]. Restores params. Returns the first mismatch, or null.
/// loss is `fn (ctx) f64` evaluated at the current params; grad is its gradient there.
pub fn gradient(ctx: anytype, comptime loss: anytype, params: []f32, grad: []const f32, indices: ?[]const usize, opts: Options) ?Mismatch {
    std.debug.assert(grad.len == params.len);
    const n = if (indices) |x| x.len else params.len;
    for (0..n) |k| {
        const i = if (indices) |x| x[k] else k;
        const old = params[i];
        params[i] = old + opts.h;
        const up = loss(ctx);
        params[i] = old - opts.h;
        const down = loss(ctx);
        params[i] = old;
        const numeric = (up - down) / (2 * @as(f64, opts.h));
        if (!(@abs(numeric - grad[i]) <= opts.tol)) return .{ .index = i, .numeric = numeric, .analytic = grad[i] };
    }
    return null;
}

/// gradient for tests: error.GradientMismatch, printing the parameter, on a mismatch
pub fn expectGradient(ctx: anytype, comptime loss: anytype, params: []f32, grad: []const f32, indices: ?[]const usize, opts: Options) !void {
    const m = gradient(ctx, loss, params, grad, indices, opts) orelse return;
    std.debug.print("gradient check: parameter {d}: numeric {d:.6}, analytic {d:.6}\n", .{ m.index, m.numeric, m.analytic });
    return error.GradientMismatch;
}

const testing = std.testing;

test "gradient: accepts a correct gradient, reports the first wrong one" {
    const Quad = struct {
        p: []f32,
        // sum x_i^3
        fn loss(q: *const @This()) f64 {
            var s: f64 = 0;
            for (q.p) |x| s += @as(f64, x) * x * x;
            return s;
        }
    };
    var p = [_]f32{ 0.5, -1, 2 };
    const q: Quad = .{ .p = &p };
    var g = [_]f32{ 0.75, 3, 12 };
    try testing.expectEqual(@as(?Mismatch, null), gradient(&q, Quad.loss, &p, &g, null, .{}));
    g[2] = 11;
    const m = gradient(&q, Quad.loss, &p, &g, null, .{}).?;
    try testing.expectEqual(@as(usize, 2), m.index);
    try testing.expectApproxEqAbs(@as(f64, 12), m.numeric, 1e-3);
    try testing.expectEqual(@as(?Mismatch, null), gradient(&q, Quad.loss, &p, &g, &.{ 0, 1 }, .{}));
    try testing.expectEqualSlices(f32, &.{ 0.5, -1, 2 }, &p);
}
