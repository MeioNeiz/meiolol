//! The desktop app's review pages on the private site (/private/app, docs/plan/app.md
//! "Private site"): every screen the app can show, each at its own URL so the notes tool
//! pins to it. The mock client's scenarios (testdata/lcu/scenarios, embedded) play
//! through the poller's own tick (poller.Replay against the mock on free local ports), a
//! page per change it would publish, rendered by the shell's screens.zig in both
//! editions: the same island and CSS, at the window's width or narrow, and a fake bridge
//! that shows what the page would send the shell.
//!   /private/app                      the index: opens the last edition's first state
//!   /private/app/<edition>/<slug>     a state; its app.bin under <slug>/ (review.js points
//!                                     the island's relative fetch there: nginx sends
//!                                     base-uri 'none' and drops a trailing slash)
//! Each state page: a navigator of every group and state on the left, a strip of the
//! group's steps above the frame, arrow keys between states and groups (nav.js)

const std = @import("std");
const store = @import("store");
const ui = @import("ui");
const desktop = @import("desktop");
const scenarios = @import("scenarios");
const screens = @import("../shell/screens.zig");
const shell_files = @import("../shell/files.zig");
const shell_practice = @import("../shell/practice.zig");
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
    restart: bool = false,
    /// Private edition only, with practice's bar
    practice: ?practice.Setup = null,
    /// The board's seat clicks (lane N, 255 mine): the slug that lane's page has
    lanes: [6]?[]const u8 = @splat(null),
};

const Group = struct { title: []const u8, text: []const u8 };

const root = "/private/app";

/// Every page and file under private/ (paths start "app"), in `a`
pub fn files(a: Allocator, gpa: Allocator, io: Io, in: Inputs) ![]File {
    const data = try poller.loadPaths(gpa, io, in.paths);
    defer poller.freeData(gpa, data);
    var groups: std.ArrayList(Group) = .empty;
    var shots: std.ArrayList(Shot) = .empty;
    const lock = try std.fs.path.join(a, &.{ in.work_dir, "app-review.lockfile" });
    defer Io.Dir.cwd().deleteFile(io, lock) catch {};

    try groups.append(a, .{ .title = "The app on its own", .text = "Before the client, without data, signing in." });
    try others(a, &shots);
    for (scenarios.list) |sc| {
        const g = groups.items.len;
        try groups.append(a, .{ .title = readable(sc[0]), .text = try comment(a, sc[1]) });
        try play(a, gpa, io, data, lock, &shots, .{ .group = g, .name = sc[0], .bytes = sc[1] });
    }
    // Each seat: full-game's champ select from my other places
    const seats = [_]struct { u8, []const u8 }{ .{ 0, "top" }, .{ 1, "jungle" }, .{ 3, "bottom" }, .{ 4, "support" } };
    for (seats) |s| {
        const g = groups.items.len;
        try groups.append(a, .{
            .title = try a.print("Full game as {s}", .{s[1]}),
            .text = try a.print("full-game's champ select played from the {s} seat (cell {d}).", .{ s[1], s[0] }),
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
        var c: screens.Ctx = .{ .stats = &data.stats, .icons = null, .private = ed == .private, .site = &in.icons };
        for (shots.items, 0..) |*s, i| {
            if (s.practice != null and ed == .public) continue;
            c.practice = s.practice != null;
            try page(a, &out, c, ed, groups.items, shots.items, i);
        }
    }
    try out.append(a, .{ .path = "app.html", .data = try index(a, groups.items, shots.items) });
    try out.appendSlice(a, &.{
        .{ .path = "app/app.css", .data = screens.css },
        .{ .path = "app/review.css", .data = review_css },
        .{ .path = "app/review.js", .data = review_js },
        .{ .path = "app/nav.js", .data = nav_js },
        .{ .path = "app/ui-app.js", .data = shell_files.get("ui-app.js").? },
        .{ .path = "app/ui-app.wasm", .data = shell_files.get("ui-app.wasm").? },
        .{ .path = "app/ui-practice.js", .data = shell_files.get("ui-practice.js").? },
        .{ .path = "app/ui-practice.wasm", .data = shell_files.get("ui-practice.wasm").? },
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
pub fn devFile(gpa: Allocator, io: Io, loaded: *site.Loaded, name: []const u8) !?[]const u8 {
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
        .{ .group = 0, .slug = "downloading", .short = "Downloading the data", .title = "Signed in, downloading the data", .status = .no_data, .note = .downloading },
        .{ .group = 0, .slug = "download-failed", .short = "Download failed", .title = "Download failed", .status = .no_data, .note = .{ .failed = "ConnectionTimedOut" } },
        .{ .group = 0, .slug = "no-data", .short = "No data", .title = "No data and no sign in offered", .status = .no_data },
        .{ .group = 0, .slug = "no-client", .short = "Client closed", .title = "League client closed", .status = .no_client },
        .{ .group = 0, .slug = "client-error", .short = "Client not reachable", .title = "Client not reachable", .status = .{ .client_error = "ConnectionRefused" } },
        .{ .group = 0, .slug = "home", .short = "Client home screen", .title = "Client on its home screen", .status = .{ .waiting = "Home" } },
        .{ .group = 0, .slug = "signed-out", .short = "Signed out", .title = "Signed out, data from before: the line under it", .status = .{ .waiting = "Lobby" }, .signin = .{ .full = false } },
        .{ .group = 0, .slug = "restart", .short = "Update waiting", .title = "A new version waits for the next start", .status = .{ .waiting = "Lobby" }, .restart = true },
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
    var lanes_done = false;
    while (try m.advance()) |step| {
        const s = (try r.tick(a)) orelse continue;
        if (p.select_only and s != .select) continue;
        n += 1;
        const slug = try a.print("{s}-{d:0>2}", .{ prefix, n });
        const title = try describe(a, &sc, step, s);
        const short = if (std.mem.startsWith(u8, title, "Champ select, ")) title["Champ select, ".len..] else title;
        try shots.append(a, .{ .group = p.group, .slug = slug, .title = title, .short = short, .status = s });
        // All ten locked: every ally's lane, as a seat click shows it
        if (lanes_done or p.cell != null or s != .select or s.select.comp == null) continue;
        lanes_done = true;
        const mine = shots.items.len - 1;
        for (core.Role.all) |role| {
            const i = @backingInt(role);
            state.lane_role.store(i, .release);
            const ally = (try r.tick(a)) orelse continue;
            if (ally != .select or !ally.select.ally) continue;
            const ally_slug = try a.print("{s}-lane-{s}", .{ slug, @tagName(role) });
            shots.items[mine].lanes[i] = ally_slug;
            try shots.append(a, .{
                .group = p.group,
                .slug = ally_slug,
                .title = try a.print("{s}: {s}'s lane (their seat clicked)", .{ shots.items[mine].title, role.label() }),
                .short = try a.print("{c}{s}'s lane", .{ std.ascii.toUpper(role.label()[0]), role.label()[1..] }),
                .status = ally,
            });
        }
        // Back to mine: that tick's page is the one above
        state.lane_role.store(state.own_lane, .release);
        _ = try r.tick(a);
        for (shots.items[mine + 1 ..]) |*x| {
            x.lanes = shots.items[mine].lanes;
            x.lanes[5] = slug;
        }
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

/// A scenario's name for the navigator; its file name when it has none here
fn readable(name: []const u8) []const u8 {
    const names = [_]struct { []const u8, []const u8 }{
        .{ "full-game", "Full game" },
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
            sel.* = .{ .card = s.card, .board = s.board, .comp = s.comp };
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

/// The state's page and its app.bin (practice.bin) for one edition
fn page(a: Allocator, out: *std.ArrayList(File), c: screens.Ctx, ed: Edition, groups: []const Group, shots: []const Shot, i: usize) !void {
    const s = shots[i];
    var d = try screens.data(a, c, s.status, s.note);
    d.seq = 1;
    d.signin = s.signin;
    d.restart = s.restart;
    if (ed == .private) d.practice = if (s.practice != null) true else if (shell_practice.offered(.private, c.stats, null, s.status)) false else null;
    var bar: ?ui.practice.Data = null;
    if (s.practice) |x| {
        bar = try shell_practice.data(a, c, x, true);
        bar.?.seq = d.seq;
    }
    const under: ?ui.compview.Comp = switch (s.status) {
        .select => |x| if (x.comp) |cv| try screens.compView(a, c, cv) else null,
        else => null,
    };
    const dir = try a.print("app/{t}/{s}", .{ ed, s.slug });
    var bin: std.ArrayList(u8) = .empty;
    try ui.data.encode(a, ui.app.Data, d, &bin);
    try out.append(a, .{ .path = try a.print("{s}/app.bin", .{dir}), .data = bin.items });
    if (bar) |x| {
        var pbin: std.ArrayList(u8) = .empty;
        try ui.data.encode(a, ui.practice.Data, x, &pbin);
        try out.append(a, .{ .path = try a.print("{s}/practice.bin", .{dir}), .data = pbin.items });
    }
    const html = try screens.renderIn(a, d, bar, under, .{
        .css = root ++ "/app.css",
        .js = root ++ "/ui-app.js",
        .wasm = root ++ "/ui-app.wasm",
        .practice_js = root ++ "/ui-practice.js",
        .practice_wasm = root ++ "/ui-practice.wasm",
        .head = try a.print(
            \\{s}<link rel="stylesheet" href="{s}/review.css"><script src="{s}/review.js"></script><script src="{s}/nav.js" defer></script>
        , .{ csp.files_only, root, root, root }),
        .top = try reviewTop(a, ed, groups, shots, i),
        .end = "</div>",
    });
    try out.append(a, .{ .path = try a.print("{s}.html", .{dir}), .data = html });
}

/// Every page's left side, the bar above the app (where this is, its neighbours, the
/// edition and width switches, what the page sent the shell), the group's steps, then
/// the frame the app draws in
fn reviewTop(a: Allocator, ed: Edition, groups: []const Group, shots: []const Shot, i: usize) ![]const u8 {
    const s = shots[i];
    var w: Io.Writer.Allocating = .init(a);
    const x = &w.writer;
    try navigator(x, a, ed, groups, shots, i);
    try x.print("<header class=\"rv-bar\" data-edition=\"{t}\"", .{ed});
    for (s.lanes, 0..) |l, k| if (l) |slug| try x.print(" data-lane-{d}=\"{s}\"", .{ if (k == 5) state.own_lane else k, try url(a, ed, slug) });
    if (groupStart(shots, ed, s.group, false)) |k| try x.print(" data-prev-group=\"{s}\"", .{try url(a, ed, shots[k].slug)});
    if (groupStart(shots, ed, s.group, true)) |k| try x.print(" data-next-group=\"{s}\"", .{try url(a, ed, shots[k].slug)});
    try x.writeAll("><button type=\"button\" class=\"rv-menu\" aria-controls=\"rv-nav\" aria-expanded=\"false\">States</button><b>");
    try escaped(x, s.title);
    try x.writeAll("</b><span class=\"rv-sw\">");
    if (neighbour(shots, ed, i, false)) |p| try x.print("<a href=\"{s}\" rel=\"prev\">Previous</a>", .{try url(a, ed, shots[p].slug)});
    if (neighbour(shots, ed, i, true)) |n| try x.print("<a href=\"{s}\" rel=\"next\">Next</a>", .{try url(a, ed, shots[n].slug)});
    try x.writeAll("</span><span class=\"rv-sw\">");
    for ([_]Edition{ .public, .private }) |e| {
        if (e == ed) {
            try x.print("<b>{s}</b>", .{label(e)});
        } else if (s.practice == null) {
            try x.print("<a href=\"{s}\">{s}</a>", .{ try url(a, e, s.slug), label(e) });
        } else try x.print("<span class=\"rv-off\" title=\"Testers only\">{s}</span>", .{label(e)});
    }
    try x.writeAll(
        \\</span><span class="rv-sw"><button type="button" data-rv-width="wide">Window</button><button type="button" data-rv-width="narrow">Narrow</button></span><output id="rv-log"></output></header>
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

/// Every group and its states as this edition's links (practice: the testers'), `cur`
/// marked and only its group open; the index has none, every group open
fn navigator(x: *Io.Writer, a: Allocator, ed: Edition, groups: []const Group, shots: []const Shot, cur: ?usize) !void {
    try x.writeAll("<nav class=\"rv-nav\" id=\"rv-nav\" aria-label=\"App states\"><p class=\"rv-home\"><a href=\"/private\">Private</a> / App review</p>");
    for (groups, 0..) |g, gi| {
        const open = if (cur) |k| shots[k].group == gi else true;
        try x.print("<details{s}><summary>", .{if (open) " open" else ""});
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
        .public => "Public",
        .private => "Testers",
    };
}

/// The next (or previous) shot this edition has
fn neighbour(shots: []const Shot, ed: Edition, i: usize, next: bool) ?usize {
    var k = i;
    while (true) {
        if (next) {
            k += 1;
            if (k >= shots.len) return null;
        } else {
            if (k == 0) return null;
            k -= 1;
        }
        if (ed == .private or shots[k].practice == null) return k;
    }
}

/// The first shot this edition has in the next (or previous) group that has one
fn groupStart(shots: []const Shot, ed: Edition, group: usize, next: bool) ?usize {
    var prev: ?usize = null;
    for (shots, 0..) |s, k| {
        if (ed == .public and s.practice != null) continue;
        if (next) {
            if (s.group > group) return k;
        } else if (s.group < group and (prev == null or shots[prev.?].group != s.group)) prev = k;
    }
    return prev;
}

/// The navigator full width; nav.js opens the last edition's first state from here
fn index(a: Allocator, groups: []const Group, shots: []const Shot) ![]const u8 {
    var w: Io.Writer.Allocating = .init(a);
    const x = &w.writer;
    try x.print(
        \\<!doctype html><html lang="en"><head><meta charset="utf-8">
        \\{s}<meta name="viewport" content="width=device-width, initial-scale=1">
        \\<meta name="robots" content="noindex"><title>App review</title>
        \\<link rel="stylesheet" href="{s}/app.css"><link rel="stylesheet" href="{s}/review.css"><script src="{s}/nav.js" defer></script></head>
        \\<body class="ui rv-index"><main data-first-public="{s}" data-first-private="{s}"><h1>App review</h1>
        \\<p>Every screen the desktop app can show, played from the mock client's scenarios through the app's own poller. Each opens as the public edition or the testers' (practice: testers only), at the window's width or narrow; notes pin to the page. Arrow keys: left and right for the previous and next state, up and down for the previous and next group.</p>
        \\
    , .{ csp.files_only, root, root, root, try url(a, .public, shots[0].slug), try url(a, .private, shots[0].slug) });
    try navigator(x, a, .public, groups, shots, null);
    try x.writeAll("</main></body></html>\n");
    return w.written();
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
    \\html:not(.rv-narrow) [data-rv-width="wide"], .rv-narrow [data-rv-width="narrow"] { border-color: #8ab4ff; color: #fff; }
    \\#rv-log { flex-basis: 100%; color: #9aa3b5; font-family: ui-monospace, monospace; font-size: 12px; }
    \\#rv-log:empty { display: none; }
    \\.rv-steps { display: flex; flex-wrap: wrap; align-items: center; gap: 4px; list-style: none; max-width: 1120px; margin: 12px auto 0;
    \\  padding: 0; font: 12px/1 system-ui, sans-serif; color: #9aa3b5; }
    \\.rv-steps span { margin-right: 6px; }
    \\.rv-steps a { position: relative; display: inline-block; min-width: 24px; box-sizing: border-box; padding: 5px 6px; text-align: center;
    \\  border: 1px solid #2a3140; border-radius: 4px; background: #141924; color: #c8cdd8; text-decoration: none; }
    \\.rv-steps a:hover, .rv-steps a:focus-visible { border-color: #8ab4ff; color: #fff; }
    \\.rv-steps [aria-current] { border-color: #8ab4ff; background: #8ab4ff; color: #0c1017; }
    \\.rv-steps a:hover::after { content: attr(data-label); position: absolute; left: 0; top: calc(100% + 6px); z-index: 30; width: max-content;
    \\  max-width: 360px; padding: 6px 8px; border: 1px solid #2a3140; border-radius: 4px; background: #1d2330; color: #fff;
    \\  line-height: 1.35; text-align: left; white-space: normal; }
    \\.rv-frame { width: 1120px; min-height: 720px; margin: 16px auto; outline: 1px dashed #2a3140; }
    \\.rv-narrow .rv-frame { width: 420px; }
    \\.rv-narrow .rv-steps { max-width: 420px; }
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
    \\.rv-index main { max-width: 900px; margin: 24px auto; padding: 0 16px; font: 14px/1.5 system-ui, sans-serif; }
    \\.rv-index .rv-nav { position: static; width: auto; padding: 0; border: 0; background: none; font-size: 14px; }
    \\.rv-index .rv-nav li a { white-space: normal; }
    \\.rv-index .rv-home { display: none; }
    \\
;

/// Arrow keys between states and groups, the navigator's drawer when the frame leaves no
/// room for it, the current state in view, and the index opening the last edition
const nav_js =
    \\(() => {
    \\  const html = document.documentElement;
    \\  const key = 'meiolol-review-edition';
    \\  const ix = document.querySelector('[data-first-public]');
    \\  if (ix) {
    \\    let ed = 'public';
    \\    try { ed = localStorage.getItem(key) === 'private' ? 'private' : ed; } catch (e) {}
    \\    return location.replace(ix.getAttribute('data-first-' + ed));
    \\  }
    \\  const nav = document.getElementById('rv-nav');
    \\  const bar = document.querySelector('.rv-bar');
    \\  if (!nav || !bar) return;
    \\  try { localStorage.setItem(key, bar.dataset.edition); } catch (e) {}
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
    \\  const typing = (t) => t && t.closest && t.closest('input, textarea, select, [contenteditable], .c-notes');
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
/// The islands fetch app.bin and practice.bin relative to the page: from its own folder
const review_js =
    \\(() => {
    \\  const dir = location.pathname.replace(/\/$/, '') + '/';
    \\  const get = window.fetch;
    \\  window.fetch = (u, o) => get(typeof u === 'string' && /^(app|practice)\.bin\b/.test(u) ? dir + u : u, o);
    \\  const ls = [];
    \\  const show = (m) => { const o = document.getElementById('rv-log'); if (o) o.textContent = 'to the app: ' + m; };
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
    \\  const set = (narrow) => {
    \\    document.documentElement.classList.toggle('rv-narrow', narrow);
    \\    try { localStorage.setItem(key, narrow ? 'narrow' : ''); } catch (e) {}
    \\  };
    \\  try { set(localStorage.getItem(key) === 'narrow'); } catch (e) {}
    \\  addEventListener('click', (e) => {
    \\    const b = e.target.closest && e.target.closest('[data-rv-width]');
    \\    if (b) set(b.dataset.rvWidth === 'narrow');
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
    for (list) |f| {
        if (std.mem.eql(u8, f.path, "app.html")) index_page = f.data;
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
    const ix = index_page orelse return error.NoIndex;
    try csp.check(ix);
    for ([_][]const u8{ "/private/app/public/full-game-01", "/private/app/private/practice-post", "/private/app/public/top-01", "lane-top" }) |want| {
        if (std.mem.find(u8, ix, want) == null) {
            std.debug.print("index lacks {s}\n", .{want});
            return error.Missing;
        }
    }
    // The site's icons where the shell has the client's
    for (list) |f| {
        if (std.mem.find(u8, f.data, "/icon/16.21.1/Ahri.jpg") != null) break;
    } else return error.NoSiteIcon;
}
