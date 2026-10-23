//! `zig build desktop-shot`: the desktop window's states rendered to PNG without a
//! screen or a League client (desktop/raster.zig), from real stats and curves files and
//! made-up champ selects. For looking at the UI on any machine, at 100% and 150%.
//!
//! usage: meiolol-desktop-shot --stats FILE --curves FILE [--icons DIR] [--out DIR]
//!   [--only NAME] [--min-games N]

const std = @import("std");
const dvui = @import("dvui");
const core = @import("core");
const Raster = @import("raster");
const ui = @import("desktop/ui.zig");
const lanecard = @import("lanecard.zig");
const board = @import("board.zig");
const lcu = @import("lcu/root.zig");
const Icons = @import("desktop/icons.zig").Icons;
const ingame = @import("ingame.zig");

const Shot = struct {
    name: []const u8,
    status: union(enum) { plain: ui.Status, select: Scene, game: Game },
};

/// A champ select by champion names. Enemies are locked; a trailing "?" hides the
/// position (ranked), else they play my role. Allies: "Vi" locked, "Vi~" hovering or
/// intending, "" not picked
const Scene = struct {
    role: core.Role,
    me: []const u8 = "",
    locked: bool = false,
    allies: []const struct { core.Role, []const u8 } = &.{},
    enemies: []const []const u8 = &.{},
    my_bans: []const []const u8 = &.{},
    their_bans: []const []const u8 = &.{},
    turn: lcu.session.Turn = .none,
    /// Roles whose pick turn is now (mine included)
    picking: []const core.Role = &.{},
    phase: []const u8 = "BAN_PICK",
    mastery: []const struct { []const u8, u32 } = &.{},
    tier: ?[]const u8 = null,
};

/// A Live Client Data reply from a file, as the poller would read it in game
const Game = struct {
    path: []const u8 = lcu.live.fixture_path,
    tier: ?[]const u8 = "GOLD",
};

const mid_mastery = .{ .{ "Ahri", 212_000 }, .{ "Syndra", 64_000 }, .{ "Orianna", 41_000 }, .{ "Viktor", 30_500 }, .{ "Lux", 12_000 } };

const shots = [_]Shot{
    .{ .name = "no-client", .status = .{ .plain = .no_client } },
    .{ .name = "lobby", .status = .{ .plain = .{ .waiting = "Lobby" } } },
    .{ .name = "ban-turn", .status = .{ .select = .{
        .role = .middle,
        .turn = .ban,
        .allies = &.{ .{ .top, "Darius~" }, .{ .bottom, "Jinx~" } },
        .mastery = &mid_mastery,
        .tier = "GOLD",
    } } },
    .{ .name = "mid-blind", .status = .{ .select = .{
        .role = .middle,
        .me = "Ahri",
        .turn = .pick,
        .picking = &.{ .jungle, .middle },
        .allies = &.{ .{ .top, "Darius" }, .{ .jungle, "Vi~" }, .{ .bottom, "Jinx~" } },
        .enemies = &.{ "Malphite?", "Lee Sin?" },
        .my_bans = &.{ "Zed", "Yasuo", "Kayn", "Thresh", "Master Yi" },
        .their_bans = &.{ "Darius", "Briar", "Smolder", "Mel", "Viego" },
        .mastery = &mid_mastery,
        .tier = "GOLD",
    } } },
    .{ .name = "mid-guessed", .status = .{ .select = .{
        .role = .middle,
        .me = "Ahri",
        .turn = .pick,
        .picking = &.{.middle},
        .allies = &.{ .{ .top, "Darius" }, .{ .jungle, "Vi" }, .{ .bottom, "Jinx~" } },
        .enemies = &.{ "Syndra?", "Lee Sin?", "Malphite?" },
        .my_bans = &.{ "Zed", "Yasuo", "Kayn", "Thresh", "Master Yi" },
        .their_bans = &.{ "Darius", "Briar", "Smolder", "Mel", "Viego" },
        .mastery = &mid_mastery,
        .tier = "GOLD",
    } } },
    .{ .name = "top-counter", .status = .{ .select = .{
        .role = .top,
        .me = "Garen",
        .turn = .pick,
        .picking = &.{ .top, .utility },
        .allies = &.{ .{ .jungle, "Amumu" }, .{ .middle, "Lux" }, .{ .bottom, "Caitlyn" }, .{ .utility, "" } },
        .enemies = &.{ "Darius", "Ahri?", "Kai'Sa?", "Nautilus?" },
        .my_bans = &.{ "Yone", "Aatrox", "Kayle" },
        .their_bans = &.{ "Teemo", "Fiora", "Camille", "Zed" },
        .mastery = &.{ .{ "Garen", 150_000 }, .{ "Sett", 80_000 }, .{ "Malphite", 20_000 }, .{ "Ornn", 9_000 } },
        .tier = "SILVER",
    } } },
    .{ .name = "bot-locked", .status = .{ .select = .{
        .role = .bottom,
        .me = "Jinx",
        .locked = true,
        .phase = "FINALIZATION",
        .allies = &.{ .{ .top, "Ornn" }, .{ .jungle, "Vi" }, .{ .middle, "Orianna" }, .{ .utility, "Thresh" } },
        .enemies = &.{ "Darius?", "Lee Sin?", "Syndra?", "Kai'Sa?", "Nautilus?" },
        .my_bans = &.{ "Zed", "Yasuo", "Kayn", "Draven", "Master Yi" },
        .their_bans = &.{ "Briar", "Smolder", "Mel", "Viego", "Ezreal" },
        .mastery = &.{ .{ "Jinx", 90_000 }, .{ "Caitlyn", 40_000 }, .{ "Ezreal", 22_000 } },
    } } },
    .{ .name = "in-game", .status = .{ .game = .{} } },
};

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;
    const arena = init.arena.allocator();
    dvui.io = io;
    const argv = try init.minimal.args.toSlice(arena);
    var stats_path: ?[]const u8 = null;
    var curves_path: ?[]const u8 = null;
    var icons_dir: ?[]const u8 = null;
    var out_dir: []const u8 = "zig-out/shots";
    var only: ?[]const u8 = null;
    var min_games: u32 = (core.Options{}).min_games;
    var i: usize = 1;
    while (i + 1 < argv.len) : (i += 2) {
        const flag = argv[i];
        if (std.mem.eql(u8, flag, "--stats")) stats_path = argv[i + 1];
        if (std.mem.eql(u8, flag, "--curves")) curves_path = argv[i + 1];
        if (std.mem.eql(u8, flag, "--icons")) icons_dir = argv[i + 1];
        if (std.mem.eql(u8, flag, "--out")) out_dir = argv[i + 1];
        if (std.mem.eql(u8, flag, "--only")) only = argv[i + 1];
        if (std.mem.eql(u8, flag, "--min-games")) min_games = try std.fmt.parseInt(u32, argv[i + 1], 10);
    }
    const cwd = std.Io.Dir.cwd();
    const limit: std.Io.Limit = .limited(1 << 30);
    const stats_bytes = try cwd.readFileAlloc(io, stats_path orelse return error.NeedStats, arena, limit);
    const stats: core.Stats = try .parse(arena, stats_bytes);
    var curves: ?core.curvesfile.Curves = null;
    if (curves_path) |p| curves = try .parse(arena, try cwd.readFileAlloc(io, p, arena, limit));
    var icons: Icons = .{ .gpa = gpa };
    defer icons.deinit();
    if (icons_dir) |d| try icons.loadDir(io, d);
    try cwd.createDirPath(io, out_dir);

    for (shots) |shot| {
        if (only) |o| if (std.mem.indexOf(u8, shot.name, o) == null) continue;
        var frame_arena: std.heap.ArenaAllocator = .init(gpa);
        defer frame_arena.deinit();
        const a = frame_arena.allocator();
        const opts: core.Options = .{ .min_games = min_games };
        const status: ui.Status = switch (shot.status) {
            .plain => |s| s,
            .select => |scene| blk: {
                const cs = try champSelect(a, &stats, scene);
                const sel = try a.create(ui.Select);
                sel.card = try lanecard.build(a, .{
                    .stats = &stats,
                    .curves = if (curves) |*c| c else null,
                    .role = scene.role,
                    .me = cs.my_champion,
                    .locked = cs.my_locked,
                    .allies = cs.allies,
                    .enemies = cs.enemies,
                    .bans = cs.bans,
                    .mastery = try mastery(a, &stats, scene),
                    .tier = scene.tier,
                    .opts = opts,
                });
                sel.board = try board.build(a, &stats, opts, cs, &sel.card);
                break :blk .{ .select = sel };
            },
            .game => |gm| blk: {
                const body = try cwd.readFileAlloc(io, gm.path, a, limit);
                const g = try a.create(ingame.InGame);
                g.* = try ingame.build(a, &stats, if (curves) |*c| c else null, try lcu.live.parse(a, body), gm.tier);
                g.history = try history(a, g);
                break :blk .{ .in_game = g };
            },
        };
        // Wide at 100% and 150%, as tall as everything (no scrolling), narrow, and the
        // public edition beside the private one
        const sizes = [_]struct { []const u8, ui.Edition, f32, dvui.Size.Natural }{
            .{ "", .private, 1, .{ .w = ui.size.w, .h = ui.size.h } },
            .{ "-public", .public, 1, .{ .w = ui.size.w, .h = ui.size.h } },
            .{ "@150", .private, 1.5, .{ .w = ui.size.w, .h = ui.size.h } },
            .{ "-full", .private, 1, .{ .w = ui.size.w, .h = 1300 } },
            .{ "-narrow", .private, 1, .{ .w = 440, .h = 1500 } },
        };
        for (sizes) |sz| {
            const name = try std.fmt.allocPrint(a, "{s}/{s}{s}.png", .{ out_dir, shot.name, sz[0] });
            try render(gpa, io, .{ .status = status, .stats = &stats, .icons = &icons, .edition = sz[1] }, sz[3], sz[2], name);
            std.debug.print("{s}\n", .{name});
        }
    }
}

/// A made-up game so far that ends where the reply is: even early, a swing, then the lead
fn history(a: std.mem.Allocator, g: *const ingame.InGame) ![]const ingame.Sample {
    var out: std.ArrayList(ingame.Sample) = .empty;
    const end = g.sample();
    var t: f32 = 0;
    while (t <= end.time) : (t += ingame.sample_every) {
        const x = t / end.time;
        const swing = 900 * @sin(x * 2 * std.math.pi) * (1 - x);
        try out.append(a, .{
            .time = t,
            .team = @intFromFloat(@as(f32, @floatFromInt(end.team)) * x * x + swing),
            .lane = if (end.lane) |l| @intFromFloat(@as(f32, @floatFromInt(l)) * x) else null,
        });
    }
    return out.items;
}

fn champion(stats: *const core.Stats, name: []const u8) !u32 {
    const at = stats.find(name) orelse return error.UnknownChampion;
    return stats.ids[at];
}

/// The session lcu/session.zig would read for the scene
fn champSelect(a: std.mem.Allocator, stats: *const core.Stats, s: Scene) !lcu.session.ChampSelect {
    const Slot = lcu.session.Slot;
    var mine: [5]Slot = undefined;
    var allies: std.ArrayList(core.Pick) = .empty;
    const me = if (s.me.len > 0) try champion(stats, s.me) else 0;
    for (&mine, core.Role.all) |*sl, r| {
        sl.* = .{ .role = r, .picking = std.mem.indexOfScalar(core.Role, s.picking, r) != null };
        if (r == s.role) {
            sl.me = true;
            sl.champion = me;
            sl.state = if (me == 0) .empty else if (s.locked) .locked else .hover;
            continue;
        }
        for (s.allies) |al| {
            if (al[0] != r or al[1].len == 0) continue;
            const hover = std.mem.endsWith(u8, al[1], "~");
            sl.champion = try champion(stats, if (hover) al[1][0 .. al[1].len - 1] else al[1]);
            sl.state = if (!hover) .locked else if (sl.picking) .hover else .intent;
            try allies.append(a, .{ .champion = sl.champion, .role = r, .hover = hover });
        }
    }
    var theirs: [5]Slot = @splat(.{});
    var enemies: std.ArrayList(core.Pick) = .empty;
    for (s.enemies, 0..) |e, k| {
        const hidden = std.mem.endsWith(u8, e, "?");
        const c = try champion(stats, if (hidden) e[0 .. e.len - 1] else e);
        const role: ?core.Role = if (hidden) null else s.role;
        theirs[k] = .{ .champion = c, .role = role, .state = .locked };
        try enemies.append(a, .{ .champion = c, .role = role });
    }
    var bans: std.ArrayList(u32) = .empty;
    var sides: [2]std.ArrayList(u32) = .{ .empty, .empty };
    for ([_][]const []const u8{ s.my_bans, s.their_bans }, &sides) |names, *side| for (names) |n| {
        const c = try champion(stats, n);
        try side.append(a, c);
        try bans.append(a, c);
    };
    return .{
        .my_role = s.role,
        .my_champion = me,
        .my_locked = s.locked,
        .allies = allies.items,
        .enemies = enemies.items,
        .bans = bans.items,
        .phase = s.phase,
        .my_team = try a.dupe(Slot, &mine),
        .their_team = try a.dupe(Slot, &theirs),
        .my_bans = sides[0].items,
        .their_bans = sides[1].items,
        .my_turn = s.turn,
    };
}

fn mastery(a: std.mem.Allocator, stats: *const core.Stats, s: Scene) ![]lanecard.Mastery {
    var out: std.ArrayList(lanecard.Mastery) = .empty;
    for (s.mastery) |m| try out.append(a, .{ .champion = try champion(stats, m[0]), .points = m[1] });
    return out.items;
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
