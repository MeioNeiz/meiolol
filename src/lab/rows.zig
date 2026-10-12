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
    var by_game: std.AutoHashMapUnmanaged(u32, [10]u32) = .empty;
    defer by_game.deinit(gpa);
    {
        var q = try db.prepare(
            \\SELECT match_id, slot, team_id, position, champion_id, tier, division, gold14
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

    data.games = games.items;
    data.rows = rows.items;
    return data;
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
