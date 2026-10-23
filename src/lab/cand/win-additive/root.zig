//! win-additive: additive v2 (docs/model.md "Additive model v2", `meiolol-lab effects
//! --param v2`, its "full" model) as a candidate, so nets can be fitted on top of the best
//! non-net draft model. Blue's logit = platform side + champion strength per role + 10
//! ally role-pair blocks + 15 identified matchup blocks + win-comp's damage mix, each
//! block a random effect with its own variance (MacKay's fixed point), fitted by block
//! Gauss-Seidel Newton steps.
//! A copy, as a candidate imports only std and api: keep in step with src/additive.zig
//! (key, cells, build, fit, predict; logistic only, no weights or warm start) and
//! lab/addinputs.zig (Mix, fullVariant(true, 1))

const std = @import("std");
const api = @import("api");

pub const name = "win-additive";
pub const scope: api.Scope = .champ_select;
pub const needs_stats = true;

const n_role = 5;
const n_platforms = 16;
const n_cont = 4;
const n_ally = 10;
const n_enemy = 25;
const n_groups = 1 + n_role + n_ally + n_enemy;
const g_fixed = 0;
const g_main = 1;
const g_ally = g_main + n_role;
const g_enemy = g_ally + n_ally;
/// Platform side, then cont features
const fixed_params = n_platforms + n_cont;

/// additive.Config defaults
const outer = 40;
const inner = 2;
const final = 6;
const fixed_l2 = 1e-3;
const sigma2_init = 0.01;
const sigma2_floor = 1e-8;

const GameIn = struct {
    teams: [2][n_role]u32,
    platform: u8,
    y: f32,
    /// Blue minus red: [0] the damage mix
    cont: [n_cont]f32 = @splat(0),
};

const Entry = struct { game: u32, param: u32, x: f32 };

/// additive.matchupGroups over the mains: every ally block, enemy blocks r <= q, mix on
fn hasGroup(g: usize) bool {
    if (g < g_enemy) return true;
    const e = g - g_enemy;
    return e / n_role <= e % n_role;
}

fn key(g: usize, a: u32, b: u32) u64 {
    return @as(u64, g) << 48 | @as(u64, a) << 24 | b;
}

/// The cells a game side touches in group g, as (key, sign); identified matchups
fn cells(g: usize, t: *const [2][n_role]u32, out: *[2]struct { u64, f32 }) usize {
    if (g < g_ally) {
        const r = g - g_main;
        out[0] = .{ key(g, t[0][r], 0), 1 };
        out[1] = .{ key(g, t[1][r], 0), -1 };
        return 2;
    }
    if (g < g_enemy) {
        var k: usize = 0;
        for (0..n_role) |a| for (a + 1..n_role) |b| {
            if (g_ally + k == g) {
                out[0] = .{ key(g, t[0][a], t[0][b]), 1 };
                out[1] = .{ key(g, t[1][a], t[1][b]), -1 };
                return 2;
            }
            k += 1;
        };
        unreachable;
    }
    const e = g - g_enemy;
    const r = e / n_role;
    const q = e % n_role;
    if (r == q) {
        const a = t[0][r];
        const b = t[1][r];
        if (a == b) return 0;
        out[0] = .{ key(g, @min(a, b), @max(a, b)), if (a < b) 1 else -1 };
        return 1;
    }
    out[0] = .{ key(g, t[0][r], t[1][q]), 1 };
    out[1] = .{ key(g, t[1][r], t[0][q]), -1 };
    return 2;
}

/// win-comp's mix profiles (addinputs.Mix): per champion-role, magic share of champion
/// damage and damage per minute, won and lost rows' means each shrunk to the role mean
/// by `pseudo` rows, profile = the halves' average
const Mix = struct {
    const pseudo = 20;
    acc: std.AutoHashMapUnmanaged(u64, [2][2][2]f64) = .empty,
    role_mean: [n_role][2]f64 = @splat(@splat(0)),

    fn mkey(champion: u32, role: usize) u64 {
        return @as(u64, champion) << 3 | role;
    }

    fn values(s: *const [api.seat_stat_count]f32) [2]f32 {
        const at = struct {
            fn f(st: *const [api.seat_stat_count]f32, x: api.SeatStat) f32 {
                return st[@backingInt(x)];
            }
        }.f;
        const dealt = at(s, .dmg_phys) + at(s, .dmg_magic) + at(s, .dmg_true);
        const mins = at(s, .minutes);
        const nan = std.math.nan(f32);
        return .{
            if (dealt > 0) at(s, .dmg_magic) / dealt else nan,
            if (mins > 0) dealt / mins else nan,
        };
    }

    fn init(gpa: std.mem.Allocator, train: *const api.Train, blue: []const f32) !Mix {
        var m: Mix = .{};
        errdefer m.acc.deinit(gpa);
        var role_acc: [n_role][2][2]f64 = @splat(@splat(@splat(0)));
        for (train.rows) |*r| {
            if (std.math.isNan(blue[r.game])) continue;
            const v = values(&r.stats);
            const role: usize = @backingInt(r.role);
            const e = try m.acc.getOrPutValue(gpa, mkey(r.champion, role), @splat(@splat(@splat(0))));
            const half: usize = @intFromBool(rowWon(blue, r));
            for (0..2) |f| {
                if (std.math.isNan(v[f]) or std.math.isInf(v[f])) continue;
                e.value_ptr[half][f][0] += v[f];
                e.value_ptr[half][f][1] += 1;
                role_acc[role][f][0] += v[f];
                role_acc[role][f][1] += 1;
            }
        }
        for (&m.role_mean, role_acc) |*rm, ra| for (rm, ra) |*x, a| {
            x.* = if (a[1] > 0) a[0] / a[1] else 0;
        };
        return m;
    }

    fn rowWon(blue: []const f32, r: *const api.Row) bool {
        return (blue[r.game] > 0.5) == (r.side == 0);
    }

    /// own: the training row to leave out, with its game's result
    fn profile(m: *const Mix, champion: u32, role: usize, own: ?struct { *const api.Row, []const f32 }) [2]f64 {
        const rm = m.role_mean[role];
        const a = m.acc.get(mkey(champion, role)) orelse return rm;
        var drop: [2][2]f64 = @splat(@splat(0));
        var drop_n: [2][2]f64 = @splat(@splat(0));
        if (own) |o| {
            const v = values(&o[0].stats);
            const half: usize = @intFromBool(rowWon(o[1], o[0]));
            for (0..2) |f| if (!std.math.isNan(v[f]) and !std.math.isInf(v[f])) {
                drop[half][f] = v[f];
                drop_n[half][f] = 1;
            };
        }
        var out: [2]f64 = undefined;
        for (0..2) |f| {
            var v: f64 = 0;
            for (0..2) |h| v += 0.5 * (a[h][f][0] - drop[h][f] + pseudo * rm[f]) / (a[h][f][1] - drop_n[h][f] + pseudo);
            out[f] = v;
        }
        return out;
    }

    /// Blue's mix minus red's from per-seat profiles [side][role]; an empty seat counts
    /// for nothing
    fn diff(p: *const [2][n_role]?[2]f64) f32 {
        var mix: [2]f64 = undefined;
        for (0..2) |s| {
            var num: f64 = 0;
            var den: f64 = 0;
            for (p[s]) |o| if (o) |x| {
                num += x[1] * x[0];
                den += x[1];
            };
            const frac = if (den > 0) num / den else 0.5;
            mix[s] = (frac - 0.5) * (frac - 0.5);
        }
        return @floatCast(mix[0] - mix[1]);
    }
};

pub const Model = struct {
    mix: Mix = .{},
    keys: std.AutoHashMapUnmanaged(u64, u32) = .empty,
    theta: []f64 = &.{},
};

fn sigmoid(x: f64) f64 {
    return 1 / (1 + @exp(-x));
}

pub fn fit(gpa: std.mem.Allocator, train: *const api.Train, _: api.Options) !Model {
    var arena_state = std.heap.ArenaAllocator.init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const blue = try arena.alloc(f32, train.games.len);
    @memset(blue, std.math.nan(f32));
    for (train.rows) |r| {
        const y = r.y[api.outcomeIndex(.win)];
        if (std.math.isNan(y)) continue;
        blue[r.game] = if (r.side == 0) y else 1 - y;
    }
    var m: Model = .{};
    errdefer deinit(&m, gpa);
    m.mix = try Mix.init(gpa, train, blue);

    // Fit games with their own rows left out of the mix profiles (rows of a game are
    // adjacent)
    var prof = try arena.alloc([2][n_role]?[2]f64, train.games.len);
    for (prof) |*p| p.* = @splat(@splat(null));
    for (train.rows) |*r| {
        if (std.math.isNan(blue[r.game])) continue;
        prof[r.game][r.side][@backingInt(r.role)] = m.mix.profile(r.champion, @backingInt(r.role), .{ r, blue });
    }
    var games: std.ArrayList(GameIn) = .empty;
    for (train.games, blue, prof) |g, b, *p| {
        if (std.math.isNan(b)) continue;
        try games.append(arena, .{ .teams = g.teams, .platform = g.platform, .y = b, .cont = .{ Mix.diff(p), 0, 0, 0 } });
    }

    // additive.build: params of a group contiguous, for cells seen in the fit games
    var key_of: std.ArrayList(u64) = .empty;
    for (0..fixed_params) |i| try key_of.append(arena, key(g_fixed, @intCast(i), 0));
    var param_start: [n_groups + 1]u32 = undefined;
    var group_start: [n_groups + 1]u32 = undefined;
    param_start[0] = 0;
    group_start[0] = 0;
    var n_entries: usize = games.items.len * (1 + n_cont);
    var buf: [2]struct { u64, f32 } = undefined;
    for (1..n_groups) |g| {
        param_start[g] = @intCast(key_of.items.len);
        group_start[g] = @intCast(n_entries);
        if (!hasGroup(g)) continue;
        for (games.items) |*gm| {
            const n = cells(g, &gm.teams, &buf);
            for (buf[0..n]) |c| {
                const e = try m.keys.getOrPut(gpa, c[0]);
                if (!e.found_existing) {
                    e.value_ptr.* = @intCast(key_of.items.len);
                    try key_of.append(arena, c[0]);
                }
            }
            n_entries += n;
        }
    }
    param_start[n_groups] = @intCast(key_of.items.len);
    group_start[n_groups] = @intCast(n_entries);
    param_start[1] = @max(param_start[1], fixed_params);

    const entries = try arena.alloc(Entry, n_entries);
    var at: usize = 0;
    for (games.items, 0..) |*gm, gi| {
        entries[at] = .{ .game = @intCast(gi), .param = gm.platform, .x = 1 };
        at += 1;
        for (0..n_cont) |c| {
            entries[at] = .{ .game = @intCast(gi), .param = @intCast(n_platforms + c), .x = if (c == 0) gm.cont[c] else 0 };
            at += 1;
        }
    }
    for (1..n_groups) |g| {
        std.debug.assert(at == group_start[g]);
        if (!hasGroup(g)) continue;
        for (games.items, 0..) |*gm, gi| {
            const n = cells(g, &gm.teams, &buf);
            for (buf[0..n]) |c| {
                entries[at] = .{ .game = @intCast(gi), .param = m.keys.get(c[0]).?, .x = c[1] };
                at += 1;
            }
        }
    }

    // additive.fit, logistic, variances estimated
    const np = key_of.items.len;
    const ng = games.items.len;
    m.theta = try gpa.alloc(f64, np);
    const theta = m.theta;
    @memset(theta, 0);
    const h = try arena.alloc(f64, np);
    const grad = try arena.alloc(f64, np);
    const eta = try arena.alloc(f64, ng);
    const r = try arena.alloc(f64, ng);
    const cv = try arena.alloc(f64, ng);
    var sigma2: [n_groups]f64 = @splat(sigma2_init);
    @memset(eta, 0);
    var pass: u32 = 0;
    while (pass < outer * inner + final) : (pass += 1) {
        for (0..n_groups) |g| {
            const lo = param_start[g];
            const hi = if (g == g_fixed) fixed_params else param_start[g + 1];
            if (hi <= lo) continue;
            for (games.items, eta, r, cv) |gm, e, *ri, *ci| {
                const q = sigmoid(e);
                ri.* = gm.y - q;
                ci.* = q * (1 - q);
            }
            @memset(grad[lo..hi], 0);
            @memset(h[lo..hi], 0);
            const es = entries[group_start[g]..group_start[g + 1]];
            for (es) |e| {
                grad[e.param] += e.x * r[e.game];
                h[e.param] += e.x * e.x * cv[e.game];
            }
            const lam = if (g == g_fixed) fixed_l2 else 1 / sigma2[g];
            for (lo..hi) |j| {
                h[j] += lam;
                const step = (grad[j] - lam * theta[j]) / h[j];
                theta[j] += step;
                grad[j] = step;
            }
            for (es) |e| eta[e.game] += e.x * grad[e.param];
        }
        if (pass < outer * inner and (pass + 1) % inner == 0) {
            for (1..n_groups) |g| {
                const lo = param_start[g];
                const hi = param_start[g + 1];
                if (hi <= lo) continue;
                const lam = 1 / sigma2[g];
                var ss: f64 = 0;
                var gam: f64 = 0;
                for (lo..hi) |j| {
                    ss += theta[j] * theta[j];
                    gam += 1 - lam / h[j];
                }
                sigma2[g] = if (gam > 1e-9) @max(ss / gam, sigma2_floor) else sigma2_floor;
            }
        }
    }
    return m;
}

/// Blue's logit; cells not in the fit games count 0, empty seats have no profile
pub fn blueLogit(m: *const Model, teams: [2][n_role]u32, platform: u8) f64 {
    var prof: [2][n_role]?[2]f64 = @splat(@splat(null));
    for (0..2) |s| for (teams[s], 0..) |c, role| {
        if (c != 0) prof[s][role] = m.mix.profile(c, role, null);
    };
    var x = m.theta[platform] + m.theta[n_platforms] * Mix.diff(&prof);
    var buf: [2]struct { u64, f32 } = undefined;
    for (1..n_groups) |g| {
        if (!hasGroup(g)) continue;
        const n = cells(g, &teams, &buf);
        for (buf[0..n]) |cl| {
            if (m.keys.get(cl[0])) |j| x += cl[1] * m.theta[j];
        }
    }
    return x;
}

pub fn predict(m: *const Model, q: *const api.Query) api.Prediction {
    var out: api.Prediction = api.no_opinion;
    const p = sigmoid(blueLogit(m, q.teams, q.platform));
    out[api.outcomeIndex(.win)] = @floatCast(if (q.side == 0) p else 1 - p);
    return out;
}

pub fn deinit(m: *Model, gpa: std.mem.Allocator) void {
    m.mix.acc.deinit(gpa);
    m.keys.deinit(gpa);
    gpa.free(m.theta);
}
