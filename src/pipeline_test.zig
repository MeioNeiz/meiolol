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
const lean = @import("lean.zig");
const draftmodel = @import("draftmodel.zig");
const lanemodel = @import("lanemodel.zig");
const ddragon = @import("ddragon.zig");
const site = @import("site/root.zig");
const admin = @import("admin.zig");
const api = @import("api/root.zig");
const lab_rows = @import("lab/rows.zig");
const lab_pack = @import("lab/pack.zig");
const lab_seatstats = @import("lab/seatstats.zig");
const lab_events = @import("lab/events.zig");
const objectives = @import("objectives.zig");

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
    // Ranked flex copies (the crawler's --flex-calls-per-day sample): every count below
    // and every site file stays as for the solo games alone
    try fillFlex(arena, db);

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

    // Early or late (`meiolol lean`): every fixture game counts, too few for any line
    var ln = try lean.load(gpa, db, &.{patch}, &.{"EUW1"}, 0, std.math.maxInt(i64));
    defer ln.deinit(gpa);
    try testing.expectEqual(games, ln.list.items.len);
    const lf = try lean.fit(gpa, ln.list.items, ln.champs.ids.items.len);
    defer lf.deinit(gpa);
    var lean_bytes: std.Io.Writer.Allocating = .init(arena);
    try lean.write(&lean_bytes.writer, &lf, ln.champs.ids.items, ln.list.items, "every region, last 30 days");
    const lean_file = try lean.File.parse(arena, lean_bytes.written());
    try testing.expectEqual(games, lean_file.get(122, .top).?.games);
    try tmp.dir.writeFile(io, .{ .sub_path = "lean.tsv", .data = lean_bytes.written() });
    const lean_path = try std.fs.path.join(arena, &.{ dir, "lean.tsv" });

    // Your games example (`meiolol your-example`): a player per role, their games as the
    // API answers, with the lane over the curve, and nothing that names the player or match
    const set: api.game.CurveSet = .{ .files = &.{.{
        .label = patch,
        .curves = try core.curvesfile.Curves.parse(arena, curves_bytes.written()),
    }} };
    const examples = (try api.example.buildAll(arena, db, set, .{ .since_ms = 0, .min_games = games })).?;
    try testing.expectEqualStrings("mid", examples.default);
    inline for (core.Role.all) |r| {
        const ex = @field(examples, r.label()).?;
        try testing.expectEqual(games, ex.report.?.games.len);
        const first = ex.report.?.games[0];
        try testing.expectEqualStrings(r.label(), first.role.?);
        try testing.expectEqual(@mod(start_ms, std.time.ms_per_day), start_ms - first.start_ms);
        try testing.expect(first.lane.?.curve != null and first.turning != null);
    }
    const example_json = try api.example.json(arena, examples);
    for ([_][]const u8{ "\"default\":\"mid\"", "\"support\":{\"state\":\"ready\"", "\"name\":\"Example player\"", "\"lane\":{\"gold\":[" }) |want| {
        try testing.expect(std.mem.indexOf(u8, example_json, want) != null);
    }
    try testing.expect(std.mem.indexOf(u8, example_json, "EUW1_") == null);
    try db.run("INSERT INTO forgotten SELECT DISTINCT puuid, 0 FROM participants", .{});
    try testing.expectEqual(null, try api.example.buildAll(arena, db, set, .{ .since_ms = 0, .min_games = 1 }));
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
        .lean = lean_path,
    };
    try site.generate(gpa, io, db, opts);
    try expectSiteFiles(arena, io, out);
    for ([_][]const u8{
        "index.html",
        "champions.html",
        "role/top.html",
        "table.js",
        "filters.js",
        "reasons.js",
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
        // (few games: shown, faded), it and the curve's gold at 14 linking to the matchup
        // page from the champion's side
        .{ "champions.html", &.{ "data-sortable", "class=\"ci\"", "own win rates spread around it", "id=\"wr-edge\"", "opacity:" } },
        .{ "champion/darius.html", &.{ "Lane opponents", "<a class=\"champ\" href=\"../matchup/top/darius-vs-mordekaiser.html\" title=\"Darius vs Mordekaiser\">", "href=\"../matchup/top/darius-vs-mordekaiser.html\" title=\"Lane curves", "Darius's gold lead at 14 min<small class=\"sub\">average, then 8 games in 10</small>", "Search opponent", "data-name=\"Mordekaiser\" class=\"thin\">" } },
        // Hardest first by the rate shrunk with the role's k; opponents under 1% of the
        // champion's games hidden by default (the Opponents filter's p1). Rank filter from
        // Platinum, the tier the crawl samples
        .{ "champion/darius.html", &.{ "data-sortable data-k=\"", "<option value=\"p1\" selected>", "<option value=\"\" selected>All (Platinum+ games)</option><option value=\"4\">Platinum+ players</option>", "Challenger players</option>", "last 30 days, Platinum+ games</span>" } },
        .{ "champions.html", &.{"Platinum+ ranked solo/duo games in EUW, last 30 days."} },
        .{ "index.html", &.{"<a href=\"download.html\">Coming: a champ select helper for Windows</a>"} },
        // Daily Draft: a game at least a week old, read in words (no draft win chance or
        // points); reasons from the list Learn uses
        .{ "daily.html", &.{ "at least a week old", "95% sure it is not even", "<script src=\"reasons.js\" defer></script>" } },
        .{ "privacy.html", &.{"the date\nshown is the puzzle's, not the game's"} },
        .{ "matchup/index.html", &.{ "data-min-search", "<li data-games=\"3\" data-name=\"", "<section data-min-group><h2>Top ", "</ul></section>" } },
        .{ "champion/darius.html", &.{"href=\"../patch/build/darius-top.html\""} },
        .{ "champion/darius.html", &.{"win rates on Darius: more data needed (0 players in EUW with 10+ games on it, 20 needed)."} },
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
        // Either side's page, each swapping to the other
        .{ "matchup/top/mordekaiser-vs-darius.html", &.{ "<h1>Mordekaiser vs Darius</h1>", "class=\"swap\" href=\"darius-vs-mordekaiser.html\"" } },
        .{ "matchup/top/darius-vs-mordekaiser.html", &.{ "<h1>Darius vs Mordekaiser</h1>", "class=\"swap\" href=\"mordekaiser-vs-darius.html\"", "From Darius's side" } },
        .{ "method.html", &.{ "Games to stabilise", "<h2 id=\"lean\">Early or late</h2>" } },
        // Early or late: three games, so no numbers, only that it can't tell yet
        .{ "champion/darius.html", &.{ "<b>Early or late:</b> too few games yet to tell.", "Games still going at 20 min: 3 (every region, last 30 days)", "href=\"../method.html#lean\"" } },
    };
    for (pages) |pg| {
        const path = try std.fs.path.join(arena, &.{ out, pg[0] });
        const html = try std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 20));
        for (pg[1]) |want| if (std.mem.indexOf(u8, html, want) == null) {
            std.debug.print("{s} lacks {s}\n", .{ pg[0], want });
            return error.TestUnexpectedResult;
        };
    }
    // Data is Platinum+ (the crawl's floor): no lower tier to filter by, no "all ranks"
    for ([_][]const u8{ "champions.html", "champion/darius.html" }) |page| {
        const path = try std.fs.path.join(arena, &.{ out, page });
        const html = try std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 20));
        for ([_][]const u8{ "all ranks", "All ranks", ">Gold+" }) |bad| if (std.mem.indexOf(u8, html, bad) != null) {
            std.debug.print("{s} has {s}\n", .{ page, bad });
            return error.TestUnexpectedResult;
        };
    }
    // Three games: greyed out, so no plain verdict above the gold chart (matchup.verdict)
    {
        const path = try std.fs.path.join(arena, &.{ out, "matchup/top/mordekaiser-vs-darius.html" });
        const html = try std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 20));
        try testing.expect(std.mem.indexOf(u8, html, "class=\"verdict") == null);
    }
    // table.js finds each search's and rare button's table by id: every target on the page
    for ([_][]const u8{ "champions.html", "role/top.html", "champion/darius.html" }) |page| {
        const path = try std.fs.path.join(arena, &.{ out, page });
        const html = try std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 20));
        var found: usize = 0;
        for ([_][]const u8{ "data-filter=\"", "data-show-rare=\"" }) |attr| {
            var it = std.mem.splitSequence(u8, html, attr);
            _ = it.next();
            while (it.next()) |rest| {
                const id = rest[0..std.mem.indexOfScalar(u8, rest, '"').?];
                const want = try std.fmt.allocPrint(arena, "id=\"{s}\"", .{id});
                if (std.mem.indexOf(u8, html, want) == null) {
                    std.debug.print("{s}: {s}{s}\" has no table\n", .{ page, attr, id });
                    return error.TestUnexpectedResult;
                }
                found += 1;
            }
        }
        if (found == 0) {
            std.debug.print("{s}: no table search\n", .{page});
            return error.TestUnexpectedResult;
        }
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
    // `meiolol site --views` and `render` reading it: the same bytes for every file
    {
        for (site.html.View.all) |v| try loaded.loadView(v);
        const views_path = try std.fs.path.join(arena, &.{ dir, "views.bin" });
        try loaded.writeViews(views_path);
        const from_file = try site.Loaded.readViews(gpa, io, db, views_path, arena);
        defer from_file.deinit();
        try testing.expectEqualDeep(loaded.opts, from_file.opts);
        walker.deinit();
        walker = try out_dir.walk(gpa);
        var same: usize = 0;
        while (try walker.next(io)) |e| {
            if (e.kind != .file or std.mem.endsWith(u8, e.path, ".gz")) continue;
            const want = try out_dir.readFileAlloc(io, e.path, arena, .limited(1 << 24));
            try testing.expectEqualStrings(want, (try from_file.get(arena, e.path)).?);
            same += 1;
        }
        try testing.expectEqual(checked, same);
        // A deploy's round (--reuse): every part kept, so no tallies, and the same file
        const views_bytes = try std.Io.Dir.cwd().readFileAlloc(io, views_path, arena, .limited(1 << 30));
        const again_path = try std.fs.path.join(arena, &.{ dir, "views-again.bin" });
        {
            const again = try site.Loaded.init(gpa, io, db, opts);
            defer again.deinit();
            try again.reuseViews(views_path);
            for (site.html.View.all) |v| try again.loadView(v);
            try testing.expect(again.extras.people == null);
            try again.writeViews(again_path);
            try testing.expectEqualSlices(u8, views_bytes, try std.Io.Dir.cwd().readFileAlloc(io, again_path, arena, .limited(1 << 30)));
        }
        // One part another binary's (the people part of the root view: its key flipped):
        // loaded again, the same bytes
        {
            const stale = try arena.dupe(u8, views_bytes);
            // After the magic and format: part tag, view, key, length, data
            var at: usize = 16;
            const people_tag = 3;
            while (stale[at] != people_tag or stale[at + 1] != 0) {
                at += 18 + std.mem.readInt(u64, stale[at + 10 ..][0..8], .little);
            }
            stale[at + 2] ^= 1;
            try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = again_path, .data = stale });
            const again = try site.Loaded.init(gpa, io, db, opts);
            defer again.deinit();
            try again.reuseViews(again_path);
            for (site.html.View.all) |v| try again.loadView(v);
            try testing.expect(again.extras.people != null);
            try again.writeViews(again_path);
            try testing.expectEqualSlices(u8, views_bytes, try std.Io.Dir.cwd().readFileAlloc(io, again_path, arena, .limited(1 << 30)));
        }
        // From the database in files, as on the box: filters beside the people tallies,
        // each on connections of its own and in runs at once. The same bytes
        {
            const files = try std.fs.path.join(arena, &.{ dir, "db" });
            try std.Io.Dir.cwd().createDirPath(io, files);
            for ([_][]const u8{ "main", "raw", "timeline" }, [_][]const u8{ "meiolol.db", "raw.db", "timeline.db" }) |schema, name| {
                const sql = try std.fmt.allocPrintSentinel(arena, "VACUUM {s} INTO '{s}/{s}'", .{ schema, files, name }, 0);
                try db.exec(sql);
            }
            const file_db = try store.schema.open(gpa, files);
            defer file_db.close();
            const again = try site.Loaded.init(gpa, io, file_db, opts);
            defer again.deinit();
            for (site.html.View.all) |v| try again.loadView(v);
            try again.writeViews(again_path);
            try testing.expectEqualSlices(u8, views_bytes, try std.Io.Dir.cwd().readFileAlloc(io, again_path, arena, .limited(1 << 30)));
        }
        // Another binary's types: refused, for the database load instead
        const bytes = try std.Io.Dir.cwd().readFileAlloc(io, views_path, arena, .limited(1 << 30));
        // The fingerprint follows the 8-byte magic
        bytes[8] ^= 1;
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = views_path, .data = bytes });
        try testing.expectError(error.ViewsMismatch, site.Loaded.readViews(gpa, io, db, views_path, arena));
    }
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
    for ([_][]const u8{ "champion/nobody.html", "all/champion/darius.html", "matchup/top/darius-vs-darius.html", "matchup/mid/darius-vs-mordekaiser.html", "all/daily.html", "patch/learn.html", "patch/", "nosuch/index.html", "data/filters/nobody.json", "data/your-example.json" }) |path| {
        try testing.expectEqual(null, try loaded.get(arena, path));
    }

    // `--static core` (deploy/web-loop.sh): only core_static and the front-end files, all
    // at the site root; everything the full build writes is still served (public here,
    // so the pages differ from the full build's by the preview banner), and the core
    // files are the renderer's bytes too
    try tmp.dir.writeFile(io, .{ .sub_path = "your-example.json", .data = example_json });
    var core_opts = opts;
    core_opts.out_dir = try std.fs.path.join(arena, &.{ dir, "core" });
    core_opts.static = .core;
    core_opts.public = true;
    core_opts.origin = "https://x.io";
    core_opts.riot_txt = "riot-check";
    core_opts.your_example = try std.fs.path.join(arena, &.{ dir, "your-example.json" });
    try site.generate(gpa, io, db, core_opts);
    const core_loaded = try site.Loaded.init(gpa, io, db, core_opts);
    defer core_loaded.deinit();
    var core_dir = try std.Io.Dir.cwd().openDir(io, core_opts.out_dir, .{ .iterate = true });
    defer core_dir.close(io);
    var core_walker = try core_dir.walk(gpa);
    defer core_walker.deinit();
    var core_files: usize = 0;
    while (try core_walker.next(io)) |e| {
        try testing.expect(e.kind == .file);
        if (std.mem.endsWith(u8, e.path, ".gz")) continue;
        try testing.expect(site.isStatic(core_opts, "", e.path));
        const want = try core_dir.readFileAlloc(io, e.path, arena, .limited(1 << 24));
        try testing.expectEqualStrings(want, (try core_loaded.get(arena, e.path)).?);
        core_files += 1;
    }
    for (site.core_static) |name| try core_dir.access(io, name, .{});
    walker.deinit();
    walker = try out_dir.walk(gpa);
    while (try walker.next(io)) |e| {
        if (e.kind != .file or std.mem.endsWith(u8, e.path, ".gz")) continue;
        if (site.isStatic(core_opts, "", e.path)) try core_dir.access(io, e.path, .{});
        if (try core_loaded.get(arena, e.path) == null) {
            std.debug.print("not rendered under --static core: {s}\n", .{e.path});
            return error.TestUnexpectedResult;
        }
    }
    try testing.expect(core_files >= site.core_static.len);
    try testing.expectEqualStrings(example_json, (try core_loaded.get(arena, "data/your-example.json")).?);
    // Sitemaps list rendered pages: the root one static, the views' rendered
    const sitemap = try core_dir.readFileAlloc(io, "sitemap.xml", arena, .limited(1 << 20));
    for ([_][]const u8{ "https://x.io/champion/darius.html", "https://x.io/matchup/top/mordekaiser-vs-darius.html", "https://x.io/daily.html", "https://x.io/learn.html" }) |want| {
        try testing.expect(std.mem.indexOf(u8, sitemap, want) != null);
    }
    const patch_sitemap = (try core_loaded.get(arena, "patch/sitemap.xml")).?;
    try testing.expect(std.mem.indexOf(u8, patch_sitemap, "https://x.io/patch/build/darius-top.html") != null);
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
    try log.writer.writeAll("2025-10-11 23:02:30 warning(riot): 429 (server) on /lol/match/v5/matches/EUW1_7123456, waiting 5s\n");
    try log.writer.writeAll("2025-10-11 23:03:00 error(riot): 403 on /lol/match/v5/matches/EUW1_7123457: key missing or expired\n");
    try log.writer.writeAll("KEY REJECTED\n");
    try tmp.dir.writeFile(io, .{ .sub_path = "crawl.log", .data = log.written() });
    try tmp.dir.writeFile(io, .{ .sub_path = "eval-latest.md", .data = "# meiolol eval\n" });
    try tmp.dir.writeFile(io, .{ .sub_path = "storage.tsv", .data = "db\tname\tkind\tbytes\tcells\nmeiolol\tmatches\ttable\t4096\t12\n" });
    try tmp.dir.writeFile(io, .{ .sub_path = "admin-actions.log", .data = "2025-10-11T23:05:00Z\tcrawl-restart\tok\t\n" });
    try tmp.dir.createDirPath(io, "backups/segments");
    try tmp.dir.writeFile(io, .{ .sub_path = "backups/segments/a", .data = "12345" });
    try tmp.dir.writeFile(io, .{ .sub_path = "crawl.args", .data = "--proxy 10.0.0.3:8092\n" });
    try tmp.dir.writeFile(io, .{ .sub_path = "deploys.tsv", .data = "time\tsha\tstep\tstatus\tdetail\n" ++
        "1760224000\tab12cd\tdeploy\tstart\tdeploy/box.sh web start on the Mac\n" ++
        "1760224010\tab12cd\tcommit\tinfo\tab12cd fix EUW1_7123456's timeline\n" ++
        "1760224020\tnot-a-sha\tdeploy\tok\tdropped\n" ++
        "1760224030\tab12cd\tswap\tok\tmeiolol-render@a serving; stopped meiolol-render@b\n" });

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
        "\"text\":\"warning(riot): 429 (server) on /lol/match/vN/matches/…, waiting Ns\"",
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
        "\"deploy_events\":[[1760224000,\"ab12cd\",\"deploy\",\"start\",",
        "\"riot\":{\"app_limit\":\"20:1,100:120\",\"method_limits\":{},\"crawl_args\":\"--proxy 10.0.0.3:8092\"," ++
            "\"key_problems\":[[1760223780,\"error(riot): 403 on /lol/match/vN/matches/…: key missing or expired\"]," ++
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
        "\"deploys\":[[1760224000,\"ab12cd\",\"deploy\",\"start\",\"deploy/box.sh web start on the Mac\"]," ++
            "[1760224010,\"ab12cd\",\"commit\",\"info\",\"ab12cd fix …'s timeline\"]," ++
            "[1760224030,\"ab12cd\",\"swap\",\"ok\",\"meiolol-render@a serving; stopped meiolol-render@b\"]]",
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

test "fixture games to the Draft tester's draft and lane models" {
    const gpa = testing.allocator;
    const io = testing.io;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir = try std.fs.path.join(arena, &.{ ".zig-cache", "tmp", &tmp.sub_path, "tester" });
    const db = try store.schema.memory();
    defer db.close();
    // The protocol's cuts want 100 played games
    try fillGames(arena, db, 150, true);
    var log: std.Io.Writer.Allocating = .init(arena);
    try draftmodel.run(gpa, io, db, dir, &log.writer);
    const File = struct {
        format: []const u8,
        version: u32,
        meta: struct { training_games: usize, patch: []const u8 },
        champions: []const struct { id: u32 },
        model: struct { kind: []const u8, terms: []const struct { champion: u32 }, pairs: struct { cells: []const [5]f64 } },
    };
    const text = try tmp.dir.readFileAlloc(io, "tester/draft-model.json", arena, .limited(16 << 20));
    const m = try std.json.parseFromSliceLeaky(File, arena, text, .{ .ignore_unknown_fields = true });
    try testing.expectEqualStrings("meiolol-draft-model", m.format);
    try testing.expectEqual(4, m.version);
    try testing.expectEqualStrings("draft", m.model.kind);
    try testing.expectEqual(150, m.meta.training_games);
    try testing.expectEqualStrings("15.13", m.meta.patch);
    // Every game the same ten champions: one term each; 10 ally pairs a team, 10 matchups
    // across roles each way, 5 lane matchups
    try testing.expectEqual(10, m.model.terms.len);
    try testing.expectEqual(45, m.model.pairs.cells.len);
    const Ref = struct { drafts: []const struct { label: []const u8 }, slots: []const struct { options: []const struct { champion: u32 } } };
    const ref_text = try tmp.dir.readFileAlloc(io, "tester/draft-ref.json", arena, .limited(1 << 20));
    const ref = try std.json.parseFromSliceLeaky(Ref, arena, ref_text, .{ .ignore_unknown_fields = true });
    // Three test games whole and part open, the empty board, no terms (no Rammus)
    try testing.expectEqual(8, ref.drafts.len);
    try testing.expectEqual(2, ref.slots.len);

    try lanemodel.run(gpa, io, db, dir, &log.writer);
    const Lane = struct {
        format: []const u8,
        meta: struct { training_games: usize, dev: []const struct { outcome: []const u8 } },
        outcomes: []const []const u8,
        champ: []const struct { champion: u32, n: u32, b: [4]f64 },
        pairs: []const [12]f64,
    };
    const lane_text = try tmp.dir.readFileAlloc(io, "tester/lane-model.json", arena, .limited(16 << 20));
    const lane = try std.json.parseFromSliceLeaky(Lane, arena, lane_text, .{ .ignore_unknown_fields = true });
    try testing.expectEqualStrings("meiolol-lane-model", lane.format);
    try testing.expectEqual(150, lane.meta.training_games);
    try testing.expectEqual(4, lane.meta.dev.len);
    try testing.expectEqualStrings("lanediff14", lane.outcomes[1]);
    // Both sides' laners in every role; rows only from the two thirds of games whose
    // timeline reached 15:00 (fillGames leaves every third without one)
    try testing.expectEqual(10, lane.champ.len);
    try testing.expectEqual(10, lane.pairs.len);
    for (lane.champ) |t| try testing.expectEqual(100, t.n);
    _ = try tmp.dir.readFileAlloc(io, "tester/lane-ref.json", arena, .limited(1 << 20));
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
    var day0: i64 = 0;
    {
        const db = try store.schema.open(gpa, snap);
        defer db.close();
        // The protocol's split wants 100 games, 20 of them test games
        try fillGames(arena, db, 150, true);
        try db.exec("UPDATE participants SET tier = CASE slot % 3 WHEN 0 THEN 'GOLD' " ++
            "WHEN 1 THEN NULL ELSE 'DIAMOND' END, division = 'II'");
        // The same player in each slot of every game, slot 9 unknown: experience fills in.
        // p2 and p3 swap slots (and roles) in odd games: off-role shares between 0 and 1
        try db.exec("UPDATE participants SET puuid = CASE WHEN slot = 9 THEN NULL " ++
            "WHEN slot IN (2, 3) AND CAST(substr(match_id, instr(match_id, '_') + 1) AS INTEGER) % 2 = 1 " ++
            "THEN 'p' || (5 - slot) ELSE 'p' || slot END");
        // Ladder: p0 changes rank on the third day (Gold II before, Diamond I from then);
        // p1 last seen on the first day; the rest unknown before their game's day
        day0 = @divFloor((try db.scalar("SELECT min(game_start) FROM matches", .{})).?, 86_400_000);
        const p0 = store.schema.puuidKey("p0");
        try db.run("INSERT INTO rank_history VALUES (?1, ?2, 25, 0, 1, 0), (?1, ?3, 12, 0, 2, 0)", .{ p0, day0, day0 + 2 });
        try db.run("INSERT INTO ranks VALUES (?1, 12, ?2, 0, 2, 0), (?3, 25, ?4, 0, 1, 0)", .{ p0, day0 + 5, store.schema.puuidKey("p1"), day0 });
    }
    var legendaries: std.AutoHashMapUnmanaged(u64, void) = .empty;
    defer legendaries.deinit(gpa);
    for (build_data.legendary) |item| try legendaries.put(gpa, lab_rows.legendaryKey(stats.patchKey(patch), item), {});

    var sql = try lab_rows.loadSql(gpa, snap, &legendaries);
    defer sql.deinit();
    // The fixture covers what the pack must carry: both sides of the split, two
    // platforms, games with and without timeline outcomes, ranked and unranked rows,
    // players with and without earlier games
    var seen: struct { tests: usize = 0, na: usize = 0, na_tests: usize = 0, tl: usize = 0, unranked: usize = 0, items: usize = 0, exp: usize = 0, rates: usize = 0, offrole: usize = 0, days: usize = 0, start: [3]usize = @splat(0) } = .{};
    for (sql.games) |g| {
        try testing.expect(g.duration_s > 1000 and g.duration_s <= 1620);
        seen.tests += @intFromBool(g.is_test);
        seen.na += @intFromBool(g.platform != sql.games[sql.games.len - 1].platform);
        // One time cut over every platform
        seen.na_tests += @intFromBool(g.is_test and g.platform != sql.games[sql.games.len - 1].platform);
        seen.tl += @intFromBool(g.timeline15);
    }
    for (sql.rows) |r| {
        seen.unranked += @intFromBool(r.rank_after == null);
        // Gold II = 14, Diamond I = 27 (0 Iron IV): only a sighting on an earlier day counts
        const day = @divFloor(sql.games[r.game].start, 86_400_000) - day0;
        if (r.slot == 0) {
            const want: ?u8 = if (day < 1) null else if (day < 3) 14 else 27;
            try testing.expectEqual(want, r.rank_start);
            seen.start[@min(@as(usize, @intCast(day)), 2)] += 1;
        } else if (r.slot == 1) {
            try testing.expectEqual(@as(?u8, if (day < 1) null else 14), r.rank_start);
        } else try testing.expectEqual(null, r.rank_start);
        seen.items += @intFromBool(!std.math.isNan(r.y[@backingInt(lab_rows.Outcome.first_item)]));
        seen.exp += @intFromBool(r.champ_games > 0);
        seen.rates += @intFromBool(!std.math.isNan(r.gpm_before) and !std.math.isNan(r.cspm_before) and !std.math.isNan(r.dpm_before));
        seen.offrole += @intFromBool(r.offrole_before > 0 and r.offrole_before < 1);
        seen.days += @intFromBool(r.days_since_last > 0);
        try testing.expectEqual(r.slot == 9, r.player == lab_rows.no_player);
    }
    try testing.expect(sql.games.len >= 100);
    try testing.expect(seen.tests > 0 and seen.tests < sql.games.len and seen.na > 0 and seen.na_tests > 0);
    try testing.expect(seen.tl > 0 and seen.tl < sql.games.len and seen.unranked > 0 and seen.items > 0);
    try testing.expect(seen.exp > 0 and seen.exp < sql.rows.len);
    try testing.expect(seen.rates > 0 and seen.rates < sql.rows.len and seen.offrole > 0 and seen.days > 0);
    for (seen.start) |n| try testing.expect(n > 0);

    try testing.expectEqual(null, try lab_pack.read(gpa, io, snap, &legendaries));
    _ = try lab_pack.write(gpa, io, snap, &legendaries);
    var loaded = try lab_rows.load(gpa, snap, &legendaries);
    defer loaded.deinit();
    try expectSameRows(&sql, &loaded);
    var packed_rows = (try lab_pack.read(gpa, io, snap, &legendaries)).?;
    packed_rows.deinit();

    // A copy that keeps mtimes only to the second (rsync from the Mac) still matches
    for ([_][]const u8{ "meiolol.db", "raw.db", "timeline.db" }) |name| {
        const path = try std.fs.path.join(arena, &.{ snap, name });
        const st = try std.Io.Dir.cwd().statFile(io, path, .{});
        const s = st.mtime.toSeconds();
        try std.Io.Dir.cwd().setTimestamps(io, path, .{
            .modify_timestamp = .{ .new = .fromNanoseconds(@as(i96, s) * std.time.ns_per_s) },
        });
    }
    var copied = (try lab_pack.read(gpa, io, snap, &legendaries)).?;
    copied.deinit();

    // An edit to row production (rowsql.zig) makes the pack stale
    lab_pack.test_source_edit = "edit";
    try testing.expectEqual(null, try lab_pack.read(gpa, io, snap, &legendaries));
    lab_pack.test_source_edit = "";
    var unedited = (try lab_pack.read(gpa, io, snap, &legendaries)).?;
    unedited.deinit();

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
    for (loaded2.rows) |r| for (r.stats) |x| try testing.expect(std.math.isNan(x));

    // seat_stats.tsv appearing makes the pack stale; its seats fill in, the rest stay NaN
    const seat_game = loaded2.games[loaded2.rows[0].game].match_id;
    {
        var line: std.Io.Writer.Allocating = .init(arena);
        try line.writer.print("{s}{s}\t{d}", .{ lab_seatstats.header, seat_game, loaded2.rows[0].slot });
        for (0..lab_seatstats.count) |i| try line.writer.print("\t{d}", .{i});
        try line.writer.writeByte('\n');
        const path = try std.fs.path.join(arena, &.{ snap, lab_seatstats.file_name });
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = line.written() });
    }
    try testing.expectEqual(null, try lab_pack.read(gpa, io, snap, &legendaries));
    _ = try lab_pack.write(gpa, io, snap, &legendaries);
    var seated = (try lab_pack.read(gpa, io, snap, &legendaries)).?;
    defer seated.deinit();
    var filled: usize = 0;
    for (seated.rows) |r| {
        if (std.math.isNan(r.stats[0])) continue;
        filled += 1;
        try testing.expectEqualStrings(seat_game, seated.games[r.game].match_id);
        try testing.expectEqual(loaded2.rows[0].slot, r.slot);
        try testing.expectEqual(@as(f32, lab_seatstats.count - 1), r.stats[lab_seatstats.count - 1]);
    }
    try testing.expectEqual(1, filled);
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

test "fixture games to events.tsv" {
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
        try fillGames(arena, db, 150, true);
        // EUW1_1's steal counts: slot 6 took two dragons (both stolen), slot 1 a dragon and
        // baron (one stolen: which is unknown), slot 0 none
        const doc =
            \\{"info":{"participants":[{"participantId":1,"challenges":{"epicMonsterSteals":0}},
            \\{"participantId":2,"challenges":{"epicMonsterSteals":1}},
            \\{"participantId":7,"challenges":{"epicMonsterSteals":2}}]}}
        ;
        try db.run("INSERT INTO raw.raw_docs VALUES ('riot_match', 'EUW1_1', 0, ?)", .{
            store.Blob{ .bytes = try store.raw.compress(arena, doc) },
        });
    }
    const sum = try lab_events.run(gpa, io, snap);
    // Lab games (rows.load) with a timeline: fillGames leaves out every 3rd
    var with_tl: usize = 0;
    {
        var none: std.AutoHashMapUnmanaged(u64, void) = .empty;
        var data = try lab_rows.load(gpa, snap, &none);
        defer data.deinit();
        try testing.expectEqual(data.games.len, sum.games);
        for (data.games) |g| {
            const n = try std.fmt.parseInt(usize, g.match_id[std.mem.indexOfScalar(u8, g.match_id, '_').? + 1 ..], 10);
            with_tl += @intFromBool(n % 3 != 0);
        }
    }
    try testing.expect(with_tl > 50);
    try testing.expectEqual(with_tl, sum.timelines);
    try testing.expectEqual(@as(usize, 1), sum.summaries);
    // The fixture timeline: 64 champion kills, 12 towers, an inhibitor, 8 epic monsters
    try testing.expectEqual(with_tl * (64 + 12 + 1 + 8), sum.lines);

    const path = try std.fs.path.join(arena, &.{ snap, lab_events.file_name });
    const text = try std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(64 << 20));
    try testing.expect(std.mem.startsWith(u8, text, lab_events.header));
    var cols: std.StringHashMapUnmanaged(usize) = .empty;
    var names = std.mem.splitScalar(u8, lab_events.header[0 .. lab_events.header.len - 1], '\t');
    while (names.next()) |n| try cols.put(arena, n, cols.count());

    const json = try store.raw.decompress(arena, @embedFile("riot/testdata/timeline.json.gz"));
    const ct = try riot.crawl.compactTimeline(arena, json);
    const t = try riot.timeline.decode(arena, try store.raw.decompress(arena, ct.blob));
    var lines = std.mem.tokenizeScalar(u8, text[lab_events.header.len..], '\n');
    var seen: struct { first_blood: usize = 0, steal: usize = 0, baron: bool = false } = .{};
    while (lines.next()) |line| {
        var fields: std.ArrayList([]const u8) = .empty;
        var it = std.mem.splitScalar(u8, line, '\t');
        while (it.next()) |f| try fields.append(arena, f);
        try testing.expectEqual(cols.count(), fields.items.len);
        const f = struct {
            fn get(c: *const std.StringHashMapUnmanaged(usize), row: []const []const u8, name: []const u8) []const u8 {
                return row[c.get(name).?];
            }
        }.get;
        const row = fields.items;
        if (std.mem.eql(u8, f(&cols, row, "first_blood"), "1")) {
            seen.first_blood += 1;
            try testing.expectEqualStrings("57862", f(&cols, row, "t_ms"));
            try testing.expectEqualStrings("200", f(&cols, row, "team"));
            try testing.expectEqualStrings("400", f(&cols, row, "bounty"));
        }
        const game1 = std.mem.eql(u8, f(&cols, row, "match_id"), "EUW1_1");
        const subtype = f(&cols, row, "subtype");
        if (game1 and std.mem.eql(u8, subtype, "FIRE_DRAGON")) {
            try testing.expectEqualStrings("1", f(&cols, row, "steal"));
            seen.steal += 1;
        }
        if (game1 and std.mem.eql(u8, subtype, "BARON_NASHOR")) {
            try testing.expectEqualStrings("nan", f(&cols, row, "steal"));
            try testing.expectEqualStrings("100", f(&cols, row, "team"));
            // Before baron: blue took 4 towers and red 3, red 2 dragons to blue's 1,
            // blue all 3 grubs; the state matches objectives' at the event's time
            try testing.expectEqualStrings("1", f(&cols, row, "towers"));
            try testing.expectEqualStrings("-1", f(&cols, row, "dragons"));
            try testing.expectEqualStrings("3", f(&cols, row, "grubs"));
            const at: i64 = try std.fmt.parseInt(i64, f(&cols, row, "t_ms"), 10);
            var last = t.frames[0];
            for (t.frames) |fr| if (fr.t_ms <= at) {
                last = fr;
            };
            const want = objectives.stateBefore(t, last, at);
            const gold = try std.fmt.parseFloat(f32, f(&cols, row, "gold"));
            try testing.expectApproxEqAbs(want[@backingInt(objectives.Feat.gold)], gold, 1e-3);
            seen.baron = true;
        }
        if (!game1 and std.mem.eql(u8, f(&cols, row, "type"), "monster"))
            try testing.expectEqualStrings("nan", f(&cols, row, "steal"));
    }
    try testing.expectEqual(with_tl, seen.first_blood);
    try testing.expectEqual(@as(usize, 1), seen.steal);
    try testing.expect(seen.baron);
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

/// Copies of the fixture game in ranked flex (queue 440), with timelines
fn fillFlex(arena: std.mem.Allocator, db: store.Db) !void {
    const body = @embedFile("riot/testdata/match.json");
    const json = try store.raw.decompress(arena, @embedFile("riot/testdata/timeline.json.gz"));
    const ct = try riot.crawl.compactTimeline(arena, json);
    for (0..games) |n| {
        var doc = try riot.match.parse(arena, body);
        doc.metadata.matchId = try arena.print("EUW1_{d}", .{1000 + n});
        doc.info.platformId = "EUW1";
        doc.info.queueId = riot.endpoints.ranked_flex;
        doc.info.gameVersion = patch ++ ".1.1";
        doc.info.gameStartTimestamp = start_ms;
        try riot.match.storeRows(db, doc, "riot");
        try db.run("INSERT INTO timeline.timelines VALUES (?,?,?,?)", .{
            doc.metadata.matchId, ct.frames, ct.events, store.Blob{ .bytes = ct.blob },
        });
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
