//! Bar: a magnitude without good or bad (pick, ban, games), a neutral ink bar beside its
//! figure. Bars in one column share a scale: `of` is the column's largest
const tree = @import("tree.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = @import("phrase.zig").plain;
const H = tree.H;
const N = tree.N;

pub const name = "Bar";
pub const scope = .{".c-bar"};

/// `x` of `of` as the bar's length, `text` the figure beside it
pub fn view(h: *H, x: f64, of: f64, text: tree.Text) N {
    const w = if (of > 0) @max(0, @min(100, 100 * x / of)) else 0;
    return h.span(.{ .class = "c-bar" }, .{
        h.span(.{ .aria_hidden = true }, .{h.el(.i, .{ .style = h.vars(.{ .w = w }) }, .{})}),
        text,
    });
}

pub const css =
    \\@layer components {
    \\  .c-bar { display: inline-flex; align-items: center; gap: 6px; font-variant-numeric: tabular-nums; }
    \\  .c-bar > span { position: relative; width: var(--bw, 48px); height: 4px; border-radius: 2px;
    \\    background: var(--bar-track); overflow: hidden; flex: none; }
    \\  .c-bar > span > i { position: absolute; inset: 0 auto 0 0; width: calc(var(--w) * 1%); border-radius: 2px;
    \\    background: linear-gradient(90deg, var(--bar-lo), var(--bar-hi)); }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.add("share", view(h, 56, 100, plain("56%")));
    g.add("games, the column's most", view(h, 44935, 44935, plain("44,935")));
    g.add("ban", view(h, 4.1, 100, plain("4.1%")));
}
