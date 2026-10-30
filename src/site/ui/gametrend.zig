//! GameTrend (your-games.md "Over time"): a player's games in order on chart.zig's frame,
//! each a dot at its figure, filled for a win and hollow for a loss, the rolling mean of 5
//! filled against a base (50%, zero or the average), patch changes as dashed dividers
//! named by the new patch, each week's first game dated under the axis. Games are evenly
//! spaced, not by date, so a busy evening doesn't pile up. A dot links to its game. The
//! pointer anywhere on the plot (or a tap, which stays) picks the nearest game: its dot
//! ringed, its figure and the mean in a tip (the caller's state, `at`); keyboard focus
//! on a dot shows its label. A key under the plot names the dots and the line
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const chart = @import("chart.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;

pub const W = struct {
    pub const win = plain("Win");
    pub const loss = plain("Loss");
    pub const mean = plain("Average of 5");
};
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
    /// The game picked by the pointer and the tip's content for it
    at: ?usize = null,
    tip: N = .none,
    on: chart.PlotOn = .{},
};

/// The game under a pointer at fraction f of the plot's width, of n
pub fn pick(f: f32, n: usize) usize {
    if (n == 0) return 0;
    const i: usize = @intFromFloat(@max(0, @floor(f * @as(f32, @floatFromInt(n)))));
    return @min(i, n - 1);
}

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

/// Game i at i, half a game's room at either end
fn plane(n: usize, y: chart.Scale) chart.Plane {
    return .{ .x = .{ .lo = -0.5, .hi = @as(f32, @floatFromInt(n)) - 0.5 }, .y = y };
}

pub fn view(h: *H, t: Trend) N {
    const n = t.points.len;
    if (n == 0) return .none;
    const p = plane(n, t.y);
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
        const on = t.at == i;
        over.add(if (pt.href) |href|
            h.a(.{ .class = "g", .href = href, .data_win = pt.win, .data_at = on, .aria_label = pt.label, .style = st }, .{})
        else
            h.span(.{ .class = "g", .role = "img", .data_win = pt.win, .data_at = on, .aria_label = pt.label, .style = st }, .{}));
    }
    if (t.at) |i| if (i < n) {
        for (chart.tip(h, p.px(i), .{t.tip})) |x| over.add(x);
    };
    return chart.frame(h, .{
        .label = t.label,
        .class = "c-chart c-gtrend",
        .height = t.height,
        .y = t.ticks,
        .marks = marks.done(),
        .over = over.done(),
        .below = &.{h.div(.{ .class = "xax", .aria_hidden = true }, .{xs.done()})},
        .on = t.on,
        .press = t.on.move != null,
        .foot = h.div(.{ .class = "key", .aria_hidden = true }, .{
            h.span(.{}, .{ h.el(.i, .{ .data_k = "win" }, .{}), W.win }),
            h.span(.{}, .{ h.el(.i, .{ .data_k = "loss" }, .{}), W.loss }),
            h.span(.{}, .{ h.el(.i, .{ .data_k = "mean" }, .{}), W.mean }),
        }),
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
    \\  .c-gtrend .g[data-at], .c-gtrend .g:focus-visible { z-index: 3; outline: 2px solid var(--focus); outline-offset: 1px; }
    \\  .c-gtrend .g:focus-visible::after { content: attr(aria-label); position: absolute;
    \\    bottom: calc(100% + 8px); left: 50%; transform: translateX(calc(var(--x) * -1%)); padding: 2px var(--sp-2);
    \\    border-radius: var(--r-m); background: var(--panel-3); border: 1px solid var(--line-2); box-shadow: var(--shadow-pop);
    \\    color: var(--text); font-size: var(--fs-s); white-space: nowrap; pointer-events: none; }
    \\  .c-gtrend > .xax { position: relative; height: 18px; }
    \\  .c-gtrend .tip small { margin-left: var(--sp-2); color: var(--faint); font-size: var(--fs-xs); }
    \\  .c-gtrend > .key { display: flex; flex-wrap: wrap; gap: var(--sp-1) var(--sp-4); margin-top: var(--sp-2); color: var(--muted); }
    \\  .c-gtrend > .key > span { display: inline-flex; align-items: center; gap: 6px; }
    \\  .c-gtrend > .key i { width: 6px; height: 6px; border-radius: 50%; border: 2px solid var(--them); }
    \\  .c-gtrend > .key i[data-k="win"] { border-color: var(--us); background: var(--us); }
    \\  .c-gtrend > .key i[data-k="mean"] { width: 14px; height: 0; border-radius: 0; border: 0; border-top: 1.5px solid var(--text); }
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
    const tip = h.span(.{}, .{ h.b(.{}, .{plain("98%")}), plain(" Win · Karthus vs Ahri · 2 Oct"), h.small(.{}, .{plain("Average of 5: 74%")}) });
    g.addFill("a game picked: its dot ringed, the tip", view(h, .{ .label = plain("Win chance at 15"), .points = &demo.points, .y = p.y, .ticks = chart.chanceTicks(h, p), .base = 50, .at = 10, .tip = tip }));
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

test "pick: the game whose dot is under the pointer" {
    for (1..21) |n| {
        const p = plane(n, .{ .lo = 0, .hi = 1 });
        for (0..n) |i| try testing.expectEqual(i, pick(p.px(i) / 100, n));
    }
}
