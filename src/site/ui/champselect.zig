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
const draftboard = @import("draftboard.zig");
const rate = @import("rate.zig");
const lanechart = @import("lane.zig");
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
    /// Beside the ban head, said once for every row: the figure's unit (private) or the
    /// reason they share (public)
    ban_note: []const u8 = "",
    /// Private edition: your team's draft win chance in %
    draft: ?f32 = null,
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
    /// The matchup as a figure ("-150"), gold at the lane minute, shown in place of the
    /// sentence, which is then its title; "" for none
    fig: []const u8 = "",
    lean: Lean = .none,
    /// Few games behind the sentence
    thin: bool = false,
    /// The matchup's gold by minute (band and line, no `you`) and what it shows
    chart: ?lanechart.Figures = null,
    caption: []const u8 = "",
    options: []const Option = &.{},
    /// Options weigh your mastery points (the settings toggle); null: an ally's lane (a click
    /// on their seat), `me` theirs, without a pool to weigh; once they lock (mode locked)
    /// the matchup only
    mastery: ?bool = null,
    /// That seat is an enemy's: `them` is ours, options what they could pick into us
    enemy: bool = false,
    /// "EUW, last 30 days"
    scope: []const u8 = "",

    /// Nothing rates a teammate's pick (docs/production-key.md): their lane once they
    /// lock is the matchup only
    pub fn rated(l: Lane) bool {
        return !(l.mastery == null and l.mode == .locked);
    }

    /// No options: no head either, nothing stands in for them
    pub fn listed(l: Lane) bool {
        return l.rated() and l.options.len > 0;
    }
};

pub const Option = struct {
    champ: champ.Champ,
    /// Your hover or lock
    current: bool = false,
    /// Private edition: your team's win chance with it, in %
    win: ?f32 = null,
    /// "+120 gold at 14"; "" without an opponent or curves
    lane: []const u8 = "",
    lean: Lean = .none,
    /// Few games behind the lane fact: fainter
    faint: bool = false,
    reasons: []const Reason = &.{},
    /// Practice's click (ui/practice.zig Act); "" for none
    act: []const u8 = "",
};

pub const Reason = struct {
    text: []const u8,
    lean: Lean = .none,
    /// Drawn as a picture, `text` then its title: the champion it is about (with, into)
    /// or the role (strong in)
    champ: ?champ.Champ = null,
    role: ?role.Role = null,
    /// Private edition: the signed points ("+1.4"); "" an arrow by `lean`
    fig: []const u8 = "",
    /// On hover in place of `text`: the words with the size or points
    tip: []const u8 = "",
};

/// A reason chip: the champion or role and its figure, else the words
pub fn effect(h: *H, r: Reason) N {
    const pic: ?N = if (r.champ) |c| champ.view(h, c, .{ .px = .@"20", .named = false }) else if (r.role) |x| role.view(h, x, .{ .s = .s }) else null;
    if (pic == null) return chip.view(h, .{ .v = .reason }, .{r.text});
    const fig: []const u8 = if (r.fig.len > 0) r.fig else switch (r.lean) {
        .good => "▲",
        .bad => "▼",
        .none => "",
    };
    return chip.view(h, .{ .v = .reason, .tip = if (r.tip.len > 0) r.tip else r.text }, .{ pic, h.b(.{}, .{fig}) });
}

pub const BanOption = struct {
    champ: champ.Champ,
    role: role.Role,
    /// Your lane opponent's role
    mine: bool = false,
    /// Private edition: the one figure (wins above the role per 10k games), its unit in
    /// Screen.ban_note; "" leaves the order to carry it
    fig: []const u8 = "",
    lean: Lean = .none,
    /// The ally's champion it beats in their lane
    beats: ?Reason = null,
    /// Practice's click (ui/practice.zig Act); "" for none
    act: []const u8 = "",
};

/// `held`: the island's chart state; null draws no chart
pub fn view(h: *H, s: Screen, held: ?*lanechart.Held) N {
    const bans = banOptions(h, s);
    var b = s.board;
    b.draft = s.draft;
    return h.div(.{ .class = "c-cs" }, .{
        card.view(h, .{}, &.{draftboard.view(h, b)}),
        h.div(.{ .class = "side" }, .{
            bans,
            lane(h, s.lane, held),
        }),
    });
}

fn lane(h: *H, l: Lane, held: ?*lanechart.Held) N {
    const ally = l.mastery == null;
    const rated = l.rated();
    const listed = l.listed();
    var opts = h.list();
    for (l.options, 0..) |o, i| opts.add(option(h, i, o, l.mode == .locked));
    return h.section(.{ .class = "lane" }, .{
        h.div(.{ .class = "vs" }, .{
            champ.view(h, l.me, .{ .px = .@"56", .you = !ally, .named = false, .label = W.no_pick }),
            h.div(.{ .class = "who" }, .{
                h.h2(.{}, .{
                    if (l.me) |m| m.name else W.no_pick.s,
                    if (l.them) |t| h.span(.{ .class = "them" }, .{ W.vs, t.name, if (l.guessed) W.guess else null }) else null,
                }),
                h.span(.{ .class = "tags" }, .{
                    badge.view(h, .us, .{role.Role.label(l.role)}),
                    if (ally) badge.view(h, if (l.enemy) .them else .neutral, .{if (l.enemy) W.enemy else W.ally}) else null,
                }),
            }),
            if (l.fig.len > 0) h.span(.{ .class = "fig", .data_lean = if (l.lean == .none) null else l.lean, .data_thin = l.thin, .title = l.sentence }, .{
                h.b(.{}, .{l.fig}),
                h.small(.{}, .{W.gold_at}),
            }) else null,
            if (l.them) |t| champ.view(h, t, .{ .px = .@"48", .side = .them, .state = if (l.guessed) .thin else .normal }) else null,
        }),
        if (l.sentence.len > 0 and l.fig.len == 0) h.p(.{ .class = "say", .data_thin = l.thin }, .{l.sentence}) else null,
        if (l.chart) |c| if (held) |x| x.at(c, W.gold).view(h) else null else null,
        if (l.chart != null and l.caption.len > 0) h.p(.{ .class = "scope" }, .{l.caption}) else null,
        if (!rated and l.them == null) h.p(.{ .class = "say" }, .{W.no_them}) else null,
        h.div(.{ .class = "opts-head" }, .{
            if (listed) h.h3(.{}, .{switch (l.mode) {
                .blind => W.head_blind,
                .counter => W.head_counter,
                .locked => W.head_locked,
            }}) else null,
            // bridge.js sends the act: no handler in ui-app.wasm
            if (ally) h.button(.{ .class = "c-btn", .type = "button", .data_s = "s", .data_act = "lane 255" }, .{W.own}) else null,
        }),
        if (listed) h.el(.ol, .{ .class = "opts" }, .{opts.done()}) else null,
        // With no list the chart stays under Options, and its caption names the scope
        if (l.scope.len > 0 and (listed or l.chart == null or l.caption.len == 0)) h.p(.{ .class = "scope" }, .{l.scope}) else null,
    });
}

fn option(h: *H, i: usize, o: Option, locked: bool) N {
    var chips = h.list();
    for (o.reasons, 0..) |r, j| chips.add(h.span(.{ .key = j, .class = "why", .data_lean = if (r.lean == .none) null else r.lean }, .{
        effect(h, r),
    }));
    return h.li(.{ .key = i, .data_current = o.current, .data_act = if (o.act.len > 0) o.act else null }, .{
        champ.view(h, o.champ, .{ .px = .@"48", .named = false }),
        h.div(.{ .class = "body" }, .{
            h.div(.{ .class = "name" }, .{
                h.b(.{}, .{o.champ.name}),
                if (o.current) badge.view(h, .accent, .{if (locked) W.locked_in else W.hovering}) else null,
            }),
            if (o.lane.len > 0) h.span(.{ .class = "fact", .data_lean = if (o.lean == .none) null else o.lean, .data_faint = o.faint }, .{o.lane}) else null,
            if (o.reasons.len > 0) h.span(.{ .class = "chips" }, .{chips.done()}) else null,
        }),
        if (o.win) |w| h.span(.{ .class = "win" }, .{
            rate.view(h, .estimate(w), .{ .said = "" }),
            h.small(.{}, .{W.team_win}),
        }) else null,
    });
}

fn banOptions(h: *H, s: Screen) ?N {
    if (s.ban_options.len == 0) return null;
    var rows = h.list();
    for (s.ban_options, 0..) |o, i| rows.add(h.li(.{ .key = i, .data_act = if (o.act.len > 0) o.act else null }, .{
        champ.view(h, o.champ, .{ .px = .@"40", .named = false }),
        h.div(.{ .class = "body" }, .{
            h.div(.{ .class = "name" }, .{
                h.b(.{}, .{o.champ.name}),
                role.view(h, o.role, .{ .s = .s }),
                if (o.mine) badge.view(h, .us, .{W.your_lane}) else null,
                if (o.beats) |r| effect(h, r) else null,
            }),
        }),
        if (o.fig.len > 0) h.b(.{ .class = "bfig", .data_lean = if (o.lean == .none) null else o.lean }, .{o.fig}) else null,
    }));
    return h.section(.{ .class = "bans", .data_turn = s.banning }, .{
        h.div(.{ .class = "opts-head" }, .{
            h.h3(.{}, .{if (s.banning) W.ban_now else W.ban_options}),
            if (s.ban_note.len > 0) h.small(.{}, .{s.ban_note}) else null,
        }),
        h.el(.ol, .{ .class = "opts" }, .{rows.done()}),
    });
}

const W = struct {
    const team_win = plain("team win");
    const no_pick = plain("No pick yet");
    const gold = plain("Gold");
    const gold_at = plain("gold at 14");
    const vs = plain(" vs ");
    const guess = plain("?");
    const locked_in = plain("locked");
    const hovering = plain("hovering");
    const head_blind = plain("Options that hold up blind");
    const head_counter = plain("Options into them");
    const head_locked = plain("Other options");
    const ally = plain("Ally");
    const enemy = plain("Enemy");
    const own = plain("Your lane");
    const no_them = plain("The matchup shows once both sides pick this lane.");
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
    \\  .c-cs section { display: flex; flex-direction: column; gap: var(--sp-2); min-width: 0; }
    \\  /* The lane's head first, ban options under it: the lane's parts join the side column */
    \\  .c-cs > .side { gap: var(--sp-2); }
    \\  .c-cs > .side > .lane { display: contents; }
    \\  .c-cs > .side > .lane > :is(.vs, .vs + .say) { order: -1; }
    \\  .c-cs > .side > .bans { margin-block: var(--sp-2); }
    \\  .c-cs h2 { margin: 0; font-size: var(--fs-l); font-weight: var(--w-b); line-height: var(--lh-tight); }
    \\  .c-cs h2 .them { font-weight: var(--w-r); color: var(--t2); }
    \\  .c-cs h3 { margin: var(--sp-2) 0 0; font-size: var(--fs-s); font-weight: var(--w-m); color: var(--t2); }
    \\  .c-cs .vs { display: flex; align-items: center; gap: var(--sp-3); }
    \\  .c-cs .vs .who { display: flex; flex-direction: column; gap: 4px; flex: 1; min-width: 0; }
    \\  .c-cs .tags { display: flex; gap: 4px; flex-wrap: wrap; }
    \\  .c-cs .say { margin: 0; color: var(--text); }
    \\  .c-cs .vs .fig { display: flex; flex-direction: column; align-items: flex-end; flex: none; line-height: 1.1; }
    \\  .c-cs .vs .fig > b { font-size: var(--fs-xl); font-weight: var(--w-b); font-variant-numeric: tabular-nums; }
    \\  .c-cs .vs .fig > small { font-size: var(--fs-xs); color: var(--muted); }
    \\  .c-cs .fig[data-lean="good"] > b { color: var(--hi2); }
    \\  .c-cs .fig[data-lean="bad"] > b { color: var(--lo2); }
    \\  .c-cs .fig[data-thin] > b { opacity: 0.6; }
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
    \\  .c-cs .why .c-chip:has(> b) { gap: 4px; padding-left: 2px; }
    \\  .c-cs .why .c-chip > b { font-weight: var(--w-m); font-variant-numeric: tabular-nums; }
    \\  .c-cs .win { display: flex; flex-direction: column; align-items: flex-end; flex: none; }
    \\  .c-cs .win > .c-rate > .v { font-weight: var(--w-b); }
    \\  .c-cs .win > small { font-size: var(--fs-xs); font-weight: var(--w-r); color: var(--faint); }
    \\  .c-cs .bans[data-turn] h3 { color: var(--turn); }
    \\  .c-cs .bans .opts-head > small { font-size: var(--fs-xs); color: var(--faint); }
    \\  .c-cs .bans { max-width: 26rem; }
    \\  .c-cs .bans .opts > li { padding: var(--sp-1) var(--sp-2); }
    \\  .c-cs .bfig { flex: none; font-weight: var(--w-b); font-variant-numeric: tabular-nums; }
    \\  .c-cs .bfig[data-lean="good"] { color: var(--hi2); }
    \\  .c-cs .bfig[data-lean="bad"] { color: var(--lo2); }
    \\  .c-cs:has(.seat[data-you][data-turn]) .vs > .c-champ[data-you] { outline: 2px solid var(--turn); outline-offset: 2px; }
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
        .fig = "-150",
        .lean = .bad,
        .chart = .{
            .a = "Ahri",
            .b = "Syndra",
            .band = &.{ .{ 0, 0 }, .{ -40, 30 }, .{ -90, 60 }, .{ -140, 90 }, .{ -190, 110 }, .{ -240, 140 }, .{ -290, 160 }, .{ -340, 190 }, .{ -390, 210 }, .{ -440, 240 }, .{ -480, 260 }, .{ -530, 280 }, .{ -570, 300 }, .{ -610, 320 }, .{ -650, 340 }, .{ -690, 360 } },
            .line = &.{ 0, -5, -15, -25, -40, -50, -60, -75, -85, -95, -105, -115, -125, -135, -150, -160 },
        },
        .caption = "1,204 games, all ranks, EUW, last 30 days",
        .options = &.{
            .{
                .champ = demo("Ahri", "Ahri"),
                .current = true,
                .lane = "-150 gold at 14",
                .lean = .bad,
                .reasons = &.{ .{ .text = "your most played" }, .{ .text = "magic damage, your team needs it", .lean = .good } },
            },
            .{
                .champ = demo("Galio", "Galio"),
                .lane = "+210 gold at 14",
                .lean = .good,
                .reasons = &.{
                    .{ .text = "120k mastery points" },
                    .{ .text = "strong in mid now", .lean = .good, .role = .mid },
                    .{ .text = "pairs well with Darius", .lean = .good, .champ = demo("Darius", "Darius") },
                    .{ .text = "hard into Syndra", .lean = .bad, .champ = demo("Syndra", "Syndra") },
                },
            },
            .{
                .champ = demo("Viktor", "Viktor"),
                .lane = "even at 14",
                .faint = true,
                .reasons = &.{.{ .text = "few games in this matchup" }},
            },
        },
        .mastery = true,
        .scope = "EUW, last 30 days",
    },
};

/// The tester's numbers beside the public words
pub fn private(h: *H, s: Screen) Screen {
    var p = s;
    p.draft = 53.4;
    const opts = h.mem.dupe(Option, s.lane.options) catch {
        h.oom = true;
        return s;
    };
    for (opts, [_]f32{ 52.1, 54.0, 50.6 }) |*o, w| o.win = w;
    const rs = h.mem.dupe(Reason, opts[1].reasons) catch {
        h.oom = true;
        return s;
    };
    for (rs[1..], [_][]const u8{ "+0.9", "+1.4", "-1.1" }) |*r, f| r.fig = f;
    opts[1].reasons = rs;
    p.lane.options = opts;
    const lanes = h.mem.dupe(draftboard.Lane, s.board.lanes) catch {
        h.oom = true;
        return s;
    };
    lanes[0].us.fig = "52.3%";
    lanes[0].us.rate = 52.3;
    lanes[0].us.fact = "52.3% in top · 3,410 games";
    lanes[2].them.fig = "48.1%";
    lanes[2].them.rate = 48.1;
    lanes[2].them.fact = "48.1% in mid · 1,204 games";
    p.board.lanes = lanes;
    return p;
}

/// Top's seat clicked once they locked: their matchup only
fn allyLane(h: *H) Screen {
    var s = sample;
    const lanes = h.mem.dupe(draftboard.Lane, sample.board.lanes) catch {
        h.oom = true;
        return sample;
    };
    lanes[0].us.sel = true;
    s.board.lanes = lanes;
    s.lane = .{
        .role = .top,
        .me = lanes[0].us.champ,
        .them = lanes[0].them.champ,
        .mode = .locked,
        // No matchup curve: the sentence, no figure
        .sentence = "No top games of Garen against Darius in the last 30 days.",
        .scope = "EUW, last 30 days",
    };
    return s;
}

/// The enemy jungle's seat clicked before they pick: what they could pick into ours
fn enemyLane(h: *H) Screen {
    var s = sample;
    const lanes = h.mem.dupe(draftboard.Lane, sample.board.lanes) catch {
        h.oom = true;
        return sample;
    };
    lanes[1].them.sel = true;
    s.board.lanes = lanes;
    s.lane = .{
        .role = .jungle,
        .them = lanes[1].us.champ,
        .mode = .counter,
        .enemy = true,
        .options = sample.lane.options[1..],
        .scope = "EUW, last 30 days",
    };
    return s;
}

/// The enemy jungle locked in with ours still empty: no matchup yet
fn enemyAlone(h: *H) Screen {
    var s = sample;
    const lanes = h.mem.dupe(draftboard.Lane, sample.board.lanes) catch {
        h.oom = true;
        return sample;
    };
    // The sample's enemy jungle holds only a ban: it takes our jungler
    lanes[1].them = .{ .champ = lanes[1].us.champ, .state = .locked, .sel = true };
    lanes[1].us = .{};
    s.board.lanes = lanes;
    s.lane = .{ .role = .jungle, .me = lanes[1].them.champ, .mode = .locked, .enemy = true };
    return s;
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
    g.addFill("counter, public", view(h, sample, chartState(h)));
    g.addFill("counter, private", view(h, private(h, sample), chartState(h)));
    g.addFill("an ally's lane", view(h, allyLane(h), chartState(h)));
    g.addFill("an enemy's lane", view(h, enemyLane(h), chartState(h)));
    g.addFill("an enemy's lane, ours empty", view(h, enemyAlone(h), chartState(h)));
    g.addFill("your ban, blind", view(h, .{
        .board = .{ .lanes = draftboard.sample.lanes[0..5], .bans_them = draftboard.sample.bans_them },
        .banning = true,
        .ban_note = "wins per 10k games",
        .ban_options = &.{
            .{ .champ = demo("Yasuo", "Yasuo"), .role = .mid, .mine = true, .fig = "+31", .lean = .good },
            .{ .champ = demo("Smolder", "Smolder"), .role = .bot, .fig = "+26", .lean = .good },
            .{
                .champ = demo("Malphite", "Malphite"),
                .role = .top,
                .fig = "+20",
                .lean = .good,
                .beats = .{ .text = "beats Darius in lane", .lean = .good, .champ = demo("Darius", "Darius") },
            },
        },
        .lane = .{ .role = .mid, .options = sample.lane.options[1..], .mastery = false, .scope = "EUW, last 30 days" },
    }, null));
}
