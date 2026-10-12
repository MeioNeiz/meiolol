//! meiolol-3c's additive team model (3c-team in src/outcomes.zig) as a candidate, the
//! baseline campaigns start from. Each continuous outcome is standardised per role, then
//! groups of effects are fitted in turn on the residual of the others (backfitting, 12
//! passes), each shrunk toward 0 with a prior strength from the method of moments per
//! group and role: platform, own champion, lane opponent, bot lane partners, junglers,
//! the rest of both teams. Win: no opinion (scored as the baseline)

const std = @import("std");
const api = @import("api");

pub const scope: api.Scope = .champ_select;

const passes = 12;
/// Cells with fewer games are left out of the spread estimates
const eb_min_games = 10;
/// Fewer cells in a role and the group is off for it (effects 0)
const eb_min_cells = 20;
const n_role = 5;
/// api.Game.platform is a u8 index
const n_platform = 256;

const Group = enum { platform, champ, lane, duo_enemy, duo_ally, jungle_enemy, jungle_ally, rest_enemy, rest_ally };
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
    champ: u16,
    ally: [n_role]u16,
    enemy: [n_role]u16,
};

/// Cell layouts, role first so a cell's role is cell / perRole. The last champion index
/// stands for every champion unseen in training: its cells stay 0
const Space = struct {
    champs: u32,

    fn perRole(s: Space, g: Group) u32 {
        const c = s.champs;
        return switch (g) {
            .platform => n_platform,
            .champ => c,
            .lane => c * c,
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
            .lane => out[0] = own * c + r.enemy[role],
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
    space: Space = .{ .champs = 0 },
    /// Per outcome; null for win
    fits: [api.outcome_count]?Fit = @splat(null),
};

fn champIndex(m: *const Model, id: u32) u16 {
    return m.index.get(id) orelse @intCast(m.space.champs - 1);
}

fn row(m: *const Model, teams: [2][5]u32, side: u1, role: api.Role, platform: u8) Row {
    var r: Row = .{ .role = @backingInt(role), .platform = platform, .champ = 0, .ally = undefined, .enemy = undefined };
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
    m.space = .{ .champs = m.index.count() + 1 };

    const rs = try gpa.alloc(Row, train.rows.len);
    defer gpa.free(rs);
    for (rs, train.rows) |*r, tr| {
        const g = train.games[tr.game];
        r.* = row(&m, g.teams, tr.side, tr.role, g.platform);
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
        var f: Fit = .{ .mean = undefined, .sd = undefined, .effects = undefined };
        for (0..n_role) |ri| {
            f.mean[ri] = sum[ri] / @max(count[ri], 1);
            f.sd[ri] = @sqrt(@max(sum_sq[ri] / @max(count[ri], 1) - f.mean[ri] * f.mean[ri], 1e-9));
        }
        for (train.rows, rs, z) |tr, r, *x| x.* = @floatCast((tr.y[k] - f.mean[r.role]) / f.sd[r.role]);
        f.effects = try backfit(gpa, m.space, rs, z);
        m.fits[k] = f;
    }
    return m;
}

fn backfit(gpa: std.mem.Allocator, s: Space, rs: []const Row, z: []const f32) ![n_group][]f32 {
    var effects: [n_group][]f32 = undefined;
    var made: usize = 0;
    errdefer for (effects[0..made]) |b| gpa.free(b);
    for (&effects, 0..) |*b, gi| {
        b.* = try gpa.alloc(f32, n_role * s.perRole(@fromBackingInt(@as(u4, @intCast(gi)))));
        @memset(b.*, 0);
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
        const b = effects[gi];
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
        try old.resize(gpa, b.len);
        @memcpy(old.items, b);
        for (0..n_role) |ri| {
            const lo = ri * per_role;
            const k: f64 = if (g == .platform) 1 else blk: {
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
    return effects;
}

pub fn predict(m: *const Model, q: *const api.Query) api.Prediction {
    var out = api.no_opinion;
    const r = row(m, q.teams, q.side, q.role, q.platform);
    for (m.fits, &out) |f, *o| if (f) |x| {
        o.* = @floatCast(x.predict(m.space, r));
    };
    return out;
}

pub fn deinit(m: *Model, gpa: std.mem.Allocator) void {
    for (&m.fits) |*f| if (f.*) |x| {
        for (x.effects) |b| gpa.free(b);
        f.* = null;
    };
    m.index.deinit(gpa);
}
