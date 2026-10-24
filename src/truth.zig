//! `meiolol truth` (docs/plan/estimates.md E2): how well each data mode's numbers predict
//! the next week's games on the newest patch. Rolling origin: for day d since the patch
//! went live on EUW1 (T0), every mode is built from games before T0 + d days and scored
//! on the patch's games of the `horizon` days after, per cell kind, region, rank bracket
//! and day bucket. Modes so far: the raw 30 days and the raw patch (the site's two); the
//! estimate (E3) plugs in as a third.
//!
//! Scores. Rates (win rates, build shares): binomial log loss of the target games under
//! the mode's rate, (wins + 0.5) / (games + 1) so a 0 or 100% cell scores finitely; the
//! same small-sample rule for every mode. Averages (lane gold difference at 14): squared
//! error against the target cell's mean minus that mean's noise (s^2 / n), so a mode is
//! not blamed for the target's own luck. A cell is scored only where both modes have
//! `min_games`; coverage says how much of the target that leaves. Differences are
//! paired per cell, with a standard error over cells (target games of a cell share its
//! number; overlapping horizons of nearby origins are not independent, so read it as a
//! floor)

const std = @import("std");
const store = @import("store");
const core = @import("core");
const curvesfile = core.curvesfile;
const Role = core.Role;

const Allocator = std.mem.Allocator;
const day_ms = std.time.ms_per_day;

pub const Options = struct {
    /// The newest patch ("16.20"); the boundary replayed is the one into it
    patch: []const u8,
    /// Origins d = 0 .. origins-1
    origins: u8 = 7,
    /// Target days after each origin
    horizon: u8 = 7,
    /// The raw window's days
    window: u16 = 30,
    /// A mode has a number for a cell from this many games in its window
    min_games: u32 = 10,
    /// Games from this Unix ms are never read (a held-out test window); 0: none
    until_ms: i64 = 0,
    threads: u8 = 4,
};

pub const Kind = enum(u3) {
    /// Champion-role win rate
    champion,
    /// Win rate against the lane opponent
    matchup,
    /// Bottom with its support, win rate
    duo,
    /// Lane gold difference at 14 against the opponent (an average)
    gold14,
    /// Share of a champion-role's games with a finished item
    build,

    const count = 5;

    fn label(k: Kind) []const u8 {
        return switch (k) {
            .champion => "champion-role",
            .matchup => "matchup",
            .duo => "duo (bot+sup)",
            .gold14 => "gold at 14 (matchup)",
            .build => "build share",
        };
    }
};

const regions = [_][]const u8{ "every region", "EUW1" };
const brackets = [_][]const u8{ "all ranks", "Iron-Silver", "Gold-Emerald", "Diamond+" };
const buckets = [_][]const u8{ "0", "1", "2-3", "4-7", "8+" };
const no_gold = std.math.minInt(i32);

fn bucketOf(d: usize) usize {
    return switch (d) {
        0 => 0,
        1 => 1,
        2...3 => 2,
        4...7 => 3,
        else => 4,
    };
}

/// One player in one game
pub const Row = struct {
    /// Days since T0, floored
    day: i16,
    /// champion | role << 13
    cr: u16,
    /// The lane opponent's cr; 0 none
    opp: u16 = 0,
    /// A bottom's support's cr; 0 none
    ally: u16 = 0,
    gold: i32 = no_gold,
    items: [6]u16 = @splat(0),
    win: bool,
    euw: bool,
    /// On the newest patch
    latest: bool,
    /// 0 unknown, else curvesfile.Bracket (1 low, 2 mid, 3 high)
    bracket: u2,
};

fn crOf(champion: i64, role: Role) u16 {
    return @intCast(@as(u64, @intCast(champion)) | @as(u64, @backingInt(role)) << 13);
}

fn roleOf(cr: u16) Role {
    return @fromBackingInt(@intCast(cr >> 13));
}

fn key(kind: Kind, region: usize, bracket: usize, a: u16, b: u32) u64 {
    return @as(u64, @backingInt(kind)) << 61 | @as(u64, region) << 60 | @as(u64, bracket) << 58 |
        @as(u64, a) << 32 | b;
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
};

/// The 30-day window, the patch window, the target
const Cell = struct { w: [2]Acc = .{ .{}, .{} }, t: Acc = .{} };
const Cells = std.AutoHashMapUnmanaged(u64, Cell);

/// Sums for one (region, kind, bracket, bucket)
pub const Stat = struct {
    /// Target observations (games; for build share, champion-role games x items) in
    /// cells where any mode or the target had something
    target: f64 = 0,
    /// Of them, in cells where each mode has a number
    covered: [2]f64 = .{ 0, 0 },
    /// Scored: both modes have a number
    obs: f64 = 0,
    cells: f64 = 0,
    /// Rates: log loss; averages: noise-corrected squared error times games
    loss: [2]f64 = .{ 0, 0 },
    /// Per cell difference (30 days minus patch): sums for its standard error
    d: f64 = 0,
    dd: f64 = 0,
    dn: f64 = 0,
    nn: f64 = 0,

    fn add(s: *Stat, o: Stat) void {
        inline for (@typeInfo(Stat).@"struct".field_names) |name| {
            switch (@TypeOf(@field(s, name))) {
                f64 => @field(s, name) += @field(o, name),
                [2]f64 => for (0..2) |i| {
                    @field(s, name)[i] += @field(o, name)[i];
                },
                else => comptime unreachable,
            }
        }
    }

    fn cell(s: *Stat, n: f64, l0: f64, l1: f64) void {
        s.obs += n;
        s.cells += 1;
        s.loss[0] += l0;
        s.loss[1] += l1;
        const d = l0 - l1;
        s.d += d;
        s.dd += d * d;
        s.dn += d * n;
        s.nn += n * n;
    }

    /// Mean difference per observation and its standard error, clustered by cell
    fn diff(s: Stat) struct { mean: f64, se: f64 } {
        if (s.obs == 0) return .{ .mean = 0, .se = 0 };
        const m = s.d / s.obs;
        const v = @max(0, s.dd - 2 * m * s.dn + m * m * s.nn);
        return .{ .mean = m, .se = @sqrt(v) / s.obs };
    }
};

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

fn tally(gpa: Allocator, rows: []const Row, opts: Options, d: i32) !Cells {
    var cells: Cells = .empty;
    errdefer cells.deinit(gpa);
    for (rows) |r| {
        const in30 = r.day >= d - @as(i32, opts.window) and r.day < d;
        const in_patch = r.latest and r.day < d;
        const in_target = r.latest and r.day >= d and r.day < d + @as(i32, opts.horizon);
        if (!in30 and !in_target) continue;
        const y: f64 = if (r.win) 1 else 0;
        for (0..2) |region| {
            if (region == 1 and !r.euw) continue;
            for ([_]usize{ 0, r.bracket }, 0..) |bracket, i| {
                if (i == 1 and bracket == 0) continue;
                const Add = struct {
                    fn add(cs: *Cells, g: Allocator, k: u64, v: f64, slots: [3]bool) !void {
                        const e = try cs.getOrPut(g, k);
                        if (!e.found_existing) e.value_ptr.* = .{};
                        if (slots[0]) e.value_ptr.w[0].add(v);
                        if (slots[1]) e.value_ptr.w[1].add(v);
                        if (slots[2]) e.value_ptr.t.add(v);
                    }
                };
                const slots = [3]bool{ in30, in_patch, in_target };
                try Add.add(&cells, gpa, key(.champion, region, bracket, r.cr, 0), y, slots);
                if (r.opp != 0) try Add.add(&cells, gpa, key(.matchup, region, bracket, r.cr, r.opp), y, slots);
                if (r.ally != 0) try Add.add(&cells, gpa, key(.duo, region, bracket, r.cr, r.ally), y, slots);
                if (r.gold != no_gold) {
                    try Add.add(&cells, gpa, key(.gold14, region, bracket, r.cr, r.opp), @floatFromInt(r.gold), slots);
                }
                for (r.items) |item| {
                    if (item != 0) try Add.add(&cells, gpa, key(.build, region, bracket, r.cr, item), 1, slots);
                }
            }
        }
    }
    return cells;
}

fn score(cells: *const Cells, opts: Options, bucket: usize, out: *Results) void {
    var it = cells.iterator();
    while (it.next()) |e| {
        const k = e.key_ptr.*;
        const kind: Kind = @fromBackingInt(@intCast(k >> 61));
        const region: usize = @intCast(k >> 60 & 1);
        const bracket: usize = @intCast(k >> 58 & 3);
        const s = &out[region][@backingInt(kind)][bracket][bucket];
        const c = e.value_ptr.*;
        // A build cell counts the item; its games are the champion-role's
        const games: Cell = if (kind == .build) blk: {
            const a: u16 = @intCast(k >> 32 & 0xffff);
            break :blk cells.get(key(.champion, region, bracket, a, 0)) orelse continue;
        } else c;
        const n = games.t.n;
        if (n == 0) continue;
        s.target += n;
        var have: [2]bool = undefined;
        for (0..2) |m| {
            have[m] = games.w[m].n >= @as(f64, @floatFromInt(opts.min_games));
            if (have[m]) s.covered[m] += n;
        }
        if (!have[0] or !have[1]) continue;
        switch (kind) {
            .gold14 => {
                if (n < 2) continue;
                s.cell(n, avgError(c.w[0].s / c.w[0].n, c.t), avgError(c.w[1].s / c.w[1].n, c.t));
            },
            else => s.cell(
                n,
                logLoss(rate(games.w[0], c.w[0].s), n, c.t.s),
                logLoss(rate(games.w[1], c.w[1].s), n, c.t.s),
            ),
        }
    }
}

const Job = struct {
    rows: []const Row,
    opts: Options,
    next: std.atomic.Value(usize) = .init(0),
    mutex: std.Io.Mutex = .init,
    io: std.Io,
    results: *Results,
    failed: ?anyerror = null,

    fn run(j: *Job) void {
        const gpa = std.heap.smp_allocator;
        while (true) {
            const d = j.next.fetchAdd(1, .monotonic);
            if (d >= j.opts.origins) return;
            var cells = tally(gpa, j.rows, j.opts, @intCast(d)) catch |err| {
                j.failed = err;
                return;
            };
            defer cells.deinit(gpa);
            var part: Results = @splat(@splat(@splat(@splat(.{}))));
            score(&cells, j.opts, bucketOf(d), &part);
            j.mutex.lockUncancelable(j.io);
            defer j.mutex.unlock(j.io);
            for (j.results, part) |*a, b| for (a, b) |*a2, b2| for (a2, b2) |*a3, b3| for (a3, b3) |*s, o| s.add(o);
        }
    }
};

/// T0: the patch's first ranked solo game on EUW1, Unix ms
pub fn patchStart(db: store.Db, patch: []const u8) !i64 {
    return try db.scalar(
        "SELECT min(game_start) FROM matches WHERE patch = ?1 AND platform = 'EUW1' AND queue_id = 420",
        .{patch},
    ) orelse error.PatchNotFound;
}

/// Ranked solo players of games from `from_ms` to `to_ms`, lane opponents, supports and
/// gold differences paired within each game
pub fn load(gpa: Allocator, db: store.Db, patch: []const u8, t0: i64, from_ms: i64, to_ms: i64, legendary: ?*const std.AutoHashMapUnmanaged(u32, void)) ![]Row {
    var rows: std.ArrayList(Row) = .empty;
    errdefer rows.deinit(gpa);
    var stmt = try db.prepare(
        \\SELECT m.rowid, m.game_start, m.platform = 'EUW1', m.patch = ?1, p.team_id, p.position,
        \\  p.champion_id, p.win, p.tier, p.gold14, p.item0, p.item1, p.item2, p.item3, p.item4,
        \\  p.item5
        \\FROM matches m JOIN participants p ON p.match_id = m.match_id
        \\WHERE m.queue_id = 420 AND m.remake = 0 AND m.game_start >= ?2 AND m.game_start < ?3
    );
    defer stmt.deinit();
    try stmt.bind(.{ patch, from_ms, to_ms });
    var game: i64 = -1;
    var first: usize = 0;
    var teams: [10]i64 = undefined;
    var golds: [10]?i64 = undefined;
    while (try stmt.step()) {
        const id = stmt.int(0);
        if (id != game) {
            pair(rows.items[first..], teams[0..@min(10, rows.items.len - first)], golds[0..@min(10, rows.items.len - first)]);
            game = id;
            first = rows.items.len;
        }
        const role = Role.fromLcu(stmt.bytes(5)) orelse continue;
        const i = rows.items.len - first;
        if (i >= 10) continue;
        var r: Row = .{
            .day = @intCast(@divFloor(stmt.int(1) - t0, day_ms)),
            .cr = crOf(stmt.int(6), role),
            .win = stmt.int(7) != 0,
            .euw = stmt.int(2) != 0,
            .latest = stmt.int(3) != 0,
            .bracket = if (curvesfile.tierRank(stmt.bytes(8))) |t| @intCast(@backingInt(curvesfile.Bracket.ofRank(t))) else 0,
        };
        var n: usize = 0;
        for (10..16) |col| {
            const item = stmt.int(@intCast(col));
            if (item <= 0 or item > std.math.maxInt(u16)) continue;
            if (legendary) |l| if (!l.contains(@intCast(item))) continue;
            if (std.mem.findScalar(u16, r.items[0..n], @intCast(item)) != null) continue;
            r.items[n] = @intCast(item);
            n += 1;
        }
        teams[i] = stmt.int(4);
        golds[i] = stmt.optInt(9);
        try rows.append(gpa, r);
    }
    pair(rows.items[first..], teams[0..@min(10, rows.items.len - first)], golds[0..@min(10, rows.items.len - first)]);
    return rows.toOwnedSlice(gpa);
}

/// Fills each player's lane opponent, a bottom's support and the gold difference at 14
fn pair(game: []Row, teams: []const i64, golds: []const ?i64) void {
    for (game, 0..) |*r, i| {
        for (game, 0..) |o, j| {
            if (roleOf(o.cr) != roleOf(r.cr)) {
                if (teams[j] == teams[i] and roleOf(r.cr) == .bottom and roleOf(o.cr) == .utility) r.ally = o.cr;
                continue;
            }
            if (teams[j] == teams[i]) continue;
            r.opp = o.cr;
            if (golds[i]) |a| if (golds[j]) |b| {
                r.gold = @intCast(a - b);
            };
        }
    }
}

pub fn run(gpa: Allocator, io: std.Io, db: store.Db, opts: Options, legendary: ?*const std.AutoHashMapUnmanaged(u32, void), out: *std.Io.Writer) !void {
    const t0 = try patchStart(db, opts.patch);
    const from = t0 - @as(i64, opts.window) * day_ms;
    var to = t0 + (@as(i64, opts.origins) - 1 + opts.horizon) * day_ms;
    if (opts.until_ms != 0) to = @min(to, opts.until_ms);
    const rows = try load(gpa, db, opts.patch, t0, from, to, legendary);
    defer gpa.free(rows);

    var results: Results = @splat(@splat(@splat(@splat(.{}))));
    var job: Job = .{ .rows = rows, .opts = opts, .io = io, .results = &results };
    var threads: [16]std.Thread = undefined;
    const n = @min(@max(opts.threads, 1), threads.len, opts.origins);
    for (threads[0..n]) |*t| t.* = try std.Thread.spawn(.{}, Job.run, .{&job});
    for (threads[0..n]) |t| t.join();
    if (job.failed) |err| return err;

    try out.print("# Truth test into {s}\n\nT0 (first EUW1 game) {d} ms; origins day 0-{d}, " ++
        "{d}-day targets, {d}-day raw window, a number from {d} games; {d} player rows read" ++
        "{s}\n\n", .{
        opts.patch,                                                                                                                                     t0, opts.origins - 1, opts.horizon, opts.window, opts.min_games, rows.len,
        if (opts.until_ms != 0 and opts.until_ms < t0 + (@as(i64, opts.origins) - 1 + opts.horizon) * day_ms) "; targets cut short by --until" else "",
    });
    try report(&results, out);
}

pub fn report(results: *const Results, out: *std.Io.Writer) !void {
    try out.writeAll("Rates: milli-nats per target observation (lower is better). Gold: noise-" ++
        "corrected RMSE in gold, the difference in gold^2. Diff: 30 days minus patch, " ++
        "+- 2 se over cells (negative: the 30 days predicted better)\n");
    for (results, regions) |by_kind, region| {
        try out.print("\n## {s}\n\n| cell | ranks | day | cells | covered 30d / patch | 30 days | patch | diff |\n" ++
            "| --- | --- | --- | --: | --: | --: | --: | --: |\n", .{region});
        for (by_kind, 0..) |by_bracket, k| {
            const kind: Kind = @fromBackingInt(@intCast(k));
            for (by_bracket, brackets) |by_bucket, bracket| {
                var all: Stat = .{};
                for (by_bucket) |s| all.add(s);
                for (by_bucket ++ [1]Stat{all}, buckets ++ [1][]const u8{"all"}) |s, bucket| {
                    if (s.obs == 0) continue;
                    try row(out, kind, bracket, bucket, s);
                }
            }
        }
    }
}

fn row(out: *std.Io.Writer, kind: Kind, bracket: []const u8, bucket: []const u8, s: Stat) !void {
    const d = s.diff();
    try out.print("| {s} | {s} | {s} | {d:.0} | {d:.0}% / {d:.0}% | ", .{
        kind.label(), bracket, bucket, s.cells, 100 * s.covered[0] / s.target, 100 * s.covered[1] / s.target,
    });
    if (kind == .gold14) {
        try out.print("{d:.0} | {d:.0} | {d:.0} +- {d:.0} |\n", .{
            @sqrt(@max(0, s.loss[0] / s.obs)), @sqrt(@max(0, s.loss[1] / s.obs)), d.mean, 2 * d.se,
        });
    } else {
        try out.print("{d:.1} | {d:.1} | {d:.2} +- {d:.2} |\n", .{
            1000 * s.loss[0] / s.obs, 1000 * s.loss[1] / s.obs, 1000 * d.mean, 2000 * d.se,
        });
    }
}

test "log loss and the noise-corrected squared error" {
    try std.testing.expectApproxEqAbs(@log(2.0) * 4, logLoss(0.5, 4, 1), 1e-12);
    // A target of four games at 100, 0, 100, 0: mean 50, noise s^2/n = 3333/4
    var t: Acc = .{};
    for ([_]f64{ 100, 0, 100, 0 }) |y| t.add(y);
    try std.testing.expectApproxEqAbs(4 * (0 - 10000.0 / 3.0 / 4.0), avgError(50, t), 1e-9);
    try std.testing.expectApproxEqAbs(4 * (100 - 10000.0 / 3.0 / 4.0), avgError(60, t), 1e-9);
}

test "rolling origin: windows, target and pairing" {
    const gpa = std.testing.allocator;
    const top: u16 = crOf(1, .top);
    const opp: u16 = crOf(2, .top);
    // Day -1: champion 1 wins on the old patch; day 0 and 1 on the new: a loss, a win
    const rows = [_]Row{
        .{ .day = -1, .cr = top, .opp = opp, .win = true, .euw = false, .latest = false, .bracket = 0 },
        .{ .day = 0, .cr = top, .opp = opp, .win = false, .euw = true, .latest = true, .bracket = 3 },
        .{ .day = 1, .cr = top, .opp = opp, .win = true, .euw = true, .latest = true, .bracket = 3 },
    };
    var cells = try tally(gpa, &rows, .{ .patch = "x", .horizon = 1 }, 1);
    defer cells.deinit(gpa);
    const c = cells.get(key(.champion, 0, 0, top, 0)).?;
    // Before day 1: both games in 30 days, the day-0 loss in the patch; target: day 1
    try std.testing.expectEqual(@as(f64, 2), c.w[0].n);
    try std.testing.expectEqual(@as(f64, 1), c.w[0].s);
    try std.testing.expectEqual(@as(f64, 1), c.w[1].n);
    try std.testing.expectEqual(@as(f64, 0), c.w[1].s);
    try std.testing.expectEqual(@as(f64, 1), c.t.s);
    const euw = cells.get(key(.matchup, 1, 3, top, opp)).?;
    try std.testing.expectEqual(@as(f64, 1), euw.w[0].n);

    var results: Results = @splat(@splat(@splat(@splat(.{}))));
    score(&cells, .{ .patch = "x", .min_games = 1 }, 1, &results);
    const s = results[0][@backingInt(Kind.champion)][0][1];
    try std.testing.expectEqual(@as(f64, 1), s.obs);
    // 30 days says 0.5 (1.5/3), the patch 0.25 (0.5/2): the win costs more under the patch
    try std.testing.expectApproxEqAbs(-@log(0.5) + @log(0.25), s.diff().mean, 1e-12);

    var game = [_]Row{
        .{ .day = 0, .cr = crOf(1, .bottom), .win = true, .euw = true, .latest = true, .bracket = 0 },
        .{ .day = 0, .cr = crOf(3, .utility), .win = true, .euw = true, .latest = true, .bracket = 0 },
        .{ .day = 0, .cr = crOf(4, .bottom), .win = false, .euw = true, .latest = true, .bracket = 0 },
    };
    pair(&game, &.{ 100, 100, 200 }, &.{ 5000, null, 4200 });
    try std.testing.expectEqual(crOf(3, .utility), game[0].ally);
    try std.testing.expectEqual(crOf(4, .bottom), game[0].opp);
    try std.testing.expectEqual(@as(i32, 800), game[0].gold);
    try std.testing.expectEqual(@as(u16, 0), game[2].ally);
}
