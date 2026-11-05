//! StatCell: one figure, formatted by its kind through fmt.zig and coloured by how far it
//! sits from its scale's middle. An aggregate rate is a Rate (rate.zig): its colour, games,
//! hover and fade are the rate view's. Other kinds: ink stepped (fmt.Step), or fill for
//! heat cells; a range's ends on hover, faded when wide or thin, never hidden (J35). A
//! missing figure says so
const tree = @import("tree.zig");
const fmt = @import("fmt.zig");
const rate = @import("rate.zig");
const Gallery = @import("gallery.zig").Gallery;
const phrase = @import("phrase.zig");
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "StatCell";
pub const scope = .{".c-stat"};

pub const Kind = enum {
    /// 53.6% from 53.6
    rate,
    /// +2.6 points
    points,
    /// 44,935
    count,
    /// 11:54 from seconds
    time,
    /// +1,402
    gold,
};

pub const Stat = struct {
    /// Null: no figure (too few games, not played)
    value: ?f64,
    kind: Kind = .rate,
    scale: fmt.Scale = .none,
    /// The scale's middle (50, the role's average): the colour reads value − ref
    ref: f64 = 0,
    /// 80% half-width, in the value's units (fmt.range): its ends on hover; past
    /// fmt.wide_range the figure fades
    range: ?f64 = null,
    /// An average's lanes or games (gold): under fmt.thin_games the figure fades. Rates
    /// fade by range
    thin: bool = false,
    /// Games behind the figure: after it, and in its hover
    games: ?u32 = null,
    /// False: the games on hover only, where the row has no room for them
    count: bool = true,
    /// A second line under the figure (last patch, typical)
    ctx: ?tree.Text = null,
    fill: bool = false,
};

const W = struct {
    pub const missing = plain("·");
    pub const ends = phrase.Phrase("{lo:points} to {hi:points}");
    pub const ends_games = phrase.Phrase("{e:text}, {n:count} games");
};

pub fn view(h: *H, s: Stat) N {
    const v = s.value orelse return h.span(.{ .class = "c-stat", .data_state = "missing" }, .{
        h.span(.{ .class = "v" }, .{W.missing}),
        if (s.ctx) |c| h.span(.{ .class = "ctx" }, .{c}) else null,
    });
    if (s.kind == .rate and s.scale == .aggregate and !s.fill) return h.span(.{ .class = "c-stat" }, .{
        rate.view(h, .{ .pct = v, .games = s.games, .half = s.range, .ref = s.ref }, .{ .count = s.count }),
        if (s.ctx) |c| h.span(.{ .class = "ctx" }, .{ h.span(.{ .class = "sr" }, .{", "}), c }) else null,
    });
    const d = v - s.ref;
    const step: fmt.Step = if (s.scale == .none) .{} else .of(@floatCast(d), s.scale.cuts());
    const thin = s.thin or if (s.range) |r| fmt.wide(r) else false;
    return h.span(.{
        .class = "c-stat",
        .data_v = if (s.fill) "fill" else null,
        .data_state = if (thin) "thin" else null,
        .style = if (s.scale == .none) null else if (s.fill) h.vars(.{ .f = step.fill() }) else if (s.scale == .aggregate) h.vars(.{ .c = fmt.WrColour{ .pts = d } }) else h.vars(.{ .c = step }),
        .title = tip(h, s.kind, v, s.range, s.games),
    }, .{
        h.span(.{ .class = "v" }, .{figure(h, s.kind, v)}),
        if (!s.count) null else if (s.games) |n| count(h, n) else null,
        if (s.ctx) |c| h.span(.{ .class = "ctx" }, .{c}) else null,
    });
}

/// A figure's games, faint after it: "940", "2.3k", "34k"
pub fn count(h: *H, n: u32) N {
    return h.span(.{ .class = "g" }, .{phrase.num(h, .kilo, n)});
}

/// A figure's hover: its range's ends, with its games when known; null with no range
fn tip(h: *H, k: Kind, v: f64, half: ?f64, games: ?u32) ?[]const u8 {
    const r = half orelse return null;
    return if (games) |n| endsGames(h, k, v, r, n).s else ends(h, k, v, r).s;
}

/// A strip value's hover: "50.2-52.6%, 33,108 games"
pub fn endsGames(h: *H, k: Kind, v: f64, half: f64, games: u32) tree.Text {
    return W.ends_games.with(h, .{ .e = ends(h, k, v, half).s, .n = games });
}

/// A range's ends, for its hover: "50.2-52.6%", whole once it is ±10 or wider; a change
/// "−7.7 to +1.5"
pub fn ends(h: *H, k: Kind, v: f64, half: f64) tree.Text {
    if (k == .rate) return rate.ends(h, v, half);
    return W.ends.with(h, .{ .lo = v - half, .hi = v + half });
}

/// A range's half-width: "3.1", whole from 10 ("14"): a wide range's tenths say nothing
pub fn pm(h: *H, v: f64) tree.Text {
    if (v < 10) return phrase.num(h, .dec, v);
    // Branches, not @round/@min: those pull compiler_rt into every island (ui-games' budget)
    return phrase.num(h, .int, if (v >= 100) @as(u32, 100) else @as(u32, @intFromFloat(v + 0.5)));
}

/// `v` as its kind reads: "53.6%", "+2.6", "11:54"
pub fn figure(h: *H, k: Kind, v: f64) tree.Text {
    return switch (k) {
        .rate => phrase.num(h, .rate, v),
        .points => phrase.num(h, .points, v),
        .count => phrase.num(h, .count, @as(u64, @intFromFloat(@abs(v)))),
        .time => phrase.num(h, .time, @as(i64, @intFromFloat(v))),
        .gold => phrase.num(h, .signed, @as(i64, @intFromFloat(v))),
    };
}

pub const css =
    \\@layer components {
    \\  .c-stat { display: inline-grid; grid-template-columns: auto auto; align-items: baseline;
    \\    justify-items: end; line-height: 1.15; font-variant-numeric: tabular-nums; }
    \\  .c-stat > .v { grid-column: 1; color: var(--c, var(--text)); font-weight: var(--w-m); white-space: nowrap; }
    \\  .c-stat > .g { grid-column: 2; justify-self: start; min-width: 2.7em; margin-left: 5px;
    \\    font-size: var(--fs-xs); color: var(--faint); white-space: nowrap; }
    \\  .c-stat > .c-rate { grid-column: 1 / -1; }
    \\  .c-stat > .ctx > .sr { position: absolute; width: 1px; height: 1px; overflow: hidden; clip-path: inset(50%); }
    \\  .c-stat > .ctx { grid-column: 1 / -1; font-size: var(--fs-xs); color: var(--faint); white-space: nowrap; }
    \\  .c-stat[data-state="thin"] > .v { opacity: var(--fade); }
    \\  .c-stat[data-state="missing"] > .v { color: var(--faint); }
    \\  .c-stat[data-v="fill"] { align-items: center; justify-content: center; min-width: 52px;
    \\    padding: 3px 6px; border-radius: var(--r-s); background: var(--f, var(--f-0)); }
    \\  .c-stat[data-v="fill"] > .v { color: var(--text); }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const agg: fmt.Scale = .aggregate;
    g.add("rate: its games after it, ends and games on hover", view(h, .{ .value = 53.6, .scale = agg, .ref = 50, .range = fmt.range(3143, 1685), .games = 3143 }));
    g.add("rate, low", view(h, .{ .value = 47.7, .scale = agg, .ref = 50, .range = fmt.range(747, 356), .games = 747 }));
    g.add("points", view(h, .{ .value = 2.6, .kind = .points, .scale = agg }));
    g.add("points, a range (on hover)", view(h, .{ .value = 2.6, .kind = .points, .scale = agg, .range = 1.4 }));
    g.add("count", view(h, .{ .value = 44935, .kind = .count, .ctx = plain("games") }));
    g.add("time", view(h, .{ .value = 714, .kind = .time }));
    g.add("gold, one game", view(h, .{ .value = 1402, .kind = .gold, .ctx = plain("gold") }));
    g.add("plain", view(h, .{ .value = 11.1 }));
    g.add("few games: a wide range, faded", view(h, .{ .value = 38.3, .scale = agg, .ref = 50, .range = fmt.range(64, 25), .games = 64 }));
    g.add("missing", view(h, .{ .value = null, .ctx = plain("few games") }));
    g.add("with context", view(h, .{ .value = 52.2, .scale = agg, .ref = 50, .ctx = plain("16.20 51.1%") }));
    var run = h.list();
    for ([_]f64{ 55.2, 53.9, 52.8, 51.6, 50.7, 49.8, 48.4, 46.9 }) |v| run.add(view(h, .{ .value = v, .scale = agg, .ref = 50 }));
    g.add("a sorted column: the ink mixes, no steps", h.div(.{ .class = "g-row" }, .{run.done()}));
    var fills = h.list();
    for ([_]f64{ -4.2, -2.3, -1.3, 0.3, 1.2, 1.9, 2.8 }) |d| fills.add(view(h, .{ .value = d, .kind = .points, .scale = agg, .fill = true }));
    var sure = h.list();
    for ([_][2]u32{ .{ 20000, 10600 }, .{ 20000, 10520 }, .{ 20000, 10000 }, .{ 400, 216 }, .{ 120, 65 }, .{ 40, 26 } }) |x| {
        const v = 100 * @as(f64, @floatFromInt(x[1])) / @as(f64, @floatFromInt(x[0]));
        sure.add(view(h, .{ .value = v, .scale = agg, .ref = 50, .range = fmt.range(x[0], x[1]), .games = x[0] }));
    }
    g.add("the same colour however sure: 53.0, 52.6, 50.0 of 20,000, 54.0 of 400, 54.2 of 120, 65.0 of 40 (faded)", h.div(.{ .class = "g-row" }, .{sure.done()}));
    g.add("fill, heat cells", h.div(.{ .class = "g-row" }, .{fills.done()}));
}
