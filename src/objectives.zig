//! `meiolol objectives`: what is an objective worth? Win probability from the game state
//! at fixed minutes: the gold and XP lead first, then the objectives each team holds
//! (towers, inhibitors down, dragons, soul point and soul, elder and baron buffs, grubs,
//! herald; no Atakhan in 2026 games). An objective's weight is its value beyond the gold
//! it brought, in log-odds and as the gold lead worth the same; interactions with the
//! gold lead ask whether that value depends on the state. Descriptive, not causal: teams
//! that take objectives differ in ways the state misses.
//! Split as docs/model.md "Shared protocol, 2026-10-12"; one row per game and minute.

const std = @import("std");
const store = @import("store");
const timeline = @import("riot/timeline.zig");
const stats = @import("stats.zig");
const eval = @import("eval.zig");
const analysis = @import("analysis.zig");
const logreg = @import("logreg.zig");
const Date = @import("date.zig").Date;
const Io = std.Io;

pub const Options = struct {
    test_share: f64 = eval.test_share,
    /// Region model only; the global model is never scored on a region
    test_platform: ?[]const u8 = null,
    /// One TSV per model of every test row's prediction
    preds_dir: ?[]const u8 = null,
};

pub const minutes = [_]u8{ 10, 15, 20, 25, 30 };

const minute_ms = 60_000;
/// Respawn and buff durations
const inhib_respawn_ms = 300_000;
const baron_buff_ms = 180_000;
const elder_buff_ms = 150_000;

/// Each blue minus red
pub const Feat = enum {
    /// thousands
    gold,
    /// gold * |gold| / 10: lets the lead's value bend at large leads
    gold_curve,
    /// thousands
    xp,
    towers,
    inhibs_down,
    /// elemental, not elder
    dragons,
    /// 3 elemental dragons, no soul yet
    soul_point,
    soul,
    elder,
    grubs,
    herald,
    baron,
    infernal,
    ocean,
    mountain,
    cloud,
    hextech,
    chemtech,
};
const n_feat = @typeInfo(Feat).@"enum".field_names.len;

pub const State = [n_feat]f32;

const elements = [_]struct { []const u8, Feat }{
    .{ "FIRE_DRAGON", .infernal }, .{ "WATER_DRAGON", .ocean },     .{ "EARTH_DRAGON", .mountain },
    .{ "AIR_DRAGON", .cloud },     .{ "HEXTECH_DRAGON", .hextech }, .{ "CHEMTECH_DRAGON", .chemtech },
};

pub const lead: []const Feat = &.{ .gold, .gold_curve, .xp };
pub const held: []const Feat = &.{ .towers, .inhibs_down, .dragons, .soul_point, .soul, .elder, .grubs, .herald, .baron };
const held_elements: []const Feat = &.{
    .towers, .inhibs_down, .infernal, .ocean,  .mountain, .cloud, .hextech, .chemtech, .soul_point,
    .soul,   .elder,       .grubs,    .herald, .baron,
};

/// after: the model this one adds to, for the step's gain (null: the train win rate)
const Model = struct {
    label: []const u8,
    file: []const u8,
    feats: []const Feat,
    /// each objective's feature x the gold lead
    interact: bool = false,
    after: ?usize,
};

const models = [_]Model{
    .{ .label = "gold and XP lead", .file = "3c-obj-lead", .feats = lead, .after = null },
    .{ .label = "+ objectives held", .file = "3c-obj-held", .feats = lead ++ held, .after = 0 },
    .{ .label = "dragons by element", .file = "3c-obj-elements", .feats = lead ++ held_elements, .after = 1 },
    .{ .label = "+ objective x gold lead", .file = "3c-obj-x", .feats = lead ++ held, .interact = true, .after = 1 },
};
const held_model = 1;
const elements_model = 2;
const interact_model = 3;

/// Ridge on every weight but the intercept: only keeps never-seen features solvable
const l2 = 1;

/// Game state at frame `minute`, from blue's side; null when the game ended by then
/// (frame `minute` is then the end frame, which knows the result)
pub fn stateAt(t: timeline.Timeline, minute: u8) ?State {
    if (t.participants != 10 or t.frames.len < @as(usize, minute) + 2) return null;
    const frame = t.frames[minute];
    if (frame.t_ms < @as(i64, minute) * minute_ms) return null;
    return stateBefore(t, frame, frame.t_ms);
}

/// Game state from blue's side at `at_ms`: gold and XP from `last` (a 10-participant
/// frame at or before it), objectives from the events before it, buffs and inhibitor
/// respawns timed from it
pub fn stateBefore(t: timeline.Timeline, last: timeline.Frame, at_ms: i64) State {
    var s: State = @splat(0);
    var gold: f32 = 0;
    var xp: f32 = 0;
    for (1..11) |p| {
        const sign: f32 = if (p <= 5) 1 else -1;
        gold += sign * @as(f32, @floatFromInt(last.get(@intCast(p), .total_gold)));
        xp += sign * @as(f32, @floatFromInt(last.get(@intCast(p), .xp)));
    }
    s[@backingInt(Feat.gold)] = gold / 1000;
    s[@backingInt(Feat.gold_curve)] = gold / 1000 * @abs(gold / 1000) / 10;
    s[@backingInt(Feat.xp)] = xp / 1000;

    var dragons: [2]u8 = @splat(0);
    var soul = false;
    for (t.events) |e| {
        if (e.t_ms >= at_ms) break;
        const ago = at_ms - e.t_ms;
        switch (e.data) {
            .building_kill => |b| {
                // team owns the building: the other one took it
                const sign: f32 = switch (b.team) {
                    100 => -1,
                    200 => 1,
                    else => continue,
                };
                if (std.mem.eql(u8, b.building, "TOWER_BUILDING")) {
                    s[@backingInt(Feat.towers)] += sign;
                } else if (std.mem.eql(u8, b.building, "INHIBITOR_BUILDING") and ago < inhib_respawn_ms) {
                    s[@backingInt(Feat.inhibs_down)] += sign;
                }
            },
            .elite_monster => |m| {
                const side: usize = switch (m.team) {
                    100 => 0,
                    200 => 1,
                    else => continue,
                };
                const sign: f32 = if (side == 0) 1 else -1;
                const feat: ?Feat = if (std.mem.eql(u8, m.monster, "DRAGON")) blk: {
                    if (std.mem.eql(u8, m.subtype, "ELDER_DRAGON")) {
                        break :blk if (ago < elder_buff_ms) .elder else null;
                    }
                    dragons[side] += 1;
                    s[@backingInt(Feat.dragons)] += sign;
                    break :blk for (elements) |el| {
                        if (std.mem.eql(u8, m.subtype, el[0])) break el[1];
                    } else null;
                } else if (std.mem.eql(u8, m.monster, "HORDE"))
                    .grubs
                else if (std.mem.eql(u8, m.monster, "RIFTHERALD"))
                    .herald
                else if (std.mem.eql(u8, m.monster, "BARON_NASHOR"))
                    if (ago < baron_buff_ms) .baron else null
                else
                    null;
                if (feat) |f| s[@backingInt(f)] += sign;
            },
            // Team 0: the soul's element announced after the second dragon, not taken
            .dragon_soul => |d| {
                const sign: f32 = switch (d.team) {
                    100 => 1,
                    200 => -1,
                    else => continue,
                };
                soul = true;
                s[@backingInt(Feat.soul)] += sign;
            },
            else => {},
        }
    }
    if (!soul) {
        s[@backingInt(Feat.soul_point)] = @as(f32, @floatFromInt(@intFromBool(dragons[0] >= 3))) -
            @as(f32, @floatFromInt(@intFromBool(dragons[1] >= 3)));
    }
    return s;
}

const Game = struct {
    match_id: []const u8,
    states: [minutes.len]?State,
};

const Map = std.AutoHashMapUnmanaged(u64, Game);

fn load(
    gpa: std.mem.Allocator,
    arena: std.mem.Allocator,
    db: store.Db,
    chosen: []const []const u8,
    platforms: []const []const u8,
) !Map {
    var games: analysis.TimelineGames = try .init(gpa, db, chosen, platforms);
    defer games.deinit();
    var map: Map = .empty;
    errdefer map.deinit(gpa);
    while (try games.next()) |game| {
        var g: Game = .{ .match_id = undefined, .states = undefined };
        var any = false;
        for (minutes, &g.states) |m, *s| {
            s.* = stateAt(game.t, m);
            any = any or s.* != null;
        }
        if (!any) continue;
        g.match_id = try arena.dupe(u8, game.match_id);
        try map.put(gpa, stats.matchKey(game.match_id), g);
    }
    return map;
}

fn row(m: Model, s: State, y: f64) logreg.Row {
    var r: logreg.Row = .{ .y = y };
    r.add(0, 1);
    for (m.feats, 1..) |f, i| r.add(@intCast(i), s[@backingInt(f)]);
    if (m.interact) {
        const gold = s[@backingInt(Feat.gold)];
        for (held, 1 + m.feats.len..) |f, i| r.add(@intCast(i), s[@backingInt(f)] * gold);
    }
    return r;
}

fn dims(m: Model) usize {
    return 1 + m.feats.len + if (m.interact) held.len else 0;
}

const Fitted = struct { w: []f64, se: []f64 };

pub fn run(
    gpa: std.mem.Allocator,
    io: Io,
    db: store.Db,
    patches: []const []const u8,
    platforms: []const []const u8,
    opts: Options,
    w: *Io.Writer,
) !void {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    var split = try analysis.heldOut(gpa, db, patches, platforms, opts.test_share, opts.test_platform);
    defer split.deinit();

    var map = try load(gpa, arena, db, patches, platforms);
    defer map.deinit(gpa);

    try w.print("# meiolol objectives\n\nTrain: every scanned platform, games started before " ++
        "{f} ({d}). Test: {s} games from then. One row per game and minute, " ++
        "games still going after that minute. Log loss of blue's win in nats per game; gain " ++
        "= drop in log loss from the step before, ± 95% interval over test games.\n", .{
        Date.fromMs(split.cutoff), split.cutoff, opts.test_platform orelse "every platform's",
    });

    var names: [models.len][]const u8 = undefined;
    for (&names, models) |*n, m| n.* = m.file;
    const preds: analysis.Preds = try .init(arena, io, opts.preds_dir, &names, "match_id\tminute\ty\tpred\n");
    defer preds.close(io);

    var fitted: [minutes.len][models.len]Fitted = undefined;
    var nonzero: [minutes.len][n_feat]f64 = undefined;
    try w.writeAll("\n| minute | train | test | win rate (blue) |");
    for (models) |m| try w.print(" {s} |", .{m.label});
    try w.writeAll("\n| --- | --- | --- | --- |");
    for (models) |_| try w.writeAll(" --- |");
    try w.writeAll("\n");

    for (minutes, 0..) |minute, mi| {
        var train_states: std.ArrayList(State) = .empty;
        var train_y: std.ArrayList(f64) = .empty;
        var test_states: std.ArrayList(State) = .empty;
        var test_y: std.ArrayList(f64) = .empty;
        var test_ids: std.ArrayList([]const u8) = .empty;
        for (split.parts(), [_]bool{ false, true }) |part, is_test| for (part) |g| {
            const game = map.get(g.id) orelse continue;
            const s = game.states[mi] orelse continue;
            const y: f64 = if (g.winner == 0) 1 else 0;
            if (is_test) {
                try test_states.append(arena, s);
                try test_y.append(arena, y);
                try test_ids.append(arena, game.match_id);
            } else {
                try train_states.append(arena, s);
                try train_y.append(arena, y);
            }
        };
        if (train_states.items.len < 100 or test_states.items.len < 20) return error.TooFewGames;
        nonzero[mi] = @splat(0);
        for (train_states.items) |s| for (s, &nonzero[mi]) |x, *n| {
            n.* += @floatFromInt(@intFromBool(x != 0));
        };

        var rate: f64 = 0;
        for (train_y.items) |y| rate += y;
        rate /= @floatFromInt(train_y.items.len);
        const loss_base = try arena.alloc(f64, test_y.items.len);
        for (loss_base, test_y.items) |*l, y| l.* = analysis.logLoss(rate, y);
        var loss: [models.len][]f64 = undefined;

        try w.print("| {d} | {d} | {d} | {d:.1}% |", .{ minute, train_states.items.len, test_states.items.len, 100 * rate });
        const rows = try gpa.alloc(logreg.Row, train_states.items.len);
        defer gpa.free(rows);
        for (models, 0..) |m, k| {
            for (rows, train_states.items, train_y.items) |*r, s, y| r.* = row(m, s, y);
            const d = dims(m);
            const wt = try logreg.fit(gpa, d, rows, l2);
            defer gpa.free(wt);
            const se = try logreg.stdErrors(gpa, d, rows, wt, l2);
            defer gpa.free(se);
            fitted[mi][k] = .{ .w = try arena.dupe(f64, wt), .se = try arena.dupe(f64, se) };

            loss[k] = try arena.alloc(f64, test_y.items.len);
            for (loss[k], test_states.items, test_y.items, test_ids.items) |*l, s, y, id| {
                const r = row(m, s, y);
                const p = logreg.sigmoid(r.dot(wt));
                l.* = analysis.logLoss(p, y);
                if (preds.on()) try preds.at(k).print("{s}\t{d}\t{d}\t{d:.4}\n", .{ id, minute, y, p });
            }
            const g = analysis.pairedGainGames(if (m.after) |a| loss[a] else loss_base, loss[k]);
            try w.print(" {d:.4} ± {d:.4} |", .{ g.mean, g.half_width });
        }
        try w.writeAll("\n");
    }

    try w.writeAll("\nModel 1 is the train win rate (log loss per game from it, by minute:");
    try w.writeAll(" see the gains column's base). Models 2-4 are each a step from the one named " ++
        "in their label.\n");

    try weights(w, &fitted, &nonzero, held_model, held, "Objectives held, beyond the gold " ++
        "and XP lead (+ objectives held): log-odds of a win per unit blue minus red, ± 95%, " ++
        "and [the gold lead worth the same at that minute]. A dragon: one more than the " ++
        "enemy; buffs and inhibitors: active now");
    try weights(w, &fitted, &nonzero, elements_model, held_elements, "Dragons by element (dragons by " ++
        "element model; other rows as above for that model)");
    try interactions(w, &fitted, &nonzero);
    try preds.flush();
}

fn weights(
    w: *Io.Writer,
    fitted: *const [minutes.len][models.len]Fitted,
    nonzero: *const [minutes.len][n_feat]f64,
    k: usize,
    comptime shown: []const Feat,
    title: []const u8,
) !void {
    const m = models[k];
    try w.print("\n### {s}\n\n| feature |", .{title});
    for (minutes) |minute| try w.print(" {d} min |", .{minute});
    try w.writeAll("\n| --- |");
    for (minutes) |_| try w.writeAll(" --- |");
    try w.writeAll("\n");
    const gold_i = 1 + std.mem.indexOfScalar(Feat, m.feats, .gold).?;
    for (lead[0..1] ++ lead[2..] ++ shown) |f| {
        const i = 1 + (std.mem.indexOfScalar(Feat, m.feats, f) orelse continue);
        try w.print("| {t} |", .{f});
        for (fitted, nonzero) |fm, nz| {
            // Too few games with the feature set to say anything
            if (nz[@backingInt(f)] < 30) {
                try w.writeAll(" - |");
                continue;
            }
            const b = fm[k].w[i];
            const se = fm[k].se[i];
            try w.print(" {d:.3} ± {d:.3}", .{ b, 1.96 * se });
            if (f != .gold) try w.print(" [{d:.0}]", .{1000 * b / fm[k].w[gold_i]});
            try w.writeAll(" |");
        }
        try w.writeAll("\n");
    }
    try w.writeAll("| games with it (train) |");
    for (nonzero) |nz| {
        var most: f64 = 0;
        for (shown) |f| most = @max(most, nz[@backingInt(f)]);
        try w.print(" up to {d:.0} |", .{most});
    }
    try w.writeAll("\n");
}

fn interactions(
    w: *Io.Writer,
    fitted: *const [minutes.len][models.len]Fitted,
    nonzero: *const [minutes.len][n_feat]f64,
) !void {
    const m = models[interact_model];
    try w.writeAll("\n### Objective x gold lead (+ objective x gold lead): change in an " ++
        "objective's log-odds per 1000 gold blue leads by, ± 95% (positive: worth more " ++
        "to the team ahead)\n\n| feature |");
    for (minutes) |minute| try w.print(" {d} min |", .{minute});
    try w.writeAll("\n| --- |");
    for (minutes) |_| try w.writeAll(" --- |");
    try w.writeAll("\n");
    for (held, 1 + m.feats.len..) |f, i| {
        try w.print("| {t} |", .{f});
        for (fitted, nonzero) |fm, nz| {
            if (nz[@backingInt(f)] < 30) {
                try w.writeAll(" - |");
                continue;
            }
            try w.print(" {d:.3} ± {d:.3} |", .{ fm[interact_model].w[i], 1.96 * fm[interact_model].se[i] });
        }
        try w.writeAll("\n");
    }
}

const testing = std.testing;

test "state at a minute" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const frames = try arena.alloc(timeline.Frame, 12);
    for (frames, 0..) |*f, i| {
        f.* = .{ .t_ms = @intCast(i * minute_ms + 30) };
        for (0..10) |p| {
            f.stats[p][@backingInt(timeline.Stat.total_gold)] = @intCast(500 + i * 400 + @as(usize, if (p < 5) 100 else 0));
            f.stats[p][@backingInt(timeline.Stat.xp)] = @intCast(i * 500);
        }
    }
    const red_top = "TOP_LANE";
    const events = [_]timeline.Event{
        .{ .t_ms = 300_000, .data = .{ .elite_monster = .{ .killer = 2, .team = 100, .monster = "DRAGON", .subtype = "FIRE_DRAGON", .assists = &.{} } } },
        .{ .t_ms = 320_000, .data = .{ .elite_monster = .{ .killer = 7, .team = 200, .monster = "HORDE", .subtype = "", .assists = &.{} } } },
        .{ .t_ms = 321_000, .data = .{ .elite_monster = .{ .killer = 7, .team = 200, .monster = "HORDE", .subtype = "", .assists = &.{} } } },
        .{ .t_ms = 500_000, .data = .{ .building_kill = .{ .killer = 1, .team = 200, .building = "TOWER_BUILDING", .lane = red_top, .tower = "OUTER_TURRET", .assists = &.{} } } },
        .{ .t_ms = 560_000, .data = .{ .elite_monster = .{ .killer = 2, .team = 100, .monster = "DRAGON", .subtype = "WATER_DRAGON", .assists = &.{} } } },
        // At 10:00.030 this one is still in the future
        .{ .t_ms = 600_100, .data = .{ .elite_monster = .{ .killer = 2, .team = 100, .monster = "RIFTHERALD", .subtype = "", .assists = &.{} } } },
    };
    const t: timeline.Timeline = .{ .participants = 10, .frames = frames, .events = &events };
    const s = stateAt(t, 10).?;
    try testing.expectEqual(0.5, s[@backingInt(Feat.gold)]);
    try testing.expectEqual(0, s[@backingInt(Feat.xp)]);
    try testing.expectEqual(1, s[@backingInt(Feat.towers)]);
    try testing.expectEqual(2, s[@backingInt(Feat.dragons)]);
    try testing.expectEqual(1, s[@backingInt(Feat.infernal)]);
    try testing.expectEqual(1, s[@backingInt(Feat.ocean)]);
    try testing.expectEqual(-2, s[@backingInt(Feat.grubs)]);
    try testing.expectEqual(0, s[@backingInt(Feat.herald)]);
    try testing.expectEqual(0, s[@backingInt(Feat.soul_point)]);
    // Frame 10 is the last one (the end frame) here: no state from it
    try testing.expectEqual(null, stateAt(.{ .participants = 10, .frames = frames[0..11], .events = &events }, 10));
}

test "buffs and inhibitors expire, soul point needs three dragons and no soul" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const frames = try arena.alloc(timeline.Frame, 32);
    for (frames, 0..) |*f, i| f.* = .{ .t_ms = @intCast(i * minute_ms) };
    const drake = timeline.Event.Data{ .elite_monster = .{ .killer = 8, .team = 200, .monster = "DRAGON", .subtype = "AIR_DRAGON", .assists = &.{} } };
    const events = [_]timeline.Event{
        .{ .t_ms = 400_000, .data = drake },
        .{ .t_ms = 700_000, .data = drake },
        .{ .t_ms = 1_000_000, .data = drake },
        .{ .t_ms = 1_000_000, .data = .{ .dragon_soul = .{ .team = 0, .name = "Cloud" } } },
        .{ .t_ms = 1_250_000, .data = .{ .building_kill = .{ .killer = 1, .team = 200, .building = "INHIBITOR_BUILDING", .lane = "MID_LANE", .tower = "", .assists = &.{} } } },
        .{ .t_ms = 1_380_000, .data = .{ .elite_monster = .{ .killer = 1, .team = 100, .monster = "BARON_NASHOR", .subtype = "", .assists = &.{} } } },
        .{ .t_ms = 1_400_000, .data = drake },
        .{ .t_ms = 1_400_000, .data = .{ .dragon_soul = .{ .team = 200, .name = "Cloud" } } },
    };
    const t: timeline.Timeline = .{ .participants = 10, .frames = frames, .events = &events };
    const at20 = stateAt(t, 20).?;
    try testing.expectEqual(-1, at20[@backingInt(Feat.soul_point)]);
    try testing.expectEqual(0, at20[@backingInt(Feat.inhibs_down)]);
    const at25 = stateAt(t, 25).?;
    try testing.expectEqual(0, at25[@backingInt(Feat.soul_point)]);
    try testing.expectEqual(-1, at25[@backingInt(Feat.soul)]);
    try testing.expectEqual(1, at25[@backingInt(Feat.inhibs_down)]);
    try testing.expectEqual(1, at25[@backingInt(Feat.baron)]);
    try testing.expectEqual(-4, at25[@backingInt(Feat.cloud)]);
    const at30 = stateAt(t, 30).?;
    try testing.expectEqual(0, at30[@backingInt(Feat.inhibs_down)]);
    try testing.expectEqual(0, at30[@backingInt(Feat.baron)]);
}
