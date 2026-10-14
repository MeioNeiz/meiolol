//! `meiolol-lab lane SNAP --export DIR`: the compiled-in candidate's lane model
//! (exportLane, today src/lab/cand/team2) for the admin Draft tester's champion suggester:
//! early outcomes for a champion into a lane opponent (docs/model.md "Lane model file").
//! Fits once on every game; checks the export against the model; writes
//! DIR/lane-model.json and DIR/lane-ref.json. Champion-only inputs; admin only

const std = @import("std");
const api = @import("api");
const cand = @import("cand");
const store = @import("store");
const rows = @import("rows.zig");
const harness = @import("harness.zig");
const protocol = @import("protocol.zig");

const Io = std.Io;

pub const usage =
    \\  lane SNAP --export DIR          write DIR/lane-model.json and DIR/lane-ref.json: the
    \\                                  compiled-in candidate's early outcomes per champion
    \\                                  into a lane opponent (-Dcand=src/lab/cand/team2)
    \\
;

const n_role = 5;
/// Every lane pair with a training game: thin pairs' shrunk cells are small but real (the
/// lane embeddings' gain over 3c-team was all in matchups under ~100 games)
const min_pair_games = 1;
const z95 = 1.96;
const n_lane = cand.lane_outcomes.len;

/// The reference scorer, from exported parameters only: what the page's JS must match
const Scorer = struct {
    ex: cand.LaneExport,
    champ: std.AutoHashMapUnmanaged(u64, cand.LaneTerm) = .empty,
    enemy: std.AutoHashMapUnmanaged(u64, cand.LaneTerm) = .empty,
    pairs: std.AutoHashMapUnmanaged(u64, cand.LaneTerm) = .empty,

    fn key(role: u8, champion: u32, enemy: u32) u64 {
        return (@as(u64, champion) << 32) | (@as(u64, enemy) << 3) | role;
    }

    fn init(arena: std.mem.Allocator, ex: cand.LaneExport) !Scorer {
        var s: Scorer = .{ .ex = ex };
        for (ex.champ) |t| try s.champ.put(arena, key(t.role, t.champion, 0), t);
        for (ex.enemy) |t| try s.enemy.put(arena, key(t.role, t.champion, 0), t);
        for (ex.pairs) |t| try s.pairs.put(arena, key(t.role, t.champion, t.enemy), t);
        return s;
    }

    const Value = struct {
        value: [n_lane]f64,
        lo: [n_lane]f64,
        hi: [n_lane]f64,
        champ_games: u32,
        pair_games: u32,
    };

    /// docs/model.md "Lane model file": intercept + others + champ + enemy + pair, a
    /// missing term 0; the interval from the three terms' sds, as independent
    fn value(s: *const Scorer, role: u8, champion: u32, enemy: u32, with_others: bool) Value {
        const terms = [_]?cand.LaneTerm{
            s.champ.get(key(role, champion, 0)),
            s.enemy.get(key(role, enemy, 0)),
            s.pairs.get(key(role, champion, enemy)),
        };
        var v: Value = .{ .value = undefined, .lo = undefined, .hi = undefined, .champ_games = if (terms[0]) |t| t.n else 0, .pair_games = if (terms[2]) |t| t.n else 0 };
        for (0..n_lane) |oi| {
            var x = s.ex.intercept[oi][role] + if (with_others) s.ex.others[oi][role] else 0;
            var vr: f64 = 0;
            for (terms) |maybe| if (maybe) |t| {
                x += t.b[oi];
                vr += t.sd[oi] * t.sd[oi];
            };
            v.value[oi] = x;
            v.lo[oi] = x - z95 * @sqrt(vr);
            v.hi[oi] = x + z95 * @sqrt(vr);
        }
        return v;
    }
};

pub fn main(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: Io, argv: []const []const u8) !u8 {
    if (argv.len != 3 or !std.mem.eql(u8, argv[1], "--export")) {
        std.debug.print("usage:\n{s}", .{usage});
        return 2;
    }
    if (!@hasDecl(cand, "exportLane")) {
        std.debug.print("lane: the candidate has no exportLane (src/lab/cand/team2 has)\n", .{});
        return 2;
    }
    const snap = argv[0];
    const dir = argv[2];
    var out_buf: [16 * 1024]u8 = undefined;
    var out_file = Io.File.stdout().writer(io, &out_buf);
    const w = &out_file.interface;
    defer w.flush() catch {};

    var legendaries = try rows.loadLegendaries(gpa, io, snap);
    defer legendaries.deinit(gpa);
    var data = try rows.load(gpa, snap, &legendaries);
    defer data.deinit();
    const eu = euIndex();

    var train_arena: std.heap.ArenaAllocator = .init(gpa);
    defer train_arena.deinit();
    const t = try trainOf(train_arena.allocator(), &data);
    var m = try harness.fit(cand, gpa, &t, .{});
    defer cand.deinit(&m, gpa);
    const ex = try rounded(arena, try cand.exportLane(&m, arena, eu, min_pair_games));
    const sc = try Scorer.init(arena, ex);
    try w.print("lane model fitted on {d} games: {d} champion terms, {d} enemy terms, {d} pairs ({d}+ games)\n", .{
        t.games.len, ex.champ.len, ex.enemy.len, ex.pairs.len, min_pair_games,
    });

    // The export against the model: with the other slots unseen (their cells 0), predict
    // is exactly intercept + the three lane terms
    var worst: [n_lane]f64 = @splat(0);
    var checked: usize = 0;
    for (ex.pairs, 0..) |p, i| {
        if (i % 7 != 0) continue;
        // Every 7th pair, and its champion into a different opponent (often no pair cell)
        const other = ex.pairs[(i * 31 + 5) % ex.pairs.len];
        for ([_][2]u32{ .{ p.champion, p.enemy }, .{ p.champion, other.enemy } }) |ce| {
            const v = sc.value(p.role, ce[0], ce[1], false);
            for (cand.lane_outcomes, 0..) |o, oi| {
                const want = cand.laneOnly(&m, o, @fromBackingInt(@as(u3, @intCast(p.role))), ce[0], ce[1], eu, ex.patch);
                worst[oi] = @max(worst[oi], @abs(v.value[oi] - want));
            }
            checked += 1;
        }
    }
    try w.print("export vs candidate on {d} lane slots: max |diff|", .{checked});
    for (cand.lane_outcomes, worst) |o, x| try w.print(" {t} {e}", .{ o, x });
    try w.writeAll("\n");
    // Three terms and the intercept, each rounded to 0.01
    for (worst) |x| if (x > 0.05) return error.ExportDisagrees;

    try w.print("dev score (refits on dev's games)...\n", .{});
    try w.flush();
    const dev = try devScore(gpa, &data);
    for (dev) |x| try w.print("dev {s}: typical miss {d:.2} -> {d:.2} {s} ({d:.2}% of the error removed, ±{d:.2})\n", .{ x.outcome, x.err_base, x.err_cand, x.unit, x.removed_pct, x.removed_half });

    const champions = try championList(gpa, arena, snap);
    var newest: i64 = 0;
    for (data.games) |g| newest = @max(newest, g.start);
    const model: ModelFile = .{
        .meta = .{
            .name = if (@hasDecl(cand, "name")) cand.name else "candidate",
            // "--export ." from a deploy/lab-run.sh run dir: the run is the dir's name
            .run = std.fs.path.basename(if (std.mem.eql(u8, dir, ".")) try std.process.currentPathAlloc(io, arena) else dir),
            .snapshot = std.fs.path.basename(snap),
            .newest_game = try dayOf(arena, newest),
            .training_games = t.games.len,
            .patch = try std.fmt.allocPrint(arena, "{d}.{d}", .{ ex.patch / 1000, ex.patch % 1000 }),
            .platform = protocol.home_platform,
            .dev = &dev,
        },
        .outcomes = outcomeNames(),
        .units = units(),
        .champions = champions,
        .intercept = ex.intercept,
        .others = ex.others,
        .spread = ex.spread,
        .champ = ex.champ,
        .enemy = ex.enemy,
        .pair_columns = pair_columns,
        .pairs = try pairRows(arena, ex.pairs),
    };

    // References: per role the 4 most played pairs, one of their champions into an
    // opponent with no pair cell, and an unknown champion
    var refs: std.ArrayList(Ref) = .empty;
    for (0..n_role) |r| {
        var top: [4]?cand.LaneTerm = @splat(null);
        for (ex.pairs) |p| {
            if (p.role != r) continue;
            var cur: cand.LaneTerm = p;
            for (&top) |*slot| {
                if (slot.* == null) {
                    slot.* = cur;
                    break;
                }
                if (cur.n > slot.*.?.n) std.mem.swap(cand.LaneTerm, &cur, &slot.*.?);
            }
        }
        const role: u8 = @intCast(r);
        for (top) |maybe| if (maybe) |p| try refs.append(arena, ref(&sc, "most played pair", role, p.champion, p.enemy));
        if (top[0]) |p| {
            const no_pair = for (ex.enemy) |e| {
                if (e.role == role and sc.pairs.get(Scorer.key(role, p.champion, e.champion)) == null and e.champion != p.champion) break e.champion;
            } else 0;
            try refs.append(arena, ref(&sc, "no pair cell: champion and opponent terms only", role, p.champion, no_pair));
            try refs.append(arena, ref(&sc, "unknown champion (id 0)", role, 0, p.enemy));
        }
    }

    try Io.Dir.cwd().createDirPath(io, dir);
    const model_json = try std.json.Stringify.valueAlloc(arena, model, .{});
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fs.path.join(arena, &.{ dir, "lane-model.json" }), .data = model_json });
    const ref_json = try std.json.Stringify.valueAlloc(arena, RefFile{ .refs = refs.items }, .{ .whitespace = .indent_1 });
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fs.path.join(arena, &.{ dir, "lane-ref.json" }), .data = ref_json });
    try w.print("wrote {s}/lane-model.json ({d} KB) and lane-ref.json ({d} KB)\n", .{ dir, model_json.len / 1024, ref_json.len / 1024 });
    return 0;
}

const ChampionOut = struct { id: u32, name: []const u8, alias: []const u8 };

const DevOut = struct {
    outcome: []const u8,
    unit: []const u8,
    rows: usize,
    err_base: f64,
    err_cand: f64,
    removed_pct: f64,
    removed_half: f64,
};

const ModelFile = struct {
    format: []const u8 = "meiolol-lane-model",
    version: u32 = 1,
    meta: struct {
        name: []const u8,
        run: []const u8,
        snapshot: []const u8,
        newest_game: []const u8,
        training_games: usize,
        patch: []const u8,
        platform: []const u8,
        dev: []const DevOut,
    },
    roles: [n_role][]const u8 = .{ "top", "jungle", "middle", "bottom", "utility" },
    outcomes: [n_lane][]const u8,
    units: [n_lane][]const u8,
    min_pair_games: u32 = min_pair_games,
    champions: []const ChampionOut,
    intercept: [n_lane][n_role]f64,
    others: [n_lane][n_role]f64,
    spread: [n_lane][n_role]f64,
    champ: []const cand.LaneTerm,
    enemy: []const cand.LaneTerm,
    pair_columns: [4 + 2 * n_lane][]const u8,
    /// Arrays in pair_columns order, to keep the file small
    pairs: []const PairRow,
};

const PairRow = struct { u32, u32, u8, u32, f64, f64, f64, f64, f64, f64, f64, f64 };

const pair_columns = blk: {
    var out: [4 + 2 * n_lane][]const u8 = undefined;
    out[0..4].* = .{ "champion", "enemy", "role", "n" };
    for (cand.lane_outcomes, 0..) |o, i| {
        out[4 + i] = "b_" ++ @tagName(o);
        out[4 + n_lane + i] = "sd_" ++ @tagName(o);
    }
    break :blk out;
};

fn pairRows(arena: std.mem.Allocator, terms: []const cand.LaneTerm) ![]const PairRow {
    comptime std.debug.assert(n_lane == 4);
    const out = try arena.alloc(PairRow, terms.len);
    for (out, terms) |*o, t| o.* = .{ t.champion, t.enemy, t.role, t.n, t.b[0], t.b[1], t.b[2], t.b[3], t.sd[0], t.sd[1], t.sd[2], t.sd[3] };
    return out;
}

/// Every number to 0.01 of its unit: the file is what the page scores with, so the
/// reference scorer reads the same rounded values
fn rounded(arena: std.mem.Allocator, ex: cand.LaneExport) !cand.LaneExport {
    var out = ex;
    for ([_]*[n_lane][n_role]f64{ &out.intercept, &out.others, &out.spread }) |a| for (a) |*row| for (row) |*x| {
        x.* = round2(x.*);
    };
    for ([_]*[]const cand.LaneTerm{ &out.champ, &out.enemy, &out.pairs }) |terms| {
        const copy = try arena.dupe(cand.LaneTerm, terms.*);
        for (copy) |*t| for (&t.b, &t.sd) |*b, *sd| {
            b.* = round2(b.*);
            sd.* = round2(sd.*);
        };
        terms.* = copy;
    }
    return out;
}

fn round2(x: f64) f64 {
    return @round(x * 100) / 100;
}

const Ref = struct {
    label: []const u8,
    role: u8,
    champion: u32,
    enemy: u32,
    value: [n_lane]f64,
    lo: [n_lane]f64,
    hi: [n_lane]f64,
    champ_games: u32,
    pair_games: u32,
};

const RefFile = struct {
    format: []const u8 = "meiolol-lane-ref",
    what: []const u8 = "Scorer.value with others: intercept + others + champ + enemy + pair per outcome; lo/hi = value -/+ 1.96 sqrt(sum of the present terms' sd^2)",
    refs: []const Ref,
};

fn ref(sc: *const Scorer, label: []const u8, role: u8, champion: u32, enemy: u32) Ref {
    var v = sc.value(role, champion, enemy, true);
    for ([_]*[n_lane]f64{ &v.value, &v.lo, &v.hi }) |a| for (a) |*x| {
        x.* = round2(x.*);
    };
    return .{ .label = label, .role = role, .champion = champion, .enemy = enemy, .value = v.value, .lo = v.lo, .hi = v.hi, .champ_games = v.champ_games, .pair_games = v.pair_games };
}

fn outcomeNames() [n_lane][]const u8 {
    var out: [n_lane][]const u8 = undefined;
    for (&out, cand.lane_outcomes) |*o, x| o.* = @tagName(x);
    return out;
}

fn units() [n_lane][]const u8 {
    var out: [n_lane][]const u8 = undefined;
    for (&out, cand.lane_outcomes) |*o, x| o.* = unitOf(x);
    return out;
}

fn unitOf(o: api.Outcome) []const u8 {
    return switch (o) {
        .gold14, .lanediff14 => "gold",
        .cs10 => "CS",
        .deaths15 => "deaths",
        .first_item => "min",
        .win => "% right",
    };
}

fn euIndex() u8 {
    for (protocol.platformIds(), 0..) |id, i| if (std.mem.eql(u8, id, protocol.home_platform)) return @intCast(i);
    unreachable;
}

/// A tool, not an evaluation: every game that reached 15:00 minutes, test games included
fn trainOf(a: std.mem.Allocator, d: *const rows.Data) !api.Train {
    const players = try harness.gamePlayers(a, d);
    const index = try a.alloc(u32, d.games.len);
    var games: std.ArrayList(api.Game) = .empty;
    for (d.games, players, index) |g, pl, *ix| {
        if (g.duration_s < harness.min_duration_s) continue;
        ix.* = @intCast(games.items.len);
        try games.append(a, .{ .start = g.start, .patch = g.patch, .platform = g.platform, .teams = g.teams, .ranks = pl.ranks, .exp = pl.exp });
    }
    var out: std.ArrayList(api.Row) = .empty;
    for (d.rows) |r| {
        if (d.games[r.game].duration_s < harness.min_duration_s) continue;
        try out.append(a, .{
            .game = index[r.game],
            .side = r.side,
            .role = @fromBackingInt(@backingInt(r.role)),
            .champion = r.champion,
            .rank = r.rank_start,
            .exp = harness.experience(r),
            .y = r.y,
        });
    }
    return .{ .games = games.items, .rows = out.items };
}

/// The candidate refitted on dev's visible games, scored on dev-val per lane outcome
fn devScore(gpa: std.mem.Allocator, d: *const rows.Data) ![n_lane]DevOut {
    const players = try harness.gamePlayers(gpa, d);
    defer gpa.free(players);
    const c = try harness.cuts(gpa, d);
    var s = try harness.score(cand, gpa, d, players, c, .dev, .{});
    defer s.deinit(gpa);
    var out: [n_lane]DevOut = undefined;
    for (&out, cand.lane_outcomes) |*o, x| {
        const k = api.outcomeIndex(x);
        const la = try s.losses(gpa, d, k, null, .cand);
        defer gpa.free(la);
        const lb = try s.losses(gpa, d, k, null, .base);
        defer gpa.free(lb);
        const p = harness.paired(s.game, la, lb, null);
        // As exp.zig's RESULT: losses are squared errors in role sd, scaled back per row
        var sa: f64 = 0;
        var sb: f64 = 0;
        var n: f64 = 0;
        for (la, lb, s.row) |a, b, ri| {
            if (std.math.isNan(a) or std.math.isNan(b)) continue;
            const sd = s.sd[@backingInt(d.rows[ri].role)][k];
            sa += a * sd * sd;
            sb += b * sd * sd;
            n += 1;
        }
        o.* = .{
            .outcome = @tagName(x),
            .unit = unitOf(x),
            .rows = p.n,
            .err_base = @sqrt(sb / @max(n, 1)),
            .err_cand = @sqrt(sa / @max(n, 1)),
            .removed_pct = -100 * p.diff / p.b,
            .removed_half = 100 * p.half / p.b,
        };
    }
    return out;
}

fn championList(gpa: std.mem.Allocator, arena: std.mem.Allocator, snap: []const u8) ![]const ChampionOut {
    const db = try store.schema.openReadOnly(gpa, snap);
    defer db.close();
    var out: std.ArrayList(ChampionOut) = .empty;
    var q = try db.prepare("SELECT id, name FROM champions ORDER BY name");
    defer q.deinit();
    try q.bind(.{});
    while (try q.step()) {
        const name = try arena.dupe(u8, q.bytes(1));
        var alias: std.ArrayList(u8) = .empty;
        for (name) |ch| if (std.ascii.isAlphanumeric(ch)) try alias.append(arena, std.ascii.toLower(ch));
        try out.append(arena, .{ .id = @intCast(q.int(0)), .name = name, .alias = alias.items });
    }
    return out.items;
}

fn dayOf(arena: std.mem.Allocator, ms: i64) ![]const u8 {
    const es: std.time.epoch.EpochSeconds = .{ .secs = @intCast(@divFloor(ms, 1000)) };
    const yd = es.getEpochDay().calculateYearDay();
    const md = yd.calculateMonthDay();
    return std.fmt.allocPrint(arena, "{d}-{d:0>2}-{d:0>2}", .{ yd.year, md.month.numeric(), md.day_index + 1 });
}

test "lane scorer: the documented formula on known parameters" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    if (!@hasDecl(cand, "exportLane")) return;
    var ex: cand.LaneExport = .{ .patch = 16020, .intercept = @splat(@splat(5000)), .others = @splat(@splat(10)), .spread = @splat(@splat(800)), .champ = &.{}, .enemy = &.{}, .pairs = &.{} };
    const b: [n_lane]f64 = @splat(100);
    const sd: [n_lane]f64 = @splat(30);
    ex.champ = &.{.{ .champion = 1, .role = 0, .n = 500, .b = b, .sd = sd }};
    ex.enemy = &.{.{ .champion = 2, .role = 0, .n = 400, .b = b, .sd = sd }};
    ex.pairs = &.{.{ .champion = 1, .enemy = 2, .role = 0, .n = 50, .b = b, .sd = sd }};
    const sc = try Scorer.init(arena, ex);
    const v = sc.value(0, 1, 2, true);
    try std.testing.expectApproxEqAbs(@as(f64, 5310), v.value[0], 1e-9);
    try std.testing.expectApproxEqAbs(@as(f64, 5310 - z95 * @sqrt(3 * 900.0)), v.lo[0], 1e-9);
    try std.testing.expectEqual(@as(u32, 50), v.pair_games);
    // No pair cell, unknown opponent: champion term only
    const u = sc.value(0, 1, 99, false);
    try std.testing.expectApproxEqAbs(@as(f64, 5100), u.value[0], 1e-9);
}
