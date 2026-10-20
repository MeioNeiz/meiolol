//! `meiolol builds`: what players build per champion and role, as lolalytics shows it:
//! rune pages, summoner spells (participants), starting items, boots, the first finished
//! items in purchase order and skill priority (compact timelines). Written as a JSON file
//! (`File`) that `meiolol site` turns into build pages (src/site/builds.zig).
//!
//! Memory is bounded by Options.max_keys distinct options, whatever the number of games:
//! past it the rarest options (counts at or under a rising floor) are dropped. Shares use
//! totals that are never dropped, so only options far below any shown row lose games.

const std = @import("std");
const store = @import("store");
const core = @import("core");
const timeline = @import("riot/timeline.zig");
const digest = @import("riot/digest.zig");
const ddragon = @import("ddragon.zig");
const stats = @import("stats.zig");

const Role = core.Role;
const log = std.log.scoped(.builds);

pub const Kind = enum {
    /// [keystone]
    keystone,
    /// [primary tree, keystone, 3 primary runes, secondary tree, 2 secondary runes]
    runes,
    /// [offense, flex, defense]
    shards,
    /// [lower id, higher id]: Flash on D or F is the same pair
    spells,
    /// Items bought in the first start_ms, sorted, net of undos and sales; trinkets out
    start,
    /// [tier-2 boots] (tier 3 counts as the tier 2 it upgrades), [0] for none by the
    /// second finished item
    boots,
    /// First two finished items in purchase order
    core2,
    /// First three
    core3,
    /// Basic ability slots (1 Q, 2 W, 3 E) by points after 13 skill-ups (or the game's
    /// end, from 11), ties by who got there first
    skills,
    /// Ability slots of the first three skill-ups (levels 1 to 3)
    skill_start,

    pub fn fromTimeline(k: Kind) bool {
        return @backingInt(k) >= @backingInt(Kind.start);
    }
};

pub const max_values = 8;
/// What `builds --site` writes per lane opponent: matchups with this many games, this
/// many options per kind
pub const min_matchup_games = 300;
const matchup_rows = 3;
/// Starting items: bought before this many ms
pub const start_ms = 90_000;
const skill_snapshot = 13;
const min_skill_ups = 11;

pub const Options = struct {
    /// Empty: any
    patches: []const []const u8,
    /// Riot ms; 0 for any
    since_ms: i64 = 0,
    platforms: []const []const u8,
    /// Lowest tier counted (participants.tier: the player's ladder rank when the game was
    /// stored); null counts everyone, unranked too
    min_tier: ?[]const u8 = "PLATINUM",
    /// Distinct options held in memory (~50 bytes each)
    max_keys: usize = 1 << 19,
    /// Options written per champion, role and kind, most played first
    rows: usize = 10,
    /// Distinct matchup options held (Builder.vs): at 1 << 22 the box's 16.20 run kept its
    /// floor at 1 in 1.1 GB (1 << 20: floor 12)
    max_matchup_keys: usize = 1 << 22,
    /// Matchups (champion, role and lane opponent) written: those with this many games
    /// or more; null for none
    min_matchup_games: ?u32 = null,
};

pub const Count = struct { games: u32 = 0, wins: u32 = 0 };

/// The file the site reads
pub const File = struct {
    /// "16.20"
    label: []const u8,
    /// "PLATINUM", "" for every rank
    min_tier: []const u8,
    /// Games read, and those with a timeline
    games: u32,
    timelines: u32,
    items: []const ddragon.Named,
    runes: []const ddragon.Named,
    spells: []const ddragon.Named,
    /// Rune trees for the pages' rune view; every rune in them is in `runes`. Empty in
    /// files from before 20 Oct 2026
    trees: []const ddragon.Tree = &.{},
    /// Sorted by champion, then role
    builds: []const Build,
    /// Per lane opponent, sorted by champion, role, then opponent; only matchup_kinds.
    /// Empty in files from before 20 Oct 2026
    matchups: []const Build = &.{},

    pub const Build = struct {
        champion: u32,
        role: Role,
        /// Lane opponent's champion in `matchups`, 0 in `builds`
        opponent: u32 = 0,
        /// Players counted (champion, role, rank floor) and their wins
        games: u32,
        wins: u32,
        kinds: []const Rows,

        pub fn get(b: Build, kind: Kind) ?Rows {
            for (b.kinds) |r| if (r.kind == kind) return r;
            return null;
        }
    };
    /// games and wins: every player with a value of this kind (the share's whole)
    pub const Rows = struct { kind: Kind, games: u32, wins: u32, options: []const Option };
    pub const Option = struct { v: []const u32, games: u32, wins: u32 };

    pub fn get(f: *const File, champion: u32, role: Role) ?Build {
        const i = std.sort.binarySearch(Build, f.builds, BuildKey{ .champion = champion, .role = role }, BuildKey.order) orelse return null;
        return f.builds[i];
    }

    pub fn getVs(f: *const File, champion: u32, role: Role, opponent: u32) ?Build {
        const key: BuildKey = .{ .champion = champion, .role = role, .opponent = opponent };
        const i = std.sort.binarySearch(Build, f.matchups, key, BuildKey.order) orelse return null;
        return f.matchups[i];
    }

    pub fn parse(arena: std.mem.Allocator, bytes: []const u8) !File {
        return std.json.parseFromSliceLeaky(File, arena, bytes, .{ .ignore_unknown_fields = true });
    }
};

const BuildKey = struct {
    champion: u32,
    role: Role,
    opponent: u32 = 0,

    fn order(k: BuildKey, b: File.Build) std.math.Order {
        const c = std.math.order(k.champion, b.champion);
        if (c != .eq) return c;
        const r = std.math.order(@backingInt(k.role), @backingInt(b.role));
        return if (r != .eq) r else std.math.order(k.opponent, b.opponent);
    }
};

/// Kinds counted per lane opponent; keystone, spells and skill_start only role-wide
pub const matchup_kinds = [_]Kind{ .runes, .shards, .start, .boots, .core2, .core3, .skills };

const Key = struct { champion: u16, role: Role, opponent: u16 = 0, kind: Kind, v: [max_values]u32 };
const Total = struct { champion: u16, role: Role, opponent: u16 = 0, kind: ?Kind };

pub const Builder = struct {
    gpa: std.mem.Allocator,
    max_keys: usize,
    options: std.AutoHashMapUnmanaged(Key, Count) = .empty,
    /// Per champion and role (kind null) and per kind
    totals: std.AutoHashMapUnmanaged(Total, Count) = .empty,
    /// Options at or under this count were dropped
    floor: u32 = 0,
    dropped_games: u64 = 0,
    games: u32 = 0,
    timelines: u32 = 0,
    /// Per lane opponent, own pruning floor so matchups never push role-wide options out;
    /// owned
    vs: ?*Builder = null,
    /// Matchups below this many games are left out of the file
    min_matchup_games: u32 = 0,
    /// This builder counts per opponent (Player.opponent, 0: skipped) and matchup_kinds
    per_opponent: bool = false,

    pub fn deinit(b: *Builder) void {
        b.options.deinit(b.gpa);
        b.totals.deinit(b.gpa);
        if (b.vs) |v| {
            v.deinit();
            b.gpa.destroy(v);
        }
    }

    /// Starts counting per lane opponent beside the role-wide counts
    pub fn countMatchups(b: *Builder, max_keys: usize, min_games: u32) !void {
        const v = try b.gpa.create(Builder);
        v.* = .{ .gpa = b.gpa, .max_keys = @max(max_keys, 2), .per_opponent = true };
        b.vs = v;
        b.min_matchup_games = min_games;
    }

    fn total(b: *Builder, t: Total, won: bool) !void {
        const e = try b.totals.getOrPut(b.gpa, t);
        if (!e.found_existing) e.value_ptr.* = .{};
        e.value_ptr.games += 1;
        e.value_ptr.wins += @intFromBool(won);
    }

    pub fn add(b: *Builder, champion: u32, role: Role, kind: Kind, v: []const u32, won: bool) !void {
        try b.addVs(champion, role, 0, kind, v, won);
    }

    fn addVs(b: *Builder, champion: u32, role: Role, opponent: u16, kind: Kind, v: []const u32, won: bool) !void {
        const c: u16 = @intCast(champion);
        if (b.per_opponent and std.mem.indexOfScalar(Kind, &matchup_kinds, kind) == null) return;
        try b.total(.{ .champion = c, .role = role, .opponent = opponent, .kind = kind }, won);
        var key: Key = .{ .champion = c, .role = role, .opponent = opponent, .kind = kind, .v = @splat(0) };
        @memcpy(key.v[0..v.len], v);
        if (b.options.count() >= b.max_keys and !b.options.contains(key)) try b.prune();
        const e = try b.options.getOrPut(b.gpa, key);
        if (!e.found_existing) e.value_ptr.* = .{};
        e.value_ptr.games += 1;
        e.value_ptr.wins += @intFromBool(won);
    }

    /// Drops the rarest options until at most half of max_keys are left
    fn prune(b: *Builder) !void {
        while (b.options.count() > b.max_keys / 2) {
            b.floor += 1;
            var kept: std.AutoHashMapUnmanaged(Key, Count) = .empty;
            errdefer kept.deinit(b.gpa);
            var it = b.options.iterator();
            while (it.next()) |e| {
                if (e.value_ptr.games > b.floor) {
                    try kept.put(b.gpa, e.key_ptr.*, e.value_ptr.*);
                } else b.dropped_games += e.value_ptr.games;
            }
            b.options.deinit(b.gpa);
            b.options = kept;
        }
        log.info("{s}dropped options with {d} or fewer games ({d} games in all)", .{
            if (b.per_opponent) "matchups: " else "", b.floor, b.dropped_games,
        });
    }

    /// One player: their participants row and, with a timeline, their picks
    pub fn addPlayer(b: *Builder, p: Player, chosen: ?Picks, d: *const ddragon.BuildData) !void {
        if (b.vs) |v| if (p.opponent != 0) try v.addPlayer(p, chosen, d);
        const c: u16 = @intCast(p.champion);
        const opp: u16 = if (b.per_opponent) @intCast(p.opponent) else 0;
        if (b.per_opponent and opp == 0) return;
        try b.total(.{ .champion = c, .role = p.role, .opponent = opp, .kind = null }, p.won);
        if (p.keystone != 0) {
            try b.addVs(p.champion, p.role, opp, .keystone, &.{p.keystone}, p.won);
            try b.addVs(p.champion, p.role, opp, .runes, &.{
                p.primary,  p.keystone,  p.perks[0],                   p.perks[1],
                p.perks[2], p.secondary, @min(p.perks[3], p.perks[4]), @max(p.perks[3], p.perks[4]),
            }, p.won);
        }
        if (p.shards[0] != 0) try b.addVs(p.champion, p.role, opp, .shards, &p.shards, p.won);
        if (p.spells[0] != 0) try b.addVs(p.champion, p.role, opp, .spells, &.{
            @min(p.spells[0], p.spells[1]), @max(p.spells[0], p.spells[1]),
        }, p.won);
        const k = chosen orelse return;
        if (!k.start_overflow and k.start_len > 0) {
            var start = k.start;
            std.mem.sort(u32, start[0..k.start_len], {}, std.sort.asc(u32));
            try b.addVs(p.champion, p.role, opp, .start, start[0..k.start_len], p.won);
        }
        if (k.boots != 0 or k.core_len >= 2) {
            const boots = if (k.boots != 0) d.bootsOf(k.boots) orelse 0 else 0;
            try b.addVs(p.champion, p.role, opp, .boots, &.{boots}, p.won);
        }
        if (k.core_len >= 2) try b.addVs(p.champion, p.role, opp, .core2, k.core[0..2], p.won);
        if (k.core_len >= 3) try b.addVs(p.champion, p.role, opp, .core3, k.core[0..3], p.won);
        if (k.skillOrder()) |order| try b.addVs(p.champion, p.role, opp, .skills, &order, p.won);
        if (k.skill_ups >= 3) try b.addVs(p.champion, p.role, opp, .skill_start, &.{ k.first[0], k.first[1], k.first[2] }, p.won);
    }

    /// The file, in `arena`: `rows` options per champion, role and kind, and the names
    /// of what they use
    pub fn file(b: *const Builder, arena: std.mem.Allocator, d: *const ddragon.BuildData, label: []const u8, min_tier: []const u8, rows: usize) !File {
        var used: [3]std.AutoArrayHashMapUnmanaged(u32, void) = @splat(.empty);
        const builds = try b.fileBuilds(arena, &used, rows, 0);
        const matchups = if (b.vs) |v| try v.fileBuilds(arena, &used, @min(rows, matchup_rows), b.min_matchup_games) else &.{};
        for (d.trees) |t| {
            try used[1].put(arena, t.id, {});
            for (t.slots) |slot| for (slot) |id| try used[1].put(arena, id, {});
        }
        var named: [3]std.ArrayList(ddragon.Named) = @splat(.empty);
        for (used, &named, [_][]const ddragon.Named{ d.items, d.runes, d.spells }) |ids, *out, list| {
            for (ids.keys()) |id| if (ddragon.find(list, id)) |n| try out.append(arena, n);
            std.mem.sort(ddragon.Named, out.items, {}, struct {
                fn f(_: void, x: ddragon.Named, y: ddragon.Named) bool {
                    return x.id < y.id;
                }
            }.f);
        }
        return .{
            .label = label,
            .min_tier = min_tier,
            .games = b.games,
            .timelines = b.timelines,
            .items = named[0].items,
            .runes = named[1].items,
            .spells = named[2].items,
            .trees = d.trees,
            .builds = builds,
            .matchups = matchups,
        };
    }

    /// Champion, role and opponent groups with `min_games` or more, adding the ids their
    /// options use to `used`
    fn fileBuilds(b: *const Builder, arena: std.mem.Allocator, used: *[3]std.AutoArrayHashMapUnmanaged(u32, void), rows: usize, min_games: u32) ![]const File.Build {
        const Entry = struct { key: Key, count: Count };
        var entries: std.ArrayList(Entry) = .empty;
        var it = b.options.iterator();
        while (it.next()) |e| try entries.append(arena, .{ .key = e.key_ptr.*, .count = e.value_ptr.* });
        std.mem.sort(Entry, entries.items, {}, struct {
            fn f(_: void, x: Entry, y: Entry) bool {
                if (x.key.champion != y.key.champion) return x.key.champion < y.key.champion;
                if (x.key.role != y.key.role) return @backingInt(x.key.role) < @backingInt(y.key.role);
                if (x.key.opponent != y.key.opponent) return x.key.opponent < y.key.opponent;
                if (x.key.kind != y.key.kind) return @backingInt(x.key.kind) < @backingInt(y.key.kind);
                if (x.count.games != y.count.games) return x.count.games > y.count.games;
                return std.mem.order(u32, &x.key.v, &y.key.v) == .lt;
            }
        }.f);

        var builds: std.ArrayList(File.Build) = .empty;
        var kinds: std.ArrayList(File.Rows) = .empty;
        var options: std.ArrayList(File.Option) = .empty;
        var i: usize = 0;
        while (i < entries.items.len) {
            const first = entries.items[i].key;
            const group = struct {
                fn same(x: Key, y: Key) bool {
                    return x.champion == y.champion and x.role == y.role and x.opponent == y.opponent;
                }
            }.same;
            const all = b.totals.get(.{ .champion = first.champion, .role = first.role, .opponent = first.opponent, .kind = null }) orelse Count{};
            if (all.games < min_games) {
                while (i < entries.items.len and group(entries.items[i].key, first)) i += 1;
                continue;
            }
            kinds = .empty;
            while (i < entries.items.len and group(entries.items[i].key, first)) {
                const kind = entries.items[i].key.kind;
                const t = b.totals.get(.{ .champion = first.champion, .role = first.role, .opponent = first.opponent, .kind = kind }) orelse Count{};
                options = .empty;
                while (i < entries.items.len) : (i += 1) {
                    const e = entries.items[i];
                    if (!group(e.key, first) or e.key.kind != kind) break;
                    if (options.items.len == rows) continue;
                    const v = try arena.dupe(u32, e.key.v[0..valueLen(kind, e.key.v)]);
                    if (nameList(kind)) |list| for (v) |x| {
                        if (x != 0) try used[list].put(arena, x, {});
                    };
                    try options.append(arena, .{ .v = v, .games = e.count.games, .wins = e.count.wins });
                }
                try kinds.append(arena, .{ .kind = kind, .games = t.games, .wins = t.wins, .options = options.items });
            }
            try builds.append(arena, .{
                .champion = first.champion,
                .role = first.role,
                .opponent = first.opponent,
                .games = all.games,
                .wins = all.wins,
                .kinds = kinds.items,
            });
        }
        return builds.items;
    }
};

/// 0: items, 1: runes, 2: summoner spells; skills are ability slots
fn nameList(kind: Kind) ?usize {
    return switch (kind) {
        .keystone, .runes, .shards => 1,
        .spells => 2,
        .start, .boots, .core2, .core3 => 0,
        .skills, .skill_start => null,
    };
}

fn valueLen(kind: Kind, v: [max_values]u32) usize {
    return switch (kind) {
        .keystone, .boots => 1,
        .runes => 8,
        .shards, .core3, .skills, .skill_start => 3,
        .spells, .core2 => 2,
        .start => std.mem.indexOfScalar(u32, &v, 0) orelse max_values,
    };
}

/// A participants row
pub const Player = struct {
    champion: u32,
    role: Role,
    won: bool,
    keystone: u32 = 0,
    primary: u32 = 0,
    secondary: u32 = 0,
    perks: [5]u32 = @splat(0),
    shards: [3]u32 = @splat(0),
    spells: [2]u32 = @splat(0),
    /// Lane opponent's champion: the other team's player in the same role; 0 for none
    opponent: u32 = 0,
};

/// One player's choices from a timeline
pub const Picks = struct {
    start: [max_values]u32 = @splat(0),
    start_len: u8 = 0,
    start_overflow: bool = false,
    /// First boots bought, the item itself (BuildData.bootsOf gives the choice)
    boots: u32 = 0,
    core: [3]u32 = @splat(0),
    core_len: u8 = 0,
    /// Q, W, E, R
    points: [4]u8 = @splat(0),
    reached_ms: [4]i64 = @splat(0),
    skill_ups: u8 = 0,
    /// Slots of the first three skill-ups
    first: [3]u8 = @splat(0),

    fn removeStart(p: *Picks, item: u32) void {
        const i = std.mem.indexOfScalar(u32, p.start[0..p.start_len], item) orelse return;
        p.start_len -= 1;
        p.start[i] = p.start[p.start_len];
        p.start[p.start_len] = 0;
    }

    pub fn skillOrder(p: Picks) ?[3]u32 {
        if (p.skill_ups < min_skill_ups) return null;
        var order = [3]u32{ 1, 2, 3 };
        std.mem.sort(u32, &order, p, struct {
            fn f(k: Picks, x: u32, y: u32) bool {
                if (k.points[x - 1] != k.points[y - 1]) return k.points[x - 1] > k.points[y - 1];
                return k.reached_ms[x - 1] < k.reached_ms[y - 1];
            }
        }.f);
        return order;
    }
};

/// Every participant's picks; out[participant id - 1]
pub fn picks(t: timeline.Timeline, d: *const ddragon.BuildData, out: []Picks) void {
    @memset(out, .{});
    for (t.events) |e| switch (e.data) {
        .item_purchased => |b| {
            const p = at(out, b.participant) orelse continue;
            if (e.t_ms < start_ms and !d.isTrinket(b.item)) {
                if (p.start_len == max_values) {
                    p.start_overflow = true;
                } else {
                    p.start[p.start_len] = b.item;
                    p.start_len += 1;
                }
            }
            if (p.boots == 0 and d.bootsOf(b.item) != null) p.boots = b.item;
            if (p.core_len < 3 and d.isLegendary(b.item)) {
                p.core[p.core_len] = b.item;
                p.core_len += 1;
            }
        },
        .item_sold => |s| {
            const p = at(out, s.participant) orelse continue;
            if (e.t_ms < start_ms) p.removeStart(s.item);
        },
        // Undoing a purchase: before = the item, after = 0 (after set: an undone sale)
        .item_undo => |u| {
            const p = at(out, u.participant) orelse continue;
            if (u.before == 0 or u.after != 0) continue;
            if (e.t_ms < start_ms) p.removeStart(u.before);
            if (p.boots == u.before) p.boots = 0;
            if (p.core_len > 0 and p.core[p.core_len - 1] == u.before) {
                p.core_len -= 1;
                p.core[p.core_len] = 0;
            }
        },
        .skill_level_up => |s| {
            const p = at(out, s.participant) orelse continue;
            // EVOLVE: Kai'Sa, Kha'Zix and the like upgrading an ability, not a point
            if (s.slot < 1 or s.slot > 4 or std.mem.eql(u8, s.type, "EVOLVE")) continue;
            if (p.skill_ups == skill_snapshot) continue;
            if (p.skill_ups < 3) p.first[p.skill_ups] = s.slot;
            p.skill_ups += 1;
            p.points[s.slot - 1] += 1;
            p.reached_ms[s.slot - 1] = e.t_ms;
        },
        else => {},
    };
}

fn at(out: []Picks, participant: u8) ?*Picks {
    if (participant == 0 or participant > out.len) return null;
    return &out[participant - 1];
}

/// Every ranked solo game (no remake, a winner) of `o.patches` from `o.platforms`, with
/// its timeline where there is one. Caller owns the builder
pub fn build(gpa: std.mem.Allocator, io: std.Io, db: store.Db, d: *const ddragon.BuildData, o: Options) !Builder {
    var b: [1]Builder = undefined;
    try buildEach(gpa, io, db, d, o, &.{o.platforms}, &b);
    return b[0];
}

/// As build, one builder per platform set in `sets` (each within o.platforms), every
/// timeline read once: EUW's and every region's files in one pass. Caller owns `out`
pub fn buildEach(
    gpa: std.mem.Allocator,
    io: std.Io,
    db: store.Db,
    d: *const ddragon.BuildData,
    o: Options,
    sets: []const []const []const u8,
    out: []Builder,
) !void {
    std.debug.assert(sets.len == out.len and sets.len <= max_sets);
    for (out) |*b| b.* = .{ .gpa = gpa, .max_keys = @max(o.max_keys, 2) };
    errdefer for (out) |*b| b.deinit();
    if (o.min_matchup_games) |min| for (out) |*b| try b.countMatchups(o.max_matchup_keys, min);
    const patch_json = try std.json.Stringify.valueAlloc(gpa, o.patches, .{});
    defer gpa.free(patch_json);
    const platform_json = try std.json.Stringify.valueAlloc(gpa, o.platforms, .{});
    defer gpa.free(platform_json);
    const floor: ?usize = if (o.min_tier) |t| tierIndex(t) orelse return error.UnknownTier else null;

    const where =
        \\WHERE (? = 0 OR m.patch IN (SELECT value FROM json_each(?)))
        \\  AND m.game_start >= ? AND m.queue_id = ?
        \\  AND m.platform IN (SELECT value FROM json_each(?))
        \\  AND m.remake = 0 AND m.winning_team IS NOT NULL
    ;
    const args = .{ o.patches.len, patch_json, o.since_ms, stats.ranked_solo, platform_json };
    var q = try db.prepare(
        \\SELECT m.match_id, m.platform, t.rowid, d.data
        \\FROM matches m LEFT JOIN timeline.timelines t USING (match_id)
        \\LEFT JOIN timeline.digests d ON d.source = t.rowid AND d.match_id = m.match_id
        \\
    ++ where);
    defer q.deinit();
    try q.bind(args);
    var players = try db.prepare(
        \\SELECT slot, position, champion_id, win, tier, summoner1, summoner2,
        \\  keystone, primary_style, perk1, perk2, perk3, perk4, perk5, secondary_style,
        \\  shard_offense, shard_flex, shard_defense
        \\FROM participants WHERE match_id = ?
    );
    defer players.deinit();
    var source: digest.Source = try .init(db);
    defer source.deinit();
    defer log.info("timelines from digests {d}, in full {d}", .{ source.digests, source.fulls });

    // Each game is ~3 reads at random (digest, its overflow page, participants)
    const ahead: *store.Ahead = try .start(gpa, io, db, .{
        .list = "SELECT m.match_id, t.rowid FROM matches m LEFT JOIN timeline.timelines t USING (match_id)\n" ++ where,
        .reads = &.{ digest.read_ahead, "SELECT slot FROM participants WHERE match_id = ?1" },
    }, args);
    defer ahead.stop();

    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    var all: [timeline.max_participants]Picks = undefined;
    // One game's players, kept until the loop has seen every lane opponent
    const Row = struct { p: Player, team: bool, k: ?Picks, counted: bool };
    var game: [timeline.max_participants]Row = undefined;
    while (try q.step()) {
        ahead.next();
        _ = arena_state.reset(.retain_capacity);
        const arena = arena_state.allocator();
        const m = q.row(struct { match_id: []const u8, platform: []const u8, source: ?i64, digest: ?[]const u8 });
        var in: [max_sets]bool = @splat(false);
        for (sets, 0..) |set, i| {
            for (set) |p| if (std.mem.eql(u8, p, m.platform)) {
                in[i] = true;
            };
        }
        if (std.mem.indexOfScalar(bool, in[0..out.len], true) == null) continue;
        var have_picks = false;
        if (m.source) |src| {
            if (source.get(arena, src, m.digest)) |t| {
                picks(t, d, all[0..t.participants]);
                have_picks = true;
            } else |err| log.warn("{s}: {t}", .{ m.match_id, err });
        }
        for (out, in[0..out.len]) |*b, yes| if (yes) {
            b.games += 1;
            b.timelines += @intFromBool(have_picks);
        };
        try players.bind(.{m.match_id});
        var n: usize = 0;
        while (try players.step()) {
            const r = players.row(struct {
                slot: usize,
                position: []const u8,
                champion_id: u32,
                win: bool,
                tier: ?[]const u8,
                summoner1: ?i64,
                summoner2: ?i64,
                keystone: ?i64,
                primary_style: ?i64,
                perk1: ?i64,
                perk2: ?i64,
                perk3: ?i64,
                perk4: ?i64,
                perk5: ?i64,
                secondary_style: ?i64,
                shard_offense: ?i64,
                shard_flex: ?i64,
                shard_defense: ?i64,
            });
            const role = Role.fromLcu(r.position) orelse continue;
            if (n == game.len) break;
            // Below the floor: not counted, still someone's lane opponent
            const counted = if (floor) |f| blk: {
                const rank = if (r.tier) |t| tierIndex(t) else null;
                break :blk rank != null and rank.? <= f;
            } else true;
            const p: Player = .{
                .champion = r.champion_id,
                .role = role,
                .won = r.win,
                .spells = .{ idOf(r.summoner1), idOf(r.summoner2) },
                .keystone = idOf(r.keystone),
                .primary = idOf(r.primary_style),
                .perks = .{ idOf(r.perk1), idOf(r.perk2), idOf(r.perk3), idOf(r.perk4), idOf(r.perk5) },
                .secondary = idOf(r.secondary_style),
                .shards = .{ idOf(r.shard_offense), idOf(r.shard_flex), idOf(r.shard_defense) },
            };
            const k: ?Picks = if (have_picks and r.slot < timeline.max_participants) all[r.slot] else null;
            game[n] = .{ .p = p, .team = r.slot < 5, .k = k, .counted = counted };
            n += 1;
        }
        for (game[0..n], 0..) |*g, i| {
            if (!g.counted) continue;
            var found: usize = 0;
            for (game[0..n], 0..) |h, j| if (i != j and h.team != g.team and h.p.role == g.p.role) {
                g.p.opponent = h.p.champion;
                found += 1;
            };
            if (found != 1) g.p.opponent = 0;
            for (out, in[0..out.len]) |*b, yes| if (yes) try b.addPlayer(g.p, g.k, d);
        }
    }
}

/// Platform sets one buildEach pass feeds
const max_sets = 4;

/// NULL or out of range: 0, none
fn idOf(v: ?i64) u32 {
    return std.math.cast(u32, v orelse 0) orelse 0;
}

fn tierIndex(tier: []const u8) ?usize {
    for (store.schema.tiers, 0..) |t, i| if (std.ascii.eqlIgnoreCase(tier, t)) return i;
    return null;
}

const testing = std.testing;

fn testData(arena: std.mem.Allocator) !ddragon.BuildData {
    return .{
        .version = "16.20.1",
        .legendary = &.{ 3078, 3153, 6631 },
        .trinkets = &.{3340},
        .boots = &.{ .{ 3047, 3047 }, .{ 3111, 3111 }, .{ 3174, 3047 } },
        .items = try arena.dupe(ddragon.Named, &.{.{ .id = 1055, .name = "Doran's Blade" }}),
        .runes = &.{},
        .spells = &.{},
    };
}

test "picks: starting items, boots, core and skills from events" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const d = try testData(arena_state.allocator());
    const E = timeline.Event;
    const buy = struct {
        fn f(t: i64, item: u32) E {
            return .{ .t_ms = t, .data = .{ .item_purchased = .{ .participant = 1, .item = item } } };
        }
    }.f;
    const skill = struct {
        fn f(t: i64, slot: u8) E {
            return .{ .t_ms = t, .data = .{ .skill_level_up = .{ .participant = 1, .slot = slot, .type = "NORMAL" } } };
        }
    }.f;
    const events = [_]E{
        buy(5_000, 1055),
        buy(5_100, 2003),
        buy(5_200, 3340),
        buy(6_000, 2003),
        .{ .t_ms = 7_000, .data = .{ .item_sold = .{ .participant = 1, .item = 2003 } } },
        buy(300_000, 3174),
        buy(600_000, 3078),
        buy(700_000, 6631),
        .{ .t_ms = 700_500, .data = .{ .item_undo = .{ .participant = 1, .before = 6631, .after = 0, .gold = 3300 } } },
        buy(800_000, 3153),
        buy(900_000, 6631),
        buy(1_000_000, 3111),
        // Q at 1, 4, 5, 7, 9; W at 2; E at 3, 8, 10, 12, 13; R at 6, 11
        skill(1, 1),
        skill(2, 2),
        skill(3, 3),
        skill(4, 1),
        skill(5, 1),
        skill(6, 4),
        skill(7, 1),
        skill(8, 3),
        skill(9, 1),
        skill(10, 3),
        skill(11, 4),
        skill(12, 3),
        skill(13, 3),
        skill(14, 2),
        .{ .t_ms = 15, .data = .{ .skill_level_up = .{ .participant = 1, .slot = 1, .type = "EVOLVE" } } },
    };
    var out: [2]Picks = undefined;
    picks(.{ .participants = 2, .frames = &.{}, .events = &events }, &d, &out);
    const p = out[0];
    try testing.expectEqualSlices(u32, &.{ 1055, 2003 }, p.start[0..p.start_len]);
    try testing.expectEqual(3174, p.boots);
    try testing.expectEqual(3047, d.bootsOf(p.boots).?);
    try testing.expectEqualSlices(u32, &.{ 3078, 3153, 6631 }, p.core[0..p.core_len]);
    // Q and E both 5 by the 13th point; Q got there first
    try testing.expectEqual([3]u32{ 1, 3, 2 }, p.skillOrder().?);
    try testing.expectEqual([3]u8{ 1, 2, 3 }, p.first);
    try testing.expectEqual(0, out[1].start_len);
    try testing.expectEqual(null, out[1].skillOrder());
}

test "builder: shares, rank floor in build, pruning keeps totals" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const d = try testData(arena);
    var b: Builder = .{ .gpa = testing.allocator, .max_keys = 8 };
    defer b.deinit();
    // Darius top: Doran's Blade start five times (3 won), five rare starts once each
    for (0..5) |i| {
        var k: Picks = .{};
        k.start[0] = 1055;
        k.start_len = 1;
        try b.addPlayer(.{ .champion = 122, .role = .top, .won = i < 3, .keystone = 8010, .spells = .{ 4, 12 } }, k, &d);
    }
    for (0..5) |i| {
        var k: Picks = .{};
        k.start[0] = @intCast(2000 + i);
        k.start_len = 1;
        try b.addPlayer(.{ .champion = 122, .role = .top, .won = false, .spells = .{ 12, 4 } }, k, &d);
    }
    try testing.expect(b.floor >= 1);
    const f = try b.file(arena, &d, "16.20", "PLATINUM", 3);
    const darius = f.get(122, .top).?;
    try testing.expectEqual(10, darius.games);
    const start = darius.get(.start).?;
    try testing.expectEqual(10, start.games);
    try testing.expectEqualSlices(u32, &.{1055}, start.options[0].v);
    try testing.expectEqual(5, start.options[0].games);
    try testing.expectEqual(3, start.options[0].wins);
    // D/F order does not split spells
    const spells = darius.get(.spells).?;
    try testing.expectEqualSlices(u32, &.{ 4, 12 }, spells.options[0].v);
    try testing.expectEqual(10, spells.options[0].games);
    try testing.expectEqual(null, darius.get(.core3));
    try testing.expectEqualStrings("Doran's Blade", f.items[0].name);
    try testing.expectEqual(null, f.get(122, .jungle));

    // Round trip through JSON, as the site reads it
    const json = try std.json.Stringify.valueAlloc(arena, f, .{});
    const back = try File.parse(arena, json);
    try testing.expectEqual(5, back.get(122, .top).?.get(.start).?.options[0].games);
}

test "builder: per lane opponent, own floor, only matchups with enough games" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const d = try testData(arena);
    var b: Builder = .{ .gpa = testing.allocator, .max_keys = 64 };
    defer b.deinit();
    try b.countMatchups(64, 3);
    // Darius top: 3 games vs Garen (2 won), 2 vs Sett, 1 without a lane opponent
    for ([_]u32{ 86, 86, 86, 875, 875, 0 }, 0..) |opp, i| {
        var k: Picks = .{};
        k.start[0] = 1055;
        k.start_len = 1;
        try b.addPlayer(.{ .champion = 122, .role = .top, .won = i < 2, .keystone = 8010, .spells = .{ 4, 12 }, .opponent = opp }, k, &d);
    }
    const f = try b.file(arena, &d, "16.20", "PLATINUM", 3);
    try testing.expectEqual(6, f.get(122, .top).?.games);
    try testing.expectEqual(1, f.matchups.len);
    const garen = f.getVs(122, .top, 86).?;
    try testing.expectEqual(3, garen.games);
    try testing.expectEqual(2, garen.wins);
    try testing.expectEqual(3, garen.get(.start).?.options[0].games);
    // Role-wide only
    try testing.expectEqual(null, garen.get(.keystone));
    try testing.expectEqual(null, garen.get(.spells));
    try testing.expectEqual(null, f.getVs(122, .top, 875));

    const back = try File.parse(arena, try std.json.Stringify.valueAlloc(arena, f, .{}));
    try testing.expectEqual(3, back.getVs(122, .top, 86).?.games);
    const old = try File.parse(arena,
        \\{"label":"16.20","min_tier":"","games":0,"timelines":0,"items":[],"runes":[],"spells":[],"builds":[]}
    );
    try testing.expectEqual(0, old.matchups.len);
}
