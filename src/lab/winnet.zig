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
//!          only add what the candidate misses. A training game's offset comes from a
//!          candidate fitted without its hashed fold (cross-fitted); val and scored
//!          games' from the candidate on all inner / fit games
//!   bigres: big as a residual on the same offsets (draftnet Config.resid)
//!   set:   DeepSets over each team on win-comp's profiles, residual like resid
//!          (lab/setnet.zig)
//! All antisymmetric: logit = (f(blue, red) - f(red, blue)) / 2 + c[platform] (+ offset).
//! Writes DIR/folds.tsv (per seed and block, plus the seed-averaged `ens`) and
//! DIR/preds.tsv (per game); gains paired per game (= clustered by game)
//! LoLDraftAI's evaluation beside ours (lab/randsplit.zig, dev only): --split random:SEED
//! replaces the blocks by one, fitted on the non-test games before the selection cut
//! outside that seed's random tenth and scored on the whole tenth, every platform, as
//! LoLDraftAI (preds.tsv's match_id prefix gives EUW1 alone); --filter ldai drops
//! LoLDraftAI's 15-minute filtered games from fit and scored games of any block
//! (SNAP/ldai_filter.tsv, meiolol-lab ldai-filter)

const std = @import("std");
const api = @import("api");
const cand = @import("cand");
const rows = @import("rows.zig");
const protocol = @import("protocol.zig");
const harness = @import("harness.zig");
const randsplit = @import("randsplit.zig");
const draftnet = @import("draftnet.zig");
const gates = @import("gates.zig");
const setnet = @import("setnet.zig");
const looks = @import("looks.zig");
const nn = @import("nn");
const par = @import("../par.zig");
const cuda = @import("../gpu/cuda.zig");
const dn = @import("../gpu/draftnet_layout.zig");

const Io = std.Io;

pub const usage =
    \\  netcheck SNAP --net big|small|resid|set|bigres [OPT VALUE]...
    \\                                  neural nets vs the -Dcand candidate on dev-val
    \\                                  and win-comp's 5 forward folds (lab/winnet.zig):
    \\                                  --emb N --hidden N --depth N --dropout X --wd X
    \\                                  --emb-wd X --lr X --clip X --batch N --evals N
    \\                                  --patience N --max-epochs N --min-games N
    \\                                  (big: --evals defaults to 1; patience counts
    \\                                  evaluations)
    \\                                  --fix-offset 0|1
    \\                                  set (lab/setnet.zig): --phi N --rho N
    \\                                  --cross 0|1 --ids 0|1
    \\                                  --emb-init DIR (small, resid: champion-role
    \\                                  embeddings from DIR/emb-<block>-s<seed>.tsv,
    \\                                  meiolol-lab pretrain) --emb-freeze 0|1
    \\                                  --seeds 1,2,3 --blocks dev,1,2,3,4,5
    \\                                  --blocks test (alone: the test look, fit on
    \\                                  every played game before the test cut, scored
    \\                                  on test and test minus SNAP/test-exclude.tsv;
    \\                                  ledgered in SNAP/test-looks.tsv first)
    \\                                  --fraction X (nested share of fit games)
    \\                                  --window newest:N|oldest:N|spread:N (each dev
    \\                                  block fits on N games: its newest, its oldest,
    \\                                  or a hashed share over every day; drift vs noise)
    \\                                  --resample N (A/A noise floor: fit on a seeded
    \\                                  random 90% of the fit games, the same for the
    \\                                  candidate; scored games unchanged)
    \\                                  --export 1 (set net: the dev block's fit per
    \\                                  seed as DIR/setnet-s<seed>.json, for the
    \\                                  admin Draft tester)
    \\                                  --fit-preds 1 (teacher preds for distillation:
    \\                                  each block's fit games scored by nets fitted
    \\                                  without their hashed fifth, DIR/fit-preds.tsv)
    \\                                  --shuffle-ids SEED (control: training games'
    \\                                  champion rows permuted, labels and offsets kept)
    \\                                  --threads N --out DIR
    \\                                  --split random:SEED (one block, LoLDraftAI's
    \\                                  random tenth) --filter ldai (its filters)
    \\
;

pub const Kind = enum { big, small, resid, set, bigres };

/// Nets fitted on top of the candidate's logit (cross-fitted on training games)
fn usesOffset(k: Kind) bool {
    return k == .resid or k == .set or k == .bigres;
}

fn isBig(k: Kind) bool {
    return k == .big or k == .bigres;
}

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
    /// resid: the offset's weight stays 1
    fix_offset: bool = false,
    /// Champion-role embeddings start from DIR/emb-<block>-s<seed>.tsv (pretrain.zig;
    /// s1 when the seed has none); --emb must be their width
    emb_init: ?[]const u8 = null,
    /// With emb_init: champion-role embeddings stay as loaded
    emb_freeze: bool = false,
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
    window: ?Window = null,
    /// --split random:SEED: LoLDraftAI's random tenth instead of the blocks
    split_seed: ?u32 = null,
    /// --resample N: fit games and the candidate's on a seeded random share (A/A runs)
    resample: ?u32 = null,
    /// --fit-preds 1: also score every block's fit games, each from a fit without its
    /// cross-fit fifth (effects.zig --soft reads them)
    fit_preds: bool = false,
    /// --export 1 (set net, dev block): each seed's fit as DIR/setnet-s<seed>.json
    /// (setnet.writeExport), for the admin Draft tester
    export_net: bool = false,
    /// --shuffle-ids SEED: a control for nets on fitted offsets; every training set's
    /// champion-id rows (all 10 seats together) permuted across its games, labels and
    /// offsets kept, scored games untouched: a residual net can then only recalibrate
    shuffle_ids: ?u32 = null,
    /// --filter ldai: LoLDraftAI's 15-minute filters on fit and scored games
    ldai: bool = false,
    /// CPU threads for small and resid fits (one seed per thread) and big on the CPU
    threads: u32 = 3,
    out: []const u8 = ".",
    set: setnet.Config = .{},
};

pub const Block = enum { dev, f1, f2, f3, f4, f5, random, final };
const val_share = 0.1;
pub const n_platforms = 16;

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
    if (isBig(opts.net)) gpu = cuda.Gpu.init(ptx) catch |e| blk: {
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
    std.debug.assert(protocol.platformIds().len <= n_platforms);
    const c = try harness.cuts(gpa, &data);
    var filter: ?randsplit.Filter = if (opts.ldai) try randsplit.loadFilter(gpa, io, snap) else null;
    defer if (filter) |*f| f.deinit(gpa);

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
    // gains' dev.tsv shape: one row per game, blue's chance, the block last
    const cand_name = if (@hasDecl(cand, "name")) cand.name else "cand";
    const game_head = "match_id\tslot\toutcome\ty\tpred\tblock\n";
    var cand_file = try dir.createFile(io, try std.fmt.allocPrint(arena, "games-{s}.tsv", .{cand_name}), .{});
    defer cand_file.close(io);
    var cbuf: [64 * 1024]u8 = undefined;
    var cw = cand_file.writer(io, &cbuf);
    try cw.interface.writeAll(game_head);
    var net_file = try dir.createFile(io, try std.fmt.allocPrint(arena, "games-{s}.tsv", .{@tagName(opts.net)}), .{});
    defer net_file.close(io);
    var nbuf: [64 * 1024]u8 = undefined;
    var nw = net_file.writer(io, &nbuf);
    try nw.interface.writeAll(game_head);
    const fit_file: ?Io.File = if (opts.fit_preds) try dir.createFile(io, "fit-preds.tsv", .{}) else null;
    defer if (fit_file) |f| f.close(io);
    var fpbuf: [64 * 1024]u8 = undefined;
    var fpw: ?Io.File.Writer = if (fit_file) |f| f.writer(io, &fpbuf) else null;
    if (fpw) |*x| try x.interface.writeAll("match_id\tblock\tseed\tp_blue\n");
    const out: Out = .{ .folds = &fw.interface, .preds = &pw.interface, .cand = &cw.interface, .net = &nw.interface, .fit = if (fpw) |*x| &x.interface else null };

    var out_buf: [4096]u8 = undefined;
    var stdout = Io.File.stdout().writer(io, &out_buf);
    const w = &stdout.interface;
    try w.print("# netcheck: {s} net vs {s}, fraction {d}, resample {?d}, seeds {any}\n\n", .{ @tagName(opts.net), if (@hasDecl(cand, "name")) cand.name else "cand", opts.fraction, opts.resample, opts.seeds });
    try w.print("options: emb {d} hidden {d} depth {d} dropout {d} wd {d} emb_wd {d} lr {d} clip {d} batch {d} evals {d} patience {d} min_games {d} emb_init {s} emb_freeze {}\n\n", .{
        opts.emb, opts.hidden, opts.depth, opts.dropout, opts.wd, opts.emb_wd orelse opts.wd, opts.lr, opts.clip, opts.batch, opts.evals, opts.patience, opts.min_games, opts.emb_init orelse "-", opts.emb_freeze,
    });
    if (opts.split_seed != null or opts.ldai) {
        try w.print("split: {s}{s}; dev only, the test set untouched\n\n", .{ if (opts.split_seed != null) "LoLDraftAI's random tenth" else "time", if (opts.ldai) ", LoLDraftAI's filters" else "" });
    }
    try w.flush();

    // A test look counts once the test games are read, so the ledger line comes first
    var exclude: ?looks.Exclude = null;
    defer if (exclude) |*e| e.deinit(gpa);
    if (opts.blocks.len == 1 and opts.blocks[0] == .final) {
        _ = try looks.record(gpa, io, Io.Dir.cwd(), snap, "netcheck", argv, w);
        exclude = try looks.Exclude.load(gpa, io, Io.Dir.cwd(), snap);
    }

    var pooled: Pooled = .{};
    defer pooled.deinit(gpa);
    for (opts.blocks) |b| {
        var spec: Spec = switch (b) {
            .dev => .{ .before = c.dev, .lo = c.dev, .hi = c.test_, .dev = true },
            .final => .{ .before = c.test_, .lo = c.test_, .hi = std.math.maxInt(i64), .dev = false, .final = true, .exclude = if (exclude) |*e| e else null },
            .random => .{ .before = c.test_, .lo = 0, .hi = 0, .dev = false, .random = opts.split_seed.? },
            // The shared folds (harness.Cuts, win-comp's foldAblation blocks)
            else => blk: {
                const f = c.fold(@backingInt(b));
                break :blk .{ .before = f.lo, .lo = f.lo, .hi = f.hi, .dev = false };
            },
        };
        spec.filter = if (filter) |*f| f else null;
        spec.resample = opts.resample;
        if (opts.window) |win| try win.apply(gpa, data.games, c, &spec, opts.fraction, w);
        try runBlock(gpa, io, &data, players, c, spec, b, opts, if (gpu) |*g| g else null, out, w, &pooled);
        if (opts.fit_preds) for (0..cross_folds) |f| {
            var sf = spec;
            sf.fifth = @intCast(f);
            try runBlock(gpa, io, &data, players, c, sf, b, opts, if (gpu) |*g| g else null, out, w, &pooled);
        };
    }
    if (pooled.cand.items.len > 0) {
        try w.writeAll("\nfolds pooled (blocks 1-5 run here):\n");
        try summaryHead(w);
        try summaryRow(gpa, w, "folds", pooled.ys.items, pooled.cand.items, pooled.ens.items, null);
    }
    for ([_]*Io.Writer{ out.folds, out.preds, out.cand, out.net }) |x| try x.flush();
    if (out.fit) |x| try x.flush();
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
        } else if (std.mem.eql(u8, k, "--fix-offset")) {
            o.fix_offset = (try std.fmt.parseInt(u1, v, 10)) == 1;
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
            else if (std.mem.eql(u8, s, "test"))
                .final
            else
                @fromBackingInt(@intCast(try std.fmt.parseInt(u3, s, 10))));
            o.blocks = out.items;
        } else if (std.mem.eql(u8, k, "--split")) {
            if (!std.mem.startsWith(u8, v, "random:")) return error.UnknownSplit;
            o.split_seed = try std.fmt.parseInt(u32, v["random:".len..], 10);
        } else if (std.mem.eql(u8, k, "--filter")) {
            if (!std.mem.eql(u8, v, "ldai")) return error.UnknownFilter;
            o.ldai = true;
        } else if (std.mem.eql(u8, k, "--fraction")) {
            o.fraction = try std.fmt.parseFloat(f64, v);
        } else if (std.mem.eql(u8, k, "--window")) {
            o.window = try Window.parse(v);
        } else if (std.mem.eql(u8, k, "--shuffle-ids")) {
            o.shuffle_ids = try std.fmt.parseInt(u32, v, 10);
        } else if (std.mem.eql(u8, k, "--fit-preds")) {
            o.fit_preds = std.mem.eql(u8, v, "1");
        } else if (std.mem.eql(u8, k, "--export")) {
            o.export_net = std.mem.eql(u8, v, "1");
        } else if (std.mem.eql(u8, k, "--resample")) {
            o.resample = try std.fmt.parseInt(u32, v, 10);
        } else if (std.mem.eql(u8, k, "--threads")) {
            o.threads = try std.fmt.parseInt(u32, v, 10);
        } else if (std.mem.eql(u8, k, "--emb-init")) {
            o.emb_init = v;
        } else if (std.mem.eql(u8, k, "--emb-freeze")) {
            o.emb_freeze = !std.mem.eql(u8, v, "0");
        } else if (std.mem.eql(u8, k, "--out")) {
            o.out = v;
        } else if (!try setnet.parseOption(&o.set, k, v)) return error.UnknownOption;
    }
    if (o.split_seed != null) {
        if (set.contains("--blocks")) return error.SplitReplacesBlocks;
        o.blocks = &.{.random};
    }
    // A test look is one run of the declared model on all its fit games
    if (std.mem.indexOfScalar(Block, o.blocks, .final) != null) {
        if (o.blocks.len != 1) return error.TestBlockAlone;
        for ([_][]const u8{ "--split", "--filter", "--fraction", "--window", "--resample", "--shuffle-ids", "--fit-preds" }) |k| if (set.contains(k)) return error.NotForTest;
    }
    if (o.window != null and o.split_seed != null) return error.WindowNeedsBlocks;
    // spread's share is of the block's fit games, not of a fraction of them
    if (o.window != null and o.fraction != 1) return error.WindowWithFraction;
    if (o.emb_freeze and o.emb_init == null) return error.FreezeWithoutInit;
    // An export is a model to use: the real profiles and labels, every fit game
    if (o.export_net and (o.net != .set or o.set.control != .none or o.resample != null or o.fraction != 1 or o.window != null or o.shuffle_ids != null)) return error.ExportNeedsPlainSet;
    if (o.net == .set and o.emb_init != null) return error.EmbInitNotForSet;
    if (isBig(o.net)) {
        if (o.emb_init != null) return error.EmbInitNotForBig;
        // draftnet's offset weight always trains
        if (o.fix_offset) return error.FixOffsetNotForBig;
        // draftnet's shape is fixed (dn: 10 x 32, 512, 256, dropout 0.1)
        for ([_][]const u8{ "--emb", "--hidden", "--depth", "--dropout", "--emb-wd", "--clip" }) |k| if (set.contains(k)) return error.FixedForBig;
        const d: draftnet.Config = .{};
        if (!set.contains("--min-games")) o.min_games = 30;
        if (!set.contains("--evals")) o.evals = 1;
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

/// Fit on dev-visible games before `before`; score dev-val (dev) or dev-visible games in
/// [lo, hi). random: LoLDraftAI's split instead (randsplit.zig); filter: its filters.
/// final: fit on every played game before the test cut, score the test games
const Spec = struct {
    before: i64,
    lo: i64,
    hi: i64,
    dev: bool,
    final: bool = false,
    /// final: also scored without these (an earlier snapshot's looks saw them)
    exclude: ?*const looks.Exclude = null,
    random: ?u32 = null,
    filter: ?*const randsplit.Filter = null,
    resample: ?u32 = null,
    /// --fit-preds: fit without this cross-fit fifth of the fit games, score that fifth
    fifth: ?u8 = null,
    /// --window: fit games start at or after this
    since: i64 = std.math.minInt(i64),
    /// --window spread: nested share of the fit games (inFraction's hash)
    share: f64 = 1,

    fn fits(s: Spec, c: harness.Cuts, g: rows.Game, fraction: f64) bool {
        if (s.fifth) |f| if (crossFold(g) == f) return false;
        return s.fitsAll(c, g, fraction);
    }

    fn fitsAll(s: Spec, c: harness.Cuts, g: rows.Game, fraction: f64) bool {
        if (s.filter) |f| if (!f.keep(g)) return false;
        if (!harness.inFraction(g, @min(fraction, s.share))) return false;
        if (g.start < s.since) return false;
        if (s.resample) |r| if (!inResample(g, r)) return false;
        if (s.random) |seed| return devEra(c, g) and !randsplit.inTest(g, seed);
        if (s.final) return harness.visible(.final, c, g) and g.start < s.before;
        return harness.visible(.dev, c, g) and g.start < s.before;
    }

    fn scores(s: Spec, c: harness.Cuts, g: rows.Game, fraction: f64) bool {
        if (s.fifth) |f| return crossFold(g) == f and s.fitsAll(c, g, fraction);
        if (s.filter) |f| if (!f.keep(g)) return false;
        if (s.random) |seed| return devEra(c, g) and randsplit.inTest(g, seed);
        if (s.dev) return harness.scored(.dev, c, g);
        if (s.final) return harness.scored(.final, c, g);
        return harness.visible(.dev, c, g) and harness.inRegion(c, g) and g.start >= s.lo and g.start < s.hi;
    }

    /// The random split's games: played, not test
    fn devEra(c: harness.Cuts, g: rows.Game) bool {
        return !g.is_test and g.duration_s >= harness.min_duration_s and g.start < c.test_;
    }
};

/// --window: every block fits on the same number of games, taken as its newest, its
/// oldest or spread over all its days, so equal-N fits tell drift (newest wins) from noise
const Window = struct {
    kind: enum { newest, oldest, spread },
    n: usize,

    fn parse(v: []const u8) !Window {
        const colon = std.mem.indexOfScalar(u8, v, ':') orelse return error.BadWindow;
        return .{
            .kind = std.meta.stringToEnum(@FieldType(Window, "kind"), v[0..colon]) orelse return error.BadWindow,
            .n = try std.fmt.parseInt(usize, v[colon + 1 ..], 10),
        };
    }

    /// Narrows `spec` to N of its fit games; a block with fewer is an error
    fn apply(win: Window, gpa: std.mem.Allocator, games: []const rows.Game, c: harness.Cuts, spec: *Spec, fraction: f64, w: *Io.Writer) !void {
        if (spec.random != null or spec.final) return error.WindowNeedsBlocks;
        var starts: std.ArrayList(i64) = .empty;
        defer starts.deinit(gpa);
        for (games) |g| if (spec.fitsAll(c, g, fraction)) try starts.append(gpa, g.start);
        const n = starts.items.len;
        if (n < win.n) {
            try w.print("# --window {s}:{d}: the block has {d} fit games\n", .{ @tagName(win.kind), win.n, n });
            try w.flush();
            return error.WindowTooBig;
        }
        std.mem.sort(i64, starts.items, {}, std.sort.asc(i64));
        switch (win.kind) {
            // Ties at the threshold keep a few more than N
            .newest => spec.since = starts.items[n - win.n],
            .oldest => spec.before = if (win.n == n) spec.before else starts.items[win.n],
            .spread => spec.share = @as(f64, @floatFromInt(win.n)) / @as(f64, @floatFromInt(n)),
        }
        try w.print("# window {s}:{d} of {d} fit games\n", .{ @tagName(win.kind), win.n, n });
    }
};

/// The candidate's fit games: the spec's, older than `before` (resid's inner fit)
const FitKeep = struct {
    spec: Spec,
    c: harness.Cuts,
    fraction: f64,
    before: i64 = std.math.maxInt(i64),
    /// Leave out the games of this cross-fit fold
    without: ?u8 = null,

    pub fn keep(k: FitKeep, g: rows.Game) bool {
        if (k.without) |f| if (crossFold(g) == f) return false;
        return k.spec.fits(k.c, g, k.fraction) and g.start < k.before;
    }
};

pub fn inResample(g: rows.Game, seed: u32) bool {
    return harness.inResample(g.start, g.platform, seed);
}

/// resid's offsets on its own training games come from candidates fitted without them:
/// an in-sample offset is more confident than the out-of-sample one it is scored with
const cross_folds = 5;

fn crossFold(g: rows.Game) u8 {
    var h = std.hash.Wyhash.init(0xc705);
    h.update(std.mem.asBytes(&g.start));
    h.update(std.mem.asBytes(&g.platform));
    return @intCast(h.final() % cross_folds);
}

/// Each `games` entry's blue chance from the candidate fitted on `keep`'s games outside
/// its cross-fit fold
fn candCross(gpa: std.mem.Allocator, d: *const rows.Data, players: []const harness.Players, keep: FitKeep, games: []const u32, want: []bool, out: []f32) !void {
    for (0..cross_folds) |f| {
        @memset(want, false);
        for (games) |gi| want[gi] = crossFold(d.games[gi]) == f;
        var k = keep;
        k.without = @intCast(f);
        try candBlue(gpa, d, players, k, want, out);
    }
}

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
pub const NetGame = struct {
    ids: [10]u32,
    platform: u8,
    y: f32,
    /// The candidate's logit for blue (resid), else 0
    off: f32,
};

fn shuffleIds(games: []NetGame, seed: u32, set: usize) void {
    var rng: std.Random.DefaultPrng = .init((@as(u64, seed) << 8) | set);
    const r = rng.random();
    var i = games.len;
    while (i > 1) {
        i -= 1;
        std.mem.swap([10]u32, &games[i].ids, &games[r.uintLessThan(usize, i + 1)].ids);
    }
}

/// The candidate fitted on the games `keep` accepts: blue's chance per data game index,
/// written for the games `want` marks only
fn candBlue(gpa: std.mem.Allocator, d: *const rows.Data, players: []const harness.Players, keep: FitKeep, want: []const bool, out: []f32) !void {
    const k = api.outcomeIndex(.win);
    var v = try harness.buildTrainWhere(gpa, d, players, keep);
    defer v.deinit();
    const n_seeds: u64 = if (@hasDecl(cand, "seeded") and cand.seeded) 3 else 1;
    const sum = try gpa.alloc(f64, d.games.len);
    defer gpa.free(sum);
    const cnt = try gpa.alloc(u32, d.games.len);
    defer gpa.free(cnt);
    @memset(sum, 0);
    @memset(cnt, 0);
    for (1..n_seeds + 1) |seed| {
        var m = try harness.fit(cand, gpa, &v.train, .{ .seed = seed });
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
    for (out, sum, cnt) |*o, s, n| if (n > 0) {
        o.* = @floatCast(s / @as(f64, @floatFromInt(n)));
    };
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

pub const logit = nn.logit;

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
    for (out, games) |*o, g| o.* = .{ .ids = g.ids, .platform = g.platform, .y = g.y, .off = g.off };
    return out;
}

pub const Fitted = struct {
    /// Blue's chance per scored game
    pred: []f32,
    /// Early stopping's choice, on the inner fit games
    epochs: f64,
    val_loss: f64,
    seconds: f64,
};

/// netcheck's output files: folds.tsv, preds.tsv, games-<cand>.tsv, games-<net>.tsv
const Out = struct { folds: *Io.Writer, preds: *Io.Writer, cand: *Io.Writer, net: *Io.Writer, fit: ?*Io.Writer = null };

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
    out: Out,
    w: *Io.Writer,
    pooled: *Pooled,
) !void {
    const fw = out.folds;
    const pw = out.preds;
    const t0 = Io.Clock.awake.now(io);
    // Fit games as buildTrain keeps them; scored games of the block
    var fit: std.ArrayList(u32) = .empty;
    defer fit.deinit(gpa);
    var scored: std.ArrayList(u32) = .empty;
    defer scored.deinit(gpa);
    for (d.games, 0..) |g, i| {
        if (spec.fits(c, g, opts.fraction)) try fit.append(gpa, @intCast(i));
        if (spec.scores(c, g, opts.fraction)) try scored.append(gpa, @intCast(i));
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
    const p_all = try gpa.alloc(f32, d.games.len);
    defer gpa.free(p_all);
    @memset(p_all, std.math.nan(f32));
    const all_keep: FitKeep = .{ .spec = spec, .c = c, .fraction = opts.fraction };
    try candBlue(gpa, d, players, all_keep, want, p_all);
    const p_inner = try gpa.alloc(f32, d.games.len);
    defer gpa.free(p_inner);
    @memset(p_inner, std.math.nan(f32));
    if (usesOffset(opts.net)) {
        // Training games cross-fitted; val (scored) from the candidate on all inner (fit)
        try candCross(gpa, d, players, all_keep, fit.items, want, p_all);
        var inner_keep = all_keep;
        inner_keep.before = cut;
        try candCross(gpa, d, players, inner_keep, inner.items, want, p_inner);
        @memset(want, false);
        for (val.items) |gi| want[gi] = true;
        try candBlue(gpa, d, players, inner_keep, want, p_inner);
    }
    const t_cand = secondsSince(io, t0);

    var vocab_inner = try Vocab.init(gpa, d, inner.items, opts.min_games);
    defer vocab_inner.deinit(gpa);
    var vocab_all = try Vocab.init(gpa, d, fit.items, opts.min_games);
    defer vocab_all.deinit(gpa);
    const resid = usesOffset(opts.net);
    const g_inner = try netGames(gpa, d, inner.items, &vocab_inner, if (resid) p_inner else null);
    defer gpa.free(g_inner);
    const g_val = try netGames(gpa, d, val.items, &vocab_inner, if (resid) p_inner else null);
    defer gpa.free(g_val);
    const g_fit = try netGames(gpa, d, fit.items, &vocab_all, if (resid) p_all else null);
    defer gpa.free(g_fit);
    const g_scored = try netGames(gpa, d, scored.items, &vocab_all, if (resid) p_all else null);
    defer gpa.free(g_scored);
    if (opts.shuffle_ids) |seed| for ([_][]NetGame{ g_inner, g_val, g_fit }, 0..) |set, k| shuffleIds(set, seed, k);

    const n_s = opts.seeds.len;
    const fits = try gpa.alloc(Fitted, n_s);
    defer {
        for (fits) |f| gpa.free(f.pred);
        gpa.free(fits);
    }
    const sets: Sets = .{ .inner = g_inner, .val = g_val, .fit = g_fit, .scored = g_scored, .n_inner = vocab_inner.n, .n_all = vocab_all.n, .block = block, .vocab_inner = &vocab_inner, .vocab_all = &vocab_all, .d = d, .idx = .{ .inner = inner.items, .val = val.items, .fit = fit.items, .scored = scored.items } };
    switch (opts.net) {
        .big, .bigres => for (opts.seeds, fits) |seed, *f| {
            f.* = try fitBig(gpa, io, gpu, opts, seed, sets);
        },
        .small, .resid, .set => {
            const Ctx = struct {
                gpa: std.mem.Allocator,
                io: Io,
                opts: Options,
                sets: Sets,
                seeds: []const u32,
                fits: []Fitted,
                fn one(x: @This(), i: usize) !void {
                    x.fits[i] = if (x.opts.net == .set) try setnet.fit(x.gpa, x.io, x.opts, x.seeds[i], x.sets) else try fitSmall(x.gpa, x.io, x.opts, x.seeds[i], x.sets);
                }
            };
            // One seed per thread, at most opts.threads at once
            var at: usize = 0;
            while (at < n_s) : (at += opts.threads) {
                const n = @min(opts.threads, n_s - at);
                try par.forEach(io, n, Ctx{ .gpa = gpa, .io = io, .opts = opts, .sets = sets, .seeds = opts.seeds[at..][0..n], .fits = fits[at..][0..n] }, Ctx.one);
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
    if (spec.fifth) |f| {
        const fpw = out.fit.?;
        for (scored.items, 0..) |gi, i| for (opts.seeds, fits) |seed, ft| {
            try fpw.print("{s}\t{s}\t{d}\t{d:.6}\n", .{ d.games[gi].match_id, name, seed, ft.pred[i] });
        };
        try w.print("block {s} fifth {d}: fit {d} games, scored {d} of the block's fit games\n", .{ name, f, fit.items.len, scored.items.len });
        try w.flush();
        return;
    }
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
        var m: f64 = 0;
        var m2: f64 = 0;
        for (fits) |f| {
            const x = -pairedGain(ys, pc, f.pred).mean;
            m += x;
            m2 += x * x;
        }
        m /= ns;
        try w.print("seed spread: per-seed vs cand mean {d:.5}, sd {d:.5}\n", .{ m, @sqrt(@max(m2 / ns - m * m, 0) * ns / @max(ns - 1, 1)) });
    }
    if (spec.exclude) |e| try excludedRows(gpa, w, d, scored.items, ys, pc, ens, e);
    try w.writeAll("\n");
    try w.flush();
    try fw.flush();
    const plat = protocol.platformIds();
    for (scored.items, 0..) |gi, i| {
        const g = d.games[gi];
        try pw.print("{s}\t{s}\t{s}\t{d}\t{d:.6}", .{ name, g.match_id, plat[g.platform], ys[i], pc[i] });
        for (fits) |f| try pw.print("\t{d:.6}", .{f.pred[i]});
        try pw.print("\t{d:.6}\n", .{ens[i]});
        try out.cand.print("{s}\t0\twin\t{d}\t{d:.6}\t{s}\n", .{ g.match_id, ys[i], pc[i], name });
        try out.net.print("{s}\t0\twin\t{d}\t{d:.6}\t{s}\n", .{ g.match_id, ys[i], ens[i], name });
    }
    if (!spec.dev and !spec.final and spec.random == null) {
        try pooled.ys.appendSlice(gpa, ys);
        try pooled.cand.appendSlice(gpa, pc);
        try pooled.ens.appendSlice(gpa, ens);
    }
}

/// The test look's second number: the same predictions without the excluded games
fn excludedRows(gpa: std.mem.Allocator, w: *Io.Writer, d: *const rows.Data, scored: []const u32, ys: []const f32, pc: []const f32, ens: []const f32, e: *const looks.Exclude) !void {
    var ky: std.ArrayList(f32) = .empty;
    defer ky.deinit(gpa);
    var kc: std.ArrayList(f32) = .empty;
    defer kc.deinit(gpa);
    var ke: std.ArrayList(f32) = .empty;
    defer ke.deinit(gpa);
    for (scored, ys, pc, ens) |gi, y, c, x| if (!e.has(d.games[gi].match_id)) {
        try ky.append(gpa, y);
        try kc.append(gpa, c);
        try ke.append(gpa, x);
    };
    try w.print("\ntest minus {s}: {d} of {d} games\n", .{ looks.exclude_name, ky.items.len, ys.len });
    try summaryHead(w);
    try summaryRow(gpa, w, "seed mean", ky.items, kc.items, ke.items, null);
}

fn blockName(b: Block) []const u8 {
    return switch (b) {
        .dev => "dev",
        .f1 => "1",
        .f2 => "2",
        .f3 => "3",
        .f4 => "4",
        .f5 => "5",
        .random => "random",
        .final => "test",
    };
}

pub fn secondsSince(io: Io, t0: Io.Timestamp) f64 {
    const ns = t0.durationTo(Io.Clock.awake.now(io)).toNanoseconds();
    return @as(f64, @floatFromInt(ns)) / 1e9;
}

fn summaryHead(w: *Io.Writer) !void {
    try w.writeAll("| net | games | log loss | cand log loss | vs cand, nats/game (negative: net better) | AUC | cand AUC | epochs | val log loss |\n| --- | --- | --- | --- | --- | --- | --- | --- | --- |\n");
}

fn summaryRow(gpa: std.mem.Allocator, w: *Io.Writer, label: []const u8, ys: []const f32, pc: []const f32, pn: []const f32, f: ?Fitted) !void {
    const g = pairedGain(ys, pc, pn);
    try w.print("| {s} | {d} | {d:.5} | {d:.5} | {d:.5} ± {d:.5} | {d:.4} | {d:.4} |", .{ label, ys.len, meanLoss(ys, pn), meanLoss(ys, pc), -g.mean, 1.96 * g.se, try auc(gpa, ys, pn), try auc(gpa, ys, pc) });
    if (f) |x| try w.print(" {d:.2} | {d:.5} |\n", .{ x.epochs, x.val_loss }) else try w.writeAll(" | |\n");
}

pub const loss1 = nn.logLoss;

fn meanLoss(ys: []const f32, p: []const f32) f64 {
    return nn.meanLogLoss(f32, ys, p);
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
    const both = try gpa.alloc(f32, 4 * ys.len);
    defer gpa.free(both);
    const y2 = both[0 .. 2 * ys.len];
    const p2 = both[2 * ys.len ..];
    for (ys, p, 0..) |y, q, i| {
        y2[2 * i] = y;
        p2[2 * i] = q;
        y2[2 * i + 1] = 1 - y;
        p2[2 * i + 1] = 1 - q;
    }
    return nn.auc(f32, gpa, y2, p2);
}

pub const Sets = struct {
    inner: []const NetGame,
    val: []const NetGame,
    fit: []const NetGame,
    scored: []const NetGame,
    n_inner: u32,
    n_all: u32,
    block: Block,
    vocab_inner: *const Vocab,
    vocab_all: *const Vocab,
    d: *const rows.Data,
    /// Data game indices, in the same order as the game sets above
    idx: struct { inner: []const u32, val: []const u32, fit: []const u32, scored: []const u32 },
};

/// Pretrained champion-role vectors (pretrain.zig's emb-<block>-s<seed>.tsv: champion,
/// role, fit games, then d values; champion 0 is the role's shared vector)
const EmbTable = struct {
    map: std.AutoHashMapUnmanaged(u64, []f32) = .empty,
    arena: std.heap.ArenaAllocator,

    fn load(gpa: std.mem.Allocator, io: Io, dir: []const u8, block: Block, seed: u32, d: u32) !EmbTable {
        var t: EmbTable = .{ .arena = .init(gpa) };
        errdefer t.arena.deinit();
        const a = t.arena.allocator();
        const text = for ([_]u32{ seed, 1 }) |s| {
            const path = try std.fmt.allocPrint(a, "{s}/emb-{s}-s{d}.tsv", .{ dir, blockName(block), s });
            break Io.Dir.cwd().readFileAlloc(io, path, a, .limited(64 << 20)) catch |e| switch (e) {
                error.FileNotFound => continue,
                else => return e,
            };
        } else return error.EmbFileNotFound;
        var lines = std.mem.tokenizeScalar(u8, text, '\n');
        _ = lines.next();
        while (lines.next()) |line| {
            var it = std.mem.tokenizeScalar(u8, line, '\t');
            const champion = try std.fmt.parseInt(u32, it.next() orelse return error.EmbFormat, 10);
            const role = try std.fmt.parseInt(u3, it.next() orelse return error.EmbFormat, 10);
            _ = it.next() orelse return error.EmbFormat;
            const v = try a.alloc(f32, d);
            for (v) |*x| x.* = try std.fmt.parseFloat(f32, it.next() orelse return error.EmbDim);
            if (it.next() != null) return error.EmbDim;
            try t.map.put(a, key(champion, role), v);
        }
        return t;
    }

    fn deinit(t: *EmbTable) void {
        t.arena.deinit();
    }

    /// Each vocab id's vector: its champion-role's, else its role's shared one
    fn apply(t: *const EmbTable, v: *const Vocab, s: *const Small, p: []f32) !void {
        for (0..5) |role| {
            const x = t.map.get(key(0, role)) orelse return error.EmbMissingRole;
            @memcpy(s.e.row(p, role), x);
        }
        var it = v.map.iterator();
        while (it.next()) |e| {
            const x = t.map.get(e.key_ptr.*) orelse t.map.get(key(0, e.key_ptr.* & 7)).?;
            @memcpy(s.e.row(p, e.value_ptr.*), x);
        }
    }
};

const EmbInit = struct { table: *const EmbTable, vocab: *const Vocab };

/// Steps for the refit on n games: a tenth more games, a tenth more epochs (as
/// win-ratings and win-comp)
pub fn refitSteps(epochs: f64, n: usize, batch: u32) u64 {
    return nn.refitSteps(epochs, 1.1, n, batch);
}

fn fitBig(gpa: std.mem.Allocator, io: Io, gpu: ?*const cuda.Gpu, opts: Options, seed: u32, s: Sets) !Fitted {
    const t0 = Io.Clock.awake.now(io);
    const cfg: draftnet.Config = .{ .lr = opts.lr, .wd = opts.wd, .batch = opts.batch, .seed = seed, .resid = opts.net == .bigres };
    const inner = try dnGames(gpa, s.inner);
    defer gpa.free(inner);
    const val = try dnGames(gpa, s.val);
    defer gpa.free(val);
    const all = try dnGames(gpa, s.fit);
    defer gpa.free(all);
    const scored = try dnGames(gpa, s.scored);
    defer gpa.free(scored);
    var watch: draftnet.Watch = .{ .val = val, .patience = opts.patience, .evals = opts.evals };
    {
        var net = try fitBigOn(gpa, io, gpu, cfg, s.n_inner, inner, opts.max_epochs * stepsPerEpoch(inner.len, cfg.batch), opts.threads, &watch);
        net.deinit(gpa);
    }
    var net = try fitBigOn(gpa, io, gpu, cfg, s.n_all, all, refitSteps(watch.bestEpochs(), all.len, cfg.batch), opts.threads, null);
    defer net.deinit(gpa);
    const pred = try gpa.alloc(f32, scored.len);
    try net.predict(gpa, io, scored, pred);
    if (opts.net == .bigres) std.debug.print("netcheck: seed {d}: offset weight {d:.3}\n", .{ seed, net.p[net.l.a] });
    return .{ .pred = pred, .epochs = watch.bestEpochs(), .val_loss = watch.best_loss, .seconds = secondsSince(io, t0) };
}

fn fitBigOn(gpa: std.mem.Allocator, io: Io, gpu: ?*const cuda.Gpu, cfg: draftnet.Config, n_ids: u32, games: []const dn.Game, steps: u64, threads: u32, watch: ?*draftnet.Watch) !draftnet.Net {
    const g = gpu orelse return draftnet.fitCpu(gpa, io, cfg, n_ids, games, steps, threads, watch);
    var dev: draftnet.DeviceGames = try .init(g, games);
    defer dev.deinit();
    return draftnet.fitGpu(gpa, io, g, &dev, cfg, n_ids, games, steps, watch);
}

/// The small net's flat parameters: platform intercepts, the offset's weight (resid) and
/// hidden biases (no decay); champion-role and role embeddings (emb_wd); hidden weights
/// (layer k: hidden x its input) and output weights (wd)
const max_depth = 4;

/// The small net's parameters. Decay as torch's twin (py/xcheck/xnets.py): none on the
/// platform intercepts, the offset weight and biases; emb_wd on the embeddings; wd on the
/// weights
const Small = struct {
    ps: nn.Params,
    emb: usize,
    hidden: usize,
    depth: usize,
    /// 10 slots' vectors side by side
    input: usize,
    /// Blue's intercept per platform
    c: nn.Param,
    /// The offset's weight (resid)
    a: nn.Param,
    b: [max_depth]nn.Param,
    /// Champion-role vectors by vocab id
    e: nn.Param,
    /// Role vectors, added to each slot's champion-role one
    r: nn.Param,
    /// Layer k's weights, hidden x (input or hidden)
    w: [max_depth]nn.Param,
    out: nn.Param,

    /// resid nets' output weights start at 0 (drawn and zeroed, as before); frozen_emb
    /// keeps the champion-role vectors as initialised
    fn init(gpa: std.mem.Allocator, n_ids: usize, opts: Options, frozen_emb: bool) !Small {
        std.debug.assert(opts.depth >= 1 and opts.depth <= max_depth);
        var s: Small = .{ .ps = .empty, .emb = opts.emb, .hidden = opts.hidden, .depth = opts.depth, .input = 10 * opts.emb, .c = undefined, .a = undefined, .b = undefined, .e = undefined, .r = undefined, .w = undefined, .out = undefined };
        errdefer s.ps.deinit(gpa);
        const ps = &s.ps;
        const emb_wd = opts.emb_wd orelse opts.wd;
        const names = [max_depth][2][]const u8{ .{ "b0", "w0" }, .{ "b1", "w1" }, .{ "b2", "w2" }, .{ "b3", "w3" } };
        s.c = try ps.vector(gpa, "platform", n_platforms, .{});
        s.a = try ps.scalar(gpa, "offset", .{ .init = .{ .constant = 1 }, .frozen = opts.fix_offset });
        for (0..s.depth) |k| s.b[k] = try ps.vector(gpa, names[k][0], s.hidden, .{});
        s.e = try ps.table(gpa, "champion_role", n_ids, s.emb, .{ .init = .{ .uniform = 0.1 }, .decay = emb_wd, .frozen = frozen_emb });
        s.r = try ps.table(gpa, "role", 5, s.emb, .{ .init = .{ .uniform = 0.1 }, .decay = emb_wd });
        for (0..s.depth) |k| s.w[k] = try ps.matrix(gpa, names[k][1], s.hidden, s.fanIn(k), .{ .init = .kaiming(s.fanIn(k)), .decay = opts.wd });
        const out_bound: f32 = if (opts.net == .resid) 0 else @sqrt(3.0 / @as(f32, @floatFromInt(s.hidden)));
        s.out = try ps.vector(gpa, "out", s.hidden, .{ .init = .{ .uniform = out_bound }, .decay = opts.wd });
        return s;
    }

    fn fanIn(s: *const Small, k: usize) usize {
        return if (k == 0) s.input else s.hidden;
    }
};

const SmallNet = struct {
    s: Small,
    p: []f32,

    fn init(gpa: std.mem.Allocator, s: Small, rnd: std.Random) !SmallNet {
        const p = try s.ps.alloc(gpa);
        s.ps.initValues(p, rnd);
        return .{ .s = s, .p = p };
    }

    fn deinit(n: *SmallNet, gpa: std.mem.Allocator) void {
        gpa.free(n.p);
        n.s.ps.deinit(gpa);
    }
};

/// One side order's activations: x input; per layer z pre-activation, h after ReLU and
/// dropout
const View = struct {
    x: []f32,
    z: [max_depth][]f32,
    h: [max_depth][]f32,
};

pub const dot = nn.dot;
pub const axpy = nn.axpy;

/// f for one side order (swap: red's slots first); with rnd, units drop at 1 - keep
fn forward(n: *const SmallNet, g: *const NetGame, swap: bool, v: *const View, keep: f32, rnd: ?std.Random) f32 {
    const s = &n.s;
    for (0..10) |slot| {
        const src = if (swap) (slot + 5) % 10 else slot;
        const e = s.e.row(n.p, g.ids[src]);
        const r = s.r.row(n.p, slot % 5);
        for (v.x[slot * s.emb ..][0..s.emb], e, r) |*x, a, b| x.* = a + b;
    }
    for (0..s.depth) |k| {
        const in = if (k == 0) v.x else v.h[k - 1];
        nn.linear.forward(s.w[k].of(n.p), s.b[k].of(n.p), in, v.z[k]);
        nn.relu.forward(v.z[k], v.h[k], keep, rnd);
    }
    return dot(s.out.of(n.p), v.h[s.depth - 1]);
}

/// Adds df's gradient to gr; d0 and d1 scratch of at least max(input, hidden)
fn backward(n: *const SmallNet, g: *const NetGame, swap: bool, v: *const View, df: f32, keep: f32, gr: []f32, d0: []f32, d1: []f32) void {
    const s = &n.s;
    axpy(s.out.of(gr), df, v.h[s.depth - 1]);
    var dh = d0[0..s.hidden];
    for (dh, s.out.of(n.p)) |*d, wv| d.* = df * wv;
    var dn_buf = d1;
    var k = s.depth;
    while (k > 0) {
        k -= 1;
        const in = if (k == 0) v.x else v.h[k - 1];
        const din = dn_buf[0..in.len];
        @memset(din, 0);
        nn.relu.backward(v.h[k], dh, keep, dh);
        nn.linear.backward(s.w[k].of(n.p), in, dh, s.w[k].of(gr), s.b[k].of(gr), din);
        dn_buf = dh.ptr[0..@max(s.input, s.hidden)];
        dh = din;
    }
    for (0..10) |slot| {
        const src = if (swap) (slot + 5) % 10 else slot;
        const d = dh[slot * s.emb ..][0..s.emb];
        axpy(s.e.row(gr, g.ids[src]), 1, d);
        axpy(s.r.row(gr, slot % 5), 1, d);
    }
}

pub fn sigmoid(x: f32) f32 {
    return nn.sigmoid(x);
}

fn gameLogit(n: *const SmallNet, g: *const NetGame, fb: f32, fr: f32) f32 {
    return (fb - fr) / 2 + n.s.c.at(n.p, g.platform).* + n.s.a.at(n.p, 0).* * g.off;
}

fn predictSmall(n: *const SmallNet, games: []const NetGame, w: *const Work, out: []f32) void {
    for (games, out) |*g, *o| {
        const fb = forward(n, g, false, &w.v[0], 1, null);
        const fr = forward(n, g, true, &w.v[1], 1, null);
        o.* = sigmoid(gameLogit(n, g, fb, fr));
    }
}

/// Adds game g's loss gradient, scaled by 1 / count, to gr (dropout with rnd)
fn gameGrad(n: *const SmallNet, g: *const NetGame, w: *const Work, count: f32, keep: f32, rnd: ?std.Random, gr: []f32) void {
    const fb = forward(n, g, false, &w.v[0], keep, rnd);
    const fr = forward(n, g, true, &w.v[1], keep, rnd);
    const dl = (sigmoid(gameLogit(n, g, fb, fr)) - g.y) / count;
    n.s.c.at(gr, g.platform).* += dl;
    n.s.a.at(gr, 0).* += dl * g.off;
    backward(n, g, false, &w.v[0], dl / 2, keep, gr, w.d0, w.d1);
    backward(n, g, true, &w.v[1], -dl / 2, keep, gr, w.d0, w.d1);
}

const Work = struct {
    buf: []f32,
    v: [2]View,
    d0: []f32,
    d1: []f32,

    fn init(gpa: std.mem.Allocator, s: *const Small) !Work {
        const per = s.input + 2 * s.depth * s.hidden;
        const wide = @max(s.input, s.hidden);
        const buf = try gpa.alloc(f32, 2 * per + 2 * wide);
        var w: Work = .{ .buf = buf, .v = undefined, .d0 = buf[2 * per ..][0..wide], .d1 = buf[2 * per + wide ..][0..wide] };
        for (&w.v, 0..) |*v, i| {
            var b = buf[i * per ..][0..per];
            v.x = b[0..s.input];
            b = b[s.input..];
            for (0..s.depth) |k| {
                v.z[k] = b[0..s.hidden];
                v.h[k] = b[s.hidden..][0..s.hidden];
                b = b[2 * s.hidden ..];
            }
        }
        return w;
    }

    fn deinit(w: *const Work, gpa: std.mem.Allocator) void {
        gpa.free(w.buf);
    }
};

const Trained = struct { net: SmallNet, steps: u64, epochs: f64, val_loss: f64 };

pub const stepsPerEpoch = nn.stepsPerEpoch;

/// trainSmall's side of nn.fit: a batch's gradients, clipped, one AdamW step; the
/// validation games' mean loss
const SmallFit = struct {
    n: *SmallNet,
    w: *const Work,
    train: []const NetGame,
    val: []const NetGame,
    vpred: []f32,
    gr: []f32,
    opt: *nn.Adam,
    segs: []const nn.Segment,
    keep: f32,
    drop: ?std.Random,
    clip: f32,

    pub fn step(f: *SmallFit, part: []const u32) !void {
        @memset(f.gr, 0);
        const count: f32 = @floatFromInt(part.len);
        for (part) |gi| gameGrad(f.n, &f.train[gi], f.w, count, f.keep, f.drop, f.gr);
        if (f.clip > 0) _ = nn.clipGradNorm(f.gr, f.clip);
        f.opt.step(f.n.p, f.gr, f.segs);
    }

    pub fn valLoss(f: *SmallFit) !f64 {
        predictSmall(f.n, f.val, f.w, f.vpred);
        var loss: f64 = 0;
        for (f.val, f.vpred) |g, q| loss += loss1(g.y, q);
        return loss / @as(f64, @floatFromInt(@max(f.val.len, 1)));
    }
};

/// AdamW over shuffled batches for at most max_steps; with val, evaluated opts.evals
/// times an epoch, stopping after `patience` evaluations without a new best and keeping
/// the best one's parameters
fn trainSmall(gpa: std.mem.Allocator, opts: Options, seed: u32, n_ids: u32, train: []const NetGame, val: ?[]const NetGame, max_steps: u64, emb_init: ?EmbInit) !Trained {
    var rng: std.Random.DefaultPrng = .init(seed);
    const rnd = rng.random();
    const sm: Small = try .init(gpa, n_ids, opts, emb_init != null and opts.emb_freeze);
    var n: SmallNet = SmallNet.init(gpa, sm, rnd) catch |e| {
        var x = sm;
        x.ps.deinit(gpa);
        return e;
    };
    errdefer n.deinit(gpa);
    if (emb_init) |ei| try ei.table.apply(ei.vocab, &n.s, n.p);
    const w: Work = try .init(gpa, &n.s);
    defer w.deinit(gpa);
    const gr = try n.s.ps.alloc(gpa);
    defer gpa.free(gr);
    const best = try n.s.ps.alloc(gpa);
    defer gpa.free(best);
    var opt: nn.Adam = try .init(gpa, n.s.ps.len, .{ .lr = opts.lr });
    defer opt.deinit(gpa);
    const segs = try n.s.ps.segments(gpa);
    defer gpa.free(segs);
    const vpred = try gpa.alloc(f32, if (val) |v| v.len else 0);
    defer gpa.free(vpred);
    if (val) |v| initGate(&n, v, &w, vpred, opts.net == .resid);

    var f: SmallFit = .{
        .n = &n,
        .w = &w,
        .train = train,
        .val = val orelse &.{},
        .vpred = vpred,
        .gr = gr,
        .opt = &opt,
        .segs = segs,
        .keep = 1 - opts.dropout,
        .drop = if (opts.dropout > 0) rnd else null,
        .clip = opts.clip,
    };
    const r = try nn.fit(gpa, &f, .{
        .batch = opts.batch,
        .max_steps = max_steps,
        .evals_per_epoch = opts.evals,
        .patience = opts.patience,
        .validate = val != null,
    }, train.len, rnd, n.p, best);
    return .{ .net = n, .steps = r.steps, .epochs = r.epochs, .val_loss = r.loss };
}

/// gates.initLoss on val before the first step: the base rate's loss, or the offsets'
/// for resid (its output weights start at 0)
fn initGate(n: *const SmallNet, val: []const NetGame, w: *const Work, pred: []f32, resid: bool) void {
    predictSmall(n, val, w, pred);
    var init: f64 = 0;
    var off: f64 = 0;
    var y: f64 = 0;
    for (val, pred) |g, q| {
        init += loss1(g.y, q);
        off += loss1(g.y, sigmoid(g.off));
        y += g.y;
    }
    const k: f64 = @floatFromInt(@max(val.len, 1));
    const ref = if (resid) off / k else gates.baseLoss(y / k);
    gates.initLoss(if (resid) "winnet resid" else "winnet small", init / k, ref);
}

/// For meiolol-lab health: the small (or resid) net trained on `train` for `steps` (0: at
/// init, no validation), then blue's chance on `scored` into pred; returns the parameters
/// (caller frees)
pub fn healthFit(gpa: std.mem.Allocator, opts: Options, seed: u32, n_ids: u32, train: []const NetGame, steps: u64, scored: []const NetGame, pred: []f32) ![]f32 {
    var t = try trainSmall(gpa, opts, seed, n_ids, train, null, steps, null);
    defer t.net.s.ps.deinit(gpa);
    errdefer gpa.free(t.net.p);
    const w: Work = try .init(gpa, &t.net.s);
    defer w.deinit(gpa);
    predictSmall(&t.net, scored, &w, pred);
    return t.net.p;
}

fn fitSmall(gpa: std.mem.Allocator, io: Io, opts: Options, seed: u32, s: Sets) !Fitted {
    const t0 = Io.Clock.awake.now(io);
    var table: ?EmbTable = if (opts.emb_init) |dir| try .load(gpa, io, dir, s.block, seed, opts.emb) else null;
    defer if (table) |*t| t.deinit();
    const init_inner: ?EmbInit = if (table) |*t| .{ .table = t, .vocab = s.vocab_inner } else null;
    const init_all: ?EmbInit = if (table) |*t| .{ .table = t, .vocab = s.vocab_all } else null;
    var tuned = try trainSmall(gpa, opts, seed, s.n_inner, s.inner, s.val, opts.max_epochs * stepsPerEpoch(s.inner.len, opts.batch), init_inner);
    tuned.net.deinit(gpa);
    var full = try trainSmall(gpa, opts, seed, s.n_all, s.fit, null, refitSteps(tuned.epochs, s.fit.len, opts.batch), init_all);
    defer full.net.deinit(gpa);
    const w: Work = try .init(gpa, &full.net.s);
    defer w.deinit(gpa);
    const pred = try gpa.alloc(f32, s.scored.len);
    predictSmall(&full.net, s.scored, &w, pred);
    if (opts.net == .resid) std.debug.print("netcheck: seed {d}: offset weight {d:.3}\n", .{ seed, full.net.s.a.at(full.net.p, 0).* });
    return .{ .pred = pred, .epochs = tuned.epochs, .val_loss = tuned.val_loss, .seconds = secondsSince(io, t0) };
}

const testing = std.testing;

test "small net: gradient matches finite differences at every depth" {
    const gpa = testing.allocator;
    const GameLoss = struct {
        n: *const SmallNet,
        w: *const Work,
        g: *const NetGame,
        fn loss(c: *const @This()) f64 {
            var p: [1]f32 = undefined;
            predictSmall(c.n, c.g[0..1], c.w, &p);
            return loss1(c.g.y, p[0]);
        }
    };
    for (1..4) |depth| {
        var rng: std.Random.DefaultPrng = .init(5);
        var n: SmallNet = try .init(gpa, try .init(gpa, 8, .{ .emb = 4, .hidden = 6, .depth = @intCast(depth) }, false), rng.random());
        defer n.deinit(gpa);
        const w: Work = try .init(gpa, &n.s);
        defer w.deinit(gpa);
        const g: NetGame = .{ .ids = .{ 5, 6, 7, 3, 4, 0, 1, 2, 5, 6 }, .platform = 2, .y = 1, .off = 0.3 };
        const gr = try n.s.ps.alloc(gpa);
        defer gpa.free(gr);
        gameGrad(&n, &g, &w, 1, 1, null, gr);
        try nn.expectGradient(&GameLoss{ .n = &n, .w = &w, .g = &g }, GameLoss.loss, n.p, gr, null, .{});
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
    var t = try trainSmall(gpa, opts, 1, n_ids, train, null, 8 * stepsPerEpoch(train.len, opts.batch), null);
    defer t.net.deinit(gpa);
    const w: Work = try .init(gpa, &t.net.s);
    defer w.deinit(gpa);
    var a = train[0];
    a.ids[0] = 5;
    a.ids[5] = 10;
    var b = a;
    for (0..5) |i| std.mem.swap(u32, &b.ids[i], &b.ids[i + 5]);
    var p: [2]f32 = undefined;
    predictSmall(&t.net, &.{ a, b }, &w, &p);
    // Swapping the teams flips the net's part; blue's side intercept stays
    try testing.expectApproxEqAbs(2 * t.net.s.c.at(t.net.p, 0).*, logit(p[0]) + logit(p[1]), 1e-4);
    try testing.expect(p[0] > 0.62);

    var ro = opts;
    ro.net = .resid;
    var t0 = try trainSmall(gpa, ro, 1, n_ids, train, null, 0, null);
    defer t0.net.deinit(gpa);
    a.off = 0.7;
    predictSmall(&t0.net, &.{a}, &w, p[0..1]);
    try testing.expectApproxEqAbs(sigmoid(0.7), p[0], 1e-6);
}

test "auc: both orientations, ties share ranks" {
    const gpa = testing.allocator;
    try testing.expectApproxEqAbs(@as(f64, 1), try auc(gpa, &.{ 1, 0, 1 }, &.{ 0.8, 0.3, 0.6 }), 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0.5), try auc(gpa, &.{ 1, 0 }, &.{ 0.5, 0.5 }), 1e-12);
}

test "emb init: a table's vectors by champion-role, the role's shared one otherwise, frozen stays" {
    const gpa = testing.allocator;
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = "emb-dev-s1.tsv", .data = "champion\trole\tfit_games\te0\te1\n" ++
        "0\t0\t5\t0.1\t0.2\n0\t1\t5\t0.3\t0.4\n0\t2\t5\t0\t0\n0\t3\t5\t0\t0\n0\t4\t5\t0\t0\n" ++
        "7\t0\t90\t1.5\t-2\n" });
    const dir = try std.fmt.allocPrint(gpa, ".zig-cache/tmp/{s}", .{&tmp.sub_path});
    defer gpa.free(dir);
    try testing.expectError(error.EmbDim, EmbTable.load(gpa, io, dir, .dev, 2, 3));
    var t: EmbTable = try .load(gpa, io, dir, .dev, 2, 2);
    defer t.deinit();
    var v: Vocab = .{};
    defer v.deinit(gpa);
    try v.map.put(gpa, key(7, 0), 5);
    try v.map.put(gpa, key(9, 1), 6);
    var rng: std.Random.DefaultPrng = .init(1);
    var n: SmallNet = try .init(gpa, try .init(gpa, 7, .{ .emb = 2, .hidden = 4 }, false), rng.random());
    defer n.deinit(gpa);
    try t.apply(&v, &n.s, n.p);
    try testing.expectEqualSlices(f32, &.{ 0.1, 0.2 }, n.s.e.row(n.p, 0));
    try testing.expectEqualSlices(f32, &.{ 1.5, -2 }, n.s.e.row(n.p, 5));
    try testing.expectEqualSlices(f32, &.{ 0.3, 0.4 }, n.s.e.row(n.p, 6));

    const games: [64]NetGame = @splat(.{ .ids = .{ 5, 6, 2, 3, 4, 0, 1, 2, 3, 4 }, .platform = 0, .y = 1, .off = 0 });
    const opts: Options = .{ .emb = 2, .hidden = 4, .dropout = 0, .wd = 0, .lr = 1e-2, .batch = 8, .emb_init = dir, .emb_freeze = true };
    var tr = try trainSmall(gpa, opts, 1, 7, &games, null, 20, .{ .table = &t, .vocab = &v });
    defer tr.net.deinit(gpa);
    try testing.expectEqualSlices(f32, n.s.e.of(n.p), tr.net.s.e.of(tr.net.p));
}

test "cross-fit: a game's offset never comes from a fit that holds it" {
    const c: harness.Cuts = .{ .dev = 10_000, .test_ = 20_000, .bounds = @splat(0) };
    const spec: Spec = .{ .before = 10_000, .lo = 8_000, .hi = 10_000, .dev = false };
    var seen: [cross_folds]u32 = @splat(0);
    for (0..500) |i| {
        const g: rows.Game = .{
            .match_id = "",
            .start = @intCast(i * 13),
            .patch = 0,
            .platform = @intCast(i % 3),
            .is_test = false,
            .teams = @splat(@splat(0)),
            .winner = 0,
            .duration_s = 1800,
        };
        const all: FitKeep = .{ .spec = spec, .c = c, .fraction = 1 };
        try testing.expect(all.keep(g));
        seen[crossFold(g)] += 1;
        for (0..cross_folds) |f| {
            var k = all;
            k.without = @intCast(f);
            try testing.expectEqual(crossFold(g) != f, k.keep(g));
        }
    }
    for (seen) |n| try testing.expect(n > 50);
}

test "fit preds: a fifth's net never fits a game it scores, the fifths cover the fit games" {
    const c: harness.Cuts = .{ .dev = 10_000, .test_ = 20_000, .bounds = @splat(0) };
    const spec: Spec = .{ .before = 8_000, .lo = 8_000, .hi = 10_000, .dev = false };
    for (0..800) |i| {
        const g: rows.Game = .{
            .match_id = "",
            .start = @intCast(i * 13),
            .patch = 0,
            .platform = @intCast(i % 3),
            .is_test = false,
            .teams = @splat(@splat(0)),
            .winner = 0,
            .duration_s = 1800,
        };
        var scored_in: u32 = 0;
        for (0..cross_folds) |f| {
            var sf = spec;
            sf.fifth = @intCast(f);
            const sc = sf.scores(c, g, 1);
            try testing.expect(!(sc and sf.fits(c, g, 1)));
            if (sc) scored_in += 1;
        }
        try testing.expectEqual(@as(u32, @intFromBool(spec.fits(c, g, 1))), scored_in);
    }
}

test "test block: fits every played game before the test cut, scores the played test games, alone" {
    const c: harness.Cuts = .{ .dev = 10_000, .test_ = 20_000, .bounds = @splat(0) };
    const spec: Spec = .{ .before = c.test_, .lo = c.test_, .hi = std.math.maxInt(i64), .dev = false, .final = true };
    var n_fit: u32 = 0;
    var n_dev_val: u32 = 0;
    var n_scored: u32 = 0;
    for (0..4000) |i| {
        const start: i64 = @intCast(i * 7);
        const played = i % 5 != 0;
        const g: rows.Game = .{
            .match_id = "",
            .start = start,
            .patch = 0,
            .platform = @intCast(i % 3),
            .is_test = start >= c.test_,
            .teams = @splat(@splat(0)),
            .winner = 0,
            .duration_s = if (played) harness.min_duration_s else harness.min_duration_s - 1,
        };
        const fit = spec.fits(c, g, 1);
        const sc = spec.scores(c, g, 1);
        try testing.expectEqual(played and start < c.test_, fit);
        try testing.expectEqual(played and start >= c.test_, sc);
        n_fit += @intFromBool(fit);
        n_dev_val += @intFromBool(fit and start >= c.dev);
        n_scored += @intFromBool(sc);
    }
    try testing.expect(n_dev_val > 0 and n_scored > 0 and n_fit > n_dev_val);

    const a = testing.allocator;
    var arena: std.heap.ArenaAllocator = .init(a);
    defer arena.deinit();
    const o = try parseOptions(arena.allocator(), &.{ "--net", "big", "--blocks", "test" });
    try testing.expectEqualSlices(Block, &.{.final}, o.blocks);
    try testing.expectError(error.TestBlockAlone, parseOptions(arena.allocator(), &.{ "--blocks", "test,1" }));
    try testing.expectError(error.NotForTest, parseOptions(arena.allocator(), &.{ "--blocks", "test", "--resample", "1" }));
    try testing.expectError(error.NotForTest, parseOptions(arena.allocator(), &.{ "--blocks", "test", "--window", "newest:10" }));
    try testing.expectError(error.WindowWithFraction, parseOptions(arena.allocator(), &.{ "--window", "spread:10", "--fraction", "0.5" }));
    try testing.expectError(error.BadWindow, parseOptions(arena.allocator(), &.{ "--window", "latest:10" }));
    const win = (try parseOptions(arena.allocator(), &.{ "--window", "oldest:500000" })).window.?;
    try testing.expectEqual(500000, win.n);
    try testing.expectEqual(.oldest, win.kind);
}

test "window: each kind keeps N of the block's fit games, newest and oldest by start" {
    const c: harness.Cuts = .{ .dev = 10_000, .test_ = 20_000, .bounds = @splat(0) };
    var games: [1000]rows.Game = undefined;
    for (&games, 0..) |*g, i| g.* = .{
        .match_id = "",
        .start = @intCast(i * 13),
        .patch = 0,
        .platform = @intCast(i % 3),
        .is_test = false,
        .teams = @splat(@splat(0)),
        .winner = 0,
        .duration_s = 1800,
    };
    const base: Spec = .{ .before = 8_000, .lo = 8_000, .hi = 10_000, .dev = false };
    var all: usize = 0;
    for (games) |g| all += @intFromBool(base.fits(c, g, 1));
    var discard: Io.Writer.Allocating = .init(testing.allocator);
    defer discard.deinit();
    for ([_]@FieldType(Window, "kind"){ .newest, .oldest, .spread }) |kind| {
        var spec = base;
        try (Window{ .kind = kind, .n = 200 }).apply(testing.allocator, &games, c, &spec, 1, &discard.writer);
        var n: usize = 0;
        var lo: i64 = std.math.maxInt(i64);
        var hi: i64 = 0;
        for (games) |g| if (spec.fits(c, g, 1)) {
            n += 1;
            lo = @min(lo, g.start);
            hi = @max(hi, g.start);
        };
        switch (kind) {
            .newest, .oldest => try testing.expectEqual(200, n),
            .spread => try testing.expect(n > 150 and n < 250),
        }
        if (kind == .newest) try testing.expect(lo > 4_000);
        if (kind == .oldest) try testing.expect(hi < 4_000);
        if (kind == .spread) try testing.expect(lo < 500 and hi > 7_500);
    }
    var spec = base;
    try testing.expectError(error.WindowTooBig, (Window{ .kind = .newest, .n = all + 1 }).apply(testing.allocator, &games, c, &spec, 1, &discard.writer));
}

test {
    _ = setnet;
}

test "shuffle ids: whole champion rows move together, labels and offsets stay" {
    var games: [50]NetGame = undefined;
    for (&games, 0..) |*g, i| {
        const k: u32 = @intCast(i);
        g.* = .{ .ids = .{ k, k + 100, k + 200, k + 300, k + 400, k + 500, k + 600, k + 700, k + 800, k + 900 }, .platform = 0, .y = @floatFromInt(i % 2), .off = @floatFromInt(i) };
    }
    shuffleIds(&games, 7, 0);
    var seen: [50]bool = @splat(false);
    var moved: usize = 0;
    for (games, 0..) |g, i| {
        const k = g.ids[0];
        for (g.ids, 0..) |id, s| try testing.expectEqual(k + 100 * @as(u32, @intCast(s)), id);
        try testing.expect(!seen[k]);
        seen[k] = true;
        if (k != i) moved += 1;
        try testing.expectEqual(@as(f32, @floatFromInt(i % 2)), g.y);
        try testing.expectEqual(@as(f32, @floatFromInt(i)), g.off);
    }
    try testing.expect(moved > 25);
}

test "health fit: a resid net at step 0 predicts its offsets" {
    const gpa = testing.allocator;
    var o: Options = .{};
    o.net = .resid;
    var games: [8]NetGame = undefined;
    for (&games, 0..) |*g, i| g.* = .{ .ids = .{ 5, 6, 2, 3, 4, 0, 1, 2, 3, 4 }, .platform = 0, .y = 1, .off = @as(f32, @floatFromInt(i)) / 4 - 1 };
    var pred: [8]f32 = undefined;
    const p = try healthFit(gpa, o, 1, 8, &games, 0, &games, &pred);
    defer gpa.free(p);
    for (pred, games) |q, g| try testing.expectApproxEqAbs(sigmoid(g.off), q, 1e-6);
}
