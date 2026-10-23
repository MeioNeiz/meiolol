//! `meiolol-lab effects SNAP`: the shrunk additive draft model (src/additive.zig) on
//! netcheck's blocks (dev-val and win-comp's 5 forward folds, every fit from the block's
//! fit games only), paired per game with the -Dcand candidate (win-ratings) fitted on the
//! same games. Variants nest families of terms, so each family's held-out gain shows;
//! --drop 1 also refits the full model without each block in turn. Then the full model on
//! every dev-visible game: per block the spread of true effects (sd, bootstrap over games)
//! and the clearest single cells. Outcomes: win, and blue-minus-red team gold at 14
//! (gaussian), turned into win through a logistic slope on the fit games' real gold
//! difference. --soft FILE: distillation on the teacher's cross-fitted chances (FILE:
//! match_id, block, seed, p_blue; netcheck --fit-preds), seeds averaged as logits: the
//! full model fitted to the teacher's logit by squared error (student-logit), and to
//! alpha * outcome + (1 - alpha) * the teacher's chance (student-mix).
//! Writes DIR/folds.tsv, DIR/games-<model>.tsv (pairable, netcheck's format),
//! DIR/components.tsv, DIR/cells.tsv

const std = @import("std");
const api = @import("api");
const cand = @import("cand");
const rows = @import("rows.zig");
const protocol = @import("protocol.zig");
const harness = @import("harness.zig");
const seatstats = @import("seatstats.zig");
const additive = @import("../additive.zig");
const addinputs = @import("addinputs.zig");
const par = @import("../par.zig");
const winnet = @import("winnet.zig");

const Io = std.Io;
const A = additive;
const Mix = addinputs.Mix;
const Inputs = addinputs.Inputs;
const inputs = addinputs.inputs;
const gameIn = addinputs.gameIn;

pub const usage =
    \\  effects SNAP [--out DIR] [--blocks dev,1,2,3,4,5|none] [--boot N] [--drop 0|1]
    \\                                  [--null N] (shuffled-outcome refits per table)
    \\                                  [--threads N] [--soft FILE --alpha X]
    \\                                  [--shuffle SEED] (labels permuted: a control)
    \\                                  [--resample N] (fold fits on netcheck's seeded
    \\                                  90% of fit games, the candidate's too)
    \\                                  [--param v1|v2] (v2, default: 15 identified
    \\                                  matchup blocks; v1: 25 enemy blocks, two cells
    \\                                  per matchup, as runs before 14 Oct 03Z)
    \\                                  [--calibrate SIMS] (block variances corrected by
    \\                                  simulation: calibrated table, and full-cal, the
    \\                                  full model refitted with them fixed)
    \\                                  shrunk additive model (champion strength, ally
    \\                                  and enemy role-pair blocks, damage mix) vs the
    \\                                  -Dcand candidate on dev-val and the 5 forward
    \\                                  folds; per-block effect spreads with bootstrap
    \\                                  intervals; win and team gold at 14
    \\                                  (lab/effects.zig)
    \\
;

const Options = struct {
    out: []const u8 = ".",
    blocks: []const Block = &.{ .dev, .f1, .f2, .f3, .f4, .f5 },
    boot: u32 = 100,
    /// Shuffled-outcome refits per table: thin pair cells give a block spread under no
    /// effect at all, so a block counts only above its null
    null: u32 = 10,
    drop: bool = false,
    threads: u32 = 10,
    soft: ?[]const u8 = null,
    alpha: f32 = 0.5,
    /// Shuffled-label control: game results (win and gold together) permuted across games
    /// before anything is fitted; every gain and block sd must come out ~0
    shuffle: ?u64 = null,
    /// Noise-floor refits: every block's fit games (the candidate's too) on netcheck's
    /// seeded 90% (winnet.inResample), so a gain's refit spread shows
    resample: ?u32 = null,
    /// Simulations per calibration round (additive.calibrate); 0 off
    calibrate: u32 = 0,
    param: Param = .v2,
};

/// v2: identified matchups (additive.Variant.matchupGroups); v1: the 25 enemy blocks
const Param = enum { v1, v2 };

/// Calibration rounds (additive.calibrate's iters)
const cal_rounds = 8;
const cal_seed = 0xca1;

const Block = enum { dev, f1, f2, f3, f4, f5 };
const n_folds = harness.folds;

/// Fit on dev-visible games before `before`; score dev-val (dev) or dev-visible games in
/// [lo, hi): netcheck's blocks (winnet.zig Spec), so games pair with its preds
const Spec = struct {
    before: i64,
    lo: i64,
    hi: i64,
    dev: bool,
    resample: ?u32 = null,

    fn fits(s: Spec, c: harness.Cuts, g: rows.Game) bool {
        if (s.resample) |r| if (!winnet.inResample(g, r)) return false;
        return harness.visible(.dev, c, g) and g.start < s.before;
    }

    fn scores(s: Spec, c: harness.Cuts, g: rows.Game) bool {
        if (s.dev) return harness.scored(.dev, c, g);
        return harness.visible(.dev, c, g) and harness.inRegion(c, g) and g.start >= s.lo and g.start < s.hi;
    }
};

/// The candidate's fit games (buildTrainWhere's keep)
const FitKeep = struct {
    spec: Spec,
    c: harness.Cuts,

    pub fn keep(k: FitKeep, g: rows.Game) bool {
        return k.spec.fits(k.c, g);
    }
};

/// A spread from the blocks' variances: block a's sd, plus block b's when set (an enemy
/// matchup's two sides; b == a counts the block twice)
const Pick = struct {
    a: usize,
    b: ?usize = null,

    fn of(p: Pick, s2: [A.n_groups]f64) f64 {
        const x = @sqrt(@max(s2[p.a], 0));
        return if (p.b) |b| x + @sqrt(@max(s2[b], 0)) else x;
    }
};

const Summary = struct {
    sd: f64,
    /// 95% from the half-samples
    lo: f64,
    hi: f64,
    half_mean: f64,
    /// Shuffled-outcome refits: mean square and 95th percentile
    null_ms: f64,
    null_q95: f64,
    detected: bool,

    /// Corrected for the null: sqrt(x^2 - null mean square)
    fn above(x: f64, v: f64) f64 {
        return @sqrt(@max(x * x - v, 0));
    }
};

fn summarise(arena: std.mem.Allocator, pick: Pick, sigma2: [A.n_groups]f64, boots: []const [A.n_groups]f64, nulls: []const [A.n_groups]f64) !Summary {
    // Var of the full-data estimate ~ Var over half-samples / 2
    var hm: f64 = 0;
    var hm2: f64 = 0;
    for (boots) |b| {
        const x = pick.of(b);
        hm += x;
        hm2 += x * x;
    }
    const nb: f64 = @floatFromInt(@max(boots.len, 1));
    hm /= nb;
    const se = @sqrt(@max(hm2 / nb - hm * hm, 0) * nb / @max(nb - 1, 1) / 2);
    const sd = pick.of(sigma2);
    const lo = @max(sd - 1.96 * se, 0);
    var nv: f64 = 0;
    const nsd = try arena.alloc(f64, nulls.len);
    for (nulls, nsd) |nl, *x| {
        x.* = pick.of(nl);
        nv += x.* * x.*;
    }
    nv /= @floatFromInt(@max(nulls.len, 1));
    std.mem.sort(f64, nsd, {}, std.sort.asc(f64));
    const q95 = if (nulls.len > 0) nsd[@min(nulls.len - 1, @as(usize, @ceil(0.95 * @as(f64, @floatFromInt(nulls.len)))) -| 1)] else 0;
    return .{ .sd = sd, .lo = lo, .hi = sd + 1.96 * se, .half_mean = hm, .null_ms = nv, .null_q95 = q95, .detected = sd > q95 and lo > q95 };
}

fn blockName(b: Block) []const u8 {
    return switch (b) {
        .dev => "dev",
        inline else => |t| @tagName(t)[1..],
    };
}

/// A nested family of terms
const Model = struct {
    name: []const u8,
    variant: A.Variant,
    target: Target = .win,
};

const Target = enum {
    win,
    /// Team gold at 14, blue minus red (gaussian), to win through the gold slope
    gold,
    /// Teacher's logit (gaussian)
    logit,
    /// alpha * win + (1 - alpha) * the teacher's chance (logistic)
    mix,

    fn kind(t: Target) A.Kind {
        return switch (t) {
            .win, .mix => .logistic,
            .gold, .logit => .gaussian,
        };
    }
};

fn lanePair(r: usize, q: usize) bool {
    return r == q or (r == 3 and q == 4) or (r == 4 and q == 3);
}

fn models(arena: std.mem.Allocator, param: Param) ![]Model {
    var mains = A.Variant.mains();
    mains.matchup = param == .v2;
    var mix = mains;
    mix.cont = 1;
    var ally = mix;
    for (0..A.n_role) |r| for (r + 1..A.n_role) |q| {
        ally = ally.with(A.allyGroup(r, q));
    };
    var lane = mix;
    var enemy = mix;
    for (0..A.n_role) |r| for (0..A.n_role) |q| {
        // v2: the r <= q block holds the matchup from both sides
        if (param == .v2 and q < r) continue;
        if (lanePair(r, q)) lane = lane.with(A.enemyGroup(r, q));
        enemy = enemy.with(A.enemyGroup(r, q));
    };
    const full = addinputs.fullVariant(param == .v2, 1);
    var nomix = full;
    nomix.cont = 0;
    var out: std.ArrayList(Model) = .empty;
    try out.appendSlice(arena, &.{
        .{ .name = "mains", .variant = mains },
        .{ .name = "mains-mix", .variant = mix },
        .{ .name = "ally", .variant = ally },
        .{ .name = "lane", .variant = lane },
        .{ .name = "enemy", .variant = enemy },
        .{ .name = "full", .variant = full },
        .{ .name = "full-nomix", .variant = nomix },
        .{ .name = "gold", .variant = full, .target = .gold },
    });
    return out.toOwnedSlice(arena);
}

const full_model = 5;

// ---------------------------------------------------------------- teacher (--soft)

/// Teacher's cross-fitted logit per (block, match id), mean over seeds
const Soft = struct {
    map: std.StringHashMapUnmanaged([2]f64) = .empty,

    fn load(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: Io, path: []const u8) !Soft {
        const text = try Io.Dir.cwd().readFileAlloc(io, path, arena, .unlimited);
        var s: Soft = .{};
        var lines = std.mem.tokenizeScalar(u8, text, '\n');
        while (lines.next()) |line| {
            var f = std.mem.tokenizeScalar(u8, line, '\t');
            const id = f.next() orelse continue;
            const block = f.next() orelse continue;
            _ = f.next() orelse continue;
            const p = std.math.clamp(std.fmt.parseFloat(f64, f.next() orelse continue) catch continue, 1e-6, 1 - 1e-6);
            const k = try std.mem.concat(arena, u8, &.{ block, "\t", id });
            const e = try s.map.getOrPutValue(gpa, k, .{ 0, 0 });
            e.value_ptr[0] += @log(p / (1 - p));
            e.value_ptr[1] += 1;
        }
        return s;
    }

    fn get(s: *const Soft, buf: []u8, block: []const u8, id: []const u8) ?f64 {
        const k = std.mem.print(buf, "{s}\t{s}", .{ block, id }) catch return null;
        const v = s.map.get(k) orelse return null;
        return v[0] / v[1];
    }
};

// ---------------------------------------------------------------- blocks

fn loss1(y: f32, p: f64) f64 {
    const q = std.math.clamp(p, 1e-6, 1 - 1e-6);
    return -(y * @log(q) + (1 - y) * @log(1 - q));
}

fn sigmoid(x: f64) f64 {
    return 1 / (1 + @exp(-x));
}

const Task = struct {
    model: Model,
    /// Fit without this group (--drop); 0 none
    without: usize = 0,
    /// Refit with the variances calibrated by simulation (--calibrate)
    calibrate: bool = false,
    label: []const u8,
};

const Result = struct { pred: []f64 = &.{} };

/// Logit of blue's win per unit of gold difference at 14 (thousands), from the fit
/// games' real gold: what a predicted gold edge is worth (one-variable logistic).
/// Intercept, slope, slope's standard error
fn goldSlope(gold: []const f32, win: []const f32) [3]f64 {
    var b0: f64 = 0;
    var b1: f64 = 0;
    var se: f64 = std.math.nan(f64);
    for (0..50) |_| {
        var g0: f64 = 0;
        var g1: f64 = 0;
        var h00: f64 = 0;
        var h01: f64 = 0;
        var h11: f64 = 0;
        for (gold, win) |x, y| {
            if (std.math.isNan(x)) continue;
            const p = sigmoid(b0 + b1 * x);
            const w = p * (1 - p);
            g0 += y - p;
            g1 += (y - p) * x;
            h00 += w;
            h01 += w * x;
            h11 += w * x * x;
        }
        const det = h00 * h11 - h01 * h01;
        if (det <= 0) break;
        se = @sqrt(h00 / det);
        b0 += (h11 * g0 - h01 * g1) / det;
        b1 += (h00 * g1 - h01 * g0) / det;
    }
    return .{ b0, b1, se };
}

fn runBlock(
    gpa: std.mem.Allocator,
    arena: std.mem.Allocator,
    io: Io,
    d: *const rows.Data,
    players: []const harness.Players,
    in: Inputs,
    c: harness.Cuts,
    spec: Spec,
    block: Block,
    tasks: []const Task,
    soft: ?*const Soft,
    opts: Options,
    files: *Files,
    pooled: *Pooled,
    w: *Io.Writer,
) !void {
    const t0 = Io.Clock.awake.now(io);
    var fit_idx: std.ArrayList(u32) = .empty;
    defer fit_idx.deinit(gpa);
    var scored: std.ArrayList(u32) = .empty;
    defer scored.deinit(gpa);
    const is_fit = try gpa.alloc(bool, d.games.len);
    defer gpa.free(is_fit);
    for (d.games, is_fit, 0..) |g, *f, i| {
        f.* = spec.fits(c, g);
        if (f.*) try fit_idx.append(gpa, @intCast(i));
        if (spec.scores(c, g)) try scored.append(gpa, @intCast(i));
    }
    var mix = try Mix.init(gpa, d, is_fit, in.win);
    defer mix.deinit(gpa);

    // Fit games per target: win, teacher logit, mix, gold (known gold only)
    const fit_win = try arena.alloc(A.GameIn, fit_idx.items.len);
    const fit_logit = try arena.alloc(A.GameIn, fit_idx.items.len);
    const fit_mix = try arena.alloc(A.GameIn, fit_idx.items.len);
    var fit_gold: std.ArrayList(A.GameIn) = .empty;
    const fit_goldv = try arena.alloc(f32, fit_idx.items.len);
    var n_soft: usize = 0;
    var kbuf: [128]u8 = undefined;
    for (fit_idx.items, fit_win, fit_logit, fit_mix, fit_goldv) |gi, *fw, *fl, *fm, *gv| {
        const m = mix.diff(d, in, gi, true);
        fw.* = gameIn(d, gi, in.win[gi], m);
        fl.* = fw.*;
        fm.* = fw.*;
        if (soft) |s| if (s.get(&kbuf, blockName(block), d.games[gi].match_id)) |z| {
            fl.y = @floatCast(z);
            fm.y = @floatCast(opts.alpha * in.win[gi] + (1 - opts.alpha) * sigmoid(z));
            n_soft += 1;
        };
        gv.* = in.gold[gi];
        if (!std.math.isNan(in.gold[gi])) try fit_gold.append(arena, gameIn(d, gi, in.gold[gi], m));
    }
    if (soft != null and n_soft < fit_idx.items.len) {
        try w.print("block {s}: teacher covers {d} of {d} fit games; refusing a partial soft target\n", .{ blockName(block), n_soft, fit_idx.items.len });
        return error.SoftTargetsIncomplete;
    }
    const scored_in = try arena.alloc(A.GameIn, scored.items.len);
    for (scored.items, scored_in) |gi, *s| s.* = gameIn(d, gi, in.win[gi], mix.diff(d, in, gi, false));
    const slope = goldSlope(fit_goldv, blk: {
        const ys = try arena.alloc(f32, fit_idx.items.len);
        for (fit_idx.items, ys) |gi, *y| y.* = in.win[gi];
        break :blk ys;
    });

    // The reference candidate on the same fit games: blue's chance, the mean over the
    // ten rows' answers (red's as 1 - p), as netcheck's candBlue
    const pc = try arena.alloc(f64, scored.items.len);
    {
        var v = try harness.buildTrainWhere(gpa, d, players, FitKeep{ .spec = spec, .c = c });
        defer v.deinit();
        const slot = try gpa.alloc(i32, d.games.len);
        defer gpa.free(slot);
        @memset(slot, -1);
        for (scored.items, 0..) |gi, i| slot[gi] = @intCast(i);
        const cnt = try arena.alloc(u32, scored.items.len);
        @memset(cnt, 0);
        @memset(pc, 0);
        var m = try harness.fit(cand, gpa, &v.train, .{ .seed = 1 });
        defer cand.deinit(&m, gpa);
        for (d.rows) |r| {
            if (slot[r.game] < 0) continue;
            const i: usize = @intCast(slot[r.game]);
            const q = harness.query(cand.scope, d.games[r.game], players[r.game], r, false);
            const p: f64 = cand.predict(&m, &q)[api.outcomeIndex(.win)];
            pc[i] += if (r.side == 0) p else 1 - p;
            cnt[i] += 1;
        }
        for (pc, cnt) |*p, n| p.* /= @floatFromInt(@max(n, 1));
    }

    // Additive fits, a batch of threads at a time
    const results = try arena.alloc(Result, tasks.len);
    const Ctx = struct {
        gpa: std.mem.Allocator,
        io: Io,
        sims: u32,
        tasks: []const Task,
        results: []Result,
        fit_win: []const A.GameIn,
        fit_logit: []const A.GameIn,
        fit_mix: []const A.GameIn,
        fit_gold: []const A.GameIn,
        scored: []const A.GameIn,
        slope: [3]f64,
        fn one(x: @This(), i: usize) !void {
            const t = x.tasks[i];
            var v = t.model.variant;
            if (t.without != 0) v.groups &= ~(@as(u64, 1) << @intCast(t.without));
            const games = switch (t.model.target) {
                .win => x.fit_win,
                .gold => x.fit_gold,
                .logit => x.fit_logit,
                .mix => x.fit_mix,
            };
            var p = try A.build(x.gpa, t.model.target.kind(), v, games);
            defer p.deinit(x.gpa);
            var f = try A.fit(x.gpa, &p, .{}, null, null);
            defer f.deinit(x.gpa);
            if (t.calibrate) {
                const cal = try A.calibrate(x.gpa, x.io, &p, &f, .{}, x.sims, cal_rounds, cal_seed);
                var start = f;
                start.sigma2 = cal.sigma2;
                const fc = try A.fit(x.gpa, &p, .{ .estimate = false }, null, &start);
                f.deinit(x.gpa);
                f = fc;
            }
            const pred = try x.gpa.alloc(f64, x.scored.len);
            for (x.scored, pred) |*g, *o| {
                const e = A.predict(&p, &f, g);
                o.* = switch (t.model.target) {
                    .win, .mix, .logit => sigmoid(e),
                    // Predicted gold edge -> win through the fit games' gold slope; the
                    // side term is in the gold model's platform intercept already
                    .gold => sigmoid(x.slope[0] + x.slope[1] * e),
                };
            }
            x.results[i] = .{ .pred = pred };
        }
    };
    var at: usize = 0;
    while (at < tasks.len) : (at += opts.threads) {
        const n = @min(opts.threads, tasks.len - at);
        try par.forEach(io, n, Ctx{
            .gpa = gpa,
            .io = io,
            .sims = opts.calibrate,
            .tasks = tasks[at..][0..n],
            .results = results[at..][0..n],
            .fit_win = fit_win,
            .fit_logit = fit_logit,
            .fit_mix = fit_mix,
            .fit_gold = fit_gold.items,
            .scored = scored_in,
            .slope = slope,
        }, Ctx.one);
    }
    defer for (results) |r| gpa.free(r.pred);

    const name = blockName(block);
    const secs: f64 = @as(f64, @floatFromInt(t0.durationTo(Io.Clock.awake.now(io)).nanoseconds)) / 1e9;
    try w.print("block {s}: fit {d} games ({d} with gold at 14), scored {d}; gold slope {d:.3} logit per 1000; {d:.0} s\n", .{ name, fit_idx.items.len, fit_gold.items.len, scored.items.len, slope[1], secs });
    var ref_loss: f64 = 0;
    for (scored.items, pc) |gi, p| ref_loss += loss1(in.win[gi], p);
    const n_sc: f64 = @floatFromInt(@max(scored.items.len, 1));
    try w.print("  {s}: {d:.5}\n", .{ cand_name, ref_loss / n_sc });
    for (tasks, results) |t, r| {
        var s: f64 = 0;
        var s2: f64 = 0;
        var l: f64 = 0;
        for (scored.items, pc, r.pred) |gi, a, b| {
            const x = loss1(in.win[gi], b) - loss1(in.win[gi], a);
            l += loss1(in.win[gi], b);
            s += x;
            s2 += x * x;
        }
        const mean = s / n_sc;
        const se = @sqrt(@max(s2 / n_sc - mean * mean, 0) / @max(n_sc - 1, 1));
        try w.print("  {s}: {d:.5}, vs {s} {d:.5} +- {d:.5}\n", .{ t.label, l / n_sc, cand_name, mean, 1.96 * se });
        try files.folds.print("{s}\t{s}\t{d}\t{d}\t{d:.6}\t{d:.6}\t{d:.6}\t{d:.6}\n", .{ name, t.label, fit_idx.items.len, scored.items.len, l / n_sc, ref_loss / n_sc, mean, se });
        if (t.model.target == .gold) {
            // Diagnostic, from the scored games' outcomes: what the draft's predicted
            // gold edge is worth in win, beside in-game gold's slope from the fit games
            const edge = try arena.alloc(f32, scored.items.len);
            const ys = try arena.alloc(f32, scored.items.len);
            for (scored.items, r.pred, edge, ys) |gi, q, *e, *y| {
                e.* = @floatCast((@log(q / (1 - q)) - slope[0]) / slope[1]);
                y.* = in.win[gi];
            }
            const ds = goldSlope(edge, ys);
            try w.print("    draft gold edge on scored games: {d:.3} +- {d:.3} logit per 1000 (in-game gold {d:.3})\n", .{ ds[1], 1.96 * ds[2], slope[1] });
            // Does it predict gold at all: held-out R^2 of the edge on the real gold
            // difference, and the real difference's own sd
            var n: f64 = 0;
            var sy: f64 = 0;
            var syy: f64 = 0;
            var sse: f64 = 0;
            for (scored.items, edge) |gi, e| {
                const g = in.gold[gi];
                if (std.math.isNan(g)) continue;
                n += 1;
                sy += g;
                syy += g * g;
                sse += (g - e) * (g - e);
            }
            const var_y = syy / @max(n, 1) - (sy / @max(n, 1)) * (sy / @max(n, 1));
            try w.print("    gold at 14 on {d} scored games: sd {d:.0}, held-out R^2 {d:.4}\n", .{ n, @sqrt(var_y) * 1000, 1 - sse / @max(n, 1) / var_y });
        }
    }
    try w.flush();
    try files.folds.flush();

    const gw = try files.gamesFor(io, cand_name);
    for (scored.items, pc) |gi, p| try gw.print("{s}\t0\twin\t{d}\t{d:.6}\t{s}\n", .{ d.games[gi].match_id, in.win[gi], p, name });
    for (tasks, results) |t, r| {
        const tw = try files.gamesFor(io, t.label);
        for (scored.items, r.pred) |gi, p| try tw.print("{s}\t0\twin\t{d}\t{d:.6}\t{s}\n", .{ d.games[gi].match_id, in.win[gi], p, name });
    }
    if (block != .dev) {
        for (scored.items, pc) |gi, p| {
            try pooled.y.append(gpa, in.win[gi]);
            try pooled.fold.append(gpa, @intCast(@backingInt(block)));
            try pooled.ref.append(gpa, p);
        }
        if (pooled.preds.len == 0) {
            pooled.preds = try files.arena.alloc(std.ArrayList(f64), tasks.len);
            for (pooled.preds) |*x| x.* = .empty;
        }
        for (pooled.preds, results) |*x, r| try x.appendSlice(gpa, r.pred);
    }
}

const Pooled = struct {
    /// Fold of each pooled game (1..5)
    fold: std.ArrayList(u8) = .empty,
    y: std.ArrayList(f32) = .empty,
    ref: std.ArrayList(f64) = .empty,
    preds: []std.ArrayList(f64) = &.{},

    fn deinit(p: *Pooled, gpa: std.mem.Allocator) void {
        p.y.deinit(gpa);
        p.fold.deinit(gpa);
        p.ref.deinit(gpa);
        for (p.preds) |*x| x.deinit(gpa);
    }
};

/// b's log loss minus a's per game (negative: b better), and the folds where b is better
fn pairedFolds(p: Pooled, a: []const f64, b: []const f64) struct { mean: f64, se: f64, better: u32 } {
    var s: f64 = 0;
    var s2: f64 = 0;
    var per: [n_folds + 1]f64 = @splat(0);
    for (p.y.items, p.fold.items, a, b) |y, f, pa, pb| {
        const v = loss1(y, pb) - loss1(y, pa);
        s += v;
        s2 += v * v;
        per[f] += v;
    }
    const n: f64 = @floatFromInt(@max(p.y.items.len, 1));
    const mean = s / n;
    var better: u32 = 0;
    for (per[1..]) |x| better += @intFromBool(x < 0);
    return .{ .mean = mean, .se = @sqrt(@max(s2 / n - mean * mean, 0) / @max(n - 1, 1)), .better = better };
}

const cand_name: []const u8 = if (@hasDecl(cand, "name")) cand.name else "cand";

/// Lives the whole run: its writers come from the run's arena, not a block's
const Files = struct {
    arena: std.mem.Allocator,
    dir: Io.Dir,
    folds: *Io.Writer,
    games: std.StringHashMapUnmanaged(*Io.File.Writer) = .empty,

    fn gamesFor(f: *Files, io: Io, label: []const u8) !*Io.Writer {
        const arena = f.arena;
        if (f.games.get(label)) |x| return &x.interface;
        const file = try f.dir.createFile(io, try arena.print("games-{s}.tsv", .{label}), .{});
        const buf = try arena.alloc(u8, 64 * 1024);
        const fw = try arena.create(Io.File.Writer);
        fw.* = file.writer(io, buf);
        try fw.interface.writeAll("match_id\tslot\toutcome\ty\tpred\tblock\n");
        try f.games.put(arena, label, fw);
        return &fw.interface;
    }

    fn close(f: *Files, io: Io) !void {
        var it = f.games.valueIterator();
        while (it.next()) |x| {
            try x.*.interface.flush();
            x.*.file.close(io);
        }
    }
};

// ---------------------------------------------------------------- effects on all games

/// The full model (win, and gold) on every dev-visible game: per block sigma with a
/// half-sampling interval (warm-started refits on random halves of the games; a
/// bootstrap's duplicated games make thin pair cells look consistent and inflate their
/// blocks), and single cells
fn components(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: Io, d: *const rows.Data, in: Inputs, c: harness.Cuts, opts: Options, soft: ?*const Soft, dir: Io.Dir, w: *Io.Writer) !void {
    const is_fit = try gpa.alloc(bool, d.games.len);
    defer gpa.free(is_fit);
    var idx: std.ArrayList(u32) = .empty;
    defer idx.deinit(gpa);
    for (d.games, is_fit, 0..) |g, *f, i| {
        f.* = harness.visible(.dev, c, g);
        if (f.*) try idx.append(gpa, @intCast(i));
    }
    var mix = try Mix.init(gpa, d, is_fit, in.win);
    defer mix.deinit(gpa);
    var win_games: std.ArrayList(A.GameIn) = .empty;
    var gold_games: std.ArrayList(A.GameIn) = .empty;
    var goldv: std.ArrayList(f32) = .empty;
    var winv: std.ArrayList(f32) = .empty;
    // The student's target: the dev block's fit games are every dev-visible game
    var teacher_games: std.ArrayList(A.GameIn) = .empty;
    var kbuf: [128]u8 = undefined;
    for (idx.items) |gi| {
        const m = mix.diff(d, in, gi, true);
        try win_games.append(arena, gameIn(d, gi, in.win[gi], m));
        if (soft) |sf| if (sf.get(&kbuf, "dev", d.games[gi].match_id)) |z| {
            try teacher_games.append(arena, gameIn(d, gi, @floatCast(z), m));
        };
        try goldv.append(arena, in.gold[gi]);
        try winv.append(arena, in.win[gi]);
        if (!std.math.isNan(in.gold[gi])) try gold_games.append(arena, gameIn(d, gi, in.gold[gi], m));
    }
    const slope = goldSlope(goldv.items, winv.items)[1];

    var cf = try dir.createFile(io, "components.tsv", .{});
    defer cf.close(io);
    var cbuf: [16 * 1024]u8 = undefined;
    var cw = cf.writer(io, &cbuf);
    try cw.interface.print("# fit on {d} dev-visible games ({d} with gold at 14); gold slope {d:.4} logit per 1000 gold\n", .{ win_games.items.len, gold_games.items.len, slope });
    try cw.interface.writeAll("outcome\tblock\tcells\tgames_per_cell\teff_params\tsd\tsd_lo\tsd_hi\tsd_pp\tsd_pp_lo\tsd_pp_hi\tboot\tnull_sd\tnull_q95\tsd_corr_pp\tsd_corr_pp_lo\tsd_corr_pp_hi\tdetected\n");
    var lf = try dir.createFile(io, "cells.tsv", .{});
    defer lf.close(io);
    var lbuf: [16 * 1024]u8 = undefined;
    var lw = lf.writer(io, &lbuf);
    try lw.interface.writeAll("outcome\tblock\tchampion_a\tchampion_b\tgames\teffect\tci\tunit\n");

    const full = addinputs.fullVariant(opts.param == .v2, 1);
    if (soft != null and teacher_games.items.len < win_games.items.len) {
        try w.print("teacher covers {d} of {d} dev games: no student table\n", .{ teacher_games.items.len, win_games.items.len });
        teacher_games.clearRetainingCapacity();
    }
    for ([_]Target{ .win, .gold, .logit }) |target| {
        const games = switch (target) {
            .win => win_games.items,
            .gold => gold_games.items,
            .logit => teacher_games.items,
            .mix => unreachable,
        };
        if (games.len == 0) continue;
        const kind = target.kind();
        var p = try A.build(gpa, kind, full, games);
        defer p.deinit(gpa);
        var f = try A.fit(gpa, &p, .{}, null, null);
        defer f.deinit(gpa);
        const outcome = switch (target) {
            .win => "win",
            .gold => "gold14",
            else => "teacher",
        };
        // win and the teacher's logit in win pp at 50%, gold in gold
        const in_gold = target == .gold;
        // Half-samples: each rep fits a random half of the games (weight 0 or 1)
        const boots = try arena.alloc([A.n_groups]f64, opts.boot);
        const Ctx = struct {
            gpa: std.mem.Allocator,
            p: *const A.Problem,
            f: *const A.Fit,
            boots: [][A.n_groups]f64,
            fn one(x: @This(), i: usize) !void {
                const ws = try x.gpa.alloc(f32, x.p.games.len);
                defer x.gpa.free(ws);
                var rng: std.Random.DefaultPrng = .init(0xb007 +% i);
                const r = rng.random();
                for (ws) |*v| v.* = if (r.boolean()) 1 else 0;
                var b = try A.fit(x.gpa, x.p, .{ .outer = 15 }, ws, x.f);
                defer b.deinit(x.gpa);
                x.boots[i] = b.sigma2;
            }
        };
        var at: usize = 0;
        while (at < opts.boot) : (at += opts.threads) {
            const n = @min(opts.threads, opts.boot - at);
            try par.forEach(io, n, Ctx{ .gpa = gpa, .p = &p, .f = &f, .boots = boots[at..][0..n] }, Ctx.one);
        }
        // Null: the same fit with outcomes permuted across games (the draft kept)
        const nulls = try arena.alloc([A.n_groups]f64, opts.null);
        const NullCtx = struct {
            gpa: std.mem.Allocator,
            kind: A.Kind,
            variant: A.Variant,
            games: []const A.GameIn,
            nulls: [][A.n_groups]f64,
            base: usize,
            fn one(x: @This(), i: usize) !void {
                const gs = try x.gpa.dupe(A.GameIn, x.games);
                defer x.gpa.free(gs);
                var rng: std.Random.DefaultPrng = .init(0x9a11 +% (x.base + i));
                const r = rng.random();
                var k = gs.len;
                while (k > 1) {
                    k -= 1;
                    const j = r.uintLessThan(usize, k + 1);
                    std.mem.swap(f32, &gs[k].y, &gs[j].y);
                }
                var pn = try A.build(x.gpa, x.kind, x.variant, gs);
                defer pn.deinit(x.gpa);
                var fnull = try A.fit(x.gpa, &pn, .{}, null, null);
                defer fnull.deinit(x.gpa);
                x.nulls[i] = fnull.sigma2;
            }
        };
        at = 0;
        // Each null rep builds its own problem: fewer at once
        const null_threads = @max(opts.threads / 2, 1);
        while (at < opts.null) : (at += null_threads) {
            const n = @min(null_threads, opts.null - at);
            try par.forEach(io, n, NullCtx{ .gpa = gpa, .kind = kind, .variant = full, .games = games, .nulls = nulls[at..][0..n], .base = at }, NullCtx.one);
        }
        // Effects in win pp at 50% (logit x 25); gold in gold
        const to_unit: f64 = if (in_gold) 1000 else 25;
        const to_pp: f64 = if (in_gold) 25 * slope else 25;
        var nbuf: [64]u8 = undefined;
        try w.print("\n{s}: per block sd of true effects ({s}), 95% from {d} half-samples (sd of the halves / sqrt 2), [half-sample mean]\n", .{ outcome, if (in_gold) "gold" else "win pp", opts.boot });
        for (1..A.n_groups) |g| {
            const n_cells = p.param_start[g + 1] - p.param_start[g];
            if (n_cells == 0) continue;
            var games_in: u64 = 0;
            for (p.param_start[g]..p.param_start[g + 1]) |j| games_in += p.count[j];
            const sm = try summarise(arena, .{ .a = g }, f.sigma2, boots, nulls);
            const sd = sm.sd;
            const lo = sm.lo;
            const hi = sm.hi;
            const hm = sm.half_mean;
            const nv = sm.null_ms;
            const q95 = sm.null_q95;
            const corr = Summary.above;
            const detected = sm.detected;
            const label = A.groupName(&nbuf, g);
            try cw.interface.print("{s}\t{s}\t{d}\t{d:.1}\t{d:.1}\t{d:.5}\t{d:.5}\t{d:.5}\t{d:.3}\t{d:.3}\t{d:.3}\t{d}\t{d:.5}\t{d:.5}\t{d:.3}\t{d:.3}\t{d:.3}\t{d}\n", .{
                outcome,              label,                  n_cells,              @as(f64, @floatFromInt(games_in)) / @as(f64, @floatFromInt(n_cells)),
                f.gamma[g],           sd,                     lo,                   hi,
                sd * to_pp,           lo * to_pp,             hi * to_pp,           opts.boot,
                @sqrt(nv),            q95,                    corr(sd, nv) * to_pp, corr(lo, nv) * to_pp,
                corr(hi, nv) * to_pp, @intFromBool(detected),
            });
            try w.print("  {s:<26} {d:>6} cells  sd {d:.2} [{d:.2}, {d:.2}] [{d:.2}]  null {d:.2} (95th {d:.2})  corrected {d:.2} [{d:.2}, {d:.2}] {s} {s}\n", .{ label, n_cells, sd * to_unit, lo * to_unit, hi * to_unit, hm * to_unit, @sqrt(nv) * to_unit, q95 * to_unit, corr(sd, nv) * to_unit, corr(lo, nv) * to_unit, corr(hi, nv) * to_unit, if (in_gold) "gold" else "pp", if (detected) "DETECTED" else "" });
            // Single cells whose posterior interval clears 0, in detected pair blocks only
            if (g < A.g_ally or !detected) continue;
            for (p.param_start[g]..p.param_start[g + 1]) |j| {
                const half = 1.96 / @sqrt(f.h[j]);
                if (@abs(f.theta[j]) <= half) continue;
                const cl = A.cellOf(&p, j);
                try lw.interface.print("{s}\t{s}\t#{d}\t#{d}\t{d}\t{d:.3}\t{d:.3}\t{s}\n", .{ outcome, label, cl.a, cl.b, p.count[j], f.theta[j] * to_unit, half * to_unit, if (in_gold) "gold" else "pp" });
            }
        }
        // A matchup X vs Y enters as cell(r vs q)(X, Y) - cell(q vs r)(Y, X): the fit
        // splits its effect between the two blocks by their variances (half each when
        // r == q, the same block twice), so the matchup's spread is the two cell sds
        // summed (planted lane matchups: one block's sd is half the planted spread)
        if (opts.param == .v1) try w.print("{s}: enemy matchups, spread of X-facing-Y's effect (both blocks' cell sds summed; a same-role block twice), [half-sample mean]\n", .{outcome});
        if (opts.param == .v1) for (0..A.n_role) |r| for (r..A.n_role) |q| {
            const ga = A.enemyGroup(r, q);
            const gb = A.enemyGroup(q, r);
            if (p.param_start[ga + 1] == p.param_start[ga] or p.param_start[gb + 1] == p.param_start[gb]) continue;
            const pick: Pick = .{ .a = ga, .b = gb };
            const sm = try summarise(arena, pick, f.sigma2, boots, nulls);
            const label = try arena.print("matchup {s}-{s}", .{ A.role_names[r], A.role_names[q] });
            var n_cells: usize = 0;
            var games_in: u64 = 0;
            var gamma: f64 = 0;
            for ([2]usize{ ga, gb }, 0..) |g, k| if (k == 0 or gb != ga) {
                n_cells += p.param_start[g + 1] - p.param_start[g];
                for (p.param_start[g]..p.param_start[g + 1]) |jj| games_in += p.count[jj];
                gamma += f.gamma[g];
            };
            const corr = Summary.above;
            try cw.interface.print("{s}\t{s}\t{d}\t{d:.1}\t{d:.1}\t{d:.5}\t{d:.5}\t{d:.5}\t{d:.3}\t{d:.3}\t{d:.3}\t{d}\t{d:.5}\t{d:.5}\t{d:.3}\t{d:.3}\t{d:.3}\t{d}\n", .{
                outcome,                         label,                     n_cells,                         @as(f64, @floatFromInt(games_in)) / @as(f64, @floatFromInt(n_cells)),
                gamma,                           sm.sd,                     sm.lo,                           sm.hi,
                sm.sd * to_pp,                   sm.lo * to_pp,             sm.hi * to_pp,                   opts.boot,
                @sqrt(sm.null_ms),               sm.null_q95,               corr(sm.sd, sm.null_ms) * to_pp, corr(sm.lo, sm.null_ms) * to_pp,
                corr(sm.hi, sm.null_ms) * to_pp, @intFromBool(sm.detected),
            });
            try w.print("  {s:<26} {d:>6} cells  sd {d:.2} [{d:.2}, {d:.2}] [{d:.2}]  null {d:.2} (95th {d:.2})  corrected {d:.2} [{d:.2}, {d:.2}] {s} {s}\n", .{ label, n_cells, sm.sd * to_unit, sm.lo * to_unit, sm.hi * to_unit, sm.half_mean * to_unit, @sqrt(sm.null_ms) * to_unit, sm.null_q95 * to_unit, corr(sm.sd, sm.null_ms) * to_unit, corr(sm.lo, sm.null_ms) * to_unit, corr(sm.hi, sm.null_ms) * to_unit, if (in_gold) "gold" else "pp", if (sm.detected) "DETECTED" else "" });
        };
        if (opts.calibrate > 0) {
            // Laplace-type variances run low on win with thin cells: corrected by
            // simulation; the half-sample interval scaled by the same factor
            const cal = try A.calibrate(gpa, io, &p, &f, .{}, opts.calibrate, cal_rounds, cal_seed);
            try w.print("{s}: calibrated by simulation ({d} sims x {d} rounds; interval = the half-sample one x the factor)\n", .{ outcome, opts.calibrate, cal_rounds });
            for (1..A.n_groups) |g| {
                if (p.param_start[g + 1] == p.param_start[g]) continue;
                const sm = try summarise(arena, .{ .a = g }, f.sigma2, boots, nulls);
                const k = cal.factor[g];
                try w.print("  {s:<26} sd {d:.2} -> {d:.2} [{d:.2}, {d:.2}] {s}, factor {d:.2}, last-round misfit {d:.2}\n", .{ A.groupName(&nbuf, g), sm.sd * to_unit, sm.sd * k * to_unit, sm.lo * k * to_unit, sm.hi * k * to_unit, if (in_gold) "gold" else "pp", k, cal.misfit[g] });
                try cw.interface.print("{s}\tcal {s}\t\t\t\t{d:.5}\t{d:.5}\t{d:.5}\t{d:.3}\t{d:.3}\t{d:.3}\t{d}\t\t\t\t\t\t\n", .{ outcome, A.groupName(&nbuf, g), sm.sd * k, sm.lo * k, sm.hi * k, sm.sd * k * to_pp, sm.lo * k * to_pp, sm.hi * k * to_pp, opts.boot });
            }
            if (opts.param == .v1) for (0..A.n_role) |r| for (r..A.n_role) |q| {
                const ga = A.enemyGroup(r, q);
                const gb = A.enemyGroup(q, r);
                if (p.param_start[ga + 1] == p.param_start[ga] or p.param_start[gb + 1] == p.param_start[gb]) continue;
                const sd = @sqrt(cal.sigma2[ga]) + @sqrt(cal.sigma2[gb]);
                try w.print("  matchup {s}-{s}{s} sd {d:.2} {s}\n", .{ A.role_names[r], A.role_names[q], "               "[0 .. 15 - @min(15, A.role_names[r].len + A.role_names[q].len)], sd * to_unit, if (in_gold) "gold" else "pp" });
            };
        }
        // Comp: the damage mix, per sd of the blue-minus-red term
        var s: f64 = 0;
        var s2: f64 = 0;
        for (games) |g| {
            s += g.cont[0];
            s2 += g.cont[0] * g.cont[0];
        }
        const n: f64 = @floatFromInt(games.len);
        const sdx = @sqrt(@max(s2 / n - (s / n) * (s / n), 0));
        const j = A.n_platforms;
        {
            // Diagnostic: the mix term alone (one-variable logistic on the fit games)
            const xs = try arena.alloc(f32, games.len);
            const ys = try arena.alloc(f32, games.len);
            for (games, xs, ys) |g, *x, *y| {
                x.* = g.cont[0];
                y.* = g.y;
            }
            if (target == .win) {
                const one = goldSlope(xs, ys);
                try w.print("  damage mix alone: {d:.2} +- {d:.2} pp per sd (sd of the term {d:.4}, mean |term| {d:.4})\n", .{ one[1] * sdx * 25, 1.96 * one[2] * sdx * 25, sdx, meanAbs(xs) });
            }
        }
        try w.print("  damage mix, per sd of blue minus red: {d:.2} +- {d:.2} {s}\n", .{ f.theta[j] * sdx * to_unit, 1.96 / @sqrt(f.h[j]) * sdx * to_unit, if (in_gold) "gold" else "pp" });
        try cw.interface.print("{s}\tdamage mix (per sd)\t\t\t\t{d:.5}\t{d:.5}\t{d:.5}\t{d:.3}\t\t\t\n", .{ outcome, f.theta[j] * sdx, (f.theta[j] - 1.96 / @sqrt(f.h[j])) * sdx, (f.theta[j] + 1.96 / @sqrt(f.h[j])) * sdx, f.theta[j] * sdx * to_pp });
        if (in_gold) try w.print("  residual sd {d:.0} gold; gold slope {d:.3} logit per 1000\n", .{ @sqrt(f.noise) * 1000, slope });
        try w.flush();
    }
    try cw.interface.flush();
    try lw.interface.flush();
}

// ---------------------------------------------------------------- main

fn parseOptions(arena: std.mem.Allocator, args: []const []const u8) !Options {
    var o: Options = .{};
    var i: usize = 0;
    while (i < args.len) : (i += 2) {
        if (i + 1 >= args.len) return error.MissingValue;
        const k = args[i];
        const v = args[i + 1];
        if (std.mem.eql(u8, k, "--out")) {
            o.out = v;
        } else if (std.mem.eql(u8, k, "--blocks")) {
            var out: std.ArrayList(Block) = .empty;
            var it = std.mem.tokenizeScalar(u8, v, ',');
            while (it.next()) |b| {
                if (std.mem.eql(u8, b, "none")) continue;
                const blk: Block = if (std.mem.eql(u8, b, "dev")) .dev else switch (try std.fmt.parseInt(u8, b, 10)) {
                    1 => .f1,
                    2 => .f2,
                    3 => .f3,
                    4 => .f4,
                    5 => .f5,
                    else => return error.BadBlock,
                };
                try out.append(arena, blk);
            }
            o.blocks = out.items;
        } else if (std.mem.eql(u8, k, "--null")) {
            o.null = try std.fmt.parseInt(u32, v, 10);
        } else if (std.mem.eql(u8, k, "--boot")) {
            o.boot = try std.fmt.parseInt(u32, v, 10);
        } else if (std.mem.eql(u8, k, "--drop")) {
            o.drop = std.mem.eql(u8, v, "1");
        } else if (std.mem.eql(u8, k, "--threads")) {
            o.threads = @max(1, try std.fmt.parseInt(u32, v, 10));
        } else if (std.mem.eql(u8, k, "--soft")) {
            o.soft = v;
        } else if (std.mem.eql(u8, k, "--shuffle")) {
            o.shuffle = try std.fmt.parseInt(u64, v, 10);
        } else if (std.mem.eql(u8, k, "--resample")) {
            o.resample = try std.fmt.parseInt(u32, v, 10);
        } else if (std.mem.eql(u8, k, "--param")) {
            o.param = std.meta.stringToEnum(Param, v) orelse return error.BadParam;
        } else if (std.mem.eql(u8, k, "--calibrate")) {
            o.calibrate = try std.fmt.parseInt(u32, v, 10);
        } else if (std.mem.eql(u8, k, "--alpha")) {
            o.alpha = try std.fmt.parseFloat(f32, v);
        } else return error.UnknownOption;
    }
    return o;
}

pub fn main(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: Io, argv: []const []const u8) !u8 {
    if (argv.len < 1) {
        std.debug.print("usage:\n{s}", .{usage});
        return 2;
    }
    const opts = parseOptions(arena, argv[1..]) catch |e| {
        std.debug.print("effects: {s}\nusage:\n{s}", .{ @errorName(e), usage });
        return 2;
    };
    const snap = argv[0];
    var legendaries = try rows.loadLegendaries(gpa, io, snap);
    defer legendaries.deinit(gpa);
    var data = try rows.load(gpa, snap, &legendaries);
    defer data.deinit();
    if (!anyStats(&data)) return error.NoSeatStats;
    const players = try harness.gamePlayers(gpa, &data);
    defer gpa.free(players);
    std.debug.assert(protocol.platformIds().len <= A.n_platforms);
    const c = try harness.cuts(gpa, &data);
    const in = try inputs(arena, &data);
    if (opts.shuffle) |seed| {
        var rng: std.Random.DefaultPrng = .init(seed);
        const r = rng.random();
        var i = in.win.len;
        while (i > 1) {
            i -= 1;
            const j = r.uintLessThan(usize, i + 1);
            std.mem.swap(f32, &in.win[i], &in.win[j]);
            std.mem.swap(f32, &in.gold[i], &in.gold[j]);
        }
    }
    var soft: ?Soft = if (opts.soft) |s| try Soft.load(gpa, arena, io, s) else null;
    defer if (soft) |*s| s.map.deinit(gpa);

    try Io.Dir.cwd().createDirPath(io, opts.out);
    var dir = try Io.Dir.cwd().openDir(io, opts.out, .{});
    defer dir.close(io);
    var folds_file = try dir.createFile(io, "folds.tsv", .{});
    defer folds_file.close(io);
    var fbuf: [16 * 1024]u8 = undefined;
    var fw = folds_file.writer(io, &fbuf);
    try fw.interface.print("block\tmodel\tfit_games\tscored\tloss\t{s}_loss\tdiff\tse\n", .{cand_name});
    var files: Files = .{ .arena = arena, .dir = dir, .folds = &fw.interface };
    var out_buf: [4096]u8 = undefined;
    var stdout = Io.File.stdout().writer(io, &out_buf);
    const w = &stdout.interface;
    try w.print("# effects vs {s}: blocks {any}, drop {}, half-samples {d}, soft {s} alpha {d}, shuffle {?d}, resample {?d}, calibrate {d}, param {s}\n\n", .{ cand_name, opts.blocks, opts.drop, opts.boot, opts.soft orelse "-", opts.alpha, opts.shuffle, opts.resample, opts.calibrate, @tagName(opts.param) });
    if (opts.shuffle != null) try w.writeAll("SHUFFLED LABELS: a control, every gain and sd must be ~0 (the candidate fits the real labels: its rows' y)\n\n");
    try w.flush();

    const ms = try models(arena, opts.param);
    var tasks: std.ArrayList(Task) = .empty;
    for (ms) |m| try tasks.append(arena, .{ .model = m, .label = m.name });
    if (soft != null) {
        var logit = ms[full_model];
        logit.target = .logit;
        var mixed = ms[full_model];
        mixed.target = .mix;
        try tasks.append(arena, .{ .model = logit, .label = "student-logit" });
        try tasks.append(arena, .{ .model = mixed, .label = "student-mix" });
    }
    if (opts.drop) {
        var nbuf: [64]u8 = undefined;
        for (1..A.n_groups) |g| {
            const label = try arena.print("full-without-{s}", .{A.groupName(&nbuf, g)});
            for (label) |*ch| if (ch.* == ' ') {
                ch.* = '_';
            };
            try tasks.append(arena, .{ .model = ms[full_model], .without = g, .label = label });
        }
    }
    if (opts.calibrate > 0) try tasks.append(arena, .{ .model = ms[full_model], .calibrate = true, .label = "full-cal" });

    var pooled: Pooled = .{};
    defer pooled.deinit(gpa);
    for (opts.blocks) |b| {
        const spec: Spec = switch (b) {
            .dev => .{ .before = c.dev, .lo = c.dev, .hi = c.test_, .dev = true, .resample = opts.resample },
            else => blk: {
                const f = c.fold(@backingInt(b));
                break :blk .{ .before = f.lo, .lo = f.lo, .hi = f.hi, .dev = false, .resample = opts.resample };
            },
        };
        var block_arena: std.heap.ArenaAllocator = .init(gpa);
        defer block_arena.deinit();
        try runBlock(gpa, block_arena.allocator(), io, &data, players, in, c, spec, b, tasks.items, if (soft) |*s| s else null, opts, &files, &pooled, w);
    }
    if (pooled.y.items.len > 0) {
        try w.print("\nfolds pooled ({d} games), vs {s} (negative is better):\n", .{ pooled.y.items.len, cand_name });
        const n: f64 = @floatFromInt(pooled.y.items.len);
        for (tasks.items, pooled.preds) |t, x| {
            var s: f64 = 0;
            var s2: f64 = 0;
            for (pooled.y.items, pooled.ref.items, x.items) |y, a, b| {
                const v = loss1(y, b) - loss1(y, a);
                s += v;
                s2 += v * v;
            }
            const mean = s / n;
            const se = @sqrt(@max(s2 / n - mean * mean, 0) / @max(n - 1, 1));
            try w.print("  {s:<40} {d:.5} +- {d:.5}\n", .{ t.label, mean, 1.96 * se });
            try fw.interface.print("folds\t{s}\t\t{d}\t\t\t{d:.6}\t{d:.6}\n", .{ t.label, pooled.y.items.len, mean, se });
        }
        // Between variants: each vs mains; each drop-one vs full
        try w.print("\nfolds pooled, paired between variants (folds of 5 better):\n", .{});
        for (tasks.items, pooled.preds, 0..) |t, x, ti| {
            if (ti == 0) continue;
            const base: usize = if (t.without != 0 or t.calibrate) full_model else 0;
            const g = pairedFolds(pooled, pooled.preds[base].items, x.items);
            try w.print("  {s:<40} vs {s:<5} {d:.5} +- {d:.5}  better in {d} of 5\n", .{ t.label, tasks.items[base].label, g.mean, 1.96 * g.se, g.better });
            try fw.interface.print("folds\t{s} vs {s}\t\t{d}\t\t\t{d:.6}\t{d:.6}\n", .{ t.label, tasks.items[base].label, pooled.y.items.len, g.mean, g.se });
        }
    }
    try fw.interface.flush();
    try files.close(io);
    try w.flush();
    try components(gpa, arena, io, &data, in, c, opts, if (soft) |*s| s else null, dir, w);
    try w.flush();
    return 0;
}

fn meanAbs(xs: []const f32) f64 {
    var s: f64 = 0;
    for (xs) |x| s += @abs(x);
    return s / @as(f64, @floatFromInt(@max(xs.len, 1)));
}

fn anyStats(d: *const rows.Data) bool {
    for (d.rows) |r| if (!std.math.isNan(r.stats[0])) return true;
    return false;
}

test {
    _ = additive;
    _ = addinputs;
}

test "effects options: resample" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const o = try parseOptions(arena.allocator(), &.{ "--resample", "2", "--blocks", "1" });
    try std.testing.expectEqual(@as(?u32, 2), o.resample);
    try std.testing.expectEqual(null, (try parseOptions(arena.allocator(), &.{})).resample);
}

test "effects matchup spread: a same-role block twice, a crossed pair summed" {
    var s2: [A.n_groups]f64 = @splat(0);
    s2[A.enemyGroup(0, 0)] = 0.01;
    s2[A.enemyGroup(3, 4)] = 0.04;
    s2[A.enemyGroup(4, 3)] = 0.01;
    try std.testing.expectApproxEqAbs(0.2, (Pick{ .a = A.enemyGroup(0, 0), .b = A.enemyGroup(0, 0) }).of(s2), 1e-12);
    try std.testing.expectApproxEqAbs(0.3, (Pick{ .a = A.enemyGroup(3, 4), .b = A.enemyGroup(4, 3) }).of(s2), 1e-12);
    try std.testing.expectApproxEqAbs(0.2, (Pick{ .a = A.enemyGroup(3, 4) }).of(s2), 1e-12);
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    // Halves 0.1 and 0.3 around 0.2: se = 0.1 * sqrt(2) / sqrt(2) = 0.1
    var b: [2][A.n_groups]f64 = .{ s2, s2 };
    b[0][A.enemyGroup(3, 4)] = 0.01;
    b[1][A.enemyGroup(3, 4)] = 0.09;
    const sm = try summarise(arena.allocator(), .{ .a = A.enemyGroup(3, 4) }, s2, &b, &.{});
    try std.testing.expectApproxEqAbs(0.2, sm.sd, 1e-12);
    try std.testing.expectApproxEqAbs(0.2 + 1.96 * 0.1, sm.hi, 1e-9);
}
