//! A Your games report's games (game.zig) as the pages' binary data: the game page's
//! ui.gamedata.Data and the list's ui.yourlist.List. The site build makes them for the
//! example (site/yourgame.zig), the service for a lookup (/api/game, /api/list), so both
//! show a game the same. Champions come by callback: the site names them from its stats,
//! the service from Data Dragon
const std = @import("std");
const ui = @import("ui");
const game = @import("game.zig");
const ddragon = @import("../ddragon.zig");
const Date = @import("../date.zig").Date;
const lane_minute = @import("core").curvesfile.lane_minute;

const Allocator = std.mem.Allocator;
const gd = ui.gamedata;
const yl = ui.yourlist;

/// The looked-up player: api/root.zig PlayerOut, the example's without a Riot ID
pub const Who = struct {
    name: []const u8 = "",
    tag: []const u8 = "",
    platform: []const u8 = "",
    tier: ?[]const u8 = null,
    division: ?[]const u8 = null,
    lp: ?i64 = null,
    refreshed: i64 = 0,
};

const queues = [_]struct { i64, []const u8 }{
    .{ 420, "Ranked solo" }, .{ 440, "Ranked flex" }, .{ 400, "Draft" }, .{ 480, "Swiftplay" },
};

const months = [_][]const u8{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };

/// Data Dragon's names and icons, sorted by id (ddragon.find)
pub const Names = struct {
    /// Data Dragon's version, for items the lists don't name (potions, wards, parts)
    version: []const u8 = "",
    items: []const ddragon.Named = &.{},
    spells: []const ddragon.Named = &.{},
    runes: []const ddragon.Named = &.{},
};

/// Data.arts, each item, spell and rune once
pub const Arts = struct {
    names: Names,
    list: std.ArrayList(ui.art.Art) = .empty,
    /// Kind in the high bits, so an item and a rune with one id stay apart
    keys: std.ArrayList(u64) = .empty,

    pub const Kind = enum(u2) { item, spell, rune };

    pub fn at(x: *Arts, a: Allocator, k: Kind, id: u32) !u16 {
        if (id == 0) return gd.no_art;
        const key = @as(u64, @backingInt(k)) << 32 | id;
        if (std.mem.findScalar(u64, x.keys.items, key)) |i| return @intCast(i);
        if (x.list.items.len >= gd.no_art) return gd.no_art;
        const named = switch (k) {
            .item => x.names.items,
            .spell => x.names.spells,
            .rune => x.names.runes,
        };
        var art: ui.art.Art = if (ddragon.find(named, id)) |v| .{ .name = v.name, .src = v.icon } else .{ .name = try a.print("#{d}", .{id}), .src = "" };
        if (art.src.len == 0 and k == .item and x.names.version.len > 0)
            art.src = try a.print("https://ddragon.leagueoflegends.com/cdn/{s}/img/item/{d}.png", .{ x.names.version, id });
        try x.list.append(a, art);
        try x.keys.append(a, key);
        return @intCast(x.list.items.len - 1);
    }
};

/// Your slot when the game has a page (a timeline and its detail)
pub fn pageSlot(g: game.Game) ?usize {
    const d = g.detail orelse return null;
    if (g.players.len != d.seats.len or g.players.len > 10 or g.win_chance.len < 2) return null;
    for (g.players, 0..) |p, i| if (p.you) return i;
    return null;
}

/// Games with a timeline and its detail; `champ` names a champion id and its portrait
pub fn data(arena: Allocator, nm: Names, games: []const game.Game, ctx: anytype, champ: fn (@TypeOf(ctx), u32) anyerror!ui.champ.Champ) !gd.Data {
    var used: Used(@TypeOf(ctx), champ) = .{ .ctx = ctx };
    var arts: Arts = .{ .names = nm };
    var out: std.ArrayList(gd.Game) = .empty;
    for (games) |g| {
        const you = pageSlot(g) orelse continue;
        const d = g.detail.?;
        const team = g.players[you].team;

        const seats = try arena.alloc(gd.Seat, g.players.len);
        for (g.players, d.seats, seats) |p, st, *o| {
            o.* = .{
                .champ = try used.at(arena, p.champion),
                .us = p.team == team,
                .role = if (p.role) |r| std.meta.stringToEnum(ui.role.Role, r) else null,
                .k = @intCast(std.math.clamp(p.kills, 0, 999)),
                .d = @intCast(std.math.clamp(p.deaths, 0, 999)),
                .a = @intCast(std.math.clamp(p.assists, 0, 999)),
                .riot_id = p.riot_id orelse "",
                .cs = @intCast(@min(st.cs, std.math.maxInt(u16))),
                .gold = st.gold,
                .level = st.level,
                .damage = st.damage,
                .taken = st.taken,
                .lane14 = st.lane14,
            };
            const lo = p.loadout;
            for (lo.items, &o.items) |id, *x| x.* = try arts.at(arena, .item, id);
            for (lo.spells, &o.spells) |id, *x| x.* = try arts.at(arena, .spell, id);
            o.keystone = try arts.at(arena, .rune, lo.keystone);
            o.second = try arts.at(arena, .rune, lo.second);
            // All zero: a summary from before loadouts
            if (!std.meta.eql(lo, game.Loadout{})) o.vision = @intCast(@min(lo.vision, std.math.maxInt(u16)));
        }
        const buys = try arena.alloc(gd.Buy, d.buys.len);
        for (d.buys, buys) |b, *o| o.* = .{ .t = secs(b.t_s), .item = try arts.at(arena, .item, b.item) };
        const skills = try arena.alloc(u8, d.skills.len);
        for (d.skills, skills) |k, *o| o.* = if (k >= 1 and k <= 4) "QWER"[k - 1] else '?';

        const kills = try arena.alloc(gd.Kill, d.kills.len);
        for (d.kills, kills) |k, *o| {
            const assists = try arena.alloc(u8, k.assists.len);
            for (k.assists, assists) |x, *y| y.* = @intCast(@min(x, gd.no_slot));
            o.* = .{ .t = secs(k.t_s), .killer = k.killer, .victim = k.victim, .assists = assists, .x = k.x, .y = k.y, .gold = @intCast(@min(k.gold, std.math.maxInt(u16))), .fight = k.fight };
        }
        const objs = try arena.alloc(gd.Obj, d.objectives.len);
        for (d.objectives, objs) |o, *x| x.* = .{
            .t = secs(o.t_s),
            .ours = o.ours,
            .kind = std.meta.stringToEnum(gd.ObjKind, @tagName(o.kind)).?,
            .name = o.name,
            .you = o.you,
        };
        const wc = try arena.alloc(u8, g.win_chance.len);
        for (g.win_chance, wc) |v, *o| o.* = @intCast(@min(v, 100));
        // gold_lead has the game's last frame too; the page reads it by minute
        const gold = try arena.dupe(i32, d.gold_lead[0..@min(d.gold_lead.len, wc.len)]);

        const date: Date = .fromMs(g.start_ms);
        const queue = for (queues) |q| {
            if (q[0] == g.queue) break q[1];
        } else "Normal";
        try out.append(arena, .{
            .day = try arena.print("{d} {s}", .{ date.day, months[date.month - 1] }),
            .patch = g.patch,
            .queue = queue,
            .dur = secs(@intCast(@max(0, g.duration_s))),
            .win = g.win,
            .you = @intCast(you),
            .seats = seats,
            .wc = wc,
            .gold = gold,
            .kills = kills,
            .objs = objs,
            .best = if (g.best_minute) |b| .{ .minute = b.minute, .gold = b.gold } else null,
            .buys = buys,
            .skills = skills,
            .lane = if (g.lane) |l| laneOf(l) else null,
        });
    }
    return .{ .champs = used.list.items, .games = out.items, .arts = arts.list.items };
}

/// The curve's minutes with this many games; api/game.zig reads it the same way
const min_minute_games = 10;

fn laneOf(l: game.LaneReport) gd.Lane {
    const stretch = struct {
        fn f(x: ?game.Stretch) ?gd.Lane.Stretch {
            const v = x orelse return null;
            return .{ .from = v.from, .to = v.to, .change = v.change };
        }
    }.f;
    var out: gd.Lane = .{
        .gold = l.gold,
        .xp = l.xp,
        .cs = l.cs,
        .cs10 = if (l.cs10) |c| @intCast(std.math.clamp(c, 0, std.math.maxInt(u16))) else null,
        .kills = @intCast(@min(l.lane_kills, 255)),
        .deaths = @intCast(@min(l.lane_deaths, 255)),
        .level6 = l.level6,
        .first_item = l.first_item,
        .fall = stretch(l.fall),
        .rise = stretch(l.rise),
    };
    const c = l.curve orelse return out;
    var m: usize = 0;
    while (m < c.n.len and c.n[m] >= min_minute_games) m += 1;
    if (m == 0) return out;
    out.typical = .{
        .games = c.games,
        .bracket = c.bracket,
        .gold = c.gold[0..@min(m, c.gold.len)],
        .xp = c.xp[0..@min(m, c.xp.len)],
        .cs = c.cs[0..@min(m, c.cs.len)],
        .level6 = c.level6[0],
        .first_item = c.first_item[0],
    };
    return out;
}

fn secs(s: u32) u16 {
    return @intCast(@min(s, std.math.maxInt(u16)));
}

/// `games` newest first, as the report has them; `champ` names a champion id and its
/// portrait. No Site: the API makes the same list for a lookup
pub fn list(arena: Allocator, who: Who, games: []const game.Game, nm: Names, ctx: anytype, champ: fn (@TypeOf(ctx), u32) anyerror!ui.champ.Champ) !yl.List {
    var used: Used(@TypeOf(ctx), champ) = .{ .ctx = ctx };
    var arts: Arts = .{ .names = nm };
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
        if (pageSlot(g)) |you| {
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
pub fn Used(comptime Ctx: type, comptime champ: fn (Ctx, u32) anyerror!ui.champ.Champ) type {
    return struct {
        ctx: Ctx,
        list: std.ArrayList(ui.champ.Champ) = .empty,
        ids: std.ArrayList(u32) = .empty,

        pub fn at(u: *@This(), a: Allocator, id: u32) !u16 {
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

test "a game with its detail maps every kill, objective and seat" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const raw = try @import("store").raw.decompress(arena, @embedFile("../riot/testdata/timeline.json.gz"));
    const t = try @import("../riot/root.zig").timeline.fromJson(arena, raw);
    const players = try arena.alloc(game.Summary.Player, 10);
    const positions = [_][]const u8{ "TOP", "JUNGLE", "MIDDLE", "BOTTOM", "UTILITY" };
    for (players, 0..) |*p, i| {
        p.* = .{ .hash = "", .team = if (i < 5) 100 else 200, .position = positions[i % 5], .champion = @intCast(i + 1), .win = i < 5, .kills = 0, .deaths = 0, .assists = 0 };
    }
    const s: game.Summary = .{ .patch = "16.20", .queue = 420, .start_ms = 1791720000000, .duration_s = 1800, .remake = false, .players = players };
    const g = try game.analyse(arena, .{ .summary = s, .slot = 6, .timeline = t, .detail = true }, .{}, .{});
    const d = try data(arena, .{}, &.{ g, try game.analyse(arena, .{ .summary = s, .slot = 0, .timeline = null }, .{}, .{}) }, {}, testChamp);
    // The game without a timeline has no page
    try testing.expectEqual(@as(usize, 1), d.games.len);
    const p = d.games[0];
    try testing.expectEqual(@as(u8, 6), p.you);
    try testing.expectEqual(ui.role.Role.jungle, p.me().role.?);
    try testing.expectEqual(@as(?u8, 1), p.opponent());
    try testing.expect(!p.seats[0].us and p.seats[9].us);
    try testing.expectEqual(g.detail.?.kills.len, p.kills.len);
    try testing.expectEqual(g.detail.?.objectives.len, p.objs.len);
    try testing.expectEqual(p.wc.len, p.gold.len);
    try testing.expectEqual(g.detail.?.skills.len, p.skills.len);
    try testing.expectEqual(g.detail.?.buys.len, p.buys.len);
    try testing.expect(p.lane != null);
    // No loadout in this summary: empty slots, no vision
    try testing.expectEqual(gd.no_art, p.me().items[0]);
    try testing.expectEqual(@as(?u16, null), p.me().vision);
    try testing.expectEqual(@as(usize, 10), d.champs.len);
    try testing.expectEqualStrings("Ranked solo", p.queue);
    const turn, _ = gd.turns(p.wc);
    try testing.expectEqual(g.turning.?.minute, turn.?.minute);
}

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
