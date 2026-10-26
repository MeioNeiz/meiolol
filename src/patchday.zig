//! Patch day: how champions and lane matchups moved from the previous patch to the
//! current one. Win rates and lane shares are compared with a two-proportion z test;
//! median gold with a standard error from the middle-half spread. A move counts only
//! with enough games on both patches and |z| > 2.58: stricter than the site's 1.96 for
//! edges, as the patch page tests every champion and matchup at once. Facts with n,
//! never tier grades or verdicts.

const std = @import("std");
const core = @import("core");

const Role = core.Role;
const Stats = core.Stats;
const curvesfile = core.curvesfile;
const Curves = curvesfile.Curves;
const Counts = curvesfile.Counts;
const Allocator = std.mem.Allocator;

pub const Options = struct {
    /// Games per patch for a champion's role numbers (site: min_role_games)
    min_role_games: u32 = 300,
    /// Games per patch for a matchup, or a minute of one (site: min_pair_games)
    min_pair_games: u32 = 400,
    z: f64 = 2.58,
};

/// The same share on two patches
pub const Rate = struct {
    prev: Counts,
    cur: Counts,
    /// Two-proportion z, current minus previous; 0 when either side is empty
    z: f64,

    pub fn of(prev: Counts, cur: Counts) Rate {
        return .{ .prev = prev, .cur = cur, .z = twoProportionZ(prev, cur) };
    }

    pub fn share(c: Counts) f64 {
        return @as(f64, @floatFromInt(c.wins)) / @as(f64, @floatFromInt(@max(c.games, 1)));
    }

    /// Percentage points, current minus previous
    pub fn delta(r: Rate) f64 {
        return 100 * (share(r.cur) - share(r.prev));
    }

    /// delta's range, `z` standard errors either side (unpooled)
    pub fn range(r: Rate, z: f64) [2]f64 {
        const pp = share(r.prev);
        const pc = share(r.cur);
        const np: f64 = @floatFromInt(@max(r.prev.games, 1));
        const nc: f64 = @floatFromInt(@max(r.cur.games, 1));
        const se = 100 * @sqrt(pp * (1 - pp) / np + pc * (1 - pc) / nc);
        return .{ r.delta() - z * se, r.delta() + z * se };
    }

    pub fn enough(r: Rate, min_games: u32) bool {
        return r.prev.games >= min_games and r.cur.games >= min_games;
    }

    pub fn clear(r: Rate, min_games: u32, z: f64) bool {
        return r.enough(min_games) and @abs(r.z) > z;
    }
};

pub fn twoProportionZ(a: Counts, b: Counts) f64 {
    if (a.games == 0 or b.games == 0) return 0;
    const pa = Rate.share(a);
    const pb = Rate.share(b);
    const na: f64 = @floatFromInt(a.games);
    const nb: f64 = @floatFromInt(b.games);
    const pooled = (@as(f64, @floatFromInt(a.wins + b.wins))) / (na + nb);
    const se = @sqrt(pooled * (1 - pooled) * (1 / na + 1 / nb));
    return if (se == 0) 0 else (pb - pa) / se;
}

/// Standard error of a median from the interquartile range, assuming a roughly normal
/// spread: sd = IQR / 1.349, se = 1.2533 sd / sqrt(n)
pub fn medianSe(q: curvesfile.Spread, n: u32) f64 {
    const iqr: f64 = @floatFromInt(@as(i32, q.p75) - q.p25);
    return 1.2533 * (iqr / 1.349) / @sqrt(@as(f64, @floatFromInt(@max(n, 1))));
}

pub const ChampionMove = struct {
    id: u32,
    role: Role,
    win: Rate,
    /// Games ahead in lane gold at curvesfile.lane_minute, over all its matchups
    ahead: ?Rate = null,
    /// Games won from 500 to 1,500 gold behind at 10 minutes
    comeback: ?Rate = null,
};

/// The minute a matchup's median gold difference moved most, among clear moves
pub const GoldMove = struct {
    /// 1-based minute
    minute: u8,
    prev: i16,
    cur: i16,
    prev_n: u32,
    cur_n: u32,
    z: f64,
};

/// From the lower champion id's side, like the curves file
pub const MatchupMove = struct {
    role: Role,
    a: u32,
    b: u32,
    win: Rate,
    gold: ?GoldMove = null,
};

pub const PatchDay = struct {
    prev_patch: []const u8 = "",
    cur_patch: []const u8 = "",
    prev_games: u32 = 0,
    cur_games: u32 = 0,
    opts: Options = .{},
    /// Every champion-role played enough on both patches
    champions: []const ChampionMove = &.{},
    /// Every matchup with curves on both patches
    matchups: []const MatchupMove = &.{},
    /// Wins.thin
    thin: []const ChampionMove = &.{},

    pub fn champion(p: *const PatchDay, id: u32, r: Role) ?ChampionMove {
        for (p.champions) |c| if (c.id == id and c.role == r) return c;
        return null;
    }

    /// From `me`'s side
    pub fn matchup(p: *const PatchDay, r: Role, me: u32, them: u32) ?MatchupMove {
        const a = @min(me, them);
        const b = @max(me, them);
        for (p.matchups) |m| {
            if (m.role != r or m.a != a or m.b != b) continue;
            return if (me == a) m else flip(m);
        }
        return null;
    }
};

fn flip(m: MatchupMove) MatchupMove {
    var out = m;
    out.a = m.b;
    out.b = m.a;
    out.win = flipRate(m.win);
    if (m.gold) |g| out.gold = .{
        .minute = g.minute,
        .prev = -g.prev,
        .cur = -g.cur,
        .prev_n = g.prev_n,
        .cur_n = g.cur_n,
        .z = -g.z,
    };
    return out;
}

fn flipRate(r: Rate) Rate {
    return .{
        .prev = .{ .games = r.prev.games, .wins = r.prev.games - r.prev.wins },
        .cur = .{ .games = r.cur.games, .wins = r.cur.games - r.cur.wins },
        .z = -r.z,
    };
}

pub fn build(
    arena: Allocator,
    prev: *const Stats,
    cur: *const Stats,
    prev_curves: ?*const Curves,
    cur_curves: ?*const Curves,
    opts: Options,
) !PatchDay {
    return withCurves(arena, try championWins(arena, prev, cur, opts), prev_curves, cur_curves, opts);
}

/// The part made from stats, which the site keeps in its views file
pub const Wins = struct {
    prev_patch: []const u8 = "",
    cur_patch: []const u8 = "",
    prev_games: u32 = 0,
    cur_games: u32 = 0,
    /// Every champion-role played enough on both patches, win rates only
    champions: []const ChampionMove = &.{},
    /// Champions with no role in `champions`: each one's most played role on the current
    /// patch, whatever its games (a champion Riot changed, from the patch's first day)
    thin: []const ChampionMove = &.{},
};

pub fn championWins(arena: Allocator, prev: *const Stats, cur: *const Stats, opts: Options) !Wins {
    var champions: std.ArrayList(ChampionMove) = .empty;
    var thin: std.ArrayList(ChampionMove) = .empty;
    for (cur.ids, 0..) |id, c| {
        const pc = prev.index(id);
        const had = champions.items.len;
        var main: ?Role = null;
        for (Role.all) |r| {
            const now = cur.champRole(r, c);
            if (now.games > 0 and (main == null or now.games > cur.champRole(main.?, c).games)) main = r;
            const p = pc orelse continue;
            const win = Rate.of(counts(prev.champRole(r, p)), counts(now));
            if (!win.enough(opts.min_role_games)) continue;
            try champions.append(arena, .{ .id = id, .role = r, .win = win });
        }
        if (champions.items.len > had) continue;
        const r = main orelse continue;
        const before: Counts = if (pc) |p| counts(prev.champRole(r, p)) else .{};
        try thin.append(arena, .{ .id = id, .role = r, .win = .of(before, counts(cur.champRole(r, c))) });
    }
    return .{
        .prev_patch = prev.patch,
        .cur_patch = cur.patch,
        .prev_games = prev.games,
        .cur_games = cur.games,
        .champions = champions.items,
        .thin = thin.items,
    };
}

/// championWins' moves with their lane numbers, and the matchups, from both patches'
/// curves where there are both
pub fn withCurves(
    arena: Allocator,
    wins: Wins,
    prev_curves: ?*const Curves,
    cur_curves: ?*const Curves,
    opts: Options,
) !PatchDay {
    const champions = try arena.dupe(ChampionMove, wins.champions);
    var matchups: std.ArrayList(MatchupMove) = .empty;
    if (prev_curves) |pc| if (cur_curves) |cc| {
        for (champions) |*move| {
            const lp = laneTotals(pc, move.id, move.role);
            const lc = laneTotals(cc, move.id, move.role);
            move.ahead = Rate.of(lp.ahead, lc.ahead);
            move.comeback = Rate.of(lp.comeback, lc.comeback);
        }
        for (cc.curves) |*cv| {
            const h = cv.header;
            if (h.bracket != @backingInt(curvesfile.Bracket.all)) continue;
            if (h.experience != @backingInt(curvesfile.Experience.any) or h.a == 0) continue;
            const r: Role = @fromBackingInt(@intCast(h.role));
            const pv = pc.get(r, .all, h.a, h.b) orelse continue;
            const cview: curvesfile.View = .{ .curve = cv, .flipped = false };
            try matchups.append(arena, .{
                .role = r,
                .a = h.a,
                .b = h.b,
                .win = Rate.of(.{ .games = pv.games(), .wins = pv.wins() }, .{ .games = cview.games(), .wins = cview.wins() }),
                .gold = goldMove(pv, cview, opts),
            });
        }
    };
    return .{
        .prev_patch = wins.prev_patch,
        .cur_patch = wins.cur_patch,
        .prev_games = wins.prev_games,
        .cur_games = wins.cur_games,
        .opts = opts,
        .champions = champions,
        .matchups = matchups.items,
        .thin = wins.thin,
    };
}

fn counts(c: core.statsfile.Counts) Counts {
    return .{ .games = c.games, .wins = c.wins };
}

const LaneTotals = struct { ahead: Counts = .{}, comeback: Counts = .{} };

/// `id` in `r` over all its lane matchups (all ranks, all players): games that reached
/// the lane minute and how many it led, and games 500 to 1,500 behind at 10 and won
fn laneTotals(c: *const Curves, id: u32, r: Role) LaneTotals {
    var t: LaneTotals = .{};
    for (c.curves) |*cv| {
        const h = cv.header;
        if (h.role != @backingInt(r) or h.bracket != @backingInt(curvesfile.Bracket.all)) continue;
        if (h.experience != @backingInt(curvesfile.Experience.any)) continue;
        if (h.a != id and h.b != id) continue;
        const v: curvesfile.View = .{ .curve = cv, .flipped = h.a != id };
        const l = v.lane();
        t.ahead.games += l.games;
        t.ahead.wins += l.ahead;
        const cb = v.comeback(.ten, 1);
        t.comeback.games += cb.games;
        t.comeback.wins += cb.wins;
    }
    return t;
}

fn goldMove(prev: curvesfile.View, cur: curvesfile.View, opts: Options) ?GoldMove {
    var best: ?GoldMove = null;
    for (0..curvesfile.max_minutes) |i| {
        const p = prev.minute(i);
        const c = cur.minute(i);
        if (p.n < opts.min_pair_games or c.n < opts.min_pair_games) continue;
        const se = @sqrt(std.math.pow(f64, medianSe(p.gold, p.n), 2) + std.math.pow(f64, medianSe(c.gold, c.n), 2));
        if (se == 0) continue;
        const d: f64 = @floatFromInt(@as(i32, c.gold.p50) - p.gold.p50);
        const z = d / se;
        if (@abs(z) <= opts.z) continue;
        const move: GoldMove = .{
            .minute = @intCast(i + 1),
            .prev = p.gold.p50,
            .cur = c.gold.p50,
            .prev_n = p.n,
            .cur_n = c.n,
            .z = z,
        };
        if (best == null or @abs(d) > @abs(@as(f64, @floatFromInt(@as(i32, best.?.cur) - best.?.prev)))) best = move;
    }
    return best;
}

const testing = std.testing;

test "two-proportion z" {
    // 50% of 1000 vs 55% of 1000: z about 2.24
    const z = twoProportionZ(.{ .games = 1000, .wins = 500 }, .{ .games = 1000, .wins = 550 });
    try testing.expectApproxEqAbs(2.24, z, 0.01);
    try testing.expectEqual(0, twoProportionZ(.{}, .{ .games = 5, .wins = 1 }));
    const r = Rate.of(.{ .games = 1000, .wins = 500 }, .{ .games = 1000, .wins = 550 });
    try testing.expect(r.clear(300, 1.96));
    try testing.expect(!r.clear(2000, 1.96));
    try testing.expectApproxEqAbs(5, r.delta(), 1e-9);
    try testing.expectApproxEqAbs(-5, flipRate(r).delta(), 1e-9);
}

test "median standard error" {
    // IQR 1349 is sd 1000; n 100: se = 1.2533 * 1000 / 10
    try testing.expectApproxEqAbs(125.33, medianSe(.{ .p25 = -674, .p50 = 0, .p75 = 675 }, 100), 0.01);
}

/// Two patches of top lanes, champion 1 against 2: `wins` of `games` for 1, and 1's
/// gold lead `gold` at 7 minutes (spread +-200 around it)
fn testPatch(arena: Allocator, patch: []const u8, games: u32, wins: u32, gold: i16) !struct { Stats, Curves } {
    var champs: std.ArrayList(core.statsfile.Champion) = .empty;
    for ([_]u32{ 1, 2, 100, 101, 102, 103, 104, 105, 106, 107 }) |id| {
        try champs.append(arena, .{ .id = id, .name = "x" });
    }
    var sb: core.statsfile.Builder = try .init(arena, champs.items);
    var cb: curvesfile.Builder = .{ .gpa = arena };
    for (0..games) |i| {
        const won = i < wins;
        sb.addGame(.{ .{ 1, 100, 101, 102, 103 }, .{ 2, 104, 105, 106, 107 } }, if (won) 0 else 1);
        var l: curvesfile.Lane = .{ .role = .top, .bracket = .mid, .a = 1, .b = 2, .a_won = won, .minutes = 20 };
        const spread: i16 = @intCast(@as(i32, @intCast(i % 5)) * 100 - 200);
        l.gold[6] = gold + spread;
        l.gold[13] = if (won) 1 else -1;
        try cb.addLane(l);
        cb.addGame();
    }
    var sw: std.Io.Writer.Allocating = .init(arena);
    try sb.write(&sw.writer, patch);
    var cw: std.Io.Writer.Allocating = .init(arena);
    try cb.write(&cw.writer, patch, 1);
    return .{ try Stats.parse(arena, sw.written()), try Curves.parse(arena, cw.written()) };
}

test "champion and matchup moves between patches" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const prev = try testPatch(arena, "16.20", 1000, 500, 150);
    const cur = try testPatch(arena, "16.21", 1000, 560, 320);
    const p = try build(arena, &prev[0], &cur[0], &prev[1], &cur[1], .{});
    try testing.expectEqualStrings("16.20", p.prev_patch);

    const top = p.champion(1, .top).?;
    try testing.expect(top.win.clear(300, p.opts.z));
    try testing.expectApproxEqAbs(6, top.win.delta(), 1e-9);
    try testing.expect(top.ahead.?.clear(300, p.opts.z)); // led at 14 in won games only
    try testing.expectEqual(null, p.champion(1, .jungle));
    try testing.expectEqual(0, p.thin.len);

    // A patch's first games: no role has enough, each champion's main one is thin
    const early = try testPatch(arena, "16.21", 200, 120, 320);
    const e = try championWins(arena, &prev[0], &early[0], .{});
    try testing.expectEqual(0, e.champions.len);
    try testing.expectEqual(10, e.thin.len);
    for (e.thin) |t| if (t.id == 1) {
        try testing.expectEqual(.top, t.role);
        try testing.expectEqual(1000, t.win.prev.games);
        try testing.expectEqual(200, t.win.cur.games);
    };

    const m = p.matchup(.top, 1, 2).?;
    try testing.expectEqual(7, m.gold.?.minute);
    try testing.expectEqual(150, m.gold.?.prev);
    try testing.expectEqual(320, m.gold.?.cur);
    const back = p.matchup(.top, 2, 1).?;
    try testing.expectEqual(-320, back.gold.?.cur);
    try testing.expectApproxEqAbs(-6, back.win.delta(), 1e-9);
}
