//! `meiolol-lab health`: training-health checks per model family on synthetic games
//! (docs/model.md "Model tests"), run on a code change or on demand, never per training
//! run (deploy/lab-run.sh's run-time gates are those). Per family: the loss at init is the
//! base rate's, the net is antisymmetric (swapping sides gives the other side's chance),
//! training loss falls, it can overfit a tiny set, the same seed gives identical
//! parameters, another seed others, no NaN. A table of checks; exit 1 when one fails.
//! Families: the big net (draftnet), small and resid (winnet.healthFit), set
//! (setnet.healthFit), player history (playernet.healthFit)
//! `zig build test` runs the quick subset

const std = @import("std");
const draftnet = @import("draftnet.zig");
const winnet = @import("winnet.zig");
const setnet = @import("setnet.zig");
const playernet = @import("playernet.zig");
const dn = @import("../gpu/draftnet_layout.zig");

const Io = std.Io;

pub const usage =
    \\  health [--threads N]            training-health checks on synthetic games:
    \\                                  loss at init, antisymmetry, loss falls, overfits
    \\                                  a tiny set, seeds (lab/health.zig)
    \\
;

const Check = struct {
    family: []const u8,
    name: []const u8,
    value: f64,
    limit: f64,
    /// pass when value < limit, else value > limit
    below: bool = true,

    fn ok(c: Check) bool {
        return if (c.below) c.value < c.limit else c.value > c.limit;
    }
};

const Report = struct {
    checks: std.ArrayList(Check) = .empty,

    fn add(r: *Report, gpa: std.mem.Allocator, c: Check) !void {
        try r.checks.append(gpa, c);
    }

    fn failed(r: *const Report) usize {
        var n: usize = 0;
        for (r.checks.items) |c| n += @intFromBool(!c.ok());
        return n;
    }

    fn write(r: *const Report, w: *Io.Writer) !void {
        try w.writeAll("| family | check | value | limit | |\n| --- | --- | --- | --- | --- |\n");
        for (r.checks.items) |c| try w.print("| {s} | {s} | {d:.6} | {s} {d:.6} | {s} |\n", .{
            c.family, c.name, c.value, if (c.below) "<" else ">", c.limit, if (c.ok()) "ok" else "FAIL",
        });
    }
};

/// Synthetic draft games for the big net: n_ids champion-role ids (5.. are champions),
/// ten distinct per game; blue's logit = sum of strengths (sd `sd`) blue minus red, so
/// sd 0 gives coin-flip labels
fn bigGames(gpa: std.mem.Allocator, n: usize, n_ids: u32, sd: f32, seed: u64) ![]dn.Game {
    var prng: std.Random.DefaultPrng = .init(seed);
    const r = prng.random();
    const strength = try gpa.alloc(f32, n_ids);
    defer gpa.free(strength);
    for (strength) |*s| s.* = sd * r.floatNorm(f32);
    const games = try gpa.alloc(dn.Game, n);
    for (games) |*g| {
        var z: f32 = 0;
        for (0..10) |slot| {
            g.ids[slot] = while (true) {
                const id = 5 + r.uintLessThan(u32, n_ids - 5);
                if (std.mem.indexOfScalar(u32, g.ids[0..slot], id) == null) break id;
            };
            z += if (slot < 5) strength[g.ids[slot]] else -strength[g.ids[slot]];
        }
        g.platform = 0;
        g.off = 0;
        g.y = if (r.float(f32) < 1 / (1 + @exp(-z))) 1 else 0;
    }
    return games;
}

fn swapped(gpa: std.mem.Allocator, games: []const dn.Game) ![]dn.Game {
    const out = try gpa.dupe(dn.Game, games);
    for (out) |*g| {
        const blue = g.ids[0..5].*;
        g.ids[0..5].* = g.ids[5..10].*;
        g.ids[5..10].* = blue;
        g.y = 1 - g.y;
    }
    return out;
}

/// Log loss of always predicting the labels' mean
fn baseLoss(games: []const dn.Game) f64 {
    var m: f64 = 0;
    for (games) |g| m += g.y;
    m /= @floatFromInt(games.len);
    if (m <= 0 or m >= 1) return 0;
    return -(m * @log(m) + (1 - m) * @log(1 - m));
}

fn allFinite(p: []const f32) bool {
    for (p) |x| if (!std.math.isFinite(x)) return false;
    return true;
}

fn logit(p: f32) f64 {
    const q: f64 = std.math.clamp(p, 1e-7, 1 - 1e-7);
    return @log(q / (1 - q));
}

/// Largest spread of logit(p) + logit(p swapped) over games of one platform: 0 for an
/// antisymmetric net (the sum is twice the platform's intercept)
fn asymmetry(gpa: std.mem.Allocator, io: Io, n: *const draftnet.Net, games: []const dn.Game) !f64 {
    const sw = try swapped(gpa, games);
    defer gpa.free(sw);
    const a = try gpa.alloc(f32, games.len);
    defer gpa.free(a);
    const b = try gpa.alloc(f32, games.len);
    defer gpa.free(b);
    try n.predict(gpa, io, games, a);
    try n.predict(gpa, io, sw, b);
    var lo: f64 = std.math.inf(f64);
    var hi: f64 = -std.math.inf(f64);
    for (a, b) |x, y| {
        const s = logit(x) + logit(y);
        lo = @min(lo, s);
        hi = @max(hi, s);
    }
    return hi - lo;
}

const Sizes = struct {
    learn_games: usize,
    learn_epochs: u64,
    tiny_games: usize,
    tiny_steps: u64,
    seed_steps: u64,
};

const full: Sizes = .{ .learn_games = 20_000, .learn_epochs = 4, .tiny_games = 64, .tiny_steps = 1500, .seed_steps = 40 };
const quick: Sizes = .{ .learn_games = 0, .learn_epochs = 0, .tiny_games = 32, .tiny_steps = 0, .seed_steps = 3 };

fn checkBig(gpa: std.mem.Allocator, io: Io, r: *Report, threads: usize, s: Sizes) !void {
    const fam = "big (draftnet)";
    const n_ids: u32 = 205;
    const cfg: draftnet.Config = .{};

    {
        const games = try bigGames(gpa, 4000, n_ids, 0, 11);
        defer gpa.free(games);
        var n = try draftnet.Net.init(gpa, n_ids, 1, false);
        defer n.deinit(gpa);
        const pred = try gpa.alloc(f32, games.len);
        defer gpa.free(pred);
        try n.predict(gpa, io, games, pred);
        try r.add(gpa, .{ .family = fam, .name = "init loss minus base rate's", .value = @abs(draftnet.logLoss(pred, games) - baseLoss(games)), .limit = 0.01 });
        try r.add(gpa, .{ .family = fam, .name = "init: logit sum spread, sides swapped", .value = try asymmetry(gpa, io, &n, games), .limit = 1e-4 });
        try r.add(gpa, .{ .family = fam, .name = "init: non-finite parameters", .value = @floatFromInt(@intFromBool(!allFinite(n.p))), .limit = 0.5 });
    }

    if (s.learn_games > 0) {
        const all = try bigGames(gpa, s.learn_games + 4000, n_ids, 0.5, 12);
        defer gpa.free(all);
        const train = all[0..s.learn_games];
        const held = all[s.learn_games..];
        var n = try draftnet.fitCpu(gpa, io, cfg, n_ids, train, s.learn_epochs * draftnet.stepsPerEpoch(train.len, cfg.batch), threads, null);
        defer n.deinit(gpa);
        const pred = try gpa.alloc(f32, held.len);
        defer gpa.free(pred);
        try n.predict(gpa, io, held, pred);
        // Strengths sd 0.5 over ten slots: a coin flip's loss falls by about 0.1 when learnt
        try r.add(gpa, .{ .family = fam, .name = "held-out loss after training, below base rate's by", .value = baseLoss(held) - draftnet.logLoss(pred, held), .limit = 0.03, .below = false });
        try r.add(gpa, .{ .family = fam, .name = "trained: logit sum spread, sides swapped", .value = try asymmetry(gpa, io, &n, held), .limit = 1e-3 });
        try r.add(gpa, .{ .family = fam, .name = "trained: non-finite parameters", .value = @floatFromInt(@intFromBool(!allFinite(n.p))), .limit = 0.5 });
    }

    if (s.tiny_steps > 0) {
        const tiny = try bigGames(gpa, s.tiny_games, n_ids, 0, 13);
        defer gpa.free(tiny);
        var n = try draftnet.fitCpu(gpa, io, .{ .lr = 3e-3, .wd = 0, .batch = @intCast(s.tiny_games) }, n_ids, tiny, s.tiny_steps, threads, null);
        defer n.deinit(gpa);
        const pred = try gpa.alloc(f32, tiny.len);
        defer gpa.free(pred);
        try n.predict(gpa, io, tiny, pred);
        try r.add(gpa, .{ .family = fam, .name = "tiny set (random labels): train loss after overfitting", .value = draftnet.logLoss(pred, tiny), .limit = 0.1 });
    }

    {
        const tiny = try bigGames(gpa, s.tiny_games, n_ids, 0.5, 14);
        defer gpa.free(tiny);
        const c: draftnet.Config = .{ .batch = @intCast(s.tiny_games / 2) };
        var a = try draftnet.fitCpu(gpa, io, c, n_ids, tiny, s.seed_steps, threads, null);
        defer a.deinit(gpa);
        var b = try draftnet.fitCpu(gpa, io, c, n_ids, tiny, s.seed_steps, threads, null);
        defer b.deinit(gpa);
        var o = try draftnet.fitCpu(gpa, io, .{ .batch = c.batch, .seed = 2 }, n_ids, tiny, s.seed_steps, threads, null);
        defer o.deinit(gpa);
        var same: f64 = 0;
        var other: f64 = 0;
        for (a.p, b.p, o.p) |x, y, z| {
            same = @max(same, @abs(x - y));
            other = @max(other, @abs(x - z));
        }
        try r.add(gpa, .{ .family = fam, .name = "same seed: largest parameter difference", .value = same, .limit = 1e-30 });
        try r.add(gpa, .{ .family = fam, .name = "seed 2: largest parameter difference", .value = other, .limit = 1e-3, .below = false });
    }
}

/// The CPU nets of netcheck through their healthFit hooks (winnet small and resid,
/// setnet): one generic set of checks. A family gives its game type and
///   games(gpa, n, sd, seed): n games, ids 5 + 5k + role of `net_ids`; blue's logit the
///     ids' strengths (sd `sd`, 0 for coin flips), the offset (resid) another strength
///     set, so a residual net has something left to learn
///   fit(gpa, seed, train, steps, scored, pred, overfit) params; overfit drops dropout
///     and decay where the hook allows
///   swap(game): sides exchanged (ids, profiles, y, offset)
fn Small(comptime resid: bool) type {
    return struct {
        const name = if (resid) "resid (winnet)" else "small (winnet)";
        const Game = winnet.NetGame;
        const batch = (winnet.Options{}).batch;
        const overfit_limit = 0.1;

        fn games(gpa: std.mem.Allocator, n: usize, sd: f32, seed: u64) ![]Game {
            var prng: std.Random.DefaultPrng = .init(seed);
            const r = prng.random();
            const st = try strengths(gpa, r, sd);
            defer for (st) |x| gpa.free(x);
            const out = try gpa.alloc(Game, n);
            for (out) |*g| {
                g.* = .{ .ids = undefined, .platform = 0, .y = 0, .off = 0 };
                drawIds(r, &g.ids);
                const z = teamSum(st[0], &g.ids);
                g.off = if (resid) teamSum(st[1], &g.ids) else 0;
                g.y = coin(r, z + g.off);
            }
            return out;
        }

        fn fit(gpa: std.mem.Allocator, seed: u32, train: []const Game, steps: u64, scored: []const Game, pred: []f32, overfit: bool) ![]f32 {
            var o: winnet.Options = .{ .net = if (resid) .resid else .small };
            if (overfit) {
                o.dropout = 0;
                o.wd = 0;
                o.clip = 0;
                o.lr = 3e-3;
                o.batch = @intCast(train.len);
            }
            return winnet.healthFit(gpa, o, seed, net_ids, train, steps, scored, pred);
        }

        fn swap(g: Game) Game {
            var out = g;
            out.ids[0..5].* = g.ids[5..10].*;
            out.ids[5..10].* = g.ids[0..5].*;
            out.y = 1 - g.y;
            out.off = -g.off;
            return out;
        }

        fn label(g: Game) f32 {
            return g.y;
        }

        fn offset(g: Game) f32 {
            return g.off;
        }
    };
}

const Set = struct {
    const name = "set (setnet)";
    const Game = setnet.SetGame;
    const batch = (winnet.Options{}).batch;
    /// healthFit keeps netcheck's dropout 0.2 and decay 0.1: no exact overfit
    const overfit_limit = 0.45;

    fn games(gpa: std.mem.Allocator, n: usize, sd: f32, seed: u64) ![]Game {
        var prng: std.Random.DefaultPrng = .init(seed);
        const r = prng.random();
        const out = try gpa.alloc(Game, n);
        for (out) |*g| {
            g.* = .{ .g = .{ .ids = undefined, .platform = 0, .y = 0, .off = 0 }, .z = undefined };
            drawIds(r, &g.g.ids);
            var z: f32 = 0;
            for (&g.z, 0..) |*zs, slot| {
                for (zs) |*x| x.* = r.floatNorm(f32);
                // The first profile feature carries the strength
                z += if (slot < 5) sd * zs[0] else -sd * zs[0];
            }
            g.g.y = coin(r, z);
        }
        return out;
    }

    fn fit(gpa: std.mem.Allocator, seed: u32, train: []const Game, steps: u64, scored: []const Game, pred: []f32, overfit: bool) ![]f32 {
        _ = overfit;
        return setnet.healthFit(gpa, .{}, seed, net_ids, train, steps, scored, pred);
    }

    fn swap(g: Game) Game {
        var out = g;
        out.g.ids[0..5].* = g.g.ids[5..10].*;
        out.g.ids[5..10].* = g.g.ids[0..5].*;
        out.z[0..5].* = g.z[5..10].*;
        out.z[5..10].* = g.z[0..5].*;
        out.g.y = 1 - g.g.y;
        out.g.off = -g.g.off;
        return out;
    }

    fn label(g: Game) f32 {
        return g.g.y;
    }

    fn offset(g: Game) f32 {
        return g.g.off;
    }
};

/// Player-history net: residual on the offset (the candidate's logit), players' features
/// carry the rest; the first feature holds each player's strength
const Player = struct {
    const name = "player (playernet)";
    const Game = playernet.NetGame;
    const batch = (playernet.Options{}).batch;
    const overfit_limit = 0.1;

    fn games(gpa: std.mem.Allocator, n: usize, sd: f32, seed: u64) ![]Game {
        var prng: std.Random.DefaultPrng = .init(seed);
        const r = prng.random();
        const st = try strengths(gpa, r, 0.5);
        defer for (st) |x| gpa.free(x);
        const out = try gpa.alloc(Game, n);
        for (out) |*g| {
            g.* = .{ .ids = undefined, .x = undefined, .platform = 0, .y = 0, .off = 0 };
            drawIds(r, &g.ids);
            var z: f32 = 0;
            for (&g.x, 0..) |*xs, slot| {
                for (xs) |*x| x.* = r.floatNorm(f32);
                z += if (slot < 5) sd * xs[0] else -sd * xs[0];
            }
            g.off = if (sd > 0) teamSum(st[0], &g.ids) else 0;
            g.y = coin(r, z + g.off);
        }
        return out;
    }

    fn fit(gpa: std.mem.Allocator, seed: u32, train: []const Game, steps: u64, scored: []const Game, pred: []f32, overfit: bool) ![]f32 {
        var o: playernet.Options = .{};
        if (overfit) {
            o.dropout = 0;
            o.wd = 0;
            o.clip = 0;
            o.lr = 3e-3;
            o.batch = @intCast(train.len);
        }
        return playernet.healthFit(gpa, o, seed, net_ids, train, steps, scored, pred);
    }

    fn swap(g: Game) Game {
        var out = g;
        out.ids[0..5].* = g.ids[5..10].*;
        out.ids[5..10].* = g.ids[0..5].*;
        out.x[0..5].* = g.x[5..10].*;
        out.x[5..10].* = g.x[0..5].*;
        out.y = 1 - g.y;
        out.off = -g.off;
        return out;
    }

    fn label(g: Game) f32 {
        return g.y;
    }

    fn offset(g: Game) f32 {
        return g.off;
    }
};

const net_ids: u32 = 205;

fn strengths(gpa: std.mem.Allocator, r: std.Random, sd: f32) ![2][]f32 {
    var out: [2][]f32 = undefined;
    for (&out) |*s| {
        s.* = try gpa.alloc(f32, net_ids);
        for (s.*) |*x| x.* = sd * r.floatNorm(f32);
    }
    return out;
}

/// Ten distinct ids, 5 + 5k + role
fn drawIds(r: std.Random, ids: *[10]u32) void {
    for (ids, 0..) |*id, slot| id.* = while (true) {
        const x = 5 + 5 * r.uintLessThan(u32, (net_ids - 5) / 5) + @as(u32, @intCast(slot % 5));
        if (std.mem.indexOfScalar(u32, ids[0..slot], x) == null) break x;
    };
}

fn teamSum(st: []const f32, ids: *const [10]u32) f32 {
    var z: f32 = 0;
    for (ids, 0..) |id, slot| z += if (slot < 5) st[id] else -st[id];
    return z;
}

fn coin(r: std.Random, z: f32) f32 {
    return if (r.float(f32) < 1 / (1 + @exp(-z))) 1 else 0;
}

fn meanLoss(comptime F: type, games: []const F.Game, pred: ?[]const f32) f64 {
    var l: f64 = 0;
    for (games, 0..) |g, i| {
        const p: f64 = if (pred) |ps| ps[i] else 1 / (1 + @exp(-@as(f64, F.offset(g))));
        const q = std.math.clamp(p, 1e-7, 1 - 1e-7);
        l -= if (F.label(g) > 0.5) @log(q) else @log(1 - q);
    }
    return l / @as(f64, @floatFromInt(games.len));
}

/// Loss of the offset alone, or of the labels' mean when there's none
fn refLoss(comptime F: type, games: []const F.Game) f64 {
    var any = false;
    for (games) |g| any = any or F.offset(g) != 0;
    if (any) return meanLoss(F, games, null);
    var m: f64 = 0;
    for (games) |g| m += F.label(g);
    m /= @floatFromInt(games.len);
    if (m <= 0 or m >= 1) return 0;
    return -(m * @log(m) + (1 - m) * @log(1 - m));
}

fn spread(comptime F: type, gpa: std.mem.Allocator, seed: u32, train: []const F.Game, steps: u64, games: []const F.Game) !f64 {
    const sw = try gpa.alloc(F.Game, games.len);
    defer gpa.free(sw);
    for (sw, games) |*s, g| s.* = F.swap(g);
    const a = try gpa.alloc(f32, games.len);
    defer gpa.free(a);
    const b = try gpa.alloc(f32, games.len);
    defer gpa.free(b);
    // healthFit returns predictions for one scored set: refit (deterministic) for the other
    gpa.free(try F.fit(gpa, seed, train, steps, games, a, false));
    gpa.free(try F.fit(gpa, seed, train, steps, sw, b, false));
    var lo: f64 = std.math.inf(f64);
    var hi: f64 = -std.math.inf(f64);
    for (a, b) |x, y| {
        const sm = logit(x) + logit(y);
        lo = @min(lo, sm);
        hi = @max(hi, sm);
    }
    return hi - lo;
}

fn checkFamily(comptime F: type, gpa: std.mem.Allocator, r: *Report, s: Sizes) !void {
    const fam = F.name;
    {
        const games = try F.games(gpa, 2000, 0, 21);
        defer gpa.free(games);
        const pred = try gpa.alloc(f32, games.len);
        defer gpa.free(pred);
        const p = try F.fit(gpa, 1, games, 0, games, pred, false);
        defer gpa.free(p);
        try r.add(gpa, .{ .family = fam, .name = "init loss minus base rate's (offset's when resid)", .value = @abs(meanLoss(F, games, pred) - refLoss(F, games)), .limit = 0.01 });
        try r.add(gpa, .{ .family = fam, .name = "init: logit sum spread, sides swapped", .value = try spread(F, gpa, 1, games, 0, games), .limit = 1e-4 });
        try r.add(gpa, .{ .family = fam, .name = "init: non-finite parameters", .value = @floatFromInt(@intFromBool(!allFinite(p))), .limit = 0.5 });
    }
    if (s.learn_games > 0) {
        const all = try F.games(gpa, s.learn_games + 4000, 0.5, 22);
        defer gpa.free(all);
        const train = all[0..s.learn_games];
        const held = all[s.learn_games..];
        const steps = s.learn_epochs * draftnet.stepsPerEpoch(train.len, F.batch);
        const pred = try gpa.alloc(f32, held.len);
        defer gpa.free(pred);
        const p = try F.fit(gpa, 1, train, steps, held, pred, false);
        defer gpa.free(p);
        try r.add(gpa, .{ .family = fam, .name = "held-out loss after training, below base rate's (offset's) by", .value = refLoss(F, held) - meanLoss(F, held, pred), .limit = 0.03, .below = false });
        try r.add(gpa, .{ .family = fam, .name = "trained: logit sum spread, sides swapped", .value = try spread(F, gpa, 1, train, steps, held), .limit = 1e-3 });
        try r.add(gpa, .{ .family = fam, .name = "trained: non-finite parameters", .value = @floatFromInt(@intFromBool(!allFinite(p))), .limit = 0.5 });
    }
    if (s.tiny_steps > 0) {
        const tiny = try F.games(gpa, s.tiny_games, 0, 23);
        defer gpa.free(tiny);
        const pred = try gpa.alloc(f32, tiny.len);
        defer gpa.free(pred);
        const p = try F.fit(gpa, 1, tiny, s.tiny_steps, tiny, pred, true);
        defer gpa.free(p);
        try r.add(gpa, .{ .family = fam, .name = "tiny set (random labels): train loss after overfitting", .value = meanLoss(F, tiny, pred), .limit = F.overfit_limit });
    }
    {
        const tiny = try F.games(gpa, s.tiny_games, 0.5, 24);
        defer gpa.free(tiny);
        const pred = try gpa.alloc(f32, tiny.len);
        defer gpa.free(pred);
        const a = try F.fit(gpa, 1, tiny, s.seed_steps, tiny, pred, false);
        defer gpa.free(a);
        const b = try F.fit(gpa, 1, tiny, s.seed_steps, tiny, pred, false);
        defer gpa.free(b);
        const o = try F.fit(gpa, 2, tiny, s.seed_steps, tiny, pred, false);
        defer gpa.free(o);
        var same: f64 = 0;
        var other: f64 = 0;
        for (a, b, o) |x, y, z| {
            same = @max(same, @abs(x - y));
            other = @max(other, @abs(x - z));
        }
        try r.add(gpa, .{ .family = fam, .name = "same seed: largest parameter difference", .value = same, .limit = 1e-30 });
        try r.add(gpa, .{ .family = fam, .name = "seed 2: largest parameter difference", .value = other, .limit = 1e-3, .below = false });
    }
}

pub fn main(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: Io, argv: []const []const u8) !u8 {
    _ = arena;
    var threads: usize = std.Thread.getCpuCount() catch 1;
    var i: usize = 0;
    while (i + 1 < argv.len) : (i += 2) {
        if (std.mem.eql(u8, argv[i], "--threads")) threads = try std.fmt.parseInt(usize, argv[i + 1], 10) else {
            std.debug.print("usage:\n{s}", .{usage});
            return 2;
        }
    }
    var r: Report = .{};
    defer r.checks.deinit(gpa);
    try checkBig(gpa, io, &r, threads, full);
    try checkFamily(Small(false), gpa, &r, full);
    try checkFamily(Small(true), gpa, &r, full);
    try checkFamily(Set, gpa, &r, full);
    try checkFamily(Player, gpa, &r, full);
    var buf: [4096]u8 = undefined;
    var stdout = Io.File.stdout().writer(io, &buf);
    const w = &stdout.interface;
    try w.writeAll("# health: training checks on synthetic games\n\n");
    try r.write(w);
    const bad = r.failed();
    try w.print("\n{d} of {d} checks failed\n", .{ bad, r.checks.items.len });
    try w.flush();
    return if (bad == 0) 0 else 1;
}

test "health: nets, quick checks" {
    const gpa = std.testing.allocator;
    var r: Report = .{};
    defer r.checks.deinit(gpa);
    try checkBig(gpa, std.testing.io, &r, 1, quick);
    try checkFamily(Small(false), gpa, &r, quick);
    try checkFamily(Small(true), gpa, &r, quick);
    try checkFamily(Set, gpa, &r, quick);
    try checkFamily(Player, gpa, &r, quick);
    for (r.checks.items) |c| {
        if (!c.ok()) std.debug.print("{s}: {s} = {d}\n", .{ c.family, c.name, c.value });
        try std.testing.expect(c.ok());
    }
}
