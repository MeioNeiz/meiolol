//! StatStrip: a page's headline figures in one row, plain (no box per figure): a small
//! label over each value, the answer larger, a value on the scale's colour where it has
//! one, context after it small ("4th of 53"). A range shows on hover as its ends, never as
//! a ± figure; a rate fades when its range is wide, never hides (J35). Three to a row in a
//! narrow container. A label can open a Toggletip; a figure can link to where it comes from, or be pressed
//! (the game page's cells select their span; the selected one shows pressed)
const tree = @import("tree.zig");
const fmt = @import("fmt.zig");
const stat = @import("stat.zig");
const toggletip = @import("toggletip.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = @import("phrase.zig").plain;
const bar = @import("bar.zig");
const card = @import("card.zig");
const champ = @import("champ.zig");
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
    /// A rate's 80% half-width (fmt.range): past fmt.wide_range the value fades
    range: ?f64 = null,
    /// The value's hover: its range's ends (stat.ends), with its games (stat.endsGames)
    ends: ?tree.Text = null,
    /// Games behind the value, faint after it: phrase.num .kilo. Made by the caller, so
    /// families without counts don't carry the code
    games: ?tree.Text = null,
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

/// An Item and what shows its place, the row's third column (bar.track)
pub const Row = struct {
    item: Item,
    bar: N = .none,
};

/// One row per item, every row the same columns: label, value, bar, context. In a
/// taller card the rows spread out. `ends`: under the last row, the bars' two ends named
/// once ("lowest", "highest"). Items' `href`, `on` and `answer` don't apply
pub fn rows(h: *H, rs: []const Row, ends: ?[2]tree.Text) N {
    var l = h.list();
    for (rs, 0..) |r, i| {
        const ctx = if (r.item.ctx) |c| h.small(.{ .class = "c" }, .{c}) else null;
        l.add(h.div(.{ .key = i }, .{ lab(h, r.item), val(h, r.item, false), h.span(.{ .class = "bar" }, .{r.bar}), ctx }));
    }
    const foot = if (ends) |e| h.p(.{ .class = "ends", .aria_hidden = true }, .{ h.span(.{}, .{e[0]}), h.span(.{}, .{e[1]}) }) else null;
    return h.div(.{ .class = "c-strip", .data_rows = true, .data_grow = {} }, .{ l.done(), foot });
}

fn lab(h: *H, it: Item) N {
    const tip: ?[2]N = if (it.tip) |t| toggletip.view(h, t.id, .{it.label}, it.label, t.note) else null;
    return h.span(.{ .class = "lab" }, .{ if (tip) |*t| t else null, if (tip == null) it.label else null });
}

/// The value with its count; `with_ctx`: the context inside it too (view's), else the
/// caller places it
fn val(h: *H, it: Item, with_ctx: bool) N {
    const style = if (it.step) |s| h.vars(.{ .c = s }) else null;
    const wide = if (it.range) |r| fmt.wide(r) else false;
    const ends: ?[]const u8 = if (it.ends) |e| e.s else null;
    // Count and context share one element shape (class of one letter): one tree
    // builder in every family, which matters to ui-games at its budget
    const games = if (it.games) |t| h.small(.{ .class = "g" }, .{t}) else null;
    const ctx = if (with_ctx) if (it.ctx) |c| h.small(.{ .class = "c" }, .{c}) else null else null;
    const kids = .{ it.value, games, ctx };
    return if (it.on) |on| h.button(.{
        .class = "val",
        .type = "button",
        .style = style,
        .data_wide = wide,
        .aria_pressed = it.pressed,
        .title = ends,
        .aria_label = W.cell.with(h, .{ .l = it.label.s, .v = it.value.s }),
        .on_click = on,
    }, kids) else h.span(.{ .class = "val", .style = style, .data_wide = wide, .title = ends }, kids);
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
    \\  .c-strip .val > .g { margin-left: 6px; }
    \\  .c-strip .val > .g + .c { display: block; line-height: 1.2; }
    \\  .c-strip .val[data-wide] { opacity: 0.55; }
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
    \\  .c-strip[data-rows] { display: grid; grid-template-columns: auto auto minmax(0, 1fr) auto;
    \\    align-content: space-evenly; gap: var(--sp-1) var(--sp-3); }
    \\  .c-strip[data-rows] > div { display: grid; grid-column: 1 / -1; grid-template-columns: subgrid; align-items: center; }
    \\  .c-strip[data-rows] .lab { font-size: var(--fs-s); }
    \\  .c-strip[data-rows] .val { font-size: var(--fs-m); font-weight: var(--w-m); text-align: right; }
    \\  .c-strip[data-rows] > div > .c { font-size: var(--fs-s); color: var(--muted); font-variant-numeric: tabular-nums;
    \\    min-width: 3.5em; }
    \\  .c-strip[data-rows] > .ends { grid-column: 3; display: flex; flex-direction: row; justify-content: space-between;
    \\    gap: var(--sp-2); margin: 0 10px; font-size: var(--fs-xs); color: var(--faint); }
    \\  @container (max-width: 440px) {
    \\    .c-strip { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: var(--sp-2); }
    \\    .c-strip .val > .c { display: block; line-height: 1.2; }
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
            .range = 0.6,
            .ends = plain("50.6-51.8%, 44,935 games"),
            .games = plain("45k"),
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
        .{ .label = plain("Won"), .value = plain("49.3%"), .range = fmt.range(64, 32), .ends = plain("41.4-57.2%, 64 games"), .games = plain("64"), .ctx = plain("44th of 59"), .step = .of(-0.7, agg), .answer = true },
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
        .{ .label = plain("Biggest drop"), .value = plain("−19"), .ctx = plain("12–13"), .step = .of(-19, fmt.game_cuts), .on = on },
        .{ .label = plain("Ahead"), .value = plain("13"), .ctx = plain("of 33 min") },
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
    const ornn = champ.demo("Ornn", "Ornn");
    var rs: [eog.len]Row = undefined;
    inline for (eog, 0..) |x, i| rs[i] = .{
        .item = .{ .label = plain(x[0]), .value = plain(x[1]), .ctx = plain(x[3]) },
        .bar = bar.track(h, .{ .at = @as(f64, @floatFromInt(60 - @as(u16, x[2]))) / 59, .ref = 0.5, .mark = champ.view(h, ornn, .{ .px = .@"20", .named = false }) }),
    };
    const body = h.p(.{ .class = "muted" }, .{"Card body"});
    g.addFill("rows: places on tracks, the ends named once; stretched by a taller card", card.row(h, &.{
        card.view(h, .{}, &.{ card.head(h, plain("Taller"), null, &.{}), body, body, body, body, body, body, body, body, body, body, body, body, body }),
        card.view(h, .{}, &.{ card.head(h, plain("End of game"), plain("of 60 champions"), &.{}), rows(h, &rs, .{ plain("lowest"), plain("highest") }) }),
    }));
}
