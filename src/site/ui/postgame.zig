//! PostGame: the desktop app after a game. The verdict and kills, the team gold story and
//! your lane in a sentence each, award chips; then both teams lane by lane (TeamRows), the
//! team gold through the game and damage to champions. Facts, no advice; no dense tables
//! (research/questions/desktop-app-layout.md C20)
const tree = @import("tree.zig");
const champ = @import("champ.zig");
const teamrows = @import("teamrows.zig");
const gamescreen = @import("gamescreen.zig");
const lane = @import("lane.zig");
const phrase = @import("phrase.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "PostGame";
pub const scope = .{".c-post"};

pub const Side = enum { us, them };

pub const Award = struct {
    /// "Most damage"
    what: []const u8,
    champ: ?champ.Champ,
    side: Side,
};

/// Damage to champions, one bar per player against the most anyone did
pub const Damage = struct {
    champ: ?champ.Champ,
    side: Side,
    you: bool = false,
    value: u32,
    /// "18.2k"
    text: []const u8,
};

pub const Screen = struct {
    win: bool,
    /// "Victory in 28:42."
    verdict: []const u8,
    /// Ours, theirs
    kills: [2]u16,
    /// Item gold through the game in a sentence; "" without history
    story: []const u8 = "",
    /// Your lane at 14 min against the matchup's games; "" when unknown
    lane: []const u8 = "",
    awards: []const Award = &.{},
    rows: []const teamrows.Row,
    /// Ours then theirs
    damage: []const Damage = &.{},
    /// Item gold, us minus them, by minute
    team: []const f32 = &.{},
};

pub fn view(h: *H, s: Screen, team: ?*lane.Held) N {
    var awards = h.list();
    for (s.awards, 0..) |a, i| awards.add(h.span(.{ .key = i, .class = "award", .data_side = a.side }, .{
        champ.view(h, a.champ, .{ .px = .@"24", .named = false }),
        h.span(.{}, .{
            h.small(.{}, .{a.what}),
            h.b(.{}, .{if (a.champ) |c| c.name else W.unknown.s}),
        }),
    }));
    return h.div(.{ .class = "c-post" }, .{
        h.section(.{ .class = "sum", .data_win = s.win }, .{
            h.div(.{ .class = "head" }, .{
                h.h2(.{}, .{s.verdict}),
                h.span(.{ .class = "kills" }, .{W.kills.with(h, .{ .a = @as(u32, s.kills[0]), .b = @as(u32, s.kills[1]) })}),
            }),
            if (s.story.len > 0) h.p(.{}, .{s.story}) else null,
            if (s.lane.len > 0) h.p(.{}, .{s.lane}) else null,
            if (s.awards.len > 0) h.div(.{ .class = "awards" }, .{awards.done()}) else null,
        }),
        h.div(.{ .class = "col" }, .{
            h.section(.{ .class = "lanes" }, .{
                teamrows.view(h, s.rows),
                h.p(.{ .class = "note" }, .{W.rows_note}),
            }),
        }),
        h.div(.{ .class = "col" }, .{
            gamescreen.teamGold(h, s.team, team),
            damage(h, s.damage),
        }),
    });
}

fn damage(h: *H, ds: []const Damage) ?N {
    if (ds.len == 0) return null;
    var most: u32 = 1;
    for (ds) |d| most = @max(most, d.value);
    var rows = h.list();
    for (ds, 0..) |d, i| rows.add(h.li(.{ .key = i, .data_side = d.side, .data_you = d.you }, .{
        champ.view(h, d.champ, .{ .px = .@"20" }),
        h.span(.{ .class = "n" }, .{d.text}),
        h.span(.{ .class = "track", .aria_hidden = true }, .{h.el(.i, .{ .style = h.vars(.{ .w = 100 * @as(f32, @floatFromInt(d.value)) / @as(f32, @floatFromInt(most)) }) }, .{})}),
    }));
    return h.section(.{ .class = "dmg" }, .{
        h.h3(.{}, .{W.damage}),
        h.ul(.{}, .{rows.done()}),
    });
}

const W = struct {
    const kills = phrase.Phrase("{a:int} - {b:int} kills");
    const unknown = plain("New champion");
    const rows_note = plain("Between the rows: gold earned over the game, you minus them.");
    const damage = plain("Damage to champions");
};

pub const css =
    \\@layer components {
    \\  .c-post { display: grid; grid-template-columns: minmax(0, 1fr); gap: var(--sp-4); min-width: 0; }
    \\  .c-post .col { display: contents; }
    \\  .c-post .sum { order: 1; }
    \\  .c-post .team { order: 2; }
    \\  .c-post .lanes { order: 3; }
    \\  .c-post .dmg { order: 4; }
    \\  @container (min-width: 820px) {
    \\    .c-post { grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); align-items: start; }
    \\    .c-post .sum { grid-column: 1 / -1; order: 0; }
    \\    .c-post .col { display: flex; flex-direction: column; gap: var(--sp-4); min-width: 0; }
    \\  }
    \\  .c-post section { display: flex; flex-direction: column; gap: var(--sp-2); min-width: 0; }
    \\  .c-post h3 { margin: 0; font-size: var(--fs-s); font-weight: var(--w-m); color: var(--t2); }
    \\  .c-post .note { margin: 0; font-size: var(--fs-xs); color: var(--faint); }
    \\  .c-post [data-side="us"] { --side: var(--us); }
    \\  .c-post [data-side="them"] { --side: var(--them); }
    \\  .c-post .sum { padding: var(--sp-3) var(--sp-4); border-radius: var(--r-m); background: var(--panel-2);
    \\    box-shadow: inset 3px 0 0 var(--lo2); }
    \\  .c-post .sum[data-win] { box-shadow: inset 3px 0 0 var(--hi2); }
    \\  .c-post .sum p { margin: 0; }
    \\  .c-post .head { display: flex; align-items: baseline; gap: var(--sp-3); }
    \\  .c-post h2 { margin: 0; font-size: var(--fs-xl); font-weight: var(--w-b); color: var(--lo2); }
    \\  .c-post .sum[data-win] h2 { color: var(--hi2); }
    \\  .c-post .kills { margin-left: auto; font-size: var(--fs-l); font-weight: var(--w-m); color: var(--t2);
    \\    font-variant-numeric: tabular-nums; }
    \\  .c-post .awards { display: flex; flex-wrap: wrap; gap: var(--sp-2); }
    \\  .c-post .award { display: flex; align-items: center; gap: 6px; padding: 3px 10px 3px 4px; border-radius: var(--r-m);
    \\    box-shadow: inset 0 0 0 1px var(--side); }
    \\  .c-post .award > span { display: flex; flex-direction: column; line-height: var(--lh-tight); }
    \\  .c-post .award small { font-size: var(--fs-xs); color: var(--muted); }
    \\  .c-post .award b { font-size: var(--fs-s); font-weight: var(--w-m); color: var(--side); }
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
        .{ "182 cs · 14.1k dmg", "160 cs · 9.8k dmg" },
        .{ "121 cs · 11.2k dmg", "140 cs · 15.3k dmg" },
        .{ "231 cs · 24.6k dmg", "214 cs · 19.0k dmg" },
        .{ "240 cs · 21.4k dmg", "262 cs · 25.9k dmg" },
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
    .verdict = "Victory in 28:42.",
    .kills = .{ 24, 17 },
    .story = "Your team fell behind early, took the lead at 18 minutes and held it.",
    .lane = "At 14 minutes you were 300 gold up on Syndra; most games in this matchup sit between −420 and +510.",
    .awards = &.{
        .{ .what = "Most damage", .champ = demo("Orianna", "Orianna"), .side = .us },
        .{ .what = "Most kills", .champ = demo("Caitlyn", "Caitlyn"), .side = .them },
        .{ .what = "Most vision", .champ = demo("Thresh", "Thresh"), .side = .us },
    },
    .rows = &sample_rows,
    .damage = &.{
        .{ .champ = demo("Darius", "Darius"), .side = .us, .value = 14100, .text = "14.1k" },
        .{ .champ = demo("Vi", "Vi"), .side = .us, .value = 11200, .text = "11.2k" },
        .{ .champ = demo("Orianna", "Orianna"), .side = .us, .you = true, .value = 24600, .text = "24.6k" },
        .{ .champ = demo("Jinx", "Jinx"), .side = .us, .value = 21400, .text = "21.4k" },
        .{ .champ = demo("Thresh", "Thresh"), .side = .us, .value = 6200, .text = "6.2k" },
        .{ .champ = demo("Ornn", "Ornn"), .side = .them, .value = 9800, .text = "9.8k" },
        .{ .champ = demo("LeeSin", "Lee Sin"), .side = .them, .value = 15300, .text = "15.3k" },
        .{ .champ = demo("Syndra", "Syndra"), .side = .them, .value = 19000, .text = "19.0k" },
        .{ .champ = demo("Caitlyn", "Caitlyn"), .side = .them, .value = 25900, .text = "25.9k" },
        .{ .champ = demo("Leona", "Leona"), .side = .them, .value = 7700, .text = "7.7k" },
    },
    .team = &.{ 0, 50, -120, -300, -150, -400, -700, -650, -900, -1200, -800, -500, -300, 100, 400, 300, 700, 1200, 1500, 1300, 1900, 2600, 3100, 2800, 3600, 4200, 5100, 6400, 7200 },
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.addFill("victory", view(h, sample, gamescreen.charts(h).team));
    var loss = sample;
    loss.win = false;
    loss.verdict = "Defeat in 31:05.";
    loss.story = "";
    loss.lane = "";
    loss.awards = &.{};
    loss.team = &.{};
    g.addFill("defeat, no history", view(h, loss, null));
}
