//! The static build (`meiolol site`): every view's pages and files into Options.out_dir

const std = @import("std");
const store = @import("store");
const html = @import("html.zig");
const home_page = @import("home.zig");
const daily_page = @import("daily.zig");

const Writer = std.Io.Writer;

const log = std.log.scoped(.site);

const root = @import("root.zig");
const File = root.File;
const assets = @import("assets.zig");
const Options = root.Options;
const isStatic = root.isStatic;
const Site = root.Site;
const shared_assets = root.shared_assets;
const shared_pages = root.shared_pages;
const unlisted_pages = root.unlisted_pages;
const pagePaths = root.pagePaths;
const filePath = root.filePath;
const urls = root.ui.urls;
const renderPage = root.renderPage;
const renderShared = root.renderShared;
const Extras = @import("extras.zig").Extras;
const loadParts = @import("load.zig").loadParts;
const loadAtOnce = @import("load.zig").loadAtOnce;
const unload = @import("load.zig").unload;

pub fn generate(gpa: std.mem.Allocator, io: std.Io, db: store.Db, opts: Options) !void {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, opts.out_dir);
    var root_dir = try cwd.openDir(io, opts.out_dir, .{});
    defer root_dir.close(io);
    const gz_window = try gpa.alloc(u8, store.raw.window_len);
    defer gpa.free(gz_window);
    if (opts.static == .core) return writeCore(gpa, io, opts, root_dir, gz_window, arena_state.allocator());
    var extras: Extras = .load(arena_state.allocator(), io, opts);
    defer extras.deinit(gpa, arena_state.allocator(), io);
    // The shared view first: every view's home shows its example and Daily Draft
    var views: [html.View.count]html.View = undefined;
    var n: usize = 0;
    for ([_]html.View{html.View.shared} ++ html.View.all, 0..) |v, i| {
        if (i > 0 and std.meta.eql(v, html.View.shared)) continue;
        if (opts.euw_only and v.region != .euw) continue;
        views[n] = v;
        n += 1;
    }
    // Loaded at once (Options.view_loads), then written in the order above; else each
    // loaded as it is written, one view in memory at a time
    var sites: [html.View.count]?*Site = @splat(null);
    defer for (sites) |s| if (s) |site| unload(site);
    if (opts.view_loads > 1) _ = try loadAtOnce(gpa, io, db, opts, views[0..n], &extras, null, &sites, keep);
    var home_files: []const File = &.{};
    for (views[0..n], 0..) |v, i| {
        const site = sites[v.index()] orelse try loadParts(gpa, io, db, opts, v, &extras, null);
        sites[v.index()] = null;
        defer unload(site);
        if (i == 0) home_files = try home_page.files(arena_state.allocator(), site.daily_files) else site.daily_files = home_files;
        try writeSite(site, root_dir, gz_window);
    }
}

/// Static.core: its files from the options, no view loaded
fn writeCore(gpa: std.mem.Allocator, io: std.Io, opts: Options, root_dir: std.Io.Dir, gz_window: []u8, arena: std.mem.Allocator) !void {
    const w: FileWriter = .{ .gpa = gpa, .io = io, .gz_window = gz_window };
    for (try root.coreFiles(arena, opts)) |f| try w.write(root_dir, f.path, f.data);
    for (shared_assets) |f| try w.write(root_dir, f.path, f.data);
    for (root.hashed_assets) |h| try w.write(root_dir, h.path, h.data);
}

fn keep(sites: *[html.View.count]?*Site, v: html.View, s: *Site) void {
    sites[v.index()] = s;
}

/// Every page and file of the view into its directory under `root_dir`, each with a .gz
/// twin for nginx's gzip_static
fn writeSite(site: *const Site, root_dir: std.Io.Dir, gz_window: []u8) !void {
    const io = site.io;
    const opts = site.opts;
    const vdir = site.view.dir();
    if (vdir.len > 0) try root_dir.createDirPath(io, vdir);
    var dir = if (vdir.len > 0) try root_dir.openDir(io, vdir, .{}) else root_dir;
    defer if (vdir.len > 0) dir.close(io);
    const w: FileWriter = .{ .gpa = site.gpa, .io = io, .gz_window = gz_window };
    for (site.files) |f| if (isStatic(opts, vdir, f.path)) try w.write(dir, f.path, f.data);
    for (site.shared_files) |f| if (isStatic(opts, "", f.path)) try w.write(root_dir, f.path, f.data);
    if (std.meta.eql(site.view, html.View.shared)) {
        for (shared_assets) |f| try w.write(root_dir, f.path, f.data);
        for (root.hashed_assets) |h| try w.write(root_dir, h.path, h.data);
    }

    var page_arena: std.heap.ArenaAllocator = .init(site.gpa);
    defer page_arena.deinit();
    var s = site.*;
    s.arena = page_arena.allocator();
    const pages = try pagePaths(site);
    var matchups: usize = 0;
    var champion_pages: usize = 0;
    for (pages) |at| {
        if (opts.static != .all) continue;
        _ = page_arena.reset(.retain_capacity);
        var aw: Writer.Allocating = .init(s.arena);
        if (!try renderPage(&s, &aw.writer, at)) return error.PageNotRouted;
        try w.write(root_dir, try filePath(s.arena, site.view, at), aw.written());
        if (at == .matchup) matchups += 1;
        if (at == .champion and at.champion.role == null) champion_pages += 1;
    }
    if (std.meta.eql(site.view, html.View.shared)) {
        // In the site's arena: the page arena is reset per page
        const daily_pages = try daily_page.pagePaths(site);
        for (shared_pages ++ unlisted_pages) |at| try writeShared(&s, w, root_dir, &page_arena, at);
        for (daily_pages) |at| try writeShared(&s, w, root_dir, &page_arena, at);
    }
    if (site.curves != null) log.info("{d} matchup pages", .{matchups});
    // deploy/web-loop.sh reads the first "patch" line: EUW's
    log.info("{s}/{s}: {s}, {d} games, {d} champion pages", .{
        site.opts.out_dir, site.view.dir(), site.when, site.games, champion_pages,
    });
}

/// A shared view's page, unless the static build leaves it to the renderer
fn writeShared(s: *const Site, w: FileWriter, root_dir: std.Io.Dir, page_arena: *std.heap.ArenaAllocator, at: urls.Page) !void {
    if (s.opts.static != .all) return;
    _ = page_arena.reset(.retain_capacity);
    var aw: Writer.Allocating = .init(s.arena);
    if (!try renderShared(s, &aw.writer, at)) return;
    try w.write(root_dir, try filePath(s.arena, html.View.all[0], at), aw.written());
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
    const positions = @import("core").Role.positions;
    for (games) |g| {
        const platform = g[0][0..std.mem.findScalar(u8, g[0], '_').?];
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
        .{ "champions/top.html", "in EUW, last 30 days, patch 16.20, 1 games" },
        .{ "_v/patch/champions/top.html", "in EUW, patch 16.20, 2 games" },
        .{ "_v/all/champions/top.html", "across all regions, last 30 days, patch 16.20, 2 games" },
        .{ "_v/all-patch/champions/top.html", "across all regions, patch 16.20, 3 games" },
        .{ "daily.html", "in EUW, patch 16.20, 2 games" },
    };
    for (want) |c| {
        const page = try read(arena, out, c[0]);
        try std.testing.expect(std.mem.find(u8, page, c[1]) != null);
    }
    // The champions board picks the view in its own toolbar; other view pages keep the
    // switches
    const tiers = try read(arena, out, "_v/all/champions.html");
    try std.testing.expect(std.mem.find(u8, tiers, "data-region=\"EUW1\"") == null);
    const pool = try read(arena, out, "_v/all/pool.html");
    for ([_][]const u8{
        "<a href=\"/pool?region=all&amp;period=patch\" data-period=\"patch\">Patch 16.20</a>",
        "<a href=\"/pool\" data-region=\"EUW1\">EUW</a>",
        "<a aria-disabled=\"true\" title=\"Champion pages only\" data-region=\"KR\">KR</a>",
        "<a aria-disabled=\"true\" title=\"Champion pages and the champions board only\" data-rank=\"6\">Diamond+</a>",
        "href=\"/" ++ @import("style.zig").file.path ++ "\"",
        "href=\"/daily\"",
    }) |s| try std.testing.expect(std.mem.find(u8, pool, s) != null);
    try std.testing.expect(std.mem.find(u8, tiers, "<a href=\"/champions?region=all&amp;period=patch\">Patch</a>") != null);
    // One page per champion, at the site root: the root view's, no switches until the
    // island takes the views
    const champ = try read(arena, out, "champions/a.html");
    for ([_][]const u8{
        "data-island=\"champion\" data-src=\"/data/champion/a.bin\"",
        "Ranked solo/duo in EUW, last 30 days",
        "href=\"/" ++ @import("style.zig").file.path ++ "\"",
        "<a href=\"/champions\" aria-current=\"page\" data-view=\"\">",
    }) |s| try std.testing.expect(std.mem.find(u8, champ, s) != null);
    try std.testing.expect(std.mem.find(u8, champ, "data-region=\"KR\"") == null);
    try std.testing.expectError(error.FileNotFound, read(arena, out, "_v/all/champions/a.html"));
    const shared_page = try read(arena, out, "daily.html");
    try std.testing.expect(std.mem.find(u8, shared_page, "<a href=\"/champions\" data-view=\"\">") != null);
    try std.testing.expectError(error.FileNotFound, read(arena, out, "_v/all/daily.html"));
    try std.testing.expectError(error.FileNotFound, read(arena, out, "_v/patch/style.css"));
    // Under Champions: the section's tabs and the switches; not on home or shared pages
    for ([_][]const u8{
        "<nav class=\"section\" aria-label=\"Champions\">",
        "<a href=\"/matchups?region=all\">Matchups</a>",
    }) |s| try std.testing.expect(std.mem.find(u8, tiers, s) != null);
    try std.testing.expect(std.mem.find(u8, shared_page, "class=\"subbar\"") == null);
    // Home in a view: the lookup and its islands, their script at the site root
    const home = try read(arena, out, "_v/all/index.html");
    for ([_][]const u8{
        "data-island=\"lookup\" data-to=\"/your\"",
        "<form class=\"box\" method=\"get\" role=\"search\" action=\"/your\"",
        "<script src=\"/" ++ assets.home_js.path ++ "\" data-wasm=\"",
    }) |s| try std.testing.expect(std.mem.find(u8, home, s) != null);
    try std.testing.expect(std.mem.find(u8, home, "class=\"subbar\"") == null);
    _ = try read(arena, out, "print.css");
    // Pages link the hashed names only
    try std.testing.expectError(error.FileNotFound, read(arena, out, "style.css"));
    for (root.hashed_assets) |h| try std.testing.expectEqualStrings(h.data, try read(arena, out, h.path));
}
