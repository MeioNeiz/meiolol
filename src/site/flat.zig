//! Plain data to bytes and back, for the renderer's views file (site.Loaded.writeViews):
//! ints, floats, bools, enums, optionals, arrays, slices, structs and tagged unions,
//! little-endian, slices length-prefixed. No pointers but slices, so nothing points
//! between values. `fingerprint` hashes a type's shape: a binary whose types differ
//! (a deploy that changed them) refuses the bytes instead of misreading them

const std = @import("std");
const Reader = std.Io.Reader;
const Writer = std.Io.Writer;

pub const ReadError = Reader.Error || std.mem.Allocator.Error || error{Corrupt};

/// Field names and types all the way down; enum tags by name and value
pub fn fingerprint(comptime T: type) u64 {
    return comptime std.hash.Wyhash.hash(0, shape(T));
}

fn shape(comptime T: type) []const u8 {
    @setEvalBranchQuota(100_000);
    return switch (@typeInfo(T)) {
        .void, .bool, .int, .float => @typeName(T),
        .@"enum" => |e| blk: {
            var s: []const u8 = "enum(" ++ @typeName(e.tag_type) ++ "){";
            for (e.field_names, e.field_values) |name, value| s = s ++ std.fmt.comptimePrint("{s}={d},", .{ name, value });
            break :blk s ++ "}";
        },
        .optional => |o| "?" ++ shape(o.child),
        .array => |a| std.fmt.comptimePrint("[{d}]", .{a.len}) ++ shape(a.child),
        .pointer => |p| if (p.size == .slice and p.sentinel() == null) "[]" ++ shape(p.child) else unsupported(T),
        .@"struct" => |s| blk: {
            var out: []const u8 = "struct{";
            for (s.field_names, s.field_types, s.field_attrs) |name, F, attrs| {
                if (!attrs.@"comptime") out = out ++ name ++ ":" ++ shape(F) ++ ",";
            }
            break :blk out ++ "}";
        },
        .@"union" => |u| blk: {
            if (u.tag_type == null) unsupported(T);
            var out: []const u8 = "union(" ++ shape(u.tag_type.?) ++ "){";
            for (u.field_names, u.field_types) |name, F| out = out ++ name ++ ":" ++ shape(F) ++ ",";
            break :blk out ++ "}";
        },
        else => unsupported(T),
    };
}

fn unsupported(comptime T: type) noreturn {
    @compileError("flat: no encoding for " ++ @typeName(T));
}

/// Ints go out in whole bytes: u1 as a byte, usize as 8
fn Wide(comptime info: std.lang.Type.Int) type {
    return @Int(info.signedness, (info.bits + 7) / 8 * 8);
}

pub fn write(w: *Writer, value: anytype) Writer.Error!void {
    const T = @TypeOf(value);
    switch (@typeInfo(T)) {
        .void => {},
        .bool => try w.writeByte(@intFromBool(value)),
        .int => |i| try w.writeInt(Wide(i), value, .little),
        .float => |f| try w.writeInt(@Int(.unsigned, f.bits), @bitCast(value), .little),
        .@"enum" => try write(w, @backingInt(value)),
        .optional => if (value) |v| {
            try w.writeByte(1);
            try write(w, v);
        } else try w.writeByte(0),
        .array => for (value) |v| try write(w, v),
        .pointer => |p| {
            if (p.size != .slice) unsupported(T);
            try w.writeInt(u64, value.len, .little);
            if (p.child == u8) return w.writeAll(value);
            for (value) |v| try write(w, v);
        },
        .@"struct" => |s| inline for (s.field_names, s.field_attrs) |name, attrs| {
            if (!attrs.@"comptime") try write(w, @field(value, name));
        },
        .@"union" => |u| {
            const tag: u.tag_type.? = value;
            try write(w, tag);
            switch (value) {
                inline else => |v| try write(w, v),
            }
        },
        else => unsupported(T),
    }
}

/// As `write` wrote it; slices allocated in `arena`
pub fn read(comptime T: type, r: *Reader, arena: std.mem.Allocator) ReadError!T {
    switch (@typeInfo(T)) {
        .void => return {},
        .bool => return switch (try r.takeByte()) {
            0 => false,
            1 => true,
            else => error.Corrupt,
        },
        .int => |i| return std.math.cast(T, try r.takeInt(Wide(i), .little)) orelse error.Corrupt,
        .float => |f| return @bitCast(try r.takeInt(@Int(.unsigned, f.bits), .little)),
        .@"enum" => |e| return std.enums.fromInt(T, try read(e.tag_type, r, arena)) orelse error.Corrupt,
        .optional => |o| return switch (try r.takeByte()) {
            0 => null,
            1 => try read(o.child, r, arena),
            else => error.Corrupt,
        },
        .array => |a| {
            var out: T = undefined;
            for (&out) |*v| v.* = try read(a.child, r, arena);
            return out;
        },
        .pointer => |p| {
            if (p.size != .slice) unsupported(T);
            const len = std.math.cast(usize, try r.takeInt(u64, .little)) orelse return error.Corrupt;
            // A bad length would ask for the moon: more than the rest of a sane file
            if (len > 1 << 32) return error.Corrupt;
            const out = try arena.alloc(p.child, len);
            if (p.child == u8) {
                try r.readSliceAll(out);
            } else for (out) |*v| v.* = try read(p.child, r, arena);
            return out;
        },
        .@"struct" => |s| {
            var out: T = undefined;
            inline for (s.field_names, s.field_types, s.field_attrs) |name, F, attrs| {
                if (!attrs.@"comptime") @field(out, name) = try read(F, r, arena);
            }
            return out;
        },
        .@"union" => |u| {
            const tag = try read(u.tag_type.?, r, arena);
            switch (tag) {
                inline else => |t| return @unionInit(T, @tagName(t), try read(@FieldType(T, @tagName(t)), r, arena)),
            }
        },
        else => unsupported(T),
    }
}

const testing = std.testing;

test "round trip" {
    const Kind = enum(u8) { a, b = 7 };
    const U = union(enum) { none, n: i16, s: []const u8 };
    const T = struct {
        flag: bool,
        small: u1,
        size: usize,
        neg: i64,
        x: f64,
        kind: Kind,
        maybe: ?u32,
        missing: ?[]const u8,
        pair: [2]i16,
        bytes: []const u8,
        list: []const struct { name: []const u8, k: Kind },
        u: [3]U,
    };
    const want: T = .{
        .flag = true,
        .small = 1,
        .size = 1 << 40,
        .neg = -5,
        .x = 0.1,
        .kind = .b,
        .maybe = 9,
        .missing = null,
        .pair = .{ -1, 2 },
        .bytes = "\x00\xffbinary",
        .list = &.{ .{ .name = "Kai'Sa", .k = .a }, .{ .name = "", .k = .b } },
        .u = .{ .none, .{ .n = -3 }, .{ .s = "x" } },
    };
    var aw: Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    try write(&aw.writer, want);
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var r: Reader = .fixed(aw.written());
    try testing.expectEqualDeep(want, try read(T, &r, arena.allocator()));
    try testing.expectEqual(0, r.bufferedLen());

    var short: Reader = .fixed(aw.written()[0 .. aw.written().len - 1]);
    try testing.expectError(error.EndOfStream, read(T, &short, arena.allocator()));
    var bad = try testing.allocator.dupe(u8, aw.written());
    defer testing.allocator.free(bad);
    bad[0] = 2;
    var corrupt: Reader = .fixed(bad);
    try testing.expectError(error.Corrupt, read(T, &corrupt, arena.allocator()));
}

test fingerprint {
    const A = struct { x: u32, y: []const u8 };
    const B = struct { x: u32, z: []const u8 };
    const C = struct { x: u16, y: []const u8 };
    const E1 = enum { a, b };
    const E2 = enum { a, c };
    try testing.expectEqual(fingerprint(A), fingerprint(struct { x: u32, y: []const u8 }));
    try testing.expect(fingerprint(A) != fingerprint(B));
    try testing.expect(fingerprint(A) != fingerprint(C));
    try testing.expect(fingerprint(E1) != fingerprint(E2));
}
