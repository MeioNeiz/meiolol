//! `meiolol-lab state-export SNAP [--every N] [--max M]`: the game state by minute for
//! the live state models (meiolol-state) and game-shape questions (meiolol-draftpath), as
//! SNAP/state/ (state.tmp renamed over it). Game order is nn-export's (rows.Data games),
//! so index gi joins SNAP/nn/ (split.u8, champ.u8, blue_win.u8) without match ids.
//!   minute.f32 [M][n][C]  minute-major: minute block mi is minutes[mi]'s rows for every
//!                         game, NaN rows when the game is not going (objectives.stateAt's
//!                         rule: frame m exists, is not the end frame, t_ms >= m:00)
//!   game.f32 [n][G]       per game: timeline, length, result, firsts, shape targets
//!   match_id.txt          one line per game (a check on the join)
//!   meta.json             minutes, column names in order, n, snapshot
//! Minute columns: going, t_ms; per seat s0..s9 (side * 5 + role, as champ.u8) the
//! livestate.Seat fields; obj_<objectives.Feat> from objectives.stateBefore (blue minus
//! red, so winchance's state is exactly reproducible); then per team b_/r_ the
//! livestate.Team fields, counted for the team that took it. Values come from
//! livestate.Walker, the code Your games' win chance (statemodel.zig) runs.
//! Readers go by column name: append fields to the enums, never reorder

const std = @import("std");
const store = @import("store");
const timeline = @import("../riot/timeline.zig");
const objectives = @import("../objectives.zig");
const livestate = @import("../livestate.zig");
const stats = @import("../stats.zig");
const rows = @import("rows.zig");
const protocol = @import("protocol.zig");
const statemodel = @import("../statemodel.zig");

const Io = std.Io;
const Allocator = std.mem.Allocator;
const Feat = objectives.Feat;
const nan = std.math.nan(f32);

pub const usage =
    \\  state-export SNAP [--every N] [--max M]
    \\                                  game state by minute (0, N, .., M; default 5, 40)
    \\                                  per seat and team, firsts, shape targets: SNAP/state/
    \\                                  (lab/stateexport.zig)
    \\  state-export SNAP --check MODEL CHECK
    \\                                  statemodel.zig's win chance with MODEL (stateship.py's
    \\                                  state-model.bin) from the timelines against CHECK
    \\                                  (its state-check.tsv): max |diff|, exit 1 over 1e-4
    \\
;

pub const dir_name = "state";

pub const Options = struct {
    every: u8 = 5,
    max: u8 = 40,
};

pub const Seat = livestate.Seat;
pub const Team = livestate.Team;

pub const GameCol = enum {
    has_timeline,
    duration_s,
    blue_win,
    first_blood_team,
    first_blood_min,
    first_tower_team,
    first_tower_min,
    first_dragon_team,
    first_dragon_min,
    first_grubs_team,
    first_grubs_min,
    first_herald_team,
    first_herald_min,
    first_baron_team,
    first_baron_min,
    first_inhib_team,
    first_inhib_min,
    lead_top_10,
    lead_jungle_10,
    lead_middle_10,
    lead_bottom_10,
    lead_utility_10,
    lead_top_15,
    lead_jungle_15,
    lead_middle_15,
    lead_bottom_15,
    lead_utility_15,
    lead_top_20,
    lead_jungle_20,
    lead_middle_20,
    lead_bottom_20,
    lead_utility_20,
    /// Champion kills by both teams per minute of game
    kills_per_min,
};

const n_seat = livestate.n_seat;
const n_team = livestate.n_team;
const n_feat = @typeInfo(Feat).@"enum".field_names.len;
const seat_base = 2;
const obj_base = seat_base + 10 * n_seat;
const team_base = obj_base + n_feat;
pub const n_col = team_base + 2 * n_team;
pub const n_game_col = @typeInfo(GameCol).@"enum".field_names.len;

fn seatCol(slot: usize, c: Seat) usize {
    return seat_base + slot * n_seat + @backingInt(c);
}
fn teamCol(side: usize, c: Team) usize {
    return team_base + side * n_team + @backingInt(c);
}
fn objCol(f: Feat) usize {
    return obj_base + @backingInt(f);
}

const minute_ms = livestate.minute_ms;

pub fn minuteList(gpa: Allocator, o: Options) ![]u8 {
    if (o.every == 0) return error.BadEvery;
    var list: std.ArrayList(u8) = .empty;
    errdefer list.deinit(gpa);
    var m: u16 = 0;
    while (m <= o.max) : (m += o.every) try list.append(gpa, @intCast(m));
    return list.toOwnedSlice(gpa);
}

const sideOf = livestate.sideOf;
const ownerSide = livestate.ownerSide;

/// One game's timeline into its minute rows and game columns
pub const Game = struct {
    t: timeline.Timeline,
    /// Participant id - 1 -> seat (side * 5 + role)
    seat_of: [10]u8,
    patch: u32,
    legendaries: *const std.AutoHashMapUnmanaged(u64, void),
};

const Legendaries = struct {
    set: *const std.AutoHashMapUnmanaged(u64, void),
    patch: u32,

    fn items(l: *const Legendaries) livestate.Items {
        return .{ .ctx = l, .legendary = struct {
            fn f(ctx: *const anyopaque, item: u32) bool {
                const self: *const Legendaries = @ptrCast(@alignCast(ctx));
                return self.set.contains(rows.legendaryKey(self.patch, item));
            }
        }.f };
    }
};

fn write(m: livestate.Minute, out: []f32) void {
    out[0] = 1;
    out[1] = @floatFromInt(m.t_ms);
    for (0..10) |s| {
        for (0..n_seat) |c| out[seat_base + s * n_seat + c] = m.seat[s][c];
    }
    for (m.obj, 0..) |x, f| out[obj_base + f] = x;
    for (0..2) |side| @memcpy(out[team_base + side * n_team ..][0..n_team], &m.team[side]);
}

const frameAt = livestate.frameAt;

/// Fills `out[mi]` (C floats each, NaN on entry) for each of `minutes` the game is going,
/// and the timeline's game columns
pub fn fill(g: Game, minutes: []const u8, out: [][]f32, game_out: *[n_game_col]f32) void {
    const legs: Legendaries = .{ .set = g.legendaries, .patch = g.patch };
    var walk: livestate.Walker = .init(g.t, g.seat_of, legs.items());
    for (minutes, out) |m, row| write(walk.at(m) orelse break, row);

    game_out[@backingInt(GameCol.has_timeline)] = 1;
    const First = struct { team: GameCol, min: GameCol };
    const set = struct {
        fn f(o: *[n_game_col]f32, c: First, side: ?usize, t_ms: i64) void {
            const s = side orelse return;
            if (!std.math.isNan(o[@backingInt(c.min)])) return;
            o[@backingInt(c.team)] = if (s == 0) 1 else -1;
            o[@backingInt(c.min)] = @as(f32, @floatFromInt(t_ms)) / minute_ms;
        }
    }.f;
    const firsts = [_]First{
        .{ .team = .first_blood_team, .min = .first_blood_min },
        .{ .team = .first_tower_team, .min = .first_tower_min },
        .{ .team = .first_dragon_team, .min = .first_dragon_min },
        .{ .team = .first_grubs_team, .min = .first_grubs_min },
        .{ .team = .first_herald_team, .min = .first_herald_min },
        .{ .team = .first_baron_team, .min = .first_baron_min },
        .{ .team = .first_inhib_team, .min = .first_inhib_min },
    };
    for (firsts) |f| {
        game_out[@backingInt(f.team)] = 0;
        game_out[@backingInt(f.min)] = nan;
    }
    var kills: f32 = 0;
    for (g.t.events) |e| switch (e.data) {
        .champion_kill => |k| {
            kills += 1;
            set(game_out, firsts[0], sideOf(k.killer) orelse if (sideOf(k.victim)) |vs| 1 - vs else null, e.t_ms);
        },
        .building_kill => |b| {
            const taker = if (ownerSide(b.team)) |o| 1 - o else null;
            if (std.mem.eql(u8, b.building, "TOWER_BUILDING")) set(game_out, firsts[1], taker, e.t_ms);
            if (std.mem.eql(u8, b.building, "INHIBITOR_BUILDING")) set(game_out, firsts[6], taker, e.t_ms);
        },
        .elite_monster => |m| {
            const side = ownerSide(m.team);
            if (std.mem.eql(u8, m.monster, "DRAGON")) set(game_out, firsts[2], side, e.t_ms);
            if (std.mem.eql(u8, m.monster, "HORDE")) set(game_out, firsts[3], side, e.t_ms);
            if (std.mem.eql(u8, m.monster, "RIFTHERALD")) set(game_out, firsts[4], side, e.t_ms);
            if (std.mem.eql(u8, m.monster, "BARON_NASHOR")) set(game_out, firsts[5], side, e.t_ms);
        },
        else => {},
    };
    const dur = game_out[@backingInt(GameCol.duration_s)];
    game_out[@backingInt(GameCol.kills_per_min)] = if (dur > 0) kills / (dur / 60) else nan;

    for ([_]u8{ 10, 15, 20 }, 0..) |m, mi| {
        const frame = frameAt(g.t, m) orelse continue;
        var lead: [5]f32 = @splat(0);
        for (0..10) |i| {
            const s = g.seat_of[i];
            const gold: f32 = @floatFromInt(frame.get(@intCast(i + 1), .total_gold));
            lead[s % 5] += if (s < 5) gold else -gold;
        }
        for (lead, 0..) |l, role| game_out[@backingInt(GameCol.lead_top_10) + mi * 5 + role] = l;
    }
}

/// Rows whose own team counts disagree with objectives.stateBefore's blue-minus-red
/// (towers, dragons, grubs, herald), a check that the two read events alike
pub fn mismatch(row: []const f32) bool {
    if (std.math.isNan(row[0])) return false;
    const T = struct {
        fn diff(r: []const f32, cs: []const Team) f32 {
            var d: f32 = 0;
            for (cs) |c| d += r[teamCol(0, c)] - r[teamCol(1, c)];
            return d;
        }
    };
    const towers = T.diff(row, &.{
        .tower_top_outer, .tower_top_inner, .tower_top_base,  .tower_mid_outer, .tower_mid_inner,
        .tower_mid_base,  .tower_bot_outer, .tower_bot_inner, .tower_bot_base,  .tower_nexus,
    });
    const dragons = T.diff(row, &.{ .infernal, .ocean, .mountain, .cloud, .hextech, .chemtech });
    return towers != row[objCol(.towers)] or dragons != row[objCol(.dragons)] or
        T.diff(row, &.{.grubs}) != row[objCol(.grubs)] or T.diff(row, &.{.heralds}) != row[objCol(.herald)];
}

pub const Summary = struct {
    games: usize = 0,
    timelines: usize = 0,
    /// Game-minute rows going, per minute
    going: []usize = &.{},
    mismatches: usize = 0,
    /// Seats whose timeline participant had no lab row (game skipped)
    unmapped: usize = 0,
    minutes: []u8 = &.{},
};

pub fn main(gpa: Allocator, io: Io, argv: []const []const u8) !u8 {
    if (argv.len < 1) {
        std.debug.print("usage:\n{s}", .{usage});
        return 2;
    }
    if (argv.len == 4 and std.mem.eql(u8, argv[1], "--check")) return check(gpa, io, argv[0], argv[2], argv[3]);
    var o: Options = .{};
    var i: usize = 1;
    while (i + 1 < argv.len) : (i += 2) {
        if (std.mem.eql(u8, argv[i], "--every")) {
            o.every = try std.fmt.parseInt(u8, argv[i + 1], 10);
        } else if (std.mem.eql(u8, argv[i], "--max")) {
            o.max = try std.fmt.parseInt(u8, argv[i + 1], 10);
        } else {
            std.debug.print("state-export: unknown {s}\nusage:\n{s}", .{ argv[i], usage });
            return 2;
        }
    }
    const s = try run(gpa, io, argv[0], o);
    defer gpa.free(s.going);
    defer gpa.free(s.minutes);
    std.log.info("state-export: {d} games, {d} with a 10-player timeline, {d} unmapped, {d} rows " ++
        "disagreeing with objectives.stateBefore; {d} columns -> {s}/{s}", .{
        s.games, s.timelines, s.unmapped, s.mismatches, n_col, argv[0], dir_name,
    });
    for (s.minutes, s.going) |m, n| std.log.info("  minute {d}: {d} games going", .{ m, n });
    return 0;
}

pub fn run(gpa: Allocator, io: Io, snap: []const u8, o: Options) !Summary {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const minutes = try minuteList(gpa, o);
    errdefer gpa.free(minutes);

    var legendaries = try rows.loadLegendaries(gpa, io, snap);
    defer legendaries.deinit(gpa);
    var data = try rows.load(gpa, snap, &legendaries);
    defer data.deinit();
    const n = data.games.len;
    var sum: Summary = .{ .games = n, .minutes = minutes };
    sum.going = try gpa.alloc(usize, minutes.len);
    @memset(sum.going, 0);
    errdefer gpa.free(sum.going);

    var index: std.AutoHashMapUnmanaged(u64, u32) = .empty;
    defer index.deinit(gpa);
    for (data.games, 0..) |g, gi| try index.put(gpa, stats.matchKey(g.match_id), @intCast(gi));
    const no_seat = 255;
    const seat_of = try arena.alloc([10]u8, n);
    @memset(seat_of, @splat(no_seat));
    for (data.rows) |r| if (r.slot < 10) {
        seat_of[r.game][r.slot] = @as(u8, r.side) * 5 + @backingInt(r.role);
    };

    const minute_buf = try gpa.alloc(f32, minutes.len * n * n_col);
    defer gpa.free(minute_buf);
    @memset(minute_buf, nan);
    const game_buf = try gpa.alloc([n_game_col]f32, n);
    defer gpa.free(game_buf);
    for (game_buf, data.games) |*row, g| {
        row.* = @splat(nan);
        row[@backingInt(GameCol.has_timeline)] = 0;
        row[@backingInt(GameCol.duration_s)] = @floatFromInt(g.duration_s);
        row[@backingInt(GameCol.blue_win)] = @floatFromInt(@intFromBool(g.winner == 0));
    }

    {
        const db = try store.sqlite.Db.openReadOnly(try std.fs.path.joinZ(arena, &.{ snap, "timeline.db" }));
        defer db.close();
        var q = try db.prepare("SELECT match_id, data FROM timelines");
        defer q.deinit();
        try q.bind(.{});
        var tl_arena: std.heap.ArenaAllocator = .init(gpa);
        defer tl_arena.deinit();
        const out = try arena.alloc([]f32, minutes.len);
        while (try q.step()) {
            const gi = index.get(stats.matchKey(q.bytes(0))) orelse continue;
            _ = tl_arena.reset(.retain_capacity);
            const ta = tl_arena.allocator();
            const raw = try store.raw.decompress(ta, q.bytes(1));
            const t = timeline.decode(ta, raw) catch continue;
            if (t.participants != 10 or t.frames.len == 0) continue;
            if (std.mem.findScalar(u8, &seat_of[gi], no_seat) != null) {
                sum.unmapped += 1;
                continue;
            }
            sum.timelines += 1;
            for (out, 0..) |*row, mi| row.* = minute_buf[(mi * n + gi) * n_col ..][0..n_col];
            fill(.{ .t = t, .seat_of = seat_of[gi], .patch = data.games[gi].patch, .legendaries = &legendaries }, minutes, out, &game_buf[gi]);
            for (out, sum.going) |row, *c| {
                if (std.math.isNan(row[0])) continue;
                c.* += 1;
                sum.mismatches += @intFromBool(mismatch(row));
            }
        }
    }

    comptime std.debug.assert(@import("builtin").cpu.arch.endian() == .little);
    const cwd = Io.Dir.cwd();
    const tmp_path = try arena.print("{s}/{s}.tmp", .{ snap, dir_name });
    cwd.deleteTree(io, tmp_path) catch {};
    try cwd.createDirPath(io, tmp_path);
    errdefer cwd.deleteTree(io, tmp_path) catch {};
    {
        var dir = try cwd.openDir(io, tmp_path, .{});
        defer dir.close(io);
        try dir.writeFile(io, .{ .sub_path = "minute.f32", .data = std.mem.sliceAsBytes(minute_buf) });
        try dir.writeFile(io, .{ .sub_path = "game.f32", .data = std.mem.sliceAsBytes(game_buf) });
        var text: Io.Writer.Allocating = .init(gpa);
        defer text.deinit();
        for (data.games) |g| {
            try text.writer.writeAll(g.match_id);
            try text.writer.writeByte('\n');
        }
        try dir.writeFile(io, .{ .sub_path = "match_id.txt", .data = text.written() });
        text.clearRetainingCapacity();
        try meta(&text.writer, snap, n, minutes);
        try dir.writeFile(io, .{ .sub_path = "meta.json", .data = text.written() });
    }
    const path = try std.fs.path.join(arena, &.{ snap, dir_name });
    cwd.deleteTree(io, path) catch {};
    try cwd.rename(tmp_path, cwd, path, io);
    return sum;
}

/// Largest difference allowed between statemodel.zig and the Python fit's chances
const check_tolerance = 1e-4;

/// statemodel.chances from SNAP's timelines with the model file at `model_path`, against
/// stateship.py's chances by minute in `check_path` (match_id, minute, p)
fn check(gpa: Allocator, io: Io, snap: []const u8, model_path: []const u8, check_path: []const u8) !u8 {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const cwd = Io.Dir.cwd();
    const model = try statemodel.Model.parse(try cwd.readFileAlloc(io, model_path, arena, .limited(64 << 20)));
    std.log.info("model {s}: {s} ({s}), {d} games, {d} champion-role terms", .{
        model_path, model.snapshot, model.run, model.training_games, model.n_terms,
    });

    const Want = struct { minute: u8, p: f64 };
    var want: std.StringArrayHashMapUnmanaged(std.ArrayList(Want)) = .empty;
    var lines = std.mem.tokenizeScalar(u8, try cwd.readFileAlloc(io, check_path, arena, .limited(256 << 20)), '\n');
    _ = lines.next();
    while (lines.next()) |line| {
        var f = std.mem.tokenizeScalar(u8, line, '\t');
        const id = f.next() orelse return error.BadCheckFile;
        const minute = try std.fmt.parseInt(u8, f.next() orelse return error.BadCheckFile, 10);
        const p = try std.fmt.parseFloat(f64, f.next() orelse return error.BadCheckFile);
        const e = try want.getOrPut(arena, id);
        if (!e.found_existing) e.value_ptr.* = .empty;
        try e.value_ptr.append(arena, .{ .minute = minute, .p = p });
    }

    var legendaries = try rows.loadLegendaries(gpa, io, snap);
    defer legendaries.deinit(gpa);
    var data = try rows.load(gpa, snap, &legendaries);
    defer data.deinit();
    var index: std.AutoHashMapUnmanaged(u64, u32) = .empty;
    defer index.deinit(gpa);
    for (data.games, 0..) |g, gi| try index.put(gpa, stats.matchKey(g.match_id), @intCast(gi));
    const seat_of = try arena.alloc([10]u8, data.games.len);
    for (data.rows) |r| if (r.slot < 10) {
        seat_of[r.game][r.slot] = @as(u8, r.side) * 5 + @backingInt(r.role);
    };
    const platforms = protocol.platformIds();

    const db = try store.sqlite.Db.openReadOnly(try std.fs.path.joinZ(arena, &.{ snap, "timeline.db" }));
    defer db.close();
    var q = try db.prepare("SELECT data FROM timelines WHERE match_id = ?");
    defer q.deinit();
    var worst: f64 = 0;
    var worst_at: struct { id: []const u8 = "", minute: u8 = 0 } = .{};
    var games: usize = 0;
    var minutes: usize = 0;
    var tl_arena: std.heap.ArenaAllocator = .init(gpa);
    defer tl_arena.deinit();
    var it = want.iterator();
    while (it.next()) |e| {
        _ = tl_arena.reset(.retain_capacity);
        const ta = tl_arena.allocator();
        const gi = index.get(stats.matchKey(e.key_ptr.*)) orelse return error.CheckGameNotInSnapshot;
        const g = data.games[gi];
        q.reset();
        try q.bind(.{e.key_ptr.*});
        if (!try q.step()) return error.CheckGameHasNoTimeline;
        const t = try timeline.decode(ta, try store.raw.decompress(ta, q.bytes(0)));
        var champions: [10]u32 = undefined;
        for (0..10) |s| champions[s] = g.teams[s / 5][s % 5];
        const legs: Legendaries = .{ .set = &legendaries, .patch = g.patch };
        const got = try statemodel.chances(ta, model, .{
            .t = t,
            .seat_of = seat_of[gi],
            .champions = champions,
            .platform = platforms[g.platform],
            .items = legs.items(),
        });
        games += 1;
        for (e.value_ptr.items) |w| {
            if (w.minute >= got.len) return error.CheckMinuteNotGoing;
            minutes += 1;
            const d = @abs(got[w.minute] - w.p);
            if (d > worst) {
                worst = d;
                worst_at = .{ .id = e.key_ptr.*, .minute = w.minute };
            }
        }
    }
    std.log.info("state-export --check: statemodel.zig vs the Python fit on {d} games, {d} game-minutes: " ++
        "max |diff| {e:.2} ({s} at {d}:00), tolerance {e:.0}", .{ games, minutes, worst, worst_at.id, worst_at.minute, check_tolerance });
    return if (worst <= check_tolerance) 0 else 1;
}

fn meta(w: *Io.Writer, snap: []const u8, n: usize, minutes: []const u8) !void {
    try w.print("{{\"format\":\"meiolol-state\",\"version\":1,\"snapshot\":\"{s}\",\"n\":{d},\"c\":{d},\"g\":{d},\n", .{
        std.fs.path.basename(snap), n, n_col, n_game_col,
    });
    try w.writeAll("\"files\":{\"minute.f32\":[\"minutes\",\"n\",\"c\"],\"game.f32\":[\"n\",\"g\"],\"match_id.txt\":[\"n\",\"line\"]},\n");
    try w.writeAll("\"seats\":\"side * 5 + role; side 0 blue; roles top, jungle, middle, bottom, utility\",\n");
    try w.writeAll("\"minutes\":[");
    for (minutes, 0..) |m, i| try w.print("{s}{d}", .{ if (i == 0) "" else ",", m });
    try w.writeAll("],\n\"minute_columns\":[\"going\",\"t_ms\"");
    for (0..10) |s| inline for (@typeInfo(Seat).@"enum".field_names) |f| try w.print(",\"s{d}_{s}\"", .{ s, f });
    inline for (@typeInfo(Feat).@"enum".field_names) |f| try w.print(",\"obj_{s}\"", .{f});
    for ([_][]const u8{ "b", "r" }) |side| inline for (@typeInfo(Team).@"enum".field_names) |f| try w.print(",\"{s}_{s}\"", .{ side, f });
    try w.writeAll("],\n\"game_columns\":[");
    inline for (@typeInfo(GameCol).@"enum".field_names, 0..) |f, i| try w.print("{s}\"{s}\"", .{ if (i == 0) "" else ",", f });
    try w.writeAll("]}\n");
}

const testing = std.testing;

test "fill: seats, team objectives, buffs and timers, firsts; agrees with stateBefore" {
    const E = timeline.Event;
    var frames: [6]timeline.Frame = undefined;
    for (&frames, 0..) |*f, m| {
        f.* = .{ .t_ms = @as(i64, @intCast(m)) * minute_ms + 30 };
        for (1..11) |p| {
            const pid: u8 = @intCast(p);
            f.stats[pid - 1][@backingInt(timeline.Stat.total_gold)] = @intCast(500 + 100 * m * p);
            f.stats[pid - 1][@backingInt(timeline.Stat.current_gold)] = 50;
            f.stats[pid - 1][@backingInt(timeline.Stat.level)] = @intCast(1 + m);
        }
    }
    const events = [_]E{
        .{ .t_ms = 61_000, .data = .{ .level_up = .{ .participant = 7, .level = 6 } } },
        .{ .t_ms = 100_000, .data = .{ .item_purchased = .{ .participant = 2, .item = 3031 } } },
        .{ .t_ms = 101_000, .data = .{ .item_purchased = .{ .participant = 3, .item = 3031 } } },
        .{ .t_ms = 102_000, .data = .{ .item_undo = .{ .participant = 3, .before = 3031, .after = 0, .gold = 3400 } } },
        .{ .t_ms = 110_000, .data = .{ .ward_placed = .{ .participant = 5, .ward = "CONTROL_WARD" } } },
        .{ .t_ms = 111_000, .data = .{ .ward_placed = .{ .participant = 5, .ward = "UNDEFINED" } } },
        .{ .t_ms = 115_000, .data = .{ .champion_kill = .{ .killer = 2, .victim = 7, .x = 0, .y = 0, .bounty = 400, .shutdown = 0, .assists = &.{3} } } },
        .{ .t_ms = 130_000, .data = .{ .building_kill = .{ .killer = 8, .team = 100, .building = "TOWER_BUILDING", .lane = "MID_LANE", .tower = "OUTER_TURRET", .assists = &.{} } } },
        .{ .t_ms = 140_000, .data = .{ .turret_plate = .{ .killer = 8, .team = 100, .lane = "MID_LANE" } } },
        .{ .t_ms = 150_000, .data = .{ .elite_monster = .{ .killer = 1, .team = 100, .monster = "DRAGON", .subtype = "WATER_DRAGON", .assists = &.{} } } },
        .{ .t_ms = 160_000, .data = .{ .elite_monster = .{ .killer = 6, .team = 200, .monster = "BARON_NASHOR", .subtype = "", .assists = &.{} } } },
        .{ .t_ms = 170_000, .data = .{ .building_kill = .{ .killer = 1, .team = 200, .building = "INHIBITOR_BUILDING", .lane = "BOT_LANE", .tower = "", .assists = &.{} } } },
        .{ .t_ms = 175_000, .data = .{ .dragon_soul = .{ .team = 0, .name = "Ocean" } } },
    };
    const t: timeline.Timeline = .{ .participants = 10, .frames = &frames, .events = &events };
    var legs: std.AutoHashMapUnmanaged(u64, void) = .empty;
    defer legs.deinit(testing.allocator);
    try legs.put(testing.allocator, rows.legendaryKey(7, 3031), {});
    // Participant ids 1..10 in reverse role order on each side
    const seat_of = [10]u8{ 4, 3, 2, 1, 0, 9, 8, 7, 6, 5 };
    const minutes = [_]u8{ 0, 2, 3, 5 };
    var buf: [minutes.len][n_col]f32 = @splat(@splat(nan));
    var out: [minutes.len][]f32 = undefined;
    for (&out, &buf) |*o, *b| o.* = b;
    var game: [n_game_col]f32 = @splat(nan);
    game[@backingInt(GameCol.duration_s)] = 300;
    fill(.{ .t = t, .seat_of = seat_of, .patch = 7, .legendaries = &legs }, &minutes, &out, &game);

    // Minute 5 is the end frame: not going
    try testing.expect(std.math.isNan(buf[3][0]));
    const r = buf[2];
    try testing.expectEqual(@as(f32, 1), r[0]);
    try testing.expectEqual(@as(f32, 180_030), r[1]);
    // Participant 2 = blue seat 3 (bottom): a kill and a legendary; 3 (seat 2) an undone one
    try testing.expectEqual(@as(f32, 1), r[seatCol(3, .kills)]);
    try testing.expectEqual(@as(f32, 1), r[seatCol(3, .legendaries)]);
    try testing.expectEqual(@as(f32, 0), r[seatCol(2, .legendaries)]);
    try testing.expectEqual(@as(f32, 1), r[seatCol(2, .assists)]);
    try testing.expectEqual(@as(f32, 500 + 100 * 3 * 2), r[seatCol(3, .gold)]);
    try testing.expectEqual(@as(f32, 50), r[seatCol(3, .unspent)]);
    try testing.expectEqual(@as(f32, 1), r[seatCol(0, .wards)]);
    try testing.expectEqual(@as(f32, 1), r[seatCol(0, .ctrl_wards)]);
    // Participant 7 = red seat 8 died at 1:55 at level 6 (16 s): alive by 3:00, 11 s left at 2:00
    try testing.expectEqual(@as(f32, 1), r[seatCol(8, .deaths)]);
    try testing.expectEqual(@as(f32, 0), r[seatCol(8, .respawn_s)]);
    try testing.expectApproxEqAbs(@as(f32, 131 - 120.03), buf[1][seatCol(8, .respawn_s)], 1e-3);
    try testing.expectEqual(@as(f32, 1), r[teamCol(0, .kills)]);
    // Red took blue's mid outer and a plate; blue an ocean dragon and red's bot inhibitor
    try testing.expectEqual(@as(f32, 1), r[teamCol(1, .tower_mid_outer)]);
    try testing.expectEqual(@as(f32, 1), r[teamCol(1, .plates)]);
    try testing.expectEqual(@as(f32, 1), r[teamCol(0, .ocean)]);
    try testing.expectEqual(@as(f32, 1), r[teamCol(0, .inhibs)]);
    try testing.expectApproxEqAbs(@as(f32, 300 - 10.03), r[teamCol(0, .inhib_bot_s)], 1e-3);
    try testing.expectApproxEqAbs(@as(f32, 180 - 20.03), r[teamCol(1, .baron_s)], 1e-3);
    try testing.expectEqual(@as(f32, 0), r[teamCol(0, .soul)]);
    try testing.expect(!mismatch(&r));
    try testing.expectEqual(@as(f32, -1), r[objCol(.towers)]);
    try testing.expectEqual(@as(f32, -1), r[objCol(.baron)]);

    try testing.expectEqual(@as(f32, 1), game[@backingInt(GameCol.first_blood_team)]);
    try testing.expectEqual(@as(f32, 115.0 / 60.0), game[@backingInt(GameCol.first_blood_min)]);
    try testing.expectEqual(@as(f32, -1), game[@backingInt(GameCol.first_tower_team)]);
    try testing.expectEqual(@as(f32, 0), game[@backingInt(GameCol.first_herald_team)]);
    try testing.expect(std.math.isNan(game[@backingInt(GameCol.first_herald_min)]));
    try testing.expectEqual(@as(f32, 0.2), game[@backingInt(GameCol.kills_per_min)]);
    // Frame 10 doesn't exist: no leads
    try testing.expect(std.math.isNan(game[@backingInt(GameCol.lead_top_10)]));
}
