//! The complete form's copy on the gpu-box (docs/data-safety.md "Complete form copy"):
//! each sealed day file the box serves (deploy/archive-pull.sh) rewritten pseudonymised
//! as the raw archive is (lab/anonymise.zig): match ids and PUUIDs hashed with the
//! snapshot salt, names blanked; a mastery fetch's key and body get the hashed PUUID.
//! Same format and name as the box's (store/dayfile.zig): COPY/YYYY-MM-DD.<kind>.cfd.
//!
//! Left out: documents naming a forgotten PUUID (the box's list), and as unreadable those
//! that do not rewrite (no match id or participants, a mastery key without a PUUID) or
//! still hold a PUUID-long base64url run after it, so no plain PUUID gets here.
//! COPY/index.tsv: one line per file copied.
//!
//! Erasure and age, as the raw archive's (lab/archive.zig):
//! - `complete-forget`: documents naming a forgotten player's hashed PUUID go
//!   (complete_scrub.scrubFile with 16-hex ids; every file is read, no index yet)
//! - `complete-age`: files of days older than 24 months lose every hashed PUUID and
//!   mastery files go; COPY/aged.txt lists the files done

const std = @import("std");
const store = @import("store");
const complete = @import("../riot/complete.zig");
const scrub = @import("../riot/complete_scrub.zig");
const box_archive = @import("../archive.zig");
const tsvlog = @import("../tsvlog.zig");
const lab_archive = @import("archive.zig");
const anonymise = @import("anonymise.zig");
const dayfile = store.dayfile;
const Io = std.Io;
const Allocator = std.mem.Allocator;

const log = std.log.scoped(.complete_copy);

pub const Counts = struct {
    docs: usize = 0,
    written: usize = 0,
    forgotten: usize = 0,
    unreadable: usize = 0,
    bytes_in: u64 = 0,
    bytes_out: u64 = 0,
};

const hashed_len = 16;
const tmp_name = ".copy.tmp";
const zst_tmp_name = ".copy.zst.tmp";
const lock_name = "lock";
const aged_name = "aged.txt";

const Transform = union(enum) {
    pseudonymise: struct { salt: *const anonymise.Salt, forgotten: *const scrub.Matcher },
    blank,
};

const Outcome = union(enum) { doc: dayfile.Doc, forgotten, unreadable };

/// Pseudonymises the sealed day file at `src_path` into COPY under its name, leaving out
/// documents naming a PUUID of `forgotten_path` (one per line; anything else ignored)
pub fn run(gpa: Allocator, io: Io, src_path: []const u8, copy_dir: []const u8, salt: *const anonymise.Salt, forgotten_path: ?[]const u8) !Counts {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const cwd = Io.Dir.cwd();
    const name = std.fs.path.basename(src_path);
    const kind = kindOf(name) orelse return error.NotADayFile;

    var list: std.ArrayList([]const u8) = .empty;
    if (forgotten_path) |p| {
        const text = try cwd.readFileAlloc(io, p, arena, .limited(1 << 30));
        var lines = std.mem.tokenizeAny(u8, text, " \t\r\n");
        while (lines.next()) |puuid| if (scrub.isPuuid(puuid)) try list.append(arena, puuid);
    }
    const m: scrub.Matcher = try .init(arena, list.items);

    try cwd.createDirPath(io, copy_dir);
    var dir = try cwd.openDir(io, copy_dir, .{});
    defer dir.close(io);
    const lock = try dir.createFile(io, lock_name, .{ .lock = .exclusive, .truncate = false });
    defer lock.close(io);
    var counts: Counts = .{};
    try transformFile(gpa, io, src_path, dir, copy_dir, name, kind, .{ .pseudonymise = .{ .salt = salt, .forgotten = &m } }, &counts);
    try tsvlog.appendRaw(io, dir, "index.tsv", "file\tcopied_at\tdocs\twritten\tforgotten_left_out\tunreadable\tbytes_in\tbytes_out\n", try arena.print("{s}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\n", .{
        name,             Io.Clock.real.now(io).toSeconds(), counts.docs,     counts.written,
        counts.forgotten, counts.unreadable,                 counts.bytes_in, counts.bytes_out,
    }));
    return counts;
}

/// Drops every document naming one of `plain` (PUUIDs as the box has them) from the
/// copy's files; files naming none stay untouched. Returns the documents dropped
pub fn forget(gpa: Allocator, io: Io, copy_dir: []const u8, salt: *const anonymise.Salt, plain: []const []const u8) !u64 {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var hashed: std.ArrayList([]const u8) = .empty;
    for (plain) |p| if (scrub.isPuuid(p)) try hashed.append(arena, try arena.dupe(u8, &anonymise.puuid(salt, p)));
    if (hashed.items.len == 0) return 0;
    const m: scrub.Matcher = try .initLen(arena, hashed.items, hashed_len);
    var dir = try Io.Dir.cwd().openDir(io, copy_dir, .{ .iterate = true });
    defer dir.close(io);
    const lock = try dir.createFile(io, lock_name, .{ .lock = .exclusive, .truncate = false });
    defer lock.close(io);
    var dropped: u64 = 0;
    for (try dayFiles(arena, io, dir)) |name| {
        const r = try scrub.scrubFile(gpa, io, dir, copy_dir, name, &m, false);
        gpa.free(r.ids);
        dropped += r.dropped orelse 0;
    }
    return dropped;
}

/// Files of days older than `max_days` before `today` (unix day): summaries and
/// timelines lose every hashed PUUID, mastery files go. Returns the files aged
pub fn age(gpa: Allocator, io: Io, copy_dir: []const u8, today: i64, max_days: u32) !usize {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var dir = try Io.Dir.cwd().openDir(io, copy_dir, .{ .iterate = true });
    defer dir.close(io);
    const lock = try dir.createFile(io, lock_name, .{ .lock = .exclusive, .truncate = false });
    defer lock.close(io);
    const done = dir.readFileAlloc(io, aged_name, arena, .limited(1 << 26)) catch |err| switch (err) {
        error.FileNotFound => "",
        else => return err,
    };
    var aged: usize = 0;
    for (try dayFiles(arena, io, dir)) |name| {
        if (today - scrub.sealedDay(name).? <= max_days) continue;
        var lines = std.mem.tokenizeScalar(u8, done, '\n');
        const seen = while (lines.next()) |l| {
            if (std.mem.eql(u8, l, name)) break true;
        } else false;
        if (seen) continue;
        const kind = kindOf(name).?;
        if (kind == .mastery) {
            try dir.deleteFile(io, name);
        } else {
            var counts: Counts = .{};
            const path = try std.fs.path.join(arena, &.{ copy_dir, name });
            try transformFile(gpa, io, path, dir, copy_dir, name, kind, .blank, &counts);
            try tsvlog.appendRaw(io, dir, aged_name, "", try arena.print("{s}\n", .{name}));
        }
        aged += 1;
    }
    return aged;
}

/// The sealed day files in `dir`, sorted
fn dayFiles(arena: Allocator, io: Io, dir: Io.Dir) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    var it = dir.iterate();
    while (try it.next(io)) |e| {
        if (e.kind != .file or kindOf(e.name) == null) continue;
        try out.append(arena, try arena.dupe(u8, e.name));
    }
    std.mem.sort([]const u8, out.items, {}, lessThan);
    return out.items;
}

fn lessThan(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.order(u8, a, b) == .lt;
}

fn kindOf(name: []const u8) ?complete.Kind {
    if (scrub.sealedDay(name) == null) return null;
    const end = std.mem.indexOfPos(u8, name, 11, ".cfd").?;
    return std.meta.stringToEnum(complete.Kind, name[11..end]);
}

/// Every document of the day file at `src_path` through `tr`, repacked into dir/name
/// (written beside it, fsynced, renamed over)
fn transformFile(gpa: Allocator, io: Io, src_path: []const u8, dir: Io.Dir, dir_path: []const u8, name: []const u8, kind: complete.Kind, tr: Transform, counts: *Counts) !void {
    const src = try Io.Dir.cwd().openFile(io, src_path, .{});
    defer src.close(io);
    var out: ?Io.File = try dir.createFile(io, tmp_name, .{});
    defer if (out) |o| {
        o.close(io);
        dir.deleteFile(io, tmp_name) catch {};
    };
    const zst_tmp = try std.fs.path.join(gpa, &.{ dir_path, zst_tmp_name });
    defer gpa.free(zst_tmp);
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    var frames: dayfile.Frames = .{ .file = src };
    var len: u64 = 0;
    while (try frames.next(gpa, io)) |fr| {
        defer gpa.free(fr.zst);
        defer _ = arena_state.reset(.retain_capacity);
        const arena = arena_state.allocator();
        const docs = try dayfile.decode(gpa, arena, fr);
        var kept: std.ArrayList(dayfile.Doc) = .empty;
        for (docs) |d| switch (try apply(arena, kind, d, tr)) {
            .doc => |o| try kept.append(arena, o),
            .forgotten => counts.forgotten += 1,
            .unreadable => counts.unreadable += 1,
        };
        counts.docs += docs.len;
        counts.written += kept.items.len;
        const bytes = try scrub.packFrames(gpa, arena, io, zst_tmp, kept.items, fr.type == .block, null);
        try out.?.writePositionalAll(io, bytes, len);
        len += bytes.len;
    }
    // A sealed file ends at its last whole frame: anything else is a cut transfer or damage
    if (frames.pos != try src.length(io)) return error.Corrupt;
    counts.bytes_in += frames.pos;
    counts.bytes_out += len;
    try out.?.sync(io);
    try dir.rename(tmp_name, dir, name, io);
    out.?.close(io);
    out = null;
    try box_archive.syncPath(io, dir_path, .directory);
}

fn apply(arena: Allocator, kind: complete.Kind, d: dayfile.Doc, tr: Transform) !Outcome {
    switch (tr) {
        .blank => return .{ .doc = .{ .key = d.key, .t = d.t, .bytes = try lab_archive.blankPuuids(arena, d.bytes) } },
        .pseudonymise => |p| {
            if (p.forgotten.any(d.key) or p.forgotten.any(d.bytes)) return .forgotten;
            const out = pseudonymise(arena, kind, d, p.salt) catch |err| switch (err) {
                error.OutOfMemory => return err,
                else => return .unreadable,
            };
            if (holdsPuuidRun(out.key) or holdsPuuidRun(out.bytes)) return .unreadable;
            return .{ .doc = out };
        },
    }
}

fn pseudonymise(arena: Allocator, kind: complete.Kind, d: dayfile.Doc, salt: *const anonymise.Salt) !dayfile.Doc {
    switch (kind) {
        .summary, .timeline => {
            var buf: [64]u8 = undefined;
            const key = try anonymise.matchId(salt, d.key, &buf);
            return .{ .key = try arena.dupe(u8, key), .t = d.t, .bytes = try anonymise.rewriteMatch(arena, salt, d.bytes) };
        },
        .mastery => {
            // PLATFORM:PUUID (riot/complete.zig's key for a fetch)
            const colon = std.mem.findScalar(u8, d.key, ':') orelse return error.BadKey;
            const puuid = d.key[colon + 1 ..];
            if (!scrub.isPuuid(puuid)) return error.BadKey;
            const hashed = anonymise.puuid(salt, puuid);
            return .{
                .key = try std.mem.concat(arena, u8, &.{ d.key[0 .. colon + 1], &hashed }),
                .t = d.t,
                .bytes = try std.mem.replaceOwned(u8, arena, d.bytes, puuid, &hashed),
            };
        },
    }
}

/// Whether `s` holds a base64url run as long as a PUUID
fn holdsPuuidRun(s: []const u8) bool {
    var len: usize = 0;
    for (s) |c| {
        len = if (std.ascii.isAlphanumeric(c) or c == '-' or c == '_') len + 1 else 0;
        if (len >= 78) return true;
    }
    return false;
}

const testing = std.testing;
const Date = @import("../date.zig").Date;

fn fakePuuid(arena: Allocator, c: u8) ![]const u8 {
    const p = try arena.alloc(u8, 78);
    @memset(p, c);
    p[0] = 'P';
    return p;
}

fn match(arena: Allocator, id: []const u8, p1: []const u8, p2: []const u8) ![]const u8 {
    return arena.print("{{\"metadata\":{{\"matchId\":\"{s}\",\"participants\":[\"{s}\",\"{s}\"]}},\"info\":{{\"gameId\":7,\"participants\":[{{\"puuid\":\"{s}\",\"riotIdGameName\":\"Ann\",\"profileIcon\":12}},{{\"puuid\":\"{s}\",\"riotIdGameName\":\"Bo\",\"profileIcon\":13}}]}}}}", .{ id, p1, p2, p1, p2 });
}

test "a day file copied pseudonymised, then forget and age reach the copy" {
    const gpa = testing.allocator;
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const root = try arena.print(".zig-cache/tmp/{s}", .{&tmp.sub_path});
    const copy = try arena.print("{s}/copy", .{root});
    const salt: anonymise.Salt = @splat(7);

    const a = try fakePuuid(arena, 'a');
    const b = try fakePuuid(arena, 'b');
    const x = try fakePuuid(arena, 'x');
    const D = struct { kind: complete.Kind, key: []const u8, bytes: []const u8 };
    const docs = [_]D{
        .{ .kind = .summary, .key = "EUW1_1", .bytes = try match(arena, "EUW1_1", a, x) },
        .{ .kind = .summary, .key = "EUW1_2", .bytes = try match(arena, "EUW1_2", x, b) },
        .{ .kind = .summary, .key = "EUW1_3", .bytes = try match(arena, "EUW1_3", x, x) },
        // A PUUID outside metadata.participants: unreadable, never copied
        .{ .kind = .summary, .key = "EUW1_4", .bytes = try arena.print("{{\"metadata\":{{\"matchId\":\"EUW1_4\",\"participants\":[\"{s}\"]}},\"x\":\"{s}\"}}", .{ x, a }) },
        // Not compact: a raw frame
        .{ .kind = .summary, .key = "EUW1_5", .bytes = try arena.print(" {s}", .{try match(arena, "EUW1_5", x, x)}) },
        .{ .kind = .timeline, .key = "EUW1_1", .bytes = try match(arena, "EUW1_1", a, x) },
        .{ .kind = .mastery, .key = try arena.print("EUW1:{s}", .{a}), .bytes = try arena.print("[{{\"puuid\":\"{s}\",\"championId\":1}}]", .{a}) },
        .{ .kind = .mastery, .key = try arena.print("EUW1:{s}", .{b}), .bytes = try arena.print("[{{\"puuid\":\"{s}\",\"championId\":2}}]", .{b}) },
    };
    const saved = complete.test_day;
    defer complete.test_day = saved;
    complete.test_day = 20_000;
    var p: complete.Packer = try .init(gpa, io, root);
    p.clock = complete.testClock;
    p.block_docs = 3;
    try p.start();
    for (docs, 0..) |d, i| p.push(.{ .kind = d.kind, .key = d.key, .t = @intCast(i), .gz = try store.raw.compress(arena, d.bytes) });
    try complete.settle(&p);
    complete.test_day += 1;
    p.push(.{ .kind = .summary, .key = "EUW1_9", .t = 9, .gz = try store.raw.compress(arena, try match(arena, "EUW1_9", x, x)) });
    try complete.settle(&p);
    p.close();

    const forgotten = try arena.print("{s}/forgotten.txt", .{root});
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = forgotten, .data = try arena.print("{s}\nnot-a-puuid\n", .{b}) });
    const day = Date.fromDay(20_000);
    var total: Counts = .{};
    for (std.enums.values(complete.Kind)) |k| {
        const n = try run(gpa, io, try arena.print("{s}/complete/{f}.{t}.cfd", .{ root, day, k }), copy, &salt, forgotten);
        total.docs += n.docs;
        total.written += n.written;
        total.forgotten += n.forgotten;
        total.unreadable += n.unreadable;
    }
    try testing.expectEqual(docs.len, total.docs);
    try testing.expectEqual(2, total.forgotten);
    try testing.expectEqual(1, total.unreadable);
    try testing.expectEqual(5, total.written);

    const read = struct {
        fn all(al: Allocator, dir: []const u8, k: complete.Kind) ![]dayfile.Doc {
            return dayfile.readAll(testing.allocator, al, testing.io, try al.print("{s}/{f}.{t}.cfd", .{ dir, Date.fromDay(20_000), k }));
        }
    }.all;
    const ha = anonymise.puuid(&salt, a);
    const hx = anonymise.puuid(&salt, x);
    var buf: [64]u8 = undefined;
    const summaries = try read(arena, copy, .summary);
    try testing.expectEqual(3, summaries.len);
    for (summaries, [_][]const u8{ docs[0].bytes, docs[2].bytes, docs[4].bytes }, [_][]const u8{ "EUW1_1", "EUW1_3", "EUW1_5" }) |got, json, id| {
        try testing.expectEqualStrings(try anonymise.matchId(&salt, id, &buf), got.key);
        try testing.expectEqualStrings(try anonymise.rewriteMatch(arena, &salt, json), got.bytes);
    }
    const mastery = try read(arena, copy, .mastery);
    try testing.expectEqual(1, mastery.len);
    try testing.expectEqualStrings(try arena.print("EUW1:{s}", .{&ha}), mastery[0].key);
    try testing.expectEqualStrings(try arena.print("[{{\"puuid\":\"{s}\",\"championId\":1}}]", .{&ha}), mastery[0].bytes);
    for (std.enums.values(complete.Kind)) |k| for (try read(arena, copy, k)) |d| {
        for ([_][]const u8{ a, b, x }) |plain| try testing.expect(std.mem.find(u8, d.bytes, plain) == null);
    };

    // Forget a: its game, timeline and mastery go
    try testing.expectEqual(3, try forget(gpa, io, copy, &salt, &.{ a, "short" }));
    try testing.expectEqual(2, (try read(arena, copy, .summary)).len);
    try testing.expectEqual(0, (try read(arena, copy, .timeline)).len);
    try testing.expectEqual(0, (try read(arena, copy, .mastery)).len);

    // 24 months on: no hashed PUUID left, mastery gone, once
    try testing.expectEqual(0, try age(gpa, io, copy, 20_000 + 730, 730));
    try testing.expectEqual(3, try age(gpa, io, copy, 20_000 + 731, 730));
    try testing.expectEqual(0, try age(gpa, io, copy, 20_000 + 731, 730));
    for (try read(arena, copy, .summary)) |d| try testing.expect(std.mem.find(u8, d.bytes, &hx) == null);
    try testing.expectError(error.FileNotFound, read(arena, copy, .mastery));
}
