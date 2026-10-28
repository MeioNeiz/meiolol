//! HTML helpers: escaping and the layout every page shares.

const std = @import("std");
const core = @import("core");
const Writer = std.Io.Writer;
pub const tpl = @import("tpl");
const style = @import("style.zig");
const assets = @import("assets.zig");
const ui = @import("ui");

pub const product = "meiolol";

pub const boilerplate = core.boilerplate;

/// Riot: a personal key may not serve the public while a production key is in review
const preview_banner =
    \\<div class="preview"><div class="wrap">Preview: this site is in review for a Riot
    \\Games production API key and is not yet open to the public.</div></div>
    \\
;

pub const Nav = enum {
    home,
    your,
    matchups,
    patch,
    daily,
    learn,
    pool,
    champions,
    method,
    none,

    /// Pages under Champions in the menu, with its tabs and the stats switches
    pub fn inChampions(n: Nav) bool {
        return n == .champions or n == .matchups or n == .patch or n == .pool;
    }
};

pub const Region = enum {
    euw,
    all,

    /// "ranked solo/duo {in}"
    pub fn in(r: Region) []const u8 {
        return switch (r) {
            .euw => "in EUW",
            .all => "across all regions",
        };
    }
};

pub const Period = enum { days30, patch };

/// The site's stats views, as lolalytics' filters: EUW over the last 30 days by default,
/// the rest picked by the URL's query (View.query; docs/plan/urls.md). Stats pages exist
/// in each, but champion pages: one per champion and role in the default view, whose
/// filters pick the view. Shared pages (Daily Draft, Learn, legal: EUW, current patch)
/// once
pub const View = struct {
    region: Region,
    period: Period,

    pub const all = [_]View{
        .{ .region = .euw, .period = .days30 },
        .{ .region = .euw, .period = .patch },
        .{ .region = .all, .period = .days30 },
        .{ .region = .all, .period = .patch },
    };
    pub const count = all.len;
    /// Where shared pages get their numbers
    pub const shared: View = all[1];

    pub fn index(v: View) usize {
        return 2 * @as(usize, @backingInt(v.region)) + @backingInt(v.period);
    }

    /// Its pages' and data's tree under the site root, never in a page's URL: nginx maps
    /// the query to it (deploy/nginx/meiolol.conf $meiolol_view)
    pub fn dir(v: View) []const u8 {
        return ui.urls.view_dirs[v.index()];
    }

    /// Picks this view: ui.urls.Data spelt, "" for the default. Raw: escape it in HTML
    pub fn query(v: View) []const u8 {
        return ui.urls.view_queries[v.index()];
    }
};

pub const Page = struct {
    title: []const u8,
    description: []const u8,
    /// View the page belongs to; null for shared pages and champion pages
    view: ?View = null,
    /// This page's href in each view (View.index) for the switches: usually its URL with
    /// that view's query. Null: no switches. Without a view, the switches start on
    /// View.all[0] (champion pages: filters.js moves them)
    counterparts: ?[View.count][]const u8 = null,
    nav: Nav = .none,
    /// Current patch, for the period switch
    patch: []const u8,
    /// Every platform crawled, for the region pick; champion pages offer them all
    regions: []const []const u8 = &.{},
    /// The platform of the root view (EUW)
    home: []const u8 = "EUW1",
    /// Footer: "in EUW, last 30 days, 5,123 games"
    data: []const u8,
    /// Preview: unlisted for search engines, with a banner saying so
    public: bool,
    /// Absolute URL search engines should file the page under (Options.origin); only
    /// written when public
    canonical: ?[]const u8 = null,
    /// False: noindex even when public (thin matchups, Options.index_min_games)
    index: bool = true,
    /// Why the rank picks past Plat+ are greyed, on pages with a view
    rank_off: []const u8 = "Champion pages and the champions board only",
};

/// `path` under the site root, root-relative: for href and src holes
pub const Link = struct {
    path: []const u8,

    pub fn render(l: Link, w: *Writer) Writer.Error!void {
        try w.writeByte('/');
        try w.writeAll(l.path);
    }
};

fn toSite(path: []const u8) Link {
    return .{ .path = path };
}

/// no-referrer: Your games has a Riot ID in its URL, and the access log keeps Referer
pub fn head(w: *Writer, p: Page) Writer.Error!void {
    try tpl.renderPart(w,
        \\<!doctype html>
        \\<html lang="en">
        \\<head>
        \\<meta charset="utf-8">
        \\<meta name="viewport" content="width=device-width, initial-scale=1">
        \\<meta name="referrer" content="no-referrer">
        \\<title>{title}</title>
        \\<meta name="description" content="{description}">
        \\<link rel="stylesheet" href="{css}">
        \\<link rel="stylesheet" href="{print}" media="print">
        \\<link rel="icon" href="{icon}" type="image/svg+xml">
        \\{robots}{canonical}</head>
        \\<body>
        \\{header}
        \\{look}{remember}{meio_view}{admin}
        \\{subbar}{banner}<main class="wrap">
        \\
    , .{
        .title = p.title,
        .description = p.description,
        .css = toSite(style.file.path),
        .print = toSite("print.css"),
        .icon = toSite("favicon.svg"),
        .robots = tpl.when(!p.public or !p.index, tpl.trusted("<meta name=\"robots\" content=\"noindex\">\n")),
        .canonical = if (p.public and p.index) if (p.canonical) |url|
            tpl.t("<link rel=\"canonical\" href=\"{url}\">\n", .{ .url = url })
        else
            null else null,
        .header = SiteHeader{ .p = p },
        // static/search.js
        .look = tpl.t(
            \\<script src="{js}"{view} defer></script>
            \\
        , .{
            .js = toSite(assets.search_js.path),
            .view = if (p.view) |v| tpl.attr("data-view", v.query()) else null,
        }),
        .subbar = tpl.when(p.nav.inChampions() or p.counterparts != null, tpl.call(subbar, .{p})),
        // Remembered so shared pages link back into this view
        .remember = if (p.view) |v| tpl.t(
            \\<script>try{localStorage.setItem("view","{dir}")}catch(e){}</script>
            \\
        , .{ .dir = tpl.trusted(v.query()) }) else null,
        .meio_view = tpl.when(p.view == null, tpl.trusted(meio_view)),
        .admin = tpl.trusted(admin_link),
        .banner = tpl.when(!p.public, tpl.trusted(preview_banner)),
    });
}

/// ui.site's bar. Its search: static/search.js; without JS a Riot ID lookup
const SiteHeader = struct {
    p: Page,

    pub fn render(x: SiteHeader, w: *Writer) Writer.Error!void {
        const p = x.p;
        var buf: [16 * 1024]u8 = undefined;
        var fba: std.heap.FixedBufferAllocator = .init(&buf);
        const a = fba.allocator();
        var t: ui.Tree = .{};
        var h: ui.H = .init(a, &t);
        var links: [nav_items.len]ui.site.Link = undefined;
        for (nav_items, &links) |it, *l| {
            const here = it.nav == p.nav or (it.nav == .champions and p.nav.inChampions());
            l.* = link(a, p, it, here) catch return error.WriteFailed;
        }
        var more: [champion_tabs.len - 1]ui.site.Link = undefined;
        for (champion_tabs[1..], &more) |it, *l| l.* = link(a, p, it, it.nav == p.nav) catch return error.WriteFailed;
        const look = h.el(.form, .{ .class = "look c-search", .action = "/your", .method = "get", .role = "search" }, .{
            h.input(.{
                .name = "id",
                .placeholder = "Champion, matchup or Riot ID",
                .aria_label = "Search a champion, a matchup (Ahri vs Zed) or a Riot ID (Name#TAG)",
                .autocomplete = "off",
                .spellcheck = "false",
                .required = true,
            }),
        });
        t.root = ui.site.view(&h, .{
            .home = if (p.view) |v| std.mem.concat(a, u8, &.{ "/", v.query() }) catch return error.WriteFailed else "/",
            .home_view = p.view == null,
            .links = &links,
            .more = &more,
            .search = look,
        });
        if (h.oom) return error.WriteFailed;
        try ui.html.write(&t, t.root, w);
    }

    /// Pages in a view link within it; from a shared page, to the default view's, moved
    /// by the header script into the last one visited
    fn link(a: std.mem.Allocator, p: Page, it: NavItem, here: bool) !ui.site.Link {
        return .{
            .label = .{ .s = it.label },
            .href = try navHref(a, p, it),
            .current = here,
            .view = it.in_view and p.view == null,
        };
    }
};

fn navHref(a: std.mem.Allocator, p: Page, it: NavItem) ![]const u8 {
    const q = if (it.in_view) if (p.view) |v| v.query() else "" else "";
    return std.mem.concat(a, u8, &.{ it.path, q });
}

/// A menu link to the Draft tester for logins that opened it: the admin page (/admin/) or the
/// private one (/p/) stores it in this origin's localStorage, so visitors' pages carry
/// neither link nor path. Those browsers also load /p/pv.js (static/pv.js), the private
/// numbers, which nginx serves to private logins only
const admin_link =
    \\<script>try{const l=JSON.parse(localStorage.getItem("admin-link"));if(l&&typeof l.href=="string"&&/^\/(admin|p)\//.test(l.href)){const a=document.createElement("a");
    \\a.href=l.href;a.textContent=l.label;document.querySelector("header .links").append(a);const s=document.createElement("script");s.src="/p/pv.js";document.head.append(s)}}catch(e){}</script>
    \\
;

/// On shared and champion pages: moves data-view links into the last view visited (its
/// query, View.query); meioView(v) again from the champion page's filters, which move
/// between views
const meio_view =
    \\<script>function meioView(v){try{if(v==null)v=localStorage.getItem("view");else localStorage.setItem("view",v)}catch(e){}
    \\if(!["?period=patch","?region=all","?region=all&period=patch"].includes(v))v="";for(const a of document.querySelectorAll("a[data-view]")){
    \\a.href=(a.dataset.base??=a.getAttribute("href"))+v}}meioView()</script>
    \\
;

const NavItem = struct { nav: Nav, path: []const u8, label: []const u8, in_view: bool };

/// The menu: the player's own games first; the stats pages sit under Champions
const nav_items = [_]NavItem{
    .{ .nav = .your, .path = "/your", .label = "Your games", .in_view = false },
    .{ .nav = .daily, .path = "/daily", .label = "Daily Draft", .in_view = false },
    .{ .nav = .learn, .path = "/learn", .label = "Learn", .in_view = false },
    .{ .nav = .champions, .path = "/champions", .label = "Champions", .in_view = true },
};

/// Tabs on the pages under Champions
const champion_tabs = [_]NavItem{
    .{ .nav = .champions, .path = "/champions", .label = "Champions", .in_view = true },
    .{ .nav = .matchups, .path = "/matchups", .label = "Matchups", .in_view = true },
    .{ .nav = .patch, .path = "/patch", .label = "Patch changes", .in_view = true },
    .{ .nav = .pool, .path = "/pool", .label = "Champion pool", .in_view = true },
};

fn tabItem(p: Page, w: *Writer, it: NavItem) Writer.Error!void {
    try navLink(p, w, it, it.nav == p.nav);
}

fn navLink(p: Page, w: *Writer, it: NavItem, here: bool) Writer.Error!void {
    var buf: [64]u8 = undefined;
    var fba: std.heap.FixedBufferAllocator = .init(&buf);
    try tpl.render(w, "<a href=\"{href}\"{current}{view}>{label}</a>\n", .{
        .href = navHref(fba.allocator(), p, it) catch return error.WriteFailed,
        .current = tpl.flag(here, "aria-current=\"page\""),
        .view = tpl.flag(it.in_view and p.view == null, "data-view"),
        .label = it.label,
    });
}

/// Under the header on stats pages: the section's tabs and the region and period switches
fn subbar(w: *Writer, p: Page) Writer.Error!void {
    try tpl.render(w,
        \\<div class="subbar"><div class="wrap">
        \\{tabs}{switches}</div></div>
        \\
    , .{
        .tabs = tpl.when(p.nav.inChampions(), tpl.t("<nav class=\"section\" aria-label=\"Champions\">\n{items}</nav>\n", .{
            .items = tpl.each(&champion_tabs, p, tabItem),
        })),
        .switches = tpl.when(p.counterparts != null, tpl.call(switches, .{p})),
    });
}

/// Rank picks: tier index as filters.zig tiers ("" all games: the crawl samples
/// Platinum IV+ players, so its lobbies are Platinum+); higher tiers are too thin to offer
pub const ranks = [_][2][]const u8{ .{ "", "Plat+" }, .{ "5", "Emerald+" }, .{ "6", "Diamond+" }, .{ "7", "Master+" } };

/// "EUW1" -> "EUW", "EUN1" -> "EUNE", as static/filters.js platformName
pub fn platformName(p: []const u8) []const u8 {
    const names = [_][2][]const u8{ .{ "EUN1", "EUNE" }, .{ "LA1", "LAN" }, .{ "LA2", "LAS" }, .{ "OC1", "OCE" } };
    for (names) |n| if (std.mem.eql(u8, n[0], p)) return n[1];
    return std.mem.trimEnd(u8, p, "0123456789");
}

/// Region, period and rank picks; data-region, data-period, data-rank: what filters.js
/// sets on a click. Champion pages (no view) take every pick; other pages only the
/// views', the rest greyed
fn switches(w: *Writer, p: Page) Writer.Error!void {
    const v = p.view orelse View.all[0];
    const live = p.view == null;
    try tpl.renderPart(w,
        \\<div class="filters">
        \\<details class="regions"><summary aria-label="Region">{region}</summary><div class="region-list">
        \\
    , .{ .region = if (v.region == .all) "All regions" else platformName(p.home) });
    const views = [_]struct { View, []const u8, []const u8 }{
        .{ .{ .region = .all, .period = v.period }, "all", "All regions" },
        .{ .{ .region = .euw, .period = v.period }, p.home, platformName(p.home) },
    };
    for (views) |e| try viewLink(w, p, e[0], v, "region", e[1], e[2], "");
    for (p.regions) |pl| {
        if (std.mem.eql(u8, pl, p.home)) continue;
        try pick(w, p, live, "region", pl, platformName(pl));
    }
    try w.writeAll("</div></details>\n<nav class=\"switch\" aria-label=\"Period\">");
    for ([_]Period{ .days30, .patch }) |pe| {
        const to: View = .{ .region = v.region, .period = pe };
        try viewLink(w, p, to, v, "period", @tagName(pe), if (pe == .days30) "30 days" else "Patch ", if (pe == .days30) "" else p.patch);
    }
    try w.writeAll("</nav>\n<nav class=\"switch\" aria-label=\"Rank\">");
    try w.writeAll("<a aria-current=\"page\" data-rank=\"\" title=\"Every game we crawl: Platinum IV+ players' lobbies\">Plat+</a>");
    for (ranks[1..]) |r| try pick(w, p, live, "rank", r[0], r[1]);
    try w.writeAll("</nav>\n</div>\n");
}

/// A pick no view has: on a champion page a link with it (filters.js takes the click),
/// elsewhere greyed
fn pick(w: *Writer, p: Page, live: bool, comptime key: []const u8, value: []const u8, label: []const u8) Writer.Error!void {
    if (live) {
        try tpl.render(w, "<a href=\"{to}?" ++ key ++ "={value}\" data-" ++ key ++ "=\"{value}\">{label}</a>", .{
            .to = p.counterparts.?[0],
            .value = value,
            .label = label,
        });
    } else {
        try tpl.render(w, "<a aria-disabled=\"true\" title=\"{why}\" data-" ++ key ++ "=\"{value}\">{label}</a>", .{
            .why = if (comptime std.mem.eql(u8, key, "rank")) p.rank_off else "Champion pages only",
            .value = value,
            .label = label,
        });
    }
}

/// A pick that is a view: a link to the page's counterpart there, current when it is `v`
fn viewLink(w: *Writer, p: Page, to: View, v: View, comptime key: []const u8, value: []const u8, label: []const u8, tail: []const u8) Writer.Error!void {
    const here = to.index() == v.index();
    try tpl.render(w, "<a{current}{href} data-" ++ key ++ "=\"{value}\">{label}{tail}</a>", .{
        .current = tpl.flag(here, "aria-current=\"page\""),
        .href = tpl.when(!here, tpl.attr("href", p.counterparts.?[to.index()])),
        .value = value,
        .label = label,
        .tail = tail,
    });
}

pub fn foot(w: *Writer, p: Page) Writer.Error!void {
    try tpl.renderPart(w,
        \\</main>
        \\<footer><div class="wrap">
        \\<p>Ranked solo/duo <span data-foot>{data}</span>. Updated daily.</p>
        \\<p><a href="{privacy}">Privacy</a> · <a href="{terms}">Terms</a> ·
        \\<a href="{method}">Method</a> · <a href="{download}">Desktop app</a></p>
        \\<p class="legal">{legal}</p>
        \\</div></footer>
        \\</body>
        \\</html>
        \\
    , .{
        .data = p.data,
        .privacy = "/privacy",
        .terms = "/terms",
        .method = "/method",
        .download = "/download",
        .legal = tpl.trusted(boilerplate),
    });
}

test {
    _ = tpl;
}
