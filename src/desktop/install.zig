//! Per-user install, so Windows search and the Start menu find the app: the downloaded exe
//! copies itself and its update key into %LOCALAPPDATA%\Programs\meiolol and starts from
//! there. A per-user folder needs no admin rights and the updater can replace the exe in
//! it. This is the file side; setup.zig does the Windows side (shortcut, Apps list).

const std = @import("std");
const Io = std.Io;
const update = @import("update.zig");

pub const dir_name = "meiolol";

/// Downloaded files the updater fetches anyway: copied only when the install lacks them,
/// so an old zip never puts older data over newer
const data_prefixes = [_][]const u8{ "stats-", "recent-curves", "curves-" };

/// The zip's exe carries the update key after its image (web-loop.sh desktop_files): the
/// key, its length (u16 little endian), this. Explorer runs an exe from inside a zip
/// without the files beside it, so update.key alone was lost that way
pub const key_magic = "meiolol-key";

pub const Bundled = struct {
    /// The exe without the key: what the release signed and the manifest lists
    exe: []const u8,
    key: []const u8,
};

pub fn bundled(exe: []const u8) ?Bundled {
    if (!std.mem.endsWith(u8, exe, key_magic)) return null;
    const rest = exe[0 .. exe.len - key_magic.len];
    if (rest.len < 2) return null;
    const key_len = std.mem.readInt(u16, rest[rest.len - 2 ..][0..2], .little);
    if (key_len == 0 or key_len + 2 > rest.len) return null;
    const end = rest.len - 2;
    return .{ .exe = rest[0 .. end - key_len], .key = rest[end - key_len .. end] };
}

/// Writes `exe` into `to` as update.exe_name, the key as update.key and copies data files
/// in `from` that `to` lacks. An exe already in `to` may be running: it is moved aside to
/// update.old_exe, as the updater does
pub fn copyInto(arena: std.mem.Allocator, io: Io, from: Io.Dir, exe: []const u8, key: []const u8, to: Io.Dir) !void {
    // Fails when old_exe is the running image (after a self-update); the installed exe
    // is then not running and can be overwritten. When the move fails, the write says why
    to.deleteFile(io, update.old_exe) catch {};
    update.renameExe(arena, io, to, update.exe_name, update.old_exe) catch {};
    try to.writeFile(io, .{ .sub_path = update.exe_name, .data = exe });
    try to.writeFile(io, .{ .sub_path = update.key_file, .data = key });

    var it = from.iterate();
    while (try it.next(io)) |entry| {
        if (entry.kind != .file or !isData(entry.name)) continue;
        if (to.access(io, entry.name, .{})) continue else |_| {}
        try from.copyFile(entry.name, to, entry.name, io, .{});
    }
}

fn isData(name: []const u8) bool {
    if (!std.mem.endsWith(u8, name, ".bin")) return false;
    for (data_prefixes) |p| if (std.mem.startsWith(u8, name, p)) return true;
    return false;
}

/// Windows path equality (any case, either slash, trailing slash or not), also on the Mac
/// for the tests
pub fn samePath(a: []const u8, b: []const u8) bool {
    const at = std.mem.trimEnd(u8, a, "\\/");
    const bt = std.mem.trimEnd(u8, b, "\\/");
    if (at.len != bt.len) return false;
    for (at, bt) |x, y| {
        const xs = if (x == '/') '\\' else std.ascii.toLower(x);
        const ys = if (y == '/') '\\' else std.ascii.toLower(y);
        if (xs != ys) return false;
    }
    return true;
}

/// The release number (unix seconds of the build) as the Apps list shows it
pub fn displayVersion(buf: []u8, version: u64) []const u8 {
    if (version == 0) return "dev";
    const day = std.time.epoch.EpochSeconds{ .secs = version };
    const ymd = day.getEpochDay().calculateYearDay();
    const md = ymd.calculateMonthDay();
    return std.mem.print(buf, "{d}.{d}.{d}", .{ ymd.year, md.month.numeric(), md.day_index + 1 }) catch "dev";
}

test bundled {
    try std.testing.expectEqual(null, bundled("MZ plain exe"));
    try std.testing.expectEqual(null, bundled("\x09\x00" ++ key_magic));
    const b = bundled("MZ image" ++ "k3y" ++ "\x03\x00" ++ key_magic).?;
    try std.testing.expectEqualStrings("MZ image", b.exe);
    try std.testing.expectEqualStrings("k3y", b.key);
}

test "copyInto installs the exe and key, moves a running exe aside, keeps newer data" {
    const io = std.testing.io;
    var from_dir = std.testing.tmpDir(.{ .iterate = true });
    defer from_dir.cleanup();
    var to_dir = std.testing.tmpDir(.{});
    defer to_dir.cleanup();
    const from = from_dir.dir;
    const to = to_dir.dir;
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    try from.writeFile(io, .{ .sub_path = "stats-16.20.bin", .data = "zip stats" });
    try from.writeFile(io, .{ .sub_path = "recent-curves.bin", .data = "zip curves" });
    try from.writeFile(io, .{ .sub_path = "notes.txt", .data = "not ours" });
    try to.writeFile(io, .{ .sub_path = update.exe_name, .data = "old exe" });
    try to.writeFile(io, .{ .sub_path = "recent-curves.bin", .data = "newer curves" });

    try copyInto(arena, io, from, "new exe", "key", to);
    var buf: [64]u8 = undefined;
    try std.testing.expectEqualStrings("new exe", try to.readFile(io, update.exe_name, &buf));
    try std.testing.expectEqualStrings("old exe", try to.readFile(io, update.old_exe, &buf));
    try std.testing.expectEqualStrings("key", try to.readFile(io, update.key_file, &buf));
    try std.testing.expectEqualStrings("zip stats", try to.readFile(io, "stats-16.20.bin", &buf));
    try std.testing.expectEqualStrings("newer curves", try to.readFile(io, "recent-curves.bin", &buf));
    try std.testing.expectError(error.FileNotFound, to.access(io, "notes.txt", .{}));

    // A first install has no exe to move aside
    var fresh_dir = std.testing.tmpDir(.{});
    defer fresh_dir.cleanup();
    try copyInto(arena, io, from, "new exe", "key", fresh_dir.dir);
    try std.testing.expectError(error.FileNotFound, fresh_dir.dir.access(io, update.old_exe, .{}));
}

test samePath {
    try std.testing.expect(samePath("C:\\Users\\Jo\\AppData\\Local\\Programs\\meiolol", "c:/users/jo/appdata/local/programs/meiolol\\"));
    try std.testing.expect(!samePath("C:\\Users\\Jo\\Downloads\\meiolol", "C:\\Users\\Jo\\AppData\\Local\\Programs\\meiolol"));
}

test displayVersion {
    var buf: [16]u8 = undefined;
    try std.testing.expectEqualStrings("2026.10.21", displayVersion(&buf, 1792624905));
    try std.testing.expectEqualStrings("dev", displayVersion(&buf, 0));
}
