//! StatCell: one figure, formatted by its kind through fmt.zig and coloured by how far it
//! sits from its scale's middle (the step comes from one function, fmt.Step). Thin data
//! fades; a missing figure says so. Ink by default, fill for heat cells
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
    /// 95% half-width, in the value's units: "±1.4"
    ci: ?f64 = null,
    /// The Toggletip the ± opens: its id on the page
    ci_tip: ?[]const u8 = null,
    /// Under fmt.thin_games the figure fades
    games: ?u32 = null,
    /// A second line under the figure (last patch, typical)
    ctx: ?tree.Text = null,
    fill: bool = false,
};

const W = struct {
    pub const missing = plain("·");
};

pub fn view(h: *H, s: Stat) N {
    const v = s.value orelse return h.span(.{ .class = "c-stat", .data_state = "missing" }, .{
        h.span(.{ .class = "v" }, .{W.missing}),
        if (s.ctx) |c| h.span(.{ .class = "ctx" }, .{c}) else null,
    });
    const step: fmt.Step = if (s.scale == .none) .{} else .of(@floatCast(v - s.ref), s.scale.cuts());
    const thin = if (s.games) |g| g < fmt.thin_games else false;
    const ci: ?N = if (s.ci) |c| (if (s.ci_tip) |id|
        h.button(.{ .class = "c-tt ci", .type = "button", .popovertarget = id }, .{ "±", phrase.num(h, .dec, c) })
    else
        h.span(.{ .class = "ci" }, .{ "±", phrase.num(h, .dec, c) })) else null;
    return h.span(.{
        .class = "c-stat",
        .data_v = if (s.fill) "fill" else null,
        .data_state = if (thin) "thin" else null,
        .style = if (s.scale == .none) null else if (s.fill) h.vars(.{ .f = step.fill() }) else h.vars(.{ .c = step }),
    }, .{
        h.span(.{ .class = "v" }, .{ figure(h, s.kind, v), ci }),
        if (s.ctx) |c| h.span(.{ .class = "ctx" }, .{c}) else null,
    });
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
    \\  .c-stat .ci { font-size: var(--fs-xs); color: var(--muted); font-weight: var(--w-r); margin-left: 2px; }
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
    g.add("rate", view(h, .{ .value = 53.6, .scale = agg, .ref = 50, .games = 3143, .ctx = plain("3,143") }));
    g.add("rate, low", view(h, .{ .value = 47.7, .scale = agg, .ref = 50, .games = 747, .ctx = plain("747") }));
    g.add("points", view(h, .{ .value = 2.6, .kind = .points, .scale = agg }));
    g.add("points, ±", view(h, .{ .value = 2.6, .kind = .points, .scale = agg, .ci = 1.4 }));
    g.add("count", view(h, .{ .value = 44935, .kind = .count, .ctx = plain("games") }));
    g.add("time", view(h, .{ .value = 714, .kind = .time }));
    g.add("gold, one game", view(h, .{ .value = 1402, .kind = .gold, .ctx = plain("gold") }));
    g.add("plain", view(h, .{ .value = 11.1 }));
    g.add("thin", view(h, .{ .value = 38.3, .scale = agg, .ref = 50, .games = 64, .ctx = plain("64") }));
    g.add("missing", view(h, .{ .value = null, .ctx = plain("few games") }));
    g.add("with context", view(h, .{ .value = 52.2, .scale = agg, .ref = 50, .ctx = plain("16.20 51.1%") }));
    var fills = h.list();
    for ([_]f64{ -4.2, -2.3, -1.3, 0.3, 1.2, 1.9, 2.8 }) |d| fills.add(view(h, .{ .value = d, .kind = .points, .scale = agg, .fill = true }));
    g.add("fill, heat cells", h.div(.{ .class = "g-row" }, .{fills.done()}));
}
