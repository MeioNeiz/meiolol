//! `meiolol your-example`: one real player's recent games from the crawler's tables, in
//! the shape GET /api/games answers, so your.html can show Your games without a Riot ID
//! (Riot's reviewers don't log in). Anonymised: no name, PUUID or match id, and game
//! starts cut to the day; champions, results, K/D/A and the lane stay, as on the page.

const std = @import("std");
const store = @import("store");
const api = @import("root.zig");
const game = @import("game.zig");
const fetch = @import("fetch.zig");

const Allocator = std.mem.Allocator;
const ranked_solo = 420;

pub const Options = struct {
    /// Matches started at or after this count towards picking the player
    since_ms: i64,
    platform: []const u8 = "EUW1",
    /// Games shown, newest first
    games: u32 = 10,
    /// Lane games with timelines a player needs since `since_ms` to be picked
    min_games: u32 = 8,
};

/// Null when nobody has `min_games` lane games with timelines. Players are picked by
/// lane games, most first, preferring Gold to Emerald at game time (the ranks most
/// visitors play at); `forgotten` players never
pub fn build(arena: Allocator, db: store.Db, set: game.CurveSet, o: Options) !?api.GamesOut {
    const puuid = try pick(arena, db, o) orelse return null;
    var q = try db.prepare(
        \\SELECT m.match_id, m.patch, m.game_start, m.duration_s, m.remake, t.data, pa.slot,
        \\  pa.tier, pa.division
        \\FROM participants pa JOIN matches m USING (match_id)
        \\  JOIN timeline.timelines t USING (match_id)
        \\WHERE pa.puuid = ? AND m.queue_id = ? AND m.platform = ?
        \\ORDER BY m.game_start DESC LIMIT ?
    );
    defer q.deinit();
    try q.bind(.{ puuid, ranked_solo, o.platform, o.games });
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
        });
    }
    if (inputs.items.len == 0) return null;
    return .{
        .state = "ready",
        .player = .{
            .name = "Example player",
            .tag = "",
            .platform = o.platform,
            .tier = rank.tier,
            .division = rank.division,
            .lp = null,
            .refreshed = 0,
            .@"error" = null,
        },
        .report = try game.report(arena, inputs.items, rank, set),
    };
}

fn pick(arena: Allocator, db: store.Db, o: Options) !?[]const u8 {
    var q = try db.prepare(
        \\SELECT pa.puuid, count(*) AS n,
        \\  sum(pa.tier IN ('GOLD', 'PLATINUM', 'EMERALD')) * 2 >= count(*) AS mid
        \\FROM matches m JOIN timeline.timelines t USING (match_id)
        \\  JOIN participants pa USING (match_id)
        \\WHERE m.game_start >= ? AND m.platform = ? AND m.queue_id = ? AND m.remake = 0
        \\  AND pa.puuid IS NOT NULL AND pa.puuid != ''
        \\  AND pa.position IN ('TOP', 'MIDDLE', 'BOTTOM', 'UTILITY')
        \\  AND pa.puuid NOT IN (SELECT puuid FROM forgotten)
        \\GROUP BY pa.puuid HAVING n >= ?
        \\ORDER BY mid DESC, n DESC, pa.puuid LIMIT 1
    );
    defer q.deinit();
    try q.bind(.{ o.since_ms, o.platform, ranked_solo, o.min_games });
    if (!try q.step()) return null;
    return try arena.dupe(u8, q.bytes(0));
}

test "no player with enough games: null" {
    const db = try store.schema.memory();
    defer db.close();
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    try std.testing.expectEqual(null, try build(arena_state.allocator(), db, .{}, .{ .since_ms = 0 }));
}
