//! api.db: looked-up accounts and players, the refresh queue, matches cached by id, and
//! Daily Draft answer counts. Own file, separate from the crawler's databases: the
//! service runs on the web server.

const std = @import("std");
const store = @import("store");
const game = @import("game.zig");

const Db = store.Db;

pub const schema =
    \\PRAGMA journal_mode = WAL;
    \\
    \\-- Riot ID (lower case "name#tag") -> PUUID; puuid NULL when Riot has no such account
    \\CREATE TABLE IF NOT EXISTS accounts (
    \\    riot_id TEXT PRIMARY KEY,
    \\    puuid TEXT,
    \\    checked INTEGER NOT NULL
    \\) WITHOUT ROWID;
    \\
    \\-- Looked-up players only. Name and tag as Riot spells them; tier is the visible solo
    \\-- queue rank at the last refresh (never MMR)
    \\CREATE TABLE IF NOT EXISTS players (
    \\    puuid TEXT PRIMARY KEY,
    \\    game_name TEXT NOT NULL,
    \\    tag_line TEXT NOT NULL,
    \\    platform TEXT NOT NULL,
    \\    tier TEXT,
    \\    division TEXT,
    \\    lp INTEGER,
    \\    refreshed INTEGER NOT NULL DEFAULT 0,
    \\    looked_up INTEGER NOT NULL DEFAULT 0,
    \\    error TEXT
    \\) WITHOUT ROWID;
    \\
    \\-- Work for the fetcher: a lower case Riot ID to resolve, or a PUUID to refresh.
    \\-- pending/total: games still to fetch, for the page's progress line
    \\CREATE TABLE IF NOT EXISTS jobs (
    \\    key TEXT PRIMARY KEY,
    \\    requested INTEGER NOT NULL,
    \\    pending INTEGER,
    \\    total INTEGER
    \\) WITHOUT ROWID;
    \\
    \\CREATE TABLE IF NOT EXISTS player_games (
    \\    puuid TEXT NOT NULL,
    \\    match_id TEXT NOT NULL,
    \\    start_ms INTEGER NOT NULL,
    \\    slot INTEGER NOT NULL,
    \\    PRIMARY KEY (puuid, match_id)
    \\) WITHOUT ROWID;
    \\
    \\-- A player's games in the last 60 days not fetched yet, oldest last by id: the
    \\-- fetcher takes them a step at a time (summary only), between other lookups
    \\CREATE TABLE IF NOT EXISTS backlog (
    \\    puuid TEXT NOT NULL,
    \\    match_id TEXT NOT NULL,
    \\    PRIMARY KEY (puuid, match_id)
    \\) WITHOUT ROWID;
    \\
    \\-- Objections (docs/your-games.md): to prove they own a Riot ID, the player sets
    \\-- profile icon `icon` before `expires` (unix s). state: pending (being issued),
    \\-- issued, checking, mismatch (icon not set yet), done, not_found
    \\CREATE TABLE IF NOT EXISTS challenges (
    \\    riot_id TEXT PRIMARY KEY,
    \\    puuid TEXT,
    \\    icon INTEGER,
    \\    expires INTEGER NOT NULL,
    \\    state TEXT NOT NULL
    \\) WITHOUT ROWID;
    \\
    \\-- Players who objected (or Riot asked us to erase): never fetched or shown again
    \\CREATE TABLE IF NOT EXISTS blocked (
    \\    puuid TEXT PRIMARY KEY,
    \\    at INTEGER NOT NULL
    \\) WITHOUT ROWID;
    \\
    \\-- summary: gzip JSON of game.Summary (no names; PUUIDs hashed). timeline: gzip
    \\-- compact timeline (riot/timeline.zig); NULL not fetched yet, empty when Riot has
    \\-- none or the game was a remake
    \\CREATE TABLE IF NOT EXISTS matches (
    \\    match_id TEXT PRIMARY KEY,
    \\    fetched INTEGER NOT NULL,
    \\    summary BLOB NOT NULL,
    \\    timeline BLOB
    \\);
    \\
    \\-- Riot ID of each player in a cached match as at that game ("Name#TAG"), for the
    \\-- page's player list; erased with the match. hash: game.hashPuuid, so an erasure
    \\-- finds a player's rows. None for a blocked player
    \\CREATE TABLE IF NOT EXISTS match_names (
    \\    match_id TEXT NOT NULL,
    \\    slot INTEGER NOT NULL,
    \\    hash TEXT NOT NULL,
    \\    riot_id TEXT NOT NULL,
    \\    PRIMARY KEY (match_id, slot)
    \\) WITHOUT ROWID;
    \\CREATE INDEX IF NOT EXISTS match_names_hash ON match_names (hash);
    \\
    \\-- Daily Draft: how many finished puzzle n with each option (0-3, the puzzle's order)
    \\-- and side (0 blue, 1 red). Counts only: nothing about who answered
    \\CREATE TABLE IF NOT EXISTS daily_answers (
    \\    n INTEGER NOT NULL,
    \\    pick INTEGER NOT NULL,
    \\    side INTEGER NOT NULL,
    \\    count INTEGER NOT NULL,
    \\    PRIMARY KEY (n, pick, side)
    \\) WITHOUT ROWID;
;

/// Job keys for a player's backlog: this prefix, then the PUUID
pub const history_prefix = "history:";

pub fn open(path: [:0]const u8) !Db {
    const db = try Db.open(path);
    errdefer db.close();
    try db.exec(schema);
    return db;
}

/// Lower case "name#tag" with surrounding spaces trimmed; null unless both parts are
/// there and within Riot's lengths (name 3-16, tag 3-5; checked loosely, Riot decides)
pub fn riotIdKey(buf: []u8, name: []const u8, tag: []const u8) ?[]const u8 {
    const n = std.mem.trim(u8, name, " ");
    const t = std.mem.trim(u8, tag, " ");
    if (n.len == 0 or n.len > 32 or t.len == 0 or t.len > 8) return null;
    if (std.mem.findAny(u8, n, "#/?\\") != null or std.mem.findAny(u8, t, "#/?\\ ") != null) return null;
    const key = std.mem.print(buf, "{s}#{s}", .{ n, t }) catch return null;
    // ASCII only: Riot IDs may hold other letters, and lookups by them are case
    // insensitive on Riot's side, so a missed fold only costs a second cache row
    for (key) |*c| c.* = std.ascii.toLower(c.*);
    return key;
}

/// Deletes everything about one player (their row, games, any queued job, their Riot
/// ID in every cached match) and blocks their PUUID from being fetched again: for
/// objections and Riot's erasure lists. The blocklist keeps the PUUID alone, the
/// minimum needed to honour the objection. Matches other players share stay, without
/// this player's name; unreferenced ones go. `now` in unix seconds
pub fn forget(db: Db, puuid: []const u8, now: i64) !void {
    var hash_buf: [game.hash_len]u8 = undefined;
    try db.begin();
    errdefer db.rollback();
    try db.run("INSERT OR REPLACE INTO blocked VALUES (?, ?)", .{ puuid, now });
    try db.run("DELETE FROM match_names WHERE hash = ?", .{game.hashPuuid(&hash_buf, puuid)});
    try deletePlayers(db, "SELECT ?1", .{puuid});
    try db.commit();
}

/// Retention: players nobody has looked up since `before` (unix s) go, unblocked (a
/// new lookup starts afresh); so do settled or expired challenges and remembered
/// unknown Riot IDs older than a day
pub fn prune(db: Db, before: i64, now: i64) !void {
    try db.begin();
    errdefer db.rollback();
    try deletePlayers(db, "SELECT puuid FROM players WHERE looked_up < ?1", .{before});
    try db.run("DELETE FROM challenges WHERE expires < ?", .{now - std.time.s_per_day});
    try db.run("DELETE FROM accounts WHERE puuid IS NULL AND checked < ?", .{now - std.time.s_per_day});
    try db.commit();
}

/// After a key switch every cached PUUID belongs to the old app: players, their games,
/// Riot ID lookups, PUUID jobs and challenges go, refetched on the next lookup. Caller
/// holds the transaction; rekey.zig carries `blocked` over
pub fn clearForRekey(db: Db) !void {
    try deletePlayers(db, "SELECT puuid FROM players", .{});
    // Riot ID jobs hold '#' and stay valid
    try db.run("DELETE FROM jobs WHERE instr(key, '#') = 0", .{});
    try db.run("DELETE FROM accounts", .{});
    try db.run("DELETE FROM challenges", .{});
}

/// Players whose PUUIDs `select` returns, with their games, accounts and jobs; then
/// matches no remaining player references. Caller holds the transaction
fn deletePlayers(db: Db, comptime select: []const u8, args: anytype) !void {
    try db.run("CREATE TEMP TABLE IF NOT EXISTS gone (puuid TEXT PRIMARY KEY)", .{});
    try db.run("DELETE FROM temp.gone", .{});
    try db.run("INSERT OR IGNORE INTO temp.gone " ++ select, args);
    try db.run("DELETE FROM players WHERE puuid IN temp.gone", .{});
    try db.run("DELETE FROM player_games WHERE puuid IN temp.gone", .{});
    try db.run("DELETE FROM backlog WHERE puuid IN temp.gone", .{});
    try db.run("DELETE FROM accounts WHERE puuid IN temp.gone", .{});
    try db.run("DELETE FROM jobs WHERE key IN temp.gone OR key IN (SELECT ?1 || puuid FROM temp.gone)", .{history_prefix});
    try db.run(
        \\DELETE FROM matches WHERE match_id NOT IN (SELECT match_id FROM player_games)
    , .{});
    try db.run("DELETE FROM match_names WHERE match_id NOT IN (SELECT match_id FROM matches)", .{});
}

test "prune drops players not looked up, keeps blocked ones blocked" {
    const db = try open(":memory:");
    defer db.close();
    try db.run("INSERT INTO players (puuid, game_name, tag_line, platform, looked_up) VALUES ('old','A','1','EUW1',10), ('new','B','1','EUW1',500)", .{});
    try db.run("INSERT INTO player_games VALUES ('old','M1',0,0), ('new','M2',0,0)", .{});
    try db.run("INSERT INTO matches VALUES ('M1',0,x'00',NULL), ('M2',0,x'00',NULL)", .{});
    try db.run("INSERT INTO accounts VALUES ('old#1','old',0), ('gone#1',NULL,0)", .{});
    try db.run("INSERT INTO blocked VALUES ('x', 0)", .{});
    try prune(db, 100, 1_000_000);
    try testing.expectEqual(@as(?i64, 1), try db.scalar("SELECT count(*) FROM players", .{}));
    try testing.expectEqual(@as(?i64, 1), try db.scalar("SELECT count(*) FROM matches WHERE match_id = 'M2'", .{}));
    try testing.expectEqual(@as(?i64, 1), try db.scalar("SELECT count(*) FROM matches", .{}));
    try testing.expectEqual(@as(?i64, 0), try db.scalar("SELECT count(*) FROM accounts", .{}));
    try testing.expectEqual(@as(?i64, 1), try db.scalar("SELECT count(*) FROM blocked", .{}));
}

const testing = std.testing;

test riotIdKey {
    var buf: [64]u8 = undefined;
    try testing.expectEqualStrings("faker#kr1", riotIdKey(&buf, " Faker ", "KR1").?);
    try testing.expectEqualStrings("hide on bush#kr1", riotIdKey(&buf, "Hide on bush", "KR1").?);
    try testing.expect(riotIdKey(&buf, "", "EUW") == null);
    try testing.expect(riotIdKey(&buf, "a/b", "EUW") == null);
    try testing.expect(riotIdKey(&buf, "name", "toolongtag") == null);
}

test "forget keeps matches other players share" {
    const db = try open(":memory:");
    defer db.close();
    try db.run("INSERT INTO players (puuid, game_name, tag_line, platform) VALUES ('a','A','1','EUW1'), ('b','B','1','EUW1')", .{});
    try db.run("INSERT INTO accounts VALUES ('a#1','a',0), ('b#1','b',0)", .{});
    try db.run("INSERT INTO player_games VALUES ('a','M1',0,0), ('a','M2',0,0), ('b','M2',0,1)", .{});
    try db.run("INSERT INTO matches VALUES ('M1',0,x'00',NULL), ('M2',0,x'00',NULL)", .{});
    var ha: [game.hash_len]u8 = undefined;
    var hb: [game.hash_len]u8 = undefined;
    try db.run("INSERT INTO match_names VALUES ('M1',0,?,'A#1'), ('M2',0,?,'A#1'), ('M2',1,?,'B#1')", .{
        game.hashPuuid(&ha, "a"), game.hashPuuid(&ha, "a"), game.hashPuuid(&hb, "b"),
    });
    try forget(db, "a", 0);
    try testing.expectEqual(@as(?i64, 1), try db.scalar("SELECT count(*) FROM match_names", .{}));
    try testing.expectEqual(@as(?i64, 1), try db.scalar("SELECT count(*) FROM match_names WHERE riot_id = 'B#1'", .{}));
    try testing.expectEqual(@as(?i64, 1), try db.scalar("SELECT count(*) FROM players", .{}));
    try testing.expectEqual(@as(?i64, 1), try db.scalar("SELECT count(*) FROM accounts", .{}));
    try testing.expectEqual(@as(?i64, 1), try db.scalar("SELECT count(*) FROM matches WHERE match_id = 'M2'", .{}));
    try testing.expectEqual(@as(?i64, 1), try db.scalar("SELECT count(*) FROM matches", .{}));
}
