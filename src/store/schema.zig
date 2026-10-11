//! Schema and connection. Same tables as the original Python crawler, so its
//! database carries straight over.

const std = @import("std");
const sqlite = @import("sqlite.zig");

pub const schema =
    \\-- Every document fetched as compressed JSON (see raw.zig), so normalised tables
    \\-- can be rebuilt when parsing changes without refetching. Own file: most bytes.
    \\CREATE TABLE IF NOT EXISTS raw.raw_docs (
    \\    source TEXT NOT NULL,
    \\    key TEXT NOT NULL,
    \\    fetched_at INTEGER NOT NULL,
    \\    body BLOB NOT NULL,
    \\    PRIMARY KEY (source, key)
    \\) WITHOUT ROWID;
    \\
    \\-- PUUIDs are encrypted per API key: a new key means new PUUIDs for the same players.
    \\CREATE TABLE IF NOT EXISTS players (
    \\    puuid TEXT PRIMARY KEY,
    \\    tier TEXT,
    \\    division TEXT,
    \\    lp INTEGER,
    \\    wins INTEGER,
    \\    losses INTEGER,
    \\    rank_seen_at INTEGER,
    \\    matches_checked_at INTEGER,
    \\    source TEXT NOT NULL
    \\);
    \\CREATE INDEX IF NOT EXISTS players_check ON players (matches_checked_at);
    \\
    \\CREATE TABLE IF NOT EXISTS ladder_pages (
    \\    tier TEXT NOT NULL,
    \\    division TEXT NOT NULL,
    \\    page INTEGER NOT NULL,
    \\    entries INTEGER NOT NULL,
    \\    fetched_at INTEGER NOT NULL,
    \\    PRIMARY KEY (tier, division, page)
    \\) WITHOUT ROWID;
    \\
    \\CREATE TABLE IF NOT EXISTS match_queue (
    \\    match_id TEXT PRIMARY KEY,
    \\    status TEXT NOT NULL DEFAULT 'pending',
    \\    attempts INTEGER NOT NULL DEFAULT 0,
    \\    discovered_at INTEGER NOT NULL
    \\) WITHOUT ROWID;
    \\CREATE INDEX IF NOT EXISTS match_queue_status ON match_queue (status, match_id);
    \\
    \\CREATE TABLE IF NOT EXISTS matches (
    \\    match_id TEXT PRIMARY KEY,
    \\    source TEXT NOT NULL,
    \\    platform TEXT NOT NULL,
    \\    queue_id INTEGER NOT NULL,
    \\    patch TEXT NOT NULL,
    \\    game_version TEXT NOT NULL,
    \\    game_start INTEGER NOT NULL,
    \\    duration_s INTEGER NOT NULL,
    \\    winning_team INTEGER,
    \\    remake INTEGER NOT NULL
    \\);
    \\CREATE INDEX IF NOT EXISTS matches_patch ON matches (patch);
    \\
    \\-- slot = index in info.participants
    \\CREATE TABLE IF NOT EXISTS participants (
    \\    match_id TEXT NOT NULL,
    \\    slot INTEGER NOT NULL,
    \\    team_id INTEGER NOT NULL,
    \\    puuid TEXT,
    \\    champion_id INTEGER NOT NULL,
    \\    position TEXT,
    \\    individual_position TEXT,
    \\    win INTEGER NOT NULL,
    \\    kills INTEGER, deaths INTEGER, assists INTEGER,
    \\    gold INTEGER,
    \\    damage_to_champions INTEGER,
    \\    damage_taken INTEGER,
    \\    vision_score INTEGER,
    \\    cs INTEGER,
    \\    champ_level INTEGER,
    \\    summoner1 INTEGER, summoner2 INTEGER,
    \\    keystone INTEGER,
    \\    secondary_style INTEGER,
    \\    PRIMARY KEY (match_id, slot)
    \\);
    \\CREATE INDEX IF NOT EXISTS participants_puuid ON participants (puuid);
    \\
    \\CREATE TABLE IF NOT EXISTS bans (
    \\    match_id TEXT NOT NULL,
    \\    team_id INTEGER NOT NULL,
    \\    pick_turn INTEGER NOT NULL,
    \\    champion_id INTEGER NOT NULL,
    \\    PRIMARY KEY (match_id, team_id, pick_turn)
    \\);
    \\
    \\-- Snapshot at fetched_at, not at match time
    \\CREATE TABLE IF NOT EXISTS mastery (
    \\    puuid TEXT NOT NULL,
    \\    champion_id INTEGER NOT NULL,
    \\    level INTEGER,
    \\    points INTEGER,
    \\    last_play_time INTEGER,
    \\    fetched_at INTEGER NOT NULL,
    \\    PRIMARY KEY (puuid, champion_id)
    \\);
    \\
    \\CREATE TABLE IF NOT EXISTS champions (
    \\    id INTEGER PRIMARY KEY,
    \\    key TEXT NOT NULL,
    \\    name TEXT NOT NULL,
    \\    tags TEXT,
    \\    ddragon_version TEXT NOT NULL
    \\);
;

/// Open meiolol.db with raw.db attached as `raw`. Paths are `dir`/meiolol.db and
/// `dir`/raw.db. One connection per thread.
pub fn open(gpa: std.mem.Allocator, dir: []const u8) !sqlite.Db {
    const main_path = try std.fs.path.joinZ(gpa, &.{ dir, "meiolol.db" });
    defer gpa.free(main_path);
    const raw_path = try std.fs.path.join(gpa, &.{ dir, "raw.db" });
    defer gpa.free(raw_path);

    const db = try sqlite.Db.open(main_path);
    errdefer db.close();
    try db.run("ATTACH DATABASE ? AS raw", .{raw_path});
    try db.exec(
        \\PRAGMA main.journal_mode=WAL;
        \\PRAGMA raw.journal_mode=WAL;
        \\PRAGMA main.synchronous=NORMAL;
        \\PRAGMA raw.synchronous=NORMAL;
    );
    try db.exec(schema);
    return db;
}

test "schema applies twice" {
    const db = try sqlite.Db.open(":memory:");
    defer db.close();
    try db.exec("ATTACH DATABASE ':memory:' AS raw");
    try db.exec(schema);
    try db.exec(schema);
}
