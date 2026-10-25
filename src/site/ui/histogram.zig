//! Histogram: how players' win rates on a champion spread (10+ games each), bars per bin
//! with the middle half shaded, a marker at 50% and, on Your games, one at your own rate.
//! The caption ("388 players, middle half 46-63%") is the card head's; the luck sentence
//! its Toggletip. Plain HTML bars placed by percent, nothing measured
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "Histogram";
pub const scope = .{".c-hist"};

pub const Histogram = struct {
    /// What it shows, for screen readers: the caption
    label: tree.Text,
    /// Players in each bin
    counts: []const u32,
    /// The first bin's left edge and each bin's width, in %
    lo: f32,
    step: f32,
    /// The middle half of players, %
    mid: [2]f32,
    /// The player's own rate
    you: ?f32 = null,
    height: u16 = 110,
};

pub fn view(h: *H, o: Histogram) N {
    const n: f32 = @floatFromInt(o.counts.len);
    const hi = o.lo + n * o.step;
    const at = struct {
        fn f(lo: f32, top: f32, v: f32) f32 {
            return std.math.clamp((v - lo) / (top - lo) * 100, 0, 100);
        }
    }.f;
    var max: u32 = 1;
    for (o.counts) |c| max = @max(max, c);
    var bars = h.list();
    for (o.counts, 0..) |c, i| {
        const centre = o.lo + (@as(f32, @floatFromInt(i)) + 0.5) * o.step;
        bars.add(h.el(.i, .{
            .key = i,
            .data_mid = centre >= o.mid[0] and centre <= o.mid[1],
            .style = h.vars(.{ .v = @as(f32, @floatFromInt(c)) / @as(f32, @floatFromInt(max)) * 100 }),
        }, .{}));
    }
    var xs = h.list();
    var t = @ceil(o.lo / 25) * 25;
    while (t <= hi) : (t += 25) xs.add(h.span(.{ .class = "xt", .style = h.vars(.{ .x = at(o.lo, hi, t) }) }, .{phrase.num(h, .pct, @as(i32, @intFromFloat(t)))}));
    return h.el(.figure, .{ .class = "c-hist", .role = "img", .aria_label = o.label, .style = h.vars(.{ .h = o.height }) }, .{
        h.div(.{ .class = "bars" }, .{
            bars.done(),
            h.el(.i, .{ .class = "even", .style = h.vars(.{ .x = at(o.lo, hi, 50) }) }, .{}),
            if (o.you) |v| h.el(.i, .{ .class = "you", .style = h.vars(.{ .x = at(o.lo, hi, v) }) }, .{}) else null,
        }),
        h.div(.{ .class = "xax" }, .{xs.done()}),
    });
}

pub const css =
    \\@layer components {
    \\  .c-hist { margin: 0; font-size: var(--fs-xs); color: var(--faint); font-variant-numeric: tabular-nums; }
    \\  .c-hist > .bars { position: relative; display: flex; align-items: flex-end; gap: 2px; height: calc(var(--h) * 1px);
    \\    border-bottom: 1px solid var(--axis); }
    \\  .c-hist .bars > i:not([class]) { flex: 1; min-width: 0; height: calc(var(--v) * 1%); min-height: 1px;
    \\    border-radius: 2px 2px 0 0; background: var(--bar-lo); }
    \\  .c-hist .bars > i[data-mid] { background: var(--bar-hi); }
    \\  .c-hist .even, .c-hist .you { position: absolute; top: -4px; bottom: -4px; left: calc(var(--x) * 1%); width: 1px;
    \\    background: var(--axis); }
    \\  .c-hist .you { width: 2px; margin-left: -1px; background: var(--accent); }
    \\  .c-hist > .xax { position: relative; height: 20px; }
    \\  .c-hist .xt { position: absolute; top: 5px; left: calc(var(--x) * 1%); transform: translateX(-50%); white-space: nowrap; }
    \\  .c-hist .xt:first-child { transform: none; }
    \\  .c-hist .xt:last-child { transform: translateX(-100%); }
    \\}
    \\
;

/// Darius players, 2.5-point bins from 25% (388 players, middle half 46-63%)
pub const demo_counts = [_]u32{ 1, 2, 4, 8, 14, 22, 30, 38, 46, 50, 48, 42, 32, 22, 14, 8, 4, 2, 1, 0 };

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const label = plain("388 players, middle half 46-63%");
    g.addFill("players on a champion, the middle half shaded", view(h, .{ .label = label, .counts = &demo_counts, .lo = 25, .step = 2.5, .mid = .{ 46, 63 } }));
    g.addFill("your rate marked, short", view(h, .{ .label = label, .counts = &demo_counts, .lo = 25, .step = 2.5, .mid = .{ 46, 63 }, .you = 58.2, .height = 72 }));
}

test "bins in the middle half are marked; ticks every 25%" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    const fig = view(&h, .{ .label = plain("x"), .counts = &demo_counts, .lo = 25, .step = 2.5, .mid = .{ 46, 63 } });
    var out: std.Io.Writer.Allocating = .init(arena.allocator());
    try @import("html.zig").write(&t, fig, &out.writer);
    const s = out.written();
    // Bins centred 46.25 to 61.25: 7 of them
    try std.testing.expectEqual(@as(usize, 7), std.mem.count(u8, s, "data-mid"));
    try std.testing.expectEqual(@as(usize, 3), std.mem.count(u8, s, "class=\"xt\""));
}
