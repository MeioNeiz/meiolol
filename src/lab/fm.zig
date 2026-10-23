//! Champion-role embedding models for one continuous outcome per player (gold14, cs10,
//! deaths15, lanediff14, first_item). Nested, so each step's gain is measurable:
//!   base:      mu + b[me]                                    (champion-role mean)
//!   additive:  + pl[platform][my role] + sum over enemies a[enemy][my role]
//!              + allies g[ally][my role]
//!   lane:      + the pairwise term below for the lane opponent only (both enemies
//!              for bottom and support)
//!   pairwise:  + sum over enemies w[my role][their role] * <u[me], v[enemy]>
//! "pairwise" is the "vs the specific enemy five" reading: an enemy's effect depends on
//! who you are, weighted per role pair (the lane opponent should weigh most). Adam on
//! minibatches, L2 on everything but mu, epochs picked on a time-split validation
//! slice of train. Use-time features: champions and roles only (docs/production-key.md)

const std = @import("std");
const nn = @import("nn");

pub const Kind = enum { base, additive, lane, pairwise };

pub const max_platforms = 16;

pub const Config = struct {
    kind: Kind,
    dim: u32 = 8,
    l2: f32 = 1e-4,
    lr: f32 = 0.003,
    batch: u32 = 8192,
    max_epochs: u32 = 80,
    /// Stop when validation loss has not improved for this many epochs
    patience: u32 = 6,
    seed: u64 = 1,
};

/// A row as the model sees it: champion-role ids (dense), own role, platform, target
pub const Example = struct {
    me: u16,
    role: u3,
    platform: u8,
    enemies: [5]u16,
    enemy_roles: [5]u3,
    allies: [4]u16,
    y: f32,
};

pub const Model = struct {
    cfg: Config,
    n: usize,
    mu: f32 = 0,
    /// Parameters in one slice so Adam runs over them flat
    p: []f32,
    b: []f32,
    /// [platform][my role], additive and pairwise only
    pl: []f32,
    a: []f32,
    g: []f32,
    u: []f32,
    v: []f32,
    w: []f32,

    pub fn init(gpa: std.mem.Allocator, cfg: Config, n: usize, mu: f32) !Model {
        const d = cfg.dim;
        const sizes = [_]usize{ n, max_platforms * 5, n * 5, n * 5, n * d, n * d, 25 };
        var total: usize = 0;
        for (sizes) |s| total += s;
        const p = try gpa.alloc(f32, total);
        @memset(p, 0);
        var m: Model = .{ .cfg = cfg, .n = n, .mu = mu, .p = p, .b = undefined, .pl = undefined, .a = undefined, .g = undefined, .u = undefined, .v = undefined, .w = undefined };
        var at: usize = 0;
        inline for (.{ "b", "pl", "a", "g", "u", "v", "w" }, 0..) |name, i| {
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
        s += m.pl[@as(usize, e.platform) * 5 + e.role];
        for (e.enemies) |x| s += m.a[@as(usize, x) * 5 + e.role];
        for (e.allies) |x| s += m.g[@as(usize, x) * 5 + e.role];
        if (m.cfg.kind == .additive) return s;
        const d = m.cfg.dim;
        const um = m.u[@as(usize, e.me) * d ..][0..d];
        for (e.enemies, e.enemy_roles) |x, rx| {
            if (m.cfg.kind == .lane and !laneMates(e.role, rx)) continue;
            const vx = m.v[@as(usize, x) * d ..][0..d];
            var dot: f32 = 0;
            for (um, vx) |p, q| dot += p * q;
            s += m.w[@as(usize, e.role) * 5 + rx] * dot;
        }
        return s;
    }

    fn offset(m: *const Model, s: []f32) usize {
        return s.ptr - m.p.ptr;
    }

    /// Adds d(loss)/d(params) for one example with residual r = pred - y (squared loss / 2)
    pub fn grad(m: *const Model, e: *const Example, r: f32, gr: []f32) void {
        const off_b = m.offset(m.b);
        const off_a = m.offset(m.a);
        const off_g = m.offset(m.g);
        const off_u = m.offset(m.u);
        const off_v = m.offset(m.v);
        const off_w = m.offset(m.w);
        const d = m.cfg.dim;
        gr[off_b + e.me] += r;
        if (m.cfg.kind == .base) return;
        gr[m.offset(m.pl) + @as(usize, e.platform) * 5 + e.role] += r;
        for (e.enemies) |x| gr[off_a + @as(usize, x) * 5 + e.role] += r;
        for (e.allies) |x| gr[off_g + @as(usize, x) * 5 + e.role] += r;
        if (m.cfg.kind == .additive) return;
        const um = m.u[@as(usize, e.me) * d ..][0..d];
        const gu = gr[off_u + @as(usize, e.me) * d ..][0..d];
        for (e.enemies, e.enemy_roles) |x, rx| {
            if (m.cfg.kind == .lane and !laneMates(e.role, rx)) continue;
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

/// fit's side of nn.fit
const FmFit = struct {
    m: *const Model,
    train: []const Example,
    val: []const Example,
    gr: []f32,
    opt: *nn.Adam,
    segs: []const nn.Segment,

    pub fn step(f: *FmFit, part: []const u32) !void {
        @memset(f.gr, 0);
        for (part) |i| {
            const e = &f.train[i];
            f.m.grad(e, f.m.predict(e) - e.y, f.gr);
        }
        const scale = 1 / @as(f32, @floatFromInt(part.len));
        for (f.gr) |*g| g.* *= scale;
        f.opt.step(f.m.p, f.gr, f.segs);
    }

    pub fn valLoss(f: *FmFit) !f64 {
        return mse(f.m, f.val);
    }
};

/// Trains on train, stopping on val and returning the model at its best validation
/// epoch; without val, runs cfg.max_epochs and keeps the last
pub fn fit(gpa: std.mem.Allocator, cfg: Config, n: usize, train: []const Example, val: ?[]const Example) !Fit {
    var m = try start(gpa, cfg, n, train);
    errdefer m.deinit(gpa);
    const best = try gpa.alloc(f32, m.p.len);
    defer gpa.free(best);
    const gr = try gpa.alloc(f32, m.p.len);
    defer gpa.free(gr);
    var opt = try adam(gpa, m.p.len, cfg);
    defer opt.deinit(gpa);
    var rng = shuffler(cfg);
    var f: FmFit = .{ .m = &m, .train = train, .val = val orelse &.{}, .gr = gr, .opt = &opt, .segs = &.{.{ .len = m.p.len, .decay = cfg.l2 }} };
    const per_epoch = nn.stepsPerEpoch(train.len, cfg.batch);
    const r = try nn.fit(gpa, &f, .{
        .batch = cfg.batch,
        .max_steps = cfg.max_epochs * per_epoch,
        .patience = cfg.patience,
        .min_delta = 1e-9,
        .validate = val != null,
    }, train.len, rng.random(), m.p, best);
    return .{ .model = m, .epochs = @intCast(r.steps / per_epoch), .val_loss = r.loss };
}

/// The model before its first step: mu the train mean, b and pl warm-started
pub fn start(gpa: std.mem.Allocator, cfg: Config, n: usize, train: []const Example) !Model {
    var mu: f64 = 0;
    for (train) |e| mu += e.y;
    mu /= @floatFromInt(@max(train.len, 1));
    var m: Model = try .init(gpa, cfg, n, @floatCast(mu));
    errdefer m.deinit(gpa);
    try warmStart(gpa, &m, train);
    return m;
}

/// Shuffles train's order once per epoch; bench.zig's fits draw the same orders
pub fn shuffler(cfg: Config) std.Random.DefaultPrng {
    return .init(cfg.seed ^ 0x9e3779b97f4a7c15);
}

/// Adam with L2 in the gradient over n parameters. 1 - beta rounds in f32 (0.10000002,
/// not 0.1), as kernels.zig's fm_adam computes it on the GPU
pub fn adam(gpa: std.mem.Allocator, n: usize, cfg: Config) !nn.Adam {
    return .init(gpa, n, .{ .lr = cfg.lr, .beta1 = @as(f32, 0.9), .beta2 = @as(f32, 0.999), .decay = .coupled });
}

/// Trains for a fixed number of epochs (the refit on all of train)
pub fn fitEpochs(gpa: std.mem.Allocator, cfg: Config, n: usize, train: []const Example, epochs: u32) !Model {
    var c = cfg;
    c.max_epochs = epochs;
    const f = try fit(gpa, c, n, train, null);
    return f.model;
}

fn mse(m: *const Model, set: []const Example) f64 {
    var s: f64 = 0;
    for (set) |*e| {
        const r = m.predict(e) - e.y;
        s += r * r;
    }
    return s / @as(f64, @floatFromInt(@max(set.len, 1)));
}

/// Starts b at each champion-role's shrunk mean residual and pl at each platform-role's
/// (on what b leaves): Adam then refines instead of walking there from 0, which early
/// stopping on a drifting validation slice would cut short
fn warmStart(gpa: std.mem.Allocator, m: *Model, train: []const Example) !void {
    const prior = 50;
    const sum = try gpa.alloc(f64, @max(m.b.len, m.pl.len));
    defer gpa.free(sum);
    const cnt = try gpa.alloc(f64, sum.len);
    defer gpa.free(cnt);
    @memset(sum, 0);
    @memset(cnt, 0);
    for (train) |e| {
        sum[e.me] += e.y - m.mu;
        cnt[e.me] += 1;
    }
    for (m.b, sum[0..m.b.len], cnt[0..m.b.len]) |*b, s, c| b.* = @floatCast(s / (c + prior));
    if (m.cfg.kind == .base) return;
    @memset(sum, 0);
    @memset(cnt, 0);
    for (train) |e| {
        const i = @as(usize, e.platform) * 5 + e.role;
        sum[i] += e.y - m.mu - m.b[e.me];
        cnt[i] += 1;
    }
    for (m.pl, sum[0..m.pl.len], cnt[0..m.pl.len]) |*p, s, c| p.* = @floatCast(s / (c + prior));
}

/// The "lane" model's interactions: your lane opponent, and both enemies of the bot 2v2
fn laneMates(mine: u3, theirs: u3) bool {
    const bot = 3;
    const support = 4;
    return mine == theirs or (mine >= bot and theirs >= bot and mine <= support and theirs <= support);
}

/// One enemy's interaction term for e (enemy index k), in model units; 0 outside pairwise
/// and lane models or for a masked role pair
pub fn pairTerm(m: *const Model, e: *const Example, k: usize) f32 {
    if (m.cfg.kind != .lane and m.cfg.kind != .pairwise) return 0;
    const rx = e.enemy_roles[k];
    if (m.cfg.kind == .lane and !laneMates(e.role, rx)) return 0;
    const d = m.cfg.dim;
    const um = m.u[@as(usize, e.me) * d ..][0..d];
    const vx = m.v[@as(usize, e.enemies[k]) * d ..][0..d];
    var dot: f32 = 0;
    for (um, vx) |p, q| dot += p * q;
    return m.w[@as(usize, e.role) * 5 + rx] * dot;
}
