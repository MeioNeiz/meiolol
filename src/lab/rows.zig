//! One row per player per game from an analysis snapshot, with the shared outcomes
//! (docs/model.md "Shared protocol"). Games are stats.scan's (ranked solo, no remakes,
//! roles complete); test games are protocol's split

const std = @import("std");
const store = @import("store");
const core = @import("core");
const stats = @import("../stats.zig");
const eval = @import("../eval.zig");
const timeline = @import("../riot/timeline.zig");
const protocol = @import("protocol.zig");
const pack = @import("pack.zig");

pub const Outcome = enum { win, gold14, lanediff14, cs10, deaths15, first_item };
pub const outcome_count = @typeInfo(Outcome).@"enum".field_names.len;

pub const Game = struct {
    match_id: []const u8,
    start: i64,
    patch: u32,
    platform: u8,
    is_test: bool,
    /// Champion ids by side (0 blue) and role, as stats.Row
    teams: [2][5]u32,
    winner: u1,
    /// Timeline reaches 15:00 (protocol.reached15Timeline)
    timeline15: bool = false,
    /// Game length (matches.duration_s)
    duration_s: u32 = 0,
};

pub const Row = struct {
    game: u32,
    slot: u8,
    side: u1,
    role: core.Role,
    champion: u32,
    /// Higher is better: 0 Iron IV .. 39 Challenger I; null unranked
    rank: ?u8,
    /// Per participant; win as 0/1. NaN when unknown (no timeline, no completed item)
    y: [outcome_count]f32,
    /// This player's games in the data that ended before this one started (fillExperience):
    /// on this champion, then on any; wins of each. 0 for a missing PUUID
    champ_games: u16 = 0,
    champ_wins: u16 = 0,
    games_before: u16 = 0,
    wins_before: u16 = 0,
    /// Recent form over the same games, 0 when none: (kills + assists) / max(deaths, 1)
    /// over games_before; lane gold diff at 14 and deaths before 15 over the perf_games
    /// of them that reached 15:00
    kda_before: f32 = 0,
    perf_games: u16 = 0,
    lanediff14_before: f32 = 0,
    deaths15_before: f32 = 0,
};

pub const Data = struct {
    arena: std.heap.ArenaAllocator,
    games: []Game,
    rows: []Row,

    pub fn deinit(d: *Data) void {
        d.arena.deinit();
    }
};

const GameList = struct {
    gpa: std.mem.Allocator,
    items: std.ArrayList(stats.Row) = .empty,

    pub fn add(l: *GameList, g: stats.Row) !void {
        try l.items.append(l.gpa, g);
    }
};

/// From SNAP/pack/ when it matches the snapshot (lab/pack.zig), else from SQLite.
/// legendaries: (patch key, item id) of completed items, for first_item; may be empty
pub fn load(
    gpa: std.mem.Allocator,
    snap: []const u8,
    legendaries: *const std.AutoHashMapUnmanaged(u64, void),
) !Data {
    // Plain blocking reads, on the global Io so every caller gets the pack unchanged
    const io = std.Io.Threaded.global_single_threaded.io();
    if (try pack.read(gpa, io, snap, legendaries)) |d| return d;
    return loadSql(gpa, snap, legendaries);
}

pub fn loadSql(
    gpa: std.mem.Allocator,
    snap: []const u8,
    legendaries: *const std.AutoHashMapUnmanaged(u64, void),
) !Data {
    var data: Data = .{ .arena = .init(gpa), .games = &.{}, .rows = &.{} };
    errdefer data.deinit();
    const arena = data.arena.allocator();

    const db = try store.schema.openReadOnly(gpa, snap);
    defer db.close();
    const ids = protocol.platformIds();
    const patches = try stats.patches(arena, db, &ids);
    var list: GameList = .{ .gpa = gpa };
    defer list.items.deinit(gpa);
    _ = try stats.scan(gpa, db, patches, &ids, 0, &list);
    var parts = try eval.split(gpa, list.items.items, &ids, .{ .test_platform = protocol.test_platform });
    defer parts.deinit(gpa);

    // Scan order is by start; index by match key for the participant pass
    var index: std.AutoHashMapUnmanaged(u64, u32) = .empty;
    defer index.deinit(gpa);
    var games: std.ArrayList(Game) = .empty;
    for ([_][]const stats.Row{ parts.train, parts.tests }, [_]bool{ false, true }) |set, is_test| {
        for (set) |g| {
            try index.put(gpa, g.id, @intCast(games.items.len));
            try games.append(arena, .{
                .match_id = "",
                .start = g.start,
                .patch = g.patch,
                .platform = g.platform,
                .is_test = is_test,
                .teams = g.teams,
                .winner = g.winner,
            });
        }
    }

    {
        var q = try db.prepare("SELECT match_id, duration_s FROM matches");
        defer q.deinit();
        try q.bind(.{});
        while (try q.step()) {
            const gi = index.get(stats.matchKey(q.bytes(0))) orelse continue;
            games.items[gi].duration_s = @intCast(q.int(1));
        }
    }

    var rows: std.ArrayList(Row) = .empty;
    var players: std.ArrayList(u32) = .empty;
    defer players.deinit(gpa);
    var kdas: std.ArrayList(f32) = .empty;
    defer kdas.deinit(gpa);
    var player_ids: std.AutoHashMapUnmanaged(u64, u32) = .empty;
    defer player_ids.deinit(gpa);
    var by_game: std.AutoHashMapUnmanaged(u32, [10]u32) = .empty;
    defer by_game.deinit(gpa);
    {
        var q = try db.prepare(
            \\SELECT match_id, slot, team_id, position, champion_id, tier, division, gold14, puuid,
            \\    kills, deaths, assists
            \\FROM participants ORDER BY match_id, slot
        );
        defer q.deinit();
        try q.bind(.{});
        while (try q.step()) {
            const gi = index.get(stats.matchKey(q.bytes(0))) orelse continue;
            const g = &games.items[gi];
            if (g.match_id.len == 0) g.match_id = try arena.dupe(u8, q.bytes(0));
            const role = core.Role.fromLcu(q.bytes(3)) orelse continue;
            const side: u1 = if (q.int(2) == 100) 0 else 1;
            const slot: u8 = @intCast(q.int(1));
            const packed_rank = store.schema.packRank(q.bytes(5), q.bytes(6));
            var y: [outcome_count]f32 = @splat(std.math.nan(f32));
            y[@backingInt(Outcome.win)] = @floatFromInt(@intFromBool(side == g.winner));
            if (q.optInt(7)) |gold| y[@backingInt(Outcome.gold14)] = @floatFromInt(gold);
            const e = try by_game.getOrPut(gpa, gi);
            if (!e.found_existing) e.value_ptr.* = @splat(std.math.maxInt(u32));
            if (slot < 10) e.value_ptr[slot] = @intCast(rows.items.len);
            const player = if (q.isNull(8)) no_player else blk: {
                const p = try player_ids.getOrPut(gpa, std.hash.Wyhash.hash(0, q.bytes(8)));
                if (!p.found_existing) p.value_ptr.* = player_ids.count() - 1;
                break :blk p.value_ptr.*;
            };
            try players.append(gpa, player);
            const deaths: f32 = @floatFromInt(@max(q.optInt(10) orelse 0, 1));
            try kdas.append(gpa, @as(f32, @floatFromInt((q.optInt(9) orelse 0) + (q.optInt(11) orelse 0))) / deaths);
            try rows.append(arena, .{
                .game = gi,
                .slot = slot,
                .side = side,
                .role = role,
                .champion = @intCast(q.int(4)),
                .rank = if (packed_rank) |r| @intCast(39 - r) else null,
                .y = y,
            });
        }
    }

    // Timeline outcomes: frame t is minute t (frame 0 at the start)
    var tl_arena: std.heap.ArenaAllocator = .init(gpa);
    defer tl_arena.deinit();
    {
        var q = try db.prepare("SELECT match_id, data FROM timeline.timelines");
        defer q.deinit();
        try q.bind(.{});
        while (try q.step()) {
            const gi = index.get(stats.matchKey(q.bytes(0))) orelse continue;
            const slots = by_game.get(gi) orelse continue;
            _ = tl_arena.reset(.retain_capacity);
            const ta = tl_arena.allocator();
            const raw = try store.raw.decompress(ta, q.bytes(1));
            const t = timeline.decode(ta, raw) catch continue;
            if (!protocol.reached15Timeline(t)) continue;
            games.items[gi].timeline15 = true;
            fillTimeline(rows.items, slots, games.items[gi].patch, t, legendaries);
        }
    }

    // Lane gold diff: same role, other side
    for (games.items, 0..) |g, gi| {
        if (!g.timeline15) continue;
        const slots = by_game.get(@intCast(gi)) orelse continue;
        for (slots) |ri| {
            if (ri == std.math.maxInt(u32)) continue;
            const r = &rows.items[ri];
            for (slots) |oi| {
                if (oi == std.math.maxInt(u32)) continue;
                const o = rows.items[oi];
                if (o.side != r.side and o.role == r.role) {
                    const k = @backingInt(Outcome.lanediff14);
                    r.y[k] = r.y[@backingInt(Outcome.gold14)] - o.y[@backingInt(Outcome.gold14)];
                }
            }
        }
    }
    // participants.gold14 exists for games that ended before 15:00 too; the protocol
    // scores only games that reached it
    for (rows.items) |*r| {
        if (!games.items[r.game].timeline15) r.y[@backingInt(Outcome.gold14)] = std.math.nan(f32);
    }

    try fillExperience(gpa, games.items, rows.items, players.items, kdas.items);
    data.games = games.items;
    data.rows = rows.items;
    return data;
}

pub const no_player = std.math.maxInt(u32);

/// Games over before 15:00 (remakes, early forfeits) don't count as experience; the
/// harness's min_duration_s
const experience_min_s = 900;

/// Row.champ_games and the like: a game counts once it has ended (start + duration)
/// at or before this one's start, so its result was known in champ select. players[i]
/// is rows[i]'s dense player id, no_player when unknown; kda[i] its (kills + assists) /
/// max(deaths, 1). Counts saturate
pub fn fillExperience(gpa: std.mem.Allocator, games: []const Game, rws: []Row, players: []const u32, kda: []const f32) !void {
    std.debug.assert(rws.len == players.len and rws.len == kda.len);
    const by_start = try gpa.alloc(u32, rws.len);
    defer gpa.free(by_start);
    const by_end = try gpa.alloc(u32, rws.len);
    defer gpa.free(by_end);
    for (by_start, by_end, 0..) |*s, *e, i| {
        s.* = @intCast(i);
        e.* = @intCast(i);
    }
    const Order = struct {
        games: []const Game,
        rws: []const Row,
        fn start(o: @This(), i: u32) i64 {
            return o.games[o.rws[i].game].start;
        }
        fn end(o: @This(), i: u32) i64 {
            const g = o.games[o.rws[i].game];
            return g.start + @as(i64, g.duration_s) * 1000;
        }
        fn byStart(o: @This(), a: u32, b: u32) bool {
            return o.start(a) < o.start(b);
        }
        fn byEnd(o: @This(), a: u32, b: u32) bool {
            return o.end(a) < o.end(b);
        }
    };
    const order: Order = .{ .games = games, .rws = rws };
    std.mem.sort(u32, by_start, order, Order.byStart);
    std.mem.sort(u32, by_end, order, Order.byEnd);

    var n_players: usize = 0;
    for (players) |p| if (p != no_player) {
        n_players = @max(n_players, p + 1);
    };
    const Totals = struct { games: u16 = 0, wins: u16 = 0, kda: f64 = 0, perf: u16 = 0, lanediff: f64 = 0, deaths: f64 = 0 };
    const totals = try gpa.alloc(Totals, n_players);
    defer gpa.free(totals);
    @memset(totals, .{});
    var champs: std.AutoHashMapUnmanaged(u64, [2]u16) = .empty;
    defer champs.deinit(gpa);

    var done: usize = 0;
    for (by_start) |i| {
        const r = &rws[i];
        while (done < by_end.len and order.end(by_end[done]) <= order.start(i)) : (done += 1) {
            const j = by_end[done];
            const p = players[j];
            const o = rws[j];
            if (p == no_player or games[o.game].duration_s < experience_min_s) continue;
            const won: u16 = @intFromBool(o.side == games[o.game].winner);
            const c = try champs.getOrPut(gpa, champKey(p, o.champion));
            if (!c.found_existing) c.value_ptr.* = @splat(0);
            c.value_ptr[0] +|= 1;
            c.value_ptr[1] +|= won;
            const t = &totals[p];
            t.games +|= 1;
            t.wins +|= won;
            t.kda += kda[j];
            const ld = o.y[@backingInt(Outcome.lanediff14)];
            const dt = o.y[@backingInt(Outcome.deaths15)];
            if (!std.math.isNan(ld) and !std.math.isNan(dt)) {
                t.perf +|= 1;
                t.lanediff += ld;
                t.deaths += dt;
            }
        }
        const p = players[i];
        if (p == no_player) continue;
        const c = champs.get(champKey(p, r.champion)) orelse @as([2]u16, @splat(0));
        r.champ_games = c[0];
        r.champ_wins = c[1];
        const t = totals[p];
        r.games_before = t.games;
        r.wins_before = t.wins;
        if (t.games > 0) r.kda_before = @floatCast(t.kda / @as(f64, @floatFromInt(t.games)));
        r.perf_games = t.perf;
        if (t.perf > 0) {
            r.lanediff14_before = @floatCast(t.lanediff / @as(f64, @floatFromInt(t.perf)));
            r.deaths15_before = @floatCast(t.deaths / @as(f64, @floatFromInt(t.perf)));
        }
    }
}

fn champKey(player: u32, champion: u32) u64 {
    return (@as(u64, player) << 32) | champion;
}

pub fn legendaryKey(patch: u32, item: u32) u64 {
    return (@as(u64, patch) << 32) | item;
}

fn fillTimeline(
    rows: []Row,
    slots: [10]u32,
    patch: u32,
    t: timeline.Timeline,
    legendaries: *const std.AutoHashMapUnmanaged(u64, void),
) void {
    var deaths: [10]f32 = @splat(0);
    // First completed item, ITEM_UNDO of that purchase cancelling it (meiolol-3c's rule)
    var first: [10]?struct { item: u32, t_ms: i64 } = @splat(null);
    for (t.events) |e| switch (e.data) {
        .champion_kill => |k| if (e.t_ms < 15 * 60_000 and k.victim >= 1 and k.victim <= 10) {
            deaths[k.victim - 1] += 1;
        },
        .item_purchased => |p| if (p.participant >= 1 and p.participant <= 10) {
            const i = p.participant - 1;
            if (first[i] == null and legendaries.contains(legendaryKey(patch, p.item)))
                first[i] = .{ .item = p.item, .t_ms = e.t_ms };
        },
        .item_undo => |u| if (u.participant >= 1 and u.participant <= 10) {
            const i = u.participant - 1;
            if (first[i]) |f| if (u.before == f.item and u.after == 0) {
                first[i] = null;
            };
        },
        else => {},
    };
    const f10 = t.frames[10];
    for (slots, 0..) |ri, i| {
        if (ri == std.math.maxInt(u32)) continue;
        const r = &rows[ri];
        const pid: u8 = @intCast(i + 1);
        r.y[@backingInt(Outcome.cs10)] = @floatFromInt(f10.get(pid, .minions) + f10.get(pid, .jungle_minions));
        r.y[@backingInt(Outcome.deaths15)] = deaths[i];
        if (std.math.isNan(r.y[@backingInt(Outcome.gold14)]))
            r.y[@backingInt(Outcome.gold14)] = @floatFromInt(t.frames[14].get(pid, .total_gold));
        if (first[i]) |f| r.y[@backingInt(Outcome.first_item)] = @as(f32, @floatFromInt(f.t_ms)) / 60_000;
    }
}

/// SNAP/legendaries.tsv (patch, item id; meiolol-3c writes it), empty when missing
pub fn loadLegendaries(gpa: std.mem.Allocator, io: std.Io, snap: []const u8) !std.AutoHashMapUnmanaged(u64, void) {
    var set: std.AutoHashMapUnmanaged(u64, void) = .empty;
    errdefer set.deinit(gpa);
    const path = try std.fs.path.join(gpa, &.{ snap, "legendaries.tsv" });
    defer gpa.free(path);
    const text = std.Io.Dir.cwd().readFileAlloc(io, path, gpa, .limited(16 << 20)) catch |err| switch (err) {
        error.FileNotFound => return set,
        else => return err,
    };
    defer gpa.free(text);
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    while (lines.next()) |line| {
        var cols = std.mem.tokenizeScalar(u8, line, '\t');
        const patch = cols.next() orelse continue;
        const item = std.fmt.parseInt(u32, cols.next() orelse continue, 10) catch continue;
        try set.put(gpa, legendaryKey(stats.patchKey(patch), item), {});
    }
    return set;
}

/// Counts and means per outcome, train and test, as a check on a snapshot
pub fn summary(d: *const Data, w: *std.Io.Writer) !void {
    var tests: usize = 0;
    var tl: usize = 0;
    for (d.games) |g| {
        tests += @intFromBool(g.is_test);
        tl += @intFromBool(g.timeline15);
    }
    try w.print("{d} games ({d} test), {d} with a timeline reaching 15:00; {d} rows\n", .{
        d.games.len, tests, tl, d.rows.len,
    });
    try w.print("{s: <12} {s: >9} {s: >10} {s: >9} {s: >10}\n", .{ "outcome", "train n", "mean", "test n", "mean" });
    for (0..outcome_count) |k| {
        var n: [2]usize = @splat(0);
        var sum: [2]f64 = @splat(0);
        for (d.rows) |r| {
            const v = r.y[k];
            if (std.math.isNan(v)) continue;
            const t = @intFromBool(d.games[r.game].is_test);
            n[t] += 1;
            sum[t] += v;
        }
        try w.print("{s: <12} {d: >9} {d: >10.3} {d: >9} {d: >10.3}\n", .{
            @tagName(@as(Outcome, @fromBackingInt(@intCast(k)))),
            n[0],
            sum[0] / @as(f64, @floatFromInt(@max(n[0], 1))),
            n[1],
            sum[1] / @as(f64, @floatFromInt(@max(n[1], 1))),
        });
    }
}

test "experience counts only games that ended before the start" {
    const gpa = std.testing.allocator;
    var prng: std.Random.DefaultPrng = .init(7);
    const rnd = prng.random();
    const n_games = 400;
    const games = try gpa.alloc(Game, n_games);
    defer gpa.free(games);
    var rws: std.ArrayList(Row) = .empty;
    defer rws.deinit(gpa);
    var players: std.ArrayList(u32) = .empty;
    defer players.deinit(gpa);
    var kdas: std.ArrayList(f32) = .empty;
    defer kdas.deinit(gpa);
    for (games, 0..) |*g, gi| {
        // Starts 10 minutes apart, games up to 40 minutes long: many overlap
        g.* = .{
            .match_id = "",
            .start = @intCast(gi * 600_000),
            .patch = 0,
            .platform = 0,
            .is_test = false,
            .teams = undefined,
            .winner = rnd.int(u1),
            .duration_s = rnd.intRangeLessThan(u32, 600, 2400),
        };
        for (0..10) |slot| {
            try rws.append(gpa, .{
                .game = @intCast(gi),
                .slot = @intCast(slot),
                .side = @intCast(slot / 5),
                .role = @fromBackingInt(@as(u3, @intCast(slot % 5))),
                .champion = rnd.intRangeLessThan(u32, 1, 4),
                .rank = null,
                .y = y: {
                    var y: [outcome_count]f32 = @splat(std.math.nan(f32));
                    if (gi % 3 != 0) {
                        y[@backingInt(Outcome.lanediff14)] = @floatFromInt(rnd.intRangeLessThan(i32, -2000, 2000));
                        y[@backingInt(Outcome.deaths15)] = @floatFromInt(rnd.intRangeLessThan(u8, 0, 6));
                    }
                    break :y y;
                },
            });
            try players.append(gpa, if (slot == 9) no_player else rnd.intRangeLessThan(u32, 0, 30));
            try kdas.append(gpa, @floatFromInt(rnd.intRangeLessThan(u8, 0, 12)));
        }
    }
    try fillExperience(gpa, games, rws.items, players.items, kdas.items);
    var overlapped: usize = 0;
    for (rws.items, players.items) |r, p| {
        var want: [4]u16 = @splat(0);
        var form: [3]f64 = @splat(0);
        var perf: u16 = 0;
        if (p != no_player) for (rws.items, players.items, kdas.items) |o, op, kda| {
            const g = games[o.game];
            if (op != p or g.duration_s < experience_min_s) continue;
            const ended = g.start + @as(i64, g.duration_s) * 1000 <= games[r.game].start;
            if (!ended) {
                overlapped += @intFromBool(g.start < games[r.game].start);
                continue;
            }
            const won: u16 = @intFromBool(o.side == g.winner);
            want[2] += 1;
            want[3] += won;
            form[0] += kda;
            const ld = o.y[@backingInt(Outcome.lanediff14)];
            if (!std.math.isNan(ld)) {
                perf += 1;
                form[1] += ld;
                form[2] += o.y[@backingInt(Outcome.deaths15)];
            }
            if (o.champion == r.champion) {
                want[0] += 1;
                want[1] += won;
            }
        };
        try std.testing.expectEqual(want, [4]u16{ r.champ_games, r.champ_wins, r.games_before, r.wins_before });
        try std.testing.expectEqual(perf, r.perf_games);
        const n: f64 = @floatFromInt(@max(want[2], 1));
        const np: f64 = @floatFromInt(@max(perf, 1));
        try std.testing.expectApproxEqAbs(form[0] / n, r.kda_before, 1e-4);
        try std.testing.expectApproxEqAbs(form[1] / np, r.lanediff14_before, 1e-2);
        try std.testing.expectApproxEqAbs(form[2] / np, r.deaths15_before, 1e-4);
    }
    try std.testing.expect(overlapped > 0);
}
