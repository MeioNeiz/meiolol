//! LoadScreen: the desktop app while the game loads. A column per lane: our card, the
//! lane strip (gold at 14 from even, who reaches level 6 and the first item sooner), their
//! card. A card in one fixed order: portrait, name, role (? when guessed), how the
//! champion does in the role (private edition only), wins by game length as a spark,
//! then at most two pills coloured by meaning. Above, "your game": my lane and the enemy
//! jungler and team in a word each. Narrow windows get one row per lane. Champion facts
//! only: no player names or ranks (research/questions/desktop-app-layout.md C1-C3)
const tree = @import("tree.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const fmt = @import("fmt.zig");
const phrase = @import("phrase.zig");
const bar = @import("bar.zig");
const spark = @import("spark.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
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
    /// Private edition: "52.1% · 12k games"; "" otherwise
    fact: []const u8 = "",
    lean: Tone = .none,
    pills: []const Pill = &.{},
    /// Win % by game length, shortest first (champfacts.length_edges): the spark
    lengths: []const f32 = &.{},
    /// The spark in words, for screen readers
    lengths_label: []const u8 = "",
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
        head(h, .us, s.draft),
        h.el(.ol, .{ .class = "lanes" }, .{lanes.done()}),
        head(h, .them, if (s.draft) |d| 100 - d else null),
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
        if (draft) |d| h.span(.{ .class = "draft", .style = h.vars(.{ .c = fmt.wrColour(d / 100, 0.2) }) }, .{W.draft.with(h, .{ .p = @as(u32, @intFromFloat(fmt.round(d))) })}) else null,
    });
}

fn lane(h: *H, i: usize, l: Lane) N {
    return h.li(.{ .key = i }, .{
        if (l.us) |c| card(h, c, .us) else h.div(.{ .class = "card", .data_empty = true }, .{W.none}),
        strip(h, l),
        if (l.them) |c| card(h, c, .them) else h.div(.{ .class = "card", .data_empty = true }, .{W.none}),
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

fn card(h: *H, c: Card, side: TeamSide) N {
    var pills = h.list();
    for (c.pills, 0..) |p, j| pills.add(h.span(.{ .key = j, .class = "pill", .data_tone = if (p.tone == .none) null else p.tone }, .{p.text}));
    return h.div(.{ .class = "card", .data_side = side, .data_you = c.you }, .{
        champ.view(h, c.champ, .{ .px = .@"56", .side = if (side == .us) .us else .them, .you = c.you, .named = false, .label = W.unknown }),
        h.div(.{ .class = "body" }, .{
            h.b(.{}, .{if (c.champ) |x| x.name else W.unknown.s}),
            h.span(.{ .class = "role" }, .{
                if (c.role) |r| role.view(h, r, .{ .s = .s, .named = false }) else null,
                if (c.role) |r| r.label() else W.no_role,
                if (c.guessed) W.guess else null,
            }),
            if (c.fact.len > 0) h.span(.{ .class = "fact", .data_tone = if (c.lean == .none) null else c.lean }, .{c.fact}) else null,
            spark.view(h, .{ .vs = c.lengths, .y = spark_y, .mid = 50, .label = .{ .s = c.lengths_label }, .w = 80, .h = 20 }),
            if (c.pills.len > 0) h.span(.{ .class = "pills" }, .{pills.done()}) else null,
        }),
    });
}

/// About its own average, shrunk to even, a champion's win % by length rarely moves 5
/// points either way
const spark_y: @import("chart.zig").Scale = .{ .lo = 44, .hi = 56 };

const W = struct {
    const yours = plain("Your game");
    const us = plain("Your team");
    const them = plain("Enemy team");
    const draft = phrase.Phrase("{p:pct} draft");
    const unknown = plain("Unknown");
    const no_role = plain("Role unknown");
    const guess = plain("?");
    const none = plain("No one here");
    const no_lane = plain("Too few games of this lane");
    const six_first = plain("6 first");
    const six_later = plain("6 later");
    const items_first = plain("items first");
    const slow_items = plain("slow items");
};

pub const css =
    \\@layer components {
    \\  .c-load { display: flex; flex-direction: column; gap: var(--sp-2); min-width: 0; width: 100%; max-width: 1280px;
    \\    margin: 0 auto; }
    \\  .c-load h2 { display: flex; align-items: baseline; gap: var(--sp-2); margin: 0; padding-bottom: 4px;
    \\    border-bottom: 3px solid currentColor; font-size: var(--fs-m); font-weight: var(--w-b); }
    \\  .c-load h2[data-side="us"] { color: var(--us); }
    \\  .c-load h2[data-side="them"] { color: var(--them); padding: 4px 0 0; border-bottom: 0; border-top: 3px solid currentColor; }
    \\  .c-load .draft { margin-left: auto; font-size: var(--fs-l); color: var(--c, var(--text)); font-variant-numeric: tabular-nums; }
    \\  .c-load .yours { display: flex; align-items: center; flex-wrap: wrap; gap: var(--sp-2) var(--sp-3); }
    \\  .c-load .yours > h2 { padding: 0; border: 0; font-size: var(--fs-s); color: var(--muted); }
    \\  .c-load .yours > ul { list-style: none; margin: 0; padding: 0; display: flex; flex-wrap: wrap; gap: var(--sp-2) var(--sp-3); }
    \\  .c-load .yours li { display: flex; align-items: center; gap: 6px; font-size: var(--fs-s); }
    \\  .c-load .yours li > b { font-weight: var(--w-m); color: var(--muted); }
    \\  .c-load .lanes { list-style: none; margin: 0; padding: 0; display: grid; grid-template-columns: repeat(5, minmax(0, 1fr));
    \\    gap: 6px var(--sp-2); }
    \\  .c-load .lanes > li { display: grid; grid-row: span 3; grid-template-rows: subgrid; gap: 6px; min-width: 0; }
    \\  .c-load .card { display: flex; flex-direction: column; align-items: center; gap: var(--sp-2); min-width: 0;
    \\    padding: var(--sp-3) var(--sp-2); border-radius: var(--r-m); background: var(--panel-2); text-align: center; }
    \\  .c-load .card[data-you] { box-shadow: inset 0 0 0 2px var(--us); }
    \\  .c-load .card[data-empty] { justify-content: center; background: none; box-shadow: inset 0 0 0 1px var(--line);
    \\    font-size: var(--fs-xs); color: var(--faint); }
    \\  .c-load .body { display: flex; flex-direction: column; align-items: center; gap: 3px; min-width: 0; max-width: 100%; }
    \\  .c-load .body > b { font-size: var(--fs-m); font-weight: var(--w-b); overflow: hidden; text-overflow: ellipsis;
    \\    white-space: nowrap; max-width: 100%; }
    \\  .c-load .role { display: inline-flex; align-items: center; gap: 4px; font-size: var(--fs-xs); color: var(--muted); }
    \\  .c-load .fact { font-size: var(--fs-xs); font-variant-numeric: tabular-nums; color: var(--t2); }
    \\  .c-load .pills { display: flex; flex-wrap: wrap; justify-content: center; gap: 4px; }
    \\  .c-load .pill { padding: 1px 6px; border-radius: var(--r-s); font-size: var(--fs-xs); background: var(--wash); color: var(--t2); }
    \\  .c-load [data-tone="good"] { color: var(--hi2); }
    \\  .c-load [data-tone="bad"] { color: var(--lo2); }
    \\  .c-load [data-tone="caution"] { color: var(--turn); }
    \\  .c-load .strip { display: flex; flex-direction: column; justify-content: center; gap: 2px; min-width: 0; min-height: 28px; }
    \\  .c-load .strip > small { font-size: var(--fs-xs); color: var(--faint); text-align: center; }
    \\  .c-load .ticks { display: flex; justify-content: center; gap: var(--sp-2); font-size: var(--fs-xs); }
    \\  .c-load .ticks > [data-side="us"] { color: var(--us-hot); }
    \\  .c-load .ticks > [data-side="them"] { color: var(--them-hot); }
    \\  @container (max-width: 760px) {
    \\    .c-load .lanes { grid-template-columns: minmax(0, 1fr); gap: var(--sp-3); }
    \\    .c-load .lanes > li { grid-row: auto; grid-template-rows: none; grid-template-columns: repeat(2, minmax(0, 1fr)); }
    \\    .c-load .strip { grid-column: 1 / -1; grid-row: 2; }
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
        .{ .champ = demo("Ahri", "Ahri"), .text = "tough lane", .tone = .bad },
        .{ .champ = demo("Vi", "Vi"), .text = "early jungler" },
        .{ .who = "Enemy team", .text = "late team" },
    },
    .lanes = &.{
        .{
            .us = .{ .champ = demo("Garen", "Garen"), .role = .top, .lengths = short, .lengths_label = "Wins more in short games", .pills = &.{.{ .text = "strong now", .tone = .good }} },
            .them = .{ .champ = demo("Darius", "Darius"), .role = .top, .guessed = true, .lengths = short, .lengths_label = "Wins more in short games" },
            .strip = .{ .gold = 410, .lead = .us, .text = "ahead", .level6 = .us, .label = "Garen ahead in lane, level 6 first" },
        },
        .{
            .us = .{ .champ = demo("LeeSin", "Lee Sin"), .role = .jungle, .lengths = short, .lengths_label = "Wins more in short games", .pills = &.{.{ .text = "ban magnet" }} },
            .them = .{ .champ = demo("Vi", "Vi"), .role = .jungle, .guessed = true, .lengths = flat, .lengths_label = "About the same at any length", .pills = &.{.{ .text = "weak now", .tone = .bad }} },
            .strip = .{ .gold = 60, .lead = .even, .text = "even", .item = .them, .label = "Lee Sin even early, slow items" },
        },
        .{
            .us = .{ .champ = demo("Ahri", "Ahri"), .role = .mid, .you = true, .lengths = flat, .lengths_label = "About the same at any length", .pills = &.{ .{ .text = "lone AP" }, .{ .text = "crowd favourite" } } },
            .them = .{ .champ = demo("Syndra", "Syndra"), .role = .mid, .guessed = true, .lengths = long, .lengths_label = "Wins more in long games" },
            .strip = .{ .gold = -520, .lead = .them, .text = "behind", .level6 = .them, .item = .them, .label = "Ahri behind in lane, level 6 later, slow items" },
        },
        .{
            .us = .{ .champ = demo("Jinx", "Jinx"), .role = .bot, .lengths = long, .lengths_label = "Wins more in long games", .pills = &.{.{ .text = "hipster pick", .tone = .caution }} },
            .them = .{ .champ = demo("Caitlyn", "Caitlyn"), .role = .bot, .guessed = true, .lengths = short, .lengths_label = "Wins more in short games" },
        },
        .{
            .us = .{ .champ = demo("Lulu", "Lulu"), .role = .support, .lengths = long, .lengths_label = "Wins more in long games" },
        },
    },
};

/// The tester's numbers beside the public words
fn private(h: *H, s: Screen) Screen {
    var p = s;
    p.draft = 53.4;
    const lanes = h.mem.dupe(Lane, s.lanes) catch {
        h.oom = true;
        return s;
    };
    const facts = [_][]const u8{ "52.8% · 41k games", "50.1% · 88k games", "49.2% · 120k games", "48.6% · 210 games", "51.0% · 35k games" };
    for (lanes, facts, [_]Tone{ .good, .none, .none, .bad, .none }) |*l, f, t| {
        if (l.us) |*c| {
            c.fact = f;
            c.lean = t;
        }
        if (l.strip) |*x| x.text = switch (x.lead) {
            .us => "+410",
            .even => "+60",
            .them => "−520",
        };
    }
    p.lanes = lanes;
    return p;
}

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.addFill("public: bot with too few games of the lane, no enemy support yet", view(h, sample));
    g.addFill("private", view(h, private(h, sample)));
}
