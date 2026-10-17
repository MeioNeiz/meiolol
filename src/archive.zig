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
//! point too (writer.zig). Raw timelines (most of the bytes) are the exception: once an
//! export file holds them they leave raw.db at once, so the box never keeps two copies
//! while the gpu-box is away; the file is their copy until the ack deletes it.
//!
//! When the disk runs low regardless, `valve` drops raw the archive never got (oldest
//! unacked export first, else the oldest raw timelines) so the crawler, site builds and
//! backups keep running: Jacob, 17 Oct, uptime over a complete archive.

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
    \\-- What the valve dropped unarchived. kind: 'export' (name is its file; its row is
    \\-- marked acked so pruning moves past it) or 'raw' (timelines straight from raw.db)
    \\CREATE TABLE IF NOT EXISTS raw.archive_dropped (
    \\    at INTEGER NOT NULL,
    \\    kind TEXT NOT NULL,
    \\    name TEXT NOT NULL,
    \\    from_s INTEGER NOT NULL,
    \\    to_s INTEGER NOT NULL,
    \\    docs INTEGER NOT NULL,
    \\    bytes INTEGER NOT NULL,
    \\    free_mb INTEGER NOT NULL
    \\);
;

/// The crawler's writer stamps raw documents and mastery with the time it began the
/// transaction that stores them (writer.zig), so a document still uncommitted when an
/// export reads has a stamp at most one transaction old: this margin keeps it for the
/// next export
const settle_s = 300;

pub const Export = struct {
    name: []const u8,
    summaries: i64,
    timelines: i64,
    mastery: i64,
    /// Raw timelines dropped from raw.db because the file now holds them
    pruned: i64,
};

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
    // The file and its name on disk before raw.db gives up its copy: after a crash the
    // name could otherwise vanish, and cleanUp would export a window raw.db no longer has
    try syncPath(io, path, .file);
    try syncPath(io, dir, .directory);
    return .{
        .name = name,
        .summaries = counts.summaries,
        .timelines = counts.timelines,
        .mastery = counts.mastery,
        .pruned = try pruneExported(db, path),
    };
}

fn syncPath(io: Io, path: []const u8, kind: enum { file, directory }) !void {
    const cwd = Io.Dir.cwd();
    switch (kind) {
        .file => {
            const f = try cwd.openFile(io, path, .{});
            defer f.close(io);
            try f.sync(io);
        },
        .directory => {
            var d = try cwd.openDir(io, path, .{});
            defer d.close(io);
            const f: Io.File = .{ .handle = d.handle, .flags = .{ .nonblocking = false } };
            try f.sync(io);
        },
    }
}

/// Deletes from raw.db the raw timelines the export at `path` holds, matched on id and
/// fetch time (a refetch since is newer and waits for the next export). Failed parses
/// stay, as in the crawler's prune, for a fixed parser to redo. In short chunks by the
/// file's rowids: the crawler's writer shares raw.db
fn pruneExported(db: store.Db, path: [:0]const u8) !i64 {
    try db.run("ATTACH ? AS done", .{path});
    defer db.exec("DETACH done") catch {};
    const last = try int(db, "SELECT coalesce(max(rowid), 0) FROM done.timeline_docs", .{});
    var pruned: i64 = 0;
    var lo: i64 = 0;
    while (lo < last) : (lo += 500) {
        try db.run(
            \\DELETE FROM raw.timeline_docs WHERE match_id IN
            \\    (SELECT d.match_id FROM done.timeline_docs s
            \\     JOIN raw.timeline_docs d ON d.match_id = s.match_id AND d.fetched_at = s.fetched_at
            \\     WHERE s.rowid > ?1 AND s.rowid <= ?1 + 500 AND NOT EXISTS
            \\         (SELECT 1 FROM timeline_queue q
            \\          WHERE q.match_id = d.match_id AND q.status = 'failed'))
        , .{lo});
        pruned += db.changes();
    }
    return pruned;
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

/// For the health check: seconds since the newest ack by the gpu-box (null: never; the
/// valve's own marks don't count), exports waiting for one, and the valve's drops
pub const Status = struct {
    since_ack_s: ?i64,
    unacked: i64,
    oldest_unacked_s: ?i64,
    /// Seconds since the valve last dropped raw (null: never)
    since_drop_s: ?i64,
    drops_24h: i64,
};

pub fn status(db: store.Db, now_s: i64) !Status {
    try db.exec(ddl);
    const last = try int(db,
        \\SELECT coalesce(max(acked_at), -1) FROM raw.archive_exports
        \\WHERE name NOT IN (SELECT name FROM raw.archive_dropped WHERE kind = 'export')
    , .{});
    const oldest = try int(db, "SELECT coalesce(min(made_at), -1) FROM raw.archive_exports WHERE acked_at IS NULL", .{});
    const dropped = try int(db, "SELECT coalesce(max(at), -1) FROM raw.archive_dropped", .{});
    return .{
        .since_ack_s = if (last < 0) null else now_s - last,
        .unacked = try int(db, "SELECT count(*) FROM raw.archive_exports WHERE acked_at IS NULL", .{}),
        .oldest_unacked_s = if (oldest < 0) null else now_s - oldest,
        .since_drop_s = if (dropped < 0) null else now_s - dropped,
        .drops_24h = try int(db, "SELECT count(*) FROM raw.archive_dropped WHERE at > ?", .{now_s - std.time.s_per_day}),
    };
}

pub const Dropped = struct {
    kind: enum { @"export", raw },
    name: []const u8,
    from_s: i64,
    to_s: i64,
    docs: i64,
    bytes: i64,
};

/// Raw timelines the valve drops from raw.db per call when no export file is left:
/// ~180 MB of pages for new raw to reuse (raw.db never shrinks), so a disk at the
/// threshold stays there while the crawler goes on
const valve_raw_chunk = 2000;

/// With `free_mb` (the data disk's, measured by the caller) under `min_free_mb`, drops
/// the oldest unacked export (its file deleted, its row marked acked so pruning moves
/// past it), or when no export file is left the oldest raw timelines in raw.db; null
/// when there is room or nothing to drop. Logged, recorded in raw.archive_dropped and
/// appended to `log_path` as a line (unix time, kind, name, from_s, to_s, documents,
/// bytes, free MB; tab-separated), as it loses raw for good
pub fn valve(
    arena: std.mem.Allocator,
    io: Io,
    db: store.Db,
    dir: []const u8,
    log_path: []const u8,
    free_mb: u64,
    min_free_mb: u64,
    now_s: i64,
) !?Dropped {
    if (free_mb >= min_free_mb) return null;
    try db.exec(ddl);
    const d = try dropExport(arena, io, db, dir, now_s) orelse try dropRaw(arena, db) orelse return null;
    const free: i64 = @intCast(free_mb);
    try db.run("INSERT INTO raw.archive_dropped VALUES (?,?,?,?,?,?,?,?)", .{
        now_s, @tagName(d.kind), d.name, d.from_s, d.to_s, d.docs, d.bytes, free,
    });
    log.warn("valve: {d} MB free (under {d}): dropped {s} {s}, raw fetched {d} to {d}, " ++
        "{d} documents, {d} MB, never archived", .{
        free_mb, min_free_mb, @tagName(d.kind), d.name, d.from_s, d.to_s, d.docs, @divFloor(d.bytes, 1 << 20),
    });
    const cwd = Io.Dir.cwd();
    var file = try cwd.createFile(io, log_path, .{ .truncate = false });
    defer file.close(io);
    var buf: [512]u8 = undefined;
    var fw = file.writer(io, &buf);
    try fw.seekTo(try file.length(io));
    try fw.interface.print("{d}\t{s}\t{s}\t{d}\t{d}\t{d}\t{d}\t{d}\n", .{
        now_s, @tagName(d.kind), d.name, d.from_s, d.to_s, d.docs, d.bytes, free_mb,
    });
    try fw.interface.flush();
    return d;
}

fn dropExport(arena: std.mem.Allocator, io: Io, db: store.Db, dir: []const u8, now_s: i64) !?Dropped {
    var s = try db.prepare(
        \\SELECT name, from_s, to_s, summaries + timelines + mastery FROM raw.archive_exports
        \\WHERE acked_at IS NULL ORDER BY from_s
    );
    defer s.deinit();
    const cwd = Io.Dir.cwd();
    while (try s.step()) {
        const path = try std.fmt.allocPrint(arena, "{s}/{s}", .{ dir, s.bytes(0) });
        const f = cwd.openFile(io, path, .{}) catch |err| switch (err) {
            // Its window is lost already; a newer one may still free space
            error.FileNotFound => continue,
            else => return err,
        };
        const bytes = f.length(io);
        f.close(io);
        const d: Dropped = .{
            .kind = .@"export",
            .name = try arena.dupe(u8, s.bytes(0)),
            .from_s = s.int(1),
            .to_s = s.int(2),
            .docs = s.int(3),
            .bytes = @intCast(try bytes),
        };
        s.reset();
        try cwd.deleteFile(io, path);
        try db.run("UPDATE raw.archive_exports SET acked_at = ? WHERE name = ?", .{ now_s, d.name });
        return d;
    }
    return null;
}

fn dropRaw(arena: std.mem.Allocator, db: store.Db) !?Dropped {
    try db.exec("DROP TABLE IF EXISTS temp.valve");
    defer db.exec("DROP TABLE IF EXISTS temp.valve") catch {};
    try db.run(
        \\CREATE TEMP TABLE valve AS SELECT d.match_id, d.fetched_at, length(d.body) AS bytes
        \\FROM raw.timeline_docs d WHERE NOT EXISTS
        \\    (SELECT 1 FROM timeline_queue q WHERE q.match_id = d.match_id AND q.status = 'failed')
        \\ORDER BY d.fetched_at LIMIT ?
    , .{valve_raw_chunk});
    const docs = try int(db, "SELECT count(*) FROM temp.valve", .{});
    if (docs == 0) return null;
    const from = try int(db, "SELECT min(fetched_at) FROM temp.valve", .{});
    const to = try int(db, "SELECT max(fetched_at) + 1 FROM temp.valve", .{});
    const bytes = try int(db, "SELECT sum(bytes) FROM temp.valve", .{});
    try db.exec("DELETE FROM raw.timeline_docs WHERE match_id IN (SELECT match_id FROM temp.valve)");
    return .{
        .kind = .raw,
        .name = try arena.dupe(u8, "raw.timeline_docs"),
        .from_s = from,
        .to_s = to,
        .docs = docs,
        .bytes = bytes,
    };
}

/// Free space on the disk holding `path` in MB (`df -Pk`: std has no statvfs); null
/// when df fails or prints something else
pub fn freeMb(gpa: std.mem.Allocator, io: Io, path: []const u8) ?u64 {
    const r = std.process.run(gpa, io, .{ .argv = &.{ "df", "-Pk", path } }) catch return null;
    defer gpa.free(r.stdout);
    defer gpa.free(r.stderr);
    if (!r.term.success()) return null;
    return dfAvailableMb(r.stdout);
}

/// The Available column (1K blocks) of `df -Pk`'s one filesystem line, in MB
fn dfAvailableMb(out: []const u8) ?u64 {
    var lines = std.mem.tokenizeScalar(u8, out, '\n');
    _ = lines.next() orelse return null;
    var fields = std.mem.tokenizeAny(u8, lines.next() orelse return null, " \t");
    for (0..3) |_| _ = fields.next() orelse return null;
    const kb = std.fmt.parseInt(u64, fields.next() orelse return null, 10) catch return null;
    return kb / 1024;
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
    // The file holds the timeline now; summaries stay until the ack
    try testing.expectEqual(1, first.pruned);
    try testing.expectEqual(0, try int(db, "SELECT count(*) FROM raw.timeline_docs", .{}));
    try testing.expectEqual(2, try int(db, "SELECT count(*) FROM raw.raw_docs", .{}));
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
    try testing.expectEqual(Pruned{ .summaries = 1, .timelines = 0 }, try ack(io, db, out, first.name, 2, later));
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

test "an export prunes only the timelines it holds, never failed parses" {
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
    const now = 100 * std.time.s_per_day;
    // EUW1_1 parsed, EUW1_2 failed to parse, EUW1_3 too fresh for this export
    try db.run("INSERT INTO raw.timeline_docs VALUES ('EUW1_1', ?1, x'01'), ('EUW1_2', ?1, x'02'), ('EUW1_3', ?2, x'03')", .{
        now - 3600, now - 60,
    });
    try db.exec("INSERT INTO timeline_queue (match_id, region, status, queued_at) VALUES ('EUW1_2', 'europe', 'failed', 1)");
    const e = (try exportNew(arena, io, db, out, now)).?;
    try testing.expectEqual(2, e.timelines);
    try testing.expectEqual(1, e.pruned);
    var left = try db.prepare("SELECT match_id FROM raw.timeline_docs ORDER BY match_id");
    defer left.deinit();
    try testing.expect(try left.step());
    try testing.expectEqualStrings("EUW1_2", left.bytes(0));
    try testing.expect(try left.step());
    try testing.expectEqualStrings("EUW1_3", left.bytes(0));
    try testing.expect(!try left.step());
}

test "the valve drops the oldest unacked export, then raw timelines, and says so" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try arena.print(".zig-cache/tmp/{s}", .{&tmp.sub_path});
    const data = try arena.print("{s}/data", .{base});
    const out = try arena.print("{s}/out", .{base});
    const log_path = try arena.print("{s}/raw-dropped.log", .{data});
    const cwd = Io.Dir.cwd();
    try cwd.createDirPath(io, data);
    const db = try store.open(arena, data);
    defer db.close();
    const hour = 3600;
    const now = 100 * std.time.s_per_day;
    try db.run("INSERT INTO raw.raw_docs VALUES ('riot_match', 'EUW1_1', ?, x'01')", .{now - 3 * hour});
    const older = (try exportNew(arena, io, db, out, now - 2 * hour)).?;
    try db.run("INSERT INTO raw.raw_docs VALUES ('riot_match', 'EUW1_2', ?, x'02')", .{now - hour});
    const newer = (try exportNew(arena, io, db, out, now)).?;
    try db.run("INSERT INTO raw.timeline_docs VALUES ('EUW1_9', ?, x'09')", .{now - 60});

    const saved = testing.log_level;
    defer testing.log_level = saved;
    testing.log_level = .err;
    try testing.expectEqual(null, try valve(arena, io, db, out, log_path, 500, 400, now));
    const a = (try valve(arena, io, db, out, log_path, 300, 400, now)).?;
    try testing.expectEqualStrings(older.name, a.name);
    try testing.expectError(error.FileNotFound, cwd.access(io, try arena.print("{s}/{s}", .{ out, older.name }), .{}));
    // Pruning moves past it, but it is no ack from the gpu-box
    const st = try status(db, now + 10);
    try testing.expectEqual(null, st.since_ack_s);
    try testing.expectEqual(1, st.unacked);
    try testing.expectEqual(10, st.since_drop_s.?);
    try testing.expectEqual(1, st.drops_24h);
    try testing.expectEqual(now - 2 * hour - settle_s, (try store.schema.archivedUntil(db)).?);

    const b = (try valve(arena, io, db, out, log_path, 300, 400, now)).?;
    try testing.expectEqualStrings(newer.name, b.name);
    // No export left: the oldest raw timelines go straight from raw.db
    const c = (try valve(arena, io, db, out, log_path, 300, 400, now)).?;
    try testing.expectEqual(.raw, c.kind);
    try testing.expectEqual(1, c.docs);
    try testing.expectEqual(0, try int(db, "SELECT count(*) FROM raw.timeline_docs", .{}));
    try testing.expectEqual(null, try valve(arena, io, db, out, log_path, 300, 400, now));

    const lines = try cwd.readFileAlloc(io, log_path, arena, .limited(1 << 16));
    try testing.expectEqual(3, std.mem.count(u8, lines, "\n"));
    try testing.expect(std.mem.startsWith(u8, lines, try arena.print("{d}\texport\t{s}\t", .{ now, older.name })));
}

test "df's available column" {
    try testing.expectEqual(39062, dfAvailableMb(
        \\Filesystem     1024-blocks      Used Available Capacity Mounted on
        \\/dev/sda1        151981652 104857600  40000000      73% /
        \\
    ));
    try testing.expectEqual(null, dfAvailableMb("df: /nope: No such file or directory\n"));
}
