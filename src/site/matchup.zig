//! Lane matchup pages: how a lane unfolds minute by minute (core/curvesfile.zig). Every
//! chart carries tier, patch, n and spread; under thin_games it is greyed out as "more
//! data needed" (docs/concept.md). Facts and numbers only, no advice.

const std = @import("std");
const core = @import("core");
const root = @import("root.zig");
const html = @import("html.zig");
const comeback = @import("comeback.zig");
const lanechart = @import("lanechart.zig");
const text = @import("text.zig");
const champion = @import("champion.zig");
const tierlist = @import("tierlist.zig");
const builds = @import("builds.zig");

const Writer = std.Io.Writer;
const Role = core.Role;
const curvesfile = core.curvesfile;
const Curves = curvesfile.Curves;
const View = curvesfile.View;
const Bracket = curvesfile.Bracket;
const Site = root.Site;
const Champ = root.Champ;
const tpl = html.tpl;
const plural = text.plural;
const percent = text.percent;

/// Below this many games a curve is greyed out as "more data needed"
pub const thin_games = 200;
/// Minutes with fewer games still going are not drawn
const min_minute_games = 10;
/// Experienced-only curves with fewer games are not offered
const min_experienced = 10;
/// Minimum games choices on the matchup index, from indexFloor up
const index_floors = [_]u32{ 1, 5, 10, 20, 50, 100, thin_games, 500, 1000 };
/// 27k matchups at 1 (24 MB of rows); 50 keeps ~4k
const index_default = 50;

/// A thinner matchup (greyed out anyway) draws minutes while all its games are going
fn minuteFloor(v: View) u32 {
    return @max(1, @min(min_minute_games, v.games()));
}

/// The curves' games for running text: "last 30 days" or "patch 16.19"
fn period(a: std.mem.Allocator, curves: *const Curves) ![]const u8 {
    const label = curves.patch();
    if (label.len > 0 and std.ascii.isDigit(label[0])) return a.print("patch {s}", .{label});
    return label;
}

/// From x's side: x's gold, wins and timings first
pub fn path(a: std.mem.Allocator, r: Role, x: Champ, y: Champ) ![]const u8 {
    return a.print("matchup/{s}/{s}", .{ root.roleSlug(r), try file(a, x, y) });
}

/// path within its role's directory
fn file(a: std.mem.Allocator, x: Champ, y: Champ) ![]const u8 {
    return a.print("{s}-vs-{s}.html", .{ x.slug, y.slug });
}

/// A matchup's page curve: all ranks, all games. The file has one per bracket and
/// experience (and role baselines, champion 0) for each pair
pub fn isPage(h: *const curvesfile.Header) bool {
    return h.bracket == @backingInt(Bracket.all) and h.experience == @backingInt(curvesfile.Experience.any);
}

/// Two pages per lane matchup with an all-ranks curve of `min_games` or more, one from
/// each champion's side
pub fn paths(site: *const Site, curves: *const Curves, list: *std.ArrayList([]const u8), min_games: u32) !void {
    for (curves.curves) |c| {
        const h = c.header;
        if (!isPage(h) or h.games < min_games) continue;
        const x = champ(site, h.a) orelse continue;
        const y = champ(site, h.b) orelse continue;
        const r: Role = @fromBackingInt(@intCast(h.role));
        try list.append(site.arena, try path(site.arena, r, x, y));
        try list.append(site.arena, try path(site.arena, r, y, x));
    }
}

/// `rest`: "<role>/<a>-vs-<b>" from matchup/<rest>.html; false for no such page
pub fn route(site: *const Site, w: *Writer, curves: *const Curves, rest: []const u8) !bool {
    const slash = std.mem.indexOfScalar(u8, rest, '/') orelse return false;
    const r = root.roleFromSlug(rest[0..slash]) orelse return false;
    var it = std.mem.splitSequence(u8, rest[slash + 1 ..], "-vs-");
    const x = site.champBySlug(it.next().?) orelse return false;
    const y = site.champBySlug(it.next() orelse return false) orelse return false;
    if (it.next() != null or x.id == y.id) return false;
    if (curves.get(r, .all, x.id, y.id) == null) return false;
    try writePage(site, w, curves, r, x, y);
    return true;
}

/// matchup/index.html: one sortable table per role (tabs pick one), most games first.
/// Each pair once, from the side that won more of its games, so win rate and vs usual
/// read as how one-sided it was. Only the most played (indexFloor) are listed: the
/// rest are on each champion's page
pub fn writeIndex(site: *const Site, w: *Writer, curves: ?*const Curves) !void {
    const a = site.arena;
    const p = site.page(
        if (curves) |c| try a.print("Lane matchups, {s} | meiolol", .{try period(a, c)}) else "Lane matchups | meiolol",
        "Every lane matchup by role: win rate, against usual, gold at 14 minutes and games, each linking to how it unfolds minute by minute.",
        "matchup/index.html",
        .matchups,
    );
    try html.head(w, p);
    try tpl.render(w,
        \\<h1>Lane matchups</h1>
        \\
    , .{});
    const c = curves orelse {
        try tpl.render(w,
            \\<p class="note">Curves need match timelines, which are being collected now. Every matchup gets a page; under 200 games it is shown greyed out as "more data needed".</p>
            \\
        , .{});
        return html.foot(w, p);
    };
    var lists: [Role.count]std.ArrayList(IndexEntry) = @splat(.empty);
    for (Role.all, &lists) |r, *list| {
        const ka = champion.usualK(&site.stats, r);
        for (c.curves) |cv| {
            const h = cv.header;
            if (h.role != @backingInt(r) or !isPage(h)) continue;
            const x = champ(site, h.a) orelse continue;
            const y = champ(site, h.b) orelse continue;
            try list.append(a, indexEntry(site, c, r, x, y, h.games, ka));
        }
        std.mem.sort(IndexEntry, list.items, {}, struct {
            fn f(_: void, p_: IndexEntry, q: IndexEntry) bool {
                return p_.games > q.games;
            }
        }.f);
    }
    const floor = indexFloor(&lists);
    const default = @max(floor, index_default);
    for (&lists) |*list| {
        var keep: usize = 0;
        while (keep < list.items.len and list.items[keep].games >= floor) keep += 1;
        list.shrinkRetainingCapacity(keep);
    }
    try tpl.render(w,
        \\<p class="muted">Each pair once, from the side that won more, {region}, {when}; under {floor} games, see champion pages.</p>
        \\<div class="tl-bar mu-bar"><nav class="tabs mu-roles" aria-label="Role"><a href="#all">All roles</a>{tabs}</nav><span class="mu-search" hidden><input type="search" placeholder="Search champion" data-min-search aria-label="Search champion"></span></div>
        \\
    , .{
        .region = site.view.region.in(),
        .when = try period(a, c),
        .floor = floor,
        .tabs = tpl.each(&Role.all, {}, roleTab),
    });
    var choices: std.ArrayList(u32) = .empty;
    for (index_floors) |f| if (f >= floor) try choices.append(a, f);
    try html.minGames(w, "../", "matchups", choices.items, default, 0);
    try w.writeAll("<div class=\"mu-ix\" data-role=\"top\">\n");
    for (Role.all, lists) |r, list| {
        const slug = root.roleSlug(r);
        var shown: usize = 0;
        for (list.items) |e| shown += @intFromBool(e.games >= default);
        // One block per role, so a search can drop and reorder them (min-games.js)
        try tpl.renderPart(w,
            \\<section data-min-group data-r="{slug}" id="{slug}"><h2>{role} <span class="muted"><span id="n-{slug}">{n}</span> matchups</span></h2>
            \\
        , .{ .role = root.roleName(r), .slug = slug, .n = shown });
        if (list.items.len == 0) {
            try tpl.renderPart(w, "<p class=\"muted\">More data needed.</p></section>\n", .{});
            continue;
        }
        try tpl.renderPart(w,
            \\<div data-min-list data-count="n-{slug}"><div class="tl-wrap"><table class="tl mu-table" id="mu-{slug}" data-sortable>
            \\<thead><tr><th class="l" data-sort="text">Champion</th><th class="l" data-sort="text">Opponent</th><th data-sort="num" title="The first champion's win rate in the matchup; sorts with few games pulled toward what it usually wins">Win rate</th><th data-sort="num" title="Points more or less than the first champion usually wins against an opponent this strong">Vs usual</th><th data-sort="num" class="opt" title="Lane curve estimate: the first champion minus the opponent">Gold at {minute}</th><th data-sort="num" aria-sort="descending">Games</th></tr></thead>
            \\<tbody>
            \\{rows}</tbody></table></div>
            \\<p class="empty muted"{hidden}>None with this many games yet: lower Min games.</p></div></section>
            \\
        , .{
            .slug = slug,
            .minute = core.curvesfile.lane_minute,
            .rows = tpl.each(list.items, .{ site, r, default }, indexRow),
            .hidden = tpl.flag(shown > 0, "hidden"),
        });
    }
    try w.writeAll("</div>\n");
    try tierlist.legend(w, tierlist.matchup_span);
    try tpl.renderPart(w,
        \\<p class="muted small">Win rate and vs usual: the first champion's games in the role against the second, {when}; vs usual as on champion pages, pulled toward 0 the fewer the games. Sorting by win rate uses usual plus vs usual, so a few lucky games can't top the table. Gold at {minute} min: the lane curve's estimate, first minus second. Fainter under {full} games. <a href="../method.html">Method</a>.</p>
        \\
    , .{ .when = try period(a, c), .minute = core.curvesfile.lane_minute, .full = core.curvesfile.full_games });
    // Role tabs: one role's table at a time, every role while searching (style.css .mu-ix)
    try w.writeAll(
        \\<script>(()=>{const ix=document.querySelector(".mu-ix"),tabs=[...document.querySelectorAll(".mu-roles a")],q=document.querySelector("input[data-min-search]");
        \\const set=(r)=>{if(!tabs.some((t)=>t.hash==="#"+r))r="top";ix.dataset.role=r;for(const t of tabs)t.hash==="#"+r?t.setAttribute("aria-current","page"):t.removeAttribute("aria-current")};
        \\let r=location.hash.slice(1);if(!r)try{r=localStorage.getItem("mu-role")}catch(e){}set(r);
        \\for(const t of tabs)t.addEventListener("click",(e)=>{e.preventDefault();const r=t.hash.slice(1);set(r);history.replaceState(null,"",t.hash);try{localStorage.setItem("mu-role",r)}catch(e){}});
        \\const sync=()=>ix.classList.toggle("q",!!q&&q.value.trim()!=="");if(q){q.addEventListener("input",sync);addEventListener("pageshow",sync)}})()</script>
        \\<script src="../table.js" defer></script>
        \\
    );
    try html.foot(w, p);
}

/// Most index rows a page carries; past it the lowest floors go (index_floors)
const index_max_rows = 5000;

/// The lowest index_floors choice whose rows fit in index_max_rows
fn indexFloor(lists: []const std.ArrayList(IndexEntry)) u32 {
    for (index_floors) |f| {
        var n: usize = 0;
        for (lists) |l| {
            for (l.items) |e| n += @intFromBool(e.games >= f);
        }
        if (n <= index_max_rows) return f;
    }
    return index_floors[index_floors.len - 1];
}

fn roleTab(_: void, w: *Writer, r: Role) !void {
    try tpl.render(w, "<a href=\"#{slug}\">{name}</a>", .{ .slug = root.roleSlug(r), .name = root.roleName(r) });
}

const IndexEntry = struct {
    x: Champ,
    y: Champ,
    games: u32,
    thin: bool,
    /// x's games against y in the role (the stats, not the curves)
    wins: u32,
    played: u32,
    vs: champion.VsUsual,
    /// x's usual win rate against an opponent this strong (champion.usual)
    usual: f64,
    /// Lane curve's gold at lane_minute, x minus y
    gold: i32,
};

/// x and y swapped when y won more
fn indexEntry(site: *const Site, c: *const Curves, r: Role, x0: Champ, y0: Champ, games: u32, ka: f64) IndexEntry {
    const st = &site.stats;
    var x = x0;
    var y = y0;
    var e = st.enemy(r, r, x.c, y.c);
    if (2 * e.wins < e.games) {
        std.mem.swap(Champ, &x, &y);
        e = st.enemy(r, r, x.c, y.c);
    }
    const xr = st.champRole(r, x.c);
    const yr = st.champRole(r, y.c);
    const u = champion.usual(root.ratio(xr.wins, xr.games), root.ratio(yr.wins, yr.games));
    const v = c.get(r, .all, x.id, y.id).?;
    return .{
        .x = x,
        .y = y,
        .games = games,
        .thin = thin(v),
        .wins = e.wins,
        .played = e.games,
        .vs = champion.VsUsual.of(e.wins, e.games, u, ka),
        .usual = u,
        .gold = v.estimate(.gold, core.curvesfile.lane_minute - 1).mean,
    };
}

fn indexRow(ctx: struct { *const Site, Role, u32 }, w: *Writer, e: IndexEntry) !void {
    const site, const r, const default = ctx;
    const a = site.arena;
    const p = root.ratio(e.wins, e.played);
    try tpl.render(w,
        \\<tr class="bx{thin}" data-games="{games}" data-name="{x}|{y}"{hidden}><td class="l"><a class="champ box" href="{x_href}"><img src="{x_icon}" alt="" loading="lazy" width="24" height="24">{x}</a></td><td class="l"><a class="champ" href="{y_href}"><img src="{y_icon}" alt="" loading="lazy" width="24" height="24">{y}</a></td>{wr}<td data-v="{vs:.4}"><span class="vs" style="--c:{colour}"><b>{pts}</b></span></td><td class="opt" data-v="{gold}"><span class="gold {side}" style="opacity:{fade:.2}">{sign}{gold}</span></td><td class="dim" data-v="{games}">{games}</td></tr>
        \\
    , .{
        .games = e.games,
        .x = e.x.name,
        .y = e.y.name,
        .thin = tpl.when(e.thin, " thin"),
        .hidden = tpl.flag(e.games < default, "hidden"),
        .x_href = (try path(a, r, e.x, e.y))["matchup/".len..],
        .y_href = (try path(a, r, e.y, e.x))["matchup/".len..],
        .x_icon = site.icon(e.x),
        .y_icon = site.icon(e.y),
        // Sorts by usual + vs usual: the rate pulled toward usual by its games
        .wr = tpl.call(tierlist.trackCell, .{ p, e.usual + e.vs.mean, e.played, tierlist.matchup_span, try a.print("{d} games in the stats", .{e.played}), @as(?[]const u8, null) }),
        .vs = e.vs.mean,
        .colour = tierlist.wrColour(0.5 + e.vs.mean, tierlist.table_span),
        .pts = champion.Points{ .v = e.vs.mean },
        .side = if (e.gold > 0) "up" else if (e.gold < 0) "down" else "even",
        .fade = core.curvesfile.fade(e.games),
        .sign = if (e.gold > 0) "+" else "",
        .gold = e.gold,
    });
}

pub fn champ(site: *const Site, id: u32) ?Champ {
    const c = site.stats.index(id) orelse return null;
    return site.champs[site.by_c[c] orelse return null];
}

/// Under thin_games games, or when most of the estimate is the champions' baseline
/// rather than the matchup's own games (View.own), a curve is greyed out
pub fn thin(v: View) bool {
    return v.games() < thin_games or v.own() < 0.5;
}

/// One way of counting a matchup's games on its page: all games, or only those where
/// one side is experienced on their champion; from x's side either way
const Variant = struct {
    v: View,
    /// CSS class suffix and radio value
    key: []const u8,
    label: []const u8,
};

fn variants(a: std.mem.Allocator, curves: *const Curves, r: Role, x: Champ, y: Champ) ![]const Variant {
    var list: std.ArrayList(Variant) = .empty;
    try list.append(a, .{ .v = curves.get(r, .all, x.id, y.id).?, .key = "any", .label = "All games" });
    const who = [_]struct { Champ, Champ, []const u8 }{ .{ x, y, "x" }, .{ y, x, "y" } };
    for (who) |s| {
        const v = curves.getExperienced(r, .all, s[0].id, s[1].id) orelse continue;
        if (v.games() < min_experienced) continue;
        try list.append(a, .{
            .v = if (s[0].id == x.id) v else .{ .curve = v.curve, .flipped = !v.flipped },
            .key = s[2],
            .label = try a.print("{s} players with {d}k+ mastery", .{ s[0].name, curvesfile.experienced_points / 1000 }),
        });
    }
    return list.items;
}

fn writePage(site: *const Site, w: *Writer, curves: *const Curves, r: Role, x: Champ, y: Champ) !void {
    const a = site.arena;
    const v = curves.get(r, .all, x.id, y.id).?;
    const lane = root.roleName(r);
    const when = try period(a, curves);
    const title = try a.print("{s} vs {s}, {s} lane curves, {s} | meiolol", .{
        x.name, y.name, lane, when,
    });
    const desc = try a.print("How {s} against {s} in {s} lane unfolds minute by minute: gold, experience and CS difference, kills, level 6 and first item timing.", .{
        x.name, y.name, lane,
    });
    const page_path = try path(a, r, x, y);
    var p = site.page(title, desc, page_path, .matchups);
    p.index = v.games() >= site.opts.index_min_games;
    for (html.View.all, site.view_curves, &p.counterparts.?) |view, *other, *there| {
        const has = if (other.*) |*o| o.get(r, .all, x.id, y.id) != null else false;
        if (!has) there.* = try std.mem.concat(a, u8, &.{ view.dir(), "matchup/index.html" });
    }
    try html.head(w, p);
    const swap = try file(a, y, x);
    try tpl.render(w,
        \\<div class="hero"><img src="{x_icon}" alt="" width="72" height="72"><a class="swap" href="{swap}" title="Swap sides: {y} vs {x}" aria-label="Swap sides: {y} vs {x}">⇄</a><img src="{y_icon}" alt="" width="72" height="72"><div><h1>{x} vs {y}</h1>
        \\<p class="muted">From {x}'s side: {lane} lane, ranked solo/duo {region}, {when}, {games} Platinum+ game{s}.</p></div></div>
        \\<nav class="mu-nav" aria-label="Other matchups"><a class="btn" href="{swap}">⇄ From {y}'s side</a>
        \\{opponents}{champions}</nav>
        \\
    , .{
        .x_icon = site.icon(x),
        .y_icon = site.icon(y),
        .swap = swap,
        .x = x.name,
        .y = y.name,
        .lane = lane,
        .region = site.view.region.in(),
        .when = when,
        .games = v.games(),
        .s = plural(v.games()),
        .opponents = tpl.call(picker, .{ site, curves, r, x, y, Pick.opponent }),
        .champions = tpl.call(picker, .{ site, curves, r, y, x, Pick.champion }),
    });
    if (v.games() < thin_games) {
        try tpl.render(w,
            \\<p class="note">More data needed: {games} game{s} so far. Until {thin}, the line leans on how these two champions do against everyone (see the method), and the chart is greyed out.</p>
            \\
        , .{ .games = v.games(), .s = plural(v.games()), .thin = thin_games });
    } else if (thin(v)) {
        try tpl.render(w,
            \\<p class="note">Mostly the champions' baseline: the line still leans more on how these two champions do against everyone than on their games against each other (see the method).</p>
            \\
        , .{});
    }
    const vs = try variants(a, curves, r, x, y);
    try headline(site, w, vs, r, x, y);
    try tiles(site, w, v, r, x, y, when);
    try builds.vsStrip(site, w, r, x, y, page_path);

    const base = curves.baseline(r, .all);
    const prev = prevLine(site, r, x, y);
    const Chart = struct { title: []const u8, metric: curvesfile.Metric, unit: []const u8 };
    const charts = [_]Chart{
        .{ .title = "Gold", .metric = .gold, .unit = "gold" },
        .{ .title = "Experience", .metric = .xp, .unit = "XP" },
        .{ .title = "CS", .metric = .cs, .unit = "CS" },
    };
    try tpl.renderPart(w, "<div class=\"mu-top\"><div class=\"mu-stats\">\n", .{});
    for (vs) |s| {
        if (vs.len > 1) try tpl.renderPart(w, "<div class=\"exp exp-{key}\">\n", .{ .key = s.key });
        try why(w, s.v, r, x, y);
        if (vs.len > 1) try tpl.renderPart(w, "</div>\n", .{});
    }
    try tpl.renderPart(w,
        \\</div><div class="mu-curves"><div class="mu-tabs" role="radiogroup" aria-label="Curve" data-keep="matchup-curve">
    , .{});
    for (charts, 0..) |c, i| try tpl.renderPart(w,
        \\<label><input type="radio" name="metric" id="m-{metric}"{checked}> {title}</label>
    , .{ .metric = @tagName(c.metric), .checked = tpl.flag(i == 0, "checked"), .title = c.title });
    try tpl.renderPart(w, "</div>\n", .{});
    for (charts) |c| {
        try tpl.renderPart(w, "<div class=\"mu-m mu-m-{metric}\">\n", .{ .metric = @tagName(c.metric) });
        try chart(w, vs, base, prev, c.metric, c.unit, x, y, when, lane);
        try tpl.renderPart(w, "</div>\n", .{});
    }
    try tpl.renderPart(w, "</div></div>\n", .{});

    // Everything for a look back after the game, folded: the first screen answers champ
    // select's questions
    try tpl.renderPart(w,
        \\<details class="mu-more"><summary><b>More detail</b> <span class="muted">minute by minute, both sides, comeback odds, by rank{mastery}</span></summary>
        \\
    , .{ .mastery = tpl.when(vs.len > 1, ", mastery") });
    if (vs.len > 1) {
        // Not kept between visits (no data-keep): folded, a kept choice would change the
        // page with no visible reason
        try tpl.renderPart(w, "<fieldset class=\"exp-toggle\"><legend>Games counted, for the whole page</legend>", .{});
        for (vs, 0..) |s, i| {
            try tpl.render(w, "<label><input type=\"radio\" name=\"exp\" value=\"{key}\" id=\"exp-{key}\"{checked}> {label} <span class=\"muted\">({games})</span></label> ", .{
                .key = s.key,
                .checked = tpl.flag(i == 0, "checked"),
                .label = s.label,
                .games = s.v.games(),
            });
        }
        try tpl.renderPart(w, "</fieldset>\n", .{});
    }
    try tpl.render(w, "<h2>Minute by minute</h2>\n", .{});
    for (vs) |s| {
        if (vs.len > 1) try tpl.renderPart(w, "<div class=\"exp exp-{key}\">\n", .{ .key = s.key });
        try leads(w, s.v, x, y);
        if (vs.len > 1) try tpl.renderPart(w, "</div>\n", .{});
    }
    try tpl.render(w, "<h2>Both sides</h2>\n", .{});
    for (vs) |s| {
        if (vs.len == 1) try sides(w, s.v, x, y) else try tpl.render(w,
            \\<div class="exp exp-{key}">
            \\{sides}</div>
            \\
        , .{ .key = s.key, .sides = tpl.call(sides, .{ s.v, x, y }) });
    }
    try comeback.section(w, curves, r, x, y);
    try tpl.render(w, "<h2>By rank</h2>\n", .{});
    try brackets(w, curves, r, x, y);
    try tpl.renderPart(w, "</details>\n", .{});
    const to_site = site.toShared(page_path);
    try tpl.render(w,
        \\<p class="muted"><a href="{x_href}">{x}</a> · <a href="{y_href}">{y}</a> · <a href="{up}method.html">Method</a></p>
        \\
    , .{
        .x_href = site.champHref(x, to_site),
        .x = x.name,
        .y_href = site.champHref(y, to_site),
        .y = y.name,
        .up = to_site,
    });
    try html.foot(w, p);
}

const Pick = enum { opponent, champion };

/// A closed list of `fixed`'s other lane matchups with a page, most games first, each
/// keeping fixed's side as on this page: "Change opponent" swaps y (fixed is x),
/// "Change champion" swaps x (fixed is y)
fn picker(w: *Writer, site: *const Site, curves: *const Curves, r: Role, fixed: Champ, current: Champ, pick: Pick) !void {
    const a = site.arena;
    var list: std.ArrayList(Other) = .empty;
    for (curves.curves) |c| {
        const h = c.header;
        if (h.role != @backingInt(r) or !isPage(h)) continue;
        const id = if (h.a == fixed.id) h.b else if (h.b == fixed.id) h.a else continue;
        try list.append(a, .{ .ch = champ(site, id) orelse continue, .games = h.games });
    }
    if (list.items.len < 2) return;
    std.mem.sort(Other, list.items, {}, struct {
        fn f(_: void, p_: Other, q: Other) bool {
            return p_.games > q.games;
        }
    }.f);
    try tpl.render(w,
        \\<details class="pick"><summary>{label} <span class="muted">{n}</span></summary><ul class="pick-list">
        \\{items}</ul></details>
        \\
    , .{
        .label = switch (pick) {
            .opponent => "Change opponent",
            .champion => "Change champion",
        },
        .n = list.items.len,
        .items = tpl.each(list.items, PickCtx{ .site = site, .fixed = fixed, .current = current, .pick = pick }, pickItem),
    });
}

const Other = struct { ch: Champ, games: u32 };
const PickCtx = struct { site: *const Site, fixed: Champ, current: Champ, pick: Pick };

fn pickItem(ctx: PickCtx, w: *Writer, o: Other) !void {
    const x, const y = switch (ctx.pick) {
        .opponent => .{ ctx.fixed, o.ch },
        .champion => .{ o.ch, ctx.fixed },
    };
    try tpl.render(w,
        \\<li class="bx{current}"{aria}><a class="box" href="{href}"><img src="{icon}" alt="" loading="lazy" width="32" height="32">{name}</a> <span class="muted">{games}</span></li>
        \\
    , .{
        .current = tpl.when(o.ch.id == ctx.current.id, " current"),
        .aria = tpl.flag(o.ch.id == ctx.current.id, "aria-current=\"page\""),
        .href = try file(ctx.site.arena, x, y),
        .icon = ctx.site.icon(o.ch),
        .name = o.ch.name,
        .games = o.games,
    });
}

/// The landing page's lead: one matchup's gold curve, the clearest lane among those
/// out of "more data needed" (the most games while none is)
pub fn featured(site: *const Site, w: *Writer, curves: *const Curves, matchups: usize) !void {
    var best: ?struct { r: Role, x: Champ, y: Champ, v: View, score: f64 } = null;
    for (curves.curves) |c| {
        const h = c.header;
        if (!isPage(h)) continue;
        const x = champ(site, h.a) orelse continue;
        const y = champ(site, h.b) orelse continue;
        const r: Role = @fromBackingInt(@intCast(h.role));
        const v = curves.get(r, .all, x.id, y.id) orelse continue;
        const e = v.estimate(.gold, curvesfile.lane_minute - 1);
        const games: f64 = @floatFromInt(v.games());
        const score = if (thin(v)) games else 1e9 + @as(f64, @floatFromInt(@abs(e.mean)));
        if (best == null or score > best.?.score) best = .{ .r = r, .x = x, .y = y, .v = v, .score = score };
    }
    const b = best orelse return;
    // From x's side, the side ahead at 14 minutes, so the line reads upwards
    const flip = b.v.estimate(.gold, curvesfile.lane_minute - 1).mean < 0;
    const x = if (flip) b.y else b.x;
    const y = if (flip) b.x else b.y;
    const v = curves.get(b.r, .all, x.id, y.id).?;
    const lane = root.roleName(b.r);
    const when = try period(site.arena, curves);
    const page_path = try path(site.arena, b.r, x, y);
    try tpl.renderPart(w,
        \\<section class="featured"><h2>{x} vs {y}, {lane} lane: gold difference by minute</h2>
        \\
    , .{ .x = x.name, .y = y.name, .lane = lane });
    try summary(w, v, x, y);
    const one = [_]Variant{.{ .v = v, .key = "any", .label = "All games" }};
    try chart(w, &one, curves.baseline(b.r, .all), null, .gold, "gold", x, y, when, lane);
    try tpl.renderPart(w,
        \\<p><a href="{href}">Experience, CS, kills, item timings and ranks for this matchup</a> · <a href="{all}">All {n} matchups</a></p></section>
        \\
    , .{
        .href = page_path,
        .all = @as([]const u8, "matchup/index.html"),
        .n = matchups,
    });
}

fn summary(w: *Writer, v: View, x: Champ, y: Champ) !void {
    const lane = v.lane();
    const i = curvesfile.lane_minute - 1;
    const m = v.minute(i);
    const ahead = tpl.call(percent, .{ lane.ahead, lane.games });
    const gold = if (m.n >= minuteFloor(v)) blk: {
        const e = v.estimate(.gold, i);
        // The share in the thin case is raw and can disagree with a line that leans on the
        // baseline
        break :blk tpl.t("At {minute} minutes {x} is on average {amount} against {y}{thin}{own}", .{
            .minute = curvesfile.lane_minute,
            .x = x.name,
            .amount = tpl.call(amount, .{ e.mean, "gold" }),
            .y = y.name,
            .thin = tpl.when(thin(v), tpl.t(", mostly from how both champions do against everyone. In these {games} game{s} {x} led in gold at {minute} minutes in {ahead}. ", .{
                .games = v.games(),
                .s = plural(v.games()),
                .x = x.name,
                .minute = curvesfile.lane_minute,
                .ahead = ahead,
            })),
            .own = tpl.when(!thin(v), tpl.t(" (8 games in 10 between {p10} and {p90}), and leads in gold in {ahead} of games. ", .{
                .p10 = tpl.call(signed, .{m.gold.p10}),
                .p90 = tpl.call(signed, .{m.gold.p90}),
                .ahead = ahead,
            })),
        });
    } else null;
    try tpl.render(w,
        \\<p class="lead">{gold}{x} wins {wins} of these games{split}.</p>
        \\
    , .{
        .gold = gold,
        .x = x.name,
        .wins = tpl.call(percent, .{ v.wins(), v.games() }),
        .split = tpl.when(lane.ahead >= min_minute_games and lane.behind >= min_minute_games, tpl.t(": {ahead} when ahead at {minute} minutes, {behind} when behind", .{
            .ahead = tpl.call(percent, .{ lane.wins_ahead, lane.ahead }),
            .minute = curvesfile.lane_minute,
            .behind = tpl.call(percent, .{ lane.wins_behind, lane.behind }),
        })),
    });
}

/// x's win rate against y (the view's stats) and against usual (champion.VsUsual, as
/// the champion page's opponent grid)
const Odds = struct { wins: u32, games: u32, usual: f64, d: champion.VsUsual };

fn odds(site: *const Site, r: Role, x: Champ, y: Champ) Odds {
    const st = &site.stats;
    const e = st.enemy(r, r, x.c, y.c);
    const xr = st.champRole(r, x.c);
    const yr = st.champRole(r, y.c);
    const u = champion.usual(root.ratio(xr.wins, xr.games), root.ratio(yr.wins, yr.games));
    return .{ .wins = e.wins, .games = e.games, .usual = u, .d = champion.VsUsual.of(e.wins, e.games, u, champion.usualK(st, r)) };
}

/// Vs usual within this (a share) reads "about usual" in the headline
const about_usual = 0.01;

/// The page's answer in a line or two, descriptive (docs/production-key.md product
/// rules): x's win rate here against x's usual, then the lane (lead()) per variant
fn headline(site: *const Site, w: *Writer, vs: []const Variant, r: Role, x: Champ, y: Champ) !void {
    const o = odds(site, r, x, y);
    if (o.games == 0) return;
    try tpl.renderPart(w, "<p class=\"verdict mu-sum\">{x} wins {wr} against {y}, {side} {x}'s usual {usual:.1}%.", .{
        .x = x.name,
        .wr = tpl.call(pct1, .{ o.wins, o.games }),
        .y = y.name,
        .side = if (@abs(o.d.mean) < about_usual) "about" else if (o.d.mean > 0) "above" else "below",
        .usual = 100 * o.usual,
    });
    for (vs) |s| try lead(w, s, vs.len > 1, x);
    try tpl.renderPart(w, "</p>\n", .{});
}

/// The first screen's numbers: win rate and vs usual (odds()), the lane curve's gold at
/// lane_minute and how often x leads, then games
fn tiles(site: *const Site, w: *Writer, v: View, r: Role, x: Champ, y: Champ, when: []const u8) !void {
    const o = odds(site, r, x, y);
    const z = 1.2816;
    const i = curvesfile.lane_minute - 1;
    const has_gold = i < v.minutes() and v.minute(i).n >= minuteFloor(v);
    const g = v.estimate(.gold, i);
    const lane = v.lane();
    try tpl.render(w,
        \\<div class="tiles mu-tiles"><div title="{title}"><span>Win rate</span><b class="wrc" style="--c:{wr_colour};opacity:{fade:.2}">{wr}</b><small><b class="vs" style="--c:{colour}">{pts}</b> vs usual {usual:.1}%</small></div><div{thin}><span>Lane at {minute} min</span><b class="{side}">{gold}{dash}</b><small>ahead in {ahead}</small></div><div><span>Games</span><b>{games}</b><small>{when}</small></div></div>
        \\
    , .{
        .title = try site.arena.print("Against {s} {s} wins {d:.1}% in {d} games. Against an opponent this strong in {s}, {s} usually wins about {d:.1}%. Vs usual {f} points, pulled toward 0 the fewer the games; 8 in 10 between {f} and {f}", .{
            y.name,                                        x.name,                           100 * root.ratio(o.wins, o.games),
            o.games,                                       root.roleName(r),                 x.name,
            100 * o.usual,                                 champion.Points{ .v = o.d.mean }, champion.Points{ .v = o.d.mean - z * o.d.sd },
            champion.Points{ .v = o.d.mean + z * o.d.sd },
        }),
        .wr_colour = tierlist.wrColour(root.ratio(o.wins, o.games), tierlist.matchup_span),
        .fade = curvesfile.fade(o.games),
        .wr = tpl.call(pct1, .{ o.wins, o.games }),
        .colour = tierlist.wrColour(0.5 + o.d.mean, tierlist.table_span),
        .pts = champion.Points{ .v = o.d.mean },
        .usual = 100 * o.usual,
        .thin = tpl.flag(thin(v), "class=\"stale\""),
        .minute = curvesfile.lane_minute,
        .side = if (!has_gold) "even" else if (clearSide(g) > 0) "up" else if (clearSide(g) < 0) "down" else "even",
        .gold = tpl.when(has_gold, tpl.t("{mean} gold", .{ .mean = tpl.call(signed, .{g.mean}) })),
        .dash = tpl.when(!has_gold, "-"),
        .ahead = tpl.call(percent, .{ lane.ahead, lane.games }),
        .games = o.games,
        .when = when,
    });
}

/// "50.3%"; "-" without games
fn pct1(w: *Writer, part: u32, whole: u32) !void {
    if (whole == 0) return w.writeAll("-");
    try w.print("{d:.1}%", .{100 * root.ratio(part, whole)});
}

/// Minutes the leads table shows, while games are still going
const lead_minutes = [_]usize{ 5, 10, curvesfile.lane_minute, 20 };

/// Gold, XP and CS difference at lead_minutes: the curve's estimated average, from x's
/// side; faint within 2 standard errors of 0
fn leads(w: *Writer, v: View, x: Champ, y: Champ) !void {
    const last = reach(v);
    try tpl.renderPart(w,
        \\<table class="mu-leads{thin}"><thead><tr><th>{x} minus {y}</th>
    , .{ .thin = tpl.when(thin(v), " thin"), .x = x.name, .y = y.name });
    for (lead_minutes) |m| try tpl.renderPart(w, "<th class=\"num\">{m} min</th>", .{ .m = m });
    try tpl.renderPart(w, "</tr></thead><tbody>\n", .{});
    const rows = [_]struct { []const u8, curvesfile.Metric }{ .{ "Gold", .gold }, .{ "Experience", .xp }, .{ "CS", .cs } };
    for (rows) |row| {
        try tpl.renderPart(w, "<tr><td>{label}</td>", .{ .label = row[0] });
        for (lead_minutes) |m| {
            if (m > last) {
                try tpl.renderPart(w, "<td class=\"num\">-</td>", .{});
                continue;
            }
            const e = v.estimate(row[1], m - 1);
            const s = clearSide(e);
            try tpl.renderPart(w, "<td class=\"num {side}\">{v}</td>", .{
                .side = if (s > 0) "up" else if (s < 0) "down" else "even",
                .v = tpl.call(signed, .{e.mean}),
            });
        }
        try tpl.renderPart(w, "</tr>\n", .{});
    }
    try tpl.renderPart(w, "<tr class=\"n\"><td>Games still going</td>", .{});
    for (lead_minutes) |m| try tpl.renderPart(w, "<td class=\"num\">{n}</td>", .{ .n = if (m > last) 0 else v.minute(m - 1).n });
    try tpl.renderPart(w, "</tr>\n</tbody></table>\n", .{});
}

/// Lane minion gold per CS before 14 minutes: 3 melee (21), 3 casters (14) a wave and a
/// cannon (60 to 70) every third, 381 gold over 19 minions. Jungle camps and support
/// CS differ, so those roles get no split
const gold_per_cs = 20;

/// Short facts from the lane curve on where x's lead or deficit at lane_minute comes
/// from: CS against the rest, when half of it is there, early kills, level 6 and first
/// item timing, and how often the side ahead goes on to win. Counts, no advice
fn why(w: *Writer, v: View, r: Role, x: Champ, y: Champ) !void {
    const i = curvesfile.lane_minute - 1;
    if (i >= v.minutes() or v.minute(i).n < minuteFloor(v)) return;
    try tpl.renderPart(w,
        \\<h3 class="mu-h">How the lane goes</h3><ul class="mu-why{thin}">
        \\
    , .{ .thin = tpl.when(thin(v), " thin") });
    const gold = v.estimate(.gold, i).mean;
    const cs = v.estimate(.cs, i).mean;
    const split = r != .jungle and r != .utility;
    const cs_gold = round10(@as(i32, cs) * gold_per_cs);
    try tpl.renderPart(w, "<li><b>{gold} gold</b> at {minute} min{cs_only}{split}{half}</li>\n", .{
        .gold = tpl.call(signed, .{gold}),
        .minute = curvesfile.lane_minute,
        .cs_only = tpl.when(!split, tpl.t(" with {cs} CS", .{ .cs = tpl.call(signed, .{cs}) })),
        .split = tpl.when(split, tpl.t(": about {cs_gold} from CS ({cs} CS at about {per} gold), {rest} from kills, assists, plates and the rest", .{
            .cs_gold = tpl.call(signed, .{cs_gold}),
            .cs = tpl.call(signed, .{cs}),
            .per = gold_per_cs,
            .rest = tpl.call(signed, .{round10(@as(i32, gold) - cs_gold)}),
        })),
        .half = if (halfBy(v)) |m| tpl.t("; half of it is there by {m} min", .{ .m = m }) else null,
    });
    if (v.games() > 0) try tpl.renderPart(w,
        \\<li>Kills or assists on the lane opponent before 6 min: {x} in {k0} of games, {y} in {d0}; 6 to {minute} min: {k1} against {d1}</li>
        \\
    , .{
        .x = x.name,
        .y = y.name,
        .minute = curvesfile.lane_minute,
        .k0 = tpl.call(percent, .{ v.kills(0), v.games() }),
        .d0 = tpl.call(percent, .{ v.deaths(0), v.games() }),
        .k1 = tpl.call(percent, .{ v.kills(1), v.games() }),
        .d1 = tpl.call(percent, .{ v.deaths(1), v.games() }),
    });
    try timingFact(w, "Level 6", v.level6());
    try timingFact(w, "First finished item", v.firstItem());
    const lane = v.lane();
    if (lane.ahead >= min_minute_games and lane.behind >= min_minute_games) try tpl.renderPart(w,
        \\<li>Ahead in gold at {minute} min, {x} won {wa} of {ahead} games; behind, {wb} of {behind}</li>
        \\
    , .{
        .minute = curvesfile.lane_minute,
        .x = x.name,
        .wa = tpl.call(percent, .{ lane.wins_ahead, lane.ahead }),
        .ahead = lane.ahead,
        .wb = tpl.call(percent, .{ lane.wins_behind, lane.behind }),
        .behind = lane.behind,
    });
    try tpl.renderPart(w, "</ul>\n", .{});
}

fn round10(v: i32) i32 {
    return @divTrunc(v + if (v < 0) @as(i32, -5) else 5, 10) * 10;
}

/// The first minute x's estimated gold difference reaches half of its lane_minute one,
/// on the same side; null while that is about even (min_lead_gold)
fn halfBy(v: View) ?usize {
    const i = curvesfile.lane_minute - 1;
    const g: i32 = v.estimate(.gold, i).mean;
    if (@abs(g) < min_lead_gold) return null;
    for (0..i) |m| {
        const e: i32 = v.estimate(.gold, m).mean;
        if ((g > 0 and 2 * e >= g) or (g < 0 and 2 * e <= g)) return m + 1;
    }
    return curvesfile.lane_minute;
}

/// "Level 6 at 5:30 against 5:18 (medians), 12 s later"; none unless both sides got
/// there in most games
fn timingFact(w: *Writer, label: []const u8, both: [2]u16) !void {
    if (both[0] == 0 or both[1] == 0) return;
    const diff = @as(i32, both[0]) - @as(i32, both[1]);
    try tpl.renderPart(w, "<li>{label} at {a} against {b} (medians){gap}</li>\n", .{
        .label = label,
        .a = tpl.call(clock, .{both[0]}),
        .b = tpl.call(clock, .{both[1]}),
        .gap = tpl.when(diff != 0, tpl.t(", {d} {side}", .{
            .d = tpl.call(duration, .{@abs(diff)}),
            .side = if (diff < 0) "earlier" else "later",
        })),
    });
}

fn clock(w: *Writer, secs: u16) !void {
    try w.print("{d}:{d:0>2}", .{ secs / 60, secs % 60 });
}

/// "12 s", "2:21"
fn duration(w: *Writer, secs: u32) !void {
    if (secs < 60) return w.print("{d} s", .{secs});
    try w.print("{d}:{d:0>2}", .{ secs / 60, secs % 60 });
}

/// The headline's lane part: who is ahead by lane_minute, since when only where the
/// estimate is more than 2 SE from 0, then how often the side ahead wins; a span per
/// variant when toggled. Greyed-out (thin) curves get none: their note says why
fn lead(w: *Writer, one: Variant, toggle: bool, x: Champ) !void {
    const v = one.v;
    const i = curvesfile.lane_minute - 1;
    if (thin(v) or i >= v.minutes() or v.minute(i).n < minuteFloor(v)) return;
    const lane = v.lane();
    const split = lane.ahead >= min_minute_games and lane.behind >= min_minute_games;
    if (toggle) try tpl.renderPart(w, "<span class=\"exp exp-{key}\">", .{ .key = one.key });
    try tpl.render(w, " {gold}{wins}.", .{
        .gold = tpl.call(leadSince, .{ v, x }),
        .wins = tpl.when(split, tpl.t(", then whoever is ahead wins {share} of games", .{
            .share = tpl.call(percent, .{ lane.wins_ahead + lane.behind - lane.wins_behind, lane.ahead + lane.behind }),
        })),
    });
    if (toggle) try tpl.renderPart(w, "</span>", .{});
}

/// Minutes up to this read as "from the start": gold differences barely exist yet
const start_minute = 4;
/// A clear lead under this at lane_minute (after rounding to 100) gets no "since when":
/// just the number (J12)
const min_lead_gold = 200;

fn leadSince(w: *Writer, v: View, x: Champ) !void {
    const i = curvesfile.lane_minute - 1;
    const mean: i32 = v.estimate(.gold, i).mean;
    const side = clearSide(v.estimate(.gold, i));
    const gold = @divTrunc(@abs(mean) + 50, 100) * 100;
    if (side == 0 or gold < min_lead_gold) {
        const near = round10(mean);
        if (near == 0) return tpl.render(w, "{x} is level in gold at {minute} minutes", .{ .x = x.name, .minute = curvesfile.lane_minute });
        return tpl.render(w, "{x} is {gold} gold {side} at {minute} minutes", .{
            .x = x.name,
            .gold = @abs(near),
            .side = if (near > 0) "ahead" else "behind",
            .minute = curvesfile.lane_minute,
        });
    }
    var from: usize = i;
    while (from > 0 and clearSide(v.estimate(.gold, from - 1)) == side) from -= 1;
    const early = from + 1 <= start_minute;
    try tpl.render(w, "{x} is {side} from {start}{from}, about {gold} gold by {minute} minutes", .{
        .x = x.name,
        .side = if (side > 0) "ahead" else "behind",
        .start = tpl.when(early, "the start"),
        .from = tpl.when(!early, tpl.t("minute {m}", .{ .m = from + 1 })),
        .gold = gold,
        .minute = curvesfile.lane_minute,
    });
}

/// 1 or -1 when the estimate is more than 2 standard errors from 0, else 0
fn clearSide(e: curvesfile.Estimate) i2 {
    const mean: i32 = e.mean;
    if (@abs(mean) <= 2 * @as(u32, e.se)) return 0;
    return if (mean > 0) 1 else -1;
}

fn amount(w: *Writer, value: i16, unit: []const u8) !void {
    if (value == 0) return tpl.render(w, "even in {unit}", .{ .unit = unit });
    try tpl.render(w, "{gold} {unit} {side}", .{
        .gold = @abs(value),
        .unit = unit,
        .side = if (value > 0) "ahead" else "behind",
    });
}

fn signed(w: *Writer, value: i32) !void {
    try tpl.render(w, "{sign}{value}", .{ .sign = if (value > 0) "+" else "", .value = value });
}

/// Minutes drawn: while at least minuteFloor games are still going
fn reach(v: View) usize {
    var last: usize = 0;
    while (last < v.minutes() and v.minute(last).n >= minuteFloor(v)) last += 1;
    return last;
}

/// The band at minute i: the curve's own middle half of games once it has thin_games,
/// else the role's middle half (both sides, centred on 0) around the estimate
fn band(v: View, base: ?View, metric: curvesfile.Metric, i: usize) [2]i32 {
    const q = spreadAt(v, base, metric, i);
    return .{ q.p25, q.p75 };
}

/// Where 8 games in 10 end at minute i, from the same games as band
pub fn range(v: View, base: ?View, metric: curvesfile.Metric, i: usize) [2]i32 {
    const q = spreadAt(v, base, metric, i);
    return .{ q.p10, q.p90 };
}

const Spread32 = struct { p10: i32, p25: i32, p75: i32, p90: i32 };

fn spreadAt(v: View, base: ?View, metric: curvesfile.Metric, i: usize) Spread32 {
    const m = v.minute(i);
    const own = v.games() >= thin_games or base == null;
    const q = spreadOf(if (own) m else base.?.minute(i), metric);
    const e: i32 = if (own) 0 else m.est[@backingInt(metric)].mean;
    return .{ .p10 = e + q.p10, .p25 = e + q.p25, .p75 = e + q.p75, .p90 = e + q.p90 };
}

fn spreadOf(m: curvesfile.Minute, metric: curvesfile.Metric) curvesfile.Spread {
    return switch (metric) {
        .gold => m.gold,
        .xp => m.xp,
        .cs => m.cs,
    };
}

/// The previous patch's estimated average, dashed on a patch view's charts: from
/// Site.curves_prev, with the matchup's own games there (thin_games)
const Prev = struct { v: View, patch: []const u8 };

fn prevLine(site: *const Site, r: Role, x: Champ, y: Champ) ?Prev {
    const c = if (site.curves_prev) |*c| c else return null;
    const v = c.get(r, .all, x.id, y.id) orelse return null;
    if (v.games() < thin_games) return null;
    return .{ .v = v, .patch = c.patch() };
}

/// Estimated average line and middle-half band of `metric` by minute, an SVG per
/// variant, each on its own scale (the experienced toggle shows one); `prev` on the
/// all-games one
fn chart(
    w: *Writer,
    vs: []const Variant,
    base: ?View,
    prev: ?Prev,
    metric: curvesfile.Metric,
    unit: []const u8,
    x: Champ,
    y: Champ,
    when: []const u8,
    lane: []const u8,
) !void {
    for (vs, 0..) |s, i| try chartOne(w, s, vs.len > 1, base, if (i == 0) prev else null, metric, unit, x, y, when, lane);
}

fn chartOne(
    w: *Writer,
    one: Variant,
    toggle: bool,
    base: ?View,
    prev: ?Prev,
    metric: curvesfile.Metric,
    unit: []const u8,
    x: Champ,
    y: Champ,
    when: []const u8,
    lane: []const u8,
) !void {
    const last = reach(one.v);
    const figure = .{
        .thin = if (thin(one.v)) " thin" else "",
        .exp = tpl.when(toggle, " exp exp-"),
        .key = tpl.when(toggle, one.key),
    };
    if (last < 2) {
        return tpl.render(w,
            \\<figure class="chart{thin}{exp}{key}">
            \\<p class="muted">Not enough games yet.</p></figure>
            \\
        , figure);
    }
    var bands: [curvesfile.max_minutes][2]i32 = undefined;
    var line: [curvesfile.max_minutes]i32 = undefined;
    var prev_line: [curvesfile.max_minutes]i32 = undefined;
    for (0..last) |i| {
        bands[i] = band(one.v, base, metric, i);
        line[i] = one.v.estimate(metric, i).mean;
    }
    const prev_last = if (prev) |pv| @min(last, reach(pv.v)) else 0;
    for (0..prev_last) |i| prev_line[i] = prev.?.v.estimate(metric, i).mean;
    var aria_buf: [160]u8 = undefined;
    const aria = std.fmt.bufPrint(&aria_buf, "{s} of {s} minus {s} by minute", .{ unit, x.name, y.name }) catch unit;
    try tpl.renderPart(w, "<figure class=\"chart{thin}{exp}{key}\">\n", figure);
    try lanechart.render(w, .{
        .aria = aria,
        .a = x.name,
        .b = y.name,
        .band = bands[0..last],
        .line = line[0..last],
        .prev = prev_line[0..prev_last],
    });
    try caption(w, one.v, base, if (prev_last >= 2) prev else null, metric, x, y, when, lane);
    try tpl.renderPart(w, "</figure>\n", .{});
}

fn caption(w: *Writer, v: View, base: ?View, prev: ?Prev, metric: curvesfile.Metric, x: Champ, y: Champ, when: []const u8, lane: []const u8) !void {
    const last = reach(v);
    if (last < 2) return tpl.render(w, "<figcaption>Not enough games yet.</figcaption>\n", .{});
    const games = v.games();
    const own = games >= thin_games or base == null;
    try tpl.renderPart(w,
        \\<figcaption>{x} minus {y}: line = estimated average; band = {own}{baseline}; {when}, Platinum+ games, n = {games} game{s} ({going} still going at {last} min)
    , .{
        .x = x.name,
        .y = y.name,
        .own = tpl.when(own, "middle half of games"),
        .baseline = tpl.when(!own, tpl.t("middle half of all {lane} lanes, around the line (too few games for this matchup's own)", .{ .lane = lane })),
        .when = when,
        .games = games,
        .s = plural(games),
        .going = v.minute(last - 1).n,
        .last = last,
    });
    if (last >= curvesfile.lane_minute) {
        const e = v.estimate(metric, curvesfile.lane_minute - 1);
        const r = range(v, base, metric, curvesfile.lane_minute - 1);
        try tpl.renderPart(w, ". At {minute} min: average {mean}, 8 games in 10 between {p10} and {p90}", .{
            .minute = curvesfile.lane_minute,
            .mean = tpl.call(signed, .{e.mean}),
            .p10 = tpl.call(signed, .{r[0]}),
            .p90 = tpl.call(signed, .{r[1]}),
        });
    }
    try ended(w, if (own) v else base.?, last);
    if (prev) |pv| try tpl.renderPart(w, ". Dashed: patch {patch}, n = {games}", .{ .patch = pv.patch, .games = pv.v.games() });
    try tpl.renderPart(w, ".</figcaption>\n", .{});
}

/// Surrender opens at 15 minutes: before it nearly all games are still running
const surrender_minute = lanechart.surrender_minute;

/// "From 15 min only games still running count": the share ended by 20 and 25 min
fn ended(w: *Writer, v: View, last: usize) !void {
    if (last <= surrender_minute) return;
    const total = v.games();
    if (total == 0) return;
    try tpl.render(w, ". Right of the dotted line ({minute} min), only games still running count: ", .{ .minute = surrender_minute });
    for ([_]usize{ 20, 25 }, 0..) |m, k| {
        if (m > last) continue;
        try tpl.render(w, "{sep}{share} had ended by {minute} min", .{
            .sep = tpl.when(k > 0, ", "),
            .share = tpl.call(percent, .{ total -| v.minute(m - 1).n, total }),
            .minute = m,
        });
    }
}

fn sides(w: *Writer, v: View, x: Champ, y: Champ) !void {
    const lane = v.lane();
    try tpl.renderPart(w,
        \\<div class="table-scroll"><table>
        \\<thead><tr><th></th><th class="num">{x}</th><th class="num">{y}</th></tr></thead>
        \\<tbody>
        \\<tr><td>Ahead in gold at {minute} min</td><td class="num">{ahead}</td><td class="num">{behind}</td></tr>
        \\<tr><td>Wins the game</td><td class="num">{wins}</td><td class="num">{losses}</td></tr>
        \\<tr><td>Wins when ahead at {minute} min</td><td class="num">{wins_ahead}</td><td class="num">{wins_behind}</td></tr>
        \\
    , .{
        .x = x.name,
        .y = y.name,
        .minute = curvesfile.lane_minute,
        .ahead = tpl.call(percent, .{ lane.ahead, lane.games }),
        .behind = tpl.call(percent, .{ lane.behind, lane.games }),
        .wins = tpl.call(percent, .{ v.wins(), v.games() }),
        .losses = tpl.call(percent, .{ v.games() - v.wins(), v.games() }),
        .wins_ahead = tpl.call(percent, .{ lane.wins_ahead, lane.ahead }),
        .wins_behind = tpl.call(percent, .{ lane.behind - lane.wins_behind, lane.behind }),
    });
    const phase_names = [_][]const u8{ "before 6 min", "6 to 14 min", "after 14 min" };
    for (phase_names, 0..) |name, ph| {
        try tpl.render(w,
            \\<tr><td>Takes part in killing the other, {phase}</td><td class="num">{kills}</td><td class="num">{deaths}</td></tr>
            \\
        , .{
            .phase = name,
            .kills = tpl.call(percent, .{ v.kills(ph), v.games() }),
            .deaths = tpl.call(percent, .{ v.deaths(ph), v.games() }),
        });
    }
    try timing(w, "Level 6 (median)", v.level6());
    try timing(w, "First finished item (median)", v.firstItem());
    try tpl.renderPart(w,
        \\</tbody></table></div>
        \\<p class="muted">Share of {games} game{s}. A finished item costs 2,200 gold or more and builds into nothing; a dash means fewer than half of the games got there.</p>
        \\
    , .{ .games = v.games(), .s = plural(v.games()) });
}

fn timing(w: *Writer, label: []const u8, both: [2]u16) !void {
    try tpl.render(w, "<tr><td>{label}</td>{x}{y}</tr>\n", .{
        .label = label,
        .x = tpl.call(time, .{both[0]}),
        .y = tpl.call(time, .{both[1]}),
    });
}

fn time(w: *Writer, secs: u16) !void {
    if (secs == 0) return tpl.render(w, "<td class=\"num\">-</td>", .{});
    try tpl.render(w, "<td class=\"num\">{min}:{sec:0>2}</td>", .{ .min = secs / 60, .sec = secs % 60 });
}

fn brackets(w: *Writer, curves: *const Curves, r: Role, x: Champ, y: Champ) !void {
    try tpl.renderPart(w,
        \\<div class="table-scroll"><table>
        \\<thead><tr><th>Rank</th><th class="num">Games</th><th class="num">Gold at {minute} min</th><th class="num">{x} ahead at {minute} min</th><th class="num">{x} wins</th></tr></thead>
        \\<tbody>
        \\
    , .{ .minute = curvesfile.lane_minute, .x = x.name });
    for (std.enums.values(Bracket)) |b| {
        const v = curves.get(r, b, x.id, y.id) orelse {
            try tpl.render(w,
                \\<tr class="thin"><td>{rank}</td><td class="num" colspan="4">more data needed</td></tr>
                \\
            , .{ .rank = b.label() });
            continue;
        };
        const i = curvesfile.lane_minute - 1;
        const has_gold = v.minute(i).n >= minuteFloor(v);
        const gold = if (has_gold) blk: {
            const e = v.estimate(.gold, i);
            const g = range(v, curves.baseline(r, b), .gold, i);
            break :blk tpl.t("{mean} <small>{p10} to {p90}</small>", .{
                .mean = tpl.call(signed, .{e.mean}),
                .p10 = tpl.call(signed, .{g[0]}),
                .p90 = tpl.call(signed, .{g[1]}),
            });
        } else null;
        try tpl.render(w,
            \\<tr{thin}><td>{rank}</td><td class="num">{games}</td><td class="num">{gold}{dash}</td><td class="num">{ahead}</td><td class="num">{wins}</td></tr>
            \\
        , .{
            .thin = tpl.flag(thin(v), "class=\"thin\""),
            .rank = b.label(),
            .games = v.games(),
            .gold = gold,
            .dash = tpl.when(!has_gold, "-"),
            .ahead = tpl.call(percent, .{ v.lane().ahead, v.lane().games }),
            .wins = tpl.call(percent, .{ v.wins(), v.games() }),
        });
    }
    try tpl.renderPart(w,
        \\</tbody></table></div>
        \\<p class="muted">Rank is the median visible tier of the players in each game. Gold is the estimated average, then where 8 games in 10 end (the 10th to 90th percentile); a rank's estimate leans on the one for all games until it has games of its own. Rows under {thin} games, or mostly baseline, are greyed out.</p>
        \\
    , .{ .thin = thin_games });
}

test "nice scale" {
    try std.testing.expectEqual(1, lanechart.niceCeil(0));
    try std.testing.expectEqual(500, lanechart.niceCeil(420));
    try std.testing.expectEqual(600, lanechart.niceCeil(501));
    try std.testing.expectEqual(2000, lanechart.niceCeil(1001));
    try std.testing.expectEqual(3000, lanechart.niceCeil(2120));
}

test "one page per matchup, though experienced players' curves share its pair" {
    const gpa = std.testing.allocator;
    var b: curvesfile.Builder = .{ .gpa = gpa };
    defer b.deinit();
    for (0..40) |i| {
        try b.addLane(.{
            .role = .top,
            .bracket = .mid,
            .a = 10,
            .b = 60,
            .a_won = i % 2 == 0,
            .minutes = 20,
            .experienced_a = i % 3 != 0,
            .experienced_b = i % 3 != 1,
        });
        b.addGame();
    }
    var aw: Writer.Allocating = .init(gpa);
    defer aw.deinit();
    try b.write(&aw.writer, "16.20", 1);
    var c: Curves = try .parse(gpa, aw.written());
    defer c.deinit(gpa);
    var all_ranks: usize = 0;
    var pages: usize = 0;
    for (c.curves) |cv| {
        if (cv.header.a != 10 or cv.header.b != 60) continue;
        all_ranks += @intFromBool(cv.header.bracket == @backingInt(Bracket.all));
        pages += @intFromBool(isPage(cv.header));
    }
    try std.testing.expectEqual(3, all_ranks);
    try std.testing.expectEqual(1, pages);
}

test lead {
    const gpa = std.testing.allocator;
    var minutes: [curvesfile.lane_minute]curvesfile.Minute = @splat(.{ .n = 400, .gold = .{}, .xp = .{}, .cs = .{} });
    var header = std.mem.zeroes(curvesfile.Header);
    header.games = 400;
    header.own = 800;
    header.lane_games = 400;
    header.lane_a = 250;
    header.lane_b = 150;
    header.a_wins_lane_a = 160;
    header.b_wins_lane_b = 96;
    // Clear of 0 from minute 2, behind past 14: "from the start"
    for (&minutes, 0..) |*m, i| m.est[0] = .{ .mean = @intCast(60 * i), .se = 20 };
    minutes[curvesfile.lane_minute - 1].est[0].mean = 846;
    const x: Champ = .{ .c = 0, .id = 1, .key = "", .name = "Ahri", .slug = "", .banned = 0, .games = 0 };
    const cv: curvesfile.Curve = .{ .header = &header, .minutes = &minutes };
    const Case = struct { flipped: bool, want: []const u8 };
    const ahead = [_]Case{
        .{ .flipped = false, .want = " Ahri is ahead from the start, about 800 gold by 14 minutes, then whoever is ahead wins 64% of games." },
        .{ .flipped = true, .want = " Ahri is behind from the start, about 800 gold by 14 minutes, then whoever is ahead wins 64% of games." },
    };
    for (ahead) |case| {
        var aw: Writer.Allocating = .init(gpa);
        defer aw.deinit();
        try lead(&aw.writer, .{ .v = .{ .curve = &cv, .flipped = case.flipped }, .key = "any", .label = "" }, false, x);
        try std.testing.expectEqualStrings(case.want, aw.written());
    }

    // Clear only from minute 9 on
    for (minutes[0..8]) |*m| m.est[0].se = 1000;
    var aw: Writer.Allocating = .init(gpa);
    defer aw.deinit();
    try lead(&aw.writer, .{ .v = .{ .curve = &cv, .flipped = false }, .key = "x", .label = "" }, true, x);
    try std.testing.expectEqualStrings("<span class=\"exp exp-x\"> Ahri is ahead from minute 9, about 800 gold by 14 minutes, then whoever is ahead wins 64% of games.</span>", aw.written());

    // Within 2 SE at 14, or clear but about 100 gold: the number, no "since when"
    const small = [_]struct { e: curvesfile.Estimate, want: []const u8 }{
        .{ .e = .{ .mean = 30, .se = 20 }, .want = "Ahri is 30 gold ahead" },
        .{ .e = .{ .mean = -140, .se = 20 }, .want = "Ahri is 140 gold behind" },
        .{ .e = .{ .mean = 4, .se = 20 }, .want = "Ahri is level in gold" },
    };
    for (small) |case| {
        minutes[curvesfile.lane_minute - 1].est[0] = case.e;
        aw.clearRetainingCapacity();
        try lead(&aw.writer, .{ .v = .{ .curve = &cv, .flipped = false }, .key = "any", .label = "" }, false, x);
        const want = try std.fmt.allocPrint(gpa, " {s} at 14 minutes, then whoever is ahead wins 64% of games.", .{case.want});
        defer gpa.free(want);
        try std.testing.expectEqualStrings(want, aw.written());
    }

    // Mostly baseline: the page's note says so, no verdict
    var thin_header = header;
    thin_header.own = 300;
    const thin_cv: curvesfile.Curve = .{ .header = &thin_header, .minutes = &minutes };
    aw.clearRetainingCapacity();
    try lead(&aw.writer, .{ .v = .{ .curve = &thin_cv, .flipped = false }, .key = "any", .label = "" }, false, x);
    try std.testing.expectEqualStrings("", aw.written());
}

test why {
    const gpa = std.testing.allocator;
    var minutes: [curvesfile.lane_minute]curvesfile.Minute = @splat(.{ .n = 400, .gold = .{}, .xp = .{}, .cs = .{} });
    var header = std.mem.zeroes(curvesfile.Header);
    header.games = 400;
    header.own = 800;
    header.lane_games = 400;
    header.lane_a = 250;
    header.lane_b = 150;
    header.a_wins_lane_a = 160;
    header.b_wins_lane_b = 96;
    header.a_kills_b = .{ 120, 200, 0 };
    header.b_kills_a = .{ 80, 220, 0 };
    header.level6_a = 330;
    header.level6_b = 342;
    header.first_item_a = 853;
    header.first_item_b = 712;
    for (&minutes, 0..) |*m, i| {
        m.est[0] = .{ .mean = @intCast(60 * i), .se = 20 };
        m.est[2] = .{ .mean = @intCast(i), .se = 1 };
    }
    const x: Champ = .{ .c = 0, .id = 1, .key = "", .name = "Ahri", .slug = "", .banned = 0, .games = 0 };
    const y: Champ = .{ .c = 1, .id = 2, .key = "", .name = "Zed", .slug = "", .banned = 0, .games = 0 };
    const cv: curvesfile.Curve = .{ .header = &header, .minutes = &minutes };
    var aw: Writer.Allocating = .init(gpa);
    defer aw.deinit();
    try why(&aw.writer, .{ .curve = &cv, .flipped = false }, .middle, x, y);
    // 780 gold and 13 CS at 14: 260 of it from CS; half (390) first reached at minute 8
    try std.testing.expectEqualStrings(
        \\<h3 class="mu-h">How the lane goes</h3><ul class="mu-why">
        \\<li><b>+780 gold</b> at 14 min: about +260 from CS (+13 CS at about 20 gold), +520 from kills, assists, plates and the rest; half of it is there by 8 min</li>
        \\<li>Kills or assists on the lane opponent before 6 min: Ahri in 30% of games, Zed in 20%; 6 to 14 min: 50% against 55%</li>
        \\<li>Level 6 at 5:30 against 5:42 (medians), 12 s earlier</li>
        \\<li>First finished item at 14:13 against 11:52 (medians), 2:21 later</li>
        \\<li>Ahead in gold at 14 min, Ahri won 64% of 250 games; behind, 36% of 150</li>
        \\</ul>
        \\
    , aw.written());

    // From Zed's side in the jungle: no CS split, the deficit's half by minute 8 too
    aw.clearRetainingCapacity();
    try why(&aw.writer, .{ .curve = &cv, .flipped = true }, .jungle, y, x);
    try std.testing.expect(std.mem.startsWith(u8, aw.written(),
        \\<h3 class="mu-h">How the lane goes</h3><ul class="mu-why">
        \\<li><b>-780 gold</b> at 14 min with -13 CS; half of it is there by 8 min</li>
        \\<li>Kills or assists on the lane opponent before 6 min: Zed in 20% of games, Ahri in 30%
    ));
}
