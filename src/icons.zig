//! The site's champion portraits (ui.champ.icon_fmt): Data Dragon's squares shrunk to
//! ui.champ.icon_px JPEGs (~3 KB against ~29 KB), made once per Data Dragon version into
//! a cache laid out as the site (<cache>/icon/<version>/<Key>.jpg), then copied into each
//! build: the web round builds into a fresh folder

const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const store = @import("store");
const ui = @import("ui");
const ddragon = @import("ddragon.zig");
const image = @import("image.zig");

const log = std.log.scoped(.icons);

const quality = 82;
/// Failures in a row that mean Data Dragon is down, not one icon missing: the rest wait
/// for the next run instead of a timeout each
const give_up_after = 3;

pub const Source = union(enum) {
    http: *std.http.Client,
    /// <Key>.png files (tests)
    dir: Io.Dir,
};

pub const Counts = struct {
    made: u32 = 0,
    had: u32 = 0,
    /// The caller warns: one line for the run
    failed: u32 = 0,
};

/// Every champion's portrait in `cache_dir` and, unless null, `site_dir`, at the version
/// the pages link: the first champion's by name, as site.champs takes it (Data Dragon
/// refreshes all rows at once)
pub fn sync(gpa: Allocator, io: Io, db: store.Db, cache_dir: []const u8, site_dir: ?[]const u8, source: Source) !Counts {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var keys: std.ArrayList([]const u8) = .empty;
    var version: []const u8 = "";
    var q = try db.prepare("SELECT key, ddragon_version FROM champions ORDER BY name");
    defer q.deinit();
    try q.bind(.{});
    while (try q.step()) {
        const r = q.row(struct { key: []const u8, ddragon_version: []const u8 });
        if (version.len == 0) version = try arena.dupe(u8, r.ddragon_version);
        try keys.append(arena, try arena.dupe(u8, r.key));
    }
    return syncKeys(gpa, io, cache_dir, site_dir, version, keys.items, source);
}

pub fn syncKeys(gpa: Allocator, io: Io, cache_dir: []const u8, site_dir: ?[]const u8, version: []const u8, keys: []const []const u8, source: Source) !Counts {
    var counts: Counts = .{};
    // Both go into a path
    if (!plain(version, ".")) {
        counts.failed = @intCast(keys.len);
        return counts;
    }
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const cwd = Io.Dir.cwd();
    var in_a_row: u32 = 0;
    for (keys) |key| {
        _ = arena_state.reset(.retain_capacity);
        const arena = arena_state.allocator();
        if (!plain(key, "")) {
            counts.failed += 1;
            continue;
        }
        const rel = try arena.print(ui.champ.icon_fmt[1..], .{ version, key });
        const path = try std.fs.path.join(arena, &.{ cache_dir, rel });
        if (cwd.access(io, path, .{})) |_| {
            counts.had += 1;
        } else |err| switch (err) {
            error.FileNotFound => {
                const jpg = make(gpa, arena, io, version, key, source) catch |e| switch (e) {
                    error.OutOfMemory => return e,
                    else => {
                        log.info("{s}: {t}", .{ key, e });
                        counts.failed += 1;
                        in_a_row += 1;
                        if (in_a_row == give_up_after) break;
                        continue;
                    },
                };
                in_a_row = 0;
                var file = try cwd.createFileAtomic(io, path, .{ .make_path = true, .replace = true });
                defer file.deinit(io);
                try file.file.writeStreamingAll(io, jpg);
                try file.replace(io);
                counts.made += 1;
            },
            else => return err,
        }
        if (site_dir) |d| try cwd.copyFile(path, cwd, try std.fs.path.join(arena, &.{ d, rel }), io, .{ .make_path = true });
    }
    return counts;
}

fn make(gpa: Allocator, arena: Allocator, io: Io, version: []const u8, key: []const u8, source: Source) ![]u8 {
    const png = switch (source) {
        .http => |http| try ddragon.fetch(http, arena, try arena.print(
            "https://ddragon.leagueoflegends.com/cdn/{s}/img/champion/{s}.png",
            .{ version, key },
        )),
        .dir => |d| try d.readFileAlloc(io, try arena.print("{s}.png", .{key}), arena, .limited(1 << 20)),
    };
    const img = try image.decodePng(gpa, png);
    defer img.deinit(gpa);
    const small = try image.resize(gpa, img, ui.champ.icon_px, ui.champ.icon_px);
    defer small.deinit(gpa);
    return image.encodeJpeg(arena, small, quality);
}

/// Letters and digits, and `extra`
fn plain(s: []const u8, extra: []const u8) bool {
    if (s.len == 0) return false;
    for (s) |c| {
        if (!std.ascii.isAlphanumeric(c) and std.mem.findScalar(u8, extra, c) == null) return false;
    }
    return true;
}

test "syncKeys: made once, kept after; bad keys and missing art counted" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try arena.print(".zig-cache/tmp/{s}", .{&tmp.sub_path});
    var rgb: [6 * 6 * 3]u8 = undefined;
    for (&rgb, 0..) |*v, i| v.* = @intCast(i * 7 % 256);
    try tmp.dir.writeFile(io, .{ .sub_path = "Ahri.png", .data = try image.testPng(arena, 6, 6, &rgb, 1) });
    const keys: []const []const u8 = &.{ "Ahri", "Nope", "../x" };

    const cache = try arena.print("{s}/cache", .{base});
    const site = try arena.print("{s}/site", .{base});
    const first = try syncKeys(gpa, io, cache, site, "16.21.1", keys, .{ .dir = tmp.dir });
    try std.testing.expectEqual(Counts{ .made = 1, .failed = 2 }, first);
    const jpg = try tmp.dir.readFileAlloc(io, "cache/icon/16.21.1/Ahri.jpg", arena, .limited(1 << 16));
    try std.testing.expect(std.mem.startsWith(u8, jpg, &.{ 0xFF, 0xD8 }));
    const sof = std.mem.find(u8, jpg, &.{ 0xFF, 0xC0 }) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(ui.champ.icon_px, std.mem.readInt(u16, jpg[sof + 5 ..][0..2], .big));

    // The build's copy at the path the pages link
    const linked = try arena.print(ui.champ.icon_fmt, .{ "16.21.1", "Ahri" });
    const copy = try tmp.dir.readFileAlloc(io, try arena.print("site{s}", .{linked}), arena, .limited(1 << 16));
    try std.testing.expectEqualSlices(u8, jpg, copy);

    // A fresh build: copied from the cache, nothing made
    try tmp.dir.deleteTree(io, "site");
    const again = try syncKeys(gpa, io, cache, site, "16.21.1", keys, .{ .dir = tmp.dir });
    try std.testing.expectEqual(Counts{ .had = 1, .failed = 2 }, again);
    try tmp.dir.access(io, "site/icon/16.21.1/Ahri.jpg", .{});
    try std.testing.expectEqual(Counts{ .failed = 3 }, try syncKeys(gpa, io, cache, null, "../16", keys, .{ .dir = tmp.dir }));
}

test "syncKeys: gives up after a few failures in a row" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const keys: []const []const u8 = &.{ "A", "B", "C", "D", "E" };
    const got = try syncKeys(gpa, io, ".zig-cache/tmp/none", null, "16.21.1", keys, .{ .dir = tmp.dir });
    try std.testing.expectEqual(Counts{ .failed = give_up_after }, got);
}
