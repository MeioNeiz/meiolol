//! `meiolol builds`: what players build per champion and role, as lolalytics shows it:
//! rune pages, summoner spells (participants), starting items, boots, the first finished
//! items in purchase order, the 4th to 6th finished items, skill priority and the skill
//! path through level 18 (compact timelines), per finished item and boots the median
//! minute bought, and wins by the minute the first finished item was bought. Written as a
//! JSON file
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
    /// [rune id]: each of a page's six runes, so a rune's share is its pick rate
    rune,
    /// [shard row 0 to 2, shard id]
    shard,
    /// Items bought in the first start_ms that start_gold covers, sorted, net of undos
    /// and sales; trinkets out
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
    /// [item]: the 4th, 5th and 6th finished items, whatever came before
    item4,
    item5,
    item6,
    /// Levels 1 to 18, an ability slot (0 Q to 3 R) per level in 2 bits: [levels 1 to 16,
    /// 17 and 18]. From 11 skill-ups; a game ending sooner is filled as the player was
    /// going (Picks.skillPath)
    skill_path,
};

pub const max_values = 8;
/// The rank filter's floors above Platinum (Emerald+, Diamond+, Master+): `builds --site`
/// writes a file per view for each
pub const rank_tiers = [_][]const u8{ "EMERALD", "DIAMOND", "MASTER" };
/// What `builds --site` writes per lane opponent: matchups with this many games, this
/// many options per kind
pub const min_matchup_games = 300;
const matchup_rows = 3;
/// Options written for .rune and .shard: every rune a champion's players took, in a
/// matchup only those on 1%+ of its players (the file stays small)
const every_rune = 64;
/// Starting items: bought before this many ms
pub const start_ms = 90_000;
/// What every player starts with. The first purchase it can't cover ends the start:
/// that's a second stop (gold from an invade, bought on respawn), not a start
pub const start_gold = 500;
const skill_snapshot = 13;
const min_skill_ups = 11;
pub const max_level = 18;
/// Finished items in Picks.core: core2, core3 and item4 to item6
const max_items = 6;
/// File.Build.minutes and first_item: a minute bucket each, the last for that minute and
/// later
const minute_buckets = 60;

pub const Options = struct {
    /// Empty: any
    patches: []const []const u8,
    /// Riot ms; 0 for any
    since_ms: i64 = 0,
    platforms: []const []const u8,
    /// Lowest tier counted (participants.tier: the player's ladder rank when the game was
    /// stored); null counts everyone, unranked too
    min_tier: ?[]const u8 = "PLATINUM",
    /// Distinct options held in memory (~50 bytes each): at 1 << 19 the box's 16.21 run
    /// with items 4 to 6 and skill paths pruned in its first week
    max_keys: usize = 1 << 20,
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
    /// Per kind, k: the games that pull an option's win rate halfway to its slot's, so a
    /// few lucky games can't make an option look best (spreadK). Empty in files before
    /// 21 Oct 2026
    shrink: []const Shrink = &.{},

    pub const Shrink = struct { kind: Kind, k: f64, vs: f64 };

    /// `kind`'s k in `builds`, or with `vs` in `matchups`
    pub fn shrinkK(f: *const File, kind: Kind, vs: bool) ?f64 {
        for (f.shrink) |x| if (x.kind == kind) return if (vs) x.vs else x.k;
        return null;
    }

    pub const Build = struct {
        champion: u32,
        role: Role,
        /// Lane opponent's champion in `matchups`, 0 in `builds`
        opponent: u32 = 0,
        /// Players counted (champion, role, rank floor) and their wins
        games: u32,
        wins: u32,
        kinds: []const Rows,

        /// Median minute each boots and finished item of the options was bought, by slot;
        /// none in `matchups` and files before 24 Oct 2026
        minutes: []const Minute = &.{},
        /// Players by the minute (index) they bought their first finished item, and their
        /// wins; empties at the end cut. None in `matchups` and files before 29 Oct 2026
        first_item: []const Count = &.{},

        pub fn get(b: Build, kind: Kind) ?Rows {
            for (b.kinds) |r| if (r.kind == kind) return r;
            return null;
        }

        pub fn minute(b: Build, slot: u8, item: u32) ?Minute {
            for (b.minutes) |m| if (m.slot == slot and m.item == item) return m;
            return null;
        }
    };
    /// slot: 0 boots (item the .boots value), 1 to 6 the nth finished item; games: players
    /// who bought it there
    pub const Minute = struct { slot: u8, item: u32, games: u32, minute: f64 };
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

/// Kinds counted per lane opponent; keystone and skill_start only role-wide
pub const matchup_kinds = [_]Kind{ .runes, .shards, .rune, .shard, .spells, .start, .boots, .core2, .core3, .item4, .item5, .item6, .skills, .skill_path };

const Key = struct { champion: u16, role: Role, opponent: u16 = 0, kind: Kind, v: [max_values]u32 };
const Total = struct { champion: u16, role: Role, opponent: u16 = 0, kind: ?Kind };
const MinuteKey = struct { champion: u16, role: Role, slot: u8, item: u32 };
const Minutes = [minute_buckets]u32;
const RoleKey = struct { champion: u16, role: Role };

pub const Builder = struct {
    gpa: std.mem.Allocator,
    max_keys: usize,
    options: std.AutoHashMapUnmanaged(Key, Count) = .empty,
    /// Per champion and role (kind null) and per kind
    totals: std.AutoHashMapUnmanaged(Total, Count) = .empty,
    /// Role-wide only: players per minute bought, every boots and finished item by slot
    minutes: std.AutoHashMapUnmanaged(MinuteKey, Minutes) = .empty,
    /// Role-wide only: players and wins per minute their first finished item was bought
    first_item: std.AutoHashMapUnmanaged(RoleKey, [minute_buckets]Count) = .empty,
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
        b.minutes.deinit(b.gpa);
        b.first_item.deinit(b.gpa);
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
        if (b.per_opponent and std.mem.findScalar(Kind, &matchup_kinds, kind) == null) return;
        try b.total(.{ .champion = c, .role = role, .opponent = opponent, .kind = kind }, won);
        try b.option(c, role, opponent, kind, v, won);
    }

    /// The player once in the total, then each value of `vs` as an option; one ending in
    /// 0 (no rune) is skipped
    fn addEach(b: *Builder, champion: u32, role: Role, opponent: u16, kind: Kind, vs: []const []const u32, won: bool) !void {
        const c: u16 = @intCast(champion);
        if (b.per_opponent and std.mem.findScalar(Kind, &matchup_kinds, kind) == null) return;
        try b.total(.{ .champion = c, .role = role, .opponent = opponent, .kind = kind }, won);
        for (vs) |v| if (v[v.len - 1] != 0) try b.option(c, role, opponent, kind, v, won);
    }

    fn option(b: *Builder, c: u16, role: Role, opponent: u16, kind: Kind, v: []const u32, won: bool) !void {
        var key: Key = .{ .champion = c, .role = role, .opponent = opponent, .kind = kind, .v = @splat(0) };
        @memcpy(key.v[0..v.len], v);
        if (b.options.count() >= b.max_keys and !b.options.contains(key)) try b.prune();
        const e = try b.options.getOrPut(b.gpa, key);
        if (!e.found_existing) e.value_ptr.* = .{};
        e.value_ptr.games += 1;
        e.value_ptr.wins += @intFromBool(won);
    }

    fn addMinute(b: *Builder, c: u16, role: Role, slot: u8, item: u32, ms: i64) !void {
        const e = try b.minutes.getOrPut(b.gpa, .{ .champion = c, .role = role, .slot = slot, .item = item });
        if (!e.found_existing) e.value_ptr.* = @splat(0);
        e.value_ptr[minuteOf(ms)] += 1;
    }

    fn addFirstItem(b: *Builder, c: u16, role: Role, ms: i64, won: bool) !void {
        const e = try b.first_item.getOrPut(b.gpa, .{ .champion = c, .role = role });
        if (!e.found_existing) e.value_ptr.* = @splat(.{});
        const x = &e.value_ptr[minuteOf(ms)];
        x.games += 1;
        x.wins += @intFromBool(won);
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
            try b.addEach(p.champion, p.role, opp, .rune, &.{
                &.{p.keystone}, &.{p.perks[0]}, &.{p.perks[1]}, &.{p.perks[2]}, &.{p.perks[3]}, &.{p.perks[4]},
            }, p.won);
        }
        if (p.shards[0] != 0) {
            try b.addVs(p.champion, p.role, opp, .shards, &p.shards, p.won);
            try b.addEach(p.champion, p.role, opp, .shard, &.{
                &.{ 0, p.shards[0] }, &.{ 1, p.shards[1] }, &.{ 2, p.shards[2] },
            }, p.won);
        }
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
        for ([_]Kind{ .item4, .item5, .item6 }, 3..) |kind, i| {
            if (k.core_len > i) try b.addVs(p.champion, p.role, opp, kind, &.{k.core[i]}, p.won);
        }
        if (k.skillOrder()) |order| try b.addVs(p.champion, p.role, opp, .skills, &order, p.won);
        if (k.skill_ups >= 3) try b.addVs(p.champion, p.role, opp, .skill_start, &.{ k.first[0], k.first[1], k.first[2] }, p.won);
        if (k.skillPath()) |path| try b.addVs(p.champion, p.role, opp, .skill_path, &path, p.won);
        if (b.per_opponent) return;
        if (k.boots != 0) if (d.bootsOf(k.boots)) |boots| try b.addMinute(c, p.role, 0, boots, k.boots_ms);
        for (k.core[0..k.core_len], k.core_ms[0..k.core_len], 1..) |item, ms, slot| try b.addMinute(c, p.role, @intCast(slot), item, ms);
        if (k.core_len > 0) try b.addFirstItem(c, p.role, k.core_ms[0], p.won);
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
            .shrink = try shrinks(arena, builds, matchups, d.trees),
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
                    const per_rune = kind == .rune or kind == .shard;
                    if (options.items.len == if (per_rune) every_rune else rows) continue;
                    if (per_rune and min_games > 0 and e.count.games * 100 < t.games) continue;
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
                .minutes = try b.fileMinutes(arena, first.champion, first.role, kinds.items),
                .first_item = try b.fileFirstItem(arena, first.champion, first.role),
            });
        }
        return builds.items;
    }

    /// The median minute of each boots and finished item in `kinds`' options, in its slot
    fn fileMinutes(b: *const Builder, arena: std.mem.Allocator, c: u16, role: Role, kinds: []const File.Rows) ![]const File.Minute {
        if (b.minutes.count() == 0) return &.{};
        var out: std.ArrayList(File.Minute) = .empty;
        for (kinds) |rows| for (rows.options) |o| for (o.v, 0..) |item, i| {
            const slot = itemSlot(rows.kind, i) orelse continue;
            const hist = b.minutes.get(.{ .champion = c, .role = role, .slot = slot, .item = item }) orelse continue;
            for (out.items) |m| {
                if (m.slot == slot and m.item == item) break;
            } else try out.append(arena, median(slot, item, hist));
        };
        std.mem.sort(File.Minute, out.items, {}, struct {
            fn f(_: void, x: File.Minute, y: File.Minute) bool {
                return if (x.slot != y.slot) x.slot < y.slot else x.item < y.item;
            }
        }.f);
        return out.items;
    }

    fn fileFirstItem(b: *const Builder, arena: std.mem.Allocator, c: u16, role: Role) ![]const Count {
        const hist = b.first_item.get(.{ .champion = c, .role = role }) orelse return &.{};
        var n: usize = hist.len;
        while (n > 0 and hist[n - 1].games == 0) n -= 1;
        return arena.dupe(Count, hist[0..n]);
    }
};

fn minuteOf(ms: i64) usize {
    return @intCast(std.math.clamp(@divFloor(ms, std.time.ms_per_min), 0, minute_buckets - 1));
}

/// File.Minute.slot of the item at `i` in an option of `kind`; null for kinds without
pub fn itemSlot(kind: Kind, i: usize) ?u8 {
    return switch (kind) {
        .boots => 0,
        .core2, .core3 => @intCast(i + 1),
        .item4 => 4,
        .item5 => 5,
        .item6 => 6,
        else => null,
    };
}

/// The minute half the players had bought it by, within its bucket as if spread evenly,
/// to a tenth
fn median(slot: u8, item: u32, hist: Minutes) File.Minute {
    var games: u32 = 0;
    for (hist) |n| games += n;
    const half = @as(f64, @floatFromInt(games)) / 2;
    var below: f64 = 0;
    var mid: f64 = 0;
    for (hist, 0..) |n, m| {
        const count: f64 = @floatFromInt(n);
        if (n > 0 and below + count >= half) {
            mid = @as(f64, @floatFromInt(m)) + (half - below) / count;
            break;
        }
        below += count;
    }
    return .{ .slot = slot, .item = item, .games = games, .minute = @round(mid * 10) / 10 };
}

/// k for an option's win rate: how much true win rates differ between the options of one
/// slot (a kind's rows; for .rune a tree row, for .shard a shard row), by the method of
/// moments over every champion and role, as core/banimpact.zig's Prior. Each option's
/// squared gap to its slot's win rate, less the binomial noise expected (an option is
/// part of its slot's average, so 1 - its share of it), leaves the true spread tau2;
/// k = p(1 - p) / tau2. 16.20 EUW: about 6,000 for a rune, 600 to 1,000 for items
pub const Spread = struct {
    q: f64 = 0,
    noise: f64 = 0,
    pq: f64 = 0,
    games: f64 = 0,

    /// No measurable spread: an option's own games barely move its estimate
    pub const max_k = 1e6;

    pub fn add(s: *Spread, options: []const File.Option, games: u32, wins: u32) void {
        if (games == 0) return;
        const n: f64 = @floatFromInt(games);
        const base = @as(f64, @floatFromInt(wins)) / n;
        for (options) |o| {
            if (o.games == 0) continue;
            const g: f64 = @floatFromInt(o.games);
            const d = @as(f64, @floatFromInt(o.wins)) - g * base;
            s.q += d * d / g;
            s.noise += base * (1 - base) * (1 - g / n);
            s.pq += g * base * (1 - base);
            s.games += g;
        }
    }

    pub fn k(s: Spread) f64 {
        if (s.games == 0) return max_k;
        const pq = s.pq / s.games;
        const tau2 = (s.q - s.noise) / s.games;
        return if (tau2 * max_k <= pq) max_k else pq / tau2;
    }
};

/// Rows of `kind` as slots into `s`: .rune by tree row, .shard by shard row (only those
/// with two or more options), any other kind whole
fn addSlots(s: *Spread, trees: []const ddragon.Tree, rows: File.Rows) void {
    var buf: [8]File.Option = undefined;
    switch (rows.kind) {
        .rune => for (trees) |t| for (t.slots) |slot| {
            var n: usize = 0;
            for (slot) |id| for (rows.options) |o| {
                if (o.v[0] == id and n < buf.len) {
                    buf[n] = o;
                    n += 1;
                }
            };
            addSlot(s, buf[0..n]);
        },
        .shard => for (0..ddragon.shard_rows.len) |row| {
            var n: usize = 0;
            for (rows.options) |o| if (o.v[0] == row and n < buf.len) {
                buf[n] = o;
                n += 1;
            };
            addSlot(s, buf[0..n]);
        },
        else => s.add(rows.options, rows.games, rows.wins),
    }
}

fn addSlot(s: *Spread, options: []const File.Option) void {
    if (options.len < 2) return;
    var games: u32 = 0;
    var wins: u32 = 0;
    for (options) |o| {
        games += o.games;
        wins += o.wins;
    }
    s.add(options, games, wins);
}

fn shrinks(arena: std.mem.Allocator, builds: []const File.Build, matchups: []const File.Build, trees: []const ddragon.Tree) ![]const File.Shrink {
    var role: std.EnumArray(Kind, Spread) = .initFill(.{});
    var vs: std.EnumArray(Kind, Spread) = .initFill(.{});
    for (builds) |b| for (b.kinds) |rows| addSlots(role.getPtr(rows.kind), trees, rows);
    for (matchups) |b| for (b.kinds) |rows| addSlots(vs.getPtr(rows.kind), trees, rows);
    var out: std.ArrayList(File.Shrink) = .empty;
    for (std.enums.values(Kind)) |kind| {
        if (role.get(kind).games == 0) continue;
        try out.append(arena, .{ .kind = kind, .k = role.get(kind).k(), .vs = vs.get(kind).k() });
    }
    return out.items;
}

/// 0: items, 1: runes, 2: summoner spells; skills are ability slots
fn nameList(kind: Kind) ?usize {
    return switch (kind) {
        .keystone, .runes, .shards, .rune => 1,
        .spells => 2,
        .start, .boots, .core2, .core3, .item4, .item5, .item6 => 0,
        .shard, .skills, .skill_start, .skill_path => null,
    };
}

fn valueLen(kind: Kind, v: [max_values]u32) usize {
    return switch (kind) {
        .keystone, .boots, .rune, .item4, .item5, .item6 => 1,
        .runes => 8,
        .shards, .core3, .skills, .skill_start => 3,
        .spells, .core2, .shard, .skill_path => 2,
        .start => std.mem.findScalar(u32, &v, 0) orelse max_values,
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
    start_spent: u32 = 0,
    start_done: bool = false,
    /// First boots bought, the item itself (BuildData.bootsOf gives the choice)
    boots: u32 = 0,
    boots_ms: i64 = 0,
    /// Finished items in purchase order, and when each was bought
    core: [max_items]u32 = @splat(0),
    core_ms: [max_items]i64 = @splat(0),
    core_len: u8 = 0,
    /// Q, W, E, R: the first skill_snapshot skill-ups
    points: [4]u8 = @splat(0),
    reached_ms: [4]i64 = @splat(0),
    skill_ups: u8 = 0,
    /// Slots of the first three skill-ups
    first: [3]u8 = @splat(0),
    /// Slot (1 Q to 4 R) of every skill-up up to max_level
    path: [max_level]u8 = @splat(0),
    path_len: u8 = 0,

    fn removeStart(p: *Picks, item: u32) bool {
        const i = std.mem.findScalar(u32, p.start[0..p.start_len], item) orelse return false;
        p.start_len -= 1;
        p.start[i] = p.start[p.start_len];
        p.start[p.start_len] = 0;
        return true;
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

    /// The .skill_path value: path packed 2 bits a level. A game ending before level 18,
    /// from 11 skill-ups, is filled as the player was going: R when one is due (6, 11,
    /// 16), else the basic ability with the most points under 5, ties to the one that got
    /// there first. Not filled, so null, for a path off those rules (Udyr, Jayce and the
    /// other kits with R before 6 or a basic past 5): those count from level 18 only
    pub fn skillPath(p: Picks) ?[2]u32 {
        if (p.path_len < min_skill_ups) return null;
        var path = p.path;
        if (p.path_len < max_level) {
            var points: [4]u8 = @splat(0);
            var reached: [4]usize = @splat(0);
            for (path[0..p.path_len], 1..) |s, level| {
                points[s - 1] += 1;
                reached[s - 1] = level;
                if (points[3] > ultPoints(level) or points[s - 1] > 5) return null;
            }
            for (p.path_len + 1..max_level + 1) |level| {
                var s: u8 = 4;
                if (points[3] == ultPoints(level)) {
                    s = 0;
                    for (1..4) |x| {
                        if (points[x - 1] == 5) continue;
                        if (s == 0 or points[x - 1] > points[s - 1] or
                            (points[x - 1] == points[s - 1] and reached[x - 1] < reached[s - 1])) s = @intCast(x);
                    }
                    if (s == 0) return null;
                }
                path[level - 1] = s;
                points[s - 1] += 1;
                reached[s - 1] = level;
            }
        }
        var v: [2]u32 = @splat(0);
        for (path, 0..) |s, i| v[i / 16] |= @as(u32, s - 1) << @intCast(2 * (i % 16));
        return v;
    }
};

/// R points a standard kit can have at `level`
fn ultPoints(level: usize) u8 {
    return @as(u8, @intFromBool(level >= 6)) + @intFromBool(level >= 11) + @intFromBool(level >= 16);
}

/// Ability slots (1 Q to 4 R), one per level, of a .skill_path value
pub fn unpackPath(v: []const u32) [max_level]u8 {
    var out: [max_level]u8 = undefined;
    for (&out, 0..) |*s, i| s.* = @intCast((v[i / 16] >> @intCast(2 * (i % 16)) & 3) + 1);
    return out;
}

/// Every participant's picks; out[participant id - 1]
pub fn picks(t: timeline.Timeline, d: *const ddragon.BuildData, out: []Picks) void {
    @memset(out, .{});
    for (t.events) |e| switch (e.data) {
        .item_purchased => |b| {
            const p = at(out, b.participant) orelse continue;
            if (e.t_ms < start_ms and !p.start_done and !d.isTrinket(b.item)) {
                const gold = d.goldOf(b.item);
                if (p.start_spent + gold > start_gold) {
                    p.start_done = true;
                } else if (p.start_len == max_values) {
                    p.start_overflow = true;
                } else {
                    p.start[p.start_len] = b.item;
                    p.start_len += 1;
                    p.start_spent += gold;
                }
            }
            if (p.boots == 0 and d.bootsOf(b.item) != null) {
                p.boots = b.item;
                p.boots_ms = e.t_ms;
            }
            if (p.core_len < max_items and d.isLegendary(b.item)) {
                p.core[p.core_len] = b.item;
                p.core_ms[p.core_len] = e.t_ms;
                p.core_len += 1;
            }
        },
        .item_sold => |s| {
            const p = at(out, s.participant) orelse continue;
            // A sale refunds part of the price: the gold stays spent
            if (e.t_ms < start_ms and !p.start_done) _ = p.removeStart(s.item);
        },
        // Undoing a purchase: before = the item, after = 0 (after set: an undone sale)
        .item_undo => |u| {
            const p = at(out, u.participant) orelse continue;
            if (u.before == 0 or u.after != 0) continue;
            if (e.t_ms < start_ms and !p.start_done and p.removeStart(u.before)) p.start_spent -|= d.goldOf(u.before);
            if (p.boots == u.before) p.boots = 0;
            if (p.core_len > 0 and p.core[p.core_len - 1] == u.before) {
                p.core_len -= 1;
                p.core[p.core_len] = 0;
                p.core_ms[p.core_len] = 0;
            }
        },
        .skill_level_up => |s| {
            const p = at(out, s.participant) orelse continue;
            // EVOLVE: Kai'Sa, Kha'Zix and the like upgrading an ability, not a point
            if (s.slot < 1 or s.slot > 4 or std.mem.eql(u8, s.type, "EVOLVE")) continue;
            if (p.path_len < max_level) {
                p.path[p.path_len] = s.slot;
                p.path_len += 1;
            }
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
    try buildEach(gpa, io, db, d, o, &.{.{ .slice = .{ .platforms = o.platforms, .since_ms = o.since_ms, .patches = o.patches } }}, &b);
    return b[0];
}

/// One builder of buildEach: the games of `slice` (platforms within Options.platforms)
pub const Set = struct {
    slice: stats.Slice,
    /// Per lane opponent too (Options.min_matchup_games)
    matchups: bool = true,
    /// Lowest tier counted in this set, in place of Options.min_tier: the rank filter's
    /// builds (Emerald+, Diamond+, Master+) in the pass that makes Platinum+
    min_tier: ?[]const u8 = null,
};

/// As build, one builder per set, every timeline read once: EUW's and every region's
/// files, a patch's and the last 30 days', in one pass. The sets' slices pick the games,
/// not o.patches and o.since_ms. Caller owns `out`
pub fn buildEach(
    gpa: std.mem.Allocator,
    io: std.Io,
    db: store.Db,
    d: *const ddragon.BuildData,
    o: Options,
    sets: []const Set,
    out: []Builder,
) !void {
    std.debug.assert(sets.len == out.len and sets.len <= max_sets);
    for (out) |*b| b.* = .{ .gpa = gpa, .max_keys = @max(o.max_keys, 2) };
    errdefer for (out) |*b| b.deinit();
    if (o.min_matchup_games) |min| for (out, sets) |*b, set| {
        if (set.matchups) try b.countMatchups(o.max_matchup_keys, min);
    };
    // Every set's games and some more: those on a set's patches, or from the earliest
    // start of a set on any patch; each set then takes its own
    var patches: std.ArrayList([]const u8) = .empty;
    defer patches.deinit(gpa);
    var any_since: i64 = std.math.maxInt(i64);
    var slices: [max_sets]stats.Slice = undefined;
    for (sets, slices[0..sets.len]) |set, *sl| {
        sl.* = set.slice;
        if (set.slice.patches.len == 0) any_since = @min(any_since, set.slice.since_ms) else try patches.appendSlice(gpa, set.slice.patches);
    }
    const patch_json = try std.json.Stringify.valueAlloc(gpa, patches.items, .{});
    defer gpa.free(patch_json);
    const platform_json = try std.json.Stringify.valueAlloc(gpa, o.platforms, .{});
    defer gpa.free(platform_json);
    const floor: ?usize = if (o.min_tier) |t| tierIndex(t) orelse return error.UnknownTier else null;
    var floors: [max_sets]?usize = undefined;
    for (sets, floors[0..sets.len]) |set, *f| f.* = if (set.min_tier) |t| tierIndex(t) orelse return error.UnknownTier else floor;

    const where =
        \\WHERE (m.patch IN (SELECT value FROM json_each(?)) OR m.game_start >= ?)
        \\  AND m.queue_id = ?
        \\  AND m.platform IN (SELECT value FROM json_each(?))
        \\  AND m.remake = 0 AND m.winning_team IS NOT NULL
    ;
    const args = .{ patch_json, any_since, stats.ranked_solo, platform_json };
    var q = try db.prepare(
        \\SELECT m.match_id, m.platform, m.game_start, m.patch, t.rowid, d.data
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
    const Row = struct { p: Player, team: bool, k: ?Picks, rank: ?usize };
    var game: [timeline.max_participants]Row = undefined;
    while (try q.step()) {
        ahead.next();
        _ = arena_state.reset(.retain_capacity);
        const arena = arena_state.allocator();
        const m = q.row(struct { match_id: []const u8, platform: []const u8, start: i64, patch: []const u8, source: ?i64, digest: ?[]const u8 });
        const mask = stats.Slice.of(slices[0..sets.len], m.platform, m.start, m.patch);
        if (mask == 0) continue;
        var in: [max_sets]bool = undefined;
        for (&in, 0..) |*yes, i| yes.* = mask & (@as(u32, 1) << @intCast(i)) != 0;
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
            game[n] = .{ .p = p, .team = r.slot < 5, .k = k, .rank = if (r.tier) |t| tierIndex(t) else null };
            n += 1;
        }
        for (game[0..n], 0..) |*g, i| {
            // Below a set's floor: not counted there, still someone's lane opponent
            var counted: [max_sets]bool = undefined;
            var any = false;
            for (floors[0..out.len], counted[0..out.len], in[0..out.len]) |f, *c, yes| {
                c.* = yes and if (f) |lowest| g.rank != null and g.rank.? <= lowest else true;
                any = any or c.*;
            }
            if (!any) continue;
            var found: usize = 0;
            for (game[0..n], 0..) |h, j| if (i != j and h.team != g.team and h.p.role == g.p.role) {
                g.p.opponent = h.p.champion;
                found += 1;
            };
            if (found != 1) g.p.opponent = 0;
            for (out, counted[0..out.len]) |*b, yes| if (yes) try b.addPlayer(g.p, g.k, d);
        }
    }
}

/// Sets one buildEach pass feeds: `builds --site`'s four views at four rank floors
pub const max_sets = 16;

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
        .gold = &.{ .{ 1052, 400 }, .{ 1055, 450 }, .{ 1101, 450 }, .{ 2003, 50 } },
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
    try testing.expectEqualSlices(i64, &.{ 600_000, 800_000, 900_000 }, p.core_ms[0..3]);
    try testing.expectEqual(300_000, p.boots_ms);
    // 14 skill-ups (EVOLVE out), then filled: E maxed at 13, W to 15, R at 16, W to 18
    try testing.expectEqual(14, p.path_len);
    try testing.expectEqualSlices(u8, &.{ 1, 2, 3, 1, 1, 4, 1, 3, 1, 3, 4, 3, 3, 2, 2, 4, 2, 2 }, &unpackPath(&p.skillPath().?));
}

test "picks: the start ends at the first purchase the starting gold can't cover" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const d = try testData(arena_state.allocator());
    const E = timeline.Event;
    const buy = struct {
        fn f(t: i64, item: u32) E {
            return .{ .t_ms = t, .data = .{ .item_purchased = .{ .participant = 1, .item = item } } };
        }
    }.f;
    // Karthus jungle: Tome undone for Pup and a potion; Tome again at 79 s on invade gold
    const events = [_]E{
        buy(2_000, 1052),
        .{ .t_ms = 2_500, .data = .{ .item_undo = .{ .participant = 1, .before = 1052, .after = 0, .gold = 400 } } },
        buy(3_000, 1101),
        buy(3_100, 2003),
        buy(79_000, 1052),
        buy(80_000, 2003),
    };
    var out: [1]Picks = undefined;
    picks(.{ .participants = 1, .frames = &.{}, .events = &events }, &d, &out);
    try testing.expectEqualSlices(u32, &.{ 1101, 2003 }, out[0].start[0..out[0].start_len]);
}

test "skill path: 18 levels kept as played, off-rule kits only once complete" {
    const of = struct {
        fn f(slots: []const u8) Picks {
            var p: Picks = .{};
            @memcpy(p.path[0..slots.len], slots);
            p.path_len = @intCast(slots.len);
            return p;
        }
    }.f;
    const full = [_]u8{ 1, 3, 2, 1, 1, 4, 1, 1, 3, 3, 4, 3, 3, 2, 2, 4, 2, 2 };
    try testing.expectEqualSlices(u8, &full, &unpackPath(&of(&full).skillPath().?));
    // Q maxed second: the fill follows the points, not the slot order
    try testing.expectEqualSlices(u8, &.{ 3, 1, 2, 3, 3, 4, 3, 1, 3, 1, 4, 1, 1, 2, 2, 4, 2, 2 }, &unpackPath(&of(&.{ 3, 1, 2, 3, 3, 4, 3, 1, 3, 1, 4 }).skillPath().?));
    // R at level 1 (Jayce): not filled
    try testing.expectEqual(null, of(&.{ 4, 1, 2, 3, 1, 4, 1, 1, 1, 1, 4, 2 }).skillPath());
    try testing.expectEqual(null, of(full[0..10]).skillPath());
}

test "median minute: halfway through the bucket half the players reach" {
    var hist: Minutes = @splat(0);
    hist[10] = 2;
    hist[12] = 4;
    // 3 of 6: one of the 4 in minute 12, a quarter of the way
    try testing.expectEqual(12.3, median(1, 3078, hist).minute);
    try testing.expectEqual(6, median(1, 3078, hist).games);
}

test "builder: shares, rank floor in build, pruning keeps totals" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const d = try testData(arena);
    var b: Builder = .{ .gpa = testing.allocator, .max_keys = 10 };
    defer b.deinit();
    // Darius top: Doran's Blade start five times (3 won), six rare starts once each
    for (0..5) |i| {
        var k: Picks = .{};
        k.start[0] = 1055;
        k.start_len = 1;
        try b.addPlayer(.{ .champion = 122, .role = .top, .won = i < 3, .keystone = 8010, .spells = .{ 4, 12 } }, k, &d);
    }
    for (0..6) |i| {
        var k: Picks = .{};
        k.start[0] = @intCast(2000 + i);
        k.start_len = 1;
        try b.addPlayer(.{ .champion = 122, .role = .top, .won = false, .spells = .{ 12, 4 } }, k, &d);
    }
    try testing.expect(b.floor >= 1);
    const f = try b.file(arena, &d, "16.20", "PLATINUM", 3);
    const darius = f.get(122, .top).?;
    try testing.expectEqual(11, darius.games);
    const start = darius.get(.start).?;
    try testing.expectEqual(11, start.games);
    try testing.expectEqualSlices(u32, &.{1055}, start.options[0].v);
    try testing.expectEqual(5, start.options[0].games);
    try testing.expectEqual(3, start.options[0].wins);
    // D/F order does not split spells
    const spells = darius.get(.spells).?;
    try testing.expectEqualSlices(u32, &.{ 4, 12 }, spells.options[0].v);
    try testing.expectEqual(11, spells.options[0].games);
    // Per rune: the player once in the total, no option for an empty slot
    const rune = darius.get(.rune).?;
    try testing.expectEqual(5, rune.games);
    try testing.expectEqual(1, rune.options.len);
    try testing.expectEqualSlices(u32, &.{8010}, rune.options[0].v);
    try testing.expectEqualStrings("Doran's Blade", f.items[0].name);
    try testing.expectEqual(null, f.get(122, .jungle));

    // Round trip through JSON, as the site reads it
    const json = try std.json.Stringify.valueAlloc(arena, f, .{});
    const back = try File.parse(arena, json);
    try testing.expectEqual(5, back.get(122, .top).?.get(.start).?.options[0].games);
}

test "spread: k from how much a slot's options differ beyond noise" {
    const o = struct {
        fn f(games: u32, wins: u32) File.Option {
            return .{ .v = &.{}, .games = games, .wins = wins };
        }
    }.f;
    var same: Spread = .{};
    same.add(&.{ o(1000, 500), o(1000, 500) }, 2000, 1000);
    try testing.expectEqual(Spread.max_k, same.k());
    // 60% and 40%: q = 20, noise 0.25, tau2 = 19.75 / 2000, k = 0.25 / tau2
    var apart: Spread = .{};
    apart.add(&.{ o(1000, 600), o(1000, 400) }, 2000, 1000);
    try testing.expectApproxEqAbs(25.32, apart.k(), 0.01);
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
        k.core = .{ 3078, 3153, 6631, 3078, 0, 0 };
        k.core_ms = .{ 600_000, 800_000, 900_000, 1_500_000 + @as(i64, @intCast(i)) * 60_000, 0, 0 };
        k.core_len = 4;
        try b.addPlayer(.{ .champion = 122, .role = .top, .won = i < 2, .keystone = 8010, .spells = .{ 4, 12 }, .opponent = opp }, k, &d);
    }
    const f = try b.file(arena, &d, "16.20", "PLATINUM", 3);
    const darius = f.get(122, .top).?;
    try testing.expectEqual(6, darius.games);
    try testing.expectEqualSlices(u32, &.{3078}, darius.get(.item4).?.options[0].v);
    try testing.expectEqual(null, darius.get(.item5));
    // Minutes 25 to 30, one each: the third of six is all of 27
    try testing.expectEqual(28, darius.minute(4, 3078).?.minute);
    try testing.expectEqual(10.5, darius.minute(1, 3078).?.minute);
    // Every first item at 10:00: minute 10's bucket, the last kept
    try testing.expectEqual(11, darius.first_item.len);
    try testing.expectEqual(Count{ .games = 6, .wins = 2 }, darius.first_item[10]);
    try testing.expectEqual(1, f.matchups.len);
    const garen = f.getVs(122, .top, 86).?;
    try testing.expectEqual(3, garen.games);
    try testing.expectEqual(2, garen.wins);
    try testing.expectEqual(3, garen.get(.start).?.options[0].games);
    try testing.expectEqualSlices(u32, &.{8010}, garen.get(.rune).?.options[0].v);
    try testing.expectEqual(3, garen.get(.rune).?.options[0].games);
    try testing.expectEqualSlices(u32, &.{ 4, 12 }, garen.get(.spells).?.options[0].v);
    try testing.expectEqual(3, garen.get(.item4).?.games);
    try testing.expectEqual(0, garen.minutes.len);
    try testing.expectEqual(0, garen.first_item.len);
    // Role-wide only
    try testing.expectEqual(null, garen.get(.keystone));
    try testing.expectEqual(null, garen.get(.skill_start));
    try testing.expectEqual(null, f.getVs(122, .top, 875));

    const back = try File.parse(arena, try std.json.Stringify.valueAlloc(arena, f, .{}));
    try testing.expectEqual(3, back.getVs(122, .top, 86).?.games);
    try testing.expectEqual(6, back.get(122, .top).?.first_item[10].games);
    const old = try File.parse(arena,
        \\{"label":"16.20","min_tier":"","games":0,"timelines":0,"items":[],"runes":[],"spells":[],"builds":[]}
    );
    try testing.expectEqual(0, old.matchups.len);
}
