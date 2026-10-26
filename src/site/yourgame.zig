//! The game page's data from `meiolol your-example`'s file: each role's player's games as
//! ui.gamedata.Data (api/game.zig's Game with its Detail), and the file again without
//! the detail for the pages that read it whole (home, your.html): twice the bytes
//! otherwise
const std = @import("std");
const ui = @import("ui");
const game = @import("../api/game.zig");
const Date = @import("../date.zig").Date;
const Champ = @import("root.zig").Champ;

const Allocator = std.mem.Allocator;
const gd = ui.gamedata;

pub const Example = struct {
    default: []const u8,
    top: ?Player = null,
    jungle: ?Player = null,
    mid: ?Player = null,
    bot: ?Player = null,
    support: ?Player = null,

    pub const Player = struct { report: struct { games: []const game.Game } };

    pub fn player(e: Example, role: []const u8) ?Player {
        inline for (.{ "top", "jungle", "mid", "bot", "support" }) |r| {
            if (std.mem.eql(u8, role, r)) return @field(e, r);
        }
        return null;
    }
};

pub fn parse(arena: Allocator, json: []const u8) !Example {
    return std.json.parseFromSliceLeaky(Example, arena, json, .{ .ignore_unknown_fields = true });
}

/// `json` with every game's `detail` left out
pub fn stripped(arena: Allocator, json: []const u8) ![]u8 {
    const v = try std.json.parseFromSliceLeaky(std.json.Value, arena, json, .{});
    if (v != .object) return error.BadExample;
    for (v.object.values()) |p| {
        if (p != .object) continue;
        const r = p.object.get("report") orelse continue;
        if (r != .object) continue;
        const games = r.object.get("games") orelse continue;
        if (games != .array) continue;
        for (games.array.items) |*g| if (g.* == .object) {
            _ = g.object.orderedRemove("detail");
        };
    }
    return std.json.Stringify.valueAlloc(arena, v, .{});
}

const queues = [_]struct { i64, []const u8 }{
    .{ 420, "Ranked solo" }, .{ 440, "Ranked flex" }, .{ 400, "Draft" }, .{ 480, "Swiftplay" },
};

const months = [_][]const u8{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };

/// Games with a timeline and its detail; `icon` makes a portrait URL
pub fn data(arena: Allocator, champs: []const Champ, games: []const game.Game, ctx: anytype, icon: fn (@TypeOf(ctx), Champ) anyerror![]const u8) !gd.Data {
    var used: std.ArrayList(ui.champ.Champ) = .empty;
    var ids: std.ArrayList(u32) = .empty;
    var out: std.ArrayList(gd.Game) = .empty;
    for (games) |g| {
        const d = g.detail orelse continue;
        if (g.players.len != d.seats.len or g.players.len > 10 or g.win_chance.len < 2) continue;
        const you = for (g.players, 0..) |p, i| {
            if (p.you) break i;
        } else continue;
        const team = g.players[you].team;

        const seats = try arena.alloc(gd.Seat, g.players.len);
        for (g.players, d.seats, seats) |p, st, *o| {
            const at = std.mem.findScalar(u32, ids.items, p.champion) orelse blk: {
                const ch = for (champs) |c| {
                    if (c.id == p.champion) break c;
                } else return error.UnknownChampion;
                try ids.append(arena, p.champion);
                try used.append(arena, .{ .name = ch.name, .src = try icon(ctx, ch) });
                break :blk ids.items.len - 1;
            };
            o.* = .{
                .champ = @intCast(at),
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
        }

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
        });
    }
    return .{ .champs = used.items, .games = out.items };
}

fn secs(s: u32) u16 {
    return @intCast(@min(s, std.math.maxInt(u16)));
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
    var champs: [10]Champ = undefined;
    for (players, &champs, 0..) |*p, *c, i| {
        p.* = .{ .hash = "", .team = if (i < 5) 100 else 200, .position = positions[i % 5], .champion = @intCast(i + 1), .win = i < 5, .kills = 0, .deaths = 0, .assists = 0 };
        c.* = .{ .c = i, .id = @intCast(i + 1), .key = "Ahri", .name = "Ahri", .slug = "ahri", .banned = 0, .games = 0 };
    }
    const s: game.Summary = .{ .patch = "16.20", .queue = 420, .start_ms = 1791720000000, .duration_s = 1800, .remake = false, .players = players };
    const g = try game.analyse(arena, .{ .summary = s, .slot = 6, .timeline = t, .detail = true }, .{}, .{});
    const icon = struct {
        fn f(_: void, c: Champ) anyerror![]const u8 {
            return c.key;
        }
    }.f;
    const d = try data(arena, &champs, &.{ g, try game.analyse(arena, .{ .summary = s, .slot = 0, .timeline = null }, .{}, .{}) }, {}, icon);
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
    try testing.expectEqual(@as(usize, 10), d.champs.len);
    try testing.expectEqualStrings("Ranked solo", p.queue);
    const turn, _ = gd.turns(p.wc);
    try testing.expectEqual(g.turning.?.minute, turn.?.minute);
}

test "stripped drops only the detail" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const json =
        \\{"default":"mid","mid":{"state":"ready","report":{"games":[{"win":true,"detail":{"kills":[]}}],"weeks":[]}}}
    ;
    try testing.expectEqualStrings(
        \\{"default":"mid","mid":{"state":"ready","report":{"games":[{"win":true}],"weeks":[]}}}
    , try stripped(arena, json));
}
