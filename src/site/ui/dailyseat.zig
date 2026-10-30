//! Daily Draft's review after the reveal (docs/plan/ui/daily.md): the selected seat's
//! CandidateList (rows open their ReasonBreakdown, two at most) and On paper. Its own
//! island (ui-dailyseat.wasm), loaded by ui-daily.wasm once the puzzle is answered; the
//! answers and the board's selected seat from that island's root (`read`). Empty until
//! then; dailypage.layout places its cards beside and under the board
const std = @import("std");
const tree = @import("tree.zig");
const dd = @import("dailydata.zig");
const dp = @import("dailypage.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const card = @import("card.zig");
const draftboard = @import("draftboard.zig");
const candlist = @import("candlist.zig");
const reasons = @import("reasons.zig");
const split = @import("split.zig");
const toggletip = @import("toggletip.zig");
const phrase = @import("phrase.zig");
const plain = phrase.plain;
const Phrase = phrase.Phrase;
const H = tree.H;
const N = tree.N;

pub const name = "DailySeat";
pub const scope = .{".c-dseat"};
pub const sel = "[data-island=dailyseat]";

pub const Seat = struct {
    p: *const dd.Puzzle,
    /// The board's selected seat: side * 5 + role
    seat: u8,
    /// The option locked in (index into p.options)
    guess: ?u8 = null,
    done: bool = false,
    /// Candidate rows open (champion indexes)
    open: [2]?u16 = .{ null, null },
    /// The server's render: this family's files, for ui-daily.wasm to load
    js: []const u8 = "",
    wasm: []const u8 = "",

    pub const Msg = union(enum) { cand: u16 };

    pub fn init(_: std.mem.Allocator, p: *const dd.Puzzle) Seat {
        return .{ .p = p, .seat = dp.hiddenSeat(p) };
    }

    pub fn update(s: *Seat, m: Msg, _: *tree.Event) void {
        switch (m) {
            .cand => |c| {
                if (s.open[0] == c) {
                    s.open = .{ s.open[1], null };
                } else if (s.open[1] == c) {
                    s.open[1] = null;
                } else {
                    const keep = s.open[0];
                    s.open = .{ c, keep };
                }
            },
        }
    }

    /// The page island's root attributes: data-phase, data-seat and data-guess (the
    /// option index); a new seat closes the open rows
    pub fn read(s: *Seat, phase: []const u8, seat: []const u8, guess: []const u8) void {
        s.done = std.mem.eql(u8, phase, "done");
        s.guess = if (digit(guess)) |g| (if (g < s.p.options.len) g else null) else null;
        const to = digit(seat) orelse dp.hiddenSeat(s.p);
        if (to != s.seat) {
            s.seat = to;
            s.open = .{ null, null };
        }
    }

    pub fn view(s: *Seat, h: *H) N {
        return h.div(.{
            .class = "c-dseat",
            .data_island = "dailyseat",
            .data_js = if (s.js.len > 0) s.js else null,
            .data_wasm = if (s.wasm.len > 0) s.wasm else null,
        }, .{
            // Under the board in one column, as before the seat
            if (s.done) s.paper(h) else null,
            if (s.done) s.panel(h) else null,
        });
    }

    fn champOf(s: *const Seat, i: u16) champ.Champ {
        return s.p.champs[i];
    }

    fn panel(s: *Seat, h: *H) N {
        const p = s.p;
        const t = s.seat / 5;
        const r = s.seat % 5;
        const x = p.seats[t][r];
        const side: dd.Side = @fromBackingInt(@intCast(t));
        const rl = role.Role.all[r];
        const played = for (x.cands) |c| {
            if (c.champ == x.champ) break c;
        } else null;
        const rows = h.mem.alloc(candlist.Row, x.cands.len) catch {
            h.oom = true;
            return .none;
        };
        const mine: ?u16 = if (s.seat == dp.hiddenSeat(p)) if (s.guess) |g| p.options[g] else null else null;
        var last: u16 = 0;
        for (rows, x.cands) |*row, c| {
            const nm = s.champOf(c.champ).name;
            const detail = if (c.terms.len == 0) null else s.breakdown(h, x, c, side, rl);
            row.* = .{
                .champ = s.champOf(c.champ),
                .rank = c.rank,
                .star = c.rank == 1,
                .ref = c.champ == x.champ,
                .win = c.win,
                .vs = if (c.champ == x.champ) null else if (played) |pc| c.win - pc.win else null,
                .reasons = s.chips(h, c, rl, side),
                .tag = if (c.champ == mine and c.champ != x.champ) W.yours_tag else null,
                .gap = @as(u32, c.rank) > @as(u32, last) + 1,
                .open = detail != null and (s.open[0] == c.champ or s.open[1] == c.champ),
                .detail = detail,
                .label = if (detail != null) W.why.with(h, .{ .n = nm }) else null,
                .id = if (detail != null) h.fmt("dw-{d}", .{c.champ}) else "",
                .on = if (detail != null) h.on(s, .{ .cand = c.champ }) else null,
            };
            last = c.rank;
        }
        const pick = dp.pickOf(p, t, x.champ);
        return h.div(.{ .key = 1, .class = "seat" }, .{card.view(h, .{ .label = W.seat }, &.{
            // Kept across seats, so a screen reader hears which seat the panel now shows
            h.div(.{ .class = "sh", .aria_live = "polite" }, .{
                champ.view(h, s.champOf(x.champ), .{ .px = .@"40", .named = false }),
                h.div(.{}, .{
                    h.b(.{}, .{s.champOf(x.champ).name}),
                    h.span(.{ .class = "sub" }, .{
                        if (pick) |n| W.where_pick.with(h, .{ .side = dp.sideWord(side).s, .r = rl.label().s, .n = n }) else W.where.with(h, .{ .side = dp.sideWord(side).s, .r = rl.label().s }),
                    }),
                }),
                if (x.rank) |n| h.span(.{ .class = "of" }, .{
                    h.b(.{}, .{W.nth.with(h, .{ .n = n, .s = draftboard.ordinal(n) })}),
                    h.span(.{}, .{W.of.with(h, .{ .n = x.of })}),
                }) else null,
            }),
            if (s.seat == dp.hiddenSeat(p)) s.yours(h, x) else .none,
            if (rows.len > 0) candlist.view(h, .{ .rows = rows, .head = .{ W.chance.with(h, .{ .side = dp.sideWord(side).s }), W.with_, W.vs } }) else h.p(.{ .class = "none" }, .{W.unrated}),
        })});
    }

    /// The pick locked in, when neither the played one nor in the list (where it is tagged:
    /// puzzles whose review ranks the options)
    fn yours(s: *const Seat, h: *H, x: dd.Seat) N {
        const g = s.guess orelse return .none;
        const c = s.p.options[g];
        if (c == x.champ) return .none;
        for (x.cands) |k| if (k.champ == c) return .none;
        return h.p(.{ .class = "yours" }, .{
            champ.view(h, s.champOf(c), .{ .px = .@"20", .named = false }),
            W.yours.with(h, .{ .n = s.champOf(c).name }),
        });
    }

    /// Up to three of the pick's largest terms. Strength as the role icon, a pair as the
    /// other champion in its team's ring: the words go to the chip's title and the
    /// opened breakdown
    fn chips(s: *const Seat, h: *H, c: dd.Cand, rl: role.Role, side: dd.Side) []const candlist.Reason {
        var idx: [3]usize = undefined;
        var n: usize = 0;
        for (c.terms, 0..) |t, i| {
            var at = n;
            while (at > 0 and @abs(c.terms[idx[at - 1]].pp) < @abs(t.pp)) : (at -= 1) {
                if (at < 3) idx[at] = idx[at - 1];
            }
            if (at < 3) idx[at] = i;
            n = @min(n + 1, 3);
        }
        const out = h.mem.alloc(candlist.Reason, n) catch {
            h.oom = true;
            return &.{};
        };
        for (out, idx[0..n]) |*o, i| {
            const t = c.terms[i];
            o.* = .{ .pp = t.pp, .text = switch (t.kind) {
                .strength => W.strength.with(h, .{ .r = rl.label().s }),
                .into => W.into_l.with(h, .{ .n = s.otherName(t) }),
                .with => W.with_l.with(h, .{ .n = s.otherName(t) }),
            } };
            // The board's rings: blue is us
            o.pic = if (t.kind == .strength)
                role.view(h, rl, .{ .s = .s, .named = false })
            else if (t.other) |x|
                champ.view(h, s.champOf(x), .{ .px = .@"20", .side = if ((t.kind == .with) == (side == .blue)) .us else .them, .named = false })
            else
                null;
        }
        return out;
    }

    fn otherName(s: *const Seat, t: dd.Term) []const u8 {
        return if (t.other) |o| s.champOf(o).name else "?";
    }

    fn breakdown(s: *const Seat, h: *H, x: dd.Seat, c: dd.Cand, side: dd.Side, rl: role.Role) reasons.Breakdown {
        const terms = h.mem.alloc(reasons.Term, c.terms.len) catch {
            h.oom = true;
            return .{ .base_label = W.even, .base = x.base, .terms = &.{}, .total_label = W.even };
        };
        for (terms, c.terms) |*o, t| o.* = .{
            .label = switch (t.kind) {
                .strength => W.strength.with(h, .{ .r = rl.label().s }),
                .into => W.into.with(h, .{ .n = s.otherName(t) }),
                .with => W.with.with(h, .{ .n = s.otherName(t) }),
            },
            .pp = t.pp,
            .games = t.games,
        };
        return .{
            .base_label = W.even,
            .base = x.base,
            .terms = terms,
            .rest = if (c.rest != 0) c.rest else null,
            .total_label = W.side_with.with(h, .{ .side = dp.sideWord(side).s, .n = s.champOf(c.champ).name }),
            .low = c.low,
            .high = c.high,
            .tip_id = h.fmt("dr-{d}", .{c.champ}),
        };
    }

    fn paper(s: *const Seat, h: *H) N {
        const pp = s.p.paper orelse return .none;
        var rows = h.list();
        var most: f32 = 0.5;
        for (pp.edges) |e| most = @max(most, @abs(e));
        for (pp.edges, W.kinds, 0..) |e, k, i| {
            const side: dd.Side = if (e >= 0) .blue else .red;
            const w = 50 * @min(@abs(e) / most, 1);
            rows.add(h.div(.{ .key = i, .class = "e" }, .{
                h.span(.{ .class = "lab" }, .{k}),
                h.span(.{ .class = "bar", .aria_hidden = true }, .{h.el(.i, .{
                    .data_side = dp.sideOf(side),
                    .style = h.vars(.{ .l = if (side == .blue) 50 - w else 50, .w = w }),
                }, .{})}),
                h.span(.{ .class = "v", .data_side = dp.sideOf(side) }, .{W.edge.with(h, .{ .side = dp.sideWord(side).s, .d = @abs(e) })}),
            }));
        }
        const won = s.p.result.winner;
        return h.div(.{ .key = 2, .class = "onpaper" }, .{card.view(h, .{ .label = W.paper }, &.{
            card.head(h, W.paper, null, &.{}),
            h.div(.{ .class = "paper" }, .{
                h.div(.{}, .{
                    split.view(h, .{
                        .p = pp.blue,
                        .lo = pp.low,
                        .hi = pp.high,
                        .range_tip = "dp-range",
                        .won = if (won == .blue) .blue else .red,
                        .s = .l,
                    }),
                    toggletip.tip(h, "dp-range", W.range, W.range_note, false),
                    h.p(.{ .class = "verdict" }, .{verdict(pp.blue, won)}),
                }),
                h.div(.{ .class = "edges" }, .{rows.done()}),
            }),
        })});
    }
};

/// Which draft was better against who won, in words: the split above has the numbers.
/// Drafts seldom differ by much (most of a puzzle's blue chances are 44-56%), so a
/// point either side is even and under four is "slightly"
pub fn verdict(blue: f32, won: dd.Side) tree.Text {
    const lead = @abs(blue - 50);
    if (lead < 1) return if (won == .blue) W.even_blue else W.even_red;
    const better: dd.Side = if (blue > 50) .blue else .red;
    const i: usize = @as(usize, @intFromBool(lead >= 4)) * 4 + @as(usize, @backingInt(better)) * 2 + @intFromBool(better != won);
    return W.verdicts[i];
}

fn digit(v: []const u8) ?u8 {
    return if (v.len == 1 and v[0] >= '0' and v[0] <= '9') v[0] - '0' else null;
}

const W = struct {
    const seat = plain("The selected seat");
    const where = Phrase("{side:text} {r:text}");
    const where_pick = Phrase("{side:text} {r:text} · pick {n:int}");
    const nth = Phrase("{n:int}{s:text}");
    const of = Phrase("of {n:int}");
    const yours = Phrase("Your pick {n:text}");
    const yours_tag = plain("your pick");
    const chance = Phrase("{side:text}'s win chance");
    const with_ = plain("with");
    const vs = plain("vs played");
    const unrated = plain("The model can't rate this seat.");
    const why = Phrase("Why {n:text}");
    const into_l = Phrase("into {n:text}");
    const with_l = Phrase("with {n:text}");
    const even = plain("Even game");
    const strength = Phrase("{r:text} strength");
    const into = Phrase("Into {n:text}");
    const with = Phrase("With {n:text}");
    const side_with = Phrase("{side:text} with {n:text}");
    const paper = plain("On paper");
    const kinds = [4]tree.Text{ plain("Champions"), plain("Teammates"), plain("Lanes"), plain("Matchups") };
    const edge = Phrase("{side:text} {d:points}");
    const range = plain("95% range");
    const range_note = plain("How sure the model is of this draft's chance: it would land in this range 19 times in 20.");
    const even_blue = plain("Even drafts. Blue won.");
    const even_red = plain("Even drafts. Red won.");
    /// By [better by 4+][better side][an upset]
    const verdicts = [8]tree.Text{
        plain("Blue's draft was slightly better, and blue won."),
        plain("Blue's draft was slightly better, but red won."),
        plain("Red's draft was slightly better, and red won."),
        plain("Red's draft was slightly better, but blue won."),
        plain("Blue's draft was better, and blue won."),
        plain("Blue's draft was better, but red won."),
        plain("Red's draft was better, and red won."),
        plain("Red's draft was better, but blue won."),
    };
};

pub const css =
    \\@layer components {
    \\  .c-dseat { display: contents; }
    \\  .c-dseat > * { min-width: 0; }
    \\  .c-dseat > .seat { grid-column: 2; grid-row: 1 / span 2; }
    \\  .c-dseat > .onpaper { grid-column: 1; grid-row: 2; }
    \\  .c-dseat .sh { display: grid; grid-template-columns: auto minmax(0, 1fr) auto; gap: var(--sp-3); align-items: center;
    \\    padding-bottom: var(--sp-3); border-bottom: 1px solid var(--line); }
    \\  .c-dseat .sh .sub { display: block; font-size: var(--fs-s); color: var(--muted); }
    \\  .c-dseat .of { display: grid; justify-items: end; font-size: var(--fs-xs); color: var(--muted); }
    \\  .c-dseat .of b { font-size: var(--fs-l); color: var(--text); }
    \\  .c-dseat .yours { display: flex; align-items: center; gap: var(--sp-2); margin: var(--sp-3) 0 0; font-size: var(--fs-s); color: var(--t2); }
    \\  .c-dseat .none { color: var(--muted); font-size: var(--fs-s); }
    \\  .c-dseat .paper { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: var(--sp-4); align-items: center; }
    \\  .c-dseat .verdict { margin: var(--sp-3) 0 0; font-size: var(--fs-s); color: var(--t2); }
    \\  .c-dseat .edges { display: grid; gap: 6px; }
    \\  .c-dseat .edges .lab { color: var(--t2); }
    \\  .c-dseat .e { display: grid; grid-template-columns: 96px minmax(0, 1fr) 80px; gap: var(--sp-2); align-items: center; font-size: var(--fs-s); }
    \\  .c-dseat .e .bar { position: relative; height: 8px; background: linear-gradient(var(--line-2), var(--line-2)) 50% / 1px 100% no-repeat; }
    \\  .c-dseat .e .bar i { position: absolute; top: 0; bottom: 0; left: calc(var(--l) * 1%); width: calc(var(--w) * 1%); border-radius: 2px; }
    \\  .c-dseat .e .bar i[data-side="us"] { background: var(--us); }
    \\  .c-dseat .e .bar i[data-side="them"] { background: var(--them); }
    \\  .c-dseat .e .v { text-align: right; font-variant-numeric: tabular-nums; font-weight: var(--w-m); }
    \\  .c-dseat .e .v[data-side="us"] { color: var(--us); }
    \\  .c-dseat .e .v[data-side="them"] { color: var(--them); }
    \\  @container daily (max-width: 1400px) { .c-dseat > :is(.seat, .onpaper) { grid-column: 1; grid-row: auto; } }
    \\  @container daily (max-width: 760px) { .c-dseat .paper { grid-template-columns: minmax(0, 1fr); } }
    \\}
    \\
;

pub fn gallery(g: *@import("gallery.zig").Gallery) void {
    const h = g.h;
    if (dp.shown(h, &dd.sample, 2, 2, .blue)) |p| g.addFill("wrong pick: yours tagged in the list, On paper", dp.both(h, p, .{ null, null }));
    if (h.mem.create(dd.Puzzle)) |old| {
        // A review from before the options' ranks: the hidden seat lists the played one only
        old.* = dd.sample;
        var seats = old.seats;
        const x = &seats[@backingInt(old.hidden_side)][@backingInt(old.hidden_role)];
        x.cands = x.cands[x.cands.len - 1 ..];
        old.seats = seats;
        if (dp.shown(h, old, 2, 2, .blue)) |p| g.addFill("wrong pick off the list: named in a line", dp.both(h, p, .{ null, null }));
    } else |_| h.oom = true;
    if (dp.shown(h, &dd.sample, 0, 0, .blue)) |p| {
        p.seat = 1;
        g.addFill("another seat, one the model can't rate", dp.both(h, p, .{ null, null }));
    }
    if (dp.shown(h, &dp.pro, 1, 1, .red)) |p| g.addFill("the played pick's reasons open", dp.both(h, p, .{ 5, null }));
}
