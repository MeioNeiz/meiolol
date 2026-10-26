//! The Your games list's data (ui.yourlist.List) from `meiolol your-example`'s file: the
//! default role's player, every game, in data/your/list.bin
const std = @import("std");
const ui = @import("ui");
const game = @import("../api/game.zig");
const lane_minute = @import("core").curvesfile.lane_minute;
const yourgame = @import("yourgame.zig");

const Allocator = std.mem.Allocator;
const yl = ui.yourlist;
const gd = ui.gamedata;

pub const path = "data/your/list.bin";

/// The curve's minutes with this many games; api/game.zig reads it the same way
const min_minute_games = 10;

/// `games` newest first, as the report has them; `champ` names a champion id and its
/// portrait. No Site: the API makes the same list for a lookup
pub fn list(arena: Allocator, who: yourgame.Example.Who, games: []const game.Game, nm: yourgame.Names, ctx: anytype, champ: fn (@TypeOf(ctx), u32) anyerror!ui.champ.Champ) !yl.List {
    var used: Used(@TypeOf(ctx), champ) = .{ .ctx = ctx };
    var arts: yourgame.Arts = .{ .names = nm };
    var out: std.ArrayList(yl.Game) = .empty;
    var pages: u16 = 0;
    for (games) |g| {
        var row: yl.Game = .{
            .start_ms = g.start_ms,
            .dur = @intCast(std.math.clamp(g.duration_s, 0, std.math.maxInt(u16))),
            .patch = g.patch,
            .queue = yl.queueOf(g.queue),
            .role = if (g.role) |r| std.meta.stringToEnum(ui.role.Role, r) else null,
            .champ = try used.at(arena, g.champion),
            .opp = if (g.opponent) |o| try used.at(arena, o) else null,
            .win = g.win,
            .remake = g.remake,
            .k = count(g.kills),
            .d = count(g.deaths),
            .a = count(g.assists),
            .lane14 = if (g.lane) |l| lane14(l) else null,
        };
        const wc = try arena.alloc(u8, g.win_chance.len);
        for (g.win_chance, wc) |v, *o| o.* = @intCast(@min(v, 100));
        row.wc = wc;
        for (g.players) |p| if (p.you) {
            for (p.loadout.items, &row.items) |id, *x| x.* = try arts.at(arena, .item, id);
        };
        if (yourgame.pageSlot(g)) |you| {
            const st = g.detail.?.seats[you];
            row.level = st.level;
            row.cs = @intCast(@min(st.cs, std.math.maxInt(u16)));
            row.page = pages;
            pages += 1;
        }
        try out.append(arena, row);
    }
    return .{
        .player = .{
            .name = who.name,
            .tag = who.tag,
            .platform = who.platform,
            .tier = who.tier,
            .division = who.division,
            .lp = if (who.lp) |lp| @intCast(std.math.clamp(lp, 0, std.math.maxInt(u16))) else null,
            .refreshed = who.refreshed,
        },
        .champs = used.list.items,
        .arts = arts.list.items,
        .games = out.items,
    };
}

/// List.champs, each champion once
fn Used(comptime Ctx: type, comptime champ: fn (Ctx, u32) anyerror!ui.champ.Champ) type {
    return struct {
        ctx: Ctx,
        list: std.ArrayList(ui.champ.Champ) = .empty,
        ids: std.ArrayList(u32) = .empty,

        fn at(u: *@This(), a: Allocator, id: u32) !u16 {
            if (std.mem.findScalar(u32, u.ids.items, id)) |i| return @intCast(i);
            try u.list.append(a, try champ(u.ctx, id));
            try u.ids.append(a, id);
            return @intCast(u.ids.items.len - 1);
        }
    };
}

fn count(v: i64) u16 {
    return @intCast(std.math.clamp(v, 0, 999));
}

fn lane14(l: game.LaneReport) ?yl.Lane14 {
    const m = lane_minute - 1;
    if (m >= l.gold.len) return null;
    var out: yl.Lane14 = .{ .you = l.gold[m] };
    if (l.curve) |c| if (m < c.n.len and m < c.gold.len and c.n[m] >= min_minute_games) {
        out.typ = c.gold[m];
    };
    return out;
}

const testing = std.testing;

fn testChamp(_: void, id: u32) anyerror!ui.champ.Champ {
    return .{ .name = if (id == 7) "LeBlanc" else "Ahri", .src = "" };
}

fn testGame(start_ms: i64, champion: u32) game.Game {
    return .{ .start_ms = start_ms, .queue = 440, .patch = "16.21", .duration_s = 1500, .remake = false, .win = true, .role = "mid", .champion = champion, .opponent = 7, .kills = 3, .deaths = -1, .assists = 4000, .lane = null };
}

test "rows without detail: no page, CS or level; champions once; lane at 14 against a full curve only" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    var gold: [20]i16 = undefined;
    for (&gold, 0..) |*x, i| x.* = @intCast(i * 10);
    var n: [20]u32 = @splat(50);
    n[13] = 9;
    var games = [_]game.Game{ testGame(2000, 103), testGame(1000, 7) };
    games[0].lane = .{ .gold = &gold, .xp = &.{}, .cs = &.{}, .cs10 = null, .level6 = .{ null, null }, .first_item = .{ null, null }, .lane_deaths = 0, .lane_kills = 0, .curve = .{ .patch = "16.21", .bracket = "All", .pooled = false, .games = 50, .n = &n, .gold = &@as([20][3]i16, @splat(.{ -100, 0, 100 })), .xp = &.{}, .cs = &.{}, .level6 = .{ null, null }, .first_item = .{ null, null } }, .fall = null, .rise = null };
    games[1].lane = .{ .gold = gold[0..10], .xp = &.{}, .cs = &.{}, .cs10 = null, .level6 = .{ null, null }, .first_item = .{ null, null }, .lane_deaths = 0, .lane_kills = 0, .curve = null, .fall = null, .rise = null };
    const l = try list(a, .{ .name = "Example player", .lp = 70000 }, &games, .{}, {}, testChamp);
    try testing.expectEqual(2, l.champs.len);
    try testing.expectEqual(l.games[0].opp.?, l.games[1].champ);
    try testing.expectEqual(yl.Queue.flex, l.games[0].queue);
    try testing.expectEqual(ui.role.Role.mid, l.games[0].role.?);
    try testing.expectEqual(null, l.games[0].page);
    try testing.expectEqual(null, l.games[0].cs);
    try testing.expectEqual(gd.no_art, l.games[0].items[0]);
    try testing.expectEqual(0, l.games[0].d);
    try testing.expectEqual(999, l.games[0].a);
    try testing.expectEqual(std.math.maxInt(u16), l.player.lp.?);
    // Minute 14 has 9 games on the curve: too thin for the typical
    try testing.expectEqual(yl.Lane14{ .you = 130 }, l.games[0].lane14.?);
    try testing.expectEqual(null, l.games[1].lane14);
}
