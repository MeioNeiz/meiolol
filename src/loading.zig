//! The loading screen cards (docs/plan/app.md APP10): ten cards, our row over theirs, from
//! the last champ select's seats (board.zig: roles given or guessed). Champion facts only,
//! as short pills coloured by meaning (research/questions/desktop-app-layout.md C1-C3),
//! some playful (Jacob's note 113): how the champion does in its role now, its lane
//! against the same role across with level 6 and first item timings, its early or late
//! lean, lone damage type, ban and pick rates. Player scouting is APP7's, private, where names
//! are visible. Pure.

const std = @import("std");
const core = @import("core");
const lanecard = @import("lanecard.zig");
const board = @import("board.zig");
const comp = @import("comp.zig");
const Role = core.Role;
const Stats = core.Stats;
const curvesfile = core.curvesfile;

pub const Tone = enum { neutral, good, bad, caution };

pub const Pill = struct {
    text: []const u8,
    tone: Tone,
};

/// A seat as the poller keeps it from champ select
pub const Seat = struct {
    champion: u32,
    role: ?Role,
    guessed: bool = false,
    me: bool = false,
};

pub const Card = struct {
    champion: u32,
    role: ?Role,
    guessed: bool,
    me: bool,
    /// The champion's games and win rate in the role
    games: u32,
    win: f64,
    pills: []const Pill,
};

pub const Loading = struct {
    /// Ours, theirs; in role order where known
    teams: [2][]const Card,
    /// The draft model at the end of champ select; the private edition shows it
    draft: ?board.Draft,
    /// The comp view of the same ten (comp.zig), and each team's pills from it
    comp: ?comp.Comp = null,
    team_pills: [2][]const Pill = .{ &.{}, &.{} },
};

pub const Input = struct {
    stats: *const Stats,
    curves: ?*const curvesfile.Curves = null,
    facts: ?*const core.champfacts.Facts = null,
    /// Ours, theirs
    seats: [2][]const Seat,
    draft: ?board.Draft = null,
    tier: ?[]const u8 = null,
    opts: core.Options = .{},
};

/// A lane lead this many standard errors from even gets a colour
const sure = 2;
/// Seconds: closer timings are "about the same" and get no pill
const timing_gap = 20;

/// Allocates in `arena`
pub fn build(arena: std.mem.Allocator, in: Input) !Loading {
    const cv = try comp.build(arena, .{ .stats = in.stats, .curves = in.curves, .facts = in.facts, .tier = in.tier }, in.seats);
    var out: Loading = .{ .teams = undefined, .draft = in.draft, .comp = cv };
    for (&out.team_pills, cv.teams) |*p, t| p.* = try comp.pills(arena, t);
    for (in.seats, 0..) |team, side| {
        const sorted = try arena.dupe(Seat, team);
        std.mem.sort(Seat, sorted, {}, struct {
            fn before(_: void, a: Seat, b: Seat) bool {
                const ra: usize = if (a.role) |r| @backingInt(r) else Role.count;
                const rb: usize = if (b.role) |r| @backingInt(r) else Role.count;
                return ra < rb;
            }
        }.before);
        const cards = try arena.alloc(Card, sorted.len);
        for (cards, sorted) |*c, s| c.* = try card(arena, in, s, team, in.seats[1 - side]);
        out.teams[side] = cards;
    }
    return out;
}

/// Most a card shows, the first found in pillsOf's order
pub const max_pills = 4;
/// A role pick share from here up is "crowd favourite"
const popular_share = 0.10;
/// A ban rate from here up is "ban magnet"
const banned_rate = 0.25;

fn card(arena: std.mem.Allocator, in: Input, s: Seat, team: []const Seat, across: []const Seat) !Card {
    var c: Card = .{ .champion = s.champion, .role = s.role, .guessed = s.guessed, .me = s.me, .games = 0, .win = 0.5, .pills = &.{} };
    const stats = in.stats;
    const role = s.role orelse return c;
    const at = stats.index(s.champion) orelse return c;
    c.games = stats.champRole(role, at).games;
    c.win = core.score.roleWin(stats, in.opts, at, role);
    var pills: std.ArrayList(Pill) = .empty;
    if (c.games < 1000) {
        try pills.append(arena, .{ .text = "hipster pick", .tone = .caution });
    } else if (c.win >= 0.515) {
        try pills.append(arena, .{ .text = "strong now", .tone = .good });
    } else if (c.win <= 0.485) {
        try pills.append(arena, .{ .text = "weak now", .tone = .bad });
    }
    const opp = for (across) |o| {
        if (o.role == role and o.champion != 0) break o;
    } else null;
    if (opp) |o| if (in.curves) |curves| try lanePills(arena, in, curves, role, s.champion, o.champion, &pills);
    if (in.facts) |f| try factPills(arena, f, s, role, team, &pills);
    // Two players per role a game
    const share = @as(f64, @floatFromInt(c.games)) / @as(f64, @floatFromInt(@max(1, 2 * @as(u64, stats.games))));
    if (c.games >= 1000 and share >= popular_share) try pills.append(arena, .{ .text = "crowd favourite", .tone = .neutral });
    c.pills = pills.items[0..@min(pills.items.len, max_pills)];
    return c;
}

/// "scales" or "early game", "lone AP", "ban magnet"
fn factPills(arena: std.mem.Allocator, f: *const core.champfacts.Facts, s: Seat, role: Role, team: []const Seat, pills: *std.ArrayList(Pill)) !void {
    if (f.leanOf(s.champion, role)) |row| switch (row.lean()) {
        .early => try pills.append(arena, .{ .text = "early game", .tone = .neutral }),
        .late => try pills.append(arena, .{ .text = "scales", .tone = .neutral }),
        .none => {},
    };
    if (lone(f, s.champion, team)) |kind| try pills.append(arena, .{ .text = if (kind == .ap) "lone AP" else "lone AD", .tone = .neutral });
    if (f.banRate(s.champion)) |r| if (r >= banned_rate) try pills.append(arena, .{ .text = "ban magnet", .tone = .neutral });
}

pub const Kind = enum { ap, ad };

/// .ap when `champion` is its team's only magic dealer, .ad its only physical one; null
/// unless all five splits are known
pub fn lone(f: *const core.champfacts.Facts, champion: u32, team: []const Seat) ?Kind {
    if (team.len != 5) return null;
    var magic: [5]f32 = undefined;
    var mine: ?usize = null;
    for (team, &magic, 0..) |t, *m, i| {
        m.* = f.magicOf(t.champion) orelse return null;
        if (t.champion == champion) mine = i;
    }
    const at = mine orelse return null;
    for ([_]bool{ true, false }) |ap| {
        var dealers: usize = 0;
        for (magic) |m| {
            if (if (ap) m >= lone_share else m <= 1 - lone_share) dealers += 1;
        }
        const is = if (ap) magic[at] >= lone_share else magic[at] <= 1 - lone_share;
        if (is and dealers == 1) return if (ap) .ap else .ad;
    }
    return null;
}

/// A champion dealing this share of one kind of damage counts as a dealer of it
const lone_share = 0.6;

/// A lane matchup's curve as the loading screen and the comp view read it
pub const LaneFacts = struct {
    games: u32,
    /// Gold at lane_minute, mine minus theirs; null when the curve stops sooner
    gold: ?struct { mean: i32, se: i32 },
    /// Seconds, mine minus theirs (negative: mine sooner); null when either is unknown
    level6: ?i32,
    first_item: ?i32,

    pub const Edge = enum { ahead, even, behind };

    /// Ahead or behind only `sure` standard errors from even
    pub fn edge(f: LaneFacts) ?Edge {
        const g = f.gold orelse return null;
        const z = @as(f64, @floatFromInt(g.mean)) / @as(f64, @floatFromInt(@max(1, g.se)));
        return if (z >= sure) .ahead else if (z <= -sure) .behind else .even;
    }
};

/// Null without a curve with enough games of the pair, mine the champion's own way round
pub fn laneFacts(curves: *const curvesfile.Curves, role: Role, tier: ?[]const u8, me: u32, them: u32) ?LaneFacts {
    const found = lanecard.view(curves, role, lanecard.bracketOf(tier), me, them) orelse return null;
    const v = found.view;
    if (v.games() < lanecard.thin_games or v.own() < 0.5) return null;
    var f: LaneFacts = .{ .games = v.games(), .gold = null, .level6 = null, .first_item = null };
    if (v.minutes() >= curvesfile.lane_minute) {
        const e = v.estimate(.gold, curvesfile.lane_minute - 1);
        f.gold = .{ .mean = e.mean, .se = @max(1, e.se) };
    }
    for ([_][2]u16{ v.level6(), v.firstItem() }, [_]*?i32{ &f.level6, &f.first_item }) |t, out| {
        if (t[0] == 0 or t[1] == 0) continue;
        out.* = @as(i32, t[0]) - t[1];
    }
    return f;
}

/// Closer timings than timing_gap are "about the same"
pub fn timingWord(gap: ?i32) ?enum { sooner, later } {
    const g = gap orelse return null;
    if (@abs(g) < timing_gap) return null;
    return if (g < 0) .sooner else .later;
}

/// "lane bully" or "tough lane", "6 first", "slow items": no names, the card across
/// shows who
fn lanePills(arena: std.mem.Allocator, in: Input, curves: *const curvesfile.Curves, role: Role, me: u32, them: u32, pills: *std.ArrayList(Pill)) !void {
    const f = laneFacts(curves, role, in.tier, me, them) orelse return;
    const jungle = role == .jungle;
    if (f.edge()) |e| switch (e) {
        .ahead => try pills.append(arena, .{ .text = if (jungle) "strong start" else "lane bully", .tone = .good }),
        .behind => try pills.append(arena, .{ .text = if (jungle) "slow start" else "tough lane", .tone = .bad }),
        .even => {},
    };
    if (timingWord(f.level6)) |w| try pills.append(arena, if (w == .sooner)
        .{ .text = "6 first", .tone = .good }
    else
        .{ .text = "6 later", .tone = .caution });
    if (timingWord(f.first_item)) |w| try pills.append(arena, if (w == .sooner)
        .{ .text = "items first", .tone = .good }
    else
        .{ .text = "slow items", .tone = .caution });
}

/// The seats of the last champ select as the loading screen keeps them
pub fn seatsOf(arena: std.mem.Allocator, b: *const board.Board) ![2][]const Seat {
    var out: [2][]const Seat = undefined;
    for ([_][]const board.Seat{ b.allies, b.enemies }, &out) |list, *o| {
        var keep: std.ArrayList(Seat) = .empty;
        for (list) |s| {
            if (s.slot.champion == 0) continue;
            try keep.append(arena, .{ .champion = s.slot.champion, .role = s.role, .guessed = s.guessed, .me = s.slot.me });
        }
        o.* = keep.items;
    }
    return out;
}

const testing = std.testing;
const cardscenes = @import("cardscenes.zig");

test "loading screen: cards by role, lane pills against the same role across" {
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
    const ours = [_]Seat{
        .{ .champion = id(st, "Ahri"), .role = .middle, .me = true },
        .{ .champion = id(st, "Darius"), .role = .top },
    };
    const theirs = [_]Seat{
        .{ .champion = id(st, "Syndra"), .role = .middle, .guessed = true },
        .{ .champion = id(st, "Malphite"), .role = .top, .guessed = true },
        .{ .champion = id(st, "Teemo"), .role = null, .guessed = true },
    };
    const l = try build(arena, .{ .stats = st, .curves = &f.curves, .seats = .{ &ours, &theirs }, .opts = cardscenes.test_opts });
    // Role order: top first
    try testing.expectEqual(id(st, "Darius"), l.teams[0][0].champion);
    try testing.expect(l.teams[0][1].me);
    // Planted: Malphite beats Darius in lane, Syndra beats Ahri
    const has = struct {
        fn in(c: Card, text: []const u8, tone: Tone) bool {
            for (c.pills) |p| if (std.mem.eql(u8, p.text, text) and p.tone == tone) return true;
            return false;
        }
    }.in;
    try testing.expect(has(l.teams[0][0], "tough lane", .bad));
    try testing.expect(has(l.teams[1][0], "lane bully", .good));
    try testing.expect(has(l.teams[1][1], "lane bully", .good));
    // No role: no facts
    try testing.expectEqual(0, l.teams[1][2].pills.len);
}
