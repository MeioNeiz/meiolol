//! Pre-game champion mastery (`meiolol-lab mastery-pre SNAP ARCHIVE`; docs/model.md Next
//! steps). A snapshot's mastery table keeps each player's latest fetch, usually after
//! their games; the raw archive (lab/archive.zig) keeps every fetch, hashed with the same
//! salt. For each queue 420 participant this takes the player's latest archived fetch
//! with fetched_at (s) strictly before game_start (ms) and writes SNAP/mastery_pre.tsv:
//!   match_id slot fetched_at level points last_play champions total_points
//! level, points, last_play (unix s, up to an hour late): the game's champion in that
//! fetch, 0s when it is absent (never played). champions, total_points: the whole fetch.
//! Participants without such a fetch get no line.
//! SNAP/mastery_pre_pool.tsv, the pool the app would see (lanecard.pool_size most points
//! first), one line per participant of mastery_pre.tsv, in fetch order:
//!   match_id slot champion pool   (pool: champion:points,... most points first)
//!
//! Two passes over the mastery files, each streamed through `zstd -dc`: the first keeps
//! only each participant's best fetched_at so far, the second decodes just the chosen
//! blobs, so memory grows with participants, not with fetches (~1M a day)

const std = @import("std");
const store = @import("store");
const riot_mastery = @import("../riot/mastery.zig");
const archive = @import("archive.zig");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.mastery_pre);

pub const file_name = "mastery_pre.tsv";
pub const pool_file_name = "mastery_pre_pool.tsv";
pub const pool_size = 15;
const pool_header = "match_id\tslot\tchampion\tpool\n";
const header = "match_id\tslot\tfetched_at\tlevel\tpoints\tlast_play\tchampions\ttotal_points\n";
const ranked_solo = 420;
const no_fetch = std.math.minInt(i64);

const Participant = struct {
    match: u32,
    slot: u8,
    champion: u32,
    start_ms: i64,
    /// Latest fetched_at before start_ms seen so far, and the file holding it
    best: i64 = no_fetch,
    best_file: u32 = 0,
    filled: bool = false,
    level: u32 = 0,
    points: u32 = 0,
    last_play: i64 = 0,
    champions: u32 = 0,
    total_points: u64 = 0,
};

const Snapshot = struct {
    match_ids: std.ArrayList([]const u8) = .empty,
    parts: std.ArrayList(Participant) = .empty,
    players: std.StringHashMapUnmanaged(u32) = .empty,
    /// Player p's participants: by_player[offsets[p]..offsets[p + 1]]
    offsets: []u32 = &.{},
    by_player: []u32 = &.{},
    last_start_ms: i64 = 0,

    fn deinit(s: *Snapshot, gpa: Allocator) void {
        s.match_ids.deinit(gpa);
        s.parts.deinit(gpa);
        s.players.deinit(gpa);
        gpa.free(s.offsets);
        gpa.free(s.by_player);
    }

    fn of(s: *const Snapshot, player: u32) []const u32 {
        return s.by_player[s.offsets[player]..s.offsets[player + 1]];
    }
};

pub const Summary = struct {
    rows: usize,
    pre_game: usize,
    median_gap_h: f64,
    files_read: usize,
    /// Exports that began at or after the last game: nothing in them can be pre-game
    files_skipped: usize,
};

pub fn run(gpa: Allocator, io: Io, snap: []const u8, archive_dir: []const u8) !Summary {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    var s = try load(gpa, arena, snap);
    defer s.deinit(gpa);
    const files = try masteryFiles(arena, io, archive_dir, s.last_start_ms);

    const buf = try gpa.alloc(u8, 1 << 20);
    defer gpa.free(buf);
    for (files.read, 0..) |path, i| {
        var pass: Choose = .{ .s = &s, .file = @intCast(i) };
        try scan(io, path, buf, &pass);
    }
    var line_arena: std.heap.ArenaAllocator = .init(gpa);
    defer line_arena.deinit();
    var blob: std.ArrayList(u8) = .empty;
    defer blob.deinit(gpa);
    const wanted = try arena.alloc(bool, files.read.len);
    @memset(wanted, false);
    for (s.parts.items) |p| if (p.best != no_fetch) {
        wanted[p.best_file] = true;
    };
    const cwd = Io.Dir.cwd();
    const pool_path = try std.fs.path.join(arena, &.{ snap, pool_file_name });
    var pool_file = try cwd.createFileAtomic(io, pool_path, .{ .replace = true });
    defer pool_file.deinit(io);
    {
        var wbuf: [64 * 1024]u8 = undefined;
        var fw = pool_file.file.writer(io, &wbuf);
        try fw.interface.writeAll(pool_header);
        for (files.read, wanted, 0..) |path, want, i| {
            if (!want) continue;
            var pass: Decode = .{
                .gpa = gpa,
                .s = &s,
                .file = @intCast(i),
                .arena = &line_arena,
                .blob = &blob,
                .pool = &fw.interface,
            };
            try scan(io, path, buf, &pass);
        }
        try fw.interface.flush();
    }

    const out_path = try std.fs.path.join(arena, &.{ snap, file_name });
    var gaps: std.ArrayList(f64) = .empty;
    defer gaps.deinit(gpa);
    var out_file = try cwd.createFileAtomic(io, out_path, .{ .replace = true });
    defer out_file.deinit(io);
    {
        var wbuf: [64 * 1024]u8 = undefined;
        var fw = out_file.file.writer(io, &wbuf);
        const w = &fw.interface;
        try w.writeAll(header);
        for (s.parts.items) |p| {
            if (p.best == no_fetch) continue;
            if (!p.filled) return error.ChosenFetchMissing;
            try w.print("{s}\t{d}\t{d}\t", .{ s.match_ids.items[p.match], p.slot, p.best });
            try w.print("{d}\t{d}\t{d}\t", .{ p.level, p.points, p.last_play });
            try w.print("{d}\t{d}\n", .{ p.champions, p.total_points });
            try gaps.append(gpa, @as(f64, @floatFromInt(p.start_ms - p.best * 1000)) / 3_600_000);
        }
        try w.flush();
    }
    try out_file.replace(io);
    try pool_file.replace(io);
    return .{
        .rows = s.parts.items.len,
        .pre_game = gaps.items.len,
        .median_gap_h = median(gaps.items),
        .files_read = files.read.len,
        .files_skipped = files.skipped,
    };
}

fn load(gpa: Allocator, arena: Allocator, snap: []const u8) !Snapshot {
    var s: Snapshot = .{};
    errdefer s.deinit(gpa);
    const path = try std.fs.path.joinZ(arena, &.{ snap, "meiolol.db" });
    const db = try store.sqlite.Db.openReadOnly(path);
    defer db.close();
    var q = try db.prepare(
        \\SELECT p.match_id, p.slot, p.puuid, p.champion_id, m.game_start
        \\FROM participants p JOIN matches m USING (match_id)
        \\WHERE m.queue_id = ? AND p.puuid IS NOT NULL AND p.puuid != ''
        \\ORDER BY p.match_id, p.slot
    );
    defer q.deinit();
    try q.bind(.{ranked_solo});
    var player_of: std.ArrayList(u32) = .empty;
    defer player_of.deinit(gpa);
    while (try q.step()) {
        const r = q.row(struct {
            match_id: []const u8,
            slot: u8,
            puuid: []const u8,
            champion: u32,
            start_ms: i64,
        });
        const ids = s.match_ids.items;
        if (ids.len == 0 or !std.mem.eql(u8, ids[ids.len - 1], r.match_id)) {
            try s.match_ids.append(gpa, try arena.dupe(u8, r.match_id));
        }
        const gop = try s.players.getOrPut(gpa, r.puuid);
        if (!gop.found_existing) {
            gop.key_ptr.* = try arena.dupe(u8, r.puuid);
            gop.value_ptr.* = s.players.count() - 1;
        }
        try player_of.append(gpa, gop.value_ptr.*);
        try s.parts.append(gpa, .{
            .match = @intCast(s.match_ids.items.len - 1),
            .slot = r.slot,
            .champion = r.champion,
            .start_ms = r.start_ms,
        });
        s.last_start_ms = @max(s.last_start_ms, r.start_ms);
    }

    s.offsets = try gpa.alloc(u32, s.players.count() + 1);
    @memset(s.offsets, 0);
    for (player_of.items) |p| s.offsets[p + 1] += 1;
    for (1..s.offsets.len) |i| s.offsets[i] += s.offsets[i - 1];
    s.by_player = try gpa.alloc(u32, player_of.items.len);
    const next = try gpa.dupe(u32, s.offsets[0 .. s.offsets.len - 1]);
    defer gpa.free(next);
    for (player_of.items, 0..) |p, i| {
        s.by_player[next[p]] = @intCast(i);
        next[p] += 1;
    }
    return s;
}

const Files = struct { read: []const []const u8, skipped: usize };

/// Every day's mastery files, sorted, but those of exports that began at or after the
/// last game: an export covers fetched_at in [FROM, TO) and its day is TO's, so FROM
/// in the name is the exact bound where a day directory's name is not
fn masteryFiles(arena: Allocator, io: Io, archive_dir: []const u8, last_start_ms: i64) !Files {
    var out: std.ArrayList([]const u8) = .empty;
    var skipped: usize = 0;
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
            if (e.kind != .file or !std.mem.startsWith(u8, e.name, "mastery-")) continue;
            if (!std.mem.endsWith(u8, e.name, ".tsv.zst")) continue;
            if (exportFrom(e.name)) |from| if (from *| 1000 >= last_start_ms) {
                skipped += 1;
                continue;
            };
            try out.append(arena, try std.fs.path.join(arena, &.{ day_path, e.name }));
        }
    }
    std.mem.sort([]const u8, out.items, {}, lessThan);
    return .{ .read = out.items, .skipped = skipped };
}

fn lessThan(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

/// "mastery-raw-FROM-TO.tsv.zst" -> FROM (unix s)
fn exportFrom(name: []const u8) ?i64 {
    const prefix = "mastery-raw-";
    if (!std.mem.startsWith(u8, name, prefix)) return null;
    const rest = name[prefix.len..];
    const dash = std.mem.findScalar(u8, rest, '-') orelse return null;
    return std.fmt.parseInt(i64, rest[0..dash], 10) catch null;
}

/// Feeds each line of the zstd file at `path` to `pass.line`
fn scan(io: Io, path: []const u8, buf: []u8, pass: anytype) !void {
    var child = try std.process.spawn(io, .{
        .argv = &.{ "zstd", "-dc", "-q", "--long=27", path },
        .stdin = .ignore,
        .stdout = .pipe,
    });
    defer child.kill(io);
    var r = child.stdout.?.readerStreaming(io, buf);
    while (r.interface.takeDelimiter('\n') catch |e| return r.err orelse e) |line| {
        if (line.len > 0) try pass.line(line);
    }
    const term = try child.wait(io);
    if (!term.success()) {
        log.err("zstd -dc {s}: {f}", .{ path, term });
        return error.ZstdFailed;
    }
}

const Line = struct { player: u32, fetched_at: i64, hex: []const u8 };

/// hashed PUUID, platform, fetched_at, champions, blob as hex; null for a player not in
/// the snapshot
fn parse(s: *const Snapshot, text: []const u8) !?Line {
    var f = std.mem.splitScalar(u8, text, '\t');
    const player = s.players.get(f.first()) orelse return null;
    _ = f.next() orelse return error.BadMasteryLine;
    const fetched = f.next() orelse return error.BadMasteryLine;
    _ = f.next() orelse return error.BadMasteryLine;
    return .{
        .player = player,
        .fetched_at = std.fmt.parseInt(i64, fetched, 10) catch return error.BadMasteryLine,
        .hex = f.next() orelse return error.BadMasteryLine,
    };
}

const Choose = struct {
    s: *Snapshot,
    file: u32,

    fn line(c: *Choose, text: []const u8) !void {
        const l = try parse(c.s, text) orelse return;
        for (c.s.of(l.player)) |i| {
            const p = &c.s.parts.items[i];
            if (l.fetched_at *| 1000 < p.start_ms and l.fetched_at > p.best) {
                p.best = l.fetched_at;
                p.best_file = c.file;
            }
        }
    }
};

const Decode = struct {
    gpa: Allocator,
    s: *Snapshot,
    file: u32,
    arena: *std.heap.ArenaAllocator,
    blob: *std.ArrayList(u8),
    pool: *std.Io.Writer,

    fn chosen(c: *const Decode, p: *const Participant, fetched_at: i64) bool {
        return !p.filled and p.best == fetched_at and p.best_file == c.file;
    }

    fn line(c: *Decode, text: []const u8) !void {
        const l = try parse(c.s, text) orelse return;
        const parts = c.s.parts.items;
        const wanted = for (c.s.of(l.player)) |i| {
            if (c.chosen(&parts[i], l.fetched_at)) break true;
        } else false;
        if (!wanted) return;
        try c.blob.resize(c.gpa, l.hex.len / 2);
        _ = std.fmt.hexToBytes(c.blob.items, l.hex) catch return error.BadMasteryLine;
        _ = c.arena.reset(.retain_capacity);
        const entries = try riot_mastery.decode(c.arena.allocator(), c.blob.items, l.fetched_at);
        var total: u64 = 0;
        for (entries) |e| total += e.points;
        std.mem.sort(riot_mastery.Entry, entries, {}, morePoints);
        for (c.s.of(l.player)) |i| {
            const p = &parts[i];
            if (!c.chosen(p, l.fetched_at)) continue;
            try c.pool.print("{s}\t{d}\t{d}\t", .{ c.s.match_ids.items[p.match], p.slot, p.champion });
            for (entries[0..@min(entries.len, pool_size)], 0..) |e, k| {
                try c.pool.print("{s}{d}:{d}", .{ if (k == 0) "" else ",", e.champion, e.points });
            }
            try c.pool.writeAll("\n");
            p.filled = true;
            p.champions = @intCast(entries.len);
            p.total_points = total;
            for (entries) |e| if (e.champion == p.champion) {
                p.level = e.level;
                p.points = e.points;
                p.last_play = e.last_play;
            };
        }
    }
};

fn morePoints(_: void, a: riot_mastery.Entry, b: riot_mastery.Entry) bool {
    return a.points > b.points;
}

fn median(xs: []f64) f64 {
    if (xs.len == 0) return std.math.nan(f64);
    std.mem.sort(f64, xs, {}, std.sort.asc(f64));
    const mid = xs.len / 2;
    return if (xs.len % 2 == 1) xs[mid] else (xs[mid - 1] + xs[mid]) / 2;
}

const testing = std.testing;

test "export start from a mastery file name" {
    try testing.expectEqual(1791000000, exportFrom("mastery-raw-1791000000-1791003600.tsv.zst"));
    try testing.expectEqual(null, exportFrom("mastery-x.tsv.zst"));
}

test "latest fetch strictly before game start, champion entry decoded" {
    const gpa = testing.allocator;
    const io = testing.io;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const version = std.process.run(gpa, io, .{ .argv = &.{ "zstd", "--version" } }) catch
        return error.SkipZigTest;
    gpa.free(version.stdout);
    gpa.free(version.stderr);
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try arena.print(".zig-cache/tmp/{s}", .{&tmp.sub_path});
    const snap = try std.fs.path.join(arena, &.{ base, "snap" });
    const archive_dir = try std.fs.path.join(arena, &.{ base, "archive" });
    const cwd = Io.Dir.cwd();
    try cwd.createDirPath(io, snap);
    const salt: @import("anonymise.zig").Salt = @splat(3);
    const hashed = struct {
        fn of(a: Allocator, sl: *const [32]u8, plain: []const u8) ![]const u8 {
            return a.dupe(u8, &@import("anonymise.zig").puuid(sl, plain));
        }
    }.of;

    const t0: i64 = 1_791_000_000;
    const h = 3600;
    const start1 = (t0 + 10 * h) * 1000;
    // 1 ms after a fetch: fetched_at in s still counts as before
    const start2 = (t0 + 11 * h) * 1000 + 1;
    {
        const db = try store.sqlite.Db.open(try std.fs.path.joinZ(arena, &.{ snap, "meiolol.db" }));
        defer db.close();
        try db.exec(
            \\CREATE TABLE matches (match_id TEXT PRIMARY KEY, platform TEXT, queue_id INTEGER,
            \\  game_start INTEGER);
            \\CREATE TABLE participants (match_id TEXT, slot INTEGER, puuid TEXT,
            \\  champion_id INTEGER, PRIMARY KEY (match_id, slot));
        );
        for ([_]struct { []const u8, i64, i64 }{
            .{ "EUW1_1", ranked_solo, start1 },
            .{ "EUW1_2", ranked_solo, start2 },
            .{ "EUW1_3", 450, start2 },
        }) |m| try db.run("INSERT INTO matches VALUES (?, 'EUW1', ?, ?)", .{ m[0], m[1], m[2] });
        for ([_]struct { []const u8, i64, ?[]const u8, i64 }{
            .{ "EUW1_1", 0, try hashed(arena, &salt, "alice"), 38 },
            // not in bob's fetch
            .{ "EUW1_1", 1, try hashed(arena, &salt, "bob"), 999 },
            // fetched only at and after game start
            .{ "EUW1_1", 2, try hashed(arena, &salt, "carol"), 1 },
            .{ "EUW1_1", 3, null, 1 },
            // never fetched
            .{ "EUW1_1", 4, try hashed(arena, &salt, "dave"), 1 },
            .{ "EUW1_2", 0, try hashed(arena, &salt, "alice"), 1 },
            .{ "EUW1_3", 0, try hashed(arena, &salt, "alice"), 1 },
        }) |p| {
            try db.run("INSERT INTO participants VALUES (?, ?, ?, ?)", .{ p[0], p[1], p[2], p[3] });
        }
    }

    // Three hourly exports through archive.zig; the last begins after the last game
    const Fetch = struct { []const u8, i64, []const riot_mastery.Entry };
    const alice = struct {
        fn at(t: i64, points: u32) [2]riot_mastery.Entry {
            return .{
                .{ .champion = 1, .level = 2, .points = 1000, .last_play = t - 5 * h },
                .{ .champion = 38, .level = points / 40, .points = points, .last_play = t - 3 * h },
            };
        }
    }.at;
    const exports = [_]struct { i64, i64, []const Fetch }{
        .{ t0, t0 + 9 * h + h / 2, &.{
            .{ "alice", t0 + 8 * h, &alice(t0 + 8 * h, 100) },
            .{ "alice", t0 + 9 * h, &alice(t0 + 9 * h, 200) },
            .{ "bob", t0 + 5 * h, &.{
                .{ .champion = 1, .level = 1, .points = 10, .last_play = t0 },
                .{ .champion = 2, .level = 1, .points = 20, .last_play = t0 },
            } },
        } },
        .{ t0 + 9 * h + h / 2, t0 + 13 * h, &.{
            .{ "alice", t0 + 10 * h, &alice(t0 + 10 * h, 300) },
            .{ "alice", t0 + 11 * h, &alice(t0 + 11 * h, 400) },
            .{ "carol", t0 + 10 * h, &.{} },
            .{ "carol", t0 + 12 * h, &.{} },
        } },
        .{ t0 + 13 * h, t0 + 14 * h, &.{.{ "alice", t0 + 13 * h, &alice(t0 + 13 * h, 500) }} },
    };
    for (exports) |e| {
        const path = try arena.print("{s}/raw-{d}-{d}.db", .{ base, e[0], e[1] });
        const db = try store.sqlite.Db.open(try arena.dupeSentinel(u8, path, 0));
        defer db.close();
        try db.exec(
            \\CREATE TABLE raw_docs (key TEXT, fetched_at INTEGER, body BLOB);
            \\CREATE TABLE timeline_docs (match_id TEXT, fetched_at INTEGER, body BLOB);
            \\CREATE TABLE mastery (puuid TEXT, platform TEXT, fetched_at INTEGER,
            \\  champions INTEGER, data BLOB);
        );
        for (e[2]) |f| {
            const blob = try riot_mastery.encode(arena, f[2], f[1]);
            try db.run("INSERT INTO mastery VALUES (?, 'EUW1', ?, ?, ?)", .{
                f[0], f[1], f[2].len, store.Blob{ .bytes = blob },
            });
        }
        _ = try archive.run(gpa, io, path, archive_dir, &salt, null);
    }

    const sum = try run(gpa, io, snap, archive_dir);
    try testing.expectEqual(5, sum.rows);
    try testing.expectEqual(3, sum.pre_game);
    try testing.expectApproxEqAbs(1.0, sum.median_gap_h, 1e-9);
    try testing.expectEqual(2, sum.files_read);
    try testing.expectEqual(1, sum.files_skipped);

    const out_path = try std.fs.path.join(arena, &.{ snap, file_name });
    const out = try cwd.readFileAlloc(io, out_path, arena, .limited(1 << 20));
    try testing.expectEqualStrings(try arena.print(header ++
        "EUW1_1\t0\t{d}\t5\t200\t{d}\t2\t1200\n" ++
        "EUW1_1\t1\t{d}\t0\t0\t0\t2\t30\n" ++
        "EUW1_2\t0\t{d}\t2\t1000\t{d}\t2\t1400\n", .{
        t0 + 9 * h, t0 + 6 * h, t0 + 5 * h, t0 + 11 * h, t0 + 6 * h,
    }), out);

    const pool = try cwd.readFileAlloc(io, try std.fs.path.join(arena, &.{ snap, pool_file_name }), arena, .limited(1 << 20));
    try testing.expectEqualStrings(pool_header ++
        "EUW1_1\t1\t999\t2:20,1:10\n" ++
        "EUW1_1\t0\t38\t1:1000,38:200\n" ++
        "EUW1_2\t0\t1\t1:1000,38:400\n", pool);
}
