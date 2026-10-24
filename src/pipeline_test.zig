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
const digests = @import("digests.zig");
const ddragon = @import("ddragon.zig");
const site = @import("site/root.zig");
const admin = @import("admin.zig");
const api = @import("api/root.zig");
const lab_rows = @import("lab/rows.zig");
const lab_pack = @import("lab/pack.zig");
const lab_seatstats = @import("lab/seatstats.zig");
const lab_events = @import("lab/events.zig");
const objectives = @import("objectives.zig");
const partials = @import("partials.zig");
const forget = @import("forget.zig");

const testing = std.testing;
const games = 3;
const patch = "15.13";
/// Fixed game start; the 30-day views start there
const start_ms = 1_752_000_000_000;
/// The patch before, its games a day earlier: in the patch day only (patch.html)
const prev_patch = "15.12";

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

    var cv = try curves.build(gpa, io, db, &.{patch}, 0, &.{"EUW1"}, &.{});
    defer cv.builder.deinit();
    try testing.expectEqual(games, cv.summary.games);
    const curves_path = try std.fs.path.join(arena, &.{ dir, "curves.bin" });
    var curves_bytes: std.Io.Writer.Allocating = .init(arena);
    try cv.builder.write(&curves_bytes.writer, patch, 1);
    try tmp.dir.writeFile(io, .{ .sub_path = "curves.bin", .data = curves_bytes.written() });

    // Builds count Platinum IV and up only: one rank snapshot below it is left out
    try db.exec("UPDATE participants SET tier = CASE slot WHEN 5 THEN 'GOLD' ELSE 'PLATINUM' END");
    var bd = try builds.build(gpa, io, db, &build_data, .{ .patches = &.{patch}, .platforms = &.{"EUW1"}, .min_matchup_games = 0 });
    defer bd.deinit();
    try testing.expectEqual(games, bd.timelines);
    const build_file = try bd.file(arena, &build_data, patch, "PLATINUM", 10);
    try testing.expectEqual(9, build_file.builds.len);
    const darius = build_file.get(122, .top).?;
    try testing.expectEqual(games, darius.games);
    try testing.expectEqual(games, darius.get(.start).?.games);
    try testing.expectEqualSlices(u32, &.{ 4, 6 }, darius.get(.spells).?.options[0].v);
    try testing.expectEqual(games, darius.get(.skill_start).?.games);
    try testing.expectEqual(games, darius.get(.skill_path).?.games);
    try testing.expect(darius.minutes.len > 0);
    const builds_json = try std.json.Stringify.valueAlloc(arena, build_file, .{});
    try tmp.dir.writeFile(io, .{ .sub_path = "builds.json", .data = builds_json });
    const builds_path = try std.fs.path.join(arena, &.{ dir, "builds.json" });
    // The 30-day views' (builds --site): the same games
    var recent_builds = build_file;
    recent_builds.label = "last 30 days";
    try tmp.dir.writeFile(io, .{ .sub_path = "recent-builds.json", .data = try std.json.Stringify.valueAlloc(arena, recent_builds, .{}) });
    const recent_builds_path = try std.fs.path.join(arena, &.{ dir, "recent-builds.json" });
    // The previous patch's: Ahri mid with more games than the current patch's few,
    // so its strips show it; Darius's stay on the current patch
    var prev_builds = build_file;
    prev_builds.label = prev_patch;
    const more = try arena.dupe(builds.File.Build, build_file.builds);
    for (more) |*b| if (b.champion == 103 and b.role == .middle) {
        b.games += 1000;
    };
    prev_builds.builds = more;
    try tmp.dir.writeFile(io, .{ .sub_path = "builds-prev.json", .data = try std.json.Stringify.valueAlloc(arena, prev_builds, .{}) });
    const prev_builds_path = try std.fs.path.join(arena, &.{ dir, "builds-prev.json" });

    // Early or late (`meiolol lean`): every fixture game counts, too few for any line
    var ln = try lean.load(gpa, io, db, &.{patch}, &.{"EUW1"}, 0, std.math.maxInt(i64));
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
        try testing.expect(std.mem.find(u8, example_json, want) != null);
    }
    try testing.expect(std.mem.find(u8, example_json, "EUW1_") == null);
    try db.run("INSERT INTO forgotten SELECT DISTINCT puuid, 0 FROM participants", .{});
    try testing.expectEqual(null, try api.example.buildAll(arena, db, set, .{ .since_ms = 0, .min_games = 1 }));
    try db.exec("DELETE FROM forgotten");

    try fillPrev(arena, db);
    var prev_cv = try curves.build(gpa, io, db, &.{prev_patch}, 0, &.{"EUW1"}, &.{});
    defer prev_cv.builder.deinit();
    try testing.expectEqual(games, prev_cv.summary.games);
    var prev_curves_bytes: std.Io.Writer.Allocating = .init(arena);
    try prev_cv.builder.write(&prev_curves_bytes.writer, prev_patch, 1);
    try tmp.dir.writeFile(io, .{ .sub_path = "curves-prev.bin", .data = prev_curves_bytes.written() });
    const prev_curves_path = try std.fs.path.join(arena, &.{ dir, "curves-prev.bin" });

    const out = try std.fs.path.join(arena, &.{ dir, "site" });
    const opts: site.Options = .{
        .out_dir = out,
        .patches = &.{patch},
        .since_ms = start_ms,
        .all_platforms = &.{"EUW1"},
        .contact = "test@example.com",
        .updated = "1 January 2026",
        // No daily: puzzles need three other options for a slot, more than 10 champions
        .curves = @splat(curves_path),
        .builds = .{ recent_builds_path, builds_path, recent_builds_path, builds_path },
        .prev_patch = prev_patch,
        .curves_prev = .{ null, prev_curves_path, null, prev_curves_path },
        .builds_prev = .{ null, prev_builds_path, null, prev_builds_path },
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
        "build/darius-top.html",
        "all/build/darius-top.html",
    }) |page| {
        const path = try std.fs.path.join(arena, &.{ out, page });
        std.Io.Dir.cwd().access(io, path, .{}) catch |err| {
            std.debug.print("missing {s}\n", .{page});
            return err;
        };
    }
    // The draft helper's model file carries the fitted draft model (fitted.zig)
    {
        const bytes = try std.Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(arena, &.{ out, "data/stats.bin" }), arena, .limited(64 << 20));
        const helper: core.Stats = try .parse(arena, bytes);
        try testing.expect(helper.fitted_bytes != null);
    }
    // Build page: three games, so no bare win rates; the champion page (root view) links
    // into the patch view's
    const pages = [_]struct { []const u8, []const []const u8 }{
        .{ "patch/build/darius-top.html", &.{ "Conqueror", "few games", "Doran&#39;s Shield", "More data needed", "href=\"../../champion/darius.html?period=patch\"" } },
        // Patch day: three games a patch is a patch's first day, too early to tell, in
        // every view, the champion pages per role, and a tab after Matchups
        .{ "patch/patch.html", &.{ "<h1>Patch 15.13: what changed</h1>", "Too early to tell: 0 champion roles" } },
        .{ "all/patch.html", &.{ "<h1>Patch 15.13: what changed</h1>", "across all regions" } },
        // Its region's, whatever the period: the region pick shows every region's
        .{ "champion/darius.html", &.{ "<div data-by-view><div data-view=\"0 1\"><p class=\"since muted\"><span class=\"scope\" data-chip data-region=\"EUW1\" data-period=\"patch:15.13\" data-rank=\"\"", "<span class=\"off\">Patch 15.13 vs 15.12<i>, not the 30 days picked</i></span><span>Plat+</span></span> Patch 15.13 against 15.12: too early to tell, too few games on 15.13 so far. <a href=\"../patch/patch.html\">Patch changes</a>", "<div data-view=\"2 3\" hidden><p class=\"since muted\"><span class=\"scope\" data-chip data-region=\"all\"", "</span> Patch 15.13 against 15.12: too early to tell, too few games on 15.13 so far. <a href=\"../all/patch/patch.html\">Patch changes</a>" } },
        .{ "champions.html", &.{"Matchups</a>\n<a href=\"patch.html\">Patch changes</a>"} },
        .{ "index.html", &.{"New patch: <a href=\"patch/patch.html\">what changed in 15.13 since 15.12</a>."} },
        // Champion table and page: raw win rate on the table's track, every lane opponent
        // as a tile in one grid (few games: shown, faded) with its rate against usual
        // (the opponent's own rate on the row for filters.js), it and the curve's gold at
        // 14 linking to the matchup page from the champion's side
        .{ "champions.html", &.{ "data-sortable", "class=\"ci\"", "own win rates spread around it", "id=\"wr-edge\"", "opacity:", "<p class=\"wr-key\">Win rate colour <span class=\"wrc\" style=\"--c:var(--lo4)\">44.5%</span>", "<p class=\"tl-key\">Sorted by win rate pulled toward the role's average", "<details class=\"tl-knobs\" hidden><summary>Minimums</summary>", "<symbol id=\"ri-top\"", "<td class=\"role\" data-v=\"", "<title>Top</title><use href=\"#ri-top\">", "data-min=\"games\"", "data-min=\"share\" data-for=\"tiers\"", "\" data-share=\"" } },
        .{ "champion/darius.html", &.{ "Lane opponents", "<a class=\"champ box\" href=\"../matchup/top/darius-vs-mordekaiser.html\" title=\"Darius vs Mordekaiser\">", "href=\"../matchup/top/darius-vs-mordekaiser.html\" title=\"Lane curves", "<th data-sort=\"num\" title=\"Lane curve estimate: Darius minus the opponent\">Gold at 14</th>", "Search opponent", "data-name=\"Mordekaiser\" data-q=\"", "<tr class=\"bx thin\" data-id=", "<table class=\"og\"", "data-ka=\"", "usually wins about", "Each tile: win rate, vs usual, gold at 14 min, games", "<small data-rank>", "<p class=\"wr-key\">Matchup win rate colour, on a scale twice as wide as the champions table's: <span class=\"wrc\" style=\"--c:var(--lo4)\">39%</span>" } },
        // Hardest first by the rate shrunk with the role's k; opponents under 1% of the
        // champion's games hidden by default (the Opponents filter's p1). Rank filter from
        // Platinum, the tier the crawl samples
        // Opponent tabs (champion.zig opponentTabs): Lane, vs each other role, Duos by ally
        // role, the latter from the root view whatever the picks
        .{ "champion/darius.html", &.{ "<div class=\"og-tabs\" data-tabset><nav class=\"tabs\" role=\"tablist\" aria-label=\"Opponents and duos\" hidden><button type=\"button\" role=\"tab\" data-tab=\"lane\" aria-selected=\"true\">Lane</button><button type=\"button\" role=\"tab\" data-tab=\"jungle\" aria-selected=\"false\">vs Jungle</button>", "data-tab=\"support\" aria-selected=\"false\">vs Support</button><button type=\"button\" role=\"tab\" data-tab=\"duo\" aria-selected=\"false\">Duos</button></nav>", "<div data-panel=\"jungle\" hidden>", "<table class=\"og\" id=\"opp-top-jungle\"", "<div data-panel=\"duo\" data-tabset hidden>", "data-tab=\"duo-jungle\" aria-selected=\"true\">with Jungle</button>", "<div data-panel=\"duo-mid\" hidden>", "<table class=\"og\" id=\"duo-top-jungle\"", "Jungle duos <span class=\"muted\">", "highest win rate first", "With an ally winning", "Each tile: win rate, vs usual, games" } },
        .{ "champion/darius.html", &.{ "data-sortable data-k=\"", "<a aria-current=\"page\" data-min=\"p1\"", "<a href=\"../champion/darius.html?rank=7\" data-rank=\"7\">Master+</a>", "last 30 days, patch 15.13, Platinum+ games</span>" } },
        .{ "champions.html", &.{"Platinum+ ranked solo/duo games in EUW, last 30 days, patch 15.13."} },
        .{ "index.html", &.{"<a href=\"download.html\">Coming: a champ select helper for Windows</a>"} },
        // Daily Draft: a recent game, read in words (no draft win chance,
        // points or gold amounts); reasons from the list Learn uses; option cards and lane
        // rows that static/daily.js fills
        .{ "daily.html", &.{ "from recent games", "rated as if it were the last", "two standard errors on 200+ games", "<div id=\"options\" class=\"dd-options\"></div>", "<ul id=\"lanes\" class=\"dd-lanes\"></ul>", "<script src=\"reasons.js\" defer></script>", "<p id=\"crowd\" class=\"muted dd-crowd-note\" hidden></p>" } },
        .{ "privacy.html", &.{ "the date\nshown is the puzzle's, not the game's", "we keep only each puzzle's totals", "<h2 id=\"accounts\">Accounts</h2>" } },
        // Learn: lessons and practice as tabs, a lesson a screen with its own nav, practice
        // levels (learn.js draws them)
        .{ "learn.html", &.{ "<section id=\"puzzles\" data-view=\"puzzles\">", "<script type=\"application/json\" id=\"puzzle-data\">[{\"id\":\"know\"", "\"id\":\"luck\"", "<ol class=\"pz-list nojs\">", "<section id=\"practice\" data-view=\"practice\">", "<div class=\"lesson-nav\"></div>", "id=\"p-levels\"", "<article class=\"card lesson\" id=\"lesson-roles\"" } },
        // A search for one champion turns its rows to its side (MU8); gold under a clear
        // lead plain (J11, J12)
        .{ "matchup/index.html", &.{ "(searching one champion shows its side)", "row.toggleAttribute(\"data-f\")", "<span class=\"gold even\"" } },
        .{ "matchup/index.html", &.{ "data-min-search", "<tr class=\"bx thin\" data-games=\"3\" data-name=\"", "<section data-min-group data-r=\"top\" id=\"top\"><h2>Top ", "<nav class=\"tabs mu-roles\" aria-label=\"Role\"><a href=\"#all\">All roles</a><a href=\"#top\">Top</a>", "<table class=\"tl mu-table\" id=\"mu-top\" data-sortable>", "<option selected>50</option>", " vs usual", "</b></span></td><td class=\"opt\" data-v=\"", "<p class=\"wr-key\">" } },
        // Champion page: each view's most played choice per kind, few games so no win
        // rate, then that view's build page; filters.js shows the one its picks select
        .{ "champion/darius.html", &.{ "<div data-by-view><div data-view=\"0\"><div class=\"bstrip\"><p class=\"bhead\"><b>Most played build</b> <span class=\"scope\" data-chip data-region=\"EUW1\" data-period=\"days30\" data-rank=\"\"", "<span>EUW</span><span>30 days</span><span>Plat+</span></span> <span class=\"muted\">last 30 days, in EUW, Platinum IV and up: 3 games.</span> <a href=\"../build/darius-top.html\">", "<div data-view=\"1\" hidden><div class=\"bstrip\"><p class=\"bhead\"><b>Most played build</b> <span class=\"scope\" data-chip data-region=\"EUW1\" data-period=\"patch:15.13\"", "<span class=\"off\">Patch 15.13<i>, not the 30 days picked</i></span><span>Plat+</span></span> <span class=\"muted\">patch 15.13, in EUW, Platinum IV and up: 3 games.</span> <a href=\"../patch/build/darius-top.html\">", "href=\"../all/build/darius-top.html\"", "<div class=\"bk runes thin\"><span>Runes</span>", "<div class=\"rp\"><div class=\"rt\"><img class=\"rh on\" src=\"https://example.com/8000.png\" alt=\"Precision\"", "<img class=\"on\" src=\"https://example.com/8242.png\" alt=\"Unflinching\"", "<div class=\"rt rs\" title=\"Most played stat shards\">", "<span>Levels 1-3</span>", "<span>Skill priority</span>", "players took this\">3 games · 100%</small>" } },
        .{ "patch/build/darius-top.html", &.{ "<th>Levels 1 to 3</th>", "<th>Levels 1 to 18</th>", "<th>Fourth finished item</th>", ">Minute</th>", "<div class=\"rpages\">", "<div class=\"rpc thin\"><span class=\"tags\"><span class=\"tag mp\">most played</span></span><div class=\"rp\">", "<div class=\"rx\">", "<span class=\"rc on\" title=\"Conqueror: 3 games, 100.0%\">", "<span class=\"rc off\" title=\"Adaptive force: 0 games, 0.0%\">", "Most played rune pages first. Share of 3 players.", "the highest win rate among options with 100+ games once each is pulled toward the average by k games" } },
        .{ "champion/darius.html", &.{ "<div data-view=\"0\"><p class=\"muted small\">Players' win rates on Darius: more data needed (0 players in EUW with 10+ games on it, last 30 days; 20 needed).", "<div data-view=\"3\" hidden><p class=\"muted small\">Players' win rates on Darius: more data needed (0 players across all regions with 10+ games on it, patch 15.13; 20 needed).", "<div data-view=\"0 2\"></div><div data-view=\"1 3\" hidden></div>" } },
        .{ "build/darius-top.html", &.{ "ranked solo/duo in EUW, last 30 days, Platinum IV and up. 3 games.", "<title>Darius Top build: runes, items, skill order, last 30 days | meiolol</title>" } },
        .{ "champions.html", &.{"<a href=\"build/index.html\">Builds, last 30 days</a>."} },
        // Filters: the champion's counts by region, rank, patch, role and opponent, its
        // bans and each view's curve gold, the players per role for pick rates, and the
        // bar that sums them, written as the root view. One page per champion: the other
        // views link to it with their filters, and its switches set them
        .{ "data/filters/darius.json", &.{ "\"platforms\":[\"EUW1\"]", "\"rows\":[[", "\"bans\":[", "\"gold\":{\"EUW1|days30|\":[" } },
        .{ "data/filters.json", &.{ "\"roles\":[\"top\"", "\"slots\":[[" } },
        .{ "champion/darius.html", &.{ "data-filters data-src=\"../data/filters/darius.json\"", "data-region=\"EUW1\"", "data-min=\"0\"", "filters.js", "data-id=\"", "data-tile=\"pick\"", "data-early=\"", "href=\"../champion/darius.html?region=all\" data-region=\"all\"" } },
        .{ "all/patch/role/top.html", &.{"href=\"../../../champion/darius.html?region=all&amp;period=patch\""} },
        .{ "all/matchup/top/mordekaiser-vs-darius.html", &.{"href=\"../../../champion/darius.html?region=all\""} },
        // Lane curves: the estimate (curvefit.zig) on the page, k on the method page
        .{ "matchup/top/mordekaiser-vs-darius.html", &.{ "estimated average", "First finished item", "More data needed" } },
        // All on screen as cards: a headline against usual, tiles (vs usual:
        // champion.VsUsual), the gold curve beside head to head bars, XP and CS curves
        // (hover titles per minute), comeback chart, by rank and mastery
        .{ "matchup/top/mordekaiser-vs-darius.html", &.{ "<p class=\"verdict mu-sum\">Mordekaiser wins ", "% against Darius, ", "% in all Top games.", "<small>Mordekaiser, in gold</small>", "<div class=\"tiles mu-tiles\">", "<span>Vs usual</span>", "Mordekaiser usually wins about", "<span>Gold at 14 min</span>", "<section class=\"mu-card mu-gold\"><h2>Gold difference</h2>", "<title>14 min: ", "<section class=\"mu-card mu-h2h thin\"><h2>Head to head</h2>", "<span class=\"h2h-l\">Kill on the other, 0 to 6 min</span>", "<span class=\"h2h-l\">Level 6</span>", "<h2>Experience difference</h2>", "<h2>CS difference</h2>", "<section class=\"mu-card mu-comeback\"><h2>Win rate by gold at 10 min</h2>", "<section class=\"mu-card mu-split\"><h2>By rank and mastery</h2>", "Iron to Silver" } },
        // Either side's page, each swapping to the other
        .{ "matchup/top/mordekaiser-vs-darius.html", &.{ "<h1>Mordekaiser vs Darius</h1>", "class=\"swap\" href=\"darius-vs-mordekaiser.html\"" } },
        // Bot lane partners (MU4): each side's supports, and a support matchup's bot laners
        .{ "matchup/bot/kaisa-vs-twitch.html", &.{ "<section class=\"mu-card mu-duos\"><h2>Supports <span class=\"muted\">in all their Bot games</span></h2>", "<span class=\"sh\">Twitch with</span><span class=\"sh num\">Vs usual</span>", "title=\"Twitch with " } },
        .{ "matchup/support/pyke-vs-rakan.html", &.{ "<h2>Bot laners <span class=\"muted\">in all their Support games</span></h2>", "<span class=\"sh\">Rakan with</span>" } },
        // Opponent strip (MU2): the lane opponents with a page, the current one lit
        .{ "matchup/top/darius-vs-mordekaiser.html", &.{ "<div class=\"mu-opps\"><input type=\"search\"", "<li data-name=\"Mordekaiser\"><a href=\"darius-vs-mordekaiser.html\" aria-current=\"page\" title=\"Darius vs Mordekaiser: Darius wins " } },
        .{ "matchup/top/darius-vs-mordekaiser.html", &.{ "<h1>Darius vs Mordekaiser</h1>", "class=\"swap\" href=\"mordekaiser-vs-darius.html\"", "From Darius's side", "<div class=\"mu-build\"><section class=\"mu-card\"><h2>Most played build <span class=\"scope\" data-chip data-region=\"EUW1\" data-period=\"patch:15.13\"", "<span class=\"off\">Patch 15.13<i>, not the 30 days picked</i></span><span>Plat+</span></span></h2>", "games, patch ", "href=\"../../patch/build/darius-top.html\">Darius's full Top build</a>", "<span>Runes <em class=\"muted\">same as usual</em></span>", "<span>First 2 items" } },
        // Per rune in the matchup: share, win rate and games under each, beside the runes
        // whose share moves (builds.runeShifts)
        .{ "matchup/top/darius-vs-mordekaiser.html", &.{ "<h2>Runes against Mordekaiser <span class=\"scope\" data-chip ", "Every rune picked within 10 points of Darius's other Top games.", "<div class=\"rx\">", "<span class=\"rc on\" title=\"Conqueror: 3 games, 100.0%\">" } },
        .{ "method.html", &.{ "Games to stabilise", "<h2 id=\"lean\">Early or late</h2>" } },
        // Early or late: three games, so no numbers, only that it can't tell yet
        .{ "champion/darius.html", &.{ "<b>Early or late:</b> too few games yet to tell.", "Games still going at 20 min: 3 (every region, last 30 days)", "href=\"../method.html#lean\"" } },
        // A pick the current patch has few games of: the previous patch's build, no link
        // to the thin page (builds.zig pick)
        .{ "champion/ahri.html", &.{"<span class=\"off\">Patch 15.12<i>, not the 30 days picked</i></span><span>Plat+</span></span> <span class=\"muted\">patch 15.12 (15.13: 3 games so far), in EUW"} },
        .{ "learn.html", &.{"From ranked games in EUW on patch 15.13"} },
        // Spread bars, pool and its section follow the view
        .{ "champions.html", &.{"games on it in any role, last 30 days (none under 20"} },
        .{ "patch/champions.html", &.{"games on it in any role, patch 15.13 (none under 20"} },
        .{ "all/pool.html", &.{"players across all regions so far)"} },
        // The pool section's, one per view (the fixture has no mains)
        .{ "champion/darius.html", &.{"<div data-by-view><div data-view=\"0\"></div><div data-view=\"1\" hidden></div><div data-view=\"2\" hidden></div><div data-view=\"3\" hidden></div></div>"} },
        .{ "daily.html", &.{"From ranked solo games in EUW on patch 15.13"} },
        // Scope chips (site/scope.zig): what each block covers, marked where it doesn't
        // follow the page's picks; filters.js marks them again for each pick
        .{ "champion/darius.html", &.{
            "<section id=\"top\"><h2>Top <span class=\"scope\" data-chip data-region=\"*\" data-period=\"*\" data-rank=\"*\" title=\"Region, period and rank these numbers are from\"><span>EUW</span><span>30 days</span><span>Plat+</span></span></h2>",
            "<p class=\"curves-links\"><span class=\"scope\" data-chip data-region=\"all\" data-period=\"days30\" data-rank=\"\" title=\"Region, period and rank these numbers are from\"><span class=\"off\">All regions<i>, not EUW alone</i></span><span>30 days</span><span>Plat+</span></span> <b>Early or late",
            "patch 15.13; 20 needed). <span class=\"scope\" data-chip data-region=\"all\" data-period=\"patch:15.13\" data-rank=\"\"",
        } },
        .{ "patch/matchup/top/darius-vs-mordekaiser.html", &.{ "<h2>Most played build <span class=\"scope\" data-chip data-region=\"EUW1\" data-period=\"patch:15.13\" data-rank=\"\" title=\"Region, period and rank these numbers are from\"><span>EUW</span><span>Patch 15.13</span><span>Plat+</span></span></h2>", "<p class=\"muted\"><span class=\"scope\" data-chip data-region=\"EUW1\" data-period=\"patch:15.13\"" } },
        // The fixture's every-region 30-day view has only a patch's curves
        .{ "all/matchup/top/darius-vs-mordekaiser.html", &.{"<p class=\"muted\"><span class=\"scope\" data-chip data-region=\"all\" data-period=\"patch:15.13\" data-rank=\"\" title=\"Region, period and rank these numbers are from\"><span>All regions</span><span class=\"off\">Patch 15.13<i>, not the 30 days picked</i></span><span>Plat+</span></span> From Darius"} },
        .{ "patch/build/darius-top.html", &.{"<p class=\"muted\"><span class=\"scope\" data-chip data-region=\"EUW1\" data-period=\"patch:15.13\" data-rank=\"\" title=\"Region, period and rank these numbers are from\"><span>EUW</span><span>Patch 15.13</span><span>Plat+</span></span> What players take"} },
        .{ "pool.html", &.{ "<p class=\"muted\"><span class=\"scope\" data-chip data-region=\"EUW1\" data-period=\"every\"", "<h2 id=\"pick-up\">How hard champions are to pick up <span class=\"scope\" data-chip data-region=\"all\" data-period=\"days30\"", "<span class=\"off\">All regions<i>, not EUW alone</i></span>" } },
        .{ "all/patch/pool.html", &.{"<h2 id=\"pick-up\">How hard champions are to pick up <span class=\"scope\" data-chip data-region=\"all\" data-period=\"patch:15.13\" data-rank=\"\" title=\"Region, period and rank these numbers are from\"><span>All regions</span><span>Patch 15.13</span><span>Plat+</span></span></h2>"} },
    };
    for (pages) |pg| {
        const path = try std.fs.path.join(arena, &.{ out, pg[0] });
        const html = try std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 20));
        for (pg[1]) |want| if (std.mem.find(u8, html, want) == null) {
            std.debug.print("{s} lacks {s}\n", .{ pg[0], want });
            return error.TestUnexpectedResult;
        };
    }
    // Every block on a champion page says its scope: each role section, and each
    // variant written per view that has anything in it
    for ([_][]const u8{ "champion/darius.html", "champion/ahri.html" }) |page| {
        const path = try std.fs.path.join(arena, &.{ out, page });
        const html = try std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 20));
        var sections = std.mem.splitSequence(u8, html, "<section id=\"");
        _ = sections.next();
        while (sections.next()) |rest| {
            const h2 = rest[0 .. std.mem.indexOf(u8, rest, "</h2>") orelse rest.len];
            if (std.mem.indexOf(u8, h2, "data-chip") == null) {
                std.debug.print("{s}: section without a scope chip: {s}\n", .{ page, h2 });
                return error.TestUnexpectedResult;
            }
        }
        var variants = std.mem.splitSequence(u8, html, "<div data-view=\"");
        _ = variants.next();
        var blocks: usize = 0;
        while (variants.next()) |rest| {
            const body = rest[std.mem.indexOfScalar(u8, rest, '>').? + 1 ..];
            if (std.mem.startsWith(u8, body, "</div>")) continue;
            blocks += 1;
            const end = std.mem.indexOf(u8, body, "</div></div>\n") orelse body.len;
            if (std.mem.indexOf(u8, body[0..end], "data-chip") == null) {
                std.debug.print("{s}: block without a scope chip: {s}\n", .{ page, body[0..@min(body.len, 200)] });
                return error.TestUnexpectedResult;
            }
        }
        try testing.expect(blocks >= 8);
    }
    // Data is Platinum+ (the crawl's floor): no lower tier to filter by, no "all ranks"
    for ([_][]const u8{ "champions.html", "champion/darius.html" }) |page| {
        const path = try std.fs.path.join(arena, &.{ out, page });
        const html = try std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 20));
        for ([_][]const u8{ "all ranks", "All ranks", ">Gold+" }) |bad| if (std.mem.find(u8, html, bad) != null) {
            std.debug.print("{s} has {s}\n", .{ page, bad });
            return error.TestUnexpectedResult;
        };
    }
    // Three games: greyed out, so the headline has no lane part (matchup.lead) and nothing
    // is folded away
    {
        const path = try std.fs.path.join(arena, &.{ out, "matchup/top/mordekaiser-vs-darius.html" });
        const html = try std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 20));
        try testing.expect(std.mem.find(u8, html, "whoever is ahead wins") == null);
        const pickers = std.mem.count(u8, html, "<details class=\"pick\">") + std.mem.count(u8, html, "<details class=\"regions\">");
        try testing.expectEqual(pickers, std.mem.count(u8, html, "<details"));
    }
    // table.js finds each search's, minimum's and rare button's table by id: every target on
    // the page
    for ([_][]const u8{ "champions.html", "role/top.html", "champion/darius.html" }) |page| {
        const path = try std.fs.path.join(arena, &.{ out, page });
        const html = try std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 20));
        var found: usize = 0;
        for ([_][]const u8{ "data-filter=\"", "data-show-rare=\"", "data-for=\"", "data-no-min=\"", "data-rare-count=\"" }) |attr| {
            var it = std.mem.splitSequence(u8, html, attr);
            _ = it.next();
            while (it.next()) |rest| {
                const id = rest[0..std.mem.findScalar(u8, rest, '"').?];
                const want = try arena.print("id=\"{s}\"", .{id});
                if (std.mem.find(u8, html, want) == null) {
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
        if (std.mem.endsWith(u8, e.path, ".html") and std.mem.find(u8, want, "data-sortable") != null and
            std.mem.find(u8, want, "table.js\"") == null)
        {
            std.debug.print("{s}: sortable table without table.js\n", .{e.path});
            return error.TestUnexpectedResult;
        }
    }
    try testing.expect(checked > 50);
    // The account pages (site/account.zig): rendered on request only, never indexed
    for ([_][]const u8{ "login.html", "signup.html", "join.html", "account.html" }) |p| {
        const page = try loaded.get(arena, p) orelse return error.TestUnexpectedResult;
        try testing.expect(std.mem.find(u8, page, "<meta name=\"robots\" content=\"noindex\">") != null);
        try testing.expect(std.mem.find(u8, page, "<form id=\"auth\" class=\"auth-form\" data-kind=\"") != null);
        try testing.expect(std.mem.find(u8, page, "<script src=\"account.js\" defer></script>") != null);
    }
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
                const sql = try arena.printSentinel("VACUUM {s} INTO '{s}/{s}'", .{ schema, files, name }, 0);
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
        try testing.expect(std.mem.find(u8, sitemap, want) != null);
    }
    const patch_sitemap = (try core_loaded.get(arena, "patch/sitemap.xml")).?;
    try testing.expect(std.mem.find(u8, patch_sitemap, "https://x.io/patch/build/darius-top.html") != null);
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

    // A day before now_s, one draft row fewer: the newest is stored in the last 24 h
    try tmp.dir.writeFile(io, .{ .sub_path = "admin-history.tsv", .data = "time\tmeiolol_db\ttimeline_db\traw_db\tdisk_used" ++
        "\tdisk_size\tplayers\tranks\tmatches\ttimelines\tdrafts\tmatch_queue\ttimeline_queue\tmastery\tmeiolol_wal\ttimeline_wal\traw_wal\n" ++
        "1760137700\t\t\t\t\t\t\t\t\t\t2\t\t\t\t\t\t\n" });
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
        "\"recent\":[0,0,1,0]}]",
    }) |want| if (std.mem.find(u8, html, want) == null) {
        std.debug.print("admin page lacks {s}\n", .{want});
        return error.TestUnexpectedResult;
    };
    try std.testing.expect(std.mem.find(u8, html, "EUW1_7123456") == null);
    // The private site's Draft tester: the page in private mode, none of the box's data
    const private = try std.fs.path.join(arena, &.{ dir, "p" });
    try admin.private(gpa, io, private, 1760224200);
    const p_html = try std.Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(arena, &.{ private, "index.html" }), arena, .limited(1 << 20));
    try std.testing.expect(std.mem.find(u8, p_html, "<script id=\"data\" type=\"application/json\">{\"private\":true,\"now\":1760224200}</script>") != null);
    for ([_][]const u8{ "admin.js", "admin-draft.js", "admin-setnet.js", "admin.css" }) |f| {
        try std.Io.Dir.cwd().access(io, try std.fs.path.join(arena, &.{ private, f }), .{});
    }
    try std.testing.expectError(error.FileNotFound, std.Io.Dir.cwd().access(io, try std.fs.path.join(arena, &.{ private, "data.json" }), .{}));
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
    }) |want| if (std.mem.find(u8, json, want) == null) {
        std.debug.print("data.json lacks {s}\n", .{want});
        return error.TestUnexpectedResult;
    };
    try std.testing.expect(std.mem.find(u8, html, json) != null);
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
    }) |want| if (std.mem.find(u8, live, want) == null) {
        std.debug.print("live.json lacks {s}\n{s}\n", .{ want, live });
        return error.TestUnexpectedResult;
    };
    for ([_][]const u8{ "admin.js", "admin.css", "index.html.gz", "data.json.gz" }) |f| {
        try std.Io.Dir.cwd().access(io, try std.fs.path.join(arena, &.{ out, f }), .{});
    }
    // One history line per build, under one header
    const history = try std.Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(arena, &.{ dir, "admin-history.tsv" }), arena, .limited(1 << 20));
    try testing.expectEqual(4, std.mem.count(u8, history, "\n"));
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
        meta: struct { training_games: usize, patch: []const u8, patch_games: u32, oldest_patch: []const u8, newest_patch: []const u8 },
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
    try testing.expectEqualStrings("15.13", m.meta.newest_patch);
    try testing.expectEqual(150, m.meta.patch_games);
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
        meta: struct { training_games: usize, newest_patch: []const u8, dev: []const struct { outcome: []const u8 } },
        outcomes: []const []const u8,
        champ: []const struct { champion: u32, n: u32, b: [4]f64 },
        pairs: []const [12]f64,
    };
    const lane_text = try tmp.dir.readFileAlloc(io, "tester/lane-model.json", arena, .limited(16 << 20));
    const lane = try std.json.parseFromSliceLeaky(Lane, arena, lane_text, .{ .ignore_unknown_fields = true });
    try testing.expectEqualStrings("meiolol-lane-model", lane.format);
    try testing.expectEqual(150, lane.meta.training_games);
    try testing.expectEqualStrings("15.13", lane.meta.newest_patch);
    try testing.expectEqual(4, lane.meta.dev.len);
    try testing.expectEqualStrings("lanediff14", lane.outcomes[1]);
    // Both sides' laners in every role; rows only from the two thirds of games whose
    // timeline reached 15:00 (fillGames leaves every third without one)
    try testing.expectEqual(10, lane.champ.len);
    try testing.expectEqual(10, lane.pairs.len);
    for (lane.champ) |t| try testing.expectEqual(100, t.n);
    _ = try tmp.dir.readFileAlloc(io, "tester/lane-ref.json", arena, .limited(1 << 20));
}

test "curves, lean, lane-model and builds: the same files with digests, without, old ones" {
    const gpa = testing.allocator;
    const io = testing.io;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const db = try store.schema.memory();
    defer db.close();
    try fillGames(arena, db, 150, true);
    try db.exec("UPDATE participants SET tier = 'PLATINUM'");

    const want = try timelineOutputs(arena, io, db, tmp, "none");
    try testing.expectEqual(0, try db.scalar("SELECT count(*) FROM timeline.digests", .{}));
    const s = try digests.catchUp(gpa, io, db, .{});
    try testing.expectEqual(100, s.made);
    const with = try timelineOutputs(arena, io, db, tmp, "all");
    // Every other one another version: those games' readers take the full timeline
    try db.exec("UPDATE timeline.digests SET data = x'00' || substr(data, 2) WHERE source % 2 = 0");
    const mixed = try timelineOutputs(arena, io, db, tmp, "mixed");
    // From files, as on the box: their reads ahead (store.Ahead) take sibling connections
    const dir = try std.fs.path.join(arena, &.{ ".zig-cache", "tmp", &tmp.sub_path, "db" });
    try std.Io.Dir.cwd().createDirPath(io, dir);
    for ([_][]const u8{ "main", "raw", "timeline" }, [_][]const u8{ "meiolol", "raw", "timeline" }) |name, file| {
        try db.run(try arena.print("VACUUM {s} INTO ?", .{name}), .{try arena.print("{s}/{s}.db", .{ dir, file })});
    }
    const files = try store.schema.openReadOnly(gpa, dir);
    defer files.close();
    const ahead = try timelineOutputs(arena, io, files, tmp, "files");
    for (want, with, mixed, ahead) |a, b, c, d| {
        try testing.expect(a.len > 0);
        try testing.expectEqualStrings(a, b);
        try testing.expectEqualStrings(a, c);
        try testing.expectEqualStrings(a, d);
    }
}

/// curves.bin, builds.json, lean.tsv and the lane model's two files
fn timelineOutputs(arena: std.mem.Allocator, io: std.Io, db: store.Db, tmp: std.testing.TmpDir, tag: []const u8) ![5][]const u8 {
    const gpa = testing.allocator;
    const both: []const []const u8 = &.{ "EUW1", "NA1" };
    var out: [5][]const u8 = undefined;

    var cv = try curves.build(gpa, io, db, &.{patch}, 0, both, &.{});
    defer cv.builder.deinit();
    var curves_bytes: std.Io.Writer.Allocating = .init(arena);
    try cv.builder.write(&curves_bytes.writer, patch, 1);
    out[0] = curves_bytes.written();

    var bd = try builds.build(gpa, io, db, &build_data, .{ .patches = &.{patch}, .platforms = both });
    defer bd.deinit();
    out[1] = try std.json.Stringify.valueAlloc(arena, try bd.file(arena, &build_data, patch, "PLATINUM", 10), .{});

    var ln = try lean.load(gpa, io, db, &.{patch}, both, 0, std.math.maxInt(i64));
    defer ln.deinit(gpa);
    const lf = try lean.fit(gpa, ln.list.items, ln.champs.ids.items.len);
    defer lf.deinit(gpa);
    var lean_bytes: std.Io.Writer.Allocating = .init(arena);
    try lean.write(&lean_bytes.writer, &lf, ln.champs.ids.items, ln.list.items, "every region");
    out[2] = lean_bytes.written();

    const dir = try std.fs.path.join(arena, &.{ ".zig-cache", "tmp", &tmp.sub_path, tag });
    var log: std.Io.Writer.Allocating = .init(arena);
    try lanemodel.run(gpa, io, db, dir, &log.writer);
    const model = try tmp.dir.readFileAlloc(io, try arena.print("{s}/lane-model.json", .{tag}), arena, .limited(16 << 20));
    // Its run time to the minute: two runs either side of one differ there only
    const run = std.mem.find(u8, model, "\"run\":\"").? + 7;
    @memset(model[run..][0.."2026-10-19 08:02Z".len], '-');
    out[3] = model;
    out[4] = try tmp.dir.readFileAlloc(io, try arena.print("{s}/lane-ref.json", .{tag}), arena, .limited(1 << 20));
    return out;
}

test "fixture games to builds: EUW and every region, patch and recent, from one pass" {
    const gpa = testing.allocator;
    const io = testing.io;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const db = try store.schema.memory();
    defer db.close();
    // Every 4th game NA1, every 3rd without a timeline
    try fillGames(arena, db, 40, true);
    const both: []const []const u8 = &.{ "EUW1", "NA1" };
    const o: builds.Options = .{ .patches = &.{patch}, .platforms = both, .min_tier = null };
    // An hour apart: the third set (a 30-day view's) from game 20, any patch
    var each: [3]builds.Builder = undefined;
    try builds.buildEach(gpa, io, db, &build_data, o, &.{
        .{ .slice = .{ .platforms = &.{"EUW1"}, .patches = &.{patch} } },
        .{ .slice = .{ .platforms = both, .patches = &.{patch} } },
        .{ .slice = .{ .platforms = both, .since_ms = start_ms + 20 * std.time.ms_per_hour }, .matchups = false },
    }, &each);
    defer for (&each) |*b| b.deinit();
    try testing.expectEqual(30, each[0].games);
    try testing.expectEqual(40, each[1].games);
    try testing.expectEqual(27, each[1].timelines);
    try testing.expectEqual(20, each[2].games);
    for (each[0..2], [_][]const []const u8{ &.{"EUW1"}, both }) |b, platforms| {
        var alone = try builds.build(gpa, io, db, &build_data, .{ .patches = &.{patch}, .platforms = platforms, .min_tier = null });
        defer alone.deinit();
        try testing.expectEqual(alone.games, b.games);
        try testing.expectEqual(alone.timelines, b.timelines);
        const a = try std.json.Stringify.valueAlloc(arena, try alone.file(arena, &build_data, patch, "", 10), .{});
        const e = try std.json.Stringify.valueAlloc(arena, try b.file(arena, &build_data, patch, "", 10), .{});
        try testing.expectEqualStrings(a, e);
    }
    // `site --patch-games`, which the web loop decides on
    try testing.expectEqual(30, try stats.countGames(db, &.{patch}, &.{"EUW1"}));
    try testing.expectEqual(0, try stats.countGames(db, &.{"15.12"}, &.{"EUW1"}));
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
        const at = std.mem.find(u8, manifest, line).?;
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
            if (std.mem.find(u8, other, line) == null) std.debug.print("site file {s}: {s}\n", .{ label, line });
        }
    }
    const new_path = ".zig-cache/site-files.txt";
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = new_path, .data = got });
    std.debug.print("site output changed; if on purpose, deploy/commit.sh rewrites src/testdata/site-files.txt (or cp {s})\n", .{new_path});
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
            const n = try std.fmt.parseInt(usize, g.match_id[std.mem.findScalar(u8, g.match_id, '_').? + 1 ..], 10);
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

test "views partials: the database's views file, after late, replaced, timelined, forgotten and gone games" {
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
    try fillGames(arena, db, 14, true);
    try fillPrev(arena, db);
    try fillFlex(arena, db);
    // Learn's damage split from 10 games or more: every champion's damage type known, so
    // its team mixes count. Again after the forget, which deletes the player's
    const raw_body = store.Blob{ .bytes = try store.raw.compress(arena, @embedFile("riot/testdata/match.json")) };
    const raw_docs = "INSERT OR IGNORE INTO raw.raw_docs SELECT 'riot_match', match_id, 0, ? FROM matches";
    try db.run(raw_docs, .{raw_body});
    // Out of learn's games
    try db.exec("UPDATE matches SET winning_team = NULL WHERE match_id = 'EUW1_6'");
    try db.exec("UPDATE participants SET tier = CASE slot % 3 WHEN 0 THEN 'GOLD' WHEN 1 THEN 'DIAMOND' END");
    _ = try riot.crawl.rebuildGold(gpa, db);
    try db.exec("INSERT INTO players (puuid, source, region, matches_checked_at) SELECT DISTINCT puuid, 'ladder', 'europe', 1 FROM participants WHERE puuid IS NOT NULL");
    const now_s = @divFloor(start_ms, 1000) + 3600;
    const puuids = try readStrings(arena, db, "SELECT DISTINCT puuid FROM participants WHERE puuid IS NOT NULL ORDER BY puuid");
    try testing.expectEqual(10, puuids.len);
    for (puuids, 0..) |p, i| try putMastery(arena, db, p, if (i % 4 == 3) "NA1" else "EUW1", now_s, i);

    const opts: site.Options = .{
        .out_dir = try std.fs.path.join(arena, &.{ dir, "site" }),
        .patches = &.{patch},
        .since_ms = start_ms,
        .all_platforms = &.{ "EUW1", "NA1" },
        .contact = "test@example.com",
        .updated = "1 January 2026",
        .prev_patch = prev_patch,
    };
    const pdir = try std.fs.path.join(arena, &.{ dir, "partials" });
    const views_path = try std.fs.path.join(arena, &.{ dir, "views.bin" });
    const before = try viewsFile(arena, io, db, opts, null, views_path, null);
    try testing.expectEqualSlices(u8, before, try viewsFile(arena, io, db, opts, pdir, views_path, null));

    // The first build of a big store reads whole tables: the same games
    {
        const bulk_dir = try std.fs.path.join(arena, &.{ dir, "bulk" });
        const now_ms = std.Io.Clock.real.now(io).toMilliseconds();
        const bulk = try partials.Store.open(gpa, io, db, bulk_dir, .{ .now_ms = now_ms, .bulk_after = 0 });
        defer bulk.deinit();
        try testing.expect(bulk.counts.bulk);
        const each = try partials.Store.open(gpa, io, db, pdir, .{ .now_ms = now_ms });
        defer each.deinit();
        try testing.expectEqual(0, each.counts.read);
        var a: std.Io.Writer.Allocating = .init(arena);
        try partials.dump(bulk, &a.writer);
        var b: std.Io.Writer.Allocating = .init(arena);
        try partials.dump(each, &b.writer);
        try testing.expectEqualStrings(a.written(), b.written());
        // Flex copies listed as others
        try testing.expectEqual(14 + games, bulk.counts.games);
    }

    // `meiolol forget`: the player's key out of every file at once, and gone for good
    const gone = puuids[3];
    try testing.expect(try partials.mentions(gpa, io, pdir, gone) > 1);
    _ = try forget.forget(db, gone, now_s, .record);
    try testing.expect(try partials.forget(gpa, io, pdir, &.{gone}) > 1);
    try testing.expectEqual(0, try partials.mentions(gpa, io, pdir, gone));

    // A late game on an old day, a re-stored (REPLACE) one, a timeline arriving, a game
    // pruned and a mastery row fetched again: those read, the rest kept
    {
        const body = @embedFile("riot/testdata/match.json");
        var doc = try riot.match.parse(arena, body);
        doc.metadata.matchId = "EUW1_100";
        doc.info.platformId = "EUW1";
        doc.info.gameVersion = patch ++ ".1.1";
        doc.info.gameStartTimestamp = start_ms - 3 * std.time.ms_per_day;
        try riot.match.storeRows(db, doc, "riot");
    }
    // As the crawler stores a forgotten player's game
    try db.run("UPDATE participants SET puuid = NULL WHERE match_id = 'EUW1_100' AND puuid = ?", .{gone});
    try db.exec(
        \\INSERT OR REPLACE INTO matches SELECT match_id, source, platform, queue_id, patch,
        \\  game_version, game_start, duration_s, 300 - winning_team, remake
        \\FROM matches WHERE match_id = 'EUW1_2';
        \\UPDATE participants SET win = 1 - win WHERE match_id = 'EUW1_2';
        \\INSERT INTO timeline.timelines SELECT 'EUW1_3', frames, events, data FROM timeline.timelines WHERE match_id = 'EUW1_1';
        \\UPDATE participants SET gold14 = 5000 + 37 * slot, gold15 = 5600 WHERE match_id = 'EUW1_3';
        \\DELETE FROM participants WHERE match_id = 'EUW1_5';
        \\DELETE FROM bans WHERE match_id = 'EUW1_5';
        \\DELETE FROM matches WHERE match_id = 'EUW1_5';
    );
    try putMastery(arena, db, puuids[0], "EUW1", now_s, 7);
    try db.run(raw_docs, .{raw_body});
    var counts: partials.Counts = .{};
    const after = try viewsFile(arena, io, db, opts, null, views_path, null);
    try testing.expect(!std.mem.eql(u8, before, after));
    try testing.expectEqualSlices(u8, after, try viewsFile(arena, io, db, opts, pdir, views_path, &counts));
    try testing.expectEqual(3, counts.read);
    try testing.expectEqual(1, counts.dropped);
    try testing.expectEqual(9, counts.mastery);
    try testing.expectEqual(1, counts.mastery_read);
    try testing.expectEqual(0, try partials.mentions(gpa, io, pdir, gone));
}

/// `site --views` from db (from the partials in `partials_dir` when given), its bytes
fn viewsFile(arena: std.mem.Allocator, io: std.Io, db: store.Db, opts: site.Options, partials_dir: ?[]const u8, path: []const u8, counts: ?*partials.Counts) ![]const u8 {
    const loaded = try site.Loaded.init(testing.allocator, io, db, opts);
    defer loaded.deinit();
    loaded.extras.partials_dir = partials_dir;
    for (site.html.View.all) |v| try loaded.loadView(v);
    if (counts) |c| c.* = loaded.extras.games.?.counts;
    try loaded.writeViews(path);
    return std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 30));
}

fn readStrings(arena: std.mem.Allocator, db: store.Db, sql: []const u8) ![]const []const u8 {
    var q = try db.prepare(sql);
    defer q.deinit();
    try q.bind(.{});
    var out: std.ArrayList([]const u8) = .empty;
    while (try q.step()) try out.append(arena, try arena.dupe(u8, q.bytes(0)));
    return out.items;
}

/// A mastery row over the fixture champions, points varied by `seed`
fn putMastery(arena: std.mem.Allocator, db: store.Db, puuid: []const u8, platform: []const u8, now_s: i64, seed: usize) !void {
    var entries: [fixture_champions.len]riot.mastery.Entry = undefined;
    for (&entries, fixture_champions) |*e, c| e.* = .{
        .champion = c.id,
        .level = 5,
        .points = @intCast((c.id * 7919 + seed * 104_729) % 90_000 + 1000),
        .last_play = now_s - @as(i64, @intCast((c.id + seed) % 3)) * 200 * std.time.s_per_day,
    };
    std.mem.sort(riot.mastery.Entry, &entries, {}, struct {
        fn f(_: void, a: riot.mastery.Entry, b: riot.mastery.Entry) bool {
            return a.champion < b.champion;
        }
    }.f);
    const blob = try riot.mastery.encode(arena, &entries, now_s);
    try db.run("INSERT OR REPLACE INTO mastery VALUES (?,?,?,?,?)", .{ puuid, platform, now_s, entries.len, store.Blob{ .bytes = blob } });
}

/// Data Dragon's classes for the fixture timeline's purchases (16.20): its finished
/// items and boots; Darius's runes and spells for names
const build_data: ddragon.BuildData = .{
    .version = "16.20.1",
    .legendary = &.{ 2510, 2520, 3071, 3073, 3087, 3094, 3118, 3124, 3179, 3302, 3508, 3814, 4633, 4645, 4646, 6653, 6665, 6672, 6676, 6698, 6699 },
    .trinkets = &.{ 3340, 3363, 3364 },
    .boots = &.{ .{ 3006, 3006 }, .{ 3008, 3008 }, .{ 3009, 3009 }, .{ 3020, 3020 }, .{ 3047, 3047 }, .{ 3111, 3111 } },
    .items = &.{.{ .id = 1054, .name = "Doran's Shield", .icon = "https://example.com/1054.png" }},
    .runes = &.{
        .{ .id = 8000, .name = "Precision", .icon = "https://example.com/8000.png" },
        .{ .id = 8010, .name = "Conqueror", .icon = "https://example.com/8010.png" },
        .{ .id = 8242, .name = "Unflinching", .icon = "https://example.com/8242.png" },
        .{ .id = 8400, .name = "Resolve", .icon = "https://example.com/8400.png" },
    },
    .spells = &.{ .{ .id = 4, .name = "Flash" }, .{ .id = 6, .name = "Ghost" } },
    .trees = &.{
        .{ .id = 8000, .slots = &.{ &.{ 8005, 8008, 8021, 8010 }, &.{ 9101, 9111, 8009 }, &.{ 9104, 9105, 9103 }, &.{ 8014, 8017, 8299 } } },
        .{ .id = 8400, .slots = &.{ &.{ 8437, 8439, 8465 }, &.{ 8446, 8463, 8401 }, &.{ 8429, 8444, 8473 }, &.{ 8451, 8453, 8242 } } },
    },
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
    var doc = try riot.match.parse(arena, body);
    const duration = doc.info.gameDuration;
    for (0..n_games) |n| {
        const platform = if (varied and n % 4 == 3) "NA1" else "EUW1";
        doc.metadata.matchId = try arena.print("{s}_{d}", .{ platform, n + 1 });
        doc.info.platformId = platform;
        doc.info.gameVersion = patch ++ ".1.1";
        doc.info.gameStartTimestamp = if (varied) start_ms + @as(i64, @intCast(n)) * 3_600_000 else start_ms;
        doc.info.gameDuration = if (varied) duration - @as(i64, @intCast(n % 7)) * 60 else duration;
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

/// The fixture game `games` times on prev_patch, a day before start_ms
fn fillPrev(arena: std.mem.Allocator, db: store.Db) !void {
    const body = @embedFile("riot/testdata/match.json");
    const json = try store.raw.decompress(arena, @embedFile("riot/testdata/timeline.json.gz"));
    const ct = try riot.crawl.compactTimeline(arena, json);
    for (0..games) |n| {
        var doc = try riot.match.parse(arena, body);
        doc.metadata.matchId = try arena.print("EUW1_{d}", .{2000 + n});
        doc.info.platformId = "EUW1";
        doc.info.gameVersion = prev_patch ++ ".1.1";
        doc.info.gameStartTimestamp = start_ms - std.time.ms_per_day;
        try riot.match.storeRows(db, doc, "riot");
        try db.run("INSERT INTO timeline.timelines VALUES (?,?,?,?)", .{
            doc.metadata.matchId, ct.frames, ct.events, store.Blob{ .bytes = ct.blob },
        });
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
