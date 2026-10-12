//! Schema and connection. Same tables as the original Python crawler, so its
//! database carries straight over.

const std = @import("std");
const sqlite = @import("sqlite.zig");
const draft = @import("draft.zig");

// Tables migrate() rebuilds, so their DDL lives apart from `schema`. WITHOUT ROWID
// where the key is text: a rowid table would store the key twice (table + index).

/// PUUIDs are encrypted per app: a new key type (dev -> personal -> production) means
/// new PUUIDs for the same players (see rekey). platform is Riot's id (EUW1, KR);
/// region the match-v5 route (europe, asia). seen_at: last time a ladder page or a
/// match showed the player; the crawler drops players unseen for 30 days (Riot asks
/// for stored player data to be refreshed monthly; erased accounts stop appearing).
/// games_checked: ranked games (wins + losses) as of the player's last match id scan,
/// so the ladder shows who has played since
const players_ddl =
    \\CREATE TABLE IF NOT EXISTS players (
    \\    puuid TEXT PRIMARY KEY,
    \\    tier TEXT,
    \\    division TEXT,
    \\    lp INTEGER,
    \\    wins INTEGER,
    \\    losses INTEGER,
    \\    rank_seen_at INTEGER,
    \\    matches_checked_at INTEGER,
    \\    source TEXT NOT NULL,
    \\    platform TEXT,
    \\    region TEXT,
    \\    seen_at INTEGER,
    \\    games_checked INTEGER
    \\) WITHOUT ROWID;
    \\
;

/// slot = index in info.participants. Builds live here because raw summaries are
/// pruned: items at game end (item6 = trinket), runes (keystone = first primary perk,
/// perk1-3 primary, perk4-5 secondary, then stat shards). tier/division: the player's
/// ladder rank when the match was stored (players holds only the latest and loses
/// everyone on rekey); NULL when not on the ladder then. gold10/14/15: total gold at
/// timeline frames 10/14/15, set when the timeline is stored; NULL without one
const participants_ddl =
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
    \\    item0 INTEGER, item1 INTEGER, item2 INTEGER, item3 INTEGER,
    \\    item4 INTEGER, item5 INTEGER, item6 INTEGER,
    \\    primary_style INTEGER,
    \\    perk1 INTEGER, perk2 INTEGER, perk3 INTEGER, perk4 INTEGER, perk5 INTEGER,
    \\    shard_offense INTEGER, shard_flex INTEGER, shard_defense INTEGER,
    \\    tier TEXT, division TEXT,
    \\    gold10 INTEGER, gold14 INTEGER, gold15 INTEGER,
    \\    PRIMARY KEY (match_id, slot)
    \\) WITHOUT ROWID;
    \\
;

const bans_ddl =
    \\CREATE TABLE IF NOT EXISTS bans (
    \\    match_id TEXT NOT NULL,
    \\    team_id INTEGER NOT NULL,
    \\    pick_turn INTEGER NOT NULL,
    \\    champion_id INTEGER NOT NULL,
    \\    PRIMARY KEY (match_id, team_id, pick_turn)
    \\) WITHOUT ROWID;
    \\
;

/// One compact blob per player (riot/mastery.zig). Snapshot at fetched_at, not at
/// match time
const mastery_ddl =
    \\CREATE TABLE IF NOT EXISTS mastery (
    \\    puuid TEXT PRIMARY KEY,
    \\    platform TEXT,
    \\    fetched_at INTEGER NOT NULL,
    \\    champions INTEGER NOT NULL,
    \\    data BLOB NOT NULL
    \\);
    \\
;

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
    \\-- Raw timelines (~60 KB each), kept a few days so timelines.data can be re-extracted
    \\-- after a parser fix; the crawler prunes older ones.
    \\CREATE TABLE IF NOT EXISTS raw.timeline_docs (
    \\    match_id TEXT PRIMARY KEY,
    \\    fetched_at INTEGER NOT NULL,
    \\    body BLOB NOT NULL
    \\);
    \\
    \\-- Compact timelines (riot/timeline.zig, gzip). Own file: grows ~1 GB/day.
    \\CREATE TABLE IF NOT EXISTS timeline.timelines (
    \\    match_id TEXT PRIMARY KEY,
    \\    frames INTEGER NOT NULL,
    \\    events INTEGER NOT NULL,
    \\    data BLOB NOT NULL
    \\);
    \\
++ players_ddl ++
    \\
    \\CREATE TABLE IF NOT EXISTS ladder_pages (
    \\    platform TEXT NOT NULL,
    \\    tier TEXT NOT NULL,
    \\    division TEXT NOT NULL,
    \\    page INTEGER NOT NULL,
    \\    entries INTEGER NOT NULL,
    \\    fetched_at INTEGER NOT NULL,
    \\    PRIMARY KEY (platform, tier, division, page)
    \\) WITHOUT ROWID;
    \\
    \\CREATE TABLE IF NOT EXISTS match_queue (
    \\    match_id TEXT PRIMARY KEY,
    \\    status TEXT NOT NULL DEFAULT 'pending',
    \\    attempts INTEGER NOT NULL DEFAULT 0,
    \\    discovered_at INTEGER NOT NULL,
    \\    region TEXT NOT NULL DEFAULT 'europe'
    \\) WITHOUT ROWID;
    \\
    \\CREATE TABLE IF NOT EXISTS timeline_queue (
    \\    match_id TEXT PRIMARY KEY,
    \\    region TEXT NOT NULL,
    \\    status TEXT NOT NULL DEFAULT 'pending',
    \\    attempts INTEGER NOT NULL DEFAULT 0,
    \\    queued_at INTEGER NOT NULL
    \\) WITHOUT ROWID;
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
++ participants_ddl ++ bans_ddl ++ mastery_ddl ++
    \\
    \\CREATE TABLE IF NOT EXISTS champions (
    \\    id INTEGER PRIMARY KEY,
    \\    key TEXT NOT NULL,
    \\    name TEXT NOT NULL,
    \\    tags TEXT,
    \\    ddragon_version TEXT NOT NULL
    \\);
    \\
++ forgotten_ddl ++ ranks_ddl;

/// Ladder rank of every ranked player, for participants' rank snapshot: 8 bytes of
/// PUUID hash (puuidKey) instead of the PUUID, so millions of players fit in a few
/// hundred MB that stay in the page cache. players holds full rows only for the
/// sampled scan pool. rank = packRank; seen_day = unix day of the last ladder page
/// showing the player (gone after 30 days, as players). lp, wins and losses as last
/// seen, so the writer can tell a change for rank_history (NULL in rows from before)
const ranks_ddl =
    \\CREATE TABLE IF NOT EXISTS ranks (
    \\    key INTEGER PRIMARY KEY,
    \\    rank INTEGER NOT NULL,
    \\    seen_day INTEGER NOT NULL,
    \\    lp INTEGER,
    \\    wins INTEGER,
    \\    losses INTEGER
    \\);
    \\
++ rank_history_ddl;

/// Ladder rank over time: a row when a ladder page shows a player (puuidKey) with a
/// rank, LP or game count other than ranks held, so the day of each change. Kept 24
/// months after the player's last row once ranks no longer lists them. Key first:
/// lookups and forget are by player; ~2.5 changed rows/s land as random writes
const rank_history_ddl =
    \\CREATE TABLE IF NOT EXISTS rank_history (
    \\    key INTEGER NOT NULL,
    \\    day INTEGER NOT NULL,
    \\    rank INTEGER NOT NULL,
    \\    lp INTEGER NOT NULL,
    \\    wins INTEGER NOT NULL,
    \\    losses INTEGER NOT NULL,
    \\    PRIMARY KEY (key, day)
    \\) WITHOUT ROWID;
    \\
;

pub fn puuidKey(puuid: []const u8) i64 {
    return @bitCast(std.hash.Wyhash.hash(0, puuid));
}

/// Ranked tiers, highest first, and divisions, as the ladder names them
pub const tiers = [_][]const u8{
    "CHALLENGER", "GRANDMASTER", "MASTER", "DIAMOND", "EMERALD",
    "PLATINUM",   "GOLD",        "SILVER", "BRONZE",  "IRON",
};
pub const divisions = [_][]const u8{ "I", "II", "III", "IV" };

pub fn packRank(tier: []const u8, division: []const u8) ?i64 {
    const t = indexOf(&tiers, tier) orelse return null;
    const d = indexOf(&divisions, division) orelse return null;
    return @intCast(t * divisions.len + d);
}

pub const Rank = struct { tier: []const u8, division: []const u8 };

pub fn unpackRank(rank: i64) ?Rank {
    if (rank < 0 or rank >= tiers.len * divisions.len) return null;
    const r: usize = @intCast(rank);
    return .{ .tier = tiers[r / divisions.len], .division = divisions[r % divisions.len] };
}

fn indexOf(names: []const []const u8, name: []const u8) ?usize {
    for (names, 0..) |n, i| if (std.mem.eql(u8, n, name)) return i;
    return null;
}

/// Suppression list of players who asked to be forgotten (`meiolol forget`,
/// src/forget.zig): the crawler never stores them again. Plain PUUIDs, not hashes: a
/// rekey must translate them, and the Your games service exchanges the list
const forgotten_ddl =
    \\CREATE TABLE IF NOT EXISTS forgotten (
    \\    puuid TEXT PRIMARY KEY,
    \\    forgotten_at INTEGER NOT NULL
    \\) WITHOUT ROWID;
    \\
;

/// After migrate: they may name columns older databases lack
const indexes =
    \\CREATE INDEX IF NOT EXISTS players_region_check
    \\    ON players (region, matches_checked_at, puuid);
    \\CREATE INDEX IF NOT EXISTS match_queue_region
    \\    ON match_queue (region, status, discovered_at, match_id);
    \\CREATE INDEX IF NOT EXISTS timeline_queue_region
    \\    ON timeline_queue (region, status, queued_at, match_id);
    \\CREATE INDEX IF NOT EXISTS raw.timeline_docs_age ON timeline_docs (fetched_at);
    \\CREATE INDEX IF NOT EXISTS raw.raw_docs_age ON raw_docs (source, fetched_at);
    \\CREATE INDEX IF NOT EXISTS participants_puuid ON participants (puuid);
    \\CREATE INDEX IF NOT EXISTS players_seen ON players (seen_at);
    \\CREATE INDEX IF NOT EXISTS players_new_games
    \\    ON players (region, wins + losses - games_checked) WHERE games_checked IS NOT NULL;
    \\CREATE INDEX IF NOT EXISTS mastery_age ON mastery (fetched_at);
    \\CREATE INDEX IF NOT EXISTS matches_start ON matches (game_start);
;

/// Open meiolol.db with raw.db and timeline.db attached as `raw` and `timeline`, all
/// in `dir`. One connection per thread.
pub fn open(gpa: std.mem.Allocator, dir: []const u8) !sqlite.Db {
    const db = try connect(gpa, dir);
    errdefer db.close();
    try apply(db);
    return db;
}

/// As open, without creating or migrating anything, for extra connections of a process
/// that already ran open once (crawler workers): a migration holds the write lock, and
/// 19 connections each waiting on it outlast the busy timeout on a slow machine
pub fn connect(gpa: std.mem.Allocator, dir: []const u8) !sqlite.Db {
    const main_path = try std.fs.path.joinZ(gpa, &.{ dir, "meiolol.db" });
    defer gpa.free(main_path);
    const db = try sqlite.Db.open(main_path);
    errdefer db.close();
    try attach(gpa, db, dir);
    try db.exec(
        \\PRAGMA main.journal_mode=WAL;
        \\PRAGMA raw.journal_mode=WAL;
        \\PRAGMA timeline.journal_mode=WAL;
        \\PRAGMA main.synchronous=NORMAL;
        \\PRAGMA raw.synchronous=NORMAL;
        \\PRAGMA timeline.synchronous=NORMAL;
    );
    return db;
}

/// As connect, read-only (raw and timeline too) and without the WAL pragmas: never
/// takes the write lock, so it neither waits on nor stalls the crawler's writer. Expects
/// an existing database with a current schema
pub fn openReadOnly(gpa: std.mem.Allocator, dir: []const u8) !sqlite.Db {
    const main_path = try std.fs.path.joinZ(gpa, &.{ dir, "meiolol.db" });
    defer gpa.free(main_path);
    const db = try sqlite.Db.openReadOnly(main_path);
    errdefer db.close();
    try attach(gpa, db, dir);
    // Sorts (GROUP BY without an index) in memory: no temp files on the box's disk
    try db.exec("PRAGMA query_only=ON; PRAGMA temp_store=MEMORY");
    return db;
}

fn attach(gpa: std.mem.Allocator, db: sqlite.Db, dir: []const u8) !void {
    const raw_path = try std.fs.path.join(gpa, &.{ dir, "raw.db" });
    defer gpa.free(raw_path);
    const timeline_path = try std.fs.path.join(gpa, &.{ dir, "timeline.db" });
    defer gpa.free(timeline_path);
    try db.run("ATTACH DATABASE ? AS raw", .{raw_path});
    try db.run("ATTACH DATABASE ? AS timeline", .{timeline_path});
}

/// Empty in-memory database with every table, for tests
pub fn memory() !sqlite.Db {
    const db = try sqlite.Db.open(":memory:");
    errdefer db.close();
    try db.exec("ATTACH DATABASE ':memory:' AS raw; ATTACH DATABASE ':memory:' AS timeline");
    try apply(db);
    return db;
}

pub fn apply(db: sqlite.Db) !void {
    try db.exec(schema);
    try migrate(db);
    try db.exec(indexes);
}

/// Databases from before multi-region crawling held EUW only. Idempotent, and safe
/// when several connections open at once: the checks run inside the write lock.
fn migrate(db: sqlite.Db) !void {
    try db.begin();
    errdefer db.rollback();
    if (!try hasColumn(db, "players", "region")) {
        try db.exec(
            \\ALTER TABLE players ADD COLUMN platform TEXT;
            \\ALTER TABLE players ADD COLUMN region TEXT;
            \\UPDATE players SET platform = 'EUW1', region = 'europe';
            \\DROP INDEX IF EXISTS players_check;
        );
    }
    if (!try hasColumn(db, "match_queue", "region")) {
        try db.exec(
            \\ALTER TABLE match_queue ADD COLUMN region TEXT NOT NULL DEFAULT 'europe';
            \\DROP INDEX IF EXISTS match_queue_status;
        );
    }
    if (!try hasColumn(db, "ladder_pages", "platform")) {
        try db.exec(
            \\ALTER TABLE ladder_pages RENAME TO ladder_pages_euw;
            \\CREATE TABLE ladder_pages (
            \\    platform TEXT NOT NULL,
            \\    tier TEXT NOT NULL,
            \\    division TEXT NOT NULL,
            \\    page INTEGER NOT NULL,
            \\    entries INTEGER NOT NULL,
            \\    fetched_at INTEGER NOT NULL,
            \\    PRIMARY KEY (platform, tier, division, page)
            \\) WITHOUT ROWID;
            \\INSERT INTO ladder_pages
            \\    SELECT 'EUW1', tier, division, page, entries, fetched_at FROM ladder_pages_euw;
            \\DROP TABLE ladder_pages_euw;
        );
    }
    if (!try hasColumn(db, "participants", "item0")) {
        // Rebuilt rather than altered to drop their rowids; `meiolol rebuild` fills
        // the new columns from raw summaries
        try db.exec("ALTER TABLE participants RENAME TO participants_v1;" ++
            "ALTER TABLE bans RENAME TO bans_v1;" ++ participants_ddl ++ bans_ddl ++
            \\INSERT INTO participants (match_id, slot, team_id, puuid, champion_id, position,
            \\    individual_position, win, kills, deaths, assists, gold, damage_to_champions,
            \\    damage_taken, vision_score, cs, champ_level, summoner1, summoner2, keystone,
            \\    secondary_style)
            \\SELECT match_id, slot, team_id, puuid, champion_id, position, individual_position,
            \\    win, kills, deaths, assists, gold, damage_to_champions, damage_taken,
            \\    vision_score, cs, champ_level, summoner1, summoner2, keystone, secondary_style
            \\FROM participants_v1;
            \\INSERT INTO bans SELECT * FROM bans_v1;
            \\DROP TABLE participants_v1;
            \\DROP TABLE bans_v1;
        );
    }
    if (!try hasColumn(db, "mastery", "data")) {
        // Row-per-champion form, never filled on the box (ladder still seeding); its raw
        // documents go too. Take a backup before the first run anyway
        try db.exec("DROP TABLE mastery; DELETE FROM raw.raw_docs WHERE source = 'riot_mastery';" ++
            mastery_ddl);
    }
    if (!try hasColumn(db, "players", "seen_at")) {
        // Counts as seen now, so existing players get the full 30 days. A constant
        // default rather than an UPDATE: adding it rewrites no rows (millions of players)
        const now = try db.scalar("SELECT unixepoch()", .{}) orelse 0;
        var buf: [96]u8 = undefined;
        try db.exec(try std.mem.printSentinel(&buf, "ALTER TABLE players ADD COLUMN seen_at INTEGER DEFAULT {d}", .{now}, 0));
    }
    if (!try hasColumn(db, "players", "games_checked")) {
        // NULL until the ladder next changes a row, which sets it from the old counts
        try db.exec("ALTER TABLE players ADD COLUMN games_checked INTEGER");
    }
    if (try hasColumn(db, "forgotten", "puuid_sha256")) {
        // Hashed form never held rows: `meiolol forget` was not deployed with it
        try db.exec("DROP TABLE forgotten;" ++ forgotten_ddl);
    }
    if (!try hasColumn(db, "participants", "gold10")) {
        try db.exec(
            \\ALTER TABLE participants ADD COLUMN gold10 INTEGER;
            \\ALTER TABLE participants ADD COLUMN gold14 INTEGER;
            \\ALTER TABLE participants ADD COLUMN gold15 INTEGER;
        );
    }
    if (!try hasColumn(db, "ranks", "lp")) {
        // Schema only, no row rewrite: each player's first sighting after this writes
        // their first rank_history row
        try db.exec(
            \\ALTER TABLE ranks ADD COLUMN lp INTEGER;
            \\ALTER TABLE ranks ADD COLUMN wins INTEGER;
            \\ALTER TABLE ranks ADD COLUMN losses INTEGER;
        );
    }
    if (!try hasColumn(db, "drafts", "id")) {
        // Every match stored so far awaits `meiolol draft-backfill`; from now on the
        // writer adds each new match's row. In key order: appends to the list's B-tree
        try db.exec(draft.ddl ++ "INSERT INTO draft_backfill SELECT match_id FROM matches ORDER BY match_id;");
    }
    if (!try hasColumn(db, "drafts", "minutes")) {
        // Added hours after drafts went live. Their matches are all still stored (the
        // table is younger than any --keep-days window), so the rows go back on the
        // backfill list, which writes them again with a length. If there are fewer
        // unlisted matches than rows, some are gone: keep the rows, length NULL
        try db.exec("ALTER TABLE drafts ADD COLUMN minutes INTEGER");
        const rows = try db.scalar("SELECT count(*) FROM drafts", .{}) orelse 0;
        const unlisted = try db.scalar(
            "SELECT count(*) FROM matches WHERE match_id NOT IN draft_backfill",
            .{},
        ) orelse 0;
        if (rows <= unlisted) try db.exec(
            \\DELETE FROM drafts;
            \\INSERT OR IGNORE INTO draft_backfill SELECT match_id FROM matches ORDER BY match_id;
        );
    }
    try db.commit();
}

/// For a new app's key (dev -> personal -> production): PUUIDs change, so forget
/// players, ladder pages and mastery (re-seeded from the ladders) and blank old
/// PUUIDs in participants, keeping their rank in participants.tier. Matches, timelines and queues are keyed by match id and
/// stay. Run `meiolol rebuild` before, not after: it restores PUUIDs from raw.
pub fn rekey(db: sqlite.Db) !void {
    try db.begin();
    errdefer db.rollback();
    try rekeyRows(db);
    try db.commit();
    try apply(db);
}

/// rekey inside the caller's transaction (rekey.zig carries `forgotten` over in the same
/// one); run apply after the commit, to recreate the dropped tables
pub fn rekeyRows(db: sqlite.Db) !void {
    try db.exec(
        \\UPDATE participants SET (tier, division) =
        \\    (SELECT tier, division FROM players p WHERE p.puuid = participants.puuid)
        \\WHERE tier IS NULL;
    ++ "DROP TABLE players; DROP TABLE ladder_pages; DROP TABLE mastery; DELETE FROM ranks;" ++
        "UPDATE participants SET puuid = NULL;" ++
        "DELETE FROM raw.raw_docs WHERE source = 'riot_mastery';");
}

fn hasColumn(db: sqlite.Db, table: []const u8, column: []const u8) !bool {
    const n = try db.scalar("SELECT count(*) FROM pragma_table_info(?) WHERE name = ?", .{
        table, column,
    });
    return (n orelse 0) > 0;
}

test "ranks pack and unpack" {
    try std.testing.expectEqual(@as(?i64, 0), packRank("CHALLENGER", "I"));
    try std.testing.expectEqual(@as(?i64, null), packRank("UNRANKED", "I"));
    const r = unpackRank(packRank("GOLD", "III").?).?;
    try std.testing.expectEqualStrings("GOLD", r.tier);
    try std.testing.expectEqualStrings("III", r.division);
    try std.testing.expectEqual(@as(?Rank, null), unpackRank(40));
}

test "schema applies twice" {
    const db = try memory();
    defer db.close();
    try apply(db);
}

test "migrates an EUW-only database" {
    const db = try sqlite.Db.open(":memory:");
    defer db.close();
    try db.exec(
        \\ATTACH DATABASE ':memory:' AS raw; ATTACH DATABASE ':memory:' AS timeline;
        \\CREATE TABLE players (puuid TEXT PRIMARY KEY, tier TEXT, division TEXT, lp INTEGER,
        \\    wins INTEGER, losses INTEGER, rank_seen_at INTEGER, matches_checked_at INTEGER,
        \\    source TEXT NOT NULL);
        \\CREATE INDEX players_check ON players (matches_checked_at);
        \\CREATE TABLE ladder_pages (tier TEXT NOT NULL, division TEXT NOT NULL,
        \\    page INTEGER NOT NULL, entries INTEGER NOT NULL, fetched_at INTEGER NOT NULL,
        \\    PRIMARY KEY (tier, division, page)) WITHOUT ROWID;
        \\CREATE TABLE match_queue (match_id TEXT PRIMARY KEY,
        \\    status TEXT NOT NULL DEFAULT 'pending', attempts INTEGER NOT NULL DEFAULT 0,
        \\    discovered_at INTEGER NOT NULL) WITHOUT ROWID;
        \\CREATE TABLE participants (match_id TEXT NOT NULL, slot INTEGER NOT NULL,
        \\    team_id INTEGER NOT NULL, puuid TEXT, champion_id INTEGER NOT NULL, position TEXT,
        \\    individual_position TEXT, win INTEGER NOT NULL, kills INTEGER, deaths INTEGER,
        \\    assists INTEGER, gold INTEGER, damage_to_champions INTEGER, damage_taken INTEGER,
        \\    vision_score INTEGER, cs INTEGER, champ_level INTEGER, summoner1 INTEGER,
        \\    summoner2 INTEGER, keystone INTEGER, secondary_style INTEGER,
        \\    PRIMARY KEY (match_id, slot));
        \\CREATE INDEX participants_puuid ON participants (puuid);
        \\CREATE TABLE bans (match_id TEXT NOT NULL, team_id INTEGER NOT NULL,
        \\    pick_turn INTEGER NOT NULL, champion_id INTEGER NOT NULL,
        \\    PRIMARY KEY (match_id, team_id, pick_turn));
        \\CREATE TABLE mastery (puuid TEXT NOT NULL, champion_id INTEGER NOT NULL,
        \\    level INTEGER, points INTEGER, last_play_time INTEGER,
        \\    fetched_at INTEGER NOT NULL, PRIMARY KEY (puuid, champion_id));
        \\INSERT INTO players (puuid, source) VALUES ('p1', 'ladder');
        \\INSERT INTO ladder_pages VALUES ('GOLD', 'I', 1, 205, 9);
        \\INSERT INTO match_queue (match_id, discovered_at) VALUES ('EUW1_1', 9);
        \\INSERT INTO participants (match_id, slot, team_id, puuid, champion_id, win, keystone)
        \\    VALUES ('EUW1_1', 0, 100, 'p1', 266, 1, 8010);
        \\INSERT INTO bans VALUES ('EUW1_1', 100, 1, 157);
    );
    try apply(db);
    try apply(db);
    const t = std.testing;
    const one: ?i64 = 1;
    try t.expectEqual(@as(?i64, 8010), try db.scalar(
        "SELECT keystone FROM participants WHERE puuid = 'p1' AND item0 IS NULL",
        .{},
    ));
    try t.expectEqual(@as(?i64, 157), try db.scalar("SELECT champion_id FROM bans", .{}));
    try t.expect(try hasColumn(db, "mastery", "data"));
    try t.expectEqual(one, try db.scalar(
        "SELECT count(*) FROM players " ++
            "WHERE region = 'europe' AND platform = 'EUW1' AND seen_at > 0",
        .{},
    ));
    try t.expectEqual(@as(?i64, 205), try db.scalar(
        "SELECT entries FROM ladder_pages WHERE platform = 'EUW1'",
        .{},
    ));
    try t.expectEqual(one, try db.scalar(
        "SELECT count(*) FROM match_queue WHERE region = 'europe'",
        .{},
    ));
    try t.expectEqual(@as(?i64, 0), try db.scalar(
        "SELECT count(*) FROM sqlite_master WHERE name = 'players_check'",
        .{},
    ));
}

test "rekey keeps matches, forgets players" {
    const db = try memory();
    defer db.close();
    try db.exec(
        \\INSERT INTO players (puuid, tier, division, source) VALUES ('old', 'GOLD', 'II', 'ladder');
        \\INSERT INTO match_queue (match_id, discovered_at) VALUES ('EUW1_1', 9);
        \\INSERT INTO participants (match_id, slot, team_id, puuid, champion_id, win)
        \\    VALUES ('EUW1_1', 0, 100, 'old', 266, 1);
    );
    try rekey(db);
    const t = std.testing;
    try t.expectEqual(@as(?i64, 0), try db.scalar("SELECT count(*) FROM players", .{}));
    try t.expectEqual(@as(?i64, 1), try db.scalar("SELECT count(*) FROM match_queue", .{}));
    try t.expectEqual(@as(?i64, 1), try db.scalar(
        "SELECT count(*) FROM participants WHERE puuid IS NULL AND tier = 'GOLD'",
        .{},
    ));
}

test "drafts: a database from before them lists its matches for the backfill" {
    const db = try memory();
    defer db.close();
    try db.exec(
        \\DROP TABLE drafts; DROP TABLE draft_backfill;
        \\INSERT INTO matches VALUES ('EUW1_2', 'riot', 'EUW1', 420, '16.1', '16.1.1', 1, 1, 100, 0);
        \\INSERT INTO matches VALUES ('EUW1_1', 'riot', 'EUW1', 420, '16.1', '16.1.1', 1, 1, 100, 0);
    );
    try apply(db);
    try db.exec("INSERT INTO matches VALUES ('EUW1_3', 'riot', 'EUW1', 420, '16.1', '16.1.1', 1, 1, 100, 0)");
    // Once only: a later open lists nothing new
    try apply(db);
    try std.testing.expectEqual(@as(?i64, 2), try db.scalar("SELECT count(*) FROM draft_backfill", .{}));
    try std.testing.expectEqual(@as(?i64, 0), try db.scalar("SELECT count(*) FROM drafts", .{}));
}

test "drafts: rows from before minutes go back on the backfill list" {
    const db = try memory();
    defer db.close();
    try db.exec(
        \\DROP TABLE drafts;
        \\CREATE TABLE drafts (id INTEGER PRIMARY KEY, platform TEXT NOT NULL,
        \\    queue INTEGER NOT NULL, patch TEXT NOT NULL, day INTEGER NOT NULL, rank INTEGER,
        \\    ranked INTEGER NOT NULL, blue_win INTEGER NOT NULL, picks BLOB NOT NULL,
        \\    bans BLOB NOT NULL);
        \\INSERT INTO matches VALUES ('EUW1_1', 'riot', 'EUW1', 420, '16.1', '16.1.1', 1, 1, 100, 0);
        \\INSERT INTO matches VALUES ('EUW1_2', 'riot', 'EUW1', 420, '16.1', '16.1.1', 1, 1, 100, 0);
        \\INSERT INTO draft_backfill VALUES ('EUW1_1');
        \\INSERT INTO drafts (platform, queue, patch, day, ranked, blue_win, picks, bans)
        \\    VALUES ('EUW1', 420, '16.1', 0, 0, 1, x'', x'');
    );
    try apply(db);
    try apply(db);
    try std.testing.expectEqual(@as(?i64, 0), try db.scalar("SELECT count(*) FROM drafts", .{}));
    try std.testing.expectEqual(@as(?i64, 2), try db.scalar("SELECT count(*) FROM draft_backfill", .{}));
    try std.testing.expect(try hasColumn(db, "drafts", "minutes"));
}

test "openReadOnly: every schema read-only, data visible" {
    const testing = std.testing;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir = try testing.allocator.print(".zig-cache/tmp/{s}", .{&tmp.sub_path});
    defer testing.allocator.free(dir);
    {
        const db = try open(testing.allocator, dir);
        defer db.close();
        try db.exec("INSERT INTO champions VALUES (1, 'Annie', 'Annie', NULL, '1')");
    }
    const db = try openReadOnly(testing.allocator, dir);
    defer db.close();
    for ([_][:0]const u8{ "main", "raw", "timeline" }) |name| {
        try testing.expectEqual(1, sqlite.c.sqlite3_db_readonly(db.handle, name));
    }
    try testing.expectEqual(@as(?i64, 1), try db.scalar("SELECT count(*) FROM champions", .{}));
}
