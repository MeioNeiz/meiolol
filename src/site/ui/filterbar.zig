//! FilterBar: the page's filters in one row, usually a Card's toolbar band. In a
//! container under 520 px one Filters button stands in for them, with the choices in
//! force beside it ("EUW · Plat+"); it opens them under it (island state: `open`). The
//! controls sit in one wrapper, so hiding them never sets display on a Select's popover.
//! Also the table's Find box (`find`), which sits in the page's head beside them
const tree = @import("tree.zig");
const segmented = @import("segmented.zig");
const select = @import("select.zig");
const Gallery = @import("gallery.zig").Gallery;
const phrase = @import("phrase.zig");
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "FilterBar";
pub const scope = .{ ".c-filters", ".c-find" };

pub const Opts = struct {
    /// The choices in force, on the narrow toggle
    summary: ?tree.Text = null,
    open: bool = false,
    on_toggle: ?tree.Handler = null,
};

const W = struct {
    pub const filters = plain("Filters");
    pub const clear = plain("Clear search");
};

pub fn view(h: *H, o: Opts, kids: []const N) N {
    return h.div(.{ .class = "c-filters", .data_open = o.open }, .{
        h.button(.{ .class = "c-btn toggle", .type = "button", .aria_expanded = o.open, .on_click = o.on_toggle }, .{W.filters}),
        if (o.summary) |s| h.span(.{ .class = "sum" }, .{s}) else null,
        h.div(.{ .class = "set" }, .{kids}),
    });
}

/// A control with a small label before it ("Min games"), kept together when the row wraps
pub fn group(h: *H, t: tree.Text, control: N) N {
    return h.span(.{ .class = "grp" }, .{ h.span(.{ .class = "lab", .aria_hidden = true }, .{t}), control });
}

/// A search box (DataTable.searchBox or the page's own) with a × while it has text, the
/// browser's own × hidden so it isn't drawn twice
pub fn find(h: *H, input: ?N, has_text: bool, on_clear: ?tree.Handler) N {
    return h.span(.{ .class = "c-find" }, .{
        input,
        if (has_text) h.button(.{ .type = "button", .class = "x", .aria_label = W.clear, .on_click = on_clear }, .{"×"}) else null,
    });
}

pub const css =
    \\@layer components {
    \\  .c-filters { display: flex; flex-wrap: wrap; align-items: center; gap: var(--sp-2); flex: 1; min-width: 0; }
    \\  .c-filters > :is(.toggle, .sum) { display: none; }
    \\  .c-filters > .set { display: contents; }
    \\  .c-filters .grp { display: inline-flex; align-items: center; gap: var(--sp-2); flex: none; }
    \\  .c-filters .lab { font-size: var(--fs-xs); font-weight: var(--w-b); color: var(--faint);
    \\    text-transform: uppercase; letter-spacing: 0.06em; margin-left: var(--sp-2); }
    \\  .c-filters > .sum { flex: 1; min-width: 0; color: var(--muted); font-size: var(--fs-s);
    \\    white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    \\  .c-find { position: relative; display: flex; flex: 0 1 260px; margin-left: auto; }
    \\  .c-find > input { flex: 1; min-width: 0; padding-right: 32px; }
    \\  .c-find > input::-webkit-search-cancel-button { display: none; }
    \\  .c-find > .x { all: unset; position: absolute; right: 4px; top: 50%; transform: translateY(-50%);
    \\    width: 26px; height: 26px; display: grid; place-items: center; border-radius: 50%; cursor: pointer;
    \\    color: var(--muted); font-size: var(--fs-l); line-height: 1; }
    \\  .c-find > .x:hover { color: var(--text); background: var(--ctl-bg-2); }
    \\  .c-find > .x:focus-visible { outline: 2px solid var(--focus); }
    \\  @container (max-width: 520px) {
    \\    .c-filters > .toggle { display: inline-flex; flex: none; gap: 10px; }
    \\    .c-filters > .toggle::after { content: ""; width: 6px; height: 6px; border-right: 1.5px solid var(--muted);
    \\      border-bottom: 1.5px solid var(--muted); transform: translateY(-2px) rotate(45deg); }
    \\    .c-filters[data-open] > .toggle::after { transform: translateY(2px) rotate(225deg); }
    \\    .c-filters > .sum { display: block; }
    \\    .c-filters > .set { display: none; }
    \\    .c-filters[data-open] > .set { display: flex; flex-wrap: wrap; align-items: center; gap: var(--sp-2); width: 100%; }
    \\    .c-filters[data-open] .lab { margin-left: 0; }
    \\  }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const sum = plain("EUW · 30 days · Plat+");
    const card = @import("card.zig");
    g.addFill("in a toolbar band; one button when narrow", card.toolbar(h, &.{view(h, .{ .summary = sum }, &demo(g, "fb-a"))}));
    g.addFill("narrow, opened", card.toolbar(h, &.{view(h, .{ .summary = sum, .open = true }, &demo(g, "fb-b"))}));
    const find_in = h.input(.{ .type = "search", .placeholder = plain("Find"), .aria_label = plain("Find"), .value = "Ahri" });
    g.add("Find, with text: its ×", find(h, find_in, true, null));
}

fn demo(g: *Gallery, comptime id: []const u8) [5]N {
    const h = g.h;
    const region = select.view(h, .{ .id = g.id(id), .cols = 4 }, plain("EUW"), &.{
        .{ .label = plain("EUW"), .selected = true },
        .{ .label = plain("NA") },
        .{ .label = plain("KR") },
    });
    return .{
        region[0],
        region[1],
        segmented.view(h, .{}, &.{ .{ .label = plain("30 days"), .selected = true }, .{ .label = plain("16.21") } }),
        segmented.view(h, .{ .label = plain("Rank") }, &.{
            .{ .label = plain("Plat+"), .selected = true },
            .{ .label = plain("Emerald+") },
            .{ .label = plain("Master+") },
        }),
        group(h, plain("Min games"), segmented.view(h, .{ .label = plain("Min games") }, &.{
            .{ .label = plain("Any"), .selected = true },
            .{ .label = plain("300") },
            .{ .label = plain("1k") },
        })),
    };
}
