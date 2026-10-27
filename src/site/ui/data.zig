//! Binary data for islands: a state the server didn't render (another role, a fuller
//! list) comes as a small file encoded from the same Zig struct the component reads, so
//! std.json never ships in ui.wasm. Little-endian, lengths as u32, a fingerprint of the
//! type up front: a stale file against a new ui.wasm fails to decode instead of
//! misreading. Decoded strings point into the input bytes, which must outlive the value.
//!
//! Types: ints, floats, bools, enums, optionals, arrays, slices, structs, tagged unions
//! (void payloads too).
const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Error = error{ Truncated, BadValue, WrongType, OutOfMemory };

/// Changes when a field, its name, type or order changes
pub fn fingerprint(comptime T: type) u32 {
    return comptime @truncate(std.hash.Wyhash.hash(0, signature(T)));
}

fn signature(comptime T: type) []const u8 {
    comptime {
        @setEvalBranchQuota(100_000);
        return switch (@typeInfo(T)) {
            .int, .float, .bool, .void => @typeName(T),
            .@"enum" => |e| blk: {
                var s: []const u8 = "enum(" ++ @typeName(e.tag_type) ++ "){";
                for (e.field_names, e.field_values) |n, v| s = s ++ n ++ std.fmt.comptimePrint("={d},", .{v});
                break :blk s ++ "}";
            },
            .optional => |o| "?" ++ signature(o.child),
            .array => |a| std.fmt.comptimePrint("[{d}]", .{a.len}) ++ signature(a.child),
            .pointer => |p| "[]" ++ signature(p.child),
            .@"struct" => blk: {
                var s: []const u8 = "{";
                for (std.meta.fieldNames(T)) |f| s = s ++ f ++ ":" ++ signature(@FieldType(T, f)) ++ ",";
                break :blk s ++ "}";
            },
            .@"union" => blk: {
                var s: []const u8 = "union{";
                for (std.meta.fieldNames(T)) |f| s = s ++ f ++ ":" ++ signature(@FieldType(T, f)) ++ ",";
                break :blk s ++ "}";
            },
            else => @compileError("data: can't encode " ++ @typeName(T)),
        };
    }
}

/// `v` with its fingerprint in front, appended to `out`
pub fn encode(a: Allocator, comptime T: type, v: T, out: *std.ArrayList(u8)) Allocator.Error!void {
    try put(a, out, u32, fingerprint(T));
    try put(a, out, T, v);
}

/// A value of `T` from bytes written by `encode`; slices are allocated with `a` (an arena),
/// except `[]const u8`, which point into `bytes`: keep them as long as the value
pub fn decode(a: Allocator, comptime T: type, bytes: []const u8) Error!T {
    var r: Reader = .{ .bytes = bytes, .a = a };
    if (r.read(u32) != fingerprint(T)) return r.err orelse error.WrongType;
    const v = r.read(T);
    if (r.err) |e| return e;
    if (r.i != bytes.len) return error.BadValue;
    return v;
}

/// The first fields of a `T` written by `encode`, as `Head` (the same names and types in
/// order), and the bytes after them: a reader of the head alone needs no decoder for the
/// rest. Slices point into `bytes`; `Head` holds no other slices
pub fn decodeHead(comptime T: type, comptime Head: type, bytes: []const u8) Error!struct { head: Head, rest: []const u8 } {
    comptime {
        const tf = std.meta.fieldNames(T);
        for (std.meta.fieldNames(Head), 0..) |f, i| {
            if (!std.mem.eql(u8, f, tf[i]) or @FieldType(Head, f) != @FieldType(T, f)) @compileError("data: " ++ @typeName(Head) ++ " isn't the start of " ++ @typeName(T));
        }
    }
    var r: Reader = .{ .bytes = bytes, .a = std.mem.Allocator.failing };
    if (r.read(u32) != fingerprint(T)) return r.err orelse error.WrongType;
    const v = r.read(Head);
    if (r.err) |e| return e;
    return .{ .head = v, .rest = bytes[r.i..] };
}

fn put(a: Allocator, out: *std.ArrayList(u8), comptime T: type, v: T) Allocator.Error!void {
    switch (@typeInfo(T)) {
        .int => |i| {
            const U = @Int(.unsigned, (i.bits + 7) / 8 * 8);
            var b: [@sizeOf(U)]u8 = undefined;
            std.mem.writeInt(U, &b, @bitCast(@as(@Int(i.signedness, @bitSizeOf(U)), v)), .little);
            try out.appendSlice(a, &b);
        },
        .float => |f| try put(a, out, @Int(.unsigned, f.bits), @bitCast(v)),
        .bool => try out.append(a, @intFromBool(v)),
        .void => {},
        .@"enum" => |e| try put(a, out, e.tag_type, @backingInt(v)),
        .optional => |o| {
            try out.append(a, @intFromBool(v != null));
            if (v) |x| try put(a, out, o.child, x);
        },
        .array => |arr| for (v) |x| try put(a, out, arr.child, x),
        .pointer => |p| {
            comptime if (p.size != .slice) @compileError("data: slices only, not " ++ @typeName(T));
            try put(a, out, u32, @intCast(v.len));
            if (p.child == u8) return out.appendSlice(a, v);
            for (v) |x| try put(a, out, p.child, x);
        },
        .@"struct" => inline for (comptime std.meta.fieldNames(T)) |f| try put(a, out, @FieldType(T, f), @field(v, f)),
        .@"union" => |u| {
            comptime if (u.tag_type == null) @compileError("data: unions need a tag");
            const tag = std.meta.activeTag(v);
            try put(a, out, u.tag_type.?, tag);
            switch (v) {
                inline else => |x| try put(a, out, @TypeOf(x), x),
            }
        },
        else => @compileError("data: can't encode " ++ @typeName(T)),
    }
}

/// Errors are sticky and checked once at the end: no branch per field (ui.wasm size). After
/// one, reads give zeros and empty slices
const Reader = struct {
    bytes: []const u8,
    i: usize = 0,
    a: Allocator,
    err: ?Error = null,

    fn fail(r: *Reader, e: Error) void {
        if (r.err == null) r.err = e;
        r.i = r.bytes.len;
    }

    fn take(r: *Reader, n: usize) []const u8 {
        if (n > r.bytes.len - r.i) {
            r.fail(error.Truncated);
            return "";
        }
        defer r.i += n;
        return r.bytes[r.i..][0..n];
    }

    /// `n` bytes little-endian; one function for every int width
    noinline fn word(r: *Reader, n: u8) u64 {
        const b = r.take(n);
        var x: u64 = 0;
        for (b, 0..) |c, k| x |= @as(u64, c) << @intCast(8 * k);
        return x;
    }

    fn read(r: *Reader, comptime T: type) T {
        switch (@typeInfo(T)) {
            .int => |i| {
                const U = @Int(.unsigned, (i.bits + 7) / 8 * 8);
                const u: U = @truncate(r.word(@sizeOf(U)));
                const wide: @Int(i.signedness, @bitSizeOf(U)) = @bitCast(u);
                return std.math.cast(T, wide) orelse {
                    r.fail(error.BadValue);
                    return 0;
                };
            },
            .float => |f| return @bitCast(r.read(@Int(.unsigned, f.bits))),
            .void => return {},
            .bool => {
                const x = r.read(u8);
                if (x > 1) r.fail(error.BadValue);
                return x == 1;
            },
            .@"enum" => |e| {
                const x = r.read(e.tag_type);
                if (comptime dense(e)) {
                    if (x < e.field_names.len) return @fromBackingInt(@intCast(x));
                } else if (std.enums.fromInt(T, x)) |v| return v;
                r.fail(error.BadValue);
                return @fromBackingInt(@intCast(e.field_values[0]));
            },
            .optional => |o| return if (r.read(bool)) r.read(o.child) else null,
            .array => |arr| {
                var v: T = undefined;
                for (&v) |*x| x.* = r.read(arr.child);
                return v;
            },
            .pointer => |p| {
                const n = r.read(u32);
                if (p.child == u8) return r.take(n);
                // Every element takes a byte or more: a bad length can't ask for more
                // memory than the file is long
                if (n > r.bytes.len - r.i) {
                    r.fail(error.Truncated);
                    return &.{};
                }
                const items = r.a.alloc(p.child, n) catch {
                    r.fail(error.OutOfMemory);
                    return &.{};
                };
                for (items) |*x| x.* = r.read(p.child);
                return items;
            },
            .@"struct" => {
                var v: T = undefined;
                inline for (comptime std.meta.fieldNames(T)) |f| @field(v, f) = r.read(@FieldType(T, f));
                return v;
            },
            .@"union" => |u| {
                const tag = r.read(u.tag_type.?);
                switch (tag) {
                    inline else => |t| return @unionInit(T, @tagName(t), r.read(@FieldType(T, @tagName(t)))),
                }
            },
            else => @compileError("data: can't decode " ++ @typeName(T)),
        }
    }

    /// Values 0, 1, 2 ... in order: a range check stands for the lookup
    fn dense(comptime e: std.lang.Type.Enum) bool {
        if (e.mode != .exhaustive) return false;
        for (e.field_values, 0..) |v, k| if (v != k) return false;
        return true;
    }
};

const testing = std.testing;

const Champ = struct {
    name: []const u8,
    role: enum(u8) { top, jungle, mid, bot, support },
    games: u32,
    win: f32,
    change: ?f32 = null,
    spark: [3]i16,
    seen: union(enum) { never, at: u32 },
    off: bool,
};

test "a champion list round-trips" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var out: std.ArrayList(u8) = .empty;
    const rows = [_]Champ{
        .{ .name = "Kai'Sa", .role = .bot, .games = 9000, .win = 51.2, .spark = .{ -3, 0, 7 }, .seen = .{ .at = 5 }, .off = false },
        .{ .name = "Ahri", .role = .mid, .games = 12, .win = 48, .change = -1.5, .spark = .{ 0, 0, 0 }, .seen = .never, .off = true },
    };
    try encode(a, []const Champ, &rows, &out);
    const back = try decode(a, []const Champ, out.items);
    try testing.expectEqual(@as(usize, 2), back.len);
    try testing.expectEqualStrings("Kai'Sa", back[0].name);
    try testing.expectEqual(rows[0].seen, back[0].seen);
    try testing.expectEqual(rows[1].change, back[1].change);
    try testing.expectEqual(rows[0].spark, back[0].spark);
    try testing.expectEqual(rows[1].role, back[1].role);
    try testing.expectEqual(@as(?f32, null), back[0].change);
}

test "a head without the rest's decoder" {
    const T = struct { n: u8, name: []const u8, rest: []const u16 };
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try encode(testing.allocator, T, .{ .n = 3, .name = "Ahri", .rest = &.{ 1, 2 } }, &out);
    const got = try decodeHead(T, struct { n: u8, name: []const u8 }, out.items);
    try testing.expectEqual(3, got.head.n);
    try testing.expectEqualStrings("Ahri", got.head.name);
    try testing.expectEqualSlices(u8, &.{ 2, 0, 0, 0, 1, 0, 2, 0 }, got.rest);
    try testing.expectError(error.WrongType, decodeHead(struct { n: u8 }, struct { n: u8 }, out.items));
}

test "a stale, cut or damaged file fails to decode" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var out: std.ArrayList(u8) = .empty;
    try encode(a, []const u32, &.{ 1, 2, 3 }, &out);
    try testing.expectError(error.WrongType, decode(a, []const i32, out.items));
    try testing.expectError(error.Truncated, decode(a, []const u32, out.items[0 .. out.items.len - 1]));
    var long = try out.clone(a);
    try long.append(a, 0);
    try testing.expectError(error.BadValue, decode(a, []const u32, long.items));
    // A huge length is refused before anything is allocated
    @memset(out.items[4..8], 0xff);
    try testing.expectError(error.Truncated, decode(a, []const u32, out.items));
}

test "fuzz: decoding never crashes" {
    try testing.fuzz({}, struct {
        fn one(_: void, s: *testing.Smith) anyerror!void {
            var buf: [256]u8 = undefined;
            const n = s.slice(&buf);
            var arena: std.heap.ArenaAllocator = .init(testing.allocator);
            defer arena.deinit();
            var bytes = buf[0..n];
            if (bytes.len >= 4) std.mem.writeInt(u32, bytes[0..4], fingerprint([]const Champ), .little);
            _ = decode(arena.allocator(), []const Champ, bytes) catch {};
        }
    }.one, .{});
}
