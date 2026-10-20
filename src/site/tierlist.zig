//! champions.html and the role pages: every champion's win rate, by role

const std = @import("std");
const core = @import("core");
const html = @import("html.zig");
const spread = @import("../spread.zig");
const builds_page = @import("builds.zig");

const Writer = std.Io.Writer;
const Role = core.Role;
const tpl = html.tpl;

const Champ = @import("root.zig").Champ;
const Site = @import("root.zig").Site;
const pct = @import("root.zig").pct;
const ratio = @import("root.zig").ratio;
const earlyNote = @import("root.zig").earlyNote;
const roleSlug = @import("root.zig").roleSlug;
const roleName = @import("root.zig").roleName;
const thousands = @import("root.zig").thousands;

/// Below this share of all games a champion's row is a rare pick, listed on request
const min_pick_rate = 0.004;
/// And below this share of the champion's own games, as a role it rarely plays
pub const min_role_share = 0.1;

const Row = struct {
    ch: Champ,
    role: Role,
    games: u32,
    wins: u32,
    /// Under min_pick_rate or min_role_share: listed only on request
    rare: bool,
    /// core.banimpact: edge pulled toward the role's average, times pick when available
    impact: f64,
    /// The pulled edge, as a share, for the impact cell's title
    edge: f64,
};

/// Every champion's games in `role`, or in each role it plays when null. Most played
/// first; the browser sorts by any column (static/table.js)
fn tierRows(site: *const Site, role: ?Role) ![]Row {
    var rows: std.ArrayList(Row) = .empty;
    for (Role.all) |r| {
        if (role != null and role.? != r) continue;
        const prior = core.banimpact.Prior.of(&site.stats, r);
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
                .impact = prior.score(cr.wins, cr.games, ch.banned, site.games),
                .edge = prior.edge(cr.wins, cr.games),
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

/// Champions table's win rate cell: trackCell with the shape of its players' own win
/// rates around it (spread.zig), mirrored about the track and coloured by win rate
/// along it (shapeGradient); none under min_players. The shape doesn't narrow as games
/// come in; only the rate fades
fn distCell(w: *Writer, site: *const Site, ch: Champ, wins: u32, games: u32) !void {
    const p = ratio(wins, games);
    const s = &site.spread;
    const players = if (s.get(ch.id)) |c| (if (c.players >= s.min_players) c else null) else null;
    const title = if (players) |c|
        try site.arena.print("{d} games; players with {d}+ games on {s}: middle half {d}% to {d}% ({d} players)", .{ games, s.min_games, ch.name, c.p25, c.p75, c.players })
    else
        try site.arena.print("{d} games", .{games});
    const shape = if (players) |c| try shapePath(site.arena, c.shape, 100 * p) else null;
    try trackCell(w, p, games, table_span, title, shape);
}

/// Win rate as the champions table shows it: a dot at the rate on a track from 25% to
/// 75% (50% marked), an optional shape path behind it (shapePath), then the rate,
/// coloured by wrColour on `span` and fainter with fewer games (curvesfile.fade). data-v
/// for sorting. Matchup rates (matchup_span) use it bare
pub fn trackCell(w: *Writer, p: f64, games: u32, span: f64, title: []const u8, shape: ?[]const u8) !void {
    try tpl.render(w, "<td data-v=\"{p:.4}\"><span class=\"wr\" style=\"--c:{colour}\" title=\"{title}\"><span class=\"ci\">" ++
        "{shape}<i class=\"d\" style=\"left:{dot:.1}%\"></i></span>" ++
        "<b style=\"opacity:{fade:.2}\">{rate:.1}%</b></span></td>", .{
        .p = p,
        .colour = wrColour(p, span),
        .title = title,
        .shape = if (shape) |d| tpl.t("<svg class=\"shape\" viewBox=\"0 0 100 10\" preserveAspectRatio=\"none\" aria-hidden=\"true\"><path d=\"{d}\"></path></svg>", .{ .d = d }) else null,
        .dot = trackX(100 * p),
        .fade = core.curvesfile.fade(games),
        .rate = 100 * p,
    });
}

/// wrColour's span on the champions table, and for anything coloured to match it
pub const table_span = 0.12;
/// A matchup's win rate spreads about twice as wide (it is mostly the opponent's
/// strength): on table_span most would be the vivid end
pub const matchup_span = 0.24;

/// The track's scale: 25% to 75% as 0 to 100
const track_lo = 25.0;
const track_width = 50.0;

fn trackX(rate: f64) f64 {
    return 100 * (std.math.clamp(rate, track_lo, track_lo + track_width) - track_lo) / track_width;
}

/// The shape's outline centred on `centre`% in a 100 x 10 box: along the top, back
/// along the bottom, pointed at both ends; it fades out towards the track's ends
/// (#wr-edge), past them clipped
fn shapePath(a: std.mem.Allocator, shape: [spread.shape_points]u8, centre: f64) ![]const u8 {
    const Point = struct {
        fn x(c: f64, k: usize) f64 {
            const off = @as(f64, @floatFromInt(spread.shape_step * k)) - spread.shape_reach;
            return 100 * (c + off - track_lo) / track_width;
        }
        fn half(v: u8) f64 {
            return 5 * @as(f64, @floatFromInt(v)) / 255;
        }
    };
    var out: std.ArrayList(u8) = .empty;
    try out.print(a, "M{d:.1} 5", .{Point.x(centre, 0)});
    for (shape, 0..) |v, k| {
        try out.print(a, "L{d:.1} {d:.2}", .{ Point.x(centre, k), 5 - Point.half(v) });
    }
    try out.print(a, "L{d:.1} 5", .{Point.x(centre, spread.shape_points - 1)});
    var k: usize = spread.shape_points;
    while (k > 0) {
        k -= 1;
        try out.print(a, "L{d:.1} {d:.2}", .{ Point.x(centre, k), 5 + Point.half(shape[k]) });
    }
    try out.append(a, 'Z');
    return out.items;
}

/// One gradient and edge mask for every row's shape: orange at the track's low end
/// through grey at 50% to blue at its high end, as win rates are coloured, fading out
/// over the outer tenth at each end
fn shapeGradient(w: *Writer) !void {
    try w.writeAll("<svg width=\"0\" height=\"0\" style=\"position:absolute\" aria-hidden=\"true\"><defs>" ++
        "<linearGradient id=\"wr-shape\" gradientUnits=\"userSpaceOnUse\" x1=\"0\" x2=\"100\" y1=\"0\" y2=\"0\">" ++
        "<stop offset=\"0\" class=\"lo\"></stop><stop offset=\"0.5\" class=\"mid\"></stop><stop offset=\"1\" class=\"hi\"></stop></linearGradient>" ++
        "<linearGradient id=\"wr-fade\" gradientUnits=\"userSpaceOnUse\" x1=\"0\" x2=\"100\" y1=\"0\" y2=\"0\">" ++
        "<stop offset=\"0\" stop-color=\"#000\"></stop><stop offset=\"0.1\" stop-color=\"#fff\"></stop>" ++
        "<stop offset=\"0.9\" stop-color=\"#fff\"></stop><stop offset=\"1\" stop-color=\"#000\"></stop></linearGradient>" ++
        "<mask id=\"wr-edge\" maskUnits=\"userSpaceOnUse\" x=\"0\" y=\"0\" width=\"100\" height=\"10\">" ++
        "<rect width=\"100\" height=\"10\" fill=\"url(#wr-fade)\"></rect></mask></defs></svg>\n");
}

/// Win rate colour on the site's diverging scale (style.css --lo4 to --hi4,
/// docs/design-ideas.md): continuous, orange then hot pink below 50%, blue then aqua
/// above, each colour at its stop's points (scaled by span / table_span). Grey only when
/// it shows as 50.0%: every other rate has a side (J12). Not red against green: the
/// pair red-green colour blindness merges. Few games fade by opacity, not colour
pub fn wrColour(p: f64, span: f64) WrColour {
    return .{ .pts = 100 * (p - 0.5) * table_span / span };
}

/// Aggregate scale (a champion's or matchup's rate over many games): the points where
/// --hi1..--hi4 sit; past the last, --hi4 as a filled chip with dark ink. 4% of
/// champion roles with 500+ games reach it
const stops = [_]f64{ 0, 2, 3.5, 5.5 };

pub const WrColour = struct {
    pts: f64,

    /// The value of --c: a mix of the two stops either side; past the last stop it
    /// also sets --chip, so the number shows as dark ink on a vivid fill (style.css)
    pub fn format(c: WrColour, w: *Writer) Writer.Error!void {
        const side = if (c.pts < 0) "lo" else "hi";
        const x = @abs(c.pts);
        if (x < 0.05) return w.writeAll("var(--s0)");
        if (x >= stops[stops.len - 1]) return w.print("var(--chip-ink);--chip:var(--{s}4)", .{side});
        var i: usize = 1;
        while (x >= stops[i]) i += 1;
        const t = (x - stops[i - 1]) / (stops[i] - stops[i - 1]);
        const near: u8 = @intFromFloat(@round(100 * (1 - t)));
        if (near == 100) return w.print("var(--{s}{d})", .{ side, i });
        if (near == 0) return w.print("var(--{s}{d})", .{ side, i + 1 });
        try w.print("color-mix(in oklab,var(--{s}{d}) {d}%,var(--{s}{d}))", .{ side, i, near, side, i + 1 });
    }
};

test wrColour {
    var buf: [96]u8 = undefined;
    const cases = .{
        .{ 0.5004, "var(--s0)" },
        .{ 0.501, "color-mix(in oklab,var(--hi1) 95%,var(--hi2))" },
        .{ 0.495, "color-mix(in oklab,var(--lo1) 75%,var(--lo2))" },
        .{ 0.52, "var(--hi2)" },
        .{ 0.545, "color-mix(in oklab,var(--hi3) 50%,var(--hi4))" },
        .{ 0.44, "var(--chip-ink);--chip:var(--lo4)" },
    };
    inline for (cases) |c| {
        const s = try std.fmt.bufPrint(&buf, "{f}", .{wrColour(c[0], table_span)});
        try std.testing.expectEqualStrings(c[1], s);
    }
}

/// A win rate in text (.wrc), coloured by wrColour on the champions table's scale and
/// fainter with fewer games, as the table's own
pub fn wrText(w: *Writer, p: f64, games: u32) !void {
    try tpl.render(w, "<span class=\"wrc\" style=\"--c:{colour};opacity:{fade:.2}\">{rate:.1}%</span>", .{
        .colour = wrColour(p, table_span),
        .fade = core.curvesfile.fade(games),
        .rate = 100 * p,
    });
}

/// All roles (champions.html) and one per role (role/<slug>.html)
fn roleTabs(w: *Writer, current: ?Role, root: []const u8) !void {
    try tpl.renderPart(w, "<nav class=\"tabs\"><a href=\"{root}champions.html\"{current}>All roles</a>", .{
        .root = root,
        .current = tpl.flag(current == null, "aria-current=\"page\""),
    });
    for (Role.all) |r| {
        try tpl.render(w, "<a href=\"{root}role/{slug}.html\"{current}>{name}</a>", .{
            .root = root,
            .slug = roleSlug(r),
            .current = tpl.flag(current == r, "aria-current=\"page\""),
            .name = roleName(r),
        });
    }
    try tpl.renderPart(w, "</nav>\n", .{});
}

/// Champions table: win rate, pick and ban rate, games. Rows sorted by win rate; rare picks hidden until asked for
fn tierTable(site: *const Site, w: *Writer, role: ?Role, root: []const u8) !void {
    const rows = try tierRows(site, role);
    std.mem.sort(Row, rows, {}, struct {
        fn f(_: void, a: Row, b: Row) bool {
            return ratio(a.wins, a.games) > ratio(b.wins, b.games);
        }
    }.f);
    try tpl.renderPart(w, "<div class=\"tl-bar\">", .{});
    try roleTabs(w, role, root);
    try tpl.renderPart(w,
        \\<input type="search" placeholder="Search champion" data-filter="tiers" aria-label="Search champion"></div>
        \\{gradient}<div class="tl-wrap"><table class="tl" id="tiers" data-sortable>
        \\<thead><tr><th class="rank">#</th><th class="l" data-sort="text">Champion</th>{role}<th data-sort="num" aria-sort="descending">Win rate</th><th data-sort="num" class="opt">Pick</th><th data-sort="num" class="opt">Ban</th><th data-sort="num" title="Win rate over the role's average, pulled toward it the fewer the games, times how often it is picked when not banned">Influence</th><th data-sort="num">Games</th></tr></thead>
        \\<tbody>
        \\
    , .{
        .gradient = tpl.call(shapeGradient, .{}),
        .role = tpl.when(role == null, tpl.t("<th class=\"l\" data-sort=\"text\">Role</th>", .{})),
    });
    const to_site = try std.mem.concat(site.arena, u8, &.{ root, site.view.up() });
    var rare: usize = 0;
    var n: usize = 0;
    for (rows) |row| {
        if (row.rare) rare += 1 else n += 1;
        try tpl.render(w,
            \\<tr class="bx" data-name="{name}"{rare}><td class="rank">{n}</td><td class="l">{link}</td>{role}{wr}<td class="opt" data-v="{games}">{pick}</td><td class="opt" data-v="{banned}">{ban}</td>{impact}<td class="dim" data-v="{games}">{games}</td></tr>
            \\
        , .{
            .name = row.ch.name,
            .rare = tpl.flag(row.rare, "data-rare hidden"),
            .n = n,
            .link = tpl.call(champLinkTo, .{ site, row.ch, to_site }),
            .role = tpl.when(role == null, tpl.t("<td class=\"l role\" data-v=\"{role}\">{role}</td>", .{ .role = roleName(row.role) })),
            .wr = tpl.call(distCell, .{ site, row.ch, row.wins, row.games }),
            .games = row.games,
            .pick = tpl.call(pct, .{ row.games, site.games }),
            .banned = row.ch.banned,
            .ban = tpl.call(pct, .{ row.ch.banned, site.games }),
            .impact = tpl.call(impactCell, .{ row, site.games }),
        });
    }
    try tpl.renderPart(w,
        \\</tbody></table></div>
        \\{more}<script src="{table_js}" defer></script>
        \\
    , .{
        .more = tpl.when(rare > 0, tpl.t(
            \\<p class="tl-more">{rare} rare picks (under {min:.1}% pick rate, or a role the champion seldom plays) hidden. <button class="link" data-show-rare="tiers">Show them</button></p>
            \\
        , .{ .rare = rare, .min = 100 * min_pick_rate })),
        .table_js = html.Link{ .root = root, .up = site.view.up(), .path = "table.js" },
    });
}

/// Influence (ban impact), one decimal as lolalytics' PBI; below 0 dim. Title: its two parts
fn impactCell(w: *Writer, row: Row, total: u64) !void {
    const available = total -| row.ch.banned;
    try tpl.render(w, "<td class=\"{class}\" data-v=\"{v:.3}\" title=\"Win rate {edge:.1} points {side} the role's average once pulled toward it; picked in {pick:.1}% of games it was not banned\">{minus}{abs:.1}</td>", .{
        .class = if (row.impact < 0) "bi dim" else "bi",
        .v = row.impact,
        // U+2212: tabular figures space a hyphen out as if it were a digit
        .minus = if (row.impact <= -0.05) "\u{2212}" else "",
        .abs = @abs(row.impact),
        .edge = 100 * @abs(row.edge),
        .side = if (row.edge < 0) "under" else "over",
        .pick = if (available == 0) 0 else 100 * @as(f64, @floatFromInt(row.games)) / @as(f64, @floatFromInt(available)),
    });
}

/// Site.champBox for tpl.call
fn champLinkTo(w: *Writer, site: *const Site, ch: Champ, to_site: []const u8) !void {
    return site.champBox(w, ch, to_site);
}

pub fn writeTierList(site: *const Site, w: *Writer, role: ?Role) !void {
    const a = site.arena;
    const name = if (role) |r| roleName(r) else "All";
    const title = if (role) |r|
        try a.print("{s} lane champions, {s} | meiolol", .{ roleName(r), site.when })
    else
        try a.print("Champions, {s} | meiolol", .{site.when});
    const desc = try a.print("{s} champions in ranked solo queue {s}, {s}: win rate with how sure it is, pick and ban rates, influence.", .{ name, site.view.region.in(), site.when });
    const path = if (role) |r| try a.print("role/{s}.html", .{roleSlug(r)}) else "champions.html";
    const root = site.toRoot(path);
    const p = site.page(title, desc, path, .champions);
    try html.head(w, p);
    if (role) |r| {
        try tpl.render(w, "<h1>{role} lane champions</h1>\n", .{ .role = roleName(r) });
    } else try tpl.render(w, "<h1>Champions</h1>\n", .{});
    const patch_view: html.View = .{ .region = site.view.region, .period = .patch };
    try tpl.render(w,
        \\<p class="muted"><b>{games}</b> Platinum+ ranked solo/duo games {in}, {when}.{builds}</p>
        \\
    , .{
        .games = try thousands(a, site.games),
        .in = site.view.region.in(),
        .when = site.when,
        .builds = if (site.view_builds[patch_view.index()] != null) tpl.t(" <a href=\"{href}\">Builds for patch {patch}</a>.", .{
            .href = try std.mem.concat(a, u8, &.{ root, site.view.up(), patch_view.dir(), builds_page.index_path }),
            .patch = site.patch,
        }) else null,
    });
    try earlyNote(site, w, false);
    try tierTable(site, w, role, root);
    try tpl.render(w,
        \\<p class="muted small">Win rate: the champion's, the dot. Bar: how its players' own win rates spread around it, thicker where more players are, players with {min}+ games on it (every role and patch we have; none under {need} such players). On a scale from 25% to 75%, 50% marked. In 10 to 20 games luck alone moves a player's win rate by about 15 points, so much of the spread is luck. Influence: how far the champion's win rate in the role sits above the role's average, pulled toward the average the fewer its games (so a few hundred lucky games can't make a big number), times its pick rate in the games it was not banned; as lolalytics' PBI. High: often played and winning more than most, so a ban takes it away often. Below 0: winning less than most. A past-games measure, not a promise about your game.</p>
        \\
    , .{ .min = site.spread.min_games, .need = site.spread.min_players });
    try html.foot(w, p);
}
