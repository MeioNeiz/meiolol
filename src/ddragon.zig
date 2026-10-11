//! Champion ids and names from Data Dragon.

const std = @import("std");
const store = @import("store");

const base = "https://ddragon.leagueoflegends.com";

pub fn refresh(gpa: std.mem.Allocator, io: std.Io, db: store.Db) !usize {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    const a = arena.allocator();
    var http: std.http.Client = .{ .allocator = gpa, .io = io };
    defer http.deinit();

    const versions = try std.json.parseFromSliceLeaky(
        []const []const u8,
        a,
        try fetch(&http, a, base ++ "/api/versions.json"),
        .{},
    );
    const version = versions[0];
    const url = try std.fmt.allocPrint(a, base ++ "/cdn/{s}/data/en_GB/champion.json", .{version});
    const Champion = struct { key: []const u8, id: []const u8, name: []const u8, tags: []const []const u8 = &.{} };
    const doc = try std.json.parseFromSliceLeaky(
        struct { data: std.json.ArrayHashMap(Champion) },
        a,
        try fetch(&http, a, url),
        .{ .ignore_unknown_fields = true },
    );

    try db.begin();
    errdefer db.rollback();
    var ins = try db.prepare("INSERT OR REPLACE INTO champions VALUES (?,?,?,?,?)");
    defer ins.deinit();
    for (doc.data.map.values()) |c| {
        const tags = try std.mem.join(a, ",", c.tags);
        try ins.exec(.{ try std.fmt.parseInt(i64, c.key, 10), c.id, c.name, tags, version });
    }
    try db.commit();
    return doc.data.map.count();
}

fn fetch(http: *std.http.Client, arena: std.mem.Allocator, url: []const u8) ![]u8 {
    var body: std.Io.Writer.Allocating = .init(arena);
    const res = try http.fetch(.{ .location = .{ .url = url }, .response_writer = &body.writer });
    if (res.status != .ok) return error.UnexpectedStatus;
    return body.written();
}

/// The Data Dragon version for `patch` ("16.20" -> "16.20.1"), else the newest
fn versionFor(http: *std.http.Client, arena: std.mem.Allocator, patch: []const u8) ![]const u8 {
    const versions = try std.json.parseFromSliceLeaky(
        []const []const u8,
        arena,
        try fetch(http, arena, base ++ "/api/versions.json"),
        .{},
    );
    if (versions.len == 0) return error.NoVersions;
    for (versions) |v| {
        if (std.mem.startsWith(u8, v, patch) and v.len > patch.len and v[patch.len] == '.') return v;
    }
    return versions[0];
}

/// Finished items for first-item timing: on Summoner's Rift, bought in the shop, at least
/// 2200 gold, building into nothing; no boots, consumables or champion-only items.
/// Sorted ids, from the Data Dragon version for `patch` ("16.20") or else the newest.
pub fn legendaries(gpa: std.mem.Allocator, io: std.Io, patch: []const u8) ![]u32 {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    const a = arena.allocator();
    var http: std.http.Client = .{ .allocator = gpa, .io = io };
    defer http.deinit();
    const version = try versionFor(&http, a, patch);
    const url = try std.fmt.allocPrint(a, base ++ "/cdn/{s}/data/en_GB/item.json", .{version});
    return parseLegendaries(gpa, a, try fetch(&http, a, url));
}

const ItemJson = struct {
    name: []const u8 = "",
    gold: struct { total: u32, purchasable: bool },
    maps: std.json.ArrayHashMap(bool),
    from: []const []const u8 = &.{},
    into: []const []const u8 = &.{},
    tags: []const []const u8 = &.{},
    requiredChampion: []const u8 = "",
    requiredAlly: []const u8 = "",
    inStore: bool = true,
    image: struct { full: []const u8 = "" } = .{},

    fn onRift(item: ItemJson) bool {
        return item.maps.map.get("11") orelse false;
    }

    fn tagged(item: ItemJson, tag: []const u8) bool {
        for (item.tags) |t| if (std.mem.eql(u8, t, tag)) return true;
        return false;
    }

    fn legendary(item: ItemJson) bool {
        if (!item.onRift() or !item.gold.purchasable or item.gold.total < 2200 or !item.inStore) return false;
        if (item.into.len > 0 or item.requiredChampion.len > 0 or item.requiredAlly.len > 0) return false;
        return !item.tagged("Boots") and !item.tagged("Consumable");
    }
};

fn parseItems(arena: std.mem.Allocator, body: []const u8) !std.json.ArrayHashMap(ItemJson) {
    const doc = try std.json.parseFromSliceLeaky(
        struct { data: std.json.ArrayHashMap(ItemJson) },
        arena,
        body,
        .{ .ignore_unknown_fields = true },
    );
    return doc.data;
}

fn parseLegendaries(gpa: std.mem.Allocator, arena: std.mem.Allocator, body: []const u8) ![]u32 {
    const items = try parseItems(arena, body);
    var ids: std.ArrayList(u32) = .empty;
    errdefer ids.deinit(gpa);
    var it = items.map.iterator();
    while (it.next()) |e| {
        if (!e.value_ptr.legendary()) continue;
        try ids.append(gpa, std.fmt.parseInt(u32, e.key_ptr.*, 10) catch continue);
    }
    std.mem.sort(u32, ids.items, {}, std.sort.asc(u32));
    return ids.toOwnedSlice(gpa);
}

/// An item, rune, rune tree or summoner spell for display; icon is a full Data Dragon
/// URL ("" for stat shards, which have no icon there)
pub const Named = struct { id: u32, name: []const u8, icon: []const u8 = "" };

/// What the builds step (src/builds.zig) needs from Data Dragon: which items are
/// finished, boots or trinkets, and names and icons for the pages. Slices sorted by id
pub const BuildData = struct {
    version: []const u8,
    /// As for legendaries
    legendary: []const u32,
    trinkets: []const u32,
    /// [item, the tier-2 boots it is]: tier-2 boots map to themselves, tier-3 to the
    /// tier 2 they upgrade from. Basic Boots (1001) are not a choice and left out
    boots: []const [2]u32,
    items: []const Named,
    runes: []const Named,
    spells: []const Named,

    pub fn isLegendary(d: *const BuildData, item: u32) bool {
        return std.sort.binarySearch(u32, d.legendary, item, orderU32) != null;
    }

    pub fn isTrinket(d: *const BuildData, item: u32) bool {
        return std.sort.binarySearch(u32, d.trinkets, item, orderU32) != null;
    }

    /// The tier-2 boots `item` counts as, or null when it is not boots
    pub fn bootsOf(d: *const BuildData, item: u32) ?u32 {
        const i = std.sort.binarySearch([2]u32, d.boots, item, struct {
            fn f(key: u32, b: [2]u32) std.math.Order {
                return std.math.order(key, b[0]);
            }
        }.f) orelse return null;
        return d.boots[i][1];
    }
};

fn orderU32(key: u32, item: u32) std.math.Order {
    return std.math.order(key, item);
}

/// Stat shards are not in runesReforged.json; ids as match-v5 reports them
const shards = [_]Named{
    .{ .id = 5001, .name = "Health scaling" },
    .{ .id = 5002, .name = "Armor" },
    .{ .id = 5003, .name = "Magic resist" },
    .{ .id = 5005, .name = "Attack speed" },
    .{ .id = 5007, .name = "Ability haste" },
    .{ .id = 5008, .name = "Adaptive force" },
    .{ .id = 5010, .name = "Move speed" },
    .{ .id = 5011, .name = "Health" },
    .{ .id = 5013, .name = "Tenacity and slow resist" },
};

/// Item, rune and summoner spell data for `patch` (as legendaries), in `arena`
pub fn buildData(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: std.Io, patch: []const u8) !BuildData {
    var http: std.http.Client = .{ .allocator = gpa, .io = io };
    defer http.deinit();
    const version = try versionFor(&http, arena, patch);
    var bodies: [3][]const u8 = undefined;
    for ([_][]const u8{ "item", "runesReforged", "summoner" }, &bodies) |file, *body| {
        const url = try std.fmt.allocPrint(arena, base ++ "/cdn/{s}/data/en_GB/{s}.json", .{ version, file });
        body.* = try fetch(&http, arena, url);
    }
    return parseBuildData(arena, version, bodies[0], bodies[1], bodies[2]);
}

pub fn parseBuildData(
    arena: std.mem.Allocator,
    version: []const u8,
    item_json: []const u8,
    runes_json: []const u8,
    summoner_json: []const u8,
) !BuildData {
    const items = try parseItems(arena, item_json);
    var legendary: std.ArrayList(u32) = .empty;
    var trinkets: std.ArrayList(u32) = .empty;
    var boots: std.ArrayList([2]u32) = .empty;
    var named: std.ArrayList(Named) = .empty;
    var it = items.map.iterator();
    while (it.next()) |e| {
        const item = e.value_ptr.*;
        if (!item.onRift()) continue;
        const id = std.fmt.parseInt(u32, e.key_ptr.*, 10) catch continue;
        try named.append(arena, .{
            .id = id,
            .name = item.name,
            .icon = try std.fmt.allocPrint(arena, base ++ "/cdn/{s}/img/item/{s}", .{ version, item.image.full }),
        });
        if (item.legendary()) try legendary.append(arena, id);
        if (item.tagged("Trinket")) try trinkets.append(arena, id);
        if (item.tagged("Boots") and item.from.len > 0 and std.mem.eql(u8, item.from[0], "1001")) {
            try boots.append(arena, .{ id, id });
        }
    }
    // Tier 3: upgrades of a tier 2
    it = items.map.iterator();
    while (it.next()) |e| {
        const item = e.value_ptr.*;
        if (!item.onRift() or !item.tagged("Boots") or item.from.len != 1) continue;
        const from = std.fmt.parseInt(u32, item.from[0], 10) catch continue;
        for (boots.items) |b| if (b[0] == from and b[1] == from) {
            try boots.append(arena, .{ std.fmt.parseInt(u32, e.key_ptr.*, 10) catch break, from });
            break;
        };
    }
    std.mem.sort(u32, legendary.items, {}, std.sort.asc(u32));
    std.mem.sort(u32, trinkets.items, {}, std.sort.asc(u32));
    std.mem.sort([2]u32, boots.items, {}, struct {
        fn f(_: void, a: [2]u32, b: [2]u32) bool {
            return a[0] < b[0];
        }
    }.f);

    const Rune = struct { id: u32, name: []const u8, icon: []const u8 };
    const Tree = struct {
        id: u32,
        name: []const u8,
        icon: []const u8,
        slots: []const struct { runes: []const Rune },
    };
    const trees = try std.json.parseFromSliceLeaky([]const Tree, arena, runes_json, .{ .ignore_unknown_fields = true });
    var runes: std.ArrayList(Named) = .empty;
    try runes.appendSlice(arena, &shards);
    for (trees) |t| {
        try runes.append(arena, .{ .id = t.id, .name = t.name, .icon = try runeIcon(arena, t.icon) });
        for (t.slots) |slot| for (slot.runes) |r| {
            try runes.append(arena, .{ .id = r.id, .name = r.name, .icon = try runeIcon(arena, r.icon) });
        };
    }

    const Spell = struct { key: []const u8, name: []const u8, image: struct { full: []const u8 } };
    const doc = try std.json.parseFromSliceLeaky(
        struct { data: std.json.ArrayHashMap(Spell) },
        arena,
        summoner_json,
        .{ .ignore_unknown_fields = true },
    );
    var spells: std.ArrayList(Named) = .empty;
    for (doc.data.map.values()) |s| try spells.append(arena, .{
        .id = std.fmt.parseInt(u32, s.key, 10) catch continue,
        .name = s.name,
        .icon = try std.fmt.allocPrint(arena, base ++ "/cdn/{s}/img/spell/{s}", .{ version, s.image.full }),
    });

    for ([_][]Named{ named.items, runes.items, spells.items }) |list| {
        std.mem.sort(Named, list, {}, struct {
            fn f(_: void, a: Named, b: Named) bool {
                return a.id < b.id;
            }
        }.f);
    }
    return .{
        .version = version,
        .legendary = legendary.items,
        .trinkets = trinkets.items,
        .boots = boots.items,
        .items = named.items,
        .runes = runes.items,
        .spells = spells.items,
    };
}

fn runeIcon(arena: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.fmt.allocPrint(arena, base ++ "/cdn/img/{s}", .{path});
}

/// `id` in a list sorted by id
pub fn find(list: []const Named, id: u32) ?Named {
    const i = std.sort.binarySearch(Named, list, id, struct {
        fn f(key: u32, n: Named) std.math.Order {
            return std.math.order(key, n.id);
        }
    }.f) orelse return null;
    return list[i];
}

test "legendary items" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const body =
        \\{"data": {
        \\ "3078": {"gold": {"total": 3333, "purchasable": true}, "maps": {"11": true}},
        \\ "3009": {"gold": {"total": 1000, "purchasable": true}, "maps": {"11": true},
        \\          "into": ["3170"], "tags": ["Boots"]},
        \\ "3133": {"gold": {"total": 1100, "purchasable": true}, "maps": {"11": true},
        \\          "into": ["3071"]},
        \\ "3157": {"gold": {"total": 3250, "purchasable": true}, "maps": {"11": true, "12": true}},
        \\ "3040": {"gold": {"total": 3000, "purchasable": false}, "maps": {"11": true}},
        \\ "4403": {"gold": {"total": 3000, "purchasable": true}, "maps": {"11": false}},
        \\ "7050": {"gold": {"total": 2500, "purchasable": true}, "maps": {"11": true},
        \\          "requiredChampion": "Gangplank"}
        \\}}
    ;
    const ids = try parseLegendaries(std.testing.allocator, arena.allocator(), body);
    defer std.testing.allocator.free(ids);
    try std.testing.expectEqualSlices(u32, &.{ 3078, 3157 }, ids);
}

test "build data: boots tiers, trinkets, names" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const items =
        \\{"data": {
        \\ "1001": {"name": "Boots", "gold": {"total": 300, "purchasable": true},
        \\          "maps": {"11": true}, "into": ["3006"], "tags": ["Boots"]},
        \\ "3006": {"name": "Berserker's Greaves", "gold": {"total": 1100, "purchasable": true},
        \\          "maps": {"11": true}, "from": ["1001", "1042"], "into": ["3172"],
        \\          "tags": ["Boots"], "image": {"full": "3006.png"}},
        \\ "3172": {"name": "Gunmetal Greaves", "gold": {"total": 1600, "purchasable": true},
        \\          "maps": {"11": true}, "from": ["3006"], "tags": ["Boots"]},
        \\ "3340": {"name": "Stealth Ward", "gold": {"total": 0, "purchasable": true},
        \\          "maps": {"11": true}, "tags": ["Trinket", "Vision"]},
        \\ "3078": {"name": "Trinity Force", "gold": {"total": 3333, "purchasable": true},
        \\          "maps": {"11": true}}
        \\}}
    ;
    const runes =
        \\[{"id": 8000, "key": "Precision", "icon": "p.png", "name": "Precision",
        \\  "slots": [{"runes": [{"id": 8010, "key": "Conqueror", "icon": "c.png",
        \\  "name": "Conqueror"}]}]}]
    ;
    const spells =
        \\{"data": {"SummonerFlash": {"key": "4", "name": "Flash",
        \\  "image": {"full": "SummonerFlash.png"}}}}
    ;
    const d = try parseBuildData(arena.allocator(), "16.20.1", items, runes, spells);
    try std.testing.expectEqualSlices(u32, &.{3078}, d.legendary);
    try std.testing.expect(d.isTrinket(3340));
    try std.testing.expectEqual(3006, d.bootsOf(3006).?);
    try std.testing.expectEqual(3006, d.bootsOf(3172).?);
    try std.testing.expectEqual(null, d.bootsOf(1001));
    try std.testing.expectEqualStrings(
        "https://ddragon.leagueoflegends.com/cdn/16.20.1/img/item/3006.png",
        find(d.items, 3006).?.icon,
    );
    try std.testing.expectEqualStrings("Conqueror", find(d.runes, 8010).?.name);
    try std.testing.expectEqualStrings("Adaptive force", find(d.runes, 5008).?.name);
    try std.testing.expectEqualStrings("Flash", find(d.spells, 4).?.name);
}
