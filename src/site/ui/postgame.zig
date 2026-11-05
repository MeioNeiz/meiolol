//! PostGame: the desktop app after a game, static HTML after the island (nothing to tap).
//! The verdict and kills over award cards (a champion's best figures, one card each);
//! then both teams lane by lane (TeamRows) beside damage to champions, each team with
//! its total. Facts, no advice, no sentences (research/questions/desktop-app-layout.md
//! C20)
const tree = @import("tree.zig");
const champ = @import("champ.zig");
const teamrows = @import("teamrows.zig");
const phrase = @import("phrase.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "PostGame";
pub const scope = .{".c-post"};

pub const Side = enum { us, them };

/// A champion holding any of the game's best figures
pub const Award = struct {
    champ: ?champ.Champ,
    side: Side,
    /// "25k dmg", "6.3 KDA", "224 cs"
    figures: []const []const u8,
};

/// Damage to champions by one player
pub const Damage = struct {
    champ: ?champ.Champ,
    you: bool = false,
    value: u32,
    /// "18k"
    text: []const u8,
};

pub const Team = struct {
    /// "73k"
    total: []const u8 = "",
    players: []const Damage = &.{},
};

pub const Screen = struct {
    win: bool,
    /// The client is still counting: the last in-game rows, no verdict yet
    coming: bool = false,
    /// "Victory 28:42"
    verdict: []const u8,
    /// Ours, theirs
    kills: [2]u16,
    /// Ours first, at most 4
    awards: []const Award = &.{},
    rows: []const teamrows.Row,
    /// Ours, theirs; none until the result
    damage: [2]Team = .{ .{}, .{} },
};

pub fn view(h: *H, s: Screen) N {
    var awards = h.list();
    for (s.awards, 0..) |a, i| awards.add(award(h, i, a));
    return h.div(.{ .class = "c-post" }, .{
        h.section(.{ .class = "sum", .data_win = s.win, .data_coming = s.coming }, .{
            h.div(.{ .class = "head" }, .{
                h.h2(.{}, .{s.verdict}),
                h.span(.{ .class = "kills" }, .{W.kills.with(h, .{ .a = @as(u32, s.kills[0]), .b = @as(u32, s.kills[1]) })}),
            }),
            if (s.awards.len > 0) h.el(.ol, .{ .class = "awards" }, .{awards.done()}) else null,
        }),
        h.section(.{ .class = "lanes" }, .{
            teamrows.view(h, s.rows),
            if (s.coming) null else h.p(.{ .class = "note" }, .{W.rows_note}),
        }),
        damage(h, s.damage),
    });
}

fn award(h: *H, i: usize, a: Award) N {
    var figures = h.list();
    for (a.figures, 0..) |f, j| figures.add(h.span(.{ .key = j }, .{f}));
    return h.li(.{ .key = i, .class = "award", .data_side = a.side }, .{
        champ.view(h, a.champ, .{ .px = .@"40", .side = if (a.side == .us) .us else .them, .named = false, .label = W.unknown }),
        h.div(.{}, .{
            h.b(.{}, .{if (a.champ) |c| c.name else W.unknown.s}),
            h.span(.{ .class = "figs" }, .{figures.done()}),
        }),
    });
}

/// One bar per player against the most anyone did, so the two teams share a scale
fn damage(h: *H, teams: [2]Team) ?N {
    if (teams[0].players.len + teams[1].players.len == 0) return null;
    var most: u32 = 1;
    for (teams) |t| for (t.players) |d| {
        most = @max(most, d.value);
    };
    var blocks = h.list();
    for (teams, [_]Side{ .us, .them }) |t, side| {
        if (t.players.len == 0) continue;
        var rows = h.list();
        for (t.players, 0..) |d, i| rows.add(h.li(.{ .key = i, .data_you = d.you }, .{
            champ.view(h, d.champ, .{ .px = .@"20" }),
            h.span(.{ .class = "n" }, .{d.text}),
            h.span(.{ .class = "track", .aria_hidden = true }, .{h.el(.i, .{ .style = h.vars(.{ .w = 100 * @as(f32, @floatFromInt(d.value)) / @as(f32, @floatFromInt(most)) }) }, .{})}),
        }));
        blocks.add(h.div(.{ .key = @backingInt(side), .class = "side", .data_side = side }, .{
            h.el(.h4, .{}, .{ if (side == .us) W.us else W.them, h.span(.{}, .{t.total}) }),
            h.ul(.{}, .{rows.done()}),
        }));
    }
    return h.section(.{ .class = "dmg" }, .{
        h.h3(.{}, .{W.damage}),
        blocks.done(),
    });
}

const W = struct {
    const kills = phrase.Phrase("{a:int} - {b:int} kills");
    const unknown = plain("New champion");
    const rows_note = plain("Between the rows: gold earned over the game, you minus them.");
    const damage = plain("Damage to champions");
    const us = plain("Your team");
    const them = plain("Enemy team");
};

pub const css =
    \\@layer components {
    \\  .c-post { display: grid; grid-template-columns: minmax(0, 1fr); gap: var(--sp-4); min-width: 0; }
    \\  @container (min-width: 820px) {
    \\    .c-post { grid-template-columns: minmax(0, 3fr) minmax(0, 2fr); align-items: start; }
    \\    .c-post .sum { grid-column: 1 / -1; }
    \\  }
    \\  .c-post section { display: flex; flex-direction: column; gap: var(--sp-2); min-width: 0; }
    \\  .c-post h3 { margin: 0; font-size: var(--fs-s); font-weight: var(--w-m); color: var(--t2); }
    \\  .c-post .note { margin: 0; font-size: var(--fs-xs); color: var(--faint); }
    \\  .c-post [data-side="us"] { --side: var(--us); }
    \\  .c-post [data-side="them"] { --side: var(--them); }
    \\  .c-post .sum { gap: var(--sp-3); padding: var(--sp-3) var(--sp-4); border-radius: var(--r-m);
    \\    background: var(--panel-2); box-shadow: inset 3px 0 0 var(--lo2); }
    \\  .c-post .sum[data-win] { box-shadow: inset 3px 0 0 var(--hi2); }
    \\  .c-post .head { display: flex; align-items: baseline; gap: var(--sp-3); }
    \\  .c-post h2 { margin: 0; font-size: var(--fs-xl); font-weight: var(--w-b); color: var(--lo2);
    \\    font-variant-numeric: tabular-nums; }
    \\  .c-post .sum[data-win] h2 { color: var(--hi2); }
    \\  .c-post .sum[data-coming] { box-shadow: inset 3px 0 0 var(--line); }
    \\  .c-post .sum[data-coming] h2 { color: var(--t2); }
    \\  .c-post .kills { margin-left: auto; font-size: var(--fs-l); font-weight: var(--w-m); color: var(--t2);
    \\    font-variant-numeric: tabular-nums; }
    \\  .c-post .awards { list-style: none; margin: 0; padding: 0; display: grid; gap: var(--sp-2);
    \\    grid-template-columns: repeat(auto-fill, minmax(190px, 1fr)); }
    \\  .c-post .award { display: flex; align-items: center; gap: var(--sp-3); padding: var(--sp-2) var(--sp-3);
    \\    border-radius: var(--r-m); background: var(--panel); }
    \\  .c-post .award > div { display: flex; flex-direction: column; gap: 2px; min-width: 0; }
    \\  .c-post .award b { font-size: var(--fs-s); font-weight: var(--w-m); color: var(--side); }
    \\  .c-post .figs { display: flex; flex-wrap: wrap; gap: 0 var(--sp-2); font-size: var(--fs-s);
    \\    font-variant-numeric: tabular-nums; }
    \\  .c-post .dmg .side { display: flex; flex-direction: column; gap: 2px; }
    \\  .c-post .dmg .side + .side { margin-top: var(--sp-2); }
    \\  .c-post h4 { display: flex; justify-content: space-between; margin: 0 0 2px; font-size: var(--fs-xs);
    \\    font-weight: var(--w-m); color: var(--side); }
    \\  .c-post h4 > span { color: var(--t2); font-variant-numeric: tabular-nums; }
    \\  .c-post .dmg ul { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 2px; }
    \\  .c-post .dmg li { display: flex; align-items: center; gap: var(--sp-2); }
    \\  .c-post .n { width: 44px; flex: none; font-size: var(--fs-s); font-variant-numeric: tabular-nums; color: var(--t2); }
    \\  .c-post .dmg li[data-you] .n { color: var(--text); font-weight: var(--w-m); }
    \\  .c-post .track { flex: 1; height: 10px; }
    \\  .c-post .track > i { display: block; height: 100%; width: calc(var(--w) * 1%); border-radius: 3px;
    \\    background: var(--side); opacity: 0.65; }
    \\  .c-post li[data-you] .track > i { opacity: 1; }
    \\}
    \\
;

const demo = champ.demo;

/// The post game rows: K/D/A · cs · damage, gold earned between
const sample_rows = blk: {
    var r = teamrows.sample;
    const lines = [_][2][]const u8{
        .{ "182 cs · 14k dmg", "160 cs · 9.8k dmg" },
        .{ "121 cs · 11k dmg", "140 cs · 15k dmg" },
        .{ "231 cs · 25k dmg", "214 cs · 19k dmg" },
        .{ "240 cs · 21k dmg", "262 cs · 26k dmg" },
        .{ "31 cs · 6.2k dmg", "28 cs · 7.7k dmg" },
    };
    for (&r, lines) |*x, l| {
        x.us.?.dead = null;
        x.us.?.line = l[0];
        x.them.?.line = l[1];
    }
    break :blk r;
};

pub const sample: Screen = .{
    .win = true,
    .verdict = "Victory 28:42",
    .kills = .{ 24, 17 },
    .awards = &.{
        .{ .champ = demo("Orianna", "Orianna"), .side = .us, .figures = &.{ "25k dmg", "6.3 KDA", "231 cs" } },
        .{ .champ = demo("Caitlyn", "Caitlyn"), .side = .them, .figures = &.{"14k gold"} },
        .{ .champ = demo("Thresh", "Thresh"), .side = .us, .figures = &.{"61 vision"} },
    },
    .rows = &sample_rows,
    .damage = .{
        .{ .total = "78k", .players = &.{
            .{ .champ = demo("Darius", "Darius"), .value = 14100, .text = "14k" },
            .{ .champ = demo("Vi", "Vi"), .value = 11200, .text = "11k" },
            .{ .champ = demo("Orianna", "Orianna"), .you = true, .value = 24600, .text = "25k" },
            .{ .champ = demo("Jinx", "Jinx"), .value = 21400, .text = "21k" },
            .{ .champ = demo("Thresh", "Thresh"), .value = 6200, .text = "6.2k" },
        } },
        .{ .total = "78k", .players = &.{
            .{ .champ = demo("Ornn", "Ornn"), .value = 9800, .text = "9.8k" },
            .{ .champ = demo("LeeSin", "Lee Sin"), .value = 15300, .text = "15k" },
            .{ .champ = demo("Syndra", "Syndra"), .value = 19000, .text = "19k" },
            .{ .champ = demo("Caitlyn", "Caitlyn"), .value = 25900, .text = "26k" },
            .{ .champ = demo("Leona", "Leona"), .value = 7700, .text = "7.7k" },
        } },
    },
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.addFill("victory", view(h, sample));
    var loss = sample;
    loss.win = false;
    loss.verdict = "Defeat 31:05";
    loss.awards = &.{
        .{ .champ = demo("Caitlyn", "Caitlyn"), .side = .them, .figures = &.{ "26k dmg", "14k gold", "262 cs" } },
        .{ .champ = demo("Leona", "Leona"), .side = .them, .figures = &.{"7.0 KDA"} },
        .{ .champ = demo("Thresh", "Thresh"), .side = .us, .figures = &.{"61 vision"} },
    };
    g.addFill("defeat", view(h, loss));
    var coming = loss;
    coming.coming = true;
    coming.verdict = "Result coming";
    coming.awards = &.{};
    coming.damage = .{ .{}, .{} };
    var bare = sample_rows;
    for (&bare) |*r| {
        r.gap = "";
        r.lean = .none;
    }
    coming.rows = &bare;
    g.addFill("result coming", view(h, coming));
}
