//! Random-search sweeps for deploy/lab-sweep.sh (docs/lab-run.md "Sweeps").
//!
//! SPACE: one flag per line, `--name DIST ARGS`; # comments. DIST: choice V..., uniform
//! LO HI, loguniform LO HI, int LO HI, logint LO HI. Values reach a shell on the gpu-box,
//! so only letters, digits and . , + - _. `ref --name V ...` (every flag) adds a
//! reference trial, `ref`, run first: shown in the table, never ranked, so never the pick.
//!
//! table and verdict read `TRIAL<tab>LINE` for each line of each trial's folds.tsv
//! (header included), as lab-sweep.sh fetches them. folds.tsv (meiolol-f1's netcheck):
//! seed fold fit_games scored_games logloss ratings_logloss gain gain_se epochs seconds
//! val_logloss auc; fold 1..5 (forward folds) or dev; gain = reference - net in nats per
//! game, the reference being ratings (netcheck) or the -Dcand candidate (playernet:
//! cand_logloss). Trials are ranked by val_logloss (inner validation on fit games), never
//! by the fold gain: picking on the scored blocks would be selection on them (meiolol-f1).
//!
//! Output is byte for byte deploy/lab-sweep.pl's, which this replaced (perl.zig).

const std = @import("std");
const perl = @import("perl.zig");
const Writer = std.Io.Writer;
const Allocator = std.mem.Allocator;

pub const usage =
    \\  lab-sweep   random-search sweeps for deploy/lab-sweep.sh (src/labtools/sweep.zig)
    \\              sample SPACE TRIALS RNG   trials.tsv: trial, then the sampled flags
    \\              table TRIALS_TSV          markdown table from the trials' folds.tsv
    \\                                        on stdin
    \\              verdict TRIALS_TSV K      the stopping rule on finished trials'
    \\                                        folds: `stop ...` when K or more are scored
    \\                                        and every one loses by over 2 se, `pass ...`
    \\                                        when K are scored and one doesn't, else
    \\                                        `wait`
    \\
;

/// `lab-sweep MODE ARGS...`; table and verdict read folds on `in`. Exit code: 1 with
/// the reason on `err` for a bad SPACE or unreadable file, 2 on bad usage
pub fn main(arena: Allocator, io: std.Io, args: []const []const u8, in: *std.Io.Reader, out: *Writer, err: *Writer) !u8 {
    const mode = if (args.len > 0) args[0] else "";
    if (std.mem.eql(u8, mode, "sample") and args.len == 4) {
        if (!allDigits(args[2])) return fail(err, "TRIALS: a number\n", .{});
        if (!allDigits(args[3])) return fail(err, "RNG: a number\n", .{});
        const text = readFile(arena, io, args[1]) catch |e| return fail(err, "{s}: {s}\n", .{ args[1], errText(e) });
        return sample(arena, text, args[1], parseCount(args[2]), parseCount(args[3]), out, err);
    }
    if (std.mem.eql(u8, mode, "table") and args.len == 2) {
        const text = readFile(arena, io, args[1]) catch |e| return fail(err, "{s}: {s}\n", .{ args[1], errText(e) });
        const s = try summarise(arena, text, try in.allocRemaining(arena, .unlimited));
        try table(arena, s, out);
        return 0;
    }
    if (std.mem.eql(u8, mode, "verdict") and args.len == 3) {
        const k = args[2];
        if (k.len == 0 or k[0] == '0' or !allDigits(k)) return fail(err, "K: a number\n", .{});
        const text = readFile(arena, io, args[1]) catch |e| return fail(err, "{s}: {s}\n", .{ args[1], errText(e) });
        const s = try summarise(arena, text, try in.allocRemaining(arena, .unlimited));
        try verdict(s, k, out);
        return 0;
    }
    try err.writeAll("usage: meiolol lab-sweep sample SPACE TRIALS RNG | table TRIALS_TSV | verdict TRIALS_TSV K\n");
    return 2;
}

fn fail(err: *Writer, comptime f: []const u8, args: anytype) !u8 {
    try err.print(f, args);
    return 1;
}

fn readFile(arena: Allocator, io: std.Io, path: []const u8) std.Io.Dir.ReadFileAllocError![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 30));
}

/// Perl's $! for the usual cases
fn errText(e: std.Io.Dir.ReadFileAllocError) []const u8 {
    return switch (e) {
        error.FileNotFound => "No such file or directory",
        error.AccessDenied => "Permission denied",
        error.IsDir => "Is a directory",
        else => @errorName(e),
    };
}

/// A decimal count as Perl reads it: past u64, the largest
fn parseCount(s: []const u8) u64 {
    return std.fmt.parseInt(u64, s, 10) catch std.math.maxInt(u64);
}

const Dist = enum { choice, uniform, loguniform, int, logint };

const Dim = struct {
    flag: []const u8,
    dist: Dist,
    args: []const []const u8,
};

/// trials.tsv for N trials drawn from SPACE with srand(RNG), as lab-sweep.pl wrote it
fn sample(arena: Allocator, text: []const u8, space: []const u8, n: u64, rng: u64, out: *Writer, err: *Writer) !u8 {
    var dims: std.ArrayList(Dim) = .empty;
    var ref: ?[]const []const u8 = null;
    var lines = Lines{ .text = text };
    var no: usize = 0;
    while (lines.next()) |raw| {
        no += 1;
        const line = raw[0 .. std.mem.findScalar(u8, raw, '#') orelse raw.len];
        const w = try perl.words(arena, line);
        if (w.len == 0) continue;
        const flag = w[0];
        if (eql(flag, "ref")) {
            if (ref != null) return fail(err, "{s}:{d}: one ref line\n", .{ space, no });
            ref = w[1..];
            if (w.len == 1 or (w.len - 1) % 2 == 1) return fail(err, "{s}:{d}: ref --name V ...\n", .{ space, no });
            for (w[1..]) |v| if (!valueOk(v)) return fail(err, "{s}:{d}: values: letters, digits . , + - _\n", .{ space, no });
            continue;
        }
        const dist_name = if (w.len > 1) w[1] else "";
        if (!flagOk(flag) or !perl.truthy(dist_name)) return fail(err, "{s}:{d}: --name DIST ARGS\n", .{ space, no });
        const a = w[2..];
        for (a) |v| if (!valueOk(v)) return fail(err, "{s}:{d}: values: letters, digits . , + - _\n", .{ space, no });
        const dist = std.meta.stringToEnum(Dist, dist_name) orelse return fail(err, "{s}:{d}: unknown DIST {s}\n", .{ space, no, dist_name });
        if (dist == .choice) {
            if (a.len == 0) return fail(err, "{s}:{d}: choice needs values\n", .{ space, no });
        } else {
            if (!(a.len == 2 and boundOk(a[0]) and boundOk(a[1]) and perl.num(a[0]) <= perl.num(a[1])))
                return fail(err, "{s}:{d}: {s} LO HI\n", .{ space, no, dist_name });
            if ((dist == .loguniform or dist == .logint) and perl.num(a[0]) <= 0)
                return fail(err, "{s}:{d}: {s} needs LO > 0\n", .{ space, no, dist_name });
        }
        try dims.append(arena, .{ .flag = flag, .dist = dist, .args = a });
    }
    if (dims.items.len == 0) return fail(err, "{s}: no flags\n", .{space});
    var rand = perl.Rand.init(rng);
    try out.writeAll("trial");
    for (dims.items) |d| try out.print("\t{s}", .{d.flag});
    try out.writeAll("\n");
    if (ref) |r| {
        // %v = @ref: a flag given twice keeps its last value
        var v: std.StringArrayHashMapUnmanaged([]const u8) = .empty;
        var i: usize = 0;
        while (i < r.len) : (i += 2) try v.put(arena, r[i], r[i + 1]);
        var missing: std.ArrayList(u8) = .empty;
        for (dims.items) |d| if (!v.contains(d.flag)) {
            if (missing.items.len > 0) try missing.append(arena, ' ');
            try missing.appendSlice(arena, d.flag);
        };
        if (missing.items.len > 0) return fail(err, "{s}: ref lacks {s}\n", .{ space, missing.items });
        if (v.count() > dims.items.len) return fail(err, "{s}: ref sets flags the space doesn't\n", .{space});
        try out.writeAll("ref");
        for (dims.items) |d| try out.print("\t{s}", .{v.get(d.flag).?});
        try out.writeAll("\n");
    }
    var t: u64 = 1;
    while (t <= n) : (t += 1) {
        try out.print("t{d:0>2}", .{t});
        for (dims.items) |d| {
            var b: [64]u8 = undefined;
            try out.print("\t{s}", .{draw(&b, d, rand.next())});
        }
        try out.writeAll("\n");
    }
    return 0;
}

fn draw(buf: []u8, d: Dim, u: f64) []const u8 {
    if (d.dist == .choice) {
        const n: f64 = @floatFromInt(d.args.len);
        return d.args[@trunc(u * n)];
    }
    const lo = perl.num(d.args[0]);
    const hi = perl.num(d.args[1]);
    return switch (d.dist) {
        .choice => unreachable,
        .uniform => perl.fmtFloat(buf, "%.4g", lo + u * (hi - lo)),
        .loguniform => perl.fmtFloat(buf, "%.4g", perl.e(perl.ln(lo) + u * (perl.ln(hi) - perl.ln(lo)))),
        .int => perl.intStr(buf, lo + u * (hi - lo + 1)),
        .logint => perl.intStr(buf, perl.e(perl.ln(lo) + u * (perl.ln(hi + 1) - perl.ln(lo)))),
    };
}

/// /^--[a-z][a-z0-9-]*$/
fn flagOk(s: []const u8) bool {
    if (s.len < 3 or !std.mem.startsWith(u8, s, "--") or !std.ascii.isLower(s[2])) return false;
    for (s[3..]) |c| if (!std.ascii.isLower(c) and !std.ascii.isDigit(c) and c != '-') return false;
    return true;
}

/// /^[A-Za-z0-9.,+_-]+$/
fn valueOk(s: []const u8) bool {
    if (s.len == 0) return false;
    for (s) |c| if (!std.ascii.isAlphanumeric(c) and std.mem.findScalar(u8, ".,+_-", c) == null) return false;
    return true;
}

/// /^[-+.\deE]+$/
fn boundOk(s: []const u8) bool {
    if (s.len == 0) return false;
    for (s) |c| if (!std.ascii.isDigit(c) and std.mem.findScalar(u8, "-+.eE", c) == null) return false;
    return true;
}

/// One folds.tsv line's fields, by the trial's last header; null where the line is short
const Row = struct {
    seed: ?[]const u8,
    fold: ?[]const u8,
    gain: ?[]const u8,
    gain_se: ?[]const u8,
    scored_games: ?[]const u8,
    epochs: ?[]const u8,
    seconds: ?[]const u8,
    val_logloss: ?[]const u8,
};

const columns = [_][]const u8{ "seed", "fold", "gain", "gain_se", "scored_games", "epochs", "seconds", "val_logloss" };

const Done = struct {
    t: []const u8,
    val: ?f64,
    gain: ?f64,
    se: ?f64,
    seed_sd: ?f64,
    seeds: usize,
    blocks: usize,
    dev: ?f64,
    epochs: ?[]const u8,
    secs: f64,
    better: usize,
    rows: usize,
    ens: ?f64,
};

const Summary = struct {
    /// trial -> its flags, "--a 1 --b 2"
    config: std.StringHashMapUnmanaged([]const u8),
    /// trials.tsv's order
    order: []const []const u8,
    rows: std.StringHashMapUnmanaged(std.ArrayList(Row)),
    done: []const Done,
};

/// Trials' order and configs from trials.tsv, and a summary per trial with folds
fn summarise(arena: Allocator, trials_tsv: []const u8, folds: []const u8) !Summary {
    var lines = Lines{ .text = trials_tsv };
    const head = try perl.split(arena, lines.next() orelse "", '\t');
    var config: std.StringHashMapUnmanaged([]const u8) = .empty;
    var order: std.ArrayList([]const u8) = .empty;
    while (lines.next()) |line| {
        const f = try perl.split(arena, line, '\t');
        const t = if (f.len > 0) f[0] else "";
        var c: std.ArrayList(u8) = .empty;
        for (f[@min(1, f.len)..], 1..) |v, i| {
            if (i > 1) try c.append(arena, ' ');
            try c.print(arena, "{s} {s}", .{ if (i < head.len) head[i] else "", v });
        }
        try config.put(arena, t, c.items);
        try order.append(arena, t);
    }

    // Per trial: its header's column of each field we read
    var cols: std.StringHashMapUnmanaged([columns.len]?usize) = .empty;
    var rows: std.StringHashMapUnmanaged(std.ArrayList(Row)) = .empty;
    var in = Lines{ .text = folds };
    while (in.next()) |l| {
        const tab = std.mem.findScalar(u8, l, '\t') orelse continue;
        const t = l[0..tab];
        const f = try perl.split(arena, l[tab + 1 ..], '\t');
        if (f.len > 0 and eql(f[0], "seed")) {
            var c: [columns.len]?usize = @splat(null);
            for (f, 0..) |name, i| for (columns, 0..) |want, j| {
                if (eql(name, want)) c[j] = i;
            };
            try cols.put(arena, t, c);
            continue;
        }
        const c = cols.get(t) orelse continue;
        var v: [columns.len]?[]const u8 = undefined;
        for (c, &v) |ci, *x| x.* = if (ci) |i| (if (i < f.len) f[i] else null) else null;
        const gop = try rows.getOrPut(arena, t);
        if (!gop.found_existing) gop.value_ptr.* = .empty;
        try gop.value_ptr.append(arena, .{ .seed = v[0], .fold = v[1], .gain = v[2], .gain_se = v[3], .scored_games = v[4], .epochs = v[5], .seconds = v[6], .val_logloss = v[7] });
    }

    var done: std.ArrayList(Done) = .empty;
    for (order.items) |t| {
        const rs = if (rows.get(t)) |l| l.items else continue;
        if (rs.len == 0) continue;
        var by_seed: std.StringArrayHashMapUnmanaged(std.ArrayList(Row)) = .empty;
        var dev: std.ArrayList(f64) = .empty;
        var val: std.ArrayList(f64) = .empty;
        var ep: std.ArrayList(?[]const u8) = .empty;
        var ens: std.ArrayList(Row) = .empty;
        var secs: f64 = 0;
        for (rs) |r| {
            // netcheck's seed ensemble: its own column, not another seed
            if (eql(r.seed orelse "", "ens")) {
                if (!eql(r.fold orelse "", "dev")) try ens.append(arena, r);
                continue;
            }
            if (r.val_logloss) |v| if (v.len > 0) try val.append(arena, perl.num(v));
            try ep.append(arena, r.epochs);
            secs += numOr0(r.seconds);
            if (eql(r.fold orelse "", "dev")) {
                try dev.append(arena, numOr0(r.gain));
            } else {
                const gop = try by_seed.getOrPut(arena, r.seed orelse "");
                if (!gop.found_existing) gop.value_ptr.* = .empty;
                try gop.value_ptr.append(arena, r);
            }
        }
        by_seed.sort(struct {
            keys: []const []const u8,
            pub fn lessThan(c: @This(), a: usize, b: usize) bool {
                return std.mem.lessThan(u8, c.keys[a], c.keys[b]);
            }
        }{ .keys = by_seed.keys() });
        // Per seed, the folds pooled by scored games; their se as independent blocks
        var g: std.ArrayList(f64) = .empty;
        var se: std.ArrayList(f64) = .empty;
        var blocks: std.StringHashMapUnmanaged(void) = .empty;
        for (by_seed.values()) |seed_rows| {
            var n: f64 = 0;
            var sum: f64 = 0;
            var v: f64 = 0;
            for (seed_rows.items) |r| {
                const sg = numOr0(r.scored_games);
                n += sg;
                sum += numOr0(r.gain) * sg;
                v += perl.power(numOr0(r.gain_se) * sg, 2);
                try blocks.put(arena, r.fold orelse "", {});
            }
            if (n == 0) continue;
            try g.append(arena, sum / n);
            try se.append(arena, @sqrt(v) / n);
        }
        // Fold sign consistency: folds where the mean over seeds favours the net
        var per_fold: std.StringArrayHashMapUnmanaged(std.ArrayList(f64)) = .empty;
        for (by_seed.values()) |seed_rows| for (seed_rows.items) |r| {
            const gop = try per_fold.getOrPut(arena, r.fold orelse "");
            if (!gop.found_existing) gop.value_ptr.* = .empty;
            try gop.value_ptr.append(arena, numOr0(r.gain));
        };
        var better: usize = 0;
        for (per_fold.values()) |gains| {
            if (mean(gains.items).? > 0) better += 1;
        }
        std.mem.sort(?[]const u8, ep.items, {}, struct {
            fn lt(_: void, a: ?[]const u8, b: ?[]const u8) bool {
                return numOr0(a) < numOr0(b);
            }
        }.lt);
        var en: f64 = 0;
        var esum: f64 = 0;
        for (ens.items) |r| {
            const sg = numOr0(r.scored_games);
            en += sg;
            esum += numOr0(r.gain) * sg;
        }
        try done.append(arena, .{
            .t = t,
            .val = mean(val.items),
            .gain = mean(g.items),
            .se = mean(se.items),
            .seed_sd = sd(g.items),
            .seeds = g.items.len,
            .blocks = blocks.count(),
            .dev = mean(dev.items),
            .epochs = if (ep.items.len > 0) ep.items[(ep.items.len - 1) / 2] else null,
            .secs = secs,
            .better = better,
            .rows = val.items.len,
            .ens = if (en != 0) esum / en else null,
        });
    }
    return .{ .config = config, .order = order.items, .rows = rows, .done = done.items };
}

fn numOr0(s: ?[]const u8) f64 {
    return perl.num(s orelse "");
}

fn mean(xs: []const f64) ?f64 {
    if (xs.len == 0) return null;
    var s: f64 = 0;
    for (xs) |x| s += x;
    return s / @as(f64, @floatFromInt(xs.len));
}

fn sd(xs: []const f64) ?f64 {
    const m = mean(xs) orelse return null;
    if (xs.len < 2) return null;
    var s: f64 = 0;
    for (xs) |x| s += perl.power(x - m, 2);
    return @sqrt(s / @as(f64, @floatFromInt(xs.len - 1)));
}

/// big1, big1b, big1c (17 Oct): 23 trials, every one behind ratings in 0 of 5 folds.
/// Losing = pooled fold gain below -2 se; ref is the bar, not counted
fn verdict(s: Summary, k: []const u8, out: *Writer) !void {
    var n: usize = 0;
    var lost: usize = 0;
    var best: ?Done = null;
    for (s.done) |d| {
        if (eql(d.t, "ref")) continue;
        const gain = d.gain orelse continue;
        const se = d.se orelse continue;
        n += 1;
        if (gain < -2 * se) lost += 1;
        if (best == null or gain > best.?.gain.?) best = d;
    }
    if (@as(f64, @floatFromInt(n)) < perl.num(k)) {
        try out.print("wait {d} of {s} scored\n", .{ n, k });
    } else if (lost == n) {
        var b1: [64]u8 = undefined;
        var b2: [64]u8 = undefined;
        try out.print("stop all {d} scored trials lose by > 2 se (best {s} {s} ± {s} mnats)\n", .{
            n, best.?.t, perl.fmtFloat(&b1, "%+.2f", 1000 * best.?.gain.?), perl.fmtFloat(&b2, "%.2f", 1000 * best.?.se.?),
        });
    } else try out.print("pass {d} of {d} scored trials within 2 se or better\n", .{ n - lost, n });
}

fn table(a: Allocator, s: Summary, out: *Writer) !void {
    try out.writeAll(
        \\Ranked by inner-validation log loss (fit games only). Gains vs the command's
        \\reference (netcheck: ratings; playernet: its -Dcand candidate) in milli-nats
        \\per game, positive = net better: folds pooled by games, mean over
        \\seeds ± its paired 95% half-width; better in = folds whose mean over seeds
        \\favours the net; seed sd = spread of the per-seed gain;
        \\ens = the seeds' averaged predictions (netcheck's ens rows), folds pooled.
        \\
    );
    var has_ref = false;
    for (s.done) |d| has_ref = has_ref or eql(d.t, "ref");
    if (has_ref) try out.writeAll("ref = SPACE's reference config: the bar, never ranked.\n");
    try out.writeAll("\n");
    try out.writeAll("| # | trial | val log loss | fold gain | better in | seed sd | ens gain | dev gain | seeds x blocks | epochs | GPU s | config |\n");
    for (0..12) |_| try out.writeAll("| --- ");
    try out.writeAll("|\n");
    // netcheck writes rows as it goes: fewer than the fullest trial = still running
    var full: usize = 0;
    for (s.done) |d| full = @max(full, d.rows);
    // The reference row first, unnumbered: it is the bar, not a candidate
    var ranked: std.ArrayList(Done) = .empty;
    for (s.done) |d| if (eql(d.t, "ref")) try ranked.append(a, d);
    const refs = ranked.items.len;
    for (s.done) |d| if (!eql(d.t, "ref")) try ranked.append(a, d);
    std.mem.sort(Done, ranked.items[refs..], {}, struct {
        fn lt(_: void, x: Done, y: Done) bool {
            return (x.val orelse 9) < (y.val orelse 9);
        }
    }.lt);
    var i: usize = 0;
    for (ranked.items) |d| {
        var bn: [16]u8 = undefined;
        var bv: [64]u8 = undefined;
        var bufs: [6][64]u8 = undefined;
        const is_ref = eql(d.t, "ref");
        if (!is_ref) i += 1;
        try out.print("| {s} | {s}{s} | {s} | {s} ± {s} | {d} of {d} | {s} | {s} | {s} | {d} x {d} | {s} | {s} | {s} |\n", .{
            if (is_ref) "ref" else std.mem.print(&bn, "{d}", .{i}) catch unreachable,
            d.t,
            if (d.rows < full) " (partial)" else "",
            if (d.val) |v| perl.fmtFloat(&bv, "%.5f", v) else "-",
            milli(&bufs[0], "%+.2f", d.gain),
            milli(&bufs[1], "%.2f", if (d.se) |x| 1.96 * x else null),
            d.better,
            d.blocks,
            milli(&bufs[2], "%.2f", d.seed_sd),
            milli(&bufs[3], "%+.2f", d.ens),
            milli(&bufs[4], "%+.2f", d.dev),
            d.seeds,
            d.blocks,
            d.epochs orelse "-",
            perl.fmtFloat(&bufs[5], "%.0f", d.secs),
            s.config.get(d.t) orelse "",
        });
    }
    var missing: std.ArrayList(u8) = .empty;
    for (s.order) |t| if (!s.rows.contains(t)) {
        try missing.appendSlice(a, if (missing.items.len == 0) "; none yet: " else " ");
        try missing.appendSlice(a, t);
    };
    try out.print("\n{d} of {d} trials scored{s}\n", .{ s.done.len, s.order.len, missing.items });
}

/// sprintf(SPEC, 1000 * x), "-" when x is null
fn milli(buf: []u8, comptime spec: [:0]const u8, x: ?f64) []const u8 {
    return if (x) |v| perl.fmtFloat(buf, spec, 1000 * v) else "-";
}

/// Perl's `<$f>`: lines without their "\n", none after a final one
const Lines = struct {
    text: []const u8,
    at: usize = 0,

    fn next(l: *Lines) ?[]const u8 {
        if (l.at >= l.text.len) return null;
        const end = std.mem.findScalarPos(u8, l.text, l.at, '\n') orelse l.text.len;
        defer l.at = end + 1;
        return l.text[l.at..end];
    }
};

fn eql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

fn allDigits(s: []const u8) bool {
    if (s.len == 0) return false;
    for (s) |c| if (!std.ascii.isDigit(c)) return false;
    return true;
}

const testing = std.testing;

fn sampled(arena: Allocator, space: []const u8, n: u64, rng: u64) !struct { u8, []const u8, []const u8 } {
    var out: Writer.Allocating = .init(arena);
    var err: Writer.Allocating = .init(arena);
    const code = try sample(arena, space, "space", n, rng, &out.writer, &err.writer);
    return .{ code, out.written(), err.written() };
}

test "sample draws what lab-sweep.pl drew for the same seed" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const space = @embedFile("../testdata/labtools/space");
    const want = @embedFile("../testdata/labtools/trials.tsv");
    const code, const out, _ = try sampled(a, space, 12, 1);
    try testing.expectEqual(@as(u8, 0), code);
    try testing.expectEqualStrings(want, out);
    // Perl's seed is a U32
    _, const wrapped, _ = try sampled(a, space, 12, (1 << 32) + 1);
    try testing.expectEqualStrings(want, wrapped);
}

test "sample refuses a bad SPACE line as lab-sweep.pl did" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const cases = [_][2][]const u8{
        .{ "--A int 1 2\n", "space:1: --name DIST ARGS\n" },
        .{ "# x\n--a 0 1 2\n", "space:2: --name DIST ARGS\n" },
        .{ "--a normal 0 1\n", "space:1: unknown DIST normal\n" },
        .{ "--a choice x;y\n", "space:1: values: letters, digits . , + - _\n" },
        .{ "--a uniform 2 1\n", "space:1: uniform LO HI\n" },
        .{ "--a loguniform 0 1\n", "space:1: loguniform needs LO > 0\n" },
        .{ "--a choice\n", "space:1: choice needs values\n" },
        .{ "ref --a\n--a int 1 2\n", "space:1: ref --name V ...\n" },
        .{ "ref --a 1\nref --a 2\n", "space:2: one ref line\n" },
        .{ "# nothing\n", "space: no flags\n" },
        .{ "--a int 1 9\n--b int 1 9\nref --a 1\n", "space: ref lacks --b\n" },
        .{ "--a int 1 9\nref --a 1 --z 2\n", "space: ref sets flags the space doesn't\n" },
    };
    for (cases) |c| {
        const code, _, const err = try sampled(a, c[0], 3, 1);
        try testing.expectEqual(@as(u8, 1), code);
        try testing.expectEqualStrings(c[1], err);
    }
}

test "table and verdict as lab-sweep.pl wrote them on recorded folds" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const trials = @embedFile("../testdata/labtools/trials.tsv");
    const folds = @embedFile("../testdata/labtools/folds.tsv");
    const s = try summarise(a, trials, folds);
    var out: Writer.Allocating = .init(a);
    try table(a, s, &out.writer);
    try testing.expectEqualStrings(@embedFile("../testdata/labtools/table.md"), out.written());
    const lose = try summarise(a, trials, @embedFile("../testdata/labtools/folds-lose.tsv"));
    var lines = std.mem.splitScalar(u8, @embedFile("../testdata/labtools/verdicts.txt"), '\n');
    while (lines.next()) |l| {
        if (l.len == 0) continue;
        const tab = std.mem.findScalar(u8, l, '\t').?;
        const k = l[0..tab];
        var v: Writer.Allocating = .init(a);
        if (std.mem.startsWith(u8, k, "lose ")) try verdict(lose, k[5..], &v.writer) else try verdict(s, k, &v.writer);
        try testing.expectEqualStrings(l[tab + 1 ..], std.mem.trimEnd(u8, v.written(), "\n"));
    }
}
