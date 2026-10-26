//! TrendChart: a win rate over a few ordered points (patches, game length buckets,
//! mastery bands), a line with its ±95% band, each point a dot coloured on the scale
//! against a reference (dashed), the point's name under it with a second line (rank in
//! role, games), the last figure at the end. No per-point text: a tap or hover shows a
//! point's numbers (ChartTip). A base line, faint dashed, compares each point with a
//! wider group (the matchup page's all lanes) and takes the reference's place. OutcomeCurve (Pick-up) is the same preset over mastery
//! bands
const std = @import("std");
const tree = @import("tree.zig");
const fmt = @import("fmt.zig");
const phrase = @import("phrase.zig");
const chart = @import("chart.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "TrendChart";
pub const scope = .{".c-trend"};

pub const Point = struct {
    label: tree.Text,
    /// Under the label: rank in role ("3rd"), games ("2.3k")
    sub: ?tree.Text = null,
    /// Win rate in %
    v: f32,
    /// Half the 95% range, points
    ci: f32 = 0,
    /// The tip's figures after the label ("48.7% of 23,166 · pick 7.6%")
    tip: tree.Text = .{ .s = "" },
};

pub const Trend = struct {
    label: tree.Text,
    points: []const Point,
    /// What the dots are coloured against, dashed: 50, or the champion's own rate
    ref: f32 = 50,
    /// A rate to compare with at each point, faint dashed (all lanes): one per point, or
    /// none
    base: []const f32 = &.{},
    height: u16 = 130,
    /// ChartTip on this point
    tip: ?u8 = null,
    press: chart.Press = .{},

    const T = @This();

    pub const Msg = union(enum) { plot };

    pub fn update(t: *T, _: Msg, ev: *tree.Event) void {
        const n = t.points.len;
        if (n == 0) return;
        switch (t.press.pointer(ev)) {
            .hover, .tap => |f| {
                // Points sit inside a half-step margin: nearest by the plane's x
                const x = std.math.clamp(f * (@as(f32, @floatFromInt(n)) - 1 + 2 * margin) - margin, 0, @as(f32, @floatFromInt(n - 1)));
                t.tip = @intFromFloat(@round(x));
            },
            .leave => t.tip = null,
            .none, .range => {},
        }
    }

    /// Ticks every `step` points around the even number nearest the reference (50 for
    /// 49.3), at least ±4 so a flat champion stays flat
    fn scale(t: *const T) struct { y: chart.Scale, c: f32, step: f32 } {
        const c = @round(t.ref / 2) * 2;
        var dev: f32 = 0;
        for (t.points) |p| dev = @max(dev, @abs(p.v + p.ci - c), @abs(p.v - p.ci - c));
        for (t.base) |b| dev = @max(dev, @abs(b - c));
        var step: f32 = 4;
        for ([_]f32{ 4, 5, 8, 10, 15, 20, 25 }) |s| {
            step = s;
            if (s * 1.2 >= dev) break;
        }
        return .{ .y = .{ .lo = c - step * 1.25, .hi = c + step * 1.25 }, .c = c, .step = step };
    }

    fn plane(t: *const T) chart.Plane {
        const n: f32 = @floatFromInt(@max(t.points.len, 1));
        return .{ .x = .{ .lo = -margin, .hi = n - 1 + margin }, .y = t.scale().y };
    }

    pub fn view(t: *T, h: *H) N {
        const s = t.scale();
        const p = t.plane();
        const n = t.points.len;
        const vs = h.mem.alloc(f32, 3 * n) catch {
            h.oom = true;
            return .none;
        };
        const v = vs[0..n];
        const lo = vs[n .. 2 * n];
        const hi = vs[2 * n ..];
        for (t.points, v, lo, hi) |pt, *a, *b, *c| {
            a.* = pt.v;
            b.* = pt.v - pt.ci;
            c.* = pt.v + pt.ci;
        }
        var ys: std.ArrayList(chart.Tick) = .empty;
        for ([_]f32{ 1, 0, -1 }) |k| {
            const at = s.c + k * s.step;
            ys.append(h.mem, .{ .at = p.py(at), .label = phrase.num(h, .pct, @as(i32, @intFromFloat(at))) }) catch {
                h.oom = true;
            };
        }
        var xs: std.ArrayList(chart.Tick) = .empty;
        var over = h.list();
        for (t.points, 0..) |pt, i| {
            xs.append(h.mem, .{ .at = p.px(i), .label = pt.label, .sub = pt.sub }) catch {
                h.oom = true;
            };
            over.add(chart.dot(h, p, i, pt.v, fmt.Step.of(pt.v - t.ref, fmt.win_cuts)));
        }
        if (n > 0) over.add(chart.endLabel(h, p, v[n - 1], phrase.num(h, .rate, v[n - 1])));
        if (t.tip) |i| if (i < n) {
            const pt = t.points[i];
            for (chart.tip(h, p.px(i), .{ h.b(.{}, .{pt.label}), " ", pt.tip })) |x| over.add(x);
        };
        return chart.frame(h, .{
            .label = t.label,
            .class = "c-chart c-trend",
            .height = t.height,
            .right = 48,
            .y = ys.items,
            .x = xs.items,
            .marks = &.{
                // The base alone is dashed: the grid already marks 50%
                if (t.base.len == n) .none else chart.level(h, p, t.ref),
                chart.band(h, p, lo, hi),
                if (t.base.len == n) chart.line(h, p, t.base, .prev) else .none,
                chart.line(h, p, v, .typ),
            },
            .over = over.done(),
            .press = true,
            .on = .{
                .down = h.on(t, .plot),
                .move = h.on(t, .plot),
                .up = h.on(t, .plot),
                .leave = h.on(t, .plot),
                .cancel = h.on(t, .plot),
            },
        });
    }
};

/// Room left of the first point and right of the last, in steps, so their dots and labels
/// clear the plot's edges
const margin = 0.25;

pub const css =
    \\@layer components {
    \\  .c-trend .ln[data-k="typ"] { stroke: var(--t2); stroke-dasharray: none; }
    \\  .c-trend .xt { color: var(--t2); }
    \\  .c-trend .xt small { color: var(--faint); }
    \\}
    \\
;

/// Darius top, from the round 4 mock
pub const demo_patch = [_]Point{
    .{ .label = plain("16.19"), .sub = plain("32nd"), .v = 49.9, .ci = 2.7, .tip = plain("49.9% · pick 8.0% · 32nd of 61") },
    .{ .label = plain("16.20"), .sub = plain("49th"), .v = 48.7, .ci = 0.6, .tip = plain("48.7% of 23,166 · pick 7.6% · 49th of 59") },
    .{ .label = plain("16.21"), .sub = plain("3rd"), .v = 51.3, .ci = 1.2, .tip = plain("51.3% of 6,678 · pick 8.4% · 3rd of 58") },
};
pub const demo_length = [_]Point{
    .{ .label = plain("<20"), .sub = plain("2.3k"), .v = 49.1, .ci = 2.0, .tip = plain("min 49.1% of 2,299") },
    .{ .label = plain("20-25"), .sub = plain("4.6k"), .v = 50.6, .ci = 1.4, .tip = plain("min 50.6% of 4,642") },
    .{ .label = plain("25-30"), .sub = plain("9.9k"), .v = 48.7, .ci = 1.0, .tip = plain("min 48.7% of 9,926") },
    .{ .label = plain("30-35"), .sub = plain("8.6k"), .v = 50.0, .ci = 1.1, .tip = plain("min 50.0% of 8,607") },
    .{ .label = plain("35+"), .sub = plain("5.8k"), .v = 48.5, .ci = 1.3, .tip = plain("min 48.5% of 5,783") },
};
pub const demo_mastery = [_]Point{
    .{ .label = plain("<10k"), .sub = plain("2.2k"), .v = 48.7, .ci = 2.1, .tip = plain("points 48.7% of 2,200") },
    .{ .label = plain("10k"), .sub = plain("2.8k"), .v = 46.8, .ci = 1.9, .tip = plain("points 46.8% of 2,768") },
    .{ .label = plain("30k"), .sub = plain("5.5k"), .v = 49.2, .ci = 1.3, .tip = plain("points 49.2% of 5,545") },
    .{ .label = plain("100k"), .sub = plain("5.9k"), .v = 51.7, .ci = 1.3, .tip = plain("points 51.7% of 5,871") },
    .{ .label = plain("300k+"), .sub = plain("8.6k"), .v = 53.2, .ci = 1.1, .tip = plain("points 53.2% of 8,636") },
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const states = [_]struct { []const u8, Trend }{
        .{ "by patch, rank in role under each", .{ .label = plain("By patch"), .points = &demo_patch } },
        .{ "by game length, games under each; a point tapped", .{ .label = plain("By game length"), .points = &demo_length, .tip = 2 } },
        .{ "against a base, faint dashed (all lanes)", .{ .label = plain("Won by gold at 10"), .points = &demo_length, .base = &.{ 46, 48.5, 50, 51.5, 54 } } },
        .{ "OutcomeCurve: by mastery, against his own rate", .{ .label = plain("Pick-up"), .points = &demo_mastery, .ref = 49.3, .height = 110 } },
    };
    for (states) |s| {
        const t = h.mem.create(Trend) catch {
            h.oom = true;
            return;
        };
        t.* = s[1];
        g.addFill(s[0], t.view(h));
    }
}

const testing = std.testing;

test "the scale centres on the reference, whole ticks, at least ±4" {
    var t: Trend = .{ .label = plain("x"), .points = &demo_patch };
    const s = t.scale();
    try testing.expectEqual(@as(f32, 50), s.c);
    try testing.expectEqual(@as(f32, 4), s.step);
    try testing.expectEqual(@as(f32, 45), s.y.lo);
    const wide = [_]Point{ .{ .label = plain("a"), .v = 40, .ci = 3 }, .{ .label = plain("b"), .v = 52 } };
    t = .{ .label = plain("x"), .points = &wide, .ref = 49.3 };
    try testing.expectEqual(@as(f32, 50), t.scale().c);
    try testing.expectEqual(@as(f32, 15), t.scale().step);
    // A base far off widens the scale too
    t = .{ .label = plain("x"), .points = &demo_patch, .base = &.{ 50, 50, 60 } };
    try testing.expectEqual(@as(f32, 10), t.scale().step);
}

test "a tap picks the nearest point; leaving clears the tip" {
    var t: Trend = .{ .label = plain("x"), .points = &demo_length };
    // 5 points over -0.25..4.25: x 0.5 of the plot is point 2, 0.02 is point 0
    var ev: tree.Event = .{ .kind = .pointerdown, .x = 200, .w = 400 };
    t.update(.plot, &ev);
    try testing.expectEqual(@as(?u8, 2), t.tip);
    ev = .{ .kind = .pointermove, .x = 8, .w = 400 };
    t.update(.plot, &ev);
    try testing.expectEqual(@as(?u8, 2), t.tip);
    ev = .{ .kind = .pointerup, .x = 8, .w = 400 };
    t.update(.plot, &ev);
    ev = .{ .kind = .pointermove, .x = 8, .w = 400 };
    t.update(.plot, &ev);
    try testing.expectEqual(@as(?u8, 0), t.tip);
    ev = .{ .kind = .pointerleave, .x = 8, .w = 400 };
    t.update(.plot, &ev);
    try testing.expectEqual(@as(?u8, null), t.tip);
}
