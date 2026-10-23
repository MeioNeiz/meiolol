//! How hard champions are to pick up: win rate by the player's mastery points on the
//! champion at the time. Players new to a champion (under 30k points) against practised
//! ones (100k+): every champion has a gap (practised players are often better players
//! too), so a champion is harder or easier to pick up only when its gap is clearly off
//! the average one (docs/learned.md, Player). Every region's games, whatever the view's
//! region (a champion's difficulty hardly depends on it, and one region's games are too
//! few to tell most champions apart); the view's period's, as the rest of its pages.
//!
//! Points at the time: the player's mastery row (one per player, refetched monthly) for
//! games that start after its fetch. Games on the champion between the fetch and the
//! game are missing from the points, so some players count as newer than they are; the
//! row's last game on a champion instead (points of that very game) leans to losses,
//! as players drop a champion after one (docs/learned.md).

const std = @import("std");
const store = @import("store");
const core = @import("core");
const stats = @import("stats.zig");
const riot_mastery = @import("riot/mastery.zig");
const partials = @import("partials.zig");

const Stats = core.Stats;
const Allocator = std.mem.Allocator;

const log = std.log.scoped(.learning);

/// Lowest points of each bin: under 10k, 10-30k, 30-100k, 100-300k, 300k+
pub const bins = [_]u32{ 0, 10_000, 30_000, 100_000, 300_000 };
pub const bin_count = bins.len;
/// Bins below this are players new to the champion (under 30k points)
pub const new_bins = 2;
/// Bins from this are practised players (100k+)
pub const practised_from = 3;
/// Lane gold is read at this minute (the usual GD@14 convention)
pub const gold_minute = core.curvesfile.lane_minute;

pub fn binOf(points: u32) usize {
    var i: usize = bin_count - 1;
    while (points < bins[i]) i -= 1;
    return i;
}

/// `champion`'s bin in a decoded mastery row; absent (never played) is the first
pub fn binIn(entries: []const riot_mastery.Entry, champion: u32) usize {
    for (entries) |e| if (e.champion == champion) return binOf(e.points);
    return 0;
}

/// Whether a game starting at `start_ms` counts for a row fetched at `fetched_at`
pub fn after(fetched_at: i64, start_ms: i64) bool {
    return start_ms > fetched_at * 1000;
}

pub const Bin = struct {
    games: u32 = 0,
    wins: u32 = 0,
    /// Games with a timeline long enough for gold at gold_minute
    gold_games: u32 = 0,
    gold_sum: i64 = 0,

    pub fn winRate(b: Bin) f64 {
        return @as(f64, @floatFromInt(b.wins)) / @as(f64, @floatFromInt(@max(b.games, 1)));
    }

    pub fn gold(b: Bin) ?f64 {
        if (b.gold_games == 0) return null;
        return @as(f64, @floatFromInt(b.gold_sum)) / @as(f64, @floatFromInt(b.gold_games));
    }

    fn merge(b: *Bin, x: Bin) void {
        b.games += x.games;
        b.wins += x.wins;
        b.gold_games += x.gold_games;
        b.gold_sum += x.gold_sum;
    }
};

/// The bins from `lo` to `hi` (exclusive) as one
fn sum(b: [bin_count]Bin, lo: usize, hi: usize) Bin {
    var out: Bin = .{};
    for (b[lo..hi]) |x| out.merge(x);
    return out;
}

pub const Options = struct {
    /// Bins with fewer games are greyed out as "more data needed"
    thin_games: u32 = 200,
    /// Games of new and of practised players each, for a champion's gap
    min_games: u32 = 200,
    /// A champion is harder or easier when its pulled gap is this many of its own
    /// standard deviations (after pulling) off the average: with ~170 champions a plain
    /// 2-standard-error rule labels several by chance
    z: f64 = 2,
};

/// Bins per champion, by stats index
pub const Tally = struct {
    games: u32 = 0,
    bins: [][bin_count]Bin,

    pub fn init(gpa: Allocator, n: usize) !Tally {
        const b = try gpa.alloc([bin_count]Bin, n);
        @memset(b, @splat(.{}));
        return .{ .bins = b };
    }

    pub fn deinit(t: *Tally, gpa: Allocator) void {
        gpa.free(t.bins);
    }

    /// Champion index `c` played from points bin `bin`
    pub fn add(t: *Tally, c: usize, bin: usize, win: bool, gold: ?i32) void {
        t.games += 1;
        const b = &t.bins[c][bin];
        b.games += 1;
        b.wins += @intFromBool(win);
        if (gold) |g| {
            b.gold_games += 1;
            b.gold_sum += g;
        }
    }
};

/// Lane gold difference at gold_minute per participant slot, from the gold columns the
/// crawler fills from each timeline (riot/crawl.zig goldAt)
const GoldMap = std.StringHashMapUnmanaged([10]?i32);

/// A lane row of one match, as goldMap reads it
const LaneRow = struct { slot: i64, team: i64, position: [8]u8, len: usize, gold14: ?i64 };

/// Lane opponent: same position, other team. Both need a frame after gold_minute
/// (gold15 set): the last frame is the game's end, part of a minute
fn goldMap(arena: Allocator, db: store.Db, platform_json: []const u8) !GoldMap {
    var map: GoldMap = .empty;
    // Each match's lane rows read once and paired here: joining participants to
    // themselves took 20x the VM steps. CROSS JOIN keeps a match's rows together
    var q = try db.prepare(
        \\SELECT p.match_id, p.slot, p.team_id, p.position, p.gold14
        \\FROM matches m CROSS JOIN participants p USING (match_id)
        \\WHERE m.queue_id = ? AND m.remake = 0
        \\  AND m.platform IN (SELECT value FROM json_each(?))
        \\  AND p.position IN ('TOP', 'JUNGLE', 'MIDDLE', 'BOTTOM', 'UTILITY')
        \\  AND p.gold15 IS NOT NULL
    );
    defer q.deinit();
    try q.bind(.{ stats.ranked_solo, platform_json });
    var match: std.ArrayList(u8) = .empty;
    var lanes: std.ArrayList(LaneRow) = .empty;
    var more = try q.step();
    while (true) {
        const r = if (more) q.row(struct {
            match_id: []const u8,
            slot: i64,
            team_id: i64,
            position: []const u8,
            gold14: ?i64,
        }) else undefined;
        if (!more or !std.mem.eql(u8, r.match_id, match.items)) {
            try pairLanes(arena, &map, match.items, lanes.items);
            if (!more) break;
            match.clearRetainingCapacity();
            try match.appendSlice(arena, r.match_id);
            lanes.clearRetainingCapacity();
        }
        var lane: LaneRow = .{ .slot = r.slot, .team = r.team_id, .position = undefined, .len = r.position.len, .gold14 = r.gold14 };
        if (r.position.len <= lane.position.len) @memcpy(lane.position[0..r.position.len], r.position);
        try lanes.append(arena, lane);
        more = try q.step();
    }
    return map;
}

/// Each lane row's difference to its opponent (same position, other team): the last
/// opponent by slot when a position repeats, 0 when either lacks gold14
fn pairLanes(arena: Allocator, map: *GoldMap, match_id: []const u8, lanes: []const LaneRow) !void {
    for (lanes) |p| {
        if (p.slot < 0 or p.slot >= 10) continue;
        for (lanes) |o| {
            if (o.team == p.team or o.len != p.len) continue;
            if (!std.mem.eql(u8, o.position[0..o.len], p.position[0..p.len])) continue;
            const e = try map.getOrPut(arena, match_id);
            if (!e.found_existing) {
                e.key_ptr.* = try arena.dupe(u8, match_id);
                e.value_ptr.* = @splat(null);
            }
            const diff: i32 = if (p.gold14 != null and o.gold14 != null) @intCast(p.gold14.? - o.gold14.?) else 0;
            e.value_ptr[@intCast(p.slot)] = diff;
        }
    }
}

/// Every ranked solo game after its player's mastery fetch, into out[i] for slices[i]
fn tallyDb(gpa: Allocator, db: store.Db, st: *const Stats, slices: []const stats.Slice, out: []Tally) !void {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const platform_json = try stats.Slice.platformsJson(arena, slices);
    const gold = try goldMap(arena, db, platform_json);
    var q = try db.prepare(
        \\SELECT pa.match_id, pa.slot, pa.champion_id, pa.win, m.platform, m.game_start,
        \\  m.patch, ma.data, ma.fetched_at
        \\FROM matches m CROSS JOIN participants pa USING (match_id)
        \\  CROSS JOIN mastery ma ON ma.puuid = pa.puuid
        \\WHERE m.queue_id = ? AND m.remake = 0
        \\  AND m.platform IN (SELECT value FROM json_each(?))
        \\  AND m.game_start > ma.fetched_at * 1000
    );
    defer q.deinit();
    try q.bind(.{ stats.ranked_solo, platform_json });
    var scratch: std.heap.ArenaAllocator = .init(gpa);
    defer scratch.deinit();
    while (try q.step()) {
        _ = scratch.reset(.retain_capacity);
        const r = q.row(struct {
            match_id: []const u8,
            slot: i64,
            champion: u32,
            win: bool,
            platform: []const u8,
            start: i64,
            patch: []const u8,
            data: []const u8,
            fetched_at: i64,
        });
        const c = st.index(r.champion) orelse continue;
        std.debug.assert(after(r.fetched_at, r.start));
        const entries = riot_mastery.decode(scratch.allocator(), r.data, r.fetched_at) catch continue;
        const bin = binIn(entries, r.champion);
        const g: ?i32 = if (gold.get(r.match_id)) |slots|
            (if (r.slot >= 0 and r.slot < 10) slots[@intCast(r.slot)] else null)
        else
            null;
        const in = stats.Slice.of(slices, r.platform, r.start, r.patch);
        for (out, 0..) |*t, i| {
            if (in & (@as(u32, 1) << @intCast(i)) != 0) t.add(c, bin, r.win, g);
        }
    }
}

/// tallyDb from the views partials, with the bins masteryTallies found
fn tallyPartials(gpa: Allocator, games: *const partials.Store, st: *const Stats, slices: []const stats.Slice, out: []Tally) !void {
    const bins_of = &(games.learning orelse return error.NoMastery);
    var masks = try games.sliceMasks(gpa, slices);
    defer masks.deinit(gpa);
    const lanes = try games.codesIn(gpa, &.{ "TOP", "JUNGLE", "MIDDLE", "BOTTOM", "UTILITY" });
    defer gpa.free(lanes);
    for (games.sorted) |g| {
        const in = masks.of(g);
        if (in == 0) continue;
        for (g.players) |p| {
            const k = p.puuid orelse continue;
            const id = std.math.cast(u16, p.champion) orelse continue;
            const at = bins_of.get(.{ .key = k, .champion = id }) orelse continue;
            if (!after(at.fetched_at, g.start)) continue;
            const c = st.index(id) orelse continue;
            const bin = at.bin;
            const gold = laneGold(g, lanes, p.slot);
            for (out, 0..) |*t, i| {
                if (in & (@as(u32, 1) << @intCast(i)) != 0) t.add(c, bin, p.win, gold);
            }
        }
    }
}

/// goldMap's value for the player at `slot`: the difference to the last lane opponent
/// by slot (same position, other team, both with gold15), 0 when either lacks gold14;
/// null without one
fn laneGold(g: *const partials.Game, lanes: []const bool, slot: i8) ?i32 {
    if (slot < 0 or slot >= 10) return null;
    var diff: ?i32 = null;
    for (g.players) |p| {
        if (p.slot != slot) continue;
        if (!lanes[p.position] or !p.gold15) return null;
        for (g.players) |o| {
            if (!lanes[o.position] or !o.gold15) continue;
            if (o.team == p.team or o.position != p.position) continue;
            diff = if (p.gold14 != null and o.gold14 != null) p.gold14.? - o.gold14.? else 0;
        }
        return diff;
    }
    return null;
}

/// Tallies for each of `slices`; with `from`, the games from the views partials, after
/// their masteryTallies. Free with freeTallies
pub fn tallyWith(gpa: Allocator, db: store.Db, st: *const Stats, slices: []const stats.Slice, from: ?*const partials.Store) ![]Tally {
    const out = try gpa.alloc(Tally, slices.len);
    var made: usize = 0;
    errdefer freeTallies(gpa, out[0..made]);
    while (made < slices.len) : (made += 1) out[made] = try .init(gpa, st.n);
    if (from) |p| {
        try tallyPartials(gpa, p, st, slices, out);
    } else try tallyDb(gpa, db, st, slices, out);
    return out;
}

pub fn freeTallies(gpa: Allocator, ts: []Tally) void {
    for (ts) |*t| t.deinit(gpa);
    gpa.free(ts);
}

pub const Kind = enum { harder, usual, easier };

/// New against practised players on a champion
pub const Gap = struct {
    new: Bin,
    practised: Bin,
    /// Practised win rate minus new, percentage points, and its standard error
    pp: f64,
    se: f64,
    /// pp pulled toward the average gap by its noise, so a few lucky games can't top
    /// the table
    pulled: f64,
    kind: Kind,
};

pub const Champion = struct {
    id: u32,
    bins: [bin_count]Bin,
    /// Null under Options.min_games new or practised
    gap: ?Gap,
};

pub const Learning = struct {
    games: u32 = 0,
    thin_games: u32 = 0,
    /// Average gap over the champions with one, percentage points
    mean_pp: f64 = 0,
    /// Every champion's games together
    all: [bin_count]Bin = @splat(.{}),
    /// Champions with any games, in stats order
    champions: []const Champion = &.{},

    pub fn get(l: *const Learning, id: u32) ?Champion {
        for (l.champions) |c| if (c.id == id) return c;
        return null;
    }
};

pub fn build(arena: Allocator, t: *const Tally, st: *const Stats, opts: Options) !Learning {
    var out: Learning = .{ .games = t.games, .thin_games = opts.thin_games };
    var list: std.ArrayList(Champion) = .empty;
    var n_gaps: f64 = 0;
    var pp_sum: f64 = 0;
    var noise_sum: f64 = 0;
    for (t.bins, 0..) |b, c| {
        for (&out.all, b) |*a, x| a.merge(x);
        if (sum(b, 0, bin_count).games == 0) continue;
        const new = sum(b, 0, new_bins);
        const practised = sum(b, practised_from, bin_count);
        var gap: ?Gap = null;
        if (new.games >= opts.min_games and practised.games >= opts.min_games) {
            const pn = new.winRate();
            const pp = practised.winRate();
            const se = 100 * @sqrt(pn * (1 - pn) / @as(f64, @floatFromInt(new.games)) +
                pp * (1 - pp) / @as(f64, @floatFromInt(practised.games)));
            gap = .{ .new = new, .practised = practised, .pp = 100 * (pp - pn), .se = se, .pulled = 0, .kind = .usual };
            n_gaps += 1;
            pp_sum += gap.?.pp;
            noise_sum += se * se;
        }
        try list.append(arena, .{ .id = st.ids[c], .bins = b, .gap = gap });
    }
    out.champions = list.items;
    if (n_gaps == 0) return out;
    const mean = pp_sum / n_gaps;
    out.mean_pp = mean;
    var spread: f64 = 0;
    for (list.items) |c| if (c.gap) |g| {
        spread += (g.pp - mean) * (g.pp - mean);
    };
    // Spread between champions beyond what their noise alone gives
    const between = if (n_gaps > 1) @max(0, spread / (n_gaps - 1) - noise_sum / n_gaps) else 0;
    for (list.items) |*c| if (c.gap) |*g| {
        const keep = if (between > 0) between / (between + g.se * g.se) else 0;
        g.pulled = mean + keep * (g.pp - mean);
        // (pulled - mean) / (sqrt(keep) se)
        const z = (g.pp - mean) / g.se * @sqrt(keep);
        g.kind = if (z >= opts.z) .harder else if (z <= -opts.z) .easier else .usual;
    };
    return out;
}

pub fn make(arena: Allocator, t: *const Tally, st: *const Stats, opts: Options) !Learning {
    const l = try build(arena, t, st, opts);
    var counts: [3]usize = @splat(0);
    for (l.champions) |c| if (c.gap) |g| {
        counts[@backingInt(g.kind)] += 1;
    };
    log.info("{d} games with points at the time, average gap {d:.1} pp; {d} harder, {d} usual, {d} easier", .{
        l.games, l.mean_pp, counts[0], counts[1], counts[2],
    });
    return l;
}

/// data/learning.json, the champions with a gap: win rates of new and practised players
/// and their games
pub fn writeJson(w: *std.Io.Writer, l: Learning) !void {
    try w.print("{{\"games\":{d},\"mean_pp\":{d:.1},\"champions\":[", .{ l.games, l.mean_pp });
    var first = true;
    for (l.champions) |c| {
        const g = c.gap orelse continue;
        if (!first) try w.writeByte(',');
        first = false;
        try w.print("{{\"id\":{d},\"kind\":\"{t}\",\"new\":[{d:.4},{d}],\"practised\":[{d:.4},{d}]}}", .{
            c.id, g.kind, g.new.winRate(), g.new.games, g.practised.winRate(), g.practised.games,
        });
    }
    try w.writeAll("]}\n");
}

const testing = std.testing;

test "bins" {
    try testing.expectEqual(0, binOf(0));
    try testing.expectEqual(0, binOf(9_999));
    try testing.expectEqual(1, binOf(10_000));
    try testing.expectEqual(2, binOf(99_999));
    try testing.expectEqual(4, binOf(2_000_000));
    const entries = [_]riot_mastery.Entry{
        .{ .champion = 10, .level = 5, .points = 50_000, .last_play = 0 },
        .{ .champion = 20, .level = 9, .points = 400_000, .last_play = 0 },
    };
    try testing.expectEqual(2, binIn(&entries, 10));
    try testing.expectEqual(0, binIn(&entries, 30));
    try testing.expect(after(1_752_000_000, 1_752_000_000_001));
    try testing.expect(!after(1_752_000_000, 1_752_000_000_000));
}

test "gaps: off the average only when clear" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var champs: std.ArrayList(core.statsfile.Champion) = .empty;
    for (1..9) |id| try champs.append(arena, .{ .id = @intCast(id), .name = "x" });
    var b: core.statsfile.Builder = try .init(arena, champs.items);
    var aw: std.Io.Writer.Allocating = .init(arena);
    try b.write(&aw.writer, "16.20");
    const st: Stats = try .parse(arena, aw.written());

    var t: Tally = try .init(arena, st.n);
    // New players win 48%, practised 52%; champion 1 new 40%, champion 2 new 50% on few
    // games, champion 3 too few practised
    const new_wins = [_]u32{ 400, 110, 480, 480, 480, 480, 480, 480 };
    const new_games = [_]u32{ 1000, 220, 1000, 1000, 1000, 1000, 1000, 1000 };
    for (0..8) |i| {
        const c = st.index(@intCast(i + 1)).?;
        t.bins[c][0] = .{ .games = new_games[i], .wins = new_wins[i] };
        t.bins[c][4] = .{ .games = if (i == 2) 50 else 1000, .wins = if (i == 2) 26 else 520 };
    }
    const l = try build(arena, &t, &st, .{});
    try testing.expectEqual(.harder, l.get(1).?.gap.?.kind);
    try testing.expectEqual(null, l.get(3).?.gap);
    // Champion 2's gap is small but on 220 new games: pulled most of the way back
    const g2 = l.get(2).?.gap.?;
    try testing.expect(g2.pulled > g2.pp and g2.pulled < l.mean_pp);
    try testing.expectEqual(.usual, l.get(4).?.gap.?.kind);
    var out: std.Io.Writer.Allocating = .init(arena);
    try writeJson(&out.writer, l);
    const parsed = try std.json.parseFromSliceLeaky(std.json.Value, arena, out.written(), .{});
    try testing.expectEqual(7, parsed.object.get("champions").?.array.items.len);
}

test "db: games after the player's fetch, by the points then" {
    const gpa = testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const db = try store.schema.memory();
    defer db.close();
    try db.exec("INSERT INTO champions VALUES (10,'A','A','',''), (20,'B','B','',''), (99,'C','C','','')");
    const fetched_s: i64 = 1_752_000_000;
    const blob = try riot_mastery.encode(arena, &.{
        .{ .champion = 10, .level = 9, .points = 50_000, .last_play = fetched_s - 3600 },
        .{ .champion = 20, .level = 1, .points = 900, .last_play = fetched_s - 7200 },
    }, fetched_s);
    try db.run("INSERT INTO mastery VALUES ('me','EUW1',?,2,?)", .{ fetched_s, store.Blob{ .bytes = blob } });
    // Game 0 before the fetch; then 'me' (slot 0) wins on 10 and loses on 20
    for ([_]struct { i64, i64, bool }{ .{ -3600, 10, true }, .{ 3600, 10, true }, .{ 7200, 20, false } }, 0..) |g, n| {
        const id = try arena.print("EUW1_{d}", .{n});
        try db.run("INSERT INTO matches VALUES (?,'t','EUW1',420,'16.20','',?,1600,?,0)", .{ id, (fetched_s + g[0]) * 1000, @as(i64, if (g[2]) 100 else 200) });
        for (0..10) |slot| {
            const team: i64 = if (slot < 5) 100 else 200;
            try db.run(
                \\INSERT INTO participants (match_id, slot, team_id, puuid, champion_id, position, win)
                \\VALUES (?,?,?,?,?,'TOP',?)
            , .{ id, slot, team, if (slot == 0) "me" else "other", if (slot == 0) g[1] else 99, (team == 100) == g[2] });
        }
    }

    var champs: std.ArrayList(core.statsfile.Champion) = .empty;
    for ([_]u32{ 10, 20, 99 }) |id| try champs.append(arena, .{ .id = id, .name = "x" });
    var b: core.statsfile.Builder = try .init(arena, champs.items);
    var aw: std.Io.Writer.Allocating = .init(arena);
    try b.write(&aw.writer, "16.20");
    const st: Stats = try .parse(arena, aw.written());

    const ts = try tallyWith(gpa, db, &st, &.{.{ .platforms = &.{"EUW1"} }}, null);
    defer freeTallies(gpa, ts);
    const t = ts[0];
    try testing.expectEqual(2, t.games);
    try testing.expectEqual(Bin{ .games = 1, .wins = 1 }, t.bins[st.index(10).?][2]);
    try testing.expectEqual(Bin{ .games = 1, .wins = 0 }, t.bins[st.index(20).?][0]);
    try testing.expectEqual(0, t.bins[st.index(99).?][0].games);
}
