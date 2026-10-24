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
const Dim = @import("scope.zig").Dim;

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

/// period in a page's scope line: a 30-day file's with the patches its view's 30 days
/// span ("last 30 days, patches 16.19 to 16.21"), as the footer
fn scope(site: *const Site, curves: *const Curves) ![]const u8 {
    const label = curves.patch();
    if (label.len > 0 and std.ascii.isDigit(label[0])) return site.arena.print("patch {s}", .{label});
    return if (site.view.period == .days30) site.when else label;
}

/// The curves' period as a scope chip: a patch file's patch, else the view's
fn periodDim(site: *const Site, curves: *const Curves) !Dim {
    const label = curves.patch();
    if (label.len > 0 and std.ascii.isDigit(label[0])) return .patch(site.arena, label);
    return site.periodDim(site.view.period);
}

/// From x's side: x's gold, wins and timings first
pub fn path(a: std.mem.Allocator, r: Role, x: Champ, y: Champ) ![]const u8 {
    return a.print("matchup/{s}/{s}", .{ r.label(), try file(a, x, y) });
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
    const slash = std.mem.findScalar(u8, rest, '/') orelse return false;
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
    const p = try site.page(
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
        \\<p class="muted">Each pair once, from the side that won more (searching one champion shows its side), {region}, {when}; under {floor} games, see champion pages.</p>
        \\<div class="tl-bar mu-bar"><nav class="tabs mu-roles" aria-label="Role"><a href="#all">All roles</a>{tabs}</nav><span class="mu-search" hidden><input type="search" placeholder="Search champion" data-min-search aria-label="Search champion"></span></div>
        \\
    , .{
        .region = site.view.region.in(),
        .when = try scope(site, c),
        .floor = floor,
        .tabs = tpl.each(&Role.all, {}, roleTab),
    });
    var choices: std.ArrayList(u32) = .empty;
    for (index_floors) |f| if (f >= floor) try choices.append(a, f);
    try html.minGames(w, "../", "matchups", choices.items, default, 0);
    try w.writeAll("<div class=\"mu-ix\" data-role=\"top\">\n");
    for (Role.all, lists) |r, list| {
        const slug = r.label();
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
        \\const neg=(t)=>t[0]==="+"?"-"+t.slice(1):t[0]==="-"?"+"+t.slice(1):t,hl=(e)=>{e.style.cssText=e.style.cssText.replace(/--(hi|lo)(?=\d)/g,(m)=>m==="--hi"?"--lo":"--hi")};
        \\const flip=(row)=>{const [a,b,wr,vs,gold]=row.cells,x=a.firstElementChild,y=b.firstElementChild;a.append(y);b.append(x);x.classList.toggle("box");y.classList.toggle("box");
        \\for(const c of [wr,vs,gold])c.dataset.v=String(c===wr?1-c.dataset.v:-c.dataset.v);const w=wr.querySelector(".wr"),d=w.querySelector(".d"),r=w.querySelector("b");hl(w);d.style.left=(100-parseFloat(d.style.left)).toFixed(1)+"%";r.textContent=(100-parseFloat(r.textContent)).toFixed(1)+"%";
        \\const s=vs.querySelector(".vs");hl(s);s.firstElementChild.textContent=neg(s.textContent);const g=gold.querySelector(".gold");g.textContent=neg(g.textContent);g.classList.contains("even")||(g.classList.toggle("up"),g.classList.toggle("down"));row.toggleAttribute("data-f")};
        \\// A search naming only a row's second champion turns the row to that champion's side: its rate is 100 minus the other's, vs usual and gold the other's negated (champion.usual is symmetric)
        \\const norm=(t)=>t.toLowerCase().replace(/[^a-z0-9]/g,"");
        \\const sync=()=>{const v=q?q.value.trim():"";ix.classList.toggle("q",v!=="");const words=v.split(/\s+/).map(norm).filter((x)=>x&&!["v","vs","versus"].includes(x));let moved=false;
        \\for(const row of ix.querySelectorAll("tr[data-name]")){const [a,b]=row.dataset.name.split("|").map(norm),has=(n)=>words.length>0&&words.every((x)=>n.includes(x));if((has(b)&&!has(a))!==row.hasAttribute("data-f")){flip(row);moved=true}}
        \\if(moved)for(const t of ix.querySelectorAll("table"))t._resort?.()};if(q){q.addEventListener("input",sync);addEventListener("pageshow",sync)}})()</script>
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
    try tpl.render(w, "<a href=\"#{slug}\">{name}</a>", .{ .slug = r.label(), .name = root.roleName(r) });
}

const IndexEntry = struct {
    x: Champ,
    y: Champ,
    games: u32,
    thin: bool,
    /// From the stats, not the curves
    odds: Odds,
    /// Lane curve's gold at lane_minute, x minus y
    gold: i32,
    /// A lead to emphasise (J11, J12): min_lead_gold or more, 2 SE from 0, thin_games
    clear: bool,
};

/// x and y swapped when y won more
fn indexEntry(site: *const Site, c: *const Curves, r: Role, x0: Champ, y0: Champ, games: u32, ka: f64) IndexEntry {
    const st = &site.stats;
    var x = x0;
    var y = y0;
    const e = st.enemy(r, r, x.c, y.c);
    if (2 * e.wins < e.games) std.mem.swap(Champ, &x, &y);
    const v = c.get(r, .all, x.id, y.id).?;
    const g = v.estimate(.gold, core.curvesfile.lane_minute - 1);
    return .{
        .x = x,
        .y = y,
        .games = games,
        .thin = thin(v),
        .odds = odds(st, r, x, y, ka),
        .gold = g.mean,
        .clear = games >= thin_games and @abs(g.mean) >= min_lead_gold and clearSide(g) != 0,
    };
}

fn indexRow(ctx: struct { *const Site, Role, u32 }, w: *Writer, e: IndexEntry) !void {
    const site, const r, const default = ctx;
    const a = site.arena;
    const o = e.odds;
    try tpl.render(w,
        \\<tr class="bx{thin}" data-games="{games}" data-name="{x}|{y}"{hidden}><td class="l"><a class="champ box" href="{x_href}"><img src="{x_icon}" alt="" loading="lazy" width="24" height="24">{x}</a></td><td class="l"><a class="champ" href="{y_href}"><img src="{y_icon}" alt="" loading="lazy" width="24" height="24">{y}</a></td>{wr}<td data-v="{vs:.4}"><span class="vs" style="--c:{colour}"><b>{pts}</b></span></td><td class="opt" data-v="{gold}"><span class="gold {side}" style="opacity:{fade:.2}">{sign}{gold}</span></td><td class="dim" data-v="{games}">{count}</td></tr>
        \\
    , .{
        .games = e.games,
        .x = e.x.name,
        .y = e.y.name,
        .thin = tpl.when(e.thin, " thin"),
        .hidden = tpl.flag(e.games < default, "hidden"),
        .x_href = (try path(a, r, e.x, e.y))["matchup/".len..],
        .y_href = (try path(a, r, e.y, e.x))["matchup/".len..],
        .x_icon = try site.icon(e.x),
        .y_icon = try site.icon(e.y),
        // Sorts by usual + vs usual: the rate pulled toward usual by its games
        .wr = tpl.call(tierlist.trackCell, .{ root.ratio(o.wins, o.games), o.usual + o.d.mean, o.games, tierlist.matchup_span, try a.print("{d} games in the stats", .{o.games}), @as(?[]const u8, null) }),
        .vs = o.d.mean,
        .colour = tierlist.wrColour(0.5 + o.d.mean, tierlist.table_span),
        .pts = champion.Points{ .v = o.d.mean },
        .side = if (!e.clear) "even" else if (e.gold > 0) "up" else "down",
        .fade = core.curvesfile.fade(e.games),
        .count = root.Thousands{ .n = e.games },
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
            .label = try a.print("{s} {d}k+ mastery", .{ s[0].name, curvesfile.experienced_points / 1000 }),
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
    var p = try site.page(title, desc, page_path, .matchups);
    p.index = v.games() >= site.opts.index_min_games;
    for (html.View.all, site.view_curves, &p.counterparts.?) |view, *other, *there| {
        const has = if (other.*) |*o| o.get(r, .all, x.id, y.id) != null else false;
        if (!has) there.* = try std.mem.concat(a, u8, &.{ view.dir(), "matchup/index.html" });
    }
    try html.head(w, p);
    const swap = try file(a, y, x);
    try tpl.render(w,
        \\<div class="hero"><img src="{x_icon}" alt="" width="72" height="72"><a class="swap" href="{swap}" title="Swap sides: {y} vs {x}" aria-label="Swap sides: {y} vs {x}">⇄</a><img src="{y_icon}" alt="" width="72" height="72"><div><h1>{x} vs {y}</h1>
        \\<p class="muted">{chip} From {x}'s side: {lane} lane, ranked solo/duo {region}, {when}, Platinum+.</p></div></div>
        \\<nav class="mu-nav" aria-label="Other matchups"><a class="btn" href="{swap}">⇄ From {y}'s side</a>
        \\{champions}{opponents}</nav>
        \\
    , .{
        .chip = site.chip(site.regionDim(site.view.region), try periodDim(site, curves), .plat),
        .x_icon = try site.icon(x),
        .y_icon = try site.icon(y),
        .swap = swap,
        .x = x.name,
        .y = y.name,
        .lane = lane,
        .region = site.view.region.in(),
        .when = try scope(site, curves),
        .opponents = tpl.call(opponentStrip, .{ site, curves, r, x, y }),
        .champions = tpl.call(picker, .{ site, curves, r, x, y }),
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
    const base = curves.baseline(r, .all);
    const o = odds(&site.stats, r, x, y, champion.usualK(&site.stats, r));
    try headline(w, o, v, r, x, y);
    try tiles(site, w, o, v, r, x, y, when);
    // Everything on screen at once as cards: the gold curve beside both sides' numbers,
    // then XP, CS, comebacks and the splits, then the build
    try tpl.renderPart(w, "<div class=\"mu-main\"><section class=\"mu-card mu-gold\"><h2>Gold difference</h2>\n", .{});
    try chartOne(w, v, base, prevLine(site, r, x, y), .gold, "gold", x, y, when, lane, false);
    try tpl.renderPart(w, "</section>\n", .{});
    try h2h(w, v, x, y);
    try tpl.renderPart(w, "</div>\n<div class=\"mu-cards\">\n", .{});
    for ([_]struct { []const u8, curvesfile.Metric, []const u8 }{ .{ "Experience difference", .xp, "XP" }, .{ "CS difference", .cs, "CS" } }) |c| {
        try tpl.renderPart(w, "<section class=\"mu-card\"><h2>{title}</h2>\n", .{ .title = c[0] });
        try chartOne(w, v, base, null, c[1], c[2], x, y, when, lane, true);
        try tpl.renderPart(w, "</section>\n", .{});
    }
    try comeback.card(w, curves, r, x, y);
    try splits(w, curves, vs, r, x, y);
    try duos(site, w, r, x, y);
    try tpl.renderPart(w, "</div>\n", .{});
    try builds.vsStrip(site, w, r, x, y, page_path);
    const to_site = try site.toShared(page_path);
    try tpl.render(w,
        \\<p class="muted"><a href="{x_href}">{x}</a> · <a href="{y_href}">{y}</a> · <a href="{up}method.html">Method</a></p>
        \\
    , .{
        .x_href = try site.champHref(x, to_site),
        .x = x.name,
        .y_href = try site.champHref(y, to_site),
        .y = y.name,
        .up = to_site,
    });
    try html.foot(w, p);
}

/// y's other lane opponents with a page as a closed list, most games first, each from
/// that champion's side against y: "Change champion" swaps x
fn picker(w: *Writer, site: *const Site, curves: *const Curves, r: Role, x: Champ, y: Champ) !void {
    const list = try others(site, curves, r, y);
    if (list.len < 2) return;
    try tpl.render(w,
        \\<details class="pick"><summary>Change champion <span class="muted">{n}</span></summary><ul class="pick-list">
        \\{items}</ul></details>
        \\
    , .{ .n = list.len, .items = tpl.each(list, .{ site, x, y }, pickItem) });
}

const Other = struct { ch: Champ, games: u32 };

fn moreGames(_: void, p_: Other, q: Other) bool {
    return p_.games > q.games;
}

/// `fixed`'s lane opponents with a page in r, most games (the curves') first
fn others(site: *const Site, curves: *const Curves, r: Role, fixed: Champ) ![]Other {
    var list: std.ArrayList(Other) = .empty;
    for (curves.curves) |c| {
        const h = c.header;
        if (h.role != @backingInt(r) or !isPage(h)) continue;
        const id = if (h.a == fixed.id) h.b else if (h.b == fixed.id) h.a else continue;
        try list.append(site.arena, .{ .ch = champ(site, id) orelse continue, .games = h.games });
    }
    std.mem.sort(Other, list.items, {}, moreGames);
    return list.items;
}

fn pickItem(ctx: struct { *const Site, Champ, Champ }, w: *Writer, o: Other) !void {
    const site, const x, const y = ctx;
    try tpl.render(w,
        \\<li class="bx{current}"{aria}><a class="box" href="{href}"><img src="{icon}" alt="" loading="lazy" width="32" height="32">{name}</a> <span class="muted">{games}</span></li>
        \\
    , .{
        .current = tpl.when(o.ch.id == x.id, " current"),
        .aria = tpl.flag(o.ch.id == x.id, "aria-current=\"page\""),
        .href = try file(site.arena, o.ch, y),
        .icon = try site.icon(o.ch),
        .name = o.ch.name,
        .games = o.games,
    });
}

/// x's lane opponents with a page as one scrolling row under the header, most games
/// first: icon and x's win rate against each (the stats, as the tiles), y lit and
/// scrolled into view; the search hides the others, Enter opens the first left
fn opponentStrip(w: *Writer, site: *const Site, curves: *const Curves, r: Role, x: Champ, y: Champ) !void {
    const list = try others(site, curves, r, x);
    if (list.len == 0) return;
    for (list) |*o| o.games = site.stats.enemy(r, r, x.c, o.ch.c).games;
    std.mem.sort(Other, list, {}, moreGames);
    try tpl.render(w,
        \\<div class="mu-opps"><input type="search" placeholder="Opponent" aria-label="Search {x}'s opponents"><ul aria-label="{x}'s {lane} lane opponents, most games first">
        \\{items}</ul></div>
        \\
    , .{
        .x = x.name,
        .lane = root.roleName(r),
        .items = tpl.each(list, .{ site, r, x, y }, opponentItem),
    });
    try w.writeAll(
        \\<script>(()=>{const s=document.currentScript.previousElementSibling,q=s.querySelector("input"),l=s.querySelector("ul"),c=l.querySelector("[aria-current]");
        \\if(c)l.scrollLeft=c.offsetLeft-(l.clientWidth-c.offsetWidth)/2;const k=(t)=>t.toLowerCase().replace(/[^a-z0-9]/g,"");
        \\q.addEventListener("input",()=>{const v=k(q.value);for(const li of l.children)li.hidden=!k(li.dataset.name).includes(v);l.scrollLeft=0});
        \\q.addEventListener("keydown",(e)=>{const a=[...l.children].find((li)=>!li.hidden);if(e.key==="Enter"&&a&&q.value.trim())location.href=a.querySelector("a").href})})()</script>
        \\
    );
}

fn opponentItem(ctx: struct { *const Site, Role, Champ, Champ }, w: *Writer, o: Other) !void {
    const site, const r, const x, const y = ctx;
    const e = site.stats.enemy(r, r, x.c, o.ch.c);
    const current = o.ch.id == y.id;
    try tpl.render(w,
        \\<li data-name="{name}"><a href="{href}"{aria} title="{title}"><img src="{icon}" alt="{name}" loading="lazy" width="32" height="32"><b style="--c:{colour};opacity:{fade:.2}">{wr}</b></a></li>
        \\
    , .{
        .name = o.ch.name,
        .href = try file(site.arena, x, o.ch),
        .aria = tpl.flag(current, "aria-current=\"page\""),
        .title = try site.arena.print("{s} vs {s}: {s} wins {d:.1}% in {f} games", .{
            x.name, o.ch.name, x.name, 100 * root.ratio(e.wins, e.games), root.Thousands{ .n = e.games },
        }),
        .wr = tpl.call(pct1, .{ e.wins, e.games }),
        .icon = try site.icon(o.ch),
        .colour = tierlist.wrColour(root.ratio(e.wins, e.games), tierlist.matchup_span),
        .fade = curvesfile.fade(e.games),
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
    try chartOne(w, v, curves.baseline(b.r, .all), null, .gold, "gold", x, y, when, lane, false);
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
/// the champion page's opponent grid); `ka`: champion.usualK of `r`
/// `base`: x's win rate in the role, the champion page's
const Odds = struct { wins: u32, games: u32, base: f64, usual: f64, d: champion.VsUsual };

fn odds(st: *const core.Stats, r: Role, x: Champ, y: Champ, ka: f64) Odds {
    const e = st.enemy(r, r, x.c, y.c);
    const xr = st.champRole(r, x.c);
    const yr = st.champRole(r, y.c);
    const base = root.ratio(xr.wins, xr.games);
    const u = champion.usual(base, root.ratio(yr.wins, yr.games));
    return .{ .wins = e.wins, .games = e.games, .base = base, .usual = u, .d = champion.VsUsual.of(e.wins, e.games, u, ka) };
}

/// The page's answer in a line, descriptive (docs/production-key.md product rules): x's
/// win rate here, then in all its games in the role (the champion page's number; the
/// Vs usual tile compares against this opponent's strength), then the lane (lead())
fn headline(w: *Writer, o: Odds, v: View, r: Role, x: Champ, y: Champ) !void {
    if (o.games == 0) return;
    try tpl.render(w, "<p class=\"verdict mu-sum\">{x} wins {wr} against {y}, {base:.1}% in all {lane} games.{lead}</p>\n", .{
        .x = x.name,
        .wr = tpl.call(pct1, .{ o.wins, o.games }),
        .y = y.name,
        .base = 100 * o.base,
        .lane = root.roleName(r),
        .lead = tpl.call(lead, .{ v, x }),
    });
}

/// The first screen's numbers: win rate, vs usual (odds()), the lane curve's gold at
/// lane_minute (CS's part of it and when half of it is there in its title) and how often
/// x leads, then games
fn tiles(site: *const Site, w: *Writer, o: Odds, v: View, r: Role, x: Champ, y: Champ, when: []const u8) !void {
    const z = 1.2816;
    const i = curvesfile.lane_minute - 1;
    const has_gold = i < v.minutes() and v.minute(i).n >= minuteFloor(v);
    const g = v.estimate(.gold, i);
    const cs_gold = if (has_gold and r != .jungle and r != .utility) round10(@as(i32, v.estimate(.cs, i).mean) * gold_per_cs) else null;
    const lane = v.lane();
    try tpl.render(w,
        \\<div class="tiles mu-tiles"><div><span>Win rate</span><b class="wrc" style="--c:{wr_colour};opacity:{fade:.2}">{wr}</b><small>{x} against {y}</small></div><div title="{title}"><span>Vs usual</span><b class="vs" style="--c:{colour}">{pts}</b><small>usually {usual:.1}%</small></div><div{thin} title="{gold_title}"><span>Gold at {minute} min</span><b class="{side}">{gold}{dash}</b><small>{cs}</small></div><div{thin}><span>Ahead at {minute} min</span><b>{ahead}</b><small>{x}, in gold</small></div><div><span>Games</span><b>{games}</b><small>{when}</small></div></div>
        \\
    , .{
        .wr_colour = tierlist.wrColour(root.ratio(o.wins, o.games), tierlist.matchup_span),
        .fade = curvesfile.fade(o.games),
        .wr = tpl.call(pct1, .{ o.wins, o.games }),
        .x = x.name,
        .y = y.name,
        .title = try site.arena.print("Against {s} {s} wins {d:.1}% in {d} games. Against an opponent this strong in {s}, {s} usually wins about {d:.1}%. Vs usual {f} points, pulled toward 0 the fewer the games; 8 in 10 between {f} and {f}", .{
            y.name,                                        x.name,                           100 * root.ratio(o.wins, o.games),
            o.games,                                       root.roleName(r),                 x.name,
            100 * o.usual,                                 champion.Points{ .v = o.d.mean }, champion.Points{ .v = o.d.mean - z * o.d.sd },
            champion.Points{ .v = o.d.mean + z * o.d.sd },
        }),
        .colour = tierlist.wrColour(0.5 + o.d.mean, tierlist.table_span),
        .pts = champion.Points{ .v = o.d.mean },
        .usual = 100 * o.usual,
        .thin = tpl.flag(thin(v), "class=\"stale\""),
        .gold_title = if (!has_gold) "" else if (halfBy(v)) |m| try site.arena.print("{s} minus {s}, estimated average; half of it there by {d} min", .{ x.name, y.name, m }) else try site.arena.print("{s} minus {s}, estimated average", .{ x.name, y.name }),
        .minute = curvesfile.lane_minute,
        .side = if (!has_gold) "even" else if (clearSide(g) > 0) "up" else if (clearSide(g) < 0) "down" else "even",
        .gold = tpl.when(has_gold, tpl.call(signed, .{g.mean})),
        .dash = tpl.when(!has_gold, "-"),
        .cs = if (cs_gold) |c| tpl.t("about {c} of it from CS", .{ .c = tpl.call(signed, .{c}) }) else null,
        .ahead = tpl.call(percent, .{ lane.ahead, lane.games }),
        .games = root.Thousands{ .n = o.games },
        .when = when,
    });
}

/// Both sides' shares as bars from the middle, x's growing left and y's right, then
/// level 6 and first item timings; each row titled in full
fn h2h(w: *Writer, v: View, x: Champ, y: Champ) !void {
    const lane = v.lane();
    const m = curvesfile.lane_minute;
    try tpl.renderPart(w,
        \\<section class="mu-card mu-h2h{thin}"><h2>Head to head</h2><div class="h2h"><span class="h2h-x">{x}</span><span></span><span></span><span class="h2h-y">{y}</span>
        \\
    , .{ .thin = tpl.when(thin(v), " thin"), .x = x.name, .y = y.name });
    try bars(w, "Wins the game", .{ v.wins(), v.games() }, .{ v.games() - v.wins(), v.games() });
    var buf: [64]u8 = undefined;
    try bars(w, try std.mem.print(&buf, "Ahead in gold at {d} min", .{m}), .{ lane.ahead, lane.games }, .{ lane.behind, lane.games });
    var buf2: [64]u8 = undefined;
    try bars(w, try std.mem.print(&buf2, "Wins when ahead at {d} min", .{m}), .{ lane.wins_ahead, lane.ahead }, .{ lane.behind - lane.wins_behind, lane.behind });
    const phases = [_][]const u8{ "Kill on the other, 0 to 6 min", "Kill on the other, 6 to 14 min", "Kill on the other, after 14 min" };
    for (phases, 0..) |label, ph| try bars(w, label, .{ v.kills(ph), v.games() }, .{ v.deaths(ph), v.games() });
    try times(w, "Level 6", v.level6());
    try times(w, "First finished item", v.firstItem());
    try tpl.renderPart(w,
        \\</div><p class="mu-note">Share of each side's games; kills count assists. Medians for timings.</p></section>
        \\
    , .{});
}

fn bars(w: *Writer, label: []const u8, a: [2]u32, b: [2]u32) !void {
    const pa = root.ratio(a[0], a[1]);
    const pb = root.ratio(b[0], b[1]);
    const ra: i32 = @round(100 * pa);
    const rb: i32 = @round(100 * pb);
    try tpl.render(w,
        \\<span class="h2h-l">{label}</span><b class="h2h-v{xa}">{pa}</b><span class="h2h-bar"><i class="x" style="width:{wa:.1}%"></i></span><span class="h2h-bar r"><i class="y" style="width:{wb:.1}%"></i></span><b class="h2h-v{yb}">{pb}</b>
        \\
    , .{
        .label = label,
        .xa = tpl.when(ra < rb, " lo"),
        .pa = tpl.call(percent, .{ a[0], a[1] }),
        .wa = 100 * pa,
        .wb = 100 * pb,
        .yb = tpl.when(rb < ra, " lo"),
        .pb = tpl.call(percent, .{ b[0], b[1] }),
    });
}

/// A timing row: both medians, the gap between them in the middle; "-" when fewer than
/// half the games got there
fn times(w: *Writer, label: []const u8, both: [2]u16) !void {
    const diff = @as(i32, both[0]) - @as(i32, both[1]);
    const known = both[0] != 0 and both[1] != 0;
    try tpl.render(w,
        \\<span class="h2h-l">{label}</span><b class="h2h-v{xa}">{a}</b><span class="h2h-gap">{gap}</span><b class="h2h-v{yb}">{b}</b>
        \\
    , .{
        .label = label,
        .xa = tpl.when(known and diff > 0, " lo"),
        .a = tpl.call(clockOr, .{both[0]}),
        .gap = tpl.when(known and diff != 0, tpl.t("{d} apart", .{ .d = tpl.call(duration, .{@abs(diff)}) })),
        .yb = tpl.when(known and diff < 0, " lo"),
        .b = tpl.call(clockOr, .{both[1]}),
    });
}

fn clockOr(w: *Writer, secs: u16) !void {
    if (secs == 0) return w.writeAll("-");
    try clock(w, secs);
}

/// x's win rate and gold at lane_minute by rank bracket, then with either side
/// experienced on their champion (variants after the first); rows under thin_games faded
fn splits(w: *Writer, curves: *const Curves, vs: []const Variant, r: Role, x: Champ, y: Champ) !void {
    try tpl.renderPart(w,
        \\<section class="mu-card mu-split"><h2>By rank and mastery</h2><div class="split"><span></span><span class="sh">{x} wins</span><span class="sh num">Gold at {minute}</span>
        \\
    , .{ .x = x.name, .minute = curvesfile.lane_minute });
    for (std.enums.values(Bracket)) |b| {
        const v = curves.get(r, b, x.id, y.id) orelse {
            try tpl.render(w, "<span class=\"thin\">{rank}</span><span class=\"thin sh\">more data needed</span><span></span>\n", .{ .rank = b.label() });
            continue;
        };
        try splitRow(w, b.label(), v, b != .all);
    }
    for (vs[1..]) |s| try splitRow(w, s.label, s.v, true);
    try tpl.renderPart(w, "</div></section>\n", .{});
}

/// `count`: games under the label; all games' count is the Games tile's, so left out
fn splitRow(w: *Writer, label: []const u8, v: View, count: bool) !void {
    const i = curvesfile.lane_minute - 1;
    const has_gold = i < v.minutes() and v.minute(i).n >= minuteFloor(v);
    const p = root.ratio(v.wins(), v.games());
    try tpl.render(w,
        \\<span{thin}>{label}{count}</span><b class="wrc{thin_c}" style="--c:{colour}" title="{label}: {x_wins} of {games} games won">{rate}</b><span class="num{thin_c}">{gold}{dash}</span>
        \\
    , .{
        .thin = tpl.flag(thin(v), "class=\"thin\""),
        .label = label,
        .count = tpl.when(count, tpl.t("<small>{games} games</small>", .{ .games = root.Thousands{ .n = v.games() } })),
        .thin_c = tpl.when(thin(v), " thin"),
        .colour = tierlist.wrColour(p, tierlist.matchup_span),
        .x_wins = v.wins(),
        .games = root.Thousands{ .n = v.games() },
        .rate = tpl.call(percent, .{ v.wins(), v.games() }),
        .gold = tpl.when(has_gold, tpl.call(signed, .{v.estimate(.gold, i).mean})),
        .dash = tpl.when(!has_gold, "-"),
    });
}

/// Most duo partners listed for each side
const duo_rows = 5;

/// Bot lane: the supports x and y each play with, most games first, vs usual as on the
/// champion page's Duos tab; a support matchup lists their bot laners. From all of each
/// champion's games in the role, not only this matchup's: the stats count pairs, not
/// threes
fn duos(site: *const Site, w: *Writer, r: Role, x: Champ, y: Champ) !void {
    const r2: Role = switch (r) {
        .bottom => .utility,
        .utility => .bottom,
        else => return,
    };
    const p: champion.Pairs = .{ .st = &site.stats, .r = r, .r2 = r2, .ally = true };
    const k = champion.pairsUsualK(p);
    try tpl.renderPart(w,
        \\<section class="mu-card mu-duos"><h2>{title} <span class="muted">in all their {lane} games</span></h2><div class="split">
        \\
    , .{ .title = if (r2 == .utility) "Supports" else "Bot laners", .lane = root.roleName(r) });
    const to_site = try site.toShared(try path(site.arena, r, x, y));
    for ([_]Champ{ x, y }) |ch| try duoRows(site, w, p, k, ch, to_site);
    try tpl.renderPart(w, "</div></section>\n", .{});
}

fn duoRows(site: *const Site, w: *Writer, p: champion.Pairs, k: f64, ch: Champ, to_site: []const u8) !void {
    const st = p.st;
    const Duo = struct { ch: Champ, wins: u32, games: u32 };
    var list: std.ArrayList(Duo) = .empty;
    for (0..st.n) |c2| {
        const e = p.get(ch.c, c2);
        if (e.games == 0) continue;
        try list.append(site.arena, .{ .ch = site.champs[site.by_c[c2] orelse continue], .wins = e.wins, .games = e.games });
    }
    std.mem.sort(Duo, list.items, {}, struct {
        fn f(_: void, a: Duo, b: Duo) bool {
            return a.games > b.games;
        }
    }.f);
    try tpl.render(w, "<span class=\"sh\">{x} with</span><span class=\"sh num\">Vs usual</span><span class=\"sh num\">Games</span>\n", .{ .x = ch.name });
    if (list.items.len == 0) return tpl.render(w, "<span class=\"thin\">more data needed</span><span></span><span></span>\n", .{});
    const cr = st.champRole(p.r, ch.c);
    for (list.items[0..@min(duo_rows, list.items.len)]) |d| {
        const dr = st.champRole(p.r2, d.ch.c);
        const u = p.usualOf(root.ratio(cr.wins, cr.games), root.ratio(dr.wins, dr.games));
        const v = champion.VsUsual.of(d.wins, d.games, u, k);
        try tpl.render(w,
            \\<a class="champ" href="{href}" style="opacity:{fade:.2}"><img src="{icon}" alt="" loading="lazy" width="24" height="24">{name}</a><span class="vs num" style="--c:{colour};opacity:{fade:.2}" title="{title}"><b>{pts}</b></span><span class="num dim">{games}</span>
            \\
        , .{
            .href = try site.champHref(d.ch, to_site),
            .fade = curvesfile.fade(d.games),
            .icon = try site.icon(d.ch),
            .name = d.ch.name,
            .colour = tierlist.wrColour(0.5 + v.mean, tierlist.table_span),
            .title = try site.arena.print("{s} with {s}: {d:.1}% won in {f} games, usually about {d:.1}%", .{
                ch.name, d.ch.name, 100 * root.ratio(d.wins, d.games), root.Thousands{ .n = d.games }, 100 * u,
            }),
            .pts = champion.Points{ .v = v.mean },
            .games = root.Thousands{ .n = d.games },
        });
    }
}

/// "50.3%"; "-" without games
fn pct1(w: *Writer, part: u32, whole: u32) !void {
    if (whole == 0) return w.writeAll("-");
    try w.print("{d:.1}%", .{100 * root.ratio(part, whole)});
}

/// Lane minion gold per CS before 14 minutes: 3 melee (21), 3 casters (14) a wave and a
/// cannon (60 to 70) every third, 381 gold over 19 minions. Jungle camps and support
/// CS differ, so those roles get no split
const gold_per_cs = 20;

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

fn clock(w: *Writer, secs: u16) !void {
    try w.print("{d}:{d:0>2}", .{ secs / 60, secs % 60 });
}

/// "12 s", "2:21"
fn duration(w: *Writer, secs: u32) !void {
    if (secs < 60) return w.print("{d} s", .{secs});
    try w.print("{d}:{d:0>2}", .{ secs / 60, secs % 60 });
}

/// The headline's lane part: who is ahead by lane_minute, since when only where the
/// estimate is more than 2 SE from 0, then how often the side ahead wins. Greyed-out
/// (thin) curves get none: their note says why
fn lead(w: *Writer, v: View, x: Champ) !void {
    const i = curvesfile.lane_minute - 1;
    if (thin(v) or i >= v.minutes() or v.minute(i).n < minuteFloor(v)) return;
    const lane = v.lane();
    const split = lane.ahead >= min_minute_games and lane.behind >= min_minute_games;
    try tpl.render(w, " {gold}{wins}.", .{
        .gold = tpl.call(leadSince, .{ v, x }),
        .wins = tpl.when(split, tpl.t(", then whoever is ahead wins {share} of games", .{
            .share = tpl.call(percent, .{ lane.wins_ahead + lane.behind - lane.wins_behind, lane.ahead + lane.behind }),
        })),
    });
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

/// Estimated average line and middle-half band of `metric` by minute, each minute
/// titled with both; `prev` dashed. A `small` chart (XP, CS beside the gold one) has no
/// caption: the gold one's says what the marks are
fn chartOne(
    w: *Writer,
    v: View,
    base: ?View,
    prev: ?Prev,
    metric: curvesfile.Metric,
    unit: []const u8,
    x: Champ,
    y: Champ,
    when: []const u8,
    lane: []const u8,
    small: bool,
) !void {
    const last = reach(v);
    const figure = .{ .thin = tpl.when(thin(v), " thin"), .small = tpl.when(small, " mu-small") };
    if (last < 2) {
        return tpl.render(w,
            \\<figure class="chart{thin}{small}">
            \\<p class="muted">Not enough games yet.</p></figure>
            \\
        , figure);
    }
    var bands: [curvesfile.max_minutes][2]i32 = undefined;
    var line: [curvesfile.max_minutes]i32 = undefined;
    var prev_line: [curvesfile.max_minutes]i32 = undefined;
    for (0..last) |i| {
        bands[i] = band(v, base, metric, i);
        line[i] = v.estimate(metric, i).mean;
    }
    const prev_last = if (prev) |pv| @min(last, reach(pv.v)) else 0;
    for (0..prev_last) |i| prev_line[i] = prev.?.v.estimate(metric, i).mean;
    var aria_buf: [160]u8 = undefined;
    const aria = std.mem.print(&aria_buf, "{s} of {s} minus {s} by minute", .{ unit, x.name, y.name }) catch unit;
    try tpl.renderPart(w, "<figure class=\"chart{thin}{small}\">\n", figure);
    try lanechart.render(w, .{
        .aria = aria,
        .a = x.name,
        .b = y.name,
        .band = bands[0..last],
        .line = line[0..last],
        .prev = prev_line[0..prev_last],
        .tips = unit,
        .width = if (small) 400 else 640,
        .height = if (small) 280 else 250,
    });
    if (!small) try caption(w, v, base, if (prev_last >= 2) prev else null, when, lane);
    try tpl.renderPart(w, "</figure>\n", .{});
}

/// What the marks are, in one line; the minutes' numbers are in the chart's hover titles
fn caption(w: *Writer, v: View, base: ?View, prev: ?Prev, when: []const u8, lane: []const u8) !void {
    const last = reach(v);
    const own = v.games() >= thin_games or base == null;
    try tpl.render(w,
        \\<figcaption><span class="k line"></span>average <span class="k band"></span>middle half of {band}{base}{ended}{prev} · games with timelines, {when}</figcaption>
        \\
    , .{
        .band = tpl.when(own, "games"),
        .base = tpl.when(!own, tpl.t("all {lane} lanes (few games here)", .{ .lane = lane })),
        .ended = tpl.when(last > surrender_minute, tpl.t(" <span class=\"k end\"></span>{m} min, after it only games still going", .{ .m = surrender_minute })),
        .prev = if (prev) |pv| tpl.t(" <span class=\"k prev\"></span>patch {patch}", .{ .patch = pv.patch }) else null,
        .when = when,
    });
}

/// Surrender opens at 15 minutes: before it nearly all games are still running
const surrender_minute = lanechart.surrender_minute;

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
        try lead(&aw.writer, .{ .curve = &cv, .flipped = case.flipped }, x);
        try std.testing.expectEqualStrings(case.want, aw.written());
    }

    // Clear only from minute 9 on
    for (minutes[0..8]) |*m| m.est[0].se = 1000;
    var aw: Writer.Allocating = .init(gpa);
    defer aw.deinit();
    try lead(&aw.writer, .{ .curve = &cv, .flipped = false }, x);
    try std.testing.expectEqualStrings(" Ahri is ahead from minute 9, about 800 gold by 14 minutes, then whoever is ahead wins 64% of games.", aw.written());

    // Within 2 SE at 14, or clear but about 100 gold: the number, no "since when"
    const small = [_]struct { e: curvesfile.Estimate, want: []const u8 }{
        .{ .e = .{ .mean = 30, .se = 20 }, .want = "Ahri is 30 gold ahead" },
        .{ .e = .{ .mean = -140, .se = 20 }, .want = "Ahri is 140 gold behind" },
        .{ .e = .{ .mean = 4, .se = 20 }, .want = "Ahri is level in gold" },
    };
    for (small) |case| {
        minutes[curvesfile.lane_minute - 1].est[0] = case.e;
        aw.clearRetainingCapacity();
        try lead(&aw.writer, .{ .curve = &cv, .flipped = false }, x);
        const want = try gpa.print(" {s} at 14 minutes, then whoever is ahead wins 64% of games.", .{case.want});
        defer gpa.free(want);
        try std.testing.expectEqualStrings(want, aw.written());
    }

    // Mostly baseline: the page's note says so, no verdict
    var thin_header = header;
    thin_header.own = 300;
    const thin_cv: curvesfile.Curve = .{ .header = &thin_header, .minutes = &minutes };
    aw.clearRetainingCapacity();
    try lead(&aw.writer, .{ .curve = &thin_cv, .flipped = false }, x);
    try std.testing.expectEqualStrings("", aw.written());
}
