//! GameTrend (your-games.md "Over time"): a player's games in order on chart.zig's frame,
//! each a dot at its figure, filled for a win and hollow for a loss, the rolling mean of 5
//! filled against a base (50%, zero or the average), patch changes as dashed dividers
//! named by the new patch, each week's first game dated under the axis. Games are evenly
//! spaced, not by date, so a busy evening doesn't pile up. A dot links to its game; a
//! hover or focus shows its label (CSS, no wasm)
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const chart = @import("chart.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "GameTrend";
pub const scope = .{".c-gtrend"};

pub const Point = struct {
    v: f32,
    win: bool,
    patch: []const u8,
    /// Under the axis on a week's first game ("13 Oct")
    week: ?tree.Text = null,
    /// The game's page; null when it has none
    href: ?[]const u8 = null,
    /// "Karthus vs Ahri · 72% · 19 Oct"
    label: tree.Text,
};

pub const Trend = struct {
    label: tree.Text,
    /// Oldest first
    points: []const Point,
    y: chart.Scale,
    ticks: []const chart.Tick,
    base: f32,
    height: u16 = 220,
};

const roll = 5;

/// The mean of each value and the 4 before it (fewer at the start)
pub fn rolling(h: *H, vs: []const f32) ?[]f32 {
    const mean = h.mem.alloc(f32, vs.len) catch {
        h.oom = true;
        return null;
    };
    var sum: f32 = 0;
    for (vs, 0..) |v, i| {
        sum += v;
        if (i >= roll) sum -= vs[i - roll];
        mean[i] = sum / @as(f32, @floatFromInt(@min(i + 1, roll)));
    }
    return mean;
}

pub fn view(h: *H, t: Trend) N {
    const n = t.points.len;
    if (n == 0) return .none;
    const p: chart.Plane = .{ .x = .{ .lo = -0.5, .hi = @as(f32, @floatFromInt(n)) - 0.5 }, .y = t.y };
    const vs = h.mem.alloc(f32, n) catch {
        h.oom = true;
        return .none;
    };
    for (vs, t.points) |*v, pt| v.* = pt.v;
    const mean = rolling(h, vs) orelse return .none;
    const fill = chart.area(h, p, mean, t.base);
    var marks = h.list();
    for ([_]N{ fill[0], fill[1], chart.level(h, p, t.base), chart.line(h, p, mean, .main) }) |m| marks.add(m);
    var over = h.list();
    var xs = h.list();
    for (t.points, 0..) |pt, i| {
        if (i > 0 and !std.mem.eql(u8, pt.patch, t.points[i - 1].patch)) {
            const x = p.px(i) - (p.px(i) - p.px(i - 1)) / 2;
            marks.add(h.line(.{ .class = "pd", .x1 = x, .x2 = x, .y1 = 0, .y2 = 100 }, .{}));
            over.add(h.span(.{ .class = "pl", .style = h.vars(.{ .x = x }) }, .{pt.patch}));
        }
        if (pt.week) |w| xs.add(h.span(.{ .class = "xt", .style = h.vars(.{ .x = p.px(i) }) }, .{w}));
        const st = h.vars(.{ .x = p.px(i), .y = p.py(pt.v) });
        over.add(if (pt.href) |href|
            h.a(.{ .class = "g", .href = href, .data_win = pt.win, .aria_label = pt.label, .style = st }, .{})
        else
            h.span(.{ .class = "g", .role = "img", .data_win = pt.win, .aria_label = pt.label, .style = st }, .{}));
    }
    return chart.frame(h, .{
        .label = t.label,
        .class = "c-chart c-gtrend",
        .height = t.height,
        .y = t.ticks,
        .marks = marks.done(),
        .over = over.done(),
        .below = &.{h.div(.{ .class = "xax", .aria_hidden = true }, .{xs.done()})},
    });
}

pub const css =
    \\@layer components {
    \\  .c-gtrend > .plot { margin-top: 18px; }
    \\  .c-gtrend .pd { stroke: var(--line-2); stroke-dasharray: 4 3; }
    \\  .c-gtrend .pl { position: absolute; bottom: 100%; left: calc(var(--x) * 1%); padding-left: 4px; line-height: 18px; }
    \\  .c-gtrend .g { position: absolute; left: calc(var(--x) * 1%); top: calc(var(--y) * 1%); width: 10px; height: 10px;
    \\    margin: -5px 0 0 -5px; border-radius: 50%; border: 2px solid var(--them); background: var(--panel); }
    \\  .c-gtrend .g[data-win] { border-color: var(--us); background: var(--us); }
    \\  .c-gtrend .g::before { content: ""; position: absolute; inset: -6px; border-radius: 50%; }
    \\  .c-gtrend .g:hover, .c-gtrend .g:focus-visible { z-index: 3; outline: 2px solid var(--focus); outline-offset: 1px; }
    \\  .c-gtrend .g:hover::after, .c-gtrend .g:focus-visible::after { content: attr(aria-label); position: absolute;
    \\    bottom: calc(100% + 8px); left: 50%; transform: translateX(calc(var(--x) * -1%)); padding: 2px var(--sp-2);
    \\    border-radius: var(--r-m); background: var(--panel-3); border: 1px solid var(--line-2); box-shadow: var(--shadow-pop);
    \\    color: var(--text); font-size: var(--fs-s); white-space: nowrap; pointer-events: none; }
    \\  .c-gtrend > .xax { position: relative; height: 18px; }
    \\}
    \\
;

const demo = struct {
    const vs = [_]f32{ 36, 23, 16, 100, 14, 74, 48, 45, 99, 67, 98, 60, 38, 4, 5, 92, 50, 68, 42, 12 };
    const wins = "lllwlwwlwlwwwllwwwwl";
    const points = blk: {
        var ps: [vs.len]Point = undefined;
        for (&ps, vs, wins, 0..) |*x, v, w, i| x.* = .{
            .v = v,
            .win = w == 'w',
            .patch = if (i < 3) "16.19" else if (i < 15) "16.20" else "16.21",
            .week = if (i % 7 == 0) plain(&.{ '0' + i / 7, ' ', 'O', 'c', 't' }) else null,
            .href = if (i % 5 == 4) null else "#",
            .label = plain("Karthus vs Ahri · 72% · 19 Oct"),
        };
        break :blk ps;
    };
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const p: chart.Plane = .{ .x = .{ .lo = 0, .hi = 1 }, .y = .{ .lo = 0, .hi = 100 } };
    g.addFill("win chance at 15, 20 games over three patches", view(h, .{ .label = plain("Win chance at 15"), .points = &demo.points, .y = p.y, .ticks = chart.chanceTicks(h, p), .base = 50 }));
}

const testing = std.testing;

test "dots link their games, patch changes divide, the mean starts at the first game" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    const n = view(&h, .{ .label = plain("x"), .points = &demo.points, .y = .{ .lo = 0, .hi = 100 }, .ticks = &.{}, .base = 50 });
    // The figure's own label and one per dot
    try testing.expectEqual(21, t.count(n, "aria-label"));
    try testing.expectEqual(16, t.count(n, "href"));
    try testing.expectEqual(11, t.count(n, "data-win"));
    try testing.expect(t.find(n, "class", "pl") != null);
    try testing.expect(!h.oom);
}
