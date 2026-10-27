//! The champion page's rank filter tally: per champion, games and wins against the lane
//! opponent by region, the player's rank, patch, role and opponent, with players per
//! role and bans by game rank, summed into each view and rank group's figures
//! (Made.ranked) that champrank.zig writes as the rank files

const std = @import("std");
const store = @import("store");
const core = @import("core");
const root = @import("root.zig");
const html = @import("html.zig");
const stats = @import("../stats.zig");
const par = @import("../par.zig");
const partials = @import("../partials.zig");
const tierlist = @import("tierlist.zig");

const Role = core.Role;

/// Ladder tiers, lowest first; a player off the ladder when the game was stored (tier
/// NULL) gets index tiers.len, counted only under "All (Platinum+ games)"
pub const tiers = [_][]const u8{
    "IRON", "BRONZE", "SILVER", "GOLD", "PLATINUM", "EMERALD", "DIAMOND", "MASTER", "GRANDMASTER", "CHALLENGER",
};
/// The Rank filter's lowest option, Platinum: the tier the crawl samples from
pub const lowest_offered = 4;

comptime {
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

const Cells = std.AutoArrayHashMapUnmanaged(Key, Counts);

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
};

pub const Made = struct {
    /// The rank filter's (rankFigures), by champion, view, group and role
    ranked: []const Ranked = &.{},
    /// Every champion's lane games by view, group, role and champion (roleCount):
    /// opponents' own rates at a rank
    role_counts: []const Counts = &.{},
    /// Games by view and group (by gameTier): the champions board's at a rank
    games: []const u64 = &.{},

    pub fn gamesAt(m: *const Made, v: usize, g: usize) u64 {
        return m.games[v * rank_groups.len + g];
    }

    pub fn roleCount(m: *const Made, v: usize, g: usize, r: Role, c: usize) Counts {
        const n = m.role_counts.len / (html.View.count * rank_groups.len * Role.all.len);
        return m.role_counts[((v * rank_groups.len + g) * Role.all.len + @backingInt(r)) * n + c];
    }
};

/// The champion page's rank filter above its Platinum+ base (ui.champrank): Emerald+,
/// Diamond+, Master+ by their lowest tier index, as builds.rank_tiers
pub const rank_groups = [_]u8{ 5, 6, 7 };

pub const Counts = struct { games: u32 = 0, wins: u32 = 0 };

/// A champion's lane games in a role under a view and rank group, with the figures that
/// need every champion's; champrank.zig adds those that need the view's own files
pub const Ranked = struct {
    /// site.champs index
    champ: u16,
    view: u8,
    group: u8,
    role: Role,
    games: u32,
    wins: u32,
    /// %, of the role's players at the rank and of its games (by gameTier)
    pick: f32,
    ban: f32,
    /// tierlist.roleRank's order from the rank's counts; 0: rare there
    rank: u16 = 0,
    of: u16 = 0,
    /// In 1%+ of its games here, most played first
    opps: []const RankedOpp,
    /// Oldest first, those the view has players of the role on
    patches: []const RankedPatch,
};

/// champ: site.champs index
pub const RankedOpp = struct { champ: u16, games: u32, wins: u32 };

pub const RankedPatch = struct { patch: []const u8, games: u32, wins: u32, rank: u16 = 0 };

/// The games' matches; make reads each one's players and bans by primary key. A join
/// ordered by match_id walks every match ever stored: with +match_id the start and patch
/// indexes find the matches and only those are sorted. The order fixes the first-seen
/// order of patches and the maps
const games_sql =
    \\SELECT match_id, winning_team, game_start, patch, platform
    \\FROM matches
    \\WHERE queue_id = ? AND platform IN (SELECT value FROM json_each(?))
    \\  AND remake = 0 AND winning_team IS NOT NULL
    \\  AND (game_start >= ? OR patch IN (SELECT value FROM json_each(?)))
    \\ORDER BY +match_id
;

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
/// runs of games at once, merged in game order, so the tally matches a single walk's
pub fn make(site: *const root.Site, db: store.Db, opts: root.Options) !Made {
    return figures(site, opts, try tally(site, db, opts, opts.filter_runs, null));
}

/// As make, the games from the views partials
pub fn makeFrom(site: *const root.Site, games: *const partials.Store, opts: root.Options) !Made {
    return figures(site, opts, try tally(site, null, opts, opts.filter_runs, games));
}

fn figures(site: *const root.Site, opts: root.Options, t: Tally) !Made {
    const ranks = try rankFigures(site.arena, site, opts, t.patches, t.cells, &t.slots, &t.games, &t.bans, t.index_of);
    return .{ .ranked = ranks.ranked, .role_counts = ranks.role_counts, .games = ranks.games };
}

/// Every run's counts merged, patch indexes into `patches`
const Tally = struct {
    cells: []const Cells,
    slots: Slots,
    games: Games,
    bans: Bans,
    patches: []const []const u8,
    index_of: []const ?u16,
};

fn tally(site: *const root.Site, maybe_db: ?store.Db, opts: root.Options, run_count: usize, games_from: ?*const partials.Store) !Tally {
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
                add((try into.getOrPutValue(a, inGlobal(e.key_ptr.*, &global), .{})).value_ptr, e.value_ptr.*);
            }
        }
        var bit = r.bans.iterator();
        while (bit.next()) |e| (try bans.getOrPutValue(a, inGlobal(e.key_ptr.*, &global), 0)).value_ptr.* += e.value_ptr.*;
        r.arena.deinit();
        r.arena = .init(gpa);
    }

    return .{ .cells = cells, .slots = slots, .games = games, .bans = bans, .patches = patches.items, .index_of = index_of };
}

/// Each of `matches`' players and bans by primary key, into `run`
fn countRun(run: *Run, db: store.Db, matches: []const Match, index_of: []const ?u16, since_ms: i64, all_platforms: []const []const u8) !void {
    var pq = try db.prepare(
        \\SELECT team_id, position, champion_id, tier FROM participants WHERE match_id = ? ORDER BY slot
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
            });
            game.add(r.team, r.position, r.champion, r.tier);
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
            game.add(p.team, games.string(p.position), p.champion, games.string(p.tier));
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

    fn add(g: *Game, team_id: i64, position: ?[]const u8, champion: i64, tier: ?[]const u8) void {
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

const Ranks = struct { ranked: []const Ranked, role_counts: []const Counts, games: []const u64 };

/// Which slices and tiers a view and rank group count
const RankScope = struct {
    /// By opts.all_platforms: an EUW view's
    home: []const bool,
    /// By patch index: the patch views'
    current: []const bool,

    fn has(s: RankScope, v: html.View, slice: Slice) bool {
        if (v.region == .euw and !s.home[slice.platform]) return false;
        return switch (v.period) {
            .days30 => slice.recent,
            .patch => s.current[slice.patch],
        };
    }

    /// Every ladder tier from the group's lowest up; off the ladder (tiers.len) is only
    /// in the base's Platinum+
    fn inGroup(g: usize, tier: u8) bool {
        return tier >= rank_groups[g] and tier < tiers.len;
    }
};

/// The rank filter's figures from the merged tally: cells' lane games summed over each
/// view's slices and each group's tiers, and per patch; rank in role, pick and ban rates
/// from every champion's at the same view and group
fn rankFigures(a: std.mem.Allocator, site: *const root.Site, opts: root.Options, patches: []const []const u8, cells: []const Cells, slots: *const Slots, games: *const Games, bans: *const Bans, index_of: []const ?u16) !Ranks {
    const n_v = html.View.count;
    const n_g = rank_groups.len;
    const n_r = Role.all.len;
    const n_c = site.champs.len;
    const n_p = patches.len;
    const home = try a.alloc(bool, opts.all_platforms.len);
    for (home, opts.all_platforms) |*h, p| h.* = indexOf(opts.platforms, p) != null;
    const current = try a.alloc(bool, n_p);
    for (current, patches) |*c, p| c.* = indexOf(opts.patches, p) != null;
    const scope: RankScope = .{ .home = home, .current = current };

    // By view, group, role (vgr), then champion; by_patch with the patch before it.
    // players: by vgr then patch, index n_p for every patch
    const vgr = n_v * n_g * n_r;
    const totals = try a.alloc(Counts, vgr * n_c);
    const by_patch = try a.alloc(Counts, vgr * n_p * n_c);
    const players = try a.alloc(u64, vgr * (n_p + 1));
    const game_n = try a.alloc(u64, n_v * n_g);
    const ban_n = try a.alloc(u64, n_v * n_g * n_c);
    @memset(totals, .{});
    @memset(by_patch, .{});
    @memset(players, 0);
    @memset(game_n, 0);
    @memset(ban_n, 0);
    const at = struct {
        fn vgrOf(v: usize, g: usize, r: Role) usize {
            return (v * rank_groups.len + g) * Role.all.len + @backingInt(r);
        }
    };

    var sit = slots.iterator();
    while (sit.next()) |e| {
        const k = e.key_ptr.*;
        for (html.View.all, 0..) |v, vi| {
            if (!scope.has(v, k.slice)) continue;
            for (0..n_g) |g| if (RankScope.inGroup(g, k.tier)) {
                const i = at.vgrOf(vi, g, k.role) * (n_p + 1);
                players[i + n_p] += e.value_ptr.*;
                players[i + k.slice.patch] += e.value_ptr.*;
            };
        }
    }
    var git = games.iterator();
    while (git.next()) |e| for (html.View.all, 0..) |v, vi| {
        if (!scope.has(v, e.key_ptr.slice)) continue;
        for (0..n_g) |g| if (RankScope.inGroup(g, e.key_ptr.tier)) {
            game_n[vi * n_g + g] += e.value_ptr.*;
        };
    };
    var bit = bans.iterator();
    while (bit.next()) |e| {
        const k = e.key_ptr.*;
        if (k.champion > std.math.maxInt(u16)) continue;
        const c = index_of[k.champion] orelse continue;
        for (html.View.all, 0..) |v, vi| {
            if (!scope.has(v, k.game.slice)) continue;
            for (0..n_g) |g| if (RankScope.inGroup(g, k.game.tier)) {
                ban_n[(vi * n_g + g) * n_c + c] += e.value_ptr.*;
            };
        }
    }
    for (cells, 0..) |*cs, c| {
        var it = cs.iterator();
        while (it.next()) |e| {
            const k = e.key_ptr.*;
            for (html.View.all, 0..) |v, vi| {
                if (!scope.has(v, k.slice)) continue;
                for (0..n_g) |g| if (RankScope.inGroup(g, k.tier)) {
                    const i = at.vgrOf(vi, g, k.role);
                    add(&totals[i * n_c + c], e.value_ptr.*);
                    add(&by_patch[(i * n_p + k.slice.patch) * n_c + c], e.value_ptr.*);
                };
            }
        }
    }

    // Each champion's games over every role, by view and group (and patch): role shares
    const champ_games = try a.alloc(u64, n_v * n_g * (n_p + 1) * n_c);
    @memset(champ_games, 0);
    for (0..n_v * n_g) |vg| for (0..n_r) |r| for (0..n_c) |c| {
        const i = vg * n_r + r;
        champ_games[(vg * (n_p + 1) + n_p) * n_c + c] += totals[i * n_c + c].games;
        for (0..n_p) |p| champ_games[(vg * (n_p + 1) + p) * n_c + c] += by_patch[(i * n_p + p) * n_c + c].games;
    };
    // Rank in role per vgr and patch (n_p: every patch), 0 when rare
    const ranks = try a.alloc(u16, vgr * (n_p + 1) * n_c);
    const ofs = try a.alloc(u16, vgr * (n_p + 1));
    for (0..vgr) |i| for (0..n_p + 1) |p| {
        const vg = i / n_r;
        const counts = if (p == n_p) totals[i * n_c ..][0..n_c] else by_patch[(i * n_p + p) * n_c ..][0..n_c];
        const j = i * (n_p + 1) + p;
        ofs[j] = try roleRanks(a, counts, champ_games[(vg * (n_p + 1) + p) * n_c ..][0..n_c], players[j], ranks[j * n_c ..][0..n_c]);
    };

    // Patches oldest first
    const order = try a.alloc(usize, n_p);
    for (order, 0..) |*o, i| o.* = i;
    std.mem.sort(usize, order, patches, struct {
        fn f(ps: []const []const u8, x: usize, y: usize) bool {
            return stats.patchKey(ps[x]) < stats.patchKey(ps[y]);
        }
    }.f);

    var out: std.ArrayList(Ranked) = .empty;
    const OppKey = struct { vgr: u16, opp: u16 };
    var opps: std.AutoArrayHashMapUnmanaged(OppKey, Counts) = .empty;
    for (cells, 0..) |*cs, c| {
        opps.clearRetainingCapacity();
        var it = cs.iterator();
        while (it.next()) |e| {
            const k = e.key_ptr.*;
            if (k.opponent > std.math.maxInt(u16)) continue;
            const o = index_of[k.opponent] orelse continue;
            for (html.View.all, 0..) |v, vi| {
                if (!scope.has(v, k.slice)) continue;
                for (0..n_g) |g| if (RankScope.inGroup(g, k.tier)) {
                    add((try opps.getOrPutValue(a, .{ .vgr = @intCast(at.vgrOf(vi, g, k.role)), .opp = o }, .{})).value_ptr, e.value_ptr.*);
                };
            }
        }
        for (0..n_v) |vi| for (0..n_g) |g| for (Role.all) |r| {
            const i = at.vgrOf(vi, g, r);
            const vg = vi * n_g + g;
            const t = totals[i * n_c + c];
            if (t.games == 0) continue;
            const floor = @max(1, min_opponent_share * @as(f64, @floatFromInt(t.games)));
            var list: std.ArrayList(RankedOpp) = .empty;
            var oit = opps.iterator();
            while (oit.next()) |e| {
                if (e.key_ptr.vgr != i or @as(f64, @floatFromInt(e.value_ptr.games)) < floor) continue;
                try list.append(a, .{ .champ = e.key_ptr.opp, .games = e.value_ptr.games, .wins = e.value_ptr.wins });
            }
            std.mem.sort(RankedOpp, list.items, {}, struct {
                fn f(_: void, x: RankedOpp, y: RankedOpp) bool {
                    return x.games > y.games;
                }
            }.f);
            var ps: std.ArrayList(RankedPatch) = .empty;
            for (order) |p| {
                if (players[i * (n_p + 1) + p] == 0) continue;
                const pc = by_patch[(i * n_p + p) * n_c + c];
                try ps.append(a, .{ .patch = patches[p], .games = pc.games, .wins = pc.wins, .rank = ranks[(i * (n_p + 1) + p) * n_c + c] });
            }
            const j = i * (n_p + 1) + n_p;
            const rank = ranks[j * n_c + c];
            try out.append(a, .{
                .champ = @intCast(c),
                .view = @intCast(vi),
                .group = @intCast(g),
                .role = r,
                .games = t.games,
                .wins = t.wins,
                .pick = @floatCast(100 * ratio(t.games, players[j] / 2)),
                .ban = @floatCast(100 * ratio(ban_n[vg * n_c + c], game_n[vg])),
                .rank = rank,
                .of = if (rank > 0) ofs[j] else 0,
                .opps = list.items,
                .patches = ps.items,
            });
        };
    }
    return .{ .ranked = out.items, .role_counts = totals, .games = game_n };
}

/// Opponents under this share of the champion's games in the role are left out, as on
/// the champion page (champion.zig)
const min_opponent_share = 0.01;

fn add(into: *Counts, c: Counts) void {
    into.games += c.games;
    into.wins += c.wins;
}

fn ratio(n: u64, of: u64) f64 {
    return if (of == 0) 0 else @as(f64, @floatFromInt(n)) / @as(f64, @floatFromInt(of));
}

/// tierlist.roleRank's rule on one role's counts: rare picks (under min_pick_rate of the
/// role's players' games, or min_role_share of the champion's) left out, the rest by win
/// rate, more games first on a tie. Writes each champion's place (0: rare or none) into
/// `out` and returns how many are placed
fn roleRanks(a: std.mem.Allocator, counts: []const Counts, champ_games: []const u64, players: u64, out: []u16) !u16 {
    @memset(out, 0);
    var placed: std.ArrayList(usize) = .empty;
    for (counts, champ_games, 0..) |x, all, c| {
        if (x.games == 0) continue;
        if (ratio(x.games, players / 2) < tierlist.min_pick_rate or ratio(x.games, all) < tierlist.min_role_share) continue;
        try placed.append(a, c);
    }
    std.mem.sort(usize, placed.items, counts, struct {
        fn f(cs: []const Counts, x: usize, y: usize) bool {
            const rx = ratio(cs[x].wins, cs[x].games);
            const ry = ratio(cs[y].wins, cs[y].games);
            return if (rx != ry) rx > ry else cs[x].games > cs[y].games;
        }
    }.f);
    for (placed.items, 1..) |c, k| out[c] = @intCast(k);
    return @intCast(placed.items.len);
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
    // the ladder); both teams ban 11. EUW1_2: nine players, left out
    try db.exec(
        \\INSERT INTO matches VALUES ('EUW1_1', 'riot', 'EUW1', 420, '16.20', '16.20.1', 1000, 1800, 100, 0),
        \\  ('EUW1_2', 'riot', 'EUW1', 420, '16.20', '16.20.1', 1000, 1800, 100, 0);
        \\INSERT INTO bans VALUES ('EUW1_1', 100, 1, 11), ('EUW1_1', 200, 6, 11), ('EUW1_2', 100, 1, 11);
    );
    for ([_][]const u8{ "EUW1_1", "EUW1_2" }, [_]usize{ 10, 9 }) |id, players| {
        for (0..players) |slot| {
            const blue = slot < 5;
            const tier: ?[]const u8 = if (slot == 9) null else if (blue) "GOLD" else "PLATINUM";
            try db.run(
                \\INSERT INTO participants (match_id, slot, team_id, champion_id, position, win, tier)
                \\VALUES (?, ?, ?, ?, ?, ?, ?)
            , .{ id, slot, @as(i64, if (blue) 100 else 200), slot + 1, Role.positions[slot % 5], @intFromBool(blue), tier });
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
    const t = try tally(&site, db, opts, opts.filter_runs, null);
    const slice: Slice = .{ .platform = 0, .patch = 0, .recent = true };
    const counts = struct {
        fn f(c: Cells, tier: u8, r: Role, opp: u16) !Counts {
            try std.testing.expectEqual(1, c.count());
            return c.get(.{ .slice = slice, .tier = tier, .role = r, .opponent = opp }) orelse error.TestUnexpectedResult;
        }
    }.f;
    // Tier (Gold 3, Platinum 4, off the ladder 10), role, lane opponent
    try std.testing.expectEqual(Counts{ .games = 1, .wins = 1 }, try counts(t.cells[0], 3, .top, 6));
    try std.testing.expectEqual(Counts{ .games = 1, .wins = 0 }, try counts(t.cells[5], 4, .top, 1));
    try std.testing.expectEqual(Counts{ .games = 1, .wins = 0 }, try counts(t.cells[9], 10, .utility, 5));
    try std.testing.expectEqual(0, t.cells[10].count());
    try std.testing.expectEqual(10, t.slots.count());
    for (Role.all) |r| {
        try std.testing.expectEqual(1, t.slots.get(.{ .slice = slice, .tier = 3, .role = r }));
        try std.testing.expectEqual(1, t.slots.get(.{ .slice = slice, .tier = if (r == .utility) 10 else 4, .role = r }));
    }
    // Banned by both teams: one game, of Gold rank (the players' lower median)
    try std.testing.expectEqual(1, t.games.count());
    try std.testing.expectEqual(1, t.games.get(.{ .slice = slice, .tier = 3 }));
    try std.testing.expectEqual(1, t.bans.count());
    try std.testing.expectEqual(1, t.bans.get(.{ .game = .{ .slice = slice, .tier = 3 }, .champion = 11 }));
}

test "runs on their own connections tally as one walk does" {
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
                try db.run(
                    \\INSERT INTO participants (match_id, slot, team_id, champion_id, position, win, tier)
                    \\VALUES (?, ?, ?, ?, ?, ?, ?)
                , .{ id, slot, @as(i64, if (blue) 100 else 200), (g * 3 + slot * 7) % 11 + 1, Role.positions[slot % 5], @intFromBool(blue == (g % 2 == 0)), tier });
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
    const one = try tally(&site, memory_db, opts, 1, null);
    const several = try tally(&site, file_db, opts, opts.filter_runs, null);
    for (one.patches, several.patches) |x, y| try std.testing.expectEqualStrings(x, y);
    for (one.cells, several.cells) |x, y| {
        try std.testing.expectEqualSlices(Key, x.keys(), y.keys());
        try std.testing.expectEqualSlices(Counts, x.values(), y.values());
    }
    try std.testing.expectEqualSlices(SlotKey, one.slots.keys(), several.slots.keys());
    try std.testing.expectEqualSlices(u32, one.slots.values(), several.slots.values());
    try std.testing.expectEqualSlices(BanKey, one.bans.keys(), several.bans.keys());
    try std.testing.expectEqualSlices(u32, one.bans.values(), several.bans.values());
    const made = try figures(&site, opts, several);
    try std.testing.expect(made.ranked.len > 0);
    try std.testing.expectEqualDeep(made, try figures(&site, opts, one));
}

test "rank in role at a rank: rare picks out, then by win rate" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var out: [4]u16 = undefined;
    // The third has 5% of its games in the role, the fourth 0.2% of the role's players
    const of = try roleRanks(arena.allocator(), &.{
        .{ .games = 100, .wins = 50 },
        .{ .games = 100, .wins = 60 },
        .{ .games = 100, .wins = 70 },
        .{ .games = 1, .wins = 1 },
    }, &.{ 100, 100, 2000, 1 }, 1000, &out);
    try std.testing.expectEqual(2, of);
    try std.testing.expectEqualSlices(u16, &.{ 2, 1, 0, 0 }, &out);
}
