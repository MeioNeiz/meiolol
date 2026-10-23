//! The post game view (postgame.zig): the verdict and award chips first, then both teams
//! lane by lane and the team gold through the game (research/questions/desktop-app-
//! layout.md C20). No dense tables

const std = @import("std");
const dvui = @import("dvui");
const postgame = @import("../postgame.zig");
const w = @import("widgets.zig");
const rows = @import("rows.zig");
const Ctx = w.Ctx;
const palette = w.palette;

pub fn wide(ctx: Ctx, p: *const postgame.PostGame) void {
    var col = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .both, .padding = .{ .x = 16, .y = 12, .w = 16, .h = 8 } });
    defer col.deinit();
    summary(ctx, p);
    var row = dvui.box(@src(), .{ .dir = .horizontal, .equal_space = true }, .{ .expand = .both });
    defer row.deinit();
    {
        var left = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .both, .margin = .{ .w = 10 } });
        defer left.deinit();
        lanes(ctx, p);
    }
    var right = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .both, .margin = .{ .x = 10 } });
    defer right.deinit();
    rows.teamGold(p.history);
    damage(ctx, p);
}

pub fn narrow(ctx: Ctx, p: *const postgame.PostGame) void {
    var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
    defer scroll.deinit();
    var col = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .horizontal, .padding = .all(12) });
    defer col.deinit();
    summary(ctx, p);
    rows.teamGold(p.history);
    lanes(ctx, p);
    damage(ctx, p);
}

/// "Victory in 28:42." big, the gold story and my lane in a sentence each, award chips
fn summary(ctx: Ctx, p: *const postgame.PostGame) void {
    var box = w.card(@src(), 0, if (p.win) palette.ahead.opacity(0.6) else palette.behind.opacity(0.6), .vertical);
    defer box.deinit();
    {
        var head = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer head.deinit();
        const big = dvui.themeGet().font_title;
        dvui.labelNoFmt(@src(), p.verdict, .{}, .{
            .font = big.withSize(big.size + 6),
            .color_text = .{ .color = if (p.win) palette.ahead else palette.behind },
            .padding = .{},
            .gravity_y = 0.5,
        });
        var buf: [48]u8 = undefined;
        dvui.labelNoFmt(@src(), std.fmt.bufPrint(&buf, "{d} - {d} kills", .{ p.kills[0], p.kills[1] }) catch "", .{}, .{
            .gravity_x = 1,
            .gravity_y = 0.5,
            .font = dvui.themeGet().font_heading,
            .color_text = .{ .color = w.text().opacity(0.75) },
            .padding = .{},
        });
    }
    if (p.story.len > 0) w.para(@src(), "{s}", .{p.story}, .{ .id_extra = 0 });
    if (p.lane.len > 0) w.para(@src(), "{s}", .{p.lane}, .{ .id_extra = 1 });
    if (p.awards.len == 0) return;
    var fb = w.pills(@src(), 0);
    defer fb.deinit();
    for (p.awards, 0..) |a, i| award(ctx, i, a);
}

/// "Most damage" over the champion's icon and name, in its team's colour
fn award(ctx: Ctx, i: usize, a: postgame.Award) void {
    const team = if (a.ours) palette.ally else palette.enemy;
    var box = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .id_extra = i,
        .background = true,
        .color_fill = .{ .color = team.opacity(0.12) },
        .border = .all(1),
        .color_border = .{ .color = team.opacity(0.6) },
        .corners = .all(8),
        .padding = .{ .x = 4, .y = 3, .w = 10, .h = 3 },
        .margin = .{ .w = 6, .h = 4 },
    });
    defer box.deinit();
    w.champIcon(@src(), ctx, a.champion, .{ .size = 24 });
    var col = dvui.box(@src(), .{ .dir = .vertical }, .{ .gravity_y = 0.5, .margin = .{ .x = 6 } });
    defer col.deinit();
    dvui.labelNoFmt(@src(), a.what, .{}, .{ .font = w.tiny(), .color_text = .{ .color = w.text().opacity(0.65) }, .padding = .{} });
    dvui.labelNoFmt(@src(), ctx.stats.nameOf(a.champion), .{}, .{ .font = w.small(), .color_text = .{ .color = team.lighten(10) }, .padding = .{} });
}

fn lanes(ctx: Ctx, p: *const postgame.PostGame) void {
    {
        var head = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal, .margin = .{ .y = 8, .h = 2 } });
        defer head.deinit();
        dvui.labelNoFmt(@src(), "Your team", .{}, .{ .font = dvui.themeGet().font_heading, .color_text = .{ .color = palette.ally }, .padding = .{} });
        dvui.labelNoFmt(@src(), "Enemy team", .{}, .{ .gravity_x = 1, .font = dvui.themeGet().font_heading, .color_text = .{ .color = palette.enemy }, .padding = .{} });
    }
    for (p.rows, 0..) |r, i| {
        var bufs: [2][64]u8 = undefined;
        var views: [2]?rows.SeatView = .{ null, null };
        for ([_]?postgame.Seat{ r.ours, r.theirs }, &views, &bufs) |s_or, *v, *buf| {
            const s = s_or orelse continue;
            var dbuf: [16]u8 = undefined;
            const dmg = w.compact(&dbuf, s.damage);
            const line = if (ctx.wide)
                std.fmt.bufPrint(buf, "{d} / {d} / {d} · {d} cs · {s} dmg", .{ s.kills, s.deaths, s.assists, s.cs, dmg })
            else
                std.fmt.bufPrint(buf, "{d}/{d}/{d} · {d}", .{ s.kills, s.deaths, s.assists, s.cs });
            v.* = .{ .champion = s.champion, .me = s.me, .line = line catch "" };
        }
        rows.mirrored(ctx, i, r.role, views[0], views[1], r.goldDiff());
    }
    w.para(@src(), "{s}Between the rows: gold earned over the game, you minus them.", .{
        if (ctx.wide) "" else "Kills/deaths/assists · cs. ",
    }, .{ .muted = true, .small = true });
}

/// Damage to champions, one bar per player against the most anyone did, ours then theirs
fn damage(ctx: Ctx, p: *const postgame.PostGame) void {
    w.heading(@src(), "Damage to champions", null);
    var most: u32 = 1;
    for (p.rows) |r| for ([_]?postgame.Seat{ r.ours, r.theirs }) |s| if (s) |seat| {
        most = @max(most, seat.damage);
    };
    var i: usize = 0;
    for ([_]bool{ true, false }) |ours| for (p.rows) |r| {
        const s = (if (ours) r.ours else r.theirs) orelse continue;
        defer i += 1;
        const team = if (ours) palette.ally else palette.enemy;
        var row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .id_extra = i, .expand = .horizontal, .margin = .{ .y = 1, .h = 1 } });
        defer row.deinit();
        w.champIcon(@src(), ctx, s.champion, .{ .size = 20 });
        var buf: [16]u8 = undefined;
        dvui.labelNoFmt(@src(), w.compact(&buf, s.damage), .{}, .{
            .gravity_y = 0.5,
            .font = w.small(),
            .min_size_content = .{ .w = 44 },
            .color_text = .{ .color = w.text().opacity(if (s.me) 1 else 0.7) },
            .padding = .{ .x = 6, .w = 4 },
        });
        var track = dvui.box(@src(), .{}, .{ .expand = .horizontal, .gravity_y = 0.5, .min_size_content = .{ .h = 10 } });
        defer track.deinit();
        var bar = track.data().contentRectScale().r;
        bar.w *= @as(f32, @floatFromInt(s.damage)) / @as(f32, @floatFromInt(most));
        bar.fill(.all(bar.h / 3), .{ .color = .{ .color = if (s.me) team else team.opacity(0.65) } });
    };
}
