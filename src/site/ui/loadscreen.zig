//! LoadScreen: the desktop app while the game loads. Our five cards over theirs, one
//! fixed order per card: portrait, name, role (? when guessed), how the champion does in
//! the role (private edition only), then pills coloured by meaning. Narrow windows get
//! one compact row per seat. Champion facts only: no player names or ranks
//! (research/questions/desktop-app-layout.md C1-C3)
const tree = @import("tree.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const fmt = @import("fmt.zig");
const phrase = @import("phrase.zig");
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
};

pub const Screen = struct {
    us: []const Card,
    them: []const Card,
    /// Private edition: our team's draft win chance in %
    draft: ?f32 = null,
};

const Side = enum { us, them };

pub fn view(h: *H, s: Screen) N {
    return h.div(.{ .class = "c-load" }, .{
        team(h, s.us, .us, if (s.draft) |d| d else null),
        team(h, s.them, .them, if (s.draft) |d| 100 - d else null),
        h.p(.{ .class = "foot" }, .{W.foot}),
    });
}

fn team(h: *H, cards: []const Card, side: Side, draft: ?f32) N {
    var list = h.list();
    for (cards, 0..) |c, i| list.add(card(h, i, c, side));
    return h.section(.{ .class = "team", .data_side = side }, .{
        h.h2(.{}, .{
            if (side == .us) W.us else W.them,
            if (draft) |d| h.span(.{ .class = "draft", .style = h.vars(.{ .c = fmt.wrColour(d / 100, 0.2) }) }, .{W.draft.with(h, .{ .p = @as(u32, @intFromFloat(@round(d))) })}) else null,
        }),
        h.el(.ol, .{ .class = "cards" }, .{list.done()}),
    });
}

fn card(h: *H, i: usize, c: Card, side: Side) N {
    var pills = h.list();
    for (c.pills, 0..) |p, j| pills.add(h.span(.{ .key = j, .class = "pill", .data_tone = if (p.tone == .none) null else p.tone }, .{p.text}));
    return h.li(.{ .key = i, .data_you = c.you }, .{
        champ.view(h, c.champ, .{ .px = .@"56", .side = if (side == .us) .us else .them, .you = c.you, .named = false, .label = W.unknown }),
        h.div(.{ .class = "body" }, .{
            h.b(.{}, .{if (c.champ) |x| x.name else W.unknown.s}),
            h.span(.{ .class = "role" }, .{
                if (c.role) |r| role.view(h, r, .{ .s = .s, .named = false }) else null,
                if (c.role) |r| r.label() else W.no_role,
                if (c.guessed) W.guess else null,
            }),
            if (c.fact.len > 0) h.span(.{ .class = "fact", .data_tone = if (c.lean == .none) null else c.lean }, .{c.fact}) else null,
            if (c.pills.len > 0) h.span(.{ .class = "pills" }, .{pills.done()}) else null,
        }),
    });
}

const W = struct {
    const us = plain("Your team");
    const them = plain("Enemy team");
    const draft = phrase.Phrase("{p:pct} draft");
    const unknown = plain("Unknown");
    const no_role = plain("Role unknown");
    const guess = plain("?");
    const foot = plain("Champion facts only: the role, how the champion does in it now, and its lane against the same role across. Roles with ? are guesses.");
};

pub const css =
    \\@layer components {
    \\  .c-load { display: flex; flex-direction: column; gap: var(--sp-4); min-width: 0; }
    \\  .c-load .team { display: flex; flex-direction: column; gap: var(--sp-2); min-width: 0; }
    \\  .c-load h2 { display: flex; align-items: baseline; gap: var(--sp-2); margin: 0; padding-bottom: 6px;
    \\    border-bottom: 3px solid currentColor; font-size: var(--fs-m); font-weight: var(--w-b); }
    \\  .c-load .team[data-side="us"] h2 { color: var(--us); }
    \\  .c-load .team[data-side="them"] h2 { color: var(--them); }
    \\  .c-load .draft { margin-left: auto; font-size: var(--fs-l); color: var(--c, var(--text)); font-variant-numeric: tabular-nums; }
    \\  .c-load .cards { list-style: none; margin: 0; padding: 0; display: grid; grid-template-columns: repeat(5, minmax(0, 1fr));
    \\    gap: var(--sp-2); }
    \\  .c-load .cards > li { display: flex; flex-direction: column; align-items: center; gap: var(--sp-2); min-width: 0;
    \\    padding: var(--sp-3) var(--sp-2); border-radius: var(--r-m); background: var(--panel-2); text-align: center; }
    \\  .c-load .cards > li[data-you] { box-shadow: inset 0 0 0 2px var(--us); }
    \\  .c-load .body { display: flex; flex-direction: column; align-items: center; gap: 3px; min-width: 0; max-width: 100%; }
    \\  .c-load .body > b { font-size: var(--fs-m); font-weight: var(--w-b); overflow: hidden; text-overflow: ellipsis;
    \\    white-space: nowrap; max-width: 100%; }
    \\  .c-load .role { display: inline-flex; align-items: center; gap: 4px; font-size: var(--fs-xs); color: var(--muted); }
    \\  .c-load .fact { font-size: var(--fs-xs); font-variant-numeric: tabular-nums; color: var(--t2); }
    \\  .c-load .pills { display: flex; flex-wrap: wrap; justify-content: center; gap: 4px; margin-top: 2px; }
    \\  .c-load .pill { padding: 1px 6px; border-radius: var(--r-s); font-size: var(--fs-xs); background: var(--wash); color: var(--t2); }
    \\  .c-load [data-tone="good"] { color: var(--hi2); }
    \\  .c-load [data-tone="bad"] { color: var(--lo2); }
    \\  .c-load [data-tone="caution"] { color: var(--turn); }
    \\  .c-load .foot { margin: 0; font-size: var(--fs-xs); color: var(--faint); }
    \\  @container (max-width: 640px) {
    \\    .c-load .cards { grid-template-columns: minmax(0, 1fr); gap: 2px; }
    \\    .c-load .cards > li { flex-direction: row; padding: var(--sp-2); text-align: left; }
    \\    .c-load .cards > li > .c-champ { --sz: var(--icon-m); }
    \\    .c-load .body { align-items: flex-start; }
    \\    .c-load .pills { justify-content: flex-start; }
    \\    .c-load .foot { display: none; }
    \\  }
    \\}
    \\
;

const demo = champ.demo;

pub const sample: Screen = .{
    .us = &.{
        .{ .champ = demo("Garen", "Garen"), .role = .top, .pills = &.{ .{ .text = "strong in top", .tone = .good }, .{ .text = "ahead at 14 min vs Darius", .tone = .good } } },
        .{ .champ = demo("LeeSin", "Lee Sin"), .role = .jungle, .pills = &.{.{ .text = "level 6 sooner" }} },
        .{ .champ = demo("Ahri", "Ahri"), .role = .mid, .you = true, .pills = &.{.{ .text = "behind at 14 min vs Syndra", .tone = .bad }} },
        .{ .champ = demo("Jinx", "Jinx"), .role = .bot, .pills = &.{.{ .text = "few games", .tone = .caution }} },
        .{ .champ = demo("Lulu", "Lulu"), .role = .support },
    },
    .them = &.{
        .{ .champ = demo("Darius", "Darius"), .role = .top, .guessed = true },
        .{ .champ = demo("Vi", "Vi"), .role = .jungle, .guessed = true, .pills = &.{.{ .text = "weak in jungle", .tone = .bad }} },
        .{ .champ = demo("Syndra", "Syndra"), .role = .mid, .guessed = true, .pills = &.{.{ .text = "ahead at 14 min vs Ahri", .tone = .good }} },
        .{ .champ = demo("Caitlyn", "Caitlyn"), .role = .bot, .guessed = true },
        .{ .champ = null, .role = null },
    },
};

/// The tester's numbers beside the public words
fn private(h: *H, s: Screen) Screen {
    var p = s;
    p.draft = 53.4;
    const us = h.mem.dupe(Card, s.us) catch {
        h.oom = true;
        return s;
    };
    for (us, [_][]const u8{ "52.8% · 41k games", "50.1% · 88k games", "49.2% · 120k games", "48.6% · 210 games", "51.0% · 35k games" }, [_]Tone{ .good, .none, .none, .bad, .none }) |*c, f, l| {
        c.fact = f;
        c.lean = l;
    }
    p.us = us;
    return p;
}

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.addFill("public", view(h, sample));
    g.addFill("private", view(h, private(h, sample)));
}
