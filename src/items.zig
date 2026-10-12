//! `meiolol items`: does the item a player finishes change their win chance, given the
//! state when they finish it? Rows: each player's first three distinct finished items
//! (outcomes.zig's finished set and undo rule). A logistic baseline gives the win
//! chance from the purchase's state (minute, team gold lead, lane gold lead, slot);
//! additive effects on its residual, in win probability, follow for the champion, the
//! item in its role and slot, and the item on that champion, each shrunk toward 0 by a
//! method-of-moments prior per role (as outcomes.zig). Descriptive: item choice also
//! answers the enemy team (meiolol-2a's item x enemy team) and the game.
//! Split as docs/model.md "Shared protocol, 2026-10-12".

const std = @import("std");
const store = @import("store");
const core = @import("core");
const timeline = @import("riot/timeline.zig");
const stats = @import("stats.zig");
const eval = @import("eval.zig");
const logreg = @import("logreg.zig");
const outcomes = @import("outcomes.zig");
const Date = @import("date.zig").Date;
const Role = core.Role;
const Io = std.Io;

pub const Options = struct {
    test_share: f64 = 0.2,
    test_platform: []const u8 = "EUW1",
    passes: u32 = 12,
    /// One TSV per model of every test row's prediction
    preds_dir: ?[]const u8 = null,
};

const minute_ms = 60_000;
/// Finished items per player, in order
pub const slots = 3;

/// One finished item of one player
const Row = struct {
    game: u32,
    /// participant id - 1
    slot: u8,
    role: u8,
    champ: u16,
    item: u16,
    /// 0: first finished item
    k: u8,
    minute: f32,
    /// thousands, at the frame before the purchase
    team_lead: f32,
    lane_lead: f32,
    won: bool,
};

/// One player's finished items: purchase time, item id, gold leads then
const Purchase = struct { t_ms: i64, item: u32, team_lead: f32, lane_lead: f32 };

const GameItems = struct {
    match_id: []const u8,
    /// [side][role]: participant id - 1, and its purchases (null: fewer than slots)
    slot: [2][Role.count]u8,
    bought: [2][Role.count][slots]?Purchase,
};

const Map = std.AutoHashMapUnmanaged(u64, GameItems);

const Group = enum {
    /// own champion in its role
    champ,
    /// item in its role and slot
    item,
    /// item on own champion in its role
    champ_item,
};
const n_group = @typeInfo(Group).@"enum".field_names.len;

const Model = struct { label: []const u8, file: []const u8, groups: []const Group };

const models = [_]Model{
    .{ .label = "+ champion", .file = "3c-items-champ", .groups = &.{.champ} },
    .{ .label = "+ item in role and slot", .file = "3c-items-item", .groups = &.{ .champ, .item } },
    .{ .label = "+ item on the champion", .file = "3c-items-champitem", .groups = &.{ .champ, .item, .champ_item } },
};

const Space = struct {
    champs: u32,
    items: u32,

    fn perRole(s: Space, g: Group) u32 {
        return switch (g) {
            .champ => s.champs,
            .item => slots * s.items,
            .champ_item => s.champs * s.items,
        };
    }

    fn cell(s: Space, g: Group, r: Row) u32 {
        const role: u32 = r.role;
        return switch (g) {
            .champ => role * s.champs + r.champ,
            .item => (role * slots + r.k) * s.items + r.item,
            .champ_item => (role * s.champs + r.champ) * s.items + r.item,
        };
    }
};

/// Cells with fewer rows are left out of the spread estimates
const eb_min_rows = 10;
/// Fewer cells in a role and the group is off for it
const eb_min_cells = 20;

const Fit = struct {
    effects: [n_group]?[]f32 = @splat(null),
    /// [group][role]: prior strength in rows (inf: off), spread of true effects
    k: [n_group][Role.count]f64 = @splat(@splat(0)),
    tau: [n_group][Role.count]f64 = @splat(@splat(0)),
    /// [group]: rows behind each cell, for reading effects
    n: [n_group]?[]f32 = @splat(null),

    fn deinit(f: *Fit, gpa: std.mem.Allocator) void {
        for (f.effects) |e| if (e) |x| gpa.free(x);
        for (f.n) |e| if (e) |x| gpa.free(x);
    }

    fn predict(f: *const Fit, s: Space, r: Row) f32 {
        var sum: f32 = 0;
        for (f.effects, 0..) |e, gi| if (e) |b| {
            sum += b[s.cell(@fromBackingInt(@intCast(gi)), r)];
        };
        return sum;
    }
};

/// Backfitting with shrinkage on residuals `z` (outcomes.zig's fit, one term per row)
fn fit(gpa: std.mem.Allocator, s: Space, rows: []const Row, z: []const f32, groups: []const Group, passes: u32) !Fit {
    var f: Fit = .{};
    errdefer f.deinit(gpa);
    const res = try gpa.alloc(f32, rows.len);
    defer gpa.free(res);
    @memcpy(res, z);
    for (groups) |g| {
        const len = Role.count * s.perRole(g);
        const b = try gpa.alloc(f32, len);
        @memset(b, 0);
        f.effects[@backingInt(g)] = b;
        const n = try gpa.alloc(f32, len);
        @memset(n, 0);
        for (rows) |r| n[s.cell(g, r)] += 1;
        f.n[@backingInt(g)] = n;
    }
    var sum_r: std.ArrayList(f64) = .empty;
    defer sum_r.deinit(gpa);
    var old: std.ArrayList(f32) = .empty;
    defer old.deinit(gpa);

    for (0..passes) |_| for (groups) |g| {
        const gi = @backingInt(g);
        const b = f.effects[gi].?;
        const n = f.n[gi].?;
        const per_role = s.perRole(g);
        try sum_r.resize(gpa, b.len);
        @memset(sum_r.items, 0);
        var sum_sq: f64 = 0;
        for (rows, res) |r, e| {
            const c = s.cell(g, r);
            sum_r.items[c] += e + b[c];
            sum_sq += e * e;
        }
        const sigma2 = sum_sq / @as(f64, @floatFromInt(rows.len));
        try old.resize(gpa, b.len);
        @memcpy(old.items, b);
        for (0..Role.count) |ri| {
            const lo = ri * per_role;
            var cells: f64 = 0;
            var excess: f64 = 0;
            for (sum_r.items[lo..][0..per_role], n[lo..][0..per_role]) |xr, xn| {
                if (xn < eb_min_rows) continue;
                const est = xr / xn;
                cells += 1;
                excess += est * est - sigma2 / xn;
            }
            const k = if (cells < eb_min_cells or excess <= 0) std.math.inf(f64) else sigma2 / (excess / cells);
            f.k[gi][ri] = k;
            f.tau[gi][ri] = if (std.math.isInf(k)) 0 else @sqrt(sigma2 / k);
            for (b[lo..][0..per_role], sum_r.items[lo..][0..per_role], n[lo..][0..per_role]) |*x, xr, xn| {
                x.* = if (std.math.isInf(k) or xn == 0) 0 else @floatCast(xr / (xn + k));
            }
        }
        for (rows, res) |r, *e| {
            const c = s.cell(g, r);
            e.* -= b[c] - old.items[c];
        }
    };
    return f;
}

/// The baseline's features for a row: win chance from the purchase's state
fn baseRow(r: Row, y: f64) logreg.Row {
    var b: logreg.Row = .{ .y = y };
    const m = r.minute / 10;
    b.add(0, 1);
    for (0..slots) |k| if (r.k == k) {
        const at: u32 = @intCast(1 + 6 * k);
        b.add(at, r.team_lead);
        b.add(at + 1, r.team_lead / m);
        b.add(at + 2, r.lane_lead);
        b.add(at + 3, m);
        b.add(at + 4, m * m);
        if (k > 0) b.add(at + 5, 1);
    };
    return b;
}
const base_dims = 1 + 6 * slots;

fn logLoss(p: f64, y: f64) f64 {
    const q = std.math.clamp(p, 1e-4, 1 - 1e-4);
    return -(y * @log(q) + (1 - y) * @log(1 - q));
}

const Gain = struct { mean: f64, half_width: f64 };

/// Mean of before - after per row, ± 95% with rows clustered by game (rows sorted by game)
fn pairedGain(rows: []const Row, before: []const f64, after: []const f64) Gain {
    var total: f64 = 0;
    var sum_sq: f64 = 0;
    var n_games: f64 = 0;
    var i: usize = 0;
    while (i < rows.len) {
        var d: f64 = 0;
        const g = rows[i].game;
        while (i < rows.len and rows[i].game == g) : (i += 1) d += before[i] - after[i];
        total += d;
        sum_sq += d * d;
        n_games += 1;
    }
    const n_rows: f64 = @floatFromInt(rows.len);
    const mean_d = total / n_games;
    const var_d = sum_sq / n_games - mean_d * mean_d;
    return .{ .mean = total / n_rows, .half_width = 1.96 * @sqrt(n_games * var_d) / n_rows };
}

/// Each player's first `slots` distinct finished items, in games with a timeline
fn load(
    gpa: std.mem.Allocator,
    arena: std.mem.Allocator,
    db: store.Db,
    chosen: []const []const u8,
    platforms: []const []const u8,
    legendaries: *const outcomes.Legendaries,
) !Map {
    const patch_json = try std.json.Stringify.valueAlloc(arena, chosen, .{});
    const platform_json = try std.json.Stringify.valueAlloc(arena, platforms, .{});
    var q = try db.prepare(
        \\SELECT m.match_id, t.data, m.patch
        \\FROM matches m JOIN timeline.timelines t USING (match_id)
        \\WHERE m.patch IN (SELECT value FROM json_each(?)) AND m.queue_id = ?
        \\  AND m.platform IN (SELECT value FROM json_each(?))
        \\  AND m.remake = 0 AND m.winning_team IS NOT NULL
    );
    defer q.deinit();
    try q.bind(.{ patch_json, stats.ranked_solo, platform_json });
    var players = try db.prepare("SELECT slot, team_id, position FROM participants WHERE match_id = ?");
    defer players.deinit();

    var map: Map = .empty;
    errdefer map.deinit(gpa);
    var scratch_state: std.heap.ArenaAllocator = .init(gpa);
    defer scratch_state.deinit();
    while (try q.step()) {
        _ = scratch_state.reset(.retain_capacity);
        const scratch = scratch_state.allocator();
        const t = timeline.decode(scratch, store.raw.decompress(scratch, q.bytes(1)) catch continue) catch continue;
        if (t.participants != 10 or t.frames.len == 0) continue;
        const finished = legendaries.get(stats.patchKey(q.bytes(2))) orelse continue;

        try players.bind(.{q.bytes(0)});
        var pid: [2][Role.count]u8 = @splat(@splat(0));
        while (try players.step()) {
            const side: usize = switch (players.int(1)) {
                100 => 0,
                200 => 1,
                else => continue,
            };
            const r = Role.fromLcu(if (players.isNull(2)) "" else players.bytes(2)) orelse continue;
            const slot = players.int(0);
            if (slot < 0 or slot >= t.participants) continue;
            pid[side][@backingInt(r)] = @intCast(slot + 1);
        }
        if (std.mem.indexOfScalar(u8, std.mem.asBytes(&pid), 0) != null) continue;
        // participant id - 1 -> lane opponent's participant id
        var opponent: [10]u8 = undefined;
        for (0..2) |side| for (0..Role.count) |ri| {
            opponent[pid[side][ri] - 1] = pid[1 - side][ri];
        };

        var bought: [10][slots]Purchase = undefined;
        var count: [10]u8 = @splat(0);
        // An undo removes a finished item only while it is p's latest purchase
        var last_finished: [10]bool = @splat(false);
        for (t.events) |e| switch (e.data) {
            .item_purchased => |b| if (b.participant >= 1 and b.participant <= 10) {
                const p = b.participant - 1;
                last_finished[p] = false;
                if (count[p] == slots or std.sort.binarySearch(u32, finished, b.item, orderU32) == null) continue;
                for (bought[p][0..count[p]]) |x| {
                    if (x.item == b.item) break;
                } else {
                    const frame = t.frames[@min(@as(usize, @intCast(@divFloor(e.t_ms, minute_ms))), t.frames.len - 1)];
                    var team_lead: f32 = 0;
                    for (1..11) |o| {
                        const same = (o <= 5) == (b.participant <= 5);
                        const gold: f32 = @floatFromInt(frame.get(@intCast(o), .total_gold));
                        team_lead += if (same) gold else -gold;
                    }
                    const lane_lead = frame.get(b.participant, .total_gold) - frame.get(opponent[p], .total_gold);
                    bought[p][count[p]] = .{
                        .t_ms = e.t_ms,
                        .item = b.item,
                        .team_lead = team_lead / 1000,
                        .lane_lead = @as(f32, @floatFromInt(lane_lead)) / 1000,
                    };
                    count[p] += 1;
                    last_finished[p] = true;
                }
            },
            .item_undo => |u| if (u.participant >= 1 and u.participant <= 10) {
                const p = u.participant - 1;
                if (last_finished[p] and u.after == 0 and u.before == bought[p][count[p] - 1].item) {
                    count[p] -= 1;
                    last_finished[p] = false;
                }
            },
            else => {},
        };

        var g: GameItems = .{ .match_id = try arena.dupe(u8, q.bytes(0)), .slot = undefined, .bought = undefined };
        for (0..2) |side| for (0..Role.count) |ri| {
            const p = pid[side][ri] - 1;
            g.slot[side][ri] = p;
            for (&g.bought[side][ri], 0..) |*x, k| x.* = if (k < count[p]) bought[p][k] else null;
        };
        try map.put(gpa, stats.matchKey(q.bytes(0)), g);
    }
    return map;
}

fn orderU32(a: u32, b: u32) std.math.Order {
    return std.math.order(a, b);
}

const GameList = struct {
    gpa: std.mem.Allocator,
    items: std.ArrayList(stats.Row) = .empty,

    pub fn add(l: *GameList, g: stats.Row) !void {
        try l.items.append(l.gpa, g);
    }
};

fn denseIndex(gpa: std.mem.Allocator, index: *std.AutoHashMapUnmanaged(u32, u16), ids: *std.ArrayList(u32), id: u32) !u16 {
    const e = try index.getOrPut(gpa, id);
    if (!e.found_existing) {
        e.value_ptr.* = @intCast(ids.items.len);
        try ids.append(gpa, id);
    }
    return e.value_ptr.*;
}

pub fn run(
    gpa: std.mem.Allocator,
    io: Io,
    db: store.Db,
    patches: []const []const u8,
    platforms: []const []const u8,
    legendaries: *const outcomes.Legendaries,
    opts: Options,
    w: *Io.Writer,
) !void {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    var list: GameList = .{ .gpa = gpa };
    defer list.items.deinit(gpa);
    _ = try stats.scan(gpa, db, patches, platforms, 0, &list);
    var split = try eval.split(gpa, list.items.items, platforms, .{ .test_share = opts.test_share, .test_platform = opts.test_platform });
    defer split.deinit(gpa);
    const cutoff = split.tests[0].start;

    var map = try load(gpa, arena, db, patches, platforms, legendaries);
    defer map.deinit(gpa);

    var champ_index: std.AutoHashMapUnmanaged(u32, u16) = .empty;
    defer champ_index.deinit(gpa);
    var champ_ids: std.ArrayList(u32) = .empty;
    defer champ_ids.deinit(gpa);
    var item_index: std.AutoHashMapUnmanaged(u32, u16) = .empty;
    defer item_index.deinit(gpa);
    var item_ids: std.ArrayList(u32) = .empty;
    defer item_ids.deinit(gpa);

    var train: std.ArrayList(Row) = .empty;
    defer train.deinit(gpa);
    var tests: std.ArrayList(Row) = .empty;
    defer tests.deinit(gpa);
    var test_ids: std.ArrayList([]const u8) = .empty;
    defer test_ids.deinit(gpa);
    var n_games: [2]u32 = @splat(0);
    for ([_][]const stats.Row{ split.train, split.tests }, [_]bool{ false, true }) |part, is_test| for (part) |g| {
        const gi = map.get(g.id) orelse continue;
        const out = if (is_test) &tests else &train;
        if (is_test) try test_ids.append(gpa, gi.match_id);
        const game = n_games[@intFromBool(is_test)];
        n_games[@intFromBool(is_test)] += 1;
        for (0..2) |side| for (0..Role.count) |ri| {
            const champ = try denseIndex(gpa, &champ_index, &champ_ids, g.teams[side][ri]);
            for (gi.bought[side][ri], 0..) |x, k| {
                const b = x orelse break;
                try out.append(gpa, .{
                    .game = game,
                    .slot = gi.slot[side][ri],
                    .role = @intCast(ri),
                    .champ = champ,
                    .item = try denseIndex(gpa, &item_index, &item_ids, b.item),
                    .k = @intCast(k),
                    .minute = @floatCast(@as(f64, @floatFromInt(b.t_ms)) / minute_ms),
                    .team_lead = b.team_lead,
                    .lane_lead = b.lane_lead,
                    .won = g.winner == side,
                });
            }
        };
    };
    if (train.items.len == 0 or tests.items.len == 0) return error.TooFewGames;
    const space: Space = .{ .champs = @intCast(champ_ids.items.len), .items = @intCast(item_ids.items.len) };

    try w.print("# meiolol items\n\nTrain: {d} games with a timeline, every scanned platform, " ++
        "started before {f} ({d}). Test: {d} {s} games from then. Rows: each player's first " ++
        "{d} distinct finished items ({d} train, {d} test). Champions {d}, items {d}.\n", .{
        n_games[0],         Date.fromMs(cutoff), cutoff,          n_games[1],
        opts.test_platform, slots,               train.items.len, tests.items.len,
        space.champs,       space.items,
    });

    // Baseline: the purchase's state
    const base_rows = try gpa.alloc(logreg.Row, train.items.len);
    defer gpa.free(base_rows);
    for (base_rows, train.items) |*b, r| b.* = baseRow(r, @floatFromInt(@intFromBool(r.won)));
    const wb = try logreg.fit(gpa, base_dims, base_rows, 1);
    defer gpa.free(wb);
    const z = try gpa.alloc(f32, train.items.len);
    defer gpa.free(z);
    var rate: f64 = 0;
    for (z, base_rows) |*x, *b| {
        x.* = @floatCast(b.y - logreg.sigmoid(b.dot(wb)));
        rate += b.y;
    }
    rate /= @floatFromInt(train.items.len);

    const p_base = try arena.alloc(f64, tests.items.len);
    const loss_rate = try arena.alloc(f64, tests.items.len);
    const loss_base = try arena.alloc(f64, tests.items.len);
    for (tests.items, p_base, loss_rate, loss_base) |r, *p, *lr, *lb| {
        const y: f64 = @floatFromInt(@intFromBool(r.won));
        const b = baseRow(r, y);
        p.* = logreg.sigmoid(b.dot(wb));
        lr.* = logLoss(rate, y);
        lb.* = logLoss(p.*, y);
    }

    var files: [models.len + 1]?Io.File = @splat(null);
    var bufs: [models.len + 1][16 * 1024]u8 = undefined;
    var writers: [models.len + 1]Io.File.Writer = undefined;
    defer for (files) |f| if (f) |x| x.close(io);
    if (opts.preds_dir) |dir| {
        const cwd = Io.Dir.cwd();
        try cwd.createDirPath(io, dir);
        for (0..models.len + 1) |i| {
            const name = if (i == 0) "3c-items-state" else models[i - 1].file;
            const path = try std.fmt.allocPrint(arena, "{s}/{s}.tsv", .{ dir, name });
            files[i] = try cwd.createFile(io, path, .{});
            writers[i] = files[i].?.writer(io, &bufs[i]);
            try writers[i].interface.writeAll("match_id\tslot\tk\ty\tpred\n");
        }
        for (tests.items, p_base) |r, p| try writers[0].interface.print("{s}\t{d}\t{d}\t{d}\t{d:.4}\n", .{
            test_ids.items[r.game], r.slot, r.k, @intFromBool(r.won), p,
        });
    }

    try w.writeAll("\nTest log loss of the player's win, nats per row; gain = drop from the step " ++
        "before, ± 95% interval clustered by game.\n\n| model | test log loss | gain |\n" ++
        "| --- | --- | --- |\n");
    try w.print("| train win rate | {d:.4} | - |\n", .{mean(loss_rate)});
    const g0 = pairedGain(tests.items, loss_rate, loss_base);
    try w.print("| state at purchase (minute, team and lane gold lead, slot) | {d:.4} | {d:.5} ± {d:.5} |\n", .{
        mean(loss_base), g0.mean, g0.half_width,
    });

    var fits: [models.len]Fit = undefined;
    var n_fits: usize = 0;
    defer for (fits[0..n_fits]) |*f| f.deinit(gpa);
    var before = loss_base;
    for (models, 0..) |m, mi| {
        fits[mi] = try fit(gpa, space, train.items, z, m.groups, opts.passes);
        n_fits += 1;
        const loss = try arena.alloc(f64, tests.items.len);
        for (tests.items, p_base, loss) |r, pb, *l| {
            const p = std.math.clamp(pb + fits[mi].predict(space, r), 0.01, 0.99);
            l.* = logLoss(p, @floatFromInt(@intFromBool(r.won)));
            if (opts.preds_dir != null) try writers[mi + 1].interface.print("{s}\t{d}\t{d}\t{d}\t{d:.4}\n", .{
                test_ids.items[r.game], r.slot, r.k, @intFromBool(r.won), p,
            });
        }
        const g = pairedGain(tests.items, before, loss);
        try w.print("| {s} | {d:.4} | {d:.5} ± {d:.5} |\n", .{ m.label, mean(loss), g.mean, g.half_width });
        before = loss;
    }

    const full = &fits[models.len - 1];
    try w.writeAll("\nSpread of true effects (sd, win percentage points) and prior strength " ++
        "(rows), by role, from the fullest model:\n\n| group |");
    for (Role.all) |r| try w.print(" {t} |", .{r});
    try w.writeAll("\n| --- |");
    for (Role.all) |_| try w.writeAll(" --- |");
    try w.writeAll("\n");
    for (0..n_group) |gi| {
        try w.print("| {t} |", .{@as(Group, @fromBackingInt(@intCast(gi)))});
        for (0..Role.count) |ri| {
            const k = full.k[gi][ri];
            if (std.math.isInf(k)) {
                try w.writeAll(" off |");
            } else try w.print(" {d:.2} ({d:.0}) |", .{ 100 * full.tau[gi][ri], k });
        }
        try w.writeAll("\n");
    }

    try topEffects(w, arena, db, space, full, .item, champ_ids.items, item_ids.items, 500);
    try topEffects(w, arena, db, space, full, .champ_item, champ_ids.items, item_ids.items, 300);
    for (files, &writers) |f, *x| if (f != null) try x.interface.flush();
}

fn mean(xs: []const f64) f64 {
    var sum: f64 = 0;
    for (xs) |x| sum += x;
    return sum / @as(f64, @floatFromInt(xs.len));
}

/// The largest shrunk effects of a group, cells with `min_rows` train rows or more
fn topEffects(
    w: *Io.Writer,
    arena: std.mem.Allocator,
    db: store.Db,
    s: Space,
    f: *const Fit,
    g: Group,
    champ_ids: []const u32,
    item_ids: []const u32,
    min_rows: f32,
) !void {
    const b = f.effects[@backingInt(g)] orelse return;
    const n = f.n[@backingInt(g)].?;
    var cells: std.ArrayList(u32) = .empty;
    for (b, n, 0..) |x, xn, c| if (xn >= min_rows and x != 0) try cells.append(arena, @intCast(c));
    const Order = struct {
        b: []const f32,
        fn more(o: @This(), x: u32, y: u32) bool {
            return @abs(o.b[x]) > @abs(o.b[y]);
        }
    };
    std.mem.sort(u32, cells.items, Order{ .b = b }, Order.more);
    var name = try db.prepare("SELECT name FROM champions WHERE id = ?");
    defer name.deinit();
    try w.print("\nLargest {t} effects (win pp, shrunk; cells with {d:.0}+ train rows; {d} " ++
        "such cells):\n\n| role | champion | slot | item | effect | rows |\n| --- | --- | --- | --- " ++
        "| --- | --- |\n", .{ g, min_rows, cells.items.len });
    for (cells.items[0..@min(cells.items.len, 20)]) |c| {
        const per_role = s.perRole(g);
        const role: Role = @fromBackingInt(@intCast(c / per_role));
        const in_role = c % per_role;
        const item = item_ids[in_role % s.items];
        try w.print("| {t} |", .{role});
        if (g == .champ_item) {
            try name.bind(.{@as(i64, champ_ids[in_role / s.items])});
            try w.print(" {s} | - |", .{if (try name.step()) name.bytes(0) else "?"});
        } else try w.print(" - | {d} |", .{in_role / s.items + 1});
        try w.print(" {d} | {d:.2} | {d:.0} |\n", .{ item, 100 * b[c], n[c] });
    }
}

const testing = std.testing;

test "first three distinct finished items, undo and the state at purchase" {
    const gpa = testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const frames = try arena.alloc(timeline.Frame, 30);
    for (frames, 0..) |*f, i| {
        f.* = .{ .t_ms = @intCast(i * minute_ms) };
        // Blue top (1) 300 ahead of red top (6) from minute 10; the rest level
        for (0..10) |p| f.stats[p][@backingInt(timeline.Stat.total_gold)] = @intCast(500 + i * 400);
        if (i >= 10) f.stats[0][@backingInt(timeline.Stat.total_gold)] += 300;
    }
    const buy = struct {
        fn at(t_ms: i64, item: u32) timeline.Event {
            return .{ .t_ms = t_ms, .data = .{ .item_purchased = .{ .participant = 1, .item = item } } };
        }
    }.at;
    const events = [_]timeline.Event{
        buy(600_000, 3078),
        .{ .t_ms = 601_000, .data = .{ .item_undo = .{ .participant = 1, .before = 3078, .after = 0, .gold = 3300 } } },
        buy(660_000, 3153),
        // Not finished, then a repeat of a finished one: neither counts
        buy(700_000, 1001),
        buy(800_000, 3153),
        buy(900_000, 3078),
        buy(1_000_000, 6610),
        buy(1_100_000, 3071),
    };
    const blob = try store.raw.compress(arena, try timeline.encode(arena, .{ .participants = 10, .frames = frames, .events = &events }));

    const db = try store.schema.memory();
    defer db.close();
    try db.run("INSERT INTO matches VALUES ('EUW1_1','t','EUW1',420,'16.20','',0,1800,100,0)", .{});
    try db.run("INSERT INTO timeline.timelines VALUES ('EUW1_1',30,0,?)", .{store.Blob{ .bytes = blob }});
    const positions = [_][]const u8{ "TOP", "JUNGLE", "MIDDLE", "BOTTOM", "UTILITY" };
    for (0..10) |slot| {
        try db.run(
            \\INSERT INTO participants (match_id, slot, team_id, champion_id, position, win)
            \\VALUES ('EUW1_1',?,?,?,?,0)
        , .{ slot, @as(i64, if (slot < 5) 100 else 200), slot + 1, positions[slot % 5] });
    }
    var legendaries: outcomes.Legendaries = .empty;
    defer legendaries.deinit(gpa);
    try legendaries.put(gpa, stats.patchKey("16.20"), &.{ 3071, 3078, 3153, 6610 });
    var map = try load(gpa, arena, db, &.{"16.20"}, &.{"EUW1"}, &legendaries);
    defer map.deinit(gpa);
    const g = map.get(stats.matchKey("EUW1_1")).?;
    const top = g.bought[0][@backingInt(Role.top)];
    try testing.expectEqual(3153, top[0].?.item);
    try testing.expectEqual(3078, top[1].?.item);
    try testing.expectEqual(6610, top[2].?.item);
    try testing.expectEqual(0.3, top[0].?.lane_lead);
    try testing.expectEqual(0.3, top[0].?.team_lead);
    try testing.expectEqual(null, g.bought[1][@backingInt(Role.top)][0]);
}
