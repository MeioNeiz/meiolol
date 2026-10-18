//! Backups (`meiolol backup`, `meiolol restore`). docs/data-safety.md has the why.
//!
//! Two kinds of file, both plain SQLite, so `meiolol forget --backups` can scrub them:
//! - state/state-YYYY-MM-DD.db: the mutable tables (queues, forgotten, ...), rotated
//!   (7 daily + 4 weekly by default)
//! - mastery/NNNNNN.db: mastery rows fetched since the last one (by fetched_at), the
//!   `mastery_range` table holding its window. Restore loads them in order, so each
//!   player's newest wins; a file goes once its window is past the crawler's 30-day
//!   mastery prune. Out of state: a full copy a day was 3.4 GB at 3.1M rows (17 Oct)
//! - segments/NNNNNN.db: matches, participants and bans of matches stored since the last
//!   segment, and compact timelines and draft rows (store/draft.zig) likewise. These
//!   rows never change once stored, so segments are append-only and kept; the `segment`
//!   table holds each one's rowid range.
//!   `--full` writes one segment with everything and drops the older ones (after a
//!   rebuild or rekey, which rewrite stored rows)
//! Raw JSON is not backed up: raw.db is a 30-day buffer and the tables hold what it gives.
//! Mirrors (the Mac, the gpu-box: deploy/backup-mirror.sh) keep every segment and their
//! own rotation of state; `--mirror DIR` tends one: scrubs PUUIDs the box has forgotten
//! since, then rotates. The box prunes what a mirror has acked (deploy/backup-serve.sh).
//! Each file is written as *.tmp in one read transaction (a consistent snapshot while the
//! crawler writes) and renamed when complete.

const std = @import("std");
const store = @import("store");
const forget = @import("forget.zig");
const Date = @import("date.zig").Date;

const Db = store.Db;
const Io = std.Io;
const log = std.log.scoped(.backup);

/// Not players or ladder_pages: crawl state the crawler re-seeds from Riot's ladders
/// within a day of a restore (at the cost of rescanning everyone's match ids). At ~9M
/// players they are ~3 GB per snapshot, more than the box's disk holds 11 times over, and
/// millions of PUUIDs kept out of backups
pub const state_tables = [_][]const u8{
    "match_queue",
    "timeline_queue",
    "champions",
    "forgotten",
};

pub const Options = struct {
    data_dir: []const u8,
    out_dir: []const u8,
    keep_daily: usize = 7,
    keep_weekly: usize = 4,
    full: bool = false,
    now: i64,
};

pub const Summary = struct {
    state: []const u8,
    segment: ?[]const u8,
    mastery: i64,
    matches: i64,
    timelines: i64,
    drafts: i64,
    rank_history: i64,
    removed: usize,
};

pub fn run(arena: std.mem.Allocator, io: Io, opts: Options) !Summary {
    const cwd = Io.Dir.cwd();
    const state_dir = try std.fs.path.join(arena, &.{ opts.out_dir, "state" });
    const seg_dir = try std.fs.path.join(arena, &.{ opts.out_dir, "segments" });
    try cwd.createDirPath(io, state_dir);
    try cwd.createDirPath(io, seg_dir);

    // Not store.open: that runs migrations under the write lock, which on a slow host
    // starve the crawler. Backups copy each table's live DDL, whatever its version
    const main_db = try std.fs.path.join(arena, &.{ opts.data_dir, "meiolol.db" });
    const timeline_db = try std.fs.path.join(arena, &.{ opts.data_dir, "timeline.db" });
    // ATTACH would create a missing file
    try cwd.access(io, main_db, .{});
    try cwd.access(io, timeline_db, .{});

    const state_path = try arena.print("{s}/state-{f}.db", .{ state_dir, Date.fromSeconds(opts.now) });
    _ = try writeFile(arena, io, state_path, main_db, timeline_db, .state, .{}, opts.now);

    var removed = try rotate(arena, io, state_dir, opts.keep_daily, opts.keep_weekly);

    const m_dir = try std.fs.path.join(arena, &.{ opts.out_dir, "mastery" });
    try cwd.createDirPath(io, m_dir);
    const ms = try listSegments(arena, io, m_dir);
    var m_after: Range = .{};
    if (!opts.full and ms.len > 0) {
        m_after = try readMasteryRange(arena, try std.fs.path.join(arena, &.{ m_dir, ms[ms.len - 1].name }));
    }
    const m_next = if (ms.len > 0) ms[ms.len - 1].seq + 1 else 1;
    const m_path = try arena.print("{s}/{d:0>6}.db", .{ m_dir, m_next });
    const m_wrote = try writeFile(arena, io, m_path, main_db, timeline_db, .mastery, m_after, opts.now);
    if (m_wrote.rows > 0 and opts.full) {
        for (ms) |s| {
            try cwd.deleteFile(io, try std.fs.path.join(arena, &.{ m_dir, s.name }));
            removed += 1;
        }
    }
    removed += try rotateMastery(arena, io, m_dir, opts.now);
    log.info("mastery: {d} rows fetched since the last backup", .{m_wrote.rows});

    const segs = try listSegments(arena, io, seg_dir);
    var after: Range = .{};
    if (!opts.full and segs.len > 0) {
        const last = try std.fs.path.join(arena, &.{ seg_dir, segs[segs.len - 1].name });
        after = try readRange(arena, last);
    }
    const next = if (segs.len > 0) segs[segs.len - 1].seq + 1 else 1;
    const seg_path = try arena.print("{s}/{d:0>6}.db", .{ seg_dir, next });
    const wrote = try writeFile(arena, io, seg_path, main_db, timeline_db, .segment, after, opts.now);
    if (wrote.rows > 0 and opts.full) {
        for (segs) |s| {
            try cwd.deleteFile(io, try std.fs.path.join(arena, &.{ seg_dir, s.name }));
            removed += 1;
        }
    }
    return .{
        .state = state_path,
        .segment = if (wrote.rows > 0) seg_path else null,
        .mastery = m_wrote.rows,
        .matches = wrote.matches,
        .timelines = wrote.timelines,
        .drafts = wrote.drafts,
        .rank_history = wrote.rank_history,
        .removed = removed,
    };
}

const Kind = enum { state, segment, mastery };

/// The crawler's writer stamps fetched_at when its transaction begins: a mastery file
/// stops this short of now, so a row still being written goes in the next one
/// (archive.zig's exports likewise)
const mastery_margin_s = 300;

/// riot/writer.zig drops mastery fetched over 30 days ago: a file whose whole window is
/// older than that (and a margin) holds nothing the live table still has
const mastery_keep_s = 32 * std.time.s_per_day;

const Written = struct { rows: i64 = 0, matches: i64 = 0, timelines: i64 = 0, drafts: i64 = 0, rank_history: i64 = 0 };

/// Build `path` from the live databases inside one read transaction. A segment with no
/// new rows is not kept.
fn writeFile(
    arena: std.mem.Allocator,
    io: Io,
    path: []const u8,
    main_db: []const u8,
    timeline_db: []const u8,
    kind: Kind,
    after: Range,
    now: i64,
) !Written {
    const cwd = Io.Dir.cwd();
    const tmp = try arena.printSentinel("{s}.tmp", .{path}, 0);
    cwd.deleteFile(io, tmp) catch |err| if (err != error.FileNotFound) return err;
    var w: Written = .{};
    {
        const db = try Db.open(tmp);
        defer db.close();
        // A tmp file renamed only when complete needs no journal; FULL sync still makes
        // the commit durable before the rename
        try db.exec("PRAGMA journal_mode = OFF; PRAGMA synchronous = FULL");
        try db.run("ATTACH DATABASE ? AS live", .{main_db});
        try db.run("ATTACH DATABASE ? AS livet", .{timeline_db});
        try db.exec("BEGIN");
        errdefer db.rollback();
        switch (kind) {
            .state => for (state_tables) |t| {
                if (!try copyDdl(arena, db, "live", t)) continue;
                try copyRows(arena, db, "live", t, "");
            },
            .segment => {
                const to_m = try db.scalar("SELECT coalesce(max(rowid), 0) FROM live.matches", .{}) orelse 0;
                const to_t = try db.scalar("SELECT coalesce(max(rowid), 0) FROM livet.timelines", .{}) orelse 0;
                // A database no binary with drafts has opened yet lacks the table
                const drafts = try copyDdl(arena, db, "live", "drafts");
                const to_d = if (!drafts) after.drafts_to else try db.scalar(
                    "SELECT coalesce(max(id), 0) FROM live.drafts",
                    .{},
                ) orelse 0;
                try db.exec(
                    \\CREATE TABLE segment (matches_after INTEGER NOT NULL, matches_to INTEGER NOT NULL,
                    \\    timelines_after INTEGER NOT NULL, timelines_to INTEGER NOT NULL,
                    \\    made_at INTEGER NOT NULL, drafts_after INTEGER NOT NULL DEFAULT 0,
                    \\    drafts_to INTEGER NOT NULL DEFAULT 0, history_after INTEGER NOT NULL DEFAULT 0,
                    \\    history_to INTEGER NOT NULL DEFAULT 0);
                );
                // rank_history by day: a day's rows change until it ends, so whole days only
                const history = try copyDdl(arena, db, "live", "rank_history");
                const to_h = if (history) @divFloor(now, std.time.s_per_day) - 1 else after.history_to;
                try db.run("INSERT INTO segment VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", .{
                    after.matches_to, to_m, after.timelines_to, to_t, now, after.drafts_to, to_d,
                    after.history_to, to_h,
                });
                for ([_][]const u8{ "matches", "participants", "bans" }) |t| _ = try copyDdl(arena, db, "live", t);
                _ = try copyDdl(arena, db, "livet", "timelines");
                try copyRows(arena, db, "live", "matches", try arena.print(
                    " WHERE rowid > {d} AND rowid <= {d}",
                    .{ after.matches_to, to_m },
                ));
                w.matches = db.changes();
                // Same transaction as the match row in the crawler, so never half a match
                const of_matches = " WHERE match_id IN (SELECT match_id FROM main.matches)";
                try copyRows(arena, db, "live", "participants", of_matches);
                try copyRows(arena, db, "live", "bans", of_matches);
                try copyRows(arena, db, "livet", "timelines", try arena.print(
                    " WHERE rowid > {d} AND rowid <= {d}",
                    .{ after.timelines_to, to_t },
                ));
                w.timelines = db.changes();
                if (drafts) {
                    try copyRows(arena, db, "live", "drafts", try arena.print(
                        " WHERE id > {d} AND id <= {d}",
                        .{ after.drafts_to, to_d },
                    ));
                    w.drafts = db.changes();
                }
                if (history) {
                    try copyRows(arena, db, "live", "rank_history", try arena.print(
                        " WHERE day > {d} AND day <= {d}",
                        .{ after.history_to, to_h },
                    ));
                    w.rank_history = db.changes();
                }
                w.rows = w.matches + w.timelines + w.drafts + w.rank_history;
            },
            .mastery => {
                try db.exec(
                    \\CREATE TABLE mastery_range (after_s INTEGER NOT NULL, to_s INTEGER NOT NULL,
                    \\    made_at INTEGER NOT NULL);
                );
                const to = now - mastery_margin_s;
                try db.run("INSERT INTO mastery_range VALUES (?, ?, ?)", .{ after.mastery_to, to, now });
                if (try copyDdl(arena, db, "live", "mastery")) {
                    try copyRows(arena, db, "live", "mastery", try arena.print(
                        " WHERE fetched_at > {d} AND fetched_at <= {d}",
                        .{ after.mastery_to, to },
                    ));
                    w.rows = db.changes();
                }
            },
        }
        try db.exec("COMMIT");
    }
    if (kind != .state and w.rows == 0) {
        try cwd.deleteFile(io, tmp);
        return w;
    }
    try cwd.rename(tmp, cwd, path, io);
    return w;
}

/// Create `table` in the backup's main schema with the live table's own DDL (column
/// order included, so SELECT * copies line up). false when the live side lacks it.
fn copyDdl(arena: std.mem.Allocator, db: Db, from: []const u8, table: []const u8) !bool {
    var s = try db.prepare(try arena.print(
        "SELECT sql FROM {s}.sqlite_master WHERE type = 'table' AND name = ?",
        .{from},
    ));
    defer s.deinit();
    try s.bind(.{table});
    if (!try s.step()) return false;
    try db.exec(try arena.dupeSentinel(u8, s.bytes(0), 0));
    return true;
}

fn copyRows(arena: std.mem.Allocator, db: Db, from: []const u8, table: []const u8, where: []const u8) !void {
    try db.exec(try arena.printSentinel(
        "INSERT INTO main.{s} SELECT * FROM {s}.{s}{s}",
        .{ table, from, table, where },
        0,
    ));
}

const Segment = struct { seq: u32, name: []const u8 };

fn lessSeq(_: void, a: Segment, b: Segment) bool {
    return a.seq < b.seq;
}

pub fn listSegments(arena: std.mem.Allocator, io: Io, seg_dir: []const u8) ![]Segment {
    var dir = try Io.Dir.cwd().openDir(io, seg_dir, .{ .iterate = true });
    defer dir.close(io);
    var out: std.ArrayList(Segment) = .empty;
    var it = dir.iterate();
    while (try it.next(io)) |e| {
        if (e.kind != .file or !std.mem.endsWith(u8, e.name, ".db")) continue;
        const seq = std.fmt.parseInt(u32, e.name[0 .. e.name.len - 3], 10) catch continue;
        try out.append(arena, .{ .seq = seq, .name = try arena.dupe(u8, e.name) });
    }
    std.mem.sort(Segment, out.items, {}, lessSeq);
    return out.items;
}

/// Last rowid (drafts: id; rank_history: day; mastery: fetched_at) each file copied up to
const Range = struct {
    matches_to: i64 = 0,
    timelines_to: i64 = 0,
    drafts_to: i64 = 0,
    history_to: i64 = 0,
    mastery_to: i64 = 0,
};

const MasteryRange = struct { after_s: i64, to_s: i64 };

fn masteryRange(arena: std.mem.Allocator, path: []const u8) !MasteryRange {
    const db = try Db.open(try arena.dupeSentinel(u8, path, 0));
    defer db.close();
    var s = try db.prepare("SELECT after_s, to_s FROM mastery_range");
    defer s.deinit();
    if (!try s.step()) return error.BadSegment;
    return s.row(MasteryRange);
}

fn readMasteryRange(arena: std.mem.Allocator, path: []const u8) !Range {
    return .{ .mastery_to = (try masteryRange(arena, path)).to_s };
}

/// Delete mastery files whose window is past `mastery_keep_s`, never the newest (the
/// next backup starts where it ends). Returns how many were deleted.
fn rotateMastery(arena: std.mem.Allocator, io: Io, dir: []const u8, now: i64) !usize {
    const files = listSegments(arena, io, dir) catch |err| switch (err) {
        error.FileNotFound => return 0,
        else => return err,
    };
    if (files.len < 2) return 0;
    var n: usize = 0;
    for (files[0 .. files.len - 1]) |f| {
        const path = try std.fs.path.join(arena, &.{ dir, f.name });
        if ((try masteryRange(arena, path)).to_s >= now - mastery_keep_s) continue;
        try Io.Dir.cwd().deleteFile(io, path);
        n += 1;
    }
    return n;
}

fn readRange(arena: std.mem.Allocator, path: []const u8) !Range {
    const db = try Db.open(try arena.dupeSentinel(u8, path, 0));
    defer db.close();
    // Segments from before drafts or rank_history lack those columns: the next one
    // copies them all
    var s = try db.prepare(try arena.printSentinel(
        "SELECT matches_to, timelines_to, {s}, {s}, 0 FROM segment",
        .{ try segmentColumn(db, "drafts_to"), try segmentColumn(db, "history_to") },
        0,
    ));
    defer s.deinit();
    if (!try s.step()) return error.BadSegment;
    return s.row(Range);
}

fn isFull(arena: std.mem.Allocator, path: []const u8) !bool {
    const db = try Db.open(try arena.dupeSentinel(u8, path, 0));
    defer db.close();
    const after = try db.scalar("SELECT matches_after + timelines_after FROM segment", .{}) orelse
        return error.BadSegment;
    return after == 0;
}

fn segmentColumn(db: Db, name: []const u8) ![]const u8 {
    const n = try db.scalar("SELECT count(*) FROM pragma_table_info('segment') WHERE name = ?", .{name});
    return if ((n orelse 0) > 0) name else "0";
}

/// Keep the newest `daily` snapshots, plus the newest of each of the `weekly` most recent
/// weeks. Returns how many were deleted.
fn rotate(arena: std.mem.Allocator, io: Io, state_dir: []const u8, daily: usize, weekly: usize) !usize {
    var dir = try Io.Dir.cwd().openDir(io, state_dir, .{ .iterate = true });
    defer dir.close(io);
    var names: std.ArrayList([]const u8) = .empty;
    var it = dir.iterate();
    while (try it.next(io)) |e| {
        if (e.kind == .file and dateOf(e.name) != null) try names.append(arena, try arena.dupe(u8, e.name));
    }
    const doomed = try toDelete(arena, names.items, daily, weekly);
    for (doomed) |n| try dir.deleteFile(io, n);
    return doomed.len;
}

fn greaterName(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.order(u8, a, b) == .gt;
}

fn toDelete(arena: std.mem.Allocator, names: [][]const u8, daily: usize, weekly: usize) ![][]const u8 {
    std.mem.sort([]const u8, names, {}, greaterName);
    var weeks: std.AutoHashMapUnmanaged(i64, void) = .empty;
    var out: std.ArrayList([]const u8) = .empty;
    for (names, 0..) |n, i| {
        const week = @divFloor(dateOf(n).?, 7);
        const newest_of_week = !weeks.contains(week);
        if (newest_of_week) try weeks.put(arena, week, {});
        if (i < daily or (newest_of_week and weeks.count() <= weekly)) continue;
        try out.append(arena, n);
    }
    return out.items;
}

/// Days since 1970-01-01 from "state-YYYY-MM-DD.db"
fn dateOf(name: []const u8) ?i64 {
    if (name.len != "state-YYYY-MM-DD.db".len or !std.mem.startsWith(u8, name, "state-") or
        !std.mem.endsWith(u8, name, ".db")) return null;
    const d = Date.parse(name["state-".len..][0.."YYYY-MM-DD".len]) orelse return null;
    return d.toDay();
}

pub const Restored = struct { files: usize, matches: i64, timelines: i64, mastery: i64, removed: forget.Removed };

/// Rebuild `data_dir` (which must not hold a database yet) from the newest state
/// snapshot (or `state_file`) and every segment in order, then re-apply erasures
/// recorded since. Columns are matched by name, so an older backup restores into a newer
/// schema.
pub fn restore(arena: std.mem.Allocator, io: Io, from_dir: []const u8, data_dir: []const u8, state_file: ?[]const u8, now: i64) !Restored {
    const cwd = Io.Dir.cwd();
    const target = try std.fs.path.join(arena, &.{ data_dir, "meiolol.db" });
    if (cwd.access(io, target, .{})) |_| {
        return error.TargetNotEmpty;
    } else |err| if (err != error.FileNotFound) return err;
    try cwd.createDirPath(io, data_dir);

    const state_dir = try std.fs.path.join(arena, &.{ from_dir, "state" });
    const state = state_file orelse blk: {
        var dir = try cwd.openDir(io, state_dir, .{ .iterate = true });
        defer dir.close(io);
        var newest: ?[]const u8 = null;
        var it = dir.iterate();
        while (try it.next(io)) |e| {
            if (e.kind != .file or dateOf(e.name) == null) continue;
            if (newest == null or std.mem.order(u8, e.name, newest.?) == .gt) newest = try arena.dupe(u8, e.name);
        }
        break :blk try std.fs.path.join(arena, &.{ state_dir, newest orelse return error.NoStateSnapshot });
    };

    const db = try store.open(arena, data_dir);
    defer db.close();
    try forget.ensure(db);
    var r: Restored = .{ .files = 0, .matches = 0, .timelines = 0, .mastery = 0, .removed = .{} };
    try load(arena, db, state);
    r.files += 1;
    const m_dir = try std.fs.path.join(arena, &.{ from_dir, "mastery" });
    const ms = listSegments(arena, io, m_dir) catch |err| switch (err) {
        error.FileNotFound => &.{},
        else => return err,
    };
    // As for segments: a --full mastery file starts from the beginning
    var m_first: usize = 0;
    for (ms, 0..) |s, i| {
        if ((try masteryRange(arena, try std.fs.path.join(arena, &.{ m_dir, s.name }))).after_s == 0) m_first = i;
    }
    for (ms[m_first..]) |s| {
        try load(arena, db, try std.fs.path.join(arena, &.{ m_dir, s.name }));
        r.files += 1;
    }
    r.mastery = try db.scalar("SELECT count(*) FROM mastery", .{}) orelse 0;
    const seg_dir = try std.fs.path.join(arena, &.{ from_dir, "segments" });
    const segs = try listSegments(arena, io, seg_dir);
    // A mirror keeps the segments a --full backup replaced on the box: start at the
    // newest one that copied from the beginning
    var first: usize = 0;
    for (segs, 0..) |s, i| {
        if (try isFull(arena, try std.fs.path.join(arena, &.{ seg_dir, s.name }))) first = i;
    }
    for (segs[first..]) |s| {
        try load(arena, db, try std.fs.path.join(arena, &.{ seg_dir, s.name }));
        r.files += 1;
    }
    r.matches = try db.scalar("SELECT count(*) FROM matches", .{}) orelse 0;
    r.timelines = try db.scalar("SELECT count(*) FROM timeline.timelines", .{}) orelse 0;
    r.removed = try forget.reapply(arena, db, now);
    return r;
}

/// Copy every table of a backup file into the live schema, by column name. Later files
/// win (INSERT OR REPLACE), so a `--full` segment, a re-extracted timeline or a newer
/// mastery fetch overrides.
fn load(arena: std.mem.Allocator, db: Db, path: []const u8) !void {
    try db.run("ATTACH DATABASE ? AS b", .{path});
    defer db.exec("DETACH DATABASE b") catch {};
    var tables: std.ArrayList([]const u8) = .empty;
    {
        var s = try db.prepare(
            \\SELECT name FROM b.sqlite_master
            \\WHERE type = 'table' AND name NOT IN ('segment', 'mastery_range')
        );
        defer s.deinit();
        while (try s.step()) try tables.append(arena, try arena.dupe(u8, s.bytes(0)));
    }
    try db.begin();
    errdefer db.rollback();
    for (tables.items) |t| {
        const schema: []const u8 = if (std.mem.eql(u8, t, "timelines")) "timeline" else "main";
        var cols: std.ArrayList(u8) = .empty;
        var s = try db.prepare(
            \\SELECT b.name FROM pragma_table_info(?1, 'b') b
            \\JOIN pragma_table_info(?1, ?2) l ON l.name = b.name ORDER BY b.cid
        );
        defer s.deinit();
        try s.bind(.{ t, schema });
        while (try s.step()) {
            if (cols.items.len > 0) try cols.append(arena, ',');
            try cols.print(arena, "\"{s}\"", .{s.bytes(0)});
        }
        if (cols.items.len == 0) {
            log.warn("{s}: table {s} is not in the schema, skipped", .{ path, t });
            continue;
        }
        try db.exec(try arena.printSentinel(
            "INSERT OR REPLACE INTO {s}.{s} ({s}) SELECT {s} FROM b.{s}",
            .{ schema, t, cols.items, cols.items, t },
            0,
        ));
    }
    try db.commit();
}

/// Erase `puuid` from every backup file under `dir` (forget --backups)
pub fn scrub(arena: std.mem.Allocator, io: Io, dir: []const u8, puuid: []const u8, now: i64) !forget.Removed {
    return scrubMany(arena, io, dir, &.{puuid}, now);
}

/// As scrub, every file opened once for all of `puuids`
pub fn scrubMany(arena: std.mem.Allocator, io: Io, dir: []const u8, puuids: []const []const u8, now: i64) !forget.Removed {
    var total: forget.Removed = .{};
    if (puuids.len == 0) return total;
    for ([_][]const u8{ "state", "segments", "mastery" }) |sub| {
        const path = try std.fs.path.join(arena, &.{ dir, sub });
        var d = Io.Dir.cwd().openDir(io, path, .{ .iterate = true }) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return err,
        };
        defer d.close(io);
        var it = d.iterate();
        while (try it.next(io)) |e| {
            if (e.kind != .file or !std.mem.endsWith(u8, e.name, ".db")) continue;
            const file = try arena.printSentinel("{s}/{s}", .{ path, e.name }, 0);
            const db = try Db.open(file);
            defer db.close();
            for (puuids) |p| total.add(try forget.forget(db, p, now, .scrub));
        }
    }
    return total;
}

pub const Tended = struct { new_forgotten: usize, removed: forget.Removed, rotated: usize };

/// A mirror's upkeep: PUUIDs in `forgotten_path` (the box's complete list) not yet in
/// DIR/forgotten-applied.txt are scrubbed from every file, then state rotates as on the
/// box. Segments are never deleted here: the box may have pruned its copy
pub fn tendMirror(
    arena: std.mem.Allocator,
    io: Io,
    dir: []const u8,
    forgotten_path: []const u8,
    keep_daily: usize,
    keep_weekly: usize,
    now: i64,
) !Tended {
    const cwd = Io.Dir.cwd();
    const applied_path = try std.fs.path.join(arena, &.{ dir, "forgotten-applied.txt" });
    var applied: std.StringHashMapUnmanaged(void) = .empty;
    const old = cwd.readFileAlloc(io, applied_path, arena, .limited(256 << 20)) catch |err| switch (err) {
        error.FileNotFound => "",
        else => return err,
    };
    var lines = std.mem.tokenizeAny(u8, old, "\r\n");
    while (lines.next()) |l| try applied.put(arena, l, {});

    const listed = try cwd.readFileAlloc(io, forgotten_path, arena, .limited(256 << 20));
    var fresh: std.ArrayList([]const u8) = .empty;
    lines = std.mem.tokenizeAny(u8, listed, "\r\n");
    while (lines.next()) |line| {
        const p = std.mem.trim(u8, line, " \t");
        if (p.len == 0 or applied.contains(p)) continue;
        try applied.put(arena, p, {});
        try fresh.append(arena, p);
    }
    const removed = try scrubMany(arena, io, dir, fresh.items, now);
    if (fresh.items.len > 0) {
        // Only once every file is scrubbed: a crash before this repeats the scrub
        var out: std.Io.Writer.Allocating = .init(arena);
        try out.writer.writeAll(old);
        if (old.len > 0 and old[old.len - 1] != '\n') try out.writer.writeByte('\n');
        for (fresh.items) |p| try out.writer.print("{s}\n", .{p});
        const tmp = try arena.print("{s}.tmp", .{applied_path});
        try cwd.writeFile(io, .{ .sub_path = tmp, .data = out.written() });
        try cwd.rename(tmp, cwd, applied_path, io);
    }
    const state_dir = try std.fs.path.join(arena, &.{ dir, "state" });
    try cwd.createDirPath(io, state_dir);
    const rotated = try rotate(arena, io, state_dir, keep_daily, keep_weekly);
    const m_rotated = try rotateMastery(arena, io, try std.fs.path.join(arena, &.{ dir, "mastery" }), now);
    if (m_rotated > 0) log.info("{s}: {d} old mastery files removed", .{ dir, m_rotated });
    return .{ .new_forgotten = fresh.items.len, .removed = removed, .rotated = rotated };
}

const testing = std.testing;

test "rotation keeps 7 daily and the newest of 4 weeks" {
    var names: std.ArrayList([]const u8) = .empty;
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    // 40 consecutive days, 2026-09-01 .. 2026-10-10
    const start = (Date{ .year = 2026, .month = 9, .day = 1 }).toDay();
    for (0..40) |i| {
        const date: Date = .fromDay(start + @as(i64, @intCast(i)));
        try names.append(arena, try arena.print("state-{f}.db", .{date}));
    }
    const doomed = try toDelete(arena, names.items, 7, 4);
    // Kept: 7 newest days (Oct 4-10) + newest of each of the 4 newest weeks; two of those
    // weeks' newest days are among the 7, so 7 + 2 kept
    try testing.expectEqual(40 - 9, doomed.len);
    for (doomed) |n| try testing.expect(!std.mem.eql(u8, n, "state-2026-10-10.db"));
}

test "backup then restore round trip, incremental segments, scrub" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try arena.print(".zig-cache/tmp/{s}", .{&tmp.sub_path});
    const data = try arena.print("{s}/data", .{base});
    const out = try arena.print("{s}/backups", .{base});
    try Io.Dir.cwd().createDirPath(io, data);

    {
        const db = try store.open(arena, data);
        defer db.close();
        try db.exec(
            \\INSERT INTO players (puuid, source) VALUES ('p1', 'ladder'), ('p2', 'ladder');
            \\INSERT INTO matches VALUES ('EUW1_1', 'riot', 'EUW1', 420, '16.20', '16.20.1', 1, 1800, 100, 0);
            \\INSERT INTO participants (match_id, slot, team_id, puuid, champion_id, win)
            \\    VALUES ('EUW1_1', 0, 100, 'p1', 1, 1), ('EUW1_1', 1, 200, 'p2', 2, 0);
            \\INSERT INTO bans VALUES ('EUW1_1', 100, 1, 9);
            \\INSERT INTO timeline.timelines VALUES ('EUW1_1', 30, 100, x'01');
            \\INSERT INTO drafts (id, platform, queue, patch, day, ranked, blue_win, picks, bans)
            \\    VALUES (7, 'EUW1', 420, '16.20', 1, 0, 1, x'', x'');
        );
        try db.run("INSERT INTO rank_history VALUES (?, 20736, 20, 0, 1, 0), (?, 20736, 20, 0, 1, 0)", .{
            store.schema.puuidKey("p1"), store.schema.puuidKey("p2"),
        });
    }
    const day = 86400 * 20737;
    {
        const db = try store.open(arena, data);
        defer db.close();
        try db.run("INSERT INTO mastery VALUES ('p1', 'EUW1', ?1, 1, x'01'), ('p2', 'EUW1', ?1, 1, x'02')", .{day - 1000});
    }
    const first = try run(arena, io, .{ .data_dir = data, .out_dir = out, .now = day });
    try testing.expectEqual(1, first.matches);
    try testing.expectEqual(1, first.timelines);
    try testing.expectEqual(1, first.drafts);
    try testing.expectEqual(2, first.rank_history);
    try testing.expectEqual(2, first.mastery);
    {
        const st = try Db.open(try arena.printSentinel("{s}", .{first.state}, 0));
        defer st.close();
        try testing.expectEqual(@as(?i64, 0), try st.scalar("SELECT count(*) FROM sqlite_master WHERE name = 'mastery'", .{}));
    }
    // Nothing new: no segment, no mastery file
    const idle = try run(arena, io, .{ .data_dir = data, .out_dir = out, .now = day + 86400 });
    try testing.expectEqual(null, idle.segment);
    try testing.expectEqual(0, idle.mastery);
    {
        const db = try store.open(arena, data);
        defer db.close();
        try db.exec(
            \\INSERT INTO matches VALUES ('EUW1_2', 'riot', 'EUW1', 420, '16.20', '16.20.1', 2, 1700, 200, 0);
            \\INSERT INTO participants (match_id, slot, team_id, puuid, champion_id, win)
            \\    VALUES ('EUW1_2', 0, 100, 'p1', 3, 0);
        );
        // The second backup's today: in the third, once the day is over
        try db.run("INSERT INTO rank_history VALUES (?, 20738, 20, 9, 2, 0), (?, 20739, 20, 9, 2, 0)", .{
            store.schema.puuidKey("p1"), store.schema.puuidKey("p2"),
        });
        try db.run("INSERT OR REPLACE INTO mastery VALUES ('p2', 'EUW1', ?, 2, x'03')", .{day + 2 * 86400 - 1000});
    }
    const second = try run(arena, io, .{ .data_dir = data, .out_dir = out, .now = day + 2 * 86400 });
    try testing.expectEqual(1, second.matches);
    try testing.expectEqual(0, second.timelines);
    try testing.expectEqual(0, second.drafts);
    try testing.expectEqual(1, second.rank_history);
    try testing.expectEqual(1, second.mastery);
    try testing.expectEqual(2, (try listSegments(arena, io, try arena.print("{s}/segments", .{out}))).len);
    try testing.expectEqual(2, (try listSegments(arena, io, try arena.print("{s}/mastery", .{out}))).len);

    // p1 objects after the backups were taken: live forget records it, scrub cleans files
    {
        const db = try store.open(arena, data);
        defer db.close();
        _ = try forget.forget(db, "p1", day, .record);
    }
    const scrubbed = try scrub(arena, io, out, "p1", day);
    try testing.expectEqual(2, scrubbed.participants);
    try testing.expectEqual(2, scrubbed.rank_history);
    try testing.expectEqual(1, scrubbed.mastery);
    try testing.expectEqual(0, scrubbed.players); // not backed up

    // A restore from the older state still ends without p1: forgotten comes from the
    // newest snapshot, so take one more
    _ = try run(arena, io, .{ .data_dir = data, .out_dir = out, .now = day + 3 * 86400 });
    const restored_dir = try arena.print("{s}/restored", .{base});
    const r = try restore(arena, io, out, restored_dir, null, day);
    try testing.expectEqual(2, r.matches);
    try testing.expectEqual(1, r.timelines);
    try testing.expectEqual(1, r.mastery);
    {
        const db = try store.open(arena, restored_dir);
        defer db.close();
        try testing.expectEqual(@as(?i64, 3), try db.scalar("SELECT count(*) FROM participants", .{}));
        try testing.expectEqual(@as(?i64, 0), try db.scalar("SELECT count(*) FROM participants WHERE puuid = 'p1'", .{}));
        try testing.expectEqual(@as(?i64, 0), try db.scalar("SELECT count(*) FROM players", .{}));
        try testing.expectEqual(@as(?i64, 1), try db.scalar("SELECT count(*) FROM bans", .{}));
        try testing.expectEqual(@as(?i64, 7), try db.scalar("SELECT id FROM drafts", .{}));
        try testing.expectEqual(@as(?i64, 2), try db.scalar("SELECT count(*) FROM rank_history WHERE key = ?", .{store.schema.puuidKey("p2")}));
        try testing.expectEqual(@as(?i64, 2), try db.scalar("SELECT count(*) FROM rank_history", .{}));
        try testing.expect(try forget.isForgotten(db, "p1"));
        // The newest fetch wins
        try testing.expectEqual(@as(?i64, 2), try db.scalar("SELECT champions FROM mastery WHERE puuid = 'p2'", .{}));
    }
    try testing.expectError(error.TargetNotEmpty, restore(arena, io, out, restored_dir, null, day));

    // A mirror copies the segments before --full replaces them on the box
    const mirror = try arena.print("{s}/mirror", .{base});
    const cwd = Io.Dir.cwd();
    for ([_][]const u8{ "state", "segments", "mastery" }) |sub| {
        const from = try arena.print("{s}/{s}", .{ out, sub });
        try cwd.createDirPath(io, try arena.print("{s}/{s}", .{ mirror, sub }));
        var d = try cwd.openDir(io, from, .{ .iterate = true });
        defer d.close(io);
        var it = d.iterate();
        while (try it.next(io)) |e| try Io.Dir.copyFile(d, e.name, cwd, try arena.print("{s}/{s}/{s}", .{ mirror, sub, e.name }), io, .{});
    }

    // --full replaces the segments with one
    const full = try run(arena, io, .{ .data_dir = data, .out_dir = out, .now = day + 4 * 86400, .full = true });
    try testing.expectEqual(2, full.matches);
    // 3 segments (the third holds p2's day-20739 rank row) and 2 mastery files
    try testing.expectEqual(5, full.removed);
    try testing.expectEqual(1, full.mastery);

    // The mirror gets the full segment too and keeps the old ones; restore starts at it
    const newest = (try listSegments(arena, io, try arena.print("{s}/segments", .{out})))[0].name;
    try Io.Dir.copyFile(cwd, try arena.print("{s}/segments/{s}", .{ out, newest }), cwd, try arena.print("{s}/segments/{s}", .{ mirror, newest }), io, .{});
    try testing.expectEqual(4, (try listSegments(arena, io, try arena.print("{s}/segments", .{mirror}))).len);
    const full_m = (try listSegments(arena, io, try arena.print("{s}/mastery", .{out})))[0].name;
    try Io.Dir.copyFile(cwd, try arena.print("{s}/mastery/{s}", .{ out, full_m }), cwd, try arena.print("{s}/mastery/{s}", .{ mirror, full_m }), io, .{});
    const from_mirror = try restore(arena, io, mirror, try arena.print("{s}/restored-mirror", .{base}), null, day);
    try testing.expectEqual(2, from_mirror.matches);
    try testing.expectEqual(3, from_mirror.files); // newest state + the full mastery and segment
    try testing.expectEqual(1, from_mirror.mastery);

    // Tending: p2 newly forgotten on the box is scrubbed from every mirror file once
    const list = try arena.print("{s}/forgotten.txt", .{base});
    try cwd.writeFile(io, .{ .sub_path = list, .data = "p1\np2\n" });
    const t1 = try tendMirror(arena, io, mirror, list, 7, 4, day);
    try testing.expectEqual(2, t1.new_forgotten);
    try testing.expect(t1.removed.participants > 0);
    const t2 = try tendMirror(arena, io, mirror, list, 7, 4, day);
    try testing.expectEqual(0, t2.new_forgotten);
    try testing.expectEqual(4, (try listSegments(arena, io, try arena.print("{s}/segments", .{mirror}))).len);
    // Past the mastery prune's window every mastery file goes but the newest
    const mirror_m = try arena.print("{s}/mastery", .{mirror});
    try testing.expectEqual(3, (try listSegments(arena, io, mirror_m)).len);
    _ = try tendMirror(arena, io, mirror, list, 7, 4, day + 40 * 86400);
    try testing.expectEqual(1, (try listSegments(arena, io, mirror_m)).len);
    try testing.expectEqual(4, (try listSegments(arena, io, try arena.print("{s}/segments", .{mirror}))).len);
}
