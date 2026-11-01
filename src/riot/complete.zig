//! The complete form writer (docs/plan/ops.md "Complete form"): every summary, timeline
//! and mastery body the crawler stores goes byte-exact into a day file,
//! <data>/complete/YYYY-MM-DD.<kind>.cfd (store/dayfile.zig), `.cfd.part` while that day
//! is open. A sealed file is never opened for write again.
//!
//! The writer hands each committed document to the Packer thread, which appends it to a
//! spool segment (complete/spool/<kind>.<n>, gzip as the raw store has it, no fsync) and
//! a jsonpack block in memory. At block_docs documents (or block_plain bytes) the block is
//! decoded again and each document compared (length and xxhash64 kept per add); one that
//! does not come back is tried alone and kept raw if it fails, the rest repacked. The
//! Sealer thread then runs `zstd -19`, reads the result back through std's decompressor,
//! appends the frame, fsyncs and deletes the segment.
//!
//! Crash safety: a torn frame at a file's end is cut on start (dayfile.recover); spool
//! segments left behind are replayed through the same path, so a crash loses at most the
//! documents queued but not yet spooled. A crash between a frame's fsync and its
//! segment's delete stores those documents twice: readers keep one per key.
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
const zstd_level = "-19";

/// One stored document, as the writer hands it over (copied)
pub const Item = struct { kind: Kind, key: []const u8, t: i64, gz: []const u8 };

pub const Stats = struct {
    docs: std.atomic.Value(u64) = .init(0),
    /// Documents kept raw: not compact, or did not come back from a block
    raw: std.atomic.Value(u64) = .init(0),
    frames: std.atomic.Value(u64) = .init(0),
    bytes: std.atomic.Value(u64) = .init(0),
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
    /// Stopped on an error: pushes are dropped (raw still has them)
    dead: bool = false,
    /// Adding a batch taken from the queue
    busy: bool = false,
    block_docs: usize = block_docs,
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

    /// Checks zstd is on PATH and makes the directories
    pub fn init(gpa: Allocator, io: Io, data_dir: []const u8) !Packer {
        const r = std.process.run(gpa, io, .{ .argv = &.{ "zstd", "--version" } }) catch |err| {
            log.err("zstd not found ({t}): install it or run with --no-complete", .{err});
            return error.ZstdMissing;
        };
        gpa.free(r.stdout);
        gpa.free(r.stderr);
        const dir = try std.fs.path.join(gpa, &.{ data_dir, "complete" });
        errdefer gpa.free(dir);
        const spool = try std.fs.path.join(gpa, &.{ dir, "spool" });
        defer gpa.free(spool);
        try Io.Dir.cwd().createDirPath(io, spool);
        return .{ .gpa = gpa, .io = io, .dir = dir };
    }

    /// Seals day files of older days, finds the spool to replay, starts both threads.
    /// `p` stays put until close
    pub fn start(p: *Packer) !void {
        p.day = p.clock(p.io);
        for (&p.lanes, 0..) |*l, i| l.* = .{ .kind = @fromBackingInt(@intCast(i)), .block = .init(p.gpa) };
        p.sealer = .{ .p = p };
        try p.sealer.sealOlder(p.day);
        p.next_seg = try p.lastSegment() + 1;
        p.sealer_thread = try std.Thread.spawn(.{}, Sealer.run, .{&p.sealer});
        p.thread = try std.Thread.spawn(.{}, run, .{p});
    }

    /// After the writer stopped: spools what is queued, then stops both threads. Blocks
    /// not yet sealed stay in the spool for the next start
    pub fn close(p: *Packer) void {
        {
            p.mutex.lockUncancelable(p.io);
            defer p.mutex.unlock(p.io);
            p.closing = true;
            p.cond.broadcast(p.io);
        }
        if (p.thread) |t| t.join();
        p.sealer.close();
        if (p.sealer_thread) |t| t.join();
        for (&p.lanes) |*l| l.deinit(p.gpa);
        for (p.queue.items) |o| p.gpa.free(o.buf);
        p.queue.deinit(p.gpa);
        p.sealer.deinit();
        p.gpa.free(p.dir);
    }

    /// From the writer, after its commit
    pub fn push(p: *Packer, item: Item) !void {
        const buf = try p.gpa.alloc(u8, item.key.len + item.gz.len);
        @memcpy(buf[0..item.key.len], item.key);
        @memcpy(buf[item.key.len..], item.gz);
        p.mutex.lockUncancelable(p.io);
        defer p.mutex.unlock(p.io);
        if (p.dead) {
            p.gpa.free(buf);
            return;
        }
        p.queue.append(p.gpa, .{ .kind = item.kind, .t = item.t, .key_len = item.key.len, .buf = buf }) catch |err| {
            p.gpa.free(buf);
            return err;
        };
        p.cond.broadcast(p.io);
    }

    fn run(p: *Packer) void {
        p.loop() catch |err| {
            // The crawl goes on without its complete form rather than stop: raw still
            // keeps every document, and the spool replays on the next start
            log.err("packer stopped: {t}; the spool waits for the next start", .{err});
            p.mutex.lockUncancelable(p.io);
            defer p.mutex.unlock(p.io);
            for (p.queue.items) |o| p.gpa.free(o.buf);
            p.queue.clearRetainingCapacity();
            p.dead = true;
        };
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
            try p.rollDay();
            for (batch.items) |o| try p.add(o.kind, o.key(), o.t, o.gz());
            if (closing) {
                for (&p.lanes) |*l| l.closeSegment(p.io);
                return;
            }
        }
    }

    /// Midnight: partial blocks to the old day, its files sealed
    fn rollDay(p: *Packer) !void {
        const today = p.clock(p.io);
        if (today == p.day) return;
        for (&p.lanes) |*l| try p.seal(l);
        try p.sealer.submit(.{ .seal_day = p.day });
        log.info("complete: day {f} done, {d} documents so far, {d} raw", .{
            Date.fromDay(p.day), p.stats.docs.load(.monotonic), p.stats.raw.load(.monotonic),
        });
        p.day = today;
    }

    fn add(p: *Packer, kind: Kind, key: []const u8, t: i64, gz: []const u8) !void {
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
        try p.addPlain(l, key, t, gz);
        if (l.count() >= p.block_docs or l.plain >= block_plain) try p.seal(l);
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
    /// job's frames are on disk
    fn seal(p: *Packer, l: *Lane) !void {
        l.closeSegment(p.io);
        if (l.count() == 0) return;
        const gpa = p.gpa;
        var job: Job = .{ .frames = .{ .kind = l.kind, .day = p.day } };
        errdefer job.deinit(gpa);
        if (l.seg_n != 0) job.frames.segment = try p.segPath(gpa, l.kind, l.seg_n);
        l.seg_n = 0;
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
        try l.packed_docs.appendSlice(gpa, good.items);
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
        const spool = try std.fs.path.join(gpa, &.{ p.dir, "spool" });
        defer gpa.free(spool);
        var docs: usize = 0;
        for (segs) |s| {
            if (s.n > p.next_seg) p.next_seg = s.n;
            var arena_state: std.heap.ArenaAllocator = .init(gpa);
            defer arena_state.deinit();
            const path = try std.fs.path.join(arena_state.allocator(), &.{ spool, s.name });
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

    const Seg = struct { kind: Kind, n: u64, name: []u8 };

    fn segments(p: *Packer, gpa: Allocator) ![]Seg {
        return listSegments(gpa, p.io, p.dir);
    }

    fn listSegments(gpa: Allocator, io: Io, complete_dir: []const u8) ![]Seg {
        const spool = try std.fs.path.join(gpa, &.{ complete_dir, "spool" });
        defer gpa.free(spool);
        var dir = try Io.Dir.cwd().openDir(io, spool, .{ .iterate = true });
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

    fn deinit(l: *Lane, gpa: Allocator) void {
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

const Record = struct { key: []const u8, t: i64, gz: []const u8 };

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

fn readRecord(r: *dayfile.Reader) !Record {
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

    const Open = struct { day: i64, file: Io.File, len: u64 };

    fn submit(s: *Sealer, job: Job) !void {
        const io = s.p.io;
        s.mutex.lockUncancelable(io);
        defer s.mutex.unlock(io);
        while (s.jobs.items.len >= max_jobs and !s.dead) s.cond.waitUncancelable(io, &s.mutex);
        if (s.dead) return error.SealerStopped;
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
                log.err("complete: sealer stopped: {t}; the spool waits for the next start", .{err});
                s.mutex.lockUncancelable(io);
                defer s.mutex.unlock(io);
                s.dead = true;
                s.cond.broadcast(io);
                return;
            };
        }
    }

    fn do(s: *Sealer, job: Job) !void {
        switch (job) {
            .seal_day => |day| for (std.enums.values(Kind)) |k| try s.sealFile(k, day),
            .frames => |f| {
                const o = try s.file(f.kind, f.day);
                var end = o.len;
                if (f.packed_plain) |plain| end += try s.appendFrame(o.file, end, .block, plain);
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
        const len = try dayfile.recover(s.p.gpa, s.p.io, f);
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
            _ = try dayfile.recover(gpa, io, f);
            try f.sync(io);
        }
        try cwd.rename(part, cwd, sealed, io);
        try archive.syncPath(io, s.p.dir, .directory);
        log.info("complete: sealed {s}", .{std.fs.path.basename(sealed)});
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
        const zst = try compress(gpa, s.p.io, s.p.dir, plain);
        defer gpa.free(zst);
        {
            var arena_state: std.heap.ArenaAllocator = .init(gpa);
            defer arena_state.deinit();
            const back = try dayfile.inflate(gpa, arena_state.allocator(), zst);
            if (!std.mem.eql(u8, back, plain)) return error.ZstdRoundTrip;
        }
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

/// `plain` through `nice zstd -19 -T1` (std has no compressor), via a temp file in `dir`
fn compress(gpa: Allocator, io: Io, dir: []const u8, plain: []const u8) ![]u8 {
    const tmp = try std.fmt.allocPrint(gpa, "{s}/frame.zst.tmp", .{dir});
    defer gpa.free(tmp);
    const cwd = Io.Dir.cwd();
    defer cwd.deleteFile(io, tmp) catch {};
    {
        var child = try std.process.spawn(io, .{
            .argv = &.{ "nice", "-n", "19", "zstd", "-q", "-f", zstd_level, "-T1", "-", "-o", tmp },
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
    return cwd.readFileAlloc(io, tmp, gpa, .limited(dayfile.max_payload));
}

var test_day: i64 = 20_000;

fn testClock(_: Io) i64 {
    return test_day;
}

/// Until both threads have nothing left to do
fn settle(p: *Packer) !void {
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
        try p.push(.{ .kind = .summary, .key = try arena.print("EUW1_{d}", .{i}), .t = @intCast(100 + i), .gz = gz });
    }
    try p.push(.{ .kind = .timeline, .key = "EUW1_0", .t = 200, .gz = timeline_gz });
    try p.push(.{ .kind = .mastery, .key = "EUW1:abc", .t = 300, .gz = mastery_gz });
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
    try p2.push(.{ .kind = .mastery, .key = "EUW1:next", .t = 400, .gz = mastery_gz });
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
        try p.push(.{ .kind = .summary, .key = try arena.print("K{d}", .{i}), .t = 1, .gz = try store.raw.compress(arena, doc) });
    }
    try settle(&p);
    // As if the codec lost the middle document: its recorded hash no longer matches
    {
        p.mutex.lockUncancelable(io);
        defer p.mutex.unlock(io);
        p.lanes[@backingInt(Kind.summary)].packed_docs.items[1].hash +%= 1;
    }
    test_day += 1;
    try p.push(.{ .kind = .mastery, .key = "wake", .t = 1, .gz = try store.raw.compress(arena, "[]") });
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
