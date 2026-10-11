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

/// Finished items for first-item timing: on Summoner's Rift, bought in the shop, at least
/// 2200 gold, building into nothing; no boots, consumables or champion-only items.
/// Sorted ids, from the Data Dragon version for `patch` ("16.20") or else the newest.
pub fn legendaries(gpa: std.mem.Allocator, io: std.Io, patch: []const u8) ![]u32 {
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
    var version = versions[0];
    for (versions) |v| if (std.mem.startsWith(u8, v, patch) and v.len > patch.len and v[patch.len] == '.') {
        version = v;
        break;
    };
    const url = try std.fmt.allocPrint(a, base ++ "/cdn/{s}/data/en_GB/item.json", .{version});
    return parseLegendaries(gpa, a, try fetch(&http, a, url));
}

fn parseLegendaries(gpa: std.mem.Allocator, arena: std.mem.Allocator, body: []const u8) ![]u32 {
    const Item = struct {
        gold: struct { total: u32, purchasable: bool },
        maps: std.json.ArrayHashMap(bool),
        into: []const []const u8 = &.{},
        tags: []const []const u8 = &.{},
        requiredChampion: []const u8 = "",
        requiredAlly: []const u8 = "",
        inStore: bool = true,
    };
    const doc = try std.json.parseFromSliceLeaky(
        struct { data: std.json.ArrayHashMap(Item) },
        arena,
        body,
        .{ .ignore_unknown_fields = true },
    );
    var ids: std.ArrayList(u32) = .empty;
    errdefer ids.deinit(gpa);
    var it = doc.data.map.iterator();
    items: while (it.next()) |e| {
        const item = e.value_ptr.*;
        if (!(item.maps.map.get("11") orelse false)) continue;
        if (!item.gold.purchasable or item.gold.total < 2200 or !item.inStore) continue;
        if (item.into.len > 0 or item.requiredChampion.len > 0 or item.requiredAlly.len > 0) continue;
        for (item.tags) |t| {
            if (std.mem.eql(u8, t, "Boots") or std.mem.eql(u8, t, "Consumable")) continue :items;
        }
        try ids.append(gpa, std.fmt.parseInt(u32, e.key_ptr.*, 10) catch continue);
    }
    std.mem.sort(u32, ids.items, {}, std.sort.asc(u32));
    return ids.toOwnedSlice(gpa);
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
