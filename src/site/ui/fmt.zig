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
    /// 4.4: one decimal, no sign (a ± or an arrow carries it)
    dec,
    /// 940, 2.3k, 34k: a count where the exact figure is not the point (chart subs)
    kilo,
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
        // Unsigned seconds: std puts "+" on a signed int given a width ("11:+54")
        .time => try w.print("{d}:{d:0>2}", .{ @divTrunc(v, 60), @as(u64, @intCast(@mod(v, 60))) }),
        .int => try w.print("{d}", .{v}),
        .dec => try fixed(w, @abs(v), 1, false),
        .kilo => {
            const n: u64 = @intCast(v);
            if (n < 1000) return w.print("{d}", .{n});
            const th = @as(f64, @floatFromInt(n)) / 1000;
            if (n < 9950) try fixed(w, th, 1, true) else try fixed(w, th, 0, true);
            try w.writeByte('k');
        },
        .text => try w.writeAll(v),
    }
}

/// `x` with `places` decimals (trailing zeros dropped when `trim`), by integer
/// arithmetic: std's float formatter is several KB of ui.wasm
pub fn fixed(w: *W, x: anytype, comptime places: u4, trim: bool) W.Error!void {
    comptime std.debug.assert(places <= 9);
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
    var digits: [9]u8 = undefined;
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
        .rate, .points, .dec => info == .float or info == .comptime_float,
        .pct, .count, .signed, .time, .int, .kilo => info == .int or info == .comptime_int,
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
/// One game's swings are wider than an aggregate's
pub const game_cuts: [4]f32 = .{ 2.5, 5, 10, 15 };

pub const Scale = enum {
    none,
    /// A rate over many games (a champion's, a matchup's): win_cuts
    aggregate,
    /// One game: game_cuts
    game,

    pub fn cuts(s: Scale) [4]f32 {
        return if (s == .game) game_cuts else win_cuts;
    }
};

/// Under this many games a figure fades: it could easily be luck
pub const thin_games = 100;

/// A step of the diverging scale as a CSS colour: `h.vars(.{ .c = Step.of(d, cuts) })`
/// writes var(--hi2)
pub const Step = struct {
    /// 0 grey, 1..4 away from the middle
    s: u3 = 0,
    low: bool = false,

    pub fn of(v: f32, cuts: [4]f32) Step {
        return .{ .s = step(v, cuts), .low = v < 0 };
    }

    pub fn format(c: Step, w: *W) W.Error!void {
        if (c.s == 0) return w.writeAll("var(--s0)");
        try w.print("var(--{s}{d})", .{ if (c.low) "lo" else "hi", c.s });
    }

    /// The cell fill for this step (fills stop at step 3)
    pub fn fill(c: Step) Fill {
        return .{ .of = c };
    }
};

/// A heat cell's background: var(--f-hi2)
pub const Fill = struct {
    of: Step,

    pub fn format(f: Fill, w: *W) W.Error!void {
        if (f.of.s == 0) return w.writeAll("var(--f-0)");
        try w.print("var(--f-{s}{d})", .{ if (f.of.low) "lo" else "hi", @min(f.of.s, 3) });
    }
};

/// The class for a step of the scale: s0, hi1..hi4, lo1..lo4
pub fn ink(v: f32, cuts: [4]f32) []const u8 {
    const names = [_][]const u8{ "s0", "hi1", "hi2", "hi3", "hi4", "lo1", "lo2", "lo3", "lo4" };
    const s = step(v, cuts);
    if (s == 0) return names[0];
    return names[@as(usize, s) + if (v > 0) @as(usize, 0) else 4];
}

/// Win rate colour on the site's diverging scale (--lo4 to --hi4, docs/design-ideas.md):
/// continuous, orange then hot pink below 50%, blue then aqua above, each colour at its
/// stop's points (scaled by span / table_span). Grey only when it shows as 50.0%: every
/// other rate has a side (J12). Not red against green: the pair red-green colour
/// blindness merges. Few games fade by opacity, not colour
pub fn wrColour(p: f64, span: f64) WrColour {
    return .{ .pts = 100 * (p - 0.5) * table_span / span };
}

/// wrColour's span on the champions table, and for anything coloured to match it
pub const table_span = 0.12;

/// Aggregate scale (a champion's or matchup's rate over many games): the points where
/// --hi1..--hi4 sit; past the last, --hi4. 4% of champion roles with 500+ games reach
/// it
const wr_stops = [_]f64{ 0, 2, 3.5, 5.5 };

/// A colour of the scale, as a CSS value: `h.vars(.{ .c = wrColour(p, span) })`
pub const WrColour = struct {
    pts: f64,

    /// A mix of the two stops either side
    pub fn format(c: WrColour, w: *W) W.Error!void {
        const side = if (c.pts < 0) "lo" else "hi";
        const x = @abs(c.pts);
        if (x < 0.05) return w.writeAll("var(--s0)");
        if (x >= wr_stops[wr_stops.len - 1]) return w.print("var(--{s}4)", .{side});
        var i: usize = 1;
        while (x >= wr_stops[i]) i += 1;
        const t = (x - wr_stops[i - 1]) / (wr_stops[i] - wr_stops[i - 1]);
        const near: u8 = @round(100 * (1 - t));
        if (near == 100) return w.print("var(--{s}{d})", .{ side, i });
        if (near == 0) return w.print("var(--{s}{d})", .{ side, i + 1 });
        try w.print("color-mix(in oklab,var(--{s}{d}) {d}%,var(--{s}{d}))", .{ side, i, near, side, i + 1 });
    }
};

test wrColour {
    var buf: [96]u8 = undefined;
    const cases = .{
        .{ 0.5004, "var(--s0)" },
        .{ 0.501, "color-mix(in oklab,var(--hi1) 95%,var(--hi2))" },
        .{ 0.495, "color-mix(in oklab,var(--lo1) 75%,var(--lo2))" },
        .{ 0.52, "var(--hi2)" },
        .{ 0.545, "color-mix(in oklab,var(--hi3) 50%,var(--hi4))" },
        .{ 0.44, "var(--lo4)" },
    };
    inline for (cases) |c| {
        const s = try std.mem.print(&buf, "{f}", .{wrColour(c[0], table_span)});
        try std.testing.expectEqualStrings(c[1], s);
    }
}

test Step {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("var(--hi2)", try std.mem.print(&buf, "{f}", .{Step.of(2.6, win_cuts)}));
    try std.testing.expectEqualStrings("var(--lo1)", try std.mem.print(&buf, "{f}", .{Step.of(-4.4, game_cuts)}));
    try std.testing.expectEqualStrings("var(--f-lo3)", try std.mem.print(&buf, "{f}", .{Step.of(-6, win_cuts).fill()}));
    try std.testing.expectEqualStrings("var(--s0)", try std.mem.print(&buf, "{f}", .{Step.of(0.3, win_cuts)}));
}

test "numbers read as the mock's" {
    var buf: [64]u8 = undefined;
    var w: W = .fixed(&buf);
    try write(&w, .count, 403364);
    try write(&w, .points, @as(f32, -2.94));
    try write(&w, .time, @as(i64, 2196));
    try write(&w, .signed, -811);
    try std.testing.expectEqualStrings("403,364\u{2212}2.936:36\u{2212}811", w.buffered());
    w = .fixed(&buf);
    for ([_]u32{ 940, 2300, 2349, 9960, 34_120 }) |n| {
        try write(&w, .kilo, n);
        try w.writeByte(' ');
    }
    try std.testing.expectEqualStrings("940 2.3k 2.3k 10k 34k ", w.buffered());
    try std.testing.expectEqualStrings("hi3", ink(4, win_cuts));
    try std.testing.expectEqualStrings("lo1", ink(-1.5, win_cuts));
    w = .fixed(&buf);
    try fixed(&w, @as(f64, 2e-9), 9, false);
    try w.writeByte(' ');
    try fixed(&w, @as(f64, -0.1234567894), 9, true);
    try std.testing.expectEqualStrings("0.000000002 -0.123456789", w.buffered());
}
