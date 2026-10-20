//! Build pages (src/builds.zig): what players take on a champion in a role this patch,
//! most played first, never ranked by win rate or called "best" (docs/concept.md,
//! docs/production-key.md). Every row shows games and pick share; a win rate only with
//! rate_games behind it and always with its 95% range; rows under solid_games greyed.
//! Pages live in the patch views; the 30-day views link to them.

const std = @import("std");
const core = @import("core");
const root = @import("root.zig");
const html = @import("html.zig");
const tpl = html.tpl;
const plural = @import("text.zig").plural;
const builds = @import("../builds.zig");
const ddragon = @import("../ddragon.zig");

const Writer = std.Io.Writer;
const Role = core.Role;
const Site = root.Site;
const Champ = root.Champ;
const File = builds.File;
const Kind = builds.Kind;

/// Below this a row shows no win rate: ±10 points at 100 games, wider below
pub const rate_games = 100;
/// Below this a row is greyed out
pub const solid_games = 400;
const rows_shown = 6;
const pages_shown = 4;
/// A role gets a page when it has this share of the champion's games in the file
const min_role_share = 0.1;

pub fn path(a: std.mem.Allocator, ch: Champ, r: Role) ![]const u8 {
    return a.print("build/{s}-{s}.html", .{ ch.slug, root.roleSlug(r) });
}

/// The build `ch` has a page for in `r`
pub fn shown(f: *const File, champion: u32, r: Role) ?File.Build {
    const b = f.get(champion, r) orelse return null;
    var all: u64 = 0;
    for (Role.all) |other| {
        if (f.get(champion, other)) |o| all += o.games;
    }
    if (b.games == 0 or @as(f64, @floatFromInt(b.games)) < min_role_share * @as(f64, @floatFromInt(all))) return null;
    return b;
}

/// The patch view of the site view's region, where build pages are
fn patchView(site: *const Site) html.View {
    return .{ .region = site.view.region, .period = .patch };
}

/// A page per champion and role with enough of the champion's games (patch views only)
pub fn paths(site: *const Site, f: *const File, list: *std.ArrayList([]const u8)) !void {
    try list.append(site.arena, index_path);
    for (site.champs) |ch| for (Role.all) |r| {
        if (shown(f, ch.id, r) == null) continue;
        try list.append(site.arena, try path(site.arena, ch, r));
    };
}

pub const index_path = "build/index.html";

/// Every champion and role with a build page, by role
pub fn writeIndex(site: *const Site, w: *Writer, f: *const File) !void {
    const a = site.arena;
    const title = try a.print("Builds, patch {s} | meiolol", .{f.label});
    const desc = try a.print("Runes, items and skill order per champion and role in ranked solo/duo {s}, patch {s}.", .{ site.view.region.in(), f.label });
    var p = site.page(title, desc, index_path, .champions);
    // Builds are per patch: a view without them switches to its champions list
    for (html.View.all, &p.counterparts.?) |v, *there| {
        if (v.period != .patch or site.view_builds[v.index()] == null)
            there.* = try std.mem.concat(a, u8, &.{ v.dir(), "champions.html" });
    }
    try html.head(w, p);
    try tpl.render(w,
        \\<h1>Builds, patch {patch}</h1>
        \\<p class="muted">What players take per champion and role: ranked solo/duo {in}, patch {patch}, {ranks}. A role is listed when it has a tenth or more of the champion's games.</p>
        \\
    , .{ .patch = f.label, .in = site.view.region.in(), .ranks = try rankLabel(a, f.min_tier) });
    for (Role.all) |r| {
        var any = false;
        for (site.champs) |ch| any = any or shown(f, ch.id, r) != null;
        if (!any) continue;
        try tpl.renderPart(w, "<h2>{role}</h2>\n<ul class=\"build-list\">", .{ .role = root.roleName(r) });
        for (site.champs) |ch| {
            const b = shown(f, ch.id, r) orelse continue;
            try tpl.render(w,
                \\<li><a class="champ" href="{href}"><img src="{icon}" alt="" loading="lazy" width="32" height="32">{name}</a> <span class="muted">{games}</span></li>
            , .{
                .href = try a.print("{s}-{s}.html", .{ ch.slug, root.roleSlug(r) }),
                .icon = site.icon(ch),
                .name = ch.name,
                .games = b.games,
            });
        }
        try w.writeAll("</ul>\n");
    }
    try html.foot(w, p);
}

/// `rest`: "<champion>-<role>" from build/<rest>.html; false for no such page
pub fn route(site: *const Site, w: *Writer, f: *const File, rest: []const u8) !bool {
    const dash = std.mem.lastIndexOfScalar(u8, rest, '-') orelse return false;
    const ch = site.champBySlug(rest[0..dash]) orelse return false;
    const r = root.roleFromSlug(rest[dash + 1 ..]) orelse return false;
    const b = shown(f, ch.id, r) orelse return false;
    try writePage(site, w, f, ch, r, b);
    return true;
}

/// Champion page, in `r`'s section: the most played choice of each kind with its games,
/// share and win rate (a past-games fact, the build page's framing), and a link to the
/// build page, in this view or its patch view. Builds follow the patch view, not the
/// page's filters. `from`: the champion page's path
pub fn strip(site: *const Site, w: *Writer, ch: Champ, r: Role, from: []const u8) !void {
    const pv = patchView(site);
    const f = if (site.view_builds[pv.index()]) |*f| f else return;
    const b = shown(f, ch.id, r) orelse return;
    const to = try path(site.arena, ch, r);
    const href: html.Link = if (site.view.period == .patch)
        .{ .root = site.toRoot(from), .path = to }
    else
        .{ .root = site.toShared(from), .up = pv.dir(), .path = to };
    try tpl.renderPart(w,
        \\<div class="bstrip"><p class="bhead"><b>Most played build</b> <span class="muted">patch {patch}, {in}, {ranks}: {games} game{s}; the filters above don't change it.</span> <a href="{href}">Full build: runes, items and skill order</a></p>
        \\<div class="bks">
    , .{
        .patch = f.label,
        .in = pv.region.in(),
        .ranks = try rankLabel(site.arena, f.min_tier),
        .games = try root.thousands(site.arena, b.games),
        .s = plural(b.games),
        .href = href,
    });
    try top(site.arena, w, f, b, .runes, "Runes");
    if (f.trees.len == 0) try top(site.arena, w, f, b, .shards, "Shards");
    try top(site.arena, w, f, b, .spells, "Spells");
    try top(site.arena, w, f, b, .start, "Start");
    try top(site.arena, w, f, b, .boots, "Boots");
    try top(site.arena, w, f, b, .core3, "First 3 items");
    try top(site.arena, w, f, b, .skill_start, "Levels 1-3");
    try top(site.arena, w, f, b, .skills, "Skill priority");
    try w.writeAll("</div></div>\n");
}

/// One kind's most played option: value, then games, share and win rate
fn top(a: std.mem.Allocator, w: *Writer, f: *const File, b: File.Build, kind: Kind, comptime title: []const u8) !void {
    const rows = b.get(kind) orelse return;
    if (rows.options.len == 0) return;
    const o = rows.options[0];
    const share = 100 * @as(f64, @floatFromInt(o.games)) / @as(f64, @floatFromInt(@max(rows.games, 1)));
    try tpl.render(w,
        \\<div class="bk {kind}{thin}"><span>{title}</span><div class="bv">{value}</div><small title="{games} of {all} players took this">{games} games · {share:.0}%{rate}</small></div>
        \\
    , .{
        .kind = @tagName(kind),
        .thin = tpl.when(o.games < solid_games, " thin"),
        .title = title,
        .value = tpl.call(cell, .{ f, b, kind, o.v }),
        .share = share,
        .all = try root.thousands(a, rows.games),
        .games = try root.thousands(a, o.games),
        .rate = tpl.when(o.games >= rate_games, tpl.t("<br>{wr:.1}% won", .{ .wr = wonPct(o) })),
    });
}

/// The strip's value: the rune page with the most played shards as the in-game tree
fn cell(w: *Writer, f: *const File, b: File.Build, kind: Kind, v: []const u32) !void {
    if (kind == .runes) {
        const shards: ?[]const u32 = if (b.get(.shards)) |r| if (r.options.len > 0) r.options[0].v else null else null;
        if (try runePage(w, f, v, shards)) return;
    }
    try value(w, f, kind, v, true);
}

fn findTree(f: *const File, id: u32) ?ddragon.Tree {
    for (f.trees) |t| if (t.id == id) return t;
    return null;
}

/// `v` (a .runes value) as the in-game page: every rune of the primary tree and of the
/// secondary's rows (its keystones left out), the chosen ones lit, and `shards` (a
/// .shards value) on the shard rows. False, writing nothing, without the trees (files
/// before 20 Oct 2026)
fn runePage(w: *Writer, f: *const File, v: []const u32, shards: ?[]const u32) !bool {
    const primary = findTree(f, v[0]) orelse return false;
    const secondary = findTree(f, v[5]) orelse return false;
    if (secondary.slots.len == 0) return false;
    try w.writeAll("<div class=\"rp\"><div class=\"rt\">");
    try rune(w, f.runes, primary.id, "rh", true);
    for (primary.slots, 0..) |slot, i| {
        try w.writeAll(if (i == 0) "<div class=\"rr ks\">" else "<div class=\"rr\">");
        for (slot) |id| try rune(w, f.runes, id, "", std.mem.indexOfScalar(u32, v[1..5], id) != null);
        try w.writeAll("</div>");
    }
    try w.writeAll("</div><div class=\"rt\">");
    try rune(w, f.runes, secondary.id, "rh", true);
    for (secondary.slots[1..]) |slot| {
        try w.writeAll("<div class=\"rr\">");
        for (slot) |id| try rune(w, f.runes, id, "", std.mem.indexOfScalar(u32, v[6..8], id) != null);
        try w.writeAll("</div>");
    }
    try w.writeAll("</div>");
    if (shards) |s| {
        try w.writeAll("<div class=\"rt rs\" title=\"Most played stat shards\">");
        for (ddragon.shard_rows, 0..) |row, i| {
            try w.writeAll("<div class=\"rr\">");
            for (row) |id| try rune(w, &ddragon.shards, id, "", i < s.len and s[i] == id);
            try w.writeAll("</div>");
        }
        try w.writeAll("</div>");
    }
    try w.writeAll("</div>");
    return true;
}

/// A rune's icon, dimmed unless `lit`; the name on hover, as alt text only when lit
fn rune(w: *Writer, list: []const ddragon.Named, id: u32, comptime class: []const u8, lit: bool) !void {
    const n = ddragon.find(list, id) orelse return w.writeAll("<i></i>");
    try tpl.render(w,
        \\<img class="{class}" src="{src}" alt="{alt}" title="{name}" loading="lazy">
    , .{
        .class = if (lit) (if (class.len == 0) "on" else class ++ " on") else class ++ " off",
        .src = n.icon,
        .alt = if (lit) n.name else "",
        .name = n.name,
    });
}

/// Build page: the most played rune pages as in-game trees, each with games, share and
/// win rate. False without the trees, for the table instead
fn pages(w: *Writer, f: *const File, b: File.Build) !bool {
    if (f.trees.len == 0) return false;
    const rows = b.get(.runes) orelse return false;
    if (rows.options.len == 0) return false;
    try w.writeAll("<div class=\"rpages\">\n");
    for (rows.options[0..@min(rows.options.len, pages_shown)]) |o| {
        try w.writeAll(if (o.games < solid_games) "<div class=\"rpc thin\">" else "<div class=\"rpc\">");
        if (!try runePage(w, f, o.v, null)) try value(w, f, .runes, o.v, true);
        try tpl.renderPart(w,
            \\<small>{games} games · {share:.1}%<br>{rate}</small></div>
            \\
        , .{
            .games = o.games,
            .share = 100 * @as(f64, @floatFromInt(o.games)) / @as(f64, @floatFromInt(@max(rows.games, 1))),
            .rate = tpl.call(winRate, .{ o.games, o.wins }),
        });
    }
    try tpl.renderPart(w, "</div>\n<p class=\"muted caption\">Most played rune pages first. Share of {games} players.</p>\n", .{
        .games = rows.games,
    });
    return true;
}

fn wonPct(o: File.Option) f64 {
    return 100 * @as(f64, @floatFromInt(o.wins)) / @as(f64, @floatFromInt(@max(o.games, 1)));
}

/// "PLATINUM" -> "Platinum IV and up"; "" -> "every player in Platinum+ games"
pub fn rankLabel(a: std.mem.Allocator, tier: []const u8) ![]const u8 {
    if (tier.len == 0) return "every player in Platinum+ games";
    const name = try std.ascii.allocLowerString(a, tier);
    name[0] = std.ascii.toUpper(name[0]);
    const apex = std.mem.eql(u8, tier, "MASTER") or std.mem.eql(u8, tier, "GRANDMASTER") or std.mem.eql(u8, tier, "CHALLENGER");
    return a.print("{s}{s} and up", .{ name, if (apex) "" else " IV" });
}

fn writePage(site: *const Site, w: *Writer, f: *const File, ch: Champ, r: Role, b: File.Build) !void {
    const a = site.arena;
    const page_path = try path(a, ch, r);
    const ranks = try rankLabel(a, f.min_tier);
    const title = try a.print("{s} {s} build: runes, items, skill order, patch {s} | meiolol", .{
        ch.name, root.roleName(r), f.label,
    });
    const role = try std.ascii.allocLowerString(a, root.roleName(r));
    const desc = try a.print("What players take on {s} in the {s} role in ranked solo/duo {s}, patch {s}: rune pages, summoner spells, starting items, boots, first items and skill order, with games and win rates.", .{
        ch.name, role, site.view.region.in(), f.label,
    });
    var p = site.page(title, desc, page_path, .champions);
    const champ_path = try a.print("champion/{s}.html", .{ch.slug});
    for (html.View.all, &p.counterparts.?) |v, *there| {
        const has = v.period == .patch and if (site.view_builds[v.index()]) |*o| shown(o, ch.id, r) != null else false;
        if (!has) there.* = try std.mem.concat(a, u8, &.{ champ_path, v.query() });
    }
    try html.head(w, p);
    try tpl.render(w,
        \\<div class="hero"><img src="{icon}" alt="" width="72" height="72"><div><h1>{name} {role} build</h1>
        \\<p class="muted">What players take on {name} in the {lower} role: ranked solo/duo {in}, patch {patch}, {ranks}. {games} game{s}{rate}.</p></div></div>
        \\
    , .{
        .icon = site.icon(ch),
        .name = ch.name,
        .role = root.roleName(r),
        .lower = role,
        .in = site.view.region.in(),
        .patch = f.label,
        .ranks = ranks,
        .games = b.games,
        .s = plural(b.games),
        .rate = tpl.when(b.games >= rate_games, tpl.t(", win rate {wr}", .{
            .wr = tpl.call(winRate, .{ b.games, b.wins }),
        })),
    });

    var others: usize = 0;
    for (Role.all) |o| others += @intFromBool(shown(f, ch.id, o) != null);
    if (others > 1) {
        try w.writeAll("<nav class=\"tabs\">");
        for (Role.all) |o| {
            if (shown(f, ch.id, o) == null) continue;
            try tpl.render(w, "<a href=\"{href}\"{current}>{label}</a>", .{
                .href = try a.print("{s}-{s}.html", .{ ch.slug, root.roleSlug(o) }),
                .current = tpl.flag(o == r, "aria-current=\"page\""),
                .label = root.roleName(o),
            });
        }
        try w.writeAll("</nav>\n");
    }
    if (b.games < solid_games) {
        try tpl.render(w,
            \\<p class="note">More data needed: {games} game{s} so far. Rows under {solid} games are greyed out and under {rated} show no win rate; with few games the most played choices can still change places.</p>
            \\
        , .{ .games = b.games, .s = plural(b.games), .solid = solid_games, .rated = rate_games });
    }
    try tpl.render(w,
        \\<p class="muted">Most played first: what players take, not a ranking. Win rates show a 95% range (±) from the number of games; two rows whose ranges overlap may not differ at all. Rows under {solid} games are greyed out; under {rated} there is no win rate.</p>
        \\
    , .{ .solid = solid_games, .rated = rate_games });

    try w.writeAll("<h2>Runes</h2>\n");
    const paged = try pages(w, f, b);
    try table(w, f, b, .keystone, "Keystone", "players");
    if (!paged) try table(w, f, b, .runes, "Rune page", "players");
    try table(w, f, b, .shards, "Stat shards", "players");
    try w.writeAll("<h2>Summoner spells</h2>\n");
    try table(w, f, b, .spells, "Spells", "players");
    try w.writeAll("<h2>Items</h2>\n");
    const items_from = "players with a match timeline";
    try table(w, f, b, .start, "Starting items", items_from);
    try table(w, f, b, .boots, "Boots", "players with boots or two finished items");
    try table(w, f, b, .core2, "First two finished items", "players who finished two items");
    try table(w, f, b, .core3, "First three finished items", "players who finished three items: longer games, so compare these win rates with each other rather than with the champion's overall");
    try w.writeAll("<h2>Skill priority</h2>\n");
    try table(w, f, b, .skills, "Order", "players with a match timeline who reached level 11");
    try table(w, f, b, .skill_start, "Levels 1 to 3", "players with a match timeline");
    const to_site = site.toShared(page_path);
    try tpl.render(w,
        \\<p class="muted"><a href="{champ}">{name}</a> · <a href="{site}method.html#builds">How builds are counted</a></p>
        \\
    , .{ .champ = site.champHref(ch, to_site), .name = ch.name, .site = to_site });
    try html.foot(w, p);
}

/// "52.3% ±2.4", or "few games" under rate_games
fn winRate(w: *Writer, games: u32, wins: u32) !void {
    if (games < rate_games) return w.writeAll("<span class=\"muted\">few games</span>");
    const n: f64 = @floatFromInt(games);
    const rate = @as(f64, @floatFromInt(wins)) / n;
    try tpl.render(w, "{rate:.1}% <span class=\"muted\">±{pm:.1}</span>", .{
        .rate = 100 * rate,
        .pm = 196 * @sqrt(rate * (1 - rate) / n),
    });
}

fn table(w: *Writer, f: *const File, b: File.Build, kind: Kind, comptime title: []const u8, comptime of: []const u8) !void {
    try w.writeAll("<div class=\"table-scroll\"><table class=\"build\">\n<thead><tr><th>" ++ title ++
        "</th><th class=\"num\">Games</th><th class=\"num\">Share</th><th class=\"num\">Win rate</th></tr></thead>\n<tbody>\n");
    const rows = b.get(kind) orelse File.Rows{ .kind = kind, .games = 0, .wins = 0, .options = &.{} };
    if (rows.options.len == 0) {
        try w.writeAll("<tr class=\"thin\"><td colspan=\"4\">More data needed</td></tr>\n");
    }
    for (rows.options[0..@min(rows.options.len, rows_shown)]) |o| {
        try tpl.render(w,
            \\<tr{thin}><td>{value}</td><td class="num">{games}</td><td class="num">{share:.1}%</td><td class="num">{rate}</td></tr>
            \\
        , .{
            .thin = tpl.flag(o.games < solid_games, "class=\"thin\""),
            .value = tpl.call(value, .{ f, kind, o.v, false }),
            .games = o.games,
            .share = 100 * @as(f64, @floatFromInt(o.games)) / @as(f64, @floatFromInt(@max(rows.games, 1))),
            .rate = tpl.call(winRate, .{ o.games, o.wins }),
        });
    }
    try tpl.renderPart(w, "</tbody></table></div>\n<p class=\"muted caption\">Share of {games} " ++ of ++ ".</p>\n", .{
        .games = rows.games,
    });
}

/// `compact`: icons without names beside them (names on hover), shards one a line
fn value(w: *Writer, f: *const File, kind: Kind, v: []const u32, compact: bool) !void {
    switch (kind) {
        .keystone, .boots => {
            if (v[0] == 0) return w.writeAll("No boots");
            try named(w, if (kind == .boots) f.items else f.runes, v[0], !compact);
        },
        .spells => for (v, 0..) |x, i| {
            if (i > 0) try w.writeAll(" ");
            try named(w, f.spells, x, !compact);
        },
        .runes => for (v, 0..) |x, i| {
            // Trees (0, 5) as a divider, runes as icons
            if (i == 5) try w.writeAll("<span class=\"sep\">|</span>");
            if (i == 0 or i == 5) continue;
            try named(w, f.runes, x, false);
        },
        .shards => for (v, 0..) |x, i| {
            if (i > 0) try w.writeAll(if (compact) "<br>" else " · ");
            if (ddragon.find(f.runes, x)) |n| try tpl.writeEscaped(n.name, w) else try w.print("#{d}", .{x});
        },
        .start => for (v) |x| try named(w, f.items, x, false),
        .core2, .core3 => for (v, 0..) |x, i| {
            if (i > 0) try w.writeAll("<span class=\"sep\">›</span>");
            try named(w, f.items, x, false);
        },
        .skills, .skill_start => for (v, 0..) |x, i| {
            if (i > 0) try w.writeAll(if (kind == .skills) "<span class=\"sep\">›</span>" else " ");
            try tpl.render(w, "<b>{key}</b>", .{ .key = switch (x) {
                1 => "Q",
                2 => "W",
                3 => "E",
                else => "?",
            } });
        },
    }
}

/// Icon (name as alt and title), and the name beside it with `label`
fn named(w: *Writer, list: []const ddragon.Named, id: u32, label: bool) !void {
    var buf: [16]u8 = undefined;
    const n = ddragon.find(list, id) orelse ddragon.Named{ .id = id, .name = try std.mem.print(&buf, "#{d}", .{id}) };
    if (n.icon.len > 0) {
        try tpl.render(w,
            \\<img class="icon" src="{src}" alt="{name}" title="{name}" width="28" height="28" loading="lazy">
        , .{ .src = n.icon, .name = n.name });
    }
    if (label or n.icon.len == 0) try tpl.render(w, "<span class=\"label\">{name}</span>", .{ .name = n.name });
}

test "rank label" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try std.testing.expectEqualStrings("Platinum IV and up", try rankLabel(a, "PLATINUM"));
    try std.testing.expectEqualStrings("Master and up", try rankLabel(a, "MASTER"));
    try std.testing.expectEqualStrings("every player in Platinum+ games", try rankLabel(a, ""));
}
