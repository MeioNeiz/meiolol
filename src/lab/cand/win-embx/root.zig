//! win-comp (ratings + damage mix) plus low-rank interactions on frozen champion-role
//! embeddings E (dim 12) that `meiolol-lab pretrain` learnt from each seat's early outcomes
//! and end-of-game stats (docs/model.md "Neural draft models"). Pair cells are too sparse
//! to learn; a d x d form over a 12-number description of each champion-role is ~150
//! weights. Terms, each blue's minus red's where one-sided:
//!   lane_cross: sum over the five same-role opponents of e_b' A e_r, A antisymmetric
//!   lane_duo:   bottom x utility, e_bot' S e_sup, S symmetric
//!   all_cross:  every blue x red pair, = (sum E_b)' A (sum E_r), A antisymmetric
//!   all_within: every teammate pair i < j, e_i' S e_j, S symmetric
//! Weights on features standardised to sd 1, own L2 picked on the newest 10% of visible
//! games with mix's L2 kept (none if no L2 beats ratings + mix). Ratings and mix as win-comp.
//! E per fit set from Options.embeddings (`meiolol-lab --emb DIR`): the harness hands over
//! the file learnt on exactly this fit set's games, else the fit fails, so E never saw a
//! scored game; the inner val games are inside E's fit set (L2 choice only).
//! cfg.folds: every Variant on the forward folds, seeds 1-3 averaged per game, in the
//! seed-1 fit (effects table folds)

const std = @import("std");
const api = @import("api");

const Feature = enum { magic, true_dmg, dmg, tank, taken, armour, cc, immob, ally, heal, range, buildings };
const n_raw = std.enums.values(Feature).len;

const labels = [n_raw][]const u8{
    "magic share",
    "true share",
    "damage/min",
    "mitigated share",
    "taken/min",
    "armour minus MR",
    "CC/min",
    "immobilise/min",
    "ally heal+shield/min",
    "own heal/min",
    "range",
    "buildings/min",
};

const Cfg = struct {
    prior: bool = false,
    balance: bool = false,
    team: bool = false,
    /// team's within-team forms, on the five raw profiles
    forms: []const TeamForm = &.{ .mix, .frontline },
    cross: bool = false,
    features: []const Feature = std.enums.values(Feature),
    /// Pseudo-games at the role mean, per half (wins, losses)
    pseudo: f64 = 20,
    /// Comp stage leaves the intercepts and ratings as fitted (else trains them jointly)
    freeze: bool = false,
    /// Forward-chaining folds over the visible games for the nested ablation (effects
    /// table folds); 0 for none
    folds: u8 = 0,
    lane_cross: bool = false,
    lane_duo: bool = false,
    all_cross: bool = false,
    all_within: bool = false,
    /// Control: each champion-role gets another one's E from the same role (a fixed
    /// shuffle), so a gain must come from what E says, not from the extra weights
    shuffle: bool = false,
};

const base_cfg: Cfg = .{ .team = true, .forms = &.{.mix}, .freeze = true };

/// The steps of the fold table, in order; the first two are win-ratings and win-comp
const Variant = enum { ratings, mix, lane, all, cross, within, both, shuffled };

fn variantCfg(v: Variant) Cfg {
    var c = base_cfg;
    switch (v) {
        .ratings => c.team = false,
        .mix => {},
        .lane => {
            c.lane_cross = true;
            c.lane_duo = true;
        },
        .all => {
            c.all_cross = true;
            c.all_within = true;
        },
        .cross => c.all_cross = true,
        .within => c.all_within = true,
        .both => {
            c.lane_cross = true;
            c.lane_duo = true;
            c.all_cross = true;
            c.all_within = true;
        },
        .shuffled => {
            c.all_cross = true;
            c.all_within = true;
            c.shuffle = true;
        },
    }
    return c;
}

/// The variant scored (exp, netcheck's per-game blocks); folds = 5 adds the in-candidate
/// fold table of every variant (deecc3f's run 20261013T215827Z-embx-all)
const variant: Variant = .all;
const cfg: Cfg = variantCfg(variant);
/// Sealed confirmation seeds: 3 maps the harness's seeds 1-3 to E (and fit) seeds 4-6
const seed_offset: u64 = 3;

pub const name = "win-embx";

pub const scope: api.Scope = .champ_select;
/// Profiles come from Row.stats: without SNAP/seat_stats.tsv the fit fails, not ratings
pub const needs_stats = true;

const n_role = 5;
const n_platform = 256;
/// Within-team forms on f = the team's damage-weighted magic share: mix (f - 0.5)^2,
/// ad_heavy min(f - 0.5, 0)^2, ap_heavy max(f - 0.5, 0)^2; frontline the soft max of the
/// five mitigated shares
const TeamForm = enum { mix, ad_heavy, ap_heavy, frontline };
const n_team = std.enums.values(TeamForm).len;

const form_labels = [n_team][]const u8{
    "team magic share off 50%, squared",
    "team AD-heavy (magic share under 50%), squared",
    "team AP-heavy (magic share over 50%), squared",
    "team best frontline",
};
/// pretrain's default --dim; a file of another width fails the fit
const emb_dim = 12;
const n_sym = emb_dim * (emb_dim + 1) / 2;
const n_anti = emb_dim * (emb_dim - 1) / 2;
const max_base_d = 5 * n_raw + n_raw * (n_raw + 1) / 2 + n_raw * (n_raw - 1) / 2 + n_team;
const max_d = max_base_d + 2 * n_sym + 2 * n_anti;
const val_share = 0.1;
const batch = 2048;
const lr = 0.003;
const max_epochs = 60;
const patience = 5;
const l2_grid = [_]f32{ 3e-4, 1e-3, 3e-3, 1e-2 };
/// On standardised features: 0.25 is the information one game gives a weight
const comp_l2_grid = [_]f32{ 1e-3, 1e-2, 1e-1, 1 };
/// 0.25 is all the training games' information on a weight: 1e-1 and 1 are strong
const emb_l2_grid = [_]f32{ 1e-3, 1e-2, 3e-2, 1e-1, 3e-1, 1 };
/// Frontline soft max temperature, in mitigated share
const front_tau = 0.05;

fn baseCount(c: Cfg) usize {
    const k = c.features.len;
    var d: usize = 0;
    if (c.prior) d += n_role * k;
    if (c.balance) d += k * (k + 1) / 2;
    if (c.cross) d += k * (k - 1) / 2;
    if (c.team) d += c.forms.len;
    return d;
}

fn termCount(c: Cfg) usize {
    var d = baseCount(c);
    if (c.lane_cross) d += n_anti;
    if (c.lane_duo) d += n_sym;
    if (c.all_cross) d += n_anti;
    if (c.all_within) d += n_sym;
    return d;
}

fn hasEmb(c: Cfg) bool {
    return c.lane_cross or c.lane_duo or c.all_cross or c.all_within;
}

/// One game: dense champion-role ids by side and role (0 = unseen), blue won, comp features
const Game = struct {
    ids: [2][n_role]u16,
    platform: u8,
    y: f32,
    x: []const f32,
    /// Index into Train.games
    src: u32 = 0,
};

fn dot(a: []const f32, b: []const f32) f32 {
    var s: f32 = 0;
    for (a, b) |x, y| s += x * y;
    return s;
}

/// Flat parameters: platform intercepts, ratings, then d comp weights
const Params = struct {
    n_ids: usize,
    d: usize,
    p: []f32,

    const c = 0;
    const b = n_platform;

    fn w(m: Params) usize {
        return b + m.n_ids;
    }

    fn len(n_ids: usize, d: usize) usize {
        return n_platform + n_ids + d;
    }

    fn logit(m: Params, g: *const Game) f32 {
        const p = m.p;
        var s = p[c + g.platform];
        for (0..n_role) |r| s += p[b + g.ids[0][r]] - p[b + g.ids[1][r]];
        return s + dot(p[m.w()..][0..m.d], g.x[0..m.d]);
    }

    fn grad(m: Params, g: *const Game, r: f32, gr: []f32) void {
        gr[c + g.platform] += r;
        for (0..n_role) |ro| {
            gr[b + g.ids[0][ro]] += r;
            gr[b + g.ids[1][ro]] -= r;
        }
        for (gr[m.w()..][0..m.d], g.x[0..m.d]) |*x, v| x.* += r * v;
    }
};

fn sigmoid(x: f32) f32 {
    return 1 / (1 + @exp(-x));
}

fn logLoss(m: Params, set: []const Game) f64 {
    var s: f64 = 0;
    for (set) |*g| {
        const q = std.math.clamp(sigmoid(m.logit(g)), 1e-6, 1 - 1e-6);
        s -= g.y * @log(q) + (1 - g.y) * @log(1 - q);
    }
    return s / @max(@as(f64, @floatFromInt(set.len)), 1e-9);
}

const Trained = struct { p: []f32, epochs: u32, val_loss: f64 };

/// Adam on minibatches (win-ratings' train); from `init` when given (shorter: the rest
/// starts at 0); with val, stops on it and keeps the best epoch's parameters
/// Comp weights from `split` on take l2e instead of l2w (the embedding terms)
fn train(gpa: std.mem.Allocator, n_ids: usize, d: usize, l2: f32, l2w: f32, set: []const Game, val: ?[]const Game, epochs_cap: u32, seed: u64, init: ?[]const f32, frozen: usize, split: usize, l2e: f32) !Trained {
    const n = Params.len(n_ids, d);
    const p = try gpa.alloc(f32, n);
    errdefer gpa.free(p);
    @memset(p, 0);
    if (init) |x| @memcpy(p[0..x.len], x);
    var rng: std.Random.DefaultPrng = .init(seed);
    const rnd = rng.random();
    const m: Params = .{ .n_ids = n_ids, .d = d, .p = p };

    const scratch = try gpa.alloc(f32, n * 4);
    defer gpa.free(scratch);
    const gr = scratch[0..n];
    const m1 = scratch[n .. 2 * n];
    const m2 = scratch[2 * n .. 3 * n];
    const best = scratch[3 * n ..];
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
            for (part) |i| {
                const g = &set[i];
                m.grad(g, sigmoid(m.logit(g)) - g.y, gr);
            }
            const scale = 1 / @max(@as(f32, @floatFromInt(part.len)), 1e-6);
            step += 1;
            const c1 = 1 - std.math.pow(f32, b1, @floatFromInt(step));
            const c2 = 1 - std.math.pow(f32, b2, @floatFromInt(step));
            for (p, gr, m1, m2, 0..) |*x, g0, *s1, *s2, i| {
                if (i < frozen) continue;
                // Side intercepts unshrunk (on every game)
                const shrink: f32 = if (i < n_platform) 0 else if (i < m.w()) l2 else if (i < m.w() + split) l2w else l2e;
                const g = g0 * scale + shrink * x.*;
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
    c: Cfg,
    n_ids: usize = 0,
    /// Comp weights in use: 0 when the comp L2 search kept plain ratings
    d: usize = 0,
    p: []f32 = &.{},
    ids: std.AutoHashMapUnmanaged(u64, u16) = .empty,
    id_games: []u32 = &.{},
    id_role: []u8 = &.{},
    /// Per id, n_raw shrunk outcome-balanced means; id 0 unused (role_mean instead)
    raw: []f32 = &.{},
    /// Per id, cfg.features.len z-scores within the role; id 0 all 0
    z: []f32 = &.{},
    role_mean: [n_role][n_raw]f32 = @splat(@splat(0)),
    /// Per id, emb_dim; id 0 unused (role_emb instead): pretrain's E for this fit set
    emb: []f32 = &.{},
    role_emb: [n_role][emb_dim]f32 = @splat(@splat(0)),
    /// 1 / sd of each comp feature over training games, 0 for a constant one
    x_scale: [max_d]f32 = @splat(0),
    /// Laplace diagonal sd of each comp weight
    w_sd: [max_d]f32 = @splat(0),
    games: u32 = 0,
    /// The ratings' L2, for the export's rating sd
    l2: f32 = 0,
    /// The platform index with the most training games (effects' sanity drafts)
    main_platform: u8 = 0,
    /// cfg.folds' nested ablation, in chain order (ratings first)
    fold_rows: []FoldRow = &.{},

    /// buildProfiles' sums per [id][half][feature]: sum, count (leave-one-out)
    acc: []f64 = &.{},
    /// Within-role z: mean and sd per role and cfg.features entry (sd 0: z is 0)
    z_mean: [n_role][n_raw]f64 = @splat(@splat(0)),
    z_sd: [n_role][n_raw]f64 = @splat(@splat(0)),

    fn zOf(m: *const Model, id: u16) []const f32 {
        const k = m.c.features.len;
        return m.z[@as(usize, id) * k ..][0..k];
    }

    fn rawOf(m: *const Model, id: u16, role: usize) *const [n_raw]f32 {
        if (id == 0) return &m.role_mean[role];
        return m.raw[@as(usize, id) * n_raw ..][0..n_raw];
    }
};

fn key(champion: u32, role: usize) u64 {
    return (@as(u64, champion) << 3) | role;
}

fn idOf(m: *const Model, champion: u32, role: usize) u16 {
    return m.ids.get(key(champion, role)) orelse 0;
}

fn stat(s: []const f32, x: api.SeatStat) f32 {
    return s[@backingInt(x)];
}

/// One game's value of a profile feature, NaN when its stats are unknown
fn rowValue(f: Feature, s: []const f32) f32 {
    const nan = std.math.nan(f32);
    const mins = stat(s, .minutes);
    const per: f32 = if (mins > 0) 1 / mins else nan;
    const dealt = stat(s, .dmg_phys) + stat(s, .dmg_magic) + stat(s, .dmg_true);
    const taken = stat(s, .taken_phys) + stat(s, .taken_magic) + stat(s, .taken_true);
    const mitigated = stat(s, .mitigated);
    const share = struct {
        fn of(x: f32, total: f32) f32 {
            return if (total > 0) x / total else std.math.nan(f32);
        }
    }.of;
    return switch (f) {
        .magic => share(stat(s, .dmg_magic), dealt),
        .true_dmg => share(stat(s, .dmg_true), dealt),
        .dmg => dealt * per,
        .tank => share(mitigated, mitigated + taken),
        .taken => taken * per,
        .armour => stat(s, .armor_end) - stat(s, .mr_end),
        .cc => stat(s, .cc_time) * per,
        .immob => stat(s, .immobilisations) * per,
        .ally => (stat(s, .heal_allies) + stat(s, .shield_allies)) * per,
        // heal is Riot's totalHeal, teammates included
        .heal => blk: {
            const own = stat(s, .heal) - stat(s, .heal_allies);
            break :blk if (std.math.isNan(own)) nan else @max(own, 0) * per;
        },
        .range => stat(s, .attack_range),
        .buildings => stat(s, .dmg_buildings) * per,
    };
}

/// Shrunk outcome-balanced means and within-role z-scores per id, from the rows of
/// training games that started before `before` (z weighted by those rows)
fn buildProfiles(gpa: std.mem.Allocator, m: *Model, t: *const api.Train, before: i64) !void {
    const n = m.n_ids;
    const k = m.c.features.len;
    gpa.free(m.raw);
    gpa.free(m.z);
    m.raw = &.{};
    m.z = &.{};
    const seen = try gpa.alloc(u32, n);
    defer gpa.free(seen);
    @memset(seen, 0);
    // [id][half][feature]: sum, count
    gpa.free(m.acc);
    m.acc = &.{};
    const acc = try gpa.alloc(f64, n * 2 * n_raw * 2);
    m.acc = acc;
    m.z_mean = @splat(@splat(0));
    m.z_sd = @splat(@splat(0));
    @memset(acc, 0);
    var role_acc: [n_role][n_raw][2]f64 = @splat(@splat(@splat(0)));
    for (t.rows) |r| {
        const y = r.y[api.outcomeIndex(.win)];
        if (std.math.isNan(y) or t.games[r.game].start >= before) continue;
        const role: usize = @backingInt(r.role);
        const id = idOf(m, r.champion, role);
        if (id == 0) continue;
        seen[id] += 1;
        const half: usize = @intFromBool(y > 0.5);
        for (std.enums.values(Feature), 0..) |f, fi| {
            const v = rowValue(f, &r.stats);
            if (std.math.isNan(v) or std.math.isInf(v)) continue;
            const at = ((@as(usize, id) * 2 + half) * n_raw + fi) * 2;
            acc[at] += v;
            acc[at + 1] += 1;
            role_acc[role][fi][0] += v;
            role_acc[role][fi][1] += 1;
        }
    }
    for (&m.role_mean, role_acc) |*mean, ra| for (mean, ra) |*x, a| {
        x.* = if (a[1] > 0) @floatCast(a[0] / a[1]) else 0;
    };
    m.raw = try gpa.alloc(f32, n * n_raw);
    @memset(m.raw, 0);
    for (1..n) |id| {
        const rm = &m.role_mean[m.id_role[id]];
        for (0..n_raw) |fi| {
            var v: f64 = 0;
            for (0..2) |half| {
                const at = ((id * 2 + half) * n_raw + fi) * 2;
                v += 0.5 * (acc[at] + m.c.pseudo * rm[fi]) / (acc[at + 1] + m.c.pseudo);
            }
            m.raw[id * n_raw + fi] = @floatCast(v);
        }
    }
    m.z = try gpa.alloc(f32, n * k);
    @memset(m.z, 0);
    for (0..n_role) |role| for (m.c.features, 0..) |f, j| {
        const fi: usize = @backingInt(f);
        var sw: f64 = 0;
        var s1: f64 = 0;
        var s2: f64 = 0;
        for (1..n) |id| {
            if (m.id_role[id] != role) continue;
            const wt: f64 = @floatFromInt(seen[id]);
            const v: f64 = m.raw[id * n_raw + fi];
            sw += wt;
            s1 += wt * v;
            s2 += wt * v * v;
        }
        if (sw == 0) continue;
        const mean = s1 / sw;
        const sd = @sqrt(@max(s2 / sw - mean * mean, 0));
        if (sd < 1e-9 * @max(@abs(mean), 1)) continue;
        m.z_mean[role][j] = mean;
        m.z_sd[role][j] = sd;
        for (1..n) |id| {
            if (m.id_role[id] != role) continue;
            m.z[id * k + j] = @floatCast((m.raw[id * n_raw + fi] - mean) / sd);
        }
    };
}

fn loadEmb(gpa: std.mem.Allocator, m: *Model, t: *const api.Train, opts: api.Options) !void {
    const src = opts.embeddings orelse return error.NoEmbeddings;
    var e = try src.forFit(gpa, t, opts.seed);
    defer e.deinit(gpa);
    if (e.dim != emb_dim) return error.EmbeddingDim;
    gpa.free(m.emb);
    m.emb = try gpa.alloc(f32, m.n_ids * emb_dim);
    const own = try gpa.alloc(bool, m.n_ids);
    defer gpa.free(own);
    @memset(own, false);
    for (e.rows) |r| {
        const role: usize = @backingInt(r.role);
        if (r.champion == 0) {
            @memcpy(&m.role_emb[role], r.e);
            continue;
        }
        const id = m.ids.get(key(r.champion, role)) orelse continue;
        own[id] = true;
        @memcpy(m.emb[@as(usize, id) * emb_dim ..][0..emb_dim], r.e);
    }
    for (1..m.n_ids) |id| if (!own[id]) {
        m.emb[id * emb_dim ..][0..emb_dim].* = m.role_emb[m.id_role[id]];
    };
    if (m.c.shuffle) shuffleEmb(m, opts.seed);
}

/// A fixed permutation within each role of the champion-roles with their own E
fn shuffleEmb(m: *Model, seed: u64) void {
    var rng: std.Random.DefaultPrng = .init(0x5eed ^ seed);
    for (0..n_role) |role| {
        var i: usize = m.n_ids;
        while (i > 1) {
            i -= 1;
            if (m.id_role[i] != role or m.id_games[i] == 0) continue;
            const j = 1 + rng.random().uintLessThan(usize, i);
            if (m.id_role[j] != role) continue;
            for (m.emb[i * emb_dim ..][0..emb_dim], m.emb[j * emb_dim ..][0..emb_dim]) |*a, *b| std.mem.swap(f32, a, b);
        }
    }
}

/// Game-weighted correlations of the z profiles, pooled over roles, to the log
fn printCorrelations(m: *const Model) void {
    const k = m.c.features.len;
    std.debug.print("win-embx: profile correlations (champion-roles weighted by games)\n", .{});
    for (0..k) |i| {
        std.debug.print("  {s:>20}", .{labels[@backingInt(m.c.features[i])]});
        for (0..k) |j| {
            var sw: f64 = 0;
            var sx: f64 = 0;
            for (1..m.n_ids) |id| {
                const wt: f64 = @floatFromInt(m.id_games[id]);
                sw += wt;
                sx += wt * m.z[id * k + i] * m.z[id * k + j];
            }
            std.debug.print(" {d:>5.2}", .{sx / @max(sw, 1)});
        }
        std.debug.print("\n", .{});
    }
}

/// Magic share of the team's damage off 50%, squared; soft max of mitigated share
/// One player's profile as a game's comp features see it
const Slot = struct { z: [n_raw]f32, raw: [n_raw]f32, e: [emb_dim]f32 = @splat(0) };

fn slotOf(m: *const Model, id: u16, role: usize) Slot {
    var s: Slot = .{ .z = @splat(0), .raw = m.rawOf(id, role).* };
    @memcpy(s.z[0..m.c.features.len], m.zOf(id));
    if (m.emb.len > 0) s.e = if (id == 0) m.role_emb[role] else m.emb[@as(usize, id) * emb_dim ..][0..emb_dim].*;
    return s;
}

/// The profile without this row's own game: a training game's features never see its
/// own stats (they lean towards the result for a thin champion-role)
fn slotWithout(m: *const Model, id: u16, role: usize, row: *const api.Row) Slot {
    var s = slotOf(m, id, role);
    const y = row.y[api.outcomeIndex(.win)];
    if (id == 0 or std.math.isNan(y)) return s;
    const own: usize = @intFromBool(y > 0.5);
    const rm = &m.role_mean[role];
    for (std.enums.values(Feature), 0..) |f, fi| {
        const v = rowValue(f, &row.stats);
        if (std.math.isNan(v) or std.math.isInf(v)) continue;
        var raw: f64 = 0;
        for (0..2) |half| {
            const at = ((@as(usize, id) * 2 + half) * n_raw + fi) * 2;
            const drop: f64 = if (half == own) 1 else 0;
            raw += 0.5 * (m.acc[at] - drop * v + m.c.pseudo * rm[fi]) / (m.acc[at + 1] - drop + m.c.pseudo);
        }
        s.raw[fi] = @floatCast(raw);
    }
    for (m.c.features, 0..) |f, j| {
        const sd = m.z_sd[role][j];
        s.z[j] = if (sd > 0) @floatCast((s.raw[@backingInt(f)] - m.z_mean[role][j]) / sd) else 0;
    }
    return s;
}

fn teamForms(team: *const [n_role]Slot) [n_team]f32 {
    var num: f32 = 0;
    var den: f32 = 0;
    var top: f32 = -std.math.inf(f32);
    var tank: [n_role]f32 = undefined;
    for (team, 0..) |*slot, r| {
        const raw = &slot.raw;
        num += raw[@backingInt(Feature.dmg)] * raw[@backingInt(Feature.magic)];
        den += raw[@backingInt(Feature.dmg)];
        tank[r] = raw[@backingInt(Feature.tank)] / front_tau;
        top = @max(top, tank[r]);
    }
    var se: f32 = 0;
    for (tank) |x| se += @exp(x - top);
    const frac = if (den > 0) num / den else 0.5;
    const lo = @min(frac - 0.5, 0);
    const hi = @max(frac - 0.5, 0);
    return .{ (frac - 0.5) * (frac - 0.5), lo * lo, hi * hi, front_tau * (top + @log(se)) };
}

/// Unscaled comp features of a game, in termLabels' order
fn compX(c: Cfg, slots: *const [2][n_role]Slot, out: []f32) void {
    const k = c.features.len;
    var t: [2][n_raw]f32 = @splat(@splat(0));
    for (0..2) |side| for (&slots[side]) |*s| {
        for (t[side][0..k], s.z[0..k]) |*x, z| x.* += z;
    };
    var at: usize = 0;
    if (c.prior) for (0..n_role) |r| {
        for (slots[0][r].z[0..k], slots[1][r].z[0..k]) |zb, zr| {
            out[at] = zb - zr;
            at += 1;
        }
    };
    if (c.balance) for (0..k) |i| for (i..k) |j| {
        out[at] = t[0][i] * t[0][j] - t[1][i] * t[1][j];
        at += 1;
    };
    if (c.cross) for (0..k) |i| for (i + 1..k) |j| {
        out[at] = t[0][i] * t[1][j] - t[0][j] * t[1][i];
        at += 1;
    };
    if (c.team) {
        const blue = teamForms(&slots[0]);
        const red = teamForms(&slots[1]);
        for (c.forms) |form| {
            out[at] = blue[@backingInt(form)] - red[@backingInt(form)];
            at += 1;
        }
    }
    var es: [2][emb_dim]f32 = @splat(@splat(0));
    for (0..2) |side| for (&slots[side]) |*sl| {
        for (&es[side], sl.e) |*x, v| x.* += v;
    };
    if (c.lane_cross) for (0..emb_dim) |i| for (i + 1..emb_dim) |j| {
        var v: f32 = 0;
        for (0..n_role) |r| v += slots[0][r].e[i] * slots[1][r].e[j] - slots[0][r].e[j] * slots[1][r].e[i];
        out[at] = v;
        at += 1;
    };
    if (c.lane_duo) for (0..emb_dim) |i| for (i..emb_dim) |j| {
        var v: f32 = 0;
        for (0..2) |side| {
            const a = &slots[side][3].e;
            const b = &slots[side][4].e;
            const x = if (i == j) a[i] * b[i] else a[i] * b[j] + a[j] * b[i];
            v += if (side == 0) x else -x;
        }
        out[at] = v;
        at += 1;
    };
    if (c.all_cross) for (0..emb_dim) |i| for (i + 1..emb_dim) |j| {
        out[at] = es[0][i] * es[1][j] - es[0][j] * es[1][i];
        at += 1;
    };
    // Teammate pairs a < b: from team sums minus each player's own square
    if (c.all_within) for (0..emb_dim) |i| for (i..emb_dim) |j| {
        var v: f32 = 0;
        for (0..2) |side| {
            var own: f32 = 0;
            for (&slots[side]) |*sl| own += sl.e[i] * sl.e[j];
            var x = es[side][i] * es[side][j] - own;
            if (i == j) x /= 2;
            v += if (side == 0) x else -x;
        }
        out[at] = v;
        at += 1;
    };
    std.debug.assert(at == termCount(c));
}

fn termLabels(c: Cfg, arena: std.mem.Allocator) ![][]const u8 {
    const role_names = [_][]const u8{ "top", "jungle", "middle", "bottom", "utility" };
    const k = c.features.len;
    const out = try arena.alloc([]const u8, termCount(c));
    var at: usize = 0;
    const lab = struct {
        fn of(cc: Cfg, i: usize) []const u8 {
            return labels[@backingInt(cc.features[i])];
        }
    }.of;
    if (c.prior) for (role_names) |rn| for (0..k) |i| {
        out[at] = try std.fmt.allocPrint(arena, "prior {s} {s}", .{ rn, lab(c, i) });
        at += 1;
    };
    if (c.balance) for (0..k) |i| for (i..k) |j| {
        out[at] = try std.fmt.allocPrint(arena, "balance {s} x {s}", .{ lab(c, i), lab(c, j) });
        at += 1;
    };
    if (c.cross) for (0..k) |i| for (i + 1..k) |j| {
        out[at] = try std.fmt.allocPrint(arena, "cross {s} x enemy {s}", .{ lab(c, i), lab(c, j) });
        at += 1;
    };
    if (c.team) for (c.forms) |form| {
        out[at] = form_labels[@backingInt(form)];
        at += 1;
    };
    const forms = [_]struct { on: bool, name: []const u8, diag: bool }{
        .{ .on = c.lane_cross, .name = "lane cross", .diag = false },
        .{ .on = c.lane_duo, .name = "duo", .diag = true },
        .{ .on = c.all_cross, .name = "cross", .diag = false },
        .{ .on = c.all_within, .name = "within", .diag = true },
    };
    for (forms) |f| if (f.on) for (0..emb_dim) |i| for (i + @intFromBool(!f.diag)..emb_dim) |j| {
        out[at] = try std.fmt.allocPrint(arena, "{s} e{d} x e{d}", .{ f.name, i, j });
        at += 1;
    };
    return out;
}

/// Seeds pair with pretrain's: emb-*-s<seed>.tsv
pub const seeded = true;
pub const needs_embeddings = hasEmb(cfg);

pub fn fit(gpa: std.mem.Allocator, t: *const api.Train, opts: api.Options) !Model {
    var o = opts;
    o.seed += seed_offset;
    var m = try fitWith(gpa, t, o, cfg);
    errdefer deinit(&m, gpa);
    if (cfg.folds > 0 and opts.seed == 1) m.fold_rows = try foldAblation(gpa, t, opts, cfg);
    return m;
}

const FoldRow = struct {
    step: []const u8,
    games: u32,
    /// Seed-mean prediction's log loss
    loss: f64,
    /// Paired per-game log loss difference of the seed-mean predictions: mean, 95%
    /// half-width (one prediction per game, so clustered by game)
    vs_ratings: [2]f64,
    vs_mix: [2]f64,
    /// Lowest and highest single seed's mean difference vs ratings (same seed)
    seed_lo: f64,
    seed_hi: f64,
};

fn pairedMean(a: []const f64, b: []const f64) [2]f64 {
    var s: f64 = 0;
    var s2: f64 = 0;
    for (a, b) |x, y| {
        s += x - y;
        s2 += (x - y) * (x - y);
    }
    const n: f64 = @floatFromInt(@max(a.len, 1));
    const mean = s / n;
    return .{ mean, 1.96 * @sqrt(@max(s2 / n - mean * mean, 0) / n) };
}

const fold_seeds = 3;

fn logLossOf(y: f32, q: f64) f64 {
    const p = std.math.clamp(q, 1e-6, 1 - 1e-6);
    return -(y * @log(p) + (1 - y) * @log(1 - p));
}

/// The newest half of the visible games in c.folds time blocks (win-comp's, nnexport's
/// fold bounds); each block scored by every Variant fitted on all older games with seeds
/// 1-3, E from those games only (Options.embeddings), predictions averaged per game
fn foldAblation(gpa: std.mem.Allocator, t: *const api.Train, opts: api.Options, c: Cfg) ![]FoldRow {
    const variants = std.enums.values(Variant);
    const n_steps = variants.len;
    // Per step: seed-mean losses; per step and seed: single-seed losses
    var losses: [n_steps]std.ArrayList(f64) = @splat(.empty);
    defer for (&losses) |*l| l.deinit(gpa);
    var seed_losses: [n_steps][fold_seeds]std.ArrayList(f64) = @splat(@splat(.empty));
    defer for (&seed_losses) |*ls| for (ls) |*l| l.deinit(gpa);

    const won = try gpa.alloc(f32, t.games.len);
    defer gpa.free(won);
    @memset(won, std.math.nan(f32));
    for (t.rows) |r| {
        const y = r.y[api.outcomeIndex(.win)];
        if (!std.math.isNan(y)) won[r.game] = if (r.side == 0) y else 1 - y;
    }
    var sorted: std.ArrayList(i64) = .empty;
    defer sorted.deinit(gpa);
    for (t.games, won) |g, y| if (!std.math.isNan(y)) try sorted.append(gpa, g.start);
    std.mem.sort(i64, sorted.items, {}, std.sort.asc(i64));
    const quantile = struct {
        fn at(s: []const i64, q: f64) i64 {
            if (q >= 1) return std.math.maxInt(i64);
            return s[@intFromFloat(@as(f64, @floatFromInt(s.len)) * q)];
        }
    }.at;

    const remap = try gpa.alloc(u32, t.games.len);
    defer gpa.free(remap);
    var sum: std.ArrayList(f64) = .empty;
    defer sum.deinit(gpa);
    const k: f64 = @floatFromInt(c.folds);
    for (0..c.folds) |f| {
        const fi: f64 = @floatFromInt(f);
        const lo = quantile(sorted.items, 0.5 + 0.5 * fi / k);
        const hi = quantile(sorted.items, 0.5 + 0.5 * (fi + 1) / k);
        var sub_games: std.ArrayList(api.Game) = .empty;
        defer sub_games.deinit(gpa);
        for (t.games, remap) |g, *r| {
            r.* = std.math.maxInt(u32);
            if (g.start >= lo) continue;
            r.* = @intCast(sub_games.items.len);
            try sub_games.append(gpa, g);
        }
        var sub_rows: std.ArrayList(api.Row) = .empty;
        defer sub_rows.deinit(gpa);
        for (t.rows) |r| {
            if (remap[r.game] == std.math.maxInt(u32)) continue;
            var row = r;
            row.game = remap[r.game];
            try sub_rows.append(gpa, row);
        }
        const sub: api.Train = .{ .games = sub_games.items, .rows = sub_rows.items };
        for (variants, 0..) |v, sn| {
            var step = variantCfg(v);
            step.folds = 0;
            sum.clearRetainingCapacity();
            for (0..fold_seeds) |si| {
                var o = opts;
                o.seed = si + 1 + seed_offset;
                var m = try fitWith(gpa, &sub, o, step);
                defer deinit(&m, gpa);
                var at: usize = 0;
                for (t.games, won) |*g, y| {
                    if (std.math.isNan(y) or g.start < lo or g.start >= hi) continue;
                    const q: f64 = sigmoid(blueLogit(&m, &idsOf(&m, &g.teams), g.platform));
                    if (si == 0) try sum.append(gpa, 0);
                    sum.items[at] += q / fold_seeds;
                    try seed_losses[sn][si].append(gpa, logLossOf(y, q));
                    at += 1;
                }
            }
            var at: usize = 0;
            for (t.games, won) |*g, y| {
                if (std.math.isNan(y) or g.start < lo or g.start >= hi) continue;
                try losses[sn].append(gpa, logLossOf(y, sum.items[at]));
                at += 1;
            }
        }
        std.debug.print("win-embx: fold {d}: fit on {d} games, scored {d}\n", .{ f + 1, sub_games.items.len, sum.items.len });
    }

    const out = try gpa.alloc(FoldRow, n_steps);
    std.debug.print("win-embx: folds ({d}), seeds 1-{d} averaged per game, per-game log loss, paired 95%\n| step | games | log loss | vs ratings | vs mix | seeds vs ratings |\n| --- | --- | --- | --- | --- | --- |\n", .{ c.folds, fold_seeds });
    for (out, 0..) |*o, sn| {
        const ls = losses[sn].items;
        var total: f64 = 0;
        for (ls) |x| total += x;
        var lo: f64 = std.math.inf(f64);
        var hi: f64 = -std.math.inf(f64);
        for (0..fold_seeds) |si| {
            const d = pairedMean(seed_losses[sn][si].items, seed_losses[0][si].items)[0];
            lo = @min(lo, d);
            hi = @max(hi, d);
        }
        o.* = .{
            .step = @tagName(variants[sn]),
            .games = @intCast(ls.len),
            .loss = total / @as(f64, @floatFromInt(@max(ls.len, 1))),
            .vs_ratings = pairedMean(ls, losses[0].items),
            .vs_mix = pairedMean(ls, losses[1].items),
            .seed_lo = lo,
            .seed_hi = hi,
        };
        std.debug.print("| {s} | {d} | {d:.5} | {d:.5} ± {d:.5} | {d:.5} ± {d:.5} | {d:.5} .. {d:.5} |\n", .{ o.step, o.games, o.loss, o.vs_ratings[0], o.vs_ratings[1], o.vs_mix[0], o.vs_mix[1], lo, hi });
    }
    return out;
}

/// Profiles from games before `before`, then each game's comp features (games[i].x),
/// scaled by their sd over those games
fn prepareX(gpa: std.mem.Allocator, m: *Model, t: *const api.Train, before: i64, games: []const Game, starts: []const i64) !void {
    const d = termCount(m.c);
    try buildProfiles(gpa, m, t, before);
    // A game's rows: adjacent in t.rows
    const first = try gpa.alloc(u32, t.games.len);
    defer gpa.free(first);
    @memset(first, std.math.maxInt(u32));
    for (t.rows, 0..) |r, i| {
        if (first[r.game] == std.math.maxInt(u32)) first[r.game] = @intCast(i);
    }
    var s2: [max_d]f64 = @splat(0);
    var n: f64 = 0;
    for (games, starts) |*g, s| {
        const x = @constCast(g.x);
        var slots: [2][n_role]Slot = undefined;
        for (0..2) |side| for (0..n_role) |r| {
            slots[side][r] = slotOf(m, g.ids[side][r], r);
        };
        if (s < before and first[g.src] != std.math.maxInt(u32)) {
            var i = first[g.src];
            while (i < t.rows.len and t.rows[i].game == g.src) : (i += 1) {
                const row = &t.rows[i];
                const r: usize = @backingInt(row.role);
                slots[row.side][r] = slotWithout(m, g.ids[row.side][r], r, row);
            }
        }
        compX(m.c, &slots, x);
        if (s >= before) continue;
        for (s2[0..d], x) |*a, v| a.* += v * v;
        n += 1;
    }
    for (m.x_scale[0..d], s2[0..d]) |*sc, s| {
        const sd = @sqrt(s / @max(n, 1));
        sc.* = if (sd > 1e-6) @floatCast(1 / sd) else 0;
    }
    for (games) |g| for (@constCast(g.x), m.x_scale[0..d]) |*v, sc| {
        v.* *= sc;
    };
}

fn fitWith(gpa: std.mem.Allocator, t: *const api.Train, opts: api.Options, c: Cfg) !Model {
    var m: Model = .{ .c = c };
    errdefer deinit(&m, gpa);
    const big_d = termCount(c);

    // Blue won, per game, from any row with a win label
    const won = try gpa.alloc(f32, t.games.len);
    defer gpa.free(won);
    @memset(won, std.math.nan(f32));
    for (t.rows) |r| {
        const y = r.y[api.outcomeIndex(.win)];
        if (!std.math.isNan(y)) won[r.game] = if (r.side == 0) y else 1 - y;
    }

    var next_id: u16 = 1;
    var id_role: std.ArrayList(u8) = .empty;
    defer id_role.deinit(gpa);
    try id_role.append(gpa, 0);
    var games: std.ArrayList(Game) = .empty;
    defer games.deinit(gpa);
    var starts: std.ArrayList(i64) = .empty;
    defer starts.deinit(gpa);
    var per_platform: [n_platform]u32 = @splat(0);
    for (t.games, won, 0..) |*g, y, gi| {
        if (std.math.isNan(y)) continue;
        for (0..n_role) |r| for (0..2) |side| {
            const e = try m.ids.getOrPut(gpa, key(g.teams[side][r], r));
            if (!e.found_existing) {
                e.value_ptr.* = next_id;
                next_id += 1;
                try id_role.append(gpa, @intCast(r));
            }
        };
        var out: Game = .{ .ids = undefined, .platform = g.platform, .y = y, .x = &.{}, .src = @intCast(gi) };
        for (0..2) |side| for (0..n_role) |r| {
            out.ids[side][r] = idOf(&m, g.teams[side][r], r);
        };
        try games.append(gpa, out);
        try starts.append(gpa, g.start);
        per_platform[g.platform] += 1;
    }
    m.n_ids = next_id;
    m.games = @intCast(games.items.len);
    m.main_platform = @intCast(std.mem.indexOfMax(u32, &per_platform));
    m.id_role = try gpa.dupe(u8, id_role.items);
    m.id_games = try gpa.alloc(u32, next_id);
    @memset(m.id_games, 0);
    for (games.items) |g| for (g.ids) |team| for (team) |id| {
        m.id_games[id] += 1;
    };

    // Validation: the newest share of games by start
    const sorted = try gpa.dupe(i64, starts.items);
    defer gpa.free(sorted);
    std.mem.sort(i64, sorted, {}, std.sort.asc(i64));
    const cut = sorted[@intFromFloat(@as(f64, @floatFromInt(sorted.len)) * (1 - val_share))];

    if (hasEmb(c)) try loadEmb(gpa, &m, t, opts);
    const xs = try gpa.alloc(f32, games.items.len * big_d);
    defer gpa.free(xs);
    for (games.items, 0..) |*g, i| g.x = xs[i * big_d ..][0..big_d];
    // Tuning sees profiles from the fit games only, so a val game's own stats stay out
    if (big_d > 0) try prepareX(gpa, &m, t, cut, games.items, starts.items);
    var fit_set: std.ArrayList(Game) = .empty;
    defer fit_set.deinit(gpa);
    var val_set: std.ArrayList(Game) = .empty;
    defer val_set.deinit(gpa);
    for (games.items, starts.items) |g, s| try (if (s >= cut) &val_set else &fit_set).append(gpa, g);

    var best: struct { l2: f32 = 0, epochs: u32 = 0, loss: f64 = std.math.inf(f64), p: []f32 = &.{} } = .{};
    defer gpa.free(best.p);
    for (l2_grid) |l2| {
        const tr = try train(gpa, next_id, 0, l2, 0, fit_set.items, val_set.items, max_epochs, opts.seed, null, 0, 0, 0);
        if (tr.val_loss < best.loss) {
            gpa.free(best.p);
            best = .{ .l2 = l2, .epochs = tr.epochs, .loss = tr.val_loss, .p = tr.p };
        } else gpa.free(tr.p);
    }
    std.debug.print("win-embx: ratings l2 {d} epochs {d} val {d:.5} on {d} games\n", .{ best.l2, best.epochs, best.loss, games.items.len });
    m.l2 = best.l2;

    const frozen: usize = if (c.freeze) Params.b + next_id else 0;
    const base_d = baseCount(c);
    var comp: struct { l2: f32 = 0, l2e: f32 = 0, epochs: u32 = 0, loss: f64, d: usize = 0 } = .{ .loss = best.loss };
    if (base_d > 0) for (comp_l2_grid) |l2w| {
        const tr = try train(gpa, next_id, base_d, best.l2, l2w, fit_set.items, val_set.items, max_epochs, opts.seed, best.p, frozen, base_d, 0);
        defer gpa.free(tr.p);
        std.debug.print("win-embx: comp l2 {d} epochs {d} val {d:.5}\n", .{ l2w, tr.epochs, tr.val_loss });
        if (tr.val_loss < comp.loss) comp = .{ .l2 = l2w, .epochs = tr.epochs, .loss = tr.val_loss, .d = base_d };
    };
    const base_loss = comp.loss;
    if (big_d > base_d) for (emb_l2_grid) |l2e| {
        const tr = try train(gpa, next_id, big_d, best.l2, comp.l2, fit_set.items, val_set.items, max_epochs, opts.seed, best.p, frozen, base_d, l2e);
        defer gpa.free(tr.p);
        std.debug.print("win-embx: emb l2 {d} epochs {d} val {d:.5}\n", .{ l2e, tr.epochs, tr.val_loss });
        if (tr.val_loss < comp.loss) comp = .{ .l2 = comp.l2, .l2e = l2e, .epochs = tr.epochs, .loss = tr.val_loss, .d = big_d };
    };
    if (big_d > base_d and comp.d < big_d) std.debug.print("win-embx: no emb L2 beats the step without on val\n", .{});

    // A tenth more games: a tenth more epochs
    const refit = try train(gpa, next_id, 0, best.l2, 0, games.items, null, @max(1, best.epochs + best.epochs / 10), opts.seed, null, 0, 0, 0);
    if (big_d > 0) {
        try prepareX(gpa, &m, t, std.math.maxInt(i64), games.items, starts.items);
        printCorrelations(&m);
    }
    if (comp.epochs == 0) {
        m.p = refit.p;
        if (big_d > 0) std.debug.print("win-embx: no comp L2 beats ratings on val: plain ratings\n", .{});
        return m;
    }
    defer gpa.free(refit.p);
    const full = try train(gpa, next_id, comp.d, best.l2, comp.l2, games.items, null, @max(1, comp.epochs + comp.epochs / 10), opts.seed, refit.p, frozen, base_d, comp.l2e);
    m.p = full.p;
    m.d = comp.d;
    std.debug.print("win-embx: comp l2 {d} emb l2 {d} epochs {d} val {d:.5} ({d:.5} vs ratings, {d:.5} vs base)\n", .{ comp.l2, comp.l2e, comp.epochs, comp.loss, comp.loss - best.loss, comp.loss - base_loss });

    // Laplace, diagonal: the loss's curvature at the fit plus the ridge
    const params: Params = .{ .n_ids = m.n_ids, .d = m.d, .p = m.p };
    var h: [max_d]f64 = @splat(0);
    for (games.items) |*g| {
        const q = sigmoid(params.logit(g));
        for (h[0..m.d], g.x) |*x, v| x.* += q * (1 - q) * v * v;
    }
    for (m.w_sd[0..m.d], h[0..m.d], 0..) |*sd, x, j| {
        const l2w = if (j < base_d) comp.l2 else comp.l2e;
        sd.* = @floatCast(1 / @sqrt(x + @as(f64, @floatFromInt(games.items.len)) * l2w));
    }
    return m;
}

fn blueLogit(m: *const Model, ids: *const [2][n_role]u16, platform: u8) f32 {
    var x: [max_d]f32 = undefined;
    const d = m.d;
    if (d > 0) {
        var slots: [2][n_role]Slot = undefined;
        for (0..2) |side| for (0..n_role) |r| {
            slots[side][r] = slotOf(m, ids[side][r], r);
        };
        compX(m.c, &slots, x[0..d]);
        for (x[0..d], m.x_scale[0..d]) |*v, sc| v.* *= sc;
    }
    const g: Game = .{ .ids = ids.*, .platform = platform, .y = 0, .x = x[0..d] };
    const params: Params = .{ .n_ids = m.n_ids, .d = d, .p = m.p };
    return params.logit(&g);
}

fn idsOf(m: *const Model, teams: *const [2][n_role]u32) [2][n_role]u16 {
    var ids: [2][n_role]u16 = undefined;
    for (0..2) |side| for (0..n_role) |r| {
        ids[side][r] = idOf(m, teams[side][r], r);
    };
    return ids;
}

pub fn predict(m: *const Model, q: *const api.Query) api.Prediction {
    var out = api.no_opinion;
    const blue = blueLogit(m, &idsOf(m, &q.teams), q.platform);
    out[api.outcomeIndex(.win)] = sigmoid(if (q.side == 0) blue else -blue);
    return out;
}

const sanity_blue = [n_role]u32{ 86, 0, 103, 222, 412 }; // Garen, -, Ahri, Jinx, Thresh
const sanity_red = [2][n_role]u32{
    .{ 82, 131, 134, 115, 99 }, // Mordekaiser Diana Syndra Ziggs Lux
    .{ 122, 64, 238, 51, 555 }, // Darius Lee Sin Zed Caitlyn Pyke
};
const sanity_junglers = [_]u32{ 33, 104 }; // Rammus, Graves

/// comp-terms: each comp weight, pp of blue's chance per 1 sd of its feature (at 50%);
/// comp-sanity: Rammus and Graves jungle into a fixed 5 AP vs 5 AD red team; profiles:
/// the three highest and lowest champion-roles per role and feature (200+ games)
pub fn effects(m: *const Model, arena: std.mem.Allocator, target: api.Outcome) ![]const api.Effects {
    if (target != .win) return &.{};
    var tables: std.ArrayList(api.Effects) = .empty;

    if (m.d > 0) {
        const names = try termLabels(m.c, arena);
        const rows = try arena.alloc(api.Effect, m.d);
        for (rows, names, 0..) |*r, nm, j| r.* = .{
            .label = nm,
            .effect = 25 * m.p[Params.b + m.n_ids + j],
            .ci = 25 * 1.96 * m.w_sd[j],
            .n = m.games,
        };
        std.mem.sort(api.Effect, rows, {}, struct {
            fn more(_: void, a: api.Effect, b: api.Effect) bool {
                return @abs(a.effect) > @abs(b.effect);
            }
        }.more);
        try tables.append(arena, .{
            .name = "comp-terms",
            .title = "Comp terms: blue's win chance per 1 sd of the term, at 50%",
            .unit = "win pp",
            .higher = "blue wins more as blue's side of the term grows",
            .rows = rows,
        });
    }

    if (m.fold_rows.len > 0) {
        var rows: std.ArrayList(api.Effect) = .empty;
        for (m.fold_rows, 0..) |fr, s| {
            try rows.append(arena, .{ .label = try std.fmt.allocPrint(arena, "{s} vs ratings", .{fr.step}), .effect = 1000 * fr.vs_ratings[0], .ci = 1000 * fr.vs_ratings[1], .n = fr.games });
            if (s > 1) try rows.append(arena, .{ .label = try std.fmt.allocPrint(arena, "{s} vs mix", .{fr.step}), .effect = 1000 * fr.vs_mix[0], .ci = 1000 * fr.vs_mix[1], .n = fr.games });
            try rows.append(arena, .{ .label = try std.fmt.allocPrint(arena, "{s} vs ratings, lowest seed", .{fr.step}), .effect = 1000 * fr.seed_lo, .ci = 0, .n = fr.games });
            try rows.append(arena, .{ .label = try std.fmt.allocPrint(arena, "{s} vs ratings, highest seed", .{fr.step}), .effect = 1000 * fr.seed_hi, .ci = 0, .n = fr.games });
        }
        try tables.append(arena, .{
            .name = "folds",
            .title = "Nested ablation on forward-chaining folds of the visible games",
            .unit = "milli-nats/game",
            .higher = "worse log loss than the reference",
            .rows = rows.items,
        });
    }

    var sanity: std.ArrayList(api.Effect) = .empty;
    var diff: [sanity_junglers.len]f64 = undefined;
    for (sanity_junglers, &diff) |jg, *dd| {
        var teams: [2][n_role]u32 = .{ sanity_blue, undefined };
        teams[0][1] = jg;
        var pp: [2]f64 = undefined;
        for (sanity_red, &pp, [_][]const u8{ "AP", "AD" }) |red, *x, kind| {
            teams[1] = red;
            x.* = 100 * sigmoid(blueLogit(m, &idsOf(m, &teams), m.main_platform));
            try sanity.append(arena, .{ .label = try std.fmt.allocPrint(arena, "#{d} jungle into 5 {s}", .{ jg, kind }), .effect = x.*, .ci = 0, .n = m.id_games[idOf(m, jg, 1)] });
        }
        dd.* = pp[0] - pp[1];
        try sanity.append(arena, .{ .label = try std.fmt.allocPrint(arena, "#{d}: 5 AP minus 5 AD", .{jg}), .effect = dd.*, .ci = 0, .n = 0 });
    }
    try sanity.append(arena, .{ .label = "#33 minus #104: AP minus AD", .effect = diff[0] - diff[1], .ci = 0, .n = 0 });
    try tables.append(arena, .{
        .name = "comp-sanity",
        .title = "Blue's win chance with Garen, Ahri, Jinx, Thresh and this jungler",
        .unit = "win pp",
        .higher = "blue wins more",
        .rows = sanity.items,
    });

    if (m.z.len > 0) {
        const role_names = [_][]const u8{ "top", "jungle", "middle", "bottom", "utility" };
        const k = m.c.features.len;
        var prof: std.ArrayList(api.Effect) = .empty;
        var ranked: std.ArrayList(u16) = .empty;
        for (0..n_role) |role| for (m.c.features, 0..) |f, j| {
            ranked.clearRetainingCapacity();
            for (1..m.n_ids) |id| if (m.id_role[id] == role and m.id_games[id] >= 200) try ranked.append(arena, @intCast(id));
            const Ctx = struct { m: *const Model, j: usize, k: usize };
            std.mem.sort(u16, ranked.items, Ctx{ .m = m, .j = j, .k = k }, struct {
                fn more(cx: Ctx, a: u16, b: u16) bool {
                    return cx.m.z[a * cx.k + cx.j] > cx.m.z[b * cx.k + cx.j];
                }
            }.more);
            const n = ranked.items.len;
            for (ranked.items, 0..) |id, i| {
                if (i >= 3 and i + 3 < n) continue;
                var it = m.ids.iterator();
                const champ = while (it.next()) |e| {
                    if (e.value_ptr.* == id) break e.key_ptr.* >> 3;
                } else 0;
                try prof.append(arena, .{
                    .label = try std.fmt.allocPrint(arena, "{s} {s} #{d} ({d:.3})", .{ role_names[role], labels[@backingInt(f)], champ, m.raw[@as(usize, id) * n_raw + @backingInt(f)] }),
                    .effect = m.z[@as(usize, id) * k + j],
                    .ci = 0,
                    .n = m.id_games[id],
                });
            }
        };
        try tables.append(arena, .{
            .name = "profiles",
            .title = "Champion-role profiles: highest and lowest three per role and feature",
            .unit = "sd",
            .higher = "more of the feature than the role's average (raw value in brackets)",
            .rows = prof.items,
        });
    }
    return tables.items;
}

pub fn deinit(m: *Model, gpa: std.mem.Allocator) void {
    gpa.free(m.emb);
    gpa.free(m.fold_rows);
    gpa.free(m.acc);
    gpa.free(m.z);
    gpa.free(m.raw);
    gpa.free(m.id_role);
    gpa.free(m.id_games);
    gpa.free(m.p);
    m.ids.deinit(gpa);
}

/// Synthetic games: 8 champions per role with a latent armour lean and magic share; blue's
/// logit = `effect` x (blue armour sum x red magic sum - red armour sum x blue magic sum)
/// on the latents' z-scores, plus `build` when blue won added to building damage
const per_role = 8;
const Latents = struct { lean: [n_role][per_role]f32, magic: [n_role][per_role]f32 };

fn latents(rnd: std.Random) Latents {
    var l: Latents = undefined;
    for (&l.lean, &l.magic) |*a, *b| for (a, b) |*x, *y| {
        x.* = rnd.floatNorm(f32);
        y.* = rnd.floatNorm(f32);
    };
    return l;
}

fn synth(arena: std.mem.Allocator, n_games: usize, effect: f32, seed: u64) !api.Train {
    var rng: std.Random.DefaultPrng = .init(seed);
    const rnd = rng.random();
    const lat = latents(rnd);
    const lean = lat.lean;
    const magic = lat.magic;
    const games = try arena.alloc(api.Game, n_games);
    const rows = try arena.alloc(api.Row, n_games * 10);
    for (games, 0..) |*g, gi| {
        var pick: [2][n_role]usize = undefined;
        var arm: [2]f32 = @splat(0);
        var mag: [2]f32 = @splat(0);
        for (0..2) |side| for (0..n_role) |r| {
            pick[side][r] = rnd.uintLessThan(usize, per_role);
            arm[side] += lean[r][pick[side][r]];
            mag[side] += magic[r][pick[side][r]];
        };
        const logit = effect * (arm[0] * mag[1] - arm[1] * mag[0]);
        const blue_won: f32 = if (rnd.float(f32) < sigmoid(logit)) 1 else 0;
        g.* = .{
            .start = @intCast(gi * 1000),
            .patch = 1,
            .platform = 6,
            .teams = undefined,
            .ranks = @splat(@splat(null)),
            .exp = @splat(@splat(.{})),
        };
        for (0..2) |side| for (0..n_role) |r| {
            const ch = pick[side][r];
            g.teams[side][r] = @intCast(r * 100 + ch + 1);
            const won = if (side == 0) blue_won else 1 - blue_won;
            var st: [api.seat_stat_count]f32 = @splat(std.math.nan(f32));
            const noise = struct {
                fn n(rr: std.Random, x: f32) f32 {
                    return x * (1 + 0.2 * rr.floatNorm(f32));
                }
            }.n;
            const share = std.math.clamp(0.5 + 0.15 * magic[r][ch] + 0.05 * rnd.floatNorm(f32), 0.01, 0.99);
            st[@backingInt(api.SeatStat.minutes)] = 30;
            st[@backingInt(api.SeatStat.dmg_magic)] = 20000 * share;
            st[@backingInt(api.SeatStat.dmg_phys)] = 20000 * (1 - share);
            st[@backingInt(api.SeatStat.dmg_true)] = noise(rnd, 1000);
            st[@backingInt(api.SeatStat.armor_end)] = 80 + 20 * lean[r][ch] + 5 * rnd.floatNorm(f32);
            st[@backingInt(api.SeatStat.mr_end)] = 60;
            st[@backingInt(api.SeatStat.dmg_buildings)] = noise(rnd, 3000) + 4000 * won;
            rows[gi * 10 + side * 5 + r] = .{
                .game = @intCast(gi),
                .side = @intCast(side),
                .role = @fromBackingInt(@intCast(r)),
                .champion = g.teams[side][r],
                .rank = null,
                .exp = .{},
                .y = .{ won, std.math.nan(f32), std.math.nan(f32), std.math.nan(f32), std.math.nan(f32), std.math.nan(f32) },
                .stats = st,
            };
        };
    }
    return .{ .games = games, .rows = rows };
}

fn holdoutLoss(m: *const Model, t: *const api.Train) f64 {
    var s: f64 = 0;
    for (t.games, 0..) |g, gi| {
        const y = t.rows[gi * 10].y[0];
        const q: api.Query = .{ .start = g.start, .patch = g.patch, .platform = g.platform, .side = 0, .role = .top, .champion = g.teams[0][0], .rank = null, .teams = g.teams, .ranks = null, .exp = .{}, .exps = null };
        const p: f64 = predict(m, &q)[0];
        s -= y * @log(p) + (1 - y) * @log(1 - p);
    }
    return s / @as(f64, @floatFromInt(t.games.len));
}

fn findTerm(m: *const Model, arena: std.mem.Allocator, label: []const u8) ?usize {
    const names = termLabels(m.c, arena) catch return null;
    for (names[0..m.d], 0..) |nm, j| if (std.mem.eql(u8, nm, label)) return j;
    return null;
}

test "cross recovers a planted armour x enemy magic effect and beats ratings" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const gpa = std.testing.allocator;
    const tr = try synth(arena, 6000, 0.15, 1);
    const ho = try synth(arena, 3000, 0.15, 2);
    // Same latents: synth draws them first from its seed, so reuse the training champions
    const ho_same = try synth(arena, 3000, 0.15, 1);
    _ = ho;
    const features = [_]Feature{ .magic, .armour, .buildings };
    var plain = try fitWith(gpa, &tr, .{}, .{ .features = &features });
    defer deinit(&plain, gpa);
    var comp = try fitWith(gpa, &tr, .{}, .{ .features = &features, .cross = true });
    defer deinit(&comp, gpa);
    try std.testing.expectEqual(@as(usize, 0), plain.d);
    try std.testing.expectEqual(@as(usize, 3), comp.d);
    const j = findTerm(&comp, arena, "cross magic share x enemy armour minus MR").?;
    const w = comp.p[Params.b + comp.n_ids + j];
    // blue armour x red magic is +; this term is blue magic x red armour minus the reverse
    try std.testing.expect(w < -2 * comp.w_sd[j]);
    try std.testing.expect(holdoutLoss(&comp, &ho_same) < holdoutLoss(&plain, &ho_same) - 0.002);
}

test "profiles balance wins and losses, z within role, unknown champion is the role mean" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const gpa = std.testing.allocator;
    const tr = try synth(arena, 3000, 0.4, 3);
    var m = try fitWith(gpa, &tr, .{}, .{ .features = &.{ .magic, .buildings }, .balance = true });
    defer deinit(&m, gpa);
    // Building damage depends only on winning: balanced profiles barely spread
    var spread: [2]f32 = @splat(0);
    for (1..m.n_ids) |id| for (0..2) |j| {
        spread[j] = @max(spread[j], @abs(m.raw[id * n_raw + @backingInt(m.c.features[j])] - m.role_mean[m.id_role[id]][@backingInt(m.c.features[j])]));
    };
    try std.testing.expect(spread[0] > 0.05);
    try std.testing.expect(spread[1] < 0.03 * m.role_mean[0][@backingInt(Feature.buildings)]);
    for (0..n_role) |role| {
        var s: f64 = 0;
        var n: f64 = 0;
        for (1..m.n_ids) |id| if (m.id_role[id] == role) {
            s += @as(f64, m.id_games[id]) * m.z[id * 2];
            n += @floatFromInt(m.id_games[id]);
        };
        try std.testing.expect(@abs(s / n) < 1e-4);
    }
    var teams = tr.games[0].teams;
    teams[1][2] = 999_999;
    const q: api.Query = .{ .start = 0, .patch = 1, .platform = 6, .side = 0, .role = .top, .champion = teams[0][0], .rank = null, .teams = teams, .ranks = null, .exp = .{}, .exps = null };
    const p = predict(&m, &q)[0];
    try std.testing.expect(p > 0 and p < 1);
    try std.testing.expectEqual(@as(u16, 0), idOf(&m, 999_999, 2));
    for (m.zOf(0)) |z| try std.testing.expectEqual(@as(f32, 0), z);
}

test "folds: the planted cross term shows against ratings" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const gpa = std.testing.allocator;
    const tr = try synth(arena, 6000, 0.15, 5);
    var rng: std.Random.DefaultPrng = .init(5);
    const src: TestEmb = .{ .lat = latents(rng.random()) };
    const source = src.source();
    var c = base_cfg;
    c.folds = 2;
    const rows = try foldAblation(gpa, &tr, .{ .embeddings = &source }, c);
    defer gpa.free(rows);
    try std.testing.expectEqual(std.enums.values(Variant).len, rows.len);
    try std.testing.expectEqual(@as(u32, 3000), rows[1].games);
    try std.testing.expectEqual(@as(f64, 0), rows[0].vs_ratings[0]);
    const all = rows[@backingInt(Variant.all)];
    try std.testing.expect(all.vs_mix[0] + all.vs_mix[1] < 0);
    try std.testing.expect(all.seed_hi < 0);
    const shuffled = rows[@backingInt(Variant.shuffled)];
    try std.testing.expect(all.loss < shuffled.loss);
}

test "a needs_embeddings fit without embeddings fails" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const tr = try synth(arena_state.allocator(), 200, 0, 1);
    try std.testing.expectError(error.NoEmbeddings, fitWith(std.testing.allocator, &tr, .{}, variantCfg(.all)));
}

/// E = (armour lean, magic share, 0...) of synth's latents: all_cross can find its effect
const TestEmb = struct {
    lat: Latents,

    fn source(t: *const TestEmb) api.EmbeddingSource {
        return .{ .ctx = t, .forFitFn = forFit };
    }

    fn forFit(ctx: *const anyopaque, gpa: std.mem.Allocator, _: *const api.Train, _: u64) anyerror!api.Embeddings {
        const t: *const TestEmb = @ptrCast(@alignCast(ctx));
        const rows = try gpa.alloc(api.EmbeddingRow, n_role * (per_role + 1));
        var at: usize = 0;
        for (0..n_role) |r| for (0..per_role + 1) |ch| {
            const e = try gpa.alloc(f32, emb_dim);
            @memset(e, 0);
            if (ch < per_role) {
                e[0] = t.lat.lean[r][ch];
                e[1] = t.lat.magic[r][ch];
            }
            const champion: u32 = if (ch < per_role) @intCast(r * 100 + ch + 1) else 0;
            rows[at] = .{ .champion = champion, .role = @fromBackingInt(@intCast(r)), .games = 0, .e = e };
            at += 1;
        };
        return .{ .dim = emb_dim, .rows = rows };
    }
};

test "predict is symmetric between the sides" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const gpa = std.testing.allocator;
    const tr = try synth(arena, 2000, 0.3, 4);
    var m = try fitWith(gpa, &tr, .{}, .{ .features = &.{ .magic, .armour }, .prior = true, .balance = true, .cross = true, .team = true });
    defer deinit(&m, gpa);
    const g = tr.games[5];
    var q: api.Query = .{ .start = 0, .patch = 1, .platform = 6, .side = 0, .role = .top, .champion = g.teams[0][0], .rank = null, .teams = g.teams, .ranks = null, .exp = .{}, .exps = null };
    const blue = predict(&m, &q)[0];
    q.side = 1;
    try std.testing.expectApproxEqAbs(blue, 1 - predict(&m, &q)[0], 1e-6);
    const tables = try effects(&m, arena, .win);
    try std.testing.expect(tables.len >= 2);
}
