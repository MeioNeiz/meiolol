//! Mirrored lane rows (our seat left, theirs right) and the team gold graph: the in-game
//! panel's (private/game.zig) and the post game view's

const std = @import("std");
const dvui = @import("dvui");
const core = @import("core");
const ingame = @import("../ingame.zig");
const w = @import("widgets.zig");
const Ctx = w.Ctx;
const palette = w.palette;

/// A seat as a mirrored row shows it: in game and post game
pub const SeatView = struct {
    champion: u32,
    me: bool,
    dead: bool = false,
    respawn: f32 = 0,
    /// The small line under the name: level, K/D/A, CS...
    line: []const u8,
};

/// One lane: our seat left, theirs right, the role and gold difference between
/// (research/questions/desktop-app-layout.md C7)
pub fn mirrored(ctx: Ctx, i: usize, role: core.Role, ours: ?SeatView, theirs: ?SeatView, gold_diff: ?i64) void {
    const mine = if (ours) |s| s.me else false;
    var box = w.card(@src(), i, if (mine) palette.ally else null, .horizontal);
    defer box.deinit();
    seat(ctx, ours, .left);
    seat(ctx, theirs, .right);
    // Centre, between the two seats
    var mid = dvui.box(@src(), .{ .dir = .vertical }, .{ .gravity_x = 0.5, .gravity_y = 0.5, .min_size_content = .{ .w = if (ctx.wide) 84 else 56 } });
    defer mid.deinit();
    dvui.labelNoFmt(@src(), w.roleName(role), .{}, .{ .gravity_x = 0.5, .font = w.tiny(), .color_text = .{ .color = w.text().opacity(0.55) }, .padding = .{} });
    if (gold_diff) |d| {
        var buf: [32]u8 = undefined;
        var nbuf: [16]u8 = undefined;
        const n = w.compact(&nbuf, @abs(d));
        const str = std.fmt.bufPrint(&buf, "{s}{s}", .{ if (d > 0) "+" else if (d < 0) "-" else "", n }) catch "?";
        const color = if (@abs(d) < 300) w.text().opacity(0.5) else if (d > 0) palette.ally else palette.enemy;
        dvui.labelNoFmt(@src(), str, .{}, .{
            .gravity_x = 0.5,
            .background = true,
            .color_fill = .{ .color = color.opacity(0.18) },
            .color_text = .{ .color = if (@abs(d) < 300) w.text().opacity(0.8) else color.lighten(10) },
            .corners = .all(8),
            .padding = .{ .x = 8, .y = 1, .w = 8, .h = 1 },
            .font = dvui.themeGet().font_heading,
        });
    }
}

const Edge = enum { left, right };

/// Icon, name and the small line; on the right the same mirrored. Narrow windows drop
/// the name: the icon says who it is
fn seat(ctx: Ctx, s_or: ?SeatView, edge: Edge) void {
    const right = edge == .right;
    const gx: f32 = if (right) 1 else 0;
    var box = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .id_extra = @backingInt(edge),
        .gravity_x = gx,
        .min_size_content = .{ .w = if (ctx.wide) 180 else 0 },
    });
    defer box.deinit();
    const s = s_or orelse {
        dvui.labelNoFmt(@src(), "Nobody", .{}, .{ .gravity_x = gx, .gravity_y = 0.5, .color_text = .{ .color = w.text().opacity(0.4) } });
        return;
    };
    const team = if (right) palette.enemy else palette.ally;
    const icon: w.IconOpts = .{ .size = if (ctx.wide) 40 else 32, .dim = s.dead, .border = team.opacity(0.7) };
    if (!right) w.champIcon(@src(), ctx, s.champion, icon);
    {
        var col = dvui.box(@src(), .{ .dir = .vertical }, .{ .gravity_x = gx, .gravity_y = 0.5, .margin = .{ .x = 6, .w = 6 } });
        defer col.deinit();
        var dbuf: [32]u8 = undefined;
        const dead = std.fmt.bufPrint(&dbuf, "dead {d:.0}s", .{s.respawn}) catch "dead";
        if (ctx.wide) {
            var nbuf: [64]u8 = undefined;
            const name = if (s.champion != 0) ctx.stats.nameOf(s.champion) else "New champion";
            dvui.labelNoFmt(@src(), if (s.dead) std.fmt.bufPrint(&nbuf, "{s} · {s}", .{ name, dead }) catch name else name, .{}, .{
                .gravity_x = gx,
                .font = dvui.themeGet().font_heading,
                .color_text = .{ .color = w.text().opacity(if (s.dead) 0.5 else 1) },
                .padding = .{},
            });
        } else if (s.dead) {
            dvui.labelNoFmt(@src(), dead, .{}, .{ .gravity_x = gx, .font = w.small(), .color_text = .{ .color = w.text().opacity(0.5) }, .padding = .{} });
        }
        dvui.labelNoFmt(@src(), s.line, .{}, .{
            .gravity_x = gx,
            .font = w.small(),
            .color_text = .{ .color = w.text().opacity(0.65) },
            .padding = .{},
        });
    }
    if (right) w.champIcon(@src(), ctx, s.champion, icon);
}

/// "Orianna vs Syndra", then CS and gold against the matchup's games at this minute,
/// Team item gold difference through the game: blue above zero, red below, as the
/// post-game graphs players like (research/questions/desktop-app-layout.md C12)
pub fn teamGold(h: []const ingame.Sample) void {
    if (h.len < 2) return;
    w.heading(@src(), "Team gold", null);
    var lo: f64 = 0;
    var hi: f64 = 0;
    for (h) |s| {
        lo = @min(lo, @as(f64, @floatFromInt(s.team)));
        hi = @max(hi, @as(f64, @floatFromInt(s.team)));
    }
    const span = @max(@abs(lo), @abs(hi), 1000);
    const step: f64 = if (span > 6000) 4000 else if (span > 3000) 2000 else 1000;
    const top = @ceil(span / step) * step;
    var x_axis: dvui.PlotWidget.Axis = .{
        .name = "minute",
        .min = 0,
        .max = @max(5, h[h.len - 1].time / 60),
        .ticks = .{ .locations = .{ .auto = .{ .tick_num_suggestion = 5 } }, .format = .{ .normal = .{ .precision = 0 } } },
    };
    var y_axis: dvui.PlotWidget.Axis = .{
        .name = "",
        .min = -top,
        .max = top,
        .ticks = .{ .locations = .{ .auto = .{ .tick_num_suggestion = 3 } }, .format = .{ .custom = signedTick } },
        .gridline_color = w.text().opacity(0.12),
    };
    var plot = dvui.plot(@src(), .{ .x_axis = &x_axis, .y_axis = &y_axis, .border_thick = 0 }, .{
        .expand = .horizontal,
        .min_size_content = .{ .w = 300, .h = 130 },
        .margin = .{ .y = 4 },
    });
    defer plot.deinit();
    for (h[0 .. h.len - 1], h[1..]) |a, b| {
        const ax: f64 = a.time / 60;
        const bx: f64 = b.time / 60;
        const ay: f64 = @floatFromInt(a.team);
        const by: f64 = @floatFromInt(b.team);
        // A segment crossing zero is filled in two parts, one per colour
        if ((ay > 0 and by < 0) or (ay < 0 and by > 0)) {
            const cx = ax + (bx - ax) * ay / (ay - by);
            area(plot, ax, ay, cx, 0);
            area(plot, cx, 0, bx, by);
        } else area(plot, ax, ay, bx, by);
    }
    var zero = plot.line();
    defer zero.deinit();
    zero.point(0, 0);
    zero.point(x_axis.max.?, 0);
    zero.stroke(1, w.text().opacity(0.35));
}

fn area(plot: *dvui.PlotWidget, ax: f64, ay: f64, bx: f64, by: f64) void {
    var path: dvui.Path.Builder = .init(dvui.currentWindow().lifo());
    defer path.deinit();
    path.addPoint(plot.dataToScreen(.{ .x = ax, .y = 0 }));
    path.addPoint(plot.dataToScreen(.{ .x = ax, .y = ay }));
    path.addPoint(plot.dataToScreen(.{ .x = bx, .y = by }));
    path.addPoint(plot.dataToScreen(.{ .x = bx, .y = 0 }));
    const color = if (ay + by >= 0) palette.ally else palette.enemy;
    path.build().fillConvex(.{ .color = .{ .color = color.opacity(0.7) } });
}

fn signedTick(gpa: std.mem.Allocator, tick: f64) std.mem.Allocator.Error![]const u8 {
    if (tick == 0) return gpa.dupe(u8, "0");
    return std.fmt.allocPrint(gpa, "{s}{d:.0}k", .{ if (tick > 0) "+" else "", tick / 1000 });
}
