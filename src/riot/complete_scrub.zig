//! Erasure and the 24-month rule for the complete form's sealed day files
//! (riot/complete.zig; docs/data-safety.md "Erasure"). A document naming a forgotten
//! PUUID is dropped whole, as raw.db drops a forgotten player's summaries and timelines;
//! a day file older than 730 days is deleted. Open `.part` files and the spool are the
//! crawler's: they wait until sealed, then the next run (forget, or the daily backup)
//! reaches them.
//!
//! A PUUID's bytes sit literally in a frame's plain payload when any of its documents
//! names it (keys; jsonpack keeps every string's bytes the first time a block meets it;
//! raw bodies), so only frames that hold one are decoded and repacked; the rest are
//! copied as they are. The file is rewritten beside itself, fsynced and renamed over.
//!
//! complete/forgotten.txt: every PUUID applied, in the order first applied (append-only,
//! so a count names a prefix); complete/scrubbed.tsv: FILE<TAB>N, the first N of them
//! applied to FILE. Each run appends what meiolol.db's `forgotten` adds and brings every
//! sealed file up to the whole list, under complete/scrub.lock.

const std = @import("std");
const store = @import("store");
const complete = @import("complete.zig");
const archive = @import("../archive.zig");
const Date = @import("../date.zig").Date;
const dayfile = store.dayfile;
const jsonpack = store.jsonpack;
const Io = std.Io;
const Allocator = std.mem.Allocator;

const log = std.log.scoped(.complete);

/// The privacy policy's 24 months, as backup.zig's sweepAged and the crawler
pub const aged_days = 730;

pub const Tended = struct {
    /// Files read for PUUIDs new to them
    files: usize = 0,
    rewritten: usize = 0,
    dropped: u64 = 0,
    aged: usize = 0,
    /// Records dropped from quarantined spool segments
    quarantined: usize = 0,
    /// Files that failed (logged, retried next run)
    failed: usize = 0,
};

/// Aging deletes no more than this many days' files a run: a bad reference deletes slowly,
/// warned, rather than every day at once
const aged_days_per_run = 2;

/// With `aged_by` (unix seconds; the caller's clock, null: no aging) deletes day files past
/// 24 months of it, then brings every sealed file up to `forgotten` (meiolol.db's whole
/// list; anything there but a PUUID is left out, warned). Nothing to do without
/// <data>/complete
pub fn tend(gpa: Allocator, io: Io, data_dir: []const u8, forgotten: []const []const u8, aged_by: ?i64) !Tended {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const cwd = Io.Dir.cwd();
    const dir_path = try std.fs.path.join(arena, &.{ data_dir, "complete" });
    var dir = cwd.openDir(io, dir_path, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return .{},
        else => return err,
    };
    defer dir.close(io);
    const lock = try dir.createFile(io, "scrub.lock", .{ .lock = .exclusive, .truncate = false });
    defer lock.close(io);

    var t: Tended = .{};
    const Named = struct { name: []const u8, day: i64 };
    var all: std.ArrayList(Named) = .empty;
    var it = dir.iterate();
    while (try it.next(io)) |e| {
        const day = sealedDay(e.name) orelse continue;
        if (e.kind != .file) continue;
        try all.append(arena, .{ .name = try arena.dupe(u8, e.name), .day = day });
    }
    var sealed: std.ArrayList([]const u8) = .empty;
    if (aged_by) |by| {
        const today = @divFloor(by, std.time.s_per_day);
        // The oldest aged_days_per_run days due go; the rest wait for the next run
        var due: std.ArrayList(i64) = .empty;
        for (all.items) |f| if (f.day < today - aged_days and std.mem.indexOfScalar(i64, due.items, f.day) == null) try due.append(arena, f.day);
        std.mem.sort(i64, due.items, {}, std.sort.asc(i64));
        if (due.items.len > aged_days_per_run) log.warn("complete: {d} days past 24 months, {d} deleted this run", .{ due.items.len, aged_days_per_run });
        const cut = if (due.items.len > aged_days_per_run) due.items[aged_days_per_run] else std.math.maxInt(i64);
        for (all.items) |f| {
            if (f.day < today - aged_days and f.day < cut) {
                try dir.deleteFile(io, f.name);
                t.aged += 1;
            } else try sealed.append(arena, f.name);
        }
        if (t.aged > 0) try archive.syncPath(io, dir_path, .directory);
    } else for (all.items) |f| try sealed.append(arena, f.name);

    const list = try syncList(arena, io, dir, forgotten);
    const old = try readApplied(arena, io, dir);
    // Files gone (aged, or deleted by hand) leave the table and the index; a file not as
    // its row says (replaced: a restore over it, a hand merge), or past the list's end
    // (forgotten.txt cut short by hand: the pair is append-only), is read whole again
    var applied: std.StringArrayHashMapUnmanaged(Applied) = .empty;
    var changed = false;
    var past_end: usize = 0;
    for (sealed.items) |name| {
        const st = try dir.statFile(io, name, .{});
        const now_as: Applied = .{ .n = 0, .size = st.size, .mtime = st.mtime.toNanoseconds() };
        const row = old.get(name) orelse now_as;
        if (row.n > list.len) past_end += 1;
        const as_row = row.size == st.size and row.mtime == now_as.mtime and row.n <= list.len;
        try applied.put(arena, name, if (as_row) row else now_as);
        changed = changed or !as_row;
    }
    changed = changed or applied.count() != old.count();
    if (past_end > 0) log.warn("complete: {d} files applied more of forgotten.txt than it holds: read whole again", .{past_end});
    try dir.createDirPath(io, index_dir);
    try dropStaleIndexes(arena, io, dir, applied);

    var m: Matcher = try .init(arena, list);
    t.quarantined = try scrubQuarantine(arena, io, dir, &m);
    for (sealed.items) |name| {
        const row = applied.get(name).?;
        if (row.n >= list.len) continue;
        const fresh = list[row.n..];
        if (row.n > 0) if (try readIndex(arena, io, dir, name)) |ids| if (!mayHold(ids, fresh)) {
            try applied.put(arena, name, .{ .n = list.len, .size = row.size, .mtime = row.mtime });
            changed = true;
            continue;
        };
        try m.reset(arena, fresh);
        t.files += 1;
        const r = scrubFile(gpa, io, dir, dir_path, name, &m) catch |err| {
            log.err("complete: scrubbing {s} failed: {t}; tried again next run", .{ name, err });
            t.failed += 1;
            continue;
        };
        defer gpa.free(r.ids);
        if (r.dropped) |d| {
            t.rewritten += 1;
            t.dropped += d;
        }
        try writeIndex(arena, io, dir, name, r.ids);
        const st = try dir.statFile(io, name, .{});
        try applied.put(arena, name, .{ .n = list.len, .size = st.size, .mtime = st.mtime.toNanoseconds() });
        try writeApplied(arena, io, dir, applied);
        changed = false;
    }
    if (changed) try writeApplied(arena, io, dir, applied);
    return t;
}

/// A real PUUID: 78 characters of base64url. Anything shorter would match nearly every
/// document, and forgotten.txt never forgets an entry
pub fn isPuuid(s: []const u8) bool {
    return s.len == puuid_len and std.mem.indexOfNone(u8, s, &Matcher.chars) == null;
}

/// complete/index/<file>.ids: "CFI1" then the sorted Wyhash of every PUUID-long window
/// of base64url bytes the file holds (from its documents as they are now: never a
/// forgotten one, those are dropped first). A new forgotten PUUID found in none of a
/// file's hashes needs no read of it. Missing or damaged: the file is read whole
const index_dir = "index";
const index_magic = "CFI1";
const puuid_len = 78;

fn indexName(arena: Allocator, name: []const u8) ![]const u8 {
    return std.fmt.allocPrint(arena, index_dir ++ "/{s}.ids", .{name});
}

fn readIndex(arena: Allocator, io: Io, dir: Io.Dir, name: []const u8) !?[]const u64 {
    const bytes = dir.readFileAlloc(io, try indexName(arena, name), arena, .unlimited) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    if (!std.mem.startsWith(u8, bytes, index_magic) or (bytes.len - index_magic.len) % 8 != 0) return null;
    const ids = try arena.alloc(u64, (bytes.len - index_magic.len) / 8);
    for (ids, 0..) |*id, i| id.* = std.mem.readInt(u64, bytes[index_magic.len + i * 8 ..][0..8], .little);
    return ids;
}

fn writeIndex(arena: Allocator, io: Io, dir: Io.Dir, name: []const u8, ids: []const u64) !void {
    const bytes = try arena.alloc(u8, index_magic.len + ids.len * 8);
    @memcpy(bytes[0..index_magic.len], index_magic);
    for (ids, 0..) |id, i| std.mem.writeInt(u64, bytes[index_magic.len + i * 8 ..][0..8], id, .little);
    try replaceFile(io, dir, try indexName(arena, name), bytes);
}

/// Whether a file with index `ids` may name any of `puuids`
fn mayHold(ids: []const u64, puuids: []const []const u8) bool {
    for (puuids) |p| {
        if (std.sort.binarySearch(u64, ids, std.hash.Wyhash.hash(0, p), orderU64) != null) return true;
    }
    return false;
}

fn orderU64(a: u64, b: u64) std.math.Order {
    return std.math.order(a, b);
}

/// Every PUUID-long window of each base64url run in `bytes`, hashed into `out`
fn collectIds(gpa: Allocator, out: *std.ArrayList(u64), bytes: []const u8) !void {
    var i: usize = 0;
    while (i < bytes.len) {
        if (!Matcher.word[bytes[i]]) {
            i += 1;
            continue;
        }
        const start = i;
        while (i < bytes.len and Matcher.word[bytes[i]]) i += 1;
        if (i - start < puuid_len) continue;
        var at = start;
        while (at + puuid_len <= i) : (at += 1) try out.append(gpa, std.hash.Wyhash.hash(0, bytes[at..][0..puuid_len]));
    }
}

fn sortUnique(ids: *std.ArrayList(u64)) void {
    std.mem.sort(u64, ids.items, {}, std.sort.asc(u64));
    var n: usize = 0;
    for (ids.items) |id| {
        if (n > 0 and ids.items[n - 1] == id) continue;
        ids.items[n] = id;
        n += 1;
    }
    ids.shrinkRetainingCapacity(n);
}

fn dropStaleIndexes(arena: Allocator, io: Io, dir: Io.Dir, applied: std.StringArrayHashMapUnmanaged(Applied)) !void {
    var idx = try dir.openDir(io, index_dir, .{ .iterate = true });
    defer idx.close(io);
    var stale: std.ArrayList([]const u8) = .empty;
    var it = idx.iterate();
    while (try it.next(io)) |e| {
        if (std.mem.endsWith(u8, e.name, ".ids") and applied.contains(e.name[0 .. e.name.len - ".ids".len])) continue;
        try stale.append(arena, try arena.dupe(u8, e.name));
    }
    for (stale.items) |name| try idx.deleteFile(io, name);
}

/// Quarantined spool segments (complete.zig) rewritten without the records naming any
/// of `m`'s PUUIDs, or whose body does not inflate (can't be checked), and without
/// everything from a damaged record on (framing lost: can't be checked or replayed); a
/// segment left empty is deleted.
/// Count of records dropped. Rare and small: read whole each run
fn scrubQuarantine(arena: Allocator, io: Io, dir: Io.Dir, m: *const Matcher) !usize {
    var q = dir.openDir(io, "spool/quarantine", .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return 0,
        else => return err,
    };
    defer q.close(io);
    var names: std.ArrayList([]const u8) = .empty;
    var it = q.iterate();
    while (try it.next(io)) |e| if (e.kind == .file and isSegmentName(e.name)) try names.append(arena, try arena.dupe(u8, e.name));
    var dropped: usize = 0;
    for (names.items) |name| {
        const bytes = try q.readFileAlloc(io, name, arena, .unlimited);
        var kept: std.ArrayList(u8) = .empty;
        var r: dayfile.Reader = .{ .b = bytes };
        var changed = false;
        while (!r.done()) {
            const at = r.i;
            const rec = complete.readRecord(&r) catch {
                changed = true;
                break;
            };
            const plain = store.raw.decompress(arena, rec.gz) catch |err| switch (err) {
                error.OutOfMemory => return err,
                else => null,
            };
            if (plain == null or m.any(rec.key) or m.any(plain.?)) {
                dropped += 1;
                changed = true;
                continue;
            }
            try kept.appendSlice(arena, bytes[at..r.i]);
        }
        if (!changed) continue;
        if (kept.items.len == 0) try q.deleteFile(io, name) else try replaceFile(io, q, name, kept.items);
    }
    return dropped;
}

/// A quarantined segment's name, <kind>.<n>.<unix time> (complete.zig): never a temp
/// file a crash left
fn isSegmentName(name: []const u8) bool {
    var parts = std.mem.splitScalar(u8, name, '.');
    _ = std.meta.stringToEnum(complete.Kind, parts.next().?) orelse return false;
    for (0..2) |_| {
        const digits = parts.next() orelse return false;
        if (digits.len == 0 or std.mem.indexOfNone(u8, digits, "0123456789") != null) return false;
    }
    return parts.next() == null;
}

/// A sealed day file's UTC day from its name (YYYY-MM-DD.<kind>.cfd)
/// A seal that found its name taken set its file aside as <name>.clash-<time>
/// (complete.zig): sealed too
pub fn sealedDay(name: []const u8) ?i64 {
    if (name.len < 12 or name[10] != '.') return null;
    const end = std.mem.indexOfPos(u8, name, 11, ".cfd") orelse return null;
    const rest = name[end + ".cfd".len ..];
    if (rest.len > 0 and !std.mem.startsWith(u8, rest, ".clash-")) return null;
    _ = std.meta.stringToEnum(complete.Kind, name[11..end]) orelse return null;
    return (Date.parse(name[0..10]) orelse return null).toDay();
}

/// forgotten.txt with every PUUID of `forgotten` not yet in it appended (sorted, so a
/// run is repeatable); the whole list. Entries that are not PUUIDs are left out, warned
fn syncList(arena: Allocator, io: Io, dir: Io.Dir, forgotten: []const []const u8) ![]const []const u8 {
    const old = dir.readFileAlloc(io, "forgotten.txt", arena, .limited(1 << 30)) catch |err| switch (err) {
        error.FileNotFound => "",
        else => return err,
    };
    var list: std.ArrayList([]const u8) = .empty;
    var seen: std.StringHashMapUnmanaged(void) = .empty;
    var lines = std.mem.tokenizeScalar(u8, old, '\n');
    while (lines.next()) |l| {
        // Counts in scrubbed.tsv name a prefix of this file: a line dropped would shift them
        if (!isPuuid(l)) {
            log.err("complete: forgotten.txt line {d} is not a PUUID: mend the file by hand", .{list.items.len + 1});
            return error.Corrupt;
        }
        try list.append(arena, l);
        try seen.put(arena, l, {});
    }
    const before = list.items.len;
    var odd: usize = 0;
    for (forgotten) |p| {
        if (!isPuuid(p)) {
            odd += 1;
            continue;
        }
        if ((try seen.getOrPut(arena, p)).found_existing) continue;
        try list.append(arena, p);
    }
    if (odd > 0) log.warn("complete: {d} forgotten entries are not PUUIDs: left out", .{odd});
    const fresh = list.items[before..];
    if (fresh.len == 0) return list.items;
    std.mem.sort([]const u8, fresh, {}, struct {
        fn lt(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.order(u8, a, b) == .lt;
        }
    }.lt);
    var out: std.Io.Writer.Allocating = .init(arena);
    for (list.items) |p| try out.writer.print("{s}\n", .{p});
    try replaceFile(io, dir, "forgotten.txt", out.written());
    return list.items;
}

/// scrubbed.tsv row: the first `n` of forgotten.txt applied to the file as it was then
/// (size, mtime in ns)
const Applied = struct { n: usize, size: u64, mtime: i96 };

fn readApplied(arena: Allocator, io: Io, dir: Io.Dir) !std.StringArrayHashMapUnmanaged(Applied) {
    var map: std.StringArrayHashMapUnmanaged(Applied) = .empty;
    const text = dir.readFileAlloc(io, "scrubbed.tsv", arena, .limited(64 << 20)) catch |err| switch (err) {
        error.FileNotFound => return map,
        else => return err,
    };
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    while (lines.next()) |l| {
        var cols = std.mem.splitScalar(u8, l, '\t');
        const name = cols.first();
        const row: Applied = .{
            .n = std.fmt.parseInt(usize, cols.next() orelse return error.Corrupt, 10) catch return error.Corrupt,
            .size = std.fmt.parseInt(u64, cols.next() orelse return error.Corrupt, 10) catch return error.Corrupt,
            .mtime = std.fmt.parseInt(i96, cols.next() orelse return error.Corrupt, 10) catch return error.Corrupt,
        };
        try map.put(arena, name, row);
    }
    return map;
}

fn writeApplied(arena: Allocator, io: Io, dir: Io.Dir, map: std.StringArrayHashMapUnmanaged(Applied)) !void {
    var out: std.Io.Writer.Allocating = .init(arena);
    var it = map.iterator();
    while (it.next()) |e| {
        const r = e.value_ptr.*;
        try out.writer.print("{s}\t{d}\t{d}\t{d}\n", .{ e.key_ptr.*, r.n, r.size, r.mtime });
    }
    try replaceFile(io, dir, "scrubbed.tsv", out.written());
}

fn replaceFile(io: Io, dir: Io.Dir, name: []const u8, bytes: []const u8) !void {
    var file = try dir.createFileAtomic(io, name, .{ .replace = true });
    defer file.deinit(io);
    try file.file.writeStreamingAll(io, bytes);
    try file.file.sync(io);
    try file.replace(io);
}

/// Finds any of a set of PUUIDs (isPuuid) in bytes: every PUUID-long window of each
/// base64url run is looked up
const Matcher = struct {
    set: std.StringHashMapUnmanaged(void) = .empty,

    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_".*;
    const word = blk: {
        var w: [256]bool = @splat(false);
        for (chars) |c| w[c] = true;
        break :blk w;
    };

    fn init(arena: Allocator, puuids: []const []const u8) !Matcher {
        var m: Matcher = .{};
        try m.reset(arena, puuids);
        return m;
    }

    fn reset(m: *Matcher, arena: Allocator, puuids: []const []const u8) !void {
        m.set.clearRetainingCapacity();
        for (puuids) |p| {
            std.debug.assert(isPuuid(p));
            try m.set.put(arena, p, {});
        }
    }

    fn any(m: *const Matcher, hay: []const u8) bool {
        if (m.set.count() == 0) return false;
        var i: usize = 0;
        while (i < hay.len) {
            if (!word[hay[i]]) {
                i += 1;
                continue;
            }
            const start = i;
            while (i < hay.len and word[hay[i]]) i += 1;
            if (i - start < puuid_len) continue;
            var at = start;
            while (at + puuid_len <= i) : (at += 1) if (m.set.contains(hay[at..][0..puuid_len])) return true;
        }
        return false;
    }
};

const Scrubbed = struct {
    /// Documents dropped; null when no frame names any (the file untouched)
    dropped: ?u64,
    /// The file's index as it is now (sorted, unique; gpa)
    ids: []u64,
};

/// Rewrites the sealed file `name` without the documents `m` finds
fn scrubFile(gpa: Allocator, io: Io, dir: Io.Dir, dir_path: []const u8, name: []const u8, m: *const Matcher) !Scrubbed {
    const tmp_name = ".scrub.tmp";
    var ids: std.ArrayList(u64) = .empty;
    defer ids.deinit(gpa);
    const file = try dir.openFile(io, name, .{});
    defer file.close(io);
    var out: ?Io.File = null;
    defer if (out) |o| {
        o.close(io);
        dir.deleteFile(io, tmp_name) catch {};
    };
    var out_len: u64 = 0;
    var dropped: u64 = 0;
    var frames: dayfile.Frames = .{ .file = file };
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const zst_tmp = try std.fs.path.join(gpa, &.{ dir_path, "scrub.zst.tmp" });
    defer gpa.free(zst_tmp);
    while (true) {
        const at = frames.pos;
        const fr = try frames.next(gpa, io) orelse break;
        defer gpa.free(fr.zst);
        defer _ = arena_state.reset(.retain_capacity);
        const arena = arena_state.allocator();
        const plain = try dayfile.inflate(gpa, arena, fr.zst);
        const hit = m.any(plain);
        if (!hit) try collectIds(gpa, &ids, plain);
        if (hit and out == null) {
            out = try dir.createFile(io, tmp_name, .{ .read = true });
            out_len = try copyRange(io, file, out.?, at);
        }
        const o = out orelse continue;
        if (!hit) {
            const h = dayfile.header(fr.type, fr.zst);
            try o.writePositionalAll(io, &h, out_len);
            try o.writePositionalAll(io, fr.zst, out_len + h.len);
            out_len += h.len + fr.zst.len;
            continue;
        }
        const r = try repack(gpa, arena, io, zst_tmp, fr, m, &ids);
        try o.writePositionalAll(io, r.frames, out_len);
        out_len += r.frames.len;
        dropped += r.dropped;
    }
    // Sealed files end at their last whole frame (complete.zig cuts the tail first)
    if (frames.pos != try file.length(io)) return error.Corrupt;
    sortUnique(&ids);
    const o = out orelse return .{ .dropped = null, .ids = try ids.toOwnedSlice(gpa) };
    try o.sync(io);
    try dir.rename(tmp_name, dir, name, io);
    o.close(io);
    out = null;
    try archive.syncPath(io, dir_path, .directory);
    return .{ .dropped = dropped, .ids = try ids.toOwnedSlice(gpa) };
}

fn copyRange(io: Io, from: Io.File, to: Io.File, len: u64) !u64 {
    var buf: [1 << 20]u8 = undefined;
    var pos: u64 = 0;
    while (pos < len) {
        const n: usize = @intCast(@min(buf.len, len - pos));
        if (try from.readPositionalAll(io, buf[0..n], pos) < n) return error.Corrupt;
        try to.writePositionalAll(io, buf[0..n], pos);
        pos += n;
    }
    return pos;
}

/// A frame's documents but those `m` finds, as zero to two frames (a block and the
/// documents that do not pack, or raw as before), in `arena`; their index hashes to `ids`
fn repack(gpa: Allocator, arena: Allocator, io: Io, zst_tmp: []const u8, fr: dayfile.Frame, m: *const Matcher, ids: *std.ArrayList(u64)) !struct { frames: []u8, dropped: u64 } {
    const docs = try dayfile.decode(gpa, arena, fr);
    var packs: std.ArrayList(dayfile.Doc) = .empty;
    var raws: std.ArrayList(dayfile.Doc) = .empty;
    var block: std.ArrayList(u8) = .empty;
    defer block.deinit(gpa);
    var b: jsonpack.Block = .init(gpa);
    defer b.deinit();
    for (docs) |d| {
        if (m.any(d.key) or m.any(d.bytes)) continue;
        if (fr.type == .block and try b.add(d.bytes)) try packs.append(arena, d) else try raws.append(arena, d);
    }
    if (packs.items.len > 0) {
        try b.finish(&block);
        if (!try same(gpa, block.items, packs.items)) {
            log.warn("complete: a repacked block did not decode back: kept raw", .{});
            try raws.insertSlice(arena, 0, packs.items);
            packs.clearRetainingCapacity();
        }
    }
    var out: std.ArrayList(u8) = .empty;
    for ([_]dayfile.Type{ .block, .raw }) |t| {
        const list = if (t == .block) packs.items else raws.items;
        if (list.len == 0) continue;
        var plain: std.ArrayList(u8) = .empty;
        defer plain.deinit(gpa);
        try dayfile.keys(gpa, &plain, list);
        if (t == .block) try plain.appendSlice(gpa, block.items) else try dayfile.rawBody(gpa, &plain, list);
        try collectIds(gpa, ids, plain.items);
        const zst = try complete.compress(gpa, io, zst_tmp, plain.items);
        defer gpa.free(zst);
        try out.appendSlice(arena, &dayfile.header(t, zst));
        try out.appendSlice(arena, zst);
    }
    return .{ .frames = out.items, .dropped = docs.len - packs.items.len - raws.items.len };
}

/// Whether `block` decodes to exactly `docs`' bytes
fn same(gpa: Allocator, block: []const u8, docs: []const dayfile.Doc) !bool {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(gpa);
    const ends = jsonpack.decode(gpa, block, &out) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => return false,
    };
    defer gpa.free(ends);
    if (ends.len != docs.len) return false;
    var start: usize = 0;
    for (docs, ends) |d, end| {
        if (!std.mem.eql(u8, out.items[start..end], d.bytes)) return false;
        start = end;
    }
    return true;
}

/// Sealed day files of a backup's complete/ copied into <data>/complete (meiolol
/// restore); count copied. The caller then tends them with the restored `forgotten`
pub fn restore(io: Io, from_dir: []const u8, data_dir: []const u8) !usize {
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const cwd = Io.Dir.cwd();
    var from = cwd.openDir(io, try std.fmt.bufPrint(&buf, "{s}/complete", .{from_dir}), .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return 0,
        else => return err,
    };
    defer from.close(io);
    const to_path = try std.fmt.bufPrint(&buf, "{s}/complete", .{data_dir});
    try cwd.createDirPath(io, to_path);
    var to = try cwd.openDir(io, to_path, .{});
    defer to.close(io);
    var n: usize = 0;
    var it = from.iterate();
    while (try it.next(io)) |e| {
        if (e.kind != .file or sealedDay(e.name) == null) continue;
        try from.copyFile(e.name, to, e.name, io, .{});
        n += 1;
    }
    return n;
}

const testing = std.testing;

fn fakePuuid(arena: Allocator, c: u8) ![]const u8 {
    const p = try arena.alloc(u8, 78);
    @memset(p, c);
    p[0] = 'P';
    return p;
}

test "a forget drops exactly the documents naming the player; the rest stay byte for byte" {
    const gpa = testing.allocator;
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const data = try arena.print(".zig-cache/tmp/{s}", .{&tmp.sub_path});

    const a = try fakePuuid(arena, 'a');
    const b = try fakePuuid(arena, 'b');
    const x = try fakePuuid(arena, 'x');
    const summary = struct {
        fn doc(al: Allocator, p1: []const u8, p2: []const u8) ![]const u8 {
            return al.print("{{\"metadata\":{{\"participants\":[\"{s}\",\"{s}\"]}},\"info\":{{\"participants\":[{{\"puuid\":\"{s}\"}},{{\"puuid\":\"{s}\"}}]}}}}", .{ p1, p2, p1, p2 });
        }
    }.doc;
    const Want = struct { kind: complete.Kind, key: []const u8, bytes: []const u8, names: []const u8 };
    const docs = [_]Want{
        .{ .kind = .summary, .key = "EUW1_1", .bytes = try summary(arena, a, x), .names = "a" },
        .{ .kind = .summary, .key = "EUW1_2", .bytes = try summary(arena, x, b), .names = "b" },
        .{ .kind = .summary, .key = "EUW1_3", .bytes = try summary(arena, x, x), .names = "" },
        // Not compact: a raw frame
        .{ .kind = .summary, .key = "EUW1_4", .bytes = try arena.print(" [\"{s}\"]", .{a}), .names = "a" },
        .{ .kind = .summary, .key = "EUW1_5", .bytes = " [1]", .names = "" },
        .{ .kind = .timeline, .key = "EUW1_1", .bytes = try summary(arena, a, x), .names = "a" },
        .{ .kind = .timeline, .key = "EUW1_3", .bytes = try summary(arena, x, x), .names = "" },
        .{ .kind = .mastery, .key = try arena.print("EUW1:{s}", .{a}), .bytes = "[{\"championId\":1}]", .names = "a" },
        .{ .kind = .mastery, .key = try arena.print("EUW1:{s}", .{x}), .bytes = "[{\"championId\":2}]", .names = "" },
    };
    const saved = complete.test_day;
    defer complete.test_day = saved;
    complete.test_day = 20_000;
    var p: complete.Packer = try .init(gpa, io, data);
    p.clock = complete.testClock;
    p.block_docs = 3;
    try p.start();
    for (docs, 0..) |d, i| p.push(.{ .kind = d.kind, .key = d.key, .t = @intCast(i), .gz = try store.raw.compress(arena, d.bytes) });
    try complete.settle(&p);
    complete.test_day += 1;
    // Today's open file names a too: not the scrub's to touch
    for (0..3) |i| p.push(.{ .kind = .summary, .key = try arena.print("EUW1_9{d}", .{i}), .t = 9, .gz = try store.raw.compress(arena, try summary(arena, a, a)) });
    try complete.settle(&p);
    p.close();

    const day0 = Date.fromDay(20_000);
    const now = 20_001 * std.time.s_per_day;
    const left = struct {
        fn check(al: Allocator, dir: []const u8, ws: []const Want, gone: []const u8) !void {
            for (std.enums.values(complete.Kind)) |k| {
                const got = try dayfile.readAll(testing.allocator, al, testing.io, try al.print("{s}/complete/{f}.{t}.cfd", .{ dir, Date.fromDay(20_000), k }));
                var n: usize = 0;
                for (ws) |w| {
                    if (w.kind != k or (w.names.len > 0 and std.mem.indexOf(u8, gone, w.names) != null)) continue;
                    const d = for (got) |g| {
                        if (std.mem.eql(u8, g.key, w.key)) break g;
                    } else return error.Missing;
                    try testing.expectEqualStrings(w.bytes, d.bytes);
                    n += 1;
                }
                try testing.expectEqual(n, got.len);
            }
        }
    }.check;
    try left(arena, data, &docs, "");

    var t = try tend(gpa, io, data, &.{a}, now);
    try testing.expectEqual(3, t.files);
    try testing.expectEqual(3, t.rewritten);
    try testing.expectEqual(4, t.dropped);
    try left(arena, data, &docs, "a");
    const part = try dayfile.readAll(gpa, arena, io, try arena.print("{s}/complete/{f}.summary.cfd.part", .{ data, Date.fromDay(20_001) }));
    try testing.expectEqual(3, part.len);

    // Again: nothing new for any file, none read
    t = try tend(gpa, io, data, &.{a}, now);
    try testing.expectEqual(0, t.files);
    const timeline_before = try Io.Dir.cwd().readFileAlloc(io, try arena.print("{s}/complete/{f}.timeline.cfd", .{ data, day0 }), arena, .unlimited);
    // Scrubbed files' indexes never hold a forgotten PUUID
    var dir = try Io.Dir.cwd().openDir(io, try arena.print("{s}/complete", .{data}), .{});
    defer dir.close(io);
    for (std.enums.values(complete.Kind)) |k| {
        const ids = (try readIndex(arena, io, dir, try arena.print("{f}.{t}.cfd", .{ day0, k }))).?;
        try testing.expect(!mayHold(ids, &.{a}));
        try testing.expect(mayHold(ids, &.{x}));
    }
    // b only names a summary: the indexes rule the other files out unread
    t = try tend(gpa, io, data, &.{ b, a }, now);
    try testing.expectEqual(1, t.files);
    try testing.expectEqual(1, t.rewritten);
    try testing.expectEqual(1, t.dropped);
    try left(arena, data, &docs, "ab");
    try testing.expectEqualStrings(timeline_before, try Io.Dir.cwd().readFileAlloc(io, try arena.print("{s}/complete/{f}.timeline.cfd", .{ data, day0 }), arena, .unlimited));
    const tsv = try dir.readFileAlloc(io, "scrubbed.tsv", arena, .unlimited);
    try testing.expectEqual(3, std.mem.count(u8, tsv, "\t2\t"));

    // Warned from here on
    const saved_level = testing.log_level;
    defer testing.log_level = saved_level;
    testing.log_level = .err;

    // Entries that are not PUUIDs never reach the list: "1" would match nearly every doc
    t = try tend(gpa, io, data, &.{ "1", "EUW1", b, a }, now);
    try testing.expectEqual(0, t.files);
    try testing.expectEqual(2, std.mem.count(u8, try dir.readFileAlloc(io, "forgotten.txt", arena, .unlimited), "\n"));
    try left(arena, data, &docs, "ab");

    // A file not as its row says (replaced since) is read whole again, its index unused
    {
        var out: std.Io.Writer.Allocating = .init(arena);
        var lines = std.mem.tokenizeScalar(u8, tsv, '\n');
        while (lines.next()) |l| {
            var cols = std.mem.splitScalar(u8, l, '\t');
            const name = cols.first();
            const n = cols.next().?;
            const size = if (std.mem.indexOf(u8, name, "summary") != null) "1" else cols.next().?;
            if (std.mem.indexOf(u8, name, "summary") != null) _ = cols.next();
            try out.writer.print("{s}\t{s}\t{s}\t{s}\n", .{ name, n, size, cols.next().? });
        }
        try dir.writeFile(io, .{ .sub_path = "scrubbed.tsv", .data = out.written() });
    }
    t = try tend(gpa, io, data, &.{ b, a }, now);
    try testing.expectEqual(1, t.files);
    try testing.expectEqual(0, t.rewritten);
    try left(arena, data, &docs, "ab");

    // Quarantined spool segments lose the records naming a forgotten player and a torn
    // tail; one left empty goes
    const c = try fakePuuid(arena, 'c');
    try dir.createDirPath(io, "spool/quarantine");
    const seg = struct {
        fn bytes(al: Allocator, key: []const u8, body: []const u8) ![]const u8 {
            const gz = try store.raw.compress(al, body);
            return std.mem.concat(al, u8, &.{ &.{ 9, @intCast(key.len) }, key, &.{@intCast(gz.len)}, gz });
        }
    }.bytes;
    const keep = try seg(arena, "EUW1:k", try arena.print("[\"{s}\"]", .{x}));
    try dir.writeFile(io, .{ .sub_path = "spool/quarantine/mastery.7.1", .data = try seg(arena, "EUW1:k", try arena.print("[\"{s}\"]", .{c})) });
    try dir.writeFile(io, .{ .sub_path = "spool/quarantine/mastery.8.1", .data = keep });
    try dir.writeFile(io, .{ .sub_path = "spool/quarantine/mastery.9.1", .data = try std.mem.concat(arena, u8, &.{ keep, try seg(arena, "EUW1:j", try arena.print("[\"{s}\"]", .{c})), keep, "\x09\x40EU" }) });
    t = try tend(gpa, io, data, &.{c}, now);
    try testing.expectEqual(2, t.quarantined);
    try testing.expectError(error.FileNotFound, dir.access(io, "spool/quarantine/mastery.7.1", .{}));
    try testing.expectEqualStrings(keep, try dir.readFileAlloc(io, "spool/quarantine/mastery.8.1", arena, .unlimited));
    try testing.expectEqualStrings(try std.mem.concat(arena, u8, &.{ keep, keep }), try dir.readFileAlloc(io, "spool/quarantine/mastery.9.1", arena, .unlimited));

    // 24 months on: no aging without a clock (forget, restore)
    const later = (20_000 + aged_days + 1) * std.time.s_per_day;
    try dir.writeFile(io, .{ .sub_path = try arena.print("{f}.mastery.cfd", .{Date.fromDay(20_000 + aged_days)}), .data = "" });
    t = try tend(gpa, io, data, &.{ b, a }, null);
    try testing.expectEqual(0, t.aged);
    // With one the old days go, at most aged_days_per_run a run, and leave the table and
    // the index
    for ([_]i64{ 19_998, 19_999 }) |d| try dir.writeFile(io, .{ .sub_path = try arena.print("{f}.summary.cfd", .{Date.fromDay(d)}), .data = "" });
    t = try tend(gpa, io, data, &.{ b, a }, later);
    try testing.expectEqual(2, t.aged);
    t = try tend(gpa, io, data, &.{ b, a }, later);
    try testing.expectEqual(3, t.aged);
    const rows = try dir.readFileAlloc(io, "scrubbed.tsv", arena, .unlimited);
    try testing.expectEqual(1, std.mem.count(u8, rows, "\n"));
    var idx = try dir.openDir(io, index_dir, .{ .iterate = true });
    defer idx.close(io);
    var it = idx.iterate();
    try testing.expect(std.mem.startsWith(u8, (try it.next(io)).?.name, try arena.print("{f}.mastery.cfd", .{Date.fromDay(20_000 + aged_days)})));
    try testing.expect(try it.next(io) == null);

    // forgotten.txt cut short by hand: a row past its end is read whole again
    try dir.writeFile(io, .{ .sub_path = "forgotten.txt", .data = try arena.print("{s}\n", .{b}) });
    t = try tend(gpa, io, data, &.{}, null);
    try testing.expectEqual(1, t.files);
}

test "quarantined segments by name, never a temp file" {
    try testing.expect(isSegmentName("mastery.7.1761955200"));
    try testing.expect(!isSegmentName("mastery.7"));
    try testing.expect(!isSegmentName(".scrub.tmp"));
    try testing.expect(!isSegmentName("mastery.7.1761955200.tmp"));
    try testing.expect(!isSegmentName("other.7.1"));
    try testing.expect(!isSegmentName("timeline..1"));
}

test "sealed day files by name: set-aside clashes too, never an open one" {
    try testing.expect(sealedDay("2026-11-01.summary.cfd") != null);
    try testing.expect(sealedDay("2026-11-01.timeline.cfd.clash-1761955200") != null);
    try testing.expect(sealedDay("2026-11-01.summary.cfd.part") == null);
    try testing.expect(sealedDay("2026-11-01.other.cfd") == null);
    try testing.expect(sealedDay("forgotten.txt") == null);
}

test "the matcher finds a PUUID inside a longer run, and nothing else" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const p = try fakePuuid(arena, 'q');
    var m: Matcher = try .init(arena, &.{p});
    try testing.expect(m.any(try arena.print("\x00N{s}N{s}", .{ p[0..77], p })));
    try testing.expect(!m.any(try arena.print("\x00{s}\x00{s}", .{ p[0..77], p[1..] })));
    try testing.expect(!m.any(""));
}
