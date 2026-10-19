//! Timeline digests (timeline.digests): the part of a compact timeline that curves, lean,
//! lane-model and builds read, so their passes skip the gzip and the events they never
//! look at. Readers (Source) take the digest when it is current, else the stored timeline
//! put through `cut`: the same Timeline either way, so no output depends on the catch-up
//! (`meiolol digest`, src/digests.zig) having run.
//!
//! Kept (since version 1): frames 0..max_frames-1 with total gold, XP, minions and jungle
//! minions (other stats 0); every champion kill (killer, victim, assists), item purchase,
//! sale and undo, and skill-up; reaching level 6; buildings, elite monsters and dragon
//! souls before the last kept frame, without assists. Dropped: the other stats, kill
//! positions and bounties, wards, item destroys, plates, transforms, other level-ups.
//! Bump `version` on any change to what is kept or how: `meiolol digest` then remakes
//! every digest.
//!
//! Row: source = the timelines rowid it was cut from (a re-stored timeline gets a new
//! one, so a stale digest never matches), match_id, data = u8 version + a version 2
//! timeline blob (timeline.encodeStats), uncompressed since version 2: ~5.0 KB against
//! 3.5 KB raw deflate (version 1), but decoding 4x faster, and the box's 2 cores are
//! busy with the crawler.

const std = @import("std");
const store = @import("store");
const timeline = @import("timeline.zig");

const Timeline = timeline.Timeline;
const Event = timeline.Event;

pub const version: u8 = 2;

/// curves' 25 whole minutes need frames 0..26, and its minute count (frames - 2) the
/// frame count up to 27; lean's state at 20 needs 22
pub const max_frames = 27;

pub const stats: timeline.StatSet = .initMany(&.{ .total_gold, .xp, .minions, .jungle_minions });

/// What a digest of `t` decodes to; in `arena`
pub fn cut(arena: std.mem.Allocator, t: Timeline) !Timeline {
    const n = @min(t.frames.len, max_frames);
    const frames = try arena.alloc(timeline.Frame, n);
    for (frames, t.frames[0..n]) |*f, src| {
        f.* = .{ .t_ms = src.t_ms };
        for (f.stats[0..t.participants], src.stats[0..t.participants]) |*to, from| {
            var it = stats.iterator();
            while (it.next()) |s| to[@backingInt(s)] = from[@backingInt(s)];
        }
    }
    const end_ms: i64 = if (t.frames.len > max_frames) frames[n - 1].t_ms else std.math.maxInt(i64);
    const events = try arena.alloc(Event, t.events.len);
    var kept: usize = 0;
    for (t.events) |e| {
        const data: Event.Data = switch (e.data) {
            .champion_kill => |k| .{ .champion_kill = .{
                .killer = k.killer,
                .victim = k.victim,
                .x = 0,
                .y = 0,
                .bounty = 0,
                .shutdown = 0,
                .assists = k.assists,
            } },
            .item_purchased, .item_sold, .item_undo, .skill_level_up => e.data,
            .level_up => |u| if (u.level == 6) e.data else continue,
            .building_kill => |b| if (e.t_ms < end_ms) blk: {
                var c = b;
                c.assists = &.{};
                break :blk .{ .building_kill = c };
            } else continue,
            .elite_monster => |m| if (e.t_ms < end_ms) blk: {
                var c = m;
                c.assists = &.{};
                break :blk .{ .elite_monster = c };
            } else continue,
            .dragon_soul => if (e.t_ms < end_ms) e.data else continue,
            .item_destroyed, .ward_placed, .ward_kill, .turret_plate, .champion_transform => continue,
        };
        events[kept] = .{ .t_ms = e.t_ms, .data = data };
        kept += 1;
    }
    return .{ .participants = t.participants, .frames = frames, .events = events[0..kept] };
}

/// A digest of the full timeline `t`; caller owns it
pub fn encode(gpa: std.mem.Allocator, t: Timeline) ![]u8 {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const blob = try timeline.encodeStats(arena, try cut(arena, t), stats);
    var out: std.Io.Writer.Allocating = try .initCapacity(gpa, blob.len);
    errdefer out.deinit();
    try out.writer.writeByte(version);
    try out.writer.writeAll(blob);
    return out.toOwnedSlice();
}

/// Null for another version's digest
pub fn decode(arena: std.mem.Allocator, bytes: []const u8) !?Timeline {
    if (bytes.len == 0 or bytes[0] != version) return null;
    // assists slice into the bytes, and a statement's column lives only to its next step
    return try timeline.decode(arena, try arena.dupe(u8, bytes[1..]));
}

/// A pass's timelines: a game's digest when current, else its stored timeline, cut.
/// Readers select t.rowid and d.data with
/// `LEFT JOIN timeline.digests d ON d.source = t.rowid AND d.match_id = <match id>`:
/// t's rowid comes from its match_id index, so a full blob is read only for a game
/// without a current digest
/// A digest's read for store.Ahead (?1 match_id, ?2 timelines rowid)
pub const read_ahead = "SELECT data FROM timeline.digests WHERE source = ?2 AND match_id = ?1";

pub const Source = struct {
    full: store.Stmt,
    one: store.Stmt,
    digests: usize = 0,
    fulls: usize = 0,

    pub fn init(db: store.Db) !Source {
        var full = try db.prepare("SELECT data FROM timeline.timelines WHERE rowid = ?");
        errdefer full.deinit();
        return .{
            .full = full,
            .one = try db.prepare("SELECT data FROM timeline.digests WHERE source = ? AND match_id = ?"),
        };
    }

    pub fn deinit(s: *Source) void {
        s.full.deinit();
        s.one.deinit();
    }

    /// As get, looking the digest up: for a pass over many timelines in rowid order,
    /// which reads the digests in theirs (a join in match id order reads them at random)
    pub fn lookup(s: *Source, arena: std.mem.Allocator, source: i64, match_id: []const u8) !Timeline {
        try s.one.bind(.{ source, match_id });
        defer s.one.reset();
        return s.get(arena, source, if (try s.one.step()) s.one.bytes(0) else null);
    }

    /// `source`: t.rowid; `data`: d.data. In `arena`
    pub fn get(s: *Source, arena: std.mem.Allocator, source: i64, data: ?[]const u8) !Timeline {
        if (data) |d| {
            if (decode(arena, d) catch null) |t| {
                s.digests += 1;
                return t;
            }
        }
        try s.full.bind(.{source});
        defer s.full.reset();
        if (!try s.full.step()) return error.NoTimeline;
        const t = try timeline.decode(arena, try store.raw.decompress(arena, s.full.bytes(0)));
        s.fulls += 1;
        return cut(arena, t);
    }
};

const testing = std.testing;

test "a digest decodes to the cut timeline, and the cut keeps what readers use" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const json = try store.raw.decompress(arena, @embedFile("testdata/timeline.json.gz"));
    const t = try timeline.fromJson(arena, json);
    // A longer game: the fixture's 26 frames and 4 more, each a minute on
    var long = try arena.alloc(timeline.Frame, 30);
    @memcpy(long[0..26], t.frames);
    for (long[26..], 26..) |*f, i| {
        f.* = t.frames[25];
        f.t_ms = @intCast(i * 60_000);
    }
    const late: Event = .{ .t_ms = 28 * 60_000, .data = .{ .dragon_soul = .{ .team = 100, .name = "Ocean" } } };
    const events = try std.mem.concat(arena, Event, &.{ t.events, &.{late} });
    for ([_]Timeline{ t, .{ .participants = 10, .frames = long, .events = events } }) |full| {
        const bytes = try encode(testing.allocator, full);
        defer testing.allocator.free(bytes);
        const back = (try decode(arena, bytes)).?;
        const c = try cut(arena, full);
        try testing.expectEqual(c.participants, back.participants);
        try testing.expectEqualDeep(c.frames, back.frames);
        try testing.expectEqualDeep(c.events, back.events);
        try testing.expectEqual(@min(full.frames.len, max_frames), back.frames.len);
        for (back.events) |e| switch (e.data) {
            .ward_placed, .ward_kill, .item_destroyed => return error.TestUnexpectedResult,
            .dragon_soul => try testing.expect(e.t_ms < back.frames[back.frames.len - 1].t_ms or full.frames.len <= max_frames),
            else => {},
        };
        const f = back.frames[14];
        try testing.expectEqual(full.frames[14].get(3, .total_gold), f.get(3, .total_gold));
        try testing.expectEqual(full.frames[14].get(3, .jungle_minions), f.get(3, .jungle_minions));
        try testing.expectEqual(0, f.get(3, .level));
        // Version 1 digests weigh well under the gzipped compact timeline
        const blob = try store.raw.compress(testing.allocator, try timeline.encode(arena, full));
        defer testing.allocator.free(blob);
        try testing.expect(bytes.len < blob.len);
    }
    var other = try encode(testing.allocator, t);
    defer testing.allocator.free(other);
    other[0] = version + 1;
    try testing.expectEqual(null, try decode(arena, other));
}
