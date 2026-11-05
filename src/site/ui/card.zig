//! Card, its bands and SectionHead. A card's head (title, count, its own controls), Tabs
//! and toolbar (the page's filters) run edge to edge as bands built into the card, not
//! floating above it. SectionHead titles a run of content outside a card
const tree = @import("tree.zig");
const Gallery = @import("gallery.zig").Gallery;
const phrase = @import("phrase.zig");
const plain = phrase.plain;
const segmented = @import("segmented.zig");
const tabs = @import("tabs.zig");
const chip = @import("chip.zig");
const trend = @import("trend.zig");
const H = tree.H;
const N = tree.N;

pub const name = "Card";
pub const scope = .{ ".c-card", ".c-head", ".c-toolbar", ".c-sechead", ".c-cards" };

pub const Opts = struct {
    /// No padding: a table or chart fills it to the edges
    flush: bool = false,
    label: ?tree.Text = null,
    /// A link's target (Tabs to the page's sections)
    id: ?[]const u8 = null,
    /// A section tab's target: focusable, so after the jump the next Tab starts in it
    target: bool = false,
};

pub fn view(h: *H, o: Opts, kids: []const N) N {
    return h.section(.{ .class = "c-card", .data_v = if (o.flush) "flush" else null, .aria_label = o.label, .id = o.id, .tabindex = if (o.target) @as(?i8, -1) else null }, .{kids});
}

/// The card's head band: its title, a count, then its own controls at the end
pub fn head(h: *H, title: tree.Text, count: ?tree.Text, controls: []const N) N {
    return h.div(.{ .class = "c-head" }, .{
        h.h2(.{}, .{title}),
        if (count) |c| h.span(.{ .class = "count" }, .{c}) else null,
        controls,
    });
}

/// Cards side by side, one height: the tallest's
pub fn row(h: *H, kids: []const N) N {
    return h.div(.{ .class = "c-cards" }, .{kids});
}

/// The filters band: groups of controls, `spacer()` pushes the rest to the end
pub fn toolbar(h: *H, kids: []const N) N {
    return h.div(.{ .class = "c-toolbar" }, .{kids});
}

pub fn spacer(h: *H) N {
    return h.span(.{ .class = "sp" }, .{});
}

/// Controls kept together when the band wraps
pub fn group(h: *H, kids: []const N) N {
    return h.span(.{ .class = "grp" }, .{kids});
}

/// An uppercase label before a group ("Min games")
pub fn label(h: *H, text: tree.Text) N {
    return h.span(.{ .class = "lab" }, .{text});
}

pub fn sechead(h: *H, title: tree.Text, count: ?tree.Text, controls: []const N) N {
    return h.div(.{ .class = "c-sechead" }, .{
        h.h2(.{}, .{title}),
        if (count) |c| h.span(.{ .class = "count" }, .{c}) else null,
        controls,
    });
}

pub const css =
    \\@layer components {
    \\  .c-card { background: var(--panel); border: 1px solid var(--line); border-radius: var(--r-m);
    \\    padding: var(--card-pad); min-width: 0; }
    \\  .c-card[data-v="flush"] { padding: 0; overflow: clip; display: flow-root; }
    \\  /* A row of cards stretches to its tallest: a chart's plot, or a body marked data-grow,
    \\     takes the spare height */
    \\  .c-card:has(> :is(.c-chart, [data-grow])) { display: flex; flex-direction: column; }
    \\  .c-card > :is(.c-chart, [data-grow]) { flex: 1 0 auto; }
    \\  .c-cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 280px), 1fr)); gap: var(--sp-4); }
    \\  .c-card > :is(.c-head, .c-tabs, .c-toolbar) { margin-inline: calc(-1 * var(--card-px)); padding-inline: var(--card-px); }
    \\  .c-card > :is(.c-head, .c-tabs, .c-toolbar):first-child { margin-top: calc(-1 * var(--card-py)); }
    \\  .c-card > :is(.c-head, .c-tabs, .c-toolbar) + :not(.c-tabs, .c-toolbar, .c-head) { margin-top: var(--card-py); }
    \\  .c-card > .c-toolbar:last-child { margin-bottom: calc(-1 * var(--card-py)); border-bottom: 0;
    \\    border-radius: 0 0 calc(var(--r-m) - 1px) calc(var(--r-m) - 1px); }
    \\  .c-card > .c-head:last-child { margin-bottom: calc(-1 * var(--card-py)); border-bottom: 0; }
    \\  .c-card[data-v="flush"] > :is(.c-head, .c-tabs, .c-toolbar) { margin: 0; }
    \\  .c-head { display: flex; align-items: center; gap: var(--sp-2) var(--sp-3); flex-wrap: wrap;
    \\    min-height: calc(var(--ctl) + 2 * var(--sp-2)); padding-block: var(--sp-2); border-bottom: 1px solid var(--line); }
    \\  .c-head h2 { font-size: var(--fs-l); margin-right: auto; }
    \\  .c-head h2:has(+ .count) { margin-right: 0; }
    \\  .c-head .count { color: var(--faint); font-size: var(--fs-s); font-variant-numeric: tabular-nums; margin-right: auto; }
    \\  .c-toolbar { display: flex; align-items: center; flex-wrap: wrap; gap: var(--sp-2);
    \\    padding-block: var(--sp-2); background: var(--panel-2); border-bottom: 1px solid var(--line); }
    \\  .c-toolbar > .sp { flex: 1; }
    \\  .c-toolbar > .grp { display: flex; gap: var(--sp-1); flex-wrap: wrap; }
    \\  .c-toolbar > .lab { font-size: var(--fs-xs); font-weight: var(--w-b); color: var(--faint);
    \\    text-transform: uppercase; letter-spacing: 0.06em; margin: 0 -2px 0 var(--sp-2); }
    \\  .c-sechead { display: flex; align-items: center; gap: var(--sp-2) var(--sp-3); flex-wrap: wrap;
    \\    margin-bottom: var(--sp-2); min-height: var(--ctl); }
    \\  .c-sechead h2 { margin-right: auto; }
    \\  .c-sechead h2:has(+ .count) { margin-right: 0; }
    \\  .c-sechead .count { color: var(--faint); font-size: var(--fs-s); font-variant-numeric: tabular-nums; margin-right: auto; }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const body = h.p(.{ .class = "muted" }, .{"Card body"});
    g.addFill("plain", view(h, .{}, &.{ head(h, plain("Lane opponents"), plain("48"), &.{}), body }));
    g.addFill("head with a control", view(h, .{}, &.{
        head(h, plain("Gold lead"), null, &.{segmented.view(h, .{ .s = .s }, &.{
            .{ .label = plain("Gold"), .selected = true },
            .{ .label = plain("XP") },
        })}),
        h.p(.{ .class = "muted" }, .{"Chart"}),
    }));
    const t = h.mem.create(trend.Trend) catch {
        h.oom = true;
        return;
    };
    t.* = .{ .label = plain("By patch"), .points = &trend.demo_patch };
    g.addFill("a row stretched taller: the chart grows into it", row(h, &.{
        view(h, .{}, &.{ head(h, plain("By patch"), null, &.{}), t.view(h) }),
        view(h, .{}, &.{ head(h, plain("End of game"), null, &.{}), body, body, body, body, body, body, body, body }),
    }));
    g.addFill("tabs and toolbar bands", view(h, .{}, &.{
        tabs.view(h, null, &.{
            .{ .label = plain("Games"), .n = 23, .selected = true },
            .{ .label = plain("Champions"), .n = 6 },
            .{ .label = plain("Friends"), .n = 5 },
        }, &.{}),
        toolbar(h, &.{
            segmented.view(h, .{ .s = .s }, &.{
                .{ .label = plain("All"), .selected = true },
                .{ .label = plain("Ranked") },
                .{ .label = plain("Normal") },
            }),
            spacer(h),
            label(h, plain("Result")),
            group(h, &.{ chip.view(h, .{ .pressed = true }, .{"Wins"}), chip.view(h, .{}, .{"Losses"}) }),
        }),
        h.p(.{ .class = "muted" }, .{"Card body"}),
    }));
    g.addFill("flush", view(h, .{ .flush = true }, &.{
        toolbar(h, &.{h.span(.{ .class = "muted" }, .{"A table fills it"})}),
    }));
    g.addFill("SectionHead", sechead(h, plain("Lane opponents"), plain("48"), &.{segmented.view(h, .{ .s = .s }, &.{
        .{ .label = plain("Hardest"), .selected = true },
        .{ .label = plain("Easiest") },
    })}));
}
