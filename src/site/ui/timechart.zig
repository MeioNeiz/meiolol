//! TimeChart: ops series over clock time (matches stored per hour, requests per minute,
//! queue depth) on chart.zig's frame. Several series as lines, stacked areas or stacked
//! bars, one bucket each from `start`; a null breaks a line. Each series named at its
//! end, not in a legend; reference levels dashed with their name; events (crawler
//! restarts) as thin marks. Hover or tap shows the bucket's figures (ChartTip), a drag
//! zooms to its buckets, "Show all" goes back
const std = @import("std");
const tree = @import("tree.zig");
const fmt = @import("fmt.zig");
const phrase = @import("phrase.zig");
const chart = @import("chart.zig");
const civil = @import("yourlist.zig").civil;
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "TimeChart";
pub const scope = .{".c-time"};

pub const Kind = enum { line, area, bars };

/// How ticks and the tip write a value
pub const Unit = enum {
    /// 2.3k on the axis, 2,312 in the tip
    count,
    /// 53.4%
    rate,
    /// 0.693: model scores that move in the third decimal
    score,
};

pub const Series = struct {
    name: tree.Text,
    /// One per bucket from `start`; null where nothing was recorded
    values: []const ?f32,
};

pub const Ref = struct { v: f32, label: tree.Text };

pub const Time = struct {
    label: tree.Text,
    kind: Kind = .line,
    unit: Unit = .count,
    /// Unix seconds of the first bucket's start, and the bucket width
    start: i64,
    step: u32 = 3600,
    /// Seconds added for the clock the ticks read in (UK: 0 or 3600)
    offset: i32 = 0,
    series: []const Series,
    refs: []const Ref = &.{},
    /// Unix seconds of events drawn as thin marks (crawler restarts)
    marks: []const i64 = &.{},
    /// y around the data, not from zero
    fit: bool = false,
    height: u16 = 160,
    /// Buckets shown [a, b), after a drag; null for all
    zoom: ?[2]u32 = null,
    tip: ?u32 = null,
    drag: ?[2]f32 = null,
    press: chart.Press = .{},

    const T = @This();

    pub const Msg = union(enum) { plot, all };

    pub fn update(t: *T, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .all => {
                t.zoom = null;
                t.tip = null;
            },
            .plot => {
                const was = t.drag;
                switch (t.press.pointer(ev)) {
                    .hover, .tap => |f| {
                        t.drag = null;
                        t.tip = t.at(f);
                    },
                    .range => |r| {
                        t.drag = r;
                        t.tip = null;
                    },
                    .leave => {
                        t.drag = null;
                        t.tip = null;
                    },
                    .none => if (ev.kind == .pointerup) if (was) |r| {
                        t.drag = null;
                        t.zoomTo(r);
                    },
                }
            },
        }
    }

    fn len(t: *const T) u32 {
        var n: usize = 0;
        for (t.series) |s| n = @max(n, s.values.len);
        return @intCast(@min(n, std.math.maxInt(u32)));
    }

    /// The buckets shown, [a, b)
    fn window(t: *const T) [2]u32 {
        const n = t.len();
        if (t.zoom) |z| {
            const b = @min(z[1], n);
            if (z[0] + 1 < b) return .{ z[0], b };
        }
        return .{ 0, n };
    }

    /// The bucket under a fraction of the plot's width
    fn at(t: *const T, f: f32) ?u32 {
        const w = t.window();
        if (w[1] <= w[0]) return null;
        const k: u32 = @intFromFloat(@floor(std.math.clamp(f, 0, 1) * @as(f32, @floatFromInt(w[1] - w[0]))));
        return @min(w[0] + k, w[1] - 1);
    }

    fn zoomTo(t: *T, r: [2]f32) void {
        const w = t.window();
        const span: f32 = @floatFromInt(w[1] - w[0]);
        const a = w[0] + @as(u32, @intFromFloat(@floor(std.math.clamp(r[0], 0, 1) * span)));
        const b = w[0] + @as(u32, @intFromFloat(@ceil(std.math.clamp(r[1], 0, 1) * span)));
        if (b >= a + 2) t.zoom = .{ a, @min(b, w[1]) };
    }

    fn value(t: *const T, s: Series, i: u32) ?f32 {
        _ = t;
        if (i >= s.values.len) return null;
        const v = s.values[i] orelse return null;
        return if (std.math.isFinite(v)) v else null;
    }

    /// Bucket i's stack top below series k (stacked kinds), 0 at the floor
    fn under(t: *const T, k: usize, i: u32) f32 {
        var sum: f32 = 0;
        for (t.series[0..k]) |s| sum += @max(0, t.value(s, i) orelse 0);
        return sum;
    }

    fn scale(t: *const T, w: [2]u32) struct { y: chart.Scale, step: f32 } {
        var lo: f32 = std.math.inf(f32);
        var hi: f32 = -std.math.inf(f32);
        var i = w[0];
        while (i < w[1]) : (i += 1) {
            if (t.kind == .line) {
                for (t.series) |s| if (t.value(s, i)) |v| {
                    lo = @min(lo, v);
                    hi = @max(hi, v);
                };
            } else hi = @max(hi, t.under(t.series.len, i));
        }
        for (t.refs) |r| {
            lo = @min(lo, r.v);
            hi = @max(hi, r.v);
        }
        if (!(hi > -std.math.inf(f32))) return .{ .y = .{ .lo = 0, .hi = 4 }, .step = 1 };
        if (t.fit and t.kind == .line) {
            const st = chart.niceStep(@max(hi - lo, @abs(hi) * 0.01, 1e-6), 4);
            const base = @floor(lo / st) * st;
            var top = base + 4 * st;
            if (top < hi) top += st;
            return .{ .y = .{ .lo = base, .hi = top }, .step = st };
        }
        const st = chart.niceStep(@max(hi, 1e-6), 4);
        return .{ .y = .{ .lo = 0, .hi = @ceil(hi / st) * st }, .step = st };
    }

    pub fn view(t: *T, h: *H) N {
        const w = t.window();
        const any = blk: {
            var i = w[0];
            while (i < w[1]) : (i += 1) for (t.series) |s| if (t.value(s, i) != null) break :blk true;
            break :blk false;
        };
        // A zoom onto an outage keeps its way back
        if (!any) return h.el(.figure, .{ .class = "c-time", .role = "group", .aria_label = t.label }, .{ h.p(.{ .class = "note" }, .{W.none}), t.foot(h) });
        const s = t.scale(w);
        // Bucket i's centre at domain value i
        const p: chart.Plane = .{
            .x = .{ .lo = @as(f32, @floatFromInt(w[0])) - 0.5, .hi = @as(f32, @floatFromInt(w[1])) - 0.5 },
            .y = s.y,
        };
        var ys: std.ArrayList(chart.Tick) = .empty;
        var v = s.y.lo;
        while (v <= s.y.hi + s.step * 0.01) : (v += s.step) {
            ys.append(h.mem, .{ .at = p.py(v), .label = t.tick(h, v), .zero = v == 0 }) catch {
                h.oom = true;
            };
        }
        var marks = h.list();
        for (t.refs) |r| marks.add(chart.level(h, p, r.v));
        for (t.marks) |m| {
            const d = t.domain(m);
            if (d >= p.x.lo and d <= p.x.hi) marks.add(chart.span(h, p, d, d, "mark"));
        }
        var ends: std.ArrayList(End) = .empty;
        var over = h.list();
        for (t.series, 0..) |sr, k| {
            var lone = h.list();
            const kids = switch (t.kind) {
                .line => t.lines(h, p, sr, w, &lone),
                .area => t.areas(h, p, k, w),
                .bars => t.bars(h, p, k, w),
            };
            marks.add(h.el(.g, .{ .key = k, .data_s = if (t.series.len > 1) k else null }, .{kids}));
            if (lone.items.items.len > 0) over.add(h.span(.{ .key = 200 + k, .class = "lone", .data_s = if (t.series.len > 1) k else null }, .{lone.done()}));
            if (t.last(sr, w)) |li| {
                const top = if (t.kind == .line) t.value(sr, li) orelse 0 else t.under(k + 1, li);
                const mid = if (t.kind == .line) top else (top + t.under(k, li)) / 2;
                ends.append(h.mem, .{ .k = k, .y = p.py(mid), .v = t.value(sr, li) orelse 0 }) catch {
                    h.oom = true;
                };
            }
        }
        spread(ends.items);
        for (ends.items) |e| over.add(h.span(.{
            .key = e.k,
            .class = "end",
            .data_s = if (t.series.len > 1) e.k else null,
            .style = h.vars(.{ .y = e.y }),
        }, .{
            if (t.series.len > 1) t.series[e.k].name else null,
            if (t.series.len > 1) " " else null,
            h.b(.{}, .{t.exact(h, e.v)}),
        }));
        for (t.refs, 0..) |r, i| over.add(h.span(.{ .key = 100 + i, .class = "rl", .style = h.vars(.{ .y = p.py(r.v) }) }, .{r.label}));
        if (t.drag) |r| over.add(chart.range(h, r[0] * 100, r[1] * 100));
        if (t.tip) |i| if (i >= w[0] and i < w[1]) {
            var kids = h.list();
            kids.add(h.b(.{}, .{t.when(h, t.start + @as(i64, i) * t.step, true)}));
            for (t.series) |sr| if (t.value(sr, i)) |x| {
                kids.add(h.text(" · "));
                if (t.series.len > 1) kids.add(h.span(.{}, .{ sr.name, " " }));
                kids.add(h.text(t.exact(h, x).s));
            };
            for (chart.tip(h, p.px(i), .{kids.done()})) |x| over.add(x);
        };
        return chart.frame(h, .{
            .label = t.label,
            .class = "c-chart c-time",
            .height = t.height,
            .right = if (t.series.len > 1) 96 else 56,
            .y = ys.items,
            .x = t.ticks(h, p, w),
            .marks = marks.done(),
            .over = over.done(),
            .press = true,
            .on = .{
                .down = h.on(t, .plot),
                .move = h.on(t, .plot),
                .up = h.on(t, .plot),
                .leave = h.on(t, .plot),
                .cancel = h.on(t, .plot),
            },
            .foot = t.foot(h),
        });
    }

    fn foot(t: *T, h: *H) N {
        if (t.zoom == null) return .none;
        return h.div(.{ .class = "foot" }, .{
            h.button(.{ .class = "c-btn", .type = "button", .data_s = "s", .on_click = h.on(t, .all) }, .{W.all}),
        });
    }

    /// A unix time in the plot's domain (bucket centres at whole numbers)
    fn domain(t: *const T, at_s: i64) f32 {
        const step: f32 = @floatFromInt(@max(t.step, 1));
        return @as(f32, @floatFromInt(at_s - t.start)) / step - 0.5;
    }

    fn last(t: *const T, s: Series, w: [2]u32) ?u32 {
        var i = w[1];
        while (i > w[0]) {
            i -= 1;
            if (t.value(s, i) != null) return i;
        }
        return null;
    }

    /// A line per run of recorded buckets; a lone bucket a dot into `lone` (HTML: an SVG
    /// circle would stretch with the plot)
    fn lines(t: *const T, h: *H, p: chart.Plane, s: Series, w: [2]u32, lone: *tree.List) []const N {
        var l = h.list();
        var i = w[0];
        while (i < w[1]) {
            if (t.value(s, i) == null) {
                i += 1;
                continue;
            }
            const j = i;
            while (i < w[1] and t.value(s, i) != null) i += 1;
            const vs = h.mem.alloc(f32, i - j) catch {
                h.oom = true;
                return l.done();
            };
            for (vs, j..) |*x, b| x.* = t.value(s, @intCast(b)) orelse 0;
            // chart.line puts point 0 at the plane's 0: shift the plane to the run's start
            const q = shifted(p, j);
            if (vs.len > 1) l.add(chart.line(h, q, vs, .main)) else lone.add(chart.dot(h, p, j, vs[0], null));
        }
        return l.done();
    }

    /// Series k's band of the stack, with its top edge
    fn areas(t: *const T, h: *H, p: chart.Plane, k: usize, w: [2]u32) []const N {
        const n = w[1] - w[0];
        const vs = h.mem.alloc(f32, 2 * n) catch {
            h.oom = true;
            return &.{};
        };
        const lo = vs[0..n];
        const hi = vs[n..];
        for (lo, hi, w[0]..) |*a, *b, i| {
            a.* = t.under(k, @intCast(i));
            b.* = t.under(k + 1, @intCast(i));
        }
        const q = shifted(p, w[0]);
        const out = h.mem.alloc(N, 2) catch {
            h.oom = true;
            return &.{};
        };
        out[0] = chart.band(h, q, lo, hi);
        out[1] = chart.line(h, q, hi, .main);
        return out;
    }

    /// Series k's segment of each bucket's stacked bar
    fn bars(t: *const T, h: *H, p: chart.Plane, k: usize, w: [2]u32) []const N {
        var l = h.list();
        const bw = 100 / @as(f32, @floatFromInt(@max(w[1] - w[0], 1)));
        // A hairline gap between bars once they are wide enough to show one
        const gap: f32 = if (bw > 1.2) 0.15 * bw else 0;
        var i = w[0];
        while (i < w[1]) : (i += 1) {
            const v = t.value(t.series[k], i) orelse continue;
            if (v <= 0) continue;
            const b = t.under(k, i);
            const y0 = p.py(b + v);
            l.add(h.rect(.{ .key = i, .class = "bk", .x = p.px(i) - bw / 2 + gap / 2, .y = y0, .width = bw - gap, .height = @max(0, p.py(b) - y0) }, .{}));
        }
        return l.done();
    }

    fn tick(t: *const T, h: *H, v: f32) tree.Text {
        return switch (t.unit) {
            .count => phrase.num(h, .kilo, @as(u64, @intFromFloat(@max(0, @round(v))))),
            .rate => phrase.num(h, .rate, v),
            .score => score(h, v),
        };
    }

    fn exact(t: *const T, h: *H, v: f32) tree.Text {
        return switch (t.unit) {
            .count => phrase.num(h, .count, @as(u64, @intFromFloat(@max(0, @round(v))))),
            .rate => phrase.num(h, .rate, v),
            .score => score(h, v),
        };
    }

    /// "14:00", or "27 Oct" at midnight; `long` puts the day before the hour
    fn when(t: *const T, h: *H, at_s: i64, long: bool) tree.Text {
        const local = at_s + t.offset;
        const day: i32 = @intCast(@divFloor(local, 86400));
        const sec: u32 = @intCast(@mod(local, 86400));
        const c = civil(day);
        var out: std.Io.Writer.Allocating = .init(h.mem);
        const wr = &out.writer;
        const mon = months[@min(c.month -| 1, 11)];
        (if (long)
            wr.print("{d} {s} {d:0>2}:{d:0>2}", .{ c.day, mon, sec / 3600, sec / 60 % 60 })
        else if (sec == 0)
            wr.print("{d} {s}", .{ c.day, mon })
        else
            wr.print("{d:0>2}:{d:0>2}", .{ sec / 3600, sec / 60 % 60 })) catch {
            h.oom = true;
        };
        return .{ .s = out.written() };
    }

    /// Hour ticks while the window is under three days, else midnights; about six
    fn ticks(t: *const T, h: *H, p: chart.Plane, w: [2]u32) []const chart.Tick {
        const t0 = t.start + @as(i64, w[0]) * t.step;
        const t1 = t.start + @as(i64, w[1]) * t.step;
        var st: i64 = 7 * 86400;
        for ([_]i64{ 3600, 2 * 3600, 3 * 3600, 6 * 3600, 12 * 3600, 86400, 2 * 86400, 7 * 86400 }) |c| if (@divFloor(t1 - t0, c) <= 6) {
            st = c;
            break;
        };
        var l: std.ArrayList(chart.Tick) = .empty;
        // On the clock's whole steps: UK midnight, not UTC's
        var x = @divFloor(t0 + t.offset + st - 1, st) * st - t.offset;
        var k: u32 = 0;
        while (x <= t1 and l.items.len < 16) : ({
            x += st;
            k += 1;
        }) {
            const at_p = p.x.at(t.domain(x) + 0.5);
            if (at_p <= 0 or at_p >= 100) continue;
            l.append(h.mem, .{ .at = at_p, .label = t.when(h, x, false), .minor = k % 2 == 1 }) catch {
                h.oom = true;
            };
        }
        return l.items;
    }
};

const months = [_][]const u8{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };

const End = struct { k: usize, y: f32, v: f32 };

/// Moves end labels apart, top to bottom, so none sits within `gap` % of the one above
fn spread(es: []End) void {
    const gap = 11;
    std.mem.sort(End, es, {}, struct {
        fn lt(_: void, a: End, b: End) bool {
            return a.y < b.y;
        }
    }.lt);
    for (es, 0..) |*e, i| if (i > 0) {
        e.y = @max(e.y, es[i - 1].y + gap);
    };
    // Pushed past the floor: walk back up from it
    if (es.len > 0 and es[es.len - 1].y > 100) {
        es[es.len - 1].y = 100;
        var i = es.len - 1;
        while (i > 0) : (i -= 1) es[i - 1].y = @min(es[i - 1].y, es[i].y - gap);
    }
}

/// `p` moved so point 0 is bucket `j`
fn shifted(p: chart.Plane, j: u32) chart.Plane {
    const d: f32 = @floatFromInt(j);
    return .{ .x = .{ .lo = p.x.lo - d, .hi = p.x.hi - d }, .y = p.y };
}

fn score(h: *H, v: f32) tree.Text {
    var out: std.Io.Writer.Allocating = .init(h.mem);
    (if (v < 0) out.writer.writeAll("−") else {}) catch {
        h.oom = true;
    };
    fmt.fixed(&out.writer, @abs(v), 3, false) catch {
        h.oom = true;
    };
    return .{ .s = out.written() };
}

const W = struct {
    pub const none = plain("No data in this range");
    pub const all = plain("Show all");
};

pub const css =
    \\@layer components {
    \\  .c-time [data-s="0"] { --s: var(--us); }
    \\  .c-time [data-s="1"] { --s: var(--drop); }
    \\  .c-time [data-s="2"] { --s: var(--gain); }
    \\  .c-time [data-s="3"] { --s: var(--accent); }
    \\  .c-time [data-s="4"] { --s: var(--turn); }
    \\  .c-time [data-s="5"] { --s: var(--them); }
    \\  .c-time g .ln { stroke: var(--s, var(--text)); }
    \\  .c-time g .band { fill: var(--s, var(--text)); opacity: 0.35; }
    \\  .c-time .bk { fill: var(--s, var(--t2)); }
    \\  .c-time .lone .dot { --c: var(--s, var(--text)); width: 5px; height: 5px; margin: -2.5px 0 0 -2.5px; box-shadow: none; }
    \\  .c-time .mark { fill: var(--turn); opacity: 0.8; }
    \\  .c-time .end { color: var(--s, var(--text)); font-weight: var(--w-r); }
    \\  .c-time .end b { color: var(--text); font-weight: var(--w-m); }
    \\  .c-time .rl { position: absolute; left: 4px; top: calc(var(--y) * 1%); transform: translateY(-100%);
    \\    color: var(--muted); white-space: nowrap; pointer-events: none; }
    \\  .c-time .foot { display: flex; justify-content: flex-end; margin-top: var(--sp-1); }
    \\  .c-time > .note { margin: 0; color: var(--muted); font-size: var(--fs-s); }
    \\}
    \\
;

/// Three days of an EUW, EUN, NA crawl by hour, a restart, gaps in NA's around a lone hour
const demo = struct {
    const start = 1761350400; // 25 Oct 2025 00:00 UTC
    const euw = thrice(.{ 410, 395, 380, 352, 330, 318, 322, 351, 402, 455, 498, 512, 520, 516, 509, 511, 522, 540, 556, 571, 560, 532, 489, 441 });
    const eun = thrice(.{ 160, 150, 141, 133, 127, 125, 130, 142, 160, 181, 195, 203, 206, 204, 200, 201, 205, 213, 220, 226, 221, 210, 192, 174 });
    const na = thrice(.{ 220, 236, 250, 258, 262, 255, 240, 214, 188, 160, 138, 121, 110, 104, 101, 108, null, 130, null, 150, 171, 189, 204, 212 });
    const series = [_]Series{ .{ .name = plain("EUW1"), .values = &euw }, .{ .name = plain("EUN1"), .values = &eun }, .{ .name = plain("NA1"), .values = &na } };
    const loss = [_]?f32{ 0.6931, 0.6928, 0.6926, 0.6925, 0.6921, 0.6924, 0.6919, 0.6917, 0.6918, 0.6915, 0.6913, 0.6914 };
    const empty = [_]?f32{ null, null, null };

    fn thrice(day: [24]?f32) [72]?f32 {
        var o: [72]?f32 = undefined;
        for (0..3) |k| o[k * 24 ..][0..24].* = day;
        return o;
    }
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const states = [_]struct { []const u8, Time }{
        .{ "lines by region, a restart, NA's gaps", .{ .label = plain("Matches stored per hour"), .start = demo.start, .series = &demo.series, .marks = &.{demo.start + 30 * 3600} } },
        .{ "stacked area, a bucket tipped", .{ .label = plain("Timelines stored per hour"), .kind = .area, .start = demo.start, .series = &demo.series, .tip = 40 } },
        .{ "stacked bars, zoomed, against a limit", .{ .label = plain("Requests per minute"), .kind = .bars, .start = demo.start, .series = &demo.series, .refs = &.{.{ .v = 1000, .label = plain("Limit 1,000") }}, .zoom = .{ 30, 54 } } },
        .{ "one series fitted to its range, 6-hourly", .{ .label = plain("Validation loss"), .unit = .score, .fit = true, .start = demo.start, .step = 6 * 3600, .series = &.{.{ .name = plain("loss"), .values = &demo.loss }} } },
        .{ "nothing recorded", .{ .label = plain("Queue depth"), .start = demo.start, .series = &.{.{ .name = plain("queue"), .values = &demo.empty }} } },
    };
    for (states) |s| {
        const t = h.mem.create(Time) catch {
            h.oom = true;
            return;
        };
        t.* = s[1];
        g.addFill(s[0], t.view(h));
    }
}

const testing = std.testing;

const X = struct {
    arena: std.heap.ArenaAllocator,
    t: tree.Tree = .{},
    h: H = undefined,
    out: std.Io.Writer.Allocating = undefined,

    fn init(x: *X) void {
        x.* = .{ .arena = .init(testing.allocator) };
        x.h = .init(x.arena.allocator(), &x.t);
        x.out = .init(x.arena.allocator());
    }

    fn html(x: *X, t: *Time) ![]const u8 {
        x.out.clearRetainingCapacity();
        const root = t.view(&x.h);
        try testing.expect(!x.h.oom);
        try @import("html.zig").write(&x.t, root, &x.out.writer);
        return x.out.written();
    }
};

fn has(s: []const u8, want: []const []const u8, not: []const []const u8) !void {
    for (want) |w| if (std.mem.find(u8, s, w) == null) {
        std.debug.print("missing {s}\n", .{w});
        return error.TestExpectedEqual;
    };
    for (not) |w| if (std.mem.find(u8, s, w) != null) {
        std.debug.print("unwanted {s}\n", .{w});
        return error.TestExpectedEqual;
    };
}

test "scale: from zero to a nice top, stacks summed, fit around the data" {
    var t: Time = .{ .label = plain("x"), .start = 0, .series = &demo.series };
    var s = t.scale(.{ 0, 72 });
    try testing.expectEqual(@as(f32, 0), s.y.lo);
    try testing.expectEqual(@as(f32, 600), s.y.hi);
    t.kind = .bars;
    s = t.scale(.{ 0, 72 });
    // The tallest stack is 952 (hour 20: 560 + 221 + 171)
    try testing.expectEqual(@as(f32, 1000), s.y.hi);
    t = .{ .label = plain("x"), .start = 0, .series = &.{.{ .name = plain("l"), .values = &demo.loss }}, .fit = true };
    s = t.scale(.{ 0, 12 });
    // At least 1% of the value tall, as the old page: 0.690 to 0.698 in steps of 0.002
    try testing.expect(s.y.lo <= 0.6913 and s.y.lo >= 0.6899);
    try testing.expectApproxEqAbs(@as(f32, 0.698), s.y.hi, 1e-5);
    // A NaN is a gap, not a poisoned axis
    t = .{ .label = plain("x"), .start = 0, .series = &.{.{ .name = plain("n"), .values = &.{ 1, std.math.nan(f32), 3 } }} };
    try testing.expectEqual(@as(f32, 3), t.scale(.{ 0, 3 }).y.hi);
}

test "a drag zooms to its buckets, a tap tips one, Show all resets" {
    var t: Time = .{ .label = plain("x"), .start = 0, .series = &demo.series };
    var ev: tree.Event = .{ .kind = .pointerdown, .x = 100, .w = 720 };
    t.update(.plot, &ev);
    ev = .{ .kind = .pointermove, .x = 200, .w = 720 };
    t.update(.plot, &ev);
    try testing.expect(t.drag != null);
    ev = .{ .kind = .pointerup, .x = 200, .w = 720 };
    t.update(.plot, &ev);
    // 72 buckets over 720 px: 100..200 px is buckets 10..20
    try testing.expectEqual(@as(?[2]u32, .{ 10, 20 }), t.zoom);
    try testing.expectEqual(@as(?[2]f32, null), t.drag);
    ev = .{ .kind = .pointerdown, .x = 360, .w = 720 };
    t.update(.plot, &ev);
    ev = .{ .kind = .pointerup, .x = 360, .w = 720 };
    t.update(.plot, &ev);
    try testing.expectEqual(@as(?u32, 15), t.tip);
    t.update(.all, &ev);
    try testing.expectEqual(@as(?[2]u32, null), t.zoom);
    // A zoom past the data falls back to all of it
    t.zoom = .{ 80, 90 };
    try testing.expectEqual([2]u32{ 0, 72 }, t.window());
}

test "view: series named at their ends, gaps break lines, ticks on UK hours, tip" {
    var x: X = undefined;
    x.init();
    defer x.arena.deinit();
    var t: Time = .{ .label = plain("Matches"), .start = demo.start, .series = &demo.series, .marks = &.{demo.start + 30 * 3600}, .tip = 40, .offset = 3600 };
    var s = try x.html(&t);
    // NA's gaps split it into four runs and three lone hours
    try has(s, &.{ "class=\"mark\"", "EUW1 <b>441</b>", "NA1 <b>212</b>", "<b>26 Oct 17:00</b>", "<b>26 Oct 17:00</b> · <span>EUW1 </span>522", "26 Oct<", "aria-label=\"Matches\"" }, &.{ "Show all", "No data" });
    try testing.expectEqual(@as(usize, 2 + 4), std.mem.count(u8, s, "<path class=\"ln\""));
    try testing.expectEqual(@as(usize, 3), std.mem.count(u8, s, "class=\"dot\""));
    t = .{ .label = plain("Q"), .kind = .bars, .start = demo.start, .series = &demo.series, .zoom = .{ 30, 54 }, .refs = &.{.{ .v = 1000, .label = plain("Limit") }} };
    s = try x.html(&t);
    try has(s, &.{ "Show all", "class=\"bk\"", ">Limit<", "data-k=\"ref\"" }, &.{});
    try testing.expectEqual(@as(usize, 24 * 3 - 2), std.mem.count(u8, s, "class=\"bk\""));
    t = .{ .label = plain("Q"), .start = demo.start, .series = &.{.{ .name = plain("q"), .values = &demo.empty }} };
    s = try x.html(&t);
    try has(s, &.{"No data in this range"}, &.{ "<svg", "Show all" });
    // A drag across an outage: the note keeps Show all, and it goes back
    t.zoom = .{ 0, 2 };
    s = try x.html(&t);
    try has(s, &.{ "No data in this range", "Show all" }, &.{"<svg"});
    var ev: tree.Event = .{ .kind = .click };
    t.update(.all, &ev);
    try testing.expectEqual(@as(?[2]u32, null), t.zoom);
    t = .{ .label = plain("L"), .unit = .score, .fit = true, .start = demo.start, .series = &.{.{ .name = plain("l"), .values = &demo.loss }} };
    s = try x.html(&t);
    try has(s, &.{"<b>0.691</b>"}, &.{"data-s="});
}

test "spread keeps end labels apart and inside the plot" {
    var es = [_]End{ .{ .k = 0, .y = 50, .v = 0 }, .{ .k = 1, .y = 52, .v = 0 }, .{ .k = 2, .y = 98, .v = 0 } };
    spread(&es);
    try testing.expectEqual(@as(f32, 50), es[0].y);
    try testing.expectEqual(@as(f32, 61), es[1].y);
    try testing.expectEqual(@as(f32, 98), es[2].y);
    var low = [_]End{ .{ .k = 0, .y = 95, .v = 0 }, .{ .k = 1, .y = 97, .v = 0 } };
    spread(&low);
    try testing.expectEqual(@as(f32, 100), low[1].y);
    try testing.expectEqual(@as(f32, 89), low[0].y);
}
