//! Other players' facts for the private loading screen (docs/plan/app.md Policy line:
//! scouting from the loading screen on): solo tier, mastery at the two ends, their recent
//! Rift games on the pick. Read-only GETs per player; puuids live only in the poller's
//! arena for that game, nothing is written. A streamer-mode player has no puuid in the
//! session and gets no calls (research/sources/riot-docs-lol.md ^f5, opgg-ingame-
//! streamer-mode.md ^f2). Field names follow the community LCU schema; check them in the
//! first real `meiolol-app record`.

const std = @import("std");
const core = @import("core");
const me = @import("me.zig");

pub const paths = struct {
    pub const session = "/lol-gameflow/v1/session";

    pub fn ranked(buf: []u8, puuid: []const u8) ![]const u8 {
        return std.fmt.bufPrint(buf, "/lol-ranked/v1/ranked-stats/{s}", .{puuid});
    }

    pub fn mastery(buf: []u8, puuid: []const u8) ![]const u8 {
        return std.fmt.bufPrint(buf, "/lol-champion-mastery/v1/{s}/champion-mastery", .{puuid});
    }

    pub fn history(buf: []u8, puuid: []const u8) ![]const u8 {
        return std.fmt.bufPrint(buf, "/lol-match-history/v1/products/lol/{s}/matches?begIndex=0&endIndex={d}", .{ puuid, history_games });
    }

    /// Fits each path for a puuid of up to 96 bytes
    pub const max_len = 160;
};

/// Games asked for; only the Summoner's Rift ones among them count
pub const history_games = 20;

pub const Player = struct { puuid: []const u8, champion: u32 };

const json_opts: std.json.ParseOptions = .{
    .ignore_unknown_fields = true,
    .allocate = .alloc_always,
};

/// Both teams from the gameflow session's gameData. Players without a puuid (streamer
/// mode) or a champion are left out. Allocates in `arena`
pub fn parsePlayers(arena: std.mem.Allocator, json: []const u8) ![]Player {
    const Row = struct { puuid: []const u8 = "", championId: i64 = 0 };
    const Session = struct {
        gameData: struct { teamOne: []const Row = &.{}, teamTwo: []const Row = &.{} } = .{},
    };
    const s = try std.json.parseFromSliceLeaky(Session, arena, json, json_opts);
    var out: std.ArrayList(Player) = .empty;
    for ([_][]const Row{ s.gameData.teamOne, s.gameData.teamTwo }) |team| for (team) |r| {
        if (r.puuid.len == 0 or r.puuid.len > 96) continue;
        const champion = std.math.cast(u32, r.championId) orelse continue;
        if (champion == 0) continue;
        try out.append(arena, .{ .puuid = r.puuid, .champion = champion });
    };
    return out.items;
}

pub const Mastery = enum(u8) {
    unknown,
    /// No points on the champion: their first game on it
    first,
    /// Their most played champion
    main,
    /// Between: the card says nothing
    some,
};

/// What a card shows about one player. Strings are static
pub const Facts = struct {
    /// "Emerald"; empty when unranked or unknown
    tier: []const u8 = "",
    /// "II"; empty for apex tiers
    division: []const u8 = "",
    mastery: Mastery = .unknown,
    /// Their Summoner's Rift games of the last history_games, those on the pick, won
    games: u8 = 0,
    on_pick: u8 = 0,
    won: u8 = 0,

    /// Fewer games on the pick are too few for a win count
    pub const thin = 5;

    pub fn empty(f: Facts) bool {
        return f.tier.len == 0 and f.mastery != .first and f.mastery != .main and f.on_pick == 0;
    }
};

const tiers = [_]struct { []const u8, []const u8, bool }{
    .{ "IRON", "Iron", false },
    .{ "BRONZE", "Bronze", false },
    .{ "SILVER", "Silver", false },
    .{ "GOLD", "Gold", false },
    .{ "PLATINUM", "Platinum", false },
    .{ "EMERALD", "Emerald", false },
    .{ "DIAMOND", "Diamond", false },
    .{ "MASTER", "Master", true },
    .{ "GRANDMASTER", "Grandmaster", true },
    .{ "CHALLENGER", "Challenger", true },
};
const divisions = [_][]const u8{ "I", "II", "III", "IV" };

pub const Rank = struct { tier: []const u8, division: []const u8 };

/// Ranked Solo/Duo from ranked-stats, as words; null when unranked, missing or unknown
pub fn parseRank(arena: std.mem.Allocator, json: []const u8) !?Rank {
    const Queue = struct { tier: []const u8 = "", division: []const u8 = "" };
    const Ranked = struct {
        queueMap: struct { RANKED_SOLO_5x5: Queue = .{} } = .{},
    };
    const r = try std.json.parseFromSliceLeaky(Ranked, arena, json, json_opts);
    const q = r.queueMap.RANKED_SOLO_5x5;
    for (tiers) |t| if (std.mem.eql(u8, q.tier, t[0])) {
        if (t[2]) return .{ .tier = t[1], .division = "" };
        for (divisions) |d| if (std.mem.eql(u8, q.division, d)) return .{ .tier = t[1], .division = d };
        return .{ .tier = t[1], .division = "" };
    };
    return null;
}

/// Each part null when its reply didn't load. `mastery` most points first
/// (me.parseMastery), `games` the player's Rift games (me.parseHistory)
pub fn factsOf(champion: u32, rank: ?Rank, mastery: ?[]const me.Mastery, games: ?[]const me.Game) Facts {
    var f: Facts = .{};
    if (rank) |r| {
        f.tier = r.tier;
        f.division = r.division;
    }
    // An empty list says nothing: a fresh account and a failed lookup look alike
    if (mastery) |m| if (m.len > 0) {
        f.mastery = blk: {
            if (m[0].champion == champion and m[0].points > 0) break :blk .main;
            for (m) |x| if (x.champion == champion and x.points > 0) break :blk .some;
            break :blk .first;
        };
    };
    if (games) |gs| {
        const n = @min(gs.len, history_games);
        f.games = @intCast(n);
        for (gs[0..n]) |g| if (g.champion == champion) {
            f.on_pick += 1;
            if (g.win) f.won += 1;
        };
    }
    if (f.mastery == .first and f.on_pick > 0) f.mastery = .some;
    return f;
}

test "players: both teams, streamer mode and empty seats left out" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const json =
        \\{"phase":"GameStart","gameData":{"gameId":7,"teamOne":[
        \\ {"puuid":"a-1","championId":103,"summonerName":"x"},
        \\ {"puuid":"","championId":64,"summonerName":""}],
        \\ "teamTwo":[{"puuid":"b-1","championId":266},{"puuid":"b-2","championId":0}]}}
    ;
    const ps = try parsePlayers(arena.allocator(), json);
    try std.testing.expectEqual(2, ps.len);
    try std.testing.expectEqualStrings("a-1", ps[0].puuid);
    try std.testing.expectEqual(266, ps[1].champion);
    try std.testing.expectEqual(0, (try parsePlayers(arena.allocator(), "{}")).len);
}

test "rank as words" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const emerald =
        \\{"queueMap":{"RANKED_SOLO_5x5":{"tier":"EMERALD","division":"II"}}}
    ;
    const r = (try parseRank(a, emerald)).?;
    try std.testing.expectEqualStrings("Emerald", r.tier);
    try std.testing.expectEqualStrings("II", r.division);
    const master =
        \\{"queueMap":{"RANKED_SOLO_5x5":{"tier":"MASTER","division":"I"}}}
    ;
    try std.testing.expectEqualStrings("", (try parseRank(a, master)).?.division);
    const none =
        \\{"queueMap":{"RANKED_SOLO_5x5":{"tier":"NONE","division":"NA"}}}
    ;
    try std.testing.expectEqual(null, try parseRank(a, none));
}

test "facts: mastery ends, games on the pick" {
    const ahri = 103;
    const m = [_]me.Mastery{ .{ .champion = 266, .points = 90_000 }, .{ .champion = ahri, .points = 4_000 } };
    try std.testing.expectEqual(.some, factsOf(ahri, null, &m, null).mastery);
    try std.testing.expectEqual(.main, factsOf(266, null, &m, null).mastery);
    try std.testing.expectEqual(.first, factsOf(1, null, &m, null).mastery);
    try std.testing.expectEqual(.unknown, factsOf(1, null, null, null).mastery);
    try std.testing.expectEqual(.unknown, factsOf(1, null, &.{}, null).mastery);

    const g = [_]me.Game{
        .{ .champion = ahri, .win = true, .kills = 0, .deaths = 0, .assists = 0, .minutes = 30 },
        .{ .champion = 266, .win = true, .kills = 0, .deaths = 0, .assists = 0, .minutes = 30 },
        .{ .champion = ahri, .win = false, .kills = 0, .deaths = 0, .assists = 0, .minutes = 30 },
    };
    const f = factsOf(ahri, .{ .tier = "Gold", .division = "IV" }, &m, &g);
    try std.testing.expectEqual(3, f.games);
    try std.testing.expectEqual(2, f.on_pick);
    try std.testing.expectEqual(1, f.won);
    try std.testing.expect(!f.empty());
    try std.testing.expect(factsOf(ahri, null, null, null).empty());
}

fn fuzzPlayers(_: void, s: *std.testing.Smith) !void {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const session =
        \\{"gameData":{"teamOne":[{"puuid":"a","championId":103}],"teamTwo":[{"puuid":"","championId":64}]}}
    ;
    const ranked =
        \\{"queueMap":{"RANKED_SOLO_5x5":{"tier":"GOLD","division":"II"}}}
    ;
    _ = parsePlayers(arena, try core.fuzz.mutate(s, arena, session)) catch {};
    _ = parseRank(arena, try core.fuzz.mutate(s, arena, ranked)) catch {};
}

test "fuzz: damaged session and ranked replies" {
    try std.testing.fuzz({}, fuzzPlayers, .{});
}
