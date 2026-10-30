//! Delta: a signed change in points, on the scale's colour with its sign (or an arrow) as
//! the second cue; faint when its 95% range spans zero (it could be luck) or the caller
//! says it may be (`faint`). DeltaBar draws
//! it from a centre line with the range as a whisker; dot for a forest of them
const tree = @import("tree.zig");
const fmt = @import("fmt.zig");
const Gallery = @import("gallery.zig").Gallery;
const phrase = @import("phrase.zig");
const H = tree.H;
const N = tree.N;

pub const name = "Delta";
pub const scope = .{ ".c-delta", ".c-dbar" };

pub const Delta = struct {
    /// Points
    d: f32,
    /// 95% half-width
    ci: ?f32 = null,
    scale: fmt.Scale = .aggregate,
    /// ▲ or ▼ instead of the sign
    arrow: bool = false,
    /// Faint whatever its range: past 1.96 can still be luck, e.g. the most extreme of
    /// many tests
    faint: bool = false,
};

fn unclear(x: Delta) bool {
    if (x.faint) return true;
    const c = x.ci orelse return false;
    return @abs(x.d) < c;
}

pub fn view(h: *H, x: Delta) N {
    const step: fmt.Step = .of(x.d, x.scale.cuts());
    const text = if (x.arrow) phrase.num(h, .dec, x.d) else phrase.num(h, .points, x.d);
    return h.span(.{ .class = "c-delta", .data_state = if (unclear(x)) "unclear" else null, .style = h.vars(.{ .c = step }) }, .{
        if (x.arrow and x.d != 0) h.span(.{ .class = "ar", .aria_hidden = true }, .{if (x.d > 0) "▲" else "▼"}) else null,
        text,
    });
}

pub const Bar = struct {
    d: f32,
    ci: ?f32 = null,
    /// The points at either edge: every bar in a list shares it
    span: f32 = 8,
    scale: fmt.Scale = .aggregate,
    dot: bool = false,
};

/// Positions in % of the width, the centre line at 50
pub fn bar(h: *H, x: Bar) N {
    const step: fmt.Step = .of(x.d, x.scale.cuts());
    const at = struct {
        fn f(v: f32, span: f32) f32 {
            return @max(0, @min(100, 50 + 50 * v / span));
        }
    }.f;
    const lo = @min(at(x.d, x.span), 50);
    const hi = @max(at(x.d, x.span), 50);
    const mark = if (x.dot)
        h.el(.i, .{ .style = h.vars(.{ .l = at(x.d, x.span) }) }, .{})
    else
        h.el(.i, .{ .style = h.vars(.{ .l = lo, .w = hi - lo }) }, .{});
    const whisker: ?N = if (x.ci) |c| h.el(.s, .{ .style = h.vars(.{ .l = at(x.d - c, x.span), .w = at(x.d + c, x.span) - at(x.d - c, x.span) }) }, .{}) else null;
    return h.span(.{
        .class = "c-dbar",
        .data_v = if (x.dot) "dot" else null,
        .data_state = if (unclear(.{ .d = x.d, .ci = x.ci })) "unclear" else null,
        .style = h.vars(.{ .c = step }),
        .aria_hidden = true,
    }, .{ whisker, mark });
}

pub const css =
    \\@layer components {
    \\  .c-delta { color: var(--c, var(--s0)); font-variant-numeric: tabular-nums; white-space: nowrap;
    \\    font-size: var(--fs-s); font-weight: var(--w-m); }
    \\  .c-delta[data-state="unclear"] { opacity: 0.5; font-weight: var(--w-r); }
    \\  .c-delta .ar { font-size: var(--fs-xs); margin-right: 2px; position: relative; top: -1px; }
    \\  .c-dbar { position: relative; display: block; height: 14px; min-width: 80px; }
    \\  .c-dbar::before { content: ""; position: absolute; left: 50%; top: -2px; bottom: -2px; width: 1px; background: var(--axis); }
    \\  .c-dbar > i { position: absolute; top: 3px; height: 8px; left: calc(var(--l) * 1%); width: calc(var(--w) * 1%);
    \\    border-radius: 2px; background: var(--c); }
    \\  .c-dbar > s { position: absolute; top: 6px; height: 2px; left: calc(var(--l) * 1%); width: calc(var(--w) * 1%);
    \\    background: var(--c); opacity: 0.45; }
    \\  .c-dbar > s::before, .c-dbar > s::after { content: ""; position: absolute; top: -3px; width: 1px; height: 8px; background: inherit; }
    \\  .c-dbar > s::before { left: 0; }
    \\  .c-dbar > s::after { right: 0; }
    \\  .c-dbar[data-v="dot"] > i { width: 8px; height: 8px; border-radius: 50%; margin-left: -4px; }
    \\  .c-dbar[data-state="unclear"] > i { opacity: 0.5; }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.add("inline", view(h, .{ .d = 2.6 }));
    g.add("arrow", view(h, .{ .d = -4.4, .arrow = true }));
    g.add("spans 0", view(h, .{ .d = 0.2, .ci = 0.9 }));
    g.add("faint, may be luck", view(h, .{ .d = 12.4, .faint = true }));
    g.add("one game", view(h, .{ .d = -6.2, .scale = .game }));
    var bars = h.list();
    for ([_][2]f32{ .{ 2.6, 1.4 }, .{ 2.0, 1.2 }, .{ -4.4, 2.8 }, .{ -0.6, 1.5 } }) |p| bars.add(bar(h, .{ .d = p[0], .ci = p[1] }));
    g.addFill("bars, ±95%, one span", h.div(.{ .class = "g-col" }, .{bars.done()}));
    var dots = h.list();
    for ([_][2]f32{ .{ -3.1, 1.6 }, .{ -2.5, 1.2 }, .{ 1.1, 0.8 } }) |p| dots.add(bar(h, .{ .d = p[0], .ci = p[1], .dot = true }));
    g.addFill("dots, a forest", h.div(.{ .class = "g-col" }, .{dots.done()}));
}
