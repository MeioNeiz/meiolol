//! Stage 2 of docs/model.md "Playstyle clusters": a residual net on the per-minute style
//! sequence (lab/style.zig). logit = offset (b0's model) + f(x), f = MLP in -> H -> B ->
//! 1, ReLU, dropout after the first layer; the B units are the style embedding. Optional
//! champion-role embedding beside the input. CPU: ~0.1M MACs a row at H 128, seconds an
//! epoch on the Mac, so no GPU path (docs/compute.md). Gradients summed over a fixed
//! number of chunks in order: the same result whatever the thread count

const std = @import("std");
const nn = @import("nn");
const par = @import("../par.zig");
const analysis = @import("../analysis.zig");

pub const Config = struct {
    hidden: u32,
    bottleneck: u32 = 8,
    dropout: f32 = 0.1,
    /// champion-role embedding width, 0 for none
    emb: u32 = 0,
    lr: f32 = 1e-3,
    wd: f32 = 1e-4,
    batch: u32 = 512,
    max_epochs: u32 = 30,
    /// epochs without a better inner validation loss before stopping
    patience: u32 = 3,
    seed: u32 = 1,
};

pub const Data = struct {
    /// rows x n_in, standardised
    x: []const f32,
    n_in: u32,
    /// champion-role id per row
    ids: []const u32,
    n_ids: u32,
    /// another model's log-odds, not learned
    offset: []const f32,
    y: []const f32,

    fn row(d: Data, i: usize) []const f32 {
        return d.x[i * d.n_in ..][0..d.n_in];
    }
};

const chunks = 8;

/// The parameters in Net.p's order: w1 (hidden x in, in = n_in + emb), b1, w2 (bottleneck
/// x hidden), b2, w3, b3, the champion-role table. Biases get no weight decay
const Shape = struct {
    ps: nn.Params,
    in: usize,
    w1: nn.Param,
    b1: nn.Param,
    w2: nn.Param,
    b2: nn.Param,
    w3: nn.Param,
    b3: nn.Param,
    e: nn.Param,

    fn init(gpa: std.mem.Allocator, cfg: Config, d: Data) !Shape {
        var s: Shape = undefined;
        s.ps = .empty;
        errdefer s.ps.deinit(gpa);
        const ps = &s.ps;
        s.in = d.n_in + cfg.emb;
        // He init for the ReLU layers; the output starts at 0, so f starts as the offset
        s.w1 = try ps.matrix(gpa, "w1", cfg.hidden, s.in, .{ .init = heNormal(s.in), .decay = cfg.wd });
        s.b1 = try ps.vector(gpa, "b1", cfg.hidden, .{});
        s.w2 = try ps.matrix(gpa, "w2", cfg.bottleneck, cfg.hidden, .{ .init = heNormal(cfg.hidden), .decay = cfg.wd });
        s.b2 = try ps.vector(gpa, "b2", cfg.bottleneck, .{});
        s.w3 = try ps.vector(gpa, "w3", cfg.bottleneck, .{ .decay = cfg.wd });
        s.b3 = try ps.scalar(gpa, "b3", .{});
        s.e = try ps.table(gpa, "champion_role", d.n_ids, cfg.emb, .{ .init = .{ .normal = 0.1 }, .decay = cfg.wd });
        return s;
    }

    fn heNormal(fan_in: usize) nn.Init {
        return .{ .normal = @sqrt(2 / @as(f32, @floatFromInt(fan_in))) };
    }
};

pub const Net = struct {
    cfg: Config,
    s: Shape,
    p: []f32,
    epochs: u32,
    val_loss: f64,
    seconds_per_epoch: f64,

    pub fn deinit(n: *Net, gpa: std.mem.Allocator) void {
        gpa.free(n.p);
        n.s.ps.deinit(gpa);
    }

    /// f(x) for row i
    pub fn predict(n: *const Net, d: Data, i: usize) f32 {
        var sc: Scratch = undefined;
        return forward(n.cfg, &n.s, n.p, d, i, &sc, null);
    }

    /// The bottleneck units of row i
    pub fn embed(n: *const Net, d: Data, i: usize, out: []f32) void {
        var sc: Scratch = undefined;
        _ = forward(n.cfg, &n.s, n.p, d, i, &sc, null);
        @memcpy(out, sc.h2[0..n.cfg.bottleneck]);
    }
};

const max_in = 512;
const max_hidden = 512;
const max_bottleneck = 16;

const Scratch = struct {
    xin: [max_in]f32,
    z1: [max_hidden]f32,
    h1: [max_hidden]f32,
    z2: [max_bottleneck]f32,
    h2: [max_bottleneck]f32,
};

/// Dropout: whether unit j of batch row r survives at this step. A hash, so any thread
/// order drops the same units
fn kept(seed: u32, step: u32, r: u32, j: u32, keep: f32) bool {
    var h = seed ^ (step *% 0x9e3779b1);
    h = (h ^ r) *% 0xc2b2ae3d;
    h = (h ^ (h >> 15) ^ j) *% 0x27d4eb2f;
    h ^= h >> 13;
    h *%= 0x165667b1;
    h ^= h >> 16;
    return @as(f32, @floatFromInt(h >> 8)) < keep * (1 << 24);
}

/// mask: (step, batch row) for training with dropout, null for prediction
fn forward(cfg: Config, s: *const Shape, p: []const f32, d: Data, i: usize, sc: *Scratch, mask: ?[2]u32) f32 {
    const xin = sc.xin[0..s.in];
    @memcpy(xin[0..d.n_in], d.row(i));
    if (cfg.emb > 0) @memcpy(xin[d.n_in..], s.e.row(p, d.ids[i]));
    const z1 = sc.z1[0..cfg.hidden];
    const h1 = sc.h1[0..cfg.hidden];
    nn.linear.forward(s.w1.of(p), s.b1.of(p), xin, z1);
    const keep = 1 - cfg.dropout;
    for (z1, h1, 0..) |z, *h, j| {
        const on = if (mask) |m| kept(cfg.seed, m[0], m[1], @intCast(j), keep) else true;
        h.* = if (z > 0 and on) (if (mask != null) z / keep else z) else 0;
    }
    const z2 = sc.z2[0..cfg.bottleneck];
    const h2 = sc.h2[0..cfg.bottleneck];
    nn.linear.forward(s.w2.of(p), s.b2.of(p), h1, z2);
    nn.relu.forward(z2, h2, 1, null);
    // In order from b3, not nn.dot's lanes: the sum's rounding is the trained nets'
    var f = s.b3.at(p, 0).*;
    for (s.w3.of(p), h2) |w, h| f += w * h;
    return f;
}

/// Adds row i's log-loss gradient, scaled by `scale`, into g
fn backward(cfg: Config, s: *const Shape, p: []const f32, d: Data, i: usize, g: []f32, scale: f32, step: u32, r: u32) void {
    var sc: Scratch = undefined;
    const f = forward(cfg, s, p, d, i, &sc, .{ step, r });
    const dl = (nn.sigmoid(d.offset[i] + f) - d.y[i]) * scale;
    const h1 = sc.h1[0..cfg.hidden];
    const h2 = sc.h2[0..cfg.bottleneck];
    s.b3.at(g, 0).* += dl;
    nn.axpy(s.w3.of(g), dl, h2);
    var dz2: [max_bottleneck]f32 = undefined;
    for (dz2[0..cfg.bottleneck], s.w3.of(p)) |*dz, w| dz.* = dl * w;
    nn.relu.backward(h2, dz2[0..cfg.bottleneck], 1, dz2[0..cfg.bottleneck]);
    var dz1: [max_hidden]f32 = @splat(0);
    nn.linear.backward(s.w2.of(p), h1, dz2[0..cfg.bottleneck], s.w2.of(g), s.b2.of(g), dz1[0..cfg.hidden]);
    nn.relu.backward(h1, dz1[0..cfg.hidden], 1 - cfg.dropout, dz1[0..cfg.hidden]);
    nn.linear.backward(s.w1.of(p), sc.xin[0..s.in], dz1[0..cfg.hidden], s.w1.of(g), s.b1.of(g), null);
    // Unit by unit into the row, not through linear's din: keeps the summation order
    if (cfg.emb > 0) {
        const ge = s.e.row(g, d.ids[i]);
        for (dz1[0..cfg.hidden], 0..) |dz, j| if (dz != 0) nn.axpy(ge, dz, s.w1.row(p, j)[d.n_in..]);
    }
}

const Step = struct {
    cfg: Config,
    s: *const Shape,
    p: []const f32,
    d: Data,
    rows: []const u32,
    grads: [chunks][]f32,
    step: u32,

    fn body(st: *const Step, c: usize) !void {
        const g = st.grads[c];
        @memset(g, 0);
        const per = (st.rows.len + chunks - 1) / chunks;
        const lo = @min(c * per, st.rows.len);
        const hi = @min(lo + per, st.rows.len);
        const scale = 1 / @as(f32, @floatFromInt(st.rows.len));
        for (st.rows[lo..hi], lo..) |i, r| backward(st.cfg, st.s, st.p, st.d, i, g, scale, st.step, @intCast(r));
    }
};

const Eval = struct {
    cfg: Config,
    s: *const Shape,
    p: []const f32,
    d: Data,
    rows: []const u32,
    out: []f64,

    fn body(e: *const Eval, i: usize) !void {
        var sc: Scratch = undefined;
        const r = e.rows[i];
        const f = forward(e.cfg, e.s, e.p, e.d, r, &sc, null);
        e.out[i] = analysis.logLoss(nn.sigmoid(e.d.offset[r] + f), e.d.y[r]);
    }
};

fn meanLoss(gpa: std.mem.Allocator, io: std.Io, cfg: Config, s: *const Shape, p: []const f32, d: Data, rows: []const u32) !f64 {
    const out = try gpa.alloc(f64, rows.len);
    defer gpa.free(out);
    const e: Eval = .{ .cfg = cfg, .s = s, .p = p, .d = d, .rows = rows, .out = out };
    try par.forEach(io, rows.len, &e, Eval.body);
    return analysis.mean(out);
}

/// train's side of nn.fit: a batch's gradients in `chunks` parts on the threads, summed in
/// chunk order into g, then AdamW
const Fit = struct {
    gpa: std.mem.Allocator,
    io: std.Io,
    st: Step,
    p: []f32,
    g: []f32,
    train_rows: []const u32,
    val: []const u32,
    batch: []u32,
    opt: *nn.Adam,
    segs: []const nn.Segment,
    per_epoch: u64,

    pub fn step(f: *Fit, part: []const u32) !void {
        const rows = f.batch[0..part.len];
        for (rows, part) |*r, k| r.* = f.train_rows[k];
        f.st.rows = rows;
        f.st.step = @intCast(f.opt.t);
        try par.forEach(f.io, chunks, &f.st, Step.body);
        @memset(f.g, 0);
        for (f.st.grads) |gr| for (f.g, gr) |*a, b| {
            a.* += b;
        };
        f.opt.step(f.p, f.g, f.segs);
    }

    pub fn valLoss(f: *Fit) !f64 {
        return meanLoss(f.gpa, f.io, f.st.cfg, f.st.s, f.p, f.st.d, f.val);
    }

    pub fn onEval(f: *Fit, at: u64, loss: f64) void {
        if (at == 0) return;
        const cfg = f.st.cfg;
        std.log.scoped(.stylenet).info("H{d} B{d} drop {d:.1} emb {d} epoch {d}: inner val {d:.5}", .{ cfg.hidden, cfg.bottleneck, cfg.dropout, cfg.emb, at / f.per_epoch, loss });
    }
};

/// Trains on `train`, keeping the epoch with the lowest mean log loss on `val` (the
/// starting net, the offset alone, can win)
pub fn train(gpa: std.mem.Allocator, io: std.Io, cfg: Config, d: Data, train_rows: []const u32, val: []const u32) !Net {
    std.debug.assert(cfg.hidden <= max_hidden and cfg.bottleneck <= max_bottleneck and d.n_in + cfg.emb <= max_in);
    var s: Shape = try .init(gpa, cfg, d);
    errdefer s.ps.deinit(gpa);
    const p = try s.ps.alloc(gpa);
    errdefer gpa.free(p);
    var prng: std.Random.DefaultPrng = .init(cfg.seed);
    const rnd = prng.random();
    s.ps.initValues(p, rnd);
    const g = try s.ps.alloc(gpa);
    defer gpa.free(g);
    const best = try s.ps.alloc(gpa);
    defer gpa.free(best);
    const segs = try s.ps.segments(gpa);
    defer gpa.free(segs);
    var opt: nn.Adam = try .init(gpa, s.ps.len, .{ .lr = cfg.lr });
    defer opt.deinit(gpa);
    const batch = try gpa.alloc(u32, cfg.batch);
    defer gpa.free(batch);
    var f: Fit = .{
        .gpa = gpa,
        .io = io,
        .st = .{ .cfg = cfg, .s = &s, .p = p, .d = d, .rows = &.{}, .grads = undefined, .step = 0 },
        .p = p,
        .g = g,
        .train_rows = train_rows,
        .val = val,
        .batch = batch,
        .opt = &opt,
        .segs = segs,
        .per_epoch = nn.stepsPerEpoch(train_rows.len, cfg.batch),
    };
    var n_grads: usize = 0;
    defer for (f.st.grads[0..n_grads]) |gr| gpa.free(gr);
    for (&f.st.grads) |*gr| {
        gr.* = try s.ps.alloc(gpa);
        n_grads += 1;
    }

    const t0 = std.Io.Clock.awake.now(io);
    const r = try nn.fit(gpa, &f, .{
        .batch = cfg.batch,
        .max_steps = cfg.max_epochs * f.per_epoch,
        .patience = cfg.patience,
        .min_delta = 0,
        .score_start = true,
    }, train_rows.len, rnd, p, best);
    const epochs_run: f64 = @floatFromInt(r.ran / f.per_epoch);
    const secs = @as(f64, @floatFromInt(t0.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds())) / 1e9 / epochs_run;
    return .{ .cfg = cfg, .s = s, .p = p, .epochs = @intCast(r.steps / f.per_epoch), .val_loss = r.loss, .seconds_per_epoch = secs };
}

const testing = std.testing;

test "the net learns a residual the offset misses" {
    // y depends on x0 only through its sign; the offset knows nothing
    const n = 4000;
    const n_in = 4;
    var x: [n * n_in]f32 = undefined;
    var ids: [n]u32 = @splat(0);
    var offset: [n]f32 = @splat(0);
    var y: [n]f32 = undefined;
    var prng: std.Random.DefaultPrng = .init(3);
    const rnd = prng.random();
    for (0..n) |i| {
        for (0..n_in) |k| x[i * n_in + k] = rnd.floatNorm(f32);
        const p: f32 = if (x[i * n_in] > 0) 0.8 else 0.2;
        y[i] = if (rnd.float(f32) < p) 1 else 0;
        ids[i] = @intCast(i % 3);
    }
    const d: Data = .{ .x = &x, .n_in = n_in, .ids = &ids, .n_ids = 3, .offset = &offset, .y = &y };
    var rows: [n]u32 = undefined;
    for (&rows, 0..) |*r, i| r.* = @intCast(i);
    var net = try train(testing.allocator, testing.io, .{ .hidden = 16, .bottleneck = 4, .emb = 2, .batch = 64, .max_epochs = 30, .lr = 3e-3 }, d, rows[0..3000], rows[3000..]);
    defer net.deinit(testing.allocator);
    // Coin flip is 0.693; the sign rule gives about 0.50
    try testing.expect(net.val_loss < 0.56);
    var e: [4]f32 = undefined;
    net.embed(d, 0, &e);
}

test "gradient matches finite differences" {
    const gpa = testing.allocator;
    const n_in = 5;
    var x: [n_in]f32 = .{ 0.5, -1.2, 0.3, 2.0, -0.7 };
    const ids = [_]u32{1};
    const offset = [_]f32{0.2};
    const y = [_]f32{1};
    const d: Data = .{ .x = &x, .n_in = n_in, .ids = &ids, .n_ids = 2, .offset = &offset, .y = &y };
    const cfg: Config = .{ .hidden = 6, .bottleneck = 3, .emb = 2, .dropout = 0 };
    var s: Shape = try .init(gpa, cfg, d);
    defer s.ps.deinit(gpa);
    const p = try s.ps.alloc(gpa);
    defer gpa.free(p);
    var prng: std.Random.DefaultPrng = .init(5);
    for (p) |*w| w.* = prng.random().floatNorm(f32) * 0.5;
    const g = try s.ps.alloc(gpa);
    defer gpa.free(g);
    backward(cfg, &s, p, d, 0, g, 1, 0, 0);
    const Row = struct {
        cfg: Config,
        s: *const Shape,
        p: []const f32,
        d: Data,
        fn loss(r: *const @This()) f64 {
            var sc: Scratch = undefined;
            const f = forward(r.cfg, r.s, r.p, r.d, 0, &sc, null);
            return analysis.logLoss(nn.sigmoid(r.d.offset[0] + f), r.d.y[0]);
        }
    };
    try nn.expectGradient(&Row{ .cfg = cfg, .s = &s, .p = p, .d = d }, Row.loss, p, g, null, .{});
}
