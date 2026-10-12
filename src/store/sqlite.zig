//! Thin SQLite wrapper: open, exec, prepared statements with tuple binding.

const std = @import("std");
pub const c = @import("sqlite_c");
const profile = @import("profile.zig");

const log = std.log.scoped(.sqlite);

/// Busy: another connection held the lock past the busy timeout; worth retrying
pub const Error = error{ Sqlite, Busy };

/// How long a connection waits on another's lock before Busy
pub const busy_timeout_ms = 60_000;

/// Extended codes too: SQLITE_BUSY_SNAPSHOT and the like
fn busy(rc: c_int) bool {
    return rc & 0xff == c.SQLITE_BUSY or rc & 0xff == c.SQLITE_LOCKED;
}

fn failure(db: ?*c.sqlite3, rc: c_int, what: []const u8) Error {
    const msg = if (db) |h| c.sqlite3_errmsg(h) else c.sqlite3_errstr(rc);
    if (busy(rc)) {
        log.warn("{s}: {s}", .{ what, msg });
        return error.Busy;
    }
    // One bad row, which callers like the crawler's writer skip and carry on
    if (rc & 0xff == c.SQLITE_CONSTRAINT) {
        log.warn("{s}: {s}", .{ what, msg });
        return error.Sqlite;
    }
    log.err("{s}: {s}", .{ what, msg });
    return error.Sqlite;
}

/// Bind as a BLOB rather than TEXT
pub const Blob = struct { bytes: []const u8 };

pub const Db = struct {
    handle: *c.sqlite3,

    pub fn open(path: [:0]const u8) Error!Db {
        return openFlags(path, c.SQLITE_OPEN_READWRITE | c.SQLITE_OPEN_CREATE);
    }

    /// Attached databases are read-only too
    pub fn openReadOnly(path: [:0]const u8) Error!Db {
        return openFlags(path, c.SQLITE_OPEN_READONLY);
    }

    fn openFlags(path: [:0]const u8, flags: c_int) Error!Db {
        var handle: ?*c.sqlite3 = null;
        if (c.sqlite3_open_v2(path.ptr, &handle, flags, null) != c.SQLITE_OK) {
            if (handle) |h| {
                log.err("open {s}: {s}", .{ path, c.sqlite3_errmsg(h) });
                _ = c.sqlite3_close(h);
            }
            return error.Sqlite;
        }
        // Before anything else: other connections may hold the lock (WAL switch). Long:
        // the crawler's writer waits out prune chunks and other processes on a slow disk
        _ = c.sqlite3_busy_timeout(handle.?, busy_timeout_ms);
        profile.opened(handle.?);
        return .{ .handle = handle.? };
    }

    pub fn setBusyTimeout(db: Db, ms: c_int) void {
        _ = c.sqlite3_busy_timeout(db.handle, ms);
    }

    pub fn close(db: Db) void {
        _ = c.sqlite3_close_v2(db.handle);
        profile.closed();
    }

    /// One or more statements without parameters or results
    pub fn exec(db: Db, sql: [:0]const u8) Error!void {
        const rc = c.sqlite3_exec(db.handle, sql.ptr, null, null, null);
        if (rc != c.SQLITE_OK) return failure(db.handle, rc, "exec");
    }

    pub fn prepare(db: Db, sql: []const u8) Error!Stmt {
        var stmt: ?*c.sqlite3_stmt = null;
        const rc = c.sqlite3_prepare_v2(db.handle, sql.ptr, @intCast(sql.len), &stmt, null);
        if (rc != c.SQLITE_OK) {
            log.err("  in: {s}", .{sql});
            return failure(db.handle, rc, "prepare");
        }
        return .{ .handle = stmt.?, .db = db.handle };
    }

    /// Run a statement once with `args`, discarding any rows
    pub fn run(db: Db, sql: []const u8, args: anytype) Error!void {
        var stmt = try db.prepare(sql);
        defer stmt.deinit();
        try stmt.exec(args);
    }

    /// First column of the first row as an integer, or null when no rows
    pub fn scalar(db: Db, sql: []const u8, args: anytype) Error!?i64 {
        var stmt = try db.prepare(sql);
        defer stmt.deinit();
        try stmt.bind(args);
        return if (try stmt.step()) stmt.int(0) else null;
    }

    /// Pages this connection wrote to the database or WAL, and read from disk (cache
    /// misses), since it opened: every attached schema
    pub fn pageCounts(db: Db) struct { written: u64, missed: u64 } {
        var cur: c_int = 0;
        var hi: c_int = 0;
        _ = c.sqlite3_db_status(db.handle, c.SQLITE_DBSTATUS_CACHE_WRITE, &cur, &hi, 0);
        const written: u64 = @intCast(cur);
        _ = c.sqlite3_db_status(db.handle, c.SQLITE_DBSTATUS_CACHE_MISS, &cur, &hi, 0);
        return .{ .written = written, .missed = @intCast(cur) };
    }

    /// Rows the last INSERT, UPDATE or DELETE changed
    pub fn changes(db: Db) i64 {
        return c.sqlite3_changes64(db.handle);
    }

    /// Rows changed since the connection opened
    pub fn totalChanges(db: Db) i64 {
        return c.sqlite3_total_changes64(db.handle);
    }

    pub fn begin(db: Db) Error!void {
        try db.exec("BEGIN IMMEDIATE");
    }

    pub fn commit(db: Db) Error!void {
        try db.exec("COMMIT");
    }

    pub fn rollback(db: Db) void {
        db.exec("ROLLBACK") catch {};
    }
};

pub const Stmt = struct {
    handle: *c.sqlite3_stmt,
    db: *c.sqlite3,

    pub fn deinit(s: *Stmt) void {
        _ = c.sqlite3_finalize(s.handle);
    }

    /// Reset, clear bindings, bind a tuple of ints, floats, strings, Blobs, nulls
    /// or optionals. Strings and blobs are bound without copying: keep them alive
    /// until the statement has been stepped.
    pub fn bind(s: *Stmt, args: anytype) Error!void {
        _ = c.sqlite3_reset(s.handle);
        _ = c.sqlite3_clear_bindings(s.handle);
        inline for (args, 1..) |arg, i| try s.bindOne(i, arg);
    }

    fn bindOne(s: *Stmt, i: c_int, arg: anytype) Error!void {
        const T = @TypeOf(arg);
        const rc = switch (@typeInfo(T)) {
            .null => c.sqlite3_bind_null(s.handle, i),
            .optional => return if (arg) |v| s.bindOne(i, v) else s.bindOne(i, null),
            .int, .comptime_int => c.sqlite3_bind_int64(s.handle, i, @intCast(arg)),
            .float, .comptime_float => c.sqlite3_bind_double(s.handle, i, arg),
            .bool => c.sqlite3_bind_int64(s.handle, i, @intFromBool(arg)),
            else => if (T == Blob)
                c.sqlite3_bind_blob64(s.handle, i, arg.bytes.ptr, arg.bytes.len, null)
            else
                c.sqlite3_bind_text64(s.handle, i, text(arg).ptr, text(arg).len, null, c.SQLITE_UTF8),
        };
        if (rc != c.SQLITE_OK) {
            log.err("bind {d}: {s}", .{ i, c.sqlite3_errmsg(s.db) });
            return error.Sqlite;
        }
    }

    fn text(arg: anytype) []const u8 {
        return arg;
    }

    /// true when a row is ready, false when done
    pub fn step(s: *Stmt) Error!bool {
        return switch (c.sqlite3_step(s.handle)) {
            c.SQLITE_ROW => true,
            c.SQLITE_DONE => false,
            else => |rc| failure(s.db, rc, "step"),
        };
    }

    /// Ends a read early (a statement stepped to its first row only)
    pub fn reset(s: *Stmt) void {
        _ = c.sqlite3_reset(s.handle);
    }

    pub fn exec(s: *Stmt, args: anytype) Error!void {
        try s.bind(args);
        while (try s.step()) {}
    }

    pub fn int(s: *Stmt, col: c_int) i64 {
        return c.sqlite3_column_int64(s.handle, col);
    }

    pub fn isNull(s: *Stmt, col: c_int) bool {
        return c.sqlite3_column_type(s.handle, col) == c.SQLITE_NULL;
    }

    pub fn optInt(s: *Stmt, col: c_int) ?i64 {
        return if (s.isNull(col)) null else s.int(col);
    }

    /// Valid until the next step, reset or deinit
    pub fn bytes(s: *Stmt, col: c_int) []const u8 {
        const len: usize = @intCast(c.sqlite3_column_bytes(s.handle, col));
        const ptr: ?[*]const u8 = @ptrCast(c.sqlite3_column_blob(s.handle, col));
        return if (ptr) |p| p[0..len] else "";
    }

    /// The current row as a T, one field per column in SELECT order: ints, floats, bools,
    /// []const u8 (text or blob, valid until the next step, reset or deinit) or optionals
    /// of those (null for NULL). Panics when the column count differs from T's fields, so
    /// a SELECT edited without its struct fails on first use instead of reading shifted
    /// columns
    pub fn row(s: *Stmt, comptime T: type) T {
        const info = @typeInfo(T).@"struct";
        const n = c.sqlite3_column_count(s.handle);
        if (n != info.field_names.len) std.debug.panic(
            "row {s}: {d} columns for {d} fields",
            .{ @typeName(T), n, info.field_names.len },
        );
        var r: T = undefined;
        inline for (info.field_names, info.field_types, 0..) |name, F, i| {
            @field(r, name) = s.column(F, i);
        }
        return r;
    }

    fn column(s: *Stmt, comptime T: type, col: c_int) T {
        return switch (@typeInfo(T)) {
            .optional => |o| if (s.isNull(col)) null else s.column(o.child, col),
            .int => @intCast(s.int(col)),
            .float => @floatCast(c.sqlite3_column_double(s.handle, col)),
            .bool => s.int(col) != 0,
            else => if (T == []const u8) s.bytes(col) else @compileError(
                "row: no column type " ++ @typeName(T),
            ),
        };
    }
};

test "round trip" {
    const db = try Db.open(":memory:");
    defer db.close();
    try db.exec("CREATE TABLE t (a INTEGER, b TEXT, c BLOB)");
    try db.run("INSERT INTO t VALUES (?, ?, ?)", .{ 42, "hi", Blob{ .bytes = "\x00\x01" } });
    try db.run("INSERT INTO t VALUES (?, ?, ?)", .{ @as(?i64, null), "x", null });
    try std.testing.expectEqual(@as(?i64, 2), try db.scalar("SELECT count(*) FROM t", .{}));
    var s = try db.prepare("SELECT a, b, c FROM t ORDER BY rowid");
    defer s.deinit();
    try std.testing.expect(try s.step());
    try std.testing.expectEqual(@as(i64, 42), s.int(0));
    try std.testing.expectEqualStrings("hi", s.bytes(1));
    try std.testing.expectEqualSlices(u8, "\x00\x01", s.bytes(2));
    try std.testing.expect(try s.step());
    const r = s.row(struct { a: ?u8, b: []const u8, c: ?[]const u8 });
    try std.testing.expectEqual(@as(?u8, null), r.a);
    try std.testing.expectEqualStrings("x", r.b);
    try std.testing.expectEqual(@as(?[]const u8, null), r.c);
    try std.testing.expect(!try s.step());
}

test busy {
    try std.testing.expect(busy(c.SQLITE_BUSY));
    try std.testing.expect(busy(c.SQLITE_BUSY_SNAPSHOT));
    try std.testing.expect(busy(c.SQLITE_LOCKED_SHAREDCACHE));
    try std.testing.expect(!busy(c.SQLITE_ERROR));
    try std.testing.expect(!busy(c.SQLITE_CONSTRAINT_UNIQUE));
}
