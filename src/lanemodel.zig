//! `meiolol lane-model`: the admin Draft tester's lane model (src/lab/cand/team2, 3c-team2:
//! early outcomes for a champion into a lane opponent) on every played game in the
//! database, every platform and patch, as lane-model.json and lane-ref.json (lanefile.zig,
//! docs/model.md "Lane model file"). Daily on the box (deploy/web-loop.sh), as
//! `meiolol-lab lane --export` does from a snapshot. Rows as the lab's (lab/rowsql.zig):
//! gold at 14 from participants (the timeline's when missing), lane gold difference at 14,
//! CS at 10 and deaths before 15 from the timeline, each only for a game whose timeline
//! reached 15:00; held compactly (team2.LaneRow), about 0.5 GB for 800k games

const std = @import("std");
const store = @import("store");
const core = @import("core");
const api = @import("api");
const team2 = @import("team2");
const stats = @import("stats.zig");
const eval = @import("eval.zig");
const analysis = @import("analysis.zig");
const digest = @import("riot/digest.zig");
const protocol = @import("lab/protocol.zig");
const harness = @import("lab/harness.zig");
const lf = @import("lanefile.zig");
const Date = @import("date.zig").Date;
const Time = @import("date.zig").Time;

const n_lane = lf.n_lane;
const no_row = std.math.maxInt(u32);

comptime {
    for (team2.lane_outcomes, lf.outcomes) |o, name| std.debug.assert(std.mem.eql(u8, @tagName(o), name));
}

/// Played games oldest first, their rows in match id and slot order (the lab's)
const Data = struct {
    games: []team2.LaneGame,
    starts: []i64,
    rows: []team2.LaneRow,
    /// Champion id per row, for the dev score's baseline
    champions: []u32,
};

pub fn run(gpa: std.mem.Allocator, io: std.Io, db: store.Db, dir: []const u8, w: *std.Io.Writer) !void {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const now_ms = std.Io.Clock.real.now(io).toMilliseconds();
    const ids = protocol.platformIds();
    const eu: u8 = for (ids, 0..) |id, i| {
        if (std.mem.eql(u8, id, protocol.home_platform)) break @intCast(i);
    } else unreachable;

    const d = try load(gpa, io, arena, db, &ids);
    try w.print("{d} played games, {d} rows\n", .{ d.games.len, d.rows.len });
    try w.flush();
    const cuts = try eval.cutsOf(d.starts, .{});

    var m = try team2.fitLane(gpa, d.games, d.rows);
    defer team2.deinit(&m, gpa);
    const ex = try lf.rounded(arena, try team2.exportLane(&m, arena, eu, lf.min_pair_games));
    const sc = try lf.Scorer.init(arena, ex);
    try w.print("lane model fitted on {d} games: {d} champion terms, {d} enemy terms, {d} pairs\n", .{ d.games.len, ex.champ.len, ex.enemy.len, ex.pairs.len });

    // As the lab: with the other slots unseen (their cells 0), predict is exactly
    // intercept + the three lane terms, each rounded to 0.01
    var worst: [n_lane]f64 = @splat(0);
    var checked: usize = 0;
    for (ex.pairs, 0..) |p, i| {
        if (i % 7 != 0) continue;
        const other = ex.pairs[(i * 31 + 5) % ex.pairs.len];
        for ([_][2]u32{ .{ p.champion, p.enemy }, .{ p.champion, other.enemy } }) |ce| {
            const v = sc.value(p.role, ce[0], ce[1], false);
            for (team2.lane_outcomes, 0..) |o, oi| {
                const want = team2.laneOnly(&m, o, @fromBackingInt(@as(u3, @intCast(p.role))), ce[0], ce[1], eu, ex.patch);
                worst[oi] = @max(worst[oi], @abs(v.value[oi] - want));
            }
            checked += 1;
        }
    }
    try w.print("file vs model on {d} lane slots: max |diff|", .{checked});
    for (lf.outcomes, worst) |o, x| try w.print(" {s} {e}", .{ o, x });
    try w.writeAll("\n");
    for (worst) |x| if (x > 0.05) return error.ExportDisagrees;
    team2.deinit(&m, gpa);
    m = .{};

    const dev = try devScore(gpa, &d, cuts);
    for (dev) |x| try w.print("dev {s}: typical miss {d:.2} -> {d:.2} {s} ({d:.2}% of the error removed, ±{d:.2})\n", .{ x.outcome, x.err_base, x.err_cand, x.unit, x.removed_pct, x.removed_half });
    const range = try lf.patchRange(arena, d.games);
    try lf.write(arena, io, &sc, .{
        .name = team2.name,
        .run = try arena.print("{f}", .{Time.fromMs(now_ms).minutes()}),
        .snapshot = "box database",
        .newest_game = try arena.print("{f}", .{Date.fromMs(d.starts[d.starts.len - 1])}),
        .training_games = d.games.len,
        .patch = try lf.patchLabel(arena, ex.patch),
        .oldest_patch = range[0],
        .newest_patch = range[1],
        .platform = protocol.home_platform,
        .dev = &dev,
    }, try lf.championList(arena, db), dir, w);
}

fn load(gpa: std.mem.Allocator, io: std.Io, arena: std.mem.Allocator, db: store.Db, ids: []const []const u8) !Data {
    var list: analysis.GameList = .{ .gpa = gpa };
    defer list.items.deinit(gpa);
    _ = try stats.scanAhead(gpa, io, db, try stats.patches(arena, db, ids), ids, 0, &list);
    var played: std.ArrayList(stats.Row) = .empty;
    defer played.deinit(gpa);
    for (list.items.items) |g| if (g.duration_s >= eval.min_duration_s) try played.append(gpa, g);
    std.mem.sort(stats.Row, played.items, {}, struct {
        fn f(_: void, a: stats.Row, b: stats.Row) bool {
            return a.start < b.start;
        }
    }.f);
    const n = played.items.len;
    var d: Data = .{ .games = try arena.alloc(team2.LaneGame, n), .starts = try arena.alloc(i64, n), .rows = &.{}, .champions = &.{} };
    var index: std.AutoHashMapUnmanaged(u64, u32) = .empty;
    defer index.deinit(gpa);
    try index.ensureTotalCapacity(gpa, @intCast(n));
    for (played.items, d.games, d.starts, 0..) |g, *lg, *s, i| {
        lg.* = .{ .teams = g.teams, .patch = g.patch, .platform = g.platform };
        s.* = g.start;
        index.putAssumeCapacity(g.id, @intCast(i));
    }

    // Row index by game and participant slot
    const slots = try gpa.alloc([10]u32, n);
    defer gpa.free(slots);
    @memset(slots, @splat(no_row));
    var rows: std.ArrayList(team2.LaneRow) = .empty;
    var champions: std.ArrayList(u32) = .empty;
    try rows.ensureTotalCapacity(arena, 10 * n);
    try champions.ensureTotalCapacity(arena, 10 * n);
    {
        var q = try db.prepare("SELECT match_id, slot, team_id, position, champion_id, gold14 FROM participants ORDER BY match_id, slot");
        defer q.deinit();
        try q.bind(.{});
        // The whole table in key order, its pages scattered on disk
        const ahead: *store.Ahead = try .start(gpa, io, db, .{
            .list = "SELECT match_id, NULL FROM matches ORDER BY match_id",
            .reads = &.{"SELECT slot FROM participants WHERE match_id = ?1"},
        }, .{});
        defer ahead.stop();
        while (try q.step()) {
            if (q.int(1) == 0) ahead.next();
            const gi = index.get(stats.matchKey(q.bytes(0))) orelse continue;
            const role = core.Role.fromLcu(q.bytes(3)) orelse continue;
            const slot: usize = @intCast(q.int(1));
            var y: [n_lane]f32 = @splat(std.math.nan(f32));
            if (q.optInt(5)) |gold| y[0] = @floatFromInt(gold);
            if (slot < 10) slots[gi][slot] = @intCast(rows.items.len);
            try rows.append(arena, .{ .game = gi, .side = if (q.int(2) == 100) 0 else 1, .role = @fromBackingInt(@backingInt(role)), .y = y });
            try champions.append(arena, @intCast(q.int(4)));
        }
    }

    // Timeline outcomes: frame t is minute t (frame 0 at the start)
    const reached = try gpa.alloc(bool, n);
    defer gpa.free(reached);
    @memset(reached, false);
    var tl_arena: std.heap.ArenaAllocator = .init(gpa);
    defer tl_arena.deinit();
    {
        // The played games' timelines, then read in rowid order: their digests' order
        const Stored = struct { source: i64, game: u32, match_id: []const u8 };
        var stored: std.ArrayList(Stored) = .empty;
        defer stored.deinit(gpa);
        {
            var q = try db.prepare("SELECT match_id, rowid FROM timeline.timelines");
            defer q.deinit();
            try q.bind(.{});
            while (try q.step()) {
                const gi = index.get(stats.matchKey(q.bytes(0))) orelse continue;
                try stored.append(gpa, .{ .source = q.int(1), .game = gi, .match_id = try arena.dupe(u8, q.bytes(0)) });
            }
        }
        std.mem.sortUnstable(Stored, stored.items, {}, struct {
            fn f(_: void, a: Stored, b: Stored) bool {
                return a.source < b.source;
            }
        }.f);
        var source: digest.Source = try .init(db);
        defer source.deinit();
        for (stored.items) |st| {
            const gi = st.game;
            _ = tl_arena.reset(.retain_capacity);
            const ta = tl_arena.allocator();
            const t = source.lookup(ta, st.source, st.match_id) catch continue;
            if (!protocol.reached15Timeline(t)) continue;
            reached[gi] = true;
            var deaths: [10]f32 = @splat(0);
            for (t.events) |e| switch (e.data) {
                .champion_kill => |k| if (e.t_ms < 15 * 60_000 and k.victim >= 1 and k.victim <= 10) {
                    deaths[k.victim - 1] += 1;
                },
                else => {},
            };
            for (slots[gi], 0..) |ri, i| {
                if (ri == no_row) continue;
                const r = &rows.items[ri];
                const pid: u8 = @intCast(i + 1);
                r.y[2] = @floatFromInt(t.frames[10].get(pid, .minions) + t.frames[10].get(pid, .jungle_minions));
                r.y[3] = deaths[i];
                if (std.math.isNan(r.y[0])) r.y[0] = @floatFromInt(t.frames[14].get(pid, .total_gold));
            }
        }
    }
    // Lane gold difference: same role, other side; participants.gold14 exists for games
    // that ended before 15:00 too, and the protocol scores only games that reached it
    for (slots, reached) |sl, ok| {
        for (sl) |ri| {
            if (ri == no_row) continue;
            const r = &rows.items[ri];
            if (!ok) {
                r.y[0] = std.math.nan(f32);
                continue;
            }
            for (sl) |oi| if (oi != no_row) {
                const o = rows.items[oi];
                if (o.side != r.side and o.role == r.role) r.y[1] = r.y[0] - o.y[0];
            };
        }
    }
    d.rows = rows.items;
    d.champions = champions.items;
    return d;
}

/// Refitted on the played games older than dev-val, scored on dev-val against each
/// champion-role's mean on the same rows, per outcome in role sds and paired by game, as
/// the lab's (harness.score's dev phase)
fn devScore(gpa: std.mem.Allocator, d: *const Data, cuts: eval.Cuts) ![n_lane]lf.DevOut {
    var older: usize = 0;
    while (older < d.starts.len and d.starts[older] < cuts.dev) older += 1;
    var visible: std.ArrayList(team2.LaneRow) = .empty;
    defer visible.deinit(gpa);
    const Mean = struct { n: [n_lane]f64 = @splat(0), sum: [n_lane]f64 = @splat(0), sumsq: [n_lane]f64 = @splat(0) };
    var cells: std.AutoHashMapUnmanaged(u64, Mean) = .empty;
    defer cells.deinit(gpa);
    var roles: [lf.n_role]Mean = @splat(.{});
    for (d.rows, d.champions) |r, c| {
        if (r.game >= older) continue;
        try visible.append(gpa, r);
        const e = try cells.getOrPut(gpa, (@as(u64, c) << 3) | @backingInt(r.role));
        if (!e.found_existing) e.value_ptr.* = .{};
        for (r.y, 0..) |y, k| if (!std.math.isNan(y)) {
            for ([_]*Mean{ e.value_ptr, &roles[@backingInt(r.role)] }) |mn| {
                mn.n[k] += 1;
                mn.sum[k] += y;
                mn.sumsq[k] += y * y;
            }
        };
    }
    var m = try team2.fitLane(gpa, d.games[0..older], visible.items);
    defer team2.deinit(&m, gpa);
    var sd: [lf.n_role][n_lane]f64 = undefined;
    for (roles, &sd) |rc, *o| for (o, 0..) |*s, k| {
        const mean = if (rc.n[k] > 0) rc.sum[k] / rc.n[k] else 0;
        const v = if (rc.n[k] > 1) (rc.sumsq[k] - rc.n[k] * mean * mean) / (rc.n[k] - 1) else 1;
        s.* = if (v > 0) @sqrt(v) else 1;
    };

    var game: std.ArrayList(u32) = .empty;
    defer game.deinit(gpa);
    var role_of: std.ArrayList(u8) = .empty;
    defer role_of.deinit(gpa);
    var la: [n_lane]std.ArrayList(f64) = @splat(.empty);
    var lb: [n_lane]std.ArrayList(f64) = @splat(.empty);
    defer for (&la, &lb) |*a, *b| {
        a.deinit(gpa);
        b.deinit(gpa);
    };
    for (d.rows, d.champions) |r, c| {
        if (r.game < older or d.starts[r.game] >= cuts.test_) continue;
        const g = d.games[r.game];
        const q: api.Query = .{ .start = d.starts[r.game], .patch = g.patch, .platform = g.platform, .side = r.side, .role = r.role, .champion = c, .rank = null, .teams = g.teams, .ranks = null, .exp = .{}, .exps = null };
        const pred = team2.predict(&m, &q);
        const ri = @backingInt(r.role);
        const rc = roles[ri];
        const cell = cells.get((@as(u64, c) << 3) | ri) orelse Mean{};
        try game.append(gpa, r.game);
        try role_of.append(gpa, ri);
        for (team2.lane_outcomes, 0..) |o, k| {
            const y = r.y[k];
            const base = if (cell.n[k] > 0) cell.sum[k] / cell.n[k] else if (rc.n[k] > 0) rc.sum[k] / rc.n[k] else 0;
            const p: f64 = pred[api.outcomeIndex(o)];
            try la[k].append(gpa, if (std.math.isNan(y)) std.math.nan(f64) else harness.loss(api.outcomeIndex(o), y, p, sd[ri][k]));
            try lb[k].append(gpa, if (std.math.isNan(y)) std.math.nan(f64) else harness.loss(api.outcomeIndex(o), y, base, sd[ri][k]));
        }
    }
    var out: [n_lane]lf.DevOut = undefined;
    for (&out, 0..) |*o, k| {
        const p = harness.paired(game.items, la[k].items, lb[k].items, null);
        // Squared errors in role sd, scaled back per row
        var sa: f64 = 0;
        var sb: f64 = 0;
        var n: f64 = 0;
        for (la[k].items, lb[k].items, role_of.items) |a, b, ri| {
            if (std.math.isNan(a) or std.math.isNan(b)) continue;
            const s = sd[ri][k];
            sa += a * s * s;
            sb += b * s * s;
            n += 1;
        }
        o.* = .{
            .outcome = lf.outcomes[k],
            .unit = lf.units[k],
            .rows = p.n,
            .err_base = @sqrt(sb / @max(n, 1)),
            .err_cand = @sqrt(sa / @max(n, 1)),
            // 0 when the baseline is exact (fixtures): JSON has no infinities
            .removed_pct = if (p.b > 0) -100 * p.diff / p.b else 0,
            .removed_half = if (p.b > 0 and std.math.isFinite(p.half)) 100 * p.half / p.b else 0,
        };
    }
    return out;
}
