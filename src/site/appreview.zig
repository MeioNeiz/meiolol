//! The desktop app's review pages on the private site (/private/app, docs/plan/app.md
//! "Private site"): every screen the app can show, each at its own URL so meionotes
//! pins to it. The mock client's scenarios (testdata/lcu/scenarios, embedded) play
//! through the poller's own tick (poller.Replay against the mock on free local ports), a
//! page per change it would publish, rendered by the shell's screens.zig in both
//! editions: the same island and CSS, at the window's width or narrow, and a fake bridge
//! that shows what the page would send the shell.
//!   /private/app                      the first state's page (app.html)
//!   /private/app/<edition>/<slug>     a state; its app.bin under <slug>/ (review.js points
//!                                     the island's relative fetch there: nginx sends
//!                                     base-uri 'none' and drops a trailing slash)
//! Each state page: a navigator of every group and state on the left (full game's other
//! seats only through the bar's seat switch), a strip of the group's steps above the
//! frame while the navigator is a drawer, arrow keys between states and groups (nav.js)

const std = @import("std");
const store = @import("store");
const ui = @import("ui");
const desktop = @import("desktop");
const scenarios = @import("scenarios");
const screens = @import("../shell/screens.zig");
const shell_files = @import("../shell/files.zig");
const shell_practice = @import("../shell/practice.zig");
const shell_lobby = @import("../shell/lobby.zig");
const shell_home = @import("../shell/home.zig");
const site = @import("root.zig");
const csp = @import("csp.zig");
const core = desktop.core;
const poller = desktop.poller;
const state = desktop.state;
const practice = desktop.practice;
const mock = desktop.lcu.mock;
const Io = std.Io;
const Allocator = std.mem.Allocator;

pub const Inputs = struct {
    paths: poller.Paths,
    icons: screens.SiteIcons,
    /// The mock's lockfile goes here for the run
    work_dir: []const u8,
    /// The stats keep 1 game in this many (sampleOf): min_games shrinks to match, so the
    /// options lists show as on full data
    sample: u32 = 1,
};

pub const File = struct { path: []const u8, data: []const u8 };

const Edition = enum { public, private };

/// One screen to review
const Shot = struct {
    group: usize,
    slug: []const u8,
    title: []const u8,
    /// The navigator's name
    short: []const u8,
    status: state.Status,
    note: state.Note = .none,
    signin: ?ui.signin.SignIn = null,
    /// Private edition only, with practice's bar
    practice: ?practice.Setup = null,
    /// The board's seat clicks (lane N: allies 0-4, enemies 5-9; 255 mine, kept at
    /// `own_slot`): the slug that lane's page has
    lanes: [own_slot + 1]?[]const u8 = @splat(null),
    /// The scenario's step it was published on: the same moment from another seat
    step: u32 = 0,
    /// Another seat's lane after a click on it
    lane: bool = false,
    /// The lobby's form panel beside a waiting status
    form: ?desktop.lcu.me.Form = null,
};

const own_slot = state.enemy_lanes + core.Role.count;

const Group = struct {
    title: []const u8,
    text: []const u8,
    /// My seat, where the group has others' (seat_of)
    seat: ?[]const u8 = null,
    /// A group of `seat_of`'s steps from another seat: in no navigator, reached by the
    /// bar's seat switch
    seat_of: ?usize = null,
};

const root = "/private/app";

/// Every page and file under private/ (paths start "app"), in `a`
pub fn files(a: Allocator, gpa: Allocator, io: Io, in: Inputs) ![]File {
    const data = try poller.loadPaths(gpa, io, in.paths);
    defer poller.freeData(gpa, data);
    data.opts.min_games = @max(1, data.opts.min_games / @max(1, in.sample));
    var groups: std.ArrayList(Group) = .empty;
    var shots: std.ArrayList(Shot) = .empty;
    const lock = try std.fs.path.join(a, &.{ in.work_dir, "app-review.lockfile" });
    defer Io.Dir.cwd().deleteFile(io, lock) catch {};

    try groups.append(a, .{ .title = "The app on its own", .text = "Before the client, without data, signing in." });
    try others(a, &shots);
    for (scenarios.list, 0..) |sc, k| {
        const g = groups.items.len;
        // full-game's own seat is mid (cell 2), the others below
        try groups.append(a, .{ .title = readable(sc[0]), .text = try comment(a, sc[1]), .seat = if (k == 0) "Mid" else null });
        try play(a, gpa, io, data, lock, &shots, .{ .group = g, .name = sc[0], .bytes = sc[1] });
    }
    // Each seat: full-game's champ select from my other places
    const full_game = groups.items.len - scenarios.list.len;
    const seats = [_]struct { u8, []const u8, []const u8 }{ .{ 0, "top", "Top" }, .{ 1, "jungle", "Jungle" }, .{ 3, "bottom", "Bot" }, .{ 4, "support", "Support" } };
    for (seats) |s| {
        const g = groups.items.len;
        try groups.append(a, .{
            .title = try a.print("Full game as {s}", .{s[1]}),
            .text = try a.print("full-game's champ select played from the {s} seat (cell {d}).", .{ s[1], s[0] }),
            .seat = s[2],
            .seat_of = full_game,
        });
        try play(a, gpa, io, data, lock, &shots, .{ .group = g, .name = scenarios.list[0][0], .bytes = scenarios.list[0][1], .cell = s[0], .slug = s[1], .select_only = true });
    }
    {
        const g = groups.items.len;
        try groups.append(a, .{ .title = "Practice", .text = "The tester edition's practice bar on a seeded random draft, one per screen." });
        var setup: practice.Setup = .{};
        var rng: std.Random.DefaultPrng = .init(7);
        setup.randomise(&data.stats, rng.random());
        for ([_]practice.Screen{ .select, .loading, .game, .post }) |screen| {
            var x = setup;
            x.screen = screen;
            const built = try practice.build(a, .{
                .stats = &data.stats,
                .curves = if (data.curves) |*c| c else null,
                .facts = if (data.facts) |*f| f else null,
            }, x);
            try shots.append(a, .{
                .group = g,
                .slug = try a.print("practice-{t}", .{screen}),
                .title = try a.print("Practice: {t}", .{screen}),
                .short = switch (screen) {
                    .select => "Champ select",
                    .loading => "Loading screen",
                    .game => "In game",
                    .post => "Post game",
                },
                .status = try statusOf(a, built),
                .practice = x,
            });
        }
    }

    var out: std.ArrayList(File) = .empty;
    for ([_]Edition{ .public, .private }) |ed| {
        var c: screens.Ctx = .{ .stats = &data.stats, .facts = if (data.facts) |*f| f else null, .icons = null, .private = ed == .private, .site = &in.icons };
        for (shots.items, 0..) |*s, i| {
            if (s.practice != null and ed == .public) continue;
            c.practice = s.practice != null;
            try page(a, &out, c, ed, groups.items, shots.items, i, false);
        }
    }
    // The index is the first state, so the app shows on the first screen
    try page(a, &out, .{ .stats = &data.stats, .icons = null, .private = false, .site = &in.icons }, .public, groups.items, shots.items, 0, true);
    try out.appendSlice(a, &.{
        .{ .path = "app/app.css", .data = screens.css },
        .{ .path = "app/review.css", .data = review_css },
        .{ .path = "app/review.js", .data = review_js },
        .{ .path = "app/nav.js", .data = nav_js },
        .{ .path = "app/ui-app.js", .data = shell_files.get("ui-app.js").? },
        .{ .path = "app/ui-app.wasm", .data = shell_files.get("ui-app.wasm").? },
        .{ .path = "app/ui-practice.js", .data = shell_files.get("ui-practice.js").? },
        .{ .path = "app/ui-practice.wasm", .data = shell_files.get("ui-practice.wasm").? },
        .{ .path = "app/ui-picks.js", .data = shell_files.get("ui-picks.js").? },
        .{ .path = "app/ui-picks.wasm", .data = shell_files.get("ui-picks.wasm").? },
        .{ .path = "app/ui-teams.js", .data = shell_files.get("ui-teams.js").? },
        .{ .path = "app/ui-teams.wasm", .data = shell_files.get("ui-teams.wasm").? },
    });
    return out.items;
}

/// The private site's app/ and app.html under `out_dir`, each with a .gz (gzip_static).
/// Data from the box's files: the testers' stats and facts (web-loop.sh desktop_files)
/// and the current curves; nothing without the stats
pub fn write(gpa: Allocator, io: Io, out_dir: []const u8, data_dir: []const u8, db: store.Db) !void {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const cwd = Io.Dir.cwd();
    const stats = try std.fs.path.join(a, &.{ data_dir, "desktop/stats.bin" });
    cwd.access(io, stats, .{}) catch {
        std.log.info("app review pages: no {s}", .{stats});
        return;
    };
    const curves = try std.fs.path.join(a, &.{ data_dir, "export/recent-curves.bin" });
    const facts = try std.fs.path.join(a, &.{ data_dir, "desktop/champ-facts.tsv" });
    const list = try files(a, gpa, io, .{
        .paths = .{ .stats = stats, .curves = if (exists(io, curves)) curves else null, .facts = if (exists(io, facts)) facts else null },
        .icons = try siteIcons(a, db),
        .work_dir = data_dir,
    });
    var dir = try cwd.openDir(io, out_dir, .{});
    defer dir.close(io);
    for (list) |f| {
        if (std.fs.path.dirname(f.path)) |d| try dir.createDirPath(io, d);
        try dir.writeFile(io, .{ .sub_path = f.path, .data = f.data });
        try dir.writeFile(io, .{ .sub_path = try std.mem.concat(a, u8, &.{ f.path, ".gz" }), .data = try store.raw.compress(a, f.data) });
    }
}

/// The dev server's (serve.zig): made on the first request from what it loaded (its
/// stats.bin and champion facts, the shared view's curves), kept until it restarts. `name`
/// from private/, as `app/public/full-game-01`; null for none
pub fn devFile(gpa: Allocator, io: Io, loaded: *site.Loaded, name: []const u8, sample: u32) !?[]const u8 {
    try dev.mutex.lock(io);
    defer dev.mutex.unlock(io);
    if (dev.files == null) {
        const a = dev.arena.allocator();
        const work = "zig-out/app-review";
        try Io.Dir.cwd().createDirPath(io, work);
        const stats = work ++ "/stats.bin";
        const facts = work ++ "/champ-facts.tsv";
        try Io.Dir.cwd().writeFile(io, .{ .sub_path = stats, .data = (try loaded.get(a, "data/stats.bin")) orelse return error.NoStats });
        const has_facts = if (try loaded.get(a, "data/champ-facts.tsv")) |f| blk: {
            try Io.Dir.cwd().writeFile(io, .{ .sub_path = facts, .data = f });
            break :blk true;
        } else false;
        const shared = try loaded.site(.shared);
        const keys = try a.create(std.AutoHashMapUnmanaged(u32, []const u8));
        keys.* = .empty;
        for (shared.champs) |c| try keys.put(a, c.id, c.key);
        dev.files = try files(a, gpa, io, .{
            .paths = .{ .stats = stats, .curves = loaded.opts.curves[site.html.View.shared.index()], .facts = if (has_facts) facts else null },
            .icons = .{ .ddragon = shared.ddragon_version, .keys = keys },
            .work_dir = work,
            .sample = sample,
        });
    }
    for ([_][]const u8{ "", ".html" }) |ext| for (dev.files.?) |f| {
        if (f.path.len == name.len + ext.len and std.mem.startsWith(u8, f.path, name) and std.mem.endsWith(u8, f.path, ext)) return f.data;
    };
    return null;
}

var dev: struct {
    mutex: Io.Mutex = .init,
    arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator),
    files: ?[]File = null,
} = .{};

/// N of the "1/N" deploy/snap-small.sh ends `data_dir`/.source with; 1 for a full snapshot
pub fn sampleOf(io: Io, data_dir: []const u8) u32 {
    var buf: [1024]u8 = undefined;
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "{s}/.source", .{data_dir}) catch return 1;
    const text = Io.Dir.cwd().readFile(io, path, &buf) catch return 1;
    return parseSample(std.mem.trimEnd(u8, text, " \n"));
}

fn parseSample(source: []const u8) u32 {
    const last = source[(std.mem.findScalarLast(u8, source, ' ') orelse return 1) + 1 ..];
    if (!std.mem.startsWith(u8, last, "1/")) return 1;
    return @max(1, std.fmt.parseInt(u32, last[2..], 10) catch 1);
}

test parseSample {
    try std.testing.expectEqual(20, parseSample("/data/snap 47658878 317255680 1792483761 1/20"));
    try std.testing.expectEqual(1, parseSample(""));
    try std.testing.expectEqual(1, parseSample("/data/snap 1 2 3"));
}

fn exists(io: Io, path: []const u8) bool {
    Io.Dir.cwd().access(io, path, .{}) catch return false;
    return true;
}

/// Champion keys and the Data Dragon version for the site's icons
pub fn siteIcons(a: Allocator, db: store.Db) !screens.SiteIcons {
    const keys = try a.create(std.AutoHashMapUnmanaged(u32, []const u8));
    keys.* = .empty;
    var version: []const u8 = "";
    var q = try db.prepare("SELECT id, key, ddragon_version FROM champions");
    defer q.deinit();
    try q.bind(.{});
    while (try q.step()) {
        const r = q.row(struct { id: u32, key: []const u8, ddragon_version: []const u8 });
        try keys.put(a, r.id, try a.dupe(u8, r.key));
        if (version.len == 0) version = try a.dupe(u8, r.ddragon_version);
    }
    return .{ .ddragon = version, .keys = keys };
}

/// States with no client in them: before it starts, no data, sign in, an update waiting
fn others(a: Allocator, shots: *std.ArrayList(Shot)) !void {
    try shots.appendSlice(a, &.{
        .{ .group = 0, .slug = "signin", .short = "Sign in", .title = "First start: sign in, no data yet", .status = .no_data, .signin = .{ .full = true } },
        .{ .group = 0, .slug = "signin-busy", .short = "Signing in", .title = "Signing in", .status = .no_data, .signin = .{ .full = true, .busy = true } },
        .{ .group = 0, .slug = "signin-failed", .short = "Sign in refused", .title = "Sign in refused", .status = .no_data, .signin = .{ .full = true, .message = "Wrong username or password." } },
        .{ .group = 0, .slug = "downloading", .short = "Downloading the data", .title = "Signed in, downloading the data", .status = .no_data, .note = .{ .downloading = .{ .done = 12_400_000, .total = 38_100_000 } } },
        .{ .group = 0, .slug = "download-failed", .short = "Download failed", .title = "Download failed", .status = .no_data, .note = .{ .failed = .{ .why = "no connection to meio.lol", .minutes = 10 } } },
        .{ .group = 0, .slug = "no-data", .short = "No data", .title = "No data and no sign in offered", .status = .no_data },
        .{ .group = 0, .slug = "no-client", .short = "Client closed", .title = "League client closed", .status = .no_client },
        .{ .group = 0, .slug = "client-error", .short = "Client not reachable", .title = "Client not reachable", .status = .{ .client_error = "ConnectionRefused" } },
        .{ .group = 0, .slug = "home", .short = "Client home screen", .title = "Client on its home screen", .status = .{ .waiting = "Home" } },
        .{ .group = 0, .slug = "signed-out", .short = "Signed out", .title = "Signed out, data from before: the line under it", .status = .{ .waiting = "Lobby" }, .signin = .{ .full = false } },
        .{ .group = 0, .slug = "restart", .short = "Update waiting", .title = "A new version waits for the next start", .status = .{ .waiting = "Lobby" }, .note = .restart },
        .{ .group = 0, .slug = "update-moved", .short = "Update address gone", .title = "The update address is gone: get the new version", .status = .{ .waiting = "Lobby" }, .note = .moved },
    });
}

const Play = struct {
    group: usize,
    name: []const u8,
    bytes: []const u8,
    /// My cell, else the scenario's
    cell: ?u8 = null,
    /// Slug prefix, else the name
    slug: ?[]const u8 = null,
    /// Champ select's pages only
    select_only: bool = false,
};

/// The scenario step by step through the poller's tick; a shot whenever it would
/// publish. On full-game's last pick step, each ally's lane too (a seat click)
fn play(a: Allocator, gpa: Allocator, io: Io, data: *const poller.Data, lock: []const u8, shots: *std.ArrayList(Shot), p: Play) !void {
    var sc = try mock.Scenario.parse(a, p.name, p.bytes, scenarios.champions);
    if (p.cell) |c| sc.local_cell = c;
    var m: mock.Mock = .{ .gpa = gpa, .io = io, .scenario = &sc };
    const address = try Io.net.IpAddress.parse("127.0.0.1", 0);
    var lcu_server = try address.listen(io, .{ .reuse_address = true });
    defer lcu_server.deinit(io);
    var live_server = try address.listen(io, .{ .reuse_address = true });
    defer live_server.deinit(io);
    var group: Io.Group = .init;
    defer group.cancel(io);
    try group.concurrent(io, mock.Mock.serveLcu, .{ &m, &lcu_server });
    try group.concurrent(io, mock.Mock.serveLive, .{ &m, &live_server });
    var buf: [128]u8 = undefined;
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = lock, .data = try m.lockfile(&buf, lcu_server.socket.address.getPort()) });

    var r: poller.Replay = .init(gpa, io, lock, live_server.socket.address.getPort(), data);
    defer r.deinit();
    defer state.lane_role.store(state.own_lane, .release);
    const prefix = p.slug orelse p.name;
    var n: usize = 0;
    var steps: u32 = 0;
    var lanes_done = false;
    var picking_done = false;
    while (try m.advance()) |step| {
        steps += 1;
        var s = (try r.tick(a)) orelse continue;
        // Other players' facts land on the loading screen's second tick
        if (s == .loading) if (try r.tick(a)) |again| {
            s = again;
        };
        if (p.select_only and s != .select) continue;
        n += 1;
        const slug = try a.print("{s}-{d:0>2}", .{ prefix, n });
        const title = try describe(a, &sc, step, s);
        try shots.append(a, .{ .group = p.group, .slug = slug, .title = title, .short = try short(a, title), .status = s, .step = steps, .form = r.form(s) });
        if (p.cell != null or s != .select) continue;
        // My first pick turn: each enemy's lane, what they could pick into us; all ten
        // locked: every seat's lane, as a click on it shows it
        if (!picking_done and s.select.board.turn == .pick) {
            picking_done = true;
            try seatLanes(a, &r, shots, p.group, steps, state.enemy_lanes);
            try movedEnemies(a, &r, shots, p.group, steps);
        } else if (!lanes_done and desktop.comp.ready(&s.select.board)) {
            lanes_done = true;
            try seatLanes(a, &r, shots, p.group, steps, 0);
        }
    }
}

/// The board above with its first enemy seat dragged onto the second's row: a shot with
/// their roles swapped, then the moves undone for the shots after
fn movedEnemies(a: Allocator, r: *poller.Replay, shots: *std.ArrayList(Shot), group: usize, steps: u32) !void {
    const mine = for (0..shots.items.len) |i| {
        const k = shots.items.len - 1 - i;
        if (!shots.items[k].lane) break k;
    } else return;
    const two = r.moveEnemy() orelse return;
    const s = (try r.tick(a)) orelse return;
    // Back as the client has them: that tick's page is the one above
    defer {
        r.unmove();
        _ = r.tick(a) catch {};
    }
    if (s != .select) return;
    try shots.append(a, .{
        .group = group,
        .slug = try a.print("{s}-moved", .{shots.items[mine].slug}),
        .title = try a.print("{s}: enemy {s} dragged onto the {s} row (their roles swap)", .{ shots.items[mine].title, two[0].label(), two[1].label() }),
        .short = "Enemies moved",
        .status = s,
        .step = steps,
        .lane = true,
    });
}

/// The last shot's board clicked seat by seat from `first` (state.lane_role) to the
/// enemies' last: a shot per lane the poller shows, each linking to the others
fn seatLanes(a: Allocator, r: *poller.Replay, shots: *std.ArrayList(Shot), group: usize, steps: u32, first: u8) !void {
    const mine = shots.items.len - 1;
    const slug = shots.items[mine].slug;
    var k = first;
    while (k < own_slot) : (k += 1) {
        state.lane_role.store(k, .release);
        const seat = (try r.tick(a)) orelse continue;
        if (seat != .select or !seat.select.ally) continue;
        const enemy = k >= state.enemy_lanes;
        const role: core.Role = @fromBackingInt(@intCast(if (enemy) k - state.enemy_lanes else k));
        const name = role.label();
        const lane_slug = try a.print("{s}-lane-{s}{s}", .{ slug, if (enemy) "enemy-" else "", @tagName(role) });
        shots.items[mine].lanes[k] = lane_slug;
        try shots.append(a, .{
            .group = group,
            .slug = lane_slug,
            .title = try a.print("{s}: {s}{s}'s lane (their seat clicked)", .{ shots.items[mine].title, if (enemy) "enemy " else "", name }),
            .short = if (enemy)
                try a.print("Enemy {s}", .{name})
            else
                try a.print("{c}{s}'s lane", .{ std.ascii.toUpper(name[0]), name[1..] }),
            .status = seat,
            .step = steps,
            .lane = true,
        });
    }
    // Back to mine: that tick's page is the one above
    state.lane_role.store(state.own_lane, .release);
    _ = try r.tick(a);
    for (shots.items[mine + 1 ..]) |*x| {
        x.lanes = shots.items[mine].lanes;
        x.lanes[own_slot] = slug;
    }
}

/// The step's note, else what it changed
fn describe(a: Allocator, sc: *const mock.Scenario, step: std.json.Value, s: state.Status) ![]const u8 {
    const o = step.object;
    var w: Io.Writer.Allocating = .init(a);
    try w.writer.writeAll(switch (s) {
        .select => |x| try a.print("Champ select, {s}", .{x.board.stage}),
        .no_role => "Champ select, no lane",
        .waiting => |phase| phase,
        .loading => "Loading screen",
        .in_game => |g| try a.print("In game, {d}:{d:0>2}", .{ @as(u32, @intFromFloat(g.time)) / 60, @as(u32, @intFromFloat(g.time)) % 60 }),
        .post_game => "Post game",
        .no_client => "Client closed",
        .no_data => "No data",
        .client_error => |e| e,
    });
    if (o.get("note")) |v| return a.print("{s}: {s}", .{ w.written(), v.string });
    var sep: []const u8 = ": ";
    inline for (.{ "lock", "hover", "intent", "ban" }) |key| if (o.get(key)) |v| {
        try w.writer.print("{s}{s} ", .{ sep, key });
        sep = "; ";
        var it = v.object.iterator();
        var first = true;
        while (it.next()) |e| {
            const cell = std.fmt.parseInt(u8, e.key_ptr.*, 10) catch 0;
            try w.writer.print("{s}{s}{s}", .{ if (first) "" else ", ", e.value_ptr.string, if (cell == sc.local_cell) " (me)" else "" });
            first = false;
        }
    };
    if (o.get("swap") != null) try w.writer.print("{s}a trade", .{sep});
    return w.written();
}

/// The navigator's name: the title without the stage most of champ select is in
fn short(a: Allocator, title: []const u8) ![]const u8 {
    var t = title;
    for ([_][]const u8{ "Champ select, ", "Picks and bans: " }) |p| {
        if (std.mem.startsWith(u8, t, p)) t = t[p.len..];
    }
    if (t.len == title.len or t.len == 0) return t;
    const out = try a.dupe(u8, t);
    out[0] = std.ascii.toUpper(out[0]);
    return out;
}

/// A scenario's name for the navigator; its file name when it has none here
fn readable(name: []const u8) []const u8 {
    const names = [_]struct { []const u8, []const u8 }{
        .{ "full-game", "Full game" },
        .{ "lost-lead", "Lost lead" },
        .{ "laner-locked-first", "Laner locks first" },
        .{ "trade", "Trade" },
        .{ "dodge", "Dodge" },
        .{ "blind-normal", "Blind pick (normal)" },
        .{ "aram", "ARAM" },
    };
    for (names) |n| if (std.mem.eql(u8, n[0], name)) return n[1];
    return name;
}

fn comment(a: Allocator, bytes: []const u8) ![]const u8 {
    const v = try std.json.parseFromSliceLeaky(std.json.Value, a, bytes, .{});
    const c = v.object.get("_comment") orelse return "";
    return c.string;
}

/// As the poller's practiceStatus
fn statusOf(a: Allocator, built: practice.Built) !state.Status {
    return switch (built) {
        .select => |s| blk: {
            const sel = try a.create(state.Select);
            sel.* = .{ .card = s.card, .board = s.board, .comp = s.comp, .picks = s.picks };
            break :blk .{ .select = sel };
        },
        .loading => |l| .{ .loading = try dupe(a, l) },
        .in_game => |g| .{ .in_game = try dupe(a, g) },
        .post_game => |pg| .{ .post_game = try dupe(a, pg) },
    };
}

fn dupe(a: Allocator, v: anytype) !*const @TypeOf(v) {
    const out = try a.create(@TypeOf(v));
    out.* = v;
    return out;
}

fn url(a: Allocator, ed: Edition, slug: []const u8) ![]const u8 {
    return a.print("{s}/{t}/{s}", .{ root, ed, slug });
}

/// The state's page and its app.bin (practice.bin) for one edition; `as_index` the page
/// alone at app.html, its files fetched from the state's folder
fn page(a: Allocator, out: *std.ArrayList(File), c: screens.Ctx, ed: Edition, groups: []const Group, shots: []const Shot, i: usize, as_index: bool) !void {
    const s = shots[i];
    var d = try screens.data(a, c, s.status, s.note);
    d.seq = 1;
    screens.withSignIn(&d, s.signin);
    if (ed == .private) d.practice = if (s.practice != null) true else if (shell_practice.offered(.private, c.stats, null, s.status)) false else null;
    var bar: ?ui.practice.Data = null;
    if (s.practice) |x| {
        bar = try shell_practice.data(a, c, x, true);
        bar.?.seq = d.seq;
    }
    const under = try screens.compUnder(a, c, s.status);
    var opts: ?ui.picks.Data = switch (s.status) {
        .select => |x| try screens.picksOf(a, c, x),
        else => null,
    };
    if (opts) |*x| x.seq = d.seq;
    var teams = try screens.teamsOf(a, c, s.status);
    if (teams) |*x| x.seq = d.seq;
    const dir = try a.print("app/{t}/{s}", .{ ed, s.slug });
    const html = try screens.renderIn(a, d, bar, under, .{
        .css = root ++ "/app.css",
        .js = root ++ "/ui-app.js",
        .wasm = root ++ "/ui-app.wasm",
        .practice_js = root ++ "/ui-practice.js",
        .practice_wasm = root ++ "/ui-practice.wasm",
        .picks_js = root ++ "/ui-picks.js",
        .picks_wasm = root ++ "/ui-picks.wasm",
        .teams_js = root ++ "/ui-teams.js",
        .teams_wasm = root ++ "/ui-teams.wasm",
        .picks = opts,
        .teams = teams,
        .lobby = if (s.form) |*f| try shell_lobby.view(a, c, f) else null,
        .home = if (s.status == .waiting) try shell_home.view(a, c, if (s.form) |*f| f else null) else null,
        .build = try screens.gameBuild(a, c, s.status),
        .load = try screens.loadUnder(a, c, s.status),
        .post = try screens.postUnder(a, c, s.status),
        .head = try a.print(
            \\{s}<meta name="rv-bin" content="/private/{s}/"><link rel="stylesheet" href="{s}/review.css"><script src="{s}/review.js"></script><script src="{s}/nav.js" defer></script>
        , .{ csp.files_only, dir, root, root, root }),
        .top = try reviewTop(a, ed, groups, shots, i),
        .site = "",
        .live = if (as_index) "/private/app" else try url(a, ed, s.slug),
        .end = "</div>",
    });
    if (as_index) return out.append(a, .{ .path = "app.html", .data = html });
    try out.append(a, .{ .path = try a.print("{s}.html", .{dir}), .data = html });
    var bin: std.ArrayList(u8) = .empty;
    try ui.data.encode(a, ui.app.Data, d, &bin);
    try out.append(a, .{ .path = try a.print("{s}/app.bin", .{dir}), .data = bin.items });
    if (bar) |x| {
        var pbin: std.ArrayList(u8) = .empty;
        try ui.data.encode(a, ui.practice.Data, x, &pbin);
        try out.append(a, .{ .path = try a.print("{s}/practice.bin", .{dir}), .data = pbin.items });
    }
    if (opts) |x| {
        var kbin: std.ArrayList(u8) = .empty;
        try ui.data.encode(a, ui.picks.Data, x, &kbin);
        try out.append(a, .{ .path = try a.print("{s}/picks.bin", .{dir}), .data = kbin.items });
    }
    if (teams) |x| {
        var tbin: std.ArrayList(u8) = .empty;
        try ui.data.encode(a, ui.compview.Data, x, &tbin);
        try out.append(a, .{ .path = try a.print("{s}/teams.bin", .{dir}), .data = tbin.items });
    }
}

/// Every page's left side, the bar above the app (where this is, its neighbours, the
/// seat, app and width switches, what the page sent the shell), the group's steps, then
/// the frame the app draws in
fn reviewTop(a: Allocator, ed: Edition, groups: []const Group, shots: []const Shot, i: usize) ![]const u8 {
    const s = shots[i];
    const base = groups[s.group].seat_of orelse s.group;
    var w: Io.Writer.Allocating = .init(a);
    const x = &w.writer;
    try navigator(x, a, ed, groups, shots, if (base == s.group) i else sameStep(shots, ed, i, base) orelse i);
    try x.print("<header class=\"rv-bar\" data-edition=\"{t}\"", .{ed});
    for (s.lanes, 0..) |l, k| if (l) |slug| try x.print(" data-lane-{d}=\"{s}\"", .{ if (k == own_slot) state.own_lane else k, try url(a, ed, slug) });
    if (groupStart(groups, shots, ed, base, false)) |k| try x.print(" data-prev-group=\"{s}\"", .{try url(a, ed, shots[k].slug)});
    if (groupStart(groups, shots, ed, base, true)) |k| try x.print(" data-next-group=\"{s}\"", .{try url(a, ed, shots[k].slug)});
    try x.writeAll("><button type=\"button\" class=\"rv-menu\" aria-controls=\"rv-nav\" aria-expanded=\"false\">States</button><b>");
    try escaped(x, s.title);
    try x.writeAll("</b><span class=\"rv-sw\">");
    if (neighbour(groups, shots, ed, i, false)) |p| try x.print("<a href=\"{s}\" rel=\"prev\">Previous</a>", .{try url(a, ed, shots[p].slug)});
    if (neighbour(groups, shots, ed, i, true)) |n| try x.print("<a href=\"{s}\" rel=\"next\">Next</a>", .{try url(a, ed, shots[n].slug)});
    try x.writeAll("</span>");
    try seatSwitch(x, a, ed, groups, shots, i);
    try x.writeAll("<span class=\"rv-sw\">");
    for ([_]Edition{ .public, .private }) |e| {
        if (e == ed) {
            try x.print("<b title=\"{s}\">{s}</b>", .{ about(e), label(e) });
        } else if (s.practice == null) {
            try x.print("<a href=\"{s}\" title=\"{s}\">{s}</a>", .{ try url(a, e, s.slug), about(e), label(e) });
        } else try x.print("<span class=\"rv-off\" title=\"Private app only\">{s}</span>", .{label(e)});
    }
    try x.writeAll(
        \\</span><span class="rv-sw"><button type="button" data-rv-width="wide" title="The window as it opens, 1120 by 720">Window</button><button type="button" data-rv-width="full" title="Full screen: this browser's size">Full</button><button type="button" data-rv-width="narrow" title="420 wide">Narrow</button></span><output id="rv-log"></output></header>
    );
    try x.writeAll("<ol class=\"rv-steps\"><li><span>");
    try escaped(x, groups[s.group].title);
    try x.writeAll("</span></li>");
    var n: usize = 0;
    for (shots, 0..) |t, k| if (t.group == s.group and (ed == .private or t.practice == null)) {
        n += 1;
        try x.print("<li><a href=\"{s}\" data-label=\"", .{try url(a, ed, t.slug)});
        try escaped(x, t.title);
        try x.print("\"{s}>{d}</a></li>", .{ if (k == i) " aria-current=\"page\"" else "", n });
    };
    try x.writeAll("</ol><div class=\"rv-frame\">");
    return w.written();
}

/// The same moment of champ select from every seat the group has: mine, then the others'
fn seatSwitch(x: *Io.Writer, a: Allocator, ed: Edition, groups: []const Group, shots: []const Shot, i: usize) !void {
    const s = shots[i];
    const base = groups[s.group].seat_of orelse s.group;
    if (s.lane or s.status != .select or groups[base].seat == null) return;
    try x.writeAll("<span class=\"rv-sw\">Seat");
    for (groups, 0..) |g, gi| {
        if (gi != base and g.seat_of != base) continue;
        if (gi == s.group) {
            try x.print("<b>{s}</b>", .{g.seat.?});
        } else if (sameStep(shots, ed, i, gi)) |k| {
            try x.print("<a href=\"{s}\">{s}</a>", .{ try url(a, ed, shots[k].slug), g.seat.? });
        } else try x.print("<span class=\"rv-off\">{s}</span>", .{g.seat.?});
    }
    try x.writeAll("</span>");
}

/// Group `g`'s shot published on shot `i`'s scenario step, not a lane
fn sameStep(shots: []const Shot, ed: Edition, i: usize, g: usize) ?usize {
    for (shots, 0..) |t, k| {
        if (t.group == g and t.step == shots[i].step and !t.lane and (ed == .private or t.practice == null)) return k;
    }
    return null;
}

/// Every group and its states as this edition's links (practice: the private app's),
/// `cur` marked and only its group open. Other seats' groups only through the seat switch
fn navigator(x: *Io.Writer, a: Allocator, ed: Edition, groups: []const Group, shots: []const Shot, cur: usize) !void {
    try x.writeAll("<nav class=\"rv-nav\" id=\"rv-nav\" aria-label=\"App states\"><p class=\"rv-home\"><a href=\"/\">meiolol</a> / <a href=\"/private\">Private</a> / App review</p>");
    for (groups, 0..) |g, gi| {
        if (g.seat_of != null) continue;
        try x.print("<details{s}><summary>", .{if (shots[cur].group == gi) " open" else ""});
        try escaped(x, g.title);
        try x.writeAll("</summary><ol>");
        var n: usize = 0;
        for (shots, 0..) |s, k| if (s.group == gi) {
            n += 1;
            try x.print("<li><a href=\"{s}\" title=\"", .{try url(a, if (s.practice != null) .private else ed, s.slug)});
            try escaped(x, s.title);
            try x.print("\"{s}><i>{d}</i>", .{ if (cur == k) " aria-current=\"page\"" else "", n });
            try escaped(x, s.short);
            try x.writeAll("</a></li>");
        };
        try x.writeAll("</ol></details>");
    }
    try x.writeAll("</nav>");
}

fn label(e: Edition) []const u8 {
    return switch (e) {
        .public => "Public app",
        .private => "Private app",
    };
}

fn about(e: Edition) []const u8 {
    return switch (e) {
        .public => "The app Riot reviews, for everyone after the production key",
        .private => "The app friends download today: adds practice and in game",
    };
}

/// The next (or previous) shot this edition has: within the group for another seat's,
/// else skipping those
fn neighbour(groups: []const Group, shots: []const Shot, ed: Edition, i: usize, next: bool) ?usize {
    const seat = groups[shots[i].group].seat_of != null;
    var k = i;
    while (true) {
        if (next) {
            k += 1;
            if (k >= shots.len) return null;
        } else {
            if (k == 0) return null;
            k -= 1;
        }
        if (ed == .public and shots[k].practice != null) continue;
        if (seat) return if (shots[k].group == shots[i].group) k else null;
        if (groups[shots[k].group].seat_of == null) return k;
    }
}

/// The first shot this edition has in the next (or previous) navigator group that has one
fn groupStart(groups: []const Group, shots: []const Shot, ed: Edition, group: usize, next: bool) ?usize {
    var prev: ?usize = null;
    for (shots, 0..) |s, k| {
        if (ed == .public and s.practice != null) continue;
        if (groups[s.group].seat_of != null) continue;
        if (next) {
            if (s.group > group) return k;
        } else if (s.group < group and (prev == null or shots[prev.?].group != s.group)) prev = k;
    }
    return prev;
}

fn escaped(w: *Io.Writer, s: []const u8) !void {
    for (s) |ch| switch (ch) {
        '<' => try w.writeAll("&lt;"),
        '>' => try w.writeAll("&gt;"),
        '&' => try w.writeAll("&amp;"),
        '"' => try w.writeAll("&quot;"),
        else => try w.writeByte(ch),
    };
}

const review_css =
    \\.rv-bar { position: sticky; top: 0; z-index: 10; display: flex; flex-wrap: wrap; align-items: center; gap: 8px 16px;
    \\  padding: 8px 16px; background: #10141c; border-bottom: 1px solid #2a3140; font: 13px/1.4 system-ui, sans-serif; color: #c8cdd8; }
    \\.rv-bar a { color: #8ab4ff; }
    \\.rv-bar b { color: #fff; }
    \\.rv-off { color: #5d6577; }
    \\.rv-sw { display: inline-flex; gap: 8px; align-items: center; }
    \\.rv-sw button, .rv-menu { font: inherit; color: inherit; background: #1d2330; border: 1px solid #2a3140; border-radius: 4px; padding: 2px 8px; cursor: pointer; }
    \\html:not(.rv-narrow, .rv-full) [data-rv-width="wide"], .rv-narrow [data-rv-width="narrow"], .rv-full [data-rv-width="full"] { border-color: #8ab4ff; color: #fff; }
    \\#rv-log { flex-basis: 100%; color: #9aa3b5; font-family: ui-monospace, monospace; font-size: 12px; }
    \\#rv-log:empty { display: none; }
    \\.rv-steps { display: flex; flex-wrap: wrap; align-items: center; gap: 4px; list-style: none; max-width: 1120px; margin: 12px auto 0;
    \\  padding: 0 16px; box-sizing: border-box; font: 12px/1 system-ui, sans-serif; color: #9aa3b5; }
    \\.rv-steps span { margin-right: 6px; }
    \\.rv-steps a { position: relative; display: inline-block; min-width: 24px; box-sizing: border-box; padding: 5px 6px; text-align: center;
    \\  border: 1px solid #2a3140; border-radius: 4px; background: #141924; color: #c8cdd8; text-decoration: none; }
    \\.rv-steps a:hover, .rv-steps a:focus-visible { border-color: #8ab4ff; color: #fff; }
    \\.rv-steps [aria-current] { border-color: #8ab4ff; background: #8ab4ff; color: #0c1017; }
    \\.rv-steps a:hover::after { content: attr(data-label); position: absolute; left: 0; top: calc(100% + 6px); z-index: 30; width: max-content;
    \\  max-width: 360px; padding: 6px 8px; border: 1px solid #2a3140; border-radius: 4px; background: #1d2330; color: #fff;
    \\  line-height: 1.35; text-align: left; white-space: normal; }
    \\html:not(.rv-drawer) .rv-steps { display: none; }
    \\.rv-frame { --vh: 720px; width: 1120px; max-width: 100%; height: var(--vh); margin: 16px auto; overflow: auto;
    \\  outline: 1px dashed #2a3140; }
    \\.rv-narrow .rv-frame { --vh: 760px; width: 420px; }
    \\.rv-full .rv-frame { --vh: calc(100vh - 53px); width: auto; margin: 0; }
    \\/* The app's page sets its window height to 100vh; in the frame, the frame's */
    \\.rv-frame .c-page { --vh: inherit; }
    \\.rv-full .rv-steps { display: none; }
    \\.rv-narrow .rv-steps { max-width: 452px; }
    \\.rv-nav { position: fixed; z-index: 20; left: 0; top: 0; bottom: 0; width: 240px; box-sizing: border-box; overflow-y: auto;
    \\  padding: 10px 8px 48px; background: #0c1017; border-right: 1px solid #2a3140; font: 13px/1.35 system-ui, sans-serif; color: #c8cdd8; }
    \\body:has(> .rv-nav) { padding-left: 240px; }
    \\.rv-home { margin: 0; padding: 4px 8px 10px; color: #fff; font-weight: 600; }
    \\.rv-home a { color: #8ab4ff; font-weight: 400; }
    \\.rv-nav summary { padding: 4px 8px; border-radius: 4px; color: #fff; font-weight: 600; cursor: pointer; }
    \\.rv-nav summary:hover { background: #1d2330; }
    \\.rv-nav ol { margin: 0 0 6px; padding: 0; list-style: none; }
    \\.rv-nav li a { display: block; padding: 3px 8px 3px 12px; border-radius: 4px; color: #c8cdd8; text-decoration: none;
    \\  white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    \\.rv-nav li a:hover { background: #1d2330; color: #fff; }
    \\.rv-nav i { display: inline-block; min-width: 22px; color: #6b7385; font-style: normal; }
    \\.rv-nav [aria-current] { background: #22304d; color: #fff; box-shadow: inset 2px 0 #8ab4ff; }
    \\.rv-menu { display: none; }
    \\.rv-drawer body:has(> .rv-nav) { padding-left: 0; }
    \\.rv-drawer .rv-nav { transform: translateX(-100%); transition: transform 0.15s; }
    \\.rv-drawer.rv-nav-open .rv-nav { transform: none; box-shadow: 8px 0 24px #0009; }
    \\.rv-drawer .rv-menu { display: inline-block; }
    \\
;

/// Arrow keys between states and groups, the navigator's drawer when the frame leaves no
/// room for it, the current state in view
const nav_js =
    \\(() => {
    \\  const html = document.documentElement;
    \\  const nav = document.getElementById('rv-nav');
    \\  const bar = document.querySelector('.rv-bar');
    \\  if (!nav || !bar) return;
    \\  const dock = () => html.classList.toggle('rv-drawer', innerWidth < (html.classList.contains('rv-narrow') ? 720 : 1400));
    \\  dock();
    \\  addEventListener('resize', dock);
    \\  const menu = bar.querySelector('.rv-menu');
    \\  const open = (on) => {
    \\    html.classList.toggle('rv-nav-open', on);
    \\    menu.setAttribute('aria-expanded', on);
    \\  };
    \\  addEventListener('click', (e) => {
    \\    if (e.target.closest('[data-rv-width]')) return dock();
    \\    if (e.target.closest('.rv-menu')) return open(!html.classList.contains('rv-nav-open'));
    \\    if (!e.target.closest('#rv-nav')) open(false);
    \\  });
    \\  const cur = nav.querySelector('[aria-current]');
    \\  if (cur) nav.scrollTop = cur.offsetTop - nav.clientHeight / 2;
    \\  const typing = (t) => t && t.closest && t.closest('input, textarea, select, [contenteditable], .c-meionotes');
    \\  addEventListener('keydown', (e) => {
    \\    if (e.defaultPrevented || e.altKey || e.ctrlKey || e.metaKey || e.shiftKey) return;
    \\    if (typing(e.target) || typing(document.activeElement)) return;
    \\    if (e.key === 'Escape') return open(false);
    \\    const link = (rel) => { const l = bar.querySelector('[rel=' + rel + ']'); return l && l.href; };
    \\    const to = { ArrowLeft: link('prev'), ArrowRight: link('next'), ArrowUp: bar.dataset.prevGroup, ArrowDown: bar.dataset.nextGroup }[e.key];
    \\    if (!to) return;
    \\    e.preventDefault();
    \\    location.assign(to);
    \\  });
    \\})();
    \\
;

/// What the shell's webview gives a page (mac.zig's shim), faked, then the shell's own
/// bridge.js. Messages to the shell show in the bar; a seat click opens that lane's page.
/// The islands fetch app.bin, practice.bin, picks.bin and teams.bin relative to the page: from the
/// state's folder (rv-bin; the index is a state's page at another address)
const review_js =
    \\(() => {
    \\  const dir = document.querySelector('meta[name=rv-bin]').content;
    \\  const get = window.fetch;
    \\  window.fetch = (u, o) => get(typeof u === 'string' && /^(app|practice|picks|teams)\.bin\b/.test(u) ? dir + u : u, o);
    \\  const ls = [];
    \\  const show = (m) => { const o = document.getElementById('rv-log'); if (o) o.textContent = 'to the app: ' + m; };
    \\  window.meiololApp = location.origin + '/private/app';
    \\  window.chrome = window.chrome || {};
    \\  window.chrome.webview = {
    \\    postMessage: (m) => {
    \\      const j = JSON.parse(m);
    \\      if (j.painted) return;
    \\      const bar = document.querySelector('.rv-bar');
    \\      const to = j.lane !== undefined && bar && bar.getAttribute('data-lane-' + j.lane);
    \\      if (to) return location.assign(to);
    \\      show(m);
    \\    },
    \\    addEventListener: (t, f) => { if (t === 'message') ls.push(f); },
    \\  };
    \\  const key = 'meiolol-review-width';
    \\  const set = (w) => {
    \\    for (const k of ['narrow', 'full']) document.documentElement.classList.toggle('rv-' + k, w === k);
    \\    try { localStorage.setItem(key, w); } catch (e) {}
    \\  };
    \\  try { set(localStorage.getItem(key) || 'wide'); } catch (e) {}
    \\  addEventListener('click', (e) => {
    \\    const b = e.target.closest && e.target.closest('[data-rv-width]');
    \\    if (b) set(b.dataset.rvWidth);
    \\  });
    \\})();
    \\
++ shell_files.bridge_js;

const testing = std.testing;

test "every scenario's states as pages in both editions, practice testers only" {
    const gpa = testing.allocator;
    const io = testing.io;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    // Every champion the scenarios name, a few games for some
    const table = try std.json.parseFromSliceLeaky(std.json.Value, a, scenarios.champions, .{});
    var champs: std.ArrayList(core.statsfile.Champion) = .empty;
    var it = table.object.iterator();
    while (it.next()) |e| if (e.value_ptr.* == .integer) try champs.append(a, .{ .id = @intCast(e.value_ptr.integer), .name = e.key_ptr.* });
    var sb: core.statsfile.Builder = try .init(gpa, champs.items);
    defer sb.deinit();
    const ids = champs.items;
    for (0..60) |i| sb.addGame(.{
        .{ ids[i % 10].id, ids[10 + i % 10].id, ids[20 + i % 10].id, ids[30 + i % 10].id, ids[40 + i % 10].id },
        .{ ids[50 + i % 10].id, ids[60 + i % 10].id, ids[70 + i % 10].id, ids[80 + i % 10].id, ids[90 + i % 10].id },
    }, @intCast(i % 2));
    var aw: Io.Writer.Allocating = .init(a);
    try sb.write(&aw.writer, "test");
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = "stats.bin", .data = aw.written() });
    const dir = try std.fmt.allocPrint(a, ".zig-cache/tmp/{s}", .{tmp.sub_path});
    var keys: std.AutoHashMapUnmanaged(u32, []const u8) = .empty;
    try keys.put(a, 103, "Ahri");

    const list = try files(a, gpa, io, .{
        .paths = .{ .stats = try std.fs.path.join(a, &.{ dir, "stats.bin" }), .curves = null, .facts = null },
        .icons = .{ .ddragon = "16.21.1", .keys = &keys },
        .work_dir = dir,
    });
    var pages: [2]usize = .{ 0, 0 };
    var index_page: ?[]const u8 = null;
    var seat_switch = false;
    for (list) |f| {
        if (std.mem.eql(u8, f.path, "app.html")) index_page = f.data;
        // Another seat's same step from full game's champ select, and back
        if (std.mem.startsWith(u8, f.path, "app/public/full-game-") and std.mem.find(u8, f.data, "Seat<b>Mid</b><a href=\"/private/app/public/top-") != null) seat_switch = true;
        if (!std.mem.endsWith(u8, f.path, ".html") or !std.mem.startsWith(u8, f.path, "app/")) continue;
        const public = std.mem.startsWith(u8, f.path, "app/public/");
        pages[@intFromBool(public)] += 1;
        try testing.expect(std.mem.find(u8, f.data, "data-island=\"app\"") != null);
        try testing.expect(std.mem.find(u8, f.data, "<base") == null);
        try csp.check(f.data);
        try testing.expect(std.mem.find(u8, f.data, "aria-current=\"page\"") != null);
        // Its app.bin beside it
        const bin = try std.mem.concat(a, u8, &.{ f.path[0 .. f.path.len - ".html".len], "/app.bin" });
        for (list) |g| {
            if (std.mem.eql(u8, g.path, bin)) break;
        } else return error.NoAppBin;
        if (public) try testing.expect(std.mem.find(u8, f.data, "c-practice") == null);
    }
    // The testers' edition has the practice pages on top
    try testing.expectEqual(pages[1] + 4, pages[0]);
    try testing.expect(pages[1] > 40);
    try testing.expect(seat_switch);
    // The index: the first state, its files from that state's folder
    const ix = index_page orelse return error.NoIndex;
    try csp.check(ix);
    for ([_][]const u8{ "data-island=\"app\"", "content=\"/private/app/public/signin/\"", "/private/app/public/full-game-01", "/private/app/private/practice-post", "lane-top" }) |want| {
        if (std.mem.find(u8, ix, want) == null) {
            std.debug.print("index lacks {s}\n", .{want});
            return error.Missing;
        }
    }
    // Other seats are reached through the seat switch, not the navigator
    try testing.expect(std.mem.find(u8, ix, "/private/app/public/top-01") == null);
    // The site's icons where the shell has the client's
    for (list) |f| {
        if (std.mem.find(u8, f.data, "/icon/16.21.1/Ahri.jpg") != null) break;
    } else return error.NoSiteIcon;
}
