//! Where the player tools find their data: data/export under the current directory,
//! else next to the executable (beside it or in its data/export).

const std = @import("std");

/// Newest stats-*.bin
pub fn stats(arena: std.mem.Allocator, io: std.Io) !?[]const u8 {
    return find(arena, io, "stats-", ".bin");
}

/// recent-curves.bin, else the newest curves-<patch>.bin
pub fn curves(arena: std.mem.Allocator, io: std.Io) !?[]const u8 {
    if (try find(arena, io, "recent-curves", ".bin")) |p| return p;
    return find(arena, io, "curves-", ".bin");
}

/// champ-facts.tsv (core/champfacts.zig)
pub fn facts(arena: std.mem.Allocator, io: std.Io) !?[]const u8 {
    return find(arena, io, "champ-facts", ".tsv");
}

fn find(arena: std.mem.Allocator, io: std.Io, prefix: []const u8, suffix: []const u8) !?[]const u8 {
    if (try newest(arena, io, "data/export", prefix, suffix)) |p| return p;
    const exe_dir = std.process.executableDirPathAlloc(io, arena) catch return null;
    const exe_export = try std.fs.path.join(arena, &.{ exe_dir, "data", "export" });
    if (try newest(arena, io, exe_export, prefix, suffix)) |p| return p;
    return newest(arena, io, exe_dir, prefix, suffix);
}

fn newest(arena: std.mem.Allocator, io: std.Io, dir_path: []const u8, prefix: []const u8, suffix: []const u8) !?[]const u8 {
    const cwd = std.Io.Dir.cwd();
    var dir = cwd.openDir(io, dir_path, .{ .iterate = true }) catch return null;
    defer dir.close(io);
    var best: ?[]const u8 = null;
    var best_time: i96 = std.math.minInt(i96);
    var it = dir.iterate();
    while (it.next(io) catch null) |entry| {
        if (entry.kind != .file and entry.kind != .sym_link) continue;
        const name = entry.name;
        if (!std.mem.startsWith(u8, name, prefix) or !std.mem.endsWith(u8, name, suffix)) continue;
        const st = dir.statFile(io, entry.name, .{}) catch continue;
        if (st.mtime.nanoseconds <= best_time) continue;
        best_time = st.mtime.nanoseconds;
        best = try std.fs.path.join(arena, &.{ dir_path, entry.name });
    }
    return best;
}
