//! Versus: your team against theirs, one figure at a time. `split`: per item the two
//! counts and a bar split by share, yours left in --us and theirs right in --them; the
//! side that got it first carries a "1st" mark with its time on hover and for screen
//! readers (game-detail.md "Objectives and firsts"). `race`: when you and your opponent
//! got somewhere, the typical time a tick, the gap to typical a signed figure (later is
//! worse). `band`: one figure on a track, the typical middle half shaded and its median
//! a tick (game-detail.md "Lane"); `cell` the same at a list row's size, the figure under
//! the track and the label only for screen readers (GameRow's lane at 14). `rows`: one
//! side against the other mirrored, a row per figure, bars growing out from the middle,
//! the larger (or earlier) figure bold (matchup.md "Versus"). `dumbbell`: a row per item,
//! two rates on a shared axis as dots, the line between them the gap, the gap a figure
//! (pool.md "How hard to pick up": new against practised players)
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const objicon = @import("objicon.zig");
const champ = @import("champ.zig");
const badge = @import("badge.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "Versus";
pub const scope = .{".c-vs"};

pub const Item = struct {
    label: tree.Text,
    icon: ?objicon.Kind = null,
    us: tree.Text,
    them: tree.Text,
    /// The bar's share: us / (us + them); null when both are 0
    share: ?f32,
    first: ?struct { ours: bool, t: u16 } = null,
};

const W = struct {
    pub const label = plain("Your team against theirs");
    pub const rows = phrase.Phrase("{a:text} against {b:text}");
    pub const first = plain("1st");
    pub const first_at = phrase.Phrase("First at {t:time}");
    pub const times = phrase.Phrase("{a:text} {x:text} · {b:text} {y:text}");
    pub const typ_at = phrase.Phrase(" · typical {t:time}");
    pub const you = plain("You");
    pub const gap = phrase.Phrase("{v:signed}s");
    pub const typ = phrase.Phrase("typ {v:signed}");
    pub const never = plain("–");
    pub const tick = phrase.Phrase("{v:int}%");
    pub const bell = phrase.Phrase("{a:text} {x:rate}, {b:text} {y:rate}");
};

pub const Race = struct {
    label: tree.Text,
    /// Seconds; null when not reached
    you: ?u16,
    them: ?u16,
    typ: ?u16 = null,
    a: champ.Champ,
    b: champ.Champ,
};

pub fn race(h: *H, r: Race) N {
    var lo: u16 = std.math.maxInt(u16);
    var hi: u16 = 0;
    for ([_]?u16{ r.you, r.them, r.typ }) |v| if (v) |x| {
        lo = @min(lo, x);
        hi = @max(hi, x);
    };
    if (hi == 0) return .none;
    // Half a minute either side, on whole half minutes
    lo = (lo -| 30) / 30 * 30;
    hi = (hi + 59) / 30 * 30;
    const at = struct {
        fn f(v: u16, a: u16, b: u16) f32 {
            return @round(@as(f32, @floatFromInt(v - a)) * 1000 / @as(f32, @floatFromInt(b - a))) / 10;
        }
    }.f;
    const t = struct {
        fn f(hh: *H, v: ?u16) tree.Text {
            return if (v) |x| phrase.num(hh, .time, x) else W.never;
        }
    }.f;
    var ax = h.list();
    if (r.you != null and r.them != null) ax.add(h.span(.{ .class = "join", .style = h.vars(.{ .a = at(@min(r.you.?, r.them.?), lo, hi), .b = at(@max(r.you.?, r.them.?), lo, hi) }) }, .{}));
    if (r.typ) |v| ax.add(h.span(.{ .class = "typ", .style = h.vars(.{ .x = at(v, lo, hi) }) }, .{}));
    if (r.them) |v| ax.add(h.span(.{ .class = "ic", .style = h.vars(.{ .x = at(v, lo, hi) }) }, .{champ.view(h, r.b, .{ .px = .@"20", .named = false })}));
    if (r.you) |v| ax.add(h.span(.{ .class = "ic", .style = h.vars(.{ .x = at(v, lo, hi) }) }, .{champ.view(h, r.a, .{ .px = .@"20", .you = true, .named = false })}));
    const gap: ?i32 = if (r.you != null and r.typ != null) @as(i32, r.you.?) - r.typ.? else null;
    return h.div(.{ .class = "race" }, .{
        h.span(.{ .class = "lab" }, .{
            r.label,
            h.small(.{}, .{
                W.times.with(h, .{ .a = W.you.s, .x = t(h, r.you).s, .b = r.b.name, .y = t(h, r.them).s }),
                if (r.typ) |v| W.typ_at.with(h, .{ .t = v }) else null,
            }),
        }),
        if (gap) |g| h.b(.{ .class = "fig", .data_side = side(g < 0, g > 0) }, .{W.gap.with(h, .{ .v = g })}) else null,
        h.div(.{ .class = "ax", .aria_hidden = true }, .{ax.done()}),
    });
}

fn side(good: bool, bad: bool) ?[]const u8 {
    return if (good) "us" else if (bad) "them" else null;
}

pub const Band = struct {
    label: tree.Text,
    you: i32,
    /// Typical [p25, p50, p75]
    typ: ?[3]i32 = null,
    /// The track runs -dom to +dom
    dom: i32,
};

pub fn band(h: *H, b: Band) N {
    const md: ?i32 = if (b.typ) |q| q[1] else null;
    return h.div(.{ .class = "bnd" }, .{
        h.span(.{ .class = "lab" }, .{b.label}),
        h.b(.{ .class = "fig", .data_side = bandSide(b) }, .{phrase.num(h, .signed, b.you)}),
        track(h, b),
        h.span(.{ .class = "ends", .aria_hidden = true }, .{
            h.span(.{}, .{phrase.num(h, .signed, -b.dom)}),
            if (md) |m| h.span(.{}, .{W.typ.with(h, .{ .v = m })}) else null,
            h.span(.{}, .{phrase.num(h, .signed, b.dom)}),
        }),
    });
}

/// `fig` written under the track ("−768 at 14")
pub fn cell(h: *H, b: Band, fig: tree.Text) N {
    return h.span(.{ .class = "c-vs", .data_v = "cell", .title = b.label }, .{
        track(h, b),
        h.span(.{ .class = "fig", .data_side = bandSide(b) }, .{fig}),
    });
}

/// Against the typical median: better is ours
fn bandSide(b: Band) ?[]const u8 {
    const q = b.typ orelse return null;
    return side(b.you > q[1], b.you < q[1]);
}

fn track(h: *H, b: Band) N {
    const d: f32 = @floatFromInt(@max(b.dom, 1));
    const at = struct {
        fn f(v: i32, dd: f32) f32 {
            return @round(std.math.clamp((@as(f32, @floatFromInt(v)) + dd) / (2 * dd), 0, 1) * 1000) / 10;
        }
    }.f;
    return h.span(.{ .class = "tr", .aria_hidden = true }, .{
        if (b.typ) |q| h.span(.{ .class = "q", .style = h.vars(.{ .a = at(q[0], d), .b = at(q[2], d) }) }, .{}) else null,
        if (b.typ) |q| h.span(.{ .class = "typ", .style = h.vars(.{ .x = at(q[1], d) }) }, .{}) else null,
        h.span(.{ .class = "you", .style = h.vars(.{ .x = at(b.you, d) }) }, .{}),
    });
}

pub const Row = struct {
    label: tree.Text,
    a: tree.Text,
    b: tree.Text,
    /// Bar lengths, of half the row: none for a timing
    bars: ?[2]f32 = null,
    /// The side shown bold
    lead: ?Side = null,
    /// Under the label, small: "8 s apart"
    sub: ?tree.Text = null,
};

pub const Side = enum { a, b };

/// `names`: the two sides, over their columns
pub fn rows(h: *H, names: [2][]const u8, items: []const Row) N {
    var l = h.list();
    for (items, 0..) |r, i| l.add(h.div(.{ .key = i, .class = "mr" }, .{
        h.span(.{ .class = "n us", .data_lead = r.lead == .a }, .{r.a}),
        h.span(.{ .class = "mid" }, .{
            h.span(.{ .class = "lab" }, .{ r.label, if (r.sub) |x| h.small(.{}, .{x}) else null }),
            if (r.bars) |b| h.span(.{ .class = "bars", .aria_hidden = true, .style = h.vars(.{ .a = pct(b[0]), .b = pct(b[1]) }) }, .{}) else null,
        }),
        h.span(.{ .class = "n them", .data_lead = r.lead == .b }, .{r.b}),
    }));
    return h.div(.{ .class = "c-vs", .data_v = "rows", .role = "group", .aria_label = W.rows.with(h, .{ .a = names[0], .b = names[1] }) }, .{
        h.div(.{ .class = "who", .aria_hidden = true }, .{ h.span(.{ .class = "us" }, .{names[0]}), h.span(.{ .class = "them" }, .{names[1]}) }),
        l.done(),
    });
}

pub const Bell = struct {
    /// A champion's icon and name, as a link
    head: N,
    /// Rates on the axis, percent: the first dot and the second
    a: f32,
    b: f32,
    /// After the track: "+11.0"
    fig: tree.Text,
    /// Under the head: a Badge
    tag: ?N = null,
    /// Few games: faded
    thin: bool = false,
};

pub const Bells = struct {
    /// The two dots, for the legend: "New", "Practised"
    names: [2][]const u8,
    /// Over the figures: "Gap"
    fig: tree.Text,
    /// Axis ends and ticks, percent
    lo: f32,
    hi: f32,
    ticks: []const u8,
};

pub fn dumbbell(h: *H, o: Bells, items: []const Bell) N {
    const at = struct {
        fn f(b: Bells, v: f32) f32 {
            return pct((v - b.lo) / (b.hi - b.lo));
        }
    }.f;
    var ticks = h.list();
    for (o.ticks, 0..) |t, i| ticks.add(h.span(.{ .key = i, .style = h.vars(.{ .x = at(o, @floatFromInt(t)) }) }, .{W.tick.with(h, .{ .v = t })}));
    var l = h.list();
    for (items, 0..) |it, i| {
        const a = at(o, it.a);
        const b = at(o, it.b);
        l.add(h.div(.{ .key = i, .class = "bl", .data_thin = it.thin }, .{
            h.span(.{ .class = "hd" }, .{ it.head, it.tag }),
            h.span(.{ .class = "tk", .role = "img", .aria_label = W.bell.with(h, .{ .a = o.names[0], .x = it.a, .b = o.names[1], .y = it.b }), .style = h.vars(.{ .a = a, .b = b, .l = @min(a, b), .w = @abs(b - a) }) }, .{
                h.span(.{ .class = "a" }, .{}),
                h.span(.{ .class = "b" }, .{}),
            }),
            h.span(.{ .class = "fig" }, .{it.fig}),
        }));
    }
    return h.div(.{ .class = "c-vs", .data_v = "bell" }, .{
        h.div(.{ .class = "bl ax", .aria_hidden = true }, .{
            h.span(.{ .class = "hd key" }, .{ h.span(.{ .class = "a" }, .{}), o.names[0], h.span(.{ .class = "b" }, .{}), o.names[1] }),
            h.span(.{ .class = "tx" }, .{ticks.done()}),
            h.span(.{ .class = "fig" }, .{o.fig}),
        }),
        l.done(),
    });
}

fn pct(f: f32) f32 {
    return @round(std.math.clamp(f, 0, 1) * 1000) / 10;
}

pub fn split(h: *H, items: []const Item) N {
    var l = h.list();
    for (items, 0..) |it, i| {
        const mark = struct {
            fn f(hh: *H, x: Item, ours: bool) ?N {
                const fi = x.first orelse return null;
                if (fi.ours != ours) return null;
                const at = W.first_at.with(hh, .{ .t = fi.t });
                return hh.el(.abbr, .{ .class = "first", .title = at, .aria_label = at }, .{W.first});
            }
        }.f;
        l.add(h.div(.{ .key = i, .class = "it" }, .{
            h.span(.{ .class = "lab" }, .{ if (it.icon) |k| objicon.view(h, k, .{ .s = .s, .named = false }) else null, it.label }),
            h.span(.{ .class = "n us" }, .{ it.us, mark(h, it, true) }),
            h.span(.{ .class = "n them" }, .{ mark(h, it, false), it.them }),
            h.span(.{ .class = "bar", .aria_hidden = true, .style = if (it.share) |s| h.vars(.{ .s = @round(s * 1000) / 10 }) else null, .data_none = it.share == null }, .{}),
        }));
    }
    return h.div(.{ .class = "c-vs", .role = "group", .aria_label = W.label }, .{l.done()});
}

pub const css =
    \\@layer components {
    \\  .c-vs { display: grid; grid-template-columns: repeat(auto-fit, minmax(88px, 1fr)); gap: var(--sp-3) var(--sp-4); }
    \\  .c-vs .it { display: grid; grid-template-columns: 1fr 1fr; align-items: baseline; row-gap: 2px; min-width: 0; }
    \\  .c-vs .lab { grid-column: 1 / -1; justify-self: center; display: inline-flex; align-items: center; gap: 4px;
    \\    font-size: var(--fs-xs); color: var(--muted); white-space: nowrap; }
    \\  .c-vs .n { font-size: var(--fs-l); font-weight: var(--w-b); font-variant-numeric: tabular-nums; line-height: 1.2;
    \\    display: inline-flex; align-items: baseline; gap: 4px; white-space: nowrap; }
    \\  .c-vs .n.us { color: var(--us-hot); }
    \\  .c-vs .n.them { color: var(--them-hot); justify-content: flex-end; }
    \\  .c-vs .first { font-size: var(--fs-xs); font-weight: var(--w-m); color: var(--brand-dot); text-decoration: none;
    \\    border-bottom: 1px solid currentColor; line-height: 1.1; cursor: help; }
    \\  .c-vs .bar { grid-column: 1 / -1; height: 4px; border-radius: 2px;
    \\    background: linear-gradient(90deg, var(--us) calc(var(--s, 50) * 1% - 1px), transparent 0 calc(var(--s, 50) * 1% + 1px), var(--them) 0); }
    \\  .c-vs .bar[data-none] { background: var(--bar-track); }
    \\  .c-vs > .race, .c-vs > .bnd { display: grid; grid-template-columns: minmax(0, 1fr) auto; align-items: end; gap: 6px var(--sp-2); }
    \\  .c-vs .race > .lab, .c-vs .bnd > .lab { grid-column: 1; justify-self: start; display: block; font-size: var(--fs-s); color: var(--t2); white-space: normal; }
    \\  .c-vs .race small { display: block; font-size: var(--fs-xs); color: var(--faint); }
    \\  .c-vs .fig { font-variant-numeric: tabular-nums; color: var(--t2); }
    \\  .c-vs .fig[data-side="us"] { color: var(--us-hot); }
    \\  .c-vs .fig[data-side="them"] { color: var(--them-hot); }
    \\  .c-vs .ax, .c-vs .tr { grid-column: 1 / -1; position: relative; height: 24px; }
    \\  .c-vs .ax::before { content: ""; position: absolute; inset: 50% 0 auto; height: 1px; background: var(--line-2); }
    \\  .c-vs .ax > .join { position: absolute; top: calc(50% - 1px); height: 3px; left: calc(var(--a) * 1%); width: calc((var(--b) - var(--a)) * 1%); background: var(--t2); opacity: 0.5; }
    \\  .c-vs .ax > .typ, .c-vs .tr > .typ { position: absolute; top: 4px; bottom: 4px; left: calc(var(--x) * 1%); width: 2px; margin-left: -1px; background: var(--text); }
    \\  .c-vs .ax > .ic { position: absolute; top: 2px; left: calc(var(--x) * 1%); margin-left: -10px; display: flex; }
    \\  .c-vs .tr { height: 14px; margin-top: 4px; border-radius: 3px; background: var(--bar-track); }
    \\  .c-vs .tr::before { content: ""; position: absolute; top: -3px; bottom: -3px; left: 50%; width: 1px; background: var(--line-2); }
    \\  .c-vs .tr > .q { position: absolute; inset: 0 auto; left: calc(var(--a) * 1%); width: calc((var(--b) - var(--a)) * 1%); background: var(--wash); box-shadow: inset 0 0 0 1px var(--line-2); }
    \\  .c-vs .tr > .typ { top: 0; bottom: 0; }
    \\  .c-vs .tr > .you { position: absolute; top: -4px; bottom: -4px; left: calc(var(--x) * 1%); width: 8px; margin-left: -4px; border-radius: 3px; background: var(--us); box-shadow: 0 0 0 2px var(--panel); }
    \\  .c-vs[data-v="rows"] { grid-template-columns: minmax(0, 1fr); gap: var(--sp-2); }
    \\  .c-vs > .who { display: flex; justify-content: space-between; font-weight: var(--w-b); }
    \\  .c-vs > .who > .us { color: var(--us-hot); }
    \\  .c-vs > .who > .them { color: var(--them-hot); }
    \\  .c-vs > .mr { display: grid; grid-template-columns: 3.4em minmax(0, 1fr) 3.4em; align-items: center; gap: var(--sp-2); }
    \\  .c-vs .mr > .n { font-size: var(--fs-m); font-weight: var(--w-m); font-variant-numeric: tabular-nums; color: var(--t2); }
    \\  .c-vs .mr > .them { text-align: right; justify-content: flex-end; }
    \\  .c-vs .mr > .n[data-lead] { font-weight: var(--w-b); color: var(--text); }
    \\  .c-vs .mr > .mid { display: flex; flex-direction: column; align-items: center; gap: 3px; min-width: 0; }
    \\  .c-vs .mr .lab small { margin-left: 6px; color: var(--faint); }
    \\  .c-vs .mr .bars { align-self: stretch; height: 5px;
    \\    background: linear-gradient(90deg, transparent calc(50% - var(--a) * 0.5%), var(--us) 0 calc(50% - 1px), transparent 0 calc(50% + 1px),
    \\      var(--them) 0 calc(50% + var(--b) * 0.5%), transparent 0); border-radius: 3px; }
    \\  .c-vs[data-v="cell"] { display: flex; flex-direction: column; gap: 3px; width: 96px; }
    \\  .c-vs[data-v="cell"] > .tr { display: block; height: 8px; margin-top: 3px; }
    \\  .c-vs[data-v="cell"] .tr > .you { top: -3px; bottom: -3px; width: 6px; margin-left: -3px; }
    \\  .c-vs[data-v="cell"] > .fig { font-size: var(--fs-xs); white-space: nowrap; }
    \\  .c-vs[data-v="bell"] { grid-template-columns: minmax(0, 1fr); gap: 0; }
    \\  .c-vs > .bl { display: grid; grid-template-columns: minmax(0, 10em) minmax(0, 1fr) 3.4em; align-items: center; gap: var(--sp-2); min-height: 32px; }
    \\  .c-vs > .bl[data-thin] { opacity: 0.55; }
    \\  .c-vs > .bl + .bl:not(.ax) { border-top: 1px solid var(--line); }
    \\  .c-vs .bl > .hd { display: flex; flex-wrap: wrap; align-items: center; gap: 2px 6px; min-width: 0; }
    \\  .c-vs .hd > a { display: inline-flex; align-items: center; gap: 6px; min-width: 0; color: inherit; text-decoration: none; }
    \\  .c-vs .hd > a:hover { text-decoration: underline; }
    \\  .c-vs .bl > .key { font-size: var(--fs-xs); color: var(--muted); gap: 4px; }
    \\  .c-vs .key > span, .c-vs .tk > span { width: 9px; height: 9px; border-radius: 50%; box-sizing: border-box; }
    \\  .c-vs .bl > .fig { text-align: right; font-variant-numeric: tabular-nums; }
    \\  .c-vs .bl.ax > .fig { font-size: var(--fs-xs); color: var(--muted); }
    \\  .c-vs .bl > .tx { position: relative; height: 16px; font-size: var(--fs-xs); color: var(--faint); font-variant-numeric: tabular-nums; }
    \\  .c-vs .tx > span { position: absolute; left: calc(var(--x) * 1%); transform: translateX(-50%); white-space: nowrap; }
    \\  .c-vs .bl > .tk { position: relative; height: 14px; background: linear-gradient(var(--line), var(--line)) 0 50% / 100% 1px no-repeat; }
    \\  .c-vs .tk::before { content: ""; position: absolute; top: calc(50% - 1.5px); height: 3px; left: calc(var(--l) * 1%); width: calc(var(--w) * 1%); background: var(--line-2); }
    \\  .c-vs .tk > span { position: absolute; top: 50%; margin: -4.5px 0 0 -4.5px; }
    \\  .c-vs .tk > .a { left: calc(var(--a) * 1%); }
    \\  .c-vs .tk > .b { left: calc(var(--b) * 1%); }
    \\  .c-vs .key > .a, .c-vs .tk > .a { border: 2px solid var(--t2); background: var(--panel); }
    \\  .c-vs .key > .b, .c-vs .tk > .b { background: var(--brand-dot); }
    \\  .c-vs .bnd > .ends { grid-column: 1 / -1; display: flex; justify-content: space-between; font-size: var(--fs-xs); color: var(--faint); font-variant-numeric: tabular-nums; }
    \\}
    \\
;

pub const demo = [_]Item{
    .{ .label = plain("Kills"), .us = plain("53"), .them = plain("44"), .share = 53.0 / 97.0, .first = .{ .ours = true, .t = 195 } },
    .{ .label = plain("Gold"), .us = plain("91k"), .them = plain("85k"), .share = 91.0 / 176.0 },
    .{ .label = plain("Towers"), .icon = .tower, .us = plain("9"), .them = plain("7"), .share = 9.0 / 16.0, .first = .{ .ours = false, .t = 853 } },
    .{ .label = plain("Dragons"), .icon = .dragon, .us = plain("4"), .them = plain("2"), .share = 4.0 / 6.0, .first = .{ .ours = true, .t = 417 } },
    .{ .label = plain("Grubs"), .icon = .grubs, .us = plain("3"), .them = plain("0"), .share = 1 },
    .{ .label = plain("Herald"), .icon = .herald, .us = plain("0"), .them = plain("0"), .share = null },
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.addFill("objectives and firsts", split(h, &demo));
    g.add("two", split(h, demo[0..2]));
    const a = champ.demo("Katarina", "Katarina");
    const b = champ.demo("Annie", "Annie");
    g.add("races: level 6 later than typical, first item earlier", h.div(.{ .class = "c-vs" }, .{
        race(h, .{ .label = plain("Level 6"), .you = 391, .them = 315, .typ = 339, .a = a, .b = b }),
        race(h, .{ .label = plain("First item"), .you = 650, .them = 714, .typ = 681, .a = a, .b = b }),
        race(h, .{ .label = plain("First item"), .you = null, .them = 714, .a = a, .b = b }),
    }));
    g.addFill("mirrored rows: a matchup's head to head", rows(h, .{ "Darius", "Garen" }, &.{
        .{ .label = plain("Wins"), .a = plain("50%"), .b = plain("50%"), .bars = .{ 0.5, 0.5 } },
        .{ .label = plain("Ahead at 14"), .a = plain("61%"), .b = plain("39%"), .bars = .{ 0.61, 0.39 }, .lead = .a },
        .{ .label = plain("First blood"), .a = plain("15%"), .b = plain("17%"), .bars = .{ 0.15, 0.17 }, .lead = .b },
        .{ .label = plain("Level 6"), .a = plain("5:19"), .b = plain("5:28"), .lead = .a, .sub = plain("9 s apart") },
        .{ .label = plain("First item"), .a = plain("12:04"), .b = plain("–") },
    }));
    g.addFill("dumbbell: new against practised players, a gap each; a thin row", dumbbell(h, .{ .names = .{ "New", "Practised" }, .fig = plain("Gap"), .lo = 40, .hi = 56, .ticks = &.{ 40, 45, 50, 55 } }, &.{
        .{ .head = bellHead(h, "Rengar"), .a = 41.2, .b = 52.2, .fig = plain("+11.0"), .tag = badge.view(h, .neutral, .{plain("Harder")}) },
        .{ .head = bellHead(h, "Udyr"), .a = 43.0, .b = 52.9, .fig = plain("+9.9") },
        .{ .head = bellHead(h, "Garen"), .a = 50.8, .b = 52.1, .fig = plain("+1.3"), .tag = badge.view(h, .neutral, .{plain("Easier")}) },
        .{ .head = bellHead(h, "Taliyah"), .a = 46.0, .b = 51.5, .fig = plain("+5.5"), .thin = true },
    }));
    g.add("bands: below typical, above, no typical", h.div(.{ .class = "c-vs" }, .{
        band(h, .{ .label = plain("Gold lead at 14"), .you = -768, .typ = .{ -1677, -63, 511 }, .dom = 2500 }),
        band(h, .{ .label = plain("CS lead at 10"), .you = 12, .typ = .{ -9, -1, 6 }, .dom = 30 }),
        band(h, .{ .label = plain("CS lead at 10"), .you = -4, .dom = 30 }),
    }));
    g.add("cells: below typical, above, no typical", h.div(.{ .class = "g-row" }, .{
        cell(h, .{ .label = plain("Gold lead at 14"), .you = -768, .typ = .{ -1677, -63, 511 }, .dom = 3000 }, plain("−768 at 14")),
        cell(h, .{ .label = plain("Gold lead at 14"), .you = 1084, .typ = .{ -200, 300, 900 }, .dom = 3000 }, plain("+1,084 at 14")),
        cell(h, .{ .label = plain("Gold lead at 14"), .you = -3408, .dom = 3000 }, plain("−3,408 at 14")),
    }));
}

fn bellHead(h: *H, comptime key: []const u8) N {
    return h.a(.{ .href = "#" }, .{ champ.view(h, champ.demo(key, key), .{ .named = false }), key });
}

test "dumbbell: dots and the gap on the axis, legend and ticks, thin rows marked" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    const fig = dumbbell(&h, .{ .names = .{ "New", "Practised" }, .fig = plain("Gap"), .lo = 40, .hi = 60, .ticks = &.{ 40, 50 } }, &.{
        .{ .head = h.text("Rengar"), .a = 45, .b = 55, .fig = plain("+10.0") },
        .{ .head = h.text("Garen"), .a = 52, .b = 50, .fig = plain("−2.0"), .thin = true },
    });
    var out: std.Io.Writer.Allocating = .init(arena.allocator());
    try @import("html.zig").write(&t, fig, &out.writer);
    const s = out.written();
    try std.testing.expect(std.mem.indexOf(u8, s, "--a:25;--b:75;--l:25;--w:50") != null);
    // Practised below new: the line still runs left to right
    try std.testing.expect(std.mem.indexOf(u8, s, "--a:60;--b:50;--l:50;--w:10") != null);
    try std.testing.expect(std.mem.indexOf(u8, s, "aria-label=\"New 45.0%, Practised 55.0%\"") != null);
    try std.testing.expectEqual(1, std.mem.count(u8, s, "data-thin"));
    try std.testing.expect(std.mem.indexOf(u8, s, ">50%</span>") != null);
}
