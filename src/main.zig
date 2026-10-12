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
pub const patchday = @import("patchday.zig");
pub const eval = @import("eval.zig");
pub const api = @import("api/root.zig");
pub const backup = @import("backup.zig");
pub const forget = @import("forget.zig");
pub const admin = @import("admin.zig");
const Date = @import("date.zig").Date;

pub const std_options: std.Options = .{ .logFn = logFn };

const usage =
    \\usage: meiolol <command> [options]
    \\
    \\commands:
    \\  crawl       crawl ranked solo games (needs RIOT_API_KEY in env or .env)
    \\              --hours H        stop after H hours (default: run until stopped)
    \\              --since-days N   how far back to collect match ids (default 14)
    \\              --patch-only     match ids only from each platform's newest patch;
    \\                               older patches' matches get no timeline
    \\              --no-active-first  scan stalest players first, not those the
    \\                               ladder shows played since their last scan
    \\              --no-mastery     skip champion mastery
    \\              --ladder-refresh-days N  refetch ladder pages after N days
    \\                               (default 7)
    \\              --ladder-refresh-hours N  the same in hours
    \\              --ladder-per-hour N  ladder pages per platform per hour at most
    \\                               (default 0: no cap)
    \\              --regions R      americas,asia,europe,sea (default all)
    \\              --timelines PCT  share of matches that also get a timeline; every
    \\                               --priority match gets one (default 100)
    \\              --raw-timeline-days N  keep raw timeline JSON N days (default 7,
    \\                                     0 none)
    \\              --raw-match-days N     keep raw match JSON N days (default 30,
    \\                                     0 forever)
    \\              --keep-days N    rolling window: drop matches, their rows and
    \\                               timelines N days after game start (default 0,
    \\                               kept forever)
    \\              --no-participant-players  scan ladder players only, not every
    \\                               match participant
    \\              --cache-mb N     the writer's page cache (default 64)
    \\              --player-sample N  keep full player rows (the scan pool) for 1
    \\                               ladder player in N; ranks has everyone (default 1)
    \\              --priority P     platforms whose players and matches come first
    \\                               in their region; its region's writes go first
    \\                               when the machine falls behind (default EUW1,
    \\                               "none" for none)
    \\              --min-tier T     lowest tier walked on the ladder and scanned for
    \\                               matches (e.g. PLATINUM: Platinum IV and up;
    \\                               default IRON, everyone)
    \\              --reserve PCT    leave PCT of each rate limit to other processes
    \\                               on the key while one is using it (default 0)
    \\  stats       write the model file the app reads (ranked solo, no remakes)
    \\              --patch P        patch to include, repeatable or comma separated
    \\                               (default: the newest patch)
    \\              --out FILE       default DIR/export/stats-<patch>.bin
    \\              --platform P     Riot platform id, repeatable or comma separated
    \\                               (default EUW1; "all" for every platform in
    \\                               riot/endpoints.zig)
    \\  curves      write lane matchup curves from match timelines (curvesfile.zig)
    \\              --patch P        as for stats (default: every patch of the last
    \\                               --days, to DIR/export/recent-curves.bin)
    \\              --days N         default 30
    \\              --platform P     as for stats
    \\              --out FILE       default DIR/export/curves-<patch>.bin (all-curves-...
    \\                               and all-recent-curves.bin with --platform all)
    \\              --min-games N    leave out matchups with fewer games (default 1: all)
    \\  builds      write what players build per champion and role (builds.zig): runes,
    \\              summoner spells, starting items, boots, first items, skill order;
    \\              JSON the site reads (needs Data Dragon)
    \\              --patch P        as for stats (default: the newest patch)
    \\              --platform P     as for stats
    \\              --min-tier T     lowest rank counted, per player (default PLATINUM;
    \\                               "any" counts everyone, unranked too)
    \\              --max-keys N     distinct options held in memory (default 524288)
    \\              --out FILE       default DIR/export/builds-<patch>.json
    \\                               (all-builds-... with --platform all)
    \\  pool        write what players of each champion also play (pool.zig), as JSON
    \\              --patch P        as for stats (matchups); pools use every patch
    \\              --platform P     as for stats
    \\              --out FILE       default DIR/export/pool.json
    \\  eval        how well the draft model predicts held-out newer games (markdown
    \\              report on stdout; docs/model.md)
    \\              --patch P        as for stats (default: every patch, pooled)
    \\              --platform P     as for stats
    \\              --test-share F   newest share of games held out (default 0.2)
    \\              --folds K        folds for tuning inside train (default 5)
    \\              --test-platform P  test on P's games only; compares training on P
    \\                               alone with every --platform pooled
    \\              --history FILE   append one TSV line (date, sizes, log loss and AUC
    \\                               per model) for the accuracy-vs-data curve
    \\  site       write the public website (static files): EUW over the last 30 days
    \\              at the root, the patch under patch/, every region under all/ and
    \\              all/patch/ (lane curves and builds: the curves and builds
    \\              commands' default files)
    \\              --patch P        the patch views' (default: EUW's newest patch)
    \\              --out DIR        default DIR/site
    \\              --contact EMAIL  shown on the privacy and terms pages (required)
    \\              --riot-txt TEXT  served as /riot.txt (Riot's verification string)
    \\              --public         listed for search engines, no preview banner; only
    \\                               once Riot grants the production key
    \\              --euw-only       the EUW views only (root, patch/): a quick preview
    \\              --static-min-games N  leave out matchup pages under N games (for
    \\                               `render` to serve on request)
    \\  dev        work on the site: pages rendered on request from DIR (data loaded
    \\              once), CSS and JS from src/site/static, live reload; run by
    \\              deploy/dev.sh, which rebuilds on edits. Takes site's flags
    \\              --port P         default 8080
    \\  render     the pages `site --static-min-games` leaves out, rendered on request
    \\              for the web server's nginx (all views loaded up front). Takes
    \\              site's flags (--contact required)
    \\              --host H         default 127.0.0.1 (local only)
    \\              --port P         default 8091
    \\              --reload FILE    load the data again whenever FILE changes
    \\              --ready FILE     written once listening. Several may share the
    \\                               port (SO_REUSEPORT): deploy/render-swap.sh
    \\  serve       serve the website (default DIR/site) over HTTP, for the tunnel
    \\              --host H         default 127.0.0.1 (local only)
    \\              --port P         default 8080
    \\              --out DIR        site directory to serve
    \\  api         the "Your games" service: JSON at /api/ (src/api/root.zig; needs
    \\              RIOT_API_KEY). Cache in DIR/api.db
    \\              --host H         default 127.0.0.1 (local only)
    \\              --port P         default 8090
    \\              --exchange DIR   shared with the box: curves/ in, forgotten
    \\                               PUUID lists both ways (docs/your-games.md)
    \\              --curves DIR     curves-<patch>.bin files (default EXCHANGE/curves,
    \\                               else DIR/export)
    \\              --budget SPEC    Riot calls per route, Riot's format (default 20:120)
    \\              --cors ORIGIN    allow a page on ORIGIN (local testing)
    \\  status      row counts and crawl queue state
    \\  admin       private ops page (src/admin.zig): crawl rates from the crawl log,
    \\              storage growth (appends DIR/admin-history.tsv), ingest mix, queues
    \\              --out DIR        default DIR/admin
    \\              --log FILE       crawler log (default DIR/crawl.log)
    \\              --days N         history shown (default 7)
    \\              --disk "S U A"   data disk size, used, available in bytes
    \\              --health TEXT    deploy/health.sh output
    \\  rebuild     re-parse kept raw match JSON into the normalised tables, and
    \\              refill participants columns taken from timelines
    \\  rekey       after switching to another app's key (new PUUIDs): forget
    \\              players, ladder and mastery, keep matches; run rebuild first
    \\  champions   refresh champion ids and names from Data Dragon
    \\  draft-backfill  add the draft rows (kept forever) of matches stored before the
    \\              drafts table existed; once, alongside the crawler
    \\              --chunk N        matches per transaction (default 200)
    \\              --pause-ms MS    between chunks, so the crawler gets the lock
    \\                               (default 1000)
    \\  backup      consistent copy of tables and compact timelines (docs/data-safety.md)
    \\              --out DIR        default $MEIOLOL_BACKUPS or ./backups
    \\              --keep-daily N   state snapshots kept (default 7)
    \\              --keep-weekly N  plus the newest of N weeks (default 4)
    \\              --full           one segment with every match, replacing the rest
    \\  restore     rebuild --data DIR (no database there yet) from a backup
    \\              --from DIR       backup directory
    \\              --state FILE     state snapshot (default the newest)
    \\  forget      erase players from every table (docs/data-safety.md)
    \\              --puuid P        repeatable
    \\              --riot-id N#T    repeatable; needs RIOT_API_KEY
    \\              --list FILE      one PUUID or Riot ID per line (erasure lists)
    \\              --backups DIR    also scrub every backup file there
    \\              --export FILE    write every forgotten PUUID there, one per line
    \\
    \\options for all commands:
    \\  --data DIR  data directory (default $MEIOLOL_DATA or ./data)
    \\
    \\exit codes: 0 ok, 1 error, 2 bad usage, 3 Riot rejected the API key
    \\
;

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
    try std.Io.Dir.cwd().createDirPath(init.io, c.data_dir);
    return run(&c) catch |err| switch (err) {
        error.Usage => usageError(c.flag),
        // Logged where it happened
        error.NoApiKey => 1,
        else => err,
    };
}

const commands = std.StaticStringMap(*const fn (*Cmd) anyerror!u8).initComptime(.{
    .{ "crawl", cmdCrawl },
    .{ "stats", cmdStats },
    .{ "curves", cmdCurves },
    .{ "builds", cmdBuilds },
    .{ "pool", cmdPool },
    .{ "eval", cmdEval },
    .{ "site", cmdSite },
    .{ "serve", cmdServe },
    .{ "dev", cmdDev },
    .{ "render", cmdRender },
    .{ "api", cmdApi },
    .{ "status", cmdStatus },
    .{ "admin", cmdAdmin },
    .{ "rebuild", cmdRebuild },
    .{ "rekey", cmdRekey },
    .{ "champions", cmdChampions },
    .{ "draft-backfill", cmdDraftBackfill },
    .{ "backup", cmdBackup },
    .{ "restore", cmdRestore },
    .{ "forget", cmdForget },
});

/// What a command gets: the process, the data directory and a cursor over its own
/// flags. A flag it doesn't take, or a bad value, is error.Usage (exit 2)
const Cmd = struct {
    init: std.process.Init,
    arena: std.mem.Allocator,
    data_dir: []const u8,
    args: []const []const u8 = &.{},
    i: usize = 0,
    /// The flag being read, named in the usage error
    flag: ?[]const u8 = null,

    fn next(c: *Cmd) ?[]const u8 {
        if (c.i >= c.args.len) return null;
        c.flag = c.args[c.i];
        c.i += 1;
        return c.flag;
    }

    fn is(c: *const Cmd, name: []const u8) bool {
        return std.mem.eql(u8, c.flag.?, name);
    }

    /// The current flag's value
    fn value(c: *Cmd) error{Usage}![]const u8 {
        if (c.i >= c.args.len) return error.Usage;
        c.i += 1;
        return c.args[c.i - 1];
    }

    fn int(c: *Cmd, comptime T: type) error{Usage}!T {
        return std.fmt.parseInt(T, try c.value(), 10) catch error.Usage;
    }

    fn float(c: *Cmd) error{Usage}!f64 {
        return std.fmt.parseFloat(f64, try c.value()) catch error.Usage;
    }

    /// A comma separated value, split
    fn list(c: *Cmd) ![]const []const u8 {
        var out: std.ArrayList([]const u8) = .empty;
        var it = std.mem.tokenizeScalar(u8, try c.value(), ',');
        while (it.next()) |v| try out.append(c.arena, v);
        return out.items;
    }

    fn noFlags(c: *Cmd) error{Usage}!void {
        if (c.next() != null) return error.Usage;
    }

    fn required(c: *Cmd, v: ?[]const u8, name: []const u8) error{Usage}![]const u8 {
        c.flag = name;
        return v orelse error.Usage;
    }

    fn open(c: *const Cmd) !store.Db {
        return store.open(c.init.gpa, c.data_dir);
    }

    /// RIOT_API_KEY from the environment, else from ./.env
    fn apiKey(c: *const Cmd) ![]const u8 {
        if (c.init.environ_map.get("RIOT_API_KEY")) |k| return k;
        const text = std.Io.Dir.cwd().readFileAlloc(c.init.io, ".env", c.arena, .limited(64 * 1024)) catch |err| switch (err) {
            error.FileNotFound => "",
            else => return err,
        };
        var lines = std.mem.tokenizeAny(u8, text, "\r\n");
        while (lines.next()) |line| {
            const eq = std.mem.indexOfScalar(u8, line, '=') orelse continue;
            if (std.mem.eql(u8, std.mem.trim(u8, line[0..eq], " "), "RIOT_API_KEY")) {
                return std.mem.trim(u8, line[eq + 1 ..], " \"'");
            }
        }
        std.log.err("RIOT_API_KEY not set (env or .env)", .{});
        return error.NoApiKey;
    }
};

/// --patch and --platform: the games stats, curves, pool and eval read
const Games = struct {
    patches: std.ArrayList([]const u8) = .empty,
    platforms: std.ArrayList([]const u8) = .empty,
    /// --platform all: output files get the all- prefix
    every_platform: bool = false,

    /// Reads the current flag if it is one of these
    fn parse(g: *Games, c: *Cmd) !bool {
        if (c.is("--patch")) {
            try g.patches.appendSlice(c.arena, try c.list());
        } else if (c.is("--platform")) {
            for (try c.list()) |p| {
                if (std.mem.eql(u8, p, "all")) {
                    g.every_platform = true;
                    for (riot.endpoints.platforms) |pl| try g.platforms.append(c.arena, pl.id);
                } else try g.platforms.append(c.arena, p);
            }
        } else return false;
        return true;
    }

    /// EUW1 unless given: the site says EUW
    fn platformIds(g: *const Games) []const []const u8 {
        return if (g.platforms.items.len > 0) g.platforms.items else &.{"EUW1"};
    }
};

fn cmdCrawl(c: *Cmd) !u8 {
    var o: riot.crawl.Options = .{ .data_dir = c.data_dir, .key = "" };
    var regions: std.ArrayList(riot.endpoints.Region) = .empty;
    var fake_api_ms: ?u32 = null;
    while (c.next()) |_| {
        if (c.is("--no-mastery")) {
            o.mastery = false;
        } else if (c.is("--no-participant-players")) {
            o.participant_players = false;
        } else if (c.is("--hours")) {
            o.hours = try c.float();
        } else if (c.is("--since-days")) {
            o.since_days = try c.int(i64);
        } else if (c.is("--patch-only")) {
            o.patch_only = true;
        } else if (c.is("--no-active-first")) {
            o.active_first = false;
        } else if (c.is("--ladder-refresh-hours")) {
            o.ladder_refresh_s = try c.int(i64) * 3600;
        } else if (c.is("--ladder-refresh-days")) {
            o.ladder_refresh_s = try c.int(i64) * std.time.s_per_day;
        } else if (c.is("--ladder-per-hour")) {
            o.ladder_per_hour = try c.int(u32);
        } else if (c.is("--player-sample")) {
            o.player_sample = try c.int(u32);
        } else if (c.is("--keep-days")) {
            o.keep_days = try c.int(u32);
        } else if (c.is("--cache-mb")) {
            o.cache_mb = try c.int(u32);
        } else if (c.is("--regions")) {
            for (try c.list()) |r| {
                const region = std.meta.stringToEnum(riot.endpoints.Region, r) orelse return error.Usage;
                try regions.append(c.arena, region);
            }
        } else if (c.is("--timelines")) {
            o.timeline_percent = try c.int(u8);
            if (o.timeline_percent > 100) return error.Usage;
        } else if (c.is("--raw-timeline-days")) {
            o.raw_timeline_days = try c.int(u32);
        } else if (c.is("--raw-match-days")) {
            o.raw_match_days = try c.int(u32);
        } else if (c.is("--priority")) {
            var priority: std.ArrayList([]const u8) = .empty;
            for (try c.list()) |p| {
                if (std.mem.eql(u8, p, "none")) continue;
                if (riot.endpoints.platform(p) == null) return error.Usage;
                try priority.append(c.arena, p);
            }
            o.priority = priority.items;
        } else if (c.is("--min-tier")) {
            const tier = try c.value();
            o.min_tier = for (store.schema.tiers, 0..) |t, i| {
                if (std.ascii.eqlIgnoreCase(t, tier)) break i;
            } else return error.Usage;
        } else if (c.is("--reserve")) {
            o.reserve_pct = try c.int(u8);
            if (o.reserve_pct > 90) return error.Usage;
        } else if (c.is("--fake-api")) {
            // Benchmark only, not in usage: canned answers after MS ms (deploy/bench-crawl.sh)
            fake_api_ms = try c.int(u32);
        } else return error.Usage;
    }
    if (regions.items.len > 0) o.regions = regions.items;
    var fake: ?riot.fake.Fake = if (fake_api_ms) |ms| try .init(c.init.gpa, c.init.io, ms) else null;
    defer if (fake) |*f| f.deinit(c.init.gpa);
    if (fake) |*f| {
        o.fake = f;
        o.key = "fake";
    } else o.key = try c.apiKey();
    var crawler: riot.crawl.Crawler = .{ .gpa = c.init.gpa, .io = c.init.io, .opts = o };
    crawler.run() catch |err| switch (err) {
        error.KeyRejected => return 3,
        else => return err,
    };
    return 0;
}

fn cmdStats(c: *Cmd) !u8 {
    var g: Games = .{};
    var out: ?[]const u8 = null;
    while (c.next()) |_| {
        if (try g.parse(c)) continue;
        if (c.is("--out")) out = try c.value() else return error.Usage;
    }
    const io = c.init.io;
    const db = try c.open();
    defer db.close();
    const platforms = g.platformIds();
    const chosen = if (g.patches.items.len > 0) g.patches.items else try newestPatch(c.arena, db, platforms);
    var label_buf: [core.statsfile.patch_len]u8 = undefined;
    const label = try stats.label(&label_buf, chosen);
    const path = out orelse
        try std.fmt.allocPrint(c.arena, "{s}/export/stats-{s}.bin", .{ c.data_dir, label });

    var r = try stats.build(c.init.gpa, db, chosen, platforms);
    defer r.builder.deinit();
    if (r.summary.games == 0) {
        std.log.err("no complete ranked solo games on patch {s}", .{label});
        return error.NoMatches;
    }
    var file = try std.Io.Dir.cwd().createFileAtomic(io, path, .{ .make_path = true, .replace = true });
    defer file.deinit(io);
    var buf: [64 * 1024]u8 = undefined;
    var w = file.file.writer(io, &buf);
    try r.builder.write(&w.interface, label);
    try w.interface.flush();
    try file.replace(io);
    std.log.info("{s}: patch {s}, {d} games ({d} skipped), {d} champions", .{
        path, label, r.summary.games, r.summary.skipped, r.builder.ids.len,
    });
    return 0;
}

fn cmdCurves(c: *Cmd) !u8 {
    var g: Games = .{};
    var out: ?[]const u8 = null;
    var days: u32 = 30;
    var min_games: u32 = 1;
    while (c.next()) |_| {
        if (try g.parse(c)) continue;
        if (c.is("--out")) {
            out = try c.value();
        } else if (c.is("--days")) {
            days = try c.int(u32);
        } else if (c.is("--min-games")) {
            min_games = try c.int(u32);
        } else return error.Usage;
    }
    const gpa = c.init.gpa;
    const io = c.init.io;
    const db = try c.open();
    defer db.close();
    const wanted = g.patches.items;
    const platforms = g.platformIds();
    var label_buf: [core.statsfile.patch_len]u8 = undefined;
    const label = if (wanted.len > 0)
        try stats.label(&label_buf, wanted)
    else
        try std.fmt.bufPrint(&label_buf, "last {d} days", .{days});
    const path = out orelse if (wanted.len > 0)
        try curvesPath(c.arena, c.data_dir, wanted, g.every_platform)
    else
        try recentCurvesPath(c.arena, c.data_dir, g.every_platform);
    const now_ms = std.Io.Clock.real.now(io).toMilliseconds();
    const since_ms: i64 = if (wanted.len > 0) 0 else now_ms - @as(i64, days) * std.time.ms_per_day;
    const item_patch = if (wanted.len > 0) wanted[0] else (try newestPatch(c.arena, db, platforms))[0];

    const legendaries = ddragon.legendaries(gpa, io, item_patch) catch |err| blk: {
        std.log.warn("no item list from Data Dragon ({t}): curves without first items", .{err});
        break :blk &.{};
    };
    defer gpa.free(legendaries);
    var r = try curves.build(gpa, db, wanted, since_ms, platforms, legendaries);
    defer r.builder.deinit();
    if (r.summary.games == 0) {
        std.log.err("no ranked solo games with timelines for {s}", .{label});
        return error.NoMatches;
    }
    var file = try std.Io.Dir.cwd().createFileAtomic(io, path, .{ .make_path = true, .replace = true });
    defer file.deinit(io);
    var buf: [64 * 1024]u8 = undefined;
    var w = file.file.writer(io, &buf);
    try r.builder.write(&w.interface, label, min_games);
    try w.interface.flush();
    try file.replace(io);
    std.log.info("{s}: {s}, {d} games ({d} skipped)", .{
        path, label, r.summary.games, r.summary.skipped,
    });
    return 0;
}

fn cmdBuilds(c: *Cmd) !u8 {
    var g: Games = .{};
    var out: ?[]const u8 = null;
    var o: builds.Options = .{ .patches = &.{}, .platforms = &.{} };
    while (c.next()) |_| {
        if (try g.parse(c)) continue;
        if (c.is("--out")) {
            out = try c.value();
        } else if (c.is("--min-tier")) {
            const t = try c.value();
            o.min_tier = if (std.mem.eql(u8, t, "any")) null else t;
        } else if (c.is("--max-keys")) {
            o.max_keys = try c.int(usize);
        } else return error.Usage;
    }
    const gpa = c.init.gpa;
    const io = c.init.io;
    const db = try c.open();
    defer db.close();
    o.platforms = g.platformIds();
    o.patches = if (g.patches.items.len > 0) g.patches.items else try newestPatch(c.arena, db, o.platforms);
    var label_buf: [core.statsfile.patch_len]u8 = undefined;
    const label = try stats.label(&label_buf, o.patches);
    const path = out orelse try buildsPath(c.arena, c.data_dir, o.patches, g.every_platform);
    const data = try ddragon.buildData(gpa, c.arena, io, o.patches[0]);

    var b = try builds.build(gpa, db, &data, o);
    defer b.deinit();
    if (b.games == 0) {
        std.log.err("no ranked solo games on patch {s}", .{label});
        return error.NoMatches;
    }
    const f = try b.file(c.arena, &data, label, o.min_tier orelse "", o.rows);
    var file = try std.Io.Dir.cwd().createFileAtomic(io, path, .{ .make_path = true, .replace = true });
    defer file.deinit(io);
    var buf: [64 * 1024]u8 = undefined;
    var w = file.file.writer(io, &buf);
    try std.json.Stringify.value(f, .{}, &w.interface);
    try w.interface.flush();
    try file.replace(io);
    std.log.info("{s}: patch {s}, {d} games ({d} with timelines), {d} champion roles, {d} options held", .{
        path, label, b.games, b.timelines, f.builds.len, b.options.count(),
    });
    return 0;
}

fn cmdPool(c: *Cmd) !u8 {
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

fn cmdEval(c: *Cmd) !u8 {
    var g: Games = .{};
    var o: eval.Options = .{};
    var history: ?[]const u8 = null;
    while (c.next()) |_| {
        if (try g.parse(c)) continue;
        if (c.is("--test-share")) {
            o.test_share = try c.float();
            if (!(o.test_share > 0 and o.test_share < 1)) return error.Usage;
        } else if (c.is("--folds")) {
            o.folds = try c.int(u32);
            if (o.folds < 2) return error.Usage;
        } else if (c.is("--test-platform")) {
            o.test_platform = try c.value();
        } else if (c.is("--history")) {
            history = try c.value();
        } else return error.Usage;
    }
    const io = c.init.io;
    const db = try c.open();
    defer db.close();
    const platforms = g.platformIds();
    const chosen = if (g.patches.items.len > 0) g.patches.items else try stats.patches(c.arena, db, platforms);
    var buf: [64 * 1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(io, &buf);
    const line = try eval.run(c.init.gpa, db, chosen, platforms, o, &stdout.interface);
    try stdout.interface.flush();
    if (history) |path| {
        const today: Date = .fromMs(std.Io.Clock.real.now(io).toMilliseconds());
        try eval.appendHistory(io, path, line, try std.fmt.allocPrint(c.arena, "{f}", .{today}));
    }
    return 0;
}

/// Flags `site` and `dev` share
const SiteFlags = struct {
    patches: std.ArrayList([]const u8) = .empty,
    out: ?[]const u8 = null,
    contact: ?[]const u8 = null,
    riot_txt: ?[]const u8 = null,
    public: bool = false,
    euw_only: bool = false,
    static_min_games: u32 = 0,

    /// False for a flag that isn't one of these
    fn parse(f: *SiteFlags, c: *Cmd) !bool {
        if (c.is("--patch")) {
            try f.patches.appendSlice(c.arena, try c.list());
        } else if (c.is("--out")) {
            f.out = try c.value();
        } else if (c.is("--contact")) {
            f.contact = try c.value();
        } else if (c.is("--riot-txt")) {
            f.riot_txt = try c.value();
        } else if (c.is("--public")) {
            f.public = true;
        } else if (c.is("--euw-only")) {
            f.euw_only = true;
        } else if (c.is("--static-min-games")) {
            f.static_min_games = try c.int(u32);
        } else return false;
        return true;
    }

    /// Allocated in `arena`, which must outlive the options
    fn options(f: *const SiteFlags, c: *Cmd, arena: std.mem.Allocator, db: store.Db, contact: []const u8) !site.Options {
        const chosen = if (f.patches.items.len > 0) f.patches.items else try newestPatch(arena, db, &.{"EUW1"});
        var every: std.ArrayList([]const u8) = .empty;
        for (riot.endpoints.platforms) |pl| try every.append(arena, pl.id);
        const now_ms = std.Io.Clock.real.now(c.init.io).toMilliseconds();
        return .{
            .out_dir = f.out orelse try std.fs.path.join(arena, &.{ c.data_dir, "site" }),
            .patches = chosen,
            .since_ms = now_ms - 30 * std.time.ms_per_day,
            .all_platforms = every.items,
            .contact = contact,
            .riot_txt = f.riot_txt,
            .updated = try std.fmt.allocPrint(arena, "{f}", .{Date.fromMs(now_ms).long()}),
            .public = f.public,
            .euw_only = f.euw_only,
            .static_min_games = f.static_min_games,
            .daily_dir = try std.fs.path.join(arena, &.{ c.data_dir, "daily" }),
            // Indexed by site.html.View.index: EUW 30 days, EUW patch, all 30 days, all patch
            .curves = .{
                try recentCurvesPath(arena, c.data_dir, false),
                try curvesPath(arena, c.data_dir, chosen, false),
                try recentCurvesPath(arena, c.data_dir, true),
                try curvesPath(arena, c.data_dir, chosen, true),
            },
            .builds = .{
                null,
                try buildsPath(arena, c.data_dir, chosen, false),
                null,
                try buildsPath(arena, c.data_dir, chosen, true),
            },
        };
    }
};

fn cmdSite(c: *Cmd) !u8 {
    var f: SiteFlags = .{};
    while (c.next()) |_| {
        if (!try f.parse(c)) return error.Usage;
    }
    const email = try c.required(f.contact, "--contact");
    const db = try c.open();
    defer db.close();
    try site.generate(c.init.gpa, c.init.io, db, try f.options(c, c.arena, db, email));
    return 0;
}

/// Pages rendered on request from data loaded once, CSS and JS from src/site/static, and
/// the browser reloading after an edit (deploy/dev.sh rebuilds the binary)
fn cmdDev(c: *Cmd) !u8 {
    var f: SiteFlags = .{};
    var port: u16 = 8080;
    while (c.next()) |_| {
        if (c.is("--port")) {
            port = try c.int(u16);
        } else if (!try f.parse(c)) return error.Usage;
    }
    const static_dir = "src/site/static";
    const dev: serve.Dev = try .init(c.arena, c.init.io, try c.init.minimal.args.toSlice(c.arena), static_dir);
    const db = try c.open();
    defer db.close();
    var opts = try f.options(c, c.arena, db, f.contact orelse "dev@example.com");
    opts.static_dir = static_dir;
    const loaded = try site.Loaded.init(c.init.gpa, c.init.io, db, opts);
    const rendered = serve.Rendered.init(c.init.gpa, c.init.io, loaded, null) catch |err| {
        loaded.deinit();
        return err;
    };
    defer rendered.deinit();
    // Before listening, so the browser reloads once it is ready; the others on request
    _ = try loaded.site(site.html.View.all[0]);
    try serve.run(c.init.gpa, c.init.io, .{
        .port = port,
        .render = rendered,
        .dev = dev,
    });
    return 0;
}

/// The pages the static build leaves out (--static-min-games), rendered on request for
/// the web server's nginx (docs/hosting.md "Rendering on request"), loaded again whenever
/// the --reload file changes. Beside a running instance (a deploy: deploy/render-swap.sh)
/// it loads every view, then listens too (SO_REUSEPORT) and is --ready for the old one
/// to stop. Alone (a boot), it listens at once and serves each view as it loads, the
/// rest answering 503
fn cmdRender(c: *Cmd) !u8 {
    var f: SiteFlags = .{};
    var host: []const u8 = "127.0.0.1";
    var port: u16 = 8091;
    var reload: ?[]const u8 = null;
    var ready: ?[]const u8 = null;
    while (c.next()) |_| {
        if (c.is("--host")) {
            host = try c.value();
        } else if (c.is("--port")) {
            port = try c.int(u16);
        } else if (c.is("--reload")) {
            reload = try c.value();
        } else if (c.is("--ready")) {
            ready = try c.value();
        } else if (!try f.parse(c)) return error.Usage;
    }
    const email = try c.required(f.contact, "--contact");
    const gpa = c.init.gpa;
    const io = c.init.io;
    const db = try c.open();
    defer db.close();
    const alone = !listening(io, host, port);
    const first = try prepare(c, &f, db, email);
    first.loaded.lazy = false;
    if (!alone) loadViews(first.loaded) catch |err| {
        first.free(gpa);
        return err;
    };
    const rendered = serve.Rendered.init(gpa, io, first.loaded, first.arena) catch |err| {
        first.free(gpa);
        return err;
    };
    defer rendered.deinit();
    var group: std.Io.Group = .init;
    defer group.cancel(io);
    group.async(io, background, .{ c, &f, db, email, rendered, if (alone) first.loaded else null, if (alone) ready else null, reload });
    try serve.run(gpa, io, .{ .host = host, .port = port, .render = rendered, .ready = if (alone) null else ready });
    return 0;
}

/// Whether something already listens at host:port: an older renderer
fn listening(io: std.Io, host: []const u8, port: u16) bool {
    const address = std.Io.net.IpAddress.parse(host, port) catch return false;
    const stream = address.connect(io, .{ .mode = .stream }) catch return false;
    stream.close(io);
    return true;
}

/// The database's only user once the server runs: the first load when serving early
/// (exiting on failure, for systemd to start again), then reloads
fn background(c: *Cmd, f: *const SiteFlags, db: store.Db, contact: []const u8, rendered: *serve.Rendered, first: ?*site.Loaded, ready: ?[]const u8, reload: ?[]const u8) void {
    const io = c.init.io;
    if (first) |l| {
        loadViews(l) catch |err| {
            std.log.err("render load: {t}", .{err});
            std.process.exit(1);
        };
        if (ready) |path| std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = "" }) catch |err| {
            std.log.warn("render ready file: {t}", .{err});
        };
    }
    if (reload) |path| reloadOnChange(c, f, db, contact, rendered, path);
}

const LoadedAll = struct {
    loaded: *site.Loaded,
    /// The options' strings
    arena: *std.heap.ArenaAllocator,

    fn free(l: LoadedAll, gpa: std.mem.Allocator) void {
        l.loaded.deinit();
        l.arena.deinit();
        gpa.destroy(l.arena);
    }
};

/// Options as of now (patch, 30-day window), no view loaded yet
fn prepare(c: *Cmd, f: *const SiteFlags, db: store.Db, contact: []const u8) !LoadedAll {
    const gpa = c.init.gpa;
    const arena = try gpa.create(std.heap.ArenaAllocator);
    arena.* = .init(gpa);
    errdefer {
        arena.deinit();
        gpa.destroy(arena);
    }
    const opts = try f.options(c, arena.allocator(), db, contact);
    return .{ .loaded = try site.Loaded.init(gpa, c.init.io, db, opts), .arena = arena };
}

/// Every view, the root (most visited) and the shared one first
fn loadViews(loaded: *site.Loaded) !void {
    for (site.html.View.all) |v| {
        if (loaded.opts.euw_only and v.region != .euw) continue;
        try loaded.loadView(v);
    }
}

/// prepare and loadViews: every view loaded, not on its first request
fn loadAll(c: *Cmd, f: *const SiteFlags, db: store.Db, contact: []const u8) !LoadedAll {
    const l = try prepare(c, f, db, contact);
    errdefer l.free(c.init.gpa);
    l.loaded.lazy = false;
    try loadViews(l.loaded);
    return l;
}

/// Swaps in freshly loaded data whenever `path`'s mtime moves (deploy/web-loop.sh touches
/// it after each upload); on a failed load the old data stays
fn reloadOnChange(c: *Cmd, f: *const SiteFlags, db: store.Db, contact: []const u8, rendered: *serve.Rendered, path: []const u8) void {
    const io = c.init.io;
    var seen = fileMtime(io, path);
    while (true) {
        io.sleep(.fromMilliseconds(10_000), .awake) catch return;
        const now = fileMtime(io, path);
        if (now == seen) continue;
        seen = now;
        const start = std.Io.Clock.real.now(io).toMilliseconds();
        const next = loadAll(c, f, db, contact) catch |err| {
            std.log.warn("render reload: {t}", .{err});
            continue;
        };
        rendered.swap(next.loaded, next.arena) catch |err| {
            next.free(c.init.gpa);
            std.log.warn("render reload: {t}", .{err});
            continue;
        };
        std.log.info("render: reloaded in {d} s", .{@divTrunc(std.Io.Clock.real.now(io).toMilliseconds() - start, 1000)});
    }
}

fn fileMtime(io: std.Io, path: []const u8) i96 {
    const st = std.Io.Dir.cwd().statFile(io, path, .{}) catch return 0;
    return st.mtime.toNanoseconds();
}

fn cmdServe(c: *Cmd) !u8 {
    var dir: ?[]const u8 = null;
    var host: []const u8 = "127.0.0.1";
    var port: u16 = 8080;
    while (c.next()) |_| {
        if (c.is("--out")) {
            dir = try c.value();
        } else if (c.is("--host")) {
            host = try c.value();
        } else if (c.is("--port")) {
            port = try c.int(u16);
        } else return error.Usage;
    }
    const root = dir orelse try std.fs.path.join(c.arena, &.{ c.data_dir, "site" });
    try serve.run(c.init.gpa, c.init.io, .{ .root = root, .host = host, .port = port });
    return 0;
}

fn cmdApi(c: *Cmd) !u8 {
    var o: api.Options = .{ .db_path = "", .curves_dir = "", .key = "" };
    var curves_dir: ?[]const u8 = null;
    while (c.next()) |_| {
        if (c.is("--host")) {
            o.host = try c.value();
        } else if (c.is("--port")) {
            o.port = try c.int(u16);
        } else if (c.is("--exchange")) {
            o.fetch.exchange_dir = try c.value();
        } else if (c.is("--curves")) {
            curves_dir = try c.value();
        } else if (c.is("--budget")) {
            o.fetch.budget = try c.value();
        } else if (c.is("--cors")) {
            o.cors = try c.value();
        } else return error.Usage;
    }
    const arena = c.arena;
    o.key = try c.apiKey();
    o.db_path = try std.fmt.allocPrintSentinel(arena, "{s}/api.db", .{c.data_dir}, 0);
    o.curves_dir = curves_dir orelse if (o.fetch.exchange_dir) |x|
        try std.fs.path.join(arena, &.{ x, "curves" })
    else
        try std.fs.path.join(arena, &.{ c.data_dir, "export" });
    try api.run(c.init.gpa, c.init.io, o);
    return 0;
}

fn cmdStatus(c: *Cmd) !u8 {
    try c.noFlags();
    try status(c.init.gpa, c.init.io, c.data_dir);
    return 0;
}

fn cmdAdmin(c: *Cmd) !u8 {
    const now = std.Io.Clock.real.now(c.init.io).toSeconds();
    var o: admin.Options = .{ .out_dir = "", .data_dir = c.data_dir, .crawl_log = "", .now_s = now };
    var out: ?[]const u8 = null;
    var log_path: ?[]const u8 = null;
    while (c.next()) |_| {
        if (c.is("--out")) {
            out = try c.value();
        } else if (c.is("--log")) {
            log_path = try c.value();
        } else if (c.is("--days")) {
            o.days = try c.int(u32);
        } else if (c.is("--disk")) {
            var words = std.mem.tokenizeScalar(u8, try c.value(), ' ');
            var d: [3]u64 = undefined;
            for (&d) |*x| x.* = std.fmt.parseInt(u64, words.next() orelse return error.Usage, 10) catch return error.Usage;
            o.disk = d;
        } else if (c.is("--health")) {
            o.health = try c.value();
        } else return error.Usage;
    }
    o.out_dir = out orelse try std.fs.path.join(c.arena, &.{ c.data_dir, "admin" });
    o.crawl_log = log_path orelse try std.fs.path.join(c.arena, &.{ c.data_dir, "crawl.log" });
    const db = try store.open(c.init.gpa, c.data_dir);
    defer db.close();
    try admin.generate(c.init.gpa, c.init.io, db, o);
    return 0;
}

fn cmdRebuild(c: *Cmd) !u8 {
    try c.noFlags();
    const db = try c.open();
    defer db.close();
    std.log.info("{d} matches rebuilt", .{try riot.match.rebuild(c.init.gpa, db)});
    std.log.info("{d} timelines gave gold columns", .{try riot.crawl.rebuildGold(c.init.gpa, db)});
    return 0;
}

fn cmdRekey(c: *Cmd) !u8 {
    try c.noFlags();
    const db = try c.open();
    defer db.close();
    try store.schema.rekey(db);
    std.log.info("players, ladder and mastery cleared; matches kept", .{});
    return 0;
}

fn cmdChampions(c: *Cmd) !u8 {
    try c.noFlags();
    const db = try c.open();
    defer db.close();
    std.log.info("{d} champions", .{try ddragon.refresh(c.init.gpa, c.init.io, db)});
    return 0;
}

/// Resumable: the list shrinks as chunks commit
fn cmdDraftBackfill(c: *Cmd) !u8 {
    var chunk: usize = 200;
    var pause_ms: u32 = 1000;
    while (c.next()) |_| {
        if (c.is("--chunk")) {
            chunk = try c.int(usize);
            if (chunk == 0) return error.Usage;
        } else if (c.is("--pause-ms")) {
            pause_ms = try c.int(u32);
        } else return error.Usage;
    }
    const io = c.init.io;
    const db = try c.open();
    defer db.close();
    var b: store.draft.Builder = try .init(db);
    defer b.deinit();
    const left = try db.scalar("SELECT count(*) FROM draft_backfill", .{}) orelse 0;
    std.log.info("{d} matches to read", .{left});
    var taken: usize = 0;
    var written: usize = 0;
    var chunks: usize = 0;
    while (true) {
        const r = store.draft.backfillChunk(c.init.gpa, db, &b, chunk) catch |err| switch (err) {
            // The crawler's writer or a backup held the lock past the busy timeout
            error.Busy => {
                try io.sleep(.fromMilliseconds(pause_ms), .awake);
                continue;
            },
            else => return err,
        };
        if (r.taken == 0) break;
        taken += r.taken;
        written += r.written;
        chunks += 1;
        if (chunks % 50 == 0) std.log.info("{d} of {d} read, {d} rows", .{ taken, left, written });
        try io.sleep(.fromMilliseconds(pause_ms), .awake);
    }
    std.log.info("done: {d} matches read, {d} draft rows (the rest not complete ranked games)", .{
        taken, written,
    });
    return 0;
}

fn cmdBackup(c: *Cmd) !u8 {
    var o: backup.Options = .{
        .data_dir = c.data_dir,
        .out_dir = c.init.environ_map.get("MEIOLOL_BACKUPS") orelse "backups",
        .now = std.Io.Clock.real.now(c.init.io).toSeconds(),
    };
    while (c.next()) |_| {
        if (c.is("--out")) {
            o.out_dir = try c.value();
        } else if (c.is("--keep-daily")) {
            o.keep_daily = try c.int(usize);
        } else if (c.is("--keep-weekly")) {
            o.keep_weekly = try c.int(usize);
        } else if (c.is("--full")) {
            o.full = true;
        } else return error.Usage;
    }
    const r = try backup.run(c.arena, c.init.io, o);
    std.log.info("{s}; segment {s}: {d} matches, {d} timelines, {d} drafts; {d} old files removed", .{
        r.state, r.segment orelse "none (nothing new)", r.matches, r.timelines, r.drafts, r.removed,
    });
    return 0;
}

fn cmdRestore(c: *Cmd) !u8 {
    var from: ?[]const u8 = null;
    var state_file: ?[]const u8 = null;
    while (c.next()) |_| {
        if (c.is("--from")) {
            from = try c.value();
        } else if (c.is("--state")) {
            state_file = try c.value();
        } else return error.Usage;
    }
    const from_dir = try c.required(from, "--from");
    const now = std.Io.Clock.real.now(c.init.io).toSeconds();
    const r = backup.restore(c.arena, c.init.io, from_dir, c.data_dir, state_file, now) catch |err| {
        if (err == error.TargetNotEmpty) std.log.err("{s} holds a database: restore only into an empty directory", .{c.data_dir});
        return err;
    };
    std.log.info("{s}: {d} files, {d} matches, {d} timelines; {d} rows re-erased", .{
        c.data_dir, r.files, r.matches, r.timelines, r.removed.total(),
    });
    return 0;
}

/// Logs counts only: an erasure log naming the player would defeat the erasure. PUUIDs
/// already in `forgotten` are skipped, so complete lists can be fed in again and again.
fn cmdForget(c: *Cmd) !u8 {
    const io = c.init.io;
    const arena = c.arena;
    var id_list: std.ArrayList([]const u8) = .empty;
    // --list given: an empty list is fine (the exchange with the Your games service)
    var listed = false;
    var backups: ?[]const u8 = null;
    var export_path: ?[]const u8 = null;
    while (c.next()) |_| {
        if (c.is("--puuid") or c.is("--riot-id")) {
            try id_list.append(arena, try c.value());
        } else if (c.is("--list")) {
            listed = true;
            const text = try std.Io.Dir.cwd().readFileAlloc(io, try c.value(), arena, .limited(64 << 20));
            var lines = std.mem.tokenizeAny(u8, text, "\r\n");
            while (lines.next()) |line| {
                const t = std.mem.trim(u8, line, " \t");
                // Riot IDs hold '#', so only a leading one marks a comment
                if (t.len > 0 and t[0] != '#') try id_list.append(arena, t);
            }
        } else if (c.is("--backups")) {
            backups = try c.value();
        } else if (c.is("--export")) {
            export_path = try c.value();
        } else return error.Usage;
    }
    const ids = id_list.items;
    if (ids.len == 0 and !listed and export_path == null) {
        c.flag = "--puuid, --riot-id, --list or --export";
        return error.Usage;
    }
    const now = std.Io.Clock.real.now(io).toSeconds();
    var client: ?riot.client.Client = null;
    defer if (client) |*cl| cl.deinit();
    // The box holds the crawler databases, the web server the Your games cache; open
    // whichever this data directory has, never creating the other
    const cwd = std.Io.Dir.cwd();
    const crawl_path = try std.fs.path.join(arena, &.{ c.data_dir, "meiolol.db" });
    const api_path = try std.fs.path.joinZ(arena, &.{ c.data_dir, "api.db" });
    const db: ?store.Db = if (cwd.access(io, crawl_path, .{})) |_| try c.open() else |_| null;
    defer if (db) |d| d.close();
    const api_db: ?store.Db = if (cwd.access(io, api_path, .{})) |_| try api.cache.open(api_path) else |_| null;
    defer if (api_db) |d| d.close();
    if (db == null and api_db == null) {
        std.log.err("{s} holds neither meiolol.db nor api.db", .{c.data_dir});
        return 1;
    }
    var live: forget.Removed = .{};
    var scrubbed: forget.Removed = .{};
    var unresolved: usize = 0;
    var already: usize = 0;
    for (ids) |id| {
        const puuid = if (std.mem.indexOfScalar(u8, id, '#') == null) id else blk: {
            if (client == null) client = try .init(c.init.gpa, io, try c.apiKey());
            break :blk try forget.resolveRiotId(arena, &client.?, id) orelse {
                unresolved += 1;
                continue;
            };
        };
        if (api_db) |d| try api.cache.forget(d, puuid, now);
        const d = db orelse continue;
        if (try forget.isForgotten(d, puuid)) {
            already += 1;
            continue;
        }
        live.add(try forget.forget(d, puuid, now, .record));
        if (backups) |dir| scrubbed.add(try backup.scrub(arena, io, dir, puuid, now));
    }
    if (ids.len > 0) {
        std.log.info("{d} of {d} erased, {d} already forgotten; live rows: players {d}, " ++
            "mastery {d}, participants blanked {d}, raw matches {d}, raw timelines {d}", .{
            ids.len - unresolved - already,
            ids.len,
            already,
            live.players,
            live.mastery,
            live.participants,
            live.raw_matches,
            live.raw_timelines,
        });
    }
    if (api_db != null and ids.len > 0) std.log.info("Your games cache: erased and blocked", .{});
    if (backups != null) std.log.info("backup rows: {d}", .{scrubbed.total()});
    if (export_path) |path| {
        const d = db orelse {
            std.log.err("--export needs meiolol.db in {s}", .{c.data_dir});
            return 1;
        };
        std.log.info("{d} forgotten PUUIDs written to {s}", .{ try forget.exportList(io, d, path), path });
    }
    if (unresolved > 0) {
        std.log.warn("{d} Riot IDs have no account (renamed or deleted): resolve them by PUUID", .{unresolved});
        return 1;
    }
    return 0;
}

fn usageError(arg: ?[]const u8) u8 {
    if (arg) |a| std.log.err("unknown, incomplete or missing for this command: {s}", .{a});
    std.debug.print("{s}", .{usage});
    return 2;
}

/// Where `meiolol curves` writes by default for these patches. Every platform's files
/// start all-, out of the curves-*.bin the Your games service reads (EUW, per patch)
fn curvesPath(arena: std.mem.Allocator, data_dir: []const u8, chosen: []const []const u8, every: bool) ![]const u8 {
    var label_buf: [core.statsfile.patch_len]u8 = undefined;
    const label = try stats.label(&label_buf, chosen);
    return std.fmt.allocPrint(arena, "{s}/export/{s}curves-{s}.bin", .{ data_dir, allPrefix(every), label });
}

/// Where `meiolol curves` writes by default: every patch of the last --days. Not
/// curves-*.bin, which the Your games service reads as one file per patch
fn recentCurvesPath(arena: std.mem.Allocator, data_dir: []const u8, every: bool) ![]const u8 {
    return std.fmt.allocPrint(arena, "{s}/export/{s}recent-curves.bin", .{ data_dir, allPrefix(every) });
}

/// Where `meiolol builds` writes by default; the site reads the newest patch's
fn buildsPath(arena: std.mem.Allocator, data_dir: []const u8, chosen: []const []const u8, every: bool) ![]const u8 {
    var label_buf: [core.statsfile.patch_len]u8 = undefined;
    const label = try stats.label(&label_buf, chosen);
    return std.fmt.allocPrint(arena, "{s}/export/{s}builds-{s}.json", .{ data_dir, allPrefix(every), label });
}

fn allPrefix(every: bool) []const u8 {
    return if (every) "all-" else "";
}

fn newestPatch(arena: std.mem.Allocator, db: store.Db, platforms: []const []const u8) ![]const []const u8 {
    const all = try stats.patches(arena, db, platforms);
    if (all.len == 0) return error.NoMatches;
    return all[0..1];
}

fn status(gpa: std.mem.Allocator, io: std.Io, data_dir: []const u8) !void {
    const db = try store.open(gpa, data_dir);
    defer db.close();
    var buf: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(io, &buf);
    const out = &stdout.interface;
    const tables = .{
        "players",
        "ladder_pages",
        "match_queue",
        "matches",
        "participants",
        "bans",
        "mastery",
        "champions",
        "raw.raw_docs",
        "timeline_queue",
        "timeline.timelines",
        "raw.timeline_docs",
        "drafts",
        "draft_backfill",
    };
    inline for (tables) |t| {
        try out.print("{s}: {d}\n", .{ t, try db.scalar("SELECT count(*) FROM " ++ t, .{}) orelse 0 });
    }
    var q = try db.prepare("SELECT status, count(*) FROM match_queue GROUP BY 1 ORDER BY 1");
    defer q.deinit();
    try q.bind(.{});
    try out.writeAll("queue:");
    while (try q.step()) try out.print(" {s}={d}", .{ q.bytes(0), q.int(1) });
    var p = try db.prepare("SELECT patch, count(*) FROM matches GROUP BY 1 ORDER BY 1 DESC LIMIT 6");
    defer p.deinit();
    try p.bind(.{});
    try out.writeAll("\nby patch:");
    while (try p.step()) try out.print(" {s}={d}", .{ p.bytes(0), p.int(1) });
    try groups(db, out, "\nby platform:", "SELECT platform, count(*) FROM matches GROUP BY 1 ORDER BY 2 DESC");
    try groups(db, out, "\ntimelines:", "SELECT region || ' ' || status, count(*) FROM timeline_queue GROUP BY 1 ORDER BY 1");
    try groups(db, out, "\nplayers:", "SELECT region, count(*) FROM players GROUP BY 1 ORDER BY 2 DESC");
    try out.writeAll("\n");
    try out.flush();
}

fn groups(db: store.Db, out: *std.Io.Writer, label: []const u8, sql: []const u8) !void {
    var q = try db.prepare(sql);
    defer q.deinit();
    try q.bind(.{});
    try out.writeAll(label);
    while (try q.step()) try out.print(" {s}={d}", .{ q.bytes(0), q.int(1) });
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
