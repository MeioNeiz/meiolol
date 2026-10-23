//! The in-game panel (ingame.zig), private edition only: the score and item gold, five
//! mirrored lane rows (rows.zig), your lane against the matchup's curve, and objective
//! respawns. A panel to look at, never an alert (docs/plan/app.md "In-game companion")

const std = @import("std");
const dvui = @import("dvui");
const ingame = @import("../../ingame.zig");
const w = @import("../widgets.zig");
const lane = @import("../lane.zig");
const rows = @import("../rows.zig");
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
        lanes(ctx, g);
    }
    var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both, .background = true, .color_fill = .{ .color = palette.bar.lighten(2) } });
    defer scroll.deinit();
    var col = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .horizontal, .padding = .{ .x = 14, .y = 12, .w = 16, .h = 12 } });
    defer col.deinit();
    myLane(ctx, g);
    timers(g);
    rows.teamGold(g.history);
}

/// One column, small enough for a second screen's corner: score, your lane, lanes, timers
pub fn narrow(ctx: Ctx, g: *const ingame.InGame) void {
    var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
    defer scroll.deinit();
    var col = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .horizontal, .padding = .all(12) });
    defer col.deinit();
    score(g);
    myLane(ctx, g);
    lanes(ctx, g);
    timers(g);
    rows.teamGold(g.history);
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
fn lanes(ctx: Ctx, g: *const ingame.InGame) void {
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
    var views: [2]?rows.SeatView = .{ null, null };
    for ([_]?ingame.Seat{ r.ours, r.theirs }, &views, &bufs) |s_or, *v, *buf| {
        const s = s_or orelse continue;
        const line = if (ctx.wide)
            std.fmt.bufPrint(buf, "Lv {d} · {d} / {d} / {d} · {d} cs", .{ s.level, s.kills, s.deaths, s.assists, s.cs })
        else
            std.fmt.bufPrint(buf, "{d} · {d}/{d}/{d} · {d}", .{ s.level, s.kills, s.deaths, s.assists, s.cs });
        v.* = .{ .champion = s.champion, .me = s.me, .dead = s.dead, .respawn = s.respawn, .line = line catch "" };
    }
    rows.mirrored(ctx, i, r.role, views[0], views[1], r.goldDiff());
}

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
