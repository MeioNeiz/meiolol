//! The static build (`meiolol site`): every view's pages and files into Options.out_dir

const std = @import("std");
const store = @import("store");
const html = @import("html.zig");

const Writer = std.Io.Writer;

const log = std.log.scoped(.site);

const root = @import("root.zig");
const Options = root.Options;
const isStatic = root.isStatic;
const Site = root.Site;
const shared_assets = root.shared_assets;
const view_assets = root.view_assets;
const shared_pages = root.shared_pages;
const pagePaths = root.pagePaths;
const renderPage = root.renderPage;
const renderShared = root.renderShared;
const Extras = @import("extras.zig").Extras;
const loadParts = @import("load.zig").loadParts;
const unload = @import("load.zig").unload;

pub fn generate(gpa: std.mem.Allocator, io: std.Io, db: store.Db, opts: Options) !void {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    var extras: Extras = .load(arena_state.allocator(), io, opts);
    defer extras.deinit(gpa, arena_state.allocator(), io);
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, opts.out_dir);
    var root_dir = try cwd.openDir(io, opts.out_dir, .{});
    defer root_dir.close(io);
    const gz_window = try gpa.alloc(u8, store.raw.window_len);
    defer gpa.free(gz_window);
    for (html.View.all) |v| {
        if (opts.euw_only and v.region != .euw) continue;
        // Static.core: only the root's files, from the root view and the shared one
        if (opts.static == .core and v.index() != 0 and !std.meta.eql(v, html.View.shared)) continue;
        const site = try loadParts(gpa, io, db, opts, v, &extras, null);
        defer unload(site);
        try writeSite(site, root_dir, gz_window);
    }
}

/// Every page and file of the view into its directory under `root_dir`, each with a .gz
/// twin for nginx's gzip_static
fn writeSite(site: *const Site, root_dir: std.Io.Dir, gz_window: []u8) !void {
    const io = site.io;
    const opts = site.opts;
    const vdir = site.view.dir();
    // Static.core writes nothing into a view's own directory, so makes none
    const own = vdir.len == 0 or opts.static == .all;
    if (own and vdir.len > 0) try root_dir.createDirPath(io, vdir);
    var dir = if (own) try root_dir.openDir(io, if (vdir.len == 0) "." else vdir, .{}) else root_dir;
    defer if (own) dir.close(io);
    const w: FileWriter = .{ .gpa = site.gpa, .io = io, .gz_window = gz_window };
    for (site.files) |f| if (isStatic(opts, vdir, f.path)) try w.write(dir, f.path, f.data);
    for (site.shared_files) |f| if (isStatic(opts, "", f.path)) try w.write(root_dir, f.path, f.data);
    if (std.meta.eql(site.view, html.View.shared)) {
        for (shared_assets) |f| try w.write(root_dir, f.path, f.data);
    }
    for (view_assets) |f| if (isStatic(opts, vdir, f.path)) try w.write(dir, f.path, f.data);

    var page_arena: std.heap.ArenaAllocator = .init(site.gpa);
    defer page_arena.deinit();
    var s = site.*;
    s.arena = page_arena.allocator();
    const paths = try pagePaths(site);
    var matchups: usize = 0;
    var build_pages: usize = 0;
    var champion_pages: usize = 0;
    for (paths) |path| {
        if (!isStatic(opts, vdir, path)) continue;
        _ = page_arena.reset(.retain_capacity);
        var aw: Writer.Allocating = .init(s.arena);
        if (!try renderPage(&s, &aw.writer, path)) return error.PageNotRouted;
        try w.write(dir, path, aw.written());
        if (std.mem.startsWith(u8, path, "matchup/") and !std.mem.eql(u8, path, "matchup/index.html")) matchups += 1;
        if (std.mem.startsWith(u8, path, "build/")) build_pages += 1;
        if (std.mem.startsWith(u8, path, "champion/")) champion_pages += 1;
    }
    if (std.meta.eql(site.view, html.View.shared)) for (shared_pages) |path| {
        if (!isStatic(opts, "", path)) continue;
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
        .{ "role/top.html", "in EUW, last 30 days, patch 16.20, 1 games" },
        .{ "patch/role/top.html", "in EUW, patch 16.20, 2 games" },
        .{ "all/role/top.html", "across all regions, last 30 days, patch 16.20, 2 games" },
        .{ "all/patch/role/top.html", "across all regions, patch 16.20, 3 games" },
        .{ "daily.html", "in EUW, patch 16.20, 2 games" },
    };
    for (want) |c| {
        const page = try read(arena, out, c[0]);
        try std.testing.expect(std.mem.find(u8, page, c[1]) != null);
    }
    const tiers = try read(arena, out, "all/champions.html");
    for ([_][]const u8{
        "<a href=\"../all/patch/champions.html\" data-period=\"patch\">Patch 16.20</a>",
        "<a href=\"../champions.html\" data-region=\"EUW1\">EUW</a>",
        "<a aria-disabled=\"true\" title=\"Champion pages only\" data-region=\"KR\">KR</a>",
        "<a aria-disabled=\"true\" title=\"Champion pages only\" data-rank=\"6\">Diamond+</a>",
        "href=\"../style.css\"",
        "href=\"../daily.html\"",
        "href=\"../champion/a.html?region=all\"",
    }) |s| try std.testing.expect(std.mem.find(u8, tiers, s) != null);
    // One page per champion, at the site root: its switches set the filters
    const champ = try read(arena, out, "champion/a.html");
    for ([_][]const u8{
        "<a href=\"../champion/a.html?period=patch\" data-period=\"patch\">Patch 16.20</a>",
        "<a aria-current=\"page\" data-region=\"EUW1\">EUW</a>",
        "<a href=\"../champion/a.html?region=KR\" data-region=\"KR\">KR</a>",
        "<a href=\"../champion/a.html?rank=6\" data-rank=\"6\">Diamond+</a>",
        "<span data-foot>in EUW, last 30 days",
        "href=\"../style.css\"",
        "<a href=\"../champions.html\" aria-current=\"page\" data-view>",
    }) |s| try std.testing.expect(std.mem.find(u8, champ, s) != null);
    try std.testing.expectError(error.FileNotFound, read(arena, out, "all/champion/a.html"));
    const shared_page = try read(arena, out, "daily.html");
    try std.testing.expect(std.mem.find(u8, shared_page, "<a href=\"champions.html\" data-view>") != null);
    try std.testing.expectError(error.FileNotFound, read(arena, out, "all/daily.html"));
    try std.testing.expectError(error.FileNotFound, read(arena, out, "patch/style.css"));
    // Under Champions: the section's tabs and the switches; not on home or shared pages
    for ([_][]const u8{
        "<nav class=\"section\" aria-label=\"Champions\">",
        "<a href=\"matchup/index.html\">Matchups</a>",
    }) |s| try std.testing.expect(std.mem.find(u8, tiers, s) != null);
    try std.testing.expect(std.mem.find(u8, shared_page, "class=\"subbar\"") == null);
    // Home in a view: the lookup and the review demo, its scripts at the site root
    const home = try read(arena, out, "all/index.html");
    for ([_][]const u8{
        "<form class=\"search\" action=\"../your.html\"",
        "<script src=\"../review.js\" defer></script>",
        "<script src=\"../home.js\" data-root=\"../\" defer></script>",
        "against ranked games in EUW on that game's patch",
    }) |s| try std.testing.expect(std.mem.find(u8, home, s) != null);
    try std.testing.expect(std.mem.find(u8, home, "class=\"subbar\"") == null);
    const your = try read(arena, out, "your.html");
    try std.testing.expect(std.mem.find(u8, your, "<script src=\"review.js\" defer></script>\n<script src=\"your.js\" defer></script>") != null);
    for ([_][]const u8{ "review.js", "home.js", "inter.woff2" }) |f| _ = try read(arena, out, f);
}
