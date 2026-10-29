//! ChampSelect: the desktop app's champ select screen. The board (DraftBoard) beside the
//! lane panel: you against your lane opponent, a sentence on the matchup, then options
//! from your pool, each with its lane fact and reasons as chips; ban options under while
//! bans are open. The shell writes every word for its edition (src/shell/screens.zig):
//! the public one gets no win chances (`win` and `draft` stay null, product rules).
//! The options list is the seed of CandidateList (draft-tester.md)
const tree = @import("tree.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const badge = @import("badge.zig");
const chip = @import("chip.zig");
const card = @import("card.zig");
const fmt = @import("fmt.zig");
const draftboard = @import("draftboard.zig");
const lanechart = @import("lane.zig");
const compview = @import("compview.zig");
const phrase = @import("phrase.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "ChampSelect";
pub const scope = .{".c-cs"};

pub const Lean = draftboard.Lean;

pub const Screen = struct {
    board: draftboard.Board,
    lane: Lane,
    ban_options: []const BanOption = &.{},
    /// Your turn to ban: the ban options lead
    banning: bool = false,
    /// Private edition: your team's draft win chance in %
    draft: ?f32 = null,
    /// Once all ten are locked: under the board
    comp: ?compview.Comp = null,
};

pub const Mode = enum { blind, counter, locked };

pub const Lane = struct {
    role: role.Role,
    me: ?champ.Champ = null,
    them: ?champ.Champ = null,
    /// Their role is a guess: enemy positions are hidden
    guessed: bool = false,
    mode: Mode = .blind,
    /// One sentence on the matchup; "" before both are known
    sentence: []const u8 = "",
    /// Few games behind the sentence
    thin: bool = false,
    /// The matchup's gold by minute (band and line, no `you`) and what it shows
    chart: ?lanechart.Figures = null,
    caption: []const u8 = "",
    options: []const Option = &.{},
    /// Options weigh your mastery points; null shows no toggle
    mastery: ?bool = null,
    /// "EUW, last 30 days"
    scope: []const u8 = "",
};

pub const Option = struct {
    champ: champ.Champ,
    /// Your hover or lock
    current: bool = false,
    /// Private edition: your team's win chance with it, in %
    win: ?f32 = null,
    /// "+120 gold at 14 min vs Syndra"; "" without an opponent or curves
    lane: []const u8 = "",
    lean: Lean = .none,
    /// Few games behind the lane fact: fainter
    faint: bool = false,
    reasons: []const Reason = &.{},
    /// Practice's click (ui/practice.zig Act); "" for none
    act: []const u8 = "",
};

pub const Reason = struct { text: []const u8, lean: Lean = .none };

pub const BanOption = struct {
    champ: champ.Champ,
    role: role.Role,
    /// Your lane opponent's role
    mine: bool = false,
    /// Why ("wins often, picked a lot"; numbers in the private edition)
    why: []const u8,
    /// Practice's click (ui/practice.zig Act); "" for none
    act: []const u8 = "",
};

/// `held`: the island's chart state; null draws no chart. `mastery` flips Lane.mastery
pub fn view(h: *H, s: Screen, held: ?*lanechart.Held, mastery: ?tree.Handler) N {
    const bans = banOptions(h, s);
    return h.div(.{ .class = "c-cs" }, .{
        h.div(.{ .class = "board" }, .{
            if (s.draft) |d| h.p(.{ .class = "draft", .style = h.vars(.{ .c = fmt.wrColour(d / 100, 0.2) }) }, .{W.draft.with(h, .{ .p = d })}) else null,
            draftboard.view(h, s.board),
            if (s.comp) |c| compview.view(h, c) else null,
            if (!s.banning) bans else null,
        }),
        h.div(.{ .class = "side" }, .{
            if (s.banning) bans else null,
            lane(h, s.lane, held, mastery),
        }),
    });
}

fn lane(h: *H, l: Lane, held: ?*lanechart.Held, on_mastery: ?tree.Handler) N {
    var opts = h.list();
    for (l.options, 0..) |o, i| opts.add(option(h, i, o, l.mode == .locked));
    return h.section(.{ .class = "lane" }, .{
        h.div(.{ .class = "vs" }, .{
            champ.view(h, l.me, .{ .px = .@"48", .you = true, .named = false, .label = W.no_pick }),
            h.div(.{ .class = "who" }, .{
                h.h2(.{}, .{
                    if (l.me) |m| m.name else W.no_pick.s,
                    if (l.them) |t| h.span(.{ .class = "them" }, .{ W.vs, t.name, if (l.guessed) W.guess else null }) else null,
                }),
                h.span(.{ .class = "tags" }, .{
                    badge.view(h, .us, .{role.Role.label(l.role)}),
                    badge.view(h, if (l.mode == .locked) .accent else .neutral, .{switch (l.mode) {
                        .blind => W.blind,
                        .counter => W.counter,
                        .locked => W.locked,
                    }}),
                }),
            }),
            if (l.them) |t| champ.view(h, t, .{ .px = .@"32", .side = .them, .state = if (l.guessed) .thin else .normal }) else null,
        }),
        if (l.sentence.len > 0) h.p(.{ .class = "say", .data_thin = l.thin }, .{l.sentence}) else null,
        if (l.chart) |c| if (held) |x| x.at(c, W.gold).view(h) else null else null,
        if (l.chart != null and l.caption.len > 0) h.p(.{ .class = "scope" }, .{l.caption}) else null,
        h.div(.{ .class = "opts-head" }, .{
            h.h3(.{}, .{switch (l.mode) {
                .blind => W.head_blind,
                .counter => W.head_counter,
                .locked => W.head_locked,
            }}),
            if (l.mastery) |m| chip.view(h, .{ .pressed = m, .on = on_mastery }, .{W.mastery}) else null,
        }),
        if (l.options.len == 0) h.p(.{ .class = "say" }, .{W.none}) else h.el(.ol, .{ .class = "opts" }, .{opts.done()}),
        if (l.scope.len > 0) h.p(.{ .class = "scope" }, .{l.scope}) else null,
    });
}

fn option(h: *H, i: usize, o: Option, locked: bool) N {
    var chips = h.list();
    for (o.reasons, 0..) |r, j| chips.add(h.span(.{ .key = j, .class = "why", .data_lean = if (r.lean == .none) null else r.lean }, .{
        chip.view(h, .{ .v = .reason }, .{r.text}),
    }));
    return h.li(.{ .key = i, .data_current = o.current, .data_act = if (o.act.len > 0) o.act else null }, .{
        champ.view(h, o.champ, .{ .px = .@"40", .named = false }),
        h.div(.{ .class = "body" }, .{
            h.div(.{ .class = "name" }, .{
                h.b(.{}, .{o.champ.name}),
                if (o.current) badge.view(h, .accent, .{if (locked) W.locked_in else W.hovering}) else null,
            }),
            if (o.lane.len > 0) h.span(.{ .class = "fact", .data_lean = if (o.lean == .none) null else o.lean, .data_faint = o.faint }, .{o.lane}) else null,
            if (o.reasons.len > 0) h.span(.{ .class = "chips" }, .{chips.done()}) else null,
        }),
        if (o.win) |w| h.span(.{ .class = "win", .style = h.vars(.{ .c = fmt.wrColour(w / 100, 0.2) }) }, .{
            W.win.with(h, .{ .p = w }),
            h.small(.{}, .{W.team_win}),
        }) else null,
    });
}

fn banOptions(h: *H, s: Screen) ?N {
    if (s.ban_options.len == 0) return null;
    var rows = h.list();
    for (s.ban_options, 0..) |o, i| rows.add(h.li(.{ .key = i, .data_act = if (o.act.len > 0) o.act else null }, .{
        champ.view(h, o.champ, .{ .px = .@"32", .named = false }),
        h.div(.{ .class = "body" }, .{
            h.div(.{ .class = "name" }, .{
                h.b(.{}, .{o.champ.name}),
                role.view(h, o.role, .{ .s = .s }),
                if (o.mine) badge.view(h, .us, .{W.your_lane}) else null,
            }),
            h.span(.{ .class = "fact" }, .{o.why}),
        }),
    }));
    return h.section(.{ .class = "bans", .data_turn = s.banning }, .{
        h.h3(.{}, .{if (s.banning) W.ban_now else W.ban_options}),
        h.el(.ol, .{ .class = "opts" }, .{rows.done()}),
    });
}

const W = struct {
    const draft = phrase.Phrase("Draft so far: {p:rate} for your team");
    const win = phrase.Phrase("{p:rate}");
    const team_win = plain("team win");
    const no_pick = plain("No pick yet");
    const gold = plain("Gold");
    const vs = plain(" vs ");
    const guess = plain("?");
    const blind = plain("Safe blind");
    const counter = plain("Counter");
    const locked = plain("Locked in");
    const locked_in = plain("locked");
    const hovering = plain("hovering");
    const head_blind = plain("Options that hold up blind");
    const head_counter = plain("Options into them");
    const head_locked = plain("Other options");
    const mastery = plain("Count mastery");
    const none = plain("No champion you can pick has enough games in this role.");
    const your_lane = plain("your lane");
    const ban_now = plain("Your ban");
    const ban_options = plain("Ban options");
};

pub const css =
    \\@layer components {
    \\  .c-cs { container-type: inline-size; display: grid; grid-template-columns: minmax(0, 1fr);
    \\    gap: var(--sp-4); min-width: 0; }
    \\  @container (min-width: 820px) {
    \\    .c-cs { grid-template-columns: minmax(0, 5fr) minmax(0, 6fr); align-items: start; }
    \\  }
    \\  .c-cs > div { display: flex; flex-direction: column; gap: var(--sp-4); min-width: 0; }
    \\  .c-cs .draft { margin: 0; font-weight: var(--w-m); color: var(--c, var(--text)); }
    \\  .c-cs section { display: flex; flex-direction: column; gap: var(--sp-2); min-width: 0; }
    \\  .c-cs h2 { margin: 0; font-size: var(--fs-l); font-weight: var(--w-b); line-height: var(--lh-tight); }
    \\  .c-cs h2 .them { font-weight: var(--w-r); color: var(--t2); }
    \\  .c-cs h3 { margin: var(--sp-2) 0 0; font-size: var(--fs-s); font-weight: var(--w-m); color: var(--t2); }
    \\  .c-cs .vs { display: flex; align-items: center; gap: var(--sp-3); }
    \\  .c-cs .vs .who { display: flex; flex-direction: column; gap: 4px; flex: 1; min-width: 0; }
    \\  .c-cs .tags { display: flex; gap: 4px; flex-wrap: wrap; }
    \\  .c-cs .say { margin: 0; color: var(--text); }
    \\  .c-cs .say[data-thin] { color: var(--muted); }
    \\  .c-cs .opts-head { display: flex; align-items: flex-end; justify-content: space-between; gap: var(--sp-2); flex-wrap: wrap; }
    \\  .c-cs .scope { margin: 0; font-size: var(--fs-xs); color: var(--faint); }
    \\  .c-cs .opts { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 2px; }
    \\  .c-cs .opts > li { display: flex; align-items: center; gap: var(--sp-3); padding: var(--sp-2);
    \\    border-radius: var(--r-s); background: var(--panel-2); min-width: 0; }
    \\  .c-cs .opts > li[data-current] { box-shadow: inset 0 0 0 1px var(--sel-line); }
    \\  .c-cs .body { display: flex; flex-direction: column; gap: 3px; flex: 1; min-width: 0; }
    \\  .c-cs .name { display: flex; align-items: center; gap: 6px; min-width: 0; }
    \\  .c-cs .name > b { font-weight: var(--w-m); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    \\  .c-cs .fact { font-size: var(--fs-xs); color: var(--t2); }
    \\  .c-cs .fact[data-lean="good"], .c-cs .why[data-lean="good"] .c-chip { color: var(--hi2); }
    \\  .c-cs .fact[data-lean="bad"], .c-cs .why[data-lean="bad"] .c-chip { color: var(--lo2); }
    \\  .c-cs .fact[data-faint] { opacity: 0.6; }
    \\  .c-cs .chips { display: flex; gap: 4px; flex-wrap: wrap; }
    \\  .c-cs .win { display: flex; flex-direction: column; align-items: flex-end; flex: none;
    \\    font-weight: var(--w-b); font-variant-numeric: tabular-nums; color: var(--c, var(--text)); }
    \\  .c-cs .win > small { font-size: var(--fs-xs); font-weight: var(--w-r); color: var(--faint); }
    \\  .c-cs .bans[data-turn] h3 { color: var(--turn); }
    \\}
    \\
;

const demo = champ.demo;

pub const sample: Screen = .{
    .board = draftboard.sample,
    .lane = .{
        .role = .mid,
        .me = demo("Ahri", "Ahri"),
        .them = demo("Syndra", "Syndra"),
        .guessed = true,
        .mode = .counter,
        .sentence = "Ahri usually trails Syndra by about 150 gold at 14 minutes, though 8 games in 10 land between -900 and +700.",
        .chart = .{
            .a = "Ahri",
            .b = "Syndra",
            .band = &.{ .{ 0, 0 }, .{ -40, 30 }, .{ -90, 60 }, .{ -140, 90 }, .{ -190, 110 }, .{ -240, 140 }, .{ -290, 160 }, .{ -340, 190 }, .{ -390, 210 }, .{ -440, 240 }, .{ -480, 260 }, .{ -530, 280 }, .{ -570, 300 }, .{ -610, 320 }, .{ -650, 340 }, .{ -690, 360 } },
            .line = &.{ 0, -5, -15, -25, -40, -50, -60, -75, -85, -95, -105, -115, -125, -135, -150, -160 },
        },
        .caption = "Gold, you minus them: the line is the average, the band the middle half of 1,204 games (All games, EUW, last 30 days).",
        .options = &.{
            .{
                .champ = demo("Ahri", "Ahri"),
                .current = true,
                .lane = "-150 gold at 14 min vs Syndra",
                .lean = .bad,
                .reasons = &.{ .{ .text = "your most played" }, .{ .text = "magic damage, your team needs it", .lean = .good } },
            },
            .{
                .champ = demo("Galio", "Galio"),
                .lane = "+210 gold at 14 min vs Syndra",
                .lean = .good,
                .reasons = &.{ .{ .text = "120k mastery" }, .{ .text = "strong in mid now", .lean = .good } },
            },
            .{
                .champ = demo("Viktor", "Viktor"),
                .lane = "about even at 14 min vs Syndra",
                .faint = true,
                .reasons = &.{.{ .text = "few games in this matchup", .lean = .bad }},
            },
        },
        .mastery = true,
        .scope = "EUW, last 30 days",
    },
};

/// The tester's numbers beside the public words
fn private(h: *H, s: Screen) Screen {
    var p = s;
    p.draft = 53.4;
    const opts = h.mem.dupe(Option, s.lane.options) catch {
        h.oom = true;
        return s;
    };
    for (opts, [_]f32{ 52.1, 54.0, 50.6 }) |*o, w| o.win = w;
    p.lane.options = opts;
    return p;
}

fn chartState(h: *H) ?*lanechart.Held {
    const x = h.mem.create(lanechart.Held) catch {
        h.oom = true;
        return null;
    };
    x.* = .{};
    return x;
}

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.addFill("counter, public", view(h, sample, chartState(h), null));
    g.addFill("counter, private", view(h, private(h, sample), chartState(h), null));
    var done = sample;
    done.lane.mode = .locked;
    done.comp = compview.sample;
    g.addFill("all locked, comp", view(h, done, chartState(h), null));
    g.addFill("your ban, blind", view(h, .{
        .board = .{ .lanes = draftboard.sample.lanes[0..5], .bans_them = draftboard.sample.bans_them },
        .banning = true,
        .ban_options = &.{
            .{ .champ = demo("Yasuo", "Yasuo"), .role = .mid, .mine = true, .why = "wins often and is picked a lot in mid" },
            .{ .champ = demo("Smolder", "Smolder"), .role = .bot, .why = "wins often and is picked a lot in bot" },
        },
        .lane = .{ .role = .mid, .options = sample.lane.options[1..], .mastery = false, .scope = "EUW, last 30 days" },
    }, null, null));
}
