//! The lane card (docs/concept.md part 6): in champ select, the likely lane opponent's
//! matchup curve in one sentence, and several options from the player's pool with the
//! facts behind each. Facts only: no "+X% win" wording, never a single pick, never
//! other players' names or stats (docs/production-key.md). Pure; the desktop window
//! and `meiolol-app` build it from what they read off the League client.

const std = @import("std");
const core = @import("core");
const Role = core.Role;
const Stats = core.Stats;
const Pick = core.Pick;
const curvesfile = core.curvesfile;
const Curves = curvesfile.Curves;
const View = curvesfile.View;
const Bracket = curvesfile.Bracket;

/// As the site: fewer games, or mostly the champions' baseline, and a curve is thin
pub const thin_games = 200;
/// Minutes with fewer games still going are not drawn
const min_minute_games = 10;
/// Riot policy: 3 to 5 options, never one
pub const min_options = 3;
pub const max_options = 5;
/// Most-played champions (by mastery) that make up "your pool"
pub const pool_size = 15;
/// As the champions table's rare rows: under this share of a champion's games in the role
/// and it never fills up a pool (off-role players who win on it are a self-selected few)
pub const min_role_share = 0.1;
const max_reasons = 3;

pub const Mastery = struct { champion: u32, points: u32 };

/// The player's own experience on an option, from their mastery points: adds
/// beta[role] * feature(points) to the option's log-odds before the pool is ranked. Shown
/// only as the points fact, never as a win chance (docs/production-key.md)
pub const Expertise = struct {
    beta: [Role.count]f64,

    /// `meiolol eval --replay` of 20 Oct (snap-20261018T1007Z, 977k train seats): one beta
    /// for every role, fitted beside the player's total points, so it ranks within a
    /// pool (docs/model.md "Pool and expertise replay")
    pub const fitted: Expertise = .{ .beta = @splat(0.1022) };

    /// 0 for never played; one more per tenfold points past 1000
    pub fn feature(points: u32) f64 {
        return @log10(@as(f64, @floatFromInt(points)) + 1000) - 3;
    }

    pub fn logit(e: Expertise, role: Role, points: u32) f64 {
        return e.beta[@backingInt(role)] * feature(points);
    }
};

pub const Input = struct {
    stats: *const Stats,
    curves: ?*const Curves,
    role: Role,
    /// Hovered or locked, 0 when none
    me: u32 = 0,
    locked: bool = false,
    allies: []const Pick = &.{},
    enemies: []const Pick = &.{},
    bans: []const u32 = &.{},
    /// Pickable and owned; null when unknown (anything goes)
    pickable: ?[]const u32 = null,
    /// Most points first
    mastery: []const Mastery = &.{},
    /// Visible solo queue tier ("GOLD"), never MMR
    tier: ?[]const u8 = null,
    /// Null ranks the pool by the draft alone (the window's toggle)
    expertise: ?Expertise = .fitted,
    opts: core.Options = .{},
};

pub const Opponent = struct {
    champion: u32,
    /// Enemy positions are hidden: inferred from the champions' role play rates
    guessed: bool,
};

pub const Point = struct {
    minute: u8,
    mean: i16,
    p25: i16,
    p75: i16,
};

pub const Matchup = struct {
    bracket: Bracket,
    games: u32,
    /// Estimated gold difference at lane_minute, me minus them
    gold: curvesfile.Estimate,
    /// 10th and 90th percentile of the games' gold difference then: 8 games in 10
    range: [2]i16,
    lane_games: u32,
    ahead: u32,
    thin: bool,
    /// Gold difference by minute while enough games are still going
    points: []const Point,
};

pub const Option = struct {
    champion: u32,
    mastery: u32,
    /// Gold against the lane opponent; null without an opponent or a curves file
    lane: ?LaneFact,
    /// Plain facts: mastery, team fit
    reasons: []const []const u8,
};

pub const LaneFact = struct {
    /// "vs Syndra: +120 gold at 14 min (1234 games)"
    text: []const u8,
    /// Who the estimate puts ahead, whatever the games
    lean: enum { ahead, behind, unclear },
    /// How strongly to show it: curvesfile.fade of the games
    strength: f32 = 1,
};

pub const Card = struct {
    role: Role,
    me: u32,
    locked: bool,
    opponent: ?Opponent,
    /// Me against the opponent; null until both are known or without a curve
    matchup: ?Matchup,
    /// One sentence on the matchup; "" when there is nothing to say yet
    sentence: []const u8,
    options: []const Option,
    /// "last 30 days" or "patch 16.20"; "" without a curves file
    period: []const u8,
};

/// Allocates in `arena`
pub fn build(arena: std.mem.Allocator, in: Input) !Card {
    const stats = in.stats;
    const opp = opponent(in);
    const bracket: Bracket = if (in.tier) |t|
        if (curvesfile.tierRank(t)) |r| Bracket.ofRank(r) else .all
    else
        .all;
    var card: Card = .{
        .role = in.role,
        .me = in.me,
        .locked = in.locked,
        .opponent = opp,
        .matchup = null,
        .sentence = "",
        .options = &.{},
        .period = if (in.curves) |c| try period(arena, c) else "",
    };

    if (opp) |o| if (in.me != 0) {
        const me_name = stats.nameOf(in.me);
        const them = stats.nameOf(o.champion);
        if (in.curves) |c| if (view(c, in.role, bracket, in.me, o.champion)) |v| {
            card.matchup = try matchup(arena, v.view, v.bracket);
        };
        card.sentence = if (card.matchup) |m|
            try sentence(arena, m, me_name, them, card.period)
        else if (in.curves != null)
            try std.fmt.allocPrint(arena, "No {s} games of {s} against {s} in the {s}.", .{
                in.role.label(), me_name, them, card.period,
            })
        else
            "";
    };

    card.options = try options(arena, in, opp, bracket);
    return card;
}

/// The card as text in reading order: scenario tests and `meiolol-app cards`
pub fn write(card: Card, stats: *const Stats, w: *std.Io.Writer) !void {
    try w.writeAll(card.role.label());
    if (card.me != 0) try w.print(", {s} {s}", .{ if (card.locked) "locked" else "hovering", stats.nameOf(card.me) });
    if (card.opponent) |o| try w.print("; opponent {s}{s}", .{ stats.nameOf(o.champion), if (o.guessed) " (guessed)" else "" });
    try w.writeAll("\n");
    if (card.sentence.len > 0) try w.print("{s}\n", .{card.sentence});
    for (card.options) |o| {
        try w.print("- {s}", .{stats.nameOf(o.champion)});
        if (o.lane) |l| try w.print(" | {s}", .{l.text});
        for (o.reasons, 0..) |r, i| try w.print("{s}{s}", .{ if (i == 0) " | " else "; ", r });
        try w.writeAll("\n");
    }
}

/// An enemy shown in my position, else the one inferred into it
fn opponent(in: Input) ?Opponent {
    for (in.enemies) |e| if (e.role == in.role) return .{ .champion = e.champion, .guessed = false };
    const n = @min(in.enemies.len, 5);
    var roles: [5]?Role = @splat(null);
    core.score.inferRoles(in.stats, in.enemies[0..n], roles[0..n]);
    for (in.enemies[0..n], roles[0..n]) |e, r| {
        if (r == in.role) return .{ .champion = e.champion, .guessed = true };
    }
    return null;
}

const Found = struct { view: View, bracket: Bracket };

/// The player's bracket once it has thin_games games, else all ranks
fn view(c: *const Curves, role: Role, bracket: Bracket, me: u32, them: u32) ?Found {
    if (bracket != .all) if (c.get(role, bracket, me, them)) |v| {
        if (v.games() >= thin_games) return .{ .view = v, .bracket = bracket };
    };
    const v = c.get(role, .all, me, them) orelse return null;
    return .{ .view = v, .bracket = .all };
}

fn matchup(arena: std.mem.Allocator, v: View, bracket: Bracket) !Matchup {
    const floor = @max(1, @min(min_minute_games, v.games()));
    var points: std.ArrayList(Point) = .empty;
    for (0..v.minutes()) |i| {
        const m = v.minute(i);
        if (m.n < floor) break;
        try points.append(arena, .{
            .minute = @intCast(i + 1),
            .mean = m.est[@backingInt(curvesfile.Metric.gold)].mean,
            .p25 = m.gold.p25,
            .p75 = m.gold.p75,
        });
    }
    const lane = v.lane();
    const at = v.minute(curvesfile.lane_minute - 1).gold;
    return .{
        .bracket = bracket,
        .games = v.games(),
        .gold = v.estimate(.gold, curvesfile.lane_minute - 1),
        .range = .{ at.p10, at.p90 },
        .lane_games = lane.games,
        .ahead = lane.ahead,
        .thin = v.games() < thin_games or v.own() < 0.5,
        .points = points.items,
    };
}

/// "At 14 min Ahri is typically 250 gold behind Syndra (8 games in 10 between -1400 and
/// +900) and ahead in 44% of 1234 games (Gold to Emerald, last 30 days)."
fn sentence(arena: std.mem.Allocator, m: Matchup, me: []const u8, them: []const u8, when: []const u8) ![]const u8 {
    var aw: std.Io.Writer.Allocating = .init(arena);
    const w = &aw.writer;
    try w.print("At {d} min {s} is typically ", .{ curvesfile.lane_minute, me });
    try gold(w, m.gold.mean);
    try w.print(" {s}", .{them});
    if (m.thin) {
        try w.print(", mostly from how both champions do against everyone: {d} game{s}", .{
            m.games, if (m.games == 1) "" else "s",
        });
    } else if (m.lane_games > 0) {
        try w.print(" (8 games in 10 between {s}{d} and {s}{d})", .{
            if (m.range[0] > 0) "+" else "", m.range[0], if (m.range[1] > 0) "+" else "", m.range[1],
        });
        try w.print(" and ahead in {d}% of {d} games", .{ percent(m.ahead, m.lane_games), m.games });
    }
    try w.print(" ({s}, {s}).", .{ m.bracket.label(), when });
    return aw.written();
}

/// "250 gold behind", "120 gold ahead of", "even in gold with"
fn gold(w: *std.Io.Writer, mean: i16) !void {
    if (mean == 0) return w.writeAll("even in gold with");
    try w.print("{d} gold {s}", .{ @abs(mean), if (mean > 0) "ahead of" else "behind" });
}

fn percent(part: u32, whole: u32) u32 {
    if (whole == 0) return 0;
    return @intFromFloat(@round(100 * @as(f64, @floatFromInt(part)) / @as(f64, @floatFromInt(whole))));
}

fn period(arena: std.mem.Allocator, c: *const Curves) ![]const u8 {
    const label = c.patch();
    if (label.len > 0 and std.ascii.isDigit(label[0])) return std.fmt.allocPrint(arena, "patch {s}", .{label});
    return label;
}

/// "From your pool": the most-played champions that are pickable and played in the
/// role, ranked by the recommender; filled up from every pickable champion when the
/// pool has fewer than min_options
fn options(arena: std.mem.Allocator, in: Input, opp: ?Opponent, bracket: Bracket) ![]const Option {
    const stats = in.stats;
    var pool: std.ArrayList(u32) = .empty;
    for (in.mastery) |m| {
        if (pool.items.len == pool_size) break;
        if (m.points == 0) break;
        const c = stats.index(m.champion) orelse continue;
        if (stats.champRole(in.role, c).games < in.opts.min_games) continue;
        if (in.pickable) |p| if (std.mem.indexOfScalar(u32, p, m.champion) == null) continue;
        try pool.append(arena, m.champion);
    }
    const draft: core.Draft = .{
        .role = in.role,
        .allies = in.allies,
        .enemies = in.enemies,
        .bans = in.bans,
        .pool = pool.items,
    };
    var buf: [pool_size]core.Suggestion = undefined;
    var list = core.recommend(stats, draft, in.opts, &buf);
    if (in.expertise) |e| {
        const Rank = struct { e: Expertise, in: Input };
        std.mem.sort(core.Suggestion, list, Rank{ .e = e, .in = in }, struct {
            fn more(r: Rank, a: core.Suggestion, b: core.Suggestion) bool {
                return rankLogit(r.e, r.in, a) > rankLogit(r.e, r.in, b);
            }
        }.more);
    }
    list = list[0..@min(list.len, max_options)];
    if (list.len < min_options) {
        // Keep the pool's options, then fill from everyone who plays the role
        var wide = draft;
        wide.pool = try rolePlayers(arena, stats, in.role, in.pickable);
        var more: [2 * max_options]core.Suggestion = undefined;
        var len = list.len;
        for (core.recommend(stats, wide, in.opts, &more)) |s| {
            if (len == max_options) break;
            for (list) |p| {
                if (p.champion == s.champion) break;
            } else {
                buf[len] = s;
                len += 1;
            }
        }
        list = buf[0..len];
    }

    // Strong in the role only says something when it sets an option apart
    var strong: usize = 0;
    for (list) |s| strong += @intFromBool(isStrong(s));
    const show_strong = 2 * strong < list.len;

    const out = try arena.alloc(Option, list.len);
    for (list, out) |s, *o| {
        o.* = .{
            .champion = s.champion,
            .mastery = masteryOf(in.mastery, s.champion),
            .lane = if (opp) |p| try laneFact(arena, in, s.champion, p.champion, bracket) else null,
            .reasons = try reasons(arena, in, s, opp, show_strong),
        };
    }
    return out;
}

/// Of `pickable` (every champion when null), those with min_role_share of their games
/// in `role`
fn rolePlayers(arena: std.mem.Allocator, stats: *const Stats, role: Role, pickable: ?[]const u32) ![]const u32 {
    var out: std.ArrayList(u32) = .empty;
    for (0..stats.n) |c| {
        const id = stats.ids[c];
        if (pickable) |p| if (std.mem.indexOfScalar(u32, p, id) == null) continue;
        const g: f64 = @floatFromInt(stats.champRole(role, c).games);
        if (g < min_role_share * @as(f64, @floatFromInt(stats.champGames(c)))) continue;
        try out.append(arena, id);
    }
    return out.items;
}

fn isStrong(s: core.Suggestion) bool {
    for (s.reasons()) |r| if (r.kind == .base and r.pp > 0) return true;
    return false;
}

fn rankLogit(e: Expertise, in: Input, s: core.Suggestion) f64 {
    return @log(s.win / (1 - s.win)) + e.logit(in.role, masteryOf(in.mastery, s.champion));
}

fn masteryOf(mastery: []const Mastery, champion: u32) u32 {
    for (mastery) |m| if (m.champion == champion) return m.points;
    return 0;
}

fn laneFact(arena: std.mem.Allocator, in: Input, me: u32, them: u32, bracket: Bracket) !?LaneFact {
    const c = in.curves orelse return null;
    const name = in.stats.nameOf(them);
    const f = view(c, in.role, bracket, me, them) orelse return .{
        .text = try std.fmt.allocPrint(arena, "vs {s}: no lane games yet", .{name}),
        .lean = .unclear,
    };
    const e = f.view.estimate(.gold, curvesfile.lane_minute - 1);
    const thin = f.view.games() < thin_games or f.view.own() < 0.5;
    return .{
        .text = try std.fmt.allocPrint(arena, "vs {s}: {s}{d} gold at {d} min ({d} games{s})", .{
            name,
            if (e.mean > 0) "+" else "",
            e.mean,
            curvesfile.lane_minute,
            f.view.games(),
            if (thin) ", mostly baseline" else "",
        }),
        .lean = if (e.mean > 0) .ahead else if (e.mean < 0) .behind else .unclear,
        .strength = @floatCast(curvesfile.fade(f.view.games())),
    };
}

fn reasons(arena: std.mem.Allocator, in: Input, s: core.Suggestion, opp: ?Opponent, show_strong: bool) ![]const []const u8 {
    const stats = in.stats;
    var out: std.ArrayList([]const u8) = .empty;
    const points = masteryOf(in.mastery, s.champion);
    if (points > 0) {
        var aw: std.Io.Writer.Allocating = .init(arena);
        try compact(&aw.writer, points);
        try aw.writer.writeAll(" mastery points");
        try out.append(arena, aw.written());
    }
    for (s.reasons()) |r| {
        if (out.items.len == max_reasons) break;
        // The lane opponent is covered by its curve above
        if (opp != null and r.kind == .enemy and r.champion == opp.?.champion) continue;
        const name = stats.nameOf(r.champion);
        const text = switch (r.kind) {
            .base => if (r.pp > 0 and show_strong) try std.fmt.allocPrint(arena, "strong in {s}{f}", .{ in.role.label(), core.score.When{ .label = stats.patch } }) else continue,
            .ally => if (r.pp > 0) try std.fmt.allocPrint(arena, "pairs well with {s}", .{name}) else continue,
            .enemy => try std.fmt.allocPrint(arena, "{s} into {s}", .{ if (r.pp > 0) "good" else "hard", name }),
        };
        try out.append(arena, text);
    }
    return out.items;
}

/// 950, 12k, 1.2M
fn compact(w: *std.Io.Writer, n: u32) !void {
    if (n < 1000) return w.print("{d}", .{n});
    if (n < 1_000_000) return w.print("{d}k", .{n / 1000});
    return w.print("{d}.{d}M", .{ n / 1_000_000, n / 100_000 % 10 });
}

const testing = std.testing;
const statsfile = core.statsfile;

const garen = 86;
const darius = 122;
const sett = 875;
const ahri = 103;
const lux = 99;
const test_champions = [_]statsfile.Champion{
    .{ .id = garen, .name = "Garen" },
    .{ .id = darius, .name = "Darius" },
    .{ .id = sett, .name = "Sett" },
    .{ .id = ahri, .name = "Ahri" },
    .{ .id = lux, .name = "Lux" },
};

const Fixture = struct {
    stats_bytes: []u8,
    stats: Stats,
    curves_bytes: []u8,
    curves: Curves,

    fn deinit(f: *Fixture) void {
        f.stats.deinit(testing.allocator);
        testing.allocator.free(f.stats_bytes);
        f.curves.deinit(testing.allocator);
        testing.allocator.free(f.curves_bytes);
    }
};

/// Garen, Darius and Sett play top, Ahri mid, Lux support (and top in a few won
/// games). Darius leads Garen by about 300 gold at 14 in 300 games; Sett vs Garen has 20
/// games
fn fixture() !Fixture {
    const gpa = testing.allocator;
    var sb: statsfile.Builder = try .init(gpa, &test_champions);
    defer sb.deinit();
    for (0..900) |i| {
        const tops = [_]u32{ garen, darius, sett };
        const a = tops[i % 3];
        const b = tops[(i + 1) % 3];
        sb.addGame(.{ .{ a, 0, ahri, 0, lux }, .{ b, 0, 0, 0, 0 } }, @intCast(i % 2));
    }
    // Lux top: a few games, all won, under min_role_share of hers
    for (0..60) |_| sb.addGame(.{ .{ lux, 0, 0, 0, 0 }, .{ garen, 0, 0, 0, 0 } }, 0);
    var aw: std.Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();
    try sb.write(&aw.writer, "test");
    const bytes = try aw.toOwnedSlice();
    errdefer gpa.free(bytes);
    var stats: Stats = try .parse(gpa, bytes);
    errdefer stats.deinit(gpa);

    var cb: curvesfile.Builder = .{ .gpa = gpa };
    defer cb.deinit();
    for (0..320) |i| {
        const vs_sett = i >= 300;
        const g: i16 = if (vs_sett) -100 else if (i % 4 == 0) -200 else 500;
        var l: curvesfile.Lane = .{
            .role = .top,
            .bracket = .mid,
            .a = if (vs_sett) sett else darius,
            .b = garen,
            .a_won = i % 2 == 0,
            .minutes = 20,
        };
        for (0..20) |m| l.gold[m] = @intCast(@divTrunc(@as(i32, g) * @as(i32, @intCast(m + 1)), curvesfile.lane_minute));
        try cb.addLane(l);
        cb.addGame();
    }
    var cw: std.Io.Writer.Allocating = .init(gpa);
    defer cw.deinit();
    try cb.write(&cw.writer, "last 30 days", 1);
    const curves_bytes = try cw.toOwnedSlice();
    errdefer gpa.free(curves_bytes);
    return .{ .stats_bytes = bytes, .stats = stats, .curves_bytes = curves_bytes, .curves = try .parse(gpa, curves_bytes) };
}

const test_opts: core.Options = .{ .min_games = 50, .base_prior_games = 50, .prior_games = 20 };

test "known opponent: sentence and curve" {
    var f = try fixture();
    defer f.deinit();
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const card = try build(arena.allocator(), .{
        .stats = &f.stats,
        .curves = &f.curves,
        .role = .top,
        .me = darius,
        .enemies = &.{.{ .champion = garen, .role = .top }},
        .tier = "GOLD",
        .opts = test_opts,
    });
    try testing.expectEqual(garen, card.opponent.?.champion);
    try testing.expect(!card.opponent.?.guessed);
    const m = card.matchup.?;
    try testing.expectEqual(Bracket.mid, m.bracket);
    try testing.expectEqual(300, m.games);
    try testing.expectEqual(20, m.points.len);
    try testing.expect(m.gold.mean > 0);
    try testing.expectEqual(225, m.ahead);
    try testing.expect(m.range[0] < m.gold.mean and m.gold.mean < m.range[1]);
    try testing.expectEqualStrings("last 30 days", card.period);
    try testing.expect(std.mem.startsWith(u8, card.sentence, "At 14 min Darius is typically "));
    try testing.expect(std.mem.indexOf(u8, card.sentence, " gold ahead of Garen (8 games in 10 between ") != null);
    try testing.expect(std.mem.endsWith(u8, card.sentence, "% of 300 games (Gold to Emerald, last 30 days)."));
}

test "guessed opponent, thin curve, options with reasons" {
    var f = try fixture();
    defer f.deinit();
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const card = try build(arena.allocator(), .{
        .stats = &f.stats,
        .curves = &f.curves,
        .role = .top,
        .me = sett,
        // Garen's position is hidden; Ahri's is mid
        .enemies = &.{ .{ .champion = ahri }, .{ .champion = garen } },
        .mastery = &.{ .{ .champion = darius, .points = 91_000 }, .{ .champion = ahri, .points = 5000 } },
        .opts = test_opts,
    });
    try testing.expectEqual(garen, card.opponent.?.champion);
    try testing.expect(card.opponent.?.guessed);
    try testing.expect(card.matchup.?.thin);
    try testing.expect(std.mem.indexOf(u8, card.sentence, "mostly from how both champions do against everyone: 20 games") != null);
    // Darius alone is in the pool for top: widened to everyone who plays it, Garen taken;
    // not Lux, whose few top games are all wins
    try testing.expectEqual(2, card.options.len);
    for (card.options) |o| try testing.expect(o.champion == darius or o.champion == sett);
    const d = for (card.options) |o| {
        if (o.champion == darius) break o;
    } else unreachable;
    try testing.expectEqual(91_000, d.mastery);
    try testing.expect(std.mem.startsWith(u8, d.lane.?.text, "vs Garen: +"));
    try testing.expectEqual(.ahead, d.lane.?.lean);
    try testing.expectEqualStrings("91k mastery points", d.reasons[0]);
    const sett_vs = for (card.options) |o| {
        if (o.champion == sett) break o.lane.?;
    } else unreachable;
    // 20 games: a lean, shown faint
    try testing.expect(sett_vs.lean != .unclear);
    try testing.expect(sett_vs.strength < 0.8);
    try testing.expectEqual(1, d.lane.?.strength);
}

test "before picks: no opponent, no sentence" {
    var f = try fixture();
    defer f.deinit();
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const card = try build(arena.allocator(), .{
        .stats = &f.stats,
        .curves = null,
        .role = .middle,
        .opts = test_opts,
    });
    try testing.expectEqual(null, card.opponent);
    try testing.expectEqualStrings("", card.sentence);
    try testing.expectEqualStrings("", card.period);
    try testing.expectEqual(1, card.options.len);
    try testing.expectEqual(ahri, card.options[0].champion);
}

test "expertise ranks the pool by points too" {
    var f = try fixture();
    defer f.deinit();
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var in: Input = .{
        .stats = &f.stats,
        .curves = null,
        .role = .top,
        .mastery = &.{
            .{ .champion = sett, .points = 400_000 },
            .{ .champion = darius, .points = 20_000 },
            .{ .champion = garen, .points = 1000 },
        },
        .opts = test_opts,
        .expertise = null,
    };
    const draft_only = try build(arena.allocator(), in);
    try testing.expect(draft_only.options[0].champion != sett);
    in.expertise = .{ .beta = @splat(1) };
    const card = try build(arena.allocator(), in);
    try testing.expectEqual(3, card.options.len);
    try testing.expectEqual(sett, card.options[0].champion);
    try testing.expectEqual(garen, card.options[2].champion);
    try testing.expectEqual(0, Expertise.feature(0));
    try testing.expectApproxEqAbs(1, Expertise.feature(9000), 1e-12);
}

test compact {
    var buf: [16]u8 = undefined;
    for ([_]u32{ 950, 91_000, 1_250_000 }, [_][]const u8{ "950", "91k", "1.2M" }) |n, want| {
        var w: std.Io.Writer = .fixed(&buf);
        try compact(&w, n);
        try testing.expectEqualStrings(want, w.buffered());
    }
}

const FuzzFiles = struct { stats: []const u8, curves: []const u8 };

/// Damaged stats and curves files (what update.zig downloads) and any champions the
/// client may name: the card is built or refused, never a crash
fn fuzzCard(files: FuzzFiles, s: *testing.Smith) !void {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const stats = Stats.parse(arena, try core.fuzz.mutate(s, arena, files.stats)) catch return;
    var curves: ?Curves = Curves.parse(arena, try core.fuzz.mutate(s, arena, files.curves)) catch null;
    const ids = [_]u32{ 0, garen, darius, sett, ahri, lux, 1, std.math.maxInt(u32) };
    var picks: [10]Pick = undefined;
    for (&picks) |*p| p.* = .{
        .champion = ids[s.index(ids.len)],
        .role = if (s.value(bool)) s.value(Role) else null,
        .hover = s.value(bool),
    };
    const n_allies = s.valueRangeAtMost(u8, 0, 4);
    const card = build(arena, .{
        .stats = &stats,
        .curves = if (curves) |*c| c else null,
        .role = s.value(Role),
        .me = ids[s.index(ids.len)],
        .locked = s.value(bool),
        .allies = picks[0..n_allies],
        .enemies = picks[5 .. 5 + s.valueRangeAtMost(u8, 0, 5)],
        .bans = &.{ ids[s.index(ids.len)], ids[s.index(ids.len)] },
        .pickable = if (s.value(bool)) &.{ garen, darius, ids[s.index(ids.len)] } else null,
        .mastery = &.{.{ .champion = ids[s.index(ids.len)], .points = s.value(u32) }},
        .tier = ([_]?[]const u8{ null, "GOLD", "CHALLENGER", "NONE", "" })[s.index(5)],
        .expertise = if (s.value(bool)) .fitted else null,
        .opts = test_opts,
    }) catch return;
    var buf: [256]u8 = undefined;
    var w: std.Io.Writer.Discarding = .init(&buf);
    try write(card, &stats, &w.writer);
}

test "fuzz: damaged files and odd drafts never crash the card" {
    var f = try fixture();
    defer f.deinit();
    try testing.fuzz(FuzzFiles{ .stats = f.stats_bytes, .curves = f.curves_bytes }, fuzzCard, .{});
}
