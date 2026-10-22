//! Pool: champion discovery from what players actually play (docs/concept.md part 5).
//!
//! - Players who main X also play Y: lift over Y's usual play rate (not raw counts,
//!   which only repeat popularity), shrunk toward 1 for small n, with n shown
//! - Options for X's hard lanes: of those Y, the ones that do well into X's worst lane
//!   matchups (several, with reasons; never "the best pick")
//! - Ban fallback: Y that X's players also play and that are good into the same lanes
//!
//! A player's main is their top champion: by mastery points once the mastery table
//! fills, until then by ranked solo games in the crawl. Champion and aggregate data
//! only: nothing about any player is published.

const std = @import("std");
const store = @import("store");
const core = @import("core");
const stats = @import("stats.zig");
const riot_mastery = @import("riot/mastery.zig");
const spread = @import("spread.zig");
const partials = @import("partials.zig");

const Role = core.Role;
const Stats = core.Stats;
const score = core.score;
const Allocator = std.mem.Allocator;

const log = std.log.scoped(.pool);

pub const Source = enum { games, mastery };

pub const Play = struct {
    champion: u32,
    weight: u32,
    /// Of the games, when weight is games
    wins: u32 = 0,
};

/// When a player counts, and which of their champions they play
pub const Rule = struct {
    /// Total weight (games or points) below which a player is too new to say
    min_total: u32,
    /// Weight below which a champion is not played
    min_weight: u32,
    /// Share of the player's top champion's weight below which a champion is not played
    min_share: f64 = 0.1,
    /// Top champion's share of the total from which a player is a one-trick
    one_trick_share: f64 = 0.5,

    pub const games: Rule = .{ .min_total = 10, .min_weight = 2 };
    /// Points: roughly 10 games' worth to count a champion
    pub const mastery: Rule = .{ .min_total = 50_000, .min_weight = 10_000 };
};

pub const Options = struct {
    /// Fewer players maining a champion and its lists are left out ("more data needed")
    min_players: u32 = 30,
    /// Pseudo-players pulling lift toward 1, so a few players cannot make a big lift
    prior_players: f64 = 20,
    /// Champions also played by fewer of a main's players are left out
    min_together: u32 = 3,
    /// Lane pairs with fewer games say nothing either way
    min_pair_games: u32 = 30,
    /// Lane matchups closer to even than this, in points, are not hard or good: the
    /// model's matchup terms are pulled toward 0, so most are a fraction of a point
    min_lane_pp: f64 = 1,
    /// A champion plays a role when it has this share of its own games there
    min_role_share: f64 = 0.1,
    also_shown: usize = 12,
    lanes_shown: usize = 5,
    options_shown: usize = 4,
    score: score.Options = .{},
};

/// Counts over players, by stats index
pub const Tally = struct {
    n: usize,
    players: u32 = 0,
    mains: []u32,
    one_tricks: []u32,
    /// Players who play the champion but main another
    plays: []u32,
    /// [main * n + other]: players maining `main` who also play `other`
    together: []u32,

    pub fn init(gpa: Allocator, n: usize) !Tally {
        const buf = try gpa.alloc(u32, 3 * n + n * n);
        @memset(buf, 0);
        return .{
            .n = n,
            .mains = buf[0..n],
            .one_tricks = buf[n .. 2 * n],
            .plays = buf[2 * n .. 3 * n],
            .together = buf[3 * n ..],
        };
    }

    pub fn deinit(t: *Tally, gpa: Allocator) void {
        gpa.free(t.mains.ptr[0 .. 3 * t.n + t.n * t.n]);
    }

    /// One player's champions; ids missing from `st` are ignored
    pub fn add(t: *Tally, st: *const Stats, plays: []const Play, rule: Rule) void {
        const c = contribution(st, plays, rule) orelse return;
        t.players += 1;
        t.mains[c.m] += 1;
        if (c.one_trick) t.one_tricks[c.m] += 1;
        for (plays) |p| if (c.plays(st, p)) t.also(c.m, st.index(p.champion).?);
    }

    /// A player as `contribution` gave them, by champion ids (partials' mastery.bin)
    pub fn addContribution(t: *Tally, st: *const Stats, main: u32, one_trick: bool, others: []const u16) void {
        const m = st.index(main).?;
        t.players += 1;
        t.mains[m] += 1;
        if (one_trick) t.one_tricks[m] += 1;
        for (others) |o| t.also(m, st.index(o).?);
    }

    fn also(t: *Tally, m: usize, o: usize) void {
        t.plays[o] += 1;
        t.together[m * t.n + o] += 1;
    }

    /// Share of players who don't main `other` but play it; null when none do
    pub fn base(t: *const Tally, other: usize) ?f64 {
        const rest = t.players - t.mains[other];
        if (rest == 0 or t.plays[other] == 0) return null;
        return @as(f64, @floatFromInt(t.plays[other])) / @as(f64, @floatFromInt(rest));
    }

    /// How much more often `main`'s players play `other` than players of other mains
    /// do, shrunk toward 1 by `prior` pseudo-players; null when nobody plays `other`
    pub fn lift(t: *const Tally, main: usize, other: usize, prior: f64) ?f64 {
        const b = t.base(other) orelse return null;
        const k: f64 = @floatFromInt(t.together[main * t.n + other]);
        const n: f64 = @floatFromInt(t.mains[main]);
        return (k + prior * b) / ((n + prior) * b);
    }
};

/// How a player counts in a Tally: their main and whether a one-trick
pub const Contribution = struct {
    main: u32,
    /// Stats index of main
    m: usize,
    one_trick: bool,
    top_w: f64,
    rule: Rule,

    /// Whether `p` counts as a champion they also play
    pub fn plays(c: Contribution, st: *const Stats, p: Play) bool {
        const o = st.index(p.champion) orelse return false;
        if (o == c.m or p.weight < c.rule.min_weight) return false;
        return @as(f64, @floatFromInt(p.weight)) >= c.rule.min_share * c.top_w;
    }
};

/// Null when the player does not count: no champion in `st`, or too little weight
pub fn contribution(st: *const Stats, plays: []const Play, rule: Rule) ?Contribution {
    var total: u64 = 0;
    var top: ?Play = null;
    for (plays) |p| {
        if (st.index(p.champion) == null) continue;
        total += p.weight;
        if (top == null or p.weight > top.?.weight) top = p;
    }
    const main = top orelse return null;
    if (total < rule.min_total) return null;
    const top_w: f64 = @floatFromInt(main.weight);
    return .{
        .main = main.champion,
        .m = st.index(main.champion).?,
        .one_trick = top_w >= rule.one_trick_share * @as(f64, @floatFromInt(total)),
        .top_w = top_w,
        .rule = rule,
    };
}

/// Every player's ranked solo champions, from the matches crawled so far (all patches: a
/// pool changes more slowly than a patch), into out[i] for the platforms of sets[i], in
/// one pass; each player's win rate on each champion in slices[i]'s games into spreads[i]
pub fn tallyGames(
    gpa: Allocator,
    db: store.Db,
    st: *const Stats,
    sets: []const []const []const u8,
    slices: []const stats.Slice,
    out: []Tally,
    spreads: []spread.Tally,
) !void {
    var platforms: std.ArrayList([]const u8) = .empty;
    defer platforms.deinit(gpa);
    for (sets) |s| try platforms.appendSlice(gpa, s);
    for (slices) |s| try platforms.appendSlice(gpa, s.platforms);
    const platform_json = try std.json.Stringify.valueAlloc(gpa, platforms.items, .{});
    defer gpa.free(platform_json);
    // Grouped by whether a game is from the slices' one start (the site's views: every
    // game or the last 30 days'), so a row's start stands in as that start or just before
    var recent_ms: i64 = 0;
    for (slices) |s| recent_ms = @max(recent_ms, s.since_ms);
    for (slices) |s| std.debug.assert(s.since_ms == 0 or s.since_ms == recent_ms);
    // CROSS JOIN: matches first, in table order. Walking the puuid index instead reads
    // participants pages at random, 6x slower. By champion within a player, as the old
    // GROUP BY puuid, champion gave: the first of tied top champions is the main
    var q = try db.prepare(
        \\SELECT p.puuid, m.platform, p.champion_id, m.patch, m.game_start >= ?, count(*),
        \\  sum(p.win)
        \\FROM matches m CROSS JOIN participants p USING (match_id)
        \\WHERE m.queue_id = ? AND m.remake = 0 AND p.puuid IS NOT NULL
        \\  AND m.platform IN (SELECT value FROM json_each(?))
        \\GROUP BY 1, 2, 3, 4, 5 ORDER BY 1, 3
    );
    defer q.deinit();
    try q.bind(.{ recent_ms, stats.ranked_solo, platform_json });
    var plays: Plays = try .init(gpa, sets.len, slices.len);
    defer plays.deinit(gpa);
    var current: std.ArrayList(u8) = .empty;
    defer current.deinit(gpa);
    while (try q.step()) {
        const r = q.row(struct {
            puuid: []const u8,
            platform: []const u8,
            champion_id: u32,
            patch: []const u8,
            recent: bool,
            games: u32,
            wins: u32,
        });
        if (!std.mem.eql(u8, r.puuid, current.items)) {
            plays.flush(st, out, spreads);
            current.clearRetainingCapacity();
            try current.appendSlice(gpa, r.puuid);
        }
        const play: Play = .{ .champion = r.champion_id, .weight = r.games, .wins = r.wins };
        const start = if (r.recent) recent_ms else recent_ms - 1;
        try plays.add(gpa, play, stats.setsWith(sets, r.platform), stats.Slice.of(slices, r.platform, start, r.patch));
    }
    plays.flush(st, out, spreads);
}

/// tallyGames from the views partials: the same players and plays, grouped by PUUID key
/// instead of PUUID (the tallies are sums, so in any player order)
pub fn tallyGamesFrom(
    gpa: Allocator,
    games: *const partials.Store,
    st: *const Stats,
    sets: []const []const []const u8,
    slices: []const stats.Slice,
    out: []Tally,
    spreads: []spread.Tally,
) !void {
    const masks = try games.setMasks(gpa, sets);
    defer gpa.free(masks);
    var slice_masks = try games.sliceMasks(gpa, slices);
    defer slice_masks.deinit(gpa);
    const Row = struct { key: partials.Key, champion: u32, sets: u32, slices: u32, win: bool };
    var rows: std.ArrayList(Row) = .empty;
    defer rows.deinit(gpa);
    for (games.sorted) |g| {
        const in_sets = masks[g.platform];
        const in_slices = slice_masks.of(g);
        if (in_sets | in_slices == 0) continue;
        for (g.players) |p| {
            const k = p.puuid orelse continue;
            try rows.append(gpa, .{
                .key = k,
                .champion = std.math.cast(u32, p.champion) orelse return error.Unrepresentable,
                .sets = in_sets,
                .slices = in_slices,
                .win = p.win,
            });
        }
    }
    std.mem.sort(Row, rows.items, {}, struct {
        fn f(_: void, a: Row, b: Row) bool {
            if (!a.key.eql(b.key)) return a.key.lessThan(b.key);
            return a.champion < b.champion;
        }
    }.f);
    var plays: Plays = try .init(gpa, sets.len, slices.len);
    defer plays.deinit(gpa);
    var at: usize = 0;
    while (at < rows.items.len) {
        const k = rows.items[at].key;
        var end = at;
        while (end < rows.items.len and rows.items[end].key.eql(k)) end += 1;
        for (rows.items[at..end]) |r| {
            try plays.add(gpa, .{ .champion = r.champion, .weight = 1, .wins = @intFromBool(r.win) }, r.sets, r.slices);
        }
        plays.flush(st, out, spreads);
        at = end;
    }
}

/// One player's plays per pool set and per spread slice, until flush
const Plays = struct {
    sets: []std.ArrayList(Play),
    slices: []std.ArrayList(Play),

    fn init(gpa: Allocator, sets: usize, slices: usize) !Plays {
        const s = try gpa.alloc(std.ArrayList(Play), sets);
        errdefer gpa.free(s);
        const sl = try gpa.alloc(std.ArrayList(Play), slices);
        @memset(s, .empty);
        @memset(sl, .empty);
        return .{ .sets = s, .slices = sl };
    }

    fn deinit(p: *Plays, gpa: Allocator) void {
        for (p.sets) |*l| l.deinit(gpa);
        for (p.slices) |*l| l.deinit(gpa);
        gpa.free(p.sets);
        gpa.free(p.slices);
    }

    /// `play` into the sets and slices whose bits are set in `sets` and `slices`
    fn add(p: *Plays, gpa: Allocator, play: Play, sets: u32, slices: u32) !void {
        for (p.sets, 0..) |*l, i| if (sets & (@as(u32, 1) << @intCast(i)) != 0) try merge(gpa, l, play);
        for (p.slices, 0..) |*l, i| if (slices & (@as(u32, 1) << @intCast(i)) != 0) try merge(gpa, l, play);
    }

    /// Rows come by champion within a player, so the same champion (on another
    /// platform, patch or start) is the last one
    fn merge(gpa: Allocator, l: *std.ArrayList(Play), play: Play) !void {
        if (l.items.len > 0 and l.items[l.items.len - 1].champion == play.champion) {
            const have = &l.items[l.items.len - 1];
            have.weight += play.weight;
            have.wins += play.wins;
        } else try l.append(gpa, play);
    }

    /// The player's plays into the tallies, then cleared for the next player
    fn flush(p: *Plays, st: *const Stats, out: []Tally, spreads: []spread.Tally) void {
        for (out, p.sets) |*t, *l| {
            t.add(st, l.items, .games);
            l.clearRetainingCapacity();
        }
        for (spreads, p.slices) |*s, *l| {
            for (l.items) |play| {
                if (st.index(play.champion)) |c| s.add(c, play.weight, play.wins, .{});
            }
            l.clearRetainingCapacity();
        }
    }
};

/// Champions a player has not played for this long are not in their pool: mastery
/// points are lifetime
const mastery_recent_s = 365 * std.time.s_per_day;

/// Every ladder player's champion mastery, by points, into out[i] for the platforms of
/// sets[i], in one pass
pub fn tallyMastery(
    gpa: Allocator,
    db: store.Db,
    st: *const Stats,
    sets: []const []const []const u8,
    out: []Tally,
) !void {
    const platform_json = try stats.setsJson(gpa, sets);
    defer gpa.free(platform_json);
    var q = try db.prepare(
        \\SELECT data, fetched_at, platform FROM mastery
        \\WHERE platform IN (SELECT value FROM json_each(?))
    );
    defer q.deinit();
    try q.bind(.{platform_json});
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    var plays: std.ArrayList(Play) = .empty;
    defer plays.deinit(gpa);
    while (try q.step()) {
        _ = arena_state.reset(.retain_capacity);
        const r = q.row(struct { data: []const u8, fetched_at: i64, platform: []const u8 });
        plays.clearRetainingCapacity();
        if (!try masteryPlays(arena_state.allocator(), gpa, r.data, r.fetched_at, &plays)) continue;
        const in = stats.setsWith(sets, r.platform);
        for (out, 0..) |*t, i| {
            if (in & (@as(u32, 1) << @intCast(i)) != 0) t.add(st, plays.items, .mastery);
        }
    }
}

/// A mastery row's champions played within mastery_recent_s, by points, into `plays`;
/// false when the blob doesn't decode (the row is left out)
pub fn masteryPlays(scratch: Allocator, gpa: Allocator, data: []const u8, fetched_at: i64, plays: *std.ArrayList(Play)) !bool {
    const entries = riot_mastery.decode(scratch, data, fetched_at) catch return false;
    for (entries) |e| {
        if (e.last_play < fetched_at - mastery_recent_s) continue;
        try plays.append(gpa, .{ .champion = e.champion, .weight = e.points });
    }
    return true;
}

/// Both sources' tallies, one per platform set
pub const Tallies = struct {
    games: []Tally,
    mastery: []Tally,
    spread: []spread.Tally,

    pub fn deinit(t: *Tallies, gpa: Allocator) void {
        freeTallies(gpa, t.games);
        freeTallies(gpa, t.mastery);
        for (t.spread) |*s| s.deinit(gpa);
        gpa.free(t.spread);
    }
};

fn initTallies(gpa: Allocator, n: usize, count: usize) ![]Tally {
    const out = try gpa.alloc(Tally, count);
    var made: usize = 0;
    errdefer freeTallies(gpa, out[0..made]);
    while (made < count) : (made += 1) out[made] = try .init(gpa, n);
    return out;
}

fn freeTallies(gpa: Allocator, ts: []Tally) void {
    for (ts) |*t| t.deinit(gpa);
    gpa.free(ts);
}

/// Tallies for each of `sets` (platform lists), and players' win rates in each of
/// `slices`' games, two passes over the database in all
pub fn tally(gpa: Allocator, db: store.Db, st: *const Stats, sets: []const []const []const u8, slices: []const stats.Slice) !Tallies {
    return tallyWith(gpa, db, st, sets, slices, null);
}

/// As tally; with `from`, games from the views partials and only the mastery rows
/// changed since they were read
pub fn tallyWith(
    gpa: Allocator,
    db: store.Db,
    st: *const Stats,
    sets: []const []const []const u8,
    slices: []const stats.Slice,
    from: ?*partials.Store,
) !Tallies {
    const games = try initTallies(gpa, st.n, sets.len);
    errdefer freeTallies(gpa, games);
    const mastery = try initTallies(gpa, st.n, sets.len);
    errdefer freeTallies(gpa, mastery);
    const spreads = try gpa.alloc(spread.Tally, slices.len);
    var made: usize = 0;
    errdefer {
        for (spreads[0..made]) |*s| s.deinit(gpa);
        gpa.free(spreads);
    }
    while (made < slices.len) : (made += 1) spreads[made] = try .init(gpa, st.n);
    if (from) |p| {
        try tallyGamesFrom(gpa, p, st, sets, slices, games, spreads);
        try p.masteryTallies(db, st, sets, mastery);
    } else {
        try tallyGames(gpa, db, st, sets, slices, games, spreads);
        try tallyMastery(gpa, db, st, sets, mastery);
    }
    return .{ .games = games, .mastery = mastery, .spread = spreads };
}

/// Build for sets[set] from the source with more players (mastery once it fills), in
/// `arena`
pub fn make(arena: Allocator, t: *const Tallies, set: usize, st: *const Stats, opts: Options) !Pool {
    const games = &t.games[set];
    const points = &t.mastery[set];
    const p = if (points.players > games.players)
        try build(arena, points, st, .mastery, opts)
    else
        try build(arena, games, st, .games, opts);
    var listed: usize = 0;
    for (p.mains) |m| listed += @intFromBool(m.players >= opts.min_players);
    log.info("{d} players from {s}, {d} champions with {d}+ mains", .{
        p.players, @tagName(p.source), listed, opts.min_players,
    });
    return p;
}

pub const Also = struct {
    id: u32,
    together: u32,
    lift: f64,
    /// Share of other players who play it
    base: f64,
};

/// A lane matchup from the main's side (or an option's), in its role
pub const Lane = struct { id: u32, pp: f64, games: u32 };

/// An option for the main's hard lanes, and the lanes it covers
pub const Cover = struct {
    id: u32,
    lift: f64,
    /// This option's matchups against the main's hard lanes it does well into
    lanes: []const Lane,
};

/// A stand-in for when the main is banned
pub const Fallback = struct {
    id: u32,
    together: u32,
    lift: f64,
    /// The main's good lanes this champion is also good into
    lanes: []const Lane,
};

pub const Main = struct {
    id: u32,
    players: u32,
    one_tricks: u32,
    /// Empty below Options.min_players
    also: []const Also = &.{},
    /// The main's most played role; null when it has no games this patch
    role: ?Role = null,
    hard: []const Lane = &.{},
    cover: []const Cover = &.{},
    fallback: []const Fallback = &.{},
};

pub const Pool = struct {
    source: Source = .games,
    patch: []const u8 = "",
    players: u32 = 0,
    min_players: u32 = 0,
    mains: []const Main = &.{},
};

/// Lists for every champion someone mains, most mained first, in `arena`
pub fn build(
    arena: Allocator,
    t: *const Tally,
    st: *const Stats,
    source: Source,
    opts: Options,
) !Pool {
    var mains: std.ArrayList(Main) = .empty;
    for (0..t.n) |m| {
        if (t.mains[m] == 0) continue;
        try mains.append(arena, try buildMain(arena, t, st, m, opts));
    }
    std.mem.sort(Main, mains.items, {}, struct {
        fn f(_: void, a: Main, b: Main) bool {
            return a.players > b.players;
        }
    }.f);
    return .{
        .source = source,
        .patch = st.patch,
        .players = t.players,
        .min_players = opts.min_players,
        .mains = mains.items,
    };
}

fn buildMain(arena: Allocator, t: *const Tally, st: *const Stats, m: usize, opts: Options) !Main {
    var out: Main = .{ .id = st.ids[m], .players = t.mains[m], .one_tricks = t.one_tricks[m] };
    if (t.mains[m] < opts.min_players) return out;

    var also: std.ArrayList(Also) = .empty;
    for (0..t.n) |o| {
        const k = t.together[m * t.n + o];
        if (o == m or k < opts.min_together) continue;
        const l = t.lift(m, o, opts.prior_players) orelse continue;
        if (l <= 1) continue;
        try also.append(arena, .{ .id = st.ids[o], .together = k, .lift = l, .base = t.base(o).? });
    }
    std.mem.sort(Also, also.items, {}, struct {
        fn f(_: void, a: Also, b: Also) bool {
            return a.lift > b.lift;
        }
    }.f);
    out.also = also.items[0..@min(also.items.len, opts.also_shown)];

    const r = mainRole(st, m) orelse return out;
    out.role = r;
    const lanes = try laneMatchups(arena, st, m, r, opts);
    var n_good: usize = 0;
    while (n_good < lanes.len and lanes[n_good].pp >= opts.min_lane_pp) n_good += 1;
    var n_hard: usize = 0;
    while (n_hard < lanes.len - n_good and lanes[lanes.len - 1 - n_hard].pp <= -opts.min_lane_pp) n_hard += 1;
    const good = lanes[0..@min(n_good, opts.lanes_shown)];
    var hard = lanes[lanes.len - @min(n_hard, opts.lanes_shown) ..];
    hard = try arena.dupe(Lane, hard);
    std.mem.reverse(Lane, hard);
    out.hard = hard;

    // Candidates: every champion mained players play more than usual, in the main's role
    var cover: std.ArrayList(Cover) = .empty;
    var fallback: std.ArrayList(Fallback) = .empty;
    for (also.items) |a| {
        const y = st.index(a.id).?;
        if (!playsRole(st, y, r, opts)) continue;
        const covers = try into(arena, st, y, r, hard, opts);
        if (covers.len > 0) {
            try cover.append(arena, .{ .id = a.id, .lift = a.lift, .lanes = covers });
        }
        const same = try into(arena, st, y, r, good, opts);
        if (same.len > 0) try fallback.append(arena, .{
            .id = a.id,
            .together = a.together,
            .lift = a.lift,
            .lanes = same,
        });
    }
    std.mem.sort(Cover, cover.items, {}, struct {
        fn f(_: void, a: Cover, b: Cover) bool {
            if (a.lanes.len != b.lanes.len) return a.lanes.len > b.lanes.len;
            return a.lift > b.lift;
        }
    }.f);
    std.mem.sort(Fallback, fallback.items, {}, struct {
        fn f(_: void, a: Fallback, b: Fallback) bool {
            if (a.lanes.len != b.lanes.len) return a.lanes.len > b.lanes.len;
            return a.lift > b.lift;
        }
    }.f);
    out.cover = cover.items[0..@min(cover.items.len, opts.options_shown)];
    out.fallback = fallback.items[0..@min(fallback.items.len, opts.options_shown)];
    return out;
}

fn mainRole(st: *const Stats, c: usize) ?Role {
    var best: ?Role = null;
    var most: u32 = 0;
    for (Role.all) |r| {
        const g = st.champRole(r, c).games;
        if (g > most) {
            most = g;
            best = r;
        }
    }
    return best;
}

fn playsRole(st: *const Stats, c: usize, r: Role, opts: Options) bool {
    const g: f64 = @floatFromInt(st.champRole(r, c).games);
    return g >= @as(f64, @floatFromInt(opts.min_pair_games)) and
        g >= opts.min_role_share * @as(f64, @floatFromInt(st.champGames(c)));
}

/// `c`'s lane matchups in `r` with enough games, best first
fn laneMatchups(arena: Allocator, st: *const Stats, c: usize, r: Role, opts: Options) ![]Lane {
    var list: std.ArrayList(Lane) = .empty;
    for (0..st.n) |e| {
        if (e == c) continue;
        const games = st.enemy(r, r, c, e).games;
        if (games < opts.min_pair_games) continue;
        try list.append(arena, .{
            .id = st.ids[e],
            .pp = score.matchupPp(st, opts.score, r, c, r, e),
            .games = games,
        });
    }
    std.mem.sort(Lane, list.items, {}, struct {
        fn f(_: void, a: Lane, b: Lane) bool {
            return a.pp > b.pp;
        }
    }.f);
    return list.items;
}

/// `y`'s matchups in `r` against those of `enemies` it does well into
fn into(
    arena: Allocator,
    st: *const Stats,
    y: usize,
    r: Role,
    enemies: []const Lane,
    opts: Options,
) ![]const Lane {
    var list: std.ArrayList(Lane) = .empty;
    for (enemies) |en| {
        const e = st.index(en.id).?;
        if (e == y) continue;
        const games = st.enemy(r, r, y, e).games;
        if (games < opts.min_pair_games) continue;
        const pp = score.matchupPp(st, opts.score, r, y, r, e);
        if (pp >= opts.min_lane_pp) try list.append(arena, .{ .id = en.id, .pp = pp, .games = games });
    }
    return list.items;
}

/// data/pool.json for the site: ids, counts and percentage points rounded for size
pub fn writeJson(w: *std.Io.Writer, p: Pool) !void {
    try w.print("{{\"source\":\"{s}\",\"patch\":", .{@tagName(p.source)});
    try std.json.Stringify.value(p.patch, .{}, w);
    try w.print(",\"players\":{d},\"min_players\":{d},\"mains\":[", .{ p.players, p.min_players });
    for (p.mains, 0..) |m, i| {
        if (i > 0) try w.writeByte(',');
        try w.print("{{\"id\":{d},\"players\":{d},\"one_tricks\":{d}", .{ m.id, m.players, m.one_tricks });
        if (m.role) |r| try w.print(",\"role\":\"{s}\"", .{@tagName(r)});
        if (m.also.len > 0) {
            try w.writeAll(",\"also\":[");
            for (m.also, 0..) |a, j| {
                if (j > 0) try w.writeByte(',');
                try w.print("[{d},{d},{d:.2},{d:.3}]", .{ a.id, a.together, a.lift, a.base });
            }
            try w.writeByte(']');
        }
        if (m.hard.len > 0) {
            try w.writeAll(",\"hard\":");
            try lanesJson(w, m.hard);
        }
        if (m.cover.len > 0) {
            try w.writeAll(",\"cover\":[");
            for (m.cover, 0..) |c, j| {
                if (j > 0) try w.writeByte(',');
                try w.print("{{\"id\":{d},\"lift\":{d:.2},\"lanes\":", .{ c.id, c.lift });
                try lanesJson(w, c.lanes);
                try w.writeByte('}');
            }
            try w.writeByte(']');
        }
        if (m.fallback.len > 0) {
            try w.writeAll(",\"fallback\":[");
            for (m.fallback, 0..) |f, j| {
                if (j > 0) try w.writeByte(',');
                try w.print("{{\"id\":{d},\"together\":{d},\"lift\":{d:.2},\"lanes\":", .{ f.id, f.together, f.lift });
                try lanesJson(w, f.lanes);
                try w.writeByte('}');
            }
            try w.writeByte(']');
        }
        try w.writeByte('}');
    }
    try w.writeAll("]}\n");
}

/// [[id, pp, games], ...]
fn lanesJson(w: *std.Io.Writer, lanes: []const Lane) !void {
    try w.writeByte('[');
    for (lanes, 0..) |l, i| {
        if (i > 0) try w.writeByte(',');
        try w.print("[{d},{d:.1},{d}]", .{ l.id, l.pp, l.games });
    }
    try w.writeByte(']');
}

const testing = std.testing;

/// Champions 1..n and fillers 100..107; each game is (blue top, red top, winner) with
/// the fillers in the other roles. In `arena`: Stats borrows the file bytes
fn testStats(arena: Allocator, n: u32, games: []const struct { u32, u32, u1 }) !Stats {
    var champs: std.ArrayList(core.statsfile.Champion) = .empty;
    for (1..n + 1) |id| try champs.append(arena, .{ .id = @intCast(id), .name = "x" });
    for (100..108) |id| try champs.append(arena, .{ .id = @intCast(id), .name = "f" });
    var b: core.statsfile.Builder = try .init(arena, champs.items);
    for (games) |g| b.addGame(.{
        .{ g[0], 100, 101, 102, 103 },
        .{ g[1], 104, 105, 106, 107 },
    }, g[2]);
    var aw: std.Io.Writer.Allocating = .init(arena);
    try b.write(&aw.writer, "16.20");
    return .parse(arena, aw.written());
}

test "lift over popularity, shrunk for small n" {
    const gpa = testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const st = try testStats(arena_state.allocator(), 4, &.{.{ 1, 2, 0 }});
    var t: Tally = try .init(gpa, st.n);
    defer t.deinit(gpa);
    // 10 players main 1 and also play 2; 90 main 3, of whom 9 play 2 and all play 4
    for (0..10) |_| t.add(&st, &.{ .{ .champion = 1, .weight = 20 }, .{ .champion = 2, .weight = 5 } }, .games);
    for (0..90) |i| {
        const two: u32 = if (i < 9) 5 else 0;
        t.add(&st, &.{
            .{ .champion = 3, .weight = 20 },
            .{ .champion = 2, .weight = two },
            .{ .champion = 4, .weight = 4 },
            .{ .champion = 999, .weight = 50 }, // not in stats
        }, .games);
    }
    t.add(&st, &.{.{ .champion = 1, .weight = 5 }}, .games); // too few games
    t.add(&st, &.{ .{ .champion = 3, .weight = 30 }, .{ .champion = 4, .weight = 2 } }, .games);
    const one = st.index(1).?;
    const two = st.index(2).?;
    const three = st.index(3).?;
    const four = st.index(4).?;
    try testing.expectEqual(101, t.players);
    try testing.expectEqual(10, t.mains[one]);
    try testing.expectEqual(91, t.mains[three]);
    try testing.expectEqual(90, t.plays[four]); // the last player's 2 games are under 10%
    try testing.expectEqual(91 + 10, t.one_tricks[three] + t.one_tricks[one]);
    // 19 of 101 players play 2; all 10 of 1's do: raw lift 101/19
    const raw = t.lift(one, two, 0).?;
    try testing.expectApproxEqAbs(101.0 / 19.0, raw, 1e-9);
    const shrunk = t.lift(one, two, 20).?;
    try testing.expect(shrunk > 1.5 and shrunk < raw);
    try testing.expect(t.lift(one, four, 20).? < 1);
    try testing.expectEqual(null, t.lift(one, st.index(100).?, 20));
}

test "options cover the main's hard lanes; fallbacks share its good ones" {
    const gpa = testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var games: std.ArrayList(struct { u32, u32, u1 }) = .empty;
    // Top: 1 (the main) loses to 4 and beats 5; 2 beats 4; 3 beats 5 (and loses to 6,
    // so its own rating does not already explain that)
    for (0..2000) |i| {
        const win30: u1 = @intFromBool(i % 10 < 7);
        const win70: u1 = @intFromBool(i % 10 >= 7);
        const win80: u1 = @intFromBool(i % 10 >= 8);
        try games.append(arena, .{ 1, 4, win30 });
        try games.append(arena, .{ 1, 5, win80 });
        try games.append(arena, .{ 2, 4, win70 });
        try games.append(arena, .{ 3, 5, win80 });
        try games.append(arena, .{ 2, 3, @intCast(i % 2) });
        try games.append(arena, .{ 6, 3, win70 });
    }
    const st = try testStats(arena, 6, games.items);
    var t: Tally = try .init(gpa, st.n);
    defer t.deinit(gpa);
    for (0..40) |_| t.add(&st, &.{
        .{ .champion = 1, .weight = 30 },
        .{ .champion = 2, .weight = 8 },
        .{ .champion = 3, .weight = 8 },
        .{ .champion = 6, .weight = 8 },
    }, .games);
    for (0..60) |_| t.add(&st, &.{ .{ .champion = 4, .weight = 30 }, .{ .champion = 5, .weight = 3 } }, .games);
    for (0..10) |_| t.add(&st, &.{.{ .champion = 2, .weight = 30 }}, .games); // under min_players

    // Fixture sized for the pre-17 Oct priors: its lanes sit near the thresholds
    const old_priors: score.Options = .{ .base_prior_games = 1000, .prior_games = 1000, .weights = .{} };
    const p = try build(arena, &t, &st, .games, .{ .score = old_priors });
    try testing.expectEqual(110, p.players);
    const m = p.mains[1];
    try testing.expectEqual(1, m.id);
    try testing.expectEqual(Role.top, m.role.?);
    try testing.expectEqual(4, m.hard[0].id);
    try testing.expect(m.hard[0].pp < 0);
    try testing.expectEqual(1, m.cover.len);
    try testing.expectEqual(2, m.cover[0].id);
    try testing.expectEqual(4, m.cover[0].lanes[0].id);
    try testing.expectEqual(1, m.fallback.len);
    try testing.expectEqual(3, m.fallback[0].id);
    try testing.expectEqual(5, m.fallback[0].lanes[0].id);
    const thin = p.mains[2];
    try testing.expectEqual(2, thin.id);
    try testing.expectEqual(0, thin.also.len);

    var aw: std.Io.Writer.Allocating = .init(arena);
    try writeJson(&aw.writer, p);
    const parsed = try std.json.parseFromSliceLeaky(std.json.Value, arena, aw.written(), .{});
    try testing.expectEqualStrings("games", parsed.object.get("source").?.string);
    try testing.expectEqual(3, parsed.object.get("mains").?.array.items.len);
}

test "mastery: points as weight, stale and small champions left out" {
    const gpa = testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const st = try testStats(arena, 4, &.{.{ 1, 2, 0 }});
    const db = try store.schema.memory();
    defer db.close();
    const now: i64 = 1_800_000_000;
    const old = now - 2 * mastery_recent_s;
    const players = [_]struct { []const u8, []const riot_mastery.Entry }{
        // Mains 1, plays 2; 3 is stale, 4 too few points
        .{ "EUW1", &.{
            .{ .champion = 1, .level = 10, .points = 200_000, .last_play = now },
            .{ .champion = 2, .level = 7, .points = 40_000, .last_play = now },
            .{ .champion = 3, .level = 9, .points = 150_000, .last_play = old },
            .{ .champion = 4, .level = 2, .points = 5_000, .last_play = now },
        } },
        // Under min_total
        .{ "EUW1", &.{.{ .champion = 2, .level = 4, .points = 30_000, .last_play = now }} },
        // Other platform
        .{ "KR", &.{.{ .champion = 2, .level = 9, .points = 90_000, .last_play = now }} },
    };
    for (players, 0..) |p, i| {
        const blob = try riot_mastery.encode(arena, p[1], now);
        const puuid = try arena.print("p{d}", .{i});
        try db.run("INSERT INTO mastery VALUES (?,?,?,?,?)", .{
            puuid, p[0], now, p[1].len, store.Blob{ .bytes = blob },
        });
    }
    var both = try tally(gpa, db, &st, &.{ &.{"EUW1"}, &.{ "EUW1", "KR" } }, &.{});
    defer both.deinit(gpa);
    try testing.expectEqual(2, both.mastery[1].players);
    const t = both.mastery[0];
    try testing.expectEqual(1, t.players);
    try testing.expectEqual(1, t.mains[st.index(1).?]);
    try testing.expectEqual(1, t.one_tricks[st.index(1).?]); // 200k of 245k recent
    try testing.expectEqual(1, t.plays[st.index(2).?]);
    try testing.expectEqual(0, t.plays[st.index(3).?]);
    try testing.expectEqual(0, t.plays[st.index(4).?]);
}

test "games: one pass for several platform sets, a champion summed across platforms; spreads by slice" {
    const gpa = testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const st = try testStats(arena, 4, &.{.{ 1, 2, 0 }});
    const db = try store.schema.memory();
    defer db.close();
    try db.exec("INSERT INTO players (puuid, source) VALUES ('a','t')");
    // 'a': champion 1 six times on EUW1 and five on KR, champion 2 three times on KR
    for (0..14) |g| {
        const platform: []const u8 = if (g < 6) "EUW1" else "KR";
        const id = try arena.print("{s}_{d}", .{ platform, g });
        try db.run("INSERT INTO matches VALUES (?,'t',?,420,'16.20','',?,1600,100,0)", .{ id, platform, g });
        const champ: i64 = if (g < 11) 1 else 2;
        try db.run(
            \\INSERT INTO participants (match_id, slot, team_id, puuid, champion_id, position, win)
            \\VALUES (?,0,100,'a',?,'TOP',1)
        , .{ id, champ });
    }
    // Spreads: every game, and from game 6 (KR's only: 5 games of champion 1, too few)
    const slices = [_]stats.Slice{
        .{ .platforms = &.{ "EUW1", "KR" } },
        .{ .platforms = &.{ "EUW1", "KR" }, .since_ms = 6 },
    };
    var t = try tally(gpa, db, &st, &.{ &.{"EUW1"}, &.{ "EUW1", "KR" } }, &slices);
    defer t.deinit(gpa);
    try testing.expectEqual(1, t.spread[0].players[st.index(1).? * 101 + 100]);
    for (t.spread[1].players) |n| try testing.expectEqual(0, n);
    try testing.expectEqual(0, t.games[0].players); // 6 games: too new to say
    const all = t.games[1];
    try testing.expectEqual(1, all.players);
    try testing.expectEqual(1, all.one_tricks[st.index(1).?]); // 11 of 14
    try testing.expectEqual(1, all.plays[st.index(2).?]);
}
