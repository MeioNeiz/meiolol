//! A player's experience on their champion, for eval: research says it outweighs
//! counters at low and mid elo (research/questions/player-tool-needs.md C3). In the app
//! only the user's own is known (docs/data.md, Policy); eval measures both that and the
//! upper bound with every player's.
//!
//! Two sources, both only for some players:
//! - history: games on the champion before this one in the player's crawled ranked
//!   history. No leakage, but games before the crawl window are
//!   missing, so early numbers hold some returning players
//! - mastery points, a snapshot taken after the match: it includes this game and later
//!   ones, and wins earn more, so it flatters the term somewhat. Read as an upper bound

const std = @import("std");
const store = @import("store");
const core = @import("core");
const stats = @import("stats.zig");
const ep = @import("riot/endpoints.zig");
const riot_mastery = @import("riot/mastery.zig");
const Role = core.Role;

/// FROM and WHERE for the participant rows of the scan pool's players (matches_checked_at
/// set), driven from players_region_check: ~15k players of 9M, where joining every
/// participant to players did 2.3M lookups. Every region listed so the index's first
/// column is an equality; a checked player always has one
const checked_players = "FROM players pl CROSS JOIN participants pa USING (puuid)" ++
    " CROSS JOIN matches m USING (match_id)" ++
    " WHERE pl.region IN (" ++ region_list ++ ") AND pl.matches_checked_at IS NOT NULL";

const region_list = blk: {
    var list: []const u8 = "";
    for (std.enums.values(ep.Region), 0..) |r, i| list = list ++ (if (i == 0) "'" else ", '") ++ @tagName(r) ++ "'";
    break :blk list;
};

/// First game number of each history bin: 1-5, 6-20, 21-50, 51+
const history_starts = [_]u32{ 1, 6, 21, 51 };

/// Experience bins (index into a Row's features), per source
pub const history_bins = history_starts.len;
/// Points: under 10k (the research's "low mastery"), 10-50k, 50-200k, 200k+
pub const mastery_edges = [_]u32{ 0, 10_000, 50_000, 200_000 };
pub const mastery_bins = mastery_edges.len;

pub const Player = struct {
    /// historyBin(game number), when the player's history was crawled
    history: ?u8 = null,
    mastery: ?u8 = null,
};

/// [side][role]
pub const Game = [2][Role.count]Player;

pub const Map = std.AutoHashMapUnmanaged(u64, Game);

pub fn historyBin(game: u32) u8 {
    var i: usize = history_bins - 1;
    while (game < history_starts[i]) i -= 1;
    return @intCast(i);
}

pub fn masteryBin(points: u32) u8 {
    var i: usize = mastery_bins - 1;
    while (points < mastery_edges[i]) i -= 1;
    return @intCast(i);
}

/// Every ranked solo game on `platforms` (all patches: experience builds across them)
/// with at least one player of known experience, keyed by stats.matchKey
pub fn load(gpa: std.mem.Allocator, db: store.Db, platforms: []const []const u8) !Map {
    var map: Map = .empty;
    errdefer map.deinit(gpa);
    const platform_json = try std.json.Stringify.valueAlloc(gpa, platforms, .{});
    defer gpa.free(platform_json);

    var q = try db.prepare("SELECT pa.puuid, pa.champion_id, pa.match_id, pa.team_id, pa.position " ++
        checked_players ++ " AND m.queue_id = ? AND m.remake = 0" ++
        " AND m.platform IN (SELECT value FROM json_each(?))" ++
        " ORDER BY pa.puuid, pa.champion_id, m.game_start");
    defer q.deinit();
    try q.bind(.{ stats.ranked_solo, platform_json });
    var player: std.ArrayList(u8) = .empty;
    defer player.deinit(gpa);
    var champion: i64 = -1;
    var game: u32 = 0;
    while (try q.step()) {
        const r = q.row(struct {
            puuid: []const u8,
            champion_id: i64,
            match_id: []const u8,
            team_id: i64,
            position: []const u8,
        });
        if (!std.mem.eql(u8, r.puuid, player.items)) {
            player.clearRetainingCapacity();
            try player.appendSlice(gpa, r.puuid);
            champion = -1;
        }
        if (r.champion_id != champion) {
            champion = r.champion_id;
            game = 0;
        }
        game += 1;
        const at = slot(r.team_id, r.position) orelse continue;
        const gop = try map.getOrPut(gpa, stats.matchKey(r.match_id));
        if (!gop.found_existing) gop.value_ptr.* = @splat(@splat(.{}));
        gop.value_ptr[at[0]][at[1]].history = historyBin(game);
    }

    var m = try db.prepare(
        \\SELECT pa.match_id, pa.team_id, pa.position, pa.champion_id, ma.data, ma.fetched_at
        \\FROM participants pa JOIN matches m USING (match_id) JOIN mastery ma USING (puuid)
        \\WHERE m.queue_id = ? AND m.remake = 0
        \\  AND m.platform IN (SELECT value FROM json_each(?))
    );
    defer m.deinit();
    try m.bind(.{ stats.ranked_solo, platform_json });
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    while (try m.step()) {
        _ = arena_state.reset(.retain_capacity);
        const r = m.row(struct {
            match_id: []const u8,
            team_id: i64,
            position: []const u8,
            champion_id: u32,
            data: []const u8,
            fetched_at: i64,
        });
        const at = slot(r.team_id, r.position) orelse continue;
        const entries = riot_mastery.decode(arena_state.allocator(), r.data, r.fetched_at) catch continue;
        // Absent from the response: never played it, 0 points
        var points: u32 = 0;
        for (entries) |e| if (e.champion == r.champion_id) {
            points = e.points;
        };
        const gop = try map.getOrPut(gpa, stats.matchKey(r.match_id));
        if (!gop.found_existing) gop.value_ptr.* = @splat(@splat(.{}));
        gop.value_ptr[at[0]][at[1]].mastery = masteryBin(points);
    }
    return map;
}

fn slot(team_id: i64, position: []const u8) ?[2]usize {
    const side: usize = switch (team_id) {
        100 => 0,
        200 => 1,
        else => return null,
    };
    const r = Role.fromLcu(position) orelse return null;
    return .{ side, @backingInt(r) };
}

const testing = std.testing;

test "history bins" {
    try testing.expectEqual(0, historyBin(1));
    try testing.expectEqual(0, historyBin(5));
    try testing.expectEqual(1, historyBin(6));
    try testing.expectEqual(2, historyBin(50));
    try testing.expectEqual(3, historyBin(51));
    try testing.expectEqual(3, historyBin(4000));
}

test "mastery bins" {
    try testing.expectEqual(0, masteryBin(0));
    try testing.expectEqual(0, masteryBin(9_999));
    try testing.expectEqual(1, masteryBin(10_000));
    try testing.expectEqual(3, masteryBin(1_000_000));
}
