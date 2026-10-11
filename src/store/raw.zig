//! Raw document bodies. New ones are gzip; ones written by the original Python
//! crawler are zstd. std can decompress both but only compress deflate, so the
//! format is told apart by magic bytes rather than stored.

const std = @import("std");
const flate = std.compress.flate;
const zstd = std.compress.zstd;
const Allocator = std.mem.Allocator;

const zstd_magic = "\x28\xb5\x2f\xfd";
const gzip_magic = "\x1f\x8b";

pub fn compress(gpa: Allocator, data: []const u8) ![]u8 {
    var out: std.Io.Writer.Allocating = try .initCapacity(gpa, @max(64, data.len / 4));
    errdefer out.deinit();
    const window = try gpa.alloc(u8, flate.max_window_len);
    defer gpa.free(window);
    var c = try flate.Compress.init(&out.writer, window, .gzip, .default);
    try c.writer.writeAll(data);
    try c.finish();
    return out.toOwnedSlice();
}

pub fn decompress(gpa: Allocator, blob: []const u8) ![]u8 {
    var in: std.Io.Reader = .fixed(blob);
    if (std.mem.startsWith(u8, blob, zstd_magic)) {
        const buf = try gpa.alloc(u8, zstd.default_window_len + zstd.block_size_max);
        defer gpa.free(buf);
        var d: zstd.Decompress = .init(&in, buf, .{});
        return d.reader.allocRemaining(gpa, .unlimited);
    }
    if (std.mem.startsWith(u8, blob, gzip_magic)) {
        const buf = try gpa.alloc(u8, flate.max_window_len);
        defer gpa.free(buf);
        var d: flate.Decompress = .init(&in, .gzip, buf);
        return d.reader.allocRemaining(gpa, .unlimited);
    }
    return error.UnknownCompression;
}

test "gzip round trip" {
    const gpa = std.testing.allocator;
    const text = "{\"metadata\":{\"matchId\":\"EUW1_1\"}," ** 200 ++ "}";
    const packed_ = try compress(gpa, text);
    defer gpa.free(packed_);
    try std.testing.expect(packed_.len < text.len / 10);
    const unpacked = try decompress(gpa, packed_);
    defer gpa.free(unpacked);
    try std.testing.expectEqualStrings(text, unpacked);
}

test "zstd from python" {
    // compression.zstd.compress(b'{"a":1}') from Python 3.14
    const blob = "\x28\xb5\x2f\xfd\x20\x07\x39\x00\x00\x7b\x22\x61\x22\x3a\x31\x7d";
    const out = try decompress(std.testing.allocator, blob);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("{\"a\":1}", out);
}
