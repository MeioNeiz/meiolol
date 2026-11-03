//! Champion facts file (champ-facts.tsv) for the desktop's comp view (src/comp.zig):
//! each champion's damage split and the team damage mix tally (Learn's, src/learn.zig),
//! and each champion-role's early or late lean (`meiolol lean`, src/lean.zig). The
//! site's shared view writes it as data/champ-facts.tsv; the web loop lists it in the
//! desktop manifest. One fact per line, its kind first, tab separated:
//!   meiolol-champs VERSION PATCH         the header; PATCH is the damage split's
//!   damage CHAMPION MAGIC                magic share of damage to champions, 0..1
//!   mix BUCKET GAMES WINS                teams by damage mix (mix_bounds)
//!   lean CHAMPION ROLE GAMES GOLD GOLD_SD WIN_PP WIN_SD    as lean.tsv's rows
//!   games N                              the patch's games, the ban rates' base
//!   ban CHAMPION RATE                    share of them it was banned in, 0..1
//!   build CHAMPION ROLE GAMES BOOTS CORE1 CORE2 CORE3 ORDER PATH
//!                                        the usual build (Build); 0 for no item, - for
//!                                        no order or path
//!   item ID NAME                         a build's item's name
//!   runes CHAMPION ROLE SHARE KEYSTONE SECOND    the most picked keystone and second
//!                                        tree together (Runes); SHARE of the role's games
//!   spells CHAMPION ROLE SHARE A B       the most picked summoner spell pair (Spells)
//!   rune ID NAME, spell ID NAME          their names (id ranges may clash with items')
//!   length CHAMPION ROLE G0 W0 ... G4 W4 games and wins by game length (length_edges)
//!   dpm CHAMPION ROLE DPM                damage to champions a minute
//! Readers skip kinds they don't know, so a new kind needs no version bump; a changed
//! kind does.

const std = @import("std");
const Role = @import("roles.zig").Role;
const Counts = @import("statsfile.zig").Counts;

pub const magic = "meiolol-champs";
pub const version: u32 = 1;
/// Far above the ~170 champions times five roles, a few kinds each; bounds what a
/// damaged file allocates
const max_rows = 16384;

/// Team damage mix buckets by the team's average magic share: mostly physical below the
/// first, mostly magic from the second
pub const mix_bounds = [_]f64{ 0.3, 0.7 };
pub const mixes = mix_bounds.len + 1;

pub fn mixBucket(share: f64) usize {
    var b: usize = 0;
    while (b < mix_bounds.len and share >= mix_bounds[b]) b += 1;
    return b;
}

/// lean.zig's minutes: team gold lead at the first, wins from an even game at the second
pub const gold_minute = 14;
pub const win_minute = 20;
/// Fewer fit games still going at win_minute and the champion-role says nothing
pub const lean_min_games = 200;
/// An effect is clear this many posterior sds from 0
pub const clear_z = 2.0;
/// Fewer games on the patch (its first hours) and ban rates say nothing: at this many a
/// rate's standard error is at most 1.1 points (at 50%), so a champion's share of games
/// left to pick, 1 - rate, is known to about 2%
pub const ban_min_games = 2000;

pub const Lean = enum { early, late, none };

/// Game length bucket edges in minutes, as stats.length_edges
pub const length_edges = [_]u32{ 20, 25, 30, 35 };
pub const length_buckets = length_edges.len + 1;

/// One champion-role's lean, in display units
pub const LeanRow = struct {
    champion: u32,
    role: Role,
    /// Fit games still going at win_minute
    games: u32,
    /// Team gold lead at gold_minute against the role's average pick, ± its sd
    gold: f64,
    gold_sd: f64,
    /// Win pp from an even game at win_minute against the role's average pick (log-odds
    /// x 25: the change at 50%), ± its sd
    win: f64,
    win_sd: f64,

    pub fn goldClear(r: LeanRow) bool {
        return clear(r.gold, r.gold_sd, r.games);
    }

    pub fn winClear(r: LeanRow) bool {
        return clear(r.win, r.win_sd, r.games);
    }

    pub fn enough(r: LeanRow) bool {
        return r.games >= lean_min_games;
    }

    /// Early: ahead at gold_minute and wins less from even; late: the other way round
    pub fn lean(r: LeanRow) Lean {
        if (!r.goldClear() or !r.winClear()) return .none;
        if (r.gold > 0 and r.win < 0) return .early;
        if (r.gold < 0 and r.win > 0) return .late;
        return .none;
    }
};

fn clear(b: f64, sd: f64, n: u32) bool {
    return n >= lean_min_games and sd > 0 and @abs(b) >= clear_z * sd;
}

/// A champion-role's usual build in game: each kind's most played option (builds.zig)
pub const Build = struct {
    champion: u32,
    role: Role,
    games: u32,
    /// Tier-2 boots; 0 none or unknown
    boots: u32 = 0,
    /// First three finished items in purchase order; 0 unknown
    core: [3]u32 = @splat(0),
    /// Basic abilities by points maxed first ("QWE"); 0s unknown
    order: [3]u8 = @splat(0),
    /// The ability taken at each level, 'Q' to 'R'; 0s unknown
    path: [max_level]u8 = @splat(0),

    pub const max_level = 18;

    pub fn hasOrder(b: Build) bool {
        return b.order[0] != 0;
    }

    pub fn hasPath(b: Build) bool {
        return b.path[0] != 0;
    }
};

pub const Item = struct { id: u32, name: []const u8 };

/// Most picked, never with a win rate (learned.md: builds' win rates mislead)
pub const Runes = struct {
    champion: u32,
    role: Role,
    /// Of the champion-role's games, 0..1
    share: f32,
    keystone: u32,
    /// The secondary tree
    second: u32,
};

pub const Spells = struct {
    champion: u32,
    role: Role,
    share: f32,
    /// Lower id first
    ids: [2]u32,
};

pub const LengthRow = struct { champion: u32, role: Role, by: [length_buckets]Counts };
pub const Dpm = struct { champion: u32, role: Role, dpm: f32 };

/// What the app shows beyond the comp view's facts: usual builds, runes and spells with
/// their names, games by length and damage a minute
pub const App = struct {
    builds: []const Build = &.{},
    items: []const Item = &.{},
    runes: []const Runes = &.{},
    spells: []const Spells = &.{},
    rune_names: []const Item = &.{},
    spell_names: []const Item = &.{},
    lengths: []const LengthRow = &.{},
    dpm: []const Dpm = &.{},
};

pub const Damage = struct { champion: u32, magic: f32 };
pub const Ban = struct { champion: u32, rate: f32 };

pub const Facts = struct {
    patch: []const u8 = "",
    damage: []const Damage = &.{},
    mix: [mixes]Counts = @splat(.{ .games = 0, .wins = 0 }),
    lean: []const LeanRow = &.{},
    /// The patch's games and each champion's ban rate on them
    games: u32 = 0,
    bans: []const Ban = &.{},
    builds: []const Build = &.{},
    items: []const Item = &.{},
    runes: []const Runes = &.{},
    spells: []const Spells = &.{},
    rune_names: []const Item = &.{},
    spell_names: []const Item = &.{},
    lengths: []const LengthRow = &.{},
    dpm: []const Dpm = &.{},

    /// Magic share of the champion's damage to champions; null when unsampled
    pub fn magicOf(f: *const Facts, champion: u32) ?f32 {
        for (f.damage) |d| if (d.champion == champion) return d.magic;
        return null;
    }

    /// Null below ban_min_games, so callers keep their no-ban reading; 0 for a champion
    /// never banned
    pub fn banRate(f: *const Facts, champion: u32) ?f32 {
        if (f.games < ban_min_games) return null;
        for (f.bans) |b| if (b.champion == champion) return b.rate;
        return 0;
    }

    pub fn leanOf(f: *const Facts, champion: u32, role: Role) ?LeanRow {
        for (f.lean) |r| if (r.champion == champion and r.role == role) return r;
        return null;
    }

    pub fn buildOf(f: *const Facts, champion: u32, role: Role) ?Build {
        for (f.builds) |b| if (b.champion == champion and b.role == role) return b;
        return null;
    }

    /// "" for an item the file doesn't name
    pub fn itemName(f: *const Facts, id: u32) []const u8 {
        return nameIn(f.items, id);
    }

    pub fn runeName(f: *const Facts, id: u32) []const u8 {
        return nameIn(f.rune_names, id);
    }

    pub fn spellName(f: *const Facts, id: u32) []const u8 {
        return nameIn(f.spell_names, id);
    }

    fn nameIn(names: []const Item, id: u32) []const u8 {
        for (names) |it| if (it.id == id) return it.name;
        return "";
    }

    pub fn runesOf(f: *const Facts, champion: u32, role: Role) ?Runes {
        for (f.runes) |x| if (x.champion == champion and x.role == role) return x;
        return null;
    }

    pub fn spellsOf(f: *const Facts, champion: u32, role: Role) ?Spells {
        for (f.spells) |x| if (x.champion == champion and x.role == role) return x;
        return null;
    }

    pub fn lengthOf(f: *const Facts, champion: u32, role: Role) ?[length_buckets]Counts {
        for (f.lengths) |x| if (x.champion == champion and x.role == role) return x.by;
        return null;
    }

    pub fn dpmOf(f: *const Facts, champion: u32, role: Role) ?f32 {
        for (f.dpm) |x| if (x.champion == champion and x.role == role) return x.dpm;
        return null;
    }

    /// Allocates in `arena`; the patch borrows `bytes`
    pub fn parse(arena: std.mem.Allocator, bytes: []const u8) !Facts {
        var lines = std.mem.tokenizeScalar(u8, bytes, '\n');
        var head = std.mem.splitScalar(u8, lines.next() orelse return error.BadFacts, '\t');
        if (!std.mem.eql(u8, head.next() orelse "", magic)) return error.BadFacts;
        if (try int(u32, head.next()) != version) return error.UnsupportedVersion;
        var f: Facts = .{ .patch = head.next() orelse "" };
        var damage: std.ArrayList(Damage) = .empty;
        var lean: std.ArrayList(LeanRow) = .empty;
        var bans: std.ArrayList(Ban) = .empty;
        var builds: std.ArrayList(Build) = .empty;
        var items: std.ArrayList(Item) = .empty;
        var runes: std.ArrayList(Runes) = .empty;
        var spells: std.ArrayList(Spells) = .empty;
        var rune_names: std.ArrayList(Item) = .empty;
        var spell_names: std.ArrayList(Item) = .empty;
        var lengths: std.ArrayList(LengthRow) = .empty;
        var dpm: std.ArrayList(Dpm) = .empty;
        var rows: usize = 0;
        while (lines.next()) |line| : (rows += 1) {
            if (rows >= max_rows) return error.BadFacts;
            var it = std.mem.splitScalar(u8, line, '\t');
            const kind = it.next() orelse continue;
            if (std.mem.eql(u8, kind, "damage")) {
                const champion = try int(u32, it.next());
                const m = try float(it.next());
                if (!(m >= 0 and m <= 1)) return error.BadFacts;
                try damage.append(arena, .{ .champion = champion, .magic = @floatCast(m) });
            } else if (std.mem.eql(u8, kind, "mix")) {
                const b = try int(usize, it.next());
                if (b >= mixes) return error.BadFacts;
                f.mix[b] = .{ .games = try int(u32, it.next()), .wins = try int(u32, it.next()) };
                if (f.mix[b].wins > f.mix[b].games) return error.BadFacts;
            } else if (std.mem.eql(u8, kind, "lean")) {
                try lean.append(arena, .{
                    .champion = try int(u32, it.next()),
                    .role = std.meta.stringToEnum(Role, it.next() orelse "") orelse return error.BadFacts,
                    .games = try int(u32, it.next()),
                    .gold = try finite(it.next()),
                    .gold_sd = try finite(it.next()),
                    .win = try finite(it.next()),
                    .win_sd = try finite(it.next()),
                });
            } else if (std.mem.eql(u8, kind, "games")) {
                f.games = try int(u32, it.next());
            } else if (std.mem.eql(u8, kind, "ban")) {
                const champion = try int(u32, it.next());
                const r = try float(it.next());
                if (!(r >= 0 and r <= 1)) return error.BadFacts;
                try bans.append(arena, .{ .champion = champion, .rate = @floatCast(r) });
            } else if (std.mem.eql(u8, kind, "build")) {
                try builds.append(arena, try parseBuild(&it));
            } else if (std.mem.eql(u8, kind, "item")) {
                try items.append(arena, try parseName(arena, &it));
            } else if (std.mem.eql(u8, kind, "rune")) {
                try rune_names.append(arena, try parseName(arena, &it));
            } else if (std.mem.eql(u8, kind, "spell")) {
                try spell_names.append(arena, try parseName(arena, &it));
            } else if (std.mem.eql(u8, kind, "runes")) {
                try runes.append(arena, .{
                    .champion = try int(u32, it.next()),
                    .role = try roleOf(it.next()),
                    .share = try share(it.next()),
                    .keystone = try int(u32, it.next()),
                    .second = try int(u32, it.next()),
                });
            } else if (std.mem.eql(u8, kind, "spells")) {
                try spells.append(arena, .{
                    .champion = try int(u32, it.next()),
                    .role = try roleOf(it.next()),
                    .share = try share(it.next()),
                    .ids = .{ try int(u32, it.next()), try int(u32, it.next()) },
                });
            } else if (std.mem.eql(u8, kind, "length")) {
                var x: LengthRow = .{ .champion = try int(u32, it.next()), .role = try roleOf(it.next()), .by = undefined };
                for (&x.by) |*c| {
                    c.* = .{ .games = try int(u32, it.next()), .wins = try int(u32, it.next()) };
                    if (c.wins > c.games) return error.BadFacts;
                }
                try lengths.append(arena, x);
            } else if (std.mem.eql(u8, kind, "dpm")) {
                const champion = try int(u32, it.next());
                const r = try roleOf(it.next());
                const x = try finite(it.next());
                if (x < 0) return error.BadFacts;
                try dpm.append(arena, .{ .champion = champion, .role = r, .dpm = @floatCast(x) });
            }
        }
        f.damage = damage.items;
        f.lean = lean.items;
        f.bans = bans.items;
        f.builds = builds.items;
        f.items = items.items;
        f.runes = runes.items;
        f.spells = spells.items;
        f.rune_names = rune_names.items;
        f.spell_names = spell_names.items;
        f.lengths = lengths.items;
        f.dpm = dpm.items;
        return f;
    }

    fn parseName(arena: std.mem.Allocator, it: *std.mem.SplitIterator(u8, .scalar)) !Item {
        const id = try int(u32, it.next());
        const name = it.next() orelse return error.BadFacts;
        return .{ .id = id, .name = try arena.dupe(u8, name) };
    }

    fn roleOf(s: ?[]const u8) !Role {
        return std.meta.stringToEnum(Role, s orelse "") orelse error.BadFacts;
    }

    fn share(s: ?[]const u8) !f32 {
        const x = try float(s);
        return if (x >= 0 and x <= 1) @floatCast(x) else error.BadFacts;
    }

    fn parseBuild(it: *std.mem.SplitIterator(u8, .scalar)) !Build {
        var b: Build = .{
            .champion = try int(u32, it.next()),
            .role = std.meta.stringToEnum(Role, it.next() orelse "") orelse return error.BadFacts,
            .games = try int(u32, it.next()),
            .boots = try int(u32, it.next()),
        };
        for (&b.core) |*c| c.* = try int(u32, it.next());
        try keys(it.next(), "QWE", &b.order);
        try keys(it.next(), "QWER", &b.path);
        return b;
    }

    /// "-" leaves `out` all 0s; else exactly out.len letters of `allowed`
    fn keys(s: ?[]const u8, allowed: []const u8, out: []u8) !void {
        const x = s orelse return error.BadFacts;
        if (std.mem.eql(u8, x, "-")) return;
        if (x.len != out.len) return error.BadFacts;
        for (x) |ch| if (std.mem.findScalar(u8, allowed, ch) == null) return error.BadFacts;
        @memcpy(out, x);
    }

    fn int(comptime T: type, s: ?[]const u8) !T {
        return std.fmt.parseInt(T, s orelse return error.BadFacts, 10) catch error.BadFacts;
    }

    fn float(s: ?[]const u8) !f64 {
        return std.fmt.parseFloat(f64, s orelse return error.BadFacts) catch error.BadFacts;
    }

    fn finite(s: ?[]const u8) !f64 {
        const x = try float(s);
        return if (std.math.isFinite(x)) x else error.BadFacts;
    }
};

/// The patch's games and how many each champion was banned in
pub const BanCounts = struct {
    games: u32,
    ids: []const u32,
    banned: []const u32,
};

/// `magic` indexed as `ids` (null: unsampled)
pub fn write(w: *std.Io.Writer, patch: []const u8, ids: []const u32, magic_share: []const ?f32, mix: [mixes]Counts, lean: []const LeanRow, bans: BanCounts, app: App) !void {
    try w.print("{s}\t{d}\t{s}\n", .{ magic, version, patch });
    for (ids, magic_share) |id, m| if (m) |x| try w.print("damage\t{d}\t{d:.3}\n", .{ id, x });
    for (mix, 0..) |m, b| try w.print("mix\t{d}\t{d}\t{d}\n", .{ b, m.games, m.wins });
    for (lean) |r| try w.print("lean\t{d}\t{t}\t{d}\t{d:.0}\t{d:.0}\t{d:.2}\t{d:.2}\n", .{ r.champion, r.role, r.games, r.gold, r.gold_sd, r.win, r.win_sd });
    if (bans.games > 0) {
        try w.print("games\t{d}\n", .{bans.games});
        const games: f64 = @floatFromInt(bans.games);
        for (bans.ids, bans.banned) |id, n| if (n > 0) try w.print("ban\t{d}\t{d:.4}\n", .{ id, @min(1, @as(f64, @floatFromInt(n)) / games) });
    }
    for (app.builds) |b| {
        try w.print("build\t{d}\t{t}\t{d}\t{d}\t{d}\t{d}\t{d}\t{s}\t{s}\n", .{
            b.champion,                          b.role,                            b.games, b.boots, b.core[0], b.core[1], b.core[2],
            if (b.hasOrder()) &b.order else "-", if (b.hasPath()) &b.path else "-",
        });
    }
    for (app.runes) |x| try w.print("runes\t{d}\t{t}\t{d:.3}\t{d}\t{d}\n", .{ x.champion, x.role, x.share, x.keystone, x.second });
    for (app.spells) |x| try w.print("spells\t{d}\t{t}\t{d:.3}\t{d}\t{d}\n", .{ x.champion, x.role, x.share, x.ids[0], x.ids[1] });
    for (app.lengths) |x| {
        try w.print("length\t{d}\t{t}", .{ x.champion, x.role });
        for (x.by) |c| try w.print("\t{d}\t{d}", .{ c.games, c.wins });
        try w.writeByte('\n');
    }
    for (app.dpm) |x| try w.print("dpm\t{d}\t{t}\t{d:.0}\n", .{ x.champion, x.role, x.dpm });
    try writeNames(w, "item", app.items);
    try writeNames(w, "rune", app.rune_names);
    try writeNames(w, "spell", app.spell_names);
}

fn writeNames(w: *std.Io.Writer, kind: []const u8, list: []const Item) !void {
    // Names are one field: a tab or newline in one would break the line
    for (list) |it| if (std.mem.findAny(u8, it.name, "\t\n") == null) try w.print("{s}\t{d}\t{s}\n", .{ kind, it.id, it.name });
}

const testing = std.testing;

test "facts file round trip, unknown kinds skipped" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const rows = [_]LeanRow{.{ .champion = 119, .role = .bottom, .games = 900, .gold = 900, .gold_sd = 100, .win = -8, .win_sd = 1.5 }};
    var aw: std.Io.Writer.Allocating = .init(arena);
    const bans: BanCounts = .{ .games = 4000, .ids = &.{ 1, 2, 3 }, .banned = &.{ 1000, 0, 4 } };
    const builds = [_]Build{
        .{ .champion = 103, .role = .middle, .games = 5000, .boots = 3020, .core = .{ 6655, 3157, 3089 }, .order = "QWE".*, .path = "QEWQQRQWQWRWWEEREE".* },
        .{ .champion = 1, .role = .top, .games = 300 },
    };
    const items = [_]Item{ .{ .id = 3020, .name = "Sorcerer's Shoes" }, .{ .id = 1, .name = "bad\tname" } };
    const runes = [_]Runes{.{ .champion = 103, .role = .middle, .share = 0.582, .keystone = 8112, .second = 8200 }};
    const spells = [_]Spells{.{ .champion = 103, .role = .middle, .share = 0.91, .ids = .{ 4, 14 } }};
    var by: [length_buckets]Counts = undefined;
    for (&by, 0..) |*c, b| c.* = .{ .games = @intCast(100 * (b + 1)), .wins = @intCast(50 * b) };
    const lengths = [_]LengthRow{.{ .champion = 103, .role = .middle, .by = by }};
    const dpm = [_]Dpm{.{ .champion = 103, .role = .middle, .dpm = 812 }};
    const app: App = .{
        .builds = &builds,
        .items = &items,
        .runes = &runes,
        .spells = &spells,
        .rune_names = &.{ .{ .id = 8112, .name = "Electrocute" }, .{ .id = 8200, .name = "Sorcery" } },
        .spell_names = &.{ .{ .id = 4, .name = "Flash" }, .{ .id = 14, .name = "Ignite" } },
        .lengths = &lengths,
        .dpm = &dpm,
    };
    try write(&aw.writer, "16.21", &.{ 1, 2, 3 }, &.{ 0.9, null, 0.05 }, .{ .{ .games = 10, .wins = 4 }, .{ .games = 20, .wins = 10 }, .{ .games = 5, .wins = 2 } }, &rows, bans, app);
    try aw.writer.writeAll("someday\t1\t2\n");
    const f = try Facts.parse(arena, aw.written());
    try testing.expectEqualStrings("16.21", f.patch);
    try testing.expectApproxEqAbs(0.9, f.magicOf(1).?, 1e-6);
    try testing.expectEqual(null, f.magicOf(2));
    try testing.expectEqual(20, f.mix[1].games);
    try testing.expectEqual(Lean.early, f.leanOf(119, .bottom).?.lean());
    try testing.expectEqual(null, f.leanOf(119, .top));
    try testing.expectApproxEqAbs(0.25, f.banRate(1).?, 1e-6);
    try testing.expectEqual(0, f.banRate(2).?);
    try testing.expectApproxEqAbs(0.001, f.banRate(3).?, 1e-6);
    try testing.expectEqualDeep(builds[0], f.buildOf(103, .middle).?);
    try testing.expectEqualDeep(builds[1], f.buildOf(1, .top).?);
    try testing.expectEqual(null, f.buildOf(103, .top));
    try testing.expectEqualStrings("Sorcerer's Shoes", f.itemName(3020));
    try testing.expectEqualStrings("", f.itemName(1));
    try testing.expectEqualDeep(runes[0], f.runesOf(103, .middle).?);
    try testing.expectEqualDeep(spells[0], f.spellsOf(103, .middle).?);
    try testing.expectEqual(null, f.spellsOf(103, .top));
    try testing.expectEqualStrings("Sorcery", f.runeName(8200));
    try testing.expectEqualStrings("Flash", f.spellName(4));
    try testing.expectEqualStrings("", f.itemName(4));
    try testing.expectEqualDeep(by, f.lengthOf(103, .middle).?);
    try testing.expectEqual(812, f.dpmOf(103, .middle).?);
    try testing.expectEqual(null, f.dpmOf(1, .top));
    // A patch's first hours: too few games for any rate
    var early = f;
    early.games = ban_min_games - 1;
    try testing.expectEqual(null, early.banRate(1));
    try testing.expectError(error.BadFacts, Facts.parse(arena, "meiolol-champs\t1\t16.21\nban\t1\t1.5\n"));
    try testing.expectError(error.BadFacts, Facts.parse(arena, "meiolol-champs\t1\t16.21\ndamage\t1\t1.5\n"));
    try testing.expectError(error.UnsupportedVersion, Facts.parse(arena, "meiolol-champs\t2\t16.21\n"));
    try testing.expectError(error.BadFacts, Facts.parse(arena, "meiolol-champs\t1\t16.21\nbuild\t1\ttop\t9\t0\t0\t0\t0\tQWR\t-\n"));
    try testing.expectError(error.BadFacts, Facts.parse(arena, "meiolol-champs\t1\t16.21\nbuild\t1\ttop\t9\t0\t0\t0\n"));
    try testing.expectError(error.BadFacts, Facts.parse(arena, "meiolol-champs\t1\t16.21\nrunes\t1\ttop\t1.2\t8112\t8200\n"));
    try testing.expectError(error.BadFacts, Facts.parse(arena, "meiolol-champs\t1\t16.21\nlength\t1\ttop\t10\t11\t0\t0\t0\t0\t0\t0\t0\t0\n"));
    try testing.expectError(error.BadFacts, Facts.parse(arena, "meiolol-champs\t1\t16.21\nlength\t1\ttop\t10\t5\n"));
}

fn fuzzParse(valid: []const u8, s: *testing.Smith) !void {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const f = Facts.parse(arena, try @import("fuzz.zig").mutate(s, arena, valid)) catch return;
    for (f.lean) |r| _ = r.lean();
}

test "fuzz: a damaged facts file is parsed or refused" {
    const valid: []const u8 = "meiolol-champs\t1\t16.21\ndamage\t1\t0.900\nmix\t0\t10\t4\nlean\t119\tbottom\t900\t900\t100\t-8.00\t1.50\ngames\t4000\nban\t1\t0.2500\nbuild\t103\tmiddle\t5000\t3020\t6655\t3157\t3089\tQWE\tQEWQQRQWQWRWWEEREE\nitem\t3020\tSorcerer's Shoes\nrunes\t103\tmiddle\t0.582\t8112\t8200\nspells\t103\tmiddle\t0.910\t4\t14\nlength\t103\tmiddle\t100\t0\t200\t50\t300\t100\t400\t150\t500\t200\ndpm\t103\tmiddle\t812\nrune\t8112\tElectrocute\nspell\t4\tFlash\n";
    try testing.fuzz(valid, fuzzParse, .{});
}
