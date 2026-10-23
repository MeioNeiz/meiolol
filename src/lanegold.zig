//! Lane gold at 14 minutes as a draft signal, for eval. A game's result is one noisy
//! bit; its lane gold differences are five much less noisy numbers, so champion and
//! matchup lane strength need fewer games measured in gold than in wins.
//!
//! Champion gold: a champion's mean lane gold difference in a role against everyone,
//! shrunk toward 0. Pair gold: a lane pair's mean minus what the two champions' gold
//! predicts, shrunk toward 0. Both shrink by empirical Bayes (method of moments, as
//! score.empiricalPriors). In standard deviations of the role's gold difference, so
//! roles compare (supports trade far less gold than mid laners).

const std = @import("std");
const store = @import("store");
const core = @import("core");
const timeline = @import("riot/timeline.zig");
const stats = @import("stats.zig");
const analysis = @import("analysis.zig");
const Role = core.Role;

pub const minute = core.curvesfile.lane_minute;

/// Blue's laner minus red's, total gold at `minute`, per role
pub const Lanes = [Role.count]f32;

pub const Map = std.AutoHashMapUnmanaged(u64, Lanes);

/// Lane gold for every game on `chosen` patches and `platforms` with a timeline long
/// enough, keyed by stats.matchKey. Caller deinits
pub fn load(
    gpa: std.mem.Allocator,
    db: store.Db,
    chosen: []const []const u8,
    platforms: []const []const u8,
) !Map {
    var games: analysis.TimelineGames = try .init(gpa, db, chosen, platforms);
    defer games.deinit();
    var map: Map = .empty;
    errdefer map.deinit(gpa);
    while (try games.next()) |g| {
        // Frame k is minute k; the last frame is the game's end, part of a minute
        if (g.t.frames.len < minute + 2) continue;
        const pid = try games.pids(g) orelse continue;
        var lanes: Lanes = undefined;
        const f = g.t.frames[minute];
        for (Role.all) |r| {
            const ri = @backingInt(r);
            lanes[ri] = @floatFromInt(f.get(pid[0][ri], .total_gold) - f.get(pid[1][ri], .total_gold));
        }
        try map.put(gpa, stats.matchKey(g.match_id), lanes);
    }
    return map;
}

/// Cells with fewer games are left out of the spread estimates
const eb_min_games = 10;

/// Shrunk champion and pair gold, from some games
pub const Model = struct {
    n: usize,
    /// Standard deviation of the gold difference per role
    sd: [Role.count]f64,
    /// [role][champion]: shrunk mean in sds, from the champion's side
    champ: []f64,
    /// [role][a][b]: shrunk pair deviation in sds, from a's side
    pair: []f64,
    /// Prior strengths, games
    champ_prior: [Role.count]f64,
    pair_prior: [Role.count]f64,
    games: usize,

    pub fn deinit(m: *Model, gpa: std.mem.Allocator) void {
        gpa.free(m.champ);
        gpa.free(m.pair);
    }

    /// From `games` with lane gold in `map`, skipping fold `skip.k` of `skip.folds`
    pub fn build(
        gpa: std.mem.Allocator,
        st: *const core.Stats,
        games: []const stats.Row,
        map: *const Map,
        skip: ?struct { k: usize, folds: usize },
    ) !Model {
        const n = st.n;
        const Cell = struct { n: f64 = 0, sum: f64 = 0 };
        const champ_cells = try gpa.alloc(Cell, Role.count * n);
        defer gpa.free(champ_cells);
        @memset(champ_cells, .{});
        const pair_cells = try gpa.alloc(Cell, Role.count * n * n);
        defer gpa.free(pair_cells);
        @memset(pair_cells, .{});
        var sum_sq: [Role.count]f64 = @splat(0);
        var count: f64 = 0;

        for (games, 0..) |g, i| {
            if (skip) |s| if (i % s.folds == s.k) continue;
            const lanes = map.get(g.id) orelse continue;
            count += 1;
            for (Role.all, lanes) |r, gold| {
                const ri = @backingInt(r);
                const a = st.index(g.teams[0][ri]) orelse continue;
                const b = st.index(g.teams[1][ri]) orelse continue;
                const d: f64 = gold;
                sum_sq[ri] += d * d;
                addCell(&champ_cells[ri * n + a], d);
                addCell(&champ_cells[ri * n + b], -d);
                addCell(&pair_cells[(ri * n + a) * n + b], d);
                addCell(&pair_cells[(ri * n + b) * n + a], -d);
            }
        }

        var m: Model = .{
            .n = n,
            .sd = undefined,
            .champ = try gpa.alloc(f64, Role.count * n),
            .pair = try gpa.alloc(f64, Role.count * n * n),
            .champ_prior = undefined,
            .pair_prior = undefined,
            .games = @trunc(count),
        };
        errdefer m.deinit(gpa);
        @memset(m.pair, 0);
        for (Role.all) |r| {
            const ri = @backingInt(r);
            // Lane gold differences are centred on 0 by symmetry
            m.sd[ri] = if (count > 1) @sqrt(sum_sq[ri] / count) else 1;
            const sd = m.sd[ri];

            // Champion: observed mean in sds has noise variance about 1/n
            var champ_mom: Moments = .{};
            for (champ_cells[ri * n ..][0..n]) |c| champ_mom.add(c.n, c.sum / sd);
            m.champ_prior[ri] = champ_mom.prior();
            for (champ_cells[ri * n ..][0..n], m.champ[ri * n ..][0..n]) |c, *out| {
                out.* = c.sum / sd / (c.n + m.champ_prior[ri]);
            }

            // Pair: deviation from champ_a - champ_b
            var pair_mom: Moments = .{};
            for (0..n) |a| for (0..n) |b| {
                const c = pair_cells[(ri * n + a) * n + b];
                if (c.n == 0) continue;
                const expected = m.champ[ri * n + a] - m.champ[ri * n + b];
                pair_mom.add(c.n, c.sum / sd - c.n * expected);
            };
            m.pair_prior[ri] = pair_mom.prior();
            for (0..n) |a| for (0..n) |b| {
                const c = pair_cells[(ri * n + a) * n + b];
                if (c.n == 0) continue;
                const expected = m.champ[ri * n + a] - m.champ[ri * n + b];
                m.pair[(ri * n + a) * n + b] = (c.sum / sd - c.n * expected) / (c.n + m.pair_prior[ri]);
            };
        }
        return m;
    }

    fn addCell(c: anytype, d: f64) void {
        c.n += 1;
        c.sum += d;
    }

    /// Blue minus red: summed champion gold, summed pair gold (sds)
    pub fn features(m: *const Model, st: *const core.Stats, teams: [2][5]u32) [2]f64 {
        var out: [2]f64 = .{ 0, 0 };
        for (Role.all) |r| {
            const ri = @backingInt(r);
            const a = st.index(teams[0][ri]) orelse continue;
            const b = st.index(teams[1][ri]) orelse continue;
            out[0] += m.champ[ri * m.n + a] - m.champ[ri * m.n + b];
            out[1] += m.pair[(ri * m.n + a) * m.n + b];
        }
        return out;
    }
};

/// Method of moments for means of unit-variance draws: a cell of n games with sum s has
/// mean s/n, noise variance 1/n; spread = mean over cells of (s/n)^2 - 1/n; k = 1/spread
const Moments = struct {
    cells: f64 = 0,
    excess: f64 = 0,

    fn add(m: *Moments, n: f64, sum: f64) void {
        if (n < eb_min_games) return;
        const mean = sum / n;
        m.cells += 1;
        m.excess += mean * mean - 1 / n;
    }

    fn prior(m: Moments) f64 {
        if (m.cells < 100 or m.excess <= 0) return core.score.max_prior_games;
        return std.math.clamp(m.cells / m.excess, core.score.min_prior_games, core.score.max_prior_games);
    }
};

const testing = std.testing;

test "lane gold from a real timeline" {
    const gpa = testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const json = try store.raw.decompress(arena, @embedFile("riot/testdata/timeline.json.gz"));
    const t = try timeline.fromJson(arena, json);
    const blob = try store.raw.compress(arena, try timeline.encode(arena, t));

    const db = try store.schema.memory();
    defer db.close();
    try db.run("INSERT INTO matches VALUES ('EUW1_1','t','EUW1',420,'16.20','',0,1600,100,0)", .{});
    try db.run("INSERT INTO timeline.timelines VALUES ('EUW1_1',26,0,?)", .{store.Blob{ .bytes = blob }});
    const positions = [_][]const u8{ "TOP", "JUNGLE", "MIDDLE", "BOTTOM", "UTILITY" };
    for (0..10) |slot| {
        try db.run(
            \\INSERT INTO participants (match_id, slot, team_id, champion_id, position, win)
            \\VALUES ('EUW1_1',?,?,?,?,0)
        , .{ slot, @as(i64, if (slot < 5) 100 else 200), slot + 1, positions[slot % 5] });
    }

    var map = try load(gpa, db, &.{"16.20"}, &.{"EUW1"});
    defer map.deinit(gpa);
    try testing.expectEqual(1, map.count());
    const lanes = map.get(stats.matchKey("EUW1_1")).?;
    const f = t.frames[minute];
    // Mid: participant 3 (blue) against 8 (red)
    const want: f32 = @floatFromInt(f.get(3, .total_gold) - f.get(8, .total_gold));
    try testing.expectEqual(want, lanes[@backingInt(Role.middle)]);
}

test "champion gold shrinks toward zero" {
    const gpa = testing.allocator;
    const champs = [_]core.statsfile.Champion{
        .{ .id = 1, .name = "A" }, .{ .id = 2, .name = "B" }, .{ .id = 3, .name = "C" },
    };
    var b: core.statsfile.Builder = try .init(gpa, &champs);
    defer b.deinit();
    var aw: std.Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();
    try b.write(&aw.writer, "t");
    var st: core.Stats = try .parse(gpa, aw.written());
    defer st.deinit(gpa);

    // A tops 400 games against B (+500 gold); C one game (+500): too few for spread
    // estimates (under 100 cells), so priors are at the cap and both shrink to ~0,
    // A far less than C relative to their games
    var games: [401]stats.Row = undefined;
    var map: Map = .empty;
    defer map.deinit(gpa);
    for (&games, 0..) |*g, i| {
        const blue: u32 = if (i == 400) 3 else 1;
        g.* = .{ .id = i, .start = 0, .patch = 0, .platform = 0, .teams = .{ .{ blue, 0, 0, 0, 0 }, .{ 2, 0, 0, 0, 0 } }, .winner = 0 };
        try map.put(gpa, i, .{ 500, 0, 0, 0, 0 });
    }
    var m: Model = try .build(gpa, &st, &games, &map, null);
    defer m.deinit(gpa);
    try testing.expectEqual(401, m.games);
    const a = st.index(1).?;
    const c = st.index(3).?;
    try testing.expect(m.champ[a] > 0);
    try testing.expect(m.champ[a] > 100 * m.champ[c]);
    const f = m.features(&st, games[0].teams);
    try testing.expect(f[0] > 0);
}
