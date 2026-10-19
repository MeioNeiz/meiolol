//! `meiolol crawl`, `stats`, `champions`, `draft-backfill`, `digest`: fill the database

const std = @import("std");
const store = @import("store");
const core = @import("core");
const riot = @import("../riot/root.zig");
const ddragon = @import("../ddragon.zig");
const stats = @import("../stats.zig");
const digests = @import("../digests.zig");
const main = @import("../main.zig");
const Cmd = main.Cmd;
const Games = main.Games;
const newestPatch = main.newestPatch;

pub const usage_crawl =
    \\  crawl       crawl ranked solo games (needs RIOT_API_KEY in env or .env)
    \\              --hours H        stop after H hours (default: run until stopped)
    \\              --since-days N   how far back to collect match ids (default 14)
    \\              --patch-only     match ids only from each platform's newest patch;
    \\                               older patches' matches get no timeline
    \\              --no-active-first  scan stalest players first, not those the
    \\                               ladder shows played since their last scan
    \\              --no-mastery     skip champion mastery
    \\              --mastery-sweep-days N  the first participant mastery pass after
    \\                               start covers games N days back, not 7 (one-time
    \\                               sweep; refreshes stay weekly)
    \\              --ladder-refresh-days N  refetch ladder pages after N days
    \\                               (default 7)
    \\              --ladder-refresh-hours N  the same in hours
    \\              --ladder-per-hour N  ladder pages per platform per hour at most
    \\                               (default 0: no cap)
    \\              --regions R      americas,asia,europe,sea (default all)
    \\              --timelines PCT  share of non-priority matches that also get a
    \\                               timeline, the same games on a rerun (default 100)
    \\              --timelines-priority PCT  the same for --priority matches (default
    \\                               100)
    \\              --timeline-min-s S  no timeline for matches shorter than S seconds
    \\                               (default 0: every length)
    \\              --timelines-sparse N  a match the sample skips still gets a
    \\                               timeline while a lane of it has under N in its
    \\                               champion pair and rank cell this patch (default
    \\                               0: off; docs/data.md)
    \\              --timelines-sparse-from TIER  --timelines-sparse only for games of
    \\                               median rank TIER and up
    \\              --flex-calls-per-day N  ranked flex id lookups a day for --priority
    \\                               players, a test sample (default 0; queue 420 only on
    \\                               the site and in models)
    \\              --raw-timeline-days N  keep raw timeline JSON N days (default 7,
    \\                                     0 none)
    \\              --raw-match-days N     keep raw match JSON N days (default 30,
    \\                                     0 forever)
    \\              --raw-valve-free-gb N  under N GB free on the data disk, drop raw
    \\                               the archive never got, oldest first, logged in
    \\                               DATA/raw-dropped.log (default 0: never)
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
    \\              --proxy HOST:PORT  serve the Your games service's Riot calls
    \\                               through the crawler's limiters, ahead of the crawl
    \\                               (box: 10.0.0.3:8092, the private address)
    \\
;

pub fn cmdCrawl(c: *Cmd) !u8 {
    var o: riot.crawl.Options = .{ .data_dir = c.data_dir, .key = "" };
    var regions: std.ArrayList(riot.endpoints.Region) = .empty;
    var fake_api_ms: ?u32 = null;
    while (c.next()) |_| {
        if (c.is("--no-mastery")) {
            o.mastery = false;
        } else if (c.is("--mastery-sweep-days")) {
            o.mastery_sweep_days = try c.int(u32);
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
        } else if (c.is("--timelines-priority")) {
            o.timeline_priority_percent = try c.int(u8);
            if (o.timeline_priority_percent > 100) return error.Usage;
        } else if (c.is("--timeline-min-s")) {
            o.timeline_min_s = try c.int(u32);
        } else if (c.is("--timelines-sparse")) {
            o.timeline_sparse = try c.int(u32);
        } else if (c.is("--timelines-sparse-from")) {
            o.timeline_sparse_min_rank = riot.sparse.rankOf(try c.value()) orelse return error.Usage;
        } else if (c.is("--flex-calls-per-day")) {
            o.flex_calls_per_day = try c.int(u32);
        } else if (c.is("--raw-timeline-days")) {
            o.raw_timeline_days = try c.int(u32);
        } else if (c.is("--raw-match-days")) {
            o.raw_match_days = try c.int(u32);
        } else if (c.is("--raw-valve-free-gb")) {
            o.raw_valve_free_mb = try c.int(u64) * 1024;
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
        } else if (c.is("--proxy")) {
            o.proxy = try c.value();
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

pub const usage_stats =
    \\  stats       write the model file the app reads (ranked solo, no remakes)
    \\              --patch P        patch to include, repeatable or comma separated
    \\                               (default: the newest patch)
    \\              --out FILE       default DIR/export/stats-<patch>.bin
    \\              --platform P     Riot platform id, repeatable or comma separated
    \\                               (default EUW1; "all" for every platform in
    \\                               riot/endpoints.zig)
    \\
;

pub fn cmdStats(c: *Cmd) !u8 {
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
        try c.arena.print("{s}/export/stats-{s}.bin", .{ c.data_dir, label });

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

pub const usage_champions =
    \\  champions   refresh champion ids and names from Data Dragon
    \\
;

pub fn cmdChampions(c: *Cmd) !u8 {
    try c.noFlags();
    const db = try c.open();
    defer db.close();
    std.log.info("{d} champions", .{try ddragon.refresh(c.init.gpa, c.init.io, db)});
    return 0;
}

pub const usage_digest =
    \\  digest      timeline digests (what curves, lean, lane-model and builds read) for
    \\              timelines stored since the last run; all again on a new version
    \\              --full           remake every digest
    \\              --pause-ms MS    between chunks of 2,000 (default 0)
    \\
;

pub fn cmdDigest(c: *Cmd) !u8 {
    var o: digests.Options = .{};
    while (c.next()) |_| {
        if (c.is("--full")) {
            o.full = true;
        } else if (c.is("--pause-ms")) {
            o.pause_ms = try c.int(u32);
        } else return error.Usage;
    }
    const io = c.init.io;
    const db = try c.open();
    defer db.close();
    const start = std.Io.Clock.awake.now(io).toMilliseconds();
    const s = try digests.catchUp(c.init.gpa, io, db, o);
    const n: f64 = @floatFromInt(@max(s.made, 1));
    std.log.info("{d} digests made ({d} timelines did not decode) in {d} s: {d:.0} B each against {d:.0} B gzipped; decode {d:.0} us against {d:.0} us", .{
        s.made,
        s.failed,
        @divTrunc(std.Io.Clock.awake.now(io).toMilliseconds() - start, 1000),
        @as(f64, @floatFromInt(s.bytes)) / n,
        @as(f64, @floatFromInt(s.full_bytes)) / n,
        @as(f64, @floatFromInt(s.digest_ns)) / n / 1000,
        @as(f64, @floatFromInt(s.full_ns)) / n / 1000,
    });
    return 0;
}

pub const usage_draft_backfill =
    \\  draft-backfill  add the draft rows (kept forever) of matches stored before the
    \\              drafts table existed; once, alongside the crawler
    \\              --chunk N        matches per transaction (default 200)
    \\              --pause-ms MS    between chunks, so the crawler gets the lock
    \\                               (default 1000)
    \\
;

/// Resumable: the list shrinks as chunks commit
pub fn cmdDraftBackfill(c: *Cmd) !u8 {
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
