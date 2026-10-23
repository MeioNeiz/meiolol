//! The game's own Live Client Data API (127.0.0.1:2999, no password, Riot's root as the
//! LCU): what the in-game panel reads. Only what it shows is kept: champions, positions,
//! scores, items' prices and the objective events. Shapes from Riot's docs and the mock;
//! APP1's capture checks them against a real game (docs/plan/app.md)

const std = @import("std");
const core = @import("core");
const Role = core.Role;

pub const port = 2999;
pub const path = "/liveclientdata/allgamedata";

/// ORDER is the blue side (team 100), CHAOS red
pub const Team = enum { order, chaos };

pub const Player = struct {
    /// Data Dragon id from rawChampionName ("MonkeyKing"), else the display name, which
    /// follows the client's language
    champion: []const u8,
    team: Team,
    /// Null when the game leaves the position blank (custom games, some modes)
    role: ?Role,
    level: u32,
    kills: u32,
    deaths: u32,
    assists: u32,
    /// Lane minions plus monsters
    cs: u32,
    dead: bool,
    respawn: f32,
    /// Shop price of everything held: what other players' gold is estimated from, as
    /// the game shows nobody's gold but your own
    item_gold: u32,
    /// The local player
    me: bool,
};

pub const Kind = enum { dragon, elder, baron, herald, grubs, tower, inhibitor, inhibitor_back };

pub const Event = struct {
    /// Game seconds
    time: f64,
    kind: Kind,
    /// Who took it; for inhibitor_back the side whose inhibitor is back. Null when the
    /// killer is unknown
    team: ?Team,
    /// Inhibitors only
    lane: ?Lane = null,
};

pub const Lane = enum { top, mid, bot };

pub const Game = struct {
    /// Game seconds
    time: f64,
    /// CLASSIC on Summoner's Rift
    mode: []const u8,
    players: []const Player,
    events: []const Event,
    /// The local player's unspent gold
    gold: f64,

    pub fn me(g: Game) ?Player {
        for (g.players) |p| if (p.me) return p;
        return null;
    }
};

const json_opts: std.json.ParseOptions = .{
    .ignore_unknown_fields = true,
    .allocate = .alloc_always,
};

const Raw = struct {
    activePlayer: struct {
        riotId: []const u8 = "",
        summonerName: []const u8 = "",
        currentGold: f64 = 0,
    } = .{},
    allPlayers: []const struct {
        championName: []const u8 = "",
        rawChampionName: []const u8 = "",
        isDead: bool = false,
        respawnTimer: f64 = 0,
        level: i64 = 1,
        position: []const u8 = "",
        riotId: []const u8 = "",
        riotIdGameName: []const u8 = "",
        summonerName: []const u8 = "",
        team: []const u8 = "",
        scores: struct {
            kills: i64 = 0,
            deaths: i64 = 0,
            assists: i64 = 0,
            creepScore: i64 = 0,
        } = .{},
        items: []const struct { price: i64 = 0, count: i64 = 1 } = &.{},
    } = &.{},
    events: struct { Events: []const std.json.Value = &.{} } = .{},
    gameData: struct { gameTime: f64 = 0, gameMode: []const u8 = "" } = .{},
};

/// Allocates in `arena`
pub fn parse(arena: std.mem.Allocator, json: []const u8) !Game {
    const raw = try std.json.parseFromSliceLeaky(Raw, arena, json, json_opts);
    const players = try arena.alloc(Player, raw.allPlayers.len);
    // Event killers go by Riot ID game name (summoner name before Riot IDs)
    const names = try arena.alloc([]const u8, raw.allPlayers.len);
    const ap = raw.activePlayer;
    for (players, names, raw.allPlayers) |*p, *n, r| {
        var gold: u64 = 0;
        for (r.items) |it| gold += clamp(it.price) * @max(1, clamp(it.count));
        const prefix = "game_character_displayname_";
        p.* = .{
            .champion = if (std.mem.startsWith(u8, r.rawChampionName, prefix)) r.rawChampionName[prefix.len..] else r.championName,
            .team = if (std.mem.eql(u8, r.team, "CHAOS")) .chaos else .order,
            .role = role(r.position),
            .level = clamp(r.level),
            .kills = clamp(r.scores.kills),
            .deaths = clamp(r.scores.deaths),
            .assists = clamp(r.scores.assists),
            .cs = clamp(r.scores.creepScore),
            .dead = r.isDead,
            .respawn = @floatCast(@max(0, r.respawnTimer)),
            .item_gold = std.math.lossyCast(u32, gold),
            .me = same(r.riotId, ap.riotId) or same(r.summonerName, ap.summonerName),
        };
        n.* = if (r.riotIdGameName.len > 0) r.riotIdGameName else r.summonerName;
    }
    var events: std.ArrayList(Event) = .empty;
    for (raw.events.Events) |v| if (try event(v, players, names)) |e| try events.append(arena, e);
    return .{
        .time = @max(0, raw.gameData.gameTime),
        .mode = raw.gameData.gameMode,
        .players = players,
        .events = events.items,
        .gold = @max(0, ap.currentGold),
    };
}

fn same(a: []const u8, b: []const u8) bool {
    return a.len > 0 and std.mem.eql(u8, a, b);
}

fn clamp(n: i64) u32 {
    return std.math.lossyCast(u32, @max(0, n));
}

fn role(position: []const u8) ?Role {
    const names = [_]struct { []const u8, Role }{
        .{ "TOP", .top },
        .{ "JUNGLE", .jungle },
        .{ "MIDDLE", .middle },
        .{ "BOTTOM", .bottom },
        .{ "UTILITY", .utility },
    };
    for (names) |n| if (std.mem.eql(u8, position, n[0])) return n[1];
    return null;
}

/// The objective events the panel counts; null for the rest (kills, multikills, ...)
fn event(v: std.json.Value, players: []const Player, names: []const []const u8) !?Event {
    if (v != .object) return null;
    const o = v.object;
    const name = str(o, "EventName");
    const time: f64 = switch (o.get("EventTime") orelse return null) {
        .float => |f| f,
        .integer => |i| @floatFromInt(i),
        else => return null,
    };
    const eql = std.mem.eql;
    const killer = teamOf(str(o, "KillerName"), players, names);
    if (eql(u8, name, "DragonKill")) {
        return .{ .time = time, .kind = if (eql(u8, str(o, "DragonType"), "Elder")) .elder else .dragon, .team = killer };
    }
    if (eql(u8, name, "BaronKill")) return .{ .time = time, .kind = .baron, .team = killer };
    if (eql(u8, name, "HeraldKill")) return .{ .time = time, .kind = .herald, .team = killer };
    if (eql(u8, name, "HordeKill")) return .{ .time = time, .kind = .grubs, .team = killer };
    // Structures name their owner: Turret_T1_C_05_A is ORDER's, so CHAOS took it
    if (eql(u8, name, "TurretKilled")) {
        const owner = structureTeam(str(o, "TurretKilled")) orelse return null;
        return .{ .time = time, .kind = .tower, .team = other(owner) };
    }
    if (eql(u8, name, "InhibKilled") or eql(u8, name, "InhibRespawned")) {
        const what = str(o, name);
        const owner = structureTeam(what) orelse return null;
        const back = eql(u8, name, "InhibRespawned");
        return .{ .time = time, .kind = if (back) .inhibitor_back else .inhibitor, .team = if (back) owner else other(owner), .lane = inhibLane(what) };
    }
    return null;
}

fn str(o: std.json.ObjectMap, key: []const u8) []const u8 {
    const v = o.get(key) orelse return "";
    return if (v == .string) v.string else "";
}

fn teamOf(killer: []const u8, players: []const Player, names: []const []const u8) ?Team {
    if (killer.len == 0) return null;
    for (players, names) |p, n| if (std.mem.eql(u8, n, killer)) return p.team;
    return null;
}

fn other(t: Team) Team {
    return if (t == .order) .chaos else .order;
}

fn structureTeam(name: []const u8) ?Team {
    if (std.mem.indexOf(u8, name, "_T1_") != null) return .order;
    if (std.mem.indexOf(u8, name, "_T2_") != null) return .chaos;
    return null;
}

/// Barracks_T1_L1 top, _C1 mid, _R1 bot
fn inhibLane(name: []const u8) ?Lane {
    const at = std.mem.lastIndexOfScalar(u8, name, '_') orelse return null;
    if (at + 1 >= name.len) return null;
    return switch (name[at + 1]) {
        'L' => .top,
        'C' => .mid,
        'R' => .bot,
        else => null,
    };
}

const testing = std.testing;
pub const fixture_path = "testdata/lcu/live-allgamedata.json";

test "a game's reply: players, gold from items, objectives by team" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const body = try std.Io.Dir.cwd().readFileAlloc(testing.io, fixture_path, arena, .limited(1 << 20));
    const g = try parse(arena, body);
    try testing.expectEqual(10, g.players.len);
    const me = g.me().?;
    try testing.expectEqualStrings("Orianna", me.champion);
    try testing.expectEqual(Team.order, me.team);
    try testing.expectEqual(Role.middle, me.role.?);
    try testing.expectEqual(2900, me.item_gold);
    try testing.expectEqualStrings("MonkeyKing", g.players[6].champion);
    var dragons: [2]u32 = .{ 0, 0 };
    var towers: [2]u32 = .{ 0, 0 };
    for (g.events) |e| switch (e.kind) {
        .dragon => dragons[@backingInt(e.team.?)] += 1,
        .tower => towers[@backingInt(e.team.?)] += 1,
        else => {},
    };
    try testing.expectEqual([2]u32{ 1, 1 }, dragons);
    try testing.expectEqual([2]u32{ 2, 1 }, towers);
}

test "inhibitors by lane and owner" {
    const players = [_]Player{};
    var obj: std.json.ObjectMap = .empty;
    defer obj.deinit(testing.allocator);
    try obj.put(testing.allocator, "EventName", .{ .string = "InhibKilled" });
    try obj.put(testing.allocator, "EventTime", .{ .float = 1800 });
    try obj.put(testing.allocator, "InhibKilled", .{ .string = "Barracks_T2_R1" });
    const e = (try event(.{ .object = obj }, &players, &.{})).?;
    try testing.expectEqual(Kind.inhibitor, e.kind);
    try testing.expectEqual(Team.order, e.team.?);
    try testing.expectEqual(Lane.bot, e.lane.?);
}

fn fuzzLive(fixture: []const u8, s: *testing.Smith) !void {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    _ = parse(arena, try core.fuzz.mutate(s, arena, fixture)) catch {};
}

test "fuzz: a damaged Live Client Data reply parses or fails, never crashes" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const body = try std.Io.Dir.cwd().readFileAlloc(testing.io, fixture_path, arena_state.allocator(), .limited(1 << 20));
    try testing.fuzz(@as([]const u8, body), fuzzLive, .{});
}
