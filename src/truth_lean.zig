//! The lean table (docs/plan/meio-middle.md NL0, the M10 gate): does Meio's middle run
//! high or low over a group of cells? Lean = the later rate minus Meio's middle, target
//! games weighted (sum (k - n p) / sum n), in points (gold at 14: gold). Groups: kind x
//! region x rank set, then all cells, popularity band, Meio's own games, the gem check
//! and day bucket. se over day origins (one origin's cells share a fit, so aren't
//! independent; overlapping horizons make it a floor); under 4 origins (day buckets
//! 0-3) over cells. A group fails beyond 2 se and over a floor; with ~2,500 groups
//! some fail by chance, so the gate also counts how many would (Student t over origins)
//! and fails when the count is beyond that
//!
//! Also the per-cell dump (`truth --cells`): every Meio-estimated cell of the chosen
//! kinds at every origin, so each analysis reads the same cells

const std = @import("std");
const truth = @import("truth.zig");

const Kind = truth.Kind;
const Allocator = std.mem.Allocator;

/// Sums over cells or origin blocks of r = k - n p and n, for a ratio mean and its se
pub const Moments = struct {
    count: f64 = 0,
    r: f64 = 0,
    n: f64 = 0,
    rr: f64 = 0,
    rn: f64 = 0,
    nn: f64 = 0,

    fn add(m: *Moments, o: Moments) void {
        m.count += o.count;
        m.r += o.r;
        m.n += o.n;
        m.rr += o.rr;
        m.rn += o.rn;
        m.nn += o.nn;
    }

    fn one(m: *Moments, r: f64, n: f64) void {
        m.add(.{ .count = 1, .r = r, .n = n, .rr = r * r, .rn = r * n, .nn = n * n });
    }

    /// The ratio mean's variance: sum (r_i - mean n_i)^2 / N^2, small-sample corrected
    fn variance(m: Moments, mean: f64) f64 {
        if (m.count < 2 or m.n == 0) return std.math.inf(f64);
        const ss = m.rr - 2 * mean * m.rn + mean * mean * m.nn;
        return @max(0, ss) / (m.n * m.n) * m.count / (m.count - 1);
    }
};

/// Origins needed for the se over origins; fewer: over cells
const min_blocks = 4;

pub const Group = struct {
    cells: Moments = .{},
    /// One entry per origin, from `block`
    blocks: Moments = .{},

    fn add(g: *Group, o: Group) void {
        g.cells.add(o.cells);
        g.blocks.add(o.blocks);
    }

    /// Folds one origin's cells into one block
    fn block(g: *Group) void {
        std.debug.assert(g.blocks.count == 0);
        if (g.cells.count > 0) g.blocks.one(g.cells.r, g.cells.n);
    }

    pub fn mean(g: Group) ?f64 {
        return if (g.cells.n > 0) g.cells.r / g.cells.n else null;
    }

    /// The mean's se and its t's degrees of freedom (0: normal, se over cells)
    pub fn se(g: Group) ?struct { se: f64, df: f64 } {
        const m = g.mean() orelse return null;
        const by_blocks = g.blocks.count >= min_blocks;
        const v = if (by_blocks) g.blocks.variance(m) else g.cells.variance(m);
        if (!std.math.isFinite(v)) return null;
        return .{ .se = @sqrt(v), .df = if (by_blocks) g.blocks.count - 1 else 0 };
    }
};

/// Popularity bands of x = log((games + 0.5) / (parent games + 1)), the cell's own
/// region, rank set and 30-day window; fixed edges 1 log unit wide (deciles would put
/// most bands in the rare tail). Champion-roles out of their role's games, every other
/// kind out of its champion-role's
pub const pop_bands = 10;
pub const pop_labels: [2][pop_bands][]const u8 = .{
    .{ "> -3", "-3..-4", "-4..-5", "-5..-6", "-6..-7", "-7..-8", "-8..-9", "-9..-10", "-10..-11", "< -11" },
    .{ "> -0.5", "-0.5..-1", "-1..-2", "-2..-3", "-3..-4", "-4..-5", "-5..-6", "-6..-7", "-7..-8", "< -8" },
};
/// The gem check's bands: the rarest
const gem_from = pop_bands - 3;

pub fn popBand(kind: Kind, x: f64) usize {
    if (kind == .champion) return @intFromFloat(std.math.clamp(@floor(-x) - 2, 0, pop_bands - 1));
    if (x > -0.5) return 0;
    if (x > -1) return 1;
    return @intFromFloat(std.math.clamp(@floor(-x) + 1, 2, pop_bands - 1));
}

/// Meio's own games (newest patch, the cell's region and rank set)
pub const own_labels = [_][]const u8{ "own 0", "own 1-9", "own 10-99", "own 100-999", "own 1000+" };

fn ownBand(own: f64) usize {
    if (!(own >= 1)) return 0;
    return @min(own_labels.len - 1, 1 + @as(usize, @intFromFloat(@log10(own))));
}

/// The rarest bands' cells by their raw 30-day number against Meio's middle: selected on
/// past games only, so an honest middle leans on neither side; over-shrinking shows as
/// the cells above (gems) winning more later
pub const gem_labels = [_][]const u8{ "rare, raw above", "rare, raw below", "rare, unseen" };

pub const Lean = struct {
    all: Group = .{},
    pop: [pop_bands]Group = @splat(.{}),
    own: [own_labels.len]Group = @splat(.{}),
    gem: [gem_labels.len]Group = @splat(.{}),

    pub fn add(l: *Lean, o: Lean) void {
        l.all.add(o.all);
        for (&l.pop, o.pop) |*a, b| a.add(b);
        for (&l.own, o.own) |*a, b| a.add(b);
        for (&l.gem, o.gem) |*a, b| a.add(b);
    }

    /// One origin's Lean: each group's cells as one block
    pub fn block(l: *Lean) void {
        l.all.block();
        for (&l.pop) |*g| g.block();
        for (&l.own) |*g| g.block();
        for (&l.gem) |*g| g.block();
    }

    /// k of n target games (gold: their sum) against Meio's p; x the popularity, raw
    /// the 30-day number (null: no games)
    pub fn cell(l: *Lean, kind: Kind, c: Cell) void {
        const r = c.k - c.n * c.p;
        const band = popBand(kind, c.x);
        l.all.cells.one(r, c.n);
        l.pop[band].cells.one(r, c.n);
        l.own[ownBand(c.own)].cells.one(r, c.n);
        if (band >= gem_from) {
            const side: usize = if (c.raw) |raw| (if (raw > c.p) 0 else 1) else 2;
            l.gem[side].cells.one(r, c.n);
        }
    }
};

pub const Cell = struct { n: f64, k: f64, p: f64, x: f64, own: f64, raw: ?f64 };

/// The gate's floors: a lean under them is harmless however sure (Jacob's call)
pub const Floors = struct { points: f64 = 0.5, gold: f64 = 25 };

/// Points or gold per unit of a kind's lean
fn scale(kind: Kind) f64 {
    return if (kind == .gold14) 1 else 100;
}

fn floorOf(kind: Kind, f: Floors) f64 {
    return if (kind == .gold14) f.gold else f.points;
}

pub const Family = enum { all, pop, own, gem, day };

/// One group as judged
pub const Judged = struct {
    region: usize,
    kind: Kind,
    bracket: usize,
    family: Family,
    index: usize,
    cells: f64,
    games: f64,
    /// Points or gold
    lean: f64,
    se: f64,
    df: f64,
    fails: bool,
    /// Chance it fails with no lean at all: P(|T| > max(2, floor / se))
    chance: f64,

    pub fn name(j: Judged) []const u8 {
        return switch (j.family) {
            .all => "all cells",
            .pop => pop_labels[@intFromBool(j.kind != .champion)][j.index],
            .own => own_labels[j.index],
            .gem => gem_labels[j.index],
            .day => truth.buckets[j.index],
        };
    }

    fn of(region: usize, kind: Kind, bracket: usize, family: Family, index: usize, g: Group, floors: Floors) ?Judged {
        const m = g.mean() orelse return null;
        const s = g.se() orelse return null;
        const k = scale(kind);
        const lean = k * m;
        const se = k * s.se;
        const floor = floorOf(kind, floors);
        const crit = if (se > 0) @max(2, floor / se) else std.math.inf(f64);
        return .{
            .region = region,
            .kind = kind,
            .bracket = bracket,
            .family = family,
            .index = index,
            .cells = g.cells.count,
            .games = g.cells.n,
            .lean = lean,
            .se = se,
            .df = s.df,
            .fails = @abs(lean) > 2 * se and @abs(lean) > floor,
            .chance = twoTail(crit, s.df),
        };
    }

    fn z(j: Judged) f64 {
        return if (j.se > 0) @abs(j.lean) / j.se else 0;
    }
};

/// Groups per region, kind and rank set
const per_set = 1 + pop_bands + own_labels.len + gem_labels.len + truth.buckets.len;
pub const max_judged = truth.regions.len * Kind.count * truth.brackets.len * per_set;

/// Every group with a mean and se, into `out` (max_judged long)
pub fn judge(results: *const truth.Results, floors: Floors, out: []Judged) []Judged {
    var n: usize = 0;
    for (results, 0..) |by_kind, region| for (by_kind, 0..) |by_bracket, k| {
        const kind: Kind = @fromBackingInt(@intCast(k));
        for (by_bracket, 0..) |by_bucket, bracket| {
            var days: Lean = .{};
            for (by_bucket) |s| days.add(s.lean);
            const Put = struct {
                out: []Judged,
                n: *usize,
                region: usize,
                kind: Kind,
                bracket: usize,
                floors: Floors,
                fn put(p: @This(), family: Family, index: usize, g: Group) void {
                    const j = Judged.of(p.region, p.kind, p.bracket, family, index, g, p.floors) orelse return;
                    p.out[p.n.*] = j;
                    p.n.* += 1;
                }
            };
            const p: Put = .{ .out = out, .n = &n, .region = region, .kind = kind, .bracket = bracket, .floors = floors };
            p.put(.all, 0, days.all);
            for (days.pop, 0..) |g, i| p.put(.pop, i, g);
            for (days.own, 0..) |g, i| p.put(.own, i, g);
            for (days.gem, 0..) |g, i| p.put(.gem, i, g);
            for (by_bucket, 0..) |s, i| p.put(.day, i, s.lean.all);
        }
    };
    return out[0..n];
}

/// Failing groups against the count expected by chance; beyond chance past expected +
/// 2 sqrt(expected) (Poisson; nested groups make failures cluster, so read it loosely)
pub const Gate = struct {
    judged: usize = 0,
    failing: usize = 0,
    expected: f64 = 0,

    pub fn of(list: []const Judged) Gate {
        var g: Gate = .{};
        for (list) |j| {
            g.judged += 1;
            g.failing += @intFromBool(j.fails);
            g.expected += j.chance;
        }
        return g;
    }

    pub fn limit(g: Gate) f64 {
        return g.expected + 2 * @sqrt(g.expected);
    }

    pub fn beyondChance(g: Gate) bool {
        return @as(f64, @floatFromInt(g.failing)) > g.limit();
    }
};

/// P(|T| > x), T Student t with df degrees of freedom (0: normal)
pub fn twoTail(x: f64, df: f64) f64 {
    if (!std.math.isFinite(x)) return 0;
    if (df == 0) return 2 * (1 - truth.normCdf(x));
    const lg = std.math.lgamma;
    const c = @exp(lg(f64, (df + 1) / 2) - lg(f64, df / 2)) / @sqrt(df * std.math.pi);
    // Simpson on [0, x]
    const steps = 2000;
    const h = x / steps;
    var sum: f64 = 0;
    for (0..steps + 1) |i| {
        const t = h * @as(f64, @floatFromInt(i));
        const w: f64 = if (i == 0 or i == steps) 1 else if (i % 2 == 1) 4 else 2;
        sum += w * std.math.pow(f64, 1 + t * t / df, -(df + 1) / 2);
    }
    return @max(0, 1 - 2 * c * sum * h / 3);
}

/// Failing rows listed in the report, the surest first; every group is in --lean
const listed = 60;

pub fn report(gpa: Allocator, results: *const truth.Results, floors: Floors, out: *std.Io.Writer) !void {
    const buf = try gpa.alloc(Judged, max_judged);
    defer gpa.free(buf);
    const list = judge(results, floors, buf);
    const gate = Gate.of(list);
    try out.print("\n## Lean (the M10 gate)\n\nLater rate minus Meio's middle, in points (gold " ++
        "at 14: gold), target games weighted; +- 2 se over day origins (day buckets 0-3: over " ++
        "cells). A group fails beyond 2 se and over {d} points ({d} gold). Groups per " ++
        "kind, region and rank set: all cells, popularity band (log share of the parent's " ++
        "games in the cell's region, rank set and 30 days: champion-roles of their role, the " ++
        "rest of their champion-role), Meio's own games, the gem check (the 3 rarest bands by " ++
        "raw 30 days above or below Meio's middle) and day bucket. Chance: failures expected " ++
        "with no lean anywhere (Student t over origins); the gate fails beyond expected + 2 " ++
        "sqrt(expected)\n\n**Gate: {s}.** {d} groups judged, {d} failing, {d:.1} expected by " ++
        "chance (limit {d:.1})\n", .{
        floors.points, floors.gold,  if (gate.beyondChance()) "FAILS beyond chance" else "passes",
        gate.judged,   gate.failing, gate.expected,
        gate.limit(),
    });
    for ([_]bool{ false, true }) |shares| try bandTable(out, list, shares);
    try summary(out, list);
    try failing(gpa, out, list);
}

/// Every region, all ranks, every day: lean per popularity band (* fails)
fn bandTable(out: *std.Io.Writer, list: []const Judged, conditional: bool) !void {
    try out.print("\n### Lean by popularity, every region, all ranks: {s}\n\n| cell |", .{if (conditional) "locks (x of the champion-role's games)" else "champion-role (x of the role's games)"});
    for (pop_labels[@intFromBool(conditional)]) |b| try out.print(" {s} |", .{b});
    try out.writeAll("\n| --- |");
    for (0..pop_bands) |_| try out.writeAll(" --: |");
    try out.writeAll("\n");
    for (0..Kind.count) |k| {
        const kind: Kind = @fromBackingInt(@intCast(k));
        if ((kind != .champion) != conditional) continue;
        var cols: [pop_bands]?Judged = @splat(null);
        var any = false;
        for (list) |j| if (j.region == 0 and j.bracket == 0 and j.kind == kind and j.family == .pop) {
            cols[j.index] = j;
            any = true;
        };
        if (!any) continue;
        try out.print("| {s} |", .{truth.label(kind)});
        for (cols) |c| {
            if (c) |j| try out.print(" {d:.2}{s} |", .{ j.lean, if (j.fails) "*" else "" }) else try out.writeAll(" |");
        }
        try out.writeAll("\n");
    }
}

/// Per kind and region: groups, failing, expected by chance, the surest failure
fn summary(out: *std.Io.Writer, list: []const Judged) !void {
    try out.writeAll("\n### Lean by kind\n\n| cell | region | groups | failing | chance | surest failure |\n" ++
        "| --- | --- | --: | --: | --: | --- |\n");
    for (0..Kind.count) |k| for (truth.regions, 0..) |region, ri| {
        const kind: Kind = @fromBackingInt(@intCast(k));
        var g: Gate = .{};
        var worst: ?Judged = null;
        for (list) |j| if (j.kind == kind and j.region == ri) {
            g.judged += 1;
            g.expected += j.chance;
            if (!j.fails) continue;
            g.failing += 1;
            if (worst == null or j.z() > worst.?.z()) worst = j;
        };
        if (g.judged == 0) continue;
        try out.print("| {s} | {s} | {d} | {d} | {d:.1} |", .{ truth.label(kind), region, g.judged, g.failing, g.expected });
        if (worst) |w| try out.print(" {s}, {s}: {d:.2} +- {d:.2} |\n", .{ truth.brackets[w.bracket], w.name(), w.lean, 2 * w.se }) else try out.writeAll(" |\n");
    };
}

fn failing(gpa: Allocator, out: *std.Io.Writer, list: []const Judged) !void {
    var fails: std.ArrayList(Judged) = .empty;
    defer fails.deinit(gpa);
    for (list) |j| if (j.fails) try fails.append(gpa, j);
    std.mem.sortUnstable(Judged, fails.items, {}, struct {
        fn less(_: void, a: Judged, b: Judged) bool {
            return a.z() > b.z();
        }
    }.less);
    try out.print("\n### Failing groups ({d}; the surest {d} here, every group in --lean)\n\n" ++
        "| cell | region | ranks | group | cells | games | lean | +- 2 se |\n" ++
        "| --- | --- | --- | --- | --: | --: | --: | --: |\n", .{ fails.items.len, @min(listed, fails.items.len) });
    for (fails.items[0..@min(listed, fails.items.len)]) |j| {
        try out.print("| {s} | {s} | {s} | {s} | {d:.0} | {d:.0} | {d:.2} | {d:.2} |\n", .{
            truth.label(j.kind), truth.regions[j.region], truth.brackets[j.bracket], j.name(), j.cells, j.games, j.lean, 2 * j.se,
        });
    }
}

/// Every judged group, one line each
pub fn writeTsv(gpa: Allocator, results: *const truth.Results, floors: Floors, patch: []const u8, out: *std.Io.Writer) !void {
    const buf = try gpa.alloc(Judged, max_judged);
    defer gpa.free(buf);
    try out.writeAll("patch\tregion\tkind\tbracket\tfamily\tgroup\tcells\tgames\tlean\tse\tdf\tfails\tchance\n");
    for (judge(results, floors, buf)) |j| {
        try out.print("{s}\t{s}\t{t}\t{s}\t{t}\t{s}\t{d}\t{d}\t{d:.4}\t{d:.4}\t{d}\t{d}\t{d:.5}\n", .{
            patch, truth.regions[j.region], j.kind, truth.brackets[j.bracket], j.family, j.name(), j.cells, j.games, j.lean, j.se, j.df, @intFromBool(j.fails), j.chance,
        });
    }
}

/// `truth --cells`: one line per Meio-estimated cell of `kinds` per origin, single
/// brackets only (not the masked set). Each origin buffers and appends under the lock
pub const Dump = struct {
    io: std.Io,
    out: *std.Io.Writer,
    kinds: std.EnumSet(Kind),
    lock: std.Io.Mutex = .init,

    pub const header = "origin\tkind\tregion\tbracket\ta\tb\tx\tp\tlo\thi\town\ttarget_n\ttarget_k\t" ++
        "w30_n\tw30_k\tpatch_n\tpatch_k\tpit\n";

    /// Kinds by name, comma separated
    pub fn parseKinds(s: []const u8) ?std.EnumSet(Kind) {
        var set: std.EnumSet(Kind) = .empty;
        var it = std.mem.tokenizeScalar(u8, s, ',');
        while (it.next()) |name| set.insert(std.meta.stringToEnum(Kind, name) orelse return null);
        return set;
    }

    pub const default_kinds: []const u8 = "champion,keystone,item,rune,build";

    pub fn flush(d: *Dump, buf: *std.ArrayList(u8)) !void {
        if (buf.items.len == 0) return;
        d.lock.lockUncancelable(d.io);
        defer d.lock.unlock(d.io);
        try d.out.writeAll(buf.items);
        buf.clearRetainingCapacity();
    }
};

test "popularity bands: fixed edges, champion-roles of the role, locks of the champion-role" {
    try std.testing.expectEqual(@as(usize, 0), popBand(.champion, -2.5));
    try std.testing.expectEqual(@as(usize, 1), popBand(.champion, -3.5));
    try std.testing.expectEqual(@as(usize, 8), popBand(.champion, -10.5));
    try std.testing.expectEqual(@as(usize, 9), popBand(.champion, -14));
    try std.testing.expectEqual(@as(usize, 0), popBand(.keystone, -0.2));
    try std.testing.expectEqual(@as(usize, 1), popBand(.keystone, -0.7));
    try std.testing.expectEqual(@as(usize, 2), popBand(.keystone, -1));
    try std.testing.expectEqual(@as(usize, 8), popBand(.item, -7.5));
    try std.testing.expectEqual(@as(usize, 9), popBand(.item, -20));
    try std.testing.expectEqual(@as(usize, 0), ownBand(0.5));
    try std.testing.expectEqual(@as(usize, 2), ownBand(10));
    try std.testing.expectEqual(@as(usize, 4), ownBand(5000));
}

test "t tails: normal at df 0, wider at few df" {
    try std.testing.expectApproxEqAbs(0.0455, twoTail(2, 0), 1e-4);
    // t(13): P(|T| > 2) = 0.0667; t(1) Cauchy: 1 - 2 atan(2) / pi
    try std.testing.expectApproxEqAbs(0.0667, twoTail(2, 13), 2e-4);
    try std.testing.expectApproxEqAbs(1 - 2 * std.math.atan(@as(f64, 2)) / std.math.pi, twoTail(2, 1), 1e-6);
}

test "a planted lean fails, a clean group doesn't; merging origins equals one pass" {
    const gpa = std.testing.allocator;
    // 14 origins, 40 cells each: champion-roles at band -6..-7 run 1 point over Meio's
    // 50% (target 51 of 100 every cell, small spread); band > -3 exactly on
    var parts: [14]Lean = @splat(.{});
    var one_pass: Group = .{};
    var by_origin: Moments = .{};
    var prng: std.Random.DefaultPrng = .init(7);
    const rnd = prng.random();
    for (&parts) |*part| {
        var r_o: f64 = 0;
        var n_o: f64 = 0;
        for (0..40) |_| {
            const wiggle: f64 = @floatFromInt(rnd.intRangeAtMost(i32, -2, 2));
            const k = 51 + wiggle;
            part.cell(.champion, .{ .n = 100, .k = k, .p = 0.5, .x = -6.5, .own = 100, .raw = 0.6 });
            part.cell(.champion, .{ .n = 100, .k = 50 + wiggle, .p = 0.5, .x = -2, .own = 100, .raw = 0.5 });
            one_pass.cells.one(k - 50, 100);
            r_o += k - 50;
            n_o += 100;
        }
        by_origin.one(r_o, n_o);
    }
    for (&parts) |*p| p.block();
    // Merged in one go and in two halves: the same group
    var merged: Lean = .{};
    for (parts) |p| merged.add(p);
    var a: Lean = .{};
    var b: Lean = .{};
    for (parts[0..5]) |p| a.add(p);
    for (parts[5..]) |p| b.add(p);
    a.add(b);
    const planted = merged.pop[popBand(.champion, -6.5)];
    try std.testing.expectEqual(planted.cells, a.pop[popBand(.champion, -6.5)].cells);
    try std.testing.expectEqual(planted.blocks, a.pop[popBand(.champion, -6.5)].blocks);
    // Against one pass over the cells and its own origin sums
    try std.testing.expectApproxEqAbs(one_pass.mean().?, planted.mean().?, 1e-12);
    try std.testing.expectEqual(one_pass.cells.count, planted.cells.count);
    try std.testing.expectApproxEqAbs(@sqrt(by_origin.variance(planted.mean().?)), planted.se().?.se, 1e-12);
    try std.testing.expectEqual(@as(f64, 13), planted.se().?.df);

    const results = try gpa.create(truth.Results);
    defer gpa.destroy(results);
    results.* = @splat(@splat(@splat(@splat(.{}))));
    results[0][@backingInt(Kind.champion)][0][4].lean = merged;
    const buf = try gpa.alloc(Judged, max_judged);
    defer gpa.free(buf);
    const list = judge(results, .{}, buf);
    var planted_fails = false;
    var clean_fails = false;
    for (list) |j| if (j.family == .pop) {
        if (j.index == popBand(.champion, -6.5)) planted_fails = j.fails;
        if (j.index == 0) clean_fails = j.fails;
    };
    try std.testing.expect(planted_fails);
    try std.testing.expect(!clean_fails);
    // Band -6..-7 isn't one of the rarest: no gem cells
    try std.testing.expectEqual(@as(f64, 0), merged.gem[0].cells.count);
    // Under a 2-point floor nothing fails
    for (judge(results, .{ .points = 2 }, buf)) |j| try std.testing.expect(!j.fails);
    var w: std.Io.Writer.Allocating = .init(gpa);
    defer w.deinit();
    try report(gpa, results, .{}, &w.writer);
    try std.testing.expect(std.mem.find(u8, w.written(), "FAILS beyond chance") != null);
}
