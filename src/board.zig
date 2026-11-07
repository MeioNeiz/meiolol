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
    /// The ally's champion in `role` it beats in lane, 0 for none; its share of `impact`
    /// and the points it gains there beyond both ratings, in an even game
    beats: u32 = 0,
    counter: f64 = 0,
    beats_pp: f64 = 0,
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
    /// By role, where no enemy champion is: the role's likeliest picks (likely), for an
    /// empty enemy seat placed there
    enemy_ideas: [Role.count][]const u32 = @splat(&.{}),
};

pub const max_ban_options = 5;
/// Ban rows from my lane that lead while my opponent is unknown
pub const my_lane_first = 2;
pub const max_ideas = 3;
/// Counter wins per 10,000 games for a ban option to name the ally's champion it beats
pub const min_counter = 2;
/// How much less likely by play rates a guessed role may be for an enemy's ban to pick it
/// (breakTies)
pub const ban_tie = 1.25;

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
    var enemy_ideas: [Role.count][]const u32 = @splat(&.{});
    for (Role.all, &enemy_ideas) |r, *o| {
        const filled = for (enemies) |e| {
            if (e.slot.champion != 0 and e.role == r) break true;
        } else false;
        if (!filled) o.* = try likely(arena, stats, cs, r);
    }

    return .{
        .allies = allies,
        .enemies = enemies,
        .my_bans = cs.my_bans,
        .their_bans = cs.their_bans,
        .turn = cs.my_turn,
        .stage = stage(cs.phase),
        .mode = if (card) |c| modeOf(c) else .blind,
        .ban_options = if (cs.bans_open) try banOptions(arena, stats, opts, cs, enemies, card, facts) else &.{},
        .draft = draft(stats, opts, allies, enemies),
        .enemy_ideas = enemy_ideas,
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

/// The lane card's input seen from the enemy in `role` (the board's roles: given or
/// guessed): their champion as mine, the rest of their team as allies, my team (hovers
/// too) as enemies. As an ally's: no pool, mastery or rank, options by the draft alone
/// (what they could pick into us), none once they lock
pub fn enemyLane(arena: std.mem.Allocator, mine: lanecard.Input, b: *const Board, role: Role) !lanecard.Input {
    var in = mine;
    in.role = role;
    in.me = 0;
    in.locked = false;
    var allies: std.ArrayList(core.Pick) = .empty;
    for (b.enemies) |s| {
        if (s.slot.champion == 0) continue;
        if (in.me == 0 and s.role == role) {
            in.me = s.slot.champion;
            in.locked = s.slot.state == .locked;
        } else try allies.append(arena, .{ .champion = s.slot.champion, .role = s.role });
    }
    var enemies: std.ArrayList(core.Pick) = .empty;
    for (b.allies) |s| if (s.slot.champion != 0) try enemies.append(arena, .{
        .champion = s.slot.champion,
        .role = s.role,
        .hover = s.slot.state != .locked,
    });
    in.allies = allies.items;
    in.enemies = enemies.items;
    in.pickable = null;
    in.mastery = &.{};
    in.tier = null;
    in.expertise = null;
    in.ally = true;
    return in;
}

/// An enemy's seat dragged from row `from` onto row `to`: it takes `to`, and the seat
/// placed in `to`, if any, takes `from`. `roles`: the board's enemy roles by cell, as
/// shown; `moved`: the roles set by hand so far, by cell (withMoves)
pub fn moveEnemy(roles: []const ?Role, moved: []?Role, from: Role, to: Role) void {
    if (from == to) return;
    const a = std.mem.findScalar(?Role, roles, from) orelse return;
    if (std.mem.findScalar(?Role, roles, to)) |b| moved[b] = from;
    moved[a] = to;
}

/// `cs` with enemy roles moved by hand (moveEnemy) in place of the client's or the
/// guess, on their seats and their picks: the board, the lane card and the draft follow
pub fn withMoves(arena: std.mem.Allocator, cs: session.ChampSelect, moved: []const ?Role) !session.ChampSelect {
    var out = cs;
    const team = try arena.dupe(Slot, cs.their_team);
    const picks = try arena.dupe(core.Pick, cs.enemies);
    for (team, 0..) |*sl, i| {
        const r = (if (i < moved.len) moved[i] else null) orelse continue;
        sl.role = r;
        if (sl.champion == 0) continue;
        for (picks) |*p| if (p.champion == sl.champion) {
            p.role = r;
        };
    }
    out.their_team = team;
    out.enemies = picks;
    return out;
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
    var given: [5]bool = undefined;
    var hints: [5]?Role = undefined;
    var fit: [5][Role.count]f64 = undefined;
    for (0..n) |k| {
        const sl = slots[at.items[k]];
        given[k] = sl.role != null;
        hints[k] = if (sl.ban != 0) mainRole(stats, sl.ban) else null;
        fit[k] = roleFit(stats, sl.champion);
    }
    breakTies(roles[0..n], given[0..n], hints[0..n], fit[0..n]);
    for (out, slots) |*o, sl| o.* = seat(stats, opts, sl, sl.role, false);
    for (at.items[0..n], roles[0..n]) |i, r| {
        if (slots[i].role != null) continue;
        out[i] = seat(stats, opts, slots[i], r, r != null);
    }
}

/// An enemy's ban hints at their role (players ban their lane's threats), but no data
/// says how strongly: match-v5 bans have a pick turn, not a cell. So it only breaks near
/// ties: pick k, guessed in `roles[k]` (not `given[k]`), moves to its seat's ban's role
/// `hints[k]` when that placement is at most `ban_tie` times less likely by the picks'
/// role shares `fit`, swapping with the guessed pick there (one whose ban hints the same
/// role keeps it)
fn breakTies(roles: []?Role, given: []const bool, hints: []const ?Role, fit: []const [Role.count]f64) void {
    for (roles, given, hints, fit) |*r, g, hint, f| {
        const want = hint orelse continue;
        const now = r.* orelse continue;
        if (g or now == want) continue;
        var odds = f[@backingInt(want)] / f[@backingInt(now)];
        const other = std.mem.findScalar(?Role, roles, want);
        if (other) |j| {
            if (given[j] or hints[j] == want) continue;
            odds *= fit[j][@backingInt(now)] / fit[j][@backingInt(want)];
        }
        if (odds * ban_tie < 1) continue;
        if (other) |j| roles[j] = now;
        r.* = want;
    }
}

/// A champion's share of its games in each role, with core.score's floor so a role never
/// seen is unlikely, not impossible
fn roleFit(stats: *const Stats, champion: u32) [Role.count]f64 {
    var out: [Role.count]f64 = @splat(0.2);
    const c = stats.index(champion) orelse return out;
    const total: f64 = @floatFromInt(stats.champGames(c));
    if (total == 0) return out;
    for (&out, Role.all) |*o, r| o.* = @as(f64, @floatFromInt(stats.champRole(r, c).games)) / total + 1e-4;
    return out;
}

/// The role a champion is played in most, null when the stats file has no games of it
fn mainRole(stats: *const Stats, champion: u32) ?Role {
    const c = stats.index(champion) orelse return null;
    var best: ?Role = null;
    var most: u32 = 0;
    for (Role.all) |r| {
        const games = stats.champRole(r, c).games;
        if (games > most) {
            best = r;
            most = games;
        }
    }
    return best;
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

/// The role's most played champions still free (not banned, on neither team), by the
/// stats file's games in the role: who an empty enemy seat there likely picks
fn likely(arena: std.mem.Allocator, stats: *const Stats, cs: session.ChampSelect, role: Role) ![]const u32 {
    var top: [max_ideas]struct { id: u32 = 0, games: u32 = 0 } = @splat(.{});
    for (stats.ids, 0..) |id, c| {
        const games = stats.champRole(role, c).games;
        if (games <= top[max_ideas - 1].games or taken(cs, id)) continue;
        var i: usize = max_ideas - 1;
        while (i > 0 and top[i - 1].games < games) : (i -= 1) top[i] = top[i - 1];
        top[i] = .{ .id = id, .games = games };
    }
    var out: std.ArrayList(u32) = .empty;
    for (top) |t| if (t.games > 0) try out.append(arena, t.id);
    return out.items;
}

fn taken(cs: session.ChampSelect, id: u32) bool {
    for ([_][]const Slot{ cs.my_team, cs.their_team }) |slots| for (slots) |sl| if (sl.champion == id) return true;
    for ([_][]const u32{ cs.bans, cs.my_bans, cs.their_bans }) |list| if (std.mem.findScalar(u32, list, id) != null) return true;
    return false;
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
/// has no bans); without one, per 10,000 games of all. An ally's champion in the role
/// (hover, intent or lock) adds what the candidate gains against it beyond both ratings,
/// at the same pick rate: banning it spares that lane the matchup
fn banOptions(arena: std.mem.Allocator, stats: *const Stats, opts: core.Options, cs: session.ChampSelect, enemies: []const Seat, card: ?*const lanecard.Card, facts: ?*const core.champfacts.Facts) ![]const BanOption {
    const my_role = if (card) |c| c.role else cs.my_role;
    const mine: []const lanecard.Option = if (card) |c| c.options else &.{};
    var open: [Role.count]bool = @splat(true);
    for (enemies) |e| if (e.slot.state == .locked) if (e.role) |r| {
        open[@backingInt(r)] = false;
    };

    var laner: [Role.count]?usize = @splat(null);
    for (cs.my_team) |sl| if (sl.champion != 0) if (sl.role) |r| {
        laner[@backingInt(r)] = stats.index(sl.champion);
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
            const own = prior.score(cr.wins, cr.games, banned, role_games);
            var o: BanOption = .{
                .champion = id,
                .role = r,
                .pick_rate = @as(f64, @floatFromInt(cr.games)) / @as(f64, @floatFromInt(role_games)),
                .win = prior.base + prior.edge(cr.wins, cr.games),
                .impact = own,
                .my_lane = my_role == r,
            };
            if (laner[@backingInt(r)]) |a| if (banned < role_games) {
                const m = core.score.matchupLogit(stats, opts, r, c, r, a);
                const pp = 1 / (1 + @exp(-m)) - 0.5;
                const available: f64 = @floatFromInt(role_games - banned);
                o.counter = 1e4 * pp * @as(f64, @floatFromInt(cr.games)) / available;
                o.impact += o.counter;
                if (o.counter >= min_counter) {
                    o.beats = stats.ids[a];
                    o.beats_pp = 100 * pp;
                }
            };
            if (o.impact <= 0) continue;
            try list.append(arena, o);
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
    // Empty enemy seats: the open roles' most played, most first, none taken or banned
    try testing.expectEqual(0, b.enemy_ideas[@backingInt(Role.top)].len);
    try testing.expectEqual(0, b.enemy_ideas[@backingInt(Role.middle)].len);
    var banned = cs;
    const jungle = b.enemy_ideas[@backingInt(Role.jungle)];
    try testing.expectEqual(max_ideas, jungle.len);
    for (jungle[1..], jungle[0 .. jungle.len - 1]) |c, before|
        try testing.expect(st.champRole(.jungle, st.index(c).?).games <= st.champRole(.jungle, st.index(before).?).games);
    banned.bans = @constCast(&[_]u32{jungle[0]});
    const after_ban = (try build(arena, st, cardscenes.test_opts, banned, null, null)).enemy_ideas[@backingInt(Role.jungle)];
    try testing.expectEqualSlices(u32, jungle[1..], after_ban[0..2]);
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
    // Darius locked in top: Malphite, planted to beat him, names him and gains on Darius
    // still to pick; nothing else in top beats him that much
    const counter = for (opening) |o| {
        if (o.champion == id(st, "Malphite")) break o;
    } else return error.TestExpectedEqual;
    try testing.expectEqual(id(st, "Darius"), counter.beats);
    try testing.expect(counter.counter >= min_counter and counter.beats_pp > 0.5);
    for (opening) |o| if (o.role == .top and o.champion != counter.champion) try testing.expect(o.beats == 0);
    var undecided = mine;
    undecided[0] = .{ .role = .top };
    var no_top = bans;
    no_top.my_team = &undecided;
    const plain_top = try build(arena, st, cardscenes.test_opts, no_top, null, null);
    for (plain_top.ban_options) |o| try testing.expect(o.beats != id(st, "Darius"));
    const plain = for (plain_top.ban_options) |o| {
        if (o.champion == counter.champion) break o;
    } else return error.TestExpectedEqual;
    try testing.expectApproxEqAbs(plain.impact + counter.counter, counter.impact, 1e-9);
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

    // Their jungle still to pick: what they could pick into my team
    const mine_in: lanecard.Input = .{ .stats = st, .curves = null, .role = .middle, .me = id(st, "Ahri"), .opts = cardscenes.test_opts };
    const theirs_in = try enemyLane(arena, mine_in, &b, .jungle);
    try testing.expectEqual(0, theirs_in.me);
    const threats = try lanecard.build(arena, theirs_in);
    try testing.expect(threats.options.len >= lanecard.min_options);
    for (threats.options) |o| try testing.expect(o.champion != id(st, "Darius") and o.champion != id(st, "Ahri"));
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

test "board: an enemy's lane from their side" {
    var f = try cardscenes.fixture();
    defer f.deinit();
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const ally_seats = [_]Seat{
        .{ .slot = .{ .champion = 122, .role = .top, .state = .locked }, .role = .top, .guessed = false },
        .{ .slot = .{ .champion = 103, .role = .middle, .state = .hover, .me = true }, .role = .middle, .guessed = false },
        .{ .slot = .{ .role = .jungle }, .role = .jungle, .guessed = false },
    };
    const enemy_seats = [_]Seat{
        .{ .slot = .{ .champion = 86, .state = .locked }, .role = .top, .guessed = true },
        .{ .slot = .{ .champion = 134, .state = .locked }, .role = .middle, .guessed = true },
        .{ .slot = .{}, .role = null, .guessed = false },
    };
    const b: Board = .{
        .allies = &ally_seats,
        .enemies = &enemy_seats,
        .my_bans = &.{},
        .their_bans = &.{},
        .turn = .none,
        .stage = "",
        .mode = .blind,
        .ban_options = &.{},
        .draft = null,
    };
    const base: lanecard.Input = .{ .stats = &f.stats, .curves = null, .role = .middle, .me = 103, .pickable = &.{103}, .tier = "GOLD" };
    const top = try enemyLane(arena, base, &b, .top);
    try testing.expectEqual(86, top.me);
    try testing.expect(top.locked and top.ally);
    try testing.expectEqual(null, top.pickable);
    try testing.expectEqualSlices(core.Pick, &.{.{ .champion = 134, .role = .middle }}, top.allies);
    try testing.expectEqualSlices(core.Pick, &.{ .{ .champion = 122, .role = .top }, .{ .champion = 103, .role = .middle, .hover = true } }, top.enemies);
    const jungle = try enemyLane(arena, base, &b, .jungle);
    try testing.expectEqual(0, jungle.me);
    try testing.expect(!jungle.locked);
    try testing.expectEqual(2, jungle.allies.len);
}

test "board: an enemy moved by hand swaps rows, the rest guessed around them" {
    var f = try cardscenes.fixture();
    defer f.deinit();
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const st = &f.stats;
    const garen = st.ids[st.find("Garen").?];
    const syndra = st.ids[st.find("Syndra").?];
    var mine = [_]Slot{ .{ .role = .top }, .{ .role = .jungle }, .{ .role = .middle, .me = true }, .{ .role = .bottom }, .{ .role = .utility } };
    var theirs = [_]Slot{ .{ .champion = garen, .state = .locked }, .{ .champion = syndra, .state = .locked }, .{}, .{}, .{} };
    const cs: session.ChampSelect = .{
        .my_role = .middle,
        .my_champion = 0,
        .my_locked = false,
        .allies = &.{},
        .enemies = @constCast(&[_]core.Pick{ .{ .champion = garen }, .{ .champion = syndra } }),
        .bans = &.{},
        .phase = "BAN_PICK",
        .my_team = &mine,
        .their_team = &theirs,
    };
    const before = try build(arena, st, cardscenes.test_opts, cs, null, null);
    var roles: [5]?Role = undefined;
    for (&roles, before.enemies) |*r, s| r.* = s.role;
    try testing.expectEqualSlices(?Role, &.{ .top, .middle, null, null, null }, &roles);

    // Garen dragged onto the middle row: Syndra takes top
    var moved: [5]?Role = @splat(null);
    moveEnemy(&roles, &moved, .top, .middle);
    try testing.expectEqualSlices(?Role, &.{ .middle, .top, null, null, null }, &moved);
    const swapped = try withMoves(arena, cs, &moved);
    try testing.expectEqual(null, cs.their_team[0].role);
    try testing.expectEqual(Role.top, swapped.enemies[1].role.?);
    const after = try build(arena, st, cardscenes.test_opts, swapped, null, null);
    try testing.expectEqual(Role.middle, after.enemies[0].role.?);
    try testing.expectEqual(Role.top, after.enemies[1].role.?);
    for (after.ban_options) |o| try testing.expect(o.role != .top and o.role != .middle);

    // Onto a row no enemy is placed in: only Syndra moves
    moved = @splat(null);
    moveEnemy(&roles, &moved, .middle, .bottom);
    try testing.expectEqualSlices(?Role, &.{ null, .bottom, null, null, null }, &moved);
    // From a row with no placed enemy, or onto its own: nothing
    moved = @splat(null);
    moveEnemy(&roles, &moved, .jungle, .top);
    moveEnemy(&roles, &moved, .top, .top);
    try testing.expectEqualSlices(?Role, &(@as([5]?Role, @splat(null))), &moved);
}

test "board: an enemy's ban breaks a near tie in their role guess, no more" {
    const o = 1e-4;
    // Top 45%, middle 55%: guessed middle, a top ban moves them
    var roles = [_]?Role{ .middle, .jungle };
    const fit = [_][Role.count]f64{ .{ 0.45, o, 0.55, o, o }, .{ o, 1, o, o, o } };
    breakTies(&roles, &.{ false, false }, &.{ .top, null }, &fit);
    try testing.expectEqualSlices(?Role, &.{ .top, .jungle }, &roles);
    // 30% against 70%: the guess stands
    roles = .{ .middle, .jungle };
    breakTies(&roles, &.{ false, false }, &.{ .top, null }, &.{ .{ 0.3, o, 0.7, o, o }, fit[1] });
    try testing.expectEqualSlices(?Role, &.{ .middle, .jungle }, &roles);

    // Both even between top and middle: the ban swaps them
    const even = [_][Role.count]f64{ .{ 0.5, o, 0.5, o, o }, .{ 0.5, o, 0.5, o, o } };
    roles = .{ .top, .middle };
    breakTies(&roles, &.{ false, false }, &.{ .middle, null }, &even);
    try testing.expectEqualSlices(?Role, &.{ .middle, .top }, &roles);
    // Not when the other's role is given, nor when their ban hints the same role
    roles = .{ .top, .middle };
    breakTies(&roles, &.{ false, true }, &.{ .middle, null }, &even);
    try testing.expectEqualSlices(?Role, &.{ .top, .middle }, &roles);
    breakTies(&roles, &.{ false, false }, &.{ .middle, .middle }, &even);
    try testing.expectEqualSlices(?Role, &.{ .top, .middle }, &roles);

    // On the board: Garen plays only top, so a middle ban leaves him there
    var f = try cardscenes.fixture();
    defer f.deinit();
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const st = &f.stats;
    const garen = st.ids[st.find("Garen").?];
    const syndra = st.ids[st.find("Syndra").?];
    try testing.expectEqual(Role.middle, mainRole(st, syndra).?);
    var mine = [_]Slot{ .{ .role = .top }, .{ .role = .jungle }, .{ .role = .middle, .me = true }, .{ .role = .bottom }, .{ .role = .utility } };
    var theirs = [_]Slot{ .{ .champion = garen, .state = .locked, .ban = syndra }, .{}, .{}, .{}, .{} };
    const b = try build(arena_state.allocator(), st, cardscenes.test_opts, .{
        .my_role = .middle,
        .my_champion = 0,
        .my_locked = false,
        .allies = &.{},
        .enemies = @constCast(&[_]core.Pick{.{ .champion = garen }}),
        .bans = @constCast(&[_]u32{syndra}),
        .phase = "BAN_PICK",
        .my_team = &mine,
        .their_team = &theirs,
    }, null, null);
    try testing.expectEqual(Role.top, b.enemies[0].role.?);
    try testing.expect(b.enemies[0].guessed);
}
