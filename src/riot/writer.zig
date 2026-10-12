//! The crawler's only database writer. Fetch workers parse and compress, then hand
//! owned jobs to this thread, which applies whatever has queued up in one transaction.
//! On a slow host 19 threads each taking the write lock spent most of their time
//! waiting for it (a holder descheduled mid-transaction stalls everyone); one writer
//! never waits on itself, and a commit per batch instead of per item writes shared
//! pages (indexes, queues) once.
//!
//! Workers read on their own connections and call `wait` before reading state their
//! jobs change (queues), so nothing is fetched twice.

const std = @import("std");
const store = @import("store");
const ep = @import("endpoints.zig");
const match = @import("match.zig");
const crawl = @import("crawl.zig");

const log = std.log.scoped(.crawl);

/// Jobs waiting before submit blocks: bounds memory (a match job holds its parsed
/// document, ~0.3 MB). Non-priority jobs block at half, so when the writer falls behind
/// (disk, CPU) the priority region's jobs still get in and the rest slow down
const max_pending = 128;
/// Busy here means another process (backup, rebuild) holds the lock: retry the batch
const busy_pause_s = 5;
/// A short batch waits up to this long for more jobs (fewer, bigger commits: each
/// commit rewrites the index pages it touched), unless a worker is waiting in wait()
const linger_ms = 2000;
const linger_jobs = 32;

pub const Job = struct {
    arena: std.heap.ArenaAllocator,
    seq: u64 = 0,
    kind: Kind,
    /// Set by apply, counted once the batch commits
    stored: bool = false,

    pub fn create(gpa: std.mem.Allocator, kind: Kind) !*Job {
        const job = try gpa.create(Job);
        job.* = .{ .arena = .init(gpa), .kind = kind };
        return job;
    }

    /// Allocator for the job's data: freed with the job after its commit
    pub fn allocator(job: *Job) std.mem.Allocator {
        return job.arena.allocator();
    }

    pub fn destroy(job: *Job, gpa: std.mem.Allocator) void {
        job.arena.deinit();
        gpa.destroy(job);
    }
};

pub const Kind = union(enum) {
    ladder: struct { platform: ep.Platform, tier: []const u8, division: []const u8, page: u32, entries: []const ep.LeagueEntry, t: i64 },
    /// blob null: Riot does not know the PUUID, so the player goes
    mastery: struct { puuid: []const u8, platform: []const u8, t: i64, champions: usize, blob: ?[]const u8 },
    /// found: ids new to the queue, set by apply
    match_ids: struct { ids: []const []const u8, discovered_at: i64, region: ep.Region, found: u32 = 0 },
    checked: struct { puuid: []const u8, t: i64 },
    /// id: the queue's, in case Riot's document names another. timeline false: an older
    /// patch's match under --patch-only, stored without one
    match: struct { region: ep.Region, id: []const u8, doc: match.Doc, raw: []const u8, t: i64, timeline: bool = true },
    timeline: struct { region: ep.Region, id: []const u8, raw: ?[]const u8, compact: ?crawl.Compact, t: i64 },
    queue: struct { which: Queue, id: []const u8, status: Status },
    /// Barrier only: lets a worker wait for what it queued so far
    none,

    pub const Queue = enum { match, timeline };
    pub const Status = enum { attempt, missing, failed };
};

pub const Stats = struct {
    jobs: std.atomic.Value(u64) = .init(0),
    commits: std.atomic.Value(u64) = .init(0),
    busy: std.atomic.Value(u64) = .init(0),
    /// The writer connection's page writes and cache misses (page_size bytes each); a
    /// checkpoint writes WAL pages to the database file again, not counted here
    pages_written: std.atomic.Value(u64) = .init(0),
    pages_read: std.atomic.Value(u64) = .init(0),
};

pub const Writer = struct {
    c: *crawl.Crawler,
    mutex: std.Io.Mutex = .init,
    /// Broadcast on every change below: jobs queued, committed, closing, dead
    cond: std.Io.Condition = .init,
    pending: std.ArrayList(*Job) = .empty,
    next_seq: u64 = 0,
    committed_seq: u64 = 0,
    closing: bool = false,
    dead: bool = false,
    /// Workers in wait(): the batch commits at once rather than linger
    waiters: u32 = 0,
    stats: Stats = .{},
    prune: Prune = .{},

    pub fn deinit(wr: *Writer) void {
        for (wr.pending.items) |job| job.destroy(wr.c.gpa);
        wr.pending.deinit(wr.c.gpa);
    }

    /// Queue a job (the writer owns it once this returns); its sequence number for
    /// `wait`. Blocks while the queue is full for this job (`room`), except when
    /// stopping: the writer drains it then
    pub fn submit(wr: *Writer, job: *Job, priority: bool) !u64 {
        const io = wr.c.io;
        wr.mutex.lockUncancelable(io);
        defer wr.mutex.unlock(io);
        while (!room(wr.pending.items.len, priority) and !wr.dead and !wr.stopping()) {
            wr.cond.waitUncancelable(io, &wr.mutex);
        }
        if (wr.dead) return error.Stopping;
        try wr.pending.append(wr.c.gpa, job);
        wr.next_seq += 1;
        job.seq = wr.next_seq;
        wr.cond.broadcast(io);
        return job.seq;
    }

    /// Until job `seq` and every one before it are committed
    pub fn wait(wr: *Writer, seq: u64) !void {
        const io = wr.c.io;
        wr.mutex.lockUncancelable(io);
        defer wr.mutex.unlock(io);
        wr.waiters += 1;
        defer wr.waiters -= 1;
        while (wr.committed_seq < seq) {
            if (wr.dead or wr.stopping()) return error.Stopping;
            wr.cond.waitUncancelable(io, &wr.mutex);
        }
    }

    /// Wake waiters to see c.stop
    pub fn wake(wr: *Writer) void {
        wr.mutex.lockUncancelable(wr.c.io);
        defer wr.mutex.unlock(wr.c.io);
        wr.cond.broadcast(wr.c.io);
    }

    /// After the workers stopped: write what they queued, then end run()
    pub fn close(wr: *Writer) void {
        wr.mutex.lockUncancelable(wr.c.io);
        defer wr.mutex.unlock(wr.c.io);
        wr.closing = true;
        wr.cond.broadcast(wr.c.io);
    }

    fn room(pending: usize, priority: bool) bool {
        return pending < @as(usize, if (priority) max_pending else max_pending / 2);
    }

    pub fn queued(wr: *Writer) usize {
        wr.mutex.lockUncancelable(wr.c.io);
        defer wr.mutex.unlock(wr.c.io);
        return wr.pending.items.len;
    }

    fn stopping(wr: *Writer) bool {
        return wr.c.stop.load(.acquire);
    }

    /// Thread body
    pub fn run(wr: *Writer) void {
        wr.loop() catch |err| {
            log.err("writer: {t}", .{err});
            wr.mutex.lockUncancelable(wr.c.io);
            wr.dead = true;
            wr.cond.broadcast(wr.c.io);
            wr.mutex.unlock(wr.c.io);
            wr.c.fail(err);
        };
    }

    fn loop(wr: *Writer) !void {
        const gpa = wr.c.gpa;
        const db = try store.schema.connect(gpa, wr.c.opts.data_dir);
        defer db.close();
        try tune(db, wr.c.opts.cache_mb);
        var s: Stmts = try .init(db);
        defer s.deinit();
        var batch: std.ArrayList(*Job) = .empty;
        defer batch.deinit(gpa);
        while (true) {
            {
                wr.mutex.lockUncancelable(wr.c.io);
                defer wr.mutex.unlock(wr.c.io);
                while (wr.pending.items.len == 0 and !wr.closing) wr.cond.waitUncancelable(wr.c.io, &wr.mutex);
                if (wr.pending.items.len == 0) return;
                wr.linger();
                std.mem.swap(std.ArrayList(*Job), &batch, &wr.pending);
                // Room again for blocked submitters
                wr.cond.broadcast(wr.c.io);
            }
            defer {
                for (batch.items) |job| job.destroy(gpa);
                batch.clearRetainingCapacity();
            }
            var tries: u32 = 0;
            while (true) : (tries += 1) {
                wr.commit(db, &s, batch.items) catch |err| {
                    if (err != error.Busy) return err;
                    _ = wr.stats.busy.fetchAdd(1, .monotonic);
                    // Shutting down: give another process's lock a minute, then leave
                    // the items queued in the database for the next run
                    if (wr.closing and tries >= 60 / busy_pause_s) return;
                    log.warn("writer: database busy, retrying {d} jobs", .{batch.items.len});
                    wr.c.io.sleep(.fromSeconds(busy_pause_s), .awake) catch return;
                    continue;
                };
                break;
            }
            wr.counted(batch.items);
            const pages = db.pageCounts();
            wr.stats.pages_written.store(pages.written, .monotonic);
            wr.stats.pages_read.store(pages.missed, .monotonic);
            wr.mutex.lockUncancelable(wr.c.io);
            wr.committed_seq = batch.items[batch.items.len - 1].seq;
            wr.cond.broadcast(wr.c.io);
            wr.mutex.unlock(wr.c.io);
            wr.prune.step(db, wr.c.io, wr.c.opts) catch |err| {
                if (err != error.Busy) return err;
            };
        }
    }

    /// Called and returns with the mutex held. Sleeps in short steps so a worker that
    /// starts waiting gets its commit within ~50 ms
    fn linger(wr: *Writer) void {
        const io = wr.c.io;
        var waited: u32 = 0;
        while (wr.pending.items.len < linger_jobs and wr.waiters == 0 and !wr.closing and
            !wr.stopping() and waited < linger_ms) : (waited += 50)
        {
            wr.mutex.unlock(io);
            io.sleep(.fromMilliseconds(50), .awake) catch {};
            wr.mutex.lockUncancelable(io);
        }
    }

    fn commit(wr: *Writer, db: store.Db, s: *Stmts, jobs: []const *Job) !void {
        try db.begin();
        errdefer db.rollback();
        for (jobs) |job| try wr.applyOne(db, s, job);
        try db.commit();
    }

    fn counted(wr: *Writer, jobs: []const *Job) void {
        _ = wr.stats.jobs.fetchAdd(jobs.len, .monotonic);
        _ = wr.stats.commits.fetchAdd(1, .monotonic);
        for (jobs) |job| {
            if (!job.stored) continue;
            switch (job.kind) {
                .match => |m| _ = wr.c.counters.region[@intFromEnum(m.region)].matches.fetchAdd(1, .monotonic),
                .timeline => |t| _ = wr.c.counters.region[@intFromEnum(t.region)].timelines.fetchAdd(1, .monotonic),
                .match_ids => |q| _ = wr.c.counters.region[@intFromEnum(q.region)].ids_found.fetchAdd(q.found, .monotonic),
                .mastery => |m| if (m.blob != null) {
                    _ = wr.c.counters.mastery.fetchAdd(1, .monotonic);
                },
                .ladder => _ = wr.c.counters.ladder_pages.fetchAdd(1, .monotonic),
                else => {},
            }
        }
    }

    /// In a savepoint: a row one job cannot store must not lose the batch or stop the
    /// crawler (on restart the same match would come first again)
    fn applyOne(wr: *Writer, db: store.Db, s: *Stmts, job: *Job) !void {
        job.stored = false;
        try db.exec("SAVEPOINT job");
        wr.apply(db, s, job) catch |err| {
            db.exec("ROLLBACK TO job") catch {};
            try db.exec("RELEASE job");
            if (err != error.Sqlite) return err;
            switch (job.kind) {
                // An attempt, not failed at once: Sqlite errors are often passing
                // (locks, a full disk), and a match that never stores fails after three
                .match => |m| {
                    log.warn("match {s} not stored: {t}", .{ m.id, err });
                    try s.match_attempt.exec(.{m.id});
                },
                .timeline => |t| {
                    log.warn("timeline {s} not stored: {t}", .{ t.id, err });
                    try s.timeline_attempt.exec(.{t.id});
                },
                else => log.warn("writer: {t} not stored: {t}", .{ job.kind, err }),
            }
            return;
        };
        try db.exec("RELEASE job");
        job.stored = true;
    }

    fn apply(wr: *Writer, db: store.Db, s: *Stmts, job: *Job) !void {
        switch (job.kind) {
            .none => {},
            .ladder => |l| {
                const day = @divFloor(l.t, std.time.s_per_day);
                for (l.entries) |e| {
                    const puuid = e.puuid orelse continue;
                    if (try s.isForgotten(puuid)) continue;
                    const key = store.schema.puuidKey(puuid);
                    if (store.schema.packRank(e.tier, e.rank)) |rank| try s.rank_put.exec(.{ key, rank, day });
                    if (!sampled(key, wr.c.opts.player_sample)) continue;
                    try s.ladder_player.exec(.{
                        puuid, e.tier, e.rank, e.leaguePoints, e.wins, e.losses, l.t, l.platform.id, @tagName(l.platform.region),
                    });
                }
                try s.ladder_page.exec(.{ l.platform.id, l.tier, l.division, l.page, l.entries.len, l.t });
            },
            .mastery => |m| if (m.blob) |blob| {
                try s.mastery.exec(.{ m.puuid, m.platform, m.t, m.champions, store.Blob{ .bytes = blob } });
            } else {
                // Riot does not know the PUUID: an erased or moved account. Forget it
                // now rather than wait for the 30-day unseen expiry
                try s.mastery_delete.exec(.{m.puuid});
                try s.player_delete.exec(.{m.puuid});
            },
            .match_ids => |*q| {
                const before = try db.scalar("SELECT total_changes()", .{}) orelse 0;
                for (q.ids) |id| try s.match_queue.exec(.{ id, q.discovered_at, @tagName(q.region) });
                q.found = @intCast((try db.scalar("SELECT total_changes()", .{}) orelse 0) - before);
            },
            .checked => |ch| try s.checked.exec(.{ ch.t, ch.puuid }),
            .match => |m| try wr.storeMatch(db, s, m.region, m.id, m.doc, m.raw, m.t, m.timeline),
            .timeline => |t| try wr.storeTimeline(s, t.id, t.raw, t.compact, t.t),
            .queue => |q| switch (q.which) {
                .match => switch (q.status) {
                    .attempt => try s.match_attempt.exec(.{q.id}),
                    else => try s.match_status.exec(.{ @tagName(q.status), q.id }),
                },
                .timeline => switch (q.status) {
                    .attempt => try s.timeline_attempt.exec(.{q.id}),
                    else => try s.timeline_status.exec(.{ @tagName(q.status), q.id }),
                },
            },
        }
    }

    fn storeMatch(wr: *Writer, db: store.Db, s: *Stmts, r: ep.Region, id: []const u8, doc: match.Doc, raw: []const u8, t: i64, want_timeline: bool) !void {
        const stored_id = doc.metadata.matchId;
        const existed = try s.exists(stored_id);
        var any_forgotten = false;
        for (doc.info.participants) |p| {
            if (p.puuid) |puuid| any_forgotten = any_forgotten or try s.isForgotten(puuid);
        }
        // The raw JSON names every player, so none is kept for a forgotten one's match
        if (!any_forgotten) try s.raw_doc.exec(.{ "riot_match", id, t, store.Blob{ .bytes = raw } });
        try match.storeRows(db, doc, "riot");
        const platform = doc.info.platformId orelse if (ep.platformOf(id)) |p| p.id else null;
        for (doc.info.participants, 0..) |p, slot| {
            const puuid = p.puuid orelse continue;
            if (any_forgotten and try s.isForgotten(puuid)) {
                try s.blank_participant.exec(.{ id, slot });
                continue;
            }
            const key = store.schema.puuidKey(puuid);
            // Rank snapshot from ranks; storeRows took it from players, which keeps
            // only the scan pool
            if (try s.rankOf(key)) |rank| {
                try s.participant_rank.exec(.{ rank.tier, rank.division, id, slot });
            }
            if (wr.c.opts.participant_players and sampled(key, wr.c.opts.player_sample)) {
                try s.participant_player.exec(.{ puuid, platform, @tagName(r), t });
            }
        }
        // After the ranks above. Once per match: a re-stored one has its row already,
        // unless it still awaits the backfill
        if (!existed or try s.drafts.taken(stored_id)) _ = try s.drafts.write(stored_id);
        if (want_timeline and !match.isRemake(doc) and wr.c.wantTimeline(id)) try s.timeline_queue.exec(.{ id, @tagName(r), t });
        try s.match_done.exec(.{id});
    }

    fn storeTimeline(wr: *Writer, s: *Stmts, id: []const u8, raw: ?[]const u8, compact: ?crawl.Compact, t: i64) !void {
        // Raw timelines carry PUUIDs: none kept when a player is blank (forgotten, or a
        // match from before a rekey)
        try s.blank.bind(.{id});
        const blank = try s.blank.step() and s.blank.int(0) == 1;
        s.blank.reset();
        if (!blank and (wr.c.opts.raw_timeline_days > 0 or compact == null)) {
            if (raw) |bytes| try s.raw_timeline.exec(.{ id, t, store.Blob{ .bytes = bytes } });
        }
        if (compact) |ct| {
            try s.timeline.exec(.{ id, ct.frames, ct.events, store.Blob{ .bytes = ct.blob } });
            for (0..ct.participants) |slot| {
                try s.gold.exec(.{ ct.gold[0][slot], ct.gold[1][slot], ct.gold[2][slot], id, slot });
            }
            try s.timeline_done.exec(.{id});
        } else try s.timeline_status.exec(.{ "failed", id });
    }
};

/// The writer's connection: the only one that needs a big page cache. The WAL file
/// keeps its high-water size, so cap it: a burst must not leave a huge file every
/// reader searches
fn tune(db: store.Db, cache_mb: u32) !void {
    var buf: [64]u8 = undefined;
    try db.exec(try std.fmt.bufPrintZ(&buf, "PRAGMA main.cache_size = -{d}", .{cache_mb * 1024}));
    try db.exec(
        \\PRAGMA main.journal_size_limit = 67108864;
        \\PRAGMA raw.journal_size_limit = 67108864;
        \\PRAGMA timeline.journal_size_limit = 67108864;
        \\PRAGMA temp_store = MEMORY;
        \\CREATE TEMP TABLE IF NOT EXISTS gone (id TEXT PRIMARY KEY);
    );
}

/// Hourly upkeep, one chunk per batch so items never wait long behind it
const Prune = struct {
    /// Index into `steps`; steps.len when idle
    next: usize = steps.len,
    started_at: i64 = 0,
    total: i64 = 0,

    const Step = struct {
        what: []const u8,
        days: union(enum) { raw_timeline, raw_match, keep, fixed: u32 },
        /// Removes one chunk older than the cutoff (unix seconds); returns how many
        run: *const fn (db: store.Db, cutoff: i64) store.sqlite.Error!i64,
    };

    const steps = [_]Step{
        // Raw timelines that failed to parse stay, so a fixed parser can redo them
        .{ .what = "raw timelines", .days = .raw_timeline, .run = chunk(
            \\DELETE FROM raw.timeline_docs WHERE rowid IN
            \\    (SELECT rowid FROM raw.timeline_docs d WHERE fetched_at < ? AND NOT EXISTS
            \\        (SELECT 1 FROM timeline_queue q
            \\         WHERE q.match_id = d.match_id AND q.status = 'failed')
            \\     LIMIT 500)
        ) },
        .{ .what = "raw match summaries", .days = .raw_match, .run = chunk(
            \\DELETE FROM raw.raw_docs WHERE source = 'riot_match' AND key IN
            \\    (SELECT key FROM raw.raw_docs
            \\     WHERE source = 'riot_match' AND fetched_at < ? LIMIT 500)
        ) },
        // Riot asks for stored player data to be refreshed monthly: players no ladder
        // page or match has shown for 30 days go with their mastery (erased accounts
        // stop appearing), and older mastery is dropped to be fetched again
        .{ .what = "unseen players", .days = .{ .fixed = 30 }, .run = unseenPlayers },
        .{ .what = "unseen ranks", .days = .{ .fixed = 30 }, .run = unseenRanks },
        .{ .what = "mastery snapshots", .days = .{ .fixed = 30 }, .run = chunk(
            \\DELETE FROM mastery WHERE puuid IN
            \\    (SELECT puuid FROM mastery WHERE fetched_at < ? LIMIT 500)
        ) },
        // Privacy policy: matches older than 24 months keep no PUUIDs
        .{ .what = "PUUIDs of old matches", .days = .{ .fixed = 730 }, .run = chunk(
            \\UPDATE participants SET puuid = NULL WHERE (match_id, slot) IN
            \\    (SELECT p.match_id, p.slot FROM matches m JOIN participants p USING (match_id)
            \\     WHERE m.game_start < ? * 1000 AND p.puuid IS NOT NULL LIMIT 2000)
        ) },
        .{ .what = "matches past the window", .days = .keep, .run = oldMatches },
    };

    fn chunk(comptime sql: []const u8) *const fn (store.Db, i64) store.sqlite.Error!i64 {
        return struct {
            fn run(db: store.Db, cutoff: i64) store.sqlite.Error!i64 {
                try db.run(sql, .{cutoff});
                return try db.scalar("SELECT changes()", .{}) orelse 0;
            }
        }.run;
    }

    /// A chunk of ids into a temp table, then every table's rows for them
    fn unseenPlayers(db: store.Db, cutoff: i64) store.sqlite.Error!i64 {
        try db.exec("DELETE FROM temp.gone");
        try db.run("INSERT INTO temp.gone SELECT puuid FROM players WHERE seen_at < ? LIMIT 500", .{cutoff});
        const n = try db.scalar("SELECT changes()", .{}) orelse 0;
        try db.exec(
            \\DELETE FROM mastery WHERE puuid IN temp.gone;
            \\DELETE FROM players WHERE puuid IN temp.gone;
        );
        return n;
    }

    /// A twenty-fourth of the key space per hourly round (ranks has no seen_day index:
    /// it would cost a random write per row), so the whole table is swept daily
    fn unseenRanks(db: store.Db, cutoff: i64) store.sqlite.Error!i64 {
        const slice: i128 = @mod(@divFloor(cutoff, 3600), 24);
        const span: i128 = (@as(i128, 1) << 64) / 24;
        const lo: i64 = @intCast(std.math.minInt(i64) + slice * span);
        const hi: i64 = if (slice == 23) std.math.maxInt(i64) else @intCast(lo + span - 1);
        try db.run(
            \\DELETE FROM ranks WHERE key IN (SELECT key FROM ranks
            \\    WHERE key BETWEEN ? AND ? AND seen_day < ? LIMIT 500)
        , .{ lo, hi, @divFloor(cutoff, std.time.s_per_day) });
        return try db.scalar("SELECT changes()", .{}) orelse 0;
    }

    fn oldMatches(db: store.Db, cutoff: i64) store.sqlite.Error!i64 {
        try db.exec("DELETE FROM temp.gone");
        // Not those the draft backfill has yet to read
        try db.run(
            \\INSERT INTO temp.gone SELECT match_id FROM matches
            \\WHERE game_start < ? * 1000 AND match_id NOT IN draft_backfill LIMIT 500
        , .{cutoff});
        const n = try db.scalar("SELECT changes()", .{}) orelse 0;
        try db.exec(
            \\DELETE FROM timeline.timelines WHERE match_id IN temp.gone;
            \\DELETE FROM participants WHERE match_id IN temp.gone;
            \\DELETE FROM bans WHERE match_id IN temp.gone;
            \\DELETE FROM matches WHERE match_id IN temp.gone;
        );
        return n;
    }

    fn cutoffDays(s: Step, opts: crawl.Options) ?u32 {
        const days = switch (s.days) {
            // 0 keeps no raw timelines; for the rest 0 is forever
            .raw_timeline => return opts.raw_timeline_days,
            .raw_match => opts.raw_match_days,
            .keep => opts.keep_days,
            .fixed => |d| d,
        };
        return if (days == 0) null else days;
    }

    /// Start a round when an hour has passed, else run one chunk of the current step.
    /// The first round an hour after start: start-up is busy enough on a slow box
    fn step(p: *Prune, db: store.Db, io: std.Io, opts: crawl.Options) !void {
        const now = std.Io.Clock.real.now(io).toSeconds();
        if (p.started_at == 0) p.started_at = now;
        if (p.next == steps.len) {
            if (now - p.started_at < 3600) return;
            p.started_at = now;
            p.next = 0;
            p.total = 0;
        }
        const s = steps[p.next];
        const days = cutoffDays(s, opts) orelse return p.advance();
        try db.begin();
        errdefer db.rollback();
        const n = try s.run(db, now - @as(i64, days) * 86400);
        try db.commit();
        p.total += n;
        if (n == 0) {
            if (p.total > 0) log.info("pruned {d} {s}", .{ p.total, s.what });
            p.advance();
        }
    }

    fn advance(p: *Prune) void {
        p.next += 1;
        p.total = 0;
    }
};

/// In the scan pool: one PUUID key in `sample` (all when sample is 0 or 1)
fn sampled(key: i64, sample: u32) bool {
    return sample <= 1 or @as(u64, @bitCast(key)) % sample == 0;
}

/// Prepared once: on the slow box re-preparing per row cost as much as the writes
const Stmts = struct {
    forgotten: store.Stmt,
    rank_put: store.Stmt,
    rank_get: store.Stmt,
    participant_rank: store.Stmt,
    ladder_player: store.Stmt,
    ladder_page: store.Stmt,
    mastery: store.Stmt,
    mastery_delete: store.Stmt,
    player_delete: store.Stmt,
    match_queue: store.Stmt,
    checked: store.Stmt,
    raw_doc: store.Stmt,
    participant_player: store.Stmt,
    blank_participant: store.Stmt,
    timeline_queue: store.Stmt,
    match_status: store.Stmt,
    match_done: store.Stmt,
    match_attempt: store.Stmt,
    blank: store.Stmt,
    raw_timeline: store.Stmt,
    timeline: store.Stmt,
    gold: store.Stmt,
    timeline_status: store.Stmt,
    timeline_done: store.Stmt,
    timeline_attempt: store.Stmt,
    match_exists: store.Stmt,
    drafts: store.draft.Builder,

    const sql = .{
        .forgotten = "SELECT EXISTS (SELECT 1 FROM forgotten WHERE puuid = ?)",
        // A refetched page rewrites a row only when the rank changed or a day passed
        .rank_put =
        \\INSERT INTO ranks VALUES (?1, ?2, ?3) ON CONFLICT (key) DO UPDATE SET
        \\    rank = excluded.rank, seen_day = excluded.seen_day
        \\WHERE rank <> excluded.rank OR seen_day <> excluded.seen_day
        ,
        .rank_get = "SELECT rank FROM ranks WHERE key = ?",
        .participant_rank = "UPDATE participants SET tier = ?, division = ? WHERE match_id = ? AND slot = ?",
        .ladder_player =
        \\INSERT INTO players (puuid, tier, division, lp, wins, losses, rank_seen_at, source,
        \\    platform, region, seen_at, games_checked)
        \\VALUES (?1,?2,?3,?4,?5,?6,?7,'ladder',?8,?9,?7,?5 + ?6)
        \\ON CONFLICT (puuid) DO UPDATE SET
        \\    tier = excluded.tier, division = excluded.division, lp = excluded.lp,
        \\    wins = excluded.wins, losses = excluded.losses,
        \\    rank_seen_at = excluded.rank_seen_at, source = 'ladder',
        \\    platform = excluded.platform, region = excluded.region,
        \\    seen_at = excluded.seen_at,
        // Fewer games than checked: a new season. Never set: from the previous page,
        // so its games since then count as new
        \\    games_checked = CASE
        \\        WHEN excluded.wins + excluded.losses < coalesce(games_checked, wins + losses, 0)
        \\            THEN excluded.wins + excluded.losses
        \\        WHEN games_checked IS NULL THEN coalesce(wins + losses, excluded.wins + excluded.losses)
        \\        ELSE games_checked END
        // Most of a ladder is unchanged week to week: leave those rows (and the
        // players indexes) alone unless seen_at is a day old
        \\WHERE tier IS NOT excluded.tier OR division IS NOT excluded.division
        \\    OR lp IS NOT excluded.lp OR wins IS NOT excluded.wins
        \\    OR losses IS NOT excluded.losses OR source <> 'ladder'
        \\    OR seen_at < excluded.seen_at - 86400
        ,
        .ladder_page = "INSERT OR REPLACE INTO ladder_pages " ++
            "(platform, tier, division, page, entries, fetched_at) VALUES (?,?,?,?,?,?)",
        .mastery = "INSERT OR REPLACE INTO mastery VALUES (?,?,?,?,?)",
        .mastery_delete = "DELETE FROM mastery WHERE puuid = ?",
        .player_delete = "DELETE FROM players WHERE puuid = ?",
        // Stored matches leave the queue, so a match already stored is checked for too
        .match_queue =
        \\INSERT OR IGNORE INTO match_queue (match_id, discovered_at, region)
        \\SELECT ?1, ?2, ?3 WHERE NOT EXISTS (SELECT 1 FROM matches WHERE match_id = ?1)
        ,
        .checked = "UPDATE players SET matches_checked_at = ?, games_checked = wins + losses WHERE puuid = ?",
        .raw_doc = "INSERT OR REPLACE INTO raw.raw_docs VALUES (?,?,?,?)",
        .participant_player =
        \\INSERT INTO players (puuid, source, platform, region, seen_at)
        \\VALUES (?, 'participant', ?, ?, ?)
        \\ON CONFLICT (puuid) DO UPDATE SET seen_at = excluded.seen_at
        \\WHERE seen_at < excluded.seen_at - 86400
        ,
        .blank_participant = "UPDATE participants SET puuid = NULL WHERE match_id = ? AND slot = ?",
        .timeline_queue = "INSERT OR IGNORE INTO timeline_queue (match_id, region, queued_at) VALUES (?, ?, ?)",
        .match_status = "UPDATE match_queue SET status = ? WHERE match_id = ?",
        .match_done = "DELETE FROM match_queue WHERE match_id = ?",
        .match_attempt =
        \\UPDATE match_queue SET attempts = attempts + 1,
        \\    status = CASE WHEN attempts >= 2 THEN 'failed' ELSE status END
        \\WHERE match_id = ?
        ,
        .blank = "SELECT EXISTS (SELECT 1 FROM participants WHERE match_id = ? AND puuid IS NULL)",
        .raw_timeline = "INSERT OR REPLACE INTO raw.timeline_docs VALUES (?,?,?)",
        .timeline = "INSERT OR REPLACE INTO timeline.timelines VALUES (?,?,?,?)",
        .gold = "UPDATE participants SET gold10 = ?, gold14 = ?, gold15 = ? WHERE match_id = ? AND slot = ?",
        .timeline_status = "UPDATE timeline_queue SET status = ? WHERE match_id = ?",
        .timeline_done = "DELETE FROM timeline_queue WHERE match_id = ?",
        .timeline_attempt =
        \\UPDATE timeline_queue SET attempts = attempts + 1,
        \\    status = CASE WHEN attempts >= 2 THEN 'failed' ELSE status END
        \\WHERE match_id = ?
        ,
        .match_exists = "SELECT EXISTS (SELECT 1 FROM matches WHERE match_id = ?)",
    };

    fn init(db: store.Db) !Stmts {
        var s: Stmts = undefined;
        s.drafts = try .init(db);
        errdefer s.drafts.deinit();
        var done: usize = 0;
        errdefer inline for (stmt_fields, 0..) |f, i| {
            if (i < done) @field(s, f.name).deinit();
        };
        inline for (stmt_fields) |f| {
            @field(s, f.name) = try db.prepare(@field(sql, f.name));
            done += 1;
        }
        return s;
    }

    fn deinit(s: *Stmts) void {
        inline for (stmt_fields) |f| @field(s, f.name).deinit();
        s.drafts.deinit();
    }

    /// Every field but drafts
    const stmt_fields = @typeInfo(Stmts).@"struct".fields[0 .. @typeInfo(Stmts).@"struct".fields.len - 1];

    fn exists(s: *Stmts, match_id: []const u8) !bool {
        try s.match_exists.bind(.{match_id});
        defer s.match_exists.reset();
        return try s.match_exists.step() and s.match_exists.int(0) == 1;
    }

    fn rankOf(s: *Stmts, key: i64) !?store.schema.Rank {
        try s.rank_get.bind(.{key});
        defer s.rank_get.reset();
        if (!try s.rank_get.step()) return null;
        return store.schema.unpackRank(s.rank_get.int(0));
    }

    fn isForgotten(s: *Stmts, puuid: []const u8) !bool {
        try s.forgotten.bind(.{puuid});
        defer s.forgotten.reset();
        return try s.forgotten.step() and s.forgotten.int(0) == 1;
    }
};

test "jobs apply in one transaction; a bad one counts an attempt, the rest stored" {
    // The bad job's warnings are expected
    std.testing.log_level = .err;
    const gpa = std.testing.allocator;
    const db = try store.schema.memory();
    defer db.close();
    var c: crawl.Crawler = .{ .gpa = gpa, .io = std.testing.io, .opts = .{ .data_dir = "", .key = "" } };
    var wr: Writer = .{ .c = &c };
    defer wr.deinit();
    var s: Stmts = try .init(db);
    defer s.deinit();

    try db.exec(
        \\INSERT INTO match_queue (match_id, discovered_at, region) VALUES ('EUW1_1', 1, 'europe');
        \\INSERT INTO timeline_queue (match_id, region, queued_at) VALUES ('EUW1_2', 'europe', 1);
        \\INSERT INTO forgotten VALUES ('gone', 1);
        \\CREATE TRIGGER timeline.no_bad BEFORE INSERT ON timelines WHEN new.match_id = 'EUW1_2'
        \\    BEGIN SELECT RAISE(ABORT, 'bad'); END;
    );
    var jobs: [4]*Job = undefined;
    jobs[0] = try .create(gpa, .{ .match_ids = undefined });
    const ids = try jobs[0].allocator().dupe([]const u8, &.{ "EUW1_1", "EUW1_3" });
    jobs[0].kind = .{ .match_ids = .{ .ids = ids, .discovered_at = 2, .region = .europe } };
    jobs[1] = try .create(gpa, .{ .ladder = .{
        .platform = ep.platform("EUW1").?,
        .tier = "GOLD",
        .division = "I",
        .page = 1,
        .entries = &.{ .{ .puuid = "p1", .tier = "GOLD", .rank = "I" }, .{ .puuid = "gone", .tier = "GOLD", .rank = "I" } },
        .t = 5,
    } });
    jobs[2] = try .create(gpa, .{ .timeline = .{
        .region = .europe,
        .id = "EUW1_2",
        .raw = "x",
        .compact = .{ .blob = @constCast("c"), .frames = 1, .events = 1, .participants = 0, .gold = undefined },
        .t = 5,
    } });
    jobs[3] = try .create(gpa, .{ .queue = .{ .which = .match, .id = "EUW1_1", .status = .attempt } });
    defer for (jobs) |job| job.destroy(gpa);

    try wr.commit(db, &s, &jobs);
    try std.testing.expect(jobs[1].stored and !jobs[2].stored and jobs[3].stored);
    const want = [_]struct { []const u8, i64 }{
        .{ "SELECT count(*) FROM match_queue", 2 },
        .{ "SELECT attempts FROM match_queue WHERE match_id = 'EUW1_1'", 1 },
        .{ "SELECT count(*) FROM players", 1 },
        .{ "SELECT count(*) FROM ladder_pages WHERE entries = 2", 1 },
        .{ "SELECT attempts FROM timeline_queue WHERE match_id = 'EUW1_2' AND status = 'pending'", 1 },
        .{ "SELECT count(*) FROM raw.timeline_docs", 0 },
    };
    for (want) |w| try std.testing.expectEqual(@as(?i64, w[1]), try db.scalar(w[0], .{}));
}

test "stored matches leave the queue and are not queued again" {
    const gpa = std.testing.allocator;
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    const db = try store.schema.memory();
    defer db.close();
    var c: crawl.Crawler = .{ .gpa = gpa, .io = std.testing.io, .opts = .{ .data_dir = "", .key = "" } };
    var wr: Writer = .{ .c = &c };
    defer wr.deinit();
    var s: Stmts = try .init(db);
    defer s.deinit();

    var doc = try match.parse(arena.allocator(), @embedFile("testdata/match.json"));
    doc.metadata.matchId = "EUW1_1";
    const ids: []const []const u8 = &.{ "EUW1_1", "EUW1_2" };
    var first = [_]*Job{
        try .create(gpa, .{ .match_ids = .{ .ids = ids, .discovered_at = 1, .region = .europe } }),
        try .create(gpa, .{ .match = .{ .region = .europe, .id = "EUW1_1", .doc = doc, .raw = "r", .t = 2 } }),
    };
    defer for (first) |job| job.destroy(gpa);
    try wr.commit(db, &s, &first);
    var again = [_]*Job{try .create(gpa, .{ .match_ids = .{ .ids = ids, .discovered_at = 3, .region = .europe } })};
    defer for (again) |job| job.destroy(gpa);
    try wr.commit(db, &s, &again);

    const want = [_]struct { []const u8, i64 }{
        .{ "SELECT count(*) FROM match_queue", 1 },
        .{ "SELECT count(*) FROM match_queue WHERE match_id = 'EUW1_2'", 1 },
        .{ "SELECT count(*) FROM timeline_queue", 1 },
        .{ "SELECT count(*) FROM players WHERE source = 'participant'", 10 },
    };
    for (want) |w| try std.testing.expectEqual(@as(?i64, w[1]), try db.scalar(w[0], .{}));
}

test "rolling window prunes old matches with their rows" {
    const db = try store.schema.memory();
    defer db.close();
    try tune(db, 1);
    const now = std.Io.Clock.real.now(std.testing.io).toSeconds();
    var buf: [1024]u8 = undefined;
    try db.exec(try std.fmt.bufPrintZ(&buf,
        \\INSERT INTO matches VALUES ('A', 'riot', 'EUW1', 420, '16.1', '16.1.1', {d}, 1, 100, 0);
        \\INSERT INTO matches VALUES ('B', 'riot', 'EUW1', 420, '16.1', '16.1.1', {d}, 1, 100, 0);
        \\INSERT INTO participants (match_id, slot, team_id, champion_id, win) VALUES
        \\    ('A', 0, 100, 1, 1), ('B', 0, 100, 1, 1);
        \\INSERT INTO bans VALUES ('A', 100, 1, 2), ('B', 100, 1, 2);
        \\INSERT INTO timeline.timelines VALUES ('A', 1, 1, x'00'), ('B', 1, 1, x'00');
        \\INSERT INTO players (puuid, source, seen_at) VALUES ('old', 'ladder', 1), ('new', 'ladder', {d});
        \\INSERT INTO mastery VALUES ('old', 'EUW1', {d}, 0, x'00');
    , .{ (now - 61 * 86400) * 1000, (now - 59 * 86400) * 1000, now, now }));
    var p: Prune = .{ .started_at = 1 };
    const opts: crawl.Options = .{ .data_dir = "", .key = "", .keep_days = 60 };
    for (0..40) |_| try p.step(db, std.testing.io, opts);
    for ([_][]const u8{ "matches", "participants", "bans", "timeline.timelines" }) |t| {
        var sql: [128]u8 = undefined;
        var q = try db.prepare(try std.fmt.bufPrint(&sql, "SELECT group_concat(match_id) FROM {s}", .{t}));
        defer q.deinit();
        try q.bind(.{});
        try std.testing.expect(try q.step());
        try std.testing.expectEqualStrings("B", q.bytes(0));
    }
    try std.testing.expectEqual(@as(?i64, 1), try db.scalar("SELECT count(*) FROM players", .{}));
    try std.testing.expectEqual(@as(?i64, 0), try db.scalar("SELECT count(*) FROM mastery", .{}));
}

test "ladder: ranks for everyone, player rows for the sample; matches take ranks" {
    const gpa = std.testing.allocator;
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    const db = try store.schema.memory();
    defer db.close();
    var c: crawl.Crawler = .{ .gpa = gpa, .io = std.testing.io, .opts = .{ .data_dir = "", .key = "", .player_sample = 1000 } };
    var wr: Writer = .{ .c = &c };
    defer wr.deinit();
    var s: Stmts = try .init(db);
    defer s.deinit();

    var doc = try match.parse(arena.allocator(), @embedFile("testdata/match.json"));
    doc.metadata.matchId = "EUW1_1";
    const puuid = doc.info.participants[0].puuid.?;
    var jobs = [_]*Job{
        try .create(gpa, .{ .ladder = .{
            .platform = ep.platform("EUW1").?,
            .tier = "GOLD",
            .division = "II",
            .page = 1,
            .entries = &.{.{ .puuid = puuid, .tier = "GOLD", .rank = "II" }},
            .t = 5 * std.time.s_per_day,
        } }),
        try .create(gpa, .{ .match = .{ .region = .europe, .id = "EUW1_1", .doc = doc, .raw = "r", .t = 6 } }),
    };
    defer for (jobs) |job| job.destroy(gpa);
    try wr.commit(db, &s, &jobs);
    const want = [_]struct { []const u8, i64 }{
        .{ "SELECT count(*) FROM ranks WHERE seen_day = 5", 1 },
        .{ "SELECT count(*) FROM participants WHERE match_id = 'EUW1_1' AND slot = 0 AND tier = 'GOLD' AND division = 'II'", 1 },
    };
    for (want) |w| try std.testing.expectEqual(@as(?i64, w[1]), try db.scalar(w[0], .{}));
    // 1 in 1000 sampled: almost surely none of the 11 PUUIDs
    try std.testing.expect((try db.scalar("SELECT count(*) FROM players", .{})).? <= 2);
}

test "one draft row per match, kept by the prune; listed matches wait for the backfill" {
    const gpa = std.testing.allocator;
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    const db = try store.schema.memory();
    defer db.close();
    try tune(db, 1);
    var c: crawl.Crawler = .{ .gpa = gpa, .io = std.testing.io, .opts = .{ .data_dir = "", .key = "" } };
    var wr: Writer = .{ .c = &c };
    defer wr.deinit();
    var s: Stmts = try .init(db);
    defer s.deinit();

    var docs: [3]match.Doc = undefined;
    for (&docs, 0..) |*d, i| {
        d.* = try match.parse(arena.allocator(), @embedFile("testdata/match.json"));
        d.metadata.matchId = try std.fmt.allocPrint(arena.allocator(), "EUW1_{d}", .{i + 1});
    }
    // 2 and 3 were stored before drafts existed
    try match.storeRows(db, docs[1], "riot");
    try match.storeRows(db, docs[2], "riot");
    try db.exec("INSERT INTO draft_backfill VALUES ('EUW1_2'), ('EUW1_3')");
    var jobs: [3]*Job = undefined;
    for (&jobs, [_]usize{ 0, 0, 1 }) |*job, d| {
        const id = docs[d].metadata.matchId;
        job.* = try .create(gpa, .{ .match = .{ .region = .europe, .id = id, .doc = docs[d], .raw = "r", .t = 2 } });
    }
    defer for (jobs) |job| job.destroy(gpa);
    try wr.commit(db, &s, &jobs);
    try std.testing.expectEqual(@as(?i64, 2), try db.scalar("SELECT count(*) FROM drafts", .{}));

    // The fixture game is from 2025: past a 1-day window, except 3 (still listed)
    var p: Prune = .{ .started_at = 1 };
    const opts: crawl.Options = .{ .data_dir = "", .key = "", .keep_days = 1 };
    for (0..40) |_| try p.step(db, std.testing.io, opts);
    const want = [_]struct { []const u8, i64 }{
        .{ "SELECT count(*) FROM drafts", 2 },
        .{ "SELECT count(*) FROM matches WHERE match_id = 'EUW1_3'", 1 },
        .{ "SELECT count(*) FROM matches", 1 },
        .{ "SELECT count(*) FROM draft_backfill", 1 },
    };
    for (want) |w| try std.testing.expectEqual(@as(?i64, w[1]), try db.scalar(w[0], .{}));
}

test "games_checked: from the ladder's previous counts, reset by a scan or a new season" {
    const db = try store.schema.memory();
    defer db.close();
    try db.exec(
        \\INSERT INTO players (puuid, wins, losses, source, platform, region) VALUES
        \\    ('old', 10, 10, 'ladder', 'EUW1', 'europe');
    );
    var s: Stmts = try .init(db);
    defer s.deinit();
    const Row = struct { []const u8, i64, i64 };
    const pages = [_]Row{ .{ "old", 12, 11 }, .{ "new", 3, 4 } };
    for (pages) |r| try s.ladder_player.exec(.{ r[0], "GOLD", "I", 0, r[1], r[2], 5, "EUW1", "europe" });
    const pending = "SELECT wins + losses - games_checked FROM players WHERE puuid = ?";
    try std.testing.expectEqual(@as(?i64, 3), try db.scalar(pending, .{"old"}));
    try std.testing.expectEqual(@as(?i64, 0), try db.scalar(pending, .{"new"}));
    try s.checked.exec(.{ 6, "old" });
    try std.testing.expectEqual(@as(?i64, 0), try db.scalar(pending, .{"old"}));
    try s.ladder_player.exec(.{ "old", "GOLD", "I", 0, 14, 11, 7, "EUW1", "europe" });
    try std.testing.expectEqual(@as(?i64, 2), try db.scalar(pending, .{"old"}));
    // New season: counts restart below games_checked
    try s.ladder_player.exec(.{ "old", "GOLD", "I", 0, 1, 0, 8, "EUW1", "europe" });
    try std.testing.expectEqual(@as(?i64, 0), try db.scalar(pending, .{"old"}));
}

test "non-priority jobs wait at half the queue, priority ones at full" {
    try std.testing.expect(Writer.room(max_pending / 2 - 1, false));
    try std.testing.expect(!Writer.room(max_pending / 2, false));
    try std.testing.expect(Writer.room(max_pending - 1, true));
    try std.testing.expect(!Writer.room(max_pending, true));
}
