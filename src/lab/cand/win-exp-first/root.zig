//! win-exp-first: win-exp plus a step for having played the champion before (cfg
//! champ_played). A copy, as a candidate imports only std and api:
//! keep in step with win-exp (diff: cfg, name and this header)
//!
//! Win from the draft, one logistic model per game (blue side's chance), nested so each
//! step's gain is measurable:
//!   rates:    blue-side rate per platform + each champion-role's own win rate as
//!             log-odds, pulled to 50% by `rate_prior` games (eval's base rates)
//!   ratings:  blue-side intercept per platform + sum of champion-role ratings, blue minus
//!             red (eval's joint ratings, fitted by Adam)
//!   lane:     + lane-opponent interactions (both enemies for bottom and support):
//!             w[my role][their role] * <u[me], v[them]>, blue's minus red's
//!   counters: the same interaction with all five enemies
//!   full:     counters + teammate synergy, z[role][role] * <s[a], s[b]> per ally pair
//! Optional: own_rank (champ select: the user's rank, a per-role slope on top of the
//! game's logit) and all_ranks (post-game only: everyone's rank, an upper bound on what
//! rank data is worth). Internal only, from everyone's api.Experience, per-role weights
//! on blue's minus red's: champ_exp (log1p games on the champion, its shrunk win rate's
//! log-odds) and form (the same on any champion, plus mean KDA, lane gold diff at 14
//! and deaths before 15, each pulled to the average by n / (n + 3)); skill (with
//! champ_exp: each champion-role's own extra slope on log1p(games on the champion),
//! shrunk to 0 by the ratings' L2, so the role's shared slope where data is thin;
//! effects-skill-<role>.tsv). L2 and dim picked on the newest 10% of visible games, refit on
//! all of them. Other outcomes: no opinion. Variants differ only in `cfg` (docs/model.md)

const std = @import("std");
const api = @import("api");

const Kind = enum { rates, ratings, lane, counters, full };

const Cfg = struct {
    kind: Kind,
    own_rank: bool = false,
    all_ranks: bool = false,
    champ_exp: bool = false,
    /// With champ_exp: a step for having played the champion before (calibration by bucket
    /// showed log1p alone under-reacts to who has and hasn't)
    champ_played: bool = false,
    form: bool = false,
    skill: bool = false,
    /// Only games of this platform index (protocol.platformIds order); null for all
    platform: ?u8 = null,
    /// Days; older games weigh exp(-age / half_life * ln 2); 0 for equal weights
    half_life: f64 = 0,
};

const cfg: Cfg = .{ .kind = .ratings, .champ_exp = true, .form = true, .champ_played = true };

/// For exported files; variants differ by cfg.kind
pub const name = "win-exp-first";

const experience = cfg.champ_exp or cfg.form;

pub const scope: api.Scope = if (experience) .internal else if (cfg.all_ranks) .post_game else .champ_select;

const n_role = 5;
const n_platform = 256;
const val_share = 0.1;
const batch = 2048;
const lr = 0.003;
const max_epochs = 60;
const patience = 5;
/// Rank units: 0 Iron IV .. 39 Challenger I, centred on the training mean
const rank_scale = 1.0 / 4.0;

const rate_prior = 1000;

/// Per player: champ_exp's 2 then form's 5 (expFeatures), then champ_played's 1
const n_exp = if (cfg.champ_played) 8 else 7;
/// Pseudo-games at 50% in an experience win rate
const exp_prior = 5;

const l2_grid = [_]f32{ 3e-4, 1e-3, 3e-3, 1e-2 };
const dim_grid: []const u32 = if (cfg.kind == .ratings or cfg.kind == .rates) &.{0} else &.{ 4, 8 };

/// One game: dense champion-role ids by side and role (0 = unseen), blue won
const Game = struct {
    ids: [2][n_role]u16,
    platform: u8,
    /// Everyone's rank minus the mean, blue's minus red's per role (all_ranks only)
    rank_diff: [n_role]f32,
    /// Experience features, blue's minus red's per role (experience only)
    exp_diff: [n_role][n_exp]f32,
    /// log1p(games on the champion) by side and role (skill only)
    skill_x: [2][n_role]f32,
    y: f32,
    weight: f32,
};

const Space = struct {
    dim: u32,
    n_ids: usize,
    // Offsets into the flat parameter slice
    c: usize,
    b: usize,
    u: usize,
    v: usize,
    w: usize,
    s: usize,
    z: usize,
    k: usize,
    e: usize,
    /// skill: per champion-role slope
    q: usize,
    len: usize,

    fn init(n_ids: usize, dim: u32) Space {
        var sp: Space = undefined;
        sp.dim = dim;
        sp.n_ids = n_ids;
        const d: usize = dim;
        var at: usize = 0;
        inline for (.{ "c", "b", "u", "v", "w", "s", "z", "k", "e", "q" }, .{ n_platform, n_ids, n_ids * d, n_ids * d, 25, n_ids * d, 25, n_role, n_role * n_exp, if (cfg.skill) n_ids else 0 }) |field, size| {
            @field(sp, field) = at;
            at += size;
        }
        sp.len = at;
        return sp;
    }
};

fn laneMates(mine: usize, theirs: usize) bool {
    const bot = @backingInt(api.Role.bottom);
    const sup = @backingInt(api.Role.utility);
    return mine == theirs or (mine >= bot and theirs >= bot and mine <= sup and theirs <= sup);
}

fn interacts(mine: usize, theirs: usize) bool {
    return switch (cfg.kind) {
        .rates, .ratings => false,
        .lane => laneMates(mine, theirs),
        .counters, .full => true,
    };
}

fn dot(a: []const f32, b: []const f32) f32 {
    var s: f32 = 0;
    for (a, b) |x, y| s += x * y;
    return s;
}

const Params = struct {
    sp: Space,
    p: []f32,

    fn vec(m: Params, off: usize, id: u16) []f32 {
        const d: usize = m.sp.dim;
        return m.p[off + @as(usize, id) * d ..][0..d];
    }

    fn logit(m: Params, g: *const Game) f32 {
        const p = m.p;
        const sp = m.sp;
        var s = p[sp.c + g.platform];
        for (0..n_role) |r| s += p[sp.b + g.ids[0][r]] - p[sp.b + g.ids[1][r]];
        if (cfg.all_ranks) for (0..n_role) |r| {
            s += p[sp.k + r] * g.rank_diff[r];
        };
        if (experience) for (0..n_role) |r| {
            s += dot(p[sp.e + r * n_exp ..][0..n_exp], &g.exp_diff[r]);
        };
        if (cfg.skill) for (0..n_role) |r| {
            s += p[sp.q + g.ids[0][r]] * g.skill_x[0][r] - p[sp.q + g.ids[1][r]] * g.skill_x[1][r];
        };
        if (cfg.kind == .ratings or cfg.kind == .rates) return s;
        for (0..2) |side| {
            const sign: f32 = if (side == 0) 1 else -1;
            for (0..n_role) |ri| for (0..n_role) |rj| {
                if (!interacts(ri, rj)) continue;
                const uv = dot(m.vec(sp.u, g.ids[side][ri]), m.vec(sp.v, g.ids[1 - side][rj]));
                s += sign * p[sp.w + ri * n_role + rj] * uv;
            };
            if (cfg.kind == .full) for (0..n_role) |ri| for (ri + 1..n_role) |rj| {
                const ss = dot(m.vec(sp.s, g.ids[side][ri]), m.vec(sp.s, g.ids[side][rj]));
                s += sign * p[sp.z + ri * n_role + rj] * ss;
            };
        }
        return s;
    }

    /// Adds d(loss)/d(params) for g with residual r = p - y (log loss), times weight
    fn grad(m: Params, g: *const Game, r: f32, gr: []f32) void {
        const p = m.p;
        const sp = m.sp;
        const d: usize = sp.dim;
        gr[sp.c + g.platform] += r;
        for (0..n_role) |ro| {
            gr[sp.b + g.ids[0][ro]] += r;
            gr[sp.b + g.ids[1][ro]] -= r;
        }
        if (cfg.all_ranks) for (0..n_role) |ro| {
            gr[sp.k + ro] += r * g.rank_diff[ro];
        };
        if (experience) for (0..n_role) |ro| for (0..n_exp) |j| {
            gr[sp.e + ro * n_exp + j] += r * g.exp_diff[ro][j];
        };
        if (cfg.skill) for (0..n_role) |ro| {
            gr[sp.q + g.ids[0][ro]] += r * g.skill_x[0][ro];
            gr[sp.q + g.ids[1][ro]] -= r * g.skill_x[1][ro];
        };
        if (cfg.kind == .ratings or cfg.kind == .rates) return;
        for (0..2) |side| {
            const rs = if (side == 0) r else -r;
            for (0..n_role) |ri| for (0..n_role) |rj| {
                if (!interacts(ri, rj)) continue;
                const a = g.ids[side][ri];
                const b = g.ids[1 - side][rj];
                const ua = m.vec(sp.u, a);
                const vb = m.vec(sp.v, b);
                const wi = sp.w + ri * n_role + rj;
                gr[wi] += rs * dot(ua, vb);
                const wr = rs * p[wi];
                const gu = gr[sp.u + @as(usize, a) * d ..][0..d];
                const gv = gr[sp.v + @as(usize, b) * d ..][0..d];
                for (gu, gv, ua, vb) |*x, *y, pu, pv| {
                    x.* += wr * pv;
                    y.* += wr * pu;
                }
            };
            if (cfg.kind == .full) for (0..n_role) |ri| for (ri + 1..n_role) |rj| {
                const a = g.ids[side][ri];
                const b = g.ids[side][rj];
                const sa = m.vec(sp.s, a);
                const sb = m.vec(sp.s, b);
                const zi = sp.z + ri * n_role + rj;
                gr[zi] += rs * dot(sa, sb);
                const zr = rs * p[zi];
                const ga = gr[sp.s + @as(usize, a) * d ..][0..d];
                const gb = gr[sp.s + @as(usize, b) * d ..][0..d];
                for (ga, gb, sa, sb) |*x, *y, pa, pb| {
                    x.* += zr * pb;
                    y.* += zr * pa;
                }
            };
        }
    }
};

fn sigmoid(x: f32) f32 {
    return 1 / (1 + @exp(-x));
}

fn logLoss(m: Params, set: []const Game) f64 {
    var s: f64 = 0;
    var wsum: f64 = 0;
    for (set) |*g| {
        const q = std.math.clamp(sigmoid(m.logit(g)), 1e-6, 1 - 1e-6);
        s -= g.weight * (g.y * @log(q) + (1 - g.y) * @log(1 - q));
        wsum += g.weight;
    }
    return s / @max(wsum, 1e-9);
}

const Trained = struct { p: []f32, epochs: u32, val_loss: f64 };

/// Adam on minibatches; with val, stops on it and keeps the best epoch's parameters
fn train(gpa: std.mem.Allocator, sp: Space, l2: f32, set: []const Game, val: ?[]const Game, epochs_cap: u32, seed: u64) !Trained {
    const p = try gpa.alloc(f32, sp.len);
    errdefer gpa.free(p);
    @memset(p, 0);
    var rng: std.Random.DefaultPrng = .init(seed);
    const rnd = rng.random();
    // Unseen (id 0) keeps zero vectors: it never appears in training
    for (sp.u + sp.dim..sp.u + sp.n_ids * sp.dim) |i| p[i] = (rnd.float(f32) - 0.5) * 0.02;
    for (sp.v + sp.dim..sp.v + sp.n_ids * sp.dim) |i| p[i] = (rnd.float(f32) - 0.5) * 0.02;
    for (sp.s + sp.dim..sp.s + sp.n_ids * sp.dim) |i| p[i] = (rnd.float(f32) - 0.5) * 0.02;
    @memset(p[sp.w..][0..25], 1);
    @memset(p[sp.z..][0..25], 1);
    const m: Params = .{ .sp = sp, .p = p };

    const scratch = try gpa.alloc(f32, sp.len * 4);
    defer gpa.free(scratch);
    const gr = scratch[0..sp.len];
    const m1 = scratch[sp.len .. 2 * sp.len];
    const m2 = scratch[2 * sp.len .. 3 * sp.len];
    const best = scratch[3 * sp.len ..];
    @memset(m1, 0);
    @memset(m2, 0);
    const order = try gpa.alloc(u32, set.len);
    defer gpa.free(order);
    for (order, 0..) |*o, i| o.* = @intCast(i);

    var best_loss = std.math.inf(f64);
    var best_epoch: u32 = 0;
    var step: u32 = 0;
    const b1: f32 = 0.9;
    const b2: f32 = 0.999;
    var epoch: u32 = 0;
    while (epoch < epochs_cap) : (epoch += 1) {
        rnd.shuffle(u32, order);
        var at: usize = 0;
        while (at < order.len) : (at += batch) {
            const part = order[at..@min(at + batch, order.len)];
            @memset(gr, 0);
            var wsum: f32 = 0;
            for (part) |i| {
                const g = &set[i];
                m.grad(g, g.weight * (sigmoid(m.logit(g)) - g.y), gr);
                wsum += g.weight;
            }
            const scale = 1 / @max(wsum, 1e-6);
            step += 1;
            const c1 = 1 - std.math.pow(f32, b1, @floatFromInt(step));
            const c2 = 1 - std.math.pow(f32, b2, @floatFromInt(step));
            for (p, gr, m1, m2, 0..) |*x, g0, *s1, *s2, i| {
                // No shrinkage on the side intercepts, the role-pair weights or the
                // experience weights (35, on every game)
                const shrink = !(i < sp.c + n_platform or (i >= sp.w and i < sp.w + 25) or (i >= sp.z and i < sp.z + 25) or
                    (i >= sp.e and i < sp.e + n_role * n_exp));
                const g = g0 * scale + if (shrink) l2 * x.* else 0;
                s1.* = b1 * s1.* + (1 - b1) * g;
                s2.* = b2 * s2.* + (1 - b2) * g * g;
                x.* -= lr * (s1.* / c1) / (@sqrt(s2.* / c2) + 1e-8);
            }
        }
        const v = val orelse {
            best_epoch = epoch + 1;
            continue;
        };
        const loss = logLoss(m, v);
        if (loss < best_loss - 1e-7) {
            best_loss = loss;
            best_epoch = epoch + 1;
            @memcpy(best, p);
        } else if (epoch + 1 - best_epoch >= patience) break;
    }
    if (val != null) @memcpy(p, best);
    return .{ .p = p, .epochs = best_epoch, .val_loss = best_loss };
}

pub const Model = struct {
    sp: Space,
    p: []f32,
    ids: std.AutoHashMapUnmanaged(u64, u16) = .empty,
    rank_mean: f32 = 0,
    /// own_rank: per-role slope on the user's centred rank, on the row's logit
    own: [n_role]f32 = @splat(0),
    /// Training games per dense id, for exportModel's sd
    id_games: []u32 = &.{},
    /// skill: per dense id, training players with earlier games on it and their sum of
    /// log1p(games)^2, for the effect table's n and sd
    skill_n: []u32 = &.{},
    skill_x2: []f32 = &.{},
    /// The rating prior's precision in logit units (L2 x games, or the rate prior)
    prior_precision: f32 = 0,
    /// form: training rows' mean KDA and deaths before 15, where known
    form_mean: [2]f32 = @splat(0),
};

fn key(champion: u32, role: usize) u64 {
    return (@as(u64, champion) << 3) | role;
}

fn idOf(m: *const Model, champion: u32, role: usize) u16 {
    return m.ids.get(key(champion, role)) orelse 0;
}

fn centred(rank: ?u8, mean: f32) f32 {
    const r = rank orelse return 0;
    return (@as(f32, @floatFromInt(r)) - mean) * rank_scale;
}

fn logOdds(wins: u16, games: u16) f32 {
    const q = (@as(f32, @floatFromInt(wins)) + exp_prior * 0.5) / (@as(f32, @floatFromInt(games)) + exp_prior);
    return @log(q / (1 - q));
}

/// n / (n + 3): a mean over few games counts for little
fn trust(n: u16) f32 {
    const x: f32 = @floatFromInt(n);
    return x / (x + 3);
}

fn expFeatures(m: *const Model, e: api.Experience) [n_exp]f32 {
    var out: [n_exp]f32 = @splat(0);
    if (cfg.champ_exp) {
        out[0] = std.math.log1p(@as(f32, @floatFromInt(e.champ_games)));
        out[1] = logOdds(e.champ_wins, e.champ_games);
    }
    if (cfg.form) {
        out[2] = std.math.log1p(@as(f32, @floatFromInt(e.games)));
        out[3] = logOdds(e.wins, e.games);
        if (e.games > 0) out[4] = (e.kda - m.form_mean[0]) * trust(e.games);
        if (e.perf_games > 0) {
            out[5] = e.lanediff14 / 1000 * trust(e.perf_games);
            out[6] = (e.deaths15 - m.form_mean[1]) * trust(e.perf_games);
        }
    }
    if (cfg.champ_played) out[7] = @floatFromInt(@intFromBool(e.champ_games > 0));
    return out;
}

fn gameOf(m: *const Model, g: *const api.Game, ranks: ?[2][n_role]?u8, exps: ?[2][n_role]api.Experience, y: f32, weight: f32) Game {
    var out: Game = .{ .ids = undefined, .platform = g.platform, .rank_diff = @splat(0), .exp_diff = @splat(@splat(0)), .skill_x = @splat(@splat(0)), .y = y, .weight = weight };
    for (0..2) |side| for (0..n_role) |r| {
        out.ids[side][r] = idOf(m, g.teams[side][r], r);
    };
    if (ranks) |rk| for (0..n_role) |r| {
        out.rank_diff[r] = centred(rk[0][r], m.rank_mean) - centred(rk[1][r], m.rank_mean);
    };
    if (exps) |e| for (0..n_role) |r| {
        const blue = expFeatures(m, e[0][r]);
        const red = expFeatures(m, e[1][r]);
        for (&out.exp_diff[r], blue, red) |*x, b, rd| x.* = b - rd;
        if (cfg.skill) for (0..2) |side| {
            out.skill_x[side][r] = std.math.log1p(@as(f32, @floatFromInt(e[side][r].champ_games)));
        };
    };
    return out;
}

pub fn fit(gpa: std.mem.Allocator, t: *const api.Train, opts: api.Options) !Model {
    var m: Model = .{ .sp = undefined, .p = &.{} };
    errdefer m.ids.deinit(gpa);

    // Blue won, per game, from any row with a win label
    const won = try gpa.alloc(f32, t.games.len);
    defer gpa.free(won);
    @memset(won, std.math.nan(f32));
    var rank_sum: f64 = 0;
    var rank_n: f64 = 0;
    for (t.rows) |r| {
        const y = r.y[api.outcomeIndex(.win)];
        if (!std.math.isNan(y)) won[r.game] = if (r.side == 0) y else 1 - y;
        if (r.rank) |rk| {
            rank_sum += @floatFromInt(rk);
            rank_n += 1;
        }
    }
    m.rank_mean = @floatCast(rank_sum / @max(rank_n, 1));
    var form_sum: [2]f64 = @splat(0);
    var form_n: [2]f64 = @splat(0);
    for (t.rows) |r| {
        if (r.exp.games > 0) {
            form_sum[0] += r.exp.kda;
            form_n[0] += 1;
        }
        if (r.exp.perf_games > 0) {
            form_sum[1] += r.exp.deaths15;
            form_n[1] += 1;
        }
    }
    for (&m.form_mean, form_sum, form_n) |*x, sm, n| x.* = @floatCast(sm / @max(n, 1));

    var newest: i64 = std.math.minInt(i64);
    for (t.games) |g| newest = @max(newest, g.start);
    var next_id: u16 = 1;
    var games: std.ArrayList(Game) = .empty;
    defer games.deinit(gpa);
    var starts: std.ArrayList(i64) = .empty;
    defer starts.deinit(gpa);
    for (t.games, won) |*g, y| {
        if (std.math.isNan(y)) continue;
        if (cfg.platform) |pl| if (g.platform != pl) continue;
        for (0..n_role) |r| for (0..2) |side| {
            const e = try m.ids.getOrPut(gpa, key(g.teams[side][r], r));
            if (!e.found_existing) {
                e.value_ptr.* = next_id;
                next_id += 1;
            }
        };
        const age_days = @as(f64, @floatFromInt(newest - g.start)) / 86_400_000;
        const weight: f32 = if (cfg.half_life > 0) @floatCast(@exp(-age_days / cfg.half_life * @log(2.0))) else 1;
        try games.append(gpa, gameOf(&m, g, if (cfg.all_ranks) g.ranks else null, if (experience) g.exp else null, y, weight));
        try starts.append(gpa, g.start);
    }

    m.id_games = try gpa.alloc(u32, next_id);
    errdefer gpa.free(m.id_games);
    @memset(m.id_games, 0);
    for (games.items) |g| for (g.ids) |team| for (team) |id| {
        m.id_games[id] += 1;
    };
    if (cfg.skill) {
        m.skill_n = try gpa.alloc(u32, next_id);
        m.skill_x2 = try gpa.alloc(f32, next_id);
        @memset(m.skill_n, 0);
        @memset(m.skill_x2, 0);
        for (games.items) |g| for (g.ids, g.skill_x) |team, xs| for (team, xs) |id, x| {
            if (x == 0) continue;
            m.skill_n[id] += 1;
            m.skill_x2[id] += x * x;
        };
    }

    // Validation: the newest share of games by start
    const sorted = try gpa.dupe(i64, starts.items);
    defer gpa.free(sorted);
    std.mem.sort(i64, sorted, {}, std.sort.asc(i64));
    const cut = sorted[@intFromFloat(@as(f64, @floatFromInt(sorted.len)) * (1 - val_share))];
    var fit_set: std.ArrayList(Game) = .empty;
    defer fit_set.deinit(gpa);
    var val_set: std.ArrayList(Game) = .empty;
    defer val_set.deinit(gpa);
    for (games.items, starts.items) |g, s| try (if (s >= cut) &val_set else &fit_set).append(gpa, g);

    if (cfg.kind == .rates) {
        m.sp = .init(next_id, 0);
        m.p = try rates(gpa, m.sp, games.items);
        m.prior_precision = rate_prior * 0.25;
        if (cfg.own_rank) fitOwnRank(&m, t, won);
        return m;
    }

    var best: struct { l2: f32 = 0, dim: u32 = 0, epochs: u32 = 0, loss: f64 = std.math.inf(f64) } = .{};
    for (dim_grid) |dim| for (l2_grid) |l2| {
        const tr = try train(gpa, .init(next_id, dim), l2, fit_set.items, val_set.items, max_epochs, opts.seed);
        defer gpa.free(tr.p);
        if (tr.val_loss < best.loss) best = .{ .l2 = l2, .dim = dim, .epochs = tr.epochs, .loss = tr.val_loss };
    };
    m.sp = .init(next_id, best.dim);
    m.prior_precision = best.l2 * @as(f32, @floatFromInt(games.items.len));
    // A tenth more games: a tenth more epochs
    const refit = try train(gpa, m.sp, best.l2, games.items, null, @max(1, best.epochs + best.epochs / 10), opts.seed);
    m.p = refit.p;
    std.debug.print("win-model: kind {t} dim {d} l2 {d} epochs {d} val {d:.5} on {d} games\n", .{ cfg.kind, best.dim, best.l2, best.epochs, best.loss, games.items.len });
    if (experience) std.debug.print("win-model: experience weights by role (champ games, champ rate, games, rate, kda, lanediff, deaths15{s}) {any}\n", .{ if (cfg.champ_played) ", played" else "", m.p[m.sp.e..][0 .. n_role * n_exp] });

    if (cfg.own_rank) fitOwnRank(&m, t, won);
    return m;
}

/// Marginal rates as log-odds, no joint fit: the side intercept per platform and each
/// champion-role's team win rate, shrunk to 50%
fn rates(gpa: std.mem.Allocator, sp: Space, games: []const Game) ![]f32 {
    const p = try gpa.alloc(f32, sp.len);
    @memset(p, 0);
    const n = try gpa.alloc(f64, sp.n_ids + n_platform);
    defer gpa.free(n);
    const w = try gpa.alloc(f64, n.len);
    defer gpa.free(w);
    @memset(n, 0);
    @memset(w, 0);
    for (games) |g| {
        n[sp.n_ids + g.platform] += g.weight;
        w[sp.n_ids + g.platform] += g.weight * g.y;
        for (0..2) |side| for (g.ids[side]) |id| {
            n[id] += g.weight;
            w[id] += g.weight * (if (side == 0) g.y else 1 - g.y);
        };
    }
    for (0..sp.n_ids) |id| {
        const q = (w[id] + rate_prior * 0.5) / (n[id] + rate_prior);
        p[sp.b + id] = @floatCast(@log(q / (1 - q)));
    }
    for (0..n_platform) |pl| {
        const q = (w[sp.n_ids + pl] + 50) / (n[sp.n_ids + pl] + 100);
        p[sp.c + pl] = @floatCast(@log(q / (1 - q)));
    }
    return p;
}

/// Per role, one slope on the user's centred rank with the game's logit as offset:
/// Newton steps on the training rows, a weak ridge
fn fitOwnRank(m: *Model, t: *const api.Train, won: []const f32) void {
    const params: Params = .{ .sp = m.sp, .p = m.p };
    for (0..n_role) |role| {
        var beta: f64 = 0;
        for (0..8) |_| {
            var g1: f64 = 0;
            var h: f64 = 1;
            for (t.rows) |r| {
                if (@backingInt(r.role) != role) continue;
                const y = won[r.game];
                if (std.math.isNan(y)) continue;
                const x = centred(r.rank, m.rank_mean);
                if (x == 0) continue;
                const tg = gameOf(m, &t.games[r.game], null, null, y, 1);
                const base = params.logit(&tg);
                const off: f64 = if (r.side == 0) base else -base;
                const yr: f64 = if (r.side == 0) y else 1 - y;
                const q = 1 / (1 + @exp(-(off + beta * x)));
                g1 += (q - yr) * x;
                h += q * (1 - q) * x * x;
            }
            beta -= g1 / h;
        }
        m.own[role] = @floatCast(beta);
    }
    std.debug.print("win-model: own rank slopes {any}\n", .{m.own});
}

pub fn predict(m: *const Model, q: *const api.Query) api.Prediction {
    var out = api.no_opinion;
    const g: api.Game = .{ .start = q.start, .patch = q.patch, .platform = q.platform, .teams = q.teams, .ranks = @splat(@splat(null)), .exp = @splat(@splat(.{})) };
    const tg = gameOf(m, &g, if (cfg.all_ranks) q.ranks else null, if (experience) q.exps else null, 0, 1);
    const params: Params = .{ .sp = m.sp, .p = m.p };
    const blue = params.logit(&tg);
    var s = if (q.side == 0) blue else -blue;
    if (cfg.own_rank) s += m.own[@backingInt(q.role)] * centred(q.rank, m.rank_mean);
    out[api.outcomeIndex(.win)] = sigmoid(s);
    return out;
}

/// One champion-role's terms; vectors empty when the kind has none
pub const Term = struct {
    champion: u32,
    /// api.Role order: top jungle middle bottom utility
    role: u8,
    games: u32,
    /// Rating, logit units
    b: f32,
    /// Approximate sd of b: 1 / sqrt(games / 4 + prior precision) (Laplace, diagonal)
    sd: f32,
    u: []const f32,
    v: []const f32,
    s: []const f32,
};

pub const Export = struct {
    kind: []const u8,
    dim: u32,
    /// Blue side's intercept by platform index (protocol.platformIds order)
    intercept: []const f32,
    /// Counters: w[mine * 5 + theirs], 0 for pairs the kind leaves out
    w: [25]f32,
    /// Ally synergy: z[a * 5 + b] for a < b, 0 unless kind full
    z: [25]f32,
    terms: []const Term,
};

/// The fitted parameters for meiolol-lab draft --export (docs/model.md "Draft model file")
pub fn exportModel(m: *const Model, arena: std.mem.Allocator) !Export {
    const sp = m.sp;
    const d: usize = sp.dim;
    var terms: std.ArrayList(Term) = .empty;
    var it = m.ids.iterator();
    while (it.next()) |e| {
        const id = e.value_ptr.*;
        const games = m.id_games[id];
        try terms.append(arena, .{
            .champion = @intCast(e.key_ptr.* >> 3),
            .role = @intCast(e.key_ptr.* & 7),
            .games = games,
            .b = m.p[sp.b + id],
            .sd = 1 / @sqrt(@as(f32, @floatFromInt(games)) / 4 + m.prior_precision),
            .u = if (d > 0) m.p[sp.u + @as(usize, id) * d ..][0..d] else &.{},
            .v = if (d > 0) m.p[sp.v + @as(usize, id) * d ..][0..d] else &.{},
            .s = if (d > 0 and cfg.kind == .full) m.p[sp.s + @as(usize, id) * d ..][0..d] else &.{},
        });
    }
    var w: [25]f32 = @splat(0);
    var z: [25]f32 = @splat(0);
    for (0..n_role) |ri| for (0..n_role) |rj| {
        if (interacts(ri, rj)) w[ri * n_role + rj] = m.p[sp.w + ri * n_role + rj];
        if (cfg.kind == .full and ri < rj) z[ri * n_role + rj] = m.p[sp.z + ri * n_role + rj];
    };
    return .{ .kind = @tagName(cfg.kind), .dim = sp.dim, .intercept = m.p[sp.c..][0..n_platform], .w = w, .z = z, .terms = terms.items };
}

/// skill: per role, each champion's win chance from 0 to 50 earlier games on it (the
/// role's shared slope plus its own), linearised at 50%
pub fn effects(m: *const Model, arena: std.mem.Allocator, target: api.Outcome) ![]const api.Effects {
    if (!cfg.skill or target != .win) return &.{};
    const role_names = [_][]const u8{ "top", "jungle", "middle", "bottom", "utility" };
    const span = @log(51.0);
    var tables: [n_role]std.ArrayList(api.Effect) = @splat(.empty);
    var it = m.ids.iterator();
    while (it.next()) |e| {
        const id = e.value_ptr.*;
        const role: usize = @intCast(e.key_ptr.* & 7);
        const slope = m.p[m.sp.e + role * n_exp] + m.p[m.sp.q + id];
        const sd = 1 / @sqrt(m.skill_x2[id] / 4 + m.prior_precision);
        try tables[role].append(arena, .{
            .label = try std.fmt.allocPrint(arena, "#{d}", .{e.key_ptr.* >> 3}),
            .effect = 100 * (1 / (1 + @exp(-slope * span)) - 0.5),
            .ci = 25 * span * 1.96 * sd,
            .n = m.skill_n[id],
        });
    }
    const out = try arena.alloc(api.Effects, n_role);
    for (out, &tables, role_names) |*o, *t, rn| {
        std.mem.sort(api.Effect, t.items, {}, struct {
            fn more(_: void, a: api.Effect, b: api.Effect) bool {
                return a.effect > b.effect;
            }
        }.more);
        o.* = .{
            .name = try std.fmt.allocPrint(arena, "skill-{s}", .{rn}),
            .title = try std.fmt.allocPrint(arena, "Win chance from 0 to 50 earlier games on the champion, {s}", .{rn}),
            .unit = "win pp",
            .higher = "the champion rewards playing it a lot more",
            .rows = t.items,
        };
    }
    return out;
}

pub fn deinit(m: *Model, gpa: std.mem.Allocator) void {
    gpa.free(m.skill_n);
    gpa.free(m.skill_x2);
    gpa.free(m.id_games);
    gpa.free(m.p);
    m.ids.deinit(gpa);
}
