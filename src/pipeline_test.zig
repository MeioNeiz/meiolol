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
const buildblock = @import("site/buildblock.zig");
const lean = @import("lean.zig");
const draftmodel = @import("draftmodel.zig");
const lanemodel = @import("lanemodel.zig");
const testerbin = @import("testerbin.zig");
const digests = @import("digests.zig");
const ddragon = @import("ddragon.zig");
const site = @import("site/root.zig");
const csp = @import("site/csp.zig");
const assets = @import("site/assets.zig");
const admin = @import("admin.zig");
const site_tester = @import("site/tester.zig");
const site_admin = @import("site/adminpage.zig");
const site_champion = @import("site/champion.zig");
const api = @import("api/root.zig");
const lab_rows = @import("lab/rows.zig");
const lab_pack = @import("lab/pack.zig");
const lab_seatstats = @import("lab/seatstats.zig");
const lab_events = @import("lab/events.zig");
const objectives = @import("objectives.zig");
const partials = @import("partials.zig");
const cubes = @import("cubes.zig");
const patchday = @import("patchday.zig");
const flat = @import("site/flat.zig");
const forget = @import("forget.zig");
const ui = @import("ui");

const testing = std.testing;
const games = 3;
const patch = "15.13";
/// Fixed game start; the 30-day views start there
const start_ms = 1_752_000_000_000;
/// The patch before, its games a day earlier: in the patch day only (/patch)
const prev_patch = "15.12";
/// Two days earlier: prev_patch against it is the older pair's page
/// (/patch/15-12)
const older_patch = "15.11";

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
    // One ban of a played champion, for champ-facts' ban line: Darius for Dr. Mundo
    try db.exec("UPDATE bans SET champion_id = 122 WHERE match_id = 'EUW1_1' AND pick_turn = 1");
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

    var cv = try curvesOne(try cubeDir(arena, dir, "curves"), db, .{ .chosen = &.{patch}, .since_ms = 0, .platforms = &.{"EUW1"} });
    defer cv.builder.deinit();
    try testing.expectEqual(games, cv.summary.games);
    const curves_path = try std.fs.path.join(arena, &.{ dir, "curves.bin" });
    var curves_bytes: std.Io.Writer.Allocating = .init(arena);
    try cv.builder.write(&curves_bytes.writer, patch, 1);
    try tmp.dir.writeFile(io, .{ .sub_path = "curves.bin", .data = curves_bytes.written() });

    // Builds count Platinum IV and up only: one rank snapshot below it is left out
    try db.exec("UPDATE participants SET tier = CASE slot WHEN 5 THEN 'GOLD' ELSE 'PLATINUM' END");
    // Darius 1,000 gold ahead of every lane opponent at 14 minutes
    try db.exec("CREATE TEMP TABLE gold AS SELECT match_id, slot, gold14 FROM participants");
    try db.exec("UPDATE participants SET gold14 = CASE champion_id WHEN 122 THEN 6000 ELSE 5000 END");
    var bd = try buildsOne(try cubeDir(arena, dir, "builds"), db, .{ .min_matchup_games = 0, .min_split_games = 1 }, .{ .slice = .{ .platforms = &.{"EUW1"}, .patches = &.{patch} } });
    defer bd.deinit();
    try testing.expectEqual(games, bd.timelines);
    try db.exec(
        \\UPDATE participants SET gold14 = g.gold14 FROM temp.gold g
        \\  WHERE g.match_id = participants.match_id AND g.slot = participants.slot
    );
    const build_file = try bd.file(arena, &build_data, patch, "PLATINUM", 10);
    try testing.expectEqual(9, build_file.builds.len);
    const darius = build_file.get(122, .top).?;
    try testing.expectEqual(games, darius.games);
    // The rank filter (filters.zig rankFigures): Darius's players at Diamond from here
    try db.exec("UPDATE participants SET tier = 'DIAMOND' WHERE champion_id = 122");
    try testing.expectEqual(games, darius.get(.start).?.games);
    try testing.expectEqualSlices(u32, &.{ 4, 6 }, darius.get(.spells).?.options[0].v);
    try testing.expectEqual(games, darius.get(.skill_start).?.games);
    try testing.expectEqual(games, darius.get(.skill_path).?.games);
    try testing.expect(darius.minutes.len > 0);
    // First item timing: every game's first finished item counted, in the champion page's
    // buckets with the threshold at one game
    var first_item: u32 = 0;
    for (darius.first_item) |x| first_item += x.games;
    try testing.expectEqual(games, first_item);
    var timed: u32 = 0;
    for (try site_champion.timingOf(arena, darius.first_item, 1)) |x| timed += x.games;
    try testing.expectEqual(games, timed);
    // Objectives taken first come through the day cubes: every game, some taken
    try testing.expectEqual(1 + builds.firsts_len, darius.firsts.len);
    try testing.expectEqual(games, darius.firsts[0].games);
    var took: u32 = 0;
    for (darius.firsts[1..]) |x| took += x.games;
    try testing.expect(took > 0);
    // The champion page's build block: the file as BuildPanel's data, drawn
    const block = try buildblock.data(arena, &build_file, darius, "Darius");
    try testing.expectEqual(.spells, block.slots[0].kind);
    try testing.expectEqualStrings("Flash Ghost", block.slots[0].options[0].name);
    for (block.slots) |s| if (s.kind == .skill_path) try testing.expectEqual(18, s.options[0].keys.len);
    try testing.expectEqual(games, block.runes.games);
    // Precision first by keystone players (Conqueror), Resolve the secondary
    try testing.expectEqual(2, block.runes.trees.len);
    try testing.expectEqualStrings("Precision", block.runes.trees[0].art.name);
    try testing.expectEqual(games, block.runes.trees[0].rows[0][3].games);
    try testing.expectEqualStrings("Conqueror", block.runes.pages[0].keystone.name);
    try testing.expectEqualStrings("Resolve", block.runes.pages[0].second.name);
    try testing.expectEqual(3, block.runes.shards.len);
    // Against Mordekaiser, melee, every game; none against a ranged opponent
    try testing.expectEqual(2, block.reach.len);
    try testing.expectEqual(games, block.reach[0].games);
    try testing.expectEqualStrings("Conqueror", block.reach[0].pages[0].keystone.name);
    try testing.expectEqual(0, block.reach[1].games);
    try testing.expectEqual(2, block.lead.len);
    try testing.expectEqual(games, block.lead[0].games);
    try testing.expectEqual(0, block.lead[1].games);
    // Every game ahead: the same item rows as all games
    for (block.slots) |all| if (all.kind == .core) for (block.lead[0].slots) |s| if (s.kind == .core) {
        try testing.expectEqual(all.games, s.games);
        try testing.expectEqual(all.options.len, s.options.len);
    };
    var panel: site.ui.buildpanel.BuildPanel = undefined;
    try panel.init(arena, &block);
    var panel_tree: site.ui.Tree = .{};
    var panel_h: site.ui.H = .init(arena, &panel_tree);
    panel_tree.root = panel.view(&panel_h);
    var panel_html: std.Io.Writer.Allocating = .init(arena);
    try site.ui.html.write(&panel_tree, panel_tree.root, &panel_html.writer);
    try testing.expect(std.mem.find(u8, panel_html.written(), "alt=\"Conqueror\"") != null);
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
    // The rank filter's (builds --site): Darius top solid at Emerald+, thin at Master+
    var rank_paths: [2][]const u8 = undefined;
    for (&rank_paths, [_]u32{ 400, 10 }, [_][]const u8{ "EMERALD", "MASTER" }) |*path, games_at, tier| {
        var f = build_file;
        f.min_tier = tier;
        const bs = try arena.dupe(builds.File.Build, build_file.builds);
        for (bs) |*x| if (x.champion == 122 and x.role == .top) {
            x.games = games_at;
        };
        f.builds = bs;
        const name = try arena.print("builds-{s}.json", .{tier});
        try tmp.dir.writeFile(io, .{ .sub_path = name, .data = try std.json.Stringify.valueAlloc(arena, f, .{}) });
        path.* = try std.fs.path.join(arena, &.{ dir, name });
    }

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
    try fillOn(arena, db, older_patch, 2, 3000);
    var prev_cv = try curvesOne(try cubeDir(arena, dir, "prev"), db, .{ .chosen = &.{prev_patch}, .since_ms = 0, .platforms = &.{"EUW1"} });
    defer prev_cv.builder.deinit();
    try testing.expectEqual(games, prev_cv.summary.games);
    var prev_curves_bytes: std.Io.Writer.Allocating = .init(arena);
    try prev_cv.builder.write(&prev_curves_bytes.writer, prev_patch, 1);
    try tmp.dir.writeFile(io, .{ .sub_path = "curves-prev.bin", .data = prev_curves_bytes.written() });
    const prev_curves_path = try std.fs.path.join(arena, &.{ dir, "curves-prev.bin" });

    // Data Dragon's files for the three patches, as patchnotes caches them: Riot changed
    // Darius' Q cooldown each time
    for ([_][]const u8{ older_patch ++ ".1", prev_patch ++ ".1", patch ++ ".1" }, [_][]const u8{ "10,9,8,7,6", "9,8,7,6,5", "9,7.75,6.5,5.25,4" }) |v, cd| {
        const vdir = try std.fs.path.join(arena, &.{ "ddragon", v });
        try tmp.dir.createDirPath(io, vdir);
        try tmp.dir.writeFile(io, .{ .sub_path = try std.fs.path.join(arena, &.{ vdir, "championFull.json" }), .data = try arena.print(
            \\{{"data":{{"Darius":{{"key":"122","name":"Darius","stats":{{"hp":652}},"spells":[{{"name":"Decimate","cooldown":[{s}],"cost":[25],"range":[425],"tooltip":"x"}}]}}}}}}
        , .{cd}) });
        try tmp.dir.writeFile(io, .{ .sub_path = try std.fs.path.join(arena, &.{ vdir, "item.json" }), .data = "{\"data\":{}}" });
        try tmp.dir.writeFile(io, .{ .sub_path = try std.fs.path.join(arena, &.{ vdir, "runesReforged.json" }), .data = "[]" });
        // No CommunityDragon numbers: Data Dragon's alone, no network
        try tmp.dir.writeFile(io, .{ .sub_path = try std.fs.path.join(arena, &.{ vdir, @import("cdragon.zig").cache_file }), .data = "[]" });
    }

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
        .older_pairs = &.{.{ prev_patch, older_patch }},
        .curves_prev = .{ null, prev_curves_path, null, prev_curves_path },
        .ddragon_dir = try std.fs.path.join(arena, &.{ dir, "ddragon" }),
        .builds_prev = .{ null, prev_builds_path, null, prev_builds_path },
        .builds_rank = .{ .{ rank_paths[0], null, rank_paths[1] }, @splat(null), @splat(null), @splat(null) },
        .lean = lean_path,
    };
    try site.generate(gpa, io, db, opts);
    try expectSiteFiles(arena, io, out);
    {
        // Rank filter files, every view's at the root: Darius at Emerald+ and Diamond+
        // (no one at Master+); the builds from Emerald+'s file, Diamond+'s missing
        for ([_][]const u8{ "", "-patch", "-all", "-all-patch" }) |suffix| for ([_][]const u8{ "", "-build", "-more" }) |part| {
            _ = try std.Io.Dir.cwd().statFile(io, try std.fs.path.join(arena, &.{ out, try arena.print("data/champion/darius{s}-rank{s}.bin", .{ part, suffix }) }), .{});
        };
        // Every view's own champion data
        for ([_][]const u8{ "_v/patch/", "_v/all/", "_v/all-patch/" }) |dir_of| {
            _ = try std.Io.Dir.cwd().statFile(io, try std.fs.path.join(arena, &.{ out, dir_of, "data/champion/darius-more.bin" }), .{});
        }
        const cr = site.ui.champrank;
        const rank_top = try site.ui.data.decode(arena, cr.Top, try std.Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(arena, &.{ out, "data/champion/darius-rank.bin" }), arena, .limited(1 << 20)));
        const rank_build = try site.ui.data.decode(arena, cr.Build, try std.Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(arena, &.{ out, "data/champion/darius-build-rank.bin" }), arena, .limited(1 << 20)));
        const rank_more = try site.ui.data.decode(arena, cr.More, try std.Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(arena, &.{ out, "data/champion/darius-more-rank.bin" }), arena, .limited(1 << 20)));
        for (rank_top.groups[0..2], rank_build.groups[0..2], rank_more.groups[0..2]) |t, b, m| {
            try testing.expectEqual(1, t.len);
            try testing.expectEqual(.top, t[0].role);
            try testing.expectEqual(games, t[0].games);
            try testing.expectEqual(1, t[0].rank);
            try testing.expectEqual(1, t[0].of);
            try testing.expectEqual(1, b[0].from);
            try testing.expect(b[0].build != null and m[0].rels.len == 1 and m[0].rels[0].opps.len > 0 and m[0].by_patch.len == 1);
            try testing.expectEqual(games, m[0].by_patch[0].games);
            // The Matchups tab's count, Top's, is More's lane opponents
            try testing.expectEqual(m[0].rels[0].opps.len, t[0].opps);
        }
        try testing.expectEqual(0, rank_top.groups[2].len);
        try testing.expectError(error.FileNotFound, std.Io.Dir.cwd().statFile(io, try std.fs.path.join(arena, &.{ out, "data/champion/mordekaiser-rank.bin" }), .{}));
    }
    {
        // By rank: every game counted in its bracket, each with ten known players, the
        // median Platinum: all Gold-Emerald, dashed at the head's rate
        const charts = try site.ui.data.decode(arena, site.ui.champpage.ChartsData, try std.Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(arena, &.{ out, "data/champion/darius-charts.bin" }), arena, .limited(1 << 20)));
        const k = charts.roles[0].ranks.?;
        try testing.expectEqual(games, k.all.games);
        try testing.expectEqual([3]u32{ 0, games, 0 }, [3]u32{ k.by[0].games, k.by[1].games, k.by[2].games });
        try testing.expectEqual(k.all.wins, k.by[1].wins);
    }
    for ([_][]const u8{
        "index.html",
        "champions.html",
        "champions/top.html",
        "champions/darius.html",
        "champions/darius/top.html",
        "data/champion/darius.bin",
        "data/champion/darius-build.bin",
        "data/champion/darius-more.bin",
        "_v/patch/index.html",
        "_v/all-patch/index.html",
        "data/stats.bin",
        "matchups.html",
        "learn.html",
        "privacy.html",
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
    // The desktop's comp view facts: the lean file's rows, a mix tally (damage split from
    // raw JSON the fixture may lack), the ban options' ban rates
    {
        const bytes = try std.Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(arena, &.{ out, "data/champ-facts.tsv" }), arena, .limited(1 << 20));
        const facts = try core.champfacts.Facts.parse(arena, bytes);
        try testing.expectEqual(games, facts.leanOf(122, .top).?.games);
        // The fixture's other bans are of champions nobody plays in it, with no row to
        // rate: Darius's ban, in one game of the patch's, is the only line
        try testing.expectEqual(1, facts.bans.len);
        try testing.expectEqual(122, facts.bans[0].champion);
        try testing.expectApproxEqAbs(1 / @as(f32, @floatFromInt(facts.games)), facts.bans[0].rate, 1e-4);
        try testing.expectEqualStrings("15.13", facts.patch);
    }
    // Pool grid: a lanes file per champion and view, the champion page's lane opponents
    {
        for ([_][]const u8{ "", "_v/patch/", "_v/all/", "_v/all-patch/" }) |dir_of| {
            _ = try std.Io.Dir.cwd().statFile(io, try std.fs.path.join(arena, &.{ out, dir_of, "data/pool/lanes/darius.bin" }), .{});
        }
        const lanes = try site.ui.data.decode(arena, site.ui.pooldata.Lanes, try std.Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(arena, &.{ out, "data/pool/lanes/darius.bin" }), arena, .limited(1 << 20)));
        const darius_more = try site.ui.data.decode(arena, site.ui.champpage.MoreData, try std.Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(arena, &.{ out, "data/champion/darius-more.bin" }), arena, .limited(1 << 22)));
        try testing.expectEqual(122, lanes.id);
        try testing.expectEqual(1, lanes.roles.len);
        const top = lanes.of(.top).?;
        try testing.expectEqual(games, top.games);
        const rel = darius_more.roles[0].rels[0];
        try testing.expectEqual(rel.opps.len, top.opps.len);
        try testing.expect(top.opps.len > 0);
        try testing.expectEqual(rel.opps[0].games, top.opps[0].games);
        try testing.expectEqual(rel.opps[0].gold, top.opps[0].gold);
    }
    // Matchup finder: each champion's roles for its picker; a pick's grid fetches the
    // champion page's -more.bin under the view's root (checked above for every view)
    {
        const page = try std.Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(arena, &.{ out, "matchups.html" }), arena, .limited(1 << 22));
        const key = "data-bin=\"";
        const at = (std.mem.find(u8, page, key) orelse return error.TestUnexpectedResult) + key.len;
        const b64 = page[at .. at + (std.mem.findScalar(u8, page[at..], '"') orelse return error.TestUnexpectedResult)];
        const raw = try arena.alloc(u8, try std.base64.standard.Decoder.calcSizeForSlice(b64));
        try std.base64.standard.Decoder.decode(raw, b64);
        const fd = try site.ui.data.decode(arena, site.ui.finder.Data, raw);
        try testing.expectEqual(fd.champs.len, fd.roles.len);
        for (fd.champs, fd.roles) |c, rs| if (std.mem.eql(u8, c.slug, "darius")) {
            try testing.expectEqualSlices(site.ui.role.Role, &.{.top}, rs);
        };
    }
    // Build page: three games, so no bare win rates; the champion page (root view) links
    // into the patch view's
    const pages = [_]struct { []const u8, []const []const u8 }{
        // Patch day: three games a patch is a patch's first day, no role with enough
        // games; Darius, whom Riot changed, in his main role all the same; in every view,
        // linking the patch view's pages, and a tab after Matchups
        .{ "_v/patch/patch.html", &.{ "<h1>Patch 15.13 vs 15.12</h1>", "<div class=\"c-patch\" data-island=\"patch\" data-src=\"/_v/patch/data/patch.bin\" data-stamp=\"", "href=\"/champions/darius/top?period=patch\"", "<span class=\"ar\" aria-hidden=\"true\">▲</span>Q</span>", "league-of-legends-patch-25-13-notes/", "<script src=\"/" ++ assets.patch_js.path ++ "\" data-wasm=\"" ++ assets.patch_wasm.path ++ "\" defer></script>" } },
        // The older pair's page: PatchHead's ‹ › from every patch.html, back to the
        // newest; win rates only, Riot's changes its own
        .{ "patch/15-12.html", &.{ "<h1>Patch 15.12 vs 15.11</h1>", "data-src=\"/data/patch-15.12-15.11.bin\"", "href=\"/patch\"", "<span class=\"ar\" aria-hidden=\"true\">▲</span>Q</span>" } },
        .{ "_v/all/patch/15-12.html", &.{ "<h1>Patch 15.12 vs 15.11</h1>", "href=\"/patch?region=all\"" } },
        .{ "patch.html", &.{"href=\"/patch/15-12\""} },
        .{ "_v/patch/patch.html", &.{"href=\"/patch/15-12\""} },
        .{ "_v/all-patch/patch.html", &.{"href=\"/patch/15-12?region=all\""} },
        .{ "_v/all/patch.html", &.{ "<h1>Patch 15.13 vs 15.12</h1>", "href=\"/champions/darius/top?region=all&amp;period=patch\"", "title=\"This page counts every game we crawl (Plat+)\">Emerald+</a>" } },
        .{ "champions.html", &.{"Matchups</a><a href=\"/patch\">Patch changes</a>"} },
        // Champion page: the ui.champpage island from the root view, its data file for
        // the other roles; the head, the build, the matchups with the most met opponent's
        // brief linking to the matchup page from the champion's side
        .{ "champions/darius.html", &.{ "<div class=\"c-cpage\" data-id=\"122\" data-roles=\"top\"><div class=\"part\" data-island=\"champion\" data-src=\"/data/champion/darius.bin\" data-stamp=\"", "<h1>Darius</h1>", "<span class=\"sum\">EUW · 30 days · Plat+</span>", "data-island=\"champbuild\" data-src=\"/data/champion/darius-build.bin\"", "<section class=\"c-card\" data-v=\"flush\"><div class=\"c-build\">", "<h2>Matchups</h2>", "data-island=\"champmore\" data-src=\"/data/champion/darius-more.bin\"", "data-js=\"/" ++ assets.champmore_js.path ++ "\" data-wasm=\"" ++ assets.champmore_wasm.path ++ "\"", "class=\"c-dots\"", "class=\"c-mpick\"", "href=\"/matchups/top/darius-vs-mordekaiser\"", "<h2>By patch</h2>", "<h2>By game length</h2>", "data-island=\"champcharts\" data-src=\"/data/champion/darius-charts.bin\"", "<h2>Lane</h2>", "<h2>Won by lane gold</h2>", "<h2>Pick-up</h2>", "<h2>By rank</h2>", "<h2>First item done</h2>", "<script src=\"/" ++ assets.champion_js.path ++ "\" data-wasm=\"" ++ assets.champion_wasm.path ++ "\" defer></script>" } },
        .{ "champions.html", &.{ "<div class=\"c-tiers\" data-island=\"tiers\" data-src=\"/data/tiers.bin\" data-stamp=\"", "data-base=\"/\" data-view=\"0\" data-path=\"/champions\"", "<h1>Champions</h1>", "<linearGradient id=\"c-violin-g\"", "<a href=\"/champions?region=all\">All</a>", "<div class=\"rb\">", "<script src=\"/" ++ assets.stats_js.path ++ "\" data-wasm=\"" ++ assets.stats_wasm.path ++ "\" defer></script>" } },
        // Home: the lookup, each role's most played (the example's game: core_loaded); no
        // clear patch move on a patch's first day, so the Patch card is its link alone
        .{ "index.html", &.{ "data-island=\"lookup\" data-to=\"/your\"", "data-island=\"homechamps\" data-bin=\"", "Patch 15.13", "vs 15.12", "href=\"/patch?period=patch\" data-s=\"s\">All changes</a>", "<script src=\"/" ++ assets.home_js.path ++ "\" data-wasm=\"" ++ assets.home_wasm.path ++ "\" defer></script>" } },
        // Daily Draft (ui.dailypage): the fixture makes no puzzle, so the page says so
        .{ "daily.html", &.{ "<h1>Daily Draft</h1>", "No puzzle today." } },
        .{ "privacy.html", &.{ "the date shown is the puzzle&#39;s, not the game&#39;s", "we keep only each puzzle&#39;s totals", "<h2 id=\"accounts\">Accounts</h2>" } },
        // Learn (ui.learnpage): the island with its chapters inline, a first visit on
        // chapter 1's first puzzle, today's five over it
        .{ "learn.html", &.{ "<div class=\"c-learn\" data-island=\"learn\" data-bin=\"", "Does knowing your champion matter?", "How often do mains win?", "Today&#39;s five", "<script src=\"/" ++ assets.learn_js.path ++ "\" data-wasm=\"" ++ assets.learn_wasm.path ++ "\" defer></script>" } },
        // A search for one champion turns its rows to its side (MU8); gold under a clear
        // lead plain (J11, J12)
        .{ "matchups.html", &.{ "<div class=\"c-finder\" data-island=\"finder\" data-query=\"\" data-bin=\"", "<h1>Matchups</h1>", "<div class=\"c-crp-pair\">", "Your champion", "Opponent", "<div class=\"c-fgrid\" data-island=\"findergrid\" data-root=\"/\" data-query=\"\" data-js=\"/" ++ assets.findergrid_js.path ++ "\" data-wasm=\"" ++ assets.findergrid_wasm.path ++ "\"></div>", "<h2>Hardest lanes</h2>", "<h2>Lane bullies</h2>", "<script src=\"/" ++ assets.finder_js.path ++ "\" data-wasm=\"" ++ assets.finder_wasm.path ++ "\" defer></script>" } },
        // One page per champion: the other views link to it with their view
        .{ "_v/all-patch/champions/top.html", &.{ "<a href=\"/champions/top?period=patch\">EUW</a>", "data-path=\"/champions/top\" data-role=\"top\"" } },
        .{ "_v/all/matchups/top/mordekaiser-vs-darius.html", &.{"href=\"/champions/darius?region=all\""} },
        // The matchup page (ui.matchpage): three islands with their data inline; the head
        // with both portraits, the swap and the headline figures, the lane by minute beside
        // head to head, won by gold at 10 and by game length (all lanes dashed), by rank and
        // mastery
        .{ "matchups/top/mordekaiser-vs-darius.html", &.{ "<div class=\"c-cpage c-mpage\" data-id=\"", "data-role=\"top\"><div class=\"part\" data-island=\"matchup\" data-bin=\"", "<h1>Mordekaiser<span class=\"and\">vs</span>Darius</h1>", "href=\"/matchups/top/darius-vs-mordekaiser\"", "Mordekaiser wins", "Vs usual", "data-island=\"matchmore\" data-bin=\"", "data-js=\"/" ++ assets.matchmore_js.path ++ "\" data-wasm=\"" ++ assets.matchmore_wasm.path ++ "\"", "<h2>Lane</h2>", "class=\"c-chart c-lane\"", "<h2>Head to head</h2>", "Kills to 6 min", "Level 6", "First item", "<h2>Won by gold at 10</h2>", "dashed: all lanes", "<h2>By game length</h2>", "dashed: Mordekaiser against everyone", "<h2>By rank and mastery</h2>", "All games", "<script src=\"/" ++ assets.matchup_js.path ++ "\" data-wasm=\"" ++ assets.matchup_wasm.path ++ "\" defer></script>" } },
        // Bot lane partners (MU4): each side's supports, and a support matchup's bot laners
        .{ "matchups/bot/kaisa-vs-twitch.html", &.{ "First blood", "<h2>Lane partners</h2>", "<h3>Twitch with</h3>" } },
        .{ "matchups/support/pyke-vs-rakan.html", &.{"<h3>Rakan with</h3>"} },
        // MatchupStrip: the lane opponents with a page, the current one lit; the pair's build
        .{ "matchups/top/darius-vs-mordekaiser.html", &.{ "<nav class=\"c-mstrip\" aria-label=\"Darius&#39;s Top opponents\">", "<a href=\"/matchups/top/darius-vs-mordekaiser\" aria-current=\"page\"", "data-island=\"champbuild\" data-bin=\"", "<h2>Build against Mordekaiser</h2>", "href=\"/champions/darius/top\"" } },
        .{ "method.html", &.{ "Games to stabilise", "<li><strong>Highest win rate</strong>: marked among options", "<h2 id=\"lean\">Early or late</h2>" } },
        // The board, pool and its section follow the view
        .{ "_v/patch/champions.html", &.{ "data-view=\"1\"", "<a href=\"/champions\">30 days</a>" } },
        .{ "_v/all/pool.html", &.{ "<div class=\"c-poolwrap\"><div class=\"c-poolpage\" data-island=\"pool\" data-bin=\"", "<p class=\"muted\"><span class=\"c-scope\"><span class=\"c-chip\" data-v=\"scope\" title=\"Region, period and rank these numbers are from\"><span class=\"part\">All regions</span>" } },
        // Scope chips (ui.scopechip): what each block covers, marked where it doesn't
        // follow the page's picks
        // View links: this page in each view, the current one lit, ranks greyed
        .{ "_v/patch/matchups/top/darius-vs-mordekaiser.html", &.{ "<a aria-current=\"page\">15.13</a>", "<a href=\"/matchups/top/darius-vs-mordekaiser\">30 days</a>", "<a aria-disabled=\"true\">Emerald+</a>" } },
        // Pool: the island empty (the picker), the grid's island empty beside it, the
        // lanes' scope, ui-pool.wasm and ui-poolgrid.wasm
        .{ "pool.html", &.{ "<h2>Choose your pool</h2>", "<div class=\"c-poolgrid\" data-island=\"poolgrid\"></div></div>", "<script src=\"/" ++ assets.poolgrid_js.path ++ "\" data-wasm=\"" ++ assets.poolgrid_wasm.path ++ "\" defer></script>", "<p class=\"muted\"><span class=\"c-scope\"><span class=\"c-chip\" data-v=\"scope\" title=\"Region, period and rank these numbers are from\"><span class=\"part\">EUW</span><span class=\"part\">30 days</span>", "(<a href=\"/pickup\">How hard to pick up</a>)", "<script src=\"/" ++ assets.pool_js.path ++ "\" data-wasm=\"" ++ assets.pool_wasm.path ++ "\" defer></script>" } },
        .{ "pickup.html", &.{ "<h1>How hard to pick up <span class=\"c-scope\"><span class=\"c-chip\" data-v=\"scope\" title=\"Region, period and rank these numbers are from\"><span class=\"part off\">All regions, not EUW alone</span><span class=\"part\">30 days</span>", "<a aria-current=\"page\">All</a><a href=\"/pickup/top\">Top</a>" } },
        .{ "_v/patch/pickup/mid.html", &.{ "<a href=\"/pickup?period=patch\">All</a><a href=\"/pickup/top?period=patch\">Top</a>", "<a aria-current=\"page\">Mid</a>" } },
        .{ "_v/all-patch/pool.html", &.{"<span class=\"c-scope\"><span class=\"c-chip\" data-v=\"scope\" title=\"Region, period and rank these numbers are from\"><span class=\"part\">All regions</span><span class=\"part\">Patch 15.13</span><span class=\"part\">Plat+</span></span></span> Lanes:"} },
    };
    for (pages) |pg| {
        const path = try std.fs.path.join(arena, &.{ out, pg[0] });
        const html = try std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 20));
        for (pg[1]) |want| if (std.mem.find(u8, html, want) == null) {
            std.debug.print("{s} lacks {s}\n", .{ pg[0], want });
            return error.TestUnexpectedResult;
        };
    }
    // The older pair's period switch stays on it: no patch view has the page
    {
        const pair_page = try std.Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(arena, &.{ out, "patch/15-12.html" }), arena, .limited(1 << 20));
        try testing.expect(std.mem.find(u8, pair_page, "/patch/15-12?period=patch") == null);
        try testing.expect(std.mem.find(u8, pair_page, "so far") == null);
    }
    // Matchup first screen: the numbers and opponents, the pair's build, then head to head
    // beside the lane, the outcome cards last
    {
        const path = try std.fs.path.join(arena, &.{ out, "matchups/top/darius-vs-mordekaiser.html" });
        const html = try std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 20));
        var at: usize = 0;
        for ([_][]const u8{ "<nav class=\"c-mstrip\"", "<h2>Build against Mordekaiser", "<h2>Head to head</h2>", "<h2>Lane</h2>", "<h2>Won by gold at 10</h2>" }) |want| {
            at = (std.mem.findPos(u8, html, at, want) orelse {
                std.debug.print("darius-vs-mordekaiser: {s} missing or out of order\n", .{want});
                return error.TestUnexpectedResult;
            }) + want.len;
        }
    }
    // Data is Platinum+ (the crawl's floor): no lower tier to filter by, no "all ranks"
    for ([_][]const u8{ "champions.html", "champions/darius.html" }) |page| {
        const path = try std.fs.path.join(arena, &.{ out, page });
        const html = try std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 20));
        for ([_][]const u8{ "all ranks", "All ranks", ">Gold+" }) |bad| if (std.mem.find(u8, html, bad) != null) {
            std.debug.print("{s} has {s}\n", .{ page, bad });
            return error.TestUnexpectedResult;
        };
    }
    // The matchup page's islands: what ui-matchup.wasm and ui-matchmore.wasm render from
    // their data-bin is the page's own (hydration adopts the server's nodes as they are)
    {
        const path = try std.fs.path.join(arena, &.{ out, "matchups/top/mordekaiser-vs-darius.html" });
        const page = try std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 22));
        const mp = site.ui.matchpage;
        var t: site.ui.Tree = .{};
        var h: site.ui.H = .init(arena, &t);
        const hb = try dataBin(arena, page, "matchup");
        const hd = try arena.create(mp.HeadData);
        hd.* = try site.ui.data.decode(arena, mp.HeadData, hb[1]);
        var head: mp.Head = try .init(arena, hd);
        head.bin = hb[0];
        const mb = try dataBin(arena, page, "matchmore");
        const md = try arena.create(mp.MoreData);
        md.* = try site.ui.data.decode(arena, mp.MoreData, mb[1]);
        var mo: mp.More = try .init(arena, md);
        mo.bin = mb[0];
        mo.js = "/" ++ assets.matchmore_js.path;
        mo.wasm = assets.matchmore_wasm.path;
        for ([_]site.ui.N{ head.view(&h), mo.view(&h) }, [_][]const u8{ "matchup", "matchmore" }) |n, name| {
            var w: std.Io.Writer.Allocating = .init(arena);
            try site.ui.html.write(&t, n, &w.writer);
            if (std.mem.find(u8, page, w.written()) == null) {
                std.debug.print("mordekaiser-vs-darius: the {s} island differs from ui.wasm's render of its data-bin\n", .{name});
                return error.TestUnexpectedResult;
            }
        }
    }

    // The champions board: what ui-stats.wasm renders from the data file, before the
    // URL's state, is the page's own (hydration adopts the server's nodes as they are)
    for ([_]struct { []const u8, []const u8, ?site.ui.tiers.Role }{
        .{ "champions.html", "/champions", null },
        .{ "champions/top.html", "/champions/top", .top },
    }) |c| {
        const page = try std.Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(arena, &.{ out, c[0] }), arena, .limited(1 << 22));
        const bytes = try std.Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(arena, &.{ out, "data/tiers.bin" }), arena, .limited(1 << 22));
        const tiers = site.ui.tiers;
        const d = try arena.create(tiers.Data);
        d.* = try site.ui.data.decode(arena, tiers.Data, bytes);
        var state: tiers.Tiers = .init(d, try tiers.prepare(arena, d, "/"), c[2]);
        state.path = c[1];
        state.src = "/data/tiers.bin";
        state.stamp = tiers.stamp(bytes);
        var t: site.ui.Tree = .{};
        var h: site.ui.H = .init(arena, &t);
        t.root = state.view(&h);
        var w: std.Io.Writer.Allocating = .init(arena);
        try site.ui.html.write(&t, t.root, &w.writer);
        if (std.mem.find(u8, page, w.written()) == null) {
            std.debug.print("{s}: the island differs from ui.wasm's render of data/tiers.bin\n", .{c[0]});
            return error.TestUnexpectedResult;
        }
    }

    // The patch page: ui-patch.wasm's render of its view's data file is the page's own
    for ([_][]const u8{ "", "_v/patch/", "_v/all/" }) |vdir| {
        const page_path = try std.mem.concat(arena, u8, &.{ vdir, "patch.html" });
        const page = try std.Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(arena, &.{ out, page_path }), arena, .limited(1 << 22));
        const bytes = try std.Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(arena, &.{ out, vdir, "data/patch.bin" }), arena, .limited(1 << 22));
        const pp = site.ui.patchpage;
        const d = try arena.create(pp.Data);
        d.* = try site.ui.data.decode(arena, pp.Data, bytes);
        var state: pp.Page = .init(d, try pp.prepare(arena, d, "/"));
        state.base = "/";
        state.src = try std.mem.concat(arena, u8, &.{ "/", vdir, "data/patch.bin" });
        state.stamp = pp.stamp(bytes);
        var t: site.ui.Tree = .{};
        var h: site.ui.H = .init(arena, &t);
        t.root = state.view(&h);
        var w: std.Io.Writer.Allocating = .init(arena);
        try site.ui.html.write(&t, t.root, &w.writer);
        if (std.mem.find(u8, page, w.written()) == null) {
            std.debug.print("{s}: the island differs from ui.wasm's render of data/patch.bin\n", .{page_path});
            return error.TestUnexpectedResult;
        }
    }

    // The board's rank files (tierlist.rankFiles), every view's: Darius top at Emerald+,
    // no spreads, the rank's pick and ban; picked, the board shows it and links it on
    {
        const tiers = site.ui.tiers;
        for (tiers.rank_paths) |p| _ = try std.Io.Dir.cwd().statFile(io, try std.fs.path.join(arena, &.{ out, p }), .{});
        const bytes = try std.Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(arena, &.{ out, tiers.rank_paths[0] }), arena, .limited(1 << 22));
        const rk = try site.ui.data.decode(arena, tiers.RankData, bytes);
        const em = &rk.groups[0];
        try testing.expectEqual(.emerald, em.rank);
        const top = for (em.rows) |r| {
            if (r.role == .top and std.mem.eql(u8, em.champs[r.champ].slug, "darius")) break r;
        } else return error.TestUnexpectedResult;
        try testing.expect(top.games > 0 and top.spread == null and top.rates != null);
        const plat = try site.ui.data.decode(arena, tiers.Data, try std.Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(arena, &.{ out, "data/tiers.bin" }), arena, .limited(1 << 22)));
        var state: tiers.Tiers = .init(&plat, try tiers.prepare(arena, &plat, "/"), null);
        state.want = .emerald;
        try testing.expect(state.need());
        state.ranks = &rk;
        try state.show(arena);
        try testing.expect(!state.busy() and state.data == em);
        var t: site.ui.Tree = .{};
        var h: site.ui.H = .init(arena, &t);
        t.root = state.view(&h);
        var w: std.Io.Writer.Allocating = .init(arena);
        try site.ui.html.write(&t, t.root, &w.writer);
        try testing.expect(std.mem.find(u8, w.written(), " · Emerald+") != null);
        // Under the Games floor here, so off the table, but its link carries the rank
        const line = for (state.lines[1]) |*l| {
            if (std.mem.find(u8, l.href, "/champions/darius/") != null) break l;
        } else return error.TestUnexpectedResult;
        try testing.expectEqualStrings("/champions/darius/top#rank=emerald", line.href);
    }

    // Rendered on request (site.Loaded, `meiolol serve --render` and `dev`): every file
    // the static build wrote, byte for byte, and nothing for paths it didn't
    const loaded = try site.Loaded.init(gpa, io, db, opts);
    defer loaded.deinit();
    {
        // Rank filter: Master+ asked, Diamond+ missing, Master+ thin, so Emerald+ shown
        const s = try loaded.site(site.html.View.all[0]);
        const ch = s.champBySlug("darius").?;
        const v = s.view;
        const at = site.builds_page.forRank(s, v, ch, .top, 3).?;
        try testing.expectEqual(1, at.rank);
        try testing.expectEqual(400, at.picked.b.games);
        try testing.expectEqualStrings("EMERALD", at.picked.f.min_tier);
        try testing.expectEqual(0, site.builds_page.forRank(s, v, ch, .top, 0).?.rank);
        try testing.expectEqual(0, site.builds_page.forRank(s, .{ .region = .euw, .period = .patch }, ch, .top, 3).?.rank);
    }
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
        if (std.mem.endsWith(u8, e.path, ".html")) {
            try expectPageLinks(arena, e.path, want);
            csp.check(want) catch |err| {
                std.debug.print("{s}: CSP {t}\n", .{ e.path, err });
                return err;
            };
        }
    }
    try testing.expect(checked > 50);
    // The account pages (ui.account): rendered on request only, never indexed
    for ([_][]const u8{ "login", "signup", "join", "account" }) |p| {
        const page = try loaded.get(arena, try std.fmt.allocPrint(arena, "{s}.html", .{p})) orelse return error.TestUnexpectedResult;
        try testing.expect(std.mem.find(u8, page, "<meta name=\"robots\" content=\"noindex\">") != null);
        try csp.check(page);
        try testing.expect(std.mem.find(u8, page, try std.fmt.allocPrint(arena, "data-island=\"account\" data-kind=\"{s}\"", .{p})) != null);
        const action = if (std.mem.eql(u8, p, "account")) "password" else p;
        try testing.expect(std.mem.find(u8, page, try std.fmt.allocPrint(arena, "<form method=\"post\" action=\"/auth/{s}\">", .{action})) != null);
        try testing.expect(std.mem.find(u8, page, "data-wasm=\"" ++ assets.account_wasm.path ++ "\"") != null);
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
            try testing.expectEqual(0, again.extras.people.items.len);
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
            try testing.expectEqual(1, again.extras.people.items.len);
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
            // Views at once (Options.view_loads), each on its own connection: the same
            // bytes, the people tallies made once
            for ([_]usize{ 2, 4 }) |n| {
                var at_once_opts = opts;
                at_once_opts.view_loads = n;
                const at_once = try site.Loaded.init(gpa, io, file_db, at_once_opts);
                defer at_once.deinit();
                at_once.lazy = false;
                try at_once.loadAll();
                try testing.expectEqual(1, at_once.extras.people.items.len);
                // The options part holds it
                at_once.opts.view_loads = 1;
                try at_once.writeViews(again_path);
                try testing.expectEqualSlices(u8, views_bytes, try std.Io.Dir.cwd().readFileAlloc(io, again_path, arena, .limited(1 << 30)));
            }
            // A view that fails stops the build with its own error, not a stopped
            // view's, and no load waits on it for ever. Every 30-day view has no games
            for ([_]usize{ 2, 4 }) |n| {
                var failing = opts;
                failing.view_loads = n;
                failing.since_ms = std.math.maxInt(i64);
                const at_once = try site.Loaded.init(gpa, io, file_db, failing);
                defer at_once.deinit();
                try testing.expectError(error.NoMatches, at_once.loadAll());
            }
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
        try testing.expectError(error.Loading, early.get(arena, "_v/patch/index.html"));
    }
    // Thin matchups left out of the static build are still rendered on request
    {
        var s = (try loaded.site(site.html.View.all[0])).*;
        s.arena = arena;
        s.opts.static_min_games = std.math.maxInt(u32);
        for (try site.pagePaths(&s)) |p| try testing.expect(p != .matchup);
        try testing.expect(try loaded.get(arena, "matchups/top/mordekaiser-vs-darius.html") != null);
    }
    for ([_][]const u8{ "champions/nobody.html", "champions/darius/mid.html", "_v/all/champions/darius.html", "matchups/top/darius-vs-darius.html", "matchups/mid/darius-vs-mordekaiser.html", "_v/all/daily.html", "_v/patch/learn.html", "_v/patch/", "nosuch.html", "data/your-example.json" }) |path| {
        try testing.expectEqual(null, try loaded.get(arena, path));
    }
    // The renderer's 404 page for them (serve.notFoundPage): the site's chrome, links
    // and assets root-relative (any depth), never indexed
    {
        const page = try loaded.notFound(arena);
        for ([_][]const u8{ "<h1>Page not found</h1>", "href=\"/\">Home</a>", "href=\"/champions\">Champions</a>", "<meta name=\"robots\" content=\"noindex\">", "<link rel=\"stylesheet\" href=\"/" }) |want| {
            if (std.mem.find(u8, page, want) == null) {
                std.debug.print("404 page lacks {s}\n", .{want});
                return error.TestUnexpectedResult;
            }
        }
    }
    // /admin/api/pages.txt, cache-warm's list: each once and each rendered, the home and
    // the shared pages in it, the fixture's thin matchups not
    {
        const list = try loaded.pageList(arena);
        var seen: std.StringHashMapUnmanaged(void) = .empty;
        for (list) |p| {
            if ((try seen.fetchPut(arena, p, {})) != null or try loaded.get(arena, p) == null) {
                std.debug.print("pages.txt: {s} twice or not rendered\n", .{p});
                return error.TestUnexpectedResult;
            }
        }
        var wants: std.ArrayList([]const u8) = .empty;
        try wants.appendSlice(arena, &.{ "index.html", "champions.html", "champions/darius.html", "champions/darius/top.html", "_v/all/index.html" });
        // Your games: none without the example's list (this site has none)
        for (site.shared_pages) |p| if (p != .your) try wants.append(arena, try site.filePath(arena, site.html.View.all[0], p));
        for (wants.items) |want| {
            if (!seen.contains(want)) {
                std.debug.print("pages.txt lacks {s}\n", .{want});
                return error.TestUnexpectedResult;
            }
        }
        try testing.expect(!seen.contains("matchups/top/mordekaiser-vs-darius.html"));
    }

    // `--static core` (deploy/web-loop.sh): only core_static and the front-end files, all
    // at the site root, no view loaded; everything the full build writes, the home and
    // root sitemap too, is rendered (public here, so the pages differ from the full
    // build's by the preview banner), and the core files are the renderer's bytes too
    try tmp.dir.writeFile(io, .{ .sub_path = "your-example.json", .data = example_json });
    var core_opts = opts;
    core_opts.out_dir = try std.fs.path.join(arena, &.{ dir, "core" });
    core_opts.static = .core;
    core_opts.public = true;
    core_opts.origin = "https://x.io";
    core_opts.riot_txt = "riot-check";
    core_opts.your_example = try std.fs.path.join(arena, &.{ dir, "your-example.json" });
    try site.generate(gpa, io, db, core_opts);
    // The renderer's views file with the root view's patch day given a clear move (the
    // fixture's patch has none), for the home's Patch card
    const moved = try std.fs.path.join(arena, &.{ dir, "views-moved.bin" });
    try withClearMove(arena, io, try std.fs.path.join(arena, &.{ dir, "views-again.bin" }), moved);
    const core_loaded = try site.Loaded.init(gpa, io, db, core_opts);
    defer core_loaded.deinit();
    try core_loaded.reuseViews(moved);
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
    for ([_][]const u8{ "index.html", "sitemap.xml" }) |name| {
        try testing.expectError(error.FileNotFound, core_dir.access(io, name, .{}));
    }
    // The full build with its views loaded at once (Options.view_loads), from the
    // database in files as on the box: the same files. A view that fails stops the build
    // with its own error, nothing written
    {
        const files = try std.fs.path.join(arena, &.{ dir, "db-core" });
        try std.Io.Dir.cwd().createDirPath(io, files);
        for ([_][]const u8{ "main", "raw", "timeline" }, [_][]const u8{ "meiolol.db", "raw.db", "timeline.db" }) |schema, name| {
            try db.exec(try arena.printSentinel("VACUUM {s} INTO '{s}/{s}'", .{ schema, files, name }, 0));
        }
        const file_db = try store.schema.open(gpa, files);
        defer file_db.close();
        for ([_]usize{ 2, 4 }) |n| {
            var at_once = opts;
            at_once.view_loads = n;
            at_once.out_dir = try std.fmt.allocPrint(arena, "{s}-at-{d}", .{ opts.out_dir, n });
            try site.generate(gpa, io, file_db, at_once);
            try expectSameTree(arena, io, opts.out_dir, at_once.out_dir);
            var failing = at_once;
            failing.since_ms = std.math.maxInt(i64);
            failing.out_dir = try std.fmt.allocPrint(arena, "{s}-failing", .{at_once.out_dir});
            try testing.expectError(error.NoMatches, site.generate(gpa, io, file_db, failing));
            var empty = try std.Io.Dir.cwd().openDir(io, failing.out_dir, .{ .iterate = true });
            defer empty.close(io);
            var it = empty.iterate();
            try testing.expectEqual(null, try it.next(io));
        }
    }
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
    // The game page and its data from the example's detail
    try testing.expect(std.mem.find(u8, example_json, "\"detail\":{") != null);
    try testing.expectEqual(null, try core_loaded.get(arena, "data/your-example.json"));
    const game_page = (try core_loaded.get(arena, "game.html")).?;
    for ([_][]const u8{ "data-island=\"games\"", "data-src=\"data/your/mid.bin\"", "ui-games.", "noindex", "data-island=\"gamemore\"", "data-js=\"" ++ assets.gamemore_js.path ++ "\" data-wasm=\"" ++ assets.gamemore_wasm.path ++ "\"", "data-island=\"gamelane\"", "data-js=\"" ++ assets.gamelane_js.path ++ "\" data-wasm=\"" ++ assets.gamelane_wasm.path ++ "\"" }) |want| {
        try testing.expect(std.mem.find(u8, game_page, want) != null);
    }
    // The list page: the example's list in the island, rows opening /game
    const your_page = (try core_loaded.get(arena, "your.html")).?;
    try testing.expect(std.mem.find(u8, your_page, "noindex") == null);
    for ([_][]const u8{ "data-island=\"your\" data-bin=\"", "class=\"c-player\"", "class=\"c-psum\"", "href=\"/game#g=0\"", "data-wasm=\"" ++ assets.your_wasm.path ++ "\"", "data-island=\"yourviews\"", "data-island=\"yourtime\"", "data-js=\"" ++ assets.yourtime_js.path ++ "\" data-wasm=\"" ++ assets.yourtime_wasm.path ++ "\"", "data-wasm=\"" ++ assets.yourviews_wasm.path ++ "\"", "data-island=\"yourlookup\"", "data-island=\"forget\"", "data-island=\"yourfriends\"", "data-wasm=\"" ++ assets.yourfriends_wasm.path ++ "\"", "data-wasm=\"" ++ assets.forget_wasm.path ++ "\"", "data-js=\"" ++ assets.yourlookup_js.path ++ "\" data-wasm=\"" ++ assets.yourlookup_wasm.path ++ "\"", "An example player" }) |want| {
        try testing.expect(std.mem.find(u8, your_page, want) != null);
    }
    // Squads: the start view, its island loads the fragment's squad; never indexed, and
    // one click from every page (the header)
    const squad_page = (try core_loaded.get(arena, "squad.html")).?;
    for ([_][]const u8{ "noindex", "data-island=\"squad\"", "data-wasm=\"" ++ assets.squad_wasm.path ++ "\"", "class=\"c-squad\"" }) |want| {
        try testing.expect(std.mem.find(u8, squad_page, want) != null);
    }
    try testing.expect(std.mem.find(u8, (try core_loaded.get(arena, "index.html")).?, "href=\"/squad\"") != null);
    // Home in every view: the shared view's example, its game file loaded lazily; the
    // Patch card's moves (all/ has none: its patch day isn't in views-moved.bin)
    {
        const home = (try core_loaded.get(arena, "index.html")).?;
        try testing.expect(std.mem.find(u8, home, "<ul class=\"c-today\" data-v=\"changes\"><li><a href=\"/champions/darius/top\">") != null);
        try testing.expect(std.mem.find(u8, home, "<small>45.0% → 56.0%</small>") != null);
    }
    for ([_][]const u8{ "index.html", "_v/all/index.html" }) |path| {
        const home = (try core_loaded.get(arena, path)).?;
        try testing.expect(std.mem.find(u8, home, "vs 15.12") != null);
        for ([_][]const u8{ "data-island=\"home\" data-src=\"", "data/your/mid.bin\"", "data-js=\"", assets.homegame_js.path ++ "\" data-wasm=\"" ++ assets.homegame_wasm.path ++ "\"" }) |want| {
            try testing.expect(std.mem.find(u8, home, want) != null);
        }
    }
    inline for (core.Role.all) |r| {
        const bin = (try core_loaded.get(arena, "data/your/" ++ comptime r.label() ++ ".bin")).?;
        const d = try ui.data.decode(arena, ui.gamedata.Data, bin);
        try testing.expectEqual(games, d.games.len);
    }
    // The list: the default role's games, each with its page on game.html
    const list = try ui.data.decode(arena, ui.yourlist.List, (try core_loaded.get(arena, "data/your/list.bin")).?);
    const mid = try ui.data.decode(arena, ui.gamedata.Data, (try core_loaded.get(arena, "data/your/mid.bin")).?);
    try testing.expectEqualStrings("Example player", list.player.name);
    try testing.expectEqual(games, list.games.len);
    for (list.games, mid.games, 0..) |row, g, i| {
        try testing.expectEqual(@as(?u16, @intCast(i)), row.page);
        try testing.expectEqual(g.me().cs, row.cs.?);
        try testing.expectEqualStrings(mid.champs[g.me().champ].name, list.champs[row.champ].name);
    }
    // Sitemaps list rendered pages
    const sitemap = (try core_loaded.get(arena, "sitemap.xml")).?;
    for ([_][]const u8{ "<loc>https://x.io/champions/darius</loc>", "<loc>https://x.io/matchups/top/mordekaiser-vs-darius</loc>", "<loc>https://x.io/daily</loc>", "<loc>https://x.io/learn</loc>" }) |want| {
        try testing.expect(std.mem.find(u8, sitemap, want) != null);
    }
    // Unlisted pages, a main role's own URL and the views stay out: one sitemap
    for ([_][]const u8{ "x.io/game<", "x.io/squad<", "x.io/champions/darius/top<", "region=", "period=" }) |page| {
        try testing.expect(std.mem.find(u8, sitemap, page) == null);
    }
    try testing.expectEqual(null, try core_loaded.get(arena, "_v/patch/sitemap.xml"));
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
    // The private site's index: none of the box's data, and the old JS tester is gone
    const private = try std.fs.path.join(arena, &.{ dir, "p" });
    try admin.private(gpa, io, private);
    const i_html = try std.Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(arena, &.{ private, "index.html" }), arena, .limited(1 << 20));
    for ([_][]const u8{ "<meta name=\"robots\" content=\"noindex\">", "href=\"/private/tester\"", "href=\"/private/app\"", "\"admin-link\"" }) |s| {
        try std.testing.expect(std.mem.find(u8, i_html, s) != null);
    }
    try std.testing.expect(std.mem.find(u8, i_html, "/private/old") == null);
    for ([_][]const u8{ "data.json", "old.html", "admin.js", "admin-draft.js", "admin-setnet.js", "admin.css" }) |f| {
        try std.testing.expectError(error.FileNotFound, std.Io.Dir.cwd().access(io, try std.fs.path.join(arena, &.{ private, f }), .{}));
    }
    // The new tester beside it: the island with the champions inline, its code and style
    try site_tester.write(gpa, io, private, db);
    const t_html = try std.Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(arena, &.{ private, "tester.html" }), arena, .limited(1 << 20));
    // Private: never indexed, its code never among the public site's assets
    for (site.hashed_assets) |x| {
        for ([_][]const u8{ assets.tester_js.path, assets.tester_wasm.path, assets.testercand_js.path, assets.testercand_wasm.path }) |f| try std.testing.expect(!std.mem.eql(u8, x.path, f));
    }
    for ([_][]const u8{ "<meta name=\"robots\" content=\"noindex\">", "data-island=\"tester\"", "data-bin=\"", assets.tester_js.path, "<style>@layer", "data-island=\"testercand\"", assets.testercand_js.path }) |s| {
        try std.testing.expect(std.mem.find(u8, t_html, s) != null);
    }
    try std.testing.expect(std.mem.find(u8, t_html, "stylesheet") == null);
    for ([_][]const u8{ assets.tester_js.path, assets.tester_wasm.path, assets.testercand_js.path, assets.testercand_wasm.path, "tester.html.gz" }) |f| {
        try std.Io.Dir.cwd().access(io, try std.fs.path.join(arena, &.{ private, f }), .{});
    }
    // The admin page beside its data: empty islands the wasms fill from admin.bin, the
    // chart tabs' hidden with their code on the root (loaded by ui-admin.wasm)
    try site_admin.write(gpa, io, out);
    const a_html = try std.Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(arena, &.{ out, "index.html" }), arena, .limited(1 << 20));
    for ([_][]const u8{ "<meta name=\"robots\" content=\"noindex\">", "data-island=\"admin\"", site_admin.js.path, site_admin.wasm.path, "<style>@layer", ".c-admin", ".c-adcharts", "data-island=\"admincharts\"", site_admin.charts_js.path, site_admin.charts_wasm.path, "data-island=\"admintraffic\"", site_admin.traffic_js.path, site_admin.traffic_wasm.path, "data-island=\"adminops\"", site_admin.ops_js.path, site_admin.ops_wasm.path, "data-island=\"adminmodels\"", site_admin.models_js.path, site_admin.models_wasm.path, "data-island=\"adminlab\"", site_admin.lab_js.path, site_admin.lab_wasm.path, "data-island=\"adminruns\"", site_admin.runs_js.path, site_admin.runs_wasm.path }) |s| {
        try std.testing.expect(std.mem.find(u8, a_html, s) != null);
    }
    try std.testing.expect(std.mem.find(u8, a_html, "stylesheet") == null);
    for ([_][]const u8{ site_admin.js.path, site_admin.wasm.path, site_admin.charts_js.path, site_admin.charts_wasm.path, "index.html.gz", "new.html", "admin.bin.gz", "models.bin.gz" }) |f| {
        try std.Io.Dir.cwd().access(io, try std.fs.path.join(arena, &.{ out, f }), .{});
    }
    // The old page's files are gone: no JSON copy of the data, no admin.js
    for ([_][]const u8{ "data.json", "admin.js", "admin-nn.js", "admin.css" }) |f| {
        try std.testing.expectError(error.FileNotFound, std.Io.Dir.cwd().access(io, try std.fs.path.join(arena, &.{ out, f }), .{}));
    }
    // admin.bin: the same snapshot typed, for the new page (ui/admindata.zig)
    const bin = try std.Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(arena, &.{ out, "admin.bin" }), arena, .limited(4 << 20));
    const snap = try ui.data.decode(arena, ui.admindata.Snapshot, bin);
    try std.testing.expectEqual(1760224200, snap.now);
    var europe: u64 = 0;
    for (snap.crawl.buckets) |b| europe += b.m[@backingInt(ui.admindata.Region.europe)];
    try std.testing.expectEqual(25, europe);
    // models.bin: the Models tab's eval digest (ui/modelsdata.zig)
    const models = try ui.data.decode(arena, ui.modelsdata.Models, try std.Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(arena, &.{ out, "models.bin" }), arena, .limited(4 << 20)));
    try std.testing.expectEqual(snap.now, models.now);
    try std.testing.expectEqual(snap.eval.len, models.eval.len);
    try std.testing.expectEqualSlices(i64, &.{1760223600}, snap.crawl.restarts);
    try std.testing.expectEqual(3, snap.drafts.rows);
    try std.testing.expectEqualStrings("unknown", snap.drafts.tiers[snap.drafts.tiers.len - 1].key);
    try std.testing.expectEqual(3, snap.history.len);
    try std.testing.expectEqual(@as(?u64, 2), snap.history[0].drafts);
    try std.testing.expectEqual(3, snap.deploy_events.len);
    try std.testing.expectEqualStrings("swap", snap.deploy_events[2].step);
    try std.testing.expectEqualStrings("matches", snap.storage.?.rows[0].name);
    try std.testing.expectEqualStrings("--proxy 10.0.0.3:8092", snap.riot.crawl_args);
    try std.testing.expectEqual(2, snap.riot.key_problems.len);
    try std.testing.expectEqual(1, snap.backups.?.files);
    try std.testing.expectEqualStrings("# meiolol eval\n", snap.eval_report);
    try std.testing.expect(std.mem.find(u8, bin, "EUW1_7123456") == null);
    for (snap.counts) |c| if (std.mem.eql(u8, c.name, "matches")) try std.testing.expectEqual(3, c.rows);
    try std.testing.expectEqualStrings("warning(riot): 429 (server) on /lol/match/vN/matches/…, waiting Ns", snap.crawl.messages[0].text);
    try std.testing.expectEqualSlices(u64, &.{ 0, 0, 1, 0 }, &snap.drafts.days[0].recent);
    try std.testing.expectEqualStrings("error(riot): 403 on /lol/match/vN/matches/…: key missing or expired", snap.riot.key_problems[0].text);
    // live.bin (admin_api.zig), its command results given
    const live_bin = try ui.data.decode(arena, ui.admindata.Live, try admin.liveBin(arena, io, db, .{
        .data_dir = dir,
        .now_s = 1760224200,
        .services = .{ .@"meiolol-crawl" = "active" },
        .health = "crawler silent",
        .disk = .{ 100, 40, 60 },
        .action = .{ .name = "site-build", .since = 1760224190 },
    }));
    try std.testing.expectEqualStrings("meiolol-crawl", live_bin.services[0].unit);
    try std.testing.expectEqualStrings("active", live_bin.services[0].state);
    try std.testing.expectEqual(60, live_bin.crawl.step);
    try std.testing.expectEqual(@as(u64, 40), live_bin.disk.?.used);
    try std.testing.expectEqualStrings("crawl-restart", live_bin.actions[0].name);
    try std.testing.expectEqual(3, live_bin.deploys.len);
    // Redacted when served
    try std.testing.expectEqualStrings("ab12cd fix …'s timeline", live_bin.deploys[1].detail);
    try std.testing.expectEqualStrings("site-build", live_bin.action.?.name);
    try std.testing.expectEqual(@as(?i64, null), live_bin.eval_since);
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
    // The new tester page's file: the same model, scored by ui.wasm's code
    try testerbin.convert(arena, io, dir, &log.writer);
    const bin = try ui.testerdata.Model.decode(arena, try tmp.dir.readFileAlloc(io, "tester/draft-model.bin", arena, .limited(16 << 20)));
    try testing.expectEqual(10, bin.params.terms.len);
    try testing.expect(bin.check(&try bin.scorer(arena)).ok());

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
    // The new tester page's lane file, checked against lane-ref.json by ui.wasm's scorer
    try testerbin.convert(arena, io, dir, &log.writer);
    const lane_bin = try ui.testerlane.Model.decode(arena, try tmp.dir.readFileAlloc(io, "tester/lane-model.bin", arena, .limited(16 << 20)));
    try testing.expectEqual(10, lane_bin.champ.len);
    try testing.expect((try ui.testerlane.Scorer.init(arena, &lane_bin)).check().ok());
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

    const dir = try std.fs.path.join(arena, &.{ ".zig-cache", "tmp", &tmp.sub_path, tag });
    var cv = try curvesOne(try cubeDir(arena, dir, "curves"), db, .{ .chosen = &.{patch}, .since_ms = 0, .platforms = both });
    defer cv.builder.deinit();
    var curves_bytes: std.Io.Writer.Allocating = .init(arena);
    try cv.builder.write(&curves_bytes.writer, patch, 1);
    out[0] = curves_bytes.written();

    var bd = try buildsOne(try cubeDir(arena, dir, "builds"), db, .{}, .{ .slice = .{ .platforms = both, .patches = &.{patch} } });
    defer bd.deinit();
    out[1] = try std.json.Stringify.valueAlloc(arena, try bd.file(arena, &build_data, patch, "PLATINUM", 10), .{});

    var ln = try lean.load(gpa, io, db, &.{patch}, both, 0, std.math.maxInt(i64));
    defer ln.deinit(gpa);
    const lf = try lean.fit(gpa, ln.list.items, ln.champs.ids.items.len);
    defer lf.deinit(gpa);
    var lean_bytes: std.Io.Writer.Allocating = .init(arena);
    try lean.write(&lean_bytes.writer, &lf, ln.champs.ids.items, ln.list.items, "every region");
    out[2] = lean_bytes.written();

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
    const o: builds.Options = .{ .min_tier = null };
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir = try std.fs.path.join(arena, &.{ ".zig-cache", "tmp", &tmp.sub_path });
    try db.exec("UPDATE participants SET tier = CASE WHEN slot < 3 THEN 'MASTER' WHEN slot < 6 THEN 'EMERALD' ELSE 'PLATINUM' END");
    // An hour apart: the third set (a 30-day view's) from game 20, any patch; the last
    // two the rank filter's (EUW at Emerald+ and Master+)
    var each: [5]builds.Builder = undefined;
    const cube = try cubes.Store.open(gpa, io, try cubeDir(arena, dir, "each"));
    defer cube.deinit();
    _ = try cubes.buildsOf(cube, db, fixture_items, &build_data, o, &.{
        .{ .slice = .{ .platforms = &.{"EUW1"}, .patches = &.{patch} } },
        .{ .slice = .{ .platforms = both, .patches = &.{patch} } },
        .{ .slice = .{ .platforms = both, .since_ms = start_ms + 20 * std.time.ms_per_hour }, .matchups = false },
        .{ .slice = .{ .platforms = &.{"EUW1"}, .patches = &.{patch} }, .matchups = false, .min_tier = "EMERALD" },
        .{ .slice = .{ .platforms = &.{"EUW1"}, .patches = &.{patch} }, .matchups = false, .min_tier = "MASTER" },
    }, &each);
    defer for (&each) |*b| b.deinit();
    try testing.expectEqual(30, each[0].games);
    try testing.expectEqual(40, each[1].games);
    try testing.expectEqual(27, each[1].timelines);
    try testing.expectEqual(20, each[2].games);
    for (each[0..2], [_][]const []const u8{ &.{"EUW1"}, both }) |b, platforms| {
        var alone = try buildsOne(try cubeDir(arena, dir, "alone"), db, o, .{ .slice = .{ .platforms = platforms, .patches = &.{patch} } });
        defer alone.deinit();
        try testing.expectEqual(alone.games, b.games);
        try testing.expectEqual(alone.timelines, b.timelines);
        const a = try std.json.Stringify.valueAlloc(arena, try alone.file(arena, &build_data, patch, "", 10), .{});
        const e = try std.json.Stringify.valueAlloc(arena, try b.file(arena, &build_data, patch, "", 10), .{});
        try testing.expectEqualStrings(a, e);
    }
    // Each rank set as a run at that floor alone, without matchups
    for (each[3..], [_][]const u8{ "EMERALD", "MASTER" }, [_]u32{ 6, 3 }) |b, tier, per_game| {
        var alone = try buildsOne(try cubeDir(arena, dir, tier), db, .{ .min_tier = tier }, .{ .slice = .{ .platforms = &.{"EUW1"}, .patches = &.{patch} } });
        defer alone.deinit();
        const a = try std.json.Stringify.valueAlloc(arena, try alone.file(arena, &build_data, patch, tier, 10), .{});
        const f = try b.file(arena, &build_data, patch, tier, 10);
        try testing.expectEqualStrings(a, try std.json.Stringify.valueAlloc(arena, f, .{}));
        var players: u32 = 0;
        for (f.builds) |x| players += x.games;
        try testing.expectEqual(30 * per_game, players);
    }
    // `site --patch-games`, which the web loop decides on
    try testing.expectEqual(30, try stats.countGames(db, &.{patch}, &.{"EUW1"}));
    try testing.expectEqual(0, try stats.countGames(db, &.{"15.12"}, &.{"EUW1"}));
}

test "day cubes: days built again when their games change, as if built afresh" {
    const gpa = testing.allocator;
    const io = testing.io;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const db = try store.schema.memory();
    defer db.close();
    // An hour apart from start_ms (18:40 UTC): three UTC days
    try fillGames(arena, db, 40, true);
    try db.exec("UPDATE participants SET tier = CASE WHEN slot < 3 THEN 'MASTER' WHEN slot < 6 THEN 'EMERALD' ELSE 'PLATINUM' END");
    const cube = try cubes.Store.open(gpa, io, try std.fs.path.join(arena, &.{ ".zig-cache", "tmp", &tmp.sub_path, "cubes" }));
    defer cube.deinit();

    var n = try cube.refresh(db, start_ms, fixture_items);
    try testing.expectEqual(3, n.days);
    try testing.expectEqual(3, n.built);
    try testing.expectEqual(40, n.games_built);
    try expectCubesMatch(arena, io, db, cube, try std.fs.path.join(arena, &.{ ".zig-cache", "tmp", &tmp.sub_path, "fresh-first" }));
    n = try cube.refresh(db, start_ms, fixture_items);
    try testing.expectEqual(0, n.built);

    // A timeline gone, a new one, a game REPLACEd: their days, and in them only those
    // games; a day with no games left goes
    try db.exec("DELETE FROM timeline.timelines WHERE match_id = 'EUW1_2'");
    try db.exec("UPDATE timeline.timelines SET rowid = rowid + 1000 WHERE match_id = 'EUW1_5'");
    try db.exec("INSERT OR REPLACE INTO matches SELECT * FROM matches WHERE match_id = 'EUW1_30'");
    n = try cube.refresh(db, start_ms, fixture_items);
    try testing.expectEqual(2, n.built);
    try testing.expectEqual(3, n.games_built);
    try expectCubesMatch(arena, io, db, cube, try std.fs.path.join(arena, &.{ ".zig-cache", "tmp", &tmp.sub_path, "fresh-changed" }));
    try db.run("DELETE FROM matches WHERE game_start >= ?", .{start_ms + 30 * std.time.ms_per_hour});
    n = try cube.refresh(db, start_ms, fixture_items);
    try testing.expectEqual(1, n.dropped);
    const left = try cube.days(gpa, start_ms);
    defer gpa.free(left);
    try testing.expectEqual(2, left.len);
    try expectCubesMatch(arena, io, db, cube, try std.fs.path.join(arena, &.{ ".zig-cache", "tmp", &tmp.sub_path, "fresh-dropped" }));
    // Days before the window and older than keep_days go
    n = try cube.refresh(db, start_ms + std.time.ms_per_day, fixture_items);
    try testing.expectEqual(1, n.dropped);
}

test "day cubes: drop deletes every day, and a missing directory is fine" {
    const gpa = testing.allocator;
    const io = testing.io;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir = try std.fs.path.join(arena, &.{ ".zig-cache", "tmp", &tmp.sub_path, "cubes" });
    try cubes.drop(gpa, io, dir);
    try tmp.dir.createDirPath(io, "cubes/days");
    try tmp.dir.writeFile(io, .{ .sub_path = "cubes/days/20000.bin", .data = "x" });
    try cubes.drop(gpa, io, dir);
    const cube = try cubes.Store.open(gpa, io, dir);
    defer cube.deinit();
    const left = try cube.days(gpa, 0);
    defer gpa.free(left);
    try testing.expectEqual(0, left.len);
}

/// curves --site's and builds --site's sets from `cube`, current, as from a cube built
/// afresh in `fresh_dir`
fn expectCubesMatch(arena: std.mem.Allocator, io: std.Io, db: store.Db, cube: *cubes.Store, fresh_dir: []const u8) !void {
    const fresh = try cubes.Store.open(testing.allocator, io, fresh_dir);
    defer fresh.deinit();
    const gpa = testing.allocator;
    const both: []const []const u8 = &.{ "EUW1", "NA1" };
    const since = start_ms + 20 * std.time.ms_per_hour;
    const specs = [_]curves.Spec{
        .{ .chosen = &.{patch}, .since_ms = 0, .platforms = &.{"EUW1"} },
        .{ .chosen = &.{}, .since_ms = since, .platforms = both },
        .{ .chosen = &.{patch}, .since_ms = 0, .platforms = both },
    };
    var want: [specs.len]core.curvesfile.Builder = @splat(.{ .gpa = gpa });
    defer for (&want) |*b| b.deinit();
    var got: [specs.len]core.curvesfile.Builder = @splat(.{ .gpa = gpa });
    defer for (&got) |*b| b.deinit();
    var want_sum: [specs.len]curves.Summary = undefined;
    var got_sum: [specs.len]curves.Summary = undefined;
    _ = try cubes.curvesOf(fresh, db, fixture_items, &specs, &want, &want_sum);
    try testing.expectEqual(0, (try cubes.curvesOf(cube, db, fixture_items, &specs, &got, &got_sum)).built);
    for (&want, &got, want_sum, got_sum) |*a, *b, x, y| {
        try testing.expectEqual(x, y);
        try testing.expect(x.games > 0);
        var wa: std.Io.Writer.Allocating = .init(arena);
        try a.write(&wa.writer, patch, 1);
        var wb: std.Io.Writer.Allocating = .init(arena);
        try b.write(&wb.writer, patch, 1);
        try testing.expectEqualSlices(u8, wa.written(), wb.written());
    }

    const o: builds.Options = .{ .min_matchup_games = 0 };
    const sets = [_]builds.Set{
        .{ .slice = .{ .platforms = &.{"EUW1"}, .patches = &.{patch} } },
        .{ .slice = .{ .platforms = both, .patches = &.{patch} } },
        .{ .slice = .{ .platforms = both, .since_ms = since }, .matchups = false },
        .{ .slice = .{ .platforms = &.{"EUW1"}, .patches = &.{patch} }, .matchups = false, .min_tier = "EMERALD" },
        .{ .slice = .{ .platforms = both, .since_ms = since }, .matchups = false, .min_tier = "MASTER" },
    };
    var bw: [sets.len]builds.Builder = undefined;
    _ = try cubes.buildsOf(fresh, db, fixture_items, &build_data, o, &sets, &bw);
    defer for (&bw) |*b| b.deinit();
    var bg: [sets.len]builds.Builder = undefined;
    try testing.expectEqual(0, (try cubes.buildsOf(cube, db, fixture_items, &build_data, o, &sets, &bg)).built);
    defer for (&bg) |*b| b.deinit();
    for (&bw, &bg, sets) |*a, *b, set| {
        try testing.expectEqual(a.games, b.games);
        try testing.expectEqual(a.timelines, b.timelines);
        const tier = set.min_tier orelse "PLATINUM";
        const fa = try std.json.Stringify.valueAlloc(arena, try a.file(arena, &build_data, patch, tier, 10), .{});
        const fb = try std.json.Stringify.valueAlloc(arena, try b.file(arena, &build_data, patch, tier, 10), .{});
        try testing.expectEqualStrings(fa, fb);
    }
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

/// An old page path's new URL (docs/plan/urls.md) parses back as the same kind of page:
/// a champion page stays a champion, never a role list
/// File `path` is a page (its URL parses back) and every href in it is a page's URL, a
/// file (asset, data), a fragment or external: a relative or misspelt link fails
fn expectPageLinks(arena: std.mem.Allocator, path: []const u8, page: []const u8) !void {
    const url = try site.urlOf(arena, path);
    if (ui.urls.parse(url[0 .. std.mem.findScalar(u8, url, '?') orelse url.len]) == null) {
        std.debug.print("{s}: URL {s} isn't a page\n", .{ path, url });
        return error.TestUnexpectedResult;
    }
    var it = std.mem.splitSequence(u8, page, "href=\"");
    _ = it.next();
    while (it.next()) |rest| {
        const href = rest[0 .. std.mem.findScalar(u8, rest, '"') orelse rest.len];
        if (href.len == 0 or href[0] == '#') continue;
        if (std.mem.startsWith(u8, href, "https://") or std.mem.startsWith(u8, href, "http://") or std.mem.startsWith(u8, href, "mailto:")) continue;
        const end = std.mem.findAny(u8, href, "?#") orelse href.len;
        const bare = href[0..end];
        const last = bare[(std.mem.findScalarLast(u8, bare, '/') orelse 0)..];
        const file = std.mem.findScalar(u8, last, '.') != null;
        if (bare.len > 0 and bare[0] == '/' and (file or ui.urls.parse(bare) != null)) continue;
        std.debug.print("{s}: href {s} is neither a page's URL nor a file\n", .{ path, href });
        return error.TestUnexpectedResult;
    }
}

/// Every generated file's hash, against src/testdata/site-files.txt: a refactor that
/// claims the same output shows it, and a change on purpose shows which files it moved.
/// Assets copied from static/ or compiled (wasm) are left out
/// Every file under `want` in `got` with the same bytes, and no others
fn expectSameTree(arena: std.mem.Allocator, io: std.Io, want: []const u8, got: []const u8) !void {
    var want_dir = try std.Io.Dir.cwd().openDir(io, want, .{ .iterate = true });
    defer want_dir.close(io);
    var got_dir = try std.Io.Dir.cwd().openDir(io, got, .{ .iterate = true });
    defer got_dir.close(io);
    var counts: [2]usize = .{ 0, 0 };
    for ([_]std.Io.Dir{ want_dir, got_dir }, &counts) |d, *count| {
        var walker = try d.walk(arena);
        defer walker.deinit();
        while (try walker.next(io)) |e| if (e.kind == .file) {
            count.* += 1;
        };
    }
    try testing.expectEqual(counts[0], counts[1]);
    var walker = try want_dir.walk(arena);
    defer walker.deinit();
    while (try walker.next(io)) |e| {
        if (e.kind != .file) continue;
        const a = try want_dir.readFileAlloc(io, e.path, arena, .limited(1 << 26));
        const b = got_dir.readFileAlloc(io, e.path, arena, .limited(1 << 26)) catch |err| {
            std.debug.print("{s}: {t}\n", .{ e.path, err });
            return err;
        };
        if (!std.mem.eql(u8, a, b)) {
            std.debug.print("differs: {s}\n", .{e.path});
            return error.TestUnexpectedResult;
        }
    }
}

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
    // Read, not embedded: build.zig siteFiles
    const want = try std.Io.Dir.cwd().readFileAlloc(io, "src/testdata/site-files.txt", arena, .limited(1 << 20));
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

/// The views file at `from` to `to`, the root view's patch day (Part.prev) with Darius
/// top up from 45% to 56% over 1,000 games each patch
fn withClearMove(arena: std.mem.Allocator, io: std.Io, from: []const u8, to: []const u8) !void {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, from, arena, .limited(1 << 30));
    // After the magic and format: part tag, view, key, length, data
    var at: usize = 16;
    const prev_tag = 5;
    while (bytes[at] != prev_tag or bytes[at + 1] != 0) {
        at += 18 + std.mem.readInt(u64, bytes[at + 10 ..][0..8], .little);
    }
    const len = std.mem.readInt(u64, bytes[at + 10 ..][0..8], .little);
    var r: std.Io.Reader = .fixed(bytes[at + 18 ..][0..len]);
    var wins = try flat.read(patchday.Wins, &r, arena);
    const moved = [_]patchday.ChampionMove{.{ .id = 122, .role = .top, .win = .of(.{ .games = 1000, .wins = 450 }, .{ .games = 1000, .wins = 560 }) }};
    wins.champions = try std.mem.concat(arena, patchday.ChampionMove, &.{ wins.champions, &moved });
    var part: std.Io.Writer.Allocating = .init(arena);
    try flat.write(&part.writer, wins);
    var out: std.Io.Writer.Allocating = .init(arena);
    try out.writer.writeAll(bytes[0 .. at + 10]);
    try out.writer.writeInt(u64, part.written().len, .little);
    try out.writer.writeAll(part.written());
    try out.writer.writeAll(bytes[at + 18 + len ..]);
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = to, .data = out.written() });
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
/// A day cube directory of its own under `dir`: tests change rows in place, which a
/// cube's day signature does not see
fn cubeDir(arena: std.mem.Allocator, dir: []const u8, tag: []const u8) ![]const u8 {
    return std.fs.path.join(arena, &.{ dir, "cubes", tag });
}

/// The fixture's Data Dragon data for every patch
const fixture_items: cubes.Items = .{ .ctx = @ptrCast(@constCast(&build_data)), .get = struct {
    fn f(_: *anyopaque, _: []const u8) anyerror!*const ddragon.BuildData {
        return &build_data;
    }
}.f };

/// One curves file, through a day cube in `dir`
fn curvesOne(dir: []const u8, db: store.Db, spec: curves.Spec) !struct { builder: core.curvesfile.Builder, summary: curves.Summary } {
    const gpa = testing.allocator;
    const cube = try cubes.Store.open(gpa, testing.io, dir);
    defer cube.deinit();
    var b: [1]core.curvesfile.Builder = .{.{ .gpa = gpa }};
    errdefer b[0].deinit();
    var sum: [1]curves.Summary = undefined;
    _ = try cubes.curvesOf(cube, db, fixture_items, &.{spec}, &b, &sum);
    return .{ .builder = b[0], .summary = sum[0] };
}

/// One builds file, through a day cube in `dir`
fn buildsOne(dir: []const u8, db: store.Db, o: builds.Options, set: builds.Set) !builds.Builder {
    const gpa = testing.allocator;
    const cube = try cubes.Store.open(gpa, testing.io, dir);
    defer cube.deinit();
    var b: [1]builds.Builder = undefined;
    _ = try cubes.buildsOf(cube, db, fixture_items, &build_data, o, &.{set}, &b);
    return b[0];
}

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
    // The fixture's champions: Twitch, Amumu, Orianna, Lee Sin, Mordekaiser, Ahri, Darius,
    // Kai'Sa, Rakan, Pyke
    .ranges = &.{ .{ 29, 550 }, .{ 32, 125 }, .{ 61, 525 }, .{ 64, 125 }, .{ 82, 175 }, .{ 103, 550 }, .{ 122, 175 }, .{ 145, 525 }, .{ 497, 300 }, .{ 555, 150 } },
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
    return fillOn(arena, db, prev_patch, 1, 2000);
}

/// The fixture game `games` times on `p`, `days` before start_ms, match ids from `first`
fn fillOn(arena: std.mem.Allocator, db: store.Db, p: []const u8, days: i64, first: usize) !void {
    const body = @embedFile("riot/testdata/match.json");
    const json = try store.raw.decompress(arena, @embedFile("riot/testdata/timeline.json.gz"));
    const ct = try riot.crawl.compactTimeline(arena, json);
    for (0..games) |n| {
        var doc = try riot.match.parse(arena, body);
        doc.metadata.matchId = try arena.print("EUW1_{d}", .{first + n});
        doc.info.platformId = "EUW1";
        doc.info.gameVersion = try arena.print("{s}.1.1", .{p});
        doc.info.gameStartTimestamp = start_ms - days * std.time.ms_per_day;
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

/// An island root's data-bin in `page`: as written, and decoded
fn dataBin(a: std.mem.Allocator, page: []const u8, island: []const u8) !struct { []const u8, []u8 } {
    const key = try std.fmt.allocPrint(a, "data-island=\"{s}\" data-bin=\"", .{island});
    const at = (std.mem.find(u8, page, key) orelse return error.NoIsland) + key.len;
    const s = page[at .. std.mem.findScalarPos(u8, page, at, '"') orelse return error.NoIsland];
    const d = std.base64.standard.Decoder;
    const out = try a.alloc(u8, try d.calcSizeForSlice(s));
    try d.decode(out, s);
    return .{ s, out };
}
