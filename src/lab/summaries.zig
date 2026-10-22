//! Every queue 420 game's match-v5 summary, once, for the per-seat exports (seatstats,
//! compstats). The box keeps raw summaries ~2 days before the archive takes them, so a
//! snapshot's raw.db alone covers only its newest games: SNAP/raw.db first, then the raw
//! archive's summaries files (lab/archive.zig, ids hashed with the snapshot's salt).
//! zstd on PATH for the archive

const std = @import("std");
const store = @import("store");
const archive = @import("archive.zig");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.summaries);

const ranked_solo = 420;

/// Champion ids of a game by slot, 0 for none
pub const Game = struct { champions: [10]u32 = @splat(0), done: bool = false };
pub const Games = std.StringHashMapUnmanaged(Game);

/// Queue 420 games of SNAP/meiolol.db; keys live in `arena`
pub fn loadGames(gpa: Allocator, arena: Allocator, snap: []const u8) !Games {
    var games: Games = .empty;
    errdefer games.deinit(gpa);
    const path = try std.fs.path.joinZ(arena, &.{ snap, "meiolol.db" });
    const db = try store.sqlite.Db.openReadOnly(path);
    defer db.close();
    var q = try db.prepare(
        \\SELECT p.match_id, p.slot, p.champion_id
        \\FROM participants p JOIN matches m USING (match_id) WHERE m.queue_id = ?
    );
    defer q.deinit();
    try q.bind(.{ranked_solo});
    while (try q.step()) {
        const g = try games.getOrPut(gpa, q.bytes(0));
        if (!g.found_existing) {
            g.key_ptr.* = try arena.dupe(u8, q.bytes(0));
            g.value_ptr.* = .{};
        }
        const slot = q.int(1);
        if (slot >= 0 and slot < 10) g.value_ptr.champions[@intCast(slot)] = @intCast(q.int(2));
    }
    return games;
}

pub const Doc = struct {
    key: []const u8,
    champions: [10]u32,
    body: []const u8,
    /// store.raw compressed (raw.db) rather than plain JSON (archive)
    compressed: bool,

    pub fn json(d: Doc, a: Allocator) ![]const u8 {
        return if (d.compressed) store.raw.decompress(a, d.body) else d.body;
    }
};

pub const Counts = struct {
    from_raw: usize = 0,
    from_archive: usize = 0,
    archive_files: usize = 0,
};

pub const batch_len = 4096;

/// Calls `sink.batch(docs)` with up to batch_len summaries of games in `games` not yet
/// done, marking them done; bodies live until the next call
pub fn each(
    gpa: Allocator,
    io: Io,
    snap: []const u8,
    archive_dir: ?[]const u8,
    games: *Games,
    sink: anytype,
) !Counts {
    var counts: Counts = .{};
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const docs = try gpa.alloc(Doc, batch_len);
    defer gpa.free(docs);
    var b: Buffer(@TypeOf(sink)) = .{ .arena = .init(gpa), .games = games, .docs = docs, .sink = sink };
    defer b.arena.deinit();

    {
        const path = try std.fs.path.joinZ(arena_state.allocator(), &.{ snap, "raw.db" });
        const db = try store.sqlite.Db.openReadOnly(path);
        defer db.close();
        var q = try db.prepare("SELECT key, body FROM raw_docs WHERE source = 'riot_match'");
        defer q.deinit();
        try q.bind(.{});
        while (try q.step()) counts.from_raw += @intFromBool(try b.add(q.bytes(0), q.bytes(1), true));
        try b.flush();
    }
    if (archive_dir) |dir| {
        const files = try summaryFiles(arena_state.allocator(), io, dir);
        const buf = try gpa.alloc(u8, 16 << 20);
        defer gpa.free(buf);
        for (files) |path| {
            var child = try std.process.spawn(io, .{
                .argv = &.{ "zstd", "-dc", "-q", "--long=27", path },
                .stdin = .ignore,
                .stdout = .pipe,
            });
            defer child.kill(io);
            var r = child.stdout.?.readerStreaming(io, buf);
            while (r.interface.takeDelimiter('\n') catch |e| return r.err orelse e) |line| {
                const id = matchId(line) orelse continue;
                counts.from_archive += @intFromBool(try b.add(id, line, false));
            }
            const term = try child.wait(io);
            if (!term.success()) {
                log.err("zstd -dc {s}: {f}", .{ path, term });
                return error.ZstdFailed;
            }
            counts.archive_files += 1;
        }
        try b.flush();
    }
    return counts;
}

fn Buffer(comptime Sink: type) type {
    return struct {
        arena: std.heap.ArenaAllocator,
        games: *Games,
        docs: []Doc,
        sink: Sink,
        n: usize = 0,

        const B = @This();

        fn add(b: *B, key: []const u8, body: []const u8, compressed: bool) !bool {
            const g = b.games.getEntry(key) orelse return false;
            if (g.value_ptr.done) return false;
            g.value_ptr.done = true;
            b.docs[b.n] = .{
                .key = g.key_ptr.*,
                .champions = g.value_ptr.champions,
                .body = try b.arena.allocator().dupe(u8, body),
                .compressed = compressed,
            };
            b.n += 1;
            if (b.n == b.docs.len) try b.flush();
            return true;
        }

        fn flush(b: *B) !void {
            if (b.n > 0) try b.sink.batch(b.docs[0..b.n]);
            b.n = 0;
            _ = b.arena.reset(.retain_capacity);
        }
    };
}

/// metadata.matchId, the first "matchId" of a summary
fn matchId(line: []const u8) ?[]const u8 {
    const key = "\"matchId\":\"";
    const start = (std.mem.indexOf(u8, line, key) orelse return null) + key.len;
    const end = std.mem.indexOfScalarPos(u8, line, start, '"') orelse return null;
    return line[start..end];
}

/// ARCHIVE/<day>/summaries-*.jsonl.zst, newest first (a game is read once, from its
/// newest copy)
fn summaryFiles(arena: Allocator, io: Io, archive_dir: []const u8) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    var dir = try Io.Dir.cwd().openDir(io, archive_dir, .{ .iterate = true });
    defer dir.close(io);
    var it = dir.iterate();
    while (try it.next(io)) |d| {
        if (d.kind != .directory or archive.parseDay(d.name) == null) continue;
        const day_path = try std.fs.path.join(arena, &.{ archive_dir, d.name });
        var day = try Io.Dir.cwd().openDir(io, day_path, .{ .iterate = true });
        defer day.close(io);
        var files = day.iterate();
        while (try files.next(io)) |e| {
            if (e.kind != .file or !std.mem.startsWith(u8, e.name, "summaries-")) continue;
            if (!std.mem.endsWith(u8, e.name, ".jsonl.zst")) continue;
            try out.append(arena, try std.fs.path.join(arena, &.{ day_path, e.name }));
        }
    }
    std.mem.sort([]const u8, out.items, {}, greaterThan);
    return out.items;
}

fn greaterThan(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, b, a);
}

const testing = std.testing;

test "raw.db first, then the archive, each game once" {
    const gpa = testing.allocator;
    const io = testing.io;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const snap = try arena.print(".zig-cache/tmp/{s}", .{&tmp.sub_path});
    {
        const db = try store.sqlite.Db.open(try std.fs.path.joinZ(arena, &.{ snap, "meiolol.db" }));
        defer db.close();
        try db.exec(
            \\CREATE TABLE matches (match_id TEXT PRIMARY KEY, queue_id INTEGER);
            \\CREATE TABLE participants (match_id TEXT, slot INTEGER, champion_id INTEGER);
            \\INSERT INTO matches VALUES ('A', 420), ('B', 420), ('C', 420), ('D', 450);
            \\INSERT INTO participants VALUES ('A', 0, 33), ('B', 0, 63), ('C', 3, 7), ('D', 0, 1);
        );
    }
    {
        const db = try store.sqlite.Db.open(try std.fs.path.joinZ(arena, &.{ snap, "raw.db" }));
        defer db.close();
        try db.exec("CREATE TABLE raw_docs (key TEXT, source TEXT, body BLOB)");
        const body = try store.raw.compress(arena, "{\"from\":\"raw\"}");
        try db.run("INSERT INTO raw_docs VALUES ('A', 'riot_match', ?)", .{store.Blob{ .bytes = body }});
    }
    const arch = try arena.print("{s}/archive", .{snap});
    for ([_][2][]const u8{
        .{ "2026-10-12", "{\"metadata\":{\"matchId\":\"A\"},\"from\":\"old\"}\n{\"metadata\":{\"matchId\":\"B\"}}\n" },
        .{ "2026-10-13", "{\"metadata\":{\"matchId\":\"B\"},\"from\":\"new\"}\n{\"metadata\":{\"matchId\":\"D\"}}\n" },
    }) |f| {
        const day = try arena.print("{s}/{s}", .{ arch, f[0] });
        try Io.Dir.cwd().createDirPath(io, day);
        const plain = try arena.print("{s}/summaries-x.jsonl", .{day});
        try Io.Dir.cwd().writeFile(io, .{ .sub_path = plain, .data = f[1] });
        const r = try std.process.run(gpa, io, .{ .argv = &.{ "zstd", "-q", "--rm", plain } });
        gpa.free(r.stdout);
        gpa.free(r.stderr);
    }

    var games = try loadGames(gpa, arena, snap);
    defer games.deinit(gpa);
    const Sink = struct {
        a: Allocator,
        seen: std.ArrayList([]const u8) = .empty,
        fn batch(s: *@This(), docs: []const Doc) !void {
            for (docs) |d| try s.seen.append(s.a, try s.a.dupe(u8, try d.json(s.a)));
        }
    };
    var sink: Sink = .{ .a = arena };
    const counts = try each(gpa, io, snap, arch, &games, &sink);
    try testing.expectEqual(Counts{ .from_raw = 1, .from_archive = 1, .archive_files = 2 }, counts);
    try testing.expectEqual(@as(usize, 2), sink.seen.items.len);
    try testing.expectEqualStrings("{\"from\":\"raw\"}", sink.seen.items[0]);
    try testing.expectEqualStrings("{\"metadata\":{\"matchId\":\"B\"},\"from\":\"new\"}", sink.seen.items[1]);
    try testing.expectEqual(@as(u32, 7), games.get("C").?.champions[3]);
    try testing.expect(!games.get("C").?.done);
}
