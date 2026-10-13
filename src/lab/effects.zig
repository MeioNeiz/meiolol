//! `meiolol-lab effects SNAP`: the shrunk additive draft model (lab/additive.zig) on
//! netcheck's blocks (dev-val and win-comp's 5 forward folds, every fit from the block's
//! fit games only), paired per game with the -Dcand candidate (win-ratings) fitted on the
//! same games. Variants nest families of terms, so each family's held-out gain shows;
//! --drop 1 also refits the full model without each block in turn. Then the full model on
//! every dev-visible game: per block the spread of true effects (sd, bootstrap over games)
//! and the clearest single cells. Outcomes: win, and blue-minus-red team gold at 14
//! (gaussian), turned into win through a logistic slope on the fit games' real gold
//! difference. --soft FILE: distillation, the fit target is alpha * outcome + (1 - alpha)
//! * the teacher's cross-fitted chance (FILE: match_id, block, seed, p_blue).
//! Writes DIR/folds.tsv, DIR/games-<model>.tsv (pairable, netcheck's format),
//! DIR/components.tsv, DIR/cells.tsv

const std = @import("std");
const api = @import("api");
const cand = @import("cand");
const rows = @import("rows.zig");
const protocol = @import("protocol.zig");
const harness = @import("harness.zig");
const seatstats = @import("seatstats.zig");
const additive = @import("additive.zig");
const par = @import("../par.zig");

const Io = std.Io;
const A = additive;

pub const usage =
    \\  effects SNAP [--out DIR] [--blocks dev,1,2,3,4,5] [--boot N] [--drop 0|1]
    \\                                  [--threads N] [--soft FILE --alpha X]
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
    drop: bool = false,
    threads: u32 = 10,
    soft: ?[]const u8 = null,
    alpha: f32 = 0.5,
};

const Block = enum { dev, f1, f2, f3, f4, f5 };
const n_folds = 5;

/// Fit on dev-visible games before `before`; score dev-val (dev) or dev-visible games in
/// [lo, hi): netcheck's blocks (winnet.zig Spec), so games pair with its preds
const Spec = struct {
    before: i64,
    lo: i64,
    hi: i64,
    dev: bool,

    fn fits(s: Spec, c: harness.Cuts, g: rows.Game) bool {
        return harness.visible(.dev, c, g) and g.start < s.before;
    }

    fn scores(s: Spec, c: harness.Cuts, g: rows.Game) bool {
        if (s.dev) return harness.scored(.dev, c, g);
        return harness.visible(.dev, c, g) and g.start >= s.lo and g.start < s.hi;
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

fn quantile(xs: []const i64, x: f64) i64 {
    if (x >= 1) return std.math.maxInt(i64);
    return xs[@intFromFloat(@as(f64, @floatFromInt(xs.len)) * x)];
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
    kind: A.Kind = .logistic,
};

fn lanePair(r: usize, q: usize) bool {
    return r == q or (r == 3 and q == 4) or (r == 4 and q == 3);
}

fn models(arena: std.mem.Allocator) ![]Model {
    const mains = A.Variant.mains();
    var mix = mains;
    mix.cont = 1;
    var ally = mix;
    for (0..A.n_role) |r| for (r + 1..A.n_role) |q| {
        ally = ally.with(A.allyGroup(r, q));
    };
    var lane = mix;
    var enemy = mix;
    for (0..A.n_role) |r| for (0..A.n_role) |q| {
        if (lanePair(r, q)) lane = lane.with(A.enemyGroup(r, q));
        enemy = enemy.with(A.enemyGroup(r, q));
    };
    var full = A.Variant.all();
    full.cont = 1;
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
        .{ .name = "gold", .variant = full, .kind = .gaussian },
    });
    return out.toOwnedSlice(arena);
}

const full_model = 5;

// ---------------------------------------------------------------- damage mix (win-comp)

/// win-comp's mix term (cand/win-comp teamForms): per champion-role, magic share of
/// champion damage and damage per minute, means over won and lost rows separately, each
/// shrunk to the role mean by `pseudo` rows, profile = the halves' average; a team's
/// damage-weighted magic share frac, mix = (frac - 0.5)^2. Fit games see their own rows
/// left out
const Mix = struct {
    const pseudo = 20;
    /// key -> [half][feature][sum, n]
    acc: std.AutoHashMapUnmanaged(u64, [2][2][2]f64) = .empty,
    role_mean: [A.n_role][2]f64 = @splat(@splat(0)),

    fn key(champion: u32, role: usize) u64 {
        return @as(u64, champion) << 3 | role;
    }

    /// Magic share and damage per minute of one row, NaN when unknown
    fn values(s: *const seatstats.Stats) [2]f32 {
        const at = struct {
            fn f(st: *const seatstats.Stats, x: seatstats.SeatStat) f32 {
                return st[@backingInt(x)];
            }
        }.f;
        const dealt = at(s, .dmg_phys) + at(s, .dmg_magic) + at(s, .dmg_true);
        const mins = at(s, .minutes);
        const nan = std.math.nan(f32);
        return .{
            if (dealt > 0) at(s, .dmg_magic) / dealt else nan,
            if (mins > 0) dealt / mins else nan,
        };
    }

    fn init(gpa: std.mem.Allocator, d: *const rows.Data, fit: []const bool) !Mix {
        var m: Mix = .{};
        var role_acc: [A.n_role][2][2]f64 = @splat(@splat(@splat(0)));
        for (d.rows) |r| {
            if (!fit[r.game]) continue;
            const y = r.y[api.outcomeIndex(.win)];
            if (std.math.isNan(y)) continue;
            const v = values(&r.stats);
            const role: usize = @backingInt(r.role);
            const e = try m.acc.getOrPutValue(gpa, key(r.champion, role), @splat(@splat(@splat(0))));
            const half: usize = @intFromBool(y > 0.5);
            for (0..2) |f| {
                if (std.math.isNan(v[f]) or std.math.isInf(v[f])) continue;
                e.value_ptr[half][f][0] += v[f];
                e.value_ptr[half][f][1] += 1;
                role_acc[role][f][0] += v[f];
                role_acc[role][f][1] += 1;
            }
        }
        for (&m.role_mean, role_acc) |*rm, ra| for (rm, ra) |*x, a| {
            x.* = if (a[1] > 0) a[0] / a[1] else 0;
        };
        return m;
    }

    fn deinit(m: *Mix, gpa: std.mem.Allocator) void {
        m.acc.deinit(gpa);
    }

    /// Profile of a champion-role; own: the row to leave out (a fit game's), else null
    fn profile(m: *const Mix, champion: u32, role: usize, own: ?*const rows.Row) [2]f64 {
        const rm = m.role_mean[role];
        const a = m.acc.get(key(champion, role)) orelse return rm;
        var drop: [2][2]f64 = @splat(@splat(0));
        var drop_n: [2][2]f64 = @splat(@splat(0));
        if (own) |r| {
            const y = r.y[api.outcomeIndex(.win)];
            if (!std.math.isNan(y)) {
                const v = values(&r.stats);
                const half: usize = @intFromBool(y > 0.5);
                for (0..2) |f| if (!std.math.isNan(v[f]) and !std.math.isInf(v[f])) {
                    drop[half][f] = v[f];
                    drop_n[half][f] = 1;
                };
            }
        }
        var out: [2]f64 = undefined;
        for (0..2) |f| {
            var v: f64 = 0;
            for (0..2) |h| v += 0.5 * (a[h][f][0] - drop[h][f] + pseudo * rm[f]) / (a[h][f][1] - drop_n[h][f] + pseudo);
            out[f] = v;
        }
        return out;
    }

    /// Blue's mix minus red's for game gi; leave_out: the game is a fit game
    fn diff(m: *const Mix, d: *const rows.Data, first_row: []const u32, gi: usize, leave_out: bool) f32 {
        var num: [2]f64 = @splat(0);
        var den: [2]f64 = @splat(0);
        for (d.rows[first_row[gi]..first_row[gi + 1]]) |*r| {
            const p = m.profile(r.champion, @backingInt(r.role), if (leave_out) r else null);
            num[r.side] += p[1] * p[0];
            den[r.side] += p[1];
        }
        var mix: [2]f64 = undefined;
        for (0..2) |s| {
            const frac = if (den[s] > 0) num[s] / den[s] else 0.5;
            mix[s] = (frac - 0.5) * (frac - 0.5);
        }
        return @floatCast(mix[0] - mix[1]);
    }
};

// ---------------------------------------------------------------- inputs

const Inputs = struct {
    win: []f32,
    /// Blue minus red team gold at 14, thousands; NaN unless all ten are known
    gold: []f32,
    first_row: []u32,
};

fn inputs(gpa: std.mem.Allocator, d: *const rows.Data) !Inputs {
    const win = try gpa.alloc(f32, d.games.len);
    const gold = try gpa.alloc(f32, d.games.len);
    const first_row = try gpa.alloc(u32, d.games.len + 1);
    @memset(gold, 0);
    for (d.games, win) |g, *w| w.* = if (g.winner == 0) 1 else 0;
    var seen = try gpa.alloc(u8, d.games.len);
    defer gpa.free(seen);
    @memset(seen, 0);
    var at: u32 = 0;
    var gi: usize = 0;
    first_row[0] = 0;
    for (d.rows, 0..) |r, i| {
        while (gi < r.game) : (gi += 1) first_row[gi + 1] = @intCast(i);
        std.debug.assert(r.game >= gi);
        const y = r.y[api.outcomeIndex(.gold14)];
        gold[r.game] += if (r.side == 0) y / 1000 else -y / 1000;
        seen[r.game] += 1;
        at = @intCast(i + 1);
    }
    while (gi < d.games.len) : (gi += 1) first_row[gi + 1] = at;
    for (gold, seen) |*g, n| if (n != 10) {
        g.* = std.math.nan(f32);
    };
    return .{ .win = win, .gold = gold, .first_row = first_row };
}

fn gameIn(d: *const rows.Data, gi: usize, y: f32, mix: f32) A.GameIn {
    const g = d.games[gi];
    return .{ .teams = g.teams, .platform = g.platform, .y = y, .cont = .{ mix, 0, 0, 0 } };
}

// ---------------------------------------------------------------- teacher (--soft)

/// Teacher's cross-fitted chance per (block, match id), mean over seeds
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
            const p = std.fmt.parseFloat(f64, f.next() orelse continue) catch continue;
            const k = try std.mem.concat(arena, u8, &.{ block, "\t", id });
            const e = try s.map.getOrPutValue(gpa, k, .{ 0, 0 });
            e.value_ptr[0] += p;
            e.value_ptr[1] += 1;
        }
        return s;
    }

    fn get(s: *const Soft, buf: []u8, block: []const u8, id: []const u8) ?f64 {
        const k = std.fmt.bufPrint(buf, "{s}\t{s}", .{ block, id }) catch return null;
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
    soft: bool = false,
    label: []const u8,
};

const Result = struct { pred: []f64 = &.{} };

/// Logit of blue's win per unit of gold difference at 14 (thousands), from the fit
/// games' real gold: what a predicted gold edge is worth (one-variable logistic)
fn goldSlope(gold: []const f32, win: []const f32) [2]f64 {
    var b0: f64 = 0;
    var b1: f64 = 0;
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
        b0 += (h11 * g0 - h01 * g1) / det;
        b1 += (h00 * g1 - h01 * g0) / det;
    }
    return .{ b0, b1 };
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
    var mix = try Mix.init(gpa, d, is_fit);
    defer mix.deinit(gpa);

    // Fit games per target: win, soft win, gold (known gold only)
    const fit_win = try arena.alloc(A.GameIn, fit_idx.items.len);
    const fit_soft = try arena.alloc(A.GameIn, fit_idx.items.len);
    var fit_gold: std.ArrayList(A.GameIn) = .empty;
    const fit_goldv = try arena.alloc(f32, fit_idx.items.len);
    var n_soft: usize = 0;
    var kbuf: [128]u8 = undefined;
    for (fit_idx.items, fit_win, fit_soft, fit_goldv) |gi, *fw, *fs, *gv| {
        const m = mix.diff(d, in.first_row, gi, true);
        fw.* = gameIn(d, gi, in.win[gi], m);
        fs.* = fw.*;
        if (soft) |s| if (s.get(&kbuf, blockName(block), d.games[gi].match_id)) |p| {
            fs.y = @floatCast(opts.alpha * in.win[gi] + (1 - opts.alpha) * p);
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
    for (scored.items, scored_in) |gi, *s| s.* = gameIn(d, gi, in.win[gi], mix.diff(d, in.first_row, gi, false));
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
        tasks: []const Task,
        results: []Result,
        fit_win: []const A.GameIn,
        fit_soft: []const A.GameIn,
        fit_gold: []const A.GameIn,
        scored: []const A.GameIn,
        slope: [2]f64,
        fn one(x: @This(), i: usize) !void {
            const t = x.tasks[i];
            var v = t.model.variant;
            if (t.without != 0) v.groups &= ~(@as(u64, 1) << @intCast(t.without));
            const games = if (t.model.kind == .gaussian) x.fit_gold else if (t.soft) x.fit_soft else x.fit_win;
            var p = try A.build(x.gpa, t.model.kind, v, games);
            defer p.deinit(x.gpa);
            var f = try A.fit(x.gpa, &p, .{}, null, null);
            defer f.deinit(x.gpa);
            const pred = try x.gpa.alloc(f64, x.scored.len);
            for (x.scored, pred) |*g, *o| {
                const e = A.predict(&p, &f, g);
                o.* = switch (t.model.kind) {
                    .logistic => sigmoid(e),
                    // Predicted gold edge -> win through the fit games' gold slope; the
                    // side term is in the gold model's platform intercept already
                    .gaussian => sigmoid(x.slope[0] + x.slope[1] * e),
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
            .tasks = tasks[at..][0..n],
            .results = results[at..][0..n],
            .fit_win = fit_win,
            .fit_soft = fit_soft,
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
    }
    try w.flush();
    try files.folds.flush();

    const gw = try files.gamesFor(arena, io, cand_name);
    for (scored.items, pc) |gi, p| try gw.print("{s}\t0\twin\t{d}\t{d:.6}\t{s}\n", .{ d.games[gi].match_id, in.win[gi], p, name });
    for (tasks, results) |t, r| {
        const tw = try files.gamesFor(arena, io, t.label);
        for (scored.items, r.pred) |gi, p| try tw.print("{s}\t0\twin\t{d}\t{d:.6}\t{s}\n", .{ d.games[gi].match_id, in.win[gi], p, name });
    }
    if (block != .dev) {
        for (scored.items, pc) |gi, p| {
            try pooled.y.append(gpa, in.win[gi]);
            try pooled.ref.append(gpa, p);
        }
        if (pooled.preds.len == 0) {
            pooled.preds = try arena.alloc(std.ArrayList(f64), tasks.len);
            for (pooled.preds) |*x| x.* = .empty;
        }
        for (pooled.preds, results) |*x, r| try x.appendSlice(gpa, r.pred);
    }
}

const Pooled = struct {
    y: std.ArrayList(f32) = .empty,
    ref: std.ArrayList(f64) = .empty,
    preds: []std.ArrayList(f64) = &.{},

    fn deinit(p: *Pooled, gpa: std.mem.Allocator) void {
        p.y.deinit(gpa);
        p.ref.deinit(gpa);
        for (p.preds) |*x| x.deinit(gpa);
    }
};

const cand_name: []const u8 = if (@hasDecl(cand, "name")) cand.name else "cand";

const Files = struct {
    dir: Io.Dir,
    folds: *Io.Writer,
    games: std.StringHashMapUnmanaged(*Io.File.Writer) = .empty,

    fn gamesFor(f: *Files, arena: std.mem.Allocator, io: Io, label: []const u8) !*Io.Writer {
        if (f.games.get(label)) |x| return &x.interface;
        const file = try f.dir.createFile(io, try std.fmt.allocPrint(arena, "games-{s}.tsv", .{label}), .{});
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
/// bootstrap interval (Poisson game weights, warm-started refits), and single cells
fn components(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: Io, d: *const rows.Data, in: Inputs, c: harness.Cuts, opts: Options, dir: Io.Dir, w: *Io.Writer) !void {
    const is_fit = try gpa.alloc(bool, d.games.len);
    defer gpa.free(is_fit);
    var idx: std.ArrayList(u32) = .empty;
    defer idx.deinit(gpa);
    for (d.games, is_fit, 0..) |g, *f, i| {
        f.* = harness.visible(.dev, c, g);
        if (f.*) try idx.append(gpa, @intCast(i));
    }
    var mix = try Mix.init(gpa, d, is_fit);
    defer mix.deinit(gpa);
    var win_games: std.ArrayList(A.GameIn) = .empty;
    var gold_games: std.ArrayList(A.GameIn) = .empty;
    var goldv: std.ArrayList(f32) = .empty;
    var winv: std.ArrayList(f32) = .empty;
    for (idx.items) |gi| {
        const m = mix.diff(d, in.first_row, gi, true);
        try win_games.append(arena, gameIn(d, gi, in.win[gi], m));
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
    try cw.interface.writeAll("outcome\tblock\tcells\tgames_per_cell\teff_params\tsd\tsd_lo\tsd_hi\tsd_pp\tsd_pp_lo\tsd_pp_hi\tboot\n");
    var lf = try dir.createFile(io, "cells.tsv", .{});
    defer lf.close(io);
    var lbuf: [16 * 1024]u8 = undefined;
    var lw = lf.writer(io, &lbuf);
    try lw.interface.writeAll("outcome\tblock\tchampion_a\tchampion_b\tgames\teffect\tci\tunit\n");

    var full = A.Variant.all();
    full.cont = 1;
    for ([_]A.Kind{ .logistic, .gaussian }) |kind| {
        const games = if (kind == .logistic) win_games.items else gold_games.items;
        var p = try A.build(gpa, kind, full, games);
        defer p.deinit(gpa);
        var f = try A.fit(gpa, &p, .{}, null, null);
        defer f.deinit(gpa);
        const outcome = if (kind == .logistic) "win" else "gold14";
        // Bootstrap: Poisson(1) weights per game, each rep warm-started from f
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
                for (ws) |*v| v.* = @floatFromInt(poisson1(rng.random()));
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
        // Effects in win pp at 50% (logit x 25); gold in gold
        const to_unit: f64 = if (kind == .logistic) 25 else 1000;
        const to_pp: f64 = if (kind == .logistic) 25 else 25 * slope;
        var nbuf: [64]u8 = undefined;
        try w.print("\n{s}: per block sd of true effects ({s}), 95% bootstrap ({d} reps)\n", .{ outcome, if (kind == .logistic) "win pp" else "gold", opts.boot });
        for (1..A.n_groups) |g| {
            const n_cells = p.param_start[g + 1] - p.param_start[g];
            if (n_cells == 0) continue;
            var games_in: u64 = 0;
            for (p.param_start[g]..p.param_start[g + 1]) |j| games_in += p.count[j];
            const sds = try arena.alloc(f64, opts.boot);
            for (boots, sds) |b, *s| s.* = @sqrt(b[g]);
            std.mem.sort(f64, sds, {}, std.sort.asc(f64));
            const lo = if (opts.boot > 0) sds[@intFromFloat(@as(f64, @floatFromInt(opts.boot)) * 0.025)] else std.math.nan(f64);
            const hi = if (opts.boot > 0) sds[@min(opts.boot - 1, @as(usize, @intFromFloat(@as(f64, @floatFromInt(opts.boot)) * 0.975)))] else std.math.nan(f64);
            const sd = @sqrt(f.sigma2[g]);
            const label = A.groupName(&nbuf, g);
            try cw.interface.print("{s}\t{s}\t{d}\t{d:.1}\t{d:.1}\t{d:.5}\t{d:.5}\t{d:.5}\t{d:.3}\t{d:.3}\t{d:.3}\t{d}\n", .{
                outcome,    label,      n_cells,    @as(f64, @floatFromInt(games_in)) / @as(f64, @floatFromInt(n_cells)),
                f.gamma[g], sd,         lo,         hi,
                sd * to_pp, lo * to_pp, hi * to_pp, opts.boot,
            });
            try w.print("  {s:<26} {d:>6} cells  sd {d:.2} [{d:.2}, {d:.2}] {s}\n", .{ label, n_cells, sd * to_unit, lo * to_unit, hi * to_unit, if (kind == .logistic) "pp" else "gold" });
            // Single cells whose posterior interval clears 0 (pair blocks only)
            if (g < A.g_ally) continue;
            for (p.param_start[g]..p.param_start[g + 1]) |j| {
                const half = 1.96 / @sqrt(f.h[j]);
                if (@abs(f.theta[j]) <= half) continue;
                const cl = A.cellOf(&p, j);
                try lw.interface.print("{s}\t{s}\t#{d}\t#{d}\t{d}\t{d:.3}\t{d:.3}\t{s}\n", .{ outcome, label, cl.a, cl.b, p.count[j], f.theta[j] * to_unit, half * to_unit, if (kind == .logistic) "pp" else "gold" });
            }
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
        try w.print("  damage mix, per sd of blue minus red: {d:.2} +- {d:.2} {s}\n", .{ f.theta[j] * sdx * to_unit, 1.96 / @sqrt(f.h[j]) * sdx * to_unit, if (kind == .logistic) "pp" else "gold" });
        try cw.interface.print("{s}\tdamage mix (per sd)\t\t\t\t{d:.5}\t{d:.5}\t{d:.5}\t{d:.3}\t\t\t\n", .{ outcome, f.theta[j] * sdx, (f.theta[j] - 1.96 / @sqrt(f.h[j])) * sdx, (f.theta[j] + 1.96 / @sqrt(f.h[j])) * sdx, f.theta[j] * sdx * to_pp });
        if (kind == .gaussian) try w.print("  residual sd {d:.0} gold; gold slope {d:.3} logit per 1000\n", .{ @sqrt(f.noise) * 1000, slope });
        try w.flush();
    }
    try cw.interface.flush();
    try lw.interface.flush();
}

/// Knuth's method; mean 1
fn poisson1(r: std.Random) u32 {
    const l = @exp(-1.0);
    var k: u32 = 0;
    var p: f64 = 1;
    while (true) {
        p *= r.float(f64);
        if (p <= l) return k;
        k += 1;
    }
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
        } else if (std.mem.eql(u8, k, "--boot")) {
            o.boot = try std.fmt.parseInt(u32, v, 10);
        } else if (std.mem.eql(u8, k, "--drop")) {
            o.drop = std.mem.eql(u8, v, "1");
        } else if (std.mem.eql(u8, k, "--threads")) {
            o.threads = @max(1, try std.fmt.parseInt(u32, v, 10));
        } else if (std.mem.eql(u8, k, "--soft")) {
            o.soft = v;
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
    const ids = protocol.platformIds();
    std.debug.assert(ids.len <= A.n_platforms);
    const eu: u8 = for (ids, 0..) |id, i| {
        if (std.mem.eql(u8, id, protocol.test_platform)) break @intCast(i);
    } else return error.TestPlatformNotScanned;
    const c = try harness.cuts(gpa, &data, eu);
    const in = try inputs(arena, &data);
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
    var files: Files = .{ .dir = dir, .folds = &fw.interface };
    var out_buf: [4096]u8 = undefined;
    var stdout = Io.File.stdout().writer(io, &out_buf);
    const w = &stdout.interface;
    try w.print("# effects vs {s}: blocks {any}, drop {}, boot {d}, soft {s} alpha {d}\n\n", .{ cand_name, opts.blocks, opts.drop, opts.boot, opts.soft orelse "-", opts.alpha });
    try w.flush();

    const ms = try models(arena);
    var tasks: std.ArrayList(Task) = .empty;
    for (ms) |m| try tasks.append(arena, .{ .model = m, .label = m.name });
    if (soft != null) try tasks.append(arena, .{ .model = ms[full_model], .soft = true, .label = "full-soft" });
    if (opts.drop) {
        var nbuf: [64]u8 = undefined;
        for (1..A.n_groups) |g| {
            const label = try std.fmt.allocPrint(arena, "full-without-{s}", .{A.groupName(&nbuf, g)});
            for (label) |*ch| if (ch.* == ' ') {
                ch.* = '_';
            };
            try tasks.append(arena, .{ .model = ms[full_model], .without = g, .label = label });
        }
    }

    var starts: std.ArrayList(i64) = .empty;
    defer starts.deinit(gpa);
    for (data.games) |g| if (harness.visible(.dev, c, g)) try starts.append(gpa, g.start);
    std.mem.sort(i64, starts.items, {}, std.sort.asc(i64));
    var pooled: Pooled = .{};
    defer pooled.deinit(gpa);
    for (opts.blocks) |b| {
        const spec: Spec = switch (b) {
            .dev => .{ .before = c.dev, .lo = c.dev, .hi = c.select, .dev = true },
            else => blk: {
                const f: f64 = @floatFromInt(@backingInt(b) - 1);
                const k: f64 = n_folds;
                const lo = quantile(starts.items, 0.5 + 0.5 * f / k);
                const hi = @min(quantile(starts.items, 0.5 + 0.5 * (f + 1) / k), c.dev);
                break :blk .{ .before = lo, .lo = lo, .hi = hi, .dev = false };
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
    }
    try fw.interface.flush();
    try files.close(io);
    try w.flush();
    try components(gpa, arena, io, &data, in, c, opts, dir, w);
    try w.flush();
    return 0;
}

fn anyStats(d: *const rows.Data) bool {
    for (d.rows) |r| if (!std.math.isNan(r.stats[0])) return true;
    return false;
}

test {
    _ = additive;
}
