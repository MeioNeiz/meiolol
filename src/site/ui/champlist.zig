//! ChampList: a short list of champions, one line each: portrait, name (a badge after
//! it), the figure the list is ordered by, a faint note last (share, games). A row can
//! link to the champion's page. Two columns in a wide card (`cols`). A pair (`vs`): a
//! duel, the portraits at both ends, the names over the lane's bar (the first's win rate
//! a tick against the middle's, the bar solid to its 95% range's low end and fading to
//! the high one, a ring where a patch move started), the figure and its note last
const tree = @import("tree.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const badge = @import("badge.zig");
const fmt = @import("fmt.zig");
const delta = @import("delta.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = @import("phrase.zig").plain;
const H = tree.H;
const N = tree.N;

pub const name = "ChampList";
pub const scope = .{".c-clist"};

/// A matchup's lane from the first champion's side, in % (ci: the 95% half width)
pub const Lane = struct { win: f32, ci: f32 = 0, was: ?f32 = null };

pub const Row = struct {
    champ: champ.Champ,
    /// The opponent: a matchup row
    vs: ?champ.Champ = null,
    /// A matchup row's bar
    lane: ?Lane = null,
    href: ?[]const u8 = null,
    role: ?role.Role = null,
    /// After the name: a Badge
    tag: ?N = null,
    /// The figure the list is ordered by
    value: ?N = null,
    /// Faint, last
    note: ?tree.Text = null,
};

pub const Opts = struct {
    /// Two columns where they fit
    cols: bool = false,
    label: ?tree.Text = null,
};

const W = struct {
    pub const vs = plain("vs ");
};

pub fn view(h: *H, o: Opts, rows: []const Row) N {
    var l = h.list();
    for (rows, 0..) |r, i| {
        const kids = if (r.vs) |y| duel(h, r, y) else nodes(h, .{
            champ.view(h, r.champ, .{ .named = false }),
            h.span(.{ .class = "nm" }, .{ r.champ.name, r.tag }),
            if (r.role) |x| role.view(h, x, .{ .s = .s }) else null,
            if (r.value) |v| h.span(.{ .class = "v" }, .{v}) else null,
            if (r.note) |n| h.span(.{ .class = "g" }, .{n}) else null,
        });
        const duo = r.vs != null;
        l.add(h.li(.{ .key = i }, .{if (r.href) |href| h.a(.{ .href = href, .class = if (duo) "duel" else null }, .{kids}) else h.div(.{ .class = if (duo) "duel" else null }, .{kids})}));
    }
    return h.ul(.{ .class = "c-clist", .data_v = if (o.cols) "2" else null, .aria_label = o.label }, .{l.done()});
}

fn nodes(h: *H, kids: anytype) []const N {
    var l = h.list();
    inline for (kids) |k| l.add(if (@typeInfo(@TypeOf(k)) == .optional) k orelse .none else k);
    return l.done();
}

fn duel(h: *H, r: Row, y: champ.Champ) []const N {
    const mid = if (r.role) |x| role.view(h, x, .{ .s = .s }) else h.span(.{ .class = "vs" }, .{W.vs});
    return nodes(h, .{
        champ.view(h, r.champ, .{ .named = false, .px = .@"32" }),
        h.span(.{ .class = "mid" }, .{
            h.span(.{ .class = "nm" }, .{ h.span(.{}, .{ r.champ.name, r.tag }), mid, h.span(.{}, .{y.name}) }),
            if (r.lane) |x| lane(h, x) else null,
        }),
        champ.view(h, y, .{ .named = false, .px = .@"32" }),
        h.span(.{ .class = "fig" }, .{
            if (r.value) |v| h.span(.{ .class = "v" }, .{v}) else null,
            if (r.note) |n| h.span(.{ .class = "g" }, .{n}) else null,
        }),
    });
}

/// 30-70% across the bar: lanes rarely leave it, and 50 stays the middle
fn at(win: f32) f32 {
    return @max(0, @min(100, (win - 30) * 2.5));
}

fn lane(h: *H, x: Lane) N {
    const lo = at(x.win - x.ci);
    const hi = at(x.win + x.ci);
    return h.span(.{ .class = "lane", .aria_hidden = true, .style = h.vars(.{ .c = fmt.Step.of(x.win - 50, fmt.win_cuts), .w = at(x.win), .hi = hi, .k = if (hi > 0) 100 * lo / hi else 0 }) }, .{
        h.el(.i, .{ .class = "f" }, .{}),
        if (x.was) |w| h.el(.i, .{ .class = "was", .style = h.vars(.{ .x = at(w) }) }, .{}) else null,
        h.el(.i, .{ .class = "t" }, .{}),
    });
}

pub const css =
    \\@layer components {
    \\  .c-clist { list-style: none; margin: 0; padding: 0; }
    \\  .c-clist li > * { display: flex; align-items: center; gap: var(--sp-2); height: var(--row); color: inherit; }
    \\  .c-clist li > a:hover { text-decoration: none; }
    \\  .c-clist li > a:hover .nm { color: var(--accent); }
    \\  .c-clist .nm { display: flex; align-items: center; gap: var(--sp-2); flex: 1; min-width: 0; overflow: hidden;
    \\    white-space: nowrap; }
    \\  .c-clist .v { font-weight: var(--w-b); font-variant-numeric: tabular-nums; white-space: nowrap; color: var(--c, inherit); }
    \\  .c-clist .v > [style] { color: var(--c); }
    \\  .c-clist .g { min-width: 36px; text-align: right; font-size: var(--fs-xs); color: var(--faint);
    \\    font-variant-numeric: tabular-nums; }
    \\  .c-clist[data-v="2"] { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); column-gap: var(--sp-5); }
    \\  .c-clist[data-v="2"]:has(.duel) { grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); }
    \\  .c-clist[data-v="2"] li > * { height: 36px; border-bottom: 1px solid var(--line); }
    \\  .c-clist li > .duel { display: grid; grid-template-columns: auto minmax(0, 1fr) auto auto; column-gap: var(--sp-3);
    \\    height: 52px; }
    \\  .c-clist .duel > .mid { display: grid; gap: 6px; min-width: 0; }
    \\  .c-clist .duel .nm { display: grid; grid-template-columns: minmax(0, 1fr) auto minmax(0, 1fr); align-items: center;
    \\    font-size: var(--fs-s); }
    \\  .c-clist .duel .nm > span { overflow: hidden; text-overflow: ellipsis; }
    \\  .c-clist .duel .nm > :last-child { text-align: right; }
    \\  .c-clist .duel .nm > .vs { color: var(--faint); font-size: var(--fs-xs); }
    \\  .c-clist .duel > .fig { display: grid; justify-items: end; width: 84px; }
    \\  .c-clist .lane { position: relative; height: 6px; border-radius: 3px; background: var(--bar-track); }
    \\  .c-clist .lane::after { content: ""; position: absolute; left: 50%; top: -3px; bottom: -3px; width: 1px;
    \\    background: var(--faint); }
    \\  .c-clist .lane > i { position: absolute; }
    \\  .c-clist .lane > .f { inset: 0 auto 0 0; width: calc(var(--hi) * 1%); border-radius: 3px;
    \\    background: linear-gradient(90deg, var(--c) calc(var(--k) * 1%), transparent); }
    \\  .c-clist .lane > .t { left: calc(var(--w) * 1% - 1px); top: -2px; bottom: -2px; width: 2px; border-radius: 1px;
    \\    background: var(--text); z-index: 1; }
    \\  .c-clist .lane > .was { left: calc(var(--x) * 1% - 4px); top: -1px; width: 8px; height: 8px; box-sizing: border-box;
    \\    border-radius: 50%; border: 2px solid var(--t2); background: var(--bg); }
    \\}
    \\
;

const G = struct {
    pub const harder = plain("harder to pick up");
    pub const also = plain("Darius mains also play");
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const also = [_]struct { champ.Champ, tree.Text, tree.Text, bool }{
        .{ champ.demo("Sett", "Sett"), plain("×3.5"), plain("44%"), false },
        .{ champ.demo("Olaf", "Olaf"), plain("×3.4"), plain("22%"), false },
        .{ champ.demo("Mordekaiser", "Mordekaiser"), plain("×3.0"), plain("45%"), false },
        .{ champ.demo("Garen", "Garen"), plain("×2.9"), plain("49%"), true },
        .{ champ.demo("Aatrox", "Aatrox"), plain("×2.9"), plain("30%"), false },
    };
    var rows: [also.len]Row = undefined;
    for (also, 0..) |x, i| rows[i] = .{
        .champ = x[0],
        .href = "#",
        .tag = if (x[3]) badge.view(h, .neutral, .{G.harder}) else null,
        .value = h.span(.{}, .{x[1]}),
        .note = x[2],
    };
    g.addFill("mains also play: links, a badge", view(h, .{ .label = G.also }, &rows));
    g.addFill("two columns", view(h, .{ .cols = true, .label = G.also }, &rows));
    g.addFill("matchups: duels, the lane's bar and range; a role; where a move started", view(h, .{}, &.{
        .{ .champ = champ.demo("Darius", "Darius"), .vs = champ.demo("Garen", "Garen"), .href = "#", .lane = .{ .win = 51.2, .ci = 2.3 }, .value = h.span(.{ .style = h.vars(.{ .c = fmt.Step.of(1.2, fmt.win_cuts) }) }, .{plain("51.2%")}), .note = plain("1,788") },
        .{ .champ = champ.demo("Tryndamere", "Tryndamere"), .vs = champ.demo("Malphite", "Malphite"), .href = "#", .lane = .{ .win = 41.6, .ci = 2.8 }, .value = h.span(.{ .style = h.vars(.{ .c = fmt.Step.of(-8.4, fmt.win_cuts) }) }, .{plain("41.6%")}), .note = plain("1,204") },
        .{ .champ = champ.demo("Jax", "Jax"), .vs = champ.demo("Aatrox", "Aatrox"), .role = .top, .href = "#", .lane = .{ .win = 53.9, .ci = 3.2, .was = 50.8 }, .value = delta.view(h, .{ .d = 3.1 }), .note = plain("905") },
        .{ .champ = champ.demo("Ornn", "Ornn"), .vs = champ.demo("Gragas", "Gragas"), .role = .top, .href = "#", .lane = .{ .win = 61.8, .ci = 7.3, .was = 44 }, .value = delta.view(h, .{ .d = 17.8, .faint = true }), .note = plain("170") },
    }));
    g.addFill("with roles, no links", view(h, .{}, &.{
        .{ .champ = champ.demo("Ahri", "Ahri"), .role = .mid, .value = h.span(.{}, .{plain("+2.4")}), .note = plain("12,040") },
        .{ .champ = champ.demo("Jinx", "Jinx"), .role = .bot, .value = h.span(.{}, .{plain("−1.8")}), .note = plain("9,311") },
    }));
}
