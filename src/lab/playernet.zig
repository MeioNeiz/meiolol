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
//! pre-game points on the champion and known (SNAP/mastery_pre.tsv when present).
//! Writes DIR/folds.tsv, DIR/preds.tsv (as netcheck's) and DIR/coverage.tsv (feature
//! coverage of rows per block and part; test rows' features only, never outcomes)

const std = @import("std");
const api = @import("api");
const cand = @import("cand");
const rows = @import("rows.zig");
const protocol = @import("protocol.zig");
const harness = @import("harness.zig");
const mastery_pre = @import("mastery_pre.zig");
const par = @import("../par.zig");

const Io = std.Io;

pub const usage =
    \\  playernet SNAP [OPT VALUE]...   player-history net residual on the -Dcand
    \\                                  candidate (internal scope; lab/playernet.zig):
    \\                                  --emb N (0: no champion-role) --hidden N
    \\                                  --dropout X --wd X --emb-wd X --lr X --clip X
    \\                                  --batch N --evals N --patience N --max-epochs N
    \\                                  --min-games N --fix-offset 0|1
    \\                                  --feats champ,any,form,rank,mastery|none
    \\                                  --emb-init DIR (pretrain's emb-<block>-s<seed>.tsv)
    \\                                  --seeds 1,2,3 --blocks dev,1,2,3,4,5
    \\                                  --fraction X --threads N --out DIR
    \\
;

pub const Group = enum { champ, any, form, rank, mastery };

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

    fn group(f: Feat) Group {
        return switch (f) {
            .champ_games, .champ_wr, .champ_played => .champ,
            .games, .wr, .any_played, .champ_share => .any,
            .kda, .lanediff14, .deaths15 => .form,
            .rank, .rank_known => .rank,
            .mastery, .mastery_known => .mastery,
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
    groups: [5]bool = @splat(true),
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
    threads: u32 = 3,
    out: []const u8 = ".",
};

pub const Block = enum { dev, f1, f2, f3, f4, f5 };
const n_folds = 5;
const val_share = 0.1;
const n_platforms = 16;

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
    const ids = protocol.platformIds();
    std.debug.assert(ids.len <= n_platforms);
    const eu: u8 = for (ids, 0..) |id, i| {
        if (std.mem.eql(u8, id, protocol.test_platform)) break @intCast(i);
    } else return error.TestPlatformNotScanned;
    const c = try harness.cuts(gpa, &data, eu);
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
    try pw.interface.writeAll("\tens\n");
    var cov_file = try dir.createFile(io, "coverage.tsv", .{});
    defer cov_file.close(io);
    var cbuf: [16 * 1024]u8 = undefined;
    var cw = cov_file.writer(io, &cbuf);
    try cw.interface.writeAll("block\tpart\trows\tany_games\tchamp_games\tchamp_10plus\trank_start\tmastery_pre\n");

    var out_buf: [4096]u8 = undefined;
    var stdout = Io.File.stdout().writer(io, &out_buf);
    const w = &stdout.interface;
    try w.print("# playernet vs {s}, fraction {d}, seeds {any}\n\n", .{ if (@hasDecl(cand, "name")) cand.name else "cand", opts.fraction, opts.seeds });
    try w.print("options: emb {d} hidden {d} dropout {d} wd {d} emb_wd {d} lr {d} clip {d} batch {d} evals {d} patience {d} min_games {d} fix_offset {} emb_init {s} feats", .{
        opts.emb, opts.hidden, opts.dropout, opts.wd, opts.emb_wd orelse opts.wd, opts.lr, opts.clip, opts.batch, opts.evals, opts.patience, opts.min_games, opts.fix_offset, opts.emb_init orelse "-",
    });
    for (opts.groups, 0..) |on, gi| if (on) try w.print(" {s}", .{@tagName(@as(Group, @fromBackingInt(@intCast(gi))))});
    try w.print("\nmastery_pre.tsv: {d} participants\n\n", .{mastery.map.count()});
    try w.flush();

    // Test rows' feature coverage (no outcomes): how thin the test look would be
    {
        var test_rows: std.ArrayList(u32) = .empty;
        defer test_rows.deinit(gpa);
        for (data.rows, 0..) |r, i| if (harness.scored(.final, c, data.games[r.game])) try test_rows.append(gpa, @intCast(i));
        try coverageLine(&cw.interface, "test", "scored", &data, raw, test_rows.items);
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
        } else if (std.mem.eql(u8, k, "--fix-offset")) {
            o.fix_offset = (try std.fmt.parseInt(u1, v, 10)) == 1;
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
    const out = try gpa.alloc([n_feat]f32, d.rows.len);
    const nan = std.math.nan(f32);
    for (out, d.rows) |*o, r| {
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
    }
    return out;
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

    /// Unknown values sit at the fit mean (0 after scaling); groups off are 0
    fn apply(s: Scale, x: [n_feat]f32, groups: [5]bool) [n_feat]f32 {
        var out: [n_feat]f32 = @splat(0);
        for (x, 0..) |v, f| {
            if (!groups[@backingInt(@as(Feat, @fromBackingInt(@intCast(f))).group())] or std.math.isNan(v)) continue;
            out[f] = (v - s.mean[f]) / s.sd[f];
        }
        return out;
    }
};

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

    fn fits(s: Spec, c: harness.Cuts, g: rows.Game, fraction: f64) bool {
        return harness.inFraction(g, fraction) and harness.visible(.dev, c, g) and g.start < s.before;
    }

    fn scores(s: Spec, c: harness.Cuts, g: rows.Game) bool {
        if (s.dev) return harness.scored(.dev, c, g);
        return harness.visible(.dev, c, g) and g.start >= s.lo and g.start < s.hi;
    }
};

/// The candidate's fit games: the spec's, older than `before` (the inner fit)
const FitKeep = struct {
    spec: Spec,
    c: harness.Cuts,
    fraction: f64,
    before: i64 = std.math.maxInt(i64),
    without: ?u8 = null,

    pub fn keep(k: FitKeep, g: rows.Game) bool {
        if (k.without) |f| if (crossFold(g) == f) return false;
        return k.spec.fits(k.c, g, k.fraction) and g.start < k.before;
    }
};

/// Training offsets come from candidates fitted without the game (winnet's resid): an
/// in-sample offset is more confident than the out-of-sample one it is scored with
const cross_folds = 5;

fn crossFold(g: rows.Game) u8 {
    var h = std.hash.Wyhash.init(0xc705);
    h.update(std.mem.asBytes(&g.start));
    h.update(std.mem.asBytes(&g.platform));
    return @intCast(h.final() % cross_folds);
}

fn candCross(gpa: std.mem.Allocator, d: *const rows.Data, players: []const harness.Players, keep: FitKeep, games: []const u32, want: []bool, out: []f32) !void {
    for (0..cross_folds) |f| {
        @memset(want, false);
        for (games) |gi| want[gi] = crossFold(d.games[gi]) == f;
        var k = keep;
        k.without = @intCast(f);
        try candBlue(gpa, d, players, k, want, out);
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

/// Dense champion-role ids from fit games: min_games or more get their own, others their
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

    fn id(v: *const Vocab, champion: u32, role: usize) u32 {
        return v.map.get(key(champion, role)) orelse @intCast(role);
    }
};

fn key(champion: u32, role: usize) u64 {
    return (@as(u64, champion) << 3) | role;
}

fn logit(p: f32) f32 {
    const q = std.math.clamp(p, 1e-6, 1 - 1e-6);
    return @log(q / (1 - q));
}

/// One game as the net sees it: slots blue by role, then red
const NetGame = struct {
    ids: [10]u32,
    x: [10][n_feat]f32,
    platform: u8,
    y: f32,
    /// The candidate's logit for blue
    off: f32,
};

fn netGames(gpa: std.mem.Allocator, d: *const rows.Data, raw: []const [n_feat]f32, row_of: []const [10]u32, games: []const u32, vocab: *const Vocab, scale: Scale, groups: [5]bool, off: []const f32) ![]NetGame {
    const out = try gpa.alloc(NetGame, games.len);
    for (out, games) |*o, gi| {
        const g = d.games[gi];
        o.* = .{ .ids = undefined, .x = undefined, .platform = g.platform, .y = if (g.winner == 0) 1 else 0, .off = logit(off[gi]) };
        for (0..10) |slot| {
            o.ids[slot] = vocab.id(g.teams[slot / 5][slot % 5], slot % 5);
            const ri = row_of[gi][slot];
            o.x[slot] = if (ri == no_row) @splat(0) else scale.apply(raw[ri], groups);
        }
    }
    return out;
}

const no_row = std.math.maxInt(u32);

/// Each game's row index by slot (side * 5 + role)
fn rowsByGame(gpa: std.mem.Allocator, d: *const rows.Data) ![][10]u32 {
    const out = try gpa.alloc([10]u32, d.games.len);
    @memset(out, @splat(no_row));
    for (d.rows, 0..) |r, i| out[r.game][@as(usize, r.side) * 5 + @backingInt(r.role)] = @intCast(i);
    return out;
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
        if (spec.scores(c, g)) try scored.append(gpa, @intCast(i));
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
    const g_inner = try netGames(gpa, d, raw, row_of, inner.items, &vocab_inner, scale_inner, opts.groups, p_inner);
    defer gpa.free(g_inner);
    const g_val = try netGames(gpa, d, raw, row_of, val.items, &vocab_inner, scale_inner, opts.groups, p_inner);
    defer gpa.free(g_val);
    const g_fit = try netGames(gpa, d, raw, row_of, fit.items, &vocab_all, scale_all, opts.groups, p_all);
    defer gpa.free(g_fit);
    const g_scored = try netGames(gpa, d, raw, row_of, scored.items, &vocab_all, scale_all, opts.groups, p_all);
    defer gpa.free(g_scored);

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
    try w.writeAll("| net | games | log loss | cand log loss | vs cand, nats/game (negative: net better) | AUC | cand AUC | epochs | val log loss | offset weight |\n| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |\n");
}

fn summaryRow(gpa: std.mem.Allocator, w: *Io.Writer, label: []const u8, ys: []const f32, pc: []const f32, pn: []const f32, f: ?Fitted) !void {
    const g = pairedGain(ys, pc, pn);
    try w.print("| {s} | {d} | {d:.5} | {d:.5} | {d:.5} ± {d:.5} | {d:.4} | {d:.4} |", .{ label, ys.len, meanLoss(ys, pn), meanLoss(ys, pc), -g.mean, 1.96 * g.se, try auc(gpa, ys, pn), try auc(gpa, ys, pc) });
    if (f) |x| try w.print(" {d:.2} | {d:.5} | {d:.3} |\n", .{ x.epochs, x.val_loss, x.offset_weight }) else try w.writeAll(" | | |\n");
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

/// Candidate's loss minus the net's, per game (clustered by game); positive: net better
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

/// Over both sides' rows, as the harness scores rows; ties share their rank
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
    block: Block,
    vocab_inner: *const Vocab,
    vocab_all: *const Vocab,
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
            for (v) |*x| x.* = try std.fmt.parseFloat(f32, it.next() orelse return error.EmbFormat);
            if (it.next() != null) return error.EmbDim;
            try t.map.put(a, key(champion, role), v);
        }
        return t;
    }

    fn deinit(t: *EmbTable) void {
        t.arena.deinit();
    }

    /// Each vocab id's vector: its champion-role's, else its role's shared one; role
    /// embeddings stay 0
    fn apply(t: *const EmbTable, v: *const Vocab, l: Layout, p: []f32) !void {
        for (0..5) |role| {
            const x = t.map.get(key(0, role)) orelse return error.EmbMissingRole;
            @memcpy(p[l.e + role * l.emb ..][0..l.emb], x);
        }
        var it = v.map.iterator();
        while (it.next()) |e| {
            const x = t.map.get(e.key_ptr.*) orelse t.map.get(key(0, e.key_ptr.* & 7)).?;
            @memcpy(p[l.e + e.value_ptr.* * l.emb ..][0..l.emb], x);
        }
        @memset(p[l.r..l.w], 0);
    }
};

const EmbInit = struct { table: *const EmbTable, vocab: *const Vocab };

/// Flat parameters: platform intercepts, the offset's weight and hidden biases (no
/// decay); champion-role and role embeddings (emb_wd); hidden weights (hidden x input,
/// input = emb + n_feat) and output weights (wd)
const Layout = struct {
    emb: usize,
    hidden: usize,
    input: usize,
    c: usize,
    a: usize,
    b: usize,
    e: usize,
    r: usize,
    w: usize,
    out: usize,
    len: usize,

    fn init(n_ids: usize, emb: usize, hidden: usize) Layout {
        var l: Layout = undefined;
        l.emb = emb;
        l.hidden = hidden;
        l.input = emb + n_feat;
        l.c = 0;
        l.a = n_platforms;
        l.b = l.a + 1;
        l.e = l.b + hidden;
        l.r = l.e + n_ids * emb;
        l.w = l.r + 5 * emb;
        l.out = l.w + hidden * l.input;
        l.len = l.out + hidden;
        return l;
    }
};

const Net = struct {
    l: Layout,
    p: []f32,

    fn init(gpa: std.mem.Allocator, l: Layout, rnd: std.Random) !Net {
        const p = try gpa.alloc(f32, l.len);
        @memset(p, 0);
        p[l.a] = 1;
        for (p[l.e..l.w]) |*x| x.* = (rnd.float(f32) * 2 - 1) * 0.1;
        const bound = @sqrt(6.0 / @as(f32, @floatFromInt(l.input)));
        for (p[l.w..l.out]) |*x| x.* = (rnd.float(f32) * 2 - 1) * bound;
        return .{ .l = l, .p = p };
    }
};

/// One slot's activations: input, hidden after ReLU and dropout
const Slot = struct {
    x: []f32,
    h: []f32,
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

fn forwardSlot(n: *const Net, g: *const NetGame, slot: usize, v: Slot, keep: f32, rnd: ?std.Random) f32 {
    const l = n.l;
    if (l.emb > 0) {
        const e = n.p[l.e + g.ids[slot] * l.emb ..][0..l.emb];
        const r = n.p[l.r + (slot % 5) * l.emb ..][0..l.emb];
        for (v.x[0..l.emb], e, r) |*x, a, b| x.* = a + b;
    }
    @memcpy(v.x[l.emb..], &g.x[slot]);
    const wk = n.p[l.w..l.out];
    for (v.h, 0..) |*h, j| {
        const z = dot(wk[j * l.input ..][0..l.input], v.x) + n.p[l.b + j];
        const kept = if (rnd) |rr| rr.float(f32) < keep else true;
        h.* = if (z > 0 and kept) (if (rnd != null) z / keep else z) else 0;
    }
    return dot(n.p[l.out..l.len], v.h);
}

fn backwardSlot(n: *const Net, g: *const NetGame, slot: usize, v: Slot, df: f32, keep: f32, gr: []f32, dx: []f32) void {
    const l = n.l;
    axpy(gr[l.out..l.len], df, v.h);
    @memset(dx, 0);
    const wk = n.p[l.w..l.out];
    const gwk = gr[l.w..l.out];
    for (v.h, n.p[l.out..l.len], 0..) |h, wo, j| {
        if (h == 0) continue;
        const dz = df * wo / keep;
        gr[l.b + j] += dz;
        axpy(gwk[j * l.input ..][0..l.input], dz, v.x);
        axpy(dx, dz, wk[j * l.input ..][0..l.input]);
    }
    if (l.emb > 0) {
        axpy(gr[l.e + g.ids[slot] * l.emb ..][0..l.emb], 1, dx[0..l.emb]);
        axpy(gr[l.r + (slot % 5) * l.emb ..][0..l.emb], 1, dx[0..l.emb]);
    }
}

fn sigmoid(x: f32) f32 {
    return 1 / (1 + @exp(-x));
}

fn gameLogit(n: *const Net, g: *const NetGame, f: [10]f32) f32 {
    var s: f32 = 0;
    for (f, 0..) |x, slot| s += if (slot < 5) x else -x;
    return s + n.p[n.l.c + g.platform] + n.p[n.l.a] * g.off;
}

fn predict(n: *const Net, games: []const NetGame, w: *const Work, out: []f32) void {
    for (games, out) |*g, *o| {
        var f: [10]f32 = undefined;
        for (&f, 0..) |*x, slot| x.* = forwardSlot(n, g, slot, w.slots[slot], 1, null);
        o.* = sigmoid(gameLogit(n, g, f));
    }
}

const Work = struct {
    buf: []f32,
    slots: [10]Slot,
    dx: []f32,

    fn init(gpa: std.mem.Allocator, l: Layout) !Work {
        const per = l.input + l.hidden;
        const buf = try gpa.alloc(f32, 10 * per + l.input);
        var w: Work = .{ .buf = buf, .slots = undefined, .dx = buf[10 * per ..][0..l.input] };
        for (&w.slots, 0..) |*s, i| {
            s.x = buf[i * per ..][0..l.input];
            s.h = buf[i * per + l.input ..][0..l.hidden];
        }
        return w;
    }

    fn deinit(w: *const Work, gpa: std.mem.Allocator) void {
        gpa.free(w.buf);
    }
};

const Trained = struct { net: Net, steps: u64, epochs: f64, val_loss: f64 };

fn stepsPerEpoch(n: usize, batch: u32) u64 {
    return @max(1, (n + batch - 1) / batch);
}

/// Steps for the refit on n games: a tenth more games, a tenth more epochs
fn refitSteps(epochs: f64, n: usize, batch: u32) u64 {
    const per: f64 = @floatFromInt(stepsPerEpoch(n, batch));
    return @max(1, @as(u64, @intFromFloat(@round(epochs * 1.1 * per))));
}

/// AdamW over shuffled batches for at most max_steps; with val, evaluated opts.evals
/// times an epoch, stopping after `patience` evaluations without a new best and keeping
/// the best one's parameters
fn train(gpa: std.mem.Allocator, opts: Options, seed: u32, n_ids: u32, games: []const NetGame, val: ?[]const NetGame, max_steps: u64, emb_init: ?EmbInit) !Trained {
    var rng: std.Random.DefaultPrng = .init(seed);
    const rnd = rng.random();
    const l: Layout = .init(n_ids, opts.emb, opts.hidden);
    var n = try Net.init(gpa, l, rnd);
    errdefer gpa.free(n.p);
    if (emb_init) |ei| try ei.table.apply(ei.vocab, l, n.p);
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
    const order = try gpa.alloc(u32, games.len);
    defer gpa.free(order);
    for (order, 0..) |*o, i| o.* = @intCast(i);
    const vpred = try gpa.alloc(f32, if (val) |v| v.len else 0);
    defer gpa.free(vpred);
    const keep = 1 - opts.dropout;
    const drop: ?std.Random = if (opts.dropout > 0) rnd else null;
    const emb_wd = opts.emb_wd orelse opts.wd;
    const per_epoch = stepsPerEpoch(games.len, opts.batch);
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
            const g = &games[gi];
            var f: [10]f32 = undefined;
            for (&f, 0..) |*x, slot| x.* = forwardSlot(&n, g, slot, w.slots[slot], keep, drop);
            const dl = (sigmoid(gameLogit(&n, g, f)) - g.y) / count;
            gr[l.c + g.platform] += dl;
            gr[l.a] += dl * g.off;
            for (0..10) |slot| backwardSlot(&n, g, slot, w.slots[slot], if (slot < 5) dl else -dl, keep, gr, w.dx);
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
            if (i == l.a and opts.fix_offset) continue;
            const decay: f32 = if (i < l.e) 0 else if (i < l.w) emb_wd * x.* else opts.wd * x.*;
            x.* -= opts.lr * ((s1.* / c1) / (@sqrt(s2.* / c2) + 1e-8) + decay);
        }
        const v = val orelse continue;
        if (step % eval_every != 0 and step != max_steps) continue;
        predict(&n, v, &w, vpred);
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

fn fitNet(gpa: std.mem.Allocator, io: Io, opts: Options, seed: u32, s: Sets) !Fitted {
    const t0 = Io.Clock.awake.now(io);
    var table: ?EmbTable = if (opts.emb_init) |dir| try .load(gpa, io, dir, s.block, seed, opts.emb) else null;
    defer if (table) |*t| t.deinit();
    const init_inner: ?EmbInit = if (table) |*t| .{ .table = t, .vocab = s.vocab_inner } else null;
    const init_all: ?EmbInit = if (table) |*t| .{ .table = t, .vocab = s.vocab_all } else null;
    const tuned = try train(gpa, opts, seed, s.n_inner, s.inner, s.val, opts.max_epochs * stepsPerEpoch(s.inner.len, opts.batch), init_inner);
    gpa.free(tuned.net.p);
    const full = try train(gpa, opts, seed, s.n_all, s.fit, null, refitSteps(tuned.epochs, s.fit.len, opts.batch), init_all);
    defer gpa.free(full.net.p);
    const w: Work = try .init(gpa, full.net.l);
    defer w.deinit(gpa);
    const pred = try gpa.alloc(f32, s.scored.len);
    predict(&full.net, s.scored, &w, pred);
    return .{ .pred = pred, .epochs = tuned.epochs, .val_loss = tuned.val_loss, .seconds = secondsSince(io, t0), .offset_weight = full.net.p[full.net.l.a] };
}

const testing = std.testing;

test "playernet gradient matches finite differences" {
    var rng: std.Random.DefaultPrng = .init(7);
    const rnd = rng.random();
    const l: Layout = .init(8, 3, 4);
    var n = try Net.init(testing.allocator, l, rnd);
    defer testing.allocator.free(n.p);
    for (n.p[l.out..l.len]) |*x| x.* = rnd.float(f32) - 0.5;
    n.p[l.a] = 0.8;
    var g: NetGame = .{ .ids = undefined, .x = undefined, .platform = 2, .y = 1, .off = 0.3 };
    for (&g.ids, &g.x) |*id, *x| {
        id.* = rnd.uintLessThan(u32, 8);
        for (x) |*v| v.* = rnd.float(f32) * 2 - 1;
    }
    const w: Work = try .init(testing.allocator, l);
    defer w.deinit(testing.allocator);
    const gr = try testing.allocator.alloc(f32, l.len);
    defer testing.allocator.free(gr);
    @memset(gr, 0);
    const lossAt = struct {
        fn f(net: *const Net, game: *const NetGame, wk: *const Work) f64 {
            var p: [1]f32 = undefined;
            predict(net, (game)[0..1], wk, &p);
            return loss1(game.y, p[0]);
        }
    }.f;
    var f: [10]f32 = undefined;
    for (&f, 0..) |*x, slot| x.* = forwardSlot(&n, &g, slot, w.slots[slot], 1, null);
    const dl = sigmoid(gameLogit(&n, &g, f)) - g.y;
    gr[l.c + g.platform] += dl;
    gr[l.a] += dl * g.off;
    for (0..10) |slot| {
        _ = forwardSlot(&n, &g, slot, w.slots[slot], 1, null);
        backwardSlot(&n, &g, slot, w.slots[slot], if (slot < 5) dl else -dl, 1, gr, w.dx);
    }
    const eps = 1e-3;
    for (0..l.len) |i| {
        const x0 = n.p[i];
        n.p[i] = x0 + eps;
        const up = lossAt(&n, &g, &w);
        n.p[i] = x0 - eps;
        const down = lossAt(&n, &g, &w);
        n.p[i] = x0;
        try testing.expectApproxEqAbs((up - down) / (2 * eps), gr[i], 2e-3);
    }
}

test "playernet is antisymmetric: swapping sides flips the logit" {
    var rng: std.Random.DefaultPrng = .init(3);
    const rnd = rng.random();
    const l: Layout = .init(6, 2, 5);
    var n = try Net.init(testing.allocator, l, rnd);
    defer testing.allocator.free(n.p);
    for (n.p[l.out..l.len]) |*x| x.* = rnd.float(f32) - 0.5;
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
    const w: Work = try .init(testing.allocator, l);
    defer w.deinit(testing.allocator);
    var p: [2]f32 = undefined;
    predict(&n, (&g)[0..1], &w, p[0..1]);
    predict(&n, (&s)[0..1], &w, p[1..2]);
    try testing.expectApproxEqAbs(@as(f32, 1), p[0] + p[1], 1e-5);
}
