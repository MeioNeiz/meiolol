//! The loading screen cards (docs/plan/app.md APP10): ten cards, our row over theirs, from
//! the last champ select's seats (board.zig: roles given or guessed). Champion facts only,
//! as short pills coloured by meaning (research/questions/desktop-app-layout.md C1-C3),
//! some playful (Jacob's note 113): how the champion does in its role now, lone damage
//! type, ban and pick rates; at most two, none that half the board shares. Beside them
//! the lane against the same role across (the lane strip: gold, level 6 and first item
//! timings) and wins by game length (the card's spark). The private edition adds
//! what the client says about each other player (Card.player). Pure.

const std = @import("std");
const core = @import("core");
const players = @import("lcu/players.zig");
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
    /// Rates the pick on today's patch ("strong now", "weak now")
    patch: bool = false,
};

/// Public shows only the patch pills, which read plainly ("hipster pick", "ban magnet",
/// "lone AP" are jargon there), and never rates a locked teammate's pick
/// (docs/production-key.md): on my own card and the enemies'
pub fn shows(p: Pill, c: Card, ours: bool, private: bool) bool {
    return private or (p.patch and (c.me or !ours));
}

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
    /// Against the same role across: the lane strip; null without a curve of the pair
    lane: ?LaneFacts = null,
    /// Games and wins by game length (champfacts.length_edges): the card's spark
    lengths: ?Lengths = null,
    /// Private edition only; null on my card and for streamer-mode players
    player: ?Player = null,
};

pub const Player = players.Facts;

/// A player's facts by the champion they play: unique in a draft game
pub const Scouted = struct { champion: u32, player: Player };

pub const Lengths = @FieldType(core.champfacts.LengthRow, "by");

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
    scouted: []const Scouted = &.{},
};

/// A lane lead this many standard errors from even gets a colour
const sure = 2;
/// Seconds: closer timings are "about the same" and get no pill
const timing_gap = 20;

/// Allocates in `arena`
pub fn build(arena: std.mem.Allocator, in: Input) !Loading {
    const cv = try comp.build(arena, .{ .stats = in.stats, .curves = in.curves, .facts = in.facts, .tier = in.tier }, in.seats);
    var out: Loading = .{ .teams = undefined, .draft = in.draft, .comp = cv };
    var all: [2][]Card = undefined;
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
        all[side] = cards;
    }
    try cutPills(arena, all);
    out.teams = .{ all[0], all[1] };
    return out;
}

/// Most a card shows, the first found in card's order
pub const max_pills = 2;
/// A role pick share from here up is "crowd favourite"
const popular_share = 0.10;
/// Under this role pick share, "hipster pick": about one card a game on the full snap
/// (2.06M games, 16.21: 9.8% of seats)
const hipster_share = 0.005;

/// A pill on more than half the cards says nothing about any one of them: it goes, then
/// each card keeps its first max_pills
fn cutPills(arena: std.mem.Allocator, teams: [2][]Card) !void {
    const n = teams[0].len + teams[1].len;
    var kept: [2][][]const Pill = undefined;
    for (&kept, teams) |*k, t| {
        k.* = try arena.alloc([]const Pill, t.len);
        for (k.*, t) |*ps, c| {
            var keep: std.ArrayList(Pill) = .empty;
            for (c.pills) |p| {
                if (keep.items.len == max_pills) break;
                if (n >= 6 and 2 * cardsWith(teams, p.text) > n) continue;
                try keep.append(arena, p);
            }
            ps.* = keep.items;
        }
    }
    for (kept, teams) |k, t| for (k, t) |ps, *c| {
        c.pills = ps;
    };
}

fn cardsWith(teams: [2][]Card, text: []const u8) usize {
    var on: usize = 0;
    for (teams) |t| for (t) |c| for (c.pills) |q| {
        if (std.mem.eql(u8, q.text, text)) on += 1;
    };
    return on;
}
/// A ban rate from here up is "ban magnet"
const banned_rate = 0.25;

fn card(arena: std.mem.Allocator, in: Input, s: Seat, team: []const Seat, across: []const Seat) !Card {
    var c: Card = .{ .champion = s.champion, .role = s.role, .guessed = s.guessed, .me = s.me, .games = 0, .win = 0.5, .pills = &.{} };
    if (!s.me) for (in.scouted) |x| if (x.champion == s.champion and !x.player.empty()) {
        c.player = x.player;
    };
    const stats = in.stats;
    const role = s.role orelse return c;
    const at = stats.index(s.champion) orelse return c;
    c.games = stats.champRole(role, at).games;
    c.win = core.score.roleWin(stats, in.opts, at, role);
    if (in.facts) |f| c.lengths = f.lengthOf(s.champion, role);
    // Two players per role a game
    const share = @as(f64, @floatFromInt(c.games)) / @as(f64, @floatFromInt(@max(1, 2 * @as(u64, stats.games))));
    var pills: std.ArrayList(Pill) = .empty;
    if (share < hipster_share) {
        try pills.append(arena, .{ .text = "hipster pick", .tone = .caution });
    } else if (c.win >= 0.515) {
        try pills.append(arena, .{ .text = "strong now", .tone = .good, .patch = true });
    } else if (c.win <= 0.485) {
        try pills.append(arena, .{ .text = "weak now", .tone = .bad, .patch = true });
    }
    const opp = for (across) |o| {
        if (o.role == role and o.champion != 0) break o;
    } else null;
    if (opp) |o| if (in.curves) |curves| {
        c.lane = laneFacts(curves, role, in.tier, s.champion, o.champion);
    };
    if (in.facts) |f| try factPills(arena, f, s, team, &pills);
    if (share >= popular_share) try pills.append(arena, .{ .text = "crowd favourite", .tone = .neutral });
    c.pills = pills.items;
    return c;
}

/// "lone AP", "ban magnet"; the early or late lean is the card's spark
fn factPills(arena: std.mem.Allocator, f: *const core.champfacts.Facts, s: Seat, team: []const Seat, pills: *std.ArrayList(Pill)) !void {
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

test "loading screen: cards by role, lane facts against the same role across" {
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
    const scouted = [_]Scouted{
        .{ .champion = id(st, "Ahri"), .player = .{ .tier = "Gold" } },
        .{ .champion = id(st, "Syndra"), .player = .{ .tier = "Gold", .games = 20, .on_pick = 6, .won = 4 } },
        .{ .champion = id(st, "Malphite"), .player = .{} },
    };
    const l = try build(arena, .{ .stats = st, .curves = &f.curves, .seats = .{ &ours, &theirs }, .opts = cardscenes.test_opts, .scouted = &scouted });
    // My own card says nothing about me; a player with nothing known gets no line
    try testing.expectEqual(null, l.teams[0][1].player);
    try testing.expectEqual(null, l.teams[1][0].player);
    try testing.expectEqual(6, l.teams[1][1].player.?.on_pick);
    // Role order: top first
    try testing.expectEqual(id(st, "Darius"), l.teams[0][0].champion);
    try testing.expect(l.teams[0][1].me);
    // Planted: Malphite beats Darius in lane, Syndra beats Ahri
    try testing.expectEqual(.behind, l.teams[0][0].lane.?.edge().?);
    try testing.expectEqual(.ahead, l.teams[1][0].lane.?.edge().?);
    try testing.expectEqual(.ahead, l.teams[1][1].lane.?.edge().?);
    // No role: no facts
    try testing.expectEqual(0, l.teams[1][2].pills.len);
    try testing.expectEqual(null, l.teams[1][2].lane);
}

test "loading screen: a pill on more than half the board goes, then two a card" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const common: Pill = .{ .text = "crowd favourite", .tone = .neutral };
    const pills = [_]Pill{ common, .{ .text = "lone AP", .tone = .neutral }, .{ .text = "6 first", .tone = .good }, .{ .text = "ban magnet", .tone = .neutral } };
    var cards: [2][5]Card = undefined;
    for (&cards) |*t| for (t, 0..) |*c, i| {
        c.* = .{ .champion = @intCast(i + 1), .role = null, .guessed = false, .me = false, .games = 0, .win = 0.5, .pills = if (i == 0) &pills else &.{common} };
    };
    try cutPills(arena, .{ &cards[0], &cards[1] });
    try testing.expectEqual(2, cards[0][0].pills.len);
    try testing.expectEqualStrings("lone AP", cards[0][0].pills[0].text);
    try testing.expectEqualStrings("6 first", cards[0][0].pills[1].text);
    try testing.expectEqual(0, cards[1][3].pills.len);
}
