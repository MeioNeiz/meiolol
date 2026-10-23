//! `meiolol stats`: the model file (core.statsfile) from the matches in meiolol.db.

const std = @import("std");
const store = @import("store");
const core = @import("core");
const statsfile = core.statsfile;
const partials = @import("partials.zig");
const fitted = @import("fitted.zig");
const Role = core.Role;

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
    return buildSince(gpa, db, null, chosen, platforms, 0, false);
}

pub const Built = struct {
    builder: statsfile.Builder,
    summary: Summary,
};

/// As build, games started from `since_ms` (Unix ms) only, from the views partials when
/// `from` is given (champions still from db); `fit`: with the draft model fitted on them
/// (fitted.zig), what the site and app score with
pub fn buildSince(
    gpa: std.mem.Allocator,
    db: store.Db,
    from: ?*const partials.Store,
    chosen: []const []const u8,
    platforms: []const []const u8,
    since_ms: i64,
    fit: bool,
) !Built {
    const champs = try champions(gpa, db);
    defer freeChampions(gpa, champs);
    var b: statsfile.Builder = try .init(gpa, champs);
    errdefer b.deinit();
    var played: fitted.Games = .{ .gpa = gpa };
    defer played.deinit();
    const sink: BuilderSink = .{ .b = &b, .games = if (fit) &played else null };
    const summary = if (from) |games|
        try scanFrom(gpa, games, chosen, platforms, since_ms, sink)
    else
        try scan(gpa, db, chosen, platforms, since_ms, sink);
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

/// "16.20" as 16020, for ordering and comparing patches cheaply
pub fn patchKey(patch: []const u8) u32 {
    var it = std.mem.splitScalar(u8, patch, '.');
    const major = std.fmt.parseInt(u32, it.next() orelse "", 10) catch 0;
    const minor = std.fmt.parseInt(u32, it.next() orelse "", 10) catch 0;
    return major * 1000 + minor;
}

/// Every valid game (as for `build`) started from `since_ms` (0: any) to
/// `sink.add(Row)`, in match id order
pub fn scan(
    gpa: std.mem.Allocator,
    db: store.Db,
    chosen: []const []const u8,
    platforms: []const []const u8,
    since_ms: i64,
    sink: anytype,
) !Summary {
    return scanWith(gpa, null, db, chosen, platforms, since_ms, sink);
}

/// As scan, reading each game's participants ahead (store.Ahead): for passes over most
/// of the table, whose pages lie scattered on disk
pub fn scanAhead(
    gpa: std.mem.Allocator,
    io: std.Io,
    db: store.Db,
    chosen: []const []const u8,
    platforms: []const []const u8,
    since_ms: i64,
    sink: anytype,
) !Summary {
    return scanWith(gpa, io, db, chosen, platforms, since_ms, sink);
}

fn scanWith(
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
        \\  p.team_id, p.position, p.champion_id
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
        game.add(r.team_id, r.position, r.champion_id);
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
        for (g.players) |p| game.add(p.team, games.string(p.position) orelse "", p.champion);
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

    fn add(g: *Game, team_id: i64, position: []const u8, champion: i64) void {
        g.rows += 1;
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
