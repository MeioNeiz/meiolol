//! Segmented: one control for views, sorts and filters. A well darker than the card
//! holding filled segments; the chosen one is a solid tinted fill. s fits a row or a
//! chart head, fill splits a phone pane's width. Buttons with aria-pressed in a group:
//! choosing one changes what shows here, it doesn't switch tab panels (Tabs does). With
//! `href` a segment is a link to another page (a view's), the chosen one aria-current
const tree = @import("tree.zig");
const Gallery = @import("gallery.zig").Gallery;
const phrase = @import("phrase.zig");
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "Segmented";
pub const scope = .{".c-seg"};

pub const Item = struct {
    label: tree.Text,
    on: ?tree.Handler = null,
    selected: bool = false,
    /// Shown but not choosable (no data for it)
    disabled: bool = false,
    /// A line on hover: why it is disabled, what it counts
    title: ?[]const u8 = null,
    /// A count after the label
    n: ?u32 = null,
    /// A link instead of a button: the page that shows it
    href: ?[]const u8 = null,
};

pub const Variant = enum { default, fill };
pub const Size = enum { m, s };

pub const Opts = struct {
    v: Variant = .default,
    s: Size = .m,
    /// What the group chooses ("Min games"), for screen readers
    label: ?tree.Text = null,
};

pub fn view(h: *H, o: Opts, items: []const Item) N {
    var l = h.list();
    for (items, 0..) |it, i| {
        const kids = .{ it.label, if (it.n) |n| h.span(.{ .class = "n" }, .{phrase.num(h, .count, n)}) else null };
        l.add(if (it.href) |href| h.a(.{
            .key = i,
            .href = if (it.disabled or it.selected) null else href,
            .aria_current = if (it.selected) "page" else null,
            .aria_disabled = if (it.disabled) true else null,
            .title = it.title,
        }, kids) else h.button(.{
            .key = i,
            .type = "button",
            .aria_pressed = it.selected,
            .aria_disabled = if (it.disabled) true else null,
            .title = it.title,
            .on_click = if (it.disabled) null else it.on,
        }, kids));
    }
    return h.div(.{
        .class = "c-seg",
        .role = "group",
        .aria_label = o.label,
        .data_v = if (o.v == .default) null else o.v,
        .data_s = if (o.s == .m) null else o.s,
    }, .{l.done()});
}

pub const css =
    \\@layer components {
    \\  .c-seg { display: inline-flex; gap: 2px; padding: 3px; height: var(--ctl); flex: none;
    \\    border-radius: calc(var(--r-ctl) + 3px); background: var(--bg);
    \\    box-shadow: inset 0 0 0 1px var(--ctl-line); max-width: 100%; overflow-x: auto; scrollbar-width: none; }
    \\  .c-seg > :is(button, a) { all: unset; position: relative; display: inline-flex; align-items: center;
    \\    justify-content: center; gap: 6px; height: 100%; padding: 0 12px; border-radius: var(--r-ctl);
    \\    color: var(--t2); font-size: var(--fs-m); font-weight: var(--w-m); white-space: nowrap;
    \\    cursor: pointer; box-sizing: border-box;
    \\    transition: background var(--dur) var(--ease), color var(--dur) var(--ease); }
    \\  .c-seg > :is(button, a[href]):hover { color: var(--text); background: var(--ctl-bg-2); }
    \\  .c-seg > :is([aria-pressed="true"], [aria-current="page"]) { background: var(--sel-bg); color: var(--sel-ink);
    \\    box-shadow: inset 0 0 0 1px var(--sel-line), var(--shadow-ctl); }
    \\  .c-seg > [aria-disabled="true"] { color: var(--faint); cursor: default; background: none; }
    \\  .c-seg > :is(button, a):focus-visible { outline: 2px solid var(--focus); outline-offset: -2px; }
    \\  .c-seg > :is(button, a)::after { content: ""; position: absolute; left: 0; right: 0; top: 50%;
    \\    height: max(100%, var(--hit)); transform: translateY(-50%); }
    \\  .c-seg .n { color: var(--muted); font-weight: var(--w-r); font-size: var(--fs-s); font-variant-numeric: tabular-nums; }
    \\  .c-seg > :is([aria-pressed="true"], [aria-current="page"]) .n { color: var(--accent); }
    \\  .c-seg[data-s="s"] { height: var(--ctl-s); padding: 2px; border-radius: calc(var(--r-ctl) + 2px); }
    \\  .c-seg[data-s="s"] > :is(button, a) { padding: 0 10px; font-size: var(--fs-s); border-radius: var(--r-s); }
    \\  .c-seg[data-v="fill"] { display: flex; }
    \\  .c-seg[data-v="fill"] > :is(button, a) { flex: 1; }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.add("view", view(h, .{}, &.{
        .{ .label = plain("Win chance"), .selected = true },
        .{ .label = plain("Gold") },
    }));
    g.add("sort, disabled", view(h, .{}, &.{
        .{ .label = plain("Hardest") },
        .{ .label = plain("Easiest"), .selected = true },
        .{ .label = plain("Most played") },
        .{ .label = plain("Gold at 14"), .disabled = true },
    }));
    g.add("small, in a chart head", view(h, .{ .s = .s }, &.{
        .{ .label = plain("Gold"), .selected = true },
        .{ .label = plain("XP") },
        .{ .label = plain("CS") },
    }));
    g.add("fill, phone panes", view(h, .{ .v = .fill }, &.{
        .{ .label = plain("Ally"), .selected = true },
        .{ .label = plain("Draft") },
        .{ .label = plain("Enemy") },
    }));
    g.add("links to views, one greyed", view(h, .{ .label = plain("Rank") }, &.{
        .{ .label = plain("Plat+"), .selected = true, .href = "#" },
        .{ .label = plain("Emerald+"), .disabled = true, .href = "#" },
        .{ .label = plain("All regions"), .href = "#" },
    }));
    g.add("counts", view(h, .{ .label = plain("Min games") }, &.{
        .{ .label = plain("Any"), .n = 862 },
        .{ .label = plain("300"), .n = 214, .selected = true },
        .{ .label = plain("1k"), .n = 97 },
    }));
}
