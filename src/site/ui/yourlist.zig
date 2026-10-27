//! One player's games as the Your games list reads them (docs/plan/ui/your-games.md
//! "Games"): a row's worth per game, and what the list works out of them client side:
//! the filter, day groups with W-L and time played, per champion and per role totals,
//! the streak. Remakes show as rows but count in no record
const std = @import("std");
const champ = @import("champ.zig");
const role = @import("role.zig");
const art = @import("art.zig");
const gd = @import("gamedata.zig");
const fmt = @import("fmt.zig");

pub const Queue = enum { solo, flex, draft, swift, other };

pub fn queueOf(id: i64) Queue {
    return switch (id) {
        420 => .solo,
        440 => .flex,
        400 => .draft,
        480 => .swift,
        else => .other,
    };
}

pub const Player = struct {
    name: []const u8,
    /// "" for the example
    tag: []const u8 = "",
    platform: []const u8 = "",
    /// "EMERALD"; null unranked
    tier: ?[]const u8 = null,
    division: ?[]const u8 = null,
    lp: ?u16 = null,
    /// Unix seconds of the last check; 0 never
    refreshed: i64 = 0,
};

/// Your gold lead over your lane opponent at 14 min, against the matchup's typical
pub const Lane14 = struct {
    you: i32,
    /// [p25, p50, p75]; null when the curve is thin there
    typ: ?[3]i16 = null,
};

pub const Game = struct {
    start_ms: i64,
    /// Seconds
    dur: u16,
    patch: []const u8,
    queue: Queue,
    role: ?role.Role = null,
    /// `List.champs` indices
    champ: u16,
    opp: ?u16 = null,
    win: bool,
    remake: bool = false,
    k: u16,
    d: u16,
    a: u16,
    /// Null without the game's detail (older history)
    level: ?u8 = null,
    cs: ?u16 = null,
    /// `List.arts` indices, 6 the trinket; all `gd.no_art` before loadouts
    items: [7]u16 = @splat(gd.no_art),
    /// Your team's win chance in % at each minute from 0; empty without a timeline
    /// (the turn: gd.turns)
    wc: []const u8 = &.{},
    lane14: ?Lane14 = null,
    /// Index in game.html's games; null when it has no page
    page: ?u16 = null,

    pub fn ends(g: Game) i64 {
        return g.start_ms + @as(i64, g.dur) * std.time.ms_per_s;
    }
};

pub const List = struct {
    player: Player,
    champs: []const champ.Champ,
    arts: []const art.Art = &.{},
    /// Newest first
    games: []const Game,

    pub fn artAt(l: *const List, i: u16) ?art.Art {
        return if (i < l.arts.len) l.arts[i] else null;
    }
};

/// /api/list's answer (api/root.zig): a lookup's state, and the list once ready. The
/// page polls while queued or fetching, as your.js does /api/games
pub const Lookup = struct {
    state: State,
    /// Jobs ahead in the queue
    ahead: ?u16 = null,
    /// Games left to fetch, and in this refresh
    pending: ?u16 = null,
    total: ?u16 = null,
    /// Unix seconds from which &refresh=1 checks for new games
    check_at: ?i64 = null,
    /// The last refresh failed (an error name): the list is from before it
    failed: ?[]const u8 = null,
    list: ?List = null,

    /// busy: the queue is full, try again in a few minutes; none: &cached=1 and the
    /// cache doesn't know the player
    pub const State = enum { queued, fetching, ready, not_found, opted_out, busy, none };
};

/// The filter row and the summary's presses; null is All
pub const Filter = struct {
    queue: ?Queue = null,
    role: ?role.Role = null,
    champ: ?u16 = null,

    pub fn keeps(f: Filter, g: Game) bool {
        if (f.queue) |q| if (g.queue != q) return false;
        if (f.role) |r| if (g.role != r) return false;
        if (f.champ) |c| if (g.champ != c) return false;
        return true;
    }
};

pub const Totals = struct {
    games: u16 = 0,
    wins: u16 = 0,
    k: u32 = 0,
    d: u32 = 0,
    a: u32 = 0,

    pub fn add(t: *Totals, g: Game) void {
        if (g.remake) return;
        t.games += 1;
        t.wins += @intFromBool(g.win);
        t.k += g.k;
        t.d += g.d;
        t.a += g.a;
    }

    pub fn losses(t: Totals) u16 {
        return t.games - t.wins;
    }

    /// (K + A) / D, deathless games counting D as 1
    pub fn kda(t: Totals) f32 {
        return @as(f32, @floatFromInt(t.k + t.a)) / @as(f32, @floatFromInt(@max(t.d, 1)));
    }
};

pub fn totals(games: []const Game, f: Filter) Totals {
    var t: Totals = .{};
    for (games) |g| if (f.keeps(g)) t.add(g);
    return t;
}

/// Per role, `role.Role` order; the filter's role is ignored so every bar shows
pub fn byRole(games: []const Game, f: Filter) [roles]Totals {
    var out: [roles]Totals = @splat(.{});
    var any_role = f;
    any_role.role = null;
    for (games) |g| if (any_role.keeps(g)) if (g.role) |r| out[@backingInt(r)].add(g);
    return out;
}

const roles = @typeInfo(role.Role).@"enum".field_names.len;

pub const ChampTotals = struct { champ: u16, t: Totals };

/// Champions played, most games first, then most wins; the filter's champion is ignored
/// so the summary keeps its rows while one is chosen
pub fn byChamp(a: std.mem.Allocator, games: []const Game, f: Filter) ![]ChampTotals {
    var out: std.ArrayList(ChampTotals) = .empty;
    var any_champ = f;
    any_champ.champ = null;
    for (games) |g| {
        if (!any_champ.keeps(g) or g.remake) continue;
        const c = for (out.items) |*c| {
            if (c.champ == g.champ) break c;
        } else blk: {
            try out.append(a, .{ .champ = g.champ, .t = .{} });
            break :blk &out.items[out.items.len - 1];
        };
        c.t.add(g);
    }
    std.mem.sort(ChampTotals, out.items, {}, struct {
        fn more(_: void, x: ChampTotals, y: ChampTotals) bool {
            if (x.t.games != y.t.games) return x.t.games > y.t.games;
            return x.t.wins > y.t.wins;
        }
    }.more);
    return out.items;
}

/// The newest results' run: wins or losses in a row, remakes skipped
pub const Streak = struct { win: bool, n: u16 };

pub fn streak(games: []const Game) ?Streak {
    var s: ?Streak = null;
    for (games) |g| {
        if (g.remake) continue;
        if (s) |*x| {
            if (x.win != g.win) break;
            x.n += 1;
        } else s = .{ .win = g.win, .n = 1 };
    }
    return s;
}

/// Days since 1970-01-01 in the viewer's time zone; `tz_min` east of UTC (JS's
/// getTimezoneOffset negated)
pub fn dayOf(ms: i64, tz_min: i32) i32 {
    return @intCast(@divFloor(ms + @as(i64, tz_min) * std.time.ms_per_min, std.time.ms_per_day));
}

/// One day's games the filter keeps, newest first
pub const Day = struct {
    day: i32,
    /// `List.games` indices
    games: []const u16,
    t: Totals,
    /// Seconds, remakes too
    played: u32,
};

/// `tz`: each game's minutes east of UTC; empty is UTC
pub fn days(a: std.mem.Allocator, games: []const Game, f: Filter, tz: []const i32) ![]Day {
    var out: std.ArrayList(Day) = .empty;
    var idx: std.ArrayList(u16) = .empty;
    var starts: std.ArrayList(usize) = .empty;
    for (games, 0..) |g, i| {
        if (!f.keeps(g)) continue;
        const d = dayOf(g.start_ms, if (i < tz.len) tz[i] else 0);
        if (out.items.len == 0 or out.items[out.items.len - 1].day != d) {
            try out.append(a, .{ .day = d, .games = &.{}, .t = .{}, .played = 0 });
            try starts.append(a, idx.items.len);
        }
        const day = &out.items[out.items.len - 1];
        day.t.add(g);
        day.played += g.dur;
        try idx.append(a, @intCast(i));
    }
    for (out.items, starts.items, 0..) |*day, s, i| {
        const end = if (i + 1 < starts.items.len) starts.items[i + 1] else idx.items.len;
        day.games = idx.items[s..end];
    }
    return out.items;
}

const testing = std.testing;

fn demoGame(start_ms: i64, c: u16, r: role.Role, win: bool) Game {
    return .{ .start_ms = start_ms, .dur = 1800, .patch = "16.21", .queue = .solo, .role = r, .champ = c, .win = win, .k = 5, .d = 2, .a = 7 };
}

const day_ms = std.time.ms_per_day;
// 22 Oct 2026 00:00 UTC, a Thursday
const t0: i64 = 20748 * day_ms;

test "days group by the viewer's date, newest first, remakes counted only in time" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var remake = demoGame(t0 + 22 * std.time.ms_per_hour, 1, .mid, false);
    remake.remake = true;
    remake.dur = 200;
    const games = [_]Game{
        demoGame(t0 + 23 * std.time.ms_per_hour + 30 * std.time.ms_per_min, 0, .mid, true),
        remake,
        demoGame(t0 + 10 * std.time.ms_per_hour, 0, .mid, false),
        demoGame(t0 - 2 * std.time.ms_per_hour, 1, .top, true),
    };
    const ds = try days(arena.allocator(), &games, .{}, &.{});
    try testing.expectEqual(2, ds.len);
    try testing.expectEqual(dayOf(t0, 0), ds[0].day);
    try testing.expectEqualSlices(u16, &.{ 0, 1, 2 }, ds[0].games);
    try testing.expectEqual(2, ds[0].t.games);
    try testing.expectEqual(1, ds[0].t.wins);
    try testing.expectEqual(3800, ds[0].played);
    try testing.expectEqualSlices(u16, &.{3}, ds[1].games);
    // An hour east of UTC, the newest game falls on the next day; each game its own offset
    const east = try days(arena.allocator(), &games, .{}, &.{ 60, 60, 60, 60 });
    try testing.expectEqual(3, east.len);
    try testing.expectEqualSlices(u16, &.{0}, east[0].games);
    try testing.expectEqualSlices(u16, &.{ 1, 2 }, east[1].games);
    // The oldest game before a DST change, two hours east then: on the 22nd too
    try testing.expectEqual(1, (try days(arena.allocator(), &games, .{}, &.{ 0, 0, 0, 120 })).len);
    const c = fmt.civil(dayOf(t0, 0));
    try testing.expectEqual(fmt.Civil{ .weekday = 3, .day = 22, .month = 10, .year = 2026 }, c);
}

test "the filter cuts days and totals; the summary rows ignore their own field" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var flex = demoGame(t0 + 3 * day_ms, 2, .jungle, true);
    flex.queue = .flex;
    const games = [_]Game{ flex, demoGame(t0 + 2 * day_ms, 1, .top, false), demoGame(t0 + day_ms, 0, .mid, true), demoGame(t0, 0, .mid, true) };
    const mid: Filter = .{ .role = .mid };
    try testing.expectEqual(2, (try days(arena.allocator(), &games, mid, &.{})).len);
    try testing.expectEqual(Totals{ .games = 2, .wins = 2, .k = 10, .d = 4, .a = 14 }, totals(&games, mid));
    const rs = byRole(&games, mid);
    try testing.expectEqual(1, rs[@backingInt(role.Role.top)].games);
    try testing.expectEqual(2, rs[@backingInt(role.Role.mid)].games);
    const cs = try byChamp(arena.allocator(), &games, .{ .champ = 1 });
    try testing.expectEqual(3, cs.len);
    try testing.expectEqual(0, cs[0].champ);
    try testing.expectEqual(2, cs[0].t.wins);
    try testing.expectEqual(0, (try days(arena.allocator(), &games, .{ .queue = .flex, .role = .top }, &.{})).len);
    try testing.expectApproxEqAbs(6.0, totals(&games, .{}).kda(), 0.001);
}

test "streak skips remakes" {
    var remake = demoGame(t0 + 3 * day_ms, 0, .mid, false);
    remake.remake = true;
    const games = [_]Game{ remake, demoGame(t0 + 2 * day_ms, 0, .mid, true), demoGame(t0 + day_ms, 0, .mid, true), demoGame(t0, 0, .mid, false) };
    try testing.expectEqual(Streak{ .win = true, .n = 2 }, streak(&games).?);
    try testing.expectEqual(null, streak(games[0..1]));
}

test "list round trip" {
    const games = [_]Game{demoGame(t0, 0, .mid, true)};
    const l: List = .{ .player = .{ .name = "Example player", .tier = "EMERALD" }, .champs = &.{champ.demo("Ahri", "Ahri")}, .games = &games };
    var bytes: std.ArrayList(u8) = .empty;
    defer bytes.deinit(testing.allocator);
    try @import("data.zig").encode(testing.allocator, List, l, &bytes);
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const back = try @import("data.zig").decode(arena.allocator(), List, bytes.items);
    try testing.expectEqualStrings("EMERALD", back.player.tier.?);
    try testing.expectEqual(games[0].start_ms, back.games[0].start_ms);
}
