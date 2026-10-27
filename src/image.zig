//! Champion icons for the site: Data Dragon's PNG squares shrunk and saved as JPEG
//! (64 px ~3 KB against ~29 KB for the 128 px PNG, drawn at 20-56 px). Reads the PNGs
//! Data Dragon serves (8-bit RGB or RGBA, not interlaced; alpha dropped: the squares are
//! opaque); writes baseline JPEG, no chroma subsampling (small art keeps its edges)

const std = @import("std");
const Allocator = std.mem.Allocator;

/// 8-bit RGB, rows top to bottom
pub const Image = struct {
    w: u32,
    h: u32,
    rgb: []u8,

    pub fn deinit(i: Image, gpa: Allocator) void {
        gpa.free(i.rgb);
    }
};

const max_side = 4096;

pub const PngError = error{ NotPng, Unsupported, Corrupt };

pub fn decodePng(gpa: Allocator, data: []const u8) (PngError || Allocator.Error)!Image {
    const sig = "\x89PNG\r\n\x1a\n";
    if (!std.mem.startsWith(u8, data, sig)) return error.NotPng;
    var pos: usize = sig.len;
    var w: u32 = 0;
    var h: u32 = 0;
    var channels: u32 = 0;
    var z: std.ArrayList(u8) = .empty;
    defer z.deinit(gpa);
    while (true) {
        if (data.len - pos < 12) return error.Corrupt;
        const len = std.mem.readInt(u32, data[pos..][0..4], .big);
        if (len > data.len - pos - 12) return error.Corrupt;
        const kind = data[pos + 4 ..][0..4];
        const body = data[pos + 8 ..][0..len];
        pos += 12 + len;
        if (std.mem.eql(u8, kind, "IHDR")) {
            if (len != 13) return error.Corrupt;
            w = std.mem.readInt(u32, body[0..4], .big);
            h = std.mem.readInt(u32, body[4..8], .big);
            if (w == 0 or h == 0 or w > max_side or h > max_side) return error.Unsupported;
            // Bit depth 8, no compression or filter variants, not interlaced
            if (body[8] != 8 or body[10] != 0 or body[11] != 0 or body[12] != 0) return error.Unsupported;
            channels = switch (body[9]) {
                2 => 3,
                6 => 4,
                else => return error.Unsupported,
            };
        } else if (std.mem.eql(u8, kind, "IDAT")) {
            if (channels == 0) return error.Corrupt;
            try z.appendSlice(gpa, body);
        } else if (std.mem.eql(u8, kind, "IEND")) break;
    }
    if (channels == 0) return error.Corrupt;
    const stride = w * channels;
    const raw = try gpa.alloc(u8, (stride + 1) * h);
    defer gpa.free(raw);
    const window = try gpa.alloc(u8, std.compress.flate.max_window_len);
    defer gpa.free(window);
    var in: std.Io.Reader = .fixed(z.items);
    var d: std.compress.flate.Decompress = .init(&in, .zlib, window);
    d.reader.readSliceAll(raw) catch return error.Corrupt;

    const px = try gpa.alloc(u8, stride * h);
    defer gpa.free(px);
    for (0..h) |y| {
        const line = raw[y * (stride + 1) ..][0 .. stride + 1];
        const cur = px[y * stride ..][0..stride];
        const up: ?[]const u8 = if (y > 0) px[(y - 1) * stride ..][0..stride] else null;
        for (cur, line[1..], 0..) |*out, x, i| {
            const a: u8 = if (i >= channels) cur[i - channels] else 0;
            const b: u8 = if (up) |u| u[i] else 0;
            const c: u8 = if (up) |u| (if (i >= channels) u[i - channels] else 0) else 0;
            out.* = x +% switch (line[0]) {
                0 => 0,
                1 => a,
                2 => b,
                3 => @as(u8, @intCast((@as(u16, a) + b) / 2)),
                4 => paeth(a, b, c),
                else => return error.Corrupt,
            };
        }
    }
    const rgb = try gpa.alloc(u8, @as(usize, w) * h * 3);
    for (0..@as(usize, w) * h) |i| @memcpy(rgb[3 * i ..][0..3], px[channels * i ..][0..3]);
    return .{ .w = w, .h = h, .rgb = rgb };
}

fn paeth(a: u8, b: u8, c: u8) u8 {
    const p = @as(i16, a) + b - c;
    const pa = @abs(p - a);
    const pb = @abs(p - b);
    const pc = @abs(p - c);
    if (pa <= pb and pa <= pc) return a;
    return if (pb <= pc) b else c;
}

/// Each output pixel the mean of the source area it covers (in sRGB values: close
/// enough for icons)
pub fn resize(gpa: Allocator, src: Image, w: u32, h: u32) Allocator.Error!Image {
    std.debug.assert(w > 0 and h > 0);
    // Rows first: w x src.h, then columns
    const tmp = try gpa.alloc(f32, @as(usize, w) * src.h * 3);
    defer gpa.free(tmp);
    for (0..src.h) |y| for (0..w) |x| {
        var sum: [3]f32 = @splat(0);
        const span = spanOf(x, w, src.w);
        var i = span.first;
        while (i < span.end) : (i += 1) {
            const k = span.cover(i);
            for (&sum, src.rgb[3 * (y * src.w + i) ..][0..3]) |*s, v| s.* += k * @as(f32, @floatFromInt(v));
        }
        for (sum, tmp[3 * (y * w + x) ..][0..3]) |s, *t| t.* = s / span.len;
    };
    const rgb = try gpa.alloc(u8, @as(usize, w) * h * 3);
    for (0..h) |y| for (0..w) |x| {
        var sum: [3]f32 = @splat(0);
        const span = spanOf(y, h, src.h);
        var i = span.first;
        while (i < span.end) : (i += 1) {
            const k = span.cover(i);
            for (&sum, tmp[3 * (i * w + x) ..][0..3]) |*s, v| s.* += k * v;
        }
        for (sum, rgb[3 * (y * w + x) ..][0..3]) |s, *o| o.* = @intFromFloat(std.math.clamp(@round(s / span.len), 0, 255));
    };
    return .{ .w = w, .h = h, .rgb = rgb };
}

const Span = struct {
    lo: f32,
    hi: f32,
    len: f32,
    first: usize,
    end: usize,

    /// How much of source pixel `i` lies in the span
    fn cover(s: Span, i: usize) f32 {
        const f: f32 = @floatFromInt(i);
        return @min(f + 1, s.hi) - @max(f, s.lo);
    }
};

/// The source pixels under output pixel `o` of `out`, from `in` source pixels
fn spanOf(o: usize, out: u32, in: u32) Span {
    const scale = @as(f32, @floatFromInt(in)) / @as(f32, @floatFromInt(out));
    const lo = @as(f32, @floatFromInt(o)) * scale;
    const hi = @min(lo + scale, @as(f32, @floatFromInt(in)));
    const first: usize = @intFromFloat(@floor(lo));
    const end: usize = @min(@as(usize, @intFromFloat(@ceil(hi))), in);
    return .{ .lo = lo, .hi = hi, .len = hi - lo, .first = first, .end = end };
}

/// Baseline JPEG, `quality` 1-100 as libjpeg's scale; caller owns it
pub fn encodeJpeg(gpa: Allocator, img: Image, quality: u8) Allocator.Error![]u8 {
    var aw: std.Io.Writer.Allocating = .init(gpa);
    errdefer aw.deinit();
    writeJpeg(&aw.writer, img, quality) catch return error.OutOfMemory;
    return aw.toOwnedSlice();
}

fn writeJpeg(w: *std.Io.Writer, img: Image, quality: u8) std.Io.Writer.Error!void {
    const qt: [2][64]u8 = .{ scaled(base_luma, quality), scaled(base_chroma, quality) };
    try w.writeAll(&.{ 0xFF, 0xD8 });
    try w.writeAll(&.{ 0xFF, 0xE0, 0, 16, 'J', 'F', 'I', 'F', 0, 1, 1, 0, 0, 1, 0, 1, 0, 0 });
    try w.writeAll(&.{ 0xFF, 0xDB, 0, 2 + 2 * 65 });
    for (qt, 0..) |t, id| {
        try w.writeByte(@intCast(id));
        for (zigzag) |n| try w.writeByte(t[n]);
    }
    try w.writeAll(&.{ 0xFF, 0xC0, 0, 17, 8 });
    try w.writeInt(u16, @intCast(img.h), .big);
    try w.writeInt(u16, @intCast(img.w), .big);
    try w.writeAll(&.{ 3, 1, 0x11, 0, 2, 0x11, 1, 3, 0x11, 1 });
    var dht_len: u16 = 2;
    for (specs) |s| dht_len += @intCast(1 + 16 + s.vals.len);
    try w.writeAll(&.{ 0xFF, 0xC4 });
    try w.writeInt(u16, dht_len, .big);
    for (specs) |s| {
        try w.writeByte(s.class_id);
        try w.writeAll(&s.bits);
        try w.writeAll(s.vals);
    }
    try w.writeAll(&.{ 0xFF, 0xDA, 0, 12, 3, 1, 0x00, 2, 0x11, 3, 0x11, 0, 63, 0 });

    const codes = comptime blk: {
        @setEvalBranchQuota(10_000);
        var c: [4]Codes = undefined;
        for (specs, &c) |s, *o| o.* = .of(s);
        break :blk c;
    };
    var bits: Bits = .{ .w = w };
    var prev_dc: [3]i32 = @splat(0);
    var by: u32 = 0;
    while (by < img.h) : (by += 8) {
        var bx: u32 = 0;
        while (bx < img.w) : (bx += 8) {
            var block: [3][64]f32 = undefined;
            for (0..8) |y| for (0..8) |x| {
                // Past the edge: the edge pixel again
                const sx = @min(bx + x, img.w - 1);
                const sy = @min(by + y, img.h - 1);
                const p = img.rgb[3 * (sy * img.w + sx) ..][0..3];
                const r: f32 = @floatFromInt(p[0]);
                const g: f32 = @floatFromInt(p[1]);
                const b: f32 = @floatFromInt(p[2]);
                block[0][y * 8 + x] = 0.299 * r + 0.587 * g + 0.114 * b - 128;
                block[1][y * 8 + x] = -0.168736 * r - 0.331264 * g + 0.5 * b;
                block[2][y * 8 + x] = 0.5 * r - 0.418688 * g - 0.081312 * b;
            };
            for (block, 0..) |samples, ch| {
                const t: usize = if (ch == 0) 0 else 1;
                try encodeBlock(&bits, samples, qt[t], &prev_dc[ch], codes[2 * t], codes[2 * t + 1]);
            }
        }
    }
    try bits.flush();
    try w.writeAll(&.{ 0xFF, 0xD9 });
}

fn encodeBlock(bits: *Bits, samples: [64]f32, q: [64]u8, prev_dc: *i32, dc: Codes, ac: Codes) !void {
    var coef: [64]i32 = undefined;
    for (0..8) |v| for (0..8) |u| {
        var s: f32 = 0;
        for (0..8) |y| for (0..8) |x| {
            s += samples[y * 8 + x] * cosines[x][u] * cosines[y][v];
        };
        const cu: f32 = if (u == 0) std.math.sqrt1_2 else 1;
        const cv: f32 = if (v == 0) std.math.sqrt1_2 else 1;
        coef[v * 8 + u] = @intFromFloat(@round(0.25 * cu * cv * s / @as(f32, @floatFromInt(q[v * 8 + u]))));
    };
    const diff = coef[0] - prev_dc.*;
    prev_dc.* = coef[0];
    try bits.value(dc, 0, diff);
    var run: u8 = 0;
    for (zigzag[1..]) |n| {
        const c = coef[n];
        if (c == 0) {
            run += 1;
            continue;
        }
        while (run > 15) : (run -= 16) try bits.code(ac, 0xF0);
        try bits.value(ac, run << 4, c);
        run = 0;
    }
    if (run > 0) try bits.code(ac, 0x00);
}

const cosines = blk: {
    var c: [8][8]f32 = undefined;
    for (0..8) |x| for (0..8) |u| {
        c[x][u] = @cos(@as(f32, @floatFromInt((2 * x + 1) * u)) * std.math.pi / 16);
    };
    break :blk c;
};

const Bits = struct {
    w: *std.Io.Writer,
    acc: u32 = 0,
    n: u5 = 0,

    fn put(b: *Bits, v: u32, len: u5) !void {
        var left = len;
        while (left > 0) {
            left -= 1;
            b.acc = (b.acc << 1) | ((v >> left) & 1);
            b.n += 1;
            if (b.n == 8) {
                const byte: u8 = @intCast(b.acc);
                try b.w.writeByte(byte);
                // 0xFF in the data would read as a marker
                if (byte == 0xFF) try b.w.writeByte(0);
                b.acc = 0;
                b.n = 0;
            }
        }
    }

    fn code(b: *Bits, t: Codes, sym: u8) !void {
        try b.put(t.code[sym], t.len[sym]);
    }

    /// `sym_hi` (an AC run << 4, 0 for DC) with `v`'s size, then `v` in that many bits
    fn value(b: *Bits, t: Codes, sym_hi: u8, v: i32) !void {
        const mag: u32 = @abs(v);
        const size: u5 = @intCast(32 - @clz(mag));
        try b.code(t, sym_hi | size);
        if (size == 0) return;
        const raw: u32 = if (v < 0) @bitCast(v - 1) else mag;
        try b.put(raw & ((@as(u32, 1) << size) - 1), size);
    }

    fn flush(b: *Bits) !void {
        if (b.n > 0) try b.put(0x7F, 8 - b.n);
    }
};

const Spec = struct {
    class_id: u8,
    bits: [16]u8,
    vals: []const u8,
};

const Codes = struct {
    code: [256]u16,
    len: [256]u5,

    fn of(s: Spec) Codes {
        var c: Codes = .{ .code = @splat(0), .len = @splat(0) };
        var next: u16 = 0;
        var k: usize = 0;
        for (s.bits, 1..) |count, len| {
            for (0..count) |_| {
                c.code[s.vals[k]] = next;
                c.len[s.vals[k]] = @intCast(len);
                next += 1;
                k += 1;
            }
            next <<= 1;
        }
        return c;
    }
};

fn scaled(base: [64]u8, quality: u8) [64]u8 {
    const q: u32 = std.math.clamp(quality, 1, 100);
    const s: u32 = if (q < 50) 5000 / q else 200 - 2 * q;
    var out: [64]u8 = undefined;
    for (base, &out) |b, *o| o.* = @intCast(std.math.clamp((@as(u32, b) * s + 50) / 100, 1, 255));
    return out;
}

// The tables below: ITU-T T.81 Annex K

const zigzag = [64]u8{
    0,  1,  8,  16, 9,  2,  3,  10, 17, 24, 32, 25, 18, 11, 4,  5,
    12, 19, 26, 33, 40, 48, 41, 34, 27, 20, 13, 6,  7,  14, 21, 28,
    35, 42, 49, 56, 57, 50, 43, 36, 29, 22, 15, 23, 30, 37, 44, 51,
    58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62, 63,
};

const base_luma = [64]u8{
    16, 11, 10, 16, 24,  40,  51,  61,
    12, 12, 14, 19, 26,  58,  60,  55,
    14, 13, 16, 24, 40,  57,  69,  56,
    14, 17, 22, 29, 51,  87,  80,  62,
    18, 22, 37, 56, 68,  109, 103, 77,
    24, 35, 55, 64, 81,  104, 113, 92,
    49, 64, 78, 87, 103, 121, 120, 101,
    72, 92, 95, 98, 112, 100, 103, 99,
};

const base_chroma = [64]u8{
    17, 18, 24, 47, 99, 99, 99, 99,
    18, 21, 26, 66, 99, 99, 99, 99,
    24, 26, 56, 99, 99, 99, 99, 99,
    47, 66, 99, 99, 99, 99, 99, 99,
    99, 99, 99, 99, 99, 99, 99, 99,
    99, 99, 99, 99, 99, 99, 99, 99,
    99, 99, 99, 99, 99, 99, 99, 99,
    99, 99, 99, 99, 99, 99, 99, 99,
};

const dc_vals = [_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 };

const ac_luma_vals = [_]u8{
    0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, 0x21, 0x31, 0x41, 0x06, 0x13, 0x51, 0x61, 0x07,
    0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xa1, 0x08, 0x23, 0x42, 0xb1, 0xc1, 0x15, 0x52, 0xd1, 0xf0,
    0x24, 0x33, 0x62, 0x72, 0x82, 0x09, 0x0a, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x25, 0x26, 0x27, 0x28,
    0x29, 0x2a, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49,
    0x4a, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69,
    0x6a, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89,
    0x8a, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7,
    0xa8, 0xa9, 0xaa, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6, 0xb7, 0xb8, 0xb9, 0xba, 0xc2, 0xc3, 0xc4, 0xc5,
    0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 0xd8, 0xd9, 0xda, 0xe1, 0xe2,
    0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xea, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8,
    0xf9, 0xfa,
};

const ac_chroma_vals = [_]u8{
    0x00, 0x01, 0x02, 0x03, 0x11, 0x04, 0x05, 0x21, 0x31, 0x06, 0x12, 0x41, 0x51, 0x07, 0x61, 0x71,
    0x13, 0x22, 0x32, 0x81, 0x08, 0x14, 0x42, 0x91, 0xa1, 0xb1, 0xc1, 0x09, 0x23, 0x33, 0x52, 0xf0,
    0x15, 0x62, 0x72, 0xd1, 0x0a, 0x16, 0x24, 0x34, 0xe1, 0x25, 0xf1, 0x17, 0x18, 0x19, 0x1a, 0x26,
    0x27, 0x28, 0x29, 0x2a, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48,
    0x49, 0x4a, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68,
    0x69, 0x6a, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87,
    0x88, 0x89, 0x8a, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0xa2, 0xa3, 0xa4, 0xa5,
    0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6, 0xb7, 0xb8, 0xb9, 0xba, 0xc2, 0xc3,
    0xc4, 0xc5, 0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 0xd8, 0xd9, 0xda,
    0xe2, 0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xea, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8,
    0xf9, 0xfa,
};

/// DC luma, AC luma, DC chroma, AC chroma: encodeBlock's 2 * table + (0 DC, 1 AC)
const specs = [4]Spec{
    .{ .class_id = 0x00, .bits = .{ 0, 1, 5, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0 }, .vals = &dc_vals },
    .{ .class_id = 0x10, .bits = .{ 0, 2, 1, 3, 3, 2, 4, 3, 5, 5, 4, 4, 0, 0, 1, 0x7d }, .vals = &ac_luma_vals },
    .{ .class_id = 0x01, .bits = .{ 0, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0 }, .vals = &dc_vals },
    .{ .class_id = 0x11, .bits = .{ 0, 2, 1, 2, 4, 4, 3, 4, 7, 5, 4, 4, 0, 1, 2, 0x77 }, .vals = &ac_chroma_vals },
};

comptime {
    for (specs) |s| {
        var n: usize = 0;
        for (s.bits) |b| n += b;
        std.debug.assert(n == s.vals.len);
    }
}

/// Tests: a PNG of `rgb` (w x h, colour type 2) in a stored deflate block, each row
/// filtered with `filter`: what decodePng must read back
pub fn testPng(gpa: Allocator, w: u32, h: u32, rgb: []const u8, filter: u8) ![]u8 {
    var raw: std.ArrayList(u8) = .empty;
    defer raw.deinit(gpa);
    for (0..h) |y| {
        try raw.append(gpa, filter);
        const row = rgb[y * w * 3 ..][0 .. w * 3];
        const up: ?[]const u8 = if (y > 0) rgb[(y - 1) * w * 3 ..][0 .. w * 3] else null;
        for (row, 0..) |v, i| {
            const a: u8 = if (i >= 3) row[i - 3] else 0;
            const b: u8 = if (up) |u| u[i] else 0;
            const c: u8 = if (up) |u| (if (i >= 3) u[i - 3] else 0) else 0;
            try raw.append(gpa, v -% switch (filter) {
                0 => 0,
                1 => a,
                2 => b,
                3 => @as(u8, @intCast((@as(u16, a) + b) / 2)),
                else => paeth(a, b, c),
            });
        }
    }
    var z: std.ArrayList(u8) = .empty;
    defer z.deinit(gpa);
    try z.appendSlice(gpa, &.{ 0x78, 0x01, 0x01 });
    const len: u16 = @intCast(raw.items.len);
    try z.appendSlice(gpa, &std.mem.toBytes(std.mem.nativeToLittle(u16, len)));
    try z.appendSlice(gpa, &std.mem.toBytes(std.mem.nativeToLittle(u16, ~len)));
    try z.appendSlice(gpa, raw.items);
    try z.appendSlice(gpa, &std.mem.toBytes(std.mem.nativeToBig(u32, std.hash.Adler32.hash(raw.items))));

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(gpa);
    try out.appendSlice(gpa, "\x89PNG\r\n\x1a\n");
    var ihdr: [13]u8 = undefined;
    std.mem.writeInt(u32, ihdr[0..4], w, .big);
    std.mem.writeInt(u32, ihdr[4..8], h, .big);
    ihdr[8..13].* = .{ 8, 2, 0, 0, 0 };
    for ([_]struct { []const u8, []const u8 }{ .{ "IHDR", &ihdr }, .{ "IDAT", z.items }, .{ "IEND", "" } }) |c| {
        try out.appendSlice(gpa, &std.mem.toBytes(std.mem.nativeToBig(u32, @intCast(c[1].len))));
        try out.appendSlice(gpa, c[0]);
        try out.appendSlice(gpa, c[1]);
        // CRC unchecked by decodePng
        try out.appendSlice(gpa, &.{ 0, 0, 0, 0 });
    }
    return out.toOwnedSlice(gpa);
}

test "decodePng reads every filter back" {
    const gpa = std.testing.allocator;
    var rgb: [5 * 4 * 3]u8 = undefined;
    for (&rgb, 0..) |*v, i| v.* = @intCast((i * 37 + 11) % 256);
    for (0..5) |filter| {
        const png = try testPng(gpa, 5, 4, &rgb, @intCast(filter));
        defer gpa.free(png);
        const img = try decodePng(gpa, png);
        defer img.deinit(gpa);
        try std.testing.expectEqual(5, img.w);
        try std.testing.expectEqual(4, img.h);
        try std.testing.expectEqualSlices(u8, &rgb, img.rgb);
    }
}

test "decodePng refuses what it can't read" {
    const gpa = std.testing.allocator;
    try std.testing.expectError(error.NotPng, decodePng(gpa, "GIF89a"));
    const rgb: [3]u8 = .{ 1, 2, 3 };
    const png = try testPng(gpa, 1, 1, &rgb, 0);
    defer gpa.free(png);
    // Cut inside IDAT
    try std.testing.expectError(error.Corrupt, decodePng(gpa, png[0 .. png.len - 20]));
    // Palette colour type
    const pal = try gpa.dupe(u8, png);
    defer gpa.free(pal);
    pal[8 + 8 + 9] = 3;
    try std.testing.expectError(error.Unsupported, decodePng(gpa, pal));
    // Bad filter byte
    const bad = try gpa.dupe(u8, png);
    defer gpa.free(bad);
    const idat = std.mem.find(u8, bad, "IDAT").? + 4;
    bad[idat + 7] = 9;
    try std.testing.expectError(error.Corrupt, decodePng(gpa, bad));
}

test "resize averages the area under each pixel" {
    const gpa = std.testing.allocator;
    // 4x1 to 2x1: (0, 100) and (200, 40) averaged
    var rgb = [_]u8{ 0, 0, 0, 100, 100, 100, 200, 200, 200, 40, 40, 40 };
    const out = try resize(gpa, .{ .w = 4, .h = 1, .rgb = &rgb }, 2, 1);
    defer out.deinit(gpa);
    try std.testing.expectEqualSlices(u8, &.{ 50, 50, 50, 120, 120, 120 }, out.rgb);
    // 3 to 2: the middle pixel split half and half
    var three = [_]u8{ 0, 0, 0, 90, 90, 90, 180, 180, 180 };
    const two = try resize(gpa, .{ .w = 3, .h = 1, .rgb = &three }, 2, 1);
    defer two.deinit(gpa);
    try std.testing.expectEqualSlices(u8, &.{ 30, 30, 30, 150, 150, 150 }, two.rgb);
}

test "encodeJpeg: markers, size and a flat block's few bytes" {
    const gpa = std.testing.allocator;
    const rgb = try gpa.alloc(u8, 12 * 10 * 3);
    defer gpa.free(rgb);
    @memset(rgb, 200);
    const jpg = try encodeJpeg(gpa, .{ .w = 12, .h = 10, .rgb = rgb }, 80);
    defer gpa.free(jpg);
    try std.testing.expect(std.mem.startsWith(u8, jpg, &.{ 0xFF, 0xD8, 0xFF, 0xE0 }));
    try std.testing.expect(std.mem.endsWith(u8, jpg, &.{ 0xFF, 0xD9 }));
    const sof = std.mem.find(u8, jpg, &.{ 0xFF, 0xC0 }).?;
    try std.testing.expectEqual(10, std.mem.readInt(u16, jpg[sof + 5 ..][0..2], .big));
    try std.testing.expectEqual(12, std.mem.readInt(u16, jpg[sof + 7 ..][0..2], .big));
    const sos = std.mem.find(u8, jpg, &.{ 0xFF, 0xDA }).?;
    // 2x2 blocks of three flat channels: a DC and an EOB each
    try std.testing.expect(jpg.len - sos - 14 - 2 < 20);
    // No marker inside the entropy-coded data
    const data = jpg[sos + 14 .. jpg.len - 2];
    for (data[0 .. data.len - 1], data[1..]) |a, b| try std.testing.expect(a != 0xFF or b == 0);
}

test "Bits.value: negative values as their ones' complement" {
    var buf: [8]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    var t: Codes = .{ .code = @splat(0), .len = @splat(0) };
    // Category 3 coded as the single bit 1
    t.code[3] = 1;
    t.len[3] = 1;
    var b: Bits = .{ .w = &w };
    // -5: size 3, bits 010; 5: 101
    try b.value(t, 0, -5);
    try b.value(t, 0, 5);
    try b.flush();
    try std.testing.expectEqualSlices(u8, &.{0b1010_1101}, w.buffered());
}
