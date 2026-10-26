//! Versus: your team against theirs, one figure at a time. `split`: per item the two
//! counts and a bar split by share, yours left in --us and theirs right in --them; the
//! side that got it first carries a "1st" mark with its time on hover and for screen
//! readers (game-detail.md "Objectives and firsts"). `race`: when you and your opponent
//! got somewhere, the typical time a tick, the gap to typical a signed figure (later is
//! worse). `band`: one figure on a track, the typical middle half shaded and its median
//! a tick (game-detail.md "Lane")
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const objicon = @import("objicon.zig");
const champ = @import("champ.zig");
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
    pub const first = plain("1st");
    pub const first_at = phrase.Phrase("First at {t:time}");
    pub const times = phrase.Phrase("{a:text} {x:text} · {b:text} {y:text}");
    pub const typ_at = phrase.Phrase(" · typical {t:time}");
    pub const you = plain("You");
    pub const gap = phrase.Phrase("{v:signed}s");
    pub const typ = phrase.Phrase("typ {v:signed}");
    pub const never = plain("–");
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
    const d: f32 = @floatFromInt(@max(b.dom, 1));
    const at = struct {
        fn f(v: i32, dd: f32) f32 {
            return @round(std.math.clamp((@as(f32, @floatFromInt(v)) + dd) / (2 * dd), 0, 1) * 1000) / 10;
        }
    }.f;
    const md: ?i32 = if (b.typ) |q| q[1] else null;
    return h.div(.{ .class = "bnd" }, .{
        h.span(.{ .class = "lab" }, .{b.label}),
        h.b(.{ .class = "fig", .data_side = if (md) |m| side(b.you > m, b.you < m) else null }, .{phrase.num(h, .signed, b.you)}),
        h.div(.{ .class = "tr", .aria_hidden = true }, .{
            if (b.typ) |q| h.span(.{ .class = "q", .style = h.vars(.{ .a = at(q[0], d), .b = at(q[2], d) }) }, .{}) else null,
            if (md) |m| h.span(.{ .class = "typ", .style = h.vars(.{ .x = at(m, d) }) }, .{}) else null,
            h.span(.{ .class = "you", .style = h.vars(.{ .x = at(b.you, d) }) }, .{}),
        }),
        h.span(.{ .class = "ends", .aria_hidden = true }, .{
            h.span(.{}, .{phrase.num(h, .signed, -b.dom)}),
            if (md) |m| h.span(.{}, .{W.typ.with(h, .{ .v = m })}) else null,
            h.span(.{}, .{phrase.num(h, .signed, b.dom)}),
        }),
    });
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
    g.add("bands: below typical, above, no typical", h.div(.{ .class = "c-vs" }, .{
        band(h, .{ .label = plain("Gold lead at 14"), .you = -768, .typ = .{ -1677, -63, 511 }, .dom = 2500 }),
        band(h, .{ .label = plain("CS lead at 10"), .you = 12, .typ = .{ -9, -1, 6 }, .dom = 30 }),
        band(h, .{ .label = plain("CS lead at 10"), .you = -4, .dom = 30 }),
    }));
}
