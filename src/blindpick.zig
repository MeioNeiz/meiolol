//! `meiolol eval --blind`: J2's safe blind pick on held-out games (docs/model.md "Blind
//! pick ranking"). Same time split and shipped model as eval's pick metric, but my lane
//! opponent is hidden: the lane card ranks blind picks with no lane term, as if every
//! opponent were average. Variants add a per champion-role offset over the role's likely
//! opponents (every champion with pick_min_games train games in it, weighted by them):
//! the expected lane term, low quantiles of it, mean minus spread, and the J2 wording's
//! low end of the base rating's own uncertainty.
//!
//! Per test seat, each ranking's percentile of the champion actually picked; reports
//! winners' minus losers' mean percentile and AUC (each ± paired by game against today's
//! ranking) and the win rate of picks in each ranking's top 10%. Two scenarios: the other
//! eight known, and allies only (no enemy picked yet).

const std = @import("std");
const store = @import("store");
const core = @import("core");
const stats = @import("stats.zig");
const additive = @import("additive.zig");
const eval = @import("eval.zig");
const analysis = @import("analysis.zig");
const par = @import("par.zig");
const Date = @import("date.zig").Date;
const score = core.score;
const Role = core.Role;
const Game = stats.Row;
const Io = std.Io;

const Variant = enum {
    current,
    mean,
    q25,
    q10,
    mean_sd,
    lcb,

    fn label(v: Variant) []const u8 {
        return switch (v) {
            .current => "today: no lane term",
            .mean => "+ expected lane term over likely opponents",
            .q25 => "+ its 25th percentile",
            .q10 => "+ its 10th percentile",
            .mean_sd => "+ expected minus one spread",
            .lcb => "today minus one SE of the base rating",
        };
    }
};
const variants = std.enums.values(Variant);
const nv = variants.len;

const Scenario = enum {
    lane_hidden,
    enemies_hidden,

    fn label(s: Scenario) []const u8 {
        return switch (s) {
            .lane_hidden => "Lane opponent hidden, other eight known",
            .enemies_hidden => "No enemy known, four allies known",
        };
    }
};
const scenarios = std.enums.values(Scenario);

/// Per (role, champion index): the variants' offsets on the pick's logit
const Offsets = [nv][Role.count][]f64;

pub fn run(
    gpa: std.mem.Allocator,
    io: Io,
    db: store.Db,
    patches: []const []const u8,
    platforms: []const []const u8,
    opts: eval.Options,
    w: *Io.Writer,
) !void {
    const champs = try stats.champions(gpa, db);
    defer stats.freeChampions(gpa, champs);
    var list: analysis.GameList = .{ .gpa = gpa };
    defer list.items.deinit(gpa);
    _ = try stats.scan(gpa, io, db, patches, platforms, 0, &list);
    const classes = try stats.kitClasses(gpa, db);
    defer gpa.free(classes);
    try runGames(gpa, io, champs, classes, list.items.items, platforms, opts, w);
}

fn runGames(
    gpa: std.mem.Allocator,
    io: Io,
    champs: []const core.statsfile.Champion,
    classes: []const additive.KitClass,
    games: []Game,
    platforms: []const []const u8,
    opts: eval.Options,
    w: *Io.Writer,
) !void {
    var parts = try eval.split(gpa, games, platforms, opts);
    defer parts.deinit(gpa);
    const train = parts.train;
    const tests = parts.tests;
    if (train.len == 0 or tests.len < 2) return error.TooFewGames;

    var shipped: eval.Model = try .buildShipped(gpa, champs, train, classes);
    defer shipped.deinit(gpa);
    const st = &shipped.stats;

    try w.print("# meiolol eval --blind\n\nBlind pick ranking (docs/model.md). Train: " ++
        "oldest {d} games ({f} to {f}). {s}: {d} ({f} to {f}). Shipped model; candidates " ++
        "and likely opponents: {d}+ train games in the role.\n", .{
        train.len,                               Date.fromMs(train[0].start),
        Date.fromMs(train[train.len - 1].start), if (opts.dev) "Dev-val" else "Test",
        tests.len,                               Date.fromMs(tests[0].start),
        Date.fromMs(tests[tests.len - 1].start), opts.pick_min_games,
    });

    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const offsets = try offsetsOf(arena_state.allocator(), st, opts.pick_min_games);
    try offsetTable(w, st, &offsets, opts.pick_min_games);

    const seats = tests.len * 2 * Role.count;
    const pct = try gpa.alloc([nv]f32, seats);
    defer gpa.free(pct);
    for (scenarios) |sc| {
        try par.forEach(io, tests.len, Rank{
            .gpa = gpa,
            .st = st,
            .games = tests,
            .min_games = opts.pick_min_games,
            .offsets = &offsets,
            .scenario = sc,
            .pct = pct,
        }, Rank.game);
        try report(w, sc, try summarise(gpa, tests, pct));
    }
}

fn offsetsOf(arena: std.mem.Allocator, st: *const core.Stats, min_games: u32) !Offsets {
    var out: Offsets = undefined;
    for (&out) |*v| for (v) |*r| {
        r.* = try arena.alloc(f64, st.n);
        @memset(r.*, 0);
    };
    const opts: score.Options = .{};
    const Pair = struct { x: f64, wt: f64 };
    const vals = try arena.alloc(Pair, st.n);
    for (Role.all) |r| {
        const ri = @backingInt(r);
        for (0..st.n) |c| {
            const games = st.champRole(r, c).games;
            if (games < min_games) continue;
            var n: usize = 0;
            var sw: f64 = 0;
            var sx: f64 = 0;
            for (0..st.n) |o| {
                if (o == c) continue;
                const og = st.champRole(r, o).games;
                if (og < min_games) continue;
                const wt: f64 = @floatFromInt(og);
                const x = score.matchupLogit(st, opts, r, c, r, o);
                vals[n] = .{ .x = x, .wt = wt };
                n += 1;
                sw += wt;
                sx += wt * x;
            }
            if (n == 0) continue;
            const mean = sx / sw;
            var sv: f64 = 0;
            for (vals[0..n]) |p| sv += p.wt * (p.x - mean) * (p.x - mean);
            std.mem.sort(Pair, vals[0..n], {}, struct {
                fn lt(_: void, a: Pair, b: Pair) bool {
                    return a.x < b.x;
                }
            }.lt);
            out[@backingInt(Variant.mean)][ri][c] = mean;
            out[@backingInt(Variant.q25)][ri][c] = quantile(vals[0..n], sw, 0.25);
            out[@backingInt(Variant.q10)][ri][c] = quantile(vals[0..n], sw, 0.10);
            out[@backingInt(Variant.mean_sd)][ri][c] = mean - @sqrt(sv / sw);
            // The base term's posterior SE near 50% (score.termVar), its prior as shipped
            const g: f64 = @floatFromInt(games);
            out[@backingInt(Variant.lcb)][ri][c] = -2 / @sqrt(g + opts.base_prior_games);
        }
    }
    return out;
}

/// Each offset over the candidate champion-roles: its mean, spread and correlation with
/// log role games. A spread of shrunk estimates grows with the games behind them, so an
/// offset that tracks games partly ranks by popularity, not by safety. r is "-" when
/// either side doesn't vary
fn offsetTable(
    w: *Io.Writer,
    st: *const core.Stats,
    offsets: *const Offsets,
    min_games: u32,
) !void {
    var candidates: usize = 0;
    for (Role.all) |r| for (0..st.n) |c| {
        candidates += @intFromBool(st.champRole(r, c).games >= min_games);
    };
    if (candidates < 2) return error.TooFewGames;
    try w.writeAll("\n## Offsets\n\nPer champion-role with the candidates' train games: " ++
        "mean, spread and correlation with log role games.\n\n" ++
        "| offset | champion-roles | mean | sd | r with log games |\n" ++
        "| --- | --- | --- | --- | --- |\n");
    for (variants[1..], 1..) |v, vi| {
        var n: f64 = 0;
        var sx: f64 = 0;
        var sy: f64 = 0;
        var sxx: f64 = 0;
        var syy: f64 = 0;
        var sxy: f64 = 0;
        for (Role.all) |r| for (0..st.n) |c| {
            const games = st.champRole(r, c).games;
            if (games < min_games) continue;
            const x = offsets[vi][@backingInt(r)][c];
            const y = @log(@as(f64, @floatFromInt(games)));
            n += 1;
            sx += x;
            sy += y;
            sxx += x * x;
            syy += y * y;
            sxy += x * y;
        };
        const vx = @max(0, sxx / n - (sx / n) * (sx / n));
        const vy = @max(0, syy / n - (sy / n) * (sy / n));
        try w.print("| {s} | {d} | {d:.4} | {d:.4} |", .{
            v.label(), @as(usize, @intFromFloat(n)), sx / n, @sqrt(vx),
        });
        if (vx > 0 and vy > 0) {
            try w.print(" {d:.2} |\n", .{(sxy / n - sx / n * sy / n) / @sqrt(vx * vy)});
        } else try w.writeAll(" - |\n");
    }
}

/// Weighted quantile of `sorted` (ascending), total weight `sw`
fn quantile(sorted: anytype, sw: f64, q: f64) f64 {
    var acc: f64 = 0;
    for (sorted) |p| {
        acc += p.wt;
        if (acc >= q * sw) return p.x;
    }
    return sorted[sorted.len - 1].x;
}

const Rank = struct {
    gpa: std.mem.Allocator,
    st: *const core.Stats,
    games: []const Game,
    min_games: u32,
    offsets: *const Offsets,
    scenario: Scenario,
    /// Per seat (game, side, role); NaN when the pick was not ranked: no candidate, or
    /// under two candidates
    pct: [][nv]f32,

    fn game(c: Rank, gi: usize) !void {
        const out = try c.gpa.alloc(score.Suggestion, c.st.n);
        defer c.gpa.free(out);
        const keys = try c.gpa.alloc(f64, c.st.n);
        defer c.gpa.free(keys);
        var cand: score.Options = .{};
        cand.min_games = c.min_games;
        const g = c.games[gi];
        for (0..2) |s| for (Role.all) |r| {
            var allies: [4]score.Pick = undefined;
            var na: usize = 0;
            for (Role.all) |ar| if (ar != r) {
                allies[na] = .{ .champion = g.teams[s][@backingInt(ar)], .role = ar };
                na += 1;
            };
            var enemies: [4]score.Pick = undefined;
            var ne: usize = 0;
            if (c.scenario == .lane_hidden) for (Role.all) |er| if (er != r) {
                enemies[ne] = .{ .champion = g.teams[1 - s][@backingInt(er)], .role = er };
                ne += 1;
            };
            const list = score.recommend(c.st, .{
                .role = r,
                .allies = &allies,
                .enemies = enemies[0..ne],
            }, cand, out);
            const at = (gi * 2 + s) * Role.count + @backingInt(r);
            const hidden = g.teams[s][@backingInt(r)];
            const mine = for (list, 0..) |sg, i| {
                if (sg.champion == hidden) break i;
            } else null;
            if (mine == null or list.len < 2) {
                c.pct[at] = @splat(std.math.nan(f32));
                continue;
            }
            for (variants, 0..) |v, vi| {
                const off = c.offsets[vi][@backingInt(r)];
                for (list, keys[0..list.len]) |sg, *k| {
                    const x = @log(sg.win / (1 - sg.win));
                    k.* = if (v == .current) x else x + off[c.st.index(sg.champion).?];
                }
                const kh = keys[mine.?];
                var above: f64 = 0;
                for (keys[0..list.len], 0..) |k, i| {
                    if (i == mine.?) continue;
                    if (k > kh) above += 1 else if (k == kh) above += 0.5;
                }
                c.pct[at][vi] = @floatCast(1 - above / @as(f64, @floatFromInt(list.len - 1)));
            }
        };
    }
};

const Paired = struct {
    diff: f64,
    /// 95%, by game
    half: f64,

    /// diff: the per-game terms' sum, unless given
    fn of(per_game: []const f64, diff: ?f64) Paired {
        var total: f64 = 0;
        for (per_game) |x| total += x;
        const n: f64 = @floatFromInt(per_game.len);
        var ss: f64 = 0;
        for (per_game) |x| ss += (x - total / n) * (x - total / n);
        return .{ .diff = diff orelse total, .half = 1.96 * @sqrt(n / (n - 1) * ss) };
    }
};

const Summary = struct {
    picks: usize,
    unranked: usize,
    rows: [nv]Row,

    const Row = struct {
        winners: f64,
        losers: f64,
        auc: f64,
        /// Against today's ranking; zero for it
        gap_vs: Paired,
        auc_vs: Paired,
        top_n: usize,
        top_win: f64,

        fn gap(r: Row) f64 {
            return r.winners - r.losers;
        }
    };
};

/// Gap and AUC per ranking, each paired by game against today's: both are sums over seats
/// (AUC by its DeLong placements), so their difference splits into per-game terms
fn summarise(gpa: std.mem.Allocator, games: []const Game, pct: []const [nv]f32) !Summary {
    var nw: f64 = 0;
    var nl: f64 = 0;
    var unranked: usize = 0;
    for (games, 0..) |g, gi| for (0..2) |s| for (0..Role.count) |r| {
        const p = pct[(gi * 2 + s) * Role.count + r];
        if (std.math.isNan(p[0])) {
            unranked += 1;
            continue;
        }
        if (g.winner == s) nw += 1 else nl += 1;
    };
    if (nw == 0 or nl == 0) return error.TooFewGames;
    const n: usize = @intFromFloat(nw + nl);
    var out: Summary = .{ .picks = n, .unranked = unranked, .rows = undefined };

    const q = try gpa.alloc(f64, n);
    defer gpa.free(q);
    const won = try gpa.alloc(bool, n);
    defer gpa.free(won);
    const place = try gpa.alloc(f64, n);
    defer gpa.free(place);
    // Per game: today's AUC terms, then this ranking's gap and AUC differences from today
    const auc0 = try gpa.alloc(f64, games.len);
    defer gpa.free(auc0);
    const d_gap = try gpa.alloc(f64, games.len);
    defer gpa.free(d_gap);
    const d_auc = try gpa.alloc(f64, games.len);
    defer gpa.free(d_auc);
    for (variants, &out.rows, 0..) |v, *row, vi| {
        var sw: f64 = 0;
        var sl: f64 = 0;
        var top_n: f64 = 0;
        var top_w: f64 = 0;
        var k: usize = 0;
        @memset(d_gap, 0);
        for (games, 0..) |g, gi| for (0..2) |s| for (0..Role.count) |r| {
            const p = pct[(gi * 2 + s) * Role.count + r];
            if (std.math.isNan(p[0])) continue;
            const x: f64 = p[vi];
            const win = g.winner == s;
            if (win) sw += x else sl += x;
            q[k] = x;
            won[k] = win;
            k += 1;
            if (x >= 0.9) {
                top_n += 1;
                top_w += @floatFromInt(@intFromBool(win));
            }
            const d = x - p[0];
            d_gap[gi] += if (win) d / nw else -d / nl;
        };
        const auc = try eval.auc(gpa, q, won, place);
        const terms = if (v == .current) auc0 else d_auc;
        @memset(terms, 0);
        k = 0;
        for (games, 0..) |g, gi| for (0..2) |s| for (0..Role.count) |r| {
            if (std.math.isNan(pct[(gi * 2 + s) * Role.count + r][0])) continue;
            terms[gi] += (place[k] - auc) / if (g.winner == s) nw else nl;
            k += 1;
        };
        if (v != .current) for (d_auc, auc0) |*d, t| {
            d.* -= t;
        };
        row.* = .{
            .winners = sw / nw,
            .losers = sl / nl,
            .auc = auc,
            .gap_vs = if (v == .current) .{ .diff = 0, .half = 0 } else .of(d_gap, null),
            .auc_vs = if (v == .current)
                .{ .diff = 0, .half = 0 }
            else
                .of(d_auc, auc - out.rows[0].auc),
            .top_n = @intFromFloat(top_n),
            .top_win = top_w / @max(top_n, 1),
        };
    }
    return out;
}

fn report(w: *Io.Writer, sc: Scenario, sum: Summary) !void {
    try w.print("\n## {s}\n\n{d} picks ({d} not ranked: no candidate, or under two). Gap: " ++
        "winners' mean percentile minus losers' (1 = the ranking's top); \"vs today\" ± 95% " ++
        "paired by game.\n\n" ++
        "| ranking | winners | losers | gap | gap vs today | AUC | AUC vs today | " ++
        "top 10% win |\n| --- | --- | --- | --- | --- | --- | --- | --- |\n", .{
        sc.label(), sum.picks, sum.unranked,
    });
    for (variants, sum.rows) |v, row| {
        try w.print("| {s} | {d:.4} | {d:.4} | {d:.4} |", .{
            v.label(), row.winners, row.losers, row.gap(),
        });
        if (v == .current) try w.print(" | {d:.4} |", .{row.auc}) else {
            try w.print(" {f} | {d:.4} | {f} |", .{
                signed(row.gap_vs), row.auc, signed(row.auc_vs),
            });
        }
        if (v == .current) try w.writeAll(" |");
        try w.print(" {d:.2}% of {d} |\n", .{ 100 * row.top_win, row.top_n });
    }
}

fn signed(p: Paired) Signed {
    return .{ .p = p };
}

const Signed = struct {
    p: Paired,

    pub fn format(s: Signed, w: *Io.Writer) Io.Writer.Error!void {
        try w.print("{s}{d:.4} ± {d:.4}", .{ if (s.p.diff >= 0) "+" else "", s.p.diff, s.p.half });
    }
};

test "weighted quantile" {
    const P = struct { x: f64, wt: f64 };
    const v = [_]P{ .{ .x = -1, .wt = 1 }, .{ .x = 0, .wt = 2 }, .{ .x = 1, .wt = 1 } };
    try std.testing.expectEqual(-1, quantile(&v, 4, 0.10));
    try std.testing.expectEqual(0, quantile(&v, 4, 0.5));
    try std.testing.expectEqual(1, quantile(&v, 4, 0.9));
}

const testing = std.testing;

/// Ten champions, all in every game, roles at random; in the middle lane champion 1 loses
/// to champion 2 nine games in ten, every other result a coin flip
fn plantedGames(arena: std.mem.Allocator, n: usize) ![]Game {
    var rng: std.Random.DefaultPrng = .init(5);
    const rnd = rng.random();
    const games = try arena.alloc(Game, n);
    const mid = @backingInt(Role.middle);
    for (games, 0..) |*g, i| {
        var ids: [10]u32 = .{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
        rnd.shuffle(u32, &ids);
        g.* = .{
            .id = i,
            .start = @intCast(i),
            .patch = 16020,
            .platform = 0,
            .teams = .{ ids[0..5].*, ids[5..10].* },
            .winner = rnd.int(u1),
            .duration_s = 1800,
        };
        for (0..2) |s| if (g.teams[s][mid] == 1 and g.teams[1 - s][mid] == 2) {
            g.winner = @intCast(if (rnd.float(f64) < 0.9) 1 - s else s);
        };
    }
    return games;
}

const planted_champs = blk: {
    var c: [10]core.statsfile.Champion = undefined;
    for (&c, 0..) |*x, i| x.* = .{ .id = i + 1, .name = "X" };
    break :blk c;
};

fn runPlanted(games: []Game, o: eval.Options, w: *Io.Writer) !void {
    return runGames(testing.allocator, testing.io, &planted_champs, &.{}, games, &.{"EUW1"}, o, w);
}

test "offsets: a planted bad lane matchup lowers the 10th percentile and the mean" {
    const gpa = testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const games = try plantedGames(arena, 3000);
    var m: eval.Model = try .buildShipped(gpa, &planted_champs, games, &.{});
    defer m.deinit(gpa);
    const st = &m.stats;
    const off = try offsetsOf(arena, st, 10);
    const mid = @backingInt(Role.middle);
    const a = st.index(1).?;
    const b = st.index(2).?;
    const q10 = off[@backingInt(Variant.q10)][mid];
    const mean = off[@backingInt(Variant.mean)][mid];
    // Each of nine opponents weighs about 11%, so the 10th percentile is the worst matchup
    try testing.expectEqual(score.matchupLogit(st, .{}, .middle, a, .middle, b), q10[a]);
    try testing.expect(q10[a] < -0.5);
    try testing.expect(mean[a] < 0 and mean[b] > 0);
    for (0..st.n) |c| if (c != a) try testing.expect(q10[c] > q10[a]);
    // Top lane has no planted effect: every offset there is small
    for (off[@backingInt(Variant.q10)][@backingInt(Role.top)]) |x| try testing.expect(x > -0.5);
}

test "summary: paired gap and AUC differences, their intervals against a jackknife" {
    const gpa = testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var rng: std.Random.DefaultPrng = .init(9);
    const rnd = rng.random();
    const n_games = 300;
    const games = try arena.alloc(Game, n_games);
    const pct = try arena.alloc([nv]f32, n_games * 2 * Role.count);
    for (games, 0..) |*g, gi| {
        g.* = .{
            .id = gi,
            .start = @intCast(gi),
            .patch = 0,
            .platform = 0,
            .teams = @splat(@splat(0)),
            .winner = rnd.int(u1),
        };
        // A game-level shift shared by its seats, in the differences too (winners'), so
        // clustering by game matters
        const shift = 0.2 * rnd.float(f32);
        for (0..2) |s| for (0..Role.count) |r| {
            const p = &pct[(gi * 2 + s) * Role.count + r];
            const won: f32 = if (g.winner == s) 1 else 0;
            p[0] = @min(1, 0.8 * rnd.float(f32) + shift);
            for (p[1..], 1..) |*x, vi| {
                const vf: f32 = @floatFromInt(vi);
                x.* = p[0] + 0.05 * vf * (rnd.float(f32) - 0.5) + 0.01 * vf * won +
                    0.3 * vf * shift * won;
            }
        };
    }
    pct[3] = @splat(std.math.nan(f32));
    const sum = try summarise(gpa, games, pct);
    try testing.expectEqual(1, sum.unranked);
    try testing.expectEqual(n_games * 10 - 1, sum.picks);
    const q = try arena.alloc(f64, sum.picks);
    const won = try arena.alloc(bool, sum.picks);
    // The per-game sums give each difference exactly; jackknife by game for the spread
    const sub_pct = try arena.alloc([nv]f32, pct.len - 10);
    for (1..nv) |vi| {
        const row = sum.rows[vi];
        try testing.expectApproxEqAbs(row.gap() - sum.rows[0].gap(), row.gap_vs.diff, 1e-9);
        var k: usize = 0;
        for (games, 0..) |g, gi| for (0..2) |s| for (0..Role.count) |r| {
            const p = pct[(gi * 2 + s) * Role.count + r];
            if (std.math.isNan(p[0])) continue;
            q[k] = p[vi];
            won[k] = g.winner == s;
            k += 1;
        };
        try testing.expectApproxEqAbs(try eval.auc(gpa, q, won, null), row.auc, 1e-12);
        try testing.expectApproxEqAbs(row.auc - sum.rows[0].auc, row.auc_vs.diff, 1e-12);
    }
    // Seats as if independent: the gap difference's SE from the seats' spread alone
    var seat_se: [nv]f64 = undefined;
    for (1..nv) |vi| {
        var sum_d: [2]f64 = .{ 0, 0 };
        var ss_d: [2]f64 = .{ 0, 0 };
        var count: [2]f64 = .{ 0, 0 };
        for (games, 0..) |g, gi| for (0..2) |s| for (0..Role.count) |r| {
            const p = pct[(gi * 2 + s) * Role.count + r];
            if (std.math.isNan(p[0])) continue;
            const d: f64 = p[vi] - p[0];
            const c = @intFromBool(g.winner == s);
            sum_d[c] += d;
            ss_d[c] += d * d;
            count[c] += 1;
        };
        var v: f64 = 0;
        for (0..2) |c| {
            const mean = sum_d[c] / count[c];
            v += (ss_d[c] / count[c] - mean * mean) / count[c];
        }
        seat_se[vi] = @sqrt(v);
    }
    var jack: [nv][2]f64 = @splat(.{ 0, 0 });
    var jack_ss: [nv][2]f64 = @splat(.{ 0, 0 });
    for (0..n_games) |drop| {
        @memcpy(sub_pct[0 .. drop * 10], pct[0 .. drop * 10]);
        @memcpy(sub_pct[drop * 10 ..], pct[(drop + 1) * 10 ..]);
        const sub_games = try std.mem.concat(arena, Game, &.{ games[0..drop], games[drop + 1 ..] });
        const s = try summarise(gpa, sub_games, sub_pct);
        for (1..nv) |vi| {
            const d = [2]f64{ s.rows[vi].gap() - s.rows[0].gap(), s.rows[vi].auc - s.rows[0].auc };
            for (0..2) |m| {
                jack[vi][m] += d[m];
                jack_ss[vi][m] += d[m] * d[m];
            }
        }
    }
    const n: f64 = n_games;
    for (1..nv) |vi| for (0..2) |m| {
        const mean = jack[vi][m] / n;
        const se = @sqrt((n - 1) / n * (jack_ss[vi][m] - n * mean * mean));
        const half = if (m == 0) sum.rows[vi].gap_vs.half else sum.rows[vi].auc_vs.half;
        const ratio = half / 1.96 / se;
        try testing.expect(ratio > 0.85 and ratio < 1.15);
        if (m == 0) try testing.expect(seat_se[vi] < 0.7 * se);
    };
}

test "summary and run: too few games is an error, not NaN or a panic" {
    const gpa = testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const games = try plantedGames(arena, 400);
    const pct = try arena.alloc([nv]f32, 2 * 10);
    @memset(pct, @splat(std.math.nan(f32)));
    try testing.expectError(error.TooFewGames, summarise(gpa, games[0..2], pct));

    var discard: Io.Writer.Discarding = .init(&.{});
    var o: eval.Options = .{ .cuts = .{ .test_ = 0, .dev = 0, .bounds = @splat(0) } };
    try testing.expectError(error.TooFewGames, runPlanted(games, o, &discard.writer));
    o.cuts.?.test_ = games[games.len - 1].start;
    try testing.expectError(error.TooFewGames, runPlanted(games, o, &discard.writer));

    // No candidate champion-role: refused before the offsets table prints a NaN
    var out: Io.Writer.Allocating = .init(arena);
    const none: eval.Options = .{ .pick_min_games = std.math.maxInt(u32) };
    try testing.expectError(error.TooFewGames, runPlanted(games, none, &out.writer));
    try testing.expect(std.mem.indexOf(u8, out.written(), "nan") == null);
}

test "offset table: offsets that don't vary print no correlation, not NaN" {
    const gpa = testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const games = try plantedGames(arena, 400);
    var m: eval.Model = try .buildShipped(gpa, &planted_champs, games, &.{});
    defer m.deinit(gpa);
    var off: Offsets = undefined;
    for (&off) |*per_role| for (per_role) |*x| {
        x.* = try arena.alloc(f64, m.stats.n);
        @memset(x.*, 0);
    };
    var out: Io.Writer.Allocating = .init(arena);
    try offsetTable(&out.writer, &m.stats, &off, 10);
    try testing.expect(std.mem.indexOf(u8, out.written(), "nan") == null);
    try testing.expectEqual(nv - 1, std.mem.count(u8, out.written(), " - |\n"));
}

test "run on planted games: every table filled, the planted matchup in the offsets" {
    const gpa = testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const games = try plantedGames(arena, 1500);
    for ([_]bool{ true, false }) |dev| {
        var out: Io.Writer.Allocating = .init(arena);
        try runPlanted(games, .{ .dev = dev }, &out.writer);
        const text = out.written();
        try testing.expect(std.mem.indexOf(u8, text, if (dev) "Dev-val: " else "Test: ") != null);
        for (scenarios) |sc| try testing.expect(std.mem.indexOf(u8, text, sc.label()) != null);
        try testing.expect(std.mem.indexOf(u8, text, "nan") == null);
        try testing.expect(std.mem.indexOf(u8, text, "inf") == null);
        // Header, two scenarios: one row per ranking each, five offsets
        try testing.expectEqual(2 * (2 + nv) + 2 + nv - 1, std.mem.count(u8, text, "\n| "));
    }
}
