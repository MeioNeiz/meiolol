//! `meiolol api --fixture`: made-up players in a fresh api.db, so pages can be tried
//! against a local API with no Riot key and no Riot call. One recorded match and
//! timeline (src/riot/testdata, read from disk: never in the binary) played from each of
//! its ten seats in turn, a game every seven hours back from now
//!
//! - Fixture#EUW: 40 games (some without a timeline, one remake), GOLD II, friends with
//!   Duo#EUW in a few
//! - Duo#EUW: the same games from the seat beside, unranked
//! - Hidden#EUW: opted out
//! - Any other Riot ID: never looked up (queued, it stays so: the fetcher doesn't run)
const std = @import("std");
const store = @import("store");
const riot = @import("../riot/root.zig");
const cache = @import("cache.zig");
const game = @import("game.zig");

const Allocator = std.mem.Allocator;

pub const match_path = "src/riot/testdata/match.json";
pub const timeline_path = "src/riot/testdata/timeline.json.gz";

const games = 40;
const gap_ms: i64 = 7 * std.time.ms_per_hour;

const Who = struct { riot_id: []const u8, puuid: []const u8, name: []const u8, tier: ?[]const u8 = null, division: ?[]const u8 = null, lp: ?i64 = null };

const fixture: Who = .{ .riot_id = "fixture#euw", .puuid = "fixture-puuid", .name = "Fixture", .tier = "GOLD", .division = "II", .lp = 41 };
const duo: Who = .{ .riot_id = "duo#euw", .puuid = "duo-puuid", .name = "Duo" };
const hidden: Who = .{ .riot_id = "hidden#euw", .puuid = "hidden-puuid", .name = "Hidden" };

/// `match_json` and `timeline_gz` as at `match_path` and `timeline_path`; `now_s` dates
/// the games
pub fn seed(arena: Allocator, db: store.Db, match_json: []const u8, timeline_gz: []const u8, now_s: i64) !void {
    const base = try game.summarise(arena, match_json);
    const t = try riot.timeline.fromJson(arena, try store.raw.decompress(arena, timeline_gz));
    const timeline = try store.raw.compress(arena, try riot.timeline.encode(arena, t));

    for ([_]Who{ fixture, duo, hidden }) |w| {
        try db.run("INSERT INTO accounts VALUES (?, ?, ?)", .{ w.riot_id, w.puuid, now_s });
        try db.run(
            "INSERT INTO players (puuid, game_name, tag_line, platform, tier, division, lp, refreshed) VALUES (?, ?, 'EUW', 'EUW1', ?, ?, ?, ?)",
            .{ w.puuid, w.name, w.tier, w.division, w.lp, now_s },
        );
    }
    try db.run("INSERT INTO blocked VALUES (?, ?)", .{ hidden.puuid, now_s });

    for (0..games) |i| {
        var s = base;
        s.start_ms = now_s * std.time.ms_per_s - @as(i64, @intCast(i + 1)) * gap_ms;
        s.queue = if (i % 5 == 4) 440 else 420;
        s.remake = i == 11;
        if (s.remake) s.duration_s = 200;
        const players = try arena.dupe(game.Summary.Player, base.players);
        for (players) |*p| p.hash = "";
        s.players = players;
        const id = try arena.print("EUW1_{d}", .{9000000000 + i});
        const has_timeline = i % 7 != 6 and !s.remake;
        const json = try std.json.Stringify.valueAlloc(arena, s, .{});
        const summary: store.Blob = .{ .bytes = try store.raw.compress(arena, json) };
        const with: ?store.Blob = if (has_timeline) .{ .bytes = timeline } else null;
        try db.run("INSERT INTO matches VALUES (?, ?, ?, ?)", .{ id, now_s, summary, with });
        const slot: u8 = @intCast(i % 10);
        try db.run("INSERT INTO player_games VALUES (?, ?, ?, ?)", .{ fixture.puuid, id, s.start_ms, slot });
        try db.run("INSERT INTO match_names VALUES (?, ?, '', 'Fixture#EUW')", .{ id, slot });
        // Beside them on their team in every third game
        if (i % 3 == 0) {
            const beside: u8 = if (slot % 5 == 4) slot - 1 else slot + 1;
            try db.run("INSERT INTO player_games VALUES (?, ?, ?, ?)", .{ duo.puuid, id, s.start_ms, beside });
            try db.run("INSERT INTO match_names VALUES (?, ?, '', 'Duo#EUW')", .{ id, beside });
        }
    }
}

test "seed: three players, the games newest first" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const db = try cache.open(":memory:");
    defer db.close();
    try seed(arena, db, @embedFile("../riot/testdata/match.json"), @embedFile("../riot/testdata/timeline.json.gz"), 1_800_000_000);
    try std.testing.expectEqual(@as(?i64, 3), try db.scalar("SELECT count(*) FROM players", .{}));
    try std.testing.expectEqual(@as(?i64, games), try db.scalar("SELECT count(*) FROM player_games WHERE puuid = 'fixture-puuid'", .{}));
    try std.testing.expectEqual(@as(?i64, 1_800_000_000_000 - gap_ms), try db.scalar("SELECT max(start_ms) FROM player_games", .{}));
    try std.testing.expectEqual(@as(?i64, 6), try db.scalar("SELECT count(*) FROM matches WHERE timeline IS NULL", .{}));
}
