//! Front-end files every page or island loads, linked by a name with their content's hash
//! (`search.1a2b3c4d.js`), which nginx serves as immutable for a year (docs/hosting.md).
//! A deploy changes the name, so a browser never revalidates them. Only hashed names are
//! written; the web loop keeps a replaced copy three days (prune) for pages loaded or
//! cached before a deploy
const std = @import("std");
const names = @import("asset_names");
const ui = @import("ui");

pub const Hashed = struct { plain: []const u8, path: []const u8, data: []const u8 };

pub const stats_js = built("ui-stats.js", @embedFile("ui-stats.js"));
pub const stats_wasm = built("ui-stats.wasm", @embedFile("ui-stats.wasm"));
pub const champion_js = built("ui-champion.js", @embedFile("ui-champion.js"));
pub const champion_wasm = built("ui-champion.wasm", @embedFile("ui-champion.wasm"));
pub const champbuild_js = built("ui-champbuild.js", @embedFile("ui-champbuild.js"));
pub const champbuild_wasm = built("ui-champbuild.wasm", @embedFile("ui-champbuild.wasm"));
pub const champmore_js = built("ui-champmore.js", @embedFile("ui-champmore.js"));
pub const champmore_wasm = built("ui-champmore.wasm", @embedFile("ui-champmore.wasm"));
pub const champcharts_js = built("ui-champcharts.js", @embedFile("ui-champcharts.js"));
pub const champcharts_wasm = built("ui-champcharts.wasm", @embedFile("ui-champcharts.wasm"));
pub const matchup_js = built("ui-matchup.js", @embedFile("ui-matchup.js"));
pub const matchup_wasm = built("ui-matchup.wasm", @embedFile("ui-matchup.wasm"));
pub const matchmore_js = built("ui-matchmore.js", @embedFile("ui-matchmore.js"));
pub const matchmore_wasm = built("ui-matchmore.wasm", @embedFile("ui-matchmore.wasm"));
pub const games_js = built("ui-games.js", @embedFile("ui-games.js"));
pub const games_wasm = built("ui-games.wasm", @embedFile("ui-games.wasm"));
pub const gamemore_js = built("ui-gamemore.js", @embedFile("ui-gamemore.js"));
pub const gamemore_wasm = built("ui-gamemore.wasm", @embedFile("ui-gamemore.wasm"));
pub const gamelane_js = built("ui-gamelane.js", @embedFile("ui-gamelane.js"));
pub const gamelane_wasm = built("ui-gamelane.wasm", @embedFile("ui-gamelane.wasm"));
pub const finder_js = built("ui-finder.js", @embedFile("ui-finder.js"));
pub const finder_wasm = built("ui-finder.wasm", @embedFile("ui-finder.wasm"));
pub const findergrid_js = built("ui-findergrid.js", @embedFile("ui-findergrid.js"));
pub const findergrid_wasm = built("ui-findergrid.wasm", @embedFile("ui-findergrid.wasm"));
pub const learn_js = built("ui-learn.js", @embedFile("ui-learn.js"));
pub const learn_wasm = built("ui-learn.wasm", @embedFile("ui-learn.wasm"));
pub const patch_js = built("ui-patch.js", @embedFile("ui-patch.js"));
pub const patch_wasm = built("ui-patch.wasm", @embedFile("ui-patch.wasm"));
pub const pool_js = built("ui-pool.js", @embedFile("ui-pool.js"));
pub const pool_wasm = built("ui-pool.wasm", @embedFile("ui-pool.wasm"));
pub const poolgrid_js = built("ui-poolgrid.js", @embedFile("ui-poolgrid.js"));
pub const poolgrid_wasm = built("ui-poolgrid.wasm", @embedFile("ui-poolgrid.wasm"));
pub const daily_js = built("ui-daily.js", @embedFile("ui-daily.js"));
pub const daily_wasm = built("ui-daily.wasm", @embedFile("ui-daily.wasm"));
pub const dailydays_js = built("ui-dailydays.js", @embedFile("ui-dailydays.js"));
pub const dailydays_wasm = built("ui-dailydays.wasm", @embedFile("ui-dailydays.wasm"));
pub const home_js = built("ui-home.js", @embedFile("ui-home.js"));
pub const home_wasm = built("ui-home.wasm", @embedFile("ui-home.wasm"));
pub const homegame_js = built("ui-homegame.js", @embedFile("ui-homegame.js"));
pub const homegame_wasm = built("ui-homegame.wasm", @embedFile("ui-homegame.wasm"));
pub const your_js = built("ui-your.js", @embedFile("ui-your.js"));
pub const your_wasm = built("ui-your.wasm", @embedFile("ui-your.wasm"));
pub const yourviews_js = built("ui-yourviews.js", @embedFile("ui-yourviews.js"));
pub const yourviews_wasm = built("ui-yourviews.wasm", @embedFile("ui-yourviews.wasm"));
pub const yourtime_js = built("ui-yourtime.js", @embedFile("ui-yourtime.js"));
pub const yourtime_wasm = built("ui-yourtime.wasm", @embedFile("ui-yourtime.wasm"));
pub const yourlookup_js = built("ui-yourlookup.js", @embedFile("ui-yourlookup.js"));
pub const yourlookup_wasm = built("ui-yourlookup.wasm", @embedFile("ui-yourlookup.wasm"));
pub const yourfriends_js = built("ui-yourfriends.js", @embedFile("ui-yourfriends.js"));
pub const yourfriends_wasm = built("ui-yourfriends.wasm", @embedFile("ui-yourfriends.wasm"));
pub const forget_js = built("ui-forget.js", @embedFile("ui-forget.js"));
pub const forget_wasm = built("ui-forget.wasm", @embedFile("ui-forget.wasm"));
pub const sitesearch_js = built("ui-sitesearch.js", @embedFile("ui-sitesearch.js"));
pub const sitesearch_wasm = built("ui-sitesearch.wasm", @embedFile("ui-sitesearch.wasm"));
pub const tester_js = built("ui-tester.js", @embedFile("ui-tester.js"));
pub const tester_wasm = built("ui-tester.wasm", @embedFile("ui-tester.wasm"));
pub const testercand_js = built("ui-testercand.js", @embedFile("ui-testercand.js"));
pub const testercand_wasm = built("ui-testercand.wasm", @embedFile("ui-testercand.wasm"));

/// A file the build hashed (src/tools/assetnames.zig): `plain` with its 8 hex digits
pub fn built(comptime plain: []const u8, comptime data: []const u8) Hashed {
    const dot = comptime std.mem.findScalarLast(u8, plain, '.').?;
    return .{ .plain = plain, .path = plain[0..dot] ++ "." ++ @field(names, plain) ++ plain[dot..], .data = data };
}

/// `plain` with 8 hex digits of `data`'s FNV-1a before its extension, at comptime: small
/// data only, a megabyte takes minutes
pub fn hashed(comptime plain: []const u8, comptime data: []const u8) Hashed {
    const dot = comptime std.mem.findScalarLast(u8, plain, '.').?;
    return .{ .plain = plain, .path = comptime plain[0..dot] ++ "." ++ ui.css.version(data) ++ plain[dot..], .data = data };
}

test hashed {
    try std.testing.expectEqualStrings("ui-stats.fd0c5087.js", hashed("ui-stats.js", "x").path);
}

/// The site's hashed copies a deploy replaced, in the uploaded site `dir` (the web loop's
/// data/site: a file's time is when it first came): each goes with its .gz once the copy
/// that replaced it is `grace` old, so a page or island loaded before a deploy still finds
/// its files that long. A hashed name no current asset has (removed or renamed) goes
/// `orphan_grace` after it came. The count removed
pub fn prune(gpa: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, current: []const Hashed, now: std.Io.Timestamp, grace: std.Io.Duration) !usize {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var copies: std.ArrayList(Copy) = .empty;
    var it = dir.iterate();
    while (try it.next(io)) |e| {
        if (e.kind != .file or std.mem.endsWith(u8, e.name, ".gz")) continue;
        // rsync may be replacing it
        const st = dir.statFile(io, e.name, .{}) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return err,
        };
        try copies.append(arena, .{ .name = try arena.dupe(u8, e.name), .time = st.mtime });
    }
    const gone = try stale(arena, current, copies.items, now, grace);
    for (gone) |name| for ([_][]const u8{ name, try arena.print("{s}.gz", .{name}) }) |n| {
        dir.deleteFile(io, n) catch |err| switch (err) {
            error.FileNotFound => {},
            else => return err,
        };
    };
    return gone.len;
}

const Copy = struct { name: []const u8, time: std.Io.Timestamp };

pub const orphan_grace: std.Io.Duration = .fromNanoseconds(30 * std.time.ns_per_day);

/// The names prune deletes from `files`
fn stale(arena: std.mem.Allocator, current: []const Hashed, files: []const Copy, now: std.Io.Timestamp, grace: std.Io.Duration) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    var mine: std.ArrayList(Copy) = .empty;
    for (current) |h| {
        mine.clearRetainingCapacity();
        for (files) |f| if (copyOf(h, f.name)) try mine.append(arena, f);
        // Oldest first; a copy as old as the current one is older (one upload)
        std.mem.sort(Copy, mine.items, h.path, struct {
            fn lt(path: []const u8, a: Copy, b: Copy) bool {
                if (a.time.nanoseconds != b.time.nanoseconds) return a.time.nanoseconds < b.time.nanoseconds;
                return !std.mem.eql(u8, a.name, path) and std.mem.eql(u8, b.name, path);
            }
        }.lt);
        if (mine.items.len < 2) continue;
        for (mine.items[0 .. mine.items.len - 1], mine.items[1..]) |old, next| {
            if (std.mem.eql(u8, old.name, h.path)) continue;
            if (next.time.durationTo(now).nanoseconds >= grace.nanoseconds) try out.append(arena, old.name);
        }
    }
    for (files) |f| {
        if (!looksHashed(f.name) or f.time.durationTo(now).nanoseconds < orphan_grace.nanoseconds) continue;
        for (current) |h| {
            if (copyOf(h, f.name)) break;
        } else try out.append(arena, f.name);
    }
    return out.items;
}

/// `name` is `h`'s plain name with some 8 hex digits, as hashed() makes it
fn copyOf(h: Hashed, name: []const u8) bool {
    const dot = std.mem.findScalarLast(u8, h.plain, '.') orelse return false;
    const stem = h.plain[0 .. dot + 1];
    const ext = h.plain[dot..];
    if (name.len != stem.len + 8 + ext.len) return false;
    if (!std.mem.startsWith(u8, name, stem) or !std.mem.endsWith(u8, name, ext)) return false;
    for (name[stem.len..][0..8]) |c| if (!std.ascii.isHex(c) or std.ascii.isUpper(c)) return false;
    return true;
}

/// `stem.<8 hex>.ext`, as hashed() names them and nginx serves them immutable
fn looksHashed(name: []const u8) bool {
    const dot = std.mem.findScalarLast(u8, name, '.') orelse return false;
    if (dot < 10 or name[dot - 9] != '.' or dot + 1 == name.len) return false;
    for (name[0 .. dot - 9]) |c| if (!std.ascii.isAlphanumeric(c) and c != '-' and c != '_') return false;
    for (name[dot - 8 .. dot]) |c| if (!std.ascii.isHex(c) or std.ascii.isUpper(c)) return false;
    for (name[dot + 1 ..]) |c| if (!std.ascii.isAlphanumeric(c)) return false;
    return true;
}

test "stale: a replaced copy goes once its replacement is grace old" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const cur = hashed("ui-stats.js", "x");
    const day: i96 = std.time.ns_per_day;
    const at = struct {
        fn f(d: i96) std.Io.Timestamp {
            return .fromNanoseconds(d * std.time.ns_per_day);
        }
    }.f;
    const files = [_]Copy{
        .{ .name = "ui-stats.00000001.js", .time = at(1) },
        .{ .name = "ui-stats.00000002.js", .time = at(5) },
        .{ .name = "ui-stats.00000003.js", .time = at(9) },
        .{ .name = cur.path, .time = at(10) },
        // Not a copy of it
        .{ .name = "ui-stats.js", .time = at(0) },
        .{ .name = "ui-statsx.00000001.js", .time = at(0) },
        .{ .name = "ui-stats.0000000g.js", .time = at(0) },
        .{ .name = "ui-stats.00000001.wasm", .time = at(0) },
    };
    const grace: std.Io.Duration = .fromNanoseconds(3 * day);
    // Day 11: 1 replaced on day 5, 2 on day 9 (2 days ago), 3 on day 10
    const got = try stale(arena, &.{cur}, &files, at(11), grace);
    try std.testing.expectEqual(1, got.len);
    try std.testing.expectEqualStrings("ui-stats.00000001.js", got[0]);
    try std.testing.expectEqual(3, (try stale(arena, &.{cur}, &files, at(13), grace)).len);
    // Uploaded with the current one: replaced now
    const same = [_]Copy{ .{ .name = cur.path, .time = at(10) }, .{ .name = "ui-stats.00000009.js", .time = at(10) } };
    try std.testing.expectEqual(0, (try stale(arena, &.{cur}, &same, at(12), grace)).len);
    try std.testing.expectEqual(1, (try stale(arena, &.{cur}, &same, at(13), grace)).len);
    // Back on an older build: the newer copy stays, nothing replaced it
    const back = [_]Copy{ .{ .name = cur.path, .time = at(1) }, .{ .name = "ui-stats.00000009.js", .time = at(2) } };
    try std.testing.expectEqual(0, (try stale(arena, &.{cur}, &back, at(30), grace)).len);
    // Not built any more: gone 30 days after it came
    const orphans = [_]Copy{ .{ .name = cur.path, .time = at(1) }, .{ .name = "ui-old.0000000a.wasm", .time = at(2) }, .{ .name = "notes.txt", .time = at(0) } };
    try std.testing.expectEqual(0, (try stale(arena, &.{cur}, &orphans, at(31), grace)).len);
    const gone = try stale(arena, &.{cur}, &orphans, at(32), grace);
    try std.testing.expectEqual(1, gone.len);
    try std.testing.expectEqualStrings("ui-old.0000000a.wasm", gone[0]);
}

test looksHashed {
    try std.testing.expect(looksHashed("ui-champ_more.1a2b3c4d.wasm"));
    for ([_][]const u8{ "ui-stats.js", ".1a2b3c4d.js", "a.1a2b3c4D.js", "a.1a2b3c4d.", "a.b.1a2b3c4d.js", "a.1a2b3c4.js", "a.1a2b3c4d.j-s" }) |n| {
        try std.testing.expect(!looksHashed(n));
    }
}

test "prune deletes the copy and its .gz, keeps the current one" {
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    const cur = hashed("search.js", "x");
    for ([_][]const u8{ "search.00000001.js", "search.00000001.js.gz", cur.path, "search.js" }) |name| {
        try tmp.dir.writeFile(io, .{ .sub_path = name, .data = "x" });
    }
    const now = std.Io.Timestamp.now(io, .real);
    try std.testing.expectEqual(0, try prune(std.testing.allocator, io, tmp.dir, &.{cur}, now, .fromNanoseconds(std.time.ns_per_day)));
    try std.testing.expectEqual(1, try prune(std.testing.allocator, io, tmp.dir, &.{cur}, now, .fromNanoseconds(0)));
    try std.testing.expectError(error.FileNotFound, tmp.dir.access(io, "search.00000001.js", .{}));
    try std.testing.expectError(error.FileNotFound, tmp.dir.access(io, "search.00000001.js.gz", .{}));
    try tmp.dir.access(io, cur.path, .{});
    try tmp.dir.access(io, "search.js", .{});
}
