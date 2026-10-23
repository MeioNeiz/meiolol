//! nn: a small library for training neural nets on the CPU, std only. No autograd: a net
//! writes its forward and backward from the layers here, and the library supplies the
//! rest of the training: named parameters in one flat buffer, Adam(W), gradient
//! clipping, the minibatch loop with early stopping, metrics and a gradient checker.
//!
//! Logistic regression on two features, end to end (also run as a test below):
//!
//!     var ps: nn.Params = .empty;
//!     defer ps.deinit(gpa);
//!     const w = try ps.vector(gpa, "w", 2, .{ .init = .{ .uniform = 0.1 }, .decay = 1e-4 });
//!     const b = try ps.scalar(gpa, "b", .{});
//!     const p = try ps.alloc(gpa);
//!     ps.initValues(p, rnd);
//!     const segs = try ps.segments(gpa);
//!     var opt: nn.Adam = try .init(gpa, ps.len, .{ .lr = 0.05 });
//!
//!     // fit calls step(rows) for each batch and valLoss() to stop early
//!     const Ctx = struct {
//!         fn step(c: *@This(), rows: []const u32) !void {
//!             @memset(c.g, 0);
//!             for (rows) |i| {
//!                 const d = nn.sigmoid(nn.dot(w.of(c.p), x[i]) + b.at(c.p, 0).*) - y[i];
//!                 nn.axpy(w.of(c.g), d / n, x[i]);
//!                 b.at(c.g, 0).* += d / n;
//!             }
//!             c.opt.step(c.p, c.g, c.segs);
//!         }
//!         fn valLoss(c: *@This()) !f64 { ... mean nn.logLoss on held-out rows ... }
//!     };
//!     const r = try nn.fit(gpa, &ctx, .{ .batch = 32, .max_steps = 2000 }, n_train, rnd, p, best);
//!
//! Conventions: f32 parameters, f64 losses. Backward passes add into gradient buffers.
//! Random draws (init, shuffles, dropout) come from a caller's std.Random in a fixed
//! order, so a seed reproduces a run to the last bit.

const std = @import("std");

pub const optim = @import("optim.zig");
pub const params = @import("params.zig");
pub const train = @import("train.zig");
pub const layers = @import("layers.zig");
pub const metrics = @import("metrics.zig");
pub const check = @import("check.zig");

pub const Adam = optim.Adam;
pub const Segment = optim.Segment;
pub const clipGradNorm = optim.clipGradNorm;

pub const Params = params.Params;
pub const Param = params.Param;
pub const Init = params.Init;

pub const fit = train.fit;
pub const stepsPerEpoch = train.stepsPerEpoch;
pub const refitSteps = train.refitSteps;

pub const dot = layers.dot;
pub const axpy = layers.axpy;
pub const linear = layers.linear;
pub const relu = layers.relu;
pub const embedding = layers.embedding;
pub const meanPool = layers.meanPool;

pub const sigmoid = metrics.sigmoid;
pub const logit = metrics.logit;
pub const logLoss = metrics.logLoss;
pub const meanLogLoss = metrics.meanLogLoss;
pub const auc = metrics.auc;

pub const expectGradient = check.expectGradient;

const nn = @This();
const testing = std.testing;

test {
    testing.refAllDecls(@This());
}

test "example: logistic regression learns a planted rule, gradient checks" {
    const gpa = testing.allocator;
    var rng: std.Random.DefaultPrng = .init(1);
    const rnd = rng.random();

    // y = 1 with chance sigmoid(2 x0 - x1 + 0.5)
    const n = 2000;
    const x = try gpa.alloc([2]f32, n);
    defer gpa.free(x);
    const y = try gpa.alloc(f32, n);
    defer gpa.free(y);
    for (x, y) |*xi, *yi| {
        xi.* = .{ rnd.floatNorm(f32), rnd.floatNorm(f32) };
        yi.* = if (rnd.float(f32) < nn.sigmoid(2 * xi[0] - xi[1] + 0.5)) 1 else 0;
    }
    const n_train = 1600;

    var ps: nn.Params = .empty;
    defer ps.deinit(gpa);
    const w = try ps.vector(gpa, "w", 2, .{ .init = .{ .uniform = 0.1 }, .decay = 1e-4 });
    const b = try ps.scalar(gpa, "b", .{});
    const p = try ps.alloc(gpa);
    defer gpa.free(p);
    ps.initValues(p, rnd);
    const segs = try ps.segments(gpa);
    defer gpa.free(segs);
    var opt: nn.Adam = try .init(gpa, ps.len, .{ .lr = 0.05 });
    defer opt.deinit(gpa);
    const g = try ps.alloc(gpa);
    defer gpa.free(g);
    const best = try ps.alloc(gpa);
    defer gpa.free(best);

    const Ctx = struct {
        x: []const [2]f32,
        y: []const f32,
        n_train: usize,
        w: nn.Param,
        b: nn.Param,
        p: []f32,
        g: []f32,
        opt: *nn.Adam,
        segs: []const nn.Segment,

        fn predict(c: *const @This(), i: usize) f32 {
            return nn.sigmoid(nn.dot(c.w.of(c.p), &c.x[i]) + c.b.at(c.p, 0).*);
        }

        fn grads(c: *const @This(), rows: []const u32) void {
            @memset(c.g, 0);
            const k: f32 = @floatFromInt(rows.len);
            for (rows) |i| {
                const d = (c.predict(i) - c.y[i]) / k;
                nn.axpy(c.w.of(c.g), d, &c.x[i]);
                c.b.at(c.g, 0).* += d;
            }
        }

        pub fn step(c: *@This(), rows: []const u32) !void {
            c.grads(rows);
            _ = nn.clipGradNorm(c.g, 5);
            c.opt.step(c.p, c.g, c.segs);
        }

        pub fn valLoss(c: *const @This()) !f64 {
            var s: f64 = 0;
            for (c.n_train..c.y.len) |i| s += nn.logLoss(c.y[i], c.predict(i));
            return s / @as(f64, @floatFromInt(c.y.len - c.n_train));
        }

        fn batchLoss(c: *const @This()) f64 {
            var s: f64 = 0;
            for (0..8) |i| s += nn.logLoss(@as(f64, c.y[i]), @as(f64, c.predict(i)));
            return s / 8;
        }
    };
    var ctx: Ctx = .{ .x = x, .y = y, .n_train = n_train, .w = w, .b = b, .p = p, .g = g, .opt = &opt, .segs = segs };

    // The analytic gradient of the mean loss on rows 0..8 matches finite differences
    ctx.grads(&.{ 0, 1, 2, 3, 4, 5, 6, 7 });
    try nn.expectGradient(&ctx, Ctx.batchLoss, p, g, null, .{ .tol = 1e-3 });

    const r = try nn.fit(gpa, &ctx, .{ .batch = 32, .max_steps = 2000, .evals_per_epoch = 2 }, n_train, rnd, p, best);
    try testing.expect(r.steps > 0 and r.steps <= r.ran);
    try testing.expectApproxEqAbs(@as(f32, 2), w.of(p)[0], 0.4);
    try testing.expectApproxEqAbs(@as(f32, -1), w.of(p)[1], 0.3);
    try testing.expectApproxEqAbs(@as(f32, 0.5), b.at(p, 0).*, 0.3);
    try testing.expectEqual(r.loss, try ctx.valLoss());

    const preds = try gpa.alloc(f32, n - n_train);
    defer gpa.free(preds);
    for (preds, n_train..) |*q, i| q.* = ctx.predict(i);
    try testing.expect(try nn.auc(f32, gpa, y[n_train..], preds) > 0.75);
}
