//! Pick suggestions from a Stats file: DraftGap-style additive log-odds.
//!
//! A champion's base rating is the logit of its role winrate, smoothed toward 50%.
//! A pair (ally duo or matchup) is worth the logit of its smoothed winrate minus what
//! the two base ratings alone predict; smoothing is toward that prediction, so pairs
//! with few games add ~0. A draft's rating is my team's base ratings and duo deltas,
//! minus the enemy's, plus every matchup delta; its win chance is the logistic of that.

const std = @import("std");
const Role = @import("roles.zig").Role;
const statsfile = @import("statsfile.zig");
const Stats = statsfile.Stats;
const Counts = statsfile.Counts;

pub const max_reasons = 4;

pub const Pick = struct {
    champion: u32,
    /// Null when unknown (enemy positions are hidden in champ select); inferred from
    /// the champions' role play rates
    role: ?Role = null,
    /// Pick intent shown by an ally, not locked in
    hover: bool = false,
};

pub const Draft = struct {
    /// The role to suggest for
    role: Role,
    /// My teammates, not me; at most 4 are used
    allies: []const Pick = &.{},
    /// At most 5 are used
    enemies: []const Pick = &.{},
    bans: []const u32 = &.{},
    /// Champions I may pick (pickable and owned); null when anything goes
    pool: ?[]const u32 = null,
};

/// Multipliers on each kind of term's log-odds; .{} is the plain sum
pub const TermWeights = struct {
    base: f64 = 1,
    duo: f64 = 1,
    lane: f64 = 1,
    matchup: f64 = 1,
};

/// Defaults are `meiolol eval`'s "tuned + term weights" of 2026-10-17 (786k games, 15
/// platforms): -0.0017 ± 0.0004 nats a game against the old 1000/1000 priors. Lane above
/// 1 because one pair prior serves every pair kind and is too strong for lane opponents
pub const Options = struct {
    /// Fewer games than this in the role and a champion is not suggested
    min_games: u32 = 200,
    /// Pseudo-games pulling a champion's role winrate toward 50%
    base_prior_games: f64 = 50,
    /// Pseudo-games pulling a duo or matchup toward the base-rating prediction
    prior_games: f64 = 3200,
    /// Overrides prior_games for ally duos, for matchups between lane opponents (same
    /// role) and for other matchups; see empiricalPriors
    duo_prior_games: ?f64 = null,
    lane_prior_games: ?f64 = null,
    matchup_prior_games: ?f64 = null,
    weights: TermWeights = .{ .base = 0.943, .duo = 0.765, .lane = 2.025, .matchup = 1.009 },
    /// Reasons worth less than this many percentage points are left out
    min_reason_pp: f64 = 0.1,
    /// Drafts score with the stats file's fitted model when it has one (statsfile version
    /// 2): its terms replace the smoothed counts, priors and weights. min_games, role
    /// inference and reasons' games still read the counts; page rates (roleWin, duoPp,
    /// matchupPp) always do
    fitted: bool = true,
};

pub const Reason = struct {
    pub const Kind = enum { base, ally, enemy };

    kind: Kind,
    /// The other champion (ally or enemy); the suggestion itself for `base`
    champion: u32,
    role: Role,
    /// The other champion's role was inferred, not known
    role_guessed: bool = false,
    hover: bool = false,
    /// Change in my team's win chance, percentage points
    pp: f64,
    /// Games behind it: role games for base, pair games otherwise
    games: u32,
};

pub const Suggestion = struct {
    champion: u32,
    role: Role,
    /// Estimated win chance for my team with this pick, 0..1
    win: f64,
    /// Percentage points this pick adds over an average champion
    pp: f64,
    /// Games on this champion in this role
    games: u32,
    reasons_buf: [max_reasons]Reason,
    n_reasons: u8,

    pub fn reasons(s: *const Suggestion) []const Reason {
        return s.reasons_buf[0..s.n_reasons];
    }
};

/// Best picks first, as many as fit in `out`
pub fn recommend(
    stats: *const Stats,
    draft: Draft,
    opts: Options,
    out: []Suggestion,
) []Suggestion {
    var ctx: Context = .{ .stats = stats, .opts = opts };
    var me_taken: RoleSet = .empty;
    me_taken.set(@backingInt(draft.role));
    const allies = ctx.resolve(draft.allies, 4, me_taken, &ctx.ally_buf);
    const enemies = ctx.resolve(draft.enemies, 5, .empty, &ctx.enemy_buf);

    // Everything that does not involve my pick
    var fixed: f64 = 0;
    const wb = ctx.weights().base;
    for (allies, 0..) |a, i| {
        fixed += wb * a.base;
        for (allies[i + 1 ..]) |b| fixed += ctx.duo(a, b);
        for (enemies) |e| fixed += ctx.matchup(a, e);
    }
    for (enemies, 0..) |e, i| {
        fixed -= wb * e.base;
        for (enemies[i + 1 ..]) |f| fixed -= ctx.duo(e, f);
    }

    var len: usize = 0;
    candidates: for (0..stats.n) |c| {
        const id = stats.ids[c];
        const games = stats.champRole(draft.role, c).games;
        if (games < opts.min_games) continue;
        if (std.mem.findScalar(u32, draft.bans, id) != null) continue;
        for (draft.allies) |p| if (p.champion == id) continue :candidates;
        for (draft.enemies) |p| if (p.champion == id) continue :candidates;
        if (draft.pool) |pool| if (std.mem.findScalar(u32, pool, id) == null) continue;

        const s = ctx.suggestion(c, draft.role, allies, enemies, fixed);
        if (len < out.len) {
            len += 1;
        } else if (out.len == 0 or s.pp <= out[len - 1].pp) continue;
        var at = len - 1;
        while (at > 0 and out[at - 1].pp < s.pp) : (at -= 1) out[at] = out[at - 1];
        out[at] = s;
    }
    return out[0..len];
}

/// The stats file's games after a reason, from its label (Stats.patch): "on patch
/// 16.21", "in the last 30 days", any other " (label)"
pub const When = struct {
    label: []const u8,

    pub fn format(x: When, w: *std.Io.Writer) std.Io.Writer.Error!void {
        if (x.label.len == 0) return;
        if (std.ascii.isDigit(x.label[0])) return w.print(" on patch {s}", .{x.label});
        if (std.mem.startsWith(u8, x.label, "last ")) return w.print(" in the {s}", .{x.label});
        try w.print(" ({s})", .{x.label});
    }
};

/// "+2.1% vs Darius (top)", "+1.4% with Lulu (support, hover)", "+0.8% strong in mid
/// on patch 16.21"
pub fn describe(
    stats: *const Stats,
    r: Reason,
    w: *std.Io.Writer,
) std.Io.Writer.Error!void {
    try w.print("{s}{d:.1}% ", .{ if (r.pp >= 0) "+" else "", r.pp });
    switch (r.kind) {
        .base => try w.print("{s} in {s}{f}", .{
            if (r.pp >= 0) "strong" else "weak",
            r.role.label(),
            When{ .label = stats.patch },
        }),
        .ally, .enemy => {
            try w.print("{s} {s} ({s}{s}", .{
                if (r.kind == .ally) "with" else "vs",
                stats.nameOf(r.champion),
                r.role.label(),
                if (r.role_guessed) "?" else "",
            });
            if (r.hover) try w.writeAll(", hover");
            try w.writeAll(")");
        },
    }
}

/// Stats pages: champion `c`'s winrate in role `r`, smoothed toward 50%, 0..1
pub fn roleWin(stats: *const Stats, opts: Options, c: usize, r: Role) f64 {
    const ctx: Context = .counts(stats, opts);
    return sigmoid(ctx.base(c, r));
}

/// Stats pages: percentage points `c` in `r` gains alongside ally `a` in `ar`, beyond
/// what the two champions' own ratings predict, in an otherwise even game
pub fn duoPp(stats: *const Stats, opts: Options, r: Role, c: usize, ar: Role, a: usize) f64 {
    const ctx: Context = .counts(stats, opts);
    return evenPp(ctx.duo(ctx.place(c, r), ctx.place(a, ar)));
}

/// Stats pages: as duoPp, against enemy `e` in `er`
pub fn matchupPp(stats: *const Stats, opts: Options, r: Role, c: usize, er: Role, e: usize) f64 {
    const ctx: Context = .counts(stats, opts);
    return evenPp(ctx.matchup(ctx.place(c, r), ctx.place(e, er)));
}

/// The weighted log-odds draftWin adds for `c` in `r`; with duoLogit and matchupLogit,
/// a draft's logit is the sum of its terms (the admin Draft tester's file, draftmodel.zig)
pub fn baseLogit(stats: *const Stats, opts: Options, c: usize, r: Role) f64 {
    const ctx: Context = .{ .stats = stats, .opts = opts };
    return ctx.weights().base * ctx.base(c, r);
}

/// Allies `c` in `r` and `a` in `ar` (different roles), as baseLogit
pub fn duoLogit(stats: *const Stats, opts: Options, r: Role, c: usize, ar: Role, a: usize) f64 {
    const ctx: Context = .{ .stats = stats, .opts = opts };
    return ctx.duo(ctx.place(c, r), ctx.place(a, ar));
}

/// `c` in `r` against `e` in `er`, from `c`'s side, as baseLogit
pub fn matchupLogit(stats: *const Stats, opts: Options, r: Role, c: usize, er: Role, e: usize) f64 {
    const ctx: Context = .{ .stats = stats, .opts = opts };
    return ctx.matchup(ctx.place(c, r), ctx.place(e, er));
}

/// A full draft's log-odds for side 0, by kind of term, unweighted
pub const DraftTerms = struct {
    /// Side 0's base ratings minus side 1's
    base: f64 = 0,
    /// Side 0's duo deltas minus side 1's
    duo: f64 = 0,
    /// Matchup deltas between lane opponents (same role)
    lane: f64 = 0,
    /// All other matchup deltas
    matchup: f64 = 0,

    pub fn total(t: DraftTerms) f64 {
        return t.base + t.duo + t.lane + t.matchup;
    }

    pub fn weighted(t: DraftTerms, w: TermWeights) f64 {
        return w.base * t.base + w.duo * t.duo + w.lane * t.lane + w.matchup * t.matchup;
    }
};

/// teams[side][@backingInt(role)] = champion id, every role known; champions the stats
/// file does not know add nothing
pub fn draftTerms(stats: *const Stats, opts: Options, teams: [2][5]u32) DraftTerms {
    const ctx: Context = .{ .stats = stats, .opts = opts };
    var placed: [2][5]?Placed = undefined;
    for (teams, 0..) |team, s| for (team, Role.all) |id, r| {
        placed[s][@backingInt(r)] = if (stats.index(id)) |c| ctx.place(c, r) else null;
    };
    var t: DraftTerms = .{};
    for (0..2) |s| {
        const sign: f64 = if (s == 0) 1 else -1;
        for (placed[s], 0..) |pa, i| {
            const a = pa orelse continue;
            t.base += sign * a.base;
            for (placed[s][i + 1 ..]) |pb| if (pb) |b| {
                t.duo += sign * ctx.duoDelta(a, b);
            };
        }
    }
    for (placed[0]) |pa| {
        const a = pa orelse continue;
        for (placed[1]) |pe| if (pe) |e| {
            if (a.role == e.role) t.lane += ctx.matchupDelta(a, e) else t.matchup += ctx.matchupDelta(a, e);
        };
    }
    return t;
}

/// Side 0's win chance for a full draft, 0..1 (see draftTerms)
pub fn draftWin(stats: *const Stats, opts: Options, teams: [2][5]u32) f64 {
    const ctx: Context = .{ .stats = stats, .opts = opts };
    return sigmoid(draftTerms(stats, opts, teams).weighted(ctx.weights()));
}

/// Standard error of draftTerms' weighted log-odds under the model's own assumptions:
/// each term's posterior variance is about 4 / (games + prior games) (a logit near 50%),
/// summed as independent. Says how sure the model is given its priors, not how well it
/// predicts games
pub fn draftSe(stats: *const Stats, opts: Options, teams: [2][5]u32) f64 {
    const w = (Context{ .stats = stats, .opts = opts }).weights();
    const termVar = struct {
        fn f(weight: f64, n: u32, k: f64) f64 {
            return weight * weight * 4 / (@as(f64, @floatFromInt(n)) + k);
        }
    }.f;
    var c: [2][5]?usize = undefined;
    for (teams, &c) |team, *cs| for (team, cs) |id, *ci| {
        ci.* = stats.index(id);
    };
    var v: f64 = 0;
    for (c) |cs| for (cs, Role.all, 0..) |ca, ra, i| {
        const a = ca orelse continue;
        v += termVar(w.base, stats.champRole(ra, a).games, opts.base_prior_games);
        for (cs[i + 1 ..], Role.all[i + 1 ..]) |cb, rb| if (cb) |b| {
            const n = stats.ally(ra, rb, a, b).games;
            v += termVar(w.duo, n, opts.duo_prior_games orelse opts.prior_games);
        };
    };
    for (c[0], Role.all) |ca, ra| {
        const a = ca orelse continue;
        for (c[1], Role.all) |ce, re| if (ce) |e| {
            const n = stats.enemy(ra, re, a, e).games;
            v += if (ra == re)
                termVar(w.lane, n, opts.lane_prior_games orelse opts.prior_games)
            else
                termVar(w.matchup, n, opts.matchup_prior_games orelse opts.prior_games);
        };
    }
    return @sqrt(v);
}

/// The roles recommend infers for a team whose positions are hidden: `out[i]` for
/// `picks[i]`, null when the stats file does not know the champion. Roles given in
/// `picks` are kept
pub fn inferRoles(stats: *const Stats, picks: []const Pick, out: []?Role) void {
    var ctx: Context = .{ .stats = stats, .opts = .{} };
    const n = @min(picks.len, 5);
    const placed = ctx.resolve(picks[0..n], 5, .empty, &ctx.enemy_buf);
    var j: usize = 0;
    for (picks[0..n], out[0..n]) |p, *o| {
        if (j < placed.len and placed[j].id == p.champion and stats.index(p.champion) != null) {
            o.* = placed[j].role;
            j += 1;
        } else o.* = null;
    }
}

/// Prior strengths in pseudo-games, per kind of term
pub const Priors = struct {
    base: f64,
    duo: f64,
    lane: f64,
    matchup: f64,

    /// `opts` with these priors
    pub fn apply(p: Priors, opts: Options) Options {
        var o = opts;
        o.base_prior_games = p.base;
        o.duo_prior_games = p.duo;
        o.lane_prior_games = p.lane;
        o.matchup_prior_games = p.matchup;
        return o;
    }
};

pub const min_prior_games = 20;
/// "Noise only": a spread at or below zero must not make estimates exact (Gelman 2005)
pub const max_prior_games = 50_000;

/// Prior strengths from the stats file itself: empirical Bayes by method of moments
/// (Brown 2008, research/questions/curve-statistics-method.md). Per kind, the real
/// spread of winrates around their prediction is the observed spread minus sampling
/// noise, averaged unweighted over cells with at least `min_games` (weighting by games
/// biases it: popular champions and pairs differ systematically); k = p(1-p) / spread.
/// Pair predictions use the base ratings under the estimated base prior
pub fn empiricalPriors(stats: *const Stats, min_games: u32) Priors {
    var base: Moments = .{};
    for (Role.all) |r| for (0..stats.n) |c| base.add(stats.champRole(r, c), 0.5, min_games);
    const base_k = base.prior();

    const ctx: Context = .{ .stats = stats, .opts = .{ .base_prior_games = base_k } };
    var duo: Moments = .{};
    var lane: Moments = .{};
    var matchup: Moments = .{};
    for (Role.all) |r1| for (Role.all) |r2| {
        if (@backingInt(r2) < @backingInt(r1)) continue;
        for (0..stats.n) |c1| {
            if (stats.champRole(r1, c1).games < min_games) continue;
            const a = ctx.place(c1, r1);
            for (0..stats.n) |c2| {
                if (r1 == r2 and c2 <= c1) continue;
                const b = ctx.place(c2, r2);
                if (r1 != r2) duo.add(stats.ally(r1, r2, c1, c2), sigmoid(a.base + b.base), min_games);
                const m = if (r1 == r2) &lane else &matchup;
                m.add(stats.enemy(r1, r2, c1, c2), sigmoid(a.base - b.base), min_games);
            }
        }
    };
    return .{ .base = base_k, .duo = duo.prior(), .lane = lane.prior(), .matchup = matchup.prior() };
}

/// Running sums for one kind's method of moments
const Moments = struct {
    cells: f64 = 0,
    /// Observed squared distance from the prediction minus binomial noise
    excess: f64 = 0,
    noise: f64 = 0,

    fn add(m: *Moments, x: Counts, expected: f64, min_games: u32) void {
        if (x.games < min_games or x.games == 0) return;
        const n: f64 = @floatFromInt(x.games);
        const d = @as(f64, @floatFromInt(x.wins)) / n - expected;
        const v = expected * (1 - expected);
        m.cells += 1;
        m.excess += d * d - v / n;
        m.noise += v;
    }

    /// With few cells the estimate is too noisy to use: too small a prior overfits far
    /// worse than too large a one
    fn prior(m: Moments) f64 {
        if (m.cells < min_cells or m.excess <= 0) return max_prior_games;
        return std.math.clamp(m.noise / m.excess, min_prior_games, max_prior_games);
    }

    const min_cells = 100;
};

fn evenPp(x: f64) f64 {
    return 100 * (sigmoid(x) - 0.5);
}

const RoleSet = std.bit_set.Static(Role.count);

/// A draft champion known to the stats file, with its role settled
const Placed = struct {
    c: usize,
    id: u32,
    role: Role,
    guessed: bool,
    hover: bool,
    base: f64,
};

const Context = struct {
    stats: *const Stats,
    opts: Options,
    ally_buf: [4]Placed = undefined,
    enemy_buf: [5]Placed = undefined,

    fn counts(stats: *const Stats, opts: Options) Context {
        var o = opts;
        o.fitted = false;
        return .{ .stats = stats, .opts = o };
    }

    fn fitted(ctx: *const Context) bool {
        return ctx.opts.fitted and ctx.stats.fitted_bytes != null;
    }

    /// A fitted model's terms are on the logit scale already
    fn weights(ctx: *const Context) TermWeights {
        return if (ctx.fitted()) .{} else ctx.opts.weights;
    }

    fn base(ctx: *const Context, c: usize, r: Role) f64 {
        if (ctx.fitted()) return ctx.stats.fittedBase(r, c).?;
        const k = ctx.opts.base_prior_games;
        const cr = ctx.stats.champRole(r, c);
        return logit((@as(f64, @floatFromInt(cr.wins)) + 0.5 * k) /
            (@as(f64, @floatFromInt(cr.games)) + k));
    }

    /// Smoothed pair logit minus the expected logit
    fn pairDelta(pair: Counts, expected: f64, k: f64) f64 {
        const wins = @as(f64, @floatFromInt(pair.wins)) + k * sigmoid(expected);
        const games = @as(f64, @floatFromInt(pair.games)) + k;
        if (games == 0) return 0;
        return logit(wins / games) - expected;
    }

    fn place(ctx: *const Context, c: usize, r: Role) Placed {
        return .{
            .c = c,
            .id = ctx.stats.ids[c],
            .role = r,
            .guessed = false,
            .hover = false,
            .base = ctx.base(c, r),
        };
    }

    fn duoDelta(ctx: *const Context, a: Placed, b: Placed) f64 {
        if (a.role == b.role) return 0;
        if (ctx.fitted()) return ctx.stats.fittedAlly(a.role, b.role, a.c, b.c).?;
        const pair = ctx.stats.ally(a.role, b.role, a.c, b.c);
        return pairDelta(pair, a.base + b.base, ctx.opts.duo_prior_games orelse ctx.opts.prior_games);
    }

    /// From `a`'s side
    fn matchupDelta(ctx: *const Context, a: Placed, e: Placed) f64 {
        if (ctx.fitted()) return ctx.stats.fittedEnemy(a.role, e.role, a.c, e.c).?;
        const pair = ctx.stats.enemy(a.role, e.role, a.c, e.c);
        const k = if (a.role == e.role) ctx.opts.lane_prior_games else ctx.opts.matchup_prior_games;
        return pairDelta(pair, a.base - e.base, k orelse ctx.opts.prior_games);
    }

    fn duo(ctx: *const Context, a: Placed, b: Placed) f64 {
        return ctx.weights().duo * ctx.duoDelta(a, b);
    }

    fn matchup(ctx: *const Context, a: Placed, e: Placed) f64 {
        const w = if (a.role == e.role) ctx.weights().lane else ctx.weights().matchup;
        return w * ctx.matchupDelta(a, e);
    }

    /// Known champions with roles: given ones kept (unless clashing), the rest the
    /// likeliest assignment of the free roles by play rate
    fn resolve(
        ctx: *const Context,
        picks: []const Pick,
        max: usize,
        taken_in: RoleSet,
        buf: []Placed,
    ) []Placed {
        var taken = taken_in;
        var len: usize = 0;
        var unknown: [5]usize = undefined;
        var n_unknown: usize = 0;
        for (picks[0..@min(picks.len, max)]) |p| {
            const c = ctx.stats.index(p.champion) orelse continue;
            buf[len] = .{
                .c = c,
                .id = p.champion,
                .role = undefined,
                .guessed = true,
                .hover = p.hover,
                .base = 0,
            };
            if (p.role) |r| if (!taken.isSet(@backingInt(r))) {
                taken.set(@backingInt(r));
                buf[len].role = r;
                buf[len].guessed = false;
            };
            if (buf[len].guessed) {
                unknown[n_unknown] = len;
                n_unknown += 1;
            }
            len += 1;
        }
        const placed = buf[0..len];
        var best: [5]Role = undefined;
        var best_score: f64 = -std.math.inf(f64);
        var current: [5]Role = undefined;
        const free = unknown[0..n_unknown];
        ctx.assign(placed, free, 0, taken, 0, &current, &best, &best_score);
        if (best_score == -std.math.inf(f64)) {
            // More unknown champions than free roles: fall back to each one's main role
            for (unknown[0..n_unknown]) |i| placed[i].role = ctx.mainRole(placed[i].c);
        } else {
            for (unknown[0..n_unknown], 0..) |i, j| placed[i].role = best[j];
        }
        for (placed) |*p| p.base = ctx.base(p.c, p.role);
        return placed;
    }

    fn assign(
        ctx: *const Context,
        placed: []const Placed,
        unknown: []const usize,
        depth: usize,
        taken: RoleSet,
        score: f64,
        current: *[5]Role,
        best: *[5]Role,
        best_score: *f64,
    ) void {
        if (depth == unknown.len) {
            if (score > best_score.*) {
                best_score.* = score;
                best.* = current.*;
            }
            return;
        }
        const c = placed[unknown[depth]].c;
        const total: f64 = @floatFromInt(ctx.stats.champGames(c));
        for (Role.all) |r| {
            if (taken.isSet(@backingInt(r))) continue;
            const games: f64 = @floatFromInt(ctx.stats.champRole(r, c).games);
            // Small floor so a never-seen role is unlikely, not impossible
            const rate = if (total > 0) games / total else 0.2;
            var next = taken;
            next.set(@backingInt(r));
            current[depth] = r;
            const s = score + @log(rate + 1e-4);
            ctx.assign(placed, unknown, depth + 1, next, s, current, best, best_score);
        }
    }

    fn mainRole(ctx: *const Context, c: usize) Role {
        var best: Role = .top;
        for (Role.all) |r| {
            const games = ctx.stats.champRole(r, c).games;
            if (games > ctx.stats.champRole(best, c).games) best = r;
        }
        return best;
    }

    fn suggestion(
        ctx: *const Context,
        c: usize,
        role: Role,
        allies: []const Placed,
        enemies: []const Placed,
        fixed: f64,
    ) Suggestion {
        const cr = ctx.stats.champRole(role, c);
        const me = ctx.place(c, role);
        const Term = struct { reason: Reason, x: f64 };
        var terms: [1 + 4 + 5]Term = undefined;
        var n: usize = 0;
        terms[n] = .{ .x = ctx.weights().base * me.base, .reason = .{
            .kind = .base,
            .champion = me.id,
            .role = role,
            .pp = 0,
            .games = cr.games,
        } };
        n += 1;
        for (allies) |a| {
            terms[n] = .{ .x = ctx.duo(me, a), .reason = .{
                .kind = .ally,
                .champion = a.id,
                .role = a.role,
                .role_guessed = a.guessed,
                .hover = a.hover,
                .pp = 0,
                .games = ctx.stats.ally(role, a.role, c, a.c).games,
            } };
            n += 1;
        }
        for (enemies) |e| {
            terms[n] = .{ .x = ctx.matchup(me, e), .reason = .{
                .kind = .enemy,
                .champion = e.id,
                .role = e.role,
                .role_guessed = e.guessed,
                .pp = 0,
                .games = ctx.stats.enemy(role, e.role, c, e.c).games,
            } };
            n += 1;
        }

        var mine: f64 = 0;
        for (terms[0..n]) |t| mine += t.x;
        const total = fixed + mine;
        const win = sigmoid(total);
        for (terms[0..n]) |*t| t.reason.pp = 100 * (win - sigmoid(total - t.x));
        std.mem.sort(Term, terms[0..n], {}, struct {
            fn lessThan(_: void, a: Term, b: Term) bool {
                return @abs(a.reason.pp) > @abs(b.reason.pp);
            }
        }.lessThan);

        var s: Suggestion = .{
            .champion = me.id,
            .role = role,
            .win = win,
            .pp = 100 * (win - sigmoid(fixed)),
            .games = cr.games,
            .reasons_buf = undefined,
            .n_reasons = 0,
        };
        for (terms[0..n]) |t| {
            if (s.n_reasons == max_reasons) break;
            if (@abs(t.reason.pp) < ctx.opts.min_reason_pp) break;
            s.reasons_buf[s.n_reasons] = t.reason;
            s.n_reasons += 1;
        }
        return s;
    }
};

fn logit(p: f64) f64 {
    const q = std.math.clamp(p, 1e-6, 1 - 1e-6);
    return @log(q / (1 - q));
}

fn sigmoid(x: f64) f64 {
    return 1 / (1 + @exp(-x));
}

const testing = std.testing;

// Synthetic: Garen and Darius top, Ahri and Zed mid, Lux support, Vi jungle, Jinx bot.
// Id 0 is not in the file, so Builder skips those slots.
const garen = 86;
const darius = 122;
const ahri = 103;
const zed = 238;
const lux = 99;
const vi = 254;
const jinx = 222;

const test_champions = [_]statsfile.Champion{
    .{ .id = garen, .name = "Garen" },
    .{ .id = darius, .name = "Darius" },
    .{ .id = ahri, .name = "Ahri" },
    .{ .id = zed, .name = "Zed" },
    .{ .id = lux, .name = "Lux" },
    .{ .id = vi, .name = "Vi" },
    .{ .id = jinx, .name = "Jinx" },
};

const TestStats = struct {
    bytes: []u8,
    stats: Stats,

    fn deinit(t: *TestStats) void {
        t.stats.deinit(testing.allocator);
        testing.allocator.free(t.bytes);
    }
};

/// Garen and Darius both win 50% overall, but Darius beats a team with Zed mid 70% of
/// the time and Garen beats Ahri 70%. Garen and Lux win 80% as a duo, Darius and Lux 50%.
fn buildTestStats() !TestStats {
    const gpa = testing.allocator;
    var b: statsfile.Builder = try .init(gpa, &test_champions);
    defer b.deinit();
    for (0..1000) |i| {
        const top: u32 = if (i % 2 == 0) garen else darius;
        const other_top: u32 = if (top == garen) darius else garen;
        const their_mid: u32 = if ((i / 2) % 2 == 0) zed else ahri;
        const good = (top == darius and their_mid == zed) or
            (top == garen and their_mid == ahri);
        const won = if (good) i % 10 < 7 else i % 10 < 3;
        b.addGame(.{
            .{ top, 0, 0, 0, 0 },
            .{ other_top, 0, their_mid, 0, 0 },
        }, if (won) 0 else 1);
    }
    for (0..800) |i| {
        const top: u32 = if (i % 2 == 0) garen else darius;
        const won = if (top == garen) (i / 2) % 5 != 0 else (i / 2) % 2 == 0;
        b.addGame(.{ .{ top, 0, 0, 0, lux }, .{ 0, vi, 0, jinx, 0 } }, if (won) 0 else 1);
        // The same result flipped without Lux keeps Garen and Darius at 50% overall
        b.addGame(.{ .{ top, 0, 0, 0, 0 }, .{ 0, vi, 0, jinx, 0 } }, if (won) 1 else 0);
    }
    var aw: std.Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();
    try b.write(&aw.writer, "test");
    const bytes = try aw.toOwnedSlice();
    errdefer gpa.free(bytes);
    return .{ .bytes = bytes, .stats = try .parse(gpa, bytes) };
}

const test_opts: Options = .{
    .min_games = 50,
    .base_prior_games = 50,
    .prior_games = 20,
};

test "counter pick wins" {
    var t = try buildTestStats();
    defer t.deinit();
    var out: [4]Suggestion = undefined;

    const vs_zed = recommend(&t.stats, .{
        .role = .top,
        .enemies = &.{.{ .champion = zed, .role = .middle }},
    }, test_opts, &out);
    try testing.expectEqual(2, vs_zed.len);
    try testing.expectEqual(darius, vs_zed[0].champion);
    try testing.expect(vs_zed[0].win > 0.55);
    try testing.expect(vs_zed[1].win < 0.45);
    try testing.expectEqual(Reason.Kind.enemy, vs_zed[0].reasons()[0].kind);
    try testing.expectEqual(zed, vs_zed[0].reasons()[0].champion);

    const vs_ahri = recommend(&t.stats, .{
        .role = .top,
        .enemies = &.{.{ .champion = ahri }},
    }, test_opts, &out);
    try testing.expectEqual(garen, vs_ahri[0].champion);
    // Ahri's role is inferred: she only played mid
    try testing.expectEqual(Role.middle, vs_ahri[0].reasons()[0].role);
    try testing.expect(vs_ahri[0].reasons()[0].role_guessed);
}

test "synergy, filters and reasons" {
    var t = try buildTestStats();
    defer t.deinit();
    var out: [4]Suggestion = undefined;

    const with_lux = recommend(&t.stats, .{
        .role = .top,
        .allies = &.{.{ .champion = lux, .role = .utility, .hover = true }},
    }, test_opts, &out);
    try testing.expectEqual(garen, with_lux[0].champion);
    const r = with_lux[0].reasons()[0];
    try testing.expectEqual(Reason.Kind.ally, r.kind);
    try testing.expect(r.hover);
    try testing.expect(r.pp > 1);

    var buf: [128]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    try describe(&t.stats, r, &w);
    try testing.expect(std.mem.startsWith(u8, w.buffered(), "+"));
    try testing.expect(std.mem.endsWith(u8, w.buffered(), "% with Lux (support, hover)"));

    // Banned, picked by an enemy, outside the pool
    try testing.expectEqual(darius, recommend(&t.stats, .{
        .role = .top,
        .allies = &.{.{ .champion = lux, .role = .utility }},
        .bans = &.{garen},
    }, test_opts, &out)[0].champion);
    try testing.expectEqual(darius, recommend(&t.stats, .{
        .role = .top,
        .enemies = &.{.{ .champion = garen, .role = .top }},
    }, test_opts, &out)[0].champion);
    try testing.expectEqual(1, recommend(&t.stats, .{
        .role = .top,
        .pool = &.{ darius, ahri },
    }, test_opts, &out).len);
    const mid = recommend(&t.stats, .{ .role = .middle }, test_opts, &out);
    try testing.expectEqual(2, mid.len);
    const none = recommend(&t.stats, .{ .role = .top }, test_opts, out[0..0]);
    try testing.expectEqual(0, none.len);
}

test "full draft agrees with recommend" {
    var t = try buildTestStats();
    defer t.deinit();
    const teams: [2][5]u32 = .{ .{ garen, vi, ahri, 0, lux }, .{ darius, 0, zed, jinx, 0 } };
    const p = draftWin(&t.stats, test_opts, teams);
    const swapped = draftWin(&t.stats, test_opts, .{ teams[1], teams[0] });
    try testing.expectApproxEqAbs(1, p + swapped, 1e-12);
    var plain = test_opts;
    plain.weights = .{};
    const terms = draftTerms(&t.stats, plain, teams);
    try testing.expectApproxEqAbs(sigmoid(terms.total()), draftWin(&t.stats, plain, teams), 1e-12);
    try testing.expect(@abs(p - draftWin(&t.stats, plain, teams)) > 1e-6);

    // More games behind every term, a narrower range; the same either way round
    const se = draftSe(&t.stats, test_opts, teams);
    try testing.expectApproxEqAbs(se, draftSe(&t.stats, test_opts, .{ teams[1], teams[0] }), 1e-12);
    var loose = test_opts;
    loose.base_prior_games = 0;
    loose.prior_games = 1;
    try testing.expect(draftSe(&t.stats, loose, teams) > se);
    try testing.expect(se > 0);

    var out: [4]Suggestion = undefined;
    const s = recommend(&t.stats, .{
        .role = .top,
        .allies = &.{
            .{ .champion = vi, .role = .jungle },
            .{ .champion = ahri, .role = .middle },
            .{ .champion = lux, .role = .utility },
        },
        .enemies = &.{
            .{ .champion = darius, .role = .top },
            .{ .champion = zed, .role = .middle },
            .{ .champion = jinx, .role = .bottom },
        },
        .pool = &.{garen},
    }, test_opts, &out);
    try testing.expectApproxEqAbs(s[0].win, p, 1e-12);

    var roles: [3]?Role = undefined;
    inferRoles(&t.stats, &.{ .{ .champion = 9999 }, .{ .champion = jinx }, .{ .champion = zed } }, &roles);
    try testing.expectEqual(null, roles[0]);
    try testing.expectEqual(Role.bottom, roles[1].?);
    try testing.expectEqual(Role.middle, roles[2].?);
}

test "enemy roles inferred jointly" {
    var t = try buildTestStats();
    defer t.deinit();
    var ctx: Context = .{ .stats = &t.stats, .opts = test_opts };
    const placed = ctx.resolve(&.{
        .{ .champion = jinx },
        .{ .champion = vi },
        .{ .champion = 9999 },
        .{ .champion = zed },
        .{ .champion = lux, .role = .utility },
    }, 5, .empty, &ctx.enemy_buf);
    try testing.expectEqual(4, placed.len);
    try testing.expectEqual(Role.bottom, placed[0].role);
    try testing.expectEqual(Role.jungle, placed[1].role);
    try testing.expectEqual(Role.middle, placed[2].role);
    try testing.expectEqual(Role.utility, placed[3].role);
    try testing.expect(!placed[3].guessed);
}
