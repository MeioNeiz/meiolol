//! Practice: a champ select set up by hand in the window, before any lobby. The setup
//! becomes a mock client state (lcu/mock.zig) that goes through the same parsers and
//! builders as the real client's replies, so turns, hidden enemy hovers and ban reveals
//! behave as in a real champ select. Game and post game numbers are made up from the
//! minute and a lead.

const std = @import("std");
const core = @import("core");
const mock = @import("lcu/mock.zig");
const session = @import("lcu/session.zig");
const live = @import("lcu/live.zig");
const eog = @import("lcu/eog.zig");
const lanecard = @import("lanecard.zig");
const board = @import("board.zig");
const loading = @import("loading.zig");
const comp = @import("comp.zig");
const ingame = @import("ingame.zig");
const postgame = @import("postgame.zig");
const Role = core.Role;
const Stats = core.Stats;

pub const Stage = enum { planning, bans, picks, finalising };
pub const Screen = enum { select, loading, game, post };
pub const Lead = enum { behind, even, ahead };

pub const Seat = struct { champion: u32 = 0, locked: bool = false };

/// Where a placed champion goes: allies by role, enemies and bans by place
pub const Target = union(enum) {
    ally: Role,
    enemy: u3,
    my_ban: u3,
    their_ban: u3,
};

/// What the player set: plain data, copied between threads
pub const Setup = struct {
    role: Role = .middle,
    /// My place in my team's pick order, 0 first
    pick: u3 = 2,
    stage: Stage = .picks,
    screen: Screen = .select,
    /// By role
    mine: [5]Seat = @splat(.{}),
    /// By cell; their positions are hidden, as in ranked
    theirs: [5]Seat = @splat(.{}),
    my_bans: [5]u32 = @splat(0),
    their_bans: [5]u32 = @splat(0),
    minute: u8 = 15,
    lead: Lead = .even,
    win: bool = true,

    pub fn at(s: *Setup, t: Target) *u32 {
        return switch (t) {
            .ally => |r| &s.mine[@backingInt(r)].champion,
            .enemy => |i| &s.theirs[i].champion,
            .my_ban => |i| &s.my_bans[i],
            .their_ban => |i| &s.their_bans[i],
        };
    }

    /// A champion shows once per draft, bans included: it leaves wherever else it was.
    /// 0 clears the place
    pub fn place(s: *Setup, t: Target, champion: u32, locked: bool) void {
        if (champion != 0) for (s.allPlaces()) |p| {
            if (p.* == champion) p.* = 0;
        };
        s.at(t).* = champion;
        switch (t) {
            .ally => |r| s.mine[@backingInt(r)].locked = locked,
            // An enemy hover never shows, so theirs are always locks
            .enemy => |i| s.theirs[i].locked = true,
            .my_ban, .their_ban => {},
        }
    }

    pub fn clear(s: *Setup) void {
        s.mine = @splat(.{});
        s.theirs = @splat(.{});
        s.my_bans = @splat(0);
        s.their_bans = @splat(0);
    }

    fn allPlaces(s: *Setup) [20]*u32 {
        var out: [20]*u32 = undefined;
        for (0..5) |i| {
            out[i] = &s.mine[i].champion;
            out[5 + i] = &s.theirs[i].champion;
            out[10 + i] = &s.my_bans[i];
            out[15 + i] = &s.their_bans[i];
        }
        return out;
    }

    /// Everything locked: each seat and ban a champion often played in its role, picked
    /// at random by games (enemies in cell order top to support)
    pub fn randomise(s: *Setup, stats: *const Stats, rng: std.Random) void {
        s.clear();
        for (Role.all) |r| {
            s.place(.{ .ally = r }, popular(stats, r, rng, s), true);
            s.place(.{ .enemy = @backingInt(r) }, popular(stats, r, rng, s), true);
        }
        for (0..5) |i| {
            const r = Role.all[rng.uintLessThan(usize, Role.count)];
            s.place(.{ .my_ban = @intCast(i) }, popular(stats, r, rng, s), true);
            s.place(.{ .their_ban = @intCast(i) }, popular(stats, r, rng, s), true);
        }
    }

    /// My team's role in each cell: mine at my pick, the rest in role order
    pub fn cells(s: Setup) [5]Role {
        var out: [5]Role = undefined;
        var next: usize = 0;
        for (&out, 0..) |*c, i| {
            if (i == s.pick) {
                c.* = s.role;
                continue;
            }
            if (Role.all[next] == s.role) next += 1;
            c.* = Role.all[next];
            next += 1;
        }
        return out;
    }
};

/// A champion with games in `role`, weighted by them, not yet in the draft
fn popular(stats: *const Stats, role: Role, rng: std.Random, s: *Setup) u32 {
    var total: u64 = 0;
    for (0..stats.ids.len) |c| total += weight(stats, role, c, s);
    if (total == 0) return 0;
    var x = rng.uintLessThan(u64, total);
    for (0..stats.ids.len) |c| {
        const wt = weight(stats, role, c, s);
        if (x < wt) return stats.ids[c];
        x -= wt;
    }
    return 0;
}

fn weight(stats: *const Stats, role: Role, c: usize, s: *Setup) u64 {
    for (s.allPlaces()) |p| if (p.* == stats.ids[c]) return 0;
    return stats.champRole(role, c).games;
}

/// The mock client for `s`, champions named as in the stats file. Allocates in `arena`
pub fn scenario(arena: std.mem.Allocator, stats: *const Stats, s: Setup) !mock.Scenario {
    var sc: mock.Scenario = .{
        .name = "practice",
        .queue = 420,
        .local_cell = s.pick,
        .positions = .{ "", "", "", "", "", "", "", "", "", "" },
        .pick_order = &.{ &.{0}, &.{ 5, 6 }, &.{ 1, 2 }, &.{ 7, 8 }, &.{ 3, 4 }, &.{9} },
        .mastery = &.{},
        .tier = "",
        .pickable = &.{},
        .owned = &.{},
        .steps = &.{},
        .names = .empty,
        .ids = .empty,
    };
    for (s.cells(), 0..) |r, i| sc.positions[i] = lcuName(r);
    if (s.stage == .picks) sc.pick_order = try myTurnNow(arena, s);
    for (stats.ids, stats.names) |id, n| {
        try sc.names.put(arena, n, id);
        try sc.ids.put(arena, id, n);
    }
    return sc;
}

/// In picks it is always my turn, whatever is filled in: the locked seats picked before
/// me, the empty ones pick after
fn myTurnNow(arena: std.mem.Allocator, s: Setup) ![]const []const u8 {
    var before: std.ArrayList(u8) = .empty;
    var after: std.ArrayList(u8) = .empty;
    for (s.cells(), 0..) |r, i| {
        if (i == s.pick) continue;
        try (if (s.mine[@backingInt(r)].locked and s.mine[@backingInt(r)].champion != 0) &before else &after).append(arena, @intCast(i));
    }
    for (s.theirs, 5..) |seat, i| try (if (seat.champion != 0) &before else &after).append(arena, @intCast(i));
    var groups: std.ArrayList([]const u8) = .empty;
    if (before.items.len > 0) try groups.append(arena, before.items);
    try groups.append(arena, try arena.dupe(u8, &.{s.pick}));
    if (after.items.len > 0) try groups.append(arena, after.items);
    return groups.items;
}

fn lcuName(r: Role) []const u8 {
    return switch (r) {
        inline else => |t| @tagName(t),
    };
}

/// The client's state for `s` on its screen
pub fn state(s: Setup) mock.State {
    var st: mock.State = .{
        .phase = switch (s.screen) {
            .select => "ChampSelect",
            .loading => "GameStart",
            .game => "InProgress",
            .post => "EndOfGame",
        },
        .timer = switch (s.stage) {
            .planning => "PLANNING",
            .bans, .picks => "BAN_PICK",
            .finalising => "FINALIZATION",
        },
    };
    const in_game = s.screen != .select;
    for (s.cells(), 0..) |r, i| {
        const seat = s.mine[@backingInt(r)];
        const c = &st.cells[i];
        c.position = lcuName(r);
        if (seat.champion == 0) continue;
        if (s.stage == .planning and !seat.locked and !in_game) {
            c.intent = seat.champion;
        } else {
            c.champion = seat.champion;
            c.locked = seat.locked or in_game;
            if (c.locked) c.locked_with = seat.champion;
        }
    }
    for (s.theirs, 5..) |seat, i| {
        st.cells[i].champion = seat.champion;
        st.cells[i].locked = seat.champion != 0;
        st.cells[i].locked_with = seat.champion;
    }
    // The ban turn: every other ban is in, mine is still going
    for (&st.cells, 0..) |*c, i| {
        c.ban = if (i < 5) s.my_bans[i] else s.their_bans[i - 5];
        c.banned = in_game or switch (s.stage) {
            .planning => false,
            .bans => i != s.pick,
            .picks, .finalising => true,
        };
    }
    if (s.screen == .game or s.screen == .post) game(&st, s);
    return st;
}

/// Gold, cs and levels a game of `s.minute` minutes might have, my team ahead or behind
/// by about 8% of item gold
fn game(st: *mock.State, s: Setup) void {
    const m: f64 = @floatFromInt(@max(1, s.minute));
    st.game_time = 60 * m;
    st.gold = 450;
    st.win = s.win;
    const lead: f64 = switch (s.lead) {
        .behind => -0.08,
        .even => 0,
        .ahead => 0.08,
    };
    const roles = s.cells();
    for (&st.cells, 0..) |*c, i| {
        const r = if (i < 5) roles[i] else Role.all[i - 5];
        // Each champion a little off its role's rate, so lanes differ
        const jitter = (@as(f64, @floatFromInt(c.champion % 13)) - 6) * 0.012;
        const f = 1 + jitter + if (i < 5) lead else -lead;
        const per_min: [Role.count][2]f64 = .{ .{ 380, 6.8 }, .{ 360, 5.4 }, .{ 390, 7.2 }, .{ 400, 7.6 }, .{ 250, 1.2 } };
        const rate = per_min[@backingInt(r)];
        c.items = @intFromFloat(@max(0, (rate[0] * m - 500) * f));
        c.cs = @intFromFloat(rate[1] * m * f);
        const levels: f64 = if (r == .utility) 0.5 else 0.62;
        c.level = @intFromFloat(@min(18, 1 + m * levels * f));
        // A few kills a player by mid game, more for the team ahead
        const share = 0.12 * m * f;
        const killer: f64 = if (r == .utility) 0.3 else 1;
        c.kills = @intFromFloat(share * killer);
        c.deaths = @intFromFloat(0.12 * m * (2 - f) * 0.8);
        c.assists = @intFromFloat(share * 1.4);
    }
}

pub const Input = struct {
    stats: *const Stats,
    curves: ?*const core.curvesfile.Curves = null,
    facts: ?*const core.champfacts.Facts = null,
    mastery: []const lanecard.Mastery = &.{},
    tier: ?[]const u8 = null,
    expertise: ?lanecard.Expertise = .fitted,
};

pub const Select = struct { card: lanecard.Card, board: board.Board, comp: ?*const comp.Comp };

pub const Built = union(enum) {
    select: Select,
    loading: loading.Loading,
    in_game: ingame.InGame,
    post_game: postgame.PostGame,
};

/// What the window shows for `s`, built as the poller builds a real client's. Allocates
/// in `arena`
pub fn build(arena: std.mem.Allocator, in: Input, s: Setup) !Built {
    const sc = try scenario(arena, in.stats, s);
    // The loading screen and the game come after the draft, every seat locked
    var draft = s;
    draft.screen = .select;
    if (s.screen != .select) {
        draft.stage = .finalising;
        for (&draft.mine) |*seat| seat.locked = true;
    }
    const sel = try selectOf(arena, in, &sc, draft);
    switch (s.screen) {
        .select => return .{ .select = sel },
        .loading => return .{ .loading = try loading.build(arena, .{
            .stats = in.stats,
            .curves = in.curves,
            .facts = in.facts,
            .seats = try loading.seatsOf(arena, &sel.board),
            .draft = sel.board.draft,
            .tier = in.tier,
        }) },
        .game, .post => {},
    }
    var playing = s;
    playing.screen = .game;
    const st = state(playing);
    var g = try ingame.build(arena, in.stats, in.curves, try live.parse(arena, (try mock.live(arena, &sc, &st, live.path)).body), in.tier);
    g.history = try ingame.madeUp(arena, g.sample());
    if (s.screen == .game) return .{ .in_game = g };

    const end = state(s);
    var hints: std.ArrayList(postgame.Hint) = .empty;
    for ([_][]const board.Seat{ sel.board.allies, sel.board.enemies }, [_]bool{ true, false }) |seats, ours| for (seats) |seat| {
        const r = seat.role orelse continue;
        if (seat.slot.champion != 0) try hints.append(arena, .{ .champion = seat.slot.champion, .role = r, .ours = ours });
    };
    return .{ .post_game = try postgame.build(arena, .{
        .stats = in.stats,
        .curves = in.curves,
        .eog = try eog.parse(arena, (try mock.lcu(arena, &sc, &end, eog.path)).body),
        .history = g.history,
        .hints = hints.items,
        .tier = in.tier,
    }) };
}

fn selectOf(arena: std.mem.Allocator, in: Input, sc: *const mock.Scenario, s: Setup) !Select {
    const st = state(s);
    const cs = try session.parse(arena, (try mock.lcu(arena, sc, &st, session.paths.session)).body);
    const card = try lanecard.build(arena, .{
        .stats = in.stats,
        .curves = in.curves,
        .role = cs.my_role.?,
        .me = cs.my_champion,
        .locked = cs.my_locked,
        .allies = cs.allies,
        .enemies = cs.enemies,
        .bans = cs.bans,
        .mastery = in.mastery,
        .tier = in.tier,
        .expertise = in.expertise,
    });
    const b = try board.build(arena, in.stats, .{}, cs, &card, in.facts);
    return .{ .card = card, .board = b, .comp = try comp.after(arena, .{ .stats = in.stats, .curves = in.curves, .facts = in.facts, .tier = in.tier }, &b) };
}

const testing = std.testing;
const cardscenes = @import("cardscenes.zig");

fn parseSession(a: std.mem.Allocator, stats: *const Stats, s: Setup) !session.ChampSelect {
    const sc = try scenario(a, stats, s);
    const st = state(s);
    const r = try mock.lcu(a, &sc, &st, session.paths.session);
    return session.parse(a, r.body);
}

test "my pick place and role" {
    var s: Setup = .{ .role = .bottom, .pick = 0 };
    try testing.expectEqualSlices(Role, &.{ .bottom, .top, .jungle, .middle, .utility }, &s.cells());
    s = .{ .role = .top, .pick = 4 };
    try testing.expectEqualSlices(Role, &.{ .jungle, .middle, .bottom, .utility, .top }, &s.cells());
}

test "place keeps a champion once" {
    var s: Setup = .{};
    s.place(.{ .ally = .top }, 7, true);
    s.place(.{ .their_ban = 1 }, 7, true);
    try testing.expectEqual(0, s.mine[0].champion);
    try testing.expectEqual(7, s.their_bans[1]);
    s.place(.{ .enemy = 2 }, 7, false);
    try testing.expectEqual(0, s.their_bans[1]);
    try testing.expect(s.theirs[2].locked);
}

test "turns and reveals through the session parser" {
    var f = try cardscenes.fixture();
    defer f.deinit();
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const id = struct {
        fn of(st: *const Stats, n: []const u8) u32 {
            return st.idOf(n).?;
        }
    }.of;
    var s: Setup = .{ .role = .middle, .pick = 2 };
    s.place(.{ .ally = .top }, id(&f.stats, "Garen"), true);
    s.place(.{ .ally = .jungle }, id(&f.stats, "Vi"), false);
    s.place(.{ .enemy = 0 }, id(&f.stats, "Darius"), true);
    s.place(.{ .my_ban = 0 }, id(&f.stats, "Zed"), true);
    s.place(.{ .their_ban = 0 }, id(&f.stats, "Teemo"), true);

    var cs = try parseSession(a, &f.stats, s);
    try testing.expectEqual(Role.middle, cs.my_role.?);
    try testing.expectEqual(.pick, cs.my_turn);
    try testing.expectEqual(2, cs.bans.len);
    try testing.expectEqual(1, cs.enemies.len);
    try testing.expectEqual(null, cs.enemies[0].role);

    s.stage = .bans;
    cs = try parseSession(a, &f.stats, s);
    try testing.expectEqual(.ban, cs.my_turn);
    try testing.expectEqual(2, cs.bans.len);

    s.stage = .planning;
    cs = try parseSession(a, &f.stats, s);
    try testing.expectEqual(.none, cs.my_turn);
    try testing.expectEqual(.intent, cs.my_team[1].state);
}

test "every screen builds" {
    var f = try cardscenes.fixture();
    defer f.deinit();
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var prng: std.Random.DefaultPrng = .init(1);
    var s: Setup = .{ .minute = 20, .lead = .ahead };
    s.randomise(&f.stats, prng.random());
    for (s.mine) |seat| try testing.expect(seat.champion != 0 and seat.locked);
    const in: Input = .{ .stats = &f.stats, .curves = &f.curves };

    const sel = (try build(a, in, s)).select;
    try testing.expectEqual(5, sel.board.allies.len);
    try testing.expectEqual(.locked, sel.board.mode);
    s.screen = .loading;
    const l = (try build(a, in, s)).loading;
    try testing.expectEqual(5, l.teams[1].len);
    s.screen = .game;
    const g = (try build(a, in, s)).in_game;
    try testing.expectEqual(1200, g.time);
    try testing.expect(g.score[0].item_gold > g.score[1].item_gold);
    try testing.expect(g.history.len > 10);
    s.screen = .post;
    s.win = false;
    const pg = (try build(a, in, s)).post_game;
    try testing.expect(!pg.win);
    try testing.expectEqual(1200, pg.length);
}
