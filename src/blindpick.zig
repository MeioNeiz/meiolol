//! `meiolol eval --blind`: J2's safe blind pick on held-out games (docs/model.md "Blind
//! pick ranking"). Same time split and shipped model as eval's pick metric, but my lane
//! opponent is hidden: the lane card ranks blind picks with no lane term, as if every
//! opponent were average. Variants add a per champion-role offset over the role's likely
//! opponents (every champion with pick_min_games train games in it, weighted by them):
//! the expected lane term, low quantiles of it, mean minus spread, and the J2 wording's
//! low end of the base rating's own uncertainty.
//!
//! Per test seat, each ranking's percentile of the champion actually picked; reports
//! winners' minus losers' mean percentile (± paired by game against today's ranking),
//! AUC and the win rate of picks in each ranking's top 10%. Two scenarios: the other
//! eight known, and allies only (no enemy picked yet).

const std = @import("std");
const store = @import("store");
const core = @import("core");
const stats = @import("stats.zig");
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
    var parts = try eval.split(gpa, list.items.items, platforms, opts);
    defer parts.deinit(gpa);
    const train = parts.train;
    const tests = parts.tests;

    const classes = try stats.kitClasses(gpa, db);
    defer gpa.free(classes);
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

    const seats = tests.len * 2 * Role.count;
    for (scenarios) |sc| {
        const pct = try gpa.alloc([nv]f32, seats);
        defer gpa.free(pct);
        try par.forEach(io, tests.len, Rank{
            .gpa = gpa,
            .st = st,
            .games = tests,
            .min_games = opts.pick_min_games,
            .offsets = &offsets,
            .scenario = sc,
            .pct = pct,
        }, Rank.game);
        try report(gpa, w, sc, tests, pct);
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
    /// Per seat (game, side, role); NaN when the pick was no candidate
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

fn report(
    gpa: std.mem.Allocator,
    w: *Io.Writer,
    sc: Scenario,
    games: []const Game,
    pct: []const [nv]f32,
) !void {
    var nw: f64 = 0;
    var nl: f64 = 0;
    var missed: usize = 0;
    for (games, 0..) |g, gi| for (0..2) |s| for (0..Role.count) |r| {
        const p = pct[(gi * 2 + s) * Role.count + r];
        if (std.math.isNan(p[0])) {
            missed += 1;
            continue;
        }
        if (g.winner == s) nw += 1 else nl += 1;
    };
    try w.print("\n## {s}\n\n{d} picks ({d} not candidates). Gap: winners' mean percentile " ++
        "minus losers' (1 = the ranking's top); ± 95% paired by game against today's.\n\n" ++
        "| ranking | winners | losers | gap | gap vs today | AUC | top 10% win |\n" ++
        "| --- | --- | --- | --- | --- | --- | --- |\n", .{
        sc.label(), @as(usize, @intFromFloat(nw + nl)), missed,
    });

    const q = try gpa.alloc(f64, @intFromFloat(nw + nl));
    defer gpa.free(q);
    const won = try gpa.alloc(bool, q.len);
    defer gpa.free(won);
    const per_game = try gpa.alloc(f64, games.len);
    defer gpa.free(per_game);
    for (variants, 0..) |v, vi| {
        var sw: f64 = 0;
        var sl: f64 = 0;
        var top_n: f64 = 0;
        var top_w: f64 = 0;
        var k: usize = 0;
        @memset(per_game, 0);
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
            // This seat's share of the gap's difference from today's ranking
            const d = x - p[0];
            per_game[gi] += if (win) d / nw else -d / nl;
        };
        const gap = sw / nw - sl / nl;
        try w.print("| {s} | {d:.4} | {d:.4} | {d:.4} |", .{ v.label(), sw / nw, sl / nl, gap });
        if (v == .current) try w.writeAll(" |") else {
            var total: f64 = 0;
            for (per_game) |x| total += x;
            const n: f64 = @floatFromInt(games.len);
            var ss: f64 = 0;
            for (per_game) |x| ss += (x - total / n) * (x - total / n);
            const se = @sqrt(n / (n - 1) * ss);
            const sign = if (total >= 0) "+" else "";
            try w.print(" {s}{d:.4} ± {d:.4} |", .{ sign, total, 1.96 * se });
        }
        const top: usize = @intFromFloat(top_n);
        try w.print(" {d:.4} | {d:.2}% of {d} |\n", .{
            try auc(gpa, q, won), 100 * top_w / @max(top_n, 1), top,
        });
    }
}

/// Mann-Whitney: chance a random winner's pick ranks above a random loser's; ties half
fn auc(gpa: std.mem.Allocator, p: []const f64, won: []const bool) !f64 {
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
        const avg = @as(f64, @floatFromInt(i + j - 1)) / 2 + 1;
        for (idx[i..j]) |k| if (won[k]) {
            rank_sum += avg;
            pos += 1;
        };
        i = j;
    }
    const neg = @as(f64, @floatFromInt(p.len)) - pos;
    if (pos == 0 or neg == 0) return 0.5;
    return (rank_sum - pos * (pos + 1) / 2) / (pos * neg);
}

test "weighted quantile" {
    const P = struct { x: f64, wt: f64 };
    const v = [_]P{ .{ .x = -1, .wt = 1 }, .{ .x = 0, .wt = 2 }, .{ .x = 1, .wt = 1 } };
    try std.testing.expectEqual(-1, quantile(&v, 4, 0.10));
    try std.testing.expectEqual(0, quantile(&v, 4, 0.5));
    try std.testing.expectEqual(1, quantile(&v, 4, 0.9));
}
