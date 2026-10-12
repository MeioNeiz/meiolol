//! meiolol-b0's 3c-team2 (src/outcomes.zig) as a candidate, the start for early-outcome
//! campaigns: src/lab/cand/team plus the lane opponent's own effect (fitted before the
//! pair cell) and role x patch. Each continuous outcome is standardised per role, then
//! groups of effects are fitted in turn on the residual of the others (backfitting, 12
//! passes), each shrunk toward 0 with a prior strength from the method of moments per
//! group and role (platform and patch unshrunk). Win: no opinion (scored as the baseline)

const std = @import("std");
const api = @import("api");

pub const scope: api.Scope = .champ_select;
pub const name = "3c-team2";

const passes = 12;
/// Cells with fewer games are left out of the spread estimates
const eb_min_games = 10;
/// Fewer cells in a role and the group is off for it (effects 0)
const eb_min_cells = 20;
const n_role = 5;
/// api.Game.platform is a u8 index
const n_platform = 256;

/// Backfitting order, as outcomes.zig's team2_groups
const Group = enum { platform, champ, lane_enemy, lane, duo_enemy, duo_ally, jungle_enemy, jungle_ally, rest_enemy, rest_ally, patch };
const n_group = @typeInfo(Group).@"enum".field_names.len;
const max_terms = n_role - 1;

/// How another role relates to ours, for the team groups
const Relation = enum { duo, jungle, rest };

fn relation(role: usize, other: usize) Relation {
    const bot = @backingInt(api.Role.bottom);
    const sup = @backingInt(api.Role.utility);
    if ((role == bot and other == sup) or (role == sup and other == bot)) return .duo;
    if (other == @backingInt(api.Role.jungle)) return .jungle;
    return .rest;
}

/// One player in one game, champions as dense indices
const Row = struct {
    role: u8,
    platform: u8,
    patch: u16,
    champ: u16,
    ally: [n_role]u16,
    enemy: [n_role]u16,
};

/// Cell layouts, role first so a cell's role is cell / perRole. The last champion and
/// patch indices stand for every one unseen in training: their cells stay 0
const Space = struct {
    champs: u32,
    patches: u32,

    fn perRole(s: Space, g: Group) u32 {
        const c = s.champs;
        return switch (g) {
            .platform => n_platform,
            .champ, .lane_enemy => c,
            .lane => c * c,
            .patch => s.patches,
            .duo_enemy, .duo_ally, .jungle_enemy, .jungle_ally, .rest_enemy, .rest_ally => n_role * c,
        };
    }

    fn terms(s: Space, g: Group, r: Row, out: *[max_terms]u32) usize {
        const c = s.champs;
        const role: u32 = r.role;
        const own = role * c + r.champ;
        switch (g) {
            .platform => out[0] = role * n_platform + r.platform,
            .champ => out[0] = own,
            .lane_enemy => out[0] = role * c + r.enemy[role],
            .lane => out[0] = own * c + r.enemy[role],
            .patch => out[0] = role * s.patches + r.patch,
            else => {
                const want: Relation = switch (g) {
                    .duo_enemy, .duo_ally => .duo,
                    .jungle_enemy, .jungle_ally => .jungle,
                    else => .rest,
                };
                const enemy = g == .duo_enemy or g == .jungle_enemy or g == .rest_enemy;
                const side = if (enemy) r.enemy else r.ally;
                var n: usize = 0;
                for (0..n_role) |o| {
                    if (o == role or relation(role, o) != want) continue;
                    out[n] = (role * n_role + @as(u32, @intCast(o))) * c + side[o];
                    n += 1;
                }
                return n;
            },
        }
        return 1;
    }
};

const Fit = struct {
    mean: [n_role]f64,
    sd: [n_role]f64,
    effects: [n_group][]f32,
    /// Training rows per cell, and per group the residual variance and per role the
    /// prior strength of the last pass (for effect intervals)
    games: [n_group][]u32,
    sigma2: [n_group]f64,
    k: [n_group][n_role]f64,

    fn predict(f: *const Fit, s: Space, r: Row) f64 {
        var sum: f64 = 0;
        var buf: [max_terms]u32 = undefined;
        for (f.effects, 0..) |b, gi| {
            const n = s.terms(@fromBackingInt(@as(u4, @intCast(gi))), r, &buf);
            for (buf[0..n]) |cell| sum += b[cell];
        }
        return f.mean[r.role] + f.sd[r.role] * sum;
    }
};

pub const Model = struct {
    index: std.AutoHashMapUnmanaged(u32, u16) = .empty,
    patch_index: std.AutoArrayHashMapUnmanaged(u32, void) = .empty,
    space: Space = .{ .champs = 0, .patches = 0 },
    /// Per outcome; null for win
    fits: [api.outcome_count]?Fit = @splat(null),
};

fn champIndex(m: *const Model, id: u32) u16 {
    return m.index.get(id) orelse @intCast(m.space.champs - 1);
}

fn patchIndex(m: *const Model, patch: u32) u16 {
    return @intCast(m.patch_index.getIndex(patch) orelse m.space.patches - 1);
}

fn row(m: *const Model, teams: [2][5]u32, side: u1, role: api.Role, platform: u8, patch: u32) Row {
    var r: Row = .{ .role = @backingInt(role), .platform = platform, .patch = patchIndex(m, patch), .champ = 0, .ally = undefined, .enemy = undefined };
    for (0..n_role) |o| {
        r.ally[o] = champIndex(m, teams[side][o]);
        r.enemy[o] = champIndex(m, teams[1 - side][o]);
    }
    r.champ = r.ally[r.role];
    return r;
}

pub fn fit(gpa: std.mem.Allocator, train: *const api.Train, _: api.Options) !Model {
    var m: Model = .{};
    errdefer deinit(&m, gpa);
    for (train.games) |g| for (g.teams) |team| for (team) |id| {
        const e = try m.index.getOrPut(gpa, id);
        if (!e.found_existing) e.value_ptr.* = @intCast(m.index.count() - 1);
    };
    for (train.games) |g| try m.patch_index.put(gpa, g.patch, {});
    m.space = .{ .champs = m.index.count() + 1, .patches = @intCast(m.patch_index.count() + 1) };

    const rs = try gpa.alloc(Row, train.rows.len);
    defer gpa.free(rs);
    for (rs, train.rows) |*r, tr| {
        const g = train.games[tr.game];
        r.* = row(&m, g.teams, tr.side, tr.role, g.platform, g.patch);
    }
    const z = try gpa.alloc(f32, rs.len);
    defer gpa.free(z);
    for (0..api.outcome_count) |k| {
        if (k == api.outcomeIndex(.win)) continue;
        // Standardise per role on train
        var sum: [n_role]f64 = @splat(0);
        var sum_sq: [n_role]f64 = @splat(0);
        var count: [n_role]f64 = @splat(0);
        for (train.rows, rs) |tr, r| {
            const y = tr.y[k];
            if (std.math.isNan(y)) continue;
            sum[r.role] += y;
            sum_sq[r.role] += y * y;
            count[r.role] += 1;
        }
        var f: Fit = .{ .mean = undefined, .sd = undefined, .effects = undefined, .games = undefined, .sigma2 = undefined, .k = undefined };
        for (0..n_role) |ri| {
            f.mean[ri] = sum[ri] / @max(count[ri], 1);
            f.sd[ri] = @sqrt(@max(sum_sq[ri] / @max(count[ri], 1) - f.mean[ri] * f.mean[ri], 1e-9));
        }
        for (train.rows, rs, z) |tr, r, *x| x.* = @floatCast((tr.y[k] - f.mean[r.role]) / f.sd[r.role]);
        try backfit(gpa, m.space, rs, z, &f);
        m.fits[k] = f;
    }
    return m;
}

fn backfit(gpa: std.mem.Allocator, s: Space, rs: []const Row, z: []const f32, f: *Fit) !void {
    var made: usize = 0;
    errdefer for (f.effects[0..made], f.games[0..made]) |b, n| {
        gpa.free(b);
        gpa.free(n);
    };
    for (&f.effects, &f.games, 0..) |*b, *n, gi| {
        const len = n_role * s.perRole(@fromBackingInt(@as(u4, @intCast(gi))));
        b.* = try gpa.alloc(f32, len);
        @memset(b.*, 0);
        n.* = gpa.alloc(u32, len) catch |err| {
            gpa.free(b.*);
            return err;
        };
        @memset(n.*, 0);
        made += 1;
    }
    const res = try gpa.alloc(f32, rs.len);
    defer gpa.free(res);
    @memcpy(res, z);
    var sxr: std.ArrayList(f64) = .empty;
    defer sxr.deinit(gpa);
    var sxx: std.ArrayList(f64) = .empty;
    defer sxx.deinit(gpa);
    var old: std.ArrayList(f32) = .empty;
    defer old.deinit(gpa);
    var buf: [max_terms]u32 = undefined;

    for (0..passes) |_| for (0..n_group) |gi| {
        const g: Group = @fromBackingInt(@as(u4, @intCast(gi)));
        const b = f.effects[gi];
        const per_role = s.perRole(g);
        try sxr.resize(gpa, b.len);
        try sxx.resize(gpa, b.len);
        @memset(sxr.items, 0);
        @memset(sxx.items, 0);
        var sum_sq: f64 = 0;
        var n_rows: f64 = 0;
        for (rs, res) |r, e| {
            if (std.math.isNan(e)) continue;
            sum_sq += e * e;
            n_rows += 1;
            const n = s.terms(g, r, &buf);
            for (buf[0..n]) |cell| {
                sxr.items[cell] += e + b[cell];
                sxx.items[cell] += 1;
            }
        }
        const sigma2 = sum_sq / @max(n_rows, 1);
        f.sigma2[gi] = sigma2;
        for (f.games[gi], sxx.items) |*n, xx| n.* = @intFromFloat(xx);
        try old.resize(gpa, b.len);
        @memcpy(old.items, b);
        for (0..n_role) |ri| {
            const lo = ri * per_role;
            // Few cells, many games each: left unshrunk
            const k: f64 = if (g == .platform or g == .patch) 1 else blk: {
                var cells: f64 = 0;
                var excess: f64 = 0;
                for (sxr.items[lo..][0..per_role], sxx.items[lo..][0..per_role]) |xr, xx| {
                    if (xx < eb_min_games) continue;
                    const est = xr / xx;
                    cells += 1;
                    excess += est * est - sigma2 / xx;
                }
                if (cells < eb_min_cells or excess <= 0) break :blk std.math.inf(f64);
                break :blk sigma2 / (excess / cells);
            };
            f.k[gi][ri] = k;
            for (b[lo..][0..per_role], sxr.items[lo..][0..per_role], sxx.items[lo..][0..per_role]) |*x, xr, xx| {
                x.* = if (std.math.isInf(k) or xx == 0) 0 else @floatCast(xr / (xx + k));
            }
        }
        for (rs, res) |r, *e| {
            if (std.math.isNan(e.*)) continue;
            const n = s.terms(g, r, &buf);
            for (buf[0..n]) |cell| e.* -= b[cell] - old.items[cell];
        }
    };
}

pub fn predict(m: *const Model, q: *const api.Query) api.Prediction {
    var out = api.no_opinion;
    const r = row(m, q.teams, q.side, q.role, q.platform, q.patch);
    for (m.fits, &out) |f, *o| if (f) |x| {
        o.* = @floatCast(x.predict(m.space, r));
    };
    return out;
}

pub fn deinit(m: *Model, gpa: std.mem.Allocator) void {
    for (&m.fits) |*f| if (f.*) |x| {
        for (x.effects, x.games) |b, n| {
            gpa.free(b);
            gpa.free(n);
        }
        f.* = null;
    };
    m.index.deinit(gpa);
    m.patch_index.deinit(gpa);
}

/// Cells with fewer training rows stay out of effect tables
const table_min_games = 30;
const table_side = 10;

/// Per group, the 10 strongest and 10 weakest cells with enough games, in the target's
/// units (each role's sd); intervals are the shrunk estimate's posterior, sigma/sqrt(n+k)
pub fn effects(m: *const Model, arena: std.mem.Allocator, target: api.Outcome) ![]const api.Effects {
    const f = m.fits[api.outcomeIndex(target)] orelse return &.{};
    const ids = try arena.alloc(u32, m.space.champs);
    @memset(ids, 0);
    var it = m.index.iterator();
    while (it.next()) |e| ids[e.value_ptr.*] = e.key_ptr.*;
    const unseen = m.space.champs - 1;
    const unit = switch (target) {
        .gold14, .lanediff14 => "gold",
        .cs10 => "CS",
        .deaths15 => "deaths",
        .first_item => "min",
        .win => unreachable,
    };

    var out: std.ArrayList(api.Effects) = .empty;
    for (0..n_group) |gi| {
        const g: Group = @fromBackingInt(@as(u4, @intCast(gi)));
        if (g == .platform) continue;
        const per_role = m.space.perRole(g);
        var cells: std.ArrayList(api.Effect) = .empty;
        for (f.effects[gi], f.games[gi], 0..) |b, n, cell| {
            if (n < table_min_games or b == 0) continue;
            const role = cell / per_role;
            const k = f.k[gi][role];
            if (std.math.isInf(k)) continue;
            // Space.terms: within a role, champ and lane_enemy are a champion, lane is
            // own * c + enemy, patch a patch; the team groups are other role * c + their
            // champion
            const within: u32 = @intCast(cell % per_role);
            if (g == .patch and within == m.space.patches - 1) continue;
            const c = m.space.champs;
            const hi = within / c;
            const lo = within % c;
            if (g != .patch and (lo == unseen or (g == .lane and hi == unseen))) continue;
            const label = switch (g) {
                .champ => try std.fmt.allocPrint(arena, "#{d} {t}", .{ ids[lo], roleOf(role) }),
                .lane_enemy => try std.fmt.allocPrint(arena, "{t} against #{d}", .{ roleOf(role), ids[lo] }),
                .patch => blk: {
                    const p = m.patch_index.keys()[within];
                    break :blk try std.fmt.allocPrint(arena, "{t} on patch {d}.{d}", .{ roleOf(role), p / 1000, p % 1000 });
                },
                .lane => try std.fmt.allocPrint(arena, "#{d} vs #{d} {t}", .{ ids[hi], ids[lo], roleOf(role) }),
                else => blk: {
                    const side = if (g == .duo_enemy or g == .jungle_enemy or g == .rest_enemy) "against" else "with";
                    break :blk try std.fmt.allocPrint(arena, "{t} {s} #{d} {t}", .{ roleOf(role), side, ids[lo], roleOf(hi) });
                },
            };
            const sd = f.sd[role];
            try cells.append(arena, .{
                .label = label,
                .effect = b * sd,
                .ci = 1.96 * @sqrt(f.sigma2[gi] / (@as(f64, @floatFromInt(n)) + k)) * sd,
                .n = n,
            });
        }
        if (cells.items.len == 0) continue;
        std.mem.sort(api.Effect, cells.items, {}, struct {
            fn lt(_: void, a: api.Effect, b: api.Effect) bool {
                return a.effect > b.effect;
            }
        }.lt);
        const all = cells.items;
        const rows = if (g == .patch or all.len <= 2 * table_side) all else blk: {
            const r = try arena.alloc(api.Effect, 2 * table_side);
            @memcpy(r[0..table_side], all[0..table_side]);
            @memcpy(r[table_side..], all[all.len - table_side ..]);
            break :blk r;
        };
        try out.append(arena, .{
            .name = @tagName(g),
            .title = switch (g) {
                .champ => "Own champion, top and bottom 10",
                .lane_enemy => "Enemy laner's champion, whoever you play, top and bottom 10",
                .patch => "Patch, per role (beyond the platform mix)",
                .lane => "Lane matchup (yours vs the enemy laner), top and bottom 10",
                .duo_enemy => "Enemy bot lane partner, top and bottom 10",
                .duo_ally => "Own bot lane partner, top and bottom 10",
                .jungle_enemy => "Enemy jungler, top and bottom 10",
                .jungle_ally => "Own jungler, top and bottom 10",
                .rest_enemy => "Rest of the enemy team, top and bottom 10",
                .rest_ally => "Rest of own team, top and bottom 10",
                .platform => unreachable,
            },
            .unit = unit,
            .higher = try std.fmt.allocPrint(arena, "more {t} for the player in that role, other terms held", .{target}),
            .rows = rows,
        });
    }
    return out.items;
}

fn roleOf(r: usize) api.Role {
    return @fromBackingInt(@as(u3, @intCast(r)));
}

// ---------- lane export (src/lab/lane.zig, docs/model.md "Lane model file") ----------

/// Early outcomes the lane export carries, in this order everywhere
pub const lane_outcomes = [_]api.Outcome{ .gold14, .lanediff14, .cs10, .deaths15 };
const n_lane = lane_outcomes.len;

/// One champion-role term (enemy 0) or lane pair cell, in the outcome's units; sd is the
/// shrunk estimate's posterior, sigma/sqrt(n+k); n training rows (gold14's)
pub const LaneTerm = struct {
    champion: u32,
    enemy: u32 = 0,
    role: u8,
    n: u32,
    b: [n_lane]f64,
    sd: [n_lane]f64,
};

pub const LaneExport = struct {
    patch: u32,
    /// Role mean plus the platform's and the newest patch's offsets, per outcome and role
    intercept: [n_lane][n_role]f64,
    /// The other eight slots at their average: per row mean of the team groups' terms
    others: [n_lane][n_role]f64,
    /// Typical game-to-game spread around the expectation (residual sd)
    spread: [n_lane][n_role]f64,
    champ: []const LaneTerm,
    /// The lane opponent's own effect, for the player in that role
    enemy: []const LaneTerm,
    pairs: []const LaneTerm,
};

/// value = intercept + others + champ(you) + enemy(opponent) + pair(you, opponent),
/// a missing term counting 0; the lane slot terms are exactly predict's
pub fn exportLane(m: *const Model, arena: std.mem.Allocator, platform: u8, min_pair_games: u32) !LaneExport {
    var fits: [n_lane]Fit = undefined;
    for (lane_outcomes, &fits) |o, *f| f.* = m.fits[api.outcomeIndex(o)] orelse return error.NoFit;
    const ids = try arena.alloc(u32, m.space.champs);
    @memset(ids, 0);
    var it = m.index.iterator();
    while (it.next()) |e| ids[e.value_ptr.*] = e.key_ptr.*;
    const unseen = m.space.champs - 1;
    var newest: u32 = 0;
    for (m.patch_index.keys()) |p| newest = @max(newest, p);
    const newest_ix = patchIndex(m, newest);

    var out: LaneExport = .{ .patch = newest, .intercept = undefined, .others = undefined, .spread = undefined, .champ = &.{}, .enemy = &.{}, .pairs = &.{} };
    const team_groups = [_]Group{ .duo_enemy, .duo_ally, .jungle_enemy, .jungle_ally, .rest_enemy, .rest_ally };
    for (fits, 0..) |f, oi| for (0..n_role) |ri| {
        const pf = f.effects[@backingInt(Group.platform)][ri * n_platform + platform];
        const pt = f.effects[@backingInt(Group.patch)][ri * m.space.patches + newest_ix];
        out.intercept[oi][ri] = f.mean[ri] + f.sd[ri] * (pf + pt);
        // Each row has one own-champion term: its cells' rows count the role's rows
        const champ_per = m.space.perRole(.champ);
        var rows_n: f64 = 0;
        for (f.games[@backingInt(Group.champ)][ri * champ_per ..][0..champ_per]) |n| rows_n += @floatFromInt(n);
        var sum: f64 = 0;
        for (team_groups) |g| {
            const per = m.space.perRole(g);
            const gi = @backingInt(g);
            for (f.effects[gi][ri * per ..][0..per], f.games[gi][ri * per ..][0..per]) |b, n| sum += b * @as(f64, @floatFromInt(n));
        }
        out.others[oi][ri] = if (rows_n > 0) f.sd[ri] * sum / rows_n else 0;
        // The last group's pass sees the residual of every other group
        out.spread[oi][ri] = f.sd[ri] * @sqrt(f.sigma2[n_group - 1]);
    };

    for ([_]Group{ .champ, .lane_enemy, .lane }) |g| {
        var terms: std.ArrayList(LaneTerm) = .empty;
        const gi = @backingInt(g);
        const per = m.space.perRole(g);
        const c = m.space.champs;
        for (fits[0].games[gi], 0..) |n, cell| {
            const min: u32 = if (g == .lane) min_pair_games else 1;
            if (n < min) continue;
            const role = cell / per;
            const within: u32 = @intCast(cell % per);
            const hi = within / c;
            const lo = within % c;
            if (lo == unseen or (g == .lane and hi == unseen)) continue;
            var t: LaneTerm = .{
                .champion = ids[if (g == .lane) hi else lo],
                .enemy = if (g == .lane) ids[lo] else 0,
                .role = @intCast(role),
                .n = n,
                .b = undefined,
                .sd = undefined,
            };
            for (fits, &t.b, &t.sd) |f, *b, *sd| {
                const k = f.k[gi][role];
                const nk: f64 = @floatFromInt(f.games[gi][cell]);
                b.* = f.effects[gi][cell] * f.sd[role];
                sd.* = if (std.math.isInf(k)) 0 else @sqrt(f.sigma2[gi] / (nk + k)) * f.sd[role];
            }
            try terms.append(arena, t);
        }
        switch (g) {
            .champ => out.champ = terms.items,
            .lane_enemy => out.enemy = terms.items,
            .lane => out.pairs = terms.items,
            else => unreachable,
        }
    }
    return out;
}

/// predict's value for a lane slot alone: the other eight slots unseen (their cells 0),
/// for checking exportLane against the model (lane.zig) with others = 0
pub fn laneOnly(m: *const Model, o: api.Outcome, role: api.Role, champion: u32, enemy: u32, platform: u8, patch: u32) f64 {
    var teams: [2][5]u32 = @splat(@splat(std.math.maxInt(u32)));
    teams[0][@backingInt(role)] = champion;
    teams[1][@backingInt(role)] = enemy;
    const r = row(m, teams, 0, role, platform, patch);
    const f = m.fits[api.outcomeIndex(o)].?;
    return f.predict(m.space, r);
}
