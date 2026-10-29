//! The comp view once both teams have locked in (docs/plan/app.md APP6): each team's
//! damage mix, its champions that lean early or late, and the five lane matchups. Only
//! measured, shipped facts: Learn's damage split and team mix tally and `meiolol lean`'s
//! clear leans (core.champfacts), the lane curves. Comp leans (a champion into a
//! magic-heavy team) wait for their held-out look (docs/plan/data-and-model.md step 1).
//! Champions only, never players. What the public edition shows of it is the window's
//! call (words there, numbers for testers). Pure.

const std = @import("std");
const core = @import("core");
const board = @import("board.zig");
const loading = @import("loading.zig");
const Role = core.Role;
const Stats = core.Stats;
const champfacts = core.champfacts;
const Counts = core.statsfile.Counts;

pub const Input = struct {
    stats: *const Stats,
    curves: ?*const core.curvesfile.Curves = null,
    facts: ?*const champfacts.Facts = null,
    tier: ?[]const u8 = null,
};

pub const Mix = enum { physical, mixed, magic };

pub const Damage = struct {
    /// The team's average magic share of damage to champions
    magic: f64,
    mix: Mix,
    /// Teams with this mix on the facts' patch (Learn's tally)
    teams: Counts,
    /// Their win rate is under even by `sure` standard errors
    wins_less: bool,
};

pub const Timing = struct {
    champion: u32,
    role: Role,
    lean: champfacts.Lean,
    /// Team gold at gold_minute and win points from even at win_minute (champfacts)
    gold: f64,
    win: f64,
};

pub const Team = struct {
    /// Null unless every champion's damage split is known
    damage: ?Damage,
    /// Champions with a clear early or late lean in their role, early first
    timing: []const Timing,
};

pub const Lane = struct {
    role: Role,
    /// 0: nobody known in the role
    ours: u32,
    theirs: u32,
    me: bool,
    /// Ours against theirs; null without a curve with enough games
    facts: ?loading.LaneFacts,
};

pub const Comp = struct {
    /// Ours, theirs
    teams: [2]Team,
    lanes: [Role.count]Lane,
    /// The damage facts' patch; "" without facts
    patch: []const u8,
};

const sure = 2;

/// Every seat on both teams locked in
pub fn ready(b: *const board.Board) bool {
    if (b.allies.len != 5 or b.enemies.len != 5) return false;
    for ([_][]const board.Seat{ b.allies, b.enemies }) |side| for (side) |s| {
        if (s.slot.champion == 0 or s.slot.state != .locked) return false;
    };
    return true;
}

/// Null until `ready`. Allocates in `arena`
pub fn after(arena: std.mem.Allocator, in: Input, b: *const board.Board) !?*const Comp {
    if (!ready(b)) return null;
    const c = try arena.create(Comp);
    c.* = try build(arena, in, try loading.seatsOf(arena, b));
    return c;
}

pub fn build(arena: std.mem.Allocator, in: Input, seats: [2][]const loading.Seat) !Comp {
    var out: Comp = .{ .teams = undefined, .lanes = undefined, .patch = if (in.facts) |f| f.patch else "" };
    for (seats, &out.teams) |side, *t| t.* = try team(arena, in, side);
    for (Role.all, &out.lanes) |r, *l| {
        const ours = inRole(seats[0], r);
        const theirs = inRole(seats[1], r);
        l.* = .{
            .role = r,
            .ours = if (ours) |s| s.champion else 0,
            .theirs = if (theirs) |s| s.champion else 0,
            .me = if (ours) |s| s.me else false,
            .facts = null,
        };
        if (l.ours == 0 or l.theirs == 0) continue;
        if (in.curves) |curves| l.facts = loading.laneFacts(curves, r, in.tier, l.ours, l.theirs);
    }
    return out;
}

fn inRole(seats: []const loading.Seat, r: Role) ?loading.Seat {
    for (seats) |s| if (s.role == r and s.champion != 0) return s;
    return null;
}

fn team(arena: std.mem.Allocator, in: Input, seats: []const loading.Seat) !Team {
    const facts = in.facts orelse return .{ .damage = null, .timing = &.{} };
    var timing: std.ArrayList(Timing) = .empty;
    var sum: f64 = 0;
    var known: usize = 0;
    for (seats) |s| {
        if (facts.magicOf(s.champion)) |m| {
            sum += m;
            known += 1;
        }
        const r = s.role orelse continue;
        const row = facts.leanOf(s.champion, r) orelse continue;
        const l = row.lean();
        if (l == .none) continue;
        try timing.append(arena, .{ .champion = s.champion, .role = r, .lean = l, .gold = row.gold, .win = row.win });
    }
    std.mem.sort(Timing, timing.items, {}, struct {
        fn before(_: void, a: Timing, b: Timing) bool {
            return @backingInt(a.lean) < @backingInt(b.lean);
        }
    }.before);
    var damage: ?Damage = null;
    if (known == 5 and seats.len == 5) {
        const magic = sum / 5;
        const bucket = champfacts.mixBucket(magic);
        const teams = facts.mix[bucket];
        damage = .{
            .magic = magic,
            .mix = @fromBackingInt(@intCast(bucket)),
            .teams = teams,
            .wins_less = winsLess(teams),
        };
    }
    return .{ .damage = damage, .timing = timing.items };
}

/// Each side's lane in words, its own way round: "ahead in lane, level 6 sooner"
pub fn lines(obuf: []u8, tbuf: []u8, l: Lane) [2][]const u8 {
    const f = l.facts orelse return .{ if (l.ours != 0 and l.theirs != 0) "few games of this lane" else "", "" };
    const where = if (l.role == .jungle) "early" else "in lane";
    var out: [2][]const u8 = undefined;
    for ([_][]u8{ obuf, tbuf }, [_]bool{ true, false }, &out) |buf, mine, *o| {
        var bw: std.Io.Writer = .fixed(buf);
        if (f.edge()) |e| {
            const flipped: loading.LaneFacts.Edge = if (mine) e else switch (e) {
                .ahead => .behind,
                .behind => .ahead,
                .even => .even,
            };
            bw.print("{t} {s}", .{ flipped, where }) catch {};
        }
        if (loading.timingWord(f.level6)) |word| {
            const sooner = (word == .sooner) == mine;
            bw.print("{s}level 6 {s}", .{ if (bw.end > 0) ", " else "", if (sooner) "sooner" else "later" }) catch {};
        }
        o.* = bw.buffered();
    }
    return out;
}

fn winsLess(c: Counts) bool {
    if (c.games == 0) return false;
    const n: f64 = @floatFromInt(c.games);
    const rate = @as(f64, @floatFromInt(c.wins)) / n;
    return 0.5 - rate >= sure * @sqrt(0.25 / n);
}

const testing = std.testing;
const cardscenes = @import("cardscenes.zig");

test "comp: damage mix, early and late champions, lanes by role" {
    var f = try cardscenes.fixture();
    defer f.deinit();
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const st = &f.stats;
    const id = struct {
        fn of(s: *const Stats, name: []const u8) u32 {
            return s.ids[s.find(name).?];
        }
    }.of;
    const ours = [_]loading.Seat{
        .{ .champion = id(st, "Darius"), .role = .top },
        .{ .champion = id(st, "Ahri"), .role = .middle, .me = true },
    };
    const theirs = [_]loading.Seat{
        .{ .champion = id(st, "Malphite"), .role = .top, .guessed = true },
        .{ .champion = id(st, "Syndra"), .role = .middle, .guessed = true },
    };
    const facts: champfacts.Facts = .{
        .damage = &.{ .{ .champion = id(st, "Darius"), .magic = 0.1 }, .{ .champion = id(st, "Ahri"), .magic = 0.9 } },
        .lean = &.{
            .{ .champion = id(st, "Ahri"), .role = .middle, .games = 900, .gold = -400, .gold_sd = 100, .win = 4, .win_sd = 1 },
            .{ .champion = id(st, "Darius"), .role = .top, .games = 900, .gold = 500, .gold_sd = 100, .win = -3, .win_sd = 1 },
            // Clear in another role only
            .{ .champion = id(st, "Syndra"), .role = .top, .games = 900, .gold = 500, .gold_sd = 100, .win = -3, .win_sd = 1 },
        },
    };
    const c = try build(arena, .{ .stats = st, .curves = &f.curves, .facts = &facts }, .{ &ours, &theirs });
    // Two champions: no damage mix
    try testing.expectEqual(null, c.teams[0].damage);
    try testing.expectEqual(2, c.teams[0].timing.len);
    try testing.expectEqual(id(st, "Darius"), c.teams[0].timing[0].champion);
    try testing.expectEqual(champfacts.Lean.late, c.teams[0].timing[1].lean);
    try testing.expectEqual(0, c.teams[1].timing.len);
    // Planted: Malphite beats Darius in lane, Syndra beats Ahri
    const top = c.lanes[@backingInt(Role.top)];
    try testing.expectEqual(loading.LaneFacts.Edge.behind, top.facts.?.edge().?);
    try testing.expect(c.lanes[@backingInt(Role.middle)].me);
    try testing.expectEqual(0, c.lanes[@backingInt(Role.bottom)].ours);
}

test "comp: a full team's mix and whether such teams win less" {
    var f = try cardscenes.fixture();
    defer f.deinit();
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var seats: [5]loading.Seat = undefined;
    var damage: [5]champfacts.Damage = undefined;
    for (&seats, &damage, Role.all, 0..) |*s, *d, r, i| {
        s.* = .{ .champion = f.stats.ids[i], .role = r };
        d.* = .{ .champion = f.stats.ids[i], .magic = 0.1 };
    }
    var facts: champfacts.Facts = .{ .damage = &damage };
    facts.mix[0] = .{ .games = 10_000, .wins = 4_800 };
    const c = try build(arena, .{ .stats = &f.stats, .facts = &facts }, .{ &seats, &.{} });
    const d = c.teams[0].damage.?;
    try testing.expectEqual(Mix.physical, d.mix);
    try testing.expectApproxEqAbs(0.1, d.magic, 1e-6);
    try testing.expect(d.wins_less);
    facts.mix[0] = .{ .games = 100, .wins = 48 };
    try testing.expect(!(try build(arena, .{ .stats = &f.stats, .facts = &facts }, .{ &seats, &.{} })).teams[0].damage.?.wins_less);
}
