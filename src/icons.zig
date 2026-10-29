//! The site's champion portraits (ui.champ.icon_fmt): Data Dragon's squares shrunk to
//! ui.champ.icon_px JPEGs (~3 KB against ~29 KB) and at icon_big_px, and its item, spell and rune art
//! (ui.art.local: items and spells JPEG, runes PNG at most art_px; a keystone is up to
//! 512 px, 360 KB). Made once into a cache laid out as the site (<cache>/icon/<version>/
//! <Key>.jpg, <cache>/dd/...), then copied into each build: the web round builds into a
//! fresh folder. The uploaded site keeps a version's folder `prune` long after a newer one
//! came, for pages loaded or cached before. Runes have no version in Data Dragon's paths:
//! one made stays

const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const store = @import("store");
const ui = @import("ui");
const ddragon = @import("ddragon.zig");
const image = @import("image.zig");

const log = std.log.scoped(.icons);

/// With ui.champ.icon_px, art_px and the encoders: a change shows under the same URLs,
/// which browsers keep a year, so it needs a new folder (test "make")
const quality = 82;
/// Drawn at most 36 px (ui.art.Px): twice that for sharp screens. Items and spells are
/// 64, never grown
const art_px = 72;
/// Failures in a row that mean Data Dragon is down, not one icon missing: the rest wait
/// for the next run instead of a timeout each; cached ones are still copied
const give_up_after = 3;

pub const Source = union(enum) {
    http: *std.http.Client,
    /// Files named as the URL's last part (Ahri.png, 1058.png; tests)
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
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var counts: Counts = .{};
    var wants: std.ArrayList(Want) = .empty;
    for (keys) |key| {
        // Both go into a path
        if (!plain(version, ".") or !plain(key, "")) {
            counts.failed += 1;
            continue;
        }
        const url = try arena.print("https://ddragon.leagueoflegends.com/cdn/{s}/img/champion/{s}.png", .{ version, key });
        try wants.append(arena, .{ .rel = try arena.print(ui.champ.icon_fmt[1..], .{ version, key }), .url = url, .side = ui.champ.icon_px });
        try wants.append(arena, .{ .rel = try arena.print(ui.champ.icon_big_fmt[1..], .{ version, key }), .url = url, .side = ui.champ.icon_big_px });
    }
    return syncWants(gpa, io, cache_dir, site_dir, wants.items, source, counts);
}

/// The art at `paths` (ui.art.local's; others counted failed), as syncKeys
pub fn syncArt(gpa: Allocator, io: Io, cache_dir: []const u8, site_dir: ?[]const u8, paths: []const []const u8, source: Source) !Counts {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var counts: Counts = .{};
    var wants: std.ArrayList(Want) = .empty;
    for (paths) |path| {
        const url = try ui.art.remote(arena, path) orelse {
            counts.failed += 1;
            continue;
        };
        if (!plain(path, "/._-") or std.mem.find(u8, path, "..") != null) {
            counts.failed += 1;
            continue;
        }
        try wants.append(arena, .{ .rel = path[1..], .url = url, .side = art_px, .png = std.mem.endsWith(u8, path, ".png") });
    }
    return syncWants(gpa, io, cache_dir, site_dir, wants.items, source, counts);
}

/// One icon: its path under the site (and the cache), the PNG it is made from, its
/// largest side (never grown) and format
const Want = struct { rel: []const u8, url: []const u8, side: u32, png: bool = false };

fn syncWants(gpa: Allocator, io: Io, cache_dir: []const u8, site_dir: ?[]const u8, wants: []const Want, source: Source, start: Counts) !Counts {
    var counts = start;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const cwd = Io.Dir.cwd();
    var in_a_row: u32 = 0;
    var down = false;
    for (wants) |want| {
        _ = arena_state.reset(.retain_capacity);
        const arena = arena_state.allocator();
        const path = try std.fs.path.join(arena, &.{ cache_dir, want.rel });
        if (cwd.access(io, path, .{})) |_| {
            counts.had += 1;
        } else |err| switch (err) {
            error.FileNotFound => {
                if (down) {
                    counts.failed += 1;
                    continue;
                }
                const bytes = make(gpa, arena, io, want, source) catch |e| switch (e) {
                    error.OutOfMemory => return e,
                    else => {
                        log.info("{s}: {t}", .{ want.rel, e });
                        counts.failed += 1;
                        in_a_row += 1;
                        down = in_a_row == give_up_after;
                        continue;
                    },
                };
                in_a_row = 0;
                var file = try cwd.createFileAtomic(io, path, .{ .make_path = true, .replace = true });
                defer file.deinit(io);
                try file.file.writeStreamingAll(io, bytes);
                try file.replace(io);
                counts.made += 1;
            },
            else => return err,
        }
        if (site_dir) |d| try cwd.copyFile(path, cwd, try std.fs.path.join(arena, &.{ d, want.rel }), io, .{ .make_path = true });
    }
    return counts;
}

fn make(gpa: Allocator, arena: Allocator, io: Io, want: Want, source: Source) ![]u8 {
    const png = switch (source) {
        .http => |http| try ddragon.fetch(http, arena, want.url),
        .dir => |d| try d.readFileAlloc(io, std.fs.path.basename(want.url), arena, .limited(1 << 20)),
    };
    var img = try image.decodePng(gpa, png);
    defer img.deinit(gpa);
    if (!want.png) {
        // Opaque art: alpha would only shift its colours
        gpa.free(img.alpha);
        img.alpha = &.{};
    }
    const side = @min(want.side, img.w);
    const small = try image.resize(gpa, img, side, @max(1, img.h * side / img.w));
    defer small.deinit(gpa);
    return if (want.png) image.encodePng(arena, small) else image.encodeJpeg(arena, small, quality);
}

/// The version folders in `site`'s icon/ and dd/ older than the newest, each once the next newer
/// one is `grace` old (a folder's time: when it came or last gained a file). The count
/// removed
pub fn prune(gpa: Allocator, io: Io, site: Io.Dir, now: Io.Timestamp, grace: Io.Duration) !usize {
    var n: usize = 0;
    for ([_][]const u8{ "icon", "dd" }) |top| n += try pruneIn(gpa, io, site, top, now, grace);
    return n;
}

fn pruneIn(gpa: Allocator, io: Io, site: Io.Dir, top: []const u8, now: Io.Timestamp, grace: Io.Duration) !usize {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var dir = site.openDir(io, top, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return 0,
        else => return err,
    };
    defer dir.close(io);
    var folders: std.ArrayList(Folder) = .empty;
    var it = dir.iterate();
    while (try it.next(io)) |e| {
        // dd/img: the runes, no version
        if (e.kind != .directory or !plain(e.name, ".") or !std.ascii.isDigit(e.name[0])) continue;
        const st = dir.statFile(io, e.name, .{}) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return err,
        };
        try folders.append(arena, .{ .name = try arena.dupe(u8, e.name), .time = st.mtime });
    }
    const gone = try stale(arena, folders.items, now, grace);
    for (gone) |name| try dir.deleteTree(io, name);
    return gone.len;
}

const Folder = struct { name: []const u8, time: Io.Timestamp };

fn stale(arena: Allocator, folders: []Folder, now: Io.Timestamp, grace: Io.Duration) ![]const []const u8 {
    std.mem.sort(Folder, folders, {}, struct {
        fn lt(_: void, a: Folder, b: Folder) bool {
            return older(a.name, b.name);
        }
    }.lt);
    var out: std.ArrayList([]const u8) = .empty;
    if (folders.len < 2) return out.items;
    for (folders[0 .. folders.len - 1], folders[1..]) |old, next| {
        if (next.time.durationTo(now).nanoseconds >= grace.nanoseconds) try out.append(arena, old.name);
    }
    return out.items;
}

/// Version `a` before `b`, part by part as numbers ("16.9.1" before "16.10.1")
fn older(a: []const u8, b: []const u8) bool {
    var ia = std.mem.splitScalar(u8, a, '.');
    var ib = std.mem.splitScalar(u8, b, '.');
    while (true) {
        const pa = ia.next() orelse return ib.next() != null;
        const pb = ib.next() orelse return false;
        const na = std.fmt.parseInt(u64, pa, 10) catch 0;
        const nb = std.fmt.parseInt(u64, pb, 10) catch 0;
        if (na != nb) return na < nb;
        if (!std.mem.eql(u8, pa, pb)) return std.mem.lessThan(u8, pa, pb);
    }
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
    // Data Dragon's 120 px square
    var rgb: [120 * 120 * 3]u8 = undefined;
    for (&rgb, 0..) |*v, i| v.* = @intCast(i * 7 % 256);
    try tmp.dir.writeFile(io, .{ .sub_path = "Ahri.png", .data = try image.testPng(arena, 120, 120, &rgb, .{ .filter = 1, .deflate = true }) });
    const keys: []const []const u8 = &.{ "Ahri", "Nope", "../x" };

    const cache = try arena.print("{s}/cache", .{base});
    const site = try arena.print("{s}/site", .{base});
    const first = try syncKeys(gpa, io, cache, site, "16.21.1", keys, .{ .dir = tmp.dir });
    try std.testing.expectEqual(Counts{ .made = 2, .failed = 3 }, first);
    try tmp.dir.access(io, "site/icon/16.21.1/120/Ahri.jpg", .{});
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
    try std.testing.expectEqual(Counts{ .had = 2, .failed = 3 }, again);
    try tmp.dir.access(io, "site/icon/16.21.1/Ahri.jpg", .{});
    try std.testing.expectEqual(Counts{ .failed = 3 }, try syncKeys(gpa, io, cache, null, "../16", keys, .{ .dir = tmp.dir }));
}

test "syncKeys: gives up after a few failures in a row, still copies cached ones" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try arena.print(".zig-cache/tmp/{s}", .{&tmp.sub_path});
    const rgb: [3]u8 = .{ 1, 2, 3 };
    // E could be made, but after three failures nothing is tried
    try tmp.dir.writeFile(io, .{ .sub_path = "E.png", .data = try image.testPng(arena, 1, 1, &rgb, .{}) });
    try tmp.dir.createDirPath(io, "cache/icon/16.21.1");
    try tmp.dir.writeFile(io, .{ .sub_path = "cache/icon/16.21.1/D.jpg", .data = "jpg" });
    const keys: []const []const u8 = &.{ "A", "B", "C", "D", "E" };
    const cache = try arena.print("{s}/cache", .{base});
    const site = try arena.print("{s}/site", .{base});
    const got = try syncKeys(gpa, io, cache, site, "16.21.1", keys, .{ .dir = tmp.dir });
    try std.testing.expectEqual(Counts{ .had = 1, .failed = 9 }, got);
    try tmp.dir.access(io, "site/icon/16.21.1/D.jpg", .{});
    try std.testing.expectError(error.FileNotFound, tmp.dir.access(io, "cache/icon/16.21.1/E.jpg", .{}));
}

test "make: the portraits the URLs promise" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const rgba = try arena.alloc(u8, 128 * 128 * 4);
    var rng: std.Random.DefaultPrng = .init(7);
    for (rgba, 0..) |*v, i| v.* = @intCast((i / 4 % 128 + i / 512 + rng.random().uintLessThan(u8, 64)) % 256);
    try tmp.dir.writeFile(io, .{ .sub_path = "Ahri.png", .data = try image.testPng(arena, 128, 128, rgba, .{ .channels = 4, .filter = 4, .deflate = true }) });
    const want: Want = .{ .rel = "", .url = "https://ddragon.leagueoflegends.com/cdn/16.21.1/img/champion/Ahri.png", .side = ui.champ.icon_px };
    const jpg = try make(gpa, arena, io, want, .{ .dir = tmp.dir });
    // Fails when icon_px, quality, resize or the encoder change what a portrait looks
    // like: give ui.champ.icon_fmt a new folder, then update the hash
    try std.testing.expectEqual(5946943054216529250, std.hash.Wyhash.hash(0, jpg));
}

test "syncArt: runes shrunk to see-through PNG, items JPEG at their size; others refused" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try arena.print(".zig-cache/tmp/{s}", .{&tmp.sub_path});
    const rgba = try arena.alloc(u8, 256 * 256 * 4);
    for (rgba, 0..) |*v, i| v.* = if (i % 4 == 3) @intCast(i / 1024 % 256) else @intCast(i % 251);
    try tmp.dir.writeFile(io, .{ .sub_path = "KEY.png", .data = try image.testPng(arena, 256, 256, rgba, .{ .channels = 4, .deflate = true }) });
    const rgb: [64 * 64 * 3]u8 = @splat(90);
    try tmp.dir.writeFile(io, .{ .sub_path = "1058.png", .data = try image.testPng(arena, 64, 64, &rgb, .{ .deflate = true }) });
    const paths: []const []const u8 = &.{
        "/dd/img/perk-images/Styles/Sorcery/KEY.png",
        "/dd/16.21.1/img/item/1058.jpg",
        "/dd/../x.png",
        "/icon/16.21.1/Ahri.jpg",
    };
    const site = try arena.print("{s}/site", .{base});
    const got = try syncArt(gpa, io, try arena.print("{s}/cache", .{base}), site, paths, .{ .dir = tmp.dir });
    try std.testing.expectEqual(Counts{ .made = 2, .failed = 2 }, got);
    const png = try tmp.dir.readFileAlloc(io, "site/dd/img/perk-images/Styles/Sorcery/KEY.png", arena, .limited(1 << 20));
    const rune = try image.decodePng(gpa, png);
    defer rune.deinit(gpa);
    try std.testing.expectEqual(art_px, rune.w);
    try std.testing.expectEqual(art_px * art_px, rune.alpha.len);
    const jpg = try tmp.dir.readFileAlloc(io, "site/dd/16.21.1/img/item/1058.jpg", arena, .limited(1 << 16));
    const sof = std.mem.find(u8, jpg, &.{ 0xFF, 0xC0 }) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(64, std.mem.readInt(u16, jpg[sof + 5 ..][0..2], .big));
}

test "prune: an old version's folder goes once the next is grace old" {
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    var buf: [32]u8 = undefined;
    for ([_][]const u8{ "icon/16.9.1", "icon/16.10.1", "icon/x-y", "dd/16.9.1", "dd/16.10.1", "dd/img" }) |v| {
        const d = try tmp.dir.createDirPathOpen(io, try std.fmt.bufPrint(&buf, "{s}", .{v}), .{});
        defer d.close(io);
        try d.writeFile(io, .{ .sub_path = "A.jpg", .data = "x" });
    }
    const now = Io.Timestamp.now(io, .real);
    const gpa = std.testing.allocator;
    try std.testing.expectEqual(0, try prune(gpa, io, tmp.dir, now, .fromNanoseconds(std.time.ns_per_day)));
    try std.testing.expectEqual(2, try prune(gpa, io, tmp.dir, now, .fromNanoseconds(0)));
    try std.testing.expectError(error.FileNotFound, tmp.dir.access(io, "icon/16.9.1", .{}));
    try std.testing.expectError(error.FileNotFound, tmp.dir.access(io, "dd/16.9.1", .{}));
    try tmp.dir.access(io, "dd/img/A.jpg", .{});
    try tmp.dir.access(io, "icon/16.10.1/A.jpg", .{});
    try tmp.dir.access(io, "icon/x-y/A.jpg", .{});
    var empty = std.testing.tmpDir(.{});
    defer empty.cleanup();
    try std.testing.expectEqual(0, try prune(gpa, io, empty.dir, now, .fromNanoseconds(0)));
}

test "stale: by version order, each against the next newer" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const at = struct {
        fn f(d: i96) Io.Timestamp {
            return .fromNanoseconds(d * std.time.ns_per_day);
        }
    }.f;
    var folders = [_]Folder{
        .{ .name = "16.10.1", .time = at(9) },
        .{ .name = "16.8.1", .time = at(1) },
        .{ .name = "16.9.1", .time = at(5) },
    };
    const got = try stale(arena, &folders, at(9), .fromNanoseconds(3 * std.time.ns_per_day));
    try std.testing.expectEqual(1, got.len);
    try std.testing.expectEqualStrings("16.8.1", got[0]);
    try std.testing.expect(older("16.9", "16.9.1"));
    try std.testing.expect(!older("16.9.1", "16.9.1"));
}
