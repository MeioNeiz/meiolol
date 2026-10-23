//! The in-game panel (docs/plan/app.md APP9) from Live Client Data (lcu/live.zig) and
//! our curves: both teams lane by lane, the score, objective timers known from the
//! event feed (respawns after a kill), and your lane against the typical game in the
//! matchup at this minute. Only what the scoreboard shows anyway; never enemy
//! cooldowns, alerts or prompts (docs/plan/app.md "In-game companion"). Pure.

const std = @import("std");
const core = @import("core");
const live = @import("lcu/live.zig");
const lanecard = @import("lanecard.zig");
const Role = core.Role;
const Stats = core.Stats;
const curvesfile = core.curvesfile;

pub const Seat = struct {
    /// 0 when the stats file doesn't know it
    champion: u32,
    level: u32,
    kills: u32,
    deaths: u32,
    assists: u32,
    cs: u32,
    item_gold: u32,
    dead: bool,
    respawn: f32,
    me: bool,
};

/// One lane, our side and theirs
pub const Row = struct {
    role: Role,
    ours: ?Seat = null,
    theirs: ?Seat = null,

    /// Item gold, us minus them
    pub fn goldDiff(r: Row) ?i64 {
        const a = r.ours orelse return null;
        const b = r.theirs orelse return null;
        return @as(i64, a.item_gold) - b.item_gold;
    }
};

pub const Score = struct {
    kills: u32 = 0,
    towers: u32 = 0,
    inhibitors: u32 = 0,
    dragons: u32 = 0,
    elders: u32 = 0,
    barons: u32 = 0,
    heralds: u32 = 0,
    grubs: u32 = 0,
    item_gold: u32 = 0,
};

pub const Timer = struct {
    /// "Dragon", "Baron", "Their top inhibitor"
    what: []const u8,
    /// Game seconds it is back at
    back: f64,
};

/// A difference's spread over the matchup's games at this minute, me minus them
pub const Typical = struct { p10: i32, p25: i32, mean: i32, p75: i32, p90: i32 };

pub const Standing = enum {
    far_behind,
    behind,
    typical,
    ahead,
    far_ahead,

    pub fn of(v: i64, t: Typical) Standing {
        if (v < t.p10) return .far_behind;
        if (v < t.p25) return .behind;
        if (v <= t.p75) return .typical;
        if (v <= t.p90) return .ahead;
        return .far_ahead;
    }

    pub fn words(s: Standing) []const u8 {
        return switch (s) {
            .far_behind => "behind 9 games in 10 like it",
            .behind => "behind most games like it",
            .typical => "about typical",
            .ahead => "ahead of most games like it",
            .far_ahead => "ahead of 9 games in 10 like it",
        };
    }
};

pub const Compare = struct { now: i64, typical: Typical, standing: Standing };

/// My lane against the matchup's curve
pub const Lane = struct {
    role: Role,
    me: u32,
    opponent: u32,
    matchup: lanecard.Matchup,
    /// Whole minutes played: the curve's frame compared; null outside the curve
    minute: ?u8,
    cs: ?Compare,
    /// From item prices: nobody's gold but your own is shown in game
    gold: ?Compare,
};

/// The game so far, one sample per `sample_every` seconds: the poller keeps them
pub const Sample = struct {
    time: f32,
    /// Item gold, us minus them: the team's and my lane's
    team: i32,
    lane: ?i32,
};

pub const sample_every = 20;

pub const InGame = struct {
    time: f64,
    rows: [Role.count]Row,
    /// Ours, theirs
    score: [2]Score,
    /// Soonest first; only those still to come
    timers: []const Timer,
    lane: ?Lane,
    /// Why there is no lane comparison; "" when there is one
    lane_note: []const u8,
    /// "last 30 days"; "" without curves
    period: []const u8,
    /// My unspent gold
    gold: f64,
    /// Oldest first; the poller fills it in
    history: []const Sample = &.{},

    /// This moment as a history sample
    pub fn sample(g: *const InGame) Sample {
        const lane: ?i32 = if (g.lane) |l| @intCast(g.rows[@backingInt(l.role)].goldDiff().?) else null;
        return .{ .time = @floatCast(g.time), .team = @as(i32, @intCast(g.score[0].item_gold)) - @as(i32, @intCast(g.score[1].item_gold)), .lane = lane };
    }
};

/// The curves' frames this sparse are not compared against (lanecard's chart floor)
const min_minute_games = 10;
const dragon_respawn = 300;
const elder_respawn = 360;
const baron_respawn = 360;
const inhibitor_respawn = 300;
/// Dragons for a soul: the next one is the elder
const soul_dragons = 4;

/// Allocates in `arena`
pub fn build(arena: std.mem.Allocator, stats: *const Stats, curves: ?*const curvesfile.Curves, g: live.Game, tier: ?[]const u8) !InGame {
    const me = g.me();
    const mine: live.Team = if (me) |m| m.team else .order;
    var out: InGame = .{
        .time = g.time,
        .rows = undefined,
        .score = .{ .{}, .{} },
        .timers = &.{},
        .lane = null,
        .lane_note = "",
        .period = if (curves) |c| try lanecard.period(arena, c) else "",
        .gold = g.gold,
    };
    for (&out.rows, Role.all) |*r, role| r.* = .{ .role = role };

    for ([_]live.Team{ mine, other(mine) }, 0..) |team, side| {
        var picks: [Role.count]core.Pick = undefined;
        var players: [Role.count]live.Player = undefined;
        var n: usize = 0;
        var unknown = false;
        for (g.players) |p| {
            if (p.team != team or n == picks.len) continue;
            players[n] = p;
            picks[n] = .{ .champion = idOf(stats, p.champion), .role = p.role };
            unknown = unknown or p.role == null;
            n += 1;
        }
        var roles: [Role.count]?Role = undefined;
        for (roles[0..n], picks[0..n]) |*r, p| r.* = p.role;
        if (unknown) core.score.inferRoles(stats, picks[0..n], roles[0..n]);
        const sc = &out.score[side];
        for (players[0..n], picks[0..n], roles[0..n]) |p, pick, role| {
            sc.kills += p.kills;
            sc.item_gold += p.item_gold;
            const r = role orelse continue;
            const seat: Seat = .{
                .champion = pick.champion,
                .level = p.level,
                .kills = p.kills,
                .deaths = p.deaths,
                .assists = p.assists,
                .cs = p.cs,
                .item_gold = p.item_gold,
                .dead = p.dead,
                .respawn = p.respawn,
                .me = p.me,
            };
            const row = &out.rows[@backingInt(r)];
            if (side == 0) row.ours = row.ours orelse seat else row.theirs = row.theirs orelse seat;
        }
    }

    out.timers = try objectives(arena, g, mine, &out.score);
    if (me != null) try myLane(arena, stats, curves, g.time, tier, &out);
    return out;
}

fn other(t: live.Team) live.Team {
    return if (t == .order) .chaos else .order;
}

fn idOf(stats: *const Stats, name: []const u8) u32 {
    const i = stats.find(name) orelse return 0;
    return stats.ids[i];
}

/// Counts objectives into `score` and lists the respawns still to come
fn objectives(arena: std.mem.Allocator, g: live.Game, mine: live.Team, score: *[2]Score) ![]const Timer {
    var dragon: ?f64 = null;
    var baron: ?f64 = null;
    // [ours, theirs][lane]: when each inhibitor went down, null while up
    var inhibs: [2][3]?f64 = @splat(@splat(null));
    for (g.events) |e| {
        const side: ?usize = if (e.team) |t| @intFromBool(t != mine) else null;
        switch (e.kind) {
            .dragon, .elder => {
                if (side) |s| if (e.kind == .elder) {
                    score[s].elders += 1;
                } else {
                    score[s].dragons += 1;
                };
                const soul = score[0].dragons >= soul_dragons or score[1].dragons >= soul_dragons;
                dragon = e.time + @as(f64, if (soul) elder_respawn else dragon_respawn);
            },
            .baron => {
                if (side) |s| score[s].barons += 1;
                baron = e.time + baron_respawn;
            },
            .herald => if (side) |s| {
                score[s].heralds += 1;
            },
            .grubs => if (side) |s| {
                score[s].grubs += 1;
            },
            .tower => if (side) |s| {
                score[s].towers += 1;
            },
            // The owner is the side that lost it: the other one from the taker
            .inhibitor => if (side) |s| {
                score[s].inhibitors += 1;
                if (e.lane) |l| inhibs[1 - s][@backingInt(l)] = e.time + inhibitor_respawn;
            },
            .inhibitor_back => if (side) |s| if (e.lane) |l| {
                inhibs[s][@backingInt(l)] = null;
            },
        }
    }
    var out: std.ArrayList(Timer) = .empty;
    const elder = score[0].dragons >= soul_dragons or score[1].dragons >= soul_dragons;
    if (dragon) |t| if (t > g.time) try out.append(arena, .{ .what = if (elder) "Elder dragon" else "Dragon", .back = t });
    if (baron) |t| if (t > g.time) try out.append(arena, .{ .what = "Baron", .back = t });
    const names = [2][3][]const u8{
        .{ "Your top inhibitor", "Your mid inhibitor", "Your bot inhibitor" },
        .{ "Their top inhibitor", "Their mid inhibitor", "Their bot inhibitor" },
    };
    for (inhibs, names) |lanes, ns| for (lanes, ns) |at, name| {
        if (at) |t| if (t > g.time) try out.append(arena, .{ .what = name, .back = t });
    };
    std.mem.sort(Timer, out.items, {}, struct {
        fn sooner(_: void, a: Timer, b: Timer) bool {
            return a.back < b.back;
        }
    }.sooner);
    return out.items;
}

fn myLane(arena: std.mem.Allocator, stats: *const Stats, curves: ?*const curvesfile.Curves, time: f64, tier: ?[]const u8, out: *InGame) !void {
    const role = for (out.rows) |r| {
        if (r.ours) |s| if (s.me) break r.role;
    } else {
        out.lane_note = "Your position is unknown in this game.";
        return;
    };
    const row = out.rows[@backingInt(role)];
    const mine = row.ours.?;
    const theirs = row.theirs orelse {
        out.lane_note = "No lane opponent found.";
        return;
    };
    const c = curves orelse {
        out.lane_note = "No curves file: lane comparison off.";
        return;
    };
    if (mine.champion == 0 or theirs.champion == 0) {
        out.lane_note = "A champion in your lane is newer than the data.";
        return;
    }
    const found = lanecard.view(c, role, lanecard.bracketOf(tier), mine.champion, theirs.champion) orelse {
        out.lane_note = try std.fmt.allocPrint(arena, "No {s} games of {s} against {s} in the {s}.", .{
            role.label(), stats.nameOf(mine.champion), stats.nameOf(theirs.champion), out.period,
        });
        return;
    };
    const v = found.view;
    var lane: Lane = .{
        .role = role,
        .me = mine.champion,
        .opponent = theirs.champion,
        .matchup = try lanecard.matchup(arena, v, found.bracket),
        .minute = null,
        .cs = null,
        .gold = null,
    };
    const whole: usize = @intFromFloat(@floor(time / 60));
    if (whole >= 1 and whole <= v.minutes() and v.minute(whole - 1).n >= @min(min_minute_games, v.games())) {
        const m = v.minute(whole - 1);
        lane.minute = @intCast(whole);
        const cs_est = v.estimate(.cs, whole - 1).mean;
        const gold_est = v.estimate(.gold, whole - 1).mean;
        lane.cs = compare(@as(i64, mine.cs) - theirs.cs, m.cs, cs_est);
        lane.gold = compare(row.goldDiff().?, m.gold, gold_est);
    }
    out.lane = lane;
}

fn compare(now: i64, s: curvesfile.Spread, mean: i16) Compare {
    const t: Typical = .{ .p10 = s.p10, .p25 = s.p25, .mean = mean, .p75 = s.p75, .p90 = s.p90 };
    return .{ .now = now, .typical = t, .standing = .of(now, t) };
}

/// "12:05"
pub fn clock(buf: []u8, seconds: f64) []const u8 {
    const s: u64 = @intFromFloat(@max(0, seconds));
    return std.fmt.bufPrint(buf, "{d}:{d:0>2}", .{ s / 60, s % 60 }) catch "?";
}

const testing = std.testing;
const cardscenes = @import("cardscenes.zig");

test "in game: lanes by role, score, timers, my lane against the curve" {
    var f = try cardscenes.fixture();
    defer f.deinit();
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const body = try std.Io.Dir.cwd().readFileAlloc(testing.io, live.fixture_path, arena, .limited(1 << 20));
    const g = try live.parse(arena, body);
    const st = &f.stats;
    const ig = try build(arena, st, &f.curves, g, "GOLD");

    const mid = ig.rows[@backingInt(Role.middle)];
    try testing.expectEqualStrings("Orianna", st.nameOf(mid.ours.?.champion));
    try testing.expect(mid.ours.?.me);
    try testing.expectEqualStrings("Syndra", st.nameOf(mid.theirs.?.champion));
    try testing.expectEqual(550, mid.goldDiff().?);
    // Wukong isn't in the fixture's stats: the seat stays, as champion 0
    try testing.expectEqual(0, ig.rows[@backingInt(Role.jungle)].theirs.?.champion);

    try testing.expectEqual(5, ig.score[0].kills);
    try testing.expectEqual(.{ 1, 1 }, .{ ig.score[0].dragons, ig.score[1].dragons });
    try testing.expectEqual(.{ 2, 1 }, .{ ig.score[0].towers, ig.score[1].towers });
    try testing.expectEqual(1, ig.score[1].grubs);
    try testing.expectEqual(1, ig.timers.len);
    try testing.expectEqualStrings("Dragon", ig.timers[0].what);
    try testing.expectEqual(952, ig.timers[0].back);

    const l = ig.lane.?;
    try testing.expectEqual(12, l.minute.?);
    try testing.expectEqual(550, l.gold.?.now);
    try testing.expectEqual(8, l.cs.?.now);
    try testing.expect(l.matchup.points.len > 0);
}

test "in game: blank positions are inferred, inhibitors come back" {
    var f = try cardscenes.fixture();
    defer f.deinit();
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const st = &f.stats;
    const p = struct {
        fn of(champion: []const u8, team: live.Team, me: bool) live.Player {
            return .{ .champion = champion, .team = team, .role = null, .level = 1, .kills = 0, .deaths = 0, .assists = 0, .cs = 0, .dead = false, .respawn = 0, .item_gold = 0, .me = me };
        }
    }.of;
    const players = [_]live.Player{
        p("Garen", .order, false),  p("Vi", .order, false),    p("Ahri", .order, true),    p("Jinx", .order, false),    p("Lux", .order, false),
        p("Darius", .chaos, false), p("Viego", .chaos, false), p("Syndra", .chaos, false), p("Caitlyn", .chaos, false), p("Thresh", .chaos, false),
    };
    const events = [_]live.Event{
        .{ .time = 1500, .kind = .inhibitor, .team = .order, .lane = .mid },
        .{ .time = 1600, .kind = .inhibitor, .team = .chaos, .lane = .top },
        .{ .time = 1700, .kind = .inhibitor_back, .team = .chaos, .lane = .mid },
    };
    const ig = try build(arena, st, null, .{ .time = 1710, .mode = "CLASSIC", .players = &players, .events = &events, .gold = 0 }, null);
    try testing.expectEqualStrings("Syndra", st.nameOf(ig.rows[@backingInt(Role.middle)].theirs.?.champion));
    try testing.expectEqualStrings("Ahri", st.nameOf(ig.rows[@backingInt(Role.middle)].ours.?.champion));
    try testing.expectEqual(1, ig.timers.len);
    try testing.expectEqualStrings("Your top inhibitor", ig.timers[0].what);
    try testing.expectEqual(null, ig.lane);
    try testing.expect(ig.lane_note.len > 0);
}
