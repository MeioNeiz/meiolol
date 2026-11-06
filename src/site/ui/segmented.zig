//! Segmented: one control for views, sorts and filters. A well darker than the card
//! holding filled segments; the chosen one is a solid tinted fill. s fits a row or a
//! chart head, fill splits a phone pane's width. Buttons with aria-pressed in a group:
//! choosing one changes what shows here, it doesn't switch tab panels (Tabs does). With
//! `href` a segment is a link to another page (a view's), the chosen one aria-current;
//! with `on` too, an island takes the link's click (the page without it still follows).
//! In the app, `shell` is the message bridge.js sends the shell on a click. `radios`:
//! for static HTML with no island to switch views (the app's champ select): radios whose
//! checked one the page's CSS reads (:has([value=..]:checked)). `withWhy`: a disabled
//! segment with `why` opens its title as a Toggletip on a tap, as a title never shows on
//! phones
const tree = @import("tree.zig");
const Gallery = @import("gallery.zig").Gallery;
const phrase = @import("phrase.zig");
const toggletip = @import("toggletip.zig");
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
    /// Disabled, under withWhy: a tap opens the title as a note, under this Toggletip id
    /// (unique on the page)
    why: ?[]const u8 = null,
    /// A count after the label
    n: ?u32 = null,
    /// A link instead of a button: the page that shows it
    href: ?[]const u8 = null,
    /// The app's message to its shell, as JSON (data-shell, src/shell/web/bridge.js)
    shell: ?[]const u8 = null,
    /// radios: the input's value
    value: []const u8 = "",
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
    return of(h, o, items, false);
}

/// `view` where a disabled segment's `why` opens on a tap: apart, so an island whose
/// segments have none doesn't carry the Toggletip
pub fn withWhy(h: *H, o: Opts, items: []const Item) N {
    return of(h, o, items, true);
}

fn of(h: *H, o: Opts, items: []const Item, comptime why: bool) N {
    var l = h.list();
    var tips = h.list();
    for (items, 0..) |it, i| {
        const kids = .{ it.label, if (it.n) |n| h.span(.{ .class = "n" }, .{phrase.num(h, .count, n)}) else null };
        if (why and it.disabled) if (it.why) |id| {
            l.add(h.button(.{ .key = i, .type = "button", .popovertarget = id, .aria_disabled = true }, kids));
            tips.add(toggletip.tip(h, id, it.label, .{ .s = it.title orelse "" }, false));
            continue;
        };
        l.add(if (it.href) |href| h.a(.{
            .key = i,
            .href = if (it.disabled or it.selected) null else href,
            .aria_current = if (it.selected) "page" else null,
            .aria_disabled = if (it.disabled) true else null,
            .title = it.title,
            .on_click = if (it.disabled or it.selected) null else it.on,
        }, kids) else h.button(.{
            .key = i,
            .type = "button",
            .aria_pressed = it.selected,
            .aria_disabled = if (it.disabled) true else null,
            .title = it.title,
            .on_click = if (it.disabled) null else it.on,
            .data_shell = if (it.disabled or it.selected) null else it.shell,
        }, kids));
    }
    return h.div(.{
        .class = "c-seg",
        .role = "group",
        .aria_label = o.label,
        .data_v = if (o.v == .default) null else o.v,
        .data_s = if (o.s == .m) null else o.s,
    }, .{ l.done(), if (why) tips.done() else N.none });
}

/// Radios named `group`, the selected one checked: the page's CSS shows what it chooses
pub fn radios(h: *H, group: []const u8, o: Opts, items: []const Item) N {
    var l = h.list();
    for (items, 0..) |it, i| l.add(h.el(.label, .{ .key = i, .title = it.title }, .{
        h.input(.{ .type = "radio", .name = group, .value = it.value, .checked = it.selected }),
        it.label,
        if (it.n) |n| h.span(.{ .class = "n" }, .{phrase.num(h, .count, n)}) else null,
    }));
    return h.div(.{
        .class = "c-seg",
        .role = "radiogroup",
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
    \\  .c-seg > :is(button, a, label) { all: unset; position: relative; display: inline-flex; align-items: center;
    \\    justify-content: center; gap: 6px; height: 100%; padding: 0 12px; border-radius: var(--r-ctl);
    \\    color: var(--t2); font-size: var(--fs-m); font-weight: var(--w-m); white-space: nowrap;
    \\    cursor: pointer; box-sizing: border-box;
    \\    transition: background var(--dur) var(--ease), color var(--dur) var(--ease); }
    \\  .c-seg > :is(button, a[href], label):hover { color: var(--text); background: var(--ctl-bg-2); }
    \\  .c-seg > :is([aria-pressed="true"], [aria-current="page"], :has(> :checked)) { background: var(--sel-bg); color: var(--sel-ink);
    \\    box-shadow: inset 0 0 0 1px var(--sel-line), var(--shadow-ctl); }
    \\  .c-seg > [aria-disabled="true"] { color: var(--faint); cursor: default; background: none; }
    \\  .c-seg > :is(button, a):focus-visible, .c-seg > :has(> :focus-visible) { outline: 2px solid var(--focus); outline-offset: -2px; }
    \\  .c-seg > label > input { position: absolute; opacity: 0; width: 0; height: 0; margin: 0; }
    \\  .c-seg > :is(button, a)::after { content: ""; position: absolute; left: 0; right: 0; top: 50%;
    \\    height: max(100%, var(--hit)); transform: translateY(-50%); }
    \\  .c-seg .n { color: var(--muted); font-weight: var(--w-r); font-size: var(--fs-s); font-variant-numeric: tabular-nums; }
    \\  .c-seg > :is([aria-pressed="true"], [aria-current="page"], :has(> :checked)) .n { color: var(--accent); }
    \\  .c-seg[data-s="s"] { height: var(--ctl-s); padding: 2px; border-radius: calc(var(--r-ctl) + 2px); }
    \\  .c-seg[data-s="s"] > :is(button, a, label) { padding: 0 10px; font-size: var(--fs-s); border-radius: var(--r-s); }
    \\  .c-seg[data-v="fill"] { display: flex; }
    \\  .c-seg[data-v="fill"] > :is(button, a, label) { flex: 1; }
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
    g.add("greyed with why: a tap opens it", withWhy(h, .{ .s = .s, .label = plain("Period") }, &.{
        .{ .label = plain("30 days"), .selected = true, .href = "#" },
        .{ .label = plain("16.22"), .href = "#" },
        .{ .label = plain("Meio"), .disabled = true, .href = "", .title = "Meio's estimates are on champion pages", .why = g.id("seg-why") },
    }));
    g.add("radios, static HTML", radios(h, "seg-demo", .{ .s = .s, .label = plain("View") }, &.{
        .{ .label = plain("Options"), .value = "options", .selected = true },
        .{ .label = plain("Lane"), .value = "lane" },
        .{ .label = plain("Comps"), .value = "comp" },
    }));
    g.add("counts", view(h, .{ .label = plain("Min games") }, &.{
        .{ .label = plain("Any"), .n = 862 },
        .{ .label = plain("300"), .n = 214, .selected = true },
        .{ .label = plain("1k"), .n = 97 },
    }));
}
