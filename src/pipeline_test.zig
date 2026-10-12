//! End to end on fixtures: match JSON and timeline into the tables as the crawler stores
//! them, then the commands the box runs (stats, drafts, curves, site). Catches what unit
//! tests miss: a page that fails on thin data, a file format the next step cannot read.

const std = @import("std");
const store = @import("store");
const core = @import("core");
const riot = @import("riot/root.zig");
const stats = @import("stats.zig");
const curves = @import("curves.zig");
const builds = @import("builds.zig");
const ddragon = @import("ddragon.zig");
const site = @import("site/root.zig");
const admin = @import("admin.zig");

const testing = std.testing;
const games = 3;
const patch = "15.13";
/// Fixed game start; since_ms 0 keeps the games in the 30-day views
const start_ms = 1_752_000_000_000;

test "fixture games to stats, curves and the website" {
    const gpa = testing.allocator;
    const io = testing.io;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir = try std.fs.path.join(arena, &.{ ".zig-cache", "tmp", &tmp.sub_path });

    const db = try store.schema.memory();
    defer db.close();
    try fill(arena, db);

    var st = try stats.build(gpa, db, &.{patch}, &.{"EUW1"});
    defer st.builder.deinit();
    try testing.expectEqual(games, st.summary.games);
    var model: std.Io.Writer.Allocating = .init(arena);
    try st.builder.write(&model.writer, patch);
    _ = try core.Stats.parse(arena, model.written());

    // Draft rows of the same games, as `meiolol draft-backfill` adds them
    try db.exec("INSERT INTO draft_backfill SELECT match_id FROM matches");
    var drafts: store.draft.Builder = try .init(db);
    defer drafts.deinit();
    _ = try store.draft.backfillChunk(gpa, db, &drafts, 100);
    var reader: store.draft.Reader = try .init(gpa, db, .{ .patches = &.{patch}, .platforms = &.{"EUW1"} });
    defer reader.deinit();
    var n_drafts: usize = 0;
    while (try reader.next()) |d| : (n_drafts += 1) {
        for (d.picks) |p| try testing.expect(p.role != null);
        try testing.expectEqual(@as(?u8, 27), d.minutes);
    }
    try testing.expectEqual(games, n_drafts);

    var cv = try curves.build(gpa, db, &.{patch}, 0, &.{"EUW1"}, &.{});
    defer cv.builder.deinit();
    try testing.expectEqual(games, cv.summary.games);
    const curves_path = try std.fs.path.join(arena, &.{ dir, "curves.bin" });
    var curves_bytes: std.Io.Writer.Allocating = .init(arena);
    try cv.builder.write(&curves_bytes.writer, patch, 1);
    try tmp.dir.writeFile(io, .{ .sub_path = "curves.bin", .data = curves_bytes.written() });

    // Builds count Platinum IV and up only: one rank snapshot below it is left out
    try db.exec("UPDATE participants SET tier = CASE slot WHEN 5 THEN 'GOLD' ELSE 'PLATINUM' END");
    var bd = try builds.build(gpa, db, &build_data, .{ .patches = &.{patch}, .platforms = &.{"EUW1"} });
    defer bd.deinit();
    try testing.expectEqual(games, bd.timelines);
    const build_file = try bd.file(arena, &build_data, patch, "PLATINUM", 10);
    try testing.expectEqual(9, build_file.builds.len);
    const darius = build_file.get(122, .top).?;
    try testing.expectEqual(games, darius.games);
    try testing.expectEqual(games, darius.get(.start).?.games);
    try testing.expectEqualSlices(u32, &.{ 4, 6 }, darius.get(.spells).?.options[0].v);
    const builds_json = try std.json.Stringify.valueAlloc(arena, build_file, .{});
    try tmp.dir.writeFile(io, .{ .sub_path = "builds.json", .data = builds_json });
    const builds_path = try std.fs.path.join(arena, &.{ dir, "builds.json" });

    const out = try std.fs.path.join(arena, &.{ dir, "site" });
    const opts: site.Options = .{
        .out_dir = out,
        .patches = &.{patch},
        .since_ms = 0,
        .all_platforms = &.{"EUW1"},
        .contact = "test@example.com",
        .updated = "1 January 2026",
        // No daily: puzzles need three other options for a slot, more than 10 champions
        .curves = @splat(curves_path),
        .builds = .{ null, builds_path, null, builds_path },
    };
    try site.generate(gpa, io, db, opts);
    for ([_][]const u8{
        "index.html",
        "champions.html",
        "role/top.html",
        "table.js",
        "filters.js",
        "patch/index.html",
        "all/patch/index.html",
        "data/stats.bin",
        "matchup/index.html",
        "learn.html",
        "privacy.html",
        "patch/build/darius-top.html",
        "all/patch/build/darius-top.html",
    }) |page| {
        const path = try std.fs.path.join(arena, &.{ out, page });
        std.Io.Dir.cwd().access(io, path, .{}) catch |err| {
            std.debug.print("missing {s}\n", .{page});
            return err;
        };
    }
    // Build page: three games, so no bare win rates; the champion page (root view) links
    // into the patch view's
    const pages = [_]struct { []const u8, []const []const u8 }{
        .{ "patch/build/darius-top.html", &.{ "Conqueror", "few games", "Doran&#39;s Shield", "More data needed", "href=\"../../champion/darius.html?period=patch\"" } },
        // Champion table and page: raw win rate with its interval, every lane opponent
        // (few games: shown, faded) with the curve's gold at 14 linking to the matchup page
        .{ "champions.html", &.{ "data-sortable", "class=\"ci\"", "At least" } },
        .{ "champion/darius.html", &.{ "Lane opponents", "href=\"../matchup/top/mordekaiser-vs-darius.html\"", "Gold at 14", "Search opponent", "data-name=\"Mordekaiser\" class=\"thin\">" } },
        .{ "champion/darius.html", &.{"href=\"../patch/build/darius-top.html\""} },
        // Filters: the champion's counts by region, rank, patch, role and opponent, its
        // bans and each view's curve gold, the players per role for pick rates, and the
        // bar that sums them, written as the root view. One page per champion: the other
        // views link to it with their filters, and its switches set them
        .{ "data/filters/darius.json", &.{ "\"platforms\":[\"EUW1\"]", "\"rows\":[[", "\"bans\":[", "\"gold\":{\"EUW1|days30|\":[" } },
        .{ "data/filters.json", &.{ "\"roles\":[\"top\"", "\"slots\":[[" } },
        .{ "champion/darius.html", &.{ "class=\"filter-bar\"", "data-src=\"../data/filters/darius.json\"", "<option value=\"EUW1\" selected>EUW</option>", "filters.js", "data-id=\"", "data-tile=\"pick\"", "data-early=\"", "href=\"../champion/darius.html?region=all\" data-region=\"all\"" } },
        .{ "all/patch/role/top.html", &.{"href=\"../../../champion/darius.html?region=all&amp;period=patch\""} },
        .{ "all/matchup/top/mordekaiser-vs-darius.html", &.{"href=\"../../../champion/darius.html?region=all\""} },
        // Lane curves: the estimate (curvefit.zig) on the page, k on the method page
        .{ "matchup/top/mordekaiser-vs-darius.html", &.{ "estimated average", "First finished item", "More data needed" } },
        .{ "method.html", &.{"Games to stabilise"} },
    };
    for (pages) |pg| {
        const path = try std.fs.path.join(arena, &.{ out, pg[0] });
        const html = try std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 20));
        for (pg[1]) |want| if (std.mem.indexOf(u8, html, want) == null) {
            std.debug.print("{s} lacks {s}\n", .{ pg[0], want });
            return error.TestUnexpectedResult;
        };
    }

    // Rendered on request (site.Loaded, `meiolol serve --render` and `dev`): every file
    // the static build wrote, byte for byte, and nothing for paths it didn't
    const loaded = try site.Loaded.init(gpa, io, db, opts);
    defer loaded.deinit();
    var out_dir = try std.Io.Dir.cwd().openDir(io, out, .{ .iterate = true });
    defer out_dir.close(io);
    var walker = try out_dir.walk(gpa);
    defer walker.deinit();
    var checked: usize = 0;
    while (try walker.next(io)) |e| {
        if (e.kind != .file or std.mem.endsWith(u8, e.path, ".gz")) continue;
        const want = try out_dir.readFileAlloc(io, e.path, arena, .limited(1 << 24));
        const got = try loaded.get(arena, e.path) orelse {
            std.debug.print("not rendered: {s}\n", .{e.path});
            return error.TestUnexpectedResult;
        };
        try testing.expectEqualStrings(want, got);
        checked += 1;
    }
    try testing.expect(checked > 50);
    // `meiolol render` serving while it loads: a view not loaded yet says so at once
    {
        const early = try site.Loaded.init(gpa, io, db, opts);
        defer early.deinit();
        early.lazy = false;
        try testing.expectError(error.Loading, early.get(arena, "index.html"));
        try early.loadView(site.html.View.all[0]);
        try testing.expect(try early.get(arena, "index.html") != null);
        try testing.expectError(error.Loading, early.get(arena, "patch/index.html"));
    }
    // Thin matchups left out of the static build are still rendered on request
    {
        var s = (try loaded.site(site.html.View.all[0])).*;
        s.arena = arena;
        s.opts.static_min_games = std.math.maxInt(u32);
        for (try site.pagePaths(&s)) |p| try testing.expect(!std.mem.startsWith(u8, p, "matchup/") or std.mem.eql(u8, p, "matchup/index.html"));
        try testing.expect(try loaded.get(arena, "matchup/top/mordekaiser-vs-darius.html") != null);
    }
    for ([_][]const u8{ "champion/nobody.html", "all/champion/darius.html", "matchup/top/darius-vs-mordekaiser.html", "all/daily.html", "patch/learn.html" }) |path| {
        try testing.expectEqual(null, try loaded.get(arena, path));
    }
}

test "admin page from the fixture games and a crawl log" {
    const gpa = testing.allocator;
    const io = testing.io;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir = try std.fs.path.join(arena, &.{ ".zig-cache", "tmp", &tmp.sub_path });

    const db = try store.schema.memory();
    defer db.close();
    try fill(arena, db);
    try db.exec("INSERT INTO draft_backfill SELECT match_id FROM matches");
    var drafts: store.draft.Builder = try .init(db);
    defer drafts.deinit();
    _ = try store.draft.backfillChunk(gpa, db, &drafts, 100);

    // now_s = 2025-10-11 23:10:00
    const report = " info(crawl): 1000 matches/day | ladder pages 1 | mastery 0 | platform req 1" ++
        " | europe {d}m 1t 1ids {d}req | writes {d} in 2 commits, 0 queued, 0 busy | pages written 9, read 9\n";
    var log: std.Io.Writer.Allocating = .init(arena);
    try log.writer.writeAll("2025-10-11 23:00:00 info(crawl): 19 workers for 4 regions\n");
    try log.writer.print("2025-10-11 23:01:00" ++ report, .{ 10, 50, 10 });
    try log.writer.print("2025-10-11 23:02:00" ++ report, .{ 25, 90, 30 });
    try log.writer.writeAll("2025-10-11 23:02:30 warning(riot): 503 (server) on /lol/match/v5/matches/EUW1_7123456, waiting 5s\n");
    try tmp.dir.writeFile(io, .{ .sub_path = "crawl.log", .data = log.written() });

    const out = try std.fs.path.join(arena, &.{ dir, "admin" });
    for (0..2) |_| try admin.generate(gpa, io, db, .{
        .out_dir = out,
        .data_dir = dir,
        .crawl_log = try std.fs.path.join(arena, &.{ dir, "crawl.log" }),
        .now_s = 1760224200,
        .disk = .{ 100, 40, 60 },
        .health = "",
    });
    const html = try std.Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(arena, &.{ out, "index.html" }), arena, .limited(4 << 20));
    for ([_][]const u8{
        "\"name\":\"matches\",\"rows\":3",
        "\"restarts\":[1760223600]",
        "\"m\":[0,0,25,0]",
        "\"text\":\"warning(riot): N (server) on /lol/match/vN/matches/…, waiting Ns\"",
        "\"rows\":3,\"days\":[{\"day\":",
    }) |want| if (std.mem.indexOf(u8, html, want) == null) {
        std.debug.print("admin page lacks {s}\n", .{want});
        return error.TestUnexpectedResult;
    };
    try std.testing.expect(std.mem.indexOf(u8, html, "EUW1_7123456") == null);
    for ([_][]const u8{ "admin.js", "admin.css", "index.html.gz" }) |f| {
        try std.Io.Dir.cwd().access(io, try std.fs.path.join(arena, &.{ out, f }), .{});
    }
    // One history line per build, under one header
    const history = try std.Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(arena, &.{ dir, "admin-history.tsv" }), arena, .limited(1 << 20));
    try testing.expectEqual(3, std.mem.count(u8, history, "\n"));
}

/// Data Dragon's classes for the fixture timeline's purchases (16.20): its finished
/// items and boots; Darius's runes and spells for names
const build_data: ddragon.BuildData = .{
    .version = "16.20.1",
    .legendary = &.{ 2510, 2520, 3071, 3073, 3087, 3094, 3118, 3124, 3179, 3302, 3508, 3814, 4633, 4645, 4646, 6653, 6665, 6672, 6676, 6698, 6699 },
    .trinkets = &.{ 3340, 3363, 3364 },
    .boots = &.{ .{ 3006, 3006 }, .{ 3008, 3008 }, .{ 3009, 3009 }, .{ 3020, 3020 }, .{ 3047, 3047 }, .{ 3111, 3111 } },
    .items = &.{.{ .id = 1054, .name = "Doran's Shield", .icon = "https://example.com/1054.png" }},
    .runes = &.{.{ .id = 8010, .name = "Conqueror", .icon = "https://example.com/8010.png" }},
    .spells = &.{ .{ .id = 4, .name = "Flash" }, .{ .id = 6, .name = "Ghost" } },
};

/// The fixture game stored `games` times under EUW match ids, with its timeline and
/// champion names, as the crawler and `meiolol champions` leave them
fn fill(arena: std.mem.Allocator, db: store.Db) !void {
    const body = @embedFile("riot/testdata/match.json");
    const json = try store.raw.decompress(arena, @embedFile("riot/testdata/timeline.json.gz"));
    const ct = try riot.crawl.compactTimeline(arena, json);
    for (0..games) |n| {
        var doc = try riot.match.parse(arena, body);
        doc.metadata.matchId = try arena.print("EUW1_{d}", .{n + 1});
        doc.info.platformId = "EUW1";
        doc.info.gameVersion = patch ++ ".1.1";
        doc.info.gameStartTimestamp = start_ms;
        try riot.match.storeRows(db, doc, "riot");
        try db.run("INSERT INTO timeline.timelines VALUES (?,?,?,?)", .{
            doc.metadata.matchId, ct.frames, ct.events, store.Blob{ .bytes = ct.blob },
        });
    }
    for (fixture_champions) |c| {
        try db.run("INSERT INTO champions VALUES (?,?,?,'','15.13.1')", .{ c.id, c.key, c.key });
    }
}

/// Champions of the fixture game
const fixture_champions = [_]struct { id: u32, key: []const u8 }{
    .{ .id = 122, .key = "Darius" },
    .{ .id = 32, .key = "Amumu" },
    .{ .id = 61, .key = "Orianna" },
    .{ .id = 29, .key = "Twitch" },
    .{ .id = 555, .key = "Pyke" },
    .{ .id = 82, .key = "Mordekaiser" },
    .{ .id = 64, .key = "LeeSin" },
    .{ .id = 103, .key = "Ahri" },
    .{ .id = 145, .key = "Kaisa" },
    .{ .id = 497, .key = "Rakan" },
};
