//! The in-game panel (ingame.zig): the score and item gold, five mirrored lane rows (our
//! champion left, theirs right, the gold difference between), your lane against the
//! matchup's curve, and objective respawns. A panel to look at, never an alert
//! (docs/plan/app.md "In-game companion")

const std = @import("std");
const dvui = @import("dvui");
const core = @import("core");
const ingame = @import("../ingame.zig");
const w = @import("widgets.zig");
const lane = @import("lane.zig");
const Ctx = w.Ctx;
const palette = w.palette;

/// Wide: lanes and score left, your lane and timers right
pub fn wide(ctx: Ctx, g: *const ingame.InGame) void {
    var row = dvui.box(@src(), .{ .dir = .horizontal, .equal_space = true }, .{ .expand = .both });
    defer row.deinit();
    {
        var col = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .both, .padding = .{ .x = 16, .y = 12, .w = 10, .h = 12 } });
        defer col.deinit();
        score(g);
        rows(ctx, g);
    }
    var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both, .background = true, .color_fill = .{ .color = palette.bar.lighten(2) } });
    defer scroll.deinit();
    var col = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .horizontal, .padding = .{ .x = 14, .y = 12, .w = 16, .h = 12 } });
    defer col.deinit();
    myLane(ctx, g);
    timers(g);
    teamGold(g.history);
}

/// One column, small enough for a second screen's corner: score, your lane, lanes, timers
pub fn narrow(ctx: Ctx, g: *const ingame.InGame) void {
    var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
    defer scroll.deinit();
    var col = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .horizontal, .padding = .all(12) });
    defer col.deinit();
    score(g);
    myLane(ctx, g);
    rows(ctx, g);
    timers(g);
    teamGold(g.history);
}

/// Kills, towers, dragons and the like as "ours label theirs", then the item gold bar
fn score(g: *const ingame.InGame) void {
    const us = g.score[0];
    const them = g.score[1];
    const lines = [_]struct { []const u8, u32, u32 }{
        .{ "Kills", us.kills, them.kills },
        .{ "Towers", us.towers, them.towers },
        .{ "Dragons", us.dragons + us.elders, them.dragons + them.elders },
        .{ "Grubs", us.grubs, them.grubs },
        .{ "Heralds", us.heralds, them.heralds },
        .{ "Barons", us.barons, them.barons },
        .{ "Inhibitors", us.inhibitors, them.inhibitors },
    };
    var box = w.card(@src(), 0, null, .vertical);
    defer box.deinit();
    {
        var fb = dvui.flexbox(@src(), .{ .justify_content = .center }, .{ .expand = .horizontal });
        defer fb.deinit();
        for (lines, 0..) |l, i| {
            // Objectives nobody has taken yet only add noise
            if (i > 1 and l[1] == 0 and l[2] == 0) continue;
            var cell = dvui.box(@src(), .{ .dir = .vertical }, .{ .id_extra = i, .margin = .{ .x = 10, .w = 10 } });
            defer cell.deinit();
            {
                var nums = dvui.box(@src(), .{ .dir = .horizontal }, .{ .gravity_x = 0.5 });
                defer nums.deinit();
                const big = dvui.themeGet().font_title;
                dvui.label(@src(), "{d}", .{l[1]}, .{ .font = big, .color_text = .{ .color = palette.ally }, .padding = .{ .w = 6 } });
                dvui.labelNoFmt(@src(), "-", .{}, .{ .font = big, .color_text = .{ .color = w.text().opacity(0.35) }, .padding = .{} });
                dvui.label(@src(), "{d}", .{l[2]}, .{ .font = big, .color_text = .{ .color = palette.enemy }, .padding = .{ .x = 6 } });
            }
            dvui.labelNoFmt(@src(), l[0], .{}, .{ .gravity_x = 0.5, .font = w.tiny(), .color_text = .{ .color = w.text().opacity(0.6) }, .padding = .{} });
        }
    }
    goldBar(us.item_gold, them.item_gold);
}

/// Both teams' item gold as one bar split blue and red, the difference on top
fn goldBar(ours: u32, theirs: u32) void {
    const total: f32 = @floatFromInt(@max(1, ours + theirs));
    const share = @as(f32, @floatFromInt(ours)) / total;
    {
        var row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal, .margin = .{ .y = 8 } });
        defer row.deinit();
        var buf: [32]u8 = undefined;
        dvui.labelNoFmt(@src(), w.compact(&buf, ours), .{}, .{ .font = w.small(), .color_text = .{ .color = palette.ally }, .padding = .{} });
        const diff = @as(i64, ours) - theirs;
        var dbuf: [48]u8 = undefined;
        dvui.labelNoFmt(@src(), signedGold(&dbuf, diff, "item gold"), .{}, .{
            .gravity_x = 0.5,
            .font = w.small(),
            .color_text = .{ .color = if (diff >= 0) palette.ally else palette.enemy },
            .padding = .{},
        });
        var tbuf: [32]u8 = undefined;
        dvui.labelNoFmt(@src(), w.compact(&tbuf, theirs), .{}, .{ .gravity_x = 1, .font = w.small(), .color_text = .{ .color = palette.enemy }, .padding = .{} });
    }
    var bar = dvui.box(@src(), .{}, .{ .expand = .horizontal, .min_size_content = .{ .h = 8 }, .margin = .{ .y = 2 } });
    defer bar.deinit();
    const r = bar.data().contentRectScale().r;
    const split = r.x + r.w * share;
    var left = r;
    left.w = split - r.x;
    var right = r;
    right.x = split;
    right.w = r.x + r.w - split;
    const round = r.h / 2;
    left.fill(.{ .tl = .round(round), .bl = .round(round) }, .{ .color = .{ .color = palette.ally } });
    right.fill(.{ .tr = .round(round), .br = .round(round) }, .{ .color = .{ .color = palette.enemy } });
}

/// "+1.2k item gold", "-550 item gold", "even item gold"
fn signedGold(buf: []u8, diff: i64, what: []const u8) []const u8 {
    if (diff == 0) return std.fmt.bufPrint(buf, "even {s}", .{what}) catch what;
    var nbuf: [16]u8 = undefined;
    const n = w.compact(&nbuf, @abs(diff));
    return std.fmt.bufPrint(buf, "{s}{s} {s}", .{ if (diff > 0) "+" else "-", n, what }) catch what;
}

/// Five lanes, mirrored: ours left, the gold difference in the middle, theirs right
/// (research/questions/desktop-app-layout.md C7)
fn rows(ctx: Ctx, g: *const ingame.InGame) void {
    {
        var head = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal, .margin = .{ .y = 10, .h = 2 } });
        defer head.deinit();
        dvui.labelNoFmt(@src(), "Your team", .{}, .{ .font = dvui.themeGet().font_heading, .color_text = .{ .color = palette.ally }, .padding = .{} });
        dvui.labelNoFmt(@src(), "Enemy team", .{}, .{ .gravity_x = 1, .font = dvui.themeGet().font_heading, .color_text = .{ .color = palette.enemy }, .padding = .{} });
    }
    for (g.rows, 0..) |r, i| laneRow(ctx, i, r);
    w.para(@src(), "{s}Gold from the items each player holds: the game shows nobody's gold but your own.", .{
        if (ctx.wide) "" else "Level · kills/deaths/assists · cs. ",
    }, .{ .muted = true, .small = true });
}

fn laneRow(ctx: Ctx, i: usize, r: ingame.Row) void {
    var bufs: [2][64]u8 = undefined;
    var views: [2]?SeatView = .{ null, null };
    for ([_]?ingame.Seat{ r.ours, r.theirs }, &views, &bufs) |s_or, *v, *buf| {
        const s = s_or orelse continue;
        const line = if (ctx.wide)
            std.fmt.bufPrint(buf, "Lv {d} · {d} / {d} / {d} · {d} cs", .{ s.level, s.kills, s.deaths, s.assists, s.cs })
        else
            std.fmt.bufPrint(buf, "{d} · {d}/{d}/{d} · {d}", .{ s.level, s.kills, s.deaths, s.assists, s.cs });
        v.* = .{ .champion = s.champion, .me = s.me, .dead = s.dead, .respawn = s.respawn, .line = line catch "" };
    }
    mirrored(ctx, i, r.role, views[0], views[1], r.goldDiff());
}

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
/// and the gold curve with a dot for now
fn myLane(ctx: Ctx, g: *const ingame.InGame) void {
    w.heading(@src(), "Your lane", null);
    const l = g.lane orelse {
        w.para(@src(), "{s}", .{g.lane_note}, .{ .muted = true });
        return;
    };
    {
        var row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal, .margin = .{ .h = 4 } });
        defer row.deinit();
        w.champIcon(@src(), ctx, l.me, .{ .size = 36, .border = palette.ally });
        dvui.label(@src(), "{s} vs {s}", .{ ctx.stats.nameOf(l.me), ctx.stats.nameOf(l.opponent) }, .{
            .font = dvui.themeGet().font_title,
            .gravity_y = 0.5,
            .padding = .{ .x = 10, .w = 10 },
        });
        w.champIcon(@src(), ctx, l.opponent, .{ .size = 36, .border = palette.enemy, .id_extra = 1 });
    }
    if (l.minute) |m| {
        compareLine(0, "CS", l.cs.?, m);
        compareLine(1, "Item gold", l.gold.?, m);
    } else {
        w.para(@src(), "The lane curve covers minutes 1 to {d}.", .{l.matchup.points.len}, .{ .muted = true, .small = true });
    }
    lane.chart(l.matchup, .{ .minute = g.time / 60, .gold = @floatFromInt(if (l.gold) |gd| gd.now else 0) });
    w.para(@src(), "Gold, you minus them: average line and middle half of {d} games ({s}, EUW, {s}); the dot is you now, from items.", .{
        l.matchup.games, l.matchup.bracket.label(), g.period,
    }, .{ .muted = true, .small = true });
}

/// "CS +8 at 12 min: about typical (middle half -6 to +10)"
fn compareLine(id: usize, what: []const u8, c: ingame.Compare, minute: u8) void {
    const color: dvui.Color = switch (c.standing) {
        .far_behind, .behind => palette.behind,
        .typical => w.text(),
        .ahead, .far_ahead => palette.ahead,
    };
    var box = dvui.box(@src(), .{ .dir = .horizontal }, .{ .id_extra = id, .expand = .horizontal, .margin = .{ .y = 2 } });
    defer box.deinit();
    dvui.labelNoFmt(@src(), what, .{}, .{
        .color_text = .{ .color = w.text().opacity(0.65) },
        .min_size_content = .{ .w = 76 },
        .padding = .{},
        .gravity_y = 0.5,
    });
    var buf: [32]u8 = undefined;
    dvui.labelNoFmt(@src(), std.fmt.bufPrint(&buf, "{s}{d}", .{ if (c.now > 0) "+" else "", c.now }) catch what, .{}, .{
        .font = dvui.themeGet().font_heading,
        .color_text = .{ .color = color },
        .min_size_content = .{ .w = 56 },
        .padding = .{},
        .gravity_y = 0.5,
    });
    const t = c.typical;
    w.para(@src(), "{s} at {d} min (middle half {s}{d} to {s}{d})", .{
        c.standing.words(), minute, sign(t.p25), t.p25, sign(t.p75), t.p75,
    }, .{ .small = true, .id_extra = id });
}

fn sign(n: i32) []const u8 {
    return if (n > 0) "+" else "";
}

/// Respawns we know from the event feed: after a kill, never before the first spawn
fn timers(g: *const ingame.InGame) void {
    w.heading(@src(), "Coming back", null);
    if (g.timers.len == 0) {
        w.para(@src(), "Dragon, Baron and inhibitor respawns show here once one is taken.", .{}, .{ .muted = true, .small = true });
        return;
    }
    for (g.timers, 0..) |t, i| {
        var row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .id_extra = i, .expand = .horizontal, .margin = .{ .y = 2 } });
        defer row.deinit();
        dvui.labelNoFmt(@src(), t.what, .{}, .{ .gravity_y = 0.5, .padding = .{} });
        var at: [16]u8 = undefined;
        var in: [16]u8 = undefined;
        var buf: [48]u8 = undefined;
        const str = std.fmt.bufPrint(&buf, "{s}  (in {s})", .{ ingame.clock(&at, t.back), ingame.clock(&in, t.back - g.time) }) catch "";
        dvui.labelNoFmt(@src(), str, .{}, .{ .gravity_x = 1, .gravity_y = 0.5, .font = dvui.themeGet().font_heading, .padding = .{} });
    }
}

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
