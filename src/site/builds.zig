//! Build pages (src/builds.zig): what players take on a champion in a role this patch,
//! most played first, never ranked by win rate or called "best" (docs/concept.md,
//! docs/production-key.md). Every row shows games and pick share; a win rate only with
//! rate_games behind it and always with its 95% range; rows under solid_games greyed.
//! Pages live in the patch views; the 30-day views link to them.

const std = @import("std");
const core = @import("core");
const root = @import("root.zig");
const html = @import("html.zig");
const builds = @import("../builds.zig");
const ddragon = @import("../ddragon.zig");

const Writer = std.Io.Writer;
const Role = core.Role;
const Site = root.Site;
const Champ = root.Champ;
const File = builds.File;
const Kind = builds.Kind;
const esc = html.esc;

/// Below this a row shows no win rate: ±10 points at 100 games, wider below
pub const rate_games = 100;
/// Below this a row is greyed out
pub const solid_games = 400;
const rows_shown = 6;
/// A role gets a page when it has this share of the champion's games in the file
const min_role_share = 0.1;

pub fn path(a: std.mem.Allocator, ch: Champ, r: Role) ![]const u8 {
    return std.fmt.allocPrint(a, "build/{s}-{s}.html", .{ ch.slug, root.roleSlug(r) });
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
    for (site.champs) |ch| for (Role.all) |r| {
        if (shown(f, ch.id, r) == null) continue;
        try list.append(site.arena, try path(site.arena, ch, r));
    };
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

/// Champion page, in `r`'s section: a link to the build page, in this view or its patch
/// view. `from`: the champion page's path
pub fn link(site: *const Site, w: *Writer, ch: Champ, r: Role, from: []const u8) !void {
    const pv = patchView(site);
    const f = if (site.view_builds[pv.index()]) |*f| f else return;
    const b = shown(f, ch.id, r) orelse return;
    const to = try path(site.arena, ch, r);
    const href = if (site.view.period == .patch)
        try std.mem.concat(site.arena, u8, &.{ site.toRoot(from), to })
    else
        try std.mem.concat(site.arena, u8, &.{ site.toShared(from), pv.dir(), to });
    try w.print("<p class=\"curves-links\"><b>Build:</b> <a href=\"{s}\">runes, items and skill order, patch {s}</a> <span class=\"muted\">{d} game{s}, {s}</span></p>\n", .{
        href, f.label, b.games, plural(b.games), try rankLabel(site.arena, f.min_tier),
    });
}

/// "PLATINUM" -> "Platinum IV and up"; "" -> "all ranks"
pub fn rankLabel(a: std.mem.Allocator, tier: []const u8) ![]const u8 {
    if (tier.len == 0) return "all ranks";
    const name = try std.ascii.allocLowerString(a, tier);
    name[0] = std.ascii.toUpper(name[0]);
    const apex = std.mem.eql(u8, tier, "MASTER") or std.mem.eql(u8, tier, "GRANDMASTER") or std.mem.eql(u8, tier, "CHALLENGER");
    return std.fmt.allocPrint(a, "{s}{s} and up", .{ name, if (apex) "" else " IV" });
}

fn plural(n: u64) []const u8 {
    return if (n == 1) "" else "s";
}

fn writePage(site: *const Site, w: *Writer, f: *const File, ch: Champ, r: Role, b: File.Build) !void {
    const a = site.arena;
    const page_path = try path(a, ch, r);
    const ranks = try rankLabel(a, f.min_tier);
    const title = try std.fmt.allocPrint(a, "{s} {s} build: runes, items, skill order, patch {s} | meiolol", .{
        ch.name, root.roleName(r), f.label,
    });
    const role = try std.ascii.allocLowerString(a, root.roleName(r));
    const desc = try std.fmt.allocPrint(a, "What players take on {s} in the {s} role in ranked solo/duo {s}, patch {s}: rune pages, summoner spells, starting items, boots, first items and skill order, with games and win rates.", .{
        ch.name, role, site.view.region.in(), f.label,
    });
    var p = site.page(title, desc, page_path, .champions);
    const champ_path = try std.fmt.allocPrint(a, "champion/{s}.html", .{ch.slug});
    for (html.View.all, &p.counterparts.?) |v, *there| {
        const has = v.period == .patch and if (site.view_builds[v.index()]) |*o| shown(o, ch.id, r) != null else false;
        if (!has) there.* = champ_path;
    }
    try html.head(w, p);
    try w.print(
        "<div class=\"hero\"><img src=\"{s}\" alt=\"\" width=\"72\" height=\"72\"><div><h1>{f} {s} build</h1>\n",
        .{ site.icon(ch), esc(ch.name), root.roleName(r) },
    );
    try w.print("<p class=\"muted\">What players take on {f} in the {s} role: ranked solo/duo {s}, patch {s}, {s}. {d} game{s}", .{
        esc(ch.name), role, site.view.region.in(), f.label, ranks, b.games, plural(b.games),
    });
    if (b.games >= rate_games) {
        try w.writeAll(", win rate ");
        try winRate(w, b.games, b.wins);
    }
    try w.writeAll(".</p></div></div>\n");

    var others: usize = 0;
    for (Role.all) |o| others += @intFromBool(shown(f, ch.id, o) != null);
    if (others > 1) {
        try w.writeAll("<nav class=\"tabs\">");
        for (Role.all) |o| {
            if (shown(f, ch.id, o) == null) continue;
            try w.print("<a href=\"{s}\"{s}>{s}</a>", .{
                (try path(a, ch, o))["build/".len..], if (o == r) " aria-current=\"page\"" else "", root.roleName(o),
            });
        }
        try w.writeAll("</nav>\n");
    }
    if (b.games < solid_games) {
        try w.print("<p class=\"note\">More data needed: {d} game{s} so far. Rows under {d} games are greyed out and under {d} show no win rate; with few games the most played choices can still change places.</p>\n", .{
            b.games, plural(b.games), solid_games, rate_games,
        });
    }
    try w.print(
        "<p class=\"muted\">Most played first: what players take, not a ranking. Win rates show a 95% range (±) from the number of games; two rows whose ranges overlap may not differ at all. Rows under {d} games are greyed out; under {d} there is no win rate.</p>\n",
        .{ solid_games, rate_games },
    );

    try w.writeAll("<h2>Runes</h2>\n");
    try table(w, f, b, .keystone, "Keystone", "players");
    try table(w, f, b, .runes, "Rune page", "players");
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
    try w.print(
        "<p class=\"muted\"><a href=\"../champion/{s}.html\">{f}</a> · <a href=\"{s}method.html#builds\">How builds are counted</a></p>\n",
        .{ ch.slug, esc(ch.name), site.toShared(page_path) },
    );
    try html.foot(w, p);
}

/// "52.3% ±2.4", or "few games" under rate_games
fn winRate(w: *Writer, games: u32, wins: u32) !void {
    if (games < rate_games) return w.writeAll("<span class=\"muted\">few games</span>");
    const n: f64 = @floatFromInt(games);
    const rate = @as(f64, @floatFromInt(wins)) / n;
    try w.print("{d:.1}% <span class=\"muted\">±{d:.1}</span>", .{ 100 * rate, 196 * @sqrt(rate * (1 - rate) / n) });
}

fn table(w: *Writer, f: *const File, b: File.Build, kind: Kind, title: []const u8, of: []const u8) !void {
    try w.print(
        "<div class=\"table-scroll\"><table class=\"build\">\n<thead><tr><th>{s}</th><th class=\"num\">Games</th><th class=\"num\">Share</th><th class=\"num\">Win rate</th></tr></thead>\n<tbody>\n",
        .{title},
    );
    const rows = b.get(kind) orelse File.Rows{ .kind = kind, .games = 0, .wins = 0, .options = &.{} };
    if (rows.options.len == 0) {
        try w.writeAll("<tr class=\"thin\"><td colspan=\"4\">More data needed</td></tr>\n");
    }
    for (rows.options[0..@min(rows.options.len, rows_shown)]) |o| {
        try w.print("<tr{s}><td>", .{if (o.games < solid_games) " class=\"thin\"" else ""});
        try value(w, f, kind, o.v);
        try w.print("</td><td class=\"num\">{d}</td><td class=\"num\">{d:.1}%</td><td class=\"num\">", .{
            o.games, 100 * @as(f64, @floatFromInt(o.games)) / @as(f64, @floatFromInt(@max(rows.games, 1))),
        });
        try winRate(w, o.games, o.wins);
        try w.writeAll("</td></tr>\n");
    }
    try w.print("</tbody></table></div>\n<p class=\"muted caption\">Share of {d} {s}.</p>\n", .{ rows.games, of });
}

fn value(w: *Writer, f: *const File, kind: Kind, v: []const u32) !void {
    switch (kind) {
        .keystone, .boots => {
            if (v[0] == 0) return w.writeAll("No boots");
            try named(w, if (kind == .boots) f.items else f.runes, v[0], true);
        },
        .spells => for (v, 0..) |x, i| {
            if (i > 0) try w.writeAll(" ");
            try named(w, f.spells, x, true);
        },
        .runes => for (v, 0..) |x, i| {
            // Trees (0, 5) as a divider, runes as icons
            if (i == 5) try w.writeAll("<span class=\"sep\">|</span>");
            if (i == 0 or i == 5) continue;
            try named(w, f.runes, x, false);
        },
        .shards => for (v, 0..) |x, i| {
            if (i > 0) try w.writeAll(" · ");
            if (ddragon.find(f.runes, x)) |n| try w.print("{f}", .{esc(n.name)}) else try w.print("#{d}", .{x});
        },
        .start => for (v) |x| try named(w, f.items, x, false),
        .core2, .core3 => for (v, 0..) |x, i| {
            if (i > 0) try w.writeAll("<span class=\"sep\">›</span>");
            try named(w, f.items, x, false);
        },
        .skills => for (v, 0..) |x, i| {
            if (i > 0) try w.writeAll("<span class=\"sep\">›</span>");
            try w.print("<b>{s}</b>", .{switch (x) {
                1 => "Q",
                2 => "W",
                3 => "E",
                else => "?",
            }});
        },
    }
}

/// Icon (name as alt and title), and the name beside it with `label`
fn named(w: *Writer, list: []const ddragon.Named, id: u32, label: bool) !void {
    var buf: [16]u8 = undefined;
    const n = ddragon.find(list, id) orelse ddragon.Named{ .id = id, .name = try std.fmt.bufPrint(&buf, "#{d}", .{id}) };
    if (n.icon.len > 0) {
        try w.print("<img class=\"icon\" src=\"{s}\" alt=\"{f}\" title=\"{f}\" width=\"28\" height=\"28\" loading=\"lazy\">", .{
            n.icon, esc(n.name), esc(n.name),
        });
    }
    if (label or n.icon.len == 0) try w.print("<span class=\"label\">{f}</span>", .{esc(n.name)});
}

test "rank label" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try std.testing.expectEqualStrings("Platinum IV and up", try rankLabel(a, "PLATINUM"));
    try std.testing.expectEqualStrings("Master and up", try rankLabel(a, "MASTER"));
    try std.testing.expectEqualStrings("all ranks", try rankLabel(a, ""));
}
