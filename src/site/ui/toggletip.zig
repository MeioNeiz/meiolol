//! Toggletip: a dotted term that opens a short note on tap (popovertarget: no script,
//! one open at a time, Escape and a tap outside close it). Sparingly: a term or an
//! uncertainty that needs a line, never words an unclear component couldn't carry.
//! Placed under its term by CSS anchor positioning where supported, else centred
const tree = @import("tree.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = @import("phrase.zig").plain;
const H = tree.H;
const N = tree.N;

pub const name = "Toggletip";
pub const scope = .{ ".c-tt", ".c-tip" };

/// The term and its note, side by side in the tree. `id` unique on the page
pub fn view(h: *H, id: []const u8, term: anytype, title: tree.Text, note: tree.Text) [2]N {
    return .{
        h.button(.{ .class = "c-tt", .type = "button", .popovertarget = id }, term),
        tip(h, id, title, note, false),
    };
}

/// `open`: drawn in place, for the gallery
pub fn tip(h: *H, id: []const u8, title: tree.Text, note: tree.Text, open: bool) N {
    return h.div(.{
        .class = if (open) "c-tip static" else "c-tip",
        .id = if (open) null else id,
        .popover = if (open) null else "",
    }, .{ h.b(.{}, .{title}), note });
}

pub const css =
    \\@layer components {
    \\  .c-tt { all: unset; cursor: help; text-decoration: underline dotted var(--faint);
    \\    text-underline-offset: 3px; text-decoration-thickness: 1px; }
    \\  .c-tt:focus-visible { outline: 2px solid var(--focus); border-radius: 2px; }
    \\  .c-tip { max-width: min(280px, calc(100vw - 32px)); padding: var(--sp-2) var(--sp-3);
    \\    border: 1px solid var(--line-2); border-radius: var(--r-l); background: var(--panel-3); color: var(--t2);
    \\    font-size: var(--fs-s); line-height: 1.4; box-shadow: var(--shadow-pop); text-transform: none;
    \\    letter-spacing: 0; font-weight: var(--w-r); white-space: normal; text-align: left; }
    \\  .c-tip b { color: var(--text); display: block; font-weight: var(--w-m); margin-bottom: 2px; }
    \\  .c-tip.static { display: block; box-shadow: none; }
    \\  @supports (position-area: bottom) {
    \\    .c-tip { inset: auto; margin: 4px 0 0; position-area: bottom span-right; position-try-fallbacks: flip-block, flip-inline; }
    \\  }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const ci = view(h, g.id("tt-ci"), .{"±0.7"}, plain("± is a 95% range"), plain("The true rate is inside it 19 times in 20."));
    g.add("closed: tap", h.span(.{}, .{ "51.4% ", &ci }));
    const usual = view(h, g.id("tt-usual"), .{"Vs usual"}, plain("Vs usual"), plain("Points above or below what each side usually wins, so a strong opponent isn't counted twice."));
    g.add("a column head's term", h.span(.{ .class = "muted" }, .{&usual}));
    g.add("open", tip(h, "", plain("± is a 95% range"), plain("The true rate is inside it 19 times in 20."), true));
}
