//! The board around the lane panel (board.zig): both teams' seats, the bans, ban
//! options and the draft so far. Numbers only in the private edition; the public one
//! says it in words or not at all (docs/plan/app.md "Policy line")

const std = @import("std");
const dvui = @import("dvui");
const board = @import("../board.zig");
const w = @import("widgets.zig");
const Ctx = w.Ctx;
const palette = w.palette;

pub const Side = enum { mine, theirs };

/// Five seats in cell order, as the client lists them
pub fn column(ctx: Ctx, b: *const board.Board, side: Side) void {
    const seats = if (side == .mine) b.allies else b.enemies;
    const color = if (side == .mine) palette.ally else palette.enemy;
    // Both columns can share a parent (the narrow layout): one box each keeps ids apart
    var box = dvui.box(@src(), .{ .dir = .vertical }, .{ .id_extra = @backingInt(side), .expand = .horizontal });
    defer box.deinit();
    {
        var row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer row.deinit();
        w.heading(@src(), if (side == .mine) "Your team" else "Enemy team", color);
        if (ctx.private()) if (b.draft) |d| {
            // The team's draft score in big type on top, as DraftGap and LoLDraftAI
            const win = if (side == .mine) d.win else 1 - d.win;
            dvui.label(@src(), "{d:.0}%", .{100 * win}, .{
                .gravity_x = 1,
                .gravity_y = 0.5,
                .font = dvui.themeGet().font_title.withSize(dvui.themeGet().font_title.size + 4),
                .color_text = .{ .color = w.rateColour(win) },
                .margin = .{ .y = 6 },
            });
        };
    }
    for (seats, 0..) |s, i| seat(ctx, i, s, side);
    if (side == .theirs and seats.len > 0) {
        w.para(@src(), "Enemy positions are hidden: roles with ? are guesses from what each champion usually plays.", .{}, .{ .muted = true, .small = true });
    }
}

fn seat(ctx: Ctx, i: usize, s: board.Seat, side: Side) void {
    const sl = s.slot;
    const team = if (side == .mine) palette.ally else palette.enemy;
    const border: ?dvui.Color = if (sl.picking) palette.turn else if (sl.me) team else null;
    var box = w.card(@src(), i, border, .horizontal);
    defer box.deinit();
    w.champIcon(@src(), ctx, sl.champion, .{ .size = 48, .dim = sl.state != .locked, .border = if (sl.state == .locked) team.opacity(0.8) else null });

    var col = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .horizontal, .margin = .{ .x = 8 }, .gravity_y = 0.5 });
    defer col.deinit();
    {
        var row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer row.deinit();
        const name = if (sl.champion != 0) ctx.stats.nameOf(sl.champion) else if (sl.picking) "Picking..." else "Not picked";
        dvui.labelNoFmt(@src(), name, .{}, .{
            .font = dvui.themeGet().font_heading,
            .color_text = .{ .color = w.text().opacity(if (sl.champion == 0) 0.45 else 1) },
            .padding = .{},
        });
        if (sl.me) w.chip(@src(), "you", team.opacity(0.75), 0);
        if (sl.picking) w.chip(@src(), "picking", palette.turn.opacity(0.85), 1);
    }
    {
        var buf: [64]u8 = undefined;
        const role = if (s.role) |r| w.roleName(r) else "Role unknown";
        const state = switch (sl.state) {
            .empty, .locked => "",
            .intent => ", wants to play",
            .hover => ", hovering",
        };
        dvui.labelNoFmt(@src(), std.fmt.bufPrint(&buf, "{s}{s}{s}", .{ role, if (s.guessed) "?" else "", state }) catch role, .{}, .{
            .font = w.small(),
            .color_text = .{ .color = w.text().opacity(0.65) },
            .padding = .{},
        });
    }
    if (sl.champion != 0 and s.games > 0) fact(ctx, s);
    if (sl.champion != 0 and s.role != null and s.games < w.few_games) {
        var fb = w.pills(@src(), 0);
        defer fb.deinit();
        var buf: [32]u8 = undefined;
        w.pill(@src(), std.fmt.bufPrint(&buf, "few games: {d}", .{s.games}) catch "few games", .caution, 0);
    }
    if (s.ideas.len > 0) ideas(ctx, s.ideas);
}

/// How the champion does in the role: a number for testers, words for everyone
fn fact(ctx: Ctx, s: board.Seat) void {
    const role = s.role.?.label();
    var buf: [96]u8 = undefined;
    var nbuf: [16]u8 = undefined;
    const str, const color = if (ctx.private()) .{
        std.fmt.bufPrint(&buf, "{d:.1}% in {s} · {s} games", .{ 100 * s.win, role, w.compact(&nbuf, s.games) }) catch "",
        w.rateColour(s.win),
    } else if (s.win >= 0.515) .{
        std.fmt.bufPrint(&buf, "strong in {s} now", .{role}) catch "", palette.ahead,
    } else if (s.win <= 0.485) .{
        std.fmt.bufPrint(&buf, "weak in {s} now", .{role}) catch "", palette.behind,
    } else return;
    dvui.labelNoFmt(@src(), str, .{}, .{ .font = w.small(), .color_text = .{ .color = color.opacity(0.9) }, .padding = .{} });
}

/// Options for an ally still to pick (Jacob's list: every role, not only yours)
fn ideas(ctx: Ctx, list: []const u32) void {
    var row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .margin = .{ .y = 3 } });
    defer row.deinit();
    dvui.labelNoFmt(@src(), "ideas", .{}, .{ .font = w.tiny(), .color_text = .{ .color = w.text().opacity(0.5) }, .gravity_y = 0.5, .padding = .{ .w = 4 } });
    for (list, 0..) |c, i| {
        w.champIcon(@src(), ctx, c, .{ .size = 26, .id_extra = i });
        _ = dvui.spacer(@src(), .{ .id_extra = i, .min_size_content = .{ .w = 4 } });
    }
}

/// Both teams' bans, crossed out
pub fn bans(ctx: Ctx, b: *const board.Board) void {
    var row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
    defer row.deinit();
    dvui.labelNoFmt(@src(), "Bans", .{}, .{ .font = dvui.themeGet().font_heading, .gravity_y = 0.5, .padding = .{ .w = 10 } });
    for (b.my_bans, 0..) |c, i| w.champIcon(@src(), ctx, c, .{ .size = 28, .crossed = true, .id_extra = i, .border = palette.ally.opacity(0.6) });
    if (b.my_bans.len + b.their_bans.len == 0) {
        dvui.labelNoFmt(@src(), "none yet", .{}, .{ .font = w.small(), .color_text = .{ .color = w.text().opacity(0.5) }, .gravity_y = 0.5 });
    }
    _ = dvui.spacer(@src(), .{ .min_size_content = .{ .w = 14 } });
    for (b.their_bans, 0..) |c, i| w.champIcon(@src(), ctx, c, .{ .size = 28, .crossed = true, .id_extra = 100 + i, .border = palette.enemy.opacity(0.6) });
}

/// The draft model on what shows so far: testers only, until the held-out check says
/// how far a team win chance can be trusted (docs/plan/app.md Jacob's list)
pub fn draft(ctx: Ctx, b: *const board.Board) void {
    if (!ctx.private()) return;
    const d = b.draft orelse return;
    var col = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .horizontal });
    defer col.deinit();
    {
        var row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer row.deinit();
        dvui.labelNoFmt(@src(), "Draft so far", .{}, .{ .font = dvui.themeGet().font_heading, .padding = .{ .w = 10 } });
        // A log-odds standard error near 50% is about a quarter of it in win chance
        dvui.label(@src(), "{d:.0}% for your team, ±{d:.0}", .{ 100 * d.win, 100 * d.se / 4 }, .{
            .font = dvui.themeGet().font_heading,
            .color_text = .{ .color = w.rateColour(d.win) },
            .padding = .{},
        });
        dvui.label(@src(), "{d} v {d} champions{s}", .{ d.picks[0], d.picks[1], if (d.hovers > 0) ", hovers count" else "" }, .{
            .font = w.small(),
            .color_text = .{ .color = w.text().opacity(0.55) },
            .gravity_x = 1,
            .gravity_y = 0.5,
            .padding = .{},
        });
    }
    var bar = dvui.box(@src(), .{}, .{ .expand = .horizontal, .min_size_content = .{ .h = 8 }, .margin = .{ .y = 4 } });
    const r = bar.data().contentRectScale().r;
    bar.deinit();
    var left = r;
    left.w = r.w * @as(f32, @floatCast(d.win));
    var right = r;
    right.x += left.w;
    right.w -= left.w;
    left.fill(.{}, .{ .color = .{ .color = palette.ally } });
    right.fill(.{}, .{ .color = .{ .color = palette.enemy } });
}

/// Who to ban: champions the enemy can still pick, in roles they have not filled, by
/// ban impact
pub fn banOptions(ctx: Ctx, b: *const board.Board) void {
    if (b.ban_options.len == 0) return;
    w.heading(@src(), if (b.turn == .ban) "Your ban: options" else "Ban options", if (b.turn == .ban) palette.turn else null);
    for (b.ban_options, 0..) |o, i| {
        var box = w.card(@src(), i, null, .horizontal);
        defer box.deinit();
        w.champIcon(@src(), ctx, o.champion, .{ .size = 32 });
        var col = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .horizontal, .margin = .{ .x = 8 }, .gravity_y = 0.5 });
        defer col.deinit();
        {
            var row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
            defer row.deinit();
            dvui.label(@src(), "{s}", .{ctx.stats.nameOf(o.champion)}, .{ .font = dvui.themeGet().font_heading, .padding = .{} });
            if (o.my_lane) w.chip(@src(), "your lane", palette.ally.opacity(0.7), 0);
            if (ctx.private()) dvui.label(@src(), "impact {d:.1}", .{o.impact}, .{ .gravity_x = 1, .font = w.small(), .padding = .{} });
        }
        if (ctx.private()) {
            w.para(@src(), "{s}: {d:.1}% won, {d:.1}% of games", .{ o.role.label(), 100 * o.win, 100 * o.pick_rate }, .{ .muted = true, .small = true, .id_extra = i });
        } else {
            w.para(@src(), "wins often and is picked a lot in {s}", .{o.role.label()}, .{ .muted = true, .small = true, .id_extra = i });
        }
    }
}
