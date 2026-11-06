//! LoadScreen: the desktop app while the game loads. A column per lane: our card, the
//! lane strip (gold at 14 from even, who reaches level 6 and the first item sooner), their
//! card. A card is as tall as what it says: the portrait beside name and role (? when
//! guessed), then the champion's win rate in the role (private edition only), wins by
//! game length as a spark with its word where the tilt is clear, and at most two pills
//! coloured by meaning. Above, "your game": my lane and the enemy jungler and team in
//! plain words. Narrow windows get one row per lane. The private edition adds a line
//! about each other player from the client: rank, "main" or "first game", their recent
//! Rift games on the pick (docs/plan/app.md Policy line); never names
//! (research/questions/desktop-app-layout.md C1-C3)
const tree = @import("tree.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const phrase = @import("phrase.zig");
const bar = @import("bar.zig");
const spark = @import("spark.zig");
const rate = @import("rate.zig");
const toggletip = @import("toggletip.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const Phrase = phrase.Phrase;
const H = tree.H;
const N = tree.N;

pub const name = "LoadScreen";
pub const scope = .{".c-load"};

pub const Tone = enum { none, good, bad, caution };

pub const Pill = struct { text: []const u8, tone: Tone = .none };

pub const Card = struct {
    champ: ?champ.Champ,
    role: ?role.Role,
    guessed: bool = false,
    you: bool = false,
    /// Private edition: the champion's win rate in the role
    rate: ?rate.Rate = null,
    pills: []const Pill = &.{},
    /// Win % by game length, shortest first (champfacts.length_edges): the spark
    lengths: []const f32 = &.{},
    /// Wins more in long games (true) or short; null: the tilt is inside its noise, so
    /// no spark
    long: ?bool = null,
    /// Private edition, other players only
    player: ?Player = null,
};

/// Each part empty when unknown
pub const Player = struct {
    /// "Emerald II"
    rank: []const u8 = "",
    /// "Leona main", "first Leona game"; empty between
    mastery: []const u8 = "",
    /// Their Summoner's Rift games of the last 20 ("7 won of 12 on Leona", then "in last
    /// 17 games"; "no Leona"); 0: no games part
    games: u32 = 0,
    on_pick: u32 = 0,
    /// Null: too few on the pick for a win count, so faint
    won: ?u32 = null,
};

pub const Side = bar.Side;

/// Our lane against theirs: gold at lane_minute, ours minus theirs
pub const Strip = struct {
    gold: i32,
    /// The leader, .even inside the noise (2 standard errors)
    lead: Side,
    /// "+664" private, "ahead" public
    text: []const u8,
    /// Who reaches level 6 and the first item sooner; null: about the same or unknown
    level6: ?Side = null,
    item: ?Side = null,
    /// The whole strip in words, for screen readers
    label: []const u8 = "",
};

pub const Lane = struct {
    us: ?Card = null,
    them: ?Card = null,
    strip: ?Strip = null,
};

/// A line of "your game": a champion or a team, a word about it
pub const Fact = struct {
    champ: ?champ.Champ = null,
    /// Without a champion: whose it is ("Enemy team")
    who: []const u8 = "",
    text: []const u8,
    tone: Tone = .none,
};

pub const Screen = struct {
    /// Top to support, then seats without a role
    lanes: []const Lane,
    /// Private edition: our team's draft win chance in %
    draft: ?f32 = null,
    yours: []const Fact = &.{},
};

const TeamSide = enum { us, them };

/// Gold at which the strip's fill reaches its end
pub const gold_end = 1000;

pub fn view(h: *H, s: Screen) N {
    var lanes = h.list();
    for (s.lanes, 0..) |l, i| lanes.add(lane(h, i, l));
    return h.div(.{ .class = "c-load" }, .{
        yours(h, s.yours),
        h.div(.{ .class = "teams" }, .{
            head(h, .us, s.draft),
            h.el(.ol, .{ .class = "lanes" }, .{lanes.done()}),
            head(h, .them, if (s.draft) |d| 100 - d else null),
        }),
    });
}

fn yours(h: *H, facts: []const Fact) N {
    if (facts.len == 0) return .none;
    var l = h.list();
    for (facts, 0..) |f, i| l.add(h.li(.{ .key = i }, .{
        if (f.champ) |c| champ.view(h, c, .{ .px = .@"24", .named = false }) else h.b(.{}, .{f.who}),
        h.span(.{ .data_tone = if (f.tone == .none) null else f.tone }, .{f.text}),
    }));
    return h.section(.{ .class = "yours" }, .{
        h.h2(.{}, .{W.yours}),
        h.ul(.{}, .{l.done()}),
    });
}

fn head(h: *H, side: TeamSide, draft: ?f32) N {
    return h.h2(.{ .data_side = side }, .{
        if (side == .us) W.us else W.them,
        if (draft) |d| h.span(.{ .class = "draft" }, .{ rate.view(h, .estimate(d), .{ .said = "win chance" }), h.small(.{}, .{W.draft}) }) else null,
    });
}

fn lane(h: *H, i: usize, l: Lane) N {
    return h.li(.{ .key = i }, .{
        if (l.us) |c| card(h, i, c, .us) else h.div(.{ .class = "card", .data_empty = true }, .{W.none}),
        strip(h, l),
        if (l.them) |c| card(h, i, c, .them) else h.div(.{ .class = "card", .data_empty = true }, .{W.none}),
    });
}

fn strip(h: *H, l: Lane) N {
    const s = l.strip orelse return h.div(.{ .class = "strip" }, .{
        if (l.us != null and l.them != null and l.us.?.role != null) h.small(.{}, .{W.no_lane}) else null,
    });
    const x = @max(-gold_end, @min(gold_end, s.gold));
    const at = 0.5 + @as(f64, @floatFromInt(x)) / (2 * gold_end);
    return h.div(.{ .class = "strip" }, .{
        bar.track(h, .{ .at = at, .ref = 0.5, .side = s.lead, .text = .{ .s = s.text }, .label = .{ .s = s.label } }),
        if (s.level6 != null or s.item != null) h.span(.{ .class = "ticks", .aria_hidden = true }, .{
            if (s.level6) |w| h.span(.{ .data_side = w }, .{if (w == .us) W.six_first else W.six_later}) else null,
            if (s.item) |w| h.span(.{ .data_side = w }, .{if (w == .us) W.items_first else W.slow_items}) else null,
        }) else null,
    });
}

fn card(h: *H, i: usize, c: Card, side: TeamSide) N {
    var pills = h.list();
    for (c.pills, 0..) |p, j| pills.add(h.span(.{ .key = j, .class = "pill", .data_tone = if (p.tone == .none) null else p.tone }, .{p.text}));
    return h.div(.{ .class = "card", .data_side = side, .data_you = c.you }, .{
        champ.view(h, c.champ, .{ .px = .@"48", .side = if (side == .us) .us else .them, .you = c.you, .named = false, .label = W.unknown }),
        h.div(.{ .class = "body" }, .{
            h.b(.{}, .{if (c.champ) |x| x.name else W.unknown.s}),
            h.span(.{ .class = "role" }, .{
                if (c.role) |r| role.view(h, r, .{ .s = .s, .named = false }) else null,
                if (c.role) |r| r.label() else W.no_role,
                if (c.guessed) W.guess else null,
            }),
            if (c.rate) |r| h.span(.{ .class = "fact" }, .{rate.view(h, r, .{})}) else null,
            if (c.player) |p| player(h, i, side, if (c.champ) |ch| ch.name else "", p) else null,
            if (c.long) |l| h.span(.{ .class = "len" }, .{
                spark.view(h, .{ .vs = c.lengths, .y = spark_y, .mid = 50, .w = 64, .h = 18 }),
                if (l) W.long else W.short,
            }) else null,
            if (c.pills.len > 0) h.span(.{ .class = "pills" }, .{pills.done()}) else null,
        }),
    });
}

fn player(h: *H, i: usize, side: TeamSide, pick: []const u8, p: Player) N {
    const sep = W.sep;
    const id = switch (side) {
        .us => games_ids[0][i],
        .them => games_ids[1][i],
    };
    const games = p.games > 0;
    const last: [2]N = if (games) toggletip.view(h, id, .{W.last.with(h, .{ .n = p.games })}, W.games, W.games_note) else .{ .none, .none };
    // The win count is the figure; without one (under 5 on the pick) it's faint. The
    // window ("in last 18 games") its own faint line, so neither wraps in a narrow card
    const count: N = if (!games) .none else if (p.on_pick == 0)
        h.span(.{ .data_thin = true }, .{W.none_of.with(h, .{ .c = pick })})
    else if (p.won) |w|
        h.span(.{}, .{ h.b(.{}, .{W.won.with(h, .{ .n = w })}), W.of_on.with(h, .{ .n = p.on_pick, .c = pick }) })
    else
        h.span(.{ .data_thin = true }, .{if (p.on_pick == 1) W.one_on.with(h, .{ .c = pick }) else W.on.with(h, .{ .n = p.on_pick, .c = pick })});
    const window: N = if (games) h.span(.{ .data_thin = true }, .{ W.within, last[0], W.games_after }) else .none;
    const known = p.rank.len > 0 or p.mastery.len > 0;
    return h.div(.{ .class = "who" }, .{
        if (known) h.span(.{}, .{
            if (p.rank.len > 0) h.b(.{}, .{p.rank}) else null,
            if (p.rank.len > 0 and p.mastery.len > 0) sep else null,
            if (p.mastery.len > 0) p.mastery else null,
        }) else null,
        count,
        window,
        last[1],
    });
}

const games_ids = [2][5][]const u8{
    .{ "ls-games-0-us", "ls-games-1-us", "ls-games-2-us", "ls-games-3-us", "ls-games-4-us" },
    .{ "ls-games-0-them", "ls-games-1-them", "ls-games-2-them", "ls-games-3-them", "ls-games-4-them" },
};

/// About its own average, shrunk to even, a champion's win % by length rarely moves 5
/// points either way
const spark_y: @import("chart.zig").Scale = .{ .lo = 44, .hi = 56 };

const W = struct {
    const yours = plain("Your game");
    const us = plain("Your team");
    const them = plain("Enemy team");
    const draft = plain("draft");
    const long = plain("wins long");
    const short = plain("wins short");
    const unknown = plain("Unknown");
    const no_role = plain("Role unknown");
    const guess = plain("?");
    const none = plain("No one here");
    const no_lane = plain("Too few games of this lane");
    const six_first = plain("6 first");
    const six_later = plain("6 later");
    const items_first = plain("items first");
    const slow_items = plain("slow items");
    const sep = plain(" · ");
    const games = plain("Recent games");
    const won = Phrase("{n:count} won");
    const of_on = Phrase(" of {n:count} on {c:text}");
    const one_on = Phrase("1 game on {c:text}");
    const on = Phrase("{n:count} games on {c:text}");
    const none_of = Phrase("no {c:text}");
    const within = plain("in ");
    const last = Phrase("last {n:count}");
    const games_after = plain(" games");
    const games_note = plain("Their Summoner's Rift games among the last 20 in their match history: ARAM, Arena and other modes left out. Wins show from 5 games on the champion.");
};

pub const css =
    \\@layer components {
    \\  .c-load { display: flex; flex-direction: column; gap: var(--sp-2); min-width: 0; width: 100%; max-width: 1280px;
    \\    margin: 0 auto; }
    \\  .c-load h2 { display: flex; align-items: baseline; gap: var(--sp-2); margin: 0; padding-bottom: 4px;
    \\    border-bottom: 3px solid currentColor; font-size: var(--fs-m); font-weight: var(--w-b); }
    \\  .c-load h2[data-side="us"] { color: var(--us); }
    \\  .c-load h2[data-side="them"] { color: var(--them); }
    \\  .c-load .draft { display: inline-flex; align-items: baseline; gap: 4px; margin-left: auto; font-size: var(--fs-l);
    \\    color: var(--text); }
    \\  .c-load .draft > small { font-size: var(--fs-s); color: var(--muted); }
    \\  .c-load .yours { display: flex; align-items: center; flex-wrap: wrap; gap: var(--sp-2) var(--sp-3); }
    \\  .c-load .yours > h2 { padding: 0; border: 0; font-size: var(--fs-s); color: var(--muted); }
    \\  .c-load .yours > ul { list-style: none; margin: 0; padding: 0; display: flex; flex-wrap: wrap; gap: var(--sp-2) var(--sp-3); }
    \\  .c-load .yours li { display: flex; align-items: center; gap: 6px; font-size: var(--fs-s); }
    \\  .c-load .yours li > b { font-weight: var(--w-m); color: var(--muted); }
    \\  .c-load .teams { display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 6px var(--sp-2); }
    \\  .c-load .teams > h2 { grid-column: 1 / -1; }
    \\  .c-load .teams > h2[data-side="them"] { grid-row: 4; }
    \\  .c-load .lanes { list-style: none; margin: 0; padding: 0; display: contents; }
    \\  .c-load .lanes > li { display: grid; grid-row: 2 / span 4; grid-column: 1; grid-template-rows: subgrid; gap: 6px; min-width: 0; }
    \\  .c-load .lanes > li > :last-child { grid-row: 4; }
    \\  .c-load .lanes > li:nth-child(5n+2) { grid-column: 2; }
    \\  .c-load .lanes > li:nth-child(5n+3) { grid-column: 3; }
    \\  .c-load .lanes > li:nth-child(5n+4) { grid-column: 4; }
    \\  .c-load .lanes > li:nth-child(5n) { grid-column: 5; }
    \\  .c-load .lanes > li:nth-child(n+6) { grid-row: 6 / span 4; }
    \\  .c-load .card { display: grid; grid-template-columns: auto minmax(0, 1fr); align-content: start; align-items: start;
    \\    gap: 3px var(--sp-2); min-width: 0; padding: var(--sp-2); border-radius: var(--r-m); background: var(--panel-2); }
    \\  .c-load .card > .c-champ { grid-row: span 3; }
    \\  .c-load .card[data-you] { box-shadow: inset 0 0 0 2px var(--us); }
    \\  .c-load .card[data-empty] { display: flex; align-items: center; justify-content: center; background: none; box-shadow: inset 0 0 0 1px var(--line);
    \\    font-size: var(--fs-xs); color: var(--faint); }
    \\  .c-load .body { display: contents; }
    \\  .c-load .body > * { grid-column: 2; justify-self: start; max-width: 100%; }
    \\  .c-load .body > b { font-size: var(--fs-m); font-weight: var(--w-b); overflow: hidden; text-overflow: ellipsis;
    \\    white-space: nowrap; max-width: 100%; }
    \\  .c-load .role { display: inline-flex; align-items: center; gap: 4px; font-size: var(--fs-xs); color: var(--muted); }
    \\  .c-load .fact { font-size: var(--fs-m); font-weight: var(--w-b); }
    \\  .c-load .body > .who { grid-column: 1 / -1; justify-self: stretch; order: 1; display: flex; flex-direction: column; gap: 2px;
    \\    margin-top: 4px; padding-top: var(--sp-2); border-top: 1px solid var(--line); font-size: var(--fs-s); color: var(--t2); }
    \\  .c-load .who b { font-weight: var(--w-b); color: var(--text); }
    \\  .c-load .who [data-thin] { color: var(--faint); }
    \\  .c-load .len { display: inline-flex; align-items: center; gap: 4px; font-size: var(--fs-xs); color: var(--t2); }
    \\  .c-load .pills { display: flex; flex-wrap: wrap; gap: 4px; }
    \\  .c-load .pill { padding: 1px 6px; border-radius: var(--r-s); font-size: var(--fs-xs); background: var(--wash); color: var(--t2); }
    \\  .c-load [data-tone="good"] { color: var(--hi2); }
    \\  .c-load [data-tone="bad"] { color: var(--lo2); }
    \\  .c-load [data-tone="caution"] { color: var(--turn); }
    \\  .c-load .strip { display: flex; flex-direction: column; justify-content: flex-start; gap: 2px; min-width: 0; min-height: 28px; }
    \\  .c-load .strip > small { font-size: var(--fs-xs); color: var(--faint); text-align: center; }
    \\  .c-load .ticks { display: flex; justify-content: center; gap: var(--sp-2); font-size: var(--fs-xs); }
    \\  .c-load .ticks > [data-side="us"] { color: var(--us-hot); }
    \\  .c-load .ticks > [data-side="them"] { color: var(--them-hot); }
    \\  @container (max-width: 760px) {
    \\    .c-load .teams { grid-template-columns: repeat(2, minmax(0, 1fr)); row-gap: var(--sp-3); }
    \\    .c-load .teams > h2, .c-load .teams > h2[data-side="them"] { grid-column: auto; grid-row: 1; flex-wrap: wrap; }
    \\    .c-load .lanes { display: grid; grid-column: 1 / -1; gap: var(--sp-3); }
    \\    .c-load .lanes > li, .c-load .lanes > li:nth-child(n) { grid-row: auto; grid-column: auto; grid-template-rows: none;
    \\      grid-template-columns: repeat(2, minmax(0, 1fr)); }
    \\    .c-load .lanes > li > :last-child { grid-row: auto; }
    \\    .c-load .strip { grid-column: 1 / -1; grid-row: 2; }
    \\    .c-load .body > .len, .c-load .body > .pills { grid-column: 1 / -1; }
    \\  }
    \\}
    \\
;

const demo = champ.demo;

const short: []const f32 = &.{ 52.9, 51.6, 50.1, 48.6, 46.8 };
const long: []const f32 = &.{ 46.6, 48.4, 50.2, 51.8, 53.0 };
const flat: []const f32 = &.{ 49.8, 50.4, 49.7, 50.3, 49.8 };

pub const sample: Screen = .{
    .yours = &.{
        .{ .champ = demo("Ahri", "Ahri"), .text = "Tough lane vs Syndra", .tone = .bad },
        .{ .champ = demo("Vi", "Vi"), .text = "Their Vi strong early" },
        .{ .who = "Enemy team", .text = "strong late" },
    },
    .lanes = &.{
        .{
            .us = .{ .champ = demo("Garen", "Garen"), .role = .top, .lengths = short, .long = false, .pills = &.{.{ .text = "strong now", .tone = .good }} },
            .them = .{ .champ = demo("Darius", "Darius"), .role = .top, .guessed = true, .lengths = short, .long = false },
            .strip = .{ .gold = 410, .lead = .us, .text = "ahead", .level6 = .us, .label = "Garen ahead in lane, level 6 first" },
        },
        .{
            .us = .{ .champ = demo("LeeSin", "Lee Sin"), .role = .jungle, .lengths = short, .long = false },
            .them = .{ .champ = demo("Vi", "Vi"), .role = .jungle, .guessed = true, .lengths = flat, .pills = &.{.{ .text = "weak now", .tone = .bad }} },
            .strip = .{ .gold = 60, .lead = .even, .text = "even", .item = .them, .label = "Lee Sin even early, slow items" },
        },
        .{
            .us = .{ .champ = demo("Ahri", "Ahri"), .role = .mid, .you = true, .lengths = flat, .pills = &.{.{ .text = "weak now", .tone = .bad }} },
            .them = .{ .champ = demo("Syndra", "Syndra"), .role = .mid, .guessed = true, .lengths = long, .long = true },
            .strip = .{ .gold = -520, .lead = .them, .text = "behind", .level6 = .them, .item = .them, .label = "Ahri behind in lane, level 6 later, slow items" },
        },
        .{
            .us = .{ .champ = demo("Jinx", "Jinx"), .role = .bot, .lengths = long, .long = true },
            .them = .{ .champ = demo("Caitlyn", "Caitlyn"), .role = .bot, .guessed = true, .lengths = short, .long = false },
        },
        .{
            .us = .{ .champ = demo("Lulu", "Lulu"), .role = .support, .lengths = long, .long = true },
        },
    },
};

/// The tester's numbers beside the public words
fn private(h: *H, s: Screen) Screen {
    var p = s;
    p.draft = 53.4;
    const yrs = h.mem.dupe(Fact, s.yours) catch {
        h.oom = true;
        return s;
    };
    yrs[0].text = "−520 gold at 14 in lane";
    p.yours = yrs;
    const lanes = h.mem.dupe(Lane, s.lanes) catch {
        h.oom = true;
        return s;
    };
    const rates = [_]rate.Rate{ .at(41_200, 52.8), .at(88_000, 50.1), .at(120_400, 49.2), .at(210, 48.6), .at(35_100, 51.0) };
    const all = [_][]const Pill{ &.{}, &.{.{ .text = "ban magnet" }}, &.{ .{ .text = "weak now", .tone = .bad }, .{ .text = "lone AP" } }, &.{.{ .text = "hipster pick", .tone = .caution }}, &.{} };
    for (lanes, rates, all) |*l, r, j| {
        if (l.us) |*c| {
            c.rate = r;
            if (j.len > 0) c.pills = j;
        }
        if (l.strip) |*x| x.text = switch (x.lead) {
            .us => "+410",
            .even => "+60",
            .them => "−520",
        };
    }
    // Lulu's player is in streamer mode: no line
    const us = [_]?Player{
        .{ .rank = "Silver I", .games = 17, .on_pick = 7, .won = 3 },
        .{ .rank = "Diamond IV", .games = 18, .on_pick = 1 },
        null,
        .{ .games = 19 },
        null,
    };
    const them = [_]?Player{
        .{ .rank = "Gold II", .mastery = "Darius main", .games = 20, .on_pick = 12, .won = 7 },
        .{ .rank = "Platinum IV", .games = 18, .on_pick = 3 },
        .{ .rank = "Emerald III", .mastery = "Syndra main", .games = 20, .on_pick = 15, .won = 9 },
        .{ .rank = "Platinum II", .mastery = "first Caitlyn game" },
        null,
    };
    for (lanes, us, them) |*l, u, t| {
        if (l.us) |*c| if (!c.you) {
            c.player = u;
        };
        if (l.them) |*c| c.player = t;
    }
    p.lanes = lanes;
    return p;
}

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.addFill("public: bot with too few games of the lane, no enemy support yet", view(h, sample));
    g.addFill("private: numbers, every pill, a line about each other player (Lulu's in streamer mode)", view(h, private(h, sample)));
}
