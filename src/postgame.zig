//! The post game view (docs/plan/app.md APP11) from the client's end of game block
//! (lcu/eog.zig) and what the poller kept through the game (ingame.Sample): the verdict,
//! award cards (a champion's best figures) and both teams lane by lane. Facts, no
//! advice. Pure.

const std = @import("std");
const core = @import("core");
const eog = @import("lcu/eog.zig");
const ingame = @import("ingame.zig");
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

/// The game's best figure of a kind, held by one champion
pub const Figure = struct {
    kind: Kind,
    /// KDA as (kills + assists) / max(1, deaths); the rest as counted
    value: f64,

    pub const Kind = enum { damage, kda, gold, cs, vision };
};

/// One card per champion holding any best figure
pub const Award = struct {
    champion: u32,
    ours: bool,
    figures: []const Figure,
};

pub const PostGame = struct {
    win: bool,
    /// Before the client's end of game block: the last in-game rows and kills, no result
    pending: bool = false,
    /// Seconds
    length: u32,
    /// "Victory 28:42"
    verdict: []const u8,
    /// Ours first, at most `max_awards`
    awards: []const Award,
    rows: [Role.count]Row,
    /// Ours, theirs
    kills: [2]u32,
    gold: [2]u32,
    history: []const ingame.Sample,
};

/// What the last in-game tick knew: positions the end of game block may leave blank
pub const Hint = struct { champion: u32, role: Role, ours: bool };

/// The last in-game tick, for the post game until the end of game block lands
pub const Last = struct {
    /// Seconds
    time: f64,
    rows: [Role.count]Row,
    kills: [2]u32,

    /// Gold is item gold here: the game gives nobody's earned gold
    pub fn of(g: *const ingame.InGame) Last {
        var out: Last = .{ .time = g.time, .rows = undefined, .kills = .{ g.score[0].kills, g.score[1].kills } };
        for (&out.rows, g.rows) |*r, x| r.* = .{ .role = x.role, .ours = seat(x.ours), .theirs = seat(x.theirs) };
        return out;
    }

    fn seat(s: ?ingame.Seat) ?Seat {
        const x = s orelse return null;
        return .{
            .champion = x.champion,
            .kills = x.kills,
            .deaths = x.deaths,
            .assists = x.assists,
            .cs = x.cs,
            .gold = x.item_gold,
            .damage = 0,
            .vision = 0,
            .level = x.level,
            .me = x.me,
        };
    }
};

/// The post game while the client is still counting: the last in-game tick, no verdict
pub fn pending(last: Last, history: []const ingame.Sample) PostGame {
    return .{
        .win = false,
        .pending = true,
        .length = @intFromFloat(last.time),
        .verdict = "Result coming",
        .awards = &.{},
        .rows = last.rows,
        .kills = last.kills,
        .gold = .{ 0, 0 },
        .history = history,
    };
}

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
        .awards = &.{},
        .rows = undefined,
        .kills = .{ 0, 0 },
        .gold = .{ 0, 0 },
        .history = in.history,
    };
    for (&out.rows, Role.all) |*r, role| r.* = .{ .role = role };
    var clock_buf: [16]u8 = undefined;
    out.verdict = try std.fmt.allocPrint(arena, "{s} {s}", .{
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
    return out;
}

pub const max_awards = 4;

fn awards(arena: std.mem.Allocator, players: []const eog.Player) ![]const Award {
    const kinds = std.enums.values(Figure.Kind);
    // Kinds in order of weight, so a champion's place is that of its weightiest figure
    var held: [kinds.len]struct { player: eog.Player, figure: Figure } = undefined;
    var n: usize = 0;
    for (kinds) |kind| {
        var best: ?eog.Player = null;
        for (players) |p| {
            if (best == null or score(kind, p) > score(kind, best.?)) best = p;
        }
        const b = best orelse continue;
        if (score(kind, b) == 0) continue;
        held[n] = .{ .player = b, .figure = .{ .kind = kind, .value = score(kind, b) } };
        n += 1;
    }
    var out: std.ArrayList(Award) = .empty;
    for (held[0..n], 0..) |x, i| {
        const first = for (held[0..i]) |y| {
            if (y.player.champion == x.player.champion and y.player.ours == x.player.ours) break false;
        } else true;
        if (!first) continue;
        if (out.items.len == max_awards) break;
        var figures: std.ArrayList(Figure) = .empty;
        for (held[i..n]) |y| if (y.player.champion == x.player.champion and y.player.ours == x.player.ours) {
            try figures.append(arena, y.figure);
        };
        try out.append(arena, .{ .champion = x.player.champion, .ours = x.player.ours, .figures = figures.items });
    }
    std.sort.insertion(Award, out.items, {}, struct {
        fn f(_: void, a: Award, b: Award) bool {
            return a.ours and !b.ours;
        }
    }.f);
    return out.items;
}

fn score(kind: Figure.Kind, p: eog.Player) f64 {
    return switch (kind) {
        .damage => @floatFromInt(p.damage),
        .kda => @as(f64, @floatFromInt(p.kills + p.assists)) / @as(f64, @floatFromInt(@max(1, p.deaths))),
        .gold => @floatFromInt(p.gold),
        .cs => @floatFromInt(p.cs),
        .vision => @floatFromInt(p.vision),
    };
}

const testing = std.testing;
const cardscenes = @import("cardscenes.zig");

test "post game: verdict, rows by role, award cards" {
    var f = try cardscenes.fixture();
    defer f.deinit();
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const body = try std.Io.Dir.cwd().readFileAlloc(testing.io, eog.fixture_path, arena, .limited(1 << 20));
    const e = try eog.parse(arena, body);
    const pg = try build(arena, .{ .stats = &f.stats, .curves = &f.curves, .eog = e, .tier = "GOLD" });
    try testing.expectEqualStrings("Victory 28:42", pg.verdict);
    const mid = pg.rows[@backingInt(Role.middle)];
    try testing.expectEqual(61, mid.ours.?.champion);
    try testing.expectEqual(134, mid.theirs.?.champion);
    try testing.expectEqual(1500, mid.goldDiff().?);
    try testing.expectEqual(.{ 31, 20 }, pg.kills);
    // Orianna: damage, KDA and cs (224 to Kog'Maw's 223) on one card
    try testing.expectEqual(3, pg.awards.len);
    try testing.expectEqual(61, pg.awards[0].champion);
    const ori = pg.awards[0].figures;
    try testing.expectEqual(3, ori.len);
    try testing.expectEqual(.damage, ori[0].kind);
    try testing.expectEqual(31_200, ori[0].value);
    try testing.expectApproxEqAbs(19.0 / 3.0, ori[1].value, 1e-9);
    try testing.expectEqual(.cs, ori[2].kind);
    try testing.expectEqual(222, pg.awards[1].champion);
    try testing.expectEqual(412, pg.awards[2].champion);
}

test "post game awards: five holders, ours first, at most four" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const base: eog.Player = .{ .champion = 0, .ours = true, .role = null, .me = false, .kills = 0, .deaths = 1, .assists = 0, .cs = 0, .gold = 0, .damage = 0, .vision = 0, .level = 1 };
    var ps: [5]eog.Player = @splat(base);
    ps[0].champion = 1;
    ps[0].ours = false;
    ps[0].damage = 30_000;
    ps[1].champion = 2;
    ps[1].kills = 9;
    ps[2].champion = 3;
    ps[2].ours = false;
    ps[2].gold = 15_000;
    ps[3].champion = 4;
    ps[3].cs = 250;
    ps[4].champion = 5;
    ps[4].vision = 70;
    const got = try awards(arena_state.allocator(), &ps);
    try testing.expectEqual(4, got.len);
    for (got, [_]u32{ 2, 4, 1, 3 }) |a, c| try testing.expectEqual(c, a.champion);
}
