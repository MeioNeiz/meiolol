//! Packed rows (`meiolol-lab pack SNAP`): rows.Data as column files in SNAP/pack/, so lab
//! commands load without SQLite. rows.load reads the pack when its manifest matches the
//! snapshot and this binary, else SQLite. Layout: docs/architecture.md "Packed rows"

const std = @import("std");
const rows = @import("rows.zig");
const seatstats = @import("seatstats.zig");

const Io = std.Io;
const Data = rows.Data;
const Game = rows.Game;
const Row = rows.Row;
const log = std.log.scoped(.pack);

/// Bump when what rows.loadSql returns changes through code not in `sources`
pub const version = 1;
pub const dir_name = "pack";
const dbs = [_][]const u8{ "meiolol.db", "raw.db", "timeline.db" };

/// Any edit to these makes older packs stale. eval.split, timeline.decode and the like
/// change often for other reasons and aren't hashed: bump `version` if they change rows
const sources = [_][]const u8{
    @embedFile("rowsql.zig"),    @embedFile("pack.zig"),
    @embedFile("protocol.zig"),  @embedFile("../stats.zig"),
    @embedFile("seatstats.zig"),
};

/// Tests only: stands in for an edit to `sources`
pub var test_source_edit: []const u8 = "";

pub const Written = struct { games: usize, rows: usize, bytes: u64 };

/// Loads SNAP from SQLite and writes SNAP/pack/ through a temp dir, so readers see the
/// old pack, none, or the new one whole
pub fn write(
    gpa: std.mem.Allocator,
    io: Io,
    snap: []const u8,
    legendaries: *const std.AutoHashMapUnmanaged(u64, void),
) !Written {
    const before = try head(gpa, io, snap, legendaries);
    defer gpa.free(before);
    var data = try rows.loadSql(gpa, snap, legendaries);
    defer data.deinit();
    const after = try head(gpa, io, snap, legendaries);
    defer gpa.free(after);
    if (!std.mem.eql(u8, before, after)) return error.SnapshotChangedWhilePacking;
    return writeData(gpa, io, snap, before, &data);
}

/// From SQLite, repacking SNAP/pack/ when one exists but is stale: an edit to `sources`
/// (stats.zig changes for the site too) left every run loading from SQLite until someone
/// ran `meiolol-lab pack` (1320Z, 18 Oct: 104 s a load at 8 GB). A failed repack only logs
pub fn loadRepacking(
    gpa: std.mem.Allocator,
    io: Io,
    snap: []const u8,
    legendaries: *const std.AutoHashMapUnmanaged(u64, void),
) !Data {
    const pack_path = try std.fs.path.join(gpa, &.{ snap, dir_name });
    defer gpa.free(pack_path);
    const had = if (Io.Dir.cwd().statFile(io, pack_path, .{})) |_| true else |_| false;
    if (!had) return rows.loadSql(gpa, snap, legendaries);
    const before = try head(gpa, io, snap, legendaries);
    defer gpa.free(before);
    var data = try rows.loadSql(gpa, snap, legendaries);
    errdefer data.deinit();
    const after = try head(gpa, io, snap, legendaries);
    defer gpa.free(after);
    if (!std.mem.eql(u8, before, after)) {
        log.info("{s} changed while loading: not repacked", .{snap});
    } else if (writeData(gpa, io, snap, before, &data)) |n| {
        log.info("repacked {s}/{s} ({d} games, {d} rows)", .{ snap, dir_name, n.games, n.rows });
    } else |err| switch (err) {
        error.OutOfMemory => return err,
        else => log.info("{s}/{s}: not repacked ({t})", .{ snap, dir_name, err }),
    }
    return data;
}

/// DATA (loaded from SQLite while the manifest head was `before`) as SNAP/pack/
fn writeData(gpa: std.mem.Allocator, io: Io, snap: []const u8, before: []const u8, data: *const Data) !Written {
    var tag: [8]u8 = undefined;
    io.random(&tag);
    const tmp_path = try gpa.print("{s}/{s}.tmp-{x}", .{ snap, dir_name, tag });
    defer gpa.free(tmp_path);
    const cwd = Io.Dir.cwd();
    try cwd.createDirPath(io, tmp_path);
    errdefer cwd.deleteTree(io, tmp_path) catch {};
    var bytes: u64 = 0;
    {
        var dir = try cwd.openDir(io, tmp_path, .{});
        defer dir.close(io);
        bytes += try writeStruct(Game, "games", io, dir, data.games);
        bytes += try writeStruct(Row, "rows", io, dir, data.rows);
        // Last: a pack without its manifest is never read
        const manifest = try gpa.print("{s}games {d}\nrows {d}\n", .{
            before, data.games.len, data.rows.len,
        });
        defer gpa.free(manifest);
        var file = try dir.createFile(io, "manifest", .{});
        defer file.close(io);
        try file.writeStreamingAll(io, manifest);
        try file.sync(io);
        bytes += manifest.len;

        var back = try readColumns(gpa, io, dir, data.games.len, data.rows.len);
        defer back.deinit();
        var buf: [256]u8 = undefined;
        if (firstDiff(data, &back, &buf)) |d| {
            log.err("{s} reads back differently: {s}", .{ tmp_path, d });
            return error.PackRoundTrip;
        }
    }

    const pack_path = try std.fs.path.join(gpa, &.{ snap, dir_name });
    defer gpa.free(pack_path);
    const old_path = try gpa.print("{s}/{s}.old-{x}", .{ snap, dir_name, tag });
    defer gpa.free(old_path);
    // rename can't replace a non-empty directory: move the old one aside first
    cwd.rename(pack_path, cwd, old_path, io) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };
    try cwd.rename(tmp_path, cwd, pack_path, io);
    cwd.deleteTree(io, old_path) catch {};
    return .{ .games = data.games.len, .rows = data.rows.len, .bytes = bytes };
}

/// SNAP/pack/ as rows.Data, or null (with a note when one exists but can't be used)
pub fn read(
    gpa: std.mem.Allocator,
    io: Io,
    snap: []const u8,
    legendaries: *const std.AutoHashMapUnmanaged(u64, void),
) !?Data {
    const path = try std.fs.path.join(gpa, &.{ snap, dir_name });
    defer gpa.free(path);
    var dir = Io.Dir.cwd().openDir(io, path, .{}) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => {
            log.info("{s}: {t}; loading from SQLite", .{ path, err });
            return null;
        },
    };
    defer dir.close(io);
    const want = try head(gpa, io, snap, legendaries);
    defer gpa.free(want);
    const manifest = dir.readFileAlloc(io, "manifest", gpa, .limited(1 << 20)) catch |err| {
        log.info("{s}/manifest: {t}; loading from SQLite", .{ path, err });
        return null;
    };
    defer gpa.free(manifest);
    if (!std.mem.startsWith(u8, manifest, want)) {
        log.info("{s} is stale ({s} differs); loading from SQLite (meiolol-lab pack)", .{
            path, firstLineDiff(want, manifest),
        });
        return null;
    }
    var counts: [2]usize = undefined;
    var lines = std.mem.tokenizeScalar(u8, manifest[want.len..], '\n');
    for (&counts, [_][]const u8{ "games ", "rows " }) |*n, key| {
        const line = lines.next() orelse "";
        n.* = if (std.mem.startsWith(u8, line, key))
            std.fmt.parseInt(usize, line[key.len..], 10) catch std.math.maxInt(usize)
        else
            std.math.maxInt(usize);
    }
    if (counts[0] == std.math.maxInt(usize) or counts[1] == std.math.maxInt(usize)) {
        log.info("{s}/manifest has no counts; loading from SQLite", .{path});
        return null;
    }
    return readColumns(gpa, io, dir, counts[0], counts[1]) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => {
            log.info("{s} is unreadable ({t}); loading from SQLite", .{ path, err });
            return null;
        },
    };
}

/// The manifest lines a pack must match to be read: format, code, legendaries, the
/// source databases (size and mtime to the second, of the WAL too), seat_stats.tsv and
/// the columns
fn head(
    gpa: std.mem.Allocator,
    io: Io,
    snap: []const u8,
    legendaries: *const std.AutoHashMapUnmanaged(u64, void),
) ![]u8 {
    var out: Io.Writer.Allocating = .init(gpa);
    errdefer out.deinit();
    const w = &out.writer;
    try w.print("meiolol-lab pack {d}\n", .{version});
    var code: std.hash.Wyhash = .init(0);
    for (sources) |s| code.update(s);
    if (@import("builtin").is_test) code.update(test_source_edit);
    try w.print("code {x:0>16}\n", .{code.final()});

    const keys = try gpa.alloc(u64, legendaries.count());
    defer gpa.free(keys);
    var it = legendaries.keyIterator();
    for (keys) |*k| k.* = it.next().?.*;
    std.mem.sortUnstable(u64, keys, {}, std.sort.asc(u64));
    var leg: std.hash.Wyhash = .init(0);
    for (keys) |k| leg.update(&std.mem.toBytes(std.mem.nativeToLittle(u64, k)));
    try w.print("legendaries {d} {x:0>16}\n", .{ keys.len, leg.final() });

    inline for (dbs) |name| {
        const db = try stamp(gpa, io, snap, name) orelse return error.FileNotFound;
        const wal = try stamp(gpa, io, snap, name ++ "-wal") orelse
            Stamp{ .size = 0, .mtime = 0 };
        // Readers may create or truncate an empty WAL: only one with contents counts
        try w.print("{s} {d} {d} wal {d} {d}\n", .{
            name, db.size, db.mtime, wal.size, if (wal.size == 0) 0 else wal.mtime,
        });
    }
    // Optional input (rows.Row.stats): appearing, changing or going makes the pack stale
    const seats = try stamp(gpa, io, snap, seatstats.file_name) orelse Stamp{ .size = 0, .mtime = 0 };
    try w.print("{s} {d} {d}\n", .{ seatstats.file_name, seats.size, seats.mtime });
    try columns(Game, "games", w);
    try columns(Row, "rows", w);
    return out.toOwnedSlice();
}

/// mtime in whole seconds: rsync (openrsync on the Mac) drops the nanoseconds on copy
const Stamp = struct { size: u64, mtime: i64 };

fn stamp(gpa: std.mem.Allocator, io: Io, snap: []const u8, name: []const u8) !?Stamp {
    const path = try std.fs.path.join(gpa, &.{ snap, name });
    defer gpa.free(path);
    const st = Io.Dir.cwd().statFile(io, path, .{}) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    return .{ .size = st.size, .mtime = st.mtime.toSeconds() };
}

/// "column NAME TYPE COUNT" per file: COUNT values of TYPE (little-endian) per item;
/// a string field is NAME (the bytes, concatenated) and NAME.end (u64 end offsets)
fn columns(comptime S: type, comptime prefix: []const u8, w: *Io.Writer) !void {
    const info = @typeInfo(S).@"struct";
    inline for (info.field_names, info.field_types) |name, F| {
        if (F == []const u8) {
            try w.print("column {s}.{s} bytes\n", .{ prefix, name });
            try w.print("column {s}.{s}.end u64 1\n", .{ prefix, name });
        } else {
            const wire = @typeName(Wire(Leaf(F)));
            try w.print("column {s}.{s} {s} {d}\n", .{ prefix, name, wire, leafCount(F) });
        }
    }
}

/// The first key (a line's first word) where `want` and `have` differ
fn firstLineDiff(want: []const u8, have: []const u8) []const u8 {
    var a = std.mem.splitScalar(u8, want, '\n');
    var b = std.mem.splitScalar(u8, have, '\n');
    while (a.next()) |x| {
        const y = b.next() orelse "";
        if (!std.mem.eql(u8, x, y)) {
            if (std.mem.startsWith(u8, x, "column")) return "column layout";
            return x[0 .. std.mem.findScalar(u8, x, ' ') orelse x.len];
        }
    }
    return "manifest";
}

fn writeStruct(
    comptime S: type,
    comptime prefix: []const u8,
    io: Io,
    dir: Io.Dir,
    items: []const S,
) !u64 {
    var bytes: u64 = 0;
    const info = @typeInfo(S).@"struct";
    inline for (info.field_names, info.field_types) |name, F| {
        const file = prefix ++ "." ++ name;
        if (F == []const u8) {
            bytes += try writeColumn(S, name, .bytes, io, dir, file, items);
            bytes += try writeColumn(S, name, .ends, io, dir, file ++ ".end", items);
        } else {
            bytes += try writeColumn(S, name, .values, io, dir, file, items);
        }
    }
    return bytes;
}

fn writeColumn(
    comptime S: type,
    comptime name: []const u8,
    comptime part: enum { values, bytes, ends },
    io: Io,
    dir: Io.Dir,
    file_name: []const u8,
    items: []const S,
) !u64 {
    var file = try dir.createFile(io, file_name, .{});
    defer file.close(io);
    var buf: [1 << 16]u8 = undefined;
    var fw = file.writer(io, &buf);
    const w = &fw.interface;
    var end: u64 = 0;
    for (items) |*item| {
        const v = @field(item.*, name);
        switch (part) {
            .bytes => try w.writeAll(v),
            .ends => {
                end += v.len;
                try w.writeInt(u64, end, .little);
            },
            .values => {
                const F = @TypeOf(v);
                const L = Leaf(F);
                const flat: *const [leafCount(F)]L = @ptrCast(&v);
                for (flat) |x| {
                    try w.writeInt(Bits(Wire(L)), @bitCast(try encode(L, x)), .little);
                }
            },
        }
    }
    w.flush() catch return fw.err orelse error.WriteFailed;
    try file.sync(io);
    return file.length(io);
}

fn readColumns(gpa: std.mem.Allocator, io: Io, dir: Io.Dir, n_games: usize, n_rows: usize) !Data {
    // Sizes first: a bad count must not turn into a huge allocation
    try checkSizes(Game, "games", io, dir, n_games);
    try checkSizes(Row, "rows", io, dir, n_rows);
    var data: Data = .{ .arena = .init(gpa), .games = &.{}, .rows = &.{} };
    errdefer data.deinit();
    const arena = data.arena.allocator();
    const games = try arena.alloc(Game, n_games);
    const rws = try arena.alloc(Row, n_rows);
    try readStruct(Game, "games", gpa, arena, io, dir, games);
    try readStruct(Row, "rows", gpa, arena, io, dir, rws);
    for (rws) |r| if (r.game >= games.len) return error.PackCorrupt;
    data.games = games;
    data.rows = rws;
    return data;
}

fn readStruct(
    comptime S: type,
    comptime prefix: []const u8,
    gpa: std.mem.Allocator,
    arena: std.mem.Allocator,
    io: Io,
    dir: Io.Dir,
    items: []S,
) !void {
    const info = @typeInfo(S).@"struct";
    inline for (info.field_names, info.field_types) |name, F| {
        const file = prefix ++ "." ++ name;
        if (F == []const u8) {
            const ends = try readExact(gpa, io, dir, file ++ ".end", items.len * 8);
            defer gpa.free(ends);
            const last: u64 = if (items.len == 0) 0 else std.mem.readInt(u64, ends[ends.len - 8 ..][0..8], .little);
            const total_len = std.math.cast(usize, last) orelse return error.PackCorrupt;
            // Strings point into the arena copy
            const bytes = try readExact(arena, io, dir, file, total_len);
            var start: usize = 0;
            for (items, 0..) |*item, i| {
                const end = std.mem.readInt(u64, ends[i * 8 ..][0..8], .little);
                if (end < start or end > bytes.len) return error.PackCorrupt;
                @field(item.*, name) = bytes[start..@intCast(end)];
                start = @intCast(end);
            }
        } else {
            const L = Leaf(F);
            const W = Wire(L);
            const size = @sizeOf(W);
            const n = comptime leafCount(F);
            const bytes = try readExact(gpa, io, dir, file, items.len * n * size);
            defer gpa.free(bytes);
            var at: usize = 0;
            for (items) |*item| {
                const flat: *[n]L = @ptrCast(&@field(item.*, name));
                for (flat) |*x| {
                    const raw = std.mem.readInt(Bits(W), bytes[at..][0..size], .little);
                    x.* = try decode(L, @bitCast(raw));
                    at += size;
                }
            }
        }
    }
}

fn checkSizes(comptime S: type, comptime prefix: []const u8, io: Io, dir: Io.Dir, n: usize) !void {
    const info = @typeInfo(S).@"struct";
    inline for (info.field_names, info.field_types) |name, F| {
        const file = prefix ++ "." ++ name;
        const width = if (F == []const u8) 8 else leafCount(F) * @sizeOf(Wire(Leaf(F)));
        const want = n *| width;
        const st = try dir.statFile(io, if (F == []const u8) file ++ ".end" else file, .{});
        if (st.size != want) return error.PackCorrupt;
    }
}

fn readExact(alloc: std.mem.Allocator, io: Io, dir: Io.Dir, name: []const u8, len: usize) ![]u8 {
    const bytes = dir.readFileAlloc(io, name, alloc, .limited(len + 1)) catch |err| switch (err) {
        error.StreamTooLong => return error.PackCorrupt,
        else => return err,
    };
    if (bytes.len != len) {
        alloc.free(bytes);
        return error.PackCorrupt;
    }
    return bytes;
}

/// The innermost element of a (nested) array field, and how many of them it holds
fn Leaf(comptime F: type) type {
    return switch (@typeInfo(F)) {
        .array => |a| Leaf(a.child),
        else => F,
    };
}

fn leafCount(comptime F: type) usize {
    return switch (@typeInfo(F)) {
        .array => |a| a.len * leafCount(a.child),
        else => 1,
    };
}

/// Stored type: whole bytes; bool 0/1, enum its tag, optional its child with maxInt as null
fn Wire(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .int => |i| @Int(i.signedness, switch (i.bits) {
            0...8 => 8,
            9...16 => 16,
            17...32 => 32,
            else => 64,
        }),
        .float => T,
        .bool => u8,
        .@"enum" => |e| Wire(e.tag_type),
        .optional => |o| Wire(o.child),
        else => @compileError("pack: no column encoding for " ++ @typeName(T)),
    };
}

fn Bits(comptime W: type) type {
    return @Int(.unsigned, @bitSizeOf(W));
}

fn encode(comptime T: type, v: T) !Wire(T) {
    return switch (@typeInfo(T)) {
        .int, .float => v,
        .bool => @intFromBool(v),
        .@"enum" => @backingInt(v),
        .optional => |o| if (v) |x| blk: {
            const e = try encode(o.child, x);
            break :blk if (e == std.math.maxInt(Wire(T))) error.PackNullSentinel else e;
        } else std.math.maxInt(Wire(T)),
        else => comptime unreachable,
    };
}

fn decode(comptime T: type, w: Wire(T)) !T {
    return switch (@typeInfo(T)) {
        .int => std.math.cast(T, w) orelse error.PackCorrupt,
        .float => w,
        .bool => switch (w) {
            0 => false,
            1 => true,
            else => error.PackCorrupt,
        },
        .@"enum" => std.enums.fromInt(T, w) orelse error.PackCorrupt,
        .optional => |o| if (w == std.math.maxInt(Wire(T))) null else try decode(o.child, w),
        else => comptime unreachable,
    };
}

/// The first field that differs between two loads, bit for bit (NaN equals NaN), or null
pub fn firstDiff(a: *const Data, b: *const Data, buf: []u8) ?[]const u8 {
    if (a.games.len != b.games.len) {
        return std.mem.print(buf, "{d} games vs {d}", .{ a.games.len, b.games.len }) catch "games";
    }
    if (a.rows.len != b.rows.len) {
        return std.mem.print(buf, "{d} rows vs {d}", .{ a.rows.len, b.rows.len }) catch "rows";
    }
    for (a.games, b.games, 0..) |*x, *y, i| if (structDiff(Game, x, y)) |f| {
        return std.mem.print(buf, "game {d}: {s}", .{ i, f }) catch f;
    };
    for (a.rows, b.rows, 0..) |*x, *y, i| if (structDiff(Row, x, y)) |f| {
        return std.mem.print(buf, "row {d}: {s}", .{ i, f }) catch f;
    };
    return null;
}

fn structDiff(comptime S: type, x: *const S, y: *const S) ?[]const u8 {
    const info = @typeInfo(S).@"struct";
    inline for (info.field_names, info.field_types) |name, F| {
        if (!same(F, @field(x.*, name), @field(y.*, name))) return name;
    }
    return null;
}

fn same(comptime T: type, a: T, b: T) bool {
    if (T == []const u8) return std.mem.eql(u8, a, b);
    return switch (@typeInfo(T)) {
        .array => |arr| for (a, b) |x, y| {
            if (!same(arr.child, x, y)) break false;
        } else true,
        .optional => |o| if (a) |x| (if (b) |y| same(o.child, x, y) else false) else b == null,
        .float => @as(Bits(T), @bitCast(a)) == @as(Bits(T), @bitCast(b)),
        else => a == b,
    };
}

test "row production is hashed, loading and hooks are not" {
    const has = struct {
        fn f(text: []const u8) bool {
            for (sources) |s| if (std.mem.eql(u8, s, text)) return true;
            return false;
        }
    }.f;
    try std.testing.expect(has(@embedFile("rowsql.zig")));
    try std.testing.expect(!has(@embedFile("rows.zig")));
}
