//! ChoiceCards: a puzzle's 2 to 6 answers as cards, each with its key number (the page
//! binds keys 1-6 and Enter); a champion card is a row like a DraftBoard seat. Choosing marks a card (the others dim) and the page
//! commits with its own button; once done, the cards stop being buttons and the answer
//! is marked right, a wrong choice wrong. Champion cards (icon, name) or side cards
//! (label in the side's colour, the side's five icons): Daily's pick and "Who won?",
//! Learn's drills. Phone: six champions fit one row of icons, names kept for readers
const std = @import("std");
const tree = @import("tree.zig");
const champ = @import("champ.zig");
const phrase = @import("phrase.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "ChoiceCards";
pub const scope = .{ ".c-choices", ".c-choice" };

pub const Side = enum { us, them };
pub const Mark = enum { none, right, wrong };

pub const Choice = struct {
    /// A champion card; null for a side card
    champ: ?champ.Champ = null,
    /// A side card's label ("Blue")
    label: tree.Text = .{ .s = "" },
    side: ?Side = null,
    /// A side card's champions
    icons: []const champ.Champ = &.{},
    chosen: bool = false,
    /// After the commit
    mark: Mark = .none,
    /// After the commit, under the name: the answer's figure ("won 58%")
    sub: ?tree.Text = null,
    on: ?tree.Handler = null,
};

pub const Opts = struct {
    /// Answered: no more choosing
    done: bool = false,
    /// What is asked, for screen readers ("Red's last pick")
    label: ?tree.Text = null,
};

pub fn view(h: *H, o: Opts, choices: []const Choice) N {
    var l = h.list();
    for (choices, 0..) |c, i| {
        const kids = .{
            if (c.champ) |x| champ.view(h, x, .{ .px = .@"56", .named = false }) else null,
            if (c.champ) |x| h.span(.{ .class = "nm" }, .{x.name}) else h.b(.{ .class = "nm", .data_side = c.side }, .{c.label}),
            if (c.icons.len > 0) icons(h, c.icons) else null,
            if (o.done) if (c.sub) |s| h.span(.{ .class = "sub" }, .{s}) else null else null,
            if (o.done) mark(h, c.mark) else h.span(.{ .class = "kn", .aria_hidden = true }, .{phrase.num(h, .int, i + 1)}),
        };
        l.add(if (o.done) h.div(.{
            .key = i,
            .class = "c-choice",
            .data_mark = if (c.mark == .none) null else c.mark,
            .data_chosen = c.chosen,
        }, kids) else h.button(.{
            .key = i,
            .class = "c-choice",
            .type = "button",
            .aria_pressed = c.chosen,
            .aria_keyshortcuts = h.fmt("{d}", .{i + 1}),
            .on_click = c.on,
        }, kids));
    }
    var any = false;
    for (choices) |c| any = any or c.chosen;
    return h.div(.{
        .class = "c-choices",
        .role = "group",
        .aria_label = o.label,
        .data_n = choices.len,
        .data_side = choices.len > 0 and choices[0].side != null,
        .data_chosen = any and !o.done,
        .data_done = o.done,
    }, .{l.done()});
}

fn icons(h: *H, cs: []const champ.Champ) N {
    var l = h.list();
    for (cs, 0..) |c, i| l.add(h.span(.{ .key = i }, .{champ.view(h, c, .{ .px = .@"24" })}));
    return h.span(.{ .class = "ics" }, .{l.done()});
}

fn mark(h: *H, m: Mark) ?N {
    return switch (m) {
        .none => null,
        .right => h.span(.{ .class = "mk", .role = "img", .aria_label = W.right }, .{"✓"}),
        .wrong => h.span(.{ .class = "mk", .role = "img", .aria_label = W.wrong }, .{"✕"}),
    };
}

const W = struct {
    const right = plain("Right");
    const wrong = plain("Wrong");
};

// Champion cards are rows needing ~200 px each, so three across only from 600 px; below,
// each spans the row (the cards' container is .c-choices itself, which can't query its
// own width for its columns)
pub const css =
    \\@layer components {
    \\  .c-choices { container-type: inline-size; display: grid; grid-template-columns: repeat(2, minmax(0, 1fr));
    \\    gap: var(--sp-2); }
    \\  .c-choices[data-n="3"], .c-choices[data-n="5"], .c-choices[data-n="6"] { grid-template-columns: repeat(3, minmax(0, 1fr)); }
    \\  .c-choice { all: unset; box-sizing: border-box; position: relative; display: flex; flex-direction: column;
    \\    align-items: center; justify-content: center; gap: var(--sp-2); min-width: 0; padding: var(--sp-3) var(--sp-1) var(--sp-2);
    \\    border: 1px solid var(--line-2); border-radius: var(--r-m); background: var(--panel-2); text-align: center;
    \\    transition: border-color var(--dur) var(--ease), background var(--dur) var(--ease); }
    \\  .c-choice[type="button"] { cursor: pointer; }
    \\  .c-choice[type="button"]:hover { border-color: var(--focus); }
    \\  .c-choice[type="button"]:focus-visible { outline: 2px solid var(--focus); outline-offset: 2px; }
    \\  .c-choice .nm { max-width: 100%; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-weight: var(--w-m); }
    \\  .c-choice b.nm { font-size: var(--fs-l); font-weight: var(--w-b); white-space: normal; text-wrap: balance; }
    \\  .c-choice .nm[data-side="us"] { color: var(--us); }
    \\  .c-choice .nm[data-side="them"] { color: var(--them); }
    \\  .c-choice .sub { font-size: var(--fs-xs); color: var(--muted); font-variant-numeric: tabular-nums; }
    \\  .c-choice .ics { display: flex; gap: 3px; flex-wrap: wrap; justify-content: center; }
    \\  .c-choice .kn { position: absolute; top: 6px; right: 6px; min-width: 18px; padding: 0 4px; box-sizing: border-box;
    \\    border: 1px solid var(--line-2); border-radius: var(--r-s); font-size: var(--fs-xs); line-height: 16px;
    \\    color: var(--faint); text-align: center; font-variant-numeric: tabular-nums; }
    \\  .c-choice[aria-pressed="true"] { border-color: var(--accent); background: var(--sel-bg); box-shadow: 0 0 0 1px var(--accent); }
    \\  .c-choice[aria-pressed="true"] .kn { border-color: var(--accent); background: var(--accent); color: var(--bg); }
    \\  .c-choices[data-chosen] .c-choice:not([aria-pressed="true"]) .c-champ { opacity: 0.6; }
    \\  .c-choices[data-done] .c-choice:not([data-mark]) { opacity: 0.6; }
    \\  .c-choice[data-mark="right"] { border-color: var(--good); box-shadow: 0 0 0 1px var(--good); }
    \\  .c-choice[data-mark="wrong"] { border-color: var(--bad); }
    \\  .c-choice .mk { position: absolute; top: 4px; right: 6px; font-weight: var(--w-b); color: var(--good); }
    \\  .c-choice[data-mark="wrong"] .mk { color: var(--bad); }
    \\  .c-choices[data-side] .c-choice { min-height: 96px; }
    \\  .c-choices[data-n="6"]:has(> .c-choice > .c-champ) { grid-template-columns: repeat(2, minmax(0, 1fr)); }
    \\  .c-choice:has(> .c-champ) { display: grid; grid-template-columns: auto minmax(0, 1fr) auto; column-gap: var(--sp-3);
    \\    row-gap: 0; align-items: center; justify-items: start; padding: var(--sp-2) var(--sp-3) var(--sp-2) var(--sp-2);
    \\    border-radius: var(--r-s); text-align: left; }
    \\  .c-choice:has(> .c-champ) > .c-champ { --sz: 40px; grid-row: 1 / span 2; }
    \\  .c-choice:has(> .c-champ) > .nm { grid-column: 2; grid-row: 1 / span 2; }
    \\  .c-choice:has(> .c-champ) > :is(.kn, .mk) { position: static; grid-column: 3; grid-row: 1 / span 2; }
    \\  .c-choice:has(> .sub) > .nm { grid-row: 1; align-self: end; }
    \\  .c-choice:has(> .c-champ) > .sub { grid-column: 2; grid-row: 2; align-self: start; }
    \\  @media (pointer: coarse) { .c-choice .kn { display: none; } }
    \\  @container (max-width: 600px) {
    \\    .c-choices:is([data-n="3"], [data-n="5"]) > .c-choice:has(> .c-champ) { grid-column: 1 / -1; }
    \\  }
    \\  @container (max-width: 420px) {
    \\    .c-choices[data-side] .c-choice { min-height: 0; padding: var(--sp-2); }
    \\  }
    \\  @media (max-width: 480px) {
    \\    .c-choices[data-n="6"], .c-choices[data-n="6"]:has(> .c-choice > .c-champ) { grid-template-columns: repeat(6, minmax(0, 1fr)); gap: 4px; }
    \\    .c-choices[data-n="6"] .c-choice { display: flex; padding: 4px; gap: 0; }
    \\    .c-choices[data-n="6"] .c-champ { --sz: 44px; }
    \\    .c-choices[data-n="6"] :is(.nm, .kn) { position: absolute; width: 1px; height: 1px; overflow: hidden;
    \\      clip-path: inset(50%); white-space: nowrap; }
    \\  }
    \\}
    \\
;

const demo = champ.demo;

const six = [_]champ.Champ{
    demo("Jayce", "Jayce"),
    demo("Ambessa", "Ambessa"),
    demo("Gnar", "Gnar"),
    demo("Renekton", "Renekton"),
    demo("Jax", "Jax"),
    demo("Aatrox", "Aatrox"),
};

fn champs(h: *H, chosen: ?usize, done: bool) []const Choice {
    const cs = h.mem.alloc(Choice, six.len) catch {
        h.oom = true;
        return &.{};
    };
    for (cs, six, 0..) |*c, x, i| c.* = .{
        .champ = x,
        .chosen = chosen == i,
        .mark = if (!done) .none else if (i == 0) .right else if (chosen == i) .wrong else .none,
        .sub = if (done) .{ .s = h.fmt("won {d}%", .{54 - i}) } else null,
    };
    return cs;
}

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.addFill("six champions", view(h, .{ .label = plain("Red's last pick") }, champs(h, null, false)));
    g.addFill("one chosen, not locked in", view(h, .{}, champs(h, 1, false)));
    g.addFill("done: chose wrong", view(h, .{ .done = true }, champs(h, 1, true)));
    g.addFill("three, done: one per row when narrow", view(h, .{ .done = true }, champs(h, 2, true)[0..3]));
    g.addFill("who won: sides", view(h, .{ .label = plain("Who won") }, &.{
        .{ .label = plain("Blue"), .side = .us, .icons = six[0..5] },
        .{ .label = plain("Red"), .side = .them, .icons = six[1..6] },
    }));
    g.addFill("three, text: labels wrap, never cut", view(h, .{}, &.{
        .{ .label = plain("Nearly all") },
        .{ .label = plain("About half") },
        .{ .label = plain("Almost none") },
    }));
    g.addFill("four, text", view(h, .{}, &.{
        .{ .label = plain("Under 45%") },
        .{ .label = plain("45 to 50%"), .chosen = true },
        .{ .label = plain("50 to 55%") },
        .{ .label = plain("Over 55%") },
    }));
}

test "buttons until done, then divs with the marks; key numbers only while choosing" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const html = @import("html.zig");
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    var out: std.Io.Writer.Allocating = .init(a);
    try html.write(&t, view(&h, .{}, champs(&h, 1, false)), &out.writer);
    var s = out.written();
    try std.testing.expectEqual(6, std.mem.count(u8, s, "<button"));
    try std.testing.expectEqual(1, std.mem.count(u8, s, "aria-pressed=\"true\""));
    try std.testing.expect(std.mem.find(u8, s, "data-chosen") != null);
    try std.testing.expect(std.mem.find(u8, s, "data-side") == null);
    try std.testing.expect(std.mem.find(u8, s, "class=\"kn\"") != null);
    out = .init(a);
    try html.write(&t, view(&h, .{ .done = true }, champs(&h, 1, true)), &out.writer);
    s = out.written();
    try std.testing.expect(std.mem.find(u8, s, "<button") == null);
    try std.testing.expect(std.mem.find(u8, s, "class=\"kn\"") == null);
    try std.testing.expectEqual(1, std.mem.count(u8, s, "data-mark=\"right\""));
    try std.testing.expectEqual(1, std.mem.count(u8, s, "data-mark=\"wrong\""));
    try std.testing.expect(std.mem.find(u8, s, "won 54%") != null);
    out = .init(a);
    try html.write(&t, view(&h, .{}, &.{ .{ .label = plain("Under 45%") }, .{ .label = plain("Over 45%") } }), &out.writer);
    try std.testing.expect(std.mem.find(u8, out.written(), "data-side") == null);
}
