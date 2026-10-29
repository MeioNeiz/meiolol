//! TimeChart: ops series over clock time (matches stored per hour, requests per minute,
//! queue depth) on chart.zig's frame. Several series as lines, stacked areas or stacked
//! bars, one bucket each from `start`; a null breaks a line. Each series named at its
//! end, not in a legend; reference levels dashed with their name; events (crawler
//! restarts) as thin marks. Hover or tap shows the bucket's figures (ChartTip), a drag
//! zooms to its buckets, "Show all" goes back. By keyboard the plot is a slider: arrows
//! step the tip, + zooms round it, - shows all; a hidden summary states what it draws
const std = @import("std");
const tree = @import("tree.zig");
const fmt = @import("fmt.zig");
const phrase = @import("phrase.zig");
const chart = @import("chart.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const Phrase = phrase.Phrase;
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
    /// 132.4 GB: sizes, the values in GB
    gb,
};

pub const Series = struct {
    name: tree.Text,
    /// One per bucket from `start`; null where nothing was recorded
    values: []const ?f32,
    /// Its colour (0-5), kept when the series beside it change (a region filter); null
    /// is its place
    colour: ?u8 = null,
};

pub const Ref = struct { v: f32, label: tree.Text };

/// The clock ticks and times read in. UK moves between GMT and BST, so a range over the
/// last Sunday of October or March has an hour more or less
pub const Clock = enum { utc, uk };

pub const Time = struct {
    label: tree.Text,
    kind: Kind = .line,
    unit: Unit = .count,
    /// Unix seconds of the first bucket's start, and the bucket width
    start: i64,
    step: u32 = 3600,
    clock: Clock = .uk,
    series: []const Series,
    refs: []const Ref = &.{},
    /// Unix seconds of events drawn as thin marks (crawler restarts), and what one is
    marks: []const i64 = &.{},
    mark: tree.Text = W.restart,
    /// y around the data, not from zero
    fit: bool = false,
    height: u16 = 160,
    /// Unix seconds shown [a, b), after a drag; null for all. Times, not buckets: a page
    /// that re-fetches a sliding window keeps showing the same stretch
    zoom: ?[2]i64 = null,
    tip: ?u32 = null,
    drag: ?[2]f32 = null,
    press: chart.Press = .{},

    const T = @This();

    pub const Msg = union(enum) { plot, all, key };

    pub fn update(t: *T, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .all => {
                t.zoom = null;
                t.tip = null;
            },
            .key => t.key(ev),
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

    /// Arrows step the tip (from the latest bucket), Home and End jump, + halves the window
    /// round the tip, - shows all, Escape drops the tip, then the zoom
    fn key(t: *T, ev: *tree.Event) void {
        const w = t.window();
        if (w[1] <= w[0]) return;
        const end = w[1] - 1;
        const cur = if (t.tip) |i| std.math.clamp(i, w[0], end) else end;
        const k = ev.text;
        if (eql(k, "ArrowLeft")) {
            t.tip = if (cur > w[0]) cur - 1 else cur;
        } else if (eql(k, "ArrowRight")) {
            t.tip = if (t.tip == null) end else @min(cur + 1, end);
        } else if (eql(k, "Home")) {
            t.tip = w[0];
        } else if (eql(k, "End")) {
            t.tip = end;
        } else if (eql(k, "+") or eql(k, "=")) {
            const half = (w[1] - w[0]) / 2;
            if (half < 2) return;
            const a = std.math.clamp(cur -| half / 2, w[0], w[1] - half);
            t.zoom = .{ t.time(a), t.time(a + half) };
            t.tip = cur;
        } else if (eql(k, "-")) {
            if (t.zoom == null) return;
            t.zoom = null;
        } else if (eql(k, "Escape")) {
            if (t.tip != null) t.tip = null else if (t.zoom != null) t.zoom = null else return;
        } else return;
        ev.handled = true;
    }

    /// The bucket width, never 0
    fn st(t: *const T) i64 {
        return @max(t.step, 1);
    }

    /// Bucket i's start
    fn time(t: *const T, i: u32) i64 {
        return t.start +| @as(i64, i) * t.st();
    }

    fn off(t: *const T, at_s: i64) i64 {
        return switch (t.clock) {
            .utc => 0,
            .uk => ukOffset(at_s),
        };
    }

    fn len(t: *const T) u32 {
        var n: usize = 0;
        for (t.series) |s| n = @max(n, s.values.len);
        return @intCast(@min(n, std.math.maxInt(u32)));
    }

    /// The buckets shown, [a, b): every bucket the zoom's times touch, all of them when
    /// that is under two
    fn window(t: *const T) [2]u32 {
        const n = t.len();
        if (t.zoom) |z| {
            const a = std.math.clamp(@divFloor(z[0] -| t.start, t.st()), 0, n);
            const b = std.math.clamp(0 -| @divFloor(t.start -| z[1], t.st()), 0, n);
            if (b >= a + 2) return .{ @intCast(a), @intCast(b) };
        }
        return .{ 0, n };
    }

    /// The bucket under a fraction of the plot's width
    fn at(t: *const T, f: f32) ?u32 {
        const w = t.window();
        if (w[1] <= w[0] or std.math.isNan(f)) return null;
        const k: u32 = @intFromFloat(@floor(std.math.clamp(f, 0, 1) * @as(f32, @floatFromInt(w[1] - w[0]))));
        return @min(w[0] + k, w[1] - 1);
    }

    /// A drag under two buckets wide is ignored
    fn zoomTo(t: *T, r: [2]f32) void {
        if (std.math.isNan(r[0]) or std.math.isNan(r[1])) return;
        const w = t.window();
        const span: f32 = @floatFromInt(w[1] - w[0]);
        const a = w[0] + @as(u32, @intFromFloat(@floor(std.math.clamp(r[0], 0, 1) * span)));
        const b = @min(w[0] + @as(u32, @intFromFloat(@ceil(std.math.clamp(r[1], 0, 1) * span))), w[1]);
        if (b >= a + 2) t.zoom = .{ t.time(a), t.time(b) };
    }

    fn value(t: *const T, s: Series, i: u32) ?f32 {
        _ = t;
        if (i >= s.values.len) return null;
        const v = s.values[i] orelse return null;
        return if (std.math.isFinite(v)) v else null;
    }

    /// Bucket i's stack top below series k (stacked kinds), 0 at the floor: a null or
    /// negative value stacks as 0
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
        for (t.refs) |r| if (std.math.isFinite(r.v)) {
            lo = @min(lo, r.v);
            hi = @max(hi, r.v);
        };
        if (!(hi > -std.math.inf(f32))) return .{ .y = .{ .lo = 0, .hi = 4 }, .step = 1 };
        // A stack summed past f32's range, or a 1e30: still an axis niceStep can walk
        lo = @max(lo, -1e15);
        hi = @min(hi, 1e15);
        if (t.fit and t.kind == .line) {
            const s = t.whole(chart.niceStep(@max(hi - lo, @abs(hi) * 0.01, 1e-6), 4));
            const base = @floor(lo / s) * s;
            var top = base + 4 * s;
            if (top < hi) top += s;
            return .{ .y = .{ .lo = base, .hi = top }, .step = s };
        }
        // From zero; a line below it (a signed score) takes the axis down with it
        const a = if (t.kind == .line) @min(0, lo) else 0;
        const b = @max(0, hi);
        const s = t.whole(chart.niceStep(if (b > a) b - a else 1, 4));
        const base = @floor(a / s) * s;
        return .{ .y = .{ .lo = base, .hi = @max(@ceil(b / s) * s, base + s) }, .step = s };
    }

    /// A count's ticks a whole number apart, so none repeat a label
    fn whole(t: *const T, s: f32) f32 {
        return if (t.unit == .count) @max(s, 1) else s;
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
        // Bucket i's centre at domain value i: a time at the bucket it starts, as its point
        const p: chart.Plane = .{
            .x = .{ .lo = @as(f32, @floatFromInt(w[0])) - 0.5, .hi = @as(f32, @floatFromInt(w[1])) - 0.5 },
            .y = s.y,
        };
        var ys: std.ArrayList(chart.Tick) = .empty;
        const nt: usize = @intFromFloat(@min(@round((s.y.hi - s.y.lo) / s.step), 20));
        for (0..nt + 1) |i| {
            const raw = s.y.lo + @as(f32, @floatFromInt(i)) * s.step;
            const zero = @abs(raw) < s.step * 1e-3;
            const v = if (zero) 0 else raw;
            ys.append(h.mem, .{ .at = p.py(v), .label = t.tick(h, v), .zero = zero }) catch {
                h.oom = true;
            };
        }
        const t0 = t.time(w[0]);
        const t1 = t.time(w[1]);
        var marks = h.list();
        for (t.refs) |r| if (std.math.isFinite(r.v)) marks.add(chart.level(h, p, r.v));
        for (t.marks) |m| if (m >= t0 and m < t1) {
            const d = @min(t.domain(m), p.x.hi);
            marks.add(chart.span(h, p, d, d, "mark"));
        };
        // One bucket has no width to fill: bars draw it
        const kind: Kind = if (t.kind == .area and w[1] - w[0] < 2) .bars else t.kind;
        var ends: std.ArrayList(End) = .empty;
        var over = h.list();
        var most: usize = 0;
        for (t.series, 0..) |sr, k| {
            var lone = h.list();
            const kids = switch (kind) {
                .line => t.lines(h, p, sr, w, &lone),
                .area => t.areas(h, p, k, w),
                .bars => t.bars(h, p, k, w),
            };
            // Six colours, then round again: past six, only the end names tell lines apart
            const ds = t.shade(k);
            marks.add(h.el(.g, .{ .key = k, .data_s = ds }, .{kids}));
            if (lone.items.items.len > 0) over.add(h.span(.{ .key = 200 + k, .class = "lone", .data_s = ds }, .{lone.done()}));
            most = @max(most, sr.name.s.len);
            if (t.last(sr, w)) |li| {
                const top = if (t.kind == .line) t.value(sr, li) orelse 0 else t.under(k + 1, li);
                const mid = if (t.kind == .line) top else (top + t.under(k, li)) / 2;
                ends.append(h.mem, .{ .k = k, .y = p.py(mid), .v = t.value(sr, li) orelse 0 }) catch {
                    h.oom = true;
                };
            }
        }
        spread(ends.items);
        // Hidden from screen readers: the summary has the latest figures with their times
        for (ends.items) |e| over.add(h.span(.{
            .key = e.k,
            .class = "end",
            .data_s = t.shade(e.k),
            .aria_hidden = true,
            .style = h.vars(.{ .y = e.y }),
        }, .{
            if (t.series.len > 1) t.series[e.k].name else null,
            if (t.series.len > 1) " " else null,
            h.b(.{}, .{t.exact(h, e.v)}),
        }));
        for (t.refs, 0..) |r, i| if (std.math.isFinite(r.v)) over.add(h.span(.{ .key = 100 + i, .class = "rl", .style = h.vars(.{ .y = p.py(r.v) }) }, .{r.label}));
        if (t.drag) |r| over.add(chart.range(h, r[0] * 100, r[1] * 100));
        if (t.tip) |i| if (i >= w[0] and i < w[1]) {
            var kids = h.list();
            kids.add(h.b(.{}, .{t.when(h, t.time(i), true)}));
            for (t.series) |sr| if (t.value(sr, i)) |x| {
                kids.add(h.text(" · "));
                if (t.series.len > 1) kids.add(h.span(.{}, .{ sr.name, " " }));
                kids.add(h.text(t.exact(h, x).s));
            };
            for (chart.tip(h, p.px(i), .{kids.done()})) |x| over.add(x);
        };
        // The keyboard's way in: a slider over the plot, stepping the tip
        const now = if (t.tip) |i| std.math.clamp(i, w[0], w[1] - 1) else w[1] - 1;
        over.add(h.span(.{
            .key = 300,
            .class = "kb",
            .tabindex = @as(u8, 0),
            .role = "slider",
            .aria_label = t.label,
            .aria_valuemin = w[0],
            .aria_valuemax = w[1] - 1,
            .aria_valuenow = now,
            .aria_valuetext = t.reading(h, now),
        }, .{}));
        return chart.frame(h, .{
            .label = t.label,
            .class = "c-chart c-time",
            .height = t.height,
            // Room for the longest "name 1,234", within reason at 320 px
            .right = if (t.series.len > 1) @intCast(std.math.clamp(7 * (most + 6), 96, 140)) else 56,
            .y = ys.items,
            .x = t.ticks(h, p, w),
            .above = &.{h.p(.{ .class = "sr" }, .{t.summary(h, w)})},
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
            .on_key = h.on(t, .key),
            .foot = t.foot(h),
        });
    }

    /// Show all, while the zoom hides some buckets: a re-fetched window can leave a zoom
    /// that no longer does
    fn foot(t: *T, h: *H) N {
        const w = t.window();
        if (t.zoom == null or (w[0] == 0 and w[1] == t.len())) return .none;
        return h.div(.{ .class = "foot" }, .{
            h.button(.{ .class = "c-btn", .type = "button", .data_s = "s", .on_click = h.on(t, .all) }, .{W.all}),
        });
    }

    fn shade(t: *const T, k: usize) ?usize {
        if (t.series[k].colour) |c| return c % 6;
        return if (t.series.len > 1) k % 6 else null;
    }

    /// A unix time in the plot's domain: bucket i's start at i, where its point is
    fn domain(t: *const T, at_s: i64) f32 {
        return @as(f32, @floatFromInt(at_s -| t.start)) / @as(f32, @floatFromInt(t.st()));
    }

    /// The slider's value: "26 Oct 16:00: EUW1 522, EUN1 205"
    fn reading(t: *const T, h: *H, i: u32) tree.Text {
        var out: std.Io.Writer.Allocating = .init(h.mem);
        const wr = &out.writer;
        (blk: {
            wr.writeAll(t.when(h, t.time(i), true).s) catch |e| break :blk e;
            var first = true;
            for (t.series) |sr| if (t.value(sr, i)) |v| {
                wr.writeAll(if (first) ": " else ", ") catch |e| break :blk e;
                first = false;
                if (t.series.len > 1) wr.print("{s} ", .{sr.name.s}) catch |e| break :blk e;
                wr.writeAll(t.exact(h, v).s) catch |e| break :blk e;
            };
            if (first) wr.print(", {s}", .{W.gap.s}) catch |e| break :blk e;
        }) catch {
            h.oom = true;
        };
        return .{ .s = out.written() };
    }

    /// What the svg draws, for screen readers: the range, each series' latest figure, the
    /// marks in it
    fn summary(t: *const T, h: *H, w: [2]u32) tree.Text {
        var out: std.Io.Writer.Allocating = .init(h.mem);
        const wr = &out.writer;
        (blk: {
            wr.print("{s} {s} {s}.", .{ t.when(h, t.time(w[0]), true).s, W.to.s, t.when(h, t.time(w[1] - 1), true).s }) catch |e| break :blk e;
            var first = true;
            for (t.series) |sr| if (t.last(sr, w)) |i| {
                wr.writeAll(if (first) " " ++ W.latest.s ++ " " else ", ") catch |e| break :blk e;
                first = false;
                if (t.series.len > 1) wr.print("{s} ", .{sr.name.s}) catch |e| break :blk e;
                wr.writeAll(t.exact(h, t.value(sr, i) orelse 0).s) catch |e| break :blk e;
                // Older than the last bucket: say when
                if (i + 1 < w[1]) wr.print(" {s} {s}", .{ W.at.s, t.when(h, t.time(i), true).s }) catch |e| break :blk e;
            };
            if (!first) wr.writeByte('.') catch |e| break :blk e;
            const t0 = t.time(w[0]);
            const t1 = t.time(w[1]);
            // The first few marks by time, then how many more
            const cap = 5;
            var n: usize = 0;
            for (t.marks) |m| if (m >= t0 and m < t1) {
                if (n == 0) {
                    wr.print(" {s} {s}", .{ t.mark.s, t.when(h, m, true).s }) catch |e| break :blk e;
                } else if (n < cap) wr.print(", {s}", .{t.when(h, m, true).s}) catch |e| break :blk e;
                n += 1;
            };
            if (n > cap) wr.print(" {s} {d} {s}", .{ W.@"and".s, n - cap, W.more.s }) catch |e| break :blk e;
            if (n > 0) wr.writeByte('.') catch |e| break :blk e;
        }) catch {
            h.oom = true;
        };
        return .{ .s = out.written() };
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
        // At least a pixel tall: a small figure on a big stack still shows
        const px1 = 100 / @as(f32, @floatFromInt(@max(t.height, 1)));
        var i = w[0];
        while (i < w[1]) : (i += 1) {
            const v = t.value(t.series[k], i) orelse continue;
            if (v <= 0) continue;
            const y1 = p.py(t.under(k, i));
            const ht = @max(y1 - p.py(t.under(k + 1, i)), px1);
            l.add(h.rect(.{ .key = i, .class = "bk", .x = p.px(i) - bw / 2 + gap / 2, .y = y1 - ht, .width = bw - gap, .height = ht }, .{}));
        }
        return l.done();
    }

    fn tick(t: *const T, h: *H, v: f32) tree.Text {
        return switch (t.unit) {
            .count => phrase.num(h, .kilo, count(v)),
            .rate => phrase.num(h, .rate, v),
            .score => score(h, v),
            .gb => W.gb.with(h, .{ .n = v }),
        };
    }

    fn exact(t: *const T, h: *H, v: f32) tree.Text {
        return switch (t.unit) {
            .count => phrase.num(h, .count, count(v)),
            .rate => phrase.num(h, .rate, v),
            .score => score(h, v),
            .gb => W.gb.with(h, .{ .n = v }),
        };
    }

    /// "14:00", or "27 Oct" at midnight; `long` puts the day before the hour
    fn when(t: *const T, h: *H, at_s: i64, long: bool) tree.Text {
        const local = at_s +| t.off(at_s);
        const sec: u32 = @intCast(@mod(local, 86400));
        const c = fmt.civil(dayOf(local));
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

    /// About six ticks, on the clock's whole minutes, hours or midnights
    fn ticks(t: *const T, h: *H, p: chart.Plane, w: [2]u32) []const chart.Tick {
        const t0 = t.time(w[0]);
        const t1 = t.time(w[1]);
        const every = t.tickStep(t1 - t0);
        var l: std.ArrayList(chart.Tick) = .empty;
        var prev: i64 = std.math.minInt(i64);
        // Up to an hour, UTC's whole steps are the clock's (offsets are whole hours), and the
        // hour BST gives back is ticked twice. Longer, walk the clock's own time (UK
        // midnight, not UTC's), each tick back to UTC by the offset there
        const local = every > 3600;
        var u = @divFloor((if (local) t0 +| t.off(t0) else t0) +| (every - 1), every) * every;
        while (l.items.len < 16) : (u +|= every) {
            const x = if (local) u - t.off(u - t.off(u)) else u;
            if (x > t1) break;
            if (x <= prev) continue;
            prev = x;
            const at_p = p.x.at(t.domain(x));
            if (at_p <= 0 or at_p >= 100) continue;
            // A narrow chart keeps every other tick: those on a double step of the printed
            // time, so midnights stay among 12-hourly ones
            l.append(h.mem, .{ .at = at_p, .label = t.when(h, x, false), .minor = @mod(x +| t.off(x), 2 * every) != 0 }) catch {
                h.oom = true;
            };
        }
        return l.items;
    }

    /// The first step no finer than a bucket that gives six ticks or fewer; past four weeks,
    /// a sixth of the span in whole days
    fn tickStep(t: *const T, span: i64) i64 {
        const hr = 3600;
        const day = 86400;
        for ([_]i64{ 60, 300, 600, 900, 1800, hr, 2 * hr, 3 * hr, 6 * hr, 12 * hr, day, 2 * day, 7 * day, 14 * day, 28 * day }) |c| {
            if (c >= t.st() and @divFloor(span, c) <= 6) return c;
        }
        return @max(@divFloor(span + 6 * day - 1, 6 * day), 1) * day;
    }
};

fn eql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

/// A count for phrase.num: NaN and negatives 0, past u64 clamped
fn count(v: f32) u64 {
    if (!(v > 0)) return 0;
    return @intFromFloat(@min(@round(v), 1.8e19));
}

fn dayOf(at_s: i64) i32 {
    return @intCast(std.math.clamp(@divFloor(at_s, 86400), 0, std.math.maxInt(i32)));
}

/// BST: from 01:00 UTC on March's last Sunday to 01:00 UTC on October's
pub fn ukOffset(at_s: i64) i64 {
    const y: i64 = fmt.civil(dayOf(at_s)).year;
    const on = lastSunday(y, 3) * 86400 + 3600;
    const end = lastSunday(y, 10) * 86400 + 3600;
    return if (at_s >= on and at_s < end) 3600 else 0;
}

/// Day count since 1970 of month m's last Sunday (March and October: 31 days)
fn lastSunday(y: i64, m: i64) i64 {
    const d = days(y, m, 31);
    // 1 January 1970 was a Thursday: d + 4 is 0 on a Sunday
    return d - @mod(d + 4, 7);
}

/// Days since 1970-01-01 of a civil date (Hinnant's days_from_civil)
fn days(y0: i64, m: i64, d: i64) i64 {
    const y = if (m <= 2) y0 - 1 else y0;
    const era = @divFloor(y, 400);
    const yoe = y - era * 400;
    const doy = @divFloor(153 * @mod(m + 9, 12) + 2, 5) + d - 1;
    const doe = yoe * 365 + @divFloor(yoe, 4) - @divFloor(yoe, 100) + doy;
    return era * 146097 + doe - 719468;
}

const months = [_][]const u8{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };

const End = struct { k: usize, y: f32, v: f32 };

/// Moves end labels apart, top to bottom, so none sits within `gap` % of the one above;
/// with many, the gap shrinks so all fit
fn spread(es: []End) void {
    const gap: f32 = if (es.len > 1) @min(11, 100 / @as(f32, @floatFromInt(es.len - 1))) else 11;
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
        while (i > 0) : (i -= 1) es[i - 1].y = @max(0, @min(es[i - 1].y, es[i].y - gap));
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
    pub const gb = Phrase("{n:dec} GB");
    pub const all = plain("Show all");
    pub const restart = plain("Restart");
    pub const to = plain("to");
    pub const latest = plain("Latest");
    pub const gap = plain("nothing recorded");
    pub const at = plain("at");
    pub const @"and" = plain("and");
    pub const more = plain("more");
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
    \\  .c-time .kb { position: absolute; inset: 0; pointer-events: none; border-radius: 2px; }
    \\  .c-time .kb:focus-visible { outline: 2px solid var(--focus); outline-offset: 2px; }
    \\  .c-time .sr { position: absolute; width: 1px; height: 1px; overflow: hidden; clip-path: inset(50%); white-space: nowrap; }
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
        .{ "stacked bars, zoomed, against a limit", .{ .label = plain("Requests per minute"), .kind = .bars, .start = demo.start, .series = &demo.series, .refs = &.{.{ .v = 1000, .label = plain("Limit 1,000") }}, .zoom = .{ demo.start + 30 * 3600, demo.start + 54 * 3600 } } },
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
    t = .{ .label = plain("x"), .unit = .score, .start = 0, .series = &.{.{ .name = plain("l"), .values = &demo.loss }}, .fit = true };
    s = t.scale(.{ 0, 12 });
    // At least 1% of the value tall, as the old page: 0.690 to 0.698 in steps of 0.002
    try testing.expect(s.y.lo <= 0.6913 and s.y.lo >= 0.6899);
    try testing.expectApproxEqAbs(@as(f32, 0.698), s.y.hi, 1e-5);
    // A NaN is a gap, not a poisoned axis
    t = .{ .label = plain("x"), .start = 0, .series = &.{.{ .name = plain("n"), .values = &.{ 1, std.math.nan(f32), 3 } }} };
    try testing.expectEqual(@as(f32, 3), t.scale(.{ 0, 3 }).y.hi);
}

fn drag(t: *Time, a: f32, b: f32) !void {
    var ev: tree.Event = .{ .kind = .pointerdown, .x = a, .w = 720 };
    t.update(.plot, &ev);
    ev = .{ .kind = .pointermove, .x = b, .w = 720 };
    t.update(.plot, &ev);
    try testing.expect(t.drag != null);
    ev = .{ .kind = .pointerup, .x = b, .w = 720 };
    t.update(.plot, &ev);
    try testing.expectEqual(@as(?[2]f32, null), t.drag);
}

fn press(t: *Time, k: []const u8) bool {
    var ev: tree.Event = .{ .kind = .keydown, .text = k };
    t.update(.key, &ev);
    return ev.handled;
}

test "a drag zooms to its buckets' times, a tap tips one, Show all resets" {
    var t: Time = .{ .label = plain("x"), .start = 0, .series = &demo.series };
    try drag(&t, 100, 200);
    // 72 buckets over 720 px: 100..200 px is buckets 10..20
    try testing.expectEqual(@as(?[2]i64, .{ 10 * 3600, 20 * 3600 }), t.zoom);
    var ev: tree.Event = .{ .kind = .pointerdown, .x = 360, .w = 720 };
    t.update(.plot, &ev);
    ev = .{ .kind = .pointerup, .x = 360, .w = 720 };
    t.update(.plot, &ev);
    try testing.expectEqual(@as(?u32, 15), t.tip);
    t.update(.all, &ev);
    try testing.expectEqual(@as(?[2]i64, null), t.zoom);
    // Under two buckets wide: ignored
    try drag(&t, 100, 108);
    try testing.expectEqual(@as(?[2]i64, null), t.zoom);
    // Released past the plot: to its end
    try drag(&t, 360, 900);
    try testing.expectEqual(@as(?[2]i64, .{ 36 * 3600, 72 * 3600 }), t.zoom);
    // A zoom past the data falls back to all of it
    t.zoom = .{ 80 * 3600, 90 * 3600 };
    try testing.expectEqual([2]u32{ 0, 72 }, t.window());
    // Times between bucket starts take every bucket they touch
    t.zoom = .{ 10 * 3600 + 1, 12 * 3600 - 1 };
    try testing.expectEqual([2]u32{ 10, 12 }, t.window());
    // The page re-fetched the series an hour on: the same times, a bucket earlier
    t.start = 3600;
    t.zoom = .{ 10 * 3600, 20 * 3600 };
    try testing.expectEqual([2]u32{ 9, 19 }, t.window());
    try testing.expectEqual(@as(?u32, null), t.at(std.math.nan(f32)));
}

test "keys: arrows step the tip from the latest, + zooms round it, - and Escape go back" {
    var t: Time = .{ .label = plain("x"), .start = 0, .series = &demo.series };
    try testing.expect(press(&t, "ArrowLeft"));
    try testing.expectEqual(@as(?u32, 70), t.tip);
    _ = press(&t, "Home");
    _ = press(&t, "ArrowLeft");
    try testing.expectEqual(@as(?u32, 0), t.tip);
    _ = press(&t, "End");
    _ = press(&t, "ArrowRight");
    try testing.expectEqual(@as(?u32, 71), t.tip);
    t.tip = 40;
    try testing.expect(press(&t, "+"));
    try testing.expectEqual([2]u32{ 22, 58 }, t.window());
    _ = press(&t, "+");
    try testing.expectEqual([2]u32{ 31, 49 }, t.window());
    try testing.expectEqual(@as(?u32, 40), t.tip);
    try testing.expect(press(&t, "Escape"));
    try testing.expectEqual(@as(?u32, null), t.tip);
    try testing.expect(press(&t, "Escape"));
    try testing.expectEqual(@as(?[2]i64, null), t.zoom);
    try testing.expect(!press(&t, "Escape"));
    try testing.expect(!press(&t, "-"));
    try testing.expect(!press(&t, "x"));
    _ = press(&t, "+");
    try testing.expect(press(&t, "-"));
    try testing.expectEqual(@as(?[2]i64, null), t.zoom);
    // + at the right edge keeps the window on the data; = is +, unshifted
    t.tip = 71;
    try testing.expect(press(&t, "="));
    try testing.expectEqual([2]u32{ 36, 72 }, t.window());
    _ = press(&t, "Home");
    try testing.expectEqual(@as(?u32, 36), t.tip);
    _ = press(&t, "End");
    try testing.expectEqual(@as(?u32, 71), t.tip);
    // A tip a re-fetch left outside the window steps from its edge
    t.tip = 5;
    _ = press(&t, "ArrowRight");
    try testing.expectEqual(@as(?u32, 37), t.tip);
    // Too few buckets to halve; none at all
    var few: Time = .{ .label = plain("x"), .start = 0, .series = &.{.{ .name = plain("f"), .values = &.{ 1, 2, 3 } }} };
    try testing.expect(!press(&few, "+"));
    try testing.expect(!press(&few, "-"));
    var none: Time = .{ .label = plain("x"), .start = 0, .series = &.{} };
    try testing.expect(!press(&none, "ArrowLeft"));
}

test "view: series named at their ends, gaps break lines, ticks on UK hours, tip, summary" {
    var x: X = undefined;
    x.init();
    defer x.arena.deinit();
    var t: Time = .{ .label = plain("Matches"), .start = demo.start, .series = &demo.series, .marks = &.{demo.start + 30 * 3600}, .tip = 40 };
    var s = try x.html(&t);
    // NA's gaps split it into four runs and three lone hours. Bucket 40 is after the
    // switch to GMT (26 Oct 01:00 UTC): 16:00 UTC reads 16:00
    try has(s, &.{
        "class=\"mark\"",
        "EUW1 <b>441</b>",
        "NA1 <b>212</b>",
        "<b>26 Oct 16:00</b> · <span>EUW1 </span>522",
        "26 Oct<",
        "aria-label=\"Matches\"",
        "role=\"slider\"",
        "aria-valuetext=\"26 Oct 16:00: EUW1 522, EUN1 205\"",
        "25 Oct 01:00 to 27 Oct 23:00. Latest EUW1 441, EUN1 174, NA1 212. Restart 26 Oct 06:00.",
    }, &.{ "Show all", "No data" });
    try testing.expectEqual(@as(usize, 2 + 4), std.mem.count(u8, s, "<path class=\"ln\""));
    try testing.expectEqual(@as(usize, 3), std.mem.count(u8, s, "class=\"dot\""));
    t = .{ .label = plain("Q"), .kind = .bars, .start = demo.start, .series = &demo.series, .zoom = .{ demo.start + 30 * 3600, demo.start + 54 * 3600 }, .refs = &.{.{ .v = 1000, .label = plain("Limit") }} };
    s = try x.html(&t);
    try has(s, &.{ "Show all", "class=\"bk\"", ">Limit<", "data-k=\"ref\"" }, &.{});
    try testing.expectEqual(@as(usize, 24 * 3 - 2), std.mem.count(u8, s, "class=\"bk\""));
    t = .{ .label = plain("Q"), .start = demo.start, .series = &.{.{ .name = plain("q"), .values = &demo.empty }} };
    s = try x.html(&t);
    try has(s, &.{"No data in this range"}, &.{ "<svg", "Show all" });
    // A drag across an outage: the note keeps Show all, and it goes back
    t.zoom = .{ demo.start, demo.start + 2 * 3600 };
    s = try x.html(&t);
    try has(s, &.{ "No data in this range", "Show all" }, &.{"<svg"});
    var ev: tree.Event = .{ .kind = .click };
    t.update(.all, &ev);
    try testing.expectEqual(@as(?[2]i64, null), t.zoom);
    // A zoom a re-fetch left behind the data shows it all, so no Show all; a stale tip
    // puts the slider at the last bucket
    t = .{ .label = plain("M"), .start = demo.start, .series = &demo.series, .zoom = .{ demo.start + 80 * 3600, demo.start + 90 * 3600 }, .tip = 100 };
    try has(try x.html(&t), &.{"aria-valuenow=\"71\""}, &.{"Show all"});
    // A series that stopped early says when; marks past five are counted
    var marks: [7]i64 = undefined;
    for (&marks, 0..) |*m, i| m.* = demo.start + @as(i64, @intCast(i)) * 3600;
    t = .{ .label = plain("S"), .start = demo.start, .series = &.{.{ .name = plain("s"), .values = &.{ 1, 2, null, null, null, null, null, null } }}, .marks = &marks };
    try has(try x.html(&t), &.{"Latest 2 at 25 Oct 02:00. Restart 25 Oct 01:00, 25 Oct 02:00, 25 Oct 03:00, 25 Oct 04:00, 25 Oct 05:00 and 2 more."}, &.{});
    t = .{ .label = plain("L"), .unit = .score, .fit = true, .start = demo.start, .series = &.{.{ .name = plain("l"), .values = &demo.loss }} };
    s = try x.html(&t);
    try has(s, &.{"<b>0.691</b>"}, &.{"data-s="});
}

test "UK clock: BST until 01:00 UTC on October's last Sunday, one 01:00 tick after" {
    try testing.expectEqual(@as(i64, 0), days(1970, 1, 1));
    // 30 March and 26 October 2025
    try testing.expectEqual(@as(i64, 20177), lastSunday(2025, 3));
    try testing.expectEqual(@as(i64, 20387), lastSunday(2025, 10));
    try testing.expectEqual(@as(i64, 3600), ukOffset(demo.start + 25 * 3600 - 1));
    try testing.expectEqual(@as(i64, 0), ukOffset(demo.start + 25 * 3600));
    try testing.expectEqual(@as(i64, 0), ukOffset(lastSunday(2025, 3) * 86400 + 3599));
    try testing.expectEqual(@as(i64, 3600), ukOffset(lastSunday(2025, 3) * 86400 + 3600));

    var x: X = undefined;
    x.init();
    defer x.arena.deinit();
    var t: Time = .{ .label = plain("M"), .start = demo.start, .series = &demo.series, .tip = 10 };
    try has(try x.html(&t), &.{"<b>25 Oct 11:00</b>"}, &.{});
    t.clock = .utc;
    try has(try x.html(&t), &.{"<b>25 Oct 10:00</b>"}, &.{});
    // 23:00 to 04:00 UTC over the switch: hourly ticks, UK midnight at 23:00 UTC, the hour
    // given back ticked twice (01:00 BST, then 01:00 GMT)
    t = .{ .label = plain("M"), .start = demo.start, .series = &demo.series, .zoom = .{ demo.start + 23 * 3600, demo.start + 28 * 3600 } };
    const s = try x.html(&t);
    try has(s, &.{ ">26 Oct<", ">01:00<", ">02:00<", ">03:00<" }, &.{">00:00<"});
    try testing.expectEqual(@as(usize, 2), std.mem.count(u8, s, ">01:00<"));
}

test "ticks: March's missing hour, October's twice at sub-hour steps" {
    var x: X = undefined;
    x.init();
    defer x.arena.deinit();
    const mar = lastSunday(2025, 3) * 86400;
    var t: Time = .{ .label = plain("M"), .start = mar, .series = &demo.series, .zoom = .{ mar, mar + 4 * 3600 } };
    var s = try x.html(&t);
    try has(s, &.{ ">30 Mar<", ">02:00<", ">03:00<" }, &.{ ">00:00<", ">01:00<" });
    // Narrow keeps the printed even hours: 02:00 BST is 01:00 UTC
    const p: chart.Plane = .{ .x = .{ .lo = -0.5, .hi = 3.5 }, .y = .{ .lo = 0, .hi = 1 } };
    for (t.ticks(&x.h, p, .{ 0, 4 })) |k| try testing.expectEqual(eql(k.label.s, "03:00"), k.minor);
    // 00:30 to 01:30 UTC on 26 Oct by minute: 01:30 to 01:50 BST, then 01:00 to 01:20 GMT
    const mins = try x.arena.allocator().alloc(?f32, 60);
    @memset(mins, 1);
    t = .{ .label = plain("R"), .start = lastSunday(2025, 10) * 86400 + 1800, .step = 60, .series = &.{.{ .name = plain("r"), .values = mins }} };
    s = try x.html(&t);
    try has(s, &.{ ">01:30<", ">01:40<", ">01:50<", ">01:00<", ">01:10<", ">01:20<" }, &.{});
}

test "tickStep: never finer than a bucket, 1 minute to 28 days, then a sixth in days" {
    var t: Time = .{ .label = plain("x"), .start = 0, .step = 60, .series = &.{} };
    const hr = 3600;
    const day = 86400;
    for ([_][2]i64{
        .{ 360, 60 },
        .{ 1800, 300 },
        .{ hr, 600 },
        .{ 5400, 900 },
        .{ 3 * hr, 1800 },
        .{ 6 * hr, hr },
        .{ 3 * day, 12 * hr },
        .{ 42 * day, 7 * day },
        .{ 84 * day, 14 * day },
        .{ 168 * day, 28 * day },
        .{ 365 * day, 61 * day },
    }) |c| try testing.expectEqual(c[1], t.tickStep(c[0]));
    t.step = 3600;
    try testing.expectEqual(@as(i64, hr), t.tickStep(1800));
}

test "ticks: per minute zoomed to 20 minutes, a year by day" {
    var x: X = undefined;
    x.init();
    defer x.arena.deinit();
    const a = x.arena.allocator();
    const mins = try a.alloc(?f32, 120);
    for (mins, 0..) |*v, i| v.* = @floatFromInt(i % 7);
    var t: Time = .{ .label = plain("R"), .clock = .utc, .start = demo.start, .step = 60, .series = &.{.{ .name = plain("r"), .values = mins }}, .zoom = .{ demo.start + 600, demo.start + 1800 } };
    var s = try x.html(&t);
    try has(s, &.{ ">00:10<", ">00:15<", ">00:20<", ">00:25<" }, &.{">00:30<"});
    const year = try a.alloc(?f32, 365);
    for (year, 0..) |*v, i| v.* = @floatFromInt(1000 + i);
    t = .{ .label = plain("D"), .clock = .utc, .start = demo.start, .step = 86400, .series = &.{.{ .name = plain("d"), .values = year }} };
    s = try x.html(&t);
    const n = std.mem.count(u8, s, "class=\"xt\"");
    try testing.expect(n >= 5 and n <= 7);
    // A step of 0 is a step of 1 s
    t.step = 0;
    _ = try x.html(&t);
}

test "scale: signed lines, odd figures and refs neither hang nor panic" {
    var t: Time = .{ .label = plain("x"), .start = 0, .series = &.{.{ .name = plain("d"), .values = &.{ -5, -2, 3 } }} };
    var s = t.scale(.{ 0, 3 });
    try testing.expect(s.y.lo <= -5 and s.y.hi >= 3);
    t.series = &.{.{ .name = plain("d"), .values = &.{ -5, -2 } }};
    s = t.scale(.{ 0, 2 });
    try testing.expect(s.y.lo <= -5 and s.y.hi == 0);
    t.series = &.{.{ .name = plain("z"), .values = &.{ 0, 0 } }};
    s = t.scale(.{ 0, 2 });
    try testing.expect(s.y.hi > s.y.lo and s.step >= 1);

    var x: X = undefined;
    x.init();
    defer x.arena.deinit();
    t = .{ .label = plain("x"), .start = demo.start, .series = &.{.{ .name = plain("d"), .values = &.{ -5, -2, 3 } }} };
    try testing.expectEqual(@as(usize, 1), std.mem.count(u8, try x.html(&t), "class=\"axis\""));
    t = .{
        .label = plain("x"),
        .start = demo.start,
        .series = &.{.{ .name = plain("big"), .values = &.{ 1e30, 2, null } }},
        .refs = &.{ .{ .v = std.math.inf(f32), .label = plain("inf") }, .{ .v = std.math.nan(f32), .label = plain("nan") }, .{ .v = 10, .label = plain("ten") } },
    };
    try testing.expect(t.scale(.{ 0, 3 }).y.hi <= 1e15);
    const h = try x.html(&t);
    try has(h, &.{">ten<"}, &.{ ">inf<", ">nan<" });
    t.kind = .bars;
    t.series = &.{ .{ .name = plain("a"), .values = &.{ 3e38, 1 } }, .{ .name = plain("b"), .values = &.{ 3e38, 1 } } };
    _ = try x.html(&t);
}

test "view: a mark on its bucket's tick, marks outside left out, areas, one bucket" {
    var x: X = undefined;
    x.init();
    defer x.arena.deinit();
    var t: Time = .{ .label = plain("M"), .clock = .utc, .start = demo.start, .series = &demo.series, .marks = &.{ demo.start - 3600, demo.start + 36 * 3600, demo.start + 72 * 3600 } };
    try testing.expectEqual(@as(usize, 1), std.mem.count(u8, try x.html(&t), "class=\"mark\""));
    const p: chart.Plane = .{ .x = .{ .lo = -0.5, .hi = 71.5 }, .y = .{ .lo = 0, .hi = 1 } };
    const m = p.x.at(t.domain(demo.start + 36 * 3600));
    try testing.expectEqual(p.px(36), m);
    var on = false;
    for (t.ticks(&x.h, p, .{ 0, 72 })) |k| {
        on = on or k.at == m;
        // Narrow, the midnights stay and the noons go
        try testing.expectEqual(std.mem.findScalar(u8, k.label.s, ' ') == null, k.minor);
    }
    try testing.expect(on);
    t = .{ .label = plain("A"), .kind = .area, .start = demo.start, .series = &demo.series, .tip = 3 };
    try testing.expectEqual(@as(usize, 3), std.mem.count(u8, try x.html(&t), "class=\"band\""));
    t.series = &.{ .{ .name = plain("a"), .values = &.{4} }, .{ .name = plain("b"), .values = &.{2} } };
    try testing.expectEqual(@as(usize, 2), std.mem.count(u8, try x.html(&t), "class=\"bk\""));
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
    // Twelve at one height: a smaller gap, all on the plot
    var many: [12]End = undefined;
    for (&many, 0..) |*e, i| e.* = .{ .k = i, .y = 50, .v = 0 };
    spread(&many);
    for (many, 0..) |e, i| {
        try testing.expect(e.y >= 0 and e.y <= 100);
        if (i > 0) try testing.expect(e.y - many[i - 1].y >= 100.0 / 11.0 - 1e-3);
    }
}
