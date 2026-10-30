//! `meiolol curves`: lane matchup curves (core/curvesfile.zig) from the compact match
//! timelines in timeline.db. One pass over the chosen games, like stats.zig.

const std = @import("std");
const store = @import("store");
const core = @import("core");
const timeline = @import("riot/timeline.zig");
const digest = @import("riot/digest.zig");
const mastery = @import("riot/mastery.zig");
const stats = @import("stats.zig");

const Role = core.Role;
const curvesfile = core.curvesfile;
const Lane = curvesfile.Lane;
const max_minutes = curvesfile.max_minutes;

comptime {
    // lane() reads frames 1..max_minutes and the frame count up to max_minutes + 2
    std.debug.assert(digest.max_frames >= max_minutes + 2);
}

const log = std.log.scoped(.curves);

pub const Summary = struct {
    games: u32,
    /// Timelines that did not decode or games without all ten positions
    skipped: u32,
};

/// Which games one curves file takes
pub const Spec = struct {
    /// Empty: any patch
    chosen: []const []const u8,
    /// Riot ms timestamp, 0: any
    since_ms: i64,
    platforms: []const []const u8,

    pub fn takes(s: Spec, patch: []const u8, start: i64, platform: []const u8) bool {
        if (start < s.since_ms) return false;
        if (s.chosen.len > 0 and !has(s.chosen, patch)) return false;
        return has(s.platforms, platform);
    }
};

fn has(list: []const []const u8, x: []const u8) bool {
    for (list) |y| if (std.mem.eql(u8, x, y)) return true;
    return false;
}

/// Every ranked solo game with a timeline on `chosen` patches (empty: any) started from
/// `since_ms` on (Riot ms timestamp, 0: any) and `platforms` (no remakes, a winner, all
/// ten positions). `legendaries`: sorted finished item ids for
/// first-item timing (ddragon.legendaries), empty to leave it out. Caller owns the
/// builder.
pub fn build(
    gpa: std.mem.Allocator,
    io: std.Io,
    db: store.Db,
    chosen: []const []const u8,
    since_ms: i64,
    platforms: []const []const u8,
    legendaries: []const u32,
) !struct { builder: curvesfile.Builder, summary: Summary } {
    var b: [1]curvesfile.Builder = .{.{ .gpa = gpa }};
    errdefer b[0].deinit();
    var summary: [1]Summary = undefined;
    const spec: Spec = .{ .chosen = chosen, .since_ms = since_ms, .platforms = platforms };
    try buildMany(gpa, io, db, &.{spec}, legendaries, &b, &summary);
    return .{ .builder = b[0], .summary = summary[0] };
}

/// As build, into builders[i] for specs[i] in one pass: each timeline is decoded once
/// however many files take its game. Caller owns the builders, also on error
pub fn buildMany(
    gpa: std.mem.Allocator,
    io: std.Io,
    db: store.Db,
    specs: []const Spec,
    legendaries: []const u32,
    builders: []curvesfile.Builder,
    summaries: []Summary,
) !void {
    @memset(summaries, .{ .games = 0, .skipped = 0 });
    // The query takes every spec's games (and maybe more); takes() then picks per spec
    var since: i64 = std.math.maxInt(i64);
    var patches: std.ArrayList([]const u8) = .empty;
    defer patches.deinit(gpa);
    var platforms: std.ArrayList([]const u8) = .empty;
    defer platforms.deinit(gpa);
    for (specs) |s| {
        if (s.chosen.len == 0) since = @min(since, s.since_ms);
        try patches.appendSlice(gpa, s.chosen);
        try platforms.appendSlice(gpa, s.platforms);
    }
    const patch_json = try std.json.Stringify.valueAlloc(gpa, patches.items, .{});
    defer gpa.free(patch_json);
    const platform_json = try std.json.Stringify.valueAlloc(gpa, platforms.items, .{});
    defer gpa.free(platform_json);

    const where =
        \\WHERE (m.game_start >= ? OR m.patch IN (SELECT value FROM json_each(?)))
        \\  AND m.queue_id = ?
        \\  AND m.platform IN (SELECT value FROM json_each(?))
        \\  AND m.remake = 0 AND m.winning_team IS NOT NULL
    ;
    const args = .{ since, patch_json, stats.ranked_solo, platform_json };
    var q = try db.prepare(
        \\SELECT m.match_id, m.winning_team, t.rowid, d.data, m.patch, m.game_start, m.platform
        \\FROM matches m JOIN timeline.timelines t USING (match_id)
        \\LEFT JOIN timeline.digests d ON d.source = t.rowid AND d.match_id = m.match_id
        \\
    ++ where);
    defer q.deinit();
    try q.bind(args);
    // tier is the rank snapshot stored with the match (players is emptied on a rekey);
    // mastery is a later snapshot of each player, absent after a rekey
    var players = try db.prepare("SELECT " ++ participant_columns ++ " FROM participants WHERE match_id = ?");
    defer players.deinit();
    var experienced: Experienced = try .load(gpa, db);
    defer experienced.deinit(gpa);
    var source: digest.Source = try .init(db);
    defer source.deinit();
    defer log.info("timelines from digests {d}, in full {d}", .{ source.digests, source.fulls });

    // Each game is ~3 reads at random (digest, its overflow page, participants)
    const ahead: *store.Ahead = try .start(gpa, io, db, .{
        .list = "SELECT m.match_id, t.rowid FROM matches m JOIN timeline.timelines t USING (match_id)\n" ++ where,
        .reads = &.{ digest.read_ahead, "SELECT puuid FROM participants WHERE match_id = ?1" },
    }, args);
    defer ahead.stop();

    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    var takers: std.ArrayList(usize) = .empty;
    defer takers.deinit(gpa);
    while (try q.step()) {
        ahead.next();
        const m = q.row(struct {
            match_id: []const u8,
            winner: i64,
            source: i64,
            digest: ?[]const u8,
            patch: []const u8,
            start: i64,
            platform: []const u8,
        });
        takers.clearRetainingCapacity();
        for (specs, 0..) |s, i| {
            if (s.takes(m.patch, m.start, m.platform)) try takers.append(gpa, i);
        }
        if (takers.items.len == 0) continue;
        _ = arena_state.reset(.retain_capacity);
        const arena = arena_state.allocator();
        const blue_won = m.winner == 100;
        const t = source.get(arena, m.source, m.digest) catch |err| {
            log.warn("{s}: {t}", .{ m.match_id, err });
            for (takers.items) |i| summaries[i].skipped += 1;
            continue;
        };
        try players.bind(.{m.match_id});
        const game = try readGame(&players, &experienced) orelse {
            for (takers.items) |i| summaries[i].skipped += 1;
            continue;
        };
        for (Role.all) |r| {
            const l = lane(t, game, r, blue_won, legendaries);
            for (takers.items) |i| try builders[i].addLaneOf(l, gameHash(m.match_id));
        }
        for (takers.items) |i| {
            builders[i].addGame();
            summaries[i].games += 1;
        }
    }
}

pub const Game = struct {
    /// Participant id (slot + 1) and champion per side and role
    ids: [2][5]u8,
    champions: [2][5]u32,
    bracket: ?curvesfile.Bracket,
    /// Mastery of at least curvesfile.experienced_points on their champion
    experienced: [2][5]bool = @splat(@splat(false)),
};

/// Lane.game: which split half a game's lanes fall in (curvefit.Half), the same whatever
/// window or order the game is read in
pub fn gameHash(match_id: []const u8) u32 {
    return @truncate(std.hash.Wyhash.hash(0, match_id));
}

/// (puuid, champion) pairs with at least curvesfile.experienced_points, from one pass over
/// mastery: a lookup per player per game was ~4.8M random reads, 45-60 min of the box's
/// curves pass (15 Oct). Keyed by a hash of both, so a collision (odds ~1e-7 at 2M
/// players) would mark one player wrongly
pub const Experienced = struct {
    set: std.AutoHashMapUnmanaged(u64, void) = .empty,

    pub fn load(gpa: std.mem.Allocator, db: store.Db) !Experienced {
        var e: Experienced = .{};
        errdefer e.deinit(gpa);
        var q = try db.prepare("SELECT puuid, data, fetched_at FROM mastery");
        defer q.deinit();
        try q.bind(.{});
        var arena_state: std.heap.ArenaAllocator = .init(gpa);
        defer arena_state.deinit();
        while (try q.step()) {
            _ = arena_state.reset(.retain_capacity);
            const r = q.row(struct { puuid: []const u8, data: []const u8, fetched_at: i64 });
            const entries = mastery.decode(arena_state.allocator(), r.data, r.fetched_at) catch continue;
            for (entries) |en| {
                if (en.points >= curvesfile.experienced_points) try e.set.put(gpa, key(r.puuid, en.champion), {});
            }
        }
        return e;
    }

    pub fn deinit(e: *Experienced, gpa: std.mem.Allocator) void {
        e.set.deinit(gpa);
    }

    fn has(e: *const Experienced, puuid: []const u8, champion: u32) bool {
        return e.set.contains(key(puuid, champion));
    }

    fn key(puuid: []const u8, champion: u32) u64 {
        return std.hash.Wyhash.hash(champion, puuid);
    }
};

/// participants columns Participant reads
pub const participant_columns = "slot, team_id, position, champion_id, tier, puuid";

/// A participants row; its strings live until the statement's next step
pub const Participant = struct {
    slot: i64,
    team: i64,
    position: []const u8,
    champion: u32,
    tier: ?[]const u8,
    puuid: ?[]const u8,
};

/// What gameOf needs of a participant, without the row's strings
pub const Seat = struct {
    slot: i64,
    blue: bool,
    role: ?Role,
    champion: u32,
    rank: ?usize,
    experienced: bool,
};

pub fn seatOf(p: Participant, experienced: *const Experienced) Seat {
    return .{
        .slot = p.slot,
        .blue = p.team == 100,
        .role = Role.fromLcu(p.position),
        .champion = p.champion,
        .rank = if (p.tier) |t| curvesfile.tierRank(t) else null,
        .experienced = if (p.puuid) |id| experienced.has(id, p.champion) else false,
    };
}

fn readGame(players: *store.sqlite.Stmt, experienced: *const Experienced) !?Game {
    var seats: [10]Seat = undefined;
    var n: usize = 0;
    while (try players.step()) : (n += 1) {
        if (n == seats.len) return null;
        seats[n] = seatOf(players.row(Participant), experienced);
    }
    return gameOf(seats[0..n]);
}

/// Null unless there are ten players and every position is filled exactly once per side
pub fn gameOf(seats: []const Seat) ?Game {
    if (seats.len != 10) return null;
    var g: Game = .{ .ids = undefined, .champions = undefined, .bracket = null };
    var seen: [2][5]bool = @splat(@splat(false));
    var ranks: [10]usize = undefined;
    var n_ranks: usize = 0;
    for (seats) |p| {
        const side: usize = if (p.blue) 0 else 1;
        const r = @backingInt(p.role orelse return null);
        if (seen[side][r] or p.slot < 0 or p.slot >= timeline.max_participants) return null;
        seen[side][r] = true;
        g.ids[side][r] = @intCast(p.slot + 1);
        g.champions[side][r] = p.champion;
        g.experienced[side][r] = p.experienced;
        if (p.rank) |rank| {
            ranks[n_ranks] = rank;
            n_ranks += 1;
        }
    }
    if (curvesfile.medianRank(ranks[0..n_ranks])) |rank| g.bracket = .ofRank(rank);
    return g;
}

/// Blue's laner in `r` as a, red's as b. `legendaries` as for build
pub fn lane(t: timeline.Timeline, g: Game, r: Role, blue_won: bool, legendaries: []const u32) Lane {
    const pa = g.ids[0][@backingInt(r)];
    const pb = g.ids[1][@backingInt(r)];
    // Frame k is minute k; the last frame is the game's end, part of a minute
    const full = if (t.frames.len >= 2) t.frames.len - 2 else 0;
    var l: Lane = .{
        .role = r,
        .bracket = g.bracket,
        .a = g.champions[0][@backingInt(r)],
        .b = g.champions[1][@backingInt(r)],
        .a_won = blue_won,
        .minutes = @intCast(@min(full, max_minutes)),
        .experienced_a = g.experienced[0][@backingInt(r)],
        .experienced_b = g.experienced[1][@backingInt(r)],
    };
    if (pa > t.participants or pb > t.participants) {
        l.minutes = 0;
        return l;
    }
    for (0..l.minutes) |i| {
        const f = t.frames[i + 1];
        l.gold[i] = diff(f.get(pa, .total_gold), f.get(pb, .total_gold));
        l.xp[i] = diff(f.get(pa, .xp), f.get(pb, .xp));
        l.cs[i] = diff(cs(f, pa), cs(f, pb));
    }
    var first_kill: i64 = std.math.maxInt(i64);
    for (t.events) |e| switch (e.data) {
        .champion_kill => |k| {
            const phase = phaseOf(e.t_ms);
            if (k.victim == pb and involved(k, pa)) l.a_kills_b[phase] = true;
            if (k.victim == pa and involved(k, pb)) l.b_kills_a[phase] = true;
            if (e.t_ms < first_kill) {
                first_kill = e.t_ms;
                l.first_blood_a = involved(k, pa);
                l.first_blood_b = involved(k, pb);
            }
        },
        .level_up => |u| switch (u.level) {
            2 => {
                if (u.participant == pa and l.level2_a == 0) l.level2_a = seconds(e.t_ms);
                if (u.participant == pb and l.level2_b == 0) l.level2_b = seconds(e.t_ms);
            },
            6 => {
                if (u.participant == pa and l.level6_a == 0) l.level6_a = seconds(e.t_ms);
                if (u.participant == pb and l.level6_b == 0) l.level6_b = seconds(e.t_ms);
            },
            else => {},
        },
        .item_purchased => |p| if (std.sort.binarySearch(u32, legendaries, p.item, orderU32) != null) {
            if (p.participant == pa and l.first_item_a == 0) l.first_item_a = seconds(e.t_ms);
            if (p.participant == pb and l.first_item_b == 0) l.first_item_b = seconds(e.t_ms);
        },
        else => {},
    };
    return l;
}

fn seconds(t_ms: i64) u16 {
    return @intCast(std.math.clamp(@divFloor(t_ms, 1000), 1, std.math.maxInt(u16)));
}

fn orderU32(key: u32, item: u32) std.math.Order {
    return std.math.order(key, item);
}

fn cs(f: timeline.Frame, p: u8) i32 {
    return f.get(p, .minions) + f.get(p, .jungle_minions);
}

fn diff(a: i32, b: i32) i16 {
    return @intCast(std.math.clamp(a - b, std.math.minInt(i16), std.math.maxInt(i16)));
}

fn phaseOf(t_ms: i64) usize {
    const minute = @divFloor(t_ms, 60_000);
    for (curvesfile.phase_ends, 0..) |end, i| if (minute < end) return i;
    return curvesfile.phase_ends.len;
}

fn involved(k: anytype, p: u8) bool {
    return k.killer == p or std.mem.findScalar(u8, k.assists, p) != null;
}

const testing = std.testing;

test "curves from a real timeline" {
    const gpa = testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const json = try store.raw.decompress(arena, @embedFile("riot/testdata/timeline.json.gz"));
    const t = try timeline.fromJson(arena, json);
    const blob = try store.raw.compress(arena, try timeline.encode(arena, t));

    const db = try store.schema.memory();
    defer db.close();
    for (0..2) |g| {
        const id = try arena.print("EUW1_{d}", .{g});
        try db.run("INSERT INTO matches VALUES (?,'t','EUW1',420,'16.20','',?,1600,100,0)", .{ id, 1000 * g });
        const data: store.Blob = .{ .bytes = blob };
        try db.run("INSERT INTO timeline.timelines VALUES (?,26,0,?)", .{ id, data });
        for (0..10) |slot| {
            const team: i64 = if (slot < 5) 100 else 200;
            try db.run(
                \\INSERT INTO participants
                \\  (match_id, slot, team_id, puuid, champion_id, position, win, tier)
                \\VALUES (?,?,?,'p',?,?,0,'EMERALD')
            , .{ id, slot, team, 10 * (slot + 1), Role.positions[slot % 5] });
        }
    }
    // Everyone shares puuid 'p': 150k points on champion 10 (blue top), 5k on 60
    const owned = try mastery.encode(arena, &.{
        .{ .champion = 10, .level = 20, .points = 150_000, .last_play = 0 },
        .{ .champion = 60, .level = 3, .points = 5_000, .last_play = 0 },
    }, 0);
    try db.run("INSERT INTO mastery VALUES ('p','EUW1',0,2,?)", .{store.Blob{ .bytes = owned }});

    // Every item anyone bought counts as finished here: first purchase times
    {
        // Any patch, from the second game's start on
        var recent = try build(gpa, testing.io, db, &.{}, 1000, &.{"EUW1"}, &.{});
        defer recent.builder.deinit();
        try testing.expectEqual(Summary{ .games = 1, .skipped = 0 }, recent.summary);
    }
    {
        // One pass for several files: each gets what its own build would
        var b: [3]curvesfile.Builder = @splat(.{ .gpa = gpa });
        defer for (&b) |*x| x.deinit();
        var sum: [3]Summary = undefined;
        try buildMany(gpa, testing.io, db, &.{
            .{ .chosen = &.{}, .since_ms = 1000, .platforms = &.{"EUW1"} },
            .{ .chosen = &.{"16.19"}, .since_ms = 0, .platforms = &.{"EUW1"} },
            .{ .chosen = &.{"16.20"}, .since_ms = 0, .platforms = &.{ "KR", "EUW1" } },
        }, &.{}, &b, &sum);
        try testing.expectEqual(Summary{ .games = 1, .skipped = 0 }, sum[0]);
        try testing.expectEqual(Summary{ .games = 0, .skipped = 0 }, sum[1]);
        try testing.expectEqual(Summary{ .games = 2, .skipped = 0 }, sum[2]);
        try testing.expectEqual(5, b[0].lanes.items.len);
        try testing.expectEqual(10, b[2].lanes.items.len);
    }
    var r = try build(gpa, testing.io, db, &.{"16.20"}, 0, &.{"EUW1"}, &.{ 1055, 3078 });
    defer r.builder.deinit();
    try testing.expectEqual(Summary{ .games = 2, .skipped = 0 }, r.summary);
    try testing.expectEqual(10, r.builder.lanes.items.len);
    var aw: std.Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();
    try r.builder.write(&aw.writer, "16.20", 2);
    var c: curvesfile.Curves = try .parse(gpa, aw.written());
    defer c.deinit(gpa);

    // Top: participant 1 (champion 10) against 6 (champion 60), blue won
    const top = c.get(.top, .all, 10, 60).?;
    try testing.expectEqual(2, top.games());
    try testing.expectEqual(2, top.wins());
    try testing.expect(c.get(.top, .mid, 10, 60) != null);
    try testing.expectEqual(2, c.getExperienced(.top, .all, 10, 60).?.games());
    try testing.expect(c.getExperienced(.top, .all, 60, 10) == null);
    const f14 = t.frames[14];
    const m14 = top.minute(13);
    try testing.expectEqual(2, m14.n);
    try testing.expectEqual(f14.get(1, .total_gold) - f14.get(6, .total_gold), m14.gold.p50);
    try testing.expectEqual(f14.get(1, .xp) - f14.get(6, .xp), m14.xp.p50);
    // 26 frames: minutes 1..24 complete, the 25th frame ends the game
    try testing.expectEqual(0, top.minute(24).n);
    try testing.expectEqual(2, top.minute(23).n);
    const l6 = top.level6();
    try testing.expect(l6[0] > 5 * 60 and l6[0] < 12 * 60);

    // The first kill: 9 (red bot) on 4 (blue bot) with 10's assist, under a minute in
    const bot = c.get(.bottom, .all, 40, 90).?;
    try testing.expectEqual(2, bot.deaths(0));
    try testing.expectEqual(0, bot.kills(0));
    // First blood: 9 kills, so red's bot laner took part in both games; top did not
    try testing.expectEqual([2]u32{ 0, 2 }, bot.firstBlood());
    try testing.expectEqual([2]u32{ 0, 0 }, top.firstBlood());
    const l2 = top.level2();
    try testing.expect(l2[0] > 0 and l2[0] < 3 * 60 and l2[1] > 0 and l2[1] < 3 * 60);
    try testing.expect(c.get(.utility, .all, 100, 50).?.flipped);
}
