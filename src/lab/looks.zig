//! The test looks ledger: every command that scores the test games (exp final,
//! compcheck/fields/style --final, meiolol carry --final) appends a line to SNAP/test-looks.tsv before scoring,
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
    if (try Exclude.load(gpa, io, dir, snap)) |e| {
        var ex = e;
        defer ex.deinit(gpa);
        try w.print("{s}: {d} test games an earlier snapshot's looks saw; report test and test minus them\n", .{ exclude_name, ex.keys.count() });
    } else try w.print("no {s} on {s}: one test number, nothing excluded\n", .{ exclude_name, snap });
    try w.flush();
    return n;
}

pub const exclude_name = "test-exclude.tsv";

/// SNAP/test-exclude.tsv (match_id, reason; header line): test games an earlier
/// snapshot's test looks saw. Every --final reports the full test and the test minus
/// these (docs/model.md, the 2253Z pin), from the same predictions
pub const Exclude = struct {
    keys: std.AutoHashMapUnmanaged(u64, void) = .empty,

    /// null when SNAP has none
    pub fn load(gpa: Allocator, io: Io, dir: Io.Dir, snap: []const u8) !?Exclude {
        const path = try std.fs.path.join(gpa, &.{ snap, exclude_name });
        defer gpa.free(path);
        const text = dir.readFileAlloc(io, path, gpa, .limited(64 << 20)) catch |err| switch (err) {
            error.FileNotFound => return null,
            else => return err,
        };
        defer gpa.free(text);
        var e: Exclude = .{};
        errdefer e.deinit(gpa);
        var lines = std.mem.splitScalar(u8, text, '\n');
        _ = lines.next();
        while (lines.next()) |line| {
            const id = std.mem.sliceTo(line, '\t');
            if (id.len > 0) try e.keys.put(gpa, std.hash.Wyhash.hash(0, id), {});
        }
        return e;
    }

    pub fn deinit(e: *Exclude, gpa: Allocator) void {
        e.keys.deinit(gpa);
    }

    pub fn has(e: *const Exclude, match_id: []const u8) bool {
        return e.keys.contains(std.hash.Wyhash.hash(0, match_id));
    }
};

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

test "test-exclude.tsv: loaded by match id, said on every look either way" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(testing.io, "snap");
    var sink: Io.Writer.Allocating = .init(testing.allocator);
    defer sink.deinit();
    const args: []const []const u8 = &.{"--final"};
    try testing.expectEqual(null, try Exclude.load(testing.allocator, testing.io, tmp.dir, "snap"));
    _ = try record(testing.allocator, testing.io, tmp.dir, "snap", "exp final", args, &sink.writer);
    try testing.expect(std.mem.indexOf(u8, sink.written(), "no " ++ exclude_name) != null);
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "snap/" ++ exclude_name, .data = "match_id\treason\nEUW1_1\t2055Z test\nKR_2\t2055Z test\n" });
    var e = (try Exclude.load(testing.allocator, testing.io, tmp.dir, "snap")).?;
    defer e.deinit(testing.allocator);
    try testing.expect(e.has("EUW1_1") and e.has("KR_2") and !e.has("EUW1_2") and !e.has("match_id"));
    _ = try record(testing.allocator, testing.io, tmp.dir, "snap", "exp final", args, &sink.writer);
    try testing.expect(std.mem.indexOf(u8, sink.written(), exclude_name ++ ": 2 test games") != null);
}
