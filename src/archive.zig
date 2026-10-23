//! Raw archive, box side (`meiolol raw-export`; docs/data-safety.md "Raw archive"). The
//! gpu-box keeps every raw document; the box only buffers them.
//!
//! An export writes the raw summaries, raw timelines and mastery snapshots fetched since
//! the previous export into one SQLite file, as stored: gzip bodies, real ids. The salt
//! never comes to the box, so pseudonymising happens on the gpu-box (src/lab/archive.zig)
//! before anything is archived. An export covers at most `max_window_s` of fetches, so a
//! backlog goes as a run of small files, not one copy of it. Once the gpu-box has a file
//! (its sha256 checked against the box's, archive-serve.sh) the box deletes it
//! (`received`); the ack, after the archive, lets the box drop raw documents that are both
//! acked and `keep_days` old (`pruneAcked`). Unacked documents stay whatever their age, so
//! a PC that is off for days loses nothing while the box has disk: once an export exists
//! the crawler's own raw pruning (--raw-*-days) stops at the acked point too (writer.zig).
//! Raw timelines (most of the bytes) are the exception: once an export file holds them
//! they leave raw.db at once, so the box never keeps two copies; the file, then the
//! gpu-box's received copy, is theirs until the archive.
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
    \\-- Exports the gpu-box has (checksum checked), their files deleted; acked once archived
    \\CREATE TABLE IF NOT EXISTS raw.archive_received (
    \\    name TEXT PRIMARY KEY,
    \\    at INTEGER NOT NULL
    \\);
;

/// The crawler's writer stamps raw documents and mastery with the time it began the
/// transaction that stores them (writer.zig), so a document still uncommitted when an
/// export reads has a stamp at most one transaction old: this margin keeps it for the
/// next export
const settle_s = 300;

/// The most fetch time one export covers: ~1 GB at the crawler's rate (17 Oct: ~0.5 GB
/// an hour), so a gpu-box back after days catches up file by file and the box holds one
/// at a time instead of a copy of the whole backlog (33 GB on 17 Oct)
const max_window_s = 2 * 3600;

pub const Export = struct {
    name: []const u8,
    summaries: i64,
    timelines: i64,
    mastery: i64,
    /// Raw timelines dropped from raw.db because the file now holds them
    pruned: i64,
    /// Capped at `max_window_s`: more is waiting
    more: bool,
};

/// Writes DIR/raw-FROM-TO.db with what was fetched since the last export, up to
/// `max_window_s` from the first document; null when nothing new. The name is in
/// `arena`. `now_s` must be read before the call: each copy then sees everything
/// committed by then
pub fn exportNew(arena: std.mem.Allocator, io: Io, db: store.Db, dir: []const u8, now_s: i64) !?Export {
    try db.exec(ddl);
    try Io.Dir.cwd().createDirPath(io, dir);
    try cleanUp(arena, io, db, dir);
    const from = try int(db, "SELECT coalesce(max(to_s), 0) FROM raw.archive_exports", .{});
    // From the first document, so a stretch with none (crawler stopped) costs no exports
    const first = try int(db,
        \\SELECT coalesce(min(t), -1) FROM (
        \\    SELECT min(fetched_at) AS t FROM raw.raw_docs WHERE source = 'riot_match' AND fetched_at >= ?1
        \\    UNION ALL SELECT min(fetched_at) FROM raw.timeline_docs WHERE fetched_at >= ?1
        \\    UNION ALL SELECT min(fetched_at) FROM mastery WHERE fetched_at >= ?1)
    , .{from});
    if (first < 0) return null;
    const more = first + max_window_s < now_s - settle_s;
    const to = if (more) first + max_window_s else now_s - settle_s;
    if (to <= first) return null;
    const name = try arena.print("raw-{d}-{d}.db", .{ from, to });
    const tmp = try arena.printSentinel("{s}/{s}.tmp", .{ dir, name }, 0);
    errdefer Io.Dir.cwd().deleteFile(io, tmp) catch {};

    const counts = try copy(db, tmp, from, to);
    // Recorded before the file takes its name, so every listed file has its row; a crash
    // between the two leaves a row with no file, which cleanUp undoes
    try db.run("INSERT INTO raw.archive_exports VALUES (?,?,?,?,?,?,?,NULL)", .{
        name, from, to, counts.summaries, counts.timelines, counts.mastery, now_s,
    });
    const path = try arena.printSentinel("{s}/{s}", .{ dir, name }, 0);
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
        .more = more,
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
            // iterate: without it Linux opens O_PATH, and fsync on that fails (EBADF,
            // error.Unexpected: every export on the box, 17 Oct 14:43Z)
            var d = try cwd.openDir(io, path, .{ .iterate = true });
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
/// name (and the gpu-box never received it), so its window is exported again. An older
/// unacked row without a file is left alone: its documents are not archived, and
/// dropping the row would let them be pruned
fn cleanUp(arena: std.mem.Allocator, io: Io, db: store.Db, dir_path: []const u8) !void {
    var dir = try Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true });
    defer dir.close(io);
    var stale: std.ArrayList([]const u8) = .empty;
    var it = dir.iterate();
    while (try it.next(io)) |e| {
        if (e.kind == .file and std.mem.startsWith(u8, e.name, "raw-") and
            (std.mem.endsWith(u8, e.name, ".db.tmp") or std.mem.endsWith(u8, e.name, ".db.zst.tmp")))
        {
            try stale.append(arena, try arena.dupe(u8, e.name));
        }
    }
    for (stale.items) |name| {
        log.info("deleting {s}, left by a failed export", .{name});
        try dir.deleteFile(io, name);
    }

    var s = try db.prepare(
        \\SELECT name, name IN (SELECT name FROM raw.archive_received)
        \\FROM raw.archive_exports WHERE acked_at IS NULL ORDER BY to_s DESC LIMIT 1
    );
    defer s.deinit();
    if (!try s.step()) return;
    const newest = try arena.dupe(u8, s.bytes(0));
    const got = s.int(1) != 0;
    s.reset();
    if (got) return;
    if (try exportFile(arena, io, dir_path, newest) != null) return;
    log.info("export {s} has no file: exporting its window again", .{newest});
    try db.run("DELETE FROM raw.archive_exports WHERE name = ?", .{newest});
}

pub const Pruned = struct { summaries: i64, timelines: i64 };

/// The gpu-box has `name`, the file's sha256 checked against its own copy: the box's file
/// goes now, not at the ack after the archive. Again for a received name is a no-op (a
/// retry whose first answer was lost)
pub fn received(io: Io, db: store.Db, dir: []const u8, name: []const u8, now_s: i64) !void {
    if (!isExportName(name)) return error.BadExportName;
    try db.exec(ddl);
    if (try int(db, "SELECT count(*) FROM raw.archive_exports WHERE name = ? AND acked_at IS NULL", .{name}) == 0)
        return error.NotUnacked;
    // The row first: a crash before the delete leaves a file the ack deletes later
    try db.run("INSERT OR IGNORE INTO raw.archive_received VALUES (?, ?)", .{ name, now_s });
    try deleteExportFiles(io, dir, name);
}

/// For the gpu-box, oldest first, one line per unacked export: "NAME SIZE" while the box
/// has its file, "NAME received" once the gpu-box has it, "NAME missing" for a window the
/// next export makes again (cleanUp)
pub fn list(arena: std.mem.Allocator, io: Io, db: store.Db, dir: []const u8, w: *Io.Writer) !void {
    try db.exec(ddl);
    var s = try db.prepare(
        \\SELECT name, name IN (SELECT name FROM raw.archive_received) FROM raw.archive_exports
        \\WHERE acked_at IS NULL ORDER BY from_s
    );
    defer s.deinit();
    const cwd = Io.Dir.cwd();
    while (try s.step()) {
        const name = s.bytes(0);
        if (s.int(1) != 0) {
            try w.print("{s} received\n", .{name});
            continue;
        }
        const path = try exportFile(arena, io, dir, name) orelse {
            try w.print("{s} missing\n", .{name});
            continue;
        };
        const f = try cwd.openFile(io, path, .{});
        defer f.close(io);
        try w.print("{s} {d}\n", .{ name, try f.length(io) });
    }
}

/// Marks `name` archived and deletes its file in `dir` if the box still has it; quick, so
/// the gpu-box's ssh is short (the prune, minutes after a backlog, is `pruneAcked`). A
/// name with no row (a file from an older binary's failed export) has its file deleted
/// all the same: the gpu-box acks only what it archived, and an error here would stop
/// its every pull. Again for an acked name is a no-op
pub fn ack(io: Io, db: store.Db, dir: []const u8, name: []const u8, now_s: i64) !void {
    if (!isExportName(name)) return error.BadExportName;
    try db.exec(ddl);
    try db.run("UPDATE raw.archive_exports SET acked_at = ? WHERE name = ? AND acked_at IS NULL", .{ now_s, name });
    const known = db.changes() > 0 or
        try int(db, "SELECT count(*) FROM raw.archive_exports WHERE name = ?", .{name}) > 0;
    try deleteExportFiles(io, dir, name);
    if (!known) log.warn("ack of {s}, which no export recorded: file deleted", .{name});
}

/// The export's file: its pack (NAME.zst) once `pack` made one, else NAME; null with
/// neither
fn exportFile(arena: std.mem.Allocator, io: Io, dir: []const u8, name: []const u8) !?[]const u8 {
    const cwd = Io.Dir.cwd();
    for ([_][]const u8{ ".zst", "" }) |ext| {
        const path = try arena.print("{s}/{s}{s}", .{ dir, name, ext });
        if (cwd.access(io, path, .{})) |_| return path else |err| switch (err) {
            error.FileNotFound => {},
            else => return err,
        }
    }
    return null;
}

fn deleteExportFiles(io: Io, dir: []const u8, name: []const u8) !void {
    for ([_][]const u8{ ".zst", "" }) |ext| {
        var buf: [std.fs.max_path_bytes]u8 = undefined;
        const path = try std.mem.print(&buf, "{s}/{s}{s}", .{ dir, name, ext });
        Io.Dir.cwd().deleteFile(io, path) catch |err| switch (err) {
            error.FileNotFound => {},
            else => return err,
        };
    }
}

pub const Packed = struct { db_bytes: u64, zst_bytes: u64, docs: u64 };

/// DIR/NAME (an export) as DIR/NAME.zst: its rows as a rawpack stream (bodies gunzipped),
/// through `zstd -LEVEL -T1` on PATH, so ~half the bytes go to the gpu-box. NAME goes
/// only once the pack has been read back whole (the zstd frame's checksum, rawpack's own
/// hash and the counts against NAME's) and synced. Again for a packed name is a no-op
pub fn pack(gpa: std.mem.Allocator, io: Io, dir: []const u8, name: []const u8, level: u8) !?Packed {
    if (!isExportName(name)) return error.BadExportName;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const cwd = Io.Dir.cwd();
    const path = try arena.printSentinel("{s}/{s}", .{ dir, name }, 0);
    const zst = try arena.print("{s}.zst", .{path});
    const tmp = try arena.print("{s}.zst.tmp", .{path});
    if (cwd.access(io, path, .{})) |_| {} else |err| switch (err) {
        error.FileNotFound => if (cwd.access(io, zst, .{})) |_| return null else |e| return e,
        else => return err,
    }
    // A pack whose rename was done but not the delete: NAME's pack is whole
    if (cwd.access(io, zst, .{})) |_| {
        try cwd.deleteFile(io, path);
        return null;
    } else |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    }
    errdefer cwd.deleteFile(io, tmp) catch {};

    const db_bytes = blk: {
        const f = try cwd.openFile(io, path, .{});
        defer f.close(io);
        break :blk try f.length(io);
    };
    const db = try store.sqlite.Db.openReadOnly(path);
    defer db.close();
    const want: store.rawpack.Counts = .{
        .summaries = @intCast(try int(db, "SELECT count(*) FROM raw_docs", .{})),
        .timelines = @intCast(try int(db, "SELECT count(*) FROM timeline_docs", .{})),
        .mastery = @intCast(try int(db, "SELECT count(*) FROM mastery", .{})),
    };
    {
        const lvl = try arena.print("-{d}", .{level});
        var child = try std.process.spawn(io, .{
            .argv = &.{ "zstd", "-q", "-f", lvl, "-T1", "-", "-o", tmp },
            .stdin = .pipe,
        });
        var ok = false;
        defer if (!ok) child.kill(io);
        var wbuf: [256 * 1024]u8 = undefined;
        var fw = child.stdin.?.writerStreaming(io, &wbuf);
        var w = try store.rawpack.Writer.begin(&fw.interface);
        try packDocs(gpa, arena, db, &w, .summary, "raw_docs", "key");
        try packDocs(gpa, arena, db, &w, .timeline, "timeline_docs", "match_id");
        var q = try db.prepare("SELECT puuid, platform, fetched_at, champions, data FROM mastery ORDER BY fetched_at, puuid");
        defer q.deinit();
        try q.bind(.{});
        while (try q.step()) try w.mastery(.{
            .puuid = q.bytes(0),
            .platform = if (q.isNull(1)) null else q.bytes(1),
            .fetched_at = q.int(2),
            .champions = q.int(3),
            .data = q.bytes(4),
        });
        try w.end();
        try fw.interface.flush();
        child.stdin.?.close(io);
        child.stdin = null;
        ok = true;
        if (!(try child.wait(io)).success()) return error.ZstdFailed;
    }
    const got = try readPack(gpa, io, tmp);
    if (!std.meta.eql(got, want)) {
        log.err("{s}: pack read back {any}, export holds {any}", .{ name, got, want });
        return error.PackCountsDiffer;
    }
    try syncPath(io, tmp, .file);
    try cwd.rename(tmp, cwd, zst, io);
    try syncPath(io, dir, .directory);
    cwd.deleteFile(io, path) catch |err| {
        switch (err) {
            // The valve dropped the export meanwhile: its pack goes too
            error.FileNotFound => cwd.deleteFile(io, zst) catch {},
            else => {},
        }
        return err;
    };
    try syncPath(io, dir, .directory);
    const f = try cwd.openFile(io, zst, .{});
    defer f.close(io);
    return .{ .db_bytes = db_bytes, .zst_bytes = try f.length(io), .docs = want.summaries + want.timelines + want.mastery };
}

/// In fetched_at, key order (the archive's), sorting ids only: an ORDER BY over the rows
/// would spill the export's bodies to a temp file on the box's busy disk
fn packDocs(
    gpa: std.mem.Allocator,
    arena: std.mem.Allocator,
    db: store.Db,
    w: *store.rawpack.Writer,
    kind: store.rawpack.Kind,
    comptime table: []const u8,
    comptime key: []const u8,
) !void {
    var ids: std.ArrayList(i64) = .empty;
    {
        var q = try db.prepare("SELECT rowid FROM " ++ table ++ " ORDER BY fetched_at, " ++ key);
        defer q.deinit();
        try q.bind(.{});
        while (try q.step()) try ids.append(arena, q.int(0));
    }
    var q = try db.prepare("SELECT " ++ key ++ ", fetched_at, body FROM " ++ table ++ " WHERE rowid = ?");
    defer q.deinit();
    for (ids.items) |id| {
        try q.bind(.{id});
        if (!try q.step()) return error.RowGone;
        const body = q.bytes(2);
        const plain: ?[]u8 = store.raw.decompress(gpa, body) catch |err| switch (err) {
            error.OutOfMemory => return err,
            else => null,
        };
        defer if (plain) |p| gpa.free(p);
        try w.doc(kind, .{
            .key = q.bytes(0),
            .fetched_at = q.int(1),
            .encoding = if (plain == null) .stored else .plain,
            .body = plain orelse body,
        });
        q.reset();
    }
}

/// A pack's counts, read whole through `zstd -dc` (rawpack checks its order, hash and
/// end record)
pub fn readPack(gpa: std.mem.Allocator, io: Io, path: []const u8) !store.rawpack.Counts {
    var child = try std.process.spawn(io, .{
        .argv = &.{ "zstd", "-dc", "-q", path },
        .stdout = .pipe,
    });
    var ok = false;
    defer if (!ok) child.kill(io);
    var rbuf: [256 * 1024]u8 = undefined;
    var fr = child.stdout.?.readerStreaming(io, &rbuf);
    var r = try store.rawpack.Reader.init(gpa, &fr.interface);
    defer r.deinit();
    while (try r.next()) |_| {}
    ok = true;
    if (!(try child.wait(io)).success()) return error.ZstdFailed;
    return r.counts;
}

/// raw-FROM-TO.db, the names exportNew makes
fn isExportName(name: []const u8) bool {
    if (!std.mem.startsWith(u8, name, "raw-") or !std.mem.endsWith(u8, name, ".db")) return false;
    const range = name["raw-".len .. name.len - ".db".len];
    const dash = std.mem.findScalar(u8, range, '-') orelse return false;
    _ = std.fmt.parseInt(u64, range[0..dash], 10) catch return false;
    _ = std.fmt.parseInt(u64, range[dash + 1 ..], 10) catch return false;
    return true;
}

/// Drops raw documents that are acked (older than every unacked export) and older than
/// `keep_days`
pub fn pruneAcked(db: store.Db, keep_days: u32, now_s: i64) !Pruned {
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
    const freed = try returnFree(db);
    if (freed > 0) log.info("prune: {d} MB of raw.db returned to the disk", .{freed >> 20});
    return out;
}

/// Hands raw.db's free pages back to the disk, ~100 MB a write transaction (the
/// crawler's writer shares raw.db); bytes returned. Only with auto_vacuum=INCREMENTAL,
/// which a VACUUM sets (docs/data-safety.md "Raw archive"); without it freed pages stay
/// for new raw to reuse. Not in an export's prune: that runs in the gpu-box's ssh
/// session, which the home link kills; the next ack's prune returns those pages
pub fn returnFree(db: store.Db) !i64 {
    if (try int(db, "PRAGMA raw.auto_vacuum", .{}) != 2) return 0;
    const page = try int(db, "PRAGMA raw.page_size", .{});
    var freed: i64 = 0;
    while (true) {
        const before = try int(db, "PRAGMA raw.freelist_count", .{});
        if (before == 0) break;
        try db.exec("PRAGMA raw.incremental_vacuum(25600)");
        const after = try int(db, "PRAGMA raw.freelist_count", .{});
        if (after >= before) break;
        freed += (before - after) * page;
    }
    return freed;
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

/// Read-only (the health check runs it beside acks, exports and the crawler's prune):
/// no DDL, so tables an older box never made read as nothing yet
pub fn status(db: store.Db, now_s: i64) !Status {
    var out: Status = .{ .since_ack_s = null, .unacked = 0, .oldest_unacked_s = null, .since_drop_s = null, .drops_24h = 0 };
    if (!try hasTable(db, "archive_exports")) return out;
    const drops = try hasTable(db, "archive_dropped");
    const last = if (!drops)
        try int(db, "SELECT coalesce(max(acked_at), -1) FROM raw.archive_exports", .{})
    else
        try int(db,
            \\SELECT coalesce(max(acked_at), -1) FROM raw.archive_exports
            \\WHERE name NOT IN (SELECT name FROM raw.archive_dropped WHERE kind = 'export')
        , .{});
    const oldest = try int(db, "SELECT coalesce(min(made_at), -1) FROM raw.archive_exports WHERE acked_at IS NULL", .{});
    out.since_ack_s = if (last < 0) null else now_s - last;
    out.unacked = try int(db, "SELECT count(*) FROM raw.archive_exports WHERE acked_at IS NULL", .{});
    out.oldest_unacked_s = if (oldest < 0) null else now_s - oldest;
    if (drops) {
        const dropped = try int(db, "SELECT coalesce(max(at), -1) FROM raw.archive_dropped", .{});
        out.since_drop_s = if (dropped < 0) null else now_s - dropped;
        out.drops_24h = try int(db, "SELECT count(*) FROM raw.archive_dropped WHERE at > ?", .{now_s - std.time.s_per_day});
    }
    return out;
}

fn hasTable(db: store.Db, name: []const u8) !bool {
    return try db.scalar("SELECT 1 FROM raw.sqlite_master WHERE type = 'table' AND name = ?", .{name}) != null;
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
    if (d.kind == .raw) _ = try returnFree(db);
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
        \\WHERE acked_at IS NULL AND name NOT IN (SELECT name FROM raw.archive_received)
        \\ORDER BY from_s
    );
    defer s.deinit();
    const cwd = Io.Dir.cwd();
    while (try s.step()) {
        // No file: its window is lost already; a newer one may still free space
        const path = try exportFile(arena, io, dir, s.bytes(0)) orelse continue;
        const f = try cwd.openFile(io, path, .{});
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
        try deleteExportFiles(io, dir, d.name);
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
    try testing.expectEqual(0, try returnFree(db)); // auto_vacuum off: pages stay

    // Acking the newer export alone drops nothing: the older one still waits
    try ack(io, db, out, second.name, later);
    try testing.expectEqual(Pruned{ .summaries = 0, .timelines = 0 }, try pruneAcked(db, 0, later));
    try testing.expectEqual(1, (try status(db, later)).unacked);
    // Both acked: everything older than 2 days goes, the fresh summary stays
    try ack(io, db, out, first.name, later);
    try ack(io, db, out, first.name, later);
    try testing.expectEqual(Pruned{ .summaries = 1, .timelines = 0 }, try pruneAcked(db, 2, later));
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
    try ack(io, db, out, "raw-7-8.db", now);
    try testing.expectError(error.FileNotFound, cwd.access(io, stray, .{}));
    try testing.expectError(error.BadExportName, ack(io, db, out, "../raw-7-8.db", now));
    try testing.expectEqual(1, (try status(db, now)).unacked);
}

test "a backlog goes in windows; a received file goes before the ack, and stays exported" {
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
    const db = try store.open(arena, data);
    defer db.close();
    const hour = 3600;
    const now = 100 * std.time.s_per_day;
    // Five hours of backlog after a day with nothing
    try db.run("INSERT INTO raw.raw_docs VALUES ('riot_match', 'EUW1_1', ?, x'01'), ('riot_match', 'EUW1_2', ?, x'02')", .{
        now - 5 * hour, now - hour,
    });
    try db.run("INSERT INTO raw.timeline_docs VALUES ('EUW1_1', ?, x'03')", .{now - 5 * hour});

    const a = (try exportNew(arena, io, db, out, now)).?;
    try testing.expect(a.more);
    try testing.expectEqual(1, a.summaries);
    try testing.expectEqualStrings(try arena.print("raw-0-{d}.db", .{now - 3 * hour}), a.name);
    // Empty window between the two documents: the next export starts at EUW1_2
    const b = (try exportNew(arena, io, db, out, now)).?;
    try testing.expect(!b.more);
    try testing.expectEqual(1, b.summaries);
    try testing.expectEqual(null, try exportNew(arena, io, db, out, now));

    var buf: [256]u8 = undefined;
    var w: Io.Writer = .fixed(&buf);
    try list(arena, io, db, out, &w);
    try testing.expectEqual(2, std.mem.count(u8, w.buffered(), "\n"));
    try testing.expect(std.mem.startsWith(u8, w.buffered(), try arena.print("{s} ", .{a.name})));

    // The newest export received: its file goes, and the next export doesn't redo it
    try received(io, db, out, b.name, now);
    try received(io, db, out, b.name, now);
    try testing.expectError(error.FileNotFound, cwd.access(io, try arena.print("{s}/{s}", .{ out, b.name }), .{}));
    try testing.expectEqual(null, try exportNew(arena, io, db, out, now + 60));
    w = .fixed(&buf);
    try list(arena, io, db, out, &w);
    try testing.expect(std.mem.endsWith(u8, w.buffered(), try arena.print("{s} received\n", .{b.name})));
    // Received yet unacked: summaries stay, and the valve passes it over
    try testing.expectEqual(Pruned{ .summaries = 0, .timelines = 0 }, try pruneAcked(db, 0, now));
    const saved = testing.log_level;
    defer testing.log_level = saved;
    testing.log_level = .err;
    const log_path = try arena.print("{s}/raw-dropped.log", .{data});
    try testing.expectEqualStrings(a.name, (try valve(arena, io, db, out, log_path, 1, 2, now)).?.name);
    try testing.expectEqual(null, try valve(arena, io, db, out, log_path, 1, 2, now));

    try ack(io, db, out, b.name, now);
    try testing.expectError(error.NotUnacked, received(io, db, out, b.name, now));
    try testing.expectEqual(Pruned{ .summaries = 2, .timelines = 0 }, try pruneAcked(db, 0, now));
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

test "status reads only, on a box that never exported" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const data = try arena.print(".zig-cache/tmp/{s}/data", .{&tmp.sub_path});
    try Io.Dir.cwd().createDirPath(io, data);
    const db = try store.open(arena, data);
    db.close();
    const ro = try store.schema.openReadOnly(arena, data);
    defer ro.close();
    const st = try status(ro, 100);
    try testing.expectEqual(null, st.since_ack_s);
    try testing.expectEqual(0, st.unacked);
    try testing.expectEqual(null, st.since_drop_s);
}

test "freed raw pages go back to the disk once auto_vacuum is incremental" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const data = try arena.print(".zig-cache/tmp/{s}/data", .{&tmp.sub_path});
    try Io.Dir.cwd().createDirPath(io, data);
    const db = try store.open(arena, data);
    defer db.close();
    try db.exec("PRAGMA raw.auto_vacuum = INCREMENTAL; VACUUM raw");
    try db.exec(
        \\WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < 2000)
        \\INSERT INTO raw.timeline_docs SELECT 'EUW1_' || i, 1, randomblob(4000) FROM n
    );
    const pages = try int(db, "PRAGMA raw.page_count", .{});
    try db.exec("DELETE FROM raw.timeline_docs");
    try testing.expect(try int(db, "PRAGMA raw.freelist_count", .{}) > 0);
    try testing.expect(try returnFree(db) > 4000 * 1000);
    try testing.expectEqual(0, try int(db, "PRAGMA raw.freelist_count", .{}));
    try testing.expect(try int(db, "PRAGMA raw.page_count", .{}) < @divFloor(pages, 10));
}

test "a packed export lists, sends and goes as its pack; the window stays exported" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = testing.io;
    const gpa = testing.allocator;
    const r = std.process.run(gpa, io, .{ .argv = &.{ "zstd", "--version" } }) catch return error.SkipZigTest;
    gpa.free(r.stdout);
    gpa.free(r.stderr);
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try arena.print(".zig-cache/tmp/{s}", .{&tmp.sub_path});
    const data = try arena.print("{s}/data", .{base});
    const out = try arena.print("{s}/out", .{base});
    const cwd = Io.Dir.cwd();
    try cwd.createDirPath(io, data);
    const db = try store.open(arena, data);
    defer db.close();
    const now = 100 * std.time.s_per_day;
    const json = "{\"metadata\":{\"matchId\":\"EUW1_1\",\"participants\":[]},\"info\":{}}";
    const body = try store.raw.compress(arena, json);
    try db.run("INSERT INTO raw.raw_docs VALUES ('riot_match', 'EUW1_1', ?, ?), ('riot_match', 'EUW1_2', ?, x'00')", .{
        now - 3600, store.Blob{ .bytes = body }, now - 3601,
    });
    try db.run("INSERT INTO raw.timeline_docs VALUES ('EUW1_1', ?, ?)", .{ now - 3600, store.Blob{ .bytes = body } });
    try db.run("INSERT INTO mastery VALUES ('p1', NULL, ?, 3, x'0102')", .{now - 3600});

    const e = (try exportNew(arena, io, db, out, now)).?;
    const p = (try pack(gpa, io, out, e.name, 3)).?;
    try testing.expectEqual(4, p.docs);
    try testing.expectEqual(null, try pack(gpa, io, out, e.name, 3));
    const db_path = try arena.print("{s}/{s}", .{ out, e.name });
    const zst_path = try arena.print("{s}.zst", .{db_path});
    try testing.expectError(error.FileNotFound, cwd.access(io, db_path, .{}));
    try testing.expectEqual(store.rawpack.Counts{ .summaries = 2, .timelines = 1, .mastery = 1 }, try readPack(gpa, io, zst_path));

    // Bodies plain, in fetched_at order; the one that isn't gzip as stored
    const plain = try std.process.run(gpa, io, .{ .argv = &.{ "zstd", "-dc", "-q", zst_path }, .stdout_limit = .unlimited });
    defer gpa.free(plain.stdout);
    defer gpa.free(plain.stderr);
    var in: Io.Reader = .fixed(plain.stdout);
    var rd = try store.rawpack.Reader.init(gpa, &in);
    defer rd.deinit();
    const first = (try rd.next()).?.summary;
    try testing.expectEqualStrings("EUW1_2", first.key);
    try testing.expectEqual(store.rawpack.Encoding.stored, first.encoding);
    try testing.expectEqualStrings(json, (try rd.next()).?.summary.body);
    try testing.expectEqualStrings(json, (try rd.next()).?.timeline.body);
    try testing.expectEqual(@as(?[]const u8, null), (try rd.next()).?.mastery.platform);

    var buf: [256]u8 = undefined;
    var w: Io.Writer = .fixed(&buf);
    try list(arena, io, db, out, &w);
    try testing.expectEqualStrings(try arena.print("{s} {d}\n", .{ e.name, p.zst_bytes }), w.buffered());
    // A later export must not take the pack's window for a lost file
    try testing.expectEqual(null, try exportNew(arena, io, db, out, now + 60));
    try testing.expectEqual(1, try int(db, "SELECT count(*) FROM raw.archive_exports", .{}));
    try received(io, db, out, e.name, now);
    try testing.expectError(error.FileNotFound, cwd.access(io, zst_path, .{}));
}
