//! End to end on fixtures: match JSON and timeline into the tables as the crawler stores
//! them, then the commands the box runs (stats, drafts, curves, site). Catches what unit
//! tests miss: a page that fails on thin data, a file format the next step cannot read.

const std = @import("std");
const store = @import("store");
const core = @import("core");
const riot = @import("riot/root.zig");
const stats = @import("stats.zig");
const curves = @import("curves.zig");
const site = @import("site/root.zig");

const testing = std.testing;
const games = 3;
const patch = "15.13";
/// Fixed game start; since_ms 0 keeps the games in the 30-day views
const start_ms = 1_752_000_000_000;

test "fixture games to stats, curves and the website" {
    const gpa = testing.allocator;
    const io = testing.io;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir = try std.fs.path.join(arena, &.{ ".zig-cache", "tmp", &tmp.sub_path });

    const db = try store.schema.memory();
    defer db.close();
    try fill(arena, db);

    var st = try stats.build(gpa, db, &.{patch}, &.{"EUW1"});
    defer st.builder.deinit();
    try testing.expectEqual(games, st.summary.games);
    var model: std.Io.Writer.Allocating = .init(arena);
    try st.builder.write(&model.writer, patch);
    _ = try core.Stats.parse(arena, model.written());

    // Draft rows of the same games, as `meiolol draft-backfill` adds them
    try db.exec("INSERT INTO draft_backfill SELECT match_id FROM matches");
    var drafts: store.draft.Builder = try .init(db);
    defer drafts.deinit();
    _ = try store.draft.backfillChunk(gpa, db, &drafts, 100);
    var reader: store.draft.Reader = try .init(gpa, db, .{ .patches = &.{patch}, .platforms = &.{"EUW1"} });
    defer reader.deinit();
    var n_drafts: usize = 0;
    while (try reader.next()) |d| : (n_drafts += 1) {
        for (d.picks) |p| try testing.expect(p.role != null);
    }
    try testing.expectEqual(games, n_drafts);

    var cv = try curves.build(gpa, db, &.{patch}, 0, &.{"EUW1"}, &.{});
    defer cv.builder.deinit();
    try testing.expectEqual(games, cv.summary.games);
    const curves_path = try std.fs.path.join(arena, &.{ dir, "curves.bin" });
    var curves_bytes: std.Io.Writer.Allocating = .init(arena);
    try cv.builder.write(&curves_bytes.writer, patch, 1);
    try tmp.dir.writeFile(io, .{ .sub_path = "curves.bin", .data = curves_bytes.written() });

    const out = try std.fs.path.join(arena, &.{ dir, "site" });
    try site.generate(gpa, io, db, .{
        .out_dir = out,
        .patches = &.{patch},
        .since_ms = 0,
        .all_platforms = &.{"EUW1"},
        .contact = "test@example.com",
        .updated = "1 January 2026",
        // No daily: puzzles need three other options for a slot, more than 10 champions
        .curves = @splat(curves_path),
    });
    for ([_][]const u8{
        "index.html",
        "patch/index.html",
        "all/patch/index.html",
        "data/stats.bin",
        "matchup/index.html",
        "learn.html",
        "privacy.html",
    }) |page| {
        const path = try std.fs.path.join(arena, &.{ out, page });
        std.Io.Dir.cwd().access(io, path, .{}) catch |err| {
            std.debug.print("missing {s}\n", .{page});
            return err;
        };
    }
}

/// The fixture game stored `games` times under EUW match ids, with its timeline and
/// champion names, as the crawler and `meiolol champions` leave them
fn fill(arena: std.mem.Allocator, db: store.Db) !void {
    const body = @embedFile("riot/testdata/match.json");
    const json = try store.raw.decompress(arena, @embedFile("riot/testdata/timeline.json.gz"));
    const ct = try riot.crawl.compactTimeline(arena, json);
    for (0..games) |n| {
        var doc = try riot.match.parse(arena, body);
        doc.metadata.matchId = try std.fmt.allocPrint(arena, "EUW1_{d}", .{n + 1});
        doc.info.platformId = "EUW1";
        doc.info.gameVersion = patch ++ ".1.1";
        doc.info.gameStartTimestamp = start_ms;
        try riot.match.storeRows(db, doc, "riot");
        try db.run("INSERT INTO timeline.timelines VALUES (?,?,?,?)", .{
            doc.metadata.matchId, ct.frames, ct.events, store.Blob{ .bytes = ct.blob },
        });
    }
    for (fixture_champions) |c| {
        try db.run("INSERT INTO champions VALUES (?,?,?,'','15.13.1')", .{ c.id, c.key, c.key });
    }
}

/// Champions of the fixture game
const fixture_champions = [_]struct { id: u32, key: []const u8 }{
    .{ .id = 122, .key = "Darius" },
    .{ .id = 32, .key = "Amumu" },
    .{ .id = 61, .key = "Orianna" },
    .{ .id = 29, .key = "Twitch" },
    .{ .id = 555, .key = "Pyke" },
    .{ .id = 82, .key = "Mordekaiser" },
    .{ .id = 64, .key = "LeeSin" },
    .{ .id = 103, .key = "Ahri" },
    .{ .id = 145, .key = "Kaisa" },
    .{ .id = 497, .key = "Rakan" },
};
