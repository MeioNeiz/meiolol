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

    /// Pages under Champions in the menu, with its tabs and the view picks
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
    /// This page's href in each view (View.index) for the subbar's picks: usually its URL
    /// with that view's query. Null: no picks
    counterparts: ?[View.count][]const u8 = null,
    nav: Nav = .none,
    /// Current patch, for the period pick
    patch: []const u8,
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
        .look = tpl.trusted(search_loader),
        .subbar = tpl.when(p.nav.inChampions() or p.counterparts != null, Subbar{ .p = p }),
        // Remembered so shared pages link back into this view
        .remember = if (p.view) |v| tpl.t(
            \\<script>try{localStorage.setItem("view","{dir}")}catch(e){}</script>
            \\
        , .{ .dir = tpl.trusted(v.query()) }) else null,
        .meio_view = tpl.when(p.view == null, tpl.trusted(meio_view)),
        .admin = tpl.trusted(admin_link),
        .banner = tpl.when(!p.public, Preview{}),
    });
}

/// ui.site's bar. Its search: ui.sitesearch's island; without JS a Riot ID lookup
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
        var search: ui.sitesearch.SiteSearch = .{
            .js = "/" ++ assets.sitesearch_js.path,
            .wasm = "/" ++ assets.sitesearch_wasm.path,
            .view_q = if (p.view) |v| v.query() else null,
        };
        const look = search.view(&h);
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

/// The header search's file (ui-sitesearch.js) on the box's first use, so a page that
/// never searches loads none of it; "/" focuses the box. A submit before the island runs
/// (window.meioSearch) that isn't a Riot ID waits for it: meioSearchGo, its first option
const search_loader =
    \\<script>{const f=document.querySelector("[data-island=search]");let on=false;const go=()=>{if(on||!f)return;on=true;const s=document.createElement("script");
    \\s.src=f.dataset.js;s.dataset.wasm=f.dataset.wasm;document.head.append(s)};f?.addEventListener("focusin",go);f?.addEventListener("pointerdown",go);
    \\f?.addEventListener("submit",e=>{if(window.meioSearch||f.querySelector("input").value.includes("#"))return;e.preventDefault();window.meioSearchGo=1;go()});
    \\addEventListener("keydown",e=>{if(!f||e.key!="/"||e.ctrlKey||e.metaKey||e.altKey||e.target.closest?.("input,textarea,select,[contenteditable]"))return;e.preventDefault();go();f.querySelector("input").focus()})}</script>
    \\
;

/// A menu link to the Draft tester for logins that opened it: the admin page (/admin) or the
/// private one (/private) stores it in this origin's localStorage, so visitors' pages carry
/// neither link nor path. Those browsers also load /private/pv.js (static/pv.js), the private
/// numbers, which nginx serves to private logins only
const admin_link =
    \\<script>try{const l=JSON.parse(localStorage.getItem("admin-link"));if(l&&typeof l.href=="string"&&/^\/(admin|private)[/#]/.test(l.href)){const a=document.createElement("a");
    \\a.href=l.href;a.textContent=l.label;document.querySelector("header .links").append(a);const s=document.createElement("script");s.src="/private/pv.js";document.head.append(s)}}catch(e){}</script>
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

/// Under the header on the Champions pages: the section's tabs and, with counterparts,
/// the view picks
const Subbar = struct {
    p: Page,

    pub fn render(x: Subbar, w: *Writer) Writer.Error!void {
        const p = x.p;
        var buf: [16 * 1024]u8 = undefined;
        var fba: std.heap.FixedBufferAllocator = .init(&buf);
        const a = fba.allocator();
        var t: ui.Tree = .{};
        var h: ui.H = .init(a, &t);
        var tabs: [champion_tabs.len]ui.site.Link = undefined;
        for (champion_tabs, &tabs) |it, *l| l.* = SiteHeader.link(a, p, it, it.nav == p.nav) catch return error.WriteFailed;
        t.root = ui.site.subbar(&h, .{
            .tabs = if (p.nav.inChampions()) &tabs else &.{},
            .picks = if (p.counterparts) |c| picks(p, c) else null,
        });
        if (h.oom) return error.WriteFailed;
        try ui.html.write(&t, t.root, w);
        try w.writeByte('\n');
    }

    fn picks(p: Page, c: [View.count][]const u8) ui.site.Picks {
        const v = p.view orelse View.all[0];
        const at = struct {
            fn f(cs: [View.count][]const u8, cur: View, to: View) ui.site.Pick {
                return .{ .href = cs[to.index()], .current = to.index() == cur.index() };
            }
        }.f;
        return .{
            .home = platformName(p.home),
            .region = .{ at(c, v, .{ .region = .euw, .period = v.period }), at(c, v, .{ .region = .all, .period = v.period }) },
            .period = .{ at(c, v, .{ .region = v.region, .period = .days30 }), at(c, v, .{ .region = v.region, .period = .patch }) },
            .patch = p.patch,
            .rank_off = p.rank_off,
        };
    }
};

/// Rank picks: tier index as filters.zig tiers ("" all games: the crawl samples
/// Platinum IV+ players, so its lobbies are Platinum+); higher tiers are too thin to offer
pub const ranks = [_][2][]const u8{ .{ "", "Plat+" }, .{ "5", "Emerald+" }, .{ "6", "Diamond+" }, .{ "7", "Master+" } };

/// "EUW1" -> "EUW", "EUN1" -> "EUNE"
pub fn platformName(p: []const u8) []const u8 {
    const names = [_][2][]const u8{ .{ "EUN1", "EUNE" }, .{ "LA1", "LAN" }, .{ "LA2", "LAS" }, .{ "OC1", "OCE" } };
    for (names) |n| if (std.mem.eql(u8, n[0], p)) return n[1];
    return std.mem.trimEnd(u8, p, "0123456789");
}

pub fn foot(w: *Writer, p: Page) Writer.Error!void {
    try w.writeAll("</main>\n");
    var buf: [8 * 1024]u8 = undefined;
    var fba: std.heap.FixedBufferAllocator = .init(&buf);
    var t: ui.Tree = .{};
    var h: ui.H = .init(fba.allocator(), &t);
    t.root = ui.site.foot(&h, .{ .data = p.data, .legal = boilerplate });
    if (h.oom) return error.WriteFailed;
    try ui.html.write(&t, t.root, w);
    try w.writeAll("\n</body>\n</html>\n");
}

/// ui.site's preview strip, on every page until the production key
const Preview = struct {
    pub fn render(_: Preview, w: *Writer) Writer.Error!void {
        var buf: [2 * 1024]u8 = undefined;
        var fba: std.heap.FixedBufferAllocator = .init(&buf);
        var t: ui.Tree = .{};
        var h: ui.H = .init(fba.allocator(), &t);
        t.root = ui.site.preview(&h);
        if (h.oom) return error.WriteFailed;
        try ui.html.write(&t, t.root, w);
        try w.writeByte('\n');
    }
};

test {
    _ = tpl;
}
