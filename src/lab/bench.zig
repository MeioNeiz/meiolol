//! GPU vs CPU: fm.zig's fits timed on one core (fm.fitEpochs itself), all cores (each
//! minibatch's gradient split across threads) and the GPU (kernels.zig's fm_grad and
//! fm_adam), same seed, same epochs, same shuffles, at 1x and replicated train rows.
//! Predictions on the test rows are checked against the first device's. A sweep is S
//! fits of one config with seeds 1..S: on the CPU one fit per core, on the GPU one
//! after another. docs/compute.md "GPU vs CPU"

const std = @import("std");
const nn = @import("nn");
const fm = @import("fm.zig");
const rows = @import("rows.zig");
const enemy = @import("enemy.zig");
const par = @import("../par.zig");
const cuda = @import("../gpu/cuda.zig");
const layout = @import("../gpu/fm_layout.zig");

pub const Device = enum { cpu1, cpu, gpu };

pub const Options = struct {
    devices: []const Device = &.{ .cpu1, .cpu, .gpu },
    kinds: []const fm.Kind = &.{ .additive, .lane, .pairwise },
    /// For lane and pairwise; additive has no embeddings
    dims: []const u32 = &.{ 8, 32, 128 },
    scales: []const u32 = &.{ 1, 4, 16 },
    /// A fit's length: the grid's fits stop at 8-17 epochs (patience 6)
    epochs: u32 = 10,
    /// Fits per sweep; 0 skips sweeps
    sweep: u32 = 0,
    outcome: rows.Outcome = .gold14,
    /// GPU fits sync after each kernel and log fm_grad's and fm_adam's share of the
    /// time (slower: for profiling, not for timings)
    profile: bool = false,
};

pub fn run(gpa: std.mem.Allocator, io: std.Io, d: *const rows.Data, opts: Options, gpu: ?*const cuda.Gpu, w: *std.Io.Writer) !void {
    var ids = try enemy.buildIds(gpa, d);
    defer ids.map.deinit(gpa);
    var mean: f64 = 0;
    var sd: f64 = 1;
    var sets = try enemy.buildSets(gpa, d, &ids, opts.outcome, &mean, &sd);
    defer sets.deinit(gpa);
    const base = sets.train.ex.items;
    const tests = sets.tests.ex.items;
    const threads = std.Thread.getCpuCount() catch 1;
    try w.print("{s}, {d} train rows, {d} test rows, {d} ids, {d} epochs per fit, {d} CPU threads\n\n", .{
        @tagName(opts.outcome), base.len, tests.len, ids.n, opts.epochs, threads,
    });
    try w.writeAll("| kind | dim | scale | train rows | device | fit s | s per epoch | test MSE | max abs pred diff |\n");
    try w.writeAll("| --- | --- | --- | --- | --- | --- | --- | --- | --- |\n");
    try w.flush();

    const pred = try gpa.alloc(f32, tests.len);
    defer gpa.free(pred);
    const ref = try gpa.alloc(f32, tests.len);
    defer gpa.free(ref);

    for (opts.scales) |scale| {
        const train = try gpa.alloc(fm.Example, base.len * scale);
        defer gpa.free(train);
        for (0..scale) |i| @memcpy(train[i * base.len ..][0..base.len], base);
        var dev_ex: ?DeviceRows = if (gpu) |g| try .init(g, gpa, train) else null;
        defer if (dev_ex) |*x| x.deinit();

        for (opts.kinds) |kind| {
            const dims: []const u32 = if (kind == .additive) &.{8} else opts.dims;
            for (dims) |dim| {
                const cfg: fm.Config = .{ .kind = kind, .dim = dim };
                for (opts.devices, 0..) |dev, di| {
                    if (dev == .gpu and gpu == null) continue;
                    const t0 = std.Io.Clock.awake.now(io);
                    var m = try fitOn(dev, gpa, io, gpu, if (dev_ex) |*x| x else null, cfg, ids.n, train, opts.epochs, opts.profile);
                    defer m.deinit(gpa);
                    const secs = seconds(io, t0);
                    var se: f64 = 0;
                    for (pred, tests) |*p, *e| {
                        p.* = m.predict(e);
                        se += (p.* - e.y) * (p.* - e.y);
                    }
                    if (di == 0) @memcpy(ref, pred);
                    var diff: f32 = 0;
                    for (pred, ref) |p, r| diff = @max(diff, @abs(p - r) * @as(f32, @floatCast(sd)));
                    try w.print("| {s} | {d} | {d}x | {d} | {s} | {d:.2} | {d:.3} | {d:.4} | {e:.2} |\n", .{
                        @tagName(kind),                              dim,                                               scale,
                        train.len,                                   @tagName(dev),                                     secs,
                        secs / @as(f64, @floatFromInt(opts.epochs)), se / @as(f64, @floatFromInt(tests.len)) * sd * sd, diff,
                    });
                    try w.flush();
                }
            }
        }
        if (opts.sweep > 0) try sweeps(gpa, io, gpu, if (dev_ex) |*x| x else null, opts, ids.n, train, scale, w);
    }
}

/// Sweep wall time per device for the biggest dim of each kind
fn sweeps(gpa: std.mem.Allocator, io: std.Io, gpu: ?*const cuda.Gpu, dev_ex: ?*DeviceRows, opts: Options, n: usize, train: []const fm.Example, scale: u32, w: *std.Io.Writer) !void {
    try w.print("\nSweep of {d} fits (seeds 1..{d}), {d}x:\n\n| kind | dim | device | sweep s | s per fit |\n| --- | --- | --- | --- | --- |\n", .{ opts.sweep, opts.sweep, scale });
    for (opts.kinds) |kind| {
        const dims: []const u32 = if (kind == .additive) &.{8} else opts.dims;
        for (dims) |dim| for (opts.devices) |dev| {
            if (dev == .gpu and gpu == null) continue;
            const cfg: fm.Config = .{ .kind = kind, .dim = dim };
            const t0 = std.Io.Clock.awake.now(io);
            switch (dev) {
                // One core's sweep is S of its fits in a row; timed as such only when cheap
                .cpu1 => continue,
                .cpu => {
                    const Ctx = struct {
                        gpa: std.mem.Allocator,
                        cfg: fm.Config,
                        n: usize,
                        train: []const fm.Example,
                        epochs: u32,
                        fn one(c: @This(), i: usize) !void {
                            var cfg_i = c.cfg;
                            cfg_i.seed = i + 1;
                            var m = try fm.fitEpochs(c.gpa, cfg_i, c.n, c.train, c.epochs);
                            m.deinit(c.gpa);
                        }
                    };
                    try par.forEach(io, opts.sweep, Ctx{ .gpa = gpa, .cfg = cfg, .n = n, .train = train, .epochs = opts.epochs }, Ctx.one);
                },
                .gpu => for (0..opts.sweep) |i| {
                    var cfg_i = cfg;
                    cfg_i.seed = i + 1;
                    var m = try fitGpu(gpa, io, gpu.?, dev_ex.?, cfg_i, n, train, opts.epochs, opts.profile);
                    m.deinit(gpa);
                },
            }
            const secs = seconds(io, t0);
            try w.print("| {s} | {d} | {s} | {d:.2} | {d:.3} |\n", .{
                @tagName(kind), dim, @tagName(dev), secs, secs / @as(f64, @floatFromInt(opts.sweep)),
            });
            try w.flush();
        };
    }
    try w.writeAll("\n");
}

fn seconds(io: std.Io, t0: std.Io.Timestamp) f64 {
    const ns = t0.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds();
    return @as(f64, @floatFromInt(ns)) / 1e9;
}

fn fitOn(dev: Device, gpa: std.mem.Allocator, io: std.Io, gpu: ?*const cuda.Gpu, dev_ex: ?*DeviceRows, cfg: fm.Config, n: usize, train: []const fm.Example, epochs: u32, profile: bool) !fm.Model {
    return switch (dev) {
        .cpu1 => fm.fitEpochs(gpa, cfg, n, train, epochs),
        .cpu => fitThreads(gpa, io, cfg, n, train, epochs),
        .gpu => fitGpu(gpa, io, gpu.?, dev_ex.?, cfg, n, train, epochs, profile),
    };
}

/// fm.fitEpochs with each batch's gradient summed over one slice per thread, then
/// reduced and stepped by parameter range. Float sums run in a different order, so
/// results match the serial fit to rounding, not bit for bit
pub fn fitThreads(gpa: std.mem.Allocator, io: std.Io, cfg: fm.Config, n: usize, train: []const fm.Example, epochs: u32) !fm.Model {
    var m = try fm.start(gpa, cfg, n, train);
    errdefer m.deinit(gpa);
    const parts = std.Thread.getCpuCount() catch 1;
    const len = m.p.len;
    const grads = try gpa.alloc(f32, parts * len);
    defer gpa.free(grads);
    const gr = try gpa.alloc(f32, len);
    defer gpa.free(gr);
    var opt = try fm.adam(gpa, len, cfg);
    defer opt.deinit(gpa);
    const order = try gpa.alloc(u32, train.len);
    defer gpa.free(order);
    for (order, 0..) |*o, i| o.* = @intCast(i);
    var rng = fm.shuffler(cfg);

    const Grad = struct {
        m: *const fm.Model,
        train: []const fm.Example,
        batch: []const u32,
        grads: []f32,
        parts: usize,
        fn part(c: @This(), t: usize) !void {
            const len_ = c.m.p.len;
            const g = c.grads[t * len_ ..][0..len_];
            @memset(g, 0);
            const lo = c.batch.len * t / c.parts;
            const hi = c.batch.len * (t + 1) / c.parts;
            for (c.batch[lo..hi]) |i| {
                const e = &c.train[i];
                c.m.grad(e, c.m.predict(e) - e.y, g);
            }
        }
    };
    const Step = struct {
        p: []f32,
        gr: []f32,
        grads: []const f32,
        parts: usize,
        scale: f32,
        l2: f32,
        opt: *const nn.Adam,
        s: nn.Adam.Step,
        fn range(c: @This(), r: usize) !void {
            const len_ = c.p.len;
            const lo = len_ * r / c.parts;
            const hi = len_ * (r + 1) / c.parts;
            for (lo..hi) |j| {
                var g: f32 = 0;
                for (0..c.parts) |t| g += c.grads[t * len_ + j];
                c.gr[j] = g * c.scale;
            }
            c.opt.update(c.s, c.p, c.gr, lo, hi, c.l2);
        }
    };
    for (0..epochs) |_| {
        rng.random().shuffle(u32, order);
        var at: usize = 0;
        while (at < order.len) : (at += cfg.batch) {
            const batch = order[at..@min(at + cfg.batch, order.len)];
            try par.forEach(io, parts, Grad{ .m = &m, .train = train, .batch = batch, .grads = grads, .parts = parts }, Grad.part);
            const scale = 1 / @as(f32, @floatFromInt(batch.len));
            const s: Step = .{ .p = m.p, .gr = gr, .grads = grads, .parts = parts, .scale = scale, .l2 = cfg.l2, .opt = &opt, .s = opt.begin() };
            try par.forEach(io, parts, s, Step.range);
        }
    }
    return m;
}

/// Train rows on the device, uploaded once per data size
const DeviceRows = struct {
    gpu: *const cuda.Gpu,
    ex: cuda.DevicePtr,
    order: cuda.DevicePtr,
    len: usize,

    fn init(gpu: *const cuda.Gpu, gpa: std.mem.Allocator, train: []const fm.Example) !DeviceRows {
        const host = try gpa.alloc(layout.Example, train.len);
        defer gpa.free(host);
        for (host, train) |*h, e| {
            h.* = .{ .me = e.me, .role = e.role, .platform = e.platform, .enemies = undefined, .enemy_roles = undefined, .allies = undefined, .y = e.y };
            for (&h.enemies, &h.enemy_roles, e.enemies, e.enemy_roles) |*x, *r, ex, er| {
                x.* = ex;
                r.* = er;
            }
            for (&h.allies, e.allies) |*x, a| x.* = a;
        }
        const ex = try gpu.alloc(layout.Example, train.len);
        errdefer gpu.free(ex);
        try gpu.upload(layout.Example, ex, host);
        return .{ .gpu = gpu, .ex = ex, .order = try gpu.alloc(u32, train.len), .len = train.len };
    }

    fn deinit(r: *DeviceRows) void {
        r.gpu.free(r.ex);
        r.gpu.free(r.order);
    }
};

/// fm.fitEpochs on the GPU: the host draws the same shuffles, the device holds rows,
/// parameters and Adam state; gradients sum with float atomics (order varies by run)
pub fn fitGpu(gpa: std.mem.Allocator, io: std.Io, gpu: *const cuda.Gpu, rows_dev: *DeviceRows, cfg: fm.Config, n: usize, train: []const fm.Example, epochs: u32, profile: bool) !fm.Model {
    var m = try fm.start(gpa, cfg, n, train);
    errdefer m.deinit(gpa);
    const off = struct {
        fn of(model: *const fm.Model, s: []const f32) u32 {
            return @intCast(s.ptr - model.p.ptr);
        }
    }.of;
    const lay: layout.Layout = .{
        .b = off(&m, m.b),
        .pl = off(&m, m.pl),
        .a = off(&m, m.a),
        .g = off(&m, m.g),
        .u = off(&m, m.u),
        .v = off(&m, m.v),
        .w = off(&m, m.w),
        .kind = @backingInt(cfg.kind),
        .dim = cfg.dim,
        .mu = m.mu,
    };
    const len: u32 = @intCast(m.p.len);
    var p = try gpu.alloc(f32, len);
    defer gpu.free(p);
    var gr = try gpu.alloc(f32, len);
    defer gpu.free(gr);
    var m1 = try gpu.alloc(f32, len);
    defer gpu.free(m1);
    var m2 = try gpu.alloc(f32, len);
    defer gpu.free(m2);
    var l = try gpu.alloc(u8, @sizeOf(layout.Layout));
    defer gpu.free(l);
    try gpu.upload(f32, p, m.p);
    try gpu.memset32(m1, 0, len);
    try gpu.memset32(m2, 0, len);
    try gpu.upload(u8, l, std.mem.asBytes(&lay));
    // No moments on the host (fm_adam keeps them on the device): only each step's constants
    var opt = try fm.adam(gpa, 0, cfg);
    defer opt.deinit(gpa);
    const grad_fn = try gpu.function("fm_grad");
    const adam_fn = try gpu.function("fm_adam");

    const order = try gpa.alloc(u32, train.len);
    defer gpa.free(order);
    for (order, 0..) |*o, i| o.* = @intCast(i);
    var rng = fm.shuffler(cfg);
    var ex = rows_dev.ex;
    var dorder = rows_dev.order;
    var step: u32 = 0;
    var grad_ns: i96 = 0;
    var adam_ns: i96 = 0;
    const t_fit = std.Io.Clock.awake.now(io);
    for (0..epochs) |_| {
        rng.random().shuffle(u32, order);
        try gpu.upload(u32, dorder, order);
        var at: u32 = 0;
        while (at < order.len) : (at += cfg.batch) {
            var count: u32 = @intCast(@min(cfg.batch, order.len - at));
            var start = at;
            try gpu.memset32(gr, 0, len);
            if (profile) try gpu.sync();
            const t_grad = std.Io.Clock.awake.now(io);
            try gpu.launch(grad_fn, count, &.{ @ptrCast(&p), @ptrCast(&gr), @ptrCast(&ex), @ptrCast(&dorder), @ptrCast(&start), @ptrCast(&count), @ptrCast(&l) });
            if (profile) {
                try gpu.sync();
                grad_ns += t_grad.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds();
            }
            const t_adam = std.Io.Clock.awake.now(io);
            step += 1;
            const a = opt.begin();
            var n_ = len;
            var lr = a.lr;
            var l2 = cfg.l2;
            var scale = 1 / @as(f32, @floatFromInt(count));
            var c1 = a.c1;
            var c2 = a.c2;
            try gpu.launch(adam_fn, len, &.{ @ptrCast(&p), @ptrCast(&gr), @ptrCast(&m1), @ptrCast(&m2), @ptrCast(&n_), @ptrCast(&lr), @ptrCast(&l2), @ptrCast(&scale), @ptrCast(&c1), @ptrCast(&c2) });
            if (profile) {
                try gpu.sync();
                adam_ns += t_adam.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds();
            }
        }
    }
    try gpu.sync();
    if (profile) {
        const all: f64 = @floatFromInt(t_fit.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds());
        const g: f64 = @floatFromInt(grad_ns);
        const ad: f64 = @floatFromInt(adam_ns);
        const steps: f64 = @floatFromInt(step);
        std.log.info("fm {t} dim {d}: {d} steps, fm_grad {d:.1}% ({d:.1} us a step), fm_adam {d:.1}%, rest (memset, uploads, launches) {d:.1}%", .{
            cfg.kind, cfg.dim, step, 100 * g / all, g / 1000 / steps, 100 * ad / all, 100 * (all - g - ad) / all,
        });
    }
    try gpu.download(f32, m.p, p);
    return m;
}

const testing = std.testing;

test "threaded fit matches the serial fit to rounding" {
    const gpa = testing.allocator;
    var rng: std.Random.DefaultPrng = .init(7);
    const r = rng.random();
    const n = 40;
    const train = try gpa.alloc(fm.Example, 3000);
    defer gpa.free(train);
    for (train) |*e| {
        e.* = .{ .me = r.uintLessThan(u16, n), .role = r.uintLessThan(u3, 5), .platform = r.uintLessThan(u8, 3), .enemies = undefined, .enemy_roles = .{ 0, 1, 2, 3, 4 }, .allies = undefined, .y = r.floatNorm(f32) };
        for (&e.enemies) |*x| x.* = r.uintLessThan(u16, n);
        for (&e.allies) |*x| x.* = r.uintLessThan(u16, n);
        e.y += @as(f32, @floatFromInt(e.me % 5)) * 0.3;
    }
    const cfg: fm.Config = .{ .kind = .pairwise, .dim = 4, .batch = 256 };
    var a = try fm.fitEpochs(gpa, cfg, n, train, 4);
    defer a.deinit(gpa);
    var b = try fitThreads(gpa, testing.io, cfg, n, train, 4);
    defer b.deinit(gpa);
    for (train[0..200]) |*e| try testing.expectApproxEqAbs(a.predict(e), b.predict(e), 1e-4);
}
