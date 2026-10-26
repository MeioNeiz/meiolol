//! PuzzleCard: one puzzle a screen. The setup as a picture on a lit stage band across the
//! card's top (RateRows, champion icons, tiles), one short question, the answer (a
//! GuessSlider in the stage, or ChoiceCards under the question), then in place the
//! closeness Badge and stars, one line why and the takeaway; the foot holds the games
//! (a Toggletip with the source) and the one action, Lock in or Next.
//!
//! RateRows: a few win rates as rows on one axis centred on 50%, each a bar from the
//! middle to its rate in the rate's colour; the asked row is the GuessSlider itself
//! (row variant), so the setup, the guess and the answer share one axis
const std = @import("std");
const tree = @import("tree.zig");
const fmt = @import("fmt.zig");
const card = @import("card.zig");
const badge = @import("badge.zig");
const button = @import("button.zig");
const toggletip = @import("toggletip.zig");
const guess = @import("guess.zig");
const Gallery = @import("gallery.zig").Gallery;
const phrase = @import("phrase.zig");
const plain = phrase.plain;
const Phrase = phrase.Phrase;
const H = tree.H;
const N = tree.N;
const Guess = guess.Guess;

pub const name = "PuzzleCard";
pub const scope = .{ ".c-puzzle", ".c-rates", ".c-stars", ".c-take" };

const W = struct {
    pub const ask = plain("?");
    pub const you = plain("You ");
    pub const games = Phrase("{n:kilo} games");
    pub const stars = Phrase("{n:int} of 3 stars");
    pub const lock = plain("Lock in");
    pub const next = plain("Next");
};

pub const Opts = struct {
    /// The setup: RateRows, icons, tiles
    stage: N,
    /// At most 12 words, no numbers (they belong in the stage); may hold a Toggletip term
    q: N,
    /// Under the question before the answer: what the setup counts
    ctx: ?N = null,
    /// ChoiceCards, or a GuessSlider not in the stage
    answer: ?N = null,
    /// Revealed: "3.3 off" (a guess), and the stars
    off: ?tree.Text = null,
    stars: ?u2 = null,
    why: ?tree.Text = null,
    take: ?tree.Text = null,
    /// The games and their source (a Toggletip), at the foot's start
    games: ?N = null,
    /// The foot's one button
    action: N,
    label: ?tree.Text = null,
};

pub fn view(h: *H, o: Opts) N {
    // Slots keyed: the answer, unkeyed, keeps its nodes (and focus) when ctx goes
    return card.view(h, .{ .label = o.label }, &.{h.div(.{ .class = "c-puzzle", .aria_live = "polite" }, .{
        h.div(.{ .key = 1, .class = "stage" }, .{o.stage}),
        h.div(.{ .key = 2, .class = "qrow" }, .{
            h.h2(.{ .class = "q" }, .{o.q}),
            if (o.off) |t| badge.view(h, .neutral, .{t}) else null,
            if (o.stars) |n| stars(h, n, false) else null,
        }),
        if (o.ctx) |c| h.div(.{ .key = 3, .class = "ctx" }, .{c}) else null,
        o.answer,
        if (o.why) |t| h.p(.{ .class = "why" }, .{t}) else null,
        if (o.take) |t| take(h, t) else null,
        h.div(.{ .key = 4, .class = "foot" }, .{ o.games orelse h.span(.{}, .{}), o.action }),
    })});
}

/// 0-3 stars; `big` for a chapter's end
pub fn stars(h: *H, n: u2, big: bool) N {
    var l = h.list();
    for (0..3) |i| l.add(h.el(.i, .{ .data_off = i >= n }, .{"★"}));
    return h.span(.{ .class = "c-stars", .data_s = if (big) "l" else null, .role = "img", .aria_label = W.stars.with(h, .{ .n = n }) }, .{l.done()});
}

/// A takeaway: one sentence on an accent rule
pub fn take(h: *H, t: tree.Text) N {
    return h.p(.{ .class = "c-take" }, .{t});
}

pub const Row = struct {
    label: tree.Text,
    sub: ?tree.Text = null,
    /// %; none on the asked row until revealed
    v: ?f32 = null,
    games: ?u32 = null,
    /// The asked row, revealed: accent, with the guess marked
    hit: bool = false,
    you: ?f32 = null,
};

pub const Rates = struct {
    lo: f32,
    hi: f32,
    mid: f32 = 50,
    rows: []const Row,
    ticks: []const f32 = &.{},
    /// The asked row's slider, until revealed; its row is the one without a value
    ask: ?*const Guess = null,
    on: ?tree.Handler = null,
    /// Under the axis until the first move ("drag the Main row")
    hint: ?tree.Text = null,
};

fn at(r: Rates, v: f32) f32 {
    return 100 * std.math.clamp((v - r.lo) / (r.hi - r.lo), 0, 1);
}

pub fn rates(h: *H, r: Rates) N {
    var l = h.list();
    const mid = at(r, r.mid);
    for (r.rows, 0..) |row, i| {
        const asked = row.v == null;
        l.add(h.span(.{ .key = i, .class = "lab", .data_hit = row.hit or asked }, .{
            row.label,
            if (row.sub) |s| h.el(.small, .{}, .{s}) else null,
        }));
        const track: N = if (asked) (if (r.ask) |g| guess.view(h, g, .{ .on = r.on, .row = true, .label = row.label, .ref = "ask" }) else N.none) else h.el(.i, .{
            .class = "bar",
            .style = h.vars(.{ .a = @min(mid, at(r, row.v.?)), .b = @max(mid, at(r, row.v.?)), .c = fmt.wrColour(row.v.? / 100, fmt.table_span) }),
        }, .{});
        l.add(h.span(.{ .key = 1000 + i, .class = "trk", .data_ask = asked, .data_hit = row.hit }, .{
            track,
            if (row.you) |y| h.el(.i, .{ .class = "you", .style = h.vars(.{ .x = at(r, y) }) }, .{}) else null,
        }));
        const shown = if (row.v) |v| v else if (r.ask) |g| g.value else null;
        l.add(h.span(.{ .key = 2000 + i, .class = "v", .data_ask = asked or row.hit }, .{
            if (shown) |v| guess.text(h, .rate, v) else W.ask,
            if (row.you) |y| h.el(.small, .{ .class = "you" }, .{ W.you, guess.text(h, .rate, y) }) else if (row.games) |n| h.el(.small, .{}, .{W.games.with(h, .{ .n = n })}) else null,
        }));
    }
    var ax = h.list();
    for (r.ticks) |t| ax.add(h.span(.{ .data_mid = t == r.mid, .style = h.vars(.{ .x = at(r, t) }) }, .{guess.text(h, .rate, t)}));
    const moved = if (r.ask) |g| g.value != null else true;
    return h.div(.{ .class = "c-rates", .style = h.vars(.{ .mid = mid }) }, .{
        l.done(),
        if (ax.done().len > 0) h.div(.{ .class = "ax", .aria_hidden = true }, .{ax.done()}) else null,
        if (r.hint) |t| h.div(.{ .class = "hint", .data_gone = moved }, .{t}) else null,
    });
}

pub const css =
    \\@layer components {
    \\  .c-puzzle { display: grid; gap: var(--sp-4); container-type: inline-size; }
    \\  .c-puzzle > .stage { margin: calc(-1 * var(--card-py)) calc(-1 * var(--card-px)) 0; padding: var(--sp-5) var(--card-px) var(--sp-4);
    \\    background: radial-gradient(90% 120% at 50% 0%, var(--accent-bg), transparent 70%), var(--panel-2);
    \\    border-bottom: 1px solid var(--line); border-radius: var(--r-m) var(--r-m) 0 0; display: grid; gap: var(--sp-3); min-width: 0; }
    \\  .c-puzzle .qrow { display: flex; align-items: center; gap: var(--sp-2) var(--sp-3); flex-wrap: wrap; }
    \\  .c-puzzle .q { margin: 0; font-size: var(--fs-xl); font-weight: var(--w-b); letter-spacing: -0.01em; line-height: 1.25; }
    \\  .c-puzzle .qrow > .c-stars { margin-left: auto; }
    \\  .c-puzzle .ctx { display: flex; align-items: center; gap: var(--sp-2); flex-wrap: wrap; font-size: var(--fs-s); color: var(--muted); }
    \\  .c-puzzle .why { margin: 0; color: var(--t2); }
    \\  .c-puzzle .foot { display: flex; align-items: center; justify-content: space-between; gap: var(--sp-3);
    \\    font-size: var(--fs-s); color: var(--muted); }
    \\  .c-puzzle .foot > .c-btn[data-v="primary"] { min-width: 132px; }
    \\  .c-take { margin: 0; padding: var(--sp-2) var(--sp-3); border-left: 2px solid var(--accent); background: var(--accent-bg);
    \\    border-radius: 0 var(--r-s) var(--r-s) 0; font-weight: var(--w-m); }
    \\  .c-stars { display: inline-flex; gap: 1px; color: var(--turn); font-size: var(--fs-m); line-height: 1; }
    \\  .c-stars > i { font-style: normal; }
    \\  .c-stars > i[data-off] { color: var(--line-2); }
    \\  .c-stars[data-s="l"] { font-size: var(--fs-xl); gap: 4px; }
    \\  .c-rates { display: grid; grid-template-columns: 124px minmax(0, 1fr) 72px; column-gap: var(--sp-3); align-items: center; }
    \\  .c-rates > .lab { font-size: var(--fs-m); font-weight: var(--w-b); line-height: 1.25; min-width: 0; }
    \\  .c-rates > .lab small { display: block; font-size: var(--fs-xs); color: var(--faint); font-weight: var(--w-r); }
    \\  .c-rates > .lab[data-hit] { color: var(--accent); }
    \\  .c-rates > .trk { position: relative; height: 52px; min-width: 0; }
    \\  .c-rates > .trk::before { content: ""; position: absolute; inset-inline: 0; top: 25px; height: 2px; border-radius: 1px;
    \\    background: var(--bar-track); }
    \\  .c-rates > .trk[data-ask]::before { display: none; }
    \\  .c-rates > .trk::after { content: ""; position: absolute; left: calc(var(--mid) * 1%); top: 0; bottom: 0; width: 1px;
    \\    background: var(--axis); pointer-events: none; }
    \\  .c-rates > .trk > .bar { position: absolute; top: 15px; height: 22px; left: calc(var(--a) * 1%);
    \\    width: max(3px, calc((var(--b) - var(--a)) * 1%)); border-radius: 4px; background: var(--c); }
    \\  .c-rates > .trk[data-hit] > .bar { background: var(--accent); box-shadow: 0 0 0 1.5px var(--sel-line); }
    \\  .c-rates > .trk > .you { position: absolute; top: 10px; left: calc(var(--x) * 1%); width: 4px; height: 32px; margin-left: -2px;
    \\    border-radius: 2px; background: var(--accent); }
    \\  .c-rates > .trk > .c-guess { position: absolute; inset: 0; z-index: 1; }
    \\  .c-rates > .v { text-align: right; font-size: var(--fs-xl); font-weight: var(--w-b); font-variant-numeric: tabular-nums;
    \\    line-height: 1.15; white-space: nowrap; }
    \\  .c-rates > .v small { display: block; font-size: var(--fs-xs); font-weight: var(--w-r); color: var(--faint); }
    \\  .c-rates > .v[data-ask] { color: var(--accent); }
    \\  .c-rates > .v small.you { color: var(--accent); font-weight: var(--w-m); }
    \\  .c-rates > .ax { grid-column: 2; position: relative; height: 16px; font-size: var(--fs-xs); color: var(--faint);
    \\    font-variant-numeric: tabular-nums; }
    \\  .c-rates > .ax > span { position: absolute; left: calc(var(--x) * 1%); transform: translateX(-50%); white-space: nowrap; }
    \\  .c-rates > .ax > span[data-mid] { color: var(--t2); }
    \\  .c-rates > .hint { grid-column: 2; font-size: var(--fs-xs); color: var(--faint); text-align: center; padding-top: 2px; }
    \\  .c-rates > .hint[data-gone] { visibility: hidden; }
    \\  @container (max-width: 560px) {
    \\    .c-rates { grid-template-columns: 74px minmax(0, 1fr) 56px; column-gap: var(--sp-2); }
    \\    .c-rates > .v { font-size: var(--fs-l); }
    \\    .c-rates > .lab { font-size: var(--fs-s); }
    \\    .c-rates > .v small:not(.you) { display: none; }
    \\    .c-puzzle .foot > .c-btn[data-v="primary"] { flex: 1; }
    \\  }
    \\}
    \\
;

const bands = [_]struct { []const u8, ?[]const u8, f32, u32 }{
    .{ "<10k", "New", 47.7, 207_598 },
    .{ "10-30k", null, 48.7, 262_918 },
    .{ "30-100k", null, 49.5, 486_889 },
    .{ "100-300k", null, 50.6, 457_460 },
    .{ "300k+", "Main", 51.7, 508_609 },
};
const ticks = [_]f32{ 40, 45, 50, 55, 60 };

fn source(h: *H, g: *Gallery, comptime id: []const u8) N {
    const tt = toggletip.view(h, g.id(id), .{"508,609 games"}, plain("508,609 games"), plain("Ranked solo, Platinum IV and up, every region, by mastery points on the champion before the game."));
    return h.span(.{}, .{&tt});
}

/// The mastery puzzle: unset, moved, revealed
fn know(h: *H, g: *Gallery, comptime id: []const u8, value: ?f32, revealed: bool) N {
    const x = h.mem.create(Guess) catch {
        h.oom = true;
        return .none;
    };
    x.* = .{ .lo = 40, .hi = 60, .from = 50, .value = value, .real = if (revealed) 51.7 else null };
    if (!revealed) {
        const rows = [_]Row{
            .{ .label = plain("New"), .sub = plain("under 10k"), .v = 47.7, .games = 207_598 },
            .{ .label = plain("Main"), .sub = plain("300k+"), .games = 508_609 },
        };
        return view(h, .{
            .stage = rates(h, .{ .lo = 40, .hi = 60, .rows = h.mem.dupe(Row, &rows) catch &.{}, .ticks = &ticks, .ask = x, .hint = plain("drag the Main row") }),
            .q = h.span(.{}, .{plain("How often do mains win?")}),
            .ctx = h.span(.{}, .{plain("Mastery points on the champion, before the game")}),
            .games = source(h, g, id),
            .action = button.view(h, .{ .v = .primary, .disabled = value == null }, .{W.lock}),
        });
    }
    var rows = h.mem.alloc(Row, bands.len) catch return .none;
    for (bands, 0..) |b, i| rows[i] = .{
        .label = .{ .s = b[0] },
        .sub = if (b[1]) |s| tree.Text{ .s = s } else null,
        .v = b[2],
        .games = b[3],
        .hit = i == bands.len - 1,
        .you = if (i == bands.len - 1) value else null,
    };
    return view(h, .{
        .stage = rates(h, .{ .lo = 40, .hi = 60, .rows = rows, .ticks = &ticks }),
        .q = h.span(.{}, .{plain("How often do mains win?")}),
        .off = guess.offText(h, x),
        .stars = x.stars(1),
        .why = plain("New to main: +4 points. A typical top lane counter is 2.5."),
        .take = plain("Counter-pick with a champion you already know."),
        .games = source(h, g, id),
        .action = button.view(h, .{ .v = .primary }, .{W.next}),
    });
}

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.addFill("guess in the stage: untouched", know(h, g, "pz-a", null, false));
    g.addFill("moved", know(h, g, "pz-b", 55, false));
    g.addFill("revealed: all bands, the asked one lit", know(h, g, "pz-c", 55, true));
    const gs = h.mem.create(Guess) catch return;
    gs.* = .{ .lo = 0, .hi = 1000, .step = 25, .unit = .gold, .value = 450 };
    g.addFill("guess under the question (gold)", view(h, .{
        .stage = h.div(.{}, .{plain("Behind by 3,000+")}),
        .q = h.span(.{}, .{plain("What does a kill pay?")}),
        .answer = guess.view(h, gs, .{ .ticks = &.{ 0, 500, 1000 } }),
        .action = button.view(h, .{ .v = .primary }, .{W.lock}),
    }));
    g.add("stars", h.span(.{}, .{ stars(h, 0, false), " ", stars(h, 2, false), " ", stars(h, 3, true) }));
    g.addFill("takeaway", take(h, plain("Counter-pick with a champion you already know.")));
}
