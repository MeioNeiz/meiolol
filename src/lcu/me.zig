//! The local player's own data from the League client: champion mastery, visible solo
//! queue tier and recent games. Only the fields the app shows are parsed; identities in
//! the replies (puuid, summonerId) are never kept.

const std = @import("std");
const core = @import("core");

pub const paths = struct {
    pub const mastery = "/lol-champion-mastery/v1/local-player/champion-mastery";
    pub const ranked = "/lol-ranked/v1/current-ranked-stats";
    pub const history = "/lol-match-history/v1/products/lol/current-summoner/matches?begIndex=0&endIndex=20";
};

pub const Mastery = struct { champion: u32, points: u32 };

const json_opts: std.json.ParseOptions = .{
    .ignore_unknown_fields = true,
    .allocate = .alloc_always,
};

/// Most points first. Allocates in `arena`
pub fn parseMastery(arena: std.mem.Allocator, json: []const u8) ![]Mastery {
    const Row = struct { championId: i64 = 0, championPoints: i64 = 0 };
    const rows = try std.json.parseFromSliceLeaky([]const Row, arena, json, json_opts);
    var out: std.ArrayList(Mastery) = .empty;
    for (rows) |r| {
        if (r.championId <= 0 or r.championId > std.math.maxInt(u32)) continue;
        try out.append(arena, .{
            .champion = @intCast(r.championId),
            .points = std.math.lossyCast(u32, r.championPoints),
        });
    }
    std.mem.sort(Mastery, out.items, {}, struct {
        fn more(_: void, a: Mastery, b: Mastery) bool {
            return a.points > b.points;
        }
    }.more);
    return out.items;
}

/// Ranked Solo/Duo tier ("GOLD"), null when unranked or missing. Allocates in `arena`
pub fn parseSoloTier(arena: std.mem.Allocator, json: []const u8) !?[]const u8 {
    const Queue = struct { tier: []const u8 = "" };
    const Ranked = struct {
        queueMap: struct { RANKED_SOLO_5x5: Queue = .{} } = .{},
    };
    const r = try std.json.parseFromSliceLeaky(Ranked, arena, json, json_opts);
    const tier = r.queueMap.RANKED_SOLO_5x5.tier;
    if (tier.len == 0 or std.mem.eql(u8, tier, "NONE")) return null;
    return tier;
}

/// One of the local player's Summoner's Rift games
pub const Game = struct { champion: u16, win: bool, kills: u8, deaths: u8, assists: u8, minutes: u8 };

/// The lobby's form panel: recent games and mastery top, fixed size so the poller
/// publishes it by value
pub const Form = struct {
    games: [max_games]Game = undefined,
    n: u8 = 0,
    top: [max_top]Mastery = undefined,
    m: u8 = 0,
    /// Changes with what shows
    stamp: u64 = 0,

    pub const max_games = 20;
    pub const max_top = 5;

    pub fn recent(f: *const Form) []const Game {
        return f.games[0..f.n];
    }

    pub fn mastery(f: *const Form) []const Mastery {
        return f.top[0..f.m];
    }

    pub fn empty(f: *const Form) bool {
        return f.n == 0 and f.m == 0;
    }

    /// `m` most points first (parseMastery)
    pub fn setMastery(f: *Form, m: []const Mastery) void {
        f.m = @intCast(@min(m.len, max_top));
        @memcpy(f.top[0..f.m], m[0..f.m]);
    }

    pub fn seal(f: *Form) void {
        var h: std.hash.Wyhash = .init(0);
        for (f.recent()) |g| h.update(&.{ @truncate(g.champion), @truncate(g.champion >> 8), @intFromBool(g.win), g.kills, g.deaths, g.assists, g.minutes });
        for (f.mastery()) |x| h.update(std.mem.asBytes(&x));
        f.stamp = h.final();
    }
};

/// Shorter games are remakes, in no record
const remake_seconds = 300;
const summoners_rift = 11;

/// Summoner's Rift games newest first, remakes and bot or custom games left out. The
/// reply's participants hold only the local player; a game with any other count is
/// skipped. Allocates in `arena`
pub fn parseHistory(arena: std.mem.Allocator, json: []const u8) ![]Game {
    const Stats = struct { kills: i64 = 0, deaths: i64 = 0, assists: i64 = 0, win: bool = false };
    const Player = struct { championId: i64 = 0, stats: Stats = .{} };
    const Row = struct {
        gameCreation: i64 = 0,
        gameDuration: i64 = 0,
        mapId: i64 = 0,
        queueId: i64 = 0,
        participants: []const Player = &.{},
    };
    const Reply = struct { games: struct { games: []const Row = &.{} } = .{} };
    const r = try std.json.parseFromSliceLeaky(Reply, arena, json, json_opts);
    const rows = try arena.dupe(Row, r.games.games);
    std.mem.sort(Row, rows, {}, struct {
        fn newer(_: void, a: Row, b: Row) bool {
            return a.gameCreation > b.gameCreation;
        }
    }.newer);
    var out: std.ArrayList(Game) = .empty;
    for (rows) |g| {
        if (g.participants.len != 1 or g.mapId != summoners_rift) continue;
        // 0 custom, 800s and up bots and events
        if (g.queueId <= 0 or g.queueId >= 800 or g.gameDuration < remake_seconds) continue;
        const p = g.participants[0];
        const champion = std.math.cast(u16, p.championId) orelse continue;
        if (champion == 0) continue;
        try out.append(arena, .{
            .champion = champion,
            .win = p.stats.win,
            .kills = std.math.lossyCast(u8, p.stats.kills),
            .deaths = std.math.lossyCast(u8, p.stats.deaths),
            .assists = std.math.lossyCast(u8, p.stats.assists),
            .minutes = std.math.lossyCast(u8, @divTrunc(g.gameDuration, 60)),
        });
    }
    return out.items;
}

/// `games` newest first, the first max_games kept
pub fn formOf(games: []const Game, mastery: []const Mastery) Form {
    var f: Form = .{};
    f.n = @intCast(@min(games.len, Form.max_games));
    @memcpy(f.games[0..f.n], games[0..f.n]);
    f.setMastery(mastery);
    f.seal();
    return f;
}

test "history: newest first, only the player's Rift games" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const json =
        \\{"accountId":1,"games":{"gameCount":5,"games":[
        \\ {"gameCreation":100,"gameDuration":1834,"mapId":11,"queueId":420,
        \\  "participants":[{"championId":103,"stats":{"kills":7,"deaths":2,"assists":9,"win":true}}]},
        \\ {"gameCreation":300,"gameDuration":1500,"mapId":11,"queueId":400,
        \\  "participants":[{"championId":61,"stats":{"kills":3,"deaths":6,"assists":4,"win":false}}]},
        \\ {"gameCreation":400,"gameDuration":200,"mapId":11,"queueId":420,
        \\  "participants":[{"championId":61,"stats":{"win":false}}]},
        \\ {"gameCreation":500,"gameDuration":1100,"mapId":12,"queueId":450,
        \\  "participants":[{"championId":61,"stats":{"win":true}}]},
        \\ {"gameCreation":200,"gameDuration":1300,"mapId":11,"queueId":0,
        \\  "participants":[{"championId":61,"stats":{"win":true}}]}]}}
    ;
    const games = try parseHistory(arena.allocator(), json);
    try std.testing.expectEqual(2, games.len);
    try std.testing.expectEqual(61, games[0].champion);
    try std.testing.expectEqual(false, games[0].win);
    try std.testing.expectEqual(25, games[0].minutes);
    try std.testing.expectEqual(103, games[1].champion);
    try std.testing.expectEqual(9, games[1].assists);
    try std.testing.expectEqual(0, (try parseHistory(arena.allocator(), "{}")).len);

    const f = formOf(games, &.{ .{ .champion = 103, .points = 9 }, .{ .champion = 61, .points = 3 } });
    try std.testing.expectEqual(2, f.recent().len);
    try std.testing.expectEqual(2, f.mastery().len);
    var g = f;
    g.games[0].win = true;
    g.seal();
    try std.testing.expect(g.stamp != f.stamp);
}

test "mastery sorted, bad rows dropped" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const json =
        \\[{"championId":103,"championPoints":1200,"puuid":"x"},
        \\ {"championId":0,"championPoints":5},
        \\ {"championId":266,"championPoints":91000,"championLevel":12}]
    ;
    const m = try parseMastery(arena.allocator(), json);
    try std.testing.expectEqual(2, m.len);
    try std.testing.expectEqual(266, m[0].champion);
    try std.testing.expectEqual(91000, m[0].points);
}

test "solo tier" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const ranked =
        \\{"queueMap":{"RANKED_FLEX_SR":{"tier":"SILVER"},
        \\ "RANKED_SOLO_5x5":{"tier":"GOLD","division":"II"}},"queues":[]}
    ;
    try std.testing.expectEqualStrings("GOLD", (try parseSoloTier(a, ranked)).?);
    const none =
        \\{"queueMap":{"RANKED_SOLO_5x5":{"tier":"NONE"}}}
    ;
    try std.testing.expectEqual(null, try parseSoloTier(a, none));
    try std.testing.expectEqual(null, try parseSoloTier(a, "{}"));
}

fn fuzzMe(_: void, s: *std.testing.Smith) !void {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const mastery =
        \\[{"championId":103,"championPoints":1200},{"championId":266,"championPoints":91000}]
    ;
    const ranked =
        \\{"queueMap":{"RANKED_SOLO_5x5":{"tier":"GOLD","division":"II"}}}
    ;
    _ = parseMastery(arena, try core.fuzz.mutate(s, arena, mastery)) catch {};
    _ = parseSoloTier(arena, try core.fuzz.mutate(s, arena, ranked)) catch {};
    const history =
        \\{"games":{"games":[{"gameCreation":1,"gameDuration":1834,"mapId":11,"queueId":420,
        \\ "participants":[{"championId":103,"stats":{"kills":7,"deaths":2,"assists":9,"win":true}}]}]}}
    ;
    _ = parseHistory(arena, try core.fuzz.mutate(s, arena, history)) catch {};
}

test "fuzz: damaged mastery, ranked and history replies" {
    try std.testing.fuzz({}, fuzzMe, .{});
}
