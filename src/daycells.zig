//! `meiolol daycells` (docs/plan/meio-middle.md TS2, TS4): the day cubes summed per patch,
//! day since that patch's first EUW1 game, platform, rank bracket and champion-role, into
//! a TSV that outlives the cubes' 30 days and their format key. Day -1 and below: a
//! region that patched before EUW1 (KR). Reads the cubes only.

const std = @import("std");
const core = @import("core");
const store = @import("store");
const cubes = @import("cubes.zig");
const endpoints = @import("riot/endpoints.zig");
const par = @import("par.zig");

const Allocator = std.mem.Allocator;
const Role = core.Role;
const curvesfile = core.curvesfile;
const day_ms = std.time.ms_per_day;
const log = std.log.scoped(.daycells);

/// As truth's: a seat's stored tier, which is looked up after the game
pub const brackets = [_][]const u8{ "unranked", "Iron-Silver", "Gold-Emerald", "Diamond+" };

pub const Cell = struct { patch: u16, day: i16, platform: u8, bracket: u2, role: Role, champion: u16 };
pub const Count = struct { games: u32 = 0, wins: u32 = 0 };
pub const First = struct { patch: u16, ms: i64 };

pub const Result = struct {
    /// Ascending by patch
    firsts: []First,
    /// Sorted by key (patch, day, platform, bracket, role, champion)
    cells: std.AutoArrayHashMapUnmanaged(u64, Count),
    /// Seats of a patch never played on EUW1, or with no champion, platform or patch
    skipped: u64,
};

fn pack(c: Cell) u64 {
    const day: u16 = @bitCast(c.day);
    return @as(u64, c.patch) << 45 | @as(u64, day ^ 0x8000) << 29 | @as(u64, c.platform) << 21 |
        @as(u64, c.bracket) << 19 | @as(u64, @backingInt(c.role)) << 16 | c.champion;
}

pub fn unpack(k: u64) Cell {
    const day: u16 = @truncate(k >> 29);
    return .{
        .patch = @truncate(k >> 45),
        .day = @bitCast(day ^ 0x8000),
        .platform = @truncate(k >> 21),
        .bracket = @truncate(k >> 19),
        .role = @fromBackingInt(@intCast(@as(u3, @truncate(k >> 16)))),
        .champion = @truncate(k),
    };
}

/// "16.21" as 1621
pub fn patchNumber(patch: []const u8) ?u16 {
    const dot = std.mem.findScalar(u8, patch, '.') orelse return null;
    const major = std.fmt.parseInt(u16, patch[0..dot], 10) catch return null;
    const minor = std.fmt.parseInt(u16, patch[dot + 1 ..], 10) catch return null;
    if (minor >= 100) return null;
    const base = std.math.mul(u16, major, 100) catch return null;
    return std.math.add(u16, base, minor) catch null;
}

fn bracketOf(tier: u8) u2 {
    if (tier >= store.schema.tiers.len) return 0;
    const rank = curvesfile.tierRank(store.schema.tiers[tier]) orelse return 0;
    return @intCast(@backingInt(curvesfile.Bracket.ofRank(rank)));
}

pub fn platformIndex(id: []const u8) ?u8 {
    for (endpoints.platform_ids, 0..) |p, i| if (std.mem.eql(u8, p, id)) return @intCast(i);
    return null;
}

fn noteFirst(gpa: Allocator, list: *std.ArrayList(First), f: First) !void {
    for (list.items) |*have| if (have.patch == f.patch) {
        have.ms = @min(have.ms, f.ms);
        return;
    };
    try list.append(gpa, f);
}

fn firstOf(firsts: []const First, patch: u16) ?i64 {
    for (firsts) |f| if (f.patch == patch) return f.ms;
    return null;
}

/// One game's seats into `cells`; seats skipped
pub fn addGame(gpa: Allocator, cells: *std.AutoArrayHashMapUnmanaged(u64, Count), g: cubes.Game, d: cubes.Day, firsts: []const First) !u64 {
    const patch = patchNumber(d.string(g.patch));
    const platform = platformIndex(d.string(g.platform));
    const first = if (patch) |p| firstOf(firsts, p) else null;
    if (platform == null or first == null) return g.seats.len;
    const day = std.math.cast(i16, @divFloor(g.start - first.?, day_ms)) orelse return g.seats.len;
    var skipped: u64 = 0;
    for (g.seats) |s| {
        const champion = std.math.cast(u16, s.p.champion) orelse 0;
        if (champion == 0) {
            skipped += 1;
            continue;
        }
        const k = pack(.{
            .patch = patch.?,
            .day = day,
            .platform = platform.?,
            .bracket = if (s.rank) |r| bracketOf(r) else 0,
            .role = s.p.role,
            .champion = champion,
        });
        const e = try cells.getOrPut(gpa, k);
        if (!e.found_existing) e.value_ptr.* = .{};
        e.value_ptr.games += 1;
        e.value_ptr.wins += @intFromBool(s.p.won);
    }
    return skipped;
}

const DayOut = struct {
    firsts: std.ArrayList(First) = .empty,
    cells: std.AutoArrayHashMapUnmanaged(u64, Count) = .empty,
    skipped: u64 = 0,

    fn deinit(o: *DayOut, gpa: Allocator) void {
        o.firsts.deinit(gpa);
        o.cells.deinit(gpa);
    }
};

/// Every day file in `cube_dir`, twice: each patch's first EUW1 game, then the sums.
/// Result in `arena`
pub fn collect(gpa: Allocator, arena: Allocator, io: std.Io, cube_dir: []const u8, threads: u8) !Result {
    const s = try cubes.Store.open(gpa, io, cube_dir);
    defer s.deinit();
    const days = try s.days(gpa, 0);
    defer gpa.free(days);
    const outs = try gpa.alloc(DayOut, days.len);
    @memset(outs, .{});
    defer {
        for (outs) |*o| o.deinit(gpa);
        gpa.free(outs);
    }
    const Ctx = struct {
        gpa: Allocator,
        s: *cubes.Store,
        days: []const i64,
        outs: []DayOut,
        firsts: []const First,
        sums: bool,
        fn body(c: @This(), i: usize) !void {
            var day_arena: std.heap.ArenaAllocator = .init(c.gpa);
            defer day_arena.deinit();
            const d = try c.s.need(c.gpa, day_arena.allocator(), c.days[i]);
            const o = &c.outs[i];
            for (d.games) |g| {
                if (c.sums) {
                    o.skipped += try addGame(c.gpa, &o.cells, g, d, c.firsts);
                    continue;
                }
                if (!std.mem.eql(u8, d.string(g.platform), "EUW1")) continue;
                const patch = patchNumber(d.string(g.patch)) orelse continue;
                try noteFirst(c.gpa, &o.firsts, .{ .patch = patch, .ms = g.start });
            }
        }
    };
    var ctx: Ctx = .{ .gpa = gpa, .s = s, .days = days, .outs = outs, .firsts = &.{}, .sums = false };
    try par.forEachUpTo(io, days.len, @max(threads, 1), ctx, Ctx.body);

    var firsts: std.ArrayList(First) = .empty;
    for (outs) |o| for (o.firsts.items) |f| try noteFirst(arena, &firsts, f);
    std.mem.sort(First, firsts.items, {}, struct {
        fn less(_: void, a: First, b: First) bool {
            return a.patch < b.patch;
        }
    }.less);

    ctx.firsts = firsts.items;
    ctx.sums = true;
    try par.forEachUpTo(io, days.len, @max(threads, 1), ctx, Ctx.body);
    var out: Result = .{ .firsts = firsts.items, .cells = .empty, .skipped = 0 };
    for (outs) |o| {
        out.skipped += o.skipped;
        var it = o.cells.iterator();
        while (it.next()) |e| {
            const m = try out.cells.getOrPut(arena, e.key_ptr.*);
            if (!m.found_existing) m.value_ptr.* = .{};
            m.value_ptr.games += e.value_ptr.games;
            m.value_ptr.wins += e.value_ptr.wins;
        }
    }
    out.cells.sort(struct {
        keys: []const u64,
        pub fn lessThan(c: @This(), a: usize, b: usize) bool {
            return c.keys[a] < c.keys[b];
        }
    }{ .keys = out.cells.keys() });
    if (out.skipped > 0) log.info("{d} seats skipped (no EUW1 game on their patch, or no champion)", .{out.skipped});
    return out;
}

pub const header = "patch\tday\tplatform\tbracket\trole\tchampion\tgames\twins\n";

/// `# first <patch> <ms>` per patch, then one line per cell
pub fn write(w: *std.Io.Writer, r: Result) !void {
    for (r.firsts) |f| try w.print("# first EUW1 game\t{d}.{d}\t{d}\n", .{ f.patch / 100, f.patch % 100, f.ms });
    try w.writeAll(header);
    var it = r.cells.iterator();
    while (it.next()) |e| {
        const c = unpack(e.key_ptr.*);
        try w.print("{d}.{d}\t{d}\t{s}\t{s}\t{t}\t{d}\t{d}\t{d}\n", .{
            c.patch / 100,
            c.patch % 100,
            c.day,
            endpoints.platform_ids[c.platform],
            brackets[c.bracket],
            c.role,
            c.champion,
            e.value_ptr.games,
            e.value_ptr.wins,
        });
    }
}

test "a cell's key round-trips and sorts by patch, then day" {
    const a: Cell = .{ .patch = 1621, .day = -1, .platform = 3, .bracket = 2, .role = .utility, .champion = 950 };
    try std.testing.expectEqual(a, unpack(pack(a)));
    var b = a;
    b.day = 0;
    try std.testing.expect(pack(a) < pack(b));
    b = a;
    b.patch = 1622;
    b.day = -300;
    try std.testing.expect(pack(a) < pack(b));
    try std.testing.expectEqual(@as(?u16, 1621), patchNumber("16.21"));
    try std.testing.expectEqual(@as(?u16, null), patchNumber("16"));
}

test "a game's seats by day since its patch's first EUW1 game" {
    const builds = @import("builds.zig");
    const gpa = std.testing.allocator;
    const seats = [_]builds.Seat{
        .{ .p = .{ .champion = 1, .role = .bottom, .won = true }, .k = null, .rank = 0 },
        .{ .p = .{ .champion = 2, .role = .bottom, .won = false }, .k = null, .rank = 9 },
        .{ .p = .{ .champion = 0, .role = .top, .won = false }, .k = null, .rank = null },
    };
    const strings = [_][]const u8{ "16.21", "KR", "EUW1", "16.30" };
    var g: cubes.Game = .{
        .start = 1000 - 3 * std.time.ms_per_hour,
        .rowid = 1,
        .source = 0,
        .platform = 1,
        .patch = 0,
        .hash = 0,
        .curves = .none,
        .lanes = &.{},
        .timeline = false,
        .seats = &seats,
    };
    const d: cubes.Day = .{ .day = 0, .strings = &strings, .games = &.{} };
    const firsts = [_]First{.{ .patch = 1621, .ms = 1000 }};
    var cells: std.AutoArrayHashMapUnmanaged(u64, Count) = .empty;
    defer cells.deinit(gpa);
    try std.testing.expectEqual(@as(u64, 1), try addGame(gpa, &cells, g, d, &firsts));
    g.platform = 2;
    g.start = 1000 + day_ms;
    _ = try addGame(gpa, &cells, g, d, &firsts);
    g.patch = 3;
    try std.testing.expectEqual(@as(u64, 3), try addGame(gpa, &cells, g, d, &firsts));
    try std.testing.expectEqual(@as(usize, 4), cells.count());
    const kr = platformIndex("KR").?;
    // Challenger
    const k = pack(.{ .patch = 1621, .day = -1, .platform = kr, .bracket = 3, .role = .bottom, .champion = 1 });
    try std.testing.expectEqual(Count{ .games = 1, .wins = 1 }, cells.get(k).?);
    const euw = pack(.{ .patch = 1621, .day = 1, .platform = platformIndex("EUW1").?, .bracket = 1, .role = .bottom, .champion = 2 });
    try std.testing.expectEqual(Count{ .games = 1, .wins = 0 }, cells.get(euw).?);
}
