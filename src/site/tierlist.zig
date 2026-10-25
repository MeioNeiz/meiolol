//! champions.html and the role pages: every champion's win rate, by role

const std = @import("std");
const core = @import("core");
const ui = @import("ui");
const html = @import("html.zig");
const spread = @import("../spread.zig");
const builds_page = @import("builds.zig");

const Writer = std.Io.Writer;
const Role = core.Role;
const tpl = html.tpl;

const Champ = @import("root.zig").Champ;
const Site = @import("root.zig").Site;
const ratio = @import("root.zig").ratio;
const earlyNote = @import("root.zig").earlyNote;
const roleName = @import("root.zig").roleName;
const roleIcons = @import("root.zig").roleIcons;
const Thousands = @import("root.zig").Thousands;

/// Below this share of all games a champion's row is a rare pick, listed on request
pub const min_pick_rate = 0.004;
/// And below this share of the champion's own games, as a role it rarely plays
pub const min_role_share = 0.1;

const Row = struct {
    ch: Champ,
    role: Role,
    games: u32,
    wins: u32,
    /// Of the champion's games, the share in this role
    share: f64,
    /// Under min_pick_rate or min_role_share: listed only on request
    rare: bool,
    /// core.banimpact: edge pulled toward the role's average, times pick when available
    impact: f64,
    /// The pulled edge, as a share, for the impact cell's title
    edge: f64,
    /// Win rate pulled toward the role's average (base + edge): the sort order, so a few
    /// lucky games can't top the table
    shrunk: f64,
};

/// Every champion's games in `role`, or in each role it plays when null, by Row.shrunk
/// (ties most played first); the browser sorts by any column (static/table.js)
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
                .share = share,
                .rare = ratio(cr.games, site.games) < min_pick_rate or share < min_role_share,
                .impact = prior.score(cr.wins, cr.games, ch.banned, site.games),
                .edge = prior.edge(cr.wins, cr.games),
                .shrunk = prior.base + prior.edge(cr.wins, cr.games),
            });
        }
    }
    std.mem.sort(Row, rows.items, {}, struct {
        fn f(_: void, a: Row, b: Row) bool {
            return a.games > b.games;
        }
    }.f);
    std.mem.sort(Row, rows.items, {}, struct {
        fn f(_: void, a: Row, b: Row) bool {
            return a.shrunk > b.shrunk;
        }
    }.f);
    return rows.items;
}

pub const Rank = struct { rank: usize, of: usize };

/// The champion's place in its role's champions table (rare picks left out, as the table
/// hides them); null when it is one
pub fn roleRank(site: *const Site, r: Role, id: u32) !?Rank {
    const rows = try tierRows(site, r);
    var n: usize = 0;
    var rank: ?usize = null;
    for (rows) |row| {
        if (row.rare) continue;
        n += 1;
        if (row.ch.id == id) rank = n;
    }
    return if (rank) |k| .{ .rank = k, .of = n } else null;
}

/// The colour scale's key: rates at its stops (wrColour) on `span`, each in its colour
pub fn legend(w: *Writer, span: f64) !void {
    // A matchup's own scale says so: the same rate is paler here than on the champions table
    try w.writeAll(if (span == table_span) "<p class=\"wr-key\">Win rate colour" else "<p class=\"wr-key\">Matchup win rate colour, on a scale twice as wide as the champions table's:");
    const pts = [_]f64{ -5.5, -3.5, -2, 0, 2, 3.5, 5.5 };
    for (pts) |x| {
        const p = 0.5 + x * span / table_span / 100;
        try tpl.render(w, " <span class=\"wrc\" style=\"--c:{colour}\">{rate}%</span>", .{
            .colour = wrColour(p, span),
            .rate = @round(1000 * p) / 10,
        });
    }
    try w.writeAll("</p>\n");
}

/// Win rate as the champions table shows it: a dot at the rate on a track from 25% to
/// 75% (50% marked), an optional shape path behind it (shapePath), then the rate,
/// coloured by wrColour on `span` and fainter with fewer games (curvesfile.fade). `sort`
/// (data-v): the rate pulled toward an average by its games, so sorting by the column
/// can't put a few lucky games on top. Matchup rates (matchup_span) use it bare
pub fn trackCell(w: *Writer, p: f64, sort: f64, games: u32, span: f64, title: []const u8, shape: ?[]const u8) !void {
    try trackCellNoted(w, p, sort, games, span, title, shape);
}

/// The rate in a trackCell, fainter with fewer games
const RateText = struct {
    p: f64,
    games: u32,

    pub fn render(r: RateText, w: *Writer) !void {
        try tpl.render(w, "<b style=\"opacity:{fade:.2}\">{rate:.1}%</b>", .{ .fade = core.curvesfile.fade(r.games), .rate = 100 * r.p });
    }
};

fn trackCellNoted(w: *Writer, p: f64, sort: f64, games: u32, span: f64, title: []const u8, shape: ?[]const u8) !void {
    try tpl.render(w, "<td data-v=\"{sort:.4}\"><span class=\"wr\" style=\"--c:{colour}\" title=\"{title}\"><span class=\"ci\">" ++
        "{shape}<i class=\"d\" style=\"left:{dot:.1}%\"></i></span>" ++
        "{rate}</span></td>", .{
        .sort = sort,
        .colour = wrColour(p, span),
        .title = title,
        .shape = if (shape) |d| tpl.t("<svg class=\"shape\" viewBox=\"0 0 100 10\" preserveAspectRatio=\"none\" aria-hidden=\"true\"><path d=\"{d}\"></path></svg>", .{ .d = d }) else null,
        .dot = trackX(100 * p),
        .rate = RateText{ .p = p, .games = games },
    });
}

pub const table_span = ui.fmt.table_span;
/// A matchup's win rate spreads about twice as wide (it is mostly the opponent's
/// strength): on table_span most would be the vivid end
pub const matchup_span = 0.24;

/// The track's scale: 25% to 75% as 0 to 100
const track_lo = 25.0;
const track_width = 50.0;

fn trackX(rate: f64) f64 {
    return 100 * (std.math.clamp(rate, track_lo, track_lo + track_width) - track_lo) / track_width;
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

pub const wrColour = ui.fmt.wrColour;
pub const WrColour = ui.fmt.WrColour;

/// A win rate in text (.wrc), coloured by wrColour on the champions table's scale and
/// fainter with fewer games, as the table's own
pub fn wrText(w: *Writer, p: f64, games: u32) !void {
    try tpl.render(w, "<span class=\"wrc\" style=\"--c:{colour};opacity:{fade:.2}\">{rate:.1}%</span>", .{
        .colour = wrColour(p, table_span),
        .fade = core.curvesfile.fade(games),
        .rate = 100 * p,
    });
}

/// The champions table's data file, in each view's directory
pub const data_path = "data/tiers.bin";

/// The view's champions table, every role, for ui.tiers: tierRows' rows and order
fn tiersData(site: *const Site) !ui.tiers.Data {
    const a = site.arena;
    const rows = try tierRows(site, null);
    const champs = try a.alloc(ui.tiers.Champ, site.champs.len);
    for (champs, site.champs) |*c, ch| c.* = .{ .name = ch.name, .key = ch.key, .slug = ch.slug, .banned = ch.banned };
    const out = try a.alloc(ui.tiers.Row, rows.len);
    const s = &site.spread;
    for (out, rows) |*o, row| {
        const pd = if (site.patchday) |*pd| pd else null;
        const move = if (pd) |x| x.champion(row.ch.id, row.role) else null;
        const sp = if (s.get(row.ch.id)) |c| (if (c.players >= s.min_players) c else null) else null;
        o.* = .{
            .champ = @intCast(site.by_c[row.ch.c].?),
            .role = @fromBackingInt(@as(u8, @backingInt(row.role))),
            .games = row.games,
            .wins = row.wins,
            .share = @floatCast(row.share),
            .shrunk = @floatCast(row.shrunk),
            .impact = @floatCast(row.impact),
            .edge = @floatCast(row.edge),
            .fade = @floatCast(core.curvesfile.fade(row.games)),
            .spread = if (sp) |c| .{ .players = c.players, .p25 = c.p25, .p75 = c.p75, .shape = c.shape } else null,
            .patch = if (move) |m| .{
                .prev = .{ m.win.prev.games, m.win.prev.wins },
                .cur = .{ m.win.cur.games, m.win.cur.wins },
                .clear = m.win.clear(pd.?.opts.min_role_games, pd.?.opts.z),
            } else null,
        };
    }
    return .{
        .games = site.games,
        .min_games = @intFromFloat(@ceil(min_pick_rate * @as(f64, @floatFromInt(site.games)))),
        .min_share = @intFromFloat(100 * min_role_share),
        .spread_min_games = s.min_games,
        .cur_patch = if (site.patchday) |pd| pd.cur_patch else "",
        .prev_patch = if (site.patchday) |pd| pd.prev_patch else "",
        .region_in = site.view.region.in(),
        .ddragon = site.ddragon_version,
        .query = site.view.query(),
        .champs = champs,
        .rows = out,
    };
}

/// data/tiers.bin
pub fn dataFile(site: *const Site) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    try ui.data.encode(site.arena, ui.tiers.Data, try tiersData(site), &out);
    return out.items;
}

comptime {
    std.debug.assert(ui.tiers.shape_points == spread.shape_points and ui.tiers.shape_step == spread.shape_step and ui.tiers.shape_reach == spread.shape_reach);
    for (Role.all, 0..) |r, i| {
        std.debug.assert(std.mem.eql(u8, roleName(r), ui.tiers.Role.names[i]));
        std.debug.assert(std.mem.eql(u8, r.label(), ui.tiers.Role.slugs[i]));
    }
}

/// Champions table: the ui.tiers island, rendered from the same data its file carries
/// (ui-stats.wasm sorts, searches and sets the minimums). The role icons and the shape's
/// gradient stay outside it: string styles, which the tree refuses
fn tierTable(site: *const Site, w: *Writer, role: ?Role, root: []const u8) !void {
    const a = site.arena;
    const d = try a.create(ui.tiers.Data);
    d.* = try tiersData(site);
    var bytes: std.ArrayList(u8) = .empty;
    try ui.data.encode(a, ui.tiers.Data, d.*, &bytes);
    const base = try std.mem.concat(a, u8, &.{ root, site.view.up() });
    const r: ?ui.tiers.Role = if (role) |x| @fromBackingInt(@as(u8, @backingInt(x))) else null;
    var t: ui.tiers.Tiers = .{
        .data = d,
        .cells = try ui.tiers.prepare(a, d, r, base),
        .role = r,
        .root = root,
        .base = base,
        .src = try std.mem.concat(a, u8, &.{ root, data_path }),
        .stamp = ui.tiers.stamp(bytes.items),
    };
    var tree: ui.Tree = .{};
    var h: ui.H = .init(a, &tree);
    tree.root = t.view(&h);
    if (h.oom) return error.OutOfMemory;
    try roleIcons(w);
    try shapeGradient(w);
    try ui.html.write(&tree, tree.root, w);
    try tpl.render(w, "\n<script src=\"{js}\" data-wasm=\"ui-stats.wasm\" defer></script>\n", .{
        .js = html.Link{ .root = root, .up = site.view.up(), .path = "ui-stats.js" },
    });
}

pub fn writeTierList(site: *const Site, w: *Writer, role: ?Role) !void {
    const a = site.arena;
    const name = if (role) |r| roleName(r) else "All";
    const title = if (role) |r|
        try a.print("{s} lane champions, {s} | meiolol", .{ roleName(r), site.period() })
    else
        try a.print("Champions, {s} | meiolol", .{site.period()});
    const desc = try a.print("{s} champions in ranked solo queue {s}, {s}: win rate with how sure it is, pick and ban rates, influence.", .{ name, site.view.region.in(), site.when });
    const path = if (role) |r| try a.print("role/{s}.html", .{r.label()}) else "champions.html";
    const root = try site.toRoot(path);
    const p = try site.page(title, desc, path, .champions);
    try html.head(w, p);
    if (role) |r| {
        try tpl.render(w, "<h1>{role} lane champions</h1>\n", .{ .role = roleName(r) });
    } else try tpl.render(w, "<h1>Champions</h1>\n", .{});
    try tpl.render(w,
        \\<p class="muted"><b>{games}</b> Platinum+ ranked solo/duo games {in}, {when}.{builds}</p>
        \\
    , .{
        .games = Thousands{ .n = site.games },
        .in = site.view.region.in(),
        .when = site.when,
        .builds = if (site.view_builds[site.view.index()] != null) tpl.t(" <a href=\"{href}\">Builds, {period}</a>.", .{
            .href = try std.mem.concat(a, u8, &.{ root, builds_page.index_path }),
            .period = site.period(),
        }) else null,
    });
    try earlyNote(site, w, false);
    try tierTable(site, w, role, root);
    try tpl.render(w,
        \\<p class="muted small">Win rate: the champion's, the dot. Bar: how its players' own win rates spread around it, thicker where more players are, players with {min}+ games on it in any role, {period} (none under {need} such players). On a scale from 25% to 75%, 50% marked. In 10 to 20 games luck alone moves a player's win rate by about 15 points, so much of the spread is luck. Influence: games won above the role's average, per 10,000 games the champion was not banned: its win rate over the role's average, pulled toward the average the fewer its games (so a few hundred lucky games can't make a big number), times how often it was picked in those games. 30: in every 10,000 such games, its team won about 30 more than the role's average win rate would give. High: often played and winning more than most, so a ban takes it away often. Below 0: winning less than most. Per 10,000 so the numbers are whole games (per 1,000 most would be under 1); the scale of lolalytics' PBI, which has no pull. A past-games measure, not a promise about your game.</p>
        \\
    , .{ .min = site.spread.min_games, .period = site.periodText(site.view.period), .need = site.spread.min_players });
    try html.foot(w, p);
}
