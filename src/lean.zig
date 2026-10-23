//! `meiolol lean`: does a champion in its role lean early or late? Two facts per
//! champion-role for its champion page, from ranked solo games with a compact timeline
//! (docs/model.md "Early and late champions"): how far ahead its team usually is at
//! gold_minute (the team gold lead), and how its team wins from an even game at
//! win_minute (log-odds beyond a logistic of the state then: team gold, XP and the
//! objectives held). Both additive over the ten picks of a game, one row per game, each
//! champion-role's effect shrunk toward its role's average pick by a method-of-moments
//! prior per role (analysis.Prior). Descriptive: who picks a champion is not held fixed,
//! and "even" is even by these measures. `--check`: the lab's folds and dev-val, never a
//! game from the test cut on.

const std = @import("std");
const store = @import("store");
const core = @import("core");
const stats = @import("stats.zig");
const eval = @import("eval.zig");
const analysis = @import("analysis.zig");
const logreg = @import("logreg.zig");
const objectives = @import("objectives.zig");
const digest = @import("riot/digest.zig");
const Date = @import("date.zig").Date;
const Role = core.Role;
const Io = std.Io;

pub const gold_minute = 14;
pub const win_minute = 20;
/// Fewer fit games still going at win_minute and the champion-role says nothing
pub const min_games = 200;
/// An effect is clear this many posterior sds from 0
pub const clear_z = 2.0;
const passes = 12;
/// Champions in the game, with room for new ones
const max_champs = 512;
const minute_ms = 60_000;

/// The baseline's state at win_minute, blue minus red
const state_feats = objectives.lead ++ objectives.held;

comptime {
    // stateAt(win_minute) needs win_minute + 2 frames
    std.debug.assert(digest.max_frames >= win_minute + 2);
}
const n_state = state_feats.len;

pub const Game = struct {
    start: i64,
    /// Dense champion index by side (blue, red) and role
    champ: [2][Role.count]u16,
    blue_won: bool,
    /// Team gold lead at gold_minute, blue minus red, thousands
    gold: f32,
    /// Still going at win_minute
    late: bool,
    x: [n_state]f32,
};

pub const Games = struct {
    list: std.ArrayList(Game) = .empty,
    champs: analysis.DenseIndex = .{},

    pub fn deinit(g: *Games, gpa: std.mem.Allocator) void {
        g.list.deinit(gpa);
        g.champs.deinit(gpa);
    }
};

/// Played games (eval.min_duration_s) reaching 15:00 with a timeline, started in
/// [since_ms, before_ms)
pub fn load(
    gpa: std.mem.Allocator,
    io: std.Io,
    db: store.Db,
    patches: []const []const u8,
    platforms: []const []const u8,
    since_ms: i64,
    before_ms: i64,
) !Games {
    var scanned: analysis.GameList = .{ .gpa = gpa };
    defer scanned.items.deinit(gpa);
    _ = try stats.scanAhead(gpa, io, db, patches, platforms, since_ms, &scanned);
    var by_id: std.AutoHashMapUnmanaged(u64, u32) = .empty;
    defer by_id.deinit(gpa);
    for (scanned.items.items, 0..) |g, i| {
        if (g.duration_s >= eval.min_duration_s and g.start < before_ms) try by_id.put(gpa, g.id, @intCast(i));
    }
    var out: Games = .{};
    errdefer out.deinit(gpa);
    var tg: analysis.TimelineGames = try .initDigests(gpa, io, db, patches, platforms, since_ms);
    defer tg.deinit();
    while (try tg.next()) |game| {
        const i = by_id.get(stats.matchKey(game.match_id)) orelse continue;
        const t = game.t;
        if (t.participants != 10 or t.frames.len < 16 or t.frames[15].t_ms < 15 * minute_ms) continue;
        // Checks ids 1-5 are blue, as stateAt's sums take them
        _ = try tg.pids(game) orelse continue;
        const early = objectives.stateAt(t, gold_minute) orelse continue;
        const row = scanned.items.items[i];
        var g: Game = .{
            .start = row.start,
            .champ = undefined,
            .blue_won = row.winner == 0,
            .gold = early[@backingInt(objectives.Feat.gold)],
            .late = false,
            .x = @splat(0),
        };
        for (0..2) |side| for (0..Role.count) |ri| {
            g.champ[side][ri] = try out.champs.get(gpa, row.teams[side][ri]);
        };
        if (objectives.stateAt(t, win_minute)) |s| {
            g.late = true;
            for (state_feats, &g.x) |f, *v| v.* = s[@backingInt(f)];
        }
        try out.list.append(gpa, g);
    }
    return out;
}

/// A seat's cell (role first) and sign (blue +1)
const Seat = struct { cell: usize, s: f64 };

fn seats(g: Game, champs: usize) [2 * Role.count]Seat {
    var out: [2 * Role.count]Seat = undefined;
    for (0..2) |side| for (0..Role.count) |ri| {
        out[side * Role.count + ri] = .{
            .cell = ri * champs + g.champ[side][ri],
            .s = if (side == 0) 1 else -1,
        };
    };
    return out;
}

/// Shrunk effects per cell (role * champs + champion)
pub const Effects = struct {
    b: []f64,
    /// Posterior sd (0: the role's prior is off, so is the effect)
    sd: []f64,
    /// Games behind each cell
    n: []f64,
    /// [role]: spread of true effects
    tau: [Role.count]f64 = @splat(0),

    fn init(gpa: std.mem.Allocator, cells: usize) !Effects {
        const e: Effects = .{
            .b = try gpa.alloc(f64, cells),
            .sd = try gpa.alloc(f64, cells),
            .n = try gpa.alloc(f64, cells),
        };
        @memset(e.b, 0);
        @memset(e.sd, 0);
        @memset(e.n, 0);
        return e;
    }

    fn deinit(e: Effects, gpa: std.mem.Allocator) void {
        gpa.free(e.b);
        gpa.free(e.sd);
        gpa.free(e.n);
    }

    /// Enough games and clear of 0
    pub fn clear(e: Effects, cell: usize) bool {
        return e.n[cell] >= min_games and e.sd[cell] > 0 and @abs(e.b[cell]) >= clear_z * e.sd[cell];
    }

    /// The effect if clear, else 0
    fn shown(e: Effects, cell: usize) f64 {
        return if (e.clear(cell)) e.b[cell] else 0;
    }
};

pub const Fit = struct {
    champs: usize,
    /// Thousands of team gold at gold_minute
    gold: Effects,
    gold_mean: f64,
    /// Log-odds at win_minute beyond the state
    win: Effects,
    base: [1 + n_state]f64,

    pub fn deinit(f: Fit, gpa: std.mem.Allocator) void {
        f.gold.deinit(gpa);
        f.win.deinit(gpa);
    }

    fn goldPred(f: *const Fit, g: Game, only_clear: bool) f64 {
        var sum = f.gold_mean;
        for (seats(g, f.champs)) |st| sum += st.s * if (only_clear) f.gold.shown(st.cell) else f.gold.b[st.cell];
        return sum;
    }

    fn baseEta(f: *const Fit, g: Game) f64 {
        var sum = f.base[0];
        for (g.x, f.base[1..]) |x, w| sum += x * w;
        return sum;
    }

    fn winEta(f: *const Fit, g: Game, only_clear: bool) f64 {
        var sum = f.baseEta(g);
        for (seats(g, f.champs)) |st| sum += st.s * if (only_clear) f.win.shown(st.cell) else f.win.b[st.cell];
        return sum;
    }

    /// Early: ahead at gold_minute and wins less from even; late: the other way round
    pub fn lean(f: *const Fit, cell: usize) Lean {
        return classify(f.gold, f.win, cell);
    }
};

pub const Lean = enum { early, late, none };

fn classify(gold: Effects, win: Effects, cell: usize) Lean {
    if (!gold.clear(cell) or !win.clear(cell)) return .none;
    if (gold.b[cell] > 0 and win.b[cell] < 0) return .early;
    if (gold.b[cell] < 0 and win.b[cell] > 0) return .late;
    return .none;
}

/// Every effect from `games` (fit on all of them)
/// Cells with fewer games are left out of each role's prior (analysis.Prior's own
/// floor is 10): a role's many rare off-role picks have noise far above the spread
pub const default_prior_rows = 100;

pub fn fit(gpa: std.mem.Allocator, games: []const Game, champs: usize) !Fit {
    return fitWith(gpa, games, champs, default_prior_rows);
}

pub fn fitWith(gpa: std.mem.Allocator, games: []const Game, champs: usize, prior_rows: f64) !Fit {
    if (champs > max_champs) return error.TooManyChampions;
    const cells = Role.count * champs;
    var gold = try Effects.init(gpa, cells);
    errdefer gold.deinit(gpa);
    var win = try Effects.init(gpa, cells);
    errdefer win.deinit(gpa);
    var f: Fit = .{ .champs = champs, .gold = gold, .gold_mean = 0, .win = win, .base = undefined };
    f.gold_mean = try fitGold(gpa, games, champs, &f.gold, prior_rows);
    f.base = try fitWin(gpa, games, champs, &f.win, prior_rows);
    return f;
}

/// Backfitting of the Gaussian team gold lead, one role at a time (Gauss-Seidel: a duo's
/// picks go together, so updating every role at once can trade effects between them);
/// returns the fit mean
fn fitGold(gpa: std.mem.Allocator, games: []const Game, champs: usize, e: *Effects, prior_rows: f64) !f64 {
    var mean: f64 = 0;
    for (games) |g| mean += g.gold;
    mean /= @floatFromInt(@max(games.len, 1));
    const res = try gpa.alloc(f64, games.len);
    defer gpa.free(res);
    for (res, games) |*r, g| r.* = g.gold - mean;
    const sxr = try gpa.alloc(f64, e.b.len);
    defer gpa.free(sxr);
    const old = try gpa.alloc(f64, e.b.len);
    defer gpa.free(old);
    for (0..passes) |_| for (0..Role.count) |ri| {
        const lo = ri * champs;
        @memset(sxr[lo..][0..champs], 0);
        @memset(e.n[lo..][0..champs], 0);
        var sum_sq: f64 = 0;
        for (games, res) |g, r| {
            sum_sq += r * r;
            for (0..2) |side| {
                const c = lo + g.champ[side][ri];
                sxr[c] += sign(side) * r + e.b[c];
                e.n[c] += 1;
            }
        }
        const sigma2 = sum_sq / @as(f64, @floatFromInt(@max(games.len, 1)));
        @memcpy(old[lo..][0..champs], e.b[lo..][0..champs]);
        shrinkRole(e, ri, sxr, e.n, sigma2, champs, prior_rows);
        for (games, res) |g, *r| {
            for (0..2) |side| {
                const c = lo + g.champ[side][ri];
                r.* -= sign(side) * (e.b[c] - old[c]);
            }
        }
    };
    return mean;
}

fn sign(side: usize) f64 {
    return if (side == 0) 1 else -1;
}

/// A logistic baseline on the state, then IRLS backfitting of the champion effects on
/// top, one role at a time as fitGold (working response: unit variance per unit of
/// weight); returns the baseline's weights
fn fitWin(gpa: std.mem.Allocator, games: []const Game, champs: usize, e: *Effects, prior_rows: f64) ![1 + n_state]f64 {
    var late: std.ArrayList(Game) = .empty;
    defer late.deinit(gpa);
    for (games) |g| if (g.late) try late.append(gpa, g);
    const rows = try gpa.alloc(logreg.Row, late.items.len);
    defer gpa.free(rows);
    for (rows, late.items) |*r, g| r.* = baseRow(g);
    const wt = try logreg.fit(gpa, 1 + n_state, rows, 1);
    defer gpa.free(wt);
    var base: [1 + n_state]f64 = undefined;
    @memcpy(&base, wt);

    const eta = try gpa.alloc(f64, late.items.len);
    defer gpa.free(eta);
    for (eta, rows) |*x, r| x.* = r.dot(wt);
    const sxr = try gpa.alloc(f64, e.b.len);
    defer gpa.free(sxr);
    const sxx = try gpa.alloc(f64, e.b.len);
    defer gpa.free(sxx);
    const old = try gpa.alloc(f64, e.b.len);
    defer gpa.free(old);
    for (0..passes) |_| for (0..Role.count) |ri| {
        const lo = ri * champs;
        @memset(sxr[lo..][0..champs], 0);
        @memset(sxx[lo..][0..champs], 0);
        @memset(e.n[lo..][0..champs], 0);
        for (late.items, eta) |g, x| {
            const p = logreg.sigmoid(x);
            const w = p * (1 - p);
            const r = @as(f64, @floatFromInt(@intFromBool(g.blue_won))) - p;
            for (0..2) |side| {
                const c = lo + g.champ[side][ri];
                sxr[c] += sign(side) * r + e.b[c] * w;
                sxx[c] += w;
                e.n[c] += 1;
            }
        }
        @memcpy(old[lo..][0..champs], e.b[lo..][0..champs]);
        shrinkRole(e, ri, sxr, sxx, 1, champs, prior_rows);
        for (late.items, eta) |g, *x| {
            for (0..2) |side| {
                const c = lo + g.champ[side][ri];
                x.* += sign(side) * (e.b[c] - old[c]);
            }
        }
    };
    return base;
}

fn baseRow(g: Game) logreg.Row {
    var r: logreg.Row = .{ .y = @floatFromInt(@intFromBool(g.blue_won)) };
    r.add(0, 1);
    for (g.x, 1..) |v, i| r.add(@intCast(i), v);
    return r;
}

/// One role's cells shrunk with its prior: info is the rows over sigma2 (Gaussian) or
/// the summed IRLS weights (sigma2 1); n, the games, sets which cells count toward it
fn shrinkRole(e: *Effects, ri: usize, sxr: []const f64, info: []const f64, sigma2: f64, champs: usize, prior_rows: f64) void {
    const lo = ri * champs;
    var counted: [max_champs]f64 = undefined;
    for (counted[0..champs], e.n[lo..][0..champs]) |*x, n| x.* = if (n >= prior_rows) n else 0;
    const prior: analysis.Prior = .estimate(sxr[lo..][0..champs], info[lo..][0..champs], counted[0..champs], sigma2);
    e.tau[ri] = @sqrt(prior.tau2);
    for (lo..lo + champs) |c| {
        e.b[c] = prior.effect(sxr[c], info[c]);
        e.sd[c] = if (prior.tau2 > 0) @sqrt(sigma2 / (info[c] + prior.k)) else 0;
    }
}

// ---- The file the site reads

pub const version = 1;

/// One champion-role, in display units
pub const Row = struct {
    champion: u32,
    role: Role,
    /// Fit games still going at win_minute
    games: u32,
    /// Team gold lead at gold_minute against the role's average pick, ± its sd
    gold: f64,
    gold_sd: f64,
    /// Win pp from an even game at win_minute against the role's average pick (log-odds
    /// x 25: the change at 50%), ± its sd
    win: f64,
    win_sd: f64,

    fn effects(r: Row) [2]Effects1 {
        return .{ .{ .b = r.gold, .sd = r.gold_sd, .n = r.games }, .{ .b = r.win, .sd = r.win_sd, .n = r.games } };
    }

    pub fn goldClear(r: Row) bool {
        return r.effects()[0].clear();
    }

    pub fn winClear(r: Row) bool {
        return r.effects()[1].clear();
    }

    pub fn enough(r: Row) bool {
        return r.games >= min_games;
    }

    pub fn lean(r: Row) Lean {
        if (!r.goldClear() or !r.winClear()) return .none;
        if (r.gold > 0 and r.win < 0) return .early;
        if (r.gold < 0 and r.win > 0) return .late;
        return .none;
    }
};

const Effects1 = struct {
    b: f64,
    sd: f64,
    n: u32,

    fn clear(e: Effects1) bool {
        return e.n >= min_games and e.sd > 0 and @abs(e.b) >= clear_z * e.sd;
    }
};

pub const File = struct {
    /// Fit games (reaching 15:00)
    games: u32,
    /// Unix ms of the oldest and newest game start
    from_ms: i64,
    to_ms: i64,
    /// "every region", "EUW"
    scope: []const u8,
    rows: []const Row,

    pub fn get(f: *const File, champion: u32, role: Role) ?Row {
        for (f.rows) |r| if (r.champion == champion and r.role == role) return r;
        return null;
    }

    /// The TSV `write` makes
    pub fn parse(arena: std.mem.Allocator, bytes: []const u8) !File {
        var lines = std.mem.tokenizeScalar(u8, bytes, '\n');
        const head = lines.next() orelse return error.BadLean;
        var hf = std.mem.splitScalar(u8, head, '\t');
        if (!std.mem.eql(u8, hf.next() orelse "", "meiolol-lean")) return error.BadLean;
        if (try int(u32, hf.next()) != version) return error.BadLean;
        var f: File = .{
            .games = try int(u32, hf.next()),
            .from_ms = try int(i64, hf.next()),
            .to_ms = try int(i64, hf.next()),
            .scope = try arena.dupe(u8, hf.next() orelse return error.BadLean),
            .rows = &.{},
        };
        _ = lines.next() orelse return error.BadLean;
        var rows: std.ArrayList(Row) = .empty;
        while (lines.next()) |line| {
            var it = std.mem.splitScalar(u8, line, '\t');
            try rows.append(arena, .{
                .champion = try int(u32, it.next()),
                .role = std.meta.stringToEnum(Role, it.next() orelse "") orelse return error.BadLean,
                .games = try int(u32, it.next()),
                .gold = try float(it.next()),
                .gold_sd = try float(it.next()),
                .win = try float(it.next()),
                .win_sd = try float(it.next()),
            });
        }
        f.rows = rows.items;
        return f;
    }

    fn int(comptime T: type, s: ?[]const u8) !T {
        return std.fmt.parseInt(T, s orelse return error.BadLean, 10) catch error.BadLean;
    }

    fn float(s: ?[]const u8) !f64 {
        return std.fmt.parseFloat(f64, s orelse return error.BadLean) catch error.BadLean;
    }
};

/// The site's file: a fit on every game loaded, one row per champion-role with games at
/// win_minute
pub fn write(w: *Io.Writer, f: *const Fit, ids: []const u32, games: []const Game, scope: []const u8) !void {
    var from: i64 = std.math.maxInt(i64);
    var to: i64 = 0;
    for (games) |g| {
        from = @min(from, g.start);
        to = @max(to, g.start);
    }
    try w.print("meiolol-lean\t{d}\t{d}\t{d}\t{d}\t{s}\n", .{ version, games.len, from, to, scope });
    try w.writeAll("champion\trole\tgames\tgold\tgold_sd\twin_pp\twin_sd\n");
    for (0..Role.count * f.champs) |c| {
        if (f.win.n[c] == 0) continue;
        try w.print("{d}\t{t}\t{d}\t{d:.0}\t{d:.0}\t{d:.2}\t{d:.2}\n", .{
            ids[c % f.champs],  @as(Role, @fromBackingInt(@intCast(c / f.champs))), @as(u32, @trunc(f.win.n[c])),
            1000 * f.gold.b[c], 1000 * f.gold.sd[c],                                25 * f.win.b[c],
            25 * f.win.sd[c],
        });
    }
}

// ---- The lab check

/// Fold starts b_0-b_4, the dev cut, the test cut (harness.Cuts)
pub const Cuts = [7]i64;

pub fn labCuts(e: eval.Cuts) Cuts {
    var c: Cuts = undefined;
    @memcpy(c[0..5], e.bounds[0..5]);
    c[5] = e.dev;
    c[6] = e.test_;
    return c;
}

/// Held-out sums for one block (or several pooled)
const Score = struct {
    win: analysis.PairedSums = .{},
    win_clear: analysis.PairedSums = .{},
    /// clear-only minus shrunk: what hiding the unclear effects costs
    win_hide: analysis.PairedSums = .{},
    gold: analysis.PairedSums = .{},
    gold_clear: analysis.PairedSums = .{},
    gold_base: f64 = 0,
    /// Calibration of fitted effects on the block's own: sum wt b h, sum wt b^2 (all
    /// cells; clear cells)
    win_cal: [2][2]f64 = @splat(@splat(0)),
    gold_cal: [2][2]f64 = @splat(@splat(0)),
    /// Clear cells: in the block, same sign; expected count if the fit were the truth
    win_flag: [3]f64 = @splat(0),
    gold_flag: [3]f64 = @splat(0),
    /// Early or late cells: both parts same sign in the block; expected
    lean_flag: [3]f64 = @splat(0),
    games: [2]usize = @splat(0),

    fn add(a: *Score, b: Score) void {
        inline for (.{ "win", "win_clear", "win_hide", "gold", "gold_clear" }) |name| {
            const s = &@field(a, name);
            const o = @field(b, name);
            s.total += o.total;
            s.sum_sq += o.sum_sq;
            s.games += o.games;
            s.rows += o.rows;
        }
        a.gold_base += b.gold_base;
        for (0..2) |i| for (0..2) |j| {
            a.win_cal[i][j] += b.win_cal[i][j];
            a.gold_cal[i][j] += b.gold_cal[i][j];
        };
        for (0..3) |i| {
            a.win_flag[i] += b.win_flag[i];
            a.gold_flag[i] += b.gold_flag[i];
            a.lean_flag[i] += b.lean_flag[i];
        }
        for (0..2) |i| a.games[i] += b.games[i];
    }
};

fn normalCdf(z: f64) f64 {
    return 0.5 * erfc(-z / std.math.sqrt2);
}

/// Numerical Recipes' (fractional error under 1.2e-7), as lab/comps.zig's
fn erfc(x: f64) f64 {
    const z = @abs(x);
    const t = 1 / (1 + 0.5 * z);
    const ans = t * @exp(-z * z - 1.26551223 + t * (1.00002368 + t * (0.37409196 + t * (0.09678418 +
        t * (-0.18628806 + t * (0.27886807 + t * (-1.13520398 + t * (1.48851587 +
            t * (-0.82215223 + t * 0.17087277)))))))));
    return if (x >= 0) ans else 2 - ans;
}

/// Scores `f` on `block` games: gains over the state (win) or the mean (gold), with
/// every effect and with only the clear ones; and per cell the block's own estimate
/// (one Newton step from the fit), against the fit's
fn score(gpa: std.mem.Allocator, f: *const Fit, block: []const Game) !Score {
    var s: Score = .{};
    const cells = Role.count * f.champs;
    // [cell]: win sum s(y - p), sum p(1-p); gold sum s res, rows, sum res^2 over block
    const wu = try gpa.alloc(f64, cells);
    defer gpa.free(wu);
    const wi = try gpa.alloc(f64, cells);
    defer gpa.free(wi);
    const gu = try gpa.alloc(f64, cells);
    defer gpa.free(gu);
    const gn = try gpa.alloc(f64, cells);
    defer gpa.free(gn);
    for ([_][]f64{ wu, wi, gu, gn }) |x| @memset(x, 0);
    var gold_sq: f64 = 0;
    for (block) |g| {
        const z = @as(f64, g.gold);
        const full = f.goldPred(g, false);
        const shown = f.goldPred(g, true);
        const base_sq = (z - f.gold_mean) * (z - f.gold_mean);
        s.gold.add(base_sq - (z - full) * (z - full), 1);
        s.gold_clear.add(base_sq - (z - shown) * (z - shown), 1);
        s.gold_base += base_sq;
        gold_sq += (z - full) * (z - full);
        s.games[0] += 1;
        for (seats(g, f.champs)) |st| {
            gu[st.cell] += st.s * (z - full);
            gn[st.cell] += 1;
        }
        if (!g.late) continue;
        s.games[1] += 1;
        const y: f64 = @floatFromInt(@intFromBool(g.blue_won));
        const l0 = analysis.logLoss(logreg.sigmoid(f.baseEta(g)), y);
        const p = logreg.sigmoid(f.winEta(g, false));
        const l1 = analysis.logLoss(p, y);
        const l2 = analysis.logLoss(logreg.sigmoid(f.winEta(g, true)), y);
        s.win.add(l0 - l1, 1);
        s.win_clear.add(l0 - l2, 1);
        s.win_hide.add(l1 - l2, 1);
        for (seats(g, f.champs)) |st| {
            wu[st.cell] += st.s * (y - p);
            wi[st.cell] += p * (1 - p);
        }
    }
    const sigma2 = gold_sq / @as(f64, @floatFromInt(@max(block.len, 1)));
    for (0..cells) |c| {
        const lean = f.lean(c);
        var both: [2]f64 = undefined;
        var expect: [2]f64 = undefined;
        var have: usize = 0;
        if (gn[c] > 0) {
            const b = f.gold.b[c];
            const h = b + gu[c] / gn[c];
            const wt = gn[c] / sigma2;
            calAdd(&s.gold_cal, b, h, wt, f.gold.clear(c));
            if (f.gold.clear(c)) flagAdd(&s.gold_flag, b, h, wt);
            both[0] = h * b;
            expect[0] = normalCdf(@abs(b) * @sqrt(wt));
            have += 1;
        }
        if (wi[c] > 0) {
            const b = f.win.b[c];
            const h = b + wu[c] / wi[c];
            calAdd(&s.win_cal, b, h, wi[c], f.win.clear(c));
            if (f.win.clear(c)) flagAdd(&s.win_flag, b, h, wi[c]);
            both[1] = h * b;
            expect[1] = normalCdf(@abs(b) * @sqrt(wi[c]));
            have += 1;
        }
        if (lean != .none and have == 2) {
            s.lean_flag[0] += 1;
            s.lean_flag[1] += @floatFromInt(@intFromBool(both[0] > 0 and both[1] > 0));
            s.lean_flag[2] += expect[0] * expect[1];
        }
    }
    return s;
}

fn calAdd(cal: *[2][2]f64, b: f64, h: f64, wt: f64, is_clear: bool) void {
    cal[0][0] += wt * b * h;
    cal[0][1] += wt * b * b;
    if (!is_clear) return;
    cal[1][0] += wt * b * h;
    cal[1][1] += wt * b * b;
}

fn flagAdd(flag: *[3]f64, b: f64, h: f64, wt: f64) void {
    flag[0] += 1;
    flag[1] += @floatFromInt(@intFromBool(h * b > 0));
    flag[2] += normalCdf(@abs(b) * @sqrt(wt));
}

fn slope(cal: [2]f64) [2]f64 {
    if (cal[1] == 0) return .{ 0, 0 };
    return .{ cal[0] / cal[1], 1 / @sqrt(cal[1]) };
}

/// Folds 1-5 and dev-val as the lab's, then the dev fit's champion-roles (`table`: TSV of
/// every one with names). Games from the test cut on are never loaded
pub fn check(
    gpa: std.mem.Allocator,
    io: Io,
    db: store.Db,
    patches: []const []const u8,
    platforms: []const []const u8,
    cuts: Cuts,
    table: ?[]const u8,
    prior_rows: f64,
    w: *Io.Writer,
) !void {
    var games = try load(gpa, io, db, patches, platforms, 0, cuts[6]);
    defer games.deinit(gpa);
    const all = games.list.items;
    std.mem.sort(Game, all, {}, struct {
        fn f(_: void, a: Game, b: Game) bool {
            return a.start < b.start;
        }
    }.f);
    const champs = games.champs.ids.items.len;
    const before = struct {
        fn idx(gs: []const Game, cut: i64) usize {
            return std.sort.partitionPoint(Game, gs, cut, struct {
                fn below(c: i64, g: Game) bool {
                    return g.start < c;
                }
            }.below);
        }
    }.idx;

    try w.print("# meiolol lean --check\n\nGames reaching 15:00 before the test cut {d}: {d}; " ++
        "cuts {d},{d},{d},{d},{d}, dev {d}. Gold: team gold lead at {d} min; win: from the " ++
        "state at {d} min (team gold, XP, objectives held). Clear: {d}+ fit games at {d} " ++
        "min and |effect| >= {d:.1} posterior sd.\n\n", .{
        cuts[6],     all.len,    cuts[0],   cuts[1],    cuts[2], cuts[3], cuts[4], cuts[5],
        gold_minute, win_minute, min_games, win_minute, clear_z,
    });
    try w.writeAll("| block | fit games | scored (at 20) | win gain shrunk | win gain clear only | " ++
        "hiding unclear | gold MSE gain shrunk | clear only | win calib (all; clear) | " ++
        "gold calib (all; clear) | win clear same sign (expected) | gold clear same sign | " ++
        "early/late both same sign |\n" ++
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |\n");
    var pooled: Score = .{};
    var signs: [3]u32 = @splat(0);
    for (0..6) |k| {
        const fit_end = before(all, cuts[k]);
        const lo = fit_end;
        const hi = before(all, if (k == 5) cuts[6] else cuts[k + 1]);
        var f = try fitWith(gpa, all[0..fit_end], champs, prior_rows);
        defer f.deinit(gpa);
        const s = try score(gpa, &f, all[lo..hi]);
        if (k < 5) {
            pooled.add(s);
            signs[0] += @intFromBool(s.win.gain().mean > 0);
            signs[1] += @intFromBool(s.win_clear.gain().mean > 0);
            signs[2] += @intFromBool(s.gold_clear.gain().mean > 0);
        }
        try scoreRow(w, ([_][]const u8{ "1", "2", "3", "4", "5", "dev-val" })[k], fit_end, s);
    }
    try scoreRow(w, "folds 1-5", 0, pooled);
    try w.print("\nFolds better than without: win shrunk {d}/5, win clear only {d}/5, gold " ++
        "clear only {d}/5. Gains in nats per game (win) and % of the mean-only MSE (gold), " ++
        "± 95%. Calibration: slope of the block's own estimate (one Newton step from the " ++
        "fit) on the fitted effect, weighted by the block's information, ± 95%; 1 = the " ++
        "shrunk sizes hold.\n", .{ signs[0], signs[1], signs[2] });

    // The dev fit: what the site would show from these games
    const dev_end = before(all, cuts[5]);
    var f = try fitWith(gpa, all[0..dev_end], champs, prior_rows);
    defer f.deinit(gpa);
    try w.writeAll("\nDev fit, the prior's cell floor: spread of true win effects (pp) and clear " ++
        "cells by role, top / jungle / middle / bottom / support\n\n");
    for ([_]f64{ 10, 100, 500 }) |rows| {
        var v = try fitWith(gpa, all[0..dev_end], champs, rows);
        defer v.deinit(gpa);
        try w.print("- {d}+ games:", .{rows});
        for (0..Role.count) |ri| {
            var n: u32 = 0;
            for (ri * champs..(ri + 1) * champs) |c| n += @intFromBool(v.win.clear(c));
            try w.print(" {d:.1} ({d})", .{ 25 * v.win.tau[ri], n });
        }
        try w.writeAll("\n");
    }
    var name = try db.prepare("SELECT name FROM champions WHERE id = ?");
    defer name.deinit();
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const names = try arena.alloc([]const u8, champs);
    for (names, games.champs.ids.items) |*n, id| {
        try name.bind(.{@as(i64, id)});
        n.* = if (try name.step()) try arena.dupe(u8, name.bytes(0)) else try arena.print("#{d}", .{id});
    }
    try w.print("\nDev fit ({d} games before the dev cut): champion-roles by role, spread of " ++
        "true effects (gold; win pp)\n\n| role | {d}+ games | gold clear | win clear | early | late | " ++
        "gold tau | win tau pp |\n| --- | --- | --- | --- | --- | --- | --- | --- |\n", .{ dev_end, min_games });
    var totals: [6]u32 = @splat(0);
    for (Role.all, 0..) |role, ri| {
        var counts: [6]u32 = @splat(0);
        for (ri * champs..(ri + 1) * champs) |c| {
            if (f.win.n[c] < min_games) continue;
            counts[0] += 1;
            counts[1] += @intFromBool(f.gold.clear(c));
            counts[2] += @intFromBool(f.win.clear(c));
            counts[3] += @intFromBool(f.lean(c) == .early);
            counts[4] += @intFromBool(f.lean(c) == .late);
        }
        for (&totals, counts) |*t, x| t.* += x;
        try w.print("| {t} | {d} | {d} | {d} | {d} | {d} | {d:.0} | {d:.1} |\n", .{
            role, counts[0], counts[1], counts[2], counts[3], counts[4], 1000 * f.gold.tau[ri], 25 * f.win.tau[ri],
        });
    }
    try w.print("| all | {d} | {d} | {d} | {d} | {d} | | |\n", .{ totals[0], totals[1], totals[2], totals[3], totals[4] });

    try w.writeAll("\nEarly and late champion-roles (dev fit): gold at 14 ± 95%, win pp from even at 20 ± 95%, games at 20\n\n");
    for ([_]Lean{ .early, .late }) |kind| {
        try w.print("{t}:", .{kind});
        for (0..Role.count * champs) |c| {
            if (f.lean(c) != kind) continue;
            try w.print(" {s} {t} ({d:.0} ± {d:.0}, {d:.1} ± {d:.1}, {d});", .{
                names[c % champs], @as(Role, @fromBackingInt(@intCast(c / champs))), 1000 * f.gold.b[c], 1000 * 1.96 * f.gold.sd[c],
                25 * f.win.b[c],   25 * 1.96 * f.win.sd[c],                          f.win.n[c],
            });
        }
        try w.writeAll("\n\n");
    }

    if (table) |path| {
        const file = try Io.Dir.cwd().createFile(io, path, .{});
        defer file.close(io);
        var buf: [16 * 1024]u8 = undefined;
        var fw = file.writer(io, &buf);
        try fw.interface.writeAll("champion\trole\tgames\tgold\tgold_sd\twin_pp\twin_sd\tlean\n");
        for (0..Role.count * champs) |c| {
            if (f.win.n[c] == 0) continue;
            try fw.interface.print("{s}\t{t}\t{d}\t{d:.0}\t{d:.0}\t{d:.2}\t{d:.2}\t{t}\n", .{
                names[c % champs],   @as(Role, @fromBackingInt(@intCast(c / champs))), f.win.n[c],       1000 * f.gold.b[c],
                1000 * f.gold.sd[c], 25 * f.win.b[c],                                  25 * f.win.sd[c], f.lean(c),
            });
        }
        try fw.interface.flush();
    }
}

fn scoreRow(w: *Io.Writer, label: []const u8, fit_games: usize, s: Score) !void {
    const wg = s.win.gain();
    const wc = s.win_clear.gain();
    const wh = s.win_hide.gain();
    const base = s.gold_base / @as(f64, @floatFromInt(@max(s.games[0], 1)));
    const gg = s.gold.gain();
    const gc = s.gold_clear.gain();
    const cal = [_][2]f64{ slope(s.win_cal[0]), slope(s.win_cal[1]), slope(s.gold_cal[0]), slope(s.gold_cal[1]) };
    try w.print("| {s} | {d} | {d} | {d:.5} ± {d:.5} | {d:.5} ± {d:.5} | {d:.5} ± {d:.5} | {d:.2}% ± {d:.2} | {d:.2}% ± {d:.2} | " ++
        "{d:.2} ± {d:.2}; {d:.2} ± {d:.2} | {d:.2} ± {d:.2}; {d:.2} ± {d:.2} | {d}/{d} ({d:.1}) | {d}/{d} ({d:.1}) | {d}/{d} ({d:.1}) |\n", .{
        label,                      fit_games,                  s.games[1],
        wg.mean,                    wg.half_width,              wc.mean,
        wc.half_width,              wh.mean,                    wh.half_width,
        100 * gg.mean / base,       100 * gg.half_width / base, 100 * gc.mean / base,
        100 * gc.half_width / base, cal[0][0],                  1.96 * cal[0][1],
        cal[1][0],                  1.96 * cal[1][1],           cal[2][0],
        1.96 * cal[2][1],           cal[3][0],                  1.96 * cal[3][1],
        s.win_flag[1],              s.win_flag[0],              s.win_flag[2],
        s.gold_flag[1],             s.gold_flag[0],             s.gold_flag[2],
        s.lean_flag[1],             s.lean_flag[0],             s.lean_flag[2],
    });
}

const testing = std.testing;

fn plantGames(gpa: std.mem.Allocator, n: usize, champs: usize, seed: u64) ![]Game {
    const games = try gpa.alloc(Game, n);
    var prng: std.Random.DefaultPrng = .init(seed);
    const rand = prng.random();
    for (games, 0..) |*g, i| {
        g.* = .{ .start = @intCast(i), .champ = undefined, .blue_won = false, .gold = 0, .late = true, .x = @splat(0) };
        // Each role's champions drawn without repeats across the two sides
        for (0..Role.count) |ri| {
            const a = rand.uintLessThan(u16, @intCast(champs));
            var b = rand.uintLessThan(u16, @intCast(champs - 1));
            if (b >= a) b += 1;
            g.champ[0][ri] = a;
            g.champ[1][ri] = b;
        }
        // Champion 0 of every role: +1000 gold, -0.4 log-odds from even; 1: the other
        // way round; the rest 0
        var gold: f64 = rand.floatNorm(f64) * 2.5;
        var eta: f64 = 0;
        for (0..2) |side| for (0..Role.count) |ri| {
            const sgn: f64 = if (side == 0) 1 else -1;
            const c = g.champ[side][ri];
            if (c == 0) {
                gold += sgn;
                eta -= sgn * 0.4;
            } else if (c == 1) {
                gold -= sgn;
                eta += sgn * 0.4;
            }
        };
        g.gold = @floatCast(gold);
        g.x[0] = g.gold;
        eta += 0.5 * gold;
        g.blue_won = rand.float(f64) < logreg.sigmoid(eta);
    }
    return games;
}

test "planted early and late champions come out as such" {
    const gpa = testing.allocator;
    const champs = 30;
    const games = try plantGames(gpa, 60_000, champs, 7);
    defer gpa.free(games);
    var f = try fit(gpa, games, champs);
    defer f.deinit(gpa);
    for (0..Role.count) |ri| {
        const c0 = ri * champs;
        try testing.expectApproxEqAbs(1.0, f.gold.b[c0], 0.25);
        try testing.expectApproxEqAbs(-0.4, f.win.b[c0], 0.15);
        try testing.expectEqual(Lean.early, f.lean(c0));
        try testing.expectEqual(Lean.late, f.lean(c0 + 1));
        for (2..champs) |ci| try testing.expect(f.lean(c0 + ci) == .none);
    }
    // The state's weight on gold is the planted one, not taken by the champions
    try testing.expectApproxEqAbs(0.5, f.base[1], 0.05);

    const held = try plantGames(gpa, 20_000, champs, 8);
    defer gpa.free(held);
    const s = try score(gpa, &f, held);
    try testing.expect(s.win_clear.gain().mean > 0);
    try testing.expect(s.gold_clear.gain().mean > 0);
    const cal = slope(s.win_cal[1]);
    try testing.expectApproxEqAbs(1.0, cal[0], 0.3);
}

test "file round trip" {
    const gpa = testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const champs = 30;
    const games = try plantGames(gpa, 30_000, champs, 9);
    defer gpa.free(games);
    var f = try fit(gpa, games, champs);
    defer f.deinit(gpa);
    const ids = try arena.alloc(u32, champs);
    for (ids, 0..) |*id, i| id.* = @intCast(100 + i);
    var aw: Io.Writer.Allocating = .init(arena);
    try write(&aw.writer, &f, ids, games, "every region");
    const file = try File.parse(arena, aw.written());
    try testing.expectEqual(@as(u32, 30_000), file.games);
    try testing.expectEqualStrings("every region", file.scope);
    const r = file.get(100, .middle).?;
    try testing.expectEqual(Lean.early, r.lean());
    try testing.expectEqual(Lean.late, file.get(101, .middle).?.lean());
    try testing.expect(file.get(100, .middle).?.gold > 500);
    try testing.expect(file.get(999, .top) == null);
}
