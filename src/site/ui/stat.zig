//! StatCell: one figure, formatted by its kind through fmt.zig and coloured by how far it
//! sits from its scale's middle. Ink by default: an aggregate rate mixes continuously
//! (fmt.WrColour, as the live champions table), so a sorted column reads as a smooth run;
//! one game's steps (fmt.Step). Fill for heat cells, stepped. The colour is the value's
//! alone; a rate's 80% range shows on hover as its ends, never as a ± figure, and the
//! figure fades when it is wide, never hides (J35). A missing figure says so
const tree = @import("tree.zig");
const fmt = @import("fmt.zig");
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
    /// A second line under the figure (last patch, typical)
    ctx: ?tree.Text = null,
    fill: bool = false,
};

const W = struct {
    pub const missing = plain("·");
    pub const rate_ends = phrase.Phrase("{lo:dec}-{hi:rate}");
    pub const rate_ends_whole = phrase.Phrase("{lo:int}-{hi:pct}");
    pub const ends = phrase.Phrase("{lo:points} to {hi:points}");
};

pub fn view(h: *H, s: Stat) N {
    const v = s.value orelse return h.span(.{ .class = "c-stat", .data_state = "missing" }, .{
        h.span(.{ .class = "v" }, .{W.missing}),
        if (s.ctx) |c| h.span(.{ .class = "ctx" }, .{c}) else null,
    });
    const d = v - s.ref;
    const step: fmt.Step = if (s.scale == .none) .{} else .of(@floatCast(d), s.scale.cuts());
    const thin = s.thin or if (s.range) |r| fmt.wide(r) else false;
    return h.span(.{
        .class = "c-stat",
        .data_v = if (s.fill) "fill" else null,
        .data_state = if (thin) "thin" else null,
        .style = if (s.scale == .none) null else if (s.fill) h.vars(.{ .f = step.fill() }) else if (s.scale == .aggregate) h.vars(.{ .c = fmt.WrColour{ .pts = d } }) else h.vars(.{ .c = step }),
        .title = if (s.range) |r| ends(h, s.kind, v, r).s else null,
    }, .{
        h.span(.{ .class = "v" }, .{figure(h, s.kind, v)}),
        if (s.ctx) |c| h.span(.{ .class = "ctx" }, .{c}) else null,
    });
}

/// A range's ends, for its hover: "50.2-52.6%", whole once it is ±10 or wider; a change
/// "−7.7 to +1.5"
pub fn ends(h: *H, k: Kind, v: f64, half: f64) tree.Text {
    if (k != .rate) return W.ends.with(h, .{ .lo = v - half, .hi = v + half });
    if (half < 10) return W.rate_ends.with(h, .{ .lo = if (v < half) 0 else v - half, .hi = if (v + half > 100) 100 else v + half });
    return W.rate_ends_whole.with(h, .{ .lo = whole(v - half), .hi = whole(v + half) });
}

// Branches, not @round: it pulls compiler_rt into every island (ui-games' budget)
fn whole(v: f64) u32 {
    if (v <= 0) return 0;
    if (v >= 100) return 100;
    return @intFromFloat(v + 0.5);
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
    \\  .c-stat { display: inline-flex; flex-direction: column; align-items: flex-end; line-height: 1.15;
    \\    font-variant-numeric: tabular-nums; }
    \\  .c-stat > .v { color: var(--c, var(--text)); font-weight: var(--w-m); white-space: nowrap; }
    \\  .c-stat > .ctx { font-size: var(--fs-xs); color: var(--faint); white-space: nowrap; }
    \\  .c-stat[data-state="thin"] > .v { opacity: 0.5; }
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
    g.add("rate", view(h, .{ .value = 53.6, .scale = agg, .ref = 50, .range = fmt.range(3143, 1685), .ctx = plain("3,143") }));
    g.add("rate, low", view(h, .{ .value = 47.7, .scale = agg, .ref = 50, .range = fmt.range(747, 356), .ctx = plain("747") }));
    g.add("points", view(h, .{ .value = 2.6, .kind = .points, .scale = agg }));
    g.add("points, a range (on hover)", view(h, .{ .value = 2.6, .kind = .points, .scale = agg, .range = 1.4 }));
    g.add("count", view(h, .{ .value = 44935, .kind = .count, .ctx = plain("games") }));
    g.add("time", view(h, .{ .value = 714, .kind = .time }));
    g.add("gold, one game", view(h, .{ .value = 1402, .kind = .gold, .ctx = plain("gold") }));
    g.add("plain", view(h, .{ .value = 11.1 }));
    g.add("few games: a wide range, faded", view(h, .{ .value = 38.3, .scale = agg, .ref = 50, .range = fmt.range(64, 25), .ctx = plain("64") }));
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
        sure.add(view(h, .{ .value = v, .scale = agg, .ref = 50, .range = fmt.range(x[0], x[1]), .ctx = phrase.num(h, .count, x[0]) }));
    }
    g.add("the same colour however sure: 53.0, 52.6, 50.0 of 20,000, 54.0 of 400, 54.2 of 120, 65.0 of 40 (faded)", h.div(.{ .class = "g-row" }, .{sure.done()}));
    g.add("fill, heat cells", h.div(.{ .class = "g-row" }, .{fills.done()}));
}
