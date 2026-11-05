//! MatchupBrief: under the champion page's matchup chart, the chosen opponent (or ally)
//! in brief: portrait, name, relation, the figures, a button into the matchup page (Jacob
//! v9: one tap shows the brief, an obvious way into the matchup)
const tree = @import("tree.zig");
const champ = @import("champ.zig");
const badge = @import("badge.zig");
const button = @import("button.zig");
const strip = @import("strip.zig");
const rate = @import("rate.zig");
const phrase = @import("phrase.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "MatchupBrief";
pub const scope = .{".c-mpick"};

pub const Brief = struct {
    champ: champ.Champ,
    /// "Top opponent", "Jungle ally"
    rel: tree.Text,
    /// Few games: a badge says so (the figures' rate fades by itself)
    thin: bool = false,
    /// StatStrip: the champion's rate in it, vs usual, gold at 14, games
    figures: N,
    /// The matchup page
    href: ?[]const u8 = null,
    /// A lane partner: to the champion's lane opponents, whose matchup pages show the
    /// pair (Lane partners)
    lanes: ?tree.Handler = null,
    /// The champion page's opponent lock: every block then counts games against it
    lock: ?Lock = null,
};

pub const Lock = struct { on: tree.Handler, locked: bool };

const W = struct {
    pub const few = plain("few games");
    pub const matchup = plain("Matchup ›");
    pub const lock = plain("Lock");
    pub const unlock = plain("Unlock");
    pub const lanes = plain("Lane opponents ›");
};

pub fn view(h: *H, b: Brief) N {
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
            if (b.lock) |l| button.view(h, .{ .s = .s, .on = l.on }, .{if (l.locked) W.unlock else W.lock}) else null,
            if (b.href) |href| button.view(h, .{ .s = .s, .href = href }, .{W.matchup}) else null,
            if (b.lanes) |on| button.view(h, .{ .s = .s, .on = on }, .{W.lanes}) else null,
        }),
    });
}

pub const css =
    \\@layer components {
    \\  .c-mpick .one { display: flex; align-items: center; gap: var(--sp-3) var(--sp-5); flex-wrap: wrap; min-width: 0; }
    \\  .c-mpick .who { display: flex; align-items: center; gap: var(--sp-3); min-width: 150px; }
    \\  .c-mpick .who > .c-champ { border-radius: var(--r-s); box-shadow: 0 0 0 2px var(--panel), 0 0 0 3.5px var(--accent); }
    \\  .c-mpick .who .t { display: flex; flex-direction: column; min-width: 0; }
    \\  .c-mpick .who b { font-size: var(--fs-l); font-weight: var(--w-b); }
    \\  .c-mpick .who small { display: flex; flex-wrap: wrap; align-items: center; gap: 2px var(--sp-2); font-size: var(--fs-s); color: var(--faint); }
    \\  @container (max-width: 719px) { .c-mpick .one > .c-btn { margin-left: auto; } }
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
    const figures = strip.view(h, &.{
        .{ .label = G.darius_wins, .rate = rate.view(h, .at(1788, 49.9), .{ .said = "" }), .answer = true },
        .{ .label = G.usual, .rate = rate.delta(h, 1.2, null) },
        .{ .label = G.gold, .value = plain("+382") },
        .{ .label = G.games, .value = plain("1,788"), .ctx = plain("5.7%") },
    });
    g.addFill("an opponent chosen", view(h, .{ .champ = champ.demo("Garen", "Garen"), .rel = G.top, .figures = figures, .href = "#" }));
    g.addFill("few games", view(h, .{
        .champ = champ.demo("Quinn", "Quinn"),
        .rel = G.top,
        .thin = true,
        .figures = strip.view(h, &.{
            .{ .label = G.darius_wins, .rate = rate.view(h, .at(43, 58.1), .{ .said = "" }), .answer = true },
            .{ .label = G.games, .value = plain("43"), .ctx = plain("0.1%") },
        }),
        .href = "#",
    }));
}
