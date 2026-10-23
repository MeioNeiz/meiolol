//! Champion page filters: per champion, games, wins and gold at 14 against the lane
//! opponent, split by region, the player's rank, patch, role and opponent, as one JSON
//! file (data/filters/<slug>.json), plus data/filters.json with the role totals every
//! champion shares (for pick rates). The page's filter bar (static/filters.js) sums the
//! slices picked. Counts add up, so any mix of filters needs neither a server nor a page
//! per combination. Lane curve estimates don't add up: each view's are listed as they
//! are, for the filters that match a view

const std = @import("std");
const store = @import("store");
const core = @import("core");
const root = @import("root.zig");
const html = @import("html.zig");
const matchup = @import("matchup.zig");
const stats = @import("../stats.zig");
const par = @import("../par.zig");
const partials = @import("../partials.zig");

const Role = core.Role;
const Bracket = core.curvesfile.Bracket;
const Writer = std.Io.Writer;

/// Ladder tiers, lowest first; a player off the ladder when the game was stored (tier
/// NULL) gets index tiers.len, counted only under "All (Platinum+ games)"
pub const tiers = [_][]const u8{
    "IRON", "BRONZE", "SILVER", "GOLD", "PLATINUM", "EMERALD", "DIAMOND", "MASTER", "GRANDMASTER", "CHALLENGER",
};
/// The Rank filter's lowest option, Platinum: the tier the crawl samples from
pub const lowest_offered = 4;

/// Rank filters a curves bracket matches: all ranks, and Diamond+ (the high bracket)
const curve_ranks = [_]struct { Bracket, []const u8 }{ .{ .all, "" }, .{ .high, "6" } };

comptime {
    std.debug.assert(std.mem.eql(u8, tiers[6], "DIAMOND") and Bracket.ofRank(6) == .high and Bracket.ofRank(5) != .high);
    std.debug.assert(std.mem.eql(u8, tiers[lowest_offered], "PLATINUM"));
}

/// Where the games of a slice were played and when
const Slice = struct {
    platform: u8,
    patch: u8,
    /// Started within the 30-day window (the rest is the current patch from before it)
    recent: bool,
};

const Key = struct {
    slice: Slice,
    tier: u8,
    role: Role,
    opponent: u16,
};

const Cell = struct {
    games: u32 = 0,
    wins: u32 = 0,
    /// Games with both players' gold at 14 and a frame after it (as learning.goldMap),
    /// the difference's sum and sum of squares, for its mean and spread
    gold_n: u32 = 0,
    gold_sum: i64 = 0,
    gold_sq: i64 = 0,
};

const Cells = std.AutoArrayHashMapUnmanaged(Key, Cell);

/// Players in a role, of every champion: pick rates' denominators
const SlotKey = struct { slice: Slice, tier: u8, role: Role };
const Slots = std.AutoArrayHashMapUnmanaged(SlotKey, u32);

/// A game's rank (gameTier) where it was played: ban rates by rank, as the ban order
/// doesn't say reliably which player banned
const GameKey = struct { slice: Slice, tier: u8 };
const Games = std.AutoArrayHashMapUnmanaged(GameKey, u32);
const BanKey = struct { game: GameKey, champion: u32 };
const Bans = std.AutoArrayHashMapUnmanaged(BanKey, u32);

const Player = struct {
    team: u1,
    role: Role,
    champion: u16,
    tier: u8,
    gold14: ?i64,
};

pub const Made = struct {
    files: []const root.File = &.{},
    /// Patches with games, newest first: the period choices
    patches: []const []const u8 = &.{},
    /// Of the patch views
    current: []const []const u8 = &.{},
};

/// The games' matches; make reads each one's players and bans by primary key. A join
/// ordered by match_id walks every match ever stored: with +match_id the start and patch
/// indexes find the matches and only those are sorted. The order fixes the first-seen
/// order of patches and the maps, so the files' byte order
const games_sql =
    \\SELECT match_id, winning_team, game_start, patch, platform
    \\FROM matches
    \\WHERE queue_id = ? AND platform IN (SELECT value FROM json_each(?))
    \\  AND remake = 0 AND winning_team IS NOT NULL
    \\  AND (game_start >= ? OR patch IN (SELECT value FROM json_each(?)))
    \\ORDER BY +match_id
;

/// Contiguous runs of the games counted at once, each on its own connection: the walk
/// waits on the box's disk (cold B-tree pages one at a time), not its CPUs
const runs = 4;

const Match = struct {
    id: []const u8,
    winner: i64,
    start: i64,
    patch: []const u8,
    platform: []const u8,
    /// Its players and bans, from the views partials; null: read from db
    game: ?*const partials.Game = null,
};

/// What a run of games adds up to; its patch indexes are its own, in the order it met
/// them, until merged
const Run = struct {
    arena: std.heap.ArenaAllocator,
    cells: []Cells = &.{},
    slots: Slots = .empty,
    games: Games = .empty,
    bans: Bans = .empty,
    patches: std.ArrayList([]const u8) = .empty,
};

const Counting = struct {
    gpa: std.mem.Allocator,
    /// Null: every match has its game (partials)
    db: ?store.Db,
    strings: ?*const partials.Store,
    /// Each run on its own connection; false for an in-memory db, whose runs go in turn
    /// on its one
    siblings: bool,
    matches: []const Match,
    runs: []Run,
    index_of: []const ?u16,
    champs: usize,
    since_ms: i64,
    all_platforms: []const []const u8,

    fn count(c: *const Counting, i: usize) !void {
        const run = &c.runs[i];
        const lo = c.matches.len * i / c.runs.len;
        const hi = c.matches.len * (i + 1) / c.runs.len;
        const matches = c.matches[lo..hi];
        run.cells = try run.arena.allocator().alloc(Cells, c.champs);
        @memset(run.cells, .empty);
        const db = c.db orelse return countGames(run, c.strings.?, matches, c.index_of, c.since_ms, c.all_platforms);
        const own = if (c.siblings) (try store.schema.openSibling(c.gpa, db)).? else db;
        defer if (c.siblings) own.close();
        try countRun(run, own, matches, c.index_of, c.since_ms, c.all_platforms);
    }
};

/// The games of the 30-day and current-patch views on every platform, valid as for
/// stats.scan (ten players, one per team and role, a winner), for every champion. In
/// runs of games at once, merged in game order, so the files match a single walk's
pub fn make(site: *const root.Site, db: store.Db, opts: root.Options) !Made {
    return makeIn(site, db, opts, runs, null);
}

/// As make, the games from the views partials
pub fn makeFrom(site: *const root.Site, games: *const partials.Store, opts: root.Options) !Made {
    return makeIn(site, null, opts, runs, games);
}

fn makeIn(site: *const root.Site, maybe_db: ?store.Db, opts: root.Options, run_count: usize, games_from: ?*const partials.Store) !Made {
    const a = site.arena;
    const index_of = try a.alloc(?u16, std.math.maxInt(u16) + 1);
    @memset(index_of, null);
    for (site.champs, 0..) |ch, i| {
        if (ch.id <= std.math.maxInt(u16)) index_of[ch.id] = @intCast(i);
    }

    const platform_json = try std.json.Stringify.valueAlloc(a, opts.all_platforms, .{});
    const patch_json = try std.json.Stringify.valueAlloc(a, opts.patches, .{});
    var matches: std.ArrayList(Match) = .empty;
    if (games_from) |games| {
        // As games_sql picks them, in its order
        const platform_in = try games.codesIn(a, opts.all_platforms);
        const patch_in = try games.codesIn(a, opts.patches);
        for (games.sorted) |g| {
            if (!platform_in[g.platform]) continue;
            const winner = g.winning_team orelse continue;
            if (g.start < opts.since_ms and !patch_in[g.patch]) continue;
            try matches.append(a, .{
                .id = g.id,
                .winner = winner,
                .start = g.start,
                .patch = games.string(g.patch).?,
                .platform = games.string(g.platform).?,
                .game = g,
            });
        }
    } else {
        const db = maybe_db.?;
        var q = try db.prepare(games_sql);
        defer q.deinit();
        try q.bind(.{ stats.ranked_solo, platform_json, opts.since_ms, patch_json });
        while (try q.step()) {
            const m = q.row(struct { match_id: []const u8, winner: i64, start: i64, patch: []const u8, platform: []const u8 });
            try matches.append(a, .{
                .id = try a.dupe(u8, m.match_id),
                .winner = m.winner,
                .start = m.start,
                .patch = try a.dupe(u8, m.patch),
                .platform = try a.dupe(u8, m.platform),
            });
        }
    }

    const gpa = site.gpa;
    const parts = try a.alloc(Run, run_count);
    for (parts) |*r| r.* = .{ .arena = .init(gpa) };
    defer for (parts) |*r| r.arena.deinit();
    const counting: Counting = .{
        .gpa = gpa,
        .db = maybe_db,
        .strings = games_from,
        .siblings = if (maybe_db) |db| db.filename("main").len != 0 else true,
        .matches = matches.items,
        .runs = parts,
        .index_of = index_of,
        .champs = site.champs.len,
        .since_ms = opts.since_ms,
        .all_platforms = opts.all_platforms,
    };
    if (counting.siblings) {
        try par.each(site.io, run_count, &counting, Counting.count);
    } else for (0..run_count) |i| try counting.count(i);

    const cells = try a.alloc(Cells, site.champs.len);
    @memset(cells, .empty);
    var slots: Slots = .empty;
    var games: Games = .empty;
    var bans: Bans = .empty;
    var patches: std.ArrayList([]const u8) = .empty;
    for (parts) |*r| {
        var global: [std.math.maxInt(u8)]u8 = undefined;
        for (r.patches.items, 0..) |patch, i| global[i] = try patchIndex(a, &patches, patch);
        var git = r.games.iterator();
        while (git.next()) |e| (try games.getOrPutValue(a, inGlobal(e.key_ptr.*, &global), 0)).value_ptr.* += e.value_ptr.*;
        var sit = r.slots.iterator();
        while (sit.next()) |e| (try slots.getOrPutValue(a, inGlobal(e.key_ptr.*, &global), 0)).value_ptr.* += e.value_ptr.*;
        for (cells, r.cells) |*into, from| {
            var cit = from.iterator();
            while (cit.next()) |e| {
                const v = e.value_ptr.*;
                const to = (try into.getOrPutValue(a, inGlobal(e.key_ptr.*, &global), .{})).value_ptr;
                to.games += v.games;
                to.wins += v.wins;
                to.gold_n += v.gold_n;
                to.gold_sum += v.gold_sum;
                to.gold_sq += v.gold_sq;
            }
        }
        var bit = r.bans.iterator();
        while (bit.next()) |e| (try bans.getOrPutValue(a, inGlobal(e.key_ptr.*, &global), 0)).value_ptr.* += e.value_ptr.*;
        r.arena.deinit();
        r.arena = .init(gpa);
    }

    const sorted = try a.dupe([]const u8, patches.items);
    std.mem.sort([]const u8, sorted, {}, struct {
        fn f(_: void, x: []const u8, y: []const u8) bool {
            return stats.patchKey(x) > stats.patchKey(y);
        }
    }.f);

    const files = try a.alloc(root.File, site.champs.len + 1);
    {
        var aw: Writer.Allocating = .init(a);
        try writeMeta(&aw.writer, opts, patches.items, sorted, &slots, &games);
        files[0] = .{ .path = "data/filters.json", .data = aw.written() };
    }
    for (site.champs, cells, files[1..]) |ch, *c, *f| {
        var aw: Writer.Allocating = .init(a);
        try writeChampion(site, &aw.writer, opts, patches.items, ch, c, &bans);
        f.* = .{ .path = try a.print("data/filters/{s}.json", .{ch.slug}), .data = aw.written() };
    }
    return .{ .files = files, .patches = sorted, .current = opts.patches };
}

/// Each of `matches`' players and bans by primary key, into `run`
fn countRun(run: *Run, db: store.Db, matches: []const Match, index_of: []const ?u16, since_ms: i64, all_platforms: []const []const u8) !void {
    var pq = try db.prepare(
        \\SELECT team_id, position, champion_id, tier,
        \\  CASE WHEN gold15 IS NULL THEN NULL ELSE gold14 END
        \\FROM participants WHERE match_id = ? ORDER BY slot
    );
    defer pq.deinit();
    var bq = try db.prepare("SELECT champion_id FROM bans WHERE match_id = ? ORDER BY team_id, pick_turn");
    defer bq.deinit();

    var bans: std.ArrayList(u32) = .empty;
    defer bans.deinit(run.arena.child_allocator);
    for (matches) |m| {
        var game: Game = .{};
        try pq.bind(.{m.id});
        while (try pq.step()) {
            const r = pq.row(struct {
                team: i64,
                position: ?[]const u8,
                champion: i64,
                tier: ?[]const u8,
                gold14: ?i64,
            });
            game.add(r.team, r.position, r.champion, r.tier, r.gold14);
        }
        bans.clearRetainingCapacity();
        try bq.bind(.{m.id});
        while (try bq.step()) try bans.append(run.arena.child_allocator, bq.row(struct { champion: u32 }).champion);
        try countGame(run, &game, m, bans.items, index_of, since_ms, all_platforms);
    }
}

/// countRun from the views partials: each match's game
fn countGames(run: *Run, games: *const partials.Store, matches: []const Match, index_of: []const ?u16, since_ms: i64, all_platforms: []const []const u8) !void {
    var bans: std.ArrayList(u32) = .empty;
    defer bans.deinit(run.arena.child_allocator);
    for (matches) |m| {
        const g = m.game.?;
        var game: Game = .{};
        for (g.players) |p| {
            game.add(p.team, games.string(p.position), p.champion, games.string(p.tier), if (p.gold15) if (p.gold14) |g14| @as(i64, g14) else null else null);
        }
        bans.clearRetainingCapacity();
        for (g.bans) |b| try bans.append(run.arena.child_allocator, std.math.cast(u32, b.champion) orelse return error.Unrepresentable);
        try countGame(run, &game, m, bans.items, index_of, since_ms, all_platforms);
    }
}

/// A match's participant rows as they arrive, in slot order
const Game = struct {
    players: [10]Player = undefined,
    n: usize = 0,
    rows: usize = 0,
    bad: bool = false,

    fn add(g: *Game, team_id: i64, position: ?[]const u8, champion: i64, tier: ?[]const u8, gold14: ?i64) void {
        g.rows += 1;
        if (g.n == 10) {
            g.bad = true;
            return;
        }
        const team = side(team_id) orelse {
            g.bad = true;
            return;
        };
        const role = Role.fromLcu(position orelse "") orelse {
            g.bad = true;
            return;
        };
        if (champion <= 0 or champion > std.math.maxInt(u16)) g.bad = true;
        for (g.players[0..g.n]) |p| {
            if (p.team == team and p.role == role) g.bad = true;
        }
        g.players[g.n] = .{
            .team = team,
            .role = role,
            .champion = @intCast(std.math.clamp(champion, 0, std.math.maxInt(u16))),
            .tier = @intCast(if (tier) |t| indexOf(&tiers, t) orelse tiers.len else tiers.len),
            .gold14 = gold14,
        };
        g.n += 1;
    }
};

/// One match's game and bans (in key order) into `run`
fn countGame(run: *Run, game: *const Game, m: Match, bans: []const u32, index_of: []const ?u16, since_ms: i64, all_platforms: []const []const u8) !void {
    const a = run.arena.allocator();
    if (game.rows == 0) return;
    const slice: Slice = .{
        .recent = m.start >= since_ms,
        .platform = @intCast(indexOf(all_platforms, m.platform) orelse 0),
        .patch = try patchIndex(a, &run.patches, m.patch),
    };
    if (game.bad or game.n < 10) return;
    const winner = side(m.winner) orelse return;
    const players = &game.players;
    const gk: GameKey = .{ .slice = slice, .tier = gameTier(players) };
    (try run.games.getOrPutValue(a, gk, 0)).value_ptr.* += 1;
    for (players) |p| {
        const sl = try run.slots.getOrPutValue(a, .{ .slice = slice, .tier = p.tier, .role = p.role }, 0);
        sl.value_ptr.* += 1;
        const c = &run.cells[index_of[p.champion] orelse continue];
        const opp = opponent(players, p) orelse continue;
        const e = try c.getOrPutValue(a, .{
            .slice = slice,
            .tier = p.tier,
            .role = p.role,
            .opponent = opp.champion,
        }, .{});
        e.value_ptr.games += 1;
        if (p.team == winner) e.value_ptr.wins += 1;
        if (p.gold14 != null and opp.gold14 != null) {
            const d = p.gold14.? - opp.gold14.?;
            e.value_ptr.gold_n += 1;
            e.value_ptr.gold_sum += d;
            e.value_ptr.gold_sq += d * d;
        }
    }
    // Once per game: both teams may ban the same champion
    var banned: [10]u32 = undefined;
    var nb: usize = 0;
    for (bans) |champion| {
        if (std.mem.findScalar(u32, banned[0..nb], champion) != null or nb == banned.len) continue;
        banned[nb] = champion;
        nb += 1;
        (try run.bans.getOrPutValue(a, .{ .game = gk, .champion = champion }, 0)).value_ptr.* += 1;
    }
}

/// A run's key with its patch index in the merged order
fn inGlobal(key: anytype, global: *const [std.math.maxInt(u8)]u8) @TypeOf(key) {
    var k = key;
    switch (@TypeOf(key)) {
        Key, SlotKey, GameKey => k.slice.patch = global[k.slice.patch],
        BanKey => k.game.slice.patch = global[k.game.slice.patch],
        else => @compileError("no slice"),
    }
    return k;
}

/// Median ladder tier of the game's players (lower middle); tiers.len when none is on
/// the ladder
fn gameTier(players: *const [10]Player) u8 {
    var ranked: [10]u8 = undefined;
    var n: usize = 0;
    for (players) |p| if (p.tier < tiers.len) {
        ranked[n] = p.tier;
        n += 1;
    };
    if (n == 0) return tiers.len;
    std.mem.sort(u8, ranked[0..n], {}, std.sort.asc(u8));
    return ranked[(n - 1) / 2];
}

fn writeMeta(w: *Writer, opts: root.Options, patches: []const []const u8, sorted: []const []const u8, slots: *const Slots, games: *const Games) !void {
    try w.writeAll("{\"platforms\":");
    try std.json.Stringify.value(opts.all_platforms, .{}, w);
    try w.writeAll(",\"tiers\":");
    try std.json.Stringify.value(tiers, .{}, w);
    try w.writeAll(",\"patches\":");
    try std.json.Stringify.value(patches, .{}, w);
    try w.writeAll(",\"newest\":");
    try std.json.Stringify.value(sorted, .{}, w);
    try w.writeAll(",\"current\":");
    try std.json.Stringify.value(opts.patches, .{}, w);
    try w.writeAll(",\"roles\":[");
    for (Role.all, 0..) |r, i| {
        if (i > 0) try w.writeByte(',');
        try w.print("\"{s}\"", .{root.roleSlug(r)});
    }
    // Players per role: platform, patch, recent, tier, role, players
    try w.writeAll("],\"slots\":[");
    var it = slots.iterator();
    var first = true;
    while (it.next()) |e| {
        if (!first) try w.writeByte(',');
        first = false;
        const k = e.key_ptr.*;
        try w.print("[{d},{d},{d},{d},{d},{d}]", .{
            k.slice.platform, k.slice.patch, @intFromBool(k.slice.recent), k.tier, @backingInt(k.role), e.value_ptr.*,
        });
    }
    // Games by their rank (gameTier), for ban rates: platform, patch, recent, tier, games
    try w.writeAll("],\"games\":[");
    first = true;
    var git = games.iterator();
    while (git.next()) |e| {
        if (!first) try w.writeByte(',');
        first = false;
        const k = e.key_ptr.*;
        try w.print("[{d},{d},{d},{d},{d}]", .{ k.slice.platform, k.slice.patch, @intFromBool(k.slice.recent), k.tier, e.value_ptr.* });
    }
    try w.writeAll("]}\n");
}

fn writeChampion(site: *const root.Site, w: *Writer, opts: root.Options, patches: []const []const u8, ch: root.Champ, cells: *const Cells, bans: *const Bans) !void {
    // Platforms and patches by index, as in data/filters.json, repeated so a cached copy
    // of either file can't misread the other
    try w.writeAll("{\"platforms\":");
    try std.json.Stringify.value(opts.all_platforms, .{}, w);
    try w.writeAll(",\"patches\":");
    try std.json.Stringify.value(patches, .{}, w);
    // One array per slice: platform, patch, recent, tier, role, opponent, games, wins,
    // gold n, gold sum, gold sum of squares
    try w.writeAll(",\"rows\":[");
    var it = cells.iterator();
    var first = true;
    while (it.next()) |e| {
        if (!first) try w.writeByte(',');
        first = false;
        const k = e.key_ptr.*;
        const v = e.value_ptr.*;
        try w.print("[{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}]", .{
            k.slice.platform, k.slice.patch, @intFromBool(k.slice.recent), k.tier,     @backingInt(k.role), k.opponent,
            v.games,          v.wins,        v.gold_n,                     v.gold_sum, v.gold_sq,
        });
    }
    // Platform, patch, recent, the game's rank (gameTier), games banned in
    try w.writeAll("],\"bans\":[");
    first = true;
    var bit = bans.iterator();
    while (bit.next()) |e| {
        const k = e.key_ptr.*;
        if (k.champion != ch.id) continue;
        if (!first) try w.writeByte(',');
        first = false;
        const g = k.game;
        try w.print("[{d},{d},{d},{d},{d}]", .{ g.slice.platform, g.slice.patch, @intFromBool(g.slice.recent), g.tier, e.value_ptr.* });
    }
    // Each view's lane curve gold at 14 per role and opponent: mean, games, p10 and p90,
    // keyed "region|period|rank" as the filter bar's values. An all-ranks entry also
    // means the view has that matchup's page
    try w.writeAll("],\"gold\":{");
    first = true;
    for (html.View.all, site.view_curves) |v, *maybe| {
        const curves = if (maybe.*) |*c| c else continue;
        const period = switch (v.period) {
            .days30 => "days30",
            .patch => if (opts.patches.len == 1) try site.arena.print("patch:{s}", .{opts.patches[0]}) else continue,
        };
        const region = switch (v.region) {
            .euw => opts.platforms[0],
            .all => "all",
        };
        for (curve_ranks) |cr| {
            if (!first) try w.writeByte(',');
            first = false;
            try w.print("\"{s}|{s}|{s}\":[", .{ region, period, cr[1] });
            var n: usize = 0;
            for (Role.all) |r| for (site.champs) |other| {
                const view = curves.get(r, cr[0], ch.id, other.id) orelse continue;
                const i = core.curvesfile.lane_minute - 1;
                const e = view.estimate(.gold, i);
                const g = matchup.range(view, curves.baseline(r, cr[0]), .gold, i);
                if (n > 0) try w.writeByte(',');
                n += 1;
                try w.print("[{d},{d},{d},{d},{d},{d}]", .{ @backingInt(r), other.id, e.mean, view.games(), g[0], g[1] });
            };
            try w.writeByte(']');
        }
    }
    try w.writeAll("}}\n");
}

fn side(team_id: i64) ?u1 {
    return switch (team_id) {
        100 => 0,
        200 => 1,
        else => null,
    };
}

fn opponent(players: *const [10]Player, p: Player) ?Player {
    for (players) |o| if (o.team != p.team and o.role == p.role) return o;
    return null;
}

fn indexOf(list: []const []const u8, s: []const u8) ?usize {
    for (list, 0..) |x, i| if (std.mem.eql(u8, x, s)) return i;
    return null;
}

fn patchIndex(a: std.mem.Allocator, patches: *std.ArrayList([]const u8), patch: []const u8) !u8 {
    if (indexOf(patches.items, patch)) |i| return @intCast(i);
    if (patches.items.len == std.math.maxInt(u8)) return error.TooManyPatches;
    try patches.append(a, try a.dupe(u8, patch));
    return @intCast(patches.items.len - 1);
}

test "games come from the start and patch indexes, not a walk of every match" {
    const db = try store.schema.memory();
    defer db.close();
    var q = try db.prepare("EXPLAIN QUERY PLAN " ++ games_sql);
    defer q.deinit();
    var plan: std.ArrayList(u8) = .empty;
    defer plan.deinit(std.testing.allocator);
    while (try q.step()) try plan.appendSlice(std.testing.allocator, q.bytes(3));
    for ([_][]const u8{ "USING INDEX matches_start", "USING INDEX matches_patch" }) |want| {
        if (std.mem.find(u8, plan.items, want) == null) {
            std.debug.print("plan: {s}\n", .{plan.items});
            return error.TestUnexpectedResult;
        }
    }
}

test "a game's rows, slots and bans, once per game" {
    const gpa = std.testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const db = try store.schema.memory();
    defer db.close();
    // EUW1_1: champions 1-5 (Gold, blue, won) against 6-10 (Platinum, the support off
    // the ladder), top laners' gold at 14 500 and 300; both teams ban 11. EUW1_2: nine
    // players, left out
    try db.exec(
        \\INSERT INTO matches VALUES ('EUW1_1', 'riot', 'EUW1', 420, '16.20', '16.20.1', 1000, 1800, 100, 0),
        \\  ('EUW1_2', 'riot', 'EUW1', 420, '16.20', '16.20.1', 1000, 1800, 100, 0);
        \\INSERT INTO bans VALUES ('EUW1_1', 100, 1, 11), ('EUW1_1', 200, 6, 11), ('EUW1_2', 100, 1, 11);
    );
    const positions = [_][]const u8{ "TOP", "JUNGLE", "MIDDLE", "BOTTOM", "UTILITY" };
    for ([_][]const u8{ "EUW1_1", "EUW1_2" }, [_]usize{ 10, 9 }) |id, players| {
        for (0..players) |slot| {
            const blue = slot < 5;
            const tier: ?[]const u8 = if (slot == 9) null else if (blue) "GOLD" else "PLATINUM";
            const gold14: ?i64 = switch (slot) {
                0 => 500,
                5 => 300,
                else => null,
            };
            try db.run(
                \\INSERT INTO participants (match_id, slot, team_id, champion_id, position, win, tier, gold14, gold15)
                \\VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            , .{ id, slot, @as(i64, if (blue) 100 else 200), slot + 1, positions[slot % 5], @intFromBool(blue), tier, gold14, gold14 });
        }
    }
    var champs: [11]root.Champ = undefined;
    for (&champs, 0..) |*ch, i| {
        const slug = try a.print("c{d}", .{i + 1});
        ch.* = .{ .c = i, .id = @intCast(i + 1), .key = slug, .name = slug, .slug = slug, .banned = 0, .games = 0 };
    }
    const no_curves: [html.View.count]?core.curvesfile.Curves = @splat(null);
    const opts: root.Options = .{
        .out_dir = "",
        .patches = &.{"16.20"},
        .since_ms = 0,
        .all_platforms = &.{"EUW1"},
        .contact = "",
        .updated = "",
    };
    var site: root.Site = undefined;
    site.gpa = std.testing.allocator;
    site.io = std.testing.io;
    site.arena = a;
    site.champs = &champs;
    site.view_curves = &no_curves;
    const made = try make(&site, db, opts);
    try std.testing.expectEqual(champs.len + 1, made.files.len);
    const file = struct {
        fn f(files: []const root.File, path: []const u8) []const u8 {
            for (files) |x| if (std.mem.eql(u8, x.path, path)) return x.data;
            return "";
        }
    }.f;
    const head = "{\"platforms\":[\"EUW1\"],\"patches\":[\"16.20\"],";
    // Platform, patch, recent, tier, role, opponent, games, wins, gold n, sum, squares
    try std.testing.expectEqualStrings(head ++ "\"rows\":[[0,0,1,3,0,6,1,1,1,200,40000]],\"bans\":[],\"gold\":{}}\n", file(made.files, "data/filters/c1.json"));
    try std.testing.expectEqualStrings(head ++ "\"rows\":[[0,0,1,4,0,1,1,0,1,-200,40000]],\"bans\":[],\"gold\":{}}\n", file(made.files, "data/filters/c6.json"));
    try std.testing.expectEqualStrings(head ++ "\"rows\":[[0,0,1,10,4,5,1,0,0,0,0]],\"bans\":[],\"gold\":{}}\n", file(made.files, "data/filters/c10.json"));
    // Banned by both teams: one game, of Gold rank (the players' lower median)
    try std.testing.expectEqualStrings(head ++ "\"rows\":[],\"bans\":[[0,0,1,3,1]],\"gold\":{}}\n", file(made.files, "data/filters/c11.json"));
    const meta = file(made.files, "data/filters.json");
    for ([_][]const u8{
        "\"roles\":[\"top\",\"jungle\",\"mid\",\"bot\",\"support\"]",
        "\"slots\":[[0,0,1,3,0,1],[0,0,1,3,1,1],[0,0,1,3,2,1],[0,0,1,3,3,1],[0,0,1,3,4,1]," ++
            "[0,0,1,4,0,1],[0,0,1,4,1,1],[0,0,1,4,2,1],[0,0,1,4,3,1],[0,0,1,10,4,1]]",
        "\"games\":[[0,0,1,3,1]]}",
    }) |want| if (std.mem.find(u8, meta, want) == null) {
        std.debug.print("data/filters.json lacks {s}:\n{s}\n", .{ want, meta });
        return error.TestUnexpectedResult;
    };
}

test "runs on their own connections make the files one walk makes" {
    const gpa = std.testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir = try std.fs.path.join(a, &.{ ".zig-cache", "tmp", &tmp.sub_path });
    const file_db = try store.schema.open(gpa, dir);
    defer file_db.close();
    const memory_db = try store.schema.memory();
    defer memory_db.close();
    // 40 games over two platforms and three patches, champions and bans varying, so each
    // run meets patches and keys in its own order
    const positions = [_][]const u8{ "TOP", "JUNGLE", "MIDDLE", "BOTTOM", "UTILITY" };
    const patches = [_][]const u8{ "16.19", "16.20", "16.18" };
    for ([_]store.Db{ file_db, memory_db }) |db| {
        for (0..40) |g| {
            const id = try a.print("{s}_{d:0>3}", .{ if (g % 3 == 0) "NA1" else "EUW1", g });
            const patch = patches[(g * 7 / 5) % patches.len];
            try db.run("INSERT INTO matches VALUES (?, 'riot', ?, 420, ?, ?, ?, 1800, ?, 0)", .{
                id, id[0..std.mem.findScalar(u8, id, '_').?], patch, patch, @as(i64, @intCast(g)) * 1000, @as(i64, if (g % 2 == 0) 100 else 200),
            });
            try db.run("INSERT INTO bans VALUES (?, 100, 1, ?), (?, 200, 6, ?)", .{ id, @as(i64, @intCast(g % 4 + 1)), id, @as(i64, @intCast(g % 3 + 5)) });
            for (0..10) |slot| {
                const blue = slot < 5;
                const tier: ?[]const u8 = switch ((g + slot) % 4) {
                    0 => "GOLD",
                    1 => "SILVER",
                    2 => "DIAMOND",
                    else => null,
                };
                const gold14: ?i64 = if ((g + slot) % 3 == 0) null else @intCast(4000 + g * 13 + slot * 101);
                try db.run(
                    \\INSERT INTO participants (match_id, slot, team_id, champion_id, position, win, tier, gold14, gold15)
                    \\VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                , .{ id, slot, @as(i64, if (blue) 100 else 200), (g * 3 + slot * 7) % 11 + 1, positions[slot % 5], @intFromBool(blue == (g % 2 == 0)), tier, gold14, gold14 });
            }
        }
    }
    var champs: [11]root.Champ = undefined;
    for (&champs, 0..) |*ch, i| {
        const slug = try a.print("c{d}", .{i + 1});
        ch.* = .{ .c = i, .id = @intCast(i + 1), .key = slug, .name = slug, .slug = slug, .banned = 0, .games = 0 };
    }
    const no_curves: [html.View.count]?core.curvesfile.Curves = @splat(null);
    const opts: root.Options = .{
        .out_dir = "",
        .patches = &.{"16.20"},
        .since_ms = 20_000,
        .all_platforms = &.{ "EUW1", "NA1" },
        .contact = "",
        .updated = "",
    };
    var site: root.Site = undefined;
    site.gpa = gpa;
    site.io = std.testing.io;
    site.arena = a;
    site.champs = &champs;
    site.view_curves = &no_curves;
    const one = try makeIn(&site, memory_db, opts, 1, null);
    const several = try makeIn(&site, file_db, opts, runs, null);
    try std.testing.expectEqual(one.files.len, several.files.len);
    for (one.files, several.files) |x, y| {
        try std.testing.expectEqualStrings(x.path, y.path);
        try std.testing.expectEqualStrings(x.data, y.data);
    }
    try std.testing.expect(std.mem.find(u8, one.files[1].data, "\"rows\":[[") != null);
}
