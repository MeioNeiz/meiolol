//! "How does a champion do against the whole enemy team?" on continuous outcomes:
//! fm.zig's base, additive, lane and pairwise models on the shared split. Grid on the newest
//! 20% of train (by time), refit on all of train at the chosen epochs, test once.
//! Intervals: 95%, paired, clustered by game (a game's ten rows share one game state)

const std = @import("std");
const fm = @import("fm.zig");
const rows = @import("rows.zig");

/// Champion-roles with fewer train rows share their role's "other" id
const min_rows = 30;

pub const Ids = struct {
    map: std.AutoHashMapUnmanaged(u64, u16) = .empty,
    n: u16 = 5,

    fn key(champion: u32, role: u3) u64 {
        return (@as(u64, champion) << 3) | role;
    }

    fn get(ids: *const Ids, champion: u32, role: u3) u16 {
        return ids.map.get(key(champion, role)) orelse role;
    }
};

pub fn buildIds(gpa: std.mem.Allocator, d: *const rows.Data) !Ids {
    var counts: std.AutoHashMapUnmanaged(u64, u32) = .empty;
    defer counts.deinit(gpa);
    for (d.rows) |r| {
        if (d.games[r.game].is_test) continue;
        const e = try counts.getOrPutValue(gpa, Ids.key(r.champion, @backingInt(r.role)), 0);
        e.value_ptr.* += 1;
    }
    var ids: Ids = .{};
    var it = counts.iterator();
    while (it.next()) |e| if (e.value_ptr.* >= min_rows) {
        try ids.map.put(gpa, e.key_ptr.*, ids.n);
        ids.n += 1;
    };
    return ids;
}

pub const Set = struct {
    ex: std.ArrayList(fm.Example) = .empty,
    /// Row index of each example, for game clustering and the preds file
    row: std.ArrayList(u32) = .empty,

    fn deinit(s: *Set, gpa: std.mem.Allocator) void {
        s.ex.deinit(gpa);
        s.row.deinit(gpa);
    }
};

pub const Sets = struct {
    inner: Set = .{},
    val: Set = .{},
    train: Set = .{},
    tests: Set = .{},

    pub fn deinit(s: *Sets, gpa: std.mem.Allocator) void {
        inline for (.{ &s.inner, &s.val, &s.train, &s.tests }) |set| set.deinit(gpa);
    }
};

pub fn buildSets(gpa: std.mem.Allocator, d: *const rows.Data, ids: *const Ids, k: rows.Outcome, mean: *f64, sd: *f64) !Sets {
    // Games are in start order, train first; the newest 20% of train games validate
    var n_train: usize = 0;
    for (d.games) |g| n_train += @intFromBool(!g.is_test);
    const val_from = n_train * 4 / 5;

    // Members of each game by side, to read enemies and allies
    var members: std.AutoHashMapUnmanaged(u32, [2][5]u32) = .empty;
    defer members.deinit(gpa);
    for (d.rows, 0..) |r, i| {
        const e = try members.getOrPut(gpa, r.game);
        if (!e.found_existing) e.value_ptr.* = @splat(@splat(std.math.maxInt(u32)));
        e.value_ptr[r.side][@backingInt(r.role)] = @intCast(i);
    }

    var sum: f64 = 0;
    var sq: f64 = 0;
    var n: f64 = 0;
    for (d.rows) |r| {
        const y = r.y[@backingInt(k)];
        if (std.math.isNan(y) or r.game >= val_from) continue;
        sum += y;
        sq += y * y;
        n += 1;
    }
    mean.* = sum / n;
    sd.* = @sqrt(@max(sq / n - mean.* * mean.*, 1e-12));

    var s: Sets = .{};
    for (d.rows, 0..) |r, i| {
        const y = r.y[@backingInt(k)];
        if (std.math.isNan(y)) continue;
        const m = members.get(r.game).?;
        var e: fm.Example = .{
            .me = ids.get(r.champion, @backingInt(r.role)),
            .role = @backingInt(r.role),
            .platform = d.games[r.game].platform,
            .enemies = undefined,
            .enemy_roles = undefined,
            .allies = undefined,
            .ally_roles = undefined,
            .y = @floatCast((y - mean.*) / sd.*),
        };
        var complete = true;
        for (m[1 - r.side], 0..) |ri, role| {
            if (ri == std.math.maxInt(u32)) complete = false else {
                e.enemies[role] = ids.get(d.rows[ri].champion, @intCast(role));
                e.enemy_roles[role] = @intCast(role);
            }
        }
        var a: usize = 0;
        for (m[r.side], 0..) |ri, role| {
            if (role == @backingInt(r.role)) continue;
            if (ri == std.math.maxInt(u32)) complete = false else {
                e.allies[a] = ids.get(d.rows[ri].champion, @intCast(role));
                e.ally_roles[a] = @intCast(role);
            }
            a += 1;
        }
        if (!complete) continue;
        const g = d.games[r.game];
        const targets: []const *Set = if (g.is_test) &.{&s.tests} else if (r.game >= val_from)
            &.{ &s.val, &s.train }
        else
            &.{ &s.inner, &s.train };
        for (targets) |t| {
            try t.ex.append(gpa, e);
            try t.row.append(gpa, @intCast(i));
        }
    }
    return s;
}

const Scored = struct { label: []const u8, cfg: fm.Config, epochs: u32, pred: []f32 };

/// Mean squared error difference (a - b) in outcome units, with a 95% interval
/// clustered by game
fn pairedDiff(d: *const rows.Data, set: *const Set, ys: []const f32, a: []const f32, b: []const f32) struct { mean: f64, half: f64 } {
    var total: f64 = 0;
    for (ys, a, b) |y, pa, pb| total += (pa - y) * (pa - y) - (pb - y) * (pb - y);
    const n: f64 = @floatFromInt(ys.len);
    const mean = total / n;
    // Rows of one game are contiguous in set order (rows are by match, slot)
    var ss: f64 = 0;
    var groups: f64 = 0;
    var i: usize = 0;
    while (i < ys.len) {
        const game = d.rows[set.row.items[i]].game;
        var sum_d: f64 = 0;
        var cnt: f64 = 0;
        while (i < ys.len and d.rows[set.row.items[i]].game == game) : (i += 1) {
            sum_d += (a[i] - ys[i]) * (a[i] - ys[i]) - (b[i] - ys[i]) * (b[i] - ys[i]);
            cnt += 1;
        }
        ss += (sum_d - mean * cnt) * (sum_d - mean * cnt);
        groups += 1;
    }
    const v = groups / (groups - 1) * ss / (n * n);
    return .{ .mean = mean, .half = 1.96 * @sqrt(v) };
}

pub const Options = struct {
    outcomes: []const rows.Outcome = &.{ .gold14, .lanediff14, .cs10, .deaths15, .first_item },
    dims: []const u32 = &.{ 4, 8, 16 },
    l2s: []const f32 = &.{ 1e-6, 1e-5, 1e-4 },
    /// Where 2a-<model>.tsv prediction files go (docs/model.md "Shared protocol"); null skips
    preds_dir: ?[]const u8 = null,
};

pub fn run(gpa: std.mem.Allocator, io: std.Io, d: *const rows.Data, opts: Options, w: *std.Io.Writer) !void {
    var ids = try buildIds(gpa, d);
    defer ids.map.deinit(gpa);
    try w.print("{d} champion-role ids (min {d} train rows; rarer share a per-role id)\n\n", .{ ids.n, min_rows });
    try w.print("| outcome | model | config | epochs | test MSE | R2 vs mean | vs base | vs additive |\n", .{});
    try w.print("| --- | --- | --- | --- | --- | --- | --- | --- |\n", .{});

    for (opts.outcomes) |k| {
        var mean: f64 = 0;
        var sd: f64 = 1;
        var sets = try buildSets(gpa, d, &ids, k, &mean, &sd);
        defer sets.deinit(gpa);
        const tests = sets.tests.ex.items;
        const ys = try gpa.alloc(f32, tests.len);
        defer gpa.free(ys);
        for (ys, tests) |*y, e| y.* = e.y;

        var scored: std.ArrayList(Scored) = .empty;
        defer {
            for (scored.items) |s| gpa.free(s.pred);
            scored.deinit(gpa);
        }
        for ([_]fm.Kind{ .base, .additive, .lane, .pairwise }) |kind| {
            var best: ?struct { cfg: fm.Config, epochs: u32, loss: f64 } = null;
            const dims: []const u32 = if (kind == .lane or kind == .pairwise) opts.dims else &.{8};
            for (dims) |dim| for (opts.l2s) |l2| {
                const cfg: fm.Config = .{ .kind = kind, .dim = dim, .l2 = l2 };
                const t0 = std.Io.Clock.awake.now(io);
                var f = try fm.fit(gpa, cfg, ids.n, sets.inner.ex.items, sets.val.ex.items);
                defer f.model.deinit(gpa);
                const ms = t0.durationTo(std.Io.Clock.awake.now(io)).toMilliseconds();
                std.log.info("{s} {s} dim {d} l2 {e}: val {d:.5} at epoch {d} ({d} ms)", .{
                    @tagName(k), @tagName(kind), dim, l2, f.val_loss, f.epochs, ms,
                });
                if (best == null or f.val_loss < best.?.loss) best = .{ .cfg = cfg, .epochs = f.epochs, .loss = f.val_loss };
            };
            const b = best.?;
            var m = try fm.fitEpochs(gpa, b.cfg, ids.n, sets.train.ex.items, @max(b.epochs, 1));
            defer m.deinit(gpa);
            const pred = try gpa.alloc(f32, tests.len);
            for (pred, tests) |*p, *e| p.* = m.predict(e);
            try scored.append(gpa, .{ .label = @tagName(kind), .cfg = b.cfg, .epochs = b.epochs, .pred = pred });
            if (kind == .pairwise) try interactionSizes(&m, tests, sd, k, w);
        }

        const zero = try gpa.alloc(f32, tests.len);
        defer gpa.free(zero);
        @memset(zero, 0);
        const var_units = sd * sd;
        for (scored.items, 0..) |s, i| {
            var se: f64 = 0;
            var se0: f64 = 0;
            for (s.pred, ys) |p, y| {
                se += (p - y) * (p - y);
                se0 += y * y;
            }
            const test_mse = se / @as(f64, @floatFromInt(ys.len)) * var_units;
            const r2 = 1 - se / se0;
            try w.print("| {s} | {s} | dim {d}, l2 {e} | {d} | {d:.4} | {d:.4} |", .{
                @tagName(k), s.label, s.cfg.dim, s.cfg.l2, s.epochs, test_mse, r2,
            });
            for ([_]usize{ 0, 1 }) |against| {
                if (i <= against) {
                    try w.writeAll(" - |");
                    continue;
                }
                const diff = pairedDiff(d, &sets.tests, ys, s.pred, scored.items[against].pred);
                try w.print(" {d:.4} ± {d:.4} |", .{ diff.mean * var_units, diff.half * var_units });
            }
            try w.writeAll("\n");
        }
        try w.flush();
        if (opts.preds_dir) |dir| for (scored.items) |s| {
            try writePreds(gpa, io, d, dir, s.label, k, &sets.tests, mean, sd, s.pred);
        };
    }
}

/// data/preds/<stamp>/2a-<model>.tsv: match_id, slot, outcome, y, pred (appends per outcome)
fn writePreds(
    gpa: std.mem.Allocator,
    io: std.Io,
    d: *const rows.Data,
    dir: []const u8,
    label: []const u8,
    k: rows.Outcome,
    set: *const Set,
    mean: f64,
    sd: f64,
    pred: []const f32,
) !void {
    const name = try std.fmt.allocPrint(gpa, "2a-{s}.tsv", .{label});
    defer gpa.free(name);
    const path = try std.fs.path.join(gpa, &.{ dir, name });
    defer gpa.free(path);
    try std.Io.Dir.cwd().createDirPath(io, dir);
    const fresh = k == .gold14;
    var file = if (fresh)
        try std.Io.Dir.cwd().createFile(io, path, .{})
    else
        try std.Io.Dir.cwd().openFile(io, path, .{ .mode = .write_only });
    defer file.close(io);
    var buf: [64 * 1024]u8 = undefined;
    var out = file.writer(io, &buf);
    if (fresh) try out.interface.writeAll("match_id\tslot\toutcome\ty\tpred\n") else try out.seekTo(try file.length(io));
    for (set.row.items, set.ex.items, pred) |ri, e, p| {
        const r = d.rows[ri];
        try out.interface.print("{s}\t{d}\t{s}\t{d}\t{d:.4}\n", .{
            d.games[r.game].match_id, r.slot,        @tagName(k),
            e.y * sd + mean,          p * sd + mean,
        });
    }
    try out.interface.flush();
}

/// How far each enemy role's interaction term moves each role's outcome on the test
/// rows: root mean square, in outcome units. Which enemies matter to whom, beyond their
/// average effect
fn interactionSizes(m: *const fm.Model, tests: []const fm.Example, sd: f64, k: rows.Outcome, w: *std.Io.Writer) !void {
    var ss: [5][5]f64 = @splat(@splat(0));
    var n: [5]f64 = @splat(0);
    for (tests) |*e| {
        n[e.role] += 1;
        for (0..5) |j| {
            const t = fm.pairTerm(m, e, j);
            ss[e.role][e.enemy_roles[j]] += t * t;
        }
    }
    try w.print("\n{s}, pairwise interaction size (RMS, outcome units), my role x enemy role:\n\n", .{@tagName(k)});
    try w.writeAll("| me \\ enemy | top | jungle | mid | bot | support |\n| --- | --- | --- | --- | --- | --- |\n");
    const names = [_][]const u8{ "top", "jungle", "mid", "bot", "support" };
    for (names, 0..) |name, i| {
        try w.print("| {s} |", .{name});
        for (0..5) |j| try w.print(" {d:.2} |", .{@sqrt(ss[i][j] / @max(n[i], 1)) * sd});
        try w.writeAll("\n");
    }
    try w.writeAll("\n");
}
