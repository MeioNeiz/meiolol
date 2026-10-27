//! ReasonBreakdown: why one pick lands where it does, as a waterfall from the role's
//! average: one cumulative step per term (strength, into X, with Y, rest), its points and
//! games, then the total with its 95% range. Opens under a CandidateList row (Daily's
//! seat panel, the draft tester, the desktop's "why"). Words mode (the public app, no
//! numbers: production-key product rules; docs/plan/ui/why.md) keeps the terms as words
//! with a direction only
const tree = @import("tree.zig");
const fmt = @import("fmt.zig");
const toggletip = @import("toggletip.zig");
const phrase = @import("phrase.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "ReasonBreakdown";
pub const scope = .{".c-wf"};

pub const Mode = enum { points, words };

pub const Term = struct {
    /// "Top strength", "Into K'Sante"
    label: tree.Text,
    /// Win chance points this term moves the pick's team
    pp: f32,
    /// Games behind the term; null for the rest
    games: ?u32 = null,
};

pub const Breakdown = struct {
    /// "Average top"
    base_label: tree.Text,
    /// Win chance, %
    base: f32,
    terms: []const Term,
    /// Whatever the named terms leave (small pairs summed), points; null for none
    rest: ?f32 = null,
    /// "Red with Jayce"
    total_label: tree.Text,
    /// 95% range of the total, %
    low: ?f32 = null,
    high: ?f32 = null,
    mode: Mode = .points,
    /// Page-unique id for the rest's toggletip; "" for none
    tip_id: []const u8 = "",
};

pub fn total(b: Breakdown) f32 {
    var t = b.base + (b.rest orelse 0);
    for (b.terms) |x| t += x.pp;
    return t;
}

pub fn view(h: *H, b: Breakdown) N {
    if (b.mode == .words) return words(h, b);
    const sc = Scale.of(b);
    var rows = h.list();
    var cum = b.base;
    rows.add(h.span(.{ .class = "lab" }, .{b.base_label}));
    rows.add(h.span(.{ .class = "trk" }, .{h.b(.{ .style = h.vars(.{ .l = sc.x(b.base) }) }, .{})}));
    rows.add(h.span(.{ .class = "v" }, .{phrase.num(h, .rate, b.base)}));
    rows.add(h.span(.{ .class = "g" }, .{}));
    var first_games = true;
    for (b.terms, 0..) |t, i| {
        rows.add(h.span(.{ .key = 4 * i + 4, .class = "lab" }, .{t.label}));
        rows.add(step(h, sc, cum, t.pp, 4 * i + 5));
        rows.add(value(h, t.pp, 4 * i + 6));
        rows.add(h.span(.{ .key = 4 * i + 7, .class = "g" }, .{if (t.games) |g| if (first_games) blk: {
            first_games = false;
            break :blk W.games.with(h, .{ .n = g });
        } else phrase.num(h, .kilo, g) else null}));
        cum += t.pp;
    }
    var tip: ?N = null;
    if (b.rest) |r| {
        const k = 4 * b.terms.len + 4;
        if (b.tip_id.len > 0) {
            const tt = toggletip.view(h, b.tip_id, .{W.rest}, W.rest, W.rest_note);
            rows.add(h.span(.{ .key = k, .class = "lab" }, .{tt[0]}));
            tip = tt[1];
        } else rows.add(h.span(.{ .key = k, .class = "lab" }, .{W.rest}));
        rows.add(step(h, sc, cum, r, k + 1));
        rows.add(value(h, r, k + 2));
        rows.add(h.span(.{ .key = k + 3, .class = "g" }, .{}));
        cum += r;
    }
    const band: ?N = if (b.low != null and b.high != null) h.el(.s, .{ .style = h.vars(.{
        .l = sc.x(b.low.?),
        .w = sc.x(b.high.?) - sc.x(b.low.?),
    }) }, .{}) else null;
    return h.div(.{ .class = "c-wf" }, .{
        rows.done(),
        h.span(.{ .class = "lab tot" }, .{b.total_label}),
        h.span(.{ .class = "trk tot" }, .{ band, h.b(.{ .class = "at", .style = h.vars(.{ .l = sc.x(cum) }) }, .{}) }),
        h.span(.{ .class = "v tot" }, .{phrase.num(h, .rate, cum)}),
        h.span(.{ .class = "g tot" }, .{if (band != null) W.range.with(h, .{ .lo = b.low.?, .hi = b.high.? }) else null}),
        tip,
    });
}

fn step(h: *H, sc: Scale, from: f32, pp: f32, key: usize) N {
    const a = sc.x(@min(from, from + pp));
    return h.span(.{ .key = key, .class = "trk" }, .{h.el(.i, .{ .style = h.vars(.{
        .l = a,
        .w = sc.x(@max(from, from + pp)) - a,
        .c = fmt.Step.of(pp, fmt.win_cuts),
    }) }, .{})});
}

fn value(h: *H, pp: f32, key: usize) N {
    return h.span(.{ .key = key, .class = "v", .style = h.vars(.{ .c = fmt.Step.of(pp, fmt.win_cuts) }) }, .{phrase.num(h, .points, pp)});
}

/// No numbers: each term as words and a direction
fn words(h: *H, b: Breakdown) N {
    var rows = h.list();
    for (b.terms, 0..) |t, i| rows.add(h.span(.{ .key = i, .class = "dir", .data_up = t.pp > 0 }, .{
        t.label,
        h.span(.{ .aria_hidden = true }, .{if (t.pp > 0) "▲" else "▼"}),
    }));
    return h.div(.{ .class = "c-wf", .data_v = Mode.words }, .{rows.done()});
}

/// The track's span: every point the waterfall passes, padded
const Scale = struct {
    lo: f32,
    hi: f32,

    fn of(b: Breakdown) Scale {
        var lo = b.base;
        var hi = b.base;
        var cum = b.base;
        for (b.terms) |t| {
            cum += t.pp;
            lo = @min(lo, cum);
            hi = @max(hi, cum);
        }
        cum += b.rest orelse 0;
        lo = @min(lo, cum);
        hi = @max(hi, cum);
        if (b.low) |l| lo = @min(lo, l);
        if (b.high) |top| hi = @max(hi, top);
        const pad = @max(0.5, (hi - lo) * 0.08);
        return .{ .lo = lo - pad, .hi = hi + pad };
    }

    fn x(s: Scale, v: f32) f32 {
        return 100 * (v - s.lo) / (s.hi - s.lo);
    }
};

const W = struct {
    const games = phrase.Phrase("{n:kilo} games");
    const rest = plain("Rest");
    const rest_note = plain("Every other pairing in the draft, summed.");
    const range = phrase.Phrase("{lo:dec}–{hi:dec}");
};

pub const css =
    \\@layer components {
    \\  .c-wf { display: grid; grid-template-columns: minmax(84px, auto) minmax(64px, 1fr) auto auto; gap: 3px var(--sp-3);
    \\    align-items: center; padding: var(--sp-2) 0; font-size: var(--fs-s); font-variant-numeric: tabular-nums;
    \\    min-width: 0; }
    \\  .c-wf .lab { color: var(--t2); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    \\  .c-wf .trk { position: relative; height: 14px; }
    \\  .c-wf .trk > i { position: absolute; top: 3px; height: 8px; left: calc(var(--l) * 1%); width: calc(var(--w) * 1%);
    \\    min-width: 2px; border-radius: 2px; background: var(--c); }
    \\  .c-wf .trk > b { position: absolute; top: 0; bottom: 0; left: calc(var(--l) * 1%); width: 2px; margin-left: -1px;
    \\    background: var(--t2); }
    \\  .c-wf .trk > s { position: absolute; top: 3px; height: 8px; left: calc(var(--l) * 1%); width: calc(var(--w) * 1%);
    \\    border-radius: 2px; background: var(--bar-hi); opacity: 0.35; }
    \\  .c-wf .trk > .at { background: var(--text); }
    \\  .c-wf .v { text-align: right; font-weight: var(--w-b); color: var(--c, var(--text)); }
    \\  .c-wf .g { text-align: right; font-size: var(--fs-xs); color: var(--faint); white-space: nowrap; }
    \\  .c-wf .tot { border-top: 1px solid var(--line); padding-top: 4px; font-weight: var(--w-b); color: var(--text);
    \\    align-self: stretch; display: flex; align-items: center; }
    \\  .c-wf .v.tot, .c-wf .g.tot { justify-content: flex-end; }
    \\  .c-wf .trk.tot { display: block; height: auto; min-height: 14px; }
    \\  .c-wf[data-v="words"] { display: flex; flex-wrap: wrap; gap: 4px var(--sp-3); }
    \\  .c-wf .dir { display: inline-flex; align-items: center; gap: 4px; color: var(--t2); }
    \\  .c-wf .dir > span { color: var(--lo2); font-size: var(--fs-xs); }
    \\  .c-wf .dir[data-up] > span { color: var(--hi2); }
    \\  @container (max-width: 340px) {
    \\    .c-wf { grid-template-columns: minmax(72px, auto) minmax(40px, 1fr) auto; }
    \\    .c-wf .g { display: none; }
    \\  }
    \\}
    \\
;

/// Daily #11's red top: Jayce, played, third of 31
pub const sample: Breakdown = .{
    .base_label = plain("Average top"),
    .base = 47.5,
    .terms = &.{
        .{ .label = plain("Top strength"), .pp = 0.6, .games = 4100 },
        .{ .label = plain("Into K'Sante"), .pp = 0.9, .games = 1200 },
        .{ .label = plain("With Vi"), .pp = 0.2, .games = 880 },
        .{ .label = plain("Into Viktor"), .pp = -0.4, .games = 2300 },
    },
    .rest = 0.1,
    .total_label = plain("Red with Jayce"),
    .low = 47.6,
    .high = 50.2,
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    var s = sample;
    s.tip_id = g.id("wf-rest");
    g.addFill("points, range, rest", view(h, s));
    g.addFill("below the average, no range", view(h, .{
        .base_label = plain("Average bot"),
        .base = 48.9,
        .terms = &.{
            .{ .label = plain("Bot strength"), .pp = -1.1, .games = 37000 },
            .{ .label = plain("Into Yuumi"), .pp = -0.8, .games = 1000 },
            .{ .label = plain("With Leona"), .pp = 0.3, .games = 660 },
        },
        .total_label = plain("Blue with Jinx"),
    }));
    var t = sample;
    t.mode = .words;
    g.addFill("words, public app", view(h, t));
}
