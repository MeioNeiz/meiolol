//! The one formatter (every number a phrase or cell shows) and the colour step
const std = @import("std");
const W = std.Io.Writer;

pub const Kind = enum {
    /// 53.4%
    rate,
    /// 53%
    pct,
    /// 8,068
    count,
    /// +2.9 or −2.9 (a minus sign, not a hyphen)
    points,
    /// +1,039 or −811
    signed,
    /// 12:05 from seconds
    time,
    /// 7
    int,
    text,
};

pub fn write(w: *W, comptime k: Kind, v: anytype) W.Error!void {
    switch (k) {
        .rate => {
            try fixed(w, v, 1, false);
            try w.writeByte('%');
        },
        .pct => try w.print("{d}%", .{v}),
        .count => try count(w, @intCast(v)),
        .points => {
            try sign(w, v);
            try fixed(w, @abs(v), 1, false);
        },
        .signed => {
            try sign(w, v);
            try count(w, @abs(v));
        },
        .time => try w.print("{d}:{d:0>2}", .{ @divTrunc(v, 60), @mod(v, 60) }),
        .int => try w.print("{d}", .{v}),
        .text => try w.writeAll(v),
    }
}

/// `x` with `places` decimals (trailing zeros dropped when `trim`), by integer
/// arithmetic: std's float formatter is several KB of ui.wasm
pub fn fixed(w: *W, x: anytype, comptime places: u2, trim: bool) W.Error!void {
    const scale: f64 = comptime std.math.pow(f64, 10, places);
    const v: f64 = @floatCast(x);
    const r = @round(@abs(v) * scale);
    if (!(r < 1e15)) return w.writeAll("0");
    const n: u64 = @intFromFloat(r);
    const unit: u64 = @intFromFloat(scale);
    if (v < 0 and n != 0) try w.writeByte('-');
    try w.print("{d}", .{n / unit});
    var frac = n % unit;
    if (places == 0 or (trim and frac == 0)) return;
    var digits: [3]u8 = undefined;
    var k: usize = places;
    while (k > 0) {
        k -= 1;
        digits[k] = '0' + @as(u8, @intCast(frac % 10));
        frac /= 10;
    }
    var len: usize = places;
    if (trim) while (len > 0 and digits[len - 1] == '0') {
        len -= 1;
    };
    try w.writeByte('.');
    try w.writeAll(digits[0..len]);
}

fn sign(w: *W, v: anytype) W.Error!void {
    if (v > 0) try w.writeByte('+') else if (v < 0) try w.writeAll("\u{2212}");
}

fn count(w: *W, v: u64) W.Error!void {
    var buf: [24]u8 = undefined;
    const s = std.fmt.bufPrint(&buf, "{d}", .{v}) catch unreachable;
    for (s, 0..) |c, i| {
        if (i > 0 and (s.len - i) % 3 == 0) try w.writeByte(',');
        try w.writeByte(c);
    }
}

/// Which Kind a value type may take, checked at compile time by words.zig
pub fn accepts(comptime k: Kind, comptime T: type) bool {
    const info = @typeInfo(T);
    return switch (k) {
        .rate, .points => info == .float or info == .comptime_float,
        .pct, .count, .signed, .time, .int => info == .int or info == .comptime_int,
        .text => T == []const u8 or (info == .pointer and info.pointer.size == .one),
    };
}

/// Steps of the diverging scale: 0 grey, 1..4 away from the middle
pub fn step(v: f32, cuts: [4]f32) u3 {
    var s: u3 = 0;
    for (cuts) |c| if (@abs(v) >= c) {
        s += 1;
    };
    return s;
}

pub const win_cuts: [4]f32 = .{ 1, 2, 3.5, 5.5 };

/// The class for a step of the scale: s0, hi1..hi4, lo1..lo4
pub fn ink(v: f32, cuts: [4]f32) []const u8 {
    const names = [_][]const u8{ "s0", "hi1", "hi2", "hi3", "hi4", "lo1", "lo2", "lo3", "lo4" };
    const s = step(v, cuts);
    if (s == 0) return names[0];
    return names[@as(usize, s) + if (v > 0) @as(usize, 0) else 4];
}

test "numbers read as the mock's" {
    var buf: [64]u8 = undefined;
    var w: W = .fixed(&buf);
    try write(&w, .count, 403364);
    try write(&w, .points, @as(f32, -2.94));
    try write(&w, .time, 2196);
    try write(&w, .signed, -811);
    try std.testing.expectEqualStrings("403,364\u{2212}2.936:36\u{2212}811", w.buffered());
    try std.testing.expectEqualStrings("hi3", ink(4, win_cuts));
    try std.testing.expectEqualStrings("lo1", ink(-1.5, win_cuts));
}
