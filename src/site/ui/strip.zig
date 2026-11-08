//! StatStrip: a page's headline figures in one row, plain (no box per figure): a small
//! label over each value, the answer larger, a value on the scale's colour where it has
//! one, context after it small ("4th of 53"). A rate is a Rate: its count, range on hover
//! and fade are the rate view's. Three to a row in a
//! narrow container. A label can open a Toggletip; a figure can link to where it comes from, or be pressed
//! (the game page's cells select their span; the selected one shows pressed)
const tree = @import("tree.zig");
const fmt = @import("fmt.zig");
const rate = @import("rate.zig");
const toggletip = @import("toggletip.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = @import("phrase.zig").plain;
const bar = @import("bar.zig");
const card = @import("card.zig");
const H = tree.H;
const N = tree.N;

pub const name = "StatStrip";
pub const scope = .{".c-strip"};

pub const Item = struct {
    label: tree.Text,
    /// Formatted by its kind (stat.figure, phrase.num); a pressable cell's spoken figure,
    /// so a pressable cell takes value, not rate
    value: tree.Text = .{ .s = "" },
    /// A rate or a difference of rates in place of value (rate.view with `.said = ""`, the
    /// label says it; rate.delta): its colour, count, hover and fade are the rate's. Made
    /// by the caller, so families without rates (ui-games) don't carry the rate scale
    rate: N = .none,
    /// After the value, small
    ctx: ?tree.Text = null,
    /// The value's colour; null is plain ink
    step: ?fmt.Step = null,
    /// The figure the page answers with (one per strip)
    answer: bool = false,
    href: ?[]const u8 = null,
    /// The cell as a button (its figure, the whole cell pressable)
    on: ?tree.Handler = null,
    pressed: bool = false,
    /// The label opens this note: its Toggletip id, unique on the page
    tip: ?struct { id: []const u8, note: tree.Text } = null,
};

const W = struct {
    pub const cell = @import("phrase.zig").Phrase("{l:text} {v:text}");
};

pub fn view(h: *H, items: []const Item) N {
    var l = h.list();
    for (items, 0..) |it, i| {
        const kids = .{ lab(h, it), val(h, it, true) };
        const cls = if (it.answer) "answer" else null;
        l.add(if (it.href) |href|
            h.a(.{ .key = i, .class = cls, .href = href }, kids)
        else
            h.div(.{ .key = i, .class = cls, .data_press = it.on != null }, kids));
    }
    return h.div(.{ .class = "c-strip" }, .{l.done()});
}

/// A row of `rows`: plain label and value, no tip, link or press (Item's paths cost
/// bytes in every island that draws rows)
pub const Row = struct {
    label: tree.Text,
    value: tree.Text,
    /// What shows its place, the third column (bar.track)
    bar: N = .none,
    /// After the bar, small
    ctx: ?tree.Text = null,
};

/// One row per item, every row the same columns: label, value, bar, context. In a
/// taller card the rows grow. `foot`: under the last row's bar (bar.scale)
pub fn rows(h: *H, rs: []const Row, foot: N) N {
    var l = h.list();
    for (rs, 0..) |r, i| l.add(h.div(.{ .key = i }, .{
        h.span(.{ .class = "lab" }, .{r.label}),
        h.span(.{ .class = "val" }, .{r.value}),
        h.span(.{ .class = "bar" }, .{r.bar}),
        if (r.ctx) |c| h.small(.{ .class = "c" }, .{c}) else null,
    }));
    const f = if (foot == .none) null else h.span(.{ .class = "foot" }, .{foot});
    return h.div(.{ .class = "c-strip", .data_rows = true, .data_grow = {} }, .{ l.done(), f });
}

fn lab(h: *H, it: Item) N {
    const tip: ?[2]N = if (it.tip) |t| toggletip.view(h, t.id, .{it.label}, it.label, t.note) else null;
    return h.span(.{ .class = "lab" }, .{ if (tip) |*t| t else null, if (tip == null) it.label else null });
}

/// The value; `with_ctx`: the context inside it too (view's), else the caller places it
fn val(h: *H, it: Item, with_ctx: bool) N {
    const style = if (it.step) |s| h.vars(.{ .c = s }) else null;
    const ctx = if (with_ctx) if (it.ctx) |c| h.small(.{ .class = "c" }, .{c}) else null else null;
    const kids = .{ if (it.rate == .none) it.value else null, if (it.rate == .none) null else it.rate, ctx };
    return if (it.on) |on| h.button(.{
        .class = "val",
        .type = "button",
        .style = style,
        .aria_pressed = it.pressed,
        .aria_label = W.cell.with(h, .{ .l = it.label.s, .v = it.value.s }),
        .on_click = on,
    }, kids) else h.span(.{ .class = "val", .style = style }, kids);
}

pub const css =
    \\@layer components {
    \\  .c-strip { display: flex; flex-wrap: wrap; gap: var(--sp-2) var(--sp-5); }
    \\  .c-strip > * { display: flex; flex-direction: column; min-width: 0; color: inherit; }
    \\  .c-strip .lab { font-size: var(--fs-xs); color: var(--muted); white-space: nowrap; }
    \\  .c-strip .val { font-size: var(--fs-l); font-weight: var(--w-b); line-height: 1.25;
    \\    font-variant-numeric: tabular-nums; color: var(--c, var(--text)); white-space: nowrap; }
    \\  .c-strip .val > small { font-size: var(--fs-s); font-weight: var(--w-r); color: var(--faint); }
    \\  .c-strip .val > .c::before { content: " "; }
    \\  .c-strip .val > .c-rate > .v { font-weight: inherit; }
    \\  .c-strip .val > .c-rate > .g { margin-left: 6px; font-size: var(--fs-s); }
    \\  .c-strip .val > .c-rate + .c { display: block; line-height: 1.2; }
    \\  .c-strip > .answer .val { font-size: var(--fs-xl); }
    \\  .c-strip .val .us { color: var(--us-hot); }
    \\  .c-strip .val .them { color: var(--them-hot); }
    \\  .c-strip > a:hover { text-decoration: none; }
    \\  .c-strip > a:hover .lab { color: var(--text); }
    \\  .c-strip > [data-press] { position: relative; padding: 4px var(--sp-2); margin: -4px calc(-1 * var(--sp-2));
    \\    border-radius: var(--r-s); }
    \\  .c-strip > [data-press]:hover { background: var(--panel-2); }
    \\  .c-strip button.val { all: unset; cursor: pointer; font-size: var(--fs-l); font-weight: var(--w-b); line-height: 1.25;
    \\    font-variant-numeric: tabular-nums; color: var(--c, var(--text)); white-space: nowrap; }
    \\  .c-strip button.val::after { content: ""; position: absolute; inset: 0; border-radius: inherit; }
    \\  .c-strip button.val:focus-visible::after { outline: 2px solid var(--focus); outline-offset: -2px; }
    \\  .c-strip > [data-press]:has(> [aria-pressed="true"]) { background: var(--sel-bg); box-shadow: inset 0 0 0 1px var(--sel-line); }
    \\  .c-strip[data-rows] { display: grid; grid-template-columns: auto auto minmax(0, 1fr) auto;
    \\    gap: var(--sp-1) var(--sp-3); }
    \\  .c-strip[data-rows] > div { display: grid; grid-column: 1 / -1; grid-template-columns: subgrid; align-items: center; }
    \\  .c-strip[data-rows] .lab { font-size: var(--fs-s); }
    \\  .c-strip[data-rows] .val { font-size: var(--fs-m); font-weight: var(--w-m); text-align: right; }
    \\  .c-strip[data-rows] > div > .c { font-size: var(--fs-s); color: var(--muted); font-variant-numeric: tabular-nums;
    \\    min-width: 3.5em; }
    \\  .c-strip[data-rows] > .foot { grid-column: 3; }
    \\  @container (max-width: 440px) {
    \\    .c-strip { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: var(--sp-2); }
    \\    .c-strip .val > .c { display: block; line-height: 1.2; }
    \\    .c-strip .val > .c-rate { grid-template-columns: auto; justify-items: start; }
    \\    .c-strip .val > .c-rate > .g { margin-left: 0; line-height: 1.2; }
    \\    .c-strip > [data-press] { margin: 0; }
    \\    .c-strip:has(> [data-press]) > :not([data-press]) { padding: 4px var(--sp-2); }
    \\  }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.add("with an answer", view(h, &.{
        .{
            .label = plain("Win rate"),
            .rate = rate.view(h, .counted(44935, 23007), .{ .said = "" }),
            .ctx = plain("4th of 53"),
            .answer = true,
            .tip = .{ .id = g.id("strip-wr"), .note = plain("Ahri's games won in mid: EUW, last 30 days, Platinum and up.") },
        },
        .{ .label = plain("Pick"), .value = plain("11.1%") },
        .{ .label = plain("Ban"), .value = plain("4.1%") },
        .{ .label = plain("Games"), .value = plain("44,935") },
    }));
    g.add("six, one links", view(h, &.{
        .{ .label = plain("Won"), .rate = rate.view(h, .counted(64, 32), .{ .said = "" }), .ctx = plain("44th of 59"), .answer = true },
        .{ .label = plain("Vs usual"), .rate = rate.delta(h, 1.2, null) },
        .{ .label = plain("Pick"), .value = plain("7.7%") },
        .{ .label = plain("Ban"), .value = plain("16.5%") },
        .{ .label = plain("Games"), .value = plain("31,257") },
        .{ .label = plain("Last patch"), .value = plain("50.1%"), .href = "#" },
        .{ .label = plain("Length"), .value = plain("29:14") },
    }));
    // Pressing does nothing here: the page binds each cell to its span
    const Inert = struct {
        pub const Msg = u8;
        pub fn update(_: *@This(), _: u8, _: *tree.Event) void {}
        var it: @This() = .{};
    };
    const on = h.on(&Inert.it, 0);
    g.add("pressable, one pressed", view(h, &.{
        .{ .label = plain("Swing"), .value = plain("+38"), .ctx = plain("32–33"), .step = .of(38, fmt.game_cuts), .on = on, .pressed = true },
        .{ .label = plain("Drop"), .value = plain("−19"), .ctx = plain("12–13"), .step = .of(-19, fmt.game_cuts), .on = on },
        .{ .label = plain("Longest lead"), .value = plain("9"), .ctx = plain("min, 4–13"), .on = on },
        // Each side's number in its team's colour
        .{ .label = plain("Fight"), .value = plain("5–2"), .rate = h.span(.{}, .{ h.span(.{ .class = "us" }, .{"5"}), "–", h.span(.{ .class = "them" }, .{"2"}) }), .ctx = plain("at 20:07"), .on = on },
    }));
    const eog = [_]struct { []const u8, []const u8, u8, []const u8 }{
        .{ "Kills", "3.1", 59, "59th" },
        .{ "Deaths", "5.0", 37, "37th" },
        .{ "Assists", "8.2", 6, "6th" },
        .{ "Level", "15.2", 41, "41st" },
        .{ "Gold / min", "388", 52, "52nd" },
        .{ "Damage / min", "655", 47, "47th" },
        .{ "Taken / min", "1,302", 1, "1st" },
        .{ "CS / min", "6.5", 31, "31st" },
        .{ "Vision / min", "0.9", 22, "22nd" },
    };
    var rs: [eog.len]Row = undefined;
    inline for (eog, 0..) |x, i| rs[i] = .{
        .label = plain(x[0]),
        .value = plain(x[1]),
        .bar = bar.track(h, .{ .at = @as(f64, @floatFromInt(60 - @as(u16, x[2]))) / 59, .label = plain(x[3] ++ " highest of 60") }),
    };
    const body = h.p(.{ .class = "muted" }, .{"Card body"});
    g.addFill("rows: places on tracks, the ends named once; grown by a taller card", card.row(h, &.{
        card.view(h, .{}, &.{ card.head(h, plain("Taller"), null, &.{}), body, body, body, body, body, body, body, body, body, body, body, body, body }),
        card.view(h, .{}, &.{ card.head(h, plain("End of game"), plain("of 60 champions"), &.{}), rows(h, &rs, bar.scale(h, plain("lowest"), plain("highest"))) }),
    }));
}
