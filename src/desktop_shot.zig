//! `zig build desktop-shot`: the desktop window's states rendered to PNG without a
//! screen or a League client (desktop/raster.zig), from real stats and curves files and
//! made-up champ selects. For looking at the UI on any machine, at 100% and 150%.
//! `--compare DIR` checks each against the approved PNG of the same name there, pixel
//! for pixel: the changed ones get NAME.diff.png (changes red on the dimmed new shot)
//! and the exit code is 1 (deploy/desktop-shots.sh).
//!
//! usage: meiolol-desktop-shot --stats FILE --curves FILE [--facts FILE] [--icons DIR]
//!   [--out DIR] [--only NAME] [--min-games N] [--compare DIR]

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
const postgame = @import("postgame.zig");
const loading = @import("loading.zig");
const comp = @import("comp.zig");
const practice = @import("practice.zig");
const practice_ui = @import("desktop/private/practice.zig");
const signin = @import("desktop/signin.zig");

const Shot = struct {
    name: []const u8,
    status: union(enum) { plain: ui.Status, select: Scene, loading: Scene, game: Game, post: Post, practice: Practice },
    /// The sign-in form or line (desktop/signin.zig)
    signin: ?signin.State = null,
};

/// A random practice draft (the same one for the same stats file), on `screen`
const Practice = struct {
    screen: practice.Screen = .select,
    /// My seat and the enemy's last two left to pick
    open: bool = false,
    picker: ?practice.Target = null,
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
    /// A ban still to come
    bans_open: bool = false,
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

/// An end of game block from a file, with a made-up gold history ending at `team`
const Post = struct {
    path: []const u8 = lcu.eog.fixture_path,
    team: i32 = 3400,
    lane: i32 = 1100,
    tier: ?[]const u8 = "GOLD",
};

const mid_mastery = .{ .{ "Ahri", 212_000 }, .{ "Syndra", 64_000 }, .{ "Orianna", 41_000 }, .{ "Viktor", 30_500 }, .{ "Lux", 12_000 } };

const shots = [_]Shot{
    .{ .name = "no-client", .status = .{ .plain = .no_client } },
    .{ .name = "lobby", .status = .{ .plain = .{ .waiting = "Lobby" } } },
    .{ .name = "sign-in", .status = .{ .plain = .no_data }, .signin = .{ .needed = true } },
    .{ .name = "sign-in-failed", .status = .{ .plain = .no_data }, .signin = .{ .needed = true, .message = "Couldn't reach meio.lol (ConnectionRefused); try again in a moment." } },
    .{ .name = "ban-turn", .status = .{ .select = .{
        .role = .middle,
        .turn = .ban,
        .bans_open = true,
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
    // First pick of the game: nothing shows on either side
    .{ .name = "mid-first", .status = .{ .select = .{
        .role = .middle,
        .turn = .pick,
        .picking = &.{.middle},
        .my_bans = &.{ "Zed", "Yasuo", "Kayn", "Thresh", "Master Yi" },
        .their_bans = &.{ "Darius", "Briar", "Smolder", "Mel", "Viego" },
        .mastery = &mid_mastery,
        .tier = "GOLD",
    } } },
    // A one-trick hovering their champion into a known lane opponent
    .{ .name = "top-one-trick", .status = .{ .select = .{
        .role = .top,
        .me = "Camille",
        .turn = .pick,
        .picking = &.{.top},
        .allies = &.{ .{ .jungle, "Sejuani" }, .{ .middle, "Ahri" }, .{ .bottom, "" }, .{ .utility, "" } },
        .enemies = &.{ "Jayce?", "Viego?" },
        .my_bans = &.{ "Fiora", "Yone", "Kayle" },
        .their_bans = &.{ "Teemo", "Darius", "Zed" },
        .mastery = &.{ .{ "Camille", 850_000 }, .{ "Fiora", 30_000 }, .{ "Irelia", 12_000 }, .{ "Riven", 4_000 } },
        .tier = "EMERALD",
    } } },
    // Most points on champions played years ago, not the ones wanted tonight
    .{ .name = "jungle-old-mains", .status = .{ .select = .{
        .role = .jungle,
        .turn = .pick,
        .picking = &.{ .jungle, .utility },
        .allies = &.{ .{ .top, "Ornn" }, .{ .middle, "Orianna~" }, .{ .bottom, "Jhin" }, .{ .utility, "" } },
        .enemies = &.{ "Jayce?", "Ahri?", "Kai'Sa?" },
        .my_bans = &.{ "Zed", "Yasuo", "Kayn", "Draven", "Briar" },
        .their_bans = &.{ "Smolder", "Mel", "Viego", "Ezreal", "Lux" },
        .mastery = &.{ .{ "Master Yi", 480_000 }, .{ "Warwick", 310_000 }, .{ "Amumu", 190_000 }, .{ "Shaco", 150_000 }, .{ "Vi", 40_000 }, .{ "Lee Sin", 25_000 }, .{ "Kha'Zix", 9_000 } },
        .tier = "PLATINUM",
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
    .{ .name = "loading", .status = .{ .loading = .{
        .role = .middle,
        .me = "Orianna",
        .locked = true,
        .phase = "FINALIZATION",
        .allies = &.{ .{ .top, "Darius" }, .{ .jungle, "Vi" }, .{ .bottom, "Jinx" }, .{ .utility, "Thresh" } },
        .enemies = &.{ "Ornn?", "Lee Sin?", "Syndra?", "Caitlyn?", "Leona?" },
        .tier = "GOLD",
    } } },
    .{ .name = "in-game", .status = .{ .game = .{} } },
    .{ .name = "post-game", .status = .{ .post = .{} } },
    .{ .name = "practice", .status = .{ .practice = .{ .open = true } } },
    .{ .name = "practice-picker", .status = .{ .practice = .{ .open = true, .picker = .{ .ally = .middle } } } },
    .{ .name = "practice-game", .status = .{ .practice = .{ .screen = .game } } },
    .{ .name = "practice-post", .status = .{ .practice = .{ .screen = .post } } },
};

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;
    const arena = init.arena.allocator();
    dvui.io = io;
    const argv = try init.minimal.args.toSlice(arena);
    var stats_path: ?[]const u8 = null;
    var curves_path: ?[]const u8 = null;
    var facts_path: ?[]const u8 = null;
    var icons_dir: ?[]const u8 = null;
    var out_dir: []const u8 = "zig-out/shots";
    var only: ?[]const u8 = null;
    var approved_dir: ?[]const u8 = null;
    var min_games: u32 = (core.Options{}).min_games;
    var i: usize = 1;
    while (i + 1 < argv.len) : (i += 2) {
        const flag = argv[i];
        if (std.mem.eql(u8, flag, "--stats")) stats_path = argv[i + 1];
        if (std.mem.eql(u8, flag, "--curves")) curves_path = argv[i + 1];
        if (std.mem.eql(u8, flag, "--facts")) facts_path = argv[i + 1];
        if (std.mem.eql(u8, flag, "--icons")) icons_dir = argv[i + 1];
        if (std.mem.eql(u8, flag, "--out")) out_dir = argv[i + 1];
        if (std.mem.eql(u8, flag, "--only")) only = argv[i + 1];
        if (std.mem.eql(u8, flag, "--compare")) approved_dir = argv[i + 1];
        if (std.mem.eql(u8, flag, "--min-games")) min_games = try std.fmt.parseInt(u32, argv[i + 1], 10);
    }
    const cwd = std.Io.Dir.cwd();
    const limit: std.Io.Limit = .limited(1 << 30);
    const stats_bytes = try cwd.readFileAlloc(io, stats_path orelse return error.NeedStats, arena, limit);
    const stats: core.Stats = try .parse(arena, stats_bytes);
    var curves: ?core.curvesfile.Curves = null;
    if (curves_path) |p| curves = try .parse(arena, try cwd.readFileAlloc(io, p, arena, limit));
    var facts: ?core.champfacts.Facts = null;
    if (facts_path) |p| facts = try .parse(arena, try cwd.readFileAlloc(io, p, arena, .limited(1 << 22)));
    const comp_in: comp.Input = .{ .stats = &stats, .curves = if (curves) |*c| c else null, .facts = if (facts) |*f| f else null };
    var icons: Icons = .{ .gpa = gpa };
    defer icons.deinit();
    if (icons_dir) |d| try icons.loadDir(io, d);
    try cwd.createDirPath(io, out_dir);

    var compared: usize = 0;
    var changed: usize = 0;
    for (shots) |shot| {
        if (only) |o| if (std.mem.indexOf(u8, shot.name, o) == null) continue;
        var frame_arena: std.heap.ArenaAllocator = .init(gpa);
        defer frame_arena.deinit();
        const a = frame_arena.allocator();
        const opts: core.Options = .{ .min_games = min_games };
        var setup: ?practice.Setup = null;
        const status: ui.Status = switch (shot.status) {
            .practice => |pr| blk: {
                var st: practice.Setup = .{ .screen = pr.screen };
                var prng: std.Random.DefaultPrng = .init(7);
                st.randomise(&stats, prng.random());
                if (pr.open) {
                    st.mine[@backingInt(st.role)] = .{};
                    st.theirs[3] = .{};
                    st.theirs[4] = .{};
                }
                setup = st;
                practice_ui.open(pr.picker orelse .{ .ally = .top });
                if (pr.picker == null) practice_ui.close();
                const in: practice.Input = .{ .stats = &stats, .curves = comp_in.curves, .facts = comp_in.facts, .tier = "GOLD" };
                break :blk switch (try practice.build(a, in, st)) {
                    .select => |sel| .{ .select = try dupe(a, ui.Select{ .card = sel.card, .board = sel.board, .comp = sel.comp }) },
                    .loading => |l| .{ .loading = try dupe(a, l) },
                    .in_game => |g| .{ .in_game = try dupe(a, g) },
                    .post_game => |pg| .{ .post_game = try dupe(a, pg) },
                };
            },
            .plain => |s| s,
            .loading => |scene| blk: {
                const cs = try champSelect(a, &stats, scene);
                const card = try lanecard.build(a, .{ .stats = &stats, .curves = if (curves) |*c| c else null, .role = scene.role, .me = cs.my_champion, .locked = true, .allies = cs.allies, .enemies = cs.enemies, .tier = scene.tier, .opts = opts });
                const b = try board.build(a, &stats, opts, cs, &card, comp_in.facts);
                const l = try a.create(loading.Loading);
                l.* = try loading.build(a, .{ .stats = &stats, .curves = if (curves) |*c| c else null, .facts = if (facts) |*f| f else null, .seats = try loading.seatsOf(a, &b), .draft = b.draft, .tier = scene.tier, .opts = opts });
                break :blk .{ .loading = l };
            },
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
                sel.board = try board.build(a, &stats, opts, cs, &sel.card, comp_in.facts);
                var in = comp_in;
                in.tier = scene.tier;
                sel.comp = try comp.after(a, in, &sel.board);
                break :blk .{ .select = sel };
            },
            .game => |gm| blk: {
                const body = try cwd.readFileAlloc(io, gm.path, a, limit);
                const g = try a.create(ingame.InGame);
                g.* = try ingame.build(a, &stats, if (curves) |*c| c else null, try lcu.live.parse(a, body), gm.tier);
                g.history = try ingame.madeUp(a, g.sample());
                break :blk .{ .in_game = g };
            },
            .post => |pg| blk: {
                const e = try lcu.eog.parse(a, try cwd.readFileAlloc(io, pg.path, a, limit));
                const p = try a.create(postgame.PostGame);
                p.* = try postgame.build(a, .{
                    .stats = &stats,
                    .curves = if (curves) |*c| c else null,
                    .eog = e,
                    .history = try ingame.madeUp(a, .{ .time = @floatFromInt(e.length), .team = pg.team, .lane = pg.lane }),
                    .tier = pg.tier,
                });
                break :blk .{ .post_game = p };
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
            const name = try a.print("{s}/{s}{s}.png", .{ out_dir, shot.name, sz[0] });
            const hook: ?practice_ui.Hook = if (setup != null) .{ .setup = &setup, .shown = true, .changed = noop } else null;
            const against: ?Against = if (approved_dir) |d| .{
                .approved = try a.print("{s}/{s}{s}.png", .{ d, shot.name, sz[0] }),
                .diff = try a.print("{s}/{s}{s}.diff.png", .{ out_dir, shot.name, sz[0] }),
            } else null;
            const sign: ?signin.Hook = if (shot.signin) |*st| .{ .state = st, .submit = noSubmit } else null;
            const diff = try render(gpa, io, .{ .status = status, .stats = &stats, .icons = &icons, .edition = sz[1], .practice = hook, .signin = sign }, sz[3], sz[2], name, against);
            compared += 1;
            switch (diff) {
                .same => std.debug.print("{s}\n", .{name}),
                .new => std.debug.print("{s}: NEW, no approved shot\n", .{name}),
                .size => std.debug.print("{s}: CHANGED, another size\n", .{name}),
                .pixels => |p| std.debug.print("{s}: CHANGED, {d} pixels in x {d}-{d}, y {d}-{d}\n", .{ name, p.count, p.x0, p.x1, p.y0, p.y1 }),
            }
            if (diff != .same) changed += 1;
        }
    }
    if (changed > 0) {
        std.debug.print("{d} of {d} shots differ from {s}: see {s}/*.diff.png\n", .{ changed, compared, approved_dir.?, out_dir });
        std.process.exit(1);
    }
}

const Against = struct {
    approved: []const u8,
    /// Written only when the shot differs
    diff: []const u8,
};

const Diff = union(enum) {
    same,
    new,
    size,
    pixels: struct { count: usize, x0: u32, y0: u32, x1: u32, y1: u32 },
};

fn noop() void {}

fn noSubmit(_: []const u8, _: []const u8) void {}

fn dupe(a: std.mem.Allocator, v: anytype) !*const @TypeOf(v) {
    const out = try a.create(@TypeOf(v));
    out.* = v;
    return out;
}

fn champion(stats: *const core.Stats, name: []const u8) !u32 {
    return stats.idOf(name) orelse error.UnknownChampion;
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
        .bans_open = s.bans_open,
    };
}

fn mastery(a: std.mem.Allocator, stats: *const core.Stats, s: Scene) ![]lanecard.Mastery {
    var out: std.ArrayList(lanecard.Mastery) = .empty;
    for (s.mastery) |m| try out.append(a, .{ .champion = try champion(stats, m[0]), .points = m[1] });
    return out.items;
}

fn render(gpa: std.mem.Allocator, io: std.Io, view: ui.View, size: dvui.Size.Natural, scale: f32, path: []const u8, against: ?Against) !Diff {
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
    const a = against orelse return .same;
    return compare(gpa, io, backend.screen.pixels, backend.screen.width, backend.screen.height, a);
}

fn compare(gpa: std.mem.Allocator, io: std.Io, pixels: []const u8, width: u32, height: u32, against: Against) !Diff {
    const cwd = std.Io.Dir.cwd();
    const bytes = cwd.readFileAlloc(io, against.approved, gpa, .limited(1 << 28)) catch |err| switch (err) {
        error.FileNotFound => return .new,
        else => return err,
    };
    defer gpa.free(bytes);
    var aw: c_int = undefined;
    var ah: c_int = undefined;
    var channels: c_int = undefined;
    const approved_ptr = dvui.c.stbi_load_from_memory(bytes.ptr, @intCast(bytes.len), &aw, &ah, &channels, 4) orelse return error.BadApprovedPng;
    defer dvui.c.stbi_image_free(approved_ptr);
    if (aw != width or ah != height) return .size;
    const approved = approved_ptr[0..pixels.len];
    if (std.mem.eql(u8, approved, pixels)) return .same;

    // Changed pixels red on the new shot at a third of its brightness
    const out = try gpa.alloc(u8, pixels.len);
    defer gpa.free(out);
    var d: Diff = .{ .pixels = .{ .count = 0, .x0 = width, .y0 = height, .x1 = 0, .y1 = 0 } };
    const p = &d.pixels;
    for (0..width * height) |i| {
        const px = pixels[i * 4 ..][0..4];
        if (std.mem.eql(u8, px, approved[i * 4 ..][0..4])) {
            out[i * 4 ..][0..4].* = .{ px[0] / 3, px[1] / 3, px[2] / 3, 255 };
            continue;
        }
        out[i * 4 ..][0..4].* = .{ 255, 0, 0, 255 };
        const x: u32 = @intCast(i % width);
        const y: u32 = @intCast(i / width);
        p.count += 1;
        p.x0 = @min(p.x0, x);
        p.x1 = @max(p.x1, x);
        p.y0 = @min(p.y0, y);
        p.y1 = @max(p.y1, y);
    }
    var file = try cwd.createFile(io, against.diff, .{});
    defer file.close(io);
    var buf: [64 * 1024]u8 = undefined;
    var w = file.writer(io, &buf);
    try dvui.PNGEncoder.writeWithResolution(&w.interface, out, width, height, 0);
    try w.interface.flush();
    return d;
}
