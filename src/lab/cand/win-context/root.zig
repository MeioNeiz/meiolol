//! Win from the draft with context (meiolol-48, NN programme): win-ratings' joint
//! ratings (blue-side intercept per platform + champion-role ratings, blue minus red)
//! plus shrunk offsets on a stationary rating (research C14):
//!   patch:   rating(c, patch) = r_c + o[c][patch], o shrunk to 0 (to the champion's
//!            rating) by its own L2; a patch unseen in training gets no offset
//!   bracket: rating(c, bracket) = r_c + o[c][bracket], the bracket from the lobby's
//!            median rank_start (ten players, needs min_known of them) in training and
//!            the fold ablation; at a champ-select query only the user's own rank is
//!            known, so predict uses it as the bracket (matchmaking puts the lobby near it)
//! Ranks are rank_start only (rows.zig fillRankStart, the day before the game); never
//! rank_after. L2 picked on the newest 10% of fit games: ratings' first, then the
//! offsets' multiple of it with ratings' L2 fixed. cfg.folds: win-comp's forward-chaining
//! folds (the newest half of the visible games in time blocks, each scored by every step
//! fitted on all older games), the nested chain ratings, +patch, +bracket

const std = @import("std");
const api = @import("api");

const Cfg = struct {
    patch: bool = false,
    bracket: bool = false,
    /// Control: each game's patch slot drawn from a hash of its start, not its patch; the
    /// offsets' gain must vanish. foldAblation adds it as a last step after +patch
    shuffle: bool = false,
    folds: u8 = 0,
};

const cfg: Cfg = .{ .patch = true, .folds = 5 };

pub const name = "win-context";

pub const scope: api.Scope = .champ_select;

const n_role = 5;
const n_platform = 256;
const max_patch = 32;
const n_bracket = 5;
const none: u8 = 255;
/// Known ranks a lobby needs for a bracket
const min_known = 3;
const val_share = 0.1;
const batch = 2048;
const lr = 0.003;
const max_epochs = 60;
const patience = 5;

const l2_grid = [_]f32{ 3e-4, 1e-3, 3e-3, 1e-2 };
/// Offsets' L2 as a multiple of the ratings'
const mult_grid = [_]f32{ 1, 3, 10, 30, 100 };

/// rank 0 Iron IV .. 39 Challenger I, 4 per tier: Iron-Silver, Gold, Platinum, Emerald,
/// Diamond and up
fn bracketOf(rank: u8) u8 {
    const tier = rank / 4;
    return if (tier <= 2) 0 else @min(tier - 2, n_bracket - 1);
}

const bracket_names = [n_bracket][]const u8{ "iron-silver", "gold", "platinum", "emerald", "diamond+" };

const Game = struct {
    ids: [2][n_role]u16,
    platform: u8,
    patch: u8,
    bracket: u8,
    y: f32,
};

const Space = struct {
    n_ids: usize,
    c: usize,
    b: usize,
    /// o_patch[id * max_patch + patch]
    op: usize,
    /// o_bracket[id * n_bracket + bracket]
    ob: usize,
    len: usize,

    fn init(n_ids: usize, c: Cfg) Space {
        var sp: Space = .{ .n_ids = n_ids, .c = 0, .b = n_platform, .op = 0, .ob = 0, .len = 0 };
        sp.op = sp.b + n_ids;
        sp.ob = sp.op + if (c.patch) n_ids * max_patch else 0;
        sp.len = sp.ob + if (c.bracket) n_ids * n_bracket else 0;
        return sp;
    }
};

const Params = struct {
    sp: Space,
    c: Cfg,
    p: []f32,

    fn rating(m: Params, id: u16, g: *const Game) f32 {
        const i: usize = id;
        var s = m.p[m.sp.b + i];
        if (m.c.patch and g.patch != none) s += m.p[m.sp.op + i * max_patch + g.patch];
        if (m.c.bracket and g.bracket != none) s += m.p[m.sp.ob + i * n_bracket + g.bracket];
        return s;
    }

    fn logit(m: Params, g: *const Game) f32 {
        var s = m.p[m.sp.c + g.platform];
        for (0..n_role) |r| s += m.rating(g.ids[0][r], g) - m.rating(g.ids[1][r], g);
        return s;
    }

    fn grad(m: Params, g: *const Game, r: f32, gr: []f32) void {
        gr[m.sp.c + g.platform] += r;
        for (0..2) |side| {
            const rs = if (side == 0) r else -r;
            for (g.ids[side]) |id| {
                const i: usize = id;
                gr[m.sp.b + i] += rs;
                if (m.c.patch and g.patch != none) gr[m.sp.op + i * max_patch + g.patch] += rs;
                if (m.c.bracket and g.bracket != none) gr[m.sp.ob + i * n_bracket + g.bracket] += rs;
            }
        }
    }
};

fn sigmoid(x: f32) f32 {
    return 1 / (1 + @exp(-x));
}

fn gameLoss(m: Params, g: *const Game) f64 {
    const q = std.math.clamp(sigmoid(m.logit(g)), 1e-6, 1 - 1e-6);
    return -(g.y * @log(q) + (1 - g.y) * @log(1 - q));
}

fn logLoss(m: Params, set: []const Game) f64 {
    var s: f64 = 0;
    for (set) |*g| s += gameLoss(m, g);
    return s / @as(f64, @floatFromInt(@max(set.len, 1)));
}

const Trained = struct { p: []f32, epochs: u32, val_loss: f64 };

/// Adam on minibatches; with val, stops on it and keeps the best epoch's parameters
fn train(gpa: std.mem.Allocator, sp: Space, c: Cfg, l2: f32, mult: f32, set: []const Game, val: ?[]const Game, epochs_cap: u32, seed: u64) !Trained {
    const p = try gpa.alloc(f32, sp.len);
    errdefer gpa.free(p);
    @memset(p, 0);
    const m: Params = .{ .sp = sp, .c = c, .p = p };
    var rng: std.Random.DefaultPrng = .init(seed);
    const rnd = rng.random();

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
            for (part) |i| m.grad(&set[i], sigmoid(m.logit(&set[i])) - set[i].y, gr);
            const scale = 1 / @as(f32, @floatFromInt(part.len));
            step += 1;
            const c1 = 1 - std.math.pow(f32, b1, @floatFromInt(step));
            const c2 = 1 - std.math.pow(f32, b2, @floatFromInt(step));
            for (p, gr, m1, m2, 0..) |*x, g0, *s1, *s2, i| {
                const reg: f32 = if (i < sp.b) 0 else if (i < sp.op) l2 else l2 * mult;
                const g = g0 * scale + reg * x.*;
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

const FoldRow = struct {
    step: []const u8,
    games: u32,
    loss: f64,
    /// Paired per-game log loss difference: mean, 95% half-width
    vs_ratings: [2]f64,
    vs_prev: [2]f64,
};

pub const Model = struct {
    c: Cfg,
    sp: Space = undefined,
    p: []f32 = &.{},
    ids: std.AutoHashMapUnmanaged(u64, u16) = .empty,
    /// Patch number to its offset slot
    patches: std.AutoHashMapUnmanaged(u32, u8) = .empty,
    patch_list: [max_patch]u32 = @splat(0),
    n_patch: u8 = 0,
    id_games: []u32 = &.{},
    l2: f32 = 0,
    mult: f32 = 0,
    fold_rows: []FoldRow = &.{},
    /// Coverage: games by count of known ranks (0..10), and by bracket
    known: [11]u32 = @splat(0),
    by_bracket: [n_bracket]u32 = @splat(0),
};

fn key(champion: u32, role: usize) u64 {
    return (@as(u64, champion) << 3) | role;
}

fn idOf(m: *const Model, champion: u32, role: usize) u16 {
    return m.ids.get(key(champion, role)) orelse 0;
}

/// The lobby's median rank_start bracket, none under min_known known ranks
fn lobbyBracket(ranks: [2][5]?u8) struct { bracket: u8, known: u8 } {
    var buf: [10]u8 = undefined;
    var n: u8 = 0;
    for (ranks) |team| for (team) |r| if (r) |x| {
        buf[n] = x;
        n += 1;
    };
    if (n < min_known) return .{ .bracket = none, .known = n };
    std.mem.sort(u8, buf[0..n], {}, std.sort.asc(u8));
    const med = (@as(u16, buf[(n - 1) / 2]) + buf[n / 2]) / 2;
    return .{ .bracket = bracketOf(@intCast(med)), .known = n };
}

fn gameOf(m: *const Model, g: *const api.Game, bracket: u8, y: f32) Game {
    const patch = if (m.c.shuffle and m.n_patch > 0)
        @as(u8, @intCast(std.hash.int(@as(u64, @bitCast(g.start))) % m.n_patch))
    else
        m.patches.get(g.patch) orelse none;
    var out: Game = .{ .ids = undefined, .platform = g.platform, .patch = patch, .bracket = bracket, .y = y };
    for (0..2) |side| for (0..n_role) |r| {
        out.ids[side][r] = idOf(m, g.teams[side][r], r);
    };
    return out;
}

fn wonOf(gpa: std.mem.Allocator, t: *const api.Train) ![]f32 {
    const won = try gpa.alloc(f32, t.games.len);
    @memset(won, std.math.nan(f32));
    for (t.rows) |r| {
        const y = r.y[api.outcomeIndex(.win)];
        if (!std.math.isNan(y)) won[r.game] = if (r.side == 0) y else 1 - y;
    }
    return won;
}

pub fn fit(gpa: std.mem.Allocator, t: *const api.Train, opts: api.Options) !Model {
    var m = try fitWith(gpa, t, opts, cfg);
    errdefer deinit(&m, gpa);
    printCoverage(&m, t);
    if (cfg.folds > 0) m.fold_rows = try foldAblation(gpa, t, opts, cfg);
    return m;
}

fn printCoverage(m: *const Model, t: *const api.Train) void {
    var games: u32 = 0;
    for (m.known) |k| games += k;
    std.debug.print("win-context: {d} games by known rank_start count 0..10: {any}\n", .{ games, m.known });
    std.debug.print("win-context: lobby brackets ({d}+ known; iron-silver, gold, platinum, emerald, diamond+) {any}\n", .{ min_known, m.by_bracket });
    std.debug.print("win-context: patches {any}\n", .{m.patch_list[0..m.n_patch]});
    var rows_ranked: u64 = 0;
    for (t.rows) |r| rows_ranked += @intFromBool(r.rank != null);
    std.debug.print("win-context: rows with rank_start {d} of {d}\n", .{ rows_ranked, t.rows.len });
}

fn fitWith(gpa: std.mem.Allocator, t: *const api.Train, opts: api.Options, c: Cfg) !Model {
    var m: Model = .{ .c = c };
    errdefer deinit(&m, gpa);
    const won = try wonOf(gpa, t);
    defer gpa.free(won);

    // Patch slots: the newest max_patch patches by number
    var seen: std.AutoArrayHashMapUnmanaged(u32, void) = .empty;
    defer seen.deinit(gpa);
    for (t.games) |g| try seen.put(gpa, g.patch, {});
    const plist = try gpa.dupe(u32, seen.keys());
    defer gpa.free(plist);
    std.mem.sort(u32, plist, {}, std.sort.asc(u32));
    const from = plist.len -| max_patch;
    for (plist[from..], 0..) |pt, i| {
        try m.patches.put(gpa, pt, @intCast(i));
        m.patch_list[i] = pt;
    }
    m.n_patch = @intCast(plist.len - from);

    var next_id: u16 = 1;
    var games: std.ArrayList(Game) = .empty;
    defer games.deinit(gpa);
    var starts: std.ArrayList(i64) = .empty;
    defer starts.deinit(gpa);
    for (t.games, won) |*g, y| {
        if (std.math.isNan(y)) continue;
        for (0..n_role) |r| for (0..2) |side| {
            const e = try m.ids.getOrPut(gpa, key(g.teams[side][r], r));
            if (!e.found_existing) {
                e.value_ptr.* = next_id;
                next_id += 1;
            }
        };
        const lb = lobbyBracket(g.ranks);
        m.known[lb.known] += 1;
        if (lb.bracket != none) m.by_bracket[lb.bracket] += 1;
        try games.append(gpa, gameOf(&m, g, lb.bracket, y));
        try starts.append(gpa, g.start);
    }
    m.id_games = try gpa.alloc(u32, next_id);
    @memset(m.id_games, 0);
    for (games.items) |g| for (g.ids) |team| for (team) |id| {
        m.id_games[id] += 1;
    };

    const sorted = try gpa.dupe(i64, starts.items);
    defer gpa.free(sorted);
    std.mem.sort(i64, sorted, {}, std.sort.asc(i64));
    const cut = sorted[@intFromFloat(@as(f64, @floatFromInt(sorted.len)) * (1 - val_share))];
    var fit_set: std.ArrayList(Game) = .empty;
    defer fit_set.deinit(gpa);
    var val_set: std.ArrayList(Game) = .empty;
    defer val_set.deinit(gpa);
    for (games.items, starts.items) |g, s| try (if (s >= cut) &val_set else &fit_set).append(gpa, g);

    const base: Cfg = .{ .shuffle = c.shuffle };
    var best: struct { l2: f32 = 0, mult: f32 = 0, epochs: u32 = 0, loss: f64 = std.math.inf(f64) } = .{};
    for (l2_grid) |l2| {
        const tr = try train(gpa, .init(next_id, base), base, l2, 1, fit_set.items, val_set.items, max_epochs, opts.seed);
        defer gpa.free(tr.p);
        if (tr.val_loss < best.loss) best = .{ .l2 = l2, .epochs = tr.epochs, .loss = tr.val_loss };
    }
    const ratings_val = best.loss;
    const ratings_epochs = best.epochs;
    m.sp = .init(next_id, c);
    if (c.patch or c.bracket) {
        best.loss = std.math.inf(f64);
        for (mult_grid) |mult| {
            const tr = try train(gpa, m.sp, c, best.l2, mult, fit_set.items, val_set.items, max_epochs, opts.seed);
            defer gpa.free(tr.p);
            std.debug.print("win-context: patch {} bracket {} l2 {d} mult {d} val {d:.5} (ratings {d:.5})\n", .{ c.patch, c.bracket, best.l2, mult, tr.val_loss, ratings_val });
            if (tr.val_loss < best.loss) best = .{ .l2 = best.l2, .mult = mult, .epochs = tr.epochs, .loss = tr.val_loss };
        }
        // No multiple beats ratings on validation: no offsets, as win-comp's terms
        if (best.loss >= ratings_val) {
            m.c = .{ .shuffle = c.shuffle };
            m.sp = .init(next_id, m.c);
            best = .{ .l2 = best.l2, .epochs = ratings_epochs, .loss = ratings_val };
        }
    }
    m.l2 = best.l2;
    m.mult = best.mult;
    const refit = try train(gpa, m.sp, m.c, best.l2, best.mult, games.items, null, @max(1, best.epochs + best.epochs / 10), opts.seed);
    m.p = refit.p;
    std.debug.print("win-context: patch {} bracket {} l2 {d} mult {d} epochs {d} val {d:.5} on {d} games\n", .{ m.c.patch, m.c.bracket, best.l2, best.mult, best.epochs, best.loss, games.items.len });
    return m;
}

fn chain(c: Cfg, out: *[4]Cfg, names: *[4][]const u8) usize {
    out[0] = .{};
    names[0] = "ratings";
    var n: usize = 1;
    inline for (.{ "patch", "bracket" }) |flag| if (@field(c, flag)) {
        out[n] = out[n - 1];
        @field(out[n], flag) = true;
        names[n] = "+" ++ flag;
        n += 1;
    };
    if (c.patch) {
        out[n] = .{ .patch = true, .shuffle = true };
        names[n] = "shuffled patch (control)";
        n += 1;
    }
    return n;
}

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

/// win-comp's foldAblation blocks. Scored games' brackets from their lobby's rank_start;
/// also each step on the scored games that have a bracket, so the bracket gain is read
/// where it can act
fn foldAblation(gpa: std.mem.Allocator, t: *const api.Train, opts: api.Options, c: Cfg) ![]FoldRow {
    var steps: [4]Cfg = undefined;
    var names: [4][]const u8 = undefined;
    const n_steps = chain(c, &steps, &names);
    var losses: [4]std.ArrayList(f64) = @splat(.empty);
    defer for (&losses) |*l| l.deinit(gpa);
    var has_bracket: std.ArrayList(bool) = .empty;
    defer has_bracket.deinit(gpa);

    const won = try wonOf(gpa, t);
    defer gpa.free(won);
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
        var scored: usize = 0;
        var unseen_patch: usize = 0;
        for (steps[0..n_steps], losses[0..n_steps], 0..) |step, *ls, si| {
            var m = try fitWith(gpa, &sub, opts, step);
            defer deinit(&m, gpa);
            const params: Params = .{ .sp = m.sp, .c = m.c, .p = m.p };
            scored = 0;
            unseen_patch = 0;
            for (t.games, won) |*g, y| {
                if (std.math.isNan(y) or g.start < lo or g.start >= hi) continue;
                const lb = lobbyBracket(g.ranks);
                const tg = gameOf(&m, g, lb.bracket, y);
                try ls.append(gpa, gameLoss(params, &tg));
                if (si == 0) try has_bracket.append(gpa, lb.bracket != none);
                if (tg.patch == none) unseen_patch += 1;
                scored += 1;
            }
        }
        std.debug.print("win-context: fold {d}: fit on {d} games, scored {d} ({d} on a patch unseen in fit), vs ratings:", .{ f + 1, sub_games.items.len, scored, unseen_patch });
        const at = losses[0].items.len - scored;
        for (names[1..n_steps], losses[1..n_steps]) |nm, ls| {
            const d = pairedMean(ls.items[at..], losses[0].items[at..]);
            std.debug.print(" {s} {d:.5} ± {d:.5};", .{ nm, d[0], d[1] });
        }
        std.debug.print("\n", .{});
    }

    const out = try gpa.alloc(FoldRow, n_steps);
    std.debug.print("win-context: folds ({d}), per-game log loss, paired 95%\n| step | games | log loss | vs ratings | vs previous |\n| --- | --- | --- | --- | --- |\n", .{c.folds});
    for (out, 0..) |*o, s| {
        const ls = losses[s].items;
        var sum: f64 = 0;
        for (ls) |x| sum += x;
        o.* = .{
            .step = names[s],
            .games = @intCast(ls.len),
            .loss = sum / @as(f64, @floatFromInt(@max(ls.len, 1))),
            .vs_ratings = pairedMean(ls, losses[0].items),
            .vs_prev = pairedMean(ls, losses[if (s > 0) s - 1 else 0].items),
        };
        std.debug.print("| {s} | {d} | {d:.5} | {d:.5} ± {d:.5} | {d:.5} ± {d:.5} |\n", .{ o.step, o.games, o.loss, o.vs_ratings[0], o.vs_ratings[1], o.vs_prev[0], o.vs_prev[1] });
    }
    if (!c.bracket) return out;
    // The same on games with a bracket only
    var sub_l: [4]std.ArrayList(f64) = @splat(.empty);
    defer for (&sub_l) |*l| l.deinit(gpa);
    for (0..n_steps) |s| for (losses[s].items, has_bracket.items) |x, hb| if (hb) try sub_l[s].append(gpa, x);
    std.debug.print("win-context: folds, games with a lobby bracket only\n", .{});
    for (0..n_steps) |s| {
        const d = pairedMean(sub_l[s].items, sub_l[0].items);
        const dp = pairedMean(sub_l[s].items, sub_l[if (s > 0) s - 1 else 0].items);
        std.debug.print("| {s} | {d} | {d:.5} ± {d:.5} | {d:.5} ± {d:.5} |\n", .{ names[s], sub_l[s].items.len, d[0], d[1], dp[0], dp[1] });
    }
    return out;
}

pub fn predict(m: *const Model, q: *const api.Query) api.Prediction {
    var out = api.no_opinion;
    const g: api.Game = .{ .start = q.start, .patch = q.patch, .platform = q.platform, .teams = q.teams, .ranks = @splat(@splat(null)), .exp = @splat(@splat(.{})) };
    const bracket = if (q.rank) |r| bracketOf(r) else none;
    const tg = gameOf(m, &g, bracket, 0);
    const params: Params = .{ .sp = m.sp, .c = m.c, .p = m.p };
    const blue = params.logit(&tg);
    out[api.outcomeIndex(.win)] = sigmoid(if (q.side == 0) blue else -blue);
    return out;
}

/// The fold ablation, and the largest offsets by patch and bracket (logit units)
pub fn effects(m: *const Model, arena: std.mem.Allocator, target: api.Outcome) ![]const api.Effects {
    if (target != .win) return &.{};
    var tables: std.ArrayList(api.Effects) = .empty;
    if (m.fold_rows.len > 0) {
        var rows: std.ArrayList(api.Effect) = .empty;
        for (m.fold_rows, 0..) |fr, s| {
            try rows.append(arena, .{ .label = try std.fmt.allocPrint(arena, "{s} vs ratings", .{fr.step}), .effect = 1000 * fr.vs_ratings[0], .ci = 1000 * fr.vs_ratings[1], .n = fr.games });
            if (s > 1) try rows.append(arena, .{ .label = try std.fmt.allocPrint(arena, "{s} vs the step before", .{fr.step}), .effect = 1000 * fr.vs_prev[0], .ci = 1000 * fr.vs_prev[1], .n = fr.games });
        }
        try tables.append(arena, .{
            .name = "folds",
            .title = "Nested ablation on forward-chaining folds of the visible games",
            .unit = "milli-nats/game",
            .higher = "worse log loss than the reference",
            .rows = rows.items,
        });
    }
    var offs: std.ArrayList(api.Effect) = .empty;
    var it = m.ids.iterator();
    while (it.next()) |e| {
        const id: usize = e.value_ptr.*;
        if (m.c.patch) for (0..m.n_patch) |pi| {
            const o = m.p[m.sp.op + id * max_patch + pi];
            try offs.append(arena, .{ .label = try std.fmt.allocPrint(arena, "#{d} role {d} patch {d}", .{ e.key_ptr.* >> 3, e.key_ptr.* & 7, m.patch_list[pi] }), .effect = o, .ci = 0, .n = m.id_games[id] });
        };
        if (m.c.bracket) for (0..n_bracket) |bi| {
            const o = m.p[m.sp.ob + id * n_bracket + bi];
            try offs.append(arena, .{ .label = try std.fmt.allocPrint(arena, "#{d} role {d} {s}", .{ e.key_ptr.* >> 3, e.key_ptr.* & 7, bracket_names[bi] }), .effect = o, .ci = 0, .n = m.id_games[id] });
        };
    }
    std.mem.sort(api.Effect, offs.items, {}, struct {
        fn more(_: void, a: api.Effect, b: api.Effect) bool {
            return @abs(a.effect) > @abs(b.effect);
        }
    }.more);
    try tables.append(arena, .{
        .name = "context-offsets",
        .title = "Largest champion-role offsets by patch and lobby bracket",
        .unit = "logit",
        .higher = "stronger in that context than its rating",
        .rows = offs.items[0..@min(offs.items.len, 200)],
    });
    return tables.items;
}

pub fn deinit(m: *Model, gpa: std.mem.Allocator) void {
    gpa.free(m.fold_rows);
    gpa.free(m.id_games);
    gpa.free(m.p);
    m.ids.deinit(gpa);
    m.patches.deinit(gpa);
}

/// n games over two patches (the second half on patch 2); champion 7 top is +shift
/// logit stronger on patch 2 only
fn synth(arena: std.mem.Allocator, n: usize, shift: f32, seed: u64) !api.Train {
    var rng: std.Random.DefaultPrng = .init(seed);
    const rnd = rng.random();
    const games = try arena.alloc(api.Game, n);
    const rows = try arena.alloc(api.Row, n * 10);
    for (games, 0..) |*g, i| {
        const patch: u32 = if (i < n / 2) 1 else 2;
        g.* = .{ .start = @intCast(i * 1000), .patch = patch, .platform = 0, .teams = undefined, .ranks = @splat(@splat(null)), .exp = @splat(@splat(.{})) };
        var s: f32 = 0;
        for (0..2) |side| for (0..n_role) |r| {
            const c: u32 = rnd.uintLessThan(u32, 10);
            g.teams[side][r] = c;
            const sign: f32 = if (side == 0) 1 else -1;
            if (c == 7 and r == 0 and patch == 2) s += sign * shift;
        };
        const y: f32 = if (rnd.float(f32) < sigmoid(s)) 1 else 0;
        for (0..2) |side| for (0..n_role) |r| {
            var row: api.Row = .{ .game = @intCast(i), .side = @intCast(side), .role = @fromBackingInt(@intCast(r)), .champion = g.teams[side][r], .rank = null, .exp = .{}, .y = @splat(std.math.nan(f32)) };
            row.y[api.outcomeIndex(.win)] = if (side == 0) y else 1 - y;
            rows[i * 10 + side * n_role + r] = row;
        };
    }
    return .{ .games = games, .rows = rows };
}

test "folds: a planted patch effect shows against ratings" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const gpa = std.testing.allocator;
    const tr = try synth(arena_state.allocator(), 8000, 1.5, 3);
    const rows = try foldAblation(gpa, &tr, .{}, .{ .patch = true, .folds = 2 });
    defer gpa.free(rows);
    try std.testing.expectEqual(@as(usize, 3), rows.len);
    try std.testing.expectEqual(@as(f64, 0), rows[0].vs_ratings[0]);
    try std.testing.expect(rows[1].vs_ratings[0] + rows[1].vs_ratings[1] < 0);
    // Shuffled patch labels lose the planted effect
    try std.testing.expect(rows[2].vs_ratings[0] - rows[2].vs_ratings[1] > rows[1].vs_ratings[0]);
}

test "lobby bracket: median of known ranks, none under min_known" {
    var ranks: [2][5]?u8 = @splat(@splat(null));
    try std.testing.expectEqual(none, lobbyBracket(ranks).bracket);
    ranks[0][0] = 13;
    ranks[0][1] = 14;
    ranks[1][3] = 30;
    try std.testing.expectEqual(@as(u8, 1), lobbyBracket(ranks).bracket);
    try std.testing.expectEqual(@as(u8, 0), bracketOf(11));
    try std.testing.expectEqual(@as(u8, 4), bracketOf(39));
}
