//! One shrunk additive draft model (docs/model.md "Effects and the CPU model"): blue's
//! logit (win) or blue-minus-red outcome (team gold at 14) as
//!   platform side + sum over roles of champion strength (blue minus red)
//!   + 10 ally role-pair blocks + 15 matchup blocks (one cell per champion pair)
//!   + continuous comp features (blue minus red)
//!   + on games flagged `offset` (the latest patch's, lab/patchdays.zig), a champion-role
//!     offset per role: the patch's own shift, shrunk to 0 (docs/plan/patch-transfer.md)
//! A matchup (role r vs role q, r <= q) is one cell per pair of champions, from the r
//! side: blue gains it when blue has the r champion, loses it when red has; a same-role
//! matchup is one cell per unordered pair, signed. The older parametrisation (25 enemy
//! blocks, "my role r vs their role q" from both sides, Variant.matchup false) has two
//! cells per matchup of which only the difference is identified, so its block sds are
//! not the matchup's spread and simulation calibration can't target them
//! Every champion-role and pair block is a random effect with its own variance, estimated
//! from the fit games (MacKay's fixed point, diagonal posterior: sigma^2 = sum theta^2 /
//! effective parameters), so sigma per block is "how much this kind of pair matters". The
//! fit is block Gauss-Seidel: each group's cells get one Newton step on the diagonal
//! (cells of a group never share a game side), the game logits updated after each group.
//! Cheap at use time: ~80 table lookups per draft, no GPU

const std = @import("std");
const par = @import("par.zig");
const sigmoid = @import("logreg.zig").sigmoid;

pub const n_role = 5;
pub const n_platforms = 16;
pub const n_cont = 4;

pub const n_ally = 10;
pub const n_enemy = 25;
/// 0 fixed (platform side, comp features), 1..5 champion strength by role, then ally
/// pairs (r < q), then enemy pairs (my role r, their role q), then patch offsets by role
pub const n_groups = 1 + n_role + n_ally + n_enemy + n_role;
pub const g_fixed = 0;
pub const g_main = 1;
pub const g_ally = g_main + n_role;
pub const g_enemy = g_ally + n_ally;
pub const g_offset = g_enemy + n_enemy;

pub const role_names = [n_role][]const u8{ "top", "jungle", "middle", "bottom", "support" };

pub fn allyGroup(r: usize, q: usize) usize {
    std.debug.assert(r < q);
    var k: usize = 0;
    for (0..n_role) |a| for (a + 1..n_role) |b| {
        if (a == r and b == q) return g_ally + k;
        k += 1;
    };
    unreachable;
}

pub fn enemyGroup(r: usize, q: usize) usize {
    return g_enemy + r * n_role + q;
}

/// A pair group's roles: allies in r < q, or a matchup (my role r, their role q)
pub fn groupRoles(g: usize) struct { ally: bool, r: usize, q: usize } {
    std.debug.assert(g >= g_ally and g < g_offset);
    if (g >= g_enemy) return .{ .ally = false, .r = (g - g_enemy) / n_role, .q = (g - g_enemy) % n_role };
    var k: usize = 0;
    for (0..n_role) |a| for (a + 1..n_role) |b| {
        if (g_ally + k == g) return .{ .ally = true, .r = a, .q = b };
        k += 1;
    };
    unreachable;
}

/// "champion top", "ally jungle-middle", "jungle vs their middle", "offset top"
pub fn groupName(buf: []u8, g: usize) []const u8 {
    if (g == g_fixed) return "fixed";
    if (g < g_ally) return std.mem.print(buf, "champion {s}", .{role_names[g - g_main]}) catch unreachable;
    if (g >= g_offset) return std.mem.print(buf, "offset {s}", .{role_names[g - g_offset]}) catch unreachable;
    if (g < g_enemy) {
        var k: usize = 0;
        for (0..n_role) |a| for (a + 1..n_role) |b| {
            if (g_ally + k == g) return std.mem.print(buf, "ally {s}-{s}", .{ role_names[a], role_names[b] }) catch unreachable;
            k += 1;
        };
        unreachable;
    }
    const e = g - g_enemy;
    return std.mem.print(buf, "{s} vs their {s}", .{ role_names[e / n_role], role_names[e % n_role] }) catch unreachable;
}

pub const Kind = enum { logistic, gaussian };

/// Groups switched on, as a bit per group (bit 0, fixed, always on); cont features on
pub const Variant = struct {
    groups: u64 = 1,
    cont: u8 = 0,
    /// Identified matchups: same-role enemy blocks one signed cell per unordered pair;
    /// use with enemy groups r <= q only (matchupGroups)
    matchup: bool = false,

    pub fn with(v: Variant, g: usize) Variant {
        var o = v;
        o.groups |= @as(u64, 1) << @intCast(g);
        return o;
    }

    pub fn has(v: Variant, g: usize) bool {
        return v.groups >> @intCast(g) & 1 == 1;
    }

    pub fn mains() Variant {
        var v: Variant = .{};
        for (g_main..g_ally) |g| v = v.with(g);
        return v;
    }

    /// Every group but the patch offsets
    pub fn all() Variant {
        return .{ .groups = (@as(u64, 1) << g_offset) - 1, .cont = (1 << n_cont) - 1 };
    }

    /// The patch offsets on, for games flagged GameIn.offset
    pub fn withOffsets(v: Variant) Variant {
        var o = v;
        for (g_offset..n_groups) |g| o = o.with(g);
        return o;
    }

    /// Every ally block and the 15 matchup blocks (enemy r <= q), identified
    pub fn matchupGroups(v: Variant) Variant {
        var o = v;
        for (0..n_role) |r| for (r + 1..n_role) |q| {
            o = o.with(allyGroup(r, q));
        };
        for (0..n_role) |r| for (r..n_role) |q| {
            o = o.with(enemyGroup(r, q));
        };
        o.matchup = true;
        return o;
    }
};

pub const GameIn = struct {
    /// Champion ids by side (0 blue) and role
    teams: [2][n_role]u32,
    platform: u8,
    /// win: 1 blue won (or a soft target in [0, 1]); gaussian: blue minus red
    y: f32,
    /// Blue minus red
    cont: [n_cont]f32 = @splat(0),
    weight: f32 = 1,
    /// The patch offset groups' cells apply (the latest patch's games)
    offset: bool = false,
};

const Entry = struct { game: u32, param: u32, x: f32 };

fn key(g: usize, a: u32, b: u32) u64 {
    return @as(u64, g) << 48 | @as(u64, a) << 24 | b;
}

/// The cells a game side touches in group g, as (key, sign); at most 2 for every group
/// but fixed. matchup: a same-role enemy block has one signed cell per unordered pair
/// (none for a mirror). offset: the game takes the patch offsets
fn cells(g: usize, t: *const [2][n_role]u32, out: *[2]struct { u64, f32 }, matchup: bool, offset: bool) usize {
    if (g < g_ally or g >= g_offset) {
        if (g >= g_offset and !offset) return 0;
        const r = if (g < g_ally) g - g_main else g - g_offset;
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
    if (matchup and r == q) {
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

/// The fit games as entries by group; params of a group contiguous. Params exist for
/// cells seen in these games only; a scored game's unseen cell counts 0
pub const Problem = struct {
    variant: Variant,
    kind: Kind,
    games: []const GameIn,
    entries: []Entry,
    /// Entries of group g: entries[group_start[g]..group_start[g + 1]]
    group_start: [n_groups + 1]u32,
    /// Params of group g: param_start[g]..param_start[g + 1]
    param_start: [n_groups + 1]u32,
    /// Games behind each param
    count: []u32,
    keys: std.AutoHashMapUnmanaged(u64, u32),
    /// Param index -> key, for tables
    key_of: []u64,
    /// Pair cells shrunk toward parents instead of 0 (addParents)
    parents: ?Parents = null,

    pub fn n_params(p: *const Problem) usize {
        return p.param_start[n_groups];
    }

    pub fn deinit(p: *Problem, gpa: std.mem.Allocator) void {
        gpa.free(p.entries);
        gpa.free(p.count);
        gpa.free(p.key_of);
        p.keys.deinit(gpa);
        if (p.parents) |*x| x.deinit(gpa);
    }

    /// Identified matchups only (Variant.matchupGroups)
    pub fn addParents(p: *Problem, gpa: std.mem.Allocator, classes: []const KitClass) !void {
        std.debug.assert(p.variant.matchup and p.parents == null);
        p.parents = try .init(gpa, p, classes);
    }
};

/// A champion's kit class for Parents: role-free (Data Dragon tags, KitClass.fromTags)
pub const KitClass = struct {
    id: u32,
    class: u16,

    /// Classes by the sorted distinct tag strings ("Fighter,Tank")
    pub fn fromTags(gpa: std.mem.Allocator, ids: []const u32, tags: []const []const u8) ![]KitClass {
        const sorted = try gpa.dupe([]const u8, tags);
        defer gpa.free(sorted);
        std.mem.sort([]const u8, sorted, {}, struct {
            fn lt(_: void, a: []const u8, b: []const u8) bool {
                return std.mem.lessThan(u8, a, b);
            }
        }.lt);
        var n: usize = 0;
        for (sorted) |t| {
            if (n > 0 and std.mem.eql(u8, sorted[n - 1], t)) continue;
            sorted[n] = t;
            n += 1;
        }
        const out = try gpa.alloc(KitClass, ids.len);
        for (ids, tags, out) |id, t, *o| {
            const i = for (sorted[0..n], 0..) |x, i| {
                if (std.mem.eql(u8, x, t)) break i;
            } else unreachable;
            o.* = .{ .id = id, .class = @intCast(i) };
        }
        return out;
    }
};

/// Pair cells that borrow strength (docs/model.md "Pair cells that borrow strength (A4)",
/// the lab's pairprior `pair+kit:tag`): a pair cell's value is its own part plus two
/// parents it shares with other cells, so a thin cell is shrunk toward them, not 0:
/// the same two champions in any slot of the kind (one table over the 10 ally blocks,
/// unordered; one over the 15 matchup blocks, from the lower id's side), and a kit-class
/// pair per block (signed as the cell; a same-role matchup of one class has none).
/// Parents are random effects with MacKay variances (kit: one per block; pair: one per
/// kind), fitted with the cells; a cell the fit games never had still gets its parents
pub const Parents = struct {
    /// Per param (pair cells only, else none): its kit and pair parent and their signs
    kit_of: []u32,
    kit_sign: []f32,
    pair_of: []u32,
    pair_sign: []f32,
    /// Kit parents are 0..n_kit, pair parents n_kit..
    n_kit: u32,
    /// Per parent: its variance group (kit: the block's group; pair: n_groups ally,
    /// n_groups + 1 matchups)
    group: []u8,
    index: std.AutoHashMapUnmanaged(u64, u32),
    class: std.AutoHashMapUnmanaged(u32, u16),
    /// The class of champions `class` doesn't know
    none: u16,

    pub const none_idx = std.math.maxInt(u32);

    fn init(gpa: std.mem.Allocator, p: *const Problem, classes: []const KitClass) !Parents {
        const np = p.n_params();
        var x: Parents = .{
            .kit_of = try gpa.alloc(u32, np),
            .kit_sign = try gpa.alloc(f32, np),
            .pair_of = try gpa.alloc(u32, np),
            .pair_sign = try gpa.alloc(f32, np),
            .n_kit = 0,
            .group = &.{},
            .index = .empty,
            .class = .empty,
            .none = 0,
        };
        errdefer x.deinit(gpa);
        @memset(x.kit_of, none_idx);
        @memset(x.pair_of, none_idx);
        for (classes) |c| {
            try x.class.put(gpa, c.id, c.class);
            x.none = @max(x.none, c.class + 1);
        }
        var group: std.ArrayList(u8) = .empty;
        defer group.deinit(gpa);
        const lo = p.param_start[g_ally];
        const hi = p.param_start[g_offset];
        // Kit parents first, so they are 0..n_kit
        for ([_]bool{ true, false }) |kit| {
            for (lo..hi) |j| {
                const cl = cellOf(p, j);
                const pa = (if (kit) x.kitKey(cl.group, cl.a, cl.b) else pairKey(cl.group, cl.a, cl.b)) orelse continue;
                const e = try x.index.getOrPut(gpa, pa[0]);
                if (!e.found_existing) {
                    e.value_ptr.* = @intCast(group.items.len);
                    const grp: usize = if (kit) cl.group else if (cl.group < g_enemy) n_groups else n_groups + 1;
                    try group.append(gpa, @intCast(grp));
                }
                if (kit) {
                    x.kit_of[j] = e.value_ptr.*;
                    x.kit_sign[j] = pa[1];
                } else {
                    x.pair_of[j] = e.value_ptr.*;
                    x.pair_sign[j] = pa[1];
                }
            }
            if (kit) x.n_kit = @intCast(group.items.len);
        }
        x.group = try group.toOwnedSlice(gpa);
        return x;
    }

    pub fn deinit(x: *Parents, gpa: std.mem.Allocator) void {
        gpa.free(x.kit_of);
        gpa.free(x.kit_sign);
        gpa.free(x.pair_of);
        gpa.free(x.pair_sign);
        gpa.free(x.group);
        x.index.deinit(gpa);
        x.class.deinit(gpa);
    }

    fn classOf(x: *const Parents, id: u32) u16 {
        return x.class.get(id) orelse x.none;
    }

    fn kitKey(x: *const Parents, g: usize, a: u32, b: u32) ?struct { u64, f32 } {
        const ka = x.classOf(a);
        const kb = x.classOf(b);
        const gr = groupRoles(g);
        if (gr.ally or gr.r != gr.q) return .{ key(64 + g, ka, kb), 1 };
        if (ka == kb) return null;
        return .{ key(64 + g, @min(ka, kb), @max(ka, kb)), if (ka < kb) 1 else -1 };
    }

    fn pairKey(g: usize, a: u32, b: u32) ?struct { u64, f32 } {
        if (a == b) return null;
        if (g < g_enemy) return .{ key(128, @min(a, b), @max(a, b)), 1 };
        return .{ key(129, @min(a, b), @max(a, b)), if (a < b) 1 else -1 };
    }

    /// The parents' part of pair cell (g, a, b), oriented as the cell's key
    pub fn value(x: *const Parents, parent: []const f64, g: usize, a: u32, b: u32) f64 {
        var v: f64 = 0;
        if (x.kitKey(g, a, b)) |k| if (x.index.get(k[0])) |i| {
            v += k[1] * parent[i];
        };
        if (pairKey(g, a, b)) |k| if (x.index.get(k[0])) |i| {
            v += k[1] * parent[i];
        };
        return v;
    }
};

pub const n_parent_groups = n_groups + 2;

/// Fixed params: platform side 0..n_platforms, then cont features
const fixed_params = n_platforms + n_cont;

pub fn build(gpa: std.mem.Allocator, kind: Kind, variant: Variant, games: []const GameIn) !Problem {
    var keys: std.AutoHashMapUnmanaged(u64, u32) = .empty;
    errdefer keys.deinit(gpa);
    var key_of: std.ArrayList(u64) = .empty;
    errdefer key_of.deinit(gpa);
    var param_start: [n_groups + 1]u32 = undefined;
    var group_start: [n_groups + 1]u32 = undefined;
    var n_entries: usize = 0;
    for (0..fixed_params) |i| try key_of.append(gpa, key(g_fixed, @intCast(i), 0));
    param_start[0] = 0;
    group_start[0] = 0;
    n_entries += games.len * (1 + n_cont);
    var buf: [2]struct { u64, f32 } = undefined;
    for (1..n_groups) |g| {
        param_start[g] = @intCast(key_of.items.len);
        group_start[g] = @intCast(n_entries);
        if (!variant.has(g)) continue;
        for (games) |*gm| {
            const n = cells(g, &gm.teams, &buf, variant.matchup, gm.offset);
            for (buf[0..n]) |c| {
                const e = try keys.getOrPut(gpa, c[0]);
                if (!e.found_existing) {
                    e.value_ptr.* = @intCast(key_of.items.len);
                    try key_of.append(gpa, c[0]);
                }
            }
            n_entries += n;
        }
    }
    param_start[n_groups] = @intCast(key_of.items.len);
    group_start[n_groups] = @intCast(n_entries);
    // Group 0 starts at param 0 but its params are fixed_params long
    param_start[1] = @max(param_start[1], fixed_params);

    const entries = try gpa.alloc(Entry, n_entries);
    errdefer gpa.free(entries);
    const count = try gpa.alloc(u32, key_of.items.len);
    errdefer gpa.free(count);
    @memset(count, 0);
    var at: usize = 0;
    for (games, 0..) |*gm, gi| {
        entries[at] = .{ .game = @intCast(gi), .param = gm.platform, .x = 1 };
        count[gm.platform] += 1;
        at += 1;
        for (0..n_cont) |c| {
            const on = variant.cont >> @intCast(c) & 1 == 1;
            entries[at] = .{ .game = @intCast(gi), .param = @intCast(n_platforms + c), .x = if (on) gm.cont[c] else 0 };
            at += 1;
        }
    }
    for (1..n_groups) |g| {
        std.debug.assert(at == group_start[g]);
        if (!variant.has(g)) continue;
        for (games, 0..) |*gm, gi| {
            const n = cells(g, &gm.teams, &buf, variant.matchup, gm.offset);
            for (buf[0..n]) |c| {
                const pi = keys.get(c[0]).?;
                entries[at] = .{ .game = @intCast(gi), .param = pi, .x = c[1] };
                count[pi] += 1;
                at += 1;
            }
        }
    }
    return .{
        .variant = variant,
        .kind = kind,
        .games = games,
        .entries = entries,
        .group_start = group_start,
        .param_start = param_start,
        .count = count,
        .keys = keys,
        .key_of = try key_of.toOwnedSlice(gpa),
    };
}

pub const Config = struct {
    /// Variance updates; each after `inner` passes over every group
    outer: u32 = 40,
    inner: u32 = 2,
    /// Passes after the last variance update
    final: u32 = 6,
    /// Ridge on fixed params, so never-seen platforms stay solvable
    fixed_l2: f64 = 1e-3,
    /// Variances start here (logit units; gaussian: outcome units squared)
    sigma2_init: f64 = 0.01,
    /// Below this a group is switched off (its cells stay ~0)
    sigma2_floor: f64 = 1e-8,
    /// false: keep the given variances (a refit with them fixed)
    estimate: bool = true,
    /// Per param: the prior's centre (a warm start's old fit, by key), 0 when null; the
    /// fit starts there and variances are estimated from theta - mean
    prior_mean: ?[]const f64 = null,
    /// Per param: its group's prior variance times this (looser for patched champions)
    prior_scale: ?[]const f64 = null,
    /// The offset groups' variance, fixed instead of estimated
    offset_sigma2: ?f64 = null,
    /// Problem.parents' steps halved while they raise the penalised loss (false: the lab
    /// pairprior's steps as they were frozen)
    parent_guard: bool = true,
};

pub const Fit = struct {
    theta: []f64,
    sigma2: [n_groups]f64,
    /// Effective parameters per group: sum of (1 - lambda / H) over its cells
    gamma: [n_groups]f64,
    /// Posterior curvature per param (data + prior), for intervals
    h: []f64,
    /// gaussian: residual variance
    noise: f64,
    /// Problem.parents' values and variances (by Parents.group)
    parent: []f64 = &.{},
    parent_s2: [n_parent_groups]f64 = @splat(0),
    /// Parent steps halved to keep the loss from rising (0 on real games so far)
    parent_halvings: u32 = 0,

    pub fn deinit(f: *Fit, gpa: std.mem.Allocator) void {
        gpa.free(f.theta);
        gpa.free(f.h);
        gpa.free(f.parent);
    }
};

/// weights: per game multipliers (bootstrap), null for 1; warm: a fit of the same problem
/// to start from (theta and variances)
pub fn fit(gpa: std.mem.Allocator, p: *const Problem, cfg: Config, weights: ?[]const f32, warm: ?*const Fit) !Fit {
    const np = p.n_params();
    const ng = p.games.len;
    const theta = try gpa.alloc(f64, np);
    errdefer gpa.free(theta);
    const h = try gpa.alloc(f64, np);
    errdefer gpa.free(h);
    const grad = try gpa.alloc(f64, np);
    defer gpa.free(grad);
    const eta = try gpa.alloc(f64, ng);
    defer gpa.free(eta);
    const r = try gpa.alloc(f64, ng);
    defer gpa.free(r);
    const c = try gpa.alloc(f64, ng);
    defer gpa.free(c);
    var sigma2: [n_groups]f64 = @splat(cfg.sigma2_init);
    var noise: f64 = 1;
    const pa: ?*const Parents = if (p.parents) |*x| x else null;
    const n_par = if (pa) |x| x.group.len else 0;
    const parent = try gpa.alloc(f64, n_par);
    errdefer gpa.free(parent);
    const parent_h = try gpa.alloc(f64, n_par);
    defer gpa.free(parent_h);
    const parent_g = try gpa.alloc(f64, n_par);
    defer gpa.free(parent_g);
    var parent_s2: [n_parent_groups]f64 = @splat(cfg.sigma2_init);
    @memset(parent, 0);
    @memset(parent_h, 1);
    // Parent steps: per pair cell, its summed gradient, curvature and change
    const cell_lo = p.param_start[g_ally];
    const cell_hi = if (pa != null) p.param_start[g_offset] else cell_lo;
    const cell_g = try gpa.alloc(f64, cell_hi - cell_lo);
    defer gpa.free(cell_g);
    const cell_h = try gpa.alloc(f64, cell_g.len);
    defer gpa.free(cell_h);
    const cell_d = try gpa.alloc(f64, cell_g.len);
    defer gpa.free(cell_d);
    const pair_entries = p.entries[p.group_start[g_ally]..p.group_start[g_offset]];
    const eta_try = try gpa.alloc(f64, if (pa != null) ng else 0);
    defer gpa.free(eta_try);
    var halvings: u32 = 0;
    if (warm) |w| {
        @memcpy(theta, w.theta);
        sigma2 = w.sigma2;
        noise = w.noise;
        if (w.parent.len == n_par) {
            @memcpy(parent, w.parent);
            parent_s2 = w.parent_s2;
        }
    } else {
        if (cfg.prior_mean) |m| @memcpy(theta, m) else @memset(theta, 0);
        if (p.kind == .gaussian) {
            var s: f64 = 0;
            var s2: f64 = 0;
            for (p.games) |g| {
                s += g.y;
                s2 += @as(f64, g.y) * g.y;
            }
            const n: f64 = @floatFromInt(@max(ng, 1));
            noise = @max(s2 / n - (s / n) * (s / n), 1e-12);
            for (&sigma2) |*x| x.* = cfg.sigma2_init * noise;
        }
    }
    if (cfg.offset_sigma2) |v| @memset(sigma2[g_offset..], v);
    @memset(eta, 0);
    for (p.entries) |e| eta[e.game] += e.x * theta[e.param];
    if (pa) |x| {
        // A warm start's parents
        for (cell_d, cell_lo..) |*d, j| {
            d.* = 0;
            if (x.kit_of[j] != Parents.none_idx) d.* += x.kit_sign[j] * parent[x.kit_of[j]];
            if (x.pair_of[j] != Parents.none_idx) d.* += x.pair_sign[j] * parent[x.pair_of[j]];
        }
        for (pair_entries) |e| eta[e.game] += e.x * cell_d[e.param - cell_lo];
    }

    const passes = if (cfg.estimate) cfg.outer * cfg.inner + cfg.final else cfg.final + cfg.inner;
    var pass: u32 = 0;
    while (pass < passes) : (pass += 1) {
        for (0..n_groups) |g| {
            const lo = p.param_start[g];
            const hi = if (g == g_fixed) fixed_params else p.param_start[g + 1];
            if (hi <= lo) continue;
            working(p, weights, noise, eta, r, c);
            @memset(grad[lo..hi], 0);
            @memset(h[lo..hi], 0);
            const es = p.entries[p.group_start[g]..p.group_start[g + 1]];
            for (es) |e| {
                grad[e.param] += e.x * r[e.game];
                h[e.param] += e.x * e.x * c[e.game];
            }
            const lam_g = if (g == g_fixed) cfg.fixed_l2 else 1 / sigma2[g];
            for (lo..hi) |j| {
                const lam = lam_g / scaleOf(cfg, j);
                h[j] += lam;
                const step = (grad[j] - lam * (theta[j] - meanOf(cfg, j))) / h[j];
                theta[j] += step;
                grad[j] = step;
            }
            for (es) |e| eta[e.game] += e.x * grad[e.param];
        }
        if (pa) |x| {
            // Kit parents, then pair parents: one diagonal Newton step each on their
            // cells' summed gradient and curvature
            const steps = [_]struct { []const u32, []const f32, usize, usize }{
                .{ x.kit_of, x.kit_sign, 0, x.n_kit },
                .{ x.pair_of, x.pair_sign, x.n_kit, n_par },
            };
            for (steps) |st| {
                if (st[3] <= st[2]) continue;
                working(p, weights, noise, eta, r, c);
                @memset(cell_g, 0);
                @memset(cell_h, 0);
                for (pair_entries) |e| {
                    cell_g[e.param - cell_lo] += e.x * r[e.game];
                    cell_h[e.param - cell_lo] += e.x * e.x * c[e.game];
                }
                const of = st[0][cell_lo..cell_hi];
                const sign = st[1][cell_lo..cell_hi];
                @memset(parent_g[st[2]..st[3]], 0);
                @memset(parent_h[st[2]..st[3]], 0);
                for (of, sign, cell_g, cell_h) |k, sg, gj, hj| {
                    if (k == Parents.none_idx) continue;
                    parent_g[k] += sg * gj;
                    parent_h[k] += hj;
                }
                var prior_before: f64 = 0;
                for (st[2]..st[3]) |k| {
                    const lam = 1 / parent_s2[x.group[k]];
                    parent_h[k] += lam;
                    parent_g[k] = (parent_g[k] - lam * parent[k]) / parent_h[k];
                    prior_before += 0.5 * lam * parent[k] * parent[k];
                }
                for (of, sign, cell_d) |k, sg, *d| d.* = if (k == Parents.none_idx) 0 else sg * parent_g[k];
                // The parents of one step share game sides (a team's 10 ally pairs), so
                // the diagonal step overshoots where data outweighs the prior (dense
                // pairs: a 12-champion test ran to 150 logits). Halved until the
                // penalised loss doesn't rise; fits on real games don't halve
                const before = if (cfg.parent_guard) loss(p, weights, noise, eta) + prior_before else 0;
                var scale: f64 = 1;
                // Past 30 halvings the step is ~0: taken as is
                for (0..31) |i| {
                    @memcpy(eta_try, eta);
                    for (pair_entries) |e| eta_try[e.game] += scale * e.x * cell_d[e.param - cell_lo];
                    var prior_after: f64 = 0;
                    for (st[2]..st[3]) |k| {
                        const t = parent[k] + scale * parent_g[k];
                        prior_after += 0.5 / parent_s2[x.group[k]] * t * t;
                    }
                    const after = if (cfg.parent_guard) loss(p, weights, noise, eta_try) + prior_after else 0;
                    if (!cfg.parent_guard or after <= before + 1e-9 * @abs(before) or i == 30) break;
                    scale /= 2;
                    halvings += 1;
                }
                for (st[2]..st[3]) |k| parent[k] += scale * parent_g[k];
                @memcpy(eta, eta_try);
            }
        }
        const last_inner = (pass + 1) % cfg.inner == 0;
        if (cfg.estimate and pass < cfg.outer * cfg.inner and last_inner) {
            // h holds data + prior curvature from this pass
            for (1..n_groups) |g| {
                const lo = p.param_start[g];
                const hi = p.param_start[g + 1];
                if (hi <= lo) continue;
                if (g >= g_offset and cfg.offset_sigma2 != null) continue;
                var ss: f64 = 0;
                var gam: f64 = 0;
                for (lo..hi) |j| {
                    const s = scaleOf(cfg, j);
                    const d = theta[j] - meanOf(cfg, j);
                    ss += d * d / s;
                    gam += 1 - 1 / (sigma2[g] * s * h[j]);
                }
                const floor = cfg.sigma2_floor * (if (p.kind == .gaussian) noise else 1);
                sigma2[g] = if (gam > 1e-9) @max(ss / gam, floor) else floor;
            }
            if (pa) |x| {
                var ss: [n_parent_groups]f64 = @splat(0);
                var gam: [n_parent_groups]f64 = @splat(0);
                for (parent, parent_h, x.group) |t, hk, g| {
                    ss[g] += t * t;
                    gam[g] += 1 - 1 / (parent_s2[g] * hk);
                }
                const floor = cfg.sigma2_floor * (if (p.kind == .gaussian) noise else 1);
                for (&parent_s2, ss, gam) |*v, sg, gm| {
                    if (gm == 0 and sg == 0) continue;
                    v.* = if (gm > 1e-9) @max(sg / gm, floor) else floor;
                }
            }
            if (p.kind == .gaussian) {
                var s: f64 = 0;
                var wsum: f64 = 0;
                for (p.games, eta, 0..) |gm, e, i| {
                    const w: f64 = if (weights) |ws| ws[i] * gm.weight else gm.weight;
                    s += w * (gm.y - e) * (gm.y - e);
                    wsum += w;
                }
                noise = @max(s / @max(wsum, 1e-12), 1e-12);
            }
        }
    }
    var gamma: [n_groups]f64 = @splat(0);
    for (1..n_groups) |g| {
        for (p.param_start[g]..p.param_start[g + 1]) |j| gamma[g] += 1 - 1 / (sigma2[g] * scaleOf(cfg, j) * h[j]);
    }
    for (1..n_groups) |g| if (p.param_start[g + 1] <= p.param_start[g]) {
        sigma2[g] = 0;
    };
    return .{ .theta = theta, .sigma2 = sigma2, .gamma = gamma, .h = h, .noise = noise, .parent = parent, .parent_s2 = parent_s2, .parent_halvings = halvings };
}

/// The fit games' negative log likelihood (gaussian: up to a constant)
fn loss(p: *const Problem, weights: ?[]const f32, noise: f64, eta: []const f64) f64 {
    var s: f64 = 0;
    for (p.games, eta, 0..) |gm, e, i| {
        const w: f64 = if (weights) |ws| ws[i] * gm.weight else gm.weight;
        s += w * switch (p.kind) {
            .logistic => @max(e, 0) - gm.y * e + std.math.log1p(@exp(-@abs(e))),
            .gaussian => (gm.y - e) * (gm.y - e) / (2 * noise),
        };
    }
    return s;
}

/// Working residual and curvature per game
fn working(p: *const Problem, weights: ?[]const f32, noise: f64, eta: []const f64, r: []f64, c: []f64) void {
    for (p.games, eta, r, c, 0..) |gm, e, *ri, *ci, i| {
        const w: f64 = if (weights) |ws| ws[i] * gm.weight else gm.weight;
        switch (p.kind) {
            .logistic => {
                const q = sigmoid(e);
                ri.* = w * (gm.y - q);
                ci.* = w * q * (1 - q);
            },
            .gaussian => {
                ri.* = w * (gm.y - e) / noise;
                ci.* = w / noise;
            },
        }
    }
}

fn meanOf(cfg: Config, j: usize) f64 {
    return if (cfg.prior_mean) |m| m[j] else 0;
}

fn scaleOf(cfg: Config, j: usize) f64 {
    return if (cfg.prior_scale) |s| s[j] else 1;
}

/// Block variances corrected by simulation. Laplace-type estimates of a random effect's
/// variance run low on win (binary) outcomes when cells have few games (test "planted
/// pair sd"), and pure noise gives a spread too. So: plant every block at a trial sd on
/// the same games (cells drawn afresh, the fit's fixed terms kept), draw outcomes, refit,
/// and scale each trial sd by sqrt(observed / mean simulated) (damped: blocks trade
/// variance, so undamped steps overshoot); repeated `iters` times. Pair blocks only:
/// champion strength has hundreds of games per cell and stays at the fit's own sd (an
/// undamped joint update ran it up 4-5x). A block whose observed sd is no more than noise
/// gives calibrates towards 0
pub const Calibration = struct {
    sigma2: [n_groups]f64,
    /// Calibrated sd over the fit's own sd (1 for an unbiased block)
    factor: [n_groups]f64,
    /// Last round: observed sd over the simulations' mean sd (1 when converged)
    misfit: [n_groups]f64,
};

pub fn calibrate(gpa: std.mem.Allocator, io: std.Io, p: *const Problem, obs: *const Fit, cfg: Config, sims: u32, iters: u32, seed: u64) !Calibration {
    var s_true: [n_groups]f64 = undefined;
    for (&s_true, obs.sigma2) |*t, v| t.* = @sqrt(@max(v, 0));
    const sim_sd = try gpa.alloc([n_groups]f64, sims);
    defer gpa.free(sim_sd);
    var misfit: [n_groups]f64 = @splat(1);
    const Ctx = struct {
        gpa: std.mem.Allocator,
        p: *const Problem,
        obs: *const Fit,
        cfg: Config,
        s_true: [n_groups]f64,
        seed: u64,
        out: [][n_groups]f64,
        fn one(x: @This(), i: usize) !void {
            const np = x.p.n_params();
            const cell = try x.gpa.alloc(f64, np);
            defer x.gpa.free(cell);
            var rng: std.Random.DefaultPrng = .init(x.seed +% i *% 0x9e3779b97f4a7c15);
            const r = rng.random();
            @memcpy(cell[0..fixed_params], x.obs.theta[0..fixed_params]);
            for (1..n_groups) |g| for (x.p.param_start[g]..x.p.param_start[g + 1]) |j| {
                cell[j] = r.floatNorm(f64) * x.s_true[g];
            };
            const games = try x.gpa.dupe(GameIn, x.p.games);
            defer x.gpa.free(games);
            const eta = try x.gpa.alloc(f64, games.len);
            defer x.gpa.free(eta);
            @memset(eta, 0);
            for (x.p.entries) |e| eta[e.game] += e.x * cell[e.param];
            const sd_noise = @sqrt(x.obs.noise);
            for (games, eta) |*g, e| g.y = switch (x.p.kind) {
                .logistic => if (r.float(f64) < sigmoid(e)) 1 else 0,
                .gaussian => @floatCast(e + r.floatNorm(f64) * sd_noise),
            };
            var q = x.p.*;
            q.games = games;
            var f = try fit(x.gpa, &q, x.cfg, null, null);
            defer f.deinit(x.gpa);
            for (&x.out[i], f.sigma2) |*o, v| o.* = @sqrt(@max(v, 0));
        }
    };
    for (0..iters) |it| {
        try par.forEach(io, sims, Ctx{ .gpa = gpa, .p = p, .obs = obs, .cfg = cfg, .s_true = s_true, .seed = seed +% it *% 1000, .out = sim_sd }, Ctx.one);
        for (g_ally..n_groups) |g| {
            var m: f64 = 0;
            for (sim_sd) |sd| m += sd[g];
            m /= @floatFromInt(@max(sims, 1));
            const o = @sqrt(@max(obs.sigma2[g], 0));
            misfit[g] = if (m > 0) o / m else 1;
            // Damped multiplicative step, capped so one noisy round can't run away
            if (m > 0 and s_true[g] > 0) s_true[g] *= @sqrt(std.math.clamp(o / m, 0.25, 4));
        }
    }
    var out: Calibration = undefined;
    out.misfit = misfit;
    for (0..n_groups) |g| {
        out.sigma2[g] = s_true[g] * s_true[g];
        const o = @sqrt(@max(obs.sigma2[g], 0));
        out.factor[g] = if (o > 0) s_true[g] / o else 1;
    }
    out.sigma2[g_fixed] = obs.sigma2[g_fixed];
    out.factor[g_fixed] = 1;
    return out;
}

/// Blue's logit (win) or blue minus red (gaussian) for any game; cells not in the fit
/// games count 0
pub fn predict(p: *const Problem, f: *const Fit, g: *const GameIn) f64 {
    var x = f.theta[g.platform];
    for (0..n_cont) |c| {
        if (p.variant.cont >> @intCast(c) & 1 == 1) x += f.theta[n_platforms + c] * g.cont[c];
    }
    var buf: [2]struct { u64, f32 } = undefined;
    for (1..n_groups) |gr| {
        if (!p.variant.has(gr)) continue;
        const n = cells(gr, &g.teams, &buf, p.variant.matchup, g.offset);
        for (buf[0..n]) |cl| {
            if (p.keys.get(cl[0])) |j| x += cl[1] * f.theta[j];
            if (p.parents) |*pa| if (gr >= g_ally and gr < g_offset) {
                x += cl[1] * pa.value(f.parent, gr, @intCast(cl[0] >> 24 & 0xffffff), @intCast(cl[0] & 0xffffff));
            };
        }
    }
    return x;
}

/// A param's cell: group, first and second champion (second 0 for strength)
pub fn cellOf(p: *const Problem, j: usize) struct { group: usize, a: u32, b: u32 } {
    const k = p.key_of[j];
    return .{ .group = @intCast(k >> 48), .a = @intCast(k >> 24 & 0xffffff), .b = @intCast(k & 0xffffff) };
}

const testing = std.testing;
/// Half the default variance updates: the same estimates on these tests' games in half
/// the time. "planted pair sd" keeps the default: its logistic bias is a converged fit's
const quick: Config = .{ .outer = 20 };

/// Random games over n champions per role; the true model: strength sd s_main per role,
/// pair cells sd s_pair in group `planted` only, everything else 0
fn synth(gpa: std.mem.Allocator, kind: Kind, n_games: usize, n_champ: u32, s_main: f64, planted: usize, s_pair: f64, seed: u64) ![]GameIn {
    var rng: std.Random.DefaultPrng = .init(seed);
    const rnd = rng.random();
    const mains = try gpa.alloc(f64, n_role * n_champ);
    defer gpa.free(mains);
    for (mains) |*m| m.* = rnd.floatNorm(f64) * s_main;
    const pairs = try gpa.alloc(f64, n_champ * n_champ);
    defer gpa.free(pairs);
    for (pairs) |*m| m.* = rnd.floatNorm(f64) * s_pair;
    const games = try gpa.alloc(GameIn, n_games);
    for (games) |*g| {
        g.* = .{ .teams = undefined, .platform = 0, .y = 0 };
        for (0..2) |s| for (0..n_role) |r| {
            // Champion ids by role in disjoint ranges, as real ids differ by role
            g.teams[s][r] = @intCast(1 + r * 1000 + rnd.uintLessThan(u32, n_champ));
        };
        var eta: f64 = 0.05;
        for (0..n_role) |r| {
            eta += mains[r * n_champ + (g.teams[0][r] - 1 - r * 1000)];
            eta -= mains[r * n_champ + (g.teams[1][r] - 1 - r * 1000)];
        }
        var buf: [2]struct { u64, f32 } = undefined;
        const nc = cells(planted, &g.teams, &buf, false, false);
        for (buf[0..nc]) |cl| {
            const a: u32 = @intCast(cl[0] >> 24 & 0xffffff);
            const b: u32 = @intCast(cl[0] & 0xffffff);
            eta += cl[1] * pairs[((a - 1) % 1000) * n_champ + (b - 1) % 1000];
        }
        g.platform = 0;
        g.y = switch (kind) {
            .logistic => if (rnd.float(f64) < sigmoid(eta)) 1 else 0,
            .gaussian => @floatCast(eta + rnd.floatNorm(f64)),
        };
    }
    return games;
}

test "planted pair variance is recovered, empty blocks shrink to ~0" {
    const gpa = testing.allocator;
    const planted = allyGroup(1, 2);
    const games = try synth(gpa, .logistic, 40_000, 12, 0.2, planted, 0.25, 7);
    defer gpa.free(games);
    var v = Variant.mains().with(planted).with(allyGroup(0, 1)).with(enemyGroup(2, 2));
    v.cont = 0;
    var p = try build(gpa, .logistic, v, games);
    defer p.deinit(gpa);
    var f = try fit(gpa, &p, quick, null, null);
    defer f.deinit(gpa);
    try testing.expectApproxEqAbs(0.25, @sqrt(f.sigma2[planted]), 0.06);
    try testing.expect(@sqrt(f.sigma2[allyGroup(0, 1)]) < 0.06);
    try testing.expect(@sqrt(f.sigma2[enemyGroup(2, 2)]) < 0.06);
    // 12 draws per role: the realised sd varies, so check the mean over roles
    var m: f64 = 0;
    for (g_main..g_ally) |g| m += @sqrt(f.sigma2[g]) / n_role;
    try testing.expectApproxEqAbs(0.2, m, 0.05);
}

test "gaussian: planted enemy block recovered with its noise" {
    const gpa = testing.allocator;
    const planted = enemyGroup(1, 3);
    const games = try synth(gpa, .gaussian, 20_000, 10, 0.3, planted, 0.2, 3);
    defer gpa.free(games);
    var p = try build(gpa, .gaussian, Variant.mains().with(planted).with(enemyGroup(3, 1)), games);
    defer p.deinit(gpa);
    var f = try fit(gpa, &p, .{}, null, null);
    defer f.deinit(gpa);
    try testing.expectApproxEqAbs(0.2, @sqrt(f.sigma2[planted]), 0.04);
    try testing.expect(@sqrt(f.sigma2[enemyGroup(3, 1)]) < 0.05);
    try testing.expectApproxEqAbs(1.0, f.noise, 0.05);
}

test "antisymmetric: swapping sides negates the prediction beyond the side term" {
    const gpa = testing.allocator;
    const games = try synth(gpa, .logistic, 5_000, 8, 0.2, enemyGroup(0, 0), 0.2, 11);
    defer gpa.free(games);
    var p = try build(gpa, .logistic, Variant.all(), games);
    defer p.deinit(gpa);
    var f = try fit(gpa, &p, .{ .outer = 5 }, null, null);
    defer f.deinit(gpa);
    var g = games[0];
    const a = predict(&p, &f, &g) - f.theta[0];
    const blue = g.teams[0];
    g.teams[0] = g.teams[1];
    g.teams[1] = blue;
    const b = predict(&p, &f, &g) - f.theta[0];
    try testing.expectApproxEqAbs(a, -b, 1e-9);
}

test "group names" {
    var buf: [64]u8 = undefined;
    try testing.expectEqualStrings("ally jungle-middle", groupName(&buf, allyGroup(1, 2)));
    try testing.expectEqualStrings("bottom vs their support", groupName(&buf, enemyGroup(3, 4)));
    try testing.expectEqualStrings("champion support", groupName(&buf, g_main + 4));
    try testing.expectEqual(g_offset, enemyGroup(4, 4) + 1);
    try testing.expectEqualStrings("offset support", groupName(&buf, n_groups - 1));
    const al = groupRoles(allyGroup(1, 2));
    try testing.expect(al.ally and al.r == 1 and al.q == 2);
    const en = groupRoles(enemyGroup(3, 4));
    try testing.expect(!en.ally and en.r == 3 and en.q == 4);
}

test "planted pair sd: gaussian recovered at 6 games per cell, logistic biased low (Laplace)" {
    // docs/model.md "Effects and the CPU model": why win pair sds are lower bounds
    const gpa = testing.allocator;
    const planted = allyGroup(3, 4);
    var ratio: [2]f64 = undefined;
    for ([_]Kind{ .gaussian, .logistic }, [_]f64{ 0.3, 0.15 }, &ratio) |kind, s_pair, *out| {
        const games = try synth(gpa, kind, 20_000, 80, 0.15, planted, s_pair, 100);
        defer gpa.free(games);
        var p = try build(gpa, kind, Variant.mains().with(planted), games);
        defer p.deinit(gpa);
        var f = try fit(gpa, &p, .{}, null, null);
        defer f.deinit(gpa);
        out.* = @sqrt(f.sigma2[planted]) / s_pair;
    }
    try testing.expectApproxEqAbs(1.0, ratio[0], 0.15);
    try testing.expect(ratio[1] < 0.5);
}

test "calibration recovers a thin planted pair block on win" {
    const gpa = testing.allocator;
    const planted = allyGroup(3, 4);
    const games = try synth(gpa, .logistic, 20_000, 40, 0.15, planted, 0.15, 7);
    defer gpa.free(games);
    var p = try build(gpa, .logistic, Variant.mains().with(planted).with(allyGroup(0, 1)), games);
    defer p.deinit(gpa);
    var f = try fit(gpa, &p, quick, null, null);
    defer f.deinit(gpa);
    const cal = try calibrate(gpa, testing.io, &p, &f, quick, 4, 5, 1);
    // Raw ~0.67x at 25 games per cell; calibrated within ~20% of 0.15, the empty block ~0
    try testing.expect(@sqrt(f.sigma2[planted]) < 0.12);
    try testing.expectApproxEqAbs(0.15, @sqrt(cal.sigma2[planted]), 0.03);
    try testing.expect(@sqrt(cal.sigma2[allyGroup(0, 1)]) < 0.04);
    var m: f64 = 0;
    for (g_main..g_ally) |g| m += @sqrt(cal.sigma2[g]) / n_role;
    try testing.expectApproxEqAbs(0.15, m, 0.04);
}

test "identified matchups: a planted matchup's sd comes back as the block sd" {
    const gpa = testing.allocator;
    // Crossed: synth plants cell(1 vs 3) only, so the matchup sd is 0.2
    const cross = try synth(gpa, .gaussian, 20_000, 10, 0.3, enemyGroup(1, 3), 0.2, 3);
    defer gpa.free(cross);
    var p = try build(gpa, .gaussian, Variant.mains().matchupGroups(), cross);
    defer p.deinit(gpa);
    var f = try fit(gpa, &p, quick, null, null);
    defer f.deinit(gpa);
    try testing.expectApproxEqAbs(0.2, @sqrt(f.sigma2[enemyGroup(1, 3)]), 0.04);
    try testing.expect(@sqrt(f.sigma2[enemyGroup(1, 1)]) < 0.05);
    try testing.expectEqual(0, p.param_start[enemyGroup(3, 1) + 1] - p.param_start[enemyGroup(3, 1)]);
    // Same role: synth plants cell(a, b) and cell(b, a) independently, a matchup of sd
    // 0.2 sqrt 2 as one signed cell
    const same = try synth(gpa, .gaussian, 20_000, 10, 0.3, enemyGroup(2, 2), 0.2, 4);
    defer gpa.free(same);
    var q = try build(gpa, .gaussian, Variant.mains().matchupGroups(), same);
    defer q.deinit(gpa);
    var g = try fit(gpa, &q, quick, null, null);
    defer g.deinit(gpa);
    try testing.expectApproxEqAbs(0.2 * @sqrt(2.0), @sqrt(g.sigma2[enemyGroup(2, 2)]), 0.05);
    // 10 champions: 45 unordered pairs
    try testing.expectEqual(45, q.param_start[enemyGroup(2, 2) + 1] - q.param_start[enemyGroup(2, 2)]);
}

test "patch offsets: a shift planted on flagged games comes back, unflagged games add none" {
    const gpa = testing.allocator;
    var rng: std.Random.DefaultPrng = .init(21);
    const rnd = rng.random();
    var mains: [n_role][8]f64 = undefined;
    for (&mains) |*m| for (m) |*x| {
        x.* = rnd.floatNorm(f64) * 0.2;
    };
    // Odd games are the new patch, where top champion 1 gains 0.6 logit
    const games = try gpa.alloc(GameIn, 40_000);
    defer gpa.free(games);
    for (games, 0..) |*g, i| {
        g.* = .{ .teams = undefined, .platform = 0, .y = 0, .offset = i % 2 == 1 };
        var eta: f64 = 0.05;
        for (0..2) |s| for (0..n_role) |r| {
            const c = rnd.uintLessThan(u32, 8);
            g.teams[s][r] = @intCast(1 + r * 1000 + c);
            const sign: f64 = if (s == 0) 1 else -1;
            eta += sign * mains[r][c];
            if (g.offset and r == 0 and c == 0) eta += sign * 0.6;
        };
        g.y = if (rnd.float(f64) < sigmoid(eta)) 1 else 0;
    }
    var p = try build(gpa, .logistic, Variant.mains().withOffsets(), games);
    defer p.deinit(gpa);
    var f = try fit(gpa, &p, quick, null, null);
    defer f.deinit(gpa);
    const j = p.keys.get(key(g_offset, 1, 0)).?;
    try testing.expectApproxEqAbs(0.6, f.theta[j], 0.15);
    // A role's strengths are known up to a constant (blue minus red): centred
    var centre: f64 = 0;
    for (mains[0]) |x| centre += x / 8;
    try testing.expectApproxEqAbs(mains[0][0] - centre, f.theta[p.keys.get(key(g_main, 1, 0)).?], 0.1);
    var other: f64 = 0;
    for (p.param_start[g_offset]..p.n_params()) |k| {
        if (k != j) other = @max(other, @abs(f.theta[k]));
    }
    try testing.expect(other < 0.15);
    // Off the flagged games the offset doesn't apply
    var g = games[0];
    g.teams[0][0] = 1;
    g.teams[1][0] = 2;
    const off = predict(&p, &f, &g);
    g.offset = true;
    const red = f.theta[p.keys.get(key(g_offset, 2, 0)).?];
    // Plus the other roles' offsets, shrunk to ~0
    try testing.expectApproxEqAbs(f.theta[j] - red, predict(&p, &f, &g) - off, 1e-3);
    // No flagged game: no offset cells
    for (games) |*x| x.offset = false;
    var q = try build(gpa, .logistic, Variant.mains().withOffsets(), games);
    defer q.deinit(gpa);
    try testing.expectEqual(q.param_start[g_offset], q.n_params());
}

test "prior mean and scale: cells without data stay at the mean, a looser cell moves further" {
    const gpa = testing.allocator;
    const games = try synth(gpa, .logistic, 6_000, 8, 0.4, allyGroup(0, 1), 0, 9);
    defer gpa.free(games);
    var p = try build(gpa, .logistic, Variant.mains(), games);
    defer p.deinit(gpa);
    const np = p.n_params();
    const mean = try gpa.alloc(f64, np);
    defer gpa.free(mean);
    @memset(mean, 0.3);
    const zero = try gpa.alloc(f32, games.len);
    defer gpa.free(zero);
    @memset(zero, 0);
    var held = try fit(gpa, &p, .{ .outer = 3, .prior_mean = mean }, zero, null);
    defer held.deinit(gpa);
    for (held.theta) |t| try testing.expectApproxEqAbs(0.3, t, 1e-9);

    const scale = try gpa.alloc(f64, np);
    defer gpa.free(scale);
    @memset(scale, 1);
    const j = p.param_start[g_main];
    scale[j] = 100;
    const tight: Config = .{ .estimate = false, .sigma2_init = 0.0005 };
    var plain = try fit(gpa, &p, tight, null, null);
    defer plain.deinit(gpa);
    var cfg = tight;
    cfg.prior_scale = scale;
    var loose = try fit(gpa, &p, cfg, null, null);
    defer loose.deinit(gpa);
    try testing.expect(@abs(loose.theta[j]) > 1.5 * @abs(plain.theta[j]));
}

test "kit classes: one per distinct tag string, in sorted order" {
    const gpa = testing.allocator;
    const k = try KitClass.fromTags(gpa, &.{ 1, 2, 3, 4 }, &.{ "Tank", "Fighter,Tank", "Tank", "Mage" });
    defer gpa.free(k);
    try testing.expectEqual(2, k[0].class);
    try testing.expectEqual(0, k[1].class);
    try testing.expectEqual(2, k[2].class);
    try testing.expectEqual(1, k[3].class);
}

test "parents: counters planted in every slot reach a slot the pair never met in" {
    const gpa = testing.allocator;
    var rng: std.Random.DefaultPrng = .init(5);
    const rnd = rng.random();
    // 14 flex champions, 10 a game in any roles; champion a beats b by d[a][b] wherever
    // they meet as enemies (sd 0.3, 1 beats 2 by 0.5), but 1 and 2 never meet top vs
    // jungle. (With every champion in every game, d would be champion strength only)
    var d: [15][15]f64 = @splat(@splat(0));
    for (1..15) |a| for (a + 1..15) |b| {
        d[a][b] = rnd.floatNorm(f64) * 0.3;
        d[b][a] = -d[a][b];
    };
    d[1][2] = 0.5;
    d[2][1] = -0.5;
    const games = try gpa.alloc(GameIn, 40_000);
    defer gpa.free(games);
    for (games) |*g| {
        g.* = .{ .teams = undefined, .platform = 0, .y = 0 };
        while (true) {
            var pick: [14]u32 = undefined;
            for (&pick, 0..) |*x, i| x.* = @intCast(1 + i);
            rnd.shuffle(u32, &pick);
            for (0..2) |s| for (0..n_role) |r| {
                g.teams[s][r] = pick[s * n_role + r];
            };
            const t = g.teams;
            const top_jg = (t[0][0] == 1 and t[1][1] == 2) or (t[0][0] == 2 and t[1][1] == 1) or
                (t[1][0] == 1 and t[0][1] == 2) or (t[1][0] == 2 and t[0][1] == 1);
            if (!top_jg) break;
        }
        var eta: f64 = 0;
        for (g.teams[0]) |a| for (g.teams[1]) |b| {
            eta += d[a][b];
        };
        g.y = if (rnd.float(f64) < sigmoid(eta)) 1 else 0;
    }
    var p = try build(gpa, .logistic, Variant.mains().matchupGroups(), games);
    defer p.deinit(gpa);
    try testing.expect(p.keys.get(key(enemyGroup(0, 1), 1, 2)) == null);
    var classes: [14]KitClass = undefined;
    for (&classes, 0..) |*c, i| c.* = .{ .id = @intCast(1 + i), .class = 0 };
    try p.addParents(gpa, &classes);
    var f = try fit(gpa, &p, quick, null, null);
    defer f.deinit(gpa);
    // The top vs jungle cell alone: 1 against 2 there, from the top side
    const v = p.parents.?.value(f.parent, enemyGroup(0, 1), 1, 2);
    try testing.expect(v > 0.2 and v < 0.7);
    // Reversed roles read the same parent with the sign of the lower id's side
    try testing.expectApproxEqAbs(-v, p.parents.?.value(f.parent, enemyGroup(0, 1), 2, 1), 1e-12);
}
