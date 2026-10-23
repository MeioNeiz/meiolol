const std = @import("std");
const core = @import("core");
const lcu = @import("lcu/root.zig");
const datafiles = @import("datafiles.zig");
const lanecard = @import("lanecard.zig");
const cardscenes = @import("cardscenes.zig");
const update = @import("desktop/update.zig");

// watch retries every second; Debug builds would print a stack trace for each
// error.Unexpected from the network layer
pub const std_options: std.Options = .{ .unexpected_error_tracing = false };

const Role = core.Role;
const Stats = core.Stats;
const Pick = core.Pick;

const usage =
    \\usage: meiolol-app <command> [options]
    \\
    \\commands:
    \\  suggest   offline suggestions from champion names
    \\            --role R          top, jungle, mid, bot, support (required)
    \\            --ally LIST       teammates, e.g. top=Darius,jungle="Lee Sin",bot=Jinx?
    \\                              (a trailing ? marks a hover, not a lock)
    \\            --enemy LIST      e.g. Ahri,Jinx or mid=Ahri (roles guessed if left out)
    \\            --ban LIST        e.g. Yasuo,Zed
    \\            --top N           how many to show (default 5)
    \\  cards [FILE]  the lane card for each scene in FILE (default
    \\            testdata/cards/scenes.json), as the desktop window shows it
    \\            --curves FILE     (default: data/export recent-curves.bin)
    \\  watch     follow champ select in the League client and suggest as it changes
    \\            --role R          used when the client gives no position (blind pick)
    \\            --top N
    \\            --lockfile PATH   (or env MEIOLOL_LOCKFILE)
    \\  session   print the champ select session JSON, player identities removed
    \\            --save PATH       write it to a file instead
    \\            --lockfile PATH
    \\  get PATH  GET any League client path and print the reply (identities removed)
    \\            --lockfile PATH
    \\  record DIR  save what the client sends through champ select, the game and its
    \\            end to DIR, identities removed; Ctrl+C to stop
    \\            --live-every N    seconds between in-game saves (default 30)
    \\            --lockfile PATH
    \\  update DIR  run the desktop app's update check on a folder: needs
    \\            DIR/update.key; swaps DIR/meiolol-desktop.exe if there is one
    \\            (env MEIOLOL_UPDATE_URL: another update directory)
    \\
    \\common:
    \\  --stats FILE      model file (default: newest data/export/stats-*.bin here,
    \\                    else next to this program)
    \\  --min-games N     fewest games in the role to be suggested (default 200)
    \\  --prior N         pseudo-games pulling duos and matchups to neutral (default 1000)
    \\  --expertise on|off  cards: rank the pool by mastery points too (default on)
    \\
    \\Suggestions only: meiolol never locks, bans or dodges, and never shows other
    \\players' names.
    \\
;

const Args = struct {
    stats: ?[]const u8 = null,
    role: ?Role = null,
    ally: ?[]const u8 = null,
    enemy: ?[]const u8 = null,
    ban: ?[]const u8 = null,
    top: usize = 5,
    curves: ?[]const u8 = null,
    lockfile: ?[]const u8 = null,
    save: ?[]const u8 = null,
    live_every: u32 = 30,
    opts: core.Options = .{},
    expertise: bool = true,
    positional: ?[]const u8 = null,
};

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const argv = try init.minimal.args.toSlice(arena);
    if (argv.len < 2) fail("", .{});
    const command = argv[1];
    var args = parseArgs(argv[2..]);
    if (args.lockfile == null) args.lockfile = init.environ_map.get("MEIOLOL_LOCKFILE");

    var out_buf: [16 * 1024]u8 = undefined;
    var out_file = std.Io.File.stdout().writer(init.io, &out_buf);
    const out = &out_file.interface;
    defer out.flush() catch {};

    const app: App = .{
        .gpa = init.gpa,
        .io = init.io,
        .arena = arena,
        .out = out,
        .args = args,
    };
    if (std.mem.eql(u8, command, "suggest")) return app.suggest();
    if (std.mem.eql(u8, command, "cards")) return app.cards();
    if (std.mem.eql(u8, command, "watch")) return app.watch();
    if (std.mem.eql(u8, command, "session")) return app.session();
    if (std.mem.eql(u8, command, "get")) return app.get();
    if (std.mem.eql(u8, command, "record")) return app.record();
    if (std.mem.eql(u8, command, "update")) return app.updateFolder(init.environ_map.get("MEIOLOL_UPDATE_URL"));
    if (std.mem.eql(u8, command, "help") or std.mem.eql(u8, command, "--help")) {
        std.debug.print(usage, .{});
        return;
    }
    fail("unknown command: {s}", .{command});
}

fn parseArgs(argv: []const [:0]const u8) Args {
    var args: Args = .{};
    var i: usize = 0;
    while (i < argv.len) : (i += 1) {
        const flag = argv[i];
        if (!std.mem.startsWith(u8, flag, "--")) {
            if (args.positional != null) fail("unexpected argument: {s}", .{flag});
            args.positional = flag;
            continue;
        }
        if (i + 1 >= argv.len) fail("{s} needs a value", .{flag});
        i += 1;
        const val = argv[i];
        if (std.mem.eql(u8, flag, "--stats")) {
            args.stats = val;
        } else if (std.mem.eql(u8, flag, "--curves")) {
            args.curves = val;
        } else if (std.mem.eql(u8, flag, "--role")) {
            args.role = Role.parse(val) orelse fail("--role: unknown role {s}", .{val});
        } else if (std.mem.eql(u8, flag, "--ally")) {
            args.ally = val;
        } else if (std.mem.eql(u8, flag, "--enemy")) {
            args.enemy = val;
        } else if (std.mem.eql(u8, flag, "--ban")) {
            args.ban = val;
        } else if (std.mem.eql(u8, flag, "--top")) {
            args.top = std.fmt.parseInt(usize, val, 10) catch
                fail("--top: not a number", .{});
            if (args.top == 0 or args.top > 50) fail("--top must be 1..50", .{});
        } else if (std.mem.eql(u8, flag, "--min-games")) {
            args.opts.min_games = std.fmt.parseInt(u32, val, 10) catch
                fail("--min-games: not a number", .{});
        } else if (std.mem.eql(u8, flag, "--prior")) {
            args.opts.prior_games = std.fmt.parseFloat(f64, val) catch
                fail("--prior: not a number", .{});
            if (args.opts.prior_games < 0) fail("--prior must be >= 0", .{});
        } else if (std.mem.eql(u8, flag, "--expertise")) {
            args.expertise = if (std.mem.eql(u8, val, "on")) true else if (std.mem.eql(u8, val, "off")) false else fail("--expertise: on or off", .{});
        } else if (std.mem.eql(u8, flag, "--lockfile")) {
            args.lockfile = val;
        } else if (std.mem.eql(u8, flag, "--save")) {
            args.save = val;
        } else if (std.mem.eql(u8, flag, "--live-every")) {
            args.live_every = std.fmt.parseInt(u32, val, 10) catch
                fail("--live-every: not a number", .{});
            if (args.live_every == 0) fail("--live-every must be at least 1", .{});
        } else fail("unknown option: {s}", .{flag});
    }
    return args;
}

const App = struct {
    gpa: std.mem.Allocator,
    io: std.Io,
    arena: std.mem.Allocator,
    out: *std.Io.Writer,
    args: Args,

    fn suggest(app: App) !void {
        const loaded = try app.loadStats();
        const stats = &loaded.stats;
        const role = app.args.role orelse fail("suggest needs --role", .{});
        const allies = try app.parsePicks(stats, app.args.ally, "--ally");
        const enemies = try app.parsePicks(stats, app.args.enemy, "--enemy");
        var bans: std.ArrayList(u32) = .empty;
        if (app.args.ban) |list| {
            var it = std.mem.splitScalar(u8, list, ',');
            while (it.next()) |raw| {
                const name = std.mem.trim(u8, raw, " \t\"'");
                if (name.len == 0) continue;
                try bans.append(app.arena, try app.champion(stats, name, "--ban"));
            }
        }
        const draft: core.Draft = .{
            .role = role,
            .allies = allies,
            .enemies = enemies,
            .bans = bans.items,
        };
        try app.printHeader(loaded);
        try printDraft(app.out, stats, draft, 0, false);
        try app.printSuggestions(stats, draft, 0);
    }

    fn cards(app: App) !void {
        const loaded = try app.loadStats();
        const stats = &loaded.stats;
        const path = app.args.positional orelse cardscenes.default_path;
        const scenes = cardscenes.load(app.arena, app.io, path) catch |err|
            fail("cannot read scenes {s}: {t}", .{ path, err });
        var curves: ?core.curvesfile.Curves = null;
        const curves_path = app.args.curves orelse try datafiles.curves(app.arena, app.io);
        if (curves_path) |p| {
            const bytes = std.Io.Dir.cwd().readFileAlloc(app.io, p, app.arena, .limited(1 << 30)) catch |err|
                fail("cannot read {s}: {t}", .{ p, err });
            curves = core.curvesfile.Curves.parse(app.arena, bytes) catch |err|
                fail("{s} is not a meiolol curves file: {t}", .{ p, err });
        }
        try app.printHeader(loaded);
        for (scenes) |s| {
            var bad: []const u8 = "";
            var in = cardscenes.input(app.arena, stats, if (curves) |*c| c else null, s, app.args.opts, &bad) catch |err|
                fail("scene {s}: {t} {s}", .{ s.name, err, bad });
            if (!app.args.expertise) in.expertise = null;
            try app.out.print("\n== {s}\n", .{s.name});
            try lanecard.write(try lanecard.build(app.arena, in), stats, app.out);
        }
    }

    /// "top=Darius,jungle=Lee Sin?,Ahri"
    fn parsePicks(
        app: App,
        stats: *const Stats,
        list: ?[]const u8,
        flag: []const u8,
    ) ![]Pick {
        var picks: std.ArrayList(Pick) = .empty;
        var it = std.mem.splitScalar(u8, list orelse return picks.items, ',');
        while (it.next()) |raw| {
            var item = std.mem.trim(u8, raw, " \t\"'");
            if (item.len == 0) continue;
            var pick: Pick = .{ .champion = 0 };
            if (std.mem.endsWith(u8, item, "?")) {
                pick.hover = true;
                item = item[0 .. item.len - 1];
            }
            if (std.mem.indexOfScalar(u8, item, '=')) |eq| {
                const role_name = std.mem.trim(u8, item[0..eq], " \t");
                pick.role = Role.parse(role_name) orelse
                    fail("{s}: unknown role {s}", .{ flag, role_name });
                item = std.mem.trim(u8, item[eq + 1 ..], " \t\"'");
            }
            pick.champion = try app.champion(stats, item, flag);
            try picks.append(app.arena, pick);
        }
        return picks.items;
    }

    fn champion(app: App, stats: *const Stats, name: []const u8, flag: []const u8) !u32 {
        _ = app;
        const i = stats.find(name) orelse
            fail("{s}: no single champion matches \"{s}\" in the stats file", .{
                flag,
                name,
            });
        return stats.ids[i];
    }

    const Loaded = struct { stats: Stats, path: []const u8 };

    fn loadStats(app: App) !Loaded {
        const path = app.args.stats orelse try datafiles.stats(app.arena, app.io) orelse
            fail("no stats file: pass --stats FILE (none in data/export)", .{});
        const cwd = std.Io.Dir.cwd();
        const limit: std.Io.Limit = .limited(1 << 30);
        const bytes = cwd.readFileAlloc(app.io, path, app.arena, limit) catch |err|
            fail("cannot read {s}: {t}", .{ path, err });
        const stats = Stats.parse(app.arena, bytes) catch |err|
            fail("{s} is not a meiolol stats file: {t}", .{ path, err });
        return .{ .stats = stats, .path = path };
    }

    fn printHeader(app: App, loaded: Loaded) !void {
        try app.out.print("stats {s}:{f}, {d} games, {d} champions\n", .{
            std.fs.path.basename(loaded.path),
            core.score.When{ .label = loaded.stats.patch },
            loaded.stats.games,
            loaded.stats.n,
        });
    }

    fn printSuggestions(
        app: App,
        stats: *const Stats,
        draft: core.Draft,
        mine: u32,
    ) !void {
        const w = app.out;
        const buf = try app.arena.alloc(core.Suggestion, app.args.top);
        const list = core.recommend(stats, draft, app.args.opts, buf);
        if (list.len == 0) {
            try w.print("no champion has {d}+ games in {s} that is still available\n", .{
                app.args.opts.min_games,
                draft.role.label(),
            });
            return;
        }
        try w.print("suggestions for {s} " ++
            "(win chance for your team, change vs an average pick):\n", .{
            draft.role.label(),
        });
        for (list, 1..) |s, rank| {
            try w.print("{d:>2}. {s:<16} {d:>5.1}%  ({s}{d:.1})  {d} games{s}\n", .{
                rank,
                stats.nameOf(s.champion),
                100 * s.win,
                if (s.pp >= 0) "+" else "",
                s.pp,
                s.games,
                if (s.champion == mine and mine != 0) "  <- your current pick" else "",
            });
            for (s.reasons()) |r| {
                try w.writeAll("      ");
                try core.score.describe(stats, r, w);
                try w.writeAll("\n");
            }
        }
    }

    fn connectOrExit(app: App) lcu.Client {
        const credentials = lcu.lockfile.discover(app.arena, app.io, app.args.lockfile) catch |err| switch (err) {
            error.ClientNotRunning => fail("League client not running", .{}),
            else => fail("cannot find the League client: {t}", .{err}),
        };
        return .{ .gpa = app.gpa, .io = app.io, .credentials = credentials };
    }

    fn get(app: App) !void {
        const path = app.args.positional orelse
            fail("get needs a path, e.g. {s}", .{lcu.session.paths.phase});
        if (!std.mem.startsWith(u8, path, "/")) fail("path must start with /", .{});
        const client = app.connectOrExit();
        const resp = client.get(path) catch |err| failGet(path, err);
        defer app.gpa.free(resp.body);
        const body = try lcu.session.redact(app.arena, resp.body);
        try app.out.print("HTTP {d}\n{s}\n", .{ resp.status, body });
    }

    fn updateFolder(app: App, base: ?[]const u8) !void {
        const path = app.args.positional orelse fail("update needs a folder", .{});
        var dir = try std.Io.Dir.cwd().openDir(app.io, path, .{ .iterate = true });
        defer dir.close(app.io);
        const key = update.readKey(app.arena, app.io, dir) orelse fail("no {s} in {s}", .{ update.key_file, path });
        const exe = "meiolol-desktop.exe";
        const has_exe = if (dir.access(app.io, exe, .{})) true else |_| false;
        const r = try update.run(.{
            .gpa = app.gpa,
            .io = app.io,
            .dir = dir,
            .exe = if (has_exe) exe else null,
            .base = base orelse update.default_base,
            .key = key,
        });
        try app.out.print("data {s}, exe {s}\n", .{
            if (r.data) "updated" else "current",
            if (r.exe) "replaced" else if (has_exe) "current" else "not here",
        });
    }

    fn session(app: App) !void {
        const client = app.connectOrExit();
        const resp = client.get(lcu.session.paths.session) catch |err|
            failGet(lcu.session.paths.session, err);
        defer app.gpa.free(resp.body);
        if (resp.status == 404) fail("not in champ select", .{});
        if (resp.status / 100 != 2) {
            fail("session: HTTP {d}: {s}", .{ resp.status, resp.body });
        }
        const clean = try lcu.session.redact(app.arena, resp.body);
        if (app.args.save) |path| {
            try std.Io.Dir.cwd().writeFile(app.io, .{ .sub_path = path, .data = clean });
            try app.out.print("saved {s} ({d} bytes, identities removed)\n", .{
                path,
                clean.len,
            });
        } else {
            try app.out.print("{s}\n", .{clean});
        }
    }

    fn record(app: App) !void {
        const path = app.args.positional orelse fail("record needs a folder", .{});
        const cwd = std.Io.Dir.cwd();
        try cwd.createDirPath(app.io, path);
        var dir = try cwd.openDir(app.io, path, .{});
        defer dir.close(app.io);
        try app.out.print("recording to {s}; Ctrl+C to stop\n", .{path});
        try app.out.flush();
        var r: lcu.Record = .{
            .gpa = app.gpa,
            .io = app.io,
            .dir = dir,
            .lockfile = app.args.lockfile,
            .live_every = app.args.live_every,
        };
        defer r.deinit();
        var waiting = false;
        while (true) {
            var frame: std.heap.ArenaAllocator = .init(app.gpa);
            defer frame.deinit();
            if (r.step(frame.allocator(), app.out)) |_| {
                waiting = false;
            } else |err| switch (err) {
                error.OutOfMemory, error.WriteFailed => return err,
                else => {
                    if (!waiting) try app.out.print("waiting for the League client ({t})\n", .{err});
                    waiting = true;
                    r.disconnect();
                },
            }
            app.out.flush() catch {};
            std.Io.sleep(app.io, .fromSeconds(1), .awake) catch {};
        }
    }

    fn watch(app: App) !void {
        const loaded = try app.loadStats();
        try app.printHeader(loaded);
        try app.out.writeAll("watching the League client; Ctrl+C to stop\n");
        try app.out.flush();
        var w: Watcher = .{
            .app = app,
            .stats = &loaded.stats,
            .watch = .init(app.gpa, app.io, app.args.lockfile),
        };
        defer w.deinit();
        while (true) {
            w.tick() catch |err| switch (err) {
                error.OutOfMemory, error.WriteFailed => return err,
                else => w.disconnect(err),
            };
            app.out.flush() catch {};
            std.Io.sleep(app.io, .fromSeconds(1), .awake) catch {};
        }
    }
};

const State = union(enum) {
    starting,
    no_client,
    client_error: anyerror,
    phase: u64,
    no_role,
    bad_session: anyerror,
    shown: u64,
};

const Watcher = struct {
    app: App,
    stats: *const Stats,
    watch: lcu.Watch,
    state: State = .starting,

    fn deinit(w: *Watcher) void {
        w.watch.deinit();
    }

    fn disconnect(w: *Watcher, err: anyerror) void {
        w.watch.disconnect();
        const next: State = if (err == error.ClientNotRunning)
            .no_client
        else
            .{ .client_error = err };
        if (std.meta.eql(next, w.state)) return;
        w.state = next;
        const out = w.app.out;
        const written = switch (next) {
            .no_client => out.writeAll("\nwaiting for the League client to start\n"),
            else => out.print("\nLeague client not reachable ({t}); retrying\n", .{err}),
        };
        written catch {};
    }

    fn tick(w: *Watcher) !void {
        var frame: std.heap.ArenaAllocator = .init(w.app.gpa);
        defer frame.deinit();
        const cs = switch (try w.watch.step(frame.allocator())) {
            .phase => |phase| {
                const h = std.hash.Wyhash.hash(1, phase);
                if (!std.meta.eql(w.state, State{ .phase = h })) {
                    w.state = .{ .phase = h };
                    try w.app.out.print("\nclient: {s}; waiting for champ select\n", .{
                        phase,
                    });
                }
                return;
            },
            .between => return,
            .bad_session => |err| {
                if (!std.meta.eql(w.state, State{ .bad_session = err })) {
                    w.state = .{ .bad_session = err };
                    const msg = "\ncannot read the champ select session ({t})\n";
                    try w.app.out.print(msg, .{err});
                }
                return;
            },
            .select => |cs| cs,
        };

        const role = cs.my_role orelse w.app.args.role orelse {
            if (w.state != .no_role) {
                w.state = .no_role;
                try w.app.out.writeAll("\nchamp select without assigned positions: " ++
                    "restart with --role R to get suggestions\n");
            }
            return;
        };
        const pool = w.watch.pool;
        var h: std.hash.Wyhash = .init(cs.fingerprint());
        h.update(std.mem.asBytes(&role));
        if (pool) |p| h.update(std.mem.sliceAsBytes(p));
        const key = h.final();
        if (std.meta.eql(w.state, State{ .shown = key })) return;
        w.state = .{ .shown = key };

        const out = w.app.out;
        const timer_phase = if (cs.phase.len > 0) cs.phase else "?";
        try out.print("\n=== champ select ({s}) ===\n", .{timer_phase});
        const draft = cs.draft(role, pool);
        try printDraft(out, w.stats, draft, cs.my_champion, cs.my_locked);
        if (cs.my_locked) {
            try out.print("you locked {s}\n", .{w.stats.nameOf(cs.my_champion)});
            return;
        }
        try w.app.printSuggestions(w.stats, draft, cs.my_champion);
    }
};

fn printDraft(
    w: *std.Io.Writer,
    stats: *const Stats,
    draft: core.Draft,
    mine: u32,
    locked: bool,
) !void {
    try w.print("you: {s}", .{draft.role.label()});
    if (mine != 0) {
        const how = if (locked) "locked" else "hovering";
        try w.print(", {s} {s}", .{ how, stats.nameOf(mine) });
    }
    try w.writeAll("\n");
    try printPicks(w, stats, "allies", draft.allies);
    try printPicks(w, stats, "enemies", draft.enemies);
    if (draft.bans.len > 0) {
        try w.writeAll("bans: ");
        for (draft.bans, 0..) |b, i| {
            try w.print("{s}{s}", .{ if (i > 0) ", " else "", stats.nameOf(b) });
        }
        try w.writeAll("\n");
    }
    if (draft.pool) |p| try w.print("your pool: {d} champions\n", .{p.len});
}

fn printPicks(
    w: *std.Io.Writer,
    stats: *const Stats,
    label: []const u8,
    picks: []const Pick,
) !void {
    if (picks.len == 0) return;
    try w.print("{s}: ", .{label});
    for (picks, 0..) |p, i| {
        if (i > 0) try w.writeAll(", ");
        try w.writeAll(stats.nameOf(p.champion));
        if (p.role != null or p.hover) {
            try w.print(" ({s}{s}{s})", .{
                if (p.role) |r| r.label() else "",
                if (p.role != null and p.hover) ", " else "",
                if (p.hover) "hover" else "",
            });
        }
    }
    try w.writeAll("\n");
}

fn failGet(path: []const u8, err: anyerror) noreturn {
    if (err == error.ClientNotRunning) {
        fail("League client not running (stale lockfile?)", .{});
    }
    fail("GET {s} failed: {t}", .{ path, err });
}

fn fail(comptime fmt: []const u8, args: anytype) noreturn {
    if (fmt.len > 0) {
        std.debug.print("error: " ++ fmt ++ "\n", args);
    } else {
        std.debug.print(usage, .{});
    }
    std.process.exit(1);
}

test {
    _ = lcu;
    _ = lanecard;
    _ = cardscenes;
    _ = @import("board.zig");
    _ = @import("ingame.zig");
    _ = @import("postgame.zig");
    _ = @import("loading.zig");
    _ = @import("desktop/icons.zig");
    _ = update;
    std.testing.refAllDecls(lcu);
}
