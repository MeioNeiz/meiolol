//! `meiolol-lab stack NAME=FILE:COL...`: temperature scaling and a logistic stacker over
//! per-game win predictions already made out of sample (netcheck's preds.tsv, pretrain's
//! preds.tsv; docs/model.md "Neural draft models"). Blocks are win-comp's 5 forward folds
//! (1-5, oldest first) and dev-val. Anything fitted here for block k uses only the
//! predictions on blocks before it, which are all inside block k's fit games: folds 1..k-1
//! for fold k, folds 1-5 for dev-val. Fold 1 has nothing before it, so fitted rows score
//! folds 2-5 and dev-val, the reference on the same games.
//! FILE: tab-separated with a header holding match_id, y, a block column (fold or block)
//! and COL (blue's chance). With a seed column, COL is averaged over a game's seed rows
//! (pretrain's preds). Every input must hold the first input's games.
//! Rows per input: alone; temperature (blue's logit times one scale, no intercept); plus
//! the simple average of the inputs' chances and the stacker (logistic on the inputs'
//! logits with an intercept, small L2 on the weights). Gains are paired per game
//! (= clustered by game), 95% intervals, against each --ref (default the first input).
//! Control (--permute SEED): every input but the first ref shuffled across games within
//! each block, so it carries no information about the game; the stacker's gain over the
//! ref must then be ~0. --shuffle-y SEED: the fitted rows learn from outcomes shuffled
//! within each block (scored on the real ones), so they must gain ~0.
//! Trees (lab/gbdt.zig): boosting on top of the first ref's logit over the inputs' logits
//! and, with --feat FILE (compcheck.tsv: per team, profiles built from older games), each
//! team's profile features; fitted forward like the stacker

const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const gbdt = @import("gbdt.zig");

pub const usage =
    \\  stack NAME=FILE:COL... [--ref NAME,NAME] [--l2 X] [--permute SEED]
    \\        [--shuffle-y SEED] [--feat FILE]... [--out FILE]
    \\                                  temperature per model and a logistic stacker on
    \\                                  out-of-sample per-game predictions, fitted
    \\                                  forward over win-comp's folds (lab/stack.zig)
    \\
;

const blocks = [_][]const u8{ "1", "2", "3", "4", "5", "dev" };
const max_inputs = 16;
const eps = 1e-6;

const Input = struct { name: []const u8, path: []const u8, col: []const u8 };

const Data = struct {
    block: []u8,
    y: []f64,
    /// Outcomes the fitted rows learn from: y, or y shuffled within blocks (--shuffle-y)
    y_fit: []f64,
    id: [][]const u8,
    /// Blue's chance per input, input-major: p[m * n + i]
    p: []f64,
    n: usize,
};

pub fn main(gpa: Allocator, arena: Allocator, io: Io, argv: []const []const u8) !u8 {
    var inputs: std.ArrayList(Input) = .empty;
    var ref: ?[]const u8 = null;
    var permute: ?u64 = null;
    var shuffle_y: ?u64 = null;
    var feats: std.ArrayList([]const u8) = .empty;
    var l2: f64 = 1e-4;
    var out: ?[]const u8 = null;
    var i: usize = 0;
    while (i < argv.len) : (i += 1) {
        const a = argv[i];
        if (std.mem.startsWith(u8, a, "--")) {
            if (i + 1 >= argv.len) return usageError();
            const v = argv[i + 1];
            i += 1;
            if (std.mem.eql(u8, a, "--ref")) {
                ref = v;
            } else if (std.mem.eql(u8, a, "--l2")) {
                l2 = try std.fmt.parseFloat(f64, v);
            } else if (std.mem.eql(u8, a, "--shuffle-y")) {
                shuffle_y = try std.fmt.parseInt(u64, v, 10);
            } else if (std.mem.eql(u8, a, "--feat")) {
                try feats.append(arena, v);
            } else if (std.mem.eql(u8, a, "--permute")) {
                permute = try std.fmt.parseInt(u64, v, 10);
            } else if (std.mem.eql(u8, a, "--out")) {
                out = v;
            } else return usageError();
            continue;
        }
        const eq = std.mem.indexOfScalar(u8, a, '=') orelse return usageError();
        const colon = std.mem.lastIndexOfScalar(u8, a, ':') orelse return usageError();
        if (colon < eq) return usageError();
        try inputs.append(arena, .{ .name = a[0..eq], .path = a[eq + 1 .. colon], .col = a[colon + 1 ..] });
    }
    if (inputs.items.len == 0 or inputs.items.len > max_inputs) return usageError();
    var refs: std.ArrayList(usize) = .empty;
    var names = std.mem.tokenizeScalar(u8, ref orelse inputs.items[0].name, ',');
    while (names.next()) |name| try refs.append(arena, for (inputs.items, 0..) |in, m| {
        if (std.mem.eql(u8, in.name, name)) break m;
    } else return usageError());

    const data = try load(gpa, arena, io, inputs.items);
    defer {
        gpa.free(data.block);
        gpa.free(data.y);
        gpa.free(data.y_fit);
        gpa.free(data.id);
        gpa.free(data.p);
    }

    if (permute) |seed| try shuffle(gpa, &data, refs.items[0], seed);
    if (shuffle_y) |seed| try shuffleOutcomes(gpa, &data, seed);
    const teams = try loadTeams(arena, io, feats.items, &data);

    var buf: [8192]u8 = undefined;
    var stdout = Io.File.stdout().writer(io, &buf);
    const w = &stdout.interface;
    try report(gpa, arena, w, &data, inputs.items, refs.items, l2, teams, out, io);
    try w.flush();
    return 0;
}

/// Shuffles the outcomes the fitted rows learn from, within each block
fn shuffleOutcomes(gpa: Allocator, d: *const Data, seed: u64) !void {
    var prng = std.Random.DefaultPrng.init(seed);
    const rnd = prng.random();
    var vals: std.ArrayList(f64) = .empty;
    defer vals.deinit(gpa);
    for (0..blocks.len) |b| {
        vals.clearRetainingCapacity();
        for (0..d.n) |i| if (d.block[i] == b) try vals.append(gpa, d.y_fit[i]);
        rnd.shuffle(f64, vals.items);
        var j: usize = 0;
        for (0..d.n) |i| if (d.block[i] == b) {
            d.y_fit[i] = vals.items[j];
            j += 1;
        };
    }
}

/// Per-team features per game from compcheck.tsv files (side 0 blue): every column after
/// pred, the columns all files share. x[i * 2F + side * F + f]; NaN where a game is missing
const Teams = struct { names: []const []const u8, x: []f64 };

fn loadTeams(arena: Allocator, io: Io, paths: []const []const u8, d: *const Data) !Teams {
    if (paths.len == 0) return .{ .names = &.{}, .x = &.{} };
    var names: std.ArrayList([]const u8) = .empty;
    var texts: std.ArrayList([]const u8) = .empty;
    for (paths, 0..) |path, pi| {
        const text = try Io.Dir.cwd().readFileAlloc(io, path, arena, .unlimited);
        try texts.append(arena, text);
        const header = text[0 .. std.mem.indexOfScalar(u8, text, '\n') orelse return error.Empty];
        const at_pred = column(header, "pred") orelse return error.MissingColumn;
        if (pi == 0) {
            var it = std.mem.splitScalar(u8, header, '\t');
            var c: usize = 0;
            while (it.next()) |h| : (c += 1) if (c > at_pred) try names.append(arena, h);
        } else {
            var keep: std.ArrayList([]const u8) = .empty;
            for (names.items) |nm| if (column(header, nm) != null) try keep.append(arena, nm);
            names = keep;
        }
    }
    const nf = names.items.len;
    var index: std.StringHashMapUnmanaged(u32) = .empty;
    for (d.id, 0..) |id, i| try index.put(arena, id, @intCast(i));
    const x = try arena.alloc(f64, d.n * 2 * nf);
    @memset(x, std.math.nan(f64));
    for (texts.items) |text| {
        var lines = std.mem.tokenizeScalar(u8, text, '\n');
        const header = lines.next().?;
        const at_id = column(header, "match_id") orelse return error.MissingColumn;
        const at_side = column(header, "side") orelse return error.MissingColumn;
        var at: [32]usize = undefined;
        for (names.items, 0..) |nm, f| at[f] = column(header, nm).?;
        var cols: [64][]const u8 = undefined;
        while (lines.next()) |line| {
            var it = std.mem.splitScalar(u8, line, '\t');
            var c: usize = 0;
            while (it.next()) |v| : (c += 1) if (c < cols.len) {
                cols[c] = v;
            };
            const i = index.get(cols[at_id]) orelse continue;
            const side = try std.fmt.parseInt(u1, cols[at_side], 10);
            for (0..nf) |f| x[i * 2 * nf + side * nf + f] = std.fmt.parseFloat(f64, cols[at[f]]) catch std.math.nan(f64);
        }
    }
    return .{ .names = names.items, .x = x };
}

/// Shuffles every input but keep across games within each block
fn shuffle(gpa: Allocator, d: *const Data, keep: usize, seed: u64) !void {
    var prng = std.Random.DefaultPrng.init(seed);
    const rnd = prng.random();
    var vals: std.ArrayList(f64) = .empty;
    defer vals.deinit(gpa);
    for (0..d.p.len / d.n) |m| {
        if (m == keep) continue;
        const p = d.p[m * d.n ..][0..d.n];
        for (0..blocks.len) |b| {
            vals.clearRetainingCapacity();
            for (0..d.n) |i| if (d.block[i] == b) try vals.append(gpa, p[i]);
            rnd.shuffle(f64, vals.items);
            var j: usize = 0;
            for (0..d.n) |i| if (d.block[i] == b) {
                p[i] = vals.items[j];
                j += 1;
            };
        }
    }
}

fn usageError() u8 {
    std.debug.print("usage:\n{s}", .{usage});
    return 2;
}

fn column(header: []const u8, name: []const u8) ?usize {
    var it = std.mem.splitScalar(u8, header, '\t');
    var i: usize = 0;
    while (it.next()) |h| : (i += 1) if (std.mem.eql(u8, h, name)) return i;
    return null;
}

fn blockIndex(s: []const u8) ?u8 {
    for (blocks, 0..) |b, i| if (std.mem.eql(u8, b, s)) return @intCast(i);
    return null;
}

const Acc = struct { sum: f64 = 0, n: f64 = 0 };

fn load(gpa: Allocator, arena: Allocator, io: Io, inputs: []const Input) !Data {
    // Games (block + match id) in the first input's order
    var index: std.StringHashMapUnmanaged(u32) = .empty;
    defer index.deinit(gpa);
    var block: std.ArrayList(u8) = .empty;
    defer block.deinit(gpa);
    var ids: std.ArrayList([]const u8) = .empty;
    defer ids.deinit(gpa);
    var y: std.ArrayList(f64) = .empty;
    defer y.deinit(gpa);
    var accs: std.ArrayList(Acc) = .empty;
    defer accs.deinit(gpa);

    for (inputs, 0..) |in, m| {
        const text = try Io.Dir.cwd().readFileAlloc(io, in.path, arena, .unlimited);
        var lines = std.mem.tokenizeScalar(u8, text, '\n');
        const header = lines.next() orelse return error.Empty;
        const at_block = column(header, "fold") orelse column(header, "block") orelse return error.MissingColumn;
        const at_id = column(header, "match_id") orelse return error.MissingColumn;
        const at_y = column(header, "y") orelse return error.MissingColumn;
        const at_p = column(header, in.col) orelse {
            std.debug.print("{s}: no column {s}\n", .{ in.path, in.col });
            return error.MissingColumn;
        };
        if (m > 0) try accs.appendNTimes(gpa, .{}, y.items.len);
        var cols: [64][]const u8 = undefined;
        while (lines.next()) |line| {
            var it = std.mem.splitScalar(u8, line, '\t');
            var n: usize = 0;
            while (it.next()) |c| : (n += 1) if (n < cols.len) {
                cols[n] = c;
            };
            const b = blockIndex(cols[at_block]) orelse continue;
            const key = try std.fmt.allocPrint(arena, "{s}\t{s}", .{ cols[at_block], cols[at_id] });
            const yv = try std.fmt.parseFloat(f64, cols[at_y]);
            const pv = try std.fmt.parseFloat(f64, cols[at_p]);
            const g: u32 = if (index.get(key)) |g| g else blk: {
                if (m > 0) continue;
                const g: u32 = @intCast(y.items.len);
                try index.put(gpa, key, g);
                try block.append(gpa, b);
                try ids.append(gpa, cols[at_id]);
                try y.append(gpa, yv);
                try accs.append(gpa, .{});
                break :blk g;
            };
            if (y.items[g] != yv) return error.OutcomeMismatch;
            const e = &accs.items[m * y.items.len + g];
            e.sum += pv;
            e.n += 1;
        }
    }

    // Keep games every input has
    const n_all = y.items.len;
    const n_in = inputs.len;
    var keep: std.ArrayList(u32) = .empty;
    defer keep.deinit(gpa);
    for (0..n_all) |g| {
        const all = for (0..n_in) |m| {
            if (accs.items[m * n_all + g].n == 0) break false;
        } else true;
        if (all) try keep.append(gpa, @intCast(g));
    }
    for (inputs, 0..) |in, m| {
        var missing: usize = 0;
        for (0..n_all) |g| missing += @intFromBool(accs.items[m * n_all + g].n == 0);
        if (missing > 0) std.debug.print("{s}: {d} of the first input's games missing, left out\n", .{ in.name, missing });
    }
    const n = keep.items.len;
    const d: Data = .{
        .block = try gpa.alloc(u8, n),
        .y = try gpa.alloc(f64, n),
        .y_fit = try gpa.alloc(f64, n),
        .id = try gpa.alloc([]const u8, n),
        .p = try gpa.alloc(f64, n * n_in),
        .n = n,
    };
    for (keep.items, 0..) |g, i| {
        d.block[i] = block.items[g];
        d.y[i] = y.items[g];
        d.y_fit[i] = y.items[g];
        d.id[i] = ids.items[g];
        for (0..n_in) |m| {
            const e = accs.items[m * n_all + g];
            d.p[m * n + i] = e.sum / e.n;
        }
    }
    return d;
}

fn logit(p: f64) f64 {
    const q = std.math.clamp(p, eps, 1 - eps);
    return @log(q / (1 - q));
}

fn sigmoid(z: f64) f64 {
    return 1 / (1 + @exp(-z));
}

fn logLoss(y: f64, p: f64) f64 {
    const q = std.math.clamp(p, eps, 1 - eps);
    return -(y * @log(q) + (1 - y) * @log(1 - q));
}

/// Logistic regression on x (n rows of k features, row-major) by Newton's method; L2
/// (times n) on every weight but the intercept, which is the last feature when used
pub fn fitLogistic(gpa: Allocator, x: []const f64, y: []const f64, k: usize, intercept: bool, l2: f64) ![]f64 {
    const n = y.len;
    const w = try gpa.alloc(f64, k);
    @memset(w, 0);
    const g = try gpa.alloc(f64, k);
    defer gpa.free(g);
    const h = try gpa.alloc(f64, k * k);
    defer gpa.free(h);
    const nf: f64 = @floatFromInt(n);
    for (0..50) |_| {
        @memset(g, 0);
        @memset(h, 0);
        for (0..n) |i| {
            const row = x[i * k ..][0..k];
            var z: f64 = 0;
            for (row, w) |a, b| z += a * b;
            const p = sigmoid(z);
            const v = p * (1 - p);
            for (0..k) |a| {
                g[a] += (p - y[i]) * row[a];
                for (0..k) |b| h[a * k + b] += v * row[a] * row[b];
            }
        }
        for (0..k) |a| if (!(intercept and a == k - 1)) {
            g[a] += l2 * nf * w[a];
            h[a * k + a] += l2 * nf;
        };
        try solve(gpa, h, g, k);
        var step: f64 = 0;
        for (w, g) |*a, b| {
            a.* -= b;
            step = @max(step, @abs(b));
        }
        if (step < 1e-10) break;
    }
    return w;
}

/// Solves h x = g in place (g becomes x); Gaussian elimination with partial pivoting
fn solve(gpa: Allocator, h: []f64, g: []f64, k: usize) !void {
    _ = gpa;
    for (0..k) |c| {
        var piv = c;
        for (c + 1..k) |r| if (@abs(h[r * k + c]) > @abs(h[piv * k + c])) {
            piv = r;
        };
        if (h[piv * k + c] == 0) return error.Singular;
        if (piv != c) {
            for (0..k) |j| std.mem.swap(f64, &h[c * k + j], &h[piv * k + j]);
            std.mem.swap(f64, &g[c], &g[piv]);
        }
        for (c + 1..k) |r| {
            const f = h[r * k + c] / h[c * k + c];
            for (c..k) |j| h[r * k + j] -= f * h[c * k + j];
            g[r] -= f * g[c];
        }
    }
    var c = k;
    while (c > 0) {
        c -= 1;
        var s = g[c];
        for (c + 1..k) |j| s -= h[c * k + j] * g[j];
        g[c] = s / h[c * k + c];
    }
}

/// Games of the blocks a block's fitted rows learn from: folds before it, every fold for dev
fn fitsOn(target: u8, b: u8) bool {
    return b < target and b < 5;
}

/// Forward fit and prediction of one fitted model for every block but fold 1: features
/// per game from feat (k per game), NaN where nothing could be fitted
fn forward(gpa: Allocator, d: *const Data, feat: []const f64, k: usize, intercept: bool, l2: f64, pred: []f64, weights: ?[]f64) !void {
    @memset(pred, std.math.nan(f64));
    for (1..blocks.len) |t| {
        var xs: std.ArrayList(f64) = .empty;
        defer xs.deinit(gpa);
        var ys: std.ArrayList(f64) = .empty;
        defer ys.deinit(gpa);
        for (0..d.n) |i| if (fitsOn(@intCast(t), d.block[i])) {
            try xs.appendSlice(gpa, feat[i * k ..][0..k]);
            try ys.append(gpa, d.y_fit[i]);
        };
        const w = try fitLogistic(gpa, xs.items, ys.items, k, intercept, l2);
        defer gpa.free(w);
        if (weights) |out| @memcpy(out[(t - 1) * k ..][0..k], w);
        for (0..d.n) |i| if (d.block[i] == t) {
            var z: f64 = 0;
            for (feat[i * k ..][0..k], w) |a, b| z += a * b;
            pred[i] = sigmoid(z);
        };
    }
}

/// Features of game i seen from one side: every input's logit, then that side's team
/// features, then the other side's; the red view negates the logits
fn treeRow(d: *const Data, teams: Teams, i: usize, red: bool, out: []f64) void {
    const k_in = d.p.len / d.n;
    const sign: f64 = if (red) -1 else 1;
    for (0..k_in) |m| out[m] = sign * logit(d.p[m * d.n + i]);
    const nf = teams.names.len;
    if (nf == 0) return;
    const own = teams.x[i * 2 * nf + @as(usize, @intFromBool(red)) * nf ..][0..nf];
    const other = teams.x[i * 2 * nf + @as(usize, @intFromBool(!red)) * nf ..][0..nf];
    @memcpy(out[k_in..][0..nf], own);
    @memcpy(out[k_in + nf ..][0..nf], other);
}

/// Boosted trees on top of ref's logit, fitted forward like the stacker. Each fit game
/// enters from both sides (red's view: features swapped, logits and offset negated,
/// outcome flipped) and a prediction is the antisymmetric part, so swapping the teams
/// flips the chance. Tree count from early stopping on the newest fit fold (fold 2's fit
/// has one fold: every fifth game of it), then a refit on every fit game with that count
fn forwardTrees(gpa: Allocator, arena: Allocator, d: *const Data, ref: usize, teams: Teams, pred: []f64, counts: []usize) !void {
    const k = d.p.len / d.n + 2 * teams.names.len;
    @memset(pred, std.math.nan(f64));
    const row = try arena.alloc(f64, k);
    const Set = struct {
        x: std.ArrayList(f64) = .empty,
        y: std.ArrayList(f64) = .empty,
        off: std.ArrayList(f64) = .empty,
        fn add(set: *@This(), g: Allocator, dd: *const Data, tm: Teams, r: usize, i: usize, buf: []f64) !void {
            for ([_]bool{ false, true }) |red| {
                treeRow(dd, tm, i, red, buf);
                try set.x.appendSlice(g, buf);
                try set.y.append(g, if (red) 1 - dd.y_fit[i] else dd.y_fit[i]);
                const o = logit(dd.p[r * dd.n + i]);
                try set.off.append(g, if (red) -o else o);
            }
        }
        fn deinit(set: *@This(), g: Allocator) void {
            set.x.deinit(g);
            set.y.deinit(g);
            set.off.deinit(g);
        }
    };
    for (1..blocks.len) |t| {
        const newest: u8 = @intCast(@min(t, 5) - 1);
        var train: Set = .{};
        defer train.deinit(gpa);
        var val: Set = .{};
        defer val.deinit(gpa);
        var all: Set = .{};
        defer all.deinit(gpa);
        var seen: usize = 0;
        for (0..d.n) |i| if (fitsOn(@intCast(t), d.block[i])) {
            try all.add(gpa, d, teams, ref, i, row);
            const is_val = if (newest == 0) seen % 5 == 4 else d.block[i] == newest;
            seen += 1;
            if (is_val) try val.add(gpa, d, teams, ref, i, row) else try train.add(gpa, d, teams, ref, i, row);
        };
        var probe = try gbdt.fit(gpa, train.x.items, train.y.items, train.off.items, k, .{ .x = val.x.items, .y = val.y.items, .offset = val.off.items }, .{});
        const n_trees = probe.trees;
        probe.deinit(gpa);
        counts[t - 1] = n_trees;
        var model = try gbdt.fit(gpa, all.x.items, all.y.items, all.off.items, k, null, .{ .max_trees = @intCast(@max(n_trees, 1)) });
        defer model.deinit(gpa);
        if (n_trees == 0) model.trees = 0;
        for (0..d.n) |i| if (d.block[i] == t) {
            treeRow(d, teams, i, false, row);
            const blue = model.margin(row);
            treeRow(d, teams, i, true, row);
            const red = model.margin(row);
            pred[i] = sigmoid(logit(d.p[ref * d.n + i]) + (blue - red) / 2);
        };
    }
}

const Paired = struct { mean: f64, half: f64, n: usize, ll: f64 };

/// Mean of a's log loss minus b's over the games picked by keep, 95% half-width
fn paired(d: *const Data, a: []const f64, b: []const f64, keep: Mask) Paired {
    var s: f64 = 0;
    var s2: f64 = 0;
    var la: f64 = 0;
    var n: usize = 0;
    for (0..d.n) |i| {
        if (!keep[d.block[i]] or std.math.isNan(a[i])) continue;
        const x = logLoss(d.y[i], a[i]);
        const diff = x - logLoss(d.y[i], b[i]);
        s += diff;
        s2 += diff * diff;
        la += x;
        n += 1;
    }
    if (n < 2) return .{ .mean = std.math.nan(f64), .half = std.math.nan(f64), .n = n, .ll = std.math.nan(f64) };
    const nf: f64 = @floatFromInt(n);
    const mean = s / nf;
    const variance = (s2 - nf * mean * mean) / (nf - 1);
    return .{ .mean = mean, .half = 1.96 * @sqrt(variance / nf), .n = n, .ll = la / nf };
}

const Mask = [blocks.len]bool;
const folds15: Mask = .{ true, true, true, true, true, false };
const folds25: Mask = .{ false, true, true, true, true, false };
const dev_only: Mask = .{ false, false, false, false, false, true };

const Model = struct { name: []const u8, p: []const f64 };

fn tableRow(w: *Io.Writer, d: *const Data, m: Model, ref: []const f64) !void {
    try w.print("| {s} |", .{m.name});
    for ([_]Mask{ folds15, folds25, dev_only }, 0..) |pick, c| {
        const p = paired(d, m.p, ref, pick);
        // A fitted row has no fold 1: its folds 1-5 cell would repeat folds 2-5
        if (std.math.isNan(p.mean) or (c == 0 and std.math.isNan(firstOf(d, m.p, 0)))) {
            try w.writeAll(" - |");
        } else try w.print(" {d:.5} ({d:.5} ± {d:.5}) |", .{ p.ll, p.mean, p.half });
    }
    var better: usize = 0;
    var scored: usize = 0;
    for (0..5) |f| {
        var one: Mask = @splat(false);
        one[f] = true;
        const p = paired(d, m.p, ref, one);
        if (std.math.isNan(p.mean)) continue;
        scored += 1;
        better += @intFromBool(p.mean < 0);
    }
    try w.print(" {d} of {d} |\n", .{ better, scored });
}

/// The prediction on the first game of block b
fn firstOf(d: *const Data, p: []const f64, b: u8) f64 {
    for (0..d.n) |i| if (d.block[i] == b) return p[i];
    return std.math.nan(f64);
}

fn report(gpa: Allocator, arena: Allocator, w: *Io.Writer, d: *const Data, inputs: []const Input, refs: []const usize, l2: f64, teams: Teams, out: ?[]const u8, io: Io) !void {
    const n = d.n;
    const k_in = inputs.len;
    var counts: [blocks.len]usize = @splat(0);
    for (d.block) |b| counts[b] += 1;
    try w.print("# stack: {d} inputs, {d} games (folds 1-5: {any}, dev-val {d}), stacker L2 {d}\n\n", .{ k_in, n, counts[0..5], counts[5], l2 });
    try w.writeAll("Fitted rows: fold k from folds before it, dev-val from folds 1-5; fold 1 has none.\n");

    var models: std.ArrayList(Model) = .empty;
    const tp = try arena.alloc(f64, n * k_in);
    const scales = try arena.alloc(f64, (blocks.len - 1) * k_in);
    const feat = try arena.alloc(f64, n);
    for (inputs, 0..) |in, m| {
        const p = d.p[m * n ..][0..n];
        try models.append(arena, .{ .name = in.name, .p = p });
        for (feat, p) |*f, q| f.* = logit(q);
        try forward(gpa, d, feat, 1, false, 0, tp[m * n ..][0..n], scales[m * (blocks.len - 1) ..][0..(blocks.len - 1)]);
        try models.append(arena, .{ .name = try std.fmt.allocPrint(arena, "{s}, temperature", .{in.name}), .p = tp[m * n ..][0..n] });
    }

    const avg = try arena.alloc(f64, n);
    for (avg, 0..) |*a, i| {
        var s: f64 = 0;
        for (0..k_in) |m| s += d.p[m * n + i];
        a.* = s / @as(f64, @floatFromInt(k_in));
    }
    try models.append(arena, .{ .name = "average of chances", .p = avg });

    const k = k_in + 1;
    const xs = try arena.alloc(f64, n * k);
    for (0..n) |i| {
        for (0..k_in) |m| xs[i * k + m] = logit(d.p[m * n + i]);
        xs[i * k + k_in] = 1;
    }
    const st = try arena.alloc(f64, n);
    const sw = try arena.alloc(f64, (blocks.len - 1) * k);
    try forward(gpa, d, xs, k, true, l2, st, sw);
    try models.append(arena, .{ .name = "stacker", .p = st });
    const trees = try arena.alloc(f64, n);
    const tree_counts = try arena.alloc(usize, blocks.len - 1);
    try forwardTrees(gpa, arena, d, refs[0], .{ .names = &.{}, .x = &.{} }, trees, tree_counts);
    try models.append(arena, .{ .name = "trees on the logits", .p = trees });
    const tree_counts2 = try arena.alloc(usize, blocks.len - 1);
    if (teams.names.len > 0) {
        const trees2 = try arena.alloc(f64, n);
        try forwardTrees(gpa, arena, d, refs[0], teams, trees2, tree_counts2);
        try models.append(arena, .{ .name = "trees on the logits and team profiles", .p = trees2 });
    }

    for (refs) |r| {
        try w.print("\nCells: log loss (minus {s}'s, 95% paired by game); negative is better. Folds: better than {s} in k of the folds scored.\n\n", .{ inputs[r].name, inputs[r].name });
        try w.writeAll("| model | folds 1-5 | folds 2-5 | dev-val | folds better |\n| --- | --- | --- | --- | --- |\n");
        for (models.items) |m| try tableRow(w, d, m, d.p[r * n ..][0..n]);
    }

    try w.writeAll("\nTemperature (scale on the logit; under 1 = the input was overconfident), fitted for:\n\n| model | 2 | 3 | 4 | 5 | dev |\n| --- | --- | --- | --- | --- | --- |\n");
    for (inputs, 0..) |in, m| {
        try w.print("| {s} |", .{in.name});
        for (scales[m * (blocks.len - 1) ..][0..(blocks.len - 1)]) |s| try w.print(" {d:.3} |", .{s});
        try w.writeAll("\n");
    }
    try w.writeAll("\nStacker weights on the logits (last: intercept), fitted for:\n\n| block |");
    for (inputs) |in| try w.print(" {s} |", .{in.name});
    try w.writeAll(" intercept |\n|");
    for (0..k + 1) |_| try w.writeAll(" --- |");
    try w.writeAll("\n");
    for (blocks[1..], 0..) |b, t| {
        try w.print("| {s} |", .{b});
        for (sw[t * k ..][0..k]) |s| try w.print(" {d:.3} |", .{s});
        try w.writeAll("\n");
    }

    try w.print("\nTrees kept (early stopping on the newest fit fold; fold 2 on every fifth game of fold 1), logits only: {any}", .{tree_counts});
    if (teams.names.len > 0) try w.print("; with team profiles ({d} per team): {any}", .{ teams.names.len, tree_counts2 });
    try w.writeAll("\n");

    try calibration(w, d, inputs, tp);

    if (out) |path| {
        var file = try Io.Dir.cwd().createFile(io, path, .{});
        defer file.close(io);
        var fbuf: [64 * 1024]u8 = undefined;
        var fw = file.writer(io, &fbuf);
        const o = &fw.interface;
        try o.writeAll("block\ty");
        for (inputs) |in| try o.print("\t{s}\t{s}_t", .{ in.name, in.name });
        try o.writeAll("\tavg\tstack\n");
        for (0..n) |i| {
            try o.print("{s}\t{d}", .{ blocks[d.block[i]], d.y[i] });
            for (0..k_in) |m| try o.print("\t{d:.6}\t{d:.6}", .{ d.p[m * n + i], tp[m * n + i] });
            try o.print("\t{d:.6}\t{d:.6}\n", .{ avg[i], st[i] });
        }
        try o.flush();
    }
}

/// Observed blue win share by predicted chance, raw and after temperature, over folds 2-5
/// and dev-val (where temperature exists); ± is a binomial 95% interval
fn calibration(w: *Io.Writer, d: *const Data, inputs: []const Input, tp: []const f64) !void {
    const edges = [_]f64{ 0.40, 0.45, 0.48, 0.50, 0.52, 0.55, 0.60 };
    const n_bins = edges.len + 1;
    const n = d.n;
    try w.writeAll("\nCalibration, folds 2-5 and dev-val pooled: games, mean chance raw / after temperature, observed (bins by the raw chance)\n\n| model | bin | games | raw | temperature | observed |\n| --- | --- | --- | --- | --- | --- |\n");
    for (inputs, 0..) |in, m| {
        var cnt: [n_bins]f64 = @splat(0);
        var raw: [n_bins]f64 = @splat(0);
        var tem: [n_bins]f64 = @splat(0);
        var obs: [n_bins]f64 = @splat(0);
        for (0..n) |i| {
            if (d.block[i] == 0) continue;
            const p = d.p[m * n + i];
            var bin: usize = 0;
            while (bin < edges.len and p >= edges[bin]) bin += 1;
            cnt[bin] += 1;
            raw[bin] += p;
            tem[bin] += tp[m * n + i];
            obs[bin] += d.y[i];
        }
        for (0..n_bins) |b| {
            if (cnt[b] == 0) continue;
            const o = obs[b] / cnt[b];
            const lo = if (b == 0) 0 else edges[b - 1];
            const hi = if (b == edges.len) 1 else edges[b];
            try w.print("| {s} | {d:.2}-{d:.2} | {d} | {d:.1}% | {d:.1}% | {d:.1}% ± {d:.1} |\n", .{
                in.name,               lo,                    hi,      cnt[b],
                100 * raw[b] / cnt[b], 100 * tem[b] / cnt[b], 100 * o, 196 * @sqrt(o * (1 - o) / cnt[b]),
            });
        }
    }
}

test "fitLogistic finds a known scale" {
    const gpa = std.testing.allocator;
    var x: [4000]f64 = undefined;
    var y: [4000]f64 = undefined;
    var prng = std.Random.DefaultPrng.init(7);
    const rnd = prng.random();
    for (&x, &y) |*a, *b| {
        a.* = rnd.floatNorm(f64);
        b.* = if (rnd.float(f64) < sigmoid(0.5 * a.*)) 1 else 0;
    }
    const w = try fitLogistic(gpa, &x, &y, 1, false, 0);
    defer gpa.free(w);
    try std.testing.expectApproxEqAbs(0.5, w[0], 0.1);
}

test "fitted rows learn only from earlier blocks" {
    for (0..blocks.len) |t| for (0..blocks.len) |b| {
        if (fitsOn(@intCast(t), @intCast(b))) {
            try std.testing.expect(b < t and b != 5);
        }
    };
    try std.testing.expect(!fitsOn(0, 0));
}

test {
    _ = gbdt;
}
