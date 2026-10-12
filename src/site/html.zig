//! HTML helpers: escaping and the layout every page shares.

const std = @import("std");
const Writer = std.Io.Writer;
pub const tpl = @import("tpl.zig");

pub const product = "meiolol";

/// Riot requires this on every page (docs/production-key.md)
pub const boilerplate = product ++ " isn't endorsed by Riot Games and doesn't reflect the " ++
    "views or opinions of Riot Games or anyone officially involved in producing or " ++
    "managing Riot Games properties. Riot Games, and all associated properties are " ++
    "trademarks or registered trademarks of Riot Games, Inc.";

pub const esc = tpl.esc;

/// Riot: a personal key may not serve the public while a production key is in review
const preview_banner =
    \\<div class="preview"><div class="wrap">Preview: this site is in review for a Riot
    \\Games production API key and is not yet open to the public.</div></div>
    \\
;

pub const Nav = enum { your, matchups, daily, learn, pool, champions, method, none };

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
    /// Footer: "in EUW, last 30 days, 5123 games"
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

    pub const url = true;

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

pub fn head(w: *Writer, p: Page) Writer.Error!void {
    try tpl.renderPart(w,
        \\<!doctype html>
        \\<html lang="en">
        \\<head>
        \\<meta charset="utf-8">
        \\<meta name="viewport" content="width=device-width, initial-scale=1">
        \\<title>{title}</title>
        \\<meta name="description" content="{description}">
        \\<link rel="stylesheet" href="{css}">
        \\<link rel="icon" href="{icon}" type="image/svg+xml">
        \\{robots}{canonical}</head>
        \\<body>
        \\<header class="top"><div class="wrap">
        \\{brand}<nav>
        \\{items}</nav>
        \\{switches}{remember}{meio_view}</div></header>
        \\{banner}<main class="wrap">
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
        .brand = tpl.t("<a href=\"{href}\" class=\"brand\"{view}>{name}</a>\n", .{
            .href = Link{ .root = p.root, .path = "index.html" },
            .view = tpl.flag(p.view == null, "data-view"),
            .name = product,
        }),
        .items = tpl.each(&nav_items, p, navItem),
        .switches = tpl.when(p.counterparts != null, tpl.call(switches, .{p})),
        // Remembered so shared pages link back into this view
        .remember = if (p.view) |v| tpl.t(
            \\<script>try{localStorage.setItem("view","{dir}")}catch(e){}</script>
            \\
        , .{ .dir = tpl.trusted(v.dir()) }) else null,
        .meio_view = tpl.when(p.view == null, tpl.trusted(meio_view)),
        .banner = tpl.when(!p.public, tpl.trusted(preview_banner)),
    });
}

/// On shared and champion pages: moves data-view links into the last view visited;
/// meioView(v) again from the champion page's filters, which move between views
const meio_view =
    \\<script>function meioView(v){try{if(v==null)v=localStorage.getItem("view");else localStorage.setItem("view",v)}catch(e){}
    \\if(!["patch/","all/","all/patch/"].includes(v))v="";for(const a of document.querySelectorAll("a[data-view]")){
    \\const h=a.dataset.base??=a.getAttribute("href"),up=h.match(/^(\.\.\/)*/)[0];a.href=up+v+h.slice(up.length)}}meioView()</script>
    \\
;

const NavItem = struct { nav: Nav, path: []const u8, label: []const u8, in_view: bool };

const nav_items = [_]NavItem{
    .{ .nav = .your, .path = "your.html", .label = "Your games", .in_view = false },
    .{ .nav = .matchups, .path = "matchup/index.html", .label = "Matchups", .in_view = true },
    .{ .nav = .daily, .path = "daily.html", .label = "Daily Draft", .in_view = false },
    .{ .nav = .learn, .path = "learn.html", .label = "Learn", .in_view = false },
    .{ .nav = .pool, .path = "pool.html", .label = "Champion pool", .in_view = true },
    .{ .nav = .champions, .path = "champions.html", .label = "Champions", .in_view = true },
    .{ .nav = .method, .path = "method.html", .label = "Method", .in_view = false },
};

/// Pages in a view link within it; from a shared page (all at the site root), to the
/// default view's, moved by the header script into the last one visited
fn navItem(p: Page, w: *Writer, it: NavItem) Writer.Error!void {
    try tpl.render(w, "<a href=\"{href}\"{current}{view}>{label}</a>\n", .{
        .href = if (it.in_view) Link{ .root = p.root, .path = it.path } else toSite(p, it.path),
        .current = tpl.flag(it.nav == p.nav, "aria-current=\"page\""),
        .view = tpl.flag(it.in_view and p.view == null, "data-view"),
        .label = it.label,
    });
}

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

test "escape" {
    var buf: [64]u8 = undefined;
    var w: Writer = .fixed(&buf);
    try w.print("{f}", .{esc("Nunu & Willump <Kai'Sa>")});
    try std.testing.expectEqualStrings("Nunu &amp; Willump &lt;Kai&#39;Sa&gt;", w.buffered());
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
