//! `meiolol curves`, `builds`, `pool`, `lean`, `draft-model`, `lane-model`: the files the site
//! and the admin tester read

const std = @import("std");
const core = @import("core");
const riot = @import("../riot/root.zig");
const ddragon = @import("../ddragon.zig");
const stats = @import("../stats.zig");
const curves = @import("../curves.zig");
const builds = @import("../builds.zig");
const pool = @import("../pool.zig");
const lean = @import("../lean.zig");
const draftmodel = @import("../draftmodel.zig");
const lanemodel = @import("../lanemodel.zig");
const analysis = @import("../analysis.zig");
const main = @import("../main.zig");
const Cmd = main.Cmd;
const Games = main.Games;
const curvesPath = main.curvesPath;
const recentCurvesPath = main.recentCurvesPath;
const buildsPath = main.buildsPath;
const newestPatch = main.newestPatch;

pub const usage_curves =
    \\  curves      write lane matchup curves from match timelines (curvesfile.zig)
    \\              --patch P        as for stats (default: every patch of the last
    \\                               --days, to DIR/export/recent-curves.bin)
    \\              --days N         default 30
    \\              --platform P     as for stats
    \\              --out FILE       default DIR/export/curves-<patch>.bin (all-curves-...
    \\                               and all-recent-curves.bin with --platform all)
    \\              --min-games N    leave out matchups with fewer games (default 10;
    \\                               the fit still uses every game)
    \\              --site           the files the site reads, in one pass over the
    \\                               timelines: EUW and every platform, last --days
    \\                               and (with --patch) that patch, default paths
    \\              --format-version print the file format version this binary writes
    \\                               and reads, then exit (deploy/web-loop.sh)
    \\
;

pub fn cmdCurves(c: *Cmd) !u8 {
    var g: Games = .{};
    var out: ?[]const u8 = null;
    var days: u32 = 30;
    // Thinner curves were 71% of the file (16.20) and their spreads are noise; readers
    // need 10 games at a minute anyway, and fall back to all ranks or the plain average
    var min_games: u32 = 10;
    var site_files = false;
    while (c.next()) |_| {
        if (try g.parse(c)) continue;
        if (c.is("--out")) {
            out = try c.value();
        } else if (c.is("--days")) {
            days = try c.int(u32);
        } else if (c.is("--min-games")) {
            min_games = try c.int(u32);
        } else if (c.is("--site")) {
            site_files = true;
        } else if (c.is("--format-version")) {
            var buf: [16]u8 = undefined;
            var stdout = std.Io.File.stdout().writer(c.init.io, &buf);
            try stdout.interface.print("{d}\n", .{core.curvesfile.version});
            try stdout.interface.flush();
            return 0;
        } else return error.Usage;
    }
    if (site_files and (out != null or g.platforms.items.len > 0)) return error.Usage;
    const gpa = c.init.gpa;
    const io = c.init.io;
    const arena = c.arena;
    const db = try c.open();
    defer db.close();
    const wanted = g.patches.items;
    const now_ms = std.Io.Clock.real.now(io).toMilliseconds();
    const recent_ms = now_ms - @as(i64, days) * std.time.ms_per_day;
    var label_buf: [core.statsfile.patch_len]u8 = undefined;
    const recent_label = try arena.print("last {d} days", .{days});
    const patch_label = if (wanted.len > 0) try arena.dupe(u8, try stats.label(&label_buf, wanted)) else "";

    const File = struct { spec: curves.Spec, label: []const u8, path: []const u8 };
    var files: std.ArrayList(File) = .empty;
    if (site_files) {
        var every: std.ArrayList([]const u8) = .empty;
        for (riot.endpoints.platforms) |pl| try every.append(arena, pl.id);
        for ([_]bool{ false, true }) |all| {
            const platforms: []const []const u8 = if (all) every.items else &.{"EUW1"};
            try files.append(arena, .{
                .spec = .{ .chosen = &.{}, .since_ms = recent_ms, .platforms = platforms },
                .label = recent_label,
                .path = try recentCurvesPath(arena, c.data_dir, all),
            });
            if (wanted.len > 0) try files.append(arena, .{
                .spec = .{ .chosen = wanted, .since_ms = 0, .platforms = platforms },
                .label = patch_label,
                .path = try curvesPath(arena, c.data_dir, wanted, all),
            });
        }
    } else {
        const path = out orelse if (wanted.len > 0)
            try curvesPath(arena, c.data_dir, wanted, g.every_platform)
        else
            try recentCurvesPath(arena, c.data_dir, g.every_platform);
        try files.append(arena, .{
            .spec = .{
                .chosen = wanted,
                .since_ms = if (wanted.len > 0) 0 else recent_ms,
                .platforms = g.platformIds(),
            },
            .label = if (wanted.len > 0) patch_label else recent_label,
            .path = path,
        });
    }
    // --site: EUW's patch for every file, so EUW's files match a run of their own
    const item_patch = if (wanted.len > 0)
        wanted[0]
    else
        (try newestPatch(arena, db, if (site_files) &.{"EUW1"} else g.platformIds()))[0];

    const legendaries = ddragon.legendaries(gpa, io, item_patch) catch |err| blk: {
        std.log.warn("no item list from Data Dragon ({t}): curves without first items", .{err});
        break :blk &.{};
    };
    defer gpa.free(legendaries);
    const specs = try arena.alloc(curves.Spec, files.items.len);
    for (files.items, specs) |f, *s| s.* = f.spec;
    const builders = try arena.alloc(core.curvesfile.Builder, files.items.len);
    @memset(builders, .{ .gpa = gpa });
    defer for (builders) |*b| b.deinit();
    const summaries = try arena.alloc(curves.Summary, files.items.len);
    try curves.buildMany(gpa, io, db, specs, legendaries, builders, summaries);

    var missing = false;
    for (files.items, builders, summaries) |f, *b, sum| {
        if (sum.games == 0) {
            std.log.err("no ranked solo games with timelines for {s}: {s}", .{ f.label, f.path });
            missing = true;
            continue;
        }
        var file = try std.Io.Dir.cwd().createFileAtomic(io, f.path, .{ .make_path = true, .replace = true });
        defer file.deinit(io);
        var buf: [64 * 1024]u8 = undefined;
        var w = file.file.writer(io, &buf);
        try b.write(&w.interface, f.label, min_games);
        try w.interface.flush();
        try file.replace(io);
        std.log.info("{s}: {s}, {d} games ({d} skipped)", .{ f.path, f.label, sum.games, sum.skipped });
        // Freed as it goes: the next file's fit needs the room
        b.deinit();
        b.* = .{ .gpa = gpa };
    }
    if (missing) return error.NoMatches;
    return 0;
}

pub const usage_builds =
    \\  builds      write what players build per champion and role (builds.zig): runes,
    \\              summoner spells, starting items, boots, first items, skill order;
    \\              per lane opponent too (300+ games); JSON the site reads (needs
    \\              Data Dragon)
    \\              --patch P        as for stats (default: the newest patch)
    \\              --platform P     as for stats
    \\              --min-tier T     lowest rank counted, per player (default PLATINUM;
    \\                               "any" counts everyone, unranked too)
    \\              --max-keys N     distinct options held in memory (default 524288)
    \\              --max-matchup-keys N  the same per lane opponent (default 1048576)
    \\              --out FILE       default DIR/export/builds-<patch>.json
    \\                               (all-builds-... with --platform all)
    \\              --site           the files the site reads, in one pass over the
    \\                               timelines: EUW and every platform, default paths
    \\
;

pub fn cmdBuilds(c: *Cmd) !u8 {
    var g: Games = .{};
    var out: ?[]const u8 = null;
    var site_files = false;
    var o: builds.Options = .{ .patches = &.{}, .platforms = &.{}, .min_matchup_games = builds.min_matchup_games };
    while (c.next()) |_| {
        if (try g.parse(c)) continue;
        if (c.is("--out")) {
            out = try c.value();
        } else if (c.is("--min-tier")) {
            const t = try c.value();
            o.min_tier = if (std.mem.eql(u8, t, "any")) null else t;
        } else if (c.is("--max-keys")) {
            o.max_keys = try c.int(usize);
        } else if (c.is("--max-matchup-keys")) {
            o.max_matchup_keys = try c.int(usize);
        } else if (c.is("--site")) {
            site_files = true;
        } else return error.Usage;
    }
    if (site_files and (out != null or g.platforms.items.len > 0)) return error.Usage;
    const gpa = c.init.gpa;
    const io = c.init.io;
    const db = try c.open();
    defer db.close();
    var every: std.ArrayList([]const u8) = .empty;
    for (riot.endpoints.platforms) |pl| try every.append(c.arena, pl.id);
    o.platforms = if (site_files) every.items else g.platformIds();
    o.patches = if (g.patches.items.len > 0) g.patches.items else try newestPatch(c.arena, db, if (site_files) &.{"EUW1"} else o.platforms);
    var label_buf: [core.statsfile.patch_len]u8 = undefined;
    const label = try stats.label(&label_buf, o.patches);
    const Target = struct { platforms: []const []const u8, path: []const u8 };
    const targets: []const Target = if (site_files) &.{
        .{ .platforms = &.{"EUW1"}, .path = try buildsPath(c.arena, c.data_dir, o.patches, false) },
        .{ .platforms = every.items, .path = try buildsPath(c.arena, c.data_dir, o.patches, true) },
    } else &.{
        .{ .platforms = o.platforms, .path = out orelse try buildsPath(c.arena, c.data_dir, o.patches, g.every_platform) },
    };
    const data = try ddragon.buildData(gpa, c.arena, io, o.patches[0]);

    var sets: [2][]const []const u8 = undefined;
    for (targets, 0..) |t, i| sets[i] = t.platforms;
    var bs: [2]builds.Builder = undefined;
    try builds.buildEach(gpa, io, db, &data, o, sets[0..targets.len], bs[0..targets.len]);
    defer for (bs[0..targets.len]) |*b| b.deinit();
    for (targets, bs[0..targets.len]) |t, *b| {
        if (b.games == 0) {
            std.log.err("{s}: no ranked solo games on patch {s}", .{ t.path, label });
            return error.NoMatches;
        }
        const f = try b.file(c.arena, &data, label, o.min_tier orelse "", o.rows);
        var file = try std.Io.Dir.cwd().createFileAtomic(io, t.path, .{ .make_path = true, .replace = true });
        defer file.deinit(io);
        var buf: [64 * 1024]u8 = undefined;
        var w = file.file.writer(io, &buf);
        try std.json.Stringify.value(f, .{}, &w.interface);
        try w.interface.flush();
        try file.replace(io);
        std.log.info("{s}: patch {s}, {d} games ({d} with timelines), {d} champion roles, {d} options held, {d} matchups, {d} matchup options held", .{
            t.path, label, b.games, b.timelines, f.builds.len, b.options.count(), f.matchups.len, if (b.vs) |v| v.options.count() else 0,
        });
    }
    return 0;
}

pub const usage_pool =
    \\  pool        write what players of each champion also play (pool.zig), as JSON
    \\              --patch P        as for stats (matchups); pools use every patch
    \\              --platform P     as for stats
    \\              --out FILE       default DIR/export/pool.json
    \\
;

pub fn cmdPool(c: *Cmd) !u8 {
    var g: Games = .{};
    var out: ?[]const u8 = null;
    while (c.next()) |_| {
        if (try g.parse(c)) continue;
        if (c.is("--out")) out = try c.value() else return error.Usage;
    }
    const gpa = c.init.gpa;
    const io = c.init.io;
    const arena = c.arena;
    const db = try c.open();
    defer db.close();
    const platforms = g.platformIds();
    const chosen = if (g.patches.items.len > 0) g.patches.items else try newestPatch(arena, db, platforms);
    var r = try stats.build(gpa, db, chosen, platforms);
    defer r.builder.deinit();
    var label_buf: [core.statsfile.patch_len]u8 = undefined;
    var model: std.Io.Writer.Allocating = .init(arena);
    try r.builder.write(&model.writer, try stats.label(&label_buf, chosen));
    const st: core.Stats = try .parse(arena, model.written());
    var t = try pool.tally(gpa, db, &st, &.{platforms});
    defer t.deinit(gpa);
    const p = try pool.make(arena, &t, 0, &st, .{});

    const path = out orelse try std.fs.path.join(arena, &.{ c.data_dir, "export", "pool.json" });
    var file = try std.Io.Dir.cwd().createFileAtomic(io, path, .{ .make_path = true, .replace = true });
    defer file.deinit(io);
    var buf: [64 * 1024]u8 = undefined;
    var w = file.file.writer(io, &buf);
    try pool.writeJson(&w.interface, p);
    try w.interface.flush();
    try file.replace(io);
    std.log.info("{s}", .{path});
    return 0;
}

pub const usage_lean =
    \\  lean        early or late: each champion-role's team gold lead at 14 min and its
    \\              win from an even game at 20 min, shrunk (docs/model.md "Early and late
    \\              champions"); the champion pages' line. Writes DATA/lean.tsv
    \\              --platform P     default all; --days N  games of the last N (30)
    \\              --out FILE       instead of DATA/lean.tsv
    \\              --check          lab: folds and dev-val (markdown on stdout), no test
    \\              --cuts A,B,C,D,E,DEV,TEST  as carry's; --table FILE  dev fit's rows
    \\
;

pub fn cmdLean(c: *Cmd) !u8 {
    var g: Games = .{};
    var out: ?[]const u8 = null;
    var days: u32 = 30;
    var check = false;
    var cuts: ?lean.Cuts = null;
    var table: ?[]const u8 = null;
    var prior_rows: f64 = lean.default_prior_rows;
    while (c.next()) |_| {
        if (try g.parse(c)) continue;
        if (c.is("--out")) {
            out = try c.value();
        } else if (c.is("--prior-rows")) {
            prior_rows = try c.float();
        } else if (c.is("--days")) {
            days = try c.int(u32);
        } else if (c.is("--check")) {
            check = true;
        } else if (c.is("--cuts")) {
            var x: lean.Cuts = undefined;
            var it = std.mem.splitScalar(u8, try c.value(), ',');
            for (&x) |*v| v.* = std.fmt.parseInt(i64, it.next() orelse return error.Usage, 10) catch return error.Usage;
            if (it.next() != null) return error.Usage;
            cuts = x;
        } else if (c.is("--table")) {
            table = try c.value();
        } else return error.Usage;
    }
    const gpa = c.init.gpa;
    const io = c.init.io;
    const db = try c.open();
    defer db.close();
    var every: std.ArrayList([]const u8) = .empty;
    for (riot.endpoints.platforms) |pl| try every.append(c.arena, pl.id);
    const platforms = if (g.platforms.items.len > 0) g.platforms.items else every.items;
    const all_regions = g.platforms.items.len == 0 or g.every_platform;
    const chosen = if (g.patches.items.len > 0) g.patches.items else try stats.patches(c.arena, db, platforms);
    if (check) {
        const x = cuts orelse lean.labCuts(try analysis.protocolCuts(gpa, db));
        var buf: [64 * 1024]u8 = undefined;
        var stdout = std.Io.File.stdout().writer(io, &buf);
        try lean.check(gpa, io, db, chosen, platforms, x, table, prior_rows, &stdout.interface);
        try stdout.interface.flush();
        return 0;
    }
    const now_ms = std.Io.Clock.real.now(io).toMilliseconds();
    const since_ms = if (g.patches.items.len > 0) 0 else now_ms - @as(i64, days) * std.time.ms_per_day;
    var games = try lean.load(gpa, io, db, chosen, platforms, since_ms, std.math.maxInt(i64));
    defer games.deinit(gpa);
    if (games.list.items.len == 0) {
        std.log.err("lean: no games with a timeline", .{});
        return error.NoMatches;
    }
    var f = try lean.fit(gpa, games.list.items, games.champs.ids.items.len);
    defer f.deinit(gpa);
    const path = out orelse try std.fs.path.join(c.arena, &.{ c.data_dir, "lean.tsv" });
    var file = try std.Io.Dir.cwd().createFileAtomic(io, path, .{ .make_path = true, .replace = true });
    defer file.deinit(io);
    var buf: [64 * 1024]u8 = undefined;
    var w = file.file.writer(io, &buf);
    const where = if (all_regions) "every region" else try std.mem.join(c.arena, ", ", platforms);
    var label_buf: [core.statsfile.patch_len]u8 = undefined;
    const scope = if (g.patches.items.len > 0)
        try c.arena.print("{s}, patch {s}", .{ where, try stats.label(&label_buf, chosen) })
    else
        try c.arena.print("{s}, last {d} days", .{ where, days });
    try lean.write(&w.interface, &f, games.champs.ids.items, games.list.items, scope);
    try w.interface.flush();
    try file.replace(io);
    std.log.info("{s}: {d} games, {s}", .{ path, games.list.items.len, scope });
    return 0;
}

pub const usage_draft_model =
    \\  draft-model the shipped draft model on every played game as the admin Draft
    \\              tester's draft-model.json and draft-ref.json (docs/model.md "Draft model
    \\              file"); daily on the box
    \\              --out DIR        default DATA/tester
    \\
;

pub fn cmdDraftModel(c: *Cmd) !u8 {
    return testerModel(c, draftmodel.run);
}

pub const usage_lane_model =
    \\  lane-model  the Draft tester's lane model (lab candidate team2: gold at 14, lane gold,
    \\              CS at 10, deaths before 15 for a champion into a lane opponent) on every
    \\              played game, as lane-model.json and lane-ref.json; daily on the box
    \\              --out DIR        default DATA/tester
    \\
;

pub fn cmdLaneModel(c: *Cmd) !u8 {
    return testerModel(c, lanemodel.run);
}

/// `draft-model` and `lane-model`: --out DIR (default DATA/tester), a log on stdout
fn testerModel(c: *Cmd, comptime run: anytype) !u8 {
    var out: ?[]const u8 = null;
    while (c.next()) |_| {
        if (c.is("--out")) {
            out = try c.value();
        } else return error.Usage;
    }
    const io = c.init.io;
    const db = try c.open();
    defer db.close();
    var buf: [4096]u8 = undefined;
    // Streaming: the web loop logs both commands to one file, which positional writes
    // would overwrite from the start
    var stdout = std.Io.File.stdout().writerStreaming(io, &buf);
    defer stdout.interface.flush() catch {};
    try run(c.init.gpa, io, db, out orelse try std.fs.path.join(c.arena, &.{ c.data_dir, "tester" }), &stdout.interface);
    return 0;
}
