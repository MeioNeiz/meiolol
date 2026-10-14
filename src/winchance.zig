//! Win chance by minute from the game state: objectives.zig's "+ objectives held" model
//! (gold and XP lead, towers, inhibitors down, dragons, soul, elder, grubs, herald,
//! baron) fitted over every minute at once by `meiolol winchance`, each weight linear in
//! minute between knots, which writes the weights per minute to winchance_weights.zig.
//! Separate fits per minute were jumpy where a feature is rare (an early tower weighed
//! +0.6 at 7:00 and -0.8 at 8:00). Your games' turning minute and death cost read it.
//! Descriptive, not causal: the state misses what teams do with it.

const std = @import("std");
const store = @import("store");
const timeline = @import("riot/timeline.zig");
const objectives = @import("objectives.zig");
const logreg = @import("logreg.zig");
const stats = @import("stats.zig");
const analysis = @import("analysis.zig");
const weights = @import("winchance_weights.zig");
const Io = std.Io;

pub const feats = objectives.lead ++ objectives.held;
const dims = 1 + feats.len;
/// Later minutes reuse the last one's weights
pub const max_minute = 40;
/// Early surrenders (a leaver, mostly) and aborts end games before the state means much
const min_duration_s = 15 * 60;
const l2 = 1;

comptime {
    for (weights.w) |w| std.debug.assert(w.len == dims);
}

/// Blue's chance to win from the state at frame `minute`; 0.5 at the start, null once
/// the game has ended by then
pub fn blue(t: timeline.Timeline, minute: u8) ?f64 {
    if (minute == 0) return 0.5;
    if (weights.w.len == 0) return null;
    const s = objectives.stateAt(t, minute) orelse return null;
    return logreg.sigmoid(linear(weights.w[@min(minute, weights.w.len) - 1], s));
}

fn linear(w: [dims]f64, s: objectives.State) f64 {
    var x = w[0];
    for (feats, w[1..]) |f, b| x += b * s[@backingInt(f)];
    return x;
}

const Part = enum { fit, score, unused };
const Game = struct { id: []const u8, y: f32, part: Part, states: []const objectives.State };

pub const Options = struct {
    /// Fit on train minus every fifth train game and score those (choosing a variant);
    /// otherwise fit on train and score test
    dev: bool = false,
    knots: []const u8 = &default_knots,
};

/// Minutes where the smooth fit's weights are free; linear in between, flat past the last.
/// Chosen on dev over knots every 1-4 minutes: the same log loss, and the least win chance
/// moved by the weights alone (docs/model.md "Win chance by minute")
pub const default_knots = [_]u8{ 1, 5, 10, 15, 20, 25, 30, 35, 40 };
const max_knots = 16;
/// Per-minute fit check: a feature non-zero in fewer train games at a minute gets weight 0
const min_nonzero = 300;
const n_models = 4;
const model_labels = [n_models][]const u8{ "per minute", "per minute, 300+", "smooth", "shipped" };

/// Fits on the ranked solo games with timelines in `db` and writes a held-out check to
/// `w`. Test: every platform's games from the protocol's test cut (analysis.protocolCuts,
/// docs/model.md "Shared protocol"); train: older games. Weights (the smooth fit, per minute) as Zig source to
/// `src_out` when given
pub fn fit(gpa: std.mem.Allocator, db: store.Db, src_out: *Io.Writer, w: *Io.Writer) !void {
    return fitWith(gpa, db, .{}, src_out, w);
}

/// As fit, with dev scoring and knots to choose between
pub fn fitWith(gpa: std.mem.Allocator, db: store.Db, opts: Options, src_out: ?*Io.Writer, w: *Io.Writer) !void {
    if (opts.knots.len < 2 or opts.knots.len > max_knots) return error.Usage;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const Loaded = struct { id: []const u8, y: f32, start: i64, key: u64, states: []const objectives.State };
    var loaded: std.ArrayList(Loaded) = .empty;
    var q = try db.prepare(
        \\SELECT m.match_id, m.winning_team, m.platform, m.game_start, t.data
        \\FROM matches m JOIN timeline.timelines t USING (match_id)
        \\WHERE m.queue_id = ? AND m.remake = 0 AND m.winning_team IS NOT NULL
        \\  AND m.duration_s >= ?
    );
    defer q.deinit();
    try q.bind(.{ stats.ranked_solo, min_duration_s });
    var scratch_state: std.heap.ArenaAllocator = .init(gpa);
    defer scratch_state.deinit();
    var states: std.ArrayList(objectives.State) = .empty;
    defer states.deinit(gpa);
    while (try q.step()) {
        _ = scratch_state.reset(.retain_capacity);
        const scratch = scratch_state.allocator();
        const t = timeline.decode(scratch, store.raw.decompress(scratch, q.bytes(4)) catch continue) catch continue;
        states.clearRetainingCapacity();
        for (1..max_minute + 1) |m| try states.append(gpa, objectives.stateAt(t, @intCast(m)) orelse break);
        try loaded.append(arena, .{
            .y = if (q.int(1) == 100) 1 else 0,
            .start = q.int(3),
            .id = try arena.dupe(u8, q.bytes(0)),
            .key = stats.matchKey(q.bytes(0)),
            .states = try arena.dupe(objectives.State, states.items),
        });
    }

    const cutoff = (try analysis.protocolCuts(gpa, db)).test_;
    const games = try arena.alloc(Game, loaded.items.len);
    var n_part: [3]usize = @splat(0);
    for (loaded.items, games) |l, *g| {
        const part: Part = if (l.start >= cutoff)
            (if (opts.dev) .unused else .score)
        else if (opts.dev)
            (if (l.key % 5 == 0) .score else .fit)
        else
            .fit;
        g.* = .{ .id = l.id, .y = l.y, .part = part, .states = l.states };
        n_part[@backingInt(part)] += 1;
    }

    var models: [n_models][max_minute][dims]f64 = undefined;
    var last: [n_models]usize = undefined;
    for (0..2) |i| last[i] = try fitPerMinute(gpa, games, if (i == 0) 0 else min_nonzero, &models[i]);
    try fitSmooth(gpa, games, opts.knots, &models[2]);
    last[2] = max_minute;
    for (&models[3], 0..) |*mw, mi| mw.* = weights.w[@min(mi, weights.w.len - 1)];
    last[3] = weights.w.len;

    try w.print("# meiolol winchance\n\nRanked solo games of 15 min or more. {s}: {d} games " ++
        "(fit on {d}). Test cutoff: games started from {d}, every platform. Smooth: every weight " ++
        "linear in minute between knots {any}. Log loss in nats per game still going at that " ++
        "minute; base: the fit games' win rate.\n\n", .{
        if (opts.dev) "Dev (every fifth train game)" else "Test (the protocol's newest 15%, every platform)",
        n_part[@backingInt(Part.score)],
        n_part[@backingInt(Part.fit)],
        cutoff,
        opts.knots,
    });
    try w.writeAll("| minute | games | base |");
    for (model_labels) |l| try w.print(" {s} |", .{l});
    try w.writeAll("\n| --- | --- | --- |");
    for (model_labels) |_| try w.writeAll(" --- |");
    try w.writeAll("\n");

    var rate: f64 = 0;
    var n_fit: f64 = 0;
    for (games) |g| if (g.part == .fit) {
        rate += g.y;
        n_fit += 1;
    };
    rate /= n_fit;
    // Per scored game, its loss summed over minutes: paired differences against per minute
    var per_game: std.ArrayList([n_models]f64) = .empty;
    for (games) |g| if (g.part == .score) try per_game.append(arena, @splat(0));
    for (0..max_minute) |mi| {
        var n: f64 = 0;
        var base: f64 = 0;
        var loss: [n_models]f64 = @splat(0);
        var gi: usize = 0;
        for (games) |g| if (g.part == .score) {
            defer gi += 1;
            if (mi >= g.states.len) continue;
            n += 1;
            base += logLoss(rate, g.y);
            for (&models, last, &loss, &per_game.items[gi]) |*mw, l, *sum, *pg| {
                const x = logLoss(logreg.sigmoid(linear(mw[@min(mi, l - 1)], g.states[mi])), g.y);
                sum.* += x;
                pg.* += x;
            }
        };
        if (n == 0) break;
        try w.print("| {d} | {d} | {d:.4} |", .{ mi + 1, n, base / n });
        for (loss) |x| try w.print(" {d:.4} |", .{x / n});
        try w.writeAll("\n");
    }
    try w.writeAll("\nAll minutes, against per minute (nats per game summed over its minutes, " ++
        "± 95% over scored games):\n\n");
    for (1..n_models) |i| {
        var mean: f64 = 0;
        var sq: f64 = 0;
        for (per_game.items) |pg| {
            const d = pg[i] - pg[0];
            mean += d;
            sq += d * d;
        }
        const n: f64 = @floatFromInt(per_game.items.len);
        mean /= n;
        const se = @sqrt((sq / n - mean * mean) / n);
        try w.print("- {s}: {d:.4} ± {d:.4}\n", .{ model_labels[i], mean, 1.96 * se });
    }
    try w.writeAll("\nWin chance moved by the next minute's weights alone, state held " ++
        "(the jumpiness Your games would show), percentage points over scored game-minutes:" ++
        "\n\n| model | mean | 99th percentile | largest |\n| --- | --- | --- | --- |\n");
    var moves: std.ArrayList(f64) = .empty;
    for (&models, last, model_labels) |*mw, l, label| {
        moves.clearRetainingCapacity();
        for (games) |g| if (g.part == .score and g.states.len > 1) for (g.states[0 .. g.states.len - 1], 0..) |s, mi| {
            const now = logreg.sigmoid(linear(mw[@min(mi, l - 1)], s));
            const next = logreg.sigmoid(linear(mw[@min(mi + 1, l - 1)], s));
            try moves.append(arena, 100 * @abs(next - now));
        };
        std.mem.sort(f64, moves.items, {}, std.sort.asc(f64));
        var sum: f64 = 0;
        for (moves.items) |x| sum += x;
        const n = moves.items.len;
        try w.print("| {s} | {d:.2} | {d:.2} | {d:.1} |\n", .{
            label, sum / @as(f64, @floatFromInt(n)), moves.items[n * 99 / 100], moves.items[n - 1],
        });
    }
    try w.writeAll("\nPer scored game, its largest win chance change between adjacent minutes " ++
        "from 0:00 (Your games' turning minute), percentage points: mean over games, and how " ++
        "often the turning minute differs from smooth's\n\n| model | mean | differs |\n" ++
        "| --- | --- | --- |\n");
    const Turn = struct { minute: usize, change: f64 };
    const turns = try arena.alloc([n_models]Turn, per_game.items.len);
    {
        var gi: usize = 0;
        for (games) |g| if (g.part == .score) {
            defer gi += 1;
            for (&models, last, &turns[gi]) |*mw, l, *t| {
                t.* = .{ .minute = 0, .change = 0 };
                var prev: f64 = 0.5;
                for (g.states, 0..) |s, mi| {
                    const p = logreg.sigmoid(linear(mw[@min(mi, l - 1)], s));
                    if (@abs(p - prev) > t.change) t.* = .{ .minute = mi + 1, .change = @abs(p - prev) };
                    prev = p;
                }
            }
        };
    }
    for (model_labels, 0..) |label, k| {
        var sum: f64 = 0;
        var differs: f64 = 0;
        for (turns) |t| {
            sum += t[k].change;
            differs += @floatFromInt(@intFromBool(t[k].minute != t[2].minute));
        }
        const n: f64 = @floatFromInt(turns.len);
        try w.print("| {s} | {d:.1} | {d:.1}% |\n", .{ label, 100 * sum / n, 100 * differs / n });
    }
    try w.writeAll("\nThe five scored games where shipped's turning minute jumps most past " ++
        "smooth's: minute and change (pp)\n\n| game |");
    for (model_labels) |l| try w.print(" {s} |", .{l});
    try w.writeAll("\n| --- |");
    for (model_labels) |_| try w.writeAll(" --- |");
    try w.writeAll("\n");
    const order = try arena.alloc(usize, turns.len);
    for (order, 0..) |*o, i| o.* = i;
    std.mem.sort(usize, order, turns, struct {
        fn more(t: [][n_models]Turn, a: usize, b: usize) bool {
            return t[a][3].change - t[a][2].change > t[b][3].change - t[b][2].change;
        }
    }.more);
    var ids: std.ArrayList([]const u8) = .empty;
    for (games) |g| if (g.part == .score) try ids.append(arena, g.id);
    for (order[0..@min(5, order.len)]) |i| {
        try w.print("| {s} |", .{ids.items[i]});
        for (turns[i]) |t| try w.print(" {d}: {d:.0} |", .{ t.minute, 100 * t.change });
        try w.writeAll("\n");
    }
    try w.writeAll("\nLargest change between adjacent minutes, per feature:\n\n| model | intercept |");
    for (feats) |f| try w.print(" {t} |", .{f});
    try w.writeAll("\n| --- | --- |");
    for (feats) |_| try w.writeAll(" --- |");
    try w.writeAll("\n");
    for (models, last, model_labels) |mw, l, label| {
        try w.print("| {s} |", .{label});
        for (0..dims) |j| {
            var big: f64 = 0;
            for (1..l) |mi| big = @max(big, @abs(mw[mi][j] - mw[mi - 1][j]));
            try w.print(" {d:.3} |", .{big});
        }
        try w.writeAll("\n");
    }

    const out = src_out orelse return;
    try out.print(
        \\//! Generated by `meiolol winchance` from {d} games: one fit, each weight linear
        \\//! in minute between knots {any};
        \\//! see winchance.zig. Per minute from 1: intercept, then one weight per
        \\//! winchance.feats entry
        \\
        \\pub const w = [_][{d}]f64{{
        \\
    , .{ n_part[@backingInt(Part.fit)], opts.knots, dims });
    for (models[2]) |mw| {
        try out.writeAll("    .{");
        for (mw, 0..) |b, i| try out.print("{s}{d:.6}", .{ if (i == 0) " " else ", ", b });
        try out.writeAll(" },\n");
    }
    try out.writeAll("};\n");
}

/// One fit per minute (the old model); returns how many minutes had enough games
fn fitPerMinute(gpa: std.mem.Allocator, games: []const Game, min_games: usize, out: *[max_minute][dims]f64) !usize {
    var rows: std.ArrayList(logreg.Row) = .empty;
    defer rows.deinit(gpa);
    for (0..max_minute) |mi| {
        var nonzero: [dims]usize = @splat(0);
        for (games) |g| if (g.part == .fit and mi < g.states.len) {
            for (feats, 1..) |f, j| nonzero[j] += @intFromBool(g.states[mi][@backingInt(f)] != 0);
        };
        rows.clearRetainingCapacity();
        for (games) |g| if (g.part == .fit and mi < g.states.len) {
            var r: logreg.Row = .{ .y = g.y };
            r.add(0, 1);
            for (feats, 1..) |f, j| if (nonzero[j] >= min_games) r.add(@intCast(j), g.states[mi][@backingInt(f)]);
            try rows.append(gpa, r);
        };
        if (rows.items.len < 1000) return mi;
        const wt = try logreg.fit(gpa, dims, rows.items, l2);
        defer gpa.free(wt);
        out[mi] = wt[0..dims].*;
    }
    return max_minute;
}

/// One fit over every minute: each weight is linear in minute between `knots`
fn fitSmooth(gpa: std.mem.Allocator, games: []const Game, knots: []const u8, out: *[max_minute][dims]f64) !void {
    const k = knots.len;
    var rows: std.ArrayList(logreg.Row) = .empty;
    defer rows.deinit(gpa);
    for (games) |g| if (g.part == .fit) for (g.states, 1..) |s, m| {
        const h = hat(knots, @intCast(m));
        var r: logreg.Row = .{ .y = g.y };
        for (0..dims) |j| {
            const x: f64 = if (j == 0) 1 else s[@backingInt(feats[j - 1])];
            if (x == 0) continue;
            r.add(@intCast(j * k + h.i), (1 - h.a) * x);
            if (h.a > 0) r.add(@intCast(j * k + h.i + 1), h.a * x);
        }
        try rows.append(gpa, r);
    };
    const wt = try logreg.fit(gpa, dims * k, rows.items, l2);
    defer gpa.free(wt);
    for (out, 1..) |*mw, m| {
        const h = hat(knots, @intCast(m));
        for (mw, 0..) |*b, j| {
            b.* = (1 - h.a) * wt[j * k + h.i];
            if (h.a > 0) b.* += h.a * wt[j * k + h.i + 1];
        }
    }
}

/// Minute `m` as a mix of knot i (share 1 - a) and knot i + 1 (share a)
fn hat(knots: []const u8, m: u8) struct { i: usize, a: f64 } {
    if (m <= knots[0]) return .{ .i = 0, .a = 0 };
    for (knots[0 .. knots.len - 1], knots[1..], 0..) |lo, hi, i| if (m <= hi) {
        return .{ .i = i, .a = @as(f64, @floatFromInt(m - lo)) / @as(f64, @floatFromInt(hi - lo)) };
    };
    return .{ .i = knots.len - 1, .a = 0 };
}

fn logLoss(p: f64, y: f64) f64 {
    const q = std.math.clamp(p, 1e-6, 1 - 1e-6);
    return -(y * @log(q) + (1 - y) * @log(1 - q));
}

test "blue's chance is a half at the start and moves with the state" {
    const arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    var a = arena_state;
    defer a.deinit();
    const arena = a.allocator();
    const raw = try store.raw.decompress(arena, @embedFile("riot/testdata/timeline.json.gz"));
    const t = try timeline.fromJson(arena, raw);
    try std.testing.expectEqual(@as(?f64, 0.5), blue(t, 0));
    if (weights.w.len == 0) return;
    const p = blue(t, 10).?;
    try std.testing.expect(p > 0 and p < 1);
    try std.testing.expect(blue(t, @intCast(t.frames.len)) == null);
}

test "weights move smoothly from minute to minute" {
    // Separate per-minute fits moved a rare feature's weight by up to 1.3 a minute
    for (weights.w[0 .. weights.w.len - 1], weights.w[1..]) |a, b| {
        for (a, b) |x, y| try std.testing.expect(@abs(y - x) < 0.3);
    }
}
