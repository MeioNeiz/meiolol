//! `meiolol site`: the public stats website as static files (HTML, CSS, the model
//! file and champion JSON for the browser draft helper). Host anywhere static.

const std = @import("std");
const store = @import("store");
const core = @import("core");
const stats = @import("../stats.zig");
pub const html = @import("html.zig");
const prose = @import("prose.zig");

const Writer = std.Io.Writer;
const Stats = core.Stats;
const Role = core.Role;
const esc = html.esc;
const score = core.score;

const log = std.log.scoped(.site);

pub const Options = struct {
    out_dir: []const u8,
    patches: []const []const u8,
    /// Riot platform ids. The pages say EUW: change their wording before adding more
    platforms: []const []const u8 = &.{"EUW1"},
    contact: []const u8,
    /// The string Riot's application form gives, served as /riot.txt
    riot_txt: ?[]const u8 = null,
    /// "11 October 2026", for the legal pages
    updated: []const u8,
    /// False until Riot grants the production key: personal-key data may not serve
    /// the public (docs/production-key.md), so pages are unlisted and say so
    public: bool = false,
};

/// Below this share of all games a champion is left out of a role's tier list
const min_pick_rate = 0.004;
/// And below this share of the champion's own games, as a role it rarely plays
const min_role_share = 0.1;
const matchups_shown = 6;
const duos_shown = 6;

const Champ = struct {
    /// Index in the stats file
    c: usize,
    id: u32,
    key: []const u8,
    name: []const u8,
    slug: []const u8,
    banned: u32,
    games: u64,
};

const Site = struct {
    gpa: std.mem.Allocator,
    arena: std.mem.Allocator,
    io: std.Io,
    dir: std.Io.Dir,
    stats: Stats,
    champs: []Champ,
    /// Stats index -> champs index
    by_c: []?usize,
    games: u32,
    patch: []const u8,
    ddragon_version: []const u8,
    opts: Options,
    score_opts: score.Options = .{},

    fn page(s: *const Site, title: []const u8, description: []const u8, root: []const u8, nav: html.Nav) html.Page {
        return .{
            .title = title,
            .description = description,
            .root = root,
            .nav = nav,
            .patch = s.patch,
            .games = s.games,
            .public = s.opts.public,
        };
    }

    /// Also `path`.gz for `meiolol serve` to send to clients that accept gzip
    fn write(s: *const Site, path: []const u8, data: []const u8) !void {
        if (std.fs.path.dirname(path)) |d| try s.dir.createDirPath(s.io, d);
        try s.dir.writeFile(s.io, .{ .sub_path = path, .data = data });
        if (data.len < 1024) return;
        const gz = try store.raw.compress(s.gpa, data);
        defer s.gpa.free(gz);
        const gz_path = try std.fmt.allocPrint(s.arena, "{s}.gz", .{path});
        try s.dir.writeFile(s.io, .{ .sub_path = gz_path, .data = gz });
    }

    fn icon(s: *const Site, ch: Champ) []const u8 {
        return std.fmt.allocPrint(
            s.arena,
            "https://ddragon.leagueoflegends.com/cdn/{s}/img/champion/{s}.png",
            .{ s.ddragon_version, ch.key },
        ) catch "";
    }

    fn champLink(s: *const Site, w: *Writer, ch: Champ, root: []const u8) !void {
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

    var built = try stats.build(gpa, db, opts.patches, opts.platforms);
    defer built.builder.deinit();
    if (built.summary.games == 0) return error.NoMatches;
    var label_buf: [core.statsfile.patch_len]u8 = undefined;
    const patch = try arena.dupe(u8, try stats.label(&label_buf, opts.patches));
    var model: Writer.Allocating = .init(arena);
    try built.builder.write(&model.writer, patch);
    const model_bytes = model.written();

    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, opts.out_dir);
    var dir = try cwd.openDir(io, opts.out_dir, .{});
    defer dir.close(io);

    var site: Site = .{
        .gpa = gpa,
        .arena = arena,
        .io = io,
        .dir = dir,
        .stats = try .parse(arena, model_bytes),
        .champs = &.{},
        .by_c = &.{},
        .games = built.summary.games,
        .patch = patch,
        .ddragon_version = "",
        .opts = opts,
    };
    try loadChamps(&site, db);

    try site.write("style.css", @embedFile("static/style.css"));
    try site.write("favicon.svg", @embedFile("static/favicon.svg"));
    try site.write("draft.js", @embedFile("static/draft.js"));
    try site.write("meiolol.wasm", @embedFile("draft.wasm"));
    try site.write("data/stats.bin", model_bytes);
    try writeChampionsJson(&site);
    if (opts.riot_txt) |t| try site.write("riot.txt", t);
    try site.write("robots.txt", if (opts.public) "User-agent: *\nAllow: /\n" else "User-agent: *\nDisallow: /\n");

    try writeIndex(&site);
    try writeDraft(&site);
    for (Role.all) |r| try writeTier(&site, r);
    for (site.champs) |ch| try writeChampion(&site, ch);
    const info: prose.Info = .{ .contact = opts.contact, .updated = opts.updated };
    const fixed = [_]struct { []const u8, []const u8, []const u8, html.Nav, *const fn (*Writer, prose.Info) Writer.Error!void }{
        .{ "about.html", "How it works", "How meiolol's statistics and draft suggestions are made.", .about, prose.about },
        .{ "download.html", "Desktop app", "The meiolol champ select app for Windows.", .download, prose.download },
        .{ "privacy.html", "Privacy policy", "What meiolol collects and why.", .none, prose.privacy },
        .{ "terms.html", "Terms of use", "Terms for using meiolol.", .none, prose.terms },
    };
    for (fixed) |f| {
        var aw: Writer.Allocating = .init(arena);
        const p = site.page(try std.fmt.allocPrint(arena, "{s} | meiolol", .{f[1]}), f[2], "", f[3]);
        try html.head(&aw.writer, p);
        try f[4](&aw.writer, info);
        try html.foot(&aw.writer, p);
        try site.write(f[0], aw.written());
    }
    log.info("{s}: patch {s}, {d} games, {d} champion pages", .{
        opts.out_dir, patch, site.games, site.champs.len,
    });
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
            \\  AND m.remake = 0
            \\GROUP BY 1
        );
        defer q.deinit();
        try q.bind(.{ patch_json, stats.ranked_solo, platform_json });
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
    smoothed: f64,
    tier: u8 = 'C',
};

/// Champions played enough in `r`, best first, with tiers by rank
fn tierRows(site: *const Site, r: Role) ![]Row {
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
            .smoothed = score.roleWin(&site.stats, site.score_opts, ch.c, r),
        });
    }
    std.mem.sort(Row, rows.items, {}, struct {
        fn f(_: void, a: Row, b: Row) bool {
            return a.smoothed > b.smoothed;
        }
    }.f);
    const n = rows.items.len;
    for (rows.items, 0..) |*row, i| {
        const q = @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(n));
        row.tier = if (q < 0.1) 'S' else if (q < 0.3) 'A' else if (q < 0.6) 'B' else if (q < 0.85) 'C' else 'D';
    }
    return rows.items;
}

fn pct(w: *Writer, part: u64, whole: u64) !void {
    if (whole == 0) return w.writeAll("-");
    try w.print("{d:.1}%", .{100 * @as(f64, @floatFromInt(part)) / @as(f64, @floatFromInt(whole))});
}

fn earlyNote(site: *const Site, w: *Writer) !void {
    if (site.games >= 50_000) return;
    try w.print(
        "<p class=\"note\">Early data: {d} games so far on patch {s}. Numbers settle as more games come in; champions with few games are pulled toward 50%.</p>\n",
        .{ site.games, site.patch },
    );
}

fn roleTabs(w: *Writer, current: ?Role, root: []const u8) !void {
    try w.writeAll("<nav class=\"tabs\">");
    for (Role.all) |r| {
        try w.print("<a href=\"{s}tier/{s}.html\"{s}>{s}</a>", .{
            root,                                               roleSlug(r),
            if (current == r) " aria-current=\"page\"" else "", roleName(r),
        });
    }
    try w.writeAll("</nav>\n");
}

fn roleSlug(r: Role) []const u8 {
    return switch (r) {
        .top => "top",
        .jungle => "jungle",
        .middle => "mid",
        .bottom => "bot",
        .utility => "support",
    };
}

fn roleName(r: Role) []const u8 {
    return switch (r) {
        .top => "Top",
        .jungle => "Jungle",
        .middle => "Mid",
        .bottom => "Bot",
        .utility => "Support",
    };
}

fn writeTier(site: *const Site, r: Role) !void {
    const a = site.arena;
    var aw: Writer.Allocating = .init(a);
    const w = &aw.writer;
    const title = try std.fmt.allocPrint(a, "{s} tier list, patch {s} | meiolol", .{ roleName(r), site.patch });
    const desc = try std.fmt.allocPrint(a, "{s} champions ranked for EUW ranked solo queue on patch {s}, with win, pick and ban rates.", .{ roleName(r), site.patch });
    const p = site.page(title, desc, "../", .tiers);
    try html.head(w, p);
    try w.print("<h1>{s} tier list</h1>\n<p class=\"muted\">Patch {s}, EUW ranked solo/duo, all ranks.</p>\n", .{ roleName(r), site.patch });
    try roleTabs(w, r, "../");
    try earlyNote(site, w);
    try w.writeAll(
        \\<div class="table-scroll"><table>
        \\<thead><tr><th class="num">#</th><th>Champion</th><th>Tier</th><th class="num">Win rate</th><th class="num">Pick rate</th><th class="num">Ban rate</th><th class="num">Games</th></tr></thead>
        \\<tbody>
        \\
    );
    for (try tierRows(site, r), 1..) |row, i| {
        try w.print("<tr><td class=\"num\">{d}</td><td>", .{i});
        try site.champLink(w, row.ch, "../");
        try w.print("</td><td><span class=\"tier tier-{c}\">{c}</span></td><td class=\"num\">", .{ row.tier, row.tier });
        try pct(w, row.wins, row.games);
        try w.writeAll("</td><td class=\"num\">");
        try pct(w, row.games, site.games);
        try w.writeAll("</td><td class=\"num\">");
        try pct(w, row.ch.banned, site.games);
        try w.print("</td><td class=\"num\">{d}</td></tr>\n", .{row.games});
    }
    try w.writeAll("</tbody></table></div>\n");
    try html.foot(w, p);
    try site.write(try std.fmt.allocPrint(a, "tier/{s}.html", .{roleSlug(r)}), aw.written());
}

fn writeIndex(site: *const Site) !void {
    const a = site.arena;
    var aw: Writer.Allocating = .init(a);
    const w = &aw.writer;
    const p = site.page(
        "meiolol: draft help for ranked solo queue",
        "League of Legends champion statistics and draft suggestions for EUW ranked solo queue: tier lists, matchups, duos and a draft helper.",
        "",
        .none,
    );
    try html.head(w, p);
    try w.print(
        \\<h1>Draft help for ranked solo queue</h1>
        \\<p class="lead">Champion statistics for EUW ranked solo/duo on patch {s}, and a
        \\draft helper that offers several picks for your role with the reasons behind each:
        \\counters, synergy with your team and how the champion is doing this patch.</p>
        \\<p><a href="draft.html">Open the draft helper</a> · <a href="download.html">Desktop app for champ select</a></p>
        \\
    , .{site.patch});
    try earlyNote(site, w);
    try w.writeAll("<h2>Top of each role</h2>\n<div class=\"grid\">\n");
    for (Role.all) |r| {
        try w.print("<div class=\"card\"><h3><a href=\"tier/{s}.html\">{s}</a></h3><ul>\n", .{ roleSlug(r), roleName(r) });
        const rows = try tierRows(site, r);
        for (rows[0..@min(rows.len, 5)]) |row| {
            try w.writeAll("<li>");
            try site.champLink(w, row.ch, "");
            try w.print("<span class=\"tier tier-{c}\">{c}</span></li>\n", .{ row.tier, row.tier });
        }
        try w.writeAll("</ul></div>\n");
    }
    try w.writeAll("</div>\n<h2>All champions</h2>\n<p>");
    for (site.champs, 0..) |ch, i| {
        if (i > 0) try w.writeAll(" · ");
        try w.print("<a href=\"champion/{s}.html\">{f}</a>", .{ ch.slug, esc(ch.name) });
    }
    try w.writeAll("</p>\n");
    try html.foot(w, p);
    try site.write("index.html", aw.written());
}

fn writeDraft(site: *const Site) !void {
    var aw: Writer.Allocating = .init(site.arena);
    const w = &aw.writer;
    const p = site.page(
        "Draft helper | meiolol",
        "Enter the picks and bans so far and get several champion options for your role, with the reasons behind each.",
        "",
        .draft,
    );
    try html.head(w, p);
    try w.writeAll(
        \\<h1>Draft helper</h1>
        \\<p class="lead">Enter the picks and bans so far. You get several options for your
        \\role, each with its reasons: counters, synergy with your team and how the champion
        \\is doing this patch. The choice is yours.</p>
        \\<p id="status" class="note">Loading…</p>
        \\<form id="draft" class="draft" autocomplete="off" onsubmit="return false">
        \\<datalist id="champions"></datalist>
        \\<div class="card">
        \\<h3>Your team</h3>
        \\<label><span>You</span><select name="role">
        \\<option value="top">Top</option><option value="jungle">Jungle</option>
        \\<option value="middle" selected>Mid</option><option value="bottom">Bot</option>
        \\<option value="utility">Support</option></select></label>
        \\
    );
    for (0..4) |_| {
        try w.writeAll("<label><span></span><input data-ally list=\"champions\" placeholder=\"Champion\"></label>\n");
    }
    try w.writeAll(
        \\</div>
        \\<div class="card">
        \\<h3>Enemy team <span class="muted">roles guessed</span></h3>
        \\
    );
    for (1..6) |i| {
        try w.print("<label><span>Enemy {d}</span><input data-enemy list=\"champions\" placeholder=\"Champion\"></label>\n", .{i});
    }
    try w.writeAll(
        \\</div>
        \\<div class="card">
        \\<h3>Bans</h3>
        \\<label><input name="bans" list="champions" placeholder="Comma separated, e.g. Yasuo, Zed"></label>
        \\</div>
        \\</form>
        \\<h2>Options for your role</h2>
        \\<ul id="suggestions" class="card suggestions"></ul>
        \\<p class="muted">Numbers are percentage points of win chance each factor adds or
        \\takes away, estimated from this patch's games. <a href="about.html">How it works</a>.</p>
        \\<script src="draft.js" defer></script>
        \\
    );
    try html.foot(w, p);
    try site.write("draft.html", aw.written());
}

const Pair = struct { other: usize, role: Role, pp: f64, games: u32, wins: u32 };

fn byPpDesc(_: void, a: Pair, b: Pair) bool {
    return a.pp > b.pp;
}

fn writeChampion(site: *const Site, ch: Champ) !void {
    const a = site.arena;
    const st = &site.stats;
    var aw: Writer.Allocating = .init(a);
    const w = &aw.writer;
    const title = try std.fmt.allocPrint(a, "{s} stats, matchups and duos, patch {s} | meiolol", .{ ch.name, site.patch });
    const desc = try std.fmt.allocPrint(a, "{s} win rate, counters and best duos in EUW ranked solo queue on patch {s}.", .{ ch.name, site.patch });
    const p = site.page(title, desc, "../", .none);
    try html.head(w, p);
    try w.print(
        "<div class=\"hero\"><img src=\"{s}\" alt=\"\" width=\"72\" height=\"72\"><div><h1>{f}</h1><p class=\"muted\">Patch {s}, EUW ranked solo/duo, all ranks.</p></div></div>\n",
        .{ site.icon(ch), esc(ch.name), site.patch },
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

    for (roles[0..n_roles]) |r| {
        const cr = st.champRole(r, ch.c);
        try w.print("<h2>{s}</h2>\n<div class=\"stats\">", .{roleName(r)});
        try w.writeAll("<div><b>");
        try pct(w, cr.wins, cr.games);
        try w.writeAll("</b><span>Win rate</span></div><div><b>");
        try pct(w, cr.games, site.games);
        try w.writeAll("</b><span>Pick rate</span></div><div><b>");
        try pct(w, ch.banned, site.games);
        try w.print("</b><span>Ban rate</span></div><div><b>{d}</b><span>Games</span></div></div>\n", .{cr.games});

        var lane: std.ArrayList(Pair) = .empty;
        var duos: std.ArrayList(Pair) = .empty;
        for (site.champs) |other| {
            if (other.c == ch.c) continue;
            const e = st.enemy(r, r, ch.c, other.c);
            if (e.games > 0) try lane.append(a, .{
                .other = other.c,
                .role = r,
                .pp = score.matchupPp(st, site.score_opts, r, ch.c, r, other.c),
                .games = e.games,
                .wins = e.wins,
            });
            for (Role.all) |ar| {
                if (ar == r) continue;
                const d = st.ally(r, ar, ch.c, other.c);
                if (d.games == 0) continue;
                try duos.append(a, .{
                    .other = other.c,
                    .role = ar,
                    .pp = score.duoPp(st, site.score_opts, r, ch.c, ar, other.c),
                    .games = d.games,
                    .wins = d.wins,
                });
            }
        }
        std.mem.sort(Pair, lane.items, {}, byPpDesc);
        std.mem.sort(Pair, duos.items, {}, byPpDesc);
        var n_good: usize = 0;
        while (n_good < lane.items.len and lane.items[n_good].pp > 0) n_good += 1;
        const best_lane = lane.items[0..@min(n_good, matchups_shown)];
        const worst_lane = lane.items[@max(n_good, lane.items.len -| matchups_shown)..];
        try w.writeAll("<div class=\"grid\">\n");
        try pairCard(site, w, "Good against", "in lane", best_lane, false, false);
        try pairCard(site, w, "Hard against", "in lane", worst_lane, true, false);
        var n_duos: usize = 0;
        while (n_duos < @min(duos.items.len, duos_shown) and duos.items[n_duos].pp > 0) n_duos += 1;
        try pairCard(site, w, "Best with", "on your team", duos.items[0..n_duos], false, true);
        try w.writeAll("</div>\n");
    }
    try w.writeAll("<p class=\"muted\">Edges are percentage points beyond what each champion's own win rate predicts; pairs with few games stay near zero. <a href=\"../about.html\">How it works</a>.</p>\n");
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

fn pairCard(site: *const Site, w: *Writer, title: []const u8, sub: []const u8, pairs: []const Pair, reverse: bool, show_role: bool) !void {
    try w.print("<div class=\"card\"><h3>{s} <span class=\"muted\">{s}</span></h3><ul>\n", .{ title, sub });
    if (pairs.len == 0) try w.writeAll("<li class=\"muted\">Not enough games yet</li>\n");
    var i: usize = 0;
    while (i < pairs.len) : (i += 1) {
        const pr = pairs[if (reverse) pairs.len - 1 - i else i];
        const other = site.champs[site.by_c[pr.other].?];
        try w.writeAll("<li><span>");
        try site.champLink(w, other, "../");
        if (show_role) try w.print("<span class=\"role\">{s}</span>", .{roleName(pr.role)});
        try w.print("</span><span class=\"num {s}\" title=\"{d} games, {d} won\">{s}{d:.1}</span></li>\n", .{
            if (pr.pp >= 0) "good" else "bad", pr.games, pr.wins, if (pr.pp >= 0) "+" else "", pr.pp,
        });
    }
    try w.writeAll("</ul></div>\n");
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
