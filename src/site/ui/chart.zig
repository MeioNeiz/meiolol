//! The one chart system (docs/plan/ui/README.md "Charts: one system"). A chart is HTML
//! around one SVG that draws only lines and fills, in a 100 x 100 viewBox stretched over
//! the plot (preserveAspectRatio none, strokes non-scaling): the server's markup fits any
//! width and nothing is measured. Text, dots, icons and controls are HTML placed by
//! percent over it, so they never stretch. Here: scales, the frame, marks (line, area
//! split at a base, band, bars, dots) and the parts presets share (ChartTip, the
//! crosshair, RangeSelect and its pointer handling). Presets: timeline.zig, lane.zig,
//! trend.zig, spark.zig, dotplot.zig
const std = @import("std");
const tree = @import("tree.zig");
const fmt = @import("fmt.zig");
const phrase = @import("phrase.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "Chart";
pub const scope = .{".c-chart"};

/// A linear map from a domain onto 0..100, percent of the plot
pub const Scale = struct {
    lo: f32,
    hi: f32,

    /// Clamped: a value past the scale (a band fitted to its early minutes) draws on the edge
    pub fn at(s: Scale, v: f32) f32 {
        if (s.hi == s.lo) return 50;
        return std.math.clamp((v - s.lo) / (s.hi - s.lo) * 100, 0, 100);
    }

    /// The domain value at percent `p`
    pub fn of(s: Scale, p: f32) f32 {
        return s.lo + p / 100 * (s.hi - s.lo);
    }
};

/// Where a series' points go: point i at x `i * dx` (capped at `x_end`, a game's last
/// part-minute), y up from the bottom
pub const Plane = struct {
    x: Scale,
    y: Scale,
    dx: f32 = 1,
    x_end: ?f32 = null,

    pub fn px(p: Plane, i: usize) f32 {
        var v = @as(f32, @floatFromInt(i)) * p.dx;
        if (p.x_end) |e| v = @min(v, e);
        return p.x.at(v);
    }

    pub fn py(p: Plane, v: f32) f32 {
        return 100 - p.y.at(v);
    }
};

/// The axis top: the next 1, 1.5, 2, 2.5, 3, 4, 5, 6 or 8 times a power of ten at or
/// above `value` (lanechart.zig's, whole numbers)
pub fn niceCeil(value: f32) f32 {
    if (value <= 1) return 1;
    var unit: f32 = 1;
    while (true) : (unit *= 10) {
        for ([_]f32{ 1, 1.5, 2, 2.5, 3, 4, 5, 6, 8 }) |k| {
            if (k * unit != @round(k * unit)) continue;
            if (k * unit >= value) return k * unit;
        }
    }
}

/// A tick step near `extent / n`: 1, 2 or 5 times a power of ten
pub fn niceStep(extent: f32, n: f32) f32 {
    const raw = extent / n;
    var unit: f32 = 1;
    while (unit * 10 <= raw) unit *= 10;
    while (unit > raw) unit /= 10;
    for ([_]f32{ 1, 2, 5, 10 }) |k| if (k * unit >= raw) return k * unit;
    return 10 * unit;
}

pub const Tick = struct {
    /// Percent along its axis (from the top for y)
    at: f32,
    label: tree.Text,
    /// The y axis's zero or reference: an axis line, not a grid line
    zero: bool = false,
    /// x only: dropped in a narrow chart (every other minute label)
    minor: bool = false,
    /// x only: a second line under the label (games behind a point)
    sub: ?tree.Text = null,
};

/// Handlers on the plot: RangeSelect, ChartTip
pub const PlotOn = struct {
    down: ?tree.Handler = null,
    move: ?tree.Handler = null,
    up: ?tree.Handler = null,
    leave: ?tree.Handler = null,
    cancel: ?tree.Handler = null,
};

pub const Frame = struct {
    /// The figure's name for screen readers
    label: tree.Text,
    /// "c-chart" plus a preset's own class
    class: []const u8 = "c-chart",
    /// Plot height in px; a chart under 480 px wide takes 80% of it
    height: u16 = 190,
    y: []const Tick = &.{},
    x: []const Tick = &.{},
    /// Room for figures right of the plot (an end label), px
    right: u16 = 8,
    /// Rows over the plot (FightStrip, deaths on the top edge) and under it
    above: []const N = &.{},
    below: []const N = &.{},
    /// SVG children, in the plot's 100 x 100
    marks: []const N = &.{},
    /// HTML over the plot (dots, labels, the range, the tip)
    over: []const N = &.{},
    on: PlotOn = .{},
    /// The plot reacts to presses (crosshair cursor, no text selection)
    press: bool = false,
    on_key: ?tree.Handler = null,
    /// Under the figure, in the same column (a strip of controls)
    foot: N = .none,
};

pub fn frame(h: *H, f: Frame) N {
    var grid = h.list();
    var ys = h.list();
    for (f.y) |t| {
        grid.add(h.line(.{ .class = if (t.zero) "axis" else "grid", .x1 = 0, .x2 = 100, .y1 = t.at, .y2 = t.at }, .{}));
        ys.add(h.span(.{ .class = "yt", .style = h.vars(.{ .y = t.at }) }, .{t.label}));
    }
    var xs = h.list();
    for (f.x) |t| xs.add(h.span(.{ .class = "xt", .data_minor = t.minor, .style = h.vars(.{ .x = t.at }) }, .{
        t.label,
        if (t.sub) |s| h.small(.{}, .{s}) else null,
    }));
    return h.el(.figure, .{
        .class = f.class,
        .role = "group",
        .aria_label = f.label,
        .style = h.vars(.{ .h = f.height, .pr = f.right }),
        .on_keydown = f.on_key,
    }, .{
        f.above,
        h.div(.{
            .class = "plot",
            .data_press = f.press,
            .on_pointerdown = f.on.down,
            .on_pointermove = f.on.move,
            .on_pointerup = f.on.up,
            .on_pointerleave = f.on.leave,
            .on_pointercancel = f.on.cancel,
        }, .{
            h.svg(.{ .viewBox = "0 0 100 100", .preserveAspectRatio = "none", .aria_hidden = true }, .{ grid.done(), f.marks }),
            if (f.y.len > 0) h.div(.{ .class = "yax", .aria_hidden = true }, .{ys.done()}) else null,
            f.over,
        }),
        f.below,
        if (f.x.len > 0) h.div(.{ .class = "xax", .aria_hidden = true }, .{xs.done()}) else null,
        f.foot,
    });
}

// Marks ---------------------------------------------------------------------------------

/// SVG path data in the plot's 100 x 100
const Path = struct {
    h: *H,
    d: std.ArrayList(u8) = .empty,

    fn to(p: *Path, cmd: u8, x: f32, y: f32) void {
        var buf: [40]u8 = undefined;
        var w: std.Io.Writer = .fixed(&buf);
        w.writeByte(cmd) catch {};
        fmt.fixed(&w, x, 2, true) catch {};
        w.writeByte(' ') catch {};
        fmt.fixed(&w, y, 2, true) catch {};
        p.d.appendSlice(p.h.mem, w.buffered()) catch {
            p.h.oom = true;
        };
    }

    fn close(p: *Path) []const u8 {
        p.d.append(p.h.mem, 'Z') catch {
            p.h.oom = true;
        };
        return p.d.items;
    }
};

pub const Line = enum {
    /// The answer: solid, in ink
    main,
    /// Your own line against a typical one
    you,
    /// A typical (median) line, dashed
    typ,
    /// A previous patch's, dashed and faint
    prev,
    /// A reference level across the plot, dashed
    ref,
};

/// A line through `ys`; fewer than 2 points draw nothing
pub fn line(h: *H, p: Plane, ys: []const f32, kind: Line) N {
    if (ys.len < 2) return .none;
    var path: Path = .{ .h = h };
    for (ys, 0..) |v, i| path.to(if (i == 0) 'M' else 'L', p.px(i), p.py(v));
    return h.path(.{ .class = "ln", .data_k = if (kind == .main) null else kind, .d = path.d.items }, .{});
}

/// A level across the whole plot (a reference win rate, zero)
pub fn level(h: *H, p: Plane, v: f32) N {
    const y = p.py(v);
    return h.line(.{ .class = "ln", .data_k = Line.ref, .x1 = 0, .x2 = 100, .y1 = y, .y2 = y }, .{});
}

/// The area between `ys` and `base`, filled in your side's colour above it and the
/// other side's below; crossings are cut exactly, so each fill stops where the line
/// meets the base
pub fn area(h: *H, p: Plane, ys: []const f32, base: f32) [2]N {
    if (ys.len < 2) return .{ .none, .none };
    return .{
        h.path(.{ .class = "up", .d = split(h, p, ys, base, true) }, .{}),
        h.path(.{ .class = "dn", .d = split(h, p, ys, base, false) }, .{}),
    };
}

fn split(h: *H, p: Plane, ys: []const f32, base: f32, above: bool) []const u8 {
    var path: Path = .{ .h = h };
    const by = p.py(base);
    path.to('M', p.px(0), by);
    for (ys, 0..) |v, i| {
        if (i > 0) {
            const u = ys[i - 1];
            if ((u - base) * (v - base) < 0) {
                const t = (base - u) / (v - u);
                path.to('L', p.px(i - 1) + t * (p.px(i) - p.px(i - 1)), by);
            }
        }
        path.to('L', p.px(i), p.py(if (above) @max(v, base) else @min(v, base)));
    }
    path.to('L', p.px(ys.len - 1), by);
    return path.close();
}

/// A band from lo[i] to hi[i] (the ±95% range, a middle half)
pub fn band(h: *H, p: Plane, lo: []const f32, hi: []const f32) N {
    const n = @min(lo.len, hi.len);
    if (n < 2) return .none;
    var path: Path = .{ .h = h };
    for (0..n) |i| path.to(if (i == 0) 'M' else 'L', p.px(i), p.py(hi[i]));
    var i = n;
    while (i > 0) {
        i -= 1;
        path.to('L', p.px(i), p.py(lo[i]));
    }
    return h.path(.{ .class = "band", .d = path.close() }, .{});
}

/// A vertical band over x from a to b (domain units): the turning minute
pub fn span(h: *H, p: Plane, a: f32, b: f32, class: []const u8) N {
    const x = p.x.at(a);
    return h.rect(.{ .class = class, .x = x, .y = 0, .width = @max(0.2, p.x.at(b) - x), .height = 100 }, .{});
}

/// A dot at point i, its fill a scale colour or ink
pub fn dot(h: *H, p: Plane, i: usize, v: f32, c: ?fmt.Step) N {
    return h.el(.i, .{ .class = "dot", .style = if (c) |s| h.vars(.{ .x = p.px(i), .y = p.py(v), .c = s }) else h.vars(.{ .x = p.px(i), .y = p.py(v) }) }, .{});
}

/// The last point's figure, right of the plot
pub fn endLabel(h: *H, p: Plane, v: f32, text: tree.Text) N {
    return h.span(.{ .class = "end", .style = h.vars(.{ .y = p.py(v) }) }, .{text});
}

/// Thin bars up from the plot's floor, as tall as v / max of 20 px: games behind each point
pub fn bars(h: *H, p: Plane, vs: []const f32) N {
    var max: f32 = 0;
    for (vs) |v| max = @max(max, v);
    if (max <= 0) return .none;
    var l = h.list();
    for (vs, 0..) |v, i| l.add(h.el(.i, .{ .class = "bar", .style = h.vars(.{ .x = p.px(i), .v = @max(4, v / max * 100) }) }, .{}));
    return h.span(.{ .class = "bars" }, .{l.done()});
}

// Parts ---------------------------------------------------------------------------------

/// ChartTip: the figures at one x, as a readout on the plot's top edge (never over the
/// line), with the crosshair. It slides from left-aligned at the plot's start to
/// right-aligned at its end, so it never leaves the chart
pub fn tip(h: *H, x: f32, kids: anytype) [2]N {
    return .{
        h.el(.i, .{ .class = "hair", .style = h.vars(.{ .x = x }) }, .{}),
        h.div(.{ .class = "tip", .role = "status", .style = h.vars(.{ .x = x }) }, kids),
    };
}

/// The chosen point: a line down the plot and a dot on the series
pub fn cursor(h: *H, x: f32, y: ?f32) [2]N {
    return .{
        h.el(.i, .{ .class = "cur", .style = h.vars(.{ .x = x }) }, .{}),
        if (y) |v| h.el(.i, .{ .class = "dot", .data_k = "cur", .style = h.vars(.{ .x = x, .y = v }) }, .{}) else .none,
    };
}

/// RangeSelect's selection from a to b, percent of the plot, with a grip on each edge
pub fn range(h: *H, a: f32, b: f32) N {
    return h.div(.{ .class = "range", .style = h.vars(.{ .a = a, .b = @max(b, a + 0.3) }) }, .{
        h.el(.i, .{}, .{}),
        h.el(.i, .{}, .{}),
    });
}

/// RangeSelect's and ChartTip's pointer handling. A press that moves 6 px is a drag (a
/// range), one that doesn't is a tap; moves without a press are hover. Positions are
/// fractions of the plot's width
pub const Press = struct {
    x0: ?f32 = null,
    moved: bool = false,

    pub const Out = union(enum) {
        none,
        /// The pointer is over x (hover, or a press not yet a drag)
        hover: f32,
        /// A drag from a to b, a < b
        range: [2]f32,
        /// A press released without moving
        tap: f32,
        /// The pointer left: the tip goes
        leave,
    };

    pub fn pointer(s: *Press, ev: *tree.Event) Out {
        const w = if (ev.w > 0) ev.w else 1;
        const f = std.math.clamp(ev.x / w, 0, 1);
        switch (ev.kind) {
            .pointerdown => {
                s.* = .{ .x0 = f };
                return .{ .hover = f };
            },
            .pointermove => {
                const x0 = s.x0 orelse return .{ .hover = f };
                if (!s.moved and @abs(f - x0) * w > 6) {
                    s.moved = true;
                    // Capture once the press is a drag, so the plot keeps the pointer
                    ev.capture = true;
                }
                if (s.moved) return .{ .range = .{ @min(x0, f), @max(x0, f) } };
                return .{ .hover = f };
            },
            .pointerup => {
                const pressed = s.x0 != null;
                const moved = s.moved;
                s.* = .{};
                return if (pressed and !moved) .{ .tap = f } else .none;
            },
            .pointercancel => {
                s.* = .{};
                return .leave;
            },
            .pointerleave => return if (s.moved) .none else .leave,
            else => return .none,
        }
    }
};

/// A reading tip's pointer, never a range: hover or a drag reads where the pointer is, a
/// tap keeps the reading after the pointer leaves (a phone lifts the finger), and the
/// caller drops it on a tap at the kept reading (there is no tap outside to dismiss it)
pub const Reading = struct {
    press: Press = .{},
    /// Where a tap kept the reading
    kept: ?f32 = null,
    /// `kept` as the press began
    was: ?f32 = null,

    pub const Out = union(enum) {
        none,
        /// Read at f
        at: f32,
        /// A tap at f, kept; `was` the reading kept before it, if any
        tap: struct { f: f32, was: ?f32 },
        /// The tip goes
        clear,
    };

    pub fn pointer(r: *Reading, ev: *tree.Event) Out {
        if (ev.kind == .pointerdown) r.was = r.kept;
        switch (r.press.pointer(ev)) {
            .none => return .none,
            .hover => |f| {
                r.kept = null;
                return .{ .at = f };
            },
            .range => {
                r.kept = null;
                return .{ .at = std.math.clamp(ev.x / @max(1, ev.w), 0, 1) };
            },
            .tap => |f| {
                r.kept = f;
                return .{ .tap = .{ .f = f, .was = r.was } };
            },
            .leave => return if (r.kept == null) .clear else .none,
        }
    }

    pub fn drop(r: *Reading) void {
        r.kept = null;
    }
};

pub const css =
    \\@layer components {
    \\  .c-chart { container-type: inline-size; position: relative; display: flex; flex-direction: column; margin: 0;
    \\    padding: 0 calc(var(--pr) * 1px) 0 40px; font-size: var(--fs-xs); color: var(--faint);
    \\    font-variant-numeric: tabular-nums; }
    \\  .c-chart > .plot { position: relative; height: calc(var(--h) * 1px); }
    \\  .c-chart > .plot[data-press] { cursor: crosshair; touch-action: pan-y; user-select: none; -webkit-user-select: none; }
    \\  .c-chart svg { position: absolute; inset: 0; width: 100%; height: 100%; overflow: visible; pointer-events: none; }
    \\  .c-chart svg * { vector-effect: non-scaling-stroke; }
    \\  .c-chart .grid { stroke: var(--grid); }
    \\  .c-chart .axis { stroke: var(--axis); }
    \\  .c-chart .ln { fill: none; stroke: var(--text); stroke-width: 1.5; stroke-linejoin: round; stroke-linecap: round; }
    \\  .c-chart .ln[data-k="you"] { stroke: var(--us); stroke-width: 2; }
    \\  .c-chart .ln[data-k="typ"] { stroke: var(--t2); stroke-dasharray: 4 3; }
    \\  .c-chart .ln[data-k="prev"] { stroke: var(--faint); stroke-dasharray: 2 3; }
    \\  .c-chart .ln[data-k="ref"] { stroke: var(--axis); stroke-width: 1; stroke-dasharray: 3 3; }
    \\  .c-chart .up { fill: var(--us); opacity: 0.26; }
    \\  .c-chart .dn { fill: var(--them); opacity: 0.26; }
    \\  .c-chart .band { fill: var(--text); opacity: 0.08; }
    \\  .c-chart .yax { position: absolute; inset: 0 auto 0 0; }
    \\  .c-chart .yt { position: absolute; right: 6px; top: calc(var(--y) * 1%); transform: translateY(-50%); white-space: nowrap; }
    \\  .c-chart > .xax { position: relative; height: 18px; }
    \\  .c-chart .xt { position: absolute; top: 4px; left: calc(var(--x) * 1%); transform: translateX(-50%); white-space: nowrap;
    \\    text-align: center; line-height: 1.25; }
    \\  .c-chart .xt small { display: block; font-size: inherit; }
    \\  .c-chart > .xax:has(small) { height: 34px; }
    \\  .c-chart .dot { position: absolute; left: calc(var(--x) * 1%); top: calc(var(--y) * 1%); width: 8px; height: 8px;
    \\    margin: -4px 0 0 -4px; border-radius: 50%; background: var(--c, var(--text)); box-shadow: 0 0 0 2px var(--panel);
    \\    pointer-events: none; }
    \\  .c-chart .dot[data-k="cur"] { width: 9px; height: 9px; margin: -4.5px 0 0 -4.5px; background: var(--accent); }
    \\  .c-chart .end { position: absolute; left: calc(100% + 8px); top: calc(var(--y) * 1%); transform: translateY(-50%);
    \\    color: var(--text); font-weight: var(--w-m); white-space: nowrap; }
    \\  .c-chart .bars { position: absolute; inset: auto 0 4px; height: 20px; pointer-events: none; }
    \\  .c-chart .bar { position: absolute; bottom: 0; left: calc(var(--x) * 1%); width: 14px; margin-left: -7px;
    \\    height: calc(var(--v) * 1%); border-radius: 2px 2px 0 0; background: var(--bar-lo); opacity: 0.5; }
    \\  .c-chart .hair, .c-chart .cur { position: absolute; top: 0; bottom: 0; left: calc(var(--x) * 1%); width: 1px;
    \\    background: var(--line-2); pointer-events: none; }
    \\  .c-chart .cur { width: 1.5px; background: var(--accent); }
    \\  .c-chart .tip { position: absolute; bottom: calc(100% + 4px); left: calc(var(--x) * 1%); z-index: 2;
    \\    transform: translateX(calc(var(--x) * -1%)); padding: 2px var(--sp-2); border-radius: var(--r-m);
    \\    background: var(--panel-3); border: 1px solid var(--line-2); box-shadow: var(--shadow-pop);
    \\    color: var(--t2); font-size: var(--fs-s); white-space: nowrap; pointer-events: none; }
    \\  .c-chart .tip b { color: var(--text); font-weight: var(--w-b); }
    \\  .c-chart .range { position: absolute; top: 0; bottom: 0; left: calc(var(--a) * 1%); width: calc((var(--b) - var(--a)) * 1%);
    \\    background: var(--range-bg); border-inline: 1px solid var(--accent); pointer-events: none; }
    \\  .c-chart .range > i { position: absolute; top: 50%; left: 0; width: 6px; height: 20px; margin: -10px 0 0 -3.5px;
    \\    border-radius: 3px; background: var(--accent); }
    \\  .c-chart .range > i + i { left: 100%; }
    \\  @container (max-width: 480px) {
    \\    .c-chart > .plot { height: calc(var(--h) * 0.8px); }
    \\    .c-chart .xt[data-minor] { display: none; }
    \\  }
    \\}
    \\
;

// Gallery -------------------------------------------------------------------------------

const W = struct {
    pub const label = plain("Marks");
    pub const tip = phrase.Phrase("{t:time} · {v:pct}");
};

/// Percent ticks for a 0..100 win chance
pub fn chanceTicks(h: *H, p: Plane) []const Tick {
    var l: std.ArrayList(Tick) = .empty;
    for ([_]u8{ 0, 25, 50, 75, 100 }) |v| {
        l.append(h.mem, .{ .at = p.py(@floatFromInt(v)), .label = phrase.num(h, .pct, v), .zero = v == 50 }) catch {
            h.oom = true;
        };
    }
    return l.items;
}

/// "5:00" every 5 minutes (every other one minor) over a game of `dur` seconds
pub fn minuteTicks(h: *H, x: Scale, dur: f32) []const Tick {
    var l: std.ArrayList(Tick) = .empty;
    var m: u32 = 5;
    while (@as(f32, @floatFromInt(m * 60)) < dur) : (m += 5) {
        l.append(h.mem, .{ .at = x.at(@floatFromInt(m * 60)), .label = phrase.num(h, .time, m * 60), .minor = m % 10 != 0 }) catch {
            h.oom = true;
        };
    }
    return l.items;
}

/// A won game's win chance by minute and a lane's gold against its typical band, for the
/// gallery (timeline.zig and lane.zig draw whole games)
const demo = struct {
    const dur = 1838;
    const wc = [_]f32{ 50, 49, 52, 47, 44, 41, 45, 38, 35, 41, 52, 56, 49, 46, 58, 63, 71, 66, 60, 54, 62, 70, 74, 69, 63, 72, 79, 85, 82, 88, 92 };
    const you = [_]f32{ 0, -34, -102, 275, 179, 154, 151, 79, 211, -59, 112, 50, -196, -215, -212, -225, -137, -897, -1532, -1435, -1411 };
    const typ = [_]f32{ 0, -12, 44, 93, 80, 181, 129, 55, 104, 48, 166, 60, 63, 222, 77, -26, 53, 99, 100, 171, 187 };
    const lo = [_]f32{ 0, -62, -86, -180, -170, -223, -335, -428, -518, -556, -560, -640, -690, -720, -780, -850, -900, -960, -1010, -1080, -1150 };
    const hi = [_]f32{ 0, 40, 274, 299, 350, 449, 460, 580, 653, 699, 648, 801, 820, 870, 900, 940, 980, 1010, 1060, 1100, 1150 };
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const p: Plane = .{ .x = .{ .lo = 0, .hi = demo.dur }, .y = .{ .lo = 0, .hi = 100 }, .dx = 60, .x_end = demo.dur };
    const ar = area(h, p, &demo.wc, 50);
    g.addFill("area split at 50%, a line", frame(h, .{
        .label = W.label,
        .y = chanceTicks(h, p),
        .x = minuteTicks(h, p.x, demo.dur),
        .marks = &.{ ar[0], ar[1], line(h, p, &demo.wc, .main) },
    }));
    const lp: Plane = .{ .x = .{ .lo = 0, .hi = 20 }, .y = .{ .lo = -2000, .hi = 1500 } };
    const t = tip(h, lp.px(12), .{W.tip.with(h, .{ .t = 12 * 60, .v = 63 })});
    const c = cursor(h, lp.px(17), lp.py(demo.you[17]));
    g.addFill("band, typical and your line; tip, cursor, range", frame(h, .{
        .label = W.label,
        .height = 160,
        .marks = &.{ band(h, lp, &demo.lo, &demo.hi), line(h, lp, &demo.typ, .typ), line(h, lp, &demo.you, .you), level(h, lp, 0) },
        .over = &.{ range(h, lp.px(15), lp.px(19)), t[0], t[1], c[0], c[1] },
        .press = true,
    }));
    const tp: Plane = .{ .x = .{ .lo = -0.5, .hi = 2.5 }, .y = .{ .lo = 47, .hi = 57 } };
    const vs = [_]f32{ 52.2, 51.1, 51.3 };
    g.add("dots, bars, a reference, an end label", frame(h, .{
        .label = W.label,
        .height = 120,
        .right = 48,
        .marks = &.{ level(h, tp, 51.3), line(h, tp, &vs, .prev), span(h, tp, 0.5, 1.5, "band") },
        .over = &.{ bars(h, tp, &.{ 1731, 33830, 9374 }), dot(h, tp, 0, vs[0], fmt.Step.of(1.6, fmt.win_cuts)), dot(h, tp, 1, vs[1], null), dot(h, tp, 2, vs[2], null), endLabel(h, tp, vs[2], phrase.num(h, .rate, vs[2])) },
    }));
}

const testing = std.testing;

test "scales clamp and invert; nice numbers" {
    const s: Scale = .{ .lo = -100, .hi = 300 };
    try testing.expectEqual(@as(f32, 25), s.at(0));
    try testing.expectEqual(@as(f32, 100), s.at(900));
    try testing.expectEqual(@as(f32, 0), s.of(25));
    try testing.expectEqual(@as(f32, 500), niceCeil(420));
    try testing.expectEqual(@as(f32, 1500), niceCeil(1001));
    try testing.expectEqual(@as(f32, 2500), niceCeil(2120));
    try testing.expectEqual(@as(f32, 1), niceCeil(0));
    try testing.expectEqual(@as(f32, 2), niceStep(10, 5));
    try testing.expectEqual(@as(f32, 0.5), niceStep(2, 5));
    try testing.expectEqual(@as(f32, 500), niceStep(2400, 5));
}

test "an area split at its base cuts at the crossing" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    const p: Plane = .{ .x = .{ .lo = 0, .hi = 2 }, .y = .{ .lo = -10, .hi = 10 } };
    const a = area(&h, p, &.{ 5, -5, 5 }, 0);
    // Up: from the base, up to the first point, down to the crossing at x 25, along the
    // base to 75, up to the last point and back
    try testing.expectEqualStrings("M0 50L0 25L25 50L50 50L75 50L100 25L100 50Z", t.attr(a[0], "d").?);
    try testing.expectEqualStrings("M0 50L0 50L25 50L50 75L75 50L100 50L100 50Z", t.attr(a[1], "d").?);
    try testing.expectEqualStrings("M0 25L50 75L100 25", t.attr(line(&h, p, &.{ 5, -5, 5 }, .main), "d").?);
    try testing.expectEqual(N.none, line(&h, p, &.{5}, .main));
}

test "a press is a tap, a drag past 6 px a range" {
    var s: Press = .{};
    var ev: tree.Event = .{ .kind = .pointerdown, .x = 100, .w = 400 };
    try testing.expectEqual(Press.Out{ .hover = 0.25 }, s.pointer(&ev));
    ev = .{ .kind = .pointermove, .x = 104, .w = 400 };
    try testing.expectEqual(Press.Out{ .hover = 0.26 }, s.pointer(&ev));
    ev = .{ .kind = .pointerup, .x = 104, .w = 400 };
    try testing.expectEqual(Press.Out{ .tap = 0.26 }, s.pointer(&ev));
    ev = .{ .kind = .pointerdown, .x = 200, .w = 400 };
    _ = s.pointer(&ev);
    ev = .{ .kind = .pointermove, .x = 100, .w = 400 };
    try testing.expectEqual(Press.Out{ .range = .{ 0.25, 0.5 } }, s.pointer(&ev));
    try testing.expect(ev.capture);
    ev = .{ .kind = .pointerup, .x = 100, .w = 400 };
    try testing.expectEqual(Press.Out.none, s.pointer(&ev));
    ev = .{ .kind = .pointermove, .x = 40, .w = 400 };
    try testing.expectEqual(Press.Out{ .hover = 0.1 }, s.pointer(&ev));
}
