//! SQL profile, on with MEIOLOL_SQL_PROFILE=1: every connection sums each statement's
//! run time and SQLite's own counters per SQL text, printed (top by time) when the last
//! connection closes. Time runs from the first step to reset or the last row, so a
//! streaming read includes the caller's work between rows; full scan steps, sorts,
//! automatic indexes and VM steps are SQLite's alone

const std = @import("std");
const c = @import("sqlite.zig").c;

const log = std.log.scoped(.sql_profile);

const Entry = struct {
    runs: u64 = 0,
    ns: u64 = 0,
    vm_steps: u64 = 0,
    scan_steps: u64 = 0,
    sorts: u64 = 0,
    auto_indexes: u64 = 0,
};

const gpa = std.heap.c_allocator;
var enabled: ?bool = null;
var open_connections: std.atomic.Value(u32) = .init(0);
// Trace callbacks have no Io, so a spin lock: held for one map update
var locked: std.atomic.Value(bool) = .init(false);
var entries: std.StringArrayHashMapUnmanaged(Entry) = .empty;

fn on() bool {
    if (enabled == null) {
        const v = std.c.getenv("MEIOLOL_SQL_PROFILE");
        enabled = v != null and std.mem.eql(u8, std.mem.span(v.?), "1");
    }
    return enabled.?;
}

fn lock() void {
    while (locked.swap(true, .acquire)) std.atomic.spinLoopHint();
}

fn unlock() void {
    locked.store(false, .release);
}

pub fn opened(db: *c.sqlite3) void {
    if (!on()) return;
    _ = open_connections.fetchAdd(1, .monotonic);
    _ = c.sqlite3_trace_v2(db, c.SQLITE_TRACE_PROFILE, trace, null);
}

pub fn closed() void {
    if (!on()) return;
    if (open_connections.fetchSub(1, .acq_rel) == 1) report(25);
}

fn trace(kind: c_uint, _: ?*anyopaque, p: ?*anyopaque, x: ?*anyopaque) callconv(.c) c_int {
    if (kind != c.SQLITE_TRACE_PROFILE) return 0;
    const stmt: *c.sqlite3_stmt = @ptrCast(p.?);
    const ns: *const i64 = @ptrCast(@alignCast(x.?));
    const sql = std.mem.span(c.sqlite3_sql(stmt) orelse return 0);
    const add: Entry = .{
        .runs = 1,
        .ns = @intCast(@max(ns.*, 0)),
        .vm_steps = counter(stmt, c.SQLITE_STMTSTATUS_VM_STEP),
        .scan_steps = counter(stmt, c.SQLITE_STMTSTATUS_FULLSCAN_STEP),
        .sorts = counter(stmt, c.SQLITE_STMTSTATUS_SORT),
        .auto_indexes = counter(stmt, c.SQLITE_STMTSTATUS_AUTOINDEX),
    };
    lock();
    defer unlock();
    const gop = entries.getOrPut(gpa, sql) catch return 0;
    if (!gop.found_existing) {
        gop.key_ptr.* = gpa.dupe(u8, sql) catch {
            entries.swapRemoveAt(gop.index);
            return 0;
        };
        gop.value_ptr.* = .{};
    }
    const e = gop.value_ptr;
    inline for (@typeInfo(Entry).@"struct".field_names) |f| @field(e, f) += @field(add, f);
    return 0;
}

/// This run's count: reset so the statement's next run starts from 0
fn counter(stmt: *c.sqlite3_stmt, op: c_int) u64 {
    return @intCast(@max(c.sqlite3_stmt_status(stmt, op, 1), 0));
}

fn byTime(ctx: void, a: Entry, b: Entry) bool {
    _ = ctx;
    return a.ns > b.ns;
}

/// Logs the `top` statements by total time and clears the sums
pub fn report(top: usize) void {
    lock();
    defer unlock();
    const Ctx = struct {
        values: []const Entry,
        pub fn lessThan(ctx: @This(), a: usize, b: usize) bool {
            return byTime({}, ctx.values[a], ctx.values[b]);
        }
    };
    entries.sort(Ctx{ .values = entries.values() });
    var total: u64 = 0;
    for (entries.values()) |e| total += e.ns;
    log.info("{d} statements, {d} ms in all", .{ entries.count(), total / std.time.ns_per_ms });
    for (entries.keys()[0..@min(top, entries.count())], entries.values()[0..@min(top, entries.count())]) |sql, e| {
        log.info("{d} ms {d}x vm {d} scan {d} sort {d} autoindex {d}: {s}", .{
            e.ns / std.time.ns_per_ms, e.runs,  e.vm_steps,
            e.scan_steps,              e.sorts, e.auto_indexes,
            oneLine(sql),
        });
    }
    for (entries.keys()) |k| gpa.free(k);
    entries.clearRetainingCapacity();
}

/// First 160 bytes, whitespace runs as one space
fn oneLine(sql: []const u8) []const u8 {
    const S = struct {
        threadlocal var buf: [160]u8 = undefined;
    };
    var n: usize = 0;
    var space = false;
    for (sql) |ch| {
        if (n == S.buf.len) break;
        if (std.ascii.isWhitespace(ch)) {
            space = n > 0;
            continue;
        }
        if (space and n < S.buf.len) {
            S.buf[n] = ' ';
            n += 1;
        }
        space = false;
        if (n < S.buf.len) {
            S.buf[n] = ch;
            n += 1;
        }
    }
    return S.buf[0..n];
}
