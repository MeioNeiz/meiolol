//! GDPR erasure (`meiolol forget`): removes a player by PUUID from every table that holds
//! one, in the live databases and in backup files (backup.zig). Policy in docs/data-safety.md:
//! match rows stay for aggregates with the player's PUUID blanked; raw match and timeline
//! JSON of their games is dropped (it names all ten players); players and mastery rows go.
//! The PUUID goes into `forgotten`, a suppression list: the crawler never stores them
//! again, a restore from an older backup re-applies the erasure, and a rekey can translate
//! it (which a hash would not allow).

const std = @import("std");
const store = @import("store");
const riot = @import("riot/root.zig");

const Db = store.Db;

/// Same DDL as schema.zig; repeated so forget works on databases and backup files made
/// before the table existed
const forgotten_ddl =
    \\CREATE TABLE IF NOT EXISTS forgotten (
    \\    puuid TEXT PRIMARY KEY,
    \\    forgotten_at INTEGER NOT NULL
    \\) WITHOUT ROWID;
;

pub fn ensure(db: Db) !void {
    try db.exec(forgotten_ddl);
}

pub fn isForgotten(db: Db, puuid: []const u8) !bool {
    return try db.scalar("SELECT 1 FROM forgotten WHERE puuid = ?", .{puuid}) != null;
}

pub const Removed = struct {
    players: i64 = 0,
    mastery: i64 = 0,
    participants: i64 = 0,
    raw_matches: i64 = 0,
    raw_timelines: i64 = 0,
    rank_history: i64 = 0,

    pub fn add(a: *Removed, b: Removed) void {
        inline for (@typeInfo(Removed).@"struct".field_names) |name| @field(a, name) += @field(b, name);
    }

    pub fn total(r: Removed) i64 {
        return r.players + r.mastery + r.participants + r.raw_matches + r.raw_timelines + r.rank_history;
    }
};

pub const Mode = enum {
    /// Live databases: also adds the PUUID to `forgotten`
    record,
    /// Backup files and re-application: removal only
    scrub,
};

/// Erase one PUUID from whichever of the known tables this connection has. secure_delete
/// overwrites the freed pages, so the bytes do not linger in the file.
pub fn forget(db: Db, puuid: []const u8, now: i64, mode: Mode) !Removed {
    try db.exec("PRAGMA secure_delete = ON");
    if (mode == .record) try ensure(db);
    try db.begin();
    errdefer db.rollback();
    var r: Removed = .{};
    const has_participants = try hasTable(db, "main", "participants");
    // Raw JSON first: participants is how we find the player's games
    if (has_participants and try hasTable(db, "raw", "raw_docs")) {
        try db.run(
            \\DELETE FROM raw.raw_docs WHERE source = 'riot_match' AND key IN
            \\    (SELECT match_id FROM participants WHERE puuid = ?)
        , .{puuid});
        r.raw_matches = changes(db);
    }
    if (has_participants and try hasTable(db, "raw", "timeline_docs")) {
        try db.run(
            \\DELETE FROM raw.timeline_docs WHERE match_id IN
            \\    (SELECT match_id FROM participants WHERE puuid = ?)
        , .{puuid});
        r.raw_timelines = changes(db);
    }
    if (has_participants) {
        try db.run("UPDATE participants SET puuid = NULL WHERE puuid = ?", .{puuid});
        r.participants = changes(db);
    }
    if (try hasTable(db, "main", "players")) {
        try db.run("DELETE FROM players WHERE puuid = ?", .{puuid});
        r.players = changes(db);
    }
    if (try hasTable(db, "main", "ranks")) {
        try db.run("DELETE FROM ranks WHERE key = ?", .{store.schema.puuidKey(puuid)});
    }
    if (try hasTable(db, "main", "rank_history")) {
        try db.run("DELETE FROM rank_history WHERE key = ?", .{store.schema.puuidKey(puuid)});
        r.rank_history = changes(db);
    }
    if (try hasTable(db, "main", "mastery")) {
        try db.run("DELETE FROM mastery WHERE puuid = ?", .{puuid});
        r.mastery = changes(db);
    }
    if (mode == .record) {
        try db.run("INSERT OR IGNORE INTO forgotten VALUES (?, ?)", .{ puuid, now });
    }
    try db.commit();
    return r;
}

/// After a restore: erase everyone in `forgotten` again, in case a backup file predates
/// their erasure
pub fn reapply(gpa: std.mem.Allocator, db: Db, now: i64) !Removed {
    var puuids: std.ArrayList([]u8) = .empty;
    defer {
        for (puuids.items) |p| gpa.free(p);
        puuids.deinit(gpa);
    }
    {
        var s = try db.prepare("SELECT puuid FROM forgotten");
        defer s.deinit();
        try s.bind(.{});
        while (try s.step()) try puuids.append(gpa, try gpa.dupe(u8, s.bytes(0)));
    }
    var total: Removed = .{};
    for (puuids.items) |puuid| total.add(try forget(db, puuid, now, .scrub));
    return total;
}

/// Every forgotten PUUID, one per line, written atomically to `path`: the box's half of
/// the exchange with the Your games service (box-forgotten.txt, docs/your-games.md)
pub fn exportList(io: std.Io, db: Db, path: []const u8) !usize {
    var file = try std.Io.Dir.cwd().createFileAtomic(io, path, .{ .make_path = true, .replace = true });
    defer file.deinit(io);
    var buf: [64 * 1024]u8 = undefined;
    var w = file.file.writer(io, &buf);
    var s = try db.prepare("SELECT puuid FROM forgotten ORDER BY puuid");
    defer s.deinit();
    try s.bind(.{});
    var n: usize = 0;
    while (try s.step()) : (n += 1) try w.interface.print("{s}\n", .{s.bytes(0)});
    try w.interface.flush();
    try file.replace(io);
    return n;
}

/// Riot ID ("Name#TAG") to PUUID via account-v1; null when Riot has no such account
pub fn resolveRiotId(gpa: std.mem.Allocator, client: *riot.client.Client, riot_id: []const u8) !?[]u8 {
    const at = std.mem.lastIndexOfScalar(u8, riot_id, '#') orelse return error.BadRiotId;
    var buf: [512]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    try w.writeAll("/riot/account/v1/accounts/by-riot-id/");
    try std.Uri.Component.percentEncode(&w, riot_id[0..at], isUnreserved);
    try w.writeByte('/');
    try std.Uri.Component.percentEncode(&w, riot_id[at + 1 ..], isUnreserved);
    // Riot IDs are global: any account-v1 route answers
    const body = try client.get("europe", w.buffered(), "account-v1.by-riot-id") orelse return null;
    defer gpa.free(body);
    const parsed = try std.json.parseFromSlice(struct { puuid: []const u8 }, gpa, body, .{
        .ignore_unknown_fields = true,
    });
    defer parsed.deinit();
    return try gpa.dupe(u8, parsed.value.puuid);
}

fn isUnreserved(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '-' or c == '.' or c == '_' or c == '~';
}

fn hasTable(db: Db, schema: []const u8, name: []const u8) !bool {
    return try db.scalar("SELECT 1 FROM pragma_table_list WHERE schema = ? AND name = ?", .{
        schema, name,
    }) != null;
}

fn changes(db: Db) i64 {
    return store.sqlite.c.sqlite3_changes64(db.handle);
}

const testing = std.testing;

fn testDb() !Db {
    const db = try store.schema.memory();
    errdefer db.close();
    try db.exec(
        \\INSERT INTO players (puuid, source) VALUES ('gone', 'ladder'), ('kept', 'ladder');
        \\INSERT INTO mastery VALUES ('gone', 'EUW1', 1, 0, x''), ('kept', 'EUW1', 1, 0, x'');
        \\INSERT INTO participants (match_id, slot, team_id, puuid, champion_id, win)
        \\    VALUES ('EUW1_1', 0, 100, 'gone', 1, 1), ('EUW1_1', 1, 100, 'kept', 2, 1),
        \\           ('EUW1_2', 0, 100, 'kept', 3, 0);
        \\INSERT INTO raw.raw_docs VALUES ('riot_match', 'EUW1_1', 1, x''),
        \\    ('riot_match', 'EUW1_2', 1, x'');
        \\INSERT INTO raw.timeline_docs VALUES ('EUW1_1', 1, x''), ('EUW1_2', 1, x'');
    );
    try db.run("INSERT INTO rank_history VALUES (?1, 1, 0, 0, 1, 0), (?1, 2, 0, 9, 2, 0), (?2, 1, 0, 0, 1, 0)", .{
        store.schema.puuidKey("gone"), store.schema.puuidKey("kept"),
    });
    return db;
}

test "forget blanks identity, keeps match rows, records the PUUID" {
    const db = try testDb();
    defer db.close();
    const r = try forget(db, "gone", 7, .record);
    try testing.expectEqual(Removed{
        .players = 1,
        .mastery = 1,
        .participants = 1,
        .raw_matches = 1,
        .raw_timelines = 1,
        .rank_history = 2,
    }, r);
    try testing.expectEqual(@as(?i64, 3), try db.scalar("SELECT count(*) FROM participants", .{}));
    try testing.expectEqual(@as(?i64, 0), try db.scalar(
        "SELECT count(*) FROM participants WHERE puuid = 'gone'",
        .{},
    ));
    try testing.expectEqual(@as(?i64, 1), try db.scalar(
        "SELECT count(*) FROM raw.raw_docs WHERE key = 'EUW1_2'",
        .{},
    ));
    try testing.expect(try isForgotten(db, "gone"));
    try testing.expect(!try isForgotten(db, "kept"));
    // Idempotent, and the first date stays
    try testing.expectEqual(@as(i64, 0), (try forget(db, "gone", 8, .record)).total());
    try testing.expectEqual(@as(?i64, 7), try db.scalar("SELECT forgotten_at FROM forgotten", .{}));
}

test "reapply erases PUUIDs forgotten after the backup was taken" {
    const db = try testDb();
    defer db.close();
    try ensure(db);
    try db.run("INSERT INTO forgotten VALUES ('gone', 1)", .{});
    const r = try reapply(testing.allocator, db, 2);
    try testing.expectEqual(@as(i64, 1), r.players);
    try testing.expectEqual(@as(i64, 1), r.participants);
    try testing.expectEqual(@as(?i64, 1), try db.scalar("SELECT count(*) FROM players", .{}));
}

test "scrub works on a file with only some tables" {
    const db = try Db.open(":memory:");
    defer db.close();
    try db.exec(
        \\CREATE TABLE participants (match_id TEXT, slot INTEGER, puuid TEXT);
        \\INSERT INTO participants VALUES ('EUW1_1', 0, 'gone');
    );
    const r = try forget(db, "gone", 1, .scrub);
    try testing.expectEqual(@as(i64, 1), r.participants);
    try testing.expectEqual(@as(?i64, 0), try db.scalar(
        "SELECT count(*) FROM pragma_table_list WHERE name = 'forgotten'",
        .{},
    ));
}
