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

pub fn visible(p: Phase, c: Cuts, g: rows.Game) bool {
    if (g.is_test) return false;
    return switch (p) {
        .dev => g.start < c.dev,
        .select => g.start < c.select,
        .final => true,
    };
}

pub fn scored(p: Phase, c: Cuts, g: rows.Game) bool {
    return switch (p) {
        .dev => !g.is_test and g.platform == c.eu and g.start >= c.dev and g.start < c.select,
        .select => !g.is_test and g.platform == c.eu and g.start >= c.select,
        .final => g.is_test,
    };
}

fn role(r: core.Role) api.Role {
    return @fromBackingInt(@backingInt(r));
}

/// Everyone's rank per game, by side and role
pub fn gameRanks(gpa: std.mem.Allocator, d: *const rows.Data) ![][2][5]?u8 {
    const out = try gpa.alloc([2][5]?u8, d.games.len);
    @memset(out, @splat(@splat(null)));
    for (d.rows) |r| out[r.game][r.side][@backingInt(r.role)] = r.rank;
    return out;
}

pub fn query(scope: api.Scope, g: rows.Game, ranks: [2][5]?u8, r: rows.Row) api.Query {
    return .{
        .start = g.start,
        .patch = g.patch,
        .platform = g.platform,
        .side = r.side,
        .role = role(r.role),
        .champion = r.champion,
        .rank = r.rank,
        .teams = g.teams,
        .ranks = switch (scope) {
            .champ_select => null,
            .post_game => ranks,
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
/// on everything)
pub fn buildTrain(gpa: std.mem.Allocator, d: *const rows.Data, ranks: []const [2][5]?u8, p: Phase, c: Cuts, fraction: f64) !Visible {
    std.debug.assert(p == .dev or fraction >= 1);
    var v: Visible = .{ .arena = .init(gpa), .train = .{ .games = &.{}, .rows = &.{} } };
    errdefer v.deinit();
    const a = v.arena.allocator();
    const index = try gpa.alloc(u32, d.games.len);
    defer gpa.free(index);
    var games: std.ArrayList(api.Game) = .empty;
    for (d.games, index, ranks) |g, *i, rk| {
        if (!visible(p, c, g) or !inFraction(g, fraction)) continue;
        i.* = @intCast(games.items.len);
        try games.append(a, .{ .start = g.start, .patch = g.patch, .platform = g.platform, .teams = g.teams, .ranks = rk });
    }
    var out: std.ArrayList(api.Row) = .empty;
    for (d.rows) |r| {
        const g = d.games[r.game];
        if (!visible(p, c, g) or !inFraction(g, fraction)) continue;
        try out.append(a, .{
            .game = index[r.game],
            .side = r.side,
            .role = role(r.role),
            .champion = r.champion,
            .rank = r.rank,
            .y = r.y,
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

pub fn score(comptime C: type, gpa: std.mem.Allocator, d: *const rows.Data, ranks: []const [2][5]?u8, c: Cuts, p: Phase, opts: ScoreOptions) !Scores {
    comptime checkCandidate(C);
    var v = try buildTrain(gpa, d, ranks, p, c, opts.fraction);
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
        var m = try C.fit(gpa, &v.train, .{ .seed = seed });
        defer C.deinit(&m, gpa);
        if (@hasDecl(C, "effects") and seed == 1) if (opts.effects_for) |o| {
            effects = try C.effects(&m, opts.effects_arena.?, o);
        };
        for (row.items, cand, count) |ri, *o, *cnt| {
            const r = d.rows[ri];
            const q = query(C.scope, d.games[r.game], ranks[r.game], r);
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
    /// flip. +200 on champion 1 is below what the selection set can detect at 3000 games
    pub fn init(gpa: std.mem.Allocator, n: usize, seed: u64) !Fixture {
        var data: rows.Data = .{ .arena = .init(gpa), .games = &.{}, .rows = &.{} };
        errdefer data.deinit();
        const a = data.arena.allocator();
        var prng: std.Random.DefaultPrng = .init(seed);
        const rnd = prng.random();
        const games = try a.alloc(rows.Game, n);
        var out: std.ArrayList(rows.Row) = .empty;
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
                    .rank = @intCast(rnd.intRangeLessThan(u8, 16, 28)),
                    .y = y,
                });
            }
        }
        data.games = games;
        data.rows = out.items;
        return .{ .data = data };
    }
};

/// Records what it was given, to check the harness's guarantees
const Spy = struct {
    pub const scope: api.Scope = .champ_select;
    pub const Model = struct { newest: i64 };
    var saw_ranks = false;
    var newest_query: i64 = std.math.maxInt(i64);

    pub fn fit(_: std.mem.Allocator, t: *const api.Train, _: api.Options) !Model {
        var newest: i64 = std.math.minInt(i64);
        for (t.games) |g| newest = @max(newest, g.start);
        return .{ .newest = newest };
    }

    pub fn predict(_: *const Model, q: *const api.Query) api.Prediction {
        if (q.ranks != null) saw_ranks = true;
        newest_query = @min(newest_query, q.start);
        return api.no_opinion;
    }

    pub fn deinit(_: *Model, _: std.mem.Allocator) void {}
};

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
    const ranks = try gameRanks(gpa, &f.data);
    defer gpa.free(ranks);
    const c = try cuts(gpa, &f.data, 0);
    for ([_]Phase{ .dev, .select, .final }) |p| {
        Spy.saw_ranks = false;
        Spy.newest_query = std.math.maxInt(i64);
        var v = try buildTrain(gpa, &f.data, ranks, p, c, 1);
        defer v.deinit();
        var newest: i64 = std.math.minInt(i64);
        for (v.train.games) |g| newest = @max(newest, g.start);
        var s = try score(Spy, gpa, &f.data, ranks, c, p, .{});
        defer s.deinit(gpa);
        try std.testing.expect(s.row.len > 0);
        try std.testing.expect(newest < Spy.newest_query);
        try std.testing.expect(!Spy.saw_ranks);
        // No opinion everywhere: scored exactly as the baseline
        try std.testing.expectEqual(s.row.len, s.no_opinion[0]);
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
    const ranks = try gameRanks(gpa, &f.data);
    defer gpa.free(ranks);
    const c = try cuts(gpa, &f.data, 0);
    const k = api.outcomeIndex(.gold14);

    var noise = try score(Noise, gpa, &f.data, ranks, c, .select, .{});
    defer noise.deinit(gpa);
    const ln = try noise.losses(gpa, &f.data, k, null, .cand);
    defer gpa.free(ln);
    const lb = try noise.losses(gpa, &f.data, k, null, .base);
    defer gpa.free(lb);
    try std.testing.expect(ladder(noise.game, ln, lb, 0) == .no_change);
    try std.testing.expect(ladder(noise.game, ln, lb, look_budget) == .budget_spent);

    // The baseline knows champion 1's +400; a single mean doesn't
    var flat = try score(RoleMean, gpa, &f.data, ranks, c, .select, .{});
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
    const ranks = try gameRanks(gpa, &f.data);
    defer gpa.free(ranks);
    const c = try cuts(gpa, &f.data, 0);
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    var s = try score(Tables, gpa, &f.data, ranks, c, .dev, .{ .effects_for = .gold14, .effects_arena = arena.allocator() });
    defer s.deinit(gpa);
    try std.testing.expectEqual(@as(usize, 1), s.effects.len);
    try std.testing.expectEqualStrings("gold14", s.effects[0].name);
    try std.testing.expect(s.effects[0].rows[0].n > 0 and s.effects[0].rows[0].n < f.data.games.len);
    var plain = try score(Tables, gpa, &f.data, ranks, c, .dev, .{});
    defer plain.deinit(gpa);
    try std.testing.expectEqual(@as(usize, 0), plain.effects.len);
}

test "win is scored on games that ended before 15:00" {
    const gpa = std.testing.allocator;
    var f = try Fixture.init(gpa, 3000, 5);
    defer f.data.deinit();
    // Every third game short: no timeline outcomes, as rows.zig leaves them
    for (f.data.games, 0..) |*g, gi| g.timeline15 = gi % 3 != 0;
    for (f.data.rows) |*r| if (!f.data.games[r.game].timeline15) {
        r.y[api.outcomeIndex(.gold14)] = std.math.nan(f32);
    };
    const ranks = try gameRanks(gpa, &f.data);
    defer gpa.free(ranks);
    const c = try cuts(gpa, &f.data, 0);
    var s = try score(Spy, gpa, &f.data, ranks, c, .dev, .{});
    defer s.deinit(gpa);
    var n: [2]usize = @splat(0);
    for (s.row) |ri| for ([_]api.Outcome{ .win, .gold14 }, &n) |o, *x| {
        x.* += @intFromBool(!std.math.isNan(f.data.rows[ri].y[api.outcomeIndex(o)]));
    };
    try std.testing.expectEqual(s.row.len, n[0]);
    try std.testing.expect(n[1] < n[0]);
}
