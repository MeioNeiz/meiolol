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
const api = @import("api/root.zig");
const lab_rows = @import("lab/rows.zig");
const lab_pack = @import("lab/pack.zig");

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

    // Your games example (`meiolol your-example`): one player's games as the API
    // answers, with the lane over the curve, and nothing that names the player or match
    const set: api.game.CurveSet = .{ .files = &.{.{
        .label = patch,
        .curves = try core.curvesfile.Curves.parse(arena, curves_bytes.written()),
    }} };
    const example = (try api.example.build(arena, db, set, .{ .since_ms = 0, .min_games = games })).?;
    try testing.expectEqual(games, example.report.?.games.len);
    const first = example.report.?.games[0];
    try testing.expectEqual(@mod(start_ms, std.time.ms_per_day), start_ms - first.start_ms);
    try testing.expect(first.lane.?.curve != null);
    const example_json = try api.gamesJson(arena, example);
    for ([_][]const u8{ "\"state\":\"ready\"", "\"name\":\"Example player\"", "\"lane\":{\"gold\":[" }) |want| {
        try testing.expect(std.mem.indexOf(u8, example_json, want) != null);
    }
    try testing.expect(std.mem.indexOf(u8, example_json, "EUW1_") == null);
    try db.run("INSERT INTO forgotten SELECT DISTINCT puuid, 0 FROM participants", .{});
    try testing.expectEqual(null, try api.example.build(arena, db, set, .{ .since_ms = 0, .min_games = 1 }));
    try db.exec("DELETE FROM forgotten");

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
    try expectSiteFiles(arena, io, out);
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
    try log.writer.writeAll("2025-10-11 23:03:00 error(riot): 403 on /lol/match/v5/matches/EUW1_7123457: key missing or expired\n");
    try log.writer.writeAll("KEY REJECTED\n");
    try tmp.dir.writeFile(io, .{ .sub_path = "crawl.log", .data = log.written() });
    try tmp.dir.writeFile(io, .{ .sub_path = "eval-latest.md", .data = "# meiolol eval\n" });
    try tmp.dir.writeFile(io, .{ .sub_path = "storage.tsv", .data = "db\tname\tkind\tbytes\tcells\nmeiolol\tmatches\ttable\t4096\t12\n" });
    try tmp.dir.writeFile(io, .{ .sub_path = "admin-actions.log", .data = "2025-10-11T23:05:00Z\tcrawl-restart\tok\t\n" });
    try tmp.dir.createDirPath(io, "backups/segments");
    try tmp.dir.writeFile(io, .{ .sub_path = "backups/segments/a", .data = "12345" });
    try tmp.dir.writeFile(io, .{ .sub_path = "crawl.args", .data = "--reserve 20\n" });

    const out = try std.fs.path.join(arena, &.{ dir, "admin" });
    for (0..2) |_| try admin.generate(gpa, io, db, .{
        .out_dir = out,
        .data_dir = dir,
        .crawl_log = try std.fs.path.join(arena, &.{ dir, "crawl.log" }),
        .now_s = 1760224200,
        .disk = .{ 100, 40, 60 },
        .health = "",
        .backups_dir = try std.fs.path.join(arena, &.{ dir, "backups" }),
        .crawl_args = try std.fs.path.join(arena, &.{ dir, "crawl.args" }),
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
    // data.json: the page's data, for polling between rebuilds
    const json = try std.Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(arena, &.{ out, "data.json" }), arena, .limited(4 << 20));
    for ([_][]const u8{
        "\"eval_report\":\"# meiolol eval\\n\"",
        "\"storage\":{\"generated\":",
        "\"rows\":[[\"meiolol\",\"matches\",\"table\",4096,12]]",
        "\"backups\":{\"bytes\":5,\"files\":1,\"newest\":",
        "\"riot\":{\"app_limit\":\"20:1,100:120\",\"method_limits\":{},\"crawl_args\":\"--reserve 20\"," ++
            "\"key_problems\":[[1760223780,\"error(riot): N on /lol/match/vN/matches/…: key missing or expired\"]," ++
            "[1760223780,\"KEY REJECTED\"]]}",
    }) |want| if (std.mem.indexOf(u8, json, want) == null) {
        std.debug.print("data.json lacks {s}\n", .{want});
        return error.TestUnexpectedResult;
    };
    try std.testing.expect(std.mem.indexOf(u8, html, json) != null);
    // live.json (admin_api.zig), its command results given
    const live = try admin.liveJson(arena, io, db, .{
        .data_dir = dir,
        .now_s = 1760224200,
        .services = .{ .@"meiolol-crawl" = "active" },
        .health = "crawler silent",
        .disk = .{ 100, 40, 60 },
        .action = .{ .name = "site-build", .since = 1760224190 },
    });
    for ([_][]const u8{
        "{\"now\":1760224200,\"services\":{\"meiolol-crawl\":\"active\",\"meiolol-web\":\"unknown\",",
        "\"health\":\"crawler silent\",\"crawl\":{\"start\":1760213400,\"step\":60,",
        "\"queues\":{\"match\":",
        "\"disk\":[100,40,60],\"files\":[{\"name\":\"meiolol.db\",",
        "\"actions\":[[1760223900,\"crawl-restart\",\"ok\",\"\"]]",
        "\"running\":{\"eval\":null,\"action\":{\"name\":\"site-build\",\"since\":1760224190}}}",
    }) |want| if (std.mem.indexOf(u8, live, want) == null) {
        std.debug.print("live.json lacks {s}\n{s}\n", .{ want, live });
        return error.TestUnexpectedResult;
    };
    for ([_][]const u8{ "admin.js", "admin.css", "index.html.gz", "data.json.gz" }) |f| {
        try std.Io.Dir.cwd().access(io, try std.fs.path.join(arena, &.{ out, f }), .{});
    }
    // One history line per build, under one header
    const history = try std.Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(arena, &.{ dir, "admin-history.tsv" }), arena, .limited(1 << 20));
    try testing.expectEqual(3, std.mem.count(u8, history, "\n"));
}

test "fixture games to lab rows, from SQLite and packed" {
    const gpa = testing.allocator;
    const io = testing.io;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const snap = try std.fs.path.join(arena, &.{ ".zig-cache", "tmp", &tmp.sub_path });
    {
        const db = try store.schema.open(gpa, snap);
        defer db.close();
        // The protocol's split wants 100 games, 20 of them EUW test games
        try fillGames(arena, db, 150, true);
        try db.exec("UPDATE participants SET tier = CASE slot % 3 WHEN 0 THEN 'GOLD' " ++
            "WHEN 1 THEN NULL ELSE 'DIAMOND' END, division = 'II'");
        // The same player in each slot of every game, slot 9 unknown: experience fills in
        try db.exec("UPDATE participants SET puuid = CASE slot WHEN 9 THEN NULL ELSE 'p' || slot END");
    }
    var legendaries: std.AutoHashMapUnmanaged(u64, void) = .empty;
    defer legendaries.deinit(gpa);
    for (build_data.legendary) |item| try legendaries.put(gpa, lab_rows.legendaryKey(stats.patchKey(patch), item), {});

    var sql = try lab_rows.loadSql(gpa, snap, &legendaries);
    defer sql.deinit();
    // The fixture covers what the pack must carry: both sides of the split, two
    // platforms, games with and without timeline outcomes, ranked and unranked rows,
    // players with and without earlier games
    var seen: struct { tests: usize = 0, na: usize = 0, tl: usize = 0, unranked: usize = 0, items: usize = 0, exp: usize = 0 } = .{};
    for (sql.games) |g| {
        try testing.expect(g.duration_s > 1000 and g.duration_s <= 1620);
        seen.tests += @intFromBool(g.is_test);
        seen.na += @intFromBool(g.platform != sql.games[sql.games.len - 1].platform);
        seen.tl += @intFromBool(g.timeline15);
    }
    for (sql.rows) |r| {
        seen.unranked += @intFromBool(r.rank == null);
        seen.items += @intFromBool(!std.math.isNan(r.y[@backingInt(lab_rows.Outcome.first_item)]));
        seen.exp += @intFromBool(r.champ_games > 0);
    }
    try testing.expect(sql.games.len >= 100);
    try testing.expect(seen.tests > 0 and seen.tests < sql.games.len and seen.na > 0);
    try testing.expect(seen.tl > 0 and seen.tl < sql.games.len and seen.unranked > 0 and seen.items > 0);
    try testing.expect(seen.exp > 0 and seen.exp < sql.rows.len);

    try testing.expectEqual(null, try lab_pack.read(gpa, io, snap, &legendaries));
    _ = try lab_pack.write(gpa, io, snap, &legendaries);
    var loaded = try lab_rows.load(gpa, snap, &legendaries);
    defer loaded.deinit();
    try expectSameRows(&sql, &loaded);
    var packed_rows = (try lab_pack.read(gpa, io, snap, &legendaries)).?;
    packed_rows.deinit();

    // A pack from before a field was added (games.duration_s here) is stale
    {
        const manifest_path = try std.fs.path.join(arena, &.{ snap, "pack", "manifest" });
        const manifest = try std.Io.Dir.cwd().readFileAlloc(io, manifest_path, arena, .limited(1 << 20));
        const line = "column games.duration_s u32 1\n";
        const at = std.mem.indexOf(u8, manifest, line).?;
        const old = try std.mem.concat(arena, u8, &.{ manifest[0..at], manifest[at + line.len ..] });
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = manifest_path, .data = old });
        try testing.expectEqual(null, try lab_pack.read(gpa, io, snap, &legendaries));
    }

    // Other legendaries, or a changed database: the pack is stale
    var none: std.AutoHashMapUnmanaged(u64, void) = .empty;
    try testing.expectEqual(null, try lab_pack.read(gpa, io, snap, &none));
    {
        const db = try store.schema.open(gpa, snap);
        defer db.close();
        try db.exec("DELETE FROM timeline.timelines WHERE match_id = 'EUW1_1'");
        try db.exec("INSERT INTO champions VALUES (1, 'Annie', 'Annie', zeroblob(100000), '15.13.1')");
    }
    try testing.expectEqual(null, try lab_pack.read(gpa, io, snap, &legendaries));
    var sql2 = try lab_rows.load(gpa, snap, &legendaries);
    defer sql2.deinit();
    try testing.expect(lab_pack.firstDiff(&sql, &sql2, &.{}) != null);
    // Packing again replaces the old pack
    _ = try lab_pack.write(gpa, io, snap, &legendaries);
    var loaded2 = (try lab_pack.read(gpa, io, snap, &legendaries)).?;
    defer loaded2.deinit();
    try expectSameRows(&sql2, &loaded2);
}

/// Every generated file's hash, against src/testdata/site-files.txt: a refactor that
/// claims the same output shows it, and a change on purpose shows which files it moved.
/// Assets copied from static/ or compiled (wasm) are left out
fn expectSiteFiles(arena: std.mem.Allocator, io: std.Io, out: []const u8) !void {
    var dir = try std.Io.Dir.cwd().openDir(io, out, .{ .iterate = true });
    defer dir.close(io);
    var walker = try dir.walk(arena);
    defer walker.deinit();
    var lines: std.ArrayList([]const u8) = .empty;
    while (try walker.next(io)) |e| {
        if (e.kind != .file) continue;
        const ext = std.fs.path.extension(e.path);
        const copied = [_][]const u8{ ".gz", ".js", ".css", ".svg", ".woff2", ".wasm" };
        if (for (copied) |c| (if (std.mem.eql(u8, c, ext)) break true) else false) continue;
        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(try dir.readFileAlloc(io, e.path, arena, .limited(1 << 24)), &hash, .{});
        try lines.append(arena, try arena.print("{s} {s}\n", .{ e.path, std.fmt.bytesToHex(hash[0..8].*, .lower) }));
    }
    std.mem.sort([]const u8, lines.items, {}, struct {
        fn f(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.f);
    const got = try std.mem.concat(arena, u8, lines.items);
    const want = @embedFile("testdata/site-files.txt");
    if (std.mem.eql(u8, got, want)) return;
    // Paths whose line is in one list only
    for ([_][]const u8{ got, want }, [_][]const u8{ "now", "was" }) |list, label| {
        var it = std.mem.tokenizeScalar(u8, list, '\n');
        const other = if (list.ptr == got.ptr) want else got;
        while (it.next()) |line| {
            if (std.mem.indexOf(u8, other, line) == null) std.debug.print("site file {s}: {s}\n", .{ label, line });
        }
    }
    const new_path = ".zig-cache/site-files.txt";
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = new_path, .data = got });
    std.debug.print("site output changed; if on purpose: cp {s} src/testdata/site-files.txt\n", .{new_path});
    return error.TestUnexpectedResult;
}

fn expectSameRows(want: *const lab_rows.Data, got: *const lab_rows.Data) !void {
    var buf: [256]u8 = undefined;
    if (lab_pack.firstDiff(want, got, &buf)) |d| {
        std.debug.print("packed rows differ: {s}\n", .{d});
        return error.TestUnexpectedResult;
    }
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
    try fillGames(arena, db, games, false);
}

/// varied: an hour apart, lengths varied, every 4th on NA1, every 3rd without a timeline
fn fillGames(arena: std.mem.Allocator, db: store.Db, n_games: usize, varied: bool) !void {
    const body = @embedFile("riot/testdata/match.json");
    const json = try store.raw.decompress(arena, @embedFile("riot/testdata/timeline.json.gz"));
    const ct = try riot.crawl.compactTimeline(arena, json);
    for (0..n_games) |n| {
        const platform = if (varied and n % 4 == 3) "NA1" else "EUW1";
        var doc = try riot.match.parse(arena, body);
        doc.metadata.matchId = try arena.print("{s}_{d}", .{ platform, n + 1 });
        doc.info.platformId = platform;
        doc.info.gameVersion = patch ++ ".1.1";
        doc.info.gameStartTimestamp = if (varied) start_ms + @as(i64, @intCast(n)) * 3_600_000 else start_ms;
        if (varied) doc.info.gameDuration -= @as(i64, @intCast(n % 7)) * 60;
        try riot.match.storeRows(db, doc, "riot");
        if (varied and n % 3 == 2) continue;
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
