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
