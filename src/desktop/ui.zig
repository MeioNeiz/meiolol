//! The desktop window, drawn each frame from a `View`: the client's state, then in
//! champ select the lane card (lanecard.zig). Nothing here talks to the client.

const std = @import("std");
const dvui = @import("dvui");
const core = @import("core");
const lanecard = @import("../lanecard.zig");
const Card = lanecard.Card;
const curvesfile = core.curvesfile;

pub const title = "meiolol";
/// Logical pixels; Windows scales these by the display's DPI
pub const size: dvui.Size = .{ .w = 440, .h = 640 };

pub const Status = union(enum) {
    /// No stats file found next to the program
    no_data,
    no_client,
    /// Reachable but failing (error name)
    client_error: []const u8,
    /// Client running, not in champ select (gameflow phase)
    waiting: []const u8,
    /// Champ select without assigned positions (blind pick, ARAM)
    no_role,
    card: *const Card,
};

/// From the update thread (update.zig), under the content
pub const Note = union(enum) {
    none,
    downloading,
    /// Error name
    failed: []const u8,
    /// A new version is in place for the next start
    restart,
};

/// The window's "Rank by your mastery points" box; the poller reads it each tick
pub var by_mastery: std.atomic.Value(bool) = .init(true);
var by_mastery_box = true;

pub const View = struct {
    status: Status,
    stats: ?*const core.Stats,
    note: Note = .none,
};

const ahead_color: dvui.Color = .fromHex("#4fb37a");
const behind_color: dvui.Color = .fromHex("#d0605e");

/// For dvui.Window.init
pub const theme = dvui.Theme.builtin.adwaita_dark;

pub fn frame(v: View) void {
    var root = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .both,
        .background = true,
        .style = .window,
    });
    defer root.deinit();

    {
        var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
        defer scroll.deinit();
        var body = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .horizontal, .padding = .all(12) });
        defer body.deinit();
        header(v.status);
        switch (v.status) {
            .no_data => switch (v.note) {
                .downloading => para(@src(), "Downloading champion statistics from meio.lol.", .{}, .{}),
                .failed => |e| para(@src(), "Could not download champion statistics from meio.lol ({s}); trying again in 5 minutes.", .{e}, .{}),
                else => para(@src(), "No stats file found. Put stats-*.bin and recent-curves.bin next to meiolol-desktop.exe.", .{}, .{}),
            },
            .no_client => para(@src(), "Waiting for the League client to start.", .{}, .{}),
            .client_error => |e| para(@src(), "League client not reachable ({s}); retrying.", .{e}, .{}),
            .waiting => para(@src(), "The lane card shows in champ select.", .{}, .{}),
            .no_role => para(@src(), "This champ select has no assigned positions, so there is no lane to show.", .{}, .{}),
            .card => |c| card(c, v.stats.?),
        }
    }
    if (v.note == .restart) {
        para(@src(), "A new version of meiolol is downloaded: it starts the next time you open the app.", .{}, .{ .muted = true, .small = true });
    }
    footer();
}

fn header(s: Status) void {
    var row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal, .margin = .{ .h = 8 } });
    defer row.deinit();
    dvui.labelNoFmt(@src(), title, .{}, .{ .font = dvui.themeGet().font_title });
    const state: []const u8 = switch (s) {
        .no_data => "no data",
        .no_client => "client closed",
        .client_error => "client error",
        .waiting => |phase| phase,
        .no_role, .card => "champ select",
    };
    dvui.labelNoFmt(@src(), state, .{}, .{ .gravity_x = 1, .gravity_y = 0.5, .style = .control });
}

fn card(c: *const Card, stats: *const core.Stats) void {
    const me = if (c.me != 0) stats.nameOf(c.me) else "";
    {
        var row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer row.deinit();
        const role = c.role.label();
        if (c.opponent) |o| {
            dvui.label(@src(), "{c}{s}: {s} vs {s}", .{
                std.ascii.toUpper(role[0]),
                role[1..],
                if (me.len > 0) me else "you",
                stats.nameOf(o.champion),
            }, .{ .font = dvui.themeGet().font_heading });
        } else {
            dvui.label(@src(), "{c}{s}: enemy laner not picked yet", .{
                std.ascii.toUpper(role[0]),
                role[1..],
            }, .{ .font = dvui.themeGet().font_heading });
        }
    }
    if (c.opponent) |o| if (o.guessed) {
        para(@src(), "{s} is a guess: enemy positions are hidden", .{stats.nameOf(o.champion)}, .{ .muted = true });
    };
    if (c.sentence.len > 0) {
        const thin = if (c.matchup) |m| m.thin else false;
        para(@src(), "{s}", .{c.sentence}, .{ .muted = thin });
    }
    if (c.matchup) |m| {
        chart(m);
        chartCaption(m, c.period);
    }

    dvui.labelNoFmt(@src(), "From your pool", .{}, .{
        .font = dvui.themeGet().font_heading,
        .margin = .{ .y = 14, .h = 2 },
    });
    if (dvui.checkbox(@src(), &by_mastery_box, "Rank by your mastery points", .{})) {
        by_mastery.store(by_mastery_box, .release);
    }
    if (c.options.len == 0) para(@src(), "No champion you can pick has enough games in this role.", .{}, .{});
    for (c.options, 0..) |o, i| option(i, o, stats, o.champion == c.me);
    if (c.options.len > 0) {
        // The app's data is EUW's (deploy/web-loop.sh desktop_files)
        para(@src(), "Several options, not one answer: lane numbers are averages over many players in EUW{s}{s}.", .{
            if (c.period.len > 0) ", " else "", c.period,
        }, .{ .muted = true, .small = true });
    }
}

/// Gold difference by minute: the estimate as a line, the middle half of games as a
/// band, zero as a rule
fn chart(m: lanecard.Matchup) void {
    if (m.points.len < 2) return;
    var lo: f64 = 0;
    var hi: f64 = 0;
    for (m.points) |p| {
        lo = @min(lo, @as(f64, @floatFromInt(p.p25)));
        hi = @max(hi, @as(f64, @floatFromInt(p.p75)));
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
        .gridline_color = dvui.themeGet().color(.content, .text).opacity(0.12),
    };
    var plot = dvui.plot(@src(), .{
        .x_axis = &x_axis,
        .y_axis = &y_axis,
        .border_thick = 0,
    }, .{ .expand = .horizontal, .min_size_content = .{ .w = 300, .h = 140 }, .margin = .{ .y = 6 } });
    defer plot.deinit();

    const thin = m.thin;
    const line_color = if (thin) dvui.themeGet().color(.content, .text).opacity(0.45) else dvui.themeGet().color(.highlight, .fill);
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
        zero.stroke(1, dvui.themeGet().color(.content, .text).opacity(0.35));
    }
    var line = plot.line();
    defer line.deinit();
    for (m.points) |p| line.point(@floatFromInt(p.minute), @floatFromInt(p.mean));
    line.stroke(2, line_color);
}

fn chartCaption(m: lanecard.Matchup, period: []const u8) void {
    para(@src(), "Gold, you minus them: average line, middle half of games shaded. {s}, EUW, {s}, {d} games.", .{
        m.bracket.label(), period, m.games,
    }, .{ .muted = true, .small = true });
}

fn signed(gpa: std.mem.Allocator, tick: f64) std.mem.Allocator.Error![]const u8 {
    return std.fmt.allocPrint(gpa, "{s}{d:.0}", .{ if (tick > 0) "+" else "", tick });
}

fn option(i: usize, o: lanecard.Option, stats: *const core.Stats, current: bool) void {
    var box = dvui.box(@src(), .{ .dir = .vertical }, .{
        .id_extra = i,
        .expand = .horizontal,
        .background = true,
        .corners = .all(6),
        .padding = .all(8),
        .margin = .{ .y = 4 },
        .color_border = if (current) .{ .color = dvui.themeGet().color(.highlight, .fill) } else null,
        .border = .all(if (current) 2 else 1),
    });
    defer box.deinit();
    dvui.label(@src(), "{s}{s}", .{ stats.nameOf(o.champion), if (current) "  (your pick)" else "" }, .{
        .font = dvui.themeGet().font_heading,
        .padding = .{},
    });
    var tl = dvui.textLayout(@src(), .{}, .{ .expand = .horizontal, .background = false, .padding = .{} });
    defer tl.deinit();
    const text = dvui.themeGet().color(.content, .text);
    if (o.lane) |l| {
        const color: dvui.Color = switch (l.lean) {
            .ahead => ahead_color,
            .behind => behind_color,
            .unclear => text,
        };
        tl.addText(l.text, .{ .color_text = .{ .color = color.opacity(l.strength) } });
        if (o.reasons.len > 0) tl.addText("\n", .{});
    }
    for (o.reasons, 0..) |r, j| {
        if (j > 0) tl.addText(" · ", .{ .color_text = .{ .color = text.opacity(0.5) } });
        tl.addText(r, .{ .color_text = .{ .color = text.opacity(0.85) } });
    }
}

const ParaOpts = struct { muted: bool = false, small: bool = false };

fn para(src: std.builtin.SourceLocation, comptime fmt: []const u8, args: anytype, opts: ParaOpts) void {
    var tl = dvui.textLayout(src, .{}, .{
        .expand = .horizontal,
        .background = false,
        .margin = .{ .y = 4 },
    });
    defer tl.deinit();
    var buf: [1024]u8 = undefined;
    const text = std.fmt.bufPrint(&buf, fmt, args) catch fmt;
    const color = dvui.themeGet().color(.content, .text);
    const font = dvui.themeGet().font_body;
    tl.addText(text, .{
        .color_text = .{ .color = if (opts.muted) color.opacity(0.6) else color },
        .font = if (opts.small) font.withSize(font.size - 2) else font,
    });
}

fn footer() void {
    var tl = dvui.textLayout(@src(), .{}, .{
        .expand = .horizontal,
        .background = false,
        .padding = .{ .x = 12, .y = 6, .w = 12, .h = 8 },
    });
    defer tl.deinit();
    const color = dvui.themeGet().color(.content, .text).opacity(0.45);
    const font = dvui.themeGet().font_body;
    tl.addText(core.boilerplate, .{ .font = font.withSize(font.size - 3), .color_text = .{ .color = color } });
}
