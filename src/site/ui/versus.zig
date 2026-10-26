//! Versus: your team against theirs, one figure at a time. `split`: per item the two
//! counts and a bar split by share, yours left in --us and theirs right in --them; the
//! side that got it first carries a "1st" mark with its time on hover and for screen
//! readers (game-detail.md "Objectives and firsts")
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const objicon = @import("objicon.zig");
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
};

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
}
