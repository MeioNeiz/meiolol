//! The shared held-out split (docs/model.md "Shared protocol"): eval's own split over
//! every platform, tested on EUW1, so meiolol-lab and meiolol eval score the same games.
//! Writes split.tsv into the snapshot: one line per test game

const std = @import("std");
const store = @import("store");
const stats = @import("../stats.zig");
const eval = @import("../eval.zig");
const riot = @import("../riot/root.zig");
const Date = @import("../date.zig").Date;
const timeline = @import("../riot/timeline.zig");

pub const test_platform = "EUW1";

const GameList = struct {
    gpa: std.mem.Allocator,
    items: std.ArrayList(stats.Row) = .empty,

    pub fn add(l: *GameList, g: stats.Row) !void {
        try l.items.append(l.gpa, g);
    }
};

/// Continuous outcomes need a game that reached 15:00 (docs/model.md "Shared protocol"):
/// frame k is minute k only up to the last frame, which is the game's end, so a game
/// ending at 14:30 has a 16th frame too
pub fn reached15Timeline(t: timeline.Timeline) bool {
    return t.frames.len >= 16 and t.frames[15].t_ms >= 15 * 60_000;
}

fn reached15(arena: std.mem.Allocator, blob: []const u8) bool {
    const raw = store.raw.decompress(arena, blob) catch return false;
    const t = timeline.decode(arena, raw) catch return false;
    return reached15Timeline(t);
}

pub fn platformIds() [riot.endpoints.platforms.len][]const u8 {
    var ids: [riot.endpoints.platforms.len][]const u8 = undefined;
    for (riot.endpoints.platforms, &ids) |p, *id| id.* = p.id;
    return ids;
}

/// Prints the split and writes SNAP/split.tsv (match_id, game_start, timeline frames or 0,
/// reached15 0/1)
pub fn writeSplit(gpa: std.mem.Allocator, io: std.Io, snap: []const u8, w: *std.Io.Writer) !void {
    const db = try store.schema.openReadOnly(gpa, snap);
    defer db.close();
    const ids = platformIds();
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    const patches = try stats.patches(arena.allocator(), db, &ids);
    var list: GameList = .{ .gpa = gpa };
    defer list.items.deinit(gpa);
    const summary = try stats.scan(gpa, db, patches, &ids, 0, &list);
    var parts = try eval.split(gpa, list.items.items, &ids, .{ .test_platform = test_platform });
    defer parts.deinit(gpa);

    var keys: std.AutoHashMapUnmanaged(u64, void) = .empty;
    defer keys.deinit(gpa);
    for (parts.tests) |g| try keys.put(gpa, g.id, {});

    const path = try std.fs.path.join(gpa, &.{ snap, "split.tsv" });
    defer gpa.free(path);
    var file = try std.Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    var buf: [64 * 1024]u8 = undefined;
    var out = file.writer(io, &buf);
    try out.interface.writeAll("match_id\tgame_start\tframes\treached15\n");
    var tl_arena: std.heap.ArenaAllocator = .init(gpa);
    defer tl_arena.deinit();
    var q = try db.prepare(
        \\SELECT m.match_id, m.game_start, coalesce(t.frames, 0), t.data
        \\FROM matches m LEFT JOIN timeline.timelines t USING (match_id)
        \\WHERE m.platform = ? AND m.game_start >= ? ORDER BY m.game_start, m.match_id
    );
    defer q.deinit();
    try q.bind(.{ test_platform, parts.tests[0].start });
    var written: usize = 0;
    var with_15: usize = 0;
    while (try q.step()) {
        const r = q.row(struct { match_id: []const u8, game_start: i64, frames: i64, data: ?[]const u8 });
        if (!keys.contains(stats.matchKey(r.match_id))) continue;
        _ = tl_arena.reset(.retain_capacity);
        const reached = if (r.data) |blob| reached15(tl_arena.allocator(), blob) else false;
        try out.interface.print("{s}\t{d}\t{d}\t{d}\n", .{ r.match_id, r.game_start, r.frames, @intFromBool(reached) });
        written += 1;
        with_15 += @intFromBool(reached);
    }
    try out.interface.flush();
    if (written != parts.tests.len) return error.SplitMismatch;

    const train = parts.train;
    try w.print("snapshot {s}: {d} games scanned ({d} skipped), {d} patches, {d} platforms\n", .{
        std.fs.path.basename(snap), list.items.items.len, summary.skipped, patches.len, ids.len,
    });
    try w.print("train: {d} games, {f} to {f}, every platform older than the first test game\n", .{
        train.len, Date.fromMs(train[0].start), Date.fromMs(train[train.len - 1].start),
    });
    try w.print("test: {d} {s} games, game_start >= {d} ({f} to {f}); {d} with a timeline reaching 15:00\n", .{
        parts.tests.len,                   test_platform,                                       parts.tests[0].start,
        Date.fromMs(parts.tests[0].start), Date.fromMs(parts.tests[parts.tests.len - 1].start), with_15,
    });
    try w.print("wrote {s}\n", .{path});
}
