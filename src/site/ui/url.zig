//! State worth sharing or restoring with Back, as URL fragment pairs, from one struct
//! per island: `role=mid&sort=games&q=kai%27sa`. Only fields that differ from the
//! struct's defaults are written, so the default state is the bare page URL. Reading
//! starts from the defaults and ignores unknown keys (another island's) and bad values,
//! so a hand-edited or old link still opens.
//!
//!     const Url = struct { role: ?Role = null, sort: Key = .win, desc: bool = true, q: Str(24) = .{} };
//!     try url.write(Url, state, w);
//!     const s = url.read(Url, location_hash);
//!
//! Field types: ints, bools, enums (tag names), optionals of these (null is `key=`),
//! unsigned int arrays (`r=1200-1800`) and `Str(n)` for typed text. Two islands with the
//! same field names tell them apart by `pub const prefix = "opp-"` on one's struct.
const std = @import("std");
const Writer = std.Io.Writer;

/// Text up to `cap` bytes, kept inline so a state struct stays plain data
pub fn Str(comptime cap: u8) type {
    return struct {
        buf: [cap]u8 = undefined,
        len: u8 = 0,

        const S = @This();
        pub const is_url_str = {};

        pub fn slice(s: *const S) []const u8 {
            return s.buf[0..s.len];
        }

        /// Cut at `cap`, never inside a UTF-8 sequence
        pub fn set(s: *S, v: []const u8) void {
            var n: usize = @min(v.len, cap);
            if (n < v.len) while (n > 0 and v[n] & 0xc0 == 0x80) {
                n -= 1;
            };
            @memcpy(s.buf[0..n], v[0..n]);
            s.len = @intCast(n);
        }

        pub fn eql(s: *const S, o: *const S) bool {
            return std.mem.eql(u8, s.slice(), o.slice());
        }
    };
}

fn isStr(comptime T: type) bool {
    return @typeInfo(T) == .@"struct" and @hasDecl(T, "is_url_str");
}

/// `v`'s non-default fields as `k=v` pairs joined by `&`, no leading `#`
fn prefix(comptime T: type) []const u8 {
    return if (@hasDecl(T, "prefix")) T.prefix else "";
}

pub fn write(comptime T: type, v: T, w: *Writer) Writer.Error!void {
    const d: T = .{};
    var first = true;
    inline for (comptime std.meta.fieldNames(T)) |f| {
        const x = @field(v, f);
        if (!same(@TypeOf(x), x, @field(d, f))) {
            if (!first) try w.writeByte('&');
            first = false;
            try w.writeAll(comptime prefix(T) ++ f ++ "=");
            try value(@TypeOf(x), x, w);
        }
    }
}

fn same(comptime V: type, a: V, b: V) bool {
    if (comptime isStr(V)) return a.eql(&b);
    return switch (@typeInfo(V)) {
        .array => std.mem.eql(@typeInfo(V).array.child, &a, &b),
        // Str's bytes past its length are undefined: compare what it holds
        .optional => |o| if (a == null or b == null) a == null and b == null else same(o.child, a.?, b.?),
        else => std.meta.eql(a, b),
    };
}

fn value(comptime V: type, x: V, w: *Writer) Writer.Error!void {
    if (comptime isStr(V)) return escape(x.slice(), w);
    switch (@typeInfo(V)) {
        .int => try w.print("{d}", .{x}),
        .bool => try w.writeByte(if (x) '1' else '0'),
        .@"enum" => try w.writeAll(@tagName(x)),
        .optional => |o| if (x) |y| try value(o.child, y, w),
        .array => |a| {
            comptime if (@typeInfo(a.child) != .int or @typeInfo(a.child).int.signedness != .unsigned) {
                @compileError("url: arrays of unsigned ints only (`-` joins them)");
            };
            for (x, 0..) |y, i| {
                if (i > 0) try w.writeByte('-');
                try w.print("{d}", .{y});
            }
        },
        else => @compileError("url: can't write " ++ @typeName(V)),
    }
}

/// Unreserved characters as they are, the rest as %XX: safe in a fragment and in a link
fn escape(s: []const u8, w: *Writer) Writer.Error!void {
    for (s) |c| switch (c) {
        'a'...'z', 'A'...'Z', '0'...'9', '-', '.', '_', '~' => try w.writeByte(c),
        else => try w.print("%{X:0>2}", .{c}),
    };
}

/// The state in `s` (a fragment or query, with or without its `#` or `?`); fields not
/// there, or not readable, keep their defaults
pub fn read(comptime T: type, s: []const u8) T {
    var v: T = .{};
    const body = if (s.len > 0 and (s[0] == '#' or s[0] == '?')) s[1..] else s;
    var it = std.mem.tokenizeScalar(u8, body, '&');
    while (it.next()) |kv| {
        const eq = std.mem.findScalar(u8, kv, '=') orelse continue;
        const k = kv[0..eq];
        inline for (comptime std.meta.fieldNames(T)) |f| {
            if (std.mem.eql(u8, k, comptime prefix(T) ++ f)) {
                var buf: [256]u8 = undefined;
                const raw = unescape(kv[eq + 1 ..], &buf);
                if (parse(@FieldType(T, f), raw)) |x| @field(v, f) = x;
            }
        }
    }
    return v;
}

fn parse(comptime V: type, s: []const u8) ?V {
    if (comptime isStr(V)) {
        var x: V = .{};
        x.set(s);
        return x;
    }
    return switch (@typeInfo(V)) {
        .int => std.fmt.parseInt(V, s, 10) catch null,
        .bool => if (std.mem.eql(u8, s, "1")) true else if (std.mem.eql(u8, s, "0")) false else null,
        .@"enum" => std.meta.stringToEnum(V, s),
        .optional => |o| if (s.len == 0) @as(V, null) else if (parse(o.child, s)) |y| @as(V, y) else null,
        .array => |a| blk: {
            var x: V = undefined;
            var parts = std.mem.splitScalar(u8, s, '-');
            for (&x) |*y| y.* = std.fmt.parseInt(a.child, parts.next() orelse break :blk null, 10) catch break :blk null;
            break :blk if (parts.next() == null) x else null;
        },
        else => @compileError("url: can't read " ++ @typeName(V)),
    };
}

/// %XX decoded (and `+` left as is: we never write it), cut at `buf`'s length
fn unescape(s: []const u8, buf: []u8) []const u8 {
    var n: usize = 0;
    var i: usize = 0;
    while (i < s.len and n < buf.len) : (n += 1) {
        if (s[i] == '%' and i + 3 <= s.len) {
            if (std.fmt.parseInt(u8, s[i + 1 .. i + 3], 16)) |c| {
                buf[n] = c;
                i += 3;
                continue;
            } else |_| {}
        }
        buf[n] = s[i];
        i += 1;
    }
    return buf[0..n];
}

const testing = std.testing;

const Role = enum { top, jungle, mid, bot, support };
const State = struct {
    role: ?Role = null,
    sort: enum { win, games, pick } = .win,
    desc: bool = true,
    min: u32 = 1500,
    range: ?[2]u32 = null,
    q: Str(24) = .{},
};

fn written(comptime T: type, v: T, buf: []u8) []const u8 {
    var w: Writer = .fixed(buf);
    write(T, v, &w) catch unreachable;
    return w.buffered();
}

test "defaults write nothing; changes write only themselves and read back" {
    var buf: [128]u8 = undefined;
    try testing.expectEqualStrings("", written(State, .{}, &buf));
    var s: State = .{ .role = .mid, .sort = .games, .desc = false, .range = .{ 1200, 1800 } };
    s.q.set("kai'sa & co");
    const out = written(State, s, &buf);
    try testing.expectEqualStrings("role=mid&sort=games&desc=0&range=1200-1800&q=kai%27sa%20%26%20co", out);
    const back = read(State, out);
    try testing.expectEqual(s.role, back.role);
    try testing.expectEqual(s.sort, back.sort);
    try testing.expectEqual(s.desc, back.desc);
    try testing.expectEqual(s.min, back.min);
    try testing.expectEqual(s.range, back.range);
    try testing.expectEqualStrings("kai'sa & co", back.q.slice());
}

test "a prefix keeps two islands' fields apart" {
    const Opp = struct {
        pub const prefix = "opp-";
        sort: u8 = 0,
        desc: bool = true,
    };
    const Main = struct { sort: u8 = 0 };
    var buf: [64]u8 = undefined;
    try testing.expectEqualStrings("opp-sort=3", written(Opp, .{ .sort = 3 }, &buf));
    try testing.expectEqual(@as(u8, 3), read(Opp, "#sort=1&opp-sort=3").sort);
    try testing.expectEqual(@as(u8, 1), read(Main, "#sort=1&opp-sort=3").sort);
}

test "bad values and unknown keys keep the defaults" {
    const s = read(State, "#role=fill&sort=&min=-3&range=5-x&desc=yes&other=1&q=%zz&=&&");
    try testing.expectEqual(@as(?Role, null), s.role);
    try testing.expectEqual(@as(State, .{}).sort, s.sort);
    try testing.expectEqual(@as(u32, 1500), s.min);
    try testing.expectEqual(@as(?[2]u32, null), s.range);
    try testing.expect(s.desc);
    try testing.expectEqualStrings("%zz", s.q.slice());
    // A non-null default is cleared with `key=`
    const D = struct { role: ?Role = .top };
    var buf: [32]u8 = undefined;
    try testing.expectEqualStrings("role=", written(D, .{ .role = null }, &buf));
    try testing.expectEqual(@as(?Role, null), read(D, "role=").role);
}

test "text is cut at its cap on a character boundary" {
    var q: Str(4) = .{};
    q.set("abé!");
    try testing.expectEqualStrings("abé", q.slice());
    q.set("abcé");
    try testing.expectEqualStrings("abc", q.slice());
}

test "fuzz: any fragment reads into a valid state" {
    try testing.fuzz({}, struct {
        fn one(_: void, sm: *testing.Smith) anyerror!void {
            var buf: [200]u8 = undefined;
            const n = sm.slice(&buf);
            const s = read(State, buf[0..n]);
            var out: [512]u8 = undefined;
            const again = read(State, written(State, s, &out));
            try testing.expect(std.meta.eql(s.role, again.role) and s.min == again.min);
            try testing.expectEqualStrings(s.q.slice(), again.q.slice());
        }
    }.one, .{});
}
