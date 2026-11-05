//! Tip: a short line about what it wraps (a range's ends, a full count, a place's name),
//! shown at once on hover, on keyboard focus and on a tap, so phones see it too (a title
//! never shows there). The line is in the page, after the wrapped content: screen readers
//! read it inline, with no attr() or id. A note with a heading, or long enough to want
//! a tap to open, is a Toggletip. The native title and attr(data-tip) are uilint debt
//! that moves here
const tree = @import("tree.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = @import("phrase.zig").plain;
const H = tree.H;
const N = tree.N;

pub const name = "Tip";
pub const scope = .{ ".c-hint", ".c-hintb" };

pub const Opts = struct {
    /// Opens under its content: a chip at a card's top edge, which would clip it above
    below: bool = false,
    /// Aligned to its content's end: a right-hand column or seat
    end: bool = false,
    /// A tab stop of its own. Off for dense cells (a rate in every row): a tap or a
    /// click still opens it, Tab passes by
    stop: bool = true,
    /// Read by screen readers after the content. Off when the content already says it
    said: bool = true,
    /// Drawn open, for the gallery
    open: bool = false,
};

pub fn view(h: *H, text: tree.Text, kids: anytype, o: Opts) N {
    return h.span(.{
        .class = if (o.open) "c-hint open" else "c-hint",
        .tabindex = @as(i8, if (o.stop) 0 else -1),
        .data_at = if (o.below) "below" else null,
        .data_end = o.end,
    }, kids ++ .{h.span(.{ .class = "c-hintb", .aria_hidden = if (o.said) null else true }, .{text})});
}

// Closed, the line is visually hidden (clipped to 1px), not display: none, so screen
// readers still read it. Focus opens it for keyboards everywhere and for taps where
// nothing hovers; a mouse click that focuses it leaves it to hover
pub const css =
    \\@layer components {
    \\  .c-hint { position: relative; outline: none; }
    \\  .c-hint:focus-visible { outline: 2px solid var(--focus); outline-offset: 2px; border-radius: 2px; }
    \\  .c-hintb { position: absolute; left: 0; bottom: calc(100% + 4px); z-index: 3;
    \\    width: 1px; height: 1px; overflow: hidden; clip-path: inset(50%); white-space: nowrap;
    \\    max-width: min(260px, calc(100vw - 32px)); padding: 2px var(--sp-2); pointer-events: none;
    \\    border: 1px solid var(--line-2); border-radius: var(--r-m); background: var(--panel-3);
    \\    box-shadow: var(--shadow-pop); color: var(--text); font-size: var(--fs-s); font-weight: var(--w-r);
    \\    line-height: 1.4; text-align: left; text-transform: none; letter-spacing: 0; }
    \\  .c-hint:is(.open, :focus-visible) > .c-hintb { width: max-content; height: auto; overflow: visible;
    \\    clip-path: none; white-space: normal; }
    \\  @media (hover: hover) {
    \\    .c-hint:hover > .c-hintb { width: max-content; height: auto; overflow: visible; clip-path: none;
    \\      white-space: normal; }
    \\  }
    \\  @media (hover: none) {
    \\    .c-hint:focus > .c-hintb { width: max-content; height: auto; overflow: visible; clip-path: none;
    \\      white-space: normal; }
    \\  }
    \\  .c-hint[data-at="below"] > .c-hintb { bottom: auto; top: calc(100% + 4px); }
    \\  .c-hint[data-end] > .c-hintb { left: auto; right: 0; }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.add("closed: hover, focus or tap", h.span(.{}, .{ "Win rate ", view(h, plain("50.6-51.8%, 44,935 games"), .{"51.2%"}, .{}) }));
    g.add("open, above", room(h, .above, view(h, plain("50.6-51.8%, 44,935 games"), .{"51.2%"}, .{ .open = true })));
    g.add("open, end", room(h, .end, view(h, plain("Darius into Syndra: big effect"), .{"▲"}, .{ .end = true, .open = true })));
    g.add("open, below", room(h, .below, view(h, plain("Patch 25.21, from 4 Nov"), .{"25.21"}, .{ .below = true, .open = true })));
    g.add("open, wraps", room(h, .above, view(h, plain("Ended the game in 3rd place for damage dealt to champions, behind both carries and ahead of the support"), .{"3rd"}, .{ .open = true })));
}

/// Space on the side an open line opens to: it overlaps what is around it
fn room(h: *H, side: enum { above, below, end }, x: N) N {
    return h.div(.{ .class = "g-room", .data_at = if (side == .below) "below" else null, .data_end = side == .end }, .{x});
}
