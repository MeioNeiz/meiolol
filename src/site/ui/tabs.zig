//! Tabs: a card's or page's sections, on the panel's edge. Full-height items, the chosen
//! one carries an accent bar on the edge; inside a Card it runs edge to edge as a band.
//! Links (aria-current) when each tab is its own URL, else buttons with role tab.
//! Anything after the tabs (a Segmented, a count) sits at the band's end
const tree = @import("tree.zig");
const Gallery = @import("gallery.zig").Gallery;
const phrase = @import("phrase.zig");
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "Tabs";
pub const scope = .{".c-tabs"};

pub const Item = struct {
    label: tree.Text,
    selected: bool = false,
    on: ?tree.Handler = null,
    href: ?[]const u8 = null,
    n: ?u32 = null,
};

pub fn view(h: *H, label: ?tree.Text, items: []const Item, end: []const N) N {
    var l = h.list();
    for (items, 0..) |it, i| {
        const n: ?N = if (it.n) |c| h.span(.{ .class = "n" }, .{phrase.num(h, .count, c)}) else null;
        l.add(if (it.href) |href|
            h.a(.{ .key = i, .href = href, .aria_current = if (it.selected) "page" else null, .on_click = it.on }, .{ it.label, n })
        else
            h.button(.{ .key = i, .type = "button", .role = "tab", .aria_selected = it.selected, .on_click = it.on }, .{ it.label, n }));
    }
    const links = items.len > 0 and items[0].href != null;
    if (links) return h.el(.nav, .{ .class = "c-tabs", .aria_label = label }, .{ l.done(), end });
    return h.div(.{ .class = "c-tabs", .role = "tablist", .aria_label = label }, .{ l.done(), end });
}

pub const css =
    \\@layer components {
    \\  .c-tabs { display: flex; gap: var(--sp-1); height: var(--ctl-l); padding: 0; flex: none; max-width: 100%;
    \\    box-shadow: inset 0 -1px 0 var(--line); overflow-x: auto; scrollbar-width: none; }
    \\  .c-tabs > :is(button, a) { all: unset; position: relative; display: inline-flex; align-items: center;
    \\    gap: 6px; height: 100%; padding: 0 var(--sp-3); box-sizing: border-box; color: var(--muted);
    \\    font-size: var(--fs-m); font-weight: var(--w-b); white-space: nowrap; cursor: pointer;
    \\    transition: color var(--dur) var(--ease); }
    \\  .c-tabs > :is(button, a):hover { color: var(--text); background: none; text-decoration: none; }
    \\  .c-tabs > :is([aria-selected="true"], [aria-current="page"]) { color: var(--text);
    \\    box-shadow: inset 0 calc(-1 * var(--tab-bar)) 0 var(--accent); }
    \\  .c-tabs > :is(button, a):focus-visible { outline: 2px solid var(--focus); outline-offset: -4px; border-radius: var(--r-ctl); }
    \\  .c-tabs .n { padding: 1px 6px; border-radius: var(--r-pill); background: var(--ctl-bg-2); color: var(--t2);
    \\    font-size: var(--fs-xs); font-weight: var(--w-m); font-variant-numeric: tabular-nums; }
    \\  .c-tabs > [aria-selected="true"] .n, .c-tabs > [aria-current="page"] .n { background: var(--sel-bg); color: var(--sel-ink); }
    \\  .c-tabs > :not(button, a) { align-self: center; margin-left: auto; }
    \\  .c-tabs > :not(button, a) ~ :not(button, a) { margin-left: 0; }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.addFill("counts", view(h, null, &.{
        .{ .label = plain("Games"), .n = 23, .selected = true },
        .{ .label = plain("Champions"), .n = 6 },
        .{ .label = plain("Friends"), .n = 5 },
        .{ .label = plain("Over time") },
    }, &.{}));
    g.addFill("links, with a control at the end", view(h, plain("Ahri pages"), &.{
        .{ .label = plain("Overview"), .href = "#", .selected = true },
        .{ .label = plain("Builds"), .href = "#" },
        .{ .label = plain("Matchups"), .href = "#" },
    }, &.{
        @import("segmented.zig").view(h, .{ .s = .s }, &.{
            .{ .label = plain("30 days"), .selected = true },
            .{ .label = plain("16.21") },
        }),
    }));
}
