//! DraftBoard: a draft as lane rows, our seat on the left, theirs mirrored on the right,
//! the role between; both teams' bans under. A seat: portrait, name, a line for its
//! state (hovering, picking) and an optional short fact coloured by its lean; an ally
//! still to pick can carry ideas for the role. The desktop's champ select first, then
//! the draft tester and Daily Draft (draft-tester.md). Champions and roles only: no
//! player names or ranks (product rules). The full variant (Daily, the tester): 48 px
//! seats with their pick number, the hidden seat asked about, a chosen answer previewed
//! dashed, seats selectable, the game's line grown under each name after a reveal, each
//! lane's middle its win chance from the matchup, and each side's damage mix
const std = @import("std");
const tree = @import("tree.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const badge = @import("badge.zig");
const kda = @import("kda.zig");
const fmt = @import("fmt.zig");
const phrase = @import("phrase.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = @import("phrase.zig").plain;
const H = tree.H;
const N = tree.N;

pub const name = "DraftBoard";
pub const scope = .{".c-draft"};

pub const State = enum { empty, intent, hover, locked };

pub const Lean = enum { none, good, bad };

pub const Seat = struct {
    champ: ?champ.Champ = null,
    state: State = .empty,
    you: bool = false,
    /// Their turn to pick is now
    picking: bool = false,
    /// The row's role is the recommender's guess (enemy positions are hidden in ranked)
    guessed: bool = false,
    /// A few words ("strong in top now", "51.2% in top"); "" for none
    fact: []const u8 = "",
    lean: Lean = .none,
    /// An ally still to pick: options for the role
    ideas: []const champ.Champ = &.{},
    /// A click on the seat and on each idea, "" for none: practice's (ui/practice.zig Act)
    /// or the app's lane panel ("lane <role's backing int>", 255 mine), which bridge.js
    /// sends so ui-app.wasm carries no handler
    act: []const u8 = "",
    idea_acts: []const []const u8 = &.{},
    // Full variant from here
    /// In the draft's order, 1-10; null when the order isn't known
    pick: ?u8 = null,
    /// The seat asked about: a "?" while `champ` is null, the answer once set
    hidden: bool = false,
    /// An answer chosen, not locked in: shown dashed in the hidden seat
    preview: ?champ.Champ = null,
    /// A short line under the name ("AD", "pick 10")
    sub: tree.Text = .{ .s = "" },
    /// The game's line, after a reveal
    game: ?Game = null,
    /// Full: the seat picked; compact: the lane the app's panel shows
    sel: bool = false,
};

pub const Game = struct {
    kda: kda.Kda,
    cs: u32,
    gold: u32,
    /// Damage to champions; `dmg_of` the board's most, for the bar
    dmg: u32,
    dmg_of: u32,
    /// The played pick's place among the seat's options; null unrated
    rated: ?u32 = null,
    /// The model's own pick was played
    star: bool = false,
};

pub const Lane = struct {
    role: role.Role,
    us: Seat = .{},
    them: Seat = .{},
    /// Full variant: our side's win chance from this lane alone, %
    win: ?f32 = null,
    /// The lane asked about: the middle hides its figure, the row carries the accent
    ask: bool = false,
};

pub const Variant = enum { app, full };

/// A side's damage to champions: physical and magic shares (the rest true damage), and
/// the share of the hidden seat, unknown until answered
pub const Mix = struct { phys: f32, magic: f32, unknown: f32 = 0 };

pub const Board = struct {
    /// Role order, five in a normal draft
    lanes: []const Lane,
    bans_us: []const champ.Champ = &.{},
    bans_them: []const champ.Champ = &.{},
    v: Variant = .app,
    /// Full variant: the sides' names ("Blue", "Red") and the winner once known
    heads: [2]tree.Text = .{ words.blue, words.red },
    won: ?Side = null,
    mix: ?[2]Mix = null,
};

pub const Side = enum { us, them };

/// The app's board; the full variant is fullOn's (kept apart so ui-app.wasm doesn't carry it)
pub fn view(h: *H, b: Board) N {
    var rows = h.list();
    for (b.lanes) |l| rows.add(h.div(.{ .key = @as(u32, @backingInt(l.role)), .class = "lane" }, .{
        seat(h, l.us, .us),
        h.span(.{ .class = "mid" }, .{
            role.view(h, l.role, .{ .s = .s }),
            if (l.them.guessed and l.them.champ != null) h.span(.{ .class = "q", .role = "img", .aria_label = words.guessed }, .{"?"}) else null,
        }),
        seat(h, l.them, .them),
    }));
    return h.div(.{ .class = "c-draft" }, .{
        h.div(.{ .class = "heads" }, .{
            h.span(.{ .data_side = Side.us }, .{words.us}),
            h.span(.{ .data_side = Side.them }, .{words.them}),
        }),
        h.div(.{ .class = "lanes" }, .{rows.done()}),
        bans(h, b),
    });
}

fn seat(h: *H, s: Seat, side: Side) N {
    const line: ?N = if (s.picking)
        badge.view(h, .turn, .{words.picking})
    else switch (s.state) {
        .intent => h.span(.{ .class = "line" }, .{words.intent}),
        .hover => h.span(.{ .class = "line" }, .{words.hover}),
        .empty, .locked => null,
    };
    var ideas = h.list();
    for (s.ideas, 0..) |c, i| ideas.add(h.span(.{
        .key = i,
        .data_act = if (i < s.idea_acts.len) s.idea_acts[i] else null,
    }, .{champ.view(h, c, .{ .px = .@"20" })}));
    return h.div(.{
        .class = "seat",
        .data_side = side,
        .data_turn = s.picking,
        .data_you = s.you,
        .data_act = if (s.act.len > 0) s.act else null,
        .data_sel = s.sel,
    }, .{
        champ.view(h, s.champ, .{
            .px = .@"40",
            .state = if (s.champ != null and s.state != .locked) .thin else .normal,
            .side = if (s.champ == null or s.state != .locked or s.you) null else switch (side) {
                .us => .us,
                .them => .them,
            },
            .you = s.you,
            .named = false,
            .label = words.empty,
        }),
        h.span(.{ .class = "who" }, .{
            if (s.champ) |c| h.b(.{}, .{c.name}) else null,
            line,
            if (s.fact.len > 0) h.span(.{ .class = "fact", .data_lean = if (s.lean == .none) null else s.lean }, .{s.fact}) else null,
            if (s.ideas.len > 0) h.span(.{ .class = "ideas" }, .{ h.span(.{ .class = "line" }, .{words.ideas}), ideas.done() }) else null,
        }),
    });
}

fn bans(h: *H, b: Board) ?N {
    if (b.bans_us.len + b.bans_them.len == 0) return null;
    var us = h.list();
    for (b.bans_us, 0..) |c, i| us.add(h.span(.{ .key = i }, .{champ.view(h, c, .{ .px = .@"20", .state = .banned })}));
    var them = h.list();
    for (b.bans_them, 0..) |c, i| them.add(h.span(.{ .key = i }, .{champ.view(h, c, .{ .px = .@"20", .state = .banned })}));
    return h.div(.{ .class = "bans" }, .{
        h.span(.{ .data_side = Side.us }, .{us.done()}),
        h.span(.{ .class = "line" }, .{words.bans}),
        h.span(.{ .data_side = Side.them }, .{them.done()}),
    });
}

/// The full variant (Daily, Learn), seats as buttons where `on[i]` has lane i's us and
/// them click (kept off Seat, which the app encodes and a handler can't be)
pub fn fullOn(h: *H, b: Board, on: []const [2]?tree.Handler) N {
    var grown = false;
    for (b.lanes) |l| grown = grown or l.us.game != null or l.them.game != null;
    var rows = h.list();
    for (b.lanes, 0..) |l, i| {
        const ons: [2]?tree.Handler = if (i < on.len) on[i] else .{ null, null };
        rows.add(h.div(.{ .key = @as(u32, @backingInt(l.role)), .class = "lane", .data_ask = l.ask }, .{
            fullSeat(h, l.us, .us, ons[0], b.heads[0], l.role),
            mid(h, l, b.heads),
            fullSeat(h, l.them, .them, ons[1], b.heads[1], l.role),
        }));
    }
    return h.div(.{ .class = "c-draft", .data_v = Variant.full }, .{
        h.div(.{ .class = "heads" }, .{
            h.span(.{ .data_side = Side.us }, .{ h.b(.{}, .{b.heads[0]}), if (b.won == .us) badge.view(h, .us, .{words.won}) else null }),
            h.span(.{ .data_side = Side.them }, .{ if (b.won == .them) badge.view(h, .them, .{words.won}) else null, h.b(.{}, .{b.heads[1]}) }),
        }),
        if (grown) h.div(.{ .class = "lane hd", .aria_hidden = true }, .{ statHead(h, .us), h.span(.{}, .{}), statHead(h, .them) }) else null,
        h.div(.{ .class = "lanes" }, .{rows.done()}),
        if (b.mix) |m| h.div(.{ .class = "mix" }, .{ mixBar(h, m[0], .us), h.span(.{ .class = "line" }, .{words.damage}), mixBar(h, m[1], .them) }) else null,
        bans(h, b),
    });
}

fn statHead(h: *H, side: Side) N {
    return h.span(.{ .class = "st", .data_side = side }, .{
        h.span(.{}, .{words.kda_h}),
        h.span(.{}, .{words.cs}),
        h.span(.{}, .{words.gold}),
        h.span(.{}, .{words.dmg}),
        h.span(.{}, .{words.rated}),
    });
}

fn fullSeat(h: *H, s: Seat, side: Side, on: ?tree.Handler, head: tree.Text, rl: role.Role) N {
    // A hidden seat with its champion set has been revealed
    const asked = s.hidden and s.champ == null;
    const shown = if (asked) s.preview else s.champ;
    // The asked seat's "?" is the question; an empty one has only its label
    const nm: []const u8 = if (shown) |c| c.name else if (asked) "?" else "";
    return h.div(.{
        .class = "seat",
        .data_side = side,
        .data_hidden = asked,
        .data_preview = asked and s.preview != null,
        .data_sel = s.sel,
    }, .{
        h.span(.{ .class = "ic" }, .{
            champ.view(h, shown, .{
                .px = .@"48",
                .side = switch (side) {
                    .us => .us,
                    .them => .them,
                },
                .named = false,
                .label = if (asked) words.hidden else words.empty,
            }),
            if (s.pick) |n| h.span(.{ .class = "pn", .role = "img", .aria_label = words.pick.with(h, .{ .n = n }) }, .{n}) else null,
        }),
        h.span(.{ .class = "who" }, .{
            // Only the name is the button (a short label); its ::after covers the seat
            if (on) |o| h.button(.{
                .class = "nb",
                .type = "button",
                .aria_pressed = s.sel,
                .aria_label = seatLabel(h, s, head, rl, if (shown) |c| c.name else if (asked) words.hidden.s else words.empty.s),
                .on_click = o,
            }, .{nm}) else h.b(.{}, .{nm}),
            if (s.sub.s.len > 0) h.span(.{ .class = "line" }, .{s.sub}) else null,
        }),
        if (s.game) |g| gameLine(h, g, side) else null,
    });
}

fn seatLabel(h: *H, s: Seat, head: tree.Text, rl: role.Role, who: []const u8) tree.Text {
    if (s.pick) |n| return words.seat_pick.with(h, .{ .side = head.s, .r = rl.label().s, .n = who, .p = n });
    return words.seat.with(h, .{ .side = head.s, .r = rl.label().s, .n = who });
}

fn gameLine(h: *H, g: Game, side: Side) N {
    return h.span(.{ .class = "st", .data_side = side }, .{
        kda.view(h, g.kda, .{}),
        h.span(.{}, .{phrase.num(h, .int, g.cs)}),
        h.span(.{}, .{phrase.num(h, .kilo, g.gold)}),
        h.span(.{ .class = "dm" }, .{h.span(.{ .aria_hidden = true }, .{h.el(.i, .{ .style = h.vars(.{
            .w = if (g.dmg_of > 0) pct(@as(f32, @floatFromInt(g.dmg)) / @as(f32, @floatFromInt(g.dmg_of))) else 0,
        }) }, .{})})}),
        h.span(.{ .class = "rk", .data_star = g.star }, .{if (g.rated) |r| words.nth.with(h, .{ .n = r, .s = ordinal(r) }) else null}),
    });
}

pub fn ordinal(n: u32) []const u8 {
    if (n % 100 >= 11 and n % 100 <= 13) return "th";
    return switch (n % 10) {
        1 => "st",
        2 => "nd",
        3 => "rd",
        else => "th",
    };
}

/// The lane's middle: role, and our side's win chance from the lane, as a bar out from
/// even toward the side it favours
fn mid(h: *H, l: Lane, heads: [2]tree.Text) N {
    const bare = h.span(.{ .class = "mid" }, .{role.view(h, l.role, .{ .s = .s })});
    const raw = l.win orelse return bare;
    if (!std.math.isFinite(raw)) return bare;
    if (l.ask) return h.span(.{ .class = "mid", .data_ask = true }, .{
        role.view(h, l.role, .{ .s = .s }),
        h.span(.{ .class = "lb" }, .{}),
        h.span(.{ .class = "v" }, .{"?"}),
    });
    const w = @min(@max(raw, 0), 100);
    const d = w - 50;
    const even = @abs(d) < 0.5;
    const side: Side = if (d >= 0) .us else .them;
    const fav = if (side == .us) w else 100 - w;
    const head = heads[@backingInt(side)];
    const said = if (even) words.even else words.lane.with(h, .{ .s = head.s, .w = fav });
    // Half the bar is 5 points
    const reach = @min(@abs(d), 5) * 10;
    return h.span(.{ .class = "mid", .data_side = if (even) null else side, .title = said, .role = "img", .aria_label = said }, .{
        role.view(h, l.role, .{ .s = .s }),
        h.span(.{ .class = "lb", .aria_hidden = true }, .{if (even) null else h.el(.i, .{ .style = h.vars(.{
            .l = if (side == .us) 50 - reach else 50,
            .w = reach,
        }) }, .{})}),
        h.span(.{ .class = "v", .aria_hidden = true }, .{if (even) words.even else phrase.num(h, .rate, fav)}),
    });
}

fn mixBar(h: *H, m: Mix, side: Side) N {
    return h.span(.{ .class = "mx", .data_side = side }, .{
        h.span(.{ .class = "bar", .aria_hidden = true }, .{
            h.el(.i, .{ .class = "ph", .style = h.vars(.{ .w = pct(m.phys) }) }, .{}),
            h.el(.i, .{ .class = "mg", .style = h.vars(.{ .w = pct(m.magic) }) }, .{}),
            if (m.unknown > 0) h.el(.i, .{ .class = "uk", .style = h.vars(.{ .w = pct(m.unknown) }) }, .{}) else null,
        }),
        h.span(.{ .class = "ends" }, .{
            h.span(.{}, .{ words.ad, " ", h.b(.{}, .{phrase.num(h, .pct, share(m.phys))}) }),
            h.span(.{}, .{ words.ap, " ", h.b(.{}, .{phrase.num(h, .pct, share(m.magic))}) }),
        }),
    });
}

/// A 0-1 share from the data as a percent for a width; NaN or out of range clamps
fn pct(x: f32) f32 {
    return @min(@max(100 * x, 0), 100);
}

/// `pct` as a whole number
fn share(x: f32) u32 {
    return @intFromFloat(@round(pct(x)));
}

const words = struct {
    const us = plain("Your team");
    const them = plain("Enemy team");
    const picking = plain("Picking");
    const intent = plain("wants it");
    const hover = plain("hovering");
    const ideas = plain("ideas");
    const bans = plain("Bans");
    const empty = plain("Empty seat");
    const guessed = plain("Role guessed");
    const blue = plain("Blue");
    const red = plain("Red");
    const won = plain("Won");
    const hidden = plain("Hidden pick");
    const pick = phrase.Phrase("Pick {n:int}");
    const seat = phrase.Phrase("{side:text} {r:text}, {n:text}");
    const seat_pick = phrase.Phrase("{side:text} {r:text}, {n:text}, pick {p:int}");
    const nth = phrase.Phrase("{n:int}{s:text}");
    const lane = phrase.Phrase("{s:text} {w:rate} from the lane");
    const even = plain("Even");
    const damage = plain("Damage");
    const ad = plain("AD");
    const ap = plain("AP");
    const kda_h = plain("K/D/A");
    const cs = plain("CS");
    const gold = plain("Gold");
    const dmg = plain("Dmg");
    const rated = plain("Rated");
};

pub const css =
    \\@layer components {
    \\  .c-draft { container-type: inline-size; display: flex; flex-direction: column; gap: var(--sp-2); min-width: 0;
    \\    max-width: 640px; }
    \\  .c-draft .heads, .c-draft .bans { display: grid; grid-template-columns: minmax(0, 1fr) auto minmax(0, 1fr);
    \\    align-items: center; gap: var(--sp-2); padding: 0 var(--sp-2); }
    \\  .c-draft .heads { grid-template-columns: 1fr 1fr; font-size: var(--fs-xs); font-weight: var(--w-m); }
    \\  .c-draft [data-side="us"] { color: var(--us); }
    \\  .c-draft [data-side="them"] { color: var(--them); text-align: right; }
    \\  .c-draft .lanes { display: flex; flex-direction: column; gap: 2px; }
    \\  .c-draft .lane { display: grid; grid-template-columns: minmax(0, 1fr) 24px minmax(0, 1fr); align-items: center;
    \\    gap: var(--sp-2); padding: 6px var(--sp-2); border-radius: var(--r-s); background: var(--panel-2); }
    \\  .c-draft .mid { display: flex; flex-direction: column; align-items: center; color: var(--muted); }
    \\  .c-draft .q { font-size: var(--fs-xs); color: var(--faint); line-height: 1; }
    \\  .c-draft .seat { display: flex; align-items: center; gap: var(--sp-2); min-width: 0; color: var(--text);
    \\    border-radius: var(--r-s); }
    \\  .c-draft .seat[data-side="them"] { flex-direction: row-reverse; }
    \\  .c-draft .seat[data-turn] { box-shadow: 0 0 0 1px var(--turn-line); background: var(--wash);
    \\    padding: 3px; margin: -3px; }
    \\  .c-draft .who { display: flex; flex-direction: column; gap: 1px; min-width: 0; }
    \\  .c-draft .seat[data-side="them"] .who { align-items: flex-end; text-align: right; }
    \\  .c-draft .who > b { max-width: 100%; font-weight: var(--w-m); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    \\  .c-draft .line { font-size: var(--fs-xs); color: var(--muted); }
    \\  .c-draft .fact { font-size: var(--fs-xs); color: var(--t2); max-width: 100%; overflow: hidden;
    \\    text-overflow: ellipsis; white-space: nowrap; }
    \\  .c-draft .fact[data-lean="good"] { color: var(--hi2); }
    \\  .c-draft .fact[data-lean="bad"] { color: var(--lo2); }
    \\  .c-draft .ideas { display: flex; align-items: center; gap: 4px; flex-wrap: wrap; }
    \\  .c-draft .bans > span { display: flex; gap: 4px; flex-wrap: wrap; }
    \\  .c-draft .bans > [data-side="them"] { justify-content: flex-end; }
    \\  .c-draft[data-v="full"] { max-width: none; gap: 0; }
    \\  .c-draft[data-v="full"] .heads { padding: 0 var(--sp-2) var(--sp-2); font-size: var(--fs-l); }
    \\  .c-draft[data-v="full"] .heads > span { display: flex; align-items: center; gap: var(--sp-2); }
    \\  .c-draft[data-v="full"] .heads > [data-side="them"] { justify-content: flex-end; }
    \\  .c-draft[data-v="full"] .lanes { gap: 0; border-top: 1px solid var(--line); }
    \\  .c-draft[data-v="full"] .lane { grid-template-columns: minmax(0, 1fr) 120px minmax(0, 1fr); gap: 0; min-height: 60px;
    \\    padding: 0; border-radius: 0; background: none; border-bottom: 1px solid var(--line); }
    \\  .c-draft[data-v="full"] .lane[data-ask] { background: linear-gradient(90deg, transparent, var(--accent-bg) 70%); }
    \\  .c-draft[data-v="full"] .lane.hd { min-height: 26px; font-size: var(--fs-xs); color: var(--faint); border-bottom: 0; }
    \\  .c-draft[data-v="full"] .seat { all: unset; box-sizing: border-box; display: grid; min-width: 0;
    \\    grid-template-columns: 48px minmax(0, 1fr) auto; grid-template-areas: "ic who st"; align-items: center;
    \\    column-gap: var(--sp-3); padding: 6px var(--sp-2); border-radius: var(--r-m); flex-direction: initial; }
    \\  .c-draft[data-v="full"] .seat[data-side="them"] { grid-template-columns: auto minmax(0, 1fr) 48px;
    \\    grid-template-areas: "st who ic"; text-align: right; }
    \\  .c-draft[data-v="full"] .seat { position: relative; }
    \\  .c-draft .nb { all: unset; display: block; max-width: 100%; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
    \\    font-weight: var(--w-b); cursor: pointer; }
    \\  .c-draft .nb::after { content: ""; position: absolute; inset: 0; border-radius: var(--r-m); }
    \\  .c-draft[data-v="full"] .seat:has(.nb:hover) { background: var(--panel-2); }
    \\  .c-draft[data-v="full"] .seat:has(.nb:focus-visible) { outline: 2px solid var(--focus); outline-offset: -2px; }
    \\  .c-draft[data-v="full"] .seat[data-sel] { background: var(--accent-bg); box-shadow: inset 0 0 0 1px var(--focus); }
    \\  .c-draft .ic { grid-area: ic; position: relative; line-height: 0; }
    \\  .c-draft[data-v="full"] .who { grid-area: who; }
    \\  .c-draft[data-v="full"] .who > b { font-weight: var(--w-b); }
    \\  .c-draft .pn { position: absolute; bottom: -4px; left: -4px; min-width: 18px; height: 18px; padding: 0 4px;
    \\    box-sizing: border-box; display: grid; place-items: center; border-radius: var(--r-s); background: var(--bg);
    \\    box-shadow: inset 0 0 0 1px var(--us); font-size: var(--fs-xs); font-weight: var(--w-b); line-height: 1;
    \\    font-variant-numeric: tabular-nums; }
    \\  .c-draft .seat[data-side="them"] .pn { left: auto; right: -4px; box-shadow: inset 0 0 0 1px var(--them); }
    \\  .c-draft .seat[data-hidden] .c-champ { box-shadow: inset 0 0 0 1.5px var(--accent); animation: c-draft-pulse 1.6s var(--ease) infinite; }
    \\  .c-draft .seat:is([data-hidden], [data-preview]) .who > :is(b, .nb) { color: var(--accent); }
    \\  .c-draft .seat[data-preview] .c-champ { box-shadow: none; outline: 2px dashed var(--accent); outline-offset: 2px; opacity: 0.8; }
    \\  .c-draft .st { grid-area: st; display: grid; grid-template-columns: 64px 32px 40px 48px 36px; gap: var(--sp-2);
    \\    align-items: center; font-size: var(--fs-s); font-variant-numeric: tabular-nums; white-space: nowrap; }
    \\  .c-draft .st[data-side="them"] { direction: rtl; }
    \\  .c-draft .st[data-side="them"] > * { direction: ltr; }
    \\  .c-draft .lane.hd .st { grid-area: auto; font-size: var(--fs-xs); color: var(--faint); justify-self: end; padding: 0 var(--sp-2); }
    \\  .c-draft .lane.hd .st[data-side="them"] { justify-self: start; }
    \\  .c-draft .dm > span { display: block; position: relative; height: 4px; border-radius: 2px; background: var(--bar-track);
    \\    overflow: hidden; }
    \\  .c-draft .dm i { position: absolute; inset: 0 auto 0 0; width: calc(var(--w) * 1%); background: var(--bar-hi); }
    \\  .c-draft .rk { font-weight: var(--w-b); }
    \\  .c-draft .rk[data-star] { color: var(--turn); }
    \\  .c-draft[data-v="full"] .mid { display: grid; justify-items: center; gap: 3px; padding: 0 var(--sp-1); min-width: 0;
    \\    color: var(--t2); }
    \\  .c-draft .mid .lb { position: relative; width: 100%; height: 8px; }
    \\  .c-draft .mid .lb::before { content: ""; position: absolute; left: 0; right: 0; top: 3px; height: 2px; border-radius: 1px;
    \\    background: var(--bar-track); }
    \\  .c-draft .mid .lb::after { content: ""; position: absolute; left: 50%; top: 0; bottom: 0; width: 1px; background: var(--axis); }
    \\  .c-draft .mid .lb > i { position: absolute; top: 1px; height: 6px; left: calc(var(--l) * 1%); width: calc(var(--w) * 1%);
    \\    border-radius: 2px; background: var(--c, var(--bar-hi)); }
    \\  .c-draft .mid[data-side="us"] { --c: var(--us); }
    \\  .c-draft .mid[data-side="them"] { --c: var(--them); }
    \\  .c-draft .mid .v { font-size: var(--fs-xs); font-weight: var(--w-b); font-variant-numeric: tabular-nums; color: var(--c, var(--muted));
    \\    line-height: 14px; }
    \\  .c-draft .mid[data-ask] { color: var(--accent); --c: var(--accent); }
    \\  .c-draft .mix { display: grid; grid-template-columns: minmax(0, 1fr) 120px minmax(0, 1fr); align-items: center;
    \\    padding: var(--sp-3) 0 var(--sp-2); }
    \\  .c-draft .mix > .line { text-align: center; text-transform: uppercase; letter-spacing: 0.06em; font-weight: var(--w-b);
    \\    color: var(--faint); }
    \\  .c-draft .mx { display: grid; gap: 4px; padding: 0 var(--sp-2); min-width: 0; }
    \\  .c-draft .mx .bar { display: flex; height: 10px; border-radius: 3px; overflow: hidden; background: var(--bar-track); }
    \\  .c-draft .mx .bar > i { display: block; height: 100%; width: calc(var(--w) * 1%); }
    \\  .c-draft .mx[data-side="them"] .bar { flex-direction: row-reverse; }
    \\  .c-draft .mx .ph { background: var(--bar-hi); }
    \\  .c-draft .mx .mg { background: var(--bar-lo); }
    \\  .c-draft .mx .uk { background: repeating-linear-gradient(135deg, var(--accent-bg) 0 4px, transparent 4px 8px);
    \\    box-shadow: inset 0 0 0 1px var(--sel-line); }
    \\  .c-draft .mx .ends { display: flex; justify-content: space-between; font-size: var(--fs-xs); color: var(--muted);
    \\    font-variant-numeric: tabular-nums; }
    \\  .c-draft .mx .ends b { color: var(--text); }
    \\  .c-draft[data-v="full"] .bans { padding-top: var(--sp-2); }
    \\  .c-draft[data-v="full"] .bans .c-champ { --sz: var(--icon-m); }
    \\  .c-draft[data-v="full"] .bans .c-champ > img { opacity: 1; filter: none; }
    \\  @keyframes c-draft-pulse { 50% { box-shadow: inset 0 0 0 1.5px var(--accent), 0 0 0 4px var(--accent-bg); } }
    \\  @media (prefers-reduced-motion: reduce) { .c-draft .seat[data-hidden] .c-champ { animation: none; } }
    \\  @container (max-width: 1000px) {
    \\    .c-draft[data-v="full"] .seat:has(> .st) { grid-template-areas: "ic who" "ic st"; grid-template-columns: 48px minmax(0, 1fr);
    \\      row-gap: 2px; }
    \\    .c-draft[data-v="full"] .seat[data-side="them"]:has(> .st) { grid-template-areas: "who ic" "st ic"; grid-template-columns: minmax(0, 1fr) 48px; }
    \\    .c-draft .st { gap: var(--sp-1); }
    \\    .c-draft .seat > .st { justify-self: end; }
    \\    .c-draft .seat[data-side="them"] > .st { justify-self: start; }
    \\  }
    \\  @container (max-width: 760px) {
    \\    .c-draft[data-v="full"] .seat { grid-template-areas: "ic who"; grid-template-columns: 40px minmax(0, 1fr);
    \\      column-gap: var(--sp-2); row-gap: 2px; padding: 6px 2px; }
    \\    .c-draft[data-v="full"] .seat:has(> .st) { grid-template-areas: "ic who" "ic st"; }
    \\    .c-draft[data-v="full"] .seat[data-side="them"] { grid-template-areas: "who ic"; grid-template-columns: minmax(0, 1fr) 40px; }
    \\    .c-draft[data-v="full"] .seat[data-side="them"]:has(> .st) { grid-template-areas: "who ic" "st ic"; }
    \\    .c-draft[data-v="full"] .seat > .ic > .c-champ { --sz: 40px; }
    \\    .c-draft .st { display: flex; gap: 6px; font-size: var(--fs-xs); }
    \\    .c-draft .st[data-side="them"] { justify-content: flex-end; }
    \\    .c-draft .st > :nth-child(n+2):not(.rk) { display: none; }
    \\    .c-draft[data-v="full"] .lane.hd { display: none; }
    \\    .c-draft[data-v="full"] .lane, .c-draft .mix { grid-template-columns: minmax(0, 1fr) 64px minmax(0, 1fr); }
    \\    .c-draft[data-v="full"] .heads { font-size: var(--fs-m); }
    \\    .c-draft[data-v="full"] .bans .c-champ { --sz: var(--icon); }
    \\  }
    \\  @container (max-width: 360px) {
    \\    .c-draft .seat > .c-champ { --sz: var(--icon-m); }
    \\    .c-draft .lane { gap: var(--sp-1); padding: 4px; }
    \\    .c-draft[data-v="full"] .seat { grid-template-columns: 32px minmax(0, 1fr); column-gap: 6px; }
    \\    .c-draft[data-v="full"] .seat[data-side="them"] { grid-template-columns: minmax(0, 1fr) 32px; }
    \\    .c-draft[data-v="full"] .seat > .ic > .c-champ { --sz: 32px; }
    \\    .c-draft[data-v="full"] .lane, .c-draft .mix { grid-template-columns: minmax(0, 1fr) 52px minmax(0, 1fr); }
    \\    .c-draft .st { flex-wrap: wrap; column-gap: 4px; row-gap: 0; max-width: 100%; }
    \\  }
    \\}
    \\
;

const demo = champ.demo;

/// Mid draft: allies locked, hovering and picking, two enemies shown with guessed roles
pub const sample: Board = .{
    .lanes = &.{
        .{
            .role = .top,
            .us = .{ .champ = demo("Garen", "Garen"), .state = .locked, .fact = "strong in top now", .lean = .good },
            .them = .{ .champ = demo("Darius", "Darius"), .state = .locked, .guessed = true },
        },
        .{
            .role = .jungle,
            .us = .{ .champ = demo("LeeSin", "Lee Sin"), .state = .hover, .picking = true },
            .them = .{},
        },
        .{
            .role = .mid,
            .us = .{ .champ = demo("Ahri", "Ahri"), .state = .hover, .you = true },
            .them = .{ .champ = demo("Syndra", "Syndra"), .state = .locked, .guessed = true, .fact = "weak in mid now", .lean = .bad },
        },
        .{
            .role = .bot,
            .us = .{ .ideas = &.{ demo("Jinx", "Jinx"), demo("Caitlyn", "Caitlyn"), demo("Ezreal", "Ezreal") } },
        },
        .{
            .role = .support,
            .us = .{ .champ = demo("Lulu", "Lulu"), .state = .intent },
        },
    },
    .bans_us = &.{ demo("Yasuo", "Yasuo"), demo("Zed", "Zed") },
    .bans_them = &.{ demo("Vex", "Vex"), demo("Aurora", "Aurora"), demo("Smolder", "Smolder") },
};

/// Daily #11 before the guess: red's last pick hidden, the top lane asked
pub const daily_before: Board = .{
    .v = .full,
    .lanes = &.{
        .{ .role = .top, .ask = true, .win = 51.4, .us = .{ .champ = demo("KSante", "K'Sante"), .pick = 9, .sub = plain("AD") }, .them = .{ .hidden = true, .pick = 10, .sub = plain("pick 10") } },
        .{ .role = .jungle, .win = 50.1, .us = .{ .champ = demo("JarvanIV", "Jarvan IV"), .pick = 5, .sub = plain("AD") }, .them = .{ .champ = demo("Vi", "Vi"), .pick = 2, .sub = plain("AD") } },
        .{ .role = .mid, .win = 49.1, .us = .{ .champ = demo("Viktor", "Viktor"), .pick = 8, .sub = plain("AP") }, .them = .{ .champ = demo("Anivia", "Anivia"), .pick = 7, .sub = plain("AP") } },
        .{ .role = .bot, .win = 50.9, .us = .{ .champ = demo("Kalista", "Kalista"), .pick = 1, .sub = plain("AD") }, .them = .{ .champ = demo("Caitlyn", "Caitlyn"), .pick = 6, .sub = plain("AD") } },
        .{ .role = .support, .win = 51.3, .us = .{ .champ = demo("Renata", "Renata"), .pick = 4, .sub = plain("AD and AP") }, .them = .{ .champ = demo("Neeko", "Neeko"), .pick = 3, .sub = plain("AP") } },
    },
    .mix = .{ .{ .phys = 0.61, .magic = 0.39 }, .{ .phys = 0.44, .magic = 0.36, .unknown = 0.2 } },
    .bans_us = &.{ demo("Yasuo", "Yasuo"), demo("Zed", "Zed") },
    .bans_them = &.{ demo("Vex", "Vex"), demo("Aurora", "Aurora") },
};

fn revealed(h: *H) Board {
    const lanes = h.mem.dupe(Lane, daily_before.lanes) catch {
        h.oom = true;
        return daily_before;
    };
    const lines = [5][2]Game{
        .{ .{ .kda = .{ .k = 0, .d = 2, .a = 3 }, .cs = 398, .gold = 17500, .dmg = 9100, .dmg_of = 24000, .rated = 4 }, .{ .kda = .{ .k = 1, .d = 3, .a = 1 }, .cs = 429, .gold = 16200, .dmg = 21000, .dmg_of = 24000, .rated = 3 } },
        .{ .{ .kda = .{ .k = 2, .d = 3, .a = 6 }, .cs = 306, .gold = 16500, .dmg = 9800, .dmg_of = 24000, .rated = 2 }, .{ .kda = .{ .k = 2, .d = 3, .a = 5 }, .cs = 299, .gold = 15100, .dmg = 8200, .dmg_of = 24000, .rated = 5 } },
        .{ .{ .kda = .{ .k = 2, .d = 2, .a = 4 }, .cs = 379, .gold = 16100, .dmg = 19000, .dmg_of = 24000, .rated = 6 }, .{ .kda = .{ .k = 1, .d = 2, .a = 4 }, .cs = 371, .gold = 15500, .dmg = 16000, .dmg_of = 24000, .rated = 9 } },
        .{ .{ .kda = .{ .k = 4, .d = 0, .a = 3 }, .cs = 507, .gold = 22100, .dmg = 18000, .dmg_of = 24000, .rated = 1, .star = true }, .{ .kda = .{ .k = 4, .d = 1, .a = 2 }, .cs = 472, .gold = 21700, .dmg = 24000, .dmg_of = 24000, .rated = 2 } },
        .{ .{ .kda = .{ .k = 2, .d = 1, .a = 6 }, .cs = 64, .gold = 12000, .dmg = 5000, .dmg_of = 24000, .rated = 3 }, .{ .kda = .{ .k = 0, .d = 1, .a = 5 }, .cs = 68, .gold = 10900, .dmg = 7000, .dmg_of = 24000, .rated = 7 } },
    };
    for (lanes, lines) |*l, g| {
        l.ask = false;
        l.us.game = g[0];
        l.them.game = g[1];
        l.us.sub = .{ .s = "" };
        l.them.sub = .{ .s = "" };
    }
    lanes[0].them.champ = demo("Jayce", "Jayce");
    lanes[0].them.sel = true;
    var b = daily_before;
    b.lanes = lanes;
    b.won = .us;
    b.mix = .{ .{ .phys = 0.61, .magic = 0.39 }, .{ .phys = 0.6, .magic = 0.4 } };
    return b;
}

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.addFill("mid draft", view(h, sample));
    g.addFill("planning, nothing shown", view(h, .{ .lanes = &.{
        .{ .role = .top },
        .{ .role = .jungle },
        .{ .role = .mid, .us = .{ .you = true } },
        .{ .role = .bot },
        .{ .role = .support },
    } }));
    g.addFill("full: hidden pick asked", fullOn(h, daily_before, &.{}));
    var chosen = daily_before;
    const lanes = h.mem.dupe(Lane, daily_before.lanes) catch {
        h.oom = true;
        return;
    };
    lanes[0].them.preview = demo("Ambessa", "Ambessa");
    chosen.lanes = lanes;
    g.addFill("full: an answer chosen", fullOn(h, chosen, &.{}));
    g.addFill("full: after the reveal, a seat selected", fullOn(h, revealed(h), &.{}));
    const on = h.mem.alloc([2]?tree.Handler, 5) catch {
        h.oom = true;
        return;
    };
    for (on, 0..) |*o, i| o.* = .{ h.on(&gallery_tap, .{ .seat = @intCast(i) }), h.on(&gallery_tap, .{ .seat = @intCast(5 + i) }) };
    g.addFill("full: after the reveal, seats as buttons", fullOn(h, revealed(h), on));
}

test "full variant: pick numbers, the hidden seat, seats as buttons only with a handler" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const html = @import("html.zig");
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    var out: std.Io.Writer.Allocating = .init(a);
    try html.write(&t, fullOn(&h, daily_before, &.{}), &out.writer);
    var s = out.written();
    try std.testing.expect(std.mem.find(u8, s, "data-v=\"full\"") != null);
    try std.testing.expectEqual(1, std.mem.count(u8, s, "data-hidden"));
    try std.testing.expectEqual(2, std.mem.count(u8, s, "data-ask"));
    try std.testing.expectEqual(10, std.mem.count(u8, s, "class=\"pn\""));
    try std.testing.expect(std.mem.find(u8, s, "<button") == null);
    try std.testing.expect(std.mem.find(u8, s, "class=\"lane hd\"") == null);
    out = .init(a);
    try html.write(&t, fullOn(&h, revealed(&h), &.{}), &out.writer);
    s = out.written();
    try std.testing.expect(std.mem.find(u8, s, "data-hidden") == null);
    try std.testing.expect(std.mem.find(u8, s, "Jayce") != null);
    try std.testing.expectEqual(1, std.mem.count(u8, s, "data-sel"));
    try std.testing.expect(std.mem.find(u8, s, "class=\"lane hd\"") != null);
    try std.testing.expect(std.mem.find(u8, s, "4th") != null);
    try std.testing.expectEqual(0, share(std.math.nan(f32)));
    try std.testing.expectEqual(100, share(3));
}

var gallery_tap: Tap = .{};

const Tap = struct {
    pub const Msg = union(enum) { seat: u8 };
    pub fn update(_: *Tap, _: Msg, _: *tree.Event) void {}
};

test "full variant by hand: buttons from a short `on`, lane middles, a red win, odd data" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const html = @import("html.zig");
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    var tap: Tap = .{};
    const game: Game = .{ .kda = .{ .k = 1, .d = 2, .a = 3 }, .cs = 100, .gold = 9000, .dmg = 5000, .dmg_of = 0, .rated = 12 };
    const b: Board = .{
        .v = .full,
        .heads = .{ plain("Blue"), plain("Red") },
        .won = .them,
        .mix = .{ .{ .phys = 0.5, .magic = 0.5 }, .{ .phys = 1.4, .magic = std.math.nan(f32), .unknown = 0.2 } },
        .lanes = &.{
            .{ .role = .top, .win = 47.9, .us = .{ .champ = demo("Gnar", "Gnar"), .sel = true }, .them = .{ .hidden = true, .preview = demo("Jax", "Jax") } },
            .{ .role = .jungle, .win = 130, .us = .{ .game = game }, .them = .{ .hidden = true, .pick = 10 } },
            .{ .role = .mid, .win = std.math.nan(f32) },
            .{ .role = .bot },
            .{ .role = .support, .win = 50.2 },
        },
    };
    var out: std.Io.Writer.Allocating = .init(a);
    const on = [_][2]?tree.Handler{
        .{ h.on(&tap, .{ .seat = 0 }), h.on(&tap, .{ .seat = 5 }) },
        .{ h.on(&tap, .{ .seat = 1 }), h.on(&tap, .{ .seat = 6 }) },
    };
    try html.write(&t, fullOn(&h, b, &on), &out.writer);
    const s = out.written();
    try std.testing.expectEqual(4, std.mem.count(u8, s, "<button"));
    try std.testing.expect(std.mem.find(u8, s, "aria-label=\"Red Top, Jax\"") != null);
    try std.testing.expect(std.mem.find(u8, s, "aria-label=\"Blue Jungle, Empty seat\"") != null);
    try std.testing.expect(std.mem.find(u8, s, "aria-label=\"Red Jungle, Hidden pick, pick 10\"") != null);
    try std.testing.expectEqual(1, std.mem.count(u8, s, "aria-pressed=\"true\""));
    try std.testing.expectEqual(1, std.mem.count(u8, s, "data-preview"));
    try std.testing.expect(std.mem.find(u8, s, "Jax") != null);
    try std.testing.expect(std.mem.find(u8, s, "aria-label=\"Blue Top, Gnar\"") != null);
    try std.testing.expect(std.mem.find(u8, s, "Red 52.1% from the lane") != null);
    try std.testing.expect(std.mem.find(u8, s, "aria-label=\"Blue 100") != null);
    try std.testing.expectEqual(1, std.mem.count(u8, s, "aria-label=\"Even\""));
    try std.testing.expect(std.mem.find(u8, s, "Empty seat") != null);
    try std.testing.expect(std.mem.find(u8, s, "class=\"uk\"") != null);
    try std.testing.expect(std.mem.find(u8, s, "12th") != null);
    try std.testing.expect(std.mem.find(u8, s, "NaN") == null and std.mem.find(u8, s, "nan") == null);
    for ([_]u32{ 1, 2, 3, 4, 11, 12, 13, 21, 22, 23, 111 }, [_][]const u8{ "st", "nd", "rd", "th", "th", "th", "th", "st", "nd", "rd", "th" }) |n, want| {
        try std.testing.expectEqualStrings(want, ordinal(n));
    }
    out = .init(a);
    try html.write(&t, fullOn(&h, .{ .v = .full, .lanes = &.{} }, &.{}), &out.writer);
    try std.testing.expect(std.mem.find(u8, out.written(), "class=\"lanes\"") != null);
}

test "the app's board stays encodable" {
    const data = @import("data.zig");
    _ = data.fingerprint(Board);
}
