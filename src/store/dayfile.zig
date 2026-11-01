//! Complete form day files (docs/plan/ops.md "Complete form"): frames appended one after
//! another, each a jsonpack block of documents, or the raw bytes of documents that failed
//! their check, with every document's key and fetch time, through zstd.
//!
//! Frame: magic, type (0 block, 1 raw), payload length (u32 LE), crc32 of the payload
//! (u32 LE), payload. The payload is one zstd frame of: keys (count; per document
//! fetched_at, key length and bytes; LEB128), then the body: the jsonpack block, or per
//! raw document its length and bytes. A frame cut short or failing its crc ends the file:
//! `recover` truncates there, so a crash mid-append never touches the frames before.

const std = @import("std");
const jsonpack = @import("jsonpack.zig");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Crc32 = std.hash.Crc32;
const zstd = std.compress.zstd;

pub const magic = "CFD1";
pub const header_len = magic.len + 9;
/// A frame's plain payload at most: blocks seal long before (riot/complete.zig)
pub const max_payload = 1 << 30;

pub const Type = enum(u8) { block, raw };

pub const Doc = struct { key: []const u8, t: i64, bytes: []const u8 };

pub fn putVar(gpa: Allocator, out: *std.ArrayList(u8), v: u64) !void {
    var x = v;
    while (x >= 0x80) : (x >>= 7) try out.append(gpa, @as(u8, @truncate(x)) | 0x80);
    try out.append(gpa, @intCast(x));
}

/// LEB128 varints and length-prefixed bytes from a buffer; error.Corrupt past its end
pub const Reader = struct {
    b: []const u8,
    i: usize = 0,

    pub fn varint(r: *Reader) !u64 {
        var v: u64 = 0;
        var shift: u7 = 0;
        while (shift < 64) : (shift += 7) {
            if (r.i >= r.b.len) return error.Corrupt;
            const c = r.b[r.i];
            r.i += 1;
            v |= @as(u64, c & 0x7f) << @intCast(shift);
            if (c < 0x80) return v;
        }
        return error.Corrupt;
    }

    pub fn bytes(r: *Reader, n: u64) ![]const u8 {
        if (n > r.b.len - r.i) return error.Corrupt;
        const s = r.b[r.i..][0..@intCast(n)];
        r.i += s.len;
        return s;
    }

    pub fn done(r: *const Reader) bool {
        return r.i == r.b.len;
    }
};

/// A plain payload's start: the documents' keys and fetch times, in order
pub fn keys(gpa: Allocator, out: *std.ArrayList(u8), docs: []const Doc) !void {
    try putVar(gpa, out, docs.len);
    for (docs) |d| {
        try putVar(gpa, out, @intCast(d.t));
        try putVar(gpa, out, d.key.len);
        try out.appendSlice(gpa, d.key);
    }
}

/// A raw frame's body: each document's length and bytes
pub fn rawBody(gpa: Allocator, out: *std.ArrayList(u8), docs: []const Doc) !void {
    for (docs) |d| {
        try putVar(gpa, out, d.bytes.len);
        try out.appendSlice(gpa, d.bytes);
    }
}

pub fn header(t: Type, zst: []const u8) [header_len]u8 {
    var h: [header_len]u8 = undefined;
    @memcpy(h[0..magic.len], magic);
    h[magic.len] = @backingInt(t);
    std.mem.writeInt(u32, h[magic.len + 1 ..][0..4], @intCast(zst.len), .little);
    std.mem.writeInt(u32, h[magic.len + 5 ..][0..4], Crc32.hash(zst), .little);
    return h;
}

pub const Frame = struct { type: Type, zst: []u8 };

/// The frames of an open file from the start, positional reads only
pub const Frames = struct {
    file: Io.File,
    pos: u64 = 0,
    /// Frames past this are not read: a `.part` the crawler is appending to grows
    end: ?u64 = null,

    /// null at the end of the frames: the end of the file, or a cut or damaged frame
    /// (`pos` is where the whole frames end). zst owned by `gpa`
    pub fn next(f: *Frames, gpa: Allocator, io: Io) !?Frame {
        const end = f.end orelse try f.file.length(io);
        var h: [header_len]u8 = undefined;
        if (end -| f.pos < h.len) return null;
        if (try f.file.readPositionalAll(io, &h, f.pos) < h.len) return null;
        if (!std.mem.eql(u8, h[0..magic.len], magic)) return null;
        const t = std.enums.fromInt(Type, h[magic.len]) orelse return null;
        const n = std.mem.readInt(u32, h[magic.len + 1 ..][0..4], .little);
        // A damaged length must not allocate past the file
        if (n > end - f.pos - h.len) return null;
        const zst = try gpa.alloc(u8, n);
        errdefer gpa.free(zst);
        if (try f.file.readPositionalAll(io, zst, f.pos + h.len) < n or
            Crc32.hash(zst) != std.mem.readInt(u32, h[magic.len + 5 ..][0..4], .little))
        {
            gpa.free(zst);
            return null;
        }
        f.pos += h.len + n;
        return .{ .type = t, .zst = zst };
    }
};

/// Cuts whatever follows the last whole frame of `file` (a crash mid-append); returns its
/// length, where the next frame goes
pub fn recover(gpa: Allocator, io: Io, file: Io.File) !u64 {
    var frames: Frames = .{ .file = file };
    while (try frames.next(gpa, io)) |fr| gpa.free(fr.zst);
    if (try file.length(io) != frames.pos) {
        try file.setLength(io, frames.pos);
        try file.sync(io);
    }
    return frames.pos;
}

/// The plain payload of a frame's zstd bytes, in `arena`
pub fn inflate(gpa: Allocator, arena: Allocator, zst: []const u8) ![]u8 {
    var in: Io.Reader = .fixed(zst);
    const buf = try gpa.alloc(u8, zstd.default_window_len + zstd.block_size_max);
    defer gpa.free(buf);
    var d: zstd.Decompress = .init(&in, buf, .{});
    const plain = d.reader.allocRemaining(arena, .limited(max_payload)) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => return error.Corrupt,
    };
    if (in.seek != zst.len) return error.Corrupt;
    return plain;
}

/// A plain payload's keys and fetch times (bytes empty), and where its body starts
pub fn readKeys(arena: Allocator, plain: []const u8) !struct { docs: []Doc, body: usize } {
    var r: Reader = .{ .b = plain };
    const n = try r.varint();
    if (n > plain.len) return error.Corrupt;
    const docs = try arena.alloc(Doc, @intCast(n));
    for (docs) |*d| {
        const t = try r.varint();
        d.* = .{ .t = @bitCast(t), .key = try r.bytes(try r.varint()), .bytes = "" };
    }
    return .{ .docs = docs, .body = r.i };
}

/// A frame's documents, everything in `arena`. error.Corrupt for anything that is not a
/// whole frame
pub fn decode(gpa: Allocator, arena: Allocator, fr: Frame) ![]Doc {
    const plain = try inflate(gpa, arena, fr.zst);
    const k = try readKeys(arena, plain);
    const docs = k.docs;
    var r: Reader = .{ .b = plain, .i = k.body };
    switch (fr.type) {
        .raw => {
            for (docs) |*d| d.bytes = try r.bytes(try r.varint());
            if (!r.done()) return error.Corrupt;
        },
        .block => {
            var out: std.ArrayList(u8) = .empty;
            const ends = try jsonpack.decode(gpa, plain[r.i..], &out);
            defer gpa.free(ends);
            if (ends.len != docs.len) return error.Corrupt;
            const all = try arena.dupe(u8, out.items);
            out.deinit(gpa);
            var start: usize = 0;
            for (docs, ends) |*d, end| {
                d.bytes = all[start..end];
                start = end;
            }
        },
    }
    return docs;
}

/// Every document of the day file at `path`, in order, in `arena`; error.Corrupt when a
/// frame does not decode or bytes follow the last whole one
pub fn readAll(gpa: Allocator, arena: Allocator, io: Io, path: []const u8) ![]Doc {
    const file = try Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    var docs: std.ArrayList(Doc) = .empty;
    var frames: Frames = .{ .file = file };
    while (try frames.next(gpa, io)) |fr| {
        defer gpa.free(fr.zst);
        try docs.appendSlice(arena, try decode(gpa, arena, fr));
    }
    if (frames.pos != try file.length(io)) return error.Corrupt;
    return docs.items;
}

fn testFrame(gpa: Allocator, t: Type, docs: []const Doc) ![]u8 {
    var plain: std.ArrayList(u8) = .empty;
    defer plain.deinit(gpa);
    try keys(gpa, &plain, docs);
    switch (t) {
        .raw => try rawBody(gpa, &plain, docs),
        .block => {
            var b: jsonpack.Block = .init(gpa);
            defer b.deinit();
            for (docs) |d| try std.testing.expect(try b.add(d.bytes));
            try b.finish(&plain);
        },
    }
    // A zstd frame of one stored block (std has no compressor); payloads under 256 bytes
    var zst: std.ArrayList(u8) = .empty;
    errdefer zst.deinit(gpa);
    try zst.appendSlice(gpa, &.{ 0x28, 0xb5, 0x2f, 0xfd, 0x20 });
    try zst.append(gpa, @intCast(plain.items.len));
    const bh: u32 = @intCast(plain.items.len << 3 | 1);
    try zst.appendSlice(gpa, std.mem.asBytes(&std.mem.nativeToLittle(u32, bh))[0..3]);
    try zst.appendSlice(gpa, plain.items);
    const h = header(t, zst.items);
    try zst.insertSlice(gpa, 0, &h);
    return zst.toOwnedSlice(gpa);
}

test "frames read back; a cut or damaged tail is cut, the frames before kept" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const a = [_]Doc{ .{ .key = "EUW1_1", .t = 5, .bytes = "{\"a\":[1,2,3]}" }, .{ .key = "EUW1_2", .t = 6, .bytes = "{\"a\":[1,2,4]}" } };
    const b = [_]Doc{.{ .key = "KR_9", .t = 7, .bytes = "not json" }};
    const fa = try testFrame(gpa, .block, &a);
    defer gpa.free(fa);
    const fb = try testFrame(gpa, .raw, &b);
    defer gpa.free(fb);
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const file_path = try arena.print(".zig-cache/tmp/{s}/d.cfd", .{&tmp.sub_path});

    for ([_]usize{ 0, 1, header_len, fb.len - 1 }) |cut| {
        const file = try tmp.dir.createFile(io, "d.cfd", .{ .read = true });
        defer file.close(io);
        try file.writePositionalAll(io, fa, 0);
        try file.writePositionalAll(io, fb[0 .. fb.len - cut], fa.len);
        if (cut == 0) {
            const docs = try readAll(gpa, arena, io, file_path);
            try std.testing.expectEqual(3, docs.len);
            for (docs, a ++ b) |got, want| {
                try std.testing.expectEqualStrings(want.key, got.key);
                try std.testing.expectEqual(want.t, got.t);
                try std.testing.expectEqualStrings(want.bytes, got.bytes);
            }
            // A reader that took the length before fb was appended stops at it
            var frames: Frames = .{ .file = file, .end = fa.len };
            gpa.free((try frames.next(gpa, io)).?.zst);
            try std.testing.expectEqual(null, try frames.next(gpa, io));
            try std.testing.expectEqual(fa.len, frames.pos);
            continue;
        }
        try std.testing.expectError(error.Corrupt, readAll(gpa, arena, io, file_path));
        try std.testing.expectEqual(fa.len, try recover(gpa, io, file));
        try std.testing.expectEqual(fa.len, try file.length(io));
        try std.testing.expectEqual(2, (try readAll(gpa, arena, io, file_path)).len);
    }

    // A flipped payload byte fails the crc: that frame and all after it go
    const file = try tmp.dir.createFile(io, "d.cfd", .{ .read = true });
    defer file.close(io);
    try file.writePositionalAll(io, fa, 0);
    fb[header_len + 3] ^= 1;
    try file.writePositionalAll(io, fb, fa.len);
    try std.testing.expectEqual(fa.len, try recover(gpa, io, file));
}

test "a frame whose payload is not whole is corrupt, never a crash" {
    const gpa = std.testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const docs = [_]Doc{.{ .key = "k", .t = 1, .bytes = "[1]" }};
    for ([_]Type{ .block, .raw }) |t| {
        const f = try testFrame(gpa, t, &docs);
        defer gpa.free(f);
        try std.testing.expectEqualStrings("[1]", (try decode(gpa, arena_state.allocator(), .{ .type = t, .zst = f[header_len..] }))[0].bytes);
        try std.testing.expectError(error.Corrupt, decode(gpa, arena_state.allocator(), .{ .type = t, .zst = f[header_len .. f.len - 1] }));
    }
}
