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
const additive = @import("additive.zig");
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
    const classes = try stats.kitClasses(gpa, db);
    defer gpa.free(classes);
    var full = try eval.Model.buildShipped(gpa, champs, games, classes);
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

    const dev = try devScore(gpa, arena, champs, classes, games, cuts);
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
    try writeSlices(arena, io, &sc, &info, dir, w);
}

/// One pairing in a champion's slice: the other champion's role and id, and the chance of
/// the champion's team with both in, the rest its role's average pick
const Paired = struct { role: u8, champion: u32, p: f64, games: u32 };

/// DIR/champ/<id>.json for the private site's champion and matchup pages (/p/pv.js, built
/// by admin.zig): per role the champion plays, its team's chance against an average draft
/// (95% range) and with each opponent ("vs") or ally ("with") it has games beside, every
/// other slot its role's average pick. Numbers the public pages never show
fn writeSlices(arena: std.mem.Allocator, io: std.Io, sc: *const df.Scorer, info: *const df.Champions, dir: []const u8, w: *std.Io.Writer) !void {
    const Lists = struct { vs: std.ArrayList(Paired) = .empty, with: std.ArrayList(Paired) = .empty };
    var by: std.AutoHashMapUnmanaged(u64, Lists) = .empty;
    const pairs = sc.e.pairs orelse return;
    for (pairs.cells) |c| {
        const g = pairs.groups[c.group];
        const ally = std.mem.eql(u8, g.kind, "ally");
        for ([2]struct { u32, u8, u32, u8 }{ .{ c.a, g.r, c.b, g.q }, .{ c.b, g.q, c.a, g.r } }) |side| {
            const me, const r, const other, const q = side;
            if (sc.terms.get(df.Champions.key(me, r)) == null) continue;
            var teams: [2][n_role]u32 = @splat(@splat(0));
            teams[0][r] = me;
            teams[if (ally) 0 else 1][q] = other;
            const e = try by.getOrPut(arena, df.Champions.key(me, r));
            if (!e.found_existing) e.value_ptr.* = .{};
            const list = if (ally) &e.value_ptr.with else &e.value_ptr.vs;
            try list.append(arena, .{ .role = q, .champion = other, .p = sc.blue(teams).p, .games = c.games });
        }
    }
    const out_dir = try std.fs.path.join(arena, &.{ dir, "champ" });
    try std.Io.Dir.cwd().createDirPath(io, out_dir);
    var files: usize = 0;
    const window = try arena.alloc(u8, store.raw.window_len);
    var it = info.names.keyIterator();
    while (it.next()) |id| {
        var out: std.Io.Writer.Allocating = .init(arena);
        const o = &out.writer;
        try o.print("{{\"id\":{d},\"roles\":[", .{id.*});
        var first = true;
        for (0..n_role) |r| {
            if (sc.terms.get(df.Champions.key(id.*, r)) == null) continue;
            var teams: [2][n_role]u32 = @splat(@splat(0));
            teams[0][r] = id.*;
            const ch = sc.blue(teams);
            try o.print("{s}{{\"role\":{d},\"games\":{d},\"win\":[{d:.4},{d:.4},{d:.4}]", .{ if (first) "" else ",", r, info.gamesIn(id.*, r), ch.p, ch.lo, ch.hi });
            first = false;
            const lists = by.get(df.Champions.key(id.*, r)) orelse Lists{};
            for ([2][]const u8{ "vs", "with" }, [2][]const Paired{ lists.vs.items, lists.with.items }) |name, list| {
                try o.print(",\"{s}\":[", .{name});
                for (list, 0..) |x, i| try o.print("{s}[{d},{d},{d:.4},{d}]", .{ if (i == 0) "" else ",", x.role, x.champion, x.p, x.games });
                try o.writeAll("]");
            }
            try o.writeAll("}");
        }
        if (first) continue;
        try o.writeAll("]}\n");
        var buf: [32]u8 = undefined;
        const path = try std.fs.path.join(arena, &.{ out_dir, try std.fmt.bufPrint(&buf, "{d}.json", .{id.*}) });
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = out.written() });
        // For nginx's gzip_static: /p/ compresses nothing itself, and a slice runs to 100 KB
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = try arena.print("{s}.gz", .{path}), .data = try store.raw.compressWith(arena, window, out.written()) });
        files += 1;
    }
    try w.print("wrote {d} champion slices to {s}\n", .{ files, out_dir });
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
    classes: []const additive.KitClass,
    games: []const Game,
    cuts: eval.Cuts,
) !df.Dev {
    var older: usize = 0;
    while (games[older].start < cuts.dev) older += 1;
    var m = try eval.Model.buildShipped(gpa, champs, games[0..older], classes);
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
    var m = try eval.Model.buildShipped(gpa, &champs, games, &.{});
    defer m.deinit(gpa);
    const info = try champions(arena, &m.stats, games);
    const sc = try df.Scorer.init(arena, try params(arena, &m.stats), 0, &info);
    for (games[0..100]) |g| {
        try std.testing.expectApproxEqAbs(score.draftWin(&m.stats, opts, g.teams), sc.blue(g.teams).p, 1e-6);
    }
}

test "champion slices give the scorer's chances" {
    const testing = std.testing;
    const gpa = testing.allocator;
    const io = testing.io;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var rng: std.Random.DefaultPrng = .init(11);
    const rnd = rng.random();
    const champs = [_]core.statsfile.Champion{ .{ .id = 1, .name = "A" }, .{ .id = 2, .name = "B" }, .{ .id = 3, .name = "C" } };
    const games = try arena.alloc(Game, 300);
    for (games, 0..) |*g, i| {
        g.* = .{ .id = i, .start = @intCast(i), .patch = 16020, .platform = 0, .teams = undefined, .winner = rnd.int(u1) };
        for (0..2) |side| for (0..n_role) |r| {
            g.teams[side][r] = champs[rnd.uintLessThan(usize, champs.len)].id;
        };
    }
    var m = try eval.Model.buildShipped(gpa, &champs, games, &.{});
    defer m.deinit(gpa);
    const info = try champions(arena, &m.stats, games);
    const sc = try df.Scorer.init(arena, try params(arena, &m.stats), 0, &info);
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir = try arena.print(".zig-cache/tmp/{s}", .{&tmp.sub_path});
    var discard: std.Io.Writer.Discarding = .init(&.{});
    try writeSlices(arena, io, &sc, &info, dir, &discard.writer);

    const text = try std.Io.Dir.cwd().readFileAlloc(io, try arena.print("{s}/champ/2.json", .{dir}), arena, .limited(1 << 20));
    const Role_ = struct { role: u8, games: u32, win: [3]f64, vs: []const [4]f64, with: []const [4]f64 };
    const slice = try std.json.parseFromSliceLeaky(struct { id: u32, roles: []const Role_ }, arena, text, .{});
    try testing.expectEqual(2, slice.id);
    try testing.expectEqual(n_role, slice.roles.len);
    const top = slice.roles[0];
    var alone: [2][n_role]u32 = @splat(@splat(0));
    alone[0][0] = 2;
    try testing.expectApproxEqAbs(sc.blue(alone).p, top.win[0], 1e-4);
    // Each opponent and ally as the scorer has it
    for (top.vs) |x| {
        var t = alone;
        t[1][@intFromFloat(x[0])] = @intFromFloat(x[1]);
        try testing.expectApproxEqAbs(sc.blue(t).p, x[2], 1e-4);
    }
    for (top.with) |x| {
        var t = alone;
        t[0][@intFromFloat(x[0])] = @intFromFloat(x[1]);
        try testing.expectApproxEqAbs(sc.blue(t).p, x[2], 1e-4);
    }
    // Lane: the two others (no mirror cell); the other roles' opponents and allies: all three
    try testing.expectEqual(2 + 3 * (n_role - 1), top.vs.len);
    try testing.expectEqual(3 * (n_role - 1), top.with.len);
}

test {
    _ = df;
}
