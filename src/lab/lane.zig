//! `meiolol-lab lane SNAP --export DIR`: the compiled-in candidate's lane model
//! (exportLane, today src/lab/cand/team2) for the admin Draft tester's champion suggester:
//! early outcomes for a champion into a lane opponent (docs/model.md "Lane model file").
//! Fits once on every game; checks the export against the model; writes
//! DIR/lane-model.json and DIR/lane-ref.json (lanefile.zig, shared with the box's
//! `meiolol lane-model`). Champion-only inputs; admin only

const std = @import("std");
const api = @import("api");
const cand = @import("cand");
const store = @import("store");
const rows = @import("rows.zig");
const harness = @import("harness.zig");
const protocol = @import("protocol.zig");
const lf = @import("../lanefile.zig");
const Date = @import("../date.zig").Date;

const Io = std.Io;

pub const usage =
    \\  lane SNAP --export DIR          write DIR/lane-model.json and DIR/lane-ref.json: the
    \\                                  compiled-in candidate's early outcomes per champion
    \\                                  into a lane opponent (-Dcand=src/lab/cand/team2)
    \\
;

const n_lane = lf.n_lane;
const min_pair_games = lf.min_pair_games;

comptime {
    if (@hasDecl(cand, "lane_outcomes")) for (cand.lane_outcomes, lf.outcomes) |o, name| {
        std.debug.assert(std.mem.eql(u8, @tagName(o), name));
    };
}

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

    var data = try rows.loadSnap(gpa, io, snap);
    defer data.deinit();
    const eu = euIndex();

    const players = try harness.gamePlayers(gpa, &data);
    defer gpa.free(players);
    // A tool, not an evaluation: every game that reached 15:00 minutes, test games included
    const Played = struct {
        pub fn keep(_: @This(), g: rows.Game) bool {
            return harness.played(g);
        }
    };
    var train = try harness.buildTrainBy(gpa, &data, players, Played{}, false);
    defer train.deinit();
    const t = &train.train;
    var m = try harness.fit(cand, gpa, t, .{});
    defer cand.deinit(&m, gpa);
    const ex = try lf.rounded(arena, try cand.exportLane(&m, arena, eu, min_pair_games));
    const sc = try lf.Scorer.init(arena, ex);
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

    const db = try store.schema.openReadOnly(gpa, snap);
    defer db.close();
    const champions = try lf.championList(arena, db);
    var newest: i64 = 0;
    for (data.games) |g| newest = @max(newest, g.start);
    const range = try lf.patchRange(arena, t.games);
    try lf.write(arena, io, &sc, .{
        .name = if (@hasDecl(cand, "name")) cand.name else "candidate",
        // "--export ." from a deploy/lab-run.sh run dir: the run is the dir's name
        .run = std.fs.path.basename(if (std.mem.eql(u8, dir, ".")) try std.process.currentPathAlloc(io, arena) else dir),
        .snapshot = std.fs.path.basename(snap),
        .newest_game = try arena.print("{f}", .{Date.fromMs(newest)}),
        .training_games = t.games.len,
        .patch = try lf.patchLabel(arena, ex.patch),
        .oldest_patch = range[0],
        .newest_patch = range[1],
        .platform = protocol.home_platform,
        .dev = &dev,
    }, champions, dir, w);
    return 0;
}

fn euIndex() u8 {
    for (protocol.platformIds(), 0..) |id, i| if (std.mem.eql(u8, id, protocol.home_platform)) return @intCast(i);
    unreachable;
}

/// The candidate refitted on dev's visible games, scored on dev-val per lane outcome
fn devScore(gpa: std.mem.Allocator, d: *const rows.Data) ![n_lane]lf.DevOut {
    const players = try harness.gamePlayers(gpa, d);
    defer gpa.free(players);
    const c = try harness.cuts(gpa, d);
    var s = try harness.score(cand, gpa, d, players, c, .dev, .{});
    defer s.deinit(gpa);
    var out: [n_lane]lf.DevOut = undefined;
    for (&out, cand.lane_outcomes, lf.units) |*o, x, unit| {
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
            .unit = unit,
            .rows = p.n,
            .err_base = @sqrt(sb / @max(n, 1)),
            .err_cand = @sqrt(sa / @max(n, 1)),
            .removed_pct = -100 * p.diff / p.b,
            .removed_half = 100 * p.half / p.b,
        };
    }
    return out;
}
