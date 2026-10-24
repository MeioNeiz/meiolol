//! The lane chart: a difference by minute (gold, XP or CS, side a minus side b) as SVG,
//! with the typical band and line and optionally one game's own line. Plain numbers in,
//! so the matchup pages (curves) and Your games (chart_wasm.zig, the API's JSON) draw
//! the same chart. No allocator or I/O.

const std = @import("std");
const tpl = @import("tpl");

const Writer = std.Io.Writer;

pub const Chart = struct {
    /// Accessible name: "gold of Garen minus Darius by minute"
    aria: []const u8,
    /// Side labels: "{a} ahead" above zero, "{b} ahead" below
    a: []const u8,
    b: []const u8,
    /// Index i is minute i + 1. The band's [low, high] and the line through it; either
    /// may stop before `you`
    band: []const [2]i32 = &.{},
    line: []const i32 = &.{},
    /// One game's own difference
    you: []const i32 = &.{},
    /// The previous patch's line, dashed
    prev: []const i32 = &.{},
    /// Set: a hover column per minute titled with the line and band in this unit
    tips: []const u8 = "",
    /// SVG units; text is a fixed size in them, so a chart drawn small wants fewer
    width: u16 = 640,
    height: u16 = 240,
    /// Set: only the band's first `fit` minutes set the scale and later band clips. The
    /// band widens far past the lane (±3,000 gold at 30 min) while the line stays near 0
    fit: usize = 0,
};

/// Before this minute nearly every game is still running (no surrender vote yet)
pub const surrender_minute = 15;

/// Minutes drawn: 2 or more, or there is no chart
pub fn longest(c: Chart) usize {
    return @max(c.band.len, c.line.len, c.you.len);
}

pub fn render(w: *Writer, c: Chart) !void {
    const n = longest(c);
    if (n < 2) return;
    // Each side its own top: a lean or a one-sided game gets the room, the smaller side
    // at least a third of the larger so its tick label clears 0's
    var up: i32 = 0;
    var down: i32 = 0;
    const fitted = if (c.fit > 0) c.band[0..@min(c.fit, c.band.len)] else c.band;
    for (fitted) |b| for (b) |v| {
        up = @max(up, v);
        down = @max(down, -v);
    };
    for ([_][]const i32{ c.line, c.you, c.prev }) |vs| for (vs) |v| {
        up = @max(up, v);
        down = @max(down, -v);
    };
    const g: Geometry = .{
        .hi = niceCeil(@max(up, @divTrunc(down, 3))),
        .lo = niceCeil(@max(down, @divTrunc(up, 3))),
        .longest = n,
        .width = c.width,
        .height = c.height,
    };
    try tpl.renderPart(w, "<svg viewBox=\"0 0 {width} {height}\" role=\"img\" aria-label=\"{aria}\">\n", .{
        .width = c.width,
        .height = c.height,
        .aria = c.aria,
    });
    for ([_]i32{ g.hi, 0, -g.lo }) |tick| {
        try tpl.render(w,
            \\<line class="{class}" x1="{left}" x2="{right}" y1="{y:.1}" y2="{y:.1}"/><text x="{label_x}" y="{label_y:.1}" text-anchor="end">{sign}{tick}</text>
            \\
        , .{
            .class = if (tick == 0) "zero" else "grid",
            .left = Geometry.left,
            .right = g.width - Geometry.right,
            .y = g.py(tick),
            .label_x = Geometry.left - 6,
            .label_y = g.py(tick) + 4,
            .sign = if (tick > 0) "+" else "",
            .tick = tick,
        });
    }
    var minute: usize = 5;
    while (minute <= n) : (minute += 5) {
        try tpl.render(w, "<text x=\"{x:.1}\" y=\"{y}\" text-anchor=\"middle\">{minute} min</text>", .{
            .x = g.px(minute - 1),
            .y = g.height - 8,
            .minute = minute,
        });
    }
    if (n > surrender_minute) {
        try tpl.render(w, "<line class=\"ending\" x1=\"{x:.1}\" x2=\"{x:.1}\" y1=\"{top}\" y2=\"{bottom}\"/>", .{
            .x = g.px(surrender_minute - 1),
            .top = Geometry.top,
            .bottom = g.height - Geometry.bottom,
        });
    }
    try tpl.render(w,
        \\<text x="{x}" y="{top}" class="side">{a} ahead</text><text x="{x}" y="{bottom}" class="side">{b} ahead</text>
        \\
    , .{
        .x = Geometry.left + 6,
        .top = Geometry.top + 12,
        .bottom = g.height - Geometry.bottom - 6,
        .a = c.a,
        .b = c.b,
    });
    if (c.band.len >= 2) try tpl.render(w, "<polygon class=\"band\" points=\"{p}\"/>\n", .{
        .p = Points{ .g = g, .band = c.band },
    });
    if (c.prev.len >= 2) try tpl.render(w, "<polyline class=\"median prev\" points=\"{p}\"/>\n", .{
        .p = Points{ .g = g, .line = c.prev },
    });
    if (c.line.len >= 2) try tpl.render(w, "<polyline class=\"median\" points=\"{p}\"/>\n", .{
        .p = Points{ .g = g, .line = c.line },
    });
    if (c.you.len >= 2) try tpl.render(w, "<polyline class=\"you\" points=\"{p}\"/>\n", .{
        .p = Points{ .g = g, .line = c.you },
    });
    if (c.tips.len > 0) try tips(w, c, g);
    try w.writeAll("</svg>\n");
}

/// Hover columns, one per minute of the line, each as wide as a minute
fn tips(w: *Writer, c: Chart, g: Geometry) !void {
    const step = (g.width - Geometry.left - Geometry.right) / @as(f64, @floatFromInt(g.longest - 1));
    for (c.line, 0..) |v, i| {
        try tpl.render(w,
            \\<rect class="hit" x="{x:.1}" y="{top}" width="{step:.1}" height="{h}"><title>{m} min: {sign}{v} {unit}{band}</title></rect>
            \\
        , .{
            .x = g.px(i) - step / 2,
            .top = Geometry.top,
            .step = step,
            .h = g.height - Geometry.top - Geometry.bottom,
            .m = i + 1,
            .sign = if (v > 0) "+" else "",
            .v = v,
            .unit = c.tips,
            .band = if (i < c.band.len) tpl.t(", middle half {lo} to {hi}", .{
                .lo = Signed{ .v = c.band[i][0] },
                .hi = Signed{ .v = c.band[i][1] },
            }) else null,
        });
    }
}

const Signed = struct {
    v: i32,

    pub fn format(s: Signed, w: *Writer) Writer.Error!void {
        if (s.v > 0) try w.writeByte('+');
        try w.print("{d}", .{s.v});
    }
};

/// Chart area in SVG units; values from -lo to hi map onto it
const Geometry = struct {
    hi: i32,
    lo: i32,
    longest: usize,
    width: f64,
    height: f64,

    const left = 56;
    const right = 28;
    const top = 16;
    const bottom = 28;

    fn px(g: Geometry, i: usize) f64 {
        const span: f64 = @floatFromInt(g.longest - 1);
        return left + @as(f64, @floatFromInt(i)) / span * (g.width - left - right);
    }

    fn py(g: Geometry, value: i32) f64 {
        const v: f64 = @floatFromInt(std.math.clamp(value, -g.lo, g.hi));
        const hi: f64 = @floatFromInt(g.hi);
        const span: f64 = @floatFromInt(g.hi + g.lo);
        return top + (hi - v) / span * (g.height - top - bottom);
    }
};

/// An SVG points list: a line, or a band (upper edge forwards, lower edge back)
const Points = struct {
    g: Geometry,
    band: []const [2]i32 = &.{},
    line: []const i32 = &.{},

    pub fn render(p: Points, w: *Writer) Writer.Error!void {
        for (p.line, 0..) |v, i| try point(w, p.g.px(i), p.g.py(v));
        for (p.band, 0..) |b, i| try point(w, p.g.px(i), p.g.py(b[1]));
        var i = p.band.len;
        while (i > 0) {
            i -= 1;
            try point(w, p.g.px(i), p.g.py(p.band[i][0]));
        }
    }

    fn point(w: *Writer, x: f64, y: f64) Writer.Error!void {
        try w.print("{d:.1},{d:.1} ", .{ x, y });
    }
};

/// The axis top: the next 1, 1.5, 2, 2.5, 3, 4, 5, 6 or 8 times a power of ten at or
/// above `value`, whole numbers only
pub fn niceCeil(value: i32) i32 {
    var step: i32 = 1;
    while (true) : (step *= 10) {
        for ([_]i32{ 10, 15, 20, 25, 30, 40, 50, 60, 80 }) |k| {
            if (@rem(k * step, 10) != 0) continue;
            if (@divExact(k * step, 10) >= value) return @divExact(k * step, 10);
        }
    }
}

test "a band, its line and one game" {
    var buf: [4096]u8 = undefined;
    var w: Writer = .fixed(&buf);
    try render(&w, .{
        .aria = "gold of A & B",
        .a = "A",
        .b = "B",
        .band = &.{ .{ -10, 10 }, .{ -50, 150 } },
        .line = &.{ 0, 50 },
        .you = &.{ 20, -30, 40 },
    });
    const out = w.buffered();
    try std.testing.expect(std.mem.startsWith(u8, out, "<svg viewBox=\"0 0 640 240\" role=\"img\" aria-label=\"gold of A &amp; B\">"));
    try std.testing.expect(std.mem.find(u8, out, "<polyline class=\"you\"") != null);
    try std.testing.expect(std.mem.endsWith(u8, out, "</svg>\n"));
    try std.testing.expectEqual(@as(i32, 150), niceCeil(150));
    try std.testing.expectEqual(@as(i32, 2), niceCeil(2));
    try std.testing.expect(std.mem.find(u8, out, ">+150</text>") != null);
    try std.testing.expect(std.mem.find(u8, out, ">-50</text>") != null);
}

test "a fitted band clips past its minutes" {
    var aw: Writer.Allocating = .init(std.testing.allocator);
    defer aw.deinit();
    try render(&aw.writer, .{ .aria = "gold", .a = "A", .b = "B", .band = &.{ .{ -100, 100 }, .{ -400, 400 }, .{ -3000, 3000 } }, .line = &.{ 0, 50, 100 }, .fit = 2 });
    try std.testing.expect(std.mem.find(u8, aw.written(), ">+400</text>") != null);
    try std.testing.expect(std.mem.find(u8, aw.written(), "3000") == null);
}

test "previous patch line, dashed, inside the scale" {
    var aw: Writer.Allocating = .init(std.testing.allocator);
    defer aw.deinit();
    try render(&aw.writer, .{ .aria = "gold", .a = "A", .b = "B", .line = &.{ 0, 100, 200 }, .prev = &.{ 0, -900, -1000 } });
    try std.testing.expect(std.mem.find(u8, aw.written(), "<polyline class=\"median prev\"") != null);
    try std.testing.expect(std.mem.find(u8, aw.written(), ">-1000</text>") != null);
}
