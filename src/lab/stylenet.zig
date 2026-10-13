//! Stage 2 of docs/model.md "Playstyle clusters": a residual net on the per-minute style
//! sequence (lab/style.zig). logit = offset (b0's model) + f(x), f = MLP in -> H -> B ->
//! 1, ReLU, dropout after the first layer; the B units are the style embedding. Optional
//! champion-role embedding beside the input. CPU: ~0.1M MACs a row at H 128, seconds an
//! epoch on the Mac, so no GPU path (docs/compute.md). Gradients summed over a fixed
//! number of chunks in order: the same result whatever the thread count

const std = @import("std");
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

const Layout = struct {
    in: u32,
    w1: usize,
    b1: usize,
    w2: usize,
    b2: usize,
    w3: usize,
    b3: usize,
    e: usize,
    len: usize,

    fn init(cfg: Config, d: Data) Layout {
        var l: Layout = undefined;
        l.in = d.n_in + cfg.emb;
        l.w1 = 0;
        l.b1 = l.w1 + cfg.hidden * l.in;
        l.w2 = l.b1 + cfg.hidden;
        l.b2 = l.w2 + cfg.bottleneck * cfg.hidden;
        l.w3 = l.b2 + cfg.bottleneck;
        l.b3 = l.w3 + cfg.bottleneck;
        l.e = l.b3 + 1;
        l.len = l.e + cfg.emb * d.n_ids;
        return l;
    }

    /// Biases get no weight decay
    fn decays(l: Layout, i: usize) bool {
        return !((i >= l.b1 and i < l.w2) or (i >= l.b2 and i < l.w3) or i == l.b3);
    }
};

pub const Net = struct {
    cfg: Config,
    l: Layout,
    p: []f32,
    epochs: u32,
    val_loss: f64,
    seconds_per_epoch: f64,

    pub fn deinit(n: *Net, gpa: std.mem.Allocator) void {
        gpa.free(n.p);
    }

    /// f(x) for row i
    pub fn predict(n: *const Net, d: Data, i: usize) f32 {
        var s: Scratch = undefined;
        return forward(n.cfg, n.l, n.p, d, i, &s, null);
    }

    /// The bottleneck units of row i
    pub fn embed(n: *const Net, d: Data, i: usize, out: []f32) void {
        var s: Scratch = undefined;
        _ = forward(n.cfg, n.l, n.p, d, i, &s, null);
        @memcpy(out, s.h2[0..n.cfg.bottleneck]);
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

const V = @Vector(8, f32);

fn dot(a: []const f32, b: []const f32) f32 {
    var acc: V = @splat(0);
    var i: usize = 0;
    while (i + 8 <= a.len) : (i += 8) acc += @as(V, a[i..][0..8].*) * @as(V, b[i..][0..8].*);
    var s = @reduce(.Add, acc);
    while (i < a.len) : (i += 1) s += a[i] * b[i];
    return s;
}

/// y += a x
fn axpy(y: []f32, a: f32, x: []const f32) void {
    const av: V = @splat(a);
    var i: usize = 0;
    while (i + 8 <= y.len) : (i += 8) {
        const r: V = @as(V, y[i..][0..8].*) + av * @as(V, x[i..][0..8].*);
        y[i..][0..8].* = r;
    }
    while (i < y.len) : (i += 1) y[i] += a * x[i];
}

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
fn forward(cfg: Config, l: Layout, p: []const f32, d: Data, i: usize, s: *Scratch, mask: ?[2]u32) f32 {
    const xin = s.xin[0..l.in];
    @memcpy(xin[0..d.n_in], d.row(i));
    if (cfg.emb > 0) @memcpy(xin[d.n_in..], p[l.e + d.ids[i] * cfg.emb ..][0..cfg.emb]);
    const keep = 1 - cfg.dropout;
    for (0..cfg.hidden) |j| {
        const z = p[l.b1 + j] + dot(p[l.w1 + j * l.in ..][0..l.in], xin);
        s.z1[j] = z;
        const on = if (mask) |m| kept(cfg.seed, m[0], m[1], @intCast(j), keep) else true;
        s.h1[j] = if (z > 0 and on) (if (mask != null) z / keep else z) else 0;
    }
    var f = p[l.b3];
    for (0..cfg.bottleneck) |k| {
        const z = p[l.b2 + k] + dot(p[l.w2 + k * cfg.hidden ..][0..cfg.hidden], s.h1[0..cfg.hidden]);
        s.z2[k] = z;
        s.h2[k] = @max(z, 0);
        f += p[l.w3 + k] * s.h2[k];
    }
    return f;
}

/// Adds row i's log-loss gradient, scaled by `scale`, into g; returns its loss
fn backward(cfg: Config, l: Layout, p: []const f32, d: Data, i: usize, g: []f32, scale: f32, step: u32, r: u32) f64 {
    var s: Scratch = undefined;
    const f = forward(cfg, l, p, d, i, &s, .{ step, r });
    const logit = d.offset[i] + f;
    const prob = 1 / (1 + @exp(-logit));
    const dl = (prob - d.y[i]) * scale;
    g[l.b3] += dl;
    var dh1: [max_hidden]f32 = @splat(0);
    for (0..cfg.bottleneck) |k| {
        g[l.w3 + k] += dl * s.h2[k];
        if (s.z2[k] <= 0) continue;
        const dz = dl * p[l.w3 + k];
        g[l.b2 + k] += dz;
        axpy(g[l.w2 + k * cfg.hidden ..][0..cfg.hidden], dz, s.h1[0..cfg.hidden]);
        axpy(dh1[0..cfg.hidden], dz, p[l.w2 + k * cfg.hidden ..][0..cfg.hidden]);
    }
    const keep = 1 - cfg.dropout;
    const xin = s.xin[0..l.in];
    for (0..cfg.hidden) |j| {
        if (s.h1[j] == 0) continue;
        const dz = dh1[j] / keep;
        g[l.b1 + j] += dz;
        axpy(g[l.w1 + j * l.in ..][0..l.in], dz, xin);
        if (cfg.emb > 0) axpy(g[l.e + d.ids[i] * cfg.emb ..][0..cfg.emb], dz, p[l.w1 + j * l.in + d.n_in ..][0..cfg.emb]);
    }
    return analysis.logLoss(prob, d.y[i]);
}

const Step = struct {
    cfg: Config,
    l: Layout,
    p: []const f32,
    d: Data,
    rows: []const u32,
    grads: [chunks][]f32,
    step: u32,

    fn body(s: *const Step, c: usize) !void {
        const g = s.grads[c];
        @memset(g, 0);
        const per = (s.rows.len + chunks - 1) / chunks;
        const lo = @min(c * per, s.rows.len);
        const hi = @min(lo + per, s.rows.len);
        const scale = 1 / @as(f32, @floatFromInt(s.rows.len));
        for (s.rows[lo..hi], lo..) |i, r| _ = backward(s.cfg, s.l, s.p, s.d, i, g, scale, s.step, @intCast(r));
    }
};

const Eval = struct {
    cfg: Config,
    l: Layout,
    p: []const f32,
    d: Data,
    rows: []const u32,
    out: []f64,

    fn body(e: *const Eval, i: usize) !void {
        var s: Scratch = undefined;
        const r = e.rows[i];
        const f = forward(e.cfg, e.l, e.p, e.d, r, &s, null);
        e.out[i] = analysis.logLoss(1 / (1 + @exp(-(e.d.offset[r] + f))), e.d.y[r]);
    }
};

fn meanLoss(gpa: std.mem.Allocator, io: std.Io, cfg: Config, l: Layout, p: []const f32, d: Data, rows: []const u32) !f64 {
    const out = try gpa.alloc(f64, rows.len);
    defer gpa.free(out);
    const e: Eval = .{ .cfg = cfg, .l = l, .p = p, .d = d, .rows = rows, .out = out };
    try par.forEach(io, rows.len, &e, Eval.body);
    return analysis.mean(out);
}

/// Trains on `train`, keeping the epoch with the lowest mean log loss on `val`
pub fn train(gpa: std.mem.Allocator, io: std.Io, cfg: Config, d: Data, train_rows: []const u32, val: []const u32) !Net {
    std.debug.assert(cfg.hidden <= max_hidden and cfg.bottleneck <= max_bottleneck and d.n_in + cfg.emb <= max_in);
    const l: Layout = .init(cfg, d);
    const p = try gpa.alloc(f32, l.len);
    errdefer gpa.free(p);
    var prng: std.Random.DefaultPrng = .init(cfg.seed);
    const rnd = prng.random();
    // He init for the ReLU layers; the output starts at 0, so f starts as the offset
    @memset(p, 0);
    const s1 = @sqrt(2 / @as(f32, @floatFromInt(l.in)));
    for (p[l.w1..l.b1]) |*w| w.* = rnd.floatNorm(f32) * s1;
    const s2 = @sqrt(2 / @as(f32, @floatFromInt(cfg.hidden)));
    for (p[l.w2..l.b2]) |*w| w.* = rnd.floatNorm(f32) * s2;
    for (p[l.e..]) |*w| w.* = rnd.floatNorm(f32) * 0.1;
    const best = try gpa.dupe(f32, p);
    defer gpa.free(best);
    const m1 = try gpa.alloc(f32, l.len);
    defer gpa.free(m1);
    const m2 = try gpa.alloc(f32, l.len);
    defer gpa.free(m2);
    @memset(m1, 0);
    @memset(m2, 0);
    var st: Step = .{ .cfg = cfg, .l = l, .p = p, .d = d, .rows = &.{}, .grads = undefined, .step = 0 };
    for (&st.grads) |*g| g.* = try gpa.alloc(f32, l.len);
    defer for (st.grads) |g| gpa.free(g);
    const order = try gpa.dupe(u32, train_rows);
    defer gpa.free(order);

    var best_loss = try meanLoss(gpa, io, cfg, l, p, d, val);
    var best_epoch: u32 = 0;
    var t: u32 = 0;
    const t0 = std.Io.Clock.awake.now(io);
    var epochs: u32 = 0;
    for (1..cfg.max_epochs + 1) |epoch| {
        epochs = @intCast(epoch);
        rnd.shuffle(u32, order);
        var start: usize = 0;
        while (start < order.len) : (start += cfg.batch) {
            st.rows = order[start..@min(start + cfg.batch, order.len)];
            st.step = t;
            try par.forEach(io, chunks, &st, Step.body);
            t += 1;
            const c1 = 1 - std.math.pow(f32, 0.9, @floatFromInt(t));
            const c2 = 1 - std.math.pow(f32, 0.999, @floatFromInt(t));
            for (p, m1, m2, 0..) |*w, *a, *b, i| {
                var g: f32 = 0;
                for (st.grads) |gr| g += gr[i];
                a.* = 0.9 * a.* + 0.1 * g;
                b.* = 0.999 * b.* + 0.001 * g * g;
                const decay: f32 = if (l.decays(i)) cfg.wd * w.* else 0;
                w.* -= cfg.lr * ((a.* / c1) / (@sqrt(b.* / c2) + 1e-8) + decay);
            }
        }
        const loss = try meanLoss(gpa, io, cfg, l, p, d, val);
        std.log.scoped(.stylenet).info("H{d} B{d} drop {d:.1} emb {d} epoch {d}: inner val {d:.5}", .{ cfg.hidden, cfg.bottleneck, cfg.dropout, cfg.emb, epoch, loss });
        if (loss < best_loss) {
            best_loss = loss;
            best_epoch = @intCast(epoch);
            @memcpy(best, p);
        } else if (epoch - best_epoch >= cfg.patience) break;
    }
    const secs = @as(f64, @floatFromInt(t0.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds())) / 1e9 / @as(f64, @floatFromInt(epochs));
    @memcpy(p, best);
    return .{ .cfg = cfg, .l = l, .p = p, .epochs = best_epoch, .val_loss = best_loss, .seconds_per_epoch = secs };
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
    const n_in = 5;
    var x: [n_in]f32 = .{ 0.5, -1.2, 0.3, 2.0, -0.7 };
    const ids = [_]u32{1};
    const offset = [_]f32{0.2};
    const y = [_]f32{1};
    const d: Data = .{ .x = &x, .n_in = n_in, .ids = &ids, .n_ids = 2, .offset = &offset, .y = &y };
    const cfg: Config = .{ .hidden = 6, .bottleneck = 3, .emb = 2, .dropout = 0 };
    const l: Layout = .init(cfg, d);
    var p: [200]f32 = undefined;
    std.debug.assert(l.len <= p.len);
    var prng: std.Random.DefaultPrng = .init(5);
    for (p[0..l.len]) |*w| w.* = prng.random().floatNorm(f32) * 0.5;
    var g: [200]f32 = @splat(0);
    _ = backward(cfg, l, p[0..l.len], d, 0, g[0..l.len], 1, 0, 0);
    for (0..l.len) |i| {
        if (i >= l.e and i < l.e + cfg.emb) continue; // row 0's id is 1: these are unused
        const h = 1e-2;
        const w0 = p[i];
        p[i] = w0 + h;
        const up = rowLoss(cfg, l, p[0..l.len], d);
        p[i] = w0 - h;
        const down = rowLoss(cfg, l, p[0..l.len], d);
        p[i] = w0;
        try testing.expectApproxEqAbs((up - down) / (2 * h), g[i], 2e-3);
    }
}

fn rowLoss(cfg: Config, l: Layout, p: []const f32, d: Data) f32 {
    var s: Scratch = undefined;
    const f = forward(cfg, l, p, d, 0, &s, null);
    return @floatCast(analysis.logLoss(1 / (1 + @exp(-(d.offset[0] + f))), d.y[0]));
}
