//! Versus: your team against theirs, one figure at a time. `split`: per item the two
//! counts and a bar split by share, yours left in --us and theirs right in --them; the
//! side that got it first carries a "1st" mark with its time on hover and for screen
//! readers (game-detail.md "Objectives and firsts"). `race`: when you and your opponent
//! got somewhere, the typical time a tick, the gap to typical a signed figure (later is
//! worse). `band`: one figure on a track, the typical middle half shaded and its median a
//! tick (game-detail.md "Lane"); `cell` the same at a list row's size, the figure under
//! the track and the label only for screen readers (GameRow's lane at 14); with `from`, a
//! hollow dot joined to the figure's: before and after (an objective not taken first,
//! taken first), each with its typical tick. `rows`: one side against the other, a row
//! per figure: both rates as dots on one 0-100% track, each number beside its dot, the
//! larger bold; a timing as both times and the gap (matchup.md "Versus"); `bars`: the
//! same rows, each side's rate its own bar on a 0-100 track, so the share with neither
//! shows (champion.md "Lane kills"); `key` names the sides, for the card head.
//! `dumbbell`: a row per item, two rates on a shared axis as dots, the line between them
//! the gap, the gap a figure (pool.md "How hard to pick up": new against practised
//! players)
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const objicon = @import("objicon.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const badge = @import("badge.zig");
const hint = @import("tip.zig");
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
    /// The tile's hover
    title: ?tree.Text = null,
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
    /// False: the figure keeps its ink, not the side's colour (the caller colours it)
    tint: bool = true,
    /// A second value, hollow and joined to `you`, and its typical (cell only)
    from: ?i32 = null,
    from_typ: ?i32 = null,
    /// The label as a Tip (hover, focus, tap), not a title (cell only); narrow, opening
    /// at the cell's end with `tip_end` (a grid's right-hand columns)
    tip: bool = false,
    tip_end: bool = false,
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
/// `fig`: a Text, or a node (rate.view)
pub fn cell(h: *H, b: Band, fig: anytype) N {
    const kids = .{ track(h, b), h.span(.{ .class = "fig", .data_side = bandSide(b) }, .{fig}) };
    if (b.tip) return h.span(.{ .class = "c-vs", .data_v = "cell" }, .{hint.view(h, b.label, kids, .{ .block = true, .narrow = true, .end = b.tip_end, .stop = false })});
    return h.span(.{ .class = "c-vs", .data_v = "cell", .title = b.label }, kids);
}

/// Names a two-value cell's marks: the hollow `from`, then `you`
pub fn cellKey(h: *H, from: tree.Text, you: tree.Text) N {
    return h.span(.{ .class = "c-vs", .data_v = "ckey", .aria_hidden = true }, .{ h.span(.{ .class = "fr" }, .{}), from, h.span(.{ .class = "you" }, .{}), you });
}

/// Against the typical median: better is ours
fn bandSide(b: Band) ?[]const u8 {
    if (!b.tint) return null;
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
    const you = at(b.you, d);
    return h.span(.{ .class = "tr", .aria_hidden = true }, .{
        if (b.typ) |q| h.span(.{ .class = "q", .style = h.vars(.{ .a = at(q[0], d), .b = at(q[2], d) }) }, .{}) else null,
        if (b.typ) |q| h.span(.{ .class = "typ", .style = h.vars(.{ .x = at(q[1], d) }) }, .{}) else null,
        if (b.from_typ) |q| h.span(.{ .class = "typ", .style = h.vars(.{ .x = at(q, d) }) }, .{}) else null,
        if (b.from) |f| h.span(.{ .class = "j", .style = h.vars(.{ .l = @min(at(f, d), you), .w = @abs(you - at(f, d)) }) }, .{}) else null,
        if (b.from) |f| h.span(.{ .class = "fr", .style = h.vars(.{ .x = at(f, d) }) }, .{}) else null,
        h.span(.{ .class = "you", .style = h.vars(.{ .x = you }) }, .{}),
    });
}

pub const Row = struct {
    label: tree.Text,
    a: tree.Text,
    b: tree.Text,
    /// The two rates, 0-1: none for a timing
    bars: ?[2]f32 = null,
    /// The side shown bold
    lead: ?Side = null,
    /// After a timing's two times, small: "8 s apart"
    sub: ?tree.Text = null,
    /// A share's range past fmt.wide_range: faded (J35)
    wide: bool = false,
};

pub const Side = enum { a, b };

/// A row of two shares (0-1), rounded to whole percents; the larger bold
pub fn shares(h: *H, label: tree.Text, pa: f32, pb: f32) Row {
    const ra = @round(pa * 100);
    const rb = @round(pb * 100);
    return .{
        .label = label,
        .a = phrase.num(h, .pct, @as(u32, @intFromFloat(ra))),
        .b = phrase.num(h, .pct, @as(u32, @intFromFloat(rb))),
        .bars = .{ pa, pb },
        .lead = if (ra > rb) .a else if (rb > ra) .b else null,
    };
}

/// `names`: the two sides, for screen readers (`key` shows them)
pub fn rows(h: *H, names: [2][]const u8, items: []const Row) N {
    var l = h.list();
    for (items, 0..) |r, i| l.add(h.div(.{ .key = i, .class = "mr", .data_thin = r.wide }, .{
        h.span(.{ .class = "lab" }, .{r.label}),
        if (r.bars) |b| dots(h, r, b) else h.span(.{ .class = "tm" }, .{
            h.span(.{ .class = "n us", .data_lead = r.lead == .a }, .{r.a}),
            h.span(.{ .class = "n them", .data_lead = r.lead == .b }, .{r.b}),
            if (r.sub) |x| h.small(.{}, .{x}) else null,
        }),
    }));
    return h.div(.{ .class = "c-vs", .data_v = "rows", .role = "group", .aria_label = W.rows.with(h, .{ .a = names[0], .b = names[1] }) }, .{l.done()});
}

/// The lower number sits left of its dot, the higher right of its own: each beside its
/// dot whatever the gap
fn dots(h: *H, r: Row, b: [2]f32) N {
    const x = pct(b[0]);
    const y = pct(b[1]);
    const a_lo = x <= y;
    return h.span(.{ .class = "tk", .style = h.vars(.{ .l = @min(x, y), .w = @abs(y - x) }) }, .{
        h.span(.{ .class = "ln", .aria_hidden = true }, .{}),
        h.span(.{ .class = "d us", .aria_hidden = true, .style = h.vars(.{ .x = x }) }, .{}),
        h.span(.{ .class = "d them", .aria_hidden = true, .style = h.vars(.{ .x = y }) }, .{}),
        h.span(.{ .class = "n us", .data_lead = r.lead == .a, .data_at = if (a_lo) "lo" else "hi", .style = h.vars(.{ .x = x }) }, .{r.a}),
        h.span(.{ .class = "n them", .data_lead = r.lead == .b, .data_at = if (a_lo) "hi" else "lo", .style = h.vars(.{ .x = y }) }, .{r.b}),
    });
}

/// Two sides' shares (`shares` rows) through the phases of a game, left to right in
/// time: the first side's columns rise from a centre line, the second's hang under it,
/// each to its own 0-100, its figure at the tip, the larger bold. `sides`: what stands
/// left of each half (a portrait, a role icon), named under it. `y`: what the shares
/// count ("lanes with a kill"), once, in the label row under the sides, read first
pub fn timeline(h: *H, names: [2][]const u8, sides: [2]N, y: tree.Text, items: []const Row) N {
    var l = h.list();
    l.add(h.span(.{ .key = items.len, .class = "sd" }, .{
        h.span(.{ .class = "us", .aria_hidden = true }, .{ sides[0], h.small(.{}, .{names[0]}) }),
        h.span(.{ .class = "them", .aria_hidden = true }, .{ sides[1], h.small(.{}, .{names[1]}) }),
        h.span(.{ .class = "y" }, .{y}),
    }));
    for (items, 0..) |r, i| {
        const b = r.bars orelse continue;
        l.add(h.div(.{ .key = i, .class = "tc", .data_thin = r.wide }, .{
            h.span(.{ .class = "lab" }, .{r.label}),
            h.span(.{ .class = "up" }, .{h.span(.{ .class = "t" }, .{h.span(.{ .class = "b", .style = h.vars(.{ .x = pct(b[0]) }) }, .{
                h.span(.{ .class = "n", .data_lead = r.lead == .a }, .{ h.span(.{ .class = "sr" }, .{ names[0], " " }), r.a }),
            })})}),
            h.span(.{ .class = "dn" }, .{h.span(.{ .class = "t" }, .{h.span(.{ .class = "b", .style = h.vars(.{ .x = pct(b[1]) }) }, .{
                h.span(.{ .class = "n", .data_lead = r.lead == .b }, .{ h.span(.{ .class = "sr" }, .{ names[1], " " }), r.b }),
            })})}),
        }));
    }
    return h.div(.{ .class = "c-vs", .data_v = "time", .data_grow = {}, .role = "group", .aria_label = W.rows.with(h, .{ .a = names[0], .b = names[1] }) }, .{l.done()});
}

/// The two sides' names in their colours, for a card head over `rows`
pub fn key(h: *H, names: [2][]const u8) N {
    return h.span(.{ .class = "c-vs", .data_v = "key", .aria_hidden = true }, .{ h.span(.{ .class = "us" }, .{names[0]}), h.span(.{ .class = "them" }, .{names[1]}) });
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
    std.debug.assert(o.hi > o.lo);
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

pub const SplitOpts = struct {
    /// Figures in the side colours; false: plain ink, where side colours would read as
    /// good and bad (rates beside win rates), the bar keeping the sides
    sides: bool = true,
};

pub fn split(h: *H, o: SplitOpts, items: []const Item) N {
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
        l.add(h.div(.{ .key = i, .class = "it", .title = it.title }, .{
            h.span(.{ .class = "lab" }, .{ if (it.icon) |k| objicon.view(h, k, .{ .s = .s, .named = false }) else null, it.label }),
            h.span(.{ .class = "n us" }, .{ it.us, mark(h, it, true) }),
            h.span(.{ .class = "n them" }, .{ mark(h, it, false), it.them }),
            h.span(.{ .class = "bar", .aria_hidden = true, .style = if (it.share) |s| h.vars(.{ .s = @round(s * 1000) / 10 }) else null, .data_none = it.share == null }, .{}),
        }));
    }
    return h.div(.{ .class = "c-vs", .role = "group", .aria_label = W.label, .data_ink = !o.sides }, .{l.done()});
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
    \\  .c-vs[data-ink] .n { color: var(--text); }
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
    \\  .c-vs .tr > .typ { z-index: 1; top: -5px; bottom: -5px; box-shadow: 0 0 0 1px var(--panel); border-radius: 1px; }
    \\  .c-vs .tr > .you { position: absolute; top: -4px; bottom: -4px; left: calc(var(--x) * 1%); width: 8px; margin-left: -4px; border-radius: 3px; background: var(--us); box-shadow: 0 0 0 2px var(--panel); }
    \\  .c-vs[data-v="rows"] { grid-template-columns: minmax(0, 1fr); gap: 0; }
    \\  .c-vs[data-v="key"] { display: inline-flex; gap: var(--sp-3); font-size: var(--fs-s); font-weight: var(--w-b); }
    \\  .c-vs[data-v="key"] > span::before { content: ""; display: inline-block; width: 9px; height: 9px; margin-right: 6px; border-radius: 50%; background: currentColor; }
    \\  .c-vs[data-v="key"] > .us, .c-vs .mr .us { color: var(--us-hot); }
    \\  .c-vs[data-v="key"] > .them, .c-vs .mr .them { color: var(--them-hot); }
    \\  .c-vs > .mr { display: grid; grid-template-columns: minmax(0, 8em) minmax(0, 1fr); align-items: center; gap: var(--sp-3); min-height: 30px; }
    \\  .c-vs > .mr + .mr { border-top: 1px solid var(--line); }
    \\  .c-vs .mr > .lab { grid-column: 1; justify-self: start; display: block; color: var(--t2); font-size: var(--fs-s); }
    \\  .c-vs .mr .n { font-size: var(--fs-m); font-weight: var(--w-m); font-variant-numeric: tabular-nums; white-space: nowrap; opacity: 0.8; }
    \\  .c-vs .mr .n[data-lead] { font-weight: var(--w-b); opacity: 1; }
    \\  .c-vs .mr > .tk { position: relative; height: 26px; margin: 0 3.4em; }
    \\  .c-vs .tk::before { content: ""; position: absolute; left: 0; right: 0; top: 50%; height: 2px; margin-top: -1px; border-radius: 1px; background: var(--line-2); }
    \\  .c-vs .tk::after { content: ""; position: absolute; left: 50%; top: 5px; bottom: 5px; width: 1px; background: var(--muted); opacity: 0.5; }
    \\  .c-vs .tk > .ln { position: absolute; top: 50%; height: 4px; margin-top: -2px; left: calc(var(--l) * 1%); width: calc(var(--w) * 1%); border-radius: 2px; background: var(--muted); }
    \\  .c-vs .tk > .d { position: absolute; z-index: 1; top: 50%; left: calc(var(--x) * 1%); width: 10px; height: 10px; margin: -5px 0 0 -5px; border-radius: 50%; box-shadow: 0 0 0 2px var(--panel); }
    \\  .c-vs .tk > .d.us { background: var(--us-hot); }
    \\  .c-vs .tk > .d.them { background: var(--them-hot); }
    \\  .c-vs .tk > .n { position: absolute; z-index: 1; top: 50%; width: max-content; padding: 0 2px; transform: translateY(-50%); background: var(--panel); }
    \\  .c-vs .tk > .n[data-at="lo"] { right: calc(100% - var(--x) * 1% + 10px); }
    \\  .c-vs .tk > .n[data-at="hi"] { left: calc(var(--x) * 1% + 10px); }
    \\  .c-vs .mr > .tm { display: flex; align-items: baseline; gap: var(--sp-3); }
    \\  .c-vs .tm > small { color: var(--faint); font-size: var(--fs-xs); }
    \\  @media (max-width: 760px) {
    \\    .c-vs > .mr { grid-template-columns: minmax(0, 6.5em) minmax(0, 1fr); gap: var(--sp-2); }
    \\    .c-vs .mr > .tk { margin: 0 2.8em; }
    \\  }
    \\  .c-vs[data-v="cell"] { display: flex; flex-direction: column; gap: 3px; width: 96px; }
    \\  .c-vs[data-v="cell"] > .tr { display: block; height: 8px; margin-top: 3px; }
    \\  .c-vs[data-v="cell"] .tr > .you { top: -3px; bottom: -3px; width: 6px; margin-left: -3px; }
    \\  .c-vs[data-v="cell"] > .fig { font-size: var(--fs-xs); white-space: nowrap; }
    \\  .c-vs[data-v="ckey"] { display: flex; flex-wrap: wrap; align-items: center; gap: 2px 4px; font-size: var(--fs-xs); color: var(--muted); }
    \\  .c-vs[data-v="ckey"] > .fr { width: 9px; height: 9px; box-sizing: border-box; border: 2px solid var(--t2); border-radius: 50%; }
    \\  .c-vs[data-v="ckey"] > .you { width: 6px; height: 12px; margin-left: 4px; border-radius: 3px; background: var(--us); }
    \\  .c-vs[data-v="cell"] > .c-hint { display: flex; flex-direction: column; gap: 3px; }
    \\  .c-vs .tr > .j { position: absolute; top: 50%; height: 2px; margin-top: -1px; left: calc(var(--l) * 1%); width: calc(var(--w) * 1%); background: var(--t2); }
    \\  .c-vs .tr > .fr { position: absolute; top: 50%; left: calc(var(--x) * 1%); width: 9px; height: 9px; margin: -4.5px 0 0 -4.5px;
    \\    box-sizing: border-box; border: 2px solid var(--t2); border-radius: 50%; background: var(--panel); }
    \\  .c-vs[data-v="bell"] { grid-template-columns: minmax(0, 1fr); gap: 0; }
    \\  .c-vs > .bl { display: grid; grid-template-columns: minmax(0, 10em) minmax(0, 1fr) 3.4em; align-items: center; gap: var(--sp-2); min-height: 32px; }
    \\  .c-vs > .bl[data-thin], .c-vs > .mr[data-thin] > :not(.lab) { opacity: 0.55; }
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
    \\  .c-vs[data-v="time"] { grid-template-columns: auto; grid-auto-columns: minmax(0, 1fr); grid-auto-flow: column;
    \\    grid-template-rows: minmax(64px, 1fr) minmax(64px, 1fr) auto; gap: 0 var(--sp-2); min-height: 200px; }
    \\  .c-vs > .sd, .c-vs > .tc { grid-row: 1 / -1; display: grid; grid-template-rows: subgrid; }
    \\  .c-vs .sd > span { display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 2px; padding-right: var(--sp-2); }
    \\  .c-vs .sd small { font-size: var(--fs-xs); font-weight: var(--w-b); }
    \\  .c-vs .sd > .us small { color: var(--us-hot); }
    \\  .c-vs .sd > .them small { color: var(--them-hot); }
    \\  .c-vs .sd > .y { justify-content: flex-start; contain: inline-size; padding-top: var(--sp-1); text-align: center;
    \\    font-size: var(--fs-xs); color: var(--faint); }
    \\  .c-vs .tc > .lab { grid-row: 3; padding-top: var(--sp-1); text-align: center; font-size: var(--fs-xs); color: var(--t2); }
    \\  .c-vs .tc > :is(.up, .dn) { display: flex; justify-content: center; }
    \\  .c-vs .tc > .up { grid-row: 1; align-items: flex-end; padding-top: 1.6em; border-bottom: 1px solid var(--line-2); }
    \\  .c-vs .tc > .dn { grid-row: 2; align-items: flex-start; padding-bottom: 1.6em; }
    \\  .c-vs .tc .t { display: flex; flex-direction: column; justify-content: flex-end; width: min(48px, 60%); height: 100%; background: var(--bar-track); }
    \\  .c-vs .tc > .up .t { border-radius: 4px 4px 0 0; }
    \\  .c-vs .tc > .dn .t { justify-content: flex-start; border-radius: 0 0 4px 4px; }
    \\  .c-vs .tc .b { position: relative; height: calc(var(--x) * 1%); background: var(--c); border-radius: inherit; }
    \\  .c-vs .tc > .up .b { --c: var(--us-hot); }
    \\  .c-vs .tc > .dn .b { --c: var(--them-hot); }
    \\  .c-vs .tc .n { position: absolute; left: 50%; transform: translateX(-50%); font-size: var(--fs-m); font-variant-numeric: tabular-nums;
    \\    white-space: nowrap; opacity: 0.8; }
    \\  .c-vs .tc > .up .n { bottom: 100%; padding-bottom: 2px; }
    \\  .c-vs .tc > .dn .n { top: 100%; padding-top: 2px; }
    \\  .c-vs .tc .n[data-lead] { font-weight: var(--w-b); opacity: 1; }
    \\  .c-vs .tc[data-thin] { opacity: var(--fade); }
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
    g.addFill("objectives and firsts", split(h, .{}, &demo));
    g.add("two", split(h, .{}, demo[0..2]));
    g.add("plain ink: rates, not sides", split(h, .{ .sides = false }, demo[0..2]));
    const a = champ.demo("Katarina", "Katarina");
    const b = champ.demo("Annie", "Annie");
    g.add("races: level 6 later than typical, first item earlier", h.div(.{ .class = "c-vs" }, .{
        race(h, .{ .label = plain("Level 6"), .you = 391, .them = 315, .typ = 339, .a = a, .b = b }),
        race(h, .{ .label = plain("First item"), .you = 650, .them = 714, .typ = 681, .a = a, .b = b }),
        race(h, .{ .label = plain("First item"), .you = null, .them = 714, .a = a, .b = b }),
    }));
    g.add("key: the sides' names", key(h, .{ "Darius", "Garen" }));
    g.addFill("rows: a matchup's head to head", rows(h, .{ "Darius", "Garen" }, &.{
        .{ .label = plain("Wins"), .a = plain("50%"), .b = plain("50%"), .bars = .{ 0.5, 0.5 } },
        .{ .label = plain("Ahead at 14"), .a = plain("61%"), .b = plain("39%"), .bars = .{ 0.61, 0.39 }, .lead = .a },
        .{ .label = plain("First blood"), .a = plain("15%"), .b = plain("17%"), .bars = .{ 0.15, 0.17 }, .lead = .b },
        .{ .label = plain("Kills after 14"), .a = plain("98%"), .b = plain("3%"), .bars = .{ 0.98, 0.03 }, .lead = .a },
        .{ .label = plain("Level 6"), .a = plain("5:19"), .b = plain("5:28"), .lead = .a, .sub = plain("9 s apart") },
        .{ .label = plain("First item"), .a = plain("12:04"), .b = plain("–") },
    }));
    g.addFill("timeline: lane kills by phase, Ornn above, the opponent under", timeline(h, .{ "Ornn", "Opponent" }, .{ champ.view(h, champ.demo("Ornn", "Ornn"), .{ .px = .@"32", .named = false }), role.view(h, .top, .{ .s = .l, .named = false }) }, plain("lanes with a kill"), &.{
        shares(h, plain("by 6 min"), 0.49, 0.46),
        shares(h, plain("6-14 min"), 0.71, 0.74),
        shares(h, plain("14+ min"), 0.87, 0.82),
    }));
    g.addFill("timeline: first blood ahead; one side at 0", timeline(h, .{ "Ornn", "Opponent" }, .{ champ.view(h, champ.demo("Ornn", "Ornn"), .{ .px = .@"32", .named = false }), role.view(h, .top, .{ .s = .l, .named = false }) }, plain("lanes with a kill"), &.{
        shares(h, plain("First blood"), 0.10, 0.12),
        shares(h, plain("by 6 min"), 0.49, 0.46),
        shares(h, plain("6-14 min"), 0.71, 0.74),
        shares(h, plain("14+ min"), 0.03, 0),
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
        cellKey(h, plain("didn't take it first"), plain("took it first")),
        cell(h, .{ .label = plain("First tower: won 73.3% after taking it, 37.0% otherwise"), .you = 233, .from = -130, .typ = .{ 201, 201, 201 }, .from_typ = -105, .dom = 500, .tint = false, .tip = true }, plain("73.3%")),
    }));
}

fn bellHead(h: *H, comptime nm: []const u8) N {
    return h.a(.{ .href = "#" }, .{ champ.view(h, champ.demo(nm, nm), .{ .named = false }), nm });
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
    try std.testing.expect(std.mem.find(u8, s, "--a:25;--b:75;--l:25;--w:50") != null);
    // Practised below new: the line still runs left to right
    try std.testing.expect(std.mem.find(u8, s, "--a:60;--b:50;--l:50;--w:10") != null);
    try std.testing.expect(std.mem.find(u8, s, "aria-label=\"New 45.0%, Practised 55.0%\"") != null);
    try std.testing.expectEqual(1, std.mem.count(u8, s, "data-thin"));
    try std.testing.expect(std.mem.find(u8, s, ">50%</span>") != null);
}
