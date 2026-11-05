//! The app's page from the poller's state: ui.app.Data in the shell's words for its
//! edition, rendered to HTML for the first load and encoded (ui.data) as app.bin for the
//! island's patches. The public edition gets words, no win chances (docs/production-key.md).
//! All on the UI thread: refresh() on each tick or poller wake, get() from requests

const std = @import("std");
const ui = @import("ui");
const desktop = @import("desktop");
const core = desktop.core;
const poller = desktop.poller;
const state = desktop.state;
const board = desktop.board;
const lanecard = desktop.lanecard;
const loading = desktop.loading;
const comp = desktop.comp;
const ingame = desktop.ingame;
const postgame = desktop.postgame;
const files = @import("files.zig");
const practice = @import("practice.zig");
const lobby = @import("lobby.zig");
const home = @import("home.zig");
const channel = @import("channel.zig");
const app = ui.app;
const Allocator = std.mem.Allocator;

pub const css = ui.css.head ++ ui.css.join(.{ ui.site, ui.appbar, ui.badge, ui.chip, ui.card, ui.role, ui.champ, ui.draftboard, ui.champselect, ui.kda, ui.teamrows, ui.compview, ui.resultstrip, ui.lobby, ui.apphome, ui.today, ui.art, ui.skillgrid, ui.gamebuild, ui.bar, ui.spark, ui.loadscreen, ui.chart, ui.lane, ui.trend, ui.gamescreen, ui.postgame, ui.button, ui.signin, ui.segmented, ui.practice, ui.toggletip, ui.reasons, ui.rate, ui.candlist, ui.picks, ui.app });

const Page = struct {
    arena: std.heap.ArenaAllocator,
    html: []const u8,
    bin: []const u8,
    /// ui-practice.wasm's practice.bin; "" while practice is off
    practice: []const u8,
    /// A fingerprint of the static parts: the bar and the comp view under the island
    comp: u32,
    /// ui-picks.wasm's picks.bin; "" while there is no Options panel
    picks: []const u8,
    /// Champ select, the loading screen or a game: the window comes back from the site
    live: bool,
};

var page: ?Page = null;
var seq: u32 = 0;

/// The rendered page or app.bin as of the last refresh(); valid until the next
pub fn get(path: []const u8) ?[]const u8 {
    const p = page orelse return null;
    if (std.mem.eql(u8, path, files.start_page)) return p.html;
    if (std.mem.eql(u8, path, "app.bin")) return p.bin;
    if (std.mem.eql(u8, path, "practice.bin") and p.practice.len > 0) return p.practice;
    if (std.mem.eql(u8, path, "picks.bin") and p.picks.len > 0) return p.picks;
    return null;
}

/// An icon at icon/<id>.png (champions), item/, perk/ or spell/<id>.png, copied: the
/// poller may drop it
pub fn icon(gpa: Allocator, path: []const u8) ?[]u8 {
    const k = desktop.icons.keyOf(path) orelse return null;
    const s = poller.lock();
    defer poller.unlock();
    return gpa.dupe(u8, s.icons.art(k) orelse return null) catch null;
}

pub const Changed = struct {
    seq: u32,
    /// The bar or the comp view changed: static HTML, so not in app.bin's patches
    reload: bool,
    /// The live screen began (champ select, loading, a game)
    started: bool,

    pub fn message(c: Changed) channel.ToPage {
        return if (c.reload) .{ .reload = c.seq } else .{ .app = c.seq };
    }
};

/// Rebuilds from the poller, or without it (`live` false: --self-test) as if no client
/// ran; null when what the page shows is as before
pub fn refresh(gpa: Allocator, live: bool) ?Changed {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    const next = (build(arena.allocator(), live) catch null) orelse {
        arena.deinit();
        return null;
    };
    // The Options panel's island comes or goes with the page
    const reload = if (page) |old| old.comp != next.comp or (old.picks.len > 0) != (next.picks.len > 0) else false;
    const started = next.live and !(if (page) |old| old.live else false);
    if (page) |*old| old.arena.deinit();
    page = .{ .arena = arena, .html = next.html, .bin = next.bin, .practice = next.practice, .comp = next.comp, .picks = next.picks, .live = next.live };
    return .{ .seq = seq, .reload = reload, .started = started };
}

pub fn deinit() void {
    if (page) |*p| p.arena.deinit();
    page = null;
}

const Next = struct { html: []const u8, bin: []const u8, practice: []const u8, comp: u32, picks: []const u8, live: bool };

fn build(a: Allocator, live: bool) !?Next {
    if (!live) return finish(a, try data(a, .{ .stats = null, .icons = null, .private = false }, .no_client, .none), null, null, null, .{});
    const s = poller.lock();
    defer poller.unlock();
    const c: Ctx = .{
        .stats = s.stats,
        .facts = s.facts,
        .icons = s.icons,
        .private = s.edition == .private,
        .practice = state.private_code and s.practicing and s.practice.* != null,
        .region = switch (s.status) {
            .select => |x| regionOf(x),
            else => "EUW",
        },
    };
    var d = try data(a, c, s.status, s.note);
    withSignIn(&d, signIn(s.signin, s.status));
    var bar: ?ui.practice.Data = null;
    if (state.private_code and practice.offered(s.edition, s.stats, s.practice.*, s.status)) {
        d.practice = s.practice.* != null;
        if (s.practice.*) |x| bar = try practice.data(a, c, x, s.practicing);
    }
    const under = try compUnder(a, c, s.status);
    const opts: ?ui.picks.Data = switch (s.status) {
        .select => |x| try picksOf(a, c, x),
        else => null,
    };
    return finish(a, d, bar, under, opts, .{
        .form = if (s.form) |f| try lobby.view(a, c, f) else null,
        .home = if (s.status == .waiting) try home.view(a, c, s.form) else null,
        .build = try gameBuild(a, c, s.status),
        .load = try loadUnder(a, c, s.status),
        .post = try postUnder(a, c, s.status),
    });
}

/// The full form takes the note's place: the first of the first start's steps
pub fn withSignIn(d: *app.Data, s: ?ui.signin.SignIn) void {
    d.signin = s;
    if (s) |x| if (x.full) {
        d.screen = .{ .note = .{ .title = "", .step = .sign_in } };
    };
}

/// The form while there is no working sign-in: the whole screen until there is data
fn signIn(s: ?*const state.SignIn, status: state.Status) ?ui.signin.SignIn {
    const x = s orelse return null;
    if (!x.needed) return null;
    return .{ .full = status == .no_data, .busy = x.busy, .message = x.message };
}

/// Encoded and rendered into `a`, so nothing points into the poller's memory once it
/// unlocks; null when what shows is as before
/// The static panels after the island: before champ select the form panel and the tiles
/// beside it, the loading screen, the build panel in game, the post game
const Panels = struct {
    form: ?ui.lobby.Lobby = null,
    home: ?ui.apphome.Home = null,
    build: ?ui.gamebuild.Build = null,
    load: ?ui.loadscreen.Screen = null,
    post: ?ui.postgame.Screen = null,
};

fn finish(a: Allocator, shown: app.Data, bar: ?ui.practice.Data, under: ?ui.compview.Comp, opts: ?ui.picks.Data, panels: Panels) !?Next {
    var d = shown;
    d.seq = seq + 1;
    // The comp view and the panels are static: a change to any reloads the page
    var cbin: std.ArrayList(u8) = .empty;
    if (under) |x| try ui.data.encode(a, ui.compview.Comp, x, &cbin);
    if (panels.form) |x| try ui.data.encode(a, ui.lobby.Lobby, x, &cbin);
    if (panels.home) |x| try ui.data.encode(a, ui.apphome.Home, x, &cbin);
    if (panels.build) |x| try ui.data.encode(a, ui.gamebuild.Build, x, &cbin);
    if (panels.load) |x| try ui.data.encode(a, ui.loadscreen.Screen, x, &cbin);
    if (panels.post) |x| try ui.data.encode(a, ui.postgame.Screen, x, &cbin);
    try cbin.appendSlice(a, phase(d.where));
    try cbin.appendSlice(a, &.{ @intFromBool(state.by_mastery.load(.acquire)), @intFromBool(d.signin == null) });
    const comp_id = @as(u32, @truncate(std.hash.Wyhash.hash(0, cbin.items))) | 1;
    var bin: std.ArrayList(u8) = .empty;
    try ui.data.encode(a, app.Data, d, &bin);
    var pbin: std.ArrayList(u8) = .empty;
    var p = bar;
    if (p) |*x| {
        x.seq = d.seq;
        try ui.data.encode(a, ui.practice.Data, x.*, &pbin);
    }
    var kbin: std.ArrayList(u8) = .empty;
    var k = opts;
    if (k) |*x| {
        x.seq = d.seq;
        try ui.data.encode(a, ui.picks.Data, x.*, &kbin);
    }
    if (page) |old| if (std.mem.eql(u8, shows(old.bin), shows(bin.items)) and std.mem.eql(u8, shows(old.practice), shows(pbin.items)) and
        std.mem.eql(u8, shows(old.picks), shows(kbin.items)) and old.comp == comp_id) return null;
    seq += 1;
    const html = try renderIn(a, d, p, under, .{ .site = files.site, .mastery = state.by_mastery.load(.acquire), .picks = k, .lobby = panels.form, .home = panels.home, .build = panels.build, .load = panels.load, .post = panels.post });
    const live = switch (d.screen) {
        .select, .loading, .game => true,
        .note, .post => false,
    };
    return .{ .html = html, .bin = bin.items, .practice = pbin.items, .comp = comp_id, .picks = kbin.items, .live = live };
}

/// Past the fingerprint and seq: what shows
fn shows(bin: []const u8) []const u8 {
    return if (bin.len >= 8) bin[8..] else bin;
}

/// The page as of now with what it loads into `dir`/<seq>/, for a look without a window
/// (mac.zig --dump: serve the folder, open it in a browser)
pub fn dump(io: std.Io, gpa: Allocator, dir: []const u8) !void {
    const p = page orelse return;
    const sub = try std.fmt.allocPrint(gpa, "{s}/{d}", .{ dir, seq });
    defer gpa.free(sub);
    const own = [_]struct { []const u8, []const u8 }{ .{ files.start_page, p.html }, .{ "app.bin", p.bin }, .{ "practice.bin", p.practice }, .{ "picks.bin", p.picks } };
    for (own) |f| if (f[1].len > 0) try dumpFile(io, gpa, sub, f[0], f[1]);
    for ([_][]const u8{ "app.css", "ui-app.js", "ui-app.wasm", "ui-picks.js", "ui-picks.wasm", "ui-practice.js", "ui-practice.wasm" }) |f|
        if (files.get(f)) |bytes| try dumpFile(io, gpa, sub, f, bytes);
    var rest = p.html;
    while (std.mem.find(u8, rest, "src=\"")) |i| {
        rest = rest[i + "src=\"".len ..];
        const end = std.mem.findScalar(u8, rest, '"') orelse break;
        const png = icon(gpa, rest[0..end]) orelse continue;
        defer gpa.free(png);
        try dumpFile(io, gpa, sub, rest[0..end], png);
    }
}

fn dumpFile(io: std.Io, gpa: Allocator, dir: []const u8, name: []const u8, bytes: []const u8) !void {
    const path = try std.fs.path.join(gpa, &.{ dir, name });
    defer gpa.free(path);
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, std.fs.path.dirname(path).?);
    try cwd.writeFile(io, .{ .sub_path = path, .data = bytes });
}

/// With `bar`, practice's island above the app's and its file; with `under`, the comp
/// view after it
pub fn render(a: Allocator, d: app.Data, bar: ?ui.practice.Data, under: ?ui.compview.Comp) ![]const u8 {
    return renderIn(a, d, bar, under, .{ .site = files.site, .mastery = state.by_mastery.load(.acquire) });
}

/// The live link's label: `where` without the stage or clock ("Champ select · Picks")
pub fn phase(where: []const u8) []const u8 {
    return if (std.mem.find(u8, where, " · ")) |i| where[0..i] else where;
}

/// What the page links and wraps it in: the shell's own files, or the review pages'
/// (src/site/appreview.zig)
pub const Frame = struct {
    css: []const u8 = "app.css",
    js: []const u8 = "ui-app.js",
    wasm: []const u8 = "ui-app.wasm",
    practice_js: []const u8 = "ui-practice.js",
    practice_wasm: []const u8 = "ui-practice.wasm",
    picks_js: []const u8 = "ui-picks.js",
    picks_wasm: []const u8 = "ui-picks.wasm",
    /// The Options panel's island after the app's (ui/picks.zig); null none
    picks: ?ui.picks.Data = null,
    /// The lobby's form panel after the island (ui/lobby.zig); null none
    lobby: ?ui.lobby.Lobby = null,
    /// The lobby's tiles after the form panel (ui/apphome.zig); null none
    home: ?ui.apphome.Home = null,
    /// The in-game build panel after the island (ui/gamebuild.zig); null none
    build: ?ui.gamebuild.Build = null,
    /// The loading screen after the island (ui/loadscreen.zig), the comp view under it
    load: ?ui.loadscreen.Screen = null,
    /// The post game after the island (ui/postgame.zig)
    post: ?ui.postgame.Screen = null,
    /// Before </head>
    head: []const u8 = "",
    /// After <body> and before the scripts
    top: []const u8 = "",
    /// The bar's: the site's address, the live screen's, the mastery setting (ui/appbar.zig)
    site: []const u8 = "https://meio.lol",
    live: []const u8 = "/",
    mastery: bool = true,
    end: []const u8 = "",
};

pub fn renderIn(a: Allocator, d: app.Data, bar: ?ui.practice.Data, under: ?ui.compview.Comp, f: Frame) ![]const u8 {
    var t: ui.Tree = .{};
    var h: ui.H = .init(a, &t);
    const head = ui.appbar.view(&h, .{
        .site = f.site,
        .live = f.live,
        .phase = phase(d.where),
        .private = d.private,
        .practice = d.practice,
        .mastery = f.mastery,
        .signed_in = d.signin == null,
    });
    var island: app.App = .{ .data = d };
    const body = island.view(&h);
    var drill: ui.practice.Practice = undefined;
    const top: ?ui.N = if (bar) |x| blk: {
        drill = .{ .data = x };
        break :blk drill.view(&h);
    } else null;
    var options: ui.picks.Picks = undefined;
    const picks_n: ?ui.N = if (f.picks) |x| blk: {
        options = .{ .data = x };
        break :blk options.view(&h);
    } else null;
    const comp_n: ?ui.N = if (under) |x| ui.compview.view(&h, x) else null;
    // Champ select's views (ui/app.zig): CSS reads the checked radio, so no island byte;
    // a page reload (the comp view coming) starts on Options again
    const views = [_]ui.segmented.Item{
        .{ .label = .{ .s = "Options" }, .value = "options", .selected = true },
        .{ .label = .{ .s = "Lane" }, .value = "lane" },
        .{ .label = .{ .s = "Comps" }, .value = "comp" },
    };
    const tabs_n: ?ui.N = if (d.screen == .select) ui.segmented.radios(&h, "cs-view", .{ .s = .s, .label = .{ .s = "View" } }, views[0..if (under != null) 3 else 2]) else null;
    const lobby_n: ?ui.N = if (f.lobby) |x| ui.lobby.view(&h, x) else null;
    const home_n: ?ui.N = if (f.home) |x| ui.apphome.view(&h, f.site, x) else null;
    const build_n: ?ui.N = if (f.build) |x| ui.gamebuild.view(&h, x) else null;
    const load_n: ?ui.N = if (f.load) |x| ui.loadscreen.view(&h, x) else null;
    const post_n: ?ui.N = if (f.post) |x| ui.postgame.view(&h, x) else null;
    if (h.oom) return error.OutOfMemory;
    var out: std.Io.Writer.Allocating = .init(a);
    const w = &out.writer;
    try w.print(
        \\<!doctype html><html lang="en"><head><meta charset="utf-8">
        \\<meta name="viewport" content="width=device-width, initial-scale=1">
        \\<title>meiolol</title><link rel="stylesheet" href="{s}">{s}</head>
        \\<body class="ui">{s}
    , .{ f.css, f.head, f.top });
    // ui/app.zig's page and live area: what lays the islands and panels out together
    try w.writeAll("<div class=\"c-page\">");
    try ui.html.write(&t, head, w);
    if (top) |n| try ui.html.write(&t, n, w);
    try w.writeAll("<main class=\"c-live\">");
    try ui.html.write(&t, body, w);
    if (load_n) |n| try ui.html.write(&t, n, w);
    if (post_n) |n| try ui.html.write(&t, n, w);
    if (tabs_n) |n| try ui.html.write(&t, n, w);
    if (picks_n) |n| try ui.html.write(&t, n, w);
    if (comp_n) |n| try ui.html.write(&t, n, w);
    if (lobby_n) |n| try ui.html.write(&t, n, w);
    if (home_n) |n| try ui.html.write(&t, n, w);
    if (build_n) |n| try ui.html.write(&t, n, w);
    try w.writeAll("</main></div>");
    try w.print("{s}\n<script src=\"{s}\" data-wasm=\"{s}\" defer></script>", .{ f.end, f.js, f.wasm });
    if (top != null) try w.print("<script src=\"{s}\" data-wasm=\"{s}\" defer></script>", .{ f.practice_js, f.practice_wasm });
    if (picks_n != null) try w.print("<script src=\"{s}\" data-wasm=\"{s}\" defer></script>", .{ f.picks_js, f.picks_wasm });
    try w.writeAll("</body></html>\n");
    return out.written();
}

pub const SiteIcons = struct {
    ddragon: []const u8,
    keys: *const std.AutoHashMapUnmanaged(u32, []const u8),
};

pub const Ctx = struct {
    stats: ?*const core.Stats,
    /// Most picked runes and spells for the Options rows
    facts: ?*const core.champfacts.Facts = null,
    icons: ?*const desktop.Icons,
    private: bool,
    /// Practice shows: the board's seats and options carry practice's clicks
    practice: bool = false,
    /// The site's icons in place of the client's (the review pages)
    site: ?*const SiteIcons = null,
    /// Where champ select's stats are from (regionOf); lane gold is EUW's whatever this says
    region: []const u8 = "EUW",

    pub fn champ(c: Ctx, a: Allocator, id: u32) !?ui.champ.Champ {
        if (id == 0) return null;
        const stats = c.stats orelse return null;
        if (c.site) |s| if (s.keys.get(id)) |key| return .{ .name = stats.nameOf(id), .src = try a.print(ui.champ.icon_fmt, .{ s.ddragon, key }) };
        const has = if (c.icons) |i| i.get(id) != null else false;
        return .{ .name = stats.nameOf(id), .src = if (has) try a.print("icon/{d}.png", .{id}) else "" };
    }

    /// The site's JPEG, the client's icon once fetched, else "" (an empty square)
    pub fn item(c: Ctx, a: Allocator, id: u32) ![]const u8 {
        if (c.site) |s| return a.print("/dd/{s}/img/item/{d}.jpg", .{ s.ddragon, id });
        const icons = c.icons orelse return "";
        return if (icons.art(.{ .kind = .item, .id = id }) != null) a.print("item/{d}.png", .{id}) else "";
    }

    /// Practice's click on a board element (data-act); "" while practice doesn't show
    fn act(c: Ctx, a: Allocator, x: ui.practice.Act) ![]const u8 {
        if (!state.private_code or !c.practice) return "";
        return a.print("{f}", .{x});
    }

    /// The client's icon once fetched, else "": the review pages' site art is by path,
    /// not id
    fn clientArt(c: Ctx, a: Allocator, kind: desktop.icons.Kind, id: u32) ![]const u8 {
        const icons = c.icons orelse return "";
        return if (icons.art(.{ .kind = kind, .id = id }) != null) a.print("{s}/{d}.png", .{ kind.route(), id }) else "";
    }
};

pub fn data(a: Allocator, c: Ctx, status: state.Status, note: state.Note) !app.Data {
    return .{
        .seq = 0,
        .private = c.private,
        .where = switch (status) {
            .no_data => "No data",
            .no_client => "Client closed",
            .client_error => "Client error",
            .waiting => |p| p,
            .no_role => "Champ select",
            .select => |s| try a.print("Champ select · {s}", .{s.board.stage}),
            .loading => "Loading",
            .in_game => |g| if (c.private) try a.print("In game · {s}", .{ingame.clock(try a.alloc(u8, 16), g.time)}) else "In game",
            .post_game => "Post game",
        },
        .screen = switch (status) {
            .no_data => .{
                .note = switch (note) {
                    .downloading => |x| .{
                        .title = "Downloading stats",
                        .text = if (x.total > 0) try a.print("{d:.1} / {d:.1} MB", .{ mb(x.done), mb(x.total) }) else "",
                        .step = .download,
                        .bar = if (x.total > 0) @intCast(@max(1, @min(100, x.done * 100 / x.total))) else 0,
                    },
                    .failed => |f| .{
                        .title = "Download failed",
                        .text = try a.print("{s}; trying again in {d} minutes.", .{ try upper(a, f.why), f.minutes }),
                        .step = .download,
                        .failed = true,
                    },
                    // The foot says how to get the new version
                    .moved => .{ .title = "Download failed", .step = .download, .failed = true },
                    .none, .restart => .{ .title = "No stats file found", .text = "Put stats-*.bin and recent-curves.bin next to the app.", .step = .download },
                },
            },
            .no_client => .{ .note = .{ .title = "Waiting for League", .step = .open_league } },
            .client_error => |e| .{ .note = .{ .title = "League client not reachable", .text = try a.print("{s}; retrying.", .{e}) } },
            .waiting => .{ .note = .{ .title = "The board shows in champ select", .text = "Both teams, your lane, options and bans." } },
            .no_role => .{ .note = .{ .title = "No lane to show", .text = "This champ select has no assigned positions." } },
            .select => |s| .{ .select = try select(a, c, s) },
            .loading => .loading,
            // The public edition gets the panel once the private one has proved it
            .in_game => |g| if (c.private) .{ .game = try game(a, c, g) } else .{ .note = .{ .title = "In game", .text = "The board comes back in your next champ select." } },
            .post_game => .post,
        },
        .foot = switch (note) {
            .restart => restart_line,
            .moved => moved_line,
            .none, .downloading, .failed => "",
        },
    };
}

pub const restart_line = "A new version of meiolol is downloaded: it starts the next time you open the app.";
pub const moved_line = "This version of meiolol can no longer update itself: get the new one at meio.lol/download.";

fn mb(bytes: u64) f64 {
    return @as(f64, @floatFromInt(bytes)) / 1e6;
}

/// `s` with its first letter a capital
fn upper(a: Allocator, s: []const u8) ![]const u8 {
    if (s.len == 0) return s;
    const out = try a.dupe(u8, s);
    out[0] = std.ascii.toUpper(out[0]);
    return out;
}

fn select(a: Allocator, c: Ctx, s: *const state.Select) !ui.champselect.Screen {
    const b = &s.board;
    const bans_us = try a.alloc(ui.champ.Champ, b.my_bans.len);
    for (bans_us, b.my_bans) |*x, id| x.* = (try c.champ(a, id)) orelse .{ .name = "", .src = "" };
    const bans_them = try a.alloc(ui.champ.Champ, b.their_bans.len);
    for (bans_them, b.their_bans) |*x, id| x.* = (try c.champ(a, id)) orelse .{ .name = "", .src = "" };
    const ban_options = try a.alloc(ui.champselect.BanOption, b.ban_options.len);
    for (ban_options, b.ban_options) |*x, o| x.* = .{
        .champ = (try c.champ(a, o.champion)).?,
        .role = uiRole(o.role),
        .mine = o.my_lane,
        .why = try banWhy(a, c, o),
        .beats = if (o.beats == 0) null else .{
            .text = try a.print("beats {s} in lane", .{c.stats.?.nameOf(o.beats)}),
            .lean = .good,
            .champ = try c.champ(a, o.beats),
            .fig = if (c.private) try a.print("+{d:.1}", .{o.beats_pp}) else "",
        },
        .act = try c.act(a, .{ .ban = o.champion }),
    };
    return .{
        .board = .{ .lanes = try lanes(a, c, b, if (s.ally) .{ .role = s.card.role, .enemy = s.enemy } else null), .bans_us = bans_us, .bans_them = bans_them },
        .lane = try lane(a, c, &s.card, board.modeOf(&s.card), if (s.enemy) .enemy else if (s.ally) .ally else .mine),
        .ban_options = ban_options,
        .banning = b.turn == .ban,
        .draft = if (c.private) if (b.draft) |d| @floatCast(100 * d.win) else null else null,
    };
}

/// Words for everyone, numbers for testers
fn banWhy(a: Allocator, c: Ctx, o: board.BanOption) ![]const u8 {
    if (c.private) {
        const base = try a.print("{f} won, {f} of games, +{d:.0} wins per 10k", .{ rate(o.win), rate(o.pick_rate), o.impact });
        if (o.beats == 0) return base;
        return a.print("{s}, {d:.0} of them from the matchup", .{ base, o.counter });
    }
    // Mostly the matchup: "wins often" may not hold for it alone
    if (o.beats != 0 and 2 * o.counter >= o.impact)
        return a.print("beats {s} in lane and is picked a lot in {s}", .{ c.stats.?.nameOf(o.beats), o.role.label() });
    return a.print("wins often and is picked a lot in {s}", .{o.role.label()});
}

/// Words for everyone; the share, the mix's record, lean numbers and lane gold for
/// testers
/// The comp view under the page: champ select's once the comp is known, the loading
/// screen's locked one
pub fn compUnder(a: Allocator, c: Ctx, status: state.Status) !?ui.compview.Comp {
    return switch (status) {
        .select => |x| if (x.comp) |cv| try compView(a, c, cv) else null,
        .loading => |l| if (l.comp) |*cv| try lockedComp(a, c, cv) else null,
        else => null,
    };
}

/// The comp view under the loading screen: the island has no room for team pills
/// (ui-app.wasm at its budget), so this static HTML carries the same facts. Picks are
/// locked, so no "win less" and no win rates: they would rate teammates' picks
fn lockedComp(a: Allocator, c: Ctx, x: *const comp.Comp) !ui.compview.Comp {
    var v = try compView(a, c, x);
    // The loading screen's lane strips show the lanes
    v.lanes = &.{};
    for ([_]*ui.compview.Team{ &v.us, &v.them }) |t| if (t.damage) |*d| {
        d.wins_less = false;
        d.rate = null;
    };
    return v;
}

fn pct(x: [core.champfacts.length_buckets]f64) [core.champfacts.length_buckets]f32 {
    var out: [core.champfacts.length_buckets]f32 = undefined;
    for (&out, x) |*o, w| o.* = @floatCast(100 * w);
    return out;
}

pub fn compView(a: Allocator, c: Ctx, x: *const comp.Comp) !ui.compview.Comp {
    var teams: [2]ui.compview.Team = undefined;
    for (&teams, x.teams, 0..) |*out, t, side| {
        // champ-facts.tsv and the stats file ship apart: a champion only the facts know
        // gets no row
        var timing: std.ArrayList(ui.compview.Timing) = .empty;
        for (t.timing) |tm| {
            const champ = (try c.champ(a, tm.champion)) orelse continue;
            if (c.stats.?.index(tm.champion) == null) continue;
            try timing.append(a, .{
                .champ = champ,
                .late = tm.lean == .late,
                .gold = if (c.private) @intFromFloat(tm.gold) else null,
                .win = if (c.private) @floatCast(tm.win) else null,
            });
        }
        out.* = .{ .timing = timing.items, .tips = try comp.tips(a, c.stats.?, x, side) };
        if (t.top) |top| if (try c.champ(a, top.champion)) |champ| {
            out.top = .{ .champ = champ, .share = if (c.private) if (top.share) |sh| @floatCast(100 * sh) else null else null };
        };
        const d = t.damage orelse continue;
        out.damage = .{
            .magic = @floatCast(d.magic),
            .mix = switch (d.mix) {
                .physical => .physical,
                .mixed => .mixed,
                .magic => .magic,
            },
            .wins_less = d.wins_less,
            .share = c.private,
            .rate = if (c.private and d.teams.games > 0) @floatCast(100 * @as(f64, @floatFromInt(d.teams.wins)) / @as(f64, @floatFromInt(d.teams.games))) else null,
            .teams = d.teams.games,
        };
    }
    const rows = try a.alloc(ui.teamrows.Row, x.lanes.len);
    for (rows, x.lanes) |*r, l| {
        const words = comp.lines(try a.alloc(u8, 64), try a.alloc(u8, 64), l);
        r.* = .{
            .role = uiRole(l.role),
            .us = if (l.ours != 0) .{ .champ = try c.champ(a, l.ours), .you = l.me, .line = words[0] } else null,
            .them = if (l.theirs != 0) .{ .champ = try c.champ(a, l.theirs), .line = words[1] } else null,
        };
        const f = l.facts orelse continue;
        const g = f.gold orelse continue;
        if (!c.private) continue;
        r.gap = try a.print("{f}", .{gold(g.mean)});
        r.lean = switch (f.edge().?) {
            .ahead => .good,
            .behind => .bad,
            .even => .none,
        };
    }
    return .{
        .us = teams[0],
        .them = teams[1],
        .lanes = rows,
        .length = if (x.length) |l| .{
            .win = if (c.private) pct(l.win) else null,
            .range = if (c.private) pct(l.range) else null,
            .longer = l.longer,
        } else null,
        .patch = x.patch,
        .gold_minute = core.champfacts.gold_minute,
        .win_minute = core.champfacts.win_minute,
        .lane_minute = core.curvesfile.lane_minute,
    };
}

/// Another seat's lane in the panel
const Shown = struct { role: core.Role, enemy: bool };

/// Whose lane the panel shows
const Side = enum { mine, ally, enemy };

/// A row per role in draft order; a seat without a role takes the first row its side
/// left empty. `shown`: the seat whose lane the panel shows
fn lanes(a: Allocator, c: Ctx, b: *const board.Board, shown: ?Shown) ![]const ui.draftboard.Lane {
    var rows: [5]ui.draftboard.Lane = undefined;
    for (&rows, ui.role.Role.all) |*r, role| r.* = .{ .role = role };
    var filled: [2][5]bool = @splat(@splat(false));
    // My seats in their own role's row: board.allyLane finds an ally by role
    var roled: [5]bool = @splat(false);
    for ([_][]const board.Seat{ b.allies, b.enemies }, 0..) |seats, side| {
        for (seats, 0..) |s, k| if (s.role) |r| {
            const i = @backingInt(r);
            if (filled[side][i]) continue;
            filled[side][i] = true;
            roled[i] = side == 0;
            setSeat(&rows[i], side, try seat(a, c, s, side, k));
        };
        for (seats, 0..) |s, k| if (s.role == null) for (&rows, 0..) |*row, i| if (!filled[side][i]) {
            filled[side][i] = true;
            setSeat(row, side, try seat(a, c, s, side, k));
            break;
        };
    }
    if (shown) |x| {
        const row = &rows[@backingInt(x.role)];
        if (x.enemy) row.them.sel = true else row.us.sel = true;
    }
    // A click on another seat shows their lane, on mine (while another's shows) mine
    // again (bridge.js sends the act); under practice the seats' clicks place champions.
    // An enemy row's lane is its role's: board.enemyLane finds the seat placed there
    if (!c.practice) for (&rows, roled, 0..) |*row, by_role, i| {
        if (row.us.you) {
            if (shown != null) row.us.act = try a.print("lane {d}", .{state.own_lane});
        } else if (by_role and !row.us.sel) row.us.act = try a.print("lane {d}", .{i});
        if (!row.them.sel) row.them.act = try a.print("lane {d}", .{state.enemy_lanes + i});
    };
    return a.dupe(ui.draftboard.Lane, &rows);
}

fn setSeat(row: *ui.draftboard.Lane, side: usize, s: ui.draftboard.Seat) void {
    if (side == 0) row.us = s else row.them = s;
}

/// `k`: the seat's place in its side's list, practice's enemy seat
fn seat(a: Allocator, c: Ctx, s: board.Seat, side: usize, k: usize) !ui.draftboard.Seat {
    const sl = s.slot;
    const ideas = try a.alloc(ui.champ.Champ, s.ideas.len);
    for (ideas, s.ideas) |*x, id| x.* = (try c.champ(a, id)).?;
    // Practice: an ally's seat by role (none without one), its ideas into it
    const ally: ?u8 = if (side == 0) if (s.role) |r| @backingInt(r) else null else null;
    const idea_acts = try a.alloc([]const u8, if (ally != null) s.ideas.len else 0);
    for (idea_acts, s.ideas) |*x, id| x.* = try c.act(a, .{ .fill = .{ ally.?, id } });
    var out: ui.draftboard.Seat = .{
        .champ = try c.champ(a, sl.champion),
        .state = switch (sl.state) {
            .empty => .empty,
            .intent => .intent,
            .hover => .hover,
            .locked => .locked,
        },
        .you = sl.me,
        .picking = sl.picking,
        .guessed = s.guessed,
        .ideas = ideas,
        .act = if (side == 1)
            try c.act(a, .{ .seat = .{ .enemy = @intCast(k) } })
        else if (ally) |r| try c.act(a, .{ .seat = .{ .ally = r } }) else "",
        .idea_acts = idea_acts,
    };
    // Testers only until APP1 checks the client gives enemy bans by seat (the poller
    // clears them in the public edition; the review pages build one board for both)
    if (c.private and sl.champion == 0 and sl.ban != 0) {
        out.ban = try c.champ(a, sl.ban);
        out.fact = "their ban";
    }
    // How the champion does in the role: a number for testers, words for everyone
    if (sl.champion != 0 and s.games > 0) if (s.role) |r| {
        if (c.private) {
            out.fact = try a.print("{f} in {s} · {f} games", .{ rate(s.win), r.label(), count(s.games) });
            out.fig = try a.print("{f}", .{rate(s.win)});
            out.rate = @floatCast(100 * s.win);
            out.lean = if (s.win >= 0.515) .good else if (s.win <= 0.485) .bad else .none;
        } else if (s.win >= 0.515) {
            out.fact = try a.print("strong in {s} now", .{r.label()});
            out.fig = "▲";
            out.lean = .good;
        } else if (s.win <= 0.485) {
            out.fact = try a.print("weak in {s} now", .{r.label()});
            out.fig = "▼";
            out.lean = .bad;
        }
    };
    return out;
}

/// The Options panel (docs/plan/ui/app-options.md): every row in the private edition,
/// in the public one up to lanecard.max_options past the lane panel's own, effects with
/// their sign only (product rules: 3 to 5, no numbers)
pub fn picksOf(a: Allocator, c: Ctx, s: *const state.Select) !?ui.picks.Data {
    const p = s.picks orelse return null;
    var rows: std.ArrayList(ui.picks.Row) = .empty;
    for (p.picks, 0..) |x, i| {
        if (!c.private and x.shown) continue;
        if (!c.private and rows.items.len == lanecard.max_options) break;
        const me = try c.champ(a, x.champion) orelse continue;
        const effects = try a.alloc(ui.picks.Effect, x.reasons.len);
        var named: f64 = 0;
        for (effects, x.reasons) |*e, r| {
            named += r.pp;
            e.* = .{
                .kind = switch (r.kind) {
                    .base => .strength,
                    .ally => .with,
                    .enemy => .into,
                },
                .other = if (r.kind == .base) null else try c.champ(a, r.champion),
                .pp = if (c.private) @floatCast(r.pp) else ui.reasons.sized(@floatCast(r.pp)),
                .games = if (c.private) r.games else 0,
            };
        }
        const pr = try picked(a, c, x.champion, p.role);
        try rows.append(a, .{
            .runes = pr.runes,
            .spells = pr.spells,
            .runes_pct = pr.runes_pct,
            .spells_pct = pr.spells_pct,
            .rune_src = pr.rune_src,
            .spell_srcs = pr.spell_srcs,
            .champ = me,
            .rank = @intCast(i + 1),
            .win = if (c.private) @floatCast(100 * x.win) else null,
            .base = if (c.private) @floatCast(100 * x.win - x.pp) else 50,
            .gold = if (c.private) if (x.gold) |g| @floatCast(g) else null else null,
            .pool = x.pool,
            .current = x.champion == s.card.me,
            .effects = effects,
            .rest = if (c.private) @floatCast(x.pp - named) else 0,
            .act = if (c.practice) try c.act(a, .{ .take = x.champion }) else "",
        });
    }
    if (rows.items.len == 0) return null;
    return .{
        .seq = 0,
        .private = c.private,
        .role = uiRole(p.role),
        .them = if (s.card.opponent) |o| if (c.stats) |st| st.nameOf(o.champion) else "" else "",
        .rows = rows.items,
        // Beside the region chip, the period alone
        .scope = if (s.all_regions != null) s.card.period else try scopeOf(a, c, s.card.period),
        .all_regions = s.all_regions,
    };
}

/// "All regions" once the Options panel's chip chose them, else "EUW"
fn regionOf(s: *const state.Select) []const u8 {
    return if (s.all_regions orelse false) "All regions" else "EUW";
}

/// "EUW, last 30 days"
fn scopeOf(a: Allocator, c: Ctx, period: []const u8) ![]const u8 {
    return if (period.len > 0) a.print("{s}, {s}", .{ c.region, period }) else c.region;
}

const Picked = struct {
    runes: []const u8 = "",
    spells: []const u8 = "",
    runes_pct: ?f32 = null,
    spells_pct: ?f32 = null,
    rune_src: []const u8 = "",
    spell_srcs: [2][]const u8 = .{ "", "" },
};

/// "Electrocute + Sorcery" and "Flash, Ignite", most picked; "" unknown or unnamed
fn picked(a: Allocator, c: Ctx, champion: u32, role: core.Role) !Picked {
    const f = c.facts orelse return .{};
    var out: Picked = .{};
    if (f.runesOf(champion, role)) |r| {
        const key = f.runeName(r.keystone);
        const tree = f.runeName(r.second);
        if (key.len > 0 and tree.len > 0) {
            out.runes = try a.print("{s} + {s}", .{ key, tree });
            out.rune_src = try c.clientArt(a, .perk, r.keystone);
            if (c.private) out.runes_pct = 100 * r.share;
        }
    }
    if (f.spellsOf(champion, role)) |sp| {
        // Flash first, as players say it
        const flash = 4;
        const ids = if (sp.ids[1] == flash) [2]u32{ sp.ids[1], sp.ids[0] } else sp.ids;
        const x = f.spellName(ids[0]);
        const y = f.spellName(ids[1]);
        if (x.len > 0 and y.len > 0) {
            out.spells = try a.print("{s}, {s}", .{ x, y });
            out.spell_srcs = .{ try c.clientArt(a, .spell, ids[0]), try c.clientArt(a, .spell, ids[1]) };
            if (c.private) out.spells_pct = 100 * sp.share;
        }
    }
    return out;
}

/// `ally`: an ally's lane, without my pool or mastery (a null `mastery` tells the panel)
fn lane(a: Allocator, c: Ctx, card: *const lanecard.Card, mode: board.Mode, side: Side) !ui.champselect.Lane {
    const options = try a.alloc(ui.champselect.Option, card.options.len);
    for (options, card.options) |*x, o| {
        const reasons = try a.alloc(ui.champselect.Reason, o.reasons.len);
        for (reasons, o.reasons, 0..) |*r, text, j| {
            r.* = .{
                .text = text,
                .lean = if (j < o.tones.len) switch (o.tones[j]) {
                    .neutral => .none,
                    .good => .good,
                    .bad => .bad,
                } else .none,
            };
            // A champion or the role and its points (testers), the words in the title
            if (j >= o.marks.len) continue;
            const m = o.marks[j];
            switch (m.kind) {
                .mastery => continue,
                .base => r.role = uiRole(card.role),
                .ally, .enemy => r.champ = try c.champ(a, m.champion),
            }
            if (c.private) {
                r.fig = try a.print("{f}", .{pp(m.pp)});
                r.tip = try a.print("{s} · {f} pts", .{ text, pp(m.pp) });
            } else r.tip = try a.print("{s} · {s}", .{ text, ui.reasons.sizeWord(ui.reasons.sized(m.pp)) });
        }
        x.* = .{
            .champ = (try c.champ(a, o.champion)).?,
            .current = o.champion == card.me,
            .win = if (c.private) @floatCast(100 * o.win) else null,
            .lane = if (o.lane) |l| if (l.gold) |g| try a.print("{f} gold at {d}", .{ gold(g), core.curvesfile.lane_minute }) else l.text else "",
            .lean = if (o.lane) |l| switch (l.lean) {
                .ahead => .good,
                .behind => .bad,
                .unclear => .none,
            } else .none,
            .faint = if (o.lane) |l| l.strength < 0.75 else false,
            .reasons = reasons,
            .act = try c.act(a, .{ .take = o.champion }),
        };
    }
    const them = card.opponent;
    const me_champ = try c.champ(a, card.me);
    const them_champ = if (them) |o| try c.champ(a, o.champion) else null;
    const chart: ?ui.lane.Figures = if (card.matchup) |m| if (m.points.len >= 2) blk: {
        const cv = try curve(a, m);
        break :blk .{ .a = if (me_champ) |x| x.name else "You", .b = if (them_champ) |x| x.name else "Them", .band = cv.band, .line = cv.line };
    } else null else null;
    return .{
        .role = uiRole(card.role),
        .me = me_champ,
        .them = them_champ,
        .guessed = if (them) |o| o.guessed else false,
        .mode = switch (mode) {
            .blind => .blind,
            .counter => .counter,
            .locked => .locked,
        },
        .sentence = card.sentence,
        .fig = if (card.matchup) |m| try a.print("{f}", .{gold(m.gold.mean)}) else "",
        .lean = if (card.matchup) |m| if (m.gold.mean > 0) .good else if (m.gold.mean < 0) .bad else .none else .none,
        .thin = if (card.matchup) |m| m.thin else false,
        .chart = chart,
        .caption = if (card.matchup) |m| try a.print("{f} games · {s} · EUW, {s}", .{ count(m.games), m.bracket.label(), card.period }) else "",
        .options = options,
        .mastery = if (side != .mine) null else state.by_mastery.load(.acquire),
        .enemy = side == .enemy,
        .scope = try scopeOf(a, c, card.period),
    };
}

/// The loading screen's cards, static HTML after the island
pub fn loadUnder(a: Allocator, c: Ctx, status: state.Status) !?ui.loadscreen.Screen {
    return switch (status) {
        .loading => |l| try loadScreen(a, c, l),
        else => null,
    };
}

fn loadScreen(a: Allocator, c: Ctx, l: *const loading.Loading) !ui.loadscreen.Screen {
    var rows: std.ArrayList(ui.loadscreen.Lane) = .empty;
    var used: [2][]bool = undefined;
    for (&used, l.teams) |*u, t| u.* = try a.alloc(bool, t.len);
    for (used) |u| @memset(u, false);
    // A lane per role, then seats without one (or a second of a role) paired in order
    for (core.Role.all) |r| {
        var pair: [2]?*const loading.Card = .{ null, null };
        for (&pair, l.teams, used) |*p, t, u| for (t, u) |*x, *seen| {
            if (seen.* or x.role != r) continue;
            seen.* = true;
            p.* = x;
            break;
        };
        if (pair[0] != null or pair[1] != null) try rows.append(a, try loadLane(a, c, pair));
    }
    var rest: [2]std.ArrayList(*const loading.Card) = .{ .empty, .empty };
    for (&rest, l.teams, used) |*o, t, u| for (t, u) |*x, seen| if (!seen) try o.append(a, x);
    for (0..@max(rest[0].items.len, rest[1].items.len)) |i| {
        var pair: [2]?*const loading.Card = .{ null, null };
        for (&pair, rest) |*p, r| if (i < r.items.len) {
            p.* = r.items[i];
        };
        try rows.append(a, try loadLane(a, c, pair));
    }
    return .{
        .lanes = rows.items,
        .draft = if (c.private) if (l.draft) |d| @floatCast(100 * d.win) else null else null,
        .yours = try yourGame(a, c, l, rows.items),
    };
}

fn loadLane(a: Allocator, c: Ctx, pair: [2]?*const loading.Card) !ui.loadscreen.Lane {
    var out: ui.loadscreen.Lane = .{};
    if (pair[0]) |x| out.us = try loadCard(a, c, x, true);
    if (pair[1]) |x| out.them = try loadCard(a, c, x, false);
    const ours = pair[0] orelse return out;
    if (pair[1] == null) return out;
    const f = ours.lane orelse return out;
    const g = f.gold orelse return out;
    const lead: ui.loadscreen.Side = switch (f.edge().?) {
        .ahead => .us,
        .behind => .them,
        .even => .even,
    };
    const side = struct {
        fn of(gap: ?i32) ?ui.loadscreen.Side {
            const w = loading.timingWord(gap) orelse return null;
            return if (w == .sooner) .us else .them;
        }
    }.of;
    const word = switch (lead) {
        .us => "ahead",
        .them => "behind",
        .even => "even",
    };
    var label: std.Io.Writer.Allocating = .init(a);
    const w = &label.writer;
    try w.print("{s} {s} in lane", .{ if (out.us.?.champ) |x| x.name else "Unknown", word });
    if (c.private) try w.print(", {f} gold at {d}", .{ gold(g.mean), core.curvesfile.lane_minute });
    if (side(f.level6)) |x| try w.print(", level 6 {s}", .{if (x == .us) "first" else "later"});
    if (side(f.first_item)) |x| try w.print(", first item {s}", .{if (x == .us) "sooner" else "later"});
    out.strip = .{
        .gold = g.mean,
        .lead = lead,
        .text = if (c.private) try a.print("{f}", .{gold(g.mean)}) else word,
        .level6 = side(f.level6),
        .item = side(f.first_item),
        .label = label.written(),
    };
    return out;
}

fn loadCard(a: Allocator, c: Ctx, card: *const loading.Card, ours: bool) !ui.loadscreen.Card {
    var pills: std.ArrayList(ui.loadscreen.Pill) = .empty;
    for (card.pills) |q| if (loading.shows(q, card.*, ours, c.private)) {
        try pills.append(a, .{ .text = q.text, .tone = loadTone(q.tone) });
    };
    const shown = c.private and card.games > 0;
    var x: ui.loadscreen.Card = .{
        .champ = try c.champ(a, card.champion),
        .role = if (card.role) |r| uiRole(r) else null,
        .guessed = card.guessed,
        .you = card.me,
        .fact = if (shown) try a.print("{f} · {f} games", .{ rate(card.win), count(card.games) }) else "",
        .lean = if (!shown) .none else if (card.win >= 0.515) .good else if (card.win <= 0.485) .bad else .none,
        .pills = pills.items,
    };
    if (card.lengths) |by| {
        x.lengths = try lengthSpark(a, by);
        const d = x.lengths[x.lengths.len - 1] - x.lengths[0];
        x.lengths_label = if (d >= spark_lean) "Wins more in long games" else if (d <= -spark_lean) "Wins more in short games" else "About the same at any length";
    }
    return x;
}

/// Points of win rate between the shortest and longest games that make a lean
const spark_lean = 2;

/// Win % by length about the champion's own average, shrunk to even as the comp's team
/// curve is: when it wins more, not how much. A locked teammate's pick gets no rating
/// on the loading screen (comp.pills)
fn lengthSpark(a: Allocator, by: loading.Lengths) ![]const f32 {
    const out = try a.alloc(f32, by.len);
    var sum: f64 = 0;
    var p: [by.len]f64 = undefined;
    for (&p, by) |*x, b| {
        x.* = (@as(f64, @floatFromInt(b.wins)) + comp.length_k / 2.0) / (@as(f64, @floatFromInt(b.games)) + comp.length_k);
        sum += x.*;
    }
    const mean = sum / @as(f64, @floatFromInt(by.len));
    for (out, p) |*o, x| o.* = @floatCast(50 + 100 * (x - mean));
    return out;
}

fn loadTone(t: loading.Tone) ui.loadscreen.Tone {
    return switch (t) {
        .neutral => .none,
        .good => .good,
        .bad => .bad,
        .caution => .caution,
    };
}

/// My lane, the enemy jungler's lean and the enemy team's, in the words their pills use
fn yourGame(a: Allocator, c: Ctx, l: *const loading.Loading, shown: []const ui.loadscreen.Lane) ![]const ui.loadscreen.Fact {
    var out: std.ArrayList(ui.loadscreen.Fact) = .empty;
    for (shown) |ln| {
        const me = ln.us orelse continue;
        if (!me.you) continue;
        const s = ln.strip orelse break;
        try out.append(a, .{
            .champ = me.champ,
            .text = if (c.private) try a.print("{s} gold at {d}", .{ s.text, core.curvesfile.lane_minute }) else switch (s.lead) {
                .us => "lane bully",
                .them => "tough lane",
                .even => "even lane",
            },
            .tone = switch (s.lead) {
                .us => .good,
                .them => .bad,
                .even => .none,
            },
        });
        break;
    }
    const cv = l.comp orelse return out.items;
    for (cv.teams[1].timing) |tm| if (tm.role == .jungle) {
        if (try c.champ(a, tm.champion)) |x| try out.append(a, .{ .champ = x, .text = if (tm.lean == .early) "early game" else "scales" });
        break;
    };
    if (comp.timingOf(cv.teams[1])) |w| try out.append(a, .{ .who = "Enemy team", .text = switch (w) {
        .early => "early team",
        .late => "late team",
        .both => "early and late",
    } });
    return out.items;
}

/// The private edition's build panel in game: ingame.Plan with icons and names, the
/// tips and the spike sheet
pub fn gameBuild(a: Allocator, c: Ctx, status: state.Status) !?ui.gamebuild.Build {
    if (!c.private) return null;
    const g = switch (status) {
        .in_game => |g| g,
        else => return null,
    };
    var out: ui.gamebuild.Build = .{ .tips = g.tips };
    if (g.spikes) |sp| {
        const lean = struct {
            fn of(l: core.champfacts.Lean) ui.gamebuild.Lean {
                return switch (l) {
                    .early => .early,
                    .late => .late,
                    .none => .none,
                };
            }
        }.of;
        out.spikes = .{
            .opponent = if (c.stats) |st| st.nameOf(sp.opponent) else "",
            .level6 = spikeTiming(sp.level6),
            .first_item = spikeTiming(sp.first_item),
            .games = sp.games,
            .lean = .{ lean(sp.lean[0]), lean(sp.lean[1]) },
        };
    }
    if (g.plan) |p| {
        const items = try a.alloc(ui.gamebuild.Item, p.items.len);
        for (items, p.items) |*x, it| x.* = .{
            .art = .{ .name = if (c.facts) |f| f.itemName(it.id) else "", .src = try c.item(a, it.id) },
            .owned = it.owned,
        };
        out.items = items;
        out.next = if (p.nextItem()) |i| @intCast(i) else null;
        out.order = p.order;
        out.path = p.path;
        out.skill = p.next;
        out.unspent = p.unspent;
        out.games = p.games;
    }
    if (g.plan == null and out.tips.len == 0 and out.spikes == null) return null;
    return out;
}

fn spikeTiming(at: [2]u16) ui.gamebuild.Timing {
    if (at[0] == 0 or at[1] == 0) return .{};
    const word = loading.timingWord(@as(i32, at[0]) - at[1]);
    return .{ .at = at, .sooner = if (word) |w| if (w == .sooner) 0 else 1 else null };
}

fn game(a: Allocator, c: Ctx, g: *const ingame.InGame) !ui.gamescreen.Screen {
    const us = g.score[0];
    const them = g.score[1];
    const lines = [_]struct { []const u8, u32, u32 }{
        .{ "Kills", us.kills, them.kills },
        .{ "Towers", us.towers, them.towers },
        .{ "Dragons", us.dragons + us.elders, them.dragons + them.elders },
        .{ "Grubs", us.grubs, them.grubs },
        .{ "Heralds", us.heralds, them.heralds },
        .{ "Barons", us.barons, them.barons },
        .{ "Inhibitors", us.inhibitors, them.inhibitors },
    };
    var score: std.ArrayList(ui.gamescreen.Score) = .empty;
    for (lines, 0..) |l, i| {
        // Objectives nobody has taken yet only add noise
        if (i > 1 and l[1] == 0 and l[2] == 0) continue;
        try score.append(a, .{ .what = l[0], .us = @intCast(@min(l[1], 999)), .them = @intCast(@min(l[2], 999)) });
    }
    const diff = @as(i64, us.item_gold) - them.item_gold;
    const now = g.sample();
    const timers = try a.alloc(ui.gamescreen.Timer, g.timers.len);
    for (timers, g.timers) |*x, t| x.* = .{
        .what = t.what,
        .at = ingame.clock(try a.alloc(u8, 16), t.back),
        .in = ingame.clock(try a.alloc(u8, 16), t.back - g.time),
    };
    var rows: [5]ui.teamrows.Row = undefined;
    for (&rows, g.rows) |*x, r| {
        var seats: [2]?ui.teamrows.Seat = .{ null, null };
        for (&seats, [_]?ingame.Seat{ r.ours, r.theirs }) |*out, seat_or| {
            const s = seat_or orelse continue;
            out.* = .{
                .champ = try c.champ(a, s.champion),
                .you = s.me,
                .dead = if (s.dead) @intFromFloat(@min(999, @ceil(@max(0, s.respawn)))) else null,
                .kda = kda(s.kills, s.deaths, s.assists),
                .line = try a.print("Lv {d} · {d} cs", .{ s.level, s.cs }),
            };
        }
        x.* = try teamRow(a, r.role, seats, r.goldDiff());
    }
    return .{
        .score = score.items,
        .gold = .{
            .us = try a.print("{f}", .{count(us.item_gold)}),
            .them = try a.print("{f}", .{count(them.item_gold)}),
            .gap = try a.print("{f} item gold", .{gold(diff)}),
            .lean = if (diff > 0) .good else if (diff < 0) .bad else .none,
            .share = @floatCast(@as(f64, @floatFromInt(us.item_gold)) / @as(f64, @floatFromInt(@max(1, us.item_gold + them.item_gold)))),
        },
        .rows = try a.dupe(ui.teamrows.Row, &rows),
        .lane = if (g.lane) |l| try gameLane(a, c, g, l, now) else null,
        .lane_note = g.lane_note,
        .timers = timers,
        .team = try perMinute(a, g.history, now, .team),
    };
}

fn gameLane(a: Allocator, c: Ctx, g: *const ingame.InGame, l: ingame.Lane, now: ingame.Sample) !ui.gamescreen.Lane {
    var compare: std.ArrayList(ui.gamescreen.Compare) = .empty;
    if (l.minute) |m| for ([_]struct { []const u8, ?ingame.Compare }{ .{ "CS", l.cs }, .{ "Item gold", l.gold } }) |x| {
        const cmp = x[1] orelse continue;
        const t = cmp.typical;
        try compare.append(a, .{
            .what = x[0],
            .now = try a.print("{f}", .{signed(cmp.now)}),
            .lean = switch (cmp.standing) {
                .far_behind, .behind => .bad,
                .typical => .none,
                .ahead, .far_ahead => .good,
            },
            .text = try a.print("{s} at {d} min (middle half {f} to {f})", .{ cmp.standing.words(), m, signed(t.p25), signed(t.p75) }),
        });
    };
    const mu = l.matchup;
    const cv = try curve(a, mu);
    const me = try c.champ(a, l.me);
    const them = try c.champ(a, l.opponent);
    return .{
        .me = me,
        .them = them,
        .compare = compare.items,
        .note = if (l.minute == null) try a.print("The lane curve covers minutes 1 to {d}.", .{mu.points.len}) else "",
        .chart = .{
            .a = if (me) |x| x.name else "You",
            .b = if (them) |x| x.name else "Them",
            .you = try perMinute(a, g.history, now, .lane),
            .band = cv.band,
            .line = cv.line,
        },
        .caption = try a.print("Item gold, you minus them: the band is the middle half of {d} games ({s}, EUW, {s}), the line their average; yours from items.", .{ mu.games, mu.bracket.label(), g.period }),
    };
}

/// The matchup's gold by minute as a chart's band (middle half) and line (average). The
/// points start at minute 1; index i is minute i, both 0 at the start
fn curve(a: Allocator, mu: lanecard.Matchup) !struct { band: [][2]f32, line: []f32 } {
    var n: usize = 0;
    for (mu.points) |p| n = @max(n, @as(usize, p.minute) + 1);
    const band = try a.alloc([2]f32, n);
    const line = try a.alloc(f32, n);
    @memset(band, .{ 0, 0 });
    @memset(line, 0);
    for (mu.points) |p| {
        band[p.minute] = .{ @floatFromInt(p.p25), @floatFromInt(p.p75) };
        line[p.minute] = @floatFromInt(p.mean);
    }
    return .{ .band = band, .line = line };
}

/// The post game, static HTML after the island
pub fn postUnder(a: Allocator, c: Ctx, status: state.Status) !?ui.postgame.Screen {
    return switch (status) {
        .post_game => |p| try post(a, c, p),
        else => null,
    };
}

fn post(a: Allocator, c: Ctx, p: *const postgame.PostGame) !ui.postgame.Screen {
    const awards = try a.alloc(ui.postgame.Award, p.awards.len);
    for (awards, p.awards) |*x, w| {
        const figures = try a.alloc([]const u8, w.figures.len);
        for (figures, w.figures) |*out, f| out.* = switch (f.kind) {
            .damage => try a.print("{f} dmg", .{count(@intFromFloat(f.value))}),
            .kda => try a.print("{d:.1} KDA", .{f.value}),
            .gold => try a.print("{f} gold", .{count(@intFromFloat(f.value))}),
            .cs => try a.print("{d} cs", .{@as(u32, @intFromFloat(f.value))}),
            .vision => try a.print("{d} vision", .{@as(u32, @intFromFloat(f.value))}),
        };
        x.* = .{ .champ = try c.champ(a, w.champion), .side = if (w.ours) .us else .them, .figures = figures };
    }
    var rows: [5]ui.teamrows.Row = undefined;
    for (&rows, p.rows) |*x, r| {
        var seats: [2]?ui.teamrows.Seat = .{ null, null };
        for (&seats, [_]?postgame.Seat{ r.ours, r.theirs }) |*out, seat_or| {
            const s = seat_or orelse continue;
            out.* = .{
                .champ = try c.champ(a, s.champion),
                .you = s.me,
                .kda = kda(s.kills, s.deaths, s.assists),
                .line = if (p.pending) try a.print("Lv {d} · {d} cs", .{ s.level, s.cs }) else try a.print("{d} cs · {f} dmg", .{ s.cs, count(s.damage) }),
            };
        }
        // Pending gold is item gold, not gold earned: it would jump when the result lands
        x.* = try teamRow(a, r.role, seats, if (p.pending) null else r.goldDiff());
    }
    // Damage comes with the end of game block
    var damage: [2]ui.postgame.Team = .{ .{}, .{} };
    if (!p.pending) for (&damage, [_]bool{ true, false }) |*team, ours| {
        var players: std.ArrayList(ui.postgame.Damage) = .empty;
        var total: u32 = 0;
        for (p.rows) |r| {
            const s = (if (ours) r.ours else r.theirs) orelse continue;
            total +|= s.damage;
            try players.append(a, .{
                .champ = try c.champ(a, s.champion),
                .you = s.me,
                .value = s.damage,
                .text = try a.print("{f}", .{count(s.damage)}),
            });
        }
        team.* = .{ .total = try a.print("{f}", .{count(total)}), .players = players.items };
    };
    return .{
        .win = p.win,
        .coming = p.pending,
        .verdict = p.verdict,
        .kills = .{ @intCast(@min(p.kills[0], 9999)), @intCast(@min(p.kills[1], 9999)) },
        .awards = awards,
        .rows = try a.dupe(ui.teamrows.Row, &rows),
        .damage = damage,
    };
}

/// Our seat and theirs with the gold gap between, quiet under 300
fn teamRow(a: Allocator, role: core.Role, seats: [2]?ui.teamrows.Seat, diff: ?i64) !ui.teamrows.Row {
    return .{
        .role = uiRole(role),
        .us = seats[0],
        .them = seats[1],
        .gap = if (diff) |d| try a.print("{f}", .{gold(d)}) else "",
        .lean = if (diff) |d| if (@abs(d) < 300) .none else if (d > 0) .good else .bad else .none,
    };
}

fn kda(k: u32, d: u32, as: u32) ui.kda.Kda {
    return .{ .k = @intCast(@min(k, 999)), .d = @intCast(@min(d, 999)), .a = @intCast(@min(as, 999)) };
}

/// The game so far by minute (index i is minute i) up to `now`: the last sample at or
/// before each minute, `now` for the last
fn perMinute(a: Allocator, history: []const ingame.Sample, now: ingame.Sample, comptime what: enum { team, lane }) ![]const f32 {
    const n: usize = @intFromFloat(@max(0, now.time) / 60);
    if (n < 1) return &.{};
    const out = try a.alloc(f32, n + 1);
    var i: usize = 0;
    var last: f32 = 0;
    for (out, 0..) |*v, m| {
        while (i < history.len and history[i].time <= @as(f32, @floatFromInt(m * 60))) : (i += 1) last = value(history[i], what) orelse last;
        v.* = if (m == 0) 0 else last;
    }
    out[n] = value(now, what) orelse last;
    return out;
}

fn value(s: ingame.Sample, comptime what: anytype) ?f32 {
    return switch (what) {
        .team => @floatFromInt(s.team),
        .lane => if (s.lane) |l| @floatFromInt(l) else null,
    };
}

fn uiRole(r: core.Role) ui.role.Role {
    return @fromBackingInt(@as(u3, @backingInt(r)));
}

const Num = struct {
    v: f64,
    kind: enum { rate, count },

    pub fn format(n: Num, w: *std.Io.Writer) std.Io.Writer.Error!void {
        switch (n.kind) {
            .rate => try ui.fmt.write(w, .rate, 100 * n.v),
            // 950, 9.4k, 26k: a seat's line is narrow
            .count => if (n.v < 1000)
                try w.print("{d}", .{n.v})
            else if (n.v < 10_000)
                try w.print("{d:.1}k", .{n.v / 1000})
            else
                try w.print("{d:.0}k", .{n.v / 1000}),
        }
    }
};

/// "+1.2k", "−800", "even": a gold gap
const Gold = struct {
    n: i64,

    pub fn format(g: Gold, w: *std.Io.Writer) std.Io.Writer.Error!void {
        if (g.n == 0) return w.writeAll("even");
        try w.writeAll(if (g.n > 0) "+" else "\u{2212}");
        try count(@intCast(@min(@abs(g.n), std.math.maxInt(u32)))).format(w);
    }
};

fn gold(n: i64) Gold {
    return .{ .n = n };
}

/// "+8", "−420"
const Signed = struct {
    n: i64,

    pub fn format(s: Signed, w: *std.Io.Writer) std.Io.Writer.Error!void {
        try ui.fmt.write(w, .signed, s.n);
    }
};

fn signed(n: i64) Signed {
    return .{ .n = n };
}

/// Win chance points, one decimal: "+1.4", "−0.8"
const Points = struct {
    v: f32,

    pub fn format(p: Points, w: *std.Io.Writer) std.Io.Writer.Error!void {
        try w.writeAll(if (p.v < 0) "\u{2212}" else "+");
        try w.print("{d:.1}", .{@abs(p.v)});
    }
};

fn pp(v: f32) Points {
    return .{ .v = v };
}

fn rate(v: f64) Num {
    return .{ .v = v, .kind = .rate };
}

fn count(n: u32) Num {
    return .{ .v = @floatFromInt(n), .kind = .count };
}

const testing = std.testing;

const ahri = 103;
const syndra = 134;
const galio = 3;

pub const Fixture = struct {
    bytes: []u8,
    stats: core.Stats,

    pub fn deinit(f: *Fixture) void {
        f.stats.deinit(testing.allocator);
        testing.allocator.free(f.bytes);
    }
};

/// Three champions, Ahri and Syndra with mid games (practice.zig's tests too)
pub fn fixture() !Fixture {
    const gpa = testing.allocator;
    var sb: core.statsfile.Builder = try .init(gpa, &.{
        .{ .id = ahri, .name = "Ahri" }, .{ .id = syndra, .name = "Syndra" }, .{ .id = galio, .name = "Galio" },
    });
    defer sb.deinit();
    for (0..40) |i| sb.addGame(.{ .{ 0, 0, ahri, 0, 0 }, .{ 0, 0, syndra, 0, 0 } }, @intCast(i % 2));
    var aw: std.Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();
    try sb.write(&aw.writer, "test");
    const bytes = try aw.toOwnedSlice();
    errdefer gpa.free(bytes);
    return .{ .bytes = bytes, .stats = try .parse(gpa, bytes) };
}

fn testSelect() state.Select {
    const S = struct {
        const options = [_]lanecard.Option{
            .{ .champion = ahri, .mastery = 0, .win = 0.521, .lane = .{ .text = "-150 gold at 14 min vs Syndra", .lean = .behind }, .reasons = &.{"your most played"} },
            .{ .champion = galio, .mastery = 0, .win = 0.54, .lane = null, .reasons = &.{ "120k mastery", "strong in mid now" }, .tones = &.{ .neutral, .good }, .marks = &.{ .{ .kind = .mastery }, .{ .kind = .base, .pp = 1.4 } } },
        };
        const allies = [_]board.Seat{.{ .slot = .{ .champion = ahri, .role = .middle, .state = .hover, .me = true }, .role = .middle, .guessed = false, .games = 25_551, .win = 0.55 }};
        const enemies = [_]board.Seat{
            .{ .slot = .{ .champion = syndra, .state = .locked }, .role = null, .guessed = true, .games = 20, .win = 0.45 },
            .{ .slot = .{ .ban = galio }, .role = null, .guessed = false },
        };
        const points = [_]lanecard.Point{ .{ .minute = 1, .mean = -10, .p25 = -60, .p75 = 40 }, .{ .minute = 2, .mean = -20, .p25 = -100, .p75 = 70 } };
        const ban_options = [_]board.BanOption{
            .{ .champion = galio, .role = .middle, .impact = 31, .pick_rate = 0.08, .win = 0.53, .my_lane = true },
            .{ .champion = syndra, .role = .middle, .impact = 20, .pick_rate = 0.05, .win = 0.5, .my_lane = true, .beats = ahri, .counter = 12, .beats_pp = 2.4 },
        };
    };
    return .{
        .card = .{
            .role = .middle,
            .me = ahri,
            .locked = false,
            .opponent = .{ .champion = syndra, .guessed = true },
            .matchup = .{ .bracket = .all, .games = 1204, .gold = .{}, .range = .{ -900, 700 }, .lane_games = 1204, .ahead = 500, .thin = false, .points = &S.points },
            .sentence = "Ahri usually trails Syndra.",
            .options = &S.options,
            .period = "last 30 days",
        },
        .board = .{
            .allies = &S.allies,
            .enemies = &S.enemies,
            .my_bans = &.{},
            .their_bans = &.{galio},
            .turn = .ban,
            .stage = "Bans",
            .mode = .{ .counter = .{ .champion = syndra, .guessed = true } },
            .ban_options = &S.ban_options,
            .draft = .{ .win = 0.534, .se = 0.1, .picks = .{ 1, 1 }, .hovers = 1 },
        },
    };
}

test "champ select: the private edition's numbers, the public one's words" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var f = try fixture();
    defer f.deinit();
    const stats = &f.stats;
    const sel = testSelect();

    const priv = try data(a, .{ .stats = stats, .icons = null, .private = true }, .{ .select = &sel }, .none);
    try testing.expectEqualStrings("Champ select · Bans", priv.where);
    const ps = priv.screen.select;
    try testing.expectApproxEqAbs(@as(f32, 53.4), ps.draft.?, 0.01);
    try testing.expect(ps.banning);
    try testing.expectEqualStrings("53.0% won, 8.0% of games, +31 wins per 10k", ps.ban_options[0].why);
    try testing.expectEqual(null, ps.ban_options[0].beats);
    // Syndra beats my Ahri: her chip with its points, most of her impact the matchup
    try testing.expectEqualStrings("50.0% won, 5.0% of games, +20 wins per 10k, 12 of them from the matchup", ps.ban_options[1].why);
    try testing.expectEqualStrings("Ahri", ps.ban_options[1].beats.?.champ.?.name);
    try testing.expectEqualStrings("+2.4", ps.ban_options[1].beats.?.fig);
    try testing.expectEqualStrings("55.0% in mid · 26k games", ps.board.lanes[2].us.fact);
    try testing.expectEqualStrings("55.0%", ps.board.lanes[2].us.fig);
    // Syndra has no role: she takes the first empty enemy row
    try testing.expectEqualStrings("Syndra", ps.board.lanes[0].them.champ.?.name);
    // The next enemy yet to pick shows their ban, testers only
    try testing.expectEqualStrings("Galio", ps.board.lanes[1].them.ban.?.name);
    try testing.expectEqualStrings("their ban", ps.board.lanes[1].them.fact);
    try testing.expect(ps.board.lanes[2].us.you);
    try testing.expect(ps.lane.options[0].current and ps.lane.options[0].lean == .bad);
    try testing.expectEqual(.good, ps.lane.options[1].reasons[1].lean);
    try testing.expectEqualStrings("EUW, last 30 days", ps.lane.scope);
    try testing.expectEqualStrings("", ps.lane.me.?.src);
    try testing.expectEqualSlices([2]f32, &.{ .{ 0, 0 }, .{ -60, 40 }, .{ -100, 70 } }, ps.lane.chart.?.band);
    try testing.expectEqualStrings("Syndra", ps.lane.chart.?.b);
    try testing.expectEqualStrings("1.2k games · All games · EUW, last 30 days", ps.lane.caption);
    try testing.expect(ps.lane.fig.len > 0);
    // Strong in the role as the role and its points
    try testing.expectEqual(.mid, ps.lane.options[1].reasons[1].role.?);
    try testing.expectEqualStrings("+1.4", ps.lane.options[1].reasons[1].fig);
    try testing.expectEqual(null, ps.lane.options[1].reasons[0].role);

    var d = try data(a, .{ .stats = stats, .icons = null, .private = false }, .{ .select = &sel }, .none);
    const s = d.screen.select;
    try testing.expectEqual(null, s.draft);
    try testing.expectEqual(null, s.lane.options[0].win);
    try testing.expectEqualStrings("wins often and is picked a lot in mid", s.ban_options[0].why);
    try testing.expectEqualStrings("beats Ahri in lane and is picked a lot in mid", s.ban_options[1].why);
    try testing.expectEqualStrings("", s.ban_options[1].beats.?.fig);
    try testing.expectEqualStrings("strong in mid now", s.board.lanes[2].us.fact);
    try testing.expectEqualStrings("▲", s.board.lanes[2].us.fig);
    try testing.expectEqual(null, s.board.lanes[1].them.ban);
    // Public: no points, an arrow by the lean
    try testing.expectEqualStrings("", s.lane.options[1].reasons[1].fig);
    d.seq = 7;
    const html = try render(a, d, null, null);
    try testing.expect(std.mem.find(u8, html, "data-seq=\"7\"") != null);
    try testing.expect(std.mem.find(u8, html, "ui-app.wasm") != null);
    try testing.expect(std.mem.find(u8, html, "%") == null);

    var bin: std.ArrayList(u8) = .empty;
    try ui.data.encode(a, app.Data, d, &bin);
    const back = try ui.data.decode(a, app.Data, bin.items);
    try testing.expectEqualStrings("Syndra", back.screen.select.lane.them.?.name);
}

test "an ally's lane: their seat marked, no mastery toggle, their name on the chart" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var f = try fixture();
    defer f.deinit();
    var sel = testSelect();
    sel.ally = true;
    sel.card.role = .top;
    sel.card.me = galio;
    const allies = [_]board.Seat{
        sel.board.allies[0],
        .{ .slot = .{ .champion = galio, .role = .top, .state = .locked }, .role = .top, .guessed = false, .games = 900, .win = 0.5 },
        .{ .slot = .{ .champion = syndra, .role = .jungle, .state = .locked }, .role = .jungle, .guessed = false, .games = 9, .win = 0.5 },
    };
    sel.board.allies = &allies;
    const s = (try data(a, .{ .stats = &f.stats, .icons = null, .private = false }, .{ .select = &sel }, .none)).screen.select;
    try testing.expectEqual(null, s.lane.mastery);
    try testing.expect(s.board.lanes[0].us.sel and !s.board.lanes[2].us.sel);
    // Seats send their lane (bridge.js): the shown one none, mine back to mine, an
    // empty row none
    try testing.expectEqualStrings("", s.board.lanes[0].us.act);
    try testing.expectEqualStrings("lane 1", s.board.lanes[1].us.act);
    try testing.expectEqualStrings("lane 255", s.board.lanes[2].us.act);
    try testing.expectEqualStrings("", s.board.lanes[3].us.act);
    const html = try render(a, try data(a, .{ .stats = &f.stats, .icons = null, .private = false }, .{ .select = &sel }, .none), null, null);
    try testing.expect(std.mem.find(u8, html, "data-act=\"lane 1\"") != null);
    try testing.expect(std.mem.find(u8, html, "Your lane</button>") != null);
    try testing.expectEqualStrings("Galio", s.lane.chart.?.a);
    // The board's mode is still mine; the panel's is the card's
    try testing.expectEqual(.counter, s.lane.mode);
    // Still to lock: options as for my lane
    try testing.expect(std.mem.find(u8, html, "Options into them") != null);
    try testing.expect(std.mem.find(u8, html, "<ol class=\"opts\"") != null);
}

test "an ally's lane: once they lock the matchup only, nothing rates their pick" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var f = try fixture();
    defer f.deinit();
    var sel = testSelect();
    sel.ally = true;
    sel.card.role = .top;
    sel.card.me = galio;
    sel.card.locked = true;
    // As lanecard builds it for a locked ally
    sel.card.options = &.{};
    sel.card.sentence = "Galio usually trails Syndra.";
    const allies = [_]board.Seat{
        sel.board.allies[0],
        .{ .slot = .{ .champion = galio, .role = .top, .state = .locked }, .role = .top, .guessed = false, .games = 900, .win = 0.5 },
    };
    sel.board.allies = &allies;
    // Their list is an <ol class="opts"> too
    sel.board.ban_options = &.{};
    for ([_]bool{ false, true }) |private| {
        const c: Ctx = .{ .stats = &f.stats, .icons = null, .private = private };
        const s = (try data(a, c, .{ .select = &sel }, .none)).screen.select;
        try testing.expectEqual(.locked, s.lane.mode);
        try testing.expectEqual(0, s.lane.options.len);
        const html = try render(a, try data(a, c, .{ .select = &sel }, .none), null, null);
        try testing.expect(std.mem.find(u8, html, "Galio usually trails Syndra.") != null);
        try testing.expect(std.mem.find(u8, html, "Your lane</button>") != null);
        for ([_][]const u8{ "Other options", "<ol class=\"opts\"", "enough games", "team win" }) |no|
            try testing.expect(std.mem.find(u8, html, no) == null);
    }
    // Still to pick, nothing with enough games: not "you can pick"
    sel.card.locked = false;
    sel.card.me = 0;
    const html = try render(a, try data(a, .{ .stats = &f.stats, .icons = null, .private = false }, .{ .select = &sel }, .none), null, null);
    try testing.expect(std.mem.find(u8, html, "No champion has enough games in this role.") != null);
}

test "role-less seats: no lane click (an ally's lane is found by role)" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var f = try fixture();
    defer f.deinit();
    var sel = testSelect();
    const allies = [_]board.Seat{
        .{ .slot = .{ .champion = ahri, .state = .hover, .me = true }, .role = null, .guessed = false, .games = 0, .win = 0.5 },
        .{ .slot = .{ .champion = galio, .state = .locked }, .role = null, .guessed = false, .games = 0, .win = 0.5 },
    };
    sel.board.allies = &allies;
    const s = (try data(a, .{ .stats = &f.stats, .icons = null, .private = false }, .{ .select = &sel }, .none)).screen.select;
    for (s.board.lanes) |row| try testing.expectEqualStrings("", row.us.act);
    try testing.expect(s.board.lanes[1].us.champ != null);
}

test "comp view: once all ten are locked, words for everyone and numbers for testers" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var f = try fixture();
    defer f.deinit();
    var sel = testSelect();
    var rows: [5]comp.Lane = undefined;
    for (&rows, core.Role.all) |*l, r| l.* = .{ .role = r, .ours = 0, .theirs = 0, .me = false, .facts = null };
    rows[2] = .{ .role = .middle, .ours = ahri, .theirs = syndra, .me = true, .facts = .{ .games = 900, .gold = .{ .mean = -420, .se = 100 }, .level6 = 40, .first_item = null } };
    const c: comp.Comp = .{
        .teams = .{
            .{
                .damage = .{ .magic = 0.81, .mix = .magic, .teams = .{ .games = 6_000, .wins = 2_850 }, .wins_less = true },
                .timing = &.{
                    .{ .champion = ahri, .role = .middle, .lean = .late, .gold = -394, .win = 3.1 },
                    // Newer than the stats file: no row
                    .{ .champion = 999_999, .role = .top, .lean = .early, .gold = 300, .win = -2 },
                },
            },
            .{ .damage = null, .timing = &.{} },
        },
        .lanes = rows,
        .patch = "15.21",
    };
    sel.comp = &c;

    const priv = try compView(a, .{ .stats = &f.stats, .icons = null, .private = true }, sel.comp.?);
    try testing.expectApproxEqAbs(@as(f32, 47.5), priv.us.damage.?.rate.?, 0.01);
    try testing.expectEqual(-394, priv.us.timing[0].gold.?);
    try testing.expectEqual(1, priv.us.timing.len);
    const mid = priv.lanes[2];
    try testing.expectEqualStrings("behind in lane, level 6 later", mid.us.?.line);
    try testing.expectEqualStrings("ahead in lane, level 6 sooner", mid.them.?.line);
    try testing.expectEqualStrings("\u{2212}420", mid.gap);
    try testing.expectEqual(.bad, mid.lean);
    try testing.expectEqual(null, priv.lanes[0].us);

    // Under the loading screen picks are locked: no "win less", no win rate
    const locked = try lockedComp(a, .{ .stats = &f.stats, .icons = null, .private = true }, sel.comp.?);
    try testing.expect(!locked.us.damage.?.wins_less and locked.us.damage.?.rate == null);
    try testing.expectEqual(.magic, locked.us.damage.?.mix);

    const public = try compView(a, .{ .stats = &f.stats, .icons = null, .private = false }, sel.comp.?);
    try testing.expect(!public.us.damage.?.share and public.us.damage.?.rate == null and public.us.damage.?.wins_less);
    try testing.expectEqual(null, public.us.timing[0].win);
    try testing.expectEqualStrings("", public.lanes[2].gap);
    const d = try data(a, .{ .stats = &f.stats, .icons = null, .private = false }, .{ .select = &sel }, .none);
    const html = try render(a, d, null, public);
    // Static, after the app's island: not inside what ui-app.wasm adopts
    try testing.expect(std.mem.find(u8, html, "data-island=\"app\"").? < std.mem.find(u8, html, "class=\"c-comp\"").?);
    try testing.expect(std.mem.find(u8, try render(a, d, null, null), "c-comp") == null);
    try testing.expect(std.mem.find(u8, html, "Mostly magic damage") != null);
    const late = std.mem.find(u8, html, "<span>Late</span>").?;
    try testing.expect(std.mem.findPos(u8, html, late, "title=\"Ahri\"") != null);
    try testing.expect(std.mem.find(u8, html, "%") == null);
}

test "practice: the board's clicks while it shows, its island and file above the app" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var f = try fixture();
    defer f.deinit();
    const sel = testSelect();
    const c: Ctx = .{ .stats = &f.stats, .icons = null, .private = true, .practice = true };
    var d = try data(a, c, .{ .select = &sel }, .none);
    const s = d.screen.select;
    try testing.expectEqualStrings("seat ally 2", s.board.lanes[2].us.act);
    try testing.expectEqualStrings("seat enemy 0", s.board.lanes[0].them.act);
    try testing.expectEqualStrings("", s.board.lanes[1].us.act);
    try testing.expectEqualStrings("take 103", s.lane.options[0].act);
    try testing.expectEqualStrings("ban 3", s.ban_options[0].act);
    const off = try data(a, .{ .stats = &f.stats, .icons = null, .private = true }, .{ .select = &sel }, .none);
    try testing.expectEqualStrings("", off.screen.select.board.lanes[2].us.act);

    d.practice = true;
    d.seq = 4;
    const bar = try practice.data(a, c, .{}, true);
    const html = try render(a, d, bar, null);
    const top = std.mem.find(u8, html, "data-island=\"practice\"").?;
    try testing.expect(top < std.mem.find(u8, html, "data-island=\"app\"").?);
    try testing.expect(std.mem.find(u8, html, "data-act=\"seat enemy 0\"") != null);
    try testing.expect(std.mem.find(u8, html, "src=\"ui-practice.js\"") != null);
    try testing.expect(std.mem.find(u8, try render(a, d, null, null), "ui-practice") == null);
}

test "notes while there is no board" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const c: Ctx = .{ .stats = null, .icons = null, .private = false };
    try testing.expectEqualStrings("Lobby", (try data(a, c, .{ .waiting = "Lobby" }, .none)).where);
    const e = try data(a, c, .{ .client_error = "ConnectionRefused" }, .none);
    try testing.expectEqualStrings("ConnectionRefused; retrying.", e.screen.note.text);
    const f = try data(a, c, .no_data, .{ .failed = .{ .why = "no connection to meio.lol", .minutes = 20 } });
    try testing.expectEqualStrings("No connection to meio.lol; trying again in 20 minutes.", f.screen.note.text);
    try testing.expect(f.screen.note.step == .download and f.screen.note.failed);
    try testing.expect((try data(a, c, .no_client, .none)).screen.note.step == .open_league);
    const d = (try data(a, c, .no_data, .{ .downloading = .{ .done = 12_400_000, .total = 38_100_000 } })).screen.note;
    try testing.expectEqualStrings("12.4 / 38.1 MB", d.text);
    try testing.expectEqual(32, d.bar);
    try testing.expectEqual(0, (try data(a, c, .no_data, .{ .downloading = .{} })).screen.note.bar);
    var g = try data(a, c, .no_data, .none);
    withSignIn(&g, .{ .full = true });
    try testing.expect(g.screen.note.step == .sign_in);
    try testing.expectEqualStrings(restart_line, (try data(a, c, .{ .waiting = "Lobby" }, .restart)).foot);
    try testing.expectEqualStrings(moved_line, (try data(a, c, .{ .waiting = "Lobby" }, .moved)).foot);
    try testing.expectEqualStrings(moved_line, (try data(a, c, .no_data, .moved)).foot);
    try testing.expectEqualStrings("", (try data(a, c, .{ .waiting = "Lobby" }, .none)).foot);
}

test "sign-in: the form is the screen until there is data; what pages send parses" {
    const needed: state.SignIn = .{ .needed = true, .message = "Refused." };
    try testing.expect(signIn(&needed, .no_data).?.full);
    const line = signIn(&needed, .no_client).?;
    try testing.expect(!line.full);
    try testing.expectEqualStrings("Refused.", line.message);
    try testing.expectEqual(null, signIn(&.{}, .no_data));
    try testing.expectEqual(null, signIn(null, .no_data));

    const old = ui.toshell.out;
    defer ui.toshell.out = old;
    ui.toshell.out = hear;
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    ui.toshell.send(.signin, .{ .username = "ann", .password = "p\"w" });
    const m = try channel.read(arena.allocator(), heard[0..heard_len]);
    try testing.expectEqualStrings("ann", m.signin.username);
    try testing.expectEqualStrings("p\"w", m.signin.password);
    ui.toshell.practice(.place, .{ .at = .{ .enemy = 3 }, .champion = ahri, .locked = true });
    try testing.expectEqual(3, (try channel.read(arena.allocator(), heard[0..heard_len])).practice.place.at.enemy);
}

var heard: [256]u8 = undefined;
var heard_len: usize = 0;

fn hear(s: []const u8) void {
    @memcpy(heard[0..s.len], s);
    heard_len = s.len;
}

test "loading: the role's numbers private only" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var f = try fixture();
    defer f.deinit();
    const strong: loading.Pill = .{ .text = "strong now", .tone = .good, .patch = true };
    const ours = [_]loading.Card{
        .{ .champion = ahri, .role = .middle, .guessed = false, .me = true, .games = 12_400, .win = 0.521, .pills = &.{ .{ .text = "few games", .tone = .caution }, strong } },
        .{ .champion = galio, .role = .top, .guessed = false, .me = false, .games = 900, .win = 0.53, .pills = &.{ strong, .{ .text = "lone AP", .tone = .neutral } } },
    };
    const theirs = [_]loading.Card{
        .{ .champion = syndra, .role = .middle, .guessed = true, .me = false, .games = 0, .win = 0, .pills = &.{} },
        .{ .champion = galio, .role = .top, .guessed = false, .me = false, .games = 900, .win = 0.47, .pills = &.{.{ .text = "weak now", .tone = .bad, .patch = true }} },
    };
    const l: loading.Loading = .{ .teams = .{ &ours, &theirs }, .draft = .{ .win = 0.534, .se = 0.1, .picks = .{ 5, 5 }, .hovers = 0 } };

    const priv = try loadScreen(a, .{ .stats = &f.stats, .icons = null, .private = true }, &l);
    // Top, then mid
    try testing.expectEqual(2, priv.lanes.len);
    const us = priv.lanes[1].us.?;
    try testing.expectEqualStrings("52.1% · 12k games", us.fact);
    try testing.expectEqual(.good, us.lean);
    try testing.expectEqual(.caution, us.pills[0].tone);
    try testing.expect(priv.lanes[1].them.?.guessed and priv.lanes[1].them.?.fact.len == 0);
    try testing.expectApproxEqAbs(@as(f32, 53.4), priv.draft.?, 0.01);
    try testing.expectEqualStrings("strong now", priv.lanes[0].us.?.pills[0].text);

    const c: Ctx = .{ .stats = &f.stats, .icons = null, .private = false };
    const public = try loadScreen(a, c, &l);
    try testing.expectEqual(null, public.draft);
    try testing.expectEqualStrings("", public.lanes[1].us.?.fact);
    // No patch pill on a locked teammate; mine and the enemies' keep theirs
    try testing.expectEqual(1, public.lanes[0].us.?.pills.len);
    try testing.expectEqualStrings("lone AP", public.lanes[0].us.?.pills[0].text);
    try testing.expectEqualStrings("strong now", public.lanes[1].us.?.pills[1].text);
    try testing.expectEqualStrings("weak now", public.lanes[0].them.?.pills[0].text);
    var d = try data(a, c, .{ .loading = &l }, .none);
    d.seq = 1;
    const html = try renderIn(a, d, null, null, .{ .load = public });
    try testing.expect(std.mem.find(u8, html, "c-load") != null);
    try testing.expect(std.mem.find(u8, html, "%") == null);
}

test "loading: a lane per role, the strip's words and figure, the spark about its average" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var f = try fixture();
    defer f.deinit();
    const by: loading.Lengths = .{ .{ .games = 900, .wins = 500 }, .{ .games = 900, .wins = 470 }, .{ .games = 900, .wins = 450 }, .{ .games = 900, .wins = 430 }, .{ .games = 900, .wins = 400 } };
    const facts: loading.LaneFacts = .{ .games = 800, .gold = .{ .mean = -520, .se = 100 }, .level6 = 40, .first_item = 5 };
    const ours = [_]loading.Card{
        .{ .champion = ahri, .role = .middle, .guessed = false, .me = true, .games = 12_400, .win = 0.521, .pills = &.{}, .lane = facts, .lengths = by },
        .{ .champion = syndra, .role = null, .guessed = false, .me = false, .games = 0, .win = 0.5, .pills = &.{} },
    };
    const theirs = [_]loading.Card{.{ .champion = syndra, .role = .middle, .guessed = true, .me = false, .games = 0, .win = 0, .pills = &.{} }};
    const l: loading.Loading = .{ .teams = .{ &ours, &theirs }, .draft = null };
    const public = try loadScreen(a, .{ .stats = &f.stats, .icons = null, .private = false }, &l);
    // Mid, then the seat without a role alone
    try testing.expectEqual(2, public.lanes.len);
    try testing.expectEqual(null, public.lanes[1].them);
    const s = public.lanes[0].strip.?;
    try testing.expectEqual(.them, s.lead);
    try testing.expectEqualStrings("behind", s.text);
    try testing.expectEqual(.them, s.level6.?);
    try testing.expectEqual(null, s.item);
    try testing.expectEqualStrings("tough lane", public.yours[0].text);
    const spark = public.lanes[0].us.?.lengths;
    var sum: f32 = 0;
    for (spark) |v| sum += v;
    try testing.expectApproxEqAbs(@as(f32, 250), sum, 0.01);
    try testing.expect(spark[0] > 50 and spark[4] < 50);
    try testing.expectEqualStrings("Wins more in short games", public.lanes[0].us.?.lengths_label);
    const priv = try loadScreen(a, .{ .stats = &f.stats, .icons = null, .private = true }, &l);
    try testing.expectEqualStrings("−520", priv.lanes[0].strip.?.text);
}

fn testGame(my_lane: ?ingame.Lane) ingame.InGame {
    var rows: [5]ingame.Row = undefined;
    for (&rows, core.Role.all) |*r, role| r.* = .{ .role = role };
    rows[2] = .{
        .role = .middle,
        .ours = .{ .champion = ahri, .level = 9, .kills = 2, .deaths = 1, .assists = 3, .cs = 101, .item_gold = 4200, .dead = false, .respawn = 0, .me = true },
        .theirs = .{ .champion = syndra, .level = 8, .kills = 1, .deaths = 2, .assists = 0, .cs = 90, .item_gold = 3000, .dead = true, .respawn = 12.3, .me = false },
    };
    const S = struct {
        const history = [_]ingame.Sample{
            .{ .time = 0, .team = 0, .lane = 0 },      .{ .time = 60, .team = 100, .lane = 50 },
            .{ .time = 120, .team = 300, .lane = 80 }, .{ .time = 180, .team = 250, .lane = null },
        };
        const timers = [_]ingame.Timer{.{ .what = "Dragon", .back = 300 }};
    };
    return .{
        .time = 230,
        .rows = rows,
        .score = .{ .{ .kills = 3, .item_gold = 9000 }, .{ .kills = 2, .towers = 0, .item_gold = 8100 } },
        .timers = &S.timers,
        .lane = my_lane,
        .lane_note = "No lane to compare.",
        .period = "last 30 days",
        .gold = 300,
        .history = &S.history,
    };
}

test "in game: the private panel, a note for the public edition" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var f = try fixture();
    defer f.deinit();
    const points = [_]lanecard.Point{ .{ .minute = 1, .mean = 10, .p25 = -50, .p75 = 60 }, .{ .minute = 2, .mean = 20, .p25 = -90, .p75 = 110 } };
    const t: ingame.Typical = .{ .p10 = -300, .p25 = -100, .mean = 0, .p75 = 120, .p90 = 400 };
    const g = testGame(.{
        .role = .middle,
        .me = ahri,
        .opponent = syndra,
        .matchup = .{ .bracket = .all, .games = 412, .gold = .{}, .range = .{ -500, 500 }, .lane_games = 412, .ahead = 200, .thin = false, .points = &points },
        .minute = 3,
        .cs = .{ .now = 11, .typical = t, .standing = .typical },
        .gold = .{ .now = 1200, .typical = t, .standing = .far_ahead },
    });

    const d = try data(a, .{ .stats = &f.stats, .icons = null, .private = true }, .{ .in_game = &g }, .none);
    try testing.expectEqualStrings("In game · 3:50", d.where);
    const s = d.screen.game;
    // Kills and towers always; dragons and the rest once someone took one
    try testing.expectEqual(@as(usize, 2), s.score.len);
    try testing.expectEqualStrings("+900 item gold", s.gold.gap);
    try testing.expectEqualStrings("9.0k", s.gold.us);
    const mid = s.rows[2];
    try testing.expectEqualStrings("+1.2k", mid.gap);
    try testing.expectEqual(.good, mid.lean);
    try testing.expectEqual(@as(?u16, 13), mid.them.?.dead);
    try testing.expectEqualStrings("Lv 9 · 101 cs", mid.us.?.line);
    try testing.expect(s.rows[0].us == null and s.rows[0].gap.len == 0);
    const l = s.lane.?;
    try testing.expectEqualStrings("+11", l.compare[0].now);
    try testing.expectEqualStrings("about typical at 3 min (middle half \u{2212}100 to +120)", l.compare[0].text);
    try testing.expectEqual(.good, l.compare[1].lean);
    const c = l.chart.?;
    try testing.expectEqualSlices([2]f32, &.{ .{ 0, 0 }, .{ -50, 60 }, .{ -90, 110 } }, c.band);
    // Minutes 0..3; a sample without a lane keeps the last; the last is now
    try testing.expectEqualSlices(f32, &.{ 0, 50, 80, 1200 }, c.you);
    try testing.expectEqualSlices(f32, &.{ 0, 100, 300, 900 }, s.team);
    try testing.expectEqualStrings("5:00", s.timers[0].at);
    try testing.expectEqualStrings("1:10", s.timers[0].in);
    var shown = d;
    shown.seq = 1;
    const html = try render(a, shown, null, null);
    try testing.expect(std.mem.find(u8, html, "c-game") != null and std.mem.find(u8, html, "c-lane") != null);

    const p = try data(a, .{ .stats = &f.stats, .icons = null, .private = false }, .{ .in_game = &testGame(null) }, .none);
    try testing.expectEqualStrings("In game", p.where);
    try testing.expectEqualStrings("In game", p.screen.note.title);
}

test "in game: the build panel, private edition with a plan only" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var f = try fixture();
    defer f.deinit();
    var g = testGame(null);
    const c: Ctx = .{ .stats = &f.stats, .icons = null, .private = true };
    try testing.expectEqual(null, try gameBuild(a, c, .{ .in_game = &g }));
    g.plan = .{
        .champion = ahri,
        .role = .middle,
        .games = 900,
        .items = &.{ .{ .id = 3020, .owned = true }, .{ .id = 4645, .owned = false } },
        .order = "QWE",
        .path = "",
        .level = 9,
        .skills = .{ 4, 3, 1, 0 },
        .next = 'E',
        .unspent = true,
    };
    var public = c;
    public.private = false;
    try testing.expectEqual(null, try gameBuild(a, public, .{ .in_game = &g }));
    const b = (try gameBuild(a, c, .{ .in_game = &g })).?;
    try testing.expectEqual(@as(?u8, 1), b.next);
    // No client icon fetched yet: an empty square
    try testing.expectEqualStrings("", b.items[0].art.src);
    var d = try data(a, c, .{ .in_game = &g }, .none);
    d.seq = 1;
    const html = try renderIn(a, d, null, null, .{ .build = b });
    try testing.expect(std.mem.find(u8, html, "c-gamebuild") != null and std.mem.find(u8, html, "Level up <b class=\"k\">E</b>") != null);
}

test "in game: tips and the spike sheet without a build, sooner by a clear gap only" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var f = try fixture();
    defer f.deinit();
    var g = testGame(null);
    const c: Ctx = .{ .stats = &f.stats, .icons = null, .private = true };
    g.tips = &.{"They're all AP: magic resist goes a long way"};
    g.spikes = .{ .opponent = ahri, .level6 = .{ 420, 430 }, .first_item = .{ 600, 660 }, .games = 800, .lean = .{ .none, .late } };
    const b = (try gameBuild(a, c, .{ .in_game = &g })).?;
    try testing.expectEqual(0, b.games);
    try testing.expectEqualStrings("Ahri", b.spikes.?.opponent);
    try testing.expectEqual(null, b.spikes.?.level6.sooner);
    try testing.expectEqual(@as(?u1, 0), b.spikes.?.first_item.sooner);
    try testing.expectEqual(.late, b.spikes.?.lean[1]);
}

test "options: most picked runes and spells, the client's icons once fetched" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const facts: core.champfacts.Facts = .{
        .runes = &.{.{ .champion = ahri, .role = .middle, .share = 0.6, .keystone = 8112, .second = 8200 }},
        .spells = &.{.{ .champion = ahri, .role = .middle, .share = 0.9, .ids = .{ 4, 14 } }},
        .rune_names = &.{ .{ .id = 8112, .name = "Electrocute" }, .{ .id = 8200, .name = "Sorcery" } },
        .spell_names = &.{ .{ .id = 4, .name = "Flash" }, .{ .id = 14, .name = "Ignite" } },
    };
    var icons: desktop.Icons = .{ .gpa = testing.allocator };
    defer icons.deinit();
    const c: Ctx = .{ .stats = null, .facts = &facts, .icons = &icons, .private = false };
    const before = try picked(a, c, ahri, .middle);
    try testing.expectEqualStrings("Electrocute + Sorcery", before.runes);
    try testing.expectEqualStrings("", before.rune_src);
    try icons.put(.{ .kind = .perk, .id = 8112 }, try testing.allocator.dupe(u8, "png"));
    try icons.put(.{ .kind = .spell, .id = 14 }, try testing.allocator.dupe(u8, "png"));
    const after = try picked(a, c, ahri, .middle);
    try testing.expectEqualStrings("perk/8112.png", after.rune_src);
    try testing.expectEqualStrings("Flash, Ignite", after.spells);
    try testing.expectEqualStrings("", after.spell_srcs[0]);
    try testing.expectEqualStrings("spell/14.png", after.spell_srcs[1]);
}

test "options: the region chip once there are every region's stats, the lane panel says which" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var f = try fixture();
    defer f.deinit();
    var sel = testSelect();
    const galio_pick: desktop.picks.Pick = .{ .champion = galio, .win = 0.54, .pp = 1.4, .role = .{ .games = 100, .wins = 54 }, .mastery = 0, .pool = false, .shown = false, .gold = null, .reasons = &.{} };
    sel.picks = .{ .role = .middle, .picks = &.{galio_pick} };
    var c: Ctx = .{ .stats = &f.stats, .icons = null, .private = true };

    const euw_only = (try picksOf(a, c, &sel)).?;
    try testing.expectEqual(null, euw_only.all_regions);
    try testing.expectEqualStrings("EUW, last 30 days", euw_only.scope);

    sel.all_regions = true;
    c.region = regionOf(&sel);
    const all = (try picksOf(a, c, &sel)).?;
    try testing.expectEqual(true, all.all_regions);
    try testing.expectEqualStrings("last 30 days", all.scope);
    const d = try data(a, c, .{ .select = &sel }, .none);
    try testing.expectEqualStrings("All regions, last 30 days", d.screen.select.lane.scope);
    const html = try renderIn(a, d, null, null, .{ .picks = all });
    try testing.expect(std.mem.find(u8, html, "data-shell=\"{&quot;regions&quot;:false}\"") != null);
}

test "post game: static after the island, award cards, lanes, damage by team" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var f = try fixture();
    defer f.deinit();
    var rows: [5]postgame.Row = undefined;
    for (&rows, core.Role.all) |*r, role| r.* = .{ .role = role };
    rows[2] = .{
        .role = .middle,
        .ours = .{ .champion = ahri, .kills = 7, .deaths = 2, .assists = 9, .cs = 231, .gold = 13_000, .damage = 24_600, .vision = 20, .level = 16, .me = true },
        .theirs = .{ .champion = syndra, .kills = 2, .deaths = 7, .assists = 3, .cs = 214, .gold = 13_200, .damage = 950, .vision = 12, .level = 15, .me = false },
    };
    const p: postgame.PostGame = .{
        .win = true,
        .length = 1722,
        .verdict = "Victory 28:42",
        .awards = &.{.{ .champion = ahri, .ours = true, .figures = &.{ .{ .kind = .damage, .value = 24_600 }, .{ .kind = .kda, .value = 8 }, .{ .kind = .cs, .value = 231 } } }},
        .rows = rows,
        .kills = .{ 24, 17 },
        .gold = .{ 60_000, 52_000 },
        .history = &.{},
    };
    const c: Ctx = .{ .stats = &f.stats, .icons = null, .private = false };
    const s = (try postUnder(a, c, .{ .post_game = &p })).?;
    try testing.expectEqualStrings("231 cs · 25k dmg", s.rows[2].us.?.line);
    try testing.expectEqualStrings("\u{2212}200", s.rows[2].gap);
    try testing.expectEqual(.none, s.rows[2].lean);
    try testing.expectEqualStrings("950", s.damage[1].players[0].text);
    try testing.expectEqualStrings("25k", s.damage[0].total);
    try testing.expectEqualStrings("Ahri", s.awards[0].champ.?.name);
    try testing.expectEqualStrings("25k dmg", s.awards[0].figures[0]);
    try testing.expectEqualStrings("8.0 KDA", s.awards[0].figures[1]);
    try testing.expectEqualStrings("231 cs", s.awards[0].figures[2]);
    var d = try data(a, c, .{ .post_game = &p }, .none);
    try testing.expectEqual(.post, d.screen);
    d.seq = 1;
    const html = try renderIn(a, d, null, null, .{ .post = s });
    try testing.expect(std.mem.find(u8, html, "Victory 28:42") != null);
    try testing.expect(std.mem.find(u8, html, "c-post") != null);

    var coming = p;
    coming.pending = true;
    coming.verdict = "Result coming";
    const pending = (try postUnder(a, c, .{ .post_game = &coming })).?;
    try testing.expect(pending.coming);
    try testing.expectEqualStrings("Lv 16 · 231 cs", pending.rows[2].us.?.line);
    try testing.expectEqual(0, pending.damage[0].players.len + pending.damage[1].players.len);
    try testing.expectEqualStrings("", pending.rows[2].gap);
}

test "app.css holds every component the app's screens draw" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var t: ui.tree.Tree = .{};
    var h: ui.tree.H = .init(a, &t);
    var out: std.Io.Writer.Allocating = .init(a);
    for (ui.gallery.states(&h, ui.app, 0)) |s| try ui.html.write(&t, s.node, &out.writer);
    try testing.expect(!h.oom);
    var rest = out.written();
    while (std.mem.find(u8, rest, "class=\"")) |i| {
        rest = rest[i + 7 ..];
        var it = std.mem.tokenizeScalar(u8, rest[0..std.mem.findScalar(u8, rest, '"').?], ' ');
        while (it.next()) |c| if (std.mem.startsWith(u8, c, "c-") and !hasCss(c)) {
            std.debug.print("app.css lacks the component scoped .{s}: add it to screens.css\n", .{c});
            return error.TestUnexpectedResult;
        };
    }
}

/// Whether app.css holds the rules of the component scoped `.class` (another component's
/// selector may name the class without it)
fn hasCss(class: []const u8) bool {
    @setEvalBranchQuota(20000);
    inline for (ui.all) |C| inline for (C.scope) |sc| {
        if (std.mem.eql(u8, sc[1..], class)) return std.mem.find(u8, css, C.css) != null;
    };
    return true;
}
