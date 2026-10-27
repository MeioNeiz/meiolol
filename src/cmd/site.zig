//! `meiolol site`, `dev`, `render`, `serve`: the website, built or rendered on request

const std = @import("std");
const store = @import("store");
const core = @import("core");
const stats = @import("../stats.zig");
const site = @import("../site/root.zig");
const serve = @import("../serve.zig");
const partials = @import("../partials.zig");
const Date = @import("../date.zig").Date;
const builds = @import("../builds.zig");
const main = @import("../main.zig");
const Cmd = main.Cmd;
const curvesPath = main.curvesPath;
const recentCurvesPath = main.recentCurvesPath;
const buildsPath = main.buildsPath;
const newestPatch = main.newestPatch;
const previousPatch = main.previousPatch;

/// Flags `site` and `dev` share
const SiteFlags = struct {
    patches: std.ArrayList([]const u8) = .empty,
    out: ?[]const u8 = null,
    contact: ?[]const u8 = null,
    riot_txt: ?[]const u8 = null,
    public: bool = false,
    euw_only: bool = false,
    static: site.Static = .all,
    static_min_games: u32 = 0,
    origin: ?[]const u8 = null,
    index_min_games: u32 = 0,
    views: ?[]const u8 = null,
    views_format: bool = false,
    reuse: bool = false,
    no_partials: bool = false,
    /// The views partials, for `site --views` only: the renderer never writes them
    partials_dir: ?[]const u8 = null,

    /// False for a flag that isn't one of these
    fn parse(f: *SiteFlags, c: *Cmd) !bool {
        if (c.is("--patch")) {
            try f.patches.appendSlice(c.arena, try c.list());
        } else if (c.is("--out")) {
            f.out = try c.value();
        } else if (c.is("--contact")) {
            f.contact = try c.value();
        } else if (c.is("--riot-txt")) {
            f.riot_txt = try c.value();
        } else if (c.is("--public")) {
            f.public = true;
        } else if (c.is("--euw-only")) {
            f.euw_only = true;
        } else if (c.is("--static")) {
            f.static = std.meta.stringToEnum(site.Static, try c.value()) orelse return error.Usage;
        } else if (c.is("--static-min-games")) {
            f.static_min_games = try c.int(u32);
        } else if (c.is("--origin")) {
            f.origin = std.mem.trimEnd(u8, try c.value(), "/");
        } else if (c.is("--index-min-games")) {
            f.index_min_games = try c.int(u32);
        } else if (c.is("--views")) {
            f.views = try c.value();
        } else if (c.is("--views-format")) {
            f.views_format = true;
        } else if (c.is("--reuse")) {
            f.reuse = true;
        } else if (c.is("--no-partials")) {
            f.no_partials = true;
        } else return false;
        return true;
    }

    /// Allocated in `arena`, which must outlive the options
    fn options(f: *const SiteFlags, c: *Cmd, arena: std.mem.Allocator, db: store.Db, contact: []const u8) !site.Options {
        const chosen = if (f.patches.items.len > 0) f.patches.items else try newestPatch(arena, db, &.{"EUW1"});
        const prev = try previousPatch(arena, db, chosen);
        const now_ms = std.Io.Clock.real.now(c.init.io).toMilliseconds();
        var opts: site.Options = .{
            .out_dir = f.out orelse try std.fs.path.join(arena, &.{ c.data_dir, "site" }),
            .patches = chosen,
            .since_ms = now_ms - main.recent_days * std.time.ms_per_day,
            .all_platforms = main.riot.endpoints.platform_ids,
            .contact = contact,
            .riot_txt = f.riot_txt,
            .updated = try arena.print("{f}", .{Date.fromMs(now_ms).long()}),
            .public = f.public,
            .euw_only = f.euw_only,
            .static = f.static,
            .static_min_games = f.static_min_games,
            .origin = f.origin,
            .eval_history = try std.fs.path.join(arena, &.{ c.data_dir, "eval-history.tsv" }),
            .lean = try std.fs.path.join(arena, &.{ c.data_dir, "lean.tsv" }),
            .your_example = try std.fs.path.join(arena, &.{ c.data_dir, "your-example.json" }),
            .index_min_games = f.index_min_games,
            .daily_dir = try std.fs.path.join(arena, &.{ c.data_dir, "daily" }),
            // Indexed by site.html.View.index: EUW 30 days, EUW patch, all 30 days, all patch
            .curves = .{
                try recentCurvesPath(arena, c.data_dir, false),
                try curvesPath(arena, c.data_dir, chosen, false),
                try recentCurvesPath(arena, c.data_dir, true),
                try curvesPath(arena, c.data_dir, chosen, true),
            },
            .builds = .{
                try main.recentBuildsPath(arena, c.data_dir, false),
                try buildsPath(arena, c.data_dir, chosen, false),
                try main.recentBuildsPath(arena, c.data_dir, true),
                try buildsPath(arena, c.data_dir, chosen, true),
            },
            .builds_rank = try rankPaths(arena, .{
                try main.recentBuildsPath(arena, c.data_dir, false),
                try buildsPath(arena, c.data_dir, chosen, false),
                try main.recentBuildsPath(arena, c.data_dir, true),
                try buildsPath(arena, c.data_dir, chosen, true),
            }),
            .prev_patch = if (prev) |p| p[0] else null,
            .older_pairs = if (prev != null) try main.olderPairs(arena, db, chosen) else &.{},
            .ddragon_dir = try std.fs.path.join(arena, &.{ c.data_dir, "ddragon" }),
            .builds_prev = if (prev) |p| .{
                null,
                try buildsPath(arena, c.data_dir, p, false),
                null,
                try buildsPath(arena, c.data_dir, p, true),
            } else @splat(null),
            .curves_prev = if (prev) |p| .{
                null,
                try curvesPath(arena, c.data_dir, p, false),
                null,
                try curvesPath(arena, c.data_dir, p, true),
            } else @splat(null),
        };
        // Each run or view opens its own SQLite connection: a typo like 400 must stop the
        // build, not open hundreds
        if (c.init.environ_map.get("MEIOLOL_FILTER_RUNS")) |v| {
            opts.filter_runs = std.fmt.parseInt(usize, v, 10) catch 0;
            if (opts.filter_runs == 0 or opts.filter_runs > 64) return error.BadFilterRuns;
        }
        if (c.init.environ_map.get("MEIOLOL_VIEW_LOADS")) |v| {
            opts.view_loads = std.fmt.parseInt(usize, v, 10) catch 0;
            if (opts.view_loads == 0 or opts.view_loads > site.html.View.count) return error.BadViewLoads;
        }
        return opts;
    }
};

/// Each view's builds file at each of builds.rank_tiers (main.rankBuildsPath)
fn rankPaths(arena: std.mem.Allocator, base: [site.html.View.count][]const u8) ![site.html.View.count][builds.rank_tiers.len]?[]const u8 {
    var out: [site.html.View.count][builds.rank_tiers.len]?[]const u8 = undefined;
    for (base, &out) |b, *o| for (builds.rank_tiers, o) |tier, *p| {
        p.* = try main.rankBuildsPath(arena, b, tier);
    };
    return out;
}

pub const usage_site =
    \\  site       write the public website (static files): EUW over the last 30 days
    \\              at the root, the patch under patch/, every region under all/ and
    \\              all/patch/ (lane curves and builds: the curves and builds
    \\              commands' default files); patch.html compares the patch with
    \\              the one before (its curves too, where `curves --patch` wrote them)
    \\              --patch P        the patch views' (default: EUW's newest patch)
    \\              --out DIR        default DIR/site
    \\              --contact EMAIL  shown on the privacy and terms pages (required)
    \\              --riot-txt TEXT  served as /riot.txt (Riot's verification string)
    \\              --public         listed for search engines, no preview banner; only
    \\                               once Riot grants the production key
    \\              --euw-only       the EUW views only (root, patch/): a quick preview
    \\              --static-min-games N  leave out matchup pages under N games (for
    \\                               `render` to serve on request)
    \\              --static core    write only the home page, robots.txt, riot.txt,
    \\                               the root sitemap and the front-end files;
    \\                               `render` serves every other page and file
    \\              --origin URL     site URL for canonical links and sitemaps (public)
    \\              --index-min-games N  matchup pages under N games noindex and out of
    \\                               the sitemaps
    \\              --views FILE     load every view and write it to FILE for
    \\                               `render --views` instead of the site
    \\              --views-format   print the fingerprint a views file from this
    \\                               binary has (u64 after the 8-byte magic)
    \\              --reuse          with --views: keep the parts of the file already
    \\                               there that this binary would make the same way
    \\                               (a deploy's round), load only the rest
    \\              --no-partials    with --views: read every game from the database,
    \\                               not data/partials (docs/arch-site.md "Views
    \\                               partials"), which is left alone
    \\              --patch-games    print the EUW patch the site would show and its
    \\                               game count (no site; deploy/web-loop.sh)
    \\              --prune-assets DIR  delete the front-end files' older hashed
    \\                               copies and portrait folders in DIR three days
    \\                               after a newer one came (no site;
    \\                               deploy/web-loop.sh, on data/site)
    \\
;

pub fn cmdSite(c: *Cmd) !u8 {
    var f: SiteFlags = .{};
    var patch_games = false;
    var prune: ?[]const u8 = null;
    while (c.next()) |_| {
        if (c.is("--patch-games")) {
            patch_games = true;
        } else if (c.is("--prune-assets")) {
            prune = try c.value();
        } else if (!try f.parse(c)) return error.Usage;
    }
    if (prune) |path| {
        const io = c.init.io;
        var dir = try std.Io.Dir.cwd().openDir(io, path, .{ .iterate = true });
        defer dir.close(io);
        const grace: std.Io.Duration = .fromNanoseconds(3 * std.time.ns_per_day);
        const now: std.Io.Timestamp = .now(io, .real);
        const n = try site.assets.prune(c.init.gpa, io, dir, &site.hashed_assets, now, grace);
        const v = try main.icons.prune(c.init.gpa, io, dir, now, grace);
        std.log.info("{d} old front-end files, {d} portrait versions deleted", .{ n, v });
        return 0;
    }
    // A fraction of a second: the web loop asks every round whether to build and upload
    if (patch_games) {
        const db = try c.open();
        defer db.close();
        const chosen = if (f.patches.items.len > 0) f.patches.items else try newestPatch(c.arena, db, &.{"EUW1"});
        var label_buf: [core.statsfile.patch_len]u8 = undefined;
        var buf: [64]u8 = undefined;
        var w = std.Io.File.stdout().writer(c.init.io, &buf);
        try w.interface.print("{s} {d}\n", .{ try stats.label(&label_buf, chosen), try stats.countGames(db, chosen, &.{"EUW1"}) });
        try w.interface.flush();
        return 0;
    }
    if (f.views_format) {
        var buf: [32]u8 = undefined;
        var w = std.Io.File.stdout().writer(c.init.io, &buf);
        try w.interface.print("{d}\n", .{site.Loaded.viewsFormat()});
        try w.interface.flush();
        return 0;
    }
    const email = try c.required(f.contact, "--contact");
    const db = try c.open();
    defer db.close();
    if (f.views) |path| {
        if (!f.no_partials) f.partials_dir = try partials.dirIn(c.arena, c.data_dir);
        const l = try loadAll(c, &f, db, email);
        defer l.free(c.init.gpa);
        try l.loaded.writeViews(path);
        std.log.info("views: {s}", .{path});
        return 0;
    }
    const opts = try f.options(c, c.arena, db, email);
    try site.generate(c.init.gpa, c.init.io, db, opts);
    makeIcons(c, db, opts.out_dir);
    return 0;
}

/// Champion portraits (src/icons.zig) cached in DIR/ddragon, copied into `out_dir` unless
/// null. Failing, it warns: the pages go out, their portraits where cached
fn makeIcons(c: *Cmd, db: store.Db, out_dir: ?[]const u8) void {
    var http: std.http.Client = .{ .allocator = c.init.gpa, .io = c.init.io };
    defer http.deinit();
    const cache = std.fs.path.join(c.arena, &.{ c.data_dir, "ddragon" }) catch return;
    const n = main.icons.sync(c.init.gpa, c.init.io, db, cache, out_dir, .{ .http = &http }) catch |err| {
        std.log.warn("icons: {t}", .{err});
        return;
    };
    if (n.failed > 0) {
        std.log.warn("icons: {d} made, {d} failed (tried again next run)", .{ n.made, n.failed });
    } else if (n.made > 0) std.log.info("icons: {d} made", .{n.made});
}

pub const usage_dev =
    \\  dev        work on the site: pages rendered on request from DIR (data loaded
    \\              once), CSS and JS from src/site/static, live reload; run by
    \\              deploy/dev.sh, which rebuilds on edits. Takes site's flags
    \\              --port P         default 8080
    \\
;

/// Pages rendered on request from data loaded once, CSS and JS from src/site/static, and
/// the browser reloading after an edit (deploy/dev.sh rebuilds the binary)
pub fn cmdDev(c: *Cmd) !u8 {
    var f: SiteFlags = .{};
    var port: u16 = 8080;
    while (c.next()) |_| {
        if (c.is("--port")) {
            port = try c.int(u16);
        } else if (!try f.parse(c)) return error.Usage;
    }
    const static_dir = "src/site/static";
    var dev: serve.Dev = try .init(c.arena, c.init.io, try c.init.minimal.args.toSlice(c.arena), static_dir);
    dev.notes_db = try std.fs.path.joinZ(c.arena, &.{ c.data_dir, "dev-notes.db" });
    const db = try c.open();
    defer db.close();
    var opts = try f.options(c, c.arena, db, f.contact orelse "dev@example.com");
    opts.static_dir = static_dir;
    const loaded = try site.Loaded.init(c.init.gpa, c.init.io, db, opts);
    const rendered = serve.Rendered.init(c.init.gpa, c.init.io, loaded, null) catch |err| {
        loaded.deinit();
        return err;
    };
    defer rendered.deinit();
    // Before listening, so the browser reloads once it is ready; the others on request
    _ = try loaded.site(site.html.View.all[0]);
    // Portraits straight from their cache, laid out as the site's
    makeIcons(c, db, null);
    try serve.run(c.init.gpa, c.init.io, .{
        .root = try std.fs.path.join(c.arena, &.{ c.data_dir, "ddragon" }),
        .port = port,
        .render = rendered,
        .dev = dev,
    });
    return 0;
}

pub const usage_render =
    \\  render     the pages `site --static` leaves out, rendered on request
    \\              for the web server's nginx (all views loaded up front). Takes
    \\              site's flags (--contact required)
    \\              --host H         default 127.0.0.1 (local only)
    \\              --port P         default 8091
    \\              --reload FILE    load the data again whenever FILE changes
    \\              --ready FILE     written once listening, holding the served
    \\                               data's version (again at each reload) for
    \\                               jomify's nginx cache key. Several may share
    \\                               the port (SO_REUSEPORT): deploy/render-swap.sh
    \\              --views FILE     load from FILE (`site --views`), at start and
    \\                               on --reload, in seconds; the database when it
    \\                               is missing or another binary's types wrote it
    \\
;

/// The pages and files the static build leaves out (--static, --static-min-games),
/// rendered on request for the web server's nginx (docs/hosting.md "Rendering on
/// request"), loaded again whenever the --reload file changes. From the --views file
/// when this binary reads it: listening and --ready in seconds. Otherwise from the
/// database: beside a running instance (a deploy: deploy/render-swap.sh) it loads every
/// view, then listens too (SO_REUSEPORT) and is --ready for the old one to stop; alone
/// (a boot) it listens at once and serves each view as it loads, the rest answering 503
pub fn cmdRender(c: *Cmd) !u8 {
    var f: SiteFlags = .{};
    var host: []const u8 = "127.0.0.1";
    var port: u16 = 8091;
    var reload: ?[]const u8 = null;
    var ready: ?[]const u8 = null;
    while (c.next()) |_| {
        if (c.is("--host")) {
            host = try c.value();
        } else if (c.is("--port")) {
            port = try c.int(u16);
        } else if (c.is("--reload")) {
            reload = try c.value();
        } else if (c.is("--ready")) {
            ready = try c.value();
        } else if (!try f.parse(c)) return error.Usage;
    }
    const email = try c.required(f.contact, "--contact");
    const gpa = c.init.gpa;
    const io = c.init.io;
    const db = try c.open();
    defer db.close();
    const alone = !listening(io, host, port);
    const from_file = fromViewsFile(c, &f, db);
    if (from_file == null and f.views != null) std.log.info("render: loading from the database", .{});
    const first = from_file orelse try prepare(c, &f, db, email);
    first.loaded.lazy = false;
    // From the database in the background once listening (alone), else before
    const background_load = from_file == null and alone;
    if (from_file == null and !alone) first.loaded.loadAll() catch |err| {
        first.free(gpa);
        return err;
    };
    const rendered = serve.Rendered.init(gpa, io, first.loaded, first.arena) catch |err| {
        first.free(gpa);
        return err;
    };
    defer rendered.deinit();
    var group: std.Io.Group = .init;
    defer group.cancel(io);
    group.async(io, background, .{ c, &f, db, email, rendered, if (background_load) first.loaded else null, ready, reload });
    var admin_api: serve.admin_api.Api = .{ .gpa = gpa, .io = io, .data_dir = c.data_dir };
    defer admin_api.deinit();
    try serve.run(gpa, io, .{ .host = host, .port = port, .render = rendered, .ready = if (background_load) null else ready, .admin = &admin_api });
    return 0;
}

/// Whether something already listens at host:port: an older renderer
fn listening(io: std.Io, host: []const u8, port: u16) bool {
    const address = std.Io.net.IpAddress.parse(host, port) catch return false;
    const stream = address.connect(io, .{ .mode = .stream }) catch return false;
    stream.close(io);
    return true;
}

/// The database's only user once the server runs: the first load when serving early
/// (exiting on failure, for systemd to start again; `ready` after it), then reloads
fn background(c: *Cmd, f: *const SiteFlags, db: store.Db, contact: []const u8, rendered: *serve.Rendered, first: ?*site.Loaded, ready: ?[]const u8, reload: ?[]const u8) void {
    if (first) |l| {
        l.loadAll() catch |err| {
            std.log.err("render load: {t}", .{err});
            std.process.exit(1);
        };
        if (ready) |path| rendered.writeReady(path) catch |err| {
            std.log.warn("render ready file: {t}", .{err});
        };
    }
    if (reload) |path| reloadOnChange(c, f, db, contact, rendered, path, ready);
}

const LoadedAll = struct {
    loaded: *site.Loaded,
    /// The options' strings
    arena: *std.heap.ArenaAllocator,

    fn free(l: LoadedAll, gpa: std.mem.Allocator) void {
        l.loaded.deinit();
        l.arena.deinit();
        gpa.destroy(l.arena);
    }
};

/// Options as of now (patch, 30-day window), no view loaded yet
fn prepare(c: *Cmd, f: *const SiteFlags, db: store.Db, contact: []const u8) !LoadedAll {
    const gpa = c.init.gpa;
    const arena = try gpa.create(std.heap.ArenaAllocator);
    arena.* = .init(gpa);
    errdefer {
        arena.deinit();
        gpa.destroy(arena);
    }
    const opts = try f.options(c, arena.allocator(), db, contact);
    return .{ .loaded = try site.Loaded.init(gpa, c.init.io, db, opts), .arena = arena };
}

/// Every view from the --views file; null without one, or when it can't be read
/// (missing, or another binary's types wrote it: a deploy that changed them)
fn fromViewsFile(c: *Cmd, f: *const SiteFlags, db: store.Db) ?LoadedAll {
    const path = f.views orelse return null;
    const gpa = c.init.gpa;
    const io = c.init.io;
    const start = std.Io.Clock.real.now(io).toMilliseconds();
    const arena = gpa.create(std.heap.ArenaAllocator) catch return null;
    arena.* = .init(gpa);
    const loaded = site.Loaded.readViews(gpa, io, db, path, arena.allocator()) catch |err| {
        std.log.warn("render: views file {s}: {t}", .{ path, err });
        arena.deinit();
        gpa.destroy(arena);
        return null;
    };
    const age_s = @divTrunc(std.Io.Clock.real.now(io).toNanoseconds() - fileMtime(io, path), std.time.ns_per_s);
    std.log.info("render: views file read in {d} ms, written {d} min ago", .{
        std.Io.Clock.real.now(io).toMilliseconds() - start, @divTrunc(age_s, 60),
    });
    return .{ .loaded = loaded, .arena = arena };
}

/// prepare and Loaded.loadAll: every view loaded, not on its first request
fn loadAll(c: *Cmd, f: *const SiteFlags, db: store.Db, contact: []const u8) !LoadedAll {
    const l = try prepare(c, f, db, contact);
    errdefer l.free(c.init.gpa);
    if (f.reuse) if (f.views) |path| try l.loaded.reuseViews(path);
    l.loaded.extras.partials_dir = f.partials_dir;
    l.loaded.lazy = false;
    try l.loaded.loadAll();
    return l;
}

/// Swaps in freshly loaded data whenever `path`'s mtime moves (deploy/web-loop.sh touches
/// it after each upload); on a failed load the old data stays. With --views only from
/// that file: a database load here would run beside the web loop's (an old renderer
/// seeing a newer binary's file during a swap). `ready` gets the new data's version
fn reloadOnChange(c: *Cmd, f: *const SiteFlags, db: store.Db, contact: []const u8, rendered: *serve.Rendered, path: []const u8, ready: ?[]const u8) void {
    const io = c.init.io;
    var seen = fileMtime(io, path);
    while (true) {
        io.sleep(.fromMilliseconds(10_000), .awake) catch return;
        const now = fileMtime(io, path);
        if (now == seen) continue;
        seen = now;
        const start = std.Io.Clock.real.now(io).toMilliseconds();
        // A newer binary's file (a deploy, before the swap): the current data stays
        const next = (if (f.views != null) fromViewsFile(c, f, db) orelse continue else loadAll(c, f, db, contact)) catch |err| {
            std.log.warn("render reload: {t}", .{err});
            continue;
        };
        rendered.swap(next.loaded, next.arena) catch |err| {
            next.free(c.init.gpa);
            std.log.warn("render reload: {t}", .{err});
            continue;
        };
        std.log.info("render: reloaded in {d} s", .{@divTrunc(std.Io.Clock.real.now(io).toMilliseconds() - start, 1000)});
        if (ready) |p| rendered.writeReady(p) catch |err| std.log.warn("render ready file: {t}", .{err});
    }
}

fn fileMtime(io: std.Io, path: []const u8) i96 {
    const st = std.Io.Dir.cwd().statFile(io, path, .{}) catch return 0;
    return st.mtime.toNanoseconds();
}

pub const usage_serve =
    \\  serve       serve the website (default DIR/site) over HTTP, for the tunnel
    \\              --host H         default 127.0.0.1 (local only)
    \\              --port P         default 8080
    \\              --out DIR        site directory to serve
    \\
;

pub fn cmdServe(c: *Cmd) !u8 {
    var dir: ?[]const u8 = null;
    var host: []const u8 = "127.0.0.1";
    var port: u16 = 8080;
    while (c.next()) |_| {
        if (c.is("--out")) {
            dir = try c.value();
        } else if (c.is("--host")) {
            host = try c.value();
        } else if (c.is("--port")) {
            port = try c.int(u16);
        } else return error.Usage;
    }
    const root = dir orelse try std.fs.path.join(c.arena, &.{ c.data_dir, "site" });
    try serve.run(c.init.gpa, c.init.io, .{ .root = root, .host = host, .port = port });
    return 0;
}
