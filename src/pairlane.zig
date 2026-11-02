//! Bot lane as a pair (docs/plan/pairlane.md): one side's ADC and support against the
//! other side's, gold, XP and CS of both lanes summed, from the day cubes' lanes.
//! `meiolol pairlane` writes the file, the duo pages read it.
//!
//! Format v1, little-endian, 8-byte aligned:
//!   magic "MEIOPAIR", version u32, minutes u32 (m), games u32, cells u32 (c),
//!   curves u32 (k), 0 u32, label [32]u8 zero padded
//!   c x Cell, sorted by Key; then k x Curve (Key, m x Minute), sorted by Key
//! Everything is from the key's pair's side: diffs are the pair minus the enemy pair. A
//! zero champion in a Key means anyone: (adc, sup, 0, 0) the pair against everyone,
//! (adc, sup, x, 0) against enemy ADC x, (adc, sup, 0, y) against enemy support y,
//! (adc, 0, 0, 0) the ADC with any support, (0, sup, 0, 0) the support with any ADC.
//! Curves are kept for pairs against everyone only.

const std = @import("std");
const store = @import("store");
const core = @import("core");
const curves = @import("curves.zig");
const cubes = @import("cubes.zig");

const Allocator = std.mem.Allocator;
const Role = core.Role;
const curvesfile = core.curvesfile;
const Lane = curvesfile.Lane;

pub const magic = "MEIOPAIR";
pub const version: u32 = 1;
pub const max_minutes = curvesfile.max_minutes;
/// "Wins lane": the pair ahead in gold at this minute, as the lane curves
pub const lane_minute = curvesfile.lane_minute;
const label_len = 32;
const header_len = magic.len + 6 * 4 + label_len;

pub const Metric = enum { gold, xp, cs };
const metrics = 3;

pub const Key = extern struct {
    adc: u16,
    sup: u16,
    o_adc: u16 = 0,
    o_sup: u16 = 0,

    fn order(k: Key) u64 {
        return @as(u64, k.adc) << 48 | @as(u64, k.sup) << 32 | @as(u64, k.o_adc) << 16 | k.o_sup;
    }

    fn less(_: void, a: Key, b: Key) bool {
        return a.order() < b.order();
    }
};

pub const Sum = extern struct {
    games: u32 = 0,
    wins: u32 = 0,
    /// Games that reached lane_minute, and how many the pair led or trailed in gold then
    at14: u32 = 0,
    ahead: u32 = 0,
    behind: u32 = 0,
    wins_ahead: u32 = 0,
    wins_behind: u32 = 0,
    gold14: f64 = 0,
    gold14_sq: f64 = 0,

    fn add(s: *Sum, won: bool, g14: ?f64) void {
        s.games += 1;
        s.wins += @intFromBool(won);
        const g = g14 orelse return;
        s.at14 += 1;
        s.gold14 += g;
        s.gold14_sq += g * g;
        if (g > 0) {
            s.ahead += 1;
            s.wins_ahead += @intFromBool(won);
        } else if (g < 0) {
            s.behind += 1;
            s.wins_behind += @intFromBool(won);
        }
    }

    pub fn winRate(s: Sum) f64 {
        return ratio(s.wins, s.games);
    }

    pub fn aheadShare(s: Sum) f64 {
        return ratio(s.ahead, s.at14);
    }

    /// Mean gold lead at lane_minute
    pub fn gold(s: Sum) f64 {
        return if (s.at14 == 0) 0 else s.gold14 / @as(f64, @floatFromInt(s.at14));
    }

    /// Half width of the 95% range of gold(); 0 under two games
    pub fn goldRange(s: Sum) f64 {
        if (s.at14 < 2) return 0;
        const n: f64 = @floatFromInt(s.at14);
        const mean = s.gold14 / n;
        const variance = @max(0, (s.gold14_sq - n * mean * mean) / (n - 1));
        return 1.96 * @sqrt(variance / n);
    }
};

fn ratio(a: u32, b: u32) f64 {
    return if (b == 0) 0 else @as(f64, @floatFromInt(a)) / @as(f64, @floatFromInt(b));
}

pub const Cell = extern struct {
    key: Key,
    sum: Sum,
};

pub const Minute = extern struct {
    /// Games still going
    n: u32,
    mean: [metrics]f32,
    sd: [metrics]f32,

    pub fn of(m: Minute, metric: Metric) struct { mean: f32, sd: f32 } {
        return .{ .mean = m.mean[@backingInt(metric)], .sd = m.sd[@backingInt(metric)] };
    }
};

pub const Curve = extern struct {
    key: Key,
    minutes: [max_minutes]Minute,
};

comptime {
    std.debug.assert(header_len % 8 == 0 and @sizeOf(Cell) % 8 == 0);
}

const MinuteSum = struct {
    n: u32 = 0,
    sum: [metrics]f64 = @splat(0),
    sq: [metrics]f64 = @splat(0),
};

pub const Builder = struct {
    gpa: Allocator,
    games: u32 = 0,
    cells: std.AutoHashMapUnmanaged(Key, Sum) = .empty,
    curves: std.AutoHashMapUnmanaged(Key, [max_minutes]MinuteSum) = .empty,

    pub fn deinit(b: *Builder) void {
        b.cells.deinit(b.gpa);
        b.curves.deinit(b.gpa);
    }

    /// A game's lanes by role, blue's laner as a (cubes.Game.lanes). False when its bot
    /// lane has no frames
    pub fn addGame(b: *Builder, lanes: []const Lane) !bool {
        if (lanes.len != Role.count) return false;
        const bot = lanes[@backingInt(Role.bottom)];
        const sup = lanes[@backingInt(Role.utility)];
        const minutes = @min(bot.minutes, sup.minutes);
        if (minutes == 0) return false;
        const ids = [_]u32{ bot.a, sup.a, bot.b, sup.b };
        for (ids) |id| if (id == 0 or id >= std.math.maxInt(u16)) return false;
        for (0..2) |side| {
            const blue = side == 0;
            const sign: i32 = if (blue) 1 else -1;
            const k: Key = if (blue)
                .{ .adc = @intCast(bot.a), .sup = @intCast(sup.a) }
            else
                .{ .adc = @intCast(bot.b), .sup = @intCast(sup.b) };
            const enemy: Key = if (blue)
                .{ .adc = @intCast(bot.b), .sup = @intCast(sup.b) }
            else
                .{ .adc = @intCast(bot.a), .sup = @intCast(sup.a) };
            const won = bot.a_won == blue;
            const g14: ?f64 = if (minutes >= lane_minute)
                @floatFromInt(sign * (@as(i32, bot.gold[lane_minute - 1]) + sup.gold[lane_minute - 1]))
            else
                null;
            const keys = [_]Key{
                k,
                .{ .adc = k.adc, .sup = k.sup, .o_adc = enemy.adc },
                .{ .adc = k.adc, .sup = k.sup, .o_sup = enemy.sup },
                .{ .adc = k.adc, .sup = k.sup, .o_adc = enemy.adc, .o_sup = enemy.sup },
                .{ .adc = k.adc, .sup = 0 },
                .{ .adc = 0, .sup = k.sup },
            };
            for (keys) |key| {
                const e = try b.cells.getOrPutValue(b.gpa, key, .{});
                e.value_ptr.add(won, g14);
            }
            const c = try b.curves.getOrPutValue(b.gpa, k, @splat(.{}));
            for (c.value_ptr[0..minutes], 0..) |*m, i| {
                const v = [metrics]f64{
                    @floatFromInt(sign * (@as(i32, bot.gold[i]) + sup.gold[i])),
                    @floatFromInt(sign * (@as(i32, bot.xp[i]) + sup.xp[i])),
                    @floatFromInt(sign * (@as(i32, bot.cs[i]) + sup.cs[i])),
                };
                m.n += 1;
                for (&m.sum, &m.sq, v) |*s, *q, x| {
                    s.* += x;
                    q.* += x * x;
                }
            }
        }
        b.games += 1;
        return true;
    }

    /// Cells and curves with at least `min_games`
    pub fn write(b: *const Builder, w: *std.Io.Writer, label: []const u8, min_games: u32) !void {
        var cells: std.ArrayList(Cell) = .empty;
        defer cells.deinit(b.gpa);
        var it = b.cells.iterator();
        while (it.next()) |e| if (e.value_ptr.games >= min_games) try cells.append(b.gpa, .{ .key = e.key_ptr.*, .sum = e.value_ptr.* });
        std.mem.sort(Cell, cells.items, {}, struct {
            fn f(_: void, x: Cell, y: Cell) bool {
                return Key.less({}, x.key, y.key);
            }
        }.f);
        var keys: std.ArrayList(Key) = .empty;
        defer keys.deinit(b.gpa);
        var ci = b.curves.iterator();
        while (ci.next()) |e| if (e.value_ptr[0].n >= min_games) try keys.append(b.gpa, e.key_ptr.*);
        std.mem.sort(Key, keys.items, {}, Key.less);

        try w.writeAll(magic);
        for ([_]u32{ version, max_minutes, b.games, @intCast(cells.items.len), @intCast(keys.items.len), 0 }) |x| try w.writeInt(u32, x, .little);
        var lb: [label_len]u8 = @splat(0);
        const n = @min(label.len, label_len);
        @memcpy(lb[0..n], label[0..n]);
        try w.writeAll(&lb);
        try w.writeAll(std.mem.sliceAsBytes(cells.items));
        for (keys.items) |k| {
            var c: Curve = .{ .key = k, .minutes = undefined };
            for (b.curves.getPtr(k).?, &c.minutes) |s, *m| m.* = minuteOf(s);
            try w.writeAll(std.mem.asBytes(&c));
        }
    }
};

fn minuteOf(s: MinuteSum) Minute {
    var m: Minute = .{ .n = s.n, .mean = @splat(0), .sd = @splat(0) };
    if (s.n == 0) return m;
    const n: f64 = @floatFromInt(s.n);
    for (s.sum, s.sq, &m.mean, &m.sd) |sum, sq, *mean, *sd| {
        const mu = sum / n;
        mean.* = @floatCast(mu);
        sd.* = if (s.n < 2) 0 else @floatCast(@sqrt(@max(0, (sq - n * mu * mu) / (n - 1))));
    }
    return m;
}

pub const ParseError = error{ Truncated, BadMagic, UnsupportedVersion, SizeMismatch, OutOfMemory };

pub const File = struct {
    bytes: []align(8) const u8,
    games: u32,
    label: []const u8,
    cells: []const Cell,
    curves: []const Curve,

    /// A copy of `bytes`
    pub fn parse(gpa: Allocator, bytes: []const u8) ParseError!File {
        if (bytes.len < header_len) return error.Truncated;
        if (!std.mem.eql(u8, bytes[0..magic.len], magic)) return error.BadMagic;
        const ints = bytes[magic.len..][0 .. 6 * 4];
        const int = struct {
            fn f(b: []const u8, i: usize) u32 {
                return std.mem.readInt(u32, b[4 * i ..][0..4], .little);
            }
        }.f;
        if (int(ints, 0) != version or int(ints, 1) != max_minutes) return error.UnsupportedVersion;
        const n_cells = int(ints, 3);
        const n_curves = int(ints, 4);
        const want = header_len + @as(u64, n_cells) * @sizeOf(Cell) + @as(u64, n_curves) * @sizeOf(Curve);
        if (bytes.len != want) return error.SizeMismatch;
        const own = try gpa.alignedAlloc(u8, .@"8", bytes.len);
        @memcpy(own, bytes);
        const label = own[magic.len + 6 * 4 ..][0..label_len];
        const cells_at = header_len;
        const curves_at = cells_at + n_cells * @sizeOf(Cell);
        const cells_ptr: [*]const Cell = @ptrCast(@alignCast(own[cells_at..].ptr));
        const curves_ptr: [*]const Curve = @ptrCast(@alignCast(own[curves_at..].ptr));
        return .{
            .bytes = own,
            .games = int(ints, 2),
            .label = label[0 .. std.mem.indexOfScalar(u8, label, 0) orelse label_len],
            .cells = cells_ptr[0..n_cells],
            .curves = curves_ptr[0..n_curves],
        };
    }

    pub fn deinit(f: *File, gpa: Allocator) void {
        gpa.free(f.bytes);
    }

    pub fn get(f: *const File, key: Key) ?Sum {
        const i = lowerBound(Cell, f.cells, key) orelse return null;
        return if (std.meta.eql(f.cells[i].key, key)) f.cells[i].sum else null;
    }

    pub fn curve(f: *const File, adc: u16, sup: u16) ?*const Curve {
        const key: Key = .{ .adc = adc, .sup = sup };
        const i = lowerBound(Curve, f.curves, key) orelse return null;
        return if (std.meta.eql(f.curves[i].key, key)) &f.curves[i] else null;
    }

    /// The pair's cells against an enemy ADC, support or pair, in key order
    pub fn against(f: *const File, adc: u16, sup: u16) []const Cell {
        const from = lowerBound(Cell, f.cells, .{ .adc = adc, .sup = sup, .o_sup = 1 }) orelse return &.{};
        const to = lowerBound(Cell, f.cells, .{ .adc = adc, .sup = sup + 1 }) orelse f.cells.len;
        return f.cells[from..to];
    }
};

/// First index whose key is not below `key`; null when every key is below
fn lowerBound(comptime T: type, items: []const T, key: Key) ?usize {
    const i = std.sort.lowerBound(T, items, key, struct {
        fn f(k: Key, x: T) std.math.Order {
            return std.math.order(k.order(), x.key.order());
        }
    }.f);
    return if (i == items.len) null else i;
}

/// Pairs files, builders[i] for specs[i], from one pass over the day cubes (made current
/// first). Specs by days only (since_ms > 0). Caller owns the builders, also on error
pub fn fromCubes(
    s: *cubes.Store,
    db: store.Db,
    items: cubes.Items,
    specs: []const curves.Spec,
    builders: []Builder,
) !cubes.Counts {
    var from: i64 = std.math.maxInt(i64);
    for (specs) |spec| {
        std.debug.assert(spec.since_ms > 0);
        from = @min(from, spec.since_ms);
    }
    const n = try s.refresh(db, from, items);
    const gpa = s.gpa;
    const ds = try s.days(gpa, from);
    defer gpa.free(ds);
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    for (ds) |day| {
        _ = arena_state.reset(.retain_capacity);
        const d = try s.read(gpa, arena_state.allocator(), day) orelse return error.StaleCube;
        for (d.games) |g| {
            if (g.curves != .lanes) continue;
            for (specs, builders) |spec, *b| {
                if (spec.takes(d.string(g.patch), g.start, d.string(g.platform))) _ = try b.addGame(g.lanes);
            }
        }
    }
    return n;
}

const testing = std.testing;

fn testLane(role: Role, a: u32, b: u32, a_won: bool, gold: i16, minutes: u8) Lane {
    var l: Lane = .{ .role = role, .bracket = .all, .a = a, .b = b, .a_won = a_won, .minutes = minutes };
    for (l.gold[0..minutes], l.xp[0..minutes], l.cs[0..minutes], 0..) |*g, *x, *c, i| {
        g.* = gold * @as(i16, @intCast(i + 1));
        x.* = 10;
        c.* = 1;
    }
    return l;
}

fn testGame(adc: [2]u32, sup: [2]u32, blue_won: bool, bot_gold: i16, sup_gold: i16, minutes: u8) [Role.count]Lane {
    var lanes: [Role.count]Lane = undefined;
    for (Role.all, &lanes) |r, *l| l.* = testLane(r, 1, 2, blue_won, 0, minutes);
    lanes[@backingInt(Role.bottom)] = testLane(.bottom, adc[0], adc[1], blue_won, bot_gold, minutes);
    lanes[@backingInt(Role.utility)] = testLane(.utility, sup[0], sup[1], blue_won, sup_gold, minutes);
    return lanes;
}

test "pair lanes: both sides, cells, curves and the file" {
    const gpa = testing.allocator;
    var b: Builder = .{ .gpa = gpa };
    defer b.deinit();
    // Jinx (222) + Thresh (412) on blue against Kai'Sa (145) + Nautilus (111), twice; once
    // on red against Kai'Sa + Lulu (117), too short to reach 14 minutes
    try testing.expect(try b.addGame(&testGame(.{ 222, 145 }, .{ 412, 111 }, true, 20, 10, 20)));
    try testing.expect(try b.addGame(&testGame(.{ 222, 145 }, .{ 412, 111 }, false, -10, 0, 25)));
    try testing.expect(try b.addGame(&testGame(.{ 145, 222 }, .{ 117, 412 }, true, 5, 5, 12)));
    try testing.expect(!try b.addGame(&testGame(.{ 222, 145 }, .{ 412, 111 }, true, 5, 5, 0)));
    try testing.expectEqual(3, b.games);

    var aw: std.Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();
    try b.write(&aw.writer, "last 30 days", 1);
    var f: File = try .parse(gpa, aw.written());
    defer f.deinit(gpa);
    try testing.expectEqual(3, f.games);
    try testing.expectEqualStrings("last 30 days", f.label);

    const pair = f.get(.{ .adc = 222, .sup = 412 }).?;
    try testing.expectEqual(3, pair.games);
    try testing.expectEqual(1, pair.wins);
    try testing.expectEqual(2, pair.at14);
    try testing.expectEqual(1, pair.ahead);
    try testing.expectEqual(1, pair.wins_ahead);
    // Minute 14 is frame index 13: (20 + 10) * 14 and -10 * 14
    try testing.expectApproxEqAbs((420.0 - 140.0) / 2.0, pair.gold(), 1e-9);
    try testing.expect(pair.goldRange() > 0);

    // The red side's numbers are negated: Kai'Sa + Nautilus trailed 420 then led 140
    const enemy = f.get(.{ .adc = 145, .sup = 111 }).?;
    try testing.expectApproxEqAbs(-pair.gold(), enemy.gold(), 1e-9);
    try testing.expectEqual(1, enemy.wins);

    const vs = f.against(222, 412);
    try testing.expectEqual(5, vs.len);
    try testing.expectEqual(3, f.get(.{ .adc = 222, .sup = 412, .o_adc = 145 }).?.games);
    try testing.expectEqual(2, f.get(.{ .adc = 222, .sup = 412, .o_adc = 145, .o_sup = 111 }).?.games);
    try testing.expectEqual(1, f.get(.{ .adc = 222, .sup = 412, .o_sup = 117 }).?.games);
    try testing.expectEqual(3, f.get(.{ .adc = 222, .sup = 0 }).?.games);
    try testing.expectEqual(3, f.get(.{ .adc = 0, .sup = 412 }).?.games);
    for (vs) |c| try testing.expect(c.key.o_adc != 0 or c.key.o_sup != 0);
    try testing.expectEqual(0, f.against(222, 0).len);

    const c = f.curve(222, 412).?;
    try testing.expectEqual(3, c.minutes[0].n);
    try testing.expectEqual(2, c.minutes[13].n);
    try testing.expectEqual(1, c.minutes[20].n);
    // Minute 1 (index 0): blue 30, blue -10, red -(5 + 5); XP 20 a side, negated on red
    try testing.expectApproxEqAbs(10.0 / 3.0, c.minutes[0].of(.gold).mean, 1e-4);
    try testing.expectApproxEqAbs(20.0 / 3.0, c.minutes[0].of(.xp).mean, 1e-4);
    try testing.expect(f.curve(222, 111) == null);

    // A floor leaves thin cells and curves out
    var aw2: std.Io.Writer.Allocating = .init(gpa);
    defer aw2.deinit();
    try b.write(&aw2.writer, "x", 3);
    var f2: File = try .parse(gpa, aw2.written());
    defer f2.deinit(gpa);
    try testing.expect(f2.get(.{ .adc = 222, .sup = 412, .o_sup = 111 }) == null);
    try testing.expect(f2.curve(222, 412) != null);
    try testing.expectEqual(1, f2.against(222, 412).len);
    try testing.expectError(error.SizeMismatch, File.parse(gpa, aw2.written()[0 .. aw2.written().len - 1]));
}
