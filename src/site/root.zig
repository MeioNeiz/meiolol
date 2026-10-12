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
    /// Champion slugs whose pages get the filter bar (filters.zig; a prototype)
    filter_champions: []const []const u8 = &.{"ahri"},
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

pub const Site = struct {
    gpa: std.mem.Allocator,
    arena: std.mem.Allocator,
    io: std.Io,
    /// The view's directory, and the site root for shared pages
    dir: std.Io.Dir,
    root_dir: std.Io.Dir,
    stats: Stats,
    champs: []Champ,
    /// Stats index -> champs index
    by_c: []?usize,
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

    /// A page of the view at `path` within it
    pub fn page(s: *const Site, title: []const u8, description: []const u8, path: []const u8, nav: html.Nav) html.Page {
        var p = s.sharedPage(title, description, nav);
        p.view = s.view;
        p.counterparts = @splat(path);
        p.root = s.toRoot(path);
        return p;
    }

    /// A page at the site root, written once (from html.View.shared)
    pub fn sharedPage(s: *const Site, title: []const u8, description: []const u8, nav: html.Nav) html.Page {
        return .{
            .title = title,
            .description = description,
            .nav = nav,
            .patch = s.patch,
            .data = std.fmt.allocPrint(s.arena, "{s}, {s}, {d} games", .{ s.view.region.in(), s.when, s.games }) catch "",
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

    /// Into the view's directory
    pub fn write(s: *const Site, path: []const u8, data: []const u8) !void {
        return s.writeIn(s.dir, path, data);
    }

    /// At the site root
    pub fn writeShared(s: *const Site, path: []const u8, data: []const u8) !void {
        return s.writeIn(s.root_dir, path, data);
    }

    /// Also `path`.gz for `meiolol serve` to send to clients that accept gzip
    fn writeIn(s: *const Site, dir: std.Io.Dir, path: []const u8, data: []const u8) !void {
        if (std.fs.path.dirname(path)) |d| try dir.createDirPath(s.io, d);
        try dir.writeFile(s.io, .{ .sub_path = path, .data = data });
        if (data.len < 1024) return;
        const gz = try store.raw.compress(s.gpa, data);
        defer s.gpa.free(gz);
        const gz_path = try std.fmt.allocPrint(s.arena, "{s}.gz", .{path});
        try dir.writeFile(s.io, .{ .sub_path = gz_path, .data = gz });
    }

    pub fn icon(s: *const Site, ch: Champ) []const u8 {
        return std.fmt.allocPrint(
            s.arena,
            "https://ddragon.leagueoflegends.com/cdn/{s}/img/champion/{s}.png",
            .{ s.ddragon_version, ch.key },
        ) catch "";
    }

    pub fn champLink(s: *const Site, w: *Writer, ch: Champ, root: []const u8) !void {
        try w.print(
            "<a class=\"champ\" href=\"{s}champion/{s}.html\"><img src=\"{s}\" alt=\"\" loading=\"lazy\" width=\"32\" height=\"32\">{f}</a>",
            .{ root, ch.slug, s.icon(ch), esc(ch.name) },
        );
    }

    fn pickRate(s: *const Site, games: u64) f64 {
        return if (s.games == 0) 0 else @as(f64, @floatFromInt(games)) / @as(f64, @floatFromInt(s.games));
    }
};

pub fn generate(gpa: std.mem.Allocator, io: std.Io, db: store.Db, opts: Options) !void {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var view_curves: [html.View.count]?core.curvesfile.Curves = @splat(null);
    for (opts.curves, &view_curves) |path, *c| {
        if (path) |p| c.* = loadCurves(arena, io, p);
    }
    var view_builds: [html.View.count]?builds.File = @splat(null);
    for (opts.builds, &view_builds) |path, *b| {
        if (path) |p| b.* = loadBuilds(arena, io, p);
    }
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, opts.out_dir);
    var root_dir = try cwd.openDir(io, opts.out_dir, .{});
    defer root_dir.close(io);
    for (html.View.all) |v| try generateView(gpa, io, db, opts, v, root_dir, &view_curves, &view_builds);
}

fn generateView(
    gpa: std.mem.Allocator,
    io: std.Io,
    db: store.Db,
    all_opts: Options,
    view: html.View,
    root_dir: std.Io.Dir,
    view_curves: *const [html.View.count]?core.curvesfile.Curves,
    view_builds: *const [html.View.count]?builds.File,
) !void {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

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

    const sub = if (view.dir().len == 0) "." else view.dir();
    try root_dir.createDirPath(io, sub);
    var dir = try root_dir.openDir(io, sub, .{});
    defer dir.close(io);

    var site: Site = .{
        .gpa = gpa,
        .arena = arena,
        .io = io,
        .dir = dir,
        .root_dir = root_dir,
        .stats = try .parse(arena, model_bytes),
        .champs = &.{},
        .by_c = &.{},
        .games = built.summary.games,
        .patch = patch,
        .when = switch (view.period) {
            .patch => try std.fmt.allocPrint(arena, "patch {s}", .{patch}),
            .days30 => "last 30 days",
        },
        .ddragon_version = "",
        .view = view,
        .since_ms = since_ms,
        .opts = opts,
        .curves = view_curves[view.index()],
        .view_curves = view_curves,
        .view_builds = view_builds,
    };
    try loadChamps(&site, db);

    if (shared) {
        try site.writeShared("style.css", @embedFile("static/style.css"));
        try site.writeShared("favicon.svg", @embedFile("static/favicon.svg"));
        try site.writeShared("daily.js", @embedFile("static/daily.js"));
        try site.writeShared("your.js", @embedFile("static/your.js"));
        try site.writeShared("learn.js", @embedFile("static/learn.js"));
        try site.writeShared("table.js", @embedFile("static/table.js"));
        try site.writeShared("filters.js", @embedFile("static/filters.js"));
        try site.writeShared("meiolol.wasm", @embedFile("draft.wasm"));
        if (opts.riot_txt) |t| try site.writeShared("riot.txt", t);
        try site.writeShared("robots.txt", if (opts.public) "User-agent: *\nAllow: /\n" else "User-agent: *\nDisallow: /\n");
        try filters.write(&site, db, all_opts);
    }
    try site.write("data/stats.bin", model_bytes);
    try writeChampionsJson(&site);
    site.pool = try pool.make(gpa, arena, db, &site.stats, opts.platforms, .{});
    {
        var aw: Writer.Allocating = .init(arena);
        try pool.writeJson(&aw.writer, site.pool);
        try site.write("data/pool.json", aw.written());
    }
    site.learning = try learning.make(gpa, arena, db, &site.stats, opts.platforms, .{});
    {
        var aw: Writer.Allocating = .init(arena);
        try learning.writeJson(&aw.writer, site.learning);
        try site.write("data/learning.json", aw.written());
    }
    try site.write("pool.js", @embedFile("static/pool.js"));
    try site.write("min-games.js", @embedFile("static/min-games.js"));

    if (opts.daily_dir) |d| {
        const day: u32 = @intCast(@divFloor(std.Io.Clock.real.now(io).toSeconds(), std.time.s_per_day));
        const files = daily.update(arena, io, db, &site.stats, .{
            .dir = d,
            .patches = opts.patches,
            .platforms = opts.platforms,
            .today = day,
        }) catch |err| blk: {
            log.warn("daily draft: {t}", .{err});
            break :blk &.{};
        };
        for (files) |f| try site.writeShared(f.path, f.data);
    }
    // After the Daily Draft, so practice leaves out the games behind its puzzles
    if (shared) {
        const day: u32 = @intCast(@divFloor(std.Io.Clock.real.now(io).toSeconds(), std.time.s_per_day));
        if (learn.build(arena, io, db, &site.stats, if (site.curves) |*c| c else null, .{
            .patches = opts.patches,
            .platforms = opts.platforms,
            .today = day,
            .daily_dir = opts.daily_dir,
        })) |l| {
            for (l.files) |f| try site.writeShared(f.path, f.data);
            try learn_page.write(&site, &l.facts);
        } else |err| log.warn("learn: {t}", .{err});
    }

    try writeIndex(&site);
    try writeTierList(&site, null);
    for (Role.all) |r| try writeTierList(&site, r);
    for (site.champs) |ch| try writeChampion(&site, ch);
    if (site.curves) |*c| try matchup.writeAll(&site, c);
    try matchup.writeIndex(&site, if (site.curves) |*c| c else null);
    if (view.period == .patch) if (view_builds[view.index()]) |*b| try builds_page.writeAll(&site, b);
    try pool_page.writePage(&site, &site.pool, &site.learning);
    const info: prose.Info = .{
        .contact = opts.contact,
        .updated = opts.updated,
        .curves = biggestCurves(site.view_curves),
    };
    const fixed = [_]struct { []const u8, []const u8, []const u8, html.Nav, *const fn (*Writer, prose.Info) Writer.Error!void }{
        .{ "method.html", "Method", "Where meiolol's numbers come from and how lane curves, champion statistics and the Daily Draft are made.", .method, prose.method },
        .{ "daily.html", "Daily Draft", "Guess the hidden champion and the winner of a real ranked draft, then see what the numbers say.", .daily, daily_page.page },
        .{ "download.html", "Desktop app", "The meiolol desktop app for Windows, in development.", .none, prose.download },
        .{ "your.html", "Your games", "Your lane in each recent ranked game, minute by minute, against how the matchup typically goes at your rank.", .none, your_page.page },
        .{ "privacy.html", "Privacy policy", "What meiolol collects and why.", .none, prose.privacy },
        .{ "terms.html", "Terms of use", "Terms for using meiolol.", .none, prose.terms },
    };
    if (shared) for (fixed) |f| {
        var aw: Writer.Allocating = .init(arena);
        const p = site.sharedPage(try std.fmt.allocPrint(arena, "{s} | meiolol", .{f[1]}), f[2], f[3]);
        try html.head(&aw.writer, p);
        try f[4](&aw.writer, info);
        try html.foot(&aw.writer, p);
        try site.writeShared(f[0], aw.written());
    };
    // deploy/web-loop.sh reads the first "patch" line: EUW's
    log.info("{s}/{s}: {s}, {d} games, {d} champion pages", .{
        opts.out_dir, view.dir(), site.when, site.games, site.champs.len,
    });
}

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

fn writeChampionsJson(site: *const Site) !void {
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
    try site.write("data/champions.json", aw.written());
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
        "<td data-v=\"{d:.4}\"><span class=\"wr\" style=\"--c:oklch(0.76 0.15 {d:.0})\"><span class=\"ci\" title=\"95%: {d:.1}% to {d:.1}%, {d} games\">" ++
            "<i class=\"r\" style=\"left:{d:.1}%;width:{d:.1}%\"></i><i class=\"d\" style=\"left:{d:.1}%\"></i></span>" ++
            "<b>{d:.1}%</b><small>±{d:.1}</small></span></td>",
        .{
            p,       wrHue(p, span),       100 * iv[0],                       100 * iv[1],
            games,   at(iv[0], span),      at(iv[1], span) - at(iv[0], span), at(p, span),
            100 * p, 50 * (iv[1] - iv[0]),
        },
    );
}

/// Oklch hue for a win rate: red through amber to green, full red or green at 50% ± 40%
/// of the bar's `span` (±5 points on the champions table, ±10 against an opponent)
fn wrHue(p: f64, span: f64) f64 {
    const red = 25;
    const green = 150;
    const t = std.math.clamp((p - 0.5) / (0.4 * span), -1, 1);
    return red + (green - red) * (t + 1) / 2;
}

fn earlyNote(site: *const Site, w: *Writer) !void {
    if (site.games >= 50_000) return;
    try w.print(
        "<p class=\"note\">Early data: {d} games so far ({s}). Each bar shows where a win rate likely is (95%) and narrows as games come in. Colour runs from red (low) through amber to green (high).</p>\n",
        .{ site.games, site.when },
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
        try site.champLink(w, row.ch, root);
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

fn writeTierList(site: *const Site, role: ?Role) !void {
    const a = site.arena;
    var aw: Writer.Allocating = .init(a);
    const w = &aw.writer;
    const name = if (role) |r| roleName(r) else "All";
    const title = if (role) |r|
        try std.fmt.allocPrint(a, "{s} lane champions, {s} | meiolol", .{ roleName(r), site.when })
    else
        try std.fmt.allocPrint(a, "Champions, {s} | meiolol", .{site.when});
    const desc = try std.fmt.allocPrint(a, "{s} champions in ranked solo queue {s}, {s}: win rate with how sure it is, pick and ban rates.", .{ name, site.view.region.in(), site.when });
    const path = if (role) |r| try std.fmt.allocPrint(a, "role/{s}.html", .{roleSlug(r)}) else "champions.html";
    const root = site.toRoot(path);
    const p = site.page(title, desc, path, .champions);
    try html.head(w, p);
    if (role) |r| {
        try w.print("<h1>{s} lane champions</h1>\n", .{roleName(r)});
    } else try w.writeAll("<h1>Champions</h1>\n");
    try w.print("<p class=\"muted\"><b>{d}</b> ranked solo/duo games {s}, {s}, all ranks.</p>\n", .{ site.games, site.view.region.in(), site.when });
    try earlyNote(site, w);
    try tierTable(site, w, role, root);
    try html.foot(w, p);
    try site.write(path, aw.written());
}

fn writeIndex(site: *const Site) !void {
    const a = site.arena;
    var aw: Writer.Allocating = .init(a);
    const w = &aw.writer;
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
    try w.writeAll(
        \\<h1>Learn your lane</h1>
        \\<p class="lead">How lane matchups actually unfold, minute by minute, and how your
        \\own games compare. From ranked match timelines: the typical gold, experience and CS
        \\curve of every lane matchup by rank, with the spread and the number of games behind
        \\it. Champion and aggregate data only; never other players, never "the best pick".</p>
        \\<div class="grid">
        \\<div class="card"><h3><a href="matchup/index.html">Matchup curves</a></h3>
        \\
    );
    if (matchups > 0) {
        try w.print("<p>{d} lane matchups so far: when each side tends to get ahead, by how much, and whether winning lane wins the game.</p></div>\n", .{matchups});
    } else {
        try w.writeAll("<p>When each side of a lane matchup tends to get ahead, by how much, and whether winning lane wins the game. Curves appear as match timelines come in.</p></div>\n");
    }
    try w.print(
        \\<div class="card"><h3><a href="{0s}daily.html">Daily Draft</a></h3>
        \\<p>One real ranked draft a day, anonymised. Guess the hidden champion and the
        \\winner, then see what happened and what the numbers say. Keep a streak, share
        \\your grid.</p></div>
        \\<div class="card"><h3><a href="{0s}learn.html">New to League? Start with Learn</a></h3>
        \\<p>Five short lessons on draft in plain words, with real examples, then practice on
        \\real ranked drafts with every option explained. No timers, no streaks.</p></div>
        \\<div class="card"><h3><a href="{0s}your.html">Your games</a></h3>
        \\<p>Enter your Riot ID and see each recent game's lane laid over the typical curve
        \\for that matchup at your rank, and your record per matchup over the months.</p></div>
        \\<div class="card"><h3><a href="pool.html">Champion pool</a></h3>
        \\<p>Champions that players of your main also play, which of them cover your
        \\main's hardest lanes, and what they play when it is banned.</p></div>
        \\</div>
        \\
    , .{site.view.up()});
    try w.print("<h2>Champions</h2>\n<p class=\"muted\"><b>{d}</b> ranked solo/duo games {s}, {s}, all ranks. <a href=\"{s}method.html\">How the numbers are made</a></p>\n", .{ site.games, site.view.region.in(), site.when, site.view.up() });
    try earlyNote(site, w);
    try tierTable(site, w, null, "");
    try html.foot(w, p);
    try site.write("index.html", aw.written());
}

const Opponent = struct {
    other: Champ,
    games: u32,
    wins: u32,
    iv: [2]f64,
};

fn writeChampion(site: *const Site, ch: Champ) !void {
    const a = site.arena;
    const st = &site.stats;
    var aw: Writer.Allocating = .init(a);
    const w = &aw.writer;
    const title = try std.fmt.allocPrint(a, "{s} win rate, lane opponents and curves, {s} | meiolol", .{ ch.name, site.when });
    const desc = try std.fmt.allocPrint(a, "{s} in ranked solo queue {s}, {s}: win rate with how sure it is, every lane opponent and lane curves.", .{ ch.name, site.view.region.in(), site.when });
    const path = try std.fmt.allocPrint(a, "champion/{s}.html", .{ch.slug});
    const p = site.page(title, desc, path, .champions);
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
    try earlyNote(site, w);
    const filtered = for (site.opts.filter_champions) |f| {
        if (std.mem.eql(u8, f, ch.slug)) break true;
    } else false;
    if (filtered) try filterBar(site, w, ch);
    if (n_roles == 0) try w.writeAll("<p>No games yet.</p>\n");

    for (roles[0..n_roles]) |r| {
        const cr = st.champRole(r, ch.c);
        const iv = wilson(cr.wins, cr.games);
        try w.print("<section id=\"{s}\"><h2>{s}</h2>\n<div class=\"tiles\">", .{ roleSlug(r), roleName(r) });
        try w.print("<div data-tile=\"wr\"><span>Win rate</span><b class=\"{s}\">", .{side(iv)});
        try pct(w, cr.wins, cr.games);
        try w.print("</b><small>{d:.1}% to {d:.1}%</small></div><div data-tile=\"view\"><span>Pick rate</span><b>", .{ 100 * iv[0], 100 * iv[1] });
        try pct(w, cr.games, site.games);
        try w.writeAll("</b><small>of games</small></div><div data-tile=\"view\"><span>Ban rate</span><b>");
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
    try w.print("<p class=\"muted small\">Win rates are raw: no pulling toward 50%. Bars are 95% Wilson intervals. Gold at {d} min is the lane curve's estimate (± two standard errors). <a href=\"{s}method.html\">Method</a>.</p>\n", .{ core.curvesfile.lane_minute, site.toShared(path) });
    try w.print("<script src=\"../{s}table.js\" defer></script>\n", .{site.view.up()});
    if (filtered) try w.print("<script src=\"../{s}filters.js\" defer></script>\n", .{site.view.up()});
    try html.foot(w, p);
    try site.write(path, aw.written());
}

/// Filter bar (filters.zig, static/filters.js): hidden until the script fills it from
/// the champion's filter data. Its defaults are this view's region and period
fn filterBar(site: *const Site, w: *Writer, ch: Champ) !void {
    try w.print(
        "<div class=\"filter-bar\" hidden data-src=\"../{s}data/filters/{s}.json\" data-champions=\"../data/champions.json\" data-ddragon=\"{s}\" data-region=\"{s}\" data-period=\"{s}\">",
        .{ site.view.up(), ch.slug, site.ddragon_version, if (site.view.region == .euw) site.opts.platforms[0] else "all", @tagName(site.view.period) },
    );
    try w.writeAll(
        \\<label>Region <select data-f="region"></select></label>
        \\<label>Rank <select data-f="rank"></select></label>
        \\<label>Period <select data-f="period"></select></label>
        \\<label>Opponents <select data-f="min"></select></label>
        \\<button class="link" data-reset hidden>Reset</button></div>
        \\
    );
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
            return ratio(x.wins, x.games) < ratio(y.wins, y.games);
        }
    }.f);
    try w.print(
        \\<div class="tl-bar"><h3 class="opp-h">Lane opponents <span class="muted">{d}, hardest first</span></h3>
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
    const out = try std.fmt.allocPrint(arena, ".zig-cache/tmp/{s}/site", .{&tmp.sub_path});
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
    const champ = try read(arena, out, "all/champion/a.html");
    for ([_][]const u8{
        "<a href=\"../../all/patch/champion/a.html\">Patch 16.20</a>",
        "<a href=\"../../champion/a.html\">EUW</a>",
        "href=\"../../style.css\"",
        "href=\"../../daily.html\"",
        "href=\"../champions.html\"",
    }) |s| try std.testing.expect(std.mem.indexOf(u8, champ, s) != null);
    const shared_page = try read(arena, out, "daily.html");
    try std.testing.expect(std.mem.indexOf(u8, shared_page, "<a href=\"champions.html\" data-view>") != null);
    try std.testing.expectError(error.FileNotFound, read(arena, out, "all/daily.html"));
    try std.testing.expectError(error.FileNotFound, read(arena, out, "patch/style.css"));
}
