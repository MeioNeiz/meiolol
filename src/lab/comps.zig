//! Champion-role profiles for champcomp and champgroups (docs/model.md "Comp discovery"
//! has the experiment they came from): ~60 numbers per champion-role (damage mix,
//! frontline, CC, peel, siege, vision, objectives, waveclear, fights, roams, items, early
//! power, scaling) from fit games only, per fold: each the average of the champion-role's
//! mean in won and in lost games (end of game stats lean to the winner), shrunk to the
//! role mean, then z within role. Also the comp_stats loader and the tests' statistics

const std = @import("std");
const api = @import("api");
const rows = @import("rows.zig");
const harness = @import("harness.zig");
const seatstats = @import("seatstats.zig");
const compstats = @import("compstats.zig");
const snapcache = @import("snapcache.zig");

const Io = std.Io;
const Allocator = std.mem.Allocator;
const S = seatstats.SeatStat;

/// Profile values per champion-role
pub const V = enum {
    phys_dpm,
    magic_dpm,
    true_dpm,
    magic_share,
    true_share,
    taken_pm,
    mitig_pm,
    tank_share,
    cc_pm,
    immob_pm,
    selfheal_pm,
    ally_pm,
    build_pm,
    armour_lean,
    range,
    vision_pm,
    wards_pm,
    wardkill_pm,
    control_pm,
    epic_pm,
    turret_pm,
    dragon_td,
    baron_td,
    herald_td,
    plates,
    solo_turrets,
    herald_turrets,
    lane_cs10,
    cs_pm,
    jungle_pm,
    kills_pm,
    deaths_pm,
    assists_pm,
    solo_kills,
    outnumbered,
    kill_part,
    dmg_share,
    taken_share,
    pick_kills,
    immob_kills,
    hidden_kills,
    knock_kills,
    dive_kills,
    def_kills,
    save_ally,
    effheal_pm,
    early_td,
    roam,
    skillshots_pm,
    cc_total_pm,
    dead_share,
    gold_pm,
    antiheal,
    armour_pen,
    magic_pen,
    lethality,
    gold14,
    lanediff14,
    cs10,
    deaths15,
    first_item,
    game_len,
    /// Win rate in long games (32 min+) minus short ones (under 25), from fit games
    scaling,
};
pub const nv = @typeInfo(V).@"enum".field_names.len;

pub fn vi(v: V) usize {
    return @backingInt(v);
}

const nan = std.math.nan(f64);

/// One seat's values (NaN unknown); scaling is the profile's own
fn rowValues(r: rows.Row, extra: ?*const compstats.Seat, g: rows.Game) [nv]f64 {
    var out: [nv]f64 = @splat(nan);
    const s = r.stats;
    const st = struct {
        fn f(x: seatstats.Stats, k: S) f64 {
            return x[@backingInt(k)];
        }
    }.f;
    const m = st(s, .minutes);
    if (!std.math.isNan(m) and m > 0) {
        const phys = st(s, .dmg_phys);
        const magic = st(s, .dmg_magic);
        const tru = st(s, .dmg_true);
        const dmg = phys + magic + tru;
        const taken = st(s, .taken_phys) + st(s, .taken_magic) + st(s, .taken_true);
        const mit = st(s, .mitigated);
        out[vi(.phys_dpm)] = phys / m;
        out[vi(.magic_dpm)] = magic / m;
        out[vi(.true_dpm)] = tru / m;
        if (dmg > 0) {
            out[vi(.magic_share)] = magic / dmg;
            out[vi(.true_share)] = tru / dmg;
        }
        out[vi(.taken_pm)] = taken / m;
        out[vi(.mitig_pm)] = mit / m;
        if (mit + taken > 0) out[vi(.tank_share)] = mit / (mit + taken);
        out[vi(.cc_pm)] = st(s, .cc_time) / m;
        out[vi(.immob_pm)] = st(s, .immobilisations) / m;
        out[vi(.selfheal_pm)] = (st(s, .heal) - st(s, .heal_allies)) / m;
        out[vi(.ally_pm)] = (st(s, .heal_allies) + st(s, .shield_allies)) / m;
        out[vi(.build_pm)] = st(s, .dmg_buildings) / m;
        out[vi(.armour_lean)] = st(s, .armor_end) - st(s, .mr_end);
        out[vi(.range)] = st(s, .attack_range);
        if (extra) |e| {
            const c = struct {
                fn f(x: *const compstats.Seat, comptime name: []const u8) f64 {
                    return x[compstats.col(name)];
                }
            }.f;
            out[vi(.vision_pm)] = c(e, "visionScore") / m;
            out[vi(.wards_pm)] = c(e, "wardsPlaced") / m;
            out[vi(.wardkill_pm)] = c(e, "wardsKilled") / m;
            out[vi(.control_pm)] = c(e, "controlWardsPlaced") / m;
            out[vi(.epic_pm)] = c(e, "damageDealtToEpicMonsters") / m;
            out[vi(.turret_pm)] = c(e, "damageDealtToTurrets") / m;
            out[vi(.dragon_td)] = c(e, "dragonTakedowns") / m;
            out[vi(.baron_td)] = c(e, "baronTakedowns") / m;
            out[vi(.herald_td)] = c(e, "riftHeraldTakedowns") / m;
            out[vi(.plates)] = c(e, "turretPlatesTaken");
            // Riot leaves soloTurretsLategame out when it is 0 (never 0 in 2.3M seats)
            const solo = c(e, "soloTurretsLategame");
            out[vi(.solo_turrets)] = (if (std.math.isNan(solo)) 0 else solo) / m;
            out[vi(.herald_turrets)] = c(e, "turretsTakenWithRiftHerald") / m;
            out[vi(.lane_cs10)] = c(e, "laneMinionsFirst10Minutes");
            out[vi(.cs_pm)] = c(e, "totalMinionsKilled") / m;
            out[vi(.jungle_pm)] = c(e, "neutralMinionsKilled") / m;
            out[vi(.kills_pm)] = c(e, "kills") / m;
            out[vi(.deaths_pm)] = c(e, "deaths") / m;
            out[vi(.assists_pm)] = c(e, "assists") / m;
            out[vi(.solo_kills)] = c(e, "soloKills") / m;
            out[vi(.outnumbered)] = c(e, "outnumberedKills") / m;
            out[vi(.kill_part)] = c(e, "killParticipation");
            out[vi(.dmg_share)] = c(e, "teamDamagePercentage");
            out[vi(.taken_share)] = c(e, "damageTakenOnTeamPercentage");
            out[vi(.pick_kills)] = c(e, "pickKillWithAlly") / m;
            out[vi(.immob_kills)] = c(e, "immobilizeAndKillWithAlly") / m;
            out[vi(.hidden_kills)] = c(e, "killAfterHiddenWithAlly") / m;
            out[vi(.knock_kills)] = c(e, "knockEnemyIntoTeamAndKill") / m;
            out[vi(.dive_kills)] = c(e, "killsNearEnemyTurret") / m;
            out[vi(.def_kills)] = c(e, "killsUnderOwnTurret") / m;
            out[vi(.save_ally)] = c(e, "saveAllyFromDeath") / m;
            out[vi(.effheal_pm)] = c(e, "effectiveHealAndShielding") / m;
            out[vi(.early_td)] = c(e, "takedownsFirstXMinutes");
            out[vi(.roam)] = c(e, "killsOnOtherLanesEarlyJungleAsLaner") + c(e, "getTakedownsInAllLanesEarlyJungleAsLaner");
            out[vi(.skillshots_pm)] = c(e, "skillshotsHit") / m;
            out[vi(.cc_total_pm)] = c(e, "totalTimeCCDealt") / m;
            out[vi(.dead_share)] = c(e, "totalTimeSpentDead") / (m * 60);
            out[vi(.gold_pm)] = c(e, "goldEarned") / m;
            out[vi(.antiheal)] = c(e, "antiheal");
            out[vi(.armour_pen)] = c(e, "armour_pen");
            out[vi(.magic_pen)] = c(e, "magic_pen");
            out[vi(.lethality)] = c(e, "lethality");
        }
    }
    out[vi(.gold14)] = r.y[api.outcomeIndex(.gold14)];
    out[vi(.lanediff14)] = r.y[api.outcomeIndex(.lanediff14)];
    out[vi(.cs10)] = r.y[api.outcomeIndex(.cs10)];
    out[vi(.deaths15)] = r.y[api.outcomeIndex(.deaths15)];
    out[vi(.first_item)] = r.y[api.outcomeIndex(.first_item)];
    out[vi(.game_len)] = @as(f64, @floatFromInt(g.duration_s)) / 60;
    return out;
}

const long_game_min = 32;
const short_game_min = 25;
/// Pseudo-rows at the role mean in each half (won, lost) of a profile
const shrink_rows = 20;
/// Pseudo-games at 50% in the long and short win rates of scaling
const shrink_games = 50;
/// A pick "has" a trait when its profile is in the top share of fit picks (all roles)
const top_share = 0.2;

pub fn cellKey(champion: u32, role: usize) u64 {
    return (@as(u64, champion) << 3) | role;
}

const Cell = struct {
    /// [won, lost]
    sum: [2][nv]f64 = @splat(@splat(0)),
    n: [2][nv]f64 = @splat(@splat(0)),
    /// Wins and games, [long, short]
    wins: [2]f64 = .{ 0, 0 },
    games: [2]f64 = .{ 0, 0 },
};

/// Profiles of one fold, from its fit games
pub const Profiles = struct {
    raw: std.AutoHashMapUnmanaged(u64, [nv]f64) = .empty,
    role_raw: [5][nv]f64 = undefined,
    role_mean: [5][nv]f64 = undefined,
    role_sd: [5][nv]f64 = undefined,
    /// Top-share cut of raw values over fit picks, all roles
    cut: [nv]f64 = undefined,
    /// Optional carry columns (meiolol-61), z within role; [cell] -> values
    carry: std.AutoHashMapUnmanaged(u64, []const f64) = .empty,

    pub fn deinit(p: *Profiles, gpa: Allocator) void {
        p.raw.deinit(gpa);
        p.carry.deinit(gpa);
    }

    pub fn raw_of(p: *const Profiles, champion: u32, role: usize) [nv]f64 {
        return p.raw.get(cellKey(champion, role)) orelse p.role_raw[role];
    }

    pub fn z(p: *const Profiles, role: usize, x: [nv]f64) [nv]f64 {
        var out: [nv]f64 = undefined;
        for (&out, x, p.role_mean[role], p.role_sd[role]) |*o, a, m, s| o.* = if (s > 0) (a - m) / s else 0;
        return out;
    }
};

/// permute: nonzero shuffles the profiles among champion-roles of a role (a control:
/// traits become arbitrary functions of the champions)
pub fn buildProfiles(gpa: Allocator, d: *const rows.Data, extra: []const ?compstats.Seat, fit: Fit, permute: u64) !Profiles {
    var cells: std.AutoHashMapUnmanaged(u64, Cell) = .empty;
    defer cells.deinit(gpa);
    var roles: [5]Cell = @splat(.{});
    for (d.rows, extra) |r, *e| {
        const g = d.games[r.game];
        if (!fit.has(g)) continue;
        const role: usize = @backingInt(r.role);
        const x = rowValues(r, if (e.*) |*s| s else null, g);
        const won: usize = if (g.winner == r.side) 0 else 1;
        const c = try cells.getOrPutValue(gpa, cellKey(r.champion, role), .{});
        for ([_]*Cell{ c.value_ptr, &roles[role] }) |cell| {
            for (x, 0..) |v, k| if (!std.math.isNan(v)) {
                cell.sum[won][k] += v;
                cell.n[won][k] += 1;
            };
            const mins = @as(f64, @floatFromInt(g.duration_s)) / 60;
            const lg: ?usize = if (mins >= long_game_min) 0 else if (mins < short_game_min) 1 else null;
            if (lg) |i| {
                cell.games[i] += 1;
                cell.wins[i] += if (won == 0) 1 else 0;
            }
        }
    }
    var p: Profiles = .{};
    errdefer p.deinit(gpa);
    for (&p.role_raw, roles) |*rr, cell| rr.* = profileOf(cell, null);
    var it = cells.iterator();
    while (it.next()) |e| {
        const role: usize = @intCast(e.key_ptr.* & 7);
        try p.raw.put(gpa, e.key_ptr.*, profileOf(e.value_ptr.*, p.role_raw[role]));
    }
    if (permute != 0) {
        var rng: std.Random.DefaultPrng = .init(permute);
        for (0..5) |role| {
            var keys: std.ArrayList(u64) = .empty;
            defer keys.deinit(gpa);
            var vals: std.ArrayList([nv]f64) = .empty;
            defer vals.deinit(gpa);
            var pit = p.raw.iterator();
            while (pit.next()) |e| if ((e.key_ptr.* & 7) == role) {
                try keys.append(gpa, e.key_ptr.*);
                try vals.append(gpa, e.value_ptr.*);
            };
            std.mem.sort(u64, keys.items, {}, std.sort.asc(u64));
            for (keys.items, 0..) |k, j| vals.items[j] = p.raw.get(k).?;
            rng.random().shuffle([nv]f64, vals.items);
            for (keys.items, vals.items) |k, v| try p.raw.put(gpa, k, v);
        }
    }
    // Role means, sds and cuts over fit picks
    var sum: [5][nv]f64 = @splat(@splat(0));
    var sq: [5][nv]f64 = @splat(@splat(0));
    var n: [5]f64 = @splat(0);
    var all: [nv]std.ArrayList(f64) = @splat(.empty);
    defer for (&all) |*a| a.deinit(gpa);
    for (d.rows) |r| {
        if (!fit.has(d.games[r.game])) continue;
        const role: usize = @backingInt(r.role);
        const x = p.raw_of(r.champion, role);
        n[role] += 1;
        for (x, 0..) |v, k| {
            sum[role][k] += v;
            sq[role][k] += v * v;
            try all[k].append(gpa, v);
        }
    }
    for (0..5) |role| for (0..nv) |k| {
        const m = sum[role][k] / @max(n[role], 1);
        p.role_mean[role][k] = m;
        p.role_sd[role][k] = @sqrt(@max(sq[role][k] / @max(n[role], 1) - m * m, 0));
    };
    for (&all, &p.cut) |*a, *c| {
        std.mem.sort(f64, a.items, {}, std.sort.asc(f64));
        c.* = if (a.items.len == 0) 0 else a.items[@trunc(@as(f64, @floatFromInt(a.items.len)) * (1 - top_share))];
    }
    return p;
}

/// The average of the won and lost halves' means, each shrunk to `prior` (the role's)
fn profileOf(c: Cell, prior: ?[nv]f64) [nv]f64 {
    var out: [nv]f64 = undefined;
    for (&out, 0..) |*o, k| {
        var halves: [2]f64 = undefined;
        for (&halves, 0..) |*h, w| {
            if (prior) |pr| {
                h.* = (c.sum[w][k] + shrink_rows * pr[k]) / (c.n[w][k] + shrink_rows);
            } else {
                h.* = if (c.n[w][k] > 0) c.sum[w][k] / c.n[w][k] else 0;
            }
        }
        o.* = 0.5 * (halves[0] + halves[1]);
    }
    const half = 0.5 * shrink_games;
    const long = (c.wins[0] + half) / (c.games[0] + shrink_games);
    const short = (c.wins[1] + half) / (c.games[1] + shrink_games);
    out[vi(.scaling)] = long - short;
    return out;
}

/// Fit games of a fold: visible in .dev and older than `before`
pub const Fit = struct {
    c: harness.Cuts,
    before: i64,

    pub fn has(f: Fit, g: rows.Game) bool {
        return harness.visible(.dev, f.c, g) and g.start < f.before;
    }
};

// ---------------------------------------------------------------- statistics

/// Two-sided normal p
pub fn pOf(z: f64) f64 {
    return erfc(@abs(z) / std.math.sqrt2);
}

/// Numerical Recipes' erfc (fractional error under 1.2e-7)
fn erfc(x: f64) f64 {
    const z = @abs(x);
    const t = 1 / (1 + 0.5 * z);
    const ans = t * @exp(-z * z - 1.26551223 + t * (1.00002368 + t * (0.37409196 + t * (0.09678418 +
        t * (-0.18628806 + t * (0.27886807 + t * (-1.13520398 + t * (1.48851587 +
            t * (-0.82215223 + t * 0.17087277)))))))));
    return if (x >= 0) ans else 2 - ans;
}

/// Benjamini-Hochberg: how many of p pass at level q
fn bhCount(gpa: Allocator, p: []const f64, q: f64) !usize {
    const s = try gpa.dupe(f64, p);
    defer gpa.free(s);
    for (s) |*x| if (std.math.isNan(x.*)) {
        x.* = 1;
    };
    std.mem.sort(f64, s, {}, std.sort.asc(f64));
    const m: f64 = @floatFromInt(s.len);
    var k: usize = 0;
    for (s, 1..) |x, i| if (x <= @as(f64, @floatFromInt(i)) * q / m) {
        k = i;
    };
    return k;
}

/// BH threshold p at level q (pass when p <= it), 0 when none pass
pub fn bhThreshold(gpa: Allocator, p: []const f64, q: f64) !f64 {
    const k = try bhCount(gpa, p, q);
    if (k == 0) return 0;
    const m: f64 = @floatFromInt(p.len);
    return @as(f64, @floatFromInt(k)) * q / m;
}

const nan32 = std.math.nan(f32);

pub const Placed = struct { seats: usize, teams: usize };

/// Bump when parseExtra's output changes through code outside compstats.zig
const extra_version = 1;

test "comp_stats cache round trip keeps present and absent values" {
    var extra = [_]?compstats.Seat{ null, @splat(1.5), null };
    extra[1].?[0] = std.math.nan(f32);
    var teams = [_]?[2]compstats.Team{ .{ @splat(2), @splat(3) }, null };
    var c: ExtraCache = .{ .extra = &extra, .teams = &teams, .placed = .{ .seats = 1, .teams = 1 } };
    var buf: [4096]u8 = undefined;
    var w: Io.Writer = .fixed(&buf);
    try ExtraCache.write(&c, &w);
    var extra2: [3]?compstats.Seat = @splat(@splat(9));
    var teams2: [2]?[2]compstats.Team = @splat(null);
    var c2: ExtraCache = .{ .extra = &extra2, .teams = &teams2 };
    var r: Io.Reader = .fixed(w.buffered());
    try ExtraCache.read(&c2, &r);
    try testing.expectEqual(c.placed, c2.placed);
    try testing.expect(extra2[0] == null and extra2[2] == null and teams2[1] == null);
    try testing.expectEqualSlices(u8, std.mem.asBytes(&extra[1].?), std.mem.asBytes(&extra2[1].?));
    try testing.expectEqualSlices(u8, std.mem.asBytes(&teams[0].?), std.mem.asBytes(&teams2[0].?));
}

/// SNAP's comp_stats.tsv into extra (by row) and comp_teams.tsv into teams (by game);
/// NaN where a line has no value, null where there is no line. Parsing the 1.3 GB of
/// text took most of a minute: the result is cached beside the snapshot (snapcache
/// "compstats"), keyed by both files' stamps, the rows' games and slots, compstats.zig
pub fn loadExtra(
    gpa: Allocator,
    io: Io,
    d: *const rows.Data,
    data_path: []const u8,
    extra: []?compstats.Seat,
    team_obj: []?[2]compstats.Team,
) !Placed {
    var h: std.hash.Wyhash = .init(extra_version);
    h.update(@embedFile("compstats.zig"));
    try snapcache.stamp(gpa, io, &h, data_path, compstats.seat_file);
    try snapcache.stamp(gpa, io, &h, data_path, compstats.team_file);
    for (d.games) |g| {
        h.update(g.match_id);
        h.update(std.mem.asBytes(&g.start));
    }
    for (d.rows) |r| {
        h.update(std.mem.asBytes(&r.game));
        h.update(std.mem.asBytes(&r.slot));
    }
    const key = h.final();
    var c: ExtraCache = .{ .extra = extra, .teams = team_obj };
    if (try snapcache.load(gpa, io, data_path, "compstats", key, &c, ExtraCache.read)) return c.placed;
    c.placed = try parseExtra(gpa, io, d, data_path, extra, team_obj);
    snapcache.save(gpa, io, data_path, "compstats", key, &c, ExtraCache.write);
    return c.placed;
}

/// Counts, then per row and per game a present byte and, if 1, the values
const ExtraCache = struct {
    extra: []?compstats.Seat,
    teams: []?[2]compstats.Team,
    placed: Placed = .{ .seats = 0, .teams = 0 },

    fn read(c: *ExtraCache, r: *Io.Reader) !void {
        var counts: [2]u64 = undefined;
        try r.readSliceAll(std.mem.sliceAsBytes(&counts));
        c.placed = .{ .seats = counts[0], .teams = counts[1] };
        for (c.extra) |*e| {
            e.* = null;
            if (try r.takeByte() == 0) continue;
            // A value, not `undefined`: that leaves the optional's flag unset too
            var v: compstats.Seat = undefined;
            try r.readSliceAll(std.mem.asBytes(&v));
            e.* = v;
        }
        for (c.teams) |*t| {
            t.* = null;
            if (try r.takeByte() == 0) continue;
            var v: [2]compstats.Team = undefined;
            try r.readSliceAll(std.mem.asBytes(&v));
            t.* = v;
        }
    }

    fn write(c: *ExtraCache, w: *Io.Writer) !void {
        const counts = [2]u64{ c.placed.seats, c.placed.teams };
        try w.writeAll(std.mem.sliceAsBytes(&counts));
        for (c.extra) |e| if (e) |v| {
            try w.writeByte(1);
            try w.writeAll(std.mem.asBytes(&v));
        } else try w.writeByte(0);
        for (c.teams) |t| if (t) |v| {
            try w.writeByte(1);
            try w.writeAll(std.mem.asBytes(&v));
        } else try w.writeByte(0);
    }
};

fn parseExtra(
    gpa: Allocator,
    io: Io,
    d: *const rows.Data,
    data_path: []const u8,
    extra: []?compstats.Seat,
    team_obj: []?[2]compstats.Team,
) !Placed {
    @memset(extra, null);
    @memset(team_obj, null);
    var index: std.AutoHashMapUnmanaged(u64, u32) = .empty;
    defer index.deinit(gpa);
    for (d.games, 0..) |g, gi| try index.put(gpa, std.hash.Wyhash.hash(0, g.match_id), @intCast(gi));
    const by_slot = try gpa.alloc([10]u32, d.games.len);
    defer gpa.free(by_slot);
    @memset(by_slot, @splat(std.math.maxInt(u32)));
    for (d.rows, 0..) |r, ri| if (r.slot < 10) {
        by_slot[r.game][r.slot] = @intCast(ri);
    };
    const SeatSink = struct {
        index: *const std.AutoHashMapUnmanaged(u64, u32),
        by_slot: []const [10]u32,
        extra: []?compstats.Seat,
        pub fn at(s: @This(), match_id: []const u8, slot: u8) ?*compstats.Seat {
            const gi = s.index.get(std.hash.Wyhash.hash(0, match_id)) orelse return null;
            if (slot >= 10 or s.by_slot[gi][slot] == std.math.maxInt(u32)) return null;
            const e = &s.extra[s.by_slot[gi][slot]];
            e.* = @splat(nan32);
            return &e.*.?;
        }
    };
    const seats = try compstats.fill(io, data_path, .seat, SeatSink{ .index = &index, .by_slot = by_slot, .extra = extra }) orelse
        return error.NoCompStats;
    const TeamSink = struct {
        index: *const std.AutoHashMapUnmanaged(u64, u32),
        teams: []?[2]compstats.Team,
        pub fn at(s: @This(), match_id: []const u8, side: u8) ?*compstats.Team {
            const gi = s.index.get(std.hash.Wyhash.hash(0, match_id)) orelse return null;
            if (side > 1) return null;
            if (s.teams[gi] == null) s.teams[gi] = .{ @splat(nan32), @splat(nan32) };
            return &s.teams[gi].?[side];
        }
    };
    const teams = try compstats.fill(io, data_path, .team, TeamSink{ .index = &index, .teams = team_obj }) orelse
        return error.NoCompStats;
    return .{ .seats = seats, .teams = teams };
}

/// Gauss-Jordan inverse of a k x k matrix (small, well conditioned by construction)
pub fn invert(gpa: Allocator, a_in: []const f64, k: usize) ![]f64 {
    const a = try gpa.dupe(f64, a_in);
    defer gpa.free(a);
    const inv = try gpa.alloc(f64, k * k);
    errdefer gpa.free(inv);
    @memset(inv, 0);
    for (0..k) |i| inv[i * k + i] = 1;
    for (0..k) |col| {
        var piv = col;
        for (col + 1..k) |r| if (@abs(a[r * k + col]) > @abs(a[piv * k + col])) {
            piv = r;
        };
        if (piv != col) for (0..k) |j| {
            std.mem.swap(f64, &a[col * k + j], &a[piv * k + j]);
            std.mem.swap(f64, &inv[col * k + j], &inv[piv * k + j]);
        };
        const d = a[col * k + col];
        if (@abs(d) < 1e-12) return error.SingularMatrix;
        for (0..k) |j| {
            a[col * k + j] /= d;
            inv[col * k + j] /= d;
        }
        for (0..k) |r| {
            if (r == col) continue;
            const f = a[r * k + col];
            if (f == 0) continue;
            for (0..k) |j| {
                a[r * k + j] -= f * a[col * k + j];
                inv[r * k + j] -= f * inv[col * k + j];
            }
        }
    }
    return inv;
}

const testing = std.testing;

test "comps: BH and erfc" {
    try testing.expectApproxEqAbs(@as(f64, 0.05), pOf(1.959964), 1e-5);
    try testing.expectApproxEqAbs(@as(f64, 2.0), erfc(-10), 1e-9);
    // BH: 0.001 and 0.01 pass at q 0.05 among 4 (0.0125, 0.025), 0.04 doesn't (0.0375)
    const p = [_]f64{ 0.04, 0.001, 0.9, 0.01 };
    try testing.expectEqual(@as(usize, 2), try bhCount(testing.allocator, &p, 0.05));
}

test "comps: invert" {
    const gpa = testing.allocator;
    const m = [_]f64{ 4, 7, 2, 6 };
    const inv = try invert(gpa, &m, 2);
    defer gpa.free(inv);
    try testing.expectApproxEqAbs(@as(f64, 0.6), inv[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, -0.7), inv[1], 1e-12);
    try testing.expectError(error.SingularMatrix, invert(gpa, &.{ 1, 2, 2, 4 }, 2));
}

test "comps: profiles average won and lost halves, shrink to the role" {
    var c: Cell = .{};
    const k = vi(.build_pm);
    // Won: 10 rows at 300; lost: 10 rows at 100; role prior 200 -> halves 250, 150
    c.sum[0][k] = 3000;
    c.n[0][k] = 10;
    c.sum[1][k] = 1000;
    c.n[1][k] = 10;
    var prior: [nv]f64 = @splat(0);
    prior[k] = 200;
    const p = profileOf(c, prior);
    try testing.expectApproxEqAbs(@as(f64, 7000.0 / 30.0 * 0.5 + 5000.0 / 30.0 * 0.5), p[k], 1e-9);
    // Scaling with no games: both rates 0.5
    try testing.expectApproxEqAbs(@as(f64, 0), p[vi(.scaling)], 1e-12);
}
