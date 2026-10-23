//! The client's end of game block (/lol-end-of-game/v1/eog-stats-block, read-only): who
//! won, how long, and each player's totals, for the post game view (APP11). Shapes from
//! the community LCU schema and the mock; APP1's capture checks them

const std = @import("std");
const core = @import("core");
const Role = core.Role;

pub const path = "/lol-end-of-game/v1/eog-stats-block";

pub const Player = struct {
    champion: u32,
    /// On the local player's team
    ours: bool,
    /// detectedTeamPosition, else selectedPosition; null when both are blank
    role: ?Role,
    me: bool,
    kills: u32,
    deaths: u32,
    assists: u32,
    /// Minions plus monsters
    cs: u32,
    gold: u32,
    damage: u32,
    vision: u32,
    level: u32,
};

pub const Eog = struct {
    win: bool,
    /// Seconds
    length: u32,
    players: []const Player,
};

const json_opts: std.json.ParseOptions = .{
    .ignore_unknown_fields = true,
    .allocate = .alloc_always,
};

const RawPlayer = struct {
    championId: i64 = 0,
    puuid: []const u8 = "",
    summonerName: []const u8 = "",
    detectedTeamPosition: []const u8 = "",
    selectedPosition: []const u8 = "",
    stats: struct {
        CHAMPIONS_KILLED: i64 = 0,
        NUM_DEATHS: i64 = 0,
        ASSISTS: i64 = 0,
        MINIONS_KILLED: i64 = 0,
        NEUTRAL_MINIONS_KILLED: i64 = 0,
        GOLD_EARNED: i64 = 0,
        TOTAL_DAMAGE_DEALT_TO_CHAMPIONS: i64 = 0,
        VISION_SCORE: i64 = 0,
        LEVEL: i64 = 0,
    } = .{},
};

const Raw = struct {
    gameLength: i64 = 0,
    localPlayer: RawPlayer = .{},
    teams: []const struct {
        isPlayerTeam: bool = false,
        isWinningTeam: bool = false,
        players: []const RawPlayer = &.{},
    } = &.{},
};

/// Allocates in `arena`
pub fn parse(arena: std.mem.Allocator, json: []const u8) !Eog {
    const raw = try std.json.parseFromSliceLeaky(Raw, arena, json, json_opts);
    var players: std.ArrayList(Player) = .empty;
    var win = false;
    const lp = raw.localPlayer;
    for (raw.teams) |t| {
        if (t.isPlayerTeam) win = t.isWinningTeam;
        for (t.players) |r| {
            const st = r.stats;
            try players.append(arena, .{
                .champion = std.math.lossyCast(u32, @max(0, r.championId)),
                .ours = t.isPlayerTeam,
                .role = role(r.detectedTeamPosition) orelse role(r.selectedPosition),
                .me = (lp.puuid.len > 0 and std.mem.eql(u8, r.puuid, lp.puuid)) or
                    (lp.puuid.len == 0 and lp.summonerName.len > 0 and std.mem.eql(u8, r.summonerName, lp.summonerName)),
                .kills = clamp(st.CHAMPIONS_KILLED),
                .deaths = clamp(st.NUM_DEATHS),
                .assists = clamp(st.ASSISTS),
                .cs = clamp(st.MINIONS_KILLED) +| clamp(st.NEUTRAL_MINIONS_KILLED),
                .gold = clamp(st.GOLD_EARNED),
                .damage = clamp(st.TOTAL_DAMAGE_DEALT_TO_CHAMPIONS),
                .vision = clamp(st.VISION_SCORE),
                .level = clamp(st.LEVEL),
            });
        }
    }
    return .{ .win = win, .length = clamp(raw.gameLength), .players = players.items };
}

fn clamp(n: i64) u32 {
    return std.math.lossyCast(u32, @max(0, n));
}

fn role(position: []const u8) ?Role {
    const names = [_]struct { []const u8, Role }{
        .{ "TOP", .top },
        .{ "JUNGLE", .jungle },
        .{ "MIDDLE", .middle },
        .{ "MID", .middle },
        .{ "BOTTOM", .bottom },
        .{ "UTILITY", .utility },
        .{ "SUPPORT", .utility },
    };
    for (names) |n| if (std.ascii.eqlIgnoreCase(position, n[0])) return n[1];
    return null;
}

const testing = std.testing;
pub const fixture_path = "testdata/lcu/eog-stats-block.json";

test "end of game block: result, length, totals by team" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const body = try std.Io.Dir.cwd().readFileAlloc(testing.io, fixture_path, arena, .limited(1 << 20));
    const e = try parse(arena, body);
    try testing.expect(e.win);
    try testing.expectEqual(1722, e.length);
    try testing.expectEqual(10, e.players.len);
    const me = e.players[2];
    try testing.expect(me.me and me.ours);
    try testing.expectEqual(61, me.champion);
    try testing.expectEqual(Role.middle, me.role.?);
    try testing.expectEqual(224, me.cs);
    try testing.expect(!e.players[7].ours);
}

fn fuzzEog(fixture: []const u8, s: *testing.Smith) !void {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    _ = parse(arena, try core.fuzz.mutate(s, arena, fixture)) catch {};
}

test "fuzz: a damaged end of game block parses or fails, never crashes" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const body = try std.Io.Dir.cwd().readFileAlloc(testing.io, fixture_path, arena_state.allocator(), .limited(1 << 20));
    try testing.fuzz(@as([]const u8, body), fuzzEog, .{});
}
