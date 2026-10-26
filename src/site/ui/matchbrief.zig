//! MatchupBrief: under the champion page's matchup chart, the chosen opponent (or ally)
//! in brief: portrait, name, relation, the figures, a button into the matchup page; beside
//! it the most met as chips to jump between (Jacob v9: one tap shows the brief, an
//! obvious way into the matchup). The page's island owns the choice: chips carry its
//! handlers, as DotPlot's dots do
const tree = @import("tree.zig");
const champ = @import("champ.zig");
const chip = @import("chip.zig");
const badge = @import("badge.zig");
const button = @import("button.zig");
const strip = @import("strip.zig");
const fmt = @import("fmt.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = @import("phrase.zig").plain;
const H = tree.H;
const N = tree.N;

pub const name = "MatchupBrief";
pub const scope = .{".c-mpick"};

pub const Brief = struct {
    champ: champ.Champ,
    /// "Top opponent", "Jungle ally"
    rel: tree.Text,
    thin: bool = false,
    /// StatStrip: the champion's rate in it, vs usual, gold at 14, games
    figures: N,
    /// The matchup page
    href: ?[]const u8 = null,
};

pub const Common = struct {
    champ: champ.Champ,
    /// The champion's rate against it
    fig: tree.Text,
    colour: fmt.WrColour,
    thin: bool = false,
    pressed: bool = false,
    on: ?tree.Handler = null,
};

const W = struct {
    pub const few = plain("few games");
    pub const matchup = plain("Matchup ›");
    pub const common = plain("Most common");
};

pub fn view(h: *H, b: Brief, common: []const Common) N {
    var chips = h.list();
    for (common, 0..) |c, i| chips.add(h.div(.{ .key = i, .data_state = if (c.thin) "thin" else null }, .{
        chip.view(h, .{ .pressed = c.pressed, .on = c.on }, .{
            // Named: the portrait's alt is the chip's name with its rate
            champ.view(h, c.champ, .{ .px = .@"20" }),
            h.span(.{ .class = "v", .style = h.vars(.{ .c = c.colour }) }, .{c.fig}),
        }),
    }));
    return h.div(.{ .class = "c-mpick", .data_state = if (b.thin) "thin" else null }, .{
        h.div(.{ .class = "one" }, .{
            h.div(.{ .class = "who" }, .{
                champ.view(h, b.champ, .{ .px = .@"40", .named = false }),
                h.div(.{ .class = "t" }, .{
                    h.b(.{}, .{b.champ.name}),
                    h.small(.{}, .{ b.rel, if (b.thin) badge.view(h, .few, .{W.few}) else null }),
                }),
            }),
            b.figures,
            if (b.href) |href| button.view(h, .{ .s = .s, .href = href }, .{W.matchup}) else null,
        }),
        if (common.len > 0) h.div(.{ .class = "met" }, .{
            h.span(.{ .class = "sh" }, .{W.common}),
            h.div(.{ .class = "chips" }, .{chips.done()}),
        }) else null,
    });
}

pub const css =
    \\@layer components {
    \\  .c-mpick { display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: var(--sp-3) var(--sp-5); align-items: center; }
    \\  .c-mpick .one { display: flex; align-items: center; gap: var(--sp-3) var(--sp-5); flex-wrap: wrap; min-width: 0; }
    \\  .c-mpick .who { display: flex; align-items: center; gap: var(--sp-3); min-width: 150px; }
    \\  .c-mpick .who > .c-champ { border-radius: var(--r-s); box-shadow: 0 0 0 2px var(--panel), 0 0 0 3.5px var(--accent); }
    \\  .c-mpick .who .t { display: flex; flex-direction: column; min-width: 0; }
    \\  .c-mpick .who b { font-size: var(--fs-l); font-weight: var(--w-b); }
    \\  .c-mpick .who small { display: flex; flex-wrap: wrap; align-items: center; gap: 2px var(--sp-2); font-size: var(--fs-s); color: var(--faint); }
    \\  .c-mpick[data-state="thin"] .c-strip .val { opacity: 0.55; }
    \\  .c-mpick .met { display: flex; flex-direction: column; gap: var(--sp-1); padding-left: var(--sp-5);
    \\    border-left: 1px solid var(--line); }
    \\  .c-mpick .sh { font-size: var(--fs-xs); font-weight: var(--w-b); color: var(--faint); text-transform: uppercase;
    \\    letter-spacing: 0.06em; }
    \\  .c-mpick .chips { display: grid; grid-template-columns: repeat(3, auto); gap: var(--sp-1); }
    \\  .c-mpick .chips > div { display: flex; }
    \\  .c-mpick .chips > [data-state="thin"] { opacity: 0.6; }
    \\  .c-mpick .chips .c-chip { flex: 1; height: 30px; padding: 0 10px 0 4px; gap: 6px; border-radius: var(--r-ctl); }
    \\  .c-mpick .chips .c-champ { border-radius: var(--r-s); }
    \\  .c-mpick .chips .v { color: var(--c); font-weight: var(--w-b); font-variant-numeric: tabular-nums; }
    \\  @container (max-width: 719px) {
    \\    .c-mpick { grid-template-columns: minmax(0, 1fr); }
    \\    .c-mpick .met { padding-left: 0; border-left: 0; }
    \\    .c-mpick .one > .c-btn { margin-left: auto; }
    \\    .c-mpick .chips { display: flex; overflow-x: auto; scrollbar-width: none; }
    \\    .c-mpick .chips > div { flex: none; }
    \\  }
    \\  @container (max-width: 440px) {
    \\    .c-mpick .who { flex: 1; }
    \\    .c-mpick .one > .c-strip { order: 3; flex: 1 1 100%; }
    \\  }
    \\}
    \\
;

const G = struct {
    pub const darius_wins = plain("Darius wins");
    pub const usual = plain("Vs usual");
    pub const gold = plain("Gold at 14");
    pub const games = plain("Games");
    pub const top = plain("Top opponent");
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const agg = fmt.win_cuts;
    const common = [_]Common{
        .{ .champ = champ.demo("Garen", "Garen"), .fig = plain("49.9%"), .colour = .{ .pts = -0.1 }, .pressed = true },
        .{ .champ = champ.demo("Sett", "Sett"), .fig = plain("47.4%"), .colour = .{ .pts = -2.6 } },
        .{ .champ = champ.demo("Jayce", "Jayce"), .fig = plain("51.8%"), .colour = .{ .pts = 1.8 } },
        .{ .champ = champ.demo("Mordekaiser", "Mordekaiser"), .fig = plain("50.2%"), .colour = .{ .pts = 0.2 } },
        .{ .champ = champ.demo("Aatrox", "Aatrox"), .fig = plain("45.9%"), .colour = .{ .pts = -4.1 } },
        .{ .champ = champ.demo("Olaf", "Olaf"), .fig = plain("48.0%"), .colour = .{ .pts = -2 }, .thin = true },
    };
    const figures = strip.view(h, &.{
        .{ .label = G.darius_wins, .value = plain("49.9%"), .ctx = plain("+0.6"), .step = .of(0.6, agg), .answer = true },
        .{ .label = G.usual, .value = plain("+1.2"), .step = .of(1.2, agg) },
        .{ .label = G.gold, .value = plain("+382") },
        .{ .label = G.games, .value = plain("1,788"), .ctx = plain("5.7%") },
    });
    g.addFill("an opponent chosen, the most met beside", view(h, .{ .champ = common[0].champ, .rel = G.top, .figures = figures, .href = "#" }, &common));
    g.addFill("few games, no chips", view(h, .{
        .champ = champ.demo("Quinn", "Quinn"),
        .rel = G.top,
        .thin = true,
        .figures = strip.view(h, &.{
            .{ .label = G.darius_wins, .value = plain("58.1%"), .ctx = plain("+8.8"), .step = .of(8.8, agg), .answer = true },
            .{ .label = G.games, .value = plain("43"), .ctx = plain("0.1%") },
        }),
        .href = "#",
    }, &.{}));
}
