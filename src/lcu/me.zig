//! The local player's own data from the League client: champion mastery and visible
//! solo queue tier. Only the fields the lane card needs are parsed; identities in the
//! replies (puuid, summonerId) are never kept.

const std = @import("std");

pub const paths = struct {
    pub const mastery = "/lol-champion-mastery/v1/local-player/champion-mastery";
    pub const ranked = "/lol-ranked/v1/current-ranked-stats";
};

pub const Mastery = struct { champion: u32, points: u32 };

const json_opts: std.json.ParseOptions = .{
    .ignore_unknown_fields = true,
    .allocate = .alloc_always,
};

/// Most points first. Allocates in `arena`
pub fn parseMastery(arena: std.mem.Allocator, json: []const u8) ![]Mastery {
    const Row = struct { championId: i64 = 0, championPoints: i64 = 0 };
    const rows = try std.json.parseFromSliceLeaky([]const Row, arena, json, json_opts);
    var out: std.ArrayList(Mastery) = .empty;
    for (rows) |r| {
        if (r.championId <= 0 or r.championId > std.math.maxInt(u32)) continue;
        try out.append(arena, .{
            .champion = @intCast(r.championId),
            .points = std.math.lossyCast(u32, r.championPoints),
        });
    }
    std.mem.sort(Mastery, out.items, {}, struct {
        fn more(_: void, a: Mastery, b: Mastery) bool {
            return a.points > b.points;
        }
    }.more);
    return out.items;
}

/// Ranked Solo/Duo tier ("GOLD"), null when unranked or missing. Allocates in `arena`
pub fn parseSoloTier(arena: std.mem.Allocator, json: []const u8) !?[]const u8 {
    const Queue = struct { tier: []const u8 = "" };
    const Ranked = struct {
        queueMap: struct { RANKED_SOLO_5x5: Queue = .{} } = .{},
    };
    const r = try std.json.parseFromSliceLeaky(Ranked, arena, json, json_opts);
    const tier = r.queueMap.RANKED_SOLO_5x5.tier;
    if (tier.len == 0 or std.mem.eql(u8, tier, "NONE")) return null;
    return tier;
}

test "mastery sorted, bad rows dropped" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const json =
        \\[{"championId":103,"championPoints":1200,"puuid":"x"},
        \\ {"championId":0,"championPoints":5},
        \\ {"championId":266,"championPoints":91000,"championLevel":12}]
    ;
    const m = try parseMastery(arena.allocator(), json);
    try std.testing.expectEqual(2, m.len);
    try std.testing.expectEqual(266, m[0].champion);
    try std.testing.expectEqual(91000, m[0].points);
}

test "solo tier" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const ranked =
        \\{"queueMap":{"RANKED_FLEX_SR":{"tier":"SILVER"},
        \\ "RANKED_SOLO_5x5":{"tier":"GOLD","division":"II"}},"queues":[]}
    ;
    try std.testing.expectEqualStrings("GOLD", (try parseSoloTier(a, ranked)).?);
    const none =
        \\{"queueMap":{"RANKED_SOLO_5x5":{"tier":"NONE"}}}
    ;
    try std.testing.expectEqual(null, try parseSoloTier(a, none));
    try std.testing.expectEqual(null, try parseSoloTier(a, "{}"));
}
