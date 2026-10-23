//! The lane panel: what the lane card says (lanecard.zig), with its mode, the matchup's
//! gold chart and the options from the player's pool

const std = @import("std");
const dvui = @import("dvui");
const lanecard = @import("../lanecard.zig");
const board = @import("../board.zig");
const w = @import("widgets.zig");
const Ctx = w.Ctx;
const palette = w.palette;

/// The window's "Rank by your mastery points" box; the poller reads it each tick
pub var by_mastery: std.atomic.Value(bool) = .init(true);
var by_mastery_box = true;

pub fn panel(ctx: Ctx, c: *const lanecard.Card, mode: board.Mode) void {
    title(ctx, c, mode);
    if (c.opponent) |o| if (o.guessed) {
        w.para(@src(), "{s} is a guess: enemy positions are hidden", .{ctx.stats.nameOf(o.champion)}, .{ .muted = true, .small = true });
    };
    if (c.sentence.len > 0) {
        const thin = if (c.matchup) |m| m.thin else false;
        w.para(@src(), "{s}", .{c.sentence}, .{ .muted = thin });
    }
    if (c.matchup) |m| {
        chart(m, null);
        w.para(@src(), "Gold, you minus them: average line, middle half of games shaded. {s}, EUW, {s}, {d} games.", .{
            m.bracket.label(), c.period, m.games,
        }, .{ .muted = true, .small = true });
    }

    {
        var row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal, .margin = .{ .y = 10 } });
        defer row.deinit();
        dvui.labelNoFmt(@src(), switch (mode) {
            .blind => "Options that hold up blind",
            .counter => "Options into them",
            .locked => "Other options",
        }, .{}, .{ .font = dvui.themeGet().font_heading, .gravity_y = 0.5, .padding = .{} });
        if (dvui.checkbox(@src(), &by_mastery_box, "Rank by your mastery points", .{ .gravity_x = 1, .font = w.small() })) {
            by_mastery.store(by_mastery_box, .release);
        }
    }
    if (c.options.len == 0) w.para(@src(), "No champion you can pick has enough games in this role.", .{}, .{});
    // Two cards a row only where each still fits its reasons on two lines
    const per_row: usize = if (dvui.windowRect().w >= 1360) 2 else 1;
    var i: usize = 0;
    while (i < c.options.len) : (i += per_row) {
        var row = dvui.box(@src(), .{ .dir = .horizontal, .equal_space = true }, .{ .id_extra = i, .expand = .horizontal });
        defer row.deinit();
        for (c.options[i..@min(i + per_row, c.options.len)], i..) |o, j| option(ctx, j, o, o.champion == c.me);
        // Keep a lone last card half wide
        if (per_row == 2 and i + 1 == c.options.len) {
            var empty = dvui.box(@src(), .{}, .{ .expand = .horizontal });
            empty.deinit();
        }
    }
    if (c.options.len > 0) {
        // The app's data is EUW's (deploy/web-loop.sh desktop_files)
        w.para(@src(), "Several options, not one answer: lane numbers are averages over many players in EUW{s}{s}.", .{
            if (c.period.len > 0) ", " else "", c.period,
        }, .{ .muted = true, .small = true });
    }
}

/// "Top · Garen vs Darius" with the mode as a chip: what the options are chosen for
fn title(ctx: Ctx, c: *const lanecard.Card, mode: board.Mode) void {
    var row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal, .margin = .{ .h = 6 } });
    defer row.deinit();
    if (c.me != 0) w.champIcon(@src(), ctx, c.me, .{ .size = 48, .border = palette.ally });
    var col = dvui.box(@src(), .{ .dir = .vertical }, .{ .gravity_y = 0.5, .margin = .{ .x = 10 } });
    defer col.deinit();
    const me = if (c.me != 0) ctx.stats.nameOf(c.me) else "No pick yet";
    if (c.opponent) |o| {
        dvui.label(@src(), "{s} vs {s}", .{ me, ctx.stats.nameOf(o.champion) }, .{ .font = dvui.themeGet().font_title, .padding = .{} });
    } else {
        dvui.label(@src(), "{s}", .{me}, .{ .font = dvui.themeGet().font_title, .padding = .{} });
    }
    var chips = dvui.box(@src(), .{ .dir = .horizontal }, .{ .margin = .{ .y = 2 } });
    defer chips.deinit();
    w.chip(@src(), w.roleName(c.role), palette.ally.opacity(0.7), 0);
    var buf: [64]u8 = undefined;
    switch (mode) {
        .blind => w.chip(@src(), "Safe blind", palette.card_border, 1),
        .counter => |o| w.chip(@src(), std.fmt.bufPrint(&buf, "Into {s}{s}", .{
            ctx.stats.nameOf(o.champion), if (o.guessed) "?" else "",
        }) catch "Counter", palette.enemy.opacity(0.75), 1),
        .locked => w.chip(@src(), "Locked in", palette.ahead.opacity(0.75), 1),
    }
    if (c.opponent) |o| w.champIcon(@src(), ctx, o.champion, .{ .size = 22, .border = palette.enemy, .dim = o.guessed });
}

/// In game: where the player's lane is now
pub const Marker = struct { minute: f64, gold: f64 };

/// Gold difference by minute: the estimate as a line, the middle half of games as a
/// band, zero as a rule, and in game a dot for now
pub fn chart(m: lanecard.Matchup, marker: ?Marker) void {
    if (m.points.len < 2) return;
    var lo: f64 = 0;
    var hi: f64 = 0;
    for (m.points) |p| {
        lo = @min(lo, @as(f64, @floatFromInt(p.p25)));
        hi = @max(hi, @as(f64, @floatFromInt(p.p75)));
    }
    if (marker) |k| {
        lo = @min(lo, k.gold);
        hi = @max(hi, k.gold);
    }
    const span = @max(@abs(lo), @abs(hi), 500);
    const step: f64 = if (span > 2000) 1000 else 500;
    const top = @ceil(span / step) * step;
    var x_axis: dvui.PlotWidget.Axis = .{
        .name = "minute",
        .min = 1,
        .max = @floatFromInt(m.points[m.points.len - 1].minute),
        .ticks = .{ .locations = .{ .custom = &.{ 5, 10, 14, 20, 25 } }, .format = .{ .normal = .{ .precision = 0 } } },
    };
    var y_axis: dvui.PlotWidget.Axis = .{
        // Empty, not null: null drops the tick labels too; the caption names the axis
        .name = "",
        .min = -top,
        .max = top,
        .ticks = .{ .locations = .{ .auto = .{ .tick_num_suggestion = 4 } }, .format = .{ .custom = signed } },
        .gridline_color = w.text().opacity(0.12),
    };
    var plot = dvui.plot(@src(), .{
        .x_axis = &x_axis,
        .y_axis = &y_axis,
        .border_thick = 0,
    }, .{ .expand = .horizontal, .min_size_content = .{ .w = 300, .h = 150 }, .margin = .{ .y = 6 } });
    defer plot.deinit();

    const line_color = if (m.thin) w.text().opacity(0.45) else dvui.themeGet().color(.highlight, .fill);
    for (m.points[0 .. m.points.len - 1], m.points[1..]) |a, b| {
        var path: dvui.Path.Builder = .init(dvui.currentWindow().lifo());
        defer path.deinit();
        path.addPoint(plot.dataToScreen(.{ .x = @floatFromInt(a.minute), .y = @floatFromInt(a.p25) }));
        path.addPoint(plot.dataToScreen(.{ .x = @floatFromInt(b.minute), .y = @floatFromInt(b.p25) }));
        path.addPoint(plot.dataToScreen(.{ .x = @floatFromInt(b.minute), .y = @floatFromInt(b.p75) }));
        path.addPoint(plot.dataToScreen(.{ .x = @floatFromInt(a.minute), .y = @floatFromInt(a.p75) }));
        path.build().fillConvex(.{ .color = .{ .color = line_color.opacity(0.18) } });
    }
    {
        var zero = plot.line();
        defer zero.deinit();
        zero.point(1, 0);
        zero.point(x_axis.max.?, 0);
        zero.stroke(1, w.text().opacity(0.35));
    }
    {
        var line = plot.line();
        defer line.deinit();
        for (m.points) |p| line.point(@floatFromInt(p.minute), @floatFromInt(p.mean));
        line.stroke(2, line_color);
    }
    const k = marker orelse return;
    const at = plot.dataToScreen(.{ .x = @min(k.minute, x_axis.max.?), .y = k.gold });
    var path: dvui.Path.Builder = .init(dvui.currentWindow().lifo());
    defer path.deinit();
    const r = 5 * dvui.windowNaturalScale();
    path.addArc(at, r, std.math.pi * 2, 0, true);
    const color = if (k.gold >= 0) palette.ally else palette.enemy;
    path.build().fillConvex(.{ .color = .{ .color = color } });
    path.build().stroke(.{ .thickness = 1.5 * dvui.windowNaturalScale(), .closed = true, .color = .{ .color = dvui.Color.white } });
}

fn signed(gpa: std.mem.Allocator, tick: f64) std.mem.Allocator.Error![]const u8 {
    return std.fmt.allocPrint(gpa, "{s}{d:.0}", .{ if (tick > 0) "+" else "", tick });
}

fn option(ctx: Ctx, i: usize, o: lanecard.Option, current: bool) void {
    var box = w.card(@src(), i, if (current) dvui.themeGet().color(.highlight, .fill) else null, .horizontal);
    defer box.deinit();
    w.champIcon(@src(), ctx, o.champion, .{ .size = 44 });
    if (ctx.private()) {
        // Testers: the draft model's team win chance with this pick, at the right
        var right = dvui.box(@src(), .{ .dir = .vertical }, .{ .gravity_x = 1, .min_size_content = .{ .w = 56 }, .margin = .{ .x = 6 } });
        defer right.deinit();
        dvui.label(@src(), "{d:.1}%", .{100 * o.win}, .{
            .gravity_x = 1,
            .font = dvui.themeGet().font_heading,
            .color_text = .{ .color = w.rateColour(o.win) },
            .padding = .{},
        });
        dvui.labelNoFmt(@src(), "team", .{}, .{ .gravity_x = 1, .font = w.tiny(), .color_text = .{ .color = w.text().opacity(0.5) }, .padding = .{} });
    }
    var col = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .horizontal, .margin = .{ .x = 8 } });
    defer col.deinit();
    {
        var row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer row.deinit();
        dvui.label(@src(), "{s}", .{ctx.stats.nameOf(o.champion)}, .{ .font = dvui.themeGet().font_heading, .padding = .{} });
        if (current) w.chip(@src(), "your pick", dvui.themeGet().color(.highlight, .fill), 0);
    }
    if (o.lane) |l| {
        const color: dvui.Color = switch (l.lean) {
            .ahead => palette.ahead,
            .behind => palette.behind,
            .unclear => w.text(),
        };
        w.para(@src(), "{s}", .{l.text}, .{ .small = true, .color = color.opacity(l.strength) });
    }
    if (o.reasons.len == 0) return;
    var fb = w.pills(@src(), 0);
    defer fb.deinit();
    for (o.reasons, 0..) |r, j| {
        const tone: w.Tone = if (j < o.tones.len) switch (o.tones[j]) {
            .neutral => .neutral,
            .good => .good,
            .bad => .bad,
        } else .neutral;
        w.pill(@src(), r, tone, j);
    }
}
