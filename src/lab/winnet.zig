//! `meiolol-lab netcheck SNAP`: neural nets for win from the draft, scored on the same
//! games as the compiled-in candidate (-Dcand, the reference: win-ratings or win-comp).
//! Blocks: dev-val (the harness's dev scoring) and win-comp's forward-chaining folds (the
//! newest half of dev's visible games in 5 blocks by start, every platform, each fitted on
//! the games before it; compcheck's bounds). Per block the candidate and the net are fitted
//! on the same games; everything the net learns (ids, epochs) comes from those games, early
//! stopping on their newest 10%, then a refit on all of them for a tenth more epochs.
//! Nets:
//!   big:   draftnet.zig as built (10 x 32 embeddings, MLP 320-512-256-1), GPU when there
//!   small: champion-role + role embeddings (emb), one hidden ReLU layer, dropout, AdamW
//!   resid: small with the candidate's logit as an offset, output weights from 0: it can
//!          only add what the candidate misses. The offset on fit games is the
//!          candidate's in-sample prediction; for early stopping, a candidate fitted on
//!          the games before the validation cut
//! All antisymmetric: logit = (f(blue, red) - f(red, blue)) / 2 + c[platform] (+ offset).
//! Writes DIR/folds.tsv (per seed and block, plus the seed-averaged `ens`) and
//! DIR/preds.tsv (per game); gains paired per game (= clustered by game)

const std = @import("std");
const api = @import("api");
const cand = @import("cand");
const rows = @import("rows.zig");
const protocol = @import("protocol.zig");
const harness = @import("harness.zig");
const draftnet = @import("draftnet.zig");
const par = @import("../par.zig");
const cuda = @import("../gpu/cuda.zig");
const dn = @import("../gpu/draftnet_layout.zig");

const Io = std.Io;

pub const usage =
    \\  netcheck SNAP --net big|small|resid [OPT VALUE]...
    \\                                  neural nets vs the -Dcand candidate on dev-val
    \\                                  and win-comp's 5 forward folds (lab/winnet.zig):
    \\                                  --emb N --hidden N --depth N --dropout X --wd X
    \\                                  --emb-wd X --lr X --clip X --batch N --evals N
    \\                                  --patience N --max-epochs N --min-games N
    \\                                  --seeds 1,2,3 --blocks dev,1,2,3,4,5
    \\                                  --fraction X (nested share of fit games)
    \\                                  --threads N --out DIR
    \\
;

pub const Kind = enum { big, small, resid };

pub const Options = struct {
    net: Kind = .small,
    emb: u32 = 16,
    hidden: u32 = 64,
    /// Hidden layers, 1..4
    depth: u32 = 1,
    dropout: f32 = 0.2,
    /// Decoupled (AdamW): each step shrinks weights by lr * wd
    wd: f32 = 0.1,
    /// Embeddings' decay; null: wd
    emb_wd: ?f32 = null,
    /// Global gradient norm cap per step; 0 off
    clip: f32 = 1,
    /// Validation evaluations per epoch (early stopping; nets overfit within 1-3 epochs)
    evals: u32 = 4,
    lr: f32 = 1e-3,
    batch: u32 = 512,
    patience: u32 = 5,
    max_epochs: u32 = 60,
    /// Champion-roles with fewer fit games share their role's embedding (big: draftnet's 30)
    min_games: u32 = 10,
    seeds: []const u32 = &.{1},
    blocks: []const Block = &.{ .dev, .f1, .f2, .f3, .f4, .f5 },
    fraction: f64 = 1,
    /// CPU threads for small and resid fits (one seed per thread) and big on the CPU
    threads: u32 = 3,
    out: []const u8 = ".",
};

pub const Block = enum { dev, f1, f2, f3, f4, f5 };
const n_folds = 5;
const val_share = 0.1;
const n_platforms = 16;

pub fn main(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: Io, argv: []const []const u8, ptx: [:0]const u8) !u8 {
    if (argv.len < 1) {
        std.debug.print("usage:\n{s}", .{usage});
        return 2;
    }
    const opts = parseOptions(arena, argv[1..]) catch |e| {
        std.debug.print("netcheck: {s}\nusage:\n{s}", .{ @errorName(e), usage });
        return 2;
    };
    var gpu: ?cuda.Gpu = null;
    if (opts.net == .big) gpu = cuda.Gpu.init(ptx) catch |e| blk: {
        std.debug.print("netcheck: no GPU ({s}), big net on {d} CPU threads\n", .{ @errorName(e), opts.threads });
        break :blk null;
    };

    const snap = argv[0];
    var legendaries = try rows.loadLegendaries(gpa, io, snap);
    defer legendaries.deinit(gpa);
    var data = try rows.load(gpa, snap, &legendaries);
    defer data.deinit();
    const players = try harness.gamePlayers(gpa, &data);
    defer gpa.free(players);
    const ids = protocol.platformIds();
    std.debug.assert(ids.len <= n_platforms);
    const eu: u8 = for (ids, 0..) |id, i| {
        if (std.mem.eql(u8, id, protocol.test_platform)) break @intCast(i);
    } else return error.TestPlatformNotScanned;
    const c = try harness.cuts(gpa, &data, eu);

    try Io.Dir.cwd().createDirPath(io, opts.out);
    var dir = try Io.Dir.cwd().openDir(io, opts.out, .{});
    defer dir.close(io);
    var folds_file = try dir.createFile(io, "folds.tsv", .{});
    defer folds_file.close(io);
    var fbuf: [16 * 1024]u8 = undefined;
    var fw = folds_file.writer(io, &fbuf);
    try fw.interface.writeAll("seed\tfold\tfit_games\tscored_games\tlogloss\tratings_logloss\tgain\tgain_se\tepochs\tseconds\tval_logloss\tauc\tratings_auc\n");
    var preds_file = try dir.createFile(io, "preds.tsv", .{});
    defer preds_file.close(io);
    var pbuf: [64 * 1024]u8 = undefined;
    var pw = preds_file.writer(io, &pbuf);
    try pw.interface.writeAll("fold\tmatch_id\tplatform\ty\tcand");
    for (opts.seeds) |s| try pw.interface.print("\tseed{d}", .{s});
    try pw.interface.writeAll("\tens\n");

    var out_buf: [4096]u8 = undefined;
    var stdout = Io.File.stdout().writer(io, &out_buf);
    const w = &stdout.interface;
    try w.print("# netcheck: {s} net vs {s}, fraction {d}, seeds {any}\n\n", .{ @tagName(opts.net), if (@hasDecl(cand, "name")) cand.name else "cand", opts.fraction, opts.seeds });
    try w.print("options: emb {d} hidden {d} depth {d} dropout {d} wd {d} emb_wd {d} lr {d} clip {d} batch {d} evals {d} patience {d} min_games {d}\n\n", .{
        opts.emb, opts.hidden, opts.depth, opts.dropout, opts.wd, opts.emb_wd orelse opts.wd, opts.lr, opts.clip, opts.batch, opts.evals, opts.patience, opts.min_games,
    });
    try w.flush();

    // Fold bounds: compcheck's (win-comp's foldAblation), over every dev-visible game
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
        try runBlock(gpa, io, &data, players, c, spec, b, opts, if (gpu) |*g| g else null, &fw.interface, &pw.interface, w, &pooled);
    }
    if (pooled.cand.items.len > 0) {
        try w.writeAll("\nfolds pooled (blocks 1-5 run here):\n");
        try summaryHead(w);
        try summaryRow(gpa, w, "folds", pooled.ys.items, pooled.cand.items, pooled.ens.items, null);
    }
    try fw.interface.flush();
    try pw.interface.flush();
    try w.flush();
    return 0;
}

fn parseOptions(arena: std.mem.Allocator, args: []const []const u8) !Options {
    var o: Options = .{};
    // Flags given, so big keeps draftnet's own defaults for the rest
    var set: std.StringHashMapUnmanaged(void) = .empty;
    var i: usize = 0;
    while (i < args.len) : (i += 2) {
        if (i + 1 >= args.len) return error.MissingValue;
        const k = args[i];
        const v = args[i + 1];
        try set.put(arena, k, {});
        if (std.mem.eql(u8, k, "--net")) {
            o.net = std.meta.stringToEnum(Kind, v) orelse return error.UnknownNet;
        } else if (std.mem.eql(u8, k, "--emb")) {
            o.emb = try std.fmt.parseInt(u32, v, 10);
        } else if (std.mem.eql(u8, k, "--hidden")) {
            o.hidden = try std.fmt.parseInt(u32, v, 10);
        } else if (std.mem.eql(u8, k, "--depth")) {
            o.depth = try std.fmt.parseInt(u32, v, 10);
        } else if (std.mem.eql(u8, k, "--emb-wd")) {
            o.emb_wd = try std.fmt.parseFloat(f32, v);
        } else if (std.mem.eql(u8, k, "--clip")) {
            o.clip = try std.fmt.parseFloat(f32, v);
        } else if (std.mem.eql(u8, k, "--evals")) {
            o.evals = try std.fmt.parseInt(u32, v, 10);
        } else if (std.mem.eql(u8, k, "--dropout")) {
            o.dropout = try std.fmt.parseFloat(f32, v);
        } else if (std.mem.eql(u8, k, "--wd")) {
            o.wd = try std.fmt.parseFloat(f32, v);
        } else if (std.mem.eql(u8, k, "--lr")) {
            o.lr = try std.fmt.parseFloat(f32, v);
        } else if (std.mem.eql(u8, k, "--batch")) {
            o.batch = try std.fmt.parseInt(u32, v, 10);
        } else if (std.mem.eql(u8, k, "--patience")) {
            o.patience = try std.fmt.parseInt(u32, v, 10);
        } else if (std.mem.eql(u8, k, "--max-epochs")) {
            o.max_epochs = try std.fmt.parseInt(u32, v, 10);
        } else if (std.mem.eql(u8, k, "--min-games")) {
            o.min_games = try std.fmt.parseInt(u32, v, 10);
        } else if (std.mem.eql(u8, k, "--seeds")) {
            var out: std.ArrayList(u32) = .empty;
            var it = std.mem.tokenizeScalar(u8, v, ',');
            while (it.next()) |s| try out.append(arena, try std.fmt.parseInt(u32, s, 10));
            if (out.items.len == 0) return error.NoSeeds;
            o.seeds = out.items;
        } else if (std.mem.eql(u8, k, "--blocks")) {
            var out: std.ArrayList(Block) = .empty;
            var it = std.mem.tokenizeScalar(u8, v, ',');
            while (it.next()) |s| try out.append(arena, if (std.mem.eql(u8, s, "dev"))
                .dev
            else
                @fromBackingInt(@intCast(try std.fmt.parseInt(u3, s, 10))));
            o.blocks = out.items;
        } else if (std.mem.eql(u8, k, "--fraction")) {
            o.fraction = try std.fmt.parseFloat(f64, v);
        } else if (std.mem.eql(u8, k, "--threads")) {
            o.threads = try std.fmt.parseInt(u32, v, 10);
        } else if (std.mem.eql(u8, k, "--out")) {
            o.out = v;
        } else return error.UnknownOption;
    }
    if (o.net == .big) {
        // draftnet's shape is fixed (dn: 10 x 32, 512, 256, dropout 0.1)
        for ([_][]const u8{ "--emb", "--hidden", "--depth", "--dropout", "--emb-wd", "--clip", "--evals" }) |k| if (set.contains(k)) return error.FixedForBig;
        const d: draftnet.Config = .{};
        if (!set.contains("--min-games")) o.min_games = 30;
        if (!set.contains("--batch")) o.batch = d.batch;
        if (!set.contains("--wd")) o.wd = d.wd;
        if (!set.contains("--lr")) o.lr = d.lr;
        o.emb = dn.emb;
        o.hidden = dn.h1;
        o.dropout = 1 - dn.keep;
    }
    if (o.emb == 0 or o.hidden == 0 or o.depth == 0 or o.depth > max_depth or o.evals == 0 or o.dropout < 0 or o.dropout >= 1 or o.fraction <= 0 or o.threads == 0) return error.BadValue;
    return o;
}

fn quantile(xs: []const i64, x: f64) i64 {
    if (x >= 1) return std.math.maxInt(i64);
    return xs[@intFromFloat(@as(f64, @floatFromInt(xs.len)) * x)];
}

/// Fit on dev-visible games before `before`; score dev-val (dev) or dev-visible games in
/// [lo, hi)
const Spec = struct {
    before: i64,
    lo: i64,
    hi: i64,
    dev: bool,

    fn scores(s: Spec, c: harness.Cuts, g: rows.Game) bool {
        if (s.dev) return harness.scored(.dev, c, g);
        return harness.visible(.dev, c, g) and g.start >= s.lo and g.start < s.hi;
    }
};

const Pooled = struct {
    ys: std.ArrayList(f32) = .empty,
    cand: std.ArrayList(f32) = .empty,
    ens: std.ArrayList(f32) = .empty,

    fn deinit(p: *Pooled, gpa: std.mem.Allocator) void {
        p.ys.deinit(gpa);
        p.cand.deinit(gpa);
        p.ens.deinit(gpa);
    }
};

/// One game as the nets see it: dense ids by slot (blue by role, then red)
const NetGame = struct {
    ids: [10]u32,
    platform: u8,
    y: f32,
    /// The candidate's logit for blue (resid), else 0
    off: f32,
};

/// The candidate fitted on the dev-visible games before `before` (kept by fraction):
/// blue's chance per data game index, for the games `want` marks; NaN elsewhere
fn candBlue(gpa: std.mem.Allocator, d: *const rows.Data, players: []const harness.Players, c: harness.Cuts, before: i64, fraction: f64, want: []const bool, out: []f32) !void {
    const k = api.outcomeIndex(.win);
    const fit_cuts: harness.Cuts = .{ .dev = before, .select = before, .eu = c.eu };
    var v = try harness.buildTrain(gpa, d, players, .dev, fit_cuts, fraction, false);
    defer v.deinit();
    const n_seeds: u64 = if (@hasDecl(cand, "seeded") and cand.seeded) 3 else 1;
    const sum = try gpa.alloc(f64, d.games.len);
    defer gpa.free(sum);
    const cnt = try gpa.alloc(u32, d.games.len);
    defer gpa.free(cnt);
    @memset(sum, 0);
    @memset(cnt, 0);
    for (1..n_seeds + 1) |seed| {
        var m = try cand.fit(gpa, &v.train, .{ .seed = seed });
        defer cand.deinit(&m, gpa);
        for (d.rows) |r| {
            if (!want[r.game]) continue;
            const g = d.games[r.game];
            const q = harness.query(cand.scope, g, players[r.game], r, false);
            const p: f64 = cand.predict(&m, &q)[k];
            sum[r.game] += if (r.side == 0) p else 1 - p;
            cnt[r.game] += 1;
        }
    }
    for (out, sum, cnt) |*o, s, n| o.* = if (n > 0) @floatCast(s / @as(f64, @floatFromInt(n))) else std.math.nan(f32);
}

/// Dense ids from `fit` games: champion-roles with min_games get their own, others their
/// role's (0..4)
const Vocab = struct {
    map: std.AutoHashMapUnmanaged(u64, u32) = .empty,
    n: u32 = 5,

    fn init(gpa: std.mem.Allocator, d: *const rows.Data, fit: []const u32, min_games: u32) !Vocab {
        var counts: std.AutoHashMapUnmanaged(u64, u32) = .empty;
        defer counts.deinit(gpa);
        for (fit) |gi| for (d.games[gi].teams) |team| for (team, 0..) |champion, role| {
            const e = try counts.getOrPutValue(gpa, key(champion, role), 0);
            e.value_ptr.* += 1;
        };
        // Sorted keys, so ids don't depend on hash order
        var keys: std.ArrayList(u64) = .empty;
        defer keys.deinit(gpa);
        var it = counts.iterator();
        while (it.next()) |e| if (e.value_ptr.* >= min_games) try keys.append(gpa, e.key_ptr.*);
        std.mem.sort(u64, keys.items, {}, std.sort.asc(u64));
        var v: Vocab = .{};
        for (keys.items) |kk| {
            try v.map.put(gpa, kk, v.n);
            v.n += 1;
        }
        return v;
    }

    fn deinit(v: *Vocab, gpa: std.mem.Allocator) void {
        v.map.deinit(gpa);
    }

    fn ids(v: *const Vocab, g: rows.Game) [10]u32 {
        var out: [10]u32 = undefined;
        for (0..2) |side| for (0..5) |role| {
            out[side * 5 + role] = v.map.get(key(g.teams[side][role], role)) orelse @intCast(role);
        };
        return out;
    }
};

fn key(champion: u32, role: usize) u64 {
    return (@as(u64, champion) << 3) | role;
}

fn logit(p: f32) f32 {
    const q = std.math.clamp(p, 1e-6, 1 - 1e-6);
    return @log(q / (1 - q));
}

fn netGames(gpa: std.mem.Allocator, d: *const rows.Data, games: []const u32, vocab: *const Vocab, off: ?[]const f32) ![]NetGame {
    const out = try gpa.alloc(NetGame, games.len);
    for (out, games) |*o, gi| {
        const g = d.games[gi];
        o.* = .{ .ids = vocab.ids(g), .platform = g.platform, .y = if (g.winner == 0) 1 else 0, .off = if (off) |x| logit(x[gi]) else 0 };
    }
    return out;
}

fn dnGames(gpa: std.mem.Allocator, games: []const NetGame) ![]dn.Game {
    const out = try gpa.alloc(dn.Game, games.len);
    for (out, games) |*o, g| o.* = .{ .ids = g.ids, .platform = g.platform, .y = g.y };
    return out;
}

const Fitted = struct {
    /// Blue's chance per scored game
    pred: []f32,
    /// Early stopping's choice, on the inner fit games
    epochs: f64,
    val_loss: f64,
    seconds: f64,
};

fn runBlock(
    gpa: std.mem.Allocator,
    io: Io,
    d: *const rows.Data,
    players: []const harness.Players,
    c: harness.Cuts,
    spec: Spec,
    block: Block,
    opts: Options,
    gpu: ?*const cuda.Gpu,
    fw: *Io.Writer,
    pw: *Io.Writer,
    w: *Io.Writer,
    pooled: *Pooled,
) !void {
    const t0 = Io.Clock.awake.now(io);
    // Fit games as buildTrain keeps them; scored games of the block
    var fit: std.ArrayList(u32) = .empty;
    defer fit.deinit(gpa);
    var scored: std.ArrayList(u32) = .empty;
    defer scored.deinit(gpa);
    for (d.games, 0..) |g, i| {
        if (harness.visible(.dev, c, g) and g.start < spec.before and harness.inFraction(g, opts.fraction)) try fit.append(gpa, @intCast(i));
        if (spec.scores(c, g)) try scored.append(gpa, @intCast(i));
    }
    // Validation cut: the newest tenth of the fit games
    const fit_starts = try gpa.alloc(i64, fit.items.len);
    defer gpa.free(fit_starts);
    for (fit_starts, fit.items) |*s, gi| s.* = d.games[gi].start;
    std.mem.sort(i64, fit_starts, {}, std.sort.asc(i64));
    const cut = fit_starts[@intFromFloat(@as(f64, @floatFromInt(fit_starts.len)) * (1 - val_share))];
    var inner: std.ArrayList(u32) = .empty;
    defer inner.deinit(gpa);
    var val: std.ArrayList(u32) = .empty;
    defer val.deinit(gpa);
    for (fit.items) |gi| try (if (d.games[gi].start < cut) &inner else &val).append(gpa, gi);

    // The candidate: on all fit games for the scored ones (and fit ones, as resid's
    // offset); on the inner games for the validation offset
    const want = try gpa.alloc(bool, d.games.len);
    defer gpa.free(want);
    @memset(want, false);
    for (scored.items) |gi| want[gi] = true;
    if (opts.net == .resid) for (fit.items) |gi| {
        want[gi] = true;
    };
    const p_all = try gpa.alloc(f32, d.games.len);
    defer gpa.free(p_all);
    try candBlue(gpa, d, players, c, spec.before, opts.fraction, want, p_all);
    const p_inner = try gpa.alloc(f32, d.games.len);
    defer gpa.free(p_inner);
    if (opts.net == .resid) {
        @memset(want, false);
        for (fit.items) |gi| want[gi] = true;
        try candBlue(gpa, d, players, c, cut, opts.fraction, want, p_inner);
    }
    const t_cand = secondsSince(io, t0);

    var vocab_inner = try Vocab.init(gpa, d, inner.items, opts.min_games);
    defer vocab_inner.deinit(gpa);
    var vocab_all = try Vocab.init(gpa, d, fit.items, opts.min_games);
    defer vocab_all.deinit(gpa);
    const resid = opts.net == .resid;
    const g_inner = try netGames(gpa, d, inner.items, &vocab_inner, if (resid) p_inner else null);
    defer gpa.free(g_inner);
    const g_val = try netGames(gpa, d, val.items, &vocab_inner, if (resid) p_inner else null);
    defer gpa.free(g_val);
    const g_fit = try netGames(gpa, d, fit.items, &vocab_all, if (resid) p_all else null);
    defer gpa.free(g_fit);
    const g_scored = try netGames(gpa, d, scored.items, &vocab_all, if (resid) p_all else null);
    defer gpa.free(g_scored);

    const n_s = opts.seeds.len;
    const fits = try gpa.alloc(Fitted, n_s);
    defer {
        for (fits) |f| gpa.free(f.pred);
        gpa.free(fits);
    }
    const sets: Sets = .{ .inner = g_inner, .val = g_val, .fit = g_fit, .scored = g_scored, .n_inner = vocab_inner.n, .n_all = vocab_all.n };
    switch (opts.net) {
        .big => for (opts.seeds, fits) |seed, *f| {
            f.* = try fitBig(gpa, io, gpu, opts, seed, sets);
        },
        .small, .resid => {
            const Ctx = struct {
                gpa: std.mem.Allocator,
                io: Io,
                opts: Options,
                sets: Sets,
                fits: []Fitted,
                fn one(x: @This(), i: usize) !void {
                    x.fits[i] = try fitSmall(x.gpa, x.io, x.opts, x.opts.seeds[i], x.sets);
                }
            };
            // One seed per thread, at most opts.threads at once
            var at: usize = 0;
            while (at < n_s) : (at += opts.threads) {
                const n = @min(opts.threads, n_s - at);
                try par.forEach(io, n, Ctx{ .gpa = gpa, .io = io, .opts = opts, .sets = sets, .fits = fits[at..][0..n] }, Ctx.one);
            }
        },
    }

    const ys = try gpa.alloc(f32, scored.items.len);
    defer gpa.free(ys);
    const pc = try gpa.alloc(f32, scored.items.len);
    defer gpa.free(pc);
    const ens = try gpa.alloc(f32, scored.items.len);
    defer gpa.free(ens);
    for (ys, pc, ens, g_scored, scored.items, 0..) |*y, *p, *e, g, gi, i| {
        y.* = g.y;
        p.* = p_all[gi];
        var s: f32 = 0;
        for (fits) |f| s += f.pred[i];
        e.* = s / @as(f32, @floatFromInt(n_s));
    }
    const name = blockName(block);
    try w.print("block {s}: fit {d} games (inner {d}, val {d}, ids {d}), scored {d}; candidate {d:.1} s\n", .{ name, fit.items.len, inner.items.len, val.items.len, vocab_all.n, scored.items.len, t_cand });
    if (resid) {
        var vl: f64 = 0;
        for (g_val) |g| vl += loss1(g.y, sigmoid(g.off));
        try w.print("candidate on val (fitted on inner): {d:.5}\n", .{vl / @as(f64, @floatFromInt(@max(g_val.len, 1)))});
    }
    try summaryHead(w);
    const cand_loss = meanLoss(ys, pc);
    const cand_auc = try auc(gpa, ys, pc);
    for (opts.seeds, fits) |seed, f| {
        const g = pairedGain(ys, pc, f.pred);
        try fw.print("{d}\t{s}\t{d}\t{d}\t{d:.6}\t{d:.6}\t{d:.6}\t{d:.6}\t{d:.2}\t{d:.1}\t{d:.6}\t{d:.5}\t{d:.5}\n", .{
            seed, name, fit.items.len, scored.items.len, meanLoss(ys, f.pred), cand_loss, g.mean, g.se, f.epochs, f.seconds, f.val_loss, try auc(gpa, ys, f.pred), cand_auc,
        });
        var label_buf: [32]u8 = undefined;
        try summaryRow(gpa, w, try std.fmt.bufPrint(&label_buf, "seed {d}", .{seed}), ys, pc, f.pred, f);
    }
    {
        const g = pairedGain(ys, pc, ens);
        var epochs: f64 = 0;
        var val_loss: f64 = 0;
        var secs: f64 = 0;
        for (fits) |f| {
            epochs += f.epochs;
            val_loss += f.val_loss;
            secs += f.seconds;
        }
        const ns: f64 = @floatFromInt(n_s);
        try fw.print("ens\t{s}\t{d}\t{d}\t{d:.6}\t{d:.6}\t{d:.6}\t{d:.6}\t{d:.2}\t{d:.1}\t{d:.6}\t{d:.5}\t{d:.5}\n", .{
            name, fit.items.len, scored.items.len, meanLoss(ys, ens), cand_loss, g.mean, g.se, epochs / ns, secs, val_loss / ns, try auc(gpa, ys, ens), cand_auc,
        });
        try summaryRow(gpa, w, "seed mean", ys, pc, ens, null);
    }
    try w.writeAll("\n");
    try w.flush();
    try fw.flush();
    const plat = protocol.platformIds();
    for (scored.items, 0..) |gi, i| {
        const g = d.games[gi];
        try pw.print("{s}\t{s}\t{s}\t{d}\t{d:.6}", .{ name, g.match_id, plat[g.platform], ys[i], pc[i] });
        for (fits) |f| try pw.print("\t{d:.6}", .{f.pred[i]});
        try pw.print("\t{d:.6}\n", .{ens[i]});
    }
    if (!spec.dev) {
        try pooled.ys.appendSlice(gpa, ys);
        try pooled.cand.appendSlice(gpa, pc);
        try pooled.ens.appendSlice(gpa, ens);
    }
}

fn blockName(b: Block) []const u8 {
    return switch (b) {
        .dev => "dev",
        .f1 => "1",
        .f2 => "2",
        .f3 => "3",
        .f4 => "4",
        .f5 => "5",
    };
}

fn secondsSince(io: Io, t0: Io.Timestamp) f64 {
    const ns = t0.durationTo(Io.Clock.awake.now(io)).toNanoseconds();
    return @as(f64, @floatFromInt(ns)) / 1e9;
}

fn summaryHead(w: *Io.Writer) !void {
    try w.writeAll("| net | games | log loss | cand log loss | gain, nats/game | AUC | cand AUC | epochs | val log loss |\n| --- | --- | --- | --- | --- | --- | --- | --- | --- |\n");
}

fn summaryRow(gpa: std.mem.Allocator, w: *Io.Writer, label: []const u8, ys: []const f32, pc: []const f32, pn: []const f32, f: ?Fitted) !void {
    const g = pairedGain(ys, pc, pn);
    try w.print("| {s} | {d} | {d:.5} | {d:.5} | {d:.5} ± {d:.5} | {d:.4} | {d:.4} |", .{ label, ys.len, meanLoss(ys, pn), meanLoss(ys, pc), g.mean, 1.96 * g.se, try auc(gpa, ys, pn), try auc(gpa, ys, pc) });
    if (f) |x| try w.print(" {d:.2} | {d:.5} |\n", .{ x.epochs, x.val_loss }) else try w.writeAll(" | |\n");
}

fn loss1(y: f32, p: f32) f64 {
    const q: f64 = std.math.clamp(p, 1e-6, 1 - 1e-6);
    return -(y * @log(q) + (1 - y) * @log(1 - q));
}

fn meanLoss(ys: []const f32, p: []const f32) f64 {
    var s: f64 = 0;
    for (ys, p) |y, q| s += loss1(y, q);
    return s / @as(f64, @floatFromInt(@max(ys.len, 1)));
}

const Gain = struct { mean: f64, se: f64 };

/// Candidate's loss minus the net's, per game (one unit per game: clustered by game);
/// positive = the net is better
fn pairedGain(ys: []const f32, pc: []const f32, pn: []const f32) Gain {
    var s: f64 = 0;
    var s2: f64 = 0;
    for (ys, pc, pn) |y, a, b| {
        const x = loss1(y, a) - loss1(y, b);
        s += x;
        s2 += x * x;
    }
    const n: f64 = @floatFromInt(@max(ys.len, 1));
    const mean = s / n;
    return .{ .mean = mean, .se = @sqrt(@max(s2 / n - mean * mean, 0) / @max(n - 1, 1)) };
}

/// Over both sides' rows, as the harness scores rows: each game counts once as (p, y)
/// and once as (1 - p, 1 - y). Ties share their rank
fn auc(gpa: std.mem.Allocator, ys: []const f32, p: []const f32) !f64 {
    const Item = struct { p: f32, y: bool };
    const items = try gpa.alloc(Item, 2 * ys.len);
    defer gpa.free(items);
    for (ys, p, 0..) |y, q, i| {
        items[2 * i] = .{ .p = q, .y = y > 0.5 };
        items[2 * i + 1] = .{ .p = 1 - q, .y = y <= 0.5 };
    }
    std.mem.sort(Item, items, {}, struct {
        fn lt(_: void, a: Item, b: Item) bool {
            return a.p < b.p;
        }
    }.lt);
    var rank_sum: f64 = 0;
    var pos: f64 = 0;
    var i: usize = 0;
    while (i < items.len) {
        var j = i;
        while (j < items.len and items[j].p == items[i].p) j += 1;
        const mid = (@as(f64, @floatFromInt(i + 1)) + @as(f64, @floatFromInt(j))) / 2;
        for (items[i..j]) |it| if (it.y) {
            rank_sum += mid;
            pos += 1;
        };
        i = j;
    }
    const neg = @as(f64, @floatFromInt(items.len)) - pos;
    if (pos == 0 or neg == 0) return 0.5;
    return (rank_sum - pos * (pos + 1) / 2) / (pos * neg);
}

const Sets = struct {
    inner: []const NetGame,
    val: []const NetGame,
    fit: []const NetGame,
    scored: []const NetGame,
    n_inner: u32,
    n_all: u32,
};

/// A tenth more games: a tenth more epochs (as win-ratings and win-comp)
fn refitEpochs(e: u32) u32 {
    return @max(1, e + e / 10);
}

fn fitBig(gpa: std.mem.Allocator, io: Io, gpu: ?*const cuda.Gpu, opts: Options, seed: u32, s: Sets) !Fitted {
    const t0 = Io.Clock.awake.now(io);
    const cfg: draftnet.Config = .{ .lr = opts.lr, .wd = opts.wd, .batch = opts.batch, .seed = seed };
    const inner = try dnGames(gpa, s.inner);
    defer gpa.free(inner);
    const val = try dnGames(gpa, s.val);
    defer gpa.free(val);
    const all = try dnGames(gpa, s.fit);
    defer gpa.free(all);
    const scored = try dnGames(gpa, s.scored);
    defer gpa.free(scored);
    var watch: draftnet.Watch = .{ .val = val, .patience = opts.patience };
    {
        var net = try fitBigOn(gpa, io, gpu, cfg, s.n_inner, inner, opts.max_epochs, opts.threads, &watch);
        net.deinit(gpa);
    }
    var net = try fitBigOn(gpa, io, gpu, cfg, s.n_all, all, refitEpochs(watch.best_epoch), opts.threads, null);
    defer net.deinit(gpa);
    const pred = try gpa.alloc(f32, scored.len);
    try net.predict(gpa, io, scored, pred);
    return .{ .pred = pred, .epochs = @floatFromInt(watch.best_epoch), .val_loss = watch.best_loss, .seconds = secondsSince(io, t0) };
}

fn fitBigOn(gpa: std.mem.Allocator, io: Io, gpu: ?*const cuda.Gpu, cfg: draftnet.Config, n_ids: u32, games: []const dn.Game, epochs: u32, threads: u32, watch: ?*draftnet.Watch) !draftnet.Net {
    const g = gpu orelse return draftnet.fitCpu(gpa, io, cfg, n_ids, games, epochs, threads, watch);
    var dev: draftnet.DeviceGames = try .init(g, games);
    defer dev.deinit();
    return draftnet.fitGpu(gpa, io, g, &dev, cfg, n_ids, games, epochs, watch);
}

/// The small net's flat parameters: platform intercepts, the offset's weight (resid) and
/// hidden biases (no decay); champion-role and role embeddings (emb_wd); hidden weights
/// (layer k: hidden x its input) and output weights (wd)
const Layout = struct {
    emb: usize,
    hidden: usize,
    depth: usize,
    input: usize,
    c: usize,
    a: usize,
    b: usize,
    e: usize,
    r: usize,
    w: usize,
    out: usize,
    len: usize,

    fn init(n_ids: usize, emb: usize, hidden: usize, depth: usize) Layout {
        var l: Layout = undefined;
        l.emb = emb;
        l.hidden = hidden;
        l.depth = depth;
        l.input = 10 * emb;
        l.c = 0;
        l.a = n_platforms;
        l.b = l.a + 1;
        l.e = l.b + depth * hidden;
        l.r = l.e + n_ids * emb;
        l.w = l.r + 5 * emb;
        l.out = l.w + hidden * l.input + (depth - 1) * hidden * hidden;
        l.len = l.out + hidden;
        return l;
    }

    fn fanIn(l: Layout, k: usize) usize {
        return if (k == 0) l.input else l.hidden;
    }

    /// Layer k's weights, hidden x fanIn(k), row-major
    fn weights(l: Layout, k: usize) usize {
        return if (k == 0) l.w else l.w + l.hidden * l.input + (k - 1) * l.hidden * l.hidden;
    }
};

const SmallNet = struct {
    l: Layout,
    p: []f32,

    fn init(gpa: std.mem.Allocator, l: Layout, zero_out: bool, rnd: std.Random) !SmallNet {
        const p = try gpa.alloc(f32, l.len);
        @memset(p, 0);
        p[l.a] = 1;
        for (p[l.e..l.w]) |*x| x.* = (rnd.float(f32) * 2 - 1) * 0.1;
        for (0..l.depth) |k| {
            const bound = @sqrt(6.0 / @as(f32, @floatFromInt(l.fanIn(k))));
            for (p[l.weights(k)..][0 .. l.hidden * l.fanIn(k)]) |*x| x.* = (rnd.float(f32) * 2 - 1) * bound;
        }
        const out_bound: f32 = if (zero_out) 0 else @sqrt(3.0 / @as(f32, @floatFromInt(l.hidden)));
        for (p[l.out..l.len]) |*x| x.* = (rnd.float(f32) * 2 - 1) * out_bound;
        return .{ .l = l, .p = p };
    }
};

const max_depth = 4;

/// One side order's activations: x input; per layer z pre-activation, h after ReLU and
/// dropout
const View = struct {
    x: []f32,
    z: [max_depth][]f32,
    h: [max_depth][]f32,
};

fn dot(a: []const f32, b: []const f32) f32 {
    const V = @Vector(8, f32);
    var acc: V = @splat(0);
    var i: usize = 0;
    while (i + 8 <= a.len) : (i += 8) acc += @as(V, a[i..][0..8].*) * @as(V, b[i..][0..8].*);
    var s = @reduce(.Add, acc);
    while (i < a.len) : (i += 1) s += a[i] * b[i];
    return s;
}

fn axpy(y: []f32, s: f32, x: []const f32) void {
    for (y, x) |*a, b| a.* += s * b;
}

/// f for one side order (swap: red's slots first); with rnd, units drop at 1 - keep
fn forward(n: *const SmallNet, g: *const NetGame, swap: bool, v: *const View, keep: f32, rnd: ?std.Random) f32 {
    const l = n.l;
    for (0..10) |slot| {
        const src = if (swap) (slot + 5) % 10 else slot;
        const e = n.p[l.e + g.ids[src] * l.emb ..][0..l.emb];
        const r = n.p[l.r + (slot % 5) * l.emb ..][0..l.emb];
        for (v.x[slot * l.emb ..][0..l.emb], e, r) |*x, a, b| x.* = a + b;
    }
    for (0..l.depth) |k| {
        const in = if (k == 0) v.x else v.h[k - 1];
        const wk = n.p[l.weights(k)..];
        for (v.z[k], v.h[k], 0..) |*z, *h, j| {
            z.* = dot(wk[j * in.len ..][0..in.len], in) + n.p[l.b + k * l.hidden + j];
            const kept = if (rnd) |rr| rr.float(f32) < keep else true;
            h.* = if (z.* > 0 and kept) (if (rnd != null) z.* / keep else z.*) else 0;
        }
    }
    return dot(n.p[l.out..l.len], v.h[l.depth - 1]);
}

/// Adds df's gradient to gr; d0 and d1 scratch of at least max(input, hidden)
fn backward(n: *const SmallNet, g: *const NetGame, swap: bool, v: *const View, df: f32, keep: f32, gr: []f32, d0: []f32, d1: []f32) void {
    const l = n.l;
    const top = v.h[l.depth - 1];
    axpy(gr[l.out..l.len], df, top);
    var dh = d0[0..l.hidden];
    for (dh, n.p[l.out..l.len]) |*d, wv| d.* = df * wv;
    var dn_buf = d1;
    var k = l.depth;
    while (k > 0) {
        k -= 1;
        const in = if (k == 0) v.x else v.h[k - 1];
        const din = dn_buf[0..in.len];
        @memset(din, 0);
        const wk = n.p[l.weights(k)..];
        const gwk = gr[l.weights(k)..];
        for (dh, v.h[k], 0..) |d, h, j| {
            if (h == 0) continue;
            const dz = d / keep;
            gr[l.b + k * l.hidden + j] += dz;
            axpy(gwk[j * in.len ..][0..in.len], dz, in);
            axpy(din, dz, wk[j * in.len ..][0..in.len]);
        }
        dn_buf = dh.ptr[0..@max(l.input, l.hidden)];
        dh = din;
    }
    for (0..10) |slot| {
        const src = if (swap) (slot + 5) % 10 else slot;
        const d = dh[slot * l.emb ..][0..l.emb];
        axpy(gr[l.e + g.ids[src] * l.emb ..][0..l.emb], 1, d);
        axpy(gr[l.r + (slot % 5) * l.emb ..][0..l.emb], 1, d);
    }
}

fn sigmoid(x: f32) f32 {
    return 1 / (1 + @exp(-x));
}

fn gameLogit(n: *const SmallNet, g: *const NetGame, fb: f32, fr: f32) f32 {
    return (fb - fr) / 2 + n.p[n.l.c + g.platform] + n.p[n.l.a] * g.off;
}

fn predictSmall(n: *const SmallNet, games: []const NetGame, w: *const Work, out: []f32) void {
    for (games, out) |*g, *o| {
        const fb = forward(n, g, false, &w.v[0], 1, null);
        const fr = forward(n, g, true, &w.v[1], 1, null);
        o.* = sigmoid(gameLogit(n, g, fb, fr));
    }
}

const Work = struct {
    buf: []f32,
    v: [2]View,
    d0: []f32,
    d1: []f32,

    fn init(gpa: std.mem.Allocator, l: Layout) !Work {
        std.debug.assert(l.depth >= 1 and l.depth <= max_depth);
        const per = l.input + 2 * l.depth * l.hidden;
        const wide = @max(l.input, l.hidden);
        const buf = try gpa.alloc(f32, 2 * per + 2 * wide);
        var w: Work = .{ .buf = buf, .v = undefined, .d0 = buf[2 * per ..][0..wide], .d1 = buf[2 * per + wide ..][0..wide] };
        for (&w.v, 0..) |*v, i| {
            var b = buf[i * per ..][0..per];
            v.x = b[0..l.input];
            b = b[l.input..];
            for (0..l.depth) |k| {
                v.z[k] = b[0..l.hidden];
                v.h[k] = b[l.hidden..][0..l.hidden];
                b = b[2 * l.hidden ..];
            }
        }
        return w;
    }

    fn deinit(w: *const Work, gpa: std.mem.Allocator) void {
        gpa.free(w.buf);
    }
};

const Trained = struct { net: SmallNet, steps: u64, epochs: f64, val_loss: f64 };

fn stepsPerEpoch(n: usize, batch: u32) u64 {
    return @max(1, (n + batch - 1) / batch);
}

/// AdamW over shuffled batches for at most max_steps; with val, evaluated opts.evals
/// times an epoch, stopping after `patience` evaluations without a new best and keeping
/// the best one's parameters
fn trainSmall(gpa: std.mem.Allocator, opts: Options, seed: u32, n_ids: u32, train: []const NetGame, val: ?[]const NetGame, max_steps: u64) !Trained {
    var rng: std.Random.DefaultPrng = .init(seed);
    const rnd = rng.random();
    const l: Layout = .init(n_ids, opts.emb, opts.hidden, opts.depth);
    var n = try SmallNet.init(gpa, l, opts.net == .resid, rnd);
    errdefer gpa.free(n.p);
    const w: Work = try .init(gpa, l);
    defer w.deinit(gpa);
    const scratch = try gpa.alloc(f32, 4 * l.len);
    defer gpa.free(scratch);
    const gr = scratch[0..l.len];
    const m1 = scratch[l.len..][0..l.len];
    const m2 = scratch[2 * l.len ..][0..l.len];
    const best = scratch[3 * l.len ..][0..l.len];
    @memset(m1, 0);
    @memset(m2, 0);
    const order = try gpa.alloc(u32, train.len);
    defer gpa.free(order);
    for (order, 0..) |*o, i| o.* = @intCast(i);
    const vpred = try gpa.alloc(f32, if (val) |v| v.len else 0);
    defer gpa.free(vpred);
    const keep = 1 - opts.dropout;
    const drop: ?std.Random = if (opts.dropout > 0) rnd else null;
    const emb_wd = opts.emb_wd orelse opts.wd;
    const per_epoch = stepsPerEpoch(train.len, opts.batch);
    const eval_every = @max(1, per_epoch / @max(opts.evals, 1));

    var best_loss = std.math.inf(f64);
    var best_step: u64 = 0;
    var since_best: u32 = 0;
    var step: u64 = 0;
    var at: usize = order.len;
    while (step < max_steps) {
        if (at >= order.len) {
            rnd.shuffle(u32, order);
            at = 0;
        }
        const part = order[at..@min(at + opts.batch, order.len)];
        at += part.len;
        @memset(gr, 0);
        const count: f32 = @floatFromInt(part.len);
        for (part) |gi| {
            const g = &train[gi];
            const fb = forward(&n, g, false, &w.v[0], keep, drop);
            const fr = forward(&n, g, true, &w.v[1], keep, drop);
            const dl = (sigmoid(gameLogit(&n, g, fb, fr)) - g.y) / count;
            gr[l.c + g.platform] += dl;
            gr[l.a] += dl * g.off;
            backward(&n, g, false, &w.v[0], dl / 2, keep, gr, w.d0, w.d1);
            backward(&n, g, true, &w.v[1], -dl / 2, keep, gr, w.d0, w.d1);
        }
        if (opts.clip > 0) {
            var norm: f32 = 0;
            for (gr) |x| norm += x * x;
            norm = @sqrt(norm);
            if (norm > opts.clip) for (gr) |*x| {
                x.* *= opts.clip / norm;
            };
        }
        step += 1;
        const c1 = 1 - std.math.pow(f32, 0.9, @floatFromInt(step));
        const c2 = 1 - std.math.pow(f32, 0.999, @floatFromInt(step));
        for (n.p, gr, m1, m2, 0..) |*x, g, *s1, *s2, i| {
            s1.* = 0.9 * s1.* + 0.1 * g;
            s2.* = 0.999 * s2.* + 0.001 * g * g;
            const decay: f32 = if (i < l.e) 0 else if (i < l.w) emb_wd * x.* else opts.wd * x.*;
            x.* -= opts.lr * ((s1.* / c1) / (@sqrt(s2.* / c2) + 1e-8) + decay);
        }
        const v = val orelse continue;
        if (step % eval_every != 0 and step != max_steps) continue;
        predictSmall(&n, v, &w, vpred);
        var loss: f64 = 0;
        for (v, vpred) |g, q| loss += loss1(g.y, q);
        loss /= @floatFromInt(@max(v.len, 1));
        if (loss < best_loss - 1e-7) {
            best_loss = loss;
            best_step = step;
            since_best = 0;
            @memcpy(best, n.p);
        } else {
            since_best += 1;
            if (since_best >= opts.patience) break;
        }
    }
    if (val == null) best_step = step else if (best_step > 0) @memcpy(n.p, best);
    const epochs = @as(f64, @floatFromInt(best_step)) / @as(f64, @floatFromInt(per_epoch));
    return .{ .net = n, .steps = best_step, .epochs = epochs, .val_loss = best_loss };
}

fn fitSmall(gpa: std.mem.Allocator, io: Io, opts: Options, seed: u32, s: Sets) !Fitted {
    const t0 = Io.Clock.awake.now(io);
    const tuned = try trainSmall(gpa, opts, seed, s.n_inner, s.inner, s.val, opts.max_epochs * stepsPerEpoch(s.inner.len, opts.batch));
    gpa.free(tuned.net.p);
    // A tenth more games: a tenth more epochs (as win-ratings and win-comp)
    const per = stepsPerEpoch(s.fit.len, opts.batch);
    const steps: u64 = @max(1, @as(u64, @intFromFloat(@round(tuned.epochs * 1.1 * @as(f64, @floatFromInt(per))))));
    const full = try trainSmall(gpa, opts, seed, s.n_all, s.fit, null, steps);
    defer gpa.free(full.net.p);
    const w: Work = try .init(gpa, full.net.l);
    defer w.deinit(gpa);
    const pred = try gpa.alloc(f32, s.scored.len);
    predictSmall(&full.net, s.scored, &w, pred);
    if (opts.net == .resid) std.debug.print("netcheck: seed {d}: offset weight {d:.3}\n", .{ seed, full.net.p[full.net.l.a] });
    return .{ .pred = pred, .epochs = tuned.epochs, .val_loss = tuned.val_loss, .seconds = secondsSince(io, t0) };
}

const testing = std.testing;

test "small net: gradient matches finite differences at every depth" {
    const gpa = testing.allocator;
    for (1..4) |depth| {
        const l: Layout = .init(8, 4, 6, depth);
        var rng: std.Random.DefaultPrng = .init(5);
        var n = try SmallNet.init(gpa, l, false, rng.random());
        defer gpa.free(n.p);
        const w: Work = try .init(gpa, l);
        defer w.deinit(gpa);
        const g: NetGame = .{ .ids = .{ 5, 6, 7, 3, 4, 0, 1, 2, 5, 6 }, .platform = 2, .y = 1, .off = 0.3 };
        const gr = try gpa.alloc(f32, l.len);
        defer gpa.free(gr);
        @memset(gr, 0);
        const fb = forward(&n, &g, false, &w.v[0], 1, null);
        const fr = forward(&n, &g, true, &w.v[1], 1, null);
        const dl = sigmoid(gameLogit(&n, &g, fb, fr)) - g.y;
        gr[l.c + g.platform] += dl;
        gr[l.a] += dl * g.off;
        backward(&n, &g, false, &w.v[0], dl / 2, 1, gr, w.d0, w.d1);
        backward(&n, &g, true, &w.v[1], -dl / 2, 1, gr, w.d0, w.d1);
        var checks: std.ArrayList(usize) = .empty;
        defer checks.deinit(gpa);
        try checks.appendSlice(gpa, &.{ l.c + 2, l.a, l.b + 1, l.e + 5 * 4 + 2, l.r + 3, l.w + 7, l.out + 4 });
        if (depth > 1) try checks.appendSlice(gpa, &.{ l.weights(depth - 1) + 9, l.b + (depth - 1) * l.hidden + 2 });
        for (checks.items) |i| {
            const old = n.p[i];
            var p: [1]f32 = undefined;
            n.p[i] = old + 1e-3;
            predictSmall(&n, (&g)[0..1], &w, &p);
            const up = loss1(g.y, p[0]);
            n.p[i] = old - 1e-3;
            predictSmall(&n, (&g)[0..1], &w, &p);
            const down = loss1(g.y, p[0]);
            n.p[i] = old;
            try testing.expectApproxEqAbs((up - down) / 2e-3, gr[i], 2e-3);
        }
    }
}

test "small net: antisymmetric, learns a planted champion edge, resid starts at the offset" {
    const gpa = testing.allocator;
    var rng: std.Random.DefaultPrng = .init(3);
    const r = rng.random();
    const n_ids = 30;
    const train = try gpa.alloc(NetGame, 3000);
    defer gpa.free(train);
    for (train) |*g| {
        for (&g.ids, 0..) |*id, slot| id.* = 5 + 5 * r.uintLessThan(u32, 5) + @as(u32, @intCast(slot % 5));
        g.platform = 0;
        g.off = 0;
        // Blue wins more with id 5 at top, red likewise
        var edge: f32 = 0;
        if (g.ids[0] == 5) edge += 1;
        if (g.ids[5] == 5) edge -= 1;
        g.y = if (r.float(f32) < sigmoid(edge)) 1 else 0;
    }
    const opts: Options = .{ .emb = 8, .hidden = 16, .depth = 2, .dropout = 0, .wd = 0, .lr = 3e-3, .batch = 64 };
    const t = try trainSmall(gpa, opts, 1, n_ids, train, null, 8 * stepsPerEpoch(train.len, opts.batch));
    defer gpa.free(t.net.p);
    const w: Work = try .init(gpa, t.net.l);
    defer w.deinit(gpa);
    var a = train[0];
    a.ids[0] = 5;
    a.ids[5] = 10;
    var b = a;
    for (0..5) |i| std.mem.swap(u32, &b.ids[i], &b.ids[i + 5]);
    var p: [2]f32 = undefined;
    predictSmall(&t.net, &.{ a, b }, &w, &p);
    // Swapping the teams flips the net's part; blue's side intercept stays
    try testing.expectApproxEqAbs(2 * t.net.p[t.net.l.c], logit(p[0]) + logit(p[1]), 1e-4);
    try testing.expect(p[0] > 0.62);

    var ro = opts;
    ro.net = .resid;
    const t0 = try trainSmall(gpa, ro, 1, n_ids, train, null, 0);
    defer gpa.free(t0.net.p);
    a.off = 0.7;
    predictSmall(&t0.net, &.{a}, &w, p[0..1]);
    try testing.expectApproxEqAbs(sigmoid(0.7), p[0], 1e-6);
}

test "auc: both orientations, ties share ranks" {
    const gpa = testing.allocator;
    try testing.expectApproxEqAbs(@as(f64, 1), try auc(gpa, &.{ 1, 0, 1 }, &.{ 0.8, 0.3, 0.6 }), 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0.5), try auc(gpa, &.{ 1, 0 }, &.{ 0.5, 0.5 }), 1e-12);
}
