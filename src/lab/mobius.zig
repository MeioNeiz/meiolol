//! `meiolol-lab mobius SNAP --nets DIR`: the teacher read by exact Möbius terms over the
//! ten seats (docs/plan/lab-frontier.md C1; docs/model.md "Order spectrum of the teacher
//! (C1)"). For a draft x and a background draft z, v(S) = the model's blue logit with the
//! seats in S from x and the rest from z. Its Möbius terms m(S) = sum over T in S of
//! (-1)^(|S| - |T|) v(T) add up to the model on x, each the part only the seats of S
//! together carry. Backgrounds: fit drafts sharing no champion with x (so every mix is a
//! legal draft), the same for all 1,024 coalitions, their terms averaged in two halves
//! (even, odd). An order's power = mean over drafts of the halves' summed product, so
//! background noise adds nothing.
//! Models, on netcheck's dev block (fit below the dev cut, explain played dev-val games;
//! no test game is fitted on, a background or explained): B the compiled-in candidate
//! (-Dcand win-additive: blueLogit) refitted here, read apart from its damage mix
//! (mixLogit); T per seed = netcheck --export's set net on it (DIR/setnet-s<seed>.json),
//! and T = the seeds' logit mean. Terms are linear in the model, so B's and each net's
//! own part are computed once and combined.
//! Seat s: side s / 5 (0 blue), role s % 5; bit s of a coalition's mask.
//! `mobius plant-check FILE`: py/xcheck/mobius_plant.py --dump's planted truth, drafts,
//! backgrounds and float64 terms, recomputed here: the two must agree

const std = @import("std");
const api = @import("api");
const cand = @import("cand");
const rows = @import("rows.zig");
const harness = @import("harness.zig");
const winnet = @import("winnet.zig");
const draftfile = @import("../draftfile.zig");
const par = @import("../par.zig");

const Io = std.Io;

pub const usage =
    \\  mobius SNAP --nets DIR [OPT VALUE]...
    \\                                  exact 10-seat Mobius terms of the candidate
    \\                                  (-Dcand win-additive) and the set nets on it
    \\                                  (DIR/setnet-s<seed>.json, netcheck --export 1),
    \\                                  dev block (lab/mobius.zig): --seeds 1,2,3
    \\                                  --explain N (seeded sample of dev-val games,
    \\                                  20000) --bg N (backgrounds a draft, 32)
    \\                                  --seed K --all 1 (every dev-val game: the
    \\                                  truncation test; power stays on the sample)
    \\                                  --out DIR (orders.tsv, coalitions.tsv, trunc.tsv)
    \\  mobius plant-check FILE         py/xcheck/mobius_plant.py --dump's terms
    \\                                  recomputed: max |diff| in pp
    \\
;

pub const n_seat = 10;
pub const n_coal = 1 << n_seat;
const n_order = n_seat + 1;
pub const Draft = [n_seat]u32;
/// Win pp at 50% per logit unit
const pp: f64 = 25;
const pp2 = pp * pp;

const order_of: [n_coal]u8 = blk: {
    @setEvalBranchQuota(4 * n_coal);
    var o: [n_coal]u8 = undefined;
    for (&o, 0..) |*x, m| x.* = @popCount(m);
    break :blk o;
};

/// v(S) to its Möbius terms, in place
pub fn transform(a: *[n_coal]f64) void {
    for (0..n_seat) |i| {
        const bit = @as(usize, 1) << @intCast(i);
        for (0..n_coal) |m| {
            if (m & bit != 0) a[m] -= a[m ^ bit];
        }
    }
}

/// Terms to their sums over supersets, in place: at a pair's mask, the pair's term with
/// the other seats present
fn supersetSums(a: *[n_coal]f64) void {
    for (0..n_seat) |i| {
        const bit = @as(usize, 1) << @intCast(i);
        for (0..n_coal) |m| {
            if (m & bit == 0) a[m] += a[m | bit];
        }
    }
}

fn teamsOf(d: *const Draft) [2][5]u32 {
    return .{ d[0..5].*, d[5..10].* };
}

fn draftOf(t: [2][5]u32) Draft {
    return t[0] ++ t[1];
}

/// Seats in `mask` from x, the rest from z
fn hybrid(x: *const Draft, z: *const Draft, mask: usize) Draft {
    var out: Draft = undefined;
    for (&out, x, z, 0..) |*o, a, b, s| o.* = if (mask >> @intCast(s) & 1 == 1) a else b;
    return out;
}

fn shares(x: *const Draft, z: *const Draft) bool {
    for (x) |a| for (z) |b| {
        if (a == b) return true;
    };
    return false;
}

/// `out.len` drafts of `pool` sharing no champion with x, drawn by (seed, key) alone
pub fn drawBackgrounds(seed: u64, key: u32, x: *const Draft, pool: []const Draft, out: []Draft) void {
    var rng: std.Random.DefaultPrng = .init(std.hash.Wyhash.hash(seed, std.mem.asBytes(&key)));
    const r = rng.random();
    for (out) |*z| {
        while (true) {
            const p = &pool[r.uintLessThan(usize, pool.len)];
            if (shares(x, p)) continue;
            z.* = p.*;
            break;
        }
    }
}

/// Per component the two half-means (backgrounds j even, odd) of the Möbius terms.
/// reader.values(x, z, platform, v) fills each component's value for every coalition
pub fn halfTerms(reader: anytype, x: *const Draft, platform: u8, bgs: []const Draft, v: [][n_coal]f64, out: [][2][n_coal]f64) void {
    std.debug.assert(bgs.len % 2 == 0 and bgs.len > 0);
    for (out) |*o| o.* = @splat(@splat(0));
    for (bgs, 0..) |*z, j| {
        reader.values(x, z, platform, v);
        for (v, out) |*a, *o| {
            transform(a);
            for (&o[j & 1], a) |*s, t| s.* += t;
        }
    }
    const scale = 2 / @as(f64, @floatFromInt(bgs.len));
    for (out) |*o| for (o) |*h| for (h) |*t| {
        t.* *= scale;
    };
}

const max_rho = 256;

/// A set net file (draftfile.SetNet) for coalitions: each champion-role's phi output is
/// fixed, so its share of rho's input is cached, and a coalition one seat away costs two
/// vector adds
pub const SetEval = struct {
    rho: usize,
    /// [entry][own view: rho; other view: rho]. Entries 0..4: a role's unknown champion
    table: []f64,
    index: std.AutoHashMapUnmanaged(u64, u32) = .empty,
    cb: []f64,
    out: []f64,
    /// The base logit's weight, the platform intercepts
    a: f64,
    c: []f64,

    pub fn init(gpa: std.mem.Allocator, sn: *const draftfile.SetNet) !SetEval {
        const f = &sn.f;
        const l = f.layout;
        const p = f.params;
        if (f.rho > max_rho) return error.BadSetNetShape;
        var prof: std.AutoHashMapUnmanaged(u64, []const f32) = .empty;
        defer prof.deinit(gpa);
        var ids: std.AutoHashMapUnmanaged(u64, u32) = .empty;
        defer ids.deinit(gpa);
        var e: SetEval = .{ .rho = f.rho, .table = &.{}, .cb = &.{}, .out = &.{}, .a = p[l.a], .c = &.{} };
        errdefer e.deinit(gpa);
        var keys: std.ArrayList(u64) = .empty;
        defer keys.deinit(gpa);
        for (f.profiles) |x| {
            try prof.put(gpa, api.cellKey(x.champion, x.role), x.z);
            try keys.append(gpa, api.cellKey(x.champion, x.role));
        }
        for (f.ids) |x| {
            try ids.put(gpa, api.cellKey(x.champion, x.role), x.id);
            try keys.append(gpa, api.cellKey(x.champion, x.role));
        }
        for (keys.items) |k| {
            const g = try e.index.getOrPut(gpa, k);
            if (!g.found_existing) g.value_ptr.* = 5 + e.index.count() - 1;
        }
        const n = 5 + e.index.count();
        e.table = try gpa.alloc(f64, n * 2 * f.rho);
        e.cb = try gpa.alloc(f64, f.rho);
        e.out = try gpa.alloc(f64, f.rho);
        e.c = try gpa.alloc(f64, sn.n_platforms);
        for (e.cb, p[l.cb..][0..f.rho]) |*o, w| o.* = w;
        for (e.out, p[l.out..][0..f.rho]) |*o, w| o.* = w;
        for (e.c, p[l.c..][0..sn.n_platforms]) |*o, w| o.* = w;

        const xin = try gpa.alloc(f64, l.in);
        defer gpa.free(xin);
        const u = try gpa.alloc(f64, f.phi);
        defer gpa.free(u);
        for (0..5) |role| e.fill(f, role, role, null, role, xin, u);
        var it = e.index.iterator();
        while (it.next()) |kv| {
            const role: usize = @intCast(kv.key_ptr.* & 7);
            e.fill(f, kv.value_ptr.*, role, prof.get(kv.key_ptr.*), ids.get(kv.key_ptr.*) orelse role, xin, u);
        }
        return e;
    }

    pub fn deinit(e: *SetEval, gpa: std.mem.Allocator) void {
        gpa.free(e.table);
        gpa.free(e.cb);
        gpa.free(e.out);
        gpa.free(e.c);
        e.index.deinit(gpa);
    }

    /// One slot's phi output (profile z or zeros, role one-hot, embedding row) through
    /// each half of V, a fifth of it: its part of the team mean
    fn fill(e: *SetEval, f: *const draftfile.SetNetFile, at: usize, role: usize, z: ?[]const f32, row: usize, x: []f64, u: []f64) void {
        const l = f.layout;
        const p = f.params;
        for (x[0..f.n_prof], 0..) |*o, i| o.* = if (z) |zz| zz[i] else 0;
        for (x[f.n_prof..][0..5], 0..) |*o, i| o.* = @floatFromInt(@intFromBool(i == role));
        for (x[f.n_prof + 5 ..][0..f.emb], p[l.e + row * f.emb ..][0..f.emb]) |*o, v| o.* = v;
        for (u, 0..) |*o, j| {
            var s: f64 = p[l.b1 + j];
            for (x, p[l.w1 + j * l.in ..][0..l.in]) |xi, w| s += w * xi;
            o.* = @max(s, 0) / 5;
        }
        const out = e.table[at * 2 * e.rho ..][0 .. 2 * e.rho];
        for (0..e.rho) |j| {
            const w = p[l.v + j * l.rin ..][0..l.rin];
            var own: f64 = 0;
            var other: f64 = 0;
            for (u, 0..) |uk, k| {
                own += w[k] * uk;
                if (f.cross) other += w[f.phi + k] * uk;
            }
            out[j] = own;
            out[e.rho + j] = other;
        }
    }

    fn entry(e: *const SetEval, champion: u32, role: usize) u32 {
        if (champion == 0) return @intCast(role);
        return e.index.get(api.cellKey(champion, role)) orelse @intCast(role);
    }

    fn score(e: *const SetEval, pre: *const [2][max_rho]f64) f64 {
        var s: f64 = 0;
        for (e.out, pre[0][0..e.rho], pre[1][0..e.rho]) |w, a, b| s += w * (@max(a, 0) - @max(b, 0));
        return s / 2;
    }

    /// The net's own part, (f(blue, red) - f(red, blue)) / 2, for every coalition of x
    /// over z, walked in Gray-code order
    pub fn values(e: *const SetEval, x: *const Draft, z: *const Draft, v: *[n_coal]f64) void {
        const rho = e.rho;
        var pre: [2][max_rho]f64 = undefined;
        @memcpy(pre[0][0..rho], e.cb);
        @memcpy(pre[1][0..rho], e.cb);
        var rows_x: [n_seat][]const f64 = undefined;
        var rows_z: [n_seat][]const f64 = undefined;
        for (0..n_seat) |s| {
            rows_x[s] = e.table[e.entry(x[s], s % 5) * 2 * rho ..][0 .. 2 * rho];
            rows_z[s] = e.table[e.entry(z[s], s % 5) * 2 * rho ..][0 .. 2 * rho];
            const view = s / 5;
            for (pre[view][0..rho], rows_z[s][0..rho]) |*o, w| o.* += w;
            for (pre[1 - view][0..rho], rows_z[s][rho..]) |*o, w| o.* += w;
        }
        v[0] = e.score(&pre);
        var mask: usize = 0;
        for (1..n_coal) |k| {
            const s: usize = @ctz(k);
            const bit = @as(usize, 1) << @intCast(s);
            mask ^= bit;
            const sign: f64 = if (mask & bit != 0) 1 else -1;
            const view = s / 5;
            for (pre[view][0..rho], rows_x[s][0..rho], rows_z[s][0..rho]) |*o, a, b| o.* += sign * (a - b);
            for (pre[1 - view][0..rho], rows_x[s][rho..], rows_z[s][rho..]) |*o, a, b| o.* += sign * (a - b);
            v[mask] = e.score(&pre);
        }
    }
};

const has_logit = @hasDecl(cand, "blueLogit");
const has_mix = @hasDecl(cand, "mixLogit");

/// The compiled-in candidate as a black box; a candidate without mixLogit has no mix
const CandBase = struct {
    m: *const cand.Model,

    pub fn logit(b: CandBase, teams: [2][5]u32, platform: u8) f64 {
        return if (comptime has_logit) cand.blueLogit(b.m, teams, platform) else 0;
    }

    pub fn mix(b: CandBase, teams: [2][5]u32) f64 {
        return if (comptime has_mix) cand.mixLogit(b.m, teams) else 0;
    }
};

/// A draft's value in components: 0 the base without its mix (mains and pair cells), 1
/// the mix, 2.. each net's own part. B.logit(teams, platform), B.mix(teams): 0 is an
/// empty seat
fn Reader(comptime B: type) type {
    return struct {
        b: B,
        nets: []const SetEval = &.{},
        /// The nets' files, for `whole`
        files: []const draftfile.SetNet = &.{},

        const R = @This();

        pub fn components(r: *const R) usize {
            return 2 + r.nets.len;
        }

        fn tables(r: *const R, d: *const Draft, platform: u8) f64 {
            const t = teamsOf(d);
            return r.b.logit(t, platform) - r.b.mix(t);
        }

        pub fn values(r: *const R, x: *const Draft, z: *const Draft, platform: u8, v: [][n_coal]f64) void {
            for (0..n_coal) |mask| {
                const t = teamsOf(&hybrid(x, z, mask));
                const m = r.b.mix(t);
                v[1][mask] = m;
                v[0][mask] = r.b.logit(t, platform) - m;
            }
            for (r.nets, v[2..]) |*n, *o| n.values(x, z, o);
        }

        /// Each component on x itself, the nets by their files' own forward pass: what a
        /// draft's terms must add up to
        pub fn whole(r: *const R, x: *const Draft, platform: u8, out: []f64) void {
            const t = teamsOf(x);
            out[1] = r.b.mix(t);
            out[0] = r.b.logit(t, platform) - out[1];
            for (r.files, out[2..]) |*sn, *o| o.* = sn.logit(t, 0, 0) - sn.f.params[sn.f.layout.c];
        }

        /// The base's pair cell of seats i < j holding a and b, read with every other seat
        /// empty: the logit's second difference there, mix apart
        fn rawCell(r: *const R, i: usize, a: u32, j: usize, b: u32, platform: u8) f64 {
            var d: Draft = @splat(0);
            const none = r.tables(&d, platform);
            d[i] = a;
            const first = r.tables(&d, platform);
            d[j] = b;
            const both = r.tables(&d, platform);
            d[i] = 0;
            return both - first - r.tables(&d, platform) + none;
        }

        /// The cell centred over the backgrounds: what the pair's Möbius term must equal
        /// for a base of mains and pair cells
        fn purified(r: *const R, x: *const Draft, i: usize, j: usize, platform: u8, bgs: []const Draft) [2]f64 {
            var out: [2]f64 = @splat(0);
            const own = r.rawCell(i, x[i], j, x[j], platform);
            for (bgs, 0..) |*z, k| {
                out[k & 1] += own - r.rawCell(i, x[i], j, z[j], platform) - r.rawCell(i, z[i], j, x[j], platform) + r.rawCell(i, z[i], j, z[j], platform);
            }
            for (&out) |*o| o.* *= 2 / @as(f64, @floatFromInt(bgs.len));
            return out;
        }
    };
}

/// A model as weights on the reader's components
const Model = struct {
    name: []const u8,
    w: []const f64,
    /// Added to the empty set's term, by platform
    icpt: []const f64 = &.{},
    /// A model of the game: its logits are kept per draft
    scored: bool = false,
};

/// B without its mix, B, T per seed, T (their logit mean), then T - B per seed and mean
fn buildModels(arena: std.mem.Allocator, seeds: []const u32, nets: []const SetEval) ![]Model {
    const n = nets.len;
    const nc = 2 + n;
    var out: std.ArrayList(Model) = .empty;
    const w0 = try arena.alloc(f64, nc);
    @memset(w0, 0);
    w0[0] = 1;
    try out.append(arena, .{ .name = "B-nomix", .w = w0 });
    const w1 = try arena.dupe(f64, w0);
    w1[1] = 1;
    try out.append(arena, .{ .name = "B", .w = w1, .scored = true });
    if (n == 0) return out.items;
    const np = nets[0].c.len;
    for ([_]bool{ false, true }) |minus_b| {
        const mean_w = try arena.alloc(f64, nc);
        @memset(mean_w, 0);
        const mean_c = try arena.alloc(f64, np);
        @memset(mean_c, 0);
        for (nets, seeds, 0..) |*e, seed, k| {
            const w = try arena.alloc(f64, nc);
            @memset(w, 0);
            const base = if (minus_b) e.a - 1 else e.a;
            w[0] = base;
            w[1] = base;
            w[2 + k] = 1;
            try out.append(arena, .{
                .name = try arena.print("{s}-s{d}", .{ if (minus_b) "T-B" else "T", seed }),
                .w = w,
                .icpt = e.c,
                .scored = !minus_b,
            });
            for (mean_w, w) |*m, x| m.* += x / @as(f64, @floatFromInt(n));
            for (mean_c, e.c) |*m, x| m.* += x / @as(f64, @floatFromInt(n));
        }
        try out.append(arena, .{ .name = if (minus_b) "T-B" else "T", .w = mean_w, .icpt = mean_c, .scored = !minus_b });
    }
    return out.items;
}

const Corr = struct {
    n: f64 = 0,
    sx: f64 = 0,
    sy: f64 = 0,
    sxx: f64 = 0,
    syy: f64 = 0,
    sxy: f64 = 0,
    worst: f64 = 0,

    fn add(c: *Corr, x: f64, y: f64) void {
        c.n += 1;
        c.sx += x;
        c.sy += y;
        c.sxx += x * x;
        c.syy += y * y;
        c.sxy += x * y;
        c.worst = @max(c.worst, @abs(x - y));
    }

    fn merge(c: *Corr, o: Corr) void {
        inline for (.{ "n", "sx", "sy", "sxx", "syy", "sxy" }) |f| @field(c, f) += @field(o, f);
        c.worst = @max(c.worst, o.worst);
    }

    fn varX(c: Corr) f64 {
        return @max(c.sxx / c.n - (c.sx / c.n) * (c.sx / c.n), 0);
    }

    fn varY(c: Corr) f64 {
        return @max(c.syy / c.n - (c.sy / c.n) * (c.sy / c.n), 0);
    }

    fn r(c: Corr) f64 {
        const cov = c.sxy / c.n - (c.sx / c.n) * (c.sy / c.n);
        return cov / @sqrt(c.varX() * c.varY());
    }
};

/// Logits kept per draft and scored model: terms up to order 0, 1, 2, 3, then all
const n_cut = 5;

/// What a block of drafts adds up to; blocks merge in index order
const Acc = struct {
    drafts: usize = 0,
    /// [model][order]: the halves' product summed over the order's coalitions
    power: [][n_order]f64,
    /// [model][order 1, order 2, orders 3+] squared, for the interval over drafts
    power_sq: [][3]f64,
    /// [model][coalition]
    coal: [][n_coal]f64,
    /// [model] a pair's term with the other seats absent (x) against present (y)
    present: []Corr,
    /// The base's pair terms (x) against its purified cells (y)
    cells: Corr = .{},
    /// max over drafts and components of |sum of its terms - the component on the draft|
    worst_sum: f64 = 0,

    fn init(a: std.mem.Allocator, n_models: usize) !Acc {
        const acc: Acc = .{
            .power = try a.alloc([n_order]f64, n_models),
            .power_sq = try a.alloc([3]f64, n_models),
            .coal = try a.alloc([n_coal]f64, n_models),
            .present = try a.alloc(Corr, n_models),
        };
        @memset(acc.power, @splat(0));
        @memset(acc.power_sq, @splat(0));
        @memset(acc.coal, @splat(0));
        @memset(acc.present, .{});
        return acc;
    }

    fn merge(a: *Acc, o: *const Acc) void {
        a.drafts += o.drafts;
        for (a.power, o.power) |*x, y| for (x, y) |*p, q| {
            p.* += q;
        };
        for (a.power_sq, o.power_sq) |*x, y| for (x, y) |*p, q| {
            p.* += q;
        };
        for (a.coal, o.coal) |*x, *y| for (x, y) |*p, q| {
            p.* += q;
        };
        for (a.present, o.present) |*x, y| x.merge(y);
        a.cells.merge(o.cells);
        a.worst_sum = @max(a.worst_sum, o.worst_sum);
    }
};

const block_size = 256;

/// The drafts to explain and what comes back
fn Explain(comptime R: type) type {
    return struct {
        reader: *const R,
        models: []const Model,
        drafts: []const Draft,
        platforms: []const u8,
        /// Each draft's background draw key (its game index)
        keys: []const u32,
        /// Power, cells and coalitions count these drafts only
        sample: []const bool,
        pool: []const Draft,
        n_bg: usize,
        seed: u64,
        gpa: std.mem.Allocator,
        /// One per block_size drafts, zeroed (Acc.init)
        accs: []Acc,
        /// [draft][scored model][n_cut]
        logits: [][n_cut]f64,
        n_scored: usize,

        const E = @This();

        fn block(e: *const E, bi: usize) !void {
            const gpa = e.gpa;
            const nc = e.reader.components();
            const v = try gpa.alloc([n_coal]f64, nc);
            defer gpa.free(v);
            const halves = try gpa.alloc([2][n_coal]f64, nc);
            defer gpa.free(halves);
            const bgs = try gpa.alloc(Draft, e.n_bg);
            defer gpa.free(bgs);
            const whole = try gpa.alloc(f64, nc);
            defer gpa.free(whole);
            const t = try gpa.create([2][n_coal]f64);
            defer gpa.destroy(t);
            const mean = try gpa.create([n_coal]f64);
            defer gpa.destroy(mean);
            const acc = &e.accs[bi];
            const lo = bi * block_size;
            for (lo..@min(lo + block_size, e.drafts.len)) |i| {
                const x = &e.drafts[i];
                const plat = e.platforms[i];
                drawBackgrounds(e.seed, e.keys[i], x, e.pool, bgs);
                halfTerms(e.reader, x, plat, bgs, v, halves);
                e.reader.whole(x, plat, whole);
                for (halves, whole) |*h, want| {
                    var sum: f64 = 0;
                    for (h[0], h[1]) |a, b| sum += (a + b) / 2;
                    acc.worst_sum = @max(acc.worst_sum, @abs(sum - want));
                }
                const in_sample = e.sample[i];
                if (in_sample) acc.drafts += 1;
                var scored: usize = 0;
                for (e.models, 0..) |m, mi| {
                    for (t, 0..) |*th, hi| {
                        @memset(th, 0);
                        for (m.w, halves) |w, *h| {
                            if (w != 0) for (th, h[hi]) |*o, a| {
                                o.* += w * a;
                            };
                        }
                        if (m.icpt.len > 0) th[0] += m.icpt[plat];
                    }
                    for (mean, t[0], t[1]) |*o, a, b| o.* = (a + b) / 2;
                    if (m.scored) {
                        const out = &e.logits[i * e.n_scored + scored];
                        scored += 1;
                        var by_order: [n_order]f64 = @splat(0);
                        for (mean, order_of) |x_, o| by_order[o] += x_;
                        var upto: f64 = 0;
                        for (by_order, 0..) |b, o| {
                            upto += b;
                            if (o < n_cut - 1) out[o] = upto;
                        }
                        out[n_cut - 1] = upto;
                    }
                    if (!in_sample) continue;
                    var pw: [n_order]f64 = @splat(0);
                    for (t[0], t[1], order_of, &acc.coal[mi]) |a, b, o, *c| {
                        pw[o] += a * b;
                        c.* += a * b;
                    }
                    var high: f64 = 0;
                    for (pw, &acc.power[mi], 0..) |p, *o, k| {
                        o.* += p;
                        if (k >= 3) high += p;
                    }
                    for (&acc.power_sq[mi], [3]f64{ pw[1], pw[2], high }) |*o, p| o.* += p * p;
                    const absent = mean.*;
                    supersetSums(mean);
                    for (0..n_seat) |a| for (a + 1..n_seat) |b| {
                        const pm = @as(usize, 1) << @intCast(a) | @as(usize, 1) << @intCast(b);
                        acc.present[mi].add(absent[pm], mean[pm]);
                    };
                }
                if (in_sample) for (0..n_seat) |a| for (a + 1..n_seat) |b| {
                    const pm = @as(usize, 1) << @intCast(a) | @as(usize, 1) << @intCast(b);
                    const want = e.reader.purified(x, a, b, plat, bgs);
                    for (0..2) |hi| acc.cells.add(halves[0][hi][pm], want[hi]);
                };
            }
        }

        /// Fills accs and logits; the result doesn't depend on the thread count
        fn run(e: *const E, io: Io) !void {
            try par.forEach(io, e.accs.len, e, block);
        }
    };
}

fn nBlocks(n: usize) usize {
    return (n + block_size - 1) / block_size;
}

/// log(1 + exp(-l)) for a blue win, of l for a red one
fn loss(blue_won: bool, l: f64) f64 {
    const s = if (blue_won) l else -l;
    return if (s > 0) std.math.log1p(@exp(-s)) else -s + std.math.log1p(@exp(s));
}

const Paired = struct { d: f64, h: f64 };

/// Mean and 95% half-width of a - b over games
fn paired(a: []const f64, b: []const f64) Paired {
    var s: f64 = 0;
    var ss: f64 = 0;
    for (a, b) |x, y| {
        s += x - y;
        ss += (x - y) * (x - y);
    }
    const n: f64 = @floatFromInt(@max(a.len, 1));
    const mean = s / n;
    return .{ .d = mean, .h = 1.96 * @sqrt(@max(ss / n - mean * mean, 0) / n) };
}

const role_names = [5][]const u8{ "top", "jng", "mid", "bot", "sup" };

fn seatsLabel(arena: std.mem.Allocator, mask: usize) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    for (0..n_seat) |s| {
        if (mask >> @intCast(s) & 1 == 0) continue;
        if (out.items.len > 0) try out.append(arena, '+');
        try out.appendSlice(arena, if (s < 5) "b." else "r.");
        try out.appendSlice(arena, role_names[s % 5]);
    }
    return out.items;
}

/// A seat pair's role-pair block: 0..9 ally (r < q, either team), 10..24 enemy (r <= q)
fn pairBlock(a: usize, b: usize) usize {
    const r = @min(a % 5, b % 5);
    const q = @max(a % 5, b % 5);
    if (a / 5 == b / 5) {
        var k: usize = 0;
        for (0..5) |x| for (x + 1..5) |y| {
            if (x == r and y == q) return k;
            k += 1;
        };
        unreachable;
    }
    return 10 + r * 5 - r * (r -| 1) / 2 + (q - r);
}

fn blockLabel(arena: std.mem.Allocator, k: usize) ![]const u8 {
    for (0..n_seat) |a| for (a + 1..n_seat) |b| {
        if (pairBlock(a, b) != k) continue;
        const r = @min(a % 5, b % 5);
        const q = @max(a % 5, b % 5);
        if (k < 10) return arena.print("ally {s}+{s}", .{ role_names[r], role_names[q] });
        if (r == q) return arena.print("lane {s}", .{role_names[r]});
        return arena.print("{s} v {s}", .{ role_names[r], role_names[q] });
    };
    unreachable;
}

const Options = struct {
    nets: []const u8 = "",
    explain: u32 = 20_000,
    bg: u32 = 32,
    seed: u32 = 1,
    all: bool = false,
    out: []const u8 = ".",
    seeds: []const u32 = &.{ 1, 2, 3 },
};

const ref_tolerance = 1e-4;
/// The file's offsets are logits of f32 chances
const base_tolerance = 1e-3;

pub fn main(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: Io, argv: []const []const u8) !u8 {
    if (argv.len == 2 and std.mem.eql(u8, argv[0], "plant-check")) return plantCheck(arena, io, argv[1]);
    if (argv.len < 1 or argv.len % 2 != 1) {
        std.debug.print("usage:\n{s}", .{usage});
        return 2;
    }
    var opts: Options = .{};
    var i: usize = 1;
    while (i < argv.len) : (i += 2) {
        const k = argv[i];
        const val = argv[i + 1];
        if (std.mem.eql(u8, k, "--seeds")) {
            opts.seeds = try winnet.parseSeeds(arena, val);
        } else if (!try winnet.setFlag(&opts, k, val, &.{})) {
            std.debug.print("mobius: unknown option {s}\nusage:\n{s}", .{ k, usage });
            return 2;
        }
    }
    if (opts.nets.len == 0 or opts.bg == 0 or opts.bg % 2 != 0 or opts.explain == 0) {
        std.debug.print("mobius: --nets DIR, an even --bg and --explain N are needed\nusage:\n{s}", .{usage});
        return 2;
    }
    if (!has_logit or (@hasDecl(cand, "seeded") and cand.seeded)) {
        std.debug.print("mobius: the candidate must offer blueLogit and be unseeded: build with -Dcand=src/lab/cand/win-additive\n", .{});
        return 2;
    }
    const t0 = Io.Clock.awake.now(io);
    const snap = argv[0];
    var data = try rows.loadSnap(gpa, io, snap);
    defer data.deinit();
    const players = try harness.gamePlayers(gpa, &data);
    defer gpa.free(players);
    const c = try harness.cuts(gpa, &data);
    const spec: winnet.Spec = .{ .before = c.dev, .lo = c.dev, .hi = c.test_, .dev = true };

    var pool: std.ArrayList(Draft) = .empty;
    var scored: std.ArrayList(u32) = .empty;
    for (data.games, 0..) |g, gi| {
        const fits = spec.fits(c, g, 1);
        const scores = spec.scores(c, g, 1);
        if ((fits or scores) and g.is_test) return error.TestGame;
        if (fits) try pool.append(arena, draftOf(g.teams));
        if (scores) try scored.append(arena, @intCast(gi));
    }

    // B as netcheck fits it for the block's scored games
    const keep: winnet.FitKeep = .{ .spec = spec, .c = c, .fraction = 1 };
    var vis = try harness.buildTrainWhere(gpa, &data, players, keep);
    defer vis.deinit();
    var model = try harness.fit(cand, gpa, &vis.train, .{ .seed = 1 });
    defer cand.deinit(&model, gpa);
    const base: CandBase = .{ .m = &model };
    const t_base = winnet.secondsSince(io, t0);

    const files = try arena.alloc(draftfile.SetNet, opts.seeds.len);
    const nets = try arena.alloc(SetEval, opts.seeds.len);
    var worst_ref: f64 = 0;
    var worst_base: f64 = 0;
    var worst_eval: f64 = 0;
    for (files, nets, opts.seeds) |*sn, *e, seed| {
        const path = try std.fs.path.join(arena, &.{ opts.nets, try arena.print("setnet-s{d}.json", .{seed}) });
        sn.* = try .parse(arena, try Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 30)));
        e.* = try .init(arena, sn);
        worst_ref = @max(worst_ref, sn.checkRefs());
        const v = try arena.create([n_coal]f64);
        for (sn.f.refs) |r| {
            worst_base = @max(worst_base, @abs(base.logit(r.teams, r.platform) - r.offset));
            const x = draftOf(r.teams);
            e.values(&x, &x, v);
            worst_eval = @max(worst_eval, @abs(v[n_coal - 1] + e.c[r.platform] + e.a * r.offset - r.logit));
        }
    }
    if (!(worst_ref <= ref_tolerance and worst_eval <= ref_tolerance)) return error.NetMismatch;
    // Another snapshot, labels or candidate than the nets were fitted on
    if (!(worst_base <= base_tolerance)) return error.BaseMismatch;

    // The sample: the first N of a seeded shuffle of the scored games
    const order = try arena.alloc(u32, scored.items.len);
    for (order, 0..) |*o, k| o.* = @intCast(k);
    var rng: std.Random.DefaultPrng = .init(0x6d0b ^ @as(u64, opts.seed));
    rng.random().shuffle(u32, order);
    const n_sample = @min(opts.explain, scored.items.len);
    const picked = try arena.alloc(bool, scored.items.len);
    @memset(picked, false);
    for (order[0..n_sample]) |k| picked[k] = true;

    var drafts: std.ArrayList(Draft) = .empty;
    var platforms: std.ArrayList(u8) = .empty;
    var keys: std.ArrayList(u32) = .empty;
    var sample: std.ArrayList(bool) = .empty;
    for (scored.items, picked) |gi, inside| {
        if (!inside and !opts.all) continue;
        const g = data.games[gi];
        try drafts.append(arena, draftOf(g.teams));
        try platforms.append(arena, g.platform);
        try keys.append(arena, gi);
        try sample.append(arena, inside);
    }

    const reader: Reader(CandBase) = .{ .b = base, .nets = nets, .files = files };
    const models = try buildModels(arena, opts.seeds, nets);
    var n_scored: usize = 0;
    for (models) |m| n_scored += @intFromBool(m.scored);
    const accs = try arena.alloc(Acc, nBlocks(drafts.items.len));
    for (accs) |*a| a.* = try .init(arena, models.len);
    const logits = try arena.alloc([n_cut]f64, drafts.items.len * n_scored);
    const ex: Explain(Reader(CandBase)) = .{
        .reader = &reader,
        .models = models,
        .drafts = drafts.items,
        .platforms = platforms.items,
        .keys = keys.items,
        .sample = sample.items,
        .pool = pool.items,
        .n_bg = opts.bg,
        .seed = opts.seed,
        .gpa = gpa,
        .accs = accs,
        .logits = logits,
        .n_scored = n_scored,
    };
    try ex.run(io);
    var total: Acc = try .init(arena, models.len);
    for (accs) |*a| total.merge(a);

    var out_buf: [16 * 1024]u8 = undefined;
    var stdout = Io.File.stdout().writer(io, &out_buf);
    const w = &stdout.interface;
    try w.print("# mobius: {s} and {d} set nets (seeds {any}) on {s}\n\n", .{ if (@hasDecl(cand, "name")) cand.name else "cand", nets.len, opts.seeds, snap });
    try w.print("fit {d} games, dev-val {d}, explained {d} (sample {d}, seed {d}), {d} backgrounds a draft; base fit {d:.0} s, all {d:.0} s\n", .{
        pool.items.len, scored.items.len, drafts.items.len, total.drafts, opts.seed, opts.bg, t_base, winnet.secondsSince(io, t0),
    });
    try w.print("checks: files' refs {e:.1}, reader on refs {e:.1}, base on refs' offsets {e:.1}, terms' sum against the model {e:.1} (logit)\n", .{ worst_ref, worst_eval, worst_base, total.worst_sum });
    try w.print("RESULT check sum_terms_max_abs_logit {e:.3}\n", .{total.worst_sum});

    const ys = try arena.alloc(bool, drafts.items.len);
    for (ys, keys.items) |*y, gi| y.* = data.games[gi].winner == 0;
    try report(arena, io, w, opts, models, &total, logits, n_scored, ys, sample.items, keys.items, &data);
    try w.flush();
    return 0;
}

fn report(
    arena: std.mem.Allocator,
    io: Io,
    w: *Io.Writer,
    opts: Options,
    models: []const Model,
    total: *const Acc,
    logits: []const [n_cut]f64,
    n_scored: usize,
    ys: []const bool,
    sample: []const bool,
    keys: []const u32,
    data: *const rows.Data,
) !void {
    const n: f64 = @floatFromInt(@max(total.drafts, 1));
    try Io.Dir.cwd().createDirPath(io, opts.out);
    var dir = try Io.Dir.cwd().openDir(io, opts.out, .{});
    defer dir.close(io);
    var fbuf: [64 * 1024]u8 = undefined;

    const high0 = highPower(&total.power[0]) / n * pp2;
    try w.print("\n## Tool gate\n\nB without the mix: order 3+ power {e:.2} pp^2. Its pair terms against its purified cells: r {d:.8}, max |diff| {e:.2} pp, {d:.0} terms\n", .{
        high0, total.cells.r(), total.cells.worst * pp, total.cells.n,
    });
    try w.print("RESULT gate nomix_order3plus_pp2 {e:.3}\nRESULT gate cells_r {d:.8} cells_max_abs_pp {e:.3}\n", .{ high0, total.cells.r(), total.cells.worst * pp });

    try w.print("\n## Power by order, pp^2 (mean over {d} sampled drafts; ± 95% over drafts)\n\n", .{total.drafts});
    try w.writeAll("| model | 1 | 2 | 3 | 4 | 5 | 6-10 | 3+ | 3+ share of 1+ |\n| --- | --- | --- | --- | --- | --- | --- | --- | --- |\n");
    var orders_file = try dir.createFile(io, "orders.tsv", .{});
    defer orders_file.close(io);
    var ow = orders_file.writer(io, &fbuf);
    try ow.interface.writeAll("model\torder\tpower_pp2\thalf_width_pp2\tshare\n");
    for (models, total.power, total.power_sq) |m, pw, sq| {
        var all: f64 = 0;
        for (pw[1..]) |p| all += p;
        var late: f64 = 0;
        for (pw[6..]) |p| late += p;
        const high = highPower(&pw);
        const hw = struct {
            fn of(sum: f64, sumsq: f64, count: f64) f64 {
                const mean = sum / count;
                return 1.96 * @sqrt(@max(sumsq / count - mean * mean, 0) / count) * pp2;
            }
        }.of;
        try w.print("| {s} | {d:.4} ± {d:.4} | {d:.4} ± {d:.4} | {d:.5} | {d:.5} | {d:.5} | {d:.5} | {d:.5} ± {d:.5} | {d:.2}% |\n", .{
            m.name,         pw[1] / n * pp2, hw(pw[1], sq[0], n), pw[2] / n * pp2,  hw(pw[2], sq[1], n), pw[3] / n * pp2, pw[4] / n * pp2, pw[5] / n * pp2,
            late / n * pp2, high / n * pp2,  hw(high, sq[2], n),  100 * high / all,
        });
        try w.print("RESULT power {s} o1 {d:.5} o2 {d:.5} o3plus {d:.6} hw3plus {d:.6} share3plus {d:.5}\n", .{ m.name, pw[1] / n * pp2, pw[2] / n * pp2, high / n * pp2, hw(high, sq[2], n), high / all });
        for (pw[1..], 1..) |p, k| try ow.interface.print("{s}\t{d}\t{d:.7}\t\t{d:.6}\n", .{ m.name, k, p / n * pp2, p / all });
        try ow.interface.print("{s}\t3+\t{d:.7}\t{d:.7}\t{d:.6}\n", .{ m.name, high / n * pp2, hw(high, sq[2], n), high / all });
    }
    try ow.interface.flush();

    // B, T and T - B (the seeds' mean), by name
    var shown: [3]usize = .{ 1, 1, 1 };
    for (models, 0..) |m, mi| {
        if (std.mem.eql(u8, m.name, "T")) shown[1] = mi;
        if (std.mem.eql(u8, m.name, "T-B")) shown[2] = mi;
    }
    try w.writeAll("\n## Pair power by block, pp^2 (both teams' seat pairs summed)\n\n| block | B | T | T - B |\n| --- | --- | --- | --- |\n");
    for (0..25) |k| {
        var sum: [3]f64 = @splat(0);
        for (0..n_seat) |a| for (a + 1..n_seat) |b| {
            if (pairBlock(a, b) != k) continue;
            const pm = @as(usize, 1) << @intCast(a) | @as(usize, 1) << @intCast(b);
            for (&sum, shown) |*s, mi| s.* += total.coal[mi][pm] / n * pp2;
        };
        try w.print("| {s} | {d:.4} | {d:.4} | {d:.4} |\n", .{ try blockLabel(arena, k), sum[0], sum[1], sum[2] });
    }

    var cf = try dir.createFile(io, "coalitions.tsv", .{});
    defer cf.close(io);
    var cw = cf.writer(io, &fbuf);
    try cw.interface.writeAll("mask\torder\tseats");
    for (models) |m| try cw.interface.print("\t{s}", .{m.name});
    try cw.interface.writeAll("\n");
    for (1..n_coal) |mask| {
        try cw.interface.print("{d}\t{d}\t{s}", .{ mask, order_of[mask], try seatsLabel(arena, mask) });
        for (total.coal) |co| try cw.interface.print("\t{d:.7}", .{co[mask] / n * pp2});
        try cw.interface.writeAll("\n");
    }
    try cw.interface.flush();

    const top = try arena.alloc(usize, n_coal);
    for (top, 0..) |*t, k| t.* = k;
    const By = struct {
        co: *const [n_coal]f64,
        fn before(x: @This(), a: usize, b: usize) bool {
            const ha = order_of[a] >= 3;
            const hb = order_of[b] >= 3;
            if (ha != hb) return ha;
            return x.co[a] > x.co[b];
        }
    };
    std.mem.sort(usize, top, By{ .co = &total.coal[shown[1]] }, By.before);
    try w.writeAll("\n## Seat sets of order 3+ by T's power, pp^2 (top 20 of 968)\n\n| seats | B | T | T - B |\n| --- | --- | --- | --- |\n");
    for (top[0..20]) |mask| try w.print("| {s} | {d:.5} | {d:.5} | {d:.5} |\n", .{
        try seatsLabel(arena, mask), total.coal[shown[0]][mask] / n * pp2, total.coal[shown[1]][mask] / n * pp2, total.coal[shown[2]][mask] / n * pp2,
    });
    // Within one team, or across both
    var within: [3]f64 = @splat(0);
    var across: [3]f64 = @splat(0);
    for (1..n_coal) |mask| {
        if (order_of[mask] < 3) continue;
        const one_team = mask & 0x1f == 0 or mask >> 5 == 0;
        for (&within, &across, shown) |*a, *b, mi| (if (one_team) a else b).* += total.coal[mi][mask] / n * pp2;
    }
    try w.print("\norder 3+ power within one team / across both: B {d:.5} / {d:.5}, T {d:.5} / {d:.5}, T - B {d:.5} / {d:.5}\n", .{ within[0], across[0], within[1], across[1], within[2], across[2] });

    try w.writeAll("\n## A pair's term with the other eight seats absent against present\n\n| model | sd absent pp | sd present pp | r |\n| --- | --- | --- | --- |\n");
    for (models, total.present) |m, pr| try w.print("| {s} | {d:.4} | {d:.4} | {d:.4} |\n", .{ m.name, @sqrt(pr.varX()) * pp, @sqrt(pr.varY()) * pp, pr.r() });

    // Each scored model against its own terms up to an order, and against B
    const nd = ys.len;
    const la = try arena.alloc(f64, nd);
    const lb = try arena.alloc(f64, nd);
    try w.print("\n## Truncation: log loss on {d} drafts, the model minus its own terms up to an order (nats a game, ± 95%)\n\n", .{nd});
    try w.writeAll("| model | log loss | minus order <= 1 | minus order <= 2 | minus order <= 3 | minus B | order <= 2 minus B |\n| --- | --- | --- | --- | --- | --- | --- |\n");
    var si: usize = 0;
    for (models) |m| {
        if (!m.scored) continue;
        defer si += 1;
        var mean: f64 = 0;
        for (la, ys, 0..) |*o, y, d| {
            o.* = loss(y, logits[d * n_scored + si][n_cut - 1]);
            mean += o.*;
        }
        mean /= @floatFromInt(@max(nd, 1));
        try w.print("| {s} | {d:.5} |", .{ m.name, mean });
        var cut: [3]Paired = undefined;
        for (&cut, 1..) |*p, k| {
            for (lb, ys, 0..) |*o, y, d| o.* = loss(y, logits[d * n_scored + si][k]);
            p.* = paired(la, lb);
            try w.print(" {d:.6} ± {d:.6} |", .{ p.d, p.h });
        }
        // B is the first scored model
        for (lb, ys, 0..) |*o, y, d| o.* = loss(y, logits[d * n_scored][n_cut - 1]);
        const vs_b = paired(la, lb);
        for (la, ys, 0..) |*o, y, d| o.* = loss(y, logits[d * n_scored + si][2]);
        const cut_b = paired(la, lb);
        try w.print(" {d:.6} ± {d:.6} | {d:.6} ± {d:.6} |\n", .{ vs_b.d, vs_b.h, cut_b.d, cut_b.h });
        try w.print("RESULT trunc {s} loss {d:.6} d2 {d:.7} h2 {d:.7} bound2 {d:.7} d1 {d:.7} h1 {d:.7} d3 {d:.7} h3 {d:.7} vs_b {d:.7} h_b {d:.7}\n", .{
            m.name, mean, cut[1].d, cut[1].h, cut[1].d + 2.1 * cut[1].h, cut[0].d, cut[0].h, cut[2].d, cut[2].h, vs_b.d, vs_b.h,
        });
    }

    var tf = try dir.createFile(io, "trunc.tsv", .{});
    defer tf.close(io);
    var tw = tf.writer(io, &fbuf);
    try tw.interface.writeAll("match_id\tblue_won\tsample");
    var keep: std.ArrayList(usize) = .empty;
    si = 0;
    for (models) |m| {
        if (!m.scored) continue;
        defer si += 1;
        if (!std.mem.eql(u8, m.name, "B") and !std.mem.eql(u8, m.name, "T")) continue;
        try keep.append(arena, si);
        try tw.interface.print("\t{s}_le0\t{s}_le1\t{s}_le2\t{s}_le3\t{s}", .{ m.name, m.name, m.name, m.name, m.name });
    }
    try tw.interface.writeAll("\n");
    for (keys, ys, sample, 0..) |gi, y, inside, d| {
        try tw.interface.print("{s}\t{d}\t{d}", .{ data.games[gi].match_id, @intFromBool(y), @intFromBool(inside) });
        for (keep.items) |k| for (logits[d * n_scored + k]) |l| try tw.interface.print("\t{d:.6}", .{l});
        try tw.interface.writeAll("\n");
    }
    try tw.interface.flush();
}

fn highPower(pw: *const [n_order]f64) f64 {
    var s: f64 = 0;
    for (pw[3..]) |p| s += p;
    return s;
}

/// py/xcheck/mobius_plant.py's Truth with its drafts, backgrounds and terms (write_dump's
/// MOBP file). Champions are dense indices, a draft blue by role then red
pub const Planted = struct {
    c: usize,
    n: usize,
    n_bg: usize,
    triple_roles: [3]u32,
    triple: f64,
    main: []const f64,
    ally: []const f64,
    enemy: []const f64,
    z: []const f64,
    ex: []const u32,
    bg: []const u32,
    /// [half][draft][coalition]
    terms: []const f64,

    pub fn parse(arena: std.mem.Allocator, bytes: []const u8) !Planted {
        if (bytes.len < 40 or !std.mem.eql(u8, bytes[0..4], "MOBP")) return error.NotPlantDump;
        var head: [7]u32 = undefined;
        @memcpy(std.mem.sliceAsBytes(&head), bytes[4..32]);
        if (head[0] != 1) return error.NotPlantDump;
        var p: Planted = .{ .c = head[1], .n = head[2], .n_bg = head[3], .triple_roles = head[4..7].*, .triple = undefined, .main = &.{}, .ally = &.{}, .enemy = &.{}, .z = &.{}, .ex = &.{}, .bg = &.{}, .terms = &.{} };
        var at: usize = 32;
        p.triple = (try take(f64, arena, bytes, &at, 1))[0];
        p.main = try take(f64, arena, bytes, &at, 5 * p.c);
        p.ally = try take(f64, arena, bytes, &at, 25 * p.c * p.c);
        p.enemy = try take(f64, arena, bytes, &at, 25 * p.c * p.c);
        p.z = try take(f64, arena, bytes, &at, 5 * p.c);
        p.ex = try take(u32, arena, bytes, &at, p.n * n_seat);
        p.bg = try take(u32, arena, bytes, &at, p.n_bg * p.n * n_seat);
        p.terms = try take(f64, arena, bytes, &at, 2 * p.n * n_coal);
        if (at != bytes.len) return error.NotPlantDump;
        for (p.ex) |x| if (x >= p.c) return error.NotPlantDump;
        for (p.bg) |x| if (x >= p.c) return error.NotPlantDump;
        return p;
    }

    fn take(comptime T: type, arena: std.mem.Allocator, bytes: []const u8, at: *usize, n: usize) ![]T {
        const size = n * @sizeOf(T);
        if (at.* + size > bytes.len) return error.NotPlantDump;
        const out = try arena.alloc(T, n);
        @memcpy(std.mem.sliceAsBytes(out), bytes[at.*..][0..size]);
        at.* += size;
        return out;
    }

    fn h(p: *const Planted, own: *const [5]u32, en: *const [5]u32) f64 {
        const c = p.c;
        var out: f64 = 0;
        for (own, 0..) |ch, r| out += p.main[r * c + ch];
        for (0..5) |r| for (r..5) |s| {
            const at = (r * 5 + s) * c * c;
            if (s > r) out += p.ally[at + own[r] * c + own[s]];
            out += p.enemy[at + own[r] * c + en[s]];
        };
        if (p.triple != 0) {
            var t = p.triple;
            for (p.triple_roles) |r| t *= p.z[r * c + own[r]];
            out += t;
        }
        return out;
    }

    pub fn logit(p: *const Planted, x: *const Draft) f64 {
        return p.h(x[0..5], x[5..10]) - p.h(x[5..10], x[0..5]);
    }

    pub fn values(p: *const Planted, x: *const Draft, z: *const Draft, _: u8, v: [][n_coal]f64) void {
        for (&v[0], 0..) |*o, mask| o.* = p.logit(&hybrid(x, z, mask));
    }

    /// Draft i's two half-terms recomputed; returns max |diff| to the file's, in logit
    fn check(p: *const Planted, i: usize, bgs: []Draft, v: *[1][n_coal]f64, out: *[1][2][n_coal]f64) f64 {
        const x: *const Draft = p.ex[i * n_seat ..][0..n_seat];
        for (bgs, 0..) |*z, j| z.* = p.bg[(j * p.n + i) * n_seat ..][0..n_seat].*;
        halfTerms(p, x, 0, bgs, v, out);
        var worst: f64 = 0;
        for (0..2) |half| for (out[0][half], p.terms[(half * p.n + i) * n_coal ..][0..n_coal]) |a, b| {
            worst = @max(worst, @abs(a - b));
        };
        return worst;
    }
};

/// C1's tool gate, part 3: Zig and Python agree on a planted truth to 1e-4 pp
const plant_tolerance_pp = 1e-4;

fn plantCheck(arena: std.mem.Allocator, io: Io, path: []const u8) !u8 {
    const p: Planted = try .parse(arena, try Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(4 << 30)));
    const bgs = try arena.alloc(Draft, p.n_bg);
    const v = try arena.create([1][n_coal]f64);
    const out = try arena.create([1][2][n_coal]f64);
    var worst: f64 = 0;
    var power: [n_order]f64 = @splat(0);
    for (0..p.n) |i| {
        worst = @max(worst, p.check(i, bgs, v, out));
        for (out[0][0], out[0][1], order_of) |a, b, o| power[o] += a * b;
    }
    var buf: [4096]u8 = undefined;
    var stdout = Io.File.stdout().writer(io, &buf);
    const w = &stdout.interface;
    try w.print("# mobius plant-check {s}\n\n{d} drafts x {d} backgrounds, {d} champions, triple {d:.3} logit\npower pp^2 by order 1-10:", .{ path, p.n, p.n_bg, p.c, p.triple });
    for (power[1..]) |x| try w.print(" {d:.6}", .{x / @as(f64, @floatFromInt(@max(p.n, 1))) * pp2});
    try w.print("\nmax |Zig - Python| over {d} terms: {e:.3} pp (gate {e:.0})\nRESULT plant_check max_abs_pp {e:.3} ok {d}\n", .{ 2 * p.n * n_coal, worst * pp, plant_tolerance_pp, worst * pp, @intFromBool(worst * pp <= plant_tolerance_pp) });
    try w.flush();
    return if (worst * pp <= plant_tolerance_pp) 0 else 1;
}

const testing = std.testing;

test "transform returns the terms a value function was built from" {
    var prng: std.Random.DefaultPrng = .init(1);
    const r = prng.random();
    var m: [n_coal]f64 = @splat(0);
    for (0..60) |_| m[r.uintLessThan(usize, n_coal)] = r.floatNorm(f64);
    var v: [n_coal]f64 = undefined;
    for (&v, 0..) |*o, s| {
        o.* = 0;
        for (m, 0..) |x, t| {
            if (t & ~s == 0) o.* += x;
        }
    }
    const all = v[n_coal - 1];
    transform(&v);
    var sum: f64 = 0;
    for (v, m) |got, want| {
        try testing.expectApproxEqAbs(want, got, 1e-9);
        sum += got;
    }
    try testing.expectApproxEqAbs(all, sum, 1e-9);
    // At a pair: every term holding both seats
    var sup = m;
    supersetSums(&sup);
    var want: f64 = 0;
    for (m, 0..) |x, t| {
        if (t & 0b101 == 0b101) want += x;
    }
    try testing.expectApproxEqAbs(want, sup[0b101], 1e-9);
}

test "the Python reading's planted truth: same terms from the same drafts and backgrounds" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    // py/xcheck/mobius_plant.py --fixture: 8 champions, a 2 pp triple, float64
    const p: Planted = try .parse(arena, @embedFile("../testdata/lab/mobius-plant.bin"));
    try testing.expect(p.n >= 2 and p.n_bg >= 2 and p.triple != 0);
    const bgs = try arena.alloc(Draft, p.n_bg);
    const v = try arena.create([1][n_coal]f64);
    const out = try arena.create([1][2][n_coal]f64);
    var high: f64 = 0;
    for (0..p.n) |i| {
        try testing.expect(p.check(i, bgs, v, out) < 1e-10);
        for (out[0]) |half| for (half, order_of) |a, o| {
            // A truth of mains, pairs and one team triple a side
            if (o > 3) try testing.expect(@abs(a) < 1e-10);
            if (o == 3) high = @max(high, @abs(a));
        };
    }
    try testing.expect(high > 1e-4);
}

/// A base of hashed mains and pair cells plus a mix that is no sum of pairs
const TestBase = struct {
    fn unit(a: u64, b: u64, c: u64, d: u64) f64 {
        const k = [4]u64{ a, b, c, d };
        return @as(f64, @floatFromInt(std.hash.Wyhash.hash(7, std.mem.asBytes(&k)) >> 11)) / @as(f64, 1 << 53) - 0.5;
    }

    pub fn logit(b: TestBase, teams: [2][5]u32, platform: u8) f64 {
        const d = draftOf(teams);
        var out: f64 = 0.01 * @as(f64, @floatFromInt(platform)) + b.mix(teams);
        for (d, 0..) |x, i| {
            if (x == 0) continue;
            out += unit(i, x, 99, 0);
            for (d[i + 1 ..], i + 1..) |y, j| {
                if (y != 0) out += 0.3 * unit(i, x, j, y);
            }
        }
        return out;
    }

    pub fn mix(_: TestBase, teams: [2][5]u32) f64 {
        var out: [2]f64 = undefined;
        for (teams, &out) |t, *o| {
            var s: f64 = 0;
            for (t) |x| {
                if (x != 0) s += unit(x, 5, 5, 5);
            }
            o.* = s * s * s;
        }
        return out[0] - out[1];
    }
};

fn testDraft(r: std.Random, lo: u32, n: u32) Draft {
    var d: Draft = undefined;
    for (&d, 0..) |*x, i| x.* = while (true) {
        const c = lo + r.uintLessThan(u32, n);
        if (std.mem.findScalar(u32, d[0..i], c) == null) break c;
    };
    return d;
}

fn testNet(arena: std.mem.Allocator, r: std.Random, cross: bool) !draftfile.SetNet {
    const phi = 3;
    const rho = 4;
    const emb = 2;
    const n_prof = 2;
    const in = n_prof + 5 + emb;
    const rin: usize = if (cross) 2 * phi else phi;
    const n_ids = 5 + 8;
    const Id = struct { champion: u32, role: u8, id: u32 };
    const Prof = struct { champion: u32, role: u8, z: [n_prof]f32 };
    var ids: [8]Id = undefined;
    // Champions 1..8 in two roles each have an id; profiles for some of those and others
    for (&ids, 0..) |*x, k| x.* = .{ .champion = @intCast(1 + k), .role = @intCast(k % 5), .id = @intCast(5 + k) };
    var profs: [10]Prof = undefined;
    for (&profs, 0..) |*x, k| x.* = .{ .champion = @intCast(3 + k), .role = @intCast((k + 2) % 5), .z = .{ r.floatNorm(f32), r.floatNorm(f32) } };
    const c = 0;
    const a = c + 2;
    const b1 = a + 1;
    const cb = b1 + phi;
    const e = cb + rho;
    const w1 = e + n_ids * emb;
    const v = w1 + phi * in;
    const out = v + rho * rin;
    const len = out + rho;
    const params = try arena.alloc(f32, len);
    for (params) |*x| x.* = r.floatNorm(f32) * 0.5;
    const file = .{
        .format = "meiolol-setnet",
        .version = 1,
        .phi = phi,
        .rho = rho,
        .emb = emb,
        .cross = cross,
        .n_prof = n_prof,
        .layout = .{ .in = in, .rin = rin, .c = c, .a = a, .b1 = b1, .cb = cb, .e = e, .w1 = w1, .v = v, .out = out, .len = len },
        .params = params,
        .ids = ids,
        .profiles = profs,
        .refs = [0]struct { teams: [2][5]u32, platform: u8, offset: f32, logit: f32 }{},
    };
    return .parse(arena, try std.json.Stringify.valueAlloc(arena, file, .{}));
}

test "set net reader: every coalition equals the file's own forward pass" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var prng: std.Random.DefaultPrng = .init(5);
    const r = prng.random();
    for ([_]bool{ true, false }) |cross| {
        const sn = try testNet(arena, r, cross);
        var e: SetEval = try .init(testing.allocator, &sn);
        defer e.deinit(testing.allocator);
        const v = try arena.create([n_coal]f64);
        for (0..5) |_| {
            // 1..14: champions with an id, a profile, both or neither
            const x = testDraft(r, 1, 14);
            const z = testDraft(r, 1, 14);
            e.values(&x, &z, v);
            for (v, 0..) |got, mask| {
                const want = sn.logit(teamsOf(&hybrid(&x, &z, mask)), 1, 0) - e.c[1];
                try testing.expectApproxEqAbs(want, got, 1e-9);
            }
        }
    }
}

test "backgrounds share no champion with the draft and depend on the key alone" {
    var prng: std.Random.DefaultPrng = .init(2);
    const r = prng.random();
    var pool: [200]Draft = undefined;
    for (&pool) |*p| p.* = testDraft(r, 1, 40);
    const x = testDraft(r, 1, 40);
    var a: [8]Draft = undefined;
    var b: [8]Draft = undefined;
    drawBackgrounds(1, 7, &x, &pool, &a);
    drawBackgrounds(1, 7, &x, &pool, &b);
    for (a, b) |p, q| {
        try testing.expect(!shares(&x, &p));
        try testing.expectEqual(p, q);
    }
    drawBackgrounds(1, 8, &x, &pool, &b);
    try testing.expect(!std.meta.eql(a, b));
}

test "explain: a base of mains and pairs has no order 3+, its pair terms are its purified cells, terms add up" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var prng: std.Random.DefaultPrng = .init(9);
    const r = prng.random();
    const files = try arena.alloc(draftfile.SetNet, 2);
    const nets = try arena.alloc(SetEval, 2);
    for (files, nets) |*f, *e| {
        f.* = try testNet(arena, r, true);
        e.* = try .init(arena, f);
    }
    const reader: Reader(TestBase) = .{ .b = .{}, .nets = nets, .files = files };
    const models = try buildModels(arena, &.{ 1, 2 }, nets);
    try testing.expectEqualStrings("T", models[4].name);
    try testing.expectEqualStrings("T-B", models[7].name);
    const pool = try arena.alloc(Draft, 300);
    for (pool) |*p| p.* = testDraft(r, 1, 60);
    const n = 300;
    const drafts = try arena.alloc(Draft, n);
    const platforms = try arena.alloc(u8, n);
    const keys = try arena.alloc(u32, n);
    const sample = try arena.alloc(bool, n);
    for (drafts, platforms, keys, sample, 0..) |*d, *p, *k, *s, i| {
        d.* = testDraft(r, 1, 60);
        p.* = @intCast(i % 2);
        k.* = @intCast(i);
        s.* = i % 3 != 0;
    }
    const n_scored = 4;
    var totals: [2]Acc = undefined;
    var all_logits: [2][][n_cut]f64 = undefined;
    for (&totals, &all_logits) |*total, *logits| {
        const accs = try arena.alloc(Acc, nBlocks(n));
        for (accs) |*a| a.* = try .init(arena, models.len);
        logits.* = try arena.alloc([n_cut]f64, n * n_scored);
        const ex: Explain(Reader(TestBase)) = .{ .reader = &reader, .models = models, .drafts = drafts, .platforms = platforms, .keys = keys, .sample = sample, .pool = pool, .n_bg = 4, .seed = 3, .gpa = testing.allocator, .accs = accs, .logits = logits.*, .n_scored = n_scored };
        try ex.run(testing.io);
        total.* = try .init(arena, models.len);
        for (accs) |*a| total.merge(a);
    }
    const total = &totals[0];
    // The same whatever the threads did
    try testing.expectEqualSlices([n_order]f64, total.power, totals[1].power);
    try testing.expectEqualSlices([n_cut]f64, all_logits[0], all_logits[1]);
    try testing.expectEqual(200, total.drafts);
    try testing.expect(total.worst_sum < 1e-9);
    // B without its mix: orders 1 and 2 only, pair terms = cells centred on the backgrounds
    try testing.expect(@abs(highPower(&total.power[0])) < 1e-18);
    try testing.expect(total.power[0][1] > 0.1 and total.power[0][2] > 0.01);
    try testing.expectEqual(200 * 45 * 2, total.cells.n);
    try testing.expect(total.cells.worst < 1e-10);
    // The mix is a cube of a team sum: orders up to 3 within a team, and present pairs differ
    try testing.expect(highPower(&total.power[1]) > 1e-6);
    try testing.expect(@abs(total.power[1][4]) < 1e-18);
    try testing.expect(total.present[0].worst < 1e-10);
    try testing.expect(total.present[1].worst > 1e-4);
    // Logits: every term = the model on the draft; T = the seeds' mean
    const whole = try arena.alloc(f64, reader.components());
    for (drafts, platforms, 0..) |*d, plat, i| {
        const l = all_logits[0][i * n_scored ..][0..n_scored];
        const b = TestBase.logit(.{}, teamsOf(d), plat);
        try testing.expectApproxEqAbs(b, l[0][n_cut - 1], 1e-9);
        reader.whole(d, plat, whole);
        var mean: f64 = 0;
        for (files, l[1..3], whole[2..]) |*f, got, own| {
            const want = f.logit(teamsOf(d), plat, b);
            try testing.expectApproxEqAbs(want, got[n_cut - 1], 1e-9);
            try testing.expectApproxEqAbs(want, own + f.f.params[f.f.layout.c + plat] + f.f.params[f.f.layout.a] * b, 1e-9);
            mean += want / 2;
        }
        try testing.expectApproxEqAbs(mean, l[3][n_cut - 1], 1e-9);
    }
}

test "pair blocks: 10 ally and 15 enemy, both teams' seat pairs together" {
    var count: [25]u32 = @splat(0);
    for (0..n_seat) |a| for (a + 1..n_seat) |b| {
        count[pairBlock(a, b)] += 1;
    };
    // An ally block: one seat pair a team; a lane: one; other enemy blocks: two
    for (count[0..10]) |c| try testing.expectEqual(2, c);
    try testing.expectEqual(1, count[pairBlock(0, 5)]);
    try testing.expectEqual(2, count[pairBlock(0, 6)]);
    try testing.expectEqual(pairBlock(0, 6), pairBlock(1, 5));
    try testing.expectEqual(pairBlock(3, 4), pairBlock(8, 9));
    try testing.expectEqual(1, count[24]);
}

test "loss and paired" {
    try testing.expectApproxEqAbs(@log(2.0), loss(true, 0), 1e-12);
    try testing.expectApproxEqAbs(loss(true, 1.5), loss(false, -1.5), 1e-12);
    try testing.expectApproxEqAbs(-@log(1.0 / (1.0 + @exp(-0.7))), loss(true, 0.7), 1e-12);
    const p = paired(&.{ 1, 2, 3, 4 }, &.{ 0, 2, 2, 4 });
    try testing.expectApproxEqAbs(0.5, p.d, 1e-12);
    try testing.expectApproxEqAbs(1.96 * 0.25, p.h, 1e-12);
}
