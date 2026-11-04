//! Lock rows (docs/plan/ui/champion-locks.md L1): one row per player and game for every
//! champion-role, from the day cubes, which the renderer counts under a champion page's
//! locks. A row decodes back to the cube's builds.Seat exactly (as far as builds reads it:
//! purchase times to the minute, the skill order rather than the points behind it), so
//! counting rows with builds.Builder gives the same file as builds --site. No match id or
//! player key: rows never leave the box, answers are aggregates.

const std = @import("std");
const core = @import("core");
const builds = @import("builds.zig");
const cubes = @import("cubes.zig");
const ddragon = @import("ddragon.zig");
const flat = @import("site/flat.zig");

const Allocator = std.mem.Allocator;
const Role = core.Role;

/// Ids to small codes, 0 for none: champions and perks (runes, shards, styles, spells) in
/// a byte, items in two
pub const Dicts = struct {
    platforms: []const []const u8,
    patches: []const []const u8,
    champions: []const u32,
    perks: []const u32,
    items: []const u32,
};

/// One champion-role's rows, oldest day first
pub const Block = struct {
    champion: u32,
    role: Role,
    rows: u32,
    bytes: []const u8,
};

pub const Table = struct {
    /// Unix ms of the first day held
    from_ms: i64,
    dicts: Dicts,
    /// By champion then role
    blocks: []const Block,
    /// The newest patch's, as builds --site counts with: answers count without a fetch
    build: ddragon.BuildData,

    pub fn block(t: *const Table, champion: u32, role: Role) ?*const Block {
        const i = std.sort.binarySearch(Block, t.blocks, Key{ .champion = champion, .role = role }, Key.order) orelse return null;
        return &t.blocks[i];
    }
};

const Key = struct {
    champion: u32,
    role: Role,

    fn order(k: Key, b: Block) std.math.Order {
        if (k.champion != b.champion) return std.math.order(k.champion, b.champion);
        return std.math.order(@backingInt(k.role), @backingInt(b.role));
    }
};

/// A row decoded
pub const Row = struct {
    /// game_start, Unix seconds
    start: u32,
    platform: u8,
    patch: u8,
    seat: builds.Seat,
    /// Champion ids by role, 0 for none; allies' own role is 0
    allies: [Role.count]u32,
    enemies: [Role.count]u32,
};

const flag_won = 1;
const flag_picks = 2;
const flag_rank = 4;
const flag_gold = 8;
const flag_lead = 16;
const flag_start_overflow = 32;
const flag_start_done = 64;
const no_order = 0xff;

/// Builds a Table from games, any order of days
pub const Writer = struct {
    gpa: Allocator,
    from_ms: i64,
    platforms: Codes([]const u8) = .{},
    patches: Codes([]const u8) = .{},
    champions: Codes(u32) = .{},
    perks: Codes(u32) = .{},
    items: Codes(u32) = .{},
    blocks: std.AutoArrayHashMapUnmanaged(Key, Pending) = .empty,
    arena: std.heap.ArenaAllocator,

    const Pending = struct { rows: u32 = 0, bytes: std.ArrayList(u8) = .empty };

    pub fn init(gpa: Allocator, from_ms: i64) Writer {
        return .{ .gpa = gpa, .from_ms = from_ms, .arena = .init(gpa) };
    }

    pub fn deinit(w: *Writer) void {
        for (w.blocks.values()) |*p| p.bytes.deinit(w.gpa);
        w.blocks.deinit(w.gpa);
        inline for (.{ &w.platforms, &w.patches, &w.champions, &w.perks, &w.items }) |c| c.deinit(w.gpa);
        w.arena.deinit();
    }

    /// Every seat of one of a day's games
    pub fn addGame(w: *Writer, d: cubes.Day, g: cubes.Game) !void {
        if (g.start < w.from_ms) return;
        const platform = try w.platforms.codeOwned(w.gpa, w.arena.allocator(), d.string(g.platform));
        const patch = try w.patches.codeOwned(w.gpa, w.arena.allocator(), d.string(g.patch));
        const start: u32 = @intCast(@divFloor(g.start, std.time.ms_per_s));
        for (g.seats, 0..) |s, i| {
            var allies: [Role.count]u32 = @splat(0);
            var enemies: [Role.count]u32 = @splat(0);
            for (g.seats, 0..) |o, j| {
                if (i == j) continue;
                const side = if (o.p.won == s.p.won) &allies else &enemies;
                if (side[@backingInt(o.p.role)] == 0) side[@backingInt(o.p.role)] = o.p.champion;
            }
            allies[@backingInt(s.p.role)] = 0;
            const e = try w.blocks.getOrPut(w.gpa, .{ .champion = s.p.champion, .role = s.p.role });
            if (!e.found_existing) e.value_ptr.* = .{};
            e.value_ptr.rows += 1;
            try w.encode(&e.value_ptr.bytes, .{
                .start = start,
                .platform = platform,
                .patch = patch,
                .seat = if (g.timeline) s else .{ .p = s.p, .k = null, .rank = s.rank },
                .allies = allies,
                .enemies = enemies,
            });
        }
    }

    fn encode(w: *Writer, out: *std.ArrayList(u8), r: Row) !void {
        const gpa = w.gpa;
        const p = r.seat.p;
        var flags: u8 = 0;
        if (p.won) flags |= flag_won;
        if (r.seat.k != null) flags |= flag_picks;
        if (r.seat.rank != null) flags |= flag_rank;
        if (p.gold14 != null) flags |= flag_gold;
        if (p.lead != null) flags |= flag_lead;
        if (r.seat.k) |k| {
            if (k.start_overflow) flags |= flag_start_overflow;
            if (k.start_done) flags |= flag_start_done;
        }
        var head: [8]u8 = undefined;
        std.mem.writeInt(u32, head[0..4], r.start, .little);
        head[4] = flags;
        head[5] = r.platform;
        head[6] = r.patch;
        head[7] = r.seat.rank orelse 0;
        try out.appendSlice(gpa, &head);
        if (p.gold14) |x| try putInt(gpa, out, u16, @intCast(@min(x, std.math.maxInt(u16))));
        if (p.lead) |x| try putInt(gpa, out, i16, @intCast(std.math.clamp(x, std.math.minInt(i16), std.math.maxInt(i16))));
        const perks = [_]u32{ p.keystone, p.primary, p.secondary } ++ p.perks ++ p.shards ++ p.spells;
        for (perks) |x| try out.append(gpa, try w.perks.small(gpa, x));
        try out.append(gpa, try w.champions.small(gpa, p.opponent));
        for (r.allies ++ r.enemies) |x| try out.append(gpa, try w.champions.small(gpa, x));
        const k = r.seat.k orelse return;
        try out.append(gpa, k.start_len);
        for (k.start[0..k.start_len]) |x| try putInt(gpa, out, u16, try w.items.wide(gpa, x));
        try putInt(gpa, out, u32, k.start_spent);
        try putInt(gpa, out, u16, try w.items.wide(gpa, k.boots));
        try out.append(gpa, minute(k.boots_ms));
        try out.append(gpa, k.core_len);
        for (k.core[0..k.core_len], k.core_ms[0..k.core_len]) |x, ms| {
            try putInt(gpa, out, u16, try w.items.wide(gpa, x));
            try out.append(gpa, minute(ms));
        }
        try out.append(gpa, k.skill_ups);
        try out.append(gpa, orderCode(k));
        try out.append(gpa, k.first[0] | k.first[1] << 3 | @as(u8, k.first[2] & 3) << 6);
        try out.append(gpa, k.first[2] >> 2);
        try out.append(gpa, k.path_len);
        var packed_path: [5]u8 = @splat(0);
        for (k.path[0..k.path_len], 0..) |s, i| packed_path[i / 4] |= (s -% 1 & 3) << @intCast(i % 4 * 2);
        try out.appendSlice(gpa, packed_path[0 .. (k.path_len + 3) / 4]);
        var firsts: u8 = 0;
        for (k.firsts, 0..) |on, i| firsts |= @as(u8, @intFromBool(on)) << @intCast(i);
        try out.append(gpa, firsts);
    }

    /// The table, in `arena`, blocks by champion then role; `build` not copied
    pub fn finish(w: *Writer, arena: Allocator, build: ddragon.BuildData) !Table {
        const Sort = struct {
            keys: []const Key,
            pub fn lessThan(c: @This(), a: usize, b: usize) bool {
                const x = c.keys[a];
                const y = c.keys[b];
                if (x.champion != y.champion) return x.champion < y.champion;
                return @backingInt(x.role) < @backingInt(y.role);
            }
        };
        w.blocks.sort(Sort{ .keys = w.blocks.keys() });
        const blocks = try arena.alloc(Block, w.blocks.count());
        for (blocks, w.blocks.keys(), w.blocks.values()) |*b, k, v| b.* = .{
            .champion = k.champion,
            .role = k.role,
            .rows = v.rows,
            .bytes = try arena.dupe(u8, v.bytes.items),
        };
        return .{
            .from_ms = w.from_ms,
            .dicts = .{
                .platforms = try dupeStrings(arena, w.platforms.list.items),
                .patches = try dupeStrings(arena, w.patches.list.items),
                .champions = try arena.dupe(u32, w.champions.list.items),
                .perks = try arena.dupe(u32, w.perks.list.items),
                .items = try arena.dupe(u32, w.items.list.items),
            },
            .blocks = blocks,
            .build = build,
        };
    }
};

fn dupeStrings(arena: Allocator, xs: []const []const u8) ![]const []const u8 {
    const out = try arena.alloc([]const u8, xs.len);
    for (out, xs) |*o, x| o.* = try arena.dupe(u8, x);
    return out;
}

fn minute(ms: i64) u8 {
    return @intCast(std.math.clamp(@divFloor(ms, std.time.ms_per_min), 0, std.math.maxInt(u8)));
}

/// skillOrder's three slots as one byte (no_order without one)
fn orderCode(k: builds.Picks) u8 {
    const o = k.skillOrder() orelse return no_order;
    return @intCast((o[0] - 1) * 16 + (o[1] - 1) * 4 + (o[2] - 1));
}

fn putInt(gpa: Allocator, out: *std.ArrayList(u8), comptime T: type, x: T) !void {
    var b: [@sizeOf(T)]u8 = undefined;
    std.mem.writeInt(T, &b, x, .little);
    try out.appendSlice(gpa, &b);
}

/// Values to codes 1.., 0 for the zero value (or none for strings, never asked)
fn Codes(comptime T: type) type {
    return struct {
        const Self = @This();
        const Map = if (T == []const u8) std.StringHashMapUnmanaged(u16) else std.AutoHashMapUnmanaged(T, u16);
        map: Map = .empty,
        list: std.ArrayList(T) = .empty,

        fn deinit(c: *Self, gpa: Allocator) void {
            c.map.deinit(gpa);
            c.list.deinit(gpa);
        }

        fn code(c: *Self, gpa: Allocator, x: T) !u16 {
            if (T != []const u8) {
                if (x == 0) return 0;
            }
            const e = try c.map.getOrPut(gpa, x);
            if (!e.found_existing) {
                try c.list.append(gpa, x);
                e.value_ptr.* = @intCast(c.list.items.len);
            }
            return e.value_ptr.*;
        }

        /// Strings live in `arena`; codes from 0
        fn codeOwned(c: *Self, gpa: Allocator, arena: Allocator, x: T) !u8 {
            if (c.map.get(x)) |i| return @intCast(i - 1);
            const n = try c.code(gpa, try arena.dupe(u8, x));
            return std.math.cast(u8, n - 1) orelse error.TooManyCodes;
        }

        fn small(c: *Self, gpa: Allocator, x: T) !u8 {
            return std.math.cast(u8, try c.code(gpa, x)) orelse error.TooManyCodes;
        }

        fn wide(c: *Self, gpa: Allocator, x: T) !u16 {
            return c.code(gpa, x);
        }
    };
}

/// Walks a block's rows
pub const Rows = struct {
    t: *const Table,
    b: *const Block,
    at: usize = 0,

    pub fn next(it: *Rows) ?Row {
        if (it.at >= it.b.bytes.len) return null;
        var r: Reader = .{ .bytes = it.b.bytes, .at = it.at, .d = &it.t.dicts };
        const row = r.row(it.b.champion, it.b.role);
        it.at = r.at;
        return row;
    }
};

const Reader = struct {
    bytes: []const u8,
    at: usize,
    d: *const Dicts,

    fn byte(r: *Reader) u8 {
        defer r.at += 1;
        return r.bytes[r.at];
    }

    fn int(r: *Reader, comptime T: type) T {
        defer r.at += @sizeOf(T);
        return std.mem.readInt(T, r.bytes[r.at..][0..@sizeOf(T)], .little);
    }

    fn of(list: []const u32, c: u16) u32 {
        return if (c == 0) 0 else list[c - 1];
    }

    fn perk(r: *Reader) u32 {
        return of(r.d.perks, r.byte());
    }

    fn champion(r: *Reader) u32 {
        return of(r.d.champions, r.byte());
    }

    fn item(r: *Reader) u32 {
        return of(r.d.items, r.int(u16));
    }

    fn row(r: *Reader, champion_id: u32, role: Role) Row {
        const start = r.int(u32);
        const flags = r.byte();
        const platform = r.byte();
        const patch = r.byte();
        const rank = r.byte();
        var p: builds.Player = .{ .champion = champion_id, .role = role, .won = flags & flag_won != 0 };
        if (flags & flag_gold != 0) p.gold14 = r.int(u16);
        if (flags & flag_lead != 0) p.lead = r.int(i16);
        p.keystone = r.perk();
        p.primary = r.perk();
        p.secondary = r.perk();
        for (&p.perks) |*x| x.* = r.perk();
        for (&p.shards) |*x| x.* = r.perk();
        for (&p.spells) |*x| x.* = r.perk();
        p.opponent = r.champion();
        var allies: [Role.count]u32 = undefined;
        var enemies: [Role.count]u32 = undefined;
        for (&allies) |*x| x.* = r.champion();
        for (&enemies) |*x| x.* = r.champion();
        return .{
            .start = start,
            .platform = platform,
            .patch = patch,
            .seat = .{ .p = p, .k = if (flags & flag_picks != 0) r.picks(flags) else null, .rank = if (flags & flag_rank != 0) rank else null },
            .allies = allies,
            .enemies = enemies,
        };
    }

    fn picks(r: *Reader, flags: u8) builds.Picks {
        var k: builds.Picks = .{
            .start_overflow = flags & flag_start_overflow != 0,
            .start_done = flags & flag_start_done != 0,
        };
        k.start_len = r.byte();
        for (k.start[0..k.start_len]) |*x| x.* = r.item();
        k.start_spent = r.int(u32);
        k.boots = r.item();
        k.boots_ms = @as(i64, r.byte()) * std.time.ms_per_min;
        k.core_len = r.byte();
        for (k.core[0..k.core_len], k.core_ms[0..k.core_len]) |*x, *ms| {
            x.* = r.item();
            ms.* = @as(i64, r.byte()) * std.time.ms_per_min;
        }
        k.skill_ups = r.byte();
        const order = r.byte();
        // Points and times that give skillOrder() the stored order
        if (order != no_order) {
            const slots = [3]u8{ order / 16, order / 4 % 4, order % 4 };
            for (slots, 0..) |s, i| {
                k.points[s] = @intCast(3 - i);
                k.reached_ms[s] = @intCast(i);
            }
        }
        const f0 = r.byte();
        const f1 = r.byte();
        k.first = .{ f0 & 7, f0 >> 3 & 7, f0 >> 6 | (f1 & 1) << 2 };
        k.path_len = r.byte();
        const packed_path = r.bytes[r.at..][0 .. (k.path_len + 3) / 4];
        r.at += packed_path.len;
        for (k.path[0..k.path_len], 0..) |*s, i| s.* = (packed_path[i / 4] >> @intCast(i % 4 * 2) & 3) + 1;
        const firsts = r.byte();
        for (&k.firsts, 0..) |*on, i| on.* = firsts >> @intCast(i) & 1 != 0;
        return k;
    }
};

const magic = "MEIOLKR1";

pub fn write(w: *std.Io.Writer, t: Table) !void {
    try w.writeAll(magic);
    try w.writeInt(u64, flat.fingerprint(Table), .little);
    try flat.write(w, t);
}

/// null for another format
pub fn read(r: *std.Io.Reader, arena: Allocator) !?Table {
    var head: [magic.len + 8]u8 = undefined;
    r.readSliceAll(&head) catch return null;
    if (!std.mem.eql(u8, head[0..magic.len], magic)) return null;
    if (std.mem.readInt(u64, head[magic.len..][0..8], .little) != flat.fingerprint(Table)) return null;
    return flat.read(Table, r, arena) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => null,
    };
}

fn testSeat(champion: u32, role: Role, won: bool, opponent: u32) builds.Seat {
    var k: builds.Picks = .{ .start_len = 2, .start_spent = 500, .start_done = true, .boots = 3047, .boots_ms = 7 * 60_000 + 59_999 };
    k.start[0] = 1055;
    k.start[1] = 2003;
    k.core_len = 3;
    k.core[0..3].* = .{ 3071, 6333, 3053 };
    k.core_ms[0..3].* = .{ 11 * 60_000 + 5, 18 * 60_000, 25 * 60_000 + 30_000 };
    k.points = .{ 5, 2, 3, 2 };
    k.reached_ms = .{ 1, 2, 3, 4 };
    k.skill_ups = 12;
    k.first = .{ 1, 3, 2 };
    k.path_len = 12;
    k.path[0..12].* = .{ 1, 3, 2, 1, 1, 4, 1, 3, 1, 2, 4, 3 };
    k.firsts = .{ true, false, true, false };
    return .{
        .p = .{
            .champion = champion,
            .role = role,
            .won = won,
            .keystone = 8010,
            .primary = 8000,
            .secondary = 8400,
            .perks = .{ 9111, 9104, 8299, 8444, 8242 },
            .shards = .{ 5008, 5008, 5011 },
            .spells = .{ 4, 12 },
            .opponent = opponent,
            .gold14 = 5400,
            .lead = -310,
        },
        .k = k,
        .rank = 3,
    };
}

test "rows decode to the seats builds reads" {
    const gpa = std.testing.allocator;
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    var seats: [10]builds.Seat = undefined;
    for (&seats, 0..) |*s, i| {
        const role: Role = @fromBackingInt(@intCast(i % 5));
        s.* = testSeat(@intCast(100 + i), role, i < 5, @intCast(if (i < 5) 105 + i else 95 + i));
    }
    seats[7].k = null;
    seats[8].rank = null;
    seats[8].p.lead = null;
    const day: cubes.Day = .{ .day = 0, .strings = &.{ "EUW1", "16.21" }, .games = &.{} };
    var w: Writer = .init(gpa, 0);
    defer w.deinit();
    try w.addGame(day, .{
        .start = 1_761_000_000_000,
        .rowid = 1,
        .source = 0,
        .platform = 0,
        .patch = 1,
        .hash = 0,
        .curves = .none,
        .lanes = &.{},
        .timeline = true,
        .seats = &seats,
    });
    const t = try w.finish(arena.allocator(), .{ .version = "16.21.1", .legendary = &.{3071}, .trinkets = &.{}, .boots = &.{.{ 3047, 3047 }}, .items = &.{}, .runes = &.{}, .spells = &.{} });
    var buf: std.Io.Writer.Allocating = .init(gpa);
    defer buf.deinit();
    try write(&buf.writer, t);
    var r: std.Io.Reader = .fixed(buf.written());
    const back = (try read(&r, arena.allocator())).?;
    try std.testing.expectEqual(10, back.blocks.len);
    try std.testing.expectEqualStrings("16.21", back.dicts.patches[0]);
    try std.testing.expectEqualStrings("16.21.1", back.build.version);
    for (seats) |s| {
        var it: Rows = .{ .t = &back, .b = back.block(s.p.champion, s.p.role).? };
        const row = it.next().?;
        try std.testing.expectEqual(null, it.next());
        try std.testing.expectEqual(1_761_000_000, row.start);
        try std.testing.expectEqual(s.p, row.seat.p);
        try std.testing.expectEqual(s.rank, row.seat.rank);
        try std.testing.expectEqual(s.p.opponent, row.enemies[@backingInt(s.p.role)]);
        try std.testing.expectEqual(0, row.allies[@backingInt(s.p.role)]);
        const want = s.k orelse {
            try std.testing.expectEqual(null, row.seat.k);
            continue;
        };
        const got = row.seat.k.?;
        try std.testing.expectEqualSlices(u32, want.start[0..want.start_len], got.start[0..got.start_len]);
        try std.testing.expectEqual(want.start_spent, got.start_spent);
        try std.testing.expectEqual(want.start_done, got.start_done);
        try std.testing.expectEqual(want.boots, got.boots);
        try std.testing.expectEqual(7 * 60_000, got.boots_ms);
        try std.testing.expectEqualSlices(u32, want.core[0..3], got.core[0..got.core_len]);
        for (want.core_ms[0..3], got.core_ms[0..3]) |a, b| try std.testing.expectEqual(@divFloor(a, 60_000), @divFloor(b, 60_000));
        try std.testing.expectEqual(want.skillOrder(), got.skillOrder());
        try std.testing.expectEqual(want.skillPath(), got.skillPath());
        try std.testing.expectEqual(want.first, got.first);
        try std.testing.expectEqual(want.firsts, got.firsts);
    }
}
