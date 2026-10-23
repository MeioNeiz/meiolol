//! The post game view (docs/plan/app.md APP11) from the client's end of game block
//! (lcu/eog.zig) and what the poller kept through the game (ingame.Sample): a verdict
//! line, the team gold story, my lane at 14 min against the matchup's games, award chips
//! and both teams lane by lane. Facts, no advice. Pure.

const std = @import("std");
const core = @import("core");
const eog = @import("lcu/eog.zig");
const ingame = @import("ingame.zig");
const lanecard = @import("lanecard.zig");
const Role = core.Role;
const Stats = core.Stats;
const curvesfile = core.curvesfile;

pub const Seat = struct {
    champion: u32,
    kills: u32,
    deaths: u32,
    assists: u32,
    cs: u32,
    gold: u32,
    damage: u32,
    vision: u32,
    level: u32,
    me: bool,
};

pub const Row = struct {
    role: Role,
    ours: ?Seat = null,
    theirs: ?Seat = null,

    /// Gold earned, us minus them
    pub fn goldDiff(r: Row) ?i64 {
        const a = r.ours orelse return null;
        const b = r.theirs orelse return null;
        return @as(i64, a.gold) - b.gold;
    }
};

pub const Award = struct {
    /// "Most damage"
    what: []const u8,
    champion: u32,
    ours: bool,
};

pub const PostGame = struct {
    win: bool,
    /// Seconds
    length: u32,
    /// "Victory in 28:42."
    verdict: []const u8,
    /// Item gold through the game in one sentence; "" without history
    story: []const u8,
    /// My lane at 14 min against the matchup's games; "" when unknown
    lane: []const u8,
    awards: []const Award,
    rows: [Role.count]Row,
    /// Ours, theirs
    kills: [2]u32,
    gold: [2]u32,
    history: []const ingame.Sample,
};

/// What the last in-game tick knew: positions the end of game block may leave blank
pub const Hint = struct { champion: u32, role: Role, ours: bool };

pub const Input = struct {
    stats: *const Stats,
    curves: ?*const curvesfile.Curves = null,
    eog: eog.Eog,
    history: []const ingame.Sample = &.{},
    hints: []const Hint = &.{},
    tier: ?[]const u8 = null,
};

/// Allocates in `arena`
pub fn build(arena: std.mem.Allocator, in: Input) !PostGame {
    var out: PostGame = .{
        .win = in.eog.win,
        .length = in.eog.length,
        .verdict = "",
        .story = "",
        .lane = "",
        .awards = &.{},
        .rows = undefined,
        .kills = .{ 0, 0 },
        .gold = .{ 0, 0 },
        .history = in.history,
    };
    for (&out.rows, Role.all) |*r, role| r.* = .{ .role = role };
    var clock_buf: [16]u8 = undefined;
    out.verdict = try std.fmt.allocPrint(arena, "{s} in {s}.", .{
        if (in.eog.win) "Victory" else "Defeat", ingame.clock(&clock_buf, @floatFromInt(in.eog.length)),
    });

    for ([_]bool{ true, false }, 0..) |ours, side| {
        var players: [Role.count]eog.Player = undefined;
        var picks: [Role.count]core.Pick = undefined;
        var n: usize = 0;
        var unknown = false;
        for (in.eog.players) |p| {
            if (p.ours != ours or n == players.len) continue;
            players[n] = p;
            var r = p.role;
            if (r == null) for (in.hints) |h| {
                if (h.champion == p.champion and h.ours == ours) r = h.role;
            };
            picks[n] = .{ .champion = p.champion, .role = r };
            unknown = unknown or r == null;
            n += 1;
        }
        var roles: [Role.count]?Role = undefined;
        for (roles[0..n], picks[0..n]) |*r, p| r.* = p.role;
        if (unknown) core.score.inferRoles(in.stats, picks[0..n], roles[0..n]);
        for (players[0..n], roles[0..n]) |p, role| {
            out.kills[side] += p.kills;
            out.gold[side] += p.gold;
            const r = role orelse continue;
            const seat: Seat = .{
                .champion = p.champion,
                .kills = p.kills,
                .deaths = p.deaths,
                .assists = p.assists,
                .cs = p.cs,
                .gold = p.gold,
                .damage = p.damage,
                .vision = p.vision,
                .level = p.level,
                .me = p.me,
            };
            const row = &out.rows[@backingInt(r)];
            if (side == 0) row.ours = row.ours orelse seat else row.theirs = row.theirs orelse seat;
        }
    }

    out.awards = try awards(arena, in.eog.players);
    out.story = try story(arena, in.history, in.eog.win);
    out.lane = try myLane(arena, in, &out);
    return out;
}

fn awards(arena: std.mem.Allocator, players: []const eog.Player) ![]const Award {
    const Pick = struct {
        what: []const u8,
        score: *const fn (eog.Player) f64,
    };
    const picks = [_]Pick{
        .{ .what = "Most damage", .score = struct {
            fn f(p: eog.Player) f64 {
                return @floatFromInt(p.damage);
            }
        }.f },
        .{ .what = "Best KDA", .score = struct {
            fn f(p: eog.Player) f64 {
                return @as(f64, @floatFromInt(p.kills + p.assists)) / @as(f64, @floatFromInt(@max(1, p.deaths)));
            }
        }.f },
        .{ .what = "Most gold", .score = struct {
            fn f(p: eog.Player) f64 {
                return @floatFromInt(p.gold);
            }
        }.f },
        .{ .what = "Most CS", .score = struct {
            fn f(p: eog.Player) f64 {
                return @floatFromInt(p.cs);
            }
        }.f },
        .{ .what = "Most vision", .score = struct {
            fn f(p: eog.Player) f64 {
                return @floatFromInt(p.vision);
            }
        }.f },
    };
    var out: std.ArrayList(Award) = .empty;
    for (picks) |pk| {
        var best: ?eog.Player = null;
        for (players) |p| {
            if (best == null or pk.score(p) > pk.score(best.?)) best = p;
        }
        const b = best orelse continue;
        if (pk.score(b) == 0) continue;
        try out.append(arena, .{ .what = pk.what, .champion = b.champion, .ours = b.ours });
    }
    return out.items;
}

/// "Item gold: +1.2k at 10 min, -800 at 20 min, +3.4k at the end; behind by up to 2.1k at
/// 17 min, a comeback."
fn story(arena: std.mem.Allocator, h: []const ingame.Sample, win: bool) ![]const u8 {
    if (h.len < 2) return "";
    var aw: std.Io.Writer.Allocating = .init(arena);
    const w = &aw.writer;
    try w.writeAll("Team item gold: ");
    var parts: usize = 0;
    for ([_]f32{ 600, 1200, 1800 }) |at| {
        if (at >= h[h.len - 1].time) break;
        const s = nearest(h, at);
        try w.print("{s}{f} at {d} min", .{ if (parts > 0) ", " else "", Gold{ .n = s.team }, @as(u32, @intFromFloat(at / 60)) });
        parts += 1;
    }
    try w.print("{s}{f} at the end", .{ if (parts > 0) ", " else "", Gold{ .n = h[h.len - 1].team } });
    var low = h[0];
    var high = h[0];
    for (h) |s| {
        if (s.team < low.team) low = s;
        if (s.team > high.team) high = s;
    }
    const swing = 1500;
    if (win and low.team <= -swing) {
        try w.print("; behind by up to {f} at {d} min, a comeback", .{ Gold{ .n = -low.team, .plain = true }, @as(u32, @intFromFloat(low.time / 60)) });
    } else if (!win and high.team >= swing) {
        try w.print("; ahead by up to {f} at {d} min", .{ Gold{ .n = high.team, .plain = true }, @as(u32, @intFromFloat(high.time / 60)) });
    }
    try w.writeAll(".");
    return aw.written();
}

fn nearest(h: []const ingame.Sample, at: f32) ingame.Sample {
    var best = h[0];
    for (h) |s| if (@abs(s.time - at) < @abs(best.time - at)) {
        best = s;
    };
    return best;
}

/// "+1.2k", "-800", "even"; plain drops the sign
const Gold = struct {
    n: i64,
    plain: bool = false,

    pub fn format(g: Gold, w: *std.Io.Writer) std.Io.Writer.Error!void {
        if (g.n == 0) return w.writeAll("even");
        if (!g.plain) try w.writeAll(if (g.n > 0) "+" else "-");
        const a = @abs(g.n);
        if (a < 1000) return w.print("{d}", .{a});
        try w.print("{d:.1}k", .{@as(f64, @floatFromInt(a)) / 1000});
    }
};

/// "At 14 min your lane was +550 item gold over Syndra, ahead of most games like it.
/// Over the game Orianna earned 1.5k more gold."
fn myLane(arena: std.mem.Allocator, in: Input, out: *const PostGame) ![]const u8 {
    const row = for (out.rows) |r| {
        if (r.ours) |s| if (s.me) break r;
    } else return "";
    const me = row.ours.?;
    const them = row.theirs orelse return "";
    var aw: std.Io.Writer.Allocating = .init(arena);
    const w = &aw.writer;
    const at: f32 = curvesfile.lane_minute * 60;
    lane: {
        const c = in.curves orelse break :lane;
        if (in.history.len == 0 or in.history[in.history.len - 1].time < at) break :lane;
        const s = nearest(in.history, at);
        const now = s.lane orelse break :lane;
        const found = lanecard.view(c, row.role, lanecard.bracketOf(in.tier), me.champion, them.champion) orelse break :lane;
        const v = found.view;
        const i = curvesfile.lane_minute - 1;
        if (i >= v.minutes()) break :lane;
        const cmp = ingame.compare(now, v.minute(i).gold, v.estimate(.gold, i).mean);
        try w.print("At {d} min your lane was {f} item gold against {s}: {s}. ", .{
            curvesfile.lane_minute, Gold{ .n = now }, in.stats.nameOf(them.champion), cmp.standing.words(),
        });
    }
    const diff = row.goldDiff().?;
    try w.print("Over the game {s} earned {f} {s} than {s}.", .{
        in.stats.nameOf(me.champion), Gold{ .n = diff, .plain = true }, if (diff >= 0) "more gold" else "less gold", in.stats.nameOf(them.champion),
    });
    return aw.written();
}

const testing = std.testing;
const cardscenes = @import("cardscenes.zig");

test "post game: verdict, rows by role, awards, gold story, my lane" {
    var f = try cardscenes.fixture();
    defer f.deinit();
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const body = try std.Io.Dir.cwd().readFileAlloc(testing.io, eog.fixture_path, arena, .limited(1 << 20));
    const e = try eog.parse(arena, body);
    var history: std.ArrayList(ingame.Sample) = .empty;
    var t: f32 = 0;
    while (t <= 1722) : (t += ingame.sample_every) {
        // Behind 2k at 15 min, then ahead
        const x = t / 60;
        const team: i32 = @intFromFloat(if (x < 15) -2000 * x / 15 else -2000 + 400 * (x - 15));
        try history.append(arena, .{ .time = t, .team = team, .lane = @intFromFloat(40 * x) });
    }
    const pg = try build(arena, .{ .stats = &f.stats, .curves = &f.curves, .eog = e, .history = history.items, .tier = "GOLD" });
    try testing.expectEqualStrings("Victory in 28:42.", pg.verdict);
    const mid = pg.rows[@backingInt(Role.middle)];
    try testing.expectEqual(61, mid.ours.?.champion);
    try testing.expectEqual(134, mid.theirs.?.champion);
    try testing.expectEqual(1500, mid.goldDiff().?);
    try testing.expectEqual(.{ 31, 20 }, pg.kills);
    try testing.expectEqual(5, pg.awards.len);
    try testing.expectEqual(61, pg.awards[0].champion);
    try testing.expect(std.mem.indexOf(u8, pg.story, "a comeback") != null);
    try testing.expect(std.mem.startsWith(u8, pg.lane, "At 14 min your lane was +560 item gold against Syndra"));
    try testing.expect(std.mem.endsWith(u8, pg.lane, "Over the game Orianna earned 1.5k more gold than Syndra."));
}
