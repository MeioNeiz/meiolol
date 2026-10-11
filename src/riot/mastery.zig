//! champion-mastery-v4 response -> one compact blob per player (~1 KB vs ~70 KB JSON).
//! Keeps champion, level, points and last play; drops derived and seasonal fields.
//!
//! Format: u8 version (1), varint entries, then per entry, sorted by champion id:
//! varint champion id delta, varint level, varint points, varint hours between last
//! play and `fetched_at` (stored beside the blob), rounded down.

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const version = 1;

pub const Entry = struct {
    champion: u32,
    level: u32,
    points: u32,
    /// Unix seconds; decoded ones are up to an hour late
    last_play: i64,
};

const Json = struct {
    championId: u32,
    championLevel: u32 = 0,
    championPoints: u32 = 0,
    lastPlayTime: i64 = 0,
};

/// Entries sorted by champion id, in `arena`
pub fn fromJson(arena: Allocator, body: []const u8) ![]Entry {
    const rows = try std.json.parseFromSliceLeaky([]const Json, arena, body, .{ .ignore_unknown_fields = true });
    const out = try arena.alloc(Entry, rows.len);
    for (rows, out) |r, *e| e.* = .{
        .champion = r.championId,
        .level = r.championLevel,
        .points = r.championPoints,
        .last_play = @divFloor(r.lastPlayTime, 1000),
    };
    std.mem.sort(Entry, out, {}, byChampion);
    return out;
}

fn byChampion(_: void, a: Entry, b: Entry) bool {
    return a.champion < b.champion;
}

/// Caller frees. `entries` sorted by champion id; `fetched_at` in unix seconds
pub fn encode(gpa: Allocator, entries: []const Entry, fetched_at: i64) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(gpa);
    try out.append(gpa, version);
    try varint(&out, gpa, entries.len);
    var prev: u32 = 0;
    for (entries) |e| {
        if (e.champion < prev) return error.Unsorted;
        try varint(&out, gpa, e.champion - prev);
        prev = e.champion;
        try varint(&out, gpa, e.level);
        try varint(&out, gpa, e.points);
        try varint(&out, gpa, @intCast(@max(0, @divFloor(fetched_at - e.last_play, 3600))));
    }
    return out.toOwnedSlice(gpa);
}

pub fn decode(arena: Allocator, blob: []const u8, fetched_at: i64) ![]Entry {
    var r: Reader = .{ .bytes = blob };
    if (try r.byte() != version) return error.UnknownMasteryVersion;
    const n = try r.varint();
    if (n > blob.len) return error.BadMastery;
    const out = try arena.alloc(Entry, @intCast(n));
    var champion: u64 = 0;
    for (out) |*e| {
        champion += try r.varint();
        e.* = .{
            .champion = std.math.cast(u32, champion) orelse return error.BadMastery,
            .level = std.math.cast(u32, try r.varint()) orelse return error.BadMastery,
            .points = std.math.cast(u32, try r.varint()) orelse return error.BadMastery,
            .last_play = fetched_at - @as(i64, @intCast(try r.varint())) * 3600,
        };
    }
    if (r.pos != blob.len) return error.BadMastery;
    return out;
}

fn varint(out: *std.ArrayList(u8), gpa: Allocator, value: u64) !void {
    var v = value;
    while (v >= 0x80) : (v >>= 7) try out.append(gpa, @as(u8, @truncate(v)) | 0x80);
    try out.append(gpa, @intCast(v));
}

const Reader = struct {
    bytes: []const u8,
    pos: usize = 0,

    fn byte(r: *Reader) !u8 {
        if (r.pos >= r.bytes.len) return error.BadMastery;
        defer r.pos += 1;
        return r.bytes[r.pos];
    }

    fn varint(r: *Reader) !u64 {
        var v: u64 = 0;
        var shift: u7 = 0;
        while (shift < 64) : (shift += 7) {
            const b = try r.byte();
            v |= @as(u64, b & 0x7f) << @intCast(shift);
            if (b < 0x80) return v;
        }
        return error.BadMastery;
    }
};

const testing = std.testing;

test "fixture round trip" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const raw = @import("store").raw;
    const body = try raw.decompress(arena, @embedFile("testdata/mastery.json.gz"));
    const entries = try fromJson(arena, body);
    try testing.expectEqual(@as(usize, 102), entries.len);

    const fetched_at: i64 = 1791680000;
    const blob = try encode(testing.allocator, entries, fetched_at);
    defer testing.allocator.free(blob);
    try testing.expect(blob.len < 1024);
    const back = try decode(arena, blob, fetched_at);
    try testing.expectEqual(entries.len, back.len);
    for (entries, back) |a, b| {
        try testing.expectEqual(a.champion, b.champion);
        try testing.expectEqual(a.points, b.points);
        try testing.expect(b.last_play >= a.last_play and b.last_play - a.last_play < 3600);
    }
    var found = false;
    for (back) |e| if (e.champion == 38) {
        try testing.expectEqual(@as(u32, 61), e.level);
        try testing.expectEqual(@as(u32, 646745), e.points);
        found = true;
    };
    try testing.expect(found);
    try testing.expectError(error.BadMastery, decode(arena, blob[0 .. blob.len - 1], fetched_at));
}
