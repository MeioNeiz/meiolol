//! `meiolol-lab comps SNAP`: comp discovery (docs/model.md "Comp discovery"). Which team
//! traits and team-vs-team matchups win beyond the champions themselves. Built with
//! -Dcand=src/lab/cand/win-ratings: its predictions are the offset, as compcheck's.
//!
//! Champion-role profiles (~60 numbers: damage mix, frontline, CC, peel, siege, vision,
//! objectives, waveclear, fights, roams, items, early power, scaling) from fit games only,
//! per fold: each the average of the champion-role's mean in won and in lost games (end of
//! game stats lean to the winner), shrunk to the role mean, then z within role. A team
//! sum of a profile is linear in the champions, so ratings already hold it: candidates are
//! non-linear team traits (max, min, flags, shares, concentration), cross-team products
//! and archetype matchups; a few sums stay in as controls (expected ~0).
//!
//! Per game: blue's residual (won minus ratings' chance) against x = trait(blue) -
//! trait(red); slope in win pp per team sd (flags: pp for having it), robust se, games
//! independent. Folds are win-comp's blocks (nnexport.foldBounds); each refits ratings and
//! profiles on older games. --screen scores blocks 1-3 only: Benjamini-Hochberg over every
//! candidate, shuffled residuals as a control, mechanism outcomes beside (gold at 14,
//! objectives, win by game length). --confirm FILE opens the sealed blocks 4-5 and dev-val
//! for the names in FILE only, with a joint fit and a logistic comp layer's log loss.
//! Writes screen.tsv / confirm.tsv and archetypes.tsv in the working directory

const std = @import("std");
const api = @import("api");
const cand = @import("cand");
const rows = @import("rows.zig");
const protocol = @import("protocol.zig");
const harness = @import("harness.zig");
const seatstats = @import("seatstats.zig");
const compstats = @import("compstats.zig");
const compcheck = @import("compcheck.zig");
const nnexport = @import("nnexport.zig");
const synth = @import("synth.zig");

const Io = std.Io;
const Allocator = std.mem.Allocator;
const S = seatstats.SeatStat;

pub const usage =
    \\  comps SNAP --screen [--shuffles N] [--carry FILE] [--permute-profiles SEED]
    \\                                  comp discovery, dev only, built with
    \\                                  -Dcand=src/lab/cand/win-ratings: team traits and
    \\                                  matchups against ratings' residual on win-comp's
    \\                                  fold blocks 1-3, FDR over all, shuffle control,
    \\                                  mechanism outcomes (lab/comps.zig). SNAP may be
    \\                                  plant:SPEC:PATH (minimum detectable effect);
    \\                                  --permute-profiles: profiles shuffled among a
    \\                                  role's champions, a control (expect ~0 passes)
    \\  comps SNAP --export-teams         every team of blocks 1-5 and dev-val with its
    \\                                  archetype and traits (profiles from games before
    \\                                  its block, no outcomes): teams.tsv
    \\  comps SNAP --confirm FILE [--carry FILE] [--seen IDS]
    \\                                  the sealed blocks 4-5 and dev-val, for the
    \\                                  candidate names in FILE only (pre-declared);
    \\                                  --seen: match ids (one a line) an earlier
    \\                                  look already scored, left out of the sealed
    \\                                  blocks
    \\
;

/// Profile values per champion-role
const V = enum {
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
const nv = @typeInfo(V).@"enum".field_names.len;
const v_names = @typeInfo(V).@"enum".field_names;

fn vi(v: V) usize {
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

fn cellKey(champion: u32, role: usize) u64 {
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
const Profiles = struct {
    raw: std.AutoHashMapUnmanaged(u64, [nv]f64) = .empty,
    role_raw: [5][nv]f64 = undefined,
    role_mean: [5][nv]f64 = undefined,
    role_sd: [5][nv]f64 = undefined,
    /// Top-share cut of raw values over fit picks, all roles
    cut: [nv]f64 = undefined,
    /// Optional carry columns (meiolol-61), z within role; [cell] -> values
    carry: std.AutoHashMapUnmanaged(u64, []const f64) = .empty,

    fn deinit(p: *Profiles, gpa: Allocator) void {
        p.raw.deinit(gpa);
        p.carry.deinit(gpa);
    }

    fn raw_of(p: *const Profiles, champion: u32, role: usize) [nv]f64 {
        return p.raw.get(cellKey(champion, role)) orelse p.role_raw[role];
    }

    fn z(p: *const Profiles, role: usize, x: [nv]f64) [nv]f64 {
        var out: [nv]f64 = undefined;
        for (&out, x, p.role_mean[role], p.role_sd[role]) |*o, a, m, s| o.* = if (s > 0) (a - m) / s else 0;
        return out;
    }
};

/// permute: nonzero shuffles the profiles among champion-roles of a role (a control:
/// traits become arbitrary functions of the champions)
fn buildProfiles(gpa: Allocator, d: *const rows.Data, extra: []const ?compstats.Seat, fit: Fit, permute: u64) !Profiles {
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
        c.* = if (a.items.len == 0) 0 else a.items[@intFromFloat(@as(f64, @floatFromInt(a.items.len)) * (1 - top_share))];
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
const Fit = struct {
    c: harness.Cuts,
    before: i64,

    fn has(f: Fit, g: rows.Game) bool {
        return harness.visible(.dev, f.c, g) and g.start < f.before;
    }
};

// ---------------------------------------------------------------- team traits

/// Team aggregates used by cross-team terms and archetypes (sums of role z unless noted)
const Agg = enum {
    magic_share,
    phys_share,
    true_share,
    heal,
    sustain,
    antiheal,
    armour_lean,
    range,
    engage,
    disengage,
    peel,
    dive,
    pick,
    tank,
    front,
    pen,
    early,
    scaling,
    split,
    siege,
    wave,
    lane,
    vision,
    roam,
    conc,
};
const n_agg = @typeInfo(Agg).@"enum".field_names.len;

const Team = struct {
    raw: [5][nv]f64,
    z: [5][nv]f64,
    agg: [n_agg]f64,
    /// Carry columns' role z per seat (empty without --carry)
    carry: [5][]const f64,
};

fn sumZ(t: *const Team, vs: []const V) f64 {
    var s: f64 = 0;
    for (t.z) |zr| for (vs) |v| {
        s += zr[vi(v)];
    };
    return s;
}

fn maxZ(t: *const Team, v: V) f64 {
    var m: f64 = -std.math.inf(f64);
    for (t.z) |zr| m = @max(m, zr[vi(v)]);
    return m;
}

fn countAbove(t: *const Team, v: V, cut: f64) f64 {
    var n: f64 = 0;
    for (t.raw) |r| n += @floatFromInt(@intFromBool(r[vi(v)] >= cut));
    return n;
}

fn countZAbove(t: *const Team, vs: []const V, cut: f64) usize {
    var n: usize = 0;
    for (t.z) |zr| n += @intFromBool(for (vs) |v| {
        if (zr[vi(v)] >= cut) break true;
    } else false);
    return n;
}

fn makeTeam(p: *const Profiles, champs: [5]u32) Team {
    var t: Team = undefined;
    var phys: f64 = 0;
    var magic: f64 = 0;
    var tru: f64 = 0;
    const no_carry: []const f64 = &.{};
    for (champs, 0..) |c, role| {
        t.raw[role] = p.raw_of(c, role);
        t.z[role] = p.z(role, t.raw[role]);
        t.carry[role] = p.carry.get(cellKey(c, role)) orelse no_carry;
        phys += t.raw[role][vi(.phys_dpm)];
        magic += t.raw[role][vi(.magic_dpm)];
        tru += t.raw[role][vi(.true_dpm)];
    }
    const dmg = phys + magic + tru;
    var a: [n_agg]f64 = undefined;
    a[@backingInt(Agg.magic_share)] = magic / dmg;
    a[@backingInt(Agg.phys_share)] = phys / dmg;
    a[@backingInt(Agg.true_share)] = tru / dmg;
    a[@backingInt(Agg.heal)] = sumZ(&t, &.{ .selfheal_pm, .ally_pm });
    a[@backingInt(Agg.sustain)] = sumZ(&t, &.{.selfheal_pm});
    var antiheal: f64 = 0;
    var pen: f64 = 0;
    for (t.raw) |r| {
        antiheal += r[vi(.antiheal)];
        pen += r[vi(.armour_pen)] + r[vi(.magic_pen)] + r[vi(.lethality)];
    }
    a[@backingInt(Agg.antiheal)] = antiheal;
    a[@backingInt(Agg.pen)] = pen;
    a[@backingInt(Agg.armour_lean)] = sumZ(&t, &.{.armour_lean});
    a[@backingInt(Agg.range)] = sumZ(&t, &.{.range});
    a[@backingInt(Agg.engage)] = sumZ(&t, &.{ .immob_kills, .knock_kills, .immob_pm });
    a[@backingInt(Agg.disengage)] = sumZ(&t, &.{ .save_ally, .cc_pm });
    a[@backingInt(Agg.peel)] = sumZ(&t, &.{ .ally_pm, .save_ally });
    a[@backingInt(Agg.dive)] = sumZ(&t, &.{ .dive_kills, .outnumbered });
    a[@backingInt(Agg.pick)] = sumZ(&t, &.{ .hidden_kills, .pick_kills });
    a[@backingInt(Agg.tank)] = sumZ(&t, &.{ .tank_share, .taken_pm });
    a[@backingInt(Agg.front)] = countAbove(&t, .taken_share, p.cut[vi(.taken_share)]);
    a[@backingInt(Agg.early)] = sumZ(&t, &.{ .gold14, .early_td, .lanediff14 }) / 3;
    a[@backingInt(Agg.scaling)] = sumZ(&t, &.{.scaling});
    a[@backingInt(Agg.split)] = maxZ(&t, .solo_turrets);
    a[@backingInt(Agg.siege)] = sumZ(&t, &.{ .build_pm, .range });
    // twentyMinionsIn3SecondsCount is 0 in all but ~1 in 200k seats: minions per minute instead
    a[@backingInt(Agg.wave)] = sumZ(&t, &.{.cs_pm});
    a[@backingInt(Agg.lane)] = sumZ(&t, &.{.lane_cs10});
    a[@backingInt(Agg.vision)] = sumZ(&t, &.{.vision_pm});
    a[@backingInt(Agg.roam)] = sumZ(&t, &.{.roam});
    var conc: f64 = 0;
    for (t.raw) |r| conc = @max(conc, r[vi(.dmg_share)]);
    a[@backingInt(Agg.conc)] = conc;
    t.agg = a;
    return t;
}

fn agg(t: *const Team, a: Agg) f64 {
    return t.agg[@backingInt(a)];
}

/// Profile values that get "has one" / "has two" flags (top share of picks). Not vision or
/// epic damage: the support and the jungler always hold the top share, so no team differs
const flag_vars = [_]V{
    .taken_share,  .tank_share,  .immob_kills,  .knock_kills, .ally_pm,    .save_ally,
    .solo_turrets, .dive_kills,  .hidden_kills, .antiheal,    .armour_pen, .magic_pen,
    .true_share,   .range,       .scaling,      .early_td,    .build_pm,   .roam,
    .dmg_share,    .selfheal_pm, .immob_pm,
};
/// Sums kept as controls: additive in the champions, so ratings should hold them (~0)
const control_vars = [_]V{ .magic_dpm, .taken_pm, .cc_pm, .ally_pm, .build_pm, .gold14, .scaling, .vision_pm };

const Special = enum {
    /// win-comp's mix: (team magic share - 0.5)^2
    mix,
    lopsided,
    magic_lo,
    magic_hi,
    phys_hi,
    /// Herfindahl of the team's damage per minute over its five seats
    dmg_hhi,
    ranged4,
    melee4,
    /// Early (gold at 14, early takedowns, lane lead) and scaling both weak
    no_wincon,
    /// |early - scaling| in team sd: a one-dimensional power curve
    one_curve,
    early_x_late,
    /// A frontline, an enchanter and a bottom laner above the role's damage share
    front_to_back,
    /// A frontline and an engage, nothing to protect
    hard_engage,
    /// No seat 1+ role sd above its role in epic monster damage, dragons or heralds
    no_objective,
};

const Cross = struct { own: Agg, enemy: Agg, hyp: i8, label: []const u8 };
/// Coaching win conditions as own trait x enemy trait (hyp: the sign theory predicts)
const crosses = [_]Cross{
    .{ .own = .heal, .enemy = .antiheal, .hyp = -1, .label = "our healing x their anti-heal" },
    .{ .own = .phys_share, .enemy = .armour_lean, .hyp = -1, .label = "our AD share x their armour lean" },
    .{ .own = .magic_share, .enemy = .armour_lean, .hyp = 1, .label = "our AP share x their armour lean" },
    .{ .own = .range, .enemy = .engage, .hyp = -1, .label = "our range (poke) x their engage" },
    .{ .own = .scaling, .enemy = .early, .hyp = 0, .label = "our scaling x their early power" },
    .{ .own = .split, .enemy = .wave, .hyp = -1, .label = "our split push x their waveclear" },
    .{ .own = .dive, .enemy = .peel, .hyp = -1, .label = "our dive x their peel" },
    .{ .own = .front, .enemy = .true_share, .hyp = -1, .label = "our frontline count x their true damage" },
    .{ .own = .tank, .enemy = .pen, .hyp = -1, .label = "our tankiness x their penetration items" },
    .{ .own = .pick, .enemy = .vision, .hyp = -1, .label = "our pick potential x their vision" },
    .{ .own = .siege, .enemy = .wave, .hyp = -1, .label = "our siege x their waveclear" },
    .{ .own = .engage, .enemy = .disengage, .hyp = -1, .label = "our engage x their disengage" },
    .{ .own = .conc, .enemy = .dive, .hyp = -1, .label = "our carry concentration x their dive" },
    .{ .own = .conc, .enemy = .pick, .hyp = -1, .label = "our carry concentration x their pick" },
    .{ .own = .magic_share, .enemy = .tank, .hyp = 0, .label = "our AP share x their tankiness" },
    .{ .own = .lane, .enemy = .roam, .hyp = 0, .label = "our lane waveclear x their roams" },
    .{ .own = .sustain, .enemy = .range, .hyp = 1, .label = "our sustain x their poke (range)" },
    .{ .own = .engage, .enemy = .range, .hyp = 1, .label = "our engage x their poke (range)" },
    .{ .own = .scaling, .enemy = .dive, .hyp = 0, .label = "our scaling x their dive" },
    .{ .own = .early, .enemy = .vision, .hyp = 0, .label = "our early power x their vision" },
    .{ .own = .front, .enemy = .magic_share, .hyp = 0, .label = "our frontline count x their AP share" },
};

const Kind = union(enum) {
    max: V,
    min: V,
    sum: V,
    has: struct { v: V, k: u8 },
    special: Special,
    cross: usize,
    arch: u8,
    arch_pair: [2]u8,
    carry_max: usize,
    carry_conc: usize,
    carry_has2: usize,
    carry_none: usize,
};

const Cand = struct {
    name: []const u8,
    family: []const u8,
    kind: Kind,
    /// Coaching hypothesis' predicted sign, 0 none
    hyp: i8 = 0,
    control: bool = false,
    /// Flags read as pp for having it; others per team sd
    flag: bool = false,
};

fn candidates(arena: Allocator, n_arch: u8, carry_cols: []const []const u8) ![]Cand {
    var out: std.ArrayList(Cand) = .empty;
    for (v_names, 0..) |n, k| {
        const v: V = @fromBackingInt(@as(@typeInfo(V).@"enum".tag_type, @intCast(k)));
        try out.append(arena, .{ .name = try arena.print("max {s}", .{n}), .family = "max", .kind = .{ .max = v } });
        try out.append(arena, .{ .name = try arena.print("min {s}", .{n}), .family = "min", .kind = .{ .min = v } });
    }
    for (flag_vars) |v| for ([_]u8{ 1, 2 }) |k| {
        try out.append(arena, .{
            .name = try arena.print("{d}+ top {s}", .{ k, @tagName(v) }),
            .family = "flag",
            .kind = .{ .has = .{ .v = v, .k = k } },
            .flag = true,
        });
    };
    for (control_vars) |v| try out.append(arena, .{
        .name = try arena.print("sum {s}", .{@tagName(v)}),
        .family = "control",
        .kind = .{ .sum = v },
        .control = true,
    });
    const specials = [_]struct { Special, i8, bool }{
        .{ .mix, -1, false },       .{ .lopsided, -1, true },     .{ .magic_lo, -1, true },
        .{ .magic_hi, -1, true },   .{ .phys_hi, -1, true },      .{ .dmg_hhi, 0, false },
        .{ .ranged4, 0, true },     .{ .melee4, 0, true },        .{ .no_wincon, -1, true },
        .{ .one_curve, 0, false },  .{ .early_x_late, 0, false }, .{ .front_to_back, 1, true },
        .{ .hard_engage, 1, true }, .{ .no_objective, -1, true },
    };
    for (specials) |s| try out.append(arena, .{
        .name = @tagName(s[0]),
        .family = "special",
        .kind = .{ .special = s[0] },
        .hyp = s[1],
        .flag = s[2],
    });
    for (crosses, 0..) |c, i| try out.append(arena, .{ .name = c.label, .family = "cross", .kind = .{ .cross = i }, .hyp = c.hyp });
    for (0..n_arch) |a| try out.append(arena, .{
        .name = try arena.print("archetype {d}", .{a}),
        .family = "archetype",
        .kind = .{ .arch = @intCast(a) },
        .flag = true,
    });
    for (0..n_arch) |a| for (a + 1..n_arch) |b| try out.append(arena, .{
        .name = try arena.print("archetype {d} vs {d}", .{ a, b }),
        .family = "archetype pair",
        .kind = .{ .arch_pair = .{ @intCast(a), @intCast(b) } },
        .flag = true,
    });
    for (carry_cols, 0..) |n, i| {
        try out.append(arena, .{ .name = try arena.print("carry max {s}", .{n}), .family = "carry", .kind = .{ .carry_max = i } });
        try out.append(arena, .{ .name = try arena.print("carry concentration {s}", .{n}), .family = "carry", .kind = .{ .carry_conc = i } });
        try out.append(arena, .{ .name = try arena.print("carry 2+ top {s}", .{n}), .family = "carry", .kind = .{ .carry_has2 = i }, .flag = true });
        try out.append(arena, .{ .name = try arena.print("carry none above median {s}", .{n}), .family = "carry", .kind = .{ .carry_none = i }, .flag = true });
    }
    return out.items;
}

/// Team-level cuts from fit teams (for traits defined by quantiles)
const TeamCuts = struct {
    early_lo: f64 = 0,
    late_lo: f64 = 0,
    early_sd: f64 = 1,
    late_sd: f64 = 1,
    /// Carry columns' top-share cut of role z over fit picks
    carry_top: []const f64 = &.{},
};

fn trait(c: Cand, t: *const Team, p: *const Profiles, tc: *const TeamCuts) f64 {
    return switch (c.kind) {
        .max => |v| maxZ(t, v),
        .min => |v| blk: {
            var m: f64 = std.math.inf(f64);
            for (t.z) |zr| m = @min(m, zr[vi(v)]);
            break :blk m;
        },
        .sum => |v| sumZ(t, &.{v}),
        .has => |h| if (countAbove(t, h.v, p.cut[vi(h.v)]) >= @as(f64, @floatFromInt(h.k))) 1 else 0,
        .special => |s| special(s, t, p, tc),
        .carry_max => |i| blk: {
            var m: f64 = -std.math.inf(f64);
            for (t.carry) |cr| if (cr.len > i) {
                m = @max(m, cr[i]);
            };
            break :blk if (std.math.isInf(m)) 0 else m;
        },
        .carry_conc => |i| blk: {
            var m: f64 = -std.math.inf(f64);
            var s: f64 = 0;
            for (t.carry) |cr| {
                const x = if (cr.len > i) cr[i] else 0;
                m = @max(m, x);
                s += x;
            }
            break :blk m - s / 5;
        },
        .carry_has2 => |i| blk: {
            var n: u8 = 0;
            for (t.carry) |cr| n += @intFromBool(cr.len > i and cr[i] >= tc.carry_top[i]);
            break :blk if (n >= 2) 1 else 0;
        },
        .carry_none => |i| blk: {
            for (t.carry) |cr| if (cr.len > i and cr[i] > 0) break :blk 0;
            break :blk 1;
        },
        // Pairwise kinds are built in xOf
        .cross, .arch, .arch_pair => unreachable,
    };
}

fn special(s: Special, t: *const Team, p: *const Profiles, tc: *const TeamCuts) f64 {
    const f = agg(t, .magic_share);
    const b = struct {
        fn b(x: bool) f64 {
            return if (x) 1 else 0;
        }
    }.b;
    return switch (s) {
        .mix => (f - 0.5) * (f - 0.5),
        .lopsided => b(f < 0.2 or f >= 0.6),
        .magic_lo => b(f < 0.2),
        .magic_hi => b(f >= 0.6),
        .phys_hi => b(agg(t, .phys_share) >= 0.8),
        .dmg_hhi => blk: {
            var tot: f64 = 0;
            for (t.raw) |r| tot += r[vi(.phys_dpm)] + r[vi(.magic_dpm)] + r[vi(.true_dpm)];
            var h: f64 = 0;
            for (t.raw) |r| {
                const sh = (r[vi(.phys_dpm)] + r[vi(.magic_dpm)] + r[vi(.true_dpm)]) / tot;
                h += sh * sh;
            }
            break :blk h;
        },
        .ranged4, .melee4 => blk: {
            var n: u8 = 0;
            for (t.raw) |r| n += @intFromBool(r[vi(.range)] >= 300);
            break :blk b(if (s == .ranged4) n >= 4 else n <= 1);
        },
        .no_wincon => b(agg(t, .early) < tc.early_lo and agg(t, .scaling) < tc.late_lo),
        .one_curve => @abs(agg(t, .early) / tc.early_sd - agg(t, .scaling) / tc.late_sd),
        .early_x_late => agg(t, .early) / tc.early_sd * agg(t, .scaling) / tc.late_sd,
        .front_to_back => b(agg(t, .front) >= 1 and countAbove(t, .ally_pm, p.cut[vi(.ally_pm)]) >= 1 and
            t.z[@backingInt(api.Role.bottom)][vi(.dmg_share)] > 0),
        .hard_engage => b(agg(t, .front) >= 1 and countAbove(t, .immob_kills, p.cut[vi(.immob_kills)]) +
            countAbove(t, .knock_kills, p.cut[vi(.knock_kills)]) >= 1),
        .no_objective => b(countZAbove(t, &.{ .epic_pm, .dragon_td, .herald_td }, 1) == 0),
    };
}

/// Blue-minus-red difference for one candidate (antisymmetric under a side swap)
fn xOf(c: Cand, blue: *const Team, red: *const Team, arch: [2]u8, means: *const [n_agg]f64, p: *const Profiles, tc: *const TeamCuts) f64 {
    return switch (c.kind) {
        .cross => |i| blk: {
            const cr = crosses[i];
            const mo = means[@backingInt(cr.own)];
            const me = means[@backingInt(cr.enemy)];
            const g = struct {
                fn g(o: *const Team, e: *const Team, x: Cross, a: f64, bb: f64) f64 {
                    return (agg(o, x.own) - a) * (agg(e, x.enemy) - bb);
                }
            }.g;
            break :blk g(blue, red, cr, mo, me) - g(red, blue, cr, mo, me);
        },
        .arch => |a| @as(f64, @floatFromInt(@intFromBool(arch[0] == a))) - @as(f64, @floatFromInt(@intFromBool(arch[1] == a))),
        .arch_pair => |ab| @as(f64, @floatFromInt(@intFromBool(arch[0] == ab[0] and arch[1] == ab[1]))) -
            @as(f64, @floatFromInt(@intFromBool(arch[0] == ab[1] and arch[1] == ab[0]))),
        else => trait(c, blue, p, tc) - trait(c, red, p, tc),
    };
}

// ---------------------------------------------------------------- archetypes

const arch_aggs = [_]Agg{ .magic_share, .tank, .engage, .peel, .siege, .range, .early, .scaling, .dive, .pick, .wave, .roam };
const k_arch = 6;

const Archetypes = struct {
    mean: [arch_aggs.len]f64,
    sd: [arch_aggs.len]f64,
    centre: [k_arch][arch_aggs.len]f64,
    size: [k_arch]usize,

    fn vec(a: *const Archetypes, t: *const Team) [arch_aggs.len]f64 {
        var out: [arch_aggs.len]f64 = undefined;
        for (&out, arch_aggs, a.mean, a.sd) |*o, g, m, s| o.* = (agg(t, g) - m) / s;
        return out;
    }

    fn assign(a: *const Archetypes, t: *const Team) u8 {
        return nearest(&a.centre, a.vec(t));
    }
};

fn nearest(centre: *const [k_arch][arch_aggs.len]f64, x: [arch_aggs.len]f64) u8 {
    var best: u8 = 0;
    var bd = std.math.inf(f64);
    for (centre, 0..) |c, k| {
        var dd: f64 = 0;
        for (c, x) |a, b| dd += (a - b) * (a - b);
        if (dd < bd) {
            bd = dd;
            best = @intCast(k);
        }
    }
    return best;
}

/// k-means (k-means++ start, best of 5) on fit teams
fn fitArchetypes(gpa: Allocator, teams: []const Team) !Archetypes {
    var a: Archetypes = undefined;
    const n: f64 = @floatFromInt(teams.len);
    for (arch_aggs, 0..) |g, j| {
        var s: f64 = 0;
        var q: f64 = 0;
        for (teams) |*t| {
            s += agg(t, g);
            q += agg(t, g) * agg(t, g);
        }
        a.mean[j] = s / n;
        a.sd[j] = @sqrt(@max(q / n - a.mean[j] * a.mean[j], 1e-12));
    }
    const xs = try gpa.alloc([arch_aggs.len]f64, teams.len);
    defer gpa.free(xs);
    for (xs, teams) |*x, *t| x.* = a.vec(t);
    const lab = try gpa.alloc(u8, teams.len);
    defer gpa.free(lab);
    var rng: std.Random.DefaultPrng = .init(20261013);
    const rnd = rng.random();
    var best_cost = std.math.inf(f64);
    for (0..5) |_| {
        var centre: [k_arch][arch_aggs.len]f64 = undefined;
        centre[0] = xs[rnd.uintLessThan(usize, xs.len)];
        const dist = try gpa.alloc(f64, xs.len);
        defer gpa.free(dist);
        for (1..k_arch) |k| {
            var tot: f64 = 0;
            for (xs, dist) |x, *dd| {
                var m = std.math.inf(f64);
                for (centre[0..k]) |c| {
                    var e: f64 = 0;
                    for (c, x) |u, v| e += (u - v) * (u - v);
                    m = @min(m, e);
                }
                dd.* = m;
                tot += m;
            }
            var u = rnd.float(f64) * tot;
            var pick: usize = 0;
            for (dist, 0..) |dd, i| {
                u -= dd;
                if (u <= 0) {
                    pick = i;
                    break;
                }
            }
            centre[k] = xs[pick];
        }
        var cost: f64 = 0;
        for (0..100) |_| {
            var sum: [k_arch][arch_aggs.len]f64 = @splat(@splat(0));
            var cnt: [k_arch]f64 = @splat(0);
            cost = 0;
            for (xs, lab) |x, *l| {
                l.* = nearest(&centre, x);
                cnt[l.*] += 1;
                for (&sum[l.*], x) |*s, v| s.* += v;
                for (centre[l.*], x) |cc, v| cost += (cc - v) * (cc - v);
            }
            var moved = false;
            for (&centre, sum, cnt) |*c, s, m| {
                if (m == 0) continue;
                for (c, s) |*cc, v| {
                    const nw = v / m;
                    moved = moved or @abs(nw - cc.*) > 1e-9;
                    cc.* = nw;
                }
            }
            if (!moved) break;
        }
        if (cost < best_cost) {
            best_cost = cost;
            a.centre = centre;
        }
    }
    // Order clusters by size, largest first, so labels read the same across runs
    a.size = @splat(0);
    for (xs) |x| a.size[nearest(&a.centre, x)] += 1;
    var order: [k_arch]u8 = undefined;
    for (&order, 0..) |*o, i| o.* = @intCast(i);
    std.mem.sort(u8, &order, &a.size, struct {
        fn lt(sz: *const [k_arch]usize, x: u8, y: u8) bool {
            return sz[x] > sz[y];
        }
    }.lt);
    const centre = a.centre;
    const size = a.size;
    for (order, 0..) |o, i| {
        a.centre[i] = centre[o];
        a.size[i] = size[o];
    }
    return a;
}

// ---------------------------------------------------------------- units

/// Mechanism outcomes, own minus enemy (blue's view)
const Mech = enum { gold14, kills, first_blood, first_tower, first_dragon, first_herald, grubs, dragons, towers, barons };
const n_mech = @typeInfo(Mech).@"enum".field_names.len;

const Unit = struct {
    game: u32,
    /// 0-4 fold blocks, 5 dev-val
    block: u8,
    /// Blue won minus ratings' chance for blue
    resid: f64,
    p: f64,
    y: f64,
    minutes: f64,
    /// Mechanism outcomes minus their additive champion baseline (NaN unknown)
    mech: [n_mech]f64,
};

fn mechOf(d: *const rows.Data, gi: usize, teams: []const ?[2]compstats.Team, gold: []const [2]f64) [n_mech]f64 {
    var out: [n_mech]f64 = @splat(nan);
    out[@backingInt(Mech.gold14)] = gold[gi][0] - gold[gi][1];
    _ = d;
    const t = teams[gi] orelse return out;
    const col = compstats.teamCol;
    const pairs = [_]struct { Mech, usize }{
        .{ .kills, col(.champion, .kills) },          .{ .first_blood, col(.champion, .first) },
        .{ .first_tower, col(.tower, .first) },       .{ .first_dragon, col(.dragon, .first) },
        .{ .first_herald, col(.riftHerald, .first) }, .{ .grubs, col(.horde, .kills) },
        .{ .dragons, col(.dragon, .kills) },          .{ .towers, col(.tower, .kills) },
        .{ .barons, col(.baron, .kills) },
    };
    for (pairs) |pc| out[@backingInt(pc[0])] = t[0][pc[1]] - t[1][pc[1]];
    return out;
}

/// Additive champion-role baseline for each mechanism outcome, fitted on fit games:
/// per champion-role mean of own-minus-enemy, summed blue minus red, scaled by an OLS
/// slope on fit games
const MechBase = struct {
    cell: std.AutoHashMapUnmanaged(u64, [n_mech][2]f64) = .empty,
    slope: [n_mech]f64 = @splat(0),

    fn deinit(m: *MechBase, gpa: Allocator) void {
        m.cell.deinit(gpa);
    }

    fn pred(m: *const MechBase, g: rows.Game) [n_mech]f64 {
        var out: [n_mech]f64 = @splat(0);
        for (g.teams, 0..) |team, side| for (team, 0..) |c, role| {
            const e = m.cell.get(cellKey(c, role)) orelse continue;
            for (&out, e) |*o, se| {
                const a = se[0] / (se[1] + 50);
                o.* += if (side == 0) a else -a;
            }
        };
        for (&out, m.slope) |*o, s| o.* *= s;
        return out;
    }
};

fn fitMech(gpa: Allocator, d: *const rows.Data, fit: Fit, mech: []const [n_mech]f64) !MechBase {
    var m: MechBase = .{};
    errdefer m.deinit(gpa);
    for (d.games, 0..) |g, gi| {
        if (!fit.has(g)) continue;
        for (g.teams, 0..) |team, side| for (team, 0..) |c, role| {
            const e = try m.cell.getOrPutValue(gpa, cellKey(c, role), @splat(.{ 0, 0 }));
            for (e.value_ptr, mech[gi]) |*se, v| if (!std.math.isNan(v)) {
                se[0] += if (side == 0) v else -v;
                se[1] += 1;
            };
        };
    }
    m.slope = @splat(1);
    var sxy: [n_mech]f64 = @splat(0);
    var sxx: [n_mech]f64 = @splat(0);
    for (d.games, 0..) |g, gi| {
        if (!fit.has(g)) continue;
        const pr = m.pred(g);
        for (pr, mech[gi], &sxy, &sxx) |x, y, *a, *b| if (!std.math.isNan(y)) {
            a.* += x * y;
            b.* += x * x;
        };
    }
    for (&m.slope, sxy, sxx) |*s, a, b| s.* = if (b > 0) a / b else 0;
    return m;
}

// ---------------------------------------------------------------- statistics

const Slope = struct { beta: f64 = nan, se: f64 = nan, n: usize = 0 };

/// Games where the two teams differ that a slope needs: below it the robust se of a
/// rare flag collapses (a flag in two games gave z 175)
const min_differing = 200;

/// OLS slope of r on x with intercept, heteroscedasticity-robust se
fn slope(x: []const f64, r: []const f64, keep: ?[]const bool) Slope {
    var n: f64 = 0;
    var mx: f64 = 0;
    var mr: f64 = 0;
    var differ: usize = 0;
    for (x, r, 0..) |a, b, i| {
        if (std.math.isNan(a) or std.math.isNan(b)) continue;
        if (keep) |k| if (!k[i]) continue;
        n += 1;
        mx += a;
        mr += b;
        differ += @intFromBool(a != 0);
    }
    if (differ < min_differing) return .{ .n = @intFromFloat(n) };
    mx /= n;
    mr /= n;
    var sxx: f64 = 0;
    var sxr: f64 = 0;
    for (x, r, 0..) |a, b, i| {
        if (std.math.isNan(a) or std.math.isNan(b)) continue;
        if (keep) |k| if (!k[i]) continue;
        sxx += (a - mx) * (a - mx);
        sxr += (a - mx) * (b - mr);
    }
    if (sxx <= 0) return .{ .n = @intFromFloat(n) };
    const beta = sxr / sxx;
    var meat: f64 = 0;
    for (x, r, 0..) |a, b, i| {
        if (std.math.isNan(a) or std.math.isNan(b)) continue;
        if (keep) |k| if (!k[i]) continue;
        const e = b - mr - beta * (a - mx);
        meat += (a - mx) * (a - mx) * e * e;
    }
    return .{ .beta = beta, .se = @sqrt(meat * n / (n - 2)) / sxx, .n = @intFromFloat(n) };
}

/// Two-sided normal p
fn pOf(z: f64) f64 {
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
fn bhThreshold(gpa: Allocator, p: []const f64, q: f64) !f64 {
    const k = try bhCount(gpa, p, q);
    if (k == 0) return 0;
    const m: f64 = @floatFromInt(p.len);
    return @as(f64, @floatFromInt(k)) * q / m;
}

// ---------------------------------------------------------------- main

const Mode = enum { screen, confirm, export_teams };

pub fn main(gpa: Allocator, arena: Allocator, io: Io, argv: []const []const u8) !u8 {
    if (argv.len < 2) {
        std.debug.print("usage:\n{s}", .{usage});
        return 2;
    }
    if (!@hasDecl(cand, "name") or !std.mem.eql(u8, cand.name, "win-ratings")) {
        std.debug.print("comps: build with -Dcand=src/lab/cand/win-ratings (its predictions are the offset)\n", .{});
        return 2;
    }
    const snap = argv[0];
    var mode: ?Mode = null;
    var shuffles: usize = 20;
    var carry_path: ?[]const u8 = null;
    var confirm_path: ?[]const u8 = null;
    var seen_path: ?[]const u8 = null;
    var permute: u64 = 0;
    var i: usize = 1;
    while (i < argv.len) : (i += 1) {
        const a = argv[i];
        if (std.mem.eql(u8, a, "--screen")) {
            mode = .screen;
        } else if (std.mem.eql(u8, a, "--export-teams")) {
            mode = .export_teams;
        } else if (std.mem.eql(u8, a, "--confirm") and i + 1 < argv.len) {
            mode = .confirm;
            i += 1;
            confirm_path = argv[i];
        } else if (std.mem.eql(u8, a, "--shuffles") and i + 1 < argv.len) {
            i += 1;
            shuffles = try std.fmt.parseInt(usize, argv[i], 10);
        } else if (std.mem.eql(u8, a, "--permute-profiles") and i + 1 < argv.len) {
            i += 1;
            permute = try std.fmt.parseInt(u64, argv[i], 10);
        } else if (std.mem.eql(u8, a, "--carry") and i + 1 < argv.len) {
            i += 1;
            carry_path = argv[i];
        } else if (std.mem.eql(u8, a, "--seen") and i + 1 < argv.len) {
            i += 1;
            seen_path = argv[i];
        } else {
            std.debug.print("usage:\n{s}", .{usage});
            return 2;
        }
    }
    const m = mode orelse {
        std.debug.print("usage:\n{s}", .{usage});
        return 2;
    };
    const data_path = if (try synth.parseArg(snap)) |pa| pa.path else snap;

    var buf: [4096]u8 = undefined;
    var stdout = Io.File.stdout().writer(io, &buf);
    const w = &stdout.interface;

    var legendaries = try rows.loadLegendaries(gpa, io, snap);
    defer legendaries.deinit(gpa);
    var data = try rows.load(gpa, snap, &legendaries);
    defer data.deinit();
    const d = &data;
    const players = try harness.gamePlayers(gpa, d);
    defer gpa.free(players);
    const ids = protocol.platformIds();
    const eu: u8 = for (ids, 0..) |id, k| {
        if (std.mem.eql(u8, id, protocol.test_platform)) break @intCast(k);
    } else return error.TestPlatformNotScanned;
    const c = try harness.cuts(gpa, d, eu);
    const bounds = try nnexport.foldBounds(gpa, d, c);

    // comp_stats per row, comp_teams per game
    const extra = try gpa.alloc(?compstats.Seat, d.rows.len);
    defer gpa.free(extra);
    @memset(extra, null);
    const team_obj = try gpa.alloc(?[2]compstats.Team, d.games.len);
    defer gpa.free(team_obj);
    @memset(team_obj, null);
    {
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
        const placed = try compstats.fill(io, data_path, .seat, SeatSink{ .index = &index, .by_slot = by_slot, .extra = extra }) orelse
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
        const placed_t = try compstats.fill(io, data_path, .team, TeamSink{ .index = &index, .teams = team_obj }) orelse
            return error.NoCompStats;
        var with_stats: usize = 0;
        for (d.rows) |r| with_stats += @intFromBool(!std.math.isNan(r.stats[0]));
        try w.print("# comps ({s}{s}), {s}\nrows {d}: with seat stats {d}, comp_stats lines placed {d}; team lines {d}\n", .{
            @tagName(m), if (permute != 0) ", PERMUTED profiles" else "", snap, d.rows.len, with_stats, placed, placed_t,
        });
        if (with_stats == 0) return error.NoSeatStats;
    }

    // Team gold at 14 per game (all ten known), for the gold mechanism
    const gold = try gpa.alloc([2]f64, d.games.len);
    defer gpa.free(gold);
    @memset(gold, .{ 0, 0 });
    {
        const cnt = try gpa.alloc([2]u8, d.games.len);
        defer gpa.free(cnt);
        @memset(cnt, .{ 0, 0 });
        for (d.rows) |r| {
            const v = r.y[api.outcomeIndex(.gold14)];
            if (std.math.isNan(v)) continue;
            gold[r.game][r.side] += v;
            cnt[r.game][r.side] += 1;
        }
        for (gold, cnt) |*g, n| if (n[0] != 5 or n[1] != 5) {
            g.* = .{ nan, nan };
        };
    }
    const mech_raw = try gpa.alloc([n_mech]f64, d.games.len);
    defer gpa.free(mech_raw);
    for (mech_raw, 0..) |*mr, gi| mr.* = mechOf(d, gi, team_obj, gold);

    // Carry columns (meiolol-61): per fold, champion-role values
    var seen: std.StringHashMapUnmanaged(void) = .empty;
    if (seen_path) |sp| {
        const text = try Io.Dir.cwd().readFileAlloc(io, sp, arena, .unlimited);
        var it = std.mem.tokenizeAny(u8, text, "\r\n");
        while (it.next()) |id| try seen.put(arena, id, {});
    }
    var carry: Carry = .{};
    if (carry_path) |cp| carry = try loadCarry(arena, io, cp);
    const cands = try candidates(arena, k_arch, carry.cols);
    try w.print("candidates {d}; fold bounds {any}, dev cut {d}\n", .{ cands.len, bounds[0..5], c.dev });

    // Archetypes from block 1's fit teams (older than every scored game)
    const arch = blk: {
        const fit: Fit = .{ .c = c, .before = bounds[0] };
        var p = try buildProfiles(gpa, d, extra, fit, permute);
        defer p.deinit(gpa);
        var teams: std.ArrayList(Team) = .empty;
        defer teams.deinit(gpa);
        for (d.games) |g| if (fit.has(g)) for (g.teams) |t| try teams.append(gpa, makeTeam(&p, t));
        const a = try fitArchetypes(gpa, teams.items);
        try writeArchetypes(io, &a, w);
        break :blk a;
    };

    if (m == .export_teams) {
        try exportTeams(gpa, arena, io, d, extra, c, bounds, &arch, permute, w);
        try w.flush();
        return 0;
    }

    // Blocks: screen 0-2; sealed 3-4 and dev-val (5)
    const blocks: []const u8 = switch (m) {
        .screen => &.{ 0, 1, 2 },
        .confirm => &.{ 0, 1, 2, 3, 4, 5 },
        .export_teams => unreachable,
    };
    var units: std.ArrayList(Unit) = .empty;
    defer units.deinit(gpa);
    var xs: std.ArrayList(f64) = .empty;
    defer xs.deinit(gpa);
    for (blocks) |b| {
        const before = if (b == 5) c.dev else bounds[b];
        const hi = if (b == 5) c.select else @min(bounds[b + 1], c.dev);
        const fit: Fit = .{ .c = c, .before = before };
        var p = try buildProfiles(gpa, d, extra, fit, permute);
        defer p.deinit(gpa);
        if (carry.cols.len > 0) try carry.into(gpa, &p, b);
        var mb = try fitMech(gpa, d, fit, mech_raw);
        defer mb.deinit(gpa);
        const tc = try teamCuts(gpa, arena, d, &p, fit);

        const blue_sum = try gpa.alloc(f64, d.games.len);
        defer gpa.free(blue_sum);
        const blue_n = try gpa.alloc(f64, d.games.len);
        defer gpa.free(blue_n);
        @memset(blue_sum, 0);
        @memset(blue_n, 0);
        const src: compcheck.Source = if (b == 5) .{ .before = c.dev } else .{ .before = before, .block = .{ before, hi } };
        try compcheck.offset(gpa, d, players, c, src, blue_sum, blue_n);

        // Aggregate means over this block's teams, to centre cross terms
        var means: [n_agg]f64 = @splat(0);
        var n_teams: f64 = 0;
        for (d.games, 0..) |g, gi| {
            if (blue_n[gi] == 0) continue;
            for (g.teams) |t| {
                const tm = makeTeam(&p, t);
                for (&means, tm.agg) |*mm, v| mm.* += v;
                n_teams += 1;
            }
        }
        for (&means) |*mm| mm.* /= @max(n_teams, 1);

        var n_block: usize = 0;
        var n_seen: usize = 0;
        for (d.games, 0..) |g, gi| {
            if (blue_n[gi] == 0) continue;
            if (b >= 3 and seen.contains(g.match_id)) {
                n_seen += 1;
                continue;
            }
            const pb = blue_sum[gi] / blue_n[gi];
            const blue = makeTeam(&p, g.teams[0]);
            const red = makeTeam(&p, g.teams[1]);
            const ab: [2]u8 = .{ arch.assign(&blue), arch.assign(&red) };
            const y: f64 = if (g.winner == 0) 1 else 0;
            var mech = mech_raw[gi];
            const mp = mb.pred(g);
            for (&mech, mp) |*x, pr| x.* -= pr;
            try units.append(gpa, .{
                .game = @intCast(gi),
                .block = b,
                .resid = y - pb,
                .p = pb,
                .y = y,
                .minutes = @as(f64, @floatFromInt(g.duration_s)) / 60,
                .mech = mech,
            });
            for (cands) |cd| try xs.append(gpa, xOf(cd, &blue, &red, ab, &means, &p, &tc));
            n_block += 1;
        }
        try w.print("block {d}: fit games before {d}, scored {d} games ({d} seen, left out)\n", .{ b + 1, before, n_block, n_seen });
    }
    try w.flush();

    const nc = cands.len;
    const nu = units.items.len;
    // Column-major copy: x[cand][unit]
    const xcol = try gpa.alloc(f64, nc * nu);
    defer gpa.free(xcol);
    for (0..nu) |u| for (0..nc) |k| {
        xcol[k * nu + u] = xs.items[u * nc + k];
    };
    switch (m) {
        .screen => try screen(gpa, arena, io, cands, units.items, xcol, shuffles, w),
        .export_teams => unreachable,
        .confirm => try confirm(gpa, arena, io, cands, units.items, xcol, confirm_path.?, w),
    }
    try w.flush();
    return 0;
}

const nan32 = std.math.nan(f32);

/// Traits written per team by --export-teams (Agg values)
const export_aggs = [_]Agg{ .magic_share, .early, .scaling, .engage, .peel, .dive, .tank, .range, .siege, .pick, .wave, .roam, .front };

fn exportTeams(
    gpa: Allocator,
    arena: Allocator,
    io: Io,
    d: *const rows.Data,
    extra: []const ?compstats.Seat,
    c: harness.Cuts,
    bounds: [nnexport.folds + 1]i64,
    arch: *const Archetypes,
    permute: u64,
    w: *Io.Writer,
) !void {
    _ = arena;
    var file = try Io.Dir.cwd().createFile(io, "teams.tsv", .{});
    defer file.close(io);
    var fbuf: [64 * 1024]u8 = undefined;
    var fw = file.writer(io, &fbuf);
    const t = &fw.interface;
    try t.writeAll("match_id\tblock\tside\tarchetype");
    for (export_aggs) |g| try t.print("\t{s}", .{@tagName(g)});
    try t.writeAll("\n");
    for (0..6) |b| {
        const before = if (b == 5) c.dev else bounds[b];
        const hi = if (b == 5) c.select else @min(bounds[b + 1], c.dev);
        var p = try buildProfiles(gpa, d, extra, .{ .c = c, .before = before }, permute);
        defer p.deinit(gpa);
        var n: usize = 0;
        for (d.games) |g| {
            const in = if (b == 5) harness.scored(.dev, c, g) else harness.visible(.dev, c, g) and g.start >= before and g.start < hi;
            if (!in) continue;
            for (g.teams, 0..) |team, side| {
                const tm = makeTeam(&p, team);
                if (b == 5) try t.print("{s}\tdev\t{d}\t{d}", .{ g.match_id, side, arch.assign(&tm) }) else try t.print("{s}\t{d}\t{d}\t{d}", .{ g.match_id, b + 1, side, arch.assign(&tm) });
                for (export_aggs) |a| try t.print("\t{d:.4}", .{agg(&tm, a)});
                try t.writeAll("\n");
            }
            n += 1;
        }
        try w.print("block {s}: {d} games\n", .{ if (b == 5) "dev" else &[_]u8{'1' + @as(u8, @intCast(b))}, n });
    }
    try t.flush();
}

fn teamCuts(gpa: Allocator, arena: Allocator, d: *const rows.Data, p: *const Profiles, fit: Fit) !TeamCuts {
    var early: std.ArrayList(f64) = .empty;
    defer early.deinit(gpa);
    var late: std.ArrayList(f64) = .empty;
    defer late.deinit(gpa);
    for (d.games) |g| if (fit.has(g)) for (g.teams) |t| {
        const tm = makeTeam(p, t);
        try early.append(gpa, agg(&tm, .early));
        try late.append(gpa, agg(&tm, .scaling));
    };
    var tc: TeamCuts = .{};
    if (early.items.len < 10) return tc;
    const q = struct {
        fn q(xs: []f64, at: f64) f64 {
            std.mem.sort(f64, xs, {}, std.sort.asc(f64));
            return xs[@intFromFloat(@as(f64, @floatFromInt(xs.len)) * at)];
        }
        fn sd(xs: []const f64) f64 {
            var s: f64 = 0;
            var s2: f64 = 0;
            for (xs) |x| {
                s += x;
                s2 += x * x;
            }
            const n: f64 = @floatFromInt(xs.len);
            return @sqrt(@max(s2 / n - (s / n) * (s / n), 1e-12));
        }
    };
    tc.early_sd = q.sd(early.items);
    tc.late_sd = q.sd(late.items);
    tc.early_lo = q.q(early.items, 0.3);
    tc.late_lo = q.q(late.items, 0.3);
    // Carry top cuts: top share of fit picks' role z
    var ncol: usize = 0;
    var it = p.carry.valueIterator();
    while (it.next()) |v| ncol = @max(ncol, v.len);
    if (ncol > 0) {
        const tops = try arena.alloc(f64, ncol);
        for (tops, 0..) |*t, k| {
            var vals: std.ArrayList(f64) = .empty;
            defer vals.deinit(gpa);
            for (d.rows) |r| {
                if (!fit.has(d.games[r.game])) continue;
                const cv = p.carry.get(cellKey(r.champion, @backingInt(r.role))) orelse continue;
                if (cv.len > k) try vals.append(gpa, cv[k]);
            }
            t.* = if (vals.items.len == 0) std.math.inf(f64) else q.q(vals.items, 1 - top_share);
        }
        tc.carry_top = tops;
    }
    return tc;
}

// ---------------------------------------------------------------- carry columns

/// meiolol-61's per-fold champion-role table: fold (1-5, dev), champion, role, rows, cols
const Carry = struct {
    cols: []const []const u8 = &.{},
    /// [fold 0-5] cell -> raw values
    folds: [6]std.AutoHashMapUnmanaged(u64, []f64) = @splat(.empty),

    /// Role z of the fold's values into p.carry (NaN -> 0, the role mean)
    fn into(cr: *const Carry, gpa: Allocator, p: *Profiles, fold: u8) !void {
        const t = &cr.folds[fold];
        const k = cr.cols.len;
        var sum: [5][16]f64 = @splat(@splat(0));
        var sq: [5][16]f64 = @splat(@splat(0));
        var n: [5][16]f64 = @splat(@splat(0));
        var it = t.iterator();
        while (it.next()) |e| {
            const role: usize = @intCast(e.key_ptr.* & 7);
            for (e.value_ptr.*, 0..) |v, j| if (!std.math.isNan(v)) {
                sum[role][j] += v;
                sq[role][j] += v * v;
                n[role][j] += 1;
            };
        }
        it = t.iterator();
        while (it.next()) |e| {
            const role: usize = @intCast(e.key_ptr.* & 7);
            const out = try p.carry.getOrPut(gpa, e.key_ptr.*);
            const z = try gpa.alloc(f64, k);
            for (z, e.value_ptr.*, 0..) |*zz, v, j| {
                const mm = sum[role][j] / @max(n[role][j], 1);
                const sd = @sqrt(@max(sq[role][j] / @max(n[role][j], 1) - mm * mm, 1e-12));
                // A column shrunk to its role's value carries nothing within the role
                zz.* = if (std.math.isNan(v) or sd < 1e-9) 0 else (v - mm) / sd;
            }
            out.value_ptr.* = z;
        }
    }
};

fn loadCarry(arena: Allocator, io: Io, path: []const u8) !Carry {
    const text = try Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(256 << 20));
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    var cr: Carry = .{};
    const head = while (lines.next()) |l| {
        if (l[0] != '#') break l;
    } else return error.EmptyCarry;
    var hf = std.mem.splitScalar(u8, head, '\t');
    for (0..4) |_| _ = hf.next();
    var cols: std.ArrayList([]const u8) = .empty;
    while (hf.next()) |n| try cols.append(arena, n);
    if (cols.items.len == 0 or cols.items.len > 16) return error.BadCarry;
    cr.cols = cols.items;
    while (lines.next()) |line| {
        if (line.len == 0 or line[0] == '#') continue;
        var f = std.mem.splitScalar(u8, line, '\t');
        const fold_s = f.first();
        const fold: usize = if (std.mem.eql(u8, fold_s, "dev")) 5 else (try std.fmt.parseInt(usize, fold_s, 10)) - 1;
        if (fold > 5) return error.BadCarry;
        const champ = try std.fmt.parseInt(u32, f.next() orelse return error.BadCarry, 10);
        const role_s = f.next() orelse return error.BadCarry;
        const role: usize = for ([_][]const u8{ "top", "jungle", "middle", "bottom", "utility" }, 0..) |rn, k| {
            if (std.mem.eql(u8, rn, role_s)) break k;
        } else return error.BadCarry;
        _ = f.next();
        const vals = try arena.alloc(f64, cols.items.len);
        for (vals) |*v| v.* = std.fmt.parseFloat(f64, f.next() orelse return error.BadCarry) catch nan;
        try cr.folds[fold].put(arena, cellKey(champ, role), vals);
    }
    return cr;
}

// ---------------------------------------------------------------- screen

/// Effect scale: pp per team sd for continuous traits (sd of x / sqrt 2, x being a
/// blue-minus-red difference of two roughly independent teams), pp for flags and
/// pairwise terms
fn scale(cd: Cand, x: []const f64) f64 {
    if (cd.flag or cd.family.len == 0) return 100;
    switch (cd.kind) {
        .arch, .arch_pair => return 100,
        else => {},
    }
    var s: f64 = 0;
    var s2: f64 = 0;
    var n: f64 = 0;
    for (x) |v| if (!std.math.isNan(v)) {
        s += v;
        s2 += v * v;
        n += 1;
    };
    const sd = @sqrt(@max(s2 / n - (s / n) * (s / n), 0));
    return 100 * sd / std.math.sqrt2;
}

fn prevalence(x: []const f64) f64 {
    // Flags: share of games where the two teams differ
    var n: f64 = 0;
    var k: f64 = 0;
    for (x) |v| if (!std.math.isNan(v)) {
        n += 1;
        k += @floatFromInt(@intFromBool(v != 0));
    };
    return k / @max(n, 1);
}

fn screen(gpa: Allocator, arena: Allocator, io: Io, cands: []const Cand, units: []const Unit, xcol: []const f64, shuffles: usize, w: *Io.Writer) !void {
    const nu = units.len;
    const nc = cands.len;
    const mix_k = for (cands, 0..) |cd, k| {
        if (std.mem.eql(u8, cd.name, "mix")) break k;
    } else unreachable;
    const all_units = try gpa.alloc(bool, nu);
    defer gpa.free(all_units);
    @memset(all_units, true);
    const resid = try gpa.alloc(f64, nu);
    defer gpa.free(resid);
    for (resid, units) |*r, u| r.* = u.resid;
    const pvals = try gpa.alloc(f64, nc);
    defer gpa.free(pvals);
    const res = try gpa.alloc(Slope, nc);
    defer gpa.free(res);
    for (res, pvals, 0..) |*r, *p, k| {
        r.* = slope(xcol[k * nu ..][0..nu], resid, null);
        p.* = if (std.math.isNan(r.se) or r.se == 0) 1 else pOf(r.beta / r.se);
    }
    const thr05 = try bhThreshold(gpa, pvals, 0.05);
    const thr10 = try bhThreshold(gpa, pvals, 0.10);
    const pass05 = try bhCount(gpa, pvals, 0.05);
    const pass10 = try bhCount(gpa, pvals, 0.10);
    try w.print("\n## Screen: {d} candidates on {d} games (blocks 1-3); BH passes: {d} at q 0.05, {d} at q 0.10; Bonferroni z {d:.2}\n", .{
        nc, nu, pass05, pass10, bonferroniZ(nc),
    });

    // Shuffled-label control: residuals permuted across games
    {
        var rng: std.Random.DefaultPrng = .init(4242);
        const rnd = rng.random();
        const sh = try gpa.dupe(f64, resid);
        defer gpa.free(sh);
        const sp = try gpa.alloc(f64, nc);
        defer gpa.free(sp);
        var total05: usize = 0;
        var total10: usize = 0;
        var maxz_all: f64 = 0;
        var any: usize = 0;
        for (0..shuffles) |_| {
            rnd.shuffle(f64, sh);
            var maxz: f64 = 0;
            for (sp, 0..) |*p, k| {
                const r = slope(xcol[k * nu ..][0..nu], sh, null);
                const z = if (std.math.isNan(r.se) or r.se == 0) 0 else r.beta / r.se;
                maxz = @max(maxz, @abs(z));
                p.* = if (std.math.isNan(r.se) or r.se == 0) 1 else pOf(z);
            }
            const a = try bhCount(gpa, sp, 0.05);
            total05 += a;
            total10 += try bhCount(gpa, sp, 0.10);
            any += @intFromBool(a > 0);
            maxz_all = @max(maxz_all, maxz);
        }
        try w.print("shuffled residuals, {d} shuffles: BH passes {d} at q 0.05 ({d} shuffles with any), {d} at q 0.10; largest |z| {d:.2}\n", .{
            shuffles, total05, any, total10, maxz_all,
        });
    }

    // Per candidate: pooled, per block, mechanism, win by game length
    const order = try gpa.alloc(usize, nc);
    defer gpa.free(order);
    for (order, 0..) |*o, k| o.* = k;
    std.mem.sort(usize, order, pvals, struct {
        fn lt(p: []const f64, a: usize, b: usize) bool {
            return p[a] < p[b];
        }
    }.lt);
    const keep = try gpa.alloc(bool, nu);
    defer gpa.free(keep);
    const mech = try gpa.alloc(f64, nu);
    defer gpa.free(mech);

    const cwd = Io.Dir.cwd();
    var file = try cwd.createFile(io, "screen.tsv", .{});
    defer file.close(io);
    var fbuf: [64 * 1024]u8 = undefined;
    var fw = file.writer(io, &fbuf);
    const t = &fw.interface;
    try t.writeAll("rank\tname\tfamily\thyp\tcontrol\tflag\tunit\tprevalence\teffect_pp\tci_pp\tz\tp\tbh05\tbh10\tblock1\tblock2\tblock3\tsame_sign\tbeside_mix_pp\tbeside_mix_ci");
    for (@typeInfo(Mech).@"enum".field_names) |n| try t.print("\t{s}\t{s}_ci", .{ n, n });
    try t.writeAll("\twin_short\twin_mid\twin_long\n");
    try w.writeAll("\n| rank | candidate | family | hyp | effect | z | BH | blocks 1/2/3 | beside mix | gold14 | first tower | dragons | win <25 / 25-32 / 32+ min |\n| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |\n");
    for (order, 1..) |k, rank| {
        const cd = cands[k];
        const x = xcol[k * nu ..][0..nu];
        const r = res[k];
        const sc = scale(cd, x);
        const z = r.beta / r.se;
        var blk: [3]f64 = undefined;
        var same: u8 = 0;
        for (&blk, 0..) |*b, bi| {
            for (keep, units) |*kp, u| kp.* = u.block == bi;
            b.* = slope(x, resid, keep).beta * sc;
            same += @intFromBool(std.math.sign(b.*) == std.math.sign(r.beta));
        }
        try t.print("{d}\t{s}\t{s}\t{d}\t{d}\t{d}\t{s}\t{d:.4}\t{d:.3}\t{d:.3}\t{d:.3}\t{e:.3}\t{d}\t{d}\t{d:.3}\t{d:.3}\t{d:.3}\t{d}", .{
            rank,                  cd.name,                        cd.family,                       cd.hyp,                          @intFromBool(cd.control),
            @intFromBool(cd.flag), if (cd.flag) "pp" else "pp/sd", prevalence(x),                   r.beta * sc,                     1.96 * r.se * sc,
            z,                     pvals[k],                       @intFromBool(pvals[k] <= thr05), @intFromBool(pvals[k] <= thr10), blk[0],
            blk[1],                blk[2],                         same,
        });
        const bm = try ols(gpa, arena, xcol, nu, if (k == mix_k) &.{k} else &.{ k, mix_k }, resid, all_units);
        try t.print("\t{d:.3}\t{d:.3}", .{ bm.beta[0] * sc, 1.96 * bm.se[0] * sc });
        var mech_s: [n_mech]Slope = undefined;
        for (0..n_mech) |j| {
            for (mech, units) |*mm, u| mm.* = u.mech[j];
            mech_s[j] = slope(x, mech, null);
            // Mechanism effects in the outcome's units per team sd (or for a flag)
            try t.print("\t{d:.4}\t{d:.4}", .{ mech_s[j].beta * sc / 100, 1.96 * mech_s[j].se * sc / 100 });
        }
        var wl: [3]f64 = undefined;
        for (&wl, 0..) |*v, li| {
            for (keep, units) |*kp, u| kp.* = switch (li) {
                0 => u.minutes < short_game_min,
                1 => u.minutes >= short_game_min and u.minutes < long_game_min,
                else => u.minutes >= long_game_min,
            };
            v.* = slope(x, resid, keep).beta * sc;
        }
        try t.print("\t{d:.3}\t{d:.3}\t{d:.3}\n", .{ wl[0], wl[1], wl[2] });
        if (rank <= 40) {
            const g14 = mech_s[@backingInt(Mech.gold14)];
            const ft = mech_s[@backingInt(Mech.first_tower)];
            const dr = mech_s[@backingInt(Mech.dragons)];
            try w.print("| {d} | {s} | {s} | {d} | {d:.2} ± {d:.2} {s} | {d:.2} | {s} | {d:.1} / {d:.1} / {d:.1} | {d:.2} ± {d:.2} | {d:.0} ± {d:.0} | {d:.3} | {d:.3} | {d:.1} / {d:.1} / {d:.1} |\n", .{
                rank,                                                                    cd.name,              cd.family,                      cd.hyp,
                r.beta * sc,                                                             1.96 * r.se * sc,     if (cd.flag) "pp" else "pp/sd", z,
                if (pvals[k] <= thr05) "q05" else if (pvals[k] <= thr10) "q10" else "-", blk[0],               blk[1],                         blk[2],
                bm.beta[0] * sc,                                                         1.96 * bm.se[0] * sc, g14.beta * sc / 100,            1.96 * g14.se * sc / 100,
                ft.beta * sc / 100,                                                      dr.beta * sc / 100,   wl[0],                          wl[1],
                wl[2],
            });
        }
    }
    try t.flush();
    try w.writeAll("\nAll candidates in screen.tsv (mechanism columns: outcome units per team sd or for the flag, own minus enemy, after an additive champion baseline)\n");
}

fn bonferroniZ(m: usize) f64 {
    // z with two-sided p = 0.05 / m, by bisection on erfc
    const target = 0.05 / @as(f64, @floatFromInt(m));
    var lo: f64 = 0;
    var hi: f64 = 10;
    for (0..60) |_| {
        const mid = (lo + hi) / 2;
        if (pOf(mid) > target) lo = mid else hi = mid;
    }
    return lo;
}

fn writeArchetypes(io: Io, a: *const Archetypes, w: *Io.Writer) !void {
    var file = try Io.Dir.cwd().createFile(io, "archetypes.tsv", .{});
    defer file.close(io);
    var fbuf: [16 * 1024]u8 = undefined;
    var fw = file.writer(io, &fbuf);
    const t = &fw.interface;
    try t.writeAll("archetype\tteams");
    for (arch_aggs) |g| try t.print("\t{s}", .{@tagName(g)});
    try t.writeAll("\n");
    try w.writeAll("\n## Archetypes (k-means on block 1's fit teams; centre in team sd; largest three traits)\n\n");
    for (a.centre, a.size, 0..) |cc, sz, k| {
        try t.print("{d}\t{d}", .{ k, sz });
        for (cc) |v| try t.print("\t{d:.3}", .{v});
        try t.writeAll("\n");
        var idx: [arch_aggs.len]usize = undefined;
        for (&idx, 0..) |*x, j| x.* = j;
        std.mem.sort(usize, &idx, &cc, struct {
            fn lt(c: *const [arch_aggs.len]f64, x: usize, y: usize) bool {
                return @abs(c[x]) > @abs(c[y]);
            }
        }.lt);
        try w.print("archetype {d} ({d} teams):", .{ k, sz });
        for (idx[0..3]) |j| try w.print(" {s} {s}{d:.2}", .{ @tagName(arch_aggs[j]), if (cc[j] >= 0) "+" else "", cc[j] });
        try w.writeAll("\n");
    }
    try t.flush();
}

// ---------------------------------------------------------------- confirm

fn confirm(gpa: Allocator, arena: Allocator, io: Io, cands: []const Cand, units: []const Unit, xcol: []const f64, path: []const u8, w: *Io.Writer) !void {
    const nu = units.len;
    const text = try Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 20));
    var names: std.ArrayList(usize) = .empty;
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    while (lines.next()) |line| {
        const name = std.mem.trim(u8, line, " \t\r");
        if (name.len == 0 or name[0] == '#') continue;
        const k = for (cands, 0..) |cd, k| {
            if (std.mem.eql(u8, cd.name, name)) break k;
        } else {
            std.debug.print("comps --confirm: no candidate named \"{s}\"\n", .{name});
            return error.UnknownCandidate;
        };
        try names.append(arena, k);
    }
    const mix_k = for (cands, 0..) |cd, k| {
        if (std.mem.eql(u8, cd.name, "mix")) break k;
    } else unreachable;
    const resid = try gpa.alloc(f64, nu);
    defer gpa.free(resid);
    for (resid, units) |*r, u| r.* = u.resid;
    const sealed = try gpa.alloc(bool, nu);
    defer gpa.free(sealed);
    for (sealed, units) |*s, u| s.* = u.block >= 3;
    const keep = try gpa.alloc(bool, nu);
    defer gpa.free(keep);
    var n_sealed: usize = 0;
    for (sealed) |s| n_sealed += @intFromBool(s);

    try w.print("\n## Sealed confirmation: {d} pre-declared candidates on {d} games (blocks 4-5 and dev-val)\n\n", .{ names.items.len, n_sealed });
    var file = try Io.Dir.cwd().createFile(io, "confirm.tsv", .{});
    defer file.close(io);
    var fbuf: [16 * 1024]u8 = undefined;
    var fw = file.writer(io, &fbuf);
    const t = &fw.interface;
    try t.writeAll("name\tunit\teffect_pp\tci_pp\tz\tblock4\tblock5\tdev_val\tbeside_mix_pp\tbeside_mix_ci\tjoint_pp\tjoint_ci\n");
    try w.writeAll("| candidate | sealed effect | z | block 4 / 5 / dev-val | beside mix | jointly with all |\n| --- | --- | --- | --- | --- | --- |\n");

    // Joint OLS on sealed: every listed candidate plus mix. A column with no estimate of its
    // own (constant, or NaN for every game) would empty the fit, so it stays out
    var joint_idx: std.ArrayList(usize) = .empty;
    for (names.items) |k| if (k != mix_k and !std.math.isNan(slope(xcol[k * nu ..][0..nu], resid, sealed).beta))
        try joint_idx.append(arena, k);
    try joint_idx.append(arena, mix_k);
    const joint = try ols(gpa, arena, xcol, nu, joint_idx.items, resid, sealed);

    for (names.items) |k| {
        const cd = cands[k];
        const x = xcol[k * nu ..][0..nu];
        const sc = scale(cd, x);
        const r = slope(x, resid, sealed);
        var bl: [3]f64 = undefined;
        for (&bl, [_]u8{ 3, 4, 5 }) |*b, bi| {
            for (keep, units) |*kp, u| kp.* = u.block == bi;
            b.* = slope(x, resid, keep).beta * sc;
        }
        const pair = try ols(gpa, arena, xcol, nu, if (k == mix_k) &.{k} else &.{ k, mix_k }, resid, sealed);
        const ji = std.mem.indexOfScalar(usize, joint_idx.items, k);
        const jb = if (ji) |j| joint.beta[j] else nan;
        const js = if (ji) |j| joint.se[j] else nan;
        try t.print("{s}\t{s}\t{d:.3}\t{d:.3}\t{d:.3}\t{d:.3}\t{d:.3}\t{d:.3}\t{d:.3}\t{d:.3}\t{d:.3}\t{d:.3}\n", .{
            cd.name, if (cd.flag) "pp" else "pp/sd", r.beta * sc, 1.96 * r.se * sc,  r.beta / r.se,
            bl[0],   bl[1],                          bl[2],       pair.beta[0] * sc, 1.96 * pair.se[0] * sc,
            jb * sc, 1.96 * js * sc,
        });
        try w.print("| {s} | {d:.2} ± {d:.2} {s} | {d:.2} | {d:.1} / {d:.1} / {d:.1} | {d:.2} ± {d:.2} | {d:.2} ± {d:.2} |\n", .{
            cd.name, r.beta * sc,    1.96 * r.se * sc, if (cd.flag) "pp" else "pp/sd", r.beta / r.se,
            bl[0],   bl[1],          bl[2],            pair.beta[0] * sc,              1.96 * pair.se[0] * sc,
            jb * sc, 1.96 * js * sc,
        });
    }
    try t.flush();

    // A logistic comp layer on ratings' logit, fitted on the screen blocks, scored sealed
    try w.writeAll("\n## Logistic comp layer on ratings (fit: blocks 1-3; scored: sealed), log loss per game, paired by game\n\n");
    const fit_keep = try gpa.alloc(bool, nu);
    defer gpa.free(fit_keep);
    for (fit_keep, units) |*f, u| f.* = u.block < 3;
    const base = try gpa.alloc(f64, nu);
    defer gpa.free(base);
    for (base, units) |*b, u| b.* = logLoss(u.y, u.p);
    const game = try gpa.alloc(u32, nu);
    defer gpa.free(game);
    for (game, units) |*g, u| g.* = u.game;
    const mix_ll = try layerLoss(gpa, arena, xcol, nu, &.{mix_k}, units, fit_keep);
    defer gpa.free(mix_ll);
    var surv: std.ArrayList(usize) = .empty;
    for (names.items) |k| if (k != mix_k) try surv.append(arena, k);
    const all = try arena.dupe(usize, joint_idx.items);
    const surv_ll = try layerLoss(gpa, arena, xcol, nu, surv.items, units, fit_keep);
    defer gpa.free(surv_ll);
    const all_ll = try layerLoss(gpa, arena, xcol, nu, all, units, fit_keep);
    defer gpa.free(all_ll);
    try w.writeAll("| model | vs | sealed diff, nats/game | blocks 4-5 | dev-val |\n| --- | --- | --- | --- | --- |\n");
    const rowsets = [_]struct { []const u8, []const f64, []const u8, []const f64 }{
        .{ "ratings + mix", mix_ll, "ratings", base },
        .{ "ratings + survivors", surv_ll, "ratings", base },
        .{ "ratings + survivors + mix", all_ll, "ratings", base },
        .{ "ratings + survivors + mix", all_ll, "ratings + mix", mix_ll },
    };
    for (rowsets) |rs| {
        const pall = harness.paired(game, rs[1], rs[3], sealed);
        for (keep, units) |*kp, u| kp.* = u.block == 3 or u.block == 4;
        const pf = harness.paired(game, rs[1], rs[3], keep);
        for (keep, units) |*kp, u| kp.* = u.block == 5;
        const pd = harness.paired(game, rs[1], rs[3], keep);
        try w.print("| {s} | {s} | {d:.5} ± {d:.5} | {d:.5} ± {d:.5} | {d:.5} ± {d:.5} |\n", .{
            rs[0], rs[2], pall.diff, pall.half, pf.diff, pf.half, pd.diff, pd.half,
        });
    }
}

fn logLoss(y: f64, p: f64) f64 {
    const q = std.math.clamp(p, 1e-9, 1 - 1e-9);
    return -(y * @log(q) + (1 - y) * @log(1 - q));
}

const Ols = struct { beta: []f64, se: []f64 };

/// OLS of r on the columns `idx` of xcol (with intercept) over keep; robust se
fn ols(gpa: Allocator, arena: Allocator, xcol: []const f64, nu: usize, idx: []const usize, r: []const f64, keep: []const bool) !Ols {
    const k = idx.len + 1;
    const xtx = try gpa.alloc(f64, k * k);
    defer gpa.free(xtx);
    const xtr = try gpa.alloc(f64, k);
    defer gpa.free(xtr);
    @memset(xtx, 0);
    @memset(xtr, 0);
    const row = try gpa.alloc(f64, k);
    defer gpa.free(row);
    var differ: usize = 0;
    for (0..nu) |u| {
        if (!keep[u]) continue;
        if (!rowOf(xcol, nu, idx, u, row)) continue;
        differ += @intFromBool(row[1] != 0);
        for (0..k) |a| {
            xtr[a] += row[a] * r[u];
            for (0..k) |b| xtx[a * k + b] += row[a] * row[b];
        }
    }
    const beta = try arena.alloc(f64, k);
    const se = try arena.alloc(f64, k);
    if (differ < min_differing) {
        @memset(beta, nan);
        @memset(se, nan);
        return .{ .beta = beta[1..], .se = se[1..] };
    }
    // A constant column (a flag no team has in these games): no estimate
    const inv = invert(gpa, xtx, k) catch |err| switch (err) {
        error.SingularMatrix => {
            @memset(beta, nan);
            @memset(se, nan);
            return .{ .beta = beta[1..], .se = se[1..] };
        },
        else => return err,
    };
    defer gpa.free(inv);
    for (beta, 0..) |*b, a| {
        b.* = 0;
        for (0..k) |c| b.* += inv[a * k + c] * xtr[c];
    }
    const meat = try gpa.alloc(f64, k * k);
    defer gpa.free(meat);
    @memset(meat, 0);
    for (0..nu) |u| {
        if (!keep[u]) continue;
        if (!rowOf(xcol, nu, idx, u, row)) continue;
        var e = r[u];
        for (row, beta) |x, b| e -= x * b;
        for (0..k) |a| for (0..k) |b| {
            meat[a * k + b] += row[a] * row[b] * e * e;
        };
    }
    for (se, 0..) |*s, a| {
        var v: f64 = 0;
        for (0..k) |b| for (0..k) |c| {
            v += inv[a * k + b] * meat[b * k + c] * inv[c * k + a];
        };
        s.* = @sqrt(@max(v, 0));
    }
    // Slopes first, intercept last
    return .{ .beta = beta[1..], .se = se[1..] };
}

fn rowOf(xcol: []const f64, nu: usize, idx: []const usize, u: usize, row: []f64) bool {
    row[0] = 1;
    for (idx, 1..) |c, a| {
        const v = xcol[c * nu + u];
        if (std.math.isNan(v)) return false;
        row[a] = v;
    }
    return true;
}

/// Gauss-Jordan inverse of a k x k matrix (small, well conditioned by construction)
fn invert(gpa: Allocator, a_in: []const f64, k: usize) ![]f64 {
    const a = try gpa.dupe(f64, a_in);
    defer gpa.free(a);
    const inv = try gpa.alloc(f64, k * k);
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

/// Logistic regression with ratings' logit as offset on columns idx (standardised on the
/// fit units, small ridge), fitted on fit_keep by Newton; per-unit log loss for all units
fn layerLoss(gpa: Allocator, arena: Allocator, xcol: []const f64, nu: usize, idx: []const usize, units: []const Unit, fit_keep: []const bool) ![]f64 {
    const k = idx.len;
    const mean = try arena.alloc(f64, k);
    const sd = try arena.alloc(f64, k);
    for (idx, mean, sd) |c, *m, *s| {
        var s1: f64 = 0;
        var s2: f64 = 0;
        var n: f64 = 0;
        for (0..nu) |u| {
            if (!fit_keep[u]) continue;
            const v = xcol[c * nu + u];
            if (std.math.isNan(v)) continue;
            s1 += v;
            s2 += v * v;
            n += 1;
        }
        m.* = s1 / @max(n, 1);
        s.* = @sqrt(@max(s2 / @max(n, 1) - m.* * m.*, 1e-12));
    }
    const beta = try arena.alloc(f64, k);
    @memset(beta, 0);
    const ridge = 1.0;
    const hess = try gpa.alloc(f64, k * k);
    defer gpa.free(hess);
    const grad = try gpa.alloc(f64, k);
    defer gpa.free(grad);
    const x = try gpa.alloc(f64, k);
    defer gpa.free(x);
    for (0..25) |_| {
        @memset(hess, 0);
        @memset(grad, 0);
        for (0..k) |a| {
            hess[a * k + a] = ridge;
            grad[a] = ridge * beta[a];
        }
        for (0..nu) |u| {
            if (!fit_keep[u]) continue;
            const q = predict(xcol, nu, idx, mean, sd, beta, units[u].p, u, x);
            const e = q - units[u].y;
            const wt = q * (1 - q);
            for (0..k) |a| {
                grad[a] += e * x[a];
                for (0..k) |b| hess[a * k + b] += wt * x[a] * x[b];
            }
        }
        const inv = try invert(gpa, hess, k);
        defer gpa.free(inv);
        var step: f64 = 0;
        for (0..k) |a| {
            var dlt: f64 = 0;
            for (0..k) |b| dlt += inv[a * k + b] * grad[b];
            beta[a] -= dlt;
            step = @max(step, @abs(dlt));
        }
        if (step < 1e-8) break;
    }
    const out = try gpa.alloc(f64, nu);
    for (out, 0..) |*o, u| o.* = logLoss(units[u].y, predict(xcol, nu, idx, mean, sd, beta, units[u].p, u, x));
    return out;
}

fn predict(xcol: []const f64, nu: usize, idx: []const usize, mean: []const f64, sd: []const f64, beta: []const f64, p: f64, u: usize, x: []f64) f64 {
    const q0 = std.math.clamp(p, 1e-9, 1 - 1e-9);
    var logit = @log(q0 / (1 - q0));
    for (idx, x, mean, sd, beta) |c, *xx, m, s, b| {
        const v = xcol[c * nu + u];
        xx.* = if (std.math.isNan(v)) 0 else (v - m) / s;
        logit += b * xx.*;
    }
    return 1 / (1 + @exp(-logit));
}

const testing = std.testing;

test "comps: slope, BH and erfc" {
    // r = 0.1 x exactly: slope 0.1, se ~0
    var x: [300]f64 = undefined;
    var r: [300]f64 = undefined;
    for (&x, &r, 0..) |*a, *b, k| {
        a.* = @as(f64, @floatFromInt(k)) / 10;
        b.* = 0.1 * a.*;
    }
    const s = slope(&x, &r, null);
    try testing.expectApproxEqAbs(@as(f64, 0.1), s.beta, 1e-12);
    try testing.expect(s.se < 1e-9);
    try testing.expectApproxEqAbs(@as(f64, 0.05), pOf(1.959964), 1e-5);
    try testing.expectApproxEqAbs(@as(f64, 2.0), erfc(-10), 1e-9);
    // BH: 0.001 and 0.01 pass at q 0.05 among 4 (0.0125, 0.025), 0.04 doesn't (0.0375)
    const p = [_]f64{ 0.04, 0.001, 0.9, 0.01 };
    try testing.expectEqual(@as(usize, 2), try bhCount(testing.allocator, &p, 0.05));
    try testing.expect(bonferroniZ(200) > 3.6 and bonferroniZ(200) < 3.7);
}

test "comps: ols matches slope with one column, invert" {
    const gpa = testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var rng: std.Random.DefaultPrng = .init(1);
    const rnd = rng.random();
    const n = 500;
    var x: [n]f64 = undefined;
    var r: [n]f64 = undefined;
    var keep: [n]bool = @splat(true);
    for (&x, &r) |*a, *b| {
        a.* = rnd.floatNorm(f64);
        b.* = 0.3 * a.* + rnd.floatNorm(f64);
    }
    keep[0] = false;
    const o = try ols(gpa, arena, &x, n, &.{0}, &r, &keep);
    const s = slope(&x, &r, &keep);
    try testing.expectApproxEqAbs(s.beta, o.beta[0], 1e-9);
    try testing.expectApproxEqRel(s.se, o.se[0], 0.01);
    const m = [_]f64{ 4, 7, 2, 6 };
    const inv = try invert(gpa, &m, 2);
    defer gpa.free(inv);
    try testing.expectApproxEqAbs(@as(f64, 0.6), inv[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, -0.7), inv[1], 1e-12);
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

test "comps: candidate x is antisymmetric under a side swap" {
    const gpa = testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var p: Profiles = .{};
    defer p.deinit(gpa);
    var rng: std.Random.DefaultPrng = .init(3);
    const rnd = rng.random();
    for (0..5) |role| {
        for (&p.role_raw[role], &p.role_mean[role], &p.role_sd[role]) |*a, *m, *s| {
            a.* = rnd.float(f64);
            m.* = 0.5;
            s.* = 0.3;
        }
    }
    for (&p.cut) |*ct| ct.* = 0.6;
    for (1..11) |champ| for (0..5) |role| {
        var v: [nv]f64 = undefined;
        for (&v) |*x| x.* = rnd.float(f64);
        try p.raw.put(gpa, cellKey(@intCast(champ), role), v);
    };
    const blue = makeTeam(&p, .{ 1, 2, 3, 4, 5 });
    const red = makeTeam(&p, .{ 6, 7, 8, 9, 10 });
    const cands = try candidates(arena, k_arch, &.{});
    var means: [n_agg]f64 = undefined;
    for (&means, blue.agg, red.agg) |*m, a, b| m.* = (a + b) / 2;
    const tc: TeamCuts = .{};
    for (cands) |cd| {
        const a = xOf(cd, &blue, &red, .{ 0, 3 }, &means, &p, &tc);
        const b = xOf(cd, &red, &blue, .{ 3, 0 }, &means, &p, &tc);
        try testing.expectApproxEqAbs(a, -b, 1e-9);
    }
}
