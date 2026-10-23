//! `meiolol draft-model`: the shipped draft model (core.score with its default options on a
//! stats file with its fitted model, fitted.zig, as the site and app score drafts) on every
//! played game in the database, every platform and
//! patch, as the admin Draft tester's draft-model.json and draft-ref.json (draftfile.zig,
//! docs/model.md "Draft model file"). Daily on the box (deploy/web-loop.sh), so the tester
//! follows the data without the lab; `meiolol-lab draft --export` writes the same files
//! from a snapshot for lab models. Counts only: seconds of work after the scan.

const std = @import("std");
const store = @import("store");
const core = @import("core");
const stats = @import("stats.zig");
const eval = @import("eval.zig");
const analysis = @import("analysis.zig");
const riot = @import("riot/root.zig");
const df = @import("draftfile.zig");
const logreg = @import("logreg.zig");
const Time = @import("date.zig").Time;

const score = core.score;
const Role = core.Role;
const Game = stats.Row;
const n_role = df.n_role;

/// The site's and the app's
const opts: score.Options = .{};

pub fn run(gpa: std.mem.Allocator, io: std.Io, db: store.Db, dir: []const u8, w: *std.Io.Writer) !void {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const now_ms = std.Io.Clock.real.now(io).toMilliseconds();

    var ids: [riot.endpoints.platforms.len][]const u8 = undefined;
    for (riot.endpoints.platforms, &ids) |p, *id| id.* = p.id;
    var list: analysis.GameList = .{ .gpa = gpa };
    defer list.items.deinit(gpa);
    _ = try stats.scan(gpa, io, db, try stats.patches(arena, db, &ids), &ids, 0, &list);
    // Played games set the protocol's cuts (analysis.protocolCuts) and are fitted, as the lab
    var played: std.ArrayList(Game) = .empty;
    for (list.items.items) |g| if (g.duration_s >= eval.min_duration_s) try played.append(arena, g);
    const games = played.items;
    std.mem.sort(Game, games, {}, struct {
        fn f(_: void, a: Game, b: Game) bool {
            return a.start < b.start;
        }
    }.f);
    const starts = try arena.alloc(i64, games.len);
    for (starts, games) |*s, g| s.* = g.start;
    const cuts = try eval.cutsOf(starts, .{});

    const champs = try stats.champions(gpa, db);
    defer stats.freeChampions(gpa, champs);
    var full = try eval.Model.buildShipped(gpa, champs, games);
    defer full.deinit(gpa);
    const st = &full.stats;
    const info = try champions(arena, st, games);
    const sc = try df.Scorer.init(arena, try params(arena, st), 0, &info);
    try w.print("shipped draft model on {d} played games, every platform\n", .{games.len});

    // The file must score full drafts as the site and app do
    var tests: std.ArrayList([2][n_role]u32) = .empty;
    var worst: f64 = 0;
    for (games) |g| {
        if (g.start < cuts.test_ or tests.items.len == 500) continue;
        try tests.append(arena, g.teams);
        worst = @max(worst, @abs(sc.blue(g.teams).p - score.draftWin(st, opts, g.teams)));
    }
    try w.print("file scorer vs core.score on {d} test games: max |diff| {e}\n", .{ tests.items.len, worst });
    if (worst > 1e-4) return error.ScorerDisagrees;

    const dev = try devScore(gpa, arena, champs, games, cuts);
    try w.print("dev: log loss {d:.5} (baseline {d:.5}), accuracy {d:.4}, AUC {d:.4} on {d} games\n", .{ dev.log_loss, dev.baseline_log_loss, dev.accuracy, dev.auc, dev.games });
    try df.exportFiles(arena, io, &sc, &info, .{
        .name = "shipped model (site and app)",
        .run = try arena.print("{f}", .{Time.fromMs(now_ms).minutes()}),
        .snapshot = "box database",
        .newest_start = games[games.len - 1].start,
        .training_games = games.len,
        .platform = "EUW1",
        .dev = dev,
        .tests = tests.items,
    }, dir, w);
}

/// Names, games in each role and the share patch's play rates (the empty slot's average)
fn champions(arena: std.mem.Allocator, st: *const core.Stats, games: []const Game) !df.Champions {
    var c: df.Champions = .{};
    for (0..st.n) |i| {
        try c.names.put(arena, st.ids[i], st.name(i));
        for (Role.all) |r| {
            const n = st.champRole(r, i).games;
            if (n > 0) try c.games.put(arena, df.Champions.key(st.ids[i], @backingInt(r)), n);
        }
    }
    try c.countShares(arena, games);
    return c;
}

const role_names = [n_role][]const u8{ "top", "jungle", "middle", "bottom", "support" };

/// Every term as core.score reads it from the fitted model: b the strength, sd from the
/// smoothed rate's binomial variance (rough: the fit's own is not kept); allies r < q; matchups of role r against role q (r < q) from
/// r's side, the scorer negating red's r against blue's q; lane opponents once per
/// unordered pair, the lower champion id's side. Pairs never seen add 0 either way
fn params(arena: std.mem.Allocator, st: *const core.Stats) !df.Params {
    var terms: std.ArrayList(df.Term) = .empty;
    const k = opts.base_prior_games;
    for (0..st.n) |c| for (Role.all) |r| {
        const n = st.champRole(r, c);
        if (n.games == 0) continue;
        const games: f64 = @floatFromInt(n.games);
        const p = (@as(f64, @floatFromInt(n.wins)) + 0.5 * k) / (games + k);
        try terms.append(arena, .{
            .champion = st.ids[c],
            .role = @backingInt(r),
            .games = n.games,
            .b = @floatCast(score.baseLogit(st, opts, c, r)),
            .sd = @floatCast(1 / @sqrt((games + k) * p * (1 - p))),
        });
    };
    var groups: std.ArrayList(df.PairGroup) = .empty;
    var cells: std.ArrayList(df.PairCell) = .empty;
    for (Role.all) |r| for (Role.all) |q| {
        const ri = @backingInt(r);
        const qi = @backingInt(q);
        if (qi < ri) continue;
        const kinds: []const []const u8 = if (ri == qi) &.{"lane"} else &.{ "ally", "matchup" };
        for (kinds) |kind| {
            const g: u32 = @intCast(groups.items.len);
            var shipped: u32 = 0;
            for (0..st.n) |a| for (0..st.n) |b| {
                const ally = std.mem.eql(u8, kind, "ally");
                if (!ally and ri == qi and st.ids[a] >= st.ids[b]) continue;
                const n = if (ally) st.ally(r, q, a, b) else st.enemy(r, q, a, b);
                if (n.games == 0) continue;
                const theta = if (ally) score.duoLogit(st, opts, r, a, q, b) else score.matchupLogit(st, opts, r, a, q, b);
                try cells.append(arena, .{ .group = g, .a = st.ids[a], .b = st.ids[b], .theta = theta, .games = n.games });
                shipped += 1;
            };
            try groups.append(arena, .{
                .name = try arena.print("{s} {s}-{s}", .{ kind, role_names[ri], role_names[qi] }),
                .kind = if (std.mem.eql(u8, kind, "ally")) "ally" else "matchup",
                .r = ri,
                .q = qi,
                .sd = 0,
                .fitted = shipped,
                .shipped = shipped,
            });
        }
    };
    return .{
        .kind = "draft",
        .dim = 0,
        .intercept = &.{0},
        .w = @splat(0),
        .z = @splat(0),
        .terms = terms.items,
        .pairs = .{ .min_games = 1, .groups = groups.items, .cells = cells.items },
    };
}

/// Refitted on the played games older than dev-val, scored on dev-val per game
fn devScore(
    gpa: std.mem.Allocator,
    arena: std.mem.Allocator,
    champs: []const core.statsfile.Champion,
    games: []const Game,
    cuts: eval.Cuts,
) !df.Dev {
    var older: usize = 0;
    while (games[older].start < cuts.dev) older += 1;
    var m = try eval.Model.buildShipped(gpa, champs, games[0..older]);
    defer m.deinit(gpa);
    var points: std.ArrayList(df.Point) = .empty;
    var la: f64 = 0;
    var lb: f64 = 0;
    for (games[older..]) |g| {
        if (g.start >= cuts.test_) break;
        const y = g.winner == 0;
        const pa = score.draftWin(&m.stats, opts, g.teams);
        const pb = logreg.sigmoid(score.draftTerms(&m.stats, opts, g.teams).base);
        la -= @log(if (y) pa else 1 - pa);
        lb -= @log(if (y) pb else 1 - pb);
        try points.append(arena, .{ .p = pa, .y = y });
    }
    const n: f64 = @floatFromInt(@max(points.items.len, 1));
    const aa = df.accuracyAuc(points.items);
    return .{
        .what = "fitted on the played games older than dev-val, scored on dev-val: the 10% of played games before the test cut, every platform (docs/model.md Shared protocol); log loss per game of blue's win (baseline: champion strength alone), accuracy and AUC per game on blue's chance",
        .games = points.items.len,
        .log_loss = la / n,
        .baseline_log_loss = lb / n,
        .accuracy = aa[0],
        .auc = aa[1],
    };
}

test "the file scores fixture drafts as core.score" {
    const gpa = std.testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var rng: std.Random.DefaultPrng = .init(7);
    const rnd = rng.random();
    const champs = [_]core.statsfile.Champion{
        .{ .id = 1, .name = "A" }, .{ .id = 2, .name = "B" }, .{ .id = 3, .name = "C" },
        .{ .id = 5, .name = "D" }, .{ .id = 8, .name = "E" }, .{ .id = 9, .name = "F" },
    };
    const games = try arena.alloc(Game, 400);
    for (games, 0..) |*g, i| {
        g.* = .{ .id = i, .start = @intCast(i), .patch = 16020, .platform = 0, .teams = undefined, .winner = rnd.int(u1) };
        for (0..2) |s| for (0..n_role) |r| {
            g.teams[s][r] = champs[rnd.uintLessThan(usize, champs.len)].id;
        };
    }
    var m = try eval.Model.buildShipped(gpa, &champs, games);
    defer m.deinit(gpa);
    const info = try champions(arena, &m.stats, games);
    const sc = try df.Scorer.init(arena, try params(arena, &m.stats), 0, &info);
    for (games[0..100]) |g| {
        try std.testing.expectApproxEqAbs(score.draftWin(&m.stats, opts, g.teams), sc.blue(g.teams).p, 1e-6);
    }
}

test {
    _ = df;
}
