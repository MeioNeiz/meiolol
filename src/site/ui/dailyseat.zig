//! Daily Draft's review after the reveal (docs/plan/ui/daily.md): the selected seat's
//! CandidateList (rows open their ReasonBreakdown, two at most) and On paper. Its own
//! island (ui-dailyseat.wasm), loaded by ui-daily.wasm once the puzzle is answered; the
//! answers and the board's selected seat from that island's root (`read`). Empty until
//! then; dailypage.layout places its cards beside and under the board. On paper's Try row
//! swaps the selected seat's pick for one of its listed others and moves the split
const std = @import("std");
const tree = @import("tree.zig");
const dd = @import("dailydata.zig");
const dp = @import("dailypage.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const card = @import("card.zig");
const badge = @import("badge.zig");
const draftboard = @import("draftboard.zig");
const candlist = @import("candlist.zig");
const reasons = @import("reasons.zig");
const split = @import("split.zig");
const toggletip = @import("toggletip.zig");
const chip = @import("chip.zig");
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
    /// The hidden seat's picks beyond the options shown
    more: bool = false,
    /// The pick On paper tries in the selected seat instead of the played one (champion)
    tried: ?u16 = null,
    /// The server's render: this family's files, for ui-daily.wasm to load
    js: []const u8 = "",
    wasm: []const u8 = "",

    pub const Msg = union(enum) { cand: u16, more, try_: u16 };

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
            .more => s.more = !s.more,
            .try_ => |c| s.tried = if (c == s.p.seats[s.seat / 5][s.seat % 5].champ or s.tried == c) null else c,
        }
    }

    /// The page island's root attributes: data-phase, data-seat and data-guess (the
    /// option index); a new seat closes the open rows
    pub fn read(s: *Seat, phase: []const u8, seat: []const u8, guess: []const u8) void {
        s.done = tree.eql(phase, "done");
        s.guess = if (digit(guess)) |g| (if (g < s.p.options.len) g else null) else null;
        const to = digit(seat) orelse dp.hiddenSeat(s.p);
        if (to != s.seat) {
            s.seat = to;
            s.open = .{ null, null };
            s.more = false;
            s.tried = null;
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
        const hidden = s.seat == dp.hiddenSeat(p);
        const mine: ?u16 = if (hidden) if (s.guess) |g| p.options[g] else null else null;
        // The options offered come first, the model's other picks folded under them
        const fold = hidden and offeredAll(p, x);
        var offered: usize = 0;
        var last: u16 = 0;
        for (x.cands) |c| {
            if (fold and !isOption(p, c.champ)) continue;
            s.row(h, &rows[offered], x, c, played, mine, side, rl, !fold and @as(u32, c.rank) > @as(u32, last) + 1);
            offered += 1;
            last = c.rank;
        }
        var rest = offered;
        if (fold) for (x.cands) |c| {
            if (isOption(p, c.champ)) continue;
            s.row(h, &rows[rest], x, c, played, mine, side, rl, false);
            rest += 1;
        };
        const pick = dp.pickOf(p, t, x.champ);
        const rated = toggletip.view(h, "ds-rated", .{W.rated}, W.rated, W.rated_note.with(h, .{ .c = s.champOf(x.champ).name, .n = x.of }));
        const head: [3]tree.Text = .{ W.chance.with(h, .{ .side = dp.sideWord(side).s }), W.with_, W.vs };
        return h.div(.{ .key = 1, .class = "seat" }, .{card.view(h, .{ .label = W.seat }, &.{
            // Kept across seats, so a screen reader hears which seat the panel now shows
            h.div(.{ .class = "sh", .aria_live = "polite" }, .{
                champ.view(h, s.champOf(x.champ), .{ .px = .@"40", .named = false }),
                h.div(.{}, .{
                    h.span(.{ .class = "nm" }, .{ h.b(.{}, .{s.champOf(x.champ).name}), badge.view(h, .accent, .{W.played}) }),
                    h.span(.{ .class = "sub" }, .{
                        if (pick) |n| W.where_pick.with(h, .{ .side = dp.sideWord(side).s, .r = rl.label().s, .n = n }) else W.where.with(h, .{ .side = dp.sideWord(side).s, .r = rl.label().s }),
                    }),
                }),
                if (x.rank) |n| h.span(.{ .class = "of" }, .{
                    h.span(.{}, .{&rated}),
                    h.b(.{}, .{W.nth.with(h, .{ .n = n, .s = draftboard.ordinal(n) })}),
                    h.span(.{}, .{W.of.with(h, .{ .n = x.of })}),
                    if (played) |c| if (c.behind) badge.view(h, .neutral, .{W.behind}) else null else null,
                }) else null,
            }),
            if (hidden) s.yours(h, x) else .none,
            if (fold) s.shares(h, x, rl) else .none,
            if (rows.len == 0) h.p(.{ .class = "none" }, .{W.unrated}) else candlist.view(h, .{ .rows = rows[0..offered], .head = head }),
            if (rest > offered) h.button(.{
                .key = 2,
                .class = "more",
                .type = "button",
                .aria_expanded = s.more,
                .on_click = h.on(s, .more),
            }, .{W.more.with(h, .{ .n = rest - offered })}) else .none,
            if (rest > offered and s.more) candlist.view(h, .{ .rows = rows[offered..rest] }) else .none,
        })});
    }

    fn row(s: *Seat, h: *H, out: *candlist.Row, x: dd.Seat, c: dd.Cand, played: ?dd.Cand, mine: ?u16, side: dd.Side, rl: role.Role, gap: bool) void {
        const nm = s.champOf(c.champ).name;
        const detail = if (c.terms.len == 0) null else s.breakdown(h, x, c, side, rl);
        out.* = .{
            .champ = s.champOf(c.champ),
            .rank = c.rank,
            .star = c.rank == 1,
            .ref = c.champ == x.champ,
            .win = c.win,
            .vs = if (c.champ == x.champ) null else if (played) |pc| c.win - pc.win else null,
            .reasons = s.chips(h, c, rl, side),
            .tag = if (c.behind and c.champ != x.champ) W.behind else null,
            .mark = if (c.champ == mine and c.champ != x.champ) W.yours_tag else null,
            .mark_k = .accent,
            .gap = gap,
            .open = detail != null and (s.open[0] == c.champ or s.open[1] == c.champ),
            .detail = detail,
            .label = if (detail != null) W.why.with(h, .{ .n = nm }) else null,
            .id = if (detail != null) h.fmt("dw-{d}", .{c.champ}) else "",
            .on = if (detail != null) h.on(s, .{ .cand = c.champ }) else null,
        };
    }

    /// How often each option is picked in the role, from the crowd's games (popularity,
    /// not this draft), largest first; the played one ringed
    fn shares(s: *const Seat, h: *H, x: dd.Seat, rl: role.Role) N {
        const p = s.p;
        if (p.picked.len != p.options.len) return .none;
        var total: u64 = 0;
        for (p.picked) |g| total += g;
        if (total == 0) return .none;
        var order: [6]u8 = undefined;
        const n = p.options.len;
        for (order[0..n], 0..) |*o, i| o.* = @intCast(i);
        std.sort.insertion(u8, order[0..n], p.picked, struct {
            fn more(g: []const u32, a: u8, b: u8) bool {
                return g[a] > g[b];
            }
        }.more);
        const top: f32 = @floatFromInt(p.picked[order[0]]);
        var cells = h.list();
        for (order[0..n]) |i| {
            const c = p.options[i];
            const g: f32 = @floatFromInt(p.picked[i]);
            const pct: i64 = @intFromFloat(@round(100 * g / @as(f32, @floatFromInt(total))));
            cells.add(h.div(.{ .key = @as(usize, c), .class = "sc", .data_ref = c == x.champ, .title = s.champOf(c).name }, .{
                champ.view(h, s.champOf(c), .{ .px = .@"24", .named = false }),
                h.span(.{ .class = "sr" }, .{s.champOf(c).name}),
                h.b(.{}, .{phrase.num(h, .pct, pct)}),
                h.span(.{ .class = "sb", .aria_hidden = true }, .{h.el(.i, .{ .style = h.vars(.{ .w = 100 * g / top }) }, .{})}),
            }));
        }
        const tip = toggletip.view(h, "ds-picked", .{W.picked}, W.picked, W.picked_note.with(h, .{ .n = total, .r = rl.label().s }));
        return h.div(.{ .key = 3, .class = "shares" }, .{
            h.div(.{ .class = "st" }, .{&tip}),
            h.div(.{ .class = "sg" }, .{cells.done()}),
        });
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

    fn paper(s: *Seat, h: *H) N {
        const pp = s.p.paper orelse return .none;
        const won = s.p.result.winner;
        const x = s.p.seats[s.seat / 5][s.seat % 5];
        const side: dd.Side = @fromBackingInt(@intCast(s.seat / 5));
        const played = candOf(x, x.champ);
        const tried: ?dd.Cand = if (s.tried) |c| if (played != null) candOf(x, c) else null else null;
        const at: Moved = if (tried) |c| moved(pp, side, played.?, c) else .{ .blue = pp.blue, .lo = pp.low, .hi = pp.high };
        var most: f32 = 0.5;
        for (pp.edges) |e| most = @max(most, @abs(e));
        var rows = h.list();
        // The edges are the played draft's terms: a tried pick shows only its change, on
        // their scale, so the bar keeps its width as picks are tried
        if (tried != null) {
            most = @max(most, @abs(at.blue - pp.blue));
            rows.add(edgeRow(h, 4, W.vs_played.with(h, .{ .n = s.champOf(x.champ).name }), at.blue - pp.blue, most));
        } else for (pp.edges, W.kinds, 0..) |e, k, i| rows.add(edgeRow(h, i, k, e, most));
        return h.div(.{ .key = 2, .class = "onpaper" }, .{card.view(h, .{ .label = W.paper }, &.{
            card.head(h, W.paper, null, &.{}),
            h.div(.{ .class = "paper" }, .{
                h.div(.{}, .{
                    s.tryRow(h, x, played),
                    split.view(h, .{
                        .p = at.blue,
                        .lo = at.lo,
                        .hi = at.hi,
                        .range_tip = "dp-range",
                        .won = if (tried != null) null else if (won == .blue) .blue else .red,
                        .s = .l,
                    }),
                    toggletip.tip(h, "dp-range", W.range, W.range_note, false),
                    h.p(.{ .class = "verdict" }, .{if (tried) |c|
                        W.instead.with(h, .{ .n = s.champOf(c.champ).name, .p = s.champOf(x.champ).name })
                    else
                        verdict(pp, won)}),
                }),
                h.div(.{ .class = "edges" }, .{rows.done()}),
            }),
        })});
    }

    /// The selected seat's picks in its list (the options offered on the hidden seat), the
    /// played one first and pressed until another is tried; none with fewer than two
    fn tryRow(s: *Seat, h: *H, x: dd.Seat, played: ?dd.Cand) ?N {
        const pc = played orelse return null;
        const fold = s.seat == dp.hiddenSeat(s.p) and offeredAll(s.p, x);
        var row_ = h.list();
        row_.add(s.tryChip(h, pc.champ, true));
        for (x.cands) |c| {
            if (c.champ == pc.champ or (fold and !isOption(s.p, c.champ))) continue;
            row_.add(s.tryChip(h, c.champ, false));
        }
        if (row_.items.items.len < 2) return null;
        return h.div(.{ .class = "try" }, .{
            h.span(.{ .class = "tl" }, .{W.try_in}),
            row_.done(),
        });
    }

    fn tryChip(s: *Seat, h: *H, c: u16, played: bool) N {
        const nm = s.champOf(c).name;
        const pressed = if (s.tried) |t| t == c else played;
        return chip.view(h, .{
            .pressed = pressed,
            .label = if (played) W.try_played.with(h, .{ .n = nm }) else W.try_.with(h, .{ .n = nm }),
            .on = h.on(s, .{ .try_ = c }),
        }, .{champ.view(h, s.champOf(c), .{ .px = .@"24", .named = false })});
    }
};

/// One kind's edge, points to blue (negative: red's), as a bar from the middle on a scale
/// of `most` points
fn edgeRow(h: *H, key: usize, label: tree.Text, e: f32, most: f32) N {
    const side: dd.Side = if (e >= 0) .blue else .red;
    // Edges come to one decimal: under 0.05 shows as 0.0
    const even = @abs(e) < 0.05;
    const w = 50 * @min(@abs(e) / most, 1);
    return h.div(.{ .key = key, .class = "e" }, .{
        h.span(.{ .class = "lab" }, .{label}),
        h.span(.{ .class = "bar", .aria_hidden = true }, .{if (even) null else h.el(.i, .{
            .data_side = dp.sideOf(side),
            .style = h.vars(.{ .l = if (side == .blue) 50 - w else 50, .w = w }),
        }, .{})}),
        h.span(.{ .class = "v", .data_side = if (even) null else dp.sideOf(side) }, .{
            if (even) W.edge_even else W.edge.with(h, .{ .side = dp.sideWord(side).s, .d = @abs(e) }),
        }),
    });
}

fn candOf(x: dd.Seat, c: u16) ?dd.Cand {
    for (x.cands) |k| if (k.champ == c) return k;
    return null;
}

pub const Moved = struct { blue: f32, lo: ?f32, hi: ?f32 };

/// Blue's chance with `c` in place of the seat's played pick: the played draft's chance
/// moved by the model's gap between the two, so the played pick reads exactly as the
/// draft. The range only where the pick has one
pub fn moved(pp: dd.Paper, side: dd.Side, played: dd.Cand, c: dd.Cand) Moved {
    const sign: f32 = if (side == .blue) 1 else -1;
    const at = struct {
        fn f(pp_: dd.Paper, sg: f32, from: f32, to: ?f32) ?f32 {
            return std.math.clamp(pp_.blue + sg * ((to orelse return null) - from), 0, 100);
        }
    }.f;
    const lo = if (side == .blue) c.low else c.high;
    const hi = if (side == .blue) c.high else c.low;
    return .{
        .blue = at(pp, sign, played.win, c.win).?,
        .lo = if (lo != null and hi != null) at(pp, sign, played.win, lo) else null,
        .hi = if (lo != null and hi != null) at(pp, sign, played.win, hi) else null,
    };
}

/// Which draft was better against who won, in words: the split above has the numbers.
/// Drafts seldom differ by much (most of a puzzle's blue chances are 44-56%), so a
/// point either side is even, and "better" only when the 95% range excludes even
pub fn verdict(pp: dd.Paper, won: dd.Side) tree.Text {
    if (@abs(pp.blue - 50) < 1) return if (won == .blue) W.even_blue else W.even_red;
    const better: dd.Side = if (pp.blue > 50) .blue else .red;
    const clear = pp.low > 50 or pp.high < 50;
    const i: usize = @as(usize, @intFromBool(clear)) * 4 + @as(usize, @backingInt(better)) * 2 + @intFromBool(better != won);
    return W.verdicts[i];
}

fn isOption(p: *const dd.Puzzle, c: u16) bool {
    return std.mem.findScalar(u16, p.options, c) != null;
}

/// Every option has a row: puzzles whose review ranks the options
fn offeredAll(p: *const dd.Puzzle, x: dd.Seat) bool {
    for (p.options) |o| {
        for (x.cands) |c| {
            if (c.champ == o) break;
        } else return false;
    }
    return true;
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
    const rated = plain("Rated");
    const rated_note = Phrase("{c:text}'s place among the {n:int} the model rates here. Clearly behind: beyond its 95% range of the top pick.");
    const behind = plain("clearly behind");
    const yours = Phrase("Your pick {n:text}");
    const yours_tag = plain("your pick");
    const played = plain("played");
    const more = Phrase("More picks ({n:int})");
    const picked = plain("Pick share");
    const picked_note = Phrase("Each option's share of {n:count} ranked {r:text} games with one of them: how popular it is, not how well it fits this draft.");
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
    const edge = Phrase("{side:text} {d:points} points");
    const edge_even = plain("Even");
    const try_in = plain("Try");
    const try_ = Phrase("Try {n:text}");
    const try_played = Phrase("{n:text}, played");
    const instead = Phrase("With {n:text} instead of {p:text}.");
    const vs_played = Phrase("vs {n:text}");
    const range = plain("95% range");
    const range_note = plain("The model's 95% range, given its assumptions.");
    const even_blue = plain("Even drafts. Blue won.");
    const even_red = plain("Even drafts. Red won.");
    /// By [range clear of even][better side][an upset]
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
    \\  .c-dseat .sh .nm { display: flex; align-items: center; gap: var(--sp-2); min-width: 0; }
    \\  .c-dseat .shares { display: grid; gap: var(--sp-2); padding: var(--sp-3) 0; border-bottom: 1px solid var(--line); }
    \\  .c-dseat .st { font-size: var(--fs-xs); color: var(--faint); }
    \\  .c-dseat .sg { display: grid; grid-template-columns: repeat(auto-fill, minmax(76px, 1fr)); gap: var(--sp-2); }
    \\  .c-dseat .sc { display: grid; grid-template-columns: auto minmax(0, 1fr); align-items: center; gap: 4px 6px;
    \\    padding: 4px 6px; border-radius: var(--r-s); }
    \\  .c-dseat .sc[data-ref] { box-shadow: inset 0 0 0 1px var(--accent); }
    \\  .c-dseat .sc b { text-align: right; font-weight: var(--w-b); font-variant-numeric: tabular-nums; }
    \\  .c-dseat .sb { grid-column: 1 / -1; height: 4px; border-radius: 2px; background: var(--line-2); overflow: hidden; }
    \\  .c-dseat .sb i { display: block; height: 100%; width: calc(var(--w) * 1%); background: var(--muted); }
    \\  .c-dseat .sc[data-ref] .sb i { background: var(--accent); }
    \\  .c-dseat .more { all: unset; cursor: pointer; box-sizing: border-box; width: 100%; min-height: 36px; padding: 0 var(--sp-2);
    \\    color: var(--muted); font-size: var(--fs-s); border-bottom: 1px solid var(--line); }
    \\  .c-dseat .more::after { content: " ▾"; }
    \\  .c-dseat .more[aria-expanded="true"]::after { content: " ▴"; }
    \\  .c-dseat .more:hover { color: var(--text); background: var(--panel-2); }
    \\  .c-dseat .more:focus-visible { outline: 2px solid var(--focus); outline-offset: -2px; }
    \\  .c-dseat .of { display: grid; justify-items: end; font-size: var(--fs-xs); color: var(--muted); }
    \\  .c-dseat .of > b { font-size: var(--fs-l); color: var(--text); }
    \\  .c-dseat .yours { display: flex; align-items: center; gap: var(--sp-2); margin: var(--sp-3) 0 0; font-size: var(--fs-s); color: var(--t2); }
    \\  .c-dseat .none { color: var(--muted); font-size: var(--fs-s); }
    \\  .c-dseat .paper { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: var(--sp-4); align-items: center; }
    \\  .c-dseat .try { display: flex; flex-wrap: wrap; align-items: center; gap: var(--sp-2); margin-bottom: var(--sp-3); }
    \\  .c-dseat .try .tl { font-size: var(--fs-xs); color: var(--faint); }
    \\  .c-dseat .verdict { margin: var(--sp-3) 0 0; font-size: var(--fs-s); color: var(--t2); }
    \\  .c-dseat .edges { display: grid; grid-template-columns: auto minmax(0, 1fr) auto; gap: 6px var(--sp-2); align-items: center;
    \\    font-size: var(--fs-s); }
    \\  .c-dseat .edges .lab { color: var(--t2); }
    \\  .c-dseat .e { display: contents; }
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
    if (h.mem.create(dd.Puzzle)) |m| {
        // A model's pick not offered: folded under the options, here opened
        m.* = dd.sample;
        var seats = m.seats;
        const hs = &seats[1][0];
        const cs = h.mem.alloc(dd.Cand, hs.cands.len + 1) catch {
            h.oom = true;
            return;
        };
        cs[0] = .{ .champ = 9, .rank = 1, .win = 50.3, .terms = &.{}, .rest = 0 };
        for (hs.cands, cs[1..]) |c, *x| {
            x.* = c;
            x.rank += 1;
        }
        hs.cands = cs;
        m.seats = seats;
        if (dp.shown(h, m, 0, 0, .blue)) |p| if (h.mem.create(Seat)) |x| {
            x.* = .{ .p = m, .seat = p.seat, .guess = p.guess, .done = true, .more = true };
            g.addFill("more picks opened", dp.layout(h, p.view(h), x.view(h)));
        } else |_| {
            h.oom = true;
        };
    } else |_| h.oom = true;
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
    if (dp.shown(h, &dd.sample, 1, 1, .red)) |p| if (h.mem.create(Seat)) |x| {
        x.* = .{ .p = p.p, .seat = p.seat, .guess = p.guess, .done = true, .tried = 10 };
        g.addFill("tried: another option On paper", dp.layout(h, p.view(h), x.view(h)));
    } else |_| {
        h.oom = true;
    };
}
