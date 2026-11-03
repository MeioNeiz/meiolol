//! The lobby's form panel (ui/lobby.zig) from the poller's lcu.me.Form: record, average
//! KDA, the run of results, the champions going well lately and the mastery top

const std = @import("std");
const ui = @import("ui");
const desktop = @import("desktop");
const me = desktop.lcu.me;
const screens = @import("screens.zig");
const Allocator = std.mem.Allocator;

/// Lines in "Going well lately"
const max_best = 3;
/// A run this long gets a line
const run_from = 3;

pub fn view(a: Allocator, c: screens.Ctx, f: *const me.Form) !ui.lobby.Lobby {
    const recent = f.recent();
    var ids: std.ArrayList(u32) = .empty;
    var champs: std.ArrayList(ui.champ.Champ) = .empty;
    const games = try a.alloc(ui.lobby.Game, recent.len);
    var wins: u16 = 0;
    var sum: [3]u32 = @splat(0);
    for (games, recent) |*g, x| {
        const i = std.mem.indexOfScalar(u32, ids.items, x.champion) orelse blk: {
            try ids.append(a, x.champion);
            try champs.append(a, try champOf(a, c, x.champion));
            break :blk ids.items.len - 1;
        };
        g.* = .{ .champ = @intCast(i), .win = x.win };
        wins += @intFromBool(x.win);
        sum[0] += x.kills;
        sum[1] += x.deaths;
        sum[2] += x.assists;
    }
    var top: std.ArrayList(ui.lobby.Top) = .empty;
    for (f.mastery()) |m| try top.append(a, .{ .champ = try champOf(a, c, m.champion), .points = m.points });
    return .{
        .champs = champs.items,
        .games = games,
        .wins = wins,
        .kda = perGame(sum, recent.len),
        .run = try run(a, recent),
        .best = try best(a, c, recent),
        .top = top.items,
    };
}

fn champOf(a: Allocator, c: screens.Ctx, id: u32) !ui.champ.Champ {
    return (try c.champ(a, id)) orelse .{ .name = "", .src = "" };
}

fn perGame(sum: [3]u32, n: usize) ui.kda.Kda {
    const d: f32 = @floatFromInt(@max(n, 1));
    const r = struct {
        fn f(x: u32, by: f32) u16 {
            return @intFromFloat(@round(@as(f32, @floatFromInt(x)) / by));
        }
    }.f;
    return .{ .k = r(sum[0], d), .d = r(sum[1], d), .a = r(sum[2], d) };
}

/// The newest games' streak, if long enough to mention
fn run(a: Allocator, recent: []const me.Game) ![]const u8 {
    if (recent.len == 0) return "";
    var n: usize = 0;
    while (n < recent.len and recent[n].win == recent[0].win) n += 1;
    if (n < run_from) return "";
    return if (recent[0].win)
        a.print("On a roll: {d} wins in a row", .{n})
    else
        a.print("{d} losses in a row: a break, or a comfort pick?", .{n});
}

/// Champions with two or more games and at least half won, most wins first
fn best(a: Allocator, c: screens.Ctx, recent: []const me.Game) ![]const ui.lobby.Best {
    const Tally = struct { id: u32, games: u16 = 0, wins: u16 = 0, sum: [3]u32 = @splat(0) };
    var tallies: std.ArrayList(Tally) = .empty;
    for (recent) |g| {
        const t = for (tallies.items) |*t| {
            if (t.id == g.champion) break t;
        } else blk: {
            try tallies.append(a, .{ .id = g.champion });
            break :blk &tallies.items[tallies.items.len - 1];
        };
        t.games += 1;
        t.wins += @intFromBool(g.win);
        t.sum[0] += g.kills;
        t.sum[1] += g.deaths;
        t.sum[2] += g.assists;
    }
    var kept: std.ArrayList(Tally) = .empty;
    for (tallies.items) |t| if (t.games >= 2 and 2 * t.wins >= t.games) try kept.append(a, t);
    // Stable: ties keep the most recently played first
    std.mem.sort(Tally, kept.items, {}, struct {
        fn more(_: void, x: Tally, y: Tally) bool {
            return x.wins > y.wins or (x.wins == y.wins and x.games < y.games);
        }
    }.more);
    const out = try a.alloc(ui.lobby.Best, @min(kept.items.len, max_best));
    for (out, kept.items[0..out.len]) |*o, t| o.* = .{
        .champ = try champOf(a, c, t.id),
        .games = t.games,
        .wins = t.wins,
        .kda = perGame(t.sum, t.games),
    };
    return out;
}

const testing = std.testing;

test "record, run and best from the newest games" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var fx = try screens.fixture();
    defer fx.deinit();
    const c: screens.Ctx = .{ .stats = &fx.stats, .icons = null, .private = false };
    const g = struct {
        fn f(champion: u16, win: bool, k: u8) me.Game {
            return .{ .champion = champion, .win = win, .kills = k, .deaths = 2, .assists = 4, .minutes = 30 };
        }
    }.f;
    const ahri = 103;
    const syndra = 134;
    const galio = 3;
    const games = [_]me.Game{ g(ahri, true, 9), g(syndra, true, 3), g(ahri, true, 6), g(galio, false, 1), g(syndra, false, 2), g(galio, false, 4), g(ahri, false, 3) };
    const f = me.formOf(&games, &.{.{ .champion = ahri, .points = 90_000 }});
    const l = try view(a, c, &f);
    try testing.expectEqual(7, l.games.len);
    try testing.expectEqual(3, l.champs.len);
    try testing.expectEqual(3, l.wins);
    try testing.expectEqual(ui.kda.Kda{ .k = 4, .d = 2, .a = 4 }, l.kda);
    try testing.expectEqualStrings("On a roll: 3 wins in a row", l.run);
    // Ahri 2 of 3, Syndra 1 of 2; Galio 0 of 2 left out
    try testing.expectEqual(2, l.best.len);
    try testing.expectEqual(2, l.best[0].wins);
    try testing.expectEqual(1, l.best[1].wins);
    try testing.expectEqual(1, l.top.len);

    const losing = [_]me.Game{ g(galio, false, 1), g(galio, false, 1), g(galio, false, 1), g(ahri, true, 5) };
    const f2 = me.formOf(&losing, &.{});
    try testing.expectEqualStrings("3 losses in a row: a break, or a comfort pick?", (try view(a, c, &f2)).run);
    try testing.expectEqualStrings("", try run(a, losing[2..]));
}
