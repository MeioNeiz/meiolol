//! The loading screen (loading.zig): Porofessor's two rows of five cards, ours over
//! theirs with a team rule, one fixed order per card (champion, role, how it does in the
//! role, then pills). Narrow windows get one compact row per seat
//! (research/questions/desktop-app-layout.md C1, C2, C18, C21)

const std = @import("std");
const dvui = @import("dvui");
const loading = @import("../loading.zig");
const w = @import("widgets.zig");
const Ctx = w.Ctx;
const palette = w.palette;

pub fn view(ctx: Ctx, l: *const loading.Loading) void {
    var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
    defer scroll.deinit();
    var col = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .horizontal, .padding = .{ .x = 16, .y = 10, .w = 16, .h = 12 } });
    defer col.deinit();
    for (l.teams, 0..) |cards, side| {
        const ours = side == 0;
        const team = if (ours) palette.ally else palette.enemy;
        {
            var head = dvui.box(@src(), .{ .dir = .horizontal }, .{ .id_extra = side, .expand = .horizontal, .margin = .{ .y = if (ours) 0 else 10 } });
            defer head.deinit();
            w.heading(@src(), if (ours) "Your team" else "Enemy team", team);
            if (ctx.private()) if (l.draft) |d| {
                const win = if (ours) d.win else 1 - d.win;
                dvui.label(@src(), "{d:.0}% draft", .{100 * win}, .{
                    .gravity_x = 1,
                    .gravity_y = 0.5,
                    .font = dvui.themeGet().font_title,
                    .color_text = .{ .color = w.rateColour(win) },
                });
            };
        }
        _ = dvui.separator(@src(), .{ .id_extra = side, .expand = .horizontal, .min_size_content = .{ .h = 3 }, .color_fill = .{ .color = team }, .margin = .{ .h = 6 } });
        if (ctx.wide) {
            var row = dvui.box(@src(), .{ .dir = .horizontal, .equal_space = true }, .{ .id_extra = side, .expand = .horizontal });
            defer row.deinit();
            for (cards, 0..) |c, i| card(ctx, side * 10 + i, c, team);
        } else {
            for (cards, 0..) |c, i| compact(ctx, side * 10 + i, c, team);
        }
    }
    if (!ctx.wide) return;
    w.para(@src(), "Champion facts only: the role, how the champion does in it this period, and its lane against the same role across. Roles with ? are guesses.", .{}, .{ .muted = true, .small = true });
}

fn card(ctx: Ctx, id: usize, c: loading.Card, team: dvui.Color) void {
    var box = dvui.box(@src(), .{ .dir = .vertical }, .{
        .id_extra = id,
        .expand = .both,
        .background = true,
        .color_fill = .{ .color = palette.card },
        .border = .all(if (c.me) 2 else 1),
        .color_border = .{ .color = if (c.me) team else palette.card_border },
        .corners = .all(6),
        .padding = .all(10),
        .margin = .{ .x = 4, .w = 4 },
        .min_size_content = .{ .h = 170 },
    });
    defer box.deinit();
    {
        // champIcon centres itself vertically, which a vertical box takes as "lower down"
        var icon = dvui.box(@src(), .{}, .{ .gravity_x = 0.5 });
        defer icon.deinit();
        w.champIcon(@src(), ctx, c.champion, .{ .size = 64, .border = team.opacity(0.7) });
    }
    const name = if (c.champion != 0) ctx.stats.nameOf(c.champion) else "Unknown";
    dvui.labelNoFmt(@src(), name, .{}, .{ .gravity_x = 0.5, .font = dvui.themeGet().font_heading, .padding = .{}, .margin = .{ .y = 6 } });
    roleLine(c, .{ .gravity_x = 0.5 });
    rate(ctx, c, 0.5);
    var fb = dvui.flexbox(@src(), .{ .justify_content = .center }, .{ .expand = .horizontal, .margin = .{ .y = 6 } });
    defer fb.deinit();
    for (c.pills, 0..) |p, i| w.pill(@src(), p.text, tone(p.tone), i);
}

/// One row: icon, name and role, the rate, the first two pills
fn compact(ctx: Ctx, id: usize, c: loading.Card, team: dvui.Color) void {
    var box = w.card(@src(), id, if (c.me) team else null, .horizontal);
    defer box.deinit();
    w.champIcon(@src(), ctx, c.champion, .{ .size = 36, .border = team.opacity(0.7) });
    var col = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .horizontal, .margin = .{ .x = 8 } });
    defer col.deinit();
    {
        var row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer row.deinit();
        dvui.labelNoFmt(@src(), if (c.champion != 0) ctx.stats.nameOf(c.champion) else "Unknown", .{}, .{ .font = dvui.themeGet().font_heading, .padding = .{ .w = 8 } });
        roleLine(c, .{ .gravity_y = 0.5 });
    }
    rate(ctx, c, 0);
    var fb = w.pills(@src(), 0);
    defer fb.deinit();
    for (c.pills[0..@min(2, c.pills.len)], 0..) |p, i| w.pill(@src(), p.text, tone(p.tone), i);
}

fn roleLine(c: loading.Card, o: dvui.Options) void {
    var buf: [32]u8 = undefined;
    const role = if (c.role) |r| std.fmt.bufPrint(&buf, "{s}{s}", .{ w.roleName(r), if (c.guessed) "?" else "" }) catch "" else "Role unknown";
    dvui.labelNoFmt(@src(), role, .{}, o.override(.{ .font = w.small(), .color_text = .{ .color = w.text().opacity(0.6) }, .padding = .{} }));
}

/// Testers see the role's win rate and games; everyone sees the pills
fn rate(ctx: Ctx, c: loading.Card, gx: f32) void {
    if (!ctx.private() or c.games == 0) return;
    var nbuf: [16]u8 = undefined;
    dvui.label(@src(), "{d:.1}% · {s} games", .{ 100 * c.win, w.compact(&nbuf, c.games) }, .{
        .gravity_x = gx,
        .font = w.small(),
        .color_text = .{ .color = w.rateColour(c.win) },
        .padding = .{},
        .margin = .{ .y = 2 },
    });
}

fn tone(t: loading.Tone) w.Tone {
    return switch (t) {
        .neutral => .neutral,
        .good => .good,
        .bad => .bad,
        .caution => .caution,
    };
}
