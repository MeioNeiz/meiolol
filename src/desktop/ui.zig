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
const game = @import("game.zig");
const post = @import("post.zig");
const loadscreen = @import("loadscreen.zig");
const loading = @import("../loading.zig");
const ingame = @import("../ingame.zig");
const postgame = @import("../postgame.zig");
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
    /// The game is loading: cards from the last champ select
    loading: *const loading.Loading,
    /// In a game with Live Client Data up
    in_game: *const ingame.InGame,
    /// After a game, once the client has its end of game block
    post_game: *const postgame.PostGame,
};

/// From the update thread (update.zig), under the content
pub const Note = union(enum) {
    none,
    /// First start with update.key: fetching the data
    downloading,
    /// Error name of the last failed check (@errorName: static)
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
        // The public edition gets the panel once the private one has proved it
        .in_game => |g| if (v.edition == .private) {
            const ctx: w.Ctx = .{ .stats = v.stats.?, .icons = v.icons, .edition = v.edition, .wide = wide };
            if (wide) game.wide(ctx, g) else game.narrow(ctx, g);
        } else {
            var body = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .both, .padding = .all(16) });
            defer body.deinit();
            w.para(@src(), "In game. The board comes back in your next champ select.", .{}, .{});
        },
        .loading => |l| loadscreen.view(.{ .stats = v.stats.?, .icons = v.icons, .edition = v.edition, .wide = wide }, l),
        .post_game => |p| {
            const ctx: w.Ctx = .{ .stats = v.stats.?, .icons = v.icons, .edition = v.edition, .wide = wide };
            if (wide) post.wide(ctx, p) else post.narrow(ctx, p);
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
        .select, .loading, .in_game, .post_game => {},
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
    if (dvui.windowRect().w >= wide_from) {
        stepper(v.status);
    } else {
        const state: []const u8 = switch (v.status) {
            .no_data => "no data",
            .no_client => "client closed",
            .client_error => "client error",
            .waiting => |phase| phase,
            .no_role => "champ select",
            .select => |s| s.board.stage,
            .loading => "Loading screen",
            .in_game => "In game",
            .post_game => "Post game",
        };
        dvui.labelNoFmt(@src(), state, .{}, .{ .gravity_y = 0.5, .color_text = .{ .color = w.text().opacity(0.7) }, .padding = .{ .x = 6, .w = 6 } });
    }
    if (v.status == .select) switch (v.status.select.board.turn) {
        .none => {},
        .ban => w.chip(@src(), "Your ban", palette.turn, 1),
        .pick => w.chip(@src(), "Your pick", palette.turn, 1),
    };
    if (v.status == .in_game) {
        var buf: [16]u8 = undefined;
        dvui.labelNoFmt(@src(), ingame.clock(&buf, v.status.in_game.time), .{}, .{
            .gravity_x = 1,
            .gravity_y = 0.5,
            .font = dvui.themeGet().font_title,
            .color_text = .{ .color = w.text().opacity(0.8) },
        });
    }
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

const Step = enum { lobby, champ_select, in_game, post_game };
const step_names = [_][]const u8{ "Lobby", "Champ select", "In game", "Post game" };

/// Where the player is in a game's phases, as iTero and Mobalytics show it
fn stepper(s: Status) void {
    const now: ?Step = switch (s) {
        .select, .no_role => .champ_select,
        .loading, .in_game => .in_game,
        .post_game => .post_game,
        .waiting => |phase| if (std.mem.eql(u8, phase, "In game") or std.mem.eql(u8, phase, "Reconnect"))
            .in_game
        else if (std.mem.eql(u8, phase, "Post game"))
            .post_game
        else if (std.mem.eql(u8, phase, "Lobby") or std.mem.eql(u8, phase, "In queue") or std.mem.eql(u8, phase, "Match found"))
            .lobby
        else
            null,
        else => null,
    };
    var row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .gravity_y = 0.5, .margin = .{ .x = 10 } });
    defer row.deinit();
    for (step_names, 0..) |name, i| {
        const on = now != null and @backingInt(now.?) == i;
        if (i > 0) dvui.labelNoFmt(@src(), "›", .{}, .{ .id_extra = i, .color_text = .{ .color = w.text().opacity(0.3) }, .padding = .{ .x = 4, .w = 4 } });
        dvui.labelNoFmt(@src(), name, .{}, .{
            .id_extra = i,
            .color_text = .{ .color = if (on) w.text() else w.text().opacity(0.4) },
            .font = if (on) dvui.themeGet().font_heading else dvui.themeGet().font_body,
            .padding = .{ .x = 2, .w = 2 },
        });
    }
    if (s == .select) dvui.labelNoFmt(@src(), s.select.board.stage, .{}, .{
        .color_text = .{ .color = w.text().opacity(0.55) },
        .font = w.small(),
        .gravity_y = 0.5,
        .padding = .{ .x = 10 },
    });
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

const Tab = enum { us, picks, them };
/// The narrow window's tab, kept between champ selects
var tab: Tab = .picks;

/// One column: a switcher between our team, the picks and theirs (DraftGap's footer tabs
/// under 1024 px, research/questions/desktop-app-layout.md C15), picks first
fn narrowSelect(ctx: w.Ctx, s: *const Select) void {
    {
        var bar = dvui.box(@src(), .{ .dir = .horizontal, .equal_space = true }, .{ .expand = .horizontal, .padding = .{ .x = 12, .y = 8, .w = 12 } });
        defer bar.deinit();
        const names = [_][]const u8{ "Your team", "Picks", "Enemy team" };
        for (names, 0..) |name, i| {
            const on = @backingInt(tab) == i;
            if (dvui.button(@src(), name, .{}, .{
                .id_extra = i,
                .expand = .horizontal,
                .style = if (on) .highlight else .control,
                .corners = .all(0),
                .margin = .{},
            })) tab = @fromBackingInt(@intCast(i));
        }
    }
    var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
    defer scroll.deinit();
    var body = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .horizontal, .padding = .all(12) });
    defer body.deinit();
    switch (tab) {
        .us => teams.column(ctx, &s.board, .mine),
        .picks => centre(ctx, s),
        .them => teams.column(ctx, &s.board, .theirs),
    }
}
