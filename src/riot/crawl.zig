//! Ranked solo crawler for every region. On a personal key each routing value is its
//! own rate limit bucket, so each gets a thread:
//! - RegionCrawler (europe, asia, ...): match ids per player of its platforms, match
//!   details, then their timelines
//! - PlatformCrawler (euw1, kr, ...): ladder seeding for every tier, then mastery with
//!   spare budget: sampled ladder players, then every player of the week's new matches
//! Each thread owns a Bucket: HTTP client, its route's limiter and a DB connection it
//! only reads with; one writer thread (writer.zig) makes every write. `--proxy` serves
//! the Your games service's calls through the same limiters, ahead of the crawl
//! (proxy.zig). `--priority` platforms (EUW1)
//! come first in their region's queues, and their region's jobs first at the writer
//! when the machine falls behind. The main thread reports.

const std = @import("std");
const store = @import("store");
const Client = @import("client.zig").Client;
const Limiters = @import("ratelimit.zig").Limiters;
const Proxy = @import("proxy.zig").Proxy;
const ep = @import("endpoints.zig");
const match = @import("match.zig");
const timeline = @import("timeline.zig");
const mastery = @import("mastery.zig");
const writer = @import("writer.zig");
const sparse = @import("sparse.zig");
const Job = writer.Job;

const log = std.log.scoped(.crawl);

const tiers = store.schema.tiers;
const divisions = store.schema.divisions;
/// Match ids are refilled when fewer than this many matches wait
const pending_low = 300;
const scan_batch = 10;
const detail_batch = 40;
/// When the match queue runs short, so a timeline backlog drains in quiet spells
const timeline_batch = 60;
/// Nap when a region has nothing due
const idle_s = 15;
/// Spare-budget timelines per round: few, so a player found meanwhile waits little
const backfill_batch = 20;
/// Snowball and blind rescans go before spare-budget timelines while they find this
/// many new match ids per call: a match then costs about two calls, a timeline one
const min_yield = 1.0;
/// Snowball and blind rescans run at least this often, so their yield stays measured
const probe_s = 600;
/// Matches stored before start that the participant snowball still reads
const snowball_backlog = 5000;
const all_regions = std.enums.values(ep.Region);

pub const Options = struct {
    data_dir: []const u8,
    key: []const u8,
    since_days: i64 = 14,
    /// Match ids only from the first game seen on each platform's newest patch (still
    /// at most since_days back); matches of older patches get no timeline
    patch_only: bool = false,
    ladder_refresh_s: i64 = 7 * 24 * 3600,
    /// Ladder pages each platform thread fetches per hour at most; 0 = no cap. A page
    /// is ~600 random page writes into players: on a slow disk an uncapped ladder fills
    /// the writer's queue and matches wait behind it
    ladder_per_hour: u32 = 0,
    recheck_s: i64 = 12 * 3600,
    /// Scan first the players whose ladder wins + losses grew since their last scan,
    /// most new games first; then the stalest as before. Needs a ladder refreshed more
    /// often than players are rescanned to see who has played
    active_first: bool = true,
    mastery: bool = true,
    /// The participant pass's first pass after start covers games from this many days
    /// back, not one week (a one-time sweep); refreshes stay weekly. 0: one week
    mastery_sweep_days: u32 = 0,
    hours: ?f64 = null,
    regions: []const ep.Region = all_regions,
    /// Share of non-priority platforms' matches that also get a timeline, chosen by
    /// match id hash
    timeline_percent: u8 = 100,
    /// The same for the --priority platforms' matches, by the same hash
    timeline_priority_percent: u8 = 100,
    /// Matches shorter than this get no timeline; 0: every length
    timeline_min_s: u32 = 0,
    /// A match the sample skips still gets a timeline while a lane of it has fewer than
    /// this many in its cell (sparse.zig); 0: off
    timeline_sparse: u32 = 0,
    /// --timelines-sparse only for games whose median rank is at least this
    /// (sparse.rankOf: Iron 0); 0 every game, those of unknown rank too
    timeline_sparse_min_rank: u8 = 0,
    /// Ranked flex (queue 440) id lookups a day, one page each, for scanned players of
    /// the --priority platforms: a small test sample (Jacob, 2026-10-13) stored like solo
    /// games; every stats, site and model reader keeps to queue 420. 0: none
    flex_calls_per_day: u32 = 0,
    /// Raw timeline JSON kept this long for re-extraction; 0 keeps none
    raw_timeline_days: u32 = 7,
    /// Raw match summaries kept this long (`meiolol rebuild` re-parses them); 0 = forever
    raw_match_days: u32 = 30,
    /// Rolling window: matches, their rows and timelines go this long after game
    /// start; 0 = forever
    keep_days: u32 = 0,
    /// Under this much free space on the data disk the writer drops raw the archive
    /// never got, oldest first (archive.valve); 0: never
    raw_valve_free_mb: u64 = 0,
    /// Every match participant also becomes a player to scan. The ladder already has
    /// every ranked player, so off saves ten upserts (random index pages) per match
    participant_players: bool = true,
    /// players keeps full rows (the scan pool) for one ladder player or participant in
    /// this many, by PUUID hash; ranks has everyone's rank. 0 or 1 keeps everyone
    player_sample: u32 = 1,
    /// The writer's page cache
    cache_mb: u32 = 64,
    /// Platforms whose players and matches a region thread takes before any other's,
    /// so they get its whole budget while they have players due. Their region's jobs
    /// may also fill the writer's whole queue, the rest only half (Writer.submit)
    priority: []const []const u8 = &.{"EUW1"},
    /// Lowest tier the ladder walks and the scan pool takes, an index into `tiers`
    /// (PLATINUM: Platinum IV and up); the last tier takes everyone
    min_tier: usize = tiers.len - 1,
    /// Address the Your games proxy listens on ("10.0.0.3:8092"); none when null
    proxy: ?[]const u8 = null,
    fake: ?*const @import("fake.zig").Fake = null,
};

/// Why a player's match ids were fetched: the ladder shows new games, they were in a
/// newly stored match, or a blind rescan
pub const Source = enum { active, snowball, stale };

const RegionCounters = struct {
    matches: std.atomic.Value(u64) = .init(0),
    timelines: std.atomic.Value(u64) = .init(0),
    ids_calls: std.atomic.Value(u64) = .init(0),
    /// Match ids new to the queue
    ids_found: std.atomic.Value(u64) = .init(0),
    requests: std.atomic.Value(u64) = .init(0),
    calls_by: std.EnumArray(Source, std.atomic.Value(u64)) = .initFill(.init(0)),
    found_by: std.EnumArray(Source, std.atomic.Value(u64)) = .initFill(.init(0)),
    /// Timelines the sample skipped, fetched with spare budget
    backfill: std.atomic.Value(u64) = .init(0),
    idle_s: std.atomic.Value(u64) = .init(0),
};

const Counters = struct {
    region: [all_regions.len]RegionCounters = @splat(.{}),
    ladder_pages: std.atomic.Value(u64) = .init(0),
    mastery: std.atomic.Value(u64) = .init(0),
    platform_requests: std.atomic.Value(u64) = .init(0),
};

pub const Crawler = struct {
    gpa: std.mem.Allocator,
    io: std.Io,
    opts: Options,
    stop: std.atomic.Value(bool) = .init(false),
    counters: Counters = .{},
    failure: ?anyerror = null,
    failure_lock: std.Io.Mutex = .init,
    /// Set up by run()
    writer: writer.Writer = undefined,
    /// From the database at start; each RegionCrawler keeps its own copy up to date
    patches: Patches = .{},
    /// Set up by run(): shared by the bucket threads and the proxy
    limiters: Limiters = undefined,
    /// A stored player whose mastery this key fetched at start (checkKey), fetched
    /// again when a call gets Riot's 401/403 to tell a rejected key from one refused
    /// request. None: every 401/403 stops the crawler
    probe: ?KeyProbe = null,
    probe_lock: std.Io.Mutex = .init,
    /// When the probe last worked; a 401/403 soon after skips its request unasked
    key_ok_at: ?i64 = null,
    /// --timelines-sparse counts: seeded by run(), then the writer's alone
    sparse: sparse.Cells = .{},

    pub fn run(c: *Crawler) !void {
        c.limiters = try .init(c.gpa, c.io);
        defer c.limiters.deinit();
        for (&c.limiters.all) |*l| l.paced = true;
        c.loadWindows();
        // First, so a lookup waits only for the restart itself
        var proxy: Proxy = .{ .gpa = c.gpa, .io = c.io, .key = c.opts.key, .limiters = &c.limiters, .fake = c.opts.fake };
        var proxy_server = if (c.opts.proxy) |address| try proxy.listen(address) else null;
        defer if (proxy_server) |*s| s.deinit(c.io);
        var serving = if (proxy_server) |*s| try c.io.concurrent(Proxy.serve, .{ &proxy, s }) else null;
        defer if (serving) |*f| f.cancel(c.io);

        // Opening once here migrates the schema before the threads connect
        const db = try store.open(c.gpa, c.opts.data_dir);
        defer db.close();
        try c.checkKey(db);
        try c.backfillTimelines(db);
        defer c.sparse.deinit(c.gpa);
        try c.seedSparse(db);
        try dropDoneRows(db);
        if (c.opts.patch_only) {
            c.patches = try .load(c.gpa, db);
            c.patches.log();
        }

        c.writer = .{ .c = c };
        defer c.writer.deinit();
        const writer_thread = try std.Thread.spawn(.{}, writer.Writer.run, .{&c.writer});
        var threads: std.ArrayList(std.Thread) = .empty;
        defer threads.deinit(c.gpa);
        defer c.stopAll(&threads, writer_thread);
        try c.spawnAll(&threads);
        log.info("{d} threads for {d} regions", .{ threads.items.len, c.opts.regions.len });

        const started = c.nowS();
        var last_report = started;
        var saved_ok = true;
        while (!c.stop.load(.acquire)) {
            c.io.sleep(.fromSeconds(1), .awake) catch break;
            const now = c.nowS();
            if (@mod(now, windows_save_s) == 0) {
                if (c.saveWindows()) {
                    saved_ok = true;
                } else |err| {
                    if (saved_ok) log.warn("rate windows not saved: {t}", .{err});
                    saved_ok = false;
                }
            }
            if (c.opts.hours) |h| {
                if (@as(f64, @floatFromInt(now - started)) > h * 3600) c.stop.store(true, .release);
            }
            if (now - last_report >= 60) {
                last_report = now;
                c.report(now - started);
            }
        }
        c.stopAll(&threads, writer_thread);
        c.report(c.nowS() - started);
        c.saveWindows() catch |err| log.warn("rate windows not saved: {t}", .{err});
        if (c.failure) |err| return err;
    }

    /// The limiters' send times, saved every few seconds and loaded at start: a
    /// deploy's restart then waits only for what it sent, not 2-3 min of windows padded
    /// full from Riot's counts (Limiters.save). systemd stops the crawler with a
    /// SIGTERM, so the last save is the periodic one
    const windows_file = "rate-windows.txt";
    const windows_save_s = 2;

    fn loadWindows(c: *Crawler) void {
        if (c.opts.fake != null) return;
        const path = std.fs.path.join(c.gpa, &.{ c.opts.data_dir, windows_file }) catch return;
        defer c.gpa.free(path);
        const text = std.Io.Dir.cwd().readFileAlloc(c.io, path, c.gpa, .limited(1 << 20)) catch |err| {
            if (err != error.FileNotFound) log.warn("rate windows not loaded: {t}", .{err});
            return;
        };
        defer c.gpa.free(text);
        const n = c.limiters.load(text, std.Io.Clock.real.now(c.io).toMilliseconds()) catch |err| {
            log.warn("rate windows not loaded: {t}", .{err});
            return;
        };
        log.info("rate windows: {d} requests of the last run still in their window", .{n});
    }

    fn saveWindows(c: *Crawler) !void {
        if (c.opts.fake != null) return;
        var aw: std.Io.Writer.Allocating = .init(c.gpa);
        defer aw.deinit();
        try c.limiters.save(&aw.writer, std.Io.Clock.real.now(c.io).toMilliseconds());
        const path = try std.fs.path.join(c.gpa, &.{ c.opts.data_dir, windows_file });
        defer c.gpa.free(path);
        const tmp = try std.fmt.allocPrint(c.gpa, "{s}.tmp", .{path});
        defer c.gpa.free(tmp);
        const cwd = std.Io.Dir.cwd();
        try cwd.writeFile(c.io, .{ .sub_path = tmp, .data = aw.written() });
        try cwd.rename(tmp, cwd, path, c.io);
    }

    /// A key from another Riot app answers every call but gives 400 "Exception
    /// decrypting" for every stored PUUID (11 and 13 Oct, docs/data-safety.md), and the
    /// crawl then stores that app's PUUIDs. One call for the player most recently given
    /// mastery stops it first, as a rejected key does (exit 3)
    fn checkKey(c: *Crawler, db: store.Db) !void {
        if (c.opts.fake != null) return;
        var q = try db.prepare("SELECT puuid, platform FROM mastery WHERE champions > 0 ORDER BY fetched_at DESC LIMIT 1");
        defer q.deinit();
        if (!try q.step()) return;
        const r = q.row(struct { puuid: []const u8, platform: []const u8 });
        const p = ep.platform(r.platform) orelse return;
        const probe = KeyProbe.init(p, r.puuid) orelse return;
        c.probe = probe;
        c.probeKey(probe) catch |err| switch (err) {
            error.UnexpectedStatus => {
                log.err("a stored {s} PUUID fails with this key: a key from another Riot app? Not crawling", .{p.id});
                return error.KeyRejected;
            },
            error.KeyRejected, error.OutOfMemory, error.Canceled => return err,
            // Riot down or slow: no answer about the key, so crawl as before
            else => {
                log.warn("key check: {t}", .{err});
                return;
            },
        };
        log.info("key check: a stored {s} PUUID decrypts", .{p.id});
    }

    fn probeKey(c: *Crawler, probe: KeyProbe) !void {
        var client: Client = .init(c.gpa, c.io, c.opts.key, c.limiters.get(probe.platform.host).?);
        defer client.deinit();
        client.fake = c.opts.fake;
        if (try ep.masteries(&client, probe.platform, probe.puuid())) |b| c.gpa.free(b);
    }

    /// After Riot's JSON 401/403: whether it was the key, so the crawler stops (exit 3),
    /// or only that request, which is skipped. 16 Oct a refused TW2 player stopped all
    /// 19 threads for 205 min as a rejected key
    fn keyRejected(c: *Crawler) bool {
        const probe = c.probe orelse return true;
        c.probe_lock.lockUncancelable(c.io);
        defer c.probe_lock.unlock(c.io);
        const now = c.nowS();
        if (c.key_ok_at) |t| if (now - t < key_recheck_s) return false;
        c.probeKey(probe) catch |err| {
            if (err == error.KeyRejected) {
                log.warn("key recheck: the stored {s} player is refused too, the key is rejected", .{probe.platform.id});
                return true;
            }
            // Riot down or slow, or that player gone: no answer, so not a rejection
            log.warn("key recheck: {t}, skipping the refused request", .{err});
            return false;
        };
        c.key_ok_at = now;
        log.warn("key recheck: the key still works, skipping the refused request", .{});
        return false;
    }

    /// One recheck answers for every thread's 401/403s this long
    const key_recheck_s = 60;

    /// Bucket threads first: the writer then stores what they queued before stopping
    fn stopAll(c: *Crawler, threads: *std.ArrayList(std.Thread), writer_thread: std.Thread) void {
        if (c.writer.closing) return;
        c.stop.store(true, .release);
        c.writer.wake();
        for (threads.items) |t| t.join();
        c.writer.close();
        writer_thread.join();
    }

    fn spawnAll(c: *Crawler, threads: *std.ArrayList(std.Thread)) !void {
        try threads.ensureTotalCapacity(c.gpa, all_regions.len + ep.platforms.len);
        for (c.opts.regions) |r| {
            threads.appendAssumeCapacity(try std.Thread.spawn(.{}, Thread(RegionCrawler).run, .{ c, r }));
            for (ep.platforms) |p| {
                if (p.region != r) continue;
                threads.appendAssumeCapacity(try std.Thread.spawn(.{}, Thread(PlatformCrawler).run, .{ c, p }));
            }
        }
    }

    fn report(c: *Crawler, elapsed_s: i64) void {
        var buf: [768]u8 = undefined;
        var w: std.Io.Writer = .fixed(&buf);
        var matches: u64 = 0;
        for (c.opts.regions) |r| {
            const rc = &c.counters.region[@backingInt(r)];
            const m = rc.matches.load(.monotonic);
            matches += m;
            w.print(" | {t} {d}m {d}t {d}ids {d}new {d}req", .{
                r,                             m,
                rc.timelines.load(.monotonic), rc.ids_calls.load(.monotonic),
                rc.ids_found.load(.monotonic), rc.requests.load(.monotonic),
            }) catch break;
        }
        const per_day = if (elapsed_s > 0) matches * 86400 / @as(u64, @intCast(elapsed_s)) else 0;
        const ws = &c.writer.stats;
        log.info("{d} matches/day | ladder pages {d} | mastery {d} | platform req {d}{s}" ++
            " | writes {d} in {d} commits, {d} queued, {d} busy | pages written {d}, read {d}", .{
            per_day,
            c.counters.ladder_pages.load(.monotonic),
            c.counters.mastery.load(.monotonic),
            c.counters.platform_requests.load(.monotonic),
            w.buffered(),
            ws.jobs.load(.monotonic),
            ws.commits.load(.monotonic),
            c.writer.queued(),
            ws.busy.load(.monotonic),
            ws.pages_written.load(.monotonic),
            ws.pages_read.load(.monotonic),
        });
        w = .fixed(&buf);
        for (c.opts.regions) |r| {
            const rc = &c.counters.region[@backingInt(r)];
            w.print(" | {t}", .{r}) catch break;
            for (std.enums.values(Source)) |s| {
                w.print(" {t} {d}/{d}", .{ s, rc.calls_by.get(s).load(.monotonic), rc.found_by.get(s).load(.monotonic) }) catch break;
            }
            w.print(", {d} backfill t, {d} s idle", .{ rc.backfill.load(.monotonic), rc.idle_s.load(.monotonic) }) catch break;
        }
        log.info("scans, ids calls/new{s}", .{
            w.buffered(),
        });
    }

    fn isPriority(c: *const Crawler, p: ep.Platform) bool {
        for (c.opts.priority) |id| {
            if (std.mem.eql(u8, id, p.id)) return true;
        }
        return false;
    }

    /// Holds a `--priority` platform
    fn isPriorityRegion(c: *const Crawler, r: ep.Region) bool {
        for (c.opts.priority) |id| {
            const p = ep.platform(id) orelse continue;
            if (p.region == r) return true;
        }
        return false;
    }

    /// `--priority` as a JSON list, for the queue orderings
    fn priorityJson(c: *const Crawler, a: std.mem.Allocator) ![]const u8 {
        return std.json.Stringify.valueAlloc(a, c.opts.priority, .{});
    }

    fn nowS(c: *Crawler) i64 {
        return std.Io.Clock.real.now(c.io).toSeconds();
    }

    pub fn fail(c: *Crawler, err: anyerror) void {
        {
            c.failure_lock.lockUncancelable(c.io);
            defer c.failure_lock.unlock(c.io);
            if (c.failure == null) c.failure = err;
            c.stop.store(true, .release);
        }
        c.writer.wake();
    }

    /// `--timelines-priority` percent of priority platform matches, `--timelines` of the
    /// rest, by match id hash so a rerun picks the same games
    pub fn wantTimeline(c: *const Crawler, match_id: []const u8) bool {
        const priority = if (ep.platformOf(match_id)) |p| c.isPriority(p) else false;
        const pct = if (priority) c.opts.timeline_priority_percent else c.opts.timeline_percent;
        return pct >= 100 or std.hash.Wyhash.hash(0, match_id) % 100 < pct;
    }

    /// --timelines-sparse counts from the newest patch's stored and queued timelines
    fn seedSparse(c: *Crawler, db: store.Db) !void {
        if (c.opts.timeline_sparse == 0) return;
        const started = c.nowS();
        var arena: std.heap.ArenaAllocator = .init(c.gpa);
        defer arena.deinit();
        var newest: []const u8 = "";
        for (try column(db, arena.allocator(), "SELECT DISTINCT patch FROM matches", .{})) |p| {
            if (Patches.code(p) > Patches.code(newest)) newest = p;
        }
        if (!c.sparse.current(Patches.code(newest)) or newest.len == 0) return;
        var q = try db.prepare(
            \\SELECT m.match_id, p.team_id, p.position, p.champion_id, p.tier FROM matches m
            \\JOIN participants p ON p.match_id = m.match_id
            \\WHERE m.patch = ? AND m.queue_id = ? AND m.remake = 0 AND (
            \\    EXISTS (SELECT 1 FROM timeline.timelines t WHERE t.match_id = m.match_id) OR
            \\    EXISTS (SELECT 1 FROM timeline_queue t WHERE t.match_id = m.match_id))
        );
        defer q.deinit();
        try q.bind(.{ newest, ep.ranked_solo });
        var last: std.ArrayList(u8) = .empty;
        defer last.deinit(c.gpa);
        var game: sparse.Game = .{};
        var games: usize = 0;
        while (try q.step()) {
            const r = q.row(struct { match_id: []const u8, team_id: i64, position: ?[]const u8, champion_id: i64, tier: ?[]const u8 });
            if (!std.mem.eql(u8, r.match_id, last.items)) {
                if (last.items.len > 0) try c.sparse.add(c.gpa, &game);
                games += 1;
                game = .{};
                last.clearRetainingCapacity();
                try last.appendSlice(c.gpa, r.match_id);
            }
            game.lane(r.team_id, r.position, r.champion_id);
            if (r.tier) |t| game.rankTier(t);
        }
        if (last.items.len > 0) try c.sparse.add(c.gpa, &game);
        log.info("--timelines-sparse: {d} games of {s} with a timeline, {d} cells, {d} s", .{
            games, newest, c.sparse.counts.count(), c.nowS() - started,
        });
    }

    /// Queue timelines for matches crawled before timelines existed. Runs while the
    /// queue is empty, so in practice once
    fn backfillTimelines(c: *Crawler, db: store.Db) !void {
        if (c.opts.timeline_percent == 0 and (c.opts.priority.len == 0 or c.opts.timeline_priority_percent == 0)) return;
        if (try db.scalar("SELECT EXISTS (SELECT 1 FROM timeline_queue)", .{}) == 1) return;
        var q = try db.prepare(
            \\SELECT match_id FROM matches m WHERE remake = 0 AND queue_id = ?
            \\    AND NOT EXISTS (SELECT 1 FROM timeline.timelines t WHERE t.match_id = m.match_id)
        );
        defer q.deinit();
        try q.bind(.{ep.ranked_solo});
        var ins = try db.prepare("INSERT OR IGNORE INTO timeline_queue " ++
            "(match_id, region, queued_at) VALUES (?, ?, ?)");
        defer ins.deinit();
        var queued: usize = 0;
        try db.begin();
        errdefer db.rollback();
        const t = c.nowS();
        while (try q.step()) {
            const id = q.bytes(0);
            const p = ep.platformOf(id) orelse continue;
            if (!c.wantTimeline(id)) continue;
            try ins.exec(.{ id, @tagName(p.region), t });
            queued += 1;
        }
        try db.commit();
        if (queued > 0) log.info("queued timelines for {d} earlier matches", .{queued});
    }
};

/// Stored matches and timelines used to stay queued as 'done'; now they leave the
/// queue. A no-op once the old rows are gone
fn dropDoneRows(db: store.Db) !void {
    inline for (.{ "match_queue", "timeline_queue" }) |table| {
        var total: i64 = 0;
        while (true) {
            try db.run("DELETE FROM " ++ table ++ " WHERE match_id IN (SELECT match_id FROM " ++
                table ++ " WHERE status = 'done' LIMIT 5000)", .{});
            const n = db.changes();
            total += n;
            if (n == 0) break;
        }
        if (total > 0) log.info("dropped {d} done rows from {s}", .{ total, table });
    }
}

const KeyProbe = struct {
    platform: ep.Platform,
    buf: [96]u8 = undefined,
    len: usize = 0,

    fn init(platform: ep.Platform, id: []const u8) ?KeyProbe {
        var p: KeyProbe = .{ .platform = platform };
        if (id.len > p.buf.len) return null;
        @memcpy(p.buf[0..id.len], id);
        p.len = id.len;
        return p;
    }

    fn puuid(p: *const KeyProbe) []const u8 {
        return p.buf[0..p.len];
    }
};

/// Thread body for a RegionCrawler or PlatformCrawler (`T`): connect, then `step` until
/// stopped. Both have `b: Bucket`, `init(c, T.Of)` and `step()`
fn Thread(comptime T: type) type {
    return struct {
        fn run(c: *Crawler, of: T.Of) void {
            var t = while (true) {
                break T.init(c, of) catch |err| {
                    if (err != error.Busy or c.stop.load(.acquire)) return c.fail(err);
                    c.io.sleep(.fromSeconds(5), .awake) catch return c.fail(err);
                    continue;
                };
            };
            defer t.b.deinit();
            loop(&t) catch |err| {
                if (err != error.Stopping) {
                    log.err("{s} thread: {t}", .{ t.b.name, err });
                    c.fail(err);
                }
            };
        }

        fn loop(t: *T) !void {
            while (true) {
                try t.b.check();
                t.b.countRequests();
                t.step() catch |err| switch (err) {
                    error.Busy => {
                        log.warn("{s}: database busy, pausing", .{t.b.name});
                        try t.b.nap(5);
                    },
                    else => return err,
                };
                try t.b.flush();
            }
        }
    };
}

/// What each thread owns for its Riot rate limit bucket: HTTP client, a read-only
/// connection and its place in the writer's queue
const Bucket = struct {
    c: *Crawler,
    name: []const u8,
    /// Reads only
    db: store.Db,
    client: Client,
    /// Its jobs may fill the writer's whole queue, other buckets' only half
    priority: bool,
    /// countRequests adds this thread's requests here
    requests: *std.atomic.Value(u64),
    reported_requests: u64 = 0,
    /// Sequence number of this thread's newest job, for flush
    last_seq: u64 = 0,

    /// run() migrated already; threads only connect
    fn init(c: *Crawler, name: []const u8, priority: bool, requests: *std.atomic.Value(u64)) !Bucket {
        const db = try store.schema.connect(c.gpa, c.opts.data_dir);
        errdefer db.close();
        var client: Client = .init(c.gpa, c.io, c.opts.key, c.limiters.get(name).?);
        client.fake = c.opts.fake;
        return .{ .c = c, .name = name, .db = db, .client = client, .priority = priority, .requests = requests };
    }

    fn deinit(b: *Bucket) void {
        b.countRequests();
        b.client.deinit();
        b.db.close();
    }

    fn countRequests(b: *Bucket) void {
        const n = b.client.requests.load(.monotonic);
        _ = b.requests.fetchAdd(n - b.reported_requests, .monotonic);
        b.reported_requests = n;
    }

    /// Hand a job to the writer, which owns it from then on
    fn submit(b: *Bucket, job: *Job) !void {
        b.last_seq = try b.c.writer.submit(job, b.priority);
    }

    /// Until everything this thread queued is committed: before reading what it changes
    fn flush(b: *Bucket) !void {
        try b.c.writer.wait(b.last_seq);
    }

    fn check(b: *Bucket) !void {
        if (b.c.stop.load(.acquire)) return error.Stopping;
    }

    /// Errors that stop the crawler; anything else is logged and the item skipped
    fn fatal(b: *Bucket, err: anyerror) bool {
        return switch (err) {
            error.KeyRejected => b.c.keyRejected(),
            // Busy too (a read, rare in WAL): the thread pauses and carries on
            error.OutOfMemory, error.Stopping, error.Sqlite, error.Busy => true,
            else => false,
        };
    }

    fn nap(b: *Bucket, seconds: u32) !void {
        for (0..seconds) |_| {
            try b.check();
            try b.c.io.sleep(.fromSeconds(1), .awake);
        }
    }

    fn now(b: *Bucket) i64 {
        return b.c.nowS();
    }

    fn queueStatus(b: *Bucket, which: writer.Kind.Queue, id: []const u8, status: writer.Kind.Status) !void {
        const job = try Job.create(b.c.gpa, .none);
        errdefer job.destroy(b.c.gpa);
        job.kind = .{ .queue = .{ .which = which, .id = try job.allocator().dupe(u8, id), .status = status } };
        try b.submit(job);
    }
};

/// First column of every row, copied into `arena`
fn column(db: store.Db, arena: std.mem.Allocator, sql: []const u8, args: anytype) ![]const []const u8 {
    var s = try db.prepare(sql);
    defer s.deinit();
    try s.bind(args);
    var out: std.ArrayList([]const u8) = .empty;
    while (try s.step()) try out.append(arena, try arena.dupe(u8, s.bytes(0)));
    return out.items;
}

/// Each platform's newest patch and the start of its first game seen (s). The first
/// game we see trails the real rollout by however long it took to find one: games in
/// between are missed, never an older patch's
pub const Patches = struct {
    of: [ep.platforms.len]Start = @splat(.{}),

    const Start = struct { patch: u32 = 0, start_s: i64 = 0 };

    /// "16.20" -> 16020; 0 when not a patch. u16 parts: Riot's gameVersion can't overflow it
    pub fn code(patch: []const u8) u32 {
        const dot = std.mem.indexOfScalar(u8, patch, '.') orelse return 0;
        const major = std.fmt.parseInt(u16, patch[0..dot], 10) catch return 0;
        const minor = std.fmt.parseInt(u16, patch[dot + 1 ..], 10) catch return 0;
        return @as(u32, major) * 1000 + minor;
    }

    test code {
        try std.testing.expectEqual(16020, code("16.20"));
        try std.testing.expectEqual(0, code("16"));
        try std.testing.expectEqual(0, code("99999999.1"));
    }

    fn index(platform: []const u8) ?usize {
        for (ep.platforms, 0..) |p, i| if (std.mem.eql(u8, p.id, platform)) return i;
        return null;
    }

    /// A stored or fetched game. False when it is from an older patch than the
    /// platform's newest
    fn see(ps: *Patches, platform: []const u8, patch: []const u8, start_s: i64) bool {
        const s = &ps.of[index(platform) orelse return true];
        const p = code(patch);
        if (p == 0) return true;
        if (p > s.patch) {
            s.* = .{ .patch = p, .start_s = start_s };
        } else if (p == s.patch) {
            s.start_s = @min(s.start_s, start_s);
        }
        return p >= s.patch;
    }

    /// When the platform's newest patch began, null before any of its games
    fn start(ps: *const Patches, platform: []const u8) ?i64 {
        const s = ps.of[index(platform) orelse return null];
        return if (s.patch == 0) null else s.start_s;
    }

    /// The two newest patches overall, so a platform still on the older one (rollouts
    /// differ by a day or so) has its start too
    fn load(gpa: std.mem.Allocator, db: store.Db) !Patches {
        var arena: std.heap.ArenaAllocator = .init(gpa);
        defer arena.deinit();
        var newest: [2][]const u8 = .{ "", "" };
        for (try column(db, arena.allocator(), "SELECT DISTINCT patch FROM matches", .{})) |p| {
            if (code(p) > code(newest[0])) {
                newest[1] = newest[0];
                newest[0] = p;
            } else if (code(p) > code(newest[1])) newest[1] = p;
        }
        var ps: Patches = .{};
        var q = try db.prepare("SELECT platform, min(game_start) / 1000 FROM matches " ++
            "WHERE patch = ? GROUP BY platform");
        defer q.deinit();
        for (newest) |patch| {
            if (patch.len == 0) continue;
            try q.bind(.{patch});
            while (try q.step()) {
                const r = q.row(struct { platform: []const u8, start_s: i64 });
                _ = ps.see(r.platform, patch, r.start_s);
            }
        }
        return ps;
    }

    fn log(ps: *const Patches) void {
        for (ep.platforms, ps.of) |p, s| {
            if (s.patch == 0) continue;
            std.log.scoped(.crawl).info("{s} patch {d}.{d} since {d}", .{ p.id, s.patch / 1000, s.patch % 1000, s.start_s });
        }
    }
};

/// Match ids, match details and timelines for one regional route
const RegionCrawler = struct {
    b: Bucket,
    region: ep.Region,
    patches: Patches,
    /// UTC day and flex lookups made on it (--flex-calls-per-day)
    flex_day: i64 = 0,
    flex_calls: u32 = 0,
    /// Each platform's patch whose start went to the writer (patchStarts)
    started: [ep.platforms.len]u32 = @splat(0),
    /// matches rowid the snowball has read up to
    snowball_after: i64 = 0,
    /// game_start (ms) the spare-budget timeline walk goes on below, and when the walk
    /// began
    backfill_before: i64 = 0,
    backfill_walk_at: i64 = 0,
    /// Recent new match ids per call by source (snowball and stale used), and when each
    /// next runs regardless. Snowball starts at 16.21 day's measure
    yield: std.EnumArray(Source, f64) = .init(.{ .active = 0, .snowball = 2, .stale = 0 }),
    probe_at: std.EnumArray(Source, i64) = .initFill(0),

    const Of = ep.Region;

    fn init(c: *Crawler, r: ep.Region) !RegionCrawler {
        const requests = &c.counters.region[@backingInt(r)].requests;
        var rc: RegionCrawler = .{
            .b = try .init(c, @tagName(r), c.isPriorityRegion(r), requests),
            .region = r,
            .patches = c.patches,
        };
        errdefer rc.b.deinit();
        const newest = try rc.b.db.scalar("SELECT max(rowid) FROM matches", .{}) orelse 0;
        rc.snowball_after = @max(0, newest - snowball_backlog);
        return rc;
    }

    fn counters(rc: *RegionCrawler) *RegionCounters {
        return &rc.b.c.counters.region[@backingInt(rc.region)];
    }

    /// One round: refill match ids when the queue runs short, then a batch of matches
    /// and as many timelines, newest first, so new games get theirs at once. A short
    /// match batch makes room for more timelines, so a backlog drains in quiet spells
    fn step(rc: *RegionCrawler) !void {
        if (rc.b.c.opts.patch_only) try rc.patchStarts();
        const pending = try rc.b.db.scalar("SELECT count(*) FROM match_queue " ++
            "WHERE region = ? AND status = 'pending'", .{@tagName(rc.region)}) orelse 0;
        const scanned = if (pending < pending_low) try rc.scanPlayers(.useful) else 0;
        const matches = try rc.drain(.match, detail_batch);
        const timelines = try rc.drain(.timeline, if (matches == detail_batch) detail_batch else timeline_batch);
        if (scanned + matches + timelines == 0) try rc.spare();
    }

    /// Nothing queued and no player known to have new games: blind rescans while they
    /// find enough, else timelines the sample skipped, else the snowball and blind
    /// rescans anyway, else a nap
    fn spare(rc: *RegionCrawler) !void {
        if (rc.worth(.stale) and try rc.scanPlayers(.stale) > 0) return;
        if (try rc.skippedTimelines() > 0) return;
        if (try rc.scanPlayers(.snowball) > 0) return;
        if (try rc.scanPlayers(.stale) > 0) return;
        _ = rc.counters().idle_s.fetchAdd(idle_s, .monotonic);
        try rc.b.nap(idle_s);
    }

    fn worth(rc: *RegionCrawler, s: Source) bool {
        return rc.yield.get(s) >= min_yield or rc.b.now() >= rc.probe_at.get(s);
    }

    /// Ranked matches the timeline sample skipped (wantTimeline), long enough, newest
    /// first: game_start (ms) below ?1, at least ?2. Uses matches_start
    const skipped_timelines =
        \\SELECT match_id, game_start FROM matches m
        \\WHERE game_start < ?1 AND game_start >= ?2
        \\    AND platform IN (SELECT value FROM json_each(?3))
        \\    AND queue_id = ?4 AND remake = 0 AND duration_s >= ?5
        \\    AND NOT EXISTS (SELECT 1 FROM timeline.timelines t WHERE t.match_id = m.match_id)
        \\    AND NOT EXISTS (SELECT 1 FROM timeline_queue q WHERE q.match_id = m.match_id)
        \\ORDER BY game_start DESC
        \\LIMIT ?6
    ;

    /// Spare budget's timelines, a guaranteed result per call: a walk down from now to
    /// since_days back, so the newest patch's come first, begun again hourly for the
    /// matches stored since
    fn skippedTimelines(rc: *RegionCrawler) !usize {
        const c = rc.b.c;
        const now = rc.b.now();
        if (now - rc.backfill_walk_at >= 3600) {
            rc.backfill_before = now * 1000;
            rc.backfill_walk_at = now;
        }
        const floor = (now - c.opts.since_days * std.time.s_per_day) * 1000;
        var arena: std.heap.ArenaAllocator = .init(c.gpa);
        defer arena.deinit();
        const a = arena.allocator();
        var q = try rc.b.db.prepare(skipped_timelines);
        defer q.deinit();
        try q.bind(.{ rc.backfill_before, floor, try rc.platformsJson(a), ep.ranked_solo, c.opts.timeline_min_s, backfill_batch });
        var ids: std.ArrayList([]const u8) = .empty;
        // Walked to the floor when none: nothing more until the next walk
        rc.backfill_before = floor;
        while (try q.step()) {
            const r = q.row(struct { match_id: []const u8, game_start: i64 });
            try ids.append(a, try a.dupe(u8, r.match_id));
            rc.backfill_before = r.game_start;
        }
        for (ids.items) |id| {
            try rc.b.check();
            try rc.fetchTimeline(id);
            _ = rc.counters().backfill.fetchAdd(1, .monotonic);
        }
        try rc.b.flush();
        return ids.items.len;
    }

    /// The region's platform ids as a JSON array
    fn platformsJson(rc: *const RegionCrawler, a: std.mem.Allocator) ![]const u8 {
        var ids: std.ArrayList([]const u8) = .empty;
        for (ep.platforms) |p| if (p.region == rc.region) try ids.append(a, p.id);
        return std.json.Stringify.valueAlloc(a, ids.items, .{});
    }

    /// Once per platform and patch, so active_first skips players whose new ladder games
    /// are all an older patch's: on a patch day they made most match id calls return
    /// nothing. At startup too, for a patch begun before it
    fn patchStarts(rc: *RegionCrawler) !void {
        const gpa = rc.b.c.gpa;
        for (ep.platforms, rc.patches.of, &rc.started) |p, s, *started| {
            if (p.region != rc.region or s.patch == started.*) continue;
            const job = try Job.create(gpa, .none);
            errdefer job.destroy(gpa);
            job.kind = .{ .patch_start = .{ .platform = p, .start_s = s.start_s } };
            try rc.b.submit(job);
            started.* = s.patch;
        }
    }

    /// Fetch up to `n` of a queue's next items and wait for the writer to store them,
    /// so the next read of the queue doesn't see them again. Matches queue their
    /// timelines as they are stored
    fn drain(rc: *RegionCrawler, which: writer.Kind.Queue, n: usize) !usize {
        var arena: std.heap.ArenaAllocator = .init(rc.b.c.gpa);
        defer arena.deinit();
        const a = arena.allocator();
        const sql = switch (which) {
            .match => next_matches,
            .timeline => next_timelines,
        };
        const ids = try column(rc.b.db, a, sql, .{ @tagName(rc.region), try rc.b.c.priorityJson(a), n });
        for (ids) |id| {
            try rc.b.check();
            switch (which) {
                .match => try rc.fetchMatch(id),
                .timeline => try rc.fetchTimeline(id),
            }
        }
        try rc.b.flush();
        return ids.len;
    }

    /// Priority platforms first (other platforms share the regional rate limit), then
    /// first in, first out
    const next_matches =
        \\SELECT match_id FROM match_queue WHERE region = ?1 AND status = 'pending'
        \\ORDER BY substr(match_id, 1, instr(match_id, '_') - 1)
        \\    IN (SELECT value FROM json_each(?2)) DESC, discovered_at, match_id
        \\LIMIT ?3
    ;
    /// Priority platforms first, then newest first
    const next_timelines =
        \\SELECT match_id FROM timeline_queue WHERE region = ?1 AND status = 'pending'
        \\ORDER BY substr(match_id, 1, instr(match_id, '_') - 1)
        \\    IN (SELECT value FROM json_each(?2)) DESC, queued_at DESC, match_id DESC
        \\LIMIT ?3
    ;

    const scan_players =
        \\SELECT puuid, matches_checked_at, platform FROM players
        \\WHERE region = ?1 AND (?2 IS NULL OR platform = ?2)
        \\    AND (matches_checked_at IS NULL OR matches_checked_at < ?3)
        \\    AND (?5 IS NULL OR instr(?5, '|' || tier || '|') > 0)
        \\ORDER BY matches_checked_at, puuid
        \\LIMIT ?4
    ;

    /// Players with ranked games since their last scan (ladder wins + losses), most
    /// first. Uses players_new_games. ?5 (--patch-only): scanned players only, as a
    /// never scanned one's count runs from its first sighting, mostly older patches on
    /// a patch day (16.21 americas: 0.41 new ids per call); scan_players takes those first
    const new_games =
        \\SELECT puuid, matches_checked_at, platform FROM players
        \\WHERE region = ?1 AND games_checked IS NOT NULL AND wins + losses - games_checked > 0
        \\    AND (?2 IS NULL OR platform = ?2)
        \\    AND (?3 IS NULL OR instr(?3, '|' || tier || '|') > 0)
        \\    AND (NOT ?5 OR matches_checked_at IS NOT NULL)
        \\ORDER BY wins + losses - games_checked DESC
        \\LIMIT ?4
    ;

    /// "|CHALLENGER|...|PLATINUM|" for scan_players, null when every tier is in
    fn tierFloor(a: std.mem.Allocator, min_tier: usize) !?[]const u8 {
        if (min_tier + 1 >= tiers.len) return null;
        return try a.print("|{s}|", .{try std.mem.join(a, "|", tiers[0 .. min_tier + 1])});
    }

    /// Sampled players in the region's newly stored matches, played after their last
    /// scan: one who just played tends to have more games of the session (16.21 day: 1.6
    /// to 3.5 more per scanned player with one). Matches in storage order after ?1, up
    /// to ?2
    const snowball_players =
        \\SELECT p.puuid, p.matches_checked_at, p.platform, m.rowid, m.game_start / 1000
        \\FROM matches m CROSS JOIN participants pa ON pa.match_id = m.match_id
        \\CROSS JOIN players p ON p.puuid = pa.puuid
        \\WHERE m.rowid > ?1 AND m.rowid <= ?2 AND m.platform IN (SELECT value FROM json_each(?3))
        \\    AND (p.matches_checked_at IS NULL OR p.matches_checked_at < m.game_start / 1000)
        \\    AND (?4 IS NULL OR instr(?4, '|' || p.tier || '|') > 0)
        \\ORDER BY m.rowid
        \\LIMIT ?5
    ;

    const Scan = enum { useful, snowball, stale };

    /// .useful: players the ladder shows played since their last scan, most new games
    /// first, then the snowball's while it finds enough. .stale: never scanned (NULL
    /// sorts first), then the stalest; PUUIDs are random, so ordering by them samples
    /// players without favouring any rank or activity. Priority platforms' players
    /// first. Waits for the writer, so the match queue has their ids
    fn scanPlayers(rc: *RegionCrawler, which: Scan) !u32 {
        const c = rc.b.c;
        var arena: std.heap.ArenaAllocator = .init(c.gpa);
        defer arena.deinit();
        const a = arena.allocator();
        const floor = try tierFloor(a, c.opts.min_tier);
        var players: std.ArrayList(Player) = .empty;
        var filters: std.ArrayList(?[]const u8) = .empty;
        for (c.opts.priority) |id| {
            const p = ep.platform(id) orelse continue;
            if (p.region == rc.region) try filters.append(a, id);
        }
        try filters.append(a, null);
        switch (which) {
            .useful => if (c.opts.active_first) {
                var s = try rc.b.db.prepare(new_games);
                defer s.deinit();
                for (filters.items) |platform| {
                    if (players.items.len == scan_batch) break;
                    try s.bind(.{ @tagName(rc.region), platform, floor, scan_batch - players.items.len, c.opts.patch_only });
                    try takePlayers(a, &s, &players, .active);
                }
                if (players.items.len < scan_batch and rc.worth(.snowball)) try rc.snowball(a, floor, &players);
            },
            .snowball => try rc.snowball(a, floor, &players),
            .stale => {
                var s = try rc.b.db.prepare(scan_players);
                defer s.deinit();
                for (filters.items) |platform| {
                    if (players.items.len == scan_batch) break;
                    try s.bind(.{ @tagName(rc.region), platform, rc.b.now() - c.opts.recheck_s, scan_batch - players.items.len, floor });
                    try takePlayers(a, &s, &players, .stale);
                }
            },
        }
        const cs = rc.counters();
        var calls_before: std.EnumArray(Source, u64) = undefined;
        var found_before: std.EnumArray(Source, u64) = undefined;
        for (std.enums.values(Source)) |src| {
            calls_before.set(src, cs.calls_by.get(src).load(.monotonic));
            found_before.set(src, cs.found_by.get(src).load(.monotonic));
        }
        for (players.items) |p| {
            try rc.b.check();
            rc.scanPlayer(p) catch |err| {
                if (rc.b.fatal(err)) return err;
                log.warn("{t} match ids: {t}", .{ rc.region, err });
                // Marking them checked would skip their games since the last scan
                if (err == error.RateLimited) continue;
            };
            // Even after another error, so a bad player waits for the recheck interval
            const job = try Job.create(c.gpa, .none);
            errdefer job.destroy(c.gpa);
            job.kind = .{ .checked = .{ .puuid = try job.allocator().dupe(u8, p.puuid), .t = rc.b.now() } };
            try rc.b.submit(job);
        }
        try rc.b.flush();
        for (std.enums.values(Source)) |src| {
            const calls = cs.calls_by.get(src).load(.monotonic) - calls_before.get(src);
            if (calls == 0) continue;
            const found = cs.found_by.get(src).load(.monotonic) - found_before.get(src);
            const per_call = @as(f64, @floatFromInt(found)) / @as(f64, @floatFromInt(calls));
            rc.yield.set(src, 0.7 * rc.yield.get(src) + 0.3 * per_call);
            rc.probe_at.set(src, rc.b.now() + probe_s);
        }
        return @intCast(players.items.len);
    }

    /// Fills `players` from snowball_players, past every match it reads
    fn snowball(rc: *RegionCrawler, a: std.mem.Allocator, floor: ?[]const u8, players: *std.ArrayList(Player)) !void {
        const newest = try rc.b.db.scalar("SELECT max(rowid) FROM matches", .{}) orelse 0;
        var s = try rc.b.db.prepare(snowball_players);
        defer s.deinit();
        // Rows over the batch: some are skipped below
        const limit = 4 * scan_batch;
        try s.bind(.{ rc.snowball_after, newest, try rc.platformsJson(a), floor, limit });
        var rows: usize = 0;
        next: while (try s.step()) {
            rows += 1;
            const r = s.row(struct { puuid: []const u8, checked_at: ?i64, platform: []const u8, rowid: i64, start_s: i64 });
            rc.snowball_after = r.rowid;
            if (rc.b.c.opts.patch_only) if (rc.patches.start(r.platform)) |start| if (r.start_s < start) continue;
            for (players.items) |p| if (std.mem.eql(u8, p.puuid, r.puuid)) continue :next;
            try players.append(a, .{
                .puuid = try a.dupe(u8, r.puuid),
                .checked_at = r.checked_at,
                .platform = try a.dupe(u8, r.platform),
                .source = .snowball,
            });
            if (players.items.len == scan_batch) return;
        }
        if (rows < limit) rc.snowball_after = newest;
    }

    const Player = struct { puuid: []const u8, checked_at: ?i64, platform: []const u8, source: Source };

    /// Rows of new_games or scan_players, skipping players already taken
    fn takePlayers(a: std.mem.Allocator, s: *store.Stmt, players: *std.ArrayList(Player), source: Source) !void {
        next: while (try s.step()) {
            const r = s.row(struct { puuid: []const u8, checked_at: ?i64, platform: []const u8 });
            for (players.items) |p| if (std.mem.eql(u8, p.puuid, r.puuid)) continue :next;
            try players.append(a, .{
                .puuid = try a.dupe(u8, r.puuid),
                .checked_at = r.checked_at,
                .platform = try a.dupe(u8, r.platform),
                .source = source,
            });
        }
    }

    fn scanPlayer(rc: *RegionCrawler, p: Player) !void {
        const c = rc.b.c;
        const end = rc.b.now();
        var start_time = @max(p.checked_at orelse 0, end - c.opts.since_days * 86400);
        if (c.opts.patch_only) start_time = @max(start_time, rc.patches.start(p.platform) orelse 0);
        var start: u32 = 0;
        while (true) : (start += 100) {
            if (try rc.queueIds(p.puuid, p.source, ep.ranked_solo, start_time, end, start) < 100) break;
        }
        // One page: a sample of the player's flex games, not all of them
        if (rc.flexDue(p.platform, end)) _ = try rc.queueIds(p.puuid, p.source, ep.ranked_flex, start_time, end, 0);
    }

    /// One page of the player's match ids in `queue`, onto the match queue; how many
    fn queueIds(rc: *RegionCrawler, puuid: []const u8, source: Source, queue: u16, start_time: i64, end: i64, start: u32) !usize {
        const c = rc.b.c;
        const got = try ep.matchIds(&rc.b.client, rc.region, puuid, queue, start_time, end, start);
        defer if (got) |b| c.gpa.free(b);
        const body = got orelse "[]";
        _ = rc.counters().ids_calls.fetchAdd(1, .monotonic);
        _ = rc.counters().calls_by.getPtr(source).fetchAdd(1, .monotonic);
        const job = try Job.create(c.gpa, .none);
        errdefer job.destroy(c.gpa);
        const ids = try ep.parse([]const []const u8, job.allocator(), try job.allocator().dupe(u8, body));
        job.kind = .{ .match_ids = .{ .ids = ids, .discovered_at = end, .region = rc.region, .source = source } };
        try rc.b.submit(job);
        return ids.len;
    }

    /// A flex lookup for this player: a --priority platform, and today's are not used up
    fn flexDue(rc: *RegionCrawler, platform: []const u8, now: i64) bool {
        const c = rc.b.c;
        const p = ep.platform(platform) orelse return false;
        if (c.opts.flex_calls_per_day == 0 or !c.isPriority(p)) return false;
        const day = @divFloor(now, std.time.s_per_day);
        if (day != rc.flex_day) {
            rc.flex_day = day;
            rc.flex_calls = 0;
        }
        if (rc.flex_calls >= c.opts.flex_calls_per_day) return false;
        rc.flex_calls += 1;
        return true;
    }

    fn fetchMatch(rc: *RegionCrawler, id: []const u8) !void {
        const gpa = rc.b.c.gpa;
        const got = ep.match(&rc.b.client, rc.region, id) catch |err| {
            if (rc.b.fatal(err)) return err;
            log.warn("match {s}: {t}", .{ id, err });
            // Left pending, so a 429 storm can't use up its tries
            if (err == error.RateLimited) return;
            return rc.b.queueStatus(.match, id, .attempt);
        };
        const fetched = got orelse return rc.b.queueStatus(.match, id, .missing);
        defer gpa.free(fetched);
        if (!wholeDoc(fetched)) {
            log.warn("match {s}: not a whole document ({d} bytes), tried again later", .{ id, fetched.len });
            return rc.b.queueStatus(.match, id, .attempt);
        }

        const job = try Job.create(gpa, .none);
        errdefer job.destroy(gpa);
        const a = job.allocator();
        const body = try a.dupe(u8, fetched);
        const doc = match.parse(a, body) catch |err| {
            if (err == error.OutOfMemory) return err;
            log.warn("match {s} did not parse: {t}", .{ id, err });
            job.kind = .{ .queue = .{ .which = .match, .id = try a.dupe(u8, id), .status = .failed } };
            return rc.b.submit(job);
        };
        const platform = doc.info.platformId orelse if (ep.platformOf(id)) |p| p.id else "";
        const start_ms = doc.info.gameStartTimestamp orelse doc.info.gameCreation;
        const current = rc.patches.see(platform, match.patchOf(doc.info.gameVersion), @divFloor(start_ms, 1000));
        job.kind = .{ .match = .{
            .region = rc.region,
            .id = try a.dupe(u8, id),
            .doc = doc,
            .raw = try store.raw.compress(a, body),
            .t = rc.b.now(),
            .timeline = current or !rc.b.c.opts.patch_only,
        } };
        try rc.b.submit(job);
    }

    /// The raw JSON is kept when extraction fails (and not pruned), so a fixed parser
    /// can redo it
    fn fetchTimeline(rc: *RegionCrawler, id: []const u8) !void {
        const gpa = rc.b.c.gpa;
        const got = ep.timeline(&rc.b.client, rc.region, id) catch |err| {
            if (rc.b.fatal(err)) return err;
            log.warn("timeline {s}: {t}", .{ id, err });
            // Left pending, so a 429 storm can't use up its tries
            if (err == error.RateLimited) return;
            return rc.b.queueStatus(.timeline, id, .attempt);
        };
        const body = got orelse return rc.b.queueStatus(.timeline, id, .missing);
        defer gpa.free(body);
        // Kept raw it would be a document no parser can redo, and it stopped the raw
        // archive for 40 h (an empty 200, OC1, 15 Oct)
        if (!wholeDoc(body)) {
            log.warn("timeline {s}: not a whole document ({d} bytes), tried again later", .{ id, body.len });
            return rc.b.queueStatus(.timeline, id, .attempt);
        }

        const job = try Job.create(gpa, .none);
        errdefer job.destroy(gpa);
        const a = job.allocator();
        const compact = compactTimeline(a, body) catch |err| blk: {
            if (err == error.OutOfMemory) return err;
            log.warn("timeline {s} did not parse: {t}", .{ id, err });
            break :blk null;
        };
        const keep_raw = rc.b.c.opts.raw_timeline_days > 0 or compact == null;
        job.kind = .{ .timeline = .{
            .region = rc.region,
            .id = try a.dupe(u8, id),
            .raw = if (keep_raw) try store.raw.compress(a, body) else null,
            .compact = compact,
            .t = rc.b.now(),
        } };
        try rc.b.submit(job);
    }
};

/// League ladder pages, then champion mastery, for one platform route. Never priority
/// at the writer: a ladder page costs ~100x a match in writes, so even EUW1's waits
const PlatformCrawler = struct {
    b: Bucket,
    platform: ep.Platform,
    /// Last PUUID given mastery, so each batch resumes instead of rescanning done players
    mastery_cursor: [128]u8 = undefined,
    mastery_cursor_len: usize = 0,
    /// The ladder list's current pass stored a snapshot; a pass that stored none waits
    /// `mastery_rewrap_s` to wrap
    mastery_pass_stored: bool = false,
    /// When the ladder list may wrap again (s)
    mastery_wrap_at: i64 = 0,
    /// The last fetchMastery got a snapshot, not a 404
    mastery_got: bool = false,
    /// Mastery calls failed in a row; reset by a success
    mastery_failures: u32 = 0,
    /// During an outage, when the next mastery call may try (s)
    mastery_retry_at: i64 = 0,
    /// The last player whose mastery call worked: after failures in a row, a call for it
    /// tells an outage (it fails too) from a run of bad PUUIDs (it works)
    mastery_good: [128]u8 = undefined,
    mastery_good_len: usize = 0,
    /// matches.rowid up to which participants have been given mastery; null until the
    /// first pass, which starts at the past week's matches
    match_cursor: ?i64 = null,
    /// Within the batch after match_cursor: the last player tried, so a batch cut short
    /// by its deadline resumes instead of retrying its failures first
    batch_cursor: [128]u8 = undefined,
    batch_cursor_len: usize = 0,
    /// The participant pass has reached the newest stored match once (ends a sweep)
    swept: bool = false,
    /// When this thread last fetched a ladder page (--ladder-per-hour)
    last_ladder: i64 = 0,

    const Of = ep.Platform;

    fn init(c: *Crawler, p: ep.Platform) !PlatformCrawler {
        return .{ .b = try .init(c, p.host, false, &c.counters.platform_requests), .platform = p };
    }

    fn step(pc: *PlatformCrawler) !void {
        if (try pc.seedLadder() > 0) return;
        // Participants first: their pass is bounded (each player about weekly), while the
        // sampled ladder players without mastery number ~850k per platform and never run out
        if (pc.b.c.opts.mastery and try pc.fetchParticipantMasteries(20, null)) return;
        if (pc.b.c.opts.mastery and try pc.fetchMasteries(50) > 0) return;
        try pc.b.nap(60);
    }

    fn seedLadder(pc: *PlatformCrawler) !u32 {
        const p = pc.platform;
        var fetched: u32 = 0;
        for (tiers[0 .. pc.b.c.opts.min_tier + 1]) |tier| {
            const apex = std.mem.eql(u8, tier, "MASTER") or std.mem.eql(u8, tier, "GRANDMASTER") or
                std.mem.eql(u8, tier, "CHALLENGER");
            for (if (apex) divisions[0..1] else divisions[0..]) |division| {
                var page: u32 = 1;
                while (true) : (page += 1) {
                    try pc.b.check();
                    if (try pc.storedPage(tier, division, page)) |f| {
                        if (f.fetched_at > pc.b.now() - pc.b.c.opts.ladder_refresh_s) {
                            if (f.entries == 0) break;
                            continue;
                        }
                    }
                    try pc.ladderGap();
                    // A bad page ends this division for now; the next pass retries it
                    const entries = pc.fetchLadderPage(tier, division, page) catch |err| {
                        if (pc.b.fatal(err)) return err;
                        log.warn("{s} ladder {s} {s} page {d}: {t}", .{ p.host, tier, division, page, err });
                        break;
                    };
                    fetched += 1;
                    pc.b.countRequests();
                    if (entries == 0) break;
                }
            }
        }
        return fetched;
    }

    /// Finalised before returning: a statement left on its row holds a read transaction,
    /// and one held across the ladder gap and fetch kept main's WAL from ever restarting
    fn storedPage(pc: *PlatformCrawler, tier: []const u8, division: []const u8, page: u32) !?StoredPage {
        var s = try pc.b.db.prepare("SELECT entries, fetched_at FROM ladder_pages" ++
            " WHERE platform = ? AND tier = ? AND division = ? AND page = ?");
        defer s.deinit();
        try s.bind(.{ pc.platform.id, tier, division, page });
        return if (try s.step()) s.row(StoredPage) else null;
    }

    const StoredPage = struct { entries: i64, fetched_at: i64 };

    /// Nap until this platform may fetch another ladder page (--ladder-per-hour)
    fn ladderGap(pc: *PlatformCrawler) !void {
        const per_hour = pc.b.c.opts.ladder_per_hour;
        if (per_hour > 0) {
            const next = pc.last_ladder + @divTrunc(3600, @as(i64, per_hour));
            while (pc.b.now() < next) {
                // A reseed takes hours of gaps: participant mastery uses them, not a nap,
                // stopping at the gap's end so ladder pages keep their pace
                if (pc.b.c.opts.mastery and try pc.fetchParticipantMasteries(5, next)) continue;
                try pc.b.nap(1);
            }
        }
        pc.last_ladder = pc.b.now();
    }

    fn fetchLadderPage(pc: *PlatformCrawler, tier: []const u8, division: []const u8, page: u32) !usize {
        const gpa = pc.b.c.gpa;
        const got = try ep.leagueEntries(&pc.b.client, pc.platform, tier, division, page);
        defer if (got) |b| gpa.free(b);
        const job = try Job.create(gpa, .none);
        errdefer job.destroy(gpa);
        // Parsed strings may point into the body: the copy lives as long as the job
        const a = job.allocator();
        const entries = try ep.parse([]const ep.LeagueEntry, a, try a.dupe(u8, got orelse "[]"));
        job.kind = .{ .ladder = .{
            .platform = pc.platform,
            .tier = tier,
            .division = division,
            .page = page,
            .entries = entries,
            .t = pc.b.now(),
        } };
        try pc.b.submit(job);
        return entries.len;
    }

    /// A list down to players whose calls always fail (17 Oct: one tw2 PUUID Riot's edge
    /// refuses, after every other ladder player had mastery) still went round once a nap
    const mastery_rewrap_s = 6 * 3600;

    fn fetchMasteries(pc: *PlatformCrawler, n: u32) !u32 {
        if (pc.b.now() < pc.mastery_wrap_at) return 0;
        var arena: std.heap.ArenaAllocator = .init(pc.b.c.gpa);
        defer arena.deinit();
        const sql =
            \\SELECT p.puuid FROM players p
            \\WHERE p.platform = ? AND p.source = 'ladder' AND p.puuid > ? AND NOT EXISTS
            \\    (SELECT 1 FROM mastery m WHERE m.puuid = p.puuid)
            \\ORDER BY p.puuid LIMIT ?
        ;
        const id = pc.platform.id;
        const puuids = try column(pc.b.db, arena.allocator(), sql, .{ id, pc.masteryCursor(), n });
        // The end of the list wraps on the next step, after its nap: a list down to players
        // whose calls fail went round back to back (14 Oct: 5 euw1 PUUIDs, 60k calls a day)
        if (puuids.len == 0) {
            pc.mastery_cursor_len = 0;
            if (!pc.mastery_pass_stored) {
                log.info("{s} mastery: a ladder pass stored nothing, next pass in {d} h", .{
                    pc.platform.host, mastery_rewrap_s / 3600,
                });
                pc.mastery_wrap_at = pc.b.now() + mastery_rewrap_s;
            }
            pc.mastery_pass_stored = false;
        }
        for (puuids) |puuid| {
            try pc.b.check();
            // Players skipped here come round again when the cursor wraps
            if (!try pc.tryMastery(arena.allocator(), puuid)) {
                try pc.masteryPause(null);
                break;
            }
            if (pc.mastery_failures == 0 and pc.mastery_got) pc.mastery_pass_stored = true;
            setCursor(&pc.mastery_cursor, &pc.mastery_cursor_len, puuid);
        }
        return @intCast(puuids.len);
    }

    /// Snapshots near game time for the experience features: a refresh once a player's
    /// is older than this, so an active player gets about one a week. Riot asks for
    /// monthly refreshes; the writer drops snapshots after 30 days
    const participant_refresh_s = 7 * std.time.s_per_day;

    /// Where the first pass starts: the past week's matches, in storage order
    pub const match_cursor_start =
        \\SELECT coalesce((SELECT min(rowid) FROM matches WHERE game_start > ?) - 1,
        \\    (SELECT max(rowid) FROM matches), 0)
    ;
    /// Storage order, not game time: matches found late (a player's older games) still
    /// get theirs. The rowid of the batch's last match on this platform
    pub const match_batch_end =
        \\SELECT max(rowid) FROM
        \\    (SELECT rowid FROM matches WHERE rowid > ? AND platform = ? ORDER BY rowid LIMIT ?)
    ;
    /// Players of the batch's games from the past week without a snapshot this recent,
    /// after ?6 (the batch cursor)
    pub const participant_masteries =
        \\SELECT DISTINCT p.puuid FROM matches m JOIN participants p USING (match_id)
        \\WHERE m.rowid > ?1 AND m.rowid <= ?2 AND m.platform = ?3 AND m.game_start > ?4
        \\    AND p.puuid > ?6 AND NOT EXISTS
        \\    (SELECT 1 FROM mastery x WHERE x.puuid = p.puuid AND x.fetched_at > ?5)
        \\ORDER BY p.puuid
    ;

    /// Mastery for every player of up to n newly stored matches; false when none are new.
    /// At `deadline` (s) it stops with the batch unfinished: the next call resumes after
    /// the last player tried, so one whose call fails is skipped, not retried until the
    /// batch can never finish within a ladder gap (11 Oct: wrong-app PUUIDs stalled kr)
    fn fetchParticipantMasteries(pc: *PlatformCrawler, n: u32, deadline: ?i64) !bool {
        var arena: std.heap.ArenaAllocator = .init(pc.b.c.gpa);
        defer arena.deinit();
        const db = pc.b.db;
        const now = pc.b.now();
        const sweep_s = @as(i64, pc.b.c.opts.mastery_sweep_days) * std.time.s_per_day;
        const horizon_ms = (now - if (pc.swept) participant_refresh_s else @max(sweep_s, participant_refresh_s)) * 1000;
        const from = pc.match_cursor orelse try db.scalar(match_cursor_start, .{horizon_ms}) orelse 0;
        pc.match_cursor = from;
        // max() of no rows is NULL, read as 0
        const to = try db.scalar(match_batch_end, .{ from, pc.platform.id, n }) orelse 0;
        if (to <= from) {
            if (!pc.swept and sweep_s > participant_refresh_s) log.info("{s} mastery: sweep of {d} days done", .{
                pc.platform.host, pc.b.c.opts.mastery_sweep_days,
            });
            pc.swept = true;
            return false;
        }
        const puuids = try column(db, arena.allocator(), participant_masteries, .{
            from, to, pc.platform.id, horizon_ms, now - participant_refresh_s, pc.batch_cursor[0..pc.batch_cursor_len],
        });
        for (puuids) |puuid| {
            try pc.b.check();
            if (deadline) |d| if (pc.b.now() >= d) return true;
            // An outage keeps the batch cursor before this player, so it gets one after
            if (!try pc.tryMastery(arena.allocator(), puuid)) {
                try pc.masteryPause(deadline);
                return true;
            }
            setCursor(&pc.batch_cursor, &pc.batch_cursor_len, puuid);
        }
        pc.match_cursor = to;
        pc.batch_cursor_len = 0;
        return true;
    }

    /// Failures in a row that mean the platform's mastery endpoint is down (seen: na1
    /// 400s for every player for 3 min, ru write failures for 50 min), not one bad player
    const mastery_outage = 5;
    const mastery_pause_s = 60;

    /// False during an outage, `puuid` not given one: the caller stops, keeping it for
    /// later. True when it was tried, failed or not. After `mastery_outage` failures in a
    /// row the last good player is tried first: if it fails too, an outage, retried every
    /// `mastery_pause_s`; if it works, the failures were bad PUUIDs and the pass goes on
    fn tryMastery(pc: *PlatformCrawler, arena: std.mem.Allocator, puuid: []const u8) !bool {
        const good = pc.mastery_good[0..pc.mastery_good_len];
        if (pc.mastery_failures >= mastery_outage and good.len > 0) {
            if (pc.b.now() < pc.mastery_retry_at) return false;
            pc.fetchMastery(arena, good) catch |err| {
                if (pc.b.fatal(err)) return err;
                pc.mastery_failures += 1;
                if (pc.mastery_failures == mastery_outage + 1) log.warn("{s} mastery: {d} failures in a row " ++
                    "and the last good player fails too, trying again every {d}s", .{ pc.platform.host, mastery_outage, mastery_pause_s });
                pc.mastery_retry_at = pc.b.now() + mastery_pause_s;
                return false;
            };
            if (pc.mastery_failures > mastery_outage) log.info("{s} mastery: back", .{pc.platform.host});
            pc.mastery_failures = 0;
        }
        pc.fetchMastery(arena, puuid) catch |err| {
            if (pc.b.fatal(err)) return err;
            pc.mastery_failures += 1;
            if (pc.mastery_failures <= mastery_outage) log.warn("{s} mastery: {t}", .{ pc.platform.host, err });
            return true;
        };
        pc.mastery_failures = 0;
        setCursor(&pc.mastery_good, &pc.mastery_good_len, puuid);
        return true;
    }

    /// Until `deadline` (s) at most, so ladder pages keep their pace
    fn masteryPause(pc: *PlatformCrawler, deadline: ?i64) !void {
        const end = if (deadline) |d| @min(d, pc.mastery_retry_at) else pc.mastery_retry_at;
        try pc.b.nap(@intCast(@max(0, end - pc.b.now())));
    }

    fn setCursor(buf: *[128]u8, len: *usize, puuid: []const u8) void {
        if (puuid.len > buf.len) return;
        @memcpy(buf[0..puuid.len], puuid);
        len.* = puuid.len;
    }

    fn masteryCursor(pc: *PlatformCrawler) []const u8 {
        return pc.mastery_cursor[0..pc.mastery_cursor_len];
    }

    /// Compact only: the raw response is ~70 KB for ~1 KB of data we use. An empty
    /// list still gets a row, marking the player done
    fn fetchMastery(pc: *PlatformCrawler, arena: std.mem.Allocator, puuid: []const u8) !void {
        const gpa = pc.b.c.gpa;
        const got = try ep.masteries(&pc.b.client, pc.platform, puuid);
        defer if (got) |b| gpa.free(b);
        pc.mastery_got = got != null;
        const job = try Job.create(gpa, .none);
        errdefer job.destroy(gpa);
        const a = job.allocator();
        const t = pc.b.now();
        const entries = if (got) |body| try mastery.fromJson(arena, body) else &.{};
        job.kind = .{ .mastery = .{
            .puuid = try a.dupe(u8, puuid),
            .platform = pc.platform.id,
            .t = t,
            .champions = entries.len,
            .blob = if (got != null) try mastery.encode(a, entries, t) else null,
        } };
        try pc.b.submit(job);
    }
};

/// Frames whose total gold participants keeps (gold10, gold14, gold15)
const gold_minutes = [_]usize{ 10, 14, 15 };

pub const Compact = struct {
    blob: []u8,
    frames: usize,
    events: usize,
    participants: u8,
    gold: [gold_minutes.len][timeline.max_participants]?i32,
};

/// Timeline JSON -> gzipped compact blob, allocated with `gpa`
/// A match-v5 summary or timeline as Riot sends one: a JSON object naming its match.
/// Not a parse: a body that passes can still fail extraction and be kept raw
fn wholeDoc(body: []const u8) bool {
    const t = std.mem.trim(u8, body, " \t\r\n");
    if (t.len < 2 or t[0] != '{' or t[t.len - 1] != '}') return false;
    return std.mem.indexOf(u8, t, "\"matchId\":\"") != null;
}

pub fn compactTimeline(gpa: std.mem.Allocator, body: []const u8) !Compact {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    const t = try timeline.fromJson(arena.allocator(), body);
    const bytes = try timeline.encode(gpa, t);
    defer gpa.free(bytes);
    return .{
        .blob = try store.raw.compress(gpa, bytes),
        .frames = t.frames.len,
        .events = t.events.len,
        .participants = t.participants,
        .gold = goldAt(t),
    };
}

fn goldAt(t: timeline.Timeline) [gold_minutes.len][timeline.max_participants]?i32 {
    var gold: [gold_minutes.len][timeline.max_participants]?i32 = @splat(@splat(null));
    for (gold_minutes, &gold) |minute, *row| {
        if (minute >= t.frames.len) continue;
        for (row[0..t.participants], 1..) |*g, id| g.* = t.frames[minute].get(@intCast(id), .total_gold);
    }
    return gold;
}

fn storeGold(db: store.Db, match_id: []const u8, participants: u8, gold: [gold_minutes.len][timeline.max_participants]?i32) !void {
    var up = try db.prepare("UPDATE participants SET gold10 = ?, gold14 = ?, gold15 = ? " ++
        "WHERE match_id = ? AND slot = ?");
    defer up.deinit();
    for (0..participants) |slot| try up.exec(.{ gold[0][slot], gold[1][slot], gold[2][slot], match_id, slot });
}

/// gold10/14/15 for every stored timeline, after the columns were added
pub fn rebuildGold(gpa: std.mem.Allocator, db: store.Db) !usize {
    var q = try db.prepare("SELECT match_id, data FROM timeline.timelines");
    defer q.deinit();
    var stored: usize = 0;
    try db.begin();
    errdefer db.rollback();
    while (try q.step()) {
        var arena: std.heap.ArenaAllocator = .init(gpa);
        defer arena.deinit();
        const r = q.row(struct { match_id: []const u8, data: []const u8 });
        const bytes = try store.raw.decompress(arena.allocator(), r.data);
        const t = timeline.decode(arena.allocator(), bytes) catch |err| {
            log.warn("timeline {s} did not decode: {t}", .{ r.match_id, err });
            continue;
        };
        try storeGold(db, r.match_id, t.participants, goldAt(t));
        stored += 1;
        if (stored % 1000 == 0) {
            try db.commit();
            try db.begin();
        }
    }
    try db.commit();
    return stored;
}

test "queues: priority platforms first, matches oldest first, timelines newest" {
    const db = try store.schema.memory();
    defer db.close();
    try db.exec(
        \\INSERT INTO match_queue (match_id, discovered_at, region) VALUES
        \\    ('EUN1_1', 1, 'europe'), ('EUW1_3', 3, 'europe'), ('EUW1_2', 2, 'europe'),
        \\    ('NA1_1', 0, 'americas');
        \\INSERT INTO timeline_queue (match_id, region, queued_at) VALUES
        \\    ('EUN1_1', 'europe', 9), ('EUW1_2', 'europe', 1), ('EUW1_3', 'europe', 2);
    );
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const want = [_]struct { []const u8, []const []const u8 }{
        .{ RegionCrawler.next_matches, &.{ "EUW1_2", "EUW1_3", "EUN1_1" } },
        .{ RegionCrawler.next_timelines, &.{ "EUW1_3", "EUW1_2", "EUN1_1" } },
    };
    for (want) |c| {
        const got = try column(db, arena.allocator(), c[0], .{ "europe", "[\"EUW1\"]", 10 });
        try std.testing.expectEqual(c[1].len, got.len);
        for (c[1], got) |e, g| try std.testing.expectEqualStrings(e, g);
    }
}

test "participant mastery: the week's new matches in storage order, stale snapshots only" {
    const db = try store.schema.memory();
    defer db.close();
    const day_ms = std.time.ms_per_day;
    const now_s = 100 * std.time.s_per_day;
    const week_ago_ms = (now_s - PlatformCrawler.participant_refresh_s) * 1000;
    // rowid order: an old game, then this week's, one KR game between, one found late
    try db.run(
        \\INSERT INTO matches (match_id, source, platform, queue_id, patch, game_version,
        \\    game_start, duration_s, remake) VALUES
        \\    ('EUW1_old', 's', 'EUW1', 420, '16.20', 'v', ?1, 1800, 0),
        \\    ('EUW1_a', 's', 'EUW1', 420, '16.20', 'v', ?2, 1800, 0),
        \\    ('KR_a', 's', 'KR', 420, '16.20', 'v', ?2, 1800, 0),
        \\    ('EUW1_b', 's', 'EUW1', 420, '16.20', 'v', ?2, 1800, 0),
        \\    ('EUW1_late', 's', 'EUW1', 420, '16.20', 'v', ?3, 1800, 0)
    , .{ 80 * day_ms, 99 * day_ms, 95 * day_ms });
    try db.exec(
        \\INSERT INTO participants (match_id, slot, team_id, puuid, champion_id, position,
        \\    individual_position, win) VALUES
        \\    ('EUW1_old', 0, 100, 'o', 1, 'TOP', 'TOP', 1),
        \\    ('EUW1_a', 0, 100, 'fresh', 1, 'TOP', 'TOP', 1),
        \\    ('EUW1_a', 1, 100, 'stale', 1, 'TOP', 'TOP', 1),
        \\    ('EUW1_a', 2, 100, NULL, 1, 'TOP', 'TOP', 1),
        \\    ('KR_a', 0, 100, 'kr', 1, 'TOP', 'TOP', 1),
        \\    ('EUW1_b', 0, 100, 'stale', 1, 'TOP', 'TOP', 1),
        \\    ('EUW1_b', 1, 100, 'new', 1, 'TOP', 'TOP', 1),
        \\    ('EUW1_late', 0, 100, 'late', 1, 'TOP', 'TOP', 1);
    );
    try db.run(
        \\INSERT INTO mastery VALUES ('fresh', 'EUW1', ?1, 0, x''), ('stale', 'EUW1', ?2, 0, x'')
    , .{ now_s - 3600, now_s - 8 * std.time.s_per_day });
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const from = (try db.scalar(PlatformCrawler.match_cursor_start, .{week_ago_ms})).?;
    try std.testing.expectEqual(1, from);
    const to = (try db.scalar(PlatformCrawler.match_batch_end, .{ from, "EUW1", 2 })).?;
    try std.testing.expectEqual(4, to);
    const got = try column(db, arena.allocator(), "SELECT * FROM (" ++
        PlatformCrawler.participant_masteries ++ ") ORDER BY 1", .{
        from, to, "EUW1", week_ago_ms, now_s - PlatformCrawler.participant_refresh_s, "",
    });
    try std.testing.expectEqual(2, got.len);
    try std.testing.expectEqualStrings("new", got[0]);
    try std.testing.expectEqualStrings("stale", got[1]);
    // Resumed after a player tried: the rest of the batch, not the failures again
    const rest = try column(db, arena.allocator(), PlatformCrawler.participant_masteries, .{
        from, to, "EUW1", week_ago_ms, now_s - PlatformCrawler.participant_refresh_s, "new",
    });
    try std.testing.expectEqual(1, rest.len);
    try std.testing.expectEqualStrings("stale", rest[0]);
    try std.testing.expectEqual(5, (try db.scalar(PlatformCrawler.match_batch_end, .{ to, "EUW1", 2 })).?);
    try std.testing.expectEqual(0, (try db.scalar(PlatformCrawler.match_batch_end, .{ 5, "EUW1", 2 })).?);
}

test "scan pool: players below --min-tier are not scanned" {
    const db = try store.schema.memory();
    defer db.close();
    try db.exec(
        \\INSERT INTO players (puuid, tier, source, platform, region) VALUES
        \\    ('d', 'DIAMOND', 'ladder', 'EUW1', 'europe'), ('g', 'GOLD', 'ladder', 'EUW1', 'europe'),
        \\    ('n', NULL, 'participant', 'EUW1', 'europe'), ('p', 'PLATINUM', 'ladder', 'EUW1', 'europe');
    );
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const plat = try RegionCrawler.tierFloor(arena.allocator(), 5);
    try std.testing.expectEqualStrings("|CHALLENGER|GRANDMASTER|MASTER|DIAMOND|EMERALD|PLATINUM|", plat.?);
    try std.testing.expectEqual(null, try RegionCrawler.tierFloor(arena.allocator(), tiers.len - 1));
    const want = [_]struct { ?[]const u8, []const []const u8 }{
        .{ plat, &.{ "d", "p" } },
        .{ null, &.{ "d", "g", "n", "p" } },
    };
    for (want) |c| {
        const got = try column(db, arena.allocator(), RegionCrawler.scan_players, .{ "europe", null, 0, 10, c[0] });
        try std.testing.expectEqual(c[1].len, got.len);
        for (c[1], got) |e, g| try std.testing.expectEqualStrings(e, g);
    }
}

test "active first: players the ladder shows played since their last scan, most first" {
    const db = try store.schema.memory();
    defer db.close();
    try db.exec(
        \\INSERT INTO players (puuid, tier, wins, losses, games_checked, source, platform, region) VALUES
        \\    ('none', 'DIAMOND', 5, 5, 10, 'ladder', 'EUW1', 'europe'),
        \\    ('two', 'DIAMOND', 6, 6, 10, 'ladder', 'EUW1', 'europe'),
        \\    ('five', 'PLATINUM', 8, 7, 10, 'ladder', 'EUW1', 'europe'),
        \\    ('gold', 'GOLD', 20, 20, 10, 'ladder', 'EUW1', 'europe'),
        \\    ('unknown', 'DIAMOND', 9, 9, NULL, 'ladder', 'EUW1', 'europe'),
        \\    ('kr', 'DIAMOND', 20, 20, 10, 'ladder', 'KR', 'asia');
    );
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const plat = try RegionCrawler.tierFloor(a, 5);
    const got = try column(db, a, RegionCrawler.new_games, .{ "europe", null, plat, 10, false });
    try std.testing.expectEqual(2, got.len);
    try std.testing.expectEqualStrings("five", got[0]);
    try std.testing.expectEqualStrings("two", got[1]);
    // --patch-only: never scanned players wait for scan_players
    try db.exec("UPDATE players SET matches_checked_at = 1 WHERE puuid = 'two'");
    const scanned = try column(db, a, RegionCrawler.new_games, .{ "europe", null, plat, 10, true });
    try std.testing.expectEqual(1, scanned.len);
    try std.testing.expectEqualStrings("two", scanned[0]);
    var plan = try db.prepare("EXPLAIN QUERY PLAN " ++ RegionCrawler.new_games);
    defer plan.deinit();
    try plan.bind(.{ "europe", null, plat, 10, true });
    try std.testing.expect(try plan.step());
    try std.testing.expectEqualStrings("SEARCH players USING INDEX players_new_games (region=? AND <expr>>?)", plan.bytes(3));
    // No temp B-tree: rows come in ORDER BY order straight from the index
    try std.testing.expect(!try plan.step());
}

test "snowball: sampled players of newly stored matches who played since their last scan" {
    const db = try store.schema.memory();
    defer db.close();
    try db.exec(
        \\INSERT INTO matches (match_id, source, platform, queue_id, patch, game_version,
        \\    game_start, duration_s, remake) VALUES
        \\    ('EUW1_1', 'riot', 'EUW1', 420, '16.21', '16.21.1', 5000, 1500, 0),
        \\    ('EUW1_2', 'riot', 'EUW1', 420, '16.21', '16.21.1', 9000, 1500, 0),
        \\    ('KR_1', 'riot', 'KR', 420, '16.21', '16.21.1', 9000, 1500, 0);
        \\INSERT INTO participants (match_id, slot, team_id, puuid, champion_id, win) VALUES
        \\    ('EUW1_1', 0, 100, 'new', 1, 1), ('EUW1_1', 1, 100, 'scanned', 1, 1),
        \\    ('EUW1_2', 0, 100, 'gold', 1, 1), ('EUW1_2', 1, 100, 'stale', 1, 1),
        \\    ('EUW1_2', 2, 100, 'unsampled', 1, 1), ('KR_1', 0, 100, 'kr', 1, 1);
        \\INSERT INTO players (puuid, tier, matches_checked_at, source, platform, region) VALUES
        \\    ('new', 'DIAMOND', NULL, 'ladder', 'EUW1', 'europe'),
        \\    ('scanned', 'DIAMOND', 6, 'ladder', 'EUW1', 'europe'),
        \\    ('gold', 'GOLD', NULL, 'ladder', 'EUW1', 'europe'),
        \\    ('stale', 'PLATINUM', 2, 'ladder', 'EUW1', 'europe'),
        \\    ('kr', 'DIAMOND', NULL, 'ladder', 'KR', 'asia');
    );
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const plat = try RegionCrawler.tierFloor(a, 5);
    const europe = "[\"EUW1\",\"EUN1\"]";
    const got = try column(db, a, RegionCrawler.snowball_players, .{ 0, 10, europe, plat, 10 });
    try std.testing.expectEqual(2, got.len);
    try std.testing.expectEqualStrings("new", got[0]);
    try std.testing.expectEqualStrings("stale", got[1]);
    // Past the first match, and not past ?2
    try std.testing.expectEqual(1, (try column(db, a, RegionCrawler.snowball_players, .{ 1, 10, europe, plat, 10 })).len);
    try std.testing.expectEqual(1, (try column(db, a, RegionCrawler.snowball_players, .{ 0, 1, europe, plat, 10 })).len);
}

test "skipped timelines: long ranked matches without a timeline or queue row, newest first" {
    const db = try store.schema.memory();
    defer db.close();
    try db.exec(
        \\INSERT INTO matches (match_id, source, platform, queue_id, patch, game_version,
        \\    game_start, duration_s, remake) VALUES
        \\    ('EUW1_1', 'riot', 'EUW1', 420, '16.21', '16.21.1', 1000, 1500, 0),
        \\    ('EUW1_2', 'riot', 'EUW1', 420, '16.21', '16.21.1', 2000, 1500, 0),
        \\    ('EUW1_3', 'riot', 'EUW1', 420, '16.21', '16.21.1', 3000, 1500, 0),
        \\    ('EUW1_4', 'riot', 'EUW1', 420, '16.21', '16.21.1', 4000, 600, 0),
        \\    ('EUW1_5', 'riot', 'EUW1', 440, '16.21', '16.21.1', 5000, 1500, 0),
        \\    ('EUW1_6', 'riot', 'EUW1', 420, '16.21', '16.21.1', 6000, 1500, 0),
        \\    ('EUW1_7', 'riot', 'EUW1', 420, '16.21', '16.21.1', 7000, 1500, 1),
        \\    ('KR_1', 'riot', 'KR', 420, '16.21', '16.21.1', 6500, 1500, 0);
        \\INSERT INTO timeline.timelines VALUES ('EUW1_2', 1, 1, x'00');
        \\INSERT INTO timeline_queue (match_id, region, queued_at) VALUES ('EUW1_3', 'europe', 1);
    );
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const europe = "[\"EUW1\",\"EUN1\"]";
    const got = try column(db, a, RegionCrawler.skipped_timelines, .{ 10000, 0, europe, ep.ranked_solo, 900, 10 });
    try std.testing.expectEqual(2, got.len);
    try std.testing.expectEqualStrings("EUW1_6", got[0]);
    try std.testing.expectEqualStrings("EUW1_1", got[1]);
    try std.testing.expectEqual(1, (try column(db, a, RegionCrawler.skipped_timelines, .{ 6000, 0, europe, ep.ranked_solo, 900, 10 })).len);
    var plan = try db.prepare("EXPLAIN QUERY PLAN " ++ RegionCrawler.skipped_timelines);
    defer plan.deinit();
    try plan.bind(.{ 10000, 0, europe, ep.ranked_solo, 900, 10 });
    var uses_start = false;
    while (try plan.step()) {
        if (std.mem.indexOf(u8, plan.bytes(3), "matches_start") != null) uses_start = true;
        // Rows in game_start order straight from the index
        try std.testing.expect(std.mem.indexOf(u8, plan.bytes(3), "TEMP B-TREE") == null);
    }
    try std.testing.expect(uses_start);
}

test "patches: newest per platform, from its first game seen" {
    const db = try store.schema.memory();
    defer db.close();
    try db.exec(
        \\INSERT INTO matches (match_id, source, platform, queue_id, patch, game_version,
        \\    game_start, duration_s, remake) VALUES
        \\    ('EUW1_1', 'riot', 'EUW1', 420, '16.9', '16.9.1', 1000, 1, 0),
        \\    ('EUW1_2', 'riot', 'EUW1', 420, '16.10', '16.10.1', 9000, 1, 0),
        \\    ('EUW1_3', 'riot', 'EUW1', 420, '16.10', '16.10.1', 8000, 1, 0),
        \\    ('KR_1', 'riot', 'KR', 420, '16.9', '16.9.1', 2000, 1, 0),
        \\    ('NA1_1', 'riot', 'NA1', 420, '16.8', '16.8.1', 3000, 1, 0);
    );
    var ps: Patches = try .load(std.testing.allocator, db);
    try std.testing.expectEqual(@as(?i64, 8), ps.start("EUW1"));
    try std.testing.expectEqual(@as(?i64, 2), ps.start("KR"));
    // Only the two newest patches load
    try std.testing.expectEqual(null, ps.start("NA1"));
    try std.testing.expect(!ps.see("EUW1", "16.9", 50));
    try std.testing.expect(ps.see("EUW1", "16.10", 7));
    try std.testing.expectEqual(@as(?i64, 7), ps.start("EUW1"));
    try std.testing.expect(ps.see("KR", "16.10", 20));
    try std.testing.expectEqual(@as(?i64, 20), ps.start("KR"));
}

test "timelines: every priority match, a share of the rest" {
    var c: Crawler = .{
        .gpa = std.testing.allocator,
        .io = std.testing.io,
        .opts = .{ .data_dir = "", .key = "", .timeline_percent = 50 },
    };
    var buf: [32]u8 = undefined;
    var others: u32 = 0;
    for (0..1000) |i| {
        try std.testing.expect(c.wantTimeline(try std.mem.print(&buf, "EUW1_{d}", .{i})));
        if (c.wantTimeline(try std.mem.print(&buf, "EUN1_{d}", .{i}))) others += 1;
    }
    try std.testing.expect(others > 400 and others < 600);
    c.opts.timeline_percent = 0;
    try std.testing.expect(!c.wantTimeline("NA1_1"));
    try std.testing.expect(c.wantTimeline("EUW1_1"));
}

test "timelines: a share of priority matches too, the same games every time" {
    var c: Crawler = .{
        .gpa = std.testing.allocator,
        .io = std.testing.io,
        .opts = .{ .data_dir = "", .key = "", .timeline_priority_percent = 30 },
    };
    var buf: [32]u8 = undefined;
    var euw: u32 = 0;
    for (0..1000) |i| {
        const id = try std.mem.print(&buf, "EUW1_{d}", .{i});
        const want = c.wantTimeline(id);
        try std.testing.expectEqual(want, c.wantTimeline(id));
        if (want) euw += 1;
        try std.testing.expect(c.wantTimeline(try std.mem.print(&buf, "EUN1_{d}", .{i})));
    }
    try std.testing.expect(euw > 230 and euw < 370);
}

test "a 401/403 stops the crawler only when the key check player is refused too" {
    const gpa = std.testing.allocator;
    const saved = std.testing.log_level;
    defer std.testing.log_level = saved;
    std.testing.log_level = .err;
    var fake: @import("fake.zig").Fake = try .init(gpa, std.testing.io, 0);
    defer fake.deinit(gpa);
    var c: Crawler = .{ .gpa = gpa, .io = std.testing.io, .opts = .{ .data_dir = "", .key = "", .fake = &fake } };
    c.limiters = try .init(gpa, std.testing.io);
    defer c.limiters.deinit();
    const db = try store.schema.memory();
    defer db.close();
    var counted: std.atomic.Value(u64) = .init(0);
    var b: Bucket = .{ .c = &c, .name = "europe", .db = db, .client = .init(gpa, std.testing.io, "", c.limiters.get("europe").?), .priority = false, .requests = &counted };
    defer b.client.deinit();
    b.client.fake = &fake;

    fake.refuse = "EUW1_refused";
    const err = ep.match(&b.client, .europe, "EUW1_refused");
    try std.testing.expectError(error.KeyRejected, err);
    // No player to ask: every 401/403 stops, as before
    try std.testing.expect(b.fatal(error.KeyRejected));

    c.probe = KeyProbe.init(ep.platform("EUW1").?, "stored-puuid").?;
    try std.testing.expect(!b.fatal(error.KeyRejected));
    try std.testing.expect(c.key_ok_at != null);
    // Riot refuses everything: within a minute of the last good check the request is
    // only skipped, after it the crawler stops
    fake.refuse = "";
    try std.testing.expect(!b.fatal(error.KeyRejected));
    c.key_ok_at = c.nowS() - Crawler.key_recheck_s;
    try std.testing.expect(b.fatal(error.KeyRejected));
    try std.testing.expect(!b.fatal(error.RateLimited));
    try std.testing.expect(b.fatal(error.OutOfMemory));
}

test "whole documents: empty, cut short or not a match is a failed fetch" {
    try std.testing.expect(wholeDoc("{\"metadata\":{\"matchId\":\"OC1_1\"},\"info\":{}}\n"));
    try std.testing.expect(!wholeDoc(""));
    try std.testing.expect(!wholeDoc("  \n"));
    try std.testing.expect(!wholeDoc("{\"metadata\":{\"matchId\":\"OC1_1\"},\"info\":{"));
    try std.testing.expect(!wholeDoc("{\"status\":{\"status_code\":503}}"));
    try std.testing.expect(!wholeDoc("<html>busy</html>"));
    try std.testing.expect(wholeDoc(@embedFile("testdata/match.json")));
    const tl = try store.raw.decompress(std.testing.allocator, @embedFile("testdata/timeline.json.gz"));
    defer std.testing.allocator.free(tl);
    try std.testing.expect(wholeDoc(tl));
}

test "gold at 10, 14 and 15 minutes" {
    const gpa = std.testing.allocator;
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    const body = try store.raw.decompress(arena.allocator(), @embedFile("testdata/timeline.json.gz"));
    const ct = try compactTimeline(gpa, body);
    defer gpa.free(ct.blob);
    const db = try store.schema.memory();
    defer db.close();
    var doc = try match.parse(arena.allocator(), @embedFile("testdata/match.json"));
    doc.metadata.matchId = "EUW1_1";
    try match.storeRows(db, doc, "riot");
    try storeGold(db, "EUW1_1", ct.participants, ct.gold);
    // Frame 15, participant 1 of the fixture (riot-timeline-measured)
    try std.testing.expectEqual(@as(?i64, 6208), try db.scalar(
        "SELECT gold15 FROM participants WHERE match_id = 'EUW1_1' AND slot = 0",
        .{},
    ));
    try std.testing.expectEqual(@as(?i64, 10), try db.scalar(
        "SELECT count(*) FROM participants WHERE gold10 > 0 AND gold14 >= gold10",
        .{},
    ));
}

test "done queue rows are dropped" {
    const db = try store.schema.memory();
    defer db.close();
    try db.exec(
        \\INSERT INTO match_queue (match_id, status, discovered_at) VALUES
        \\    ('EUW1_1', 'done', 1), ('EUW1_2', 'pending', 1), ('EUW1_3', 'failed', 1);
        \\INSERT INTO timeline_queue (match_id, region, status, queued_at) VALUES
        \\    ('EUW1_1', 'europe', 'done', 1);
    );
    try dropDoneRows(db);
    try std.testing.expectEqual(@as(?i64, 2), try db.scalar("SELECT count(*) FROM match_queue", .{}));
    try std.testing.expectEqual(@as(?i64, 0), try db.scalar("SELECT count(*) FROM timeline_queue", .{}));
}
