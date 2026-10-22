//! Champion pages (champion/<slug>.html): lane opponents by role, the filter bar

const std = @import("std");
const core = @import("core");
const html = @import("html.zig");
const matchup = @import("matchup.zig");
const pool_page = @import("pool.zig");
const learning_page = @import("learning.zig");
const spread_page = @import("spread.zig");
const builds_page = @import("builds.zig");
const lean_line = @import("lean.zig");
const filters = @import("filters.zig");
const patch_page = @import("patch.zig");

const Writer = std.Io.Writer;
const Stats = core.Stats;
const Role = core.Role;
const tpl = html.tpl;

const root = @import("root.zig");
const min_role_share = @import("tierlist.zig").min_role_share;
const Champ = root.Champ;
const Site = root.Site;
const pct = root.pct;
const ratio = root.ratio;
const earlyNote = root.earlyNote;
const roleSlug = root.roleSlug;
const roleName = root.roleName;
const tierlist = @import("tierlist.zig");

/// Champion page: lane opponents with fewer games are faded and listed last
const min_opponent_games = 10;
/// And those under this share of the champion's games in the role are hidden until asked
/// for: the Opponents filter's default, "Seen in 1%+ of games"
const min_opponent_share = 0.01;

comptime {
    for (html.ranks[1..], [_][]const u8{ "EMERALD", "DIAMOND", "MASTER" }) |r, tier| {
        std.debug.assert(std.mem.eql(u8, filters.tiers[std.fmt.parseInt(usize, r[0], 10) catch unreachable], tier));
    }
}

const Opponent = struct {
    other: Champ,
    games: u32,
    wins: u32,
    /// The opponent's own win rate in the role, for usual()
    strength: f64,
};

/// One page per champion, from the root view (EUW, 30 days) at the site root; its
/// filters (the subbar's picks, filterBar's data) show the other views and any other
/// region or rank
pub fn writeChampion(site: *const Site, w: *Writer, ch: Champ) !void {
    const a = site.arena;
    const st = &site.stats;
    const title = try a.print("{s} win rate, lane opponents and curves | meiolol", .{ch.name});
    const desc = try a.print("{s} in ranked solo queue by region, rank and patch: win rate with how sure it is, every lane opponent and lane curves.", .{ch.name});
    const path = try a.print("champion/{s}.html", .{ch.slug});
    var p = site.sharedPage(title, desc, .champions);
    p.root = "../";
    p.counterparts = @as([html.View.count][]const u8, undefined);
    for (html.View.all, &p.counterparts.?) |v, *there| there.* = try std.mem.concat(a, u8, &.{ path, v.query() });
    p.canonical = site.canonical("", path);
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
    try tpl.render(w,
        \\<div class="hero"><img src="{icon}" alt="" width="64" height="64"><div><h1>{name}</h1><p class="muted">Ranked solo/duo <span data-scope>{in}, {when}, Platinum+ games</span>.{plays}</p></div></div>
        \\
    , .{
        .icon = site.icon(ch),
        .name = ch.name,
        .in = site.view.region.in(),
        .when = site.when,
        .plays = tpl.when(n_roles > 1, tpl.t(" Plays {roles}.", .{ .roles = tpl.call(roleLinks, .{roles[0..n_roles]}) })),
    });
    try earlyNote(site, w, true);
    try filterBar(site, w, ch);
    if (site.by_view.len > 0) {
        try w.writeAll("<div data-by-view>");
        for (html.View.all, site.by_view) |v, *b| {
            try variant(w, &.{v});
            try spread_page.section(w, &b.spread, ch, v.region, site.periodText(v.period));
            try w.writeAll("</div>");
        }
        try w.writeAll("</div>\n");
    }
    if (n_roles == 0) try tpl.render(w, "<p>No games yet.</p>\n", .{});

    for (roles[0..n_roles]) |r| {
        const cr = st.champRole(r, ch.c);
        const rate = ratio(cr.wins, cr.games);
        const rank = try tierlist.roleRank(site, r, ch.id);
        try tpl.renderPart(w,
            \\<section id="{slug}"><h2>{role}</h2>
            \\<div class="tiles"><div data-tile="wr"><span>Win rate</span><b class="wrc" style="--c:{colour};opacity:{fade:.2}">{wr}</b><small data-rank>{rank}{won}</small></div><div data-tile="pick"><span>Pick rate</span><b>{pick}</b><small>of games</small></div><div data-tile="ban"><span>Ban rate</span><b>{ban}</b><small>of games</small></div><div data-tile="games"><span>Games</span><b>{games}</b><small>{role} lane</small></div></div>
            \\
        , .{
            .slug = roleSlug(r),
            .role = roleName(r),
            .colour = tierlist.wrColour(rate, tierlist.table_span),
            .fade = core.curvesfile.fade(cr.games),
            .wr = tpl.call(pct, .{ cr.wins, cr.games }),
            .rank = if (rank) |k| tpl.t("<a href=\"../role/{slug}.html\">{n}{th} of {of} in {role}</a>", .{
                .slug = roleSlug(r),
                .n = k.rank,
                .th = ordinal(k.rank),
                .of = k.of,
                .role = roleName(r),
            }) else null,
            .won = tpl.when(rank == null, "of games won"),
            .pick = tpl.call(pct, .{ cr.games, site.games }),
            .ban = tpl.call(pct, .{ ch.banned, site.games }),
            .games = try root.thousands(site.arena, cr.games),
        });

        var opps: std.ArrayList(Opponent) = .empty;
        for (site.champs) |other| {
            if (other.c == ch.c) continue;
            const e = st.enemy(r, r, ch.c, other.c);
            if (e.games == 0) continue;
            const oc = st.champRole(r, other.c);
            try opps.append(a, .{ .other = other, .games = e.games, .wins = e.wins, .strength = ratio(oc.wins, oc.games) });
        }
        if (site.lean) |l| try lean_line.line(w, l, ch.id, ch.name, r, "../method.html#lean");
        try patch_page.since(site, w, ch, r, "../");
        try w.writeAll("<div data-by-view>");
        for (html.View.all) |v| {
            try variant(w, &.{v});
            _ = try builds_page.strip(site, w, ch, r, path, v);
            try w.writeAll("</div>");
        }
        try w.writeAll("</div>\n");
        try opponentTable(site, w, ch, r, cr, opponentK(st, r), usualK(st, r), opps.items);
        try tpl.renderPart(w, "</section>\n", .{});
    }
    try pool_page.section(site, w, &site.pool, ch);
    // Every region's (learning.zig): one per period
    if (site.by_view.len > 0) {
        try w.writeAll("<div data-by-view>");
        for ([_]html.Period{ .days30, .patch }) |period| {
            const views = [_]html.View{ .{ .region = .euw, .period = period }, .{ .region = .all, .period = period } };
            try variant(w, &views);
            try learning_page.section(site, w, &site.by_view[views[0].index()].learning, ch, site.periodText(period));
            try w.writeAll("</div>");
        }
        try w.writeAll("</div>\n");
    }
    try tpl.render(w,
        \\<p class="muted small">Win rates are raw: no pulling toward 50%, fainter under {full} games; coloured on a scale twice as wide as the champions table's (a matchup's rate is mostly the opponent's strength), a dot on 25% to 75%. Vs usual: how much more or less often than usual the champion won in the matchup, in points, after allowing for the opponent's own win rate in the role (against a strong opponent it usually wins less), pulled toward 0 the fewer the games so a thin matchup stays quiet; the matchup page has the numbers behind it. Hardest first, and sorting by win rate, use the win rate pulled toward the champion's own in the role, the more so the fewer the games, so a few lucky games can't top the list. Gold at {minute} min is the lane curve's estimate, then where 8 games in 10 end (10th to 90th percentile); + when the champion is ahead, in plain ink (gold is not a win rate), fainter under {full} games; for filters other than a region and period above, the plain average of the games picked. <a href="../method.html">Method</a>.</p>
        \\<script src="../table.js" defer></script>
        \\<script src="../filters.js" defer></script>
        \\
    , .{ .minute = core.curvesfile.lane_minute, .full = core.curvesfile.full_games });
    try html.foot(w, p);
}

/// Opens a variant of a [data-by-view] group for `views`: static/filters.js shows the one
/// for its picks' view; as written, the root view's
fn variant(w: *Writer, views: []const html.View) !void {
    try w.writeAll("<div data-view=\"");
    for (views, 0..) |v, i| try w.print("{s}{d}", .{ if (i == 0) "" else " ", v.index() });
    try w.writeAll("\"");
    for (views) |v| {
        if (v.index() == 0) break;
    } else try w.writeAll(" hidden");
    try w.writeAll(">");
}

/// 1 -> "st", 12 -> "th", 22 -> "nd"
fn ordinal(n: usize) []const u8 {
    if (n % 100 >= 11 and n % 100 <= 13) return "th";
    return switch (n % 10) {
        1 => "st",
        2 => "nd",
        3 => "rd",
        else => "th",
    };
}

/// "<a>Top</a>, <a>Jungle</a> and <a>Mid</a>"
fn roleLinks(w: *Writer, roles: []const Role) !void {
    for (roles, 0..) |r, i| {
        try tpl.render(w, "{sep}<a href=\"#{slug}\">{name}</a>", .{
            .sep = if (i == 0) null else if (i + 1 == roles.len) " and " else ", ",
            .slug = roleSlug(r),
            .name = roleName(r),
        });
    }
}

/// Where static/filters.js finds the champion's filter data; the picks themselves are the
/// subbar's (html.zig switches), set to the page as written (the root view)
fn filterBar(site: *const Site, w: *Writer, ch: Champ) !void {
    try tpl.render(w,
        \\<div hidden data-filters data-src="../data/filters/{slug}.json" data-meta="../data/filters.json" data-champions="../data/champions.json" data-ddragon="{ddragon}" data-id="{id}" data-region="{region}"></div>
        \\
    , .{
        .slug = ch.slug,
        .ddragon = site.ddragon_version,
        .id = ch.id,
        .region = site.opts.platforms[0],
    });
}

/// Games to stabilise (k) for a lane opponent's win rate in role r: game-to-game variance
/// over how much true rates against different opponents differ from the champion's own,
/// measured over every champion (method of moments, as curvefit for the curves). A rate
/// on n games gets the weight n / (n + k) against the champion's rate in the role
fn opponentK(st: *const Stats, r: Role) f64 {
    var q: f64 = 0;
    var noise: f64 = 0;
    var scale: f64 = 0;
    for (0..st.n) |c| {
        var n: f64 = 0;
        var wins: f64 = 0;
        var n2: f64 = 0;
        var cells: f64 = 0;
        for (0..st.n) |o| {
            const e = st.enemy(r, r, c, o);
            if (o == c or e.games == 0) continue;
            const g: f64 = @floatFromInt(e.games);
            n += g;
            wins += @floatFromInt(e.wins);
            n2 += g * g;
            cells += 1;
        }
        if (cells < 2) continue;
        const m = wins / n;
        for (0..st.n) |o| {
            const e = st.enemy(r, r, c, o);
            if (o == c or e.games == 0) continue;
            const g: f64 = @floatFromInt(e.games);
            const d = @as(f64, @floatFromInt(e.wins)) - g * m;
            q += d * d / g;
        }
        noise += (cells - 1) * m * (1 - m);
        scale += n - n2 / n;
    }
    // Rates spread at least 1 point beyond noise (k at most 2,500) and at most 10
    const tau2 = std.math.clamp((q - noise) / @max(scale, 1), 0.0001, 0.01);
    return 0.25 / tau2;
}

/// Opponent's win rate pulled toward the champion's own in the role by games (opponentK)
fn shrunk(o: Opponent, base: f64, k: f64) f64 {
    return (@as(f64, @floatFromInt(o.wins)) + k * base) / (@as(f64, @floatFromInt(o.games)) + k);
}

/// What ch usually wins against an opponent: ch's own win rate in the role (`base`)
/// moved by the opponent's own there (`strength`), on the log-odds scale. Two 50%
/// champions: 50%; a 53% champion against a 47% one: 55.9%
pub fn usual(base: f64, strength: f64) f64 {
    const logit = struct {
        fn f(x: f64) f64 {
            const c = std.math.clamp(x, 0.01, 0.99);
            return @log(c / (1 - c));
        }
    }.f;
    return 1 / (1 + @exp(logit(strength) - logit(base)));
}

/// A matchup's win rate against usual(), as a share: the matchup's rate pulled toward
/// usual by k games (usualK) minus usual, so (wins - games * usual) / (games + k) and a
/// thin matchup reads near 0. sd: its spread, sqrt(usual (1 - usual) / (games + k))
pub const VsUsual = struct {
    mean: f64,
    sd: f64,

    pub fn of(wins: u32, games: u32, e: f64, k: f64) VsUsual {
        const n: f64 = @floatFromInt(games);
        return .{
            .mean = (@as(f64, @floatFromInt(wins)) - n * e) / (n + k),
            .sd = @sqrt(e * (1 - e) / (n + k)),
        };
    }
};

/// Games to stabilise (k) for a matchup's win rate against usual() in role r: as
/// opponentK, but how much true rates differ from usual(), the opponent's strength
/// allowed for, so less than opponentK's spread and a larger k
pub fn usualK(st: *const Stats, r: Role) f64 {
    var q: f64 = 0;
    var noise: f64 = 0;
    var scale: f64 = 0;
    for (0..st.n) |c| {
        const cc = st.champRole(r, c);
        if (cc.games == 0) continue;
        for (0..st.n) |o| {
            const e = st.enemy(r, r, c, o);
            if (o == c or e.games == 0) continue;
            const oc = st.champRole(r, o);
            const u = usual(ratio(cc.wins, cc.games), ratio(oc.wins, oc.games));
            const g: f64 = @floatFromInt(e.games);
            const d = @as(f64, @floatFromInt(e.wins)) - g * u;
            q += d * d / g;
            noise += u * (1 - u);
            scale += g;
        }
    }
    const tau2 = std.math.clamp((q - noise) / @max(scale, 1), 0.0001, 0.01);
    return 0.25 / tau2;
}

/// Every lane opponent as a tile in one grid, all on screen: the opponent linking to
/// the matchup page from ch's side, ch's win rate there (tierlist.trackCell), against
/// usual (usualCell), the lane curve's gold difference at lane_minute and games. Still
/// a table, so static/table.js sorts it by the header row (shown as sort buttons).
/// Hardest first by the shrunk rate, so a few lucky games don't top the list; under
/// min_opponent_games faded and last, by games; under min_opponent_share of cr hidden
/// until asked for (static/filters.js redraws it the same way)
fn opponentTable(site: *const Site, w: *Writer, ch: Champ, r: Role, cr: core.statsfile.Counts, k: f64, ka: f64, opps: []Opponent) !void {
    if (opps.len == 0) return;
    const base = ratio(cr.wins, cr.games);
    const Order = struct {
        base: f64,
        k: f64,
        fn f(o: @This(), x: Opponent, y: Opponent) bool {
            const x_thin = x.games < min_opponent_games;
            const y_thin = y.games < min_opponent_games;
            if (x_thin != y_thin) return y_thin;
            if (x_thin) return x.games > y.games;
            return shrunk(x, o.base, o.k) < shrunk(y, o.base, o.k);
        }
    };
    std.mem.sort(Opponent, opps, Order{ .base = base, .k = k }, Order.f);
    const floor = @max(1, min_opponent_share * @as(f64, @floatFromInt(cr.games)));
    var shown: usize = 0;
    for (opps) |o| {
        if (@as(f64, @floatFromInt(o.games)) >= floor) shown += 1;
    }
    try tpl.renderPart(w,
        \\<div class="tl-bar"><h3 class="opp-h">Lane opponents <span class="muted">{n}, hardest first</span></h3>
        \\<nav class="switch" aria-label="Opponents" hidden><a aria-current="page" data-min="p1" title="Opponents in 1%+ of {name}'s games in the role">Common</a><a href="?min=0" data-min="0">All</a></nav>
        \\<input type="search" placeholder="Search opponent" data-filter="opp-{slug}" aria-label="Search opponent"></div>
        \\<div class="og-wrap"><table class="og" id="opp-{slug}" data-sortable data-k="{k:.0}" data-ka="{ka:.0}">
        \\<thead><tr><th class="l" data-sort="text">Name</th><th data-sort="num" title="{name}'s win rate in the matchup; sorts with few games pulled toward {name}'s own">Win rate</th><th data-sort="num" title="Points more or less than {name} usually wins against an opponent this strong">Vs usual</th><th data-sort="num" title="Lane curve estimate: {name} minus the opponent">Gold at {minute}</th><th data-sort="num">Games</th></tr></thead>
        \\<tbody>
        \\
    , .{ .n = shown, .name = ch.name, .minute = core.curvesfile.lane_minute, .slug = roleSlug(r), .k = k, .ka = ka });
    var few: usize = 0;
    for (opps) |o| {
        const thin = o.games < min_opponent_games;
        const rare = @as(f64, @floatFromInt(o.games)) < floor;
        if (thin and !rare) few += 1;
        try tpl.render(w,
            \\<tr class="bx{thin}" data-id="{id}" data-name="{name}" data-q="{q:.4}"{rare}><td class="l">{link}</td>{wr}{vs}{gold}<td class="dim" data-v="{games}">{games} <small>games</small></td></tr>
            \\
        , .{
            .id = o.other.id,
            .name = o.other.name,
            .q = o.strength,
            .thin = tpl.when(thin, " thin"),
            .rare = tpl.flag(rare, "data-rare hidden"),
            .link = tpl.call(opponentLink, .{ site, ch, o.other, r }),
            .wr = tpl.call(tierlist.trackCell, .{ ratio(o.wins, o.games), shrunk(o, base, k), o.games, tierlist.matchup_span, try site.arena.print("{d} games", .{o.games}), @as(?[]const u8, null) }),
            .vs = tpl.call(usualCell, .{ site, ch, r, o, base, ka }),
            .gold = tpl.call(goldCell, .{ site, ch, o.other, r }),
            .games = o.games,
        });
    }
    try tpl.renderPart(w, "</tbody></table></div>\n", .{});
    try tierlist.legend(w, tierlist.matchup_span);
    try tpl.renderPart(w,
        \\<p class="tl-more"{none}>{faded}{rare}</p>
        \\
    , .{
        .none = tpl.flag(few == 0 and shown == opps.len, "hidden"),
        .faded = tpl.when(few > 0, tpl.t("Faded: the last {few} opponents, under {min} games each, too few to read much into. ", .{
            .few = few,
            .min = min_opponent_games,
        })),
        .rare = tpl.when(shown < opps.len, tpl.t("{n} rarer opponents (under 1% of {name}'s games) hidden. <button class=\"link\" data-show-rare=\"opp-{slug}\" data-show-all>Show them</button>", .{
            .n = opps.len - shown,
            .name = ch.name,
            .slug = roleSlug(r),
        })),
    });
}

/// "+2.1 vs usual" (VsUsual in points), coloured as win rates on the champions table
/// are, as if usual were 50%; the numbers behind it on hover. As static/filters.js
/// usualCell
fn usualCell(w: *Writer, site: *const Site, ch: Champ, r: Role, o: Opponent, base: f64, k: f64) !void {
    const e = usual(base, o.strength);
    const d = VsUsual.of(o.wins, o.games, e, k);
    const z = 1.2816;
    const title = try site.arena.print("Against an opponent winning {d:.1}% in {s}, {s} usually wins about {d:.1}%; against {s} {d:.1}% in {d} games. Vs usual {f} points, pulled toward 0 the fewer the games; 8 in 10 between {f} and {f}", .{
        100 * o.strength,                 roleName(r),                      ch.name, 100 * e,
        o.other.name,                     100 * ratio(o.wins, o.games),     o.games, Points{ .v = d.mean },
        Points{ .v = d.mean - z * d.sd }, Points{ .v = d.mean + z * d.sd },
    });
    try tpl.render(w, "<td data-v=\"{v:.4}\"><span class=\"vs\" style=\"--c:{colour}\" title=\"{title}\"><b>{pts}</b> vs usual</span></td>", .{
        .v = d.mean,
        .colour = tierlist.wrColour(0.5 + d.mean, tierlist.table_span),
        .title = title,
        .pts = Points{ .v = d.mean },
    });
}

/// A share as signed points to one decimal: 0.021 -> "+2.1", -0.0004 -> "0.0"
pub const Points = struct {
    v: f64,

    pub fn format(p: Points, w: *Writer) Writer.Error!void {
        const x = 100 * p.v;
        if (@abs(x) < 0.05) return w.writeAll("0.0");
        if (x > 0) try w.writeByte('+');
        try w.print("{d:.1}", .{x});
    }
};

test "usual and vs usual" {
    try std.testing.expectApproxEqAbs(0.5, usual(0.5, 0.5), 1e-9);
    try std.testing.expectApproxEqAbs(0.5598, usual(0.53, 0.47), 1e-4);
    try std.testing.expectApproxEqAbs(0.53, usual(0.53, 0.5), 1e-9);
    // No games: nothing to say; many: close to the raw difference
    try std.testing.expectEqual(0, VsUsual.of(0, 0, 0.5, 400).mean);
    const d = VsUsual.of(5500, 10000, 0.5, 400);
    try std.testing.expectApproxEqAbs(0.0481, d.mean, 1e-4);
    var buf: [16]u8 = undefined;
    try std.testing.expectEqualStrings("+2.1", try std.fmt.bufPrint(&buf, "{f}", .{Points{ .v = 0.021 }}));
    try std.testing.expectEqualStrings("-2.1", try std.fmt.bufPrint(&buf, "{f}", .{Points{ .v = -0.021 }}));
    try std.testing.expectEqualStrings("0.0", try std.fmt.bufPrint(&buf, "{f}", .{Points{ .v = -0.0004 }}));
}

/// To the matchup page from ch's side, or the opponent's own page where there is none
fn opponentLink(w: *Writer, site: *const Site, ch: Champ, other: Champ, r: Role) !void {
    const has = if (site.curves) |*c| c.get(r, .all, ch.id, other.id) != null else false;
    if (!has) return site.champBox(w, other, "../");
    try tpl.render(w, "<a class=\"champ box\" href=\"../{path}\" title=\"{ch} vs {name}\"><img src=\"{icon}\" alt=\"\" loading=\"lazy\" width=\"32\" height=\"32\">{name}</a>", .{
        .path = try matchup.path(site.arena, r, ch, other),
        .ch = ch.name,
        .icon = site.icon(other),
        .name = other.name,
    });
}

fn goldCell(w: *Writer, site: *const Site, ch: Champ, other: Champ, r: Role) !void {
    const none = "<td class=\"dim\" data-v=\"\"></td>";
    const curves = if (site.curves) |*c| c else return tpl.render(w, none, .{});
    const v = curves.get(r, .all, ch.id, other.id) orelse return tpl.render(w, none, .{});
    const i = core.curvesfile.lane_minute - 1;
    const e = v.estimate(.gold, i);
    const g = matchup.range(v, curves.baseline(r, .all), .gold, i);
    try tpl.render(w, "<td data-v=\"{mean}\"><a class=\"gold {side}\" style=\"opacity:{fade:.2}\" href=\"../{path}\" title=\"Lane curves, {games} games; 8 games in 10 from {p10s}{p10} to {p90s}{p90}\">{sign}{mean}</a> <small>gold</small></td>", .{
        .mean = e.mean,
        .side = if (e.mean > 0) "up" else if (e.mean < 0) "down" else "even",
        .fade = core.curvesfile.fade(v.games()),
        .games = v.games(),
        .path = try matchup.path(site.arena, r, ch, other),
        .sign = if (e.mean > 0) "+" else "",
        .p10s = if (g[0] > 0) "+" else "",
        .p10 = g[0],
        .p90s = if (g[1] > 0) "+" else "",
        .p90 = g[1],
    });
}

const RoleGames = struct {
    st: *const Stats,
    c: usize,
    fn more(ctx: RoleGames, a: Role, b: Role) bool {
        return ctx.st.champRole(a, ctx.c).games > ctx.st.champRole(b, ctx.c).games;
    }
};
