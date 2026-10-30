//! One row per player per game from an analysis snapshot, with the shared outcomes
//! (docs/model.md "Shared protocol"). Games are stats.scan's (ranked solo, no remakes,
//! roles complete); test games are eval.split's (one time cut, every platform). pack.zig hashes this file, so what
//! changes rows goes here; loading paths and hooks go in rows.zig

const std = @import("std");
const store = @import("store");
const core = @import("core");
const stats = @import("../stats.zig");
const eval = @import("../eval.zig");
const timeline = @import("../riot/timeline.zig");
const protocol = @import("protocol.zig");
const seatstats = @import("seatstats.zig");

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
    /// Higher is better: 0 Iron IV .. 39 Challenger I; null unranked or unknown.
    /// participants.tier, looked up after the game (sometimes days later), so it knows
    /// recent results: a dev-only diagnostic and report slices, never a model feature
    rank_after: ?u8 = null,
    /// The ladder rank before the game's day (fillRankStart); null when unknown
    rank_start: ?u8 = null,
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
    /// Means over earlier games where known, NaN when none: gold, CS and damage to
    /// champions per minute of game (participants' end-of-game totals)
    gpm_before: f32 = std.math.nan(f32),
    cspm_before: f32 = std.math.nan(f32),
    dpm_before: f32 = std.math.nan(f32),
    /// Share of games_before played in another role than this row's, NaN when none
    offrole_before: f32 = std.math.nan(f32),
    /// Days from the end of the player's last earlier game to this game's start, NaN
    /// when none
    days_since_last: f32 = std.math.nan(f32),
    /// Dense id of the player within this load (fillExperience's), no_player when the
    /// PUUID is unknown. Internal scope only: never in a Query, an api type or an export;
    /// rebuilt from the snapshot, so erasure (meiolol forget) carries over
    player: u32 = no_player,
    /// What the player did this game (SNAP/seat_stats.tsv, seatstats.SeatStat), NaN when
    /// unknown or the file is missing. Like y: training rows only, never a query
    stats: seatstats.Stats = seatstats.unknown,
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
    _ = try stats.scan(gpa, null, db, patches, &ids, 0, &list);
    var parts = try eval.split(gpa, list.items.items, &ids, .{});
    defer parts.deinit(gpa);

    // Scan order is by start; index by match key for the participant pass
    var index: std.AutoHashMapUnmanaged(u64, u32) = .empty;
    defer index.deinit(gpa);
    // Sized up front: rows and games live in the arena, which keeps every buffer a
    // growing list leaves behind (rows ~3x their size: 2.4M games ran out of 24 GB)
    const n_games = parts.train.len + parts.tests.len;
    try index.ensureTotalCapacity(gpa, @intCast(n_games));
    var games: std.ArrayList(Game) = try .initCapacity(arena, n_games);
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
    var extras: std.ArrayList(Extra) = .empty;
    defer extras.deinit(gpa);
    var player_ids: std.AutoHashMapUnmanaged(u64, u32) = .empty;
    defer player_ids.deinit(gpa);
    var by_game: std.AutoHashMapUnmanaged(u32, [10]u32) = .empty;
    defer by_game.deinit(gpa);
    var keys: std.ArrayList(?i64) = .empty;
    defer keys.deinit(gpa);
    const n_seats = n_games * 10;
    try rows.ensureTotalCapacityPrecise(arena, n_seats);
    try players.ensureTotalCapacityPrecise(gpa, n_seats);
    try extras.ensureTotalCapacityPrecise(gpa, n_seats);
    try keys.ensureTotalCapacityPrecise(gpa, n_seats);
    try by_game.ensureTotalCapacity(gpa, @intCast(n_games));
    {
        var q = try db.prepare(
            \\SELECT match_id, slot, team_id, position, champion_id, tier, division, gold14, puuid,
            \\    kills, deaths, assists, gold, cs, damage_to_champions
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
            try keys.append(gpa, if (q.isNull(8)) null else store.schema.puuidKey(q.bytes(8)));
            const deaths: f32 = @floatFromInt(@max(q.optInt(10) orelse 0, 1));
            const minutes: f32 = @as(f32, @floatFromInt(@max(g.duration_s, 60))) / 60;
            var rate: [3]f32 = @splat(std.math.nan(f32));
            for (&rate, 12..) |*x, col| if (q.optInt(@intCast(col))) |v| {
                x.* = @as(f32, @floatFromInt(v)) / minutes;
            };
            try extras.append(gpa, .{ .kda = @as(f32, @floatFromInt((q.optInt(9) orelse 0) + (q.optInt(11) orelse 0))) / deaths, .rate = rate });
            try rows.append(arena, .{
                .game = gi,
                .slot = slot,
                .side = side,
                .role = role,
                .champion = @intCast(q.int(4)),
                .rank_after = if (packed_rank) |r| ladderRank(r) else null,
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

    try fillExperience(gpa, games.items, rows.items, players.items, extras.items);
    try fillRankStart(gpa, db, games.items, rows.items, keys.items);
    const SeatRows = struct {
        index: *const std.AutoHashMapUnmanaged(u64, u32),
        by_game: *const std.AutoHashMapUnmanaged(u32, [10]u32),
        rows: []Row,
        pub fn at(sr: @This(), match_id: []const u8, slot: u8) ?*seatstats.Stats {
            const gi = sr.index.get(stats.matchKey(match_id)) orelse return null;
            const slots = sr.by_game.get(gi) orelse return null;
            if (slot >= 10 or slots[slot] == std.math.maxInt(u32)) return null;
            return &sr.rows[slots[slot]].stats;
        }
    };
    const io = std.Io.Threaded.global_single_threaded.io();
    _ = try seatstats.fill(io, snap, SeatRows{ .index = &index, .by_game = &by_game, .rows = rows.items });
    data.games = games.items;
    data.rows = rows.items;
    return data;
}

pub const no_player = std.math.maxInt(u32);

/// store.schema.packRank (0 Challenger I) to Row's order (0 Iron IV); null out of range
fn ladderRank(packed_rank: i64) ?u8 {
    return if (packed_rank >= 0 and packed_rank <= 39) @intCast(39 - packed_rank) else null;
}

const ms_per_day = 86_400_000;

/// Row.rank_start: the player's ladder rank as last seen on a UTC day before the game's,
/// from ranks when its last sighting (seen_day) is that old, else rank_history's latest
/// change before that day (a row per day the ladder showed a change, from 2026-10-12).
/// A sighting on the game's own day may come after the game, so it never counts.
/// keys[i] is rows[i]'s schema.puuidKey, null when the PUUID is unknown
fn fillRankStart(gpa: std.mem.Allocator, db: store.Db, games: []const Game, rws: []Row, keys: []const ?i64) !void {
    std.debug.assert(rws.len == keys.len);
    const Player = struct { rank: i64 = -1, seen_day: i64 = std.math.maxInt(i64), first: u32 = 0, len: u32 = 0 };
    const Change = struct { day: i64, rank: i64 };
    var want: std.AutoHashMapUnmanaged(i64, Player) = .empty;
    defer want.deinit(gpa);
    for (keys) |k| if (k) |key| try want.put(gpa, key, .{});
    {
        var q = try db.prepare("SELECT key, rank, seen_day FROM ranks");
        defer q.deinit();
        try q.bind(.{});
        while (try q.step()) {
            const p = want.getPtr(q.int(0)) orelse continue;
            p.rank = q.int(1);
            p.seen_day = q.int(2);
        }
    }
    var changes: std.ArrayList(Change) = .empty;
    defer changes.deinit(gpa);
    {
        var q = try db.prepare("SELECT key, day, rank FROM rank_history ORDER BY key, day");
        defer q.deinit();
        try q.bind(.{});
        while (try q.step()) {
            const p = want.getPtr(q.int(0)) orelse continue;
            if (p.len == 0) p.first = @intCast(changes.items.len);
            p.len += 1;
            try changes.append(gpa, .{ .day = q.int(1), .rank = q.int(2) });
        }
    }
    for (rws, keys) |*r, k| {
        const p = want.get(k orelse continue).?;
        const day = @divFloor(games[r.game].start, ms_per_day);
        if (p.seen_day < day) {
            r.rank_start = ladderRank(p.rank);
            continue;
        }
        var i = p.len;
        while (i > 0) : (i -= 1) {
            const c = changes.items[p.first + i - 1];
            if (c.day < day) {
                r.rank_start = ladderRank(c.rank);
                break;
            }
        }
    }
}

/// Games over before 15:00 (remakes, early forfeits) don't count as experience; the
/// harness's min_duration_s
const experience_min_s = 900;

/// Row.champ_games and the like: a game counts once it has ended (start + duration)
/// at or before this one's start, so its result was known in champ select. players[i]
/// is rows[i]'s dense player id, no_player when unknown (also written to Row.player);
/// extra[i] its own game's figures. Counts saturate
pub fn fillExperience(gpa: std.mem.Allocator, games: []const Game, rws: []Row, players: []const u32, extra: []const Extra) !void {
    std.debug.assert(rws.len == players.len and rws.len == extra.len);
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
    const Totals = struct {
        games: u16 = 0,
        wins: u16 = 0,
        kda: f64 = 0,
        perf: u16 = 0,
        lanediff: f64 = 0,
        deaths: f64 = 0,
        rate: [3]f64 = @splat(0),
        rate_n: [3]u32 = @splat(0),
        roles: [5]u16 = @splat(0),
        last_end: i64 = 0,
    };
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
            t.kda += extra[j].kda;
            for (extra[j].rate, &t.rate, &t.rate_n) |x, *sum, *n| if (!std.math.isNan(x)) {
                sum.* += x;
                n.* += 1;
            };
            t.roles[@backingInt(o.role)] +|= 1;
            t.last_end = @max(t.last_end, order.end(j));
            const ld = o.y[@backingInt(Outcome.lanediff14)];
            const dt = o.y[@backingInt(Outcome.deaths15)];
            if (!std.math.isNan(ld) and !std.math.isNan(dt)) {
                t.perf +|= 1;
                t.lanediff += ld;
                t.deaths += dt;
            }
        }
        const p = players[i];
        r.player = p;
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
        for ([_]*f32{ &r.gpm_before, &r.cspm_before, &r.dpm_before }, t.rate, t.rate_n) |out, sum, n| {
            if (n > 0) out.* = @floatCast(sum / @as(f64, @floatFromInt(n)));
        }
        if (t.games > 0) {
            const off = t.games -| t.roles[@backingInt(r.role)];
            r.offrole_before = @as(f32, @floatFromInt(off)) / @as(f32, @floatFromInt(t.games));
            r.days_since_last = @floatCast(@as(f64, @floatFromInt(order.start(i) - t.last_end)) / ms_per_day);
        }
    }
}

/// A row's own game for fillExperience: (kills + assists) / max(deaths, 1); gold, CS and
/// damage to champions per minute, NaN unknown
pub const Extra = struct {
    kda: f32,
    rate: [3]f32 = @splat(std.math.nan(f32)),
};

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
    var extras: std.ArrayList(Extra) = .empty;
    defer extras.deinit(gpa);
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
                // Players move between roles: rows' roles vary per player
                .role = @fromBackingInt(@as(u3, @intCast((slot + gi) % 5))),
                .champion = rnd.intRangeLessThan(u32, 1, 4),
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
            var rate: [3]f32 = undefined;
            for (&rate) |*x| x.* = if (rnd.uintLessThan(u8, 5) == 0) std.math.nan(f32) else @floatFromInt(rnd.intRangeLessThan(u16, 1, 900));
            try extras.append(gpa, .{ .kda = @floatFromInt(rnd.intRangeLessThan(u8, 0, 12)), .rate = rate });
        }
    }
    try fillExperience(gpa, games, rws.items, players.items, extras.items);
    var overlapped: usize = 0;
    var offroled: usize = 0;
    for (rws.items, players.items) |r, p| {
        var want: [4]u16 = @splat(0);
        var form: [3]f64 = @splat(0);
        var perf: u16 = 0;
        var rate: [3]f64 = @splat(0);
        var rate_n: [3]u32 = @splat(0);
        var off: u16 = 0;
        var last_end: ?i64 = null;
        try std.testing.expectEqual(p, r.player);
        if (p != no_player) for (rws.items, players.items, extras.items) |o, op, e| {
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
            form[0] += e.kda;
            for (e.rate, &rate, &rate_n) |x, *sum, *n| if (!std.math.isNan(x)) {
                sum.* += x;
                n.* += 1;
            };
            off += @intFromBool(o.role != r.role);
            const end = g.start + @as(i64, g.duration_s) * 1000;
            last_end = @max(last_end orelse end, end);
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
        for ([_]f32{ r.gpm_before, r.cspm_before, r.dpm_before }, rate, rate_n) |got, sum, k| {
            if (k == 0) try std.testing.expect(std.math.isNan(got)) else try std.testing.expectApproxEqAbs(sum / @as(f64, @floatFromInt(k)), got, 1e-2);
        }
        if (want[2] == 0) {
            try std.testing.expect(std.math.isNan(r.offrole_before) and std.math.isNan(r.days_since_last));
        } else {
            try std.testing.expectApproxEqAbs(@as(f64, @floatFromInt(off)) / n, r.offrole_before, 1e-5);
            const days = @as(f64, @floatFromInt(games[r.game].start - last_end.?)) / ms_per_day;
            try std.testing.expectApproxEqAbs(days, r.days_since_last, 1e-4);
            offroled += @intFromBool(r.offrole_before > 0 and r.offrole_before < 1);
        }
    }
    try std.testing.expect(overlapped > 0 and offroled > 0);
}
