//! HTML helpers: escaping and the layout every page shares.

const std = @import("std");
const core = @import("core");
const Writer = std.Io.Writer;
pub const tpl = @import("tpl");

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

/// The site's stats views, as lolalytics' filters: EUW over the last 30 days at the site
/// root, the rest in directories. Stats pages exist in each, but champion pages: one per
/// champion at the site root, whose filters pick the view (View.query). Shared pages
/// (Daily Draft, Learn, legal: EUW, current patch) only at the site root
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

    /// Under the site root
    pub fn dir(v: View) []const u8 {
        return ([_][]const u8{ "", "patch/", "all/", "all/patch/" })[v.index()];
    }

    /// From this view's root to the site root
    pub fn up(v: View) []const u8 {
        return ([_][]const u8{ "", "../", "../", "../../" })[v.index()];
    }

    /// Picks this view on a champion page (one per champion, at the site root; the
    /// filter bar reads it). Raw: escape it in HTML
    pub fn query(v: View) []const u8 {
        return ([_][]const u8{ "", "?period=patch", "?region=all", "?region=all&period=patch" })[v.index()];
    }
};

pub const Page = struct {
    title: []const u8,
    description: []const u8,
    /// "" for pages at their view's root, "../" one directory down; links are relative
    /// so the site also works from disk
    root: []const u8 = "",
    /// View the page belongs to; null for shared pages and champion pages
    view: ?View = null,
    /// This page's counterpart in each view (View.index) for the switches, from the site
    /// root: usually the same path in that view's directory. Null: no switches. Without
    /// a view, the switches start on View.all[0] (champion pages: filters.js moves them)
    counterparts: ?[View.count][]const u8 = null,
    nav: Nav = .none,
    /// Current patch, for the period switch
    patch: []const u8,
    /// Footer: "in EUW, last 30 days, 5,123 games"
    data: []const u8,
    /// Preview: unlisted for search engines, with a banner saying so
    public: bool,
    /// Absolute URL search engines should file the page under (Options.origin); only
    /// written when public
    canonical: ?[]const u8 = null,
    /// False: noindex even when public (thin matchups, Options.index_min_games)
    index: bool = true,
};

/// A link to `path` under a root: for href and src holes
pub const Link = struct {
    root: []const u8,
    up: []const u8 = "",
    path: []const u8,

    pub fn render(l: Link, w: *Writer) Writer.Error!void {
        try w.writeAll(l.root);
        try w.writeAll(l.up);
        try w.writeAll(l.path);
    }
};

/// From the page to `path` under the site root (shared pages and assets)
fn toSite(p: Page, path: []const u8) Link {
    return .{ .root = p.root, .up = if (p.view) |v| v.up() else "", .path = path };
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
        \\<link rel="icon" href="{icon}" type="image/svg+xml">
        \\{robots}{canonical}</head>
        \\<body>
        \\<header class="top"><div class="wrap">
        \\{brand}<nav>
        \\{items}</nav>
        \\{look}{remember}{meio_view}{admin}</div></header>
        \\{subbar}{banner}<main class="wrap">
        \\
    , .{
        .title = p.title,
        .description = p.description,
        .css = toSite(p, "style.css"),
        .icon = toSite(p, "favicon.svg"),
        .robots = tpl.when(!p.public or !p.index, tpl.trusted("<meta name=\"robots\" content=\"noindex\">\n")),
        .canonical = if (p.public and p.index) if (p.canonical) |url|
            tpl.t("<link rel=\"canonical\" href=\"{url}\">\n", .{ .url = url })
        else
            null else null,
        .brand = tpl.t("<a href=\"{href}\" class=\"brand\"{view}>{logo}<span>{name}</span></a>\n", .{
            .href = Link{ .root = p.root, .path = "index.html" },
            .view = tpl.flag(p.view == null, "data-view"),
            .logo = tpl.trusted(logo),
            .name = product,
        }),
        .items = tpl.each(&nav_items, p, navItem),
        // static/search.js; without JS a Riot ID lookup
        .look = tpl.t(
            \\<form class="look" action="{your}" method="get" role="search"><input name="id" placeholder="Champion, matchup or Riot ID" aria-label="Search a champion, a matchup (Ahri vs Zed) or a Riot ID (Name#TAG)" autocomplete="off" spellcheck="false" required></form>
            \\<script src="{js}" data-site="{site}"{view} defer></script>
            \\
        , .{
            .your = toSite(p, "your.html"),
            .js = toSite(p, "search.js"),
            .site = toSite(p, ""),
            .view = if (p.view) |v| tpl.attr("data-view", v.dir()) else null,
        }),
        .subbar = tpl.when(p.nav.inChampions() or p.counterparts != null, tpl.call(subbar, .{p})),
        // Remembered so shared pages link back into this view
        .remember = if (p.view) |v| tpl.t(
            \\<script>try{localStorage.setItem("view","{dir}")}catch(e){}</script>
            \\
        , .{ .dir = tpl.trusted(v.dir()) }) else null,
        .meio_view = tpl.when(p.view == null, tpl.trusted(meio_view)),
        .admin = tpl.trusted(admin_link),
        .banner = tpl.when(!p.public, tpl.trusted(preview_banner)),
    });
}

/// Jacob's menu link to the admin Draft tester: the admin page (behind basic auth) stores
/// it in this origin's localStorage, so visitors' pages carry neither link nor admin path
const admin_link =
    \\<script>try{const l=JSON.parse(localStorage.getItem("admin-link"));if(l&&typeof l.href=="string"&&l.href.startsWith("/admin/")){const a=document.createElement("a");
    \\a.href=l.href;a.textContent=l.label;document.querySelector("header.top nav").append(a)}}catch(e){}</script>
    \\
;

/// On shared and champion pages: moves data-view links into the last view visited;
/// meioView(v) again from the champion page's filters, which move between views
const meio_view =
    \\<script>function meioView(v){try{if(v==null)v=localStorage.getItem("view");else localStorage.setItem("view",v)}catch(e){}
    \\if(!["patch/","all/","all/patch/"].includes(v))v="";for(const a of document.querySelectorAll("a[data-view]")){
    \\const h=a.dataset.base??=a.getAttribute("href"),up=h.match(/^(\.\.\/)*/)[0];a.href=up+v+h.slice(up.length)}}meioView()</script>
    \\
;

const NavItem = struct { nav: Nav, path: []const u8, label: []const u8, in_view: bool };

/// The menu: the player's own games first; the stats pages sit under Champions
const nav_items = [_]NavItem{
    .{ .nav = .your, .path = "your.html", .label = "Your games", .in_view = false },
    .{ .nav = .daily, .path = "daily.html", .label = "Daily Draft", .in_view = false },
    .{ .nav = .learn, .path = "learn.html", .label = "Learn", .in_view = false },
    .{ .nav = .champions, .path = "champions.html", .label = "Champions", .in_view = true },
};

/// Tabs on the pages under Champions
const champion_tabs = [_]NavItem{
    .{ .nav = .champions, .path = "champions.html", .label = "Champions", .in_view = true },
    .{ .nav = .matchups, .path = "matchup/index.html", .label = "Matchups", .in_view = true },
    .{ .nav = .patch, .path = "patch.html", .label = "Patch changes", .in_view = true },
    .{ .nav = .pool, .path = "pool.html", .label = "Champion pool", .in_view = true },
};

/// Pages in a view link within it; from a shared page (all at the site root), to the
/// default view's, moved by the header script into the last one visited
fn navItem(p: Page, w: *Writer, it: NavItem) Writer.Error!void {
    const here = it.nav == p.nav or (it.nav == .champions and p.nav.inChampions());
    try navLink(p, w, it, here);
}

fn tabItem(p: Page, w: *Writer, it: NavItem) Writer.Error!void {
    try navLink(p, w, it, it.nav == p.nav);
}

fn navLink(p: Page, w: *Writer, it: NavItem, here: bool) Writer.Error!void {
    try tpl.render(w, "<a href=\"{href}\"{current}{view}>{label}</a>\n", .{
        .href = if (it.in_view) Link{ .root = p.root, .path = it.path } else toSite(p, it.path),
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

/// Riot ID lookup forms: to Your games with the ID in the fragment, which never reaches
/// the server; without JS, the query (your.js moves it to the fragment)
pub const lookup_submit =
    \\ onsubmit="location.href=this.action+'#id='+encodeURIComponent(this.elements.namedItem('id').value.trim());return false"
;

/// The mark: a win chance line through its turning minute
pub const logo =
    \\<svg width="20" height="20" viewBox="0 0 32 32" aria-hidden="true"><rect width="32" height="32" rx="8" fill="#8b7cf6"/><path d="M6 21.5 11.5 14l5 4.5L26 7" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/><circle cx="16.5" cy="18.5" r="2.6" fill="#f5c451"/></svg>
;

/// Region and period switches; data-region, data-period: what filters.js sets on a click
fn switches(w: *Writer, p: Page) Writer.Error!void {
    const paths = p.counterparts.?;
    const v = p.view orelse View.all[0];
    try w.writeAll("<div class=\"filters\">\n");
    const groups = [_]struct { []const u8, [2]View, [2][2][]const u8 }{
        .{ "Region", .{ .{ .region = .euw, .period = v.period }, .{ .region = .all, .period = v.period } }, .{ .{ "EUW", "" }, .{ "All regions", "" } } },
        .{ "Period", .{ .{ .region = v.region, .period = .days30 }, .{ .region = v.region, .period = .patch } }, .{ .{ "30 days", "" }, .{ "Patch ", p.patch } } },
    };
    for (groups, 0..) |g, i| {
        try tpl.renderPart(w, "<nav class=\"switch\" aria-label=\"{label}\">", .{ .label = g[0] });
        for (g[1], g[2]) |to, label| {
            const here = to.index() == v.index();
            try tpl.render(w, "<a{current}{href} {data}=\"{value}\">{label}{patch}</a>", .{
                .current = tpl.flag(here, "aria-current=\"page\""),
                .href = tpl.when(!here, tpl.attr("href", toSite(p, paths[to.index()]))),
                .data = tpl.trusted(if (i == 0) "data-region" else "data-period"),
                .value = if (i == 0) @tagName(to.region) else @tagName(to.period),
                .label = label[0],
                .patch = label[1],
            });
        }
        try w.writeAll("</nav>\n");
    }
    try w.writeAll("</div>\n");
}

pub fn foot(w: *Writer, p: Page) Writer.Error!void {
    try tpl.renderPart(w,
        \\</main>
        \\<footer><div class="wrap">
        \\<p>Ranked solo/duo {data}. Updated daily.</p>
        \\<p><a href="{privacy}">Privacy</a> · <a href="{terms}">Terms</a> ·
        \\<a href="{method}">Method</a> · <a href="{download}">Desktop app</a></p>
        \\<p class="legal">{legal}</p>
        \\</div></footer>
        \\</body>
        \\</html>
        \\
    , .{
        .data = p.data,
        .privacy = toSite(p, "privacy.html"),
        .terms = toSite(p, "terms.html"),
        .method = toSite(p, "method.html"),
        .download = toSite(p, "download.html"),
        .legal = tpl.trusted(boilerplate),
    });
}

/// Minimum games selector, as on lolalytics (static/min-games.js): lists marked
/// data-min-list hide rows whose data-games is under the choice. From `strict` up a row
/// must also clear chance (data-clear="1"); 0 for never. Hidden without JS, so the page
/// must already render the `default` choice.
pub fn minGames(w: *Writer, root: []const u8, key: []const u8, choices: []const u32, default: u32, strict: u32) Writer.Error!void {
    try w.print("<p class=\"min-games\" hidden><label>Min games <select data-key=\"{s}\" data-strict=\"{d}\">", .{ key, strict });
    for (choices) |c| try w.print("<option{s}>{d}</option>", .{ if (c == default) " selected" else "", c });
    try w.print("</select></label></p>\n<script src=\"{s}min-games.js\" defer></script>\n", .{root});
}

test {
    _ = tpl;
}
