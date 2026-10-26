//! Violin: how a champion's players' own win rates spread, as a mirrored shape on a 25% to
//! 75% track (50% marked), thicker where more players are, the middle half brighter, the
//! champion's rate as a dot. Fits a table row. The shape takes its colour from one
//! gradient across the track (`defs`, once per page): orange low, grey middle, blue high
const std = @import("std");
const tree = @import("tree.zig");
const fmt = @import("fmt.zig");
const Gallery = @import("gallery.zig").Gallery;
const H = tree.H;
const N = tree.N;

pub const name = "Violin";
pub const scope = .{ ".c-violin", ".c-violin-defs" };

/// The track's ends, %
pub const lo_end = 25.0;
pub const hi_end = 75.0;

pub const Violin = struct {
    /// The outline on a 100 x 10 box (`path`); null without enough players: the track
    /// and the dot only
    path: ?[]const u8,
    /// The players' middle half, %
    lo: f32 = 0,
    hi: f32 = 0,
    /// The champion's win rate, %
    at: f32,
};

fn x(rate: f64) f64 {
    return 100 * (std.math.clamp(rate, lo_end, hi_end) - lo_end) / (hi_end - lo_end);
}

pub fn view(h: *H, v: Violin) N {
    const p = v.path orelse return h.span(.{ .class = "c-violin", .data_state = "none" }, .{
        h.el(.b, .{}, .{}),
        h.el(.i, .{ .style = h.vars(.{ .x = x(v.at) }) }, .{}),
    });
    const l = x(v.lo);
    // The middle half's own copy of the shape, cut to it: no division by zero
    const w = @max(x(v.hi) - l, 0.5);
    return h.span(.{ .class = "c-violin" }, .{
        shape(h, p),
        h.span(.{ .class = "mid", .style = h.vars(.{ .l = l, .w = w }) }, .{h.span(.{}, .{shape(h, p)})}),
        h.el(.b, .{}, .{}),
        h.el(.i, .{ .style = h.vars(.{ .x = x(v.at) }) }, .{}),
    });
}

fn shape(h: *H, p: []const u8) N {
    return h.svg(.{ .viewBox = "0 0 100 10", .preserveAspectRatio = "none", .aria_hidden = true }, .{h.path(.{ .d = p }, .{})});
}

/// The outline of `heights` (0 to 255, players near each point), the first at `first`%
/// and one every `step` points: along the top, back along the bottom, pointed at both
/// ends; past the track it is clipped
pub fn path(a: std.mem.Allocator, heights: []const u8, first: f64, step: f64) ![]const u8 {
    var out: std.Io.Writer.Allocating = .init(a);
    const w = &out.writer;
    const P = struct {
        fn pt(wr: *std.Io.Writer, cmd: u8, rate: f64, top: f64) !void {
            try wr.writeByte(cmd);
            try fmt.fixed(wr, 100 * (rate - lo_end) / (hi_end - lo_end), 1, false);
            try wr.writeByte(' ');
            try fmt.fixed(wr, top, 2, false);
        }
        fn y(v: u8, side: f64) f64 {
            return 5 + side * 5 * @as(f64, @floatFromInt(v)) / 255;
        }
    };
    const last = first + step * @as(f64, @floatFromInt(heights.len -| 1));
    try P.pt(w, 'M', first, 5);
    for (heights, 0..) |v, k| try P.pt(w, 'L', first + step * @as(f64, @floatFromInt(k)), P.y(v, -1));
    try P.pt(w, 'L', last, 5);
    var k = heights.len;
    while (k > 0) {
        k -= 1;
        try P.pt(w, 'L', first + step * @as(f64, @floatFromInt(k)), P.y(heights[k], 1));
    }
    try w.writeByte('Z');
    return out.toOwnedSlice();
}

/// The shape's gradient, once on a page with violins. Not display: none, which would
/// leave the shapes unpainted
pub fn defs(h: *H) N {
    var stops = h.list();
    for ([_]f32{ 0, 0.3, 0.44, 0.56, 0.7, 1 }) |o| stops.add(h.el(.stop, .{ .offset = o }, .{}));
    return h.svg(.{ .class = "c-violin-defs", .width = 0, .height = 0, .aria_hidden = true }, .{h.el(.defs, .{}, .{
        h.el(.linearGradient, .{ .id = "c-violin-g", .gradientUnits = "userSpaceOnUse", .x1 = 0, .x2 = 100, .y1 = 0, .y2 = 0 }, .{stops.done()}),
    })});
}

pub const css =
    \\@layer components {
    \\  .c-violin { position: relative; display: block; width: 100%; min-width: 96px; height: 18px; }
    \\  .c-violin svg { position: absolute; inset: 0; width: 100%; height: 100%; display: block; }
    \\  .c-violin path { fill: url(#c-violin-g); opacity: 0.22; }
    \\  .c-violin .mid { position: absolute; top: 0; bottom: 0; left: calc(var(--l) * 1%); width: calc(var(--w) * 1%);
    \\    overflow: hidden; }
    \\  .c-violin .mid > span { position: relative; display: block; height: 100%; width: calc(100% * 100 / var(--w));
    \\    margin-left: calc(-100% * var(--l) / var(--w)); }
    \\  .c-violin .mid path { opacity: 0.7; }
    \\  .c-violin > b { position: absolute; left: 50%; top: -3px; bottom: -3px; width: 1px; background: var(--axis); }
    \\  .c-violin > i { position: absolute; top: 50%; left: calc(var(--x) * 1%); width: 7px; height: 7px;
    \\    margin: -3.5px 0 0 -3.5px; border-radius: 50%; background: var(--text); box-shadow: 0 0 0 1.5px var(--bg); }
    \\  .c-violin[data-state="none"]::before { content: ""; position: absolute; left: 0; right: 0; top: 50%;
    \\    height: 1px; background: var(--line); }
    \\  .c-violin-defs { position: absolute; }
    \\  .c-violin-defs stop:nth-child(1) { stop-color: var(--lo3); }
    \\  .c-violin-defs stop:nth-child(2) { stop-color: var(--lo2); }
    \\  .c-violin-defs stop:nth-child(3), .c-violin-defs stop:nth-child(4) { stop-color: var(--s0); }
    \\  .c-violin-defs stop:nth-child(5) { stop-color: var(--hi2); }
    \\  .c-violin-defs stop:nth-child(6) { stop-color: var(--hi3); }
    \\}
    \\
;

/// A bell of players around `centre`%, `spread` points wide each side, 37 points two apart
fn demoPath(h: *H, centre: f64, spread: f64) []const u8 {
    var hs: [37]u8 = undefined;
    for (&hs, 0..) |*v, k| {
        const off = @as(f64, @floatFromInt(k)) * 2 - 36;
        v.* = @intFromFloat(255 * @exp(-off * off / (2 * spread * spread)));
    }
    return path(h.mem, &hs, centre - 36, 2) catch {
        h.oom = true;
        return "";
    };
}

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    // Once per frame: the gallery is one page, the first copy serves every frame
    g.add("gradient (once a page)", defs(h));
    g.addFill("wide spread, above 50%", view(h, .{ .path = demoPath(h, 53.5, 9), .lo = 47, .hi = 61, .at = 53.5 }));
    g.addFill("narrow, below 50%", view(h, .{ .path = demoPath(h, 47.2, 5), .lo = 44, .hi = 51, .at = 47.2 }));
    g.addFill("off the track's end", view(h, .{ .path = demoPath(h, 70, 8), .lo = 63, .hi = 76, .at = 70 }));
    g.addFill("too few players: dot only", view(h, .{ .path = null, .at = 51.2 }));
}
