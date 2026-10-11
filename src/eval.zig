//! `meiolol eval`: how well the draft model predicts games it has not seen.
//!
//! Time split: the newest games are held out (test), models are built only from older
//! ones (train). Never a random split: games days apart share patch and meta, so a random
//! split flatters every model. Options are tuned by k-fold inside train only.
//!
//! Reports, as markdown on stdout (results go to docs/model.md):
//! - full draft: blue side's win chance; log loss, Brier, AUC, accuracy, calibration
//! - pick: hide one pick, rank the champion actually picked among every candidate; if
//!   the model knows good picks, winners' picks rank higher than losers'
//! - role inference: share of hidden-role champions placed in their real role
//! - learning curve: the same test games, models from the newest N train games

const std = @import("std");
const store = @import("store");
const core = @import("core");
const stats = @import("stats.zig");
const logreg = @import("logreg.zig");
const lanegold = @import("lanegold.zig");
const experience = @import("experience.zig");
const score = core.score;
const Role = core.Role;

pub const Options = struct {
    /// Newest share of games held out
    test_share: f64 = 0.2,
    folds: u32 = 5,
    /// Pick metric candidates: champions with at least this many train games in the role
    pick_min_games: u32 = 10,
    /// Test only on this platform's games (train still uses every platform scanned),
    /// and compare with training on this platform alone
    test_platform: ?[]const u8 = null,
};

const Game = stats.Row;

/// Prior strengths tried by the tuning grid; the last means "no pair terms"
const prior_grid = [_]f64{ 50, 100, 200, 400, 800, 1600, 3200, 6400, 1e9 };

/// Cells with fewer games are left out of the empirical-Bayes estimate
const eb_min_games = 30;

pub fn run(
    gpa: std.mem.Allocator,
    db: store.Db,
    patches: []const []const u8,
    platforms: []const []const u8,
    opts: Options,
    w: *std.Io.Writer,
) !History {
    const champs = try stats.champions(gpa, db);
    defer stats.freeChampions(gpa, champs);
    var list: GameList = .{ .gpa = gpa };
    defer list.items.deinit(gpa);
    const summary = try stats.scan(gpa, db, patches, platforms, &list);
    const games = list.items.items;
    std.mem.sort(Game, games, {}, olderFirst);

    // Test: the newest share of the test platform's games; train: every older game
    const test_platform: ?u8 = if (opts.test_platform) |tp| for (platforms, 0..) |p, i| {
        if (std.mem.eql(u8, p, tp)) break @intCast(i);
    } else return error.TestPlatformNotScanned else null;
    var tests_list: std.ArrayList(Game) = .empty;
    defer tests_list.deinit(gpa);
    var pool: usize = 0;
    for (games) |g| pool += @intFromBool(test_platform == null or g.platform == test_platform.?);
    const n_test: usize = @intFromFloat(@round(@as(f64, @floatFromInt(pool)) * opts.test_share));
    if (games.len < 100 or n_test < 20) return error.TooFewGames;
    var at = games.len;
    while (tests_list.items.len < n_test) {
        at -= 1;
        const g = games[at];
        if (test_platform == null or g.platform == test_platform.?) try tests_list.append(gpa, g);
    }
    std.mem.reverse(Game, tests_list.items);
    const tests = tests_list.items;
    var n_train: usize = 0;
    while (games[n_train].start < tests[0].start) n_train += 1;
    const train = games[0..n_train];

    try w.print("# meiolol eval\n\n{d} games ({d} skipped) on {d} patch(es), ", .{
        games.len, summary.skipped, patches.len,
    });
    for (platforms, 0..) |p, i| try w.print("{s}{s}", .{ if (i > 0) "," else "", p });
    if (opts.test_platform) |tp| try w.print(", tested on {s} only", .{tp});
    try w.print(". Train: oldest {d} ({f} to {f}). ", .{
        train.len, Day{ .ms = train[0].start }, Day{ .ms = train[train.len - 1].start },
    });
    try w.print("Test: newest {d} ({f} to {f}).\n\n", .{
        tests.len, Day{ .ms = tests[0].start }, Day{ .ms = tests[tests.len - 1].start },
    });

    const tuned = try tune(gpa, champs, train, opts.folds, w);

    var full: Model = try .build(gpa, champs, train, null);
    defer full.deinit(gpa);

    var blue_wins: f64 = 0;
    for (train) |g| blue_wins += @floatFromInt(1 - @as(u2, g.winner));
    const blue_rate = blue_wins / @as(f64, @floatFromInt(train.len));

    const current: score.Options = .{};
    const base_only: Predictor = .{ .label = "champion base only", .kind = .{ .base = current } };
    const model: Predictor = .{ .label = "current model", .kind = .{ .model = current } };
    const tuned_priors: Predictor = .{ .label = "tuned priors", .kind = .{ .model = tuned.opts } };
    const weighted: Predictor = .{ .label = "tuned + term weights", .kind = .{ .weighted = .{
        .opts = tuned.opts,
        .w = tuned.weights,
    } } };
    const empirical: Predictor = .{ .label = "empirical-Bayes priors", .kind = .empirical };
    const joint_w = try fitJoint(gpa, &full.stats, train, tuned.joint_l2);
    defer gpa.free(joint_w);
    const joint: Predictor = .{ .label = "joint ratings (logistic)", .kind = .{ .joint = joint_w } };
    const predictors = [_]Predictor{
        .{ .label = "coin flip (50%)", .kind = .coin },
        .{ .label = "blue side rate", .kind = .{ .side = blue_rate } },
        base_only,
        model,
        tuned_priors,
        weighted,
        empirical,
        joint,
    };
    const eb = score.empiricalPriors(&full.stats, eb_min_games);
    try w.print("## Full draft, held-out games\n\nEmpirical-Bayes priors from train (cells " ++
        "with {d}+ games): base {f}, duo {f}, lane {f}, other matchups {f}.\n\n", .{
        eb_min_games,
        Prior{ .games = eb.base },
        Prior{ .games = eb.duo },
        Prior{ .games = eb.lane },
        Prior{ .games = eb.matchup },
    });
    try fullDraft(gpa, &full.stats, tests, &predictors, 3, w);

    try w.print("\nCalibration by decile of prediction, {s}:\n\n", .{empirical.label});
    try calibration(gpa, &full.stats, tests, empirical, w);

    // Default stats file today: newest patch only
    const newest = tests[tests.len - 1].patch;
    var same_patch: std.ArrayList(Game) = .empty;
    defer same_patch.deinit(gpa);
    for (train) |g| if (g.patch == newest) try same_patch.append(gpa, g);
    if (same_patch.items.len > 0 and same_patch.items.len < train.len) {
        var sp: Model = try .build(gpa, champs, same_patch.items, null);
        defer sp.deinit(gpa);
        try w.print("\nTrained on the test games' patch only ({d} games, as `meiolol stats` " ++
            "does by default), test games of that patch:\n\n", .{same_patch.items.len});
        var tests_np: std.ArrayList(Game) = .empty;
        defer tests_np.deinit(gpa);
        for (tests) |g| if (g.patch == newest) try tests_np.append(gpa, g);
        const subset = [_]Predictor{ base_only, model, tuned_priors, empirical };
        try fullDraft(gpa, &sp.stats, tests_np.items, &subset, 1, w);
        try w.writeAll("\nSame test games, trained on every patch:\n\n");
        try fullDraft(gpa, &full.stats, tests_np.items, &subset, 1, w);
    }

    if (test_platform) |tp| {
        var own: std.ArrayList(Game) = .empty;
        defer own.deinit(gpa);
        for (train) |g| if (g.platform == tp) try own.append(gpa, g);
        if (own.items.len > 0 and own.items.len < train.len) {
            var m: Model = try .build(gpa, champs, own.items, null);
            defer m.deinit(gpa);
            const subset = [_]Predictor{ base_only, model, empirical };
            try w.print("\nTrained on {s} games only ({d}):\n\n", .{ platforms[tp], own.items.len });
            try fullDraft(gpa, &m.stats, tests, &subset, 1, w);
            try w.print("\nTrained on every platform ({d}):\n\n", .{train.len});
            try fullDraft(gpa, &full.stats, tests, &subset, 1, w);
        }
    }

    const gold = try laneGoldSection(gpa, db, patches, platforms, champs, &full.stats, train, tests, opts.folds, &.{
        base_only, model, empirical, joint,
    }, w);

    try experienceSection(gpa, db, platforms, champs, &full.stats, train, tests, opts.folds, w);

    var line: History = .{
        .platforms = platforms.len,
        .test_platform = opts.test_platform orelse "",
        .games = games.len,
        .train = train.len,
        .tests = tests.len,
        .gold = gold,
    };
    for ([_]Predictor{ predictors[0], base_only, model, empirical, joint }, &line.results) |p, *out| {
        const r = try evaluate(gpa, &full.stats, tests, p);
        defer gpa.free(r.p);
        out.* = .{ .log_loss = r.m.log_loss, .auc = r.m.auc };
    }

    try w.writeAll("\n## Pick metric\n\n");
    try w.writeAll("Each held-out pick hidden in turn, the other nine known with roles; " ++
        "percentile of the champion actually picked among candidates (1 = model's top).\n\n");
    try w.writeAll("| model | picks ranked | winners' mean pct | losers' mean pct | " ++
        "AUC pct vs win | win rate, picks in model's top 10% |\n| --- | --- | --- | --- | --- | --- |\n");
    for ([_]Predictor{ model, tuned_priors, empirical }) |p| {
        try pickMetric(gpa, &full.stats, tests, p, opts.pick_min_games, w);
    }

    try w.writeAll("\n## Role inference\n\n");
    try roleInference(&full.stats, tests, w);

    try w.writeAll("\n## Learning curve\n\nSame test games, models from the newest N train games.\n\n");
    try w.writeAll("Log loss, and AUC for empirical Bayes:\n\n| train games | base only | " ++
        "current | tuned priors | tuned + weights | empirical Bayes | joint ratings | AUC (EB) |\n");
    try w.writeAll("| --- | --- | --- | --- | --- | --- | --- | --- |\n");
    var size: usize = 250;
    while (true) : (size *= 2) {
        const n = @min(size, train.len);
        const subset = train[train.len - n ..];
        var m: Model = try .build(gpa, champs, subset, null);
        defer m.deinit(gpa);
        const jw = try fitJoint(gpa, &m.stats, subset, tuned.joint_l2);
        defer gpa.free(jw);
        try w.print("| {d} |", .{n});
        var eb_auc: f64 = 0;
        for ([_]Predictor{ base_only, model, tuned_priors, weighted, empirical, .{
            .label = "joint",
            .kind = .{ .joint = jw },
        } }) |p| {
            const r = try evaluate(gpa, &m.stats, tests, p);
            defer gpa.free(r.p);
            try w.print(" {d:.4} |", .{r.m.log_loss});
            if (p.kind == .empirical) eb_auc = r.m.auc;
        }
        try w.print(" {d:.3} |\n", .{eb_auc});
        if (n == train.len) break;
    }
    return line;
}

const Result = struct { log_loss: f64, auc: f64 };

/// One run, for the history file (data/eval-history.tsv on the box, deploy/web-loop.sh)
pub const History = struct {
    platforms: usize,
    test_platform: []const u8,
    games: usize,
    train: usize,
    tests: usize,
    /// coin flip, base only, current, empirical Bayes, joint ratings
    results: [5]Result = undefined,
    /// EB + lane gold on the test games with timelines; null when too few
    gold: ?GoldResult,

    pub const header = "date\tplatforms\ttest_platform\tgames\ttrain\ttest\t" ++
        "ll_coin\tll_base\tll_current\tll_eb\tll_joint\t" ++
        "auc_base\tauc_current\tauc_eb\tauc_joint\t" ++
        "gold_test\tll_eb_gold_subset\tll_gold\tauc_gold\n";

    pub fn write(h: History, w: *std.Io.Writer, date: []const u8) !void {
        try w.print("{s}\t{d}\t{s}\t{d}\t{d}\t{d}", .{
            date, h.platforms, h.test_platform, h.games, h.train, h.tests,
        });
        for (h.results) |r| try w.print("\t{d:.5}", .{r.log_loss});
        for (h.results[1..]) |r| try w.print("\t{d:.4}", .{r.auc});
        if (h.gold) |g| {
            try w.print("\t{d}\t{d:.5}\t{d:.5}\t{d:.4}\n", .{ g.tests, g.eb_log_loss, g.log_loss, g.auc });
        } else try w.writeAll("\t0\t\t\t\n");
    }
};

pub const GoldResult = struct { tests: usize, eb_log_loss: f64, log_loss: f64, auc: f64 };

/// Appends `h` to the TSV at `path`, with a header when the file is new
pub fn appendHistory(io: std.Io, path: []const u8, h: History, date: []const u8) !void {
    var file = try std.Io.Dir.cwd().createFile(io, path, .{ .truncate = false });
    defer file.close(io);
    const len = try file.length(io);
    var buf: [1024]u8 = undefined;
    var fw = file.writer(io, &buf);
    try fw.seekTo(len);
    if (len == 0) try fw.interface.writeAll(History.header);
    try h.write(&fw.interface, date);
    try fw.interface.flush();
}

/// Fewer train games with lane gold and the section is skipped
const min_gold_games = 500;

/// Lane gold at 14 minutes (lanegold.zig) stacked with the draft's terms, on the test
/// games that have timelines
fn laneGoldSection(
    gpa: std.mem.Allocator,
    db: store.Db,
    patches: []const []const u8,
    platforms: []const []const u8,
    champs: []const core.statsfile.Champion,
    full: *const core.Stats,
    train: []const Game,
    tests: []const Game,
    folds: u32,
    others: []const Predictor,
    w: *std.Io.Writer,
) !?GoldResult {
    var map = try lanegold.load(gpa, db, patches, platforms);
    defer map.deinit(gpa);
    var train_gold: usize = 0;
    for (train) |g| train_gold += @intFromBool(map.contains(g.id));
    var tests_gold: std.ArrayList(Game) = .empty;
    defer tests_gold.deinit(gpa);
    for (tests) |g| if (map.contains(g.id)) try tests_gold.append(gpa, g);
    try w.print("\n## Lane gold at {d} minutes\n\nGames with a timeline: {d} of {d} train, {d} of " ++
        "{d} test.", .{ lanegold.minute, train_gold, train.len, tests_gold.items.len, tests.len });
    if (train_gold < min_gold_games or tests_gold.items.len < 100) {
        try w.print(" Too few (need {d} train, 100 test); skipped.\n", .{min_gold_games});
        return null;
    }

    // Out-of-fold features for the stack's weights
    var xs: std.ArrayList(Weights) = .empty;
    defer xs.deinit(gpa);
    var ys: std.ArrayList(f64) = .empty;
    defer ys.deinit(gpa);
    for (0..folds) |k| {
        var m: Model = try .build(gpa, champs, train, .{ .k = k, .folds = folds });
        defer m.deinit(gpa);
        var gm: lanegold.Model = try .build(gpa, &m.stats, train, &map, .{ .k = k, .folds = folds });
        defer gm.deinit(gpa);
        const o = score.empiricalPriors(&m.stats, eb_min_games).apply(.{});
        for (train, 0..) |g, i| if (i % folds == k and map.contains(g.id)) {
            try xs.append(gpa, goldFeatures(&m.stats, o, &gm, g));
            try ys.append(gpa, blueWon(g));
        };
    }
    const weights = fitLogistic(xs.items, ys.items, 1.0);

    var gm: lanegold.Model = try .build(gpa, full, train, &map, null);
    defer gm.deinit(gpa);
    const o = score.empiricalPriors(full, eb_min_games).apply(.{});
    try w.print(" Gold sd by role (top..support):", .{});
    for (gm.sd) |sd| try w.print(" {d:.0}", .{sd});
    try w.writeAll("; prior games, champion:");
    for (gm.champ_prior) |k| try w.print(" {f}", .{Prior{ .games = k }});
    try w.writeAll(", pair:");
    for (gm.pair_prior) |k| try w.print(" {f}", .{Prior{ .games = k }});
    try w.print(". Stack weights (out-of-fold): intercept {d:.3}, base {d:.3}, lane winrate " ++
        "{d:.3}, champion gold {d:.3}, pair gold {d:.3}\n\n", .{
        weights[0], weights[1], weights[2], weights[3], weights[4],
    });

    var list: std.ArrayList(Predictor) = .empty;
    defer list.deinit(gpa);
    try list.appendSlice(gpa, others);
    try list.append(gpa, .{ .label = "EB + lane gold (stacked)", .kind = .{ .gold = .{
        .opts = o,
        .gm = &gm,
        .w = weights,
    } } });
    var gold_only = weights;
    gold_only[1] = 0;
    gold_only[2] = 0;
    try list.append(gpa, .{ .label = "lane gold terms only", .kind = .{ .gold = .{
        .opts = o,
        .gm = &gm,
        .w = gold_only,
    } } });
    try fullDraft(gpa, full, tests_gold.items, list.items, 1, w);

    const eb = try evaluate(gpa, full, tests_gold.items, .{ .label = "", .kind = .empirical });
    defer gpa.free(eb.p);
    const stacked = try evaluate(gpa, full, tests_gold.items, list.items[others.len]);
    defer gpa.free(stacked.p);
    return .{
        .tests = tests_gold.items.len,
        .eb_log_loss = eb.m.log_loss,
        .log_loss = stacked.m.log_loss,
        .auc = stacked.m.auc,
    };
}

/// Fewer train or test games with a known player and a variant is skipped
const min_experience_train = 300;
const min_experience_test = 100;

const ExperienceSource = enum { history, mastery };

/// Player experience (experience.zig) as a term on top of the draft: every known player
/// (an upper bound) and one player per game (the user, all the app can know)
fn experienceSection(
    gpa: std.mem.Allocator,
    db: store.Db,
    platforms: []const []const u8,
    champs: []const core.statsfile.Champion,
    full: *const core.Stats,
    train: []const Game,
    tests: []const Game,
    folds: u32,
    w: *std.Io.Writer,
) !void {
    var map = try experience.load(gpa, db, platforms);
    defer map.deinit(gpa);
    try w.writeAll("\n## Player experience\n\nA term per experience bin on top of the draft's " ++
        "base and lane terms (out-of-fold, empirical-Bayes priors), against the same model " ++
        "without it, on test games with a known player. Effects in percentage points vs a " ++
        "player of unknown experience, in an otherwise even game. History bins are game " ++
        "numbers on the champion (1-5, 6-20, 21-50, 51+, crawled history only); mastery bins " ++
        "points (<10k, 10-50k, 50-200k, 200k+; snapshot after the match, so flattering).\n\n");

    const oof = try oofTerms(gpa, champs, train, folds);
    defer gpa.free(oof);
    const eb = score.empiricalPriors(full, eb_min_games).apply(.{});

    try w.writeAll("| source | players | train | test | log loss without | with | difference | " ++
        "AUC with | effect per bin (pp) |\n| --- | --- | --- | --- | --- | --- | --- | --- | --- |\n");
    for ([_]ExperienceSource{ .history, .mastery }) |source| for ([_]bool{ false, true }) |user_only| {
        try w.print("| {t} | {s} |", .{ source, if (user_only) "user only" else "all known" });
        var rows_with: std.ArrayList(logreg.Row) = .empty;
        defer rows_with.deinit(gpa);
        var rows_without: std.ArrayList(logreg.Row) = .empty;
        defer rows_without.deinit(gpa);
        for (train, oof) |g, t| {
            const e = map.get(g.id) orelse continue;
            const r = experienceRow(t, blueWon(g), e, source, user_only) orelse continue;
            try rows_with.append(gpa, r);
            try rows_without.append(gpa, experienceRow(t, blueWon(g), null, source, user_only).?);
        }
        var test_games: std.ArrayList(Game) = .empty;
        defer test_games.deinit(gpa);
        for (tests) |g| {
            const e = map.get(g.id) orelse continue;
            if (experienceRow(.{}, 0, e, source, user_only) != null) try test_games.append(gpa, g);
        }
        if (rows_with.items.len < min_experience_train or test_games.items.len < min_experience_test) {
            try w.print(" {d} | {d} | too few (need {d} and {d}) | | | | |\n", .{
                rows_with.items.len, test_games.items.len, min_experience_train, min_experience_test,
            });
            continue;
        }
        const d = 3 + @max(experience.history_bins, experience.mastery_bins);
        const ww = try logreg.fit(gpa, d, rows_with.items, 1);
        defer gpa.free(ww);
        const wo = try logreg.fit(gpa, d, rows_without.items, 1);
        defer gpa.free(wo);

        const p_with = try gpa.alloc(f64, test_games.items.len);
        defer gpa.free(p_with);
        const p_without = try gpa.alloc(f64, test_games.items.len);
        defer gpa.free(p_without);
        for (test_games.items, p_with, p_without) |g, *pw, *po| {
            const t = score.draftTerms(full, eb, g.teams);
            const e = map.get(g.id).?;
            pw.* = sigmoid(experienceRow(t, 0, e, source, user_only).?.dot(ww));
            po.* = sigmoid(experienceRow(t, 0, null, source, user_only).?.dot(wo));
        }
        const m_with = try metrics(gpa, p_with, test_games.items);
        const m_without = try metrics(gpa, p_without, test_games.items);
        const diff = pairedDiff(p_with, p_without, test_games.items);
        try w.print(" {d} | {d} | {d:.4} | {d:.4} | {s}{d:.4} ± {d:.4} | {d:.3} |", .{
            rows_with.items.len, test_games.items.len, m_without.log_loss, m_with.log_loss,
            if (diff.mean >= 0) "+" else "", diff.mean, diff.ci, m_with.auc,
        });
        const bins = switch (source) {
            .history => experience.history_bins,
            .mastery => experience.mastery_bins,
        };
        for (ww[3..][0..bins]) |b| try w.print(" {d:.1}", .{100 * (sigmoid(b) - 0.5)});
        try w.writeAll(" |\n");
    };
}

/// Draft terms of each train game from a model built without its fold, under the
/// fold model's empirical-Bayes priors
fn oofTerms(
    gpa: std.mem.Allocator,
    champs: []const core.statsfile.Champion,
    train: []const Game,
    folds: u32,
) ![]score.DraftTerms {
    const out = try gpa.alloc(score.DraftTerms, train.len);
    errdefer gpa.free(out);
    for (0..folds) |k| {
        var m: Model = try .build(gpa, champs, train, .{ .k = k, .folds = folds });
        defer m.deinit(gpa);
        const o = score.empiricalPriors(&m.stats, eb_min_games).apply(.{});
        for (train, out, 0..) |g, *t, i| if (i % folds == k) {
            t.* = score.draftTerms(&m.stats, o, g.teams);
        };
    }
    return out;
}

/// Features: intercept, base, lane, then one per experience bin (+1 blue, -1 red) for
/// the players in scope. Null when no player in scope has a known bin; `e` null for the
/// same row without experience
fn experienceRow(
    t: score.DraftTerms,
    y: f64,
    e: ?experience.Game,
    source: ExperienceSource,
    user_only: bool,
) ?logreg.Row {
    var r: logreg.Row = .{ .y = y };
    r.add(0, 1);
    r.add(1, t.base);
    r.add(2, t.lane);
    const game = e orelse return r;
    var known = false;
    for (game, 0..) |team, s| for (team) |p| {
        if (user_only and known) break;
        const bin = switch (source) {
            .history => p.history,
            .mastery => p.mastery,
        } orelse continue;
        r.add(3 + @as(u32, bin), if (s == 0) 1 else -1);
        known = true;
    };
    return if (known) r else null;
}

const Paired = struct { mean: f64, ci: f64 };

/// Mean per-game log loss of `a` minus `b`, with a 95% interval
fn pairedDiff(a: []const f64, b: []const f64, games: []const Game) Paired {
    var sum: f64 = 0;
    var sq: f64 = 0;
    for (a, b, games) |x, y, g| {
        const d = logLoss(x, blueWon(g)) - logLoss(y, blueWon(g));
        sum += d;
        sq += d * d;
    }
    const n: f64 = @floatFromInt(games.len);
    const mean = sum / n;
    return .{ .mean = mean, .ci = 1.96 * @sqrt(@max(sq / n - mean * mean, 0) / n) };
}

/// intercept, base and lane terms (opts), champion gold, pair gold
fn goldFeatures(st: *const core.Stats, opts: score.Options, gm: *const lanegold.Model, g: Game) Weights {
    const t = score.draftTerms(st, opts, g.teams);
    const f = gm.features(st, g.teams);
    return .{ 1, t.base, t.lane, f[0], f[1] };
}

/// Joint champion-role ratings: feature 0 the intercept (blue side), then one per
/// champion and role, +1 on blue, -1 on red
fn jointRow(st: *const core.Stats, g: Game) logreg.Row {
    var r: logreg.Row = .{ .y = blueWon(g) };
    r.add(0, 1);
    for (g.teams, 0..) |team, s| for (team, 0..) |id, role| {
        const c = st.index(id) orelse continue;
        r.add(@intCast(1 + role * st.n + c), if (s == 0) 1 else -1);
    };
    return r;
}

fn fitJoint(gpa: std.mem.Allocator, st: *const core.Stats, games: []const Game, l2: f64) ![]f64 {
    const rows = try gpa.alloc(logreg.Row, games.len);
    defer gpa.free(rows);
    for (rows, games) |*r, g| r.* = jointRow(st, g);
    return logreg.fit(gpa, 1 + Role.count * st.n, rows, l2);
}

const GameList = struct {
    gpa: std.mem.Allocator,
    items: std.ArrayList(Game) = .empty,

    pub fn add(l: *GameList, g: Game) !void {
        try l.items.append(l.gpa, g);
    }
};

fn olderFirst(_: void, a: Game, b: Game) bool {
    return a.start < b.start;
}

/// A stats file built in memory from some games
const Model = struct {
    bytes: []u8,
    stats: core.Stats,

    /// From `games`, leaving out fold `skip.k` of `skip.folds` (game index mod folds)
    fn build(
        gpa: std.mem.Allocator,
        champs: []const core.statsfile.Champion,
        games: []const Game,
        skip: ?Fold,
    ) !Model {
        var b: core.statsfile.Builder = try .init(gpa, champs);
        defer b.deinit();
        for (games, 0..) |g, i| {
            if (skip) |f| if (i % f.folds == f.k) continue;
            b.addGame(g.teams, g.winner);
        }
        var aw: std.Io.Writer.Allocating = .init(gpa);
        defer aw.deinit();
        try b.write(&aw.writer, "eval");
        const bytes = try aw.toOwnedSlice();
        errdefer gpa.free(bytes);
        return .{ .bytes = bytes, .stats = try .parse(gpa, bytes) };
    }

    fn deinit(m: *Model, gpa: std.mem.Allocator) void {
        m.stats.deinit(gpa);
        gpa.free(m.bytes);
    }
};

const Fold = struct { k: usize, folds: usize };

/// Logistic weights on a draft's terms: intercept (blue side), base, duo, lane, matchup
const Weights = [5]f64;

fn features(t: score.DraftTerms) Weights {
    return .{ 1, t.base, t.duo, t.lane, t.matchup };
}

const Predictor = struct {
    label: []const u8,
    kind: union(enum) {
        coin,
        side: f64,
        base: score.Options,
        model: score.Options,
        weighted: struct { opts: score.Options, w: Weights },
        /// The model with priors from score.empiricalPriors on the stats it is given
        empirical,
        /// Weights from fitJoint
        joint: []const f64,
        /// Draft terms plus lane gold, weighted (goldStack)
        gold: struct { opts: score.Options, gm: *const lanegold.Model, w: Weights },
    },

    /// Per stats file: empirical priors become concrete options
    fn on(p: Predictor, st: *const core.Stats) Predictor {
        if (p.kind != .empirical) return p;
        const priors = score.empiricalPriors(st, eb_min_games);
        return .{ .label = p.label, .kind = .{ .model = priors.apply(.{}) } };
    }

    fn predict(p: Predictor, st: *const core.Stats, g: Game) f64 {
        return switch (p.kind) {
            .empirical => unreachable,
            .joint => |jw| sigmoid(jointRow(st, g).dot(jw)),
            .gold => |x| sigmoid(dot(x.w, goldFeatures(st, x.opts, x.gm, g))),
            .coin => 0.5,
            .side => |rate| rate,
            .base => |o| sigmoid(score.draftTerms(st, o, g.teams).base),
            .model => |o| score.draftWin(st, o, g.teams),
            .weighted => |x| sigmoid(dot(x.w, features(score.draftTerms(st, x.opts, g.teams)))),
        };
    }
};

fn dot(a: Weights, b: Weights) f64 {
    var s: f64 = 0;
    for (a, b) |x, y| s += x * y;
    return s;
}

fn blueWon(g: Game) f64 {
    return if (g.winner == 0) 1 else 0;
}

const Metrics = struct {
    n: usize,
    log_loss: f64,
    brier: f64,
    auc: f64,
    accuracy: f64,
};

fn metrics(gpa: std.mem.Allocator, p: []const f64, games: []const Game) !Metrics {
    var m: Metrics = .{ .n = p.len, .log_loss = 0, .brier = 0, .auc = 0, .accuracy = 0 };
    for (p, games) |q, g| {
        const y = blueWon(g);
        m.log_loss += logLoss(q, y);
        m.brier += (q - y) * (q - y);
        if ((q > 0.5) == (y == 1) and q != 0.5) m.accuracy += 1;
        if (q == 0.5) m.accuracy += 0.5;
    }
    const n: f64 = @floatFromInt(p.len);
    m.log_loss /= n;
    m.brier /= n;
    m.accuracy /= n;
    m.auc = try auc(gpa, p, games);
    return m;
}

fn logLoss(q: f64, y: f64) f64 {
    const c = std.math.clamp(q, 1e-9, 1 - 1e-9);
    return -(y * @log(c) + (1 - y) * @log(1 - c));
}

/// Mann-Whitney: chance a random blue win scores above a random blue loss; ties half
fn auc(gpa: std.mem.Allocator, p: []const f64, games: []const Game) !f64 {
    const idx = try gpa.alloc(usize, p.len);
    defer gpa.free(idx);
    for (idx, 0..) |*x, i| x.* = i;
    std.mem.sort(usize, idx, p, struct {
        fn lt(ps: []const f64, a: usize, b: usize) bool {
            return ps[a] < ps[b];
        }
    }.lt);
    var rank_sum: f64 = 0;
    var pos: f64 = 0;
    var i: usize = 0;
    while (i < idx.len) {
        var j = i;
        while (j < idx.len and p[idx[j]] == p[idx[i]]) j += 1;
        const avg_rank = (@as(f64, @floatFromInt(i + j - 1)) / 2) + 1;
        for (idx[i..j]) |k| if (games[k].winner == 0) {
            rank_sum += avg_rank;
            pos += 1;
        };
        i = j;
    }
    const neg = @as(f64, @floatFromInt(p.len)) - pos;
    if (pos == 0 or neg == 0) return 0.5;
    return (rank_sum - pos * (pos + 1) / 2) / (pos * neg);
}

const Evaluated = struct { p: []f64, m: Metrics };

fn evaluate(gpa: std.mem.Allocator, st: *const core.Stats, games: []const Game, pr: Predictor) !Evaluated {
    const p = try gpa.alloc(f64, games.len);
    errdefer gpa.free(p);
    const concrete = pr.on(st);
    for (games, p) |g, *q| q.* = concrete.predict(st, g);
    return .{ .p = p, .m = try metrics(gpa, p, games) };
}

/// Table of metrics, plus each model's log loss difference to predictors[reference]
/// with a 95% interval from the paired per-game differences
fn fullDraft(
    gpa: std.mem.Allocator,
    st: *const core.Stats,
    games: []const Game,
    predictors: []const Predictor,
    reference: usize,
    w: *std.Io.Writer,
) !void {
    const ref = try evaluate(gpa, st, games, predictors[reference]);
    defer gpa.free(ref.p);
    try w.print("| model ({d} games) | log loss | Brier | AUC | accuracy | log loss vs {s} |\n", .{
        games.len, predictors[reference].label,
    });
    try w.writeAll("| --- | --- | --- | --- | --- | --- |\n");
    for (predictors) |pr| {
        const r = try evaluate(gpa, st, games, pr);
        defer gpa.free(r.p);
        try w.print("| {s} | {d:.4} | {d:.4} | {d:.3} | {d:.1}% | ", .{
            pr.label, r.m.log_loss, r.m.brier, r.m.auc, 100 * r.m.accuracy,
        });
        var sum: f64 = 0;
        var sq: f64 = 0;
        for (r.p, ref.p, games) |a, b, g| {
            const d = logLoss(a, blueWon(g)) - logLoss(b, blueWon(g));
            sum += d;
            sq += d * d;
        }
        const n: f64 = @floatFromInt(games.len);
        const mean = sum / n;
        const se = @sqrt(@max(sq / n - mean * mean, 0) / n);
        if (se == 0) try w.writeAll("- |\n") else {
            try w.print("{s}{d:.4} ± {d:.4} |\n", .{ if (mean >= 0) "+" else "", mean, 1.96 * se });
        }
    }
}

fn calibration(gpa: std.mem.Allocator, st: *const core.Stats, games: []const Game, pr: Predictor, w: *std.Io.Writer) !void {
    const r = try evaluate(gpa, st, games, pr);
    defer gpa.free(r.p);
    const idx = try gpa.alloc(usize, games.len);
    defer gpa.free(idx);
    for (idx, 0..) |*x, i| x.* = i;
    std.mem.sort(usize, idx, r.p, struct {
        fn lt(ps: []const f64, a: usize, b: usize) bool {
            return ps[a] < ps[b];
        }
    }.lt);
    try w.writeAll("| decile | games | mean predicted | blue won |\n| --- | --- | --- | --- |\n");
    for (0..10) |d| {
        const lo = idx.len * d / 10;
        const hi = idx.len * (d + 1) / 10;
        var sp: f64 = 0;
        var sy: f64 = 0;
        for (idx[lo..hi]) |k| {
            sp += r.p[k];
            sy += blueWon(games[k]);
        }
        const n: f64 = @floatFromInt(hi - lo);
        try w.print("| {d} | {d} | {d:.1}% | {d:.1}% |\n", .{ d + 1, hi - lo, 100 * sp / n, 100 * sy / n });
    }
}

const Tuned = struct { opts: score.Options, weights: Weights, joint_l2: f64 };

/// Prior strengths by out-of-fold log loss over the train games, then logistic weights
/// on the terms of those out-of-fold drafts
fn tune(
    gpa: std.mem.Allocator,
    champs: []const core.statsfile.Champion,
    train: []const Game,
    folds: u32,
    w: *std.Io.Writer,
) !Tuned {
    const models = try gpa.alloc(Model, folds);
    var built: usize = 0;
    defer {
        for (models[0..built]) |*m| m.deinit(gpa);
        gpa.free(models);
    }
    for (models, 0..) |*m, k| {
        m.* = try .build(gpa, champs, train, .{ .k = k, .folds = folds });
        built += 1;
    }

    var losses: [prior_grid.len][prior_grid.len]f64 = undefined;
    var best: score.Options = .{};
    var best_loss = std.math.inf(f64);
    for (prior_grid, 0..) |bp, i| for (prior_grid, 0..) |pp, j| {
        const o: score.Options = .{ .base_prior_games = bp, .prior_games = pp };
        var sum: f64 = 0;
        for (train, 0..) |g, gi| {
            sum += logLoss(score.draftWin(&models[gi % folds].stats, o, g.teams), blueWon(g));
        }
        losses[i][j] = sum / @as(f64, @floatFromInt(train.len));
        if (losses[i][j] < best_loss) {
            best_loss = losses[i][j];
            best = o;
        }
    };

    const xs = try gpa.alloc(Weights, train.len);
    defer gpa.free(xs);
    const ys = try gpa.alloc(f64, train.len);
    defer gpa.free(ys);
    for (train, xs, ys, 0..) |g, *x, *y, gi| {
        x.* = features(score.draftTerms(&models[gi % folds].stats, best, g.teams));
        y.* = blueWon(g);
    }
    const weights = fitLogistic(xs, ys, 1.0);
    var wloss: f64 = 0;
    for (xs, ys) |x, y| wloss += logLoss(sigmoid(dot(weights, x)), y);
    wloss /= @floatFromInt(train.len);

    try w.print("## Tuning ({d}-fold inside train)\n\n", .{folds});
    try w.writeAll("Out-of-fold log loss by prior strength in games (rows: base, " ++
        "columns: pairs):\n\n| base \\ pairs |");
    for (prior_grid) |pp| try w.print(" {f} |", .{Prior{ .games = pp }});
    try w.writeAll("\n| --- |");
    for (prior_grid) |_| try w.writeAll(" --- |");
    try w.writeAll("\n");
    for (prior_grid, 0..) |bp, i| {
        try w.print("| {f} |", .{Prior{ .games = bp }});
        for (losses[i]) |l| try w.print(" {d:.4} |", .{l});
        try w.writeAll("\n");
    }
    try w.print("\nBest: base {f}, pairs {f} (out-of-fold {d:.4}). ", .{
        Prior{ .games = best.base_prior_games }, Prior{ .games = best.prior_games }, best_loss,
    });
    try w.print("Term weights on those out-of-fold drafts (in-sample {d:.4}): intercept " ++
        "{d:.3}, base {d:.3}, duo {d:.3}, lane {d:.3}, matchup {d:.3}\n\n", .{
        wloss, weights[0], weights[1], weights[2], weights[3], weights[4],
    });

    // Joint ratings: L2 strength by out-of-fold log loss. Prior 1000 games ~ l2 300
    const st = &models[0].stats;
    var fold_train: std.ArrayList(Game) = .empty;
    defer fold_train.deinit(gpa);
    var best_l2: f64 = 0;
    var best_joint = std.math.inf(f64);
    try w.writeAll("Joint ratings, out-of-fold log loss by L2 strength:");
    for (joint_l2_grid) |l2| {
        var sum: f64 = 0;
        for (0..folds) |k| {
            fold_train.clearRetainingCapacity();
            for (train, 0..) |g, gi| if (gi % folds != k) try fold_train.append(gpa, g);
            const jw = try fitJoint(gpa, st, fold_train.items, l2);
            defer gpa.free(jw);
            for (train, 0..) |g, gi| if (gi % folds == k) {
                sum += logLoss(sigmoid(jointRow(st, g).dot(jw)), blueWon(g));
            };
        }
        const loss = sum / @as(f64, @floatFromInt(train.len));
        try w.print(" {d}: {d:.4};", .{ l2, loss });
        if (loss < best_joint) {
            best_joint = loss;
            best_l2 = l2;
        }
    }
    try w.print(" best {d}\n\n", .{best_l2});
    return .{ .opts = best, .weights = weights, .joint_l2 = best_l2 };
}

const joint_l2_grid = [_]f64{ 30, 100, 300, 1000, 3000, 10000 };

/// L2-penalised logistic regression by Newton's method (few features); the intercept
/// (feature 0) is not penalised
fn fitLogistic(xs: []const Weights, ys: []const f64, l2: f64) Weights {
    const d = @typeInfo(Weights).array.len;
    var b: Weights = @splat(0);
    for (0..50) |_| {
        var grad: Weights = @splat(0);
        var hess: [d][d]f64 = @splat(@splat(0));
        for (xs, ys) |x, y| {
            const p = sigmoid(dot(b, x));
            for (0..d) |i| {
                grad[i] += (p - y) * x[i];
                for (0..d) |j| hess[i][j] += p * (1 - p) * x[i] * x[j];
            }
        }
        for (1..d) |i| {
            grad[i] += l2 * b[i];
            hess[i][i] += l2;
        }
        const step = solve(d, hess, grad) orelse break;
        var size: f64 = 0;
        for (0..d) |i| {
            b[i] -= step[i];
            size += @abs(step[i]);
        }
        if (size < 1e-9) break;
    }
    return b;
}

/// a x = v by Gaussian elimination with partial pivoting; null when singular
fn solve(comptime d: usize, a_in: [d][d]f64, v_in: [d]f64) ?[d]f64 {
    var a = a_in;
    var v = v_in;
    for (0..d) |col| {
        var piv = col;
        for (col + 1..d) |r| if (@abs(a[r][col]) > @abs(a[piv][col])) {
            piv = r;
        };
        if (@abs(a[piv][col]) < 1e-12) return null;
        std.mem.swap([d]f64, &a[col], &a[piv]);
        std.mem.swap(f64, &v[col], &v[piv]);
        for (col + 1..d) |r| {
            const f = a[r][col] / a[col][col];
            for (col..d) |c| a[r][c] -= f * a[col][c];
            v[r] -= f * v[col];
        }
    }
    var x: [d]f64 = undefined;
    var i = d;
    while (i > 0) {
        i -= 1;
        var s = v[i];
        for (i + 1..d) |c| s -= a[i][c] * x[c];
        x[i] = s / a[i][i];
    }
    return x;
}

fn pickMetric(
    gpa: std.mem.Allocator,
    st: *const core.Stats,
    games: []const Game,
    pr: Predictor,
    min_games: u32,
    w: *std.Io.Writer,
) !void {
    var candidates = switch (pr.on(st).kind) {
        .model => |o| o,
        else => unreachable,
    };
    candidates.min_games = min_games;
    const out = try gpa.alloc(score.Suggestion, st.n);
    defer gpa.free(out);
    var pct: std.ArrayList(f64) = .empty;
    defer pct.deinit(gpa);
    var won: std.ArrayList(Game) = .empty;
    defer won.deinit(gpa);
    var missed: usize = 0;
    for (games) |g| for (0..2) |s| for (Role.all) |r| {
        var allies: [4]score.Pick = undefined;
        var n_allies: usize = 0;
        for (Role.all) |ar| if (ar != r) {
            allies[n_allies] = .{ .champion = g.teams[s][@intFromEnum(ar)], .role = ar };
            n_allies += 1;
        };
        var enemies: [5]score.Pick = undefined;
        for (Role.all, &enemies) |er, *e| e.* = .{ .champion = g.teams[1 - s][@intFromEnum(er)], .role = er };
        const list = score.recommend(st, .{
            .role = r,
            .allies = &allies,
            .enemies = &enemies,
        }, candidates, out);
        const hidden = g.teams[s][@intFromEnum(r)];
        const rank = for (list, 0..) |sg, i| {
            if (sg.champion == hidden) break i;
        } else {
            missed += 1;
            continue;
        };
        if (list.len < 2) continue;
        try pct.append(gpa, 1 - @as(f64, @floatFromInt(rank)) / @as(f64, @floatFromInt(list.len - 1)));
        // Reuse the AUC helper: "blue won" here means this pick's side won
        var fake = g;
        fake.winner = if (g.winner == s) 0 else 1;
        try won.append(gpa, fake);
    };
    var sw: f64 = 0;
    var nw: f64 = 0;
    var sl: f64 = 0;
    var top_n: f64 = 0;
    var top_w: f64 = 0;
    for (pct.items, won.items) |q, g| {
        if (g.winner == 0) {
            sw += q;
            nw += 1;
        } else sl += q;
        if (q >= 0.9) {
            top_n += 1;
            top_w += blueWon(g);
        }
    }
    const nl = @as(f64, @floatFromInt(pct.items.len)) - nw;
    try w.print("| {s} | {d} ({d} not candidates) | {d:.3} | {d:.3} | {d:.3} | {d:.1}% of {d} |\n", .{
        pr.label,
        pct.items.len,
        missed,
        sw / nw,
        sl / nl,
        try auc(gpa, pct.items, won.items),
        100 * top_w / @max(top_n, 1),
        top_n,
    });
}

fn roleInference(st: *const core.Stats, games: []const Game, w: *std.Io.Writer) !void {
    var right: usize = 0;
    var total: usize = 0;
    var teams_right: usize = 0;
    var by_role: [Role.count][2]usize = @splat(@splat(0));
    for (games) |g| for (g.teams) |team| {
        var picks: [5]score.Pick = undefined;
        for (team, &picks) |id, *p| p.* = .{ .champion = id };
        var roles: [5]?Role = undefined;
        score.inferRoles(st, &picks, &roles);
        var all = true;
        for (roles, Role.all) |got, want| {
            const ok = got != null and got.? == want;
            if (ok) right += 1 else all = false;
            total += 1;
            by_role[@intFromEnum(want)][0] += @intFromBool(ok);
            by_role[@intFromEnum(want)][1] += 1;
        }
        if (all) teams_right += 1;
    };
    try w.print("All five roles hidden: {d:.1}% of champions placed right, {d:.1}% of teams " ++
        "entirely right ({d} teams).", .{
        100 * @as(f64, @floatFromInt(right)) / @as(f64, @floatFromInt(total)),
        100 * @as(f64, @floatFromInt(teams_right)) / @as(f64, @floatFromInt(2 * games.len)),
        2 * games.len,
    });
    try w.writeAll(" By real role:");
    for (Role.all, by_role) |r, c| {
        try w.print(" {s} {d:.1}%", .{ r.label(), 100 * @as(f64, @floatFromInt(c[0])) / @as(f64, @floatFromInt(c[1])) });
    }
    try w.writeAll("\n");
}

fn sigmoid(x: f64) f64 {
    return 1 / (1 + @exp(-x));
}

/// Prior strength in games; "off" for the grid's no-terms value
const Prior = struct {
    games: f64,

    pub fn format(p: Prior, w: *std.Io.Writer) std.Io.Writer.Error!void {
        if (p.games >= score.max_prior_games) try w.writeAll("off") else try w.print("{d:.0}", .{p.games});
    }
};

/// Unix ms as YYYY-MM-DD (UTC)
pub const Day = struct {
    ms: i64,

    pub fn format(d: Day, w: *std.Io.Writer) std.Io.Writer.Error!void {
        const epoch: std.time.epoch.EpochSeconds = .{ .secs = @intCast(@divFloor(d.ms, 1000)) };
        const yd = epoch.getEpochDay().calculateYearDay();
        const md = yd.calculateMonthDay();
        try w.print("{d}-{d:0>2}-{d:0>2}", .{ yd.year, md.month.numeric(), md.day_index + 1 });
    }
};

const testing = std.testing;

test "auc and logistic fit" {
    const gpa = testing.allocator;
    var games: [4]Game = undefined;
    for (&games, [_]u1{ 1, 0, 1, 0 }) |*g, won| {
        g.* = .{ .id = 0, .start = 0, .patch = 0, .platform = 0, .teams = @splat(@splat(0)), .winner = won };
    }
    // Blue won games 1 and 3; perfectly ranked, then one swap
    try testing.expectEqual(1.0, try auc(gpa, &.{ 0.1, 0.9, 0.2, 0.8 }, &games));
    try testing.expectEqual(0.75, try auc(gpa, &.{ 0.1, 0.9, 0.85, 0.8 }, &games));
    try testing.expectEqual(0.5, try auc(gpa, &.{ 0.5, 0.5, 0.5, 0.5 }, &games));

    // y = 1 when x > 0, noisy: weight on x positive, intercept ~0
    var xs: [200]Weights = undefined;
    var ys: [200]f64 = undefined;
    for (&xs, &ys, 0..) |*x, *y, i| {
        const v = @as(f64, @floatFromInt(i)) / 100 - 1;
        x.* = .{ 1, v, 0, 0, 0 };
        y.* = if ((v > 0) != (i % 7 == 0)) 1 else 0;
    }
    const b = fitLogistic(&xs, &ys, 1);
    try testing.expect(b[1] > 1);
    try testing.expect(@abs(b[0]) < 0.5);
}
