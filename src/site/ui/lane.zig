//! LaneChart: you minus your lane opponent by minute (gold, XP or CS), against the
//! typical middle half as a band and its median dashed; a previous patch's median fainter.
//! Each side gets its own top, so a one-sided lane uses the room. A Gold | XP | CS switch
//! for the chart head, a tap shows the minute's figures (ChartTip), a drag selects
//! minutes (the matchup page's Versus reads `range`). lanechart.zig's successor: the
//! matchup pages and Your games move here when they are rebuilt
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const chart = @import("chart.zig");
const segmented = @import("segmented.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "LaneChart";
pub const scope = .{".c-lane"};

/// Index i is minute i
pub const Series = struct {
    you: []const f32 = &.{},
    /// The typical middle half [low, high]
    band: []const [2]f32 = &.{},
    /// The typical median
    line: []const f32 = &.{},
    prev: []const f32 = &.{},
};

pub const Metric = struct {
    label: tree.Text,
    s: Series,
    /// Set: only the band's first `fit` minutes set the scale and the rest clips. The band
    /// widens far past the lane (±3,000 gold at 30 min) while the line stays near 0
    fit: usize = 0,
};

const W = struct {
    pub const label = phrase.Phrase("{a:text} minus {b:text} by minute");
    pub const ahead = phrase.Phrase("{n:text} ahead");
    pub const metric = plain("Measure");
    pub const you = phrase.Phrase(" · {n:text} {v:signed}");
    pub const typ = phrase.Phrase(" · typical {v:signed}");
    pub const games = phrase.Phrase(" · {n:count} games");
};

pub const Lane = struct {
    /// Your champion's name (or "You") and the opponent's
    a: []const u8,
    b: []const u8,
    metrics: []const Metric,
    /// Games still running at each minute, for the tip
    games: []const u32 = &.{},
    k: u8 = 0,
    /// ChartTip at this minute
    tip: ?u8 = null,
    /// Minutes a..b
    range: ?[2]u8 = null,
    press: chart.Press = .{},

    const L = @This();

    pub const Msg = union(enum) { plot, metric: u8 };

    fn cur(l: *const L) Series {
        return l.metrics[l.k].s;
    }

    fn minutes(l: *const L) usize {
        const s = l.cur();
        return @max(s.you.len, s.band.len, s.line.len);
    }

    pub fn update(l: *L, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .metric => |k| if (k < l.metrics.len) {
                l.k = k;
            },
            .plot => {
                const n = l.minutes();
                if (n < 2) return;
                const last: f32 = @floatFromInt(n - 1);
                const at = struct {
                    fn f(x: f32, top: f32) u8 {
                        return @intFromFloat(@round(x * top));
                    }
                }.f;
                switch (l.press.pointer(ev)) {
                    .none => {},
                    .hover, .tap => |f| l.tip = at(f, last),
                    .leave => l.tip = null,
                    .range => |r| {
                        const a = at(r[0], last);
                        const b = at(r[1], last);
                        l.range = if (b > a) .{ a, b } else null;
                    },
                }
            },
        }
    }

    pub fn clear(l: *L) void {
        l.range = null;
    }

    /// The Gold | XP | CS switch, for the page's chart head
    pub fn switcher(l: *L, h: *H) N {
        var items: std.ArrayList(segmented.Item) = .empty;
        for (l.metrics, 0..) |m, i| items.append(h.mem, .{
            .label = m.label,
            .selected = i == l.k,
            .on = h.on(l, .{ .metric = @as(u8, @intCast(i)) }),
        }) catch {
            h.oom = true;
        };
        return segmented.view(h, .{ .s = .s, .label = W.metric }, items.items);
    }

    fn plane(l: *const L) chart.Plane {
        const s = l.cur();
        const fit = l.metrics[l.k].fit;
        var up: f32 = 0;
        var down: f32 = 0;
        const fitted = if (fit > 0) s.band[0..@min(fit, s.band.len)] else s.band;
        for (fitted) |b| for (b) |v| {
            up = @max(up, v);
            down = @max(down, -v);
        };
        for ([_][]const f32{ s.you, s.line, s.prev }) |vs| for (vs) |v| {
            up = @max(up, v);
            down = @max(down, -v);
        };
        // The smaller side at least a third of the larger, so its tick clears 0's
        return .{
            .x = .{ .lo = 0, .hi = @floatFromInt(@max(1, l.minutes() - 1)) },
            .y = .{ .lo = -chart.niceCeil(@max(down, up / 3)), .hi = chart.niceCeil(@max(up, down / 3)) },
        };
    }

    pub fn view(l: *L, h: *H) N {
        const s = l.cur();
        const p = l.plane();
        const lo = h.mem.alloc(f32, s.band.len) catch {
            h.oom = true;
            return .none;
        };
        const hi = h.mem.alloc(f32, s.band.len) catch {
            h.oom = true;
            return .none;
        };
        for (s.band, lo, hi) |b, *x, *y| {
            x.* = b[0];
            y.* = b[1];
        }
        var ticks: std.ArrayList(chart.Tick) = .empty;
        for ([_]f32{ p.y.hi, p.y.hi / 2, 0, p.y.lo / 2, p.y.lo }) |v| ticks.append(h.mem, .{
            .at = p.py(v),
            .label = phrase.num(h, .signed, @as(i32, @intFromFloat(@round(v)))),
            .zero = v == 0,
        }) catch {
            h.oom = true;
        };
        var xs: std.ArrayList(chart.Tick) = .empty;
        var m: u32 = 5;
        while (m < l.minutes()) : (m += 5) xs.append(h.mem, .{ .at = p.px(m), .label = phrase.num(h, .time, m * 60), .minor = m % 10 != 0 }) catch {
            h.oom = true;
        };
        var over = h.list();
        over.add(h.span(.{ .class = "side" }, .{W.ahead.with(h, .{ .n = l.a })}));
        over.add(h.span(.{ .class = "side", .data_at = "bottom" }, .{W.ahead.with(h, .{ .n = l.b })}));
        if (l.range) |r| over.add(chart.range(h, p.px(r[0]), p.px(r[1])));
        if (s.you.len >= 2) over.add(h.el(.i, .{ .class = "dot", .data_k = "you", .style = h.vars(.{ .x = p.px(s.you.len - 1), .y = p.py(s.you[s.you.len - 1]) }) }, .{}));
        if (l.tip) |i| {
            var kids = h.list();
            kids.add(h.b(.{}, .{phrase.num(h, .time, @as(u32, i) * 60)}));
            if (i < s.you.len) kids.add(h.text(W.you.with(h, .{ .n = l.a, .v = round(s.you[i]) }).s));
            if (i < s.line.len) kids.add(h.text(W.typ.with(h, .{ .v = round(s.line[i]) }).s));
            if (i < l.games.len) kids.add(h.text(W.games.with(h, .{ .n = l.games[i] }).s));
            for (chart.tip(h, p.px(i), .{kids.done()})) |n| over.add(n);
        }
        return chart.frame(h, .{
            .label = W.label.with(h, .{ .a = l.a, .b = l.b }),
            .class = "c-chart c-lane",
            .height = 220,
            .y = ticks.items,
            .x = xs.items,
            .marks = &.{
                chart.band(h, p, lo, hi),
                chart.line(h, p, s.prev, .prev),
                chart.line(h, p, s.line, .typ),
                chart.line(h, p, s.you, .you),
            },
            .over = over.done(),
            .press = true,
            .on = .{
                .down = h.on(l, .plot),
                .move = h.on(l, .plot),
                .up = h.on(l, .plot),
                .leave = h.on(l, .plot),
                .cancel = h.on(l, .plot),
            },
        });
    }
};

fn round(v: f32) i32 {
    return @intFromFloat(@round(v));
}

pub const css =
    \\@layer components {
    \\  .c-lane .side { position: absolute; left: 6px; top: 4px; pointer-events: none; }
    \\  .c-lane .side[data-at="bottom"] { top: auto; bottom: 4px; }
    \\  .c-lane .dot[data-k="you"] { width: 7px; height: 7px; margin: -3.5px 0 0 -3.5px; background: var(--us); box-shadow: none; }
    \\}
    \\
;

/// LeBlanc against Yasuo, the typical band from 109 games (mocks/components.html)
const lane_gold = Series{
    .you = &.{ 0, -34, -102, 275, 179, 154, 151, 79, 211, -59, 112, 50, -196, -215, -212, -225, -137, -897, -1532, -1435, -1411, -1434, -1503, -1629, -1898 },
    .band = &.{ .{ 0, 0 }, .{ -62, 40 }, .{ -86, 274 }, .{ -180, 299 }, .{ -170, 350 }, .{ -223, 449 }, .{ -335, 460 }, .{ -428, 580 }, .{ -518, 653 }, .{ -556, 699 }, .{ -560, 648 }, .{ -640, 801 }, .{ -716, 811 }, .{ -796, 1052 }, .{ -774, 1110 }, .{ -780, 954 }, .{ -1001, 1209 }, .{ -1076, 1422 }, .{ -1263, 1217 }, .{ -1345, 1249 }, .{ -1327, 1400 }, .{ -1169, 1566 }, .{ -1340, 1479 }, .{ -1431, 1422 }, .{ -1384, 1400 } },
    .line = &.{ 0, -12, 44, 93, 80, 181, 129, 55, 104, 48, 166, 60, 63, 222, 77, -26, 53, 99, 100, 171, 187, 275, 321, 451, 300 },
};
const lane_xp = Series{
    .you = &.{ 0, 62, -62, 335, 107, 74, -7, -69, 134, 144, 186, 341, -95, -183, -181, 108, 263, -853, -1353, -1054, -1054, -970, 86, -64, 33 },
    .band = &.{ .{ 0, 0 }, .{ -62, 62 }, .{ -60, 217 }, .{ -114, 244 }, .{ -145, 329 }, .{ -180, 428 }, .{ -223, 511 }, .{ -271, 558 }, .{ -337, 711 }, .{ -443, 649 }, .{ -518, 764 }, .{ -455, 777 }, .{ -620, 974 }, .{ -751, 1076 }, .{ -790, 1081 }, .{ -926, 1060 }, .{ -923, 1187 }, .{ -625, 1296 }, .{ -998, 1333 }, .{ -781, 1355 }, .{ -790, 1372 }, .{ -882, 1268 }, .{ -1172, 1486 }, .{ -1047, 1380 }, .{ -806, 1410 } },
    .line = &.{ 0, 0, 60, 85, 113, 195, 180, 144, 125, 202, 171, 190, 235, 188, 399, 239, 171, 244, 330, 309, 267, 338, 119, 304, 252 },
};
const lane_cs = Series{
    .you = &.{ 0, -2, -6, -4, -10, -11, -17, -14, -16, -13, -11, -8, -15, -16, -17, -19, -18, -29, -37, -29, -30, -31, -21, -26, -23 },
    .band = &.{ .{ 0, 0 }, .{ -3, 2 }, .{ -4, 4 }, .{ -7, 3 }, .{ -8, 4 }, .{ -9, 5 }, .{ -11, 5 }, .{ -13, 7 }, .{ -16, 7 }, .{ -16, 7 }, .{ -20, 6 }, .{ -22, 9 }, .{ -23, 10 }, .{ -23, 7 }, .{ -24, 8 }, .{ -30, 8 }, .{ -29, 5 }, .{ -32, 7 }, .{ -33, 7 }, .{ -34, 5 }, .{ -39, 6 }, .{ -39, 5 }, .{ -48, 4 }, .{ -47, 2 }, .{ -51, -1 } },
    .line = &.{ 0, -1, -1, -2, -2, -3, -3, -3, 0, -6, -6, -7, -8, -7, -8, -6, -6, -7, -13, -13, -14, -16, -18, -21, -21 },
};
const lane_games = [_]u32{ 109, 109, 109, 109, 109, 109, 109, 109, 109, 109, 109, 109, 109, 109, 109, 109, 109, 109, 108, 108, 105, 105, 103, 99, 93 };
/// Made up: a previous patch's median, for the dashed line
const lane_prev = [_]f32{ 0, -11, 25, 56, 44, 112, 72, 18, 49, 7, 86, 9, 8, 116, 12, -63, -11, 18, 16, 63, 71, 130, 159, 247, 138 };

pub const demo_metrics = [_]Metric{
    .{ .label = plain("Gold"), .s = lane_gold },
    .{ .label = plain("XP"), .s = lane_xp },
    .{ .label = plain("CS"), .s = lane_cs },
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const states = [_]struct { []const u8, Lane }{
        .{ "gold, a minute tapped", .{ .a = "LeBlanc", .b = "Yasuo", .metrics = &demo_metrics, .games = &lane_games, .tip = 14 } },
        .{ "CS, minutes dragged", .{ .a = "LeBlanc", .b = "Yasuo", .metrics = &demo_metrics, .k = 2, .range = .{ 10, 15 } } },
        .{ "typical only (the matchup page)", .{ .a = "LeBlanc", .b = "Yasuo", .metrics = &.{.{ .label = plain("Gold"), .s = .{ .band = lane_gold.band, .line = lane_gold.line, .prev = &lane_prev } }} } },
    };
    for (states) |s| {
        const l = h.mem.create(Lane) catch {
            h.oom = true;
            return;
        };
        l.* = s[1];
        g.addFill(s[0], h.div(.{}, .{ l.switcher(h), l.view(h) }));
    }
}

const testing = std.testing;

test "on the fake DOM: a tap shows the minute, a drag selects minutes, the switch changes measure" {
    const island = @import("island.zig");
    const Fake = @import("fakedom.zig").Fake;
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var fake: Fake = .{ .a = a, .width = 480 };
    var rt: island.Runtime(Fake) = .init(a, &fake);
    // A page's card: the switch in its head, the chart under it
    const Card = struct {
        l: Lane,
        pub const Msg = union(enum) { none };
        pub fn update(_: *@This(), _: Msg, _: *tree.Event) void {}
        pub fn view(c: *@This(), hh: *H) N {
            return hh.div(.{}, .{ c.l.switcher(hh), c.l.view(hh) });
        }
    };
    var server: Card = .{ .l = .{ .a = "LeBlanc", .b = "Yasuo", .metrics = &demo_metrics, .games = &lane_games } };
    var state = server;
    const t = try a.create(tree.Tree);
    t.* = .{};
    var h: H = .init(a, t);
    t.root = server.view(&h);
    fake.server = t;
    const i = try rt.add(Card, &state, &server, "#lane");
    const cur = i.current();
    const plot = cur.node(cur.find(cur.root, "class", "plot").?).dom;
    // 24 minutes over 480 px: minute 14 at 280 px
    _ = rt.event(0, .{ .kind = .pointerdown, .target = plot, .x = 280 });
    _ = rt.event(0, .{ .kind = .pointerup, .target = plot, .x = 280 });
    try testing.expectEqual(@as(?u8, 14), state.l.tip);
    _ = rt.event(0, .{ .kind = .pointerdown, .target = plot, .x = 200 });
    _ = rt.event(0, .{ .kind = .pointermove, .target = plot, .x = 300 });
    _ = rt.event(0, .{ .kind = .pointerup, .target = plot, .x = 300 });
    try testing.expectEqual(@as(?[2]u8, .{ 10, 15 }), state.l.range);
    _ = rt.event(0, .{ .kind = .pointerleave, .target = plot });
    try testing.expectEqual(@as(?u8, null), state.l.tip);
    try testing.expectEqual(@as(u8, 0), state.l.k);
    const now = i.current();
    const xp = now.node(now.find(now.root, "aria-pressed", "false").?).dom;
    _ = rt.event(0, .{ .kind = .click, .target = xp });
    try testing.expectEqual(@as(u8, 1), state.l.k);
    try testing.expectEqual(@as(u32, 0), fake.warnings);
}
