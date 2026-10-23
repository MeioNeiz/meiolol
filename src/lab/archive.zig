//! Raw archive, gpu-box side (`meiolol-lab archive EXPORT ARCHIVE [SALT] [FORGOTTEN]`;
//! docs/data-safety.md "Raw archive"). Takes one export from the box (src/archive.zig:
//! raw summaries, raw timelines and mastery as stored, real ids) and writes it
//! pseudonymised with the snapshot salt, so archive and snapshot ids match:
//!   ARCHIVE/YYYY-MM-DD/summaries-NAME.jsonl.zst   one match-v5 summary per line
//!   ARCHIVE/YYYY-MM-DD/timelines-NAME.jsonl.zst   one timeline per line
//!   ARCHIVE/YYYY-MM-DD/mastery-NAME.tsv.zst       hashed PUUID, platform, fetched_at,
//!                                                 champions, compact blob (hex)
//!   ARCHIVE/index.tsv                             one line per export archived
//! (day = UTC day the export ends). Documents of forgotten players (FORGOTTEN: plain
//! PUUIDs, one per line, the box's `forget --export`) are left out, and so are documents
//! that are not a match (an empty body the crawler kept, 15 Oct), counted in `unreadable`
//! so one cannot hold up every export after it. zstd on PATH
//! compresses (-15 --long: a day is ~100 GB of JSON; -19 is 9x slower for 15% smaller)
//! and tests each file. The caller acks the export on the box only after this exits 0
//! (deploy/archive-pull.sh).
//!
//! Erasure and age (privacy policy, as the crawler does for its own rows):
//! - `archive-forget`: documents and mastery lines naming a forgotten player go
//! - `archive-age`: days older than 24 months lose every hashed PUUID and their mastery
//!   files, so archived games no longer link a player across games

const std = @import("std");
const store = @import("store");
const anonymise = @import("anonymise.zig");
const Io = std.Io;
const log = std.log.scoped(.archive);

const Forgotten = std.StringHashMapUnmanaged(void);

pub const Counts = struct {
    summaries: usize = 0,
    timelines: usize = 0,
    mastery: usize = 0,
    forgotten: usize = 0,
    unreadable: usize = 0,
};

pub fn run(
    gpa: std.mem.Allocator,
    io: Io,
    export_path: []const u8,
    archive_dir: []const u8,
    salt: *const anonymise.Salt,
    forgotten_path: ?[]const u8,
) !Counts {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const cwd = Io.Dir.cwd();

    var forgotten: Forgotten = .empty;
    if (forgotten_path) |p| {
        const text = try cwd.readFileAlloc(io, p, arena, .limited(1 << 30));
        var lines = std.mem.tokenizeAny(u8, text, "\r\n");
        while (lines.next()) |line| {
            const puuid = std.mem.trim(u8, line, " \t");
            if (puuid.len > 0) try forgotten.put(arena, puuid, {});
        }
    }

    const name = std.fs.path.stem(std.fs.path.basename(export_path));
    const day = try exportDay(arena, name);
    const day_dir = try std.fs.path.join(arena, &.{ archive_dir, day });
    try cwd.createDirPath(io, day_dir);

    // A failed run must not leave its uncompressed JSON behind: the pull retries every
    // hour, and the 15 Oct export's was 43 GB
    var written: std.ArrayList([]const u8) = .empty;
    errdefer for (written.items) |p| cwd.deleteFile(io, p) catch {};
    var counts: Counts = .{};
    {
        var outs: [3]Out = undefined;
        var opened: usize = 0;
        defer for (outs[0..opened]) |*o| o.file.close(io);
        const files = [_][2][]const u8{ .{ "summaries", "jsonl" }, .{ "timelines", "jsonl" }, .{ "mastery", "tsv" } };
        for (files, &outs) |f, *o| {
            const path = try arena.print("{s}/{s}-{s}.{s}", .{ day_dir, f[0], name, f[1] });
            try written.append(arena, path);
            o.file = try cwd.createFile(io, path, .{});
            opened += 1;
            o.fw = o.file.writer(io, &o.buf);
        }
        const sink: Sink = .{ .gpa = gpa, .salt = salt, .forgotten = &forgotten, .counts = &counts };
        if (try isPack(io, export_path)) {
            try readPack(gpa, io, export_path, sink, &outs);
        } else {
            const db = try store.sqlite.Db.openReadOnly(try arena.dupeSentinel(u8, export_path, 0));
            defer db.close();
            const kinds = [_]struct { DocKind, []const u8 }{
                .{ .summary, "SELECT body FROM raw_docs ORDER BY fetched_at, key" },
                .{ .timeline, "SELECT body FROM timeline_docs ORDER BY fetched_at, match_id" },
            };
            for (kinds, outs[0..2]) |k, *o| {
                var q = try db.prepare(k[1]);
                defer q.deinit();
                try q.bind(.{});
                while (try q.step()) try sink.doc(&o.fw.interface, k[0], .stored, q.bytes(0));
            }
            var q = try db.prepare("SELECT puuid, platform, fetched_at, champions, data FROM mastery ORDER BY fetched_at, puuid");
            defer q.deinit();
            try q.bind(.{});
            while (try q.step()) try sink.mastery(&outs[2].fw.interface, q.bytes(0), q.bytes(1), q.int(2), q.int(3), q.bytes(4));
        }
        for (&outs) |*o| try o.fw.interface.flush();
    }

    for (written.items) |path| {
        try zstd(gpa, io, &.{ "zstd", "-15", "--long=27", "-T0", "-q", "-f", "--rm", path });
        try zstd(gpa, io, &.{ "zstd", "-t", "-q", "--long=27", try arena.print("{s}.zst", .{path}) });
    }

    const index_path = try std.fs.path.join(arena, &.{ archive_dir, "index.tsv" });
    var index = try cwd.createFile(io, index_path, .{ .truncate = false });
    defer index.close(io);
    var ibuf: [512]u8 = undefined;
    var iw = index.writer(io, &ibuf);
    const len = try index.length(io);
    try iw.seekTo(len);
    if (len == 0) try iw.interface.writeAll("export\tday\tsummaries\ttimelines\tmastery\tforgotten_left_out\n");
    try iw.interface.print("{s}\t{s}\t{d}\t{d}\t{d}\t{d}\n", .{
        name, day, counts.summaries, counts.timelines, counts.mastery, counts.forgotten,
    });
    try iw.interface.flush();
    return counts;
}

const Out = struct { file: Io.File, fw: Io.File.Writer, buf: [64 * 1024]u8 };
const DocKind = enum { summary, timeline };

/// Where each export row goes: left out (forgotten, unreadable), or pseudonymised to its
/// file, counted
const Sink = struct {
    gpa: std.mem.Allocator,
    salt: *const anonymise.Salt,
    forgotten: *const Forgotten,
    counts: *Counts,

    fn doc(s: Sink, w: *Io.Writer, kind: DocKind, enc: store.rawpack.Encoding, body: []const u8) !void {
        const unpacked: ?[]u8 = switch (enc) {
            .plain => null,
            .stored => store.raw.decompress(s.gpa, body) catch |err| switch (err) {
                error.OutOfMemory => return err,
                else => {
                    s.counts.unreadable += 1;
                    return;
                },
            },
        };
        defer if (unpacked) |u| s.gpa.free(u);
        const json = unpacked orelse body;
        if (mentionsForgotten(json, s.forgotten)) {
            s.counts.forgotten += 1;
            return;
        }
        const anon = anonymise.rewriteMatch(s.gpa, s.salt, json) catch |err| switch (err) {
            error.OutOfMemory => return err,
            else => {
                s.counts.unreadable += 1;
                return;
            },
        };
        defer s.gpa.free(anon);
        try w.writeAll(anon);
        try w.writeByte('\n');
        switch (kind) {
            .summary => s.counts.summaries += 1,
            .timeline => s.counts.timelines += 1,
        }
    }

    fn mastery(s: Sink, w: *Io.Writer, puuid: []const u8, platform: []const u8, fetched_at: i64, champions: i64, data: []const u8) !void {
        if (s.forgotten.contains(puuid)) {
            s.counts.forgotten += 1;
            return;
        }
        const hashed = anonymise.puuid(s.salt, puuid);
        try w.print("{s}\t{s}\t{d}\t{d}\t{x}\n", .{ &hashed, platform, fetched_at, champions, data });
        s.counts.mastery += 1;
    }
};

/// The box's packed form (src/store/rawpack.zig through zstd) rather than SQLite
fn isPack(io: Io, path: []const u8) !bool {
    const f = try Io.Dir.cwd().openFile(io, path, .{});
    defer f.close(io);
    var head: [4]u8 = undefined;
    var buf: [16]u8 = undefined;
    var r = f.reader(io, &buf);
    r.interface.readSliceAll(&head) catch return false;
    return std.mem.eql(u8, &head, "\x28\xb5\x2f\xfd");
}

fn readPack(gpa: std.mem.Allocator, io: Io, path: []const u8, sink: Sink, outs: *[3]Out) !void {
    var child = try std.process.spawn(io, .{
        .argv = &.{ "zstd", "-dc", "-q", path },
        .stdout = .pipe,
    });
    var ok = false;
    defer if (!ok) child.kill(io);
    var rbuf: [256 * 1024]u8 = undefined;
    var fr = child.stdout.?.readerStreaming(io, &rbuf);
    var r = try store.rawpack.Reader.init(gpa, &fr.interface);
    defer r.deinit();
    while (try r.next()) |rec| switch (rec) {
        .summary => |d| try sink.doc(&outs[0].fw.interface, .summary, d.encoding, d.body),
        .timeline => |d| try sink.doc(&outs[1].fw.interface, .timeline, d.encoding, d.body),
        .mastery => |m| try sink.mastery(&outs[2].fw.interface, m.puuid, m.platform orelse "", m.fetched_at, m.champions, m.data),
    };
    ok = true;
    if (!(try child.wait(io)).success()) return error.ZstdFailed;
}

/// "raw-FROM-TO" -> the UTC day of TO, "YYYY-MM-DD"
fn exportDay(arena: std.mem.Allocator, name: []const u8) ![]const u8 {
    const dash = std.mem.findScalarLast(u8, name, '-') orelse return error.BadExportName;
    const to = std.fmt.parseInt(i64, name[dash + 1 ..], 10) catch return error.BadExportName;
    const days: std.time.epoch.EpochDay = .{ .day = @intCast(@divFloor(to, std.time.s_per_day)) };
    const yd = days.calculateYearDay();
    const md = yd.calculateMonthDay();
    return arena.print("{d:0>4}-{d:0>2}-{d:0>2}", .{ yd.year, md.month.numeric(), md.day_index + 1 });
}

/// Whether metadata.participants (the PUUID list both summaries and timelines open
/// with) holds a forgotten PUUID
fn mentionsForgotten(json: []const u8, forgotten: *const Forgotten) bool {
    if (forgotten.count() == 0) return false;
    const key = "\"participants\":[";
    var i = (std.mem.find(u8, json, key) orelse return false) + key.len;
    while (i < json.len and json[i] == '"') {
        const end = std.mem.findScalarPos(u8, json, i + 1, '"') orelse return false;
        if (forgotten.contains(json[i + 1 .. end])) return true;
        i = end + 1;
        if (i < json.len and json[i] == ',') i += 1;
    }
    return false;
}

/// Drops every summary, timeline and mastery line that names one of `plain` (PUUIDs as
/// the box has them) from the whole archive; files naming none stay untouched. Returns
/// the lines dropped
pub fn forget(gpa: std.mem.Allocator, io: Io, archive_dir: []const u8, salt: *const anonymise.Salt, plain: []const []const u8) !usize {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var hashed: Forgotten = .empty;
    for (plain) |p| try hashed.put(arena, try arena.dupe(u8, &anonymise.puuid(salt, p)), {});
    if (hashed.count() == 0) return 0;
    var dropped: usize = 0;
    for (try archiveFiles(arena, io, archive_dir, null)) |path| {
        dropped += try rewrite(gpa, io, path, .{ .forget = &hashed });
    }
    return dropped;
}

/// Days whose name is older than `max_days` before `today` (unix day) lose every hashed
/// PUUID in their summaries and timelines, and their mastery files; an `aged` file marks
/// a day done. Returns the days aged
pub fn age(gpa: std.mem.Allocator, io: Io, archive_dir: []const u8, today: i64, max_days: u32) !usize {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const cwd = Io.Dir.cwd();
    var aged: usize = 0;
    for (try dayDirs(arena, io, archive_dir)) |d| {
        if (today - d.day <= max_days) continue;
        const marker = try std.fs.path.join(arena, &.{ archive_dir, d.name, "aged" });
        if (cwd.access(io, marker, .{})) |_| continue else |_| {}
        for (try archiveFiles(arena, io, archive_dir, d.name)) |path| {
            if (std.mem.find(u8, std.fs.path.basename(path), "mastery-") == 0) {
                try cwd.deleteFile(io, path);
            } else _ = try rewrite(gpa, io, path, .blank);
        }
        try cwd.writeFile(io, .{ .sub_path = marker, .data = "" });
        aged += 1;
    }
    return aged;
}

const Day = struct { name: []const u8, day: i64 };

fn dayDirs(arena: std.mem.Allocator, io: Io, archive_dir: []const u8) ![]Day {
    var out: std.ArrayList(Day) = .empty;
    var dir = try Io.Dir.cwd().openDir(io, archive_dir, .{ .iterate = true });
    defer dir.close(io);
    var it = dir.iterate();
    while (try it.next(io)) |e| {
        if (e.kind != .directory) continue;
        const day = parseDay(e.name) orelse continue;
        try out.append(arena, .{ .name = try arena.dupe(u8, e.name), .day = day });
    }
    return out.items;
}

/// Every .zst file in the archive's day directories (only `only_day` when given)
fn archiveFiles(arena: std.mem.Allocator, io: Io, archive_dir: []const u8, only_day: ?[]const u8) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    for (try dayDirs(arena, io, archive_dir)) |d| {
        if (only_day) |o| if (!std.mem.eql(u8, o, d.name)) continue;
        const day_path = try std.fs.path.join(arena, &.{ archive_dir, d.name });
        var dir = try Io.Dir.cwd().openDir(io, day_path, .{ .iterate = true });
        defer dir.close(io);
        var it = dir.iterate();
        while (try it.next(io)) |e| {
            if (e.kind != .file or !std.mem.endsWith(u8, e.name, ".zst")) continue;
            try out.append(arena, try std.fs.path.join(arena, &.{ day_path, e.name }));
        }
    }
    return out.items;
}

/// "YYYY-MM-DD" -> unix day
pub fn parseDay(name: []const u8) ?i64 {
    if (name.len != 10 or name[4] != '-' or name[7] != '-') return null;
    const y = std.fmt.parseInt(u16, name[0..4], 10) catch return null;
    const m = std.fmt.parseInt(u4, name[5..7], 10) catch return null;
    const d = std.fmt.parseInt(u5, name[8..10], 10) catch return null;
    if (m < 1 or m > 12 or d < 1 or d > 31) return null;
    var days: i64 = 0;
    var year: u16 = 1970;
    while (year < y) : (year += 1) days += std.time.epoch.getDaysInYear(year);
    var month: u4 = 1;
    while (month < m) : (month += 1) days += std.time.epoch.getDaysInMonth(y, @fromBackingInt(@intCast(month)));
    return days + d - 1;
}

const Mode = union(enum) {
    /// drop lines naming one of these hashed PUUIDs
    forget: *const Forgotten,
    /// blank every hashed PUUID
    blank,
};

/// Decompresses `path`, applies `mode` line by line, and replaces the file only when a
/// line changed (compressed, tested, then renamed over it). Returns the lines changed
fn rewrite(gpa: std.mem.Allocator, io: Io, path: []const u8, mode: Mode) !usize {
    const cwd = Io.Dir.cwd();
    const plain = try gpa.print("{s}.plain", .{path});
    defer gpa.free(plain);
    const edited = try gpa.print("{s}.edited", .{path});
    defer gpa.free(edited);
    const packed_path = try gpa.print("{s}.edited.zst", .{path});
    defer gpa.free(packed_path);
    defer for ([_][]const u8{ plain, edited, packed_path }) |p| cwd.deleteFile(io, p) catch {};
    try zstd(gpa, io, &.{ "zstd", "-d", "-q", "-f", "--long=27", path, "-o", plain });

    const tsv = std.mem.endsWith(u8, path, ".tsv.zst");
    var changed: usize = 0;
    {
        var in = try cwd.openFile(io, plain, .{});
        defer in.close(io);
        // A timeline line is ~0.7 MB
        const rbuf = try gpa.alloc(u8, 16 << 20);
        defer gpa.free(rbuf);
        var fr = in.reader(io, rbuf);
        var out = try cwd.createFile(io, edited, .{});
        defer out.close(io);
        var wbuf: [64 * 1024]u8 = undefined;
        var fw = out.writer(io, &wbuf);
        while (try fr.interface.takeDelimiter('\n')) |line| {
            switch (mode) {
                .forget => |set| {
                    const drop = if (tsv)
                        set.contains(line[0 .. std.mem.findScalar(u8, line, '\t') orelse line.len])
                    else
                        mentionsForgotten(line, set);
                    if (drop) {
                        changed += 1;
                        continue;
                    }
                    try fw.interface.writeAll(line);
                },
                .blank => {
                    const blanked = try blankPuuids(gpa, line);
                    defer gpa.free(blanked);
                    if (!std.mem.eql(u8, blanked, line)) changed += 1;
                    try fw.interface.writeAll(blanked);
                },
            }
            try fw.interface.writeByte('\n');
        }
        try fw.interface.flush();
    }
    if (changed == 0) return 0;
    try zstd(gpa, io, &.{ "zstd", "-15", "--long=27", "-T0", "-q", "-f", edited, "-o", packed_path });
    try zstd(gpa, io, &.{ "zstd", "-t", "-q", "--long=27", packed_path });
    try cwd.rename(packed_path, cwd, path, io);
    return changed;
}

/// Every PUUID of metadata.participants, wherever it occurs in the document, as ""
fn blankPuuids(gpa: std.mem.Allocator, json: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(gpa);
    try out.appendSlice(gpa, json);
    const key = "\"participants\":[";
    const list = std.mem.find(u8, json, key) orelse return out.toOwnedSlice(gpa);
    var ids: std.ArrayList([]const u8) = .empty;
    defer ids.deinit(gpa);
    var i = list + key.len;
    while (i < json.len and json[i] == '"') {
        const end = std.mem.findScalarPos(u8, json, i + 1, '"') orelse break;
        if (end > i + 1) try ids.append(gpa, json[i + 1 .. end]);
        i = end + 1;
        if (i < json.len and json[i] == ',') i += 1;
    }
    for (ids.items) |id| {
        var from: usize = 0;
        while (std.mem.findPos(u8, out.items, from, id)) |at| {
            try out.replaceRange(gpa, at, id.len, "");
            from = at;
        }
    }
    return out.toOwnedSlice(gpa);
}

fn zstd(gpa: std.mem.Allocator, io: Io, argv: []const []const u8) !void {
    const r = try std.process.run(gpa, io, .{ .argv = argv });
    defer gpa.free(r.stdout);
    defer gpa.free(r.stderr);
    if (!r.term.success()) {
        log.err("{s} failed: {s}", .{ argv[0], r.stderr });
        return error.ZstdFailed;
    }
}

const testing = std.testing;

test "export day and forgotten participants" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    // 2026-10-12 21:00:00 UTC
    try testing.expectEqualStrings("2026-10-12", try exportDay(arena, "raw-0-1791838800"));
    try testing.expectError(error.BadExportName, exportDay(arena, "raw"));

    var forgotten: Forgotten = .empty;
    try forgotten.put(arena, "BBB", {});
    const json =
        \\{"metadata":{"dataVersion":"2","matchId":"EUW1_1","participants":["AAA","BBB"]},"info":{}}
    ;
    try testing.expect(mentionsForgotten(json, &forgotten));
    try testing.expect(!mentionsForgotten(json[0..50], &forgotten));
    _ = forgotten.remove("BBB");
    try forgotten.put(arena, "CCC", {});
    try testing.expect(!mentionsForgotten(json, &forgotten));
}

test "a real timeline pseudonymises like a summary" {
    const gpa = testing.allocator;
    const json = try store.raw.decompress(gpa, @embedFile("../riot/testdata/timeline.json.gz"));
    defer gpa.free(json);
    const salt: anonymise.Salt = @splat(7);
    const anon = try anonymise.rewriteMatch(gpa, &salt, json);
    defer gpa.free(anon);
    const Doc = struct {
        metadata: struct { matchId: []const u8, participants: []const []const u8 },
        info: struct { gameId: u64, participants: []const struct { puuid: []const u8 } },
    };
    const before = try std.json.parseFromSlice(Doc, gpa, json, .{ .ignore_unknown_fields = true });
    defer before.deinit();
    const after = try std.json.parseFromSlice(Doc, gpa, anon, .{ .ignore_unknown_fields = true });
    defer after.deinit();
    for (before.value.metadata.participants) |p| {
        try testing.expect(std.mem.find(u8, anon, p) == null);
    }
    const first = anonymise.puuid(&salt, before.value.metadata.participants[0]);
    try testing.expectEqualStrings(&first, after.value.metadata.participants[0]);
    try testing.expectEqualStrings(&first, after.value.info.participants[0].puuid);
    try testing.expect(after.value.info.gameId != before.value.info.gameId);
    var buf: [64]u8 = undefined;
    try testing.expectEqualStrings(
        try anonymise.matchId(&salt, before.value.metadata.matchId, &buf),
        after.value.metadata.matchId,
    );
}

test "an unreadable document is left out, not fatal" {
    const gpa = testing.allocator;
    const io = testing.io;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    zstd(gpa, io, &.{ "zstd", "--version" }) catch return error.SkipZigTest;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try arena.print(".zig-cache/tmp/{s}", .{&tmp.sub_path});
    const path = try arena.print("{s}/raw-0-1791838800.db", .{base});
    {
        const db = try store.sqlite.Db.open(try arena.dupeSentinel(u8, path, 0));
        defer db.close();
        try db.exec(
            \\CREATE TABLE raw_docs (key TEXT, fetched_at INTEGER, body BLOB);
            \\CREATE TABLE timeline_docs (match_id TEXT, fetched_at INTEGER, body BLOB);
            \\CREATE TABLE mastery (puuid TEXT, platform TEXT, fetched_at INTEGER,
            \\  champions INTEGER, data BLOB);
        );
        const empty = try store.raw.compress(arena, "");
        try db.run("INSERT INTO timeline_docs VALUES ('OC1_1', 1, ?), ('EUW1_2', 2, ?)", .{
            store.Blob{ .bytes = empty },
            store.Blob{ .bytes = @embedFile("../riot/testdata/timeline.json.gz") },
        });
    }
    const salt: anonymise.Salt = @splat(7);
    const n = try run(gpa, io, path, try std.fs.path.join(arena, &.{ base, "archive" }), &salt, null);
    try testing.expectEqual(1, n.timelines);
    try testing.expectEqual(1, n.unreadable);
}

test "day names" {
    try testing.expectEqual(0, parseDay("1970-01-01"));
    try testing.expectEqual(@divFloor(1791838800, std.time.s_per_day), parseDay("2026-10-12"));
    try testing.expectEqual(null, parseDay("index.tsv"));
    try testing.expectEqual(null, parseDay("2026-13-01"));
}

test "blanking removes every participant id" {
    const gpa = testing.allocator;
    const out = try blankPuuids(gpa,
        \\{"metadata":{"participants":["aa11","bb22"]},"info":{"participants":[{"puuid":"aa11"},{"puuid":"bb22"}]}}
    );
    defer gpa.free(out);
    try testing.expectEqualStrings(
        \\{"metadata":{"participants":["",""]},"info":{"participants":[{"puuid":""},{"puuid":""}]}}
    , out);
}

test "forget and age rewrite archived files" {
    const gpa = testing.allocator;
    const io = testing.io;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    zstd(gpa, io, &.{ "zstd", "--version" }) catch return error.SkipZigTest;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try arena.print(".zig-cache/tmp/{s}", .{&tmp.sub_path});
    const day = try std.fs.path.join(arena, &.{ base, "2024-01-01" });
    const cwd = Io.Dir.cwd();
    try cwd.createDirPath(io, day);
    const salt: anonymise.Salt = @splat(7);
    const a = anonymise.puuid(&salt, "plain-a");
    const b = anonymise.puuid(&salt, "plain-b");
    const summaries = try std.fs.path.join(arena, &.{ day, "summaries-x.jsonl" });
    try cwd.writeFile(io, .{ .sub_path = summaries, .data = try arena.print(
        "{{\"metadata\":{{\"participants\":[\"{s}\",\"{s}\"]}}}}\n{{\"metadata\":{{\"participants\":[\"{s}\"]}}}}\n",
        .{ &a, &b, &b },
    ) });
    const mastery = try std.fs.path.join(arena, &.{ day, "mastery-x.tsv" });
    try cwd.writeFile(io, .{ .sub_path = mastery, .data = try arena.print("{s}\tEUW1\t1\t0\t00\n{s}\tEUW1\t1\t0\t00\n", .{ &a, &b }) });
    try zstd(gpa, io, &.{ "zstd", "-q", "--rm", summaries });
    try zstd(gpa, io, &.{ "zstd", "-q", "--rm", mastery });

    // Forgetting a: its game and its mastery line go, b's own game stays
    try testing.expectEqual(2, try forget(gpa, io, base, &salt, &.{"plain-a"}));
    try testing.expectEqual(0, try forget(gpa, io, base, &salt, &.{"plain-a"}));
    const plain = try std.fs.path.join(arena, &.{ base, "check.jsonl" });
    try zstd(gpa, io, &.{ "zstd", "-d", "-q", "-f", try arena.print("{s}.zst", .{summaries}), "-o", plain });
    const left = try cwd.readFileAlloc(io, plain, arena, .limited(1 << 20));
    try testing.expectEqual(1, std.mem.count(u8, left, "\n"));
    try testing.expect(std.mem.find(u8, left, &a) == null);

    // Past 24 months: ids blanked, mastery gone, done once
    const today = parseDay("2026-10-12").?;
    try testing.expectEqual(1, try age(gpa, io, base, today, 730));
    try testing.expectEqual(0, try age(gpa, io, base, today, 730));
    try zstd(gpa, io, &.{ "zstd", "-d", "-q", "-f", try arena.print("{s}.zst", .{summaries}), "-o", plain });
    const aged = try cwd.readFileAlloc(io, plain, arena, .limited(1 << 20));
    try testing.expect(std.mem.find(u8, aged, &b) == null);
    try testing.expectError(error.FileNotFound, cwd.access(io, try arena.print("{s}.zst", .{mastery}), .{}));
}

test "a packed export archives as its SQLite form does" {
    const gpa = testing.allocator;
    const io = testing.io;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    zstd(gpa, io, &.{ "zstd", "--version" }) catch return error.SkipZigTest;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try arena.print(".zig-cache/tmp/{s}", .{&tmp.sub_path});
    const name = "raw-0-1791838800.db";
    const db_path = try arena.print("{s}/db/{s}", .{ base, name });
    const pack_path = try arena.print("{s}/pack/{s}", .{ base, name });
    try Io.Dir.cwd().createDirPath(io, try arena.print("{s}/db", .{base}));
    try Io.Dir.cwd().createDirPath(io, try arena.print("{s}/pack", .{base}));
    const timeline = @embedFile("../riot/testdata/timeline.json.gz");
    const summary = "{\"metadata\":{\"matchId\":\"EUW1_2\",\"participants\":[\"p1\"]},\"info\":{\"participants\":[{\"puuid\":\"p1\"}]}}";
    {
        const db = try store.sqlite.Db.open(try arena.dupeSentinel(u8, db_path, 0));
        defer db.close();
        try db.exec(
            \\CREATE TABLE raw_docs (key TEXT, fetched_at INTEGER, body BLOB);
            \\CREATE TABLE timeline_docs (match_id TEXT, fetched_at INTEGER, body BLOB);
            \\CREATE TABLE mastery (puuid TEXT, platform TEXT, fetched_at INTEGER,
            \\  champions INTEGER, data BLOB);
            \\INSERT INTO mastery VALUES ('p1', 'EUW1', 5, 2, x'0a0b'), ('p2', NULL, 4, 0, x'');
        );
        try db.run("INSERT INTO raw_docs VALUES ('EUW1_2', 3, ?), ('EUW1_3', 1, x'00')", .{
            store.Blob{ .bytes = try store.raw.compress(arena, summary) },
        });
        try db.run("INSERT INTO timeline_docs VALUES ('EUW1_2', 2, ?)", .{store.Blob{ .bytes = timeline }});
    }
    {
        var file = try Io.Dir.cwd().createFile(io, try arena.print("{s}.plain", .{pack_path}), .{});
        defer file.close(io);
        var buf: [4096]u8 = undefined;
        var fw = file.writer(io, &buf);
        var w = try store.rawpack.Writer.begin(&fw.interface);
        try w.doc(.summary, .{ .key = "EUW1_3", .fetched_at = 1, .encoding = .stored, .body = "\x00" });
        try w.doc(.summary, .{ .key = "EUW1_2", .fetched_at = 3, .encoding = .plain, .body = summary });
        const tl = try store.raw.decompress(arena, timeline);
        try w.doc(.timeline, .{ .key = "EUW1_2", .fetched_at = 2, .encoding = .plain, .body = tl });
        try w.mastery(.{ .puuid = "p2", .platform = null, .fetched_at = 4, .champions = 0, .data = "" });
        try w.mastery(.{ .puuid = "p1", .platform = "EUW1", .fetched_at = 5, .champions = 2, .data = "\x0a\x0b" });
        try w.end();
        try fw.interface.flush();
    }
    try zstd(gpa, io, &.{ "zstd", "-q", try arena.print("{s}.plain", .{pack_path}), "-o", pack_path });
    const salt: anonymise.Salt = @splat(7);
    const a = try run(gpa, io, db_path, try arena.print("{s}/a", .{base}), &salt, null);
    const b = try run(gpa, io, pack_path, try arena.print("{s}/b", .{base}), &salt, null);
    try testing.expectEqual(a, b);
    try testing.expectEqual(Counts{ .summaries = 1, .timelines = 1, .mastery = 2, .unreadable = 1 }, a);
    for ([_][]const u8{ "summaries", "timelines", "mastery" }) |kind| {
        const ext = if (std.mem.eql(u8, kind, "mastery")) "tsv" else "jsonl";
        var got: [2][]const u8 = undefined;
        for ([_][]const u8{ "a", "b" }, &got) |side, *g| {
            const z = try arena.print("{s}/{s}/2026-10-12/{s}-raw-0-1791838800.{s}.zst", .{ base, side, kind, ext });
            const r = try std.process.run(gpa, io, .{ .argv = &.{ "zstd", "-dc", "-q", "--long=27", z }, .stdout_limit = .unlimited });
            defer gpa.free(r.stderr);
            g.* = try arena.dupe(u8, r.stdout);
            gpa.free(r.stdout);
        }
        try testing.expectEqualStrings(got[0], got[1]);
    }
}
