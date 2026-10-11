//! Curves file: how each lane matchup unfolds, minute by minute, for one patch (or
//! patch range). Written beside the model file by `meiolol curves`.
//!
//! Format v1, little-endian:
//!   magic "MEIOCURV", version u32, minutes u32 (m), games u32, curves u32 (k),
//!   patch [16]u8 zero padded
//!   k x (Header, then m x Minute), the extern structs below
//! Curves are sorted by (role, a, b, bracket) with a <= b by champion id; a == b is a
//! mirror, seen from blue's side. Everything is from a's side: diffs are a minus b.
//! Minute i (0-based) is the frame at i + 1 minutes.

const std = @import("std");
const Role = @import("roles.zig").Role;

pub const magic = "MEIOCURV";
pub const version: u32 = 1;
pub const patch_len = 16;
/// Lane phase and the early mid game; later minutes mostly measure who is still playing
pub const max_minutes = 25;
/// "Wins lane" means ahead in gold at this minute (the usual GD@14/15 convention)
pub const lane_minute = 14;
/// Phases: before level 6 timing (0-6 min), lane (6-14), after lane (14+)
pub const phase_ends = [_]u8{ 6, lane_minute };
pub const phases = phase_ends.len + 1;
const header_len = magic.len + 4 * 4 + patch_len;
/// Bounds allocations from a corrupt header
const max_curves = 1 << 24;

/// Visible rank tiers, never inferred MMR (docs/concept.md)
pub const Bracket = enum(u8) {
    all,
    /// Iron to Silver
    low,
    /// Gold to Emerald
    mid,
    /// Diamond and above
    high,

    pub const count = 4;

    pub fn label(b: Bracket) []const u8 {
        return switch (b) {
            .all => "All ranks",
            .low => "Iron to Silver",
            .mid => "Gold to Emerald",
            .high => "Diamond+",
        };
    }

    /// From an index into `tiers`
    pub fn ofRank(rank: usize) Bracket {
        return if (rank < 3) .low else if (rank < 6) .mid else .high;
    }
};

/// Riot's ranked tiers, lowest first
pub const tiers = [_][]const u8{
    "IRON",
    "BRONZE",
    "SILVER",
    "GOLD",
    "PLATINUM",
    "EMERALD",
    "DIAMOND",
    "MASTER",
    "GRANDMASTER",
    "CHALLENGER",
};

pub fn tierRank(tier: []const u8) ?usize {
    for (tiers, 0..) |t, i| if (std.mem.eql(u8, tier, t)) return i;
    return null;
}

/// A game's tier: the median rank of its players with a known one (sorts `ranks`);
/// null when fewer than half of ten players are known
pub fn medianRank(ranks: []usize) ?usize {
    if (ranks.len < 5) return null;
    std.mem.sort(usize, ranks, {}, std.sort.asc(usize));
    return ranks[ranks.len / 2];
}

pub const Quartiles = extern struct { p25: i16, p50: i16, p75: i16 };

pub const Minute = extern struct {
    /// Games still going at this minute
    n: u32,
    gold: Quartiles,
    xp: Quartiles,
    /// Lane minions plus jungle monsters
    cs: Quartiles,
    _pad: u16 = 0,
};

pub const Header = extern struct {
    role: u8,
    bracket: u8,
    _pad: u16 = 0,
    a: u32,
    b: u32,
    games: u32,
    a_wins: u32,
    /// Games that reached lane_minute, and how many each side led in gold then
    lane_games: u32,
    lane_a: u32,
    lane_b: u32,
    /// Games won by the side that led at lane_minute
    a_wins_lane_a: u32,
    b_wins_lane_b: u32,
    /// Games where a took part in killing b (as killer or assist) in each phase
    a_kills_b: [phases]u32,
    b_kills_a: [phases]u32,
    /// Median seconds to level 6; 0 when too few reached it
    level6_a: u16,
    level6_b: u16,
};

/// One lane in one game, for Builder
pub const Lane = struct {
    role: Role,
    bracket: ?Bracket,
    a: u32,
    b: u32,
    a_won: bool,
    /// Minutes with a frame, at most max_minutes
    minutes: u8,
    gold: [max_minutes]i16 = @splat(0),
    xp: [max_minutes]i16 = @splat(0),
    cs: [max_minutes]i16 = @splat(0),
    a_kills_b: [phases]bool = @splat(false),
    b_kills_a: [phases]bool = @splat(false),
    level6_a: u16 = 0,
    level6_b: u16 = 0,

    /// The same lane from b's side
    fn swapped(l: Lane) Lane {
        var s = l;
        s.a = l.b;
        s.b = l.a;
        s.a_won = !l.a_won;
        for (&s.gold, &s.xp, &s.cs) |*g, *x, *c| {
            g.* = -g.*;
            x.* = -x.*;
            c.* = -c.*;
        }
        s.a_kills_b = l.b_kills_a;
        s.b_kills_a = l.a_kills_b;
        s.level6_a = l.level6_b;
        s.level6_b = l.level6_a;
        return s;
    }
};

pub const Builder = struct {
    gpa: std.mem.Allocator,
    lanes: std.ArrayList(Lane) = .empty,
    games: u32 = 0,

    pub fn deinit(b: *Builder) void {
        b.lanes.deinit(b.gpa);
    }

    /// Call once per game, after its lanes
    pub fn addGame(b: *Builder) void {
        b.games += 1;
    }

    pub fn addLane(b: *Builder, lane: Lane) !void {
        try b.lanes.append(b.gpa, if (lane.a > lane.b) lane.swapped() else lane);
    }

    /// Curves with at least `min_games` games, for every bracket that has them
    pub fn write(b: *Builder, w: *std.Io.Writer, patch: []const u8, min_games: u32) !void {
        if (patch.len > patch_len) return error.PatchTooLong;
        const lanes = b.lanes.items;
        std.mem.sort(Lane, lanes, {}, laneOrder);
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(b.gpa);
        var scratch: std.ArrayList(i16) = .empty;
        defer scratch.deinit(b.gpa);
        var subset: std.ArrayList(Lane) = .empty;
        defer subset.deinit(b.gpa);

        var curves: u32 = 0;
        var start: usize = 0;
        while (start < lanes.len) {
            var end = start + 1;
            while (end < lanes.len and sameMatchup(lanes[start], lanes[end])) end += 1;
            const group = lanes[start..end];
            start = end;
            for (std.enums.values(Bracket)) |bracket| {
                subset.clearRetainingCapacity();
                for (group) |l| if (bracket == .all or l.bracket == bracket) {
                    try subset.append(b.gpa, l);
                };
                if (subset.items.len < @max(min_games, 1)) continue;
                try curve(b.gpa, &out, &scratch, subset.items, bracket);
                curves += 1;
            }
        }

        try w.writeAll(magic);
        try w.writeInt(u32, version, .little);
        try w.writeInt(u32, max_minutes, .little);
        try w.writeInt(u32, b.games, .little);
        try w.writeInt(u32, curves, .little);
        try w.writeAll(patch);
        try w.splatByteAll(0, patch_len - patch.len);
        try w.writeAll(out.items);
    }

    fn laneOrder(_: void, x: Lane, y: Lane) bool {
        if (x.role != y.role) return @intFromEnum(x.role) < @intFromEnum(y.role);
        if (x.a != y.a) return x.a < y.a;
        return x.b < y.b;
    }

    fn sameMatchup(x: Lane, y: Lane) bool {
        return x.role == y.role and x.a == y.a and x.b == y.b;
    }
};

fn curve(
    gpa: std.mem.Allocator,
    out: *std.ArrayList(u8),
    scratch: *std.ArrayList(i16),
    lanes: []const Lane,
    bracket: Bracket,
) !void {
    var h: Header = .{
        .role = @intFromEnum(lanes[0].role),
        .bracket = @intFromEnum(bracket),
        .a = lanes[0].a,
        .b = lanes[0].b,
        .games = @intCast(lanes.len),
        .a_wins = 0,
        .lane_games = 0,
        .lane_a = 0,
        .lane_b = 0,
        .a_wins_lane_a = 0,
        .b_wins_lane_b = 0,
        .a_kills_b = @splat(0),
        .b_kills_a = @splat(0),
        .level6_a = 0,
        .level6_b = 0,
    };
    for (lanes) |l| {
        h.a_wins += @intFromBool(l.a_won);
        for (0..phases) |p| {
            h.a_kills_b[p] += @intFromBool(l.a_kills_b[p]);
            h.b_kills_a[p] += @intFromBool(l.b_kills_a[p]);
        }
        if (l.minutes < lane_minute) continue;
        h.lane_games += 1;
        const gold = l.gold[lane_minute - 1];
        if (gold > 0) {
            h.lane_a += 1;
            h.a_wins_lane_a += @intFromBool(l.a_won);
        } else if (gold < 0) {
            h.lane_b += 1;
            h.b_wins_lane_b += @intFromBool(!l.a_won);
        }
    }
    h.level6_a = try medianLevel6(gpa, lanes, .a);
    h.level6_b = try medianLevel6(gpa, lanes, .b);
    try out.appendSlice(gpa, std.mem.asBytes(&h));

    for (0..max_minutes) |i| {
        var m: Minute = .{ .n = 0, .gold = undefined, .xp = undefined, .cs = undefined };
        inline for (.{ "gold", "xp", "cs" }) |field| {
            scratch.clearRetainingCapacity();
            for (lanes) |l| if (l.minutes > i) try scratch.append(gpa, @field(l, field)[i]);
            @field(m, field) = quartiles(scratch.items);
        }
        m.n = @intCast(scratch.items.len);
        try out.appendSlice(gpa, std.mem.asBytes(&m));
    }
}

fn medianLevel6(gpa: std.mem.Allocator, lanes: []const Lane, side: enum { a, b }) !u16 {
    var times: std.ArrayList(u16) = .empty;
    defer times.deinit(gpa);
    for (lanes) |l| {
        const t = if (side == .a) l.level6_a else l.level6_b;
        if (t > 0) try times.append(gpa, t);
    }
    // A median of a handful says little
    if (times.items.len * 2 < lanes.len) return 0;
    std.mem.sort(u16, times.items, {}, std.sort.asc(u16));
    return times.items[times.items.len / 2];
}

/// Nearest rank (the value at rank ceil(q n)); sorts `values`. Zeros when empty
fn quartiles(values: []i16) Quartiles {
    const n = values.len;
    if (n == 0) return .{ .p25 = 0, .p50 = 0, .p75 = 0 };
    std.mem.sort(i16, values, {}, std.sort.asc(i16));
    return .{
        .p25 = values[(n + 3) / 4 - 1],
        .p50 = values[(n + 1) / 2 - 1],
        .p75 = values[(3 * n + 3) / 4 - 1],
    };
}

pub const Curve = struct {
    header: Header,
    minutes: []const Minute,
};

/// A parsed curves file. Owns its arrays; does not borrow the bytes.
pub const Curves = struct {
    patch_buf: [patch_len]u8,
    patch_len: usize,
    games: u32,
    curves: []Curve,
    minutes: []Minute,

    pub const ParseError = error{
        BadMagic,
        UnsupportedVersion,
        Truncated,
        SizeMismatch,
        TooManyCurves,
        OutOfMemory,
    };

    pub fn parse(gpa: std.mem.Allocator, bytes: []const u8) ParseError!Curves {
        if (bytes.len < header_len) return error.Truncated;
        if (!std.mem.eql(u8, bytes[0..magic.len], magic)) return error.BadMagic;
        var r: std.Io.Reader = .fixed(bytes[magic.len..]);
        const ver = r.takeInt(u32, .little) catch unreachable;
        if (ver != version) return error.UnsupportedVersion;
        const m = r.takeInt(u32, .little) catch unreachable;
        if (m != max_minutes) return error.UnsupportedVersion;
        const games = r.takeInt(u32, .little) catch unreachable;
        const k = r.takeInt(u32, .little) catch unreachable;
        if (k > max_curves) return error.TooManyCurves;
        var c: Curves = .{
            .patch_buf = undefined,
            .patch_len = 0,
            .games = games,
            .curves = &.{},
            .minutes = &.{},
        };
        @memcpy(&c.patch_buf, bytes[header_len - patch_len ..][0..patch_len]);
        c.patch_len = std.mem.indexOfScalar(u8, &c.patch_buf, 0) orelse patch_len;

        const per_curve = @sizeOf(Header) + m * @sizeOf(Minute);
        const body = bytes[header_len..];
        if (body.len < k * per_curve) return error.Truncated;
        if (body.len > k * per_curve) return error.SizeMismatch;
        c.curves = try gpa.alloc(Curve, k);
        errdefer gpa.free(c.curves);
        c.minutes = try gpa.alloc(Minute, k * m);
        for (c.curves, 0..) |*cv, i| {
            const at = body[i * per_curve ..];
            cv.header = std.mem.bytesToValue(Header, at[0..@sizeOf(Header)]);
            const mins = c.minutes[i * m ..][0..m];
            @memcpy(std.mem.sliceAsBytes(mins), at[@sizeOf(Header)..][0 .. m * @sizeOf(Minute)]);
            cv.minutes = mins;
        }
        return c;
    }

    pub fn deinit(c: *Curves, gpa: std.mem.Allocator) void {
        gpa.free(c.curves);
        gpa.free(c.minutes);
        c.* = undefined;
    }

    pub fn patch(c: *const Curves) []const u8 {
        return c.patch_buf[0..c.patch_len];
    }

    /// `me` against `them` in `role`, seen from `me`'s side; null when the file has
    /// too few games for it
    pub fn get(c: *const Curves, role: Role, bracket: Bracket, me: u32, them: u32) ?View {
        const a = @min(me, them);
        const b = @max(me, them);
        const key: Header = .{
            .role = @intFromEnum(role),
            .bracket = @intFromEnum(bracket),
            .a = a,
            .b = b,
            .games = 0,
            .a_wins = 0,
            .lane_games = 0,
            .lane_a = 0,
            .lane_b = 0,
            .a_wins_lane_a = 0,
            .b_wins_lane_b = 0,
            .a_kills_b = @splat(0),
            .b_kills_a = @splat(0),
            .level6_a = 0,
            .level6_b = 0,
        };
        const i = std.sort.binarySearch(Curve, c.curves, key, struct {
            fn order(k: Header, cv: Curve) std.math.Order {
                const h = cv.header;
                if (k.role != h.role) return std.math.order(k.role, h.role);
                if (k.a != h.a) return std.math.order(k.a, h.a);
                if (k.b != h.b) return std.math.order(k.b, h.b);
                return std.math.order(k.bracket, h.bracket);
            }
        }.order) orelse return null;
        return .{ .curve = &c.curves[i], .flipped = me != a };
    }
};

/// A curve from one champion's side ("me")
pub const View = struct {
    curve: *const Curve,
    flipped: bool,

    pub fn games(v: View) u32 {
        return v.curve.header.games;
    }

    pub fn wins(v: View) u32 {
        const h = v.curve.header;
        return if (v.flipped) h.games - h.a_wins else h.a_wins;
    }

    pub const Lane = struct {
        games: u32,
        ahead: u32,
        behind: u32,
        wins_ahead: u32,
        wins_behind: u32,
    };

    pub fn lane(v: View) View.Lane {
        const h = v.curve.header;
        const lane_a: View.Lane = .{
            .games = h.lane_games,
            .ahead = h.lane_a,
            .behind = h.lane_b,
            .wins_ahead = h.a_wins_lane_a,
            .wins_behind = h.lane_b - h.b_wins_lane_b,
        };
        if (!v.flipped) return lane_a;
        return .{
            .games = h.lane_games,
            .ahead = h.lane_b,
            .behind = h.lane_a,
            .wins_ahead = h.b_wins_lane_b,
            .wins_behind = h.lane_a - h.a_wins_lane_a,
        };
    }

    /// Games where I took part in killing them in `phase`
    pub fn kills(v: View, phase: usize) u32 {
        const h = v.curve.header;
        return if (v.flipped) h.b_kills_a[phase] else h.a_kills_b[phase];
    }

    pub fn deaths(v: View, phase: usize) u32 {
        const h = v.curve.header;
        return if (v.flipped) h.a_kills_b[phase] else h.b_kills_a[phase];
    }

    /// Median seconds to level 6 for me and them; 0 when unknown
    pub fn level6(v: View) [2]u16 {
        const h = v.curve.header;
        return if (v.flipped) .{ h.level6_b, h.level6_a } else .{ h.level6_a, h.level6_b };
    }

    pub fn minutes(v: View) usize {
        return v.curve.minutes.len;
    }

    /// Minute i (frame at i + 1 minutes), diffs as me minus them
    pub fn minute(v: View, i: usize) Minute {
        const m = v.curve.minutes[i];
        if (!v.flipped) return m;
        return .{ .n = m.n, .gold = neg(m.gold), .xp = neg(m.xp), .cs = neg(m.cs) };
    }

    fn neg(q: Quartiles) Quartiles {
        return .{ .p25 = -q.p75, .p50 = -q.p50, .p75 = -q.p25 };
    }
};

const testing = std.testing;

fn testLane(a: u32, b: u32, a_won: bool, gold_at: i16, bracket: ?Bracket) Lane {
    var l: Lane = .{
        .role = .top,
        .bracket = bracket,
        .a = a,
        .b = b,
        .a_won = a_won,
        .minutes = 20,
    };
    for (0..20) |i| {
        const t: i16 = @intCast(i + 1);
        l.gold[i] = @divTrunc(gold_at * t, lane_minute);
        l.xp[i] = t * 10;
        l.cs[i] = 1;
    }
    l.a_kills_b[0] = gold_at > 0;
    l.level6_a = 360;
    l.level6_b = 420;
    return l;
}

test "round trip, sides and brackets" {
    const gpa = testing.allocator;
    var b: Builder = .{ .gpa = gpa };
    defer b.deinit();
    // Darius (122) vs Garen (86) seen from Darius: Darius leads at 14 in 3 of 4
    try b.addLane(testLane(122, 86, true, 700, .low));
    try b.addLane(testLane(122, 86, true, 300, .low));
    try b.addLane(testLane(122, 86, false, 100, .high));
    try b.addLane(testLane(122, 86, true, -500, null));
    // Too few games for a curve
    try b.addLane(testLane(1, 2, true, 0, .mid));
    for (0..5) |_| b.addGame();

    var aw: std.Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();
    try b.write(&aw.writer, "16.20", 2);
    var c: Curves = try .parse(gpa, aw.written());
    defer c.deinit(gpa);
    try testing.expectEqualStrings("16.20", c.patch());
    try testing.expectEqual(5, c.games);
    // all + low; high has one game
    try testing.expectEqual(2, c.curves.len);
    try testing.expect(c.get(.top, .all, 1, 2) == null);
    try testing.expect(c.get(.top, .high, 122, 86) == null);
    try testing.expect(c.get(.jungle, .all, 122, 86) == null);

    const darius = c.get(.top, .all, 122, 86).?;
    try testing.expect(darius.flipped);
    try testing.expectEqual(4, darius.games());
    try testing.expectEqual(3, darius.wins());
    const lane = darius.lane();
    const want: View.Lane = .{ .games = 4, .ahead = 3, .behind = 1, .wins_ahead = 2, .wins_behind = 1 };
    try testing.expectEqual(want, lane);
    try testing.expectEqual(3, darius.kills(0));
    try testing.expectEqual(0, darius.deaths(0));
    try testing.expectEqual([2]u16{ 360, 420 }, darius.level6());
    const m14 = darius.minute(lane_minute - 1);
    try testing.expectEqual(4, m14.n);
    try testing.expectEqual(Quartiles{ .p25 = 100, .p50 = 300, .p75 = 700 }, m14.gold);
    try testing.expectEqual(0, darius.minute(20).n);

    const garen = c.get(.top, .all, 86, 122).?;
    try testing.expect(!garen.flipped);
    try testing.expectEqual(1, garen.wins());
    const garen_gold: Quartiles = .{ .p25 = -700, .p50 = -300, .p75 = -100 };
    try testing.expectEqual(garen_gold, garen.minute(lane_minute - 1).gold);
    try testing.expectEqual(1, garen.lane().ahead);
    try testing.expectEqual([2]u16{ 420, 360 }, garen.level6());

    const low = c.get(.top, .low, 122, 86).?;
    try testing.expectEqual(2, low.games());

    const bytes = aw.written();
    try testing.expectError(error.Truncated, Curves.parse(gpa, bytes[0 .. bytes.len - 1]));
}
