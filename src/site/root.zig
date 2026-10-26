//! `meiolol site`: the public stats website as static files (HTML, CSS, the model
//! file and champion JSON for the browser pages). Host anywhere static.

const std = @import("std");
const core = @import("core");
pub const html = @import("html.zig");
const prose = @import("prose.zig");
const account_page = @import("account.zig");
const daily_page = @import("daily.zig");
const your_page = @import("your.zig");
const yourgame = @import("yourgame.zig");
const daily = @import("../daily.zig");
const learn = @import("../learn.zig");
const learn_page = @import("learn.zig");
const matchup = @import("matchup.zig");
const finder = @import("finder.zig");
const pool_page = @import("pool.zig");
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
const assets = @import("assets.zig");
pub const gallery = @import("gallery.zig");
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
const writeChampion = @import("champion.zig").writeChampion;

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
};

pub const Static = enum {
    /// Every page and file (but thin matchups: Options.static_min_games)
    all,
    /// core_static only
    core,
};

/// `--static core`: the only files the static build writes, besides the front-end assets
/// (shared_assets, view_assets); nginx serves them itself and hands every other path to
/// `meiolol render`. All at the site root: nginx's try_files answers the URL of a
/// directory that exists with its index.html or 403, never the renderer, so the root
/// keeps its home page and no subdirectory is written
pub const core_static = [_][]const u8{
    "index.html", "sitemap.xml", "robots.txt", "riot.txt", "meiolol.wasm", "chart.wasm",
};

/// Whether the static build writes the file at `dir` ++ `path` from the site root
pub fn isStatic(opts: Options, dir: []const u8, path: []const u8) bool {
    if (opts.static == .all) return true;
    if (dir.len > 0 or std.mem.findScalar(u8, path, '/') != null) return false;
    for (core_static) |name| if (std.mem.eql(u8, name, path)) return true;
    for (shared_assets ++ view_assets) |f| if (std.mem.eql(u8, f.path, path)) return true;
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

    /// A page of the view at `path` within it
    pub fn page(s: *const Site, title: []const u8, description: []const u8, path: []const u8, nav: html.Nav) !html.Page {
        var p = try s.sharedPage(title, description, nav);
        p.view = s.view;
        p.counterparts = @as([html.View.count][]const u8, undefined);
        for (html.View.all, &p.counterparts.?) |v, *there| {
            there.* = try std.mem.concat(s.arena, u8, &.{ v.dir(), path });
        }
        p.root = try s.toRoot(path);
        p.canonical = try s.canonical(s.view.dir(), path);
        return p;
    }

    /// `origin/dir/path`; null without Options.origin
    pub fn canonical(s: *const Site, dir: []const u8, path: []const u8) !?[]const u8 {
        const origin = s.opts.origin orelse return null;
        return try std.mem.concat(s.arena, u8, &.{ origin, "/", dir, path });
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

    /// From `path` up to its view's root
    pub fn toRoot(s: *const Site, path: []const u8) ![]const u8 {
        const depth = std.mem.count(u8, path, "/");
        const out = try s.arena.alloc(u8, 3 * depth);
        for (0..depth) |i| @memcpy(out[3 * i ..][0..3], "../");
        return out;
    }

    /// From `path` to the site root, where the shared pages are
    pub fn toShared(s: *const Site, path: []const u8) ![]const u8 {
        return std.mem.concat(s.arena, u8, &.{ try s.toRoot(path), s.view.up() });
    }

    pub fn icon(s: *const Site, ch: Champ) ![]const u8 {
        return s.arena.print(
            "https://ddragon.leagueoflegends.com/cdn/{s}/img/champion/{s}.png",
            .{ s.ddragon_version, ch.key },
        );
    }

    /// To the champion's page (one per champion, at the site root), its filters set to
    /// this view. `to_site`: from the linking page to the site root. Raw: escape it
    pub fn champHref(s: *const Site, ch: Champ, to_site: []const u8) ![]const u8 {
        return s.arena.print("{s}champion/{s}.html{s}", .{ to_site, ch.slug, s.view.query() });
    }

    /// A champion link as the main link of a row or tile (class bx) that it covers whole
    pub fn champBox(s: *const Site, w: *Writer, ch: Champ, to_site: []const u8) !void {
        try tpl.render(w, "<a class=\"champ box\" href=\"{href}\"><img src=\"{icon}\" alt=\"\" loading=\"lazy\" width=\"32\" height=\"32\">{name}</a>", .{
            .href = try s.champHref(ch, to_site),
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
pub const hashed_assets = [_]assets.Hashed{ style.file, style.font, assets.search_js, assets.stats_js, assets.stats_wasm, assets.champion_js, assets.champion_wasm, assets.champbuild_js, assets.champbuild_wasm, assets.champmore_js, assets.champmore_wasm, assets.matchup_js, assets.matchup_wasm, assets.matchmore_js, assets.matchmore_wasm, assets.games_js, assets.games_wasm, assets.gamemore_js, assets.gamemore_wasm, assets.gamelane_js, assets.gamelane_wasm, assets.finder_js, assets.finder_wasm, assets.learn_js, assets.learn_wasm, assets.patch_js, assets.patch_wasm };

/// Front-end files at the site root; `Options.static_dir` serves them from disk instead
pub const shared_assets = [_]File{
    .{ .path = "style.css", .data = style.bundle },
    .{ .path = "favicon.svg", .data = @embedFile("static/favicon.svg") },
    .{ .path = "daily.js", .data = @embedFile("static/daily.js") },
    .{ .path = "reasons.js", .data = @embedFile("static/reasons.js") },
    .{ .path = "your.js", .data = @embedFile("static/your.js") },
    .{ .path = "review.js", .data = @embedFile("static/review.js") },
    .{ .path = "home.js", .data = @embedFile("static/home.js") },
    .{ .path = "inter.woff2", .data = @embedFile("static/inter.woff2") },
    .{ .path = "table.js", .data = @embedFile("static/table.js") },
    .{ .path = "search.js", .data = @embedFile("static/search.js") },
    .{ .path = "account.js", .data = @embedFile("static/account.js") },
    // Linked for print, so it never holds up rendering; browsers still fetch it on each load
    .{ .path = "print.css", .data = @embedFile("static/print.css") },
    // Built (build.zig uiWasm), so never read from static_dir
    .{ .path = "ui-stats.wasm", .data = @embedFile("ui-stats.wasm") },
    .{ .path = "ui-stats.js", .data = @embedFile("ui-stats.js") },
    .{ .path = "ui-champion.wasm", .data = @embedFile("ui-champion.wasm") },
    .{ .path = "ui-champion.js", .data = @embedFile("ui-champion.js") },
    .{ .path = "ui-champbuild.wasm", .data = @embedFile("ui-champbuild.wasm") },
    .{ .path = "ui-champbuild.js", .data = @embedFile("ui-champbuild.js") },
    .{ .path = "ui-champmore.wasm", .data = @embedFile("ui-champmore.wasm") },
    .{ .path = "ui-champmore.js", .data = @embedFile("ui-champmore.js") },
    .{ .path = "ui-matchup.wasm", .data = @embedFile("ui-matchup.wasm") },
    .{ .path = "ui-matchup.js", .data = @embedFile("ui-matchup.js") },
    .{ .path = "ui-matchmore.wasm", .data = @embedFile("ui-matchmore.wasm") },
    .{ .path = "ui-matchmore.js", .data = @embedFile("ui-matchmore.js") },
    .{ .path = "ui-games.wasm", .data = @embedFile("ui-games.wasm") },
    .{ .path = "ui-games.js", .data = @embedFile("ui-games.js") },
    .{ .path = "ui-gamemore.wasm", .data = @embedFile("ui-gamemore.wasm") },
    .{ .path = "ui-gamemore.js", .data = @embedFile("ui-gamemore.js") },
    .{ .path = "ui-gamelane.wasm", .data = @embedFile("ui-gamelane.wasm") },
    .{ .path = "ui-gamelane.js", .data = @embedFile("ui-gamelane.js") },
    .{ .path = "ui-finder.wasm", .data = @embedFile("ui-finder.wasm") },
    .{ .path = "ui-finder.js", .data = @embedFile("ui-finder.js") },
    .{ .path = "ui-learn.wasm", .data = @embedFile("ui-learn.wasm") },
    .{ .path = "ui-learn.js", .data = @embedFile("ui-learn.js") },
    .{ .path = "ui-patch.wasm", .data = @embedFile("ui-patch.wasm") },
    .{ .path = "ui-patch.js", .data = @embedFile("ui-patch.js") },
};
/// And in every view's directory
pub const view_assets = [_]File{
    .{ .path = "pool.js", .data = @embedFile("static/pool.js") },
};

/// Asset `wanted` (a hashed name as its plain one) from Options.static_dir when set (edits
/// show without a rebuild), else as embedded; null for anything else
pub fn asset(arena: std.mem.Allocator, io: std.Io, opts: Options, wanted: []const u8) !?[]const u8 {
    const name = for (hashed_assets) |h| {
        if (std.mem.eql(u8, h.path, wanted)) break h.plain;
    } else wanted;
    const all = shared_assets ++ view_assets;
    const embedded = for (all) |f| {
        if (std.mem.eql(u8, f.path, name)) break f.data;
    } else return null;
    const dir = opts.static_dir orelse return embedded;
    if (std.mem.startsWith(u8, name, "ui-")) return embedded;
    const path = try std.fs.path.join(arena, &.{ dir, name });
    const data = try std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 24));
    return if (std.mem.eql(u8, name, "style.css")) try style.rebuild(arena, data) else data;
}

/// Pages at the site root, from the shared view (renderShared)
pub const shared_pages = [_][]const u8{
    "learn.html", "method.html", "daily.html", "download.html", "your.html", "privacy.html", "terms.html",
};

/// Shared pages the static build writes but the sitemap leaves out
pub const unlisted_pages = [_][]const u8{yourgame.page_path};

pub fn robots(arena: std.mem.Allocator, opts: Options) ![]const u8 {
    if (!opts.public) return "User-agent: *\nDisallow: /\n";
    var out: std.ArrayList(u8) = .empty;
    // Your games answers name players (docs/legal/lia.md safeguards): never crawled. /p/:
    // the private site, behind a login
    try out.appendSlice(arena, "User-agent: *\nAllow: /\nDisallow: /api/\nDisallow: /p/\n");
    if (opts.origin) |origin| for (html.View.all) |v| {
        if (opts.euw_only and v.region != .euw) continue;
        try out.print(arena, "Sitemap: {s}/{s}sitemap.xml\n", .{ origin, v.dir() });
    };
    return out.items;
}

test {
    _ = style;
    _ = patch_page;
    _ = gallery;
    _ = evalchart;
    _ = flat;
    _ = yourgame;
    _ = scope;
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
        "User-agent: *\nAllow: /\nDisallow: /api/\nDisallow: /p/\nSitemap: https://x.io/sitemap.xml\nSitemap: https://x.io/patch/sitemap.xml\n",
        try robots(arena.allocator(), public),
    );
}

/// The view's pages search engines may index, at its root; the root view's (at the
/// site root) also lists the shared pages
pub fn sitemap(site: *const Site) ![]const u8 {
    const a = site.arena;
    var out: std.ArrayList(u8) = .empty;
    try out.appendSlice(a, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n");
    var paths: std.ArrayList([]const u8) = .empty;
    try paths.appendSlice(a, try pagePathsMin(site, site.opts.index_min_games));
    // Listed from the root view, before the shared view (whose learn build may fail) loads
    if (site.view.index() == 0) try paths.appendSlice(a, &shared_pages);
    for (paths.items) |path| {
        // Old build pages only redirect to champion pages
        if (std.mem.startsWith(u8, path, "build/")) continue;
        // Paths are slugs and fixed names: nothing XML needs escaped
        try out.print(a, "<url><loc>{s}</loc></url>\n", .{(try site.canonical(site.view.dir(), path)).?});
    }
    try out.appendSlice(a, "</urlset>\n");
    return out.items;
}

/// Every page of the view the static build writes, by path within its directory
pub fn pagePaths(site: *const Site) ![]const []const u8 {
    return pagePathsMin(site, site.opts.static_min_games);
}

/// As pagePaths, but matchup pages from `min_games` up
fn pagePathsMin(site: *const Site, min_games: u32) ![]const []const u8 {
    const a = site.arena;
    var list: std.ArrayList([]const u8) = .empty;
    try list.appendSlice(a, &.{ "index.html", "champions.html" });
    for (Role.all) |r| try list.append(a, try a.print("role/{s}.html", .{r.label()}));
    if (site.view.index() == 0) for (site.champs) |ch| {
        try list.append(a, try a.print("champion/{s}.html", .{ch.slug}));
    };
    try list.append(a, "matchup/index.html");
    if (site.curves) |*c| try matchup.paths(site, c, &list, min_games);
    if (site.view_builds[site.view.index()]) |*b| try builds_page.paths(site, b, &list);
    try list.append(a, "pool.html");
    try list.append(a, patch_page.path);
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
        try finder.writePage(site, w);
    } else if (strip(path, "matchup/", ".html")) |s| {
        return matchup.route(site, w, if (site.curves) |*c| c else return false, s);
    } else if (eql(u8, path, builds_page.index_path)) {
        try builds_page.writeIndex(site, w);
    } else if (strip(path, "build/", ".html")) |s| {
        return builds_page.route(site, w, s);
    } else if (eql(u8, path, "pool.html")) {
        try pool_page.writePage(site, w, &site.pool, &site.learning);
    } else if (eql(u8, path, patch_page.path)) {
        try patch_page.writePage(site, w);
    } else return false;
    return true;
}

/// A page at the site root from the shared view (shared_pages); false for any other path
pub fn renderShared(site: *const Site, w: *Writer, path: []const u8) !bool {
    if (std.mem.eql(u8, path, "learn.html")) {
        try learn_page.write(site, w);
        return true;
    }
    if (std.mem.eql(u8, path, yourgame.page_path)) return yourgame.writePage(site, w);
    const fixed = [_]struct { []const u8, []const u8, []const u8, html.Nav, *const fn (*Writer, prose.Info) Writer.Error!void }{
        .{ "method.html", "Method", "Where meiolol's numbers come from and how lane curves, champion statistics and the Daily Draft are made.", .method, prose.method },
        .{ "daily.html", "Daily Draft", "Guess the hidden champion and the winner of a real ranked draft, then see what this patch's games say about it.", .daily, daily_page.page },
        .{ "download.html", "Champ select helper", "The meiolol champ select helper, a desktop app for Windows, in development.", .none, prose.download },
        .{ "your.html", "Your games", "Look yourself up: your lane in each recent ranked game against how the matchup typically goes, with your highlights, streaks and record per matchup.", .your, your_page.page },
        .{ "privacy.html", "Privacy policy", "What meiolol collects and why.", .none, prose.privacy },
        .{ "terms.html", "Terms of use", "Terms for using meiolol.", .none, prose.terms },
        .{ "login.html", "Log in", "Log in to meiolol.", .none, account_page.login },
        .{ "signup.html", "Make your account", "Make a meiolol account from a sign-up link.", .none, account_page.signup },
        .{ "join.html", "Set up your login", "Set up a meiolol login from an invite link.", .none, account_page.join },
        .{ "account.html", "Your account", "Your meiolol login: password and sign out.", .none, account_page.account },
    };
    for (fixed) |f| {
        if (!std.mem.eql(u8, path, f[0])) continue;
        var p = try site.sharedPage(try site.arena.print("{s} | meiolol", .{f[1]}), f[2], f[3]);
        // The account pages: not in shared_pages (the sitemap), never indexed
        p.index = for (shared_pages) |s| {
            if (std.mem.eql(u8, s, f[0])) break true;
        } else false;
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

pub fn pct(w: *Writer, part: u64, whole: u64) !void {
    if (whole == 0) return w.writeAll("-");
    try w.print("{d:.1}%", .{100 * @as(f64, @floatFromInt(part)) / @as(f64, @floatFromInt(whole))});
}

pub fn ratio(part: u64, whole: u64) f64 {
    return if (whole == 0) 0 else @as(f64, @floatFromInt(part)) / @as(f64, @floatFromInt(whole));
}

/// Under this many games a page says its data is early
const early_games = 50_000;

/// `filtered`: written even when hidden, for filters.js to show when the filters pick fewer
/// games
pub fn earlyNote(site: *const Site, w: *Writer, filtered: bool) !void {
    const early = site.games < early_games;
    if (!early and !filtered) return;
    try tpl.render(w,
        \\<p class="note" data-early="{early}"{hidden}>Early data: <span data-early-games>{games} games so far ({when})</span>. Win rates fade the fewer games they have. Colour runs from hot pink through orange (low) to blue through aqua (high), grey at 50%.</p>
        \\
    , .{
        .early = early_games,
        .hidden = tpl.flag(!early, "hidden"),
        .games = Thousands{ .n = site.games },
        .when = site.when,
    });
}

pub fn roleFromSlug(s: []const u8) ?Role {
    for (Role.all) |r| if (std.mem.eql(u8, r.label(), s)) return r;
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
