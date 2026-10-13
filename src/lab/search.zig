//! The lab agent's search tools (docs/lab-agent.md "Search"), on dev data only, so they
//! cost no selection looks:
//! - screen: each feature the candidate exposes, alone, as one linear term on the
//!   baseline's standardised residuals, centred within champion-role (a score test for
//!   adding it to champion-role means). Fitted on dev-train, scored on dev-val, paired
//!   and clustered like a run: which ideas are worth a full run, in one pass
//! - diagnose: the candidate's signed dev-val residuals by covariates it may not use
//!   (side, rank, patch, champion, lane opponent, junglers, hour): where it is biased

const std = @import("std");
const api = @import("api");
const rows = @import("rows.zig");
const core = @import("core");
const harness = @import("harness.zig");

const Io = std.Io;

/// A candidate offering features to screen declares
///   pub const feature_names: []const []const u8
///   pub fn features(m: *const Model, q: *const api.Query, out: []f32) void
pub fn hasFeatures(comptime C: type) bool {
    return @hasDecl(C, "feature_names") and @hasDecl(C, "features");
}

/// Standardised residual of y against the baseline: squared error scale for every
/// outcome (win too: a Brier proxy, enough to rank features)
fn residual(k: usize, y: f32, base: f64, sd: f64) f64 {
    if (k == api.outcomeIndex(.win)) return y - base;
    return (y - base) / sd;
}

pub fn screen(
    comptime C: type,
    gpa: std.mem.Allocator,
    d: *const rows.Data,
    players: []const harness.Players,
    c: harness.Cuts,
    k: usize,
    w: *Io.Writer,
) !void {
    if (comptime hasFeatures(C)) return screenFeatures(C, gpa, d, players, c, k, w);
    try w.writeAll("screen: the candidate exposes no features (feature_names, features)\n");
}

fn screenFeatures(
    comptime C: type,
    gpa: std.mem.Allocator,
    d: *const rows.Data,
    players: []const harness.Players,
    c: harness.Cuts,
    k: usize,
    w: *Io.Writer,
) !void {
    const nf = C.feature_names.len;
    var v = try harness.buildTrain(gpa, d, players, .dev, c, 1, harness.afterGameRank(C));
    defer v.deinit();
    var base = try harness.Baseline.fit(gpa, &v.train);
    defer base.deinit(gpa);
    const sd = base.sd();
    var m = try C.fit(gpa, &v.train, .{});
    defer C.deinit(&m, gpa);

    // Pass 1: features and residuals of dev-train rows; per champion-role feature means
    const Cell = struct { n: [nf]f64 = @splat(0), sum: [nf]f64 = @splat(0) };
    var cells: std.AutoHashMapUnmanaged(u64, Cell) = .empty;
    defer cells.deinit(gpa);
    var train_f: std.ArrayList([nf]f32) = .empty;
    defer train_f.deinit(gpa);
    var train_e: std.ArrayList(f64) = .empty;
    defer train_e.deinit(gpa);
    var train_key: std.ArrayList(u64) = .empty;
    defer train_key.deinit(gpa);
    var global: Cell = .{};
    for (d.rows) |r| {
        const g = d.games[r.game];
        if (!harness.visible(.dev, c, g) or std.math.isNan(r.y[k])) continue;
        const q = harness.query(C.scope, g, players[r.game], r, harness.afterGameRank(C));
        var f: [nf]f32 = undefined;
        C.features(&m, &q, &f);
        const key = cellKey(q.champion, q.role);
        const e = try cells.getOrPut(gpa, key);
        if (!e.found_existing) e.value_ptr.* = .{};
        for (f, 0..) |x, j| if (!std.math.isNan(x)) {
            e.value_ptr.n[j] += 1;
            e.value_ptr.sum[j] += x;
            global.n[j] += 1;
            global.sum[j] += x;
        };
        const b = base.predict(q.champion, q.role)[k];
        try train_f.append(gpa, f);
        try train_e.append(gpa, residual(k, r.y[k], b, sd[@backingInt(q.role)][k]));
        try train_key.append(gpa, key);
    }

    // Slope of residual on the centred feature, per feature
    var sfe: [nf]f64 = @splat(0);
    var sff: [nf]f64 = @splat(0);
    var see: f64 = 0;
    for (train_f.items, train_e.items, train_key.items) |f, e, key| {
        const cell = cells.get(key).?;
        see += e * e;
        for (0..nf) |j| {
            const x = centred(f[j], cell, global, j) orelse continue;
            sfe[j] += x * e;
            sff[j] += x * x;
        }
    }

    // Pass 2: dev-val, loss with the one term vs without, paired per row
    var game: std.ArrayList(u32) = .empty;
    defer game.deinit(gpa);
    var lb: std.ArrayList(f64) = .empty;
    defer lb.deinit(gpa);
    var la: [nf]std.ArrayList(f64) = @splat(.empty);
    defer for (&la) |*l| l.deinit(gpa);
    for (d.rows) |r| {
        const g = d.games[r.game];
        if (!harness.scored(.dev, c, g) or std.math.isNan(r.y[k])) continue;
        const q = harness.query(C.scope, g, players[r.game], r, harness.afterGameRank(C));
        var f: [nf]f32 = undefined;
        C.features(&m, &q, &f);
        const cell = cells.get(cellKey(q.champion, q.role)) orelse Cell{};
        const e = residual(k, r.y[k], base.predict(q.champion, q.role)[k], sd[@backingInt(q.role)][k]);
        try game.append(gpa, r.game);
        try lb.append(gpa, e * e);
        for (0..nf) |j| {
            const beta = if (sff[j] > 0) sfe[j] / sff[j] else 0;
            const x = centred(f[j], cell, global, j) orelse 0;
            const e2 = e - beta * x;
            try la[j].append(gpa, e2 * e2);
        }
    }

    const Line = struct { name: []const u8, r: f64, p: harness.Paired };
    var lines: [nf]Line = undefined;
    for (&lines, 0..) |*l, j| l.* = .{
        .name = C.feature_names[j],
        .r = if (sff[j] > 0 and see > 0) sfe[j] / @sqrt(sff[j] * see) else 0,
        .p = harness.paired(game.items, la[j].items, lb.items, null),
    };
    std.mem.sort(Line, &lines, {}, struct {
        fn lt(_: void, a: Line, b: Line) bool {
            return a.p.diff < b.p.diff;
        }
    }.lt);
    try w.print("# Screen: {d} features on {t}, dev only\n\n", .{ nf, api.outcomeAt(k) });
    try w.writeAll("Each feature alone as one linear term on the baseline's residuals (centred " ++
        "within champion-role), fitted on dev-train, scored on dev-val. Diff: change in " ++
        "mean standardised squared error (Brier for win); negative = helps.\n\n");
    try w.writeAll("| feature | r (dev-train) | dev-val diff | clears noise |\n|---|---|---|---|\n");
    var clears: usize = 0;
    for (lines) |l| {
        clears += @intFromBool(l.p.beats());
        try w.print("| {s} | {d:.4} | {d:.5} ± {d:.5} | {s} |\n", .{
            l.name, l.r, l.p.diff, l.p.half, if (l.p.beats()) "yes" else "no",
        });
    }
    try w.print("\n{d} of {d} clear; about {d:.1} would by chance (one-sided 2.5% each).\n", .{
        clears, nf, @as(f64, @floatFromInt(nf)) * 0.025,
    });
    try w.print("RESULT screen target={t} features={d} clear={d}\n", .{ api.outcomeAt(k), nf, clears });
}

fn cellKey(champion: u32, role: api.Role) u64 {
    return (@as(u64, champion) << 3) | @backingInt(role);
}

fn centred(x: f32, cell: anytype, global: anytype, j: usize) ?f64 {
    if (std.math.isNan(x)) return null;
    const mean = if (cell.n[j] > 0) cell.sum[j] / cell.n[j] else if (global.n[j] > 0) global.sum[j] / global.n[j] else 0;
    return x - mean;
}

/// Slices with fewer rows are not shown (too noisy to name a misfit)
const min_slice = 300;
const top_slices = 12;

pub fn diagnose(
    comptime C: type,
    gpa: std.mem.Allocator,
    d: *const rows.Data,
    players: []const harness.Players,
    c: harness.Cuts,
    k: usize,
    w: *Io.Writer,
) !void {
    var s = try harness.score(C, gpa, d, players, c, .dev, .{});
    defer s.deinit(gpa);
    // Signed standardised residual, candidate minus truth: positive = over-predicts
    const res = try gpa.alloc(f64, s.row.len);
    defer gpa.free(res);
    const zero = try gpa.alloc(f64, s.row.len);
    defer gpa.free(zero);
    @memset(zero, 0);
    for (res, s.row, s.cand) |*x, ri, p| {
        const r = d.rows[ri];
        const y = r.y[k];
        const scale = if (k == api.outcomeIndex(.win)) 1 else s.sd[@backingInt(r.role)][k];
        x.* = if (std.math.isNan(y)) std.math.nan(f64) else (p[k] - y) / scale;
    }
    try w.print("# Diagnose: candidate's {t} residuals on dev-val\n\n", .{api.outcomeAt(k)});
    try w.writeAll("Mean of (prediction - outcome), in role sd (win: probability), 95% interval " ++
        "clustered by game. Positive = over-predicts. Slices are relative to the overall " ++
        "bias, so they show where the model is wrong beyond a level shift. Flagged: the " ++
        "slice's z clears a Bonferroni bound for its group's number of slices, so a flag " ++
        "names a misfit worth a hypothesis. Slices under 300 rows left out; long lists show " ++
        "the 12 most biased.\n\n");
    const all = harness.paired(s.game, res, zero, null);
    try w.print("Overall bias: {d:.4} ± {d:.4} over {d} rows. Dev-val is newer than its " ++
        "training games and EUW1 only while they span every platform, so a level shift is " ++
        "drift over time, region mix, or both (a platform or patch term tells which)\n", .{ all.diff, all.half, all.n });
    for (res) |*x| x.* -= all.diff;

    const Key = struct {
        fn side(dd: *const rows.Data, ri: u32) ?u64 {
            return dd.rows[ri].side;
        }
        fn tier(dd: *const rows.Data, ri: u32) ?u64 {
            return if (dd.rows[ri].rank_after) |x| x / 4 else 10;
        }
        fn patch(dd: *const rows.Data, ri: u32) ?u64 {
            return dd.games[dd.rows[ri].game].patch;
        }
        fn hour(dd: *const rows.Data, ri: u32) ?u64 {
            return @intCast(@divFloor(@mod(@divFloor(dd.games[dd.rows[ri].game].start, 3_600_000), 24), 4) * 4);
        }
        fn champion(dd: *const rows.Data, ri: u32) ?u64 {
            const r = dd.rows[ri];
            return (@as(u64, r.champion) << 3) | @backingInt(r.role);
        }
        fn laneOpponent(dd: *const rows.Data, ri: u32) ?u64 {
            const r = dd.rows[ri];
            const g = dd.games[r.game];
            return (@as(u64, g.teams[1 - r.side][@backingInt(r.role)]) << 3) | @backingInt(r.role);
        }
        fn allyJungler(dd: *const rows.Data, ri: u32) ?u64 {
            const r = dd.rows[ri];
            if (r.role == .jungle) return null;
            return dd.games[r.game].teams[r.side][@backingInt(core.Role.jungle)];
        }
        fn enemyJungler(dd: *const rows.Data, ri: u32) ?u64 {
            const r = dd.rows[ri];
            return dd.games[r.game].teams[1 - r.side][@backingInt(core.Role.jungle)];
        }
    };
    const groups = [_]struct { name: []const u8, key: *const fn (*const rows.Data, u32) ?u64, label: Label }{
        .{ .name = "side (0 blue)", .key = &Key.side, .label = .plain },
        .{ .name = "rank tier (0 iron .. 9 challenger, 10 unranked)", .key = &Key.tier, .label = .plain },
        .{ .name = "patch", .key = &Key.patch, .label = .patch },
        .{ .name = "start hour UTC (4 h)", .key = &Key.hour, .label = .plain },
        .{ .name = "champion-role", .key = &Key.champion, .label = .champion_role },
        .{ .name = "lane opponent (champion-role)", .key = &Key.laneOpponent, .label = .champion_role },
        .{ .name = "ally jungler (champion)", .key = &Key.allyJungler, .label = .plain },
        .{ .name = "enemy jungler (champion)", .key = &Key.enemyJungler, .label = .plain },
    };
    const keep = try gpa.alloc(bool, s.row.len);
    defer gpa.free(keep);
    for (groups) |grp| {
        var values: std.AutoArrayHashMapUnmanaged(u64, usize) = .empty;
        defer values.deinit(gpa);
        for (s.row, res) |ri, x| {
            if (std.math.isNan(x)) continue;
            const key = grp.key(d, ri) orelse continue;
            const e = try values.getOrPut(gpa, key);
            if (!e.found_existing) e.value_ptr.* = 0;
            e.value_ptr.* += 1;
        }
        const Slice = struct { key: u64, p: harness.Paired };
        var slices: std.ArrayList(Slice) = .empty;
        defer slices.deinit(gpa);
        var it = values.iterator();
        while (it.next()) |e| {
            if (e.value_ptr.* < min_slice) continue;
            for (keep, s.row) |*kp, ri| kp.* = grp.key(d, ri) == e.key_ptr.*;
            try slices.append(gpa, .{ .key = e.key_ptr.*, .p = harness.paired(s.game, res, zero, keep) });
        }
        // Most biased first, by interval-scaled size
        std.mem.sort(Slice, slices.items, {}, struct {
            fn lt(_: void, a: Slice, b: Slice) bool {
                return @abs(a.p.diff) / a.p.half > @abs(b.p.diff) / b.p.half;
            }
        }.lt);
        const bound = normalQuantile(0.025 / @as(f64, @floatFromInt(@max(slices.items.len, 1))));
        try w.print("\n## {s}\n\n{d} slices, flag at |z| > {d:.2}\n\n| value | rows | relative bias | z | flag |\n|---|---|---|---|---|\n", .{ grp.name, slices.items.len, bound });
        for (slices.items[0..@min(slices.items.len, top_slices)]) |sl| {
            var buf: [32]u8 = undefined;
            const z = sl.p.diff / (sl.p.half / 1.96);
            try w.print("| {s} | {d} | {d:.4} ± {d:.4} | {d:.1} | {s} |\n", .{
                try grp.label.format(&buf, sl.key), sl.p.n, sl.p.diff, sl.p.half, z,
                if (@abs(z) > bound) "yes" else "",
            });
        }
    }
    try w.print("RESULT diagnose target={t} bias={d:.4}±{d:.4}\n", .{ api.outcomeAt(k), all.diff, all.half });
}

/// z with upper tail probability p (Abramowitz and Stegun 26.2.23, error < 4.5e-4)
fn normalQuantile(p: f64) f64 {
    const t = @sqrt(-2 * @log(p));
    return t - (2.515517 + 0.802853 * t + 0.010328 * t * t) /
        (1 + 1.432788 * t + 0.189269 * t * t + 0.001308 * t * t * t);
}

test normalQuantile {
    try std.testing.expectApproxEqAbs(@as(f64, 1.96), normalQuantile(0.025), 1e-3);
    try std.testing.expectApproxEqAbs(@as(f64, 3.29), normalQuantile(0.0005), 2e-3);
}

const Label = enum {
    plain,
    patch,
    champion_role,

    fn format(l: Label, buf: []u8, key: u64) ![]const u8 {
        return switch (l) {
            .plain => std.fmt.bufPrint(buf, "{d}", .{key}),
            .patch => std.fmt.bufPrint(buf, "{d}.{d}", .{ key / 1000, key % 1000 }),
            .champion_role => std.fmt.bufPrint(buf, "{d} {t}", .{ key >> 3, @as(api.Role, @fromBackingInt(@as(u3, @intCast(key & 7)))) }),
        };
    }
};

test "screen finds a planted feature, diagnose runs" {
    const gpa = std.testing.allocator;
    var f = try harness.Fixture.init(gpa, 3000, 4);
    defer f.data.deinit();
    const players = try harness.gamePlayers(gpa, &f.data);
    defer gpa.free(players);
    const c = try harness.cuts(gpa, &f.data, 0);
    const Cand = struct {
        pub const scope: api.Scope = .champ_select;
        pub const Model = struct {};
        pub const feature_names: []const []const u8 = &.{ "enemy has champion 2", "start parity" };
        pub fn fit(_: std.mem.Allocator, _: *const api.Train, _: api.Options) !Model {
            return .{};
        }
        pub fn predict(_: *const Model, _: *const api.Query) api.Prediction {
            return api.no_opinion;
        }
        pub fn features(_: *const Model, q: *const api.Query, out: []f32) void {
            out[0] = @floatFromInt(@intFromBool(std.mem.indexOfScalar(u32, &q.teams[1 - q.side], 2) != null));
            out[1] = @floatFromInt(@mod(@divFloor(q.start, 60_000), 2));
        }
        pub fn deinit(_: *Model, _: std.mem.Allocator) void {}
    };
    var aw: Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();
    try screen(Cand, gpa, &f.data, players, c, api.outcomeIndex(.gold14), &aw.writer);
    const out = aw.written();
    try std.testing.expect(std.mem.indexOf(u8, out, "| enemy has champion 2 |") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "clear=1") != null);
    aw.clearRetainingCapacity();
    try diagnose(Cand, gpa, &f.data, players, c, api.outcomeIndex(.gold14), &aw.writer);
    try std.testing.expect(std.mem.indexOf(u8, aw.written(), "RESULT diagnose") != null);
}
