//! Append-only TSV logs (data/eval-history.tsv, data/admin-history.tsv): a header line,
//! then a row per run. Columns are only ever added at the end; when the file's header is
//! a prefix of the current one it is rewritten, so readers keyed by header (the admin
//! page) see the new columns. Older rows keep their shorter length.

const std = @import("std");
const Io = std.Io;

/// `header` and `row` end in a newline
pub fn append(gpa: std.mem.Allocator, io: Io, path: []const u8, header: []const u8, row: []const u8) !void {
    const cwd = Io.Dir.cwd();
    if (try outdated(gpa, io, path, header)) |rest| {
        defer gpa.free(rest);
        const tmp = try gpa.print("{s}.tmp", .{path});
        defer gpa.free(tmp);
        const data = try std.mem.concat(gpa, u8, &.{ header, rest, row });
        defer gpa.free(data);
        try cwd.writeFile(io, .{ .sub_path = tmp, .data = data });
        try cwd.rename(tmp, cwd, path, io);
        return;
    }
    var file = try cwd.createFile(io, path, .{ .truncate = false });
    defer file.close(io);
    const len = try file.length(io);
    var buf: [1024]u8 = undefined;
    var fw = file.writer(io, &buf);
    try fw.seekTo(len);
    if (len == 0) try fw.interface.writeAll(header);
    try fw.interface.writeAll(row);
    try fw.interface.flush();
}

/// The rows after the file's header when that header is an older form of `header`
fn outdated(gpa: std.mem.Allocator, io: Io, path: []const u8, header: []const u8) !?[]u8 {
    var file = Io.Dir.cwd().openFile(io, path, .{}) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    defer file.close(io);
    var first: [4096]u8 = undefined;
    const got = first[0..try file.readPositionalAll(io, &first, 0)];
    const nl = std.mem.findScalar(u8, got, '\n') orelse return null;
    const old = got[0..nl];
    const new = header[0 .. header.len - 1];
    if (std.mem.eql(u8, old, new) or !std.mem.startsWith(u8, new, old) or new[old.len] != '\t') return null;
    const len: usize = @intCast(try file.length(io));
    const rest = try gpa.alloc(u8, len - nl - 1);
    errdefer gpa.free(rest);
    _ = try file.readPositionalAll(io, rest, nl + 1);
    return rest;
}

test "append, then widen the header" {
    const testing = std.testing;
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try testing.allocator.print(".zig-cache/tmp/{s}/h.tsv", .{&tmp.sub_path});
    defer testing.allocator.free(path);

    try append(testing.allocator, io, path, "a\tb\n", "1\t2\n");
    try append(testing.allocator, io, path, "a\tb\n", "3\t4\n");
    try append(testing.allocator, io, path, "a\tb\tc\n", "5\t6\t7\n");
    try append(testing.allocator, io, path, "a\tb\tc\n", "8\t9\t10\n");
    // Not an extension of the file's header: rows still go on the end
    try append(testing.allocator, io, path, "x\n", "11\n");
    const text = try Io.Dir.cwd().readFileAlloc(io, path, testing.allocator, .limited(1 << 10));
    defer testing.allocator.free(text);
    try testing.expectEqualStrings("a\tb\tc\n1\t2\n3\t4\n5\t6\t7\n8\t9\t10\n11\n", text);
}
