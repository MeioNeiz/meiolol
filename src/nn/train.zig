//! The minibatch training loop: shuffled batches over the training rows, validation
//! every so many steps, early stopping on patience, keep-best, and the step count for a
//! refit on more rows.

const std = @import("std");

/// Batches in one pass over n rows (the last may be short)
pub fn stepsPerEpoch(n: usize, batch: u32) u64 {
    return @max(1, (n + batch - 1) / batch);
}

/// Steps for a refit on n rows that matches `epochs` of a tuned run, scaled by `more`
/// (1.1: a tenth more epochs for a tenth more rows). At least 1.
pub fn refitSteps(epochs: f64, more: f64, n: usize, batch: u32) u64 {
    const per: f64 = @floatFromInt(stepsPerEpoch(n, batch));
    return @max(1, @as(u64, @intFromFloat(@round(epochs * more * per))));
}

pub const Config = struct {
    batch: u32,
    max_steps: u64,
    /// Validate this many times an epoch (every max(1, steps per epoch / this) steps), and
    /// after the last step
    evals_per_epoch: u32 = 1,
    /// Stop after this many validations in a row without a new best
    patience: u32 = 5,
    /// A new best must beat the old by more than this
    min_delta: f64 = 1e-7,
    /// Validate before the first step too, so the starting parameters can win (a net that
    /// starts at a useful offset); otherwise the first best is the first validation's
    score_start: bool = false,
    /// Validate at all; false trains max_steps and keeps the last parameters (a refit)
    validate: bool = true,
};

pub const Result = struct {
    /// Steps at the kept parameters (all steps run when not validating)
    steps: u64,
    /// steps in epochs of the training rows
    epochs: f64,
    /// Best validation loss (inf when not validating)
    loss: f64,
    /// Steps actually run
    ran: u64,
};

/// Trains on rows 0..n, shuffling a permutation with rnd at each epoch's start. ctx
/// provides:
///   fn step(ctx, rows: []const u32) !void   gradients for these rows and an update of
///                                           `params`
///   fn valLoss(ctx) !f64                    validation loss at the current `params`
///                                           (only called when cfg.validate)
/// and optionally fn onEval(ctx, step: u64, loss: f64) void after each validation.
/// With validation, `params` ends at the best validated values (best: scratch of the
/// same length); without, at the last step's.
pub fn fit(gpa: std.mem.Allocator, ctx: anytype, cfg: Config, n: usize, rnd: std.Random, params: []f32, best: []f32) !Result {
    std.debug.assert(best.len == params.len or !cfg.validate);
    const order = try gpa.alloc(u32, n);
    defer gpa.free(order);
    for (order, 0..) |*o, i| o.* = @intCast(i);
    const per_epoch = stepsPerEpoch(n, cfg.batch);
    const eval_every = @max(1, per_epoch / @max(cfg.evals_per_epoch, 1));

    var best_loss = std.math.inf(f64);
    var have_best = false;
    if (cfg.validate and cfg.score_start) {
        best_loss = try ctx.valLoss();
        have_best = true;
        @memcpy(best, params);
        if (@hasDecl(Deref(@TypeOf(ctx)), "onEval")) ctx.onEval(0, best_loss);
    }
    var best_step: u64 = 0;
    var since_best: u32 = 0;
    var step: u64 = 0;
    var at: usize = order.len;
    while (step < cfg.max_steps) {
        if (at >= order.len) {
            rnd.shuffle(u32, order);
            at = 0;
        }
        const part = order[at..@min(at + cfg.batch, order.len)];
        at += part.len;
        try ctx.step(part);
        step += 1;
        if (!cfg.validate) continue;
        if (step % eval_every != 0 and step != cfg.max_steps) continue;
        const loss = try ctx.valLoss();
        if (@hasDecl(Deref(@TypeOf(ctx)), "onEval")) ctx.onEval(step, loss);
        if (loss < best_loss - cfg.min_delta) {
            best_loss = loss;
            best_step = step;
            since_best = 0;
            have_best = true;
            @memcpy(best, params);
        } else {
            since_best += 1;
            if (since_best >= cfg.patience) break;
        }
    }
    if (!cfg.validate) best_step = step else if (have_best) @memcpy(params, best);
    return .{
        .steps = best_step,
        .epochs = @as(f64, @floatFromInt(best_step)) / @as(f64, @floatFromInt(per_epoch)),
        .loss = best_loss,
        .ran = step,
    };
}

fn Deref(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .pointer => |p| p.child,
        else => T,
    };
}

const testing = std.testing;

/// One parameter, loss (x - target)^2, plain gradient steps; validation reads a scripted
/// sequence of losses so the stopping rules can be checked exactly
const Toy = struct {
    p: []f32,
    losses: []const f64,
    evals: usize = 0,
    steps: usize = 0,
    seen: std.ArrayList(u32) = .empty,
    gpa: std.mem.Allocator,

    fn step(t: *Toy, rows: []const u32) !void {
        t.steps += 1;
        t.p[0] += 1;
        try t.seen.appendSlice(t.gpa, rows);
    }

    fn valLoss(t: *Toy) !f64 {
        defer t.evals += 1;
        return t.losses[t.evals];
    }
};

test "fit: early stop on patience keeps the best validated parameters" {
    const gpa = testing.allocator;
    var p = [_]f32{0};
    var best: [1]f32 = undefined;
    var t: Toy = .{ .p = &p, .losses = &.{ 0.9, 0.7, 0.8, 0.75, 0.71 }, .gpa = gpa };
    defer t.seen.deinit(gpa);
    var rng: std.Random.DefaultPrng = .init(1);
    // 10 rows, batch 5: 2 steps an epoch, evaluated twice an epoch
    const r = try fit(gpa, &t, .{ .batch = 5, .max_steps = 100, .evals_per_epoch = 2, .patience = 3 }, 10, rng.random(), &p, &best);
    try testing.expectEqual(@as(u64, 2), r.steps);
    try testing.expectEqual(@as(u64, 5), r.ran);
    try testing.expectEqual(@as(f64, 1), r.epochs);
    try testing.expectEqual(@as(f64, 0.7), r.loss);
    // p counted steps; the best was after step 2
    try testing.expectEqual(@as(f32, 2), p[0]);
}

test "fit: every row once per epoch, short last batch" {
    const gpa = testing.allocator;
    var p = [_]f32{0};
    var t: Toy = .{ .p = &p, .losses = &.{}, .gpa = gpa };
    defer t.seen.deinit(gpa);
    var rng: std.Random.DefaultPrng = .init(2);
    const r = try fit(gpa, &t, .{ .batch = 4, .max_steps = 6, .validate = false }, 10, rng.random(), &p, &.{});
    try testing.expectEqual(@as(u64, 6), r.steps);
    try testing.expectEqual(@as(f64, 2), r.epochs);
    try testing.expectEqual(@as(f64, std.math.inf(f64)), r.loss);
    try testing.expectEqual(@as(usize, 20), t.seen.items.len);
    for (0..2) |e| {
        var hit: [10]bool = @splat(false);
        for (t.seen.items[e * 10 ..][0..10]) |i| hit[i] = true;
        for (hit) |h| try testing.expect(h);
    }
}

test "fit: score_start lets the starting parameters win; without it a step must" {
    const gpa = testing.allocator;
    var rng: std.Random.DefaultPrng = .init(3);
    var p = [_]f32{0};
    var best: [1]f32 = undefined;
    var t: Toy = .{ .p = &p, .losses = &.{ 0.5, 0.6, 0.6 }, .gpa = gpa };
    defer t.seen.deinit(gpa);
    const r = try fit(gpa, &t, .{ .batch = 10, .max_steps = 10, .patience = 2, .score_start = true }, 10, rng.random(), &p, &best);
    try testing.expectEqual(@as(u64, 0), r.steps);
    try testing.expectEqual(@as(f32, 0), p[0]);
    try testing.expectEqual(@as(f64, 0.5), r.loss);

    var q = [_]f32{0};
    var u: Toy = .{ .p = &q, .losses = &.{ 0.6, 0.6, 0.6 }, .gpa = gpa };
    defer u.seen.deinit(gpa);
    const s = try fit(gpa, &u, .{ .batch = 10, .max_steps = 10, .patience = 2 }, 10, rng.random(), &q, &best);
    try testing.expectEqual(@as(u64, 1), s.steps);
    try testing.expectEqual(@as(f32, 1), q[0]);
}

test "fit: validates after the last step, min_delta guards ties" {
    const gpa = testing.allocator;
    var rng: std.Random.DefaultPrng = .init(4);
    var p = [_]f32{0};
    var best: [1]f32 = undefined;
    // 1 step an epoch would validate every step; with 3 steps an epoch and 1 eval, at 3
    // and at the last step 4
    var t: Toy = .{ .p = &p, .losses = &.{ 0.5, 0.5 - 1e-9 }, .gpa = gpa };
    defer t.seen.deinit(gpa);
    const r = try fit(gpa, &t, .{ .batch = 1, .max_steps = 4 }, 3, rng.random(), &p, &best);
    try testing.expectEqual(@as(usize, 2), t.evals);
    try testing.expectEqual(@as(u64, 3), r.steps);
    try testing.expectEqual(@as(f32, 3), p[0]);
}

test "refit steps: epochs scaled, rounded, at least one" {
    try testing.expectEqual(@as(u64, 3), stepsPerEpoch(10, 4));
    try testing.expectEqual(@as(u64, 1), stepsPerEpoch(0, 4));
    try testing.expectEqual(@as(u64, 33), refitSteps(10, 1.1, 10, 4));
    try testing.expectEqual(@as(u64, 1), refitSteps(0, 1.1, 10, 4));
}
