//! `meiolol`: backend. Crawls ranked solo games and timelines from the Riot API into SQLite
//! and builds the model file the app reads. Runs on the box (deploy/box.sh).

const std = @import("std");
const store = @import("store");
const core = @import("core");
pub const riot = @import("riot/root.zig");
pub const ddragon = @import("ddragon.zig");
pub const stats = @import("stats.zig");
pub const site = @import("site/root.zig");
pub const serve = @import("serve.zig");
pub const daily = @import("daily.zig");
pub const learn = @import("learn.zig");
pub const curves = @import("curves.zig");
pub const builds = @import("builds.zig");
pub const pool = @import("pool.zig");
pub const learning = @import("learning.zig");
pub const spread = @import("spread.zig");
pub const patchday = @import("patchday.zig");
pub const patchnotes = @import("patchnotes.zig");
pub const cdragon = @import("cdragon.zig");
pub const leaguepedia = @import("leaguepedia.zig");
pub const image = @import("image.zig");
pub const icons = @import("icons.zig");
pub const eval = @import("eval.zig");
pub const fitted = @import("fitted.zig");
pub const objectives = @import("objectives.zig");
pub const winchance = @import("winchance.zig");
pub const playstyle = @import("playstyle.zig");
pub const lean = @import("lean.zig");
pub const draftmodel = @import("draftmodel.zig");
pub const lanemodel = @import("lanemodel.zig");
pub const digests = @import("digests.zig");
pub const archive = @import("archive.zig");
pub const api = @import("api/root.zig");
pub const backup = @import("backup.zig");
pub const forget = @import("forget.zig");
pub const rekey = @import("rekey.zig");
pub const admin = @import("admin.zig");
pub const status = @import("status.zig");
const cmd_crawl = @import("cmd/crawl.zig");
const cmd_sitedata = @import("cmd/sitedata.zig");
const cmd_analysis = @import("cmd/analysis.zig");
const cmd_site = @import("cmd/site.zig");
const cmd_ops = @import("cmd/ops.zig");
const cmd_data = @import("cmd/data.zig");
const cmd_lab = @import("cmd/lab.zig");
const cmd_desktop = @import("cmd/desktop.zig");
pub const labtools = @import("labtools/root.zig");

pub const std_options: std.Options = .{ .logFn = logFn };

const usage_head =
    \\usage: meiolol <command> [options]
    \\
    \\commands:
    \\
;

const usage_tail =
    \\
    \\options for all commands:
    \\  --data DIR  data directory (default $MEIOLOL_DATA or ./data)
    \\
    \\exit codes: 0 ok, 1 error, 2 bad usage, 3 Riot rejected the API key
    \\
;

/// The help, in this order; each command's text sits beside its function
const usage = usage_head ++
    cmd_crawl.usage_crawl ++
    cmd_crawl.usage_stats ++
    cmd_sitedata.usage_curves ++
    cmd_sitedata.usage_builds ++
    cmd_analysis.usage_eval ++
    cmd_analysis.usage_legendaries ++
    cmd_analysis.usage_patchnotes ++
    cmd_analysis.usage_winchance ++
    cmd_analysis.usage_objectives ++
    cmd_analysis.usage_playstyle ++
    cmd_analysis.usage_truth ++
    cmd_sitedata.usage_lean ++
    cmd_sitedata.usage_draft_model ++
    cmd_sitedata.usage_lane_model ++
    cmd_sitedata.usage_tester_bin ++
    cmd_data.usage_raw_export ++
    cmd_site.usage_site ++
    cmd_site.usage_dev ++
    cmd_site.usage_render ++
    cmd_site.usage_serve ++
    cmd_ops.usage_api ++
    cmd_ops.usage_account ++
    cmd_ops.usage_your_example ++
    cmd_ops.usage_status ++
    cmd_ops.usage_admin ++
    cmd_ops.usage_notes ++
    cmd_ops.usage_urls ++
    cmd_data.usage_rebuild ++
    cmd_data.usage_rekey ++
    cmd_crawl.usage_champions ++
    cmd_crawl.usage_draft_backfill ++
    cmd_crawl.usage_digest ++
    cmd_data.usage_backup ++
    cmd_data.usage_restore ++
    cmd_data.usage_forget ++
    cmd_desktop.usage_desktop_sign ++
    cmd_lab.usage_lab_place ++
    cmd_lab.usage_lab_sweep ++
    usage_tail;

pub fn main(init: std.process.Init) !u8 {
    const arena = init.arena.allocator();
    const argv = try init.minimal.args.toSlice(arena);
    if (argv.len < 2) return usageError(null);
    const run = commands.get(argv[1]) orelse return usageError(argv[1]);
    var c: Cmd = .{
        .init = init,
        .arena = arena,
        .data_dir = init.environ_map.get("MEIOLOL_DATA") orelse "data",
    };
    // --data is for every command; the rest are the command's own
    var flags: std.ArrayList([]const u8) = .empty;
    var i: usize = 2;
    while (i < argv.len) : (i += 1) {
        if (std.mem.eql(u8, argv[i], "--data") and i + 1 < argv.len) {
            i += 1;
            c.data_dir = argv[i];
        } else try flags.append(arena, argv[i]);
    }
    c.args = flags.items;
    // The lab tools, desktop-sign and -curves run from deploy/ scripts in any directory;
    // urls from traffic.sh's sandbox, where nothing is writable
    if (!std.mem.startsWith(u8, argv[1], "lab-") and !std.mem.startsWith(u8, argv[1], "desktop-") and
        !std.mem.eql(u8, argv[1], "urls")) try std.Io.Dir.cwd().createDirPath(init.io, c.data_dir);
    return run(&c) catch |err| switch (err) {
        error.Usage => usageError(c.flag),
        // Logged where it happened
        error.NoApiKey => 1,
        else => err,
    };
}

const commands = std.StaticStringMap(*const fn (*Cmd) anyerror!u8).initComptime(.{
    .{ "crawl", cmd_crawl.cmdCrawl },
    .{ "stats", cmd_crawl.cmdStats },
    .{ "curves", cmd_sitedata.cmdCurves },
    .{ "builds", cmd_sitedata.cmdBuilds },
    .{ "eval", cmd_analysis.cmdEval },
    .{ "legendaries", cmd_analysis.cmdLegendaries },
    .{ "patchnotes", cmd_analysis.cmdPatchnotes },
    .{ "objectives", cmd_analysis.cmdObjectives },
    .{ "winchance", cmd_analysis.cmdWinchance },
    .{ "playstyle", cmd_analysis.cmdPlaystyle },
    .{ "truth", cmd_analysis.cmdTruth },
    .{ "lean", cmd_sitedata.cmdLean },
    .{ "draft-model", cmd_sitedata.cmdDraftModel },
    .{ "lane-model", cmd_sitedata.cmdLaneModel },
    .{ "tester-bin", cmd_sitedata.cmdTesterBin },
    .{ "raw-export", cmd_data.cmdRawExport },
    .{ "site", cmd_site.cmdSite },
    .{ "serve", cmd_site.cmdServe },
    .{ "dev", cmd_site.cmdDev },
    .{ "render", cmd_site.cmdRender },
    .{ "api", cmd_ops.cmdApi },
    .{ "account", cmd_ops.cmdAccount },
    .{ "your-example", cmd_ops.cmdYourExample },
    .{ "status", cmd_ops.cmdStatus },
    .{ "admin", cmd_ops.cmdAdmin },
    .{ "notes", cmd_ops.cmdNotes },
    .{ "urls", cmd_ops.cmdUrls },
    .{ "rebuild", cmd_data.cmdRebuild },
    .{ "rekey", cmd_data.cmdRekey },
    .{ "champions", cmd_crawl.cmdChampions },
    .{ "draft-backfill", cmd_crawl.cmdDraftBackfill },
    .{ "digest", cmd_crawl.cmdDigest },
    .{ "backup", cmd_data.cmdBackup },
    .{ "restore", cmd_data.cmdRestore },
    .{ "forget", cmd_data.cmdForget },
    .{ "desktop-sign", cmd_desktop.cmdDesktopSign },
    .{ "desktop-curves", cmd_desktop.cmdDesktopCurves },
    .{ "lab-place", cmd_lab.cmdLabPlace },
    .{ "lab-sweep", cmd_lab.cmdLabSweep },
});

/// What a command gets: the process, the data directory and a cursor over its own
/// flags. A flag it doesn't take, or a bad value, is error.Usage (exit 2)
pub const Cmd = struct {
    init: std.process.Init,
    arena: std.mem.Allocator,
    data_dir: []const u8,
    args: []const []const u8 = &.{},
    i: usize = 0,
    /// The flag being read, named in the usage error
    flag: ?[]const u8 = null,

    pub fn next(c: *Cmd) ?[]const u8 {
        if (c.i >= c.args.len) return null;
        c.flag = c.args[c.i];
        c.i += 1;
        return c.flag;
    }

    pub fn is(c: *const Cmd, name: []const u8) bool {
        return std.mem.eql(u8, c.flag.?, name);
    }

    /// The current flag's value
    pub fn value(c: *Cmd) error{Usage}![]const u8 {
        if (c.i >= c.args.len) return error.Usage;
        c.i += 1;
        return c.args[c.i - 1];
    }

    pub fn int(c: *Cmd, comptime T: type) error{Usage}!T {
        return std.fmt.parseInt(T, try c.value(), 10) catch error.Usage;
    }

    pub fn float(c: *Cmd) error{Usage}!f64 {
        return std.fmt.parseFloat(f64, try c.value()) catch error.Usage;
    }

    /// A comma separated value, split
    pub fn list(c: *Cmd) ![]const []const u8 {
        var out: std.ArrayList([]const u8) = .empty;
        var it = std.mem.tokenizeScalar(u8, try c.value(), ',');
        while (it.next()) |v| try out.append(c.arena, v);
        return out.items;
    }

    pub fn noFlags(c: *Cmd) error{Usage}!void {
        if (c.next() != null) return error.Usage;
    }

    pub fn required(c: *Cmd, v: ?[]const u8, name: []const u8) error{Usage}![]const u8 {
        c.flag = name;
        return v orelse error.Usage;
    }

    pub fn open(c: *const Cmd) !store.Db {
        return store.open(c.init.gpa, c.data_dir);
    }

    pub fn apiKey(c: *const Cmd) ![]const u8 {
        return try c.envKey("RIOT_API_KEY") orelse {
            std.log.err("RIOT_API_KEY not set (env or .env)", .{});
            return error.NoApiKey;
        };
    }

    /// `name` from the environment, else from ./.env
    pub fn envKey(c: *const Cmd, name: []const u8) !?[]const u8 {
        if (c.init.environ_map.get(name)) |k| return k;
        const text = std.Io.Dir.cwd().readFileAlloc(c.init.io, ".env", c.arena, .limited(64 * 1024)) catch |err| switch (err) {
            error.FileNotFound => "",
            else => return err,
        };
        var lines = std.mem.tokenizeAny(u8, text, "\r\n");
        while (lines.next()) |line| {
            const eq = std.mem.findScalar(u8, line, '=') orelse continue;
            if (std.mem.eql(u8, std.mem.trim(u8, line[0..eq], " "), name)) {
                return std.mem.trim(u8, line[eq + 1 ..], " \"'");
            }
        }
        return null;
    }
};

/// --patch and --platform: the games stats, curves and eval read
pub const Games = struct {
    patches: std.ArrayList([]const u8) = .empty,
    platforms: std.ArrayList([]const u8) = .empty,
    /// --platform all: output files get the all- prefix
    every_platform: bool = false,

    /// Reads the current flag if it is one of these
    pub fn parse(g: *Games, c: *Cmd) !bool {
        if (c.is("--patch")) {
            try g.patches.appendSlice(c.arena, try c.list());
        } else if (c.is("--platform")) {
            for (try c.list()) |p| {
                if (std.mem.eql(u8, p, "all")) {
                    g.every_platform = true;
                    try g.platforms.appendSlice(c.arena, riot.endpoints.platform_ids);
                } else try g.platforms.append(c.arena, p);
            }
        } else return false;
        return true;
    }

    /// EUW1 unless given: the site says EUW
    pub fn platformIds(g: *const Games) []const []const u8 {
        return if (g.platforms.items.len > 0) g.platforms.items else &.{"EUW1"};
    }
};

fn usageError(arg: ?[]const u8) u8 {
    if (arg) |a| std.log.err("unknown, incomplete or missing for this command: {s}", .{a});
    std.debug.print("{s}", .{usage});
    return 2;
}

/// Where `meiolol curves` writes by default for these patches. Every platform's files
/// start all-, out of the curves-*.bin the Your games service reads (EUW, per patch)
pub fn curvesPath(arena: std.mem.Allocator, data_dir: []const u8, chosen: []const []const u8, every: bool) ![]const u8 {
    var label_buf: [core.statsfile.patch_len]u8 = undefined;
    const label = try stats.label(&label_buf, chosen);
    return arena.print("{s}/export/{s}curves-{s}.bin", .{ data_dir, allPrefix(every), label });
}

/// Where `meiolol curves` writes by default: every patch of the last --days. Not
/// curves-*.bin, which the Your games service reads as one file per patch
pub fn recentCurvesPath(arena: std.mem.Allocator, data_dir: []const u8, every: bool) ![]const u8 {
    return arena.print("{s}/export/{s}recent-curves.bin", .{ data_dir, allPrefix(every) });
}

/// The site's 30-day views reach back this far
pub const recent_days = 30;

/// `meiolol builds --site`'s last recent_days, for the 30-day views
pub fn recentBuildsPath(arena: std.mem.Allocator, data_dir: []const u8, every: bool) ![]const u8 {
    return arena.print("{s}/export/{s}recent-builds.json", .{ data_dir, allPrefix(every) });
}

/// Where `meiolol builds` writes by default; the site reads the newest patch's
pub fn buildsPath(arena: std.mem.Allocator, data_dir: []const u8, chosen: []const []const u8, every: bool) ![]const u8 {
    var label_buf: [core.statsfile.patch_len]u8 = undefined;
    const label = try stats.label(&label_buf, chosen);
    return arena.print("{s}/export/{s}builds-{s}.json", .{ data_dir, allPrefix(every), label });
}

/// A builds file's rank filter twin: builds-16.21.json at Emerald+ is
/// builds-16.21-emerald.json
pub fn rankBuildsPath(arena: std.mem.Allocator, path: []const u8, tier: []const u8) ![]const u8 {
    std.debug.assert(std.mem.endsWith(u8, path, ".json"));
    const low = try std.ascii.allocLowerString(arena, tier);
    return arena.print("{s}-{s}.json", .{ path[0 .. path.len - ".json".len], low });
}

pub fn allPrefix(every: bool) []const u8 {
    return if (every) "all-" else "";
}

pub fn newestPatch(arena: std.mem.Allocator, db: store.Db, platforms: []const []const u8) ![]const []const u8 {
    const all = try stats.patches(arena, db, platforms);
    if (all.len == 0) return error.NoMatches;
    return all[0..1];
}

/// The EUW patch before `chosen` when it is one patch, for the site's patch day
pub fn previousPatch(arena: std.mem.Allocator, db: store.Db, chosen: []const []const u8) !?[]const []const u8 {
    if (chosen.len != 1) return null;
    const all = try stats.patches(arena, db, &.{"EUW1"});
    for (all, 0..) |p, i| {
        if (std.mem.eql(u8, p, chosen[0])) return if (i + 1 < all.len) all[i + 1 .. i + 2] else null;
    }
    return null;
}

/// The site's older patch pages: adjacent EUW pairs {cur, prev} below `chosen`, newest
/// first. The oldest patch in the database was crawled from partway, so a pair's
/// patches are both whole only when the patch below them was crawled too
pub fn olderPairs(arena: std.mem.Allocator, db: store.Db, chosen: []const []const u8) ![]const [2][]const u8 {
    if (chosen.len != 1) return &.{};
    const all = try stats.patches(arena, db, &.{"EUW1"});
    const at = patchIndex(all, chosen[0]) orelse return &.{};
    const games = try arena.alloc(u64, all.len);
    @memset(games, 0);
    // Only the patches a pair could rest on: each count reads its patch's rows
    const from, const to = restRange(all.len, at);
    for (from..to) |i| {
        games[i] = try stats.countGames(db, &.{all[i]}, &.{"EUW1"});
    }
    return pairsBelow(arena, all, games, at);
}

const max_older_pairs = 4;

/// Indices of the patches the pairs below all[at] could rest on, of `n` patches
fn restRange(n: usize, at: usize) [2]usize {
    const from = @min(n, at + 3);
    return .{ from, @min(n, from + max_older_pairs) };
}

test restRange {
    try std.testing.expectEqual([2]usize{ 1, 1 }, restRange(1, 0));
    try std.testing.expectEqual([2]usize{ 2, 2 }, restRange(2, 0));
    try std.testing.expectEqual([2]usize{ 3, 3 }, restRange(3, 1));
    try std.testing.expectEqual([2]usize{ 3, 4 }, restRange(4, 0));
    try std.testing.expectEqual([2]usize{ 4, 8 }, restRange(20, 1));
}

/// EUW games the patch below a pair needs to count as crawled: a crawled patch has tens
/// of thousands, stray games from before the crawl began (players' match histories
/// reach back) far fewer
const whole_floor = 10_000;

fn patchIndex(all: []const []const u8, patch: []const u8) ?usize {
    for (all, 0..) |p, i| if (std.mem.eql(u8, p, patch)) return i;
    return null;
}

/// `all` newest first, `games` each one's, from below all[at]
fn pairsBelow(arena: std.mem.Allocator, all: []const []const u8, games: []const u64, at: usize) ![]const [2][]const u8 {
    var out: std.ArrayList([2][]const u8) = .empty;
    var j = at + 1;
    while (j + 2 < all.len and games[j + 2] >= whole_floor and out.items.len < max_older_pairs) : (j += 1) {
        try out.append(arena, .{ all[j], all[j + 1] });
    }
    return out.items;
}

test pairsBelow {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const all = [_][]const u8{ "16.22", "16.21", "16.20", "16.19" };
    const crawled: [8]u64 = @splat(whole_floor);
    try std.testing.expectEqualDeep(&[_][2][]const u8{.{ "16.21", "16.20" }}, try pairsBelow(a, &all, &crawled, 0));
    try std.testing.expectEqual(0, (try pairsBelow(a, all[1..], &crawled, 0)).len);
    // A stray handful on the oldest patch: 16.20 may be partial
    try std.testing.expectEqual(0, (try pairsBelow(a, &all, &.{ 0, 0, 0, 40 }, 0)).len);
    // Sorted as the database's list is: 16.10 above 16.9
    var shuffled = [_][]const u8{ "16.8", "16.10", "16.7", "16.9", "16.6" };
    stats.sortPatches(&shuffled);
    try std.testing.expectEqualDeep(&[_][2][]const u8{ .{ "16.9", "16.8" }, .{ "16.8", "16.7" } }, try pairsBelow(a, &shuffled, &crawled, 0));
    const many = [_][]const u8{ "16.9", "16.8", "16.7", "16.6", "16.5", "16.4", "16.3", "16.2" };
    const got = try pairsBelow(a, &many, &crawled, 0);
    try std.testing.expectEqual(max_older_pairs, got.len);
    try std.testing.expectEqualDeep([2][]const u8{ "16.5", "16.4" }, got[3]);
    // Stops at the first patch below that wasn't crawled
    var gap = crawled;
    gap[5] = 0;
    try std.testing.expectEqual(2, (try pairsBelow(a, &many, &gap, 0)).len);
}

/// Default log format plus a UTC timestamp, for the crawl log on the box
fn logFn(
    comptime level: std.log.Level,
    comptime scope: @EnumLiteral(),
    comptime format: []const u8,
    args: anytype,
) void {
    const io = std.Options.debug_io;
    const secs: u64 = @intCast(std.Io.Clock.real.now(io).toSeconds());
    const epoch: std.time.epoch.EpochSeconds = .{ .secs = secs };
    const day = epoch.getEpochDay().calculateYearDay();
    const md = day.calculateMonthDay();
    const ds = epoch.getDaySeconds();
    var buffer: [64]u8 = undefined;
    const stderr = std.debug.lockStderr(&buffer).terminal();
    defer std.debug.unlockStderr();
    stderr.writer.print("{d}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2} ", .{
        day.year,             md.month.numeric(),      md.day_index + 1,
        ds.getHoursIntoDay(), ds.getMinutesIntoHour(), ds.getSecondsIntoMinute(),
    }) catch {};
    std.log.defaultLogFileTerminal(level, scope, format, args, stderr) catch {};
}

test {
    std.testing.refAllDecls(@This());
    _ = @import("pipeline_test.zig");
}
