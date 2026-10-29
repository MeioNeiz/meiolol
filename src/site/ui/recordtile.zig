//! RecordTile: one record from a player's games (your-games.md "Highlights"): the figure
//! large, a label of 1-3 words, and the game it came from as a chip (your champion and
//! theirs, W or L, the date), a link to that game at the record's moment. Colour only
//! where the figure is good or bad for you (a lead, a swing); counts and times plain. A
//! streak shows the newest results as pips under the figure, its run boxed
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const fmt = @import("fmt.zig");
const champ = @import("champ.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "RecordTile";
pub const scope = .{".c-rtile"};

pub const Chip = struct {
    me: champ.Champ,
    opp: ?champ.Champ = null,
    win: bool,
    date: tree.Text,
    href: ?[]const u8 = null,
};

pub const Tile = struct {
    label: tree.Text,
    value: tree.Text,
    /// The figure's colour; null is plain ink
    step: ?fmt.Step = null,
    game: ?Chip = null,
    /// Results as pips, oldest first; the last `run` boxed as the streak
    form: []const bool = &.{},
    run: usize = 0,
};

const W = struct {
    pub const win = plain("W");
    pub const loss = plain("L");
    pub const won = plain("Win");
    pub const lost = plain("Loss");
};

pub fn view(h: *H, t: Tile) N {
    return h.div(.{ .class = "c-rtile" }, .{
        h.b(.{ .class = "val", .style = if (t.step) |s| h.vars(.{ .c = s }) else null }, .{t.value}),
        h.span(.{ .class = "lab" }, .{t.label}),
        if (t.form.len > 0) form(h, t.form, t.run) else null,
        if (t.game) |c| chip(h, c) else null,
    });
}

fn form(h: *H, rs: []const bool, run: usize) N {
    const k = rs.len - @min(run, rs.len);
    var before = h.list();
    var boxed = h.list();
    for (rs, 0..) |w, i| (if (i < k) &before else &boxed).add(h.el(.i, .{ .key = i, .data_win = w }, .{}));
    return h.span(.{ .class = "form", .aria_hidden = true }, .{
        before.done(),
        if (run > 0) h.span(.{ .class = "run", .data_win = rs[rs.len - 1] }, .{boxed.done()}) else null,
    });
}

fn chip(h: *H, c: Chip) N {
    const kids = .{
        champ.view(h, c.me, .{ .px = .@"20" }),
        if (c.opp) |o| champ.view(h, o, .{ .px = .@"20" }) else null,
        h.span(.{ .class = "r", .data_win = c.win, .title = if (c.win) W.won else W.lost }, .{if (c.win) W.win else W.loss}),
        h.span(.{}, .{c.date}),
    };
    if (c.href) |href| return h.a(.{ .class = "chip", .href = href }, kids);
    return h.span(.{ .class = "chip" }, kids);
}

pub const css =
    \\@layer components {
    \\  .c-rtile { display: grid; align-content: start; gap: 2px; min-width: 0; padding: var(--sp-3) var(--sp-4);
    \\    background: var(--panel); border: 1px solid var(--line); border-radius: var(--r-l); }
    \\  .c-rtile > .val { font-size: var(--fs-xl); font-weight: var(--w-b); line-height: 1.15; color: var(--c, var(--text));
    \\    font-variant-numeric: tabular-nums; overflow-wrap: anywhere; }
    \\  .c-rtile > .lab { font-size: var(--fs-s); color: var(--muted); }
    \\  .c-rtile > .chip { justify-self: start; display: inline-flex; align-items: center; gap: 4px; margin-top: var(--sp-1);
    \\    padding: 2px 8px 2px 2px; border-radius: var(--r-pill); background: var(--ctl-bg); color: var(--t2);
    \\    font-size: var(--fs-xs); font-variant-numeric: tabular-nums; text-decoration: none; }
    \\  .c-rtile > a.chip:hover { background: var(--ctl-bg-2); color: var(--text); }
    \\  .c-rtile > a.chip:focus-visible { outline: 2px solid var(--focus); outline-offset: 2px; }
    \\  .c-rtile > .form { display: flex; align-items: center; gap: 3px; margin-top: var(--sp-1); }
    \\  .c-rtile .form i { width: 7px; height: 14px; border-radius: 2px; background: var(--them); opacity: 0.35; }
    \\  .c-rtile .form i[data-win] { background: var(--us); }
    \\  .c-rtile .form > .run { display: flex; gap: 3px; padding: 2px; border-radius: 4px; box-shadow: 0 0 0 1px var(--them); }
    \\  .c-rtile .form > .run[data-win] { box-shadow: 0 0 0 1px var(--us); }
    \\  .c-rtile .form > .run i { opacity: 1; }
    \\  .c-rtile .r { font-weight: var(--w-b); color: var(--them); }
    \\  .c-rtile .r[data-win] { color: var(--us); }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const ahri = champ.demo("Ahri", "Ahri");
    const zed = champ.demo("Zed", "Zed");
    g.add("a lead", view(h, .{ .label = plain("Biggest lead at 14"), .value = plain("+1,759"), .step = .of(1759, .{ 250, 750, 1500, 2500 }), .game = .{ .me = ahri, .opp = zed, .win = true, .date = plain("19 Oct"), .href = "#" } }));
    g.add("a time, no opponent", view(h, .{ .label = plain("Longest game"), .value = plain("41:07"), .game = .{ .me = ahri, .win = false, .date = plain("17 Oct"), .href = "#" } }));
    g.add("no game", view(h, .{ .label = plain("Record"), .value = plain("16–8") }));
    g.add("a streak", view(h, .{ .label = plain("Win streak"), .value = plain("5"), .form = &.{ true, false, false, true, false, true, true, true, true, true }, .run = 5 }));
}
