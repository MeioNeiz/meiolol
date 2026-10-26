//! Learn's ui.learndata.Data for learn.html: the hand-written chapters (learnfixed.zig)
//! and the ones made from this patch's games. A chapter with no puzzle that clears its
//! bar (3+ points or 200+ gold, hundreds of games: J11) is left out
const std = @import("std");
const ld = @import("ui").learndata;
const fixed = @import("learnfixed.zig");
const root = @import("root.zig");
const html = @import("html.zig");
const matchup = @import("matchup.zig");
const champion = @import("champion.zig");
const lean = @import("../lean.zig");

const core = @import("core");
const curvesfile = core.curvesfile;

const Site = root.Site;
const Role = core.Role;
const Champ = root.Champ;

/// A champion counts as a role's own at this share of its games (Jacob v6: 90%, so Lee
/// Sin at 92.7% stays)
const role_share = 0.9;

pub fn data(site: *const Site) !ld.Data {
    const a = site.arena;
    var chapters: std.ArrayList(ld.Chapter) = .empty;
    const all = [_]ld.Chapter{
        .{ .title = "The basics", .puzzles = try starter(site) },
        .{ .title = "Does knowing your champion matter?", .puzzles = &fixed.chapter1 },
        .{ .title = "Whose lead wins games?", .puzzles = &fixed.chapter2 },
        .{ .title = "Does winning lane win the game?", .puzzles = try lane(site) },
        .{ .title = "Counter, or just strong?", .puzzles = try counters(site) },
        .{ .title = "Myth or measured", .puzzles = &fixed.chapter5 },
    };
    var start: u8 = 0;
    for (all, 0..) |c, i| {
        if (c.puzzles.len == 0) continue;
        // A first visit lands on chapter 1 (notes/learn.md Decisions)
        if (i == 1) start = @intCast(chapters.items.len);
        try chapters.append(a, c);
    }
    return .{ .ddragon = site.ddragon_version, .chapters = chapters.items, .start = start };
}

/// Chapter 0 (plan "Chapter 0"): tiles of clear examples, the question on another
fn starter(site: *const Site) ![]const ld.Puzzle {
    var out: std.ArrayList(ld.Puzzle) = .empty;
    const all = [_]?ld.Puzzle{ try roles(site), try counterBasic(site), try leanBasic(site), try damageBasic(site), try duoBasic(site) };
    for (all) |x| if (x) |p| try out.append(site.arena, p);
    return out.items;
}

fn uiRole(r: Role) ld.Role {
    return @fromBackingInt(@intCast(@backingInt(r)));
}

fn share(site: *const Site, c: usize) struct { Role, f64, u64 } {
    const st = &site.stats;
    var best: Role = .top;
    var total: u64 = 0;
    for (Role.all) |r| {
        const g = st.champRole(r, c).games;
        total += g;
        if (g > st.champRole(best, c).games) best = r;
    }
    const g = st.champRole(best, c).games;
    return .{ best, if (total == 0) 0 else @as(f64, @floatFromInt(g)) / @as(f64, @floatFromInt(total)), total };
}

/// Example tiles: each role's three most played champions that are 90%+ that role; the
/// question: the jungle's fourth, not on its tile
fn roles(site: *const Site) !?ld.Puzzle {
    const a = site.arena;
    const st = &site.stats;
    var tiles: [5]ld.Tile = undefined;
    var asked: ?root.Champ = null;
    for (Role.all, 0..) |r, ri| {
        var picks: [4]?root.Champ = @splat(null);
        for (site.champs) |c| {
            const main, const sh, _ = share(site, c.c);
            if (main != r or sh < role_share) continue;
            const g = st.champRole(r, c.c).games;
            for (&picks, 0..) |*slot, i| {
                if (slot.* == null or g > st.champRole(r, slot.*.?.c).games) {
                    var j: usize = picks.len - 1;
                    while (j > i) : (j -= 1) picks[j] = picks[j - 1];
                    slot.* = c;
                    break;
                }
            }
        }
        var cs: std.ArrayList(ld.Champ) = .empty;
        for (picks[0..3]) |x| if (x) |c| try cs.append(a, .{ .key = c.key, .name = c.name });
        if (cs.items.len == 0) return null;
        tiles[ri] = .{ .title = root.roleName(r), .role = uiRole(r), .champs = cs.items };
        if (r == .jungle) asked = picks[3];
    }
    const c = asked orelse return null;
    _, _, const total = share(site, c.c);
    var choices: [5]ld.Choice = undefined;
    for (Role.all, 0..) |r, ri| {
        const g = st.champRole(r, c.c).games;
        choices[ri] = .{
            .text = root.roleName(r),
            .role = uiRole(r),
            .shown = try a.print("{d:.1}%", .{100 * @as(f64, @floatFromInt(g)) / @as(f64, @floatFromInt(@max(total, 1)))}),
            .games = @intCast(g),
        };
    }
    return .{
        .id = try a.print("role-{s}", .{c.slug}),
        .q = try a.print("Which role is {s}?", .{c.name}),
        .setup = .{ .tiles = try a.dupe(ld.Tile, &tiles) },
        .answer = .{ .pick = .{ .right = @backingInt(Role.jungle), .choices = try a.dupe(ld.Choice, &choices) } },
        .why = try a.print("{s} is played in the jungle in 9 games of 10 or more.", .{c.name}),
        .tip = "Each champion has a usual role: start there.",
        .games = @intCast(total),
        .from = try a.print("{s}'s games by role, patch {s}", .{ c.name, site.patch }),
    };
}

fn uiChamp(c: Champ) ld.Champ {
    return .{ .key = c.key, .name = c.name };
}

/// The lane puzzle, the lean hook, then early or late per role
fn lane(site: *const Site) ![]const ld.Puzzle {
    var out: std.ArrayList(ld.Puzzle) = .empty;
    if (try lanePuzzle(site)) |p| try out.append(site.arena, p);
    try out.appendSlice(site.arena, try leanPuzzles(site));
    return out.items;
}

fn counters(site: *const Site) ![]const ld.Puzzle {
    var out: std.ArrayList(ld.Puzzle) = .empty;
    for ([_]Role{ .top, .middle, .bottom }) |r| {
        if (try counterPuzzle(site, r)) |c| try out.append(site.arena, c);
    }
    return out.items;
}

const lane_min_games = 300;
/// A matchup counts as one-sided in lane from this share of games led at 14
const lane_lead_share = 0.6;
/// The lane leader's win rate must sit this far below even, and 2 standard errors
const lane_min_gap = 0.05;

/// "Ahead in lane, so wins?": the matchup whose usual lane leader most clearly loses
/// the game, from the all-ranks lane curves
fn lanePuzzle(site: *const Site) !?ld.Puzzle {
    const curves = site.curves orelse return null;
    const Best = struct { lead: Champ, other: Champ, r: Role, led: f64, won: f64, games: u32 };
    var best: ?Best = null;
    for (curves.curves) |c| {
        const h = c.header;
        if (!matchup.isPage(h) or h.a == h.b or h.role >= Role.count) continue;
        if (h.games < lane_min_games or h.lane_games < h.games / 2) continue;
        const a_led = h.lane_a >= h.lane_b;
        const led_n: f64 = @floatFromInt(if (a_led) h.lane_a else h.lane_b);
        const led = led_n / @as(f64, @floatFromInt(h.lane_games));
        if (led < lane_lead_share) continue;
        const wins = if (a_led) h.a_wins else h.games - h.a_wins;
        const games: f64 = @floatFromInt(h.games);
        const won = @as(f64, @floatFromInt(wins)) / games;
        if (0.5 - won < lane_min_gap or 0.5 - won < 2 * @sqrt(won * (1 - won) / games)) continue;
        if (best) |b| if (led - won <= b.led - b.won) continue;
        const x = matchup.champ(site, h.a) orelse continue;
        const y = matchup.champ(site, h.b) orelse continue;
        best = .{
            .lead = if (a_led) x else y,
            .other = if (a_led) y else x,
            .r = @fromBackingInt(@intCast(h.role)),
            .led = led,
            .won = won,
            .games = h.games,
        };
    }
    const b = best orelse return null;
    const a = site.arena;
    const won_pct = @round(100 * b.won);
    // By name, so the answer is not always the same button
    const other_first = std.mem.lessThan(u8, b.other.name, b.lead.name);
    const lead: ld.Choice = .{ .text = b.lead.name, .champ = uiChamp(b.lead), .shown = try a.print("won {d:.0}%", .{won_pct}), .games = b.games };
    const other: ld.Choice = .{ .text = b.other.name, .champ = uiChamp(b.other), .shown = try a.print("won {d:.0}%", .{100 - won_pct}), .games = b.games };
    return .{
        .id = "lane",
        .q = "Who wins more of these games?",
        .ctx = try a.print("{s} against {s}, {s}", .{ b.lead.name, b.other.name, laneName(b.r) }),
        .setup = .{ .chips = .{
            .champs = try a.dupe(ld.Champ, &.{ uiChamp(b.lead), uiChamp(b.other) }),
            .chips = try a.dupe([]const u8, &.{try a.print("{s} ahead at 14: {d:.0}%", .{ b.lead.name, @round(100 * b.led) })}),
        } },
        .answer = .{ .pick = .{
            .right = if (other_first) 0 else 1,
            .choices = try a.dupe(ld.Choice, if (other_first) &.{ other, lead } else &.{ lead, other }),
        } },
        .why = try a.print("{s} wins the lane, {s} the game.", .{ b.lead.name, b.other.name }),
        .tip = "Losing lane is not losing the game: against an early champion, play for later.",
        .games = b.games,
        .from = try a.print("This patch's ranked games, all ranks, {s}", .{laneName(b.r)}),
    };
}

fn laneName(r: Role) []const u8 {
    return switch (r) {
        .top => "top lane",
        .jungle => "the jungle",
        .middle => "mid lane",
        .bottom => "bot lane",
        .utility => "bot lane as supports",
    };
}

/// A lean counts from this many win points from an even game at win_minute
const lean_min_points = 3;
/// and this much team gold at gold_minute, against the role's average pick
const lean_min_gold = 200;

fn leanClear(r: lean.Row) bool {
    return r.enough() and r.lean() != .none and @abs(r.win) >= lean_min_points and
        @abs(r.gold) >= lean_min_gold;
}

/// The hook first (the early champion furthest ahead at 14, yet losing long games, of
/// those played in hook_games or more), then per other role its most played champion
/// with a clear lean, clearest first
fn leanRows(a: std.mem.Allocator, rows: []const lean.Row, hook_games: u32) ![]const lean.Row {
    var hook: ?lean.Row = null;
    for (rows) |r| {
        if (!leanClear(r) or r.lean() != .early or r.games < hook_games) continue;
        if (hook == null or r.gold > hook.?.gold) hook = r;
    }
    const h = hook orelse return &.{};
    var per_role: [Role.count]?lean.Row = @splat(null);
    for (rows) |r| {
        if (!leanClear(r) or r.role == h.role) continue;
        const slot = &per_role[@backingInt(r.role)];
        if (slot.* == null or r.games > slot.*.?.games) slot.* = r;
    }
    var out: std.ArrayList(lean.Row) = .empty;
    try out.append(a, h);
    for (per_role) |r| if (r) |x| try out.append(a, x);
    const z = struct {
        fn more(_: void, x: lean.Row, y: lean.Row) bool {
            return @abs(x.win) / x.win_sd > @abs(y.win) / y.win_sd;
        }
    };
    std.mem.sort(lean.Row, out.items[1..], {}, z.more);
    return out.items;
}

/// "Early or late?": does winning lane win the game? From `meiolol lean`
fn leanPuzzles(site: *const Site) ![]const ld.Puzzle {
    const file = site.lean orelse return &.{};
    const a = site.arena;
    // An off-role pick with a few hundred games is no hook: 1 in 100 games, about 13k
    // over 30 days
    const rows = try leanRows(a, file.rows, file.games / 100);
    const from = try a.print("Ranked games, {s}, games still going at {d} minutes", .{ file.scope, lean.win_minute });
    var out: std.ArrayList(ld.Puzzle) = .empty;
    for (rows, 0..) |r, i| {
        const c = matchup.champ(site, r.champion) orelse continue;
        const gold: root.Thousands = .{ .n = @trunc(@round(@abs(r.gold) / 10) * 10) };
        const pts: i64 = @max(1, @as(i64, @trunc(@round(@abs(r.win)))));
        const early = r.lean() == .early;
        const champs = try a.dupe(ld.Champ, &.{uiChamp(c)});
        if (i == 0) {
            try out.append(a, .{
                .id = "lean-hook",
                .q = try a.print("Even at {d} minutes: does it win more or less?", .{lean.win_minute}),
                .ctx = try a.print("{s} {s}, against an average {s}", .{ c.name, inRole(r.role), roleNoun(r.role) }),
                .setup = .{ .chips = .{
                    .champs = champs,
                    .chips = try a.dupe([]const u8, &.{try a.print("+{f} gold at {d}", .{ gold, lean.gold_minute })}),
                } },
                .answer = .{ .pick = .{ .right = 1, .choices = try a.dupe(ld.Choice, &.{
                    .{ .text = "More" },
                    .{ .text = "Less", .shown = try a.print("{d} points less", .{pts}), .games = r.games },
                }) } },
                .why = "Early champions win lanes, not long games.",
                .tip = "Ahead with an early champion? Spend the lead before 20 minutes.",
                .games = r.games,
                .from = from,
            });
            continue;
        }
        try out.append(a, .{
            .id = try a.print("lean-{d}-{t}", .{ r.champion, r.role }),
            .q = "Early or late?",
            .ctx = try a.print("{s} {s}", .{ c.name, inRole(r.role) }),
            .setup = .{ .chips = .{ .champs = champs, .chips = try a.dupe([]const u8, &.{root.roleName(r.role)}) } },
            .answer = .{ .pick = .{ .right = if (early) 0 else 1, .choices = try a.dupe(ld.Choice, &.{
                .{ .text = "Early", .shown = if (early) try a.print("{f} gold ahead at {d}", .{ gold, lean.gold_minute }) else "", .games = r.games },
                .{ .text = "Late", .shown = if (early) "" else try a.print("+{d} points from even at {d}", .{ pts, lean.win_minute }), .games = r.games },
            }) } },
            .why = if (early)
                "Its lead comes early; in a long, even game the other team is stronger."
            else
                "Behind at 14, but in a long, even game its team is the stronger one.",
            .tip = if (early)
                try a.print("Against {s}, play safe early: an even game at 20 is better than usual for you.", .{c.name})
            else
                try a.print("Against {s}, end it early: take objectives before 20 minutes.", .{c.name}),
            .games = r.games,
            .from = from,
        });
    }
    return out.items;
}

fn inRole(r: Role) []const u8 {
    return switch (r) {
        .top => "in top lane",
        .jungle => "in the jungle",
        .middle => "in mid lane",
        .bottom => "in bot lane",
        .utility => "as support",
    };
}

fn roleNoun(r: Role) []const u8 {
    return switch (r) {
        .top => "top laner",
        .jungle => "jungler",
        .middle => "mid laner",
        .bottom => "bot laner",
        .utility => "support",
    };
}

/// Opponents of a counter puzzle each beat the champion by 2 SE in this many games or more
const counter_min_games = 200;
/// A real counter: this far under usual() (shrunk, as the champion page's vs usual) and
/// 2 sd, against an opponent winning at most counter_ordinary in the role
const counter_min_gap = 0.03;
const counter_ordinary = 0.51;
/// Just strong: within this of usual(), against an opponent winning at least
/// counter_strong in the role, by 2 SE
const strong_max_gap = 0.01;
const counter_strong = 0.51;

const Tally = struct {
    games: u64 = 0,
    wins: u64 = 0,

    fn rate(t: Tally) f64 {
        return root.ratio(t.wins, t.games);
    }
};

/// x against one lane opponent, from x's side
const Against = struct { o: u32, wins: u32, games: u32, own: Tally, vs: champion.VsUsual };

const Beaten = enum { counter, strong, neither };

/// How x losing to an opponent reads: a real counter, the opponent's own strength, or
/// neither clearly
fn beaten(a: Against) Beaten {
    const n: f64 = @floatFromInt(a.games);
    const rate = root.ratio(a.wins, a.games);
    if (a.games < counter_min_games) return .neither;
    if (0.5 - rate < 2 * @sqrt(rate * (1 - rate) / n)) return .neither;
    const o = a.own.rate();
    const o_se = @sqrt(o * (1 - o) / @as(f64, @floatFromInt(@max(1, a.own.games))));
    if (-a.vs.mean >= counter_min_gap and -a.vs.mean >= 2 * a.vs.sd and o <= counter_ordinary) return .counter;
    if (@abs(a.vs.mean) <= strong_max_gap and o >= counter_strong and o - 0.5 >= 2 * o_se) return .strong;
    return .neither;
}

/// One role's lane matchups from a curves file: each champion's own record (its
/// matchups summed) and k for vs usual (as champion.usualK, over these pairs)
const Lanes = struct {
    pairs: []const curvesfile.Header,
    own: std.AutoHashMapUnmanaged(u32, Tally),
    k: f64,

    fn init(a: std.mem.Allocator, curves: *const curvesfile.Curves, r: Role) !Lanes {
        var pairs: std.ArrayList(curvesfile.Header) = .empty;
        var own: std.AutoHashMapUnmanaged(u32, Tally) = .empty;
        for (curves.curves) |c| {
            const h = c.header;
            if (!matchup.isPage(h) or h.role != @backingInt(r) or h.a == 0) continue;
            const ta = try own.getOrPutValue(a, h.a, .{});
            ta.value_ptr.games += h.games;
            ta.value_ptr.wins += h.a_wins;
            const tb = try own.getOrPutValue(a, h.b, .{});
            tb.value_ptr.games += h.games;
            tb.value_ptr.wins += h.games - h.a_wins;
            if (h.a != h.b) try pairs.append(a, h.*);
        }
        var l: Lanes = .{ .pairs = pairs.items, .own = own, .k = 0 };
        var q: f64 = 0;
        var noise: f64 = 0;
        var scale: f64 = 0;
        for (l.pairs) |h| {
            const u = l.usualOf(h.a, h.b);
            const g: f64 = @floatFromInt(h.games);
            const d = @as(f64, @floatFromInt(h.a_wins)) - g * u;
            q += d * d / g;
            noise += u * (1 - u);
            scale += g;
        }
        l.k = 0.25 / std.math.clamp((q - noise) / @max(scale, 1), 0.0001, 0.01);
        return l;
    }

    fn usualOf(l: *const Lanes, x: u32, o: u32) f64 {
        return champion.usual(l.own.get(x).?.rate(), l.own.get(o).?.rate());
    }

    fn against(l: *const Lanes, x: u32, h: curvesfile.Header) Against {
        const o = if (h.a == x) h.b else h.a;
        const wins = if (h.a == x) h.a_wins else h.games - h.a_wins;
        return .{
            .o = o,
            .wins = wins,
            .games = h.games,
            .own = l.own.get(o).?,
            .vs = champion.VsUsual.of(wins, h.games, l.usualOf(x, o), l.k),
        };
    }
};

/// "Counter or just strong?" in role r: the most played champion that loses clearly to
/// one real counter and to one or two opponents strong against everyone (two if any
/// champion has them), from the every region, last 30 days lane curves (a patch in one
/// region is too few games for a counter to clear k)
fn counterPuzzle(site: *const Site, r: Role) !?ld.Puzzle {
    const curves = &(site.view_curves[(html.View{ .region = .all, .period = .days30 }).index()] orelse return null);
    const a = site.arena;
    const lanes: Lanes = try .init(a, curves, r);
    const Case = struct { x: u32, games: u64, counter: Against, strong: [2]?Against };
    var best: ?Case = null;
    var it = lanes.own.iterator();
    while (it.next()) |e| {
        const x = e.key_ptr.*;
        if (best) |b| if (e.value_ptr.games <= b.games and (b.strong[1] != null)) continue;
        var counter: ?Against = null;
        var strong: [2]?Against = .{ null, null };
        for (lanes.pairs) |h| {
            if (h.a != x and h.b != x) continue;
            const o = lanes.against(x, h);
            switch (beaten(o)) {
                .counter => if (counter == null or o.vs.mean / o.vs.sd < counter.?.vs.mean / counter.?.vs.sd) {
                    counter = o;
                },
                // The two most played
                .strong => if (strong[0] == null or o.games > strong[0].?.games) {
                    strong[1] = strong[0];
                    strong[0] = o;
                } else if (strong[1] == null or o.games > strong[1].?.games) {
                    strong[1] = o;
                },
                .neither => {},
            }
        }
        if (counter == null or strong[0] == null) continue;
        // Three options beat two; then the most played
        if (best) |b| if (b.strong[1] != null and strong[1] == null) continue;
        if (best) |b| if ((b.strong[1] != null) == (strong[1] != null) and e.value_ptr.games <= b.games) continue;
        best = .{ .x = x, .games = e.value_ptr.games, .counter = counter.?, .strong = strong };
    }
    const b = best orelse return null;
    const x = matchup.champ(site, b.x) orelse return null;
    const Named = struct { c: Champ, t: Against };
    var buf: [3]Named = undefined;
    var three: []Named = buf[0..0];
    for ([_]?Against{ b.counter, b.strong[0], b.strong[1] }) |maybe| {
        const t = maybe orelse continue;
        three.len += 1;
        three[three.len - 1] = .{ .c = matchup.champ(site, t.o) orelse return null, .t = t };
    }
    const by_name = struct {
        fn less(_: void, p: Named, q: Named) bool {
            return std.mem.lessThan(u8, p.c.name, q.c.name);
        }
    };
    std.mem.sort(Named, three, {}, by_name.less);
    const choices = try a.alloc(ld.Choice, three.len);
    const vs = try a.alloc(ld.Figure, three.len);
    var right: u8 = 0;
    var games: u32 = 0;
    for (three, choices, vs, 0..) |n, *ch, *f, i| {
        if (n.t.o == b.counter.o) right = @intCast(i);
        games += n.t.games;
        // x's rate into the opponent: the setup; the reveal, how much worse than usual
        f.* = .{ .champ = uiChamp(n.c), .text = try a.print("{d:.0}%", .{@round(100 * root.ratio(n.t.wins, n.t.games))}) };
        ch.* = .{
            .text = n.c.name,
            .champ = uiChamp(n.c),
            .shown = if (@round(-100 * n.t.vs.mean) < 1) "as usual" else try a.print("{d:.0} under usual", .{@round(-100 * n.t.vs.mean)}),
            .games = n.t.games,
        };
    }
    const c = three[right];
    return .{
        .id = try a.print("counter-{t}", .{r}),
        .q = "Which is a real counter?",
        .term = .{ .word = "counter", .note = "Wins more against this champion than against everyone else." },
        .setup = .{ .duel = .{ .who = uiChamp(x), .role = uiRole(r), .label = "wins into", .vs = vs } },
        .answer = .{ .pick = .{ .right = right, .choices = choices } },
        .why = try a.print("{s} wins {d:.0}% against everyone, {d:.0}% against {s}.", .{
            c.c.name, @round(100 * c.t.own.rate()), 100 - @round(100 * root.ratio(c.t.wins, c.t.games)), x.name,
        }),
        .tip = "Before calling it a counter, check the enemy's win rate against everyone.",
        .games = games,
        .from = try a.print("Ranked games, every region, all ranks, last 30 days; {s} games only", .{laneName(r)}),
    };
}

/// Chapter 0's counters (plan "Chapter 0"): the counter wins the pair outright by 2 SE,
/// this far under usual and 2 sd, in this many games, both champions in the top half of
/// their role by games
const basic_counter_gap = 0.04;
const basic_counter_games = 500;

/// x losing clearly to t.o in role r
const Lopsided = struct { r: Role, x: u32, t: Against };

fn lopsided(a: std.mem.Allocator, curves: *const curvesfile.Curves) ![]Lopsided {
    var out: std.ArrayList(Lopsided) = .empty;
    for ([_]Role{ .top, .middle, .bottom }) |r| {
        const lanes: Lanes = try .init(a, curves, r);
        var games: std.ArrayList(u64) = .empty;
        var it = lanes.own.valueIterator();
        while (it.next()) |t| try games.append(a, t.games);
        if (games.items.len == 0) continue;
        std.mem.sort(u64, games.items, {}, std.sort.desc(u64));
        const popular = games.items[games.items.len / 2];
        for (lanes.pairs) |h| for ([_]u32{ h.a, h.b }) |x| {
            const t = lanes.against(x, h);
            if (t.games < basic_counter_games or -t.vs.mean < basic_counter_gap or -t.vs.mean < 2 * t.vs.sd) continue;
            const won = root.ratio(t.wins, t.games);
            if (0.5 - won < 2 * @sqrt(won * (1 - won) / @as(f64, @floatFromInt(t.games)))) continue;
            if (lanes.own.get(x).?.games < popular or t.own.games < popular) continue;
            try out.append(a, .{ .r = r, .x = x, .t = t });
        };
    }
    std.mem.sort(Lopsided, out.items, {}, struct {
        fn more(_: void, p: Lopsided, q: Lopsided) bool {
            return p.t.vs.mean < q.t.vs.mean;
        }
    }.more);
    return out.items;
}

/// Tiles of the two most lopsided counters; the question, "who wins?" on the next pair
/// with neither champion on a tile
fn counterBasic(site: *const Site) !?ld.Puzzle {
    const curves = &(site.view_curves[(html.View{ .region = .all, .period = .days30 }).index()] orelse return null);
    const a = site.arena;
    var seen: std.ArrayList(u32) = .empty;
    var tiles: std.ArrayList(ld.Tile) = .empty;
    var asked: ?Lopsided = null;
    for (try lopsided(a, curves)) |l| {
        if (std.mem.indexOfScalar(u32, seen.items, l.x) != null or std.mem.indexOfScalar(u32, seen.items, l.t.o) != null) continue;
        try seen.appendSlice(a, &.{ l.x, l.t.o });
        if (tiles.items.len == 2) {
            asked = l;
            break;
        }
        const x = matchup.champ(site, l.x) orelse continue;
        const o = matchup.champ(site, l.t.o) orelse continue;
        try tiles.append(a, .{
            .title = root.roleName(l.r),
            .role = uiRole(l.r),
            .champs = try a.dupe(ld.Champ, &.{ uiChamp(o), uiChamp(x) }),
            .sep = "into",
        });
    }
    const l = asked orelse return null;
    const x = matchup.champ(site, l.x) orelse return null;
    const o = matchup.champ(site, l.t.o) orelse return null;
    const won = @round(100 * root.ratio(l.t.wins, l.t.games));
    const o_first = std.mem.lessThan(u8, o.name, x.name);
    const lose: ld.Choice = .{ .text = x.name, .champ = uiChamp(x), .shown = try a.print("won {d:.0}%", .{won}), .games = l.t.games };
    const win: ld.Choice = .{ .text = o.name, .champ = uiChamp(o), .shown = try a.print("won {d:.0}%", .{100 - won}), .games = l.t.games };
    return .{
        .id = try a.print("basic-counter-{s}-{s}", .{ o.slug, x.slug }),
        .q = "Who wins this lane more often?",
        .ctx = try a.print("{s} against {s}, {s}", .{ x.name, o.name, laneName(l.r) }),
        .setup = .{ .tiles = tiles.items },
        .answer = .{ .pick = .{
            .right = if (o_first) 0 else 1,
            .choices = try a.dupe(ld.Choice, if (o_first) &.{ win, lose } else &.{ lose, win }),
        } },
        .why = try a.print("{s} wins {d:.0}% of these games: a counter to {s}.", .{ o.name, 100 - won, x.name }),
        .tip = "A few matchups are lopsided: know the ones that beat your champion.",
        .games = l.t.games,
        .from = try a.print("Ranked games, every region, all ranks, last 30 days; {s} games only", .{laneName(l.r)}),
    };
}

/// Tiles of the three most played clearly early and clearly late champions; the
/// question on the next most played, none of them in "Does winning lane win the game?",
/// each in its main role
fn leanBasic(site: *const Site) !?ld.Puzzle {
    const file = site.lean orelse return null;
    const a = site.arena;
    var seen: std.ArrayList(u32) = .empty;
    for (try leanRows(a, file.rows, file.games / 100)) |r| try seen.append(a, r.champion);
    var clear: std.ArrayList(lean.Row) = .empty;
    for (file.rows) |r| {
        const c = matchup.champ(site, r.champion) orelse continue;
        const main, _, _ = share(site, c.c);
        if (main == r.role and leanClear(r)) try clear.append(a, r);
    }
    std.mem.sort(lean.Row, clear.items, {}, struct {
        fn more(_: void, x: lean.Row, y: lean.Row) bool {
            return x.games > y.games;
        }
    }.more);
    var tiles: [2]std.ArrayList(ld.Champ) = .{ .empty, .empty };
    var asked: ?struct { lean.Row, Champ } = null;
    for (clear.items) |r| {
        if (std.mem.indexOfScalar(u32, seen.items, r.champion) != null) continue;
        const c = matchup.champ(site, r.champion) orelse continue;
        try seen.append(a, r.champion);
        const t = &tiles[if (r.lean() == .early) 0 else 1];
        if (t.items.len < 3) {
            try t.append(a, uiChamp(c));
        } else if (tiles[0].items.len == 3 and tiles[1].items.len == 3) {
            asked = .{ r, c };
            break;
        }
    }
    const r, const c = asked orelse return null;
    const early = r.lean() == .early;
    const gold: root.Thousands = .{ .n = @trunc(@round(@abs(r.gold) / 10) * 10) };
    const pts: i64 = @max(1, @as(i64, @trunc(@round(@abs(r.win)))));
    return .{
        .id = try a.print("basic-lean-{s}-{t}", .{ c.slug, r.role }),
        .q = try a.print("{s}: early or late?", .{c.name}),
        .ctx = try a.print("{s} {s}", .{ c.name, inRole(r.role) }),
        .setup = .{ .tiles = try a.dupe(ld.Tile, &.{
            .{ .title = "Early", .champs = tiles[0].items },
            .{ .title = "Late", .champs = tiles[1].items },
        }) },
        .answer = .{ .pick = .{ .right = if (early) 0 else 1, .choices = try a.dupe(ld.Choice, &.{
            .{ .text = "Early", .shown = if (early) try a.print("{f} gold ahead at {d}", .{ gold, lean.gold_minute }) else "", .games = r.games },
            .{ .text = "Late", .shown = if (early) "" else try a.print("+{d} points from even at {d}", .{ pts, lean.win_minute }), .games = r.games },
        }) } },
        .why = if (early)
            try a.print("{s} is ahead at {d} minutes, then wins fewer long, even games.", .{ c.name, lean.gold_minute })
        else
            try a.print("{s} is behind at {d} minutes, then wins more long, even games.", .{ c.name, lean.gold_minute }),
        .tip = "Early champions want a short game; late ones a long one.",
        .games = r.games,
        .from = try a.print("Ranked games, {s}, games still going at {d} minutes", .{ file.scope, lean.win_minute }),
    };
}

/// Mostly magic or mostly physical: this share of damage to champions or more
const basic_damage_share = 0.8;

/// Tiles of the three most played mostly magic and mostly physical champions; the
/// question: which of the next ones is magic
fn damageBasic(site: *const Site) !?ld.Puzzle {
    const facts = site.learn orelse return null;
    const a = site.arena;
    var kinds: [2]std.ArrayList(Champ) = .{ .empty, .empty };
    for (site.champs) |c| {
        const m = facts.champs[c.c].magic orelse continue;
        if (m >= basic_damage_share) try kinds[0].append(a, c);
        if (1 - m >= basic_damage_share) try kinds[1].append(a, c);
    }
    for (&kinds) |*k| std.mem.sort(Champ, k.items, {}, struct {
        fn more(_: void, x: Champ, y: Champ) bool {
            return x.games > y.games;
        }
    }.more);
    const m = kinds[0].items;
    const p = kinds[1].items;
    if (m.len < 4 or p.len < 5) return null;
    var three = [_]Champ{ p[3], m[3], p[4] };
    std.mem.sort(Champ, &three, {}, struct {
        fn less(_: void, x: Champ, y: Champ) bool {
            return std.mem.lessThan(u8, x.name, y.name);
        }
    }.less);
    var choices: [3]ld.Choice = undefined;
    var right: u8 = 0;
    for (three, &choices, 0..) |c, *ch, i| {
        if (c.id == m[3].id) right = @intCast(i);
        ch.* = .{ .text = c.name, .champ = uiChamp(c), .shown = try a.print("{d:.0}% magic", .{@round(100 * facts.champs[c.c].magic.?)}) };
    }
    var tiles: [2]ld.Tile = undefined;
    for (&tiles, [_][]const u8{ "Mostly magic", "Mostly physical" }, [_][]const Champ{ m, p }) |*t, title, k| {
        var cs: [3]ld.Champ = undefined;
        for (&cs, k[0..3]) |*x, c| x.* = uiChamp(c);
        t.* = .{ .title = title, .champs = try a.dupe(ld.Champ, &cs) };
    }
    return .{
        .id = try a.print("basic-magic-{s}", .{m[3].slug}),
        .q = "Which of these deals mostly magic damage?",
        .setup = .{ .tiles = try a.dupe(ld.Tile, &tiles) },
        .answer = .{ .pick = .{ .right = right, .choices = try a.dupe(ld.Choice, &choices) } },
        .why = try a.print("{d:.0}% of {s}'s damage to champions is magic.", .{ @round(100 * facts.champs[m[3].c].magic.?), m[3].name }),
        .tip = "Mix magic and physical damage: armour alone then can't stop your team.",
        .games = facts.damage_games,
        .from = try a.print("Damage to champions in {d} recent ranked games, patch {s}", .{ facts.damage_games, site.patch }),
    };
}

/// A bot and support pair counts from this many games together
const duo_min_games = 300;

const Duo = struct { bot: Champ, sup: Champ, wins: u32, games: u32, vs: champion.VsUsual };

/// "Which pair wins more together?": a bot and support pair clearly over usual (2 sd)
/// against the two most played pairs as usual, both clearly under it in raw win rate;
/// none when no pair is clear (learned.md: duos move 1.3-1.6 points)
fn duoBasic(site: *const Site) !?ld.Puzzle {
    const st = &site.stats;
    const a = site.arena;
    const pairs: champion.Pairs = .{ .st = st, .r = .bottom, .r2 = .utility, .ally = true };
    const k = champion.pairsUsualK(pairs);
    var duos: std.ArrayList(Duo) = .empty;
    for (site.champs) |x| {
        const xs = st.champRole(.bottom, x.c);
        if (xs.games < duo_min_games) continue;
        for (site.champs) |y| {
            const n = pairs.get(x.c, y.c);
            if (x.c == y.c or n.games < duo_min_games) continue;
            const ys = st.champRole(.utility, y.c);
            const u = pairs.usualOf(root.ratio(xs.wins, xs.games), root.ratio(ys.wins, ys.games));
            try duos.append(a, .{ .bot = x, .sup = y, .wins = n.wins, .games = n.games, .vs = .of(n.wins, n.games, u, k) });
        }
    }
    var best: ?Duo = null;
    for (duos.items) |d| {
        if (d.vs.mean < 2 * d.vs.sd) continue;
        if (best == null or d.vs.mean / d.vs.sd > best.?.vs.mean / best.?.vs.sd) best = d;
    }
    const b = best orelse return null;
    var usual: [2]?Duo = .{ null, null };
    for (duos.items) |d| {
        if (d.bot.c == b.bot.c or d.sup.c == b.sup.c or @abs(d.vs.mean) > d.vs.sd) continue;
        if (!clearlyAbove(b, d)) continue;
        if (usual[0] != null and d.bot.c == usual[0].?.bot.c) continue;
        if (usual[0] == null or d.games > usual[0].?.games) {
            usual[1] = usual[0];
            usual[0] = d;
        } else if (usual[1] == null or d.games > usual[1].?.games) {
            usual[1] = d;
        }
    }
    var three = [_]Duo{ b, usual[0] orelse return null, usual[1] orelse return null };
    std.mem.sort(Duo, &three, {}, struct {
        fn less(_: void, x: Duo, y: Duo) bool {
            return std.mem.lessThan(u8, x.bot.name, y.bot.name);
        }
    }.less);
    var tiles: [3]ld.Tile = undefined;
    var choices: [3]ld.Choice = undefined;
    var right: u8 = 0;
    var games: u32 = 0;
    for (three, &tiles, &choices, 0..) |d, *t, *ch, i| {
        if (d.bot.c == b.bot.c) right = @intCast(i);
        games += d.games;
        const name = try a.print("{s} + {s}", .{ d.bot.name, d.sup.name });
        t.* = .{ .title = "", .champs = try a.dupe(ld.Champ, &.{ uiChamp(d.bot), uiChamp(d.sup) }), .sep = "+" };
        ch.* = .{ .text = name, .shown = try a.print("won {d:.0}%", .{@round(100 * root.ratio(d.wins, d.games))}), .games = d.games };
    }
    return .{
        .id = try a.print("basic-duo-{s}-{s}", .{ b.bot.slug, b.sup.slug }),
        .q = "Which pair wins more together?",
        .ctx = "A bot laner and a support, same team",
        .setup = .{ .tiles = try a.dupe(ld.Tile, &tiles) },
        .answer = .{ .pick = .{ .right = right, .choices = try a.dupe(ld.Choice, &choices) } },
        .why = try a.print("{s} and {s} win more together than each does with others.", .{ b.bot.name, b.sup.name }),
        .tip = "Bot and support is the pairing that matters: pick with your partner.",
        .games = games,
        .from = try a.print("Ranked games, patch {s}, bot laners and supports on one team", .{site.patch}),
    };
}

/// x wins more than y by 2 standard errors of the difference
fn clearlyAbove(x: Duo, y: Duo) bool {
    const p = root.ratio(x.wins, x.games);
    const q = root.ratio(y.wins, y.games);
    const v = p * (1 - p) / @as(f64, @floatFromInt(x.games)) + q * (1 - q) / @as(f64, @floatFromInt(y.games));
    return p - q >= 2 * @sqrt(v);
}
