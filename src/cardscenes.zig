//! Champ select scenes for the lane card (testdata/cards/scenes.json). `meiolol-app
//! cards` shows them against real stats and curves, to compare settings before a
//! recommender change ships; the tests here show them against a synthetic fixture and
//! keep the text in testdata/cards/fixture.txt, so any change in what a player would
//! read shows as a diff. Random drafts check what must always hold (pool, 3 to 5
//! options, policy wording).

const std = @import("std");
const core = @import("core");
const lanecard = @import("lanecard.zig");
const Role = core.Role;
const Stats = core.Stats;
const Pick = core.Pick;

pub const default_path = "testdata/cards/scenes.json";

pub const Scene = struct {
    name: []const u8,
    role: []const u8,
    me: []const u8 = "",
    locked: bool = false,
    /// As `meiolol-app suggest`: "jungle=Vi" for a known position, a trailing "?" for a
    /// hover; enemies' positions are hidden in ranked, so they usually have none
    allies: []const []const u8 = &.{},
    enemies: []const []const u8 = &.{},
    bans: []const []const u8 = &.{},
    /// Owned and pickable; null when anything goes
    pickable: ?[]const []const u8 = null,
    /// [name, points], any order
    mastery: []const struct { []const u8, u32 } = &.{},
    tier: ?[]const u8 = null,
};

pub fn load(arena: std.mem.Allocator, io: std.Io, path: []const u8) ![]const Scene {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 20));
    return std.json.parseFromSliceLeaky([]const Scene, arena, bytes, .{});
}

pub const Error = error{ UnknownChampion, UnknownRole } || std.mem.Allocator.Error;

/// Names resolved against `stats`; `bad` holds the name an error is about
pub fn input(
    arena: std.mem.Allocator,
    stats: *const Stats,
    curves: ?*const core.curvesfile.Curves,
    s: Scene,
    opts: core.Options,
    bad: *[]const u8,
) Error!lanecard.Input {
    const ids: Ids = .{ .stats = stats, .bad = bad };
    var bans: std.ArrayList(u32) = .empty;
    for (s.bans) |n| try bans.append(arena, try ids.of(n));
    var pickable: ?[]const u32 = null;
    if (s.pickable) |names| {
        const out = try arena.alloc(u32, names.len);
        for (names, out) |n, *o| o.* = try ids.of(n);
        pickable = out;
    }
    const mastery = try arena.alloc(lanecard.Mastery, s.mastery.len);
    for (s.mastery, mastery) |m, *o| o.* = .{ .champion = try ids.of(m[0]), .points = m[1] };
    std.mem.sort(lanecard.Mastery, mastery, {}, morePoints);
    bad.* = s.role;
    return .{
        .stats = stats,
        .curves = curves,
        .role = Role.parse(s.role) orelse return error.UnknownRole,
        .me = if (s.me.len > 0) try ids.of(s.me) else 0,
        .locked = s.locked,
        .allies = try ids.picks(arena, s.allies),
        .enemies = try ids.picks(arena, s.enemies),
        .bans = bans.items,
        .pickable = pickable,
        .mastery = mastery,
        .tier = s.tier,
        .opts = opts,
    };
}

fn morePoints(_: void, a: lanecard.Mastery, b: lanecard.Mastery) bool {
    return a.points > b.points;
}

const Ids = struct {
    stats: *const Stats,
    bad: *[]const u8,

    fn of(ids: Ids, name: []const u8) Error!u32 {
        const i = ids.stats.find(name) orelse {
            ids.bad.* = name;
            return error.UnknownChampion;
        };
        return ids.stats.ids[i];
    }

    fn picks(ids: Ids, arena: std.mem.Allocator, names: []const []const u8) Error![]Pick {
        const out = try arena.alloc(Pick, names.len);
        for (names, out) |raw, *p| {
            var name = raw;
            p.* = .{ .champion = 0 };
            if (std.mem.endsWith(u8, name, "?")) {
                p.hover = true;
                name = name[0 .. name.len - 1];
            }
            if (std.mem.findScalar(u8, name, '=')) |eq| {
                p.role = Role.parse(name[0..eq]) orelse {
                    ids.bad.* = raw;
                    return error.UnknownRole;
                };
                name = name[eq + 1 ..];
            }
            p.champion = try ids.of(name);
        }
        return out;
    }
};

const testing = std.testing;
const statsfile = core.statsfile;
const curvesfile = core.curvesfile;

/// Champions of the scenes, by main role, with a planted strength (log-odds) and how
/// often they are picked; Teemo too rarely for test_opts.min_games
const Champ = struct { id: u32, name: []const u8, role: Role, strength: f64, weight: u32 = 10 };
const champs = [_]Champ{
    .{ .id = 86, .name = "Garen", .role = .top, .strength = 0.05 },
    .{ .id = 122, .name = "Darius", .role = .top, .strength = 0.10 },
    .{ .id = 875, .name = "Sett", .role = .top, .strength = 0 },
    .{ .id = 54, .name = "Malphite", .role = .top, .strength = 0.08 },
    .{ .id = 516, .name = "Ornn", .role = .top, .strength = -0.05 },
    .{ .id = 17, .name = "Teemo", .role = .top, .strength = 0, .weight = 1 },
    .{ .id = 254, .name = "Vi", .role = .jungle, .strength = 0.05 },
    .{ .id = 64, .name = "Lee Sin", .role = .jungle, .strength = -0.05 },
    .{ .id = 234, .name = "Viego", .role = .jungle, .strength = 0 },
    .{ .id = 103, .name = "Ahri", .role = .middle, .strength = 0.05 },
    .{ .id = 134, .name = "Syndra", .role = .middle, .strength = 0 },
    .{ .id = 61, .name = "Orianna", .role = .middle, .strength = -0.03 },
    .{ .id = 112, .name = "Viktor", .role = .middle, .strength = 0.08 },
    .{ .id = 238, .name = "Zed", .role = .middle, .strength = -0.02 },
    .{ .id = 222, .name = "Jinx", .role = .bottom, .strength = 0.06 },
    .{ .id = 51, .name = "Caitlyn", .role = .bottom, .strength = 0 },
    .{ .id = 81, .name = "Ezreal", .role = .bottom, .strength = -0.06 },
    .{ .id = 145, .name = "Kai'Sa", .role = .bottom, .strength = 0.02 },
    .{ .id = 99, .name = "Lux", .role = .utility, .strength = 0.04 },
    .{ .id = 111, .name = "Nautilus", .role = .utility, .strength = 0.02 },
    .{ .id = 43, .name = "Karma", .role = .utility, .strength = -0.04 },
    .{ .id = 412, .name = "Thresh", .role = .utility, .strength = 0 },
};

/// Planted lane matchups (log-odds for a over b, and gold at 14): Darius beats Garen,
/// Malphite beats Darius, Syndra beats Ahri
const Plant = struct { a: []const u8, b: []const u8, logit: f64, gold: i16 };
const plants = [_]Plant{
    .{ .a = "Darius", .b = "Garen", .logit = 0.35, .gold = 450 },
    .{ .a = "Malphite", .b = "Darius", .logit = 0.3, .gold = 200 },
    .{ .a = "Syndra", .b = "Ahri", .logit = 0.25, .gold = 300 },
};

pub const Fixture = struct {
    stats_bytes: []u8,
    stats: Stats,
    curves: curvesfile.Curves,

    pub fn deinit(f: *Fixture) void {
        f.stats.deinit(testing.allocator);
        testing.allocator.free(f.stats_bytes);
        f.curves.deinit(testing.allocator);
    }
};

fn plant(a: u32, b: u32) Plant {
    for (plants) |p| {
        const pa = champs[champIndex(p.a)].id;
        const pb = champs[champIndex(p.b)].id;
        if (a == pa and b == pb) return p;
        if (a == pb and b == pa) return .{ .a = p.b, .b = p.a, .logit = -p.logit, .gold = -p.gold };
    }
    return .{ .a = "", .b = "", .logit = 0, .gold = 0 };
}

fn champIndex(name: []const u8) usize {
    for (champs, 0..) |c, i| if (std.mem.eql(u8, c.name, name)) return i;
    unreachable;
}

/// Deterministic games from the planted strengths; the same bytes on every run
pub fn fixture() !Fixture {
    const gpa = testing.allocator;
    var named: [champs.len]statsfile.Champion = undefined;
    for (champs, &named) |c, *n| n.* = .{ .id = c.id, .name = c.name };
    var sb: statsfile.Builder = try .init(gpa, &named);
    defer sb.deinit();
    var cb: curvesfile.Builder = .{ .gpa = gpa };
    defer cb.deinit();

    var prng: std.Random.DefaultPrng = .init(20261020);
    const rand = prng.random();
    for (0..6000) |g| {
        var teams: [2][5]u32 = undefined;
        var logit: f64 = 0;
        for (Role.all) |role| {
            const r = @backingInt(role);
            teams[0][r] = pickIn(rand, role, 0);
            teams[1][r] = pickIn(rand, role, teams[0][r]);
            logit += strengthOf(teams[0][r]) - strengthOf(teams[1][r]);
            logit += plant(teams[0][r], teams[1][r]).logit;
        }
        const blue_won = rand.float(f64) < 1 / (1 + @exp(-logit));
        sb.addGame(teams, if (blue_won) 0 else 1);
        for ([_]Role{ .top, .middle }) |role| {
            const a = teams[0][@backingInt(role)];
            const b = teams[1][@backingInt(role)];
            const at14: f64 = 2000 * (strengthOf(a) - strengthOf(b)) + @as(f64, @floatFromInt(plant(a, b).gold)) +
                600 * (rand.float(f64) - 0.5) + if (blue_won) @as(f64, 300) else -300;
            var l: curvesfile.Lane = .{
                .role = role,
                .bracket = @as(curvesfile.Bracket, @fromBackingInt(@intCast(@as(u8, @intCast(1 + g % 3))))),
                .a = a,
                .b = b,
                .a_won = blue_won,
                .minutes = 20,
            };
            for (0..20) |m| l.gold[m] = @trunc(at14 * @as(f64, @floatFromInt(m + 1)) / curvesfile.lane_minute);
            try cb.addLane(l);
        }
        cb.addGame();
    }

    var aw: std.Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();
    try sb.write(&aw.writer, "test");
    const bytes = try aw.toOwnedSlice();
    errdefer gpa.free(bytes);
    var stats: Stats = try .parse(gpa, bytes);
    errdefer stats.deinit(gpa);
    var cw: std.Io.Writer.Allocating = .init(gpa);
    defer cw.deinit();
    try cb.write(&cw.writer, "last 30 days", 1);
    return .{ .stats_bytes = bytes, .stats = stats, .curves = try .parse(gpa, cw.written()) };
}

fn pickIn(rand: std.Random, role: Role, taken: u32) u32 {
    var total: u32 = 0;
    for (champs) |c| {
        if (c.role == role and c.id != taken) total += c.weight;
    }
    var at = rand.uintLessThan(u32, total);
    for (champs) |c| {
        if (c.role != role or c.id == taken) continue;
        if (at < c.weight) return c.id;
        at -= c.weight;
    }
    unreachable;
}

fn strengthOf(id: u32) f64 {
    for (champs) |c| if (c.id == id) return c.strength;
    unreachable;
}

pub const test_opts: core.Options = .{ .min_games = 300 };
const golden_path = "testdata/cards/fixture.txt";
const got_path = ".zig-cache/cards-fixture.got.txt";

test "scenes on the fixture match testdata/cards/fixture.txt" {
    const io = testing.io;
    var f = try fixture();
    defer f.deinit();
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const scenes = try load(arena, io, default_path);
    try testing.expect(scenes.len >= 8);

    var aw: std.Io.Writer.Allocating = .init(arena);
    const w = &aw.writer;
    for (scenes) |s| {
        var bad: []const u8 = "";
        const in = input(arena, &f.stats, &f.curves, s, test_opts, &bad) catch |err| {
            std.debug.print("scene {s}: {t} {s}\n", .{ s.name, err, bad });
            return err;
        };
        const card = try lanecard.build(arena, in);
        try w.print("== {s}\n", .{s.name});
        try lanecard.write(card, &f.stats, w);
        try checkCard(in, card);
    }
    const want = try std.Io.Dir.cwd().readFileAlloc(io, golden_path, arena, .limited(1 << 20));
    if (!std.mem.eql(u8, want, aw.written())) {
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = got_path, .data = aw.written() });
        std.debug.print("lane cards changed: diff {s} {s}; if intended, cp it over\n", .{ golden_path, got_path });
        return error.CardsChanged;
    }
}

test "random drafts: pool, option count, policy wording" {
    var f = try fixture();
    defer f.deinit();
    var prng: std.Random.DefaultPrng = .init(7);
    const rand = prng.random();
    for (0..400) |_| {
        var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
        defer arena_state.deinit();
        const arena = arena_state.allocator();
        var used: std.ArrayList(u32) = .empty;
        const role = Role.all[rand.uintLessThan(usize, Role.count)];
        const allies = try randomPicks(arena, rand, &used, rand.uintAtMost(usize, 4), role);
        const enemies = try randomPicks(arena, rand, &used, rand.uintAtMost(usize, 5), null);
        const bans = try arena.alloc(u32, rand.uintAtMost(usize, 4));
        for (bans) |*b| b.* = champs[rand.uintLessThan(usize, champs.len)].id;
        var pickable: ?[]const u32 = null;
        if (rand.boolean()) {
            var list: std.ArrayList(u32) = .empty;
            for (champs) |c| if (rand.uintLessThan(u8, 4) != 0) try list.append(arena, c.id);
            pickable = list.items;
        }
        var mastery: std.ArrayList(lanecard.Mastery) = .empty;
        var points: u32 = 400_000;
        for (champs) |c| {
            if (rand.uintLessThan(u8, 3) != 0) continue;
            points = rand.uintAtMost(u32, points);
            try mastery.append(arena, .{ .champion = c.id, .points = points });
        }
        const in: lanecard.Input = .{
            .stats = &f.stats,
            .curves = &f.curves,
            .role = role,
            .allies = allies,
            .enemies = enemies,
            .bans = bans,
            .pickable = pickable,
            .mastery = mastery.items,
            .opts = test_opts,
        };
        try checkCard(in, try lanecard.build(arena, in));
    }
}

fn randomPicks(arena: std.mem.Allocator, rand: std.Random, used: *std.ArrayList(u32), n: usize, skip: ?Role) ![]Pick {
    var out: std.ArrayList(Pick) = .empty;
    while (out.items.len < n) {
        const c = champs[rand.uintLessThan(usize, champs.len)];
        if (std.mem.findScalar(u32, used.items, c.id) != null) continue;
        if (skip == c.role) continue;
        try used.append(arena, c.id);
        try out.append(arena, .{
            .champion = c.id,
            .role = if (rand.boolean()) c.role else null,
            .hover = rand.uintLessThan(u8, 4) == 0,
        });
    }
    return out.items;
}

/// What every card must hold, whatever the draft
fn checkCard(in: lanecard.Input, card: lanecard.Card) !void {
    // The pool as lanecard.options takes it: the most-played champions it may suggest,
    // counted before bans and picks
    var pool: usize = 0;
    var pool_left: usize = 0;
    for (in.mastery) |m| {
        if (pool == lanecard.pool_size or m.points == 0) break;
        if (!eligible(in, m.champion)) continue;
        pool += 1;
        if (available(in, m.champion)) pool_left += 1;
    }
    var everyone: usize = 0;
    for (in.stats.ids) |id| {
        if (eligible(in, id) and available(in, id) and playsRole(in, id)) everyone += 1;
    }
    const from_pool = pool_left >= lanecard.min_options;
    try testing.expectEqual(@min(if (from_pool) pool_left else everyone, lanecard.max_options), card.options.len);
    // Filled up, the pool's champions still come first
    if (!from_pool) for (card.options[0..pool_left]) |o| try testing.expect(masteryOf(in, o.champion) > 0);
    for (card.options, 0..) |o, i| {
        try testing.expect(available(in, o.champion) and eligible(in, o.champion));
        if (from_pool) try testing.expect(masteryOf(in, o.champion) > 0);
        if (i >= pool_left) try testing.expect(playsRole(in, o.champion));
        for (card.options[0..i]) |p| try testing.expect(p.champion != o.champion);
        for (o.reasons) |r| try policyWording(r);
        if (o.lane) |l| try policyWording(l.text);
    }
}

/// Played enough in the role and pickable
fn eligible(in: lanecard.Input, id: u32) bool {
    const i = in.stats.index(id) orelse return false;
    if (in.stats.champRole(in.role, i).games < in.opts.min_games) return false;
    if (in.pickable) |p| if (std.mem.findScalar(u32, p, id) == null) return false;
    return true;
}

/// Enough of its games in the role to fill up a pool
fn playsRole(in: lanecard.Input, id: u32) bool {
    const i = in.stats.index(id).?;
    const g: f64 = @floatFromInt(in.stats.champRole(in.role, i).games);
    return g >= lanecard.min_role_share * @as(f64, @floatFromInt(in.stats.champGames(i)));
}

fn available(in: lanecard.Input, id: u32) bool {
    if (std.mem.findScalar(u32, in.bans, id) != null) return false;
    for (in.allies) |p| if (p.champion == id) return false;
    for (in.enemies) |p| if (p.champion == id) return false;
    return true;
}

fn masteryOf(in: lanecard.Input, id: u32) u32 {
    for (in.mastery) |m| if (m.champion == id) return m.points;
    return 0;
}

/// docs/production-key.md "Product rules": facts, no win rate uplift, never "best"
fn policyWording(text: []const u8) !void {
    for ([_][]const u8{ "%", "win", "best", "Best" }) |bad| {
        if (std.mem.find(u8, text, bad) != null) {
            std.debug.print("policy wording: \"{s}\" in \"{s}\"\n", .{ bad, text });
            return error.PolicyWording;
        }
    }
}
