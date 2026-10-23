//! `meiolol your-example`: real players' recent games from the crawler's tables, one per
//! role, each in the shape GET /api/games answers, so your.html can show Your games
//! without a Riot ID (Riot's reviewers don't log in). Anonymised: no name, PUUID or match
//! id, and game starts cut to the day; champions, results, K/D/A and the lane stay, as on
//! the page.

const std = @import("std");
const store = @import("store");
const Role = @import("core").Role;
const api = @import("root.zig");
const game = @import("game.zig");
const fetch = @import("fetch.zig");

const Allocator = std.mem.Allocator;
const ranked_solo = 420;
/// Riot teamPosition by Role
const platform = "EUW1";
/// Games shown, newest first
const games_shown = 10;
/// Players tried per role for one with a game whose review has a turning minute and a
/// lane curve (what the home page's featured review shows)
const tries = 10;

pub const Options = struct {
    /// Matches started at or after this count towards picking the player
    since_ms: i64,
    /// Games of the role with timelines a player needs since `since_ms` to be picked
    min_games: u32 = 8,
};

/// your-example.json: an example per role, keyed by Role.label(); missing where no
/// player qualified
pub const Examples = struct {
    /// Role a bare #example opens: mid, else the first here
    default: []const u8,
    top: ?api.GamesOut = null,
    jungle: ?api.GamesOut = null,
    mid: ?api.GamesOut = null,
    bot: ?api.GamesOut = null,
    support: ?api.GamesOut = null,
};

/// Each role's example is a different player. Null when no role has one
pub fn buildAll(arena: Allocator, db: store.Db, set: game.CurveSet, o: Options) !?Examples {
    var out: Examples = .{ .default = "" };
    var used: std.ArrayList([]const u8) = .empty;
    const candidates = try pick(arena, db, o);
    inline for (Role.all) |r| {
        if (try build(arena, db, set, r, candidates[@backingInt(r)], &used)) |ex| {
            @field(out, r.label()) = ex;
            if (out.default.len == 0 or r == .middle) out.default = r.label();
        }
    }
    return if (out.default.len == 0) null else out;
}

pub fn json(arena: Allocator, ex: Examples) ![]u8 {
    return std.json.Stringify.valueAlloc(arena, ex, .{ .emit_null_optional_fields = false });
}

/// The first of `candidates` (from pick) outside `used` with a reviewed game: their
/// games of `role`. The pick joins `used`
fn build(arena: Allocator, db: store.Db, set: game.CurveSet, role: Role, candidates: []const []const u8, used: *std.ArrayList([]const u8)) !?api.GamesOut {
    for (candidates) |puuid| {
        if (contains(used.items, puuid)) continue;
        const out = try player(arena, db, set, role, puuid) orelse continue;
        if (!reviewed(out.report.?)) continue;
        try used.append(arena, puuid);
        return out;
    }
    return null;
}

fn contains(list: []const []const u8, s: []const u8) bool {
    for (list) |x| if (std.mem.eql(u8, x, s)) return true;
    return false;
}

fn reviewed(r: game.Report) bool {
    for (r.games) |g| {
        const l = g.lane orelse continue;
        if (g.turning != null and l.curve != null) return true;
    }
    return false;
}

fn player(arena: Allocator, db: store.Db, set: game.CurveSet, role: Role, puuid: []const u8) !?api.GamesOut {
    var q = try db.prepare(
        \\SELECT m.match_id, m.patch, m.game_start, m.duration_s, m.remake, t.data, pa.slot,
        \\  pa.tier, pa.division
        \\FROM participants pa JOIN matches m USING (match_id)
        \\  JOIN timeline.timelines t USING (match_id)
        \\WHERE pa.puuid = ? AND pa.position = ? AND m.queue_id = ? AND m.platform = ?
        \\ORDER BY m.game_start DESC LIMIT ?
    );
    defer q.deinit();
    try q.bind(.{ puuid, Role.positions[@backingInt(role)], ranked_solo, platform, games_shown });
    var players = try db.prepare(
        \\SELECT slot, team_id, position, champion_id, win, kills, deaths, assists
        \\FROM participants WHERE match_id = ? ORDER BY slot
    );
    defer players.deinit();

    var inputs: std.ArrayList(game.Input) = .empty;
    var rank: game.Rank = .{};
    while (try q.step()) {
        const g = q.row(struct {
            match_id: []const u8,
            patch: []const u8,
            game_start: i64,
            duration_s: i64,
            remake: bool,
            timeline: []const u8,
            slot: u8,
            tier: ?[]const u8,
            division: ?[]const u8,
        });
        if (inputs.items.len == 0) rank = .{
            .tier = if (g.tier) |v| try arena.dupe(u8, v) else null,
            .division = if (g.division) |v| try arena.dupe(u8, v) else null,
        };
        try players.bind(.{g.match_id});
        var list: std.ArrayList(game.Summary.Player) = .empty;
        while (try players.step()) {
            const p = players.row(struct {
                slot: i64,
                team: i64,
                position: []const u8,
                champion: u32,
                win: bool,
                kills: i64,
                deaths: i64,
                assists: i64,
            });
            try list.append(arena, .{
                .hash = "",
                .team = p.team,
                .position = try arena.dupe(u8, p.position),
                .champion = p.champion,
                .win = p.win,
                .kills = p.kills,
                .deaths = p.deaths,
                .assists = p.assists,
            });
        }
        if (g.slot >= list.items.len) continue;
        const t = fetch.readTimeline(arena, g.timeline) catch null;
        try inputs.append(arena, .{
            .summary = .{
                .patch = try arena.dupe(u8, g.patch),
                .queue = ranked_solo,
                .start_ms = @divFloor(g.game_start, std.time.ms_per_day) * std.time.ms_per_day,
                .duration_s = g.duration_s,
                .remake = g.remake,
                .players = list.items,
            },
            .slot = g.slot,
            .timeline = t,
            .platform = platform,
        });
    }
    if (inputs.items.len == 0) return null;
    return .{
        .state = "ready",
        .player = .{
            .name = "Example player",
            .tag = "",
            .platform = platform,
            .tier = rank.tier,
            .division = rank.division,
            .lp = null,
            .refreshed = 0,
            .@"error" = null,
        },
        .report = try game.report(arena, inputs.items, rank, set),
    };
}

/// Up to `tries` players per role with `min_games` games of it with timelines since
/// `since_ms`, most first, preferring Gold to Emerald at game time (the ranks most
/// visitors play at); `forgotten` players never. One query for all roles, as it scans
/// the whole week of games
fn pick(arena: Allocator, db: store.Db, o: Options) ![Role.count][]const []const u8 {
    var q = try db.prepare(
        \\SELECT pa.position, pa.puuid, count(*) AS n,
        \\  sum(pa.tier IN ('GOLD', 'PLATINUM', 'EMERALD')) * 2 >= count(*) AS mid
        \\FROM matches m JOIN timeline.timelines t USING (match_id)
        \\  JOIN participants pa USING (match_id)
        \\WHERE m.game_start >= ? AND m.platform = ? AND m.queue_id = ? AND m.remake = 0
        \\  AND pa.puuid IS NOT NULL AND pa.puuid != ''
        \\  AND pa.puuid NOT IN (SELECT puuid FROM forgotten)
        \\GROUP BY pa.position, pa.puuid HAVING n >= ?
        \\ORDER BY mid DESC, n DESC, pa.puuid
    );
    defer q.deinit();
    try q.bind(.{ o.since_ms, platform, ranked_solo, o.min_games });
    var out: [Role.count]std.ArrayList([]const u8) = @splat(.empty);
    while (try q.step()) {
        const r = Role.fromLcu(q.bytes(0)) orelse continue;
        const list = &out[@backingInt(r)];
        if (list.items.len < tries) try list.append(arena, try arena.dupe(u8, q.bytes(1)));
    }
    var lists: [Role.count][]const []const u8 = undefined;
    for (&lists, out) |*l, list| l.* = list.items;
    return lists;
}

test "no player with enough games: null" {
    const db = try store.schema.memory();
    defer db.close();
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    try std.testing.expectEqual(null, try buildAll(arena_state.allocator(), db, .{}, .{ .since_ms = 0 }));
}

test "candidates per role: games of that role, Gold to Emerald first, never forgotten" {
    const db = try store.schema.memory();
    defer db.close();
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const Row = struct { puuid: []const u8, position: []const u8, tier: []const u8, games: u8 };
    const rows = [_]Row{
        .{ .puuid = "top-gold", .position = "TOP", .tier = "GOLD", .games = 3 },
        .{ .puuid = "jg-iron", .position = "JUNGLE", .tier = "IRON", .games = 3 },
        .{ .puuid = "jg-gold", .position = "JUNGLE", .tier = "GOLD", .games = 2 },
        .{ .puuid = "jg-forgotten", .position = "JUNGLE", .tier = "GOLD", .games = 3 },
        .{ .puuid = "jg-one", .position = "JUNGLE", .tier = "GOLD", .games = 1 },
        // Off-role games don't count towards mid
        .{ .puuid = "top-gold", .position = "MIDDLE", .tier = "GOLD", .games = 1 },
    };
    for (0..3) |i| {
        const id = try arena.print("EUW1_{d}", .{i});
        try db.run("INSERT INTO matches VALUES (?, 'test', 'EUW1', 420, '16.20', '16.20.1', ?, 1800, 100, 0)", .{ id, @as(i64, @intCast(i)) });
        try db.run("INSERT INTO timeline.timelines VALUES (?, 0, 0, x'')", .{id});
    }
    for (rows, 0..) |r, slot| for (0..r.games) |i| {
        const id = try arena.print("EUW1_{d}", .{if (std.mem.eql(u8, r.position, "MIDDLE")) 2 - i else i});
        try db.run(
            \\INSERT INTO participants (match_id, slot, team_id, puuid, champion_id, position, win, tier)
            \\VALUES (?, ?, 100, ?, 1, ?, 1, ?)
        , .{ id, @as(i64, @intCast(slot)), r.puuid, r.position, r.tier });
    };
    try db.run("INSERT INTO forgotten VALUES ('jg-forgotten', 0)", .{});
    const all = try pick(arena, db, .{ .since_ms = 0, .min_games = 2 });
    const jungle = all[@backingInt(Role.jungle)];
    try std.testing.expectEqual(2, jungle.len);
    try std.testing.expectEqualStrings("jg-gold", jungle[0]);
    try std.testing.expectEqualStrings("jg-iron", jungle[1]);
    const top = all[@backingInt(Role.top)];
    try std.testing.expectEqual(1, top.len);
    try std.testing.expectEqualStrings("top-gold", top[0]);
    try std.testing.expectEqual(0, all[@backingInt(Role.middle)].len);
}
