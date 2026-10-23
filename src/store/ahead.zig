//! Reads ahead of a serial pass (curves, lean, builds) so several reads are in flight:
//! the box's block volume serves ~6x more at once than the one a pass issues (19 Oct:
//! ~1.2 queued, ~0.8 ms each, at ~1,500 reads/s). A lister lists the rows the pass will
//! read, in its order (the pass's own query, lighter), and readers read them a window
//! ahead of it, each thread on its own read-only connection, so the pass finds their
//! pages in the OS page cache. The pass's reads, order and output are its own: a list
//! that strays from it costs time, never results.

const std = @import("std");
const Io = std.Io;
const sqlite = @import("sqlite.zig");
const schema = @import("schema.zig");

pub const Options = struct {
    /// The pass's rows in its order: match_id (TEXT), source (INTEGER or NULL)
    list: []const u8,
    /// Run for each listed row with ?1 = match_id and ?2 = source, if it has a ?2; the
    /// first column of each result row is read in full (a blob's overflow pages too)
    reads: []const []const u8,
    readers: u8 = 8,
    /// How many rows the list may run ahead of the pass: ~40 MB of pages for curves
    window: u32 = 4096,
};

const max_reads = 4;
const max_id = 32;
/// The pass wakes a waiting lister every this many rows
const wake_every = 256;

const Key = struct { i: u32, source: ?i64, len: u8, id: [max_id]u8 };

pub const Ahead = struct {
    gpa: std.mem.Allocator,
    io: Io,
    window: u32,
    reads: []const []const u8,
    /// Rows the pass has read so far
    done: std.atomic.Value(u32) = .init(0),
    waiting: std.atomic.Value(bool) = .init(false),
    group: Io.Group = .init,
    queue: Io.Queue(Key),
    queue_buf: [512]Key = undefined,
    conns: std.ArrayList(sqlite.Db) = .empty,

    /// Starts listing `o.list` (bound to `args`, which must outlive stop) and reading
    /// ahead of the pass. Without file-backed connections or threads it does nothing.
    /// The pass calls next per row of its own query, and stop when done (also on error)
    pub fn start(gpa: std.mem.Allocator, io: Io, db: sqlite.Db, o: Options, args: anytype) !*Ahead {
        std.debug.assert(o.reads.len <= max_reads);
        const a = try gpa.create(Ahead);
        a.* = .{ .gpa = gpa, .io = io, .window = o.window, .reads = o.reads, .queue = undefined };
        a.queue = .init(&a.queue_buf);
        errdefer a.stop();
        // Room first: a connection opened but not yet in conns would leak
        try a.conns.ensureTotalCapacity(gpa, 1 + o.readers);
        const lister = (try schema.openSibling(gpa, db)) orelse return a;
        a.conns.appendAssumeCapacity(lister);
        for (0..o.readers) |_| {
            const c = (try schema.openSibling(gpa, db)).?;
            a.conns.appendAssumeCapacity(c);
            // Its pages are wanted in the OS page cache, not this connection's
            try c.exec("PRAGMA main.cache_size = -1024; PRAGMA timeline.cache_size = -1024");
        }
        const List = Lister(@TypeOf(args));
        a.group.concurrent(io, List.run, .{ a, lister, o.list, args }) catch return a;
        for (a.conns.items[1..]) |c| a.group.concurrent(io, read, .{ a, c }) catch break;
        return a;
    }

    /// The pass read its next row
    pub fn next(a: *Ahead) void {
        const n = a.done.fetchAdd(1, .release) + 1;
        if (n % wake_every == 0 and a.waiting.swap(false, .acquire)) a.io.futexWake(u32, &a.done.raw, 1);
    }

    pub fn stop(a: *Ahead) void {
        a.group.cancel(a.io);
        for (a.conns.items) |c| c.close();
        a.conns.deinit(a.gpa);
        a.gpa.destroy(a);
    }

    fn Lister(comptime Args: type) type {
        return struct {
            fn run(a: *Ahead, db: sqlite.Db, sql: []const u8, args: Args) void {
                defer a.queue.close(a.io);
                var q = db.prepare(sql) catch return;
                defer q.deinit();
                q.bind(args) catch return;
                var i: u32 = 0;
                while (q.step() catch return) : (i += 1) {
                    while (true) {
                        const done = a.done.load(.acquire);
                        if (i < done +| a.window) break;
                        a.waiting.store(true, .release);
                        a.io.futexWait(u32, &a.done.raw, done) catch return;
                    }
                    const id = q.bytes(0);
                    if (id.len > max_id) continue;
                    var k: Key = .{ .i = i, .source = q.optInt(1), .len = @intCast(id.len), .id = undefined };
                    @memcpy(k.id[0..id.len], id);
                    a.queue.putOne(a.io, k) catch return;
                }
            }
        };
    }

    fn read(a: *Ahead, db: sqlite.Db) void {
        var stmts: [max_reads]sqlite.Stmt = undefined;
        var prepared: usize = 0;
        defer for (stmts[0..prepared]) |*s| s.deinit();
        for (a.reads) |sql| {
            stmts[prepared] = db.prepare(sql) catch return;
            prepared += 1;
        }
        while (true) {
            const k = a.queue.getOne(a.io) catch return;
            // The pass is past it already
            if (k.i < a.done.load(.monotonic)) continue;
            for (stmts[0..prepared]) |*s| {
                const id = k.id[0..k.len];
                (if (s.params() >= 2) s.bind(.{ id, k.source }) else s.bind(.{id})) catch return;
                while (s.step() catch return) std.mem.doNotOptimizeAway(s.bytes(0).len);
            }
        }
    }
};

const testing = std.testing;

test "reads ahead of a pass on a file database, and stops wherever the pass does" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const gpa = testing.allocator;
    const dir = try std.fs.path.join(gpa, &.{ ".zig-cache", "tmp", &tmp.sub_path });
    defer gpa.free(dir);
    const db = try schema.open(gpa, dir);
    defer db.close();
    try db.exec("CREATE TABLE timeline.t (match_id TEXT PRIMARY KEY, data BLOB)");
    var ins = try db.prepare("INSERT INTO timeline.t VALUES (?, zeroblob(10000))");
    defer ins.deinit();
    var buf: [16]u8 = undefined;
    for (0..3000) |i| try ins.exec(.{try std.fmt.bufPrint(&buf, "EUW1_{d}", .{i})});
    const o: Options = .{
        .list = "SELECT match_id, rowid FROM timeline.t WHERE rowid > ? ORDER BY match_id",
        .reads = &.{ "SELECT data FROM timeline.t WHERE match_id = ?1", "SELECT data FROM timeline.t WHERE rowid = ?2" },
        .readers = 3,
        .window = 300,
    };
    // The whole pass, part of it, and one past the list
    for ([_]usize{ 2999, 1000, 3200 }) |rows| {
        const a = try Ahead.start(gpa, testing.io, db, o, .{1});
        defer a.stop();
        for (0..rows) |_| a.next();
    }
    // In memory: nothing to read ahead of
    const mem = try schema.memory();
    defer mem.close();
    const a = try Ahead.start(gpa, testing.io, mem, o, .{1});
    a.next();
    a.stop();
}
