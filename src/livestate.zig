//! The game state at each minute from a timeline, per seat and per team: what the live
//! state models read (meiolol-lab state-export for the lab, statemodel.zig for Your
//! games). Values at the minute's frame or from events before it. Approximate:
//! respawn_s uses the wiki's death timer (level base x game-time factor), not the server's

const std = @import("std");
const timeline = @import("riot/timeline.zig");
const objectives = @import("objectives.zig");

/// Per seat, values at the minute's frame or from events before it
pub const Seat = enum {
    gold,
    xp,
    cs,
    level,
    kills,
    deaths,
    assists,
    dmg_champ,
    /// current_gold: earned, not yet spent
    unspent,
    /// Seconds until respawn, 0 alive
    respawn_s,
    /// Completed items of the patch's finished set: bought, minus undone and sold
    legendaries,
    /// Placed, not counting UNDEFINED and Teemo's mushrooms
    wards,
    ctrl_wards,
    wards_killed,
};

/// Per team, counted for the team that took it
pub const Team = enum {
    kills,
    tower_top_outer,
    tower_top_inner,
    tower_top_base,
    tower_mid_outer,
    tower_mid_inner,
    tower_mid_base,
    tower_bot_outer,
    tower_bot_inner,
    tower_bot_base,
    tower_nexus,
    /// Seconds until the enemy inhibitor in this lane respawns, 0 up
    inhib_top_s,
    inhib_mid_s,
    inhib_bot_s,
    /// Inhibitors destroyed, ever
    inhibs,
    plates,
    infernal,
    ocean,
    mountain,
    cloud,
    hextech,
    chemtech,
    /// Soul taken: 1 + element index (infernal .. chemtech), 0 none
    soul,
    elders,
    elder_s,
    barons,
    baron_s,
    grubs,
    heralds,
};

pub const n_seat = @typeInfo(Seat).@"enum".field_names.len;
pub const n_team = @typeInfo(Team).@"enum".field_names.len;

pub const minute_ms = 60_000;
const inhib_respawn_ms = 300_000;
const baron_buff_ms = 180_000;
const elder_buff_ms = 150_000;

const elements = [_][]const u8{ "FIRE_DRAGON", "WATER_DRAGON", "EARTH_DRAGON", "AIR_DRAGON", "HEXTECH_DRAGON", "CHEMTECH_DRAGON" };
const soul_names = [_][]const u8{ "Infernal", "Ocean", "Mountain", "Cloud", "Hextech", "Chemtech" };
const lanes = [_][]const u8{ "TOP_LANE", "MID_LANE", "BOT_LANE" };
const tiers = [_][]const u8{ "OUTER_TURRET", "INNER_TURRET", "BASE_TURRET" };

/// Base death timer by level (1..18), seconds (League wiki, "Death")
const base_respawn = [18]f32{ 10, 10, 12, 12, 14, 16, 20, 25, 28, 32.5, 35, 37.5, 40, 42.5, 45, 47.5, 50, 52.5 };

/// Death timer in seconds for a death at `level` and `t_ms`: base x (1 + time factor),
/// the factor rising in half-minute steps from 15:00, capped at 50%
pub fn respawnSeconds(level: u8, t_ms: i64) f32 {
    const l = std.math.clamp(level, 1, 18);
    const t = @as(f32, @floatFromInt(t_ms)) / minute_ms;
    const tif: f32 = if (t < 15)
        0
    else if (t < 30)
        @ceil(2 * (t - 15)) * 0.425
    else if (t < 45)
        12.75 + @ceil(2 * (t - 30)) * 0.30
    else if (t < 55)
        21.75 + @ceil(2 * (t - 45)) * 1.45
    else
        50;
    return base_respawn[l - 1] * (1 + @min(tif, 50) / 100);
}

/// Which item ids count as completed (legendary) items
pub const Items = struct {
    ctx: *const anyopaque,
    legendary: *const fn (ctx: *const anyopaque, item: u32) bool,

    /// From sorted item ids (ddragon.legendaries)
    pub fn sorted(ids: *const []const u32) Items {
        return .{ .ctx = @ptrCast(ids), .legendary = struct {
            fn f(ctx: *const anyopaque, item: u32) bool {
                const list: *const []const u32 = @ptrCast(@alignCast(ctx));
                return std.sort.binarySearch(u32, list.*, item, struct {
                    fn order(a: u32, b: u32) std.math.Order {
                        return std.math.order(a, b);
                    }
                }.order) != null;
            }
        }.f };
    }
};

/// The state at one minute. Seats by seat index (side * 5 + role, side 0 blue)
pub const Minute = struct {
    t_ms: i64,
    seat: [10][n_seat]f32,
    /// objectives.stateBefore: blue minus red, winchance's state
    obj: objectives.State,
    /// [side][Team]
    team: [2][n_team]f32,

    pub fn get(m: *const Minute, seat: usize, c: Seat) f32 {
        return m.seat[seat][@backingInt(c)];
    }
    pub fn teamGet(m: *const Minute, side: usize, c: Team) f32 {
        return m.team[side][@backingInt(c)];
    }
};

/// The frame for minute m when the game is still going then (objectives.stateAt's rule:
/// frame m exists, is not the end frame, t_ms >= m:00)
pub fn frameAt(t: timeline.Timeline, m: u8) ?timeline.Frame {
    if (t.frames.len < @as(usize, m) + 2) return null;
    const f = t.frames[m];
    if (f.t_ms < @as(i64, m) * minute_ms) return null;
    return f;
}

fn indexOf(list: []const []const u8, s: []const u8) ?usize {
    for (list, 0..) |x, i| if (std.mem.eql(u8, x, s)) return i;
    return null;
}

/// Team side (0 blue, 1 red) of participant ids 1..10, null otherwise
pub fn sideOf(p: u8) ?usize {
    return if (p >= 1 and p <= 5) 0 else if (p >= 6 and p <= 10) 1 else null;
}

pub fn ownerSide(team: u16) ?usize {
    return switch (team) {
        100 => 0,
        200 => 1,
        else => null,
    };
}

/// Walks one 10-player timeline minute by minute; `at` takes minutes in ascending order
pub const Walker = struct {
    t: timeline.Timeline,
    /// Participant id - 1 -> seat (side * 5 + role)
    seat_of: [10]u8,
    items: Items,
    next: usize = 0,
    kills: [10]f32 = @splat(0),
    deaths: [10]f32 = @splat(0),
    assists: [10]f32 = @splat(0),
    legendaries: [10]f32 = @splat(0),
    wards: [10]f32 = @splat(0),
    ctrl: [10]f32 = @splat(0),
    wards_killed: [10]f32 = @splat(0),
    level: [10]u8 = @splat(1),
    /// ms when the last death's timer ends
    alive_at: [10]i64 = @splat(0),
    team: [2][n_team]f32 = @splat(@splat(0)),
    inhib_down: [2][3]?i64 = @splat(@splat(null)),
    elder_at: [2]?i64 = @splat(null),
    baron_at: [2]?i64 = @splat(null),

    pub fn init(t: timeline.Timeline, seat_of: [10]u8, items: Items) Walker {
        return .{ .t = t, .seat_of = seat_of, .items = items };
    }

    /// The state at minute `m`, null once the game has ended by then
    pub fn at(w: *Walker, m: u8) ?Minute {
        const frame = frameAt(w.t, m) orelse return null;
        const now = frame.t_ms;
        while (w.next < w.t.events.len and w.t.events[w.next].t_ms < now) : (w.next += 1) w.add(w.t.events[w.next]);
        var out: Minute = .{ .t_ms = frame.t_ms, .seat = undefined, .obj = objectives.stateBefore(w.t, frame, now), .team = w.team };
        for (0..10) |i| {
            const pid: u8 = @intCast(i + 1);
            const v = struct {
                fn f(x: i32) f32 {
                    return @floatFromInt(x);
                }
            }.f;
            const s = &out.seat[w.seat_of[i]];
            s[@backingInt(Seat.gold)] = v(frame.get(pid, .total_gold));
            s[@backingInt(Seat.xp)] = v(frame.get(pid, .xp));
            s[@backingInt(Seat.cs)] = v(frame.get(pid, .minions) + frame.get(pid, .jungle_minions));
            s[@backingInt(Seat.level)] = v(frame.get(pid, .level));
            s[@backingInt(Seat.kills)] = w.kills[i];
            s[@backingInt(Seat.deaths)] = w.deaths[i];
            s[@backingInt(Seat.assists)] = w.assists[i];
            s[@backingInt(Seat.dmg_champ)] = v(frame.get(pid, .damage_to_champions));
            s[@backingInt(Seat.unspent)] = v(frame.get(pid, .current_gold));
            s[@backingInt(Seat.respawn_s)] = @as(f32, @floatFromInt(@max(0, w.alive_at[i] - now))) / 1000;
            s[@backingInt(Seat.legendaries)] = w.legendaries[i];
            s[@backingInt(Seat.wards)] = w.wards[i];
            s[@backingInt(Seat.ctrl_wards)] = w.ctrl[i];
            s[@backingInt(Seat.wards_killed)] = w.wards_killed[i];
        }
        for (0..2) |side| {
            const o = &out.team[side];
            for (0..3) |lane| o[@backingInt(Team.inhib_top_s) + lane] = left(w.inhib_down[side][lane], inhib_respawn_ms, now);
            o[@backingInt(Team.elder_s)] = left(w.elder_at[side], elder_buff_ms, now);
            o[@backingInt(Team.baron_s)] = left(w.baron_at[side], baron_buff_ms, now);
        }
        return out;
    }

    fn left(start: ?i64, len_ms: i64, now: i64) f32 {
        const s = start orelse return 0;
        return @as(f32, @floatFromInt(@max(0, s + len_ms - now))) / 1000;
    }

    fn legendary(w: *const Walker, item: u32) bool {
        return w.items.legendary(w.items.ctx, item);
    }

    fn add(a: *Walker, e: timeline.Event) void {
        switch (e.data) {
            .champion_kill => |k| {
                if (k.victim >= 1 and k.victim <= 10) {
                    const v = k.victim - 1;
                    a.deaths[v] += 1;
                    a.alive_at[v] = e.t_ms + @as(i64, @trunc(respawnSeconds(a.level[v], e.t_ms) * 1000));
                }
                if (k.killer >= 1 and k.killer <= 10) a.kills[k.killer - 1] += 1;
                for (k.assists) |p| if (p >= 1 and p <= 10) {
                    a.assists[p - 1] += 1;
                };
                const side = sideOf(k.killer) orelse if (sideOf(k.victim)) |vs| 1 - vs else return;
                a.team[side][@backingInt(Team.kills)] += 1;
            },
            .level_up => |l| if (l.participant >= 1 and l.participant <= 10) {
                a.level[l.participant - 1] = @max(a.level[l.participant - 1], l.level);
            },
            .item_purchased => |p| if (p.participant >= 1 and p.participant <= 10 and a.legendary(p.item)) {
                a.legendaries[p.participant - 1] += 1;
            },
            .item_sold => |p| if (p.participant >= 1 and p.participant <= 10 and a.legendary(p.item)) {
                a.legendaries[p.participant - 1] -= 1;
            },
            .item_undo => |u| if (u.participant >= 1 and u.participant <= 10 and u.after == 0 and a.legendary(u.before)) {
                a.legendaries[u.participant - 1] -= 1;
            },
            .ward_placed => |w| if (w.participant >= 1 and w.participant <= 10 and
                !std.mem.eql(u8, w.ward, "UNDEFINED") and !std.mem.eql(u8, w.ward, "TEEMO_MUSHROOM"))
            {
                a.wards[w.participant - 1] += 1;
                if (std.mem.eql(u8, w.ward, "CONTROL_WARD")) a.ctrl[w.participant - 1] += 1;
            },
            .ward_kill => |w| if (w.participant >= 1 and w.participant <= 10) {
                a.wards_killed[w.participant - 1] += 1;
            },
            .building_kill => |b| {
                const owner = ownerSide(b.team) orelse return;
                const taker = 1 - owner;
                if (std.mem.eql(u8, b.building, "TOWER_BUILDING")) {
                    if (std.mem.eql(u8, b.tower, "NEXUS_TURRET")) {
                        a.team[taker][@backingInt(Team.tower_nexus)] += 1;
                        return;
                    }
                    const lane = indexOf(&lanes, b.lane) orelse return;
                    const tier = indexOf(&tiers, b.tower) orelse return;
                    a.team[taker][@backingInt(Team.tower_top_outer) + lane * 3 + tier] += 1;
                } else if (std.mem.eql(u8, b.building, "INHIBITOR_BUILDING")) {
                    a.team[taker][@backingInt(Team.inhibs)] += 1;
                    const lane = indexOf(&lanes, b.lane) orelse return;
                    a.inhib_down[taker][lane] = e.t_ms;
                }
            },
            // team owns the plate
            .turret_plate => |p| if (ownerSide(p.team)) |owner| {
                a.team[1 - owner][@backingInt(Team.plates)] += 1;
            },
            .elite_monster => |m| {
                const side = ownerSide(m.team) orelse return;
                const t = &a.team[side];
                if (std.mem.eql(u8, m.monster, "DRAGON")) {
                    if (std.mem.eql(u8, m.subtype, "ELDER_DRAGON")) {
                        t[@backingInt(Team.elders)] += 1;
                        a.elder_at[side] = e.t_ms;
                    } else if (indexOf(&elements, m.subtype)) |el| {
                        t[@backingInt(Team.infernal) + el] += 1;
                    }
                } else if (std.mem.eql(u8, m.monster, "BARON_NASHOR")) {
                    t[@backingInt(Team.barons)] += 1;
                    a.baron_at[side] = e.t_ms;
                } else if (std.mem.eql(u8, m.monster, "HORDE")) {
                    t[@backingInt(Team.grubs)] += 1;
                } else if (std.mem.eql(u8, m.monster, "RIFTHERALD")) {
                    t[@backingInt(Team.heralds)] += 1;
                }
            },
            // Team 0: the element announced, not a soul taken (objectives.stateBefore)
            .dragon_soul => |d| if (ownerSide(d.team)) |side| {
                const el = indexOf(&soul_names, d.name) orelse 6;
                a.team[side][@backingInt(Team.soul)] = @floatFromInt(1 + el);
            },
            else => {},
        }
    }
};

test respawnSeconds {
    try std.testing.expectEqual(@as(f32, 10), respawnSeconds(1, 5 * minute_ms));
    try std.testing.expectEqual(@as(f32, 52.5), respawnSeconds(18, 14 * minute_ms));
    // 20:00: 10 half-minute steps of 0.425%
    try std.testing.expectApproxEqAbs(@as(f32, 40 * 1.0425), respawnSeconds(13, 20 * minute_ms), 1e-4);
    try std.testing.expectApproxEqAbs(@as(f32, 52.5 * 1.5), respawnSeconds(18, 70 * minute_ms), 1e-4);
}

test "Items.sorted" {
    const ids: []const u32 = &.{ 3031, 3071, 6610 };
    const items: Items = .sorted(&ids);
    try std.testing.expect(items.legendary(items.ctx, 3071));
    try std.testing.expect(!items.legendary(items.ctx, 1055));
}
