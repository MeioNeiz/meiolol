//! The app's Options panel (docs/plan/ui/app-options.md): every champion played in the
//! lane card's role, ranked as the card ranks its pool, each with all its reasons (the
//! other champion and the points) and its win rate in the role. Pure, built beside the
//! lane card from the same Input; the shell picks what each edition shows. Nothing rates
//! a teammate's pick: none for an ally's lane once they lock

const std = @import("std");
const core = @import("core");
const lanecard = @import("lanecard.zig");
const Role = core.Role;

/// Rows built; the private edition shows them all
pub const max = 20;

pub const Pick = struct {
    champion: u32,
    /// The draft model's win chance for my team with it, 0..1 (private only)
    win: f64,
    /// Points it adds over an average champion
    pp: f64,
    /// The champion's games and wins in the role
    role: core.statsfile.Counts,
    mastery: u32,
    /// In the player's pool (lanecard.poolOf)
    pool: bool,
    /// Already one of the lane card's options
    shown: bool,
    /// Estimated gold at 14 min against the lane opponent, me minus them; null without
    /// one, a curves file or their games
    gold: ?f64,
    /// Strongest first: base (the role), ally pairs, enemy matchups
    reasons: []const core.score.Reason,
};

pub const Picks = struct {
    role: Role,
    picks: []const Pick,
};

/// Null for an ally's locked lane
pub fn build(arena: std.mem.Allocator, in: lanecard.Input, card: *const lanecard.Card) !?Picks {
    if (in.ally and in.locked) return null;
    const stats = in.stats;
    const pool = try lanecard.poolOf(arena, in);
    const players = try lanecard.rolePlayers(arena, stats, in.role, in.pickable);
    const draft: core.Draft = .{
        .role = in.role,
        .allies = in.allies,
        .enemies = in.enemies,
        .bans = in.bans,
        .pool = players,
    };
    const buf = try arena.alloc(core.Suggestion, players.len);
    const list = core.recommend(stats, draft, in.opts, buf);
    if (in.expertise) |e| {
        const Rank = struct { e: lanecard.Expertise, in: lanecard.Input };
        std.mem.sort(core.Suggestion, list, Rank{ .e = e, .in = in }, struct {
            fn more(r: Rank, a: core.Suggestion, b: core.Suggestion) bool {
                return lanecard.rankLogit(r.e, r.in, a) > lanecard.rankLogit(r.e, r.in, b);
            }
        }.more);
    }
    const bracket = lanecard.bracketOf(in.tier);
    const out = try arena.alloc(Pick, @min(list.len, max));
    for (out, list[0..out.len]) |*p, *s| {
        const c = stats.index(s.champion).?;
        p.* = .{
            .champion = s.champion,
            .win = s.win,
            .pp = s.pp,
            .role = stats.champRole(in.role, c),
            .mastery = lanecard.masteryOf(in.mastery, s.champion),
            .pool = std.mem.findScalar(u32, pool, s.champion) != null,
            .shown = for (card.options) |o| {
                if (o.champion == s.champion) break true;
            } else false,
            .gold = if (card.opponent) |o| gold(in, s.champion, o.champion, bracket) else null,
            .reasons = try arena.dupe(core.score.Reason, s.reasons()),
        };
    }
    return .{ .role = in.role, .picks = out };
}

fn gold(in: lanecard.Input, me: u32, them: u32, bracket: core.curvesfile.Bracket) ?f64 {
    const f = lanecard.view(in.curves orelse return null, in.role, bracket, me, them) orelse return null;
    return @floatFromInt(f.view.estimate(.gold, core.curvesfile.lane_minute - 1).mean);
}

const testing = std.testing;

test "every role player ranked, the card's options marked, none for an ally's lock" {
    var f = try lanecard.testFixture();
    defer f.deinit();
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const in: lanecard.Input = .{
        .stats = &f.stats,
        .curves = &f.curves,
        .role = .top,
        .enemies = &.{.{ .champion = lanecard.test_ids.garen, .role = .top }},
        .mastery = &.{.{ .champion = lanecard.test_ids.darius, .points = 50_000 }},
        .opts = .{ .min_games = 10 },
    };
    const card = try lanecard.build(arena, in);
    const got = (try build(arena, in, &card)).?;
    try testing.expect(got.picks.len >= 1);
    var darius = false;
    for (got.picks) |p| {
        try testing.expect(p.champion != lanecard.test_ids.garen);
        try testing.expect(p.role.games > 0);
        try testing.expect(p.gold != null);
        if (p.champion == lanecard.test_ids.darius) {
            darius = true;
            try testing.expect(p.pool and p.mastery == 50_000);
        }
    }
    try testing.expect(darius);
    for (got.picks) |p| try testing.expectEqual(for (card.options) |o| {
        if (o.champion == p.champion) break true;
    } else false, p.shown);

    var ally = in;
    ally.ally = true;
    ally.locked = true;
    ally.me = lanecard.test_ids.sett;
    try testing.expectEqual(null, try build(arena, ally, &card));
}
