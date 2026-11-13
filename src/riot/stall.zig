//! What a slow commit or checkpoint waited on. The writer and checkpointer mark their
//! phase (a relaxed store, no syscall); the crawl report's minute tick warns once per
//! stall with the I/O pressure and who holds the databases' locks (/proc: Linux only)

const std = @import("std");
const builtin = @import("builtin");

pub const Phase = enum(u8) { idle, begin, apply, commit, busy_pause, prune, valve, passive, sync, truncate };

pub const State = struct { phase: Phase, detail: u8, since_ms: u64 };

/// Phase, a detail byte (writer: jobs in the batch, checkpointer: schema index) and when
/// the stalled unit began (a batch, a checkpoint round; ms on the awake clock), in one
/// word so the report never reads a phase with another unit's start
pub const Mark = struct {
    word: std.atomic.Value(u64) = .init(0),

    pub fn start(m: *Mark, phase: Phase, detail: u8, now_ms: u64) void {
        m.word.store(now_ms << 16 | @as(u64, detail) << 8 | @backingInt(phase), .monotonic);
    }

    /// Same unit, next phase. One thread marks each Mark, so load then store is enough
    pub fn to(m: *Mark, phase: Phase, detail: u8) void {
        const w = m.word.load(.monotonic);
        m.word.store(w & ~@as(u64, 0xffff) | @as(u64, detail) << 8 | @backingInt(phase), .monotonic);
    }

    pub fn get(m: *const Mark) State {
        const w = m.word.load(.monotonic);
        return .{ .phase = @fromBackingInt(@intCast(@as(u8, @truncate(w)))), .detail = @truncate(w >> 8), .since_ms = w >> 16 };
    }
};

/// Read by one thread (the crawl report)
pub const Watch = struct {
    warned_since: u64 = 0,

    /// True once per stall: a unit in a phase other than idle for `threshold_ms`
    pub fn due(w: *Watch, s: State, now_ms: u64, threshold_ms: u64) bool {
        if (s.phase == .idle or now_ms < s.since_ms + threshold_ms or s.since_ms == w.warned_since) return false;
        w.warned_since = s.since_ms;
        return true;
    }
};

pub const Psi = struct { some: f32, full: f32 };

/// /proc/pressure/io: share of the last 10 s some (full: every) task waited on I/O
pub fn parsePsi(text: []const u8) ?Psi {
    return .{ .some = avg10(text, "some ") orelse return null, .full = avg10(text, "full ") orelse return null };
}

fn avg10(text: []const u8, prefix: []const u8) ?f32 {
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        if (!std.mem.startsWith(u8, line, prefix)) continue;
        const at = std.mem.find(u8, line, "avg10=") orelse return null;
        const rest = line[at + "avg10=".len ..];
        const end = std.mem.findScalar(u8, rest, ' ') orelse rest.len;
        return std.fmt.parseFloat(f32, rest[0..end]) catch null;
    }
    return null;
}

pub const Lock = struct { pid: i32, write: bool, waiting: bool, inode: u64, start: u64, end: ?u64 };

/// A /proc/locks line: "1: POSIX  ADVISORY  WRITE 1234 fc:04:5767218 120 120"; a waiter
/// blocked on the lock above it has "->" after the number
pub fn parseLock(line: []const u8) ?Lock {
    var t = std.mem.tokenizeScalar(u8, line, ' ');
    _ = t.next() orelse return null;
    var kind = t.next() orelse return null;
    const waiting = std.mem.eql(u8, kind, "->");
    if (waiting) kind = t.next() orelse return null;
    _ = t.next() orelse return null;
    const mode = t.next() orelse return null;
    const pid = std.fmt.parseInt(i32, t.next() orelse return null, 10) catch return null;
    const dev = t.next() orelse return null;
    const colon = std.mem.findScalarLast(u8, dev, ':') orelse return null;
    const start = std.fmt.parseInt(u64, t.next() orelse return null, 10) catch return null;
    const end_word = t.next() orelse return null;
    return .{
        .pid = pid,
        .write = std.mem.eql(u8, mode, "WRITE"),
        .waiting = waiting,
        .inode = std.fmt.parseInt(u64, dev[colon + 1 ..], 10) catch return null,
        .start = start,
        .end = std.fmt.parseInt(u64, end_word, 10) catch null,
    };
}

/// A database file or its -shm, by inode
pub const File = struct { name: []const u8, shm: bool, inode: u64 };

/// SQLite's lock bytes (unix VFS, WAL mode). On -shm: 120 write, 121 checkpoint, 122
/// recover, 123-127 read marks; 128 (every connection, shared) is noise. On the database:
/// pending and reserved; the shared range only when held for writing (exclusive)
fn lockName(l: Lock, shm: bool, buf: []u8) ?[]const u8 {
    if (shm) return switch (l.start) {
        120 => "write",
        121 => "checkpoint",
        122 => "recover",
        123...127 => std.fmt.bufPrint(buf, "read{d}", .{l.start - 123}) catch null,
        else => null,
    };
    return switch (l.start) {
        1073741824 => "pending",
        1073741825 => "reserved",
        1073741826 => if (l.write) "exclusive" else null,
        else => null,
    };
}

/// The databases' locks from /proc/locks text, as "main-shm write W 1234 meiolol site";
/// "waits" before a blocked request. `names.cmd(pid)` names a process
pub fn describeLocks(w: *std.Io.Writer, text: []const u8, files: []const File, names: anytype) !void {
    var n: usize = 0;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        const l = parseLock(line) orelse continue;
        const f = for (files) |f| {
            if (f.inode == l.inode) break f;
        } else continue;
        var buf: [16]u8 = undefined;
        const name = lockName(l, f.shm, &buf) orelse continue;
        try w.print("{s}{s}{s}{s} {s} {s} {d} {s}", .{
            if (n > 0) ", " else "",
            if (l.waiting) "waits " else "",
            f.name,
            if (f.shm) "-shm" else "",
            name,
            if (l.write) "W" else "R",
            l.pid,
            names.cmd(l.pid),
        });
        n += 1;
    }
    if (n == 0) try w.writeAll("none");
}

const schemas = [_]struct { []const u8, []const u8 }{
    .{ "main", "meiolol.db" },
    .{ "raw", "raw.db" },
    .{ "timeline", "timeline.db" },
};

/// " | snapshot: io some 28.9 full 27.7 | locks ..." from /proc; empty off Linux. Only
/// while a stall is on: reads /proc/locks and each holder's cmdline
pub fn snapshot(gpa: std.mem.Allocator, io: std.Io, data_dir: []const u8, w: *std.Io.Writer) void {
    if (builtin.os.tag != .linux) return;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    w.writeAll(" | snapshot: io ") catch return;
    if (parsePsi(readProc(arena, io, "/proc/pressure/io") orelse "")) |p| {
        w.print("some {d:.1} full {d:.1}", .{ p.some, p.full }) catch return;
    } else w.writeAll("?") catch return;
    var files: [schemas.len * 2]File = undefined;
    var n: usize = 0;
    const dir = std.Io.Dir.cwd();
    for (schemas) |s| for ([_]bool{ false, true }) |shm| {
        const path = std.mem.concat(arena, u8, &.{ data_dir, "/", s[1], if (shm) "-shm" else "" }) catch return;
        const st = dir.statFile(io, path, .{}) catch continue;
        files[n] = .{ .name = s[0], .shm = shm, .inode = st.inode };
        n += 1;
    };
    w.writeAll(" | locks ") catch return;
    const text = readProc(arena, io, "/proc/locks") orelse {
        w.writeAll("?") catch {};
        return;
    };
    const names: Names = .{ .arena = arena, .io = io, .self = std.os.linux.getpid() };
    describeLocks(w, text, files[0..n], names) catch {};
}

const Names = struct {
    arena: std.mem.Allocator,
    io: std.Io,
    self: i32,

    /// "self" for the crawler, else its command line cut short
    fn cmd(n: Names, pid: i32) []const u8 {
        if (pid == n.self) return "self";
        if (pid <= 0) return "?";
        var buf: [32]u8 = undefined;
        const path = std.fmt.bufPrint(&buf, "/proc/{d}/cmdline", .{pid}) catch return "?";
        const raw = readProc(n.arena, n.io, path) orelse return "gone";
        const cut = raw[0..@min(raw.len, 60)];
        for (cut) |*c| {
            if (c.* == 0) c.* = ' ';
        }
        const line = std.mem.trimEnd(u8, cut, " ");
        const exe_end = std.mem.findScalar(u8, line, ' ') orelse line.len;
        const slash = std.mem.findScalarLast(u8, line[0..exe_end], '/');
        return line[if (slash) |s| s + 1 else 0..];
    }
};

/// /proc files report size 0: read them as a stream
fn readProc(arena: std.mem.Allocator, io: std.Io, path: []const u8) ?[]u8 {
    const f = std.Io.Dir.cwd().openFile(io, path, .{}) catch return null;
    defer f.close(io);
    var r = f.readerStreaming(io, &.{});
    return r.interface.allocRemaining(arena, .limited(1 << 20)) catch null;
}

test "a stall warns once, only past its threshold and never when idle" {
    var m: Mark = .{};
    var w: Watch = .{};
    try std.testing.expect(!w.due(m.get(), 1_000_000, 30_000));
    m.start(.begin, 12, 1_000_000);
    m.to(.apply, 12);
    try std.testing.expectEqual(State{ .phase = .apply, .detail = 12, .since_ms = 1_000_000 }, m.get());
    try std.testing.expect(!w.due(m.get(), 1_029_999, 30_000));
    try std.testing.expect(w.due(m.get(), 1_030_000, 30_000));
    m.to(.busy_pause, 12);
    try std.testing.expect(!w.due(m.get(), 1_090_000, 30_000));
    m.to(.idle, 0);
    m.start(.begin, 3, 1_100_000);
    try std.testing.expect(w.due(m.get(), 1_131_000, 30_000));
    m.to(.idle, 0);
    try std.testing.expect(!w.due(m.get(), 1_200_000, 30_000));
}

test "io pressure from /proc/pressure/io" {
    const text = "some avg10=28.90 avg60=28.98 avg300=25.85 total=140099429029\n" ++
        "full avg10=27.71 avg60=27.34 avg300=24.59 total=134717194619\n";
    const p = parsePsi(text).?;
    try std.testing.expectApproxEqAbs(@as(f32, 28.9), p.some, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 27.71), p.full, 0.01);
    try std.testing.expectEqual(@as(?Psi, null), parsePsi("some avg10=1.0\n"));
}

test "the databases' locks named from /proc/locks" {
    const text =
        \\1: POSIX  ADVISORY  WRITE 4242 fc:04:100 120 120
        \\1: -> POSIX  ADVISORY  WRITE 777 fc:04:100 120 120
        \\2: POSIX  ADVISORY  READ 4242 fc:04:100 128 128
        \\3: POSIX  ADVISORY  READ 5150 fc:04:100 124 124
        \\4: POSIX  ADVISORY  READ 5150 fc:04:99 1073741826 1073742335
        \\5: POSIX  ADVISORY  WRITE 5150 fc:04:300 121 121
        \\6: POSIX  ADVISORY  WRITE 9 08:02:555 120 120
        \\7: FLOCK  ADVISORY  WRITE 10 fc:04:99 0 EOF
        \\
    ;
    const files = [_]File{
        .{ .name = "main", .shm = false, .inode = 99 },
        .{ .name = "main", .shm = true, .inode = 100 },
        .{ .name = "raw", .shm = true, .inode = 300 },
    };
    const names = struct {
        fn cmd(_: @This(), pid: i32) []const u8 {
            return if (pid == 4242) "self" else "meiolol site";
        }
    }{};
    var buf: [512]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    try describeLocks(&w, text, &files, names);
    try std.testing.expectEqualStrings("main-shm write W 4242 self, waits main-shm write W 777 meiolol site, " ++
        "main-shm read1 R 5150 meiolol site, raw-shm checkpoint W 5150 meiolol site", w.buffered());
    w = .fixed(&buf);
    try describeLocks(&w, "", &files, names);
    try std.testing.expectEqualStrings("none", w.buffered());
}
