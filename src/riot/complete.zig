//! The complete form writer (docs/plan/ops.md "Complete form"): every summary, timeline
//! and mastery body the crawler stores goes byte-exact into a day file,
//! <data>/complete/YYYY-MM-DD.<kind>.cfd (store/dayfile.zig), `.cfd.part` while that day
//! is open. A sealed file is never opened for write again.
//!
//! The writer hands each committed document to the Packer thread, which appends each
//! batch it takes to spool segments (complete/spool/<kind>.<n>, gzip as the raw store has
//! it, no fsync) before adding it to a jsonpack block in memory. At block_docs documents (or block_plain bytes) the block is
//! decoded again and each document compared (length and xxhash64 kept per add); one that
//! does not come back is tried alone and kept raw if it fails, the rest repacked. The
//! Sealer thread then runs `zstd -19`, reads the result back through std's decompressor,
//! appends the frame, fsyncs and deletes the segment.
//!
//! Crash safety: a torn frame at a file's end is cut on start (dayfile.recover); spool
//! segments left behind are replayed through the same path, so a crash loses at most the
//! documents queued but not yet spooled (ms). A stop (SIGTERM, crawl.zig) spools the
//! queue, finishes the zstd run in hand (zstd ignores the signal) and leaves the rest in
//! the spool. A crash between a frame's fsync and its segment's delete stores those
//! documents twice: readers keep one per key. A document that crashes the packer would
//! crash every start after (replay meets it again, in whichever segment it was moved
//! to): after poison_starts unclean runs in a row the whole spool goes to
//! spool/quarantine.
//! Day = the UTC day a document reached the Packer; at midnight partial blocks go to the
//! old day's files, which are then sealed.

const std = @import("std");
const store = @import("store");
const archive = @import("../archive.zig");
const Date = @import("../date.zig").Date;
const dayfile = store.dayfile;
const jsonpack = store.jsonpack;
const Io = std.Io;
const Allocator = std.mem.Allocator;
const XxHash64 = std.hash.XxHash64;

const log = std.log.scoped(.complete);

pub const Kind = enum { summary, timeline, mastery };

pub const block_docs = 256;
pub const block_plain = 256 << 20;
/// Seal jobs waiting at most: the Packer waits when zstd falls this far behind
const max_jobs = 4;
/// Queue length that warns (spooled only once the Packer takes it)
const queue_warn = 20_000;
/// Queue length past which pushes are dropped (off for long): ~1 GB of gzip bodies
const queue_drop = 200_000;
/// Pause after an error before starting again from the spool, doubled for each other
/// restart in the last backoff_window_s (a lasting error replays the whole spool each
/// time), at most max_restart_s
const restart_s = 60;
const max_restart_s = 60 * 60;
const backoff_window_s = 6 * 60 * 60;
/// Unclean runs in a row (complete/starts) before a start sets the spool aside; a run
/// counts as clean once it closes or has run healthy_s
const poison_starts = 3;
const healthy_s = 30 * 60;
/// --zstd=wlog=23 pins the window to std's default 8 MB decompress window: a bigger one
/// (--ultra, --long) would fail every readback
const zstd_level = "-19 --zstd=wlog=23";

/// One stored document, as the writer hands it over (copied)
pub const Item = struct { kind: Kind, key: []const u8, t: i64, gz: []const u8 };

pub const Stats = struct {
    docs: std.atomic.Value(u64) = .init(0),
    /// Documents kept raw: not compact, or did not come back from a block
    raw: std.atomic.Value(u64) = .init(0),
    frames: std.atomic.Value(u64) = .init(0),
    /// Pushed while the queue was full (off for long): in neither a file nor the spool
    dropped: std.atomic.Value(u64) = .init(0),
    bytes: std.atomic.Value(u64) = .init(0),
    /// Awake-clock seconds of the latest restarts after an error, newest last
    restarts: [restarts_kept]std.atomic.Value(i64) = @splat(.init(std.math.minInt(i64) / 2)),

    const restarts_kept = 8;

    /// Restarts after an error in the last hour (at most restarts_kept)
    pub fn restartsLastHour(s: *const Stats, io: Io) usize {
        return s.restartsWithin(Io.Clock.awake.now(io).toSeconds(), std.time.s_per_hour);
    }

    fn restartsWithin(s: *const Stats, now: i64, window_s: i64) usize {
        var n: usize = 0;
        for (&s.restarts) |*r| n += @intFromBool(now - r.load(.monotonic) < window_s);
        return n;
    }

    fn noteRestart(s: *Stats, now: i64) void {
        const r = &s.restarts;
        for (r[0 .. r.len - 1], r[1..]) |*a, *b| a.store(b.load(.monotonic), .monotonic);
        r[r.len - 1].store(now, .monotonic);
    }
};

/// An item in one allocation: key then gz
const Owned = struct {
    kind: Kind,
    t: i64,
    key_len: usize,
    buf: []u8,

    fn key(o: Owned) []const u8 {
        return o.buf[0..o.key_len];
    }

    fn gz(o: Owned) []const u8 {
        return o.buf[o.key_len..];
    }
};

pub const Packer = struct {
    gpa: Allocator,
    io: Io,
    /// <data>/complete
    dir: []const u8,
    mutex: Io.Mutex = .init,
    cond: Io.Condition = .init,
    queue: std.ArrayList(Owned) = .empty,
    closing: bool = false,
    /// Set with closing: packing stops at the next document (it is spooled already) and
    /// a wait for the sealer gives up, so a stop takes at most the zstd run in hand
    stopping: std.atomic.Value(bool) = .init(false),
    /// Between an error and the restart from the spool (backoff): pushes queue
    off: std.atomic.Value(bool) = .init(false),
    /// Adding a batch taken from the queue
    busy: bool = false,
    block_docs: usize = block_docs,
    restart_s: i64 = restart_s,
    lanes: [3]Lane = undefined,
    next_seg: u64 = 0,
    /// The UTC day the lanes' blocks belong to
    day: i64 = 0,
    sealer: Sealer = undefined,
    stats: Stats = .{},
    /// The day files' current UTC day, for tests
    clock: *const fn (Io) i64 = realDay,
    thread: ?std.Thread = null,
    sealer_thread: ?std.Thread = null,
    /// complete/lock, held while the packer runs: a second crawler on the same data would
    /// append to the same day files
    lock: Io.File,
    /// Awake clock at start; null once this run counted as clean
    started: ?i64 = null,

    /// Checks zstd is on PATH, makes the directories and takes the lock (error.Locked)
    pub fn init(gpa: Allocator, io: Io, data_dir: []const u8) !Packer {
        const r = std.process.run(gpa, io, .{ .argv = &.{ "zstd", "--version" } }) catch |err| {
            log.err("zstd not found ({t}): install it or run with --no-complete", .{err});
            return error.ZstdMissing;
        };
        gpa.free(r.stdout);
        gpa.free(r.stderr);
        const dir = try std.fs.path.join(gpa, &.{ data_dir, "complete" });
        errdefer gpa.free(dir);
        const spool_dir = try std.fs.path.join(gpa, &.{ dir, "spool" });
        defer gpa.free(spool_dir);
        try Io.Dir.cwd().createDirPath(io, spool_dir);
        const lock_path = try std.fs.path.join(gpa, &.{ dir, "lock" });
        defer gpa.free(lock_path);
        const lock = Io.Dir.cwd().createFile(io, lock_path, .{ .lock = .exclusive, .lock_nonblocking = true, .truncate = false }) catch |err| switch (err) {
            error.WouldBlock => return error.Locked,
            else => return err,
        };
        return .{ .gpa = gpa, .io = io, .dir = dir, .lock = lock };
    }

    /// Seals day files of older days, finds the spool to replay, starts both threads.
    /// `p` stays put until close
    pub fn start(p: *Packer) !void {
        for (&p.lanes, 0..) |*l, i| l.* = .{ .kind = @fromBackingInt(@intCast(i)), .block = .init(p.gpa) };
        p.sealer = .{ .p = p };
        // Never a day already sealed: a clock behind (stepped back, or wrong at boot)
        // writes to the day after the newest sealed one until it catches up
        p.day = @max(p.clock(p.io), (try p.sealer.newestSealed() orelse 0) + 1);
        try p.sealer.sealOlder(p.day);
        const unclean = p.readStarts();
        if (unclean >= poison_starts) try p.quarantine(unclean);
        try p.writeStarts(if (unclean >= poison_starts) 1 else unclean + 1);
        p.started = Io.Clock.awake.now(p.io).toSeconds();
        p.next_seg = try p.lastSegment() + 1;
        p.sealer_thread = try std.Thread.spawn(.{}, Sealer.run, .{&p.sealer});
        p.thread = try std.Thread.spawn(.{}, run, .{p});
    }

    /// After the writer stopped: spools what is queued, then stops both threads. Blocks
    /// not yet sealed stay in the spool for the next start. Also undoes a failed start
    pub fn close(p: *Packer) void {
        {
            p.mutex.lockUncancelable(p.io);
            defer p.mutex.unlock(p.io);
            p.closing = true;
            p.stopping.store(true, .release);
            p.cond.broadcast(p.io);
        }
        {
            p.sealer.mutex.lockUncancelable(p.io);
            defer p.sealer.mutex.unlock(p.io);
            p.sealer.cond.broadcast(p.io);
        }
        if (p.thread) |t| t.join();
        p.sealer.close();
        if (p.sealer_thread) |t| t.join();
        if (p.started != null) p.writeStarts(0) catch |err| log.warn("complete: starts not reset: {t}", .{err});
        for (&p.lanes) |*l| l.deinit(p.gpa, p.io);
        for (p.queue.items) |o| p.gpa.free(o.buf);
        p.queue.deinit(p.gpa);
        p.sealer.deinit();
        p.gpa.free(p.dir);
        p.lock.close(p.io);
    }

    /// From the writer, after its commit. Out of memory, the document is dropped (counted):
    /// the writer goes on
    pub fn push(p: *Packer, item: Item) void {
        const buf = p.gpa.alloc(u8, item.key.len + item.gz.len) catch {
            _ = p.stats.dropped.fetchAdd(1, .monotonic);
            return;
        };
        @memcpy(buf[0..item.key.len], item.key);
        @memcpy(buf[item.key.len..], item.gz);
        p.mutex.lockUncancelable(p.io);
        defer p.mutex.unlock(p.io);
        if (p.queue.items.len >= queue_drop) {
            p.gpa.free(buf);
            _ = p.stats.dropped.fetchAdd(1, .monotonic);
            return;
        }
        p.queue.append(p.gpa, .{ .kind = item.kind, .t = item.t, .key_len = item.key.len, .buf = buf }) catch {
            p.gpa.free(buf);
            _ = p.stats.dropped.fetchAdd(1, .monotonic);
            return;
        };
        if (p.queue.items.len == queue_warn) log.warn("complete: {d} documents queued: zstd is behind", .{queue_warn});
        p.cond.broadcast(p.io);
    }

    /// On an error (here or in the sealer) the form is off for a while (backoff), then
    /// starts again from the spool; the crawl goes on meanwhile and pushes queue
    fn run(p: *Packer) void {
        while (true) {
            p.loop() catch |err| {
                const now = Io.Clock.awake.now(p.io).toSeconds();
                p.stats.noteRestart(now);
                const wait_s = backoff(p.restart_s, p.stats.restartsWithin(now, backoff_window_s));
                // A warning: the report line says "complete off" and health.sh alerts
                log.warn("complete: packer stopped: {t}; off, starting again from the spool in {d} s", .{ err, wait_s });
                p.off.store(true, .release);
                p.restart() catch |e| {
                    log.err("complete: no restart: {t}; off until the crawler restarts", .{e});
                    p.spoolRest();
                    return;
                };
                if (!p.pause(wait_s)) {
                    p.spoolRest();
                    return;
                }
                p.off.store(false, .release);
                log.info("complete: on again", .{});
                continue;
            };
            return;
        }
    }

    /// Lanes emptied (their documents are in the spool) and a fresh sealer; queued seal
    /// jobs are dropped, their segments replay
    fn restart(p: *Packer) !void {
        for (&p.lanes) |*l| {
            l.closeSegment(p.io);
            l.clear(p.gpa);
            l.seg_n = 0;
        }
        p.sealer.close();
        if (p.sealer_thread) |t| t.join();
        p.sealer_thread = null;
        p.sealer.deinit();
        p.sealer = .{ .p = p };
        p.sealer_thread = try std.Thread.spawn(.{}, Sealer.run, .{&p.sealer});
    }

    /// wait_s, or until closing; false when closing
    fn pause(p: *Packer, wait_s: i64) bool {
        const until = Io.Clock.awake.now(p.io).toSeconds() + wait_s;
        p.mutex.lockUncancelable(p.io);
        defer p.mutex.unlock(p.io);
        while (!p.closing and Io.Clock.awake.now(p.io).toSeconds() < until) {
            p.cond.waitTimeout(p.io, &p.mutex, .{ .duration = .{ .raw = .fromSeconds(1), .clock = .awake } }) catch {};
        }
        return !p.closing;
    }

    /// Closing while off: the queue to the spool, for the next start
    fn spoolRest(p: *Packer) void {
        p.mutex.lockUncancelable(p.io);
        defer p.mutex.unlock(p.io);
        for (p.queue.items) |o| p.spool(o.kind, o.key(), o.t, o.gz()) catch |err| {
            log.err("complete: {d} queued documents not spooled: {t}", .{ p.queue.items.len, err });
            break;
        };
        for (&p.lanes) |*l| l.closeSegment(p.io);
    }

    /// Whether the form is off (an error, restarting soon), for the report line
    pub fn isOff(p: *Packer) bool {
        if (p.off.load(.acquire)) return true;
        p.sealer.mutex.lockUncancelable(p.io);
        defer p.sealer.mutex.unlock(p.io);
        return p.sealer.dead;
    }

    pub fn queued(p: *Packer) usize {
        p.mutex.lockUncancelable(p.io);
        defer p.mutex.unlock(p.io);
        return p.queue.items.len;
    }

    fn loop(p: *Packer) !void {
        try p.replay();
        var batch: std.ArrayList(Owned) = .empty;
        defer batch.deinit(p.gpa);
        while (true) {
            const closing = blk: {
                p.mutex.lockUncancelable(p.io);
                defer p.mutex.unlock(p.io);
                if (p.queue.items.len == 0 and !p.closing) {
                    p.cond.waitTimeout(p.io, &p.mutex, .{ .duration = .{ .raw = .fromSeconds(30), .clock = .awake } }) catch {};
                }
                std.mem.swap(std.ArrayList(Owned), &batch, &p.queue);
                p.busy = true;
                break :blk p.closing;
            };
            defer {
                for (batch.items) |o| p.gpa.free(o.buf);
                batch.clearRetainingCapacity();
                p.mutex.lockUncancelable(p.io);
                p.busy = false;
                p.mutex.unlock(p.io);
            }
            // The whole batch reaches the spool before anything else: a stop (or a
            // crash) from here on loses none of it
            for (batch.items) |o| try p.spool(o.kind, o.key(), o.t, o.gz());
            // Stopping: the queue left is spooled on the closing round
            p.packBatch(batch.items) catch |err| if (err != error.Stopping) return err;
            p.markHealthy();
            if (closing) {
                for (&p.lanes) |*l| l.closeSegment(p.io);
                return;
            }
        }
    }

    fn packBatch(p: *Packer, batch: []const Owned) !void {
        try p.rollDay(batch);
        for (batch, 0..) |o, i| {
            if (p.stopping.load(.acquire)) return;
            try p.pack(o.kind, o.key(), o.t, o.gz(), batch[i + 1 ..]);
        }
    }

    /// Midnight: partial blocks to the old day, its files sealed. `later` as for seal
    fn rollDay(p: *Packer, later: []const Owned) !void {
        const today = p.clock(p.io);
        // Forward only: a clock stepped back keeps today's files open
        if (today <= p.day) return;
        for (&p.lanes) |*l| try p.seal(l, later);
        try p.sealer.submit(.{ .seal_day = p.day });
        log.info("complete: day {f} done, {d} documents so far, {d} raw", .{
            Date.fromDay(p.day), p.stats.docs.load(.monotonic), p.stats.raw.load(.monotonic),
        });
        p.day = today;
    }

    /// Replay: one record at a time
    fn add(p: *Packer, kind: Kind, key: []const u8, t: i64, gz: []const u8) !void {
        try p.spool(kind, key, t, gz);
        try p.pack(kind, key, t, gz, &.{});
    }

    /// Appends a record to the segment of `kind`'s lane (one is begun when none is open)
    fn spool(p: *Packer, kind: Kind, key: []const u8, t: i64, gz: []const u8) !void {
        const l = &p.lanes[@backingInt(kind)];
        if (l.seg == null) {
            p.next_seg += 1;
            l.seg_n = p.next_seg;
            const path = try p.segPath(p.gpa, kind, l.seg_n);
            defer p.gpa.free(path);
            l.seg = try Io.Dir.cwd().createFile(p.io, path, .{});
            l.seg_len = 0;
        }
        var rec: std.ArrayList(u8) = .empty;
        defer rec.deinit(p.gpa);
        try dayfile.putVar(p.gpa, &rec, @bitCast(t));
        try dayfile.putVar(p.gpa, &rec, key.len);
        try rec.appendSlice(p.gpa, key);
        try dayfile.putVar(p.gpa, &rec, gz.len);
        try l.seg.?.writePositionalAll(p.io, rec.items, l.seg_len);
        try l.seg.?.writePositionalAll(p.io, gz, l.seg_len + rec.items.len);
        l.seg_len += rec.items.len + gz.len;
    }

    /// Adds a spooled document to its lane's block, sealed when full. `later`: the batch's
    /// documents after it, spooled but not packed
    fn pack(p: *Packer, kind: Kind, key: []const u8, t: i64, gz: []const u8, later: []const Owned) !void {
        const l = &p.lanes[@backingInt(kind)];
        try p.addPlain(l, key, t, gz);
        if (l.count() >= p.block_docs or l.plain >= block_plain) try p.seal(l, later);
    }

    fn addPlain(p: *Packer, l: *Lane, key: []const u8, t: i64, gz: []const u8) !void {
        const plain = store.raw.decompress(p.gpa, gz) catch |err| switch (err) {
            error.OutOfMemory => return err,
            else => {
                log.warn("complete: {t} {s} did not gunzip ({t}), left out", .{ l.kind, key, err });
                return;
            },
        };
        defer p.gpa.free(plain);
        _ = p.stats.docs.fetchAdd(1, .monotonic);
        l.plain += plain.len;
        const k = try p.gpa.dupe(u8, key);
        errdefer p.gpa.free(k);
        if (try l.block.add(plain)) {
            try l.packed_docs.append(p.gpa, .{ .key = k, .t = t, .len = plain.len, .hash = XxHash64.hash(0, plain) });
        } else {
            try l.addRaw(p.gpa, k, t, plain);
            _ = p.stats.raw.fetchAdd(1, .monotonic);
        }
    }

    /// The lane's block and raw documents as one seal job; its segment goes once the
    /// job's frames are on disk, so `later` (spooled there, not in this block) are
    /// spooled again into the next segment first
    fn seal(p: *Packer, l: *Lane, later: []const Owned) !void {
        // Nothing packed: the open segment (if any) carries on
        if (l.count() == 0) return;
        l.closeSegment(p.io);
        const gpa = p.gpa;
        var job: Job = .{ .frames = .{ .kind = l.kind, .day = p.day } };
        errdefer job.deinit(gpa);
        if (l.seg_n != 0) job.frames.segment = try p.segPath(gpa, l.kind, l.seg_n);
        l.seg_n = 0;
        for (later) |o| if (o.kind == l.kind) try p.spool(o.kind, o.key(), o.t, o.gz());
        if (l.packed_docs.items.len > 0) {
            var block: std.ArrayList(u8) = .empty;
            defer block.deinit(gpa);
            try l.block.finish(&block);
            if (!try check(gpa, block.items, l.packed_docs.items)) {
                try p.fallback(l, job.frames.segment, &block);
            }
            if (l.packed_docs.items.len > 0) {
                var plain: std.ArrayList(u8) = .empty;
                errdefer plain.deinit(gpa);
                try dayfile.keys(gpa, &plain, try l.docList(gpa));
                try plain.appendSlice(gpa, block.items);
                job.frames.packed_plain = try plain.toOwnedSlice(gpa);
            }
        }
        if (l.raws.items.len > 0) {
            var plain: std.ArrayList(u8) = .empty;
            errdefer plain.deinit(gpa);
            try dayfile.keys(gpa, &plain, l.raws.items);
            try dayfile.rawBody(gpa, &plain, l.raws.items);
            job.frames.raw_plain = try plain.toOwnedSlice(gpa);
        }
        _ = p.stats.frames.fetchAdd(@as(u64, @intFromBool(job.frames.packed_plain != null)) + @intFromBool(job.frames.raw_plain != null), .monotonic);
        l.clear(gpa);
        try p.sealer.submit(job);
    }

    /// The block failed its check: each document is read back from the segment and
    /// tried alone; those that fail go raw, the rest are packed again. A block that still
    /// fails goes raw whole. `block` is replaced by the new block
    fn fallback(p: *Packer, l: *Lane, segment: ?[]const u8, block: *std.ArrayList(u8)) !void {
        const gpa = p.gpa;
        const n = l.packed_docs.items.len;
        log.warn("complete: a {t} block of {d} failed its check, trying each document", .{ l.kind, n });
        // Keys stay owned by packed_docs until the end: raws added here lend them, so on
        // an error they go again without their keys (Lane.clear frees each key once)
        const raws_before = l.raws.items.len;
        errdefer {
            for (l.raws.items[raws_before..]) |d| gpa.free(d.bytes);
            l.raws.shrinkRetainingCapacity(raws_before);
        }
        var arena_state: std.heap.ArenaAllocator = .init(gpa);
        defer arena_state.deinit();
        const arena = arena_state.allocator();
        const records = try readSegment(arena, p.io, segment orelse return error.NoSegment);
        var good: std.ArrayList(Meta) = .empty;
        defer good.deinit(gpa);
        var bodies: std.ArrayList([]const u8) = .empty;
        var one: jsonpack.Block = .init(gpa);
        defer one.deinit();
        var buf: std.ArrayList(u8) = .empty;
        defer buf.deinit(gpa);
        for (l.packed_docs.items) |m| {
            const plain = for (records) |r| {
                if (std.mem.eql(u8, r.key, m.key) and r.t == m.t) break try store.raw.decompress(arena, r.gz);
            } else return error.NotInSegment;
            buf.clearRetainingCapacity();
            _ = try one.add(plain);
            try one.finish(&buf);
            if (try check(gpa, buf.items, &.{m})) {
                try good.append(gpa, m);
                try bodies.append(arena, plain);
            } else {
                try l.addRaw(gpa, m.key, m.t, plain);
                _ = p.stats.raw.fetchAdd(1, .monotonic);
            }
        }
        block.clearRetainingCapacity();
        l.block.reset();
        for (bodies.items) |b| _ = try l.block.add(b);
        try l.block.finish(block);
        if (good.items.len > 0 and !try check(gpa, block.items, good.items)) {
            log.warn("complete: the repacked {t} block failed too: all raw", .{l.kind});
            for (good.items, bodies.items) |m, b| try l.addRaw(gpa, m.key, m.t, b);
            _ = p.stats.raw.fetchAdd(good.items.len, .monotonic);
            good.clearRetainingCapacity();
        }
        // Keys now owned by raws or still by good: packed_docs only lends them
        l.packed_docs.clearRetainingCapacity();
        l.packed_docs.appendSliceAssumeCapacity(good.items);
        log.warn("complete: {d} of {d} kept raw", .{ n - good.items.len, n });
    }

    /// Every spool segment left by an earlier run, in order, through `add`; each deleted
    /// once its documents are in a newer segment
    fn replay(p: *Packer) !void {
        const gpa = p.gpa;
        const segs = try p.segments(gpa);
        defer {
            for (segs) |s| gpa.free(s.name);
            gpa.free(segs);
        }
        const spool_dir = try std.fs.path.join(gpa, &.{ p.dir, "spool" });
        defer gpa.free(spool_dir);
        var docs: usize = 0;
        for (segs) |s| {
            if (s.n > p.next_seg) p.next_seg = s.n;
            var arena_state: std.heap.ArenaAllocator = .init(gpa);
            defer arena_state.deinit();
            const path = try std.fs.path.join(arena_state.allocator(), &.{ spool_dir, s.name });
            const records = try readSegment(arena_state.allocator(), p.io, path);
            for (records) |r| try p.add(s.kind, r.key, r.t, r.gz);
            docs += records.len;
            // A seal during the loop may have cut this segment's lane; the records are
            // in the newer segment either way
            for (&p.lanes) |*l| if (l.seg) |f| f.sync(p.io) catch {};
            try Io.Dir.cwd().deleteFile(p.io, path);
        }
        if (segs.len > 0) log.info("complete: replayed {d} documents from {d} spool segments", .{ docs, segs.len });
    }

    fn readStarts(p: *Packer) u64 {
        var buf: [20]u8 = undefined;
        const dir = Io.Dir.cwd().openDir(p.io, p.dir, .{}) catch return 0;
        defer dir.close(p.io);
        const got = dir.readFile(p.io, "starts", &buf) catch return 0;
        return std.fmt.parseInt(u64, std.mem.trim(u8, got, " \n"), 10) catch 0;
    }

    /// No fsync: a count lost to a power cut only delays the quarantine
    fn writeStarts(p: *Packer, n: u64) !void {
        var buf: [21]u8 = undefined;
        var dir = try Io.Dir.cwd().openDir(p.io, p.dir, .{});
        defer dir.close(p.io);
        try dir.writeFile(p.io, .{ .sub_path = "starts", .data = try std.fmt.bufPrint(&buf, "{d}\n", .{n}) });
    }

    /// After healthy_s this run counts as clean, so the next start's count begins again
    fn markHealthy(p: *Packer) void {
        const t = p.started orelse return;
        if (Io.Clock.awake.now(p.io).toSeconds() - t < healthy_s) return;
        p.writeStarts(0) catch |err| log.warn("complete: starts not reset: {t}", .{err});
        p.started = null;
    }

    /// Every spool segment to spool/quarantine (kept for a look), named apart by time
    fn quarantine(p: *Packer, unclean: u64) !void {
        const gpa = p.gpa;
        const io = p.io;
        const segs = try p.segments(gpa);
        defer {
            for (segs) |s| gpa.free(s.name);
            gpa.free(segs);
        }
        const spool_dir = try std.fs.path.join(gpa, &.{ p.dir, "spool" });
        defer gpa.free(spool_dir);
        var dir = try Io.Dir.cwd().openDir(io, spool_dir, .{});
        defer dir.close(io);
        try dir.createDirPath(io, "quarantine");
        const now = Io.Clock.real.now(io).toSeconds();
        for (segs) |s| {
            const to = try std.fmt.allocPrint(gpa, "quarantine/{s}.{d}", .{ s.name, now });
            defer gpa.free(to);
            try dir.renamePreserve(s.name, dir, to, io);
        }
        log.warn("complete: {d} unclean runs in a row: {d} spool segments moved to spool/quarantine, their documents left out", .{ unclean, segs.len });
    }

    const Seg = struct { kind: Kind, n: u64, name: []u8 };

    fn segments(p: *Packer, gpa: Allocator) ![]Seg {
        return listSegments(gpa, p.io, p.dir);
    }

    fn listSegments(gpa: Allocator, io: Io, complete_dir: []const u8) ![]Seg {
        const spool_dir = try std.fs.path.join(gpa, &.{ complete_dir, "spool" });
        defer gpa.free(spool_dir);
        var dir = try Io.Dir.cwd().openDir(io, spool_dir, .{ .iterate = true });
        defer dir.close(io);
        var list: std.ArrayList(Seg) = .empty;
        errdefer {
            for (list.items) |s| gpa.free(s.name);
            list.deinit(gpa);
        }
        var it = dir.iterate();
        while (try it.next(io)) |e| {
            if (e.kind != .file) continue;
            const dot = std.mem.indexOfScalar(u8, e.name, '.') orelse continue;
            const kind = std.meta.stringToEnum(Kind, e.name[0..dot]) orelse continue;
            const n = std.fmt.parseInt(u64, e.name[dot + 1 ..], 10) catch continue;
            try list.append(gpa, .{ .kind = kind, .n = n, .name = try gpa.dupe(u8, e.name) });
        }
        std.mem.sort(Seg, list.items, {}, struct {
            fn lt(_: void, a: Seg, b: Seg) bool {
                return a.n < b.n;
            }
        }.lt);
        return list.toOwnedSlice(gpa);
    }

    fn lastSegment(p: *Packer) !u64 {
        const segs = try p.segments(p.gpa);
        defer {
            for (segs) |s| p.gpa.free(s.name);
            p.gpa.free(segs);
        }
        return if (segs.len > 0) segs[segs.len - 1].n else 0;
    }

    fn segPath(p: *Packer, gpa: Allocator, kind: Kind, n: u64) ![]u8 {
        return std.fmt.allocPrint(gpa, "{s}/spool/{t}.{d}", .{ p.dir, kind, n });
    }
};

/// The pause before a restart: base doubled for each restart in the window but this one
fn backoff(base: i64, recent: usize) i64 {
    const doublings: u6 = @intCast(@min(recent -| 1, 12));
    return @min(base << doublings, max_restart_s);
}

fn realDay(io: Io) i64 {
    return @divFloor(Io.Clock.real.now(io).toSeconds(), std.time.s_per_day);
}

const Meta = struct { key: []u8, t: i64, len: usize, hash: u64 };

const Lane = struct {
    kind: Kind,
    block: jsonpack.Block,
    packed_docs: std.ArrayList(Meta) = .empty,
    /// Documents kept as they are; keys and bytes owned
    raws: std.ArrayList(dayfile.Doc) = .empty,
    plain: u64 = 0,
    seg: ?Io.File = null,
    seg_len: u64 = 0,
    /// The segment holding this block's documents; 0: none (closed by a seal)
    seg_n: u64 = 0,
    docs_buf: std.ArrayList(dayfile.Doc) = .empty,

    fn count(l: *const Lane) usize {
        return l.packed_docs.items.len + l.raws.items.len;
    }

    fn addRaw(l: *Lane, gpa: Allocator, key: []u8, t: i64, plain: []const u8) !void {
        const bytes = try gpa.dupe(u8, plain);
        errdefer gpa.free(bytes);
        try l.raws.append(gpa, .{ .key = key, .t = t, .bytes = bytes });
    }

    fn docList(l: *Lane, gpa: Allocator) ![]const dayfile.Doc {
        l.docs_buf.clearRetainingCapacity();
        for (l.packed_docs.items) |m| try l.docs_buf.append(gpa, .{ .key = m.key, .t = m.t, .bytes = "" });
        return l.docs_buf.items;
    }

    fn closeSegment(l: *Lane, io: Io) void {
        if (l.seg) |f| f.close(io);
        l.seg = null;
    }

    fn clear(l: *Lane, gpa: Allocator) void {
        for (l.packed_docs.items) |m| gpa.free(m.key);
        for (l.raws.items) |d| {
            gpa.free(d.key);
            gpa.free(d.bytes);
        }
        l.packed_docs.clearRetainingCapacity();
        l.raws.clearRetainingCapacity();
        l.block.reset();
        l.plain = 0;
    }

    fn deinit(l: *Lane, gpa: Allocator, io: Io) void {
        l.closeSegment(io);
        l.clear(gpa);
        l.packed_docs.deinit(gpa);
        l.raws.deinit(gpa);
        l.docs_buf.deinit(gpa);
        l.block.deinit();
    }
};

/// Whether `block` decodes to documents of the lengths and hashes in `metas`
fn check(gpa: Allocator, block: []const u8, metas: []const Meta) !bool {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(gpa);
    const ends = jsonpack.decode(gpa, block, &out) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => return false,
    };
    defer gpa.free(ends);
    if (ends.len != metas.len) return false;
    var start: usize = 0;
    for (metas, ends) |m, end| {
        const doc = out.items[start..end];
        if (doc.len != m.len or XxHash64.hash(0, doc) != m.hash) return false;
        start = end;
    }
    return true;
}

pub const Record = struct { key: []const u8, t: i64, gz: []const u8 };

/// A spool segment's records, in `arena`; a torn last record (no fsync) is dropped
fn readSegment(arena: Allocator, io: Io, path: []const u8) ![]Record {
    const bytes = try Io.Dir.cwd().readFileAlloc(io, path, arena, .unlimited);
    var r: dayfile.Reader = .{ .b = bytes };
    var list: std.ArrayList(Record) = .empty;
    while (!r.done()) {
        const at = r.i;
        const rec = readRecord(&r) catch {
            log.warn("complete: {s}: {d} bytes cut at its end dropped", .{ path, bytes.len - at });
            break;
        };
        try list.append(arena, rec);
    }
    return list.items;
}

pub fn readRecord(r: *dayfile.Reader) !Record {
    const t: i64 = @bitCast(try r.varint());
    const key = try r.bytes(try r.varint());
    const gz = try r.bytes(try r.varint());
    return .{ .key = key, .t = t, .gz = gz };
}

const Job = union(enum) {
    frames: struct {
        kind: Kind,
        day: i64,
        packed_plain: ?[]u8 = null,
        raw_plain: ?[]u8 = null,
        segment: ?[]u8 = null,
    },
    /// Every file of this day sealed
    seal_day: i64,

    fn deinit(j: *Job, gpa: Allocator) void {
        switch (j.*) {
            .frames => |f| {
                if (f.packed_plain) |b| gpa.free(b);
                if (f.raw_plain) |b| gpa.free(b);
                if (f.segment) |s| gpa.free(s);
            },
            .seal_day => {},
        }
    }
};

/// Owns the day files: zstd, read back, append, fsync, seal
const Sealer = struct {
    p: *Packer,
    mutex: Io.Mutex = .init,
    cond: Io.Condition = .init,
    jobs: std.ArrayList(Job) = .empty,
    closing: bool = false,
    dead: bool = false,
    busy: bool = false,
    open: [3]?Open = @splat(null),
    /// Tests: the next job fails
    fail_once: bool = false,

    const Open = struct { day: i64, file: Io.File, len: u64 };

    fn submit(s: *Sealer, job: Job) !void {
        const io = s.p.io;
        s.mutex.lockUncancelable(io);
        defer s.mutex.unlock(io);
        while (s.jobs.items.len >= max_jobs and !s.dead and !s.p.stopping.load(.acquire)) s.cond.waitUncancelable(io, &s.mutex);
        if (s.dead) return error.SealerStopped;
        // The job's documents stay in its segment, replayed on the next start
        if (s.jobs.items.len >= max_jobs) return error.Stopping;
        try s.jobs.append(s.p.gpa, job);
        s.cond.broadcast(io);
    }

    /// Finishes the job in hand; the queued ones are dropped, their segments replay
    fn close(s: *Sealer) void {
        s.mutex.lockUncancelable(s.p.io);
        defer s.mutex.unlock(s.p.io);
        s.closing = true;
        s.cond.broadcast(s.p.io);
    }

    fn deinit(s: *Sealer) void {
        for (s.jobs.items) |*j| j.deinit(s.p.gpa);
        s.jobs.deinit(s.p.gpa);
        for (&s.open) |*o| if (o.*) |f| {
            f.file.close(s.p.io);
            o.* = null;
        };
    }

    fn run(s: *Sealer) void {
        const io = s.p.io;
        while (true) {
            var job = blk: {
                s.mutex.lockUncancelable(io);
                defer s.mutex.unlock(io);
                while (s.jobs.items.len == 0 and !s.closing) s.cond.waitUncancelable(io, &s.mutex);
                if (s.closing) return;
                const j = s.jobs.orderedRemove(0);
                s.busy = true;
                s.cond.broadcast(io);
                break :blk j;
            };
            defer {
                job.deinit(s.p.gpa);
                s.mutex.lockUncancelable(io);
                s.busy = false;
                s.mutex.unlock(io);
            }
            s.do(job) catch |err| {
                log.warn("complete: sealer stopped: {t}; the packer starts both again", .{err});
                s.mutex.lockUncancelable(io);
                defer s.mutex.unlock(io);
                s.dead = true;
                s.cond.broadcast(io);
                return;
            };
        }
    }

    fn do(s: *Sealer, job: Job) !void {
        if (s.fail_once) {
            s.fail_once = false;
            return error.TestFailure;
        }
        switch (job) {
            .seal_day => |day| for (std.enums.values(Kind)) |k| try s.sealFile(k, day),
            .frames => |f| {
                const o = try s.file(f.kind, f.day);
                var end = o.len;
                if (f.packed_plain) |plain| {
                    end += try s.appendFrame(o.file, end, .block, plain);
                    // Only the last frame may be torn by a crash: one with a whole frame
                    // after it is damage (dayfile.recover)
                    if (f.raw_plain != null) try o.file.sync(s.p.io);
                }
                if (f.raw_plain) |plain| end += try s.appendFrame(o.file, end, .raw, plain);
                try o.file.sync(s.p.io);
                o.len = end;
                if (f.segment) |seg| try Io.Dir.cwd().deleteFile(s.p.io, seg);
            },
        }
    }

    /// The open file of `kind` for `day`, opened (and its torn tail cut) when needed
    fn file(s: *Sealer, kind: Kind, day: i64) !*Open {
        const slot = &s.open[@backingInt(kind)];
        if (slot.*) |o| {
            if (o.day == day) return &slot.*.?;
            try s.sealFile(kind, o.day);
        }
        const part = try s.path(kind, day, true);
        defer s.p.gpa.free(part);
        const f = try Io.Dir.cwd().createFile(s.p.io, part, .{ .read = true, .truncate = false });
        errdefer f.close(s.p.io);
        const len = try s.recover(f, part);
        slot.* = .{ .day = day, .file = f, .len = len };
        return &slot.*.?;
    }

    /// `kind`'s file of `day` renamed to its sealed name, if there is one
    fn sealFile(s: *Sealer, kind: Kind, day: i64) !void {
        const io = s.p.io;
        const gpa = s.p.gpa;
        const slot = &s.open[@backingInt(kind)];
        if (slot.*) |o| if (o.day == day) {
            o.file.close(io);
            slot.* = null;
        };
        const part = try s.path(kind, day, true);
        defer gpa.free(part);
        const sealed = try s.path(kind, day, false);
        defer gpa.free(sealed);
        const cwd = Io.Dir.cwd();
        {
            const f = cwd.openFile(io, part, .{ .mode = .read_write }) catch |err| switch (err) {
                error.FileNotFound => return,
                else => return err,
            };
            defer f.close(io);
            _ = try s.recover(f, part);
            try f.sync(io);
        }
        cwd.renamePreserve(part, cwd, sealed, io) catch |err| switch (err) {
            // Never meant to happen (start and rollDay keep to days after the sealed
            // ones): both kept, the newer aside for a hand merge
            error.PathAlreadyExists => {
                const aside = try std.fmt.allocPrint(gpa, "{s}.clash-{d}", .{ sealed, Io.Clock.real.now(io).toSeconds() });
                defer gpa.free(aside);
                try cwd.rename(part, cwd, aside, io);
                log.err("complete: {s} was sealed already: the new one is {s}", .{ std.fs.path.basename(sealed), std.fs.path.basename(aside) });
            },
            else => return err,
        };
        try archive.syncPath(io, s.p.dir, .directory);
        log.info("complete: sealed {s}", .{std.fs.path.basename(sealed)});
    }

    fn recover(s: *Sealer, f: Io.File, name: []const u8) !u64 {
        return dayfile.recover(s.p.gpa, s.p.io, f) catch |err| {
            if (err == error.DamagedFrame) log.err("complete: {s} has a damaged frame with whole frames after it: left as it is; the form restarts, pausing longer each time, until it is mended", .{name});
            return err;
        };
    }

    /// The newest day with a sealed file
    fn newestSealed(s: *Sealer) !?i64 {
        const io = s.p.io;
        var dir = try Io.Dir.cwd().openDir(io, s.p.dir, .{ .iterate = true });
        defer dir.close(io);
        var it = dir.iterate();
        var newest: ?i64 = null;
        while (try it.next(io)) |e| {
            if (e.kind != .file or !std.mem.endsWith(u8, e.name, ".cfd") or e.name.len < 10) continue;
            const day = (Date.parse(e.name[0..10]) orelse continue).toDay();
            if (newest == null or day > newest.?) newest = day;
        }
        return newest;
    }

    /// At start: `.part` files of days before `today` (the crawler was down at midnight)
    fn sealOlder(s: *Sealer, today: i64) !void {
        const io = s.p.io;
        var dir = try Io.Dir.cwd().openDir(io, s.p.dir, .{ .iterate = true });
        defer dir.close(io);
        var it = dir.iterate();
        var stale: std.ArrayList(struct { kind: Kind, day: i64 }) = .empty;
        defer stale.deinit(s.p.gpa);
        while (try it.next(io)) |e| {
            const name = e.name;
            if (e.kind != .file or !std.mem.endsWith(u8, name, ".cfd.part") or name.len < 11) continue;
            const day = (Date.parse(name[0..10]) orelse continue).toDay();
            const kind_s = name[11 .. name.len - ".cfd.part".len];
            const kind = std.meta.stringToEnum(Kind, kind_s) orelse continue;
            if (day < today) try stale.append(s.p.gpa, .{ .kind = kind, .day = day });
        }
        for (stale.items) |x| try s.sealFile(x.kind, x.day);
    }

    /// Bytes appended: the frame's header and zstd payload
    fn appendFrame(s: *Sealer, f: Io.File, at: u64, t: dayfile.Type, plain: []const u8) !u64 {
        const gpa = s.p.gpa;
        const tmp = try std.fmt.allocPrint(gpa, "{s}/frame.zst.tmp", .{s.p.dir});
        defer gpa.free(tmp);
        const zst = try compress(gpa, s.p.io, tmp, plain);
        defer gpa.free(zst);
        const h = dayfile.header(t, zst);
        try f.writePositionalAll(s.p.io, &h, at);
        try f.writePositionalAll(s.p.io, zst, at + h.len);
        _ = s.p.stats.bytes.fetchAdd(h.len + zst.len, .monotonic);
        return h.len + zst.len;
    }

    fn path(s: *Sealer, kind: Kind, day: i64, part: bool) ![]u8 {
        return std.fmt.allocPrint(s.p.gpa, "{s}/{f}.{t}.cfd{s}", .{ s.p.dir, Date.fromDay(day), kind, if (part) ".part" else "" });
    }
};

/// `plain` through `nice zstd -19 -T1` (std has no compressor) via the temp file `tmp`
/// (one per process: the crawler's and a scrub's differ), read back through std's
/// decompressor and compared
pub fn compress(gpa: Allocator, io: Io, tmp: []const u8, plain: []const u8) ![]u8 {
    const cwd = Io.Dir.cwd();
    defer cwd.deleteFile(io, tmp) catch {};
    {
        // systemd's stop signals every process of the service: zstd ignores it and
        // finishes the block in hand while the crawler stops (ignored stays ignored
        // through exec)
        var child = try std.process.spawn(io, .{
            .argv = &.{ "sh", "-c", "trap '' TERM INT; exec nice -n 19 zstd -q -f " ++ zstd_level ++ " -T1 - -o \"$0\"", tmp },
            .stdin = .pipe,
        });
        var ok = false;
        defer if (!ok) child.kill(io);
        var wbuf: [64 * 1024]u8 = undefined;
        var fw = child.stdin.?.writerStreaming(io, &wbuf);
        try fw.interface.writeAll(plain);
        try fw.interface.flush();
        child.stdin.?.close(io);
        child.stdin = null;
        ok = true;
        if (!(try child.wait(io)).success()) return error.ZstdFailed;
    }
    const zst = try cwd.readFileAlloc(io, tmp, gpa, .limited(dayfile.max_payload));
    errdefer gpa.free(zst);
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const back = try dayfile.inflate(gpa, arena_state.allocator(), zst);
    if (!std.mem.eql(u8, back, plain)) return error.ZstdRoundTrip;
    return zst;
}

pub var test_day: i64 = 20_000;

pub fn testClock(_: Io) i64 {
    return test_day;
}

/// Until both threads have nothing left to do
pub fn settle(p: *Packer) !void {
    for (0..2000) |_| {
        const idle = blk: {
            p.mutex.lockUncancelable(p.io);
            defer p.mutex.unlock(p.io);
            if (p.queue.items.len > 0 or p.busy) break :blk false;
            p.sealer.mutex.lockUncancelable(p.io);
            defer p.sealer.mutex.unlock(p.io);
            break :blk p.sealer.jobs.items.len == 0 and !p.sealer.busy;
        };
        if (idle) return;
        try p.io.sleep(.fromMilliseconds(5), .awake);
    }
    return error.Timeout;
}

test "day files hold every document byte for byte through a crash, a replay and midnight" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const data = try arena.print(".zig-cache/tmp/{s}", .{&tmp.sub_path});
    test_day = 20_000;
    // The torn spool record below warns
    const saved = std.testing.log_level;
    defer std.testing.log_level = saved;
    std.testing.log_level = .err;

    const match_json = @embedFile("testdata/match.json");
    const summaries = [_][]const u8{
        std.mem.trimEnd(u8, match_json, "\n"),
        " {\"not\":\"compact\"}",
        "{\"d\":[1],\"a\":[],\"f\":[1]}",
    };
    // The fixtures end in a newline, which Riot's bodies don't
    const timeline = std.mem.trimEnd(u8, try store.raw.decompress(arena, @embedFile("testdata/timeline.json.gz")), "\n");
    const timeline_gz = try store.raw.compress(arena, timeline);
    const mastery = std.mem.trimEnd(u8, try store.raw.decompress(arena, @embedFile("testdata/mastery.json.gz")), "\n");
    const mastery_gz = try store.raw.compress(arena, mastery);
    var p: Packer = try .init(gpa, io, data);
    p.clock = testClock;
    p.block_docs = 2;
    try p.start();
    for (summaries, 0..) |doc, i| {
        const gz = try store.raw.compress(arena, doc);
        p.push(.{ .kind = .summary, .key = try arena.print("EUW1_{d}", .{i}), .t = @intCast(100 + i), .gz = gz });
    }
    p.push(.{ .kind = .timeline, .key = "EUW1_0", .t = 200, .gz = timeline_gz });
    p.push(.{ .kind = .mastery, .key = "EUW1:abc", .t = 300, .gz = mastery_gz });
    try settle(&p);
    try std.testing.expectEqual(5, p.stats.docs.load(.monotonic));
    try std.testing.expectEqual(1, p.stats.raw.load(.monotonic));
    p.close();

    // A crash mid-append left a torn frame, and one spool segment a torn record
    const day0 = try arena.print("{s}/complete/{f}", .{ data, Date.fromDay(20_000) });
    {
        const f = try Io.Dir.cwd().openFile(io, try arena.print("{s}.summary.cfd.part", .{day0}), .{ .mode = .read_write });
        defer f.close(io);
        try f.writePositionalAll(io, "CFD1\x00\xff\xff", try f.length(io));
    }
    var p2: Packer = try .init(gpa, io, data);
    p2.clock = testClock;
    p2.block_docs = 2;
    const segs = try p2.segments(arena);
    try std.testing.expectEqual(3, segs.len);
    {
        const f = try Io.Dir.cwd().openFile(io, try arena.print("{s}/complete/spool/{s}", .{ data, segs[0].name }), .{ .mode = .read_write });
        defer f.close(io);
        try f.writePositionalAll(io, "\x05\x09EUW1", try f.length(io));
    }
    try p2.start();
    test_day += 1;
    p2.push(.{ .kind = .mastery, .key = "EUW1:next", .t = 400, .gz = mastery_gz });
    try settle(&p2);
    p2.close();

    const got = try dayfile.readAll(gpa, arena, io, try arena.print("{s}.summary.cfd", .{day0}));
    try std.testing.expectEqual(summaries.len, got.len);
    for (got, summaries, 0..) |d, want, i| {
        try std.testing.expectEqualStrings(try arena.print("EUW1_{d}", .{i}), d.key);
        try std.testing.expectEqual(@as(i64, @intCast(100 + i)), d.t);
        try std.testing.expectEqualStrings(want, d.bytes);
    }
    const tl = try dayfile.readAll(gpa, arena, io, try arena.print("{s}.timeline.cfd", .{day0}));
    try std.testing.expectEqual(1, tl.len);
    try std.testing.expectEqualStrings(timeline, tl[0].bytes);
    const ms = try dayfile.readAll(gpa, arena, io, try arena.print("{s}.mastery.cfd", .{day0}));
    try std.testing.expectEqual(1, ms.len);
    try std.testing.expectEqualStrings("EUW1:abc", ms[0].key);
    try std.testing.expectEqualStrings(mastery, ms[0].bytes);
    // The next day's document waits in the spool, its day file not begun
    const left = try Packer.listSegments(arena, io, try arena.print("{s}/complete", .{data}));
    try std.testing.expectEqual(1, left.len);
    try std.testing.expectEqual(Kind.mastery, left[0].kind);
}

test "a block that fails its check keeps the failing document raw and packs the rest" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const data = try arena.print(".zig-cache/tmp/{s}", .{&tmp.sub_path});
    const saved = std.testing.log_level;
    defer std.testing.log_level = saved;
    std.testing.log_level = .err;
    test_day = 20_000;

    const docs = [_][]const u8{ "{\"a\":[1,2]}", "{\"a\":[3]}", "{\"b\":\"x\"}" };
    var p: Packer = try .init(gpa, io, data);
    p.clock = testClock;
    try p.start();
    for (docs, 0..) |doc, i| {
        p.push(.{ .kind = .summary, .key = try arena.print("K{d}", .{i}), .t = 1, .gz = try store.raw.compress(arena, doc) });
    }
    try settle(&p);
    // As if the codec lost the middle document: its recorded hash no longer matches
    {
        p.mutex.lockUncancelable(io);
        defer p.mutex.unlock(io);
        p.lanes[@backingInt(Kind.summary)].packed_docs.items[1].hash +%= 1;
    }
    test_day += 1;
    p.push(.{ .kind = .mastery, .key = "wake", .t = 1, .gz = try store.raw.compress(arena, "[]") });
    try settle(&p);
    try std.testing.expectEqual(1, p.stats.raw.load(.monotonic));
    p.close();

    const got = try dayfile.readAll(gpa, arena, io, try arena.print("{s}/complete/{f}.summary.cfd", .{ data, Date.fromDay(20_000) }));
    try std.testing.expectEqual(3, got.len);
    // The packed frame first, then the raw one
    for (got, [_]usize{ 0, 2, 1 }) |d, i| {
        try std.testing.expectEqualStrings(try arena.print("K{d}", .{i}), d.key);
        try std.testing.expectEqualStrings(docs[i], d.bytes);
    }
}

test "a stop mid-queue leaves every pushed document in a day file or the spool" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const data = try arena.print(".zig-cache/tmp/{s}", .{&tmp.sub_path});
    test_day = 20_000;

    var p: Packer = try .init(gpa, io, data);
    p.clock = testClock;
    p.block_docs = 2;
    try p.start();
    const n = 300;
    const pad: [64]u8 = @splat('x');
    for (0..n) |i| {
        const kind: Kind = @fromBackingInt(@intCast(i % 3));
        const doc = try arena.print("{{\"n\":{d},\"s\":\"{s}\"}}", .{ i, &pad });
        p.push(.{ .kind = kind, .key = try arena.print("K{d}", .{i}), .t = @intCast(i), .gz = try store.raw.compress(arena, doc) });
        if (i == n / 2) test_day += 1;
    }
    p.close();

    var seen: std.StringHashMapUnmanaged(void) = .empty;
    const dir_path = try arena.print("{s}/complete", .{data});
    var dir = try Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true });
    defer dir.close(io);
    var it = dir.iterate();
    while (try it.next(io)) |e| {
        if (e.kind != .file or !std.mem.endsWith(u8, e.name, ".cfd") and !std.mem.endsWith(u8, e.name, ".cfd.part")) continue;
        for (try dayfile.readAll(gpa, arena, io, try arena.print("{s}/{s}", .{ dir_path, e.name }))) |d| try seen.put(arena, d.key, {});
    }
    for (try Packer.listSegments(arena, io, dir_path)) |s| {
        for (try readSegment(arena, io, try arena.print("{s}/spool/{s}", .{ dir_path, s.name }))) |r| try seen.put(arena, r.key, {});
    }
    for (0..n) |i| try std.testing.expect(seen.contains(try arena.print("K{d}", .{i})));
}

test "after a sealer error the form is off, then starts again from the spool" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const data = try arena.print(".zig-cache/tmp/{s}", .{&tmp.sub_path});
    const saved = std.testing.log_level;
    defer std.testing.log_level = saved;
    std.testing.log_level = .err;
    test_day = 20_000;

    var p: Packer = try .init(gpa, io, data);
    p.clock = testClock;
    p.block_docs = 2;
    p.restart_s = 0;
    try p.start();
    p.sealer.fail_once = true;
    for (0..6) |i| p.push(.{ .kind = .summary, .key = try arena.print("K{d}", .{i}), .t = @intCast(i), .gz = try store.raw.compress(arena, "[1]") });
    try settle(&p);
    test_day += 1;
    p.push(.{ .kind = .mastery, .key = "wake", .t = 9, .gz = try store.raw.compress(arena, "[]") });
    try settle(&p);
    try std.testing.expect(!p.isOff());
    p.close();
    const got = try dayfile.readAll(gpa, arena, io, try arena.print("{s}/complete/{f}.summary.cfd", .{ data, Date.fromDay(20_000) }));
    var seen: std.StringHashMapUnmanaged(void) = .empty;
    for (got) |d| try seen.put(arena, d.key, {});
    for (0..6) |i| try std.testing.expect(seen.contains(try arena.print("K{d}", .{i})));
}

test "a lasting error pauses longer before each restart, up to an hour" {
    var s: Stats = .{};
    const now = 100_000;
    s.noteRestart(now - backoff_window_s - 1);
    s.noteRestart(now);
    try std.testing.expectEqual(restart_s, backoff(restart_s, s.restartsWithin(now, backoff_window_s)));
    s.noteRestart(now + 70);
    s.noteRestart(now + 200);
    try std.testing.expectEqual(4 * restart_s, backoff(restart_s, s.restartsWithin(now + 200, backoff_window_s)));
    for (0..8) |i| s.noteRestart(now + 300 + @as(i64, @intCast(i)));
    try std.testing.expectEqual(max_restart_s, backoff(restart_s, s.restartsWithin(now + 400, backoff_window_s)));
    try std.testing.expectEqual(0, backoff(0, 8));
}

test "a clock stepped back never reopens a sealed day" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const data = try arena.print(".zig-cache/tmp/{s}", .{&tmp.sub_path});
    const gz = try store.raw.compress(arena, "[1]");
    const sealed = try arena.print("{s}/complete/{f}.summary.cfd", .{ data, Date.fromDay(20_000) });

    // Day 20,000 sealed, then the clock steps back to it mid-run: the next day stays open
    test_day = 20_000;
    var p: Packer = try .init(gpa, io, data);
    p.clock = testClock;
    p.block_docs = 1;
    try p.start();
    p.push(.{ .kind = .summary, .key = "A", .t = 1, .gz = gz });
    try settle(&p);
    test_day += 1;
    p.push(.{ .kind = .summary, .key = "B", .t = 2, .gz = gz });
    try settle(&p);
    test_day -= 1;
    p.push(.{ .kind = .summary, .key = "C", .t = 3, .gz = gz });
    try settle(&p);
    p.close();
    // A restart with the clock still behind
    var p2: Packer = try .init(gpa, io, data);
    p2.clock = testClock;
    p2.block_docs = 1;
    try p2.start();
    p2.push(.{ .kind = .summary, .key = "D", .t = 4, .gz = gz });
    try settle(&p2);
    p2.close();

    const old = try dayfile.readAll(gpa, arena, io, sealed);
    try std.testing.expectEqual(1, old.len);
    try std.testing.expectEqualStrings("A", old[0].key);
    const next = try dayfile.readAll(gpa, arena, io, try arena.print("{s}/complete/{f}.summary.cfd.part", .{ data, Date.fromDay(20_001) }));
    try std.testing.expectEqual(3, next.len);
}

test "a second packer on the same data is refused; after unclean runs the spool is set aside" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const data = try arena.print(".zig-cache/tmp/{s}", .{&tmp.sub_path});
    const saved = std.testing.log_level;
    defer std.testing.log_level = saved;
    std.testing.log_level = .err;
    test_day = 20_000;

    var p: Packer = try .init(gpa, io, data);
    try std.testing.expectError(error.Locked, Packer.init(gpa, io, data));
    // One run short of the limit: the spool replays as usual
    try tmp.dir.writeFile(io, .{ .sub_path = "complete/starts", .data = "2\n" });
    p.clock = testClock;
    try p.start();
    try std.testing.expectEqualStrings("3\n", try tmp.dir.readFileAlloc(io, "complete/starts", arena, .limited(64)));
    try settle(&p);
    p.close();
    try std.testing.expectEqualStrings("0\n", try tmp.dir.readFileAlloc(io, "complete/starts", arena, .limited(64)));

    // Three unclean runs in a row (none closed nor ran healthy_s): segments go aside
    try tmp.dir.writeFile(io, .{ .sub_path = "complete/starts", .data = "3\n" });
    try tmp.dir.writeFile(io, .{ .sub_path = "complete/spool/summary.3", .data = "poison" });
    var p2: Packer = try .init(gpa, io, data);
    p2.clock = testClock;
    try p2.start();
    try std.testing.expectEqualStrings("1\n", try tmp.dir.readFileAlloc(io, "complete/starts", arena, .limited(64)));
    try settle(&p2);
    p2.close();
    try std.testing.expectEqual(0, (try Packer.listSegments(arena, io, try arena.print("{s}/complete", .{data}))).len);
    var q = try tmp.dir.openDir(io, "complete/spool/quarantine", .{ .iterate = true });
    defer q.close(io);
    var it = q.iterate();
    const e = (try it.next(io)).?;
    try std.testing.expect(std.mem.startsWith(u8, e.name, "summary.3."));
    try std.testing.expectEqualStrings("poison", try q.readFileAlloc(io, e.name, arena, .limited(64)));
}
