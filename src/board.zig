//! The champ select board around the lane card: both teams' seats with roles and a fact
//! each, the bans, ban options, options for allies still to pick and the draft so far.
//! Pure; the desktop window builds it from what lcu/session.zig reads. Never anyone's
//! identity: seats are champions and roles only (docs/production-key.md). What the
//! public edition may show of it is the window's call (docs/plan/app.md "Policy line")

const std = @import("std");
const core = @import("core");
const lanecard = @import("lanecard.zig");
const session = @import("lcu/session.zig");
const Role = core.Role;
const Stats = core.Stats;
const Slot = session.Slot;

/// Two builds from one codebase (docs/plan/app.md "Two editions")
pub const Edition = enum {
    public,
    /// Testers: numbers and percentages beside the public wording
    private,
};

pub const Seat = struct {
    slot: Slot,
    /// Given, or inferred from what the champion usually plays
    role: ?Role,
    guessed: bool,
    /// The champion's games and win rate in that role, from the stats file
    games: u32 = 0,
    win: f64 = 0,
    /// Allies still to pick: the recommender's best for their role
    ideas: []const u32 = &.{},
};

pub const BanOption = struct {
    champion: u32,
    role: Role,
    /// core.banimpact: wins above the role's average per 10,000 games
    impact: f64,
    /// Share of the role's games
    pick_rate: f64,
    win: f64,
    /// My lane opponent's role
    my_lane: bool,
};

/// What the lane card is doing, for its label
pub const Mode = union(enum) {
    /// Before my lane opponent shows: options that hold up against anyone
    blind,
    /// Against a known (or guessed) opponent
    counter: lanecard.Opponent,
    /// I have locked in
    locked,
};

pub const Draft = struct {
    /// My team's win chance from the draft model, 0..1, and its standard error in log-odds
    win: f64,
    se: f64,
    /// Champions counted on each side (locked, plus my team's hovers)
    picks: [2]u8,
    hovers: u8,
};

pub const Board = struct {
    allies: []const Seat,
    enemies: []const Seat,
    my_bans: []const u32,
    their_bans: []const u32,
    turn: session.Turn,
    /// "Planning", "Bans", "Picks", "Finalising"
    stage: []const u8,
    mode: Mode,
    ban_options: []const BanOption,
    /// Null before any champion shows
    draft: ?Draft,
};

pub const max_ban_options = 5;
/// Ban rows from my lane that lead while my opponent is unknown
pub const my_lane_first = 2;
pub const max_ideas = 3;

/// Allocates in `arena`. `card` is the lane card already built for the same select;
/// `facts` give the ban options their ban rates
pub fn build(arena: std.mem.Allocator, stats: *const Stats, opts: core.Options, cs: session.ChampSelect, card: ?*const lanecard.Card, facts: ?*const core.champfacts.Facts) !Board {
    const allies = try arena.alloc(Seat, cs.my_team.len);
    for (allies, cs.my_team) |*s, sl| s.* = seat(stats, opts, sl, sl.role, false);
    const enemies = try arena.alloc(Seat, cs.their_team.len);
    try placeEnemies(arena, stats, opts, cs.their_team, enemies);

    for (allies) |*s| {
        if (s.slot.state == .locked or s.slot.me) continue;
        const role = s.role orelse continue;
        s.ideas = try ideas(arena, stats, opts, cs, role);
    }

    return .{
        .allies = allies,
        .enemies = enemies,
        .my_bans = cs.my_bans,
        .their_bans = cs.their_bans,
        .turn = cs.my_turn,
        .stage = stage(cs.phase),
        .mode = if (card) |c| modeOf(c) else .blind,
        .ban_options = if (cs.bans_open) try banOptions(arena, stats, cs, enemies, card, facts) else &.{},
        .draft = draft(stats, opts, allies, enemies),
    };
}

pub fn modeOf(card: *const lanecard.Card) Mode {
    return if (card.locked) .locked else if (card.opponent) |o| .{ .counter = o } else .blind;
}

/// The lane card's input seen from the ally in `role`: their champion as mine, the rest
/// of my team (me too) as allies. Their pool, mastery and rank aren't known: options
/// come from everyone who plays the role, by the draft alone, and none once they lock
/// (lanecard.Input.ally). Null when no other ally has the role
pub fn allyLane(arena: std.mem.Allocator, mine: lanecard.Input, cs: session.ChampSelect, role: Role) !?lanecard.Input {
    if (cs.my_role == role) return null;
    const ally = for (cs.my_team) |sl| {
        if (!sl.me and sl.role == role) break sl;
    } else return null;
    var allies: std.ArrayList(core.Pick) = .empty;
    if (cs.my_champion != 0) try allies.append(arena, .{ .champion = cs.my_champion, .role = cs.my_role, .hover = !cs.my_locked });
    for (cs.allies) |p| if (p.role != role) try allies.append(arena, p);
    var in = mine;
    in.role = role;
    in.me = ally.champion;
    in.locked = ally.champion != 0 and ally.state == .locked;
    in.allies = allies.items;
    in.pickable = null;
    in.mastery = &.{};
    in.tier = null;
    in.expertise = null;
    in.ally = true;
    return in;
}

fn seat(stats: *const Stats, opts: core.Options, sl: Slot, role: ?Role, guessed: bool) Seat {
    var s: Seat = .{ .slot = sl, .role = role, .guessed = guessed };
    if (sl.champion == 0) return s;
    const r = role orelse return s;
    const c = stats.index(sl.champion) orelse return s;
    s.games = stats.champRole(r, c).games;
    s.win = core.score.roleWin(stats, opts, c, r);
    return s;
}

/// Enemy positions are hidden in ranked: each shown champion gets the role the
/// recommender would place it in
fn placeEnemies(arena: std.mem.Allocator, stats: *const Stats, opts: core.Options, slots: []const Slot, out: []Seat) !void {
    var picks: std.ArrayList(core.Pick) = .empty;
    var at: std.ArrayList(usize) = .empty;
    for (slots, 0..) |sl, i| {
        if (sl.champion == 0) continue;
        try picks.append(arena, .{ .champion = sl.champion, .role = sl.role });
        try at.append(arena, i);
    }
    const n = @min(picks.items.len, 5);
    var roles: [5]?Role = @splat(null);
    core.score.inferRoles(stats, picks.items[0..n], roles[0..n]);
    for (out, slots) |*o, sl| o.* = seat(stats, opts, sl, sl.role, false);
    for (at.items[0..n], roles[0..n]) |i, r| {
        if (slots[i].role != null) continue;
        out[i] = seat(stats, opts, slots[i], r, r != null);
    }
}

/// The best champions for an ally's role given the draft, from every champion
fn ideas(arena: std.mem.Allocator, stats: *const Stats, opts: core.Options, cs: session.ChampSelect, role: Role) ![]const u32 {
    var allies: std.ArrayList(core.Pick) = .empty;
    for (cs.my_team) |sl| {
        if (sl.champion == 0 or sl.role == role) continue;
        try allies.append(arena, .{ .champion = sl.champion, .role = sl.role, .hover = sl.state != .locked });
    }
    var buf: [max_ideas]core.Suggestion = undefined;
    const list = core.recommend(stats, .{ .role = role, .allies = allies.items, .enemies = cs.enemies, .bans = cs.bans }, opts, &buf);
    const out = try arena.alloc(u32, list.len);
    for (out, list) |*o, s| o.* = s.champion;
    return out;
}

fn stage(phase: []const u8) []const u8 {
    const names = [_]struct { []const u8, []const u8 }{
        .{ "PLANNING", "Planning" },
        .{ "BAN_PICK", "Picks and bans" },
        .{ "FINALIZATION", "Finalising" },
        .{ "GAME_STARTING", "Game starting" },
    };
    for (names) |n| if (std.mem.eql(u8, phase, n[0])) return n[1];
    return phase;
}

/// Champions the enemy may still pick, by ban impact in a role they have not filled;
/// my lane's best `my_lane_first` lead while my opponent is unknown (in bans they always
/// are); never one of the lane card's options. Impact is per 10,000 games where the
/// champion was available, by the facts' ban rate (the current patch's: the stats file
/// has no bans); without one, per 10,000 games of all
fn banOptions(arena: std.mem.Allocator, stats: *const Stats, cs: session.ChampSelect, enemies: []const Seat, card: ?*const lanecard.Card, facts: ?*const core.champfacts.Facts) ![]const BanOption {
    const my_role = if (card) |c| c.role else cs.my_role;
    const mine: []const lanecard.Option = if (card) |c| c.options else &.{};
    var open: [Role.count]bool = @splat(true);
    for (enemies) |e| if (e.slot.state == .locked) if (e.role) |r| {
        open[@backingInt(r)] = false;
    };

    var list: std.ArrayList(BanOption) = .empty;
    for (Role.all) |r| {
        if (!open[@backingInt(r)]) continue;
        const prior = core.banimpact.Prior.of(stats, r);
        var role_games: u64 = 0;
        for (0..stats.n) |c| role_games += stats.champRole(r, c).games;
        if (role_games == 0) continue;
        candidates: for (0..stats.n) |c| {
            const id = stats.ids[c];
            const cr = stats.champRole(r, c);
            if (cr.games == 0) continue;
            if (std.mem.indexOfScalar(u32, cs.bans, id) != null) continue;
            // My team's hovers and intents too: never ban what an ally wants to play
            for (cs.my_team) |sl| if (sl.champion == id) continue :candidates;
            for (mine) |o| if (o.champion == id) continue :candidates;
            for (cs.their_team) |sl| if (sl.champion == id and sl.state == .locked) continue :candidates;
            const rate: f64 = if (facts) |f| f.banRate(id) orelse 0 else 0;
            const banned: u64 = @intFromFloat(@round(rate * @as(f64, @floatFromInt(role_games))));
            const impact = prior.score(cr.wins, cr.games, banned, role_games);
            if (impact <= 0) continue;
            try list.append(arena, .{
                .champion = id,
                .role = r,
                .impact = impact,
                .pick_rate = @as(f64, @floatFromInt(cr.games)) / @as(f64, @floatFromInt(role_games)),
                .win = prior.base + prior.edge(cr.wins, cr.games),
                .my_lane = my_role == r,
            });
        }
    }
    std.mem.sort(BanOption, list.items, {}, struct {
        fn more(_: void, a: BanOption, b: BanOption) bool {
            return a.impact > b.impact;
        }
    }.more);
    // One row per champion, its strongest role
    var rows: std.ArrayList(BanOption) = .empty;
    for (list.items) |o| {
        for (rows.items) |p| {
            if (p.champion == o.champion) break;
        } else try rows.append(arena, o);
    }
    var out: std.ArrayList(BanOption) = .empty;
    for (rows.items) |o| {
        if (out.items.len == my_lane_first) break;
        if (o.my_lane) try out.append(arena, o);
    }
    // The rest by impact, past the my-lane rows already in
    var skip = out.items.len;
    for (rows.items) |o| {
        if (out.items.len == max_ban_options) break;
        if (o.my_lane and skip > 0) {
            skip -= 1;
            continue;
        }
        try out.append(arena, o);
    }
    return out.items;
}

/// The draft model on what shows so far: allies by position (hovers count), enemies by
/// the roles placed above
fn draft(stats: *const Stats, opts: core.Options, allies: []const Seat, enemies: []const Seat) ?Draft {
    var teams: [2][5]u32 = @splat(@splat(0));
    var d: Draft = .{ .win = 0.5, .se = 0, .picks = .{ 0, 0 }, .hovers = 0 };
    for ([_][]const Seat{ allies, enemies }, 0..) |side, t| for (side) |s| {
        if (s.slot.champion == 0) continue;
        if (t == 1 and s.slot.state != .locked) continue;
        const r = s.role orelse continue;
        if (teams[t][@backingInt(r)] != 0) continue;
        teams[t][@backingInt(r)] = s.slot.champion;
        d.picks[t] += 1;
        if (s.slot.state != .locked) d.hovers += 1;
    };
    if (d.picks[0] + d.picks[1] == 0) return null;
    d.win = core.score.draftWin(stats, opts, teams);
    d.se = core.score.draftSe(stats, opts, teams);
    return d;
}

const testing = std.testing;
const cardscenes = @import("cardscenes.zig");

test "board: seats, guessed enemy roles, ideas, bans, draft" {
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

    var mine = [_]Slot{
        .{ .champion = id(st, "Darius"), .role = .top, .state = .locked },
        .{ .role = .jungle, .picking = true },
        .{ .champion = id(st, "Ahri"), .role = .middle, .state = .hover, .me = true, .picking = true },
        .{ .role = .bottom },
        .{ .role = .utility },
    };
    var theirs = [_]Slot{
        .{ .champion = id(st, "Garen"), .state = .locked },
        .{ .champion = id(st, "Syndra"), .state = .locked },
        .{},
        .{},
        .{},
    };
    const cs: session.ChampSelect = .{
        .my_role = .middle,
        .my_champion = id(st, "Ahri"),
        .my_locked = false,
        .allies = @constCast(&[_]core.Pick{.{ .champion = id(st, "Darius"), .role = .top }}),
        .enemies = @constCast(&[_]core.Pick{ .{ .champion = id(st, "Garen") }, .{ .champion = id(st, "Syndra") } }),
        .bans = &.{},
        .phase = "BAN_PICK",
        .my_team = &mine,
        .their_team = &theirs,
        .my_turn = .pick,
    };
    const b = try build(arena, st, cardscenes.test_opts, cs, null, null);

    try testing.expectEqualStrings("Picks and bans", b.stage);
    try testing.expectEqual(Role.top, b.enemies[0].role.?);
    try testing.expect(b.enemies[0].guessed);
    try testing.expectEqual(Role.middle, b.enemies[1].role.?);
    try testing.expect(b.allies[0].games > 0);
    try testing.expect(b.allies[0].win > 0 and b.allies[0].win < 1);
    // Locked and my own seat get no ideas; open roles get some, never a taken champion
    try testing.expectEqual(0, b.allies[0].ideas.len);
    try testing.expectEqual(0, b.allies[2].ideas.len);
    try testing.expect(b.allies[1].ideas.len > 0);
    for (b.allies[1].ideas) |c| try testing.expect(c != id(st, "Darius") and c != id(st, "Garen"));
    // Bans only in roles the enemy has not filled
    try testing.expect(b.ban_options.len > 0);
    for (b.ban_options) |o| try testing.expect(o.role != .top and o.role != .middle);
    // In bans, before any enemy pick: my lane's best lead, the rest by impact
    var empty: [5]Slot = @splat(.{});
    var bans = cs;
    bans.enemies = &.{};
    bans.their_team = &empty;
    const opening = (try build(arena, st, cardscenes.test_opts, bans, null, null)).ban_options;
    try testing.expectEqual(max_ban_options, opening.len);
    // The fixture's one middle option leads though others have more impact
    var lead: usize = 0;
    while (lead < my_lane_first and opening[lead].my_lane) lead += 1;
    try testing.expect(lead > 0 and opening[0].role == .middle);
    try testing.expect(opening[0].impact < opening[lead].impact);
    const rest = opening[lead..];
    for (rest[1..], rest[0 .. rest.len - 1]) |o, before| try testing.expect(o.impact <= before.impact);
    // Banned in half the patch's games: picked in twice the share of games it was there
    const last = opening[opening.len - 1];
    var facts: core.champfacts.Facts = .{ .games = core.champfacts.ban_min_games, .bans = &.{.{ .champion = last.champion, .rate = 0.5 }} };
    const rated = (try build(arena, st, cardscenes.test_opts, bans, null, &facts)).ban_options;
    const again = for (rated) |o| {
        if (o.champion == last.champion) break o;
    } else return error.TestExpectedEqual;
    try testing.expectApproxEqRel(2 * last.impact, again.impact, 1e-3);
    // Too few games on the patch: as without facts
    facts.games -= 1;
    try testing.expectEqualDeep(opening, (try build(arena, st, cardscenes.test_opts, bans, null, &facts)).ban_options);
    // Never one of my own options; none once the bans are in
    const card: lanecard.Card = .{
        .role = .middle,
        .me = 0,
        .locked = false,
        .opponent = null,
        .matchup = null,
        .sentence = "",
        .options = &.{.{ .champion = b.ban_options[0].champion, .mastery = 0, .lane = null, .reasons = &.{} }},
        .period = "",
    };
    const with_card = try build(arena, st, cardscenes.test_opts, cs, &card, null);
    for (with_card.ban_options) |o| try testing.expect(o.champion != b.ban_options[0].champion);
    var done = cs;
    done.bans_open = false;
    try testing.expectEqual(0, (try build(arena, st, cardscenes.test_opts, done, null, null)).ban_options.len);
    // Darius into Garen and Ahri into Syndra: the planted matchups cancel roughly
    const d = b.draft.?;
    try testing.expectEqual(.{ 2, 2 }, d.picks);
    try testing.expectEqual(1, d.hovers);
    try testing.expect(d.win > 0.3 and d.win < 0.7 and d.se > 0);
}

test "board: an ally's lane as the card sees it" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var mine = [_]Slot{
        .{ .champion = 122, .role = .top, .state = .locked },
        .{ .role = .jungle },
        .{ .champion = 103, .role = .middle, .state = .hover, .me = true },
    };
    const cs: session.ChampSelect = .{
        .my_role = .middle,
        .my_champion = 103,
        .my_locked = false,
        .allies = @constCast(&[_]core.Pick{.{ .champion = 122, .role = .top }}),
        .enemies = &.{},
        .bans = &.{},
        .phase = "BAN_PICK",
        .my_team = &mine,
    };
    var f = try cardscenes.fixture();
    defer f.deinit();
    const base: lanecard.Input = .{ .stats = &f.stats, .curves = null, .role = .middle, .me = 103, .pickable = &.{103}, .tier = "GOLD" };
    const top = (try allyLane(arena, base, cs, .top)).?;
    try testing.expectEqual(122, top.me);
    try testing.expect(top.locked);
    try testing.expectEqual(null, top.pickable);
    try testing.expectEqual(null, top.expertise);
    try testing.expect(top.ally);
    try testing.expectEqualSlices(core.Pick, &.{.{ .champion = 103, .role = .middle, .hover = true }}, top.allies);
    const jungle = (try allyLane(arena, base, cs, .jungle)).?;
    try testing.expectEqual(0, jungle.me);
    try testing.expect(!jungle.locked);
    try testing.expectEqual(2, jungle.allies.len);
    try testing.expectEqual(null, try allyLane(arena, base, cs, .middle));
    try testing.expectEqual(null, try allyLane(arena, base, cs, .bottom));
}
