//! Select: a button showing its value and a chevron, Segmented's height, that opens a
//! popover menu of choices (popovertarget: opens and closes with no script). For more
//! choices than a Segmented holds (regions, patches). The island hides the menu after a
//! choice (ev.after .hide on the menu's ref)
const tree = @import("tree.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = @import("phrase.zig").plain;
const H = tree.H;
const N = tree.N;

pub const name = "Select";
pub const scope = .{ ".c-select", ".c-menu" };

pub const Item = struct {
    label: tree.Text,
    /// Drawn in place of the label (a ModelBadge with its facts line)
    node: ?N = null,
    selected: bool = false,
    on: ?tree.Handler = null,
    /// Takes a whole row of the menu ("All regions")
    wide: bool = false,
};

pub const Opts = struct {
    /// The menu's id, unique on the page; also its data-ref
    id: []const u8,
    /// A muted label before the value ("Rank")
    label: ?tree.Text = null,
    s: enum { m, s } = .m,
    /// Columns in the menu: 1 for a list, 4 for short names
    cols: u8 = 1,
};

/// The button and its menu, side by side in the tree
pub fn view(h: *H, o: Opts, value: tree.Text, items: []const Item) [2]N {
    return .{ button(h, o, value), menu(h, o, items, false) };
}

pub fn button(h: *H, o: Opts, value: tree.Text) N {
    return h.button(.{
        .class = "c-select",
        .type = "button",
        .popovertarget = o.id,
        .data_s = if (o.s == .m) null else o.s,
    }, .{ if (o.label) |l| h.span(.{ .class = "lab" }, .{l}) else null, value });
}

/// `open`: drawn in place, for the gallery
pub fn menu(h: *H, o: Opts, items: []const Item, open: bool) N {
    var l = h.list();
    for (items, 0..) |it, i| l.add(h.button(.{
        .key = i,
        .type = "button",
        .role = "option",
        .class = if (it.wide) "wide" else null,
        .aria_selected = it.selected,
        .on_click = it.on,
    }, .{ it.node, if (it.node == null) it.label else null }));
    return h.div(.{
        .class = if (open) "c-menu static" else "c-menu",
        .id = if (open) null else o.id,
        .data_ref = if (open) null else o.id,
        .popover = if (open) null else "",
        .role = "listbox",
        .data_cols = o.cols,
    }, .{l.done()});
}

pub const css =
    \\@layer components {
    \\  .c-select { display: inline-flex; align-items: center; gap: 8px; height: var(--ctl);
    \\    padding: 0 12px; font-size: var(--fs-m); font-weight: var(--w-m); flex: none; }
    \\  .c-select > .lab { color: var(--muted); font-weight: var(--w-r); font-size: var(--fs-s); }
    \\  .c-select::after { content: ""; width: 6px; height: 6px; margin-left: 2px; border-right: 1.5px solid var(--muted);
    \\    border-bottom: 1.5px solid var(--muted); transform: rotate(45deg) translate(-2px, -2px); }
    \\  .c-select[data-s="s"] { height: var(--ctl-s); min-height: 0; padding: 0 10px; font-size: var(--fs-s); }
    \\  .c-menu { padding: 4px; border: 1px solid var(--line-2); border-radius: var(--r-l);
    \\    background: var(--panel-2); color: var(--text); box-shadow: var(--shadow-pop); gap: 2px; }
    \\  .c-menu:popover-open { display: grid; }
    \\  .c-menu.static { display: inline-grid; margin: 0; box-shadow: none; }
    \\  .c-menu[data-cols="1"] { grid-template-columns: auto; }
    \\  .c-menu[data-cols="4"] { grid-template-columns: repeat(4, auto); }
    \\  .c-menu > button { all: unset; position: relative; padding: 0 12px; height: var(--ctl-s); display: flex;
    \\    align-items: center; border-radius: var(--r-ctl); font-size: var(--fs-m); color: var(--t2); cursor: pointer; }
    \\  .c-menu > button:hover { background: var(--ctl-bg-2); color: var(--text); }
    \\  .c-menu > button:focus-visible { outline: 2px solid var(--focus); outline-offset: -2px; }
    \\  .c-menu > [aria-selected="true"] { background: var(--sel-bg); color: var(--sel-ink); font-weight: var(--w-m); }
    \\  .c-menu > .wide { grid-column: 1 / -1; }
    \\  @supports (position-area: bottom) {
    \\    .c-menu { inset: auto; margin: 4px 0 0; position-area: bottom span-right; position-try-fallbacks: flip-block, flip-inline; }
    \\  }
    \\}
    \\
;

const regions = [_][]const u8{ "EUW", "NA", "KR", "BR", "EUNE", "LAN", "LAS", "JP", "TR", "RU", "ME", "OCE", "SG", "TW", "VN" };

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const patches: []const Item = &.{
        .{ .label = plain("30 days") },
        .{ .label = plain("Patch 16.21"), .selected = true },
        .{ .label = plain("Patch 16.20") },
        .{ .label = plain("Patch 16.19") },
    };
    var region_items: [regions.len + 1]Item = undefined;
    region_items[0] = .{ .label = plain("All regions"), .wide = true };
    for (regions, 1..) |r, i| region_items[i] = .{ .label = .{ .s = r }, .selected = i == 1 };
    const reg: Opts = .{ .id = g.id("sel-region"), .cols = 4 };
    const pat: Opts = .{ .id = g.id("sel-patch") };
    const a = view(h, reg, plain("EUW"), &region_items);
    const b = view(h, pat, plain("Patch 16.21"), patches);
    g.add("closed: tap to open", h.div(.{ .class = "g-row" }, .{ &a, &b }));
    g.add("with a label, small", button(h, .{ .id = g.id("sel-rank"), .label = plain("Rank"), .s = .s }, plain("Plat+")));
    g.add("open", menu(h, pat, patches, true));
    g.add("open, 4 columns", menu(h, reg, &region_items, true));
}
