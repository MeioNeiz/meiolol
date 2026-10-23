//! The desktop window, drawn each frame from a `View`: the client's state, then in
//! champ select the board (board.zig) around the lane card (lanecard.zig). Wide windows
//! put the teams beside the lane panel, as the client's own champ select does; narrow
//! ones stack everything in one column. Nothing here talks to the client.

const std = @import("std");
const dvui = @import("dvui");
const core = @import("core");
const lanecard = @import("../lanecard.zig");
const board = @import("../board.zig");
const Icons = @import("icons.zig").Icons;
const w = @import("widgets.zig");
const lane = @import("lane.zig");
const teams = @import("teams.zig");
const palette = w.palette;

pub const title = "meiolol";
/// Logical pixels; Windows scales these by the display's DPI
pub const size: dvui.Size = .{ .w = 1120, .h = 720 };
pub const min_size: dvui.Size = .{ .w = 380, .h = 420 };
/// From this width the teams sit beside the lane panel
const wide_from = 900;
/// Each team column, padding included
const side_width = 270;

pub const Edition = board.Edition;

/// Champ select as shown: the lane card and the board around it
pub const Select = struct {
    card: lanecard.Card,
    board: board.Board,
};

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
    select: *const Select,
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

pub const by_mastery = &lane.by_mastery;

pub const View = struct {
    status: Status,
    stats: ?*const core.Stats,
    icons: *const Icons,
    edition: Edition,
    note: Note = .none,
};

/// For dvui.Window.init
pub const theme = dvui.Theme.builtin.adwaita_dark;

pub fn frame(v: View) void {
    var root = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .both,
        .background = true,
        .style = .window,
    });
    defer root.deinit();
    const wide = dvui.windowRect().w >= wide_from;
    header(v);

    switch (v.status) {
        .select => |s| {
            const ctx: w.Ctx = .{ .stats = v.stats.?, .icons = v.icons, .edition = v.edition, .wide = wide };
            if (wide) wideSelect(ctx, s) else narrowSelect(ctx, s);
        },
        else => {
            var body = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .both, .padding = .all(16) });
            defer body.deinit();
            message(v);
        },
    }
    if (v.note == .restart) {
        w.para(@src(), "A new version of meiolol is downloaded: it starts the next time you open the app.", .{}, .{ .muted = true, .small = true });
    }
    footer();
}

fn message(v: View) void {
    switch (v.status) {
        .no_data => switch (v.note) {
            .downloading => w.para(@src(), "Downloading champion statistics from meio.lol.", .{}, .{}),
            .failed => |e| w.para(@src(), "Could not download champion statistics from meio.lol ({s}); trying again in 5 minutes.", .{e}, .{}),
            else => w.para(@src(), "No stats file found. Put stats-*.bin and recent-curves.bin next to meiolol-desktop.exe.", .{}, .{}),
        },
        .no_client => w.para(@src(), "Waiting for the League client to start.", .{}, .{}),
        .client_error => |e| w.para(@src(), "League client not reachable ({s}); retrying.", .{e}, .{}),
        .waiting => w.para(@src(), "The board shows in champ select: both teams, your lane, options and bans.", .{}, .{}),
        .no_role => w.para(@src(), "This champ select has no assigned positions, so there is no lane to show.", .{}, .{}),
        .select => {},
    }
}

/// The app's name and edition, where the client is, and in champ select whose turn it is
fn header(v: View) void {
    var bar = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .horizontal,
        .background = true,
        .color_fill = .{ .color = palette.bar },
        .padding = .{ .x = 14, .y = 8, .w = 14, .h = 8 },
    });
    defer bar.deinit();
    dvui.labelNoFmt(@src(), title, .{}, .{ .font = dvui.themeGet().font_title, .gravity_y = 0.5, .padding = .{ .w = 8 } });
    if (v.edition == .private) w.chip(@src(), "private", palette.private, 0);
    const state: []const u8 = switch (v.status) {
        .no_data => "no data",
        .no_client => "client closed",
        .client_error => "client error",
        .waiting => |phase| phase,
        .no_role => "champ select",
        .select => |s| s.board.stage,
    };
    dvui.labelNoFmt(@src(), state, .{}, .{ .gravity_y = 0.5, .color_text = .{ .color = w.text().opacity(0.7) }, .padding = .{ .x = 6, .w = 6 } });
    if (v.status == .select) switch (v.status.select.board.turn) {
        .none => {},
        .ban => w.chip(@src(), "Your ban", palette.turn, 1),
        .pick => w.chip(@src(), "Your pick", palette.turn, 1),
    };
    if (v.status == .select) {
        const c = &v.status.select.card;
        dvui.label(@src(), "EUW · {s}", .{if (c.period.len > 0) c.period else "no curves"}, .{
            .gravity_x = 1,
            .gravity_y = 0.5,
            .font = w.small(),
            .color_text = .{ .color = w.text().opacity(0.55) },
        });
    }
}

/// Teams in columns either side, lane panel in the middle, bans and draft under it
fn wideSelect(ctx: w.Ctx, s: *const Select) void {
    var row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .both });
    defer row.deinit();
    sideColumn(ctx, &s.board, .mine);
    {
        // Expanding alone would take the enemy column's room too
        const rest = dvui.windowRect().w - 2 * side_width;
        var mid = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .both, .max_size_content = .width(rest) });
        defer mid.deinit();
        var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
        defer scroll.deinit();
        var body = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .horizontal, .padding = .{ .x = 16, .y = 12, .w = 16, .h = 12 } });
        defer body.deinit();
        centre(ctx, s);
    }
    sideColumn(ctx, &s.board, .theirs);
}

fn sideColumn(ctx: w.Ctx, b: *const board.Board, side: teams.Side) void {
    var col = dvui.box(@src(), .{ .dir = .vertical }, .{
        .id_extra = @backingInt(side),
        .expand = .vertical,
        .min_size_content = .{ .w = side_width - 20 },
        .max_size_content = .width(side_width - 20),
        .background = true,
        .color_fill = .{ .color = palette.bar.lighten(2) },
        .padding = .{ .x = 10, .w = 10, .h = 10 },
    });
    defer col.deinit();
    teams.column(ctx, b, side);
}

/// Ban options lead while banning; otherwise the lane comes first
fn centre(ctx: w.Ctx, s: *const Select) void {
    const banning = s.board.turn == .ban or std.mem.eql(u8, s.board.stage, "Planning");
    if (banning) teams.banOptions(ctx, &s.board);
    lane.panel(ctx, &s.card, s.board.mode);
    {
        var strip = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .horizontal, .margin = .{ .y = 14 } });
        defer strip.deinit();
        _ = dvui.separator(@src(), .{ .expand = .horizontal, .margin = .{ .h = 8 } });
        teams.draft(ctx, &s.board);
        teams.bans(ctx, &s.board);
    }
    if (!banning) teams.banOptions(ctx, &s.board);
}

fn narrowSelect(ctx: w.Ctx, s: *const Select) void {
    var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
    defer scroll.deinit();
    var body = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .horizontal, .padding = .all(12) });
    defer body.deinit();
    centre(ctx, s);
    teams.column(ctx, &s.board, .mine);
    teams.column(ctx, &s.board, .theirs);
}

fn footer() void {
    var tl = dvui.textLayout(@src(), .{}, .{
        .expand = .horizontal,
        .background = true,
        .color_fill = .{ .color = palette.bar },
        .padding = .{ .x = 14, .y = 6, .w = 14, .h = 6 },
    });
    defer tl.deinit();
    tl.addText(core.boilerplate, .{ .font = w.tiny(), .color_text = .{ .color = w.text().opacity(0.4) } });
}
