//! GameStrip: your games as one scrolling row of small cards (champion, duration, a
//! bottom edge in --us for a win and --them for a loss), the open one raised; "All
//! games" first. Each card is a button the page binds to its game
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const champ = @import("champ.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "GameStrip";
pub const scope = .{".c-gstrip"};

pub const Item = struct {
    champ: champ.Champ,
    win: bool,
    /// Seconds
    dur: u16,
    /// "23 Oct"
    day: []const u8,
    selected: bool = false,
    on: ?tree.Handler = null,
};

pub const Opts = struct {
    /// "All games": the games list
    all: ?[]const u8 = null,
};

const W = struct {
    pub const label = plain("Your games");
    pub const all = plain("All games");
    pub const won = plain("win");
    pub const lost = plain("loss");
    pub const card = phrase.Phrase("{c:text}, {r:text}, {d:time}, {day:text}");
};

pub fn view(h: *H, items: []const Item, o: Opts) N {
    var l = h.list();
    for (items, 0..) |it, i| l.add(h.button(.{
        .key = i,
        .type = "button",
        .data_win = it.win,
        .data_ref = if (it.selected) "gs-cur" else null,
        .aria_pressed = it.selected,
        .aria_label = W.card.with(h, .{ .c = it.champ.name, .r = if (it.win) W.won.s else W.lost.s, .d = it.dur, .day = it.day }),
        .on_click = it.on,
    }, .{
        champ.view(h, it.champ, .{ .px = .@"32", .named = false }),
        h.span(.{ .class = "d", .aria_hidden = true }, .{phrase.num(h, .time, it.dur)}),
    }));
    return h.el(.nav, .{ .class = "c-gstrip", .aria_label = W.label }, .{
        if (o.all) |href| h.a(.{ .class = "all", .href = href }, .{ h.span(.{ .aria_hidden = true }, .{"‹"}), W.all }) else null,
        h.div(.{ .class = "row" }, .{l.done()}),
    });
}

pub const css =
    \\@layer components {
    \\  .c-gstrip { display: flex; align-items: center; gap: var(--sp-3); min-width: 0; }
    \\  .c-gstrip > .all { display: inline-flex; align-items: center; gap: 4px; flex: none; font-size: var(--fs-s);
    \\    font-weight: var(--w-m); color: var(--t2); white-space: nowrap; }
    \\  .c-gstrip > .all:hover { color: var(--text); text-decoration: none; }
    \\  .c-gstrip > .row { display: flex; gap: 6px; min-width: 0; overflow-x: auto; scrollbar-width: none;
    \\    padding: 4px 2px; scroll-padding: 0 var(--sp-5); }
    \\  .c-gstrip button { all: unset; position: relative; display: flex; flex-direction: column; align-items: center;
    \\    gap: 2px; flex: none; padding: 4px 5px 6px; border-radius: var(--r-s); background: var(--panel-2);
    \\    box-shadow: inset 0 0 0 1px var(--line); cursor: pointer; box-sizing: border-box;
    \\    transition: background var(--dur) var(--ease), transform var(--dur) var(--ease); }
    \\  .c-gstrip button::after { content: ""; position: absolute; left: 4px; right: 4px; bottom: 0; height: 3px;
    \\    border-radius: 2px 2px 0 0; background: var(--them); }
    \\  .c-gstrip button[data-win]::after { background: var(--us); }
    \\  .c-gstrip button:hover { background: var(--panel-3); }
    \\  .c-gstrip button[aria-pressed="true"] { background: var(--sel-bg); transform: translateY(-2px);
    \\    box-shadow: inset 0 0 0 1px var(--sel-line), var(--shadow-ctl); }
    \\  .c-gstrip button:focus-visible { outline: 2px solid var(--focus); outline-offset: 1px; }
    \\  .c-gstrip .d { font-size: var(--fs-xs); color: var(--t2); font-variant-numeric: tabular-nums; line-height: 1.1; }
    \\}
    \\
;

const demo = blk: {
    const keys = [_][3][]const u8{
        .{ "AurelionSol", "Aurelion Sol", "23 Oct" },
        .{ "Yone", "Yone", "23 Oct" },
        .{ "AurelionSol", "Aurelion Sol", "22 Oct" },
        .{ "Katarina", "Katarina", "22 Oct" },
        .{ "Ahri", "Ahri", "21 Oct" },
        .{ "Katarina", "Katarina", "20 Oct" },
        .{ "Malzahar", "Malzahar", "20 Oct" },
        .{ "Annie", "Annie", "19 Oct" },
    };
    const durs = [_]u16{ 2498, 1057, 2211, 2109, 1388, 1773, 2603, 951 };
    var out: [keys.len]Item = undefined;
    for (keys, durs, 0..) |k, d, i| out[i] = .{ .champ = champ.demo(k[0], k[1]), .win = i % 3 != 1, .dur = d, .day = k[2], .selected = i == 0 };
    break :blk out;
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.addFill("the open game first", view(h, &demo, .{ .all = "#games" }));
    g.addFill("no list link", view(h, demo[2..5], .{}));
}
