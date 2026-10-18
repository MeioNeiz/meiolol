//! Learning curves: how players do on a champion by how many games they have on it.
//! Win rate and lane gold difference at 14 per experience bin, and roughly when players
//! reach the champion's usual win rate. Sets expectations for trying a champion
//! (research/questions/player-tool-needs.md C3: experience outweighs counters).
//!
//! Experience is a game's number on that champion in the player's crawled ranked
//! history, so only players whose match history was crawled count. Games before the
//! crawl window look like early games: early bins hold some returning players, which
//! makes the gap shown smaller than the real one, never larger. Mastery (once the
//! table fills) can tell those players apart.

const std = @import("std");
const store = @import("store");
const core = @import("core");
const timeline = @import("riot/timeline.zig");
const stats = @import("stats.zig");
const ep = @import("riot/endpoints.zig");
const par = @import("par.zig");
const partials = @import("partials.zig");

/// FROM and WHERE for the participant rows of the scan pool's players (matches_checked_at
/// set), driven from players_region_check: ~15k players of 9M, where joining every
/// participant to players did 2.3M lookups (19 s of the box's site build, now ~5x less).
/// Every region listed so the index's first column is an equality; a checked player
/// always has one
pub const checked_players = "FROM players pl CROSS JOIN participants pa USING (puuid)" ++
    " CROSS JOIN matches m USING (match_id)" ++
    " WHERE pl.region IN (" ++ region_list ++ ") AND pl.matches_checked_at IS NOT NULL";

const region_list = blk: {
    var list: []const u8 = "";
    for (std.enums.values(ep.Region), 0..) |r, i| list = list ++ (if (i == 0) "'" else ", '") ++ @tagName(r) ++ "'";
    break :blk list;
};

const Role = core.Role;
const Stats = core.Stats;
const Allocator = std.mem.Allocator;

const log = std.log.scoped(.learning);

/// First game number of each bin: 1-5, 6-20, 21-50, 51+
pub const bins = [_]u32{ 1, 6, 21, 51 };
pub const bin_count = bins.len;
/// Lane gold is read at this minute (the usual GD@14 convention)
pub const gold_minute = core.curvesfile.lane_minute;

pub fn binOf(game: u32) usize {
    var i: usize = bin_count - 1;
    while (game < bins[i]) i -= 1;
    return i;
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
};

pub const Options = struct {
    /// Bins with fewer games are greyed out as "more data needed"
    thin_games: u32 = 200,
    /// Every bin up to the one reached needs this many games to say when players reach
    /// the usual win rate
    reach_games: u32 = 400,
    /// Within this many points of the usual win rate counts as reached
    reach_pp: f64 = 1.0,
};

/// Bins per champion, by stats index
pub const Tally = struct {
    players: u32 = 0,
    bins: [][bin_count]Bin,

    pub fn init(gpa: Allocator, n: usize) !Tally {
        const b = try gpa.alloc([bin_count]Bin, n);
        @memset(b, @splat(.{}));
        return .{ .bins = b };
    }

    pub fn deinit(t: *Tally, gpa: Allocator) void {
        gpa.free(t.bins);
    }

    /// `game`: 1 for a player's first game on champion index `c`
    pub fn add(t: *Tally, c: usize, game: u32, win: bool, gold: ?i32) void {
        const b = &t.bins[c][binOf(game)];
        b.games += 1;
        b.wins += @intFromBool(win);
        if (gold) |g| {
            b.gold_games += 1;
            b.gold_sum += g;
        }
    }
};

/// Win rate over all bins: what players on the champion usually get
pub fn usual(b: [bin_count]Bin) f64 {
    var games: u32 = 0;
    var wins: u32 = 0;
    for (b) |x| {
        games += x.games;
        wins += x.wins;
    }
    return @as(f64, @floatFromInt(wins)) / @as(f64, @floatFromInt(@max(games, 1)));
}

/// The first bin whose win rate is within reach_pp of the usual one; null while any
/// bin up to it is under reach_games, or when none gets there
pub fn reach(b: [bin_count]Bin, opts: Options) ?usize {
    const target = usual(b) - opts.reach_pp / 100;
    for (b, 0..) |x, i| {
        if (x.games < opts.reach_games) return null;
        if (x.winRate() >= target) return i;
    }
    return null;
}

/// Lane gold difference at gold_minute per participant slot, from the gold columns the
/// crawler fills from each timeline (riot/crawl.zig goldAt)
const GoldMap = std.StringHashMapUnmanaged([10]?i32);

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
    const Lane = struct { slot: i64, team: i64, position: [8]u8, len: usize, gold14: ?i64 };
    var match: std.ArrayList(u8) = .empty;
    var lanes: std.ArrayList(Lane) = .empty;
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
        var lane: Lane = .{ .slot = r.slot, .team = r.team_id, .position = undefined, .len = r.position.len, .gold14 = r.gold14 };
        if (r.position.len <= lane.position.len) @memcpy(lane.position[0..r.position.len], r.position);
        try lanes.append(arena, lane);
        more = try q.step();
    }
    return map;
}

/// Each lane row's difference to its opponent (same position, other team): the last
/// opponent by slot when a position repeats, 0 when either lacks gold14
fn pairLanes(arena: Allocator, map: *GoldMap, match_id: []const u8, lanes: anytype) !void {
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

/// Puuid ranges the history is read in, each on its own connection: its participant
/// rows are found through the puuid index, a cold page each (on the box 16 Oct: 238 s,
/// 14 s of it CPU). Lower bounds, by first character over Riot's base64url alphabet; a
/// player's rows all fall in one range
const ranges = blk: {
    const alphabet = "-0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz";
    const n = 4;
    var lows: [n][]const u8 = undefined;
    lows[0] = "";
    for (1..n) |i| lows[i] = alphabet[alphabet.len * i / n ..][0..1];
    break :blk lows;
};

/// Past every puuid character
const puuid_end = "\x7f";

/// Every ranked solo game of players whose match history was crawled, all patches
/// (experience builds across patches), into out[i] for the platforms of sets[i]: one
/// pass per puuid range, summed (counts, so in any order)
pub fn tallyHistory(
    gpa: Allocator,
    io: std.Io,
    db: store.Db,
    st: *const Stats,
    sets: []const []const []const u8,
    out: []Tally,
) !void {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const platform_json = try stats.setsJson(arena, sets);
    const gold = try goldMap(arena, db, platform_json);

    const parts = try arena.alloc([]Tally, ranges.len);
    for (parts) |*part| {
        part.* = try arena.alloc(Tally, sets.len);
        for (part.*) |*t| t.* = .{ .bins = try arena.alloc([bin_count]Bin, st.n) };
        for (part.*) |*t| @memset(t.bins, @splat(.{}));
    }
    const reading: Reading = .{
        .gpa = gpa,
        .db = db,
        .siblings = db.filename("main").len != 0,
        .st = st,
        .sets = sets,
        .platform_json = platform_json,
        .gold = &gold,
        .parts = parts,
    };
    if (reading.siblings) {
        try par.each(io, ranges.len, &reading, Reading.read);
    } else for (0..ranges.len) |i| try reading.read(i);
    for (parts) |part| for (out, part) |*into, from| {
        into.players += from.players;
        for (into.bins, from.bins) |*to, add| for (to, add) |*b, x| {
            b.games += x.games;
            b.wins += x.wins;
            b.gold_games += x.gold_games;
            b.gold_sum += x.gold_sum;
        };
    };
}

const Reading = struct {
    gpa: Allocator,
    db: store.Db,
    /// Each range on its own connection; false for an in-memory db, whose ranges go in
    /// turn on its one
    siblings: bool,
    st: *const Stats,
    sets: []const []const []const u8,
    platform_json: []const u8,
    gold: *const GoldMap,
    parts: []const []Tally,

    fn read(r: *const Reading, i: usize) !void {
        const db = if (r.siblings) (try store.schema.openSibling(r.gpa, r.db)).? else r.db;
        defer if (r.siblings) db.close();
        const high = if (i + 1 < ranges.len) ranges[i + 1] else puuid_end;
        try historyRange(r.gpa, db, r.st, r.sets, r.platform_json, r.gold, ranges[i], high, r.parts[i]);
    }
};

/// tallyHistory for the players with puuid in [low, high)
fn historyRange(
    gpa: Allocator,
    db: store.Db,
    st: *const Stats,
    sets: []const []const []const u8,
    platform_json: []const u8,
    gold: *const GoldMap,
    low: []const u8,
    high: []const u8,
    out: []Tally,
) !void {
    var q = try db.prepare("SELECT pa.puuid, pa.champion_id, pa.match_id, pa.slot, pa.win, m.platform " ++
        checked_players ++ " AND pl.puuid >= ? AND pl.puuid < ? AND m.queue_id = ? AND m.remake = 0" ++
        " AND m.platform IN (SELECT value FROM json_each(?))" ++
        " ORDER BY pa.puuid, pa.champion_id, m.game_start");
    defer q.deinit();
    try q.bind(.{ low, high, stats.ranked_solo, platform_json });
    var player: std.ArrayList(u8) = .empty;
    defer player.deinit(gpa);
    var champion: i64 = -1;
    // Per set: the game's number on the champion, and whether the player counted yet
    const games = try gpa.alloc(u32, sets.len);
    defer gpa.free(games);
    var seen: u32 = 0;
    while (try q.step()) {
        const r = q.row(struct {
            puuid: []const u8,
            champion: i64,
            match_id: []const u8,
            slot: i64,
            win: bool,
            platform: []const u8,
        });
        if (!std.mem.eql(u8, r.puuid, player.items)) {
            player.clearRetainingCapacity();
            try player.appendSlice(gpa, r.puuid);
            seen = 0;
            champion = -1;
        }
        if (r.champion != champion) {
            champion = r.champion;
            @memset(games, 0);
        }
        const in = stats.setsWith(sets, r.platform);
        for (out, games, 0..) |*t, *game, i| {
            const bit = @as(u32, 1) << @intCast(i);
            if (in & bit == 0) continue;
            game.* += 1;
            if (seen & bit == 0) t.players += 1;
            seen |= bit;
        }
        const c = st.index(@intCast(champion)) orelse continue;
        const slot = r.slot;
        const g: ?i32 = if (gold.get(r.match_id)) |slots|
            (if (slot >= 0 and slot < 10) slots[@intCast(slot)] else null)
        else
            null;
        for (out, games, 0..) |*t, game, i| {
            if (in & (@as(u32, 1) << @intCast(i)) != 0) t.add(c, game, r.win, g);
        }
    }
}

/// tallyHistory from the views partials: the same rows, with the checked players read
/// from db, grouped by PUUID key instead of PUUID (sums, so in any player order)
pub fn tallyHistoryFrom(
    gpa: Allocator,
    db: store.Db,
    games: *const partials.Store,
    st: *const Stats,
    sets: []const []const []const u8,
    out: []Tally,
) !void {
    var checked: std.AutoHashMapUnmanaged(partials.Key, void) = .empty;
    defer checked.deinit(gpa);
    {
        var q = try db.prepare("SELECT puuid FROM players WHERE region IN (" ++ region_list ++ ") AND matches_checked_at IS NOT NULL" ++
            // As the puuid ranges
            " AND puuid < '" ++ puuid_end ++ "'");
        defer q.deinit();
        try q.bind(.{});
        while (try q.step()) try checked.put(gpa, partials.key(q.row(struct { p: []const u8 }).p), {});
    }
    const masks = try games.setMasks(gpa, sets);
    defer gpa.free(masks);
    const lanes = blk: {
        var lane = try gpa.alloc(bool, games.strings.count() + 1);
        @memset(lane, false);
        for (games.strings.keys(), 1..) |k, code| {
            for ([_][]const u8{ "TOP", "JUNGLE", "MIDDLE", "BOTTOM", "UTILITY" }) |l| if (std.mem.eql(u8, k, l)) {
                lane[code] = true;
            };
        }
        break :blk lane;
    };
    defer gpa.free(lanes);
    const Row = struct {
        key: partials.Key,
        champion: i64,
        start: i64,
        id: []const u8,
        platform: partials.Code,
        win: bool,
        gold: ?i32,
    };
    var rows: std.ArrayList(Row) = .empty;
    defer rows.deinit(gpa);
    for (games.sorted) |g| {
        if (masks[g.platform] == 0) continue;
        for (g.players) |p| {
            const k = p.puuid orelse continue;
            if (!checked.contains(k)) continue;
            try rows.append(gpa, .{
                .key = k,
                .champion = p.champion,
                .start = g.start,
                .id = g.id,
                .platform = g.platform,
                .win = p.win,
                .gold = laneGold(g, lanes, p.slot),
            });
        }
    }
    // Games on a champion in start order; a tie (never seen) by match id
    std.mem.sort(Row, rows.items, {}, struct {
        fn f(_: void, a: Row, b: Row) bool {
            if (!a.key.eql(b.key)) return a.key.lessThan(b.key);
            if (a.champion != b.champion) return a.champion < b.champion;
            if (a.start != b.start) return a.start < b.start;
            return std.mem.lessThan(u8, a.id, b.id);
        }
    }.f);
    const counts = try gpa.alloc(u32, sets.len);
    defer gpa.free(counts);
    var player: ?partials.Key = null;
    var champion: i64 = -1;
    var seen: u32 = 0;
    for (rows.items) |r| {
        if (player == null or !player.?.eql(r.key)) {
            player = r.key;
            seen = 0;
            champion = -1;
        }
        if (r.champion != champion) {
            champion = r.champion;
            @memset(counts, 0);
        }
        const in = masks[r.platform];
        for (out, counts, 0..) |*t, *game, i| {
            const bit = @as(u32, 1) << @intCast(i);
            if (in & bit == 0) continue;
            game.* += 1;
            if (seen & bit == 0) t.players += 1;
            seen |= bit;
        }
        const c = st.index(@intCast(champion)) orelse continue;
        for (out, counts, 0..) |*t, game, i| {
            if (in & (@as(u32, 1) << @intCast(i)) != 0) t.add(c, game, r.win, r.gold);
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

/// Tallies for each of `sets` (platform lists) in one pass; free with freeTallies
pub fn tally(gpa: Allocator, io: std.Io, db: store.Db, st: *const Stats, sets: []const []const []const u8) ![]Tally {
    return tallyWith(gpa, io, db, st, sets, null);
}

/// As tally; with `from`, the games from the views partials
pub fn tallyWith(gpa: Allocator, io: std.Io, db: store.Db, st: *const Stats, sets: []const []const []const u8, from: ?*const partials.Store) ![]Tally {
    const out = try gpa.alloc(Tally, sets.len);
    var made: usize = 0;
    errdefer freeTallies(gpa, out[0..made]);
    while (made < sets.len) : (made += 1) out[made] = try .init(gpa, st.n);
    if (from) |p| {
        try tallyHistoryFrom(gpa, db, p, st, sets, out);
    } else try tallyHistory(gpa, io, db, st, sets, out);
    return out;
}

pub fn freeTallies(gpa: Allocator, ts: []Tally) void {
    for (ts) |*t| t.deinit(gpa);
    gpa.free(ts);
}

pub const Champion = struct {
    id: u32,
    bins: [bin_count]Bin,
    usual: f64,
    /// Index into `bins`
    reach: ?usize,
};

pub const Learning = struct {
    players: u32 = 0,
    thin_games: u32 = 0,
    /// Champions with any games, in stats order
    champions: []const Champion = &.{},

    pub fn get(l: *const Learning, id: u32) ?Champion {
        for (l.champions) |c| if (c.id == id) return c;
        return null;
    }
};

pub fn build(arena: Allocator, t: *const Tally, st: *const Stats, opts: Options) !Learning {
    var list: std.ArrayList(Champion) = .empty;
    for (t.bins, 0..) |b, c| {
        if (usualGames(b) == 0) continue;
        try list.append(arena, .{ .id = st.ids[c], .bins = b, .usual = usual(b), .reach = reach(b, opts) });
    }
    return .{ .players = t.players, .thin_games = opts.thin_games, .champions = list.items };
}

fn usualGames(b: [bin_count]Bin) u32 {
    var n: u32 = 0;
    for (b) |x| n += x.games;
    return n;
}

pub fn make(arena: Allocator, t: *const Tally, st: *const Stats, opts: Options) !Learning {
    const l = try build(arena, t, st, opts);
    var reached: usize = 0;
    for (l.champions) |c| reached += @intFromBool(c.reach != null);
    log.info("{d} players' histories, {d} champions, {d} with a learning point", .{
        l.players, l.champions.len, reached,
    });
    return l;
}

/// data/learning.json: per champion [games, wins, gold games, mean gold] per bin
pub fn writeJson(w: *std.Io.Writer, l: Learning) !void {
    try w.print("{{\"players\":{d},\"thin_games\":{d},\"bins\":[", .{ l.players, l.thin_games });
    for (bins, 0..) |b, i| {
        if (i > 0) try w.writeByte(',');
        try w.print("{d}", .{b});
    }
    try w.writeAll("],\"champions\":[");
    for (l.champions, 0..) |c, i| {
        if (i > 0) try w.writeByte(',');
        try w.print("{{\"id\":{d},\"usual\":{d:.4},\"reach\":", .{ c.id, c.usual });
        if (c.reach) |r| try w.print("{d}", .{r}) else try w.writeAll("null");
        try w.writeAll(",\"bins\":[");
        for (c.bins, 0..) |b, j| {
            if (j > 0) try w.writeByte(',');
            try w.print("[{d},{d},{d},{d:.0}]", .{ b.games, b.wins, b.gold_games, b.gold() orelse 0 });
        }
        try w.writeAll("]}");
    }
    try w.writeAll("]}\n");
}

const testing = std.testing;

test "bins and reach" {
    try testing.expectEqual(0, binOf(1));
    try testing.expectEqual(0, binOf(5));
    try testing.expectEqual(1, binOf(6));
    try testing.expectEqual(2, binOf(50));
    try testing.expectEqual(3, binOf(51));
    try testing.expectEqual(3, binOf(4000));

    const opts: Options = .{ .reach_games = 100 };
    // 44%, 49%, 52%, 53%: usual is pulled toward the later bins by their games
    const b: [bin_count]Bin = .{
        .{ .games = 200, .wins = 88 },
        .{ .games = 400, .wins = 196 },
        .{ .games = 600, .wins = 312 },
        .{ .games = 1000, .wins = 530 },
    };
    try testing.expectEqual(2, reach(b, opts).?);
    var thin = b;
    thin[1].games = 50;
    try testing.expectEqual(null, reach(thin, opts));
    // Easy from the start
    var easy = b;
    easy[0].wins = 105;
    try testing.expectEqual(0, reach(easy, opts).?);
}

test "history: game number per player and champion, lane gold from the gold columns" {
    const gpa = testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const json = try store.raw.decompress(arena, @embedFile("riot/testdata/timeline.json.gz"));
    const tl = try timeline.fromJson(arena, json);
    // In memory, the puuid ranges in turn; in a file, each on its own connection. The
    // two players in different ranges
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const memory_db = try store.schema.memory();
    defer memory_db.close();
    const file_db = try store.schema.open(gpa, try std.fs.path.join(arena, &.{ ".zig-cache", "tmp", &tmp.sub_path }));
    defer file_db.close();
    for ([_]store.Db{ memory_db, file_db }) |db| try historyCase(arena, db, tl);
}

fn historyCase(arena: Allocator, db: store.Db, tl: anytype) !void {
    const gpa = testing.allocator;
    try db.exec(
        \\INSERT INTO champions VALUES (10,'A','A','',''), (60,'B','B','',''), (99,'C','C','','');
        \\INSERT INTO players (puuid, source, region, matches_checked_at) VALUES ('Bme','t','europe',1), ('Xyou','t','europe',1);
        \\INSERT INTO players (puuid, source) VALUES ('other','t');
    );
    const positions = [_][]const u8{ "TOP", "JUNGLE", "MIDDLE", "BOTTOM", "UTILITY" };
    // Seven games: 'me' on champion 10 in top (slot 0), 'you' on 60 against (slot 5)
    for (0..7) |g| {
        const id = try arena.print("EUW1_{d}", .{g});
        try db.run("INSERT INTO matches VALUES (?,'t','EUW1',420,'16.20','',?,1600,100,0)", .{ id, g });
        for (0..10) |slot| {
            const team: i64 = if (slot < 5) 100 else 200;
            const who: []const u8 = if (slot == 0) "Bme" else if (slot == 5) "Xyou" else "other";
            const champ: i64 = if (slot == 0) 10 else if (slot == 5) 60 else 99;
            try db.run(
                \\INSERT INTO participants (match_id, slot, team_id, puuid, champion_id, position, win)
                \\VALUES (?,?,?,?,?,?,?)
            , .{ id, slot, team, who, champ, positions[slot % 5], team == 100 });
            // Game 0 has a timeline: the crawler's gold columns from its frames
            if (g == 0) try db.run("UPDATE participants SET gold14 = ?, gold15 = ? WHERE match_id = ? AND slot = ?", .{
                tl.frames[14].get(@intCast(slot + 1), .total_gold), tl.frames[15].get(@intCast(slot + 1), .total_gold), id, slot,
            });
        }
    }

    var champs: std.ArrayList(core.statsfile.Champion) = .empty;
    for ([_]u32{ 10, 60, 99 }) |id| try champs.append(arena, .{ .id = id, .name = "x" });
    var b: core.statsfile.Builder = try .init(arena, champs.items);
    var aw: std.Io.Writer.Allocating = .init(arena);
    try b.write(&aw.writer, "16.20");
    const st: Stats = try .parse(arena, aw.written());

    const both = try tally(gpa, std.testing.io, db, &st, &.{ &.{"EUW1"}, &.{ "KR", "EUW1" } });
    defer freeTallies(gpa, both);
    try testing.expectEqualDeep(both[0].bins, both[1].bins);
    const t = both[0];
    try testing.expectEqual(2, t.players);
    const a = t.bins[st.index(10).?];
    try testing.expectEqual(Bin{ .games = 5, .wins = 5, .gold_games = 1, .gold_sum = a[0].gold_sum }, a[0]);
    try testing.expectEqual(2, a[1].games);
    const f = tl.frames[gold_minute];
    const want = f.get(1, .total_gold) - f.get(6, .total_gold);
    try testing.expectEqual(want, a[0].gold_sum);
    const opp = t.bins[st.index(60).?];
    try testing.expectEqual(-want, opp[0].gold_sum);
    try testing.expectEqual(0, opp[0].wins);
    try testing.expectEqual(0, t.bins[st.index(99).?][0].games); // 'other' not crawled

    const l = try build(arena, &t, &st, .{});
    try testing.expectEqual(2, l.champions.len);
    var out: std.Io.Writer.Allocating = .init(arena);
    try writeJson(&out.writer, l);
    const parsed = try std.json.parseFromSliceLeaky(std.json.Value, arena, out.written(), .{});
    try testing.expectEqual(4, parsed.object.get("bins").?.array.items.len);
}
