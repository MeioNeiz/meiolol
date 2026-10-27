//! Front-end files every page or island loads, linked by a name with their content's hash
//! (`search.1a2b3c4d.js`), which nginx serves as immutable for a year (docs/hosting.md).
//! A deploy changes the name, so a browser never revalidates them. Only hashed names are
//! written; the web loop keeps a replaced copy three days (prune) for pages loaded or
//! cached before a deploy
const std = @import("std");
const ui = @import("ui");

pub const Hashed = struct { plain: []const u8, path: []const u8, data: []const u8 };

pub const search_js = hashed("search.js", @embedFile("static/search.js"));
pub const stats_js = hashed("ui-stats.js", @embedFile("ui-stats.js"));
pub const stats_wasm = hashed("ui-stats.wasm", @embedFile("ui-stats.wasm"));
pub const champion_js = hashed("ui-champion.js", @embedFile("ui-champion.js"));
pub const champion_wasm = hashed("ui-champion.wasm", @embedFile("ui-champion.wasm"));
pub const champbuild_js = hashed("ui-champbuild.js", @embedFile("ui-champbuild.js"));
pub const champbuild_wasm = hashed("ui-champbuild.wasm", @embedFile("ui-champbuild.wasm"));
pub const champmore_js = hashed("ui-champmore.js", @embedFile("ui-champmore.js"));
pub const champmore_wasm = hashed("ui-champmore.wasm", @embedFile("ui-champmore.wasm"));
pub const matchup_js = hashed("ui-matchup.js", @embedFile("ui-matchup.js"));
pub const matchup_wasm = hashed("ui-matchup.wasm", @embedFile("ui-matchup.wasm"));
pub const matchmore_js = hashed("ui-matchmore.js", @embedFile("ui-matchmore.js"));
pub const matchmore_wasm = hashed("ui-matchmore.wasm", @embedFile("ui-matchmore.wasm"));
pub const games_js = hashed("ui-games.js", @embedFile("ui-games.js"));
pub const games_wasm = hashed("ui-games.wasm", @embedFile("ui-games.wasm"));
pub const gamemore_js = hashed("ui-gamemore.js", @embedFile("ui-gamemore.js"));
pub const gamemore_wasm = hashed("ui-gamemore.wasm", @embedFile("ui-gamemore.wasm"));
pub const gamelane_js = hashed("ui-gamelane.js", @embedFile("ui-gamelane.js"));
pub const gamelane_wasm = hashed("ui-gamelane.wasm", @embedFile("ui-gamelane.wasm"));
pub const finder_js = hashed("ui-finder.js", @embedFile("ui-finder.js"));
pub const finder_wasm = hashed("ui-finder.wasm", @embedFile("ui-finder.wasm"));
pub const findergrid_js = hashed("ui-findergrid.js", @embedFile("ui-findergrid.js"));
pub const findergrid_wasm = hashed("ui-findergrid.wasm", @embedFile("ui-findergrid.wasm"));
pub const learn_js = hashed("ui-learn.js", @embedFile("ui-learn.js"));
pub const learn_wasm = hashed("ui-learn.wasm", @embedFile("ui-learn.wasm"));
pub const patch_js = hashed("ui-patch.js", @embedFile("ui-patch.js"));
pub const patch_wasm = hashed("ui-patch.wasm", @embedFile("ui-patch.wasm"));
pub const pool_js = hashed("ui-pool.js", @embedFile("ui-pool.js"));
pub const pool_wasm = hashed("ui-pool.wasm", @embedFile("ui-pool.wasm"));
pub const daily_js = hashed("ui-daily.js", @embedFile("ui-daily.js"));
pub const daily_wasm = hashed("ui-daily.wasm", @embedFile("ui-daily.wasm"));
pub const dailydays_js = hashed("ui-dailydays.js", @embedFile("ui-dailydays.js"));
pub const dailydays_wasm = hashed("ui-dailydays.wasm", @embedFile("ui-dailydays.wasm"));
pub const home_js = hashed("ui-home.js", @embedFile("ui-home.js"));
pub const home_wasm = hashed("ui-home.wasm", @embedFile("ui-home.wasm"));
pub const homegame_js = hashed("ui-homegame.js", @embedFile("ui-homegame.js"));
pub const homegame_wasm = hashed("ui-homegame.wasm", @embedFile("ui-homegame.wasm"));
pub const your_js = hashed("ui-your.js", @embedFile("ui-your.js"));
pub const your_wasm = hashed("ui-your.wasm", @embedFile("ui-your.wasm"));
pub const yourviews_js = hashed("ui-yourviews.js", @embedFile("ui-yourviews.js"));
pub const yourviews_wasm = hashed("ui-yourviews.wasm", @embedFile("ui-yourviews.wasm"));
pub const yourlookup_js = hashed("ui-yourlookup.js", @embedFile("ui-yourlookup.js"));
pub const yourlookup_wasm = hashed("ui-yourlookup.wasm", @embedFile("ui-yourlookup.wasm"));
pub const tester_js = hashed("ui-tester.js", @embedFile("ui-tester.js"));
pub const tester_wasm = hashed("ui-tester.wasm", @embedFile("ui-tester.wasm"));
pub const testercand_js = hashed("ui-testercand.js", @embedFile("ui-testercand.js"));
pub const testercand_wasm = hashed("ui-testercand.wasm", @embedFile("ui-testercand.wasm"));

/// `plain` with 8 hex digits of `data`'s FNV-1a before its extension
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
