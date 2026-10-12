//! The planned deep draft model (meiolol-88's shape B, LoLDraftAI-like), timed on one
//! core, all cores and the GPU for the GPU vs CPU benchmark (docs/compute.md):
//!   x = per slot, champion-role embedding + role embedding (10 x 32, blue then red)
//!   f = MLP 320 -> 512 -> 256 -> 1, ReLU, dropout 0.1
//!   logit = (f(blue, red) - f(red, blue)) / 2 + c[platform]
//! Log loss, AdamW, batch 1024 games (2048 rows: both side orders). Same seed, shuffles
//! and dropout masks on every device; only float sum order differs

const std = @import("std");
const rows = @import("rows.zig");
const par = @import("../par.zig");
const cuda = @import("../gpu/cuda.zig");
const dn = @import("../gpu/draftnet_layout.zig");

const n_platforms = 16;
/// Champion-roles with fewer train games share their role's id (0..4)
const min_games = 30;

pub const Config = struct {
    lr: f32 = 1e-3,
    wd: f32 = 1e-4,
    batch: u32 = 1024,
    seed: u32 = 1,
};

pub const Games = struct {
    train: []dn.Game,
    tests: []dn.Game,
    n_ids: u32,

    pub fn deinit(g: *Games, gpa: std.mem.Allocator) void {
        gpa.free(g.train);
        gpa.free(g.tests);
    }
};

/// Every game (win is known for all, not only those reaching 15:00), split as the protocol
pub fn buildGames(gpa: std.mem.Allocator, d: *const rows.Data) !Games {
    var counts: std.AutoHashMapUnmanaged(u64, u32) = .empty;
    defer counts.deinit(gpa);
    for (d.games) |g| if (!g.is_test) for (g.teams) |team| for (team, 0..) |champion, role| {
        const e = try counts.getOrPutValue(gpa, key(champion, role), 0);
        e.value_ptr.* += 1;
    };
    var ids: std.AutoHashMapUnmanaged(u64, u32) = .empty;
    defer ids.deinit(gpa);
    var n_ids: u32 = 5;
    var it = counts.iterator();
    while (it.next()) |e| if (e.value_ptr.* >= min_games) {
        try ids.put(gpa, e.key_ptr.*, n_ids);
        n_ids += 1;
    };
    var train: std.ArrayList(dn.Game) = .empty;
    errdefer train.deinit(gpa);
    var tests: std.ArrayList(dn.Game) = .empty;
    errdefer tests.deinit(gpa);
    for (d.games) |g| {
        var out: dn.Game = .{ .ids = undefined, .platform = g.platform, .y = if (g.winner == 0) 1 else 0 };
        for (0..2) |side| for (0..5) |role| {
            out.ids[side * 5 + role] = ids.get(key(g.teams[side][role], role)) orelse @intCast(role);
        };
        try (if (g.is_test) &tests else &train).append(gpa, out);
    }
    return .{ .train = try train.toOwnedSlice(gpa), .tests = try tests.toOwnedSlice(gpa), .n_ids = n_ids };
}

fn key(champion: u32, role: usize) u64 {
    return (@as(u64, champion) << 3) | role;
}

pub const Net = struct {
    l: dn.Layout,
    p: []f32,

    pub fn init(gpa: std.mem.Allocator, n_ids: u32, seed: u32) !Net {
        const l: dn.Layout = .init(n_ids, n_platforms);
        const p = try gpa.alloc(f32, l.len);
        @memset(p, 0);
        var rng: std.Random.DefaultPrng = .init(seed);
        const r = rng.random();
        const blocks = [_]struct { from: u32, to: u32, bound: f32 }{
            .{ .from = l.e, .to = l.r, .bound = 0.1 },
            .{ .from = l.w1, .to = l.w2, .bound = @sqrt(6.0 / @as(f32, dn.input)) },
            .{ .from = l.w2, .to = l.w3, .bound = @sqrt(6.0 / @as(f32, dn.h1)) },
            .{ .from = l.w3, .to = l.len, .bound = @sqrt(3.0 / @as(f32, dn.h2)) },
        };
        for (blocks) |b| for (p[b.from..b.to]) |*x| {
            x.* = (r.float(f32) * 2 - 1) * b.bound;
        };
        return .{ .l = l, .p = p };
    }

    pub fn deinit(n: *Net, gpa: std.mem.Allocator) void {
        gpa.free(n.p);
    }

    /// Blue's win chance per game, dropout off
    pub fn predict(n: *const Net, gpa: std.mem.Allocator, io: std.Io, games: []const dn.Game, out: []f32) !void {
        var w: Work = try .init(gpa, 1024);
        defer w.deinit(gpa);
        const order = try gpa.alloc(u32, games.len);
        defer gpa.free(order);
        for (order, 0..) |*o, i| o.* = @intCast(i);
        var at: usize = 0;
        while (at < games.len) : (at += 1024) {
            const batch = order[at..@min(at + 1024, games.len)];
            try w.forward(io, n, games, batch, 0, 0, chunks(std.Thread.getCpuCount() catch 1));
            for (batch, 0..) |gi, g| {
                const logit = (w.f[2 * g] - w.f[2 * g + 1]) / 2 + n.p[n.l.c + games[gi].platform];
                out[gi] = 1 / (1 + @exp(-logit));
            }
        }
    }
};

/// Activations and their gradients for one batch on the CPU
const Work = struct {
    x: []f32,
    z1: []f32,
    h1: []f32,
    z2: []f32,
    h2: []f32,
    f: []f32,
    df: []f32,
    dh2: []f32,
    dh1: []f32,
    dx: []f32,
    /// Transposes, so every product is nt's row-by-row dot products
    dz_t: []f32,
    a_t: []f32,
    w_t: []f32,

    const names = .{ "x", "z1", "h1", "z2", "h2", "f", "df", "dh2", "dh1", "dx", "dz_t", "a_t", "w_t" };

    fn init(gpa: std.mem.Allocator, batch: u32) !Work {
        const r = 2 * batch;
        const sizes = .{ dn.input, dn.h1, dn.h1, dn.h2, dn.h2, 1, 1, dn.h2, dn.h1, dn.input, dn.h1, dn.h1, 0 };
        var w: Work = undefined;
        inline for (names, sizes) |name, width| {
            @field(w, name) = try gpa.alloc(f32, if (width == 0) dn.input * dn.h1 else r * width);
        }
        return w;
    }

    fn deinit(w: *Work, gpa: std.mem.Allocator) void {
        inline for (names) |name| gpa.free(@field(w, name));
    }

    /// f for the batch's 2 x len rows; seed 0 turns dropout off
    fn forward(w: *Work, io: std.Io, n: *const Net, games: []const dn.Game, batch: []const u32, seed: u32, step: u32, parts: usize) !void {
        const rws: u32 = @intCast(2 * batch.len);
        for (0..rws) |i| {
            const g = &games[batch[i / 2]];
            for (0..dn.slots) |slot| {
                const src = if (i % 2 == 1) (slot + 5) % 10 else slot;
                const e = n.p[n.l.e + g.ids[src] * dn.emb ..][0..dn.emb];
                const r = n.p[n.l.r + (slot % 5) * dn.emb ..][0..dn.emb];
                for (w.x[i * dn.input + slot * dn.emb ..][0..dn.emb], e, r) |*x, a, b| x.* = a + b;
            }
        }
        try nt(io, parts, w.x, n.p[n.l.w1..n.l.w2], w.z1, rws, dn.h1, dn.input);
        try act(io, parts, w.z1, n.p[n.l.b1..][0..dn.h1], w.h1, rws, dn.h1, seed, step, 1);
        try nt(io, parts, w.h1, n.p[n.l.w2..n.l.w3], w.z2, rws, dn.h2, dn.h1);
        try act(io, parts, w.z2, n.p[n.l.b2..][0..dn.h2], w.h2, rws, dn.h2, seed, step, 2);
        try nt(io, parts, w.h2, n.p[n.l.w3..n.l.len], w.f, rws, 1, dn.h2);
    }
};

const V = @Vector(8, f32);

fn dot(a: []const f32, b: []const f32) f32 {
    var acc: V = @splat(0);
    var i: usize = 0;
    while (i < a.len) : (i += 8) acc += @as(V, a[i..][0..8].*) * @as(V, b[i..][0..8].*);
    return @reduce(.Add, acc);
}

fn axpy(y: []f32, s: f32, x: []const f32) void {
    const sv: V = @splat(s);
    var i: usize = 0;
    while (i < y.len) : (i += 8) y[i..][0..8].* = @as(V, y[i..][0..8].*) + sv * @as(V, x[i..][0..8].*);
}

/// c[m x n] = a[m x k] . w[n x k]^T (k a multiple of 8), rows split across parts threads.
/// Blocks of 2 rows x 4 columns: 8 independent accumulators, each loaded row used 4 times
fn nt(io: std.Io, parts: usize, a: []const f32, w: []const f32, c: []f32, m: u32, n: u32, k: u32) !void {
    const Ctx = struct {
        a: []const f32,
        w: []const f32,
        c: []f32,
        m: u32,
        n: u32,
        k: u32,
        parts: usize,
        fn run(x: @This(), t: usize) !void {
            const lo = x.m * t / x.parts;
            const hi = x.m * (t + 1) / x.parts;
            var i = lo;
            while (i + 2 <= hi) : (i += 2) {
                var j: usize = 0;
                while (j + 4 <= x.n) : (j += 4) {
                    var acc: [2][4]V = @splat(@splat(@splat(0)));
                    var l: usize = 0;
                    while (l < x.k) : (l += 8) {
                        const a0: V = x.a[i * x.k + l ..][0..8].*;
                        const a1: V = x.a[(i + 1) * x.k + l ..][0..8].*;
                        inline for (0..4) |q| {
                            const wv: V = x.w[(j + q) * x.k + l ..][0..8].*;
                            acc[0][q] += a0 * wv;
                            acc[1][q] += a1 * wv;
                        }
                    }
                    inline for (0..2) |r| inline for (0..4) |q| {
                        x.c[(i + r) * x.n + j + q] = @reduce(.Add, acc[r][q]);
                    };
                }
                for (j..x.n) |jj| for (i..i + 2) |ii| {
                    x.c[ii * x.n + jj] = dot(x.a[ii * x.k ..][0..x.k], x.w[jj * x.k ..][0..x.k]);
                };
            }
            for (i..hi) |ii| for (0..x.n) |jj| {
                x.c[ii * x.n + jj] = dot(x.a[ii * x.k ..][0..x.k], x.w[jj * x.k ..][0..x.k]);
            };
        }
    };
    try split(io, parts, Ctx{ .a = a, .w = w, .c = c, .m = m, .n = n, .k = k, .parts = parts }, Ctx.run);
}

/// dst[c * ld + r] = src[r * cols + c], rows padded with zeros up to ld
fn transpose(io: std.Io, parts: usize, src: []const f32, dst: []f32, rws: u32, cols: u32, ld: u32) !void {
    const Ctx = struct {
        src: []const f32,
        dst: []f32,
        rws: u32,
        cols: u32,
        ld: u32,
        parts: usize,
        fn run(x: @This(), t: usize) !void {
            for (x.cols * t / x.parts..x.cols * (t + 1) / x.parts) |c| {
                const out = x.dst[c * x.ld ..][0..x.ld];
                for (out[0..x.rws], 0..) |*o, r| o.* = x.src[r * x.cols + c];
                @memset(out[x.rws..], 0);
            }
        }
    };
    try split(io, parts, Ctx{ .src = src, .dst = dst, .rws = rws, .cols = cols, .ld = ld, .parts = parts }, Ctx.run);
}

/// dw[n x k] = dz[m x n]^T . a[m x k], as nt over both transposed
fn tn(io: std.Io, parts: usize, w: *Work, dz: []const f32, a: []const f32, dw: []f32, m: u32, n: u32, k: u32) !void {
    const mp = (m + 7) / 8 * 8;
    try transpose(io, parts, dz, w.dz_t, m, n, mp);
    try transpose(io, parts, a, w.a_t, m, k, mp);
    try nt(io, parts, w.dz_t, w.a_t, dw, n, k, mp);
}

/// da[m x k] = dz[m x n] . w[n x k], as nt with w transposed (n a multiple of 8)
fn nn(io: std.Io, parts: usize, w: *Work, dz: []const f32, wt: []const f32, da: []f32, m: u32, n: u32, k: u32) !void {
    try transpose(io, parts, wt, w.w_t, n, k, n);
    try nt(io, parts, dz, w.w_t, da, m, k, n);
}

/// Work pieces per parallel step: several per thread, so fast cores take more of them
/// (the M5's and i5's efficiency cores run a piece ~2-3x slower)
fn chunks(threads: usize) usize {
    return if (threads == 1) 1 else threads * 4;
}

fn split(io: std.Io, parts: usize, ctx: anytype, comptime body: anytype) !void {
    if (parts == 1) return body(ctx, 0);
    try par.forEach(io, parts, ctx, body);
}

fn act(io: std.Io, parts: usize, z: []f32, b: []const f32, h: []f32, m: u32, n: u32, seed: u32, step: u32, layer: u32) !void {
    const Ctx = struct {
        z: []f32,
        b: []const f32,
        h: []f32,
        m: u32,
        n: u32,
        seed: u32,
        step: u32,
        layer: u32,
        parts: usize,
        fn run(x: @This(), t: usize) !void {
            for (x.m * t / x.parts..x.m * (t + 1) / x.parts) |i| for (0..x.n) |j| {
                const at = i * x.n + j;
                const v = x.z[at] + x.b[j];
                x.z[at] = v;
                x.h[at] = if (v > 0 and (x.seed == 0 or dn.kept(x.seed, x.step, x.layer, @intCast(i), @intCast(j))))
                    v / (if (x.seed == 0) 1 else dn.keep)
                else
                    0;
            };
        }
    };
    try split(io, parts, Ctx{ .z = z, .b = b, .h = h, .m = m, .n = n, .seed = seed, .step = step, .layer = layer, .parts = parts }, Ctx.run);
}

fn actBack(io: std.Io, parts: usize, dh: []f32, z: []const f32, m: u32, n: u32, seed: u32, step: u32, layer: u32) !void {
    const Ctx = struct {
        dh: []f32,
        z: []const f32,
        m: u32,
        n: u32,
        seed: u32,
        step: u32,
        layer: u32,
        parts: usize,
        fn run(x: @This(), t: usize) !void {
            for (x.m * t / x.parts..x.m * (t + 1) / x.parts) |i| for (0..x.n) |j| {
                const at = i * x.n + j;
                x.dh[at] = if (x.z[at] > 0 and dn.kept(x.seed, x.step, x.layer, @intCast(i), @intCast(j))) x.dh[at] / dn.keep else 0;
            };
        }
    };
    try split(io, parts, Ctx{ .dh = dh, .z = z, .m = m, .n = n, .seed = seed, .step = step, .layer = layer, .parts = parts }, Ctx.run);
}

fn colsum(dz: []const f32, m: u32, n: u32, out: []f32) void {
    @memset(out[0..n], 0);
    for (0..m) |i| for (out[0..n], dz[i * n ..][0..n]) |*o, d| {
        o.* += d;
    };
}

fn stepSeed(cfg: Config) u32 {
    return cfg.seed *% 0x2545f491 | 1;
}

fn bias(step: u32) [2]f32 {
    return .{
        1 - std.math.pow(f32, 0.9, @floatFromInt(step)),
        1 - std.math.pow(f32, 0.999, @floatFromInt(step)),
    };
}

/// Trains epochs passes on the CPU over threads (1: one core)
pub fn fitCpu(gpa: std.mem.Allocator, io: std.Io, cfg: Config, n_ids: u32, train: []const dn.Game, epochs: u32, threads: usize) !Net {
    const parts = chunks(threads);
    var n: Net = try .init(gpa, n_ids, cfg.seed);
    errdefer n.deinit(gpa);
    const l = n.l;
    var w: Work = try .init(gpa, cfg.batch);
    defer w.deinit(gpa);
    const gr = try gpa.alloc(f32, l.len);
    defer gpa.free(gr);
    const m1 = try gpa.alloc(f32, l.len);
    defer gpa.free(m1);
    const m2 = try gpa.alloc(f32, l.len);
    defer gpa.free(m2);
    @memset(m1, 0);
    @memset(m2, 0);
    const order = try gpa.alloc(u32, train.len);
    defer gpa.free(order);
    for (order, 0..) |*o, i| o.* = @intCast(i);
    var rng: std.Random.DefaultPrng = .init(cfg.seed);
    const seed = stepSeed(cfg);

    const Adam = struct {
        p: []f32,
        gr: []const f32,
        m1: []f32,
        m2: []f32,
        lr: f32,
        wd: f32,
        decay_from: u32,
        c: [2]f32,
        parts: usize,
        fn run(x: @This(), t: usize) !void {
            for (x.p.len * t / x.parts..x.p.len * (t + 1) / x.parts) |i| {
                const g = x.gr[i];
                x.m1[i] = 0.9 * x.m1[i] + 0.1 * g;
                x.m2[i] = 0.999 * x.m2[i] + 0.001 * g * g;
                const decay: f32 = if (i >= x.decay_from) x.wd * x.p[i] else 0;
                x.p[i] -= x.lr * ((x.m1[i] / x.c[0]) / (@sqrt(x.m2[i] / x.c[1]) + 1e-8) + decay);
            }
        }
    };

    var step: u32 = 0;
    for (0..epochs) |_| {
        rng.random().shuffle(u32, order);
        var at: usize = 0;
        while (at < order.len) : (at += cfg.batch) {
            const batch = order[at..@min(at + cfg.batch, order.len)];
            const rws: u32 = @intCast(2 * batch.len);
            step += 1;
            try w.forward(io, &n, train, batch, seed, step, parts);
            @memset(gr, 0);
            const count: f32 = @floatFromInt(batch.len);
            for (batch, 0..) |gi, g| {
                const game = &train[gi];
                const logit = (w.f[2 * g] - w.f[2 * g + 1]) / 2 + n.p[l.c + game.platform];
                const dl = (1 / (1 + @exp(-logit)) - game.y) / count;
                w.df[2 * g] = dl / 2;
                w.df[2 * g + 1] = -dl / 2;
                gr[l.c + game.platform] += dl;
            }
            const w3 = n.p[l.w3..l.len];
            const gw3 = gr[l.w3..l.len];
            for (0..rws) |i| {
                axpy(gw3, w.df[i], w.h2[i * dn.h2 ..][0..dn.h2]);
                for (w.dh2[i * dn.h2 ..][0..dn.h2], w3) |*d, v| d.* = w.df[i] * v;
            }
            try actBack(io, parts, w.dh2, w.z2, rws, dn.h2, seed, step, 2);
            colsum(w.dh2, rws, dn.h2, gr[l.b2..]);
            try tn(io, parts, &w, w.dh2, w.h1, gr[l.w2..l.w3], rws, dn.h2, dn.h1);
            try nn(io, parts, &w, w.dh2, n.p[l.w2..l.w3], w.dh1, rws, dn.h2, dn.h1);
            try actBack(io, parts, w.dh1, w.z1, rws, dn.h1, seed, step, 1);
            colsum(w.dh1, rws, dn.h1, gr[l.b1..]);
            try tn(io, parts, &w, w.dh1, w.x, gr[l.w1..l.w2], rws, dn.h1, dn.input);
            try nn(io, parts, &w, w.dh1, n.p[l.w1..l.w2], w.dx, rws, dn.h1, dn.input);
            for (0..rws) |i| {
                const g = &train[batch[i / 2]];
                for (0..dn.slots) |slot| {
                    const src = if (i % 2 == 1) (slot + 5) % 10 else slot;
                    const d = w.dx[i * dn.input + slot * dn.emb ..][0..dn.emb];
                    axpy(gr[l.e + g.ids[src] * dn.emb ..][0..dn.emb], 1, d);
                    axpy(gr[l.r + (slot % 5) * dn.emb ..][0..dn.emb], 1, d);
                }
            }
            const a: Adam = .{ .p = n.p, .gr = gr, .m1 = m1, .m2 = m2, .lr = cfg.lr, .wd = cfg.wd, .decay_from = l.decay, .c = bias(step), .parts = parts };
            try split(io, parts, a, Adam.run);
        }
    }
    return n;
}

/// Train games on the device, uploaded once per data size
pub const DeviceGames = struct {
    gpu: *const cuda.Gpu,
    games: cuda.DevicePtr,
    order: cuda.DevicePtr,

    pub fn init(gpu: *const cuda.Gpu, train: []const dn.Game) !DeviceGames {
        const games = try gpu.alloc(dn.Game, train.len);
        errdefer gpu.free(games);
        try gpu.upload(dn.Game, games, train);
        return .{ .gpu = gpu, .games = games, .order = try gpu.alloc(u32, train.len) };
    }

    pub fn deinit(d: *DeviceGames) void {
        d.gpu.free(d.games);
        d.gpu.free(d.order);
    }
};

/// fitCpu on the GPU: the same steps as kernels (kernels.zig dn_* and gemm)
pub fn fitGpu(gpa: std.mem.Allocator, gpu: *const cuda.Gpu, dev: *DeviceGames, cfg: Config, n_ids: u32, train: []const dn.Game, epochs: u32) !Net {
    var n: Net = try .init(gpa, n_ids, cfg.seed);
    errdefer n.deinit(gpa);
    const l = n.l;
    var b: Buffers = try .init(gpu, l.len, 2 * cfg.batch);
    defer b.deinit(gpu);
    try gpu.upload(f32, b.p, n.p);
    try gpu.memset32(b.m1, 0, l.len);
    try gpu.memset32(b.m2, 0, l.len);
    const k: Kernels = try .init(gpu);

    const order = try gpa.alloc(u32, train.len);
    defer gpa.free(order);
    for (order, 0..) |*o, i| o.* = @intCast(i);
    var rng: std.Random.DefaultPrng = .init(cfg.seed);
    const seed = stepSeed(cfg);
    var games = dev.games;
    var dorder = dev.order;
    var e_off = l.e;
    var r_off = l.r;
    var c_off = l.c;
    var step: u32 = 0;
    for (0..epochs) |_| {
        rng.random().shuffle(u32, order);
        try gpu.upload(u32, dorder, order);
        var at: u32 = 0;
        while (at < order.len) : (at += cfg.batch) {
            var start = at;
            var count: u32 = @intCast(@min(cfg.batch, order.len - at));
            var rws = 2 * count;
            step += 1;
            try gpu.memset32(b.gr, 0, l.len);
            try gpu.launch(k.gather, rws * dn.input, &.{ @ptrCast(&b.p), @ptrCast(&games), @ptrCast(&dorder), @ptrCast(&start), @ptrCast(&rws), @ptrCast(&e_off), @ptrCast(&r_off), @ptrCast(&b.x) });
            try k.gemm(b.x, sub(b.p, l.w1), b.z1, rws, dn.h1, dn.input, dn.input, 1, 1, dn.input);
            try k.act(b.z1, b.p, l.b1, b.h1, rws, dn.h1, seed, step, 1);
            try k.gemm(b.h1, sub(b.p, l.w2), b.z2, rws, dn.h2, dn.h1, dn.h1, 1, 1, dn.h1);
            try k.act(b.z2, b.p, l.b2, b.h2, rws, dn.h2, seed, step, 2);
            try k.gemm(b.h2, sub(b.p, l.w3), b.f, rws, 1, dn.h2, dn.h2, 1, 1, 0);
            try gpu.launch(k.loss, count, &.{ @ptrCast(&b.f), @ptrCast(&b.p), @ptrCast(&games), @ptrCast(&dorder), @ptrCast(&start), @ptrCast(&count), @ptrCast(&c_off), @ptrCast(&b.df), @ptrCast(&b.gr) });
            try k.gemm(b.df, b.h2, sub(b.gr, l.w3), 1, dn.h2, rws, 0, 1, dn.h2, 1);
            try k.gemm(b.df, sub(b.p, l.w3), b.dh2, rws, dn.h2, 1, 1, 0, 0, 1);
            try k.actBack(b.dh2, b.z2, rws, dn.h2, seed, step, 2);
            try k.colsum(b.dh2, rws, dn.h2, sub(b.gr, l.b2));
            try k.gemm(b.dh2, b.h1, sub(b.gr, l.w2), dn.h2, dn.h1, rws, 1, dn.h2, dn.h1, 1);
            try k.gemm(b.dh2, sub(b.p, l.w2), b.dh1, rws, dn.h1, dn.h2, dn.h2, 1, dn.h1, 1);
            try k.actBack(b.dh1, b.z1, rws, dn.h1, seed, step, 1);
            try k.colsum(b.dh1, rws, dn.h1, sub(b.gr, l.b1));
            try k.gemm(b.dh1, b.x, sub(b.gr, l.w1), dn.h1, dn.input, rws, 1, dn.h1, dn.input, 1);
            try k.gemm(b.dh1, sub(b.p, l.w1), b.dx, rws, dn.input, dn.h1, dn.h1, 1, dn.input, 1);
            try gpu.launch(k.scatter, rws * dn.input, &.{ @ptrCast(&b.dx), @ptrCast(&games), @ptrCast(&dorder), @ptrCast(&start), @ptrCast(&rws), @ptrCast(&e_off), @ptrCast(&r_off), @ptrCast(&b.gr) });
            const c = bias(step);
            var len = l.len;
            var lr = cfg.lr;
            var wd = cfg.wd;
            var decay = l.decay;
            var c1 = c[0];
            var c2 = c[1];
            try gpu.launch(k.adamw, l.len, &.{ @ptrCast(&b.p), @ptrCast(&b.gr), @ptrCast(&b.m1), @ptrCast(&b.m2), @ptrCast(&len), @ptrCast(&lr), @ptrCast(&wd), @ptrCast(&decay), @ptrCast(&c1), @ptrCast(&c2) });
        }
    }
    try gpu.sync();
    try gpu.download(f32, n.p, b.p);
    return n;
}

/// Parameters, Adam state and one batch's activations on the device
const Buffers = struct {
    p: cuda.DevicePtr = 0,
    gr: cuda.DevicePtr = 0,
    m1: cuda.DevicePtr = 0,
    m2: cuda.DevicePtr = 0,
    x: cuda.DevicePtr = 0,
    z1: cuda.DevicePtr = 0,
    h1: cuda.DevicePtr = 0,
    z2: cuda.DevicePtr = 0,
    h2: cuda.DevicePtr = 0,
    f: cuda.DevicePtr = 0,
    df: cuda.DevicePtr = 0,
    dh2: cuda.DevicePtr = 0,
    dh1: cuda.DevicePtr = 0,
    dx: cuda.DevicePtr = 0,

    const names = .{ "p", "gr", "m1", "m2", "x", "z1", "h1", "z2", "h2", "f", "df", "dh2", "dh1", "dx" };

    fn init(gpu: *const cuda.Gpu, len: u32, r: u32) !Buffers {
        const sizes = .{ len, len, len, len, r * dn.input, r * dn.h1, r * dn.h1, r * dn.h2, r * dn.h2, r, r, r * dn.h2, r * dn.h1, r * dn.input };
        var b: Buffers = .{};
        errdefer b.deinit(gpu);
        inline for (names, sizes) |name, size| @field(b, name) = try gpu.alloc(f32, size);
        return b;
    }

    fn deinit(b: *Buffers, gpu: *const cuda.Gpu) void {
        inline for (names) |name| if (@field(b, name) != 0) gpu.free(@field(b, name));
    }
};

fn sub(p: cuda.DevicePtr, offset: u32) cuda.DevicePtr {
    return p + @as(u64, offset) * @sizeOf(f32);
}

const Kernels = struct {
    gpu: *const cuda.Gpu,
    gemm_fn: cuda.Function,
    gather: cuda.Function,
    act_fn: cuda.Function,
    loss: cuda.Function,
    actback_fn: cuda.Function,
    colsum_fn: cuda.Function,
    scatter: cuda.Function,
    adamw: cuda.Function,

    fn init(gpu: *const cuda.Gpu) !Kernels {
        return .{
            .gpu = gpu,
            .gemm_fn = try gpu.function("gemm"),
            .gather = try gpu.function("dn_gather"),
            .act_fn = try gpu.function("dn_act"),
            .loss = try gpu.function("dn_loss"),
            .actback_fn = try gpu.function("dn_actback"),
            .colsum_fn = try gpu.function("dn_colsum"),
            .scatter = try gpu.function("dn_scatter"),
            .adamw = try gpu.function("dn_adamw"),
        };
    }

    /// kernels.zig's gemm: c[i*n + j] = sum a[i*sai + l*sak] * b[l*sbk + j*sbj]
    fn gemm(k: *const Kernels, a: cuda.DevicePtr, b: cuda.DevicePtr, c: cuda.DevicePtr, m: u32, n: u32, kk: u32, sai: u32, sak: u32, sbk: u32, sbj: u32) !void {
        var args = .{ a, b, c, m, n, kk, sai, sak, sbk, sbj };
        var ptrs: [10]?*anyopaque = undefined;
        inline for (0..10) |i| ptrs[i] = @ptrCast(&args[i]);
        try k.gpu.launchGrid(k.gemm_fn, (n + 63) / 64, (m + 63) / 64, 256, &ptrs);
    }

    fn act(k: *const Kernels, z: cuda.DevicePtr, p: cuda.DevicePtr, b_off: u32, h: cuda.DevicePtr, m: u32, n: u32, seed: u32, step: u32, layer: u32) !void {
        var args = .{ z, p, b_off, h, m, n, seed, step, layer };
        var ptrs: [9]?*anyopaque = undefined;
        inline for (0..9) |i| ptrs[i] = @ptrCast(&args[i]);
        try k.gpu.launch(k.act_fn, m * n, &ptrs);
    }

    fn actBack(k: *const Kernels, dh: cuda.DevicePtr, z: cuda.DevicePtr, m: u32, n: u32, seed: u32, step: u32, layer: u32) !void {
        var args = .{ dh, z, m, n, seed, step, layer };
        var ptrs: [7]?*anyopaque = undefined;
        inline for (0..7) |i| ptrs[i] = @ptrCast(&args[i]);
        try k.gpu.launch(k.actback_fn, m * n, &ptrs);
    }

    fn colsum(k: *const Kernels, dz: cuda.DevicePtr, m: u32, n: u32, out: cuda.DevicePtr) !void {
        var args = .{ dz, m, n, out };
        var ptrs: [4]?*anyopaque = undefined;
        inline for (0..4) |i| ptrs[i] = @ptrCast(&args[i]);
        try k.gpu.launch(k.colsum_fn, n, &ptrs);
    }
};

pub const Options = struct {
    devices: []const Device = &.{ .cpu1, .cpu, .gpu },
    scales: []const u32 = &.{ 1, 4, 16, 64 },
    epochs: u32 = 2,
    /// Fits per sweep (seeds 1..S): on the CPU one single-threaded fit per core at once, on
    /// the GPU one after another; 0 skips sweeps
    sweep: u32 = 0,
    /// Train on only the first N games (an agreement check over a few steps); 0 all
    limit: u32 = 0,
};

pub const Device = enum { cpu1, cpu, gpu };

pub fn run(gpa: std.mem.Allocator, io: std.Io, d: *const rows.Data, opts: Options, gpu: ?*const cuda.Gpu, w: *std.Io.Writer) !void {
    var games = try buildGames(gpa, d);
    defer games.deinit(gpa);
    const all_train = games.train;
    defer games.train = all_train;
    if (opts.limit > 0) games.train = games.train[0..@min(opts.limit, games.train.len)];
    const threads = std.Thread.getCpuCount() catch 1;
    try w.print("draft net: {d} train games, {d} test games, {d} ids, {d} params, {d} epochs per timing, {d} CPU threads\n\n", .{
        games.train.len, games.tests.len, games.n_ids, dn.Layout.init(games.n_ids, n_platforms).len, opts.epochs, threads,
    });
    try w.writeAll("| scale | train games | device | s per epoch | test log loss | max abs win chance diff |\n| --- | --- | --- | --- | --- | --- |\n");
    try w.flush();
    const pred = try gpa.alloc(f32, games.tests.len);
    defer gpa.free(pred);
    const ref = try gpa.alloc(f32, games.tests.len);
    defer gpa.free(ref);
    for (opts.scales) |scale| {
        const train = try gpa.alloc(dn.Game, games.train.len * scale);
        defer gpa.free(train);
        for (0..scale) |i| @memcpy(train[i * games.train.len ..][0..games.train.len], games.train);
        var dev: ?DeviceGames = if (gpu) |g| try .init(g, train) else null;
        defer if (dev) |*x| x.deinit();
        for (opts.devices, 0..) |device, di| {
            if (device == .gpu and gpu == null) continue;
            const t0 = std.Io.Clock.awake.now(io);
            var net = switch (device) {
                .cpu1 => try fitCpu(gpa, io, .{}, games.n_ids, train, opts.epochs, 1),
                .cpu => try fitCpu(gpa, io, .{}, games.n_ids, train, opts.epochs, threads),
                .gpu => try fitGpu(gpa, gpu.?, &dev.?, .{}, games.n_ids, train, opts.epochs),
            };
            defer net.deinit(gpa);
            const ns = t0.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds();
            const secs = @as(f64, @floatFromInt(ns)) / 1e9;
            try net.predict(gpa, io, games.tests, pred);
            var ll: f64 = 0;
            for (pred, games.tests) |q, g| ll -= if (g.y > 0.5) @log(@max(q, 1e-7)) else @log(@max(1 - q, 1e-7));
            if (di == 0) @memcpy(ref, pred);
            var diff: f32 = 0;
            for (pred, ref) |a, b| diff = @max(diff, @abs(a - b));
            try w.print("| {d}x | {d} | {s} | {d:.2} | {d:.5} | {e:.2} |\n", .{
                scale, train.len, @tagName(device), secs / @as(f64, @floatFromInt(opts.epochs)), ll / @as(f64, @floatFromInt(pred.len)), diff,
            });
            try w.flush();
        }
        if (opts.sweep > 0) for (opts.devices) |device| {
            if (device == .cpu1 or (device == .gpu and gpu == null)) continue;
            const t0 = std.Io.Clock.awake.now(io);
            switch (device) {
                .cpu1 => unreachable,
                .cpu => {
                    const Ctx = struct {
                        gpa: std.mem.Allocator,
                        io: std.Io,
                        n_ids: u32,
                        train: []const dn.Game,
                        epochs: u32,
                        fn one(c: @This(), i: usize) !void {
                            var net = try fitCpu(c.gpa, c.io, .{ .seed = @intCast(i + 1) }, c.n_ids, c.train, c.epochs, 1);
                            net.deinit(c.gpa);
                        }
                    };
                    try par.forEach(io, opts.sweep, Ctx{ .gpa = gpa, .io = io, .n_ids = games.n_ids, .train = train, .epochs = opts.epochs }, Ctx.one);
                },
                .gpu => for (0..opts.sweep) |i| {
                    var net = try fitGpu(gpa, gpu.?, &dev.?, .{ .seed = @intCast(i + 1) }, games.n_ids, train, opts.epochs);
                    net.deinit(gpa);
                },
            }
            const ns = t0.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds();
            const secs = @as(f64, @floatFromInt(ns)) / 1e9;
            try w.print("| {d}x | sweep of {d} | {s} | {d:.2} per fit-epoch | | |\n", .{
                scale, opts.sweep, @tagName(device), secs / @as(f64, @floatFromInt(opts.sweep * opts.epochs)),
            });
            try w.flush();
        };
    }
}

const testing = std.testing;

test "draft net: threaded fit matches one core, loss falls on a learnable signal" {
    const gpa = testing.allocator;
    var rng: std.Random.DefaultPrng = .init(3);
    const r = rng.random();
    const n_ids = 30;
    const train = try gpa.alloc(dn.Game, 4000);
    defer gpa.free(train);
    for (train) |*g| {
        for (&g.ids) |*id| id.* = r.uintLessThan(u32, n_ids);
        g.platform = 0;
        // Blue wins more often with ids 0-9 in its top slot
        const edge: f32 = if (g.ids[0] < 10) 0.8 else 0.3;
        g.y = if (r.float(f32) < edge) 1 else 0;
    }
    const cfg: Config = .{ .batch = 256 };
    var a = try fitCpu(gpa, testing.io, cfg, n_ids, train, 3, 1);
    defer a.deinit(gpa);
    var b = try fitCpu(gpa, testing.io, cfg, n_ids, train, 3, 4);
    defer b.deinit(gpa);
    const pa = try gpa.alloc(f32, 200);
    defer gpa.free(pa);
    const pb = try gpa.alloc(f32, 200);
    defer gpa.free(pb);
    try a.predict(gpa, testing.io, train[0..200], pa);
    try b.predict(gpa, testing.io, train[0..200], pb);
    var sum: [2]f32 = @splat(0);
    var cnt: [2]f32 = @splat(0);
    for (pa, pb, train[0..200]) |x, y, g| {
        try testing.expectApproxEqAbs(x, y, 1e-4);
        const strong = @intFromBool(g.ids[0] < 10);
        sum[strong] += x;
        cnt[strong] += 1;
    }
    try testing.expect(sum[1] / cnt[1] > sum[0] / cnt[0] + 0.1);
}
