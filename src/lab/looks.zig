//! The test looks ledger: every command that scores the test games (exp final,
//! compcheck/fields/style --final) appends a line to SNAP/test-looks.tsv before scoring,
//! so looks are counted per snapshot by the harness, not by hand (docs/lab-tooling.md).
//! A look that crashes still counts: the test games were read. `meiolol-lab looks SNAP`
//! prints the ledger

const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

pub const usage =
    \\  looks SNAP                      the snapshot's test looks ledger (test-looks.tsv):
    \\                                  one line per test look by any command
    \\
;

pub const file_name = "test-looks.tsv";
const header = "look\tutc\trun\tcommand\n";

/// Appends a look by CMD with ARGV to SNAP's ledger in DIR (cwd outside tests) and
/// prints "test look N of SNAP" to W. Returns N, this look's number
pub fn record(
    gpa: Allocator,
    io: Io,
    dir: Io.Dir,
    snap: []const u8,
    cmd: []const u8,
    argv: []const []const u8,
    w: *Io.Writer,
) !usize {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const lock = try dir.createFile(io, try std.fs.path.join(arena, &.{ snap, "test-looks.lock" }), .{
        .truncate = false,
        .lock = .exclusive,
    });
    defer lock.close(io);
    const path = try std.fs.path.join(arena, &.{ snap, file_name });
    const old = dir.readFileAlloc(io, path, arena, .limited(16 << 20)) catch |err| switch (err) {
        error.FileNotFound => "",
        else => return err,
    };
    const n = @max(std.mem.count(u8, old, "\n"), 1);
    // The run: lab-run's run dir is the cwd
    const cwd = std.process.currentPathAlloc(io, arena) catch "-";
    var line: Io.Writer.Allocating = .init(arena);
    const now = std.time.epoch.EpochSeconds{ .secs = @intCast(Io.Clock.real.now(io).toSeconds()) };
    const day = now.getEpochDay().calculateYearDay();
    const md = day.calculateMonthDay();
    const ds = now.getDaySeconds();
    try line.writer.print("{d}\t{d:0>4}-{d:0>2}-{d:0>2}", .{ n, day.year, md.month.numeric(), md.day_index + 1 });
    try line.writer.print("T{d:0>2}:{d:0>2}:{d:0>2}Z", .{ ds.getHoursIntoDay(), ds.getMinutesIntoHour(), ds.getSecondsIntoMinute() });
    try line.writer.print("\t{s}\t{s}", .{ std.fs.path.basename(cwd), cmd });
    for (argv) |a| {
        try line.writer.writeByte(' ');
        for (a) |ch| try line.writer.writeByte(if (ch == '\t' or ch == '\n') ' ' else ch);
    }
    try line.writer.writeByte('\n');
    var file = try dir.createFile(io, path, .{ .truncate = false });
    defer file.close(io);
    var buf: [1024]u8 = undefined;
    var fw = file.writer(io, &buf);
    try fw.seekTo(old.len);
    if (old.len == 0) try fw.interface.writeAll(header);
    try fw.interface.writeAll(line.written());
    try fw.interface.flush();
    try w.print("test look {d} of {s} (ledger {s})\n", .{ n, snap, path });
    try w.flush();
    return n;
}

pub fn main(gpa: Allocator, io: Io, argv: []const []const u8) !u8 {
    if (argv.len != 1) {
        std.debug.print("usage:\n{s}", .{usage});
        return 2;
    }
    const path = try std.fs.path.join(gpa, &.{ argv[0], file_name });
    defer gpa.free(path);
    var buf: [4096]u8 = undefined;
    var out = Io.File.stdout().writer(io, &buf);
    const text = Io.Dir.cwd().readFileAlloc(io, path, gpa, .limited(16 << 20)) catch |err| switch (err) {
        error.FileNotFound => {
            try out.interface.print("no test looks on {s}\n", .{argv[0]});
            try out.interface.flush();
            return 0;
        },
        else => return err,
    };
    defer gpa.free(text);
    try out.interface.writeAll(text);
    try out.interface.print("RESULT looks={d} snap={s}\n", .{ std.mem.count(u8, text, "\n") -| 1, argv[0] });
    try out.interface.flush();
    return 0;
}

const testing = std.testing;

test "looks are numbered per snapshot, header once, one line each" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(testing.io, "snap-a");
    try tmp.dir.createDirPath(testing.io, "snap-b");
    var sink: Io.Writer.Allocating = .init(testing.allocator);
    defer sink.deinit();
    const args: []const []const u8 = &.{ "SNAP", "--final", "tab\there" };
    try testing.expectEqual(1, try record(testing.allocator, testing.io, tmp.dir, "snap-a", "compcheck", args, &sink.writer));
    try testing.expectEqual(2, try record(testing.allocator, testing.io, tmp.dir, "snap-a", "fields", args, &sink.writer));
    try testing.expectEqual(1, try record(testing.allocator, testing.io, tmp.dir, "snap-b", "exp final", args, &sink.writer));
    const text = try tmp.dir.readFileAlloc(testing.io, "snap-a/" ++ file_name, testing.allocator, .unlimited);
    defer testing.allocator.free(text);
    var lines = std.mem.splitScalar(u8, text, '\n');
    try testing.expectEqualStrings(header[0 .. header.len - 1], lines.next().?);
    inline for (.{ "1\t", "2\t" }, .{ "compcheck", "fields" }) |start, cmd| {
        const l = lines.next().?;
        try testing.expect(std.mem.startsWith(u8, l, start));
        var cols = std.mem.splitScalar(u8, l, '\t');
        _ = cols.next();
        try testing.expectEqual(20, cols.next().?.len);
        _ = cols.next();
        try testing.expectEqualStrings(cmd ++ " SNAP --final tab here", cols.next().?);
        try testing.expectEqual(null, cols.next());
    }
    try testing.expectEqualStrings("", lines.next().?);
}
