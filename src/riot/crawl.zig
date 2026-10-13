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
    hours: ?f64 = null,
    regions: []const ep.Region = all_regions,
    /// Share of non-priority platforms' matches that also get a timeline, chosen by
    /// match id hash; every priority platform match gets one
    timeline_percent: u8 = 100,
    /// Raw timeline JSON kept this long for re-extraction; 0 keeps none
    raw_timeline_days: u32 = 7,
    /// Raw match summaries kept this long (`meiolol rebuild` re-parses them); 0 = forever
    raw_match_days: u32 = 30,
    /// Rolling window: matches, their rows and timelines go this long after game
    /// start; 0 = forever
    keep_days: u32 = 0,
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

const RegionCounters = struct {
    matches: std.atomic.Value(u64) = .init(0),
    timelines: std.atomic.Value(u64) = .init(0),
    ids_calls: std.atomic.Value(u64) = .init(0),
    /// Match ids new to the queue
    ids_found: std.atomic.Value(u64) = .init(0),
    requests: std.atomic.Value(u64) = .init(0),
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

    pub fn run(c: *Crawler) !void {
        c.limiters = try .init(c.gpa, c.io);
        defer c.limiters.deinit();
        for (&c.limiters.all) |*l| l.paced = true;
        // First, so a lookup waits only for the restart itself
        var proxy: Proxy = .{ .gpa = c.gpa, .io = c.io, .key = c.opts.key, .limiters = &c.limiters, .fake = c.opts.fake };
        var proxy_server = if (c.opts.proxy) |address| try proxy.listen(address) else null;
        defer if (proxy_server) |*s| s.deinit(c.io);
        var serving = if (proxy_server) |*s| try c.io.concurrent(Proxy.serve, .{ &proxy, s }) else null;
        defer if (serving) |*f| f.cancel(c.io);

        // Opening once here migrates the schema before the threads connect
        const db = try store.open(c.gpa, c.opts.data_dir);
        defer db.close();
        try c.backfillTimelines(db);
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
        while (!c.stop.load(.acquire)) {
            c.io.sleep(.fromSeconds(1), .awake) catch break;
            const now = c.nowS();
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
        if (c.failure) |err| return err;
    }

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

    /// Every priority platform match; of the rest `--timelines` percent, by match id hash
    pub fn wantTimeline(c: *const Crawler, match_id: []const u8) bool {
        if (ep.platformOf(match_id)) |p| {
            if (c.isPriority(p)) return true;
        }
        const pct = c.opts.timeline_percent;
        return pct >= 100 or std.hash.Wyhash.hash(0, match_id) % 100 < pct;
    }

    /// Queue timelines for matches crawled before timelines existed. Runs while the
    /// queue is empty, so in practice once
    fn backfillTimelines(c: *Crawler, db: store.Db) !void {
        if (c.opts.timeline_percent == 0 and c.opts.priority.len == 0) return;
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

/// Errors that stop the crawler; anything else is logged and the item skipped
fn fatal(err: anyerror) bool {
    return switch (err) {
        // Busy too (a read, rare in WAL): the thread pauses and carries on
        error.KeyRejected, error.OutOfMemory, error.Stopping, error.Sqlite, error.Busy => true,
        else => false,
    };
}

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

    /// "16.20" -> 16020; 0 when not a patch
    fn code(patch: []const u8) u32 {
        const dot = std.mem.indexOfScalar(u8, patch, '.') orelse return 0;
        const major = std.fmt.parseInt(u32, patch[0..dot], 10) catch return 0;
        const minor = std.fmt.parseInt(u32, patch[dot + 1 ..], 10) catch return 0;
        return major * 1000 + minor;
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

    const Of = ep.Region;

    fn init(c: *Crawler, r: ep.Region) !RegionCrawler {
        const requests = &c.counters.region[@backingInt(r)].requests;
        return .{
            .b = try .init(c, @tagName(r), c.isPriorityRegion(r), requests),
            .region = r,
            .patches = c.patches,
        };
    }

    fn counters(rc: *RegionCrawler) *RegionCounters {
        return &rc.b.c.counters.region[@backingInt(rc.region)];
    }

    /// One round: refill match ids when the queue runs short, then a batch of matches
    /// and as many timelines, newest first, so new games get theirs at once. A short
    /// match batch makes room for more timelines, so a backlog drains in quiet spells
    fn step(rc: *RegionCrawler) !void {
        const pending = try rc.b.db.scalar("SELECT count(*) FROM match_queue " ++
            "WHERE region = ? AND status = 'pending'", .{@tagName(rc.region)}) orelse 0;
        const scanned = if (pending < pending_low) try rc.scanPlayers(scan_batch) else 0;
        const matches = try rc.drain(.match, detail_batch);
        const timelines = try rc.drain(.timeline, if (matches == detail_batch) detail_batch else timeline_batch);
        if (scanned + matches + timelines == 0) try rc.b.nap(idle_s);
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
    /// first. Uses players_new_games
    const new_games =
        \\SELECT puuid, matches_checked_at, platform FROM players
        \\WHERE region = ?1 AND games_checked IS NOT NULL AND wins + losses - games_checked > 0
        \\    AND (?2 IS NULL OR platform = ?2)
        \\    AND (?3 IS NULL OR instr(?3, '|' || tier || '|') > 0)
        \\ORDER BY wins + losses - games_checked DESC
        \\LIMIT ?4
    ;

    /// "|CHALLENGER|...|PLATINUM|" for scan_players, null when every tier is in
    fn tierFloor(a: std.mem.Allocator, min_tier: usize) !?[]const u8 {
        if (min_tier + 1 >= tiers.len) return null;
        return try a.print("|{s}|", .{try std.mem.join(a, "|", tiers[0 .. min_tier + 1])});
    }

    /// Priority platforms' players first, then the region's. Within those, never
    /// scanned (NULL sorts first), then the stalest. PUUIDs are random, so ordering by
    /// them samples players without favouring any rank or activity. Waits for the
    /// writer, so the match queue has their ids
    fn scanPlayers(rc: *RegionCrawler, n: u32) !u32 {
        const c = rc.b.c;
        var arena: std.heap.ArenaAllocator = .init(c.gpa);
        defer arena.deinit();
        var s = try rc.b.db.prepare(scan_players);
        defer s.deinit();
        var active = try rc.b.db.prepare(new_games);
        defer active.deinit();
        const floor = try tierFloor(arena.allocator(), c.opts.min_tier);
        var players: std.ArrayList(Player) = .empty;
        var filters: std.ArrayList(?[]const u8) = .empty;
        for (c.opts.priority) |id| {
            const p = ep.platform(id) orelse continue;
            if (p.region == rc.region) try filters.append(arena.allocator(), id);
        }
        try filters.append(arena.allocator(), null);
        for (filters.items) |platform| {
            if (c.opts.active_first) {
                try active.bind(.{ @tagName(rc.region), platform, floor, n - players.items.len });
                try takePlayers(arena.allocator(), &active, &players);
            }
            if (players.items.len == n) break;
            try s.bind(.{ @tagName(rc.region), platform, rc.b.now() - c.opts.recheck_s, n - players.items.len, floor });
            try takePlayers(arena.allocator(), &s, &players);
        }
        for (players.items) |p| {
            try rc.b.check();
            rc.scanPlayer(p.puuid, p.checked_at, p.platform) catch |err| {
                if (fatal(err)) return err;
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
        return @intCast(players.items.len);
    }

    const Player = struct { puuid: []const u8, checked_at: ?i64, platform: []const u8 };

    /// Rows of new_games or scan_players, skipping players already taken
    fn takePlayers(a: std.mem.Allocator, s: *store.Stmt, players: *std.ArrayList(Player)) !void {
        next: while (try s.step()) {
            const r = s.row(Player);
            for (players.items) |p| if (std.mem.eql(u8, p.puuid, r.puuid)) continue :next;
            try players.append(a, .{
                .puuid = try a.dupe(u8, r.puuid),
                .checked_at = r.checked_at,
                .platform = try a.dupe(u8, r.platform),
            });
        }
    }

    fn scanPlayer(rc: *RegionCrawler, puuid: []const u8, checked_at: ?i64, platform: []const u8) !void {
        const c = rc.b.c;
        const end = rc.b.now();
        var start_time = @max(checked_at orelse 0, end - c.opts.since_days * 86400);
        if (c.opts.patch_only) start_time = @max(start_time, rc.patches.start(platform) orelse 0);
        var start: u32 = 0;
        while (true) : (start += 100) {
            const got = try ep.matchIds(&rc.b.client, rc.region, puuid, ep.ranked_solo, start_time, end, start);
            defer if (got) |b| c.gpa.free(b);
            const body = got orelse "[]";
            _ = rc.counters().ids_calls.fetchAdd(1, .monotonic);
            const job = try Job.create(c.gpa, .none);
            errdefer job.destroy(c.gpa);
            const ids = try ep.parse([]const []const u8, job.allocator(), try job.allocator().dupe(u8, body));
            job.kind = .{ .match_ids = .{ .ids = ids, .discovered_at = end, .region = rc.region } };
            try rc.b.submit(job);
            if (ids.len < 100) break;
        }
    }

    fn fetchMatch(rc: *RegionCrawler, id: []const u8) !void {
        const gpa = rc.b.c.gpa;
        const got = ep.match(&rc.b.client, rc.region, id) catch |err| {
            if (fatal(err)) return err;
            log.warn("match {s}: {t}", .{ id, err });
            // Left pending, so a 429 storm can't use up its tries
            if (err == error.RateLimited) return;
            return rc.b.queueStatus(.match, id, .attempt);
        };
        const fetched = got orelse return rc.b.queueStatus(.match, id, .missing);
        defer gpa.free(fetched);

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
            if (fatal(err)) return err;
            log.warn("timeline {s}: {t}", .{ id, err });
            // Left pending, so a 429 storm can't use up its tries
            if (err == error.RateLimited) return;
            return rc.b.queueStatus(.timeline, id, .attempt);
        };
        const body = got orelse return rc.b.queueStatus(.timeline, id, .missing);
        defer gpa.free(body);

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
    /// matches.rowid up to which participants have been given mastery; null until the
    /// first pass, which starts at the past week's matches
    match_cursor: ?i64 = null,
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
        if (pc.b.c.opts.mastery and try pc.fetchParticipantMasteries(20)) return;
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
                        if (fatal(err)) return err;
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
            while (pc.b.now() < pc.last_ladder + @divTrunc(3600, @as(i64, per_hour))) {
                // A reseed takes hours of gaps: participant mastery uses them, not a nap
                if (pc.b.c.opts.mastery and try pc.fetchParticipantMasteries(5)) continue;
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

    fn fetchMasteries(pc: *PlatformCrawler, n: u32) !u32 {
        var arena: std.heap.ArenaAllocator = .init(pc.b.c.gpa);
        defer arena.deinit();
        const sql =
            \\SELECT p.puuid FROM players p
            \\WHERE p.platform = ? AND p.source = 'ladder' AND p.puuid > ? AND NOT EXISTS
            \\    (SELECT 1 FROM mastery m WHERE m.puuid = p.puuid)
            \\ORDER BY p.puuid LIMIT ?
        ;
        const id = pc.platform.id;
        var puuids = try column(pc.b.db, arena.allocator(), sql, .{ id, pc.masteryCursor(), n });
        if (puuids.len == 0 and pc.mastery_cursor_len > 0) {
            pc.mastery_cursor_len = 0;
            puuids = try column(pc.b.db, arena.allocator(), sql, .{ id, "", n });
        }
        for (puuids) |puuid| {
            try pc.b.check();
            pc.fetchMastery(arena.allocator(), puuid) catch |err| {
                if (fatal(err)) return err;
                log.warn("{s} mastery: {t}", .{ pc.platform.host, err });
            };
            if (puuid.len <= pc.mastery_cursor.len) {
                @memcpy(pc.mastery_cursor[0..puuid.len], puuid);
                pc.mastery_cursor_len = puuid.len;
            }
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
    /// Players of the batch's games from the past week without a snapshot this recent
    pub const participant_masteries =
        \\SELECT DISTINCT p.puuid FROM matches m JOIN participants p USING (match_id)
        \\WHERE m.rowid > ?1 AND m.rowid <= ?2 AND m.platform = ?3 AND m.game_start > ?4
        \\    AND p.puuid IS NOT NULL AND NOT EXISTS
        \\    (SELECT 1 FROM mastery x WHERE x.puuid = p.puuid AND x.fetched_at > ?5)
    ;

    /// Mastery for every player of up to n newly stored matches; false when none are new
    fn fetchParticipantMasteries(pc: *PlatformCrawler, n: u32) !bool {
        var arena: std.heap.ArenaAllocator = .init(pc.b.c.gpa);
        defer arena.deinit();
        const db = pc.b.db;
        const now = pc.b.now();
        const week_ago_ms = (now - participant_refresh_s) * 1000;
        const from = pc.match_cursor orelse try db.scalar(match_cursor_start, .{week_ago_ms}) orelse 0;
        pc.match_cursor = from;
        // max() of no rows is NULL, read as 0
        const to = try db.scalar(match_batch_end, .{ from, pc.platform.id, n }) orelse 0;
        if (to <= from) return false;
        const puuids = try column(db, arena.allocator(), participant_masteries, .{
            from, to, pc.platform.id, week_ago_ms, now - participant_refresh_s,
        });
        for (puuids) |puuid| {
            try pc.b.check();
            pc.fetchMastery(arena.allocator(), puuid) catch |err| {
                if (fatal(err)) return err;
                log.warn("{s} mastery: {t}", .{ pc.platform.host, err });
            };
        }
        pc.match_cursor = to;
        return true;
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
        from, to, "EUW1", week_ago_ms, now_s - PlatformCrawler.participant_refresh_s,
    });
    try std.testing.expectEqual(2, got.len);
    try std.testing.expectEqualStrings("new", got[0]);
    try std.testing.expectEqualStrings("stale", got[1]);
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
    const got = try column(db, a, RegionCrawler.new_games, .{ "europe", null, plat, 10 });
    try std.testing.expectEqual(2, got.len);
    try std.testing.expectEqualStrings("five", got[0]);
    try std.testing.expectEqualStrings("two", got[1]);
    var plan = try db.prepare("EXPLAIN QUERY PLAN " ++ RegionCrawler.new_games);
    defer plan.deinit();
    try plan.bind(.{ "europe", null, plat, 10 });
    try std.testing.expect(try plan.step());
    try std.testing.expectEqualStrings("SEARCH players USING INDEX players_new_games (region=? AND <expr>>?)", plan.bytes(3));
    // No temp B-tree: rows come in ORDER BY order straight from the index
    try std.testing.expect(!try plan.step());
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
