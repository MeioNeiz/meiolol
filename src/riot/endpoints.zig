//! Riot API endpoints the crawler uses. Bodies are returned raw (caller frees) so
//! they can be stored as received; `parse*` helpers decode them.

const std = @import("std");
const Client = @import("client.zig").Client;

pub const ranked_solo = 420;
pub const ranked_flex = 440;
pub const normal_draft = 400;
pub const swiftplay = 480;

/// match-v5 routing values. Each has its own rate limit bucket on a personal key, as
/// does every platform
pub const Region = enum { americas, asia, europe, sea };

pub const Platform = struct {
    /// Riot's platform id, as in match ids (EUW1_123) and info.platformId
    id: []const u8,
    /// Host for platform-routed APIs (league-exp, mastery)
    host: []const u8,
    region: Region,
};

/// Every LoL platform in Riot's API spec (riotapi-schema, 2026-10); all 15 answered
/// league-exp on 2026-10-11. PH2 and TH2 no longer resolve (merged into SG2)
pub const platforms = [_]Platform{
    .{ .id = "NA1", .host = "na1", .region = .americas },
    .{ .id = "BR1", .host = "br1", .region = .americas },
    .{ .id = "LA1", .host = "la1", .region = .americas },
    .{ .id = "LA2", .host = "la2", .region = .americas },
    .{ .id = "KR", .host = "kr", .region = .asia },
    .{ .id = "JP1", .host = "jp1", .region = .asia },
    .{ .id = "EUW1", .host = "euw1", .region = .europe },
    .{ .id = "EUN1", .host = "eun1", .region = .europe },
    .{ .id = "TR1", .host = "tr1", .region = .europe },
    .{ .id = "RU", .host = "ru", .region = .europe },
    .{ .id = "ME1", .host = "me1", .region = .europe },
    .{ .id = "OC1", .host = "oc1", .region = .sea },
    .{ .id = "SG2", .host = "sg2", .region = .sea },
    .{ .id = "TW2", .host = "tw2", .region = .sea },
    .{ .id = "VN2", .host = "vn2", .region = .sea },
};

/// Platform of a match id ("KR_7012345678" -> KR)
pub fn platformOf(match_id: []const u8) ?Platform {
    return platform(match_id[0 .. std.mem.indexOfScalar(u8, match_id, '_') orelse return null]);
}

/// "EUW1" -> EUW1
pub fn platform(id: []const u8) ?Platform {
    for (platforms) |p| if (std.mem.eql(u8, p.id, id)) return p;
    return null;
}

pub fn leagueEntries(c: *Client, p: Platform, tier: []const u8, division: []const u8, page: u32) !?[]u8 {
    var buf: [256]u8 = undefined;
    const path = try std.mem.print(
        &buf,
        "/lol/league-exp/v4/entries/RANKED_SOLO_5x5/{s}/{s}?page={d}",
        .{ tier, division, page },
    );
    return c.get(p.host, path, "league-exp-v4.entries");
}

pub fn matchIds(c: *Client, r: Region, puuid: []const u8, queue: u16, start_time: i64, end_time: i64, start: u32) !?[]u8 {
    var buf: [512]u8 = undefined;
    const path = try std.mem.print(
        &buf,
        "/lol/match/v5/matches/by-puuid/{s}/ids?queue={d}&startTime={d}&endTime={d}" ++
            "&start={d}&count=100",
        .{ puuid, queue, start_time, end_time, start },
    );
    return c.get(@tagName(r), path, "match-v5.ids");
}

pub fn match(c: *Client, r: Region, match_id: []const u8) !?[]u8 {
    var buf: [128]u8 = undefined;
    const path = try std.mem.print(&buf, "/lol/match/v5/matches/{s}", .{match_id});
    return c.get(@tagName(r), path, "match-v5.match");
}

pub fn timeline(c: *Client, r: Region, match_id: []const u8) !?[]u8 {
    var buf: [128]u8 = undefined;
    const path = try std.mem.print(&buf, "/lol/match/v5/matches/{s}/timeline", .{match_id});
    return c.get(@tagName(r), path, "match-v5.timeline");
}

pub fn masteries(c: *Client, p: Platform, puuid: []const u8) !?[]u8 {
    var buf: [256]u8 = undefined;
    const path = try std.mem.print(
        &buf,
        "/lol/champion-mastery/v4/champion-masteries/by-puuid/{s}",
        .{puuid},
    );
    return c.get(p.host, path, "champion-mastery-v4.by-puuid");
}

/// Riot IDs are global: any of americas, asia or europe answers account-v1
pub fn accountByRiotId(c: *Client, r: Region, game_name: []const u8, tag_line: []const u8) !?[]u8 {
    var buf: [512]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    try w.writeAll("/riot/account/v1/accounts/by-riot-id/");
    try std.Uri.Component.percentEncode(&w, game_name, isUnreserved);
    try w.writeByte('/');
    try std.Uri.Component.percentEncode(&w, tag_line, isUnreserved);
    return c.get(@tagName(r), w.buffered(), "account-v1.by-riot-id");
}

/// The platform a player plays League on ({"region": "euw1"}: a platform host)
pub fn activePlatform(c: *Client, r: Region, puuid: []const u8) !?[]u8 {
    var buf: [256]u8 = undefined;
    const path = try std.mem.print(&buf, "/riot/account/v1/region/by-game/lol/by-puuid/{s}", .{puuid});
    return c.get(@tagName(r), path, "account-v1.region");
}

pub fn leagueByPuuid(c: *Client, p: Platform, puuid: []const u8) !?[]u8 {
    var buf: [256]u8 = undefined;
    const path = try std.mem.print(&buf, "/lol/league/v4/entries/by-puuid/{s}", .{puuid});
    return c.get(p.host, path, "league-v4.by-puuid");
}

/// For profileIconId: the ownership check before an objection is honoured
pub fn summonerByPuuid(c: *Client, p: Platform, puuid: []const u8) !?[]u8 {
    var buf: [256]u8 = undefined;
    const path = try std.mem.print(&buf, "/lol/summoner/v4/summoners/by-puuid/{s}", .{puuid});
    return c.get(p.host, path, "summoner-v4.by-puuid");
}

fn isUnreserved(ch: u8) bool {
    return std.ascii.isAlphanumeric(ch) or ch == '-' or ch == '.' or ch == '_' or ch == '~';
}

pub fn platformByHost(host: []const u8) ?Platform {
    for (platforms) |p| if (std.ascii.eqlIgnoreCase(p.host, host)) return p;
    return null;
}

pub const Account = struct {
    puuid: []const u8,
    gameName: ?[]const u8 = null,
    tagLine: ?[]const u8 = null,
};

pub const LeagueEntry = struct {
    queueType: ?[]const u8 = null,
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

test platformOf {
    try std.testing.expectEqual(Region.asia, platformOf("KR_7012345678").?.region);
    try std.testing.expectEqual(Region.sea, platformOf("OC1_1").?.region);
    try std.testing.expect(platformOf("XX1_1") == null);
    try std.testing.expect(platformOf("nounderscore") == null);
    try std.testing.expectEqual(Region.europe, platform("EUW1").?.region);
    try std.testing.expect(platform("EUW1_1") == null);
}
