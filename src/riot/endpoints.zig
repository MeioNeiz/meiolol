//! Riot API endpoints the crawler uses. Bodies are returned raw (caller frees) so
//! they can be stored as received; `parse*` helpers decode them.

const std = @import("std");
const Client = @import("client.zig").Client;

pub const platform = "euw1";
pub const region = "europe";
pub const ranked_solo = 420;

pub fn leagueEntries(c: *Client, tier: []const u8, division: []const u8, page: u32) !?[]u8 {
    var buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(
        &buf,
        "/lol/league-exp/v4/entries/RANKED_SOLO_5x5/{s}/{s}?page={d}",
        .{ tier, division, page },
    );
    return c.get(platform, path, "league-exp-v4.entries");
}

pub fn matchIds(c: *Client, puuid: []const u8, start_time: i64, end_time: i64, start: u32) !?[]u8 {
    var buf: [512]u8 = undefined;
    const path = try std.fmt.bufPrint(
        &buf,
        "/lol/match/v5/matches/by-puuid/{s}/ids?queue={d}&startTime={d}&endTime={d}" ++
            "&start={d}&count=100",
        .{ puuid, ranked_solo, start_time, end_time, start },
    );
    return c.get(region, path, "match-v5.ids");
}

pub fn match(c: *Client, match_id: []const u8) !?[]u8 {
    var buf: [128]u8 = undefined;
    const path = try std.fmt.bufPrint(&buf, "/lol/match/v5/matches/{s}", .{match_id});
    return c.get(region, path, "match-v5.match");
}

pub fn masteries(c: *Client, puuid: []const u8) !?[]u8 {
    var buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(
        &buf,
        "/lol/champion-mastery/v4/champion-masteries/by-puuid/{s}",
        .{puuid},
    );
    return c.get(platform, path, "champion-mastery-v4.by-puuid");
}

pub const LeagueEntry = struct {
    puuid: ?[]const u8 = null,
    tier: []const u8,
    rank: []const u8,
    leaguePoints: i64 = 0,
    wins: i64 = 0,
    losses: i64 = 0,
};

pub const Mastery = struct {
    championId: i64,
    championLevel: ?i64 = null,
    championPoints: ?i64 = null,
    lastPlayTime: ?i64 = null,
};

pub fn parse(comptime T: type, arena: std.mem.Allocator, body: []const u8) !T {
    return std.json.parseFromSliceLeaky(T, arena, body, .{ .ignore_unknown_fields = true });
}
