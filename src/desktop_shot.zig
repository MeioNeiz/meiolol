//! `zig build desktop-shot`: the desktop window's states rendered to PNG without a
//! screen or a League client (desktop/raster.zig), from real stats and curves files and
//! made-up champ selects. For looking at the UI on any machine, at 100% and 150%.
//!
//! usage: meiolol-desktop-shot --stats FILE --curves FILE [--out DIR] [--min-games N]

const std = @import("std");
const dvui = @import("dvui");
const core = @import("core");
const Raster = @import("raster");
const ui = @import("desktop/ui.zig");
const lanecard = @import("lanecard.zig");

const Shot = struct {
    name: []const u8,
    status: union(enum) { plain: ui.Status, card: Scene },
};

/// A champ select by champion names; "?" after an enemy hides its position
const Scene = struct {
    role: core.Role,
    me: []const u8 = "",
    enemies: []const []const u8 = &.{},
    allies: []const []const u8 = &.{},
    mastery: []const struct { []const u8, u32 } = &.{},
    tier: ?[]const u8 = null,
};

const shots = [_]Shot{
    .{ .name = "no-client", .status = .{ .plain = .no_client } },
    .{ .name = "lobby", .status = .{ .plain = .{ .waiting = "Lobby" } } },
    .{ .name = "mid-guessed", .status = .{ .card = .{
        .role = .middle,
        .me = "Ahri",
        .enemies = &.{ "Syndra?", "Lee Sin?" },
        .allies = &.{"Jinx"},
        .mastery = &.{ .{ "Ahri", 212_000 }, .{ "Syndra", 64_000 }, .{ "Orianna", 41_000 }, .{ "Viktor", 30_500 }, .{ "Lux", 12_000 } },
        .tier = "GOLD",
    } } },
    .{ .name = "top-no-pick", .status = .{ .card = .{
        .role = .top,
        .enemies = &.{"Darius?"},
        .mastery = &.{ .{ "Garen", 150_000 }, .{ "Sett", 80_000 }, .{ "Malphite", 20_000 }, .{ "Ornn", 9_000 } },
        .tier = "SILVER",
    } } },
    .{ .name = "bot-waiting", .status = .{ .card = .{
        .role = .bottom,
        .me = "Jinx",
        .mastery = &.{ .{ "Jinx", 90_000 }, .{ "Caitlyn", 40_000 }, .{ "Ezreal", 22_000 } },
    } } },
};

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;
    const arena = init.arena.allocator();
    dvui.io = io;
    const argv = try init.minimal.args.toSlice(arena);
    var stats_path: ?[]const u8 = null;
    var curves_path: ?[]const u8 = null;
    var out_dir: []const u8 = "zig-out/shots";
    var min_games: u32 = (core.Options{}).min_games;
    var i: usize = 1;
    while (i + 1 < argv.len) : (i += 2) {
        const flag = argv[i];
        if (std.mem.eql(u8, flag, "--stats")) stats_path = argv[i + 1];
        if (std.mem.eql(u8, flag, "--curves")) curves_path = argv[i + 1];
        if (std.mem.eql(u8, flag, "--out")) out_dir = argv[i + 1];
        if (std.mem.eql(u8, flag, "--min-games")) min_games = try std.fmt.parseInt(u32, argv[i + 1], 10);
    }
    const cwd = std.Io.Dir.cwd();
    const limit: std.Io.Limit = .limited(1 << 30);
    const stats_bytes = try cwd.readFileAlloc(io, stats_path orelse return error.NeedStats, arena, limit);
    const stats: core.Stats = try .parse(arena, stats_bytes);
    var curves: ?core.curvesfile.Curves = null;
    if (curves_path) |p| curves = try .parse(arena, try cwd.readFileAlloc(io, p, arena, limit));
    try cwd.createDirPath(io, out_dir);

    for (shots) |shot| {
        var frame_arena: std.heap.ArenaAllocator = .init(gpa);
        defer frame_arena.deinit();
        const a = frame_arena.allocator();
        var card: lanecard.Card = undefined;
        const status: ui.Status = switch (shot.status) {
            .plain => |s| s,
            .card => |scene| blk: {
                card = try lanecard.build(a, try input(a, &stats, if (curves) |*c| c else null, scene, min_games));
                break :blk .{ .card = &card };
            },
        };
        // The window at 100% and 150%, and everything at once as if it never scrolled
        const sizes = [_]struct { []const u8, f32, f32 }{ .{ "@100", 1, ui.size.h }, .{ "@150", 1.5, ui.size.h }, .{ "-full", 1, 1200 } };
        for (sizes) |sz| {
            const name = try std.fmt.allocPrint(a, "{s}/{s}{s}.png", .{ out_dir, shot.name, sz[0] });
            try render(gpa, io, .{ .status = status, .stats = &stats }, .{ .w = ui.size.w, .h = sz[2] }, sz[1], name);
            std.debug.print("{s}\n", .{name});
        }
    }
}

fn champion(stats: *const core.Stats, name: []const u8) !u32 {
    const at = stats.find(name) orelse return error.UnknownChampion;
    return stats.ids[at];
}

fn input(a: std.mem.Allocator, stats: *const core.Stats, curves: ?*const core.curvesfile.Curves, s: Scene, min_games: u32) !lanecard.Input {
    var enemies: std.ArrayList(core.Pick) = .empty;
    for (s.enemies) |e| {
        const hidden = std.mem.endsWith(u8, e, "?");
        const name = if (hidden) e[0 .. e.len - 1] else e;
        try enemies.append(a, .{ .champion = try champion(stats, name), .role = if (hidden) null else s.role });
    }
    var allies: std.ArrayList(core.Pick) = .empty;
    for (s.allies) |n| try allies.append(a, .{ .champion = try champion(stats, n) });
    var mastery: std.ArrayList(lanecard.Mastery) = .empty;
    for (s.mastery) |m| try mastery.append(a, .{ .champion = try champion(stats, m[0]), .points = m[1] });
    return .{
        .stats = stats,
        .curves = curves,
        .role = s.role,
        .me = if (s.me.len > 0) try champion(stats, s.me) else 0,
        .allies = allies.items,
        .enemies = enemies.items,
        .mastery = mastery.items,
        .tier = s.tier,
        .opts = .{ .min_games = min_games },
    };
}

fn render(gpa: std.mem.Allocator, io: std.Io, view: ui.View, size: dvui.Size.Natural, scale: f32, path: []const u8) !void {
    var backend: Raster = try .init(.{ .allocator = gpa, .size = size, .scale = scale });
    defer backend.deinit();
    var win = try dvui.Window.init(@src(), gpa, backend.backend(), .{ .theme = ui.theme, .keybinds = .windows });
    defer win.deinit();
    // Layout settles over a few frames (sizes come from the previous one)
    for (0..4) |_| {
        try win.begin(backend.nanoTime());
        ui.frame(view);
        _ = try win.end(.{});
    }
    var file = try std.Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    var buf: [64 * 1024]u8 = undefined;
    var w = file.writer(io, &buf);
    try backend.writePng(&w.interface);
    try w.interface.flush();
}
