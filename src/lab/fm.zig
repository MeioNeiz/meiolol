//! Champion-role embedding models for one continuous outcome per player (gold14, cs10,
//! deaths15, lanediff14, first_item). Nested, so each step's gain is measurable:
//!   base:      mu + b[me]                                    (champion-role mean)
//!   additive:  + sum over enemies a[enemy][my role] + allies g[ally][my role]
//!   pairwise:  + sum over enemies w[my role][their role] * <u[me], v[enemy]>
//! "pairwise" is the "vs the specific enemy five" reading: an enemy's effect depends on
//! who you are, weighted per role pair (the lane opponent should weigh most). Adam on
//! minibatches, L2 on everything but mu, epochs picked on a time-split validation
//! slice of train. Use-time features: champions and roles only (docs/production-key.md)

const std = @import("std");
const core = @import("core");
const rows_mod = @import("rows.zig");

pub const Kind = enum { base, additive, pairwise };

pub const Config = struct {
    kind: Kind,
    dim: u32 = 8,
    l2: f32 = 1e-4,
    lr: f32 = 0.01,
    batch: u32 = 4096,
    max_epochs: u32 = 60,
    /// Stop when validation loss has not improved for this many epochs
    patience: u32 = 4,
    seed: u64 = 1,
};

/// A row as the model sees it: champion-role ids (dense), own role, target
pub const Example = struct {
    me: u16,
    role: u3,
    enemies: [5]u16,
    enemy_roles: [5]u3,
    allies: [4]u16,
    ally_roles: [4]u3,
    y: f32,
};

pub const Model = struct {
    cfg: Config,
    n: usize,
    mu: f32 = 0,
    /// Parameters in one slice so Adam runs over them flat
    p: []f32,
    b: []f32,
    a: []f32,
    g: []f32,
    u: []f32,
    v: []f32,
    w: []f32,

    pub fn init(gpa: std.mem.Allocator, cfg: Config, n: usize, mu: f32) !Model {
        const d = cfg.dim;
        const sizes = [_]usize{ n, n * 5, n * 5, n * d, n * d, 25 };
        var total: usize = 0;
        for (sizes) |s| total += s;
        const p = try gpa.alloc(f32, total);
        @memset(p, 0);
        var m: Model = .{ .cfg = cfg, .n = n, .mu = mu, .p = p, .b = undefined, .a = undefined, .g = undefined, .u = undefined, .v = undefined, .w = undefined };
        var at: usize = 0;
        inline for (.{ "b", "a", "g", "u", "v", "w" }, 0..) |name, i| {
            @field(m, name) = p[at .. at + sizes[i]];
            at += sizes[i];
        }
        var rng: std.Random.DefaultPrng = .init(cfg.seed);
        const r = rng.random();
        for (m.u) |*x| x.* = (r.float(f32) - 0.5) * 0.02;
        for (m.v) |*x| x.* = (r.float(f32) - 0.5) * 0.02;
        @memset(m.w, 1);
        return m;
    }

    pub fn deinit(m: *Model, gpa: std.mem.Allocator) void {
        gpa.free(m.p);
    }

    pub fn predict(m: *const Model, e: *const Example) f32 {
        var s = m.mu + m.b[e.me];
        if (m.cfg.kind == .base) return s;
        for (e.enemies) |x| s += m.a[@as(usize, x) * 5 + e.role];
        for (e.allies) |x| s += m.g[@as(usize, x) * 5 + e.role];
        if (m.cfg.kind == .additive) return s;
        const d = m.cfg.dim;
        const um = m.u[@as(usize, e.me) * d ..][0..d];
        for (e.enemies, e.enemy_roles) |x, rx| {
            const vx = m.v[@as(usize, x) * d ..][0..d];
            var dot: f32 = 0;
            for (um, vx) |p, q| dot += p * q;
            s += m.w[@as(usize, e.role) * 5 + rx] * dot;
        }
        return s;
    }

    /// Adds d(loss)/d(params) for one example with residual r = pred - y (squared loss / 2)
    fn grad(m: *const Model, e: *const Example, r: f32, gr: []f32) void {
        const off_b = 0;
        const off_a = m.n;
        const off_g = off_a + m.n * 5;
        const off_u = off_g + m.n * 5;
        const d = m.cfg.dim;
        const off_v = off_u + m.n * d;
        const off_w = off_v + m.n * d;
        gr[off_b + e.me] += r;
        if (m.cfg.kind == .base) return;
        for (e.enemies) |x| gr[off_a + @as(usize, x) * 5 + e.role] += r;
        for (e.allies) |x| gr[off_g + @as(usize, x) * 5 + e.role] += r;
        if (m.cfg.kind == .additive) return;
        const um = m.u[@as(usize, e.me) * d ..][0..d];
        const gu = gr[off_u + @as(usize, e.me) * d ..][0..d];
        for (e.enemies, e.enemy_roles) |x, rx| {
            const wi = @as(usize, e.role) * 5 + rx;
            const vx = m.v[@as(usize, x) * d ..][0..d];
            const gv = gr[off_v + @as(usize, x) * d ..][0..d];
            var dot: f32 = 0;
            for (um, vx) |p, q| dot += p * q;
            gr[off_w + wi] += r * dot;
            const wr = r * m.w[wi];
            for (gu, gv, um, vx) |*a, *b, p, q| {
                a.* += wr * q;
                b.* += wr * p;
            }
        }
    }
};

pub const Fit = struct { model: Model, epochs: u32, val_loss: f64 };

/// Trains on train, stopping on val and returning the model at its best validation
/// epoch; without val, runs cfg.max_epochs and keeps the last
pub fn fit(gpa: std.mem.Allocator, cfg: Config, n: usize, train: []const Example, val: ?[]const Example) !Fit {
    var mu: f64 = 0;
    for (train) |e| mu += e.y;
    mu /= @floatFromInt(@max(train.len, 1));
    var m: Model = try .init(gpa, cfg, n, @floatCast(mu));
    errdefer m.deinit(gpa);
    const best = try gpa.alloc(f32, m.p.len);
    defer gpa.free(best);
    const gr = try gpa.alloc(f32, m.p.len);
    defer gpa.free(gr);
    const m1 = try gpa.alloc(f32, m.p.len);
    defer gpa.free(m1);
    const m2 = try gpa.alloc(f32, m.p.len);
    defer gpa.free(m2);
    @memset(m1, 0);
    @memset(m2, 0);
    const order = try gpa.alloc(u32, train.len);
    defer gpa.free(order);
    for (order, 0..) |*o, i| o.* = @intCast(i);
    var rng: std.Random.DefaultPrng = .init(cfg.seed ^ 0x9e3779b97f4a7c15);

    var best_loss = std.math.inf(f64);
    var best_epoch: u32 = 0;
    var step: u32 = 0;
    const b1: f32 = 0.9;
    const b2: f32 = 0.999;
    var epoch: u32 = 0;
    while (epoch < cfg.max_epochs) : (epoch += 1) {
        rng.random().shuffle(u32, order);
        var at: usize = 0;
        while (at < order.len) : (at += cfg.batch) {
            const batch = order[at..@min(at + cfg.batch, order.len)];
            @memset(gr, 0);
            for (batch) |i| {
                const e = &train[i];
                m.grad(e, m.predict(e) - e.y, gr);
            }
            const scale = 1 / @as(f32, @floatFromInt(batch.len));
            step += 1;
            const c1 = 1 - std.math.pow(f32, b1, @floatFromInt(step));
            const c2 = 1 - std.math.pow(f32, b2, @floatFromInt(step));
            for (m.p, gr, m1, m2) |*p, g0, *s1, *s2| {
                const g = g0 * scale + cfg.l2 * p.*;
                s1.* = b1 * s1.* + (1 - b1) * g;
                s2.* = b2 * s2.* + (1 - b2) * g * g;
                p.* -= cfg.lr * (s1.* / c1) / (@sqrt(s2.* / c2) + 1e-8);
            }
        }
        const v = val orelse {
            best_epoch = epoch + 1;
            continue;
        };
        const loss = mse(&m, v);
        if (loss < best_loss - 1e-9) {
            best_loss = loss;
            best_epoch = epoch + 1;
            @memcpy(best, m.p);
        } else if (epoch + 1 - best_epoch >= cfg.patience) break;
    }
    if (val != null) @memcpy(m.p, best);
    return .{ .model = m, .epochs = best_epoch, .val_loss = best_loss };
}

/// Trains for a fixed number of epochs (the refit on all of train)
pub fn fitEpochs(gpa: std.mem.Allocator, cfg: Config, n: usize, train: []const Example, epochs: u32) !Model {
    var c = cfg;
    c.max_epochs = epochs;
    const f = try fit(gpa, c, n, train, null);
    return f.model;
}

pub fn mse(m: *const Model, set: []const Example) f64 {
    var s: f64 = 0;
    for (set) |*e| {
        const r = m.predict(e) - e.y;
        s += r * r;
    }
    return s / @as(f64, @floatFromInt(@max(set.len, 1)));
}
