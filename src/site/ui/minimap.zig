//! Minimap: Summoner's Rift as a square, lanes and river drawn faintly, with where kills
//! happened: an enemy down as a dot in --us, one of yours as a cross in --them, yours
//! ringed. s is a moment row's 16 px dot (no lanes); l the moment card's map
const std = @import("std");
const tree = @import("tree.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = @import("phrase.zig").plain;
const H = tree.H;
const N = tree.N;

pub const name = "Minimap";
pub const scope = .{".c-map"};

pub const Point = struct {
    /// Map units, blue's base at (0, 0)
    x: u16,
    y: u16,
    /// One of yours died
    ours: bool,
    you: bool = false,
};

pub const Opts = struct {
    s: enum { s, l } = .l,
    /// Your team played blue (bases coloured); null leaves them plain
    blue: ?bool = null,
};

/// Map units across the playable square
const extent: f32 = 15000;

const W = struct {
    pub const label = plain("Where the kills were");
};

fn at(v: u16, flip: bool) f32 {
    const p = std.math.clamp(@as(f32, @floatFromInt(v)) / extent * 100, 2, 98);
    return if (flip) 100 - p else p;
}

pub fn view(h: *H, pts: []const Point, o: Opts) N {
    const small = o.s == .s;
    const r: f32 = if (small) 13 else 3.2;
    var l = h.list();
    for (pts, 0..) |p, i| {
        const x = at(p.x, false);
        const y = at(p.y, true);
        if (!p.ours) {
            l.add(h.circle(.{ .key = i, .class = "k", .data_you = p.you, .cx = x, .cy = y, .r = r }, .{}));
            continue;
        }
        const d = r * 0.9;
        l.add(h.el(.g, .{ .key = i, .class = "d", .data_you = p.you }, .{
            h.line(.{ .x1 = x - d, .y1 = y - d, .x2 = x + d, .y2 = y + d }, .{}),
            h.line(.{ .x1 = x - d, .y1 = y + d, .x2 = x + d, .y2 = y - d }, .{}),
        }));
    }
    const side = struct {
        fn f(blue: ?bool, base_blue: bool) ?[]const u8 {
            const b = blue orelse return null;
            return if (b == base_blue) "us" else "them";
        }
    }.f;
    return h.span(.{ .class = "c-map", .data_s = if (small) "s" else null, .role = "img", .aria_label = W.label }, .{
        h.svg(.{ .viewBox = "0 0 100 100", .aria_hidden = true }, .{
            if (small) null else h.path(.{ .class = "ln", .d = "M9 86V9h77M14 91h77V14M14 86L86 14" }, .{}),
            if (small) null else h.path(.{ .class = "rv", .d = "M14 14L86 86" }, .{}),
            if (small) null else h.circle(.{ .class = "b", .data_side = side(o.blue, true), .cx = 6, .cy = 94, .r = 5 }, .{}),
            if (small) null else h.circle(.{ .class = "b", .data_side = side(o.blue, false), .cx = 94, .cy = 6, .r = 5 }, .{}),
            l.done(),
        }),
    });
}

pub const css =
    \\@layer components {
    \\  .c-map { display: inline-block; flex: none; width: 150px; aspect-ratio: 1; border-radius: var(--r-s);
    \\    background: var(--panel-3); box-shadow: inset 0 0 0 1px var(--line); }
    \\  .c-map[data-s="s"] { width: 16px; border-radius: 3px; overflow: hidden; }
    \\  .c-map > svg { display: block; width: 100%; height: 100%; overflow: visible; }
    \\  .c-map .ln { fill: none; stroke: var(--line-2); stroke-width: 5; stroke-linecap: round; stroke-linejoin: round; opacity: .55; }
    \\  .c-map .rv { fill: none; stroke: var(--us); stroke-width: 9; stroke-linecap: round; opacity: .12; }
    \\  .c-map .b { fill: none; stroke: var(--line-2); stroke-width: 1.5; }
    \\  .c-map .b[data-side="us"] { stroke: var(--us); }
    \\  .c-map .b[data-side="them"] { stroke: var(--them); }
    \\  .c-map .k { fill: var(--us-hot); }
    \\  .c-map .d { fill: none; stroke: var(--them-hot); stroke-width: 2.2; stroke-linecap: round; }
    \\  .c-map[data-s="s"] .d { stroke-width: 10; }
    \\  .c-map .k[data-you] { stroke: var(--accent); stroke-width: 1.6; }
    \\  .c-map .d[data-you] { stroke: var(--accent); }
    \\}
    \\
;

const demo = [_]Point{
    .{ .x = 13921, .y = 4024, .ours = true },
    .{ .x = 5845, .y = 6819, .ours = false, .you = true },
    .{ .x = 7100, .y = 7600, .ours = false },
    .{ .x = 7400, .y = 7200, .ours = true, .you = true },
    .{ .x = 2125, .y = 11744, .ours = false },
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.add("a fight mid, you died in it", view(h, &demo, .{ .blue = true }));
    g.add("red side, no kills", view(h, &.{}, .{ .blue = false }));
    g.add("side unknown", view(h, demo[0..3], .{}));
    g.add("a moment row's dot", view(h, demo[2..4], .{ .s = .s }));
}
