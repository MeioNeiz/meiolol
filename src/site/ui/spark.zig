//! PatchSpark: a win rate over the last few patches in a fixed-size cell (a table's trend
//! column), the end dot coloured by the change. With `y`, `mid` and `star` it is the
//! TimelineSpark of a Your games row: the win chance, the even line and the turning
//! minute. Built as the chart system: lines in a stretched SVG, the dot and the star HTML
//! placed by percent; the figures are the row's, so the label is optional
const std = @import("std");
const tree = @import("tree.zig");
const fmt = @import("fmt.zig");
const phrase = @import("phrase.zig");
const chart = @import("chart.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "PatchSpark";
pub const scope = .{".c-spark"};

pub const Spark = struct {
    vs: []const f32,
    /// For screen readers; none: hidden, the row says it in words
    label: ?tree.Text = null,
    /// The end dot's colour, the change's step; none: ink
    c: ?fmt.Step = null,
    /// A fixed range (0..100 for win chance); none: the values' own
    y: ?chart.Scale = null,
    /// A level across, dashed (even, 50)
    mid: ?f32 = null,
    /// A point marked with a star (the turning minute)
    star: ?usize = null,
    w: u16 = 64,
    h: u16 = 20,
};

const W = struct {
    pub const star = plain("★");
};

pub fn view(h: *H, s: Spark) N {
    if (s.vs.len < 2) return .none;
    var lo = s.vs[0];
    var hi = s.vs[0];
    for (s.vs) |v| {
        lo = @min(lo, v);
        hi = @max(hi, v);
    }
    const p: chart.Plane = .{ .x = .{ .lo = 0, .hi = @floatFromInt(s.vs.len - 1) }, .y = s.y orelse .{ .lo = lo, .hi = hi } };
    const last = s.vs.len - 1;
    return h.span(.{
        .class = "c-spark",
        .role = if (s.label != null) "img" else null,
        .aria_label = s.label,
        .aria_hidden = s.label == null,
        .style = h.vars(.{ .w = s.w, .h = s.h }),
    }, .{h.span(.{ .class = "in" }, .{
        h.svg(.{ .viewBox = "0 0 100 100", .preserveAspectRatio = "none" }, .{
            if (s.mid) |m| chart.level(h, p, m) else null,
            chart.line(h, p, s.vs, .main),
        }),
        h.el(.i, .{ .class = "end", .style = if (s.c) |c| h.vars(.{ .x = p.px(last), .y = p.py(s.vs[last]), .c = c }) else h.vars(.{ .x = p.px(last), .y = p.py(s.vs[last]) }) }, .{}),
        if (s.star) |i| if (i < s.vs.len) h.span(.{ .class = "star", .style = h.vars(.{ .x = p.px(i), .y = p.py(s.vs[i]) }) }, .{W.star}) else null else null,
    })});
}

pub const css =
    \\@layer components {
    \\  .c-spark { display: block; position: relative; width: calc(var(--w) * 1px); height: calc(var(--h) * 1px); flex: none; }
    \\  .c-spark > .in { position: absolute; inset: 3px; }
    \\  .c-spark svg { position: absolute; inset: 0; width: 100%; height: 100%; overflow: visible; }
    \\  .c-spark svg * { vector-effect: non-scaling-stroke; }
    \\  .c-spark .ln { fill: none; stroke: var(--t2); stroke-width: 1.3; stroke-linejoin: round; stroke-linecap: round; }
    \\  .c-spark .ln[data-k="ref"] { stroke: var(--axis); stroke-width: 1; stroke-dasharray: 2 2; }
    \\  .c-spark .end { position: absolute; left: calc(var(--x) * 1%); top: calc(var(--y) * 1%); width: 5px; height: 5px;
    \\    margin: -2.5px 0 0 -2.5px; border-radius: 50%; background: var(--c, var(--text)); }
    \\  .c-spark .star { position: absolute; left: calc(var(--x) * 1%); top: calc(var(--y) * 1%); transform: translate(-50%, -110%);
    \\    color: var(--turn); font-size: var(--fs-xs); line-height: 1; }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    // mocks/components.html: Ahri, Darius, Renata Glasc, Viktor over 16.19-16.21
    const rows = [_]struct { []const f32, f32 }{
        .{ &.{ 52.2, 51.1, 51.3 }, 0.2 },
        .{ &.{ 49.6, 52.2 }, 2.6 },
        .{ &.{ 51.9, 47.5 }, -4.4 },
        .{ &.{ 50.8, 47.6 }, -3.2 },
    };
    var l = h.list();
    for (rows) |r| l.add(view(h, .{ .vs = r[0], .c = fmt.Step.of(r[1], fmt.win_cuts) }));
    g.add("patches: flat, up, down (the change's colour)", h.div(.{ .class = "g-row" }, .{l.done()}));
    const wc = @import("chart_demo.zig").wc;
    g.add("a game's win chance, even and the turning minute", view(h, .{ .vs = &wc, .y = .{ .lo = 0, .hi = 100 }, .mid = 50, .star = 36, .w = 120, .h = 32 }));
}

const testing = std.testing;

test "the line spans the box, the end dot sits on the last point, the star on its point" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    const n = view(&h, .{ .vs = &.{ 40, 60, 50 }, .y = .{ .lo = 0, .hi = 100 }, .mid = 50, .star = 1 });
    try testing.expectEqualStrings("true", t.attr(n, "aria-hidden").?);
    const lines = t.kidsOf(t.find(n, "viewBox", "0 0 100 100").?);
    try testing.expectEqualStrings("50", t.attr(lines[0], "y1").?);
    try testing.expectEqualStrings("M0 60L50 40L100 50", t.attr(lines[1], "d").?);
    try testing.expectEqualStrings("--x:100;--y:50", t.attr(t.find(n, "class", "end").?, "style").?);
    try testing.expectEqualStrings("--x:50;--y:40", t.attr(t.find(n, "class", "star").?, "style").?);
    try testing.expectEqual(N.none, view(&h, .{ .vs = &.{50} }));
}
