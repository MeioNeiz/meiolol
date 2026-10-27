//! Ability numbers from CommunityDragon, a fan mirror of the game's own data files
//! (raw.communitydragon.org/<patch>/game/data/characters/<id>/<id>.bin.json; static, not
//! the Riot API): what Data Dragon leaves out, most damage numbers, ratios and scalings.
//! Per patch, not per Data Dragon version, so a patch's mid-patch updates count until it
//! is cached.
//!
//! Per champion: the CharacterRecord's base stats, and for P Q W E R (its
//! mCharacterPassiveSpell and spellNames) the spell's DataValues and the numbers in its
//! mSpellCalculations. Game-mode overrides (Arena, ARAM) are left out, as are names the
//! files keep only as a hash ("{0508ccce}").

const std = @import("std");
const ddragon = @import("ddragon.zig");
const Allocator = std.mem.Allocator;
const Value = std.json.Value;

pub const Slot = enum { stats, p, q, w, e, r };

pub const Kind = enum {
    /// A DataValue: values per rank, [0] unused
    value,
    /// The spell's Cooldown, Cost or AmmoRecharge, per rank as a value; absent when all 0
    spell,
    /// A calculation's stat coefficient: one value
    ratio,
    /// A calculation's level scaling: values at level 1 and 18
    levels,
    /// Any other number in a calculation: one value
    number,
    /// A base stat: one value
    stat,
};

pub const Number = struct {
    slot: Slot,
    kind: Kind,
    /// The DataValue's, calculation's or stat's name: "BaseDamage", "TotalDamage", "Health"
    name: []const u8,
    /// ratio: its stat ("AP", "bonus AD"); number: its path in the calculation; else ""
    of: []const u8 = "",
    values: []const f64,

    /// Same number on both patches
    pub fn same(a: Number, b: Number) bool {
        return a.slot == b.slot and a.kind == b.kind and std.mem.eql(u8, a.name, b.name) and std.mem.eql(u8, a.of, b.of);
    }
};

/// A patch's numbers under a Data Dragon version's cache directory; a new name when
/// `extract` changes, so old caches are read again
pub const cache_file = "cdragon-1.json";

pub const Champion = struct {
    /// Data Dragon's id ("MonkeyKing")
    key: []const u8,
    numbers: []const Number,
};

/// The numbers of the champions `keys` (Data Dragon ids) on `patch` ("16.21"), cached as
/// `path`. A champion CommunityDragon lacks is left out (a new one); any other failure
/// fails it all, unsaved, so the next call tries again. error.NotPublished when the
/// first champions are all missing: the patch is not up yet (patch day)
pub fn cached(http: *std.http.Client, arena: Allocator, io: std.Io, path: []const u8, patch: []const u8, keys: []const []const u8) ![]const Champion {
    const cwd = std.Io.Dir.cwd();
    if (cwd.readFileAlloc(io, path, arena, .limited(64 << 20))) |body| {
        return std.json.parseFromSliceLeaky([]const Champion, arena, body, .{});
    } else |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    }
    var out: std.ArrayList(Champion) = .empty;
    for (keys, 0..) |key, i| {
        if (i == 5 and out.items.len == 0) return error.NotPublished;
        const id = try std.ascii.allocLowerString(arena, key);
        const url = try arena.print("https://raw.communitydragon.org/{s}/game/data/characters/{s}/{s}.bin.json", .{ patch, id, id });
        const body = ddragon.fetch(http, arena, url) catch |err| switch (err) {
            error.UnexpectedStatus => continue,
            else => return err,
        };
        try out.append(arena, .{ .key = key, .numbers = try extract(arena, body) });
    }
    var file = try cwd.createFileAtomic(io, path, .{ .make_path = true, .replace = true });
    defer file.deinit(io);
    try file.file.writeStreamingAll(io, try std.json.Stringify.valueAlloc(arena, out.items, .{}));
    try file.replace(io);
    return out.items;
}

/// One champion's numbers from its bin JSON
pub fn extract(arena: Allocator, json: []const u8) ![]const Number {
    const root = try std.json.parseFromSliceLeaky(Value, arena, json, .{});
    if (root != .object) return error.NotBinJson;
    var record: ?std.json.ObjectMap = null;
    var spells: std.StringHashMapUnmanaged(Value) = .empty;
    for (root.object.values()) |v| {
        if (v != .object) continue;
        const t = str(v.object.get("__type")) orelse continue;
        if (std.mem.eql(u8, t, "CharacterRecord")) record = v.object;
        if (!std.mem.eql(u8, t, "SpellObject")) continue;
        const name = str(v.object.get("mScriptName")) orelse continue;
        const spell = v.object.get("mSpell") orelse continue;
        try spells.put(arena, try std.ascii.allocLowerString(arena, name), spell);
    }
    const r = record orelse return error.NoRecord;
    var out: std.ArrayList(Number) = .empty;
    for (stat_names) |s| {
        const v = r.get(s[0]) orelse r.get(try std.mem.concat(arena, u8, &.{ s[0], "Modifiable" })) orelse continue;
        const n = num(v) orelse num(field(v, "baseValue") orelse continue) orelse continue;
        try out.append(arena, .{ .slot = .stats, .kind = .stat, .name = s[1], .values = try arena.dupe(f64, &.{n}) });
    }
    var named: [5]?[]const u8 = @splat(null);
    named[0] = str(r.get("mCharacterPassiveSpell"));
    for (arr(r.get("spellNames"))[0..@min(arr(r.get("spellNames")).len, 4)], named[1..][0..@min(arr(r.get("spellNames")).len, 4)]) |v, *n| n.* = str(v);
    for (named, [_]Slot{ .p, .q, .w, .e, .r }) |path, slot| {
        const p = path orelse continue;
        const base = p[if (std.mem.findScalarLast(u8, p, '/')) |i| i + 1 else 0..];
        const spell = spells.get(try std.ascii.allocLowerString(arena, base)) orelse continue;
        try spellNumbers(arena, &out, slot, spell);
    }
    return out.items;
}

/// CharacterRecord's names (each also as name ++ "Modifiable": {baseValue}) and Data
/// Dragon's words for them. Regen, attack speed and mana are left to Data Dragon: other
/// units
const stat_names = [_][2][]const u8{
    .{ "baseHP", "Health" },
    .{ "hpPerLevel", "Health per level" },
    .{ "baseDamage", "Attack damage" },
    .{ "damagePerLevel", "Attack damage per level" },
    .{ "baseArmor", "Armour" },
    .{ "armorPerLevel", "Armour per level" },
    .{ "baseMR", "Magic resist" },
    .{ "mrPerLevel", "Magic resist per level" },
    .{ "baseMoveSpeed", "Move speed" },
    .{ "attackRange", "Attack range" },
};

fn spellNumbers(arena: Allocator, out: *std.ArrayList(Number), slot: Slot, spell: Value) !void {
    // Per rank like a DataValue, except manaValues, whose [0] is rank 1
    const cooldown = arr(field(field(spell, "Cooldown") orelse .null, "values"));
    for ([_]struct { []const u8, []const Value, usize }{
        .{ "Cooldown", if (cooldown.len > 0) cooldown else arr(field(spell, "cooldownTime")), 0 },
        .{ "Cost", arr(field(field(spell, "manaValues") orelse .null, "values")), 1 },
        .{ "AmmoRecharge", arr(field(spell, "mAmmoRechargeTime")), 0 },
    }) |f| {
        const values = try arena.alloc(f64, f[1].len + f[2]);
        if (values.len == 0) continue;
        values[0] = 0;
        for (values[f[2]..], f[1]) |*x, v| x.* = num(v) orelse 0;
        // Some patches' files hold zeros for a field others fill (Anivia's passive)
        if (std.mem.allEqual(f64, values, 0)) continue;
        try out.append(arena, .{ .slot = slot, .kind = .spell, .name = f[0], .values = values });
    }
    for (arr(field(spell, "DataValues"))) |dv| {
        const name = str(field(dv, "name")) orelse continue;
        if (hashed(name)) continue;
        const vs = arr(field(dv, "values"));
        if (vs.len == 0) continue;
        const values = try arena.alloc(f64, vs.len);
        for (values, vs) |*x, v| x.* = num(v) orelse 0;
        try out.append(arena, .{ .slot = slot, .kind = .value, .name = name, .values = values });
    }
    const calcs = field(spell, "mSpellCalculations") orelse return;
    if (calcs != .object) return;
    var it = calcs.object.iterator();
    while (it.next()) |e| {
        if (hashed(e.key_ptr.*)) continue;
        const start = out.items.len;
        try calcNumbers(arena, out, slot, e.key_ptr.*, e.value_ptr.*, "");
        dedupe(out, start);
    }
}

/// The numbers under one calculation. Its parts are found by what they hold, not where,
/// so reordered parts read the same
fn calcNumbers(arena: Allocator, out: *std.ArrayList(Number), slot: Slot, calc: []const u8, v: Value, path: []const u8) Allocator.Error!void {
    switch (v) {
        .object => |o| {
            if (o.get("mCoefficient")) |c| if (num(c)) |x| {
                try out.append(arena, .{ .slot = slot, .kind = .ratio, .name = calc, .of = statOf(o), .values = try arena.dupe(f64, &.{x}) });
            };
            if (o.get("mStartValue") != null or o.get("mEndValue") != null) {
                const a = num(o.get("mStartValue") orelse .{ .integer = 0 }) orelse 0;
                const b = num(o.get("mEndValue") orelse .{ .integer = 0 }) orelse 0;
                try out.append(arena, .{ .slot = slot, .kind = .levels, .name = calc, .values = try arena.dupe(f64, &.{ a, b }) });
            }
            var it = o.iterator();
            while (it.next()) |e| {
                const k = e.key_ptr.*;
                const sub = try arena.print("{s}{s}{s}", .{ path, if (path.len > 0) "/" else "", k });
                if (isNumberField(k)) {
                    if (num(e.value_ptr.*)) |x| try out.append(arena, .{ .slot = slot, .kind = .number, .name = calc, .of = sub, .values = try arena.dupe(f64, &.{x}) });
                } else try calcNumbers(arena, out, slot, calc, e.value_ptr.*, sub);
            }
        },
        .array => |a| for (a.items, 0..) |x, i| {
            try calcNumbers(arena, out, slot, calc, x, try arena.print("{s}[{d}]", .{ path, i }));
        },
        else => {},
    }
}

fn isNumberField(k: []const u8) bool {
    for ([_][]const u8{ "mNumber", "mLevel1Value", "mAdditionalBonusAtThisLevel", "mBonusPerLevelAtAndAfter" }) |n| {
        if (std.mem.eql(u8, k, n)) return true;
    }
    return false;
}

/// A ratio's stat in words, from mStat and mStatFormula (codes read off the files:
/// Rammus' armour and magic resist, Sion's health); "" when not known
fn statOf(o: std.json.ObjectMap) []const u8 {
    const stat: i64 = if (o.get("mStat")) |s| (if (s == .integer) s.integer else -1) else 0;
    const formula: i64 = if (o.get("mStatFormula")) |s| (if (s == .integer) s.integer else -1) else 0;
    const names = [_]struct { i64, [3][]const u8 }{
        .{ 0, .{ "AP", "base AP", "bonus AP" } },
        .{ 1, .{ "armour", "base armour", "bonus armour" } },
        .{ 2, .{ "AD", "base AD", "bonus AD" } },
        .{ 6, .{ "magic resist", "base magic resist", "bonus magic resist" } },
        .{ 12, .{ "health", "base health", "bonus health" } },
    };
    if (formula < 0 or formula > 2) return "";
    for (names) |n| if (n[0] == stat) return n[1][@intCast(formula)];
    return "";
}

/// Two parts of one calculation with the same key (two AP ratios): keep the first
fn dedupe(out: *std.ArrayList(Number), start: usize) void {
    var n = start;
    for (out.items[start..]) |x| {
        const dup = for (out.items[start..n]) |y| {
            if (y.same(x)) break true;
        } else false;
        if (dup) continue;
        out.items[n] = x;
        n += 1;
    }
    out.shrinkRetainingCapacity(n);
}

fn hashed(name: []const u8) bool {
    return name.len == 0 or name[0] == '{';
}

fn field(v: Value, name: []const u8) ?Value {
    return if (v == .object) v.object.get(name) else null;
}

fn str(v: ?Value) ?[]const u8 {
    const x = v orelse return null;
    return if (x == .string) x.string else null;
}

fn arr(v: ?Value) []const Value {
    const x = v orelse return &.{};
    return if (x == .array) x.array.items else &.{};
}

fn num(v: Value) ?f64 {
    return switch (v) {
        .integer => |i| @floatFromInt(i),
        .float => |f| f,
        else => null,
    };
}

const testing = std.testing;

pub const varus_old =
    \\{"Characters/Varus/CharacterRecords/Root":{"__type":"CharacterRecord","mCharacterName":"Varus",
    \\ "baseHPModifiable":{"baseValue":600.0},"damagePerLevelModifiable":{"baseValue":3.25},"attackRange":575.0,
    \\ "mCharacterPassiveSpell":"Characters/Varus/Spells/VarusPassiveAbility/VarusPassive",
    \\ "spellNames":["VarusQAbility/VarusQ","VarusWAbility/VarusW","VarusE","VarusR"]},
    \\"Characters/Varus/Spells/VarusQAbility/VarusQ":{"__type":"SpellObject","mScriptName":"VarusQ","mSpell":{
    \\ "Cooldown":{"values":[17,16,15,14,13,12,11]},"manaValues":{"values":[50,55,60,65,70,75]},"cooldownTime":[1,1,1,1,1,1,1],
    \\ "DataValues":[{"name":"BaseDamageMax","values":[10,80,150,220,290,360,430]},{"name":"{0508ccce}","values":[1,1,1,1,1,1,1]}],
    \\ "DataValuesModeOverride":{"cherry":{"SpellDataValues":[{"name":"tADRatioMax","values":[1.5]}]}},
    \\ "mSpellCalculations":{"TotalDamage":{"mFormulaParts":[{"__type":"StatByCoefficientCalculationPart","mStat":2,"mStatFormula":2,"mCoefficient":0.55},
    \\  {"__type":"StatByCoefficientCalculationPart","mCoefficient":0.3},{"__type":"ByCharLevelInterpolationCalculationPart","mStartValue":40.0,"mEndValue":140.0}]},
    \\  "{b3ef3984}":{"mFormulaParts":[{"mCoefficient":9.0}]}}}},
    \\"Characters/Varus/Spells/VarusQMissile":{"__type":"SpellObject","mScriptName":"VarusQMissile","mSpell":{"DataValues":[{"name":"X","values":[1]}]}},
    \\"Characters/Varus/Spells/VarusWAbility/VarusW":{"__type":"SpellObject","mScriptName":"VarusW","mSpell":{
    \\ "mSpellCalculations":{"PerStack":{"mFormulaParts":[{"mSubpart":{"mPart2":{"__type":"NumberCalculationPart","mNumber":0.013}}}]}}}}
    \\}
;

test "extract: base stats, main spells' values and calculation numbers" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const ns = try extract(arena_state.allocator(), varus_old);
    const want = [_]Number{
        .{ .slot = .stats, .kind = .stat, .name = "Health", .values = &.{600} },
        .{ .slot = .stats, .kind = .stat, .name = "Attack damage per level", .values = &.{3.25} },
        .{ .slot = .stats, .kind = .stat, .name = "Attack range", .values = &.{575} },
        .{ .slot = .q, .kind = .spell, .name = "Cooldown", .values = &.{ 17, 16, 15, 14, 13, 12, 11 } },
        .{ .slot = .q, .kind = .spell, .name = "Cost", .values = &.{ 0, 50, 55, 60, 65, 70, 75 } },
        .{ .slot = .q, .kind = .value, .name = "BaseDamageMax", .values = &.{ 10, 80, 150, 220, 290, 360, 430 } },
        .{ .slot = .q, .kind = .ratio, .name = "TotalDamage", .of = "bonus AD", .values = &.{0.55} },
        .{ .slot = .q, .kind = .ratio, .name = "TotalDamage", .of = "AP", .values = &.{0.3} },
        .{ .slot = .q, .kind = .levels, .name = "TotalDamage", .values = &.{ 40, 140 } },
        .{ .slot = .w, .kind = .number, .name = "PerStack", .of = "mFormulaParts[0]/mSubpart/mPart2/mNumber", .values = &.{0.013} },
    };
    try testing.expectEqualDeep(@as([]const Number, &want), ns);
}

test "cached: read back without the network" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const champs = [_]Champion{.{ .key = "Varus", .numbers = try extract(arena, varus_old) }};
    try tmp.dir.writeFile(io, .{ .sub_path = "cdragon.json", .data = try std.json.Stringify.valueAlloc(arena, champs, .{}) });
    const path = try std.fs.path.join(arena, &.{ ".zig-cache", "tmp", &tmp.sub_path, "cdragon.json" });
    var http: std.http.Client = .{ .allocator = testing.allocator, .io = io };
    defer http.deinit();
    const got = try cached(&http, arena, io, path, "16.20", &.{"Varus"});
    try testing.expectEqualDeep(@as([]const Champion, &champs), got);
}
