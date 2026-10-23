//! Packed raw export (docs/data-safety.md "Raw archive"): what the box sends the gpu-box
//! instead of the export's SQLite file. The same rows, with bodies gunzipped, as one
//! stream the zstd binary compresses: gzip per document left zstd nothing to find (3%),
//! one stream of plain JSON halves the bytes sent. Little-endian, in order: the magic,
//! summaries, timelines, mastery, then an end record with the counts, so a cut stream
//! never reads as whole.
//!   doc:     tag 's'|'t', key, fetched_at i64, encoding u8, body
//!   mastery: tag 'm', puuid, platform (u8 1 then bytes, or 0 for NULL), fetched_at i64,
//!            champions i64, data
//!   end:     tag 'e', summaries u64, timelines u64, mastery u64, hash u64 (Wyhash of
//!            every record before it, as written)
//! bytes = u32 length then the bytes. Encoding 0: plain JSON; 1: the body as stored (it
//! did not decompress on the box), for the reader to judge

const std = @import("std");
const Io = std.Io;

pub const magic = "meiolol-rawpack 1\n";
/// Riot bodies are at most 16 MiB (riot/client.zig readBody); a corrupt length must
/// not make the reader reserve gigabytes before the hash check at the end
pub const max_field = 64 << 20;

pub const Kind = enum(u8) { summary = 's', timeline = 't', mastery = 'm', end = 'e' };
pub const Encoding = enum(u8) { plain = 0, stored = 1 };

pub const Doc = struct {
    key: []const u8,
    fetched_at: i64,
    encoding: Encoding,
    body: []const u8,
};

pub const Mastery = struct {
    puuid: []const u8,
    platform: ?[]const u8,
    fetched_at: i64,
    champions: i64,
    data: []const u8,
};

pub const Counts = struct { summaries: u64 = 0, timelines: u64 = 0, mastery: u64 = 0 };

pub const Writer = struct {
    w: *Io.Writer,
    hash: std.hash.Wyhash = .init(0),
    counts: Counts = .{},
    last: Kind = .summary,

    pub fn begin(w: *Io.Writer) !Writer {
        try w.writeAll(magic);
        return .{ .w = w };
    }

    pub fn doc(p: *Writer, kind: Kind, d: Doc) !void {
        try p.order(kind);
        try p.byte(@backingInt(kind));
        try p.bytes(d.key);
        try p.int(d.fetched_at);
        try p.byte(@backingInt(d.encoding));
        try p.bytes(d.body);
        switch (kind) {
            .summary => p.counts.summaries += 1,
            .timeline => p.counts.timelines += 1,
            else => unreachable,
        }
    }

    pub fn mastery(p: *Writer, m: Mastery) !void {
        try p.order(.mastery);
        try p.byte(@backingInt(Kind.mastery));
        try p.bytes(m.puuid);
        if (m.platform) |pl| {
            try p.byte(1);
            try p.bytes(pl);
        } else try p.byte(0);
        try p.int(m.fetched_at);
        try p.int(m.champions);
        try p.bytes(m.data);
        p.counts.mastery += 1;
    }

    pub fn end(p: *Writer) !void {
        const h = p.hash.final();
        try p.w.writeByte(@backingInt(Kind.end));
        for ([_]u64{ p.counts.summaries, p.counts.timelines, p.counts.mastery, h }) |v| {
            try p.w.writeInt(u64, v, .little);
        }
    }

    fn order(p: *Writer, kind: Kind) !void {
        if (kind != p.last and !after(p.last, kind)) return error.PackOrder;
        p.last = kind;
    }

    fn byte(p: *Writer, b: u8) !void {
        p.hash.update(&.{b});
        try p.w.writeByte(b);
    }

    fn int(p: *Writer, v: i64) !void {
        var b: [8]u8 = undefined;
        std.mem.writeInt(i64, &b, v, .little);
        p.hash.update(&b);
        try p.w.writeAll(&b);
    }

    fn bytes(p: *Writer, s: []const u8) !void {
        var b: [4]u8 = undefined;
        if (s.len > max_field) return error.PackFieldTooLong;
        std.mem.writeInt(u32, &b, @intCast(s.len), .little);
        p.hash.update(&b);
        p.hash.update(s);
        try p.w.writeAll(&b);
        try p.w.writeAll(s);
    }
};

/// summary < timeline < mastery
fn after(prev: Kind, next: Kind) bool {
    const rank = struct {
        fn f(k: Kind) u8 {
            return switch (k) {
                .summary => 0,
                .timeline => 1,
                .mastery => 2,
                .end => 3,
            };
        }
    }.f;
    return rank(next) > rank(prev);
}

pub const Record = union(enum) { summary: Doc, timeline: Doc, mastery: Mastery };

/// Records in order; null after the end record, whose counts and hash it checks. Each
/// record's slices live until the next call
pub const Reader = struct {
    r: *Io.Reader,
    gpa: std.mem.Allocator,
    buf: std.ArrayList(u8) = .empty,
    hash: std.hash.Wyhash = .init(0),
    counts: Counts = .{},
    last: Kind = .summary,
    done: bool = false,

    pub fn init(gpa: std.mem.Allocator, r: *Io.Reader) !Reader {
        const head = r.take(magic.len) catch return error.NotAPack;
        if (!std.mem.eql(u8, head, magic)) return error.NotAPack;
        return .{ .r = r, .gpa = gpa };
    }

    pub fn deinit(p: *Reader) void {
        p.buf.deinit(p.gpa);
    }

    pub fn next(p: *Reader) !?Record {
        if (p.done) return null;
        const tag = p.r.takeByte() catch return error.PackCut;
        const kind = std.enums.fromInt(Kind, tag) orelse return error.BadPack;
        if (kind == .end) {
            const h = p.hash.final();
            var v: [4]u64 = undefined;
            for (&v) |*x| x.* = p.r.takeInt(u64, .little) catch return error.PackCut;
            if (v[0] != p.counts.summaries or v[1] != p.counts.timelines or v[2] != p.counts.mastery)
                return error.PackCountsDiffer;
            if (v[3] != h) return error.PackHashDiffers;
            p.done = true;
            return null;
        }
        if (kind != p.last and !after(p.last, kind)) return error.PackOrder;
        p.last = kind;
        p.hash.update(&.{tag});
        p.buf.clearRetainingCapacity();
        switch (kind) {
            .summary, .timeline => {
                const key = try p.field();
                const fetched_at = try p.int();
                const enc = try p.byte();
                const body = try p.field();
                const d: Doc = .{
                    .key = p.buf.items[key.start..key.end],
                    .fetched_at = fetched_at,
                    .encoding = std.enums.fromInt(Encoding, enc) orelse return error.BadPack,
                    .body = p.buf.items[body.start..body.end],
                };
                if (kind == .summary) {
                    p.counts.summaries += 1;
                    return .{ .summary = d };
                }
                p.counts.timelines += 1;
                return .{ .timeline = d };
            },
            .mastery => {
                const puuid = try p.field();
                const has_platform = try p.byte();
                const platform = if (has_platform == 1) try p.field() else null;
                const fetched_at = try p.int();
                const champions = try p.int();
                const data = try p.field();
                p.counts.mastery += 1;
                return .{ .mastery = .{
                    .puuid = p.buf.items[puuid.start..puuid.end],
                    .platform = if (platform) |s| p.buf.items[s.start..s.end] else null,
                    .fetched_at = fetched_at,
                    .champions = champions,
                    .data = p.buf.items[data.start..data.end],
                } };
            },
            .end => unreachable,
        }
    }

    const Span = struct { start: usize, end: usize };

    fn byte(p: *Reader) !u8 {
        const b = p.r.takeByte() catch return error.PackCut;
        p.hash.update(&.{b});
        return b;
    }

    fn int(p: *Reader) !i64 {
        const b = p.r.takeArray(8) catch return error.PackCut;
        p.hash.update(b);
        return std.mem.readInt(i64, b, .little);
    }

    /// Appended to buf: a slice into it would move as buf grows
    fn field(p: *Reader) !Span {
        const lb = p.r.takeArray(4) catch return error.PackCut;
        p.hash.update(lb);
        const len = std.mem.readInt(u32, lb, .little);
        if (len > max_field) return error.BadPack;
        const start = p.buf.items.len;
        try p.buf.resize(p.gpa, start + len);
        p.r.readSliceAll(p.buf.items[start..]) catch return error.PackCut;
        p.hash.update(p.buf.items[start..]);
        return .{ .start = start, .end = start + len };
    }
};

const testing = std.testing;

test "pack round trip, and a cut or edited pack fails" {
    var out: Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    var w = try Writer.begin(&out.writer);
    try w.doc(.summary, .{ .key = "EUW1_1", .fetched_at = 10, .encoding = .plain, .body = "{\"a\":1}" });
    try w.doc(.summary, .{ .key = "EUW1_2", .fetched_at = 11, .encoding = .stored, .body = "" });
    try w.doc(.timeline, .{ .key = "EUW1_1", .fetched_at = 12, .encoding = .plain, .body = "{}" });
    try w.mastery(.{ .puuid = "p1", .platform = null, .fetched_at = 13, .champions = 2, .data = "\x00\x01" });
    try w.mastery(.{ .puuid = "p2", .platform = "EUW1", .fetched_at = 14, .champions = 0, .data = "" });
    try testing.expectError(error.PackOrder, w.doc(.summary, .{ .key = "x", .fetched_at = 0, .encoding = .plain, .body = "" }));
    try w.end();
    const bytes = out.written();

    var in: Io.Reader = .fixed(bytes);
    var r = try Reader.init(testing.allocator, &in);
    defer r.deinit();
    const a = (try r.next()).?.summary;
    try testing.expectEqualStrings("EUW1_1", a.key);
    try testing.expectEqualStrings("{\"a\":1}", a.body);
    try testing.expectEqual(Encoding.stored, (try r.next()).?.summary.encoding);
    try testing.expectEqual(@as(i64, 12), (try r.next()).?.timeline.fetched_at);
    const m = (try r.next()).?.mastery;
    try testing.expectEqual(@as(?[]const u8, null), m.platform);
    try testing.expectEqualStrings("\x00\x01", m.data);
    try testing.expectEqualStrings("EUW1", (try r.next()).?.mastery.platform.?);
    try testing.expectEqual(@as(?Record, null), try r.next());

    var cut: Io.Reader = .fixed(bytes[0 .. bytes.len - 9]);
    var rc = try Reader.init(testing.allocator, &cut);
    defer rc.deinit();
    const err = while (true) {
        _ = rc.next() catch |e| break e;
    };
    try testing.expectEqual(error.PackCut, err);

    const edited = try testing.allocator.dupe(u8, bytes);
    defer testing.allocator.free(edited);
    edited[std.mem.find(u8, edited, "\"a\":1").? + 4] = '2';
    var ein: Io.Reader = .fixed(edited);
    var re = try Reader.init(testing.allocator, &ein);
    defer re.deinit();
    const eerr = while (true) {
        _ = (re.next() catch |e| break e) orelse break error.NoError;
    };
    try testing.expectEqual(error.PackHashDiffers, eerr);
}

test "every cut is PackCut; a corrupt length fails before allocating" {
    const gpa = testing.allocator;
    var out: Io.Writer.Allocating = .init(gpa);
    defer out.deinit();
    var w = try Writer.begin(&out.writer);
    try w.doc(.summary, .{ .key = "EUW1_1", .fetched_at = 10, .encoding = .plain, .body = "{\"a\":1}" });
    try w.mastery(.{ .puuid = "p2", .platform = "EUW1", .fetched_at = 14, .champions = 0, .data = "" });
    try w.end();
    const bytes = out.written();
    for (magic.len..bytes.len) |len| {
        var in: Io.Reader = .fixed(bytes[0..len]);
        var r = try Reader.init(gpa, &in);
        defer r.deinit();
        const err = while (true) {
            _ = (r.next() catch |e| break e) orelse break error.NoError;
        };
        try testing.expectEqual(error.PackCut, err);
    }

    const bad = try gpa.dupe(u8, bytes);
    defer gpa.free(bad);
    // The body's length: after tag, key (4 + 6), fetched_at and encoding
    std.mem.writeInt(u32, bad[magic.len + 1 + 4 + 6 + 8 + 1 ..][0..4], 0xF000_0000, .little);
    var in: Io.Reader = .fixed(bad);
    var r = try Reader.init(gpa, &in);
    defer r.deinit();
    try testing.expectError(error.BadPack, r.next());
    try testing.expect(r.buf.capacity < 1024);
}
