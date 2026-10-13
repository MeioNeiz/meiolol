//! The lab agent's harness (docs/lab-agent.md). Cuts train into dev and selection by
//! time on EUW1, fits a candidate on the visible games only, builds each scored row's
//! query (scope-masked, never an outcome), and scores it per outcome against the
//! champion-role baseline, paired per row and clustered by game. Selection looks are a
//! Ladder (Blum and Hardt): "new best" only when the paired interval beats the current
//! best, otherwise no number, and at most `look_budget` looks per snapshot.

const std = @import("std");
const api = @import("api");
const core = @import("core");
const rows = @import("rows.zig");
const seatstats = @import("seatstats.zig");

pub const Phase = enum { dev, select, final };

/// Share of non-test EUW1 games in selection, and again in dev-val
pub const share = 0.2;

/// Selection looks per snapshot, shared by every campaign (docs/lab-agent.md)
pub const look_budget = 50;

/// Prior strength (rows) pulling a champion-role win rate to its role's; continuous
/// outcomes use the raw champion-role mean (docs/model.md "Shared protocol")
const win_prior = 1000;

const seeds = 3;

comptime {
    sameNames(core.Role, api.Role);
    sameNames(rows.Outcome, api.Outcome);
    sameNames(seatstats.SeatStat, api.SeatStat);
}

fn sameNames(comptime A: type, comptime B: type) void {
    const a = @typeInfo(A).@"enum".field_names;
    const b = @typeInfo(B).@"enum".field_names;
    if (a.len != b.len) @compileError(@typeName(A) ++ " and " ++ @typeName(B) ++ " differ");
    for (a, b) |x, y| if (!std.mem.eql(u8, x, y)) @compileError(@typeName(A) ++ " and " ++ @typeName(B) ++ " differ");
}

pub fn checkCandidate(comptime C: type) void {
    inline for (.{ "scope", "Model", "fit", "predict", "deinit" }) |name| {
        if (!@hasDecl(C, name)) @compileError("candidate lacks pub " ++ name ++ " (src/lab/api.zig)");
    }
    _ = @as(api.Scope, C.scope);
}

/// A candidate with `pub const after_game_rank = true` also gets rows.Row.rank_after
/// (api.Row and api.Query rank_after), the rank looked up after the game: a dev-only
/// diagnostic for how much that rank leaks, never selection, final or test preds
pub fn afterGameRank(comptime C: type) bool {
    return @hasDecl(C, "after_game_rank") and C.after_game_rank;
}

/// A candidate with `pub const needs_stats = true` uses api.Row.stats (profiles)
pub fn needsStats(comptime C: type) bool {
    return @hasDecl(C, "needs_stats") and C.needs_stats;
}

/// C.fit, but a needs_stats candidate fails when a seat stat is NaN in every training row:
/// error.NoSeatStats when all are (SNAP/seat_stats.tsv is missing: `meiolol-lab
/// seat-stats` then `pack`), error.SeatStatAllNaN when some are (a broken column, as when
/// every Data Dragon value was NaN, 30450b4). Every caller fits through here
pub fn fit(comptime C: type, gpa: std.mem.Allocator, t: *const api.Train, opts: api.Options) !C.Model {
    if (needsStats(C) and t.rows.len > 0) try statsPresent(t.rows);
    var o = opts;
    if (o.embeddings == null) o.embeddings = embeddings;
    if (needsEmbeddings(C) and o.embeddings == null) return error.NoEmbeddings;
    if (control == .shuffle) {
        const shuffled = try shuffleOutcomes(gpa, t.rows);
        defer gpa.free(shuffled);
        return C.fit(gpa, &.{ .games = t.games, .rows = shuffled }, o);
    }
    return C.fit(gpa, t, o);
}

/// `meiolol-lab --control shuffle CMD`: every candidate fit sees its training games'
/// outcomes permuted between games (scoring keeps the real ones), so a gain over the
/// baseline must vanish; one that doesn't is a leak or a harness bug. netcheck's own
/// --control shuffle|permute (setnet) does the same for its nets
pub const Control = enum { none, shuffle };
pub var control: Control = .none;

/// A copy of rows whose outcomes come from another training game, seat by seat (side and
/// role), so each game's outcomes stay one consistent game's. Games missing a seat keep
/// their own. Seeded by the row count: folds differ, reruns repeat
fn shuffleOutcomes(gpa: std.mem.Allocator, rs: []const api.Row) ![]api.Row {
    const none = std.math.maxInt(u32);
    const out = try gpa.dupe(api.Row, rs);
    errdefer gpa.free(out);
    var dense: std.AutoHashMapUnmanaged(u32, u32) = .empty;
    defer dense.deinit(gpa);
    var seats: std.ArrayList([10]u32) = .empty;
    defer seats.deinit(gpa);
    for (rs, 0..) |r, i| {
        const g = try dense.getOrPut(gpa, r.game);
        if (!g.found_existing) {
            g.value_ptr.* = @intCast(seats.items.len);
            try seats.append(gpa, @splat(none));
        }
        seats.items[g.value_ptr.*][@as(usize, r.side) * 5 + @backingInt(r.role)] = @intCast(i);
    }
    var full: std.ArrayList(u32) = .empty;
    defer full.deinit(gpa);
    for (seats.items, 0..) |s, gi| if (std.mem.indexOfScalar(u32, &s, none) == null) try full.append(gpa, @intCast(gi));
    const from = try gpa.dupe(u32, full.items);
    defer gpa.free(from);
    var rng: std.Random.DefaultPrng = .init(0x5f1e +% rs.len);
    rng.random().shuffle(u32, from);
    for (full.items, from) |to, src| for (seats.items[to], seats.items[src]) |a, b| {
        out[a].y = rs[b].y;
    };
    return out;
}

/// `meiolol-lab --emb DIR` (lab/embfiles.zig): handed to every fit as Options.embeddings
pub var embeddings: ?*const api.EmbeddingSource = null;

pub fn needsEmbeddings(comptime C: type) bool {
    return @hasDecl(C, "needs_embeddings") and C.needs_embeddings;
}

fn statsPresent(rs: []const api.Row) !void {
    var seen: [api.seat_stat_count]bool = @splat(false);
    for (rs) |r| for (r.stats, &seen) |x, *s| {
        if (!std.math.isNan(x)) s.* = true;
    };
    if (std.mem.indexOfScalar(bool, &seen, true) == null) return error.NoSeatStats;
    if (std.mem.indexOfScalar(bool, &seen, false)) |i| {
        // The test runner fails a test that writes to stderr
        if (!@import("builtin").is_test) std.debug.print("harness: seat stat {s} is NaN in every training row\n", .{@typeInfo(api.SeatStat).@"enum".field_names[i]});
        return error.SeatStatAllNaN;
    }
}

/// Scored games of a phase start at or after its cut; its visible games are older
pub const Cuts = struct {
    dev: i64,
    select: i64,
    eu: u8,
};

pub fn cuts(gpa: std.mem.Allocator, d: *const rows.Data, eu: u8) !Cuts {
    var starts: std.ArrayList(i64) = .empty;
    defer starts.deinit(gpa);
    for (d.games) |g| if (!g.is_test and g.platform == eu) try starts.append(gpa, g.start);
    std.mem.sort(i64, starts.items, {}, std.sort.desc(i64));
    const n: usize = @intFromFloat(@round(@as(f64, @floatFromInt(starts.items.len)) * share));
    if (n < 20) return error.TooFewGames;
    return .{ .select = starts.items[n - 1], .dev = starts.items[2 * n - 1], .eu = eu };
}

/// Keeps a fixed share of games, the same ones at every size (nested subsets for
/// learning curves); 1 keeps all
pub fn inFraction(g: rows.Game, fraction: f64) bool {
    if (fraction >= 1) return true;
    var h = std.hash.Wyhash.init(0x1ab);
    h.update(std.mem.asBytes(&g.start));
    h.update(std.mem.asBytes(&g.platform));
    const u: f64 = @floatFromInt(h.final() >> 11);
    return u / @as(f64, 1 << 53) < fraction;
}

/// --resample N's seeded 90% (A/A noise-floor fits), by start and platform so pretrain's
/// nn-export games and netcheck's rows agree. Independent of inFraction's and winnet's
/// crossFold hashes, so two seeds' 90% share 81%
pub fn inResample(start: i64, platform: u8, seed: u32) bool {
    var h = std.hash.Wyhash.init(0xa1a0 +% @as(u64, seed));
    h.update(std.mem.asBytes(&start));
    h.update(std.mem.asBytes(&platform));
    const u: f64 = @floatFromInt(h.final() >> 11);
    return u / @as(f64, 1 << 53) < resample_share;
}

const resample_share = 0.9;

/// docs/model.md "Rows": a game over before 15:00 is a remake, leaver forfeit or abort,
/// decided by the leaver, not the draft
pub const min_duration_s = 900;

fn played(g: rows.Game) bool {
    return g.duration_s >= min_duration_s;
}

pub fn visible(p: Phase, c: Cuts, g: rows.Game) bool {
    if (g.is_test or !played(g)) return false;
    return switch (p) {
        .dev => g.start < c.dev,
        .select => g.start < c.select,
        .final => true,
    };
}

pub fn scored(p: Phase, c: Cuts, g: rows.Game) bool {
    if (!played(g)) return false;
    return switch (p) {
        .dev => !g.is_test and g.platform == c.eu and g.start >= c.dev and g.start < c.select,
        .select => !g.is_test and g.platform == c.eu and g.start >= c.select,
        .final => g.is_test,
    };
}

fn role(r: core.Role) api.Role {
    return @fromBackingInt(@backingInt(r));
}

/// Everyone's rank and experience in one game, by side and role
pub const Players = struct {
    ranks: [2][5]?u8 = @splat(@splat(null)),
    exp: [2][5]api.Experience = @splat(@splat(.{})),
};

pub fn gamePlayers(gpa: std.mem.Allocator, d: *const rows.Data) ![]Players {
    const out = try gpa.alloc(Players, d.games.len);
    @memset(out, .{});
    for (d.rows) |r| {
        out[r.game].ranks[r.side][@backingInt(r.role)] = r.rank_start;
        out[r.game].exp[r.side][@backingInt(r.role)] = experience(r);
    }
    return out;
}

pub fn experience(r: rows.Row) api.Experience {
    return .{
        .champ_games = r.champ_games,
        .champ_wins = r.champ_wins,
        .games = r.games_before,
        .wins = r.wins_before,
        .kda = r.kda_before,
        .perf_games = r.perf_games,
        .lanediff14 = r.lanediff14_before,
        .deaths15 = r.deaths15_before,
    };
}

/// after: fill rank_after (afterGameRank, dev only)
pub fn query(scope: api.Scope, g: rows.Game, players: Players, r: rows.Row, after: bool) api.Query {
    return .{
        .start = g.start,
        .patch = g.patch,
        .platform = g.platform,
        .side = r.side,
        .role = role(r.role),
        .champion = r.champion,
        .rank = r.rank_start,
        .rank_after = if (after) r.rank_after else null,
        .teams = g.teams,
        .ranks = switch (scope) {
            .champ_select => null,
            .post_game, .internal => players.ranks,
        },
        .exp = experience(r),
        .exps = switch (scope) {
            .champ_select, .post_game => null,
            .internal => players.exp,
        },
    };
}

/// A phase's training set: its visible games and their rows, nothing else
pub const Visible = struct {
    arena: std.heap.ArenaAllocator,
    train: api.Train,

    pub fn deinit(v: *Visible) void {
        v.arena.deinit();
    }
};

/// fraction: share of the visible games kept (dev only: selection and test always fit
/// on everything). after: fill rank_after (afterGameRank, dev only)
pub fn buildTrain(gpa: std.mem.Allocator, d: *const rows.Data, players: []const Players, p: Phase, c: Cuts, fraction: f64, after: bool) !Visible {
    std.debug.assert(p == .dev or fraction >= 1);
    std.debug.assert(p == .dev or !after);
    const Keep = struct {
        p: Phase,
        c: Cuts,
        fraction: f64,
        pub fn keep(k: @This(), g: rows.Game) bool {
            return visible(k.p, k.c, g) and inFraction(g, k.fraction);
        }
    };
    return buildTrainBy(gpa, d, players, Keep{ .p = p, .c = c, .fraction = fraction }, after);
}

/// The training set of the games `k.keep(g)` accepts, a split other than the phases' (a
/// random split, a filter: dev only). Test games and games under 15:00 never enter
pub fn buildTrainWhere(gpa: std.mem.Allocator, d: *const rows.Data, players: []const Players, k: anytype) !Visible {
    const Keep = struct {
        inner: @TypeOf(k),
        pub fn keep(x: @This(), g: rows.Game) bool {
            return !g.is_test and played(g) and x.inner.keep(g);
        }
    };
    return buildTrainBy(gpa, d, players, Keep{ .inner = k }, false);
}

fn buildTrainBy(gpa: std.mem.Allocator, d: *const rows.Data, players: []const Players, k: anytype, after: bool) !Visible {
    var v: Visible = .{ .arena = .init(gpa), .train = .{ .games = &.{}, .rows = &.{} } };
    errdefer v.deinit();
    const a = v.arena.allocator();
    const index = try gpa.alloc(u32, d.games.len);
    defer gpa.free(index);
    var games: std.ArrayList(api.Game) = .empty;
    for (d.games, index, players) |g, *i, pl| {
        if (!k.keep(g)) continue;
        i.* = @intCast(games.items.len);
        try games.append(a, .{ .start = g.start, .patch = g.patch, .platform = g.platform, .teams = g.teams, .ranks = pl.ranks, .exp = pl.exp });
    }
    var out: std.ArrayList(api.Row) = .empty;
    for (d.rows) |r| {
        if (!k.keep(d.games[r.game])) continue;
        try out.append(a, .{
            .game = index[r.game],
            .side = r.side,
            .role = role(r.role),
            .champion = r.champion,
            .rank = r.rank_start,
            .rank_after = if (after) r.rank_after else null,
            .exp = experience(r),
            .y = r.y,
            .stats = r.stats,
        });
    }
    v.train = .{ .games = games.items, .rows = out.items };
    return v;
}

/// Champion-role mean per outcome, fitted on the same rows the candidate sees
pub const Baseline = struct {
    cells: std.AutoHashMapUnmanaged(u64, Cell) = .empty,
    roles: [5]Cell = @splat(.{}),

    const Cell = struct {
        n: [api.outcome_count]f64 = @splat(0),
        sum: [api.outcome_count]f64 = @splat(0),
        sumsq: [api.outcome_count]f64 = @splat(0),

        fn add(c: *Cell, y: [api.outcome_count]f32) void {
            for (y, 0..) |v, k| if (!std.math.isNan(v)) {
                c.n[k] += 1;
                c.sum[k] += v;
                c.sumsq[k] += v * v;
            };
        }
    };

    fn key(champion: u32, r: api.Role) u64 {
        return (@as(u64, champion) << 3) | @backingInt(r);
    }

    pub fn fit(gpa: std.mem.Allocator, t: *const api.Train) !Baseline {
        var b: Baseline = .{};
        errdefer b.deinit(gpa);
        for (t.rows) |r| {
            const e = try b.cells.getOrPut(gpa, key(r.champion, r.role));
            if (!e.found_existing) e.value_ptr.* = .{};
            e.value_ptr.add(r.y);
            b.roles[@backingInt(r.role)].add(r.y);
        }
        return b;
    }

    pub fn deinit(b: *Baseline, gpa: std.mem.Allocator) void {
        b.cells.deinit(gpa);
    }

    pub fn predict(b: *const Baseline, champion: u32, r: api.Role) [api.outcome_count]f64 {
        const rc = b.roles[@backingInt(r)];
        const cell = b.cells.get(key(champion, r)) orelse Cell{};
        var out: [api.outcome_count]f64 = undefined;
        for (&out, 0..) |*o, k| {
            const role_mean = if (rc.n[k] > 0) rc.sum[k] / rc.n[k] else 0;
            const prior: f64 = if (k == api.outcomeIndex(.win)) win_prior else 0;
            o.* = if (cell.n[k] + prior > 0)
                (cell.sum[k] + prior * role_mean) / (cell.n[k] + prior)
            else
                role_mean;
        }
        return out;
    }

    /// Per role, for standardising squared errors so roles and outcomes compare
    pub fn sd(b: *const Baseline) [5][api.outcome_count]f64 {
        var out: [5][api.outcome_count]f64 = undefined;
        for (b.roles, &out) |c, *o| for (o, 0..) |*s, k| {
            const m = if (c.n[k] > 0) c.sum[k] / c.n[k] else 0;
            const v = if (c.n[k] > 1) (c.sumsq[k] - c.n[k] * m * m) / (c.n[k] - 1) else 1;
            s.* = if (v > 0) @sqrt(v) else 1;
        };
        return out;
    }
};

/// Log loss for win, squared error in role standard deviations for the rest
pub fn loss(k: usize, y: f32, p: f64, sd: f64) f64 {
    if (k == api.outcomeIndex(.win)) {
        const q = std.math.clamp(p, 1e-6, 1 - 1e-6);
        return -(y * @log(q) + (1 - y) * @log(1 - q));
    }
    const e = (p - y) / sd;
    return e * e;
}

/// A phase's predictions, one entry per scored row in d.rows order
pub const Scores = struct {
    row: []u32,
    game: []u32,
    cand: [][api.outcome_count]f64,
    base: [][api.outcome_count]f64,
    sd: [5][api.outcome_count]f64,
    /// Candidate rows answered "no opinion" (scored as the baseline)
    no_opinion: [api.outcome_count]usize,
    /// ScoreOptions.effects_for's tables, owned by ScoreOptions.effects_arena
    effects: []const api.Effects = &.{},

    pub fn deinit(s: *Scores, gpa: std.mem.Allocator) void {
        gpa.free(s.row);
        gpa.free(s.game);
        gpa.free(s.cand);
        gpa.free(s.base);
    }

    /// Per-row losses for outcome k: candidate, baseline, or given predictions
    pub fn losses(s: *const Scores, gpa: std.mem.Allocator, d: *const rows.Data, k: usize, preds: ?[]const f64, which: enum { cand, base }) ![]f64 {
        const out = try gpa.alloc(f64, s.row.len);
        for (out, s.row, 0..) |*o, ri, i| {
            const r = d.rows[ri];
            const y = r.y[k];
            const p = if (preds) |ps| ps[i] else switch (which) {
                .cand => s.cand[i][k],
                .base => s.base[i][k],
            };
            o.* = if (std.math.isNan(y)) std.math.nan(f64) else loss(k, y, p, s.sd[@backingInt(r.role)][k]);
        }
        return out;
    }
};

pub const ScoreOptions = struct {
    /// Share of the phase's visible games to fit on (learning curves)
    fraction: f64 = 1,
    /// Collects the candidate's effect tables for this outcome (first seed), when it has
    /// `effects`; they live in effects_arena
    effects_for: ?api.Outcome = null,
    effects_arena: ?std.mem.Allocator = null,
};

pub fn score(comptime C: type, gpa: std.mem.Allocator, d: *const rows.Data, players: []const Players, c: Cuts, p: Phase, opts: ScoreOptions) !Scores {
    comptime checkCandidate(C);
    if (afterGameRank(C) and p != .dev) return error.AfterGameRankDevOnly;
    var v = try buildTrain(gpa, d, players, p, c, opts.fraction, afterGameRank(C));
    defer v.deinit();
    var base = try Baseline.fit(gpa, &v.train);
    defer base.deinit(gpa);

    var row: std.ArrayList(u32) = .empty;
    errdefer row.deinit(gpa);
    for (d.rows, 0..) |r, i| if (scored(p, c, d.games[r.game])) try row.append(gpa, @intCast(i));
    const n = row.items.len;
    const game = try gpa.alloc(u32, n);
    errdefer gpa.free(game);
    const cand = try gpa.alloc([api.outcome_count]f64, n);
    errdefer gpa.free(cand);
    const basep = try gpa.alloc([api.outcome_count]f64, n);
    errdefer gpa.free(basep);
    const count = try gpa.alloc([api.outcome_count]f64, n);
    defer gpa.free(count);
    @memset(cand, @splat(0));
    @memset(count, @splat(0));
    for (row.items, game, basep) |ri, *g, *b| {
        g.* = d.rows[ri].game;
        b.* = base.predict(d.rows[ri].champion, role(d.rows[ri].role));
    }

    const n_seeds: u64 = if (@hasDecl(C, "seeded") and C.seeded) seeds else 1;
    var effects: []const api.Effects = &.{};
    for (1..n_seeds + 1) |seed| {
        var m = try fit(C, gpa, &v.train, .{ .seed = seed });
        defer C.deinit(&m, gpa);
        if (@hasDecl(C, "effects") and seed == 1) if (opts.effects_for) |o| {
            effects = try C.effects(&m, opts.effects_arena.?, o);
        };
        for (row.items, cand, count) |ri, *o, *cnt| {
            const r = d.rows[ri];
            const q = query(C.scope, d.games[r.game], players[r.game], r, afterGameRank(C));
            const pred = C.predict(&m, &q);
            for (pred, o, cnt) |x, *acc, *nk| if (!std.math.isNan(x)) {
                acc.* += x;
                nk.* += 1;
            };
        }
    }
    var none: [api.outcome_count]usize = @splat(0);
    for (cand, count, basep) |*o, cnt, b| for (o, cnt, b, &none) |*x, nk, bk, *nn| {
        if (nk == 0) {
            x.* = bk;
            nn.* += 1;
        } else x.* /= nk;
    };
    return .{
        .row = try row.toOwnedSlice(gpa),
        .game = game,
        .cand = cand,
        .base = basep,
        .sd = base.sd(),
        .no_opinion = none,
        .effects = effects,
    };
}

/// Mean loss of a and b over rows where both are numbers (and keep, if given), and
/// a - b with a 95% interval clustered by game (rows of a game are adjacent)
pub const Paired = struct {
    n: usize = 0,
    a: f64 = 0,
    b: f64 = 0,
    diff: f64 = 0,
    half: f64 = std.math.inf(f64),

    pub fn beats(p: Paired) bool {
        return p.n > 0 and p.diff + p.half < 0;
    }
};

pub fn paired(game: []const u32, la: []const f64, lb: []const f64, keep: ?[]const bool) Paired {
    var p: Paired = .{};
    var sa: f64 = 0;
    var sb: f64 = 0;
    for (la, lb, 0..) |a, b, i| {
        if (std.math.isNan(a) or std.math.isNan(b)) continue;
        if (keep) |kp| if (!kp[i]) continue;
        p.n += 1;
        sa += a;
        sb += b;
    }
    if (p.n < 2) return .{ .n = p.n };
    const n: f64 = @floatFromInt(p.n);
    p.a = sa / n;
    p.b = sb / n;
    p.diff = p.a - p.b;
    var ss: f64 = 0;
    var groups: f64 = 0;
    var i: usize = 0;
    while (i < la.len) {
        const g = game[i];
        var sum_d: f64 = 0;
        var cnt: f64 = 0;
        while (i < la.len and game[i] == g) : (i += 1) {
            if (std.math.isNan(la[i]) or std.math.isNan(lb[i])) continue;
            if (keep) |kp| if (!kp[i]) continue;
            sum_d += la[i] - lb[i];
            cnt += 1;
        }
        if (cnt == 0) continue;
        ss += (sum_d - p.diff * cnt) * (sum_d - p.diff * cnt);
        groups += 1;
    }
    if (groups < 2) return p;
    p.half = 1.96 * @sqrt(groups / (groups - 1) * ss / (n * n));
    return p;
}

pub const Verdict = union(enum) {
    new_best: Paired,
    no_change,
    budget_spent,
};

/// The Ladder for one target: compares the candidate's selection losses with the
/// current best's (the baseline until something beats it). Caller holds the lock
pub fn ladder(game: []const u32, cand: []const f64, best: []const f64, looks: usize) Verdict {
    if (looks >= look_budget) return .budget_spent;
    const p = paired(game, cand, best, null);
    return if (p.beats()) .{ .new_best = p } else .no_change;
}

// Tests: a fixture of synthetic games, no snapshot

pub const Fixture = struct {
    data: rows.Data,

    /// n games a minute apart, a third EUW1 (platform 0); gold14 = 5000, +400 for champion
    /// 1 in any role, -300 with champion 2 on the enemy team, + noise (sd 300); win a coin
    /// flip. +200 on champion 1 is below what the selection set can detect at 3000 games.
    /// Players from a pool of 200, so experience fills in
    pub fn init(gpa: std.mem.Allocator, n: usize, seed: u64) !Fixture {
        var data: rows.Data = .{ .arena = .init(gpa), .games = &.{}, .rows = &.{} };
        errdefer data.deinit();
        const a = data.arena.allocator();
        var prng: std.Random.DefaultPrng = .init(seed);
        const rnd = prng.random();
        const games = try a.alloc(rows.Game, n);
        var out: std.ArrayList(rows.Row) = .empty;
        // Own stream: the outcome draws stay as they were before players
        var player_prng: std.Random.DefaultPrng = .init(seed ^ 0x9e37);
        var players: std.ArrayList(u32) = .empty;
        defer players.deinit(gpa);
        var extras: std.ArrayList(rows.Extra) = .empty;
        defer extras.deinit(gpa);
        const n_test = n / 15;
        for (games, 0..) |*g, gi| {
            var teams: [2][5]u32 = undefined;
            for (&teams) |*t| for (t) |*ch| {
                ch.* = rnd.intRangeLessThan(u32, 1, 30);
            };
            const winner: u1 = rnd.int(u1);
            g.* = .{
                .match_id = "",
                .start = @intCast(gi * 60_000),
                .patch = 16020,
                .platform = if (gi >= n - n_test) 0 else @intCast(gi % 3),
                .is_test = gi >= n - n_test,
                .teams = teams,
                .winner = winner,
                .timeline15 = true,
                .duration_s = 1800,
            };
            for (0..10) |slot| {
                const side: u1 = @intCast(slot / 5);
                const ro: core.Role = @fromBackingInt(@as(u3, @intCast(slot % 5)));
                const ch = teams[side][slot % 5];
                var y: [rows.outcome_count]f32 = @splat(std.math.nan(f32));
                y[@backingInt(rows.Outcome.win)] = @floatFromInt(@intFromBool(side == winner));
                var bump: f32 = if (ch == 1) 400 else 0;
                if (std.mem.indexOfScalar(u32, &teams[1 - side], 2) != null) bump -= 300;
                y[@backingInt(rows.Outcome.gold14)] = 5000 + bump + 300 * @as(f32, @floatCast(rnd.floatNorm(f64)));
                try out.append(a, .{
                    .game = @intCast(gi),
                    .slot = @intCast(slot),
                    .side = side,
                    .role = ro,
                    .champion = ch,
                    .rank_start = @intCast(rnd.intRangeLessThan(u8, 16, 28)),
                    .rank_after = @intCast(rnd.intRangeLessThan(u8, 16, 28)),
                    .y = y,
                });
                try players.append(gpa, player_prng.random().intRangeLessThan(u32, 0, 200));
                try extras.append(gpa, .{ .kda = 2 });
            }
        }
        try rows.fillExperience(gpa, games, out.items, players.items, extras.items);
        data.games = games;
        data.rows = out.items;
        return .{ .data = data };
    }
};

/// Records what it was given, to check the harness's guarantees
const Spy = SpyIn(.champ_select);

fn SpyIn(comptime s: api.Scope) type {
    return struct {
        pub const scope: api.Scope = s;
        pub const Model = struct { newest: i64 };
        var saw_ranks = false;
        /// rank_after in a training row or a query
        var saw_after = false;
        var saw_exps = false;
        var exps_nonzero = false;
        /// The query's own exp differs from its slot in exps
        var exps_mismatch = false;
        var newest_query: i64 = std.math.maxInt(i64);
        var train_games: usize = 0;

        fn reset() void {
            saw_ranks = false;
            saw_after = false;
            saw_exps = false;
            exps_nonzero = false;
            exps_mismatch = false;
            newest_query = std.math.maxInt(i64);
        }

        pub fn fit(_: std.mem.Allocator, t: *const api.Train, _: api.Options) !Model {
            train_games = t.games.len;
            for (t.rows) |r| if (r.rank_after != null) {
                saw_after = true;
            };
            var newest: i64 = std.math.minInt(i64);
            for (t.games) |g| newest = @max(newest, g.start);
            return .{ .newest = newest };
        }

        pub fn predict(_: *const Model, q: *const api.Query) api.Prediction {
            if (q.ranks != null) saw_ranks = true;
            if (q.rank_after != null) saw_after = true;
            if (q.exps) |e| {
                saw_exps = true;
                const own = e[q.side][@backingInt(q.role)];
                if (!std.meta.eql(own, q.exp)) exps_mismatch = true;
                for (e) |team| for (team) |x| {
                    if (x.games > 0) exps_nonzero = true;
                };
            }
            newest_query = @min(newest_query, q.start);
            return api.no_opinion;
        }

        pub fn deinit(_: *Model, _: std.mem.Allocator) void {}
    };
}

/// Wants seat stats; fits nothing
const NeedsStats = struct {
    pub const scope: api.Scope = .champ_select;
    pub const needs_stats = true;
    pub const Model = struct {};
    pub fn fit(_: std.mem.Allocator, _: *const api.Train, _: api.Options) !Model {
        return .{};
    }
    pub fn predict(_: *const Model, _: *const api.Query) api.Prediction {
        return api.no_opinion;
    }
    pub fn deinit(_: *Model, _: std.mem.Allocator) void {}
};

test "shuffled outcomes: whole games moved seat by seat, every game's set kept" {
    const gpa = std.testing.allocator;
    var f = try Fixture.init(gpa, 200, 5);
    defer f.data.deinit();
    const players = try gamePlayers(gpa, &f.data);
    defer gpa.free(players);
    const All = struct {
        pub fn keep(_: @This(), _: rows.Game) bool {
            return true;
        }
    };
    var v = try buildTrainBy(gpa, &f.data, players, All{}, false);
    defer v.deinit();
    const out = try shuffleOutcomes(gpa, v.train.rows);
    defer gpa.free(out);
    var moved: usize = 0;
    for (v.train.rows, out) |a, b| {
        try std.testing.expectEqual(a.game, b.game);
        moved += @intFromBool(a.y[0] != b.y[0]);
    }
    try std.testing.expect(moved > out.len / 4);
    // Blue's and red's wins stay opposite within each game, as in a real one
    for (out) |r| for (out) |q| if (q.game == r.game and q.side != r.side) {
        try std.testing.expectEqual(1 - r.y[0], q.y[0]);
        break;
    };
}

test "a candidate that needs seat stats fails without them" {
    const gpa = std.testing.allocator;
    var f = try Fixture.init(gpa, 600, 12);
    defer f.data.deinit();
    const players = try gamePlayers(gpa, &f.data);
    defer gpa.free(players);
    const c = try cuts(gpa, &f.data, 0);
    for ([_]Phase{ .dev, .select, .final }) |p| {
        try std.testing.expectError(error.NoSeatStats, score(NeedsStats, gpa, &f.data, players, c, p, .{}));
    }
    // Each stat known somewhere in the fit set is enough; a stat NaN everywhere isn't
    f.data.rows[0].stats = @splat(30);
    var s = try score(NeedsStats, gpa, &f.data, players, c, .dev, .{});
    s.deinit(gpa);
    f.data.rows[0].stats[3] = std.math.nan(f32);
    try std.testing.expectError(error.SeatStatAllNaN, score(NeedsStats, gpa, &f.data, players, c, .dev, .{}));
    f.data.rows[0].stats = @splat(std.math.nan(f32));
    var plain = try score(Spy, gpa, &f.data, players, c, .dev, .{});
    plain.deinit(gpa);
}

/// Seat stats in fit: fixture rows carry their game's start minute as minutes
const StatsSpy = struct {
    pub const scope: api.Scope = .internal;
    pub const Model = struct {};
    /// Latest game whose stats reached fit, rows with stats, rows whose stats aren't
    /// their own game's
    var newest_stat: f32 = -1;
    var with_stats: usize = 0;
    var wrong_game: usize = 0;
    var newest_query: i64 = std.math.maxInt(i64);

    fn reset() void {
        newest_stat = -1;
        with_stats = 0;
        wrong_game = 0;
        newest_query = std.math.maxInt(i64);
    }

    pub fn fit(_: std.mem.Allocator, t: *const api.Train, _: api.Options) !Model {
        for (t.rows) |r| {
            const m = r.stats[@backingInt(api.SeatStat.minutes)];
            if (std.math.isNan(m)) continue;
            with_stats += 1;
            newest_stat = @max(newest_stat, m);
            if (m != @as(f32, @floatFromInt(@divExact(t.games[r.game].start, 60_000)))) wrong_game += 1;
        }
        return .{};
    }

    pub fn predict(_: *const Model, q: *const api.Query) api.Prediction {
        newest_query = @min(newest_query, q.start);
        return api.no_opinion;
    }

    pub fn deinit(_: *Model, _: std.mem.Allocator) void {}
};

test "seat stats reach fit on visible games only, never a scored game's" {
    const gpa = std.testing.allocator;
    var f = try Fixture.init(gpa, 600, 10);
    defer f.data.deinit();
    const players = try gamePlayers(gpa, &f.data);
    defer gpa.free(players);
    const c = try cuts(gpa, &f.data, 0);

    // No seat_stats.tsv: every stat NaN
    StatsSpy.reset();
    var s0 = try score(StatsSpy, gpa, &f.data, players, c, .dev, .{});
    s0.deinit(gpa);
    try std.testing.expectEqual(0, StatsSpy.with_stats);

    for (f.data.rows) |*r| r.stats[@backingInt(api.SeatStat.minutes)] = @floatFromInt(@divExact(f.data.games[r.game].start, 60_000));
    for ([_]Phase{ .dev, .select, .final }) |p| {
        StatsSpy.reset();
        var s = try score(StatsSpy, gpa, &f.data, players, c, p, .{});
        defer s.deinit(gpa);
        try std.testing.expect(s.row.len > 0 and StatsSpy.with_stats > 0);
        try std.testing.expectEqual(0, StatsSpy.wrong_game);
        var visible_rows: usize = 0;
        for (f.data.rows) |r| visible_rows += @intFromBool(visible(p, c, f.data.games[r.game]));
        try std.testing.expectEqual(visible_rows, StatsSpy.with_stats);
        for (s.row) |ri| {
            const scored_min: f32 = @floatFromInt(@divExact(f.data.games[f.data.rows[ri].game].start, 60_000));
            try std.testing.expect(StatsSpy.newest_stat < scored_min);
        }
    }
    // A query has no stats field at all
    try std.testing.expect(!@hasField(api.Query, "stats"));
}

/// The baseline's own champion-role means plus a little noise: must not get past the
/// ladder
const Noise = struct {
    pub const scope: api.Scope = .champ_select;
    pub const Model = struct { base: Baseline, seed: u64 };

    pub fn fit(gpa: std.mem.Allocator, t: *const api.Train, o: api.Options) !Model {
        return .{ .base = try Baseline.fit(gpa, t), .seed = o.seed };
    }

    pub fn predict(m: *const Model, q: *const api.Query) api.Prediction {
        var h = std.hash.Wyhash.init(m.seed);
        h.update(std.mem.asBytes(&q.start));
        h.update(std.mem.asBytes(&q.champion));
        h.update(std.mem.asBytes(&q.side));
        const u: f64 = @floatFromInt(h.final() % 1000);
        const k = api.outcomeIndex(.gold14);
        var out = api.no_opinion;
        out[k] = @floatCast(m.base.predict(q.champion, q.role)[k] + (u - 500) * 0.02);
        return out;
    }

    pub fn deinit(m: *Model, gpa: std.mem.Allocator) void {
        m.base.deinit(gpa);
    }
};

/// One mean for everyone: the baseline knows champion 1's +400 gold and must beat it
const RoleMean = struct {
    pub const scope: api.Scope = .champ_select;
    pub const Model = struct { mean: f64 };

    pub fn fit(_: std.mem.Allocator, t: *const api.Train, _: api.Options) !Model {
        var s: f64 = 0;
        var n: f64 = 0;
        for (t.rows) |r| {
            const y = r.y[api.outcomeIndex(.gold14)];
            if (std.math.isNan(y)) continue;
            s += y;
            n += 1;
        }
        return .{ .mean = s / n };
    }

    pub fn predict(m: *const Model, _: *const api.Query) api.Prediction {
        var out = api.no_opinion;
        out[api.outcomeIndex(.gold14)] = @floatCast(m.mean);
        return out;
    }

    pub fn deinit(_: *Model, _: std.mem.Allocator) void {}
};

test "candidates see no scored games and no other ranks in champ select" {
    const gpa = std.testing.allocator;
    var f = try Fixture.init(gpa, 3000, 1);
    defer f.data.deinit();
    const players = try gamePlayers(gpa, &f.data);
    defer gpa.free(players);
    const c = try cuts(gpa, &f.data, 0);
    for ([_]Phase{ .dev, .select, .final }) |p| {
        Spy.reset();
        var v = try buildTrain(gpa, &f.data, players, p, c, 1, false);
        defer v.deinit();
        var newest: i64 = std.math.minInt(i64);
        for (v.train.games) |g| newest = @max(newest, g.start);
        var s = try score(Spy, gpa, &f.data, players, c, p, .{});
        defer s.deinit(gpa);
        try std.testing.expect(s.row.len > 0);
        try std.testing.expect(newest < Spy.newest_query);
        try std.testing.expect(!Spy.saw_ranks);
        try std.testing.expect(!Spy.saw_after);
        try std.testing.expect(!Spy.saw_exps);
        // No opinion everywhere: scored exactly as the baseline
        try std.testing.expectEqual(s.row.len, s.no_opinion[0]);
    }
}

test "others' experience only in internal scope, ranks in post-game and internal" {
    const gpa = std.testing.allocator;
    var f = try Fixture.init(gpa, 600, 8);
    defer f.data.deinit();
    const players = try gamePlayers(gpa, &f.data);
    defer gpa.free(players);
    const c = try cuts(gpa, &f.data, 0);
    inline for (.{ api.Scope.champ_select, .post_game, .internal }) |sc| {
        const S = SpyIn(sc);
        for ([_]Phase{ .dev, .select, .final }) |p| {
            S.reset();
            var s = try score(S, gpa, &f.data, players, c, p, .{});
            defer s.deinit(gpa);
            try std.testing.expectEqual(sc != .champ_select, S.saw_ranks);
            try std.testing.expectEqual(sc == .internal, S.saw_exps);
            try std.testing.expectEqual(sc == .internal, S.exps_nonzero);
            try std.testing.expect(!S.exps_mismatch);
        }
    }
}

/// Spy that asks for the after-game rank
const AfterSpy = struct {
    pub const scope: api.Scope = .champ_select;
    pub const after_game_rank = true;
    pub const Model = Spy.Model;
    pub const fit = Spy.fit;
    pub const predict = Spy.predict;
    pub const deinit = Spy.deinit;
};

test "the after-game rank reaches only candidates that ask, in dev runs only" {
    const gpa = std.testing.allocator;
    var f = try Fixture.init(gpa, 600, 9);
    defer f.data.deinit();
    const players = try gamePlayers(gpa, &f.data);
    defer gpa.free(players);
    const c = try cuts(gpa, &f.data, 0);
    Spy.reset();
    var s = try score(AfterSpy, gpa, &f.data, players, c, .dev, .{});
    s.deinit(gpa);
    try std.testing.expect(Spy.saw_after);
    for ([_]Phase{ .select, .final }) |p| {
        try std.testing.expectError(error.AfterGameRankDevOnly, score(AfterSpy, gpa, &f.data, players, c, p, .{}));
    }
    // Everyone else's ranks are the pre-game ones
    for (f.data.rows) |r| {
        try std.testing.expectEqual(r.rank_start, players[r.game].ranks[r.side][@backingInt(r.role)]);
    }
}

test "query carries no outcome" {
    inline for (@typeInfo(api.Query).@"struct".field_names) |name| {
        inline for (@typeInfo(api.Outcome).@"enum".field_names) |o| {
            try std.testing.expect(!std.mem.eql(u8, name, o));
        }
        try std.testing.expect(!std.mem.eql(u8, name, "y"));
    }
}

test "ladder: noise never wins, a real gain does" {
    const gpa = std.testing.allocator;
    var f = try Fixture.init(gpa, 3000, 2);
    defer f.data.deinit();
    const players = try gamePlayers(gpa, &f.data);
    defer gpa.free(players);
    const c = try cuts(gpa, &f.data, 0);
    const k = api.outcomeIndex(.gold14);

    var noise = try score(Noise, gpa, &f.data, players, c, .select, .{});
    defer noise.deinit(gpa);
    const ln = try noise.losses(gpa, &f.data, k, null, .cand);
    defer gpa.free(ln);
    const lb = try noise.losses(gpa, &f.data, k, null, .base);
    defer gpa.free(lb);
    try std.testing.expect(ladder(noise.game, ln, lb, 0) == .no_change);
    try std.testing.expect(ladder(noise.game, ln, lb, look_budget) == .budget_spent);

    // The baseline knows champion 1's +400; a single mean doesn't
    var flat = try score(RoleMean, gpa, &f.data, players, c, .select, .{});
    defer flat.deinit(gpa);
    const lf = try flat.losses(gpa, &f.data, k, null, .cand);
    defer gpa.free(lf);
    try std.testing.expect(ladder(flat.game, lb, lf, 0) == .new_best);
    try std.testing.expect(ladder(flat.game, lf, lb, 0) == .no_change);
}

test "paired interval clusters by game" {
    const game = [_]u32{ 0, 0, 1, 1, 2, 2, 3, 3 };
    const a = [_]f64{ 1, 1, 2, 2, 1, 1, 2, 2 };
    const b = [_]f64{ 1, 1, 1, 1, 1, 1, 1, 1 };
    const p = paired(&game, &a, &b, null);
    try std.testing.expectEqual(@as(usize, 8), p.n);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), p.diff, 1e-12);
    try std.testing.expect(p.half > 0.4);
}

test "fractions are nested" {
    var prng: std.Random.DefaultPrng = .init(3);
    var kept: [3]usize = @splat(0);
    for (0..2000) |i| {
        const g: rows.Game = .{ .match_id = "", .start = @intCast(i * 7919 + prng.random().int(u16)), .patch = 0, .platform = 0, .is_test = false, .teams = undefined, .winner = 0 };
        const in = [3]bool{ inFraction(g, 0.25), inFraction(g, 0.5), inFraction(g, 1) };
        if (in[0]) try std.testing.expect(in[1]);
        for (in, &kept) |x, *k| k.* += @intFromBool(x);
    }
    try std.testing.expect(kept[0] > 400 and kept[0] < 600);
    try std.testing.expectEqual(@as(usize, 2000), kept[2]);
}

/// Reports one effect table: games it was fitted on, for the target it was asked
const Tables = struct {
    pub const scope: api.Scope = .champ_select;
    pub const Model = struct { games: usize };

    pub fn fit(_: std.mem.Allocator, t: *const api.Train, _: api.Options) !Model {
        return .{ .games = t.games.len };
    }

    pub fn predict(_: *const Model, _: *const api.Query) api.Prediction {
        return api.no_opinion;
    }

    pub fn deinit(_: *Model, _: std.mem.Allocator) void {}

    pub fn effects(m: *const Model, arena: std.mem.Allocator, target: api.Outcome) ![]const api.Effects {
        const rows_ = try arena.dupe(api.Effect, &.{.{ .label = "#1", .effect = 400, .ci = 30, .n = @intCast(m.games) }});
        return arena.dupe(api.Effects, &.{.{ .name = @tagName(target), .title = "t", .unit = "gold", .higher = "h", .rows = rows_ }});
    }
};

test "effect tables come through on request only" {
    const gpa = std.testing.allocator;
    var f = try Fixture.init(gpa, 600, 6);
    defer f.data.deinit();
    const players = try gamePlayers(gpa, &f.data);
    defer gpa.free(players);
    const c = try cuts(gpa, &f.data, 0);
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    var s = try score(Tables, gpa, &f.data, players, c, .dev, .{ .effects_for = .gold14, .effects_arena = arena.allocator() });
    defer s.deinit(gpa);
    try std.testing.expectEqual(@as(usize, 1), s.effects.len);
    try std.testing.expectEqualStrings("gold14", s.effects[0].name);
    try std.testing.expect(s.effects[0].rows[0].n > 0 and s.effects[0].rows[0].n < f.data.games.len);
    var plain = try score(Tables, gpa, &f.data, players, c, .dev, .{});
    defer plain.deinit(gpa);
    try std.testing.expectEqual(@as(usize, 0), plain.effects.len);
}

test "games over before 15:00 are neither fitted on nor scored" {
    const gpa = std.testing.allocator;
    var f = try Fixture.init(gpa, 3000, 5);
    defer f.data.deinit();
    // Every fourth game a leaver forfeit at 12:00 (every third is EUW1, the scored
    // platform): no timeline outcomes, as rows.zig
    for (f.data.games, 0..) |*g, gi| if (gi % 4 == 0) {
        g.timeline15 = false;
        g.duration_s = 720;
    };
    for (f.data.rows) |*r| if (!f.data.games[r.game].timeline15) {
        r.y[api.outcomeIndex(.gold14)] = std.math.nan(f32);
    };
    const players = try gamePlayers(gpa, &f.data);
    defer gpa.free(players);
    const c = try cuts(gpa, &f.data, 0);
    var s = try score(Spy, gpa, &f.data, players, c, .dev, .{});
    defer s.deinit(gpa);
    try std.testing.expect(s.row.len > 0);
    for (s.row) |ri| try std.testing.expect(f.data.games[f.data.rows[ri].game].duration_s >= min_duration_s);
    var long: usize = 0;
    for (f.data.games) |g| long += @intFromBool(!g.is_test and g.start < c.dev and g.duration_s >= min_duration_s);
    try std.testing.expectEqual(long, Spy.train_games);
}

test "buildTrainWhere: the predicate's games, never test games or games under 15:00" {
    const gpa = std.testing.allocator;
    var f = try Fixture.init(gpa, 600, 11);
    defer f.data.deinit();
    for (f.data.games, 0..) |*g, gi| if (gi % 5 == 0) {
        g.duration_s = 720;
    };
    const players = try gamePlayers(gpa, &f.data);
    defer gpa.free(players);
    const Odd = struct {
        pub fn keep(_: @This(), g: rows.Game) bool {
            return @mod(@divFloor(g.start, 60_000), 2) == 1;
        }
    };
    var v = try buildTrainWhere(gpa, &f.data, players, Odd{});
    defer v.deinit();
    var want: usize = 0;
    for (f.data.games) |g| want += @intFromBool(!g.is_test and g.duration_s >= min_duration_s and (Odd{}).keep(g));
    try std.testing.expect(want > 0);
    try std.testing.expectEqual(want, v.train.games.len);
    for (v.train.games) |g| try std.testing.expect(@mod(@divFloor(g.start, 60_000), 2) == 1);
    try std.testing.expectEqual(10 * want, v.train.rows.len);
}
