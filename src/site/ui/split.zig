//! WinSplit: a game's win chance as one bar, blue's share from the left in blue and red's
//! the rest, the figures at the ends in their side's colour. The 95% range is a whisker
//! around the split; a second model's chance a tick. l is a page's answer (draft tester,
//! Daily's on paper): there the bar takes its own row in a narrow container
const tree = @import("tree.zig");
const Gallery = @import("gallery.zig").Gallery;
const phrase = @import("phrase.zig");
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "WinSplit";
pub const scope = .{".c-split"};

pub const Split = struct {
    /// Blue's chance in %
    p: f32,
    /// Blue's 95% range in %
    lo: ?f32 = null,
    hi: ?f32 = null,
    /// The range opens this Toggletip (its id)
    range_tip: ?[]const u8 = null,
    /// A second model's chance for blue: a tick, its name under the bar
    b: ?f32 = null,
    b_name: ?tree.Text = null,
    /// The side that won, once known
    won: ?enum { blue, red } = null,
    s: enum { m, l } = .m,
};

const W = struct {
    pub const blue = phrase.Phrase("Blue {p:rate}");
    pub const red = phrase.Phrase("{p:rate} Red");
    pub const range = phrase.Phrase("{lo:dec} to {hi:dec}");
    pub const second = phrase.Phrase("{name:text} {p:rate}");
    pub const won = plain(" ✓");
};

pub fn view(h: *H, x: Split) N {
    const range: ?tree.Text = if (x.lo != null and x.hi != null) W.range.with(h, .{ .lo = x.lo.?, .hi = x.hi.? }) else null;
    const range_n: ?N = if (range) |r| (if (x.range_tip) |id|
        h.button(.{ .class = "c-tt", .type = "button", .popovertarget = id }, .{r})
    else
        h.span(.{}, .{r})) else null;
    const second: ?N = if (x.b) |b| (if (x.b_name) |nm| h.span(.{ .class = "bt" }, .{W.second.with(h, .{ .name = nm.s, .p = b })}) else null) else null;
    return h.div(.{ .class = "c-split", .data_s = if (x.s == .m) null else x.s }, .{
        h.span(.{ .class = "us" }, .{ W.blue.with(h, .{ .p = x.p }), if (x.won == .blue) W.won else null }),
        h.div(.{ .class = "bar", .aria_hidden = true, .style = h.vars(.{ .p = x.p, .lo = x.lo orelse x.p, .hi = x.hi orelse x.p }) }, .{
            h.el(.i, .{}, .{}),
            if (range != null) h.el(.s, .{}, .{}) else null,
            if (x.b) |b| h.b(.{ .style = h.vars(.{ .x = b }) }, .{}) else null,
        }),
        h.span(.{ .class = "them" }, .{ W.red.with(h, .{ .p = 100 - x.p }), if (x.won == .red) W.won else null }),
        if (range_n != null or second != null) h.span(.{ .class = "ci" }, .{ range_n, second }) else null,
    });
}

pub const css =
    \\@layer components {
    \\  .c-split { display: grid; grid-template-columns: auto 1fr auto; gap: var(--sp-1) var(--sp-2); align-items: center;
    \\    font-variant-numeric: tabular-nums; font-weight: var(--w-b); width: 100%; }
    \\  .c-split > .bar { position: relative; height: 10px; border-radius: 5px; background: var(--them); }
    \\  .c-split > .bar > i { position: absolute; inset: 0 auto 0 0; width: calc(var(--p) * 1%);
    \\    border-radius: 5px 0 0 5px; background: var(--us); }
    \\  .c-split > .bar > s { position: absolute; top: -2px; bottom: -2px; left: calc(var(--lo) * 1%);
    \\    right: calc(100% - var(--hi) * 1%); border-left: 2px solid var(--text); border-right: 2px solid var(--text); opacity: 0.6; }
    \\  .c-split > .bar > b { position: absolute; top: -3px; bottom: -3px; left: calc(var(--x) * 1%); width: 2px;
    \\    margin-left: -1px; background: var(--text); opacity: 0.55; }
    \\  .c-split > .us { color: var(--us); white-space: nowrap; }
    \\  .c-split > .them { color: var(--them); white-space: nowrap; }
    \\  .c-split > .ci { grid-column: 1 / -1; display: flex; justify-content: center; gap: var(--sp-3);
    \\    font-size: var(--fs-xs); color: var(--muted); font-weight: var(--w-r); }
    \\  .c-split .bt { color: var(--t2); font-weight: var(--w-m); }
    \\  .c-split[data-s="l"] { font-size: var(--fs-xl); letter-spacing: -0.02em; gap: var(--sp-2) var(--sp-4); }
    \\  .c-split[data-s="l"] > .bar { height: 14px; border-radius: 7px; }
    \\  .c-split[data-s="l"] > .bar > i { border-radius: 7px 0 0 7px; }
    \\  .c-split[data-s="l"] > .ci { letter-spacing: 0; }
    \\  @container (max-width: 480px) {
    \\    .c-split[data-s="l"] { grid-template-columns: 1fr auto; gap: var(--sp-2); }
    \\    .c-split[data-s="l"] > .bar { grid-row: 2; grid-column: 1 / -1; }
    \\  }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.addFill("plain", view(h, .{ .p = 48.8 }));
    g.addFill("range, a second model's tick", view(h, .{ .p = 29.5, .lo = 28.8, .hi = 30.2, .b = 30.6, .b_name = plain("B") }));
    g.addFill("on paper, red won", view(h, .{ .p = 41.6, .lo = 30.5, .hi = 53.6, .won = .red }));
    g.addFill("the page's answer", view(h, .{ .p = 48.8, .lo = 46.1, .hi = 51.5, .s = .l }));
}
