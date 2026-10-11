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
};

/// Below this share of all games a champion is left out of a role's page
const min_pick_rate = 0.004;
/// And below this share of the champion's own games, as a role it rarely plays
const min_role_share = 0.1;
const matchups_shown = 6;
/// Win rates, edges and draft ratings are noisy at today's volume (draft model eval:
/// level with a coin flip on 6k games). A pair edge is shown only with this many games
/// and when it clears chance (|pp| > 1.96 SE, SE = 50 / sqrt(n) points)
const min_pair_games = 400;
/// Below this a champion's role win rate is marked as few games
const min_role_games = 300;
/// Champion-page minimum games choices (html.minGames); the last is the default, where a
/// pair must also clear chance. Below it pairs are greyed out
const pair_floors = [_]u32{ 1, 10, 20, 50, 100, 200, min_pair_games };
const duos_shown = 6;

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
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, opts.out_dir);
    var root_dir = try cwd.openDir(io, opts.out_dir, .{});
    defer root_dir.close(io);
    for (html.View.all) |v| try generateView(gpa, io, db, opts, v, root_dir, &view_curves);
}

fn generateView(
    gpa: std.mem.Allocator,
    io: std.Io,
    db: store.Db,
    all_opts: Options,
    view: html.View,
    root_dir: std.Io.Dir,
    view_curves: *const [html.View.count]?core.curvesfile.Curves,
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
    };
    try loadChamps(&site, db);

    if (shared) {
        try site.writeShared("style.css", @embedFile("static/style.css"));
        try site.writeShared("favicon.svg", @embedFile("static/favicon.svg"));
        try site.writeShared("daily.js", @embedFile("static/daily.js"));
        try site.writeShared("your.js", @embedFile("static/your.js"));
        try site.writeShared("learn.js", @embedFile("static/learn.js"));
        try site.writeShared("meiolol.wasm", @embedFile("draft.wasm"));
        if (opts.riot_txt) |t| try site.writeShared("riot.txt", t);
        try site.writeShared("robots.txt", if (opts.public) "User-agent: *\nAllow: /\n" else "User-agent: *\nDisallow: /\n");
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
    for (Role.all) |r| try writeRole(&site, r);
    for (site.champs) |ch| try writeChampion(&site, ch);
    if (site.curves) |*c| try matchup.writeAll(&site, c);
    try matchup.writeIndex(&site, if (site.curves) |*c| c else null);
    try pool_page.writePage(&site, &site.pool, &site.learning);
    const info: prose.Info = .{ .contact = opts.contact, .updated = opts.updated };
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

/// Optional extras: a bad or old file leaves out matchup pages, not the site
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
    games: u32,
    wins: u32,
};

/// Champions played enough in `r`, most played first. Not ranked by win rate: the site
/// describes champions, it does not grade picks (docs/concept.md)
fn roleRows(site: *const Site, r: Role) ![]Row {
    var rows: std.ArrayList(Row) = .empty;
    for (site.champs) |ch| {
        const cr = site.stats.champRole(r, ch.c);
        if (cr.games == 0) continue;
        const share = @as(f64, @floatFromInt(cr.games)) / @as(f64, @floatFromInt(@max(ch.games, 1)));
        if (site.pickRate(cr.games) < min_pick_rate or share < min_role_share) continue;
        try rows.append(site.arena, .{
            .ch = ch,
            .games = cr.games,
            .wins = cr.wins,
        });
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

fn earlyNote(site: *const Site, w: *Writer) !void {
    if (site.games >= 50_000) return;
    try w.print(
        "<p class=\"note\">Early data: {d} games so far ({s}). Numbers settle as more games come in; champions with few games are pulled toward 50%.</p>\n",
        .{ site.games, site.when },
    );
}

fn roleTabs(w: *Writer, current: ?Role, root: []const u8) !void {
    try w.writeAll("<nav class=\"tabs\">");
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

fn writeRole(site: *const Site, r: Role) !void {
    const a = site.arena;
    var aw: Writer.Allocating = .init(a);
    const w = &aw.writer;
    const title = try std.fmt.allocPrint(a, "{s} lane champions, {s} | meiolol", .{ roleName(r), site.when });
    const desc = try std.fmt.allocPrint(a, "{s} lane champions in ranked solo queue {s}, {s}: games, win, pick and ban rates.", .{ roleName(r), site.view.region.in(), site.when });
    const path = try std.fmt.allocPrint(a, "role/{s}.html", .{roleSlug(r)});
    const p = site.page(title, desc, path, .champions);
    try html.head(w, p);
    try w.print("<h1>{s} lane champions</h1>\n<p class=\"muted\">Ranked solo/duo {s}, {s}, all ranks. Most played first; greyed under {d} games.</p>\n", .{ roleName(r), site.view.region.in(), site.when, min_role_games });
    try roleTabs(w, r, "../");
    try earlyNote(site, w);
    try w.writeAll(
        \\<div class="table-scroll"><table>
        \\<thead><tr><th>Champion</th><th class="num">Games</th><th class="num">Win rate</th><th class="num">Pick rate</th><th class="num">Ban rate</th></tr></thead>
        \\<tbody>
        \\
    );
    for (try roleRows(site, r)) |row| {
        try w.print("<tr{s}><td>", .{if (row.games < min_role_games) " class=\"thin\"" else ""});
        try site.champLink(w, row.ch, "../");
        try w.print("</td><td class=\"num\">{d}</td><td class=\"num\">", .{row.games});
        try pct(w, row.wins, row.games);
        try w.writeAll("</td><td class=\"num\">");
        try pct(w, row.games, site.games);
        try w.writeAll("</td><td class=\"num\">");
        try pct(w, row.ch.banned, site.games);
        try w.writeAll("</td></tr>\n");
    }
    try w.writeAll("</tbody></table></div>\n");
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
    try earlyNote(site, w);
    try w.writeAll("<h2>Champions</h2>\n");
    try roleTabs(w, null, "");
    try w.writeAll("<p>");
    for (site.champs, 0..) |ch, i| {
        if (i > 0) try w.writeAll(" · ");
        try w.print("<a href=\"champion/{s}.html\">{f}</a>", .{ ch.slug, esc(ch.name) });
    }
    try w.print("</p>\n<p class=\"muted\"><a href=\"{s}method.html\">How the numbers are made</a></p>\n", .{site.view.up()});
    try html.foot(w, p);
    try site.write("index.html", aw.written());
}

const Pair = struct {
    other: usize,
    role: Role,
    pp: f64,
    games: u32,
    wins: u32,
    clear: bool,

    fn passes(p: Pair, floor: u32) bool {
        return p.games >= floor and (floor < min_pair_games or p.clear);
    }
};

fn byPpDesc(_: void, a: Pair, b: Pair) bool {
    return a.pp > b.pp;
}

fn byPpAsc(_: void, a: Pair, b: Pair) bool {
    return a.pp < b.pp;
}

/// The pairs a card shows at any of pair_floors (the first `n` passing at
/// each), in order
fn shownAtAnyFloor(a: std.mem.Allocator, pairs: []const Pair, n: usize) ![]const Pair {
    const keep = try a.alloc(bool, pairs.len);
    @memset(keep, false);
    for (pair_floors) |floor| {
        var shown: usize = 0;
        for (pairs, keep) |p, *k| {
            if (shown == n) break;
            if (!p.passes(floor)) continue;
            k.* = true;
            shown += 1;
        }
    }
    var out: std.ArrayList(Pair) = .empty;
    for (pairs, keep) |p, k| if (k) try out.append(a, p);
    return out.items;
}

fn writeChampion(site: *const Site, ch: Champ) !void {
    const a = site.arena;
    const st = &site.stats;
    var aw: Writer.Allocating = .init(a);
    const w = &aw.writer;
    const title = try std.fmt.allocPrint(a, "{s} lane opponents, teammates and curves, {s} | meiolol", .{ ch.name, site.when });
    const desc = try std.fmt.allocPrint(a, "{s} in ranked solo queue {s}, {s}: games, win rate, lane opponents, teammates and lane curves.", .{ ch.name, site.view.region.in(), site.when });
    const path = try std.fmt.allocPrint(a, "champion/{s}.html", .{ch.slug});
    const p = site.page(title, desc, path, .none);
    try html.head(w, p);
    try w.print(
        "<div class=\"hero\"><img src=\"{s}\" alt=\"\" width=\"72\" height=\"72\"><div><h1>{f}</h1><p class=\"muted\">Ranked solo/duo {s}, {s}, all ranks.</p></div></div>\n",
        .{ site.icon(ch), esc(ch.name), site.view.region.in(), site.when },
    );
    try earlyNote(site, w);

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
    if (n_roles == 0) try w.writeAll("<p>No games yet this patch.</p>\n");
    if (n_roles > 0) try html.minGames(w, "../", "pairs", &pair_floors, min_pair_games, min_pair_games);

    for (roles[0..n_roles]) |r| {
        const cr = st.champRole(r, ch.c);
        try w.print("<h2>{s}</h2>\n<div class=\"stats\">", .{roleName(r)});
        const few = cr.games < min_role_games;
        try w.print("<div><b{s}>", .{if (few) " class=\"muted\"" else ""});
        try pct(w, cr.wins, cr.games);
        try w.print("</b><span>Win rate{s}</span></div><div><b>", .{if (few) ", few games" else ""});
        try pct(w, cr.games, site.games);
        try w.writeAll("</b><span>Pick rate</span></div><div><b>");
        try pct(w, ch.banned, site.games);
        try w.print("</b><span>Ban rate</span></div><div><b>{d}</b><span>Games</span></div></div>\n", .{cr.games});

        var best: std.ArrayList(Pair) = .empty;
        var worst: std.ArrayList(Pair) = .empty;
        var duos: std.ArrayList(Pair) = .empty;
        for (site.champs) |other| {
            if (other.c == ch.c) continue;
            const e = st.enemy(r, r, ch.c, other.c);
            const pp = score.matchupPp(st, site.score_opts, r, ch.c, r, other.c);
            if (e.games > 0 and pp != 0) try (if (pp > 0) &best else &worst).append(a, .{
                .other = other.c,
                .role = r,
                .pp = pp,
                .games = e.games,
                .wins = e.wins,
                .clear = clearEdge(pp, e.games),
            });
            for (Role.all) |ar| {
                if (ar == r) continue;
                const d = st.ally(r, ar, ch.c, other.c);
                const duo_pp = score.duoPp(st, site.score_opts, r, ch.c, ar, other.c);
                if (d.games == 0 or duo_pp <= 0) continue;
                try duos.append(a, .{
                    .other = other.c,
                    .role = ar,
                    .pp = duo_pp,
                    .games = d.games,
                    .wins = d.wins,
                    .clear = clearEdge(duo_pp, d.games),
                });
            }
        }
        std.mem.sort(Pair, best.items, {}, byPpDesc);
        std.mem.sort(Pair, worst.items, {}, byPpAsc);
        std.mem.sort(Pair, duos.items, {}, byPpDesc);
        try w.writeAll("<div class=\"grid\">\n");
        try pairCard(site, w, "Higher win rate against", "in lane", best.items, matchups_shown, false);
        try pairCard(site, w, "Lower win rate against", "in lane", worst.items, matchups_shown, false);
        try pairCard(site, w, "Higher win rate with", "on the same team", duos.items, duos_shown, true);
        try w.writeAll("</div>\n");
        if (site.curves) |*c| try matchup.links(site, w, c, ch, r);
    }
    try pool_page.section(site, w, &site.pool, ch);
    try learning_page.section(w, &site.learning, ch);
    try w.print("<p class=\"muted\">Edges are percentage points beyond what each champion's own win rate predicts. By default a pair is listed only with {d}+ games and an edge larger than chance alone would give at that size; a lower minimum shows thinner pairs, greyed out. <a href=\"{s}method.html\">Method</a>.</p>\n", .{ min_pair_games, site.toShared(path) });
    try html.foot(w, p);
    try site.write(try std.fmt.allocPrint(a, "champion/{s}.html", .{ch.slug}), aw.written());
}

const RoleGames = struct {
    st: *const Stats,
    c: usize,
    fn more(ctx: RoleGames, a: Role, b: Role) bool {
        return ctx.st.champRole(a, ctx.c).games > ctx.st.champRole(b, ctx.c).games;
    }
};

fn clearEdge(pp: f64, games: u32) bool {
    if (games < min_pair_games) return false;
    return @abs(pp) > 98 / @sqrt(@as(f64, @floatFromInt(games)));
}

/// `pairs` best first; the first `n` passing the chosen minimum games are shown
fn pairCard(site: *const Site, w: *Writer, title: []const u8, sub: []const u8, pairs: []const Pair, n: usize, show_role: bool) !void {
    try w.print("<div class=\"card\"><h3>{s} <span class=\"muted\">{s}</span></h3><ul data-min-list data-show=\"{d}\">\n", .{ title, sub, n });
    var shown: usize = 0;
    for (try shownAtAnyFloor(site.arena, pairs, n)) |pr| {
        const other = site.champs[site.by_c[pr.other].?];
        const by_default = shown < n and pr.passes(min_pair_games);
        if (by_default) shown += 1;
        try w.print("<li data-games=\"{d}\" data-clear=\"{d}\"{s}{s}><span>", .{
            pr.games,
            @intFromBool(pr.clear),
            if (pr.passes(min_pair_games)) "" else " class=\"thin\"",
            if (by_default) "" else " hidden",
        });
        try site.champLink(w, other, "../");
        if (show_role) try w.print("<span class=\"role\">{s}</span>", .{roleName(pr.role)});
        try w.print("</span><span class=\"num {s}\" title=\"{d} games, {d} won\">{s}{d:.1}</span></li>\n", .{
            if (pr.pp >= 0) "good" else "bad", pr.games, pr.wins, if (pr.pp >= 0) "+" else "", pr.pp,
        });
    }
    try w.print("<li class=\"muted empty\"{s}>More data needed</li>\n</ul></div>\n", .{if (shown > 0) " hidden" else ""});
}

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
        "href=\"../role/top.html\"",
    }) |s| try std.testing.expect(std.mem.indexOf(u8, champ, s) != null);
    const shared_page = try read(arena, out, "daily.html");
    try std.testing.expect(std.mem.indexOf(u8, shared_page, "<a href=\"role/top.html\" data-view>") != null);
    try std.testing.expectError(error.FileNotFound, read(arena, out, "all/daily.html"));
    try std.testing.expectError(error.FileNotFound, read(arena, out, "patch/style.css"));
}
