//! `meiolol truth` (docs/plan/estimates.md E2): how well each data mode's numbers predict
//! the next week's games on the newest patch. Rolling origin: for day d since the patch
//! went live on EUW1 (T0), every mode is built from games before T0 + d days and scored
//! on the patch's games of the `horizon` days after, per cell kind, region, rank bracket
//! and day bucket. Modes: the raw 30 days and the raw patch (the site's two) and Meio,
//! the estimate (src/meio.zig, any type with fit and rate: see `run`).
//!
//! Reads the day cubes (src/cubes.zig), not the database: no player keys, already built
//! by the box's web loop, so a daily run there is a pass over ~40 day files. Each day's
//! cells are summed once and each origin adds up its days.
//!
//! Scores. Rates (win rates, shares): binomial log loss of the target games under the
//! mode's rate, (wins + 0.5) / (games + 1) for raw modes so a 0 or 100% cell scores
//! finitely. Averages (lane gold difference at 14): squared error against the target
//! cell's mean minus that mean's noise (s^2 / n), so a mode is not blamed for the
//! target's own luck. A raw mode has a number from `min_games`. Each comparison is
//! paired over the cells where both sides have a number, with a standard error over
//! cells (target games of a cell share its number; overlapping horizons of nearby
//! origins are not independent, so read it as a floor). "Unseen": win-rate cells the 30
//! days has too few games for, Meio against the champion-role's 30-day rate, which is
//! what the site falls back on
//!
//! Lock stacks (J35): a champion-role is depth 0, one condition (matchup, item, ...)
//! depth 1, two (keystone x opponent, item x opponent, keystone x item) depth 2. Ranges,
//! not games, decide what a rate shows (faded past +-6 points, never hidden), so each
//! mode's ranges are checked per kind, depth and band: share of cells whose target falls
//! inside, and the error's spread net of the target's noise

const std = @import("std");
const store = @import("store");
const core = @import("core");
const cubes = @import("cubes.zig");
const par = @import("par.zig");
const meio = @import("meio.zig");
const curvesfile = core.curvesfile;
const Role = core.Role;

const Allocator = std.mem.Allocator;
const day_ms = std.time.ms_per_day;

pub const Options = struct {
    /// The newest patch ("16.20"); the boundary replayed is the one into it
    patch: []const u8,
    /// Origins d = 0 .. origins-1
    origins: u8 = 14,
    /// Target days after each origin
    horizon: u8 = 7,
    /// The raw window's days
    window: u16 = 30,
    /// A raw mode has a number for a cell from this many games in its window
    min_games: u32 = 10,
    /// Games from this Unix ms are never read (a held-out test window); 0: none
    until_ms: i64 = 0,
    threads: u8 = 4,
};

/// meio.Kind's kinds by name, then the two-lock stacks; the order keeps keys stable
pub const Kind = enum(u4) {
    champion,
    matchup,
    duo,
    gold14,
    build,
    item,
    keystone,
    rune,
    /// Win rate with a keystone against a lane opponent (b: keystone << 16 | opponent cr)
    keystone_matchup,
    /// Win rate with a finished item against a lane opponent (b: item << 16 | opponent cr)
    item_matchup,
    /// Win rate with a keystone and a finished item (b: keystone << 16 | item)
    keystone_item,

    pub const count = @typeInfo(Kind).@"enum".field_names.len;
};

/// The model's kind of the same name; null: the model has none, so Meio has no number
fn meioKind(k: Kind) ?meio.Kind {
    return switch (k) {
        inline else => |t| if (@hasField(meio.Kind, @tagName(t))) @field(meio.Kind, @tagName(t)) else null,
    };
}

fn label(k: Kind) []const u8 {
    return switch (k) {
        .champion => "champion-role",
        .matchup => "matchup",
        .duo => "duo (bot+sup)",
        .gold14 => "gold at 14 (matchup)",
        .build => "item share",
        .item => "item win rate",
        .keystone => "keystone win rate",
        .rune => "keystone share",
        .keystone_matchup => "keystone x opponent",
        .item_matchup => "item x opponent",
        .keystone_item => "keystone x item",
    };
}

/// Counted out of the champion-role's games (key b = 0 holds them), not its wins
fn isShare(k: Kind) bool {
    return k == .build or k == .rune;
}

/// Win rates the site falls back to the champion-role for when thin
fn isChild(k: Kind) bool {
    return depth(k) > 0 and !isShare(k) and k != .gold14;
}

/// Locks on top of the champion-role
fn depth(k: Kind) u2 {
    return switch (k) {
        .champion => 0,
        .keystone_matchup, .item_matchup, .keystone_item => 2,
        else => 1,
    };
}

pub const Estimate = meio.Estimate;

/// The estimate, meio.zig at its default options
pub const Meio = struct {
    pub const Model = meio.Model;
    pub fn fit(gpa: Allocator, rows: []const Row, before_day: i32) !Model {
        return meio.fit(gpa, rows, before_day, .{});
    }
};

/// A third mode with no numbers: the raw modes alone
pub const NoMeio = struct {
    pub const Model = struct {
        pub fn rate(_: *const Model, _: meio.Kind, _: u1, _: u2, _: u16, _: u32) ?Estimate {
            return null;
        }
        pub fn deinit(_: *Model, _: Allocator) void {}
    };
    pub fn fit(_: Allocator, _: []const Row, _: i32) !Model {
        return .{};
    }
};

const regions = [_][]const u8{ "every region", "EUW1" };
const brackets = [_][]const u8{ "all ranks", "Iron-Silver", "Gold-Emerald", "Diamond+" };
const buckets = [_][]const u8{ "0", "1", "2-3", "4-7", "8+" };

fn bucketOf(d: usize) usize {
    return switch (d) {
        0 => 0,
        1 => 1,
        2...3 => 2,
        4...7 => 3,
        else => 4,
    };
}

pub const Row = meio.Row;
pub const no_gold = meio.no_gold;

pub fn crOf(champion: u32, role: Role) u16 {
    return @intCast(champion | @as(u32, @backingInt(role)) << 13);
}

fn roleOf(cr: u16) Role {
    return @fromBackingInt(@intCast(cr >> 13));
}

fn key(kind: Kind, region: usize, bracket: usize, a: u16, b: u32) u64 {
    return @as(u64, @backingInt(kind)) << 60 | @as(u64, region) << 59 | @as(u64, bracket) << 57 |
        @as(u64, a) << 32 | b;
}

const Key = struct { kind: Kind, region: u1, bracket: u2, a: u16, b: u32 };

fn unkey(k: u64) Key {
    return .{
        .kind = @fromBackingInt(@intCast(k >> 60)),
        .region = @intCast(k >> 59 & 1),
        .bracket = @intCast(k >> 57 & 3),
        .a = @intCast(k >> 32 & 0xffff),
        .b = @truncate(k),
    };
}

/// For a share cell, the champion-role's games it counts out of; else the cell itself
fn anchor(k: u64) u64 {
    const u = unkey(k);
    return if (isShare(u.kind)) k & ~@as(u64, 0xffff_ffff) else k;
}

const Acc = struct {
    n: f64 = 0,
    s: f64 = 0,
    q: f64 = 0,

    fn add(a: *Acc, y: f64) void {
        a.n += 1;
        a.s += y;
        a.q += y * y;
    }

    fn merge(a: *Acc, o: Acc) void {
        a.n += o.n;
        a.s += o.s;
        a.q += o.q;
    }
};

/// One day's sums: every game, and the newest patch's
const DayCell = struct { all: Acc = .{}, latest: Acc = .{} };
const DayCells = std.AutoHashMapUnmanaged(u64, DayCell);

/// The 30-day window, the patch window, the target
const Cell = struct { w: [2]Acc = .{ .{}, .{} }, t: Acc = .{} };
const Cells = std.AutoHashMapUnmanaged(u64, Cell);

/// Adds a row to each cell it counts in, for every region and bracket it falls in
fn addRow(gpa: Allocator, cells: *DayCells, r: Row) !void {
    const y: f64 = if (r.win) 1 else 0;
    for (0..2) |region| {
        if (region == 1 and !r.euw) continue;
        for ([_]usize{ 0, r.bracket }, 0..) |bracket, i| {
            if (i == 1 and bracket == 0) continue;
            const Add = struct {
                cells: *DayCells,
                gpa: Allocator,
                latest: bool,
                region: usize,
                bracket: usize,
                fn add(s: @This(), kind: Kind, a: u16, b: u32, v: f64) !void {
                    const e = try s.cells.getOrPut(s.gpa, key(kind, s.region, s.bracket, a, b));
                    if (!e.found_existing) e.value_ptr.* = .{};
                    e.value_ptr.all.add(v);
                    if (s.latest) e.value_ptr.latest.add(v);
                }
            };
            const s: Add = .{ .cells = cells, .gpa = gpa, .latest = r.patch == 0, .region = region, .bracket = bracket };
            try s.add(.champion, r.cr, 0, y);
            if (r.opp != 0) try s.add(.matchup, r.cr, r.opp, y);
            if (r.ally != 0) try s.add(.duo, r.cr, r.ally, y);
            if (r.gold != no_gold) try s.add(.gold14, r.cr, r.opp, @floatFromInt(r.gold));
            if (r.timeline) {
                try s.add(.build, r.cr, 0, 1);
                for (r.items) |item| if (item != 0) {
                    try s.add(.build, r.cr, item, 1);
                    try s.add(.item, r.cr, item, y);
                    if (r.opp != 0) try s.add(.item_matchup, r.cr, @as(u32, item) << 16 | r.opp, y);
                    if (r.keystone != 0) try s.add(.keystone_item, r.cr, @as(u32, r.keystone) << 16 | item, y);
                };
            }
            if (r.keystone != 0) {
                try s.add(.rune, r.cr, 0, 1);
                try s.add(.rune, r.cr, r.keystone, 1);
                try s.add(.keystone, r.cr, r.keystone, y);
                if (r.opp != 0) try s.add(.keystone_matchup, r.cr, @as(u32, r.keystone) << 16 | r.opp, y);
            }
        }
    }
}

/// Days -window .. last, each day's cells
const Days = struct {
    first: i32,
    cells: []DayCells,

    fn deinit(d: *Days, gpa: Allocator) void {
        for (d.cells) |*c| c.deinit(gpa);
        gpa.free(d.cells);
    }

    fn at(d: *const Days, day: i32) ?*const DayCells {
        const i = day - d.first;
        if (i < 0 or i >= d.cells.len) return null;
        return &d.cells[@intCast(i)];
    }
};

/// Rows sorted by day: the slice of `day`
fn daySlice(rows: []const Row, day: i32) []const Row {
    const lo = lowerBound(rows, day);
    return rows[lo..lowerBound(rows, day + 1)];
}

/// The first row on `day` or later
fn lowerBound(rows: []const Row, day: i32) usize {
    var lo: usize = 0;
    var hi = rows.len;
    while (lo < hi) {
        const mid = (lo + hi) / 2;
        if (rows[mid].day < day) lo = mid + 1 else hi = mid;
    }
    return lo;
}

fn sumDays(gpa: Allocator, io: std.Io, rows: []const Row, first: i32, last: i32, threads: u8) !Days {
    const cells = try gpa.alloc(DayCells, @intCast(last - first + 1));
    @memset(cells, .empty);
    var days: Days = .{ .first = first, .cells = cells };
    errdefer days.deinit(gpa);
    const Ctx = struct {
        gpa: Allocator,
        rows: []const Row,
        days: *Days,
        fn body(c: @This(), i: usize) !void {
            const day = c.days.first + @as(i32, @intCast(i));
            for (daySlice(c.rows, day)) |r| try addRow(c.gpa, &c.days.cells[i], r);
        }
    };
    try par.forEachUpTo(io, cells.len, @max(threads, 1), Ctx{ .gpa = gpa, .rows = rows, .days = &days }, Ctx.body);
    return days;
}

/// Origin d's windows and target, over the cells the target has (a share cell: whose
/// champion-role the target has)
fn tally(gpa: Allocator, days: *const Days, opts: Options, d: i32) !Cells {
    var cells: Cells = .empty;
    errdefer cells.deinit(gpa);
    var t = d;
    while (t < d + @as(i32, opts.horizon)) : (t += 1) {
        const day = days.at(t) orelse continue;
        var it = day.iterator();
        while (it.next()) |e| {
            if (e.value_ptr.latest.n == 0) continue;
            const c = try cells.getOrPut(gpa, e.key_ptr.*);
            if (!c.found_existing) c.value_ptr.* = .{};
            c.value_ptr.t.merge(e.value_ptr.latest);
        }
    }
    var w = days.first;
    while (w < d) : (w += 1) {
        const day = days.at(w) orelse continue;
        const in30 = w >= d - @as(i32, opts.window);
        var it = day.iterator();
        while (it.next()) |e| {
            const k = e.key_ptr.*;
            const c = if (cells.getPtr(k)) |c| c else blk: {
                if (k == anchor(k) or !cells.contains(anchor(k))) continue;
                const n = try cells.getOrPut(gpa, k);
                n.value_ptr.* = .{};
                break :blk n.value_ptr;
            };
            if (in30) c.w[0].merge(e.value_ptr.all);
            c.w[1].merge(e.value_ptr.latest);
        }
    }
    return cells;
}

/// A comparison of two modes over the cells both have a number for: challenger's loss
/// minus reference's (negative: the challenger predicted better)
pub const Pair = struct {
    /// Target observations (games; for shares, champion-role games x values)
    obs: f64 = 0,
    cells: f64 = 0,
    /// Rates: log loss; averages: noise-corrected squared error times games
    challenger: f64 = 0,
    reference: f64 = 0,
    d: f64 = 0,
    dd: f64 = 0,
    dn: f64 = 0,
    nn: f64 = 0,

    fn add(s: *Pair, o: Pair) void {
        inline for (@typeInfo(Pair).@"struct".field_names) |name| @field(s, name) += @field(o, name);
    }

    fn cell(s: *Pair, n: f64, challenger: f64, reference: f64) void {
        s.obs += n;
        s.cells += 1;
        s.challenger += challenger;
        s.reference += reference;
        const d = challenger - reference;
        s.d += d;
        s.dd += d * d;
        s.dn += d * n;
        s.nn += n * n;
    }

    /// Mean difference per observation and its standard error, clustered by cell
    pub fn diff(s: Pair) struct { mean: f64, se: f64 } {
        if (s.obs == 0) return .{ .mean = 0, .se = 0 };
        const m = s.d / s.obs;
        const v = @max(0, s.dd - 2 * m * s.dn + m * m * s.nn);
        return .{ .mean = m, .se = @sqrt(v) / s.obs };
    }
};

pub const modes = [_][]const u8{ "30 days", "patch", "Meio" };
const mode_tags = [modes.len][]const u8{ "30d", "patch", "meio" };

pub const Comparison = enum {
    patch_30,
    meio_30,
    meio_patch,
    /// Win-rate cells the 30 days has too few games for: Meio against the champion-role
    unseen,

    const count = 4;
    const sides = [count][2][]const u8{
        .{ "patch", "30 days" },
        .{ "Meio", "30 days" },
        .{ "Meio", "patch" },
        .{ "Meio", "parent" },
    };
};

/// Sums for one (region, kind, bracket, bucket)
pub const Stat = struct {
    /// Target observations in cells the target had
    target: f64 = 0,
    /// Of them, in cells where each mode has a number
    covered: [modes.len]f64 = @splat(0),
    pairs: [Comparison.count]Pair = @splat(.{}),
    /// Rate cells' ranges per mode and band; raw modes from one game
    cal: [modes.len][bands.len]Cal = @splat(@splat(.{})),
    /// The same on sure targets only: target noise under the range's claimed variance
    /// (a thin target lands inside any range, so the bands' in-range share runs high)
    sure: [modes.len]Cal = @splat(.{}),
    /// Meio's ranges against each raw mode's (30 days, patch) on cells both range
    widths: [2]Width = @splat(.{}),

    fn add(s: *Stat, o: Stat) void {
        s.target += o.target;
        for (&s.covered, o.covered) |*a, b| a.* += b;
        for (&s.pairs, o.pairs) |*a, b| a.add(b);
        for (&s.cal, o.cal) |*a, b| for (a, b) |*x, y| x.add(y);
        for (&s.sure, o.sure) |*a, b| a.add(b);
        for (&s.widths, o.widths) |*a, b| a.add(b);
    }

    /// Meio's cells whose range holds the target, over every band
    fn inRange(s: Stat) ?f64 {
        var c: Cal = .{};
        for (s.cal[2]) |b| c.add(b);
        return if (c.cells > 0) c.inside / c.cells else null;
    }

    /// Mode m's 80% range `half` around p against k of n target games
    fn range(s: *Stat, m: usize, p: f64, half: f64, n: f64, k: f64) Ranged {
        const se = half / z80;
        if (p * (1 - p) / n < se * se) _ = s.sure[m].cell(p, half, n, k);
        return .{ .half = half, .in = s.cal[m][bandOf(half)].cell(p, half, n, k) };
    }
};

/// Range bands by 80% half-width (Trust rules): solid under 6 points, faded from 6
pub const bands = [_][]const u8{ "solid", "faded" };

fn bandOf(half: f64) usize {
    return if (half < 0.06) 0 else 1;
}

/// One mode's ranges in one band
pub const Cal = struct {
    cells: f64 = 0,
    /// Cells whose target rate is inside the range, the target's noise added in quadrature
    inside: f64 = 0,
    /// (target - p)^2 less the target's binomial noise, summed
    sq: f64 = 0,
    /// The range's claimed variance, (half / 1.28)^2, summed
    claim: f64 = 0,

    fn add(c: *Cal, o: Cal) void {
        c.cells += o.cells;
        c.inside += o.inside;
        c.sq += o.sq;
        c.claim += o.claim;
    }

    /// The error's sd in points, net of the target's noise; an honest range's half-width
    /// is 1.28 of it, so solid wants under 4.7
    pub fn sd(c: Cal) f64 {
        return if (c.cells > 0) 100 * @sqrt(@max(0, c.sq / c.cells)) else 0;
    }

    /// The sd the ranges claim, in points; honest when sd() matches it
    pub fn claimedSd(c: Cal) f64 {
        return if (c.cells > 0) 100 * @sqrt(c.claim / c.cells) else 0;
    }

    /// A rate p with 80% half-width `half` against k of n target games; true if inside
    fn cell(c: *Cal, p: f64, half: f64, n: f64, k: f64) bool {
        const gap = k / n - p;
        const se = half / z80;
        const noise = p * (1 - p) / n;
        const in = @abs(gap) <= z80 * @sqrt(se * se + noise);
        c.cells += 1;
        if (in) c.inside += 1;
        c.sq += gap * gap - noise;
        c.claim += se * se;
        return in;
    }
};

/// One rate's 80% range as scored
const Ranged = struct { half: f64, in: bool };

/// Two modes' ranges on the cells both give one (E2 gate's certainty half: Meio surer
/// than the patch and still right); side 0 the raw mode, 1 Meio
pub const Width = struct {
    cells: f64 = 0,
    /// Half-widths summed
    half: [2]f64 = @splat(0),
    inside: [2]f64 = @splat(0),
    /// Cells shown solid (under 6 points)
    solid: [2]f64 = @splat(0),

    fn add(w: *Width, o: Width) void {
        w.cells += o.cells;
        for (&w.half, o.half) |*a, b| a.* += b;
        for (&w.inside, o.inside) |*a, b| a.* += b;
        for (&w.solid, o.solid) |*a, b| a.* += b;
    }

    fn cell(w: *Width, sides: [2]Ranged) void {
        w.cells += 1;
        for (sides, 0..) |r, i| {
            w.half[i] += r.half;
            if (r.in) w.inside[i] += 1;
            if (bandOf(r.half) == 0) w.solid[i] += 1;
        }
    }
};

const z80 = 1.2815515655446004;

pub const Results = [regions.len][Kind.count][brackets.len][buckets.len]Stat;

/// Log loss of k wins in n games at rate p
fn logLoss(p: f64, n: f64, k: f64) f64 {
    return -(k * @log(p) + (n - k) * @log(1 - p));
}

fn rate(a: Acc, k: f64) f64 {
    return (k + 0.5) / (a.n + 1);
}

/// Squared error of `m` against the target's mean, less the mean's noise, times n
fn avgError(m: f64, t: Acc) f64 {
    const mean = t.s / t.n;
    const variance = (t.q - t.n * mean * mean) / (t.n - 1);
    return t.n * ((m - mean) * (m - mean) - variance / t.n);
}

fn score(comptime Model: type, cells: *const Cells, model: *const Model, opts: Options, bucket: usize, out: *Results) void {
    const min: f64 = @floatFromInt(opts.min_games);
    var it = cells.iterator();
    while (it.next()) |e| {
        const k = e.key_ptr.*;
        const u = unkey(k);
        if (isShare(u.kind) and u.b == 0) continue;
        const s = &out[u.region][@backingInt(u.kind)][u.bracket][bucket];
        const c = e.value_ptr.*;
        const games: Cell = if (isShare(u.kind)) cells.get(anchor(k)) orelse continue else c;
        const n = games.t.n;
        if (n == 0 or (u.kind == .gold14 and n < 2)) continue;
        s.target += n;
        var have: [modes.len]bool = undefined;
        var loss: [modes.len]f64 = undefined;
        var ranged: [modes.len]?Ranged = @splat(null);
        for (0..2) |m| {
            const w = games.w[m].n;
            if (u.kind != .gold14 and w > 0) {
                const p = rate(games.w[m], c.w[m].s);
                const half = z80 * @sqrt(p * (1 - p) / w);
                ranged[m] = s.range(m, p, half, n, c.t.s);
            }
            have[m] = w >= min;
            if (!have[m]) continue;
            loss[m] = if (u.kind == .gold14)
                avgError(c.w[m].s / c.w[m].n, c.t)
            else
                logLoss(rate(games.w[m], c.w[m].s), n, c.t.s);
        }
        const mk = meioKind(u.kind);
        const est: ?Estimate = if (mk == null)
            null
        else if (u.kind != .gold14)
            model.rate(mk.?, u.region, u.bracket, u.a, u.b)
        else if (@hasDecl(Model, "avg"))
            model.avg(mk.?, u.region, u.bracket, u.a, u.b)
        else
            null;
        have[2] = est != null;
        if (est) |m| {
            loss[2] = if (u.kind == .gold14)
                avgError(m.p, c.t)
            else
                logLoss(std.math.clamp(m.p, 1e-4, 1 - 1e-4), n, c.t.s);
            if (u.kind != .gold14 and m.hi > m.lo) {
                ranged[2] = s.range(2, m.p, (m.hi - m.lo) / 2, n, c.t.s);
            }
        }
        if (ranged[2]) |mr| for (&s.widths, ranged[0..2]) |*w, r| {
            if (r) |rr| w.cell(.{ rr, mr });
        };
        for (have, 0..) |h, m| {
            if (h) s.covered[m] += n;
        }
        const pairs = [_][2]usize{ .{ 1, 0 }, .{ 2, 0 }, .{ 2, 1 } };
        for (pairs, 0..) |p, i| {
            if (have[p[0]] and have[p[1]]) s.pairs[i].cell(n, loss[p[0]], loss[p[1]]);
        }
        if (isChild(u.kind) and !have[0] and have[2]) {
            const parent = cells.get(key(.champion, u.region, u.bracket, u.a, 0)) orelse continue;
            if (parent.w[0].n < min) continue;
            const ref = logLoss(rate(parent.w[0], parent.w[0].s), n, c.t.s);
            s.pairs[@backingInt(Comparison.unseen)].cell(n, loss[2], ref);
        }
    }
}

/// Every origin, Meio fitted on each origin's rows before it. `Meio` has
/// `fit(gpa, rows, before_day) !Model`, and Model `rate(kind, region, bracket, a, b)
/// ?Estimate`, `deinit(gpa)` and optionally `avg` (same shape, for gold)
pub fn scoreAll(comptime Mode: type, gpa: Allocator, io: std.Io, rows: []const Row, opts: Options) !Results {
    const last: i32 = @as(i32, opts.origins) - 1 + opts.horizon - 1;
    var days = try sumDays(gpa, io, rows, -@as(i32, opts.window), last, opts.threads);
    defer days.deinit(gpa);
    const parts = try gpa.alloc(Results, opts.origins);
    defer gpa.free(parts);
    @memset(parts, @splat(@splat(@splat(@splat(.{})))));
    const Ctx = struct {
        gpa: Allocator,
        rows: []const Row,
        days: *const Days,
        opts: Options,
        parts: []Results,
        fn body(c: @This(), i: usize) !void {
            const d: i32 = @intCast(i);
            var cells = try tally(c.gpa, c.days, c.opts, d);
            defer cells.deinit(c.gpa);
            if (cells.count() == 0) return;
            var model = try Mode.fit(c.gpa, c.rows[0..lowerBound(c.rows, d)], d);
            defer model.deinit(c.gpa);
            score(@TypeOf(model), &cells, &model, c.opts, bucketOf(i), &c.parts[i]);
        }
    };
    try par.forEachUpTo(io, opts.origins, @max(opts.threads, 1), Ctx{
        .gpa = gpa,
        .rows = rows,
        .days = &days,
        .opts = opts,
        .parts = parts,
    }, Ctx.body);
    var results: Results = @splat(@splat(@splat(@splat(.{}))));
    for (parts) |*part| {
        for (&results, part) |*a, *b| for (a, b) |*a2, *b2| for (a2, b2) |*a3, *b3| for (a3, b3) |*s, o| s.add(o);
    }
    return results;
}

/// "16.21" as 1621
fn patchNumber(patch: []const u8) ?u16 {
    const dot = std.mem.findScalar(u8, patch, '.') orelse return null;
    const major = std.fmt.parseInt(u16, patch[0..dot], 10) catch return null;
    const minor = std.fmt.parseInt(u16, patch[dot + 1 ..], 10) catch return null;
    if (minor >= 100) return null;
    return major * 100 + minor;
}

/// A row before T0 is known
const Pending = struct { ms: i64, patch: u16, row: Row };

/// Each seat of a game as a row (day and patch index set later)
fn gameRows(g: cubes.Game, euw: bool, out: *[10]Row) []Row {
    var n: usize = 0;
    for (g.seats) |s| {
        if (n == out.len or s.p.champion == 0 or s.p.champion >= 1 << 13) continue;
        const role = s.p.role;
        var r: Row = .{
            .day = 0,
            .patch = 0,
            .cr = crOf(s.p.champion, role),
            .win = s.p.won,
            .euw = euw,
            .timeline = s.k != null,
            .gold = s.p.lead orelse no_gold,
            .keystone = std.math.cast(u16, s.p.keystone) orelse 0,
            .bracket = if (s.rank) |i| bracketOf(i) else 0,
        };
        if (s.p.opponent != 0 and s.p.opponent < 1 << 13) r.opp = crOf(s.p.opponent, role) else r.gold = no_gold;
        if (role == .bottom) for (g.seats) |o| {
            if (o.p.role == .utility and o.p.won == s.p.won and o.p.champion < 1 << 13) r.ally = crOf(o.p.champion, .utility);
        };
        if (s.k) |k| {
            var m: usize = 0;
            for (k.core[0..k.core_len]) |item| {
                const id = std.math.cast(u16, item) orelse continue;
                if (id == 0 or std.mem.findScalar(u16, r.items[0..m], id) != null) continue;
                r.items[m] = id;
                m += 1;
            }
        }
        out[n] = r;
        n += 1;
    }
    return out[0..n];
}

/// A seat's stored tier (store.schema.tiers index) as a curves bracket (1 low .. 3 high)
fn bracketOf(tier: u8) u2 {
    if (tier >= store.schema.tiers.len) return 0;
    const rank = curvesfile.tierRank(store.schema.tiers[tier]) orelse return 0;
    return @intCast(@backingInt(curvesfile.Bracket.ofRank(rank)));
}

pub const Loaded = struct {
    /// Sorted by day
    rows: []Row,
    /// The patch's first ranked solo game on EUW1, Unix ms
    t0: i64,
    /// Cube days read
    days: usize,
};

/// Every player row of the cubes' games from T0 - window to the last target day, on the
/// newest patch or older ones
pub fn load(gpa: Allocator, io: std.Io, cube_dir: []const u8, opts: Options) !Loaded {
    const newest = patchNumber(opts.patch) orelse return error.Usage;
    const s = try cubes.Store.open(gpa, io, cube_dir);
    defer s.deinit();
    const days = try s.days(gpa, 0);
    defer gpa.free(days);
    const per_day = try gpa.alloc(std.ArrayList(Pending), days.len);
    @memset(per_day, .empty);
    defer {
        for (per_day) |*p| p.deinit(gpa);
        gpa.free(per_day);
    }
    const Ctx = struct {
        gpa: Allocator,
        s: *cubes.Store,
        days: []const i64,
        out: []std.ArrayList(Pending),
        newest: u16,
        until_ms: i64,
        fn body(c: @This(), i: usize) !void {
            var arena: std.heap.ArenaAllocator = .init(c.gpa);
            defer arena.deinit();
            const d = try c.s.read(c.gpa, arena.allocator(), c.days[i]) orelse return error.StaleCube;
            var buf: [10]Row = undefined;
            for (d.games) |g| {
                if (c.until_ms != 0 and g.start >= c.until_ms) continue;
                const patch = patchNumber(d.string(g.patch)) orelse continue;
                if (patch > c.newest) continue;
                const euw = std.mem.eql(u8, d.string(g.platform), "EUW1");
                for (gameRows(g, euw, &buf)) |r| try c.out[i].append(c.gpa, .{ .ms = g.start, .patch = patch, .row = r });
            }
        }
    };
    try par.forEachUpTo(io, days.len, @max(opts.threads, 1), Ctx{
        .gpa = gpa,
        .s = s,
        .days = days,
        .out = per_day,
        .newest = newest,
        .until_ms = opts.until_ms,
    }, Ctx.body);

    var t0: i64 = std.math.maxInt(i64);
    var patches: std.ArrayList(u16) = .empty;
    defer patches.deinit(gpa);
    for (per_day) |p| for (p.items) |r| {
        if (r.patch == newest and r.row.euw) t0 = @min(t0, r.ms);
        if (std.mem.findScalar(u16, patches.items, r.patch) == null) try patches.append(gpa, r.patch);
    };
    if (t0 == std.math.maxInt(i64)) return error.PatchNotFound;
    std.mem.sort(u16, patches.items, {}, std.sort.desc(u16));

    const from = t0 - @as(i64, opts.window) * day_ms;
    const to = t0 + (@as(i64, opts.origins) - 1 + opts.horizon) * day_ms;
    var rows: std.ArrayList(Row) = .empty;
    errdefer rows.deinit(gpa);
    for (per_day) |p| for (p.items) |r| {
        if (r.ms < from or r.ms >= to) continue;
        var x = r.row;
        x.day = @intCast(@divFloor(r.ms - t0, day_ms));
        x.patch = @intCast(@min(255, std.mem.findScalar(u16, patches.items, r.patch).?));
        try rows.append(gpa, x);
    };
    std.mem.sortUnstable(Row, rows.items, {}, struct {
        fn less(_: void, a: Row, b: Row) bool {
            return a.day < b.day;
        }
    }.less);
    return .{ .rows = try rows.toOwnedSlice(gpa), .t0 = t0, .days = days.len };
}

/// Loads, scores and writes the markdown report to `out` (and the TSV to `tsv`)
pub fn run(comptime Mode: type, gpa: Allocator, io: std.Io, cube_dir: []const u8, opts: Options, out: *std.Io.Writer, tsv: ?*std.Io.Writer) !void {
    const loaded = try load(gpa, io, cube_dir, opts);
    defer gpa.free(loaded.rows);
    const results = try scoreAll(Mode, gpa, io, loaded.rows, opts);
    const end = if (loaded.rows.len > 0) loaded.rows[loaded.rows.len - 1].day else 0;
    try out.print("# Truth test into {s}\n\nT0 (first EUW1 game) {d} ms; origins day 0-{d}, " ++
        "{d}-day targets, {d}-day raw window, a raw number from {d} games; {d} player rows " ++
        "from {d} cube days, the last on day {d}{s}\n\n", .{
        opts.patch,  loaded.t0, opts.origins - 1,                                                 opts.horizon, opts.window, opts.min_games, loaded.rows.len,
        loaded.days, end,       if (opts.until_ms != 0) " (games from --until left out)" else "",
    });
    try report(&results, out);
    if (tsv) |w| try writeTsv(&results, opts.patch, loaded.t0, w);
}

pub fn report(results: *const Results, out: *std.Io.Writer) !void {
    try out.writeAll("Rates: milli-nats per target observation (lower is better). Gold: " ++
        "noise-corrected RMSE in gold, differences in gold^2. Each difference is the first " ++
        "mode's loss minus the second's over the cells both have a number for, +- 2 se " ++
        "over cells (negative: the first predicted better). Unseen: cells the 30 days has " ++
        "too few games for, Meio against the champion-role's 30-day rate. In range: share " ++
        "of Meio's ranges holding the target's rate (its noise added in quadrature; ~80% " ++
        "if honest)\n");
    for (results, regions) |by_kind, region| {
        try out.print("\n## {s}\n\n| cell | ranks | day | cells | covered 30d / patch / Meio | " ++
            "30 days | patch - 30d | Meio - 30d | Meio - patch | unseen cells | Meio - parent | in range |\n" ++
            "| --- | --- | --- | --: | --: | --: | --: | --: | --: | --: | --: | --: |\n", .{region});
        for (by_kind, 0..) |by_bracket, k| {
            const kind: Kind = @fromBackingInt(@intCast(k));
            for (by_bracket, brackets) |by_bucket, bracket| {
                var all: Stat = .{};
                for (by_bucket) |s| all.add(s);
                for (by_bucket ++ [1]Stat{all}, buckets ++ [1][]const u8{"all"}) |s, bucket| {
                    if (s.target == 0) continue;
                    try row(out, kind, bracket, bucket, s);
                }
            }
        }
        try calibration(out, region, &by_kind);
        try rangeWidths(out, region, &by_kind);
    }
}

/// Ranges per kind and lock depth, all ranks and days: in each band, does a mode's range
/// hold the target as often as it says?
fn calibration(out: *std.Io.Writer, region: []const u8, by_kind: *const [Kind.count][brackets.len][buckets.len]Stat) !void {
    try out.print("\n### Ranges, {s}\n\nAll ranks, every day. Bands by the 80% range's " ++
        "half-width (raw modes: binomial from their games, from 1 game): solid under 6 " ++
        "points, faded from 6. Per band: cells, share inside (the target's noise added in " ++
        "quadrature; 80% if honest), the error's sd in points net of the target's " ++
        "noise and the sd the ranges claim (honest: equal; solid claims under 4.7). " ++
        "Sure: cells of any band whose target noise is under the range's claimed " ++
        "variance (thin targets land inside any range)\n\n| cell | mode | ", .{region});
    for (bands ++ [1][]const u8{"sure"}) |b| try out.print("{s} cells | in | sd | claimed | ", .{b});
    try out.writeAll("\n| --- | --- |");
    for (0..bands.len + 1) |_| try out.writeAll(" --: | --: | --: | --: |");
    try out.writeAll("\n");
    var groups: [4]Stat = @splat(.{});
    for (by_kind, 0..) |by_bracket, k| {
        const kind: Kind = @fromBackingInt(@intCast(k));
        if (kind == .gold14) continue;
        var all: Stat = .{};
        for (by_bracket[0]) |s| all.add(s);
        try calRows(out, label(kind), all);
        groups[group(kind)].add(all);
    }
    for (groups, group_names) |g, name| try calRows(out, name, g);
}

const group_names = [_][]const u8{ "depth 0: champion", "depth 1: win rates", "depth 1: shares", "depth 2: win rates" };

fn group(kind: Kind) usize {
    return switch (depth(kind)) {
        0 => 0,
        1 => if (isShare(kind)) 2 else 1,
        else => 3,
    };
}

/// Per kind, depth and day, all ranks: Meio's range against each raw mode's on the
/// cells both range. Meio passes E2's certainty half where its mean half-width is under
/// the patch's and its in-range share stays near 80%
fn rangeWidths(out: *std.Io.Writer, region: []const u8, by_kind: *const [Kind.count][brackets.len][buckets.len]Stat) !void {
    try out.print("\n### Range widths, {s}\n\nAll ranks. Cells where Meio and the raw " ++
        "mode both give an 80% range (raw: binomial, from 1 game): mean half-width in " ++
        "points, share inside, share shown solid (under 6 points), raw mode then Meio\n\n" ++
        "| cell | day | vs | cells | half | Meio half | in | Meio in | solid | Meio solid |\n" ++
        "| --- | --- | --- | --: | --: | --: | --: | --: | --: | --: |\n", .{region});
    var groups: [group_names.len][buckets.len]Stat = @splat(@splat(.{}));
    for (by_kind, 0..) |by_bracket, k| {
        const kind: Kind = @fromBackingInt(@intCast(k));
        if (kind == .gold14) continue;
        try widthRows(out, label(kind), by_bracket[0]);
        for (&groups[group(kind)], by_bracket[0]) |*g, s| g.add(s);
    }
    for (groups, group_names) |g, name| try widthRows(out, name, g);
}

fn widthRows(out: *std.Io.Writer, name: []const u8, by_bucket: [buckets.len]Stat) !void {
    var all: Stat = .{};
    for (by_bucket) |s| all.add(s);
    for (by_bucket ++ [1]Stat{all}, buckets ++ [1][]const u8{"all"}) |s, bucket| {
        for (s.widths, modes[0..2]) |w, mode| {
            if (w.cells == 0) continue;
            try out.print("| {s} | {s} | {s} | {d:.0} | {d:.1} | {d:.1} | {d:.0}% | {d:.0}% | {d:.0}% | {d:.0}% |\n", .{
                name,                       bucket,                     mode,                        w.cells,
                100 * w.half[0] / w.cells,  100 * w.half[1] / w.cells,  100 * w.inside[0] / w.cells, 100 * w.inside[1] / w.cells,
                100 * w.solid[0] / w.cells, 100 * w.solid[1] / w.cells,
            });
        }
    }
}

fn calRows(out: *std.Io.Writer, name: []const u8, s: Stat) !void {
    for (s.cal, s.sure, modes) |by_band, sure, mode| {
        var cells: f64 = 0;
        for (by_band) |c| cells += c.cells;
        if (cells == 0) continue;
        try out.print("| {s} | {s} |", .{ name, mode });
        for (by_band ++ [1]Cal{sure}) |c| {
            if (c.cells == 0) {
                try out.writeAll(" 0 | | | |");
            } else try out.print(" {d:.0} | {d:.0}% | {d:.1} | {d:.1} |", .{
                c.cells, 100 * c.inside / c.cells, c.sd(), c.claimedSd(),
            });
        }
        try out.writeAll("\n");
    }
}

fn row(out: *std.Io.Writer, kind: Kind, bracket: []const u8, bucket: []const u8, s: Stat) !void {
    const base = s.pairs[@backingInt(Comparison.patch_30)];
    try out.print("| {s} | {s} | {s} | {d:.0} | {d:.0}% / {d:.0}% / {d:.0}% | ", .{
        label(kind),                   bracket, bucket, base.cells, 100 * s.covered[0] / s.target, 100 * s.covered[1] / s.target,
        100 * s.covered[2] / s.target,
    });
    const gold = kind == .gold14;
    if (base.obs == 0) {
        try out.writeAll(" | ");
    } else if (gold) {
        try out.print("{d:.0} | ", .{@sqrt(@max(0, base.reference / base.obs))});
    } else try out.print("{d:.1} | ", .{1000 * base.reference / base.obs});
    for (s.pairs, 0..) |p, i| {
        if (i == @backingInt(Comparison.unseen)) try out.print("{d:.0} | ", .{p.cells});
        if (p.obs == 0) {
            try out.writeAll(" | ");
            continue;
        }
        const d = p.diff();
        if (gold) {
            try out.print("{d:.0} +- {d:.0} | ", .{ d.mean, 2 * d.se });
        } else try out.print("{d:.2} +- {d:.2} | ", .{ 1000 * d.mean, 2000 * d.se });
    }
    if (s.inRange()) |r| try out.print("{d:.0}% |\n", .{100 * r}) else try out.writeAll(" |\n");
}

/// One line per (region, kind, bracket, bucket), for the method page (E9)
pub fn writeTsv(results: *const Results, patch: []const u8, t0: i64, out: *std.Io.Writer) !void {
    try out.writeAll("patch\tt0_ms\tregion\tkind\tbracket\tday\ttarget\tcovered_30d\tcovered_patch\tcovered_meio");
    for (std.enums.values(Comparison)) |c| {
        inline for (.{ "cells", "obs", "loss_a", "loss_b", "diff", "se" }) |f| try out.print("\t{t}_{s}", .{ c, f });
    }
    for (mode_tags) |m| for (bands ++ [1][]const u8{"sure"}) |b| {
        inline for (.{ "cells", "inside", "err", "claim" }) |f| try out.print("\tcal_{s}_{s}_{s}", .{ m, b, f });
    };
    for (mode_tags[0..2]) |m| {
        inline for (.{ "cells", "half", "half_meio", "inside", "inside_meio", "solid", "solid_meio" }) |f|
            try out.print("\twidth_{s}_{s}", .{ m, f });
    }
    try out.writeAll("\n");
    for (results, regions) |by_kind, region| for (by_kind, 0..) |by_bracket, k| {
        const kind: Kind = @fromBackingInt(@intCast(k));
        for (by_bracket, brackets) |by_bucket, bracket| for (by_bucket, buckets) |s, bucket| {
            if (s.target == 0) continue;
            try out.print("{s}\t{d}\t{s}\t{s}\t{s}\t{s}\t{d}\t{d}\t{d}\t{d}", .{
                patch, t0, region, @tagName(kind), bracket, bucket, s.target, s.covered[0], s.covered[1], s.covered[2],
            });
            for (s.pairs) |p| {
                const d = p.diff();
                try out.print("\t{d}\t{d}\t{d:.6}\t{d:.6}\t{e:.4}\t{e:.4}", .{ p.cells, p.obs, p.challenger, p.reference, d.mean, d.se });
            }
            for (s.cal, s.sure) |by_band, sure| for (by_band ++ [1]Cal{sure}) |c| {
                try out.print("\t{d}\t{d}\t{d:.3}\t{d:.3}", .{ c.cells, c.inside, c.sd(), c.claimedSd() });
            };
            for (s.widths) |w| try out.print("\t{d}\t{d:.6}\t{d:.6}\t{d}\t{d}\t{d}\t{d}", .{
                w.cells, w.half[0], w.half[1], w.inside[0], w.inside[1], w.solid[0], w.solid[1],
            });
            try out.writeAll("\n");
        };
    };
}

test "TSV header: one name per column, no spaces" {
    const results: Results = @splat(@splat(@splat(@splat(.{}))));
    var w: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer w.deinit();
    try writeTsv(&results, "x", 0, &w.writer);
    const header = w.written();
    try std.testing.expect(std.mem.findScalar(u8, header, ' ') == null);
    try std.testing.expectEqual(10 + 6 * Comparison.count + 4 * modes.len * (bands.len + 1) + 7 * 2, std.mem.count(u8, header, "\t") + 1);
    try std.testing.expect(std.mem.endsWith(u8, header, "\twidth_patch_solid_meio\n"));
    try std.testing.expect(std.mem.find(u8, header, "\tcal_meio_sure_claim\t") != null);
    try std.testing.expect(std.mem.find(u8, header, "\tmeio_30_diff\t") != null);
}

test "range bands, inside with the target's noise, error net of it" {
    var s: Stat = .{};
    // 50% +- 3 points against 600 of 1000 games: solid, 10 points off, outside; a sure
    // target (noise 0.25 / 1000 under (0.03 / 1.28)^2)
    try std.testing.expect(!s.range(0, 0.5, 0.03, 1000, 600).in);
    // 50% +- 8 against 52 of 100: faded, inside; target noise 0.0025 over 0.0039: sure
    try std.testing.expect(s.range(0, 0.5, 0.08, 100, 52).in);
    // 50% +- 8 against 1 of 1: inside, too thin to be sure
    try std.testing.expect(s.range(0, 0.5, 0.08, 1, 1).in);
    const c = s.cal[0];
    try std.testing.expectEqual(@as(f64, 1), c[0].cells);
    try std.testing.expectEqual(@as(f64, 2), c[1].inside);
    try std.testing.expectEqual(@as(f64, 2), s.sure[0].cells);
    try std.testing.expectEqual(@as(f64, 1), s.sure[0].inside);
    try std.testing.expectApproxEqAbs(100 * @sqrt((0.03 * 0.03 + 0.08 * 0.08) / 2.0) / z80, s.sure[0].claimedSd(), 1e-9);
    try std.testing.expectEqual(@as(f64, 0), c[0].inside);
    try std.testing.expectApproxEqAbs(100 * @sqrt(0.01 - 0.25 / 1000.0), c[0].sd(), 1e-9);
    // Error smaller than the target's noise: sd 0, not negative
    try std.testing.expectEqual(@as(f64, 0), c[1].sd());
    try std.testing.expectEqual(@as(usize, 1), bandOf(0.4));
}

test "log loss and the noise-corrected squared error" {
    try std.testing.expectApproxEqAbs(@log(2.0) * 4, logLoss(0.5, 4, 1), 1e-12);
    // A target of four games at 100, 0, 100, 0: mean 50, noise s^2/n = 3333/4
    var t: Acc = .{};
    for ([_]f64{ 100, 0, 100, 0 }) |y| t.add(y);
    try std.testing.expectApproxEqAbs(4 * (0 - 10000.0 / 3.0 / 4.0), avgError(50, t), 1e-9);
    try std.testing.expectApproxEqAbs(4 * (100 - 10000.0 / 3.0 / 4.0), avgError(60, t), 1e-9);
}

/// Says 0.5 for every win rate with a range of 0.4-0.6, nothing for shares
const HalfMeio = struct {
    const Model = struct {
        fn rate(_: *const Model, kind: meio.Kind, _: u1, _: u2, _: u16, _: u32) ?Estimate {
            if (kind == .build or kind == .rune) return null;
            return .{ .p = 0.5, .lo = 0.4, .hi = 0.6, .own = 0 };
        }
        fn deinit(_: *Model, _: Allocator) void {}
    };
    fn fit(_: Allocator, rows: []const Row, before: i32) !Model {
        for (rows) |r| std.debug.assert(r.day < before);
        return .{};
    }
};

test "rolling origin: windows, target, kinds and Meio" {
    const gpa = std.testing.allocator;
    const top: u16 = crOf(1, .top);
    const opp: u16 = crOf(2, .top);
    // Day -1: champion 1 wins on the old patch; day 0 and 1 on the new: a loss, a win
    const rows = [_]Row{
        .{ .day = -1, .patch = 1, .cr = top, .opp = opp, .win = true, .euw = false, .bracket = 0, .timeline = true, .items = .{ 3071, 0, 0, 0, 0, 0 }, .keystone = 8010 },
        .{ .day = 0, .patch = 0, .cr = top, .opp = opp, .win = false, .euw = true, .bracket = 3, .timeline = true, .items = .{ 3071, 0, 0, 0, 0, 0 }, .keystone = 8010 },
        .{ .day = 1, .patch = 0, .cr = top, .opp = opp, .win = true, .euw = true, .bracket = 3, .timeline = true, .items = .{ 3071, 6610, 0, 0, 0, 0 }, .keystone = 8010 },
    };
    const opts: Options = .{ .patch = "x", .horizon = 1, .origins = 2, .min_games = 1, .threads = 1 };
    var days = try sumDays(gpa, std.testing.io, &rows, -30, 1, 1);
    defer days.deinit(gpa);
    var cells = try tally(gpa, &days, opts, 1);
    defer cells.deinit(gpa);
    const c = cells.get(key(.champion, 0, 0, top, 0)).?;
    // Before day 1: both games in 30 days, the day-0 loss in the patch; target: day 1
    try std.testing.expectEqual(@as(f64, 2), c.w[0].n);
    try std.testing.expectEqual(@as(f64, 1), c.w[0].s);
    try std.testing.expectEqual(@as(f64, 1), c.w[1].n);
    try std.testing.expectEqual(@as(f64, 0), c.w[1].s);
    try std.testing.expectEqual(@as(f64, 1), c.t.s);
    try std.testing.expectEqual(@as(f64, 1), cells.get(key(.matchup, 1, 3, top, opp)).?.w[0].n);
    // Item shares out of timelined games; the target's new item scored, the window's kept
    try std.testing.expectEqual(@as(f64, 2), cells.get(key(.build, 0, 0, top, 3071)).?.w[0].s);
    try std.testing.expectEqual(@as(f64, 1), cells.get(key(.build, 0, 0, top, 6610)).?.t.s);
    try std.testing.expectEqual(@as(f64, 1), cells.get(key(.keystone, 0, 0, top, 8010)).?.w[0].s);
    try std.testing.expectEqual(@as(f64, 2), cells.get(key(.rune, 0, 0, top, 0)).?.w[0].n);
    // Two locks: keystone x opponent, item x opponent, keystone x item
    try std.testing.expectEqual(@as(f64, 1), cells.get(key(.keystone_matchup, 1, 3, top, @as(u32, 8010) << 16 | opp)).?.w[0].n);
    try std.testing.expectEqual(@as(f64, 1), cells.get(key(.item_matchup, 0, 0, top, @as(u32, 6610) << 16 | opp)).?.t.s);
    try std.testing.expectEqual(@as(f64, 2), cells.get(key(.keystone_item, 0, 0, top, @as(u32, 8010) << 16 | 3071)).?.w[0].n);
    try std.testing.expectEqual(Key{ .kind = .item_matchup, .region = 1, .bracket = 3, .a = top, .b = @as(u32, 6610) << 16 | opp }, unkey(key(.item_matchup, 1, 3, top, @as(u32, 6610) << 16 | opp)));

    var results: Results = @splat(@splat(@splat(@splat(.{}))));
    var model: HalfMeio.Model = .{};
    score(HalfMeio.Model, &cells, &model, opts, 1, &results);
    const s = results[0][@backingInt(Kind.champion)][0][1];
    const base = s.pairs[@backingInt(Comparison.patch_30)];
    try std.testing.expectEqual(@as(f64, 1), base.obs);
    // 30 days says 0.5 (1.5/3), the patch 0.25 (0.5/2): the win costs more under the patch
    try std.testing.expectApproxEqAbs(-@log(0.25) + @log(0.5), base.diff().mean, 1e-12);
    // Meio's 0.5 ties the 30 days, beats the patch; its range holds the win
    try std.testing.expectApproxEqAbs(0, s.pairs[@backingInt(Comparison.meio_30)].diff().mean, 1e-12);
    try std.testing.expect(s.pairs[@backingInt(Comparison.meio_patch)].diff().mean < 0);
    // Its 0.4-0.6 is faded; the win is 0.5 off, inside 1.28 sqrt(0.078^2 + 0.25)
    try std.testing.expectEqual(@as(f64, 1), s.cal[2][1].cells);
    try std.testing.expectEqual(@as(f64, 1), s.cal[2][1].inside);
    // Paired ranges: the 30 days' 0.5 from 2 games, half 1.28 sqrt(0.25 / 2), against
    // Meio's 0.1; the patch's 0.25 from 1 game, half 1.28 sqrt(0.1875)
    const w30 = s.widths[0];
    try std.testing.expectEqual(@as(f64, 1), w30.cells);
    try std.testing.expectApproxEqAbs(z80 * @sqrt(0.125), w30.half[0], 1e-12);
    try std.testing.expectApproxEqAbs(0.1, w30.half[1], 1e-12);
    try std.testing.expectEqual([2]f64{ 0, 0 }, w30.solid);
    try std.testing.expectApproxEqAbs(z80 * @sqrt(0.1875), s.widths[1].half[0], 1e-12);
    try std.testing.expectEqual(@as(f64, 0), results[0][@backingInt(Kind.build)][0][1].covered[2]);
    // Two-lock cells, the target's 8010 x 3071 and 8010 x 6610: Meio asked for both once
    // the model has the kind's name, raw modes ranged where they have games
    const ki = results[0][@backingInt(Kind.keystone_item)][0][1];
    const asked: f64 = if (meioKind(.keystone_item) != null) 2 else 0;
    try std.testing.expectEqual(asked, ki.covered[2]);
    try std.testing.expectEqual(asked, ki.cal[2][1].cells);
    // 30 days on 8010 x 3071: 1.5/3 from 2 games, half 1.28 sqrt(0.25 / 2) = 0.45: faded
    try std.testing.expectEqual(@as(f64, 1), ki.cal[0][1].cells);

    // Unseen: with 3 games needed, the matchup's 2 are too few and so are its
    // champion-role's: nothing. A third game against someone else makes the parent
    var unseen: Results = @splat(@splat(@splat(@splat(.{}))));
    const at3: Options = .{ .patch = "x", .horizon = 1, .min_games = 3 };
    score(HalfMeio.Model, &cells, &model, at3, 1, &unseen);
    const unseen_i = @backingInt(Comparison.unseen);
    try std.testing.expectEqual(@as(f64, 0), unseen[0][@backingInt(Kind.matchup)][0][1].pairs[unseen_i].cells);
    var more = rows ++ [1]Row{.{ .day = -2, .patch = 1, .cr = top, .opp = crOf(5, .top), .win = true, .euw = false, .bracket = 0 }};
    std.mem.sortUnstable(Row, &more, {}, struct {
        fn less(_: void, a: Row, b: Row) bool {
            return a.day < b.day;
        }
    }.less);
    var days3 = try sumDays(gpa, std.testing.io, &more, -30, 1, 1);
    defer days3.deinit(gpa);
    var cells3 = try tally(gpa, &days3, at3, 1);
    defer cells3.deinit(gpa);
    score(HalfMeio.Model, &cells3, &model, at3, 1, &unseen);
    const p = unseen[0][@backingInt(Kind.matchup)][0][1].pairs[unseen_i];
    try std.testing.expectEqual(@as(f64, 1), p.cells);
    // Parent 30 days: 2 wins of 3, (2.5 / 4); Meio's 0.5 is worse on the win
    try std.testing.expectApproxEqAbs(-@log(0.5) + @log(2.5 / 4.0), p.diff().mean, 1e-12);

    const all = try scoreAll(HalfMeio, gpa, std.testing.io, &rows, opts);
    try std.testing.expectEqual(@as(f64, 1), all[0][@backingInt(Kind.champion)][0][0].target);
    try std.testing.expectEqual(@as(f64, 1), all[0][@backingInt(Kind.champion)][0][1].target);
}

test "a cube game's seats as rows" {
    const builds = @import("builds.zig");
    var k: builds.Picks = .{};
    k.core[0] = 3071;
    k.core[1] = 3071;
    k.core[2] = 6610;
    k.core_len = 3;
    const seats = [_]builds.Seat{
        .{ .p = .{ .champion = 1, .role = .bottom, .won = true, .keystone = 8008, .opponent = 2, .lead = 300 }, .k = k, .rank = 0 },
        .{ .p = .{ .champion = 3, .role = .utility, .won = true }, .k = null, .rank = null },
        .{ .p = .{ .champion = 2, .role = .bottom, .won = false, .opponent = 1, .lead = -300 }, .k = null, .rank = 9 },
        .{ .p = .{ .champion = 4, .role = .utility, .won = false }, .k = null, .rank = 4 },
    };
    const g: cubes.Game = .{
        .start = 0,
        .rowid = 1,
        .source = 0,
        .platform = 0,
        .patch = 0,
        .hash = 0,
        .curves = .none,
        .lanes = &.{},
        .timeline = true,
        .seats = &seats,
    };
    var buf: [10]Row = undefined;
    const rows = gameRows(g, true, &buf);
    try std.testing.expectEqual(@as(usize, 4), rows.len);
    try std.testing.expectEqual(crOf(2, .bottom), rows[0].opp);
    try std.testing.expectEqual(crOf(3, .utility), rows[0].ally);
    try std.testing.expectEqual(crOf(4, .utility), rows[2].ally);
    try std.testing.expectEqual(@as(i32, 300), rows[0].gold);
    try std.testing.expectEqual([6]u16{ 3071, 6610, 0, 0, 0, 0 }, rows[0].items);
    try std.testing.expect(rows[0].timeline and !rows[2].timeline);
    try std.testing.expectEqual(@as(u16, 8008), rows[0].keystone);
    // Challenger, Iron, Emerald
    try std.testing.expectEqual(@as(u2, 3), rows[0].bracket);
    try std.testing.expectEqual(@as(u2, 1), rows[2].bracket);
    try std.testing.expectEqual(@as(u2, 2), rows[3].bracket);
    try std.testing.expectEqual(@as(u2, 0), rows[1].bracket);
    try std.testing.expectEqual(@as(?u16, 1621), patchNumber("16.21"));
}
