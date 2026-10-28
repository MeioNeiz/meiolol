//! `meiolol site`: the public stats website as static files (HTML, CSS, the model
//! file and champion JSON for the browser pages). Host anywhere static.

const std = @import("std");
const core = @import("core");
pub const html = @import("html.zig");
const urls = ui.urls;
const prose = @import("prose.zig");
const account_page = @import("account.zig");
const daily_page = @import("daily.zig");
const your_page = @import("your.zig");
const yourgame = @import("yourgame.zig");
const yourpage = @import("yourpage.zig");
const daily = @import("../daily.zig");
const learn = @import("../learn.zig");
const learn_page = @import("learn.zig");
const matchup = @import("matchup.zig");
const finder = @import("finder.zig");
const pool_page = @import("pool.zig");
const pickup_page = @import("pickup.zig");
const pool = @import("../pool.zig");
const learning = @import("../learning.zig");
const spread = @import("../spread.zig");
pub const builds_page = @import("builds.zig");
const builds = @import("../builds.zig");
const lean = @import("../lean.zig");
const filters = @import("filters.zig");
const evalchart = @import("evalchart.zig");
const flat = @import("flat.zig");
const style = @import("style.zig");
pub const assets = @import("assets.zig");
pub const gallery = @import("gallery.zig");
pub const notes = @import("notes.zig");
pub const ui = @import("ui");
const patchday = @import("../patchday.zig");
const patchnotes = @import("../patchnotes.zig");
const patch_page = @import("patch.zig");
const stats = @import("../stats.zig");
pub const scope = @import("scope.zig");

const Writer = std.Io.Writer;
const Stats = core.Stats;
const Role = core.Role;
const tpl = html.tpl;
const score = core.score;

pub const generate = @import("write.zig").generate;
const biggestCurves = @import("extras.zig").biggestCurves;
pub const Loaded = @import("views.zig").Loaded;
const writeIndex = @import("home.zig").writeIndex;
const writeTierList = @import("tierlist.zig").writeTierList;
const champion = @import("champion.zig");
const writeChampion = champion.writeChampion;

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
    /// The patch before Options.patches (one patch) and its curves files, by view as
    /// `curves`, the patch views' set: patch.html, the champion pages' line per role and
    /// the matchup charts' dashed line
    prev_patch: ?[]const u8 = null,
    curves_prev: [html.View.count]?[]const u8 = @splat(null),
    /// Older patch pairs {cur, prev} below prev_patch's, newest first (main.olderPairs):
    /// patches/<cur>-<prev>.html in the 30-day views, win rates only
    older_pairs: []const [2][]const u8 = &.{},
    /// Data Dragon's files by version (patchnotes.load): patch.html's Riot changes
    ddragon_dir: ?[]const u8 = null,
    /// Builds file per view (`meiolol builds`): build pages in the patch views where set
    builds: [html.View.count]?[]const u8 = @splat(null),
    /// The previous patch's builds files, by view as `builds`: the champion and matchup
    /// pages' build strips while the current patch has few games of a pick (builds.zig
    /// pick)
    builds_prev: [html.View.count]?[]const u8 = @splat(null),
    /// The rank filter's builds files, by view as `builds`, then builds.rank_tiers
    builds_rank: [html.View.count][builds.rank_tiers.len]?[]const u8 = @splat(@splat(null)),
    /// Only the EUW views (the root and patch/; the shared pages come from patch/): a
    /// quick preview, links into all/ dangle
    euw_only: bool = false,
    /// Front-end files (css, js) read from here per request instead of embedded: `meiolol
    /// dev`
    static_dir: ?[]const u8 = null,
    /// What the static build writes; `meiolol render` serves the rest on request
    static: Static = .all,
    /// Matchup pages with fewer games are left out of the static build (Static.all)
    static_min_games: u32 = 0,
    /// "https://meio.lol": canonical links and sitemaps, when public
    origin: ?[]const u8 = null,
    /// Matchup pages with fewer games are noindex and left out of the sitemaps
    index_min_games: u32 = 0,
    /// The daily eval's TSV (`meiolol eval --history`) for the method page's chart
    eval_history: ?[]const u8 = null,
    /// `meiolol lean`'s file: the champion pages' early or late line where set
    lean: ?[]const u8 = null,
    /// `meiolol your-example`'s file, served as data/your-example.json where it exists
    your_example: ?[]const u8 = null,
    /// Contiguous runs of the games filters.zig counts at once, each on its own
    /// connection: the walk waits on the disk (cold B-tree pages one at a time), not the
    /// CPUs. MEIOLOL_FILTER_RUNS (host.env) sets it per host
    filter_runs: usize = 4,
    /// Views loaded at once, each on its own connection (load.loadAtOnce: the views write
    /// and the static build): each view's stats take one CPU for minutes. 1, one after
    /// another, suits a 2-CPU host. MEIOLOL_VIEW_LOADS (host.env) sets it per host
    view_loads: usize = 1,
};

pub const Static = enum {
    /// Every page and file (but thin matchups: Options.static_min_games)
    all,
    /// core_static only
    core,
};

/// `--static core`: the only files the static build writes, besides the front-end assets
/// (shared_assets), none from the data, so it loads no view; nginx serves them itself and
/// hands every other path, the home too, to `meiolol render`. All at the site root:
/// nginx's try_files answers the URL of a directory that exists with its index.html or
/// 403, never the renderer, so no subdirectory is written
pub const core_static = [_][]const u8{ "robots.txt", "riot.txt", "meiolol.wasm", "chart.wasm" };

/// The core_static files, from the options alone
pub fn coreFiles(arena: std.mem.Allocator, opts: Options) ![]const File {
    var files: std.ArrayList(File) = .empty;
    try files.append(arena, .{ .path = "meiolol.wasm", .data = @embedFile("draft.wasm") });
    try files.append(arena, .{ .path = "chart.wasm", .data = @embedFile("chart.wasm") });
    if (opts.riot_txt) |t| try files.append(arena, .{ .path = "riot.txt", .data = t });
    try files.append(arena, .{ .path = "robots.txt", .data = try robots(arena, opts) });
    return files.items;
}

/// Whether the static build writes the file at `dir` ++ `path` from the site root
pub fn isStatic(opts: Options, dir: []const u8, path: []const u8) bool {
    if (opts.static == .all) return true;
    if (dir.len > 0 or std.mem.findScalar(u8, path, '/') != null) return false;
    for (core_static) |name| if (std.mem.eql(u8, name, path)) return true;
    for (shared_assets) |f| if (std.mem.eql(u8, f.path, path)) return true;
    for (hashed_assets) |h| if (std.mem.eql(u8, h.path, path)) return true;
    return false;
}

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

/// A view's players' win rates, learning and pool, as its own load makes them
pub const ByView = struct {
    spread: spread.Spread,
    learning: learning.Learning,
    pool: pool.Pool,
};

/// An older patch pair's page (Site.older)
pub const Older = struct {
    pd: patchday.PatchDay,
    notes: ?*const patchnotes.Notes = null,
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
    /// The view's games in running text: "last 30 days, patches 16.19 to 16.21", "patch
    /// 16.20"
    when: []const u8,
    /// A 30-day view's games by patch: "16.19 9%, 16.20 88%, 16.21 3%"; "" for one patch
    patch_mix: []const u8 = "",
    ddragon_version: []const u8,
    /// The view being written; opts.platforms and opts.patches are its own
    view: html.View,
    /// Games started from (Unix ms; 0 for any)
    since_ms: i64,
    opts: Options,
    score_opts: score.Options = .{},
    curves: ?core.curvesfile.Curves = null,
    /// The previous patch's, in the patch views (Options.curves_prev)
    curves_prev: ?core.curvesfile.Curves = null,
    /// The view's region, current patch against the previous one (Options.prev_patch)
    patchday: ?patchday.PatchDay = null,
    /// The root view's only, for the champion pages: every region's
    patchday_all: ?patchday.PatchDay = null,
    /// What Riot changed between the patch day's patches (Options.ddragon_dir)
    notes: ?*const patchnotes.Notes = null,
    /// The 30-day views' only: Options.older_pairs' patch days, each with no curves
    older: []const Older = &.{},
    /// Every view's (html.View.index), so the switches skip matchups without a page
    view_curves: *const [html.View.count]?core.curvesfile.Curves,
    /// Every view's builds (html.View.index); the 30-day views link to their patch view's
    view_builds: *const [html.View.count]?builds.File,
    /// The previous patch's (Options.builds_prev)
    view_builds_prev: *const [html.View.count]?builds.File,
    /// The rank filter's (Options.builds_rank)
    view_builds_rank: *const [html.View.count][builds.rank_tiers.len]?builds.File,
    /// One file for every view: its scope is its own, every region
    lean: ?*const lean.File = null,
    /// Win rates by game length and by patch (stats.Trend); null in a core static build
    trend: ?stats.Trend = null,
    pool: pool.Pool = .{},
    learning: learning.Learning = .{},
    spread: spread.Spread = .{},
    /// The root view's only, for the champion pages: every view's (html.View.index)
    by_view: []const ByView = &.{},
    /// Data and script files in the view's directory
    files: []const File = &.{},
    /// The shared view's files at the site root (Daily Draft, Learn)
    shared_files: []const File = &.{},
    /// Of shared_files, those the shared view's load makes (Daily Draft, your example,
    /// Learn); the rest come from the binary and options
    daily_files: []const File = &.{},
    /// What daily_files were made from (load.dailyInputs)
    daily_inputs: u64 = 0,
    /// The view's stats file (stats_path), as stats was parsed from
    model: []const u8 = "",
    /// Learn page facts; the shared view's only
    learn: ?learn.Facts = null,
    /// The method page's accuracy chart (Options.eval_history)
    eval: []const evalchart.Point = &.{},
    /// Champion page filter data; the root view's only, as the champion pages
    filter: filters.Made = .{},

    /// The view's page `at`
    pub fn page(s: *const Site, title: []const u8, description: []const u8, at: urls.Page, nav: html.Nav) !html.Page {
        var p = try s.sharedPage(title, description, nav);
        p.view = s.view;
        p.counterparts = @as([html.View.count][]const u8, undefined);
        for (html.View.all, &p.counterparts.?) |v, *there| {
            there.* = try s.arena.print("{f}{s}", .{ at, v.query() });
        }
        p.canonical = try s.canonical(at);
        return p;
    }

    /// `at` under Options.origin, no query: every view's copy files under one URL; null
    /// without an origin
    pub fn canonical(s: *const Site, at: urls.Page) !?[]const u8 {
        const origin = s.opts.origin orelse return null;
        return try s.arena.print("{s}{f}", .{ origin, at });
    }

    /// To the page `to` in this view. Raw: escape it
    pub fn href(s: *const Site, to: urls.Page) ![]const u8 {
        return s.arena.print("{f}{s}", .{ to, s.view.query() });
    }

    /// A page at the site root, written once (from html.View.shared)
    pub fn sharedPage(s: *const Site, title: []const u8, description: []const u8, nav: html.Nav) !html.Page {
        return .{
            .title = title,
            .description = description,
            .nav = nav,
            .patch = s.patch,
            .regions = s.opts.all_platforms,
            .home = s.opts.platforms[0],
            .data = try s.arena.print("{s}, {s}, {f} games{s}", .{
                s.view.region.in(),
                s.when,
                Thousands{ .n = s.games },
                if (s.patch_mix.len > 0) try s.arena.print(" ({s})", .{s.patch_mix}) else "",
            }),
            .public = s.opts.public,
        };
    }

    /// `when` short, for titles: "last 30 days", "patch 16.20"
    pub fn period(s: *const Site) []const u8 {
        return switch (s.view.period) {
            .days30 => "last 30 days",
            .patch => s.when,
        };
    }

    /// Period `p`'s games in running text: "last 30 days", "patch 16.21"
    pub fn periodText(s: *const Site, p: html.Period) []const u8 {
        return switch (p) {
            .days30 => "last 30 days",
            .patch => s.arena.print("patch {s}", .{s.patch}) catch s.patch,
        };
    }

    /// Scope chip dimensions in this site's words: EUW is opts' home platform
    pub fn regionDim(s: *const Site, r: html.Region) scope.Dim {
        return .region(r, s.opts.platforms[0]);
    }

    pub fn periodDim(s: *const Site, p: html.Period) scope.Dim {
        return switch (p) {
            .days30 => .days30,
            .patch => scope.Dim.patch(s.arena, s.patch) catch .{ .key = "patch", .text = s.patch },
        };
    }

    /// A block's scope chip, marked against this view's picks
    pub fn chip(s: *const Site, where: scope.Dim, when: scope.Dim, rank: scope.Dim) scope.Chip {
        return .{ .region = where, .period = when, .rank = rank, .picks = .{
            .region = s.regionDim(s.view.region),
            .period = s.periodDim(s.view.period),
        } };
    }

    pub fn icon(s: *const Site, ch: Champ) ![]const u8 {
        return s.arena.print(ui.champ.icon_fmt, .{ s.ddragon_version, ch.key });
    }

    /// To the champion's page (main role; one per champion and role, in the default
    /// view), its filters set to this view. Raw: escape it
    pub fn champHref(s: *const Site, ch: Champ) ![]const u8 {
        return s.href(.{ .champion = .{ .slug = ch.slug } });
    }

    /// To the champions table, a role's (null: All)
    pub fn championsHref(s: *const Site, r: ?Role) ![]const u8 {
        return s.href(.{ .champions = if (r) |x| urlRole(x) else null });
    }

    /// A champion link as the main link of a row or tile (class bx) that it covers whole
    pub fn champBox(s: *const Site, w: *Writer, ch: Champ) !void {
        try tpl.render(w, "<a class=\"champ box\" href=\"{href}\"><img src=\"{icon}\" alt=\"\" loading=\"lazy\" width=\"32\" height=\"32\">{name}</a>", .{
            .href = try s.champHref(ch),
            .icon = try s.icon(ch),
            .name = ch.name,
        });
    }

    pub fn champBySlug(s: *const Site, slug_: []const u8) ?Champ {
        return s.champs[s.by_slug.get(slug_) orelse return null];
    }

    fn info(s: *const Site) prose.Info {
        return .{ .contact = s.opts.contact, .updated = s.opts.updated, .curves = biggestCurves(s.view_curves), .patch = s.patch };
    }
};

pub const File = daily.File;

/// Also written by their plain names, with the same data (assets.zig)
pub const hashed_assets = [_]assets.Hashed{ style.file, style.font, assets.search_js, assets.stats_js, assets.stats_wasm, assets.champion_js, assets.champion_wasm, assets.champbuild_js, assets.champbuild_wasm, assets.champmore_js, assets.champmore_wasm, assets.matchup_js, assets.matchup_wasm, assets.matchmore_js, assets.matchmore_wasm, assets.games_js, assets.games_wasm, assets.gamemore_js, assets.gamemore_wasm, assets.gamelane_js, assets.gamelane_wasm, assets.finder_js, assets.finder_wasm, assets.findergrid_js, assets.findergrid_wasm, assets.learn_js, assets.learn_wasm, assets.patch_js, assets.patch_wasm, assets.pool_js, assets.pool_wasm, assets.poolgrid_js, assets.poolgrid_wasm, assets.daily_js, assets.daily_wasm, assets.dailydays_js, assets.dailydays_wasm, assets.home_js, assets.home_wasm, assets.homegame_js, assets.homegame_wasm, assets.your_js, assets.your_wasm, assets.yourviews_js, assets.yourviews_wasm, assets.yourtime_js, assets.yourtime_wasm, assets.yourlookup_js, assets.yourlookup_wasm };

/// Front-end files at the site root; `Options.static_dir` serves them from disk instead
pub const shared_assets = [_]File{
    .{ .path = "favicon.svg", .data = @embedFile("static/favicon.svg") },
    .{ .path = "your.js", .data = @embedFile("static/your.js") },
    .{ .path = "review.js", .data = @embedFile("static/review.js") },
    .{ .path = "table.js", .data = @embedFile("static/table.js") },
    .{ .path = "account.js", .data = @embedFile("static/account.js") },
    // Linked for print, so it never holds up rendering; browsers still fetch it on each load
    .{ .path = "print.css", .data = @embedFile("static/print.css") },
};

/// Asset `wanted` (a hashed name as its plain one) from Options.static_dir when set (edits
/// show without a rebuild), else as embedded; null for anything else
pub fn asset(arena: std.mem.Allocator, io: std.Io, opts: Options, wanted: []const u8) !?[]const u8 {
    const name: []const u8, const embedded: []const u8 = for (hashed_assets) |h| {
        if (std.mem.eql(u8, h.path, wanted)) break .{ h.plain, h.data };
    } else for (shared_assets) |f| {
        if (std.mem.eql(u8, f.path, wanted)) break .{ f.path, f.data };
    } else return null;
    const dir = opts.static_dir orelse return embedded;
    if (std.mem.startsWith(u8, name, "ui-")) return embedded;
    const path = try std.fs.path.join(arena, &.{ dir, name });
    const data = try std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 24));
    return if (std.mem.eql(u8, name, "style.css")) try style.rebuild(arena, data) else data;
}

/// Pages in no view, from the shared view (renderShared)
pub const shared_pages = [_]urls.Page{ .learn, .method, .{ .daily = null }, .download, .your, .privacy, .terms };

/// Shared pages the static build writes but the sitemap leaves out
pub const unlisted_pages = [_]urls.Page{ .game, .games };

/// `at`'s file in view `v`'s tree, from the site root: "_v/all/champions/top.html"
/// (nginx: $uri.html), "index.html" for home
pub fn filePath(a: std.mem.Allocator, v: html.View, at: urls.Page) ![]const u8 {
    const url = try a.print("{f}", .{at});
    return std.mem.concat(a, u8, &.{ v.dir(), if (at == .home) "index" else url[1..], ".html" });
}

/// The page whose file is `path` within a view's tree (filePath's inverse); null: none
pub fn pageOf(a: std.mem.Allocator, path: []const u8) !?urls.Page {
    if (!std.mem.endsWith(u8, path, ".html")) return null;
    const name = path[0 .. path.len - ".html".len];
    if (std.mem.eql(u8, name, "index")) return .home;
    return urls.parse(try std.mem.concat(a, u8, &.{ "/", name }));
}

/// The URL that serves file `path` (from the site root): a page's with its view's query,
/// any other file's path
pub fn urlOf(a: std.mem.Allocator, path: []const u8) ![]const u8 {
    const v = for ([_]html.View{ html.View.all[3], html.View.all[2], html.View.all[1] }) |v| {
        if (std.mem.startsWith(u8, path, v.dir())) break v;
    } else html.View.all[0];
    const rest = path[v.dir().len..];
    const at = try pageOf(a, rest) orelse return std.mem.concat(a, u8, &.{ "/", path });
    return a.print("{f}{s}", .{ at, v.query() });
}

test urlOf {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try std.testing.expectEqualStrings("/", try urlOf(a, "index.html"));
    try std.testing.expectEqualStrings("/?region=all", try urlOf(a, "_v/all/index.html"));
    try std.testing.expectEqualStrings("/champions/top?region=all&period=patch", try urlOf(a, "_v/all-patch/champions/top.html"));
    try std.testing.expectEqualStrings("/patch/16-20?period=patch", try urlOf(a, "_v/patch/patch/16-20.html"));
    try std.testing.expectEqualStrings("/_v/all/data/tiers.bin", try urlOf(a, "_v/all/data/tiers.bin"));
}

/// `r` as URLs spell it
pub fn urlRole(r: Role) ui.role.Role {
    return @import("champion.zig").uiRole(r);
}

pub fn coreRole(r: ui.role.Role) Role {
    return switch (r) {
        .top => .top,
        .jungle => .jungle,
        .mid => .middle,
        .bot => .bottom,
        .support => .utility,
    };
}

pub fn robots(arena: std.mem.Allocator, opts: Options) ![]const u8 {
    if (!opts.public) return "User-agent: *\nDisallow: /\n";
    var out: std.ArrayList(u8) = .empty;
    // Your games answers name players (docs/legal/lia.md safeguards): never crawled. /p/:
    // the private site, behind a login
    try out.appendSlice(arena, "User-agent: *\nAllow: /\nDisallow: /api/\nDisallow: /p/\n");
    if (opts.origin) |origin| try out.print(arena, "Sitemap: {s}/sitemap.xml\n", .{origin});
    return out.items;
}

test {
    _ = style;
    _ = patch_page;
    _ = gallery;
    _ = evalchart;
    _ = flat;
    _ = yourgame;
    _ = yourpage;
    _ = scope;
    _ = @import("dailydata.zig");
    _ = @import("daily.zig");
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
        "User-agent: *\nAllow: /\nDisallow: /api/\nDisallow: /p/\nSitemap: https://x.io/sitemap.xml\n",
        try robots(arena.allocator(), public),
    );
}

/// The pages search engines may index, by canonical URL (no view's query: each view's
/// copy files under it), with the data's date; the root view's
pub fn sitemap(site: *const Site) ![]const u8 {
    const a = site.arena;
    var out: std.ArrayList(u8) = .empty;
    try out.appendSlice(a, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n");
    var pages: std.ArrayList(urls.Page) = .empty;
    try pages.appendSlice(a, try pagePathsMin(site, site.opts.index_min_games));
    // Listed from the root view, before the shared view (whose learn build may fail) loads
    try pages.appendSlice(a, &shared_pages);
    const day = @import("../date.zig").Date.fromMs(site.since_ms + 30 * std.time.ms_per_day);
    for (pages.items) |at| {
        // The main role's page files under the bare champion URL
        if (at == .champion and at.champion.role != null and site.champBySlug(at.champion.slug) != null and
            mainRole(site, site.champBySlug(at.champion.slug).?) == coreRole(at.champion.role.?)) continue;
        // Slugs and fixed names: nothing XML needs escaped
        try out.print(a, "<url><loc>{s}</loc><lastmod>{f}</lastmod></url>\n", .{ (try site.canonical(at)).?, day });
    }
    try out.appendSlice(a, "</urlset>\n");
    return out.items;
}

/// Every page of the view the static build writes
pub fn pagePaths(site: *const Site) ![]const urls.Page {
    return pagePathsMin(site, site.opts.static_min_games);
}

/// The role a champion's bare URL shows: its most played
pub fn mainRole(site: *const Site, ch: Champ) ?Role {
    var best: ?Role = null;
    var most: u64 = 0;
    for (Role.all) |r| {
        const g = site.stats.champRole(r, ch.c).games;
        if (g > most) {
            best = r;
            most = g;
        }
    }
    return best;
}

/// As pagePaths, but matchup pages from `min_games` up
fn pagePathsMin(site: *const Site, min_games: u32) ![]const urls.Page {
    const a = site.arena;
    var list: std.ArrayList(urls.Page) = .empty;
    try list.appendSlice(a, &.{ .home, .{ .champions = null } });
    for (ui.role.Role.all) |r| try list.append(a, .{ .champions = r });
    // Champion pages in the default view only: their filters pick the view
    if (site.view.index() == 0) for (site.champs) |ch| {
        try list.append(a, .{ .champion = .{ .slug = ch.slug } });
        for (Role.all) |r| if (champion.plays(site, ch, r)) try list.append(a, .{ .champion = .{ .slug = ch.slug, .role = urlRole(r) } });
    };
    try list.append(a, .matchups);
    if (site.curves) |*c| try matchup.paths(site, c, &list, min_games);
    try list.append(a, .pool);
    try pickup_page.paths(site, &list);
    try list.append(a, .{ .patch = null });
    try patch_page.paths(site, &list);
    return list.items;
}

/// The view's page `at` into `w`; false when it has none
pub fn renderPage(site: *const Site, w: *Writer, at: urls.Page) !bool {
    switch (at) {
        .home => try writeIndex(site, w),
        .champions => |r| try writeTierList(site, w, if (r) |x| coreRole(x) else null),
        .champion => |c| {
            if (site.view.index() != 0) return false;
            const ch = site.champBySlug(c.slug) orelse return false;
            const main = mainRole(site, ch) orelse return false;
            const r = if (c.role) |x| coreRole(x) else main;
            // A thin role has no file (not in pagePaths) but tier rows and role tabs link
            // it: rendered on request, canonical to the bare URL
            if (site.stats.champRole(r, ch.c).games == 0) return false;
            try writeChampion(site, w, ch, r, c.role != null, c.role != null and r != main and champion.plays(site, ch, r));
        },
        .matchups => try finder.writePage(site, w),
        .matchup => |m| return matchup.route(site, w, if (site.curves) |*c| c else return false, m),
        .pool => try pool_page.writePage(site, w, &site.pool),
        .pickup => |r| try pickup_page.writePage(site, w, if (r) |x| coreRole(x) else null),
        .patch => |cur| if (cur) |x| return patch_page.writeOlder(site, w, x) else try patch_page.writePage(site, w),
        else => return false,
    }
    return true;
}

/// A page from the shared view (shared_pages, unlisted_pages, the account pages); false
/// for any other
pub fn renderShared(site: *const Site, w: *Writer, at: urls.Page) !bool {
    switch (at) {
        .learn => try learn_page.write(site, w),
        .daily => |n| if (n) |x| return daily_page.route(site, w, x) else try daily_page.write(site, w),
        .game => return yourgame.writePage(site, w),
        .games => return yourpage.writePage(site, w),
        else => {
            const fixed = [_]struct { std.meta.Tag(urls.Page), []const u8, []const u8, html.Nav, *const fn (*Writer, prose.Info) Writer.Error!void }{
                .{ .method, "Method", "Where meiolol's numbers come from and how lane curves, champion statistics and the Daily Draft are made.", .method, prose.method },
                .{ .download, "Champ select helper", "The meiolol champ select helper, a desktop app for Windows, in development.", .none, prose.download },
                .{ .your, "Your games", "Look yourself up: your lane in each recent ranked game against how the matchup typically goes, with your highlights, streaks and record per matchup.", .your, your_page.page },
                .{ .privacy, "Privacy policy", "What meiolol collects and why.", .none, prose.privacy },
                .{ .terms, "Terms of use", "Terms for using meiolol.", .none, prose.terms },
                .{ .login, "Log in", "Log in to meiolol.", .none, account_page.login },
                .{ .signup, "Make your account", "Make a meiolol account from a sign-up link.", .none, account_page.signup },
                .{ .join, "Set up your login", "Set up a meiolol login from an invite link.", .none, account_page.join },
                .{ .account, "Your account", "Your meiolol login: password and sign out.", .none, account_page.account },
            };
            for (fixed) |f| {
                if (f[0] != at) continue;
                var p = try site.sharedPage(try site.arena.print("{s} | meiolol", .{f[1]}), f[2], f[3]);
                p.canonical = try site.canonical(at);
                // The account pages: not in shared_pages (the sitemap), never indexed
                p.index = for (shared_pages) |s| {
                    if (std.meta.eql(s, at)) break true;
                } else false;
                try html.head(w, p);
                try f[4](w, site.info());
                if (f[3] == .method) try evalchart.section(w, site.eval);
                try html.foot(w, p);
                return true;
            }
            return false;
        },
    }
    return true;
}

/// The site's 404 page, never indexed
pub fn renderNotFound(site: *const Site, w: *Writer) !void {
    var p = try site.sharedPage("Page not found | meiolol", "No page at this address.", .none);
    p.index = false;
    try html.head(w, p);
    try w.writeAll(
        \\<div class="prose">
        \\<h1>Page not found</h1>
        \\<p class="lead">There's no page at this address: it may have moved, or the link has a typo.</p>
        \\<p><a href="/">Home</a> · <a href="/champions">Champions</a> · <a href="/matchups">Matchups</a></p>
        \\</div>
        \\
    );
    try html.foot(w, p);
}

pub fn pct(w: *Writer, part: u64, whole: u64) !void {
    if (whole == 0) return w.writeAll("-");
    try w.print("{d:.1}%", .{100 * @as(f64, @floatFromInt(part)) / @as(f64, @floatFromInt(whole))});
}

pub fn ratio(part: u64, whole: u64) f64 {
    return if (whole == 0) 0 else @as(f64, @floatFromInt(part)) / @as(f64, @floatFromInt(whole));
}

/// Under this many games a page says its data is early
const early_games = 50_000;

pub fn earlyNote(site: *const Site, w: *Writer) !void {
    if (site.games >= early_games) return;
    try tpl.render(w,
        \\<p class="note">Early data: {games} games so far.</p>
        \\
    , .{ .games = Thousands{ .n = site.games } });
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

/// Riot's position icons (CommunityDragon rcp-fe-lol-static-assets svg/position-*.svg)
/// as symbols for roleIcon, once per page using it: the lane in currentColor, the rest
/// of the map faint
pub fn roleIcons(w: *Writer) !void {
    try w.writeAll("<svg width=\"0\" height=\"0\" style=\"position:absolute\" aria-hidden=\"true\"><defs>" ++
        "<symbol id=\"ri-top\" viewBox=\"0 0 34 34\"><path opacity=\".35\" fill-rule=\"evenodd\" d=\"M21,14H14v7h7V14Zm5-3V26L11.014,26l-4,4H30V7.016Z\"/><polygon points=\"4 4 4.003 28.045 9 23 9 9 23 9 28.045 4.003 4 4\"/></symbol>" ++
        "<symbol id=\"ri-jungle\" viewBox=\"0 0 34 34\"><path fill-rule=\"evenodd\" d=\"M25,3c-2.128,3.3-5.147,6.851-6.966,11.469A42.373,42.373,0,0,1,20,20a27.7,27.7,0,0,1,1-3C21,12.023,22.856,8.277,25,3ZM13,20c-1.488-4.487-4.76-6.966-9-9,3.868,3.136,4.422,7.52,5,12l3.743,3.312C14.215,27.917,16.527,30.451,17,31c4.555-9.445-3.366-20.8-8-28C11.67,9.573,13.717,13.342,13,20Zm8,5a15.271,15.271,0,0,1,0,2l4-4c0.578-4.48,1.132-8.864,5-12C24.712,13.537,22.134,18.854,21,25Z\"/></symbol>" ++
        "<symbol id=\"ri-mid\" viewBox=\"0 0 34 34\"><path opacity=\".35\" fill-rule=\"evenodd\" d=\"M30,12.968l-4.008,4L26,26H17l-4,4H30ZM16.979,8L21,4H4V20.977L8,17,8,8h8.981Z\"/><polygon points=\"25 4 4 25 4 30 9 30 30 9 30 4 25 4\"/></symbol>" ++
        "<symbol id=\"ri-bot\" viewBox=\"0 0 34 34\"><path opacity=\".35\" fill-rule=\"evenodd\" d=\"M13,20h7V13H13v7ZM4,4V26.984l3.955-4L8,8,22.986,8l4-4H4Z\"/><polygon points=\"29.997 5.955 25 11 25 25 11 25 5.955 29.997 30 30 29.997 5.955\"/></symbol>" ++
        "<symbol id=\"ri-support\" viewBox=\"0 0 34 34\"><path fill-rule=\"evenodd\" d=\"M26,13c3.535,0,8-4,8-4H23l-3,3,2,7,5-2-3-4h2ZM22,5L20.827,3H13.062L12,5l5,6Zm-5,9-1-1L13,28l4,3,4-3L18,13ZM11,9H0s4.465,4,8,4h2L7,17l5,2,2-7Z\"/></symbol>" ++
        "</defs></svg>\n");
}

/// The role's icon from roleIcons, named for screen readers and on hover
pub fn roleIcon(w: *Writer, r: Role) !void {
    try tpl.render(w, "<svg class=\"ri\" role=\"img\" aria-label=\"{name}\"><title>{name}</title><use href=\"#ri-{slug}\"></use></svg>", .{
        .name = roleName(r),
        .slug = r.label(),
    });
}

/// 26568 as "26,568"
pub const Thousands = struct {
    n: u64,

    pub fn format(t: Thousands, w: *Writer) Writer.Error!void {
        var buf: [20]u8 = undefined;
        const digits = buf[0..std.fmt.printInt(&buf, t.n, 10, .lower, .{})];
        for (digits, 0..) |c, i| {
            if (i > 0 and (digits.len - i) % 3 == 0) try w.writeByte(',');
            try w.writeByte(c);
        }
    }
};

test Thousands {
    var buf: [16]u8 = undefined;
    for ([_]struct { u64, []const u8 }{ .{ 26568, "26,568" }, .{ 999, "999" }, .{ 1_000_000, "1,000,000" } }) |c| {
        try std.testing.expectEqualStrings(c[1], try std.mem.print(&buf, "{f}", .{Thousands{ .n = c[0] }}));
    }
}
