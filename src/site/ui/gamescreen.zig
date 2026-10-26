//! GameScreen: the desktop app's in-game panel, private edition only (the public one gets a
//! note). The score and both teams' item gold, the five lanes (TeamRows), your lane
//! against the matchup's games at this minute with its gold chart, objective respawns,
//! and the team gold through the game. Only what the scoreboard shows anyway: a panel to
//! look at, never an alert (docs/plan/app.md "In-game companion"). Wide: lanes left, your
//! lane right; narrow: one column, your lane after the score
const tree = @import("tree.zig");
const champ = @import("champ.zig");
const lane = @import("lane.zig");
const teamrows = @import("teamrows.zig");
const phrase = @import("phrase.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "GameScreen";
pub const scope = .{".c-game"};

pub const Lean = teamrows.Lean;

pub const Score = struct { what: []const u8, us: u16, them: u16 };

/// Both teams' item gold: one bar split by share, the difference over it
pub const Gold = struct {
    us: []const u8,
    them: []const u8,
    /// "+1.2k item gold"
    gap: []const u8,
    lean: Lean = .none,
    /// Ours of both, 0..1
    share: f32 = 0.5,
};

/// "CS +8: about typical at 12 min (middle half −6 to +10)"
pub const Compare = struct {
    what: []const u8,
    now: []const u8,
    lean: Lean = .none,
    text: []const u8,
};

pub const Lane = struct {
    me: ?champ.Champ,
    them: ?champ.Champ,
    compare: []const Compare = &.{},
    /// Why nothing is compared now ("The lane curve covers minutes 1 to 20.")
    note: []const u8 = "",
    chart: ?lane.Figures = null,
    /// What the chart shows, under it
    caption: []const u8 = "",
};

pub const Timer = struct {
    /// "Dragon", "Their top inhibitor"
    what: []const u8,
    /// "14:05"
    at: []const u8,
    /// "1:10"
    in: []const u8,
};

pub const Screen = struct {
    score: []const Score,
    gold: Gold,
    rows: []const teamrows.Row,
    lane: ?Lane = null,
    /// Why there is no lane to compare
    lane_note: []const u8 = "",
    timers: []const Timer = &.{},
    /// Item gold, us minus them, by minute
    team: []const f32 = &.{},
};

/// The island's chart states; null draws no chart
pub const Charts = struct {
    lane: ?*lane.Held = null,
    team: ?*lane.Held = null,
};

pub fn view(h: *H, s: Screen, c: Charts) N {
    return h.div(.{ .class = "c-game" }, .{
        h.div(.{ .class = "col" }, .{
            score(h, s.score, s.gold),
            h.section(.{ .class = "lanes" }, .{
                teamrows.view(h, s.rows),
                h.p(.{ .class = "note" }, .{W.rows_note}),
            }),
        }),
        h.div(.{ .class = "col" }, .{
            yourLane(h, s, c.lane),
            timers(h, s.timers),
            teamGold(h, s.team, c.team),
        }),
    });
}

fn score(h: *H, lines: []const Score, g: Gold) N {
    var cells = h.list();
    for (lines, 0..) |l, i| cells.add(h.div(.{ .key = i, .class = "cell" }, .{
        h.span(.{ .class = "nums" }, .{
            h.b(.{ .data_side = "us" }, .{l.us}),
            h.el(.i, .{ .aria_hidden = true }, .{"-"}),
            h.b(.{ .data_side = "them" }, .{l.them}),
        }),
        h.small(.{}, .{l.what}),
    }));
    return h.section(.{ .class = "score" }, .{
        h.div(.{ .class = "cells" }, .{cells.done()}),
        h.div(.{ .class = "gold" }, .{
            h.span(.{ .data_side = "us" }, .{g.us}),
            h.span(.{ .class = "gap", .data_lean = if (g.lean == .none) null else g.lean }, .{g.gap}),
            h.span(.{ .data_side = "them" }, .{g.them}),
        }),
        h.div(.{ .class = "split", .aria_hidden = true }, .{h.el(.i, .{ .style = h.vars(.{ .w = 100 * g.share }) }, .{})}),
    });
}

fn yourLane(h: *H, s: Screen, held: ?*lane.Held) N {
    const l = s.lane orelse return h.section(.{ .class = "you" }, .{
        h.h3(.{}, .{W.your_lane}),
        h.p(.{ .class = "note" }, .{s.lane_note}),
    });
    var lines = h.list();
    for (l.compare, 0..) |c, i| lines.add(h.li(.{ .key = i }, .{
        h.span(.{ .class = "what" }, .{c.what}),
        h.b(.{ .data_lean = if (c.lean == .none) null else c.lean }, .{c.now}),
        h.span(.{}, .{c.text}),
    }));
    return h.section(.{ .class = "you" }, .{
        h.h3(.{}, .{W.your_lane}),
        h.div(.{ .class = "vs" }, .{
            champ.view(h, l.me, .{ .px = .@"40", .side = .us, .named = false }),
            h.b(.{}, .{ if (l.me) |m| m.name else W.unknown.s, W.vs, if (l.them) |t| t.name else W.unknown.s }),
            champ.view(h, l.them, .{ .px = .@"40", .side = .them, .named = false }),
        }),
        if (l.compare.len > 0) h.el(.ul, .{ .class = "cmp" }, .{lines.done()}) else null,
        if (l.note.len > 0) h.p(.{ .class = "note" }, .{l.note}) else null,
        if (l.chart) |c| if (held) |x| x.at(c, W.gold).view(h) else null else null,
        if (l.caption.len > 0) h.p(.{ .class = "note" }, .{l.caption}) else null,
    });
}

fn timers(h: *H, ts: []const Timer) N {
    var rows = h.list();
    for (ts, 0..) |t, i| rows.add(h.li(.{ .key = i }, .{
        h.span(.{}, .{t.what}),
        h.b(.{}, .{ t.at, h.small(.{}, .{W.in.with(h, .{ .t = t.in })}) }),
    }));
    return h.section(.{ .class = "timers" }, .{
        h.h3(.{}, .{W.timers}),
        if (ts.len == 0) h.p(.{ .class = "note" }, .{W.no_timers}) else h.el(.ul, .{}, .{rows.done()}),
    });
}

/// Item gold, us minus them, by minute: the in-game panel's and the post game screen's
pub fn teamGold(h: *H, team: []const f32, held: ?*lane.Held) ?N {
    if (team.len < 2) return null;
    const x = held orelse return null;
    return h.section(.{ .class = "team" }, .{
        h.h3(.{}, .{W.team_gold}),
        x.at(.{ .a = W.us.s, .b = W.them.s, .you = team }, W.item_gold).view(h),
    });
}

const W = struct {
    const rows_note = plain("Gold from the items each player holds: the game shows nobody's gold but your own.");
    const your_lane = plain("Your lane");
    const vs = plain(" vs ");
    const unknown = plain("New champion");
    const gold = plain("Gold");
    const timers = plain("Coming back");
    const no_timers = plain("Dragon, Baron and inhibitor respawns show here once one is taken.");
    const in = phrase.Phrase(" in {t:text}");
    const team_gold = plain("Team gold");
    const item_gold = plain("Item gold");
    const us = plain("Your team");
    const them = plain("Enemy team");
};

pub const css =
    \\@layer components {
    \\  .c-game { display: grid; grid-template-columns: minmax(0, 1fr); gap: var(--sp-4); min-width: 0; }
    \\  .c-game .col { display: contents; }
    \\  .c-game .score { order: 1; }
    \\  .c-game .you { order: 2; }
    \\  .c-game .lanes { order: 3; }
    \\  .c-game .timers { order: 4; }
    \\  .c-game .team { order: 5; }
    \\  @container (min-width: 820px) {
    \\    .c-game { grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); align-items: start; }
    \\    .c-game .col { display: flex; flex-direction: column; gap: var(--sp-4); min-width: 0; }
    \\  }
    \\  .c-game section { display: flex; flex-direction: column; gap: var(--sp-2); min-width: 0; }
    \\  .c-game h3 { margin: 0; font-size: var(--fs-s); font-weight: var(--w-m); color: var(--t2); }
    \\  .c-game .note { margin: 0; font-size: var(--fs-xs); color: var(--faint); }
    \\  .c-game .score [data-side="us"] { color: var(--us); }
    \\  .c-game .score [data-side="them"] { color: var(--them); }
    \\  .c-game .score [data-lean="good"], .c-game .cmp [data-lean="good"] { color: var(--hi2); }
    \\  .c-game .score [data-lean="bad"], .c-game .cmp [data-lean="bad"] { color: var(--lo2); }
    \\  .c-game .score { padding: var(--sp-3); border-radius: var(--r-m); background: var(--panel-2); }
    \\  .c-game .cells { display: flex; flex-wrap: wrap; justify-content: center; gap: var(--sp-2) var(--sp-5); }
    \\  .c-game .cell { display: flex; flex-direction: column; align-items: center; }
    \\  .c-game .nums { display: flex; align-items: baseline; gap: 6px; font-size: var(--fs-xl); font-weight: var(--w-b);
    \\    font-variant-numeric: tabular-nums; line-height: var(--lh-tight); }
    \\  .c-game .nums > i { font-style: normal; font-weight: var(--w-r); color: var(--faint); }
    \\  .c-game .cell > small { font-size: var(--fs-xs); color: var(--muted); }
    \\  .c-game .gold { display: grid; grid-template-columns: 1fr auto 1fr; gap: var(--sp-2); margin-top: var(--sp-2);
    \\    font-size: var(--fs-s); font-variant-numeric: tabular-nums; }
    \\  .c-game .gold > [data-side="them"] { text-align: right; }
    \\  .c-game .gap { font-weight: var(--w-m); }
    \\  .c-game .split { height: 8px; border-radius: 4px; background: var(--them); overflow: hidden; }
    \\  .c-game .split > i { display: block; height: 100%; width: calc(var(--w) * 1%); background: var(--us); }
    \\  .c-game .vs { display: flex; align-items: center; gap: var(--sp-3); }
    \\  .c-game .vs > b { font-size: var(--fs-l); font-weight: var(--w-b); }
    \\  .c-game .cmp, .c-game .timers ul { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 4px; }
    \\  .c-game .cmp > li { display: grid; grid-template-columns: 76px 56px minmax(0, 1fr); align-items: baseline;
    \\    gap: var(--sp-2); font-size: var(--fs-s); }
    \\  .c-game .cmp .what { color: var(--muted); }
    \\  .c-game .cmp b { font-size: var(--fs-m); font-variant-numeric: tabular-nums; }
    \\  .c-game .timers li { display: flex; justify-content: space-between; gap: var(--sp-2); }
    \\  .c-game .timers b { font-variant-numeric: tabular-nums; }
    \\  .c-game .timers small { font-weight: var(--w-r); color: var(--muted); }
    \\}
    \\
;

const demo = champ.demo;

/// Minute 14, ahead a little; a made-up game so far
pub const sample: Screen = .{
    .score = &.{
        .{ .what = "Kills", .us = 9, .them = 7 },
        .{ .what = "Towers", .us = 2, .them = 1 },
        .{ .what = "Dragons", .us = 1, .them = 1 },
        .{ .what = "Grubs", .us = 3, .them = 0 },
    },
    .gold = .{ .us = "24.1k", .them = "23.0k", .gap = "+1.1k item gold", .lean = .good, .share = 0.512 },
    .rows = &teamrows.sample,
    .lane = .{
        .me = demo("Orianna", "Orianna"),
        .them = demo("Syndra", "Syndra"),
        .compare = &.{
            .{ .what = "CS", .now = "+9", .lean = .good, .text = "ahead of most games like it at 14 min (middle half −6 to +7)" },
            .{ .what = "Item gold", .now = "+300", .text = "about typical at 14 min (middle half −420 to +510)" },
        },
        .chart = .{
            .a = "Orianna",
            .b = "Syndra",
            .you = &.{ 0, 10, -20, 40, 80, 60, 120, 90, 150, 200, 180, 260, 240, 310, 300 },
            .band = &.{ .{ 0, 0 }, .{ -40, 40 }, .{ -80, 90 }, .{ -110, 130 }, .{ -150, 170 }, .{ -190, 210 }, .{ -220, 260 }, .{ -260, 300 }, .{ -290, 340 }, .{ -320, 380 }, .{ -350, 420 }, .{ -370, 450 }, .{ -390, 480 }, .{ -410, 500 }, .{ -420, 510 }, .{ -440, 540 }, .{ -460, 570 }, .{ -480, 600 }, .{ -500, 620 }, .{ -520, 650 } },
            .line = &.{ 0, 0, 5, 10, 10, 15, 20, 20, 25, 30, 35, 40, 40, 45, 45, 50, 55, 60, 60, 65 },
        },
        .caption = "Item gold, you minus them: the band is the middle half of 412 games (Emerald+, EUW, last 30 days), the line their average.",
    },
    .timers = &.{
        .{ .what = "Dragon", .at = "15:20", .in = "1:10" },
        .{ .what = "Their top inhibitor", .at = "19:02", .in = "4:52" },
    },
    .team = &.{ 0, 50, -120, -300, -150, 200, 400, 350, 700, 900, 650, 800, 1000, 1100, 1100 },
};

pub fn charts(h: *H) Charts {
    const held = h.mem.alloc(lane.Held, 2) catch {
        h.oom = true;
        return .{};
    };
    held[0] = .{};
    held[1] = .{};
    return .{ .lane = &held[0], .team = &held[1] };
}

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.addFill("minute 14", view(h, sample, charts(h)));
    var early = sample;
    early.score = sample.score[0..2];
    early.timers = &.{};
    early.team = &.{};
    early.lane = .{ .me = sample.lane.?.me, .them = null, .note = "Their mid isn't known yet: no lane to compare." };
    g.addFill("early, no opponent", view(h, early, charts(h)));
    var none = early;
    none.lane = null;
    none.lane_note = "No curves for this matchup yet.";
    g.addFill("no lane", view(h, none, .{}));
}
