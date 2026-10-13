//! `meiolol playstyle`: does how a player plays the first 14 minutes change their win
//! chance? Features per player from the compact timeline (time away from their lane,
//! time in the enemy half, fights, damage, wards, off-role CS), standardised per role.
//! Scored twice on win: over the champion in its role, and over that plus the state at
//! 14:00 (team and lane gold lead, team XP lead), since players who are ahead or behind
//! play differently. Use-time: the user's own style, post-game only.
//! Split as docs/model.md "Shared protocol, 2026-10-12"; games reaching 15:00.

const std = @import("std");
const store = @import("store");
const core = @import("core");
const timeline = @import("riot/timeline.zig");
const stats = @import("stats.zig");
const analysis = @import("analysis.zig");
const logreg = @import("logreg.zig");
const Date = @import("date.zig").Date;
const Role = core.Role;
const Io = std.Io;

pub const Options = struct {
    test_share: f64 = 0.2,
    test_platform: []const u8 = "EUW1",
    preds_dir: ?[]const u8 = null,
};

const minute_ms = 60_000;
/// Features cover frames and events before this minute; the state is read at it
const until_minute = 14;
/// Position frames from here on: before it everyone is walking to lane or a first camp
const first_position_frame = 3;

pub const Feat = enum {
    /// laners: share of position frames out of their own lane and base; junglers: share
    /// in any lane
    away,
    /// share of position frames on the enemy side of the river diagonal
    enemy_half,
    /// kills + assists + deaths
    fights,
    /// damage to champions, thousands
    damage,
    /// trinket, stealth and control wards placed
    wards,
    control_wards,
    ward_kills,
    /// laners: jungle camps taken; junglers: lane minions
    off_role_cs,
};
const n_feat: u32 = @typeInfo(Feat).@"enum".field_names.len;

const Zone = enum { blue_base, red_base, top, mid, bot, other };

/// Summoner's Rift, coordinates 0 to ~14800, blue base bottom left. Lane bands are
/// rough (one position a minute is rough anyway)
fn zone(x: i32, y: i32) Zone {
    if (x < 4000 and y < 4000) return .blue_base;
    if (x > 10800 and y > 10800) return .red_base;
    if ((x < 2600 and y > 4000) or (y > 12200 and x < 10800)) return .top;
    if ((y < 2600 and x > 4000) or (x > 12200 and y < 10800)) return .bot;
    if (@abs(x - y) < 1800) return .mid;
    return .other;
}

fn laneZone(role: Role) ?Zone {
    return switch (role) {
        .top => .top,
        .middle => .mid,
        .bottom, .utility => .bot,
        .jungle => null,
    };
}

/// Style features of every player, by participant id - 1
fn features(t: timeline.Timeline, roles: [10]Role) [10][n_feat]f32 {
    var out: [10][n_feat]f32 = @splat(@splat(0));
    const last = @min(until_minute, t.frames.len - 1);
    for (0..10) |p| {
        const pid: u8 = @intCast(p + 1);
        const blue = p < 5;
        const own_base: Zone = if (blue) .blue_base else .red_base;
        var frames: f32 = 0;
        for (t.frames[first_position_frame..last]) |f| {
            const x = f.get(pid, .x);
            const y = f.get(pid, .y);
            const z = zone(x, y);
            frames += 1;
            const away = if (laneZone(roles[p])) |lane|
                z != lane and z != own_base
            else
                z == .top or z == .mid or z == .bot;
            out[p][@backingInt(Feat.away)] += @floatFromInt(@intFromBool(away));
            const enemy_side = if (blue) x + y > 14800 else x + y < 14800;
            out[p][@backingInt(Feat.enemy_half)] += @floatFromInt(@intFromBool(enemy_side and z != own_base));
        }
        out[p][@backingInt(Feat.away)] /= @max(frames, 1);
        out[p][@backingInt(Feat.enemy_half)] /= @max(frames, 1);
        const f = t.frames[last];
        out[p][@backingInt(Feat.damage)] = @as(f32, @floatFromInt(f.get(pid, .damage_to_champions))) / 1000;
        out[p][@backingInt(Feat.off_role_cs)] = @floatFromInt(if (roles[p] == .jungle) f.get(pid, .minions) else f.get(pid, .jungle_minions));
    }
    for (t.events) |e| {
        if (e.t_ms >= until_minute * minute_ms) break;
        switch (e.data) {
            .champion_kill => |k| {
                if (k.killer >= 1 and k.killer <= 10) out[k.killer - 1][@backingInt(Feat.fights)] += 1;
                if (k.victim >= 1 and k.victim <= 10) out[k.victim - 1][@backingInt(Feat.fights)] += 1;
                for (k.assists) |a| if (a >= 1 and a <= 10) {
                    out[a - 1][@backingInt(Feat.fights)] += 1;
                };
            },
            .ward_placed => |wd| if (wd.participant >= 1 and wd.participant <= 10) {
                const p = wd.participant - 1;
                const control = std.mem.eql(u8, wd.ward, "CONTROL_WARD");
                if (control or std.mem.eql(u8, wd.ward, "YELLOW_TRINKET") or
                    std.mem.eql(u8, wd.ward, "SIGHT_WARD") or std.mem.eql(u8, wd.ward, "BLUE_TRINKET"))
                {
                    out[p][@backingInt(Feat.wards)] += 1;
                }
                if (control) out[p][@backingInt(Feat.control_wards)] += 1;
            },
            .ward_kill => |wd| if (wd.participant >= 1 and wd.participant <= 10) {
                out[wd.participant - 1][@backingInt(Feat.ward_kills)] += 1;
            },
            else => {},
        }
    }
    return out;
}

/// Blue minus red at 14:00, thousands: team gold, team XP; and each player's lane lead
const State = struct { team_gold: f32, team_xp: f32, lane: [10]f32 };

const Game = struct {
    match_id: []const u8,
    /// [side][role]: participant id - 1
    slot: [2][Role.count]u8,
    feats: [10][n_feat]f32,
    state: State,
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
        const t = game.t;
        if (t.participants != 10 or t.frames.len < 16 or t.frames[15].t_ms < 15 * minute_ms) continue;
        const pid = try games.pids(game, true) orelse continue;
        var roles: [10]Role = undefined;
        var opponent: [10]u8 = undefined;
        for (0..2) |side| for (0..Role.count) |ri| {
            const p = pid[side][ri];
            roles[p - 1] = @fromBackingInt(@intCast(ri));
            opponent[p - 1] = pid[1 - side][ri];
        };

        const f = t.frames[until_minute];
        var st: State = .{ .team_gold = 0, .team_xp = 0, .lane = undefined };
        for (1..11) |p| {
            const sign: f32 = if (p <= 5) 1 else -1;
            st.team_gold += sign * @as(f32, @floatFromInt(f.get(@intCast(p), .total_gold))) / 1000;
            st.team_xp += sign * @as(f32, @floatFromInt(f.get(@intCast(p), .xp))) / 1000;
            st.lane[p - 1] = @as(f32, @floatFromInt(f.get(@intCast(p), .total_gold) - f.get(opponent[p - 1], .total_gold))) / 1000;
        }
        var g: Game = .{
            .match_id = try arena.dupe(u8, game.match_id),
            .slot = undefined,
            .feats = features(t, roles),
            .state = st,
        };
        for (0..2) |side| for (0..Role.count) |ri| {
            g.slot[side][ri] = pid[side][ri] - 1;
        };
        try map.put(gpa, stats.matchKey(game.match_id), g);
    }
    return map;
}

const Row = struct {
    game: u32,
    slot: u8,
    role: u8,
    champ: u16,
    /// standardised per role on train after loading
    x: [n_feat]f32,
    /// own side's: team gold lead, team XP lead, lane lead
    state: [3]f32,
    won: bool,
};

const Model = struct { label: []const u8, file: []const u8, style: bool, state: bool, after: ?usize };

const models = [_]Model{
    .{ .label = "champion in role", .file = "3c-style-champ", .style = false, .state = false, .after = null },
    .{ .label = "+ style", .file = "3c-style", .style = true, .state = false, .after = 0 },
    .{ .label = "champion + state at 14:00", .file = "3c-style-state", .style = false, .state = true, .after = 0 },
    .{ .label = "+ style, given the state", .file = "3c-style-given", .style = true, .state = true, .after = 2 },
};

const Dims = struct {
    champs: u32,

    fn champ(d: Dims, r: Row) u32 {
        return 1 + @as(u32, r.role) * d.champs + r.champ;
    }
    fn style(d: Dims, role: u8, f: usize) u32 {
        return 1 + Role.count * d.champs + @as(u32, role) * n_feat + @as(u32, @intCast(f));
    }
    /// state x role: its value differs by role (a lane lead means more for some)
    fn state(d: Dims, role: u8, i: usize) u32 {
        return 1 + Role.count * d.champs + Role.count * n_feat + @as(u32, role) * 3 + @as(u32, @intCast(i));
    }
    fn total(d: Dims) usize {
        return 1 + Role.count * d.champs + Role.count * n_feat + Role.count * 3;
    }

    fn row(d: Dims, m: Model, r: Row) logreg.Row {
        var b: logreg.Row = .{ .y = @floatFromInt(@intFromBool(r.won)) };
        b.add(0, 1);
        b.add(d.champ(r), 1);
        if (m.style) for (r.x, 0..) |x, f| b.add(d.style(r.role, f), x);
        if (m.state) for (r.state, 0..) |x, i| b.add(d.state(r.role, i), x);
        return b;
    }
};

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

    var index: analysis.DenseIndex = .{};
    defer index.deinit(gpa);
    var train: std.ArrayList(Row) = .empty;
    defer train.deinit(gpa);
    var tests: std.ArrayList(Row) = .empty;
    defer tests.deinit(gpa);
    var test_ids: std.ArrayList([]const u8) = .empty;
    defer test_ids.deinit(gpa);
    var n_games: [2]u32 = @splat(0);
    for (split.parts(), [_]bool{ false, true }) |part, is_test| for (part) |g| {
        const gm = map.get(g.id) orelse continue;
        const out = if (is_test) &tests else &train;
        if (is_test) try test_ids.append(gpa, gm.match_id);
        const game = n_games[@intFromBool(is_test)];
        n_games[@intFromBool(is_test)] += 1;
        for (0..2) |side| for (0..Role.count) |ri| {
            const champ = try index.get(gpa, g.teams[side][ri]);
            const p = gm.slot[side][ri];
            const sign: f32 = if (side == 0) 1 else -1;
            try out.append(gpa, .{
                .game = game,
                .slot = p,
                .role = @intCast(ri),
                .champ = champ,
                .x = gm.feats[p],
                .state = .{ sign * gm.state.team_gold, sign * gm.state.team_xp, gm.state.lane[p] },
                .won = g.winner == side,
            });
        };
    };
    if (train.items.len == 0 or tests.items.len == 0) return error.TooFewGames;

    // Standardise per role on train
    var mean: [Role.count][n_feat]f64 = @splat(@splat(0));
    var sd: [Role.count][n_feat]f64 = @splat(@splat(0));
    var count: [Role.count]f64 = @splat(0);
    for (train.items) |r| {
        count[r.role] += 1;
        for (r.x, &mean[r.role], &sd[r.role]) |x, *m, *s| {
            m.* += x;
            s.* += x * x;
        }
    }
    for (&mean, &sd, count) |*m, *s, n| for (m, s) |*mi, *si| {
        mi.* /= @max(n, 1);
        si.* = @sqrt(@max(si.* / @max(n, 1) - mi.* * mi.*, 1e-12));
    };
    for ([_][]Row{ train.items, tests.items }) |part| for (part) |*r| {
        for (&r.x, mean[r.role], sd[r.role]) |*x, m, s| x.* = @floatCast((x.* - m) / s);
    };

    try w.print("# meiolol playstyle\n\nTrain: {d} games reaching 15:00, every scanned platform, " ++
        "started before {f} ({d}). Test: {d} {s} games from then, ten rows each. Style from " ++
        "minutes 0-{d} (positions from minute {d}); state at {d}:00.\n\nRole mean (sd) of each " ++
        "feature on train:\n\n| feature |", .{
        n_games[0],           Date.fromMs(split.cutoff), split.cutoff, n_games[1], opts.test_platform, until_minute - 1,
        first_position_frame, until_minute,
    });
    for (Role.all) |r| try w.print(" {t} |", .{r});
    try w.writeAll("\n| --- |");
    for (Role.all) |_| try w.writeAll(" --- |");
    try w.writeAll("\n");
    for (0..n_feat) |f| {
        try w.print("| {t} |", .{@as(Feat, @fromBackingInt(@intCast(f)))});
        for (0..Role.count) |ri| try w.print(" {d:.2} ({d:.2}) |", .{ mean[ri][f], sd[ri][f] });
        try w.writeAll("\n");
    }

    const dims: Dims = .{ .champs = index.count() };
    const d = dims.total();
    const rows = try gpa.alloc(logreg.Row, train.items.len);
    defer gpa.free(rows);
    const row_games = try arena.alloc(u32, train.items.len);
    for (row_games, train.items) |*g, r| g.* = r.game;

    var names: [models.len][]const u8 = undefined;
    for (&names, models) |*n, m| n.* = m.file;
    const preds: analysis.Preds = try .init(arena, io, opts.preds_dir, &names, "match_id\tslot\toutcome\ty\tpred\n");
    defer preds.close(io);

    try w.writeAll("\nTest log loss of the player's win, nats per row; gain = drop from the model " ++
        "named, ± 95% clustered by game.\n\n| model | test log loss | gain |\n| --- | --- | --- |\n");
    var loss: [models.len][]f64 = undefined;
    var weights: [models.len][]f64 = undefined;
    var errors: [models.len][]f64 = undefined;
    for (models, 0..) |m, k| {
        for (rows, train.items) |*b, r| b.* = dims.row(m, r);
        const wt = try logreg.fit(gpa, d, rows, 1);
        defer gpa.free(wt);
        // A game's ten rows share its outcome and mirrored state: not ten independent rows
        const se = try logreg.clusteredStdErrors(gpa, d, rows, row_games, wt, 1);
        defer gpa.free(se);
        weights[k] = try arena.dupe(f64, wt);
        errors[k] = try arena.dupe(f64, se);
        loss[k] = try arena.alloc(f64, tests.items.len);
        for (loss[k], tests.items) |*l, r| {
            const b = dims.row(m, r);
            const p = logreg.sigmoid(b.dot(wt));
            l.* = analysis.logLoss(p, b.y);
            if (preds.on()) try preds.at(k).print("{s}\t{d}\twin\t{d}\t{d:.4}\n", .{
                test_ids.items[r.game], r.slot, b.y, p,
            });
        }
        try w.print("| {s} | {d:.4} |", .{ m.label, analysis.mean(loss[k]) });
        if (m.after) |a| {
            const g = analysis.pairedGain(tests.items, loss[a], loss[k]);
            try w.print(" {d:.5} ± {d:.5} vs {s} |\n", .{ g.mean, g.half_width, models[a].label });
        } else try w.writeAll(" - |\n");
    }

    for ([_]usize{ 1, 3 }) |k| {
        try w.print("\n### Style weights, {s}: win percentage points per +1 sd (log-odds x 25), " ++
            "± 95% clustered by game\n\n| feature |", .{models[k].label});
        for (Role.all) |r| try w.print(" {t} |", .{r});
        try w.writeAll("\n| --- |");
        for (Role.all) |_| try w.writeAll(" --- |");
        try w.writeAll("\n");
        for (0..n_feat) |f| {
            try w.print("| {t} |", .{@as(Feat, @fromBackingInt(@intCast(f)))});
            for (0..Role.count) |ri| {
                const i = dims.style(@intCast(ri), f);
                try w.print(" {d:.2} ± {d:.2} |", .{ 25 * weights[k][i], 25 * 1.96 * errors[k][i] });
            }
            try w.writeAll("\n");
        }
    }
    try w.writeAll("\nState weights (champion + state): win pp per 1000 (log-odds x 25), by role:\n\n" ++
        "| state |");
    for (Role.all) |r| try w.print(" {t} |", .{r});
    try w.writeAll("\n| --- |");
    for (Role.all) |_| try w.writeAll(" --- |");
    try w.writeAll("\n");
    for ([_][]const u8{ "team gold lead", "team XP lead", "lane gold lead" }, 0..) |name, i| {
        try w.print("| {s} |", .{name});
        for (0..Role.count) |ri| try w.print(" {d:.2} |", .{25 * weights[2][dims.state(@intCast(ri), i)]});
        try w.writeAll("\n");
    }
    try preds.flush();
}

const testing = std.testing;

test "zones" {
    try testing.expectEqual(Zone.blue_base, zone(500, 500));
    try testing.expectEqual(Zone.red_base, zone(14300, 14300));
    try testing.expectEqual(Zone.top, zone(1200, 9000));
    try testing.expectEqual(Zone.top, zone(6000, 13600));
    try testing.expectEqual(Zone.bot, zone(9000, 1200));
    try testing.expectEqual(Zone.bot, zone(13600, 6000));
    try testing.expectEqual(Zone.mid, zone(7400, 7200));
    // Blue jungle
    try testing.expectEqual(Zone.other, zone(3800, 7800));
}

test "style features from a timeline" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const frames = try arena.alloc(timeline.Frame, 16);
    for (frames, 0..) |*f, i| {
        f.* = .{ .t_ms = @intCast(i * minute_ms) };
        for (0..10) |p| {
            // Everyone in mid; blue top (1) in top lane except minutes 5 and 6 in mid
            f.stats[p][@backingInt(timeline.Stat.x)] = 7400;
            f.stats[p][@backingInt(timeline.Stat.y)] = 7200;
        }
        if (i != 5 and i != 6) {
            f.stats[0][@backingInt(timeline.Stat.x)] = 1200;
            f.stats[0][@backingInt(timeline.Stat.y)] = 9000;
        }
        f.stats[0][@backingInt(timeline.Stat.jungle_minions)] = @intCast(i);
    }
    const events = [_]timeline.Event{
        .{ .t_ms = 300_000, .data = .{ .champion_kill = .{ .killer = 1, .victim = 6, .x = 0, .y = 0, .bounty = 300, .shutdown = 0, .assists = &.{2} } } },
        .{ .t_ms = 310_000, .data = .{ .ward_placed = .{ .participant = 1, .ward = "CONTROL_WARD" } } },
        .{ .t_ms = 320_000, .data = .{ .ward_placed = .{ .participant = 1, .ward = "YELLOW_TRINKET" } } },
        .{ .t_ms = 330_000, .data = .{ .ward_placed = .{ .participant = 1, .ward = "TEEMO_MUSHROOM" } } },
        // After 14:00: left out
        .{ .t_ms = 850_000, .data = .{ .champion_kill = .{ .killer = 1, .victim = 6, .x = 0, .y = 0, .bounty = 300, .shutdown = 0, .assists = &.{} } } },
    };
    const t: timeline.Timeline = .{ .participants = 10, .frames = frames, .events = &events };
    var roles: [10]Role = undefined;
    for (&roles, 0..) |*r, p| r.* = @fromBackingInt(@intCast(p % 5));
    const out = features(t, roles);
    const top = out[0];
    // Frames 3..13: 11, two of them in mid
    try testing.expectApproxEqAbs(2.0 / 11.0, top[@backingInt(Feat.away)], 1e-6);
    try testing.expectEqual(1, top[@backingInt(Feat.fights)]);
    try testing.expectEqual(1, out[1][@backingInt(Feat.fights)]);
    try testing.expectEqual(1, out[5][@backingInt(Feat.fights)]);
    try testing.expectEqual(2, top[@backingInt(Feat.wards)]);
    try testing.expectEqual(1, top[@backingInt(Feat.control_wards)]);
    try testing.expectEqual(14, top[@backingInt(Feat.off_role_cs)]);
    // Blue jungler (2) in mid all along: in a lane every frame
    try testing.expectEqual(1, out[1][@backingInt(Feat.away)]);
    // Red mid (8) in mid: at home
    try testing.expectEqual(0, out[7][@backingInt(Feat.away)]);
}
