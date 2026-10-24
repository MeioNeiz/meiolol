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
    item0: ?i64 = null,
    item1: ?i64 = null,
    item2: ?i64 = null,
    item3: ?i64 = null,
    item4: ?i64 = null,
    item5: ?i64 = null,
    item6: ?i64 = null,
    perks: ?struct {
        statPerks: ?struct { offense: ?i64 = null, flex: ?i64 = null, defense: ?i64 = null } = null,
        styles: []const struct {
            style: i64,
            selections: []const struct { perk: i64 } = &.{},
        } = &.{},
    } = null,

    const Runes = struct {
        primary_style: ?i64 = null,
        secondary_style: ?i64 = null,
        /// keystone, three primary, two secondary
        perks: [6]?i64 = @splat(null),
        shards: [3]?i64 = @splat(null),
    };

    fn runes(p: Participant) Runes {
        var r: Runes = .{};
        const perks = p.perks orelse return r;
        if (perks.styles.len > 0) {
            r.primary_style = perks.styles[0].style;
            for (perks.styles[0].selections[0..@min(4, perks.styles[0].selections.len)], 0..) |s, i| {
                r.perks[i] = s.perk;
            }
        }
        if (perks.styles.len > 1) {
            r.secondary_style = perks.styles[1].style;
            for (perks.styles[1].selections[0..@min(2, perks.styles[1].selections.len)], 4..) |s, i| {
                r.perks[i] = s.perk;
            }
        }
        if (perks.statPerks) |s| r.shards = .{ s.offense, s.flex, s.defense };
        return r;
    }
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

pub fn durationS(doc: Doc) i64 {
    // Before Oct 2021 gameDuration was milliseconds and gameEndTimestamp absent
    const info = doc.info;
    return if (info.gameEndTimestamp == null) @divTrunc(info.gameDuration, 1000) else info.gameDuration;
}

pub fn isRemake(doc: Doc) bool {
    for (doc.info.participants) |p| if (p.gameEndedInEarlySurrender) return true;
    return false;
}

/// Every participants column but tier and division, in insert order
const participant_columns = [_][]const u8{
    "match_id",
    "slot",
    "team_id",
    "puuid",
    "champion_id",
    "position",
    "individual_position",
    "win",
    "kills",
    "deaths",
    "assists",
    "gold",
    "damage_to_champions",
    "damage_taken",
    "vision_score",
    "cs",
    "champ_level",
    "summoner1",
    "summoner2",
    "keystone",
    "secondary_style",
    "item0",
    "item1",
    "item2",
    "item3",
    "item4",
    "item5",
    "item6",
    "primary_style",
    "perk1",
    "perk2",
    "perk3",
    "perk4",
    "perk5",
    "shard_offense",
    "shard_flex",
    "shard_defense",
};

/// A re-store (rebuild) updates the match's facts but keeps puuid (NULL after a
/// rekey) and the rank snapshot taken when the match was first stored
const insert_participant = blk: {
    var cols: []const u8 = participant_columns[0];
    var marks: []const u8 = "?";
    var sets: []const u8 = "";
    for (participant_columns[1..]) |c| {
        cols = cols ++ ", " ++ c;
        marks = marks ++ ", ?";
        if (std.mem.eql(u8, c, "slot") or std.mem.eql(u8, c, "puuid")) continue;
        sets = sets ++ (if (sets.len == 0) "" else ", ") ++ c ++ " = excluded." ++ c;
    }
    break :blk "INSERT INTO participants (" ++ cols ++ ") VALUES (" ++ marks ++
        ") ON CONFLICT (match_id, slot) DO UPDATE SET " ++ sets;
};

/// Replace this match's rows, with statements prepared for one call. Caller holds the
/// transaction
pub fn storeRows(db: store.Db, doc: Doc, source: []const u8) !void {
    var rows: Rows = try .init(db);
    defer rows.deinit();
    try rows.write(doc, source, try rows.exists(doc.metadata.matchId));
}

/// storeRows' statements, prepared once for callers storing many matches
pub const Rows = struct {
    has_rows: store.Stmt,
    trim: store.Stmt,
    unban: store.Stmt,
    match: store.Stmt,
    participant: store.Stmt,
    snapshot: store.Stmt,
    ban: store.Stmt,

    const sql = .{
        .has_rows = "SELECT EXISTS (SELECT 1 FROM participants WHERE match_id = ?)",
        .trim = "DELETE FROM participants WHERE match_id = ? AND slot >= ?",
        .unban = "DELETE FROM bans WHERE match_id = ?",
        .match = "INSERT OR REPLACE INTO matches VALUES (?,?,?,?,?,?,?,?,?,?)",
        .participant = insert_participant,
        .snapshot =
        \\UPDATE participants SET (tier, division) =
        \\    (SELECT tier, division FROM players p WHERE p.puuid = participants.puuid)
        \\WHERE match_id = ?
        ,
        // A team's pick turn twice (a damaged or odd document): the first ban stays,
        // rather than the match failing on the key
        .ban = "INSERT OR IGNORE INTO bans VALUES (?,?,?,?)",
    };
    const names = @typeInfo(Rows).@"struct".field_names;

    pub fn init(db: store.Db) !Rows {
        var r: Rows = undefined;
        var done: usize = 0;
        errdefer inline for (names, 0..) |name, i| {
            if (i < done) @field(r, name).deinit();
        };
        inline for (names) |name| {
            @field(r, name) = try db.prepare(@field(sql, name));
            done += 1;
        }
        return r;
    }

    pub fn deinit(r: *Rows) void {
        inline for (names) |name| @field(r, name).deinit();
    }

    /// The match has participant rows already
    pub fn exists(r: *Rows, id: []const u8) !bool {
        try r.has_rows.bind(.{id});
        defer r.has_rows.reset();
        return try r.has_rows.step() and r.has_rows.int(0) == 1;
    }

    /// Replace this match's rows. Caller holds the transaction. `existed`: stored
    /// before, so its rank snapshot stays
    pub fn write(rows: *Rows, doc: Doc, source: []const u8, existed: bool) !void {
        const info = doc.info;
        const id = doc.metadata.matchId;
        const duration = durationS(doc);

        var winner: ?i64 = null;
        var winners: usize = 0;
        for (info.teams) |t| if (t.win) {
            winner = t.teamId;
            winners += 1;
        };
        if (winners != 1) winner = null;
        const remake = isRemake(doc);

        const platform_id = info.platformId orelse id[0 .. std.mem.findScalar(u8, id, '_') orelse id.len];
        try rows.trim.exec(.{ id, info.participants.len });
        try rows.unban.exec(.{id});
        try rows.match.exec(.{
            id,                                               source,                    platform_id,
            info.queueId,                                     patchOf(info.gameVersion), info.gameVersion,
            info.gameStartTimestamp orelse info.gameCreation, duration,                  winner,
            remake,
        });

        for (info.participants, 0..) |p, slot| {
            const r = p.runes();
            const cs = (p.totalMinionsKilled orelse 0) + (p.neutralMinionsKilled orelse 0);
            try rows.participant.exec(.{
                id,
                slot,
                p.teamId,
                p.puuid,
                p.championId,
                nonEmpty(p.teamPosition),
                nonEmpty(p.individualPosition),
                p.win,
                p.kills,
                p.deaths,
                p.assists,
                p.goldEarned,
                p.totalDamageDealtToChampions,
                p.totalDamageTaken,
                p.visionScore,
                cs,
                p.champLevel,
                p.summoner1Id,
                p.summoner2Id,
                r.perks[0],
                r.secondary_style,
                p.item0,
                p.item1,
                p.item2,
                p.item3,
                p.item4,
                p.item5,
                p.item6,
                r.primary_style,
                r.perks[1],
                r.perks[2],
                r.perks[3],
                r.perks[4],
                r.perks[5],
                r.shards[0],
                r.shards[1],
                r.shards[2],
            });
        }
        if (!existed) try rows.snapshot.exec(.{id});

        for (info.teams) |t| for (t.bans) |b| {
            if (b.championId > 0) try rows.ban.exec(.{ id, t.teamId, b.pickTurn, b.championId });
        };
    }
};

/// Re-parse every raw summary still kept into the normalised tables, after a parser or
/// schema change. Returns how many were stored
pub fn rebuild(gpa: std.mem.Allocator, db: store.Db) !usize {
    var q = try db.prepare("SELECT key, body FROM raw.raw_docs WHERE source = 'riot_match'");
    defer q.deinit();
    var rows: Rows = try .init(db);
    defer rows.deinit();
    var stored: usize = 0;
    try db.begin();
    errdefer db.rollback();
    while (try q.step()) {
        var arena: std.heap.ArenaAllocator = .init(gpa);
        defer arena.deinit();
        const r = q.row(struct { key: []const u8, body: []const u8 });
        const body = try store.raw.decompress(arena.allocator(), r.body);
        const doc = parse(arena.allocator(), body) catch |err| {
            std.log.warn("match {s} did not parse: {t}", .{ r.key, err });
            continue;
        };
        try rows.write(doc, "riot", try rows.exists(doc.metadata.matchId));
        stored += 1;
        if (stored % 1000 == 0) {
            try db.commit();
            try db.begin();
        }
    }
    try db.commit();
    return stored;
}

const testing = std.testing;

test "parse and store the fixture" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const body = @embedFile("testdata/match.json");
    const doc = try parse(arena.allocator(), body);
    try testing.expectEqualStrings("NA1_5321429660", doc.metadata.matchId);
    try testing.expectEqualStrings("15.13", patchOf(doc.info.gameVersion));

    const db = try store.schema.memory();
    defer db.close();
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
    try testing.expectEqual(@as(?i64, 10), try db.scalar(
        "SELECT count(*) FROM participants WHERE item6 > 0 AND perk5 > 0 AND shard_defense > 0 " ++
            "AND primary_style <> secondary_style",
        .{},
    ));
}

test "re-storing after a rekey keeps rank and blanked puuids" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const doc = try parse(arena.allocator(), @embedFile("testdata/match.json"));
    const db = try store.schema.memory();
    defer db.close();
    try db.run("INSERT INTO players (puuid, tier, division, source) VALUES (?, 'GOLD', 'II', 'ladder')", .{
        doc.info.participants[0].puuid,
    });
    try storeRows(db, doc, "riot");
    try store.schema.rekey(db);
    try storeRows(db, doc, "riot");
    try testing.expectEqual(@as(?i64, 1), try db.scalar(
        "SELECT count(*) FROM participants WHERE slot = 0 AND tier = 'GOLD' AND division = 'II'",
        .{},
    ));
    try testing.expectEqual(@as(?i64, 10), try db.scalar(
        "SELECT count(*) FROM participants WHERE puuid IS NULL AND item6 IS NOT NULL",
        .{},
    ));
}

test "a pick turn twice keeps the first ban and stores the match" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    // backend-fuzz: the bans key failed and the match was not stored
    const body = try std.mem.replaceOwned(u8, arena.allocator(), @embedFile("testdata/match.json"), "\"pickTurn\":2", "\"pickTurn\":1");
    const db = try store.schema.memory();
    defer db.close();
    try storeRows(db, try parse(arena.allocator(), body), "riot");
    try testing.expectEqual(@as(?i64, 9), try db.scalar("SELECT count(*) FROM bans", .{}));
    try testing.expectEqual(@as(?i64, 10), try db.scalar("SELECT count(*) FROM participants", .{}));
}

fn fuzzMatch(db: store.Db, s: *testing.Smith) !void {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const body = try @import("core").fuzz.mutate(s, arena.allocator(), @embedFile("testdata/match.json"));
    const doc = parse(arena.allocator(), body) catch return;
    try db.begin();
    defer db.rollback();
    try storeRows(db, doc, "riot");
}

test "fuzz: a damaged match summary parses and stores, or fails, never crashes" {
    const db = try store.schema.memory();
    defer db.close();
    try testing.fuzz(db, fuzzMatch, .{});
}
