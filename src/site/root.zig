//! `meiolol site`: the public stats website as static files (HTML, CSS, the model
//! file and champion JSON for the browser pages). Host anywhere static.

const std = @import("std");
const store = @import("store");
const core = @import("core");
const stats = @import("../stats.zig");
pub const html = @import("html.zig");
const prose = @import("prose.zig");
const daily_page = @import("daily.zig");
const your_page = @import("your.zig");
const daily = @import("../daily.zig");
const learn = @import("../learn.zig");
const learn_page = @import("learn.zig");
const matchup = @import("matchup.zig");
const pool_page = @import("pool.zig");
const pool = @import("../pool.zig");
const learning_page = @import("learning.zig");
const learning = @import("../learning.zig");
const builds_page = @import("builds.zig");
const builds = @import("../builds.zig");
const filters = @import("filters.zig");
const evalchart = @import("evalchart.zig");

const Writer = std.Io.Writer;
const Stats = core.Stats;
const Role = core.Role;
const esc = html.esc;
const score = core.score;

const log = std.log.scoped(.site);

pub const Options = struct {
    out_dir: []const u8,
    /// The current patch, for the patch views (html.View)
    patches: []const []const u8,
    /// Start of the 30-day views, Unix ms
    since_ms: i64,
    /// Riot platform ids of the EUW views
    platforms: []const []const u8 = &.{"EUW1"},
    /// Of the all-regions views
    all_platforms: []const []const u8,
    contact: []const u8,
    /// The string Riot's application form gives, served as /riot.txt
    riot_txt: ?[]const u8 = null,
    /// "11 October 2026", for the legal pages
    updated: []const u8,
    /// False until Riot grants the production key: personal-key data may not serve
    /// the public (docs/production-key.md), so pages are unlisted and say so
    public: bool = false,
    /// Where Daily Draft puzzles are kept (src/daily.zig); null leaves them out
    daily_dir: ?[]const u8 = null,
    /// Lane curves file per view (html.View.index; `meiolol curves`): matchup pages
    /// where set
    curves: [html.View.count]?[]const u8 = @splat(null),
    /// Builds file per view (`meiolol builds`): build pages in the patch views where set
    builds: [html.View.count]?[]const u8 = @splat(null),
    /// Only the EUW views (the root and patch/; the shared pages come from patch/): a
    /// quick preview, links into all/ dangle
    euw_only: bool = false,
    /// Front-end files (css, js) read from here per request instead of embedded: `meiolol
    /// dev`
    static_dir: ?[]const u8 = null,
    /// Matchup pages with fewer games are left out of the static build: `meiolol render`
    /// serves them on request
    static_min_games: u32 = 0,
    /// "https://meiolol.jomify.lol": canonical links and sitemaps, when public
    origin: ?[]const u8 = null,
    /// Matchup pages with fewer games are noindex and left out of the sitemaps
    index_min_games: u32 = 0,
    /// The daily eval's TSV (`meiolol eval --history`) for the method page's chart
    eval_history: ?[]const u8 = null,
};

/// Below this share of all games a champion's row is a rare pick, listed on request
const min_pick_rate = 0.004;
/// And below this share of the champion's own games, as a role it rarely plays
const min_role_share = 0.1;
/// Champion page: lane opponents with fewer games are faded and listed last
const min_opponent_games = 10;

pub const Champ = struct {
    /// Index in the stats file
    c: usize,
    id: u32,
    key: []const u8,
    name: []const u8,
    slug: []const u8,
    banned: u32,
    games: u64,
};

/// One view's data, loaded once (`load`), and what every page of it renders from
/// (`renderPage`, `renderShared`): the static build and the request renderer (`Loaded`)
/// share one function per page type
pub const Site = struct {
    gpa: std.mem.Allocator,
    /// The view's data lives here; while a page renders, that page's own arena (a Site
    /// is copied per page), so rendering never grows or races on the view's
    arena: std.mem.Allocator,
    /// Owns the view's data, freed by unload
    owner: *std.heap.ArenaAllocator,
    io: std.Io,
    stats: Stats,
    champs: []Champ,
    /// Stats index -> champs index
    by_c: []?usize,
    by_slug: std.StringHashMapUnmanaged(usize) = .empty,
    games: u32,
    /// Current patch
    patch: []const u8,
    /// The view's games in running text: "last 30 days", "patch 16.20"
    when: []const u8,
    ddragon_version: []const u8,
    /// The view being written; opts.platforms and opts.patches are its own
    view: html.View,
    /// Games started from (Unix ms; 0 for any)
    since_ms: i64,
    opts: Options,
    score_opts: score.Options = .{},
    curves: ?core.curvesfile.Curves = null,
    /// Every view's (html.View.index), so the switches skip matchups without a page
    view_curves: *const [html.View.count]?core.curvesfile.Curves,
    /// Every view's builds (html.View.index); the 30-day views link to their patch view's
    view_builds: *const [html.View.count]?builds.File,
    pool: pool.Pool = .{},
    learning: learning.Learning = .{},
    /// Data and script files in the view's directory
    files: []const File = &.{},
    /// The shared view's files at the site root (Daily Draft, Learn)
    shared_files: []const File = &.{},
    /// Learn page facts; the shared view's only
    learn: ?learn.Facts = null,
    /// The method page's accuracy chart (Options.eval_history)
    eval: []const evalchart.Point = &.{},
    /// Champion page filter data; the root view's only, as the champion pages
    filter: filters.Made = .{},

    /// A page of the view at `path` within it
    pub fn page(s: *const Site, title: []const u8, description: []const u8, path: []const u8, nav: html.Nav) html.Page {
        var p = s.sharedPage(title, description, nav);
        p.view = s.view;
        p.counterparts = @as([html.View.count][]const u8, undefined);
        for (html.View.all, &p.counterparts.?) |v, *there| {
            there.* = std.mem.concat(s.arena, u8, &.{ v.dir(), path }) catch path;
        }
        p.root = s.toRoot(path);
        p.canonical = s.canonical(s.view.dir(), path);
        return p;
    }

    /// `origin/dir/path`; null without Options.origin
    pub fn canonical(s: *const Site, dir: []const u8, path: []const u8) ?[]const u8 {
        const origin = s.opts.origin orelse return null;
        return std.mem.concat(s.arena, u8, &.{ origin, "/", dir, path }) catch null;
    }

    /// A page at the site root, written once (from html.View.shared)
    pub fn sharedPage(s: *const Site, title: []const u8, description: []const u8, nav: html.Nav) html.Page {
        return .{
            .title = title,
            .description = description,
            .nav = nav,
            .patch = s.patch,
            .data = s.arena.print("{s}, {s}, {d} games", .{ s.view.region.in(), s.when, s.games }) catch "",
            .public = s.opts.public,
        };
    }

    /// From `path` up to its view's root
    pub fn toRoot(s: *const Site, path: []const u8) []const u8 {
        const depth = std.mem.count(u8, path, "/");
        const out = s.arena.alloc(u8, 3 * depth) catch return "";
        for (0..depth) |i| @memcpy(out[3 * i ..][0..3], "../");
        return out;
    }

    /// From `path` to the site root, where the shared pages are
    pub fn toShared(s: *const Site, path: []const u8) []const u8 {
        return std.mem.concat(s.arena, u8, &.{ s.toRoot(path), s.view.up() }) catch "";
    }

    pub fn icon(s: *const Site, ch: Champ) []const u8 {
        return s.arena.print(
            "https://ddragon.leagueoflegends.com/cdn/{s}/img/champion/{s}.png",
            .{ s.ddragon_version, ch.key },
        ) catch "";
    }

    /// To the champion's page (one per champion, at the site root), its filters set to
    /// this view. `to_site`: from the linking page to the site root. Raw: escape it
    pub fn champHref(s: *const Site, ch: Champ, to_site: []const u8) []const u8 {
        return s.arena.print("{s}champion/{s}.html{s}", .{ to_site, ch.slug, s.view.query() }) catch "";
    }

    pub fn champLink(s: *const Site, w: *Writer, ch: Champ, to_site: []const u8) !void {
        try w.print(
            "<a class=\"champ\" href=\"{f}\"><img src=\"{s}\" alt=\"\" loading=\"lazy\" width=\"32\" height=\"32\">{f}</a>",
            .{ esc(s.champHref(ch, to_site)), s.icon(ch), esc(ch.name) },
        );
    }

    pub fn champBySlug(s: *const Site, slug_: []const u8) ?Champ {
        return s.champs[s.by_slug.get(slug_) orelse return null];
    }

    fn pickRate(s: *const Site, games: u64) f64 {
        return if (s.games == 0) 0 else @as(f64, @floatFromInt(games)) / @as(f64, @floatFromInt(s.games));
    }

    fn info(s: *const Site) prose.Info {
        return .{ .contact = s.opts.contact, .updated = s.opts.updated, .curves = biggestCurves(s.view_curves) };
    }
};

pub const File = daily.File;

/// Front-end files at the site root; `Options.static_dir` serves them from disk instead
const shared_assets = [_]File{
    .{ .path = "style.css", .data = @embedFile("static/style.css") },
    .{ .path = "favicon.svg", .data = @embedFile("static/favicon.svg") },
    .{ .path = "daily.js", .data = @embedFile("static/daily.js") },
    .{ .path = "your.js", .data = @embedFile("static/your.js") },
    .{ .path = "learn.js", .data = @embedFile("static/learn.js") },
    .{ .path = "table.js", .data = @embedFile("static/table.js") },
    .{ .path = "filters.js", .data = @embedFile("static/filters.js") },
};
/// And in every view's directory
const view_assets = [_]File{
    .{ .path = "pool.js", .data = @embedFile("static/pool.js") },
    .{ .path = "min-games.js", .data = @embedFile("static/min-games.js") },
};

/// Asset `name` from Options.static_dir when set (edits show without a rebuild), else
/// as embedded; null for anything else
pub fn asset(arena: std.mem.Allocator, io: std.Io, opts: Options, name: []const u8) !?[]const u8 {
    const all = shared_assets ++ view_assets;
    const embedded = for (all) |f| {
        if (std.mem.eql(u8, f.path, name)) break f.data;
    } else return null;
    const dir = opts.static_dir orelse return embedded;
    const path = try std.fs.path.join(arena, &.{ dir, name });
    return try std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 24));
}

/// Pages at the site root, from the shared view (renderShared)
pub const shared_pages = [_][]const u8{
    "learn.html", "method.html", "daily.html", "download.html", "your.html", "privacy.html", "terms.html",
};

/// Every view's curves and builds files, loaded once for all of them
pub const Extras = struct {
    curves: [html.View.count]?core.curvesfile.Curves = @splat(null),
    builds: [html.View.count]?builds.File = @splat(null),
    /// Pool and learning tallies by html.Region, on the first view's load: all patches,
    /// so both periods share them, and one pass over the database serves every view
    people: ?People = null,

    pub fn load(arena: std.mem.Allocator, io: std.Io, opts: Options) Extras {
        var e: Extras = .{};
        for (opts.curves, &e.curves) |path, *c| {
            if (path) |p| c.* = loadCurves(arena, io, p);
        }
        for (opts.builds, &e.builds) |path, *b| {
            if (path) |p| b.* = loadBuilds(arena, io, p);
        }
        return e;
    }

    pub fn deinit(e: *Extras, gpa: std.mem.Allocator) void {
        if (e.people) |*p| p.deinit(gpa);
    }

    fn tallies(e: *Extras, gpa: std.mem.Allocator, db: store.Db, st: *const Stats, opts: Options) !*const People {
        if (e.people) |*p| {
            if (std.mem.eql(u32, p.ids, st.ids)) return p;
            // A champion added since (a new release): tally again
            p.deinit(gpa);
            e.people = null;
        }
        const sets: []const []const []const u8 = if (opts.euw_only)
            &.{opts.platforms}
        else
            &.{ opts.platforms, opts.all_platforms };
        const ids = try gpa.dupe(u32, st.ids);
        errdefer gpa.free(ids);
        var p = try pool.tally(gpa, db, st, sets);
        errdefer p.deinit(gpa);
        e.people = .{ .ids = ids, .pool = p, .learning = try learning.tally(gpa, db, st, sets) };
        return &e.people.?;
    }
};

const People = struct {
    /// Stats champion ids, which the tallies index by
    ids: []u32,
    pool: pool.Tallies,
    learning: []learning.Tally,

    fn deinit(p: *People, gpa: std.mem.Allocator) void {
        gpa.free(p.ids);
        p.pool.deinit(gpa);
        learning.freeTallies(gpa, p.learning);
    }
};

pub fn generate(gpa: std.mem.Allocator, io: std.Io, db: store.Db, opts: Options) !void {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    var extras: Extras = .load(arena_state.allocator(), io, opts);
    defer extras.deinit(gpa);
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, opts.out_dir);
    var root_dir = try cwd.openDir(io, opts.out_dir, .{});
    defer root_dir.close(io);
    const gz_window = try gpa.alloc(u8, store.raw.window_len);
    defer gpa.free(gz_window);
    for (html.View.all) |v| {
        if (opts.euw_only and v.region != .euw) continue;
        const site = try load(gpa, io, db, opts, v, &extras);
        defer unload(site);
        try writeSite(site, root_dir, gz_window);
    }
}

/// Every page and file of the view into its directory under `root_dir`, each with a .gz
/// twin for nginx's gzip_static
fn writeSite(site: *const Site, root_dir: std.Io.Dir, gz_window: []u8) !void {
    const io = site.io;
    const sub = if (site.view.dir().len == 0) "." else site.view.dir();
    try root_dir.createDirPath(io, sub);
    var dir = try root_dir.openDir(io, sub, .{});
    defer dir.close(io);
    const w: FileWriter = .{ .gpa = site.gpa, .io = io, .gz_window = gz_window };
    for (site.files) |f| try w.write(dir, f.path, f.data);
    for (site.shared_files) |f| try w.write(root_dir, f.path, f.data);
    if (std.meta.eql(site.view, html.View.shared)) {
        for (shared_assets) |f| try w.write(root_dir, f.path, f.data);
    }
    for (view_assets) |f| try w.write(dir, f.path, f.data);

    var page_arena: std.heap.ArenaAllocator = .init(site.gpa);
    defer page_arena.deinit();
    var s = site.*;
    s.arena = page_arena.allocator();
    const paths = try pagePaths(site);
    var matchups: usize = 0;
    var build_pages: usize = 0;
    var champion_pages: usize = 0;
    for (paths) |path| {
        _ = page_arena.reset(.retain_capacity);
        var aw: Writer.Allocating = .init(s.arena);
        if (!try renderPage(&s, &aw.writer, path)) return error.PageNotRouted;
        try w.write(dir, path, aw.written());
        if (std.mem.startsWith(u8, path, "matchup/") and !std.mem.eql(u8, path, "matchup/index.html")) matchups += 1;
        if (std.mem.startsWith(u8, path, "build/")) build_pages += 1;
        if (std.mem.startsWith(u8, path, "champion/")) champion_pages += 1;
    }
    if (std.meta.eql(site.view, html.View.shared)) for (shared_pages) |path| {
        _ = page_arena.reset(.retain_capacity);
        var aw: Writer.Allocating = .init(s.arena);
        if (!try renderShared(&s, &aw.writer, path)) continue;
        try w.write(root_dir, path, aw.written());
    };
    if (site.curves != null) log.info("{d} matchup pages", .{matchups});
    if (build_pages > 0) log.info("{d} build pages", .{build_pages});
    // deploy/web-loop.sh reads the first "patch" line: EUW's
    log.info("{s}/{s}: {s}, {d} games, {d} champion pages", .{
        site.opts.out_dir, site.view.dir(), site.when, site.games, champion_pages,
    });
}

const FileWriter = struct {
    gpa: std.mem.Allocator,
    io: std.Io,
    gz_window: []u8,

    /// Also `path`.gz, for clients that accept gzip
    fn write(fw: FileWriter, dir: std.Io.Dir, path: []const u8, data: []const u8) !void {
        if (std.fs.path.dirname(path)) |d| try dir.createDirPath(fw.io, d);
        try dir.writeFile(fw.io, .{ .sub_path = path, .data = data });
        if (data.len < 1024) return;
        const gz = try store.raw.compressWith(fw.gpa, fw.gz_window, data);
        defer fw.gpa.free(gz);
        var buf: [std.fs.max_path_bytes]u8 = undefined;
        const gz_path = try std.mem.print(&buf, "{s}.gz", .{path});
        try dir.writeFile(fw.io, .{ .sub_path = gz_path, .data = gz });
    }
};

/// Every page of the view the static build writes, by path within its directory
fn robots(arena: std.mem.Allocator, opts: Options) ![]const u8 {
    if (!opts.public) return "User-agent: *\nDisallow: /\n";
    var out: std.ArrayList(u8) = .empty;
    try out.appendSlice(arena, "User-agent: *\nAllow: /\n");
    if (opts.origin) |origin| for (html.View.all) |v| {
        if (opts.euw_only and v.region != .euw) continue;
        try out.print(arena, "Sitemap: {s}/{s}sitemap.xml\n", .{ origin, v.dir() });
    };
    return out.items;
}

test {
    _ = evalchart;
}

test robots {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const opts: Options = .{ .out_dir = "", .patches = &.{}, .since_ms = 0, .all_platforms = &.{}, .contact = "", .updated = "" };
    try std.testing.expectEqualStrings("User-agent: *\nDisallow: /\n", try robots(arena.allocator(), opts));
    var public = opts;
    public.public = true;
    public.origin = "https://x.io";
    public.euw_only = true;
    try std.testing.expectEqualStrings(
        "User-agent: *\nAllow: /\nSitemap: https://x.io/sitemap.xml\nSitemap: https://x.io/patch/sitemap.xml\n",
        try robots(arena.allocator(), public),
    );
}

/// The view's pages search engines may index, at its root; the root view's (at the
/// site root) also lists the shared pages
fn sitemap(site: *const Site) ![]const u8 {
    const a = site.arena;
    var out: std.ArrayList(u8) = .empty;
    try out.appendSlice(a, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n");
    var paths: std.ArrayList([]const u8) = .empty;
    try paths.appendSlice(a, try pagePathsMin(site, site.opts.index_min_games));
    if (site.view.index() == 0) try paths.appendSlice(a, &shared_pages);
    for (paths.items) |path| {
        // Paths are slugs and fixed names: nothing XML needs escaped
        try out.print(a, "<url><loc>{s}</loc></url>\n", .{site.canonical(site.view.dir(), path).?});
    }
    try out.appendSlice(a, "</urlset>\n");
    return out.items;
}

pub fn pagePaths(site: *const Site) ![]const []const u8 {
    return pagePathsMin(site, site.opts.static_min_games);
}

/// As pagePaths, but matchup pages from `min_games` up
fn pagePathsMin(site: *const Site, min_games: u32) ![]const []const u8 {
    const a = site.arena;
    var list: std.ArrayList([]const u8) = .empty;
    try list.appendSlice(a, &.{ "index.html", "champions.html" });
    for (Role.all) |r| try list.append(a, try a.print("role/{s}.html", .{roleSlug(r)}));
    if (site.view.index() == 0) for (site.champs) |ch| {
        try list.append(a, try a.print("champion/{s}.html", .{ch.slug}));
    };
    try list.append(a, "matchup/index.html");
    if (site.curves) |*c| try matchup.paths(site, c, &list, min_games);
    if (site.view.period == .patch) if (site.view_builds[site.view.index()]) |*b| try builds_page.paths(site, b, &list);
    try list.append(a, "pool.html");
    return list.items;
}

/// The view's page at `path` (within its directory) into `w`; false when it has none
pub fn renderPage(site: *const Site, w: *Writer, path: []const u8) !bool {
    const eql = std.mem.eql;
    if (eql(u8, path, "index.html")) {
        try writeIndex(site, w);
    } else if (eql(u8, path, "champions.html")) {
        try writeTierList(site, w, null);
    } else if (strip(path, "role/", ".html")) |s| {
        try writeTierList(site, w, roleFromSlug(s) orelse return false);
    } else if (strip(path, "champion/", ".html")) |s| {
        if (site.view.index() != 0) return false;
        try writeChampion(site, w, site.champBySlug(s) orelse return false);
    } else if (eql(u8, path, "matchup/index.html")) {
        try matchup.writeIndex(site, w, if (site.curves) |*c| c else null);
    } else if (strip(path, "matchup/", ".html")) |s| {
        return matchup.route(site, w, if (site.curves) |*c| c else return false, s);
    } else if (strip(path, "build/", ".html")) |s| {
        if (site.view.period != .patch) return false;
        return builds_page.route(site, w, if (site.view_builds[site.view.index()]) |*b| b else return false, s);
    } else if (eql(u8, path, "pool.html")) {
        try pool_page.writePage(site, w, &site.pool, &site.learning);
    } else return false;
    return true;
}

/// A page at the site root from the shared view (shared_pages); false for any other path
pub fn renderShared(site: *const Site, w: *Writer, path: []const u8) !bool {
    if (std.mem.eql(u8, path, "learn.html")) {
        try learn_page.write(site, w, &(site.learn orelse return false));
        return true;
    }
    const fixed = [_]struct { []const u8, []const u8, []const u8, html.Nav, *const fn (*Writer, prose.Info) Writer.Error!void }{
        .{ "method.html", "Method", "Where meiolol's numbers come from and how lane curves, champion statistics and the Daily Draft are made.", .method, prose.method },
        .{ "daily.html", "Daily Draft", "Guess the hidden champion and the winner of a real ranked draft, then see what the numbers say.", .daily, daily_page.page },
        .{ "download.html", "Desktop app", "The meiolol desktop app for Windows, in development.", .none, prose.download },
        .{ "your.html", "Your games", "Your lane in each recent ranked game, minute by minute, against how the matchup typically goes at your rank.", .none, your_page.page },
        .{ "privacy.html", "Privacy policy", "What meiolol collects and why.", .none, prose.privacy },
        .{ "terms.html", "Terms of use", "Terms for using meiolol.", .none, prose.terms },
    };
    for (fixed) |f| {
        if (!std.mem.eql(u8, path, f[0])) continue;
        const p = site.sharedPage(try site.arena.print("{s} | meiolol", .{f[1]}), f[2], f[3]);
        try html.head(w, p);
        try f[4](w, site.info());
        if (f[3] == .method) try evalchart.section(w, site.eval);
        try html.foot(w, p);
        return true;
    }
    return false;
}

/// `path` without `prefix` and `suffix`; null unless it has both
fn strip(path: []const u8, prefix: []const u8, suffix: []const u8) ?[]const u8 {
    if (path.len < prefix.len + suffix.len) return null;
    if (!std.mem.startsWith(u8, path, prefix) or !std.mem.endsWith(u8, path, suffix)) return null;
    return path[prefix.len .. path.len - suffix.len];
}

/// Reads the view's data from the database (the slow part of a site build); free with
/// unload
pub fn load(gpa: std.mem.Allocator, io: std.Io, db: store.Db, all_opts: Options, view: html.View, extras: *Extras) !*Site {
    const owner = try gpa.create(std.heap.ArenaAllocator);
    owner.* = .init(gpa);
    errdefer {
        owner.deinit();
        gpa.destroy(owner);
    }
    const arena = owner.allocator();

    var opts = all_opts;
    opts.platforms = switch (view.region) {
        .euw => all_opts.platforms,
        .all => all_opts.all_platforms,
    };
    const since_ms = switch (view.period) {
        .patch => 0,
        .days30 => all_opts.since_ms,
    };
    if (view.period == .days30) opts.patches = try stats.patches(arena, db, opts.platforms);
    const shared = std.meta.eql(view, html.View.shared);
    if (!shared) opts.daily_dir = null;

    var built = try stats.buildSince(gpa, db, opts.patches, opts.platforms, since_ms);
    defer built.builder.deinit();
    if (built.summary.games == 0) return error.NoMatches;
    var label_buf: [core.statsfile.patch_len]u8 = undefined;
    const patch = try arena.dupe(u8, try stats.label(&label_buf, all_opts.patches));
    var model: Writer.Allocating = .init(arena);
    try built.builder.write(&model.writer, if (view.period == .patch) patch else "last 30 days");
    const model_bytes = model.written();

    const site = try arena.create(Site);
    site.* = .{
        .gpa = gpa,
        .arena = arena,
        .owner = owner,
        .io = io,
        .stats = try .parse(arena, model_bytes),
        .champs = &.{},
        .by_c = &.{},
        .games = built.summary.games,
        .patch = patch,
        .when = switch (view.period) {
            .patch => try arena.print("patch {s}", .{patch}),
            .days30 => "last 30 days",
        },
        .ddragon_version = "",
        .view = view,
        .since_ms = since_ms,
        .opts = opts,
        .curves = extras.curves[view.index()],
        .view_curves = &extras.curves,
        .view_builds = &extras.builds,
    };
    try loadChamps(site, db);

    var files: std.ArrayList(File) = .empty;
    var shared_files: std.ArrayList(File) = .empty;
    if (shared) {
        try shared_files.append(arena, .{ .path = "meiolol.wasm", .data = @embedFile("draft.wasm") });
        try shared_files.append(arena, .{ .path = "chart.wasm", .data = @embedFile("chart.wasm") });
        if (opts.riot_txt) |t| try shared_files.append(arena, .{ .path = "riot.txt", .data = t });
        try shared_files.append(arena, .{ .path = "robots.txt", .data = try robots(arena, opts) });
    }
    if (opts.public and opts.origin != null) {
        try files.append(arena, .{ .path = "sitemap.xml", .data = try sitemap(site) });
    }
    // The root view's directory is the site root, where champion pages are
    if (view.index() == 0) {
        site.filter = try filters.make(site, db, all_opts);
        try files.appendSlice(arena, site.filter.files);
    }
    try files.append(arena, .{ .path = "data/stats.bin", .data = model_bytes });
    try files.append(arena, .{ .path = "data/champions.json", .data = try championsJson(site) });
    const people = try extras.tallies(gpa, db, &site.stats, all_opts);
    const set = @backingInt(view.region);
    if (set >= people.learning.len) return error.NoView;
    site.pool = try pool.make(arena, &people.pool, set, &site.stats, .{});
    {
        var aw: Writer.Allocating = .init(arena);
        try pool.writeJson(&aw.writer, site.pool);
        try files.append(arena, .{ .path = "data/pool.json", .data = aw.written() });
    }
    site.learning = try learning.make(arena, &people.learning[set], &site.stats, .{});
    {
        var aw: Writer.Allocating = .init(arena);
        try learning.writeJson(&aw.writer, site.learning);
        try files.append(arena, .{ .path = "data/learning.json", .data = aw.written() });
    }

    if (opts.daily_dir) |d| {
        const day: u32 = @intCast(@divFloor(std.Io.Clock.real.now(io).toSeconds(), std.time.s_per_day));
        const daily_files = daily.update(arena, io, db, &site.stats, .{
            .dir = d,
            .patches = opts.patches,
            .platforms = opts.platforms,
            .today = day,
        }) catch |err| blk: {
            log.warn("daily draft: {t}", .{err});
            break :blk &.{};
        };
        try shared_files.appendSlice(arena, daily_files);
    }
    if (shared) if (opts.eval_history) |path| {
        if (std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(16 << 20))) |tsv| {
            site.eval = try evalchart.parse(arena, tsv);
        } else |err| log.info("no eval history at {s}: {t}", .{ path, err });
    };
    // After the Daily Draft, so practice leaves out the games behind its puzzles
    if (shared) {
        const day: u32 = @intCast(@divFloor(std.Io.Clock.real.now(io).toSeconds(), std.time.s_per_day));
        if (learn.build(arena, io, db, &site.stats, if (site.curves) |*c| c else null, .{
            .patches = opts.patches,
            .platforms = opts.platforms,
            .today = day,
            .daily_dir = opts.daily_dir,
        })) |l| {
            try shared_files.appendSlice(arena, l.files);
            site.learn = l.facts;
        } else |err| log.warn("learn: {t}", .{err});
    }
    site.files = files.items;
    site.shared_files = shared_files.items;
    return site;
}

pub fn unload(site: *Site) void {
    const owner = site.owner;
    const gpa = site.gpa;
    owner.deinit();
    gpa.destroy(owner);
}

/// The whole site in memory for rendering on request (`meiolol serve --render`, `meiolol
/// dev`): each view loads on its first request and stays
pub const Loaded = struct {
    gpa: std.mem.Allocator,
    io: std.Io,
    db: store.Db,
    opts: Options,
    arena_state: std.heap.ArenaAllocator,
    extras: Extras,
    sites: [html.View.count]?*Site = @splat(null),
    mutex: std.Io.Mutex = .init,
    /// False: requests never load a view; one not loaded yet is error.Loading (`meiolol
    /// render` loads them with loadView while it serves)
    lazy: bool = true,

    pub fn init(gpa: std.mem.Allocator, io: std.Io, db: store.Db, opts: Options) !*Loaded {
        const l = try gpa.create(Loaded);
        l.* = .{ .gpa = gpa, .io = io, .db = db, .opts = opts, .arena_state = .init(gpa), .extras = .{} };
        l.extras = .load(l.arena_state.allocator(), io, opts);
        return l;
    }

    pub fn deinit(l: *Loaded) void {
        for (l.sites) |s| if (s) |loaded| unload(loaded);
        l.extras.deinit(l.gpa);
        l.arena_state.deinit();
        l.gpa.destroy(l);
    }

    pub fn site(l: *Loaded, v: html.View) !*const Site {
        try l.mutex.lock(l.io);
        defer l.mutex.unlock(l.io);
        if (l.sites[v.index()]) |s| return s;
        if (!l.lazy) return error.Loading;
        const s = try load(l.gpa, l.io, l.db, l.opts, v, &l.extras);
        l.sites[v.index()] = s;
        return s;
    }

    /// Loads `v` without holding the lock, so requests for loaded views go on meanwhile.
    /// Only one caller at a time: the database connection isn't shared
    pub fn loadView(l: *Loaded, v: html.View) !void {
        {
            try l.mutex.lock(l.io);
            defer l.mutex.unlock(l.io);
            if (l.sites[v.index()] != null) return;
        }
        const s = try load(l.gpa, l.io, l.db, l.opts, v, &l.extras);
        l.mutex.lockUncancelable(l.io);
        defer l.mutex.unlock(l.io);
        l.sites[v.index()] = s;
    }

    /// The page or file at `path` from the site root, in `arena`; null when there is none
    pub fn get(l: *Loaded, arena: std.mem.Allocator, path: []const u8) !?[]const u8 {
        const view, const rest = for ([_]html.View{ html.View.all[3], html.View.all[2], html.View.all[1] }) |v| {
            if (std.mem.startsWith(u8, path, v.dir())) break .{ v, path[v.dir().len..] };
        } else .{ html.View.all[0], path };
        if (l.opts.euw_only and view.region != .euw) return null;
        if (try asset(arena, l.io, l.opts, rest)) |data| return data;
        var s = (try l.site(view)).*;
        s.arena = arena;
        var aw: Writer.Allocating = .init(arena);
        if (try renderPage(&s, &aw.writer, rest)) return aw.written();
        for (s.files) |f| if (std.mem.eql(u8, f.path, rest)) return f.data;
        if (view.index() != 0) return null;
        var shared = (try l.site(html.View.shared)).*;
        shared.arena = arena;
        if (try renderShared(&shared, &aw.writer, rest)) return aw.written();
        for (shared.shared_files) |f| if (std.mem.eql(u8, f.path, rest)) return f.data;
        return null;
    }
};

/// Optional, as curves: a bad or missing file leaves out build pages
fn loadBuilds(arena: std.mem.Allocator, io: std.Io, path: []const u8) ?builds.File {
    const bytes = std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 30)) catch |err| {
        switch (err) {
            error.FileNotFound => log.info("no builds at {s}", .{path}),
            else => log.warn("builds at {s}: {t}", .{ path, err }),
        }
        return null;
    };
    return builds.File.parse(arena, bytes) catch |err| {
        log.warn("builds at {s}: {t}", .{ path, err });
        return null;
    };
}

/// Optional extras: a bad or old file leaves out matchup pages, not the site
/// The views' curves file with the most games: the steadiest fit for the method page
fn biggestCurves(all: *const [html.View.count]?core.curvesfile.Curves) ?*const core.curvesfile.Curves {
    var best: ?*const core.curvesfile.Curves = null;
    for (all) |*c| if (c.*) |*x| {
        if (best == null or x.games > best.?.games) best = x;
    };
    return best;
}

fn loadCurves(arena: std.mem.Allocator, io: std.Io, path: []const u8) ?core.curvesfile.Curves {
    const bytes = std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 30)) catch |err| {
        switch (err) {
            error.FileNotFound => log.info("no lane curves at {s}", .{path}),
            else => log.warn("lane curves at {s}: {t}", .{ path, err }),
        }
        return null;
    };
    return core.curvesfile.Curves.parse(arena, bytes) catch |err| {
        log.warn("lane curves at {s}: {t}", .{ path, err });
        return null;
    };
}

fn loadChamps(site: *Site, db: store.Db) !void {
    const a = site.arena;
    var banned: std.AutoHashMapUnmanaged(u32, u32) = .empty;
    {
        const patch_json = try std.json.Stringify.valueAlloc(a, site.opts.patches, .{});
        const platform_json = try std.json.Stringify.valueAlloc(a, site.opts.platforms, .{});
        var q = try db.prepare(
            \\SELECT b.champion_id, count(DISTINCT b.match_id)
            \\FROM bans b JOIN matches m USING (match_id)
            \\WHERE m.patch IN (SELECT value FROM json_each(?)) AND m.queue_id = ?
            \\  AND m.platform IN (SELECT value FROM json_each(?))
            \\  AND m.remake = 0 AND m.game_start >= ?
            \\GROUP BY 1
        );
        defer q.deinit();
        try q.bind(.{ patch_json, stats.ranked_solo, platform_json, site.since_ms });
        while (try q.step()) try banned.put(a, @intCast(q.int(0)), @intCast(q.int(1)));
    }

    var list: std.ArrayList(Champ) = .empty;
    var q = try db.prepare("SELECT id, key, name, ddragon_version FROM champions ORDER BY name");
    defer q.deinit();
    try q.bind(.{});
    while (try q.step()) {
        const id: u32 = @intCast(q.int(0));
        const c = site.stats.index(id) orelse continue;
        const name = try a.dupe(u8, q.bytes(2));
        try list.append(a, .{
            .c = c,
            .id = id,
            .key = try a.dupe(u8, q.bytes(1)),
            .name = name,
            .slug = try slug(a, name),
            .banned = banned.get(id) orelse 0,
            .games = site.stats.champGames(c),
        });
        if (site.ddragon_version.len == 0) site.ddragon_version = try a.dupe(u8, q.bytes(3));
    }
    site.champs = try list.toOwnedSlice(a);
    site.by_c = try a.alloc(?usize, site.stats.n);
    @memset(site.by_c, null);
    for (site.champs, 0..) |ch, i| site.by_c[ch.c] = i;
    for (site.champs, 0..) |ch, i| try site.by_slug.put(a, ch.slug, i);
}

/// "Kai'Sa" -> "kaisa", "Nunu & Willump" -> "nunu-willump"
fn slug(a: std.mem.Allocator, name: []const u8) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    var gap = false;
    for (name) |ch| {
        if (std.ascii.isAlphanumeric(ch)) {
            if (gap and out.items.len > 0) try out.append(a, '-');
            gap = false;
            try out.append(a, std.ascii.toLower(ch));
        } else if (ch == ' ' or ch == '&') {
            gap = true;
        }
    }
    return out.toOwnedSlice(a);
}

fn championsJson(site: *const Site) ![]const u8 {
    var aw: Writer.Allocating = .init(site.arena);
    const w = &aw.writer;
    try w.print("{{\"patch\":\"{s}\",\"games\":{d},\"ddragon\":\"{s}\",\"champions\":[", .{
        site.patch, site.games, site.ddragon_version,
    });
    for (site.champs, 0..) |ch, i| {
        if (i > 0) try w.writeByte(',');
        try w.print("{{\"id\":{d},\"key\":", .{ch.id});
        try std.json.Stringify.value(ch.key, .{}, w);
        try w.writeAll(",\"name\":");
        try std.json.Stringify.value(ch.name, .{}, w);
        try w.print(",\"slug\":\"{s}\",\"games\":[", .{ch.slug});
        for (Role.all, 0..) |r, j| {
            if (j > 0) try w.writeByte(',');
            try w.print("{d}", .{site.stats.champRole(r, ch.c).games});
        }
        try w.writeAll("]}");
    }
    try w.writeAll("]}\n");
    return aw.written();
}

const Row = struct {
    ch: Champ,
    role: Role,
    games: u32,
    wins: u32,
    /// Under min_pick_rate or min_role_share: listed only on request
    rare: bool,
};

/// Every champion's games in `role`, or in each role it plays when null. Most played
/// first; the browser sorts by any column (static/table.js)
fn tierRows(site: *const Site, role: ?Role) ![]Row {
    var rows: std.ArrayList(Row) = .empty;
    for (Role.all) |r| {
        if (role != null and role.? != r) continue;
        for (site.champs) |ch| {
            const cr = site.stats.champRole(r, ch.c);
            if (cr.games == 0) continue;
            const share = @as(f64, @floatFromInt(cr.games)) / @as(f64, @floatFromInt(@max(ch.games, 1)));
            try rows.append(site.arena, .{
                .ch = ch,
                .role = r,
                .games = cr.games,
                .wins = cr.wins,
                .rare = site.pickRate(cr.games) < min_pick_rate or share < min_role_share,
            });
        }
    }
    std.mem.sort(Row, rows.items, {}, struct {
        fn f(_: void, a: Row, b: Row) bool {
            return a.games > b.games;
        }
    }.f);
    return rows.items;
}

fn pct(w: *Writer, part: u64, whole: u64) !void {
    if (whole == 0) return w.writeAll("-");
    try w.print("{d:.1}%", .{100 * @as(f64, @floatFromInt(part)) / @as(f64, @floatFromInt(whole))});
}

fn ratio(part: u64, whole: u64) f64 {
    return if (whole == 0) 0 else @as(f64, @floatFromInt(part)) / @as(f64, @floatFromInt(whole));
}

/// Wilson 95% interval of a win rate: where the true rate likely is, given the games
pub fn wilson(wins: u32, games: u32) [2]f64 {
    if (games == 0) return .{ 0, 1 };
    const z = 1.96;
    const n: f64 = @floatFromInt(games);
    const p = @as(f64, @floatFromInt(wins)) / n;
    const d = 1 + z * z / n;
    const c = (p + z * z / (2 * n)) / d;
    const h = z * @sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d;
    return .{ c - h, c + h };
}

/// Coloured only when the whole interval is on one side of 50%: no grades, and no
/// pulling small samples toward 50% either
fn side(iv: [2]f64) []const u8 {
    return if (iv[0] > 0.5) "up" else if (iv[1] < 0.5) "down" else "even";
}

/// Win rate cell: the interval as a bar on an axis 50% ± `span` with the rate as a dot,
/// then the rate and its ±, coloured by wrColour. data-v for sorting
fn winRateCell(w: *Writer, wins: u32, games: u32, span: f64) !void {
    const iv = wilson(wins, games);
    const p = ratio(wins, games);
    const at = struct {
        fn f(x: f64, half: f64) f64 {
            return 100 * (std.math.clamp(x, 0.5 - half, 0.5 + half) - (0.5 - half)) / (2 * half);
        }
    }.f;
    try w.print(
        "<td data-v=\"{d:.4}\"><span class=\"wr\" style=\"--c:{f}\"><span class=\"ci\" title=\"95%: {d:.1}% to {d:.1}%, {d} games\">" ++
            "<i class=\"r\" style=\"left:{d:.1}%;width:{d:.1}%\"></i><i class=\"d\" style=\"left:{d:.1}%\"></i></span>" ++
            "<b>{d:.1}%</b><small>±{d:.1}</small></span></td>",
        .{
            p,       wrColour(p, span),    100 * iv[0],                       100 * iv[1],
            games,   at(iv[0], span),      at(iv[1], span) - at(iv[0], span), at(p, span),
            100 * p, 50 * (iv[1] - iv[0]),
        },
    );
}

/// Win rate colour, diverging: orange below 50%, blue above, grey at 50%; full at
/// 50% ± 40% of the bar's `span` (±5 points on the champions table, ±10 against an
/// opponent). Not red against green: the pair red-green colour blindness merges
fn wrColour(p: f64, span: f64) WrColour {
    return .{ .t = std.math.clamp((p - 0.5) / (0.4 * span), -1, 1) };
}

const WrColour = struct {
    t: f64,

    pub fn format(c: WrColour, w: *Writer) Writer.Error!void {
        const hue: f64 = if (c.t < 0) 50 else 225;
        try w.print("oklch(0.76 {d:.3} {d:.0})", .{ 0.15 * @abs(c.t), hue });
    }
};

/// Under this many games a page says its data is early
const early_games = 50_000;

/// `filtered`: written even when hidden, for filters.js to show when the filters pick fewer
/// games
fn earlyNote(site: *const Site, w: *Writer, filtered: bool) !void {
    const early = site.games < early_games;
    if (!early and !filtered) return;
    try w.print(
        "<p class=\"note\" data-early=\"{d}\"{s}>Early data: <span data-early-games>{d} games so far ({s})</span>. Each bar shows where a win rate likely is (95%) and narrows as games come in. Colour runs from orange (low) through grey (50%) to blue (high).</p>\n",
        .{ early_games, if (early) "" else " hidden", site.games, site.when },
    );
}

/// All roles (champions.html) and one per role (role/<slug>.html)
fn roleTabs(w: *Writer, current: ?Role, root: []const u8) !void {
    try w.print("<nav class=\"tabs\"><a href=\"{s}champions.html\"{s}>All roles</a>", .{
        root, if (current == null) " aria-current=\"page\"" else "",
    });
    for (Role.all) |r| {
        try w.print("<a href=\"{s}role/{s}.html\"{s}>{s}</a>", .{
            root,                                               roleSlug(r),
            if (current == r) " aria-current=\"page\"" else "", roleName(r),
        });
    }
    try w.writeAll("</nav>\n");
}

pub fn roleSlug(r: Role) []const u8 {
    return switch (r) {
        .top => "top",
        .jungle => "jungle",
        .middle => "mid",
        .bottom => "bot",
        .utility => "support",
    };
}

pub fn roleFromSlug(s: []const u8) ?Role {
    for (Role.all) |r| if (std.mem.eql(u8, roleSlug(r), s)) return r;
    return null;
}

pub fn roleName(r: Role) []const u8 {
    return switch (r) {
        .top => "Top",
        .jungle => "Jungle",
        .middle => "Mid",
        .bottom => "Bot",
        .utility => "Support",
    };
}

/// Champions table: win rate with its interval, its low end ("at least"), pick and ban
/// rate, games. Rows sorted by win rate; rare picks hidden until asked for
fn tierTable(site: *const Site, w: *Writer, role: ?Role, root: []const u8) !void {
    const rows = try tierRows(site, role);
    std.mem.sort(Row, rows, {}, struct {
        fn f(_: void, a: Row, b: Row) bool {
            return ratio(a.wins, a.games) > ratio(b.wins, b.games);
        }
    }.f);
    try w.writeAll("<div class=\"tl-bar\">");
    try roleTabs(w, role, root);
    try w.writeAll(
        \\<input type="search" placeholder="Search champion" data-filter aria-label="Search champion"></div>
        \\<div class="tl-wrap"><table class="tl" data-sortable>
        \\<thead><tr><th class="rank">#</th><th class="l" data-sort="text">Champion</th>
    );
    if (role == null) try w.writeAll("<th class=\"l\" data-sort=\"text\">Role</th>");
    try w.writeAll(
        \\<th data-sort="num" aria-sort="descending">Win rate</th><th data-sort="num" title="The low end of the bar: the win rate is very likely at least this">At least</th><th data-sort="num" class="opt">Pick</th><th data-sort="num" class="opt">Ban</th><th data-sort="num">Games</th></tr></thead>
        \\<tbody>
        \\
    );
    var rare: usize = 0;
    var n: usize = 0;
    for (rows) |row| {
        if (row.rare) rare += 1 else n += 1;
        try w.print("<tr data-name=\"{f}\"{s}><td class=\"rank\">{d}</td><td class=\"l\">", .{
            esc(row.ch.name), if (row.rare) " data-rare hidden" else "", n,
        });
        try site.champLink(w, row.ch, try std.mem.concat(site.arena, u8, &.{ root, site.view.up() }));
        try w.writeAll("</td>");
        if (role == null) try w.print("<td class=\"l role\" data-v=\"{s}\">{s}</td>", .{ roleName(row.role), roleName(row.role) });
        try winRateCell(w, row.wins, row.games, 0.12);
        const lo = wilson(row.wins, row.games)[0];
        try w.print("<td class=\"dim\" data-v=\"{d:.4}\">{d:.1}%</td><td class=\"opt\" data-v=\"{d}\">", .{ lo, 100 * lo, row.games });
        try pct(w, row.games, site.games);
        try w.print("</td><td class=\"opt\" data-v=\"{d}\">", .{row.ch.banned});
        try pct(w, row.ch.banned, site.games);
        try w.print("</td><td class=\"dim\" data-v=\"{d}\">{d}</td></tr>\n", .{ row.games, row.games });
    }
    try w.writeAll("</tbody></table></div>\n");
    if (rare > 0) try w.print(
        "<p class=\"tl-more\">{d} rare picks (under {d:.1}% pick rate, or a role the champion seldom plays) hidden. <button class=\"link\" data-show-rare>Show them</button></p>\n",
        .{ rare, 100 * min_pick_rate },
    );
    try w.print("<script src=\"{s}{s}table.js\" defer></script>\n", .{ root, site.view.up() });
}

fn writeTierList(site: *const Site, w: *Writer, role: ?Role) !void {
    const a = site.arena;
    const name = if (role) |r| roleName(r) else "All";
    const title = if (role) |r|
        try a.print("{s} lane champions, {s} | meiolol", .{ roleName(r), site.when })
    else
        try a.print("Champions, {s} | meiolol", .{site.when});
    const desc = try a.print("{s} champions in ranked solo queue {s}, {s}: win rate with how sure it is, pick and ban rates.", .{ name, site.view.region.in(), site.when });
    const path = if (role) |r| try a.print("role/{s}.html", .{roleSlug(r)}) else "champions.html";
    const root = site.toRoot(path);
    const p = site.page(title, desc, path, .champions);
    try html.head(w, p);
    if (role) |r| {
        try w.print("<h1>{s} lane champions</h1>\n", .{roleName(r)});
    } else try w.writeAll("<h1>Champions</h1>\n");
    try w.print("<p class=\"muted\"><b>{d}</b> ranked solo/duo games {s}, {s}, all ranks.</p>\n", .{ site.games, site.view.region.in(), site.when });
    try earlyNote(site, w, false);
    try tierTable(site, w, role, root);
    try html.foot(w, p);
}

fn writeIndex(site: *const Site, w: *Writer) !void {
    const p = site.page(
        "meiolol: learn your lane",
        "How League of Legends lane matchups unfold minute by minute, from ranked games: gold, experience and CS curves per matchup and rank, a Daily Draft puzzle and champion statistics.",
        "index.html",
        .none,
    );
    try html.head(w, p);
    const matchups: usize = if (site.curves) |c| blk: {
        var n: usize = 0;
        for (c.curves) |cv| n += @intFromBool(cv.header.bracket == 0 and cv.header.experience == 0);
        break :blk n;
    } else 0;
    try html.tpl.render(w,
        \\<h1>Learn your lane</h1>
        \\<p class="lead">How lane matchups actually unfold, minute by minute, and how your
        \\own games compare. From ranked match timelines: the typical gold, experience and CS
        \\curve of every lane matchup by rank, with the spread and the number of games behind
        \\it. Champion and aggregate data only; never other players, never "the best pick".</p>
        \\
    , .{});
    if (site.curves) |*c| if (matchups > 0) try matchup.featured(site, w, c, matchups);
    try html.tpl.render(w,
        \\<div class="grid">
        \\<div class="card"><h3><a href="{your}">Your games</a></h3>
        \\<p>Enter your Riot ID and see each recent game's lane laid over the typical curve
        \\for that matchup at your rank, and your record per matchup over the months.
        \\<a href="{example}">See an example</a>.</p></div>
        \\<div class="card"><h3><a href="matchup/index.html">Matchup curves</a></h3>
        \\<p>{matchups}{no_matchups}</p></div>
        \\<div class="card"><h3><a href="{daily}">Daily Draft</a></h3>
        \\<p>One real ranked draft a day, anonymised. Guess the hidden champion and the
        \\winner, then see what happened and what the numbers say. Keep a streak, share
        \\your grid.</p></div>
        \\<div class="card"><h3><a href="{learn}">New to League? Start with Learn</a></h3>
        \\<p>Five short lessons on draft in plain words, with real examples, then practice on
        \\real ranked drafts with every option explained. No timers, no streaks.</p></div>
        \\<div class="card"><h3><a href="pool.html">Champion pool</a></h3>
        \\<p>Champions that players of your main also play, which of them cover your
        \\main's hardest lanes, and what they play when it is banned.</p></div>
        \\</div>
        \\
    , .{
        .your = html.Link{ .root = site.view.up(), .path = "your.html" },
        .example = html.Link{ .root = site.view.up(), .path = "your.html?example" },
        .daily = html.Link{ .root = site.view.up(), .path = "daily.html" },
        .learn = html.Link{ .root = site.view.up(), .path = "learn.html" },
        .matchups = if (matchups > 0) html.tpl.t(
            "{n} lane matchups so far: when each side tends to get ahead, by how much, and whether winning lane wins the game.",
            .{ .n = matchups },
        ) else null,
        .no_matchups = html.tpl.when(matchups == 0, @as([]const u8, "When each side of a lane matchup tends to get ahead, by how much, and whether winning lane wins the game. Curves appear as match timelines come in.")),
    });
    // The full table is champions.html: on this page it was 90% of the bytes
    try html.tpl.render(w,
        \\<h2>Champions</h2>
        \\<p><a href="champions.html">Win rate, pick and ban rate of every champion</a>, from
        \\<b>{games}</b> ranked solo/duo games {in}, {when}, all ranks.
        \\<a href="{method}">How the numbers are made</a>.</p>
        \\
    , .{
        .games = site.games,
        .in = site.view.region.in(),
        .when = site.when,
        .method = html.Link{ .root = site.view.up(), .path = "method.html" },
    });
    try html.foot(w, p);
}

const Opponent = struct {
    other: Champ,
    games: u32,
    wins: u32,
    iv: [2]f64,
};

/// One page per champion, from the root view (EUW, 30 days) at the site root; its
/// filters (filterBar) show the other views and any other region, rank or patch
fn writeChampion(site: *const Site, w: *Writer, ch: Champ) !void {
    const a = site.arena;
    const st = &site.stats;
    const title = try a.print("{s} win rate, lane opponents and curves | meiolol", .{ch.name});
    const desc = try a.print("{s} in ranked solo queue by region, rank and patch: win rate with how sure it is, every lane opponent and lane curves.", .{ch.name});
    const path = try a.print("champion/{s}.html", .{ch.slug});
    var p = site.sharedPage(title, desc, .champions);
    p.root = "../";
    p.counterparts = @as([html.View.count][]const u8, undefined);
    for (html.View.all, &p.counterparts.?) |v, *there| there.* = try std.mem.concat(a, u8, &.{ path, v.query() });
    p.canonical = site.canonical("", path);
    try html.head(w, p);

    var roles: [Role.count]Role = undefined;
    var n_roles: usize = 0;
    for (Role.all) |r| {
        const g = st.champRole(r, ch.c).games;
        if (g > 0 and @as(f64, @floatFromInt(g)) >= min_role_share * @as(f64, @floatFromInt(ch.games))) {
            roles[n_roles] = r;
            n_roles += 1;
        }
    }
    std.mem.sort(Role, roles[0..n_roles], RoleGames{ .st = st, .c = ch.c }, RoleGames.more);
    try w.print(
        "<div class=\"hero\"><img src=\"{s}\" alt=\"\" width=\"64\" height=\"64\"><div><h1>{f}</h1><p class=\"muted\">Ranked solo/duo <span data-scope>{s}, {s}, all ranks</span>.",
        .{ site.icon(ch), esc(ch.name), site.view.region.in(), site.when },
    );
    if (n_roles > 1) {
        try w.writeAll(" Plays ");
        for (roles[0..n_roles], 0..) |r, i| {
            if (i > 0) try w.writeAll(if (i + 1 == n_roles) " and " else ", ");
            try w.print("<a href=\"#{s}\">{s}</a>", .{ roleSlug(r), roleName(r) });
        }
        try w.writeAll(".");
    }
    try w.writeAll("</p></div></div>\n");
    try earlyNote(site, w, true);
    try filterBar(site, w, ch);
    if (n_roles == 0) try w.writeAll("<p>No games yet.</p>\n");

    for (roles[0..n_roles]) |r| {
        const cr = st.champRole(r, ch.c);
        const iv = wilson(cr.wins, cr.games);
        try w.print("<section id=\"{s}\"><h2>{s}</h2>\n<div class=\"tiles\">", .{ roleSlug(r), roleName(r) });
        try w.print("<div data-tile=\"wr\"><span>Win rate</span><b class=\"{s}\">", .{side(iv)});
        try pct(w, cr.wins, cr.games);
        try w.print("</b><small>{d:.1}% to {d:.1}%</small></div><div data-tile=\"pick\"><span>Pick rate</span><b>", .{ 100 * iv[0], 100 * iv[1] });
        try pct(w, cr.games, site.games);
        try w.writeAll("</b><small>of games</small></div><div data-tile=\"ban\"><span>Ban rate</span><b>");
        try pct(w, ch.banned, site.games);
        try w.print("</b><small>of games</small></div><div data-tile=\"games\"><span>Games</span><b>{d}</b><small>{s} lane</small></div></div>\n", .{ cr.games, roleName(r) });

        var opps: std.ArrayList(Opponent) = .empty;
        for (site.champs) |other| {
            if (other.c == ch.c) continue;
            const e = st.enemy(r, r, ch.c, other.c);
            if (e.games == 0) continue;
            try opps.append(a, .{ .other = other, .games = e.games, .wins = e.wins, .iv = wilson(e.wins, e.games) });
        }
        try builds_page.link(site, w, ch, r, path);
        try opponentTable(site, w, ch, r, opps.items);
        try w.writeAll("</section>\n");
    }
    try pool_page.section(site, w, &site.pool, ch);
    try learning_page.section(w, &site.learning, ch);
    try w.print("<p class=\"muted small\">Win rates are raw: no pulling toward 50%. Bars are 95% Wilson intervals. Gold at {d} min is the lane curve's estimate (± two standard errors); for filters other than a region and period above, the plain average of the games picked. <a href=\"../method.html\">Method</a>.</p>\n", .{core.curvesfile.lane_minute});
    try w.writeAll("<script src=\"../table.js\" defer></script>\n<script src=\"../filters.js\" defer></script>\n");
    try html.foot(w, p);
}

/// Filter bar (filters.zig, static/filters.js), set to the page as written (the root
/// view); disabled until the script has the champion's filter data
fn filterBar(site: *const Site, w: *Writer, ch: Champ) !void {
    const f = site.filter;
    const region = site.opts.platforms[0];
    try w.print(
        "<div class=\"filter-bar\" data-src=\"../data/filters/{s}.json\" data-meta=\"../data/filters.json\" data-champions=\"../data/champions.json\" data-ddragon=\"{s}\" data-id=\"{d}\" data-region=\"{s}\" data-current=\"{s}\">",
        .{ ch.slug, site.ddragon_version, ch.id, region, site.patch },
    );
    try w.writeAll("<label>Region <select data-f=\"region\" disabled><option value=\"all\">All regions</option>");
    for (site.opts.all_platforms) |pl| {
        try w.print("<option value=\"{s}\"{s}>{s}</option>", .{ pl, selected(std.mem.eql(u8, pl, region)), platformName(pl) });
    }
    try w.writeAll("</select></label>\n<label>Rank <select data-f=\"rank\" disabled><option value=\"\" selected>All ranks</option>");
    for (filters.tiers, 0..) |t, i| {
        try w.print("<option value=\"{d}\">{c}{s}+</option>", .{ i, t[0], try std.ascii.allocLowerString(site.arena, t[1..]) });
    }
    try w.writeAll("</select></label>\n<label>Period <select data-f=\"period\" disabled><option value=\"days30\" selected>Last 30 days</option>");
    for (f.patches) |pa| {
        const current = for (f.current) |c| {
            if (std.mem.eql(u8, c, pa)) break true;
        } else false;
        try w.print("<option value=\"patch:{s}\">Patch {s}{s}</option>", .{ pa, pa, if (current) "" else " (last 30 days)" });
    }
    try w.writeAll("</select></label>\n<label>Opponents <select data-f=\"min\" disabled>");
    const mins = [_][2][]const u8{
        .{ "0", "All" },        .{ "5", "5+ games" },     .{ "10", "10+ games" },            .{ "20", "20+ games" },
        .{ "50", "50+ games" }, .{ "100", "100+ games" }, .{ "p1", "Seen in 1%+ of games" }, .{ "p2", "Seen in 2%+ of games" },
    };
    for (mins, 0..) |m, i| try w.print("<option value=\"{s}\"{s}>{s}</option>", .{ m[0], selected(i == 0), m[1] });
    try w.writeAll("</select></label>\n<button class=\"link\" data-reset hidden>Reset</button></div>\n");
}

fn selected(yes: bool) []const u8 {
    return if (yes) " selected" else "";
}

/// "EUW1" -> "EUW", "EUN1" -> "EUNE", as static/filters.js platformName
fn platformName(p: []const u8) []const u8 {
    const names = [_][2][]const u8{ .{ "EUN1", "EUNE" }, .{ "LA1", "LAN" }, .{ "LA2", "LAS" }, .{ "OC1", "OCE" } };
    for (names) |n| if (std.mem.eql(u8, n[0], p)) return n[1];
    return std.mem.trimEnd(u8, p, "0123456789");
}

/// Every lane opponent: win rate with its interval and the lane curve's gold difference at
/// lane_minute, linking to the matchup page. Hardest first; under min_opponent_games faded
/// and last, by games, so a few lucky games don't top the list
fn opponentTable(site: *const Site, w: *Writer, ch: Champ, r: Role, opps: []Opponent) !void {
    if (opps.len == 0) return;
    std.mem.sort(Opponent, opps, {}, struct {
        fn f(_: void, x: Opponent, y: Opponent) bool {
            const x_thin = x.games < min_opponent_games;
            const y_thin = y.games < min_opponent_games;
            if (x_thin != y_thin) return y_thin;
            if (x_thin) return x.games > y.games;
            // The interval's top end: hard even at best, so a few games can't top it
            return x.iv[1] < y.iv[1];
        }
    }.f);
    try w.print(
        \\<div class="tl-bar"><h3 class="opp-h">Lane opponents <span class="muted">{d}, hardest first, by the top of each bar</span></h3>
        \\<input type="search" placeholder="Search opponent" data-filter aria-label="Search opponent"></div>
        \\<div class="tl-wrap"><table class="tl" data-sortable>
        \\<thead><tr><th class="l" data-sort="text">Opponent</th><th data-sort="num">{f}'s win rate</th><th data-sort="num" title="Lane curve estimate: {f} minus the opponent">Gold at {d}</th><th data-sort="num">Games</th></tr></thead>
        \\<tbody>
        \\
    , .{ opps.len, esc(ch.name), esc(ch.name), core.curvesfile.lane_minute });
    var few: usize = 0;
    for (opps) |o| {
        const thin = o.games < min_opponent_games;
        if (thin) few += 1;
        try w.print("<tr data-id=\"{d}\" data-name=\"{f}\"{s}><td class=\"l\">", .{ o.other.id, esc(o.other.name), if (thin) " class=\"thin\"" else "" });
        try site.champLink(w, o.other, "../");
        try w.writeAll("</td>");
        try winRateCell(w, o.wins, o.games, 0.25);
        try goldCell(site, w, ch, o.other, r);
        try w.print("<td class=\"dim\" data-v=\"{d}\">{d}</td></tr>\n", .{ o.games, o.games });
    }
    try w.writeAll("</tbody></table></div>\n");
    if (few > 0) try w.print(
        "<p class=\"tl-more\">Faded: the last {d} opponents, under {d} games each, too few to read much into.</p>\n",
        .{ few, min_opponent_games },
    );
}

fn goldCell(site: *const Site, w: *Writer, ch: Champ, other: Champ, r: Role) !void {
    const curves = if (site.curves) |*c| c else return w.writeAll("<td class=\"dim\" data-v=\"\"></td>");
    const v = curves.get(r, .all, ch.id, other.id) orelse return w.writeAll("<td class=\"dim\" data-v=\"\"></td>");
    const e = v.estimate(.gold, core.curvesfile.lane_minute - 1);
    const margin = 2 * @as(i32, e.se);
    const s = if (e.mean > margin) "up" else if (e.mean < -margin) "down" else "even";
    const x, const y = if (ch.id < other.id) .{ ch, other } else .{ other, ch };
    try w.print("<td data-v=\"{d}\"><a class=\"gold {s}\" href=\"../{s}\" title=\"Lane curves\">{s}{d}</a><small>±{d}</small></td>", .{
        e.mean, s, try matchup.path(site.arena, r, x, y), if (e.mean > 0) "+" else "", e.mean, margin,
    });
}

const RoleGames = struct {
    st: *const Stats,
    c: usize,
    fn more(ctx: RoleGames, a: Role, b: Role) bool {
        return ctx.st.champRole(a, ctx.c).games > ctx.st.champRole(b, ctx.c).games;
    }
};

test "slug" {
    const a = std.testing.allocator;
    const cases = [_][2][]const u8{
        .{ "Kai'Sa", "kaisa" },
        .{ "Nunu & Willump", "nunu-willump" },
        .{ "Dr. Mundo", "dr-mundo" },
        .{ "Lee Sin", "lee-sin" },
    };
    for (cases) |c| {
        const s = try slug(a, c[0]);
        defer a.free(s);
        try std.testing.expectEqualStrings(c[1], s);
    }
}

test "views: a tree each, switches between them, shared pages once" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const db = try store.schema.memory();
    defer db.close();
    try db.exec(
        \\INSERT INTO champions VALUES
        \\  (1,'A','A','',''), (2,'B','B','',''), (3,'C','C','',''), (4,'D','D','',''),
        \\  (5,'E','E','',''), (6,'F','F','',''), (7,'G','G','',''), (8,'H','H','',''),
        \\  (9,'I','I','',''), (10,'J','J','','');
    );
    const day = std.time.ms_per_day;
    const now = 100 * day;
    // EUW: one recent game and two older ones, one on the current patch; KR: one recent
    const games = [_]struct { []const u8, []const u8, i64 }{
        .{ "EUW1_1", "16.20", now }, .{ "EUW1_2", "16.20", 0 }, .{ "EUW1_3", "16.19", 0 },
        .{ "KR_1", "16.20", now },
    };
    const positions = [5][]const u8{ "TOP", "JUNGLE", "MIDDLE", "BOTTOM", "UTILITY" };
    for (games) |g| {
        const platform = g[0][0..std.mem.indexOfScalar(u8, g[0], '_').?];
        try db.run("INSERT INTO matches VALUES (?,'t',?,420,?,'',?,1800,100,0)", .{ g[0], platform, g[1], g[2] });
        for (0..10) |slot| try db.run(
            "INSERT INTO participants (match_id, slot, team_id, champion_id, position, win) VALUES (?,?,?,?,?,?)",
            .{ g[0], slot, @as(i64, if (slot < 5) 100 else 200), slot + 1, positions[slot % 5], slot < 5 },
        );
    }

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const out = try arena.print(".zig-cache/tmp/{s}/site", .{&tmp.sub_path});
    try generate(gpa, io, db, .{
        .out_dir = out,
        .patches = &.{"16.20"},
        .since_ms = now - 30 * day,
        .all_platforms = &.{ "EUW1", "KR" },
        .contact = "x@example.com",
        .updated = "1 January 2026",
    });
    const read = struct {
        fn f(a: std.mem.Allocator, dir: []const u8, path: []const u8) ![]const u8 {
            const full = try std.fs.path.join(a, &.{ dir, path });
            return std.Io.Dir.cwd().readFileAlloc(std.testing.io, full, a, .limited(1 << 20));
        }
    }.f;
    const want = [_]struct { []const u8, []const u8 }{
        .{ "role/top.html", "in EUW, last 30 days, 1 games" },
        .{ "patch/role/top.html", "in EUW, patch 16.20, 2 games" },
        .{ "all/role/top.html", "across all regions, last 30 days, 2 games" },
        .{ "all/patch/role/top.html", "across all regions, patch 16.20, 3 games" },
        .{ "daily.html", "in EUW, patch 16.20, 2 games" },
    };
    for (want) |c| {
        const page = try read(arena, out, c[0]);
        try std.testing.expect(std.mem.indexOf(u8, page, c[1]) != null);
    }
    const tiers = try read(arena, out, "all/champions.html");
    for ([_][]const u8{
        "<a href=\"../all/patch/champions.html\" data-period=\"patch\">Patch 16.20</a>",
        "<a href=\"../champions.html\" data-region=\"euw\">EUW</a>",
        "href=\"../style.css\"",
        "href=\"../daily.html\"",
        "href=\"../champion/a.html?region=all\"",
    }) |s| try std.testing.expect(std.mem.indexOf(u8, tiers, s) != null);
    // One page per champion, at the site root: its switches set the filters
    const champ = try read(arena, out, "champion/a.html");
    for ([_][]const u8{
        "<a href=\"../champion/a.html?period=patch\" data-period=\"patch\">Patch 16.20</a>",
        "<a aria-current=\"page\" data-region=\"euw\">EUW</a>",
        "href=\"../style.css\"",
        "<a href=\"../champions.html\" aria-current=\"page\" data-view>",
    }) |s| try std.testing.expect(std.mem.indexOf(u8, champ, s) != null);
    try std.testing.expectError(error.FileNotFound, read(arena, out, "all/champion/a.html"));
    const shared_page = try read(arena, out, "daily.html");
    try std.testing.expect(std.mem.indexOf(u8, shared_page, "<a href=\"champions.html\" data-view>") != null);
    try std.testing.expectError(error.FileNotFound, read(arena, out, "all/daily.html"));
    try std.testing.expectError(error.FileNotFound, read(arena, out, "patch/style.css"));
}
