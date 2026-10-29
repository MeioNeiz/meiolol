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
const learn = @import("../learn.zig");
const daily = @import("../daily.zig");

const core = @import("core");
const curvesfile = core.curvesfile;

const Site = root.Site;
const log = std.log.scoped(.learn);
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
    const ends = try drafts(site, all.len);
    var start: u8 = 0;
    for (all, 0..) |c, i| {
        if (c.puzzles.len == 0) continue;
        // A first visit lands on chapter 1 (notes/learn.md Decisions)
        if (i == 1) start = @intCast(chapters.items.len);
        var ch = c;
        if (i < ends.len) ch.puzzles = try std.mem.concat(a, ld.Puzzle, &.{ c.puzzles, &.{ends[i]} });
        try chapters.append(a, ch);
    }
    return .{ .ddragon = site.ddragon_version, .chapters = chapters.items, .start = start };
}

/// Chapter 0 (plan "Chapter 0"): tiles of clear examples, the question on another
fn starter(site: *const Site) ![]const ld.Puzzle {
    var out: std.ArrayList(ld.Puzzle) = .empty;
    const all = [_]?ld.Puzzle{ try roles(site), try counterBasic(site), try leanBasic(site), try damageBasic(site) };
    for (all) |x| if (x) |p| try out.append(site.arena, p);
    return out.items;
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
        tiles[ri] = .{ .title = root.roleName(r), .role = champion.uiRole(r), .champs = cs.items };
        if (r == .jungle) asked = picks[3];
    }
    const c = asked orelse return null;
    _, _, const total = share(site, c.c);
    var choices: [5]ld.Choice = undefined;
    for (Role.all, 0..) |r, ri| {
        const g = st.champRole(r, c.c).games;
        choices[ri] = .{
            .text = root.roleName(r),
            .role = champion.uiRole(r),
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
    const view = (html.View{ .region = .all, .period = .days30 }).index();
    const curves = if (site.view_curves[view]) |*c| c else return null;
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
    // Per opponent, its rate into x over its rate against everyone
    const reveal = try a.alloc(ld.Rate, 2 * three.len);
    var right: u8 = 0;
    var games: u32 = 0;
    for (three, choices, vs, 0..) |n, *ch, *f, i| {
        reveal[2 * i] = .{ .label = n.c.name, .sub = try a.print("into {s}", .{x.name}), .v = @floatCast(100 * (1 - root.ratio(n.t.wins, n.t.games))), .games = n.t.games };
        reveal[2 * i + 1] = .{ .label = n.c.name, .sub = "vs everyone", .v = @floatCast(100 * n.t.own.rate()), .games = @intCast(@min(n.t.own.games, std.math.maxInt(u32))) };
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
        .setup = .{ .duel = .{ .who = uiChamp(x), .role = champion.uiRole(r), .label = "wins against", .vs = vs } },
        .answer = .{ .pick = .{ .right = right, .choices = choices } },
        .reveal = reveal,
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

/// The two most lopsided counters for the tiles, then the next with neither champion on
/// a tile to ask
fn lopsidedPicks(ls: []const Lopsided) ?[3]Lopsided {
    var out: [3]Lopsided = undefined;
    var n: usize = 0;
    next: for (ls) |l| {
        for (out[0..n]) |p| for ([_]u32{ p.x, p.t.o }) |c| if (c == l.x or c == l.t.o) continue :next;
        out[n] = l;
        n += 1;
        if (n == out.len) return out;
    }
    return null;
}

/// Tiles of the two most lopsided counters; the question, "who wins?" on the next pair
/// with neither champion on a tile
fn counterBasic(site: *const Site) !?ld.Puzzle {
    const view = (html.View{ .region = .all, .period = .days30 }).index();
    const curves = if (site.view_curves[view]) |*c| c else return null;
    const a = site.arena;
    const picks = lopsidedPicks(try lopsided(a, curves)) orelse return null;
    var tiles: [2]ld.Tile = undefined;
    for (&tiles, picks[0..2]) |*t, p| {
        const x = matchup.champ(site, p.x) orelse return null;
        const o = matchup.champ(site, p.t.o) orelse return null;
        t.* = .{
            .title = root.roleName(p.r),
            .role = champion.uiRole(p.r),
            .champs = try a.dupe(ld.Champ, &.{ uiChamp(o), uiChamp(x) }),
            .sep = "beats",
        };
    }
    const l = picks[2];
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
        .setup = .{ .tiles = try a.dupe(ld.Tile, &tiles) },
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

/// Of rows (most played first), three early and three late for the tiles, then the next
/// to ask, none of them in `hooks`
fn leanPicks(rows: []const lean.Row, hooks: []const lean.Row) ?struct { [2][3]lean.Row, lean.Row } {
    var tiles: [2][3]lean.Row = undefined;
    var n: [2]usize = .{ 0, 0 };
    next: for (rows) |r| {
        for (hooks) |h| if (h.champion == r.champion) continue :next;
        if (n[0] == 3 and n[1] == 3) return .{ tiles, r };
        const i: usize = if (r.lean() == .early) 0 else 1;
        if (n[i] == 3) continue;
        tiles[i][n[i]] = r;
        n[i] += 1;
    }
    return null;
}

/// Tiles of the three most played clearly early and clearly late champions; the
/// question on the next most played, none of them in "Does winning lane win the game?",
/// each in its main role
fn leanBasic(site: *const Site) !?ld.Puzzle {
    const file = site.lean orelse return null;
    const a = site.arena;
    const hooks = try leanRows(a, file.rows, file.games / 100);
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
    const tile_rows, const r = leanPicks(clear.items, hooks) orelse return null;
    var tiles: [2][3]ld.Champ = undefined;
    for (&tiles, tile_rows) |*t, rows| for (t, rows) |*x, row| {
        x.* = uiChamp(matchup.champ(site, row.champion) orelse return null);
    };
    const c = matchup.champ(site, r.champion) orelse return null;
    const early = r.lean() == .early;
    const gold: root.Thousands = .{ .n = @trunc(@round(@abs(r.gold) / 10) * 10) };
    const pts: i64 = @max(1, @as(i64, @trunc(@round(@abs(r.win)))));
    return .{
        .id = try a.print("basic-lean-{s}-{t}", .{ c.slug, r.role }),
        .q = try a.print("{s}: early or late?", .{c.name}),
        .ctx = try a.print("{s} {s}", .{ c.name, inRole(r.role) }),
        .setup = .{ .tiles = try a.dupe(ld.Tile, &.{
            .{ .title = "Early", .champs = try a.dupe(ld.Champ, &tiles[0]) },
            .{ .title = "Late", .champs = try a.dupe(ld.Champ, &tiles[1]) },
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

/// Chapter ends (plan "Chapter end and the drills"): practice drafts (learn.zig) where
/// one option is clearly apart. The four teammates deal under a fifth of their damage as
/// magic (learned.md: about 5 points fewer wins, Sure) and the one option bringing magic
/// is also the model's best of the four. Model gaps alone clear almost none (notes/
/// learn.md L4). One per chapter while they last, a role not used yet first
fn drafts(site: *const Site, chapters: usize) ![]const ld.Puzzle {
    const facts = site.learn orelse return &.{};
    const a = site.arena;
    const json = for (site.daily_files) |f| {
        if (std.mem.eql(u8, f.path, "learn/practice.json")) break f.data;
    } else return &.{};
    const pack = std.json.parseFromSliceLeaky([]learn.Practice, a, json, .{ .ignore_unknown_fields = true }) catch |err| {
        log.warn("learn/practice.json: {t}", .{err});
        return &.{};
    };
    var out: std.ArrayList(ld.Puzzle) = .empty;
    var used: std.EnumSet(Role) = .empty;
    for (0..2) |pass| for (pack) |p| {
        if (out.items.len == chapters) break;
        if ((pass == 0) == used.contains(p.hidden_role)) continue;
        const right = clearOption(p, teamMagic(site, facts, p) orelse continue) orelse continue;
        try out.append(a, try draftPuzzle(site, facts, p, right) orelse continue);
        used.insert(p.hidden_role);
    };
    return out.items;
}

const draft_team_magic = 0.2;

/// The four teammates' average magic share; null when one is unknown
fn teamMagic(site: *const Site, facts: learn.Facts, p: learn.Practice) ?f64 {
    var sum: f64 = 0;
    for (Role.all, p.teams[p.hidden_team]) |r, id| {
        if (r == p.hidden_role) continue;
        const c = site.stats.index(id) orelse return null;
        sum += facts.champs[c].magic orelse return null;
    }
    return sum / 4;
}

/// The option clearly apart, by draft()'s rule
fn clearOption(p: learn.Practice, team_magic: f64) ?u8 {
    if (team_magic >= draft_team_magic) return null;
    var bringer: ?u8 = null;
    for (p.options, 0..) |o, i| {
        if (@as(f64, @floatFromInt(o.magic orelse continue)) < 100 * learn.brings_share) continue;
        if (bringer != null) return null;
        bringer = @intCast(i);
    }
    const b = bringer orelse return null;
    for (p.options, 0..) |o, i| if (i != b and o.pp >= p.options[b].pp) return null;
    return b;
}

fn draftPuzzle(site: *const Site, facts: learn.Facts, p: learn.Practice, right: u8) !?ld.Puzzle {
    const a = site.arena;
    var sides: [2][5]ld.Champ = undefined;
    for (&sides, p.teams) |*side, team| for (side, team) |*dst, id| {
        dst.* = uiChamp(matchup.champ(site, id) orelse return null);
    };
    var bans: [2][]ld.Champ = undefined;
    for (&bans, p.bans) |*dst, ids| {
        var l: std.ArrayList(ld.Champ) = .empty;
        for (ids) |id| if (matchup.champ(site, id)) |c| try l.append(a, uiChamp(c));
        dst.* = l.items;
    }
    const us = p.hidden_team;
    var choices: [4]ld.Choice = undefined;
    var games: u32 = 0;
    for (p.options, &choices, 0..) |o, *ch, i| {
        const c = matchup.champ(site, o.id) orelse return null;
        var why: std.ArrayList(ld.Why) = .empty;
        if (i == right) try why.append(a, .{ .text = "Adds the magic your team lacks", .up = true });
        for (o.reasons) |r| if (try reasonWords(site, p.hidden_role, r)) |w| try why.append(a, w);
        ch.* = .{
            .text = c.name,
            .champ = uiChamp(c),
            .shown = if (o.magic) |m| try a.print("{d}% magic", .{m}) else "",
            .games = o.games,
            .why = why.items,
        };
        games += o.games;
    }
    var magic: [2][5]?u8 = undefined;
    for (&magic, [2]u1{ us, 1 - us }) |*side, t| for (side, p.teams[t]) |*m, id| {
        const c = site.stats.index(id);
        m.* = if (c) |x| if (facts.champs[x].magic) |v| @intFromFloat(@round(100 * v)) else null else null;
    };
    magic[0][@backingInt(p.hidden_role)] = p.options[right].magic;
    return .{
        .id = try a.print("draft-{x:0>8}", .{@as(u32, @truncate(std.hash.Wyhash.hash(0, std.mem.asBytes(&p.teams))))}),
        .q = "Your team picks last. Which champion fits this draft?",
        .ctx = try a.print("A real ranked game{s}{s}, patch {s}", .{ if (p.tier != null) ", " else "", if (p.tier) |t| try tierName(a, t) else "", p.patch }),
        .setup = .{ .draft = .{
            .role = champion.uiRole(p.hidden_role),
            .us = sides[us],
            .them = sides[1 - us],
            .bans = .{ bans[us], bans[1 - us] },
            .magic = magic,
        } },
        .answer = .{ .pick = .{ .right = right, .choices = try a.dupe(ld.Choice, &choices) } },
        .why = "Your four deal almost no magic damage: teams with mixed damage tend to do better.",
        .tip = "Look at your team's damage before you lock in.",
        .games = games,
        .from = try a.print("The options' games in the role, patch {s}; teams' damage from {d} games", .{ p.patch, facts.damage_games }),
    };
}

/// "Emerald" from "EMERALD"
fn tierName(a: std.mem.Allocator, t: []const u8) ![]const u8 {
    const s = try std.ascii.allocLowerString(a, t);
    if (s.len > 0) s[0] = std.ascii.toUpper(s[0]);
    return s;
}

/// Reason gates (docs/plan/ui/why.md): half a point or more; pairs on 100+ games, and
/// only those the data shows matter: the lane opponent, support or mid into the enemy
/// bot, bot with support
const reason_min_pp = 0.5;
const reason_min_games = 100;

fn reasonWords(site: *const Site, role: Role, r: daily.Reason) !?ld.Why {
    if (!(@abs(r.pp) >= reason_min_pp)) return null;
    const up = r.pp > 0;
    if (r.kind == .base) return .{ .text = if (up) "Strong this patch" else "Weak this patch", .up = up };
    if (r.games < reason_min_games) return null;
    const other = (matchup.champ(site, r.id) orelse return null).name;
    const a = site.arena;
    switch (r.kind) {
        .base => unreachable,
        .enemy => {
            const counts = r.role == role or (r.role == .bottom and (role == .utility or role == .middle));
            if (!counts) return null;
            return .{ .text = try a.print("{s} into {s}", .{ if (up) "Good" else "Hard", other }), .up = up };
        },
        .ally => {
            const duo = (role == .bottom and r.role == .utility) or (role == .utility and r.role == .bottom);
            if (!duo) return null;
            return .{ .text = try a.print("{s} with {s}", .{ if (up) "Works" else "Awkward", other }), .up = up };
        },
    }
}

test leanRows {
    const row = struct {
        fn f(id: u32, role: Role, games: u32, gold: f64, win: f64) lean.Row {
            return .{ .champion = id, .role = role, .games = games, .gold = gold, .gold_sd = 50, .win = win, .win_sd = 1 };
        }
    }.f;
    const rows = [_]lean.Row{
        row(1, .bottom, 40_000, 850, -8), // the hook: most gold of the early ones
        row(10, .top, 1_500, 1_000, -9), // more gold, too few games for the hook
        row(2, .bottom, 90_000, -250, 6), // same role as the hook
        row(3, .top, 60_000, 300, -4),
        row(4, .top, 70_000, -660, 7), // top's most played
        row(5, .jungle, 150_000, 250, -2), // under 3 points
        row(6, .jungle, 80_000, 150, -5), // under 200 gold
        row(7, .middle, 100, 900, -9), // too few games
        row(8, .utility, 90_000, 400, 5), // ahead and wins more: no lean
        row(9, .middle, 50_000, -300, 12),
    };
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const got = try leanRows(arena.allocator(), &rows, 10_000);
    var ids: [3]u32 = undefined;
    try std.testing.expectEqual(ids.len, got.len);
    for (got, &ids) |r, *id| id.* = r.champion;
    try std.testing.expectEqualSlices(u32, &.{ 1, 9, 4 }, &ids);
}

test leanPicks {
    const row = struct {
        fn f(id: u32, early: bool) lean.Row {
            return .{ .champion = id, .role = .top, .games = 50_000, .gold = if (early) 500 else -500, .gold_sd = 50, .win = if (early) -5 else 5, .win_sd = 1 };
        }
    }.f;
    const hooks = [_]lean.Row{row(2, true)};
    // 2 is a hook; 6 comes when early's tile is full, so it is passed over
    const rows = [_]lean.Row{ row(1, true), row(2, true), row(3, true), row(4, false), row(5, true), row(6, true), row(7, false), row(8, false), row(9, true) };
    const tiles, const asked = leanPicks(&rows, &hooks).?;
    for (tiles, [2][3]u32{ .{ 1, 3, 5 }, .{ 4, 7, 8 } }) |t, want| for (t, want) |r, id| try std.testing.expectEqual(id, r.champion);
    try std.testing.expectEqual(9, asked.champion);
    try std.testing.expectEqual(null, leanPicks(rows[0..8], &hooks));
}

test beaten {
    const k = 600;
    const case = struct {
        fn f(wins: u32, games: u32, own_rate: f64, usual: f64) Against {
            const own: Tally = .{ .games = 100_000, .wins = @round(own_rate * 100_000) };
            return .{ .o = 1, .wins = wins, .games = games, .own = own, .vs = champion.VsUsual.of(wins, games, usual, k) };
        }
    }.f;
    // 45% of 5,000 against a 49% champion, usually 51%: 5 points under, shrunk to 4.5
    try std.testing.expectEqual(Beaten.counter, beaten(case(2_250, 5_000, 0.49, 0.51)));
    // 48% of 5,000 against a 52% champion, usually 48%
    try std.testing.expectEqual(Beaten.strong, beaten(case(2_400, 5_000, 0.52, 0.48)));
    // Too few games, or not losing by 2 SE
    try std.testing.expectEqual(Beaten.neither, beaten(case(80, 190, 0.49, 0.51)));
    try std.testing.expectEqual(Beaten.neither, beaten(case(2_450, 5_000, 0.52, 0.48)));
    // Far under usual, but the opponent is strong: neither clearly
    try std.testing.expectEqual(Beaten.neither, beaten(case(2_100, 5_000, 0.53, 0.47)));
}

test lopsidedPicks {
    const pick = struct {
        fn f(x: u32, o: u32) Lopsided {
            return .{ .r = .top, .x = x, .t = .{ .o = o, .wins = 0, .games = 0, .own = .{}, .vs = .{ .mean = 0, .sd = 0 } } };
        }
    }.f;
    // 3 into 2 shares 2 with the first tile; 5 into 1 shares 1
    const ls = [_]Lopsided{ pick(1, 2), pick(3, 2), pick(3, 4), pick(5, 1), pick(5, 6) };
    const got = lopsidedPicks(&ls).?;
    for (got, [_]u32{ 1, 3, 5 }) |p, x| try std.testing.expectEqual(x, p.x);
    try std.testing.expectEqual(null, lopsidedPicks(ls[0..4]));
}

test clearOption {
    const opt = struct {
        fn f(pp: f64, magic: ?u8) learn.Option {
            return .{ .id = 1, .pp = pp, .games = 500, .wins = 250, .magic = magic, .reasons = &.{}, .lane = null };
        }
    }.f;
    var p: learn.Practice = .{
        .patch = "16.21",
        .tier = null,
        .teams = @splat(@splat(0)),
        .bans = .{ &.{}, &.{} },
        .hidden_team = 0,
        .hidden_role = .utility,
        .difficulty = .easy,
        .need = .magic,
        .options = .{ opt(0.5, 10), opt(1.5, 80), opt(-0.3, 20), opt(0.9, null) },
        .played = 0,
        .won = true,
        .minutes = 30,
    };
    try std.testing.expectEqual(@as(?u8, 1), clearOption(p, 0.1));
    // The team already has magic enough
    try std.testing.expectEqual(@as(?u8, null), clearOption(p, 0.25));
    // The bringer is not also the model's best of the four
    p.options[0].pp = 2;
    try std.testing.expectEqual(@as(?u8, null), clearOption(p, 0.1));
    // Two bringers: not clearly apart
    p.options[0] = opt(0.5, 70);
    try std.testing.expectEqual(@as(?u8, null), clearOption(p, 0.1));
}
