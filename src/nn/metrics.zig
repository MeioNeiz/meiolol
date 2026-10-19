//! Binary classification metrics: sigmoid, log loss and rank AUC, each with one
//! definition. Generic over the float type of the inputs.

const std = @import("std");

/// 1 / (1 + e^-x)
pub fn sigmoid(x: anytype) @TypeOf(x) {
    return 1 / (1 + @exp(-x));
}

/// Inverse of sigmoid, p clamped to [1e-6, 1 - 1e-6] in p's type
pub fn logit(p: anytype) @TypeOf(p) {
    const q = std.math.clamp(p, 1e-6, 1 - 1e-6);
    return @log(q / (1 - q));
}

/// Log loss of prediction p for outcome y in [0, 1]. p is clamped to [1e-6, 1 - 1e-6] in
/// its own type before widening, so a certain wrong prediction costs about 13.8.
pub fn logLoss(y: anytype, p: @TypeOf(y)) f64 {
    const q: f64 = std.math.clamp(p, 1e-6, 1 - 1e-6);
    return -(y * @log(q) + (1 - y) * @log(1 - q));
}

/// Mean log loss over pairs (empty: 0)
pub fn meanLogLoss(comptime T: type, ys: []const T, ps: []const T) f64 {
    std.debug.assert(ys.len == ps.len);
    var s: f64 = 0;
    for (ys, ps) |y, p| s += logLoss(y, p);
    return s / @as(f64, @floatFromInt(@max(ys.len, 1)));
}

/// Area under the ROC curve: the chance a random positive (y > 0.5) scores above a random
/// negative, ties counting half (Mann-Whitney with average ranks). NaN when either class
/// is empty, as the AUC is undefined there.
pub fn auc(comptime T: type, gpa: std.mem.Allocator, ys: []const T, ps: []const T) !f64 {
    std.debug.assert(ys.len == ps.len);
    const idx = try gpa.alloc(u32, ps.len);
    defer gpa.free(idx);
    for (idx, 0..) |*x, i| x.* = @intCast(i);
    std.mem.sort(u32, idx, ps, struct {
        fn lt(p: []const T, a: u32, b: u32) bool {
            return p[a] < p[b];
        }
    }.lt);
    var rank_sum: f64 = 0;
    var pos: f64 = 0;
    var i: usize = 0;
    while (i < idx.len) {
        var j = i;
        while (j < idx.len and ps[idx[j]] == ps[idx[i]]) j += 1;
        // Ranks i+1..j averaged over the tie
        const mid = @as(f64, @floatFromInt(i + 1 + j)) / 2;
        for (idx[i..j]) |k| if (ys[k] > 0.5) {
            rank_sum += mid;
            pos += 1;
        };
        i = j;
    }
    const neg = @as(f64, @floatFromInt(idx.len)) - pos;
    if (pos == 0 or neg == 0) return std.math.nan(f64);
    return (rank_sum - pos * (pos + 1) / 2) / (pos * neg);
}

const testing = std.testing;

test "sigmoid and logit invert, logit clamps" {
    try testing.expectEqual(@as(f32, 0.5), sigmoid(@as(f32, 0)));
    try testing.expectApproxEqAbs(@as(f64, 0.7310585786300049), sigmoid(@as(f64, 1)), 1e-15);
    try testing.expectApproxEqAbs(@as(f64, 0.8), sigmoid(logit(@as(f64, 0.8))), 1e-12);
    try testing.expect(std.math.isFinite(logit(@as(f32, 1))));
}

test "log loss: ln 2 at a coin flip, clamped at certainty, mean over pairs" {
    try testing.expectApproxEqAbs(@log(2.0), logLoss(@as(f32, 1), 0.5), 1e-12);
    try testing.expectApproxEqAbs(-@log(1e-6), logLoss(@as(f64, 1), 0), 1e-9);
    // 1 - 1e-6 rounds in f32, so certain right answers cost about 1e-6 either way
    try testing.expectApproxEqAbs(logLoss(@as(f32, 0), 0), logLoss(@as(f32, 1), 1), 1e-7);
    try testing.expectApproxEqAbs(@as(f64, 0.5 * -@log(0.25) + 0.5 * -@log(0.75)), meanLogLoss(f32, &.{ 0, 1 }, &.{ 0.75, 0.75 }), 1e-7);
    try testing.expectEqual(@as(f64, 0), meanLogLoss(f64, &.{}, &.{}));
}

test "auc: perfect, reversed, ties half, undefined without both classes" {
    const gpa = testing.allocator;
    try testing.expectEqual(@as(f64, 1), try auc(f32, gpa, &.{ 1, 0, 1 }, &.{ 0.8, 0.3, 0.6 }));
    try testing.expectEqual(@as(f64, 0), try auc(f64, gpa, &.{ 0, 1 }, &.{ 0.9, 0.1 }));
    try testing.expectEqual(@as(f64, 0.5), try auc(f32, gpa, &.{ 1, 0 }, &.{ 0.5, 0.5 }));
    // One positive at 0.6 above negatives 0.2 and tied with 0.6: (1 + 0.5) / 2
    try testing.expectEqual(@as(f64, 0.75), try auc(f64, gpa, &.{ 0, 1, 0 }, &.{ 0.2, 0.6, 0.6 }));
    try testing.expect(std.math.isNan(try auc(f32, gpa, &.{ 1, 1 }, &.{ 0.2, 0.6 })));
    try testing.expect(std.math.isNan(try auc(f32, gpa, &.{}, &.{})));
}
