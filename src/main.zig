//! `meiolol`: backend. Crawls ranked solo games and timelines from the Riot API into SQLite
//! and builds the model file the app reads. Runs on the gpu-box PC (deploy/box.sh).

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
pub const pool = @import("pool.zig");
pub const learning = @import("learning.zig");
pub const patchday = @import("patchday.zig");
pub const eval = @import("eval.zig");
pub const api = @import("api/root.zig");
pub const backup = @import("backup.zig");
pub const forget = @import("forget.zig");

pub const std_options: std.Options = .{ .logFn = logFn };

const usage =
    \\usage: meiolol <command> [options]
    \\
    \\commands:
    \\  crawl       crawl ranked solo games (needs RIOT_API_KEY in env or .env)
    \\              --hours H        stop after H hours (default: run until stopped)
    \\              --since-days N   how far back to collect match ids (default 14)
    \\              --no-mastery     skip champion mastery
    \\              --ladder-refresh-days N  refetch ladder pages after N days
    \\                               (default 7)
    \\              --regions R      americas,asia,europe,sea (default all)
    \\              --timelines PCT  share of matches that also get a timeline
    \\                               (default 100, 0 for none)
    \\              --raw-timeline-days N  keep raw timeline JSON N days (default 7)
    \\              --raw-match-days N     keep raw match JSON N days (default 30,
    \\                                     0 forever)
    \\              --priority P     platforms whose players come first in their
    \\                               region (default EUW1, "none" for none)
    \\              --reserve PCT    leave PCT of each rate limit to other processes
    \\                               on the key (default 0)
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
    \\              all/patch/ (lane curves: the curves command's default files)
    \\              --patch P        the patch views' (default: EUW's newest patch)
    \\              --out DIR        default DIR/site
    \\              --contact EMAIL  shown on the privacy and terms pages (required)
    \\              --riot-txt TEXT  served as /riot.txt (Riot's verification string)
    \\              --public         listed for search engines, no preview banner; only
    \\                               once Riot grants the production key
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
    \\  rebuild     re-parse kept raw match JSON into the normalised tables, and
    \\              refill participants columns taken from timelines
    \\  rekey       after switching to another app's key (new PUUIDs): forget
    \\              players, ladder and mastery, keep matches; run rebuild first
    \\  champions   refresh champion ids and names from Data Dragon
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
    const args = try init.minimal.args.toSlice(arena);
    if (args.len < 2) return usageError(null);

    var data_dir: []const u8 = init.environ_map.get("MEIOLOL_DATA") orelse "data";
    var hours: ?f64 = null;
    var since_days: i64 = 14;
    var mastery = true;
    var patches: std.ArrayList([]const u8) = .empty;
    var platforms: std.ArrayList([]const u8) = .empty;
    var every_platform = false;
    var regions: std.ArrayList(riot.endpoints.Region) = .empty;
    var timeline_percent: u8 = 100;
    var raw_timeline_days: u32 = 7;
    var raw_match_days: u32 = 30;
    var priority: ?[]const []const u8 = null;
    var reserve_pct: u8 = 0;
    var ladder_refresh_days: i64 = 7;
    var out_path: ?[]const u8 = null;
    var contact: ?[]const u8 = null;
    var riot_txt: ?[]const u8 = null;
    var public = false;
    var host: []const u8 = "127.0.0.1";
    var port: ?u16 = null;
    var curves_dir: ?[]const u8 = null;
    var budget: ?[]const u8 = null;
    var cors: ?[]const u8 = null;
    var exchange: ?[]const u8 = null;
    var min_games: u32 = 1;
    var days: u32 = 30;
    var eval_opts: eval.Options = .{};
    var history: ?[]const u8 = null;
    var keep_daily: usize = 7;
    var keep_weekly: usize = 4;
    var full = false;
    var from_dir: ?[]const u8 = null;
    var state_file: ?[]const u8 = null;
    var erase: ForgetArgs = .{};
    var i: usize = 2;
    while (i < args.len) : (i += 1) {
        const a = args[i];
        if (std.mem.eql(u8, a, "--no-mastery")) {
            mastery = false;
            continue;
        }
        if (std.mem.eql(u8, a, "--full")) {
            full = true;
            continue;
        }
        if (std.mem.eql(u8, a, "--public")) {
            public = true;
            continue;
        }
        if (i + 1 >= args.len) return usageError(a);
        const v = args[i + 1];
        i += 1;
        if (std.mem.eql(u8, a, "--data")) {
            data_dir = v;
        } else if (std.mem.eql(u8, a, "--hours")) {
            hours = std.fmt.parseFloat(f64, v) catch return usageError(a);
        } else if (std.mem.eql(u8, a, "--ladder-refresh-days")) {
            ladder_refresh_days = std.fmt.parseInt(i64, v, 10) catch return usageError(a);
        } else if (std.mem.eql(u8, a, "--since-days")) {
            since_days = std.fmt.parseInt(i64, v, 10) catch return usageError(a);
        } else if (std.mem.eql(u8, a, "--patch")) {
            var it = std.mem.tokenizeScalar(u8, v, ',');
            while (it.next()) |p| try patches.append(arena, p);
        } else if (std.mem.eql(u8, a, "--platform")) {
            var it = std.mem.tokenizeScalar(u8, v, ',');
            while (it.next()) |p| {
                if (std.mem.eql(u8, p, "all")) {
                    every_platform = true;
                    for (riot.endpoints.platforms) |pl| try platforms.append(arena, pl.id);
                } else try platforms.append(arena, p);
            }
        } else if (std.mem.eql(u8, a, "--regions")) {
            var it = std.mem.tokenizeScalar(u8, v, ',');
            while (it.next()) |r| {
                try regions.append(arena, std.meta.stringToEnum(riot.endpoints.Region, r) orelse
                    return usageError(a));
            }
        } else if (std.mem.eql(u8, a, "--timelines")) {
            timeline_percent = std.fmt.parseInt(u8, v, 10) catch return usageError(a);
            if (timeline_percent > 100) return usageError(a);
        } else if (std.mem.eql(u8, a, "--raw-timeline-days")) {
            raw_timeline_days = std.fmt.parseInt(u32, v, 10) catch return usageError(a);
        } else if (std.mem.eql(u8, a, "--raw-match-days")) {
            raw_match_days = std.fmt.parseInt(u32, v, 10) catch return usageError(a);
        } else if (std.mem.eql(u8, a, "--reserve")) {
            reserve_pct = std.fmt.parseInt(u8, v, 10) catch return usageError(a);
            if (reserve_pct > 90) return usageError(a);
        } else if (std.mem.eql(u8, a, "--priority")) {
            var list: std.ArrayList([]const u8) = .empty;
            var it = std.mem.tokenizeScalar(u8, v, ',');
            while (it.next()) |p| {
                if (std.mem.eql(u8, p, "none")) continue;
                if (riot.endpoints.platform(p) == null) return usageError(a);
                try list.append(arena, p);
            }
            priority = list.items;
        } else if (std.mem.eql(u8, a, "--out")) {
            out_path = v;
        } else if (std.mem.eql(u8, a, "--contact")) {
            contact = v;
        } else if (std.mem.eql(u8, a, "--host")) {
            host = v;
        } else if (std.mem.eql(u8, a, "--port")) {
            port = std.fmt.parseInt(u16, v, 10) catch return usageError(a);
        } else if (std.mem.eql(u8, a, "--min-games")) {
            min_games = std.fmt.parseInt(u32, v, 10) catch return usageError(a);
        } else if (std.mem.eql(u8, a, "--test-share")) {
            eval_opts.test_share = std.fmt.parseFloat(f64, v) catch return usageError(a);
            if (!(eval_opts.test_share > 0 and eval_opts.test_share < 1)) return usageError(a);
        } else if (std.mem.eql(u8, a, "--test-platform")) {
            eval_opts.test_platform = v;
        } else if (std.mem.eql(u8, a, "--history")) {
            history = v;
        } else if (std.mem.eql(u8, a, "--folds")) {
            eval_opts.folds = std.fmt.parseInt(u32, v, 10) catch return usageError(a);
            if (eval_opts.folds < 2) return usageError(a);
        } else if (std.mem.eql(u8, a, "--days")) {
            days = std.fmt.parseInt(u32, v, 10) catch return usageError(a);
        } else if (std.mem.eql(u8, a, "--curves")) {
            curves_dir = v;
        } else if (std.mem.eql(u8, a, "--budget")) {
            budget = v;
        } else if (std.mem.eql(u8, a, "--cors")) {
            cors = v;
        } else if (std.mem.eql(u8, a, "--exchange")) {
            exchange = v;
        } else if (std.mem.eql(u8, a, "--riot-txt")) {
            riot_txt = v;
        } else if (std.mem.eql(u8, a, "--keep-daily")) {
            keep_daily = std.fmt.parseInt(usize, v, 10) catch return usageError(a);
        } else if (std.mem.eql(u8, a, "--keep-weekly")) {
            keep_weekly = std.fmt.parseInt(usize, v, 10) catch return usageError(a);
        } else if (std.mem.eql(u8, a, "--from")) {
            from_dir = v;
        } else if (std.mem.eql(u8, a, "--state")) {
            state_file = v;
        } else if (std.mem.eql(u8, a, "--backups")) {
            erase.backups = v;
        } else if (std.mem.eql(u8, a, "--export")) {
            erase.export_path = v;
        } else if (std.mem.eql(u8, a, "--puuid") or std.mem.eql(u8, a, "--riot-id")) {
            try erase.ids.append(arena, v);
        } else if (std.mem.eql(u8, a, "--list")) {
            erase.listed = true;
            const text = try std.Io.Dir.cwd().readFileAlloc(init.io, v, arena, .limited(64 << 20));
            var lines = std.mem.tokenizeAny(u8, text, "\r\n");
            while (lines.next()) |line| {
                const t = std.mem.trim(u8, line, " \t");
                // Riot IDs hold '#', so only a leading one marks a comment
                if (t.len > 0 and t[0] != '#') try erase.ids.append(arena, t);
            }
        } else return usageError(a);
    }
    try std.Io.Dir.cwd().createDirPath(init.io, data_dir);
    if (platforms.items.len == 0) try platforms.append(arena, "EUW1");

    const cmd = args[1];
    if (std.mem.eql(u8, cmd, "crawl")) {
        const key = try apiKey(init, arena) orelse {
            std.log.err("RIOT_API_KEY not set (env or .env)", .{});
            return 1;
        };
        var crawler: riot.crawl.Crawler = .{ .gpa = init.gpa, .io = init.io, .opts = .{
            .data_dir = data_dir,
            .key = key,
            .since_days = since_days,
            .ladder_refresh_s = ladder_refresh_days * 86400,
            .mastery = mastery,
            .hours = hours,
            .regions = if (regions.items.len > 0) regions.items else std.enums.values(riot.endpoints.Region),
            .timeline_percent = timeline_percent,
            .raw_timeline_days = raw_timeline_days,
            .raw_match_days = raw_match_days,
            .priority = priority orelse &.{"EUW1"},
            .reserve_pct = reserve_pct,
        } };
        crawler.run() catch |err| switch (err) {
            error.KeyRejected => return 3,
            else => return err,
        };
        return 0;
    }
    if (std.mem.eql(u8, cmd, "stats")) {
        try writeStats(init.gpa, init.io, arena, data_dir, patches.items, platforms.items, out_path);
        return 0;
    }
    if (std.mem.eql(u8, cmd, "curves")) {
        try writeCurves(init.gpa, init.io, arena, data_dir, patches.items, days, platforms.items, every_platform, out_path, min_games);
        return 0;
    }
    if (std.mem.eql(u8, cmd, "pool")) {
        try writePool(init.gpa, init.io, arena, data_dir, patches.items, platforms.items, out_path);
        return 0;
    }
    if (std.mem.eql(u8, cmd, "eval")) {
        const db = try store.open(init.gpa, data_dir);
        defer db.close();
        const chosen = if (patches.items.len > 0) patches.items else try stats.patches(arena, db, platforms.items);
        var buf: [64 * 1024]u8 = undefined;
        var stdout = std.Io.File.stdout().writer(init.io, &buf);
        const line = try eval.run(init.gpa, db, chosen, platforms.items, eval_opts, &stdout.interface);
        try stdout.interface.flush();
        if (history) |path| {
            const now: eval.Day = .{ .ms = std.Io.Clock.real.now(init.io).toMilliseconds() };
            const date = try std.fmt.allocPrint(arena, "{f}", .{now});
            try eval.appendHistory(init.io, path, line, date);
        }
        return 0;
    }
    if (std.mem.eql(u8, cmd, "site")) {
        const email = contact orelse return usageError("--contact");
        const db = try store.open(init.gpa, data_dir);
        defer db.close();
        const chosen = if (patches.items.len > 0) patches.items else try newestPatch(arena, db, &.{"EUW1"});
        var every: std.ArrayList([]const u8) = .empty;
        for (riot.endpoints.platforms) |pl| try every.append(arena, pl.id);
        // Indexed by site.html.View.index: EUW 30 days, EUW patch, all 30 days, all patch
        const view_curves = [_]?[]const u8{
            try recentCurvesPath(arena, data_dir, false),
            try curvesPath(arena, data_dir, chosen, false),
            try recentCurvesPath(arena, data_dir, true),
            try curvesPath(arena, data_dir, chosen, true),
        };
        const now_ms = std.Io.Clock.real.now(init.io).toMilliseconds();
        try site.generate(init.gpa, init.io, db, .{
            .out_dir = out_path orelse try std.fs.path.join(arena, &.{ data_dir, "site" }),
            .patches = chosen,
            .since_ms = now_ms - 30 * std.time.ms_per_day,
            .all_platforms = every.items,
            .contact = email,
            .riot_txt = riot_txt,
            .updated = try today(arena, init.io),
            .public = public,
            .daily_dir = try std.fs.path.join(arena, &.{ data_dir, "daily" }),
            .curves = view_curves,
        });
        return 0;
    }
    if (std.mem.eql(u8, cmd, "serve")) {
        const dir = out_path orelse try std.fs.path.join(arena, &.{ data_dir, "site" });
        try serve.run(init.gpa, init.io, dir, host, port orelse 8080);
        return 0;
    }
    if (std.mem.eql(u8, cmd, "api")) {
        const key = try apiKey(init, arena) orelse {
            std.log.err("RIOT_API_KEY not set (env or .env)", .{});
            return 1;
        };
        try api.run(init.gpa, init.io, .{
            .db_path = try std.fmt.allocPrintSentinel(arena, "{s}/api.db", .{data_dir}, 0),
            .curves_dir = curves_dir orelse
                try std.fs.path.join(arena, if (exchange) |x| &.{ x, "curves" } else &.{ data_dir, "export" }),
            .key = key,
            .host = host,
            .port = port orelse 8090,
            .cors = cors,
            .fetch = .{ .budget = budget orelse "20:120", .exchange_dir = exchange },
        });
        return 0;
    }
    if (std.mem.eql(u8, cmd, "status")) {
        try status(init.gpa, init.io, data_dir);
        return 0;
    }
    if (std.mem.eql(u8, cmd, "rebuild")) {
        const db = try store.open(init.gpa, data_dir);
        defer db.close();
        std.log.info("{d} matches rebuilt", .{try riot.match.rebuild(init.gpa, db)});
        std.log.info("{d} timelines gave gold columns", .{try riot.crawl.rebuildGold(init.gpa, db)});
        return 0;
    }
    if (std.mem.eql(u8, cmd, "rekey")) {
        const db = try store.open(init.gpa, data_dir);
        defer db.close();
        try store.schema.rekey(db);
        std.log.info("players, ladder and mastery cleared; matches kept", .{});
        return 0;
    }
    if (std.mem.eql(u8, cmd, "champions")) {
        const db = try store.open(init.gpa, data_dir);
        defer db.close();
        const n = try ddragon.refresh(init.gpa, init.io, db);
        std.log.info("{d} champions", .{n});
        return 0;
    }
    if (std.mem.eql(u8, cmd, "backup")) {
        const r = try backup.run(arena, init.io, .{
            .data_dir = data_dir,
            .out_dir = out_path orelse init.environ_map.get("MEIOLOL_BACKUPS") orelse "backups",
            .keep_daily = keep_daily,
            .keep_weekly = keep_weekly,
            .full = full,
            .now = std.Io.Clock.real.now(init.io).toSeconds(),
        });
        std.log.info("{s}; segment {s}: {d} matches, {d} timelines; {d} old files removed", .{
            r.state, r.segment orelse "none (nothing new)", r.matches, r.timelines, r.removed,
        });
        return 0;
    }
    if (std.mem.eql(u8, cmd, "restore")) {
        const from = from_dir orelse return usageError("--from");
        const now = std.Io.Clock.real.now(init.io).toSeconds();
        const r = backup.restore(arena, init.io, from, data_dir, state_file, now) catch |err| {
            if (err == error.TargetNotEmpty) std.log.err("{s} holds a database: restore only into an empty directory", .{data_dir});
            return err;
        };
        std.log.info("{s}: {d} files, {d} matches, {d} timelines; {d} rows re-erased", .{
            data_dir, r.files, r.matches, r.timelines, r.removed.total(),
        });
        return 0;
    }
    if (std.mem.eql(u8, cmd, "forget")) return forgetPlayers(init, arena, data_dir, erase);
    return usageError(cmd);
}

const ForgetArgs = struct {
    ids: std.ArrayList([]const u8) = .empty,
    /// --list given: an empty list is fine (the exchange with the Your games service)
    listed: bool = false,
    backups: ?[]const u8 = null,
    export_path: ?[]const u8 = null,
};

/// Logs counts only: an erasure log naming the player would defeat the erasure. PUUIDs
/// already in `forgotten` are skipped, so complete lists can be fed in again and again.
fn forgetPlayers(init: std.process.Init, arena: std.mem.Allocator, data_dir: []const u8, args: ForgetArgs) !u8 {
    const ids = args.ids.items;
    if (ids.len == 0 and !args.listed and args.export_path == null) {
        return usageError("--puuid, --riot-id, --list or --export");
    }
    const now = std.Io.Clock.real.now(init.io).toSeconds();
    var client: ?riot.client.Client = null;
    defer if (client) |*c| c.deinit();
    // The box holds the crawler databases, the web server the Your games cache; open
    // whichever this data directory has, never creating the other
    const cwd = std.Io.Dir.cwd();
    const crawl_path = try std.fs.path.join(arena, &.{ data_dir, "meiolol.db" });
    const api_path = try std.fs.path.joinZ(arena, &.{ data_dir, "api.db" });
    const db: ?store.Db = if (cwd.access(init.io, crawl_path, .{})) |_| try store.open(init.gpa, data_dir) else |_| null;
    defer if (db) |d| d.close();
    const api_db: ?store.Db = if (cwd.access(init.io, api_path, .{})) |_| try api.cache.open(api_path) else |_| null;
    defer if (api_db) |d| d.close();
    if (db == null and api_db == null) {
        std.log.err("{s} holds neither meiolol.db nor api.db", .{data_dir});
        return 1;
    }
    var live: forget.Removed = .{};
    var scrubbed: forget.Removed = .{};
    var unresolved: usize = 0;
    var already: usize = 0;
    for (ids) |id| {
        const puuid = if (std.mem.indexOfScalar(u8, id, '#') == null) id else blk: {
            if (client == null) {
                const key = try apiKey(init, arena) orelse {
                    std.log.err("RIOT_API_KEY not set (env or .env): needed for Riot IDs", .{});
                    return 1;
                };
                client = try .init(init.gpa, init.io, key);
            }
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
        if (args.backups) |dir| scrubbed.add(try backup.scrub(arena, init.io, dir, puuid, now));
    }
    if (ids.len > 0) {
        std.log.info("{d} of {d} erased, {d} already forgotten; live rows: players {d}, " ++
            "mastery {d}, participants blanked {d}, raw matches {d}, raw timelines {d}", .{
            ids.len - unresolved - already, ids.len, already, live.players, live.mastery,
            live.participants, live.raw_matches, live.raw_timelines,
        });
    }
    if (api_db != null and ids.len > 0) std.log.info("Your games cache: erased and blocked", .{});
    if (args.backups != null) std.log.info("backup rows: {d}", .{scrubbed.total()});
    if (args.export_path) |path| {
        const d = db orelse {
            std.log.err("--export needs meiolol.db in {s}", .{data_dir});
            return 1;
        };
        std.log.info("{d} forgotten PUUIDs written to {s}", .{ try forget.exportList(init.io, d, path), path });
    }
    if (unresolved > 0) {
        std.log.warn("{d} Riot IDs have no account (renamed or deleted): resolve them by PUUID", .{unresolved});
        return 1;
    }
    return 0;
}

fn usageError(arg: ?[]const u8) u8 {
    if (arg) |a| std.log.err("unexpected or incomplete argument: {s}", .{a});
    std.debug.print("{s}", .{usage});
    return 2;
}

/// RIOT_API_KEY from the environment, else from ./.env
fn apiKey(init: std.process.Init, arena: std.mem.Allocator) !?[]const u8 {
    if (init.environ_map.get("RIOT_API_KEY")) |k| return k;
    const text = std.Io.Dir.cwd().readFileAlloc(init.io, ".env", arena, .limited(64 * 1024)) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    var lines = std.mem.tokenizeAny(u8, text, "\r\n");
    while (lines.next()) |line| {
        const eq = std.mem.indexOfScalar(u8, line, '=') orelse continue;
        if (std.mem.eql(u8, std.mem.trim(u8, line[0..eq], " "), "RIOT_API_KEY")) {
            return std.mem.trim(u8, line[eq + 1 ..], " \"'");
        }
    }
    return null;
}

fn writeStats(
    gpa: std.mem.Allocator,
    io: std.Io,
    arena: std.mem.Allocator,
    data_dir: []const u8,
    wanted: []const []const u8,
    platforms: []const []const u8,
    out_path: ?[]const u8,
) !void {
    const db = try store.open(gpa, data_dir);
    defer db.close();
    const chosen = if (wanted.len > 0) wanted else try newestPatch(arena, db, platforms);
    var label_buf: [core.statsfile.patch_len]u8 = undefined;
    const label = try stats.label(&label_buf, chosen);
    const path = out_path orelse
        try std.fmt.allocPrint(arena, "{s}/export/stats-{s}.bin", .{ data_dir, label });

    var r = try stats.build(gpa, db, chosen, platforms);
    defer r.builder.deinit();
    if (r.summary.games == 0) {
        std.log.err("no complete ranked solo games on patch {s}", .{label});
        return error.NoMatches;
    }

    const cwd = std.Io.Dir.cwd();
    var file = try cwd.createFileAtomic(io, path, .{ .make_path = true, .replace = true });
    defer file.deinit(io);
    var buf: [64 * 1024]u8 = undefined;
    var w = file.file.writer(io, &buf);
    try r.builder.write(&w.interface, label);
    try w.interface.flush();
    try file.replace(io);
    std.log.info("{s}: patch {s}, {d} games ({d} skipped), {d} champions", .{
        path, label, r.summary.games, r.summary.skipped, r.builder.ids.len,
    });
}

fn writeCurves(
    gpa: std.mem.Allocator,
    io: std.Io,
    arena: std.mem.Allocator,
    data_dir: []const u8,
    wanted: []const []const u8,
    days: u32,
    platforms: []const []const u8,
    every_platform: bool,
    out_path: ?[]const u8,
    min_games: u32,
) !void {
    const db = try store.open(gpa, data_dir);
    defer db.close();
    var label_buf: [core.statsfile.patch_len]u8 = undefined;
    const label = if (wanted.len > 0)
        try stats.label(&label_buf, wanted)
    else
        try std.fmt.bufPrint(&label_buf, "last {d} days", .{days});
    const path = out_path orelse if (wanted.len > 0)
        try curvesPath(arena, data_dir, wanted, every_platform)
    else
        try recentCurvesPath(arena, data_dir, every_platform);
    const now_ms = std.Io.Clock.real.now(io).toMilliseconds();
    const since_ms: i64 = if (wanted.len > 0) 0 else now_ms - @as(i64, days) * std.time.ms_per_day;
    const item_patch = if (wanted.len > 0) wanted[0] else (try newestPatch(arena, db, platforms))[0];

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
}

fn writePool(
    gpa: std.mem.Allocator,
    io: std.Io,
    arena: std.mem.Allocator,
    data_dir: []const u8,
    wanted: []const []const u8,
    platforms: []const []const u8,
    out_path: ?[]const u8,
) !void {
    const db = try store.open(gpa, data_dir);
    defer db.close();
    const chosen = if (wanted.len > 0) wanted else try newestPatch(arena, db, platforms);
    var r = try stats.build(gpa, db, chosen, platforms);
    defer r.builder.deinit();
    var label_buf: [core.statsfile.patch_len]u8 = undefined;
    var model: std.Io.Writer.Allocating = .init(arena);
    try r.builder.write(&model.writer, try stats.label(&label_buf, chosen));
    const st: core.Stats = try .parse(arena, model.written());
    const p = try pool.make(gpa, arena, db, &st, platforms, .{});

    const path = out_path orelse try std.fs.path.join(arena, &.{ data_dir, "export", "pool.json" });
    var file = try std.Io.Dir.cwd().createFileAtomic(io, path, .{ .make_path = true, .replace = true });
    defer file.deinit(io);
    var buf: [64 * 1024]u8 = undefined;
    var w = file.file.writer(io, &buf);
    try pool.writeJson(&w.interface, p);
    try w.interface.flush();
    try file.replace(io);
    std.log.info("{s}", .{path});
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

fn allPrefix(every: bool) []const u8 {
    return if (every) "all-" else "";
}

fn newestPatch(arena: std.mem.Allocator, db: store.Db, platforms: []const []const u8) ![]const []const u8 {
    const all = try stats.patches(arena, db, platforms);
    if (all.len == 0) return error.NoMatches;
    return all[0..1];
}

/// "11 October 2026", UTC
fn today(arena: std.mem.Allocator, io: std.Io) ![]const u8 {
    const secs: u64 = @intCast(std.Io.Clock.real.now(io).toSeconds());
    const epoch: std.time.epoch.EpochSeconds = .{ .secs = secs };
    const day = epoch.getEpochDay().calculateYearDay();
    const md = day.calculateMonthDay();
    const months = [_][]const u8{ "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" };
    return std.fmt.allocPrint(arena, "{d} {s} {d}", .{ md.day_index + 1, months[md.month.numeric() - 1], day.year });
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
}
