//! `meiolol-lab curve [OPT]... MODEL:COL:LABEL:DIR...`: learning curves from netcheck runs
//! (docs/model.md "Neural draft models"). Each source is a netcheck output DIR (folds.tsv,
//! preds.tsv) and one of its prediction columns (cand, ens, seed1...) named MODEL; LABEL
//! names the run's fit share ("25%", "350k 50%") for the pooled table. A point is one
//! model on one block at one fit size: its mean log loss over the block's scored games.
//! Blocks are told apart by their scored games, so the same fold of two snapshots is two
//! blocks, and runs at different fractions of one snapshot share theirs.
//! Per model: log loss = a * N^-b + c[block], N the block's fit games, least squares
//! weighted by scored games, a >= 0 (b by grid search). The per-block c takes out how hard
//! each block's games are; a and b come from N varying within blocks. Comparisons use the
//! mean c over the blocks every model has. Intervals: Poisson bootstrap over scored games,
//! one weight per game shared by every point (paired), the whole fit redone per replicate.
//! Main answer: the paired gap to the reference model, alpha[block] + beta * log2(N): beta
//! says whether a net gains on it per doubling of fit games, and where it would cross.
//! Not in the intervals: which fit games a fraction kept, and seed noise (use the seeds'
//! mean `ens`; netcheck's seed spread says how big that is)

const std = @import("std");
const Io = std.Io;
const tsvlog = @import("../tsvlog.zig");

pub const usage =
    \\  curve [--ref MODEL] [--min-fit N] [--max-fit N] [--reps N] [--at N,N...] [--tsv FILE] MODEL:COL:LABEL:DIR...
    \\                                  learning curves a*N^-b + c[block] from netcheck
    \\                                  runs (COL: cand, ens, seedN), game bootstrap,
    \\                                  projections and crossings vs --ref (ratings)
    \\                                  (lab/curve.zig)
    \\
;

const Point = struct {
    model: u32,
    block: u32,
    label: []const u8,
    n_fit: f64,
    games: []u32,
    loss: []f64,
    /// Per game: 1 when the side given over 50% won, 0.5 at exactly 50%
    hit: []f64,
    mean: f64 = 0,
};

const Fit = struct {
    a: f64,
    b: f64,
    /// Mean c over the shared blocks
    c: f64,
    ok: bool,
};

const n_grid = 240;
const b_lo = 0.02;
const b_hi = 3.0;

pub fn main(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: Io, argv: []const []const u8) !u8 {
    var ref: []const u8 = "ratings";
    var min_fit: f64 = 0;
    var max_fit: f64 = std.math.inf(f64);
    var reps: u32 = 1000;
    var sizes: std.ArrayList(f64) = .empty;
    var tsv: ?[]const u8 = null;
    var sources: std.ArrayList([]const u8) = .empty;
    var i: usize = 0;
    while (i < argv.len) : (i += 1) {
        const a = argv[i];
        if (std.mem.startsWith(u8, a, "--")) {
            i += 1;
            if (i >= argv.len) return usageError();
            const v = argv[i];
            if (std.mem.eql(u8, a, "--ref")) ref = v //
            else if (std.mem.eql(u8, a, "--min-fit")) min_fit = try std.fmt.parseFloat(f64, v) //
            else if (std.mem.eql(u8, a, "--max-fit")) max_fit = try std.fmt.parseFloat(f64, v) //
            else if (std.mem.eql(u8, a, "--reps")) reps = try std.fmt.parseInt(u32, v, 10) //
            else if (std.mem.eql(u8, a, "--tsv")) tsv = v //
            else if (std.mem.eql(u8, a, "--at")) {
                var it = std.mem.splitScalar(u8, v, ',');
                while (it.next()) |n| try sizes.append(arena, try std.fmt.parseFloat(f64, n));
            } else return usageError();
        } else try sources.append(arena, a);
    }
    if (sources.items.len == 0) return usageError();
    if (sizes.items.len == 0) try sizes.appendSlice(arena, &.{ 1e5, 3e5, 1e6, 3e6, 1e7 });

    var c = Corpus{};
    for (sources.items) |s| try c.read(gpa, arena, io, s);
    const ref_id = for (c.models.items, 0..) |m, k| {
        if (std.mem.eql(u8, m, ref)) break @as(u32, @intCast(k));
    } else return error.RefModelMissing;

    const shared = try c.sharedBlocks(arena);
    if (shared.len == 0) return error.NoSharedBlocks;
    const nm = c.models.items.len;

    // Replicate 0 is the point estimate (every weight 1)
    const fits = try arena.alloc(Fit, (reps + 1) * nm);
    const gaps = try arena.alloc(Gap, (reps + 1) * nm);
    const pooled = try arena.alloc(f64, (reps + 1) * c.points.items.len);
    const weights = try gpa.alloc(f64, c.n_games);
    defer gpa.free(weights);
    var prng = std.Random.DefaultPrng.init(0x5ca1);
    const rand = prng.random();
    for (0..reps + 1) |r| {
        if (r == 0) {
            @memset(weights, 1);
        } else for (weights) |*w| {
            w.* = poisson1(rand);
        }
        for (c.points.items, 0..) |*p, k| {
            var s: f64 = 0;
            var sw: f64 = 0;
            for (p.games, p.loss) |g, l| {
                s += weights[g] * l;
                sw += weights[g];
            }
            p.mean = s / @max(sw, 1e-12);
            pooled[r * c.points.items.len + k] = s;
        }
        for (0..nm) |m| fits[r * nm + m] = try fitModel(arena, c.points.items, @intCast(m), shared);
        for (0..nm) |m| gaps[r * nm + m] = try gapFit(arena, c.points.items, @intCast(m), ref_id, shared, min_fit, max_fit);
    }

    var buf: [4096]u8 = undefined;
    var stdout = Io.File.stdout().writer(io, &buf);
    const w = &stdout.interface;
    try report(arena, &c, shared, fits, gaps, reps, ref_id, sizes.items, min_fit, max_fit, w);
    try w.flush();
    if (tsv) |path| {
        var f = try Io.Dir.cwd().createFile(io, path, .{});
        defer f.close(io);
        var tb: [4096]u8 = undefined;
        var tw = f.writer(io, &tb);
        try tsvRows(arena, &c, fits, gaps, reps, ref_id, sizes.items, &tw.interface);
        try tw.interface.flush();
    }
    return 0;
}

fn usageError() u8 {
    std.debug.print("usage:\n{s}", .{usage});
    return 2;
}

/// Knuth's method for Poisson(1)
fn poisson1(rand: std.Random) f64 {
    const l = @exp(-1.0);
    var k: f64 = 0;
    var p: f64 = rand.float(f64);
    while (p > l) : (k += 1) p *= rand.float(f64);
    return k;
}

const Corpus = struct {
    models: std.ArrayList([]const u8) = .empty,
    /// Per block: hash of its sorted scored match ids, its fold name, scored games
    block_keys: std.ArrayList(u64) = .empty,
    block_names: std.ArrayList([]const u8) = .empty,
    block_games: std.ArrayList(usize) = .empty,
    points: std.ArrayList(Point) = .empty,
    ids: std.StringHashMapUnmanaged(u32) = .empty,
    n_games: usize = 0,

    fn modelId(c: *Corpus, arena: std.mem.Allocator, name: []const u8) !u32 {
        for (c.models.items, 0..) |m, k| if (std.mem.eql(u8, m, name)) return @intCast(k);
        try c.models.append(arena, name);
        return @intCast(c.models.items.len - 1);
    }

    fn blockId(c: *Corpus, arena: std.mem.Allocator, key: u64, name: []const u8, n: usize) !u32 {
        for (c.block_keys.items, 0..) |k, b| if (k == key) return @intCast(b);
        try c.block_keys.append(arena, key);
        try c.block_names.append(arena, name);
        try c.block_games.append(arena, n);
        return @intCast(c.block_keys.items.len - 1);
    }

    fn read(c: *Corpus, gpa: std.mem.Allocator, arena: std.mem.Allocator, io: Io, spec: []const u8) !void {
        var parts = std.mem.splitScalar(u8, spec, ':');
        const model = parts.next() orelse return error.BadSource;
        const col = parts.next() orelse return error.BadSource;
        const label = parts.next() orelse return error.BadSource;
        const dir = parts.rest();
        if (dir.len == 0) return error.BadSource;
        const m = try c.modelId(arena, model);

        var fit_games: std.StringHashMapUnmanaged(f64) = .empty;
        defer fit_games.deinit(gpa);
        const folds = try Io.Dir.cwd().readFileAlloc(io, try arena.print("{s}/folds.tsv", .{dir}), arena, .unlimited);
        var fl = std.mem.tokenizeScalar(u8, folds, '\n');
        _ = fl.next();
        while (fl.next()) |line| {
            var it = std.mem.splitScalar(u8, line, '\t');
            _ = it.next();
            const fold = it.next() orelse continue;
            const n = try std.fmt.parseFloat(f64, it.next() orelse continue);
            try fit_games.put(gpa, fold, n);
        }

        const preds = try Io.Dir.cwd().readFileAlloc(io, try arena.print("{s}/preds.tsv", .{dir}), arena, .unlimited);
        var pl = std.mem.tokenizeScalar(u8, preds, '\n');
        const header = pl.next() orelse return error.Empty;
        const at_col = tsvlog.column(header, col) orelse return error.MissingColumn;
        const Rows = struct { games: std.ArrayList(u32) = .empty, loss: std.ArrayList(f64) = .empty, hit: std.ArrayList(f64) = .empty, key: u64 = 0 };
        var by_fold: std.StringArrayHashMapUnmanaged(Rows) = .empty;
        defer by_fold.deinit(gpa);
        var cols: [16][]const u8 = undefined;
        while (pl.next()) |line| {
            var it = std.mem.splitScalar(u8, line, '\t');
            var n: usize = 0;
            while (it.next()) |x| : (n += 1) if (n < cols.len) {
                cols[n] = x;
            };
            if (n <= at_col) return error.ShortRow;
            const y = try std.fmt.parseFloat(f64, cols[3]);
            const p = std.math.clamp(try std.fmt.parseFloat(f64, cols[at_col]), 1e-6, 1 - 1e-6);
            const e = try c.ids.getOrPut(gpa, cols[1]);
            if (!e.found_existing) {
                e.key_ptr.* = try arena.dupe(u8, cols[1]);
                e.value_ptr.* = @intCast(c.n_games);
                c.n_games += 1;
            }
            const r = try by_fold.getOrPut(gpa, cols[0]);
            if (!r.found_existing) r.value_ptr.* = .{};
            try r.value_ptr.games.append(arena, e.value_ptr.*);
            try r.value_ptr.loss.append(arena, -(y * @log(p) + (1 - y) * @log(1 - p)));
            try r.value_ptr.hit.append(arena, if (p == 0.5) 0.5 else if ((p > 0.5) == (y > 0.5)) 1 else 0);
            // Order-free set hash of the block's games
            r.value_ptr.key +%= std.hash.Wyhash.hash(0xb10c, cols[1]);
        }
        for (by_fold.keys(), by_fold.values()) |fold, rows| {
            const n_fit = fit_games.get(fold) orelse return error.FoldWithoutFitGames;
            const b = try c.blockId(arena, rows.key, fold, rows.games.items.len);
            const dup = for (c.points.items) |q| {
                if (q.model == m and q.block == b and q.n_fit == n_fit) break true;
            } else false;
            if (dup) continue;
            try c.points.append(arena, .{ .model = m, .block = b, .label = label, .n_fit = n_fit, .games = rows.games.items, .loss = rows.loss.items, .hit = rows.hit.items });
        }
    }

    /// Blocks every model has a point on
    fn sharedBlocks(c: *const Corpus, arena: std.mem.Allocator) ![]u32 {
        var out: std.ArrayList(u32) = .empty;
        for (0..c.block_keys.items.len) |b| {
            const all = for (0..c.models.items.len) |m| {
                const has = for (c.points.items) |p| {
                    if (p.model == m and p.block == b) break true;
                } else false;
                if (!has) break false;
            } else true;
            if (all) try out.append(arena, @intCast(b));
        }
        return out.items;
    }
};

/// Least squares of p.mean on c[block] + a * n_fit^-b over model m's points, weighted by
/// scored games; a >= 0, b on a log grid. ok false when no block has two fit sizes
fn fitModel(arena: std.mem.Allocator, points: []const Point, m: u32, shared: []const u32) !Fit {
    var nb: usize = 0;
    for (points) |p| if (p.model == m) {
        nb = @max(nb, p.block + 1);
    };
    const sw = try arena.alloc(f64, nb);
    const sx = try arena.alloc(f64, nb);
    const sy = try arena.alloc(f64, nb);
    const n_sizes = try arena.alloc(f64, nb);
    @memset(n_sizes, 0);
    for (points) |p| if (p.model == m) {
        n_sizes[p.block] += 1;
    };
    const ok = std.mem.max(f64, n_sizes) >= 2;
    var best: struct { sse: f64 = std.math.inf(f64), a: f64 = 0, b: f64 = std.math.nan(f64) } = .{};
    for (0..n_grid) |gi| {
        const t = @as(f64, @floatFromInt(gi)) / (n_grid - 1);
        const b = b_lo * std.math.pow(f64, b_hi / b_lo, t);
        @memset(sw, 0);
        @memset(sx, 0);
        @memset(sy, 0);
        for (points) |p| if (p.model == m) {
            const wt: f64 = @floatFromInt(p.games.len);
            sw[p.block] += wt;
            sx[p.block] += wt * std.math.pow(f64, p.n_fit, -b);
            sy[p.block] += wt * p.mean;
        };
        var num: f64 = 0;
        var den: f64 = 0;
        for (points) |p| if (p.model == m) {
            const wt: f64 = @floatFromInt(p.games.len);
            const dx = std.math.pow(f64, p.n_fit, -b) - sx[p.block] / sw[p.block];
            num += wt * dx * (p.mean - sy[p.block] / sw[p.block]);
            den += wt * dx * dx;
        };
        const a = if (den > 0) @max(num / den, 0) else 0;
        var sse: f64 = 0;
        for (points) |p| if (p.model == m) {
            const wt: f64 = @floatFromInt(p.games.len);
            const x = std.math.pow(f64, p.n_fit, -b);
            const cb = (sy[p.block] - a * sx[p.block]) / sw[p.block];
            const e = p.mean - cb - a * x;
            sse += wt * e * e;
        };
        if (sse < best.sse - 1e-18) best = .{ .sse = sse, .a = a, .b = b };
    }
    if (best.a == 0) best.b = std.math.nan(f64);
    const b = if (std.math.isNan(best.b)) 1 else best.b;
    // c per shared block from the chosen a, b
    @memset(sw, 0);
    @memset(sx, 0);
    @memset(sy, 0);
    for (points) |p| if (p.model == m) {
        const wt: f64 = @floatFromInt(p.games.len);
        sw[p.block] += wt;
        sx[p.block] += wt * std.math.pow(f64, p.n_fit, -b);
        sy[p.block] += wt * p.mean;
    };
    var cs: f64 = 0;
    var cw: f64 = 0;
    for (shared) |k| {
        // Weighted by the block's points' games so blocks count by size
        cs += sy[k] - best.a * sx[k];
        cw += sw[k];
    }
    return .{ .a = best.a, .b = best.b, .c = cs / cw, .ok = ok };
}

fn curveAt(f: Fit, n: f64) f64 {
    if (f.a == 0) return f.c;
    return f.c + f.a * std.math.pow(f64, n, -f.b);
}

fn quantile(arena: std.mem.Allocator, xs: []const f64, q: f64) !f64 {
    const s = try arena.dupe(f64, xs);
    std.mem.sort(f64, s, {}, std.sort.asc(f64));
    const k: usize = @round(q * @as(f64, @floatFromInt(s.len - 1)));
    return s[k];
}

const Interval = struct { est: f64, lo: f64, hi: f64 };

fn interval(arena: std.mem.Allocator, est: f64, reps: []const f64) !Interval {
    if (reps.len == 0) return .{ .est = est, .lo = est, .hi = est };
    return .{ .est = est, .lo = try quantile(arena, reps, 0.025), .hi = try quantile(arena, reps, 0.975) };
}

/// Model minus ref on the same block and fit size: gap = alpha[block] + beta * log2(N).
/// beta is the change in the gap per doubling of fit games; alpha the mean over shared
/// blocks. Separate power laws for each model barely pin b and c down at our sizes (b
/// runs to the grid's floor), while the paired gap's slope is what decides a crossing
/// se_points: beta's standard error from the points' scatter about the fit, which
/// holds what the game bootstrap leaves out (seed noise, which fit games a share kept)
const Gap = struct { alpha: f64, beta: f64, n_max: f64, se_points: f64 };

/// One value per block and fit size: x = log2(N), y, weight = scored games
const Pair = struct { block: u32, x: f64, d: f64, w: f64 };

const Slope = struct { beta: f64, se_points: f64, sw: []f64, sx: []f64, sd: []f64 };

/// Weighted least squares of d on c[block] + beta * x
fn slopeFit(arena: std.mem.Allocator, pairs: []const Pair) !Slope {
    var nb: usize = 0;
    for (pairs) |p| nb = @max(nb, p.block + 1);
    const sw = try arena.alloc(f64, nb);
    const sx = try arena.alloc(f64, nb);
    const sd = try arena.alloc(f64, nb);
    @memset(sw, 0);
    @memset(sx, 0);
    @memset(sd, 0);
    for (pairs) |p| {
        sw[p.block] += p.w;
        sx[p.block] += p.w * p.x;
        sd[p.block] += p.w * p.d;
    }
    var num: f64 = 0;
    var den: f64 = 0;
    for (pairs) |p| {
        const dx = p.x - sx[p.block] / sw[p.block];
        num += p.w * dx * (p.d - sd[p.block] / sw[p.block]);
        den += p.w * dx * dx;
    }
    const beta = if (den > 0) num / den else 0;
    // Weights scaled to mean 1, so the residual variance is per point; dof: points minus
    // blocks used minus beta
    var wsum: f64 = 0;
    var used: f64 = 0;
    for (sw) |s| if (s > 0) {
        used += 1;
    };
    for (pairs) |p| wsum += p.w;
    const np: f64 = @floatFromInt(pairs.len);
    var rss: f64 = 0;
    for (pairs) |p| {
        const r = p.d - (sd[p.block] - beta * sx[p.block]) / sw[p.block] - beta * p.x;
        rss += p.w * np / wsum * r * r;
    }
    const dof = np - used - 1;
    const se = if (dof > 0 and den > 0) @sqrt(rss / dof / (den * np / wsum)) else std.math.nan(f64);
    return .{ .beta = beta, .se_points = se, .sw = sw, .sx = sx, .sd = sd };
}

fn gapFit(arena: std.mem.Allocator, points: []const Point, m: u32, ref: u32, shared: []const u32, min_fit: f64, max_fit: f64) !Gap {
    var pairs: std.ArrayList(Pair) = .empty;
    var n_max: f64 = 0;
    for (points) |p| {
        if (p.model != m or p.n_fit < min_fit or p.n_fit > max_fit) continue;
        const q = for (points) |q| {
            if (q.model == ref and q.block == p.block and q.n_fit == p.n_fit) break q;
        } else continue;
        try pairs.append(arena, .{ .block = p.block, .x = std.math.log2(p.n_fit), .d = p.mean - q.mean, .w = @floatFromInt(p.games.len) });
        n_max = @max(n_max, p.n_fit);
    }
    const s = try slopeFit(arena, pairs.items);
    var as: f64 = 0;
    var aw: f64 = 0;
    for (shared) |k| if (k < s.sw.len and s.sw[k] > 0) {
        as += s.sd[k] - s.beta * s.sx[k];
        aw += s.sw[k];
    };
    return .{ .alpha = as / @max(aw, 1e-12), .beta = s.beta, .n_max = n_max, .se_points = s.se_points };
}

/// A model's own change per doubling of fit games, log loss or accuracy (full data only)
fn trend(arena: std.mem.Allocator, points: []const Point, m: u32, min_fit: f64, max_fit: f64, acc: bool) !Slope {
    var pairs: std.ArrayList(Pair) = .empty;
    for (points) |p| {
        if (p.model != m or p.n_fit < min_fit or p.n_fit > max_fit) continue;
        const v = if (acc) sum(p.hit) / @as(f64, @floatFromInt(p.hit.len)) else sum(p.loss) / @as(f64, @floatFromInt(p.loss.len));
        try pairs.append(arena, .{ .block = p.block, .x = std.math.log2(p.n_fit), .d = v, .w = @floatFromInt(p.games.len) });
    }
    return slopeFit(arena, pairs.items);
}

fn gapAt(g: Gap, n: f64) f64 {
    return g.alpha + g.beta * std.math.log2(n);
}

/// Fit games where the gap reaches 0 going up from the largest measured size: that size
/// when the model is already level or better there, inf when the gap doesn't shrink
fn crossing(g: Gap) f64 {
    if (gapAt(g, g.n_max) <= 0) return g.n_max;
    if (g.beta >= 0) return std.math.inf(f64);
    return std.math.pow(f64, 2, -g.alpha / g.beta);
}

/// Pooled over a model's points with one label: games-weighted mean log loss, and the
/// same for ref on the same blocks and fit sizes (null when ref lacks one of them)
const Pool = struct { blocks: usize, games: usize, n_fit: f64, model: f64, ref: ?f64, acc: f64 = 0, acc_ref: f64 = 0 };

fn poolLabel(c: *const Corpus, m: u32, ref: u32, label: []const u8, dev: bool) Pool {
    var out: Pool = .{ .blocks = 0, .games = 0, .n_fit = 0, .model = 0, .ref = 0 };
    var rs: f64 = 0;
    var has_ref = true;
    for (c.points.items) |p| {
        if (p.model != m or !std.mem.eql(u8, p.label, label)) continue;
        if (std.mem.eql(u8, c.block_names.items[p.block], "dev") != dev) continue;
        out.blocks += 1;
        out.games += p.games.len;
        out.n_fit += p.n_fit;
        out.model += sum(p.loss);
        out.acc += sum(p.hit);
        const rp = for (c.points.items) |q| {
            if (q.model == ref and q.block == p.block and q.n_fit == p.n_fit) break q;
        } else null;
        if (rp) |q| {
            rs += sum(q.loss);
            out.acc_ref += sum(q.hit);
        } else has_ref = false;
    }
    const g: f64 = @floatFromInt(@max(out.games, 1));
    out.model /= g;
    out.acc /= g;
    out.acc_ref /= g;
    out.n_fit /= @floatFromInt(@max(out.blocks, 1));
    out.ref = if (has_ref) rs / g else null;
    return out;
}

fn sum(xs: []const f64) f64 {
    var s: f64 = 0;
    for (xs) |x| s += x;
    return s;
}

/// Paired 95% half-width of model minus ref over the pooled games, log loss or hits
fn pairedHalf(c: *const Corpus, m: u32, ref: u32, label: []const u8, dev: bool, hits: bool) ?f64 {
    var n: f64 = 0;
    var s: f64 = 0;
    var ss: f64 = 0;
    for (c.points.items) |p| {
        if (p.model != m or !std.mem.eql(u8, p.label, label)) continue;
        if (std.mem.eql(u8, c.block_names.items[p.block], "dev") != dev) continue;
        const q = for (c.points.items) |q| {
            if (q.model == ref and q.block == p.block and q.n_fit == p.n_fit) break q;
        } else return null;
        // Same run's games in the same order
        if (q.games.len != p.games.len) return null;
        for (if (hits) p.hit else p.loss, if (hits) q.hit else q.loss) |a, b| {
            n += 1;
            s += a - b;
            ss += (a - b) * (a - b);
        }
    }
    if (n < 2) return null;
    const mean = s / n;
    return 1.96 * @sqrt((ss / n - mean * mean) / (n - 1));
}

fn labels(arena: std.mem.Allocator, c: *const Corpus) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    for (c.points.items) |p| {
        const seen = for (out.items) |l| {
            if (std.mem.eql(u8, l, p.label)) break true;
        } else false;
        if (!seen) try out.append(arena, p.label);
    }
    return out.items;
}

fn report(arena: std.mem.Allocator, c: *const Corpus, shared: []const u32, fits: []const Fit, gaps: []const Gap, reps: u32, ref: u32, ns: []const f64, min_fit: f64, max_fit: f64, w: *Io.Writer) !void {
    const nm = c.models.items.len;
    try w.print("# curve: {d} models, {d} blocks ({d} shared by all), {d} points, {d} games, {d} bootstrap replicates\n\n", .{ nm, c.block_keys.items.len, shared.len, c.points.items.len, c.n_games, reps });
    try w.writeAll("Blocks: ");
    for (c.block_names.items, c.block_games.items, 0..) |name, n, b| try w.print("{s}{d}={s} ({d} games)", .{ if (b > 0) ", " else "", b, name, n });
    try w.writeAll("\n\n## Points pooled by label (folds = non-dev blocks; ± paired per game vs ref)\n\n");
    try w.print("| model | label | blocks | mean fit games | scored games | accuracy, 95% | acc vs {s}, pp | log loss | vs {s} |\n| --- | --- | --- | --- | --- | --- | --- | --- | --- |\n", .{ c.models.items[ref], c.models.items[ref] });
    for (try labels(arena, c)) |l| for (0..nm) |m| for ([_]bool{ false, true }) |dev| {
        const p = poolLabel(c, @intCast(m), ref, l, dev);
        if (p.blocks == 0) continue;
        const half_acc = 1.96 * @sqrt(p.acc * (1 - p.acc) / @as(f64, @floatFromInt(p.games)));
        try w.print("| {s} | {s}{s} | {d} | {d:.0} | {d} | {d:.2}% ± {d:.2} |", .{ c.models.items[m], l, if (dev) " dev" else "", p.blocks, p.n_fit, p.games, 100 * p.acc, 100 * half_acc });
        if (p.ref != null and m != ref) {
            try w.print(" {d:.2} ± {d:.2} |", .{ 100 * (p.acc - p.acc_ref), 100 * (pairedHalf(c, @intCast(m), ref, l, dev, true) orelse std.math.nan(f64)) });
        } else try w.writeAll(" |");
        try w.print(" {d:.5} |", .{p.model});
        if (p.ref != null and m != ref) {
            try w.print(" {d:.5} ± {d:.5} |\n", .{ p.model - p.ref.?, pairedHalf(c, @intCast(m), ref, l, dev, false) orelse std.math.nan(f64) });
        } else try w.writeAll(" |\n");
    };

    const tmp = try arena.alloc(f64, reps);
    try w.writeAll("\n## Fits: log loss = a * N^-b + c (c: mean over shared blocks; 95% bootstrap)\n\n| model | a | b | c | ok |\n| --- | --- | --- | --- | --- |\n");
    for (0..nm) |m| {
        const f0 = fits[m];
        for (tmp, 0..) |*x, r| x.* = fits[(r + 1) * nm + m].b;
        var finite: std.ArrayList(f64) = .empty;
        for (tmp) |x| if (!std.math.isNan(x)) try finite.append(arena, x);
        const bi = try interval(arena, f0.b, finite.items);
        for (tmp, 0..) |*x, r| x.* = fits[(r + 1) * nm + m].c;
        const ci = try interval(arena, f0.c, tmp);
        try w.print("| {s} | {e:.3} | {d:.3} [{d:.3}, {d:.3}] ({d}% of reps flat) | {d:.5} [{d:.5}, {d:.5}] | {} |\n", .{ c.models.items[m], f0.a, bi.est, bi.lo, bi.hi, (reps - finite.items.len) * 100 / @max(reps, 1), ci.est, ci.lo, ci.hi, f0.ok });
    }

    const rn = c.models.items[ref];
    try w.print("\n## Gap vs {s}: model minus {s} = alpha[block] + beta * log2(N) (paired points; 95% bootstrap)\n\n| model | beta per doubling | ± 95% from the points' scatter | P beta < 0 | gap at largest N | largest N | crossing N | 95% | reps crossing by 1e7 |\n| --- | --- | --- | --- | --- | --- | --- | --- | --- |\n", .{ rn, rn });
    for (0..nm) |m| {
        if (m == ref) continue;
        const g0 = gaps[m];
        var neg: usize = 0;
        for (tmp, 0..) |*x, r| {
            x.* = gaps[(r + 1) * nm + m].beta;
            if (x.* < 0) neg += 1;
        }
        const bi = try interval(arena, g0.beta, tmp);
        for (tmp, 0..) |*x, r| x.* = gapAt(gaps[(r + 1) * nm + m], g0.n_max);
        const gi = try interval(arena, gapAt(g0, g0.n_max), tmp);
        var by: usize = 0;
        for (tmp, 0..) |*x, r| {
            x.* = crossing(gaps[(r + 1) * nm + m]);
            if (x.* <= 1e7) by += 1;
        }
        const xi = try interval(arena, crossing(g0), tmp);
        try w.print("| {s} | {d:.5} [{d:.5}, {d:.5}] | ± {d:.5} | {d:.2} | {d:.5} [{d:.5}, {d:.5}] | {d:.0} | {e:.2} | [{e:.2}, {e:.2}] | {d}% |\n", .{ c.models.items[m], bi.est, bi.lo, bi.hi, 1.96 * g0.se_points, frac(neg, reps), gi.est, gi.lo, gi.hi, g0.n_max, xi.est, xi.lo, xi.hi, by * 100 / @max(reps, 1) });
    }

    try w.writeAll("\n## Per doubling of fit games: each model's own points, offset per block (2x today = one doubling, 4x = two; ± 95% from the points' scatter)\n\n| model | log loss per doubling | accuracy per doubling, pp |\n| --- | --- | --- |\n");
    for (0..nm) |m| {
        const tl = try trend(arena, c.points.items, @intCast(m), min_fit, max_fit, false);
        const ta = try trend(arena, c.points.items, @intCast(m), min_fit, max_fit, true);
        try w.print("| {s} | {d:.5} ± {d:.5} | {d:.3} ± {d:.3} |\n", .{ c.models.items[m], tl.beta, 1.96 * tl.se_points, 100 * ta.beta, 196 * ta.se_points });
    }

    try w.print("\n## Projection at N fit games: {s}'s power law; others {s} + their gap (95% bootstrap; P = share of replicates below {s})\n\n| model | N | log loss | vs {s} | P better |\n| --- | --- | --- | --- | --- |\n", .{ rn, rn, rn, rn });
    for (0..nm) |m| for (ns) |n| {
        const base = curveAt(fits[ref], n);
        if (m == ref) {
            for (tmp, 0..) |*x, r| x.* = curveAt(fits[(r + 1) * nm + ref], n);
            const a = try interval(arena, base, tmp);
            try w.print("| {s} | {d:.0} | {d:.5} [{d:.5}, {d:.5}] | | |\n", .{ rn, n, a.est, a.lo, a.hi });
            continue;
        }
        var better: usize = 0;
        for (tmp, 0..) |*x, r| {
            x.* = gapAt(gaps[(r + 1) * nm + m], n);
            if (x.* < 0) better += 1;
        }
        const d = try interval(arena, gapAt(gaps[m], n), tmp);
        try w.print("| {s} | {d:.0} | {d:.5} | {d:.5} [{d:.5}, {d:.5}] | {d:.2} |\n", .{ c.models.items[m], n, base + d.est, d.est, d.lo, d.hi, frac(better, reps) });
    };
}

fn frac(k: usize, n: u32) f64 {
    return @as(f64, @floatFromInt(k)) / @as(f64, @floatFromInt(@max(n, 1)));
}

/// docs/nn-results rows: pooled folds per label (absolute, and vs ref) and projections
fn tsvRows(arena: std.mem.Allocator, c: *const Corpus, fits: []const Fit, gaps: []const Gap, reps: u32, ref: u32, ns: []const f64, w: *Io.Writer) !void {
    const nm = c.models.items.len;
    const rname = c.models.items[ref];
    for (try labels(arena, c)) |l| for (0..nm) |m| {
        const p = poolLabel(c, @intCast(m), ref, l, false);
        if (p.blocks == 0) continue;
        try w.print("{s}\t-\tfolds\t{d:.5}\t\t\t\t\t{d}\t{d:.0}\t\t{s}\n", .{ c.models.items[m], p.model, p.games, p.n_fit, l });
        if (m == ref or p.ref == null) continue;
        const half = pairedHalf(c, @intCast(m), ref, l, false, false) orelse std.math.nan(f64);
        try w.print("{s}\t{s}\tfolds\t{d:.5}\t{d:.5}\t\t\t\t{d}\t{d:.0}\t\t{s}\n", .{ c.models.items[m], rname, p.model - p.ref.?, half, p.games, p.n_fit, l });
    };
    const tmp = try arena.alloc(f64, reps);
    for (0..nm) |m| for (ns) |n| {
        const base = curveAt(fits[ref], n);
        if (m == ref) {
            try w.print("{s}\t-\tprojection\t{d:.5}\t\t\t\t\t\t{d:.0}\t\ta*N^-b+c\n", .{ rname, base, n });
            continue;
        }
        for (tmp, 0..) |*x, r| x.* = gapAt(gaps[(r + 1) * nm + m], n);
        const d = try interval(arena, gapAt(gaps[m], n), tmp);
        try w.print("{s}\t-\tprojection\t{d:.5}\t\t\t\t\t\t{d:.0}\t\t{s}'s a*N^-b+c plus the gap's log2 trend\n", .{ c.models.items[m], base + d.est, n, rname });
        try w.print("{s}\t{s}\tprojection\t{d:.5}\t{d:.5}\t\t\t\t\t{d:.0}\t\tgap's log2 trend, bootstrap [{d:.5}, {d:.5}]\n", .{ c.models.items[m], rname, d.est, (d.hi - d.lo) / 2, n, d.lo, d.hi });
    };
}

test "fitModel recovers a power law with block offsets" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var points: std.ArrayList(Point) = .empty;
    const g = try arena.alloc(u32, 10);
    const l = try arena.alloc(f64, 10);
    for ([_]f64{ 0.69, 0.70 }, 0..) |c0, b| for ([_]f64{ 1e4, 3e4, 1e5, 3e5 }) |n| {
        try points.append(arena, .{ .model = 0, .block = @intCast(b), .label = "x", .n_fit = n, .games = g, .loss = l, .hit = l, .mean = c0 + 2.0 * std.math.pow(f64, n, -0.5) });
    };
    const f = try fitModel(arena, points.items, 0, &.{ 0, 1 });
    try std.testing.expect(f.ok);
    try std.testing.expectApproxEqAbs(0.5, f.b, 0.02);
    try std.testing.expectApproxEqAbs(0.695, f.c, 1e-4);
    try std.testing.expectApproxEqAbs(0.695 + 2.0 * std.math.pow(f64, 1e6, -0.5), curveAt(f, 1e6), 1e-4);
}

test "gapFit: slope per doubling and crossing past the largest size" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var points: std.ArrayList(Point) = .empty;
    const g = try arena.alloc(u32, 10);
    const l = try arena.alloc(f64, 10);
    for ([_]f64{ 0.69, 0.70 }, 0..) |c0, b| for ([_]f64{ 1e4, 2e4, 4e4 }, 0..) |n, k| {
        try points.append(arena, .{ .model = 0, .block = @intCast(b), .label = "x", .n_fit = n, .games = g, .loss = l, .hit = l, .mean = c0 });
        // Gap 0.003 at 1e4, 0.001 less per doubling: level at 8e4
        const gap = 0.003 - 0.001 * @as(f64, @floatFromInt(k));
        try points.append(arena, .{ .model = 1, .block = @intCast(b), .label = "x", .n_fit = n, .games = g, .loss = l, .hit = l, .mean = c0 + gap });
    };
    const gf = try gapFit(arena, points.items, 1, 0, &.{ 0, 1 }, 0, std.math.inf(f64));
    try std.testing.expectApproxEqAbs(-0.001, gf.beta, 1e-9);
    try std.testing.expectEqual(4e4, gf.n_max);
    try std.testing.expectApproxEqRel(8e4, crossing(gf), 1e-6);
}
