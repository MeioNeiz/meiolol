//! match-v5 timeline JSON -> compact per-match blob, and back. A raw timeline is
//! ~700 KB of JSON (~60 KB gzip); this keeps the per-minute participant stats and the
//! events we use in a few KB.
//!
//! Format, before gzip (store.raw.compress). Integers are LEB128 varints, "z" ones
//! zigzag (may be negative); "u8" is one byte.
//!   u8 version (1), u8 participants (n), u8 stats per participant (s), varint frames
//!   per frame: z timestamp ms (delta from previous frame), then for participant ids
//!     1..n the first s `Stat`s, each z delta from that participant's previous frame
//!   varint events, each: u8 `Event.Kind`, z timestamp ms (delta from previous event),
//!     then its `Event.Data` payload fields in declaration order: u8 as one byte, other
//!     ints as z, `assists` as u8 count + ids, other strings as u8 index into `names`
//!     or 255 + varint length + bytes (values Riot adds later survive)
//! Participant id = slot + 1 in the match summary; 0 = none (minion, turret, monster).
//! Version 2 (encodeStats, for digests): as 1 with a varint `Stat` bit mask in place of
//! s, and only those stats per participant. Append to `Stat`, `Event.Kind` and `names`
//! only; any other change bumps version.

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const version = 1;
pub const max_participants = 16;

pub const Stat = enum {
    total_gold,
    current_gold,
    xp,
    level,
    minions,
    jungle_minions,
    x,
    y,
    damage_to_champions,
    damage_taken,
    /// timeEnemySpentControlled: ms of crowd control dealt to enemies
    cc_dealt_ms,
};
pub const stat_count = @typeInfo(Stat).@"enum".field_names.len;
pub const StatSet = std.EnumSet(Stat);

pub const Frame = struct {
    t_ms: i64,
    /// [participant id - 1][stat]
    stats: [max_participants][stat_count]i32 = @splat(@splat(0)),

    pub fn get(f: Frame, participant: u8, stat: Stat) i32 {
        return f.stats[participant - 1][@backingInt(stat)];
    }
};

pub const Event = struct {
    t_ms: i64,
    data: Data,

    pub const Kind = enum(u8) {
        champion_kill = 1,
        item_purchased,
        item_sold,
        item_destroyed,
        item_undo,
        skill_level_up,
        level_up,
        ward_placed,
        ward_kill,
        building_kill,
        turret_plate,
        elite_monster,
        champion_transform,
        dragon_soul,
    };

    pub const Item = struct { participant: u8, item: u32 };
    pub const Ward = struct { participant: u8, ward: []const u8 };

    pub const Data = union(Kind) {
        champion_kill: struct {
            killer: u8,
            victim: u8,
            x: i32,
            y: i32,
            bounty: u32,
            shutdown: u32,
            assists: []const u8,
        },
        item_purchased: Item,
        item_sold: Item,
        item_destroyed: Item,
        item_undo: struct { participant: u8, before: u32, after: u32, gold: i32 },
        skill_level_up: struct { participant: u8, slot: u8, type: []const u8 },
        level_up: struct { participant: u8, level: u8 },
        ward_placed: Ward,
        ward_kill: Ward,
        /// team owns the building
        building_kill: struct {
            killer: u8,
            team: u16,
            building: []const u8,
            lane: []const u8,
            tower: []const u8,
            assists: []const u8,
        },
        turret_plate: struct { killer: u8, team: u16, lane: []const u8 },
        /// team is the killer's
        elite_monster: struct {
            killer: u8,
            team: u16,
            monster: []const u8,
            subtype: []const u8,
            assists: []const u8,
        },
        champion_transform: struct { participant: u8, form: []const u8 },
        dragon_soul: struct { team: u16, name: []const u8 },
    };
};

pub const Timeline = struct {
    participants: u8,
    frames: []const Frame,
    events: []const Event,
};

/// Interned strings; index 255 means inline. Append only
pub const names = [_][]const u8{
    "",
    "YELLOW_TRINKET",
    "CONTROL_WARD",
    "SIGHT_WARD",
    "BLUE_TRINKET",
    "TEEMO_MUSHROOM",
    "UNDEFINED",
    "TOP_LANE",
    "MID_LANE",
    "BOT_LANE",
    "OUTER_TURRET",
    "INNER_TURRET",
    "BASE_TURRET",
    "NEXUS_TURRET",
    "UNDEFINED_TURRET",
    "TOWER_BUILDING",
    "INHIBITOR_BUILDING",
    "DRAGON",
    "BARON_NASHOR",
    "RIFTHERALD",
    "HORDE",
    "ATAKHAN",
    "FIRE_DRAGON",
    "WATER_DRAGON",
    "EARTH_DRAGON",
    "AIR_DRAGON",
    "HEXTECH_DRAGON",
    "CHEMTECH_DRAGON",
    "ELDER_DRAGON",
    "NORMAL",
    "EVOLVE",
    "SLAYER",
    "ASSASSIN",
    "Mountain",
    "Ocean",
    "Infernal",
    "Cloud",
    "Hextech",
    "Chemtech",
};
const inline_name = 255;

comptime {
    std.debug.assert(names.len < inline_name);
}

const json_kinds: std.StaticStringMap(Event.Kind) = .initComptime(.{
    .{ "CHAMPION_KILL", .champion_kill },
    .{ "ITEM_PURCHASED", .item_purchased },
    .{ "ITEM_SOLD", .item_sold },
    .{ "ITEM_DESTROYED", .item_destroyed },
    .{ "ITEM_UNDO", .item_undo },
    .{ "SKILL_LEVEL_UP", .skill_level_up },
    .{ "LEVEL_UP", .level_up },
    .{ "WARD_PLACED", .ward_placed },
    .{ "WARD_KILL", .ward_kill },
    .{ "BUILDING_KILL", .building_kill },
    .{ "TURRET_PLATE_DESTROYED", .turret_plate },
    .{ "ELITE_MONSTER_KILL", .elite_monster },
    .{ "CHAMPION_TRANSFORM", .champion_transform },
    .{ "DRAGON_SOUL_GIVEN", .dragon_soul },
});

const Json = struct {
    info: struct {
        participants: []const struct { participantId: u8 } = &.{},
        frames: []const struct {
            timestamp: i64 = 0,
            participantFrames: std.json.ArrayHashMap(JsonFrame) = .{},
            events: []const JsonEvent = &.{},
        } = &.{},
    },
};

const JsonFrame = struct {
    totalGold: i32 = 0,
    currentGold: i32 = 0,
    xp: i32 = 0,
    level: i32 = 0,
    minionsKilled: i32 = 0,
    jungleMinionsKilled: i32 = 0,
    position: struct { x: i32 = 0, y: i32 = 0 } = .{},
    damageStats: struct {
        totalDamageDoneToChampions: i32 = 0,
        totalDamageTaken: i32 = 0,
    } = .{},
    timeEnemySpentControlled: i32 = 0,
};

const JsonEvent = struct {
    type: []const u8,
    timestamp: i64 = 0,
    participantId: u8 = 0,
    killerId: u8 = 0,
    victimId: u8 = 0,
    creatorId: u8 = 0,
    itemId: u32 = 0,
    beforeId: u32 = 0,
    afterId: u32 = 0,
    goldGain: i32 = 0,
    skillSlot: u8 = 0,
    levelUpType: []const u8 = "",
    level: u8 = 0,
    wardType: []const u8 = "",
    position: struct { x: i32 = 0, y: i32 = 0 } = .{},
    bounty: u32 = 0,
    shutdownBounty: u32 = 0,
    assistingParticipantIds: []const u8 = &.{},
    teamId: u16 = 0,
    killerTeamId: u16 = 0,
    buildingType: []const u8 = "",
    laneType: []const u8 = "",
    towerType: []const u8 = "",
    monsterType: []const u8 = "",
    monsterSubType: []const u8 = "",
    transformType: []const u8 = "",
    name: []const u8 = "",
};

/// Event types left out: derivable (special kills, game end) or noise (pauses, bounties)
pub fn fromJson(arena: Allocator, body: []const u8) !Timeline {
    const doc = try std.json.parseFromSliceLeaky(Json, arena, body, .{ .ignore_unknown_fields = true });
    const n = doc.info.participants.len;
    if (n == 0 or n > max_participants) return error.BadTimeline;

    const frames = try arena.alloc(Frame, doc.info.frames.len);
    var events: std.ArrayList(Event) = .empty;
    for (doc.info.frames, frames) |src, *dst| {
        dst.* = .{ .t_ms = src.timestamp };
        for (0..n) |i| {
            var key_buf: [4]u8 = undefined;
            const key = std.mem.print(&key_buf, "{d}", .{i + 1}) catch unreachable;
            const p = src.participantFrames.map.get(key) orelse continue;
            dst.stats[i] = .{
                p.totalGold,
                p.currentGold,
                p.xp,
                p.level,
                p.minionsKilled,
                p.jungleMinionsKilled,
                p.position.x,
                p.position.y,
                p.damageStats.totalDamageDoneToChampions,
                p.damageStats.totalDamageTaken,
                p.timeEnemySpentControlled,
            };
        }
        for (src.events) |e| {
            const data = eventData(e) orelse continue;
            try events.append(arena, .{ .t_ms = e.timestamp, .data = data });
        }
    }
    return .{ .participants = @intCast(n), .frames = frames, .events = events.items };
}

fn eventData(e: JsonEvent) ?Event.Data {
    const item: Event.Item = .{ .participant = e.participantId, .item = e.itemId };
    return switch (json_kinds.get(e.type) orelse return null) {
        .champion_kill => .{ .champion_kill = .{
            .killer = e.killerId,
            .victim = e.victimId,
            .x = e.position.x,
            .y = e.position.y,
            .bounty = e.bounty,
            .shutdown = e.shutdownBounty,
            .assists = e.assistingParticipantIds,
        } },
        .item_purchased => .{ .item_purchased = item },
        .item_sold => .{ .item_sold = item },
        .item_destroyed => .{ .item_destroyed = item },
        .item_undo => .{ .item_undo = .{
            .participant = e.participantId,
            .before = e.beforeId,
            .after = e.afterId,
            .gold = e.goldGain,
        } },
        .skill_level_up => .{ .skill_level_up = .{
            .participant = e.participantId,
            .slot = e.skillSlot,
            .type = e.levelUpType,
        } },
        .level_up => .{ .level_up = .{ .participant = e.participantId, .level = e.level } },
        .ward_placed => .{ .ward_placed = .{ .participant = e.creatorId, .ward = e.wardType } },
        .ward_kill => .{ .ward_kill = .{ .participant = e.killerId, .ward = e.wardType } },
        .building_kill => .{ .building_kill = .{
            .killer = e.killerId,
            .team = e.teamId,
            .building = e.buildingType,
            .lane = e.laneType,
            .tower = e.towerType,
            .assists = e.assistingParticipantIds,
        } },
        .turret_plate => .{ .turret_plate = .{
            .killer = e.killerId,
            .team = e.teamId,
            .lane = e.laneType,
        } },
        .elite_monster => .{ .elite_monster = .{
            .killer = e.killerId,
            .team = e.killerTeamId,
            .monster = e.monsterType,
            .subtype = e.monsterSubType,
            .assists = e.assistingParticipantIds,
        } },
        .champion_transform => .{ .champion_transform = .{
            .participant = e.participantId,
            .form = e.transformType,
        } },
        .dragon_soul => .{ .dragon_soul = .{ .team = e.teamId, .name = e.name } },
    };
}

/// Uncompressed blob (caller frees)
pub fn encode(gpa: Allocator, t: Timeline) ![]u8 {
    return encodeAs(gpa, t, .full, false);
}

/// Version 2: only `stats` per participant (the rest decode as 0)
pub fn encodeStats(gpa: Allocator, t: Timeline, stats: StatSet) ![]u8 {
    return encodeAs(gpa, t, stats, true);
}

fn encodeAs(gpa: Allocator, t: Timeline, stats: StatSet, masked: bool) ![]u8 {
    var w: Writer = .{ .gpa = gpa };
    errdefer w.out.deinit(gpa);
    try w.byte(if (masked) 2 else version);
    try w.byte(t.participants);
    if (masked) try w.varint(stats.bits.mask) else try w.byte(stat_count);
    try w.varint(t.frames.len);
    var prev: Frame = .{ .t_ms = 0 };
    for (t.frames) |f| {
        try w.z(f.t_ms - prev.t_ms);
        for (f.stats[0..t.participants], prev.stats[0..t.participants]) |now, before| {
            for (now, before, std.enums.values(Stat)) |v, b, s| {
                if (stats.contains(s)) try w.z(@as(i64, v) - b);
            }
        }
        prev = f;
    }
    try w.varint(t.events.len);
    var prev_t: i64 = 0;
    for (t.events) |e| {
        try w.byte(@backingInt(e.data));
        try w.z(e.t_ms - prev_t);
        prev_t = e.t_ms;
        switch (e.data) {
            inline else => |payload| inline for (@typeInfo(@TypeOf(payload)).@"struct".field_names) |name| {
                try w.field(name, @field(payload, name));
            },
        }
    }
    return w.out.toOwnedSlice(gpa);
}

pub fn decode(arena: Allocator, bytes: []const u8) !Timeline {
    var r: Reader = .{ .bytes = bytes };
    const v = try r.byte();
    if (v != version and v != 2) return error.UnknownTimelineVersion;
    const n = try r.byte();
    // Stat ids present, in order; ids from a newer build (>= stat_count) are skipped
    var ids: [256]u8 = undefined;
    var stats: usize = 0;
    if (v == version) {
        stats = try r.byte();
        for (0..stats) |i| ids[i] = @intCast(i);
    } else {
        const mask = try r.varint();
        for (0..64) |i| if (mask >> @intCast(i) & 1 == 1) {
            ids[stats] = @intCast(i);
            stats += 1;
        };
    }
    if (n == 0 or n > max_participants) return error.BadTimeline;
    const frames = try arena.alloc(Frame, try r.count());
    var prev: Frame = .{ .t_ms = 0 };
    for (frames) |*f| {
        f.* = .{ .t_ms = prev.t_ms + try r.z() };
        for (f.stats[0..n], prev.stats[0..n]) |*now, before| {
            // Blobs from a newer build may carry more stats: skip them
            for (ids[0..stats]) |s| {
                const d = try r.z();
                if (s >= stat_count) continue;
                now[s] = std.math.cast(i32, before[s] + d) orelse return error.BadTimeline;
            }
        }
        prev = f.*;
    }
    const events = try arena.alloc(Event, try r.count());
    var prev_t: i64 = 0;
    for (events) |*e| {
        const kind = std.enums.fromInt(Event.Kind, try r.byte()) orelse return error.BadTimeline;
        prev_t += try r.z();
        e.* = .{ .t_ms = prev_t, .data = switch (kind) {
            inline else => |k| blk: {
                var payload: @FieldType(Event.Data, @tagName(k)) = undefined;
                const info = @typeInfo(@TypeOf(payload)).@"struct";
                inline for (info.field_names, info.field_types) |name, T| {
                    @field(payload, name) = try r.field(arena, T, name);
                }
                break :blk @unionInit(Event.Data, @tagName(k), payload);
            },
        } };
    }
    if (r.pos != bytes.len) return error.BadTimeline;
    return .{ .participants = n, .frames = frames, .events = events };
}

const Writer = struct {
    gpa: Allocator,
    out: std.ArrayList(u8) = .empty,

    fn byte(w: *Writer, b: u8) !void {
        try w.out.append(w.gpa, b);
    }

    fn varint(w: *Writer, value: u64) !void {
        var v = value;
        while (v >= 0x80) : (v >>= 7) try w.byte(@as(u8, @truncate(v)) | 0x80);
        try w.byte(@intCast(v));
    }

    fn z(w: *Writer, v: i64) !void {
        try w.varint(@bitCast((v << 1) ^ (v >> 63)));
    }

    fn field(w: *Writer, comptime name: []const u8, v: anytype) !void {
        const T = @TypeOf(v);
        if (T == u8) return w.byte(v);
        if (T != []const u8) return w.z(v);
        if (comptime std.mem.eql(u8, name, "assists")) {
            const ids = v[0..@min(v.len, 255)];
            try w.byte(@intCast(ids.len));
            return w.out.appendSlice(w.gpa, ids);
        }
        for (names, 0..) |known, i| {
            if (std.mem.eql(u8, known, v)) return w.byte(@intCast(i));
        }
        try w.byte(inline_name);
        try w.varint(v.len);
        try w.out.appendSlice(w.gpa, v);
    }
};

const Reader = struct {
    bytes: []const u8,
    pos: usize = 0,

    fn byte(r: *Reader) !u8 {
        if (r.pos >= r.bytes.len) return error.BadTimeline;
        defer r.pos += 1;
        return r.bytes[r.pos];
    }

    fn slice(r: *Reader, len: usize) ![]const u8 {
        if (len > r.bytes.len - r.pos) return error.BadTimeline;
        defer r.pos += len;
        return r.bytes[r.pos..][0..len];
    }

    fn varint(r: *Reader) !u64 {
        var v: u64 = 0;
        var shift: u7 = 0;
        while (shift < 64) : (shift += 7) {
            const b = try r.byte();
            v |= @as(u64, b & 0x7f) << @intCast(shift);
            if (b < 0x80) return v;
        }
        return error.BadTimeline;
    }

    /// A length, bounded by the bytes left so a corrupt blob cannot ask for a huge alloc
    fn count(r: *Reader) !usize {
        const v = try r.varint();
        if (v > r.bytes.len - r.pos) return error.BadTimeline;
        return @intCast(v);
    }

    fn z(r: *Reader) !i64 {
        const u = try r.varint();
        return @as(i64, @bitCast(u >> 1)) ^ -@as(i64, @intCast(u & 1));
    }

    fn field(r: *Reader, arena: Allocator, comptime T: type, comptime name: []const u8) !T {
        if (T == u8) return r.byte();
        if (T != []const u8) return std.math.cast(T, try r.z()) orelse error.BadTimeline;
        if (comptime std.mem.eql(u8, name, "assists")) return r.slice(try r.byte());
        const i = try r.byte();
        if (i != inline_name) return if (i < names.len) names[i] else error.BadTimeline;
        return arena.dupe(u8, try r.slice(try r.count()));
    }
};

const testing = std.testing;

fn fixture(arena: Allocator) ![]u8 {
    const raw = @import("store").raw;
    return raw.decompress(arena, @embedFile("testdata/timeline.json.gz"));
}

test "fixture: stats, events and a lossless round trip" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const t = try fromJson(arena, try fixture(arena));

    try testing.expectEqual(@as(u8, 10), t.participants);
    try testing.expectEqual(@as(usize, 26), t.frames.len);
    const f15 = t.frames[15];
    try testing.expectEqual(@as(i32, 6208), f15.get(1, .total_gold));
    try testing.expectEqual(@as(i32, 8791), f15.get(1, .xp));
    try testing.expectEqual(@as(i32, 12), f15.get(1, .level));
    try testing.expectEqual(@as(i32, 137), f15.get(1, .minions));
    // 999 events less 11 special kills, game end, two bounty events, pause end
    try testing.expectEqual(@as(usize, 984), t.events.len);

    const bytes = try encode(testing.allocator, t);
    defer testing.allocator.free(bytes);
    const back = try decode(arena, bytes);
    const again = try encode(testing.allocator, back);
    defer testing.allocator.free(again);
    try testing.expectEqualSlices(u8, bytes, again);

    var kill: ?Event = null;
    for (back.events) |e| if (e.data == .champion_kill) {
        kill = e;
        break;
    };
    const k = kill.?.data.champion_kill;
    try testing.expectEqual(@as(i64, 57862), kill.?.t_ms);
    try testing.expectEqual(@as(u8, 9), k.killer);
    try testing.expectEqual(@as(u8, 4), k.victim);
    try testing.expectEqual(@as(i32, 10934), k.x);
    try testing.expectEqual(@as(u32, 400), k.bounty);
    try testing.expectEqualSlices(u8, &.{10}, k.assists);

    var dragon = false;
    for (back.events) |e| if (e.data == .elite_monster) {
        dragon = dragon or std.mem.eql(u8, e.data.elite_monster.subtype, "FIRE_DRAGON");
    };
    try testing.expect(dragon);

    const blob = try @import("store").raw.compress(testing.allocator, bytes);
    defer testing.allocator.free(blob);
    try testing.expect(blob.len < 12 * 1024);
}

test "unknown strings survive inline" {
    const events = [_]Event{.{ .t_ms = 5, .data = .{ .elite_monster = .{
        .killer = 3,
        .team = 100,
        .monster = "NEW_MONSTER",
        .subtype = "",
        .assists = &.{ 1, 2 },
    } } }};
    const t: Timeline = .{ .participants = 10, .frames = &.{}, .events = &events };
    const bytes = try encode(testing.allocator, t);
    defer testing.allocator.free(bytes);
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const back = try decode(arena.allocator(), bytes);
    try testing.expectEqualStrings("NEW_MONSTER", back.events[0].data.elite_monster.monster);
    try testing.expectError(error.BadTimeline, decode(arena.allocator(), bytes[0 .. bytes.len - 1]));
}
