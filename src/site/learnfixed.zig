//! Learn's hand-written puzzles in ui.learndata's shape (docs/plan/ui/learn.md "Questions:
//! short, the setup as a picture"): finished checks (docs/learned.md, research/questions/
//! coach-stat-claims.md, the 20 Oct mastery bands). Edit here by hand; a deploy makes a
//! change live (learn.html is rendered on request). Chapters 3 and 4 come from this
//! patch's games (learnbuild.zig)
const ld = @import("ui").learndata;

const mastery_from = "Ranked solo, Platinum IV and up, every region, 1.92M player-games " ++
    "with mastery points before the game (snapshot of 18 Oct)";
const fed_from = "Ranked solo, Platinum IV and up, every region, patches 16.19-16.20, " ++
    "65,240 games of 15+ minutes";
const all_regions = "Ranked solo, Platinum IV and up, every region, patches 16.19-16.20";

fn ch(comptime key: []const u8, comptime n: []const u8) ld.Champ {
    return .{ .key = key, .name = n };
}

pub const know: ld.Puzzle = .{
    .id = "know",
    .q = "How often do mains win?",
    .ctx = "Mastery points on the champion, before the game",
    .setup = .{ .rates = .{ .ask = 1, .rows = &.{
        .{ .label = "New", .sub = "under 10k", .v = 47.7, .games = 207_598 },
        .{ .label = "Main", .sub = "300k+", .v = 51.7, .games = 508_609 },
    } } },
    .answer = .{ .guess = .{ .lo = 40, .hi = 60, .real = 51.7 } },
    .reveal = &.{
        .{ .label = "<10k", .sub = "New", .v = 47.7, .games = 207_598 },
        .{ .label = "10-30k", .v = 48.7, .games = 262_918 },
        .{ .label = "30-100k", .v = 49.5, .games = 486_889 },
        .{ .label = "100-300k", .v = 50.6, .games = 457_460 },
        .{ .label = "300k+", .sub = "Main", .v = 51.7, .games = 508_609 },
    },
    .why = "New to main: +4 points. A typical top lane counter is 2.5.",
    .tip = "Counter-pick with a champion you already know.",
    .games = 508_609,
    .from = mastery_from,
};

pub const newcomer: ld.Puzzle = .{
    .id = "newcomer",
    .q = "New players struggle most on...?",
    .ctx = "New: under 30k mastery points; practised: 100k+",
    .setup = .{ .chips = .{ .champs = &.{ ch("Vayne", "Vayne"), ch("Rengar", "Rengar") }, .chips = &.{ "Vayne bot", "Rengar jungle" } } },
    .answer = .{ .pick = .{ .right = 1, .choices = &.{
        .{ .text = "Vayne", .champ = ch("Vayne", "Vayne"), .shown = "54.6% new, 49.7% practised", .games = 5_613 },
        .{ .text = "Rengar", .champ = ch("Rengar", "Rengar"), .shown = "39.4% new, 50.7% practised", .games = 5_141 },
    } } },
    .why = "Vayne's new players did no worse; Rengar's lost 11 points: hard to master is not hard to start.",
    .tip = "Learn a champion like Rengar in normal games before ranked.",
    .games = 10_754,
    .from = mastery_from,
};

pub const fed: ld.Puzzle = .{
    .id = "fed",
    .q = "How often does your team win?",
    .ctx = "You: 1,000+ gold up at 14. The other four: behind",
    .setup = .{ .chips = .{ .champs = &.{}, .chips = &.{ "You +1,000 at 14", "Other four behind" } } },
    .answer = .{ .guess = .{ .lo = 20, .hi = 80, .real = 47.3, .tol = 2 } },
    .reveal = &.{
        .{ .label = "Other four", .sub = "3k+ behind", .v = 27.6, .games = 16_328 },
        .{ .label = "1.5-3k behind", .v = 46.6, .games = 18_349 },
        .{ .label = "0-1.5k behind", .v = 60.7, .games = 25_119 },
        .{ .label = "0-1.5k ahead", .v = 73.0, .games = 26_488 },
        .{ .label = "1.5k+ ahead", .v = 89.1, .games = 56_450 },
    },
    .why = "A fed laner wins 68.6% overall, but that rides on the other four.",
    .tip = "Ahead in lane? Take your lead to where your team is losing.",
    .games = 59_796,
    .from = fed_from,
};

pub const fed_role: ld.Puzzle = .{
    .id = "fed-role",
    .q = "Whose lead wins more?",
    .ctx = "1,000+ gold up at 14, the other four behind",
    .setup = .{ .chips = .{ .champs = &.{}, .chips = &.{ "Top +1,000", "Bot +1,000" } } },
    .answer = .{ .pick = .{ .right = 1, .choices = &.{
        .{ .text = "Top", .role = .top, .shown = "44.6%", .games = 17_476 },
        .{ .text = "Bot", .role = .bot, .shown = "50.4%", .games = 14_808 },
    } } },
    .why = "Early fights happen around dragon, next to bot lane; a top lead stays far away.",
    .tip = "Ahead in top lane? Bring the lead to the map: teleport, roam, take towers.",
    .games = 32_284,
    .from = fed_from,
};

pub const surrender: ld.Puzzle = .{
    .id = "ff15",
    .q = "How often does it still win?",
    .ctx = "5,000 gold behind at 15 minutes, someone types /ff",
    .setup = .{ .chips = .{ .champs = &.{}, .chips = &.{ "−5,000 gold at 15", "/ff" } } },
    .answer = .{ .guess = .{ .lo = 0, .hi = 50, .real = 13.0, .tol = 2 } },
    .reveal = &.{
        .{ .label = "At 10 min", .v = 7.2, .games = 6_217 },
        .{ .label = "At 15 min", .v = 13.0, .games = 20_888 },
        .{ .label = "At 20 min", .v = 15.2, .games = 20_677 },
        .{ .label = "At 25 min", .v = 16.0, .games = 16_934 },
        .{ .label = "At 30 min", .v = 17.4, .games = 10_267 },
    },
    .why = "1 game in 8. The same 5k matters less later: a game holds more gold.",
    .tip = "5k down at 15 is not over: play for the next fight, not the vote.",
    .games = 20_888,
    .from = all_regions ++ ", 239,629 games still going at that minute",
};

pub const bounty: ld.Puzzle = .{
    .id = "bounty",
    .q = "Behind by 3,000+: what does a kill pay?",
    .setup = .{ .chips = .{ .champs = &.{}, .chips = &.{"A kill: ~300 gold"} } },
    .answer = .{ .guess = .{ .lo = 200, .hi = 600, .step = 10, .unit = .gold, .real = 481, .tol = 20 } },
    .why = "Bounties: 37% of kills by a team 3k+ behind pay over 450 gold.",
    .tip = "Behind? Fights pay you more: hunt the enemy with a bounty.",
    .games = 290_807,
    .from = all_regions ++ ", 290,807 games, kills from 10:00",
};

pub const splitpush: ld.Puzzle = .{
    .id = "splitpush",
    .q = "Do split pushers win more?",
    .ctx = "Yorick, Fiora, Jax, Tryndamere, Nasus, Trundle in top lane",
    .setup = .{ .chips = .{ .champs = &.{ ch("Yorick", "Yorick"), ch("Fiora", "Fiora"), ch("Jax", "Jax"), ch("Tryndamere", "Tryndamere"), ch("Nasus", "Nasus"), ch("Trundle", "Trundle") }, .chips = &.{"A video: 55.6%"} } },
    .answer = .{ .pick = .{ .right = 1, .choices = &.{
        .{ .text = "Clearly more" },
        .{ .text = "About the same", .shown = "49.9%", .games = 75_481 },
        .{ .text = "Clearly less" },
    } } },
    .why = "The 55.6% was Yorick in Iron. From Platinum up, no rank shows them ahead.",
    .tip = "A win rate means little until you know its rank and champion.",
    .games = 75_481,
    .from = all_regions ++ ", 363,927 games",
};

pub const luck: ld.Puzzle = .{
    .id = "luck",
    .q = "How much of that spread is skill?",
    .ctx = "Players with 10+ games on a champion: the middle half win 46% to 64%",
    .setup = .{ .chips = .{ .champs = &.{}, .chips = &.{ "46%", "64%" } } },
    .answer = .{ .pick = .{ .right = 2, .choices = &.{ .{ .text = "Most of it" }, .{ .text = "About half" }, .{ .text = "Almost none" } } } },
    .why = "Over 10 to 20 games, chance alone moves a win rate about 15 points.",
    .tip = "A bad 10 games on a champion is mostly luck: don't drop it yet.",
    .games = 6_952,
    .from = "Ranked solo, Platinum IV and up, EUW, every patch crawled",
};

pub const chapter1 = [_]ld.Puzzle{ know, newcomer };
pub const chapter2 = [_]ld.Puzzle{ fed, fed_role, surrender, bounty };
pub const chapter5 = [_]ld.Puzzle{ splitpush, luck };
