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
    /// The team's only magic or only physical dealer (loading.lone)
    lone: ?Lone = null,
    /// Its champion with the most damage to champions a minute in its role
    top: ?Top = null,
};

pub const Top = struct {
    champion: u32,
    /// Of the team's damage a minute, 0..1; null unless every champion's is known
    share: ?f64,
};

/// My team's win chance by game length (champfacts.length_edges), from each champion's
/// win rate in its role per length bucket, shrunk to even and summed as log-odds, mine
/// minus theirs. A sum of champion averages: lanes and pairs count twice or not at all
pub const Length = struct {
    win: [champfacts.length_buckets]f64,
    /// True: wins more in long games than short ones, false the other way; null unless
    /// `sure` standard errors apart (games of 30 min and over against under 25)
    longer: ?bool,
};

pub const Lone = struct { champion: u32, ap: bool };

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
    /// Null without length facts or five seats a side
    length: ?Length = null,
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
    if (in.facts) |f| out.length = lengthOf(f, seats);
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
    var lone: ?Lone = null;
    for (seats) |s| if (loading.lone(facts, s.champion, seats)) |kind| {
        lone = .{ .champion = s.champion, .ap = kind == .ap };
        break;
    };
    return .{ .damage = damage, .timing = timing.items, .lone = lone, .top = topOf(facts, seats) };
}

fn topOf(facts: *const champfacts.Facts, seats: []const loading.Seat) ?Top {
    var top: ?Top = null;
    var most: f64 = 0;
    var sum: f64 = 0;
    var known: usize = 0;
    for (seats) |s| {
        const dpm = facts.dpmOf(s.champion, s.role orelse continue) orelse continue;
        sum += dpm;
        known += 1;
        if (dpm > most) {
            most = dpm;
            top = .{ .champion = s.champion, .share = null };
        }
    }
    if (top) |*t| if (known == 5 and seats.len == 5) {
        t.share = most / sum;
    };
    return top;
}

/// Games a champion-role's bucket is shrunk with towards even
const length_k = 100;

fn lengthOf(facts: *const champfacts.Facts, seats: [2][]const loading.Seat) ?Length {
    if (facts.lengths.len == 0 or seats[0].len != 5 or seats[1].len != 5) return null;
    var x: [champfacts.length_buckets]f64 = @splat(0);
    var v: [champfacts.length_buckets]f64 = @splat(0);
    for (seats, [_]f64{ 1, -1 }) |side, sign| for (side) |s| {
        const none: [champfacts.length_buckets]Counts = @splat(.{ .games = 0, .wins = 0 });
        const by = if (s.role) |r| facts.lengthOf(s.champion, r) orelse none else none;
        for (by, &x, &v) |c, *xb, *vb| {
            const n = @as(f64, @floatFromInt(c.games)) + length_k;
            const p = (@as(f64, @floatFromInt(c.wins)) + length_k / 2.0) / n;
            xb.* += sign * @log(p / (1 - p));
            vb.* += 1 / (n * p * (1 - p));
        }
    };
    var out: Length = .{ .win = undefined, .longer = null };
    for (&out.win, x) |*w, l| w.* = 1 / (1 + @exp(-l));
    const d = (x[3] + x[4] - x[0] - x[1]) / 2;
    const se = @sqrt(v[0] + v[1] + v[3] + v[4]) / 2;
    if (@abs(d) >= sure * se) out.longer = d > 0;
    return out;
}

/// A team's comp as loading screen pills. Picks are locked by then, so neutral facts
/// only: a tone or a win rate there would rate teammates' picks (production-key.md)
pub fn pills(arena: std.mem.Allocator, t: Team) ![]const loading.Pill {
    var out: std.ArrayList(loading.Pill) = .empty;
    if (t.damage) |d| try out.append(arena, .{ .text = switch (d.mix) {
        .physical => "AD heavy",
        .mixed => "mixed damage",
        .magic => "AP heavy",
    }, .tone = .neutral });
    if (timingOf(t)) |w| try out.append(arena, .{ .text = switch (w) {
        .early => "early team",
        .late => "late team",
        .both => "early and late",
    }, .tone = .neutral });
    return out.items;
}

pub const When = enum { early, late, both };

/// Early or late when the team's clear leans point one way; null with none
pub fn timingOf(t: Team) ?When {
    var n: [2]usize = .{ 0, 0 };
    for (t.timing) |tm| n[if (tm.lean == .early) 0 else 1] += 1;
    if (n[0] + n[1] == 0) return null;
    if (n[1] == 0) return .early;
    if (n[0] == 0) return .late;
    return .both;
}

/// Short tips for one side of the comp view (Jacob's note 109), from the same facts as
/// the rest of it: damage type, who carries the lone kind, early or late, lanes.
/// `side` 0 ours, 1 theirs. Neutral: what the comp is, never a rating of a pick
pub fn tips(arena: std.mem.Allocator, stats: *const Stats, c: *const Comp, side: usize) ![]const []const u8 {
    const t = c.teams[side];
    var out: std.ArrayList([]const u8) = .empty;
    if (t.damage) |d| switch (d.mix) {
        .physical => try out.append(arena, "All in on AD: armour goes a long way"),
        .magic => try out.append(arena, "All in on AP: magic resist goes a long way"),
        .mixed => {},
    };
    if (t.lone) |l| try out.append(arena, try std.fmt.allocPrint(arena, "Lone {s}: {s}", .{ if (l.ap) "AP" else "AD", stats.nameOf(l.champion) }));
    if (timingOf(t)) |w| switch (w) {
        .early => try out.append(arena, try std.fmt.allocPrint(arena, "Early team: best before {d} min", .{champfacts.win_minute})),
        .late => try out.append(arena, try std.fmt.allocPrint(arena, "Late team: better after {d} min", .{champfacts.win_minute})),
        .both => {},
    };
    var ahead: usize = 0;
    var sooner: usize = 0;
    for (c.lanes) |l| {
        const f = l.facts orelse continue;
        const mine = side == 0;
        if (f.edge()) |e| if ((e == .ahead and mine) or (e == .behind and !mine)) {
            ahead += 1;
        };
        if (loading.timingWord(f.level6)) |w| if ((w == .sooner) == mine) {
            sooner += 1;
        };
    }
    if (ahead >= 3) try out.append(arena, try std.fmt.allocPrint(arena, "Lane kingdom: {d} lanes usually ahead", .{ahead}));
    if (sooner >= 3) try out.append(arena, try std.fmt.allocPrint(arena, "Level 6 first in {d} lanes", .{sooner}));
    return out.items;
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
    const ps = try pills(arena, c.teams[0]);
    try testing.expectEqual(1, ps.len);
    try testing.expectEqualStrings("early and late", ps[0].text);
    try testing.expectEqual(0, (try pills(arena, c.teams[1])).len);
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
    // Even so, the pill says what the mix is, never how it does
    const ps = try pills(arena, c.teams[0]);
    try testing.expectEqualStrings("AD heavy", ps[0].text);
    try testing.expectEqual(loading.Tone.neutral, ps[0].tone);
    try testing.expectEqual(null, c.teams[0].lone);
    facts.mix[0] = .{ .games = 100, .wins = 48 };
    try testing.expect(!(try build(arena, .{ .stats = &f.stats, .facts = &facts }, .{ &seats, &.{} })).teams[0].damage.?.wins_less);
    // One mage among four physical dealers: still AD heavy, and the tips name the mage
    damage[2].magic = 0.9;
    const one = try build(arena, .{ .stats = &f.stats, .facts = &facts }, .{ &seats, &.{} });
    try testing.expectEqual(Mix.physical, one.teams[0].damage.?.mix);
    try testing.expectEqual(f.stats.ids[2], one.teams[0].lone.?.champion);
    const ts = try tips(arena, &f.stats, &one, 0);
    try testing.expectEqualStrings("All in on AD: armour goes a long way", ts[0]);
    const want = try std.fmt.allocPrint(arena, "Lone AP: {s}", .{f.stats.nameOf(f.stats.ids[2])});
    try testing.expectEqualStrings(want, ts[1]);
    try testing.expectEqual(0, (try tips(arena, &f.stats, &one, 1)).len);
}

test "comp: win chance by game length, the team's top damage" {
    var f = try cardscenes.fixture();
    defer f.deinit();
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var seats: [2][5]loading.Seat = undefined;
    var lengths: [10]champfacts.LengthRow = undefined;
    var dpm: [5]champfacts.Dpm = undefined;
    for (0..2) |side| for (&seats[side], Role.all, 0..) |*s, r, i| {
        const id = f.stats.ids[side * 5 + i];
        s.* = .{ .champion = id, .role = r };
        var by: [champfacts.length_buckets]Counts = undefined;
        // Mine win more the longer the game, theirs even throughout
        for (&by, 0..) |*c, b| c.* = .{ .games = 1000, .wins = if (side == 0) @intCast(400 + 50 * b) else 500 };
        lengths[side * 5 + i] = .{ .champion = id, .role = r, .by = by };
        if (side == 0) dpm[i] = .{ .champion = id, .role = r, .dpm = if (i == 2) 900 else 400 };
    };
    const facts: champfacts.Facts = .{ .lengths = &lengths, .dpm = &dpm };
    const c = try build(arena, .{ .stats = &f.stats, .facts = &facts }, .{ &seats[0], &seats[1] });
    const l = c.length.?;
    try testing.expect(l.win[0] < 0.3 and l.win[4] > 0.7);
    try testing.expectEqual(true, l.longer.?);
    const top = c.teams[0].top.?;
    try testing.expectEqual(f.stats.ids[2], top.champion);
    try testing.expectApproxEqAbs(900.0 / 2500.0, top.share.?, 1e-6);
    try testing.expectEqual(null, c.teams[1].top);
    // Even on both sides: no lean either way
    for (lengths[0..5]) |*x| x.by = lengths[5].by;
    try testing.expectEqual(null, (try build(arena, .{ .stats = &f.stats, .facts = &facts }, .{ &seats[0], &seats[1] })).length.?.longer);
}
