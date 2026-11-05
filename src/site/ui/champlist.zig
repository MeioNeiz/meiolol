//! ChampList: a short list of champions, one line each: portrait, name (a badge after
//! it), the figure the list is ordered by, a faint note last (share, games). A row can
//! link to the champion's page. Two columns in a wide card (`cols`). A pair (`vs`): a
//! duel, the portraits at both ends, the names over the lane's bar (the first's win rate
//! a tick against the middle's, the bar solid to its 95% range's low end and fading to
//! the high one, a ring where a patch move started) or a Bar of a figure that isn't a
//! win rate (`fill`), the figure and its note last.
//! `tiles`: one tile per champion filling the card's width, the portrait large, the
//! figure under the name, the note small under it; a link, or a pick (the name a button)
const tree = @import("tree.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const badge = @import("badge.zig");
const fmt = @import("fmt.zig");
const delta = @import("delta.zig");
const bar = @import("bar.zig");
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
    /// 0-1: a duel's figure as a Bar, for a figure that isn't a win rate (in place of
    /// the lane's)
    fill: ?f32 = null,
    /// Tiles: the whole tile for screen readers, what its figures and tag mean
    label: ?tree.Text = null,
    /// Tiles: a tap picks it (MatchupGrid: the brief), in place of a link
    on: ?tree.Handler = null,
    pressed: bool = false,
};

pub const Opts = struct {
    /// Two columns where they fit
    cols: bool = false,
    tiles: bool = false,
    label: ?tree.Text = null,
};

const W = struct {
    pub const vs = plain("vs ");
};

pub fn view(h: *H, o: Opts, rows: []const Row) N {
    if (o.tiles) return tiles(h, o, rows);
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

fn tiles(h: *H, o: Opts, rows: []const Row) N {
    var l = h.list();
    for (rows, 0..) |r, i| {
        const kids = nodes(h, .{
            h.span(.{ .class = "pic" }, .{
                champ.view(h, r.champ, .{ .named = false, .px = .@"56" }),
                if (r.tag) |t| h.span(.{ .class = "tag" }, .{t}) else null,
            }),
            // A pick: the name is the button, stretched over the tile, so its shown label
            // stays the name (check) and a tap anywhere picks
            if (r.on) |on| h.button(.{ .class = "nm", .type = "button", .aria_pressed = r.pressed, .aria_label = if (r.label) |x| x.s else null, .on_click = on }, .{r.champ.name}) else h.span(.{ .class = "nm" }, .{r.champ.name}),
            if (r.value) |v| h.span(.{ .class = "v" }, .{v}) else null,
            if (r.note) |n| h.span(.{ .class = "g" }, .{n}) else null,
        });
        const lab: ?[]const u8 = if (r.label) |x| x.s else null;
        l.add(h.li(.{ .key = i }, .{if (r.href) |href|
            h.a(.{ .href = href, .aria_label = lab }, .{kids})
        else if (r.on != null)
            h.div(.{}, .{kids})
        else
            h.div(.{ .role = if (lab != null) "group" else null, .aria_label = lab }, .{kids})}));
    }
    // One row where all fit, else two (3x2 for 6)
    const n = rows.len;
    const cols = h.vars(.{ .n = n, .m = if (n <= 3) n else (n + 1) / 2 });
    return h.div(.{ .class = "c-clist", .data_v = "tiles", .data_grow = {} }, .{h.ul(.{ .style = cols, .aria_label = o.label }, .{l.done()})});
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
            if (r.lane) |x| lane(h, x) else if (r.fill) |f| bar.wide(h, f, 1) else null,
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
    \\  .c-clist[data-v="tiles"] { container-type: inline-size; }
    \\  .c-clist[data-v="tiles"] > ul { list-style: none; margin: 0; padding: 0; display: grid; height: 100%;
    \\    grid-template-columns: repeat(var(--m), minmax(0, 1fr)); grid-auto-rows: 1fr; gap: var(--sp-2); }
    \\  @container (min-width: 560px) { .c-clist[data-v="tiles"] > ul { grid-template-columns: repeat(var(--n), minmax(0, 1fr)); } }
    \\  .c-clist[data-v="tiles"] li > * { display: grid; justify-items: center; align-content: center; gap: 2px; height: 100%;
    \\    padding: var(--sp-3) var(--sp-2); border-radius: var(--r-m); background: var(--panel-2); }
    \\  .c-clist[data-v="tiles"] li > :is(a, :has(> button)):hover { background: var(--panel-3); }
    \\  .c-clist[data-v="tiles"] li > :has(> button) { position: relative; }
    \\  .c-clist[data-v="tiles"] button.nm { padding: 0; border: 0; background: none; font: inherit; color: inherit; cursor: pointer;
    \\    outline: none; }
    \\  .c-clist[data-v="tiles"] button.nm::after { content: ""; position: absolute; inset: 0; border-radius: inherit; }
    \\  .c-clist[data-v="tiles"] li > :has(> [aria-pressed="true"]) { box-shadow: inset 0 0 0 2px var(--accent); }
    \\  .c-clist[data-v="tiles"] li > :has(> button:focus-visible) { outline: 2px solid var(--focus); outline-offset: 2px; }
    \\  .c-clist[data-v="tiles"] .pic { position: relative; margin-bottom: 10px; }
    \\  .c-clist[data-v="tiles"] .pic > .c-champ { --sz: 64px; }
    \\  .c-clist[data-v="tiles"] .tag { position: absolute; left: 50%; bottom: -7px; transform: translateX(-50%); line-height: 1; }
    \\  .c-clist[data-v="tiles"] .tag > * { padding: 2px 5px; font-size: var(--fs-xs);
    \\    background: var(--panel); box-shadow: 0 0 0 1px var(--line-2); }
    \\  .c-clist[data-v="tiles"] .nm { display: block; flex: none; max-width: 100%; text-overflow: ellipsis; font-size: var(--fs-s); }
    \\  .c-clist[data-v="tiles"] .v { font-size: var(--fs-l); }
    \\  .c-clist[data-v="tiles"] .g { max-width: 100%; font-size: var(--fs-xs); text-align: center; }
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
    pub const hard = plain("hard");
    pub const tile = plain("Sett: 44% of Darius mains play it, 3.5× as often as other players");
    pub const tile_hard = plain("Garen: 49% of Darius mains play it, 2.9× as often as other players. Harder to pick up");
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const also = [_]struct { champ.Champ, tree.Text, tree.Text, bool, tree.Text }{
        .{ champ.demo("Sett", "Sett"), plain("×3.5"), plain("44%"), false, plain("3.5× as often") },
        .{ champ.demo("Olaf", "Olaf"), plain("×3.4"), plain("22%"), false, plain("3.4× as often") },
        .{ champ.demo("Mordekaiser", "Mordekaiser"), plain("×3.0"), plain("45%"), false, plain("3.0× as often") },
        .{ champ.demo("Garen", "Garen"), plain("×2.9"), plain("49%"), true, plain("2.9× as often") },
        .{ champ.demo("Aatrox", "Aatrox"), plain("×2.9"), plain("30%"), false, plain("2.9× as often") },
        .{ champ.demo("Malphite", "Malphite"), plain("×2.8"), plain("7%"), false, plain("2.8× as often") },
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
    var tl: [also.len]Row = undefined;
    for (also, 0..) |x, i| tl[i] = .{
        .champ = x[0],
        .href = "#",
        .tag = if (x[3]) badge.view(h, .neutral, .{G.hard}) else null,
        .label = if (x[3]) G.tile_hard else if (i == 0) G.tile else null,
        .value = h.span(.{}, .{x[2]}),
        .note = x[4],
    };
    g.addFill("tiles: the share, how much more often, a harder mark", view(h, .{ .tiles = true, .label = G.also }, &tl));
    g.addFill("two columns", view(h, .{ .cols = true, .label = G.also }, &rows));
    g.addFill("matchups: duels, the lane's bar and range; a role; where a move started", view(h, .{}, &.{
        .{ .champ = champ.demo("Darius", "Darius"), .vs = champ.demo("Garen", "Garen"), .href = "#", .lane = .{ .win = 51.2, .ci = 2.3 }, .value = h.span(.{ .style = h.vars(.{ .c = fmt.Step.of(1.2, fmt.win_cuts) }) }, .{plain("51.2%")}), .note = plain("1,788") },
        .{ .champ = champ.demo("Tryndamere", "Tryndamere"), .vs = champ.demo("Malphite", "Malphite"), .href = "#", .lane = .{ .win = 41.6, .ci = 2.8 }, .value = h.span(.{ .style = h.vars(.{ .c = fmt.Step.of(-8.4, fmt.win_cuts) }) }, .{plain("41.6%")}), .note = plain("1,204") },
        .{ .champ = champ.demo("Jax", "Jax"), .vs = champ.demo("Aatrox", "Aatrox"), .role = .top, .href = "#", .lane = .{ .win = 53.9, .ci = 3.2, .was = 50.8 }, .value = delta.view(h, .{ .d = 3.1 }), .note = plain("905") },
        .{ .champ = champ.demo("Ornn", "Ornn"), .vs = champ.demo("Gragas", "Gragas"), .role = .top, .href = "#", .lane = .{ .win = 61.8, .ci = 7.3, .was = 44 }, .value = delta.view(h, .{ .d = 17.8, .faint = true }), .note = plain("170") },
    }));
    g.addFill("duels with a Bar: a gold lead, the list's biggest full", view(h, .{}, &.{
        .{ .champ = champ.demo("Draven", "Draven"), .vs = champ.demo("Jinx", "Jinx"), .href = "#", .fill = 1, .value = h.span(.{}, .{plain("+1,227 gold")}), .note = plain("4,120") },
        .{ .champ = champ.demo("Renekton", "Renekton"), .vs = champ.demo("Kayle", "Kayle"), .role = .top, .href = "#", .fill = 0.62, .value = h.span(.{}, .{plain("+761 gold")}), .note = plain("2,310") },
    }));
    g.addFill("with roles, no links", view(h, .{}, &.{
        .{ .champ = champ.demo("Ahri", "Ahri"), .role = .mid, .value = h.span(.{}, .{plain("+2.4")}), .note = plain("12,040") },
        .{ .champ = champ.demo("Jinx", "Jinx"), .role = .bot, .value = h.span(.{}, .{plain("−1.8")}), .note = plain("9,311") },
    }));
}
