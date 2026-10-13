//! Raw archive, box side (`meiolol raw-export`; docs/data-safety.md "Raw archive"). The
//! gpu-box keeps every raw document; the box only buffers them.
//!
//! An export writes the raw summaries, raw timelines and mastery snapshots fetched since
//! the previous export into one SQLite file, as stored: gzip bodies, real ids. The salt
//! never comes to the box, so pseudonymising happens on the gpu-box (src/lab/archive.zig)
//! before anything is archived. An ack deletes the export file and lets the box drop raw
//! documents that are both acked and `keep_days` old. Unacked documents stay whatever
//! their age, so a PC that is off for days loses nothing while the box has disk: once
//! an export exists the crawler's own raw pruning (--raw-*-days) stops at the acked
//! point too (writer.zig).

const std = @import("std");
const store = @import("store");
const Io = std.Io;
const log = std.log.scoped(.archive);

/// In raw.db. from_s/to_s: fetched_at range [from_s, to_s) in unix seconds
const ddl =
    \\CREATE TABLE IF NOT EXISTS raw.archive_exports (
    \\    name TEXT PRIMARY KEY,
    \\    from_s INTEGER NOT NULL,
    \\    to_s INTEGER NOT NULL,
    \\    summaries INTEGER NOT NULL,
    \\    timelines INTEGER NOT NULL,
    \\    mastery INTEGER NOT NULL,
    \\    made_at INTEGER NOT NULL,
    \\    acked_at INTEGER
    \\);
;

/// The crawler's writer stamps raw documents and mastery with the time it began the
/// transaction that stores them (writer.zig), so a document still uncommitted when an
/// export reads has a stamp at most one transaction old: this margin keeps it for the
/// next export
const settle_s = 300;

pub const Export = struct { name: []const u8, summaries: i64, timelines: i64, mastery: i64 };

/// Writes DIR/raw-FROM-TO.db with everything fetched since the last export; null when
/// nothing new. The name is in `arena`. `now_s` must be read before the call: each copy
/// then sees everything committed by then
pub fn exportNew(arena: std.mem.Allocator, io: Io, db: store.Db, dir: []const u8, now_s: i64) !?Export {
    try db.exec(ddl);
    try Io.Dir.cwd().createDirPath(io, dir);
    try cleanUp(arena, io, db, dir);
    const from = try int(db, "SELECT coalesce(max(to_s), 0) FROM raw.archive_exports", .{});
    const to = now_s - settle_s;
    if (to <= from) return null;
    const name = try std.fmt.allocPrint(arena, "raw-{d}-{d}.db", .{ from, to });
    const tmp = try std.fmt.allocPrintSentinel(arena, "{s}/{s}.tmp", .{ dir, name }, 0);
    errdefer Io.Dir.cwd().deleteFile(io, tmp) catch {};

    const counts = try copy(db, tmp, from, to);
    // Recorded before the file takes its name, so every listed file has its row; a crash
    // between the two leaves a row with no file, which cleanUp undoes
    try db.run("INSERT INTO raw.archive_exports VALUES (?,?,?,?,?,?,?,NULL)", .{
        name, from, to, counts.summaries, counts.timelines, counts.mastery, now_s,
    });
    const path = try std.fmt.allocPrintSentinel(arena, "{s}/{s}", .{ dir, name }, 0);
    Io.Dir.cwd().rename(tmp, Io.Dir.cwd(), path, io) catch |err| {
        db.run("DELETE FROM raw.archive_exports WHERE name = ?", .{name}) catch {};
        return err;
    };
    return .{ .name = name, .summaries = counts.summaries, .timelines = counts.timelines, .mastery = counts.mastery };
}

const Counts = struct { summaries: i64, timelines: i64, mastery: i64 };

fn copy(db: store.Db, tmp: [:0]const u8, from: i64, to: i64) !Counts {
    try db.run("ATTACH ? AS seg", .{tmp});
    defer db.exec("DETACH seg") catch {};
    try db.exec(
        \\CREATE TABLE seg.raw_docs (key TEXT NOT NULL, fetched_at INTEGER NOT NULL, body BLOB NOT NULL);
        \\CREATE TABLE seg.timeline_docs (match_id TEXT NOT NULL, fetched_at INTEGER NOT NULL, body BLOB NOT NULL);
        \\CREATE TABLE seg.mastery (puuid TEXT NOT NULL, platform TEXT, fetched_at INTEGER NOT NULL,
        \\    champions INTEGER NOT NULL, data BLOB NOT NULL);
        \\PRAGMA seg.journal_mode = OFF;
        \\PRAGMA seg.synchronous = FULL;
    );
    // No transaction around the copies: each statement reads its own WAL snapshot (the
    // windows need no consistency across tables) and writes only seg, so the crawler's
    // writer never waits. A BEGIN IMMEDIATE here held its write lock for the whole copy,
    // minutes for a day's catch-up
    try db.run(
        \\INSERT INTO seg.raw_docs SELECT key, fetched_at, body FROM raw.raw_docs
        \\WHERE source = 'riot_match' AND fetched_at >= ? AND fetched_at < ?
    , .{ from, to });
    const summaries = db.changes();
    try db.run(
        \\INSERT INTO seg.timeline_docs SELECT match_id, fetched_at, body FROM raw.timeline_docs
        \\WHERE fetched_at >= ? AND fetched_at < ?
    , .{ from, to });
    const timelines = db.changes();
    try db.run(
        \\INSERT INTO seg.mastery SELECT puuid, platform, fetched_at, champions, data FROM mastery
        \\WHERE fetched_at >= ? AND fetched_at < ?
    , .{ from, to });
    return .{ .summaries = summaries, .timelines = timelines, .mastery = db.changes() };
}

/// Before an export: partial files of failed ones go (each run names its own, so none
/// would be overwritten), and so does the newest export's row if its file never got its
/// name, so its window is exported again. An older unacked row without a file is left
/// alone: its documents are not archived, and dropping the row would let them be pruned
fn cleanUp(arena: std.mem.Allocator, io: Io, db: store.Db, dir_path: []const u8) !void {
    var dir = try Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true });
    defer dir.close(io);
    var stale: std.ArrayList([]const u8) = .empty;
    var it = dir.iterate();
    while (try it.next(io)) |e| {
        if (e.kind == .file and std.mem.startsWith(u8, e.name, "raw-") and std.mem.endsWith(u8, e.name, ".db.tmp")) {
            try stale.append(arena, try arena.dupe(u8, e.name));
        }
    }
    for (stale.items) |name| {
        log.info("deleting {s}, left by a failed export", .{name});
        try dir.deleteFile(io, name);
    }

    var s = try db.prepare(
        \\SELECT name FROM raw.archive_exports WHERE acked_at IS NULL
        \\ORDER BY to_s DESC LIMIT 1
    );
    defer s.deinit();
    if (!try s.step()) return;
    const newest = try arena.dupe(u8, s.bytes(0));
    s.reset();
    if (dir.access(io, newest, .{})) |_| return else |err| if (err != error.FileNotFound) return err;
    log.info("export {s} has no file: exporting its window again", .{newest});
    try db.run("DELETE FROM raw.archive_exports WHERE name = ?", .{newest});
}

pub const Pruned = struct { summaries: i64, timelines: i64 };

/// Marks `name` archived, deletes its file in `dir`, then drops raw documents that are
/// acked (older than every unacked export) and older than `keep_days`. A name with no
/// row (a file from an older binary's failed export) has its file deleted all the same:
/// the gpu-box acks only what it archived, and an error here would stop its every pull
pub fn ack(io: Io, db: store.Db, dir: []const u8, name: []const u8, keep_days: u32, now_s: i64) !Pruned {
    if (!isExportName(name)) return error.BadExportName;
    try db.exec(ddl);
    try db.run("UPDATE raw.archive_exports SET acked_at = ? WHERE name = ? AND acked_at IS NULL", .{ now_s, name });
    const known = db.changes() > 0 or
        try int(db, "SELECT count(*) FROM raw.archive_exports WHERE name = ?", .{name}) > 0;
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = try std.fmt.bufPrint(&buf, "{s}/{s}", .{ dir, name });
    Io.Dir.cwd().deleteFile(io, path) catch |err| if (err != error.FileNotFound) return err;
    if (!known) {
        log.warn("ack of {s}, which no export recorded: file deleted, nothing pruned", .{name});
        return .{ .summaries = 0, .timelines = 0 };
    }
    return prune(db, keep_days, now_s);
}

/// raw-FROM-TO.db, the names exportNew makes
fn isExportName(name: []const u8) bool {
    if (!std.mem.startsWith(u8, name, "raw-") or !std.mem.endsWith(u8, name, ".db")) return false;
    const range = name["raw-".len .. name.len - ".db".len];
    const dash = std.mem.indexOfScalar(u8, range, '-') orelse return false;
    _ = std.fmt.parseInt(u64, range[0..dash], 10) catch return false;
    _ = std.fmt.parseInt(u64, range[dash + 1 ..], 10) catch return false;
    return true;
}

fn prune(db: store.Db, keep_days: u32, now_s: i64) !Pruned {
    const acked_until = (try store.schema.archivedUntil(db)) orelse 0;
    const cutoff = @min(acked_until, now_s - @as(i64, keep_days) * std.time.s_per_day);
    var out: Pruned = .{ .summaries = 0, .timelines = 0 };
    // Short chunks: the crawler's writer shares raw.db
    while (true) {
        try db.run(
            \\DELETE FROM raw.raw_docs WHERE source = 'riot_match' AND key IN
            \\    (SELECT key FROM raw.raw_docs WHERE source = 'riot_match' AND fetched_at < ? LIMIT 1000)
        , .{cutoff});
        const n = db.changes();
        out.summaries += n;
        if (n == 0) break;
    }
    while (true) {
        try db.run(
            \\DELETE FROM raw.timeline_docs WHERE rowid IN
            \\    (SELECT rowid FROM raw.timeline_docs WHERE fetched_at < ? LIMIT 500)
        , .{cutoff});
        const n = db.changes();
        out.timelines += n;
        if (n == 0) break;
    }
    return out;
}

/// For the health check: seconds since the newest ack (null: never acked), and exports
/// waiting for one
pub const Status = struct { since_ack_s: ?i64, unacked: i64, oldest_unacked_s: ?i64 };

pub fn status(db: store.Db, now_s: i64) !Status {
    try db.exec(ddl);
    const last = try int(db, "SELECT coalesce(max(acked_at), -1) FROM raw.archive_exports", .{});
    const oldest = try int(db, "SELECT coalesce(min(made_at), -1) FROM raw.archive_exports WHERE acked_at IS NULL", .{});
    return .{
        .since_ack_s = if (last < 0) null else now_s - last,
        .unacked = try int(db, "SELECT count(*) FROM raw.archive_exports WHERE acked_at IS NULL", .{}),
        .oldest_unacked_s = if (oldest < 0) null else now_s - oldest,
    };
}

fn int(db: store.Db, sql: []const u8, args: anytype) !i64 {
    return (try db.scalar(sql, args)) orelse 0;
}

const testing = std.testing;

test "export, ack, prune only what is acked and old enough" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try arena.print(".zig-cache/tmp/{s}", .{&tmp.sub_path});
    const data = try arena.print("{s}/data", .{base});
    const out = try arena.print("{s}/out", .{base});
    try Io.Dir.cwd().createDirPath(io, data);
    const db = try store.open(arena, data);
    defer db.close();
    const day = std.time.s_per_day;
    const now = 100 * day;
    try db.run(
        \\INSERT INTO raw.raw_docs VALUES ('riot_match', 'EUW1_1', ?, x'01'), ('riot_match', 'EUW1_2', ?, x'02');
    , .{ now - 10 * day, now - 60 });
    try db.run("INSERT INTO raw.timeline_docs VALUES ('EUW1_1', ?, x'03')", .{now - 10 * day});
    try db.run("INSERT INTO mastery VALUES ('p1', 'EUW1', ?, 0, x'04')", .{now - 10 * day});

    // EUW1_2 is too fresh: it may still sit in the writer's batch
    const first = (try exportNew(arena, io, db, out, now)).?;
    try testing.expectEqual(1, first.summaries);
    try testing.expectEqual(1, first.timelines);
    try testing.expectEqual(1, first.mastery);
    {
        const path = try arena.printSentinel("{s}/{s}", .{ out, first.name }, 0);
        const seg = try store.sqlite.Db.open(path);
        defer seg.close();
        try testing.expectEqual(1, try int(seg, "SELECT count(*) FROM raw_docs WHERE key = 'EUW1_1'", .{}));
    }
    const later = now + day;
    const second = (try exportNew(arena, io, db, out, later)).?;
    try testing.expectEqual(1, second.summaries);
    try testing.expectEqual(null, try exportNew(arena, io, db, out, later));

    // Acking the newer export alone drops nothing: the older one still waits
    try testing.expectEqual(Pruned{ .summaries = 0, .timelines = 0 }, try ack(io, db, out, second.name, 0, later));
    try testing.expectEqual(1, (try status(db, later)).unacked);
    // Both acked: everything older than 2 days goes, the fresh summary stays
    try testing.expectEqual(Pruned{ .summaries = 1, .timelines = 1 }, try ack(io, db, out, first.name, 2, later));
    try testing.expectEqual(1, try int(db, "SELECT count(*) FROM raw.raw_docs", .{}));
    try testing.expectEqual(0, (try status(db, later)).unacked);
    // The ack deleted the file
    try testing.expectError(error.FileNotFound, Io.Dir.cwd().access(io, try arena.print("{s}/{s}", .{ out, first.name }), .{}));
}

test "a failed export leaves nothing behind; an unknown ack deletes its file" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try arena.print(".zig-cache/tmp/{s}", .{&tmp.sub_path});
    const data = try arena.print("{s}/data", .{base});
    const out = try arena.print("{s}/out", .{base});
    const cwd = Io.Dir.cwd();
    try cwd.createDirPath(io, data);
    try cwd.createDirPath(io, out);
    const db = try store.open(arena, data);
    defer db.close();
    const day = std.time.s_per_day;
    const now = 100 * day;
    try db.run("INSERT INTO raw.raw_docs VALUES ('riot_match', 'EUW1_1', ?, x'01')", .{now - day});

    // A partial file, and the newest export's row whose file never got its name
    const partial = try arena.print("{s}/raw-0-5.db.tmp", .{out});
    try cwd.writeFile(io, .{ .sub_path = partial, .data = "x" });
    try db.exec(ddl);
    try db.run("INSERT INTO raw.archive_exports VALUES ('raw-0-50.db', 0, 50, 0, 0, 0, 50, NULL)", .{});
    const redone = (try exportNew(arena, io, db, out, now)).?;
    try testing.expect(std.mem.startsWith(u8, redone.name, "raw-0-"));
    try testing.expectEqual(1, redone.summaries);
    try testing.expectEqual(1, try int(db, "SELECT count(*) FROM raw.archive_exports", .{}));
    try testing.expectError(error.FileNotFound, cwd.access(io, partial, .{}));

    // A file with no row, say from an older binary's failed export
    const stray = try arena.print("{s}/raw-7-8.db", .{out});
    try cwd.writeFile(io, .{ .sub_path = stray, .data = "x" });
    const saved = testing.log_level;
    defer testing.log_level = saved;
    testing.log_level = .err;
    try testing.expectEqual(Pruned{ .summaries = 0, .timelines = 0 }, try ack(io, db, out, "raw-7-8.db", 0, now));
    try testing.expectError(error.FileNotFound, cwd.access(io, stray, .{}));
    try testing.expectError(error.BadExportName, ack(io, db, out, "../raw-7-8.db", 0, now));
    try testing.expectEqual(1, (try status(db, now)).unacked);
}
