//! `meiolol-lab playernet SNAP`: player-history nets for win from the draft, internal
//! scope only (Jacob's predictor, never the site or app). Per slot, the champion-role's
//! embedding (plus the role's) and that player's pre-game features go through one hidden
//! ReLU layer to a number; a team's value is the sum over its five slots, and
//! logit = c[platform] + a * offset + blue's - red's (antisymmetric by construction).
//! The offset is the compiled-in candidate's logit (-Dcand: win-ratings with or without
//! its hand-made experience terms), output weights start at 0, so the net starts as the
//! candidate and can only add what it misses: player x champion interactions and
//! non-linear experience curves.
//! Blocks, offsets and scoring as winnet's resid (dev-val and win-comp's 5 forward folds;
//! training offsets cross-fitted over 5 hashed folds of the fit games, early stopping on
//! the newest 10% of fit games, refit on all for a tenth more epochs). Feature scaling
//! from fit rows only.
//! Features per player (groups for --feats): champ: log1p games on the champion, its
//! shrunk win rate's log-odds (5 pseudo-games at 50%), played it before; any: the same on
//! any champion, share of games on this one; form: mean KDA, lane gold diff at 14, deaths
//! before 15 (0 when unknown); rank: rank at game start and known; mastery: log1p
//! pre-game points on the champion and known (SNAP/mastery_pre.tsv when present); prior
//! (QuickSkill-style): gold, CS and damage per minute over earlier games, off-role share,
//! log1p days since the last game; duo: teammates played with before and the most games
//! with one of them (premade).
//! Writes DIR/folds.tsv, DIR/preds.tsv (as netcheck's, plus per side b_/r_: players with
//! history, with games on their champion, games on their champions, games, players with
//! rank, with mastery) and DIR/coverage.tsv (feature coverage of rows per block and part;
//! test rows' features only, never outcomes)

const std = @import("std");
const api = @import("api");
const cand = @import("cand");
const rows = @import("rows.zig");
const protocol = @import("protocol.zig");
const harness = @import("harness.zig");
const winnet = @import("winnet.zig");
const gates = @import("gates.zig");
const mastery_pre = @import("mastery_pre.zig");
const nn = @import("nn");
const par = @import("../par.zig");

const Io = std.Io;
const Spec = winnet.Spec;
const FitKeep = winnet.FitKeep;
const candBlue = winnet.candBlue;
const candCross = winnet.candCross;
const Pooled = winnet.Pooled;
const Vocab = winnet.Vocab;
const EmbTable = winnet.EmbTable;
const EmbInit = winnet.EmbInit;
const n_platforms = winnet.n_platforms;
const logit = nn.logit;
const loss1 = nn.logLoss;
const sigmoid = winnet.sigmoid;
const secondsSince = winnet.secondsSince;
const meanLoss = winnet.meanLoss;
const pairedGain = winnet.pairedGain;
const auc = winnet.auc;
const refitSteps = winnet.refitSteps;

pub const usage =
    \\  playernet SNAP [OPT VALUE]...   player-history net residual on the -Dcand
    \\                                  candidate (internal scope; lab/playernet.zig):
    \\                                  --emb N (0: no champion-role) --hidden N
    \\                                  --dropout X --wd X --emb-wd X --lr X --clip X
    \\                                  --batch N --evals N --patience N --max-epochs N
    \\                                  --min-games N --fix-offset 0|1
    \\                                  --shuffle-labels 0|1 (control: the net trains on
    \\                                  permuted outcomes, scored on real ones)
    \\                                  --shuffle-feats 0|1 (control: players' feature
    \\                                  vectors permuted within role in training sets)
    \\                                  --feats champ,any,form,rank,mastery,prior,duo|none
    \\                                  --drop FEAT,... (single features off within the
    \\                                  groups on, e.g. gpm,days_since: ablations)
    \\                                  --emb-init DIR (pretrain's emb-<block>-s<seed>.tsv)
    \\                                  --seeds 1,2,3 --blocks dev,1,2,3,4,5
    \\                                  --resample N (fit games and the candidate's on
    \\                                  netcheck's seeded 90%; scored games unchanged)
    \\                                  --dump 0|1 (the net's inputs per block and set
    \\                                  to DIR/net-*.bin, for cross-checks)
    \\                                  --fraction X --threads N --out DIR
    \\
;

pub const Group = enum { champ, any, form, rank, mastery, prior, duo };

const Feat = enum {
    champ_games,
    champ_wr,
    champ_played,
    games,
    wr,
    any_played,
    champ_share,
    kda,
    lanediff14,
    deaths15,
    rank,
    rank_known,
    mastery,
    mastery_known,
    gpm,
    cspm,
    dpm,
    offrole,
    days_since,
    duo_mates,
    duo_games,

    fn group(f: Feat) Group {
        return switch (f) {
            .champ_games, .champ_wr, .champ_played => .champ,
            .games, .wr, .any_played, .champ_share => .any,
            .kda, .lanediff14, .deaths15 => .form,
            .rank, .rank_known => .rank,
            .mastery, .mastery_known => .mastery,
            .gpm, .cspm, .dpm, .offrole, .days_since => .prior,
            .duo_mates, .duo_games => .duo,
        };
    }

    /// Flags stay 0/1; the rest are standardised over fit rows where known
    fn flag(f: Feat) bool {
        return switch (f) {
            .champ_played, .any_played, .rank_known, .mastery_known => true,
            else => false,
        };
    }
};
const n_feat = @typeInfo(Feat).@"enum".field_names.len;

pub const Options = struct {
    /// 0: no champion-role or role embedding, the player's features only
    emb: u32 = 8,
    hidden: u32 = 32,
    dropout: f32 = 0.1,
    wd: f32 = 0.1,
    emb_wd: ?f32 = null,
    clip: f32 = 1,
    fix_offset: bool = false,
    /// Control: outcomes permuted among the net's training and validation games (offsets
    /// stay the candidate's on real outcomes); its gain on scored games must be ~0 or worse
    shuffle_labels: bool = false,
    /// Control: each player's feature vector permuted across games and sides within role
    /// in the training and validation sets (outcomes and offsets real, scored games
    /// untouched); a gain well past the noise floor means a leak
    shuffle_feats: bool = false,
    groups: [@typeInfo(Group).@"enum".field_names.len]bool = @splat(true),
    /// Features off though their group is on (--drop)
    drop: [n_feat]bool = @splat(false),
    emb_init: ?[]const u8 = null,
    evals: u32 = 4,
    lr: f32 = 1e-3,
    batch: u32 = 512,
    patience: u32 = 5,
    max_epochs: u32 = 60,
    min_games: u32 = 10,
    seeds: []const u32 = &.{1},
    blocks: []const Block = &.{ .dev, .f1, .f2, .f3, .f4, .f5 },
    fraction: f64 = 1,
    /// Fit games and the candidate's on netcheck's seeded random 90% (noise-floor resamples)
    resample: ?u32 = null,
    /// Write each block's net inputs (dumpSet) for re-implementations to train on
    dump: bool = false,
    threads: u32 = 3,
    out: []const u8 = ".",
};

pub const Block = enum { dev, f1, f2, f3, f4, f5 };
const n_folds = harness.folds;
const val_share = 0.1;
pub fn main(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: Io, argv: []const []const u8) !u8 {
    if (argv.len < 1) {
        std.debug.print("usage:\n{s}", .{usage});
        return 2;
    }
    const opts = parseOptions(arena, argv[1..]) catch |e| {
        std.debug.print("playernet: {s}\nusage:\n{s}", .{ @errorName(e), usage });
        return 2;
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
    var mastery = try Mastery.load(gpa, io, snap);
    defer mastery.deinit(gpa);
    const raw = try rawFeatures(gpa, &data, &mastery);
    defer gpa.free(raw);

    try Io.Dir.cwd().createDirPath(io, opts.out);
    var dir = try Io.Dir.cwd().openDir(io, opts.out, .{});
    defer dir.close(io);
    var folds_file = try dir.createFile(io, "folds.tsv", .{});
    defer folds_file.close(io);
    var fbuf: [16 * 1024]u8 = undefined;
    var fw = folds_file.writer(io, &fbuf);
    try fw.interface.writeAll("seed\tfold\tfit_games\tscored_games\tlogloss\tcand_logloss\tgain\tgain_se\tepochs\tseconds\tval_logloss\tauc\tcand_auc\toffset_weight\n");
    var preds_file = try dir.createFile(io, "preds.tsv", .{});
    defer preds_file.close(io);
    var pbuf: [64 * 1024]u8 = undefined;
    var pw = preds_file.writer(io, &pbuf);
    try pw.interface.writeAll("fold\tmatch_id\tplatform\ty\tcand");
    for (opts.seeds) |s| try pw.interface.print("\tseed{d}", .{s});
    try pw.interface.writeAll("\tens");
    for ([_][]const u8{ "b", "r" }) |side| for (count_names) |cn| try pw.interface.print("\t{s}_{s}", .{ side, cn });
    try pw.interface.writeAll("\n");
    var cov_file = try dir.createFile(io, "coverage.tsv", .{});
    defer cov_file.close(io);
    var cbuf: [16 * 1024]u8 = undefined;
    var cw = cov_file.writer(io, &cbuf);
    try cw.interface.writeAll("block\tpart\trows\tany_games\tchamp_games\tchamp_10plus\trank_start\tmastery_pre\n");

    var out_buf: [4096]u8 = undefined;
    var stdout = Io.File.stdout().writer(io, &out_buf);
    const w = &stdout.interface;
    try w.print("# playernet vs {s}, fraction {d}, resample {?d}, seeds {any}\n\n", .{ if (@hasDecl(cand, "name")) cand.name else "cand", opts.fraction, opts.resample, opts.seeds });
    try w.print("options: emb {d} hidden {d} dropout {d} wd {d} emb_wd {d} lr {d} clip {d} batch {d} evals {d} patience {d} min_games {d} fix_offset {} shuffle_labels {} shuffle_feats {} emb_init {s} feats", .{
        opts.emb, opts.hidden, opts.dropout, opts.wd, opts.emb_wd orelse opts.wd, opts.lr, opts.clip, opts.batch, opts.evals, opts.patience, opts.min_games, opts.fix_offset, opts.shuffle_labels, opts.shuffle_feats, opts.emb_init orelse "-",
    });
    for (opts.groups, 0..) |on, gi| if (on) try w.print(" {s}", .{@tagName(@as(Group, @fromBackingInt(@intCast(gi))))});
    for (opts.drop, 0..) |off, f| if (off) try w.print(" -{s}", .{@tagName(@as(Feat, @fromBackingInt(@intCast(f))))});
    try w.print("\nmastery_pre.tsv: {d} participants\n\n", .{mastery.map.count()});
    try w.flush();

    // Test rows' feature coverage (no outcomes): how thin the test look would be
    {
        var test_rows: std.ArrayList(u32) = .empty;
        defer test_rows.deinit(gpa);
        for (data.rows, 0..) |r, i| if (harness.scored(.final, c, data.games[r.game])) try test_rows.append(gpa, @intCast(i));
        try coverageLine(&cw.interface, "test", "scored", &data, raw, test_rows.items);
    }

    var pooled: Pooled = .{};
    defer pooled.deinit(gpa);
    for (opts.blocks) |b| {
        var spec: Spec = switch (b) {
            .dev => .{ .before = c.dev, .lo = c.dev, .hi = c.test_, .dev = true },
            else => blk: {
                const f = c.fold(@backingInt(b));
                break :blk .{ .before = f.lo, .lo = f.lo, .hi = f.hi, .dev = false };
            },
        };
        spec.resample = opts.resample;
        try runBlock(gpa, io, &data, players, raw, c, spec, b, opts, &fw.interface, &pw.interface, &cw.interface, w, &pooled);
    }
    if (pooled.cand.items.len > 0) {
        try w.writeAll("\nfolds pooled (blocks 1-5 run here):\n");
        try summaryHead(w);
        try summaryRow(gpa, w, "folds", pooled.ys.items, pooled.cand.items, pooled.ens.items, null);
    }
    try fw.interface.flush();
    try pw.interface.flush();
    try cw.interface.flush();
    try w.flush();
    return 0;
}

fn parseOptions(arena: std.mem.Allocator, args: []const []const u8) !Options {
    var o: Options = .{};
    var i: usize = 0;
    while (i < args.len) : (i += 2) {
        if (i + 1 >= args.len) return error.MissingValue;
        const k = args[i];
        const v = args[i + 1];
        if (std.mem.eql(u8, k, "--emb")) {
            o.emb = try std.fmt.parseInt(u32, v, 10);
        } else if (std.mem.eql(u8, k, "--hidden")) {
            o.hidden = try std.fmt.parseInt(u32, v, 10);
        } else if (std.mem.eql(u8, k, "--emb-wd")) {
            o.emb_wd = try std.fmt.parseFloat(f32, v);
        } else if (std.mem.eql(u8, k, "--clip")) {
            o.clip = try std.fmt.parseFloat(f32, v);
        } else if (std.mem.eql(u8, k, "--shuffle-feats")) {
            o.shuffle_feats = (try std.fmt.parseInt(u1, v, 10)) == 1;
        } else if (std.mem.eql(u8, k, "--shuffle-labels")) {
            o.shuffle_labels = (try std.fmt.parseInt(u1, v, 10)) == 1;
        } else if (std.mem.eql(u8, k, "--fix-offset")) {
            o.fix_offset = (try std.fmt.parseInt(u1, v, 10)) == 1;
        } else if (std.mem.eql(u8, k, "--drop")) {
            var it = std.mem.tokenizeScalar(u8, v, ',');
            while (it.next()) |f| o.drop[@backingInt(std.meta.stringToEnum(Feat, f) orelse return error.UnknownFeat)] = true;
        } else if (std.mem.eql(u8, k, "--feats")) {
            o.groups = @splat(false);
            if (!std.mem.eql(u8, v, "none")) {
                var it = std.mem.tokenizeScalar(u8, v, ',');
                while (it.next()) |s| o.groups[@backingInt(std.meta.stringToEnum(Group, s) orelse return error.UnknownFeats)] = true;
            }
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
        } else if (std.mem.eql(u8, k, "--dump")) {
            o.dump = (try std.fmt.parseInt(u1, v, 10)) == 1;
        } else if (std.mem.eql(u8, k, "--resample")) {
            o.resample = try std.fmt.parseInt(u32, v, 10);
        } else if (std.mem.eql(u8, k, "--fraction")) {
            o.fraction = try std.fmt.parseFloat(f64, v);
        } else if (std.mem.eql(u8, k, "--threads")) {
            o.threads = try std.fmt.parseInt(u32, v, 10);
        } else if (std.mem.eql(u8, k, "--emb-init")) {
            o.emb_init = v;
        } else if (std.mem.eql(u8, k, "--out")) {
            o.out = v;
        } else return error.UnknownOption;
    }
    if (o.emb_init != null and o.emb == 0) return error.EmbInitNeedsEmb;
    for (o.blocks) |b| if (@backingInt(b) > n_folds) return error.BadBlock;
    if (o.hidden == 0 or o.evals == 0 or o.dropout < 0 or o.dropout >= 1 or o.fraction <= 0 or o.threads == 0) return error.BadValue;
    return o;
}

/// SNAP/mastery_pre.tsv's points per (match, slot); empty when the file is missing
const Mastery = struct {
    map: std.AutoHashMapUnmanaged(u64, u32) = .empty,

    fn load(gpa: std.mem.Allocator, io: Io, snap: []const u8) !Mastery {
        var m: Mastery = .{};
        const path = try std.fs.path.join(gpa, &.{ snap, mastery_pre.file_name });
        defer gpa.free(path);
        const text = Io.Dir.cwd().readFileAlloc(io, path, gpa, .limited(4 << 30)) catch |e| switch (e) {
            error.FileNotFound => return m,
            else => return e,
        };
        defer gpa.free(text);
        var lines = std.mem.tokenizeScalar(u8, text, '\n');
        _ = lines.next();
        while (lines.next()) |line| {
            var it = std.mem.splitScalar(u8, line, '\t');
            const match_id = it.next() orelse return error.MasteryFormat;
            const slot = try std.fmt.parseInt(u8, it.next() orelse return error.MasteryFormat, 10);
            _ = it.next() orelse return error.MasteryFormat;
            _ = it.next() orelse return error.MasteryFormat;
            const points = try std.fmt.parseInt(u32, it.next() orelse return error.MasteryFormat, 10);
            try m.map.put(gpa, mkey(match_id, slot), points);
        }
        return m;
    }

    fn deinit(m: *Mastery, gpa: std.mem.Allocator) void {
        m.map.deinit(gpa);
    }

    fn mkey(match_id: []const u8, slot: u8) u64 {
        return (std.hash.Wyhash.hash(0x3a57, match_id) << 4) | slot;
    }
};

/// Per row, before scaling; NaN unknown (form without games, rank, mastery)
fn rawFeatures(gpa: std.mem.Allocator, d: *const rows.Data, m: *const Mastery) ![][n_feat]f32 {
    const duo = try coPlay(gpa, d);
    defer gpa.free(duo);
    const out = try gpa.alloc([n_feat]f32, d.rows.len);
    const nan = std.math.nan(f32);
    for (out, d.rows, 0..) |*o, r, i| {
        const cg: f32 = @floatFromInt(r.champ_games);
        const cw: f32 = @floatFromInt(r.champ_wins);
        const ag: f32 = @floatFromInt(r.games_before);
        const aw: f32 = @floatFromInt(r.wins_before);
        const pts = m.map.get(Mastery.mkey(d.games[r.game].match_id, r.slot));
        o.* = @splat(nan);
        o[@backingInt(Feat.champ_games)] = std.math.log1p(cg);
        o[@backingInt(Feat.champ_wr)] = @log((cw + 2.5) / (cg - cw + 2.5));
        o[@backingInt(Feat.champ_played)] = @floatFromInt(@intFromBool(r.champ_games > 0));
        o[@backingInt(Feat.games)] = std.math.log1p(ag);
        o[@backingInt(Feat.wr)] = @log((aw + 2.5) / (ag - aw + 2.5));
        o[@backingInt(Feat.any_played)] = @floatFromInt(@intFromBool(r.games_before > 0));
        o[@backingInt(Feat.champ_share)] = if (r.games_before > 0) cg / ag else 0;
        if (r.games_before > 0) o[@backingInt(Feat.kda)] = r.kda_before;
        if (r.perf_games > 0) {
            o[@backingInt(Feat.lanediff14)] = r.lanediff14_before;
            o[@backingInt(Feat.deaths15)] = r.deaths15_before;
        }
        if (r.rank_start) |rk| o[@backingInt(Feat.rank)] = @floatFromInt(rk);
        o[@backingInt(Feat.rank_known)] = @floatFromInt(@intFromBool(r.rank_start != null));
        if (pts) |p| o[@backingInt(Feat.mastery)] = std.math.log1p(@as(f32, @floatFromInt(p)));
        o[@backingInt(Feat.mastery_known)] = @floatFromInt(@intFromBool(pts != null));
        o[@backingInt(Feat.gpm)] = r.gpm_before;
        o[@backingInt(Feat.cspm)] = r.cspm_before;
        o[@backingInt(Feat.dpm)] = r.dpm_before;
        o[@backingInt(Feat.offrole)] = r.offrole_before;
        o[@backingInt(Feat.days_since)] = std.math.log1p(r.days_since_last);
        o[@backingInt(Feat.duo_mates)] = @floatFromInt(duo[i][0]);
        o[@backingInt(Feat.duo_games)] = std.math.log1p(@as(f32, @floatFromInt(duo[i][1])));
    }
    return out;
}

/// Per row: teammates this player had played with on the same team before, and the most
/// games with any one of them (games ended by this one's start, as fillExperience;
/// TrueSkill 2's premade signal)
fn coPlay(gpa: std.mem.Allocator, d: *const rows.Data) ![][2]u16 {
    const out = try gpa.alloc([2]u16, d.rows.len);
    @memset(out, @splat(0));
    const by_game = try gpa.alloc([10]u32, d.games.len);
    defer gpa.free(by_game);
    @memset(by_game, @splat(no_row));
    for (d.rows, 0..) |r, i| by_game[r.game][@as(usize, r.side) * 5 + @backingInt(r.role)] = @intCast(i);
    const by_start = try gpa.alloc(u32, d.games.len);
    defer gpa.free(by_start);
    const by_end = try gpa.alloc(u32, d.games.len);
    defer gpa.free(by_end);
    for (by_start, by_end, 0..) |*a, *b, i| {
        a.* = @intCast(i);
        b.* = @intCast(i);
    }
    const Order = struct {
        games: []const rows.Game,
        fn end(o: @This(), i: u32) i64 {
            return o.games[i].start + @as(i64, o.games[i].duration_s) * 1000;
        }
        fn byStart(o: @This(), a: u32, b: u32) bool {
            return o.games[a].start < o.games[b].start;
        }
        fn byEnd(o: @This(), a: u32, b: u32) bool {
            return o.end(a) < o.end(b);
        }
    };
    const order: Order = .{ .games = d.games };
    std.mem.sort(u32, by_start, order, Order.byStart);
    std.mem.sort(u32, by_end, order, Order.byEnd);
    var pairs: std.AutoHashMapUnmanaged(u64, u16) = .empty;
    defer pairs.deinit(gpa);
    var done: usize = 0;
    for (by_start) |gi| {
        while (done < by_end.len and order.end(by_end[done]) <= d.games[gi].start) : (done += 1) {
            const slots = by_game[by_end[done]];
            for (0..2) |side| for (0..5) |a| for (a + 1..5) |b| {
                const k = pairKey(d, slots[side * 5 + a], slots[side * 5 + b]) orelse continue;
                const e = try pairs.getOrPutValue(gpa, k, 0);
                e.value_ptr.* +|= 1;
            };
        }
        const slots = by_game[gi];
        for (0..10) |s| {
            if (slots[s] == no_row) continue;
            const side = s / 5;
            for (0..5) |b| {
                if (side * 5 + b == s) continue;
                const k = pairKey(d, slots[s], slots[side * 5 + b]) orelse continue;
                const n = pairs.get(k) orelse 0;
                out[slots[s]][0] += @intFromBool(n > 0);
                out[slots[s]][1] = @max(out[slots[s]][1], n);
            }
        }
    }
    return out;
}

fn pairKey(d: *const rows.Data, ra: u32, rb: u32) ?u64 {
    if (ra == no_row or rb == no_row) return null;
    const a = d.rows[ra].player;
    const b = d.rows[rb].player;
    if (a == rows.no_player or b == rows.no_player) return null;
    return (@as(u64, @min(a, b)) << 32) | @max(a, b);
}

fn coverageLine(w: *Io.Writer, block: []const u8, part: []const u8, d: *const rows.Data, raw: []const [n_feat]f32, which: []const u32) !void {
    var n: [5]usize = @splat(0);
    for (which) |ri| {
        const r = d.rows[ri];
        n[0] += @intFromBool(r.games_before > 0);
        n[1] += @intFromBool(r.champ_games > 0);
        n[2] += @intFromBool(r.champ_games >= 10);
        n[3] += @intFromBool(r.rank_start != null);
        n[4] += @intFromBool(raw[ri][@backingInt(Feat.mastery_known)] > 0);
    }
    const t: f64 = @floatFromInt(@max(which.len, 1));
    try w.print("{s}\t{s}\t{d}", .{ block, part, which.len });
    for (n) |x| try w.print("\t{d:.4}", .{@as(f64, @floatFromInt(x)) / t});
    try w.writeAll("\n");
}

/// Means and sds of the non-flag features over fit rows where known
const Scale = struct {
    mean: [n_feat]f32 = @splat(0),
    sd: [n_feat]f32 = @splat(1),

    fn init(d: *const rows.Data, raw: []const [n_feat]f32, fit_game: []const bool) Scale {
        var s1: [n_feat]f64 = @splat(0);
        var s2: [n_feat]f64 = @splat(0);
        var cnt: [n_feat]f64 = @splat(0);
        for (d.rows, raw) |r, x| {
            if (!fit_game[r.game]) continue;
            for (x, 0..) |v, f| if (!std.math.isNan(v)) {
                s1[f] += v;
                s2[f] += v * v;
                cnt[f] += 1;
            };
        }
        var s: Scale = .{};
        for (0..n_feat) |f| {
            if (@as(Feat, @fromBackingInt(@intCast(f))).flag() or cnt[f] < 2) continue;
            const m = s1[f] / cnt[f];
            s.mean[f] = @floatCast(m);
            s.sd[f] = @floatCast(@max(@sqrt(@max(s2[f] / cnt[f] - m * m, 0)), 1e-3));
        }
        return s;
    }

    /// Unknown values sit at the fit mean (0 after scaling); features off are 0
    fn apply(s: Scale, x: [n_feat]f32, on: [n_feat]bool) [n_feat]f32 {
        var out: [n_feat]f32 = @splat(0);
        for (x, 0..) |v, f| {
            if (!on[f] or std.math.isNan(v)) continue;
            out[f] = (v - s.mean[f]) / s.sd[f];
        }
        return out;
    }
};

/// One game as the net sees it: slots blue by role, then red
/// DIR/net-BLOCK-PART.bin: per game, little-endian 4-byte values: ids u32[10] (slots blue
/// top..support then red; 0 = rare or unseen champion-role), x f32[10][n_feat] (scaled as
/// the net sees them, after any --shuffle-feats), platform, y (blue won), off (the
/// candidate's logit) as f32. DIR/net-BLOCK-PART.txt: n_ids, n_feat and feature names on
/// one line, then the match ids in record order. inner and val share a vocabulary and
/// scaling; fit and scored share the other
const dump_len = 10 + 10 * n_feat + 3;

fn dumpSet(io: Io, d: *const rows.Data, out: []const u8, block: []const u8, part: []const u8, set: []const NetGame, games: []const u32, n_ids: usize) !void {
    var dir = try Io.Dir.cwd().openDir(io, out, .{});
    defer dir.close(io);
    var name_buf: [64]u8 = undefined;
    var bin = try dir.createFile(io, try std.fmt.bufPrint(&name_buf, "net-{s}-{s}.bin", .{ block, part }), .{});
    defer bin.close(io);
    var bbuf: [64 * 1024]u8 = undefined;
    var bw = bin.writer(io, &bbuf);
    comptime std.debug.assert(@import("builtin").cpu.arch.endian() == .little);
    for (set) |g| {
        var rec: [dump_len]u32 = undefined;
        for (g.ids, 0..) |id, i| rec[i] = id;
        for (g.x, 0..) |x, slot| for (x, 0..) |v, f| {
            rec[10 + slot * n_feat + f] = @bitCast(v);
        };
        for ([_]f32{ @floatFromInt(g.platform), g.y, g.off }, 0..) |v, i| rec[10 + 10 * n_feat + i] = @bitCast(v);
        try bw.interface.writeAll(std.mem.sliceAsBytes(&rec));
    }
    try bw.interface.flush();
    var txt = try dir.createFile(io, try std.fmt.bufPrint(&name_buf, "net-{s}-{s}.txt", .{ block, part }), .{});
    defer txt.close(io);
    var tbuf: [64 * 1024]u8 = undefined;
    var tw = txt.writer(io, &tbuf);
    try tw.interface.print("n_ids {d} n_feat {d}", .{ n_ids, n_feat });
    for (@typeInfo(Feat).@"enum".field_names) |f| try tw.interface.print(" {s}", .{f});
    try tw.interface.writeAll("\n");
    for (games) |gi| try tw.interface.print("{s}\n", .{d.games[gi].match_id});
    try tw.interface.flush();
}

pub const NetGame = struct {
    ids: [10]u32,
    x: [10][n_feat]f32,
    platform: u8,
    y: f32,
    /// The candidate's logit for blue
    off: f32,
};

/// Per feature: its group on and not dropped
fn featsOn(opts: Options) [n_feat]bool {
    var on: [n_feat]bool = undefined;
    for (&on, 0..) |*o, f| o.* = opts.groups[@backingInt(@as(Feat, @fromBackingInt(@intCast(f))).group())] and !opts.drop[f];
    return on;
}

fn netGames(gpa: std.mem.Allocator, d: *const rows.Data, raw: []const [n_feat]f32, row_of: []const [10]u32, games: []const u32, vocab: *const Vocab, scale: Scale, on: [n_feat]bool, off: []const f32) ![]NetGame {
    const out = try gpa.alloc(NetGame, games.len);
    for (out, games) |*o, gi| {
        const g = d.games[gi];
        o.* = .{ .ids = vocab.ids(g), .x = undefined, .platform = g.platform, .y = if (g.winner == 0) 1 else 0, .off = logit(off[gi]) };
        for (0..10) |slot| {
            const ri = row_of[gi][slot];
            o.x[slot] = if (ri == no_row) @splat(0) else scale.apply(raw[ri], on);
        }
    }
    return out;
}

const no_row = std.math.maxInt(u32);

const count_names = [_][]const u8{ "history", "champ", "champ_games", "games", "rank", "mastery" };

/// Each game's row index by slot (side * 5 + role)
fn shuffleFeats(games: []NetGame, seed: u64) void {
    var rng: std.Random.DefaultPrng = .init(seed);
    const rnd = rng.random();
    for (0..5) |role| {
        // Seat k of 2 * games.len: game k / 2, side k % 2
        var i = 2 * games.len;
        while (i > 1) : (i -= 1) {
            const j = rnd.uintLessThan(usize, i);
            std.mem.swap([n_feat]f32, &games[(i - 1) / 2].x[(i - 1) % 2 * 5 + role], &games[j / 2].x[j % 2 * 5 + role]);
        }
    }
}

fn shuffleLabels(games: []NetGame, seed: u64) void {
    var rng: std.Random.DefaultPrng = .init(seed);
    const rnd = rng.random();
    var i = games.len;
    while (i > 1) : (i -= 1) {
        const j = rnd.uintLessThan(usize, i);
        std.mem.swap(f32, &games[i - 1].y, &games[j].y);
    }
}

fn rowsByGame(gpa: std.mem.Allocator, d: *const rows.Data) ![][10]u32 {
    const out = try gpa.alloc([10]u32, d.games.len);
    @memset(out, @splat(no_row));
    for (d.rows, 0..) |r, i| out[r.game][@as(usize, r.side) * 5 + @backingInt(r.role)] = @intCast(i);
    return out;
}

/// For lab/health.zig's checks on synthetic games: trains `steps` batches on `train`
/// (0: at init), no early stopping, no IO; writes `scored`'s blue chances to `pred` and
/// returns the parameters (caller frees). ids index 0..n_ids, 0..4 being the roles'
pub fn healthFit(gpa: std.mem.Allocator, opts: Options, seed: u32, n_ids: u32, train_games: []const NetGame, steps: u64, scored: []const NetGame, pred: []f32) ![]f32 {
    var t = try train(gpa, opts, seed, n_ids, train_games, null, steps, null);
    defer t.net.s.ps.deinit(gpa);
    errdefer gpa.free(t.net.p);
    const w: Work = try .init(gpa, &t.net.s);
    defer w.deinit(gpa);
    predict(&t.net, scored, &w, pred);
    return t.net.p;
}

const Fitted = struct {
    pred: []f32,
    epochs: f64,
    val_loss: f64,
    seconds: f64,
    offset_weight: f32,
};

fn runBlock(
    gpa: std.mem.Allocator,
    io: Io,
    d: *const rows.Data,
    players: []const harness.Players,
    raw: []const [n_feat]f32,
    c: harness.Cuts,
    spec: Spec,
    block: Block,
    opts: Options,
    fw: *Io.Writer,
    pw: *Io.Writer,
    cw: *Io.Writer,
    w: *Io.Writer,
    pooled: *Pooled,
) !void {
    const t0 = Io.Clock.awake.now(io);
    var fit: std.ArrayList(u32) = .empty;
    defer fit.deinit(gpa);
    var scored: std.ArrayList(u32) = .empty;
    defer scored.deinit(gpa);
    for (d.games, 0..) |g, i| {
        if (spec.fits(c, g, opts.fraction)) try fit.append(gpa, @intCast(i));
        if (spec.scores(c, g, opts.fraction)) try scored.append(gpa, @intCast(i));
    }
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

    const name = blockName(block);
    {
        const in_fit = try gpa.alloc(bool, d.games.len);
        defer gpa.free(in_fit);
        const in_scored = try gpa.alloc(bool, d.games.len);
        defer gpa.free(in_scored);
        @memset(in_fit, false);
        @memset(in_scored, false);
        for (fit.items) |gi| in_fit[gi] = true;
        for (scored.items) |gi| in_scored[gi] = true;
        var fr: std.ArrayList(u32) = .empty;
        defer fr.deinit(gpa);
        var sr: std.ArrayList(u32) = .empty;
        defer sr.deinit(gpa);
        for (d.rows, 0..) |r, i| {
            if (in_fit[r.game]) try fr.append(gpa, @intCast(i));
            if (in_scored[r.game]) try sr.append(gpa, @intCast(i));
        }
        try coverageLine(cw, name, "fit", d, raw, fr.items);
        try coverageLine(cw, name, "scored", d, raw, sr.items);
        try cw.flush();
    }

    // Candidate offsets: scored and val from fits on all fit / all inner games; training
    // games cross-fitted
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
    try candCross(gpa, d, players, all_keep, fit.items, want, p_all);
    var inner_keep = all_keep;
    inner_keep.before = cut;
    try candCross(gpa, d, players, inner_keep, inner.items, want, p_inner);
    @memset(want, false);
    for (val.items) |gi| want[gi] = true;
    try candBlue(gpa, d, players, inner_keep, want, p_inner);
    const t_cand = secondsSince(io, t0);

    const row_of = try rowsByGame(gpa, d);
    defer gpa.free(row_of);
    const fit_mask = try gpa.alloc(bool, d.games.len);
    defer gpa.free(fit_mask);
    @memset(fit_mask, false);
    for (inner.items) |gi| fit_mask[gi] = true;
    const scale_inner: Scale = .init(d, raw, fit_mask);
    for (val.items) |gi| fit_mask[gi] = true;
    const scale_all: Scale = .init(d, raw, fit_mask);

    var vocab_inner = try Vocab.init(gpa, d, inner.items, opts.min_games);
    defer vocab_inner.deinit(gpa);
    var vocab_all = try Vocab.init(gpa, d, fit.items, opts.min_games);
    defer vocab_all.deinit(gpa);
    const g_inner = try netGames(gpa, d, raw, row_of, inner.items, &vocab_inner, scale_inner, featsOn(opts), p_inner);
    defer gpa.free(g_inner);
    const g_val = try netGames(gpa, d, raw, row_of, val.items, &vocab_inner, scale_inner, featsOn(opts), p_inner);
    defer gpa.free(g_val);
    const g_fit = try netGames(gpa, d, raw, row_of, fit.items, &vocab_all, scale_all, featsOn(opts), p_all);
    defer gpa.free(g_fit);
    const g_scored = try netGames(gpa, d, raw, row_of, scored.items, &vocab_all, scale_all, featsOn(opts), p_all);
    defer gpa.free(g_scored);
    if (opts.shuffle_labels) for ([_][]NetGame{ g_inner, g_val, g_fit }, 0..) |set, k| shuffleLabels(set, 0x5f1 + k);
    if (opts.shuffle_feats) for ([_][]NetGame{ g_inner, g_val, g_fit }, 0..) |set, k| shuffleFeats(set, 0x5f2 + k);
    if (opts.dump) for ([_][]const NetGame{ g_inner, g_val, g_fit, g_scored }, [_][]const u32{ inner.items, val.items, fit.items, scored.items }, [_][]const u8{ "inner", "val", "fit", "scored" }) |set, games, part| {
        try dumpSet(io, d, opts.out, name, part, set, games, if (std.mem.eql(u8, part, "inner") or std.mem.eql(u8, part, "val")) vocab_inner.n else vocab_all.n);
    };

    const n_s = opts.seeds.len;
    const fits = try gpa.alloc(Fitted, n_s);
    defer {
        for (fits) |f| gpa.free(f.pred);
        gpa.free(fits);
    }
    const sets: Sets = .{ .inner = g_inner, .val = g_val, .fit = g_fit, .scored = g_scored, .n_inner = vocab_inner.n, .n_all = vocab_all.n, .block = block, .vocab_inner = &vocab_inner, .vocab_all = &vocab_all };
    const Ctx = struct {
        gpa: std.mem.Allocator,
        io: Io,
        opts: Options,
        sets: Sets,
        seeds: []const u32,
        fits: []Fitted,
        fn one(x: @This(), i: usize) !void {
            x.fits[i] = try fitNet(x.gpa, x.io, x.opts, x.seeds[i], x.sets);
        }
    };
    var at: usize = 0;
    while (at < n_s) : (at += opts.threads) {
        const n = @min(opts.threads, n_s - at);
        try par.forEach(io, n, Ctx{ .gpa = gpa, .io = io, .opts = opts, .sets = sets, .seeds = opts.seeds[at..][0..n], .fits = fits[at..][0..n] }, Ctx.one);
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
    try w.print("block {s}: fit {d} games (inner {d}, val {d}, ids {d}), scored {d}; candidate {d:.1} s\n", .{ name, fit.items.len, inner.items.len, val.items.len, vocab_all.n, scored.items.len, t_cand });
    {
        var vl: f64 = 0;
        for (g_val) |g| vl += loss1(g.y, sigmoid(g.off));
        try w.print("candidate on val (fitted on inner): {d:.5}\n", .{vl / @as(f64, @floatFromInt(@max(g_val.len, 1)))});
    }
    try summaryHead(w);
    const cand_loss = meanLoss(ys, pc);
    const cand_auc = try auc(gpa, ys, pc);
    for (opts.seeds, fits) |seed, f| {
        const g = pairedGain(ys, pc, f.pred);
        try fw.print("{d}\t{s}\t{d}\t{d}\t{d:.6}\t{d:.6}\t{d:.6}\t{d:.6}\t{d:.2}\t{d:.1}\t{d:.6}\t{d:.5}\t{d:.5}\t{d:.4}\n", .{
            seed, name, fit.items.len, scored.items.len, meanLoss(ys, f.pred), cand_loss, g.mean, g.se, f.epochs, f.seconds, f.val_loss, try auc(gpa, ys, f.pred), cand_auc, f.offset_weight,
        });
        var label_buf: [32]u8 = undefined;
        try summaryRow(gpa, w, try std.fmt.bufPrint(&label_buf, "seed {d}", .{seed}), ys, pc, f.pred, f);
    }
    {
        const g = pairedGain(ys, pc, ens);
        var epochs: f64 = 0;
        var val_loss: f64 = 0;
        var secs: f64 = 0;
        var aw: f64 = 0;
        for (fits) |f| {
            epochs += f.epochs;
            val_loss += f.val_loss;
            secs += f.seconds;
            aw += f.offset_weight;
        }
        const ns: f64 = @floatFromInt(n_s);
        try fw.print("ens\t{s}\t{d}\t{d}\t{d:.6}\t{d:.6}\t{d:.6}\t{d:.6}\t{d:.2}\t{d:.1}\t{d:.6}\t{d:.5}\t{d:.5}\t{d:.4}\n", .{
            name, fit.items.len, scored.items.len, meanLoss(ys, ens), cand_loss, g.mean, g.se, epochs / ns, secs, val_loss / ns, try auc(gpa, ys, ens), cand_auc, aw / ns,
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
    try w.writeAll("\n");
    try w.flush();
    try fw.flush();
    const plat = protocol.platformIds();
    for (scored.items, 0..) |gi, i| {
        const g = d.games[gi];
        try pw.print("{s}\t{s}\t{s}\t{d}\t{d:.6}", .{ name, g.match_id, plat[g.platform], ys[i], pc[i] });
        for (fits) |f| try pw.print("\t{d:.6}", .{f.pred[i]});
        try pw.print("\t{d:.6}", .{ens[i]});
        // History per side, to split gains and check calibration by coverage
        var n: [2][count_names.len]u32 = @splat(@splat(0));
        for (row_of[gi], 0..) |ri, slot| if (ri != no_row) {
            const r = d.rows[ri];
            const k = &n[slot / 5];
            k[0] += @intFromBool(r.games_before > 0);
            k[1] += @intFromBool(r.champ_games > 0);
            k[2] += r.champ_games;
            k[3] += r.games_before;
            k[4] += @intFromBool(r.rank_start != null);
            k[5] += @intFromBool(raw[ri][@backingInt(Feat.mastery_known)] > 0);
        };
        for (n) |side| for (side) |x| try pw.print("\t{d}", .{x});
        try pw.writeAll("\n");
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

fn summaryHead(w: *Io.Writer) !void {
    try w.writeAll("| net | games | log loss | cand log loss | vs cand, nats/game (negative: net better) | AUC | cand AUC | epochs | val log loss | offset weight |\n| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |\n");
}

fn summaryRow(gpa: std.mem.Allocator, w: *Io.Writer, label: []const u8, ys: []const f32, pc: []const f32, pn: []const f32, f: ?Fitted) !void {
    const g = pairedGain(ys, pc, pn);
    try w.print("| {s} | {d} | {d:.5} | {d:.5} | {d:.5} ± {d:.5} | {d:.4} | {d:.4} |", .{ label, ys.len, meanLoss(ys, pn), meanLoss(ys, pc), -g.mean, 1.96 * g.se, try auc(gpa, ys, pn), try auc(gpa, ys, pc) });
    if (f) |x| try w.print(" {d:.2} | {d:.5} | {d:.3} |\n", .{ x.epochs, x.val_loss, x.offset_weight }) else try w.writeAll(" | | |\n");
}

const Sets = struct {
    inner: []const NetGame,
    val: []const NetGame,
    fit: []const NetGame,
    scored: []const NetGame,
    n_inner: u32,
    n_all: u32,
    block: Block,
    vocab_inner: *const Vocab,
    vocab_all: *const Vocab,
};

/// The parameters: platform intercepts, the offset's weight and hidden biases (no
/// decay); champion-role and role embeddings (emb_wd); hidden weights (hidden x input,
/// input = emb + n_feat) and output weights (wd)
const Shape = struct {
    ps: nn.Params,
    emb: usize,
    hidden: usize,
    input: usize,
    c: nn.Param,
    a: nn.Param,
    b: nn.Param,
    e: nn.Param,
    r: nn.Param,
    w: nn.Param,
    out: nn.Param,

    fn init(gpa: std.mem.Allocator, n_ids: usize, opts: Options) !Shape {
        var s: Shape = .{ .ps = .empty, .emb = opts.emb, .hidden = opts.hidden, .input = opts.emb + n_feat, .c = undefined, .a = undefined, .b = undefined, .e = undefined, .r = undefined, .w = undefined, .out = undefined };
        errdefer s.ps.deinit(gpa);
        const ps = &s.ps;
        const emb_wd = opts.emb_wd orelse opts.wd;
        s.c = try ps.vector(gpa, "platform", n_platforms, .{});
        s.a = try ps.scalar(gpa, "offset", .{ .init = .{ .constant = 1 }, .frozen = opts.fix_offset });
        s.b = try ps.vector(gpa, "b", s.hidden, .{});
        s.e = try ps.table(gpa, "champion_role", n_ids, s.emb, .{ .init = .{ .uniform = 0.1 }, .decay = emb_wd });
        s.r = try ps.table(gpa, "role", 5, s.emb, .{ .init = .{ .uniform = 0.1 }, .decay = emb_wd });
        s.w = try ps.matrix(gpa, "w", s.hidden, s.input, .{ .init = .kaiming(s.input), .decay = opts.wd });
        // Starts at 0: the net starts as the candidate
        s.out = try ps.vector(gpa, "out", s.hidden, .{ .decay = opts.wd });
        return s;
    }
};

const Net = struct {
    s: Shape,
    p: []f32,

    fn init(gpa: std.mem.Allocator, s: Shape, rnd: std.Random) !Net {
        const p = try s.ps.alloc(gpa);
        s.ps.initValues(p, rnd);
        return .{ .s = s, .p = p };
    }

    fn deinit(n: *Net, gpa: std.mem.Allocator) void {
        gpa.free(n.p);
        n.s.ps.deinit(gpa);
    }
};

/// One slot's activations: input, hidden after ReLU and dropout
const Slot = struct {
    x: []f32,
    h: []f32,
};

fn forwardSlot(n: *const Net, g: *const NetGame, slot: usize, v: Slot, keep: f32, rnd: ?std.Random) f32 {
    const s = &n.s;
    if (s.emb > 0) {
        const e = s.e.row(n.p, g.ids[slot]);
        const r = s.r.row(n.p, slot % 5);
        for (v.x[0..s.emb], e, r) |*x, a, b| x.* = a + b;
    }
    @memcpy(v.x[s.emb..], &g.x[slot]);
    nn.linear.forward(s.w.of(n.p), s.b.of(n.p), v.x, v.h);
    nn.relu.forward(v.h, v.h, keep, rnd);
    return nn.dot(s.out.of(n.p), v.h);
}

/// dh, dx: scratch of hidden and input
fn backwardSlot(n: *const Net, g: *const NetGame, slot: usize, v: Slot, df: f32, keep: f32, gr: []f32, dh: []f32, dx: []f32) void {
    const s = &n.s;
    nn.axpy(s.out.of(gr), df, v.h);
    for (dh, s.out.of(n.p)) |*d, wo| d.* = df * wo;
    nn.relu.backward(v.h, dh, keep, dh);
    @memset(dx, 0);
    nn.linear.backward(s.w.of(n.p), v.x, dh, s.w.of(gr), s.b.of(gr), dx);
    if (s.emb > 0) {
        nn.axpy(s.e.row(gr, g.ids[slot]), 1, dx[0..s.emb]);
        nn.axpy(s.r.row(gr, slot % 5), 1, dx[0..s.emb]);
    }
}

fn gameLogit(n: *const Net, g: *const NetGame, f: [10]f32) f32 {
    var s: f32 = 0;
    for (f, 0..) |x, slot| s += if (slot < 5) x else -x;
    return s + n.s.c.at(n.p, g.platform).* + n.s.a.at(n.p, 0).* * g.off;
}

fn predict(n: *const Net, games: []const NetGame, w: *const Work, out: []f32) void {
    for (games, out) |*g, *o| {
        var f: [10]f32 = undefined;
        for (&f, 0..) |*x, slot| x.* = forwardSlot(n, g, slot, w.slots[slot], 1, null);
        o.* = sigmoid(gameLogit(n, g, f));
    }
}

/// Adds game g's loss gradient, scaled by 1 / count, to gr (dropout with rnd)
fn gameGrad(n: *const Net, g: *const NetGame, w: *const Work, count: f32, keep: f32, rnd: ?std.Random, gr: []f32) void {
    var f: [10]f32 = undefined;
    for (&f, 0..) |*x, slot| x.* = forwardSlot(n, g, slot, w.slots[slot], keep, rnd);
    const dl = (sigmoid(gameLogit(n, g, f)) - g.y) / count;
    n.s.c.at(gr, g.platform).* += dl;
    n.s.a.at(gr, 0).* += dl * g.off;
    for (0..10) |slot| backwardSlot(n, g, slot, w.slots[slot], if (slot < 5) dl else -dl, keep, gr, w.dh, w.dx);
}

const Work = struct {
    buf: []f32,
    slots: [10]Slot,
    dh: []f32,
    dx: []f32,

    fn init(gpa: std.mem.Allocator, s: *const Shape) !Work {
        const per = s.input + s.hidden;
        const buf = try gpa.alloc(f32, 10 * per + s.hidden + s.input);
        var w: Work = .{ .buf = buf, .slots = undefined, .dh = buf[10 * per ..][0..s.hidden], .dx = buf[10 * per + s.hidden ..][0..s.input] };
        for (&w.slots, 0..) |*x, i| {
            x.x = buf[i * per ..][0..s.input];
            x.h = buf[i * per + s.input ..][0..s.hidden];
        }
        return w;
    }

    fn deinit(w: *const Work, gpa: std.mem.Allocator) void {
        gpa.free(w.buf);
    }
};

const Trained = struct { net: Net, steps: u64, epochs: f64, val_loss: f64 };

/// train's side of nn.fit
const NetFit = struct {
    n: *Net,
    w: *const Work,
    games: []const NetGame,
    val: []const NetGame,
    vpred: []f32,
    gr: []f32,
    opt: *nn.Adam,
    segs: []const nn.Segment,
    keep: f32,
    drop: ?std.Random,
    clip: f32,

    pub fn step(f: *NetFit, part: []const u32) !void {
        @memset(f.gr, 0);
        const count: f32 = @floatFromInt(part.len);
        for (part) |gi| gameGrad(f.n, &f.games[gi], f.w, count, f.keep, f.drop, f.gr);
        if (f.clip > 0) _ = nn.clipGradNorm(f.gr, f.clip);
        f.opt.step(f.n.p, f.gr, f.segs);
    }

    pub fn valLoss(f: *NetFit) !f64 {
        predict(f.n, f.val, f.w, f.vpred);
        var loss: f64 = 0;
        for (f.val, f.vpred) |g, q| loss += nn.logLoss(g.y, q);
        return loss / @as(f64, @floatFromInt(@max(f.val.len, 1)));
    }
};

/// AdamW over shuffled batches for at most max_steps; with val, evaluated opts.evals
/// times an epoch, stopping after `patience` evaluations without a new best and keeping
/// the best one's parameters. Step 0, the candidate alone, can win
fn train(gpa: std.mem.Allocator, opts: Options, seed: u32, n_ids: u32, games: []const NetGame, val: ?[]const NetGame, max_steps: u64, emb_init: ?EmbInit) !Trained {
    var rng: std.Random.DefaultPrng = .init(seed);
    const rnd = rng.random();
    const shape: Shape = try .init(gpa, n_ids, opts);
    var n: Net = Net.init(gpa, shape, rnd) catch |e| {
        var x = shape;
        x.ps.deinit(gpa);
        return e;
    };
    errdefer n.deinit(gpa);
    if (emb_init) |ei| {
        try ei.table.apply(ei.vocab, n.s.e, n.p);
        @memset(n.s.r.of(n.p), 0);
    }
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

    var f: NetFit = .{
        .n = &n,
        .w = &w,
        .games = games,
        .val = val orelse &.{},
        .vpred = vpred,
        .gr = gr,
        .opt = &opt,
        .segs = segs,
        .keep = 1 - opts.dropout,
        .drop = if (opts.dropout > 0) rnd else null,
        .clip = opts.clip,
    };
    if (val) |v| {
        var off_loss: f64 = 0;
        for (v) |g| off_loss += nn.logLoss(g.y, sigmoid(g.off));
        gates.initLoss("playernet", try f.valLoss(), off_loss / @as(f64, @floatFromInt(@max(v.len, 1))));
    }
    const r = try nn.fit(gpa, &f, .{
        .batch = opts.batch,
        .max_steps = max_steps,
        .evals_per_epoch = opts.evals,
        .patience = opts.patience,
        .score_start = true,
        .validate = val != null,
    }, games.len, rnd, n.p, best);
    return .{ .net = n, .steps = r.steps, .epochs = r.epochs, .val_loss = r.loss };
}

fn fitNet(gpa: std.mem.Allocator, io: Io, opts: Options, seed: u32, s: Sets) !Fitted {
    const t0 = Io.Clock.awake.now(io);
    var table: ?EmbTable = if (opts.emb_init) |dir| try .load(gpa, io, dir, blockName(s.block), seed, opts.emb) else null;
    defer if (table) |*t| t.deinit();
    const init_inner: ?EmbInit = if (table) |*t| .{ .table = t, .vocab = s.vocab_inner } else null;
    const init_all: ?EmbInit = if (table) |*t| .{ .table = t, .vocab = s.vocab_all } else null;
    var tuned = try train(gpa, opts, seed, s.n_inner, s.inner, s.val, opts.max_epochs * nn.stepsPerEpoch(s.inner.len, opts.batch), init_inner);
    tuned.net.deinit(gpa);
    var full = try train(gpa, opts, seed, s.n_all, s.fit, null, if (tuned.steps == 0) 0 else refitSteps(tuned.epochs, s.fit.len, opts.batch), init_all);
    defer full.net.deinit(gpa);
    const w: Work = try .init(gpa, &full.net.s);
    defer w.deinit(gpa);
    const pred = try gpa.alloc(f32, s.scored.len);
    predict(&full.net, s.scored, &w, pred);
    return .{ .pred = pred, .epochs = tuned.epochs, .val_loss = tuned.val_loss, .seconds = secondsSince(io, t0), .offset_weight = full.net.s.a.at(full.net.p, 0).* };
}

const testing = std.testing;

test "playernet gradient matches finite differences" {
    const gpa = testing.allocator;
    var rng: std.Random.DefaultPrng = .init(7);
    const rnd = rng.random();
    var n: Net = try .init(gpa, try .init(gpa, 8, .{ .emb = 3, .hidden = 4 }), rnd);
    defer n.deinit(gpa);
    for (n.s.out.of(n.p)) |*x| x.* = rnd.float(f32) - 0.5;
    n.s.a.at(n.p, 0).* = 0.8;
    var g: NetGame = .{ .ids = undefined, .x = undefined, .platform = 2, .y = 1, .off = 0.3 };
    for (&g.ids, &g.x) |*id, *x| {
        id.* = rnd.uintLessThan(u32, 8);
        for (x) |*v| v.* = rnd.float(f32) * 2 - 1;
    }
    const w: Work = try .init(gpa, &n.s);
    defer w.deinit(gpa);
    const gr = try n.s.ps.alloc(gpa);
    defer gpa.free(gr);
    gameGrad(&n, &g, &w, 1, 1, null, gr);
    const GameLoss = struct {
        n: *const Net,
        w: *const Work,
        g: *const NetGame,
        fn loss(c: *const @This()) f64 {
            var p: [1]f32 = undefined;
            predict(c.n, c.g[0..1], c.w, &p);
            return loss1(c.g.y, p[0]);
        }
    };
    try nn.expectGradient(&GameLoss{ .n = &n, .w = &w, .g = &g }, GameLoss.loss, n.p, gr, null, .{});
}

test "playernet is antisymmetric: swapping sides flips the logit" {
    var rng: std.Random.DefaultPrng = .init(3);
    const rnd = rng.random();
    var n: Net = try .init(testing.allocator, try .init(testing.allocator, 6, .{ .emb = 2, .hidden = 5 }), rnd);
    defer n.deinit(testing.allocator);
    for (n.s.out.of(n.p)) |*x| x.* = rnd.float(f32) - 0.5;
    var g: NetGame = .{ .ids = undefined, .x = undefined, .platform = 0, .y = 1, .off = 0.4 };
    for (&g.ids, &g.x) |*id, *x| {
        id.* = rnd.uintLessThan(u32, 6);
        for (x) |*v| v.* = rnd.float(f32);
    }
    var s = g;
    s.off = -g.off;
    for (0..10) |slot| {
        s.ids[slot] = g.ids[(slot + 5) % 10];
        s.x[slot] = g.x[(slot + 5) % 10];
    }
    const w: Work = try .init(testing.allocator, &n.s);
    defer w.deinit(testing.allocator);
    var p: [2]f32 = undefined;
    predict(&n, (&g)[0..1], &w, p[0..1]);
    predict(&n, (&s)[0..1], &w, p[1..2]);
    try testing.expectApproxEqAbs(@as(f32, 1), p[0] + p[1], 1e-5);
}

test "playernet healthFit at init is the candidate" {
    var g: NetGame = .{ .ids = @splat(0), .x = @splat(@splat(0.5)), .platform = 1, .y = 1, .off = 0.7 };
    for (&g.ids, 0..) |*id, slot| id.* = @intCast(slot % 5);
    var pred: [1]f32 = undefined;
    const p = try healthFit(testing.allocator, .{}, 1, 5, (&g)[0..1], 0, (&g)[0..1], &pred);
    defer testing.allocator.free(p);
    try testing.expectApproxEqAbs(sigmoid(0.7), pred[0], 1e-6);
}

test "playernet coPlay counts earlier games together on one team" {
    const gpa = testing.allocator;
    // Three games an hour apart, 30 minutes long: players 1 and 2 together on blue in
    // games 0 and 1, then again in game 2; player 3 against them in game 0, with them in 2
    var games: [3]rows.Game = undefined;
    for (&games, 0..) |*g, i| g.* = .{ .match_id = "", .start = @intCast(i * 3_600_000), .patch = 0, .platform = 0, .is_test = false, .teams = @splat(@splat(0)), .winner = 0, .duration_s = 1800 };
    const spec = [_][3]u32{ .{ 0, 0, 1 }, .{ 0, 1, 2 }, .{ 0, 5, 3 }, .{ 1, 0, 1 }, .{ 1, 1, 2 }, .{ 2, 0, 1 }, .{ 2, 1, 2 }, .{ 2, 2, 3 } };
    var rws: [spec.len]rows.Row = undefined;
    for (&rws, spec) |*r, x| r.* = .{ .game = x[0], .slot = @intCast(x[1]), .side = @intCast(x[1] / 5), .role = @fromBackingInt(@as(u3, @intCast(x[1] % 5))), .champion = 1, .y = @splat(0), .player = x[2] };
    const d: rows.Data = .{ .arena = .init(gpa), .games = &games, .rows = &rws };
    const got = try coPlay(gpa, &d);
    defer gpa.free(got);
    try testing.expectEqualSlices([2]u16, &.{ .{ 0, 0 }, .{ 0, 0 }, .{ 0, 0 }, .{ 1, 1 }, .{ 1, 1 }, .{ 1, 2 }, .{ 1, 2 }, .{ 0, 0 } }, got);
}

test "playernet dumpSet writes one record per game and the match ids in order" {
    const gpa = testing.allocator;
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try std.fmt.allocPrint(gpa, ".zig-cache/tmp/{s}", .{&tmp.sub_path});
    defer gpa.free(base);
    var games: [2]rows.Game = undefined;
    for (&games, [_][]const u8{ "EUW1_1", "EUW1_2" }) |*g, id| g.* = .{ .match_id = id, .start = 0, .patch = 0, .platform = 3, .is_test = false, .teams = @splat(@splat(0)), .winner = 0, .duration_s = 1800 };
    const d: rows.Data = .{ .arena = .init(gpa), .games = &games, .rows = &.{} };
    var set: [2]NetGame = undefined;
    for (&set, 0..) |*g, i| g.* = .{ .ids = @splat(@intCast(i + 1)), .x = @splat(@splat(0.5)), .platform = 3, .y = 1, .off = -0.25 };
    set[1].x[9][n_feat - 1] = 2;
    try dumpSet(io, &d, base, "dev", "fit", &set, &.{ 1, 0 }, 7);
    var dir = try Io.Dir.cwd().openDir(io, base, .{});
    defer dir.close(io);
    const bin = try dir.readFileAlloc(io, "net-dev-fit.bin", gpa, .limited(1 << 20));
    defer gpa.free(bin);
    try testing.expectEqual(2 * dump_len * 4, bin.len);
    const vals = std.mem.bytesAsSlice(u32, bin);
    try testing.expectEqual(@as(u32, 2), vals[dump_len]);
    try testing.expectEqual(@as(f32, 2), @as(f32, @bitCast(vals[2 * dump_len - 4])));
    try testing.expectEqual(@as(f32, -0.25), @as(f32, @bitCast(vals[2 * dump_len - 1])));
    const txt = try dir.readFileAlloc(io, "net-dev-fit.txt", gpa, .limited(1 << 20));
    defer gpa.free(txt);
    try testing.expect(std.mem.startsWith(u8, txt, "n_ids 7 n_feat "));
    try testing.expect(std.mem.endsWith(u8, txt, "\nEUW1_2\nEUW1_1\n"));
}

test "playernet featsOn: groups on, minus dropped features" {
    var o: Options = .{};
    o.groups = @splat(false);
    o.groups[@backingInt(Group.prior)] = true;
    o.drop[@backingInt(Feat.gpm)] = true;
    const on = featsOn(o);
    try testing.expect(!on[@backingInt(Feat.gpm)] and on[@backingInt(Feat.cspm)] and on[@backingInt(Feat.days_since)]);
    try testing.expect(!on[@backingInt(Feat.champ_games)] and !on[@backingInt(Feat.duo_mates)]);
}

test "playernet main and every pub decl compile" {
    // -Dtest-filter otherwise analyses only what tests reach, not main()'s run path
    testing.refAllDecls(@This());
}
