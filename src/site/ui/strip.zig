//! StatStrip: a page's headline figures in one row, plain (no box per figure): a small
//! label over each value, the answer larger, a value on the scale's colour where it has
//! one, context after it small ("4th of 53"). Three to a row in a narrow container. A
//! label can open a Toggletip; a figure can link to where it comes from, or be pressed
//! (the game page's cells select their span; the selected one shows pressed)
const tree = @import("tree.zig");
const fmt = @import("fmt.zig");
const toggletip = @import("toggletip.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = @import("phrase.zig").plain;
const H = tree.H;
const N = tree.N;

pub const name = "StatStrip";
pub const scope = .{".c-strip"};

pub const Item = struct {
    label: tree.Text,
    /// Formatted by its kind (stat.figure, phrase.num)
    value: tree.Text,
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
        const tip: ?[2]N = if (it.tip) |t| toggletip.view(h, t.id, .{it.label}, it.label, t.note) else null;
        const lab = h.span(.{ .class = "lab" }, .{ if (tip) |*t| t else null, if (tip == null) it.label else null });
        const style = if (it.step) |s| h.vars(.{ .c = s }) else null;
        const val = if (it.on) |on| h.button(.{
            .class = "val",
            .type = "button",
            .style = style,
            .aria_pressed = it.pressed,
            .aria_label = W.cell.with(h, .{ .l = it.label.s, .v = it.value.s }),
            .on_click = on,
        }, .{
            it.value,
            if (it.ctx) |c| h.small(.{}, .{c}) else null,
        }) else h.span(.{ .class = "val", .style = style }, .{
            it.value,
            if (it.ctx) |c| h.small(.{}, .{c}) else null,
        });
        const cls = if (it.answer) "answer" else null;
        l.add(if (it.href) |href|
            h.a(.{ .key = i, .class = cls, .href = href }, .{ lab, val })
        else
            h.div(.{ .key = i, .class = cls, .data_press = it.on != null }, .{ lab, val }));
    }
    return h.div(.{ .class = "c-strip" }, .{l.done()});
}

pub const css =
    \\@layer components {
    \\  .c-strip { display: flex; flex-wrap: wrap; gap: var(--sp-2) var(--sp-5); }
    \\  .c-strip > * { display: flex; flex-direction: column; min-width: 0; color: inherit; }
    \\  .c-strip .lab { font-size: var(--fs-xs); color: var(--muted); white-space: nowrap; }
    \\  .c-strip .val { font-size: var(--fs-l); font-weight: var(--w-b); line-height: 1.25;
    \\    font-variant-numeric: tabular-nums; color: var(--c, var(--text)); white-space: nowrap; }
    \\  .c-strip .val > small { font-size: var(--fs-s); font-weight: var(--w-r); color: var(--faint); margin-left: 4px; }
    \\  .c-strip > .answer .val { font-size: var(--fs-xl); }
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
    \\  @container (max-width: 440px) {
    \\    .c-strip { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: var(--sp-2); }
    \\    .c-strip .val > small { display: block; margin-left: 0; line-height: 1.2; }
    \\    .c-strip > [data-press] { margin: 0; }
    \\    .c-strip:has(> [data-press]) > :not([data-press]) { padding: 4px var(--sp-2); }
    \\  }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const agg = fmt.win_cuts;
    g.add("with an answer", view(h, &.{
        .{
            .label = plain("Win rate"),
            .value = plain("51.2%"),
            .ctx = plain("4th of 53"),
            .step = .of(1.2, agg),
            .answer = true,
            .tip = .{ .id = g.id("strip-wr"), .note = plain("Ahri's games won in mid: EUW, last 30 days, Platinum and up.") },
        },
        .{ .label = plain("Pick"), .value = plain("11.1%") },
        .{ .label = plain("Ban"), .value = plain("4.1%") },
        .{ .label = plain("Games"), .value = plain("44,935") },
    }));
    g.add("six, one links", view(h, &.{
        .{ .label = plain("Won"), .value = plain("49.3%"), .ctx = plain("44th of 59"), .step = .of(-0.7, agg), .answer = true },
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
        .{ .label = plain("Turn"), .value = plain("+38"), .ctx = plain("32–33"), .step = .of(38, fmt.game_cuts), .on = on, .pressed = true },
        .{ .label = plain("Biggest drop"), .value = plain("−19"), .ctx = plain("12–13"), .step = .of(-19, fmt.game_cuts), .on = on },
        .{ .label = plain("Ahead"), .value = plain("13"), .ctx = plain("of 33 min") },
    }));
}
