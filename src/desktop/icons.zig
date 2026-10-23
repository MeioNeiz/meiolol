//! Champion icons by champion id, as PNG bytes. The window reads them from the League
//! client itself (every champion, current with the patch, no internet); the shots read a
//! folder of <id>.png (`desktop-shot --icons`). Data Dragon art is allowed in apps, logos
//! are not (docs/plan/app.md APP8). A missing icon draws as the champion's initials

const std = @import("std");

pub const lcu_path = "/lol-game-data/assets/v1/champion-icons/{d}.png";

pub const Icons = struct {
    gpa: std.mem.Allocator,
    png: std.AutoHashMapUnmanaged(u32, []const u8) = .empty,
    /// Asked for and not found: not asked again
    missing: std.AutoHashMapUnmanaged(u32, void) = .empty,

    pub fn deinit(i: *Icons) void {
        var it = i.png.valueIterator();
        while (it.next()) |v| i.gpa.free(v.*);
        i.png.deinit(i.gpa);
        i.missing.deinit(i.gpa);
    }

    pub fn get(i: *const Icons, champion: u32) ?[]const u8 {
        return i.png.get(champion);
    }

    /// Neither held nor known missing
    pub fn wanted(i: *const Icons, champion: u32) bool {
        return champion != 0 and !i.png.contains(champion) and !i.missing.contains(champion);
    }

    /// Takes `bytes` (allocated with gpa); null marks the champion missing
    pub fn put(i: *Icons, champion: u32, bytes: ?[]const u8) !void {
        if (bytes) |b| {
            errdefer i.gpa.free(b);
            try i.png.put(i.gpa, champion, b);
        } else try i.missing.put(i.gpa, champion, {});
    }

    /// Every <id>.png in `dir_path`
    pub fn loadDir(i: *Icons, io: std.Io, dir_path: []const u8) !void {
        var dir = try std.Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true });
        defer dir.close(io);
        var it = dir.iterate();
        while (try it.next(io)) |entry| {
            if (!std.mem.endsWith(u8, entry.name, ".png")) continue;
            const id = std.fmt.parseInt(u32, entry.name[0 .. entry.name.len - 4], 10) catch continue;
            const bytes = try dir.readFileAlloc(io, entry.name, i.gpa, .limited(1 << 20));
            try i.put(id, bytes);
        }
    }
};

/// "Kai'Sa" -> "KS", "Lee Sin" -> "LS", "Ahri" -> "Ah"
pub fn initials(name: []const u8, buf: *[2]u8) []const u8 {
    if (name.len == 0) return "";
    buf[0] = std.ascii.toUpper(name[0]);
    for (name[1..], 1..) |ch, k| {
        if (std.ascii.isUpper(ch) or (k > 0 and (name[k - 1] == ' ' or name[k - 1] == '\'') and std.ascii.isAlphabetic(ch))) {
            buf[1] = std.ascii.toUpper(ch);
            return buf[0..2];
        }
    }
    if (name.len < 2) return buf[0..1];
    buf[1] = name[1];
    return buf[0..2];
}

test initials {
    var buf: [2]u8 = undefined;
    try std.testing.expectEqualStrings("KS", initials("Kai'Sa", &buf));
    try std.testing.expectEqualStrings("LS", initials("Lee Sin", &buf));
    try std.testing.expectEqualStrings("Ah", initials("Ahri", &buf));
    try std.testing.expectEqualStrings("KZ", initials("Kha'Zix", &buf));
    try std.testing.expectEqualStrings("", initials("", &buf));
}
