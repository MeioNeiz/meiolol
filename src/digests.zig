//! `meiolol digest`: timeline.digests (src/riot/digest.zig) for the timelines stored
//! since the newest digest, in rowid order and chunks (one short write transaction
//! each, so the crawler's writer waits ms, not minutes); every one again when the newest
//! digest is another version, or with --full (also drops digests of re-stored or pruned
//! timelines, which readers never match). Readers fall back to the full timeline for a
//! game without one, so running late changes no output, only its pass time.

const std = @import("std");
const store = @import("store");
const timeline = @import("riot/timeline.zig");
const digest = @import("riot/digest.zig");

const log = std.log.scoped(.digest);

pub const Options = struct {
    full: bool = false,
    chunk: usize = 2000,
    /// Between chunks, so the crawler's writer gets the lock
    pause_ms: u32 = 0,
};

pub const Summary = struct {
    made: usize = 0,
    /// Timelines that did not decode: no digest, readers skip them as before
    failed: usize = 0,
    bytes: u64 = 0,
    /// Timelines' gzip bytes read
    full_bytes: u64 = 0,
    /// Decode time of the full timelines (gunzip and decode) and of the digests made
    full_ns: u64 = 0,
    digest_ns: u64 = 0,
};

pub fn catchUp(gpa: std.mem.Allocator, io: std.Io, db: store.Db, o: Options) !Summary {
    var from: i64 = 0;
    var newest = try db.prepare("SELECT source, data FROM timeline.digests ORDER BY source DESC LIMIT 1");
    defer newest.deinit();
    try newest.bind(.{});
    const have = try newest.step();
    const current = have and std.mem.startsWith(u8, newest.bytes(1), &.{digest.version});
    if (have and current and !o.full) from = newest.int(0);
    newest.reset();
    if (have and (!current or o.full)) {
        log.info("dropping every digest: {s}", .{if (o.full) "--full" else "another version"});
        try db.exec("DELETE FROM timeline.digests");
    }

    var q = try db.prepare("SELECT rowid, match_id, data FROM timeline.timelines WHERE rowid > ? ORDER BY rowid LIMIT ?");
    defer q.deinit();
    var put = try db.prepare("INSERT OR REPLACE INTO timeline.digests VALUES (?,?,?)");
    defer put.deinit();
    var sum: Summary = .{};
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    var scratch_state: std.heap.ArenaAllocator = .init(gpa);
    defer scratch_state.deinit();
    const Row = struct { source: i64, match_id: []const u8, data: []const u8 };
    var rows: std.ArrayList(Row) = .empty;
    defer rows.deinit(gpa);
    var chunks: usize = 0;
    while (true) {
        _ = arena_state.reset(.retain_capacity);
        const arena = arena_state.allocator();
        rows.clearRetainingCapacity();
        var last = from;
        try q.bind(.{ from, o.chunk });
        while (try q.step()) {
            const r = q.row(struct { rowid: i64, match_id: []const u8, data: []const u8 });
            last = r.rowid;
            sum.full_bytes += r.data.len;
            _ = scratch_state.reset(.retain_capacity);
            const scratch = scratch_state.allocator();
            const t0 = std.Io.Clock.awake.now(io).toNanoseconds();
            const t = timeline.decode(scratch, store.raw.decompress(scratch, r.data) catch {
                sum.failed += 1;
                continue;
            }) catch {
                sum.failed += 1;
                continue;
            };
            const t1 = std.Io.Clock.awake.now(io).toNanoseconds();
            const bytes = try digest.encode(arena, t);
            const t2 = std.Io.Clock.awake.now(io).toNanoseconds();
            _ = try digest.decode(scratch, bytes);
            const t3 = std.Io.Clock.awake.now(io).toNanoseconds();
            sum.full_ns += @intCast(t1 - t0);
            sum.digest_ns += @intCast(t3 - t2);
            sum.bytes += bytes.len;
            try rows.append(gpa, .{ .source = r.rowid, .match_id = try arena.dupe(u8, r.match_id), .data = bytes });
        }
        q.reset();
        if (last == from) break;
        from = last;
        if (rows.items.len > 0) {
            try db.begin();
            errdefer db.rollback();
            for (rows.items) |r| try put.exec(.{ r.source, r.match_id, store.Blob{ .bytes = r.data } });
            try db.commit();
            sum.made += rows.items.len;
        }
        chunks += 1;
        if (chunks % 50 == 0) log.info("{d} digests to timelines rowid {d}", .{ sum.made, from });
        if (o.pause_ms > 0) try io.sleep(.fromMilliseconds(o.pause_ms), .awake);
    }
    return sum;
}

const testing = std.testing;

test "catch-up: new timelines only, all again on a version change" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const json = try store.raw.decompress(arena, @embedFile("riot/testdata/timeline.json.gz"));
    const blob = try store.raw.compress(arena, try timeline.encode(arena, try timeline.fromJson(arena, json)));
    const db = try store.schema.memory();
    defer db.close();
    const io = testing.io;
    for (0..3) |i| {
        try db.run("INSERT INTO timeline.timelines VALUES (?,26,0,?)", .{ try arena.print("EUW1_{d}", .{i}), store.Blob{ .bytes = blob } });
    }
    try db.exec("INSERT INTO timeline.timelines VALUES ('EUW1_bad',1,0,x'00')");
    var s = try catchUp(testing.allocator, io, db, .{ .chunk = 2 });
    try testing.expectEqual(3, s.made);
    try testing.expectEqual(1, s.failed);
    s = try catchUp(testing.allocator, io, db, .{});
    try testing.expectEqual(0, s.made);
    // Re-stored: a new rowid, so a new digest; the old one matches nothing
    try db.run("INSERT OR REPLACE INTO timeline.timelines VALUES ('EUW1_1',26,0,?)", .{store.Blob{ .bytes = blob }});
    s = try catchUp(testing.allocator, io, db, .{});
    try testing.expectEqual(1, s.made);
    try testing.expectEqual(4, try db.scalar("SELECT count(*) FROM timeline.digests", .{}));
    try db.exec("UPDATE timeline.digests SET data = x'00' WHERE source = (SELECT max(source) FROM timeline.digests)");
    s = try catchUp(testing.allocator, io, db, .{});
    try testing.expectEqual(3, s.made);
    try testing.expectEqual(3, try db.scalar("SELECT count(*) FROM timeline.digests", .{}));
    try testing.expectEqual(0, try db.scalar(
        \\SELECT count(*) FROM timeline.digests d
        \\WHERE NOT EXISTS (SELECT 1 FROM timeline.timelines t WHERE t.rowid = d.source AND t.match_id = d.match_id)
    , .{}));
}

test "digests hold no PUUID: forget has nothing to erase in them" {
    const forget = @import("forget.zig");
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const json = try store.raw.decompress(arena, @embedFile("riot/testdata/timeline.json.gz"));
    const Doc = struct { metadata: struct { participants: []const []const u8 } };
    const doc = try std.json.parseFromSliceLeaky(Doc, arena, json, .{ .ignore_unknown_fields = true });
    try testing.expectEqual(10, doc.metadata.participants.len);
    const blob = try store.raw.compress(arena, try timeline.encode(arena, try timeline.fromJson(arena, json)));
    const db = try store.schema.memory();
    defer db.close();
    try db.run("INSERT INTO timeline.timelines VALUES ('EUW1_1',26,0,?)", .{store.Blob{ .bytes = blob }});
    _ = try catchUp(testing.allocator, testing.io, db, .{});
    const before = try onlyDigest(arena, db);
    for (doc.metadata.participants) |puuid| {
        try testing.expect(std.mem.find(u8, before, puuid) == null);
        _ = try forget.forget(db, puuid, 7, .record);
    }
    try testing.expectEqualSlices(u8, before, try onlyDigest(arena, db));
}

fn onlyDigest(arena: std.mem.Allocator, db: store.Db) ![]const u8 {
    var q = try db.prepare("SELECT data FROM timeline.digests");
    defer q.deinit();
    try q.bind(.{});
    try testing.expect(try q.step());
    const data = try arena.dupe(u8, q.bytes(0));
    try testing.expect(!try q.step());
    return data;
}
