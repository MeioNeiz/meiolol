//! Ranked solo crawler for every region. On a personal key each routing value is its
//! own rate limit bucket, so each gets a thread:
//! - platform (euw1, kr, ...): ladder seeding for every tier, then mastery with spare
//!   budget
//! - regional (europe, asia, ...): match ids per player of its platforms, match
//!   details, then their timelines
//! Each thread owns its HTTP client, limiter and a DB connection it only reads with;
//! one writer thread (writer.zig) makes every write. The main thread reports and
//! prunes raw timelines.

const std = @import("std");
const store = @import("store");
const Client = @import("client.zig").Client;
const ep = @import("endpoints.zig");
const match = @import("match.zig");
const timeline = @import("timeline.zig");
const mastery = @import("mastery.zig");
const writer = @import("writer.zig");
const Job = writer.Job;

const log = std.log.scoped(.crawl);

const tiers = [_][]const u8{
    "CHALLENGER", "GRANDMASTER", "MASTER", "DIAMOND", "EMERALD",
    "PLATINUM",   "GOLD",        "SILVER", "BRONZE",  "IRON",
};
const divisions = [_][]const u8{ "I", "II", "III", "IV" };
const pending_low = 300;
const detail_batch = 40;
/// When the match queue runs short, so a timeline backlog drains in quiet spells
const timeline_batch = 60;
const all_regions = std.enums.values(ep.Region);

pub const Options = struct {
    data_dir: []const u8,
    key: []const u8,
    since_days: i64 = 14,
    ladder_refresh_s: i64 = 7 * 24 * 3600,
    recheck_s: i64 = 12 * 3600,
    mastery: bool = true,
    hours: ?f64 = null,
    regions: []const ep.Region = all_regions,
    /// Share of matches that also get a timeline, chosen by match id hash
    timeline_percent: u8 = 100,
    /// Raw timeline JSON kept this long for re-extraction; 0 keeps none
    raw_timeline_days: u32 = 7,
    /// Raw match summaries kept this long (`meiolol rebuild` re-parses them); 0 = forever
    raw_match_days: u32 = 30,
    /// Platforms whose players a regional thread scans before any other's, so they
    /// get its whole budget while they have players due
    priority: []const []const u8 = &.{"EUW1"},
    /// Share of each bucket left to other processes on the key (the Your games service)
    reserve_pct: u8 = 0,
    fake: ?*const @import("fake.zig").Fake = null,
};

const RegionCounters = struct {
    matches: std.atomic.Value(u64) = .init(0),
    timelines: std.atomic.Value(u64) = .init(0),
    ids_calls: std.atomic.Value(u64) = .init(0),
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

    pub fn run(c: *Crawler) !void {
        // Opening once here migrates the schema before the workers connect
        const db = try store.open(c.gpa, c.opts.data_dir);
        defer db.close();
        try c.backfillTimelines(db);

        c.writer = .{ .c = c };
        defer c.writer.deinit();
        const writer_thread = try std.Thread.spawn(.{}, writer.Writer.run, .{&c.writer});
        var threads: std.ArrayList(std.Thread) = .empty;
        defer threads.deinit(c.gpa);
        defer c.stopAll(&threads, writer_thread);
        try c.spawnAll(&threads);
        log.info("{d} workers for {d} regions", .{ threads.items.len, c.opts.regions.len });

        const started = c.nowS();
        var last_report = started;
        // An hour in, not at once: a prune holds this thread (and the reports) while it
        // runs, and start-up is busy enough on a slow box
        var last_prune = started;
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
            if (now - last_prune >= 3600) {
                last_prune = now;
                c.pruneRaw(db) catch |err| log.warn("pruning raw documents: {t}", .{err});
            }
        }
        c.stopAll(&threads, writer_thread);
        c.report(c.nowS() - started);
        if (c.failure) |err| return err;
    }

    /// Workers first: the writer then stores what they queued before stopping
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
            threads.appendAssumeCapacity(try std.Thread.spawn(.{}, worker, .{ c, Task{ .regional = r } }));
            for (ep.platforms) |p| {
                if (p.region != r) continue;
                threads.appendAssumeCapacity(try std.Thread.spawn(.{}, worker, .{ c, Task{ .platform = p } }));
            }
        }
    }

    fn report(c: *Crawler, elapsed_s: i64) void {
        var buf: [512]u8 = undefined;
        var w: std.Io.Writer = .fixed(&buf);
        var matches: u64 = 0;
        for (c.opts.regions) |r| {
            const rc = &c.counters.region[@intFromEnum(r)];
            const m = rc.matches.load(.monotonic);
            matches += m;
            w.print(" | {t} {d}m {d}t {d}ids {d}req", .{
                r,                             m,
                rc.timelines.load(.monotonic), rc.ids_calls.load(.monotonic),
                rc.requests.load(.monotonic),
            }) catch break;
        }
        const per_day = if (elapsed_s > 0) matches * 86400 / @as(u64, @intCast(elapsed_s)) else 0;
        const ws = &c.writer.stats;
        log.info("{d} matches/day | ladder pages {d} | mastery {d} | platform req {d}{s}" ++
            " | writes {d} in {d} commits, {d} queued, {d} busy", .{
            per_day,
            c.counters.ladder_pages.load(.monotonic),
            c.counters.mastery.load(.monotonic),
            c.counters.platform_requests.load(.monotonic),
            w.buffered(),
            ws.jobs.load(.monotonic),
            ws.commits.load(.monotonic),
            c.writer.queued(),
            ws.busy.load(.monotonic),
        });
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

    fn worker(c: *Crawler, job: Task) void {
        var w = while (true) {
            break Worker.init(c, job) catch |err| {
                if (err != error.Busy or c.stop.load(.acquire)) return c.fail(err);
                c.io.sleep(.fromSeconds(5), .awake) catch return c.fail(err);
                continue;
            };
        };
        defer w.deinit();
        w.loop() catch |err| {
            if (err != error.Stopping) {
                log.err("{s} worker: {t}", .{ job.name(), err });
                c.fail(err);
            }
        };
    }

    pub fn wantTimeline(c: *Crawler, match_id: []const u8) bool {
        const pct = c.opts.timeline_percent;
        return pct >= 100 or std.hash.Wyhash.hash(0, match_id) % 100 < pct;
    }

    /// Queue timelines for matches crawled before timelines existed. Runs while the
    /// queue is empty, so in practice once
    fn backfillTimelines(c: *Crawler, db: store.Db) !void {
        if (c.opts.timeline_percent == 0) return;
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

    fn pruneRaw(c: *Crawler, db: store.Db) !void {
        try c.pruneChunks(db, "timelines", c.opts.raw_timeline_days,
            \\DELETE FROM raw.timeline_docs WHERE rowid IN
            \\    (SELECT rowid FROM raw.timeline_docs d WHERE fetched_at < ? AND NOT EXISTS
            \\        (SELECT 1 FROM timeline_queue q
            \\         WHERE q.match_id = d.match_id AND q.status = 'failed')
            \\     LIMIT 500)
        );
        try c.pruneChunks(db, "match summaries", c.opts.raw_match_days,
            \\DELETE FROM raw.raw_docs WHERE source = 'riot_match' AND key IN
            \\    (SELECT key FROM raw.raw_docs
            \\     WHERE source = 'riot_match' AND fetched_at < ? LIMIT 500)
        );
        // Riot asks for stored player data to be refreshed monthly: players no ladder
        // page or match has shown for 30 days go (erased accounts stop appearing), and
        // mastery is dropped to be fetched again
        try c.pruneChunks(db, "mastery of unseen players", 30,
            \\DELETE FROM mastery WHERE puuid IN
            \\    (SELECT puuid FROM players WHERE seen_at < ? LIMIT 500)
        );
        try c.pruneChunks(db, "unseen players", 30,
            \\DELETE FROM players WHERE puuid IN
            \\    (SELECT puuid FROM players WHERE seen_at < ? LIMIT 500)
        );
        try c.pruneChunks(db, "mastery snapshots", 30,
            \\DELETE FROM mastery WHERE puuid IN
            \\    (SELECT puuid FROM mastery WHERE fetched_at < ? LIMIT 500)
        );
        // Privacy policy: matches older than 24 months keep no PUUIDs
        const cutoff_ms = (c.nowS() - 730 * 86400) * 1000;
        try db.run(
            \\UPDATE participants SET puuid = NULL WHERE puuid IS NOT NULL AND match_id IN
            \\    (SELECT match_id FROM matches WHERE game_start < ?)
        , .{cutoff_ms});
    }

    /// In chunks, so the writer waits at most one chunk
    fn pruneChunks(c: *Crawler, db: store.Db, what: []const u8, days: u32, sql: []const u8) !void {
        if (days == 0) return;
        const cutoff = c.nowS() - @as(i64, days) * 86400;
        var total: i64 = 0;
        while (!c.stop.load(.acquire)) {
            try db.run(sql, .{cutoff});
            const n = try db.scalar("SELECT changes()", .{}) orelse 0;
            total += n;
            if (n == 0) break;
        }
        if (total > 0) log.info("pruned {d} raw {s}", .{ total, what });
    }
};

const Task = union(enum) {
    platform: ep.Platform,
    regional: ep.Region,

    fn name(j: Task) []const u8 {
        return switch (j) {
            .platform => |p| p.host,
            .regional => |r| @tagName(r),
        };
    }
};

/// Errors that stop the crawler; anything else is logged and the item skipped
fn fatal(err: anyerror) bool {
    return switch (err) {
        // Busy too (a read, rare in WAL): Worker.loop pauses and carries on
        error.KeyRejected, error.OutOfMemory, error.Stopping, error.Sqlite, error.Busy => true,
        else => false,
    };
}

const Worker = struct {
    c: *Crawler,
    job: Task,
    /// Reads only
    db: store.Db,
    client: Client,
    reported_requests: u64 = 0,
    /// Sequence number of this worker's newest job, for flush
    last_seq: u64 = 0,
    /// Last PUUID given mastery, so each batch resumes instead of rescanning done players
    mastery_cursor: [128]u8 = undefined,
    mastery_cursor_len: usize = 0,

    /// run() migrated already; workers only connect
    fn init(c: *Crawler, job: Task) !Worker {
        const db = try store.schema.connect(c.gpa, c.opts.data_dir);
        errdefer db.close();
        var client: Client = try .init(c.gpa, c.io, c.opts.key);
        errdefer client.deinit();
        try client.limiter.setReserve(c.opts.reserve_pct);
        client.fake = c.opts.fake;
        return .{ .c = c, .job = job, .db = db, .client = client };
    }

    fn deinit(w: *Worker) void {
        w.countRequests();
        w.client.deinit();
        w.db.close();
    }

    fn countRequests(w: *Worker) void {
        const n = w.client.requests.load(.monotonic);
        const counter = switch (w.job) {
            .platform => &w.c.counters.platform_requests,
            .regional => |r| &w.c.counters.region[@intFromEnum(r)].requests,
        };
        _ = counter.fetchAdd(n - w.reported_requests, .monotonic);
        w.reported_requests = n;
    }

    fn loop(w: *Worker) !void {
        while (true) {
            try w.check();
            w.countRequests();
            w.step() catch |err| switch (err) {
                error.Busy => {
                    log.warn("{s}: database busy, pausing", .{w.job.name()});
                    try w.nap(5);
                },
                else => return err,
            };
            try w.flush();
        }
    }

    /// Hand a job to the writer, which owns it from then on
    fn submit(w: *Worker, job: *Job) !void {
        w.last_seq = try w.c.writer.submit(job);
    }

    /// Until everything this worker queued is committed: before reading what it changes
    fn flush(w: *Worker) !void {
        try w.c.writer.wait(w.last_seq);
    }

    fn step(w: *Worker) !void {
        switch (w.job) {
            .platform => |p| {
                if (try w.seedLadder(p) > 0) return;
                if (w.c.opts.mastery and try w.fetchMasteries(p, 50) > 0) return;
                try w.nap(60);
            },
            .regional => |r| try w.matchStep(r),
        }
    }

    fn check(w: *Worker) !void {
        if (w.c.stop.load(.acquire)) return error.Stopping;
    }

    fn nap(w: *Worker, seconds: u32) !void {
        for (0..seconds) |_| {
            try w.check();
            try w.c.io.sleep(.fromSeconds(1), .awake);
        }
    }

    fn now(w: *Worker) i64 {
        return w.c.nowS();
    }

    fn seedLadder(w: *Worker, p: ep.Platform) !u32 {
        var fetched: u32 = 0;
        for (tiers) |tier| {
            const apex = std.mem.eql(u8, tier, "MASTER") or std.mem.eql(u8, tier, "GRANDMASTER") or
                std.mem.eql(u8, tier, "CHALLENGER");
            for (if (apex) divisions[0..1] else divisions[0..]) |division| {
                var page: u32 = 1;
                while (true) : (page += 1) {
                    try w.check();
                    var fresh = try w.db.prepare("SELECT entries, fetched_at FROM ladder_pages" ++
                        " WHERE platform = ? AND tier = ? AND division = ? AND page = ?");
                    defer fresh.deinit();
                    try fresh.bind(.{ p.id, tier, division, page });
                    if (try fresh.step() and fresh.int(1) > w.now() - w.c.opts.ladder_refresh_s) {
                        if (fresh.int(0) == 0) break;
                        continue;
                    }
                    // A bad page ends this division for now; the next pass retries it
                    const entries = w.fetchLadderPage(p, tier, division, page) catch |err| {
                        if (fatal(err)) return err;
                        log.warn("{s} ladder {s} {s} page {d}: {t}", .{ p.host, tier, division, page, err });
                        break;
                    };
                    fetched += 1;
                    w.countRequests();
                    if (entries == 0) break;
                }
            }
        }
        return fetched;
    }

    fn fetchLadderPage(w: *Worker, p: ep.Platform, tier: []const u8, division: []const u8, page: u32) !usize {
        const got = try ep.leagueEntries(&w.client, p, tier, division, page);
        defer if (got) |b| w.c.gpa.free(b);
        const job = try Job.create(w.c.gpa, .none);
        errdefer job.destroy(w.c.gpa);
        // Parsed strings may point into the body: the copy lives as long as the job
        const a = job.allocator();
        const entries = try ep.parse([]const ep.LeagueEntry, a, try a.dupe(u8, got orelse "[]"));
        job.kind = .{ .ladder = .{
            .platform = p,
            .tier = tier,
            .division = division,
            .page = page,
            .entries = entries,
            .t = w.now(),
        } };
        try w.submit(job);
        return entries.len;
    }

    fn fetchMasteries(w: *Worker, p: ep.Platform, n: u32) !u32 {
        var arena: std.heap.ArenaAllocator = .init(w.c.gpa);
        defer arena.deinit();
        const sql =
            \\SELECT p.puuid FROM players p
            \\WHERE p.platform = ? AND p.source = 'ladder' AND p.puuid > ? AND NOT EXISTS
            \\    (SELECT 1 FROM mastery m WHERE m.puuid = p.puuid)
            \\ORDER BY p.puuid LIMIT ?
        ;
        var puuids = try w.column(arena.allocator(), sql, .{ p.id, w.masteryCursor(), n });
        if (puuids.len == 0 and w.mastery_cursor_len > 0) {
            w.mastery_cursor_len = 0;
            puuids = try w.column(arena.allocator(), sql, .{ p.id, "", n });
        }
        for (puuids) |puuid| {
            try w.check();
            w.fetchMastery(p, arena.allocator(), puuid) catch |err| {
                if (fatal(err)) return err;
                log.warn("{s} mastery: {t}", .{ p.host, err });
            };
            if (puuid.len <= w.mastery_cursor.len) {
                @memcpy(w.mastery_cursor[0..puuid.len], puuid);
                w.mastery_cursor_len = puuid.len;
            }
        }
        return @intCast(puuids.len);
    }

    fn masteryCursor(w: *Worker) []const u8 {
        return w.mastery_cursor[0..w.mastery_cursor_len];
    }

    /// Compact only: the raw response is ~70 KB for ~1 KB of data we use. An empty
    /// list still gets a row, marking the player done
    fn fetchMastery(w: *Worker, p: ep.Platform, arena: std.mem.Allocator, puuid: []const u8) !void {
        const got = try ep.masteries(&w.client, p, puuid);
        defer if (got) |b| w.c.gpa.free(b);
        const job = try Job.create(w.c.gpa, .none);
        errdefer job.destroy(w.c.gpa);
        const a = job.allocator();
        const t = w.now();
        const entries = if (got) |body| try mastery.fromJson(arena, body) else &.{};
        job.kind = .{ .mastery = .{
            .puuid = try a.dupe(u8, puuid),
            .platform = p.id,
            .t = t,
            .champions = entries.len,
            .blob = if (got != null) try mastery.encode(a, entries, t) else null,
        } };
        try w.submit(job);
    }

    /// Priority platforms' matches first (EUW: other platforms share its regional rate
    /// limit), then first in, first out. Timelines keep pace with new matches, newest
    /// first; a backlog of older ones waits for a short match queue
    fn matchStep(w: *Worker, r: ep.Region) !void {
        var done: usize = 0;
        const pending = try w.db.scalar("SELECT count(*) FROM match_queue " ++
            "WHERE region = ? AND status = 'pending'", .{@tagName(r)}) orelse 0;
        if (pending < pending_low) {
            done += try w.scanPlayers(r, 10);
            try w.flush();
        }

        var arena: std.heap.ArenaAllocator = .init(w.c.gpa);
        defer arena.deinit();
        const priority = try std.json.Stringify.valueAlloc(arena.allocator(), w.c.opts.priority, .{});
        const batch = try w.column(arena.allocator(), next_matches, .{ @tagName(r), priority, detail_batch });
        for (batch) |id| {
            try w.check();
            try w.fetchMatch(r, id);
        }
        // The writer queues these matches' timelines, which come first
        try w.flush();
        const n_timelines = if (batch.len == detail_batch) batch.len else timeline_batch;
        const timelines = try w.column(arena.allocator(), next_timelines, .{ @tagName(r), priority, n_timelines });
        for (timelines) |id| {
            try w.check();
            try w.fetchTimeline(r, id);
        }
        done += batch.len + timelines.len;
        if (done == 0) try w.nap(15);
    }

    const next_matches =
        \\SELECT match_id FROM match_queue WHERE region = ?1 AND status = 'pending'
        \\ORDER BY substr(match_id, 1, instr(match_id, '_') - 1)
        \\    IN (SELECT value FROM json_each(?2)) DESC, discovered_at, match_id
        \\LIMIT ?3
    ;
    const next_timelines =
        \\SELECT match_id FROM timeline_queue WHERE region = ?1 AND status = 'pending'
        \\ORDER BY substr(match_id, 1, instr(match_id, '_') - 1)
        \\    IN (SELECT value FROM json_each(?2)) DESC, queued_at DESC, match_id DESC
        \\LIMIT ?3
    ;

    /// Priority platforms' players first, then the region's. Within those, never
    /// scanned (NULL sorts first), then the stalest. PUUIDs are random, so ordering by
    /// them samples players without favouring any rank or activity.
    fn scanPlayers(w: *Worker, r: ep.Region, n: u32) !u32 {
        var arena: std.heap.ArenaAllocator = .init(w.c.gpa);
        defer arena.deinit();
        var s = try w.db.prepare(
            \\SELECT puuid, matches_checked_at FROM players
            \\WHERE region = ?1 AND (?2 IS NULL OR platform = ?2)
            \\    AND (matches_checked_at IS NULL OR matches_checked_at < ?3)
            \\ORDER BY matches_checked_at, puuid
            \\LIMIT ?4
        );
        defer s.deinit();
        const Player = struct { puuid: []const u8, checked_at: ?i64 };
        var players: std.ArrayList(Player) = .empty;
        var filters: std.ArrayList(?[]const u8) = .empty;
        for (w.c.opts.priority) |id| {
            const p = ep.platform(id) orelse continue;
            if (p.region == r) try filters.append(arena.allocator(), id);
        }
        try filters.append(arena.allocator(), null);
        for (filters.items) |platform| {
            const want = n - players.items.len;
            if (want == 0) break;
            try s.bind(.{ @tagName(r), platform, w.now() - w.c.opts.recheck_s, want });
            while (try s.step()) {
                try players.append(arena.allocator(), .{
                    .puuid = try arena.allocator().dupe(u8, s.bytes(0)),
                    .checked_at = s.optInt(1),
                });
            }
        }
        for (players.items) |p| {
            try w.check();
            w.scanPlayer(r, p.puuid, p.checked_at) catch |err| {
                if (fatal(err)) return err;
                log.warn("{t} match ids: {t}", .{ r, err });
            };
            // Even after an error, so a bad player waits for the recheck interval
            const job = try Job.create(w.c.gpa, .none);
            errdefer job.destroy(w.c.gpa);
            job.kind = .{ .checked = .{ .puuid = try job.allocator().dupe(u8, p.puuid), .t = w.now() } };
            try w.submit(job);
        }
        return @intCast(players.items.len);
    }

    fn scanPlayer(w: *Worker, r: ep.Region, puuid: []const u8, checked_at: ?i64) !void {
        const end = w.now();
        const start_time = @max(checked_at orelse 0, end - w.c.opts.since_days * 86400);
        var start: u32 = 0;
        while (true) : (start += 100) {
            const got = try ep.matchIds(&w.client, r, puuid, start_time, end, start);
            defer if (got) |b| w.c.gpa.free(b);
            const body = got orelse "[]";
            _ = w.c.counters.region[@intFromEnum(r)].ids_calls.fetchAdd(1, .monotonic);
            const job = try Job.create(w.c.gpa, .none);
            errdefer job.destroy(w.c.gpa);
            const ids = try ep.parse([]const []const u8, job.allocator(), try job.allocator().dupe(u8, body));
            job.kind = .{ .match_ids = .{ .ids = ids, .discovered_at = end, .region = r } };
            try w.submit(job);
            if (ids.len < 100) break;
        }
    }

    fn fetchMatch(w: *Worker, r: ep.Region, id: []const u8) !void {
        const gpa = w.c.gpa;
        const got = ep.match(&w.client, r, id) catch |err| {
            if (fatal(err)) return err;
            log.warn("match {s}: {t}", .{ id, err });
            return w.queueStatus(.match, id, .attempt);
        };
        const fetched = got orelse return w.queueStatus(.match, id, .missing);
        defer gpa.free(fetched);

        const job = try Job.create(gpa, .none);
        errdefer job.destroy(gpa);
        const a = job.allocator();
        const body = try a.dupe(u8, fetched);
        const doc = match.parse(a, body) catch |err| {
            if (err == error.OutOfMemory) return err;
            log.warn("match {s} did not parse: {t}", .{ id, err });
            job.kind = .{ .queue = .{ .which = .match, .id = try a.dupe(u8, id), .status = .failed } };
            return w.submit(job);
        };
        job.kind = .{ .match = .{
            .region = r,
            .id = try a.dupe(u8, id),
            .doc = doc,
            .raw = try store.raw.compress(a, body),
            .t = w.now(),
        } };
        try w.submit(job);
    }

    /// The raw JSON is kept when extraction fails (and not pruned), so a fixed parser
    /// can redo it
    fn fetchTimeline(w: *Worker, r: ep.Region, id: []const u8) !void {
        const gpa = w.c.gpa;
        const got = ep.timeline(&w.client, r, id) catch |err| {
            if (fatal(err)) return err;
            log.warn("timeline {s}: {t}", .{ id, err });
            return w.queueStatus(.timeline, id, .attempt);
        };
        const body = got orelse return w.queueStatus(.timeline, id, .missing);
        defer gpa.free(body);

        const job = try Job.create(gpa, .none);
        errdefer job.destroy(gpa);
        const a = job.allocator();
        const compact = compactTimeline(a, body) catch |err| blk: {
            if (err == error.OutOfMemory) return err;
            log.warn("timeline {s} did not parse: {t}", .{ id, err });
            break :blk null;
        };
        const keep_raw = w.c.opts.raw_timeline_days > 0 or compact == null;
        job.kind = .{ .timeline = .{
            .region = r,
            .id = try a.dupe(u8, id),
            .raw = if (keep_raw) try store.raw.compress(a, body) else null,
            .compact = compact,
            .t = w.now(),
        } };
        try w.submit(job);
    }

    fn queueStatus(w: *Worker, which: writer.Kind.Queue, id: []const u8, status: writer.Kind.Status) !void {
        const job = try Job.create(w.c.gpa, .none);
        errdefer job.destroy(w.c.gpa);
        job.kind = .{ .queue = .{ .which = which, .id = try job.allocator().dupe(u8, id), .status = status } };
        try w.submit(job);
    }

    /// First column of every row, copied into `arena`
    fn column(w: *Worker, arena: std.mem.Allocator, sql: []const u8, args: anytype) ![]const []const u8 {
        var s = try w.db.prepare(sql);
        defer s.deinit();
        try s.bind(args);
        var out: std.ArrayList([]const u8) = .empty;
        while (try s.step()) try out.append(arena, try arena.dupe(u8, s.bytes(0)));
        return out.items;
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
    try q.bind(.{});
    var stored: usize = 0;
    try db.begin();
    errdefer db.rollback();
    while (try q.step()) {
        var arena: std.heap.ArenaAllocator = .init(gpa);
        defer arena.deinit();
        const bytes = try store.raw.decompress(arena.allocator(), q.bytes(1));
        const t = timeline.decode(arena.allocator(), bytes) catch |err| {
            log.warn("timeline {s} did not decode: {t}", .{ q.bytes(0), err });
            continue;
        };
        try storeGold(db, q.bytes(0), t.participants, goldAt(t));
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
    var w: Worker = undefined;
    w.db = db;
    const want = [_]struct { []const u8, []const []const u8 }{
        .{ Worker.next_matches, &.{ "EUW1_2", "EUW1_3", "EUN1_1" } },
        .{ Worker.next_timelines, &.{ "EUW1_3", "EUW1_2", "EUN1_1" } },
    };
    for (want) |c| {
        const got = try w.column(arena.allocator(), c[0], .{ "europe", "[\"EUW1\"]", 10 });
        try std.testing.expectEqual(c[1].len, got.len);
        for (c[1], got) |e, g| try std.testing.expectEqualStrings(e, g);
    }
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
