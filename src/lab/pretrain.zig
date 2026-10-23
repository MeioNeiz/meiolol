//! `meiolol-lab pretrain SNAP`: champion-role embeddings learnt from what each seat did,
//! a signal far richer than win, then tested frozen as a prior for win-ratings' ratings.
//! Per block (dev-val and win-comp's 5 forward folds, nnexport's splits) and seed:
//!   1. Targets: nn-export's 22 aux per seat (early outcomes, SeatStats with totals per
//!      minute), z per role over the block's fit games, clipped at +-4, NaN masked
//!   2. Embeddings E (dim d) per champion-role with min_games fit games, else the role's
//!      shared vector: z[seat] = W[role] [E own; E lane opponent; mean E allies; mean E
//!      enemies] + b[role] + u[role] * (won ? 1 : -1). The won term takes the winner's
//!      lean out of E (end-of-game stats lean to the winner, as win-comp's halves).
//!      Adam, L2 on E and W, early stopping on the newest 10% of fit games, then a refit
//!      on all of them for a tenth more epochs
//!   3. Ratings as win-ratings (Adam batch 2048, L2 grid on the newest 10%, refit) with
//!      a prior: b[id] = w[role] . P[id] + delta[id], L2 on delta only. P: none, E,
//!      win-comp-style hand profiles (12, won/lost halves, z in role), or a random E
//!      (control: the content, not the extra parameters). L2 selection uses P from the
//!      inner games, the refit P from all fit games
//! Writes DIR/emb-<block>-s<seed>.tsv (for winnet --emb-init), aux.tsv, ratings.tsv,
//! preds.tsv and games-<variant>.tsv (netcheck's shape, none as ratings); gains paired
//! per game (= clustered by game)

const std = @import("std");
const rows = @import("rows.zig");
const protocol = @import("protocol.zig");
const harness = @import("harness.zig");
const winnet = @import("winnet.zig");
const nnexport = @import("nnexport.zig");
const seatstats = @import("seatstats.zig");
const nn = @import("nn");
const par = @import("../par.zig");
const Io = std.Io;
const Allocator = std.mem.Allocator;

pub const usage =
    \\  pretrain SNAP [OPT VALUE]...    champion-role embeddings from each seat's early
    \\                                  outcomes and end-of-game stats, tested as a prior
    \\                                  for the ratings on dev-val and the 5 forward folds
    \\                                  (lab/pretrain.zig): --dim N --min-games N --l2 X,X
    \\                                  --lr X --batch N --evals N --patience N
    \\                                  --max-epochs N --drop NAME,NAME --win-adjust 0|1
    \\                                  --rare N --seeds 1,2,3 --blocks dev,1,2,3,4,5
    \\                                  --shuffle SEED (control: win labels permuted
    \\                                  over all games first) --resample N (fit
    \\                                  games on netcheck --resample N's seeded 90%,
    \\                                  for embx's resample leg) --out DIR
    \\
;

const k = nnexport.k;
const n_early = k - seatstats.count;
const max_dim = 32;
const z_clip = 4;
const val_share = 0.1;
const n_platforms = 16;

pub const Options = struct {
    dim: u32 = 12,
    /// Champion-roles with fewer fit games share their role's vector
    min_games: u32 = 20,
    /// Aux L2 grid on E and W, picked on the validation games' aux loss
    l2: []const f32 = &.{1e-4},
    lr: f32 = 3e-3,
    /// Games per step (10 seats each)
    batch: u32 = 512,
    evals: u32 = 4,
    patience: u32 = 3,
    max_epochs: u32 = 30,
    /// Targets left out of the aux loss, bit per aux index
    drop: u32 = 0,
    win_adjust: bool = true,
    /// Scored games with a pick under this many fit games count as rare
    rare: u32 = 200,
    seeds: []const u32 = &.{ 1, 2, 3 },
    blocks: []const Block = &.{ .dev, .f1, .f2, .f3, .f4, .f5 },
    /// Shuffled-label control: the games' win labels permuted before anything is fitted,
    /// so a prior's gain must be ~0
    shuffle: ?u64 = null,
    /// Fit games on netcheck --resample N's 90% (harness.inResample), so a candidate fitted
    /// there finds E learnt on exactly its games
    resample: ?u32 = null,
    out: []const u8 = ".",
};

pub const Block = enum { dev, f1, f2, f3, f4, f5 };

fn fits(b: Block, split: u8) bool {
    return if (b == .dev) split <= nnexport.folds else split < @backingInt(b);
}

fn scores(b: Block, split: u8) bool {
    return if (b == .dev) split == @backingInt(nnexport.Split.dev_val) else split == @backingInt(b);
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

fn auxNames() [k][]const u8 {
    var out: [k][]const u8 = undefined;
    for (out[0..n_early], [_][]const u8{ "gold14", "lanediff14", "cs10", "deaths15", "first_item" }) |*o, n| o.* = n;
    inline for (@typeInfo(seatstats.SeatStat).@"enum".field_names, 0..) |name, i| out[n_early + i] = name;
    return out;
}

pub fn main(gpa: Allocator, arena: Allocator, io: Io, argv: []const []const u8) !u8 {
    if (argv.len < 1) {
        std.debug.print("usage:\n{s}", .{usage});
        return 2;
    }
    const opts = parseOptions(arena, argv[1..]) catch |e| {
        std.debug.print("pretrain: {s}\nusage:\n{s}", .{ @errorName(e), usage });
        return 2;
    };
    const snap = argv[0];
    var legendaries = try rows.loadLegendaries(gpa, io, snap);
    defer legendaries.deinit(gpa);
    var data = try rows.load(gpa, snap, &legendaries);
    defer data.deinit();
    const ids = protocol.platformIds();
    std.debug.assert(ids.len <= n_platforms);
    const c = try harness.cuts(gpa, &data);
    var e = try nnexport.build(gpa, &data, c);
    defer e.deinit();
    perMinute(e.aux);
    if (opts.shuffle) |seed| {
        var rng: std.Random.DefaultPrng = .init(seed);
        rng.random().shuffle(u8, e.blue_win);
    }

    try Io.Dir.cwd().createDirPath(io, opts.out);
    var dir = try Io.Dir.cwd().openDir(io, opts.out, .{});
    defer dir.close(io);
    var out_buf: [4096]u8 = undefined;
    var stdout = Io.File.stdout().writer(io, &out_buf);
    const w = &stdout.interface;
    try w.print("# pretrain: dim {d} min_games {d} l2 {any} lr {d} batch {d} evals {d} patience {d} max_epochs {d} drop 0x{x} win_adjust {} rare {d} seeds {any} shuffle {?d} resample {?d}\n\n", .{
        opts.dim, opts.min_games, opts.l2, opts.lr, opts.batch, opts.evals, opts.patience, opts.max_epochs, opts.drop, opts.win_adjust, opts.rare, opts.seeds, opts.shuffle, opts.resample,
    });
    try w.flush();

    const t0 = Io.Clock.awake.now(io);
    const outs = try runAll(gpa, io, &e, opts);
    defer {
        for (outs) |*o| o.deinit(gpa);
        gpa.free(outs);
    }
    try w.print("{d} jobs in {d:.1} s\n\n", .{ outs.len, secondsSince(io, t0) });
    for (outs) |o| try writeEmb(gpa, io, dir, &e, o);
    try writeTables(gpa, io, dir, &e, &data, outs);
    try summary(gpa, w, &e, opts, outs);
    try w.flush();
    return 0;
}

fn parseOptions(arena: Allocator, args: []const []const u8) !Options {
    var o: Options = .{};
    var i: usize = 0;
    while (i < args.len) : (i += 2) {
        if (i + 1 >= args.len) return error.MissingValue;
        const key = args[i];
        const v = args[i + 1];
        if (std.mem.eql(u8, key, "--dim")) {
            o.dim = try std.fmt.parseInt(u32, v, 10);
        } else if (std.mem.eql(u8, key, "--min-games")) {
            o.min_games = try std.fmt.parseInt(u32, v, 10);
        } else if (std.mem.eql(u8, key, "--l2")) {
            var out: std.ArrayList(f32) = .empty;
            var it = std.mem.tokenizeScalar(u8, v, ',');
            while (it.next()) |s| try out.append(arena, try std.fmt.parseFloat(f32, s));
            if (out.items.len == 0) return error.BadValue;
            o.l2 = out.items;
        } else if (std.mem.eql(u8, key, "--lr")) {
            o.lr = try std.fmt.parseFloat(f32, v);
        } else if (std.mem.eql(u8, key, "--batch")) {
            o.batch = try std.fmt.parseInt(u32, v, 10);
        } else if (std.mem.eql(u8, key, "--evals")) {
            o.evals = try std.fmt.parseInt(u32, v, 10);
        } else if (std.mem.eql(u8, key, "--patience")) {
            o.patience = try std.fmt.parseInt(u32, v, 10);
        } else if (std.mem.eql(u8, key, "--max-epochs")) {
            o.max_epochs = try std.fmt.parseInt(u32, v, 10);
        } else if (std.mem.eql(u8, key, "--drop")) {
            const names = auxNames();
            var it = std.mem.tokenizeScalar(u8, v, ',');
            while (it.next()) |s| {
                const j = for (names, 0..) |n, j| {
                    if (std.mem.eql(u8, n, s)) break j;
                } else return error.UnknownTarget;
                o.drop |= @as(u32, 1) << @intCast(j);
            }
        } else if (std.mem.eql(u8, key, "--win-adjust")) {
            o.win_adjust = !std.mem.eql(u8, v, "0");
        } else if (std.mem.eql(u8, key, "--rare")) {
            o.rare = try std.fmt.parseInt(u32, v, 10);
        } else if (std.mem.eql(u8, key, "--seeds")) {
            o.seeds = try winnet.parseSeeds(arena, v);
        } else if (std.mem.eql(u8, key, "--blocks")) {
            var out: std.ArrayList(Block) = .empty;
            var it = std.mem.tokenizeScalar(u8, v, ',');
            while (it.next()) |s| try out.append(arena, if (std.mem.eql(u8, s, "dev"))
                .dev
            else
                try winnet.foldBlock(Block, s));
            o.blocks = out.items;
        } else if (std.mem.eql(u8, key, "--shuffle")) {
            o.shuffle = try std.fmt.parseInt(u64, v, 10);
        } else if (std.mem.eql(u8, key, "--resample")) {
            o.resample = try std.fmt.parseInt(u32, v, 10);
        } else if (std.mem.eql(u8, key, "--out")) {
            o.out = v;
        } else return error.UnknownOption;
    }
    if (o.dim == 0 or o.dim > max_dim or o.evals == 0 or o.batch == 0 or o.blocks.len == 0) return error.BadValue;
    return o;
}

fn perMinuteStat(s: seatstats.SeatStat) bool {
    return switch (s) {
        .minutes, .armor_end, .mr_end, .attack_range => false,
        else => true,
    };
}

/// SeatStat totals to per minute, in place over [n][10][k]
fn perMinute(aux: []f32) void {
    const mins_at = n_early + @as(usize, @backingInt(seatstats.SeatStat.minutes));
    var at: usize = 0;
    while (at < aux.len) : (at += k) {
        const t = aux[at..][0..k];
        const mins = t[mins_at];
        for (std.enums.values(seatstats.SeatStat), 0..) |s, i| {
            if (!perMinuteStat(s)) continue;
            t[n_early + i] = if (mins > 0) t[n_early + i] / mins else std.math.nan(f32);
        }
    }
}

fn played(e: *const nnexport.Export, gi: usize) bool {
    return e.flags[gi] & nnexport.flag_played != 0;
}

fn inResample(e: *const nnexport.Export, gi: usize, resample: ?u32) bool {
    const r = resample orelse return true;
    return harness.inResample(e.start[gi], e.platform[gi], r);
}

fn keyOf(e: *const nnexport.Export, gi: usize, slot: usize) u32 {
    return @as(u32, e.champ[gi][slot]) * 5 + @as(u32, @intCast(slot % 5));
}

fn nKeys(e: *const nnexport.Export) usize {
    return e.champions.len * 5;
}

fn seatWon(e: *const nnexport.Export, gi: usize, slot: usize) bool {
    return (slot < 5) == (e.blue_win[gi] == 1);
}

/// Per role and target: mean and sd over the given games' known values
const Norm = struct {
    mean: [5][k]f32,
    sd: [5][k]f32,

    fn of(aux: []const f32, games: []const u32) Norm {
        var n: [5][k]f64 = @splat(@splat(0));
        var s1: [5][k]f64 = @splat(@splat(0));
        var s2: [5][k]f64 = @splat(@splat(0));
        for (games) |gi| for (0..10) |slot| {
            const t = aux[(@as(usize, gi) * 10 + slot) * k ..][0..k];
            for (t, 0..) |x, j| if (!std.math.isNan(x)) {
                n[slot % 5][j] += 1;
                s1[slot % 5][j] += x;
                s2[slot % 5][j] += @as(f64, x) * x;
            };
        };
        var out: Norm = undefined;
        for (0..5) |r| for (0..k) |j| {
            const m = if (n[r][j] > 0) s1[r][j] / n[r][j] else 0;
            const v = if (n[r][j] > 1) s2[r][j] / n[r][j] - m * m else 0;
            out.mean[r][j] = @floatCast(m);
            // sd 0 (a constant): the target is left out
            out.sd[r][j] = if (v > 1e-12) @floatCast(@sqrt(v)) else 0;
        };
        return out;
    }

    fn z(n: *const Norm, r: usize, j: usize, x: f32) ?f32 {
        if (std.math.isNan(x) or n.sd[r][j] == 0) return null;
        return std.math.clamp((x - n.mean[r][j]) / n.sd[r][j], -z_clip, z_clip);
    }
};

/// Champion-role key -> embedding id: 0..4 the role's shared vector, 5.. keys with at
/// least min_games games
const Vocab = struct {
    id: []u32,
    n: usize,

    fn init(gpa: Allocator, e: *const nnexport.Export, games: []const u32, min_games: u32) !Vocab {
        const counts = try keyCounts(gpa, e, games);
        defer gpa.free(counts);
        const id = try gpa.alloc(u32, counts.len);
        var n: u32 = 5;
        for (id, counts, 0..) |*x, cnt, key| {
            if (cnt >= @max(min_games, 1)) {
                x.* = n;
                n += 1;
            } else x.* = @intCast(key % 5);
        }
        return .{ .id = id, .n = n };
    }

    fn deinit(v: *const Vocab, gpa: Allocator) void {
        gpa.free(v.id);
    }
};

fn keyCounts(gpa: Allocator, e: *const nnexport.Export, games: []const u32) ![]u32 {
    const counts = try gpa.alloc(u32, nKeys(e));
    @memset(counts, 0);
    for (games) |gi| for (0..10) |slot| {
        counts[keyOf(e, gi, slot)] += 1;
    };
    return counts;
}

/// Aux model's parameters: E [nv][d] first (embPrior and the export read it from offset
/// 0), W [5 k][4d] (row r k + j: role r, target j), both with L2 l2; b and u [5 k], none
const AuxShape = struct {
    ps: nn.Params,
    d: usize,
    e: nn.Param,
    w: nn.Param,
    b: nn.Param,
    u: nn.Param,

    fn init(gpa: Allocator, nv: usize, d: usize, l2: f32) !AuxShape {
        var m: AuxShape = .{ .ps = .empty, .d = d, .e = undefined, .w = undefined, .b = undefined, .u = undefined };
        errdefer m.ps.deinit(gpa);
        m.e = try m.ps.table(gpa, "champion_role", nv, d, .{ .init = .{ .uniform = 0.1 }, .decay = l2 });
        const bound = @sqrt(6.0 / @as(f32, @floatFromInt(4 * d + k)));
        m.w = try m.ps.matrix(gpa, "w", 5 * k, 4 * d, .{ .init = .{ .uniform = bound }, .decay = l2 });
        m.b = try m.ps.vector(gpa, "b", 5 * k, .{});
        m.u = try m.ps.vector(gpa, "u", 5 * k, .{});
        return m;
    }
};

/// What a game set's aux fit reads
const AuxData = struct {
    e: *const nnexport.Export,
    norm: *const Norm,
    vocab: []const u32,
    /// Targets in the loss
    use: [k]bool,
    win_adjust: bool,
    /// Per role, lost then won: the mean z of the training seats (R^2's baseline)
    base: *const [5][2][k]f32,
};

/// Per target: squared errors of the model and of the role x won baseline, counts
const Sse = struct {
    model: [k]f64 = @splat(0),
    base: [k]f64 = @splat(0),
    n: [k]f64 = @splat(0),

    fn loss(s: Sse) f64 {
        var a: f64 = 0;
        var n: f64 = 0;
        for (s.model, s.n) |x, c| {
            a += x;
            n += c;
        }
        return a / @max(n, 1);
    }

    fn baseLoss(s: Sse) f64 {
        var a: f64 = 0;
        var n: f64 = 0;
        for (s.base, s.n) |x, c| {
            a += x;
            n += c;
        }
        return a / @max(n, 1);
    }
};

/// One game's ten seats: adds the gradient of 0.5 * squared error times scale to gr
/// (when given) and the squared errors to sse (when given)
fn auxGame(m: *const AuxShape, p: []const f32, ad: *const AuxData, gi: usize, gr: ?[]f32, scale: f32, sse: ?*Sse) void {
    const d = m.d;
    const in = 4 * d;
    var ids: [10]u32 = undefined;
    for (&ids, 0..) |*id, slot| id.* = ad.vocab[keyOf(ad.e, gi, slot)];
    var sum: [2][max_dim]f32 = @splat(@splat(0));
    for (ids, 0..) |id, slot| nn.axpy(sum[slot / 5][0..d], 1, m.e.row(p, id));
    for (0..10) |slot| {
        const side = slot / 5;
        const r = slot % 5;
        const t = ad.e.aux[(gi * 10 + slot) * k ..][0..k];
        const own = m.e.row(p, ids[slot]);
        const opp = m.e.row(p, ids[(slot + 5) % 10]);
        var x: [4 * max_dim]f32 = undefined;
        @memcpy(x[0..d], own);
        @memcpy(x[d .. 2 * d], opp);
        for (0..d) |i| {
            x[2 * d + i] = (sum[side][i] - own[i]) / 4;
            x[3 * d + i] = sum[1 - side][i] / 5;
        }
        const won = seatWon(ad.e, gi, slot);
        const sgn: f32 = if (!ad.win_adjust) 0 else if (won) 1 else -1;
        var dx: [4 * max_dim]f32 = @splat(0);
        for (0..k) |j| {
            if (!ad.use[j]) continue;
            const z = ad.norm.z(r, j, t[j]) orelse continue;
            const rj = r * k + j;
            const wj = m.w.row(p, rj);
            const err = nn.dot(wj, x[0..in]) + m.b.at(p, rj).* + m.u.at(p, rj).* * sgn - z;
            if (sse) |s| {
                const bz = z - ad.base[r][@intFromBool(won)][j];
                s.model[j] += err * err;
                s.base[j] += bz * bz;
                s.n[j] += 1;
            }
            if (gr) |g| {
                const ge = err * scale;
                nn.axpy(m.w.row(g, rj), ge, x[0..in]);
                m.b.at(g, rj).* += ge;
                m.u.at(g, rj).* += ge * sgn;
                nn.axpy(dx[0..in], ge, wj);
            }
        }
        const g = gr orelse continue;
        nn.axpy(m.e.row(g, ids[slot]), 1, dx[0..d]);
        nn.axpy(m.e.row(g, ids[(slot + 5) % 10]), 1, dx[d .. 2 * d]);
        for (0..10) |o| {
            if (o == slot) continue;
            if (o / 5 == side) nn.axpy(m.e.row(g, ids[o]), 0.25, dx[2 * d .. 3 * d]) else nn.axpy(m.e.row(g, ids[o]), 0.2, dx[3 * d .. 4 * d]);
        }
    }
}

fn baseMeans(e: *const nnexport.Export, norm: *const Norm, games: []const u32) [5][2][k]f32 {
    var s: [5][2][k]f64 = @splat(@splat(@splat(0)));
    var n: [5][2][k]f64 = @splat(@splat(@splat(0)));
    for (games) |gi| for (0..10) |slot| {
        const won: usize = @intFromBool(seatWon(e, gi, slot));
        const t = e.aux[(@as(usize, gi) * 10 + slot) * k ..][0..k];
        for (t, 0..) |x, j| if (norm.z(slot % 5, j, x)) |z| {
            s[slot % 5][won][j] += z;
            n[slot % 5][won][j] += 1;
        };
    };
    var out: [5][2][k]f32 = undefined;
    for (0..5) |r| for (0..2) |h| for (0..k) |j| {
        out[r][h][j] = if (n[r][h][j] > 0) @floatCast(s[r][h][j] / n[r][h][j]) else 0;
    };
    return out;
}

fn sseOf(m: *const AuxShape, p: []const f32, ad: *const AuxData, games: []const u32) Sse {
    var s: Sse = .{};
    for (games) |gi| auxGame(m, p, ad, gi, null, 0, &s);
    return s;
}

const AuxTrained = struct { p: []f32, steps: u64, epochs: f64, val: Sse };

/// trainAux's side of nn.fit
const AuxFit = struct {
    m: *const AuxShape,
    ad: *const AuxData,
    train: []const u32,
    val: []const u32,
    p: []f32,
    gr: []f32,
    opt: *nn.Adam,
    segs: []const nn.Segment,

    pub fn step(f: *AuxFit, part: []const u32) !void {
        @memset(f.gr, 0);
        const scale = 1 / @as(f32, @floatFromInt(10 * part.len));
        for (part) |i| auxGame(f.m, f.p, f.ad, f.train[i], f.gr, scale, null);
        f.opt.step(f.p, f.gr, f.segs);
    }

    pub fn valLoss(f: *AuxFit) !f64 {
        return sseOf(f.m, f.p, f.ad, f.val).loss();
    }
};

/// Adam (L2 in the gradient) over shuffled game batches for at most max_steps; with val,
/// evaluated opts.evals times an epoch, stopping after `patience` evaluations without a
/// new best and keeping the best one's parameters. E has nv rows
fn trainAux(gpa: Allocator, opts: Options, l2: f32, seed: u32, nv: usize, ad: *const AuxData, train: []const u32, val: ?[]const u32, max_steps: u64) !AuxTrained {
    var rng: std.Random.DefaultPrng = .init(seed);
    const rnd = rng.random();
    var m: AuxShape = try .init(gpa, nv, opts.dim, l2);
    defer m.ps.deinit(gpa);
    const p = try m.ps.alloc(gpa);
    errdefer gpa.free(p);
    m.ps.initValues(p, rnd);
    const gr = try m.ps.alloc(gpa);
    defer gpa.free(gr);
    const best = try m.ps.alloc(gpa);
    defer gpa.free(best);
    const segs = try m.ps.segments(gpa);
    defer gpa.free(segs);
    var opt: nn.Adam = try .init(gpa, m.ps.len, .{ .lr = opts.lr, .decay = .coupled });
    defer opt.deinit(gpa);
    var f: AuxFit = .{ .m = &m, .ad = ad, .train = train, .val = val orelse &.{}, .p = p, .gr = gr, .opt = &opt, .segs = segs };
    const r = try nn.fit(gpa, &f, .{
        .batch = opts.batch,
        .max_steps = max_steps,
        .evals_per_epoch = opts.evals,
        .patience = opts.patience,
        .validate = val != null,
    }, train.len, rnd, p, best);
    // The best validation's errors: p is back at its parameters
    const sse: Sse = if (val != null and r.steps > 0) sseOf(&m, p, ad, val.?) else .{};
    return .{ .p = p, .steps = r.steps, .epochs = r.epochs, .val = sse };
}

/// Hand profile features from a seat's (per minute) aux, NaN unknown: win-comp's 12
const n_hand = 12;

fn handValues(t: []const f32) [n_hand]f32 {
    const S = seatstats.SeatStat;
    const st = struct {
        fn at(x: []const f32, s: S) f32 {
            return x[n_early + @as(usize, @backingInt(s))];
        }
        fn share(x: f32, total: f32) f32 {
            return if (total > 0) x / total else std.math.nan(f32);
        }
    };
    const dealt = st.at(t, .dmg_phys) + st.at(t, .dmg_magic) + st.at(t, .dmg_true);
    const taken = st.at(t, .taken_phys) + st.at(t, .taken_magic) + st.at(t, .taken_true);
    const mitigated = st.at(t, .mitigated);
    const own_heal = st.at(t, .heal) - st.at(t, .heal_allies);
    return .{
        st.share(st.at(t, .dmg_magic), dealt),
        st.share(st.at(t, .dmg_true), dealt),
        dealt,
        st.share(mitigated, mitigated + taken),
        taken,
        st.at(t, .armor_end) - st.at(t, .mr_end),
        st.at(t, .cc_time),
        st.at(t, .immobilisations),
        st.at(t, .heal_allies) + st.at(t, .shield_allies),
        if (std.math.isNan(own_heal)) own_heal else @max(own_heal, 0),
        st.at(t, .attack_range),
        st.at(t, .dmg_buildings),
    };
}

/// win-comp's pseudo-rows toward the role mean, per half
const hand_pseudo = 20;

/// Per key [n_hand]: the won and lost halves' means, each shrunk to the role mean,
/// averaged; z within role weighted by seats. Keys without seats: 0
fn handProfiles(gpa: Allocator, e: *const nnexport.Export, games: []const u32) ![]f32 {
    const nk = nKeys(e);
    // [key][half][feature]: sum, count
    const acc = try gpa.alloc([2][n_hand][2]f64, nk);
    defer gpa.free(acc);
    @memset(acc, @splat(@splat(@splat(0))));
    const seen = try gpa.alloc(f64, nk);
    defer gpa.free(seen);
    @memset(seen, 0);
    var role_acc: [5][n_hand][2]f64 = @splat(@splat(@splat(0)));
    for (games) |gi| for (0..10) |slot| {
        const key = keyOf(e, gi, slot);
        const half: usize = @intFromBool(seatWon(e, gi, slot));
        seen[key] += 1;
        const v = handValues(e.aux[(@as(usize, gi) * 10 + slot) * k ..][0..k]);
        for (v, 0..) |x, f| {
            if (std.math.isNan(x) or std.math.isInf(x)) continue;
            acc[key][half][f][0] += x;
            acc[key][half][f][1] += 1;
            role_acc[slot % 5][f][0] += x;
            role_acc[slot % 5][f][1] += 1;
        }
    };
    const raw = try gpa.alloc(f32, nk * n_hand);
    errdefer gpa.free(raw);
    for (0..nk) |key| for (0..n_hand) |f| {
        const ra = role_acc[key % 5][f];
        const rm = if (ra[1] > 0) ra[0] / ra[1] else 0;
        var v: f64 = 0;
        for (0..2) |h| v += 0.5 * (acc[key][h][f][0] + hand_pseudo * rm) / (acc[key][h][f][1] + hand_pseudo);
        raw[key * n_hand + f] = @floatCast(v);
    };
    for (0..5) |r| for (0..n_hand) |f| {
        var sw: f64 = 0;
        var s1: f64 = 0;
        var s2: f64 = 0;
        var key = r;
        while (key < nk) : (key += 5) {
            const x: f64 = raw[key * n_hand + f];
            sw += seen[key];
            s1 += seen[key] * x;
            s2 += seen[key] * x * x;
        }
        const mean = if (sw > 0) s1 / sw else 0;
        const sd = @sqrt(@max(if (sw > 0) s2 / sw - mean * mean else 0, 0));
        key = r;
        while (key < nk) : (key += 5) {
            const at = key * n_hand + f;
            raw[at] = if (seen[key] == 0 or sd < 1e-9) 0 else @floatCast((raw[at] - mean) / sd);
        }
    };
    return raw;
}

/// splitmix64: a fixed random number per (seed, key, coordinate)
fn mix(x0: u64) u64 {
    var x = x0 +% 0x9e3779b97f4a7c15;
    x = (x ^ (x >> 30)) *% 0xbf58476d1ce4e5b9;
    x = (x ^ (x >> 27)) *% 0x94d049bb133111eb;
    return x ^ (x >> 31);
}

/// N(0, 1) per (seed, id, coordinate), by Box-Muller
fn randNorm(seed: u32, id: u64, j: usize) f32 {
    const h1 = mix(mix(seed) ^ (id << 8) ^ j);
    const h2 = mix(h1);
    const u_1 = (@as(f64, @floatFromInt(h1 >> 11)) + 0.5) / @as(f64, 1 << 53);
    const u_2 = @as(f64, @floatFromInt(h2 >> 11)) / @as(f64, 1 << 53);
    return @floatCast(@sqrt(-2 * @log(u_1)) * @cos(2 * std.math.pi * u_2));
}

const Variant = enum { none, emb, hand, rand };
const n_var = @typeInfo(Variant).@"enum".field_names.len;

/// One game for the ratings: dense rating ids by slot (0..4: unseen, the role's)
const RGame = struct {
    ids: [10]u16,
    platform: u8,
    y: f32,
};

const r_batch = 2048;
const r_lr = 0.003;
const r_max_epochs = 60;
const r_patience = 5;
const l2_grid = [_]f32{ 3e-4, 1e-3, 3e-3, 1e-2 };

/// Ratings with a prior: c [platforms] and w [5][dp] unshrunk, delta [n] with L2.
/// b[id] = w[role id] . prior[id] + delta[id]
const RModel = struct {
    n: usize,
    dp: usize,
    role: []const u8,
    /// [n][dp]
    prior: []const f32,

    fn w(_: RModel) usize {
        return n_platforms;
    }

    fn delta(m: RModel) usize {
        return n_platforms + 5 * m.dp;
    }

    fn len(m: RModel) usize {
        return m.delta() + m.n;
    }

    /// c and w unshrunk, delta with L2 l2
    fn segments(m: RModel, l2: f32) [2]nn.Segment {
        return .{ .{ .len = m.delta() }, .{ .len = m.n, .decay = l2 } };
    }

    fn ratings(m: RModel, p: []const f32, out: []f32) void {
        const dl = m.delta();
        for (out, 0..) |*b, id| {
            b.* = p[dl + id];
            if (m.dp > 0) b.* += nn.dot(p[m.w() + @as(usize, m.role[id]) * m.dp ..][0..m.dp], m.prior[id * m.dp ..][0..m.dp]);
        }
    }

    fn logit(_: RModel, p: []const f32, b: []const f32, g: *const RGame) f32 {
        var s = p[g.platform];
        for (0..5) |r| s += b[g.ids[r]] - b[g.ids[5 + r]];
        return s;
    }
};

const sigmoid = nn.sigmoid;
const loss1 = nn.logLoss;

fn rLoss(m: RModel, p: []const f32, b: []f32, set: []const RGame) f64 {
    m.ratings(p, b);
    var s: f64 = 0;
    for (set) |*g| s += loss1(g.y, sigmoid(m.logit(p, b, g)));
    return s / @as(f64, @floatFromInt(@max(set.len, 1)));
}

const RTrained = struct { p: []f32, epochs: u32, val_loss: f64 };

/// gr = the summed log-loss gradient of the games set[i], i in part; b and gb: m.n of
/// scratch
fn rGrad(m: RModel, p: []const f32, b: []f32, gb: []f32, gr: []f32, set: []const RGame, part: []const u32) void {
    m.ratings(p, b);
    @memset(gr, 0);
    @memset(gb, 0);
    for (part) |i| {
        const g = &set[i];
        const r = sigmoid(m.logit(p, b, g)) - g.y;
        gr[g.platform] += r;
        for (0..5) |ro| {
            gb[g.ids[ro]] += r;
            gb[g.ids[5 + ro]] -= r;
        }
    }
    const dl = m.delta();
    for (gb, 0..) |x, id| {
        if (x == 0) continue;
        gr[dl + id] += x;
        if (m.dp > 0) nn.axpy(gr[m.w() + @as(usize, m.role[id]) * m.dp ..][0..m.dp], x, m.prior[id * m.dp ..][0..m.dp]);
    }
}

/// trainRatings' side of nn.fit
const RatingsFit = struct {
    m: RModel,
    set: []const RGame,
    val: []const RGame,
    p: []f32,
    b: []f32,
    gb: []f32,
    gr: []f32,
    opt: *nn.Adam,
    segs: []const nn.Segment,

    pub fn step(f: *RatingsFit, part: []const u32) !void {
        rGrad(f.m, f.p, f.b, f.gb, f.gr, f.set, part);
        const scale = 1 / @as(f32, @floatFromInt(part.len));
        for (f.gr) |*g| g.* *= scale;
        f.opt.step(f.p, f.gr, f.segs);
    }

    pub fn valLoss(f: *RatingsFit) !f64 {
        return rLoss(f.m, f.p, f.b, f.val);
    }
};

/// win-ratings' train: Adam (L2 in the gradient) on batches of 2048 games; with val,
/// stops on it after `r_patience` epochs without a new best and keeps the best
fn trainRatings(gpa: Allocator, m: RModel, l2: f32, set: []const RGame, val: ?[]const RGame, epochs_cap: u32, seed: u64) !RTrained {
    const len = m.len();
    const p = try gpa.alloc(f32, len);
    errdefer gpa.free(p);
    @memset(p, 0);
    var rng: std.Random.DefaultPrng = .init(seed);
    const scratch = try gpa.alloc(f32, 2 * len + 2 * m.n);
    defer gpa.free(scratch);
    var opt: nn.Adam = try .init(gpa, len, .{ .lr = r_lr, .decay = .coupled });
    defer opt.deinit(gpa);
    const segs = m.segments(l2);
    var f: RatingsFit = .{
        .m = m,
        .set = set,
        .val = val orelse &.{},
        .p = p,
        .gr = scratch[0..len],
        .b = scratch[2 * len ..][0..m.n],
        .gb = scratch[2 * len + m.n ..][0..m.n],
        .opt = &opt,
        .segs = &segs,
    };
    const per_epoch = nn.stepsPerEpoch(set.len, r_batch);
    const r = try nn.fit(gpa, &f, .{
        .batch = r_batch,
        .max_steps = epochs_cap * per_epoch,
        .patience = r_patience,
        .validate = val != null,
    }, set.len, rng.random(), p, scratch[len..][0..len]);
    return .{ .p = p, .epochs = @intCast(r.steps / per_epoch), .val_loss = r.loss };
}

const RFit = struct { pred: []f32, l2: f32, epochs: u32, val_loss: f64 };

/// L2 and epochs picked on val with the inner prior, refit on inner + val with the full
/// one for a tenth more epochs (win-ratings' fit); blue's chance per scored game
fn fitRatings(gpa: Allocator, m_inner: RModel, m_all: RModel, inner: []const RGame, val: []const RGame, all: []const RGame, scored: []const RGame, seed: u64) !RFit {
    var best: struct { l2: f32 = 0, epochs: u32 = 0, loss: f64 = std.math.inf(f64) } = .{};
    for (l2_grid) |l2| {
        const tr = try trainRatings(gpa, m_inner, l2, inner, val, r_max_epochs, seed);
        defer gpa.free(tr.p);
        if (tr.val_loss < best.loss) best = .{ .l2 = l2, .epochs = tr.epochs, .loss = tr.val_loss };
    }
    const refit = try trainRatings(gpa, m_all, best.l2, all, null, @max(1, best.epochs + best.epochs / 10), seed);
    defer gpa.free(refit.p);
    const b = try gpa.alloc(f32, m_all.n);
    defer gpa.free(b);
    m_all.ratings(refit.p, b);
    const pred = try gpa.alloc(f32, scored.len);
    for (pred, scored) |*o, *g| o.* = sigmoid(m_all.logit(refit.p, b, g));
    return .{ .pred = pred, .l2 = best.l2, .epochs = best.epochs, .val_loss = best.loss };
}

/// One (block, seed)
const JobOut = struct {
    block: Block,
    seed: u32,
    fit_games: usize,
    /// Aux fit on the inner games, scored on val (early stopping's best)
    aux_val: Sse,
    aux_l2: f32,
    aux_epochs: f64,
    /// E refitted on all fit games [vocab.n][d], with its vocab and per key fit games
    emb: []f32,
    vocab: Vocab,
    key_games: []u32,
    scored: []u32,
    /// Scored game has a pick under opts.rare fit games
    rare: []bool,
    pred: [n_var][]f32,
    fit: [n_var]RFit,
    seconds: f64,

    fn deinit(o: *JobOut, gpa: Allocator) void {
        gpa.free(o.emb);
        o.vocab.deinit(gpa);
        gpa.free(o.key_games);
        gpa.free(o.scored);
        gpa.free(o.rare);
        for (o.pred) |p| gpa.free(p);
    }
};

const JobCtx = struct {
    gpa: Allocator,
    io: Io,
    e: *const nnexport.Export,
    opts: Options,
    outs: []JobOut,

    fn one(c: JobCtx, i: usize) !void {
        const n_s = c.opts.seeds.len;
        c.outs[i] = try job(c.gpa, c.io, c.e, c.opts, c.opts.blocks[i / n_s], c.opts.seeds[i % n_s]);
    }
};

fn runAll(gpa: Allocator, io: Io, e: *const nnexport.Export, opts: Options) ![]JobOut {
    const n = opts.blocks.len * opts.seeds.len;
    const outs = try gpa.alloc(JobOut, n);
    errdefer gpa.free(outs);
    try par.forEach(io, n, JobCtx{ .gpa = gpa, .io = io, .e = e, .opts = opts, .outs = outs }, JobCtx.one);
    return outs;
}

/// Rating ids from the fit games' keys: 5.. per key seen, 0..4 the role's unseen
const RIds = struct {
    of_key: []u16,
    /// Per id: its key (ids 0..4: none)
    key: []u32,
    role: []u8,

    fn init(gpa: Allocator, key_games: []const u32) !RIds {
        const of_key = try gpa.alloc(u16, key_games.len);
        errdefer gpa.free(of_key);
        var keys: std.ArrayList(u32) = .empty;
        defer keys.deinit(gpa);
        for (of_key, key_games, 0..) |*x, n, key| {
            if (n > 0) {
                x.* = @intCast(5 + keys.items.len);
                try keys.append(gpa, @intCast(key));
            } else x.* = @intCast(key % 5);
        }
        const n_ids = 5 + keys.items.len;
        const key = try gpa.alloc(u32, n_ids);
        errdefer gpa.free(key);
        const role = try gpa.alloc(u8, n_ids);
        for (0..5) |r| {
            key[r] = std.math.maxInt(u32);
            role[r] = @intCast(r);
        }
        for (keys.items, 5..) |kk, id| {
            key[id] = kk;
            role[id] = @intCast(kk % 5);
        }
        return .{ .of_key = of_key, .key = key, .role = role };
    }

    fn deinit(r: *const RIds, gpa: Allocator) void {
        gpa.free(r.of_key);
        gpa.free(r.key);
        gpa.free(r.role);
    }

    fn games(r: *const RIds, gpa: Allocator, e: *const nnexport.Export, list: []const u32) ![]RGame {
        const out = try gpa.alloc(RGame, list.len);
        for (out, list) |*o, gi| {
            for (&o.ids, 0..) |*id, slot| id.* = r.of_key[keyOf(e, gi, slot)];
            o.platform = e.platform[gi];
            o.y = @floatFromInt(e.blue_win[gi]);
        }
        return out;
    }

    /// [n_ids][d] from an embedding table: each id's vocab vector (unseen: the role's)
    fn embPrior(r: *const RIds, gpa: Allocator, emb: []const f32, vocab: []const u32, d: usize) ![]f32 {
        const out = try gpa.alloc(f32, r.key.len * d);
        for (r.key, 0..) |kk, id| {
            const v = if (id < 5) id else vocab[kk];
            @memcpy(out[id * d ..][0..d], emb[v * d ..][0..d]);
        }
        return out;
    }

    /// The random control: a fixed N(0, 1) vector per vocab entry (shared role vectors
    /// as E has them)
    fn randPrior(r: *const RIds, gpa: Allocator, vocab: []const u32, d: usize, seed: u32) ![]f32 {
        const out = try gpa.alloc(f32, r.key.len * d);
        for (r.key, 0..) |kk, id| {
            // Keys share their role's vector exactly when the vocab gives them one
            const v: u64 = if (id < 5) id else vocab[kk];
            const name: u64 = if (v < 5) v else @as(u64, kk) + 5;
            for (0..d) |j| out[id * d + j] = randNorm(seed, name, j);
        }
        return out;
    }

    fn handPrior(r: *const RIds, gpa: Allocator, prof: []const f32) ![]f32 {
        const out = try gpa.alloc(f32, r.key.len * n_hand);
        for (r.key, 0..) |kk, id| {
            if (id < 5) @memset(out[id * n_hand ..][0..n_hand], 0) else @memcpy(out[id * n_hand ..][0..n_hand], prof[@as(usize, kk) * n_hand ..][0..n_hand]);
        }
        return out;
    }
};

fn job(gpa: Allocator, io: Io, e: *const nnexport.Export, opts: Options, block: Block, seed: u32) !JobOut {
    const t0 = Io.Clock.awake.now(io);
    var fit: std.ArrayList(u32) = .empty;
    defer fit.deinit(gpa);
    var scored: std.ArrayList(u32) = .empty;
    errdefer scored.deinit(gpa);
    for (0..e.len()) |gi| {
        if (!played(e, gi)) continue;
        if (fits(block, e.split[gi]) and inResample(e, gi, opts.resample)) try fit.append(gpa, @intCast(gi));
        if (scores(block, e.split[gi])) try scored.append(gpa, @intCast(gi));
    }
    if (fit.items.len < 20) return error.TooFewGames;
    // Validation: the newest tenth of the fit games
    const starts = try gpa.alloc(i64, fit.items.len);
    defer gpa.free(starts);
    for (starts, fit.items) |*s, gi| s.* = e.start[gi];
    std.mem.sort(i64, starts, {}, std.sort.asc(i64));
    const cut = starts[@trunc(@as(f64, @floatFromInt(starts.len)) * (1 - val_share))];
    var inner: std.ArrayList(u32) = .empty;
    defer inner.deinit(gpa);
    var val: std.ArrayList(u32) = .empty;
    defer val.deinit(gpa);
    for (fit.items) |gi| try (if (e.start[gi] < cut) &inner else &val).append(gpa, gi);

    // 1-2: aux embeddings, early stopping and the L2 grid on val, refit on all
    // Target scaling from the games each pass trains on (tuning: inner only)
    const norm_inner: Norm = .of(e.aux, inner.items);
    const norm: Norm = .of(e.aux, fit.items);
    var use: [k]bool = undefined;
    for (&use, 0..) |*u, j| u.* = opts.drop & (@as(u32, 1) << @intCast(j)) == 0;
    const d: usize = opts.dim;
    var vocab_inner: Vocab = try .init(gpa, e, inner.items, opts.min_games);
    defer vocab_inner.deinit(gpa);
    const base_inner = baseMeans(e, &norm_inner, inner.items);
    const ad_inner: AuxData = .{ .e = e, .norm = &norm_inner, .vocab = vocab_inner.id, .use = use, .win_adjust = opts.win_adjust, .base = &base_inner };
    var tuned: ?AuxTrained = null;
    var tuned_l2: f32 = 0;
    defer if (tuned) |t| gpa.free(t.p);
    for (opts.l2) |l2| {
        const t = try trainAux(gpa, opts, l2, seed, vocab_inner.n, &ad_inner, inner.items, val.items, opts.max_epochs * nn.stepsPerEpoch(inner.items.len, opts.batch));
        if (tuned == null or t.val.loss() < tuned.?.val.loss()) {
            if (tuned) |old| gpa.free(old.p);
            tuned = t;
            tuned_l2 = l2;
        } else gpa.free(t.p);
    }
    const tn = tuned.?;
    var vocab_all: Vocab = try .init(gpa, e, fit.items, opts.min_games);
    errdefer vocab_all.deinit(gpa);
    const base_all = baseMeans(e, &norm, fit.items);
    const ad_all: AuxData = .{ .e = e, .norm = &norm, .vocab = vocab_all.id, .use = use, .win_adjust = opts.win_adjust, .base = &base_all };
    const steps = nn.refitSteps(tn.epochs, 1.1, fit.items.len, opts.batch);
    const full = try trainAux(gpa, opts, tuned_l2, seed, vocab_all.n, &ad_all, fit.items, null, steps);
    defer gpa.free(full.p);

    // 3: ratings with each prior
    const key_games = try keyCounts(gpa, e, fit.items);
    errdefer gpa.free(key_games);
    const rids: RIds = try .init(gpa, key_games);
    defer rids.deinit(gpa);
    const g_inner = try rids.games(gpa, e, inner.items);
    defer gpa.free(g_inner);
    const g_val = try rids.games(gpa, e, val.items);
    defer gpa.free(g_val);
    const g_all = try rids.games(gpa, e, fit.items);
    defer gpa.free(g_all);
    const g_scored = try rids.games(gpa, e, scored.items);
    defer gpa.free(g_scored);
    const hand_inner = try handProfiles(gpa, e, inner.items);
    defer gpa.free(hand_inner);
    const hand_all = try handProfiles(gpa, e, fit.items);
    defer gpa.free(hand_all);

    var out: JobOut = .{
        .block = block,
        .seed = seed,
        .fit_games = fit.items.len,
        .aux_val = tn.val,
        .aux_l2 = tuned_l2,
        .aux_epochs = tn.epochs,
        .emb = try gpa.dupe(f32, full.p[0 .. vocab_all.n * d]),
        .vocab = vocab_all,
        .key_games = key_games,
        .scored = undefined,
        .rare = undefined,
        .pred = undefined,
        .fit = undefined,
        .seconds = 0,
    };
    for (std.enums.values(Variant), 0..) |v, vi| {
        const pi: []f32, const pa: []f32, const dp: usize = switch (v) {
            .none => .{ &.{}, &.{}, 0 },
            .emb => .{ try rids.embPrior(gpa, tn.p, vocab_inner.id, d), try rids.embPrior(gpa, full.p, vocab_all.id, d), d },
            .hand => .{ try rids.handPrior(gpa, hand_inner), try rids.handPrior(gpa, hand_all), n_hand },
            .rand => .{ try rids.randPrior(gpa, vocab_inner.id, d, seed), try rids.randPrior(gpa, vocab_all.id, d, seed), d },
        };
        defer gpa.free(pi);
        defer gpa.free(pa);
        const mi: RModel = .{ .n = rids.key.len, .dp = dp, .role = rids.role, .prior = pi };
        const ma: RModel = .{ .n = rids.key.len, .dp = dp, .role = rids.role, .prior = pa };
        out.fit[vi] = try fitRatings(gpa, mi, ma, g_inner, g_val, g_all, g_scored, seed);
        out.pred[vi] = out.fit[vi].pred;
    }
    out.rare = try gpa.alloc(bool, scored.items.len);
    for (out.rare, scored.items) |*r, gi| {
        r.* = false;
        for (0..10) |slot| r.* = r.* or key_games[keyOf(e, gi, slot)] < opts.rare;
    }
    out.scored = try scored.toOwnedSlice(gpa);
    out.seconds = secondsSince(io, t0);
    return out;
}

const secondsSince = winnet.secondsSince;

/// emb-<block>-s<seed>.tsv: champion id, role (0 top .. 4 utility), fit games, then E;
/// champion 0 rows are each role's shared vector for champion-roles under min_games
fn writeEmb(gpa: Allocator, io: Io, dir: Io.Dir, e: *const nnexport.Export, o: JobOut) !void {
    const name = try gpa.print("emb-{s}-s{d}.tsv", .{ blockName(o.block), o.seed });
    defer gpa.free(name);
    var f = try dir.createFile(io, name, .{});
    defer f.close(io);
    var buf: [64 * 1024]u8 = undefined;
    var fw = f.writer(io, &buf);
    const w = &fw.interface;
    const d = o.emb.len / o.vocab.n;
    try w.writeAll("champion\trole\tfit_games");
    for (0..d) |j| try w.print("\te{d}", .{j});
    try w.writeAll("\n");
    for (0..5) |r| {
        var n: u64 = 0;
        for (o.key_games, 0..) |c, key| {
            if (key % 5 == r and o.vocab.id[key] < 5) n += c;
        }
        try w.print("0\t{d}\t{d}", .{ r, n });
        for (o.emb[r * d ..][0..d]) |x| try w.print("\t{d:.6}", .{x});
        try w.writeAll("\n");
    }
    for (o.vocab.id, 0..) |id, key| {
        if (id < 5) continue;
        try w.print("{d}\t{d}\t{d}", .{ e.champions[key / 5], key % 5, o.key_games[key] });
        for (o.emb[id * d ..][0..d]) |x| try w.print("\t{d:.6}", .{x});
        try w.writeAll("\n");
    }
    try w.flush();
}

const Diff = struct { mean: f64, se: f64, n: usize };

/// The variant's log loss minus base's per game (negative: the variant is better), over
/// the games keep marks (all when null); se clustered by game
fn pairedDiff(ys: []const f32, base: []const f32, cand: []const f32, keep: ?[]const bool) Diff {
    var s: f64 = 0;
    var s2: f64 = 0;
    var n: usize = 0;
    for (ys, base, cand, 0..) |y, a, b, i| {
        if (keep) |kp| if (!kp[i]) continue;
        const x = loss1(y, b) - loss1(y, a);
        s += x;
        s2 += x * x;
        n += 1;
    }
    const nf: f64 = @floatFromInt(@max(n, 1));
    const mean = s / nf;
    return .{ .mean = mean, .se = @sqrt(@max(s2 / nf - mean * mean, 0) / @max(nf - 1, 1)), .n = n };
}

fn meanLoss(ys: []const f32, p: []const f32) f64 {
    return nn.meanLogLoss(f32, ys, p);
}

/// Scored games of one or more jobs (one seed), concatenated
const Pool = struct {
    ys: std.ArrayList(f32) = .empty,
    pred: [n_var]std.ArrayList(f32) = @splat(.empty),
    rare: std.ArrayList(bool) = .empty,

    fn add(p: *Pool, gpa: Allocator, e: *const nnexport.Export, o: *const JobOut) !void {
        for (o.scored) |gi| try p.ys.append(gpa, @floatFromInt(e.blue_win[gi]));
        for (&p.pred, o.pred) |*pp, x| try pp.appendSlice(gpa, x);
        try p.rare.appendSlice(gpa, o.rare);
    }

    fn deinit(p: *Pool, gpa: Allocator) void {
        p.ys.deinit(gpa);
        for (&p.pred) |*pp| pp.deinit(gpa);
        p.rare.deinit(gpa);
    }
};

fn writeTables(gpa: Allocator, io: Io, dir: Io.Dir, e: *const nnexport.Export, data: *const rows.Data, outs: []const JobOut) !void {
    const names = auxNames();
    {
        var f = try dir.createFile(io, "aux.tsv", .{});
        defer f.close(io);
        var buf: [16 * 1024]u8 = undefined;
        var fw = f.writer(io, &buf);
        const w = &fw.interface;
        try w.writeAll("block\tseed\ttarget\tval_seats\tmse\tbase_mse\tr2\tl2\tepochs\n");
        for (outs) |o| {
            const s = o.aux_val;
            for (names, 0..) |n, j| {
                if (s.n[j] == 0) continue;
                try w.print("{s}\t{d}\t{s}\t{d}\t{d:.5}\t{d:.5}\t{d:.4}\t{d}\t{d:.2}\n", .{ blockName(o.block), o.seed, n, s.n[j], s.model[j] / s.n[j], s.base[j] / s.n[j], 1 - s.model[j] / @max(s.base[j], 1e-12), o.aux_l2, o.aux_epochs });
            }
            try w.print("{s}\t{d}\tall\t0\t{d:.5}\t{d:.5}\t{d:.4}\t{d}\t{d:.2}\n", .{ blockName(o.block), o.seed, s.loss(), s.baseLoss(), 1 - s.loss() / @max(s.baseLoss(), 1e-12), o.aux_l2, o.aux_epochs });
        }
        try w.flush();
    }
    {
        var f = try dir.createFile(io, "ratings.tsv", .{});
        defer f.close(io);
        var buf: [16 * 1024]u8 = undefined;
        var fw = f.writer(io, &buf);
        const w = &fw.interface;
        try w.writeAll("block\tseed\tvariant\tfit_games\tscored_games\tlogloss\tnone_logloss\tdiff\tdiff_se\trare_games\trare_diff\trare_se\tl2\tepochs\tval_logloss\tseconds\n");
        for (outs) |*o| {
            var p: Pool = .{};
            defer p.deinit(gpa);
            try p.add(gpa, e, o);
            const ys = p.ys.items;
            for (std.enums.values(Variant), 0..) |v, vi| {
                const g = pairedDiff(ys, o.pred[0], o.pred[vi], null);
                const gr = pairedDiff(ys, o.pred[0], o.pred[vi], o.rare);
                const ft = o.fit[vi];
                try w.print("{s}\t{d}\t{t}\t{d}\t{d}\t{d:.6}\t{d:.6}\t{d:.6}\t{d:.6}\t{d}\t{d:.6}\t{d:.6}\t{d}\t{d}\t{d:.6}\t{d:.1}\n", .{
                    blockName(o.block), o.seed, v, o.fit_games, ys.len, meanLoss(ys, o.pred[vi]), meanLoss(ys, o.pred[0]), g.mean, g.se, gr.n, gr.mean, gr.se, ft.l2, ft.epochs, ft.val_loss, o.seconds,
                });
            }
        }
        try w.flush();
    }
    {
        var f = try dir.createFile(io, "preds.tsv", .{});
        defer f.close(io);
        var buf: [64 * 1024]u8 = undefined;
        var fw = f.writer(io, &buf);
        const w = &fw.interface;
        try w.writeAll("block\tseed\tmatch_id\ty\trare");
        for (std.enums.values(Variant)) |v| try w.print("\t{t}", .{v});
        try w.writeAll("\n");
        for (outs) |o| for (o.scored, 0..) |gi, i| {
            try w.print("{s}\t{d}\t{s}\t{d}\t{d}", .{ blockName(o.block), o.seed, data.games[gi].match_id, e.blue_win[gi], @intFromBool(o.rare[i]) });
            for (o.pred) |p| try w.print("\t{d:.6}", .{p[i]});
            try w.writeAll("\n");
        };
        try w.flush();
    }
    // games-<variant>.tsv: netcheck's per-game shape (gains, the verifier), the seeds'
    // mean chance; a block's seeds are consecutive jobs on the same scored games
    for (std.enums.values(Variant), 0..) |v, vi| {
        const name = try gpa.print("games-{s}.tsv", .{if (v == .none) "ratings" else @tagName(v)});
        defer gpa.free(name);
        var f = try dir.createFile(io, name, .{});
        defer f.close(io);
        var buf: [64 * 1024]u8 = undefined;
        var fw = f.writer(io, &buf);
        const w = &fw.interface;
        try w.writeAll("match_id\tslot\toutcome\ty\tpred\tblock\n");
        var at: usize = 0;
        while (at < outs.len) {
            var end = at + 1;
            while (end < outs.len and outs[end].block == outs[at].block) end += 1;
            for (outs[at].scored, 0..) |gi, i| {
                var s: f64 = 0;
                for (outs[at..end]) |o| s += o.pred[vi][i];
                try w.print("{s}\t0\twin\t{d}\t{d:.6}\t{s}\n", .{ data.games[gi].match_id, e.blue_win[gi], s / @as(f64, @floatFromInt(end - at)), blockName(outs[at].block) });
            }
            at = end;
        }
        try w.flush();
    }
}

/// Markdown: aux R^2 per target (over jobs), then per block and for the folds pooled each
/// variant's log loss change vs none: the seeds' mean, their range, the mean 1.96 SE
fn summary(gpa: Allocator, w: *Io.Writer, e: *const nnexport.Export, opts: Options, outs: []const JobOut) !void {
    const names = auxNames();
    try w.writeAll("Aux fit on the inner games, scored on val: R^2 against role x won means, over blocks and seeds\n\n| target | R^2 mean | min | max |\n| --- | --- | --- | --- |\n");
    for (names, 0..) |n, j| {
        var s: f64 = 0;
        var lo: f64 = std.math.inf(f64);
        var hi: f64 = -std.math.inf(f64);
        var c: f64 = 0;
        for (outs) |o| {
            if (o.aux_val.n[j] == 0) continue;
            const r2 = 1 - o.aux_val.model[j] / @max(o.aux_val.base[j], 1e-12);
            s += r2;
            lo = @min(lo, r2);
            hi = @max(hi, r2);
            c += 1;
        }
        if (c > 0) try w.print("| {s} | {d:.3} | {d:.3} | {d:.3} |\n", .{ n, s / c, lo, hi });
    }

    const ns = opts.seeds.len;
    try w.writeAll("\nRatings with each prior, log loss vs none (negative: better), seeds' mean, range and mean 1.96 SE (clustered by game)\n\n" ++
        "| block | variant | games | log loss | vs none | seed range | rare games | rare vs none |\n| --- | --- | --- | --- | --- | --- | --- | --- |\n");
    const pools = try gpa.alloc(Pool, ns);
    defer gpa.free(pools);
    var any_fold = false;
    for (opts.blocks, 0..) |b, bi| {
        if (b != .dev) any_fold = true;
        for (pools, 0..) |*p, si| {
            p.* = .{};
            try p.add(gpa, e, &outs[bi * ns + si]);
        }
        defer for (pools) |*p| p.deinit(gpa);
        try summaryRows(w, blockName(b), pools);
    }
    if (any_fold) {
        for (pools, 0..) |*p, si| {
            p.* = .{};
            for (opts.blocks, 0..) |b, bi| if (b != .dev) try p.add(gpa, e, &outs[bi * ns + si]);
        }
        defer for (pools) |*p| p.deinit(gpa);
        try summaryRows(w, "folds", pools);
    }
    try w.writeAll("\n");
}

fn summaryRows(w: *Io.Writer, label: []const u8, pools: []const Pool) !void {
    const ns: f64 = @floatFromInt(pools.len);
    for (std.enums.values(Variant), 0..) |v, vi| {
        var loss: f64 = 0;
        var mean: f64 = 0;
        var se: f64 = 0;
        var lo: f64 = std.math.inf(f64);
        var hi: f64 = -std.math.inf(f64);
        var rare_mean: f64 = 0;
        var rare_se: f64 = 0;
        var rare_n: usize = 0;
        for (pools) |p| {
            const ys = p.ys.items;
            loss += meanLoss(ys, p.pred[vi].items);
            const g = pairedDiff(ys, p.pred[0].items, p.pred[vi].items, null);
            mean += g.mean;
            se += g.se;
            lo = @min(lo, g.mean);
            hi = @max(hi, g.mean);
            const r = pairedDiff(ys, p.pred[0].items, p.pred[vi].items, p.rare.items);
            rare_mean += r.mean;
            rare_se += r.se;
            rare_n = r.n;
        }
        try w.print("| {s} | {t} | {d} | {d:.5} |", .{ label, v, pools[0].ys.items.len, loss / ns });
        if (v == .none) {
            try w.print(" - | - | {d} | - |\n", .{rare_n});
            continue;
        }
        try w.print(" {d:.5} ± {d:.5} | {d:.5} .. {d:.5} | {d} | {d:.5} ± {d:.5} |\n", .{ mean / ns, 1.96 * se / ns, lo, hi, rare_n, rare_mean / ns, 1.96 * rare_se / ns });
    }
}

const testing = std.testing;

/// Fixture games with stats: champion c's magic share c / 30, damage per minute and
/// building damage per minute rising with c, the rest unknown
fn fixtureExport(gpa: Allocator, n: usize) !struct { f: harness.Fixture, e: nnexport.Export } {
    var f = try harness.Fixture.init(gpa, n, 11);
    errdefer f.data.deinit();
    var rng: std.Random.DefaultPrng = .init(4);
    const rnd = rng.random();
    for (f.data.rows) |*r| {
        const c: f32 = @floatFromInt(r.champion);
        const S = seatstats.SeatStat;
        r.stats[@backingInt(S.minutes)] = 30;
        const total = 30 * (400 + 20 * c) * (1 + 0.2 * rnd.floatNorm(f32));
        r.stats[@backingInt(S.dmg_magic)] = total * c / 30;
        r.stats[@backingInt(S.dmg_phys)] = total * (1 - c / 30);
        r.stats[@backingInt(S.dmg_true)] = 0;
        r.stats[@backingInt(S.dmg_buildings)] = 30 * (100 + 10 * c + 50 * rnd.floatNorm(f32));
    }
    const c = try harness.cuts(gpa, &f.data);
    const e = try nnexport.build(gpa, &f.data, c);
    perMinute(e.aux);
    return .{ .f = f, .e = e };
}

test "aux model: gradient matches finite differences" {
    const gpa = testing.allocator;
    var fx = try fixtureExport(gpa, 1000);
    defer fx.f.data.deinit();
    defer fx.e.deinit();
    const games = [_]u32{ 3, 4 };
    const norm: Norm = .of(fx.e.aux, &games);
    const base = baseMeans(&fx.e, &norm, &games);
    var vocab: Vocab = try .init(gpa, &fx.e, &games, 1);
    defer vocab.deinit(gpa);
    const ad: AuxData = .{ .e = &fx.e, .norm = &norm, .vocab = vocab.id, .use = @splat(true), .win_adjust = true, .base = &base };
    var m: AuxShape = try .init(gpa, vocab.n, 3, 0);
    defer m.ps.deinit(gpa);
    const p = try m.ps.alloc(gpa);
    defer gpa.free(p);
    var rng: std.Random.DefaultPrng = .init(2);
    for (p) |*x| x.* = rng.random().floatNorm(f32) * 0.3;
    const gr = try m.ps.alloc(gpa);
    defer gpa.free(gr);
    for (games) |gi| auxGame(&m, p, &ad, gi, gr, 1, null);
    const Loss = struct {
        m: *const AuxShape,
        p: []const f32,
        ad: *const AuxData,
        games: []const u32,
        // Half the squared errors: auxGame's loss
        fn loss(c: *const @This()) f64 {
            var a: f64 = 0;
            for (sseOf(c.m, c.p, c.ad, c.games).model) |x| a += x;
            return a / 2;
        }
    };
    // Quadratic in each parameter, so a wide step is exact but for rounding
    try nn.expectGradient(&Loss{ .m = &m, .p = p, .ad = &ad, .games = &games }, Loss.loss, p, gr, null, .{ .h = 0.1 });
}

test "ratings with a prior: gradient matches finite differences; no prior is plain ratings" {
    const gpa = testing.allocator;
    const n = 9;
    const dp = 2;
    const role = [_]u8{ 0, 1, 2, 3, 4, 0, 1, 2, 3 };
    var prior: [n * dp]f32 = undefined;
    for (&prior, 0..) |*x, i| x.* = @as(f32, @floatFromInt(i % 5)) * 0.3 - 0.5;
    const m: RModel = .{ .n = n, .dp = dp, .role = &role, .prior = &prior };
    const set = [_]RGame{
        .{ .ids = .{ 5, 6, 7, 8, 4, 0, 1, 2, 3, 4 }, .platform = 1, .y = 1 },
        .{ .ids = .{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 4 }, .platform = 2, .y = 1 },
    };
    const p = try gpa.alloc(f32, m.len());
    defer gpa.free(p);
    var rng: std.Random.DefaultPrng = .init(3);
    for (p) |*x| x.* = rng.random().floatNorm(f32) * 0.3;
    const b = try gpa.alloc(f32, n);
    defer gpa.free(b);
    m.ratings(p, b);
    var gr: [n_platforms + 5 * dp + n]f32 = undefined;
    var gb: [n]f32 = undefined;
    rGrad(m, p, b, &gb, &gr, &set, &.{ 0, 1 });
    for (&gr) |*g| g.* /= set.len;
    const Loss = struct {
        m: RModel,
        p: []const f32,
        b: []f32,
        set: []const RGame,
        fn loss(c: *const @This()) f64 {
            return rLoss(c.m, c.p, c.b, c.set);
        }
    };
    try nn.expectGradient(&Loss{ .m = m, .p = p, .b = b, .set = &set }, Loss.loss, p, &gr, null, .{});
}

test "pretrain on the fixture: E carries the planted stats, every variant scores" {
    const gpa = testing.allocator;
    var fx = try fixtureExport(gpa, 3000);
    defer fx.f.data.deinit();
    defer fx.e.deinit();
    const opts: Options = .{ .dim = 4, .min_games = 5, .batch = 32, .max_epochs = 20, .seeds = &.{ 1, 2 }, .blocks = &.{ .dev, .f5 } };
    const outs = try runAll(gpa, testing.io, &fx.e, opts);
    defer {
        for (outs) |*o| o.deinit(gpa);
        gpa.free(outs);
    }
    const magic = n_early + @as(usize, @backingInt(seatstats.SeatStat.dmg_magic));
    for (outs) |o| {
        try testing.expect(o.scored.len > 0);
        // Champion explains most of the magic damage per minute
        try testing.expect(1 - o.aux_val.model[magic] / o.aux_val.base[magic] > 0.5);
        for (o.pred) |p| for (p) |x| try testing.expect(x > 0 and x < 1);
    }
    var out: Io.Writer.Allocating = .init(gpa);
    defer out.deinit();
    try summary(gpa, &out.writer, &fx.e, opts, outs);
    try testing.expect(std.mem.find(u8, out.written(), "| folds | emb |") != null);
}

test "pretrain --blocks: a fold past 5 is an error" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    try testing.expectError(error.BadBlock, parseOptions(arena.allocator(), &.{ "--blocks", "6" }));
    const o = try parseOptions(arena.allocator(), &.{ "--blocks", "1,dev" });
    try testing.expectEqualSlices(Block, &.{ .f1, .dev }, o.blocks);
}

test "pretrain resample: fits on netcheck's 90% only" {
    const gpa = testing.allocator;
    var fx = try fixtureExport(gpa, 3000);
    defer fx.f.data.deinit();
    defer fx.e.deinit();
    const opts: Options = .{ .dim = 2, .min_games = 5, .batch = 64, .max_epochs = 2, .seeds = &.{1}, .blocks = &.{.f5}, .resample = 2 };
    const outs = try runAll(gpa, testing.io, &fx.e, opts);
    defer {
        for (outs) |*o| o.deinit(gpa);
        gpa.free(outs);
    }
    var all: usize = 0;
    var kept: usize = 0;
    for (0..fx.e.len()) |gi| if (played(&fx.e, gi) and fits(.f5, fx.e.split[gi])) {
        all += 1;
        if (harness.inResample(fx.e.start[gi], fx.e.platform[gi], 2)) kept += 1;
    };
    try testing.expectEqual(kept, outs[0].fit_games);
    try testing.expect(kept < all and kept * 10 > all * 8);
}
