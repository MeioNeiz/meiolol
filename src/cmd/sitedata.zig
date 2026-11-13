//! `meiolol curves`, `builds`, `lean`, `draft-model`, `lane-model`: the files the site and
//! the admin tester read

const std = @import("std");
const core = @import("core");
const ddragon = @import("../ddragon.zig");
const stats = @import("../stats.zig");
const curves = @import("../curves.zig");
const builds = @import("../builds.zig");
const cubes = @import("../cubes.zig");
const lockrows = @import("../lockrows.zig");
const lockanswer = @import("../lockanswer.zig");
const meio = @import("../meio.zig");
const truth = @import("../truth.zig");
const lean = @import("../lean.zig");
const pairlane = @import("../pairlane.zig");
const draftmodel = @import("../draftmodel.zig");
const testerbin = @import("../testerbin.zig");
const lanemodel = @import("../lanemodel.zig");
const analysis = @import("../analysis.zig");
const main = @import("../main.zig");
const platform_ids = main.riot.endpoints.platform_ids;
const Cmd = main.Cmd;
const Games = main.Games;
const curvesPath = main.curvesPath;
const recentCurvesPath = main.recentCurvesPath;
const buildsPath = main.buildsPath;
const recentBuildsPath = main.recentBuildsPath;
const recent_days = main.recent_days;
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
    \\                               day cubes: EUW and every platform, last --days
    \\                               and (with --patch) that patch, default paths
    \\                               (a day but today built in the last 6 h is
    \\                               read as it is)
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
        for ([_]bool{ false, true }) |all| {
            const platforms: []const []const u8 = if (all) platform_ids else &.{"EUW1"};
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
    const specs = try arena.alloc(curves.Spec, files.items.len);
    for (files.items, specs) |f, *s| s.* = f.spec;
    const builders = try arena.alloc(core.curvesfile.Builder, files.items.len);
    @memset(builders, .{ .gpa = gpa });
    defer for (builders) |*b| b.deinit();
    const summaries = try arena.alloc(curves.Summary, files.items.len);
    {
        var items: CubeItems = .{ .gpa = gpa, .arena = arena, .io = io };
        const cube = try cubes.Store.open(gpa, io, try cubes.dirIn(arena, c.data_dir));
        defer cube.deinit();
        // Each round's late games wait up to 6 h (docs/arch-stats.md), but today's
        if (site_files) {
            cube.settle_ms = 6 * std.time.ms_per_hour;
            cube.fresh_days = 1;
        }
        (try cubes.curvesOf(cube, db, items.source(), specs, builders, summaries)).report();
    }

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

pub const usage_pairlane =
    \\  pairlane    write bot lanes as pairs, ADC and support against the enemy pair
    \\              (pairlane.zig), from the day cubes: EUW and every platform, last
    \\              --days, to DIR/export/{,all-}recent-pairlane.bin
    \\              --days N         default 30
    \\              --min-games N    leave out cells with fewer games (default 10)
    \\
;

pub fn cmdPairlane(c: *Cmd) !u8 {
    var days: u32 = recent_days;
    var min_games: u32 = 10;
    while (c.next()) |_| {
        if (c.is("--days")) {
            days = try c.int(u32);
        } else if (c.is("--min-games")) {
            min_games = try c.int(u32);
        } else return error.Usage;
    }
    const gpa = c.init.gpa;
    const io = c.init.io;
    const arena = c.arena;
    const db = try c.open();
    defer db.close();
    const now_ms = std.Io.Clock.real.now(io).toMilliseconds();
    const since_ms = now_ms - @as(i64, days) * std.time.ms_per_day;
    const label = try arena.print("last {d} days", .{days});
    var specs: [2]curves.Spec = undefined;
    var paths: [2][]const u8 = undefined;
    for ([_]bool{ false, true }, &specs, &paths) |all, *s, *p| {
        s.* = .{ .chosen = &.{}, .since_ms = since_ms, .platforms = if (all) platform_ids else &.{"EUW1"} };
        p.* = try arena.print("{s}/export/{s}recent-pairlane.bin", .{ c.data_dir, if (all) "all-" else "" });
    }
    var builders: [2]pairlane.Builder = @splat(.{ .gpa = gpa });
    defer for (&builders) |*b| b.deinit();
    {
        var items: CubeItems = .{ .gpa = gpa, .arena = arena, .io = io };
        const cube = try cubes.Store.open(gpa, io, try cubes.dirIn(arena, c.data_dir));
        defer cube.deinit();
        (try pairlane.fromCubes(cube, db, items.source(), &specs, &builders)).report();
    }
    for (paths, &builders) |path, *b| {
        if (b.games == 0) {
            std.log.err("no ranked solo games with timelines for {s}: {s}", .{ label, path });
            return error.NoMatches;
        }
        var file = try std.Io.Dir.cwd().createFileAtomic(io, path, .{ .make_path = true, .replace = true });
        defer file.deinit(io);
        var buf: [64 * 1024]u8 = undefined;
        var w = file.file.writer(io, &buf);
        try b.write(&w.interface, label, min_games);
        try w.interface.flush();
        try file.replace(io);
        std.log.info("{s}: {s}, {d} games, {d} cells", .{ path, label, b.games, b.cells.count() });
    }
    return 0;
}

pub const usage_builds =
    \\  builds      write what players build per champion and role (builds.zig): runes,
    \\              summoner spells, starting items, boots, finished items 1 to 6
    \\              with the minute bought, skill order and path to 18;
    \\              per lane opponent too (300+ games); JSON the site reads (needs
    \\              Data Dragon)
    \\              --patch P        as for stats (default: the newest patch)
    \\              --platform P     as for stats
    \\              --min-tier T     lowest rank counted, per player (default PLATINUM;
    \\                               "any" counts everyone, unranked too)
    \\              --max-keys N     distinct options held in memory (default 1048576)
    \\              --max-matchup-keys N  the same per lane opponent (default 4194304)
    \\              --out FILE       default DIR/export/builds-<patch>.json
    \\                               (all-builds-... with --platform all)
    \\              --site           the files the site reads, in one pass over the
    \\                               day cubes: EUW and every platform, the patch and
    \\                               the last 30 days (no matchups), default paths;
    \\                               each again at Emerald+, Diamond+ and Master+
    \\                               (builds-16.21-emerald.json, no matchups)
    \\
;

pub fn cmdBuilds(c: *Cmd) !u8 {
    var g: Games = .{};
    var out: ?[]const u8 = null;
    var site_files = false;
    var o: builds.Options = .{ .min_matchup_games = builds.min_matchup_games };
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
    const every = platform_ids;
    const platforms = if (site_files) every else g.platformIds();
    const patches = if (g.patches.items.len > 0) g.patches.items else try newestPatch(c.arena, db, if (site_files) &.{"EUW1"} else platforms);
    var label_buf: [core.statsfile.patch_len]u8 = undefined;
    const label = try stats.label(&label_buf, patches);
    const recent_ms = std.Io.Clock.real.now(io).toMilliseconds() - recent_days * std.time.ms_per_day;
    const recent_label = std.fmt.comptimePrint("last {d} days", .{recent_days});
    const Target = struct { set: builds.Set, label: []const u8, path: []const u8 };
    const views: []const Target = if (site_files) &.{
        .{ .set = .{ .slice = .{ .platforms = &.{"EUW1"}, .patches = patches } }, .label = label, .path = try buildsPath(c.arena, c.data_dir, patches, false) },
        .{ .set = .{ .slice = .{ .platforms = every, .patches = patches } }, .label = label, .path = try buildsPath(c.arena, c.data_dir, patches, true) },
        // The champion pages' 30-day views; matchup pages show the patch's
        .{ .set = .{ .slice = .{ .platforms = &.{"EUW1"}, .since_ms = recent_ms }, .matchups = false }, .label = recent_label, .path = try recentBuildsPath(c.arena, c.data_dir, false) },
        .{ .set = .{ .slice = .{ .platforms = every, .since_ms = recent_ms }, .matchups = false }, .label = recent_label, .path = try recentBuildsPath(c.arena, c.data_dir, true) },
    } else &.{
        .{ .set = .{ .slice = .{ .platforms = platforms, .patches = patches } }, .label = label, .path = out orelse try buildsPath(c.arena, c.data_dir, patches, g.every_platform) },
    };
    // The site's views again at each higher rank filter, no matchups (rank_tiers)
    var all_targets: std.ArrayList(Target) = .empty;
    try all_targets.appendSlice(c.arena, views);
    if (site_files) for (builds.rank_tiers) |tier| for (views) |v| {
        var set = v.set;
        set.matchups = false;
        set.min_tier = tier;
        try all_targets.append(c.arena, .{ .set = set, .label = v.label, .path = try main.rankBuildsPath(c.arena, v.path, tier) });
    };
    const targets = all_targets.items;
    // Names and icons from the patch's Data Dragon: an item gone since has none
    const data = try ddragon.buildData(gpa, c.arena, io, patches[0]);

    var sets: [builds.max_sets]builds.Set = undefined;
    for (targets, 0..) |t, i| sets[i] = t.set;
    var bs: [builds.max_sets]builds.Builder = undefined;
    {
        var items: CubeItems = .{ .gpa = gpa, .arena = c.arena, .io = io };
        try items.put(patches[0], &data);
        const cube = try cubes.Store.open(gpa, io, try cubes.dirIn(c.arena, c.data_dir));
        defer cube.deinit();
        (try cubes.buildsOf(cube, db, items.source(), &data, o, sets[0..targets.len], bs[0..targets.len])).report();
    }
    defer for (bs[0..targets.len]) |*b| b.deinit();
    for (targets, bs[0..targets.len]) |t, *b| {
        if (b.games == 0) {
            std.log.err("{s}: no ranked solo games, {s}", .{ t.path, t.label });
            return error.NoMatches;
        }
        const f = try b.file(c.arena, &data, t.label, t.set.min_tier orelse o.min_tier orelse "", o.rows);
        var file = try std.Io.Dir.cwd().createFileAtomic(io, t.path, .{ .make_path = true, .replace = true });
        defer file.deinit(io);
        var buf: [64 * 1024]u8 = undefined;
        var w = file.file.writer(io, &buf);
        try std.json.Stringify.value(f, .{}, &w.interface);
        try w.interface.flush();
        try file.replace(io);
        std.log.info("{s}: {s}, {d} games ({d} with timelines), {d} champion roles, {d} options held, {d} matchups, {d} matchup options held", .{
            t.path, t.label, b.games, b.timelines, f.builds.len, b.options.count(), f.matchups.len, if (b.vs) |v| v.options.count() else 0,
        });
        // docs/learned.md keeps these: how much options of a kind really differ
        if (t.set.min_tier == null) for (f.shrink) |x| std.log.info("{s}: k {d:.0}, in matchups {d:.0}", .{ @tagName(x.kind), x.k, x.vs });
    }
    return 0;
}

pub const usage_lockrows =
    \\  lockrows    write the champion page lock rows (lockrows.zig): every ranked solo
    \\              player and game of the last --days, by champion-role, from the day
    \\              cubes (made current first, but a day built in the last 6 h is read as
    \\              it is)
    \\              --days N         default 30
    \\              --out FILE       default DIR/export/lockrows.bin
    \\              --bench FILE     time build answers (lockanswer.zig) on FILE's
    \\                               largest blocks over a lock mix, each checked
    \\                               against builds.Builder's; write nothing
    \\              --format         print the fingerprint after the file's magic
    \\                               this binary writes and reads, then exit
    \\                               (deploy/web-loop.sh)
    \\
;

pub const usage_meio =
    \\  meio        fit the MeioModel (meio.zig) on the day cubes' last 30 days, every game
    \\              up to now, and write it for the champion page locks
    \\              --patch P        the newest patch (default EUW1's in the database)
    \\              --out FILE       default DIR/export/meio.bin
    \\              --format         as for lockrows
    \\
;

fn printFormat(c: *Cmd, fingerprint: u64) !u8 {
    var buf: [32]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(c.init.io, &buf);
    try stdout.interface.print("{d}\n", .{fingerprint});
    try stdout.interface.flush();
    return 0;
}

pub fn cmdMeio(c: *Cmd) !u8 {
    var patch: ?[]const u8 = null;
    var out: ?[]const u8 = null;
    while (c.next()) |_| {
        if (c.is("--patch")) {
            patch = try c.value();
        } else if (c.is("--out")) {
            out = try c.value();
        } else if (c.is("--format")) {
            return printFormat(c, meio.fingerprint);
        } else if (c.is("--time-leans")) {
            return timeLeans(c, try c.value());
        } else return error.Usage;
    }
    const gpa = c.init.gpa;
    const io = c.init.io;
    const arena = c.arena;
    const t0 = std.Io.Clock.awake.now(io);
    if (patch == null) {
        const db = try c.open();
        defer db.close();
        patch = (try newestPatch(arena, db, &.{"EUW1"}))[0];
    }
    // One origin, its horizon past today: every game from T0 - 30 days to now
    const loaded = try truth.load(gpa, io, try cubes.dirIn(arena, c.data_dir), .{ .patch = patch.?, .origins = 1, .horizon = 255 });
    defer gpa.free(loaded.rows);
    const now_ms = std.Io.Clock.real.now(io).toMilliseconds();
    const today: i32 = @intCast(@divFloor(now_ms - loaded.t0, std.time.ms_per_day));
    const t_load = std.Io.Clock.awake.now(io);
    var m = try meio.fit(gpa, loaded.rows, today + 1, .{});
    defer m.deinit(gpa);
    meio.slim(&m, gpa);
    const t_fit = std.Io.Clock.awake.now(io);
    const path = out orelse try std.fs.path.join(arena, &.{ c.data_dir, "export", "meio.bin" });
    var file = try std.Io.Dir.cwd().createFileAtomic(io, path, .{ .make_path = true, .replace = true });
    defer file.deinit(io);
    var buf: [64 * 1024]u8 = undefined;
    var fw = file.file.writer(io, &buf);
    try meio.save(&fw.interface, &m);
    try fw.interface.flush();
    const bytes = fw.logicalPos();
    try file.replace(io);
    const ms = struct {
        fn f(a: std.Io.Timestamp, b: std.Io.Timestamp) i64 {
            return a.durationTo(b).toMilliseconds();
        }
    }.f;
    std.log.info("{s}: patch {s} day {d}, {d} rows, {d} champion-roles, {d} B; load {d} ms, fit {d} ms, write {d} ms", .{
        path, patch.?, today, loaded.rows.len, m.counts.len, bytes, ms(t0, t_load), ms(t_load, t_fit), ms(t_fit, std.Io.Clock.awake.now(io)),
    });
    return 0;
}

/// `meio --time-leans FILE`: Model.leans over every champion-role, share, pair and
/// keystone or item cell of a meio.bin, all ranks every region and EUW1 Diamond+;
/// per-number cost (E9a's budget)
fn timeLeans(c: *Cmd, path: []const u8) !u8 {
    const io = c.init.io;
    const f = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer f.close(io);
    var buf: [1 << 20]u8 = undefined;
    var r = f.reader(io, &buf);
    const m = (try meio.load(&r.interface, c.arena)) orelse {
        std.log.err("{s}: another build's meio.bin", .{path});
        return 1;
    };
    const asks = [_]struct { region: u1, brackets: meio.Brackets }{ .{ .region = 0, .brackets = .all }, .{ .region = 1, .brackets = .of(3) } };
    var n: usize = 0;
    var usual: f64 = 0;
    const t0 = std.Io.Clock.awake.now(io);
    for (asks) |ask| {
        var it = m.index.keyIterator();
        while (it.next()) |a| if (m.leans(.champion, ask.region, ask.brackets, a.*, 0)) |l| {
            n += 1;
            usual += l.usual;
        };
        inline for (.{ .{ meio.Kind.rune, &m.rune }, .{ meio.Kind.build, &m.build } }) |s| {
            var si = s[1].index.keyIterator();
            while (si.next()) |k| if (m.leans(s[0], ask.region, ask.brackets, @intCast(k.* >> 16), k.* & 0xffff)) |l| {
                n += 1;
                usual += l.usual;
            };
        }
        var pi = m.pair.index.keyIterator();
        while (pi.next()) |k| {
            const duo = k.* & 1 != 0;
            const kind: meio.Kind = if (duo) .duo else .matchup;
            if (m.leans(kind, ask.region, ask.brackets, @intCast(k.* >> 17), @intCast(k.* >> 1 & 0xffff))) |l| {
                n += 1;
                usual += l.usual;
            }
        }
        inline for (.{ .{ meio.Kind.keystone, &m.keystone }, .{ meio.Kind.item, &m.item } }) |s| {
            var si = s[1].inter_index.keyIterator();
            while (si.next()) |k| if (m.leans(s[0], ask.region, ask.brackets, @intCast(k.* >> 16), k.* & 0xffff)) |l| {
                n += 1;
                usual += l.usual;
            };
        }
    }
    const us = @as(f64, @floatFromInt(t0.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds())) / 1000;
    std.log.info("{s}: {d} numbers, {d:.1} us each, {d:.0} ms in all; mean usual {d:.3}", .{ path, n, us / @as(f64, @floatFromInt(n)), us / 1000, usual / @as(f64, @floatFromInt(n)) });
    return 0;
}

pub fn cmdLockrows(c: *Cmd) !u8 {
    var days: u32 = 30;
    var out: ?[]const u8 = null;
    while (c.next()) |_| {
        if (c.is("--days")) {
            days = try c.int(u32);
        } else if (c.is("--out")) {
            out = try c.value();
        } else if (c.is("--bench")) {
            return benchLocks(c, try c.value());
        } else if (c.is("--format")) {
            return printFormat(c, lockrows.fingerprint);
        } else return error.Usage;
    }
    const gpa = c.init.gpa;
    const io = c.init.io;
    const arena = c.arena;
    const db = try c.open();
    defer db.close();
    const t0 = std.Io.Clock.awake.now(io);
    const from_ms = std.Io.Clock.real.now(io).toMilliseconds() - @as(i64, days) * std.time.ms_per_day;
    var w: lockrows.Writer = .init(gpa, from_ms);
    defer w.deinit();
    var games: u64 = 0;
    var items: CubeItems = .{ .gpa = gpa, .arena = arena, .io = io };
    {
        const cube = try cubes.Store.open(gpa, io, try cubes.dirIn(arena, c.data_dir));
        defer cube.deinit();
        // Curves --site builds the patch's days each round, just before
        cube.settle_ms = 6 * std.time.ms_per_hour;
        (try cube.refresh(db, from_ms, items.source())).report();
        std.log.info("cubes current in {d} ms", .{t0.durationTo(std.Io.Clock.awake.now(io)).toMilliseconds()});
        const ds = try cube.days(gpa, from_ms);
        defer gpa.free(ds);
        var day_arena: std.heap.ArenaAllocator = .init(gpa);
        defer day_arena.deinit();
        for (ds) |day| {
            _ = day_arena.reset(.retain_capacity);
            const d = try cube.need(gpa, day_arena.allocator(), day);
            for (d.games) |g| try w.addGame(d, g);
            games += d.games.len;
        }
    }
    // The patch builds --site names and counts with
    const patch = (try newestPatch(arena, db, &.{"EUW1"}))[0];
    const t = try w.finish(arena, (try CubeItems.get(&items, patch)).*);
    const path = out orelse try std.fs.path.join(arena, &.{ c.data_dir, "export", "lockrows.bin" });
    var file = try std.Io.Dir.cwd().createFileAtomic(io, path, .{ .make_path = true, .replace = true });
    defer file.deinit(io);
    var buf: [64 * 1024]u8 = undefined;
    var fw = file.file.writer(io, &buf);
    try lockrows.write(&fw.interface, t);
    try fw.interface.flush();
    try file.replace(io);
    var rows: u64 = 0;
    var bytes: u64 = 0;
    const per = try arena.alloc(u32, t.blocks.len);
    for (t.blocks, per) |b, *n| {
        rows += b.rows;
        bytes += b.bytes.len;
        n.* = b.rows;
    }
    std.mem.sort(u32, per, {}, std.sort.asc(u32));
    const at = struct {
        fn f(xs: []const u32, q: f64) u32 {
            return if (xs.len == 0) 0 else xs[@min(xs.len - 1, @as(usize, @intFromFloat(q * @as(f64, @floatFromInt(xs.len)))))];
        }
    }.f;
    std.log.info("{s}: {d} games, {d} rows, {d} champion-roles (rows p50 {d}, p90 {d}, p99 {d}, max {d}), {d} B rows ({d:.1} B a row), {d} ms", .{
        path,  games,                                                                   rows,                                                       t.blocks.len, at(per, 0.5), at(per, 0.9), at(per, 0.99), at(per, 1),
        bytes, @as(f64, @floatFromInt(bytes)) / @as(f64, @floatFromInt(@max(rows, 1))), t0.durationTo(std.Io.Clock.awake.now(io)).toMilliseconds(),
    });
    return 0;
}

/// Answer times on the largest blocks: no lock, the top keystone, the top core pair, the
/// usual lane opponent, and all three, under the default view's filter (EUW, Platinum+)
/// and every region's
fn benchLocks(c: *Cmd, path: []const u8) !u8 {
    const gpa = c.init.gpa;
    const io = c.init.io;
    const arena = c.arena;
    const t0 = std.Io.Clock.awake.now(io);
    const t = blk: {
        const f = try std.Io.Dir.cwd().openFile(io, path, .{});
        defer f.close(io);
        var buf: [1 << 20]u8 = undefined;
        var r = f.reader(io, &buf);
        break :blk try lockrows.read(&r.interface, arena) orelse return error.BadLockRows;
    };
    std.log.info("{s}: {d} blocks, read in {d} ms", .{ path, t.blocks.len, t0.durationTo(std.Io.Clock.awake.now(io)).toMilliseconds() });
    const t1 = std.Io.Clock.awake.now(io);
    var index: lockanswer.Index = try .init(gpa, io, &t);
    defer index.deinit();
    var most: [2]usize = @splat(0);
    for (index.blocks) |b| for (b.values) |v| {
        most[0] = @max(most[0], v.len);
    };
    for (index.blocks) |b| most[1] = @max(most[1], b.items.len);
    std.log.info("coded in {d} ms; most values of a kind in a block {d}, items {d}", .{ t1.durationTo(std.Io.Clock.awake.now(io)).toMilliseconds(), most[0], most[1] });
    const order = try arena.alloc(usize, t.blocks.len);
    for (order, 0..) |*x, i| x.* = i;
    std.mem.sort(usize, order, t.blocks, struct {
        fn f(bs: []const lockrows.Block, a: usize, b: usize) bool {
            return bs[a].rows > bs[b].rows;
        }
    }.f);
    const euw: ?u8 = for (t.dicts.platforms, 0..) |p, i| {
        if (std.mem.eql(u8, p, "EUW1")) break @intCast(i);
    } else null;
    const floor = builds.rankOf("PLATINUM");
    const o: builds.Options = .{};
    var times: std.ArrayList(u64) = .empty;
    for (order[0..@min(order.len, 20)]) |bi| {
        const b = &t.blocks[bi];
        var scratch: std.heap.ArenaAllocator = .init(gpa);
        defer scratch.deinit();
        const sa = scratch.allocator();
        const base = (try lockanswer.file(gpa, sa, &t, &index, b.champion, b.role, .{ .floor = floor }, &.{}, o, "", "")).?;
        const own = base.get(b.champion, b.role) orelse continue;
        var mix: [5]lockanswer.Locks = @splat(.{});
        if (own.get(.keystone)) |x| if (x.options.len > 0) {
            mix[1].by.set(.keystone, .of(x.options[0].v));
            mix[4].by.set(.keystone, .of(x.options[0].v));
        };
        if (own.get(.core2)) |x| if (x.options.len > 0) {
            mix[2].by.set(.core2, .of(x.options[0].v));
            mix[4].by.set(.core2, .of(x.options[0].v));
        };
        var it: lockrows.Rows = .{ .t = &t, .b = b };
        if (it.next()) |r| if (r.seat.p.opponent != 0) {
            mix[3].by.set(.opponent, .of(&.{r.seat.p.opponent}));
            mix[4].by.set(.opponent, .of(&.{r.seat.p.opponent}));
        };
        for ([_]lockanswer.Filter{ .{ .platform = euw, .floor = floor }, .{ .floor = floor } }) |filter| for (&mix) |*l| {
            const at = std.Io.Clock.awake.now(io);
            const f = (try lockanswer.file(gpa, sa, &t, &index, b.champion, b.role, filter, l, o, "", "")).?;
            const ns: u64 = @intCast(at.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds());
            const want = (try lockanswer.reference(gpa, sa, &t, b.champion, b.role, filter, l, o, "", "")).?;
            std.testing.expectEqualDeep(want, f) catch {
                std.log.err("{d} {s} {f}: answer differs from builds.Builder's", .{ b.champion, @tagName(b.role), l.* });
                return 1;
            };
            try times.append(arena, ns);
            const games = if (f.get(b.champion, b.role)) |x| x.games else 0;
            std.log.info("{d} {s}: {d} rows, {s}, {f}: {d} games, {d:.1} ms", .{ b.champion, @tagName(b.role), b.rows, if (filter.platform != null) "EUW" else "all", l.*, games, @as(f64, @floatFromInt(ns)) / 1e6 });
        };
    }
    std.mem.sort(u64, times.items, {}, std.sort.asc(u64));
    const n = times.items.len;
    if (n > 0) std.log.info("{d} answers: p50 {d:.1} ms, p99 {d:.1} ms, max {d:.1} ms", .{
        n,
        @as(f64, @floatFromInt(times.items[n / 2])) / 1e6,
        @as(f64, @floatFromInt(times.items[@min(n - 1, n * 99 / 100)])) / 1e6,
        @as(f64, @floatFromInt(times.items[n - 1])) / 1e6,
    });
    return 0;
}

const CubeItems = cubes.ItemCache;

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
    const platforms = if (g.platforms.items.len > 0) g.platforms.items else platform_ids;
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
    \\              file"); daily on the box, then tester-bin
    \\              --out DIR        default DATA/tester
    \\
;

pub fn cmdDraftModel(c: *Cmd) !u8 {
    return testerModel(c, draftmodel.run);
}

pub const usage_tester_bin =
    \\  tester-bin  DIR/draft-model.json (the box's or a lab export) as DIR/draft-model.bin,
    \\              the file the Draft tester page reads (web-loop.sh, lab-push.sh)
    \\              DIR
    \\
;

pub fn cmdTesterBin(c: *Cmd) !u8 {
    const dir = c.next() orelse return error.Usage;
    if (c.next() != null) return error.Usage;
    var buf: [256]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(c.init.io, &buf);
    defer stdout.interface.flush() catch {};
    try testerbin.convert(c.arena, c.init.io, dir, &stdout.interface);
    return 0;
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
