//! Rate: a win rate, the one way one is shown. Its colour is the rate itself on the
//! site's diverging scale (fmt.WrColour), read against 50 unless the caller names its own
//! ref (BuildPanel: the slot's rate over its options; a ranking: the stat's usual). How
//! sure it is: its games, small and faint after it in a fixed slot, so a column's figures
//! stay aligned; its 80% range's ends and the full count on hover, never a ± figure;
//! faded (var(--fade)) past fmt.wide_range, never hidden (J35); whole once the range is
//! 10 or wider, its tenths saying nothing. A model's estimate has none of these, nor a
//! colour: it isn't the win rate itself; its list's order and vs carry the ranking.
//! Screen readers get words ("win rate 52.3%, 33,108 games"): phones never read a title.
//! `delta`: a difference of rates in points, same colour and fade
const tree = @import("tree.zig");
const fmt = @import("fmt.zig");
const phrase = @import("phrase.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "Rate";
pub const scope = .{".c-rate"};

pub const Rate = struct {
    /// %
    pct: f64,
    /// Null: a model's estimate (draft win chance): no count, range, fade or colour. 0: no
    /// figure
    games: ?u32 = null,
    /// 80% half-width in points (fmt.range)
    half: ?f64 = null,
    /// The colour reads pct − ref
    ref: f64 = 50,

    pub fn counted(games: u32, wins: u32) Rate {
        const n: f64 = @floatFromInt(@max(games, 1));
        return .{ .pct = 100 * @as(f64, @floatFromInt(@min(wins, games))) / n, .games = games, .half = fmt.range(games, wins) };
    }

    /// From a rate in % where the wins aren't at hand
    pub fn at(games: u32, pct: f64) Rate {
        return .{ .pct = pct, .games = games, .half = fmt.rangeAt(games, pct) };
    }

    pub fn estimate(pct: f64) Rate {
        return .{ .pct = pct };
    }
};

pub const Look = struct {
    /// "51.2%"; false "51.2" for a build table's narrow columns (screen readers still hear %)
    unit: bool = true,
    /// The games after the figure; false where a column holds them (still on hover; screen
    /// readers hear them in the column)
    count: bool = true,
    /// What a screen reader hears before the figure: "win chance" for a model's estimate;
    /// whose rate, where the place doesn't say: "Ornn wins"; empty where a label or column
    /// head says it (StatStrip, BuildPanel)
    said: []const u8 = "win rate",
};

const W = struct {
    pub const missing = plain("·");
    pub const ends = phrase.Phrase("{lo:dec}-{hi:rate}");
    pub const ends_whole = phrase.Phrase("{lo:int}-{hi:pct}");
    pub const ends_games = phrase.Phrase("{e:text}, {n:count} games");
    pub const delta_ends = phrase.Phrase("{lo:points} to {hi:points}");
    pub const said = phrase.Phrase("{w:text} {v:text}");
    pub const said_games = phrase.Phrase("{w:text} {v:text}, {n:count} games");
};

/// <span class="c-rate" style="--c:…" title="50.6-51.8%, 44,935 games">
/// <span class="v" aria-hidden="true">51.2%</span><span class="g" aria-hidden="true">45k</span>
/// <span class="sr">win rate 51.2%, 44,935 games</span></span>
pub fn view(h: *H, r: Rate, look: Look) N {
    if ((r.games orelse 1) == 0) return h.span(.{ .class = "c-rate", .data_state = "missing" }, .{W.missing});
    const v = figure(h, r, look.unit);
    const sv = if (look.unit) v else figure(h, r, true);
    return cell(h, if (r.games == null) null else r.pct - r.ref, r.half, tip(h, r), .{
        h.span(.{ .class = "v", .aria_hidden = true }, .{v}),
        if (!look.count) null else if (r.games) |n| h.span(.{ .class = "g", .aria_hidden = true }, .{phrase.num(h, .kilo, n)}) else null,
        h.span(.{ .class = "sr" }, .{if (r.games != null and look.count) W.said_games.with(h, .{ .w = look.said, .v = sv.s, .n = r.games.? }) else W.said.with(h, .{ .w = look.said, .v = sv.s })}),
    });
}

/// "+2.6": a difference of rates (vs usual, won − own), on the rates' colour and fade;
/// `half` its 80% half-width, its ends on hover
pub fn delta(h: *H, pts: f64, half: ?f64) N {
    const tip_ = if (half) |x| W.delta_ends.with(h, .{ .lo = pts - x, .hi = pts + x }).s else null;
    return cell(h, pts, half, tip_, .{h.span(.{ .class = "v" }, .{phrase.num(h, .points, pts)})});
}

// The hover is a title until Tip lands: this is the one place to swap it
fn cell(h: *H, pts: ?f64, half: ?f64, title: ?[]const u8, kids: anytype) N {
    return h.span(.{
        .class = "c-rate",
        .data_wide = if (half) |x| fmt.wide(x) else false,
        .style = if (pts) |x| h.vars(.{ .c = colour(x) }) else null,
        .title = title,
    }, kids);
}

/// The one colour scale for rates and their differences
fn colour(pts: f64) fmt.WrColour {
    return .{ .pts = pts };
}

/// The figure as it shows, for a label that must say the same ("50%", not "50.0%")
pub fn shown(h: *H, r: Rate) tree.Text {
    return figure(h, r, true);
}

fn figure(h: *H, r: Rate, unit: bool) tree.Text {
    const pct = r.pct;
    if ((r.half orelse 0) >= 10) return if (unit) phrase.num(h, .pct, whole(pct)) else phrase.num(h, .int, whole(pct));
    return if (unit) phrase.num(h, .rate, pct) else phrase.num(h, .dec, pct);
}

fn tip(h: *H, r: Rate) ?[]const u8 {
    const x = r.half orelse return null;
    const e = ends(h, r.pct, x);
    return if (r.games) |n| W.ends_games.with(h, .{ .e = e.s, .n = n }).s else e.s;
}

/// A rate's range as its ends, for a hover: "50.2-52.6%", whole once it is ±10 or wider
pub fn ends(h: *H, pct: f64, half: f64) tree.Text {
    if (half < 10) return W.ends.with(h, .{ .lo = if (pct < half) 0 else pct - half, .hi = if (pct + half > 100) 100 else pct + half });
    return W.ends_whole.with(h, .{ .lo = whole(pct - half), .hi = whole(pct + half) });
}

// Branches, not @round: it pulls compiler_rt into every island (ui-games' budget)
fn whole(v: f64) u32 {
    if (v <= 0) return 0;
    if (v >= 100) return 100;
    return @intFromFloat(v + 0.5);
}

pub const css =
    \\@layer components {
    \\  .c-rate { display: inline-grid; grid-template-columns: auto auto; align-items: baseline;
    \\    justify-items: end; font-variant-numeric: tabular-nums; }
    \\  .c-rate > .v { color: var(--c, var(--text)); font-weight: var(--w-m); white-space: nowrap; }
    \\  .c-rate > .g { justify-self: start; min-width: 2.7em; margin-left: 5px; font-size: var(--fs-xs);
    \\    font-weight: var(--w-r); color: var(--faint); white-space: nowrap; }
    \\  .c-rate > .sr { position: absolute; width: 1px; height: 1px; overflow: hidden; clip-path: inset(50%);
    \\    white-space: nowrap; }
    \\  .c-rate[data-wide] > .v { opacity: var(--fade); }
    \\  .c-rate[data-state="missing"] { color: var(--faint); }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.add("counted: its games after it, ends and games on hover", view(h, .counted(44935, 23007), .{}));
    g.add("low", view(h, .counted(747, 356), .{}));
    g.add("few games: a wide range, faded", view(h, .counted(64, 25), .{}));
    g.add("very few: whole, faded", view(h, .counted(12, 8), .{}));
    g.add("no unit, for a build table's narrow column", view(h, .counted(3143, 1562), .{ .unit = false }));
    g.add("no count: a column holds the games (still on hover)", view(h, .counted(3143, 1685), .{ .count = false }));
    g.add("a model's estimate: no count, range, fade or colour", view(h, .estimate(54.3), .{ .said = "win chance" }));
    var own = Rate.counted(2210, 1083);
    own.ref = 47.2;
    g.add("its own ref (BuildPanel: against the slot's 47.2%)", view(h, own, .{ .unit = false }));
    g.add("no games", view(h, .counted(0, 0), .{}));
    var run = h.list();
    for ([_]f64{ 55.2, 53.9, 52.8, 51.6, 50.7, 50.0, 49.8, 48.4, 46.9, 44.1 }) |v| run.add(view(h, .at(20000, v), .{}));
    g.add("a sorted column: the colour mixes, no steps", h.div(.{ .class = "g-row" }, .{run.done()}));
    var sure = h.list();
    for ([_][2]u32{ .{ 20000, 10600 }, .{ 20000, 10520 }, .{ 20000, 10000 }, .{ 400, 216 }, .{ 120, 65 }, .{ 40, 26 } }) |x| sure.add(view(h, .counted(x[0], x[1]), .{}));
    g.add("the same colour however sure: 53.0, 52.6, 50.0 of 20,000, 54.0 of 400, 54.2 of 120, 65 of 40 (faded)", h.div(.{ .class = "g-row" }, .{sure.done()}));
    var ds = h.list();
    for ([_][2]f64{ .{ 2.6, 1.1 }, .{ -1.4, 0.9 }, .{ 0.3, 0.8 }, .{ 4.8, 9.5 } }) |x| ds.add(delta(h, x[0], x[1]));
    g.add("delta: +2.6, −1.4, +0.3; +4.8 with a wide range, faded", h.div(.{ .class = "g-row" }, .{ds.done()}));
}

test view {
    const std = @import("std");
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const want = [_]struct { Rate, Look, []const []const u8, []const []const u8 }{
        .{ .counted(44935, 23007), .{}, &.{ ">51.2%<", ">45k<", " games\"", ">win rate 51.2%, 44,935 games<" }, &.{"data-wide"} },
        .{ .counted(64, 25), .{}, &.{ "data-wide", ">39.1%<" }, &.{} },
        .{ .counted(12, 8), .{}, &.{ "data-wide", ">67%<" }, &.{} },
        .{ .counted(3143, 1562), .{ .unit = false, .count = false }, &.{ ">49.7<", ">win rate 49.7%<" }, &.{ ">49.7%<", "class=\"g\"" } },
        .{ .counted(3143, 1562), .{ .unit = false, .count = false, .said = "" }, &.{"49.7%<"}, &.{ "rate 49", "games<" } },
        .{ .estimate(54.3), .{ .said = "win chance" }, &.{ ">54.3%<", ">win chance 54.3%<" }, &.{ "title=", "class=\"g\"", "data-wide", "--c" } },
        .{ .counted(200, 99), .{ .said = "Ornn wins" }, &.{">Ornn wins 49.5%, 200 games<"}, &.{} },
        .{ .counted(0, 0), .{}, &.{"missing"}, &.{"class=\"v\""} },
    };
    for (want) |w| {
        var t: tree.Tree = .{};
        var h: H = .init(a, &t);
        var out: std.Io.Writer.Allocating = .init(a);
        try @import("html.zig").write(&t, view(&h, w[0], w[1]), &out.writer);
        try std.testing.expect(!h.oom);
        for (w[2]) |x| if (std.mem.find(u8, out.written(), x) == null) {
            std.debug.print("no {s} in {s}\n", .{ x, out.written() });
            return error.TestUnexpectedResult;
        };
        for (w[3]) |x| if (std.mem.find(u8, out.written(), x) != null) {
            std.debug.print("{s} in {s}\n", .{ x, out.written() });
            return error.TestUnexpectedResult;
        };
    }
}
