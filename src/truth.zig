//! `meiolol truth` (docs/plan/estimates.md E2): how well each data mode's numbers predict
//! the next week's games on the newest patch. Rolling origin: for day d since the patch
//! went live on EUW1 (T0), every mode is built from games before T0 + d days and scored
//! on the patch's games of the `horizon` days after, per cell kind, region, rank bracket
//! (and the site's masked Gold+ set) and day bucket. Modes: the raw 30 days and the raw
//! patch (the site's two) and Meio, the estimate (src/meio.zig, any type with fit and
//! rateIn: see `run`).
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
//! inside, randomised binomial PIT coverage (the share that counts: thin targets fall
//! inside any range) and the error's spread net of the target's noise
//!
//! Interval scores (research/questions/forecast-judging.md; beside the gate, not it):
//! weighted interval score of Meio against each raw mode on the cells both range, skill,
//! its width / below / above parts, a sign test over day origins, per target-games band.
//! Meio's PIT is also split by its weight on the cell's own games and kept for the cells
//! lists show first, where shrunk ranges are likeliest to miss

const std = @import("std");
const store = @import("store");
const core = @import("core");
const cubes = @import("cubes.zig");
const par = @import("par.zig");
const meio = @import("meio.zig");
const lean = @import("truth_lean.zig");
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
    /// The lean gate's floors (truth_lean.zig)
    floors: lean.Floors = .{},
    /// Per-cell dump (`--cells`)
    dump: ?*lean.Dump = null,
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

pub fn label(k: Kind) []const u8 {
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
pub fn isShare(k: Kind) bool {
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
        pub fn rateIn(_: *const Model, _: meio.Kind, _: u1, _: meio.Brackets, _: u16, _: u32) ?Estimate {
            return null;
        }
        pub fn deinit(_: *Model, _: Allocator) void {}
    };
    pub fn fit(_: Allocator, _: []const Row, _: i32) !Model {
        return .{};
    }
};

pub const regions = [_][]const u8{ "every region", "EUW1" };
/// The last is a rank set, not a bracket: the site's Plat+ and Emerald+ floors, served from
/// meio's mid|high mask (common rank-pick mapping), scored on those games pooled
pub const brackets = [_][]const u8{ "all ranks", "Iron-Silver", "Gold-Emerald", "Diamond+", "Gold+ masked" };
const masked = brackets.len - 1;

fn bracketSet(bracket: usize) meio.Brackets {
    return if (bracket == masked) .{ .mask = 0b1100 } else .of(@intCast(bracket));
}
pub const buckets = [_][]const u8{ "0", "1", "2-3", "4-7", "8+" };

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
    return @as(u64, @backingInt(kind)) << 60 | @as(u64, region) << 59 | @as(u64, bracket) << 56 |
        @as(u64, a) << 32 | b;
}

const Key = struct { kind: Kind, region: u1, bracket: u3, a: u16, b: u32 };

fn unkey(k: u64) Key {
    return .{
        .kind = @fromBackingInt(@intCast(k >> 60)),
        .region = @intCast(k >> 59 & 1),
        .bracket = @intCast(k >> 56 & 7),
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

/// A summed day, compact: as maps of Accs the 50 days held ~90M cells in ~10 GB. Every
/// value but gold's is 0 or 1, so those cells keep counts (sum of squares = sum)
const Day = struct {
    counts: []Counted = &.{},
    gold: []Summed = &.{},

    const Count = struct {
        n: u32 = 0,
        s: u32 = 0,

        fn merge(a: *Count, o: Count) void {
            a.n += o.n;
            a.s += o.s;
        }

        fn of(a: Acc) Count {
            return .{ .n = @intFromFloat(a.n), .s = @intFromFloat(a.s) };
        }

        fn acc(c: Count) Acc {
            return .{ .n = @floatFromInt(c.n), .s = @floatFromInt(c.s), .q = @floatFromInt(c.s) };
        }
    };
    const Counted = struct { key: u64, all: Count, latest: Count };
    const Summed = struct { key: u64, sums: DayCell };

    fn init(gpa: Allocator, cells: *const DayCells) !Day {
        var n_gold: usize = 0;
        var it = cells.iterator();
        while (it.next()) |e| n_gold += @intFromBool(unkey(e.key_ptr.*).kind == .gold14);
        const counts = try gpa.alloc(Counted, cells.count() - n_gold);
        errdefer gpa.free(counts);
        const gold = try gpa.alloc(Summed, n_gold);
        var c: usize = 0;
        var g: usize = 0;
        it = cells.iterator();
        while (it.next()) |e| {
            const k = e.key_ptr.*;
            const v = e.value_ptr.*;
            if (unkey(k).kind == .gold14) {
                gold[g] = .{ .key = k, .sums = v };
                g += 1;
            } else {
                counts[c] = .{ .key = k, .all = .of(v.all), .latest = .of(v.latest) };
                c += 1;
            }
        }
        return .{ .counts = counts, .gold = gold };
    }

    fn deinit(d: *Day, gpa: Allocator) void {
        gpa.free(d.counts);
        gpa.free(d.gold);
    }
};

/// The 30-day window, the patch window, the target
fn Window(comptime A: type) type {
    return struct { w: [2]A = @splat(.{}), t: A = .{} };
}
const Cell = Window(Acc);
const Cells = std.AutoHashMapUnmanaged(u64, Cell);
const Counts = std.AutoHashMapUnmanaged(u64, Window(Day.Count));

/// Origin d's cells, compact like Day: as one map of Cells each thread held ~1.4 GB
const Tally = struct {
    counts: Counts = .empty,
    gold: Cells = .empty,

    fn deinit(t: *Tally, gpa: Allocator) void {
        t.counts.deinit(gpa);
        t.gold.deinit(gpa);
    }

    fn count(t: *const Tally) usize {
        return t.counts.count() + t.gold.count();
    }

    fn get(t: *const Tally, k: u64) ?Cell {
        if (unkey(k).kind == .gold14) return t.gold.get(k);
        return cellOf(t.counts.get(k) orelse return null);
    }

    fn cellOf(c: Window(Day.Count)) Cell {
        return .{ .w = .{ c.w[0].acc(), c.w[1].acc() }, .t = c.t.acc() };
    }

    const Iterator = struct {
        counts: Counts.Iterator,
        gold: Cells.Iterator,

        fn next(it: *Iterator) ?struct { key: u64, cell: Cell } {
            if (it.counts.next()) |e| return .{ .key = e.key_ptr.*, .cell = cellOf(e.value_ptr.*) };
            const e = it.gold.next() orelse return null;
            return .{ .key = e.key_ptr.*, .cell = e.value_ptr.* };
        }
    };

    fn iterator(t: *const Tally) Iterator {
        return .{ .counts = t.counts.iterator(), .gold = t.gold.iterator() };
    }
};

/// Adds a row to each cell it counts in, for every region and bracket it falls in
fn addRow(gpa: Allocator, cells: *DayCells, r: Row) !void {
    const y: f64 = if (r.win) 1 else 0;
    for (0..2) |region| {
        if (region == 1 and !r.euw) continue;
        for ([_]usize{ 0, r.bracket, masked }, 0..) |bracket, i| {
            if (i == 1 and bracket == 0) continue;
            if (i == 2 and r.bracket < 2) continue;
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
    cells: []Day,

    fn deinit(d: *Days, gpa: Allocator) void {
        for (d.cells) |*c| c.deinit(gpa);
        gpa.free(d.cells);
    }

    fn at(d: *const Days, day: i32) ?*const Day {
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
    const cells = try gpa.alloc(Day, @intCast(last - first + 1));
    @memset(cells, .{});
    var days: Days = .{ .first = first, .cells = cells };
    errdefer days.deinit(gpa);
    const Ctx = struct {
        gpa: Allocator,
        rows: []const Row,
        days: *Days,
        fn body(c: @This(), i: usize) !void {
            const day = c.days.first + @as(i32, @intCast(i));
            var sums: DayCells = .empty;
            defer sums.deinit(c.gpa);
            for (daySlice(c.rows, day)) |r| try addRow(c.gpa, &sums, r);
            c.days.cells[i] = try .init(c.gpa, &sums);
        }
    };
    try par.forEachUpTo(io, cells.len, @max(threads, 1), Ctx{ .gpa = gpa, .rows = rows, .days = &days }, Ctx.body);
    return days;
}

/// Origin d's windows and target, over the cells the target has (a share cell: whose
/// champion-role the target has)
fn tally(gpa: Allocator, days: *const Days, opts: Options, d: i32) !Tally {
    var cells: Tally = .{};
    errdefer cells.deinit(gpa);
    var t = d;
    while (t < d + @as(i32, opts.horizon)) : (t += 1) {
        const day = days.at(t) orelse continue;
        for (day.counts) |e| try addTarget(gpa, &cells.counts, e.key, e.latest);
        for (day.gold) |e| try addTarget(gpa, &cells.gold, e.key, e.sums.latest);
    }
    var w = days.first;
    while (w < d) : (w += 1) {
        const day = days.at(w) orelse continue;
        const in30 = w >= d - @as(i32, opts.window);
        for (day.counts) |e| try addWindow(gpa, &cells.counts, e.key, in30, e.all, e.latest);
        for (day.gold) |e| try addWindow(gpa, &cells.gold, e.key, in30, e.sums.all, e.sums.latest);
    }
    return cells;
}

fn addTarget(gpa: Allocator, map: anytype, k: u64, latest: anytype) !void {
    if (latest.n == 0) return;
    const c = try map.getOrPut(gpa, k);
    if (!c.found_existing) c.value_ptr.* = .{};
    c.value_ptr.t.merge(latest);
}

fn addWindow(gpa: Allocator, map: anytype, k: u64, in30: bool, all: anytype, latest: @TypeOf(all)) !void {
    const c = map.getPtr(k) orelse blk: {
        if (k == anchor(k) or !map.contains(anchor(k))) return;
        const n = try map.getOrPut(gpa, k);
        n.value_ptr.* = .{};
        break :blk n.value_ptr;
    };
    if (in30) c.w[0].merge(all);
    c.w[1].merge(latest);
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
    /// The same cells' interval scores, by target games
    wis: [2][sizes.len]Wis = @splat(@splat(.{})),
    /// Day origins (one region's) where Meio's interval score summed lower than the raw
    /// mode's, of those with paired cells: a sign test's blocks
    blocks: [2]Blocks = @splat(.{}),
    /// Meio's PIT by its weight on the cell's own games, and on the cells a list sorted
    /// by the estimate shows first (EB ranges promise average coverage only)
    by_weight: [weight_bands.len]Cover = @splat(.{}),
    shown: Cover = .{},
    /// Meio's middle against the target (truth_lean.zig, the M10 gate)
    lean: lean.Lean = .{},

    fn add(s: *Stat, o: Stat) void {
        s.target += o.target;
        for (&s.covered, o.covered) |*a, b| a.* += b;
        for (&s.pairs, o.pairs) |*a, b| a.add(b);
        for (&s.cal, o.cal) |*a, b| for (a, b) |*x, y| x.add(y);
        for (&s.sure, o.sure) |*a, b| a.add(b);
        for (&s.widths, o.widths) |*a, b| a.add(b);
        for (&s.wis, o.wis) |*a, b| for (a, b) |*x, y| x.add(y);
        for (&s.blocks, o.blocks) |*a, b| a.add(b);
        for (&s.by_weight, o.by_weight) |*a, b| a.add(b);
        s.shown.add(o.shown);
        s.lean.add(o.lean);
    }

    /// Interval scores against raw mode m over every target size
    pub fn wisAll(s: Stat, m: usize) Wis {
        var w: Wis = .{};
        for (s.wis[m]) |x| w.add(x);
        return w;
    }

    /// One origin's Stat as a sign-test block per raw mode and a lean block
    fn block(s: *Stat) void {
        s.lean.block();
        for (&s.blocks, 0..) |*b, m| {
            const w = s.wisAll(m);
            if (w.cells == 0 or w.total(0) == w.total(1)) continue;
            b.n += 1;
            if (w.total(1) < w.total(0)) b.ahead += 1;
        }
    }

    /// Meio's PIT coverage over every band
    fn inRange(s: Stat) ?f64 {
        var c: Cal = .{};
        for (s.cal[2]) |b| c.add(b);
        return if (c.cells > 0) c.pit / c.cells else null;
    }

    /// Mode m's 80% range `half` around p against k of n target games
    fn range(s: *Stat, m: usize, p: f64, half: f64, n: f64, k: f64) Ranged {
        const se = half / z80;
        if (p * (1 - p) / n < se * se) _ = s.sure[m].cell(p, half, n, k);
        const band = bandOf(half);
        const hit = s.cal[m][band].cell(p, half, n, k);
        return .{ .half = half, .in = hit.in, .pit = hit.pit, .tails = hit.tails, .solid = band == 0, .wis = hit.wis, .n = n };
    }

    /// Mode m's 80% range `half` (gold) around average p against a target mean of n
    /// games whose single-game variance is `variance`
    fn avgRange(s: *Stat, m: usize, p: f64, half: f64, n: f64, mean: f64, variance: f64) Ranged {
        const u: f64 = gold_unit;
        const se = half / z80 / u;
        const noise = variance / n / (u * u);
        if (noise < se * se) _ = s.sure[m].avgCell(p / u, se, noise, mean / u);
        const band: usize = if (half < gold_solid) 0 else 1;
        const hit = s.cal[m][band].avgCell(p / u, se, noise, mean / u);
        return .{ .half = half / u, .in = hit.in, .pit = hit.pit, .tails = hit.tails, .solid = band == 0, .wis = hit.wis, .n = n };
    }
};

/// A share target's noise over binomial: players repeat their picks, so its games
/// cluster (meio.zig Drift's phi, 16.21: 1.1 items, 1.2 keystones). Every mode's range
/// is scored on the target's n / phi games
fn targetPhi(k: Kind) f64 {
    return switch (k) {
        .build => 1.1,
        .rune => 1.2,
        else => 1,
    };
}

/// Range bands by 80% half-width (Trust rules): solid under 6 points, faded from 6
pub const bands = [_][]const u8{ "solid", "faded" };

fn bandOf(half: f64) usize {
    return if (half < 0.06) 0 else 1;
}

/// Gold enters Cal and Width in hundreds, so their "points" (x100) read as gold
const gold_unit = 100;
/// Gold at 14's solid band: 80% half-width under this many gold (no site rule yet; at
/// a lane's ~1,500 gold sd per game, about the games a 6-point win-rate range needs)
const gold_solid = 200;

/// One mode's ranges in one band
pub const Cal = struct {
    cells: f64 = 0,
    /// Cells whose target rate is inside the range, the target's noise added in quadrature
    inside: f64 = 0,
    /// (target - p)^2 less the target's binomial noise, summed
    sq: f64 = 0,
    /// The range's claimed variance, (half / 1.28)^2, summed
    claim: f64 = 0,
    /// pitParts' middle summed: unlike `inside`, 80% for honest ranges at any target size
    pit: f64 = 0,

    fn add(c: *Cal, o: Cal) void {
        c.cells += o.cells;
        c.inside += o.inside;
        c.sq += o.sq;
        c.claim += o.claim;
        c.pit += o.pit;
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

    /// A rate p with 80% half-width `half` against k of n target games
    fn cell(c: *Cal, p: f64, half: f64, n: f64, k: f64) Hit {
        const gap = k / n - p;
        const se = half / z80;
        const noise = p * (1 - p) / n;
        const pred = z80 * @sqrt(se * se + noise);
        const pit = pitParts(p, se, n, k);
        const hit: Hit = .{ .in = @abs(gap) <= pred, .pit = pit[1], .tails = .{ pit[0], pit[2] }, .wis = wis(p, pred, pred, k / n) };
        c.cells += 1;
        if (hit.in) c.inside += 1;
        c.sq += gap * gap - noise;
        c.claim += se * se;
        c.pit += hit.pit;
        return hit;
    }

    /// An average p of claimed sd se against a target mean with noise variance `noise`:
    /// normal, so PIT coverage is exact and equals in-range
    fn avgCell(c: *Cal, p: f64, se: f64, noise: f64, mean: f64) Hit {
        const gap = mean - p;
        const pred = z80 * @sqrt(se * se + noise);
        const in = @abs(gap) <= pred;
        c.cells += 1;
        if (in) c.inside += 1;
        c.sq += gap * gap - noise;
        c.claim += se * se;
        if (in) c.pit += 1;
        const tails: [2]f64 = .{ if (gap < -pred) 1 else 0, if (gap > pred) 1 else 0 };
        return .{ .in = in, .pit = if (in) 1 else 0, .tails = tails, .wis = wis(p, pred, pred, mean) };
    }
};

/// tails: the PIT's mass under 0.1 and over 0.9, the target below and above the range
const Hit = struct { in: bool, pit: f64, tails: [2]f64, wis: Parts };

/// One rate's 80% range as scored; n the target's games as scored (shares: n / phi)
const Ranged = struct { half: f64, in: bool, pit: f64, tails: [2]f64, solid: bool, wis: Parts, n: f64 };

/// An interval score's parts: width, below (the target under the point or range: the
/// mode said too high), above
const Parts = [3]f64;

/// Weighted interval score with one 80% interval and the point (Bracher et al 2021),
/// (2/3)(0.5 |y - p| + 0.1 IS), IS = (u - l) + 10 (l - y)+ + 10 (y - u)+, split into
/// Parts. y is the target's own value, so the range is the predictive one for it: l =
/// p - down, u = p + up, each side's half-width with the target's noise added
/// (`predictive`). Proper: scores the point and the range's width and misses in one
fn wis(p: f64, down: f64, up: f64, y: f64) Parts {
    const c = 2.0 / 3.0;
    const l = p - down;
    const u = p + up;
    return .{
        c * 0.1 * (u - l),
        c * (@max(0, l - y) + 0.5 * @max(0, p - y)),
        c * (@max(0, y - u) + 0.5 * @max(0, y - p)),
    };
}

/// A range side's 80% half-width with the target's noise variance added in quadrature
fn predictive(side: f64, noise: f64) f64 {
    return @sqrt(side * side + z80 * z80 * noise);
}

/// Target-games bands for interval scores: in points, cells with few games carry most
/// of the sum (their own noise), so skill is also given per band
pub const sizes = [_][]const u8{ "under 20", "20-199", "200+" };
pub const size_tags = [sizes.len][]const u8{ "n0", "n20", "n200" };

fn sizeOf(n: f64) usize {
    return if (n < 20) 0 else if (n < 200) 1 else 2;
}

/// Two modes' interval scores on the cells both range (Width's); side 0 the raw mode,
/// 1 Meio; each cell counts once (a weight independent of the forecasts keeps the sum
/// proper)
pub const Wis = struct {
    cells: f64 = 0,
    parts: [2]Parts = @splat(@splat(0)),
    /// Targets below, above the range: the randomised PIT's tails summed (gold: the
    /// normal range's misses). Not the score's own parts: on a rare share the normal
    /// range's low end is under 0, so it can't miss low there while the PIT can
    miss: [2][2]f64 = @splat(@splat(0)),

    fn add(w: *Wis, o: Wis) void {
        w.cells += o.cells;
        for (&w.parts, o.parts) |*a, b| for (a, b) |*x, y| {
            x.* += y;
        };
        for (&w.miss, o.miss) |*a, b| for (a, b) |*x, y| {
            x.* += y;
        };
    }

    fn cell(w: *Wis, sides: [2]Ranged) void {
        w.cells += 1;
        for (sides, &w.parts, &w.miss) |r, *parts, *miss| {
            for (parts, r.wis) |*a, b| a.* += b;
            for (miss, r.tails) |*a, b| a.* += b;
        }
    }

    pub fn total(w: Wis, side: usize) f64 {
        return w.parts[side][0] + w.parts[side][1] + w.parts[side][2];
    }

    /// 1 - Meio's sum over the raw mode's: above 0, Meio scored better
    pub fn skill(w: Wis) ?f64 {
        return if (w.total(0) > 0) 1 - w.total(1) / w.total(0) else null;
    }
};

pub const Blocks = struct {
    n: f64 = 0,
    ahead: f64 = 0,

    fn add(b: *Blocks, o: Blocks) void {
        b.n += o.n;
        b.ahead += o.ahead;
    }

    /// Two-sided sign test: the chance of a split at least this uneven if Meio and the
    /// raw mode were even on every block
    pub fn p(b: Blocks) f64 {
        if (b.n == 0) return 1;
        const c = binomCdf(0.5, b.n, b.ahead);
        return @min(1, 2 * @min(c[1], 1 - c[0]));
    }
};

/// Meio's weight on a cell's own games, from its range: an EB estimate's variance is the
/// weight times the own games' sampling variance (normal-normal), so w = se^2 / (that)
pub const weight_bands = [_][]const u8{ "under 0.25", "0.25-0.5", "0.5-0.75", "0.75+" };
pub const weight_tags = [weight_bands.len][]const u8{ "w0", "w25", "w50", "w75" };

fn weightOf(se: f64, own_var: f64) usize {
    if (!(own_var > 0)) return 0;
    const w = se * se / own_var;
    return @min(weight_bands.len - 1, @as(usize, @intFromFloat(@max(0, @min(4, w * 4)))));
}

/// The cells a list sorted by Meio's estimate shows first, per champion-role and lock:
/// the highest and lowest few win rates, the most taken shares
const shown_k = 5;

/// PIT coverage on a set of cells
pub const Cover = struct {
    cells: f64 = 0,
    pit: f64 = 0,

    fn add(c: *Cover, o: Cover) void {
        c.cells += o.cells;
        c.pit += o.pit;
    }

    fn one(c: *Cover, pit: f64) void {
        c.cells += 1;
        c.pit += pit;
    }
};

/// Chance a randomised PIT of k wins in n lands under 0.1, in [0.1, 0.9], over 0.9 (U
/// uniform on P(X < k) to P(X <= k)), X binomial with the rate logit-normal of sd se
/// (delta method): 0.1, 0.8, 0.1 for an honest range at any n, where a 1-game target near
/// 50% is inside any range
fn pitParts(p0: f64, se: f64, n: f64, k: f64) [3]f64 {
    const q0 = std.math.clamp(p0, 1e-4, 1 - 1e-4);
    const eta = @log(q0 / (1 - q0));
    const s = se / (q0 * (1 - q0));
    var lo: f64 = 0;
    var hi: f64 = 0;
    var weights: f64 = 0;
    const steps = 20;
    for (0..steps + 1) |j| {
        const z = -5 + 10 * @as(f64, @floatFromInt(j)) / steps;
        const w = @exp(-z * z / 2);
        const q = std.math.clamp(1 / (1 + @exp(-(eta + s * z))), 1e-6, 1 - 1e-6);
        const c = binomCdf(q, n, k);
        lo += w * c[0];
        hi += w * c[1];
        weights += w;
    }
    lo /= weights;
    hi /= weights;
    if (hi - lo < 1e-12) return if (lo < 0.1) .{ 1, 0, 0 } else if (lo > 0.9) .{ 0, 0, 1 } else .{ 0, 1, 0 };
    const in = @max(0, @min(hi, 0.9) - @max(lo, 0.1)) / (hi - lo);
    const below = @max(0, @min(hi, 0.1) - lo) / (hi - lo);
    return .{ below, in, 1 - in - below };
}

/// P(X < k), P(X <= k) for X binomial(n, q); normal past 400 games
fn binomCdf(q: f64, n_: f64, k_: f64) [2]f64 {
    const n = @round(n_);
    const k = @round(k_);
    if (n > 400) {
        const sd = @sqrt(n * q * (1 - q));
        return .{ normCdf((k - 0.5 - n * q) / sd), normCdf((k + 0.5 - n * q) / sd) };
    }
    var pmf = std.math.pow(f64, 1 - q, n);
    var below: f64 = 0;
    var j: f64 = 0;
    while (j < k) : (j += 1) {
        below += pmf;
        pmf *= (n - j) / (j + 1) * q / (1 - q);
    }
    return .{ below, below + pmf };
}

/// Abramowitz and Stegun 7.1.26, error under 1.5e-7
pub fn normCdf(x: f64) f64 {
    const z = @abs(x) / std.math.sqrt2;
    const t = 1 / (1 + 0.3275911 * z);
    const poly = t * (0.254829592 + t * (-0.284496736 + t * (1.421413741 + t * (-1.453152027 + t * 1.061405429))));
    const erf = 1 - poly * @exp(-z * z);
    return if (x >= 0) 0.5 * (1 + erf) else 0.5 * (1 - erf);
}

/// Two modes' ranges on the cells both give one (E2 gate's certainty half: Meio surer
/// than the patch and still right); side 0 the raw mode, 1 Meio
pub const Width = struct {
    cells: f64 = 0,
    /// Half-widths summed
    half: [2]f64 = @splat(0),
    inside: [2]f64 = @splat(0),
    pit: [2]f64 = @splat(0),
    /// Cells shown solid (under 6 points)
    solid: [2]f64 = @splat(0),
    /// Half-widths in points (gold at 14: gold) on a log scale, for medians
    hist: [2][hist_bins]f64 = @splat(@splat(0)),

    fn add(w: *Width, o: Width) void {
        w.cells += o.cells;
        for (&w.half, o.half) |*a, b| a.* += b;
        for (&w.inside, o.inside) |*a, b| a.* += b;
        for (&w.pit, o.pit) |*a, b| a.* += b;
        for (&w.solid, o.solid) |*a, b| a.* += b;
        for (&w.hist, o.hist) |*a, b| for (a, b) |*x, y| {
            x.* += y;
        };
    }

    fn cell(w: *Width, sides: [2]Ranged) void {
        w.cells += 1;
        for (sides, 0..) |r, i| {
            w.half[i] += r.half;
            if (r.in) w.inside[i] += 1;
            w.pit[i] += r.pit;
            if (r.solid) w.solid[i] += 1;
            w.hist[i][histBin(100 * r.half)] += 1;
        }
    }

    /// Side i's median half-width in points (gold at 14: gold), to the histogram's 10%
    pub fn median(w: Width, i: usize) ?f64 {
        if (w.cells == 0) return null;
        var seen: f64 = 0;
        for (w.hist[i], 0..) |c, b| {
            seen += c;
            if (seen >= w.cells / 2) return hist_lo * std.math.pow(f64, hist_step, @as(f64, @floatFromInt(b)) + 0.5);
        }
        return null;
    }
};

const z80 = 1.2815515655446004;

/// Bin b holds half-widths from hist_lo * hist_step^b (the first everything under, the
/// last everything over): 0.01 (share cells' ranges run under half a point) to ~39,000
/// points or gold
const hist_bins = 160;
const hist_lo = 0.01;
const hist_step = 1.1;

fn histBin(x: f64) usize {
    if (!(x > hist_lo)) return 0;
    return @min(hist_bins - 1, @as(usize, @intFromFloat(@log(x / hist_lo) / @log(hist_step))));
}

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

/// One game's gold-at-14 variance about its cell's mean, per champion-role, region and
/// bracket, from the target cells: a per-cell estimate from a few games would make thin
/// targets' ranges heavy-tailed, and one pool for all is too wide for popular
/// champion-roles' cells and too narrow for rare ones
const GoldVariance = struct {
    /// (region, bracket) pool, which each champion-role's is shrunk to
    pool: [regions.len][brackets.len]f64 = @splat(@splat(0)),
    /// By key(.gold14, region, bracket, cr, 0): residual sum of squares, its df
    by_cr: std.AutoHashMapUnmanaged(u64, [2]f64) = .empty,

    /// Pseudo-df of the pool in each champion-role's variance
    const prior_df = 30;

    fn init(gpa: Allocator, cells: *const Cells) !GoldVariance {
        var g: GoldVariance = .{};
        errdefer g.by_cr.deinit(gpa);
        var df: [regions.len][brackets.len]f64 = @splat(@splat(0));
        var it = cells.iterator();
        while (it.next()) |e| {
            const u = unkey(e.key_ptr.*);
            if (u.kind != .gold14) continue;
            const t = e.value_ptr.t;
            if (t.n < 2) continue;
            const ss = t.q - t.s * t.s / t.n;
            g.pool[u.region][u.bracket] += ss;
            df[u.region][u.bracket] += t.n - 1;
            const c = try g.by_cr.getOrPutValue(gpa, key(.gold14, u.region, u.bracket, u.a, 0), .{ 0, 0 });
            c.value_ptr[0] += ss;
            c.value_ptr[1] += t.n - 1;
        }
        for (&g.pool, df) |*a, b| for (a, b) |*x, y| {
            x.* = if (y > 0) x.* / y else 0;
        };
        return g;
    }

    fn deinit(g: *GoldVariance, gpa: Allocator) void {
        g.by_cr.deinit(gpa);
    }

    fn of(g: *const GoldVariance, u: Key) f64 {
        const pool = g.pool[u.region][u.bracket];
        const c = g.by_cr.get(key(.gold14, u.region, u.bracket, u.a, 0)) orelse return pool;
        return (c[0] + prior_df * pool) / (c[1] + prior_df);
    }
};

fn score(comptime Model: type, gpa: Allocator, cells: *const Tally, model: *const Model, opts: Options, origin: usize, out: *Results) !void {
    const bucket = bucketOf(origin);
    const min: f64 = @floatFromInt(opts.min_games);
    var gold_vars: GoldVariance = try .init(gpa, &cells.gold);
    defer gold_vars.deinit(gpa);
    const roles = roleGames(cells);
    var dump_buf: std.ArrayList(u8) = .empty;
    defer dump_buf.deinit(gpa);
    var shown: std.ArrayList(Shown) = .empty;
    defer shown.deinit(gpa);
    var it = cells.iterator();
    while (it.next()) |e| {
        const k = e.key;
        const u = unkey(k);
        if (isShare(u.kind) and u.b == 0) continue;
        const s = &out[u.region][@backingInt(u.kind)][u.bracket][bucket];
        const c = e.cell;
        const games: Cell = if (isShare(u.kind)) cells.get(anchor(k)) orelse continue else c;
        const n = games.t.n;
        if (n == 0 or (u.kind == .gold14 and n < 2)) continue;
        s.target += n;
        const phi = targetPhi(u.kind);
        const gold_var = if (u.kind == .gold14) gold_vars.of(u) else 0;
        var have: [modes.len]bool = undefined;
        var loss: [modes.len]f64 = undefined;
        var ranged: [modes.len]?Ranged = @splat(null);
        for (0..2) |m| {
            const w = games.w[m].n;
            if (u.kind != .gold14 and w > 0) {
                const p = rate(games.w[m], c.w[m].s);
                const half = z80 * @sqrt(p * (1 - p) / w);
                ranged[m] = s.range(m, p, half, n / phi, c.t.s / phi);
            } else if (u.kind == .gold14 and w > 0) {
                const half = z80 * @sqrt(gold_var / w);
                ranged[m] = s.avgRange(m, c.w[m].s / w, half, n, c.t.s / n, gold_var);
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
            model.rateIn(mk.?, u.region, bracketSet(u.bracket), u.a, u.b)
        else if (@hasDecl(Model, "avgIn"))
            model.avgIn(mk.?, u.region, bracketSet(u.bracket), u.a, u.b)
        else
            null;
        have[2] = est != null;
        if (est) |m| {
            const x = popularity(cells, &roles, k, c);
            const raw: ?f64 = if (games.w[0].n > 0) c.w[0].s / games.w[0].n else null;
            s.lean.cell(u.kind, .{ .n = n, .k = c.t.s, .p = m.p, .x = x, .own = m.own, .raw = raw });
            loss[2] = if (u.kind == .gold14)
                avgError(m.p, c.t)
            else
                logLoss(std.math.clamp(m.p, 1e-4, 1 - 1e-4), n, c.t.s);
            if (m.hi > m.lo) {
                // PIT and in-range read a symmetric half-width; the interval score takes
                // lo and hi as they are (a mixture's quantiles need not be symmetric)
                const gu: f64 = if (u.kind == .gold14) gold_unit else 1;
                const noise = if (u.kind == .gold14) gold_var / n / (gu * gu) else m.p * (1 - m.p) / (n / phi);
                var r = if (u.kind == .gold14)
                    s.avgRange(2, m.p, (m.hi - m.lo) / 2, n, c.t.s / n, gold_var)
                else
                    s.range(2, m.p, (m.hi - m.lo) / 2, n / phi, c.t.s / phi);
                r.wis = wis(m.p / gu, predictive((m.p - m.lo) / gu, noise), predictive((m.hi - m.p) / gu, noise), c.t.s / n / gu);
                ranged[2] = r;
            }
            if (opts.dump) |d| if (d.kinds.contains(u.kind) and u.bracket != masked) {
                try dump_buf.print(gpa, "{d}\t{t}\t{d}\t{d}\t{d}\t{d}\t{d:.4}\t{d:.6}\t{d:.6}\t{d:.6}\t{d:.1}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d:.4}\n", .{
                    origin,    u.kind, u.region,     u.bracket, u.a,          u.b,      x,                                m.p, m.lo, m.hi, m.own,
                    games.t.n, c.t.s,  games.w[0].n, c.w[0].s,  games.w[1].n, c.w[1].s, if (ranged[2]) |r| r.pit else -1,
                });
                if (dump_buf.items.len > 4 << 20) try d.flush(&dump_buf);
            };
        }
        if (ranged[2]) |mr| {
            for (&s.widths, &s.wis, ranged[0..2]) |*w, *by_size, r| if (r) |rr| {
                w.cell(.{ rr, mr });
                by_size[sizeOf(n)].cell(.{ rr, mr });
            };
            const m = est.?;
            const own_var = if (m.own <= 0) 0 else if (u.kind == .gold14)
                gold_var / m.own / (gold_unit * gold_unit)
            else
                m.p * (1 - m.p) / m.own;
            const se = (m.hi - m.lo) / 2 / z80 / @as(f64, if (u.kind == .gold14) gold_unit else 1);
            s.by_weight[weightOf(se, own_var)].one(mr.pit);
            if (u.b != 0) try shown.append(gpa, .{ .group = k & ~@as(u64, 0xffff), .p = m.p, .pit = mr.pit });
        }
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
    markShown(shown.items, bucket, out);
    if (opts.dump) |d| try d.flush(&dump_buf);
}

const RoleGames = [regions.len][brackets.len][Role.count]f64;

/// Each role's games in the 30-day window, per region and rank set: what a
/// champion-role's popularity counts out of
fn roleGames(cells: *const Tally) RoleGames {
    var g: RoleGames = @splat(@splat(@splat(0)));
    var it = cells.counts.iterator();
    while (it.next()) |e| {
        const u = unkey(e.key_ptr.*);
        if (u.kind != .champion) continue;
        g[u.region][u.bracket][@backingInt(roleOf(u.a))] += @floatFromInt(e.value_ptr.w[0].n);
    }
    return g;
}

/// log((games + 0.5) / (parent games + 1)) in the cell's region, rank set and 30 days:
/// a champion-role out of its role's games, a share out of its champion-role's (timelined
/// or keystone-known), a lock's win rate likewise, a matchup, duo or gold cell out of the
/// champion-role's games
fn popularity(cells: *const Tally, roles: *const RoleGames, k: u64, c: Cell) f64 {
    const u = unkey(k);
    const parent: f64 = switch (u.kind) {
        .champion => roles[u.region][u.bracket][@backingInt(roleOf(u.a))],
        else => blk: {
            const of: Kind = switch (u.kind) {
                .build, .item, .item_matchup, .keystone_item => .build,
                .rune, .keystone, .keystone_matchup => .rune,
                else => .champion,
            };
            const p = cells.get(key(of, u.region, u.bracket, u.a, 0)) orelse break :blk 0;
            break :blk p.w[0].n;
        },
    };
    return @log((c.w[0].n + 0.5) / (parent + 1));
}

/// A Meio-ranged cell under one champion-role and lock (its key less the listed value)
const Shown = struct { group: u64, p: f64, pit: f64 };

/// Per list, the cells sorted by Meio's estimate shows first into Stat.shown
fn markShown(list: []Shown, bucket: usize, out: *Results) void {
    std.mem.sortUnstable(Shown, list, {}, struct {
        fn less(_: void, a: Shown, b: Shown) bool {
            return if (a.group != b.group) a.group < b.group else a.p < b.p;
        }
    }.less);
    var i: usize = 0;
    while (i < list.len) {
        var j = i + 1;
        while (j < list.len and list[j].group == list[i].group) j += 1;
        const u = unkey(list[i].group);
        const s = &out[u.region][@backingInt(u.kind)][u.bracket][bucket];
        const same = list[i..j];
        const top = @min(shown_k, same.len);
        // Shares: the most taken; win rates: both ends, never one cell twice
        const low = if (isShare(u.kind)) 0 else @min(shown_k, same.len - top);
        for (same[same.len - top ..]) |c| s.shown.one(c.pit);
        for (same[0..low]) |c| s.shown.one(c.pit);
        i = j;
    }
}

/// Every origin, Meio fitted on each origin's rows before it. `Meio` has
/// `fit(gpa, rows, before_day) !Model`, and Model `rateIn(kind, region, meio.Brackets,
/// a, b) ?Estimate`, `deinit(gpa)` and optionally `avgIn` (same shape, for gold). On the
/// heap (~2 MB, the width histograms): the caller frees it
pub fn scoreAll(comptime Mode: type, gpa: Allocator, io: std.Io, rows: []const Row, opts: Options) !*Results {
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
            try score(@TypeOf(model), c.gpa, &cells, &model, c.opts, i, &c.parts[i]);
        }
    };
    try par.forEachUpTo(io, opts.origins, @max(opts.threads, 1), Ctx{
        .gpa = gpa,
        .rows = rows,
        .days = &days,
        .opts = opts,
        .parts = parts,
    }, Ctx.body);
    const results = try gpa.create(Results);
    results.* = @splat(@splat(@splat(@splat(.{}))));
    for (parts) |*part| {
        for (part) |*a| for (a) |*b| for (b) |*c| for (c) |*s| s.block();
        for (results, part) |*a, *b| for (a, b) |*a2, *b2| for (a2, b2) |*a3, *b3| for (a3, b3) |*s, o| s.add(o);
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
pub fn run(comptime Mode: type, gpa: Allocator, io: std.Io, cube_dir: []const u8, opts: Options, out: *std.Io.Writer, tsv: ?*std.Io.Writer, lean_tsv: ?*std.Io.Writer) !void {
    const loaded = try load(gpa, io, cube_dir, opts);
    defer gpa.free(loaded.rows);
    const results = try scoreAll(Mode, gpa, io, loaded.rows, opts);
    defer gpa.destroy(results);
    const end = if (loaded.rows.len > 0) loaded.rows[loaded.rows.len - 1].day else 0;
    try out.print("# Truth test into {s}\n\nT0 (first EUW1 game) {d} ms; origins day 0-{d}, " ++
        "{d}-day targets, {d}-day raw window, a raw number from {d} games; {d} player rows " ++
        "from {d} cube days, the last on day {d}{s}\n\n", .{
        opts.patch,  loaded.t0, opts.origins - 1,                                                 opts.horizon, opts.window, opts.min_games, loaded.rows.len,
        loaded.days, end,       if (opts.until_ms != 0) " (games from --until left out)" else "",
    });
    try report(results, out);
    try lean.report(gpa, results, opts.floors, out);
    if (tsv) |w| try writeTsv(results, opts.patch, loaded.t0, w);
    if (lean_tsv) |w| try lean.writeTsv(gpa, results, opts.floors, opts.patch, w);
}

pub fn report(results: *const Results, out: *std.Io.Writer) !void {
    try out.writeAll("Rates: milli-nats per target observation (lower is better). Gold: " ++
        "noise-corrected RMSE in gold, differences in gold^2. Each difference is the first " ++
        "mode's loss minus the second's over the cells both have a number for, +- 2 se " ++
        "over cells (negative: the first predicted better). Unseen: cells the 30 days has " ++
        "too few games for, Meio against the champion-role's 30-day rate. In range: Meio's " ++
        "PIT coverage, the share of cells whose target lands between the 10th and 90th " ++
        "percentile its range predicts for the target's games (randomised binomial PIT: " ++
        "80% if honest at any target size)\n");
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
        try intervalScores(out, region, &by_kind);
        try coverage(out, region, &by_kind);
    }
}

/// A kind's every-day Stat, all ranks
fn allDays(by_bracket: [brackets.len][buckets.len]Stat) Stat {
    var all: Stat = .{};
    for (by_bracket[0]) |s| all.add(s);
    return all;
}

/// Per kind, all ranks and days: weighted interval score skill of Meio against each raw
/// mode on the cells both range, its parts and a sign test over day origins
fn intervalScores(out: *std.Io.Writer, region: []const u8, by_kind: *const [Kind.count][brackets.len][buckets.len]Stat) !void {
    try out.print("\n### Interval scores, {s}\n\nAll ranks, every day; cells where Meio and " ++
        "the raw mode both give an 80% range, each cell once. Weighted interval score " ++
        "(one 80% range and the point, on the target's own rate with its noise added): " ++
        "skill = 1 - Meio's sum / the raw mode's (above 0: Meio better). Parts per cell in " ++
        "points (gold at 14: gold): width, below (target under the point or range), " ++
        "above; raw mode / Meio. Missed: targets below / above the range, from the " ++
        "randomised PIT's tails under 0.1 / over 0.9 (10% each if honest; the score's own " ++
        "normal range can't miss low on a rare share). Days: origins where Meio's sum was " ++
        "lower, of those scored, and the two-sided sign test's p. Then skill by target games\n\n" ++
        "| cell | vs | cells | skill | width | below | above | missed | Meio missed | days | p | ", .{region});
    for (sizes) |z| try out.print("{s} | ", .{z});
    try out.writeAll("\n| --- | --- | --: | --: | --: | --: | --: | --: | --: | --: | --: |");
    for (sizes) |_| try out.writeAll(" --: |");
    try out.writeAll("\n");
    for (by_kind, 0..) |by_bracket, k| {
        const kind: Kind = @fromBackingInt(@intCast(k));
        const all = allDays(by_bracket);
        for (modes[0..2], 0..) |mode, m| {
            const w = all.wisAll(m);
            if (w.cells == 0) continue;
            const per = 100 / w.cells;
            try out.print("| {s} | {s} | {d:.0} | {d:.1}% |", .{ label(kind), mode, w.cells, 100 * (w.skill() orelse 0) });
            for (0..3) |i| try out.print(" {d:.2} / {d:.2} |", .{ per * w.parts[0][i], per * w.parts[1][i] });
            for (w.miss) |x| try out.print(" {d:.0}% / {d:.0}% |", .{ per * x[0], per * x[1] });
            const b = all.blocks[m];
            try out.print(" {d:.0} of {d:.0} | {d:.3} |", .{ b.ahead, b.n, b.p() });
            for (all.wis[m]) |z| {
                if (z.skill()) |x| try out.print(" {d:.1}% ({d:.0}) |", .{ 100 * x, z.cells }) else try out.writeAll(" |");
            }
            try out.writeAll("\n");
        }
    }
}

/// Meio's PIT coverage per kind, all ranks and days: by its weight on the cell's own
/// games, and on the cells lists show first
fn coverage(out: *std.Io.Writer, region: []const u8, by_kind: *const [Kind.count][brackets.len][buckets.len]Stat) !void {
    try out.print("\n### Meio's coverage where it shrinks, {s}\n\nAll ranks, every day. PIT " ++
        "coverage (80% if honest) and cells, by Meio's weight on the cell's own games " ++
        "(its range's variance over the own games' sampling variance; two-lock kinds' own " ++
        "games are an upper bound), and on the cells a list sorted by Meio shows first " ++
        "(per champion-role and lock: the {d} highest and lowest win rates, the {d} most " ++
        "taken shares)\n\n| cell | ", .{ region, shown_k, shown_k });
    for (weight_bands) |w| try out.print("w {s} | ", .{w});
    try out.writeAll("shown | all |\n| --- |");
    for (0..weight_bands.len + 2) |_| try out.writeAll(" --: |");
    try out.writeAll("\n");
    for (by_kind, 0..) |by_bracket, k| {
        const kind: Kind = @fromBackingInt(@intCast(k));
        const all = allDays(by_bracket);
        var total: Cover = .{};
        for (all.by_weight) |c| total.add(c);
        if (total.cells == 0) continue;
        try out.print("| {s} |", .{label(kind)});
        for (all.by_weight ++ [2]Cover{ all.shown, total }) |c| {
            if (c.cells == 0) try out.writeAll(" |") else try out.print(" {d:.0}% ({d:.0}) |", .{ 100 * c.pit / c.cells, c.cells });
        }
        try out.writeAll("\n");
    }
}

/// Ranges per kind and lock depth, all ranks and days: in each band, does a mode's range
/// hold the target as often as it says?
fn calibration(out: *std.Io.Writer, region: []const u8, by_kind: *const [Kind.count][brackets.len][buckets.len]Stat) !void {
    try out.print("\n### Ranges, {s}\n\nAll ranks, every day. Bands by the 80% range's " ++
        "half-width (raw modes: binomial from their games, from 1 game): solid under 6 " ++
        "points, faded from 6. Per band: cells, share inside (the target's noise added in " ++
        "quadrature; runs high on thin targets, which land inside any range), PIT " ++
        "coverage (80% if honest at any target size), the error's sd in points net of the target's " ++
        "noise and the sd the ranges claim (honest: equal; solid claims under 4.7). " ++
        "Sure: cells of any band whose target noise is under the range's claimed " ++
        "variance (thin targets land inside any range). Gold at 14: sd and claimed in " ++
        "gold, solid under " ++ std.fmt.comptimePrint("{d}", .{gold_solid}) ++ " gold, " ++
        "raw modes' ranges from the pooled per-game variance, PIT exact (normal)\n\n| cell | mode | ", .{region});
    for (bands ++ [1][]const u8{"sure"}) |b| try out.print("{s} cells | in | pit | sd | claimed | ", .{b});
    try out.writeAll("\n| --- | --- |");
    for (0..bands.len + 1) |_| try out.writeAll(" --: | --: | --: | --: | --: |");
    try out.writeAll("\n");
    var groups: [4]Stat = @splat(.{});
    for (by_kind, 0..) |by_bracket, k| {
        const kind: Kind = @fromBackingInt(@intCast(k));
        var all: Stat = .{};
        for (by_bracket[0]) |s| all.add(s);
        try calRows(out, label(kind), all);
        if (kind != .gold14) groups[group(kind)].add(all);
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
        "points, share inside, PIT coverage, share shown solid (under 6 points), raw mode " ++
        "then Meio; gold at 14 in gold\n\n" ++
        "| cell | day | vs | cells | half | Meio half | in | Meio in | pit | Meio pit | solid | Meio solid |\n" ++
        "| --- | --- | --- | --: | --: | --: | --: | --: | --: | --: | --: | --: |\n", .{region});
    var groups: [group_names.len][buckets.len]Stat = @splat(@splat(.{}));
    for (by_kind, 0..) |by_bracket, k| {
        const kind: Kind = @fromBackingInt(@intCast(k));
        try widthRows(out, label(kind), by_bracket[0]);
        if (kind == .gold14) continue;
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
            const pct = 100 / w.cells;
            try out.print("| {s} | {s} | {s} | {d:.0} | {d:.1} | {d:.1} | {d:.0}% | {d:.0}% | {d:.0}% | {d:.0}% | {d:.0}% | {d:.0}% |\n", .{
                name,           bucket,         mode,             w.cells,          pct * w.half[0], pct * w.half[1], pct * w.inside[0], pct * w.inside[1],
                pct * w.pit[0], pct * w.pit[1], pct * w.solid[0], pct * w.solid[1],
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
                try out.writeAll(" 0 | | | | |");
            } else try out.print(" {d:.0} | {d:.0}% | {d:.0}% | {d:.1} | {d:.1} |", .{
                c.cells, 100 * c.inside / c.cells, 100 * c.pit / c.cells, c.sd(), c.claimedSd(),
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
        inline for (.{ "cells", "inside", "err", "claim", "pit" }) |f| try out.print("\tcal_{s}_{s}_{s}", .{ m, b, f });
    };
    for (mode_tags[0..2]) |m| {
        inline for (.{ "cells", "half", "half_meio", "inside", "inside_meio", "pit", "pit_meio", "solid", "solid_meio" }) |f|
            try out.print("\twidth_{s}_{s}", .{ m, f });
    }
    for (mode_tags[0..2]) |m| {
        inline for (.{ "median", "median_meio" }) |f| try out.print("\twidth_{s}_{s}", .{ m, f });
        inline for (.{
            "cells",      "width",      "below",           "above",           "width_meio", "below_meio", "above_meio",
            "miss_below", "miss_above", "miss_below_meio", "miss_above_meio", "blocks",     "ahead",
        }) |f| try out.print("\twis_{s}_{s}", .{ m, f });
        for (size_tags) |z| inline for (.{ "cells", "ref", "meio" }) |f| try out.print("\twis_{s}_{s}_{s}", .{ m, z, f });
    }
    for (weight_tags) |w| inline for (.{ "cells", "pit" }) |f| try out.print("\tpit_meio_{s}_{s}", .{ w, f });
    try out.writeAll("\tshown_meio_cells\tshown_meio_pit\n");
    for (results, regions) |by_kind, region| for (by_kind, 0..) |by_bracket, k| {
        const kind: Kind = @fromBackingInt(@intCast(k));
        for (by_bracket, brackets) |by_bucket, bracket| {
            var all: Stat = .{};
            for (by_bucket) |s| all.add(s);
            // "all": every day pooled, for what does not add up across rows (medians)
            for (by_bucket ++ [1]Stat{all}, buckets ++ [1][]const u8{"all"}) |s, bucket| try tsvRow(out, s, patch, t0, region, kind, bracket, bucket);
        }
    };
}

fn tsvRow(out: *std.Io.Writer, s: Stat, patch: []const u8, t0: i64, region: []const u8, kind: Kind, bracket: []const u8, bucket: []const u8) !void {
    if (s.target == 0) return;
    try out.print("{s}\t{d}\t{s}\t{s}\t{s}\t{s}\t{d}\t{d}\t{d}\t{d}", .{
        patch, t0, region, @tagName(kind), bracket, bucket, s.target, s.covered[0], s.covered[1], s.covered[2],
    });
    for (s.pairs) |p| {
        const d = p.diff();
        try out.print("\t{d}\t{d}\t{d:.6}\t{d:.6}\t{e:.4}\t{e:.4}", .{ p.cells, p.obs, p.challenger, p.reference, d.mean, d.se });
    }
    for (s.cal, s.sure) |by_band, sure| for (by_band ++ [1]Cal{sure}) |c| {
        try out.print("\t{d}\t{d}\t{d:.3}\t{d:.3}\t{d:.3}", .{ c.cells, c.inside, c.sd(), c.claimedSd(), c.pit });
    };
    for (s.widths) |w| try out.print("\t{d}\t{d:.6}\t{d:.6}\t{d}\t{d}\t{d:.3}\t{d:.3}\t{d}\t{d}", .{
        w.cells, w.half[0], w.half[1], w.inside[0], w.inside[1], w.pit[0], w.pit[1], w.solid[0], w.solid[1],
    });
    for (s.widths, 0..) |w, m| {
        try out.print("\t{d:.2}\t{d:.2}", .{ w.median(0) orelse 0, w.median(1) orelse 0 });
        const x = s.wisAll(m);
        try out.print("\t{d}", .{x.cells});
        for (x.parts) |side| for (side) |v| try out.print("\t{d:.6}", .{v});
        try out.print("\t{d:.3}\t{d:.3}\t{d:.3}\t{d:.3}\t{d}\t{d}", .{ x.miss[0][0], x.miss[0][1], x.miss[1][0], x.miss[1][1], s.blocks[m].n, s.blocks[m].ahead });
        for (s.wis[m]) |z| try out.print("\t{d}\t{d:.6}\t{d:.6}", .{ z.cells, z.total(0), z.total(1) });
    }
    for (s.by_weight ++ [1]Cover{s.shown}) |c| try out.print("\t{d}\t{d:.3}", .{ c.cells, c.pit });
    try out.writeAll("\n");
}

test "TSV header: one name per column, no spaces" {
    const results = try std.testing.allocator.create(Results);
    defer std.testing.allocator.destroy(results);
    results.* = @splat(@splat(@splat(@splat(.{}))));
    var w: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer w.deinit();
    try writeTsv(results, "x", 0, &w.writer);
    const header = w.written();
    try std.testing.expect(std.mem.findScalar(u8, header, ' ') == null);
    const wis_cols = 2 + 13 + 3 * sizes.len;
    try std.testing.expectEqual(10 + 6 * Comparison.count + 5 * modes.len * (bands.len + 1) + 9 * 2 + wis_cols * 2 + 2 * weight_bands.len + 2, std.mem.count(u8, header, "\t") + 1);
    try std.testing.expect(std.mem.endsWith(u8, header, "\tshown_meio_pit\n"));
    try std.testing.expect(std.mem.find(u8, header, "\twidth_patch_solid_meio\twidth_30d_median\t") != null);
    try std.testing.expect(std.mem.find(u8, header, "\tcal_meio_sure_pit\t") != null);
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

test "gold ranges: banded in gold, sd and claimed read in gold" {
    var s: Stat = .{};
    // 150-gold half-width, target mean of 100 games at 1500 sd: noise sd 150
    const hit = s.avgRange(2, 300, 150, 100, 500, 1500 * 1500);
    try std.testing.expect(hit.solid);
    // gap 200 within 1.28 * sqrt(117^2 + 150^2) = 244
    try std.testing.expect(hit.in);
    const c = s.cal[2][0];
    try std.testing.expectEqual(@as(f64, 1), c.pit);
    try std.testing.expectApproxEqAbs(150.0 / z80, c.claimedSd(), 1e-9);
    try std.testing.expectApproxEqAbs(@sqrt(200.0 * 200.0 - 150.0 * 150.0), c.sd(), 1e-9);
    // Wide range, far target: faded and out
    const far = s.avgRange(2, 0, 400, 1000, 2000, 1500 * 1500);
    try std.testing.expect(!far.solid and !far.in);
    try std.testing.expectEqual(@as(f64, 1), s.sure[2].cells);
}

test "PIT coverage: 80% for an honest range at any target size" {
    // A sure 50% against 1 game: U uniform on [0, 0.5] or [0.5, 1], 0.4 of each in [0.1, 0.9]
    // and the rest in its top or bottom tail
    for ([_][3]f64{ .{ 0, 0.8, 0.2 }, .{ 0.2, 0.8, 0 } }, [_]f64{ 1, 0 }) |want, k| {
        for (want, pitParts(0.5, 1e-9, 1, k)) |x, y| try std.testing.expectApproxEqAbs(x, y, 1e-9);
    }
    // 50 of 100 at 50%: the middle, inside; 70 of 100 at 50% +- 2 points: far out
    try std.testing.expectEqual(@as(f64, 1), pitParts(0.5, 0.02, 100, 50)[1]);
    try std.testing.expectEqual([3]f64{ 0, 0, 1 }, pitParts(0.5, 0.02, 100, 70));
    // Exact binomial and the normal past 400 games agree near 400
    const exact = binomCdf(0.52, 400, 210);
    const normal = normCdf((210.5 - 208) / @sqrt(400 * 0.52 * 0.48));
    try std.testing.expectApproxEqAbs(exact[1], normal, 0.01);
    // Averaged over every k under an honest predictive, coverage is 80%
    var cover: f64 = 0;
    var pmf = std.math.pow(f64, 0.6, 30);
    for (0..31) |k| {
        const kf: f64 = @floatFromInt(k);
        cover += pmf * pitParts(0.4, 1e-9, 30, kf)[1];
        pmf *= (30 - kf) / (kf + 1) * 0.4 / 0.6;
    }
    try std.testing.expectApproxEqAbs(0.8, cover, 1e-6);
}

test "interval score: width, misses and the point; sign test; median width; shown cells" {
    const c = 2.0 / 3.0;
    const inside = wis(0.5, 0.1, 0.1, 0.5);
    try std.testing.expectApproxEqAbs(c * 0.1 * 0.2, inside[0], 1e-12);
    try std.testing.expectEqual(@as(f64, 0), inside[1] + inside[2]);
    // 0.1 under the range: 10 x 0.1 of IS, and half of 0.2 from the point
    const low = wis(0.5, 0.1, 0.1, 0.3);
    try std.testing.expectApproxEqAbs(c * (0.1 + 0.1), low[1], 1e-12);
    // Asymmetric: up 0.3, so 0.7 is inside, scored on the point only
    const up = wis(0.5, 0.1, 0.3, 0.7);
    try std.testing.expectApproxEqAbs(c * 0.5 * 0.2, up[2], 1e-12);
    try std.testing.expectApproxEqAbs(2 * std.math.pow(f64, 0.5, 14), (Blocks{ .n = 14, .ahead = 14 }).p(), 1e-9);
    try std.testing.expectApproxEqAbs(1, (Blocks{ .n = 14, .ahead = 7 }).p(), 1e-9);

    var w: Width = .{};
    const r: Ranged = .{ .half = 0.03, .in = true, .pit = 0.7, .tails = .{ 0.3, 0 }, .solid = true, .wis = inside, .n = 100 };
    for (0..3) |_| w.cell(.{ r, r });
    try std.testing.expectApproxEqRel(3, w.median(0).?, 0.1);
    // Misses are the PIT's tails, not the score's range
    var scored: Wis = .{};
    scored.cell(.{ r, r });
    try std.testing.expectEqual([2]f64{ 0.3, 0 }, scored.miss[1]);

    // One matchup list of 12 under champion 1: the 5 highest and 5 lowest; a share list
    // of 7: the 5 most taken
    const res = try std.testing.allocator.create(Results);
    defer std.testing.allocator.destroy(res);
    res.* = @splat(@splat(@splat(@splat(.{}))));
    var list: [19]Shown = undefined;
    const top: u16 = crOf(1, .top);
    for (list[0..12], 0..) |*x, i| x.* = .{ .group = key(.matchup, 0, 0, top, 0), .p = @floatFromInt(i), .pit = 1 };
    for (list[12..], 0..) |*x, i| x.* = .{ .group = key(.build, 0, 0, top, 0), .p = @floatFromInt(i), .pit = 0.5 };
    markShown(&list, 2, res);
    try std.testing.expectEqual(@as(f64, 10), res[0][@backingInt(Kind.matchup)][0][2].shown.cells);
    try std.testing.expectEqual(@as(f64, 5), res[0][@backingInt(Kind.build)][0][2].shown.cells);
    try std.testing.expectEqual(@as(f64, 2.5), res[0][@backingInt(Kind.build)][0][2].shown.pit);
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
        fn rateIn(_: *const Model, kind: meio.Kind, _: u1, _: meio.Brackets, _: u16, _: u32) ?Estimate {
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

test "masked bracket: Gold and up, pooled; Iron-Silver only in its own" {
    const gpa = std.testing.allocator;
    const top: u16 = crOf(1, .top);
    const rows = [_]Row{
        .{ .day = 0, .patch = 0, .cr = top, .win = true, .euw = false, .bracket = 1 },
        .{ .day = 0, .patch = 0, .cr = top, .win = true, .euw = false, .bracket = 2 },
        .{ .day = 0, .patch = 0, .cr = top, .win = false, .euw = false, .bracket = 3 },
        // Targets on day 1: a cell exists only where the target has games
        .{ .day = 1, .patch = 0, .cr = top, .win = true, .euw = false, .bracket = 1 },
        .{ .day = 1, .patch = 0, .cr = top, .win = true, .euw = false, .bracket = 3 },
    };
    const opts: Options = .{ .patch = "x", .horizon = 1, .origins = 2, .min_games = 1, .threads = 1 };
    var days = try sumDays(gpa, std.testing.io, &rows, -30, 1, 1);
    defer days.deinit(gpa);
    var cells = try tally(gpa, &days, opts, 1);
    defer cells.deinit(gpa);
    const n = struct {
        fn of(c: *const Tally, bracket: usize, t: u16) f64 {
            return c.get(key(.champion, 0, bracket, t, 0)).?.w[0].n;
        }
    }.of;
    try std.testing.expectEqual(@as(f64, 3), n(&cells, 0, top));
    try std.testing.expectEqual(@as(f64, 1), n(&cells, 1, top));
    try std.testing.expectEqual(@as(f64, 2), n(&cells, masked, top));
    try std.testing.expectEqual(@as(u3, masked), unkey(key(.champion, 1, masked, top, 0)).bracket);
    try std.testing.expectEqual(@as(u4, 0b1100), bracketSet(masked).mask);
    try std.testing.expectEqual(@as(u4, 0b0010), bracketSet(1).mask);
}

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

    const results = try gpa.create(Results);
    defer gpa.destroy(results);
    results.* = @splat(@splat(@splat(@splat(.{}))));
    var model: HalfMeio.Model = .{};
    try score(HalfMeio.Model, gpa, &cells, &model, opts, 1, results);
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
    // Lean: the win against Meio's 0.5; its 2 of the role's 2 games, the top band
    try std.testing.expectEqual(@as(f64, 0.5), s.lean.all.cells.r);
    try std.testing.expectEqual(@as(f64, 1), s.lean.pop[0].cells.count);
    try std.testing.expectEqual(@as(f64, 1), s.lean.own[0].cells.count);
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
    const unseen = try gpa.create(Results);
    defer gpa.destroy(unseen);
    unseen.* = @splat(@splat(@splat(@splat(.{}))));
    const at3: Options = .{ .patch = "x", .horizon = 1, .min_games = 3 };
    try score(HalfMeio.Model, gpa, &cells, &model, at3, 1, unseen);
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
    try score(HalfMeio.Model, gpa, &cells3, &model, at3, 1, unseen);
    const p = unseen[0][@backingInt(Kind.matchup)][0][1].pairs[unseen_i];
    try std.testing.expectEqual(@as(f64, 1), p.cells);
    // Parent 30 days: 2 wins of 3, (2.5 / 4); Meio's 0.5 is worse on the win
    try std.testing.expectApproxEqAbs(-@log(0.5) + @log(2.5 / 4.0), p.diff().mean, 1e-12);

    const all = try scoreAll(HalfMeio, gpa, std.testing.io, &rows, opts);
    defer gpa.destroy(all);
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
