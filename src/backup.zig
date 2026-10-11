//! Backups (`meiolol backup`, `meiolol restore`). docs/data-safety.md has the why.
//!
//! Two kinds of file, both plain SQLite, so `meiolol forget --backups` can scrub them:
//! - state/state-YYYY-MM-DD.db: the mutable tables (players, queues, mastery, ...),
//!   rotated (7 daily + 4 weekly by default)
//! - segments/NNNNNN.db: matches, participants and bans of matches stored since the last
//!   segment, and compact timelines likewise. These rows never change once stored, so
//!   segments are append-only and kept; the `segment` table holds each one's rowid range.
//!   `--full` writes one segment with everything and drops the older ones (after a
//!   rebuild or rekey, which rewrite stored rows)
//! Raw JSON is not backed up: raw.db is a 30-day buffer and the tables hold what it gives.
//! Each file is written as *.tmp in one read transaction (a consistent snapshot while the
//! crawler writes) and renamed when complete.

const std = @import("std");
const store = @import("store");
const forget = @import("forget.zig");

const Db = store.Db;
const Io = std.Io;
const log = std.log.scoped(.backup);

pub const state_tables = [_][]const u8{
    "players", "ladder_pages", "match_queue", "timeline_queue", "mastery", "champions", "forgotten",
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
    matches: i64,
    timelines: i64,
    removed: usize,
};

pub fn run(arena: std.mem.Allocator, io: Io, opts: Options) !Summary {
    const cwd = Io.Dir.cwd();
    const state_dir = try std.fs.path.join(arena, &.{ opts.out_dir, "state" });
    const seg_dir = try std.fs.path.join(arena, &.{ opts.out_dir, "segments" });
    try cwd.createDirPath(io, state_dir);
    try cwd.createDirPath(io, seg_dir);

    // Opening through store applies the schema and migrations first, so backups always
    // copy the current table layout
    (try store.open(arena, opts.data_dir)).close();
    const main_db = try std.fs.path.join(arena, &.{ opts.data_dir, "meiolol.db" });
    const timeline_db = try std.fs.path.join(arena, &.{ opts.data_dir, "timeline.db" });

    var date_buf: [10]u8 = undefined;
    const state_path = try std.fmt.allocPrint(arena, "{s}/state-{s}.db", .{ state_dir, isoDate(&date_buf, opts.now) });
    _ = try writeFile(arena, io, state_path, main_db, timeline_db, .state, 0, 0, opts.now);

    var removed = try rotate(arena, io, state_dir, opts.keep_daily, opts.keep_weekly);

    const segs = try listSegments(arena, io, seg_dir);
    var after_m: i64 = 0;
    var after_t: i64 = 0;
    if (!opts.full and segs.len > 0) {
        const last = try std.fs.path.join(arena, &.{ seg_dir, segs[segs.len - 1].name });
        const range = try readRange(arena, last);
        after_m = range.matches_to;
        after_t = range.timelines_to;
    }
    const next = if (segs.len > 0) segs[segs.len - 1].seq + 1 else 1;
    const seg_path = try std.fmt.allocPrint(arena, "{s}/{d:0>6}.db", .{ seg_dir, next });
    const wrote = try writeFile(arena, io, seg_path, main_db, timeline_db, .segment, after_m, after_t, opts.now);
    if (wrote.rows > 0 and opts.full) {
        for (segs) |s| {
            try cwd.deleteFile(io, try std.fs.path.join(arena, &.{ seg_dir, s.name }));
            removed += 1;
        }
    }
    return .{
        .state = state_path,
        .segment = if (wrote.rows > 0) seg_path else null,
        .matches = wrote.matches,
        .timelines = wrote.timelines,
        .removed = removed,
    };
}

const Kind = enum { state, segment };

const Written = struct { rows: i64 = 0, matches: i64 = 0, timelines: i64 = 0 };

/// Build `path` from the live databases inside one read transaction. A segment with no
/// new rows is not kept.
fn writeFile(
    arena: std.mem.Allocator,
    io: Io,
    path: []const u8,
    main_db: []const u8,
    timeline_db: []const u8,
    kind: Kind,
    after_m: i64,
    after_t: i64,
    now: i64,
) !Written {
    const cwd = Io.Dir.cwd();
    const tmp = try std.fmt.allocPrintSentinel(arena, "{s}.tmp", .{path}, 0);
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
                try db.exec(
                    \\CREATE TABLE segment (matches_after INTEGER NOT NULL, matches_to INTEGER NOT NULL,
                    \\    timelines_after INTEGER NOT NULL, timelines_to INTEGER NOT NULL,
                    \\    made_at INTEGER NOT NULL);
                );
                try db.run("INSERT INTO segment VALUES (?, ?, ?, ?, ?)", .{ after_m, to_m, after_t, to_t, now });
                for ([_][]const u8{ "matches", "participants", "bans" }) |t| _ = try copyDdl(arena, db, "live", t);
                _ = try copyDdl(arena, db, "livet", "timelines");
                try copyRows(arena, db, "live", "matches", try std.fmt.allocPrint(
                    arena,
                    " WHERE rowid > {d} AND rowid <= {d}",
                    .{ after_m, to_m },
                ));
                w.matches = changes(db);
                // Same transaction as the match row in the crawler, so never half a match
                const of_matches = " WHERE match_id IN (SELECT match_id FROM main.matches)";
                try copyRows(arena, db, "live", "participants", of_matches);
                try copyRows(arena, db, "live", "bans", of_matches);
                try copyRows(arena, db, "livet", "timelines", try std.fmt.allocPrint(
                    arena,
                    " WHERE rowid > {d} AND rowid <= {d}",
                    .{ after_t, to_t },
                ));
                w.timelines = changes(db);
                w.rows = w.matches + w.timelines;
            },
        }
        try db.exec("COMMIT");
    }
    if (kind == .segment and w.rows == 0) {
        try cwd.deleteFile(io, tmp);
        return w;
    }
    try cwd.rename(tmp, cwd, path, io);
    return w;
}

/// Create `table` in the backup's main schema with the live table's own DDL (column
/// order included, so SELECT * copies line up). false when the live side lacks it.
fn copyDdl(arena: std.mem.Allocator, db: Db, from: []const u8, table: []const u8) !bool {
    var s = try db.prepare(try std.fmt.allocPrint(
        arena,
        "SELECT sql FROM {s}.sqlite_master WHERE type = 'table' AND name = ?",
        .{from},
    ));
    defer s.deinit();
    try s.bind(.{table});
    if (!try s.step()) return false;
    try db.exec(try arena.dupeZ(u8, s.bytes(0)));
    return true;
}

fn copyRows(arena: std.mem.Allocator, db: Db, from: []const u8, table: []const u8, where: []const u8) !void {
    try db.exec(try std.fmt.allocPrintSentinel(
        arena,
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

const Range = struct { matches_to: i64, timelines_to: i64 };

fn readRange(arena: std.mem.Allocator, path: []const u8) !Range {
    const db = try Db.open(try arena.dupeZ(u8, path));
    defer db.close();
    var s = try db.prepare("SELECT matches_to, timelines_to FROM segment");
    defer s.deinit();
    try s.bind(.{});
    if (!try s.step()) return error.BadSegment;
    return .{ .matches_to = s.int(0), .timelines_to = s.int(1) };
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
    const y = std.fmt.parseInt(i64, name[6..10], 10) catch return null;
    const m = std.fmt.parseInt(i64, name[11..13], 10) catch return null;
    const d = std.fmt.parseInt(i64, name[14..16], 10) catch return null;
    return daysFromCivil(y, m, d);
}

/// Howard Hinnant's days_from_civil
fn daysFromCivil(y0: i64, m: i64, d: i64) i64 {
    const y = if (m <= 2) y0 - 1 else y0;
    const era = @divFloor(y, 400);
    const yoe = y - era * 400;
    const mp = @mod(m + 9, 12);
    const doy = @divFloor(153 * mp + 2, 5) + d - 1;
    const doe = yoe * 365 + @divFloor(yoe, 4) - @divFloor(yoe, 100) + doy;
    return era * 146097 + doe - 719468;
}

fn isoDate(buf: *[10]u8, secs: i64) []const u8 {
    const epoch: std.time.epoch.EpochSeconds = .{ .secs = @intCast(secs) };
    const day = epoch.getEpochDay().calculateYearDay();
    const md = day.calculateMonthDay();
    return std.fmt.bufPrint(buf, "{d:0>4}-{d:0>2}-{d:0>2}", .{
        day.year, md.month.numeric(), md.day_index + 1,
    }) catch unreachable;
}

pub const Restored = struct { files: usize, matches: i64, timelines: i64, removed: forget.Removed };

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
    var r: Restored = .{ .files = 0, .matches = 0, .timelines = 0, .removed = .{} };
    try load(arena, db, state);
    r.files += 1;
    const seg_dir = try std.fs.path.join(arena, &.{ from_dir, "segments" });
    for (try listSegments(arena, io, seg_dir)) |s| {
        try load(arena, db, try std.fs.path.join(arena, &.{ seg_dir, s.name }));
        r.files += 1;
    }
    r.matches = try db.scalar("SELECT count(*) FROM matches", .{}) orelse 0;
    r.timelines = try db.scalar("SELECT count(*) FROM timeline.timelines", .{}) orelse 0;
    r.removed = try forget.reapply(arena, db, now);
    return r;
}

/// Copy every table of a backup file into the live schema, by column name. Later files
/// win (INSERT OR REPLACE), so a `--full` segment or a re-extracted timeline overrides.
fn load(arena: std.mem.Allocator, db: Db, path: []const u8) !void {
    try db.run("ATTACH DATABASE ? AS b", .{path});
    defer db.exec("DETACH DATABASE b") catch {};
    var tables: std.ArrayList([]const u8) = .empty;
    {
        var s = try db.prepare("SELECT name FROM b.sqlite_master WHERE type = 'table' AND name != 'segment'");
        defer s.deinit();
        try s.bind(.{});
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
        try db.exec(try std.fmt.allocPrintSentinel(
            arena,
            "INSERT OR REPLACE INTO {s}.{s} ({s}) SELECT {s} FROM b.{s}",
            .{ schema, t, cols.items, cols.items, t },
            0,
        ));
    }
    try db.commit();
}

/// Erase `puuid` from every backup file under `dir` (forget --backups)
pub fn scrub(arena: std.mem.Allocator, io: Io, dir: []const u8, puuid: []const u8, now: i64) !forget.Removed {
    var total: forget.Removed = .{};
    for ([_][]const u8{ "state", "segments" }) |sub| {
        const path = try std.fs.path.join(arena, &.{ dir, sub });
        var d = Io.Dir.cwd().openDir(io, path, .{ .iterate = true }) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return err,
        };
        defer d.close(io);
        var it = d.iterate();
        while (try it.next(io)) |e| {
            if (e.kind != .file or !std.mem.endsWith(u8, e.name, ".db")) continue;
            const file = try std.fmt.allocPrintSentinel(arena, "{s}/{s}", .{ path, e.name }, 0);
            const db = try Db.open(file);
            defer db.close();
            total.add(try forget.forget(db, puuid, now, .scrub));
        }
    }
    return total;
}

fn changes(db: Db) i64 {
    return store.sqlite.c.sqlite3_changes64(db.handle);
}

const testing = std.testing;

test "rotation keeps 7 daily and the newest of 4 weeks" {
    var names: std.ArrayList([]const u8) = .empty;
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    // 40 consecutive days, 2026-09-01 .. 2026-10-10
    const start = daysFromCivil(2026, 9, 1);
    for (0..40) |i| {
        var buf: [10]u8 = undefined;
        const date = isoDate(&buf, (start + @as(i64, @intCast(i))) * 86400);
        try names.append(arena, try std.fmt.allocPrint(arena, "state-{s}.db", .{date}));
    }
    const doomed = try toDelete(arena, names.items, 7, 4);
    // Kept: 7 newest days (Oct 4-10) + newest of each of the 4 newest weeks; two of those
    // weeks' newest days are among the 7, so 7 + 2 kept
    try testing.expectEqual(40 - 9, doomed.len);
    for (doomed) |n| try testing.expect(!std.mem.eql(u8, n, "state-2026-10-10.db"));
    try testing.expectEqual(daysFromCivil(1970, 1, 1), 0);
    try testing.expectEqual(daysFromCivil(2026, 10, 11), 20737);
}

test "backup then restore round trip, incremental segments, scrub" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try std.fmt.allocPrint(arena, ".zig-cache/tmp/{s}", .{&tmp.sub_path});
    const data = try std.fmt.allocPrint(arena, "{s}/data", .{base});
    const out = try std.fmt.allocPrint(arena, "{s}/backups", .{base});
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
        );
    }
    const day = 86400 * 20737;
    const first = try run(arena, io, .{ .data_dir = data, .out_dir = out, .now = day });
    try testing.expectEqual(1, first.matches);
    try testing.expectEqual(1, first.timelines);
    // Nothing new: no segment
    const idle = try run(arena, io, .{ .data_dir = data, .out_dir = out, .now = day + 86400 });
    try testing.expectEqual(null, idle.segment);
    {
        const db = try store.open(arena, data);
        defer db.close();
        try db.exec(
            \\INSERT INTO matches VALUES ('EUW1_2', 'riot', 'EUW1', 420, '16.20', '16.20.1', 2, 1700, 200, 0);
            \\INSERT INTO participants (match_id, slot, team_id, puuid, champion_id, win)
            \\    VALUES ('EUW1_2', 0, 100, 'p1', 3, 0);
        );
    }
    const second = try run(arena, io, .{ .data_dir = data, .out_dir = out, .now = day + 2 * 86400 });
    try testing.expectEqual(1, second.matches);
    try testing.expectEqual(0, second.timelines);
    try testing.expectEqual(2, (try listSegments(arena, io, try std.fmt.allocPrint(arena, "{s}/segments", .{out}))).len);

    // p1 objects after the backups were taken: live forget records it, scrub cleans files
    {
        const db = try store.open(arena, data);
        defer db.close();
        _ = try forget.forget(db, "p1", day, .record);
    }
    const scrubbed = try scrub(arena, io, out, "p1", day);
    try testing.expectEqual(2, scrubbed.participants);
    try testing.expectEqual(3, scrubbed.players); // three state snapshots

    // A restore from the older state still ends without p1: forgotten comes from the
    // newest snapshot, so take one more
    _ = try run(arena, io, .{ .data_dir = data, .out_dir = out, .now = day + 3 * 86400 });
    const restored_dir = try std.fmt.allocPrint(arena, "{s}/restored", .{base});
    const r = try restore(arena, io, out, restored_dir, null, day);
    try testing.expectEqual(2, r.matches);
    try testing.expectEqual(1, r.timelines);
    {
        const db = try store.open(arena, restored_dir);
        defer db.close();
        try testing.expectEqual(@as(?i64, 3), try db.scalar("SELECT count(*) FROM participants", .{}));
        try testing.expectEqual(@as(?i64, 0), try db.scalar("SELECT count(*) FROM participants WHERE puuid = 'p1'", .{}));
        try testing.expectEqual(@as(?i64, 1), try db.scalar("SELECT count(*) FROM players", .{}));
        try testing.expectEqual(@as(?i64, 1), try db.scalar("SELECT count(*) FROM bans", .{}));
        try testing.expect(try forget.isForgotten(db, "p1"));
    }
    try testing.expectError(error.TargetNotEmpty, restore(arena, io, out, restored_dir, null, day));

    // --full replaces the segments with one
    const full = try run(arena, io, .{ .data_dir = data, .out_dir = out, .now = day + 4 * 86400, .full = true });
    try testing.expectEqual(2, full.matches);
    try testing.expectEqual(2, full.removed);
}
