//! `meiolol stats`: the model file (core.statsfile) from the matches in meiolol.db.

const std = @import("std");
const store = @import("store");
const core = @import("core");
const statsfile = core.statsfile;
const partials = @import("partials.zig");
const fitted = @import("fitted.zig");
const additive = @import("additive.zig");
const Role = core.Role;
const Counts = statsfile.Counts;
const curvesfile = core.curvesfile;

const log = std.log.scoped(.stats);

pub const ranked_solo = 420;

pub const Summary = struct {
    games: u32,
    /// Games on the chosen patches left out: missing or repeated positions, unknown teams
    skipped: u32,
    by_patch: PatchGames = .{},
};

/// Games per patch (patchKey) in the order met; past `cap` patches, in Summary.games only
pub const PatchGames = struct {
    keys: [cap]u32 = @splat(0),
    games: [cap]u32 = @splat(0),
    len: u8 = 0,

    pub const cap = 8;

    fn add(p: *PatchGames, key: u32) void {
        for (p.keys[0..p.len], p.games[0..p.len]) |k, *n| if (k == key) {
            n.* += 1;
            return;
        };
        if (p.len == cap) return;
        p.keys[p.len] = key;
        p.games[p.len] = 1;
        p.len += 1;
    }
};

/// Every ranked solo game on `chosen` patches and `platforms` (Riot ids: EUW1, KR; no
/// remakes, a winner, all ten positions) into a builder made from the champions table.
/// Caller owns the builder.
pub fn build(gpa: std.mem.Allocator, db: store.Db, chosen: []const []const u8, platforms: []const []const u8) !Built {
    return buildSince(gpa, db, null, chosen, platforms, 0, .none);
}

pub const Built = struct {
    builder: statsfile.Builder,
    summary: Summary,
};

/// The draft model a stats file carries (fitted.zig): none (version 1), additive v2, or
/// v2 with pair cells that borrow strength (A4; what the site and app score with since
/// 24 Oct, data-and-model.md DM1)
pub const Fit = enum { none, v2, pair_prior };

/// As build, games started from `since_ms` (Unix ms) only, from the views partials when
/// `from` is given (champions still from db), with the draft model `fit` fitted on them
pub fn buildSince(
    gpa: std.mem.Allocator,
    db: store.Db,
    from: ?*const partials.Store,
    chosen: []const []const u8,
    platforms: []const []const u8,
    since_ms: i64,
    fit: Fit,
) !Built {
    const champs = try champions(gpa, db);
    defer freeChampions(gpa, champs);
    var b: statsfile.Builder = try .init(gpa, champs);
    errdefer b.deinit();
    var played: fitted.Games = .{ .gpa = gpa };
    defer played.deinit();
    const classes = if (fit == .pair_prior) try kitClasses(gpa, db) else null;
    defer if (classes) |x| gpa.free(x);
    played.classes = classes;
    const sink: BuilderSink = .{ .b = &b, .games = if (fit != .none) &played else null };
    const summary = if (from) |games|
        try scanFrom(gpa, games, chosen, platforms, since_ms, sink)
    else
        try scan(gpa, null, db, chosen, platforms, since_ms, sink);
    try played.attachTo(&b);
    return .{ .builder = b, .summary = summary };
}

const BuilderSink = struct {
    b: *statsfile.Builder,
    games: ?*fitted.Games = null,

    fn add(s: BuilderSink, r: Row) !void {
        s.b.addGame(r.teams, r.winner);
        if (s.games) |g| try g.add(r.teams, r.winner, r.platform, r.duration_s);
    }
};

/// A valid game from `scan`
pub const Row = struct {
    /// matchId hashed (matchKey), to join other per-match data
    id: u64,
    /// Unix ms
    start: i64,
    /// See patchKey
    patch: u32,
    /// Index into the `platforms` given to scan
    platform: u8,
    teams: [2][5]u32,
    winner: u1,
    duration_s: u32 = 0,
    /// As the curves': the median visible tier of its players, null under 5 known
    bracket: ?curvesfile.Bracket = null,
};

pub fn matchKey(match_id: []const u8) u64 {
    return std.hash.Wyhash.hash(0, match_id);
}

fn platformIndex(platforms: []const []const u8, platform: []const u8) u8 {
    for (platforms, 0..) |p, i| if (std.mem.eql(u8, p, platform)) return @intCast(i);
    return 0;
}

/// Every platform of every set as one JSON array (for json_each), in `gpa`: one query
/// serves several platform sets
pub fn setsJson(gpa: std.mem.Allocator, sets: []const []const []const u8) ![]u8 {
    var all: std.ArrayList([]const u8) = .empty;
    defer all.deinit(gpa);
    for (sets) |s| try all.appendSlice(gpa, s);
    return std.json.Stringify.valueAlloc(gpa, all.items, .{});
}

/// Bit i set when `platform` is in sets[i]
pub fn setsWith(sets: []const []const []const u8, platform: []const u8) u32 {
    var mask: u32 = 0;
    for (sets, 0..) |s, i| {
        for (s) |p| {
            if (std.mem.eql(u8, p, platform)) mask |= @as(u32, 1) << @intCast(i);
        }
    }
    return mask;
}

/// The games a tally counts: on these platforms, started from since_ms (Riot ms; 0: any),
/// on these patches (empty: any). The site's views as lolalytics' filters: a region over
/// the last 30 days or the current patch
pub const Slice = struct {
    platforms: []const []const u8,
    since_ms: i64 = 0,
    patches: []const []const u8 = &.{},

    /// Every slice's platforms as one JSON array, for json_each
    pub fn platformsJson(gpa: std.mem.Allocator, slices: []const Slice) ![]u8 {
        var all: std.ArrayList([]const u8) = .empty;
        defer all.deinit(gpa);
        for (slices) |s| try all.appendSlice(gpa, s.platforms);
        return std.json.Stringify.valueAlloc(gpa, all.items, .{});
    }

    /// Bit i set when slices[i] counts games on `platform`
    pub fn platformMask(slices: []const Slice, platform: []const u8) u32 {
        var mask: u32 = 0;
        for (slices, 0..) |s, i| {
            for (s.platforms) |p| {
                if (std.mem.eql(u8, p, platform)) mask |= @as(u32, 1) << @intCast(i);
            }
        }
        return mask;
    }

    /// Bit i set when slices[i] counts games on `patch`
    pub fn patchMask(slices: []const Slice, patch: []const u8) u32 {
        var mask: u32 = 0;
        for (slices, 0..) |s, i| {
            const in = s.patches.len == 0 or for (s.patches) |p| {
                if (std.mem.eql(u8, p, patch)) break true;
            } else false;
            if (in) mask |= @as(u32, 1) << @intCast(i);
        }
        return mask;
    }

    /// Bit i set when slices[i] counts a game started at `start_ms`
    pub fn sinceMask(slices: []const Slice, start_ms: i64) u32 {
        var mask: u32 = 0;
        for (slices, 0..) |s, i| {
            if (start_ms >= s.since_ms) mask |= @as(u32, 1) << @intCast(i);
        }
        return mask;
    }

    /// Bit i set when slices[i] counts the game
    pub fn of(slices: []const Slice, platform: []const u8, start_ms: i64, patch: []const u8) u32 {
        return platformMask(slices, platform) & sinceMask(slices, start_ms) & patchMask(slices, patch);
    }
};

/// "16.20" as 16020, for ordering and comparing patches cheaply. u16 parts, as
/// crawl.Patches.code: a match stored from a bogus gameVersion can't overflow it
pub fn patchKey(patch: []const u8) u32 {
    var it = std.mem.splitScalar(u8, patch, '.');
    const major = std.fmt.parseInt(u16, it.next() orelse "", 10) catch 0;
    const minor = std.fmt.parseInt(u16, it.next() orelse "", 10) catch 0;
    return @as(u32, major) * 1000 + minor;
}

/// Every valid game (as for `build`) started from `since_ms` (0: any) to
/// `sink.add(Row)`, in match id order. With `io`, each game's participants are read
/// ahead (store.Ahead): for passes over most of the table, whose pages lie scattered
/// on disk
pub fn scan(
    gpa: std.mem.Allocator,
    io: ?std.Io,
    db: store.Db,
    chosen: []const []const u8,
    platforms: []const []const u8,
    since_ms: i64,
    sink: anytype,
) !Summary {
    const patch_json = try std.json.Stringify.valueAlloc(gpa, chosen, .{});
    defer gpa.free(patch_json);
    const platform_json = try std.json.Stringify.valueAlloc(gpa, platforms, .{});
    defer gpa.free(platform_json);
    // Matches sorted alone, then each one's participants by primary key: sorting the
    // joined rows sorted 10 a match (2x the time). The outer ORDER BY costs nothing, as
    // SQLite knows m is in order, and keeps that order guaranteed
    const pick =
        \\  WHERE m.patch IN (SELECT value FROM json_each(?)) AND m.queue_id = ?
        \\    AND m.platform IN (SELECT value FROM json_each(?))
        \\    AND m.remake = 0 AND m.winning_team IS NOT NULL AND m.game_start >= ?
        \\  ORDER BY match_id
    ;
    const args = .{ patch_json, ranked_solo, platform_json, since_ms };
    var q = try db.prepare(
        \\WITH m AS MATERIALIZED (
        \\  SELECT match_id, winning_team, game_start, patch, platform, duration_s FROM matches m
        \\
    ++ pick ++
        \\
        \\)
        \\SELECT m.match_id, m.winning_team, m.game_start, m.patch, m.platform, m.duration_s,
        \\  p.team_id, p.position, p.champion_id, p.tier
        \\FROM m CROSS JOIN participants p USING (match_id)
        \\ORDER BY m.match_id
    );
    defer q.deinit();
    try q.bind(args);
    const ahead: ?*store.Ahead = if (io) |i| try .start(gpa, i, db, .{
        .list = "SELECT match_id, NULL FROM matches m\n" ++ pick,
        .reads = &.{"SELECT slot FROM participants WHERE match_id = ?1"},
    }, args) else null;
    defer if (ahead) |a| a.stop();

    var summary: Summary = .{ .games = 0, .skipped = 0 };
    var game: Game = .{};
    var current: std.ArrayList(u8) = .empty;
    defer current.deinit(gpa);
    while (try q.step()) {
        const r = q.row(struct {
            match_id: []const u8,
            winning_team: i64,
            game_start: i64,
            patch: []const u8,
            platform: []const u8,
            duration_s: i64,
            team_id: i64,
            position: []const u8,
            champion_id: i64,
            tier: ?[]const u8,
        });
        if (!std.mem.eql(u8, r.match_id, current.items)) {
            if (ahead) |a| a.next();
            try game.finish(sink, &summary);
            current.clearRetainingCapacity();
            try current.appendSlice(gpa, r.match_id);
            game = .{
                .id = matchKey(r.match_id),
                .winning_team = r.winning_team,
                .start = r.game_start,
                .patch = patchKey(r.patch),
                .platform = platformIndex(platforms, r.platform),
                .duration_s = @intCast(r.duration_s),
            };
        }
        game.add(r.team_id, r.position, r.champion_id, r.tier);
    }
    try game.finish(sink, &summary);
    return summary;
}

/// As scan, from the views partials: the same games in the same order
pub fn scanFrom(
    gpa: std.mem.Allocator,
    games: *const partials.Store,
    chosen: []const []const u8,
    platforms: []const []const u8,
    since_ms: i64,
    sink: anytype,
) !Summary {
    const patch_in = try games.codesIn(gpa, chosen);
    defer gpa.free(patch_in);
    const platform_in = try games.codesIn(gpa, platforms);
    defer gpa.free(platform_in);
    var summary: Summary = .{ .games = 0, .skipped = 0 };
    for (games.sorted) |g| {
        if (!patch_in[g.patch] or !platform_in[g.platform]) continue;
        const winning_team = g.winning_team orelse continue;
        if (g.start < since_ms) continue;
        var game: Game = .{
            .id = matchKey(g.id),
            .winning_team = winning_team,
            .start = g.start,
            .patch = patchKey(games.string(g.patch).?),
            .platform = platformIndex(platforms, games.string(g.platform).?),
            .duration_s = @intCast(g.duration_s),
        };
        // A NULL position reads as "" from SQLite
        for (g.players) |p| game.add(p.team, games.string(p.position) orelse "", p.champion, games.string(p.tier));
        try game.finish(sink, &summary);
    }
    return summary;
}

/// Games of `chosen` from `platforms` as scan's query picks them, without reading them
/// (scan's count also drops a game missing a player or role)
pub fn countGames(db: store.Db, chosen: []const []const u8, platforms: []const []const u8) !u64 {
    var buf: [1024]u8 = undefined;
    var fba: std.heap.FixedBufferAllocator = .init(&buf);
    const patch_json = try std.json.Stringify.valueAlloc(fba.allocator(), chosen, .{});
    const platform_json = try std.json.Stringify.valueAlloc(fba.allocator(), platforms, .{});
    var q = try db.prepare(
        \\SELECT count(*) FROM matches
        \\WHERE patch IN (SELECT value FROM json_each(?)) AND queue_id = ?
        \\  AND platform IN (SELECT value FROM json_each(?))
        \\  AND remake = 0 AND winning_team IS NOT NULL
    );
    defer q.deinit();
    try q.bind(.{ patch_json, ranked_solo, platform_json });
    _ = try q.step();
    return @intCast(q.int(0));
}

/// The champions table, by name. Free with freeChampions
pub fn champions(gpa: std.mem.Allocator, db: store.Db) ![]statsfile.Champion {
    var list: std.ArrayList(statsfile.Champion) = .empty;
    defer list.deinit(gpa);
    errdefer for (list.items) |c| gpa.free(c.name);
    var q = try db.prepare("SELECT id, name FROM champions ORDER BY name");
    defer q.deinit();
    while (try q.step()) {
        const r = q.row(struct { id: i64, name: []const u8 });
        const name = try gpa.dupe(u8, r.name);
        errdefer gpa.free(name);
        try list.append(gpa, .{ .id = @intCast(r.id), .name = name });
    }
    if (list.items.len == 0) return error.NoChampions;
    return list.toOwnedSlice(gpa);
}

/// Every champion's kit class for additive.Parents: its Data Dragon tags
pub fn kitClasses(gpa: std.mem.Allocator, db: store.Db) ![]additive.KitClass {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    var ids: std.ArrayList(u32) = .empty;
    var tags: std.ArrayList([]const u8) = .empty;
    var q = try db.prepare("SELECT id, coalesce(tags, '') FROM champions");
    defer q.deinit();
    while (try q.step()) {
        const r = q.row(struct { id: i64, tags: []const u8 });
        try ids.append(arena.allocator(), @intCast(r.id));
        try tags.append(arena.allocator(), try arena.allocator().dupe(u8, r.tags));
    }
    return additive.KitClass.fromTags(gpa, ids.items, tags.items);
}

pub fn freeChampions(gpa: std.mem.Allocator, champs: []const statsfile.Champion) void {
    for (champs) |c| gpa.free(c.name);
    gpa.free(champs);
}

/// One match's participants as they arrive from the query
const Game = struct {
    id: u64 = 0,
    winning_team: i64 = 0,
    start: i64 = 0,
    patch: u32 = 0,
    platform: u8 = 0,
    duration_s: u32 = 0,
    teams: [2][5]u32 = @splat(@splat(0)),
    rows: u8 = 0,
    bad: bool = false,
    /// curvesfile.tierRank of the players with a known tier
    ranks: [10]usize = undefined,
    n_ranks: u8 = 0,

    fn add(g: *Game, team_id: i64, position: []const u8, champion: i64, tier: ?[]const u8) void {
        g.rows += 1;
        if (curvesfile.tierRank(tier orelse "")) |rank| if (g.n_ranks < g.ranks.len) {
            g.ranks[g.n_ranks] = rank;
            g.n_ranks += 1;
        };
        const side: usize = switch (team_id) {
            100 => 0,
            200 => 1,
            else => {
                g.bad = true;
                return;
            },
        };
        const role = Role.fromLcu(position) orelse {
            g.bad = true;
            return;
        };
        const slot = &g.teams[side][@backingInt(role)];
        if (slot.* != 0 or champion <= 0) {
            g.bad = true;
            return;
        }
        slot.* = @intCast(champion);
    }

    fn bracket(g: *const Game) ?curvesfile.Bracket {
        var ranks = g.ranks;
        const rank = curvesfile.medianRank(ranks[0..g.n_ranks]) orelse return null;
        return .ofRank(rank);
    }

    fn finish(g: *const Game, sink: anytype, summary: *Summary) !void {
        if (g.rows == 0) return;
        const winner: ?u1 = switch (g.winning_team) {
            100 => 0,
            200 => 1,
            else => null,
        };
        if (g.bad or g.rows != 10 or winner == null) {
            summary.skipped += 1;
            return;
        }
        try sink.add(.{
            .id = g.id,
            .start = g.start,
            .patch = g.patch,
            .platform = g.platform,
            .teams = g.teams,
            .winner = winner.?,
            .duration_s = g.duration_s,
            .bracket = g.bracket(),
        });
        summary.games += 1;
        summary.by_patch.add(g.patch);
    }
};

/// Patches with ranked solo games on `platforms`, newest first ("16.20" before "16.9").
/// Per platform because a patch reaches regions on different days
pub fn patches(gpa: std.mem.Allocator, db: store.Db, platforms: []const []const u8) ![][]const u8 {
    var list: std.ArrayList([]const u8) = .empty;
    errdefer {
        for (list.items) |p| gpa.free(p);
        list.deinit(gpa);
    }
    const platform_json = try std.json.Stringify.valueAlloc(gpa, platforms, .{});
    defer gpa.free(platform_json);
    var q = try db.prepare("SELECT DISTINCT patch FROM matches WHERE queue_id = ? " ++
        "AND platform IN (SELECT value FROM json_each(?))");
    defer q.deinit();
    try q.bind(.{ ranked_solo, platform_json });
    while (try q.step()) {
        try list.ensureUnusedCapacity(gpa, 1);
        list.appendAssumeCapacity(try gpa.dupe(u8, q.bytes(0)));
    }
    sortPatches(list.items);
    return list.toOwnedSlice(gpa);
}

/// Newest first ("16.20" before "16.9")
pub fn sortPatches(list: [][]const u8) void {
    std.mem.sort([]const u8, list, {}, newerPatch);
}

fn newerPatch(_: void, a: []const u8, b: []const u8) bool {
    return patchOrder(b, a) == .lt;
}

pub fn patchOrder(a: []const u8, b: []const u8) std.math.Order {
    var ia = std.mem.splitScalar(u8, a, '.');
    var ib = std.mem.splitScalar(u8, b, '.');
    while (true) {
        const pa = ia.next() orelse return if (ib.next() == null) .eq else .lt;
        const pb = ib.next() orelse return .gt;
        const na = std.fmt.parseInt(u32, pa, 10) catch 0;
        const nb = std.fmt.parseInt(u32, pb, 10) catch 0;
        if (na != nb) return std.math.order(na, nb);
    }
}

/// "16.20" for one patch, "16.19-16.20" (oldest-newest) for several
pub fn label(buf: []u8, chosen: []const []const u8) ![]const u8 {
    var oldest = chosen[0];
    var newest = chosen[0];
    for (chosen[1..]) |p| {
        if (patchOrder(p, oldest) == .lt) oldest = p;
        if (patchOrder(p, newest) == .gt) newest = p;
    }
    if (std.mem.eql(u8, oldest, newest)) return std.mem.print(buf, "{s}", .{oldest});
    return std.mem.print(buf, "{s}-{s}", .{ oldest, newest });
}

/// Game length buckets by minute: under 20, 20 to 25, 25 to 30, 30 to 35, 35 and over.
/// Wider ones are unions (Trend.merged): the matchup page's three are 0-2, 2-4, 4-5
pub const length_edges = [_]u32{ 20, 25, 30, 35 };
pub const length_buckets = length_edges.len + 1;

pub fn lengthBucket(duration_s: u32) usize {
    var b: usize = 0;
    for (length_edges) |m| b += @intFromBool(duration_s >= 60 * m);
    return b;
}

/// Per champion role: the view's games by length (length_edges) and the games of each
/// of the last patches; per lane pair, the view's games by length. For the champion
/// page's charts and the matchup page's length chart. Champions indexed as the Stats
/// given to buildTrend
pub const Trend = struct {
    n: usize,
    /// By role, champion, length bucket
    lengths: []Counts,
    /// The same games by role, champion and rank bracket (Row.bracket), those of none left
    /// out
    brackets: []Counts,
    /// Lane opponents (same role, either side) that met, by key (laneKey) with the lower
    /// index first; wins are the lower index's
    lanes: []Lane,
    /// Newest first, at most max_patches: those with games on the view's platforms,
    /// whatever its period
    patches: []const []const u8,
    /// Games on each patch
    patch_games: []u32,
    /// By patch, role, champion
    by_patch: []Counts,
    /// UTC days (since 1970) the newest patch has games on, oldest first; at most
    /// max_days, the newest
    days: []const i32 = &.{},
    /// By day, role, champion
    by_day: []Counts = &.{},

    pub const max_patches = 6;
    pub const max_days = 28;

    pub const Lane = struct {
        key: u32,
        by: [length_buckets]Counts,

        fn order(key: u32, l: Lane) std.math.Order {
            return std.math.order(key, l.key);
        }
    };

    fn laneKey(n: usize, role: usize, lo: usize, hi: usize) u32 {
        return @intCast((role * n + lo) * n + hi);
    }

    pub fn length(t: *const Trend, r: Role, c: usize, b: usize) Counts {
        return t.lengths[(@as(usize, @backingInt(r)) * t.n + c) * length_buckets + b];
    }

    /// b: not .all
    pub fn bracket(t: *const Trend, r: Role, c: usize, b: curvesfile.Bracket) Counts {
        return t.brackets[bracketIndex(t.n, @backingInt(r), c, b)];
    }

    fn bracketIndex(n: usize, role: usize, c: usize, b: curvesfile.Bracket) usize {
        return (role * n + c) * 3 + @backingInt(b) - 1;
    }

    /// c1 against c2 in lane r by length, from c1's side; null when they never met
    pub fn lane(t: *const Trend, r: Role, c1: usize, c2: usize) ?[length_buckets]Counts {
        const key = laneKey(t.n, @backingInt(r), @min(c1, c2), @max(c1, c2));
        const i = std.sort.binarySearch(Lane, t.lanes, key, Lane.order) orelse return null;
        var by = t.lanes[i].by;
        if (c1 > c2) for (&by) |*x| {
            x.wins = x.games - x.wins;
        };
        return by;
    }

    /// Buckets `from` to `to` (exclusive) as one
    pub fn merged(by: [length_buckets]Counts, from: usize, to: usize) Counts {
        var sum: Counts = .{ .games = 0, .wins = 0 };
        for (by[from..to]) |x| {
            sum.games += x.games;
            sum.wins += x.wins;
        }
        return sum;
    }

    pub fn onPatch(t: *const Trend, p: usize, r: Role, c: usize) Counts {
        return t.by_patch[(p * Role.count + @backingInt(r)) * t.n + c];
    }

    /// d: an index into days
    pub fn onDay(t: *const Trend, d: usize, r: Role, c: usize) Counts {
        return t.by_day[(d * Role.count + @backingInt(r)) * t.n + c];
    }
};

/// The view's Trend: lengths over the games buildSince would read for `window` and
/// `since_ms`, patch counts over the newest Trend.max_patches of `all_patches` (newest
/// first, as `patches`), all from `platforms`; champions indexed as `st`. In `arena`
pub fn buildTrend(
    gpa: std.mem.Allocator,
    arena: std.mem.Allocator,
    db: store.Db,
    from: ?*const partials.Store,
    st: *const core.Stats,
    window: []const []const u8,
    all_patches: []const []const u8,
    platforms: []const []const u8,
    since_ms: i64,
) !Trend {
    const recent = all_patches[0..@min(all_patches.len, Trend.max_patches)];
    var t: Trend = .{
        .n = st.n,
        .lengths = try arena.alloc(Counts, Role.count * st.n * length_buckets),
        .brackets = try arena.alloc(Counts, Role.count * st.n * 3),
        .lanes = &.{},
        .patches = undefined,
        .patch_games = try arena.alloc(u32, recent.len),
        .by_patch = try arena.alloc(Counts, recent.len * Role.count * st.n),
    };
    const names = try arena.alloc([]const u8, recent.len);
    for (names, recent) |*name, p| name.* = try arena.dupe(u8, p);
    t.patches = names;
    @memset(t.lengths, .{ .games = 0, .wins = 0 });
    @memset(t.brackets, .{ .games = 0, .wins = 0 });
    @memset(t.patch_games, 0);
    @memset(t.by_patch, .{ .games = 0, .wins = 0 });

    var max_id: u32 = 0;
    for (st.ids) |id| max_id = @max(max_id, id);
    const index = try gpa.alloc(u16, max_id + 1);
    defer gpa.free(index);
    @memset(index, 0);
    for (st.ids, 1..) |id, i| index[id] = @intCast(i);
    var chosen: std.ArrayList([]const u8) = .empty;
    defer chosen.deinit(gpa);
    try chosen.appendSlice(gpa, recent);
    for (window) |p| {
        for (recent) |q| {
            if (std.mem.eql(u8, p, q)) break;
        } else try chosen.append(gpa, p);
    }
    const keys = try gpa.alloc(u32, window.len + recent.len);
    defer gpa.free(keys);
    for (window, keys[0..window.len]) |p, *k| k.* = patchKey(p);
    for (recent, keys[window.len..]) |p, *k| k.* = patchKey(p);

    var sink: TrendSink = .{
        .gpa = gpa,
        .t = &t,
        .index = index,
        .window = keys[0..window.len],
        .recent = keys[window.len..],
        .since_ms = since_ms,
    };
    defer sink.lanes.deinit(gpa);
    defer {
        for (sink.days.values()) |d| gpa.free(d);
        sink.days.deinit(gpa);
    }
    _ = if (from) |games|
        try scanFrom(gpa, games, chosen.items, platforms, 0, &sink)
    else
        try scan(gpa, null, db, chosen.items, platforms, 0, &sink);

    t.lanes = try arena.alloc(Trend.Lane, sink.lanes.count());
    var it = sink.lanes.iterator();
    var i: usize = 0;
    while (it.next()) |e| : (i += 1) t.lanes[i] = .{ .key = e.key_ptr.*, .by = e.value_ptr.* };
    std.mem.sort(Trend.Lane, t.lanes, {}, struct {
        fn f(_: void, a: Trend.Lane, b: Trend.Lane) bool {
            return a.key < b.key;
        }
    }.f);

    sink.days.sort(struct {
        keys: []const i32,
        pub fn lessThan(c: @This(), a: usize, b: usize) bool {
            return c.keys[a] < c.keys[b];
        }
    }{ .keys = sink.days.keys() });
    const kept = sink.days.count() - @min(sink.days.count(), Trend.max_days);
    const days = try arena.dupe(i32, sink.days.keys()[kept..]);
    t.days = days;
    t.by_day = try arena.alloc(Counts, days.len * Role.count * st.n);
    for (sink.days.values()[kept..], 0..) |d, k| @memcpy(t.by_day[k * d.len ..][0..d.len], d);
    return t;
}

const TrendSink = struct {
    gpa: std.mem.Allocator,
    t: *Trend,
    /// Champion id to its index + 1; 0 for one the stats don't know
    index: []const u16,
    window: []const u32,
    recent: []const u32,
    since_ms: i64,
    lanes: std.AutoHashMapUnmanaged(u32, [length_buckets]Counts) = .empty,
    /// The newest patch's games by UTC day: by role, champion
    days: std.AutoArrayHashMapUnmanaged(i32, []Counts) = .empty,

    fn add(s: *TrendSink, r: Row) !void {
        const t = s.t;
        var cs: [2][Role.count]?usize = undefined;
        for (r.teams, &cs) |team, *out| {
            for (team, out) |id, *c| c.* = if (id < s.index.len and s.index[id] > 0) s.index[id] - 1 else null;
        }
        if (std.mem.findScalar(u32, s.recent, r.patch)) |p| {
            t.patch_games[p] += 1;
            for (cs, 0..) |team, side| for (team, 0..) |c, role| {
                add1(&t.by_patch[(p * Role.count + role) * t.n + (c orelse continue)], side == r.winner);
            };
            if (p == 0) {
                const e = try s.days.getOrPut(s.gpa, @intCast(@divFloor(r.start, std.time.ms_per_day)));
                if (!e.found_existing) {
                    e.value_ptr.* = s.gpa.alloc(Counts, Role.count * t.n) catch |err| {
                        _ = s.days.pop();
                        return err;
                    };
                    @memset(e.value_ptr.*, .{ .games = 0, .wins = 0 });
                }
                for (cs, 0..) |team, side| for (team, 0..) |c, role| {
                    add1(&e.value_ptr.*[role * t.n + (c orelse continue)], side == r.winner);
                };
            }
        }
        if (r.start < s.since_ms or std.mem.findScalar(u32, s.window, r.patch) == null) return;
        const b = lengthBucket(r.duration_s);
        for (cs, 0..) |team, side| for (team, 0..) |maybe, role| {
            const c = maybe orelse continue;
            add1(&t.lengths[(role * t.n + c) * length_buckets + b], side == r.winner);
            if (r.bracket) |x| add1(&t.brackets[Trend.bracketIndex(t.n, role, c, x)], side == r.winner);
        };
        for (cs[0], cs[1], 0..) |a, z, role| {
            const c0 = a orelse continue;
            const c1 = z orelse continue;
            const key = Trend.laneKey(t.n, role, @min(c0, c1), @max(c0, c1));
            const e = try s.lanes.getOrPut(s.gpa, key);
            if (!e.found_existing) e.value_ptr.* = @splat(.{ .games = 0, .wins = 0 });
            add1(&e.value_ptr[b], (r.winner == 0) == (c0 <= c1));
        }
    }

    fn add1(c: *Counts, won: bool) void {
        c.games += 1;
        c.wins += @intFromBool(won);
    }
};

const testing = std.testing;

fn testDb() !store.Db {
    const db = try store.schema.memory();
    errdefer db.close();
    try db.exec(
        \\INSERT INTO champions VALUES
        \\  (1,'A','A','',''), (2,'B','B','',''), (3,'C','C','',''), (4,'D','D','',''),
        \\  (5,'E','E','',''), (6,'F','F','',''), (7,'G','G','',''), (8,'H','H','',''),
        \\  (9,'I','I','',''), (10,'J','J','','');
    );
    return db;
}

fn addMatch(db: store.Db, id: []const u8, patch: []const u8, queue: i64, winner: ?i64, remake: bool, positions: [10][]const u8) !void {
    const platform = id[0..std.mem.findScalar(u8, id, '_').?];
    try db.run("INSERT INTO matches VALUES (?,'t',?,?,?,'',0,1800,?,?)", .{
        id, platform, queue, patch, winner, remake,
    });
    for (positions, 0..) |pos, slot| {
        const team: i64 = if (slot < 5) 100 else 200;
        try db.run(
            "INSERT INTO participants (match_id, slot, team_id, champion_id, position, win) VALUES (?,?,?,?,?,?)",
            .{ id, slot, team, slot + 1, pos, winner == team },
        );
    }
}

const euw: []const []const u8 = &.{"EUW1"};

const roles_ok = [10][]const u8{ "TOP", "JUNGLE", "MIDDLE", "BOTTOM", "UTILITY", "UTILITY", "BOTTOM", "MIDDLE", "JUNGLE", "TOP" };

test "build counts valid games only" {
    const gpa = testing.allocator;
    const db = try testDb();
    defer db.close();
    try addMatch(db, "EUW1_1", "16.20", 420, 100, false, roles_ok);
    try addMatch(db, "EUW1_2", "16.20", 420, 200, false, roles_ok);
    try addMatch(db, "EUW1_3", "16.20", 420, 100, true, roles_ok); // remake
    try addMatch(db, "EUW1_4", "16.20", 440, 100, false, roles_ok); // flex
    try addMatch(db, "EUW1_5", "16.19", 420, 100, false, roles_ok); // other patch
    var dup = roles_ok;
    dup[1] = "TOP";
    try addMatch(db, "EUW1_6", "16.20", 420, 100, false, dup);
    var missing = roles_ok;
    missing[9] = "";
    try addMatch(db, "EUW1_7", "16.20", 420, 100, false, missing);

    var r = try build(gpa, db, &.{"16.20"}, euw);
    defer r.builder.deinit();
    try testing.expectEqual(2, r.summary.games);
    try testing.expectEqual(2, r.summary.skipped);
    try testing.expectEqualSlices(u32, &.{16020}, r.summary.by_patch.keys[0..r.summary.by_patch.len]);
    try testing.expectEqualSlices(u32, &.{2}, r.summary.by_patch.games[0..r.summary.by_patch.len]);

    var aw: std.Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();
    try r.builder.write(&aw.writer, "16.20");
    var s: core.Stats = try .parse(gpa, aw.written());
    defer s.deinit(gpa);
    const a = s.index(1).?;
    const j = s.index(10).?;
    try testing.expectEqual(statsfile.Counts{ .games = 2, .wins = 1 }, s.champRole(.top, a));
    try testing.expectEqual(statsfile.Counts{ .games = 2, .wins = 1 }, s.enemy(.top, .top, a, j));
    try testing.expectEqual(statsfile.Counts{ .games = 0, .wins = 0 }, s.champRole(.jungle, a));

    var both = try build(gpa, db, &.{ "16.19", "16.20" }, euw);
    defer both.builder.deinit();
    try testing.expectEqual(3, both.summary.games);

    try addMatch(db, "KR_1", "16.20", 420, 100, false, roles_ok);
    var kr = try build(gpa, db, &.{"16.20"}, &.{"KR"});
    defer kr.builder.deinit();
    try testing.expectEqual(1, kr.summary.games);
}

test patchKey {
    try testing.expectEqual(16020, patchKey("16.20"));
    try testing.expectEqual(16000, patchKey("16"));
    // A bogus gameVersion is stored as its patch: no overflow
    try testing.expectEqual(1, patchKey("99999999.1"));
}

test "patch order and label" {
    const gpa = testing.allocator;
    const db = try testDb();
    defer db.close();
    try addMatch(db, "EUW1_1", "16.9", 420, 100, false, roles_ok);
    try addMatch(db, "EUW1_2", "16.20", 420, 100, false, roles_ok);
    try addMatch(db, "EUW1_3", "16.19", 420, 100, false, roles_ok);
    try addMatch(db, "KR_1", "16.21", 420, 100, false, roles_ok);
    const ps = try patches(gpa, db, euw);
    defer {
        for (ps) |p| gpa.free(p);
        gpa.free(ps);
    }
    try testing.expectEqual(3, ps.len);
    try testing.expectEqualStrings("16.20", ps[0]);
    try testing.expectEqualStrings("16.9", ps[2]);
    var buf: [statsfile.patch_len]u8 = undefined;
    try testing.expectEqualStrings("16.9-16.20", try label(&buf, &.{ "16.20", "16.9", "16.19" }));
    try testing.expectEqualStrings("16.20", try label(&buf, &.{"16.20"}));
}

test "patches frees what it read when an allocation fails" {
    const db = try testDb();
    defer db.close();
    try addMatch(db, "EUW1_1", "16.9", 420, 100, false, roles_ok);
    try addMatch(db, "EUW1_2", "16.20", 420, 100, false, roles_ok);
    try testing.checkAllAllocationFailures(testing.allocator, struct {
        fn f(gpa: std.mem.Allocator, d: store.Db) !void {
            const ps = try patches(gpa, d, euw);
            for (ps) |p| gpa.free(p);
            gpa.free(ps);
        }
    }.f, .{db});
}

test "slice masks: platform, start and patch" {
    const slices = [_]Slice{
        .{ .platforms = &.{"EUW1"} },
        .{ .platforms = &.{ "EUW1", "KR" }, .since_ms = 1000 },
        .{ .platforms = &.{"KR"}, .patches = &.{"16.21"} },
    };
    try testing.expectEqual(0b011, Slice.of(&slices, "EUW1", 1000, "16.20"));
    try testing.expectEqual(0b001, Slice.of(&slices, "EUW1", 999, "16.21"));
    try testing.expectEqual(0b110, Slice.of(&slices, "KR", 2000, "16.21"));
    try testing.expectEqual(0b000, Slice.of(&slices, "NA1", 2000, "16.21"));
}

test "trend: lengths in the view's window, patch counts over the newest patches" {
    const gpa = testing.allocator;
    const db = try testDb();
    defer db.close();
    const timed = struct {
        fn f(d: store.Db, id: []const u8, patch: []const u8, winner: i64, start: i64, duration_s: i64) !void {
            try addMatch(d, id, patch, 420, winner, false, roles_ok);
            try d.run("UPDATE matches SET game_start = ?, duration_s = ? WHERE match_id = ?", .{ start, duration_s, id });
        }
    }.f;
    try timed(db, "EUW1_1", "16.20", 100, 2000, 1000);
    try timed(db, "EUW1_2", "16.20", 200, 2000, 1900);
    try timed(db, "EUW1_3", "16.20", 100, 500, 1500); // before since: patch counts only
    try timed(db, "EUW1_4", "16.19", 100, 2000, 2400); // outside the window
    // 1: six known, the upper middle Platinum: Gold-Emerald. 2: four known, no bracket.
    // 3: before since
    try db.exec(
        \\UPDATE participants SET tier = CASE WHEN slot < 3 THEN 'SILVER' ELSE 'PLATINUM' END
        \\  WHERE match_id = 'EUW1_1' AND slot < 6;
        \\UPDATE participants SET tier = 'DIAMOND' WHERE match_id = 'EUW1_2' AND slot < 4;
        \\UPDATE participants SET tier = 'DIAMOND' WHERE match_id = 'EUW1_3';
    );
    var built = try build(gpa, db, &.{ "16.19", "16.20" }, euw);
    defer built.builder.deinit();
    var aw: std.Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();
    try built.builder.write(&aw.writer, "16.20");
    var s: core.Stats = try .parse(gpa, aw.written());
    defer s.deinit(gpa);
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    const t = try buildTrend(gpa, arena.allocator(), db, null, &s, &.{"16.20"}, &.{ "16.20", "16.19" }, euw, 1000);

    const a = s.index(1).?;
    const j = s.index(10).?;
    const c = struct {
        fn f(games: u32, wins: u32) Counts {
            return .{ .games = games, .wins = wins };
        }
    }.f;
    try testing.expectEqual(c(1, 1), t.length(.top, a, 0));
    try testing.expectEqual(c(0, 0), t.length(.top, a, 2));
    try testing.expectEqual(c(1, 0), t.length(.top, a, 3));
    try testing.expectEqual(c(1, 1), t.lane(.top, a, j).?[0]);
    try testing.expectEqual(c(1, 1), t.lane(.top, j, a).?[3]);
    try testing.expectEqual(c(2, 1), Trend.merged(t.lane(.top, a, j).?, 0, length_buckets));
    try testing.expectEqual(null, t.lane(.top, a, s.index(2).?));
    try testing.expectEqual(2, t.patches.len);
    try testing.expectEqualStrings("16.19", t.patches[1]);
    try testing.expectEqualSlices(u32, &.{ 3, 1 }, t.patch_games);
    try testing.expectEqual(c(3, 2), t.onPatch(0, .top, a));
    try testing.expectEqual(c(1, 1), t.onPatch(1, .top, a));
    try testing.expectEqual(c(1, 0), t.onPatch(1, .top, j));
    try testing.expectEqual(c(1, 1), t.bracket(.top, a, .mid));
    try testing.expectEqual(c(1, 0), t.bracket(.top, j, .mid));
    try testing.expectEqual(c(0, 0), t.bracket(.top, a, .low));
    try testing.expectEqual(c(0, 0), t.bracket(.top, a, .high));
    // Starts 2000, 2000, 500 ms: one day
    try testing.expectEqualSlices(i32, &.{0}, t.days);
    try testing.expectEqual(c(3, 2), t.onDay(0, .top, a));
}

test "trend: the newest patch by day, oldest first, the newest max_days kept" {
    const gpa = testing.allocator;
    const db = try testDb();
    defer db.close();
    const day = std.time.ms_per_day;
    for (0..Trend.max_days + 2) |i| {
        var id: [16]u8 = undefined;
        const m = try std.fmt.bufPrint(&id, "EUW1_{d}", .{i + 1});
        try addMatch(db, m, "16.20", 420, if (i % 2 == 0) 100 else 200, false, roles_ok);
        try db.run("UPDATE matches SET game_start = ? WHERE match_id = ?", .{ @as(i64, @intCast((40 - i) * day)), m });
    }
    try addMatch(db, "EUW1_99", "16.19", 420, 100, false, roles_ok);
    var built = try build(gpa, db, &.{ "16.19", "16.20" }, euw);
    defer built.builder.deinit();
    var aw: std.Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();
    try built.builder.write(&aw.writer, "16.20");
    var s: core.Stats = try .parse(gpa, aw.written());
    defer s.deinit(gpa);
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    const t = try buildTrend(gpa, arena.allocator(), db, null, &s, &.{"16.20"}, &.{ "16.20", "16.19" }, euw, 0);
    try testing.expectEqual(Trend.max_days, t.days.len);
    try testing.expectEqual(@as(i32, 13), t.days[0]);
    try testing.expectEqual(@as(i32, 40), t.days[t.days.len - 1]);
    const a = s.index(1).?;
    // Day 40: game 1, blue won; day 39: game 2, red won
    try testing.expectEqual(Counts{ .games = 1, .wins = 1 }, t.onDay(t.days.len - 1, .top, a));
    try testing.expectEqual(Counts{ .games = 1, .wins = 0 }, t.onDay(t.days.len - 2, .top, a));
}

test lengthBucket {
    try testing.expectEqual(0, lengthBucket(0));
    try testing.expectEqual(0, lengthBucket(20 * 60 - 1));
    try testing.expectEqual(1, lengthBucket(20 * 60));
    try testing.expectEqual(4, lengthBucket(35 * 60));
}
