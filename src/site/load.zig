//! One view's data from the database, or from an earlier views file's parts, into a Site

const std = @import("std");
const store = @import("store");
const core = @import("core");
const stats = @import("../stats.zig");
const html = @import("html.zig");
const daily = @import("../daily.zig");
const learn = @import("../learn.zig");
const pool = @import("../pool.zig");
const learning = @import("../learning.zig");
const par = @import("../par.zig");
const spread = @import("../spread.zig");
const filters = @import("filters.zig");
const evalchart = @import("evalchart.zig");
const patchday = @import("../patchday.zig");
const partials = @import("../partials.zig");

const Writer = std.Io.Writer;
const Stats = core.Stats;

const log = std.log.scoped(.site);

const root = @import("root.zig");
const tierlist = @import("tierlist.zig");
const champion = @import("champion.zig");
const champrank = @import("champrank.zig");
const Options = root.Options;
const Site = root.Site;
const File = root.File;
const robots = root.robots;
const sitemap = root.sitemap;
const Extras = @import("extras.zig").Extras;
const People = @import("extras.zig").People;
const loadChamps = @import("champs.zig").loadChamps;
const indexChamps = @import("champs.zig").indexChamps;
const championsJson = @import("champs.zig").championsJson;
const search = @import("search.zig");
const yourgame = @import("yourgame.zig");
const BasePart = @import("views.zig").BasePart;
const FilterPart = @import("views.zig").FilterPart;
const PeoplePart = @import("views.zig").PeoplePart;
const DailyPart = @import("views.zig").DailyPart;
const TrendPart = @import("views.zig").TrendPart;
const champsKey = @import("views.zig").champsKey;
const Parts = @import("views.zig").Parts;

/// Reads the view's data (the slow part of a site build), each part (Part) from `old`
/// where it is there with this binary's key, the rest from the database; with
/// old.strict a part not there is ViewsMismatch. Free with unload
pub fn loadParts(gpa: std.mem.Allocator, io: std.Io, db: store.Db, all_opts: Options, view: html.View, extras: *Extras, old: ?*const Parts) !*Site {
    const owner = try gpa.create(std.heap.ArenaAllocator);
    owner.* = .init(gpa);
    errdefer {
        owner.deinit();
        gpa.destroy(owner);
    }
    const arena = owner.allocator();

    var opts = all_opts;
    opts.platforms = switch (view.region) {
        .euw => all_opts.platforms,
        .all => all_opts.all_platforms,
    };
    const shared = std.meta.eql(view, html.View.shared);
    if (!shared) opts.daily_dir = null;

    const site = try arena.create(Site);
    site.* = .{
        .gpa = gpa,
        .arena = arena,
        .owner = owner,
        .io = io,
        .stats = undefined,
        .champs = &.{},
        .by_c = &.{},
        .games = 0,
        .patch = "",
        .when = "",
        .ddragon_version = "",
        .view = view,
        .since_ms = 0,
        .opts = opts,
        .curves = extras.curves[view.index()],
        .curves_prev = extras.curves_prev[view.index()],
        .view_curves = &extras.curves,
        .view_builds = &extras.builds,
        .view_builds_prev = &extras.builds_prev,
        .view_builds_rank = &extras.builds_rank,
        .lean = if (extras.lean) |*l| l else null,
    };
    var phases: Phases = .init(io);
    // A kept patch view's patch must still be the current one
    const base = try Parts.of(old, BasePart, .base, view, arena);
    if (base != null and (view.period == .days30 or eqlStrings(base.?.patches, opts.patches))) {
        const b = base.?;
        site.opts.patches = b.patches;
        site.champs = b.champs;
        site.games = b.games;
        site.patch = b.patch;
        site.when = b.when;
        site.patch_mix = b.patch_mix;
        site.ddragon_version = b.ddragon_version;
        site.since_ms = b.since_ms;
        site.model = b.model;
        site.stats = try .parse(arena, b.model);
        try indexChamps(site);
        phases.mark("stats and champions kept");
    } else {
        if (old) |o| if (o.strict) return error.ViewsMismatch;
        try loadBase(site, db, all_opts, &phases, try extras.partialsFor(gpa, io, db, &phases));
    }
    const champs_key = champsKey(site.champs);

    // Static.core writes none of what follows (rendered on request), and skipping it is
    // most of the build: the pool tallies alone take minutes on the box
    if (all_opts.static != .core) {
        // The root view's directory is the site root, where champion pages are
        const kept_filter = if (view.index() == 0) try Parts.ofFor(old, FilterPart, .filter, view, arena, champs_key) else null;
        const kept_people = try Parts.ofFor(old, PeoplePart, .people, view, arena, champs_key);
        if (kept_filter) |f| {
            site.filter = f.filter;
            phases.mark("filters kept");
        }
        var loading: Loading = .{
            .site = site,
            .db = db,
            .extras = extras,
            .opts = all_opts,
            .want_filter = view.index() == 0 and kept_filter == null,
            .want_people = kept_people == null,
        };
        if (loading.want_filter or loading.want_people) loading.games = try extras.partialsFor(gpa, io, db, &phases);
        if (loading.want_filter and loading.want_people) loading.sibling = try store.schema.openSibling(gpa, db);
        defer if (loading.sibling) |sibling| sibling.close();
        if (loading.sibling != null) {
            try par.each(io, 2, &loading, Loading.run);
            phases.add("filters", loading.ms[0]);
            phases.add("people", loading.ms[1]);
            phases.mark("at once");
        } else for (0..2) |i| {
            try loading.run(i);
            if (i == 0 and loading.want_filter) phases.mark("filters");
            if (i == 1 and loading.want_people) phases.mark("people");
        }
        if (loading.want_filter) site.filter = loading.filter;
        if (kept_people) |p| {
            site.pool = p.pool;
            site.spread = p.spread;
            site.learning = p.learning;
            site.by_view = p.by_view;
            phases.mark("people kept");
        } else {
            const people = loading.people.?;
            const set = @backingInt(view.region);
            if (set >= people.pool.games.len) return error.NoView;
            site.pool = try pool.make(arena, &people.pool, set, &site.stats, .{});
            site.spread = try spread.make(arena, &people.pool.spread[view.index()], &site.stats);
            // Every region's, whatever the view's region (learning.zig)
            site.learning = try learning.make(arena, &people.learning[@backingInt(view.period)], &site.stats);
            // The champion pages' filters pick a view: each one's, as its own load makes them
            if (view.index() == 0) {
                const by = try arena.alloc(root.ByView, html.View.count);
                for (html.View.all, by) |v, *b| b.* = .{
                    .spread = try spread.make(arena, &people.pool.spread[v.index()], &site.stats),
                    .learning = try learning.build(arena, &people.learning[@backingInt(v.period)], &site.stats),
                    // Options.euw_only tallies EUW's alone
                    .pool = try pool.make(arena, &people.pool, @min(@backingInt(v.region), people.pool.games.len - 1), &site.stats, .{}),
                };
                site.by_view = by;
            }
        }
        if (shared) {
            if (try Parts.ofFor(old, DailyPart, .daily, view, arena, champs_key)) |d| {
                site.daily_files = d.files;
                site.learn = d.learn;
                site.eval = d.eval;
                phases.mark("daily and learn kept");
            } else try loadDaily(site, db, try extras.partialsFor(gpa, io, db, &phases), &phases);
        }
        try loadPatchDay(site, db, all_opts, extras, old, &phases);
        if (try Parts.ofFor(old, TrendPart, .trend, view, arena, champs_key)) |t| {
            site.trend = t.trend;
            phases.mark("trend kept");
        } else try loadTrend(site, db, try extras.partialsFor(gpa, io, db, &phases), &phases);
    }
    try addFiles(site);
    if (old == null or !old.?.strict) log.info("view {d} ({s}) load:{s}", .{ view.index(), site.when, phases.text() });
    return site;
}

/// Filters and the people tallies, at once when both are wanted and db is in a file
/// (sibling set): each waits on its own cold pages
const Loading = struct {
    site: *Site,
    db: store.Db,
    /// The people tallies' connection, beside filters' on db
    sibling: ?store.Db = null,
    extras: *Extras,
    opts: Options,
    want_filter: bool,
    want_people: bool,
    games: ?*partials.Store = null,
    filter: filters.Made = .{},
    people: ?*const People = null,
    /// Each one's own time
    ms: [2]i64 = .{ 0, 0 },

    fn run(l: *Loading, i: usize) !void {
        const io = l.site.io;
        const start = std.Io.Clock.awake.now(io).toMilliseconds();
        if (i == 0) {
            if (l.want_filter) l.filter = if (l.games) |g| try filters.makeFrom(l.site, g, l.opts) else try filters.make(l.site, l.db, l.opts);
        } else if (l.want_people) {
            l.people = try l.extras.tallies(l.site.gpa, l.sibling orelse l.db, &l.site.stats, l.opts);
        }
        l.ms[i] = std.Io.Clock.awake.now(io).toMilliseconds() - start;
    }
};

/// The view's stats, patches and champions from the database
fn loadBase(site: *Site, db: store.Db, all_opts: Options, phases: *Phases, games: ?*const partials.Store) !void {
    const arena = site.arena;
    const view = site.view;
    site.since_ms = switch (view.period) {
        .patch => 0,
        .days30 => all_opts.since_ms,
    };
    if (view.period == .days30) site.opts.patches = if (games) |g|
        try g.patches(arena, site.opts.platforms)
    else
        try stats.patches(arena, db, site.opts.platforms);
    var built = try stats.buildSince(site.gpa, db, games, site.opts.patches, site.opts.platforms, site.since_ms, .pair_prior);
    phases.mark("stats");
    defer built.builder.deinit();
    if (built.summary.games == 0) return error.NoMatches;
    var label_buf: [core.statsfile.patch_len]u8 = undefined;
    site.patch = try arena.dupe(u8, try stats.label(&label_buf, all_opts.patches));
    var model: Writer.Allocating = .init(arena);
    try built.builder.write(&model.writer, if (view.period == .patch) site.patch else "last 30 days");
    site.model = model.written();
    site.stats = try .parse(arena, site.model);
    site.games = built.summary.games;
    switch (view.period) {
        .patch => site.when = try arena.print("patch {s}", .{site.patch}),
        .days30 => {
            const p = try patchMix(arena, built.summary.by_patch, built.summary.games);
            site.when = p.when;
            site.patch_mix = p.mix;
        },
    }
    try loadChamps(site, db, games);
    phases.mark("champions");
}

/// The 30-day views' patches, oldest first: "last 30 days, patches 16.19 to 16.21" and
/// each one's share of the games, "16.19 9%, 16.20 88%, 16.21 3%"
fn patchMix(a: std.mem.Allocator, by: stats.PatchGames, games: u32) !struct { when: []const u8, mix: []const u8 } {
    const keys = try a.dupe(u32, by.keys[0..by.len]);
    std.mem.sort(u32, keys, {}, std.sort.asc(u32));
    const name = struct {
        fn f(al: std.mem.Allocator, k: u32) ![]const u8 {
            return al.print("{d}.{d}", .{ k / 1000, k % 1000 });
        }
    }.f;
    const when = switch (keys.len) {
        0 => "last 30 days",
        1 => try a.print("last 30 days, patch {s}", .{try name(a, keys[0])}),
        2 => try a.print("last 30 days, patches {s} and {s}", .{ try name(a, keys[0]), try name(a, keys[1]) }),
        else => try a.print("last 30 days, patches {s} to {s}", .{ try name(a, keys[0]), try name(a, keys[keys.len - 1]) }),
    };
    if (keys.len < 2) return .{ .when = when, .mix = "" };
    var mix: Writer.Allocating = .init(a);
    for (keys, 0..) |k, i| {
        const n = for (by.keys[0..by.len], by.games[0..by.len]) |bk, bn| {
            if (bk == k) break bn;
        } else 0;
        const share = 100 * @as(f64, @floatFromInt(n)) / @as(f64, @floatFromInt(@max(games, 1)));
        if (i > 0) try mix.writer.writeAll(", ");
        if (share < 1) try mix.writer.print("{s} under 1%", .{try name(a, k)}) else try mix.writer.print("{s} {d:.0}%", .{ try name(a, k), share });
    }
    return .{ .when = when, .mix = mix.written() };
}

test patchMix {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var by: stats.PatchGames = .{};
    by.keys[0..3].* = .{ 16021, 16019, 16020 };
    by.games[0..3].* = .{ 3, 9, 988 };
    by.len = 3;
    const p = try patchMix(arena.allocator(), by, 1000);
    try std.testing.expectEqualStrings("last 30 days, patches 16.19 to 16.21", p.when);
    try std.testing.expectEqualStrings("16.19 under 1%, 16.20 99%, 16.21 under 1%", p.mix);
    by.len = 1;
    const one = try patchMix(arena.allocator(), by, 3);
    try std.testing.expectEqualStrings("last 30 days, patch 16.21", one.when);
    try std.testing.expectEqualStrings("", one.mix);
}

/// The view's patch day (Options.prev_patch): its champions' win rates from both
/// patches' stats, kept in the views file (Part.prev), with the lane numbers and
/// matchups from its region's patch curves. A 30-day view builds its region's current
/// patch stats for it. The root view also makes every region's, for the champion pages'
/// region pick (Site.patchday_all)
fn loadPatchDay(site: *Site, db: store.Db, all_opts: Options, extras: *Extras, old: ?*const Parts, phases: *Phases) !void {
    const prev = all_opts.prev_patch orelse return;
    const view = site.view;
    var keep = true;
    site.patchday = try regionPatchDay(site, db, all_opts, extras, old, phases, prev, view, &keep);
    if (view.index() == 0 and !all_opts.euw_only) {
        const all: html.View = .{ .region = .all, .period = view.period };
        site.patchday_all = try regionPatchDay(site, db, all_opts, extras, old, phases, prev, all, &keep);
    }
    phases.mark(if (keep) "patch day kept" else "patch day");
}

/// `v`'s patch day, its wins from `old`'s Part.prev for v when current; `keep` false
/// when made here
fn regionPatchDay(site: *Site, db: store.Db, all_opts: Options, extras: *Extras, old: ?*const Parts, phases: *Phases, prev: []const u8, v: html.View, keep: *bool) !patchday.PatchDay {
    const arena = site.arena;
    var label_buf: [core.statsfile.patch_len]u8 = undefined;
    const cur = try stats.label(&label_buf, all_opts.patches);
    const kept = try Parts.of(old, patchday.Wins, .prev, v, arena);
    const current = if (kept) |k| std.mem.eql(u8, k.prev_patch, prev) and std.mem.eql(u8, k.cur_patch, cur) else false;
    const wins = if (current) kept.? else blk: {
        if (old) |o| if (o.strict) return error.ViewsMismatch;
        keep.* = false;
        const platforms = switch (v.region) {
            .euw => all_opts.platforms,
            .all => all_opts.all_platforms,
        };
        const games = try extras.partialsFor(site.gpa, site.io, db, phases);
        const prev_stats = try patchStats(site, db, &.{prev}, platforms, games);
        const cur_stats = if (std.meta.eql(v, site.view) and v.period == .patch) site.stats else try patchStats(site, db, all_opts.patches, platforms, games);
        break :blk try patchday.championWins(arena, &prev_stats, &cur_stats, .{});
    };
    const pv = (html.View{ .region = v.region, .period = .patch }).index();
    return patchday.withCurves(
        arena,
        wins,
        if (extras.curves_prev[pv]) |*c| c else null,
        if (extras.curves[pv]) |*c| c else null,
        .{},
    );
}

/// `platforms`' stats over `patches`, all of each
fn patchStats(site: *Site, db: store.Db, patches: []const []const u8, platforms: []const []const u8, games: ?*const partials.Store) !Stats {
    var built = try stats.buildSince(site.gpa, db, games, patches, platforms, 0, .none);
    defer built.builder.deinit();
    var label_buf: [core.statsfile.patch_len]u8 = undefined;
    var model: Writer.Allocating = .init(site.arena);
    try built.builder.write(&model.writer, try site.arena.dupe(u8, try stats.label(&label_buf, patches)));
    return .parse(site.arena, model.written());
}

/// The view's win rates by game length and by patch (stats.Trend), the patches from
/// every one with games in its region
fn loadTrend(site: *Site, db: store.Db, games: ?*const partials.Store, phases: *Phases) !void {
    const gpa = site.gpa;
    const platforms = site.opts.platforms;
    const all = if (games) |g| try g.patches(gpa, platforms) else try stats.patches(gpa, db, platforms);
    defer {
        for (all) |p| gpa.free(p);
        gpa.free(all);
    }
    site.trend = try stats.buildTrend(gpa, site.arena, db, games, &site.stats, site.opts.patches, all, platforms, site.since_ms);
    phases.mark("trend");
}

/// The shared view's Daily Draft, your example, eval chart and Learn data
fn loadDaily(site: *Site, db: store.Db, games: ?*const partials.Store, phases: *Phases) !void {
    const arena = site.arena;
    const io = site.io;
    const opts = site.opts;
    const day: u32 = @intCast(@divFloor(std.Io.Clock.real.now(io).toSeconds(), std.time.s_per_day));
    var files: std.ArrayList(File) = .empty;
    if (opts.daily_dir) |d| {
        const daily_files = daily.update(arena, io, db, &site.stats, .{
            .dir = d,
            .patches = opts.patches,
            .platforms = opts.platforms,
            .today = day,
            .curves = if (site.curves) |*c| c else null,
        }) catch |err| blk: {
            log.warn("daily draft: {t}", .{err});
            break :blk &.{};
        };
        try files.appendSlice(arena, daily_files);
    }
    if (opts.your_example) |path| {
        if (std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(16 << 20))) |json| {
            try yourgame.files(site, json, &files);
        } else |err| switch (err) {
            // `meiolol your-example` removes it after a failed run
            error.FileNotFound => {},
            else => log.warn("your example at {s}: {t}", .{ path, err }),
        }
    }
    if (opts.eval_history) |path| {
        if (std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(16 << 20))) |tsv| {
            site.eval = try evalchart.parse(arena, tsv);
        } else |err| log.info("no eval history at {s}: {t}", .{ path, err });
    }
    phases.mark("daily");
    // After the Daily Draft, so practice leaves out the games behind its puzzles
    if (learn.build(arena, io, db, games, &site.stats, if (site.curves) |*c| c else null, .{
        .patches = opts.patches,
        .platforms = opts.platforms,
        .today = day,
        .daily_dir = opts.daily_dir,
    })) |l| {
        try files.appendSlice(arena, l.files);
        site.learn = l.facts;
    } else |err| log.warn("learn: {t}", .{err});
    phases.mark("learn");
    site.daily_files = files.items;
}

/// The view's model file among its files
const stats_path = "data/stats.bin";

/// files and shared_files from the view's data, the binary and the options
fn addFiles(site: *Site) !void {
    const arena = site.arena;
    const opts = site.opts;
    var files: std.ArrayList(File) = .empty;
    var shared_files: std.ArrayList(File) = .empty;
    if (std.meta.eql(site.view, html.View.shared)) {
        try shared_files.append(arena, .{ .path = "meiolol.wasm", .data = @embedFile("draft.wasm") });
        try shared_files.append(arena, .{ .path = "chart.wasm", .data = @embedFile("chart.wasm") });
        if (opts.riot_txt) |t| try shared_files.append(arena, .{ .path = "riot.txt", .data = t });
        try shared_files.append(arena, .{ .path = "robots.txt", .data = try robots(arena, opts) });
    }
    if (opts.public and opts.origin != null) {
        try files.append(arena, .{ .path = "sitemap.xml", .data = try sitemap(site) });
    }
    if (opts.static != .core) {
        try files.append(arena, .{ .path = stats_path, .data = site.model });
        try files.append(arena, .{ .path = "data/champions.json", .data = try championsJson(site) });
        try files.append(arena, .{ .path = tierlist.data_path, .data = try tierlist.dataFile(site) });
        // Every view's champion data, for the page's view picker; the rank filter's
        // from the root view's tally
        try champion.dataFiles(site, &files);
        if (site.view.index() == 0) try champrank.dataFiles(site, &files);
        try files.append(arena, .{ .path = search.path, .data = try search.json(site) });
        {
            var aw: Writer.Allocating = .init(arena);
            try pool.writeJson(&aw.writer, site.pool);
            try files.append(arena, .{ .path = "data/pool.json", .data = aw.written() });
        }
        {
            var aw: Writer.Allocating = .init(arena);
            try learning.writeJson(&aw.writer, site.learning);
            try files.append(arena, .{ .path = "data/learning.json", .data = aw.written() });
        }
        try shared_files.appendSlice(arena, site.daily_files);
        if (site.learn) |facts| try shared_files.append(arena, .{ .path = "data/champ-facts.tsv", .data = try champFacts(site, facts) });
    }
    site.files = files.items;
    site.shared_files = shared_files.items;
}

/// The desktop's comp view facts (core/champfacts.zig): Learn's damage split and mix
/// tally, and the lean file's rows when there is one
fn champFacts(site: *const Site, facts: learn.Facts) ![]const u8 {
    const magic = try site.arena.alloc(?f32, facts.champs.len);
    for (magic, facts.champs) |*m, ch| m.* = ch.magic;
    var aw: Writer.Allocating = .init(site.arena);
    try core.champfacts.write(&aw.writer, site.patch, site.stats.ids[0..facts.champs.len], magic, facts.mix, if (site.lean) |l| l.rows else &.{});
    return aw.written();
}

fn eqlStrings(a: []const []const u8, b: []const []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |x, y| if (!std.mem.eql(u8, x, y)) return false;
    return true;
}

/// Seconds per step of a view's load, for its log line: on the box a load runs minutes
/// to an hour depending on the disk, and this says where
/// Each phase's time and the process's CPU time in it: far less CPU than time is a
/// phase waiting on the disk
pub const Phases = struct {
    io: std.Io,
    last_ms: i64,
    last_cpu_ms: i64,
    buf: [256]u8 = undefined,
    len: usize = 0,

    fn init(io: std.Io) Phases {
        return .{ .io = io, .last_ms = std.Io.Clock.awake.now(io).toMilliseconds(), .last_cpu_ms = cpuMs(io) };
    }

    pub fn mark(p: *Phases, name: []const u8) void {
        const now = std.Io.Clock.awake.now(p.io).toMilliseconds();
        const cpu = cpuMs(p.io);
        const ms: f64 = @floatFromInt(now - p.last_ms);
        const cpu_ms: f64 = @floatFromInt(cpu - p.last_cpu_ms);
        p.last_ms = now;
        p.last_cpu_ms = cpu;
        const s = std.mem.print(p.buf[p.len..], " {s} {d:.1}s (cpu {d:.1}s)", .{ name, ms / 1000, cpu_ms / 1000 }) catch return;
        p.len += s.len;
    }

    /// A part of the coming phase that ran beside others, with its own time
    fn add(p: *Phases, name: []const u8, ms: i64) void {
        const sec: f64 = @floatFromInt(ms);
        const s = std.mem.print(p.buf[p.len..], " {s} {d:.1}s", .{ name, sec / 1000 }) catch return;
        p.len += s.len;
    }

    fn cpuMs(io: std.Io) i64 {
        return std.Io.Clock.cpu_process.now(io).toMilliseconds();
    }

    fn text(p: *const Phases) []const u8 {
        return p.buf[0..p.len];
    }
};

pub fn unload(site: *Site) void {
    const owner = site.owner;
    const gpa = site.gpa;
    owner.deinit();
    gpa.destroy(owner);
}
