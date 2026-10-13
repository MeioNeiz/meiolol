//! Playstyle clusters from the first 14 minutes of the compact timeline (docs/model.md
//! "Playstyle clusters"). Per player: zone shares by phase (positions from minute 3, red
//! mirrored so everyone plays from blue) and action counts before 14:00, residualised
//! within role on champion-role and the 14:00 state (style beyond kit and beyond being
//! ahead), k-means per role. Value: win log loss over b0's state-conditioned model
//! (playstyle.zig) on the harness dev cut; `--final K` scores k = K once on test.
//! Use-time: the user's own style, post-game only.

const std = @import("std");
const store = @import("store");
const core = @import("core");
const rows = @import("rows.zig");
const harness = @import("harness.zig");
const protocol = @import("protocol.zig");
const fields = @import("fields.zig");
const analysis = @import("../analysis.zig");
const logreg = @import("../logreg.zig");
const playstyle = @import("../playstyle.zig");
const timeline = @import("../riot/timeline.zig");
const par = @import("../par.zig");

const Io = std.Io;
const Role = core.Role;
const log = std.log.scoped(.style);

pub const usage =
    \\  style SNAP OUT [--final K]      playstyle clusters per role from minutes 0-13
    \\                                  (lab/style.zig): value over b0's state model on
    \\                                  the dev cut for k = 3, 4, 6, 8; --final scores
    \\                                  k = K once on test. Report in OUT
    \\
;

const minute_ms = 60_000;
/// Style from frames and events before this minute; the state is read at it
const until_minute = 14;

pub const Zone = enum {
    own_base,
    enemy_base,
    top_own,
    top_enemy,
    mid_own,
    mid_enemy,
    bot_own,
    bot_enemy,
    river_top,
    river_bot,
    jungle_own_top,
    jungle_own_bot,
    jungle_enemy_top,
    jungle_enemy_bot,
};
const n_zone = @typeInfo(Zone).@"enum".field_names.len;

/// Summoner's Rift from blue's side (base bottom left). "own" is blue's half of the map
/// (x + y < 14800); top_side is the half above the base-to-base diagonal. Lane bands as
/// playstyle.zig's, which one position a minute makes rough anyway
pub fn zone(x: i32, y: i32) Zone {
    if (x < 4000 and y < 4000) return .own_base;
    if (x > 10800 and y > 10800) return .enemy_base;
    const own = x + y < 14800;
    const top_side = y > x;
    if ((x < 2600 and y > 4000) or (y > 12200 and x < 10800)) return if (own) .top_own else .top_enemy;
    if ((y < 2600 and x > 4000) or (x > 12200 and y < 10800)) return if (own) .bot_own else .bot_enemy;
    if (@abs(x - y) < 1800) return if (own) .mid_own else .mid_enemy;
    if (@abs(x + y - 14800) < 1400) return if (top_side) .river_top else .river_bot;
    if (own) return if (top_side) .jungle_own_top else .jungle_own_bot;
    return if (top_side) .jungle_enemy_top else .jungle_enemy_bot;
}

/// A red player's position as if they were blue: across the anti-diagonal x + y = 14800,
/// which swaps the bases and keeps top lane top
pub fn mirror(x: i32, y: i32) [2]i32 {
    return .{ 14800 - y, 14800 - x };
}

pub const Act = enum {
    /// mean distance between consecutive minute positions, thousands of units
    step,
    /// damage to champions, damage taken, thousands; crowd control dealt, seconds
    damage,
    taken,
    cc,
    lane_cs,
    jungle_cs,
    kills,
    deaths,
    assists,
    /// trinket, stealth and control wards placed
    wards,
    control_wards,
    ward_kills,
    plates,
    /// dragon, herald, grubs: killer or assist
    epics,
    /// minutes with a purchase from 1:30 on (a back, or shopping after a death)
    shops,
    /// minute of the first purchase from 1:30 on; 14 when none
    first_shop,
};
const n_act = @typeInfo(Act).@"enum".field_names.len;

/// Position frames: minutes 3-7, then 8-13
const phases = [_][2]u8{ .{ 3, 8 }, .{ 8, until_minute } };
const phase_names = [_][]const u8{ "early", "late" };
pub const n_sum = phases.len * n_zone + n_act;

fn act(a: Act) usize {
    return phases.len * n_zone + @backingInt(a);
}

pub fn sumName(buf: []u8, i: usize) []const u8 {
    if (i >= phases.len * n_zone) return @tagName(@as(Act, @fromBackingInt(@intCast(i - phases.len * n_zone))));
    const z: Zone = @fromBackingInt(@intCast(i % n_zone));
    return std.fmt.bufPrint(buf, "{s}.{t}", .{ phase_names[i / n_zone], z }) catch "?";
}

/// Style summary of every player, by participant id - 1. Needs frame `until_minute`
pub fn summary(t: timeline.Timeline) [10][n_sum]f32 {
    var out: [10][n_sum]f32 = @splat(@splat(0));
    for (&out, 0..) |*o, p| {
        const pid: u8 = @intCast(p + 1);
        var prev: ?[2]i32 = null;
        var dist: f32 = 0;
        var steps: f32 = 0;
        for (phases, 0..) |ph, k| {
            const n: f32 = @floatFromInt(ph[1] - ph[0]);
            for (t.frames[ph[0]..ph[1]]) |f| {
                const raw = [2]i32{ f.get(pid, .x), f.get(pid, .y) };
                const pos = if (p < 5) raw else mirror(raw[0], raw[1]);
                o[k * n_zone + @backingInt(zone(pos[0], pos[1]))] += 1 / n;
                if (prev) |q| {
                    dist += std.math.hypot(@as(f32, @floatFromInt(pos[0] - q[0])), @as(f32, @floatFromInt(pos[1] - q[1])));
                    steps += 1;
                }
                prev = pos;
            }
        }
        o[act(.step)] = dist / @max(steps, 1) / 1000;
        const f = t.frames[until_minute];
        o[act(.damage)] = @as(f32, @floatFromInt(f.get(pid, .damage_to_champions))) / 1000;
        o[act(.taken)] = @as(f32, @floatFromInt(f.get(pid, .damage_taken))) / 1000;
        o[act(.cc)] = @as(f32, @floatFromInt(f.get(pid, .cc_dealt_ms))) / 1000;
        o[act(.lane_cs)] = @floatFromInt(f.get(pid, .minions));
        o[act(.jungle_cs)] = @floatFromInt(f.get(pid, .jungle_minions));
        o[act(.first_shop)] = until_minute;
    }
    var shop_minute: [10]i64 = @splat(-1);
    for (t.events) |e| {
        if (e.t_ms >= until_minute * minute_ms) break;
        switch (e.data) {
            .champion_kill => |k| {
                if (k.killer >= 1 and k.killer <= 10) out[k.killer - 1][act(.kills)] += 1;
                if (k.victim >= 1 and k.victim <= 10) out[k.victim - 1][act(.deaths)] += 1;
                for (k.assists) |a| if (a >= 1 and a <= 10) {
                    out[a - 1][act(.assists)] += 1;
                };
            },
            .ward_placed => |wd| if (wd.participant >= 1 and wd.participant <= 10) {
                const o = &out[wd.participant - 1];
                const control = std.mem.eql(u8, wd.ward, "CONTROL_WARD");
                if (control or std.mem.eql(u8, wd.ward, "YELLOW_TRINKET") or
                    std.mem.eql(u8, wd.ward, "SIGHT_WARD") or std.mem.eql(u8, wd.ward, "BLUE_TRINKET"))
                {
                    o[act(.wards)] += 1;
                }
                if (control) o[act(.control_wards)] += 1;
            },
            .ward_kill => |wd| if (wd.participant >= 1 and wd.participant <= 10) {
                out[wd.participant - 1][act(.ward_kills)] += 1;
            },
            .turret_plate => |tp| if (tp.killer >= 1 and tp.killer <= 10) {
                out[tp.killer - 1][act(.plates)] += 1;
            },
            .elite_monster => |m| {
                if (m.killer >= 1 and m.killer <= 10) out[m.killer - 1][act(.epics)] += 1;
                for (m.assists) |a| if (a >= 1 and a <= 10) {
                    out[a - 1][act(.epics)] += 1;
                };
            },
            .item_purchased => |it| if (it.participant >= 1 and it.participant <= 10 and e.t_ms >= 90_000) {
                const p = it.participant - 1;
                const minute = @divFloor(e.t_ms, minute_ms);
                if (minute != shop_minute[p]) {
                    if (shop_minute[p] < 0) out[p][act(.first_shop)] = @as(f32, @floatFromInt(e.t_ms)) / minute_ms;
                    shop_minute[p] = minute;
                    out[p][act(.shops)] += 1;
                }
            },
            else => {},
        }
    }
    return out;
}

const n_b0 = playstyle.n_feat;
const n_pc = 10;
const ks = [_]u8{ 3, 4, 6, 8 };
const max_k = 8;
const n_state = 3;

const Seat = struct {
    game: u32,
    slot: u8,
    role: u3,
    cr: u32,
    won: bool,
    fit: bool,
    ok: bool = false,
    /// own side's team gold lead, team XP lead, lane gold lead at 14:00, thousands
    state: [n_state]f32 = @splat(0),
    /// b0's eight features, standardised per role on fit seats after loading
    b0: [n_b0]f32 = @splat(0),
    sum: [n_sum]f32 = @splat(0),
};

const Loaded = struct {
    seats: []Seat,
    match_ids: []const []const u8,
    n_cr: u32,
};

/// Ten seats per game with a timeline reaching 15:00, fit or scored in this phase, in
/// game order (paired intervals need rows grouped by game)
fn selectSeats(gpa: std.mem.Allocator, arena: std.mem.Allocator, d: *const rows.Data, c: harness.Cuts, phase: harness.Phase, want: *std.StringHashMapUnmanaged(u32)) !Loaded {
    const none = std.math.maxInt(u32);
    const by_game = try gpa.alloc([10]u32, d.games.len);
    defer gpa.free(by_game);
    @memset(by_game, @splat(none));
    for (d.rows, 0..) |r, i| if (r.slot < 10) {
        by_game[r.game][r.slot] = @intCast(i);
    };
    var cr_ids: std.AutoHashMapUnmanaged(u64, u32) = .empty;
    defer cr_ids.deinit(gpa);
    var seats: std.ArrayList(Seat) = .empty;
    var ids: std.ArrayList([]const u8) = .empty;
    for (d.games, by_game) |g, slots| {
        const fit = harness.visible(phase, c, g);
        if (!g.timeline15 or !(fit or harness.scored(phase, c, g))) continue;
        if (std.mem.indexOfScalar(u32, &slots, none) != null) continue;
        const game: u32 = @intCast(ids.items.len);
        try want.put(gpa, g.match_id, @intCast(seats.items.len));
        try ids.append(arena, g.match_id);
        for (slots, 0..) |ri, slot| {
            const r = d.rows[ri];
            const role: u3 = @intCast(@backingInt(r.role));
            const e = try cr_ids.getOrPut(gpa, (@as(u64, r.champion) << 3) | role);
            if (!e.found_existing) e.value_ptr.* = cr_ids.count() - 1;
            try seats.append(arena, .{
                .game = game,
                .slot = @intCast(slot),
                .role = role,
                .cr = e.value_ptr.*,
                .won = g.winner == r.side,
                .fit = fit,
            });
        }
    }
    return .{ .seats = seats.items, .match_ids = ids.items, .n_cr = cr_ids.count() };
}

const Batch = struct {
    gpa: std.mem.Allocator,
    bodies: []const []const u8,
    bases: []const u32,
    seats: []Seat,

    fn body(b: *const Batch, i: usize) !void {
        var arena: std.heap.ArenaAllocator = .init(b.gpa);
        defer arena.deinit();
        const a = arena.allocator();
        const raw = try store.raw.decompress(a, b.bodies[i]);
        const t = try timeline.decode(a, raw);
        if (!protocol.reached15Timeline(t) or t.participants != 10) return;
        const seats = b.seats[b.bases[i]..][0..10];
        var roles: [10]Role = undefined;
        for (&roles, seats) |*r, s| r.* = @fromBackingInt(s.role);
        const b0 = playstyle.features(t, roles);
        const sums = summary(t);
        const f = t.frames[until_minute];
        var gold: [2]f32 = @splat(0);
        var xp: [2]f32 = @splat(0);
        for (0..10) |p| {
            const pid: u8 = @intCast(p + 1);
            gold[p / 5] += @as(f32, @floatFromInt(f.get(pid, .total_gold))) / 1000;
            xp[p / 5] += @as(f32, @floatFromInt(f.get(pid, .xp))) / 1000;
        }
        for (seats, 0..) |*s, p| {
            const side = p / 5;
            const opp = for (seats, 0..) |o, q| {
                if (q / 5 != side and o.role == s.role) break q;
            } else return error.NoLaneOpponent;
            const lane = f.get(@intCast(p + 1), .total_gold) - f.get(@intCast(opp + 1), .total_gold);
            s.state = .{ gold[side] - gold[1 - side], xp[side] - xp[1 - side], @as(f32, @floatFromInt(lane)) / 1000 };
            s.b0 = b0[p];
            s.sum = sums[p];
            s.ok = true;
        }
    }
};

fn load(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: Io, snap: []const u8, d: *const rows.Data, c: harness.Cuts, phase: harness.Phase) !Loaded {
    var want: std.StringHashMapUnmanaged(u32) = .empty;
    defer want.deinit(gpa);
    const l = try selectSeats(gpa, arena, d, c, phase, &want);

    const db = try store.schema.openReadOnly(gpa, snap);
    defer db.close();
    var q = try db.prepare("SELECT match_id, data FROM timeline.timelines");
    defer q.deinit();
    var batch_arena: std.heap.ArenaAllocator = .init(gpa);
    defer batch_arena.deinit();
    var bodies: std.ArrayList([]const u8) = .empty;
    defer bodies.deinit(gpa);
    var bases: std.ArrayList(u32) = .empty;
    defer bases.deinit(gpa);
    const batch_len = 4096;
    try q.bind(.{});
    var more = true;
    while (more) {
        more = try q.step();
        if (more) if (want.get(q.bytes(0))) |base| {
            try bodies.append(gpa, try batch_arena.allocator().dupe(u8, q.bytes(1)));
            try bases.append(gpa, base);
        };
        if (bodies.items.len == batch_len or (!more and bodies.items.len > 0)) {
            const b: Batch = .{ .gpa = gpa, .bodies = bodies.items, .bases = bases.items, .seats = l.seats };
            try par.forEach(io, bodies.items.len, &b, Batch.body);
            bodies.clearRetainingCapacity();
            bases.clearRetainingCapacity();
            _ = batch_arena.reset(.retain_capacity);
        }
    }
    return l;
}

/// Per role, standardised residual of each summary dim after the champion-role mean
/// (shrunk to the role's) and a linear fit on the 14:00 state, all from fit seats
const Residual = struct {
    /// [cr][dim], shrunk means of the summary, then of the state
    cr_mean: [][n_sum + n_state]f64,
    coef: [Role.count][n_sum][n_state]f64,
    sd: [Role.count][n_sum]f64,

    const shrink = 20;

    fn init(gpa: std.mem.Allocator, seats: []const Seat, n_cr: u32) !Residual {
        const n = n_sum + n_state;
        var role_sum: [Role.count][n]f64 = @splat(@splat(0));
        var role_n: [Role.count]f64 = @splat(0);
        const cr_sum = try gpa.alloc([n]f64, n_cr);
        defer gpa.free(cr_sum);
        @memset(cr_sum, @splat(0));
        const cr_n = try gpa.alloc(f64, n_cr);
        defer gpa.free(cr_n);
        @memset(cr_n, 0);
        const cr_role = try gpa.alloc(u3, n_cr);
        defer gpa.free(cr_role);
        for (seats) |s| {
            cr_role[s.cr] = s.role;
            if (!s.fit) continue;
            const v = values(s);
            for (v, &cr_sum[s.cr], &role_sum[s.role]) |x, *a, *b| {
                a.* += x;
                b.* += x;
            }
            cr_n[s.cr] += 1;
            role_n[s.role] += 1;
        }
        var r: Residual = .{ .cr_mean = try gpa.alloc([n]f64, n_cr), .coef = undefined, .sd = undefined };
        errdefer gpa.free(r.cr_mean);
        for (r.cr_mean, cr_sum, cr_n, cr_role) |*m, s, cn, role| for (m, s, role_sum[role]) |*mi, si, rs| {
            mi.* = (si + shrink * rs / @max(role_n[role], 1)) / (cn + shrink);
        };

        // Within champion-role: summary on state, normal equations per role and dim
        var xtx: [Role.count][n_state][n_state]f64 = @splat(@splat(@splat(0)));
        var xty: [Role.count][n_sum][n_state]f64 = @splat(@splat(@splat(0)));
        for (seats) |s| if (s.fit) {
            const v = r.demeaned(s);
            const st = v[n_sum..];
            for (0..n_state) |a| for (0..n_state) |b| {
                xtx[s.role][a][b] += st[a] * st[b];
            };
            for (0..n_sum) |j| for (0..n_state) |a| {
                xty[s.role][j][a] += st[a] * v[j];
            };
        };
        for (0..Role.count) |role| for (0..n_sum) |j| {
            r.coef[role][j] = solve3(xtx[role], xty[role][j]);
        };
        var ss: [Role.count][n_sum]f64 = @splat(@splat(0));
        for (seats) |s| if (s.fit) {
            const e = r.raw(s);
            for (&ss[s.role], e) |*a, x| a.* += x * x;
        };
        for (&r.sd, ss, role_n) |*sd, s, rn| for (sd, s) |*a, b| {
            a.* = @sqrt(@max(b / @max(rn, 1), 1e-12));
        };
        return r;
    }

    fn deinit(r: *Residual, gpa: std.mem.Allocator) void {
        gpa.free(r.cr_mean);
    }

    fn values(s: Seat) [n_sum + n_state]f64 {
        var v: [n_sum + n_state]f64 = undefined;
        for (v[0..n_sum], s.sum) |*a, b| a.* = b;
        for (v[n_sum..], s.state) |*a, b| a.* = b;
        return v;
    }

    fn demeaned(r: *const Residual, s: Seat) [n_sum + n_state]f64 {
        var v = values(s);
        for (&v, r.cr_mean[s.cr]) |*a, m| a.* -= m;
        return v;
    }

    /// Residual before scaling
    fn raw(r: *const Residual, s: Seat) [n_sum]f64 {
        const v = r.demeaned(s);
        var out: [n_sum]f64 = undefined;
        for (&out, v[0..n_sum], r.coef[s.role]) |*o, x, c| {
            o.* = x;
            for (c, v[n_sum..]) |ci, st| o.* -= ci * st;
        }
        return out;
    }

    /// Clipped at clip sd: rare zones (enemy base before 14:00) have a tiny sd, one visit
    /// is 40+ sd, and k-means spent clusters on single players
    fn apply(r: *const Residual, s: Seat) [n_sum]f32 {
        var out: [n_sum]f32 = undefined;
        for (&out, r.raw(s), r.sd[s.role]) |*o, x, sd| o.* = @floatCast(std.math.clamp(x / sd, -clip, clip));
        return out;
    }

    const clip = 4;
};

/// a x = b for a symmetric 3 x 3 a (Cramer); zero when singular
fn solve3(a: [3][3]f64, b: [3]f64) [3]f64 {
    const det = det3(a);
    if (@abs(det) < 1e-12) return @splat(0);
    var x: [3]f64 = undefined;
    for (0..3) |k| {
        var m = a;
        for (0..3) |i| m[i][k] = b[i];
        x[k] = det3(m) / det;
    }
    return x;
}

fn det3(m: [3][3]f64) f64 {
    return m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) -
        m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0]) +
        m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]);
}

/// Eigenvectors of a symmetric matrix by cyclic Jacobi, columns of `vecs`, sorted by
/// eigenvalue, largest first
fn Eigen(comptime n: usize) type {
    return struct { values: [n]f64, vecs: [n][n]f64 };
}

fn eigen(comptime n: usize, a_in: [n][n]f64) Eigen(n) {
    var a = a_in;
    var v: [n][n]f64 = @splat(@splat(0));
    for (0..n) |i| v[i][i] = 1;
    for (0..100) |_| {
        var off: f64 = 0;
        for (0..n) |i| for (i + 1..n) |j| {
            off += a[i][j] * a[i][j];
        };
        if (off < 1e-18) break;
        for (0..n) |p| for (p + 1..n) |q| {
            if (@abs(a[p][q]) < 1e-30) continue;
            const theta = (a[q][q] - a[p][p]) / (2 * a[p][q]);
            const t = std.math.sign(theta) / (@abs(theta) + @sqrt(theta * theta + 1)) + @as(f64, if (theta == 0) 1 else 0);
            const cs = 1 / @sqrt(t * t + 1);
            const sn = t * cs;
            for (0..n) |k| {
                const akp = a[k][p];
                const akq = a[k][q];
                a[k][p] = cs * akp - sn * akq;
                a[k][q] = sn * akp + cs * akq;
            }
            for (0..n) |k| {
                const apk = a[p][k];
                const aqk = a[q][k];
                a[p][k] = cs * apk - sn * aqk;
                a[q][k] = sn * apk + cs * aqk;
            }
            for (0..n) |k| {
                const vkp = v[k][p];
                const vkq = v[k][q];
                v[k][p] = cs * vkp - sn * vkq;
                v[k][q] = sn * vkp + cs * vkq;
            }
        };
    }
    var order: [n]usize = undefined;
    for (&order, 0..) |*o, i| o.* = i;
    var diag: [n]f64 = undefined;
    for (&diag, 0..) |*d, i| d.* = a[i][i];
    std.mem.sort(usize, &order, diag, struct {
        fn gt(d: [n]f64, x: usize, y: usize) bool {
            return d[x] > d[y];
        }
    }.gt);
    var out: Eigen(n) = undefined;
    for (order, 0..) |o, c| {
        out.values[c] = diag[o];
        for (0..n) |k| out.vecs[k][c] = v[k][o];
    }
    return out;
}

const Pca = struct {
    /// [role][dim][component]
    vecs: [Role.count][n_sum][n_pc]f64,
    /// share of the residual variance each component explains
    share: [Role.count][n_pc]f64,
    /// projections are divided by it: components in sd units
    sd: [Role.count][n_pc]f64,

    fn init(z: []const [n_sum]f32, seats: []const Seat) Pca {
        var cov: [Role.count][n_sum][n_sum]f64 = @splat(@splat(@splat(0)));
        var n: [Role.count]f64 = @splat(0);
        for (seats, z) |s, x| if (s.fit) {
            n[s.role] += 1;
            for (0..n_sum) |i| for (0..n_sum) |j| {
                cov[s.role][i][j] += x[i] * x[j];
            };
        };
        var p: Pca = undefined;
        for (0..Role.count) |role| {
            const e = eigen(n_sum, cov[role]);
            var total: f64 = 0;
            for (e.values) |v| total += v;
            for (0..n_pc) |c| {
                p.share[role][c] = e.values[c] / total;
                p.sd[role][c] = @sqrt(@max(e.values[c], 1e-12) / @max(n[role], 1));
                for (0..n_sum) |k| p.vecs[role][k][c] = e.vecs[k][c];
            }
        }
        return p;
    }

    fn project(p: *const Pca, role: u3, x: [n_sum]f32) [n_pc]f32 {
        var out: [n_pc]f32 = @splat(0);
        for (&out, 0..) |*o, c| {
            var s: f64 = 0;
            for (x, 0..) |xi, k| s += xi * p.vecs[role][k][c];
            o.* = @floatCast(s / p.sd[role][c]);
        }
        return out;
    }
};

fn dist2(a: [n_sum]f32, b: [n_sum]f32) f32 {
    var s: f32 = 0;
    for (a, b) |x, y| s += (x - y) * (x - y);
    return s;
}

const Centres = struct { c: [max_k][n_sum]f32, inertia: f64 };

/// k-means++ then Lloyd, best of a few restarts by inertia
fn kmeans(gpa: std.mem.Allocator, pts: []const [n_sum]f32, k: usize, seed: u64) !Centres {
    const assign = try gpa.alloc(u8, pts.len);
    defer gpa.free(assign);
    const d2 = try gpa.alloc(f32, pts.len);
    defer gpa.free(d2);
    var best: Centres = .{ .c = undefined, .inertia = std.math.inf(f64) };
    for (0..5) |restart| {
        var prng: std.Random.DefaultPrng = .init(seed * 31 + restart);
        const rnd = prng.random();
        var c: Centres = .{ .c = @splat(@splat(0)), .inertia = 0 };
        c.c[0] = pts[rnd.uintLessThan(usize, pts.len)];
        for (pts, d2) |p, *d| d.* = dist2(p, c.c[0]);
        for (1..k) |j| {
            var total: f64 = 0;
            for (d2) |d| total += d;
            var target = rnd.float(f64) * total;
            const pick = for (d2, 0..) |d, i| {
                target -= d;
                if (target <= 0) break i;
            } else pts.len - 1;
            c.c[j] = pts[pick];
            for (pts, d2) |p, *d| d.* = @min(d.*, dist2(p, c.c[j]));
        }
        @memset(assign, max_k);
        for (0..100) |_| {
            var changed = false;
            c.inertia = 0;
            for (pts, assign) |p, *a| {
                var bj: u8 = 0;
                var bd = dist2(p, c.c[0]);
                for (1..k) |j| {
                    const d = dist2(p, c.c[j]);
                    if (d < bd) {
                        bd = d;
                        bj = @intCast(j);
                    }
                }
                c.inertia += bd;
                if (a.* != bj) changed = true;
                a.* = bj;
            }
            if (!changed) break;
            var sums: [max_k][n_sum]f64 = @splat(@splat(0));
            var counts: [max_k]f64 = @splat(0);
            for (pts, assign) |p, a| {
                counts[a] += 1;
                for (&sums[a], p) |*s, x| s.* += x;
            }
            for (0..k) |j| {
                if (counts[j] == 0) {
                    c.c[j] = pts[rnd.uintLessThan(usize, pts.len)];
                    continue;
                }
                for (&c.c[j], sums[j]) |*x, s| x.* = @floatCast(s / counts[j]);
            }
        }
        if (c.inertia < best.inertia) best = c;
    }
    return best;
}

fn nearest(c: *const Centres, k: usize, x: [n_sum]f32) u8 {
    var bj: u8 = 0;
    var bd = dist2(x, c.c[0]);
    for (1..k) |j| {
        const d = dist2(x, c.c[j]);
        if (d < bd) {
            bd = d;
            bj = @intCast(j);
        }
    }
    return bj;
}

const Clustering = struct {
    /// [role] centres, largest cluster on fit seats first
    centres: [Role.count]Centres,
    /// per seat
    of: []u8,
};

const KJob = struct {
    gpa: std.mem.Allocator,
    pts: [Role.count][]const [n_sum]f32,
    k_list: []const u8,
    out: [][Role.count]Centres,

    fn body(j: *const KJob, i: usize) !void {
        const ki = i / Role.count;
        const role = i % Role.count;
        j.out[ki][role] = try kmeans(j.gpa, j.pts[role], j.k_list[ki], 1 + 100 * role + j.k_list[ki]);
    }
};

fn cluster(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: Io, z: []const [n_sum]f32, seats: []const Seat, k_list: []const u8) ![]Clustering {
    var pts: [Role.count]std.ArrayList([n_sum]f32) = @splat(.empty);
    defer for (&pts) |*p| p.deinit(gpa);
    for (seats, z) |s, x| if (s.fit) try pts[s.role].append(gpa, x);
    var job: KJob = .{ .gpa = gpa, .pts = undefined, .k_list = k_list, .out = try gpa.alloc([Role.count]Centres, k_list.len) };
    defer gpa.free(job.out);
    for (&job.pts, pts) |*a, p| a.* = p.items;
    try par.forEach(io, k_list.len * Role.count, &job, KJob.body);

    const out = try arena.alloc(Clustering, k_list.len);
    for (out, job.out, k_list) |*cl, centres, k| {
        cl.of = try arena.alloc(u8, seats.len);
        for (0..Role.count) |role| {
            var counts: [max_k]u32 = @splat(0);
            for (pts[role].items) |x| counts[nearest(&centres[role], k, x)] += 1;
            var order: [max_k]u8 = undefined;
            for (&order, 0..) |*o, i| o.* = @intCast(i);
            std.mem.sort(u8, order[0..k], counts, struct {
                fn gt(cs: [max_k]u32, a: u8, b: u8) bool {
                    return cs[a] > cs[b];
                }
            }.gt);
            cl.centres[role] = centres[role];
            for (order[0..k], 0..) |o, j| cl.centres[role].c[j] = centres[role].c[o];
        }
        for (cl.of, seats, z) |*o, s, x| o.* = nearest(&cl.centres[s.role], k, x);
    }
    return out;
}

const Spec = struct {
    name: []const u8,
    state: bool = true,
    b0: bool = true,
    pcs: bool = false,
    /// index into the run's k list
    k: ?usize = null,
};

const Dims = struct {
    n_cr: u32,

    fn state(d: Dims, role: u3, i: usize) u32 {
        return 1 + d.n_cr + @as(u32, role) * n_state + @as(u32, @intCast(i));
    }
    fn b0(d: Dims, role: u3, f: usize) u32 {
        return 1 + d.n_cr + Role.count * n_state + @as(u32, role) * n_b0 + @as(u32, @intCast(f));
    }
    fn pc(d: Dims, role: u3, c: usize) u32 {
        return 1 + d.n_cr + Role.count * (n_state + n_b0) + @as(u32, role) * n_pc + @as(u32, @intCast(c));
    }
    /// Cluster 0 (the role's largest) is the reference: no column
    fn cluster(d: Dims, role: u3, c: usize) u32 {
        return 1 + d.n_cr + Role.count * (n_state + n_b0 + n_pc) + @as(u32, role) * max_k + @as(u32, @intCast(c));
    }
    fn total(d: Dims) usize {
        return 1 + d.n_cr + Role.count * (n_state + n_b0 + n_pc + max_k);
    }
};

const Ctx = struct {
    seats: []const Seat,
    pcs: []const [n_pc]f32,
    clusterings: []const Clustering,
    dims: Dims,

    fn row(c: *const Ctx, m: Spec, i: usize) logreg.Row {
        const s = c.seats[i];
        var b: logreg.Row = .{ .y = @floatFromInt(@intFromBool(s.won)) };
        b.add(0, 1);
        b.add(1 + s.cr, 1);
        if (m.state) for (s.state, 0..) |x, j| b.add(c.dims.state(s.role, j), x);
        if (m.b0) for (s.b0, 0..) |x, j| b.add(c.dims.b0(s.role, j), x);
        if (m.pcs) for (c.pcs[i], 0..) |x, j| b.add(c.dims.pc(s.role, j), x);
        if (m.k) |k| {
            const cl = c.clusterings[k].of[i];
            if (cl > 0) b.add(c.dims.cluster(s.role, cl), 1);
        }
        return b;
    }
};

const Fitted = struct {
    w: []f64,
    se: ?[]f64,
    /// log loss per scored seat
    loss: []f64,
    preds: []f64,
};

fn fitModel(gpa: std.mem.Allocator, arena: std.mem.Allocator, ctx: *const Ctx, m: Spec, fit_idx: []const u32, scored_idx: []const u32, games: []const u32) !Fitted {
    const d = ctx.dims.total();
    const train = try gpa.alloc(logreg.Row, fit_idx.len);
    defer gpa.free(train);
    for (train, fit_idx) |*b, i| b.* = ctx.row(m, i);
    const w = try logreg.fit(gpa, d, train, 1);
    defer gpa.free(w);
    var out: Fitted = .{ .w = try arena.dupe(f64, w), .se = null, .loss = try arena.alloc(f64, scored_idx.len), .preds = try arena.alloc(f64, scored_idx.len) };
    if (m.k != null or m.pcs) {
        // A game's ten rows share its outcome and mirrored state (playstyle.zig)
        const se = try logreg.clusteredStdErrors(gpa, d, train, games, w, 1);
        defer gpa.free(se);
        out.se = try arena.dupe(f64, se);
    }
    for (out.loss, out.preds, scored_idx) |*l, *p, i| {
        const b = ctx.row(m, i);
        p.* = logreg.sigmoid(b.dot(w));
        l.* = analysis.logLoss(p.*, b.y);
    }
    return out;
}

const GameRow = struct { game: u32 };

pub fn main(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: Io, argv: []const []const u8) !u8 {
    if (argv.len != 2 and !(argv.len == 4 and std.mem.eql(u8, argv[2], "--final"))) {
        std.debug.print("usage:\n{s}", .{usage});
        return 2;
    }
    const snap = argv[0];
    const out_dir = argv[1];
    const final_k: ?u8 = if (argv.len == 4) try std.fmt.parseInt(u8, argv[3], 10) else null;
    if (final_k) |k| if (k < 2 or k > max_k) return error.BadK;
    const phase: harness.Phase = if (final_k != null) .final else .dev;
    const k_list: []const u8 = if (final_k) |k| &.{k} else &ks;
    try Io.Dir.cwd().createDirPath(io, out_dir);

    var legendaries = try rows.loadLegendaries(gpa, io, snap);
    defer legendaries.deinit(gpa);
    var data = try rows.load(gpa, snap, &legendaries);
    defer data.deinit();
    const ids = protocol.platformIds();
    const eu: u8 = for (ids, 0..) |id, k| {
        if (std.mem.eql(u8, id, protocol.test_platform)) break @intCast(k);
    } else return error.TestPlatformNotScanned;
    const c = try harness.cuts(gpa, &data, eu);

    const l = try load(gpa, arena, io, snap, &data, c, phase);
    var missing: usize = 0;
    for (l.seats) |s| missing += @intFromBool(!s.ok);
    // Seats of a game whose timeline failed to load drop out together
    var kept: std.ArrayList(Seat) = .empty;
    for (l.seats) |s| if (s.ok) try kept.append(arena, s);
    const seats = kept.items;
    log.info("{d} seats, {d} without a timeline", .{ seats.len, missing });

    // b0's features standardised per role on fit seats, as playstyle.zig does
    {
        var m: [Role.count][n_b0]f64 = @splat(@splat(0));
        var sq: [Role.count][n_b0]f64 = @splat(@splat(0));
        var n: [Role.count]f64 = @splat(0);
        for (seats) |s| if (s.fit) {
            n[s.role] += 1;
            for (s.b0, &m[s.role], &sq[s.role]) |x, *a, *b| {
                a.* += x;
                b.* += x * x;
            }
        };
        for (&m, &sq, n) |*mr, *sr, nr| for (mr, sr) |*a, *b| {
            a.* /= @max(nr, 1);
            b.* = @sqrt(@max(b.* / @max(nr, 1) - a.* * a.*, 1e-12));
        };
        for (seats) |*s| for (&s.b0, m[s.role], sq[s.role]) |*x, a, b| {
            x.* = @floatCast((x.* - a) / b);
        };
    }

    var res = try Residual.init(gpa, seats, l.n_cr);
    defer res.deinit(gpa);
    const z = try arena.alloc([n_sum]f32, seats.len);
    for (z, seats) |*x, s| x.* = res.apply(s);
    const pca: Pca = .init(z, seats);
    const pcs = try arena.alloc([n_pc]f32, seats.len);
    for (pcs, seats, z) |*p, s, x| p.* = pca.project(s.role, x);
    const clusterings = try cluster(gpa, arena, io, z, seats, k_list);

    var fit_idx: std.ArrayList(u32) = .empty;
    var scored_idx: std.ArrayList(u32) = .empty;
    var fit_games: std.ArrayList(u32) = .empty;
    var scored_games: std.ArrayList(GameRow) = .empty;
    for (seats, 0..) |s, i| if (s.fit) {
        try fit_idx.append(arena, @intCast(i));
        try fit_games.append(arena, s.game);
    } else {
        try scored_idx.append(arena, @intCast(i));
        try scored_games.append(arena, .{ .game = s.game });
    };

    var specs: std.ArrayList(Spec) = .empty;
    try specs.append(arena, .{ .name = "champion + state", .b0 = false });
    try specs.append(arena, .{ .name = "b0: champion + state + b0 style" });
    try specs.append(arena, .{ .name = "b0 + 10 style components", .pcs = true });
    for (k_list, 0..) |k, ki| {
        try specs.append(arena, .{ .name = try std.fmt.allocPrint(arena, "b0 + clusters k={d}", .{k}), .k = ki });
        try specs.append(arena, .{ .name = try std.fmt.allocPrint(arena, "champion + state + clusters k={d}", .{k}), .b0 = false, .k = ki });
    }
    const ctx: Ctx = .{ .seats = seats, .pcs = pcs, .clusterings = clusterings, .dims = .{ .n_cr = l.n_cr } };
    const fitted = try arena.alloc(Fitted, specs.items.len);
    for (fitted, specs.items) |*f, m| {
        f.* = try fitModel(gpa, arena, &ctx, m, fit_idx.items, scored_idx.items, fit_games.items);
        log.info("{s}: {d:.5}", .{ m.name, analysis.mean(f.loss) });
    }

    const stem = if (phase == .final) "final" else "dev";
    const path = try std.fs.path.join(arena, &.{ out_dir, try std.fmt.allocPrint(arena, "{s}-report.md", .{stem}) });
    var file = try Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    var buf: [64 * 1024]u8 = undefined;
    var fw = file.writer(io, &buf);
    const w = &fw.interface;
    var n_fit_games: usize = 0;
    var n_scored_games: usize = 0;
    for (seats, 0..) |s, i| if (i % 10 == 0) {
        if (s.fit) n_fit_games += 1 else n_scored_games += 1;
    };
    try w.print("# meiolol-lab style ({s})\n\nFit: {d} games, scored: {d} games ({s}), ten rows each; " ++
        "{d} seats dropped without a timeline. Style from minutes 0-{d} (positions from 3), " ++
        "residualised within role on champion-role and the state at {d}:00.\n\n", .{
        stem, n_fit_games, n_scored_games, if (phase == .final) "test" else "dev cut", missing, until_minute - 1, until_minute,
    });
    try w.writeAll("Win log loss per row; gain = drop from b0 (or from champion + state where named), " ++
        "± 95% clustered by game.\n\n| model | log loss | gain vs b0 | gain vs champion + state |\n| --- | --- | --- | --- |\n");
    for (specs.items, fitted) |m, f| {
        const g = analysis.pairedGain(scored_games.items, fitted[1].loss, f.loss);
        const g0 = analysis.pairedGain(scored_games.items, fitted[0].loss, f.loss);
        try w.print("| {s} | {d:.5} | {d:.5} ± {d:.5} | {d:.5} ± {d:.5} |\n", .{ m.name, analysis.mean(f.loss), g.mean, g.half_width, g0.mean, g0.half_width });
    }

    try w.writeAll("\nResidual variance share of the first components, by role:\n\n| role |");
    for (0..n_pc) |j| try w.print(" pc{d} |", .{j + 1});
    try w.writeAll("\n| --- |");
    for (0..n_pc) |_| try w.writeAll(" --- |");
    try w.writeAll("\n");
    for (0..Role.count) |role| {
        try w.print("| {t} |", .{@as(Role, @fromBackingInt(@intCast(role)))});
        for (pca.share[role]) |s| try w.print(" {d:.3} |", .{s});
        try w.writeAll("\n");
    }

    try writePcs(gpa, w, &pca, ctx, fitted[2]);
    for (k_list, 0..) |k, ki| {
        const spec_i = 3 + 2 * ki;
        const f = fitted[spec_i];
        try writeClusters(gpa, w, k, ki, ctx, f, seats);
    }
    try w.flush();
    log.info("wrote {s}", .{path});

    if (phase == .final) {
        const ppath = try std.fs.path.join(arena, &.{ out_dir, "final-preds.tsv" });
        var pf = try Io.Dir.cwd().createFile(io, ppath, .{});
        defer pf.close(io);
        var pfw = pf.writer(io, &buf);
        const pw = &pfw.interface;
        try pw.writeAll("match_id\tslot\ty");
        for (specs.items) |m| try pw.print("\t{s}", .{m.name});
        try pw.writeAll("\n");
        for (scored_idx.items, 0..) |si, r| {
            const s = seats[si];
            try pw.print("{s}\t{d}\t{d}", .{ l.match_ids[s.game], s.slot, @intFromBool(s.won) });
            for (fitted) |ft| try pw.print("\t{d:.5}", .{ft.preds[r]});
            try pw.writeAll("\n");
        }
        try pw.flush();
    }
    return 0;
}

/// Per role and component: variance share, effect given b0 and the state per +1 sd, BH
/// over the table, largest loadings
fn writePcs(gpa: std.mem.Allocator, w: *Io.Writer, pca: *const Pca, ctx: Ctx, f: Fitted) !void {
    var q: [Role.count * n_pc]f64 = undefined;
    for (0..Role.count) |role| for (0..n_pc) |c| {
        const i = ctx.dims.pc(@intCast(role), c);
        q[role * n_pc + c] = 2 * fields.upperTail(@abs(f.w[i]) / f.se.?[i]);
    };
    try fields.adjustBH(gpa, &q);
    try w.writeAll("\n## Style components\n\nEffect: win pp per +1 sd of the component given b0's " ++
        "features and the state (log-odds x 25) ± 95% clustered by game; q = BH over this table. " ++
        "Loadings: the largest, on standardised residuals (sign of a component is arbitrary).\n\n" ++
        "| role | pc | share | effect | q | loadings |\n| --- | --- | --- | --- | --- | --- |\n");
    for (0..Role.count) |role| for (0..n_pc) |c| {
        const i = ctx.dims.pc(@intCast(role), c);
        try w.print("| {t} | {d} | {d:.3} | {d:.2} ± {d:.2} | {d:.3} |", .{
            @as(Role, @fromBackingInt(@intCast(role))), c + 1, pca.share[role][c], 25 * f.w[i], 25 * 1.96 * f.se.?[i], q[role * n_pc + c],
        });
        var loading: [n_sum]f32 = undefined;
        for (&loading, 0..) |*l, k| l.* = @floatCast(pca.vecs[role][k][c]);
        try writeTop(w, loading, 6);
        try w.writeAll(" |\n");
    };
}

fn writeTop(w: *Io.Writer, v: [n_sum]f32, n: usize) !void {
    var order: [n_sum]usize = undefined;
    for (&order, 0..) |*o, i| o.* = i;
    std.mem.sort(usize, &order, v, struct {
        fn gt(cc: [n_sum]f32, a: usize, b: usize) bool {
            return @abs(cc[a]) > @abs(cc[b]);
        }
    }.gt);
    var nb: [64]u8 = undefined;
    for (order[0..n], 0..) |o, t| try w.print("{s}{s} {d:.2}", .{ if (t == 0) " " else ", ", sumName(&nb, o), v[o] });
}

/// Per role and cluster: share, raw win rate, effect given b0 and the state (vs the
/// role's largest cluster, pp per log-odds x 25), BH over the table, and the centroid's
/// largest residual deviations
fn writeClusters(gpa: std.mem.Allocator, w: *Io.Writer, k: usize, ki: usize, ctx: Ctx, f: Fitted, seats: []const Seat) !void {
    const cl = ctx.clusterings[ki];
    var n: [Role.count][max_k]f64 = @splat(@splat(0));
    var wins: [Role.count][max_k]f64 = @splat(@splat(0));
    var raw: [Role.count][max_k][n_sum]f64 = @splat(@splat(@splat(0)));
    for (seats, cl.of) |s, o| if (s.fit) {
        n[s.role][o] += 1;
        wins[s.role][o] += @floatFromInt(@intFromBool(s.won));
        for (&raw[s.role][o], s.sum) |*a, x| a.* += x;
    };
    var p: [Role.count * max_k]f64 = undefined;
    var np: usize = 0;
    for (0..Role.count) |role| for (1..k) |j| {
        const i = ctx.dims.cluster(@intCast(role), j);
        p[np] = 2 * fields.upperTail(@abs(f.w[i]) / f.se.?[i]);
        np += 1;
    };
    var qa = p;
    try fields.adjustBH(gpa, qa[0..np]);
    try w.print("\n## k = {d}\n\nEffect: win pp vs the role's largest cluster given b0's features and the " ++
        "state (log-odds x 25) ± 95% clustered by game; q = BH over this table. Centre: the " ++
        "largest standardised residual deviations (style beyond champion and state); raw: " ++
        "cluster means before residualising.\n\n| role | cluster | share | raw win | effect | q | centre | raw |\n" ++
        "| --- | --- | --- | --- | --- | --- | --- | --- |\n", .{k});
    np = 0;
    for (0..Role.count) |role| {
        var total: f64 = 0;
        for (n[role][0..k]) |x| total += x;
        for (0..k) |j| {
            try w.print("| {t} | {d} | {d:.2} | {d:.3} |", .{ @as(Role, @fromBackingInt(@intCast(role))), j, n[role][j] / total, wins[role][j] / @max(n[role][j], 1) });
            if (j == 0) try w.writeAll(" ref | |") else {
                const i = ctx.dims.cluster(@intCast(role), j);
                try w.print(" {d:.2} ± {d:.2} | {d:.3} |", .{ 25 * f.w[i], 25 * 1.96 * f.se.?[i], qa[np] });
                np += 1;
            }
            try writeTop(w, cl.centres[role].c[j], 5);
            try w.writeAll(" |");
            const m = n[role][j];
            const r = raw[role][j];
            try w.print(" away {d:.2}, enemy jg {d:.2}, dmg {d:.1}, k/d/a {d:.1}/{d:.1}/{d:.1}, wards {d:.1}, cs {d:.0}+{d:.0}, shops {d:.1} first {d:.1} |\n", .{
                awayShare(r, @intCast(role)) / m,
                (r[@backingInt(Zone.jungle_enemy_top)] + r[@backingInt(Zone.jungle_enemy_bot)] + r[n_zone + @backingInt(Zone.jungle_enemy_top)] + r[n_zone + @backingInt(Zone.jungle_enemy_bot)]) / 2 / m,
                r[act(.damage)] / m,
                r[act(.kills)] / m,
                r[act(.deaths)] / m,
                r[act(.assists)] / m,
                r[act(.wards)] / m,
                r[act(.lane_cs)] / m,
                r[act(.jungle_cs)] / m,
                r[act(.shops)] / m,
                r[act(.first_shop)] / m,
            });
        }
    }
}

/// Summed over seats: mean share of position frames out of the role's lane and own base
/// (junglers: in any lane), both phases weighted by frame count
fn awayShare(r: [n_sum]f64, role: u3) f64 {
    const lanes = [_][2]Zone{ .{ .top_own, .top_enemy }, .{ .mid_own, .mid_enemy }, .{ .bot_own, .bot_enemy } };
    var home: f64 = 0;
    var lane_any: f64 = 0;
    var total: f64 = 0;
    for (phases, 0..) |ph, k| {
        const nf: f64 = @floatFromInt(ph[1] - ph[0]);
        total += nf;
        const base = k * n_zone;
        home += nf * r[base + @backingInt(Zone.own_base)];
        for (lanes) |ln| for (ln) |zn| {
            lane_any += nf * r[base + @backingInt(zn)];
        };
        const own: ?usize = switch (role) {
            0 => 0,
            2 => 1,
            3, 4 => 2,
            else => null,
        };
        if (own) |o| for (lanes[o]) |zn| {
            home += nf * r[base + @backingInt(zn)];
        };
    }
    // r holds sums of shares over seats; the caller divides by the count
    return if (role == 1) lane_any / total else (total * sumOne(r) - home) / total;
}

/// Sum over seats of the early phase's zone shares: the seat count (each seat's shares add
/// to 1)
fn sumOne(r: [n_sum]f64) f64 {
    var s: f64 = 0;
    for (r[0..n_zone]) |x| s += x;
    return s;
}

const testing = std.testing;

test "zones from blue's side, red mirrored" {
    try testing.expectEqual(Zone.own_base, zone(500, 500));
    try testing.expectEqual(Zone.enemy_base, zone(14300, 14300));
    try testing.expectEqual(Zone.top_own, zone(1200, 9000));
    try testing.expectEqual(Zone.top_enemy, zone(6000, 13600));
    try testing.expectEqual(Zone.bot_own, zone(9000, 1200));
    try testing.expectEqual(Zone.mid_own, zone(6000, 6200));
    try testing.expectEqual(Zone.mid_enemy, zone(8600, 8400));
    try testing.expectEqual(Zone.river_top, zone(4800, 9900));
    try testing.expectEqual(Zone.jungle_own_top, zone(3800, 7800));
    try testing.expectEqual(Zone.jungle_enemy_bot, zone(11000, 7000));
    // Red's base is red's own base; red in red's top lane half is in its own top half
    const rb = mirror(14300, 14300);
    try testing.expectEqual(Zone.own_base, zone(rb[0], rb[1]));
    const rt = mirror(6000, 13600);
    try testing.expectEqual(Zone.top_own, zone(rt[0], rt[1]));
}

test "style summary from a timeline" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const frames = try arena.alloc(timeline.Frame, 16);
    for (frames, 0..) |*f, i| {
        f.* = .{ .t_ms = @intCast(i * minute_ms) };
        for (0..10) |p| {
            f.stats[p][@backingInt(timeline.Stat.x)] = 7400;
            f.stats[p][@backingInt(timeline.Stat.y)] = 7200;
        }
        // Blue top in their own top half; red top (6) in its own top half, as red sees it
        f.stats[0][@backingInt(timeline.Stat.x)] = 1200;
        f.stats[0][@backingInt(timeline.Stat.y)] = 9000;
        f.stats[5][@backingInt(timeline.Stat.x)] = 6000;
        f.stats[5][@backingInt(timeline.Stat.y)] = 13600;
        f.stats[0][@backingInt(timeline.Stat.minions)] = @intCast(6 * i);
    }
    const events = [_]timeline.Event{
        .{ .t_ms = 30_000, .data = .{ .item_purchased = .{ .participant = 1, .item = 1055 } } },
        .{ .t_ms = 300_000, .data = .{ .champion_kill = .{ .killer = 1, .victim = 6, .x = 0, .y = 0, .bounty = 300, .shutdown = 0, .assists = &.{2} } } },
        .{ .t_ms = 310_000, .data = .{ .turret_plate = .{ .killer = 1, .team = 100, .lane = "TOP_LANE" } } },
        .{ .t_ms = 390_000, .data = .{ .item_purchased = .{ .participant = 1, .item = 1036 } } },
        .{ .t_ms = 400_000, .data = .{ .item_purchased = .{ .participant = 1, .item = 1037 } } },
        .{ .t_ms = 600_000, .data = .{ .elite_monster = .{ .killer = 2, .team = 100, .monster = "DRAGON", .subtype = "", .assists = &.{1} } } },
        .{ .t_ms = 610_000, .data = .{ .item_purchased = .{ .participant = 1, .item = 3133 } } },
        // After 14:00: left out
        .{ .t_ms = 850_000, .data = .{ .champion_kill = .{ .killer = 1, .victim = 6, .x = 0, .y = 0, .bounty = 300, .shutdown = 0, .assists = &.{} } } },
    };
    const t: timeline.Timeline = .{ .participants = 10, .frames = frames, .events = &events };
    const out = summary(t);
    const top = out[0];
    try testing.expectEqual(1, top[@backingInt(Zone.top_own)]);
    try testing.expectEqual(1, top[n_zone + @backingInt(Zone.top_own)]);
    try testing.expectEqual(1, out[5][@backingInt(Zone.top_own)]);
    try testing.expectEqual(0, top[act(.step)]);
    try testing.expectEqual(1, top[act(.kills)]);
    try testing.expectEqual(1, out[5][act(.deaths)]);
    try testing.expectEqual(1, out[1][act(.assists)]);
    try testing.expectEqual(1, top[act(.plates)]);
    try testing.expectEqual(1, top[act(.epics)]);
    try testing.expectEqual(1, out[1][act(.epics)]);
    // Start items don't count; two purchases in minute 6 are one trip
    try testing.expectEqual(2, top[act(.shops)]);
    try testing.expectApproxEqAbs(6.5, top[act(.first_shop)], 1e-6);
    try testing.expectEqual(14, out[1][act(.first_shop)]);
    try testing.expectEqual(84, top[act(.lane_cs)]);
}

test "k-means finds separated groups" {
    var pts: [40][n_sum]f32 = undefined;
    for (&pts, 0..) |*p, i| {
        p.* = @splat(0);
        p[0] = if (i < 20) -5 else 5;
        p[1] = @as(f32, @floatFromInt(i % 5)) * 0.1;
    }
    const c = try kmeans(testing.allocator, &pts, 2, 7);
    try testing.expect(nearest(&c, 2, pts[0]) != nearest(&c, 2, pts[39]));
    for (pts[0..20]) |p| try testing.expectEqual(nearest(&c, 2, pts[0]), nearest(&c, 2, p));
}

test "jacobi eigenvectors" {
    const a = [3][3]f64{ .{ 2, 1, 0 }, .{ 1, 2, 0 }, .{ 0, 0, 1 } };
    const e = eigen(3, a);
    try testing.expectApproxEqAbs(3, e.values[0], 1e-9);
    try testing.expectApproxEqAbs(1, e.values[1], 1e-9);
    try testing.expectApproxEqAbs(1 / @sqrt(@as(f64, 2)), @abs(e.vecs[0][0]), 1e-9);
}
