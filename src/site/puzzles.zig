//! Learn's puzzles: a committed guess (a number on a slider, or one of a few options),
//! then the measured answer with its games, one line why and a takeaway. Most are
//! hand-written from finished checks (docs/learned.md, research/questions/coach-stat-
//! claims.md, the 20 Oct mastery bands); one comes from this patch's lane curves.
//! static/learn.js runs them; without script each shows its answer folded.
//!
//! A puzzle ships only when its answer is clear of noise and big enough to matter
//! (J11): a gap of 3+ points or 200+ gold, hundreds of games or more.

const std = @import("std");
const core = @import("core");
const root = @import("root.zig");
const html = @import("html.zig");
const tpl = html.tpl;
const matchup = @import("matchup.zig");
const lean = @import("../lean.zig");

const Writer = std.Io.Writer;
const Role = core.Role;
const Site = root.Site;
const Champ = root.Champ;

const Choice = struct { t: []const u8, icon: ?[]const u8 = null };
const Bar = struct { label: []const u8, v: f64, n: u64, hi: bool = false };

pub const Puzzle = struct {
    id: []const u8,
    topic: []const u8,
    q: []const u8,
    /// guess: a slider from min to max; pick: one of choices
    kind: enum { guess, pick },
    min: f64 = 0,
    max: f64 = 100,
    step: f64 = 1,
    /// After the number: "%", " gold"
    unit: []const u8 = "%",
    /// guess: the measured number; pick: the right choice's index
    answer: f64,
    choices: []const Choice = &.{},
    /// The reveal's headline, with its games; for a guess, what follows the number
    real: []const u8,
    bars: []const Bar = &.{},
    /// Bars' unit; "%" bars are drawn on 0-100, others on their largest
    bar_unit: []const u8 = "%",
    /// What the bars count: "games", "kills", "takes"
    per: []const u8 = "games",
    why: []const u8,
    tip: []const u8,
    from: []const u8,
};

const all_regions = "Ranked solo, Platinum IV and up, every region, patches 16.19-16.20";

/// Players' pre-game mastery points on their champion (meiolol-d1, 20 Oct,
/// snap-20261018T1007Z mastery_pre.tsv; data/team/2026-10-20-morning/learning.md)
const mastery_from = "Ranked solo, Platinum IV and up, every region, 1.92M player-games " ++
    "with mastery points before the game (snapshot of 18 Oct)";

const know: Puzzle = .{
    .id = "know",
    .topic = "Play what you know",
    .q = "Players on a champion they have barely played (under 10,000 mastery points) " ++
        "win 47.7% of games. Players with 300,000+ points on their champion win how often?",
    .kind = .guess,
    .min = 40,
    .max = 65,
    .step = 0.5,
    .answer = 51.7,
    .real = "of 508,609 games",
    .bars = &.{
        .{ .label = "Under 10k points", .v = 47.7, .n = 207_598 },
        .{ .label = "10k-30k", .v = 48.7, .n = 262_918 },
        .{ .label = "30k-100k", .v = 49.5, .n = 486_889 },
        .{ .label = "100k-300k", .v = 50.6, .n = 457_460 },
        .{ .label = "300k+", .v = 51.7, .n = 508_609, .hi = true },
    },
    .why = "4 points from new to main. A typical difference between top lane matchups, " ++
        "where counters matter most, is about 2.5 points (134,375 games).",
    .tip = "Counter-pick with a champion you already know.",
    .from = mastery_from,
};

/// mastery-gaps.tsv: new under 30k points, practised 100k+
const newcomer: Puzzle = .{
    .id = "newcomer",
    .topic = "Play what you know",
    .q = "On which champion do players new to it (under 30,000 points) fall furthest " ++
        "behind its practised players (100,000+)?",
    .kind = .pick,
    .answer = 1,
    .choices = &.{ .{ .t = "Vayne bot" }, .{ .t = "Rengar jungle" } },
    .real = "Rengar: new players won 39.4% of 1,700 games, practised ones 50.7% of 3,441",
    .bars = &.{
        .{ .label = "Rengar, new", .v = 39.4, .n = 1_700, .hi = true },
        .{ .label = "Rengar, practised", .v = 50.7, .n = 3_441 },
        .{ .label = "Vayne, new", .v = 54.6, .n = 957 },
        .{ .label = "Vayne, practised", .v = 49.7, .n = 4_656 },
    },
    .why = "Vayne is famous as hard, but her new players did no worse than her regulars. " ++
        "Rengar's lost 11 points more: hard to master is not hard to start.",
    .tip = "Learn a champion like Rengar in normal games before ranked.",
    .from = mastery_from,
};

/// research/raw/fed-player-win-rate-measured.md (65,240 games, local snapshot)
const fed_from = "Ranked solo, Platinum IV and up, every region, patches 16.19-16.20, " ++
    "65,240 games of 15+ minutes";

const fed: Puzzle = .{
    .id = "fed",
    .topic = "Your lead, your team",
    .q = "You are 1,000+ gold ahead of your lane opponent at 14 minutes, but the other " ++
        "four on your team are behind theirs. How often does your team win?",
    .kind = .guess,
    .answer = 47.3,
    .real = "of 59,796 games",
    .bars = &.{
        .{ .label = "Other four 3k+ behind", .v = 27.6, .n = 16_328 },
        .{ .label = "1.5k-3k behind", .v = 46.6, .n = 18_349 },
        .{ .label = "0-1.5k behind", .v = 60.7, .n = 25_119 },
        .{ .label = "0-1.5k ahead", .v = 73.0, .n = 26_488 },
        .{ .label = "1.5k+ ahead", .v = 89.1, .n = 56_450 },
    },
    .why = "A fed laner wins 68.6% of 142,734 games overall, but that rides on the other " ++
        "four: when they are behind, it is a coin flip.",
    .tip = "Ahead in lane? Take your lead to where your team is losing.",
    .from = fed_from,
};

const fed_role: Puzzle = .{
    .id = "fed-role",
    .topic = "Your lead, your team",
    .q = "1,000+ gold up at 14, the other four behind. Whose lead turns into more wins?",
    .kind = .pick,
    .answer = 1,
    .choices = &.{ .{ .t = "A fed top laner" }, .{ .t = "A fed bot laner" } },
    .real = "Bot: 50.4% of 14,808 games. Top: 44.6% of 17,476",
    .bars = &.{
        .{ .label = "Bot", .v = 50.4, .n = 14_808, .hi = true },
        .{ .label = "Mid", .v = 49.0, .n = 12_582 },
        .{ .label = "Jungle", .v = 48.3, .n = 11_235 },
        .{ .label = "Top", .v = 44.6, .n = 17_476 },
        .{ .label = "Support", .v = 39.4, .n = 3_695 },
    },
    .why = "Early fights happen around dragon, next to bot lane. A top lane lead stays " ++
        "on the far side of the map unless it moves.",
    .tip = "Ahead in top lane? Bring the lead to the map: teleport, roam, take towers.",
    .from = fed_from,
};

/// research/raw/gold-deficit-comeback-measured.md (239,629 games, 4.5-5.5k behind)
const surrender: Puzzle = .{
    .id = "ff15",
    .topic = "Comebacks",
    .q = "Your team is 5,000 gold behind at 15 minutes and someone types /ff. How often " ++
        "does the team behind still win?",
    .kind = .guess,
    .max = 50,
    .answer = 13.0,
    .real = "of 20,888 games",
    .bars = &.{
        .{ .label = "5k behind at 10 min", .v = 7.2, .n = 6_217 },
        .{ .label = "at 15 min", .v = 13.0, .n = 20_888, .hi = true },
        .{ .label = "at 20 min", .v = 15.2, .n = 20_677 },
        .{ .label = "at 25 min", .v = 16.0, .n = 16_934 },
        .{ .label = "at 30 min", .v = 17.4, .n = 10_267 },
    },
    .why = "1 game in 8. The same 5k matters less later: a game holds about 57k gold at " ++
        "15 minutes and 125k at 30.",
    .tip = "5k down at 15 is not over: play for the next fight, not the vote.",
    .from = all_regions ++ ", 239,629 games still going at that minute",
};

/// research/raw/kill-gold-by-rank-measured.md (kills from 10:00, 290,807 games)
const bounty: Puzzle = .{
    .id = "bounty",
    .topic = "Comebacks",
    .q = "A champion kill pays about 300 gold. When your team is 3,000+ gold behind, what " ++
        "does a kill pay you on average?",
    .kind = .guess,
    .min = 200,
    .max = 600,
    .step = 10,
    .unit = " gold",
    .answer = 481,
    .real = "a kill, over 2,788,670 kills",
    .bars = &.{
        .{ .label = "Your team 3k+ behind", .v = 481, .n = 2_788_670, .hi = true },
        .{ .label = "1k-3k behind", .v = 390, .n = 1_974_057 },
        .{ .label = "Within 1k", .v = 330, .n = 2_599_521 },
        .{ .label = "1k-3k ahead", .v = 308, .n = 2_386_102 },
        .{ .label = "3k+ ahead", .v = 294, .n = 4_519_167 },
    },
    .bar_unit = " gold",
    .per = "kills",
    .why = "Bounties: 37% of kills by a team 3k+ behind pay over 450 gold, against none " ++
        "by a team 3k+ ahead. The same at every rank.",
    .tip = "Behind? Fights pay you more: hunt the enemy with a bounty.",
    .from = all_regions ++ ", 290,807 games, kills from 10:00",
};

/// research/raw/coach-objectives-measured.md: taking team's win rate minus its chance
/// at the start of that minute (236,227 games)
const objectives: Puzzle = .{
    .id = "objectives",
    .topic = "Objectives",
    .q = "Which goes with the biggest rise in a team's chance to win?",
    .kind = .pick,
    .answer = 2,
    .choices = &.{
        .{ .t = "Rift Herald" },
        .{ .t = "A void grub" },
        .{ .t = "First dragon" },
        .{ .t = "A side lane outer tower before 14:00" },
    },
    .real = "First dragon: the taking team won 6.2 points more often than its chance just " ++
        "before, over 236,046 takes",
    .bars = &.{
        .{ .label = "First dragon", .v = 6.2, .n = 236_046, .hi = true },
        .{ .label = "Side outer tower, before 14", .v = 2.2, .n = 160_516 },
        .{ .label = "A void grub", .v = 1.7, .n = 707_794 },
        .{ .label = "Rift Herald", .v = 1.5, .n = 204_835 },
    },
    .bar_unit = " points",
    .per = "takes",
    .why = "Win rate after the take minus the chance just before, from gold, levels, " ++
        "objectives and the draft. Herald comes last.",
    .tip = "Early on, first dragon is the objective to plan your recalls around.",
    .from = all_regions ++ ", 236,227 games",
};

/// research/raw/first-8-minutes-measured.md (290,807 games); kills per game-minute
const gank: Puzzle = .{
    .id = "gank",
    .topic = "The first minutes",
    .q = "In the first five minutes, when do the most kills happen?",
    .kind = .pick,
    .answer = 2,
    .choices = &.{
        .{ .t = "1:00-1:30" },
        .{ .t = "2:00-2:30" },
        .{ .t = "3:00-3:30" },
        .{ .t = "4:30-5:00" },
    },
    .real = "3:00-3:30: 297,408 kills in 290,807 games, 2.05 a game-minute",
    .bars = &.{
        .{ .label = "1:00-1:30", .v = 80_270, .n = 290_807 },
        .{ .label = "2:00-2:30", .v = 229_593, .n = 290_807 },
        .{ .label = "3:00-3:30", .v = 297_408, .n = 290_807, .hi = true },
        .{ .label = "4:30-5:00", .v = 206_098, .n = 290_807 },
    },
    .bar_unit = " kills",
    .why = "The junglers' first ganks: 90,754 jungler kills in those 30 seconds alone, " ++
        "more than in any other half minute.",
    .tip = "Around 3:00, ward the river or stand behind your minions.",
    .from = all_regions ++ ", 290,807 games",
};

/// research/raw/split-pusher-rank-measured.md (363,927 games, top laners)
const splitpush: Puzzle = .{
    .id = "splitpush",
    .topic = "Myths",
    .q = "A popular video says split pushing wins 55.6%. Yorick, Fiora, Jax, Tryndamere, " ++
        "Nasus and Trundle in top lane win how often, against other top laners?",
    .kind = .pick,
    .answer = 1,
    .choices = &.{
        .{ .t = "Clearly more" },
        .{ .t = "About the same" },
        .{ .t = "Clearly less" },
    },
    .real = "About the same: 49.9% of 75,481 games, every top laner 50.0% of 618,586",
    .bars = &.{
        .{ .label = "The six split pushers", .v = 49.9, .n = 75_481, .hi = true },
        .{ .label = "Every top laner", .v = 50.0, .n = 618_586 },
        .{ .label = "Yorick", .v = 48.9, .n = 10_175 },
    },
    .why = "The 55.6% was Yorick's win rate in Iron. From Platinum up, no rank shows " ++
        "split pushers ahead.",
    .tip = "A win rate means little until you know its rank and champion.",
    .from = all_regions ++ ", 363,927 games",
};

/// docs/learned.md Player, 15 Oct (src/spread.zig)
const luck: Puzzle = .{
    .id = "luck",
    .topic = "Luck",
    .q = "Of players with 10+ games on a champion, the middle half win between 46% and " ++
        "64%. How much of that spread is skill?",
    .kind = .pick,
    .answer = 2,
    .choices = &.{ .{ .t = "Most of it" }, .{ .t = "About half" }, .{ .t = "Almost none" } },
    .real = "Almost none, over 6,952 players with 10+ games on a champion",
    .why = "Over 10 to 20 games, chance alone moves a win rate about 15 points. Beyond " ++
        "that, no real difference between players showed: at most about 3 points.",
    .tip = "A bad 10 games on a champion is mostly luck: don't drop it yet.",
    .from = "Ranked solo, Platinum IV and up, EUW, every patch crawled",
};

/// Hand-written ones in order; the lane puzzle goes after fed_role
const fixed = [_]Puzzle{ know, newcomer, fed, fed_role, surrender, bounty, objectives, gank, splitpush, luck };

const lane_min_games = 300;
/// A matchup counts as one-sided in lane from this share of games led at 14
const lane_lead_share = 0.6;
/// The lane leader's win rate must sit this far below even, and 2 standard errors
const lane_min_gap = 0.05;

/// "Ahead in lane, so wins?": the matchup whose usual lane leader most clearly loses
/// the game, from the all-ranks lane curves
fn lanePuzzle(site: *const Site) !?Puzzle {
    const curves = site.curves orelse return null;
    const Best = struct { lead: Champ, other: Champ, r: Role, led: f64, won: f64, games: u32, wins: u32 };
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
            .wins = wins,
        };
    }
    const b = best orelse return null;
    const a = site.arena;
    const led_pct = @round(100 * b.led);
    const won_pct = @round(100 * b.won);
    const lane = switch (b.r) {
        .top => "top lane",
        .jungle => "the jungle",
        .middle => "mid lane",
        .bottom => "bot lane",
        .utility => "bot lane as supports",
    };
    // By name, so the answer is not always the same button
    const other_first = std.mem.lessThan(u8, b.other.name, b.lead.name);
    const lead_choice: Choice = .{ .t = b.lead.name, .icon = try site.icon(b.lead) };
    const other_choice: Choice = .{ .t = b.other.name, .icon = try site.icon(b.other) };
    const choices = try a.dupe(Choice, if (other_first)
        &.{ other_choice, lead_choice }
    else
        &.{ lead_choice, other_choice });
    const bars = try a.dupe(Bar, &.{
        .{ .label = try a.print("{s} ahead at 14", .{b.lead.name}), .v = led_pct, .n = b.games },
        .{ .label = try a.print("{s} won", .{b.lead.name}), .v = won_pct, .n = b.games },
        .{ .label = try a.print("{s} won", .{b.other.name}), .v = 100 - won_pct, .n = b.games, .hi = true },
    });
    return .{
        .id = "lane",
        .topic = "Lane and game",
        .q = try a.print("{s} against {s} in {s}: {s} is ahead in gold at 14 minutes in " ++
            "{d:.0}% of games. Who wins more of these games?", .{
            b.lead.name, b.other.name, lane, b.lead.name, led_pct,
        }),
        .kind = .pick,
        .answer = if (other_first) 0 else 1,
        .choices = choices,
        .real = try a.print("{s} won {d:.0}% of {d} games", .{ b.other.name, 100 - won_pct, b.games }),
        .bars = bars,
        .why = try a.print("{s} wins the lane, {s} the game. Across matchups, the side " ++
            "usually ahead at 14 is not the side that usually wins.", .{ b.lead.name, b.other.name }),
        .tip = "Losing lane is not losing the game: against an early champion, play for later.",
        .from = try a.print("This patch's ranked games, all ranks, {s}", .{lane}),
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

/// "Early or late?": does winning lane win the game? From `meiolol lean`
fn leanPuzzles(site: *const Site) ![]const Puzzle {
    const file = site.lean orelse return &.{};
    const a = site.arena;
    // An off-role pick with a few hundred games is no hook: 1 in 100 games, about 13k
    // over 30 days
    const rows = try leanRows(a, file.rows, file.games / 100);
    var enough: u32 = 0;
    var clear: u32 = 0;
    for (file.rows) |r| {
        if (!r.enough()) continue;
        enough += 1;
        if (r.lean() != .none) clear += 1;
    }
    const from = try a.print("Ranked games, {s}, games still going at {d} minutes", .{
        file.scope, lean.win_minute,
    });
    var out: std.ArrayList(Puzzle) = .empty;
    for (rows, 0..) |r, i| {
        const c = matchup.champ(site, r.champion) orelse continue;
        const gold: root.Thousands = .{ .n = @trunc(@round(@abs(r.gold) / 10) * 10) };
        const pts: i64 = @max(1, @as(i64, @trunc(@round(@abs(r.win)))));
        const early = r.lean() == .early;
        const told = try a.print("{s}'s team was {f} gold {s} at {d} minutes, and won {d} " ++
            "points {s} often from an even game at {d}", .{
            c.name,           gold, if (early) "ahead" else "behind",
            lean.gold_minute, pts,  if (early) "less" else "more",
            lean.win_minute,
        });
        const games = try a.print(", over {f} games", .{root.Thousands{ .n = r.games }});
        if (i == 0) {
            try out.append(a, .{
                .id = "lean-hook",
                .topic = "Lane and game",
                .q = try a.print("With {s} {s}, the team is usually {f} gold ahead at {d} " ++
                    "minutes. From an even game at {d}, does it win more or less often than " ++
                    "with an average {s}?", .{
                    c.name, inRole(r.role), gold, lean.gold_minute, lean.win_minute, roleNoun(r.role),
                }),
                .kind = .pick,
                .answer = 1,
                .choices = &.{ .{ .t = "More often" }, .{ .t = "Less often" } },
                .real = try a.print("Less: {s}{s}", .{ told, games }),
                .why = try a.print("Early champions win lanes, not long games. {d} of {d} " ++
                    "champion-roles lean clearly early or late.", .{ clear, enough }),
                .tip = "Ahead with an early champion? Spend the lead before 20 minutes.",
                .from = from,
            });
            continue;
        }
        try out.append(a, .{
            .id = try a.print("lean-{d}-{t}", .{ r.champion, r.role }),
            .topic = "Lane and game",
            .q = try a.print("{s} {s}: does the team lean early or late?", .{ c.name, inRole(r.role) }),
            .kind = .pick,
            .answer = if (early) 0 else 1,
            .choices = &.{ .{ .t = "Early: ahead at 14 minutes" }, .{ .t = "Late: wins more from even at 20" } },
            .real = try a.print("{s}: {s}{s}", .{ if (early) "Early" else "Late", told, games }),
            .why = if (early)
                "Its lead comes early; in a long, even game the other team is stronger."
            else
                "Behind at 14, but in a long, even game its team is the stronger one.",
            .tip = if (early)
                try a.print("Against {s}, play safe early: an even game at 20 is better " ++
                    "than usual for you.", .{c.name})
            else
                try a.print("Against {s}, end it early: take objectives before 20 minutes.", .{c.name}),
            .from = from,
        });
    }
    return out.items;
}

/// Every puzzle in play order
pub fn list(site: *const Site) ![]const Puzzle {
    var out: std.ArrayList(Puzzle) = .empty;
    for (fixed) |p| {
        try out.append(site.arena, p);
        if (std.mem.eql(u8, p.id, fed_role.id)) {
            if (try lanePuzzle(site)) |l| try out.append(site.arena, l);
            try out.appendSlice(site.arena, try leanPuzzles(site));
        }
    }
    return out.items;
}

/// The puzzles as text for readers without script: question, then the answer folded
pub fn write(w: *Writer, puzzles: []const Puzzle) !void {
    try w.writeAll("<ol class=\"pz-list nojs\">\n");
    for (puzzles) |p| {
        try tpl.render(w,
            \\<li class="card"><p class="muted small">{topic}</p><p><b>{q}</b></p>
            \\<details><summary>Answer</summary><p>{real}. {why}</p><p class="pz-tip">{tip}</p>
            \\</details></li>
            \\
        , .{ .topic = p.topic, .q = p.q, .real = p.real, .why = p.why, .tip = p.tip });
    }
    try w.writeAll("</ol>\n");
}

test "puzzles have an answer in range, games on every bar and no pick advice" {
    for (fixed) |p| {
        switch (p.kind) {
            .guess => try std.testing.expect(p.answer >= p.min and p.answer <= p.max),
            .pick => try std.testing.expect(p.answer < @as(f64, @floatFromInt(p.choices.len))),
        }
        for (p.bars) |b| try std.testing.expect(b.n > 0);
        for ([_][]const u8{ p.q, p.real, p.why, p.tip }) |text| {
            for ([_][]const u8{ "best", "Best" }) |word| {
                try std.testing.expect(std.mem.find(u8, text, word) == null);
            }
        }
    }
}

test leanRows {
    const row = struct {
        fn f(champion: u32, role: Role, games: u32, gold: f64, win: f64) lean.Row {
            return .{ .champion = champion, .role = role, .games = games, .gold = gold, .gold_sd = 50, .win = win, .win_sd = 1 };
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
