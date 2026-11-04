//! Champion, item, rune and summoner spell icons by id, as PNG bytes. The window reads
//! them from the League client itself (current with the patch, no internet); the shots
//! read a folder of <id>.png (`desktop-shot --icons`), champions only. Data Dragon art
//! is allowed in apps, logos are not (docs/plan/app.md APP8). A missing champion icon
//! draws as the champion's initials

const std = @import("std");

pub const lcu_path = "/lol-game-data/assets/v1/champion-icons/{d}.png";

pub const Kind = enum(u8) {
    champion,
    item,
    perk,
    spell,

    /// The client's list of the kind's ids and iconPath; champions' icons are at lcu_path
    pub fn list(k: Kind) []const u8 {
        return switch (k) {
            .champion => "",
            .item => "/lol-game-data/assets/v1/items.json",
            .perk => "/lol-game-data/assets/v1/perks.json",
            .spell => "/lol-game-data/assets/v1/summoner-spells.json",
        };
    }

    /// The page's path: icon/<id>.png for a champion, item/, perk/ or spell/<id>.png
    pub fn route(k: Kind) []const u8 {
        return if (k == .champion) "icon" else @tagName(k);
    }
};

pub const Key = struct { kind: Kind, id: u32 };

/// A page path's key ("item/3020.png"); null for any other path
pub fn keyOf(path: []const u8) ?Key {
    const slash = std.mem.indexOfScalar(u8, path, '/') orelse return null;
    if (!std.mem.endsWith(u8, path, ".png")) return null;
    const id = std.fmt.parseInt(u32, path[slash + 1 .. path.len - ".png".len], 10) catch return null;
    for ([_]Kind{ .champion, .item, .perk, .spell }) |k| {
        if (std.mem.eql(u8, path[0..slash], k.route())) return .{ .kind = k, .id = id };
    }
    return null;
}

pub const Icons = struct {
    gpa: std.mem.Allocator,
    png: std.AutoHashMapUnmanaged(Key, []const u8) = .empty,
    /// Asked for and not found: not asked again
    missing: std.AutoHashMapUnmanaged(Key, void) = .empty,

    pub fn deinit(i: *Icons) void {
        var it = i.png.valueIterator();
        while (it.next()) |v| i.gpa.free(v.*);
        i.png.deinit(i.gpa);
        i.missing.deinit(i.gpa);
    }

    pub fn get(i: *const Icons, champion: u32) ?[]const u8 {
        return i.png.get(.{ .kind = .champion, .id = champion });
    }

    pub fn art(i: *const Icons, k: Key) ?[]const u8 {
        return i.png.get(k);
    }

    /// Neither held nor known missing
    pub fn wanted(i: *const Icons, k: Key) bool {
        return k.id != 0 and !i.png.contains(k) and !i.missing.contains(k);
    }

    /// Takes `bytes` (allocated with gpa); null marks the icon missing
    pub fn put(i: *Icons, k: Key, bytes: ?[]const u8) !void {
        if (bytes) |b| {
            errdefer i.gpa.free(b);
            try i.png.put(i.gpa, k, b);
        } else try i.missing.put(i.gpa, k, {});
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
            try i.put(.{ .kind = .champion, .id = id }, bytes);
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

test keyOf {
    try std.testing.expectEqual(Key{ .kind = .champion, .id = 103 }, keyOf("icon/103.png").?);
    try std.testing.expectEqual(Key{ .kind = .item, .id = 3020 }, keyOf("item/3020.png").?);
    try std.testing.expectEqual(Key{ .kind = .spell, .id = 4 }, keyOf("spell/4.png").?);
    try std.testing.expectEqual(null, keyOf("champion/103.png"));
    try std.testing.expectEqual(null, keyOf("item/x.png"));
    try std.testing.expectEqual(null, keyOf("app.css"));
}

test initials {
    var buf: [2]u8 = undefined;
    try std.testing.expectEqualStrings("KS", initials("Kai'Sa", &buf));
    try std.testing.expectEqualStrings("LS", initials("Lee Sin", &buf));
    try std.testing.expectEqualStrings("Ah", initials("Ahri", &buf));
    try std.testing.expectEqualStrings("KZ", initials("Kha'Zix", &buf));
    try std.testing.expectEqualStrings("", initials("", &buf));
}
