//! match-v5 JSON -> rows in matches, participants and bans.

const std = @import("std");
const store = @import("store");

pub const Doc = struct {
    metadata: struct {
        matchId: []const u8,
        participants: []const []const u8 = &.{},
    },
    info: struct {
        gameCreation: i64,
        gameDuration: i64,
        gameStartTimestamp: ?i64 = null,
        gameEndTimestamp: ?i64 = null,
        gameVersion: []const u8,
        queueId: i64,
        platformId: ?[]const u8 = null,
        participants: []const Participant,
        teams: []const Team,
    },
};

const Participant = struct {
    puuid: ?[]const u8 = null,
    championId: i64,
    teamId: i64,
    teamPosition: ?[]const u8 = null,
    individualPosition: ?[]const u8 = null,
    win: bool = false,
    gameEndedInEarlySurrender: bool = false,
    kills: ?i64 = null,
    deaths: ?i64 = null,
    assists: ?i64 = null,
    goldEarned: ?i64 = null,
    totalDamageDealtToChampions: ?i64 = null,
    totalDamageTaken: ?i64 = null,
    visionScore: ?i64 = null,
    totalMinionsKilled: ?i64 = null,
    neutralMinionsKilled: ?i64 = null,
    champLevel: ?i64 = null,
    summoner1Id: ?i64 = null,
    summoner2Id: ?i64 = null,
    perks: ?struct {
        styles: []const struct {
            style: i64,
            selections: []const struct { perk: i64 } = &.{},
        } = &.{},
    } = null,
};

const Team = struct {
    teamId: i64,
    win: bool = false,
    bans: []const struct { championId: i64, pickTurn: i64 } = &.{},
};

pub fn parse(arena: std.mem.Allocator, body: []const u8) !Doc {
    return std.json.parseFromSliceLeaky(Doc, arena, body, .{ .ignore_unknown_fields = true });
}

/// "16.20.712.4512" -> "16.20"
pub fn patchOf(version: []const u8) []const u8 {
    var dots: usize = 0;
    for (version, 0..) |ch, i| {
        if (ch != '.') continue;
        dots += 1;
        if (dots == 2) return version[0..i];
    }
    return version;
}

fn nonEmpty(s: ?[]const u8) ?[]const u8 {
    const v = s orelse return null;
    return if (v.len == 0) null else v;
}

/// Replace this match's rows. Caller holds the transaction.
pub fn storeRows(db: store.Db, doc: Doc, source: []const u8) !void {
    const info = doc.info;
    const id = doc.metadata.matchId;
    // Before Oct 2021 gameDuration was milliseconds and gameEndTimestamp absent
    const duration = if (info.gameEndTimestamp == null) @divTrunc(info.gameDuration, 1000) else info.gameDuration;

    var winner: ?i64 = null;
    var winners: usize = 0;
    for (info.teams) |t| if (t.win) {
        winner = t.teamId;
        winners += 1;
    };
    if (winners != 1) winner = null;
    var remake = false;
    for (info.participants) |p| remake = remake or p.gameEndedInEarlySurrender;

    const platform_id = info.platformId orelse id[0 .. std.mem.indexOfScalar(u8, id, '_') orelse id.len];
    try db.run("DELETE FROM participants WHERE match_id = ?", .{id});
    try db.run("DELETE FROM bans WHERE match_id = ?", .{id});
    try db.run("INSERT OR REPLACE INTO matches VALUES (?,?,?,?,?,?,?,?,?,?)", .{
        id,                                               source,                    platform_id,
        info.queueId,                                     patchOf(info.gameVersion), info.gameVersion,
        info.gameStartTimestamp orelse info.gameCreation, duration,                  winner,
        remake,
    });

    var ins = try db.prepare("INSERT INTO participants VALUES " ++
        "(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)");
    defer ins.deinit();
    for (info.participants, 0..) |p, slot| {
        var keystone: ?i64 = null;
        var secondary: ?i64 = null;
        if (p.perks) |perks| {
            if (perks.styles.len > 0 and perks.styles[0].selections.len > 0) {
                keystone = perks.styles[0].selections[0].perk;
            }
            if (perks.styles.len > 1) secondary = perks.styles[1].style;
        }
        const cs = (p.totalMinionsKilled orelse 0) + (p.neutralMinionsKilled orelse 0);
        try ins.exec(.{
            id,                             slot,               p.teamId,
            p.puuid,                        p.championId,       nonEmpty(p.teamPosition),
            nonEmpty(p.individualPosition), p.win,              p.kills,
            p.deaths,                       p.assists,          p.goldEarned,
            p.totalDamageDealtToChampions,  p.totalDamageTaken, p.visionScore,
            cs,                             p.champLevel,       p.summoner1Id,
            p.summoner2Id,                  keystone,           secondary,
        });
    }

    var ban = try db.prepare("INSERT INTO bans VALUES (?,?,?,?)");
    defer ban.deinit();
    for (info.teams) |t| for (t.bans) |b| {
        if (b.championId > 0) try ban.exec(.{ id, t.teamId, b.pickTurn, b.championId });
    };
}

const testing = std.testing;

test "parse and store the fixture" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const body = @embedFile("testdata/match.json");
    const doc = try parse(arena.allocator(), body);
    try testing.expectEqualStrings("NA1_5321429660", doc.metadata.matchId);
    try testing.expectEqualStrings("15.13", patchOf(doc.info.gameVersion));

    const db = try store.Db.open(":memory:");
    defer db.close();
    try db.exec("ATTACH DATABASE ':memory:' AS raw");
    try db.exec(store.schema.schema);
    try storeRows(db, doc, "riot");
    try storeRows(db, doc, "riot");
    try testing.expectEqual(@as(?i64, 10), try db.scalar("SELECT count(*) FROM participants", .{}));
    try testing.expectEqual(@as(?i64, 10), try db.scalar("SELECT count(*) FROM bans", .{}));
    try testing.expectEqual(@as(?i64, 100), try db.scalar("SELECT winning_team FROM matches", .{}));
    try testing.expectEqual(@as(?i64, 1620), try db.scalar("SELECT duration_s FROM matches", .{}));
    try testing.expectEqual(@as(?i64, 5), try db.scalar(
        "SELECT count(DISTINCT position) FROM participants",
        .{},
    ));
}
