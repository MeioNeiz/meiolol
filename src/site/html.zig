//! HTML helpers: escaping and the layout every page shares.

const std = @import("std");
const Writer = std.Io.Writer;

pub const product = "meiolol";

/// Riot requires this on every page (docs/production-key.md)
pub const boilerplate = product ++ " isn't endorsed by Riot Games and doesn't reflect the " ++
    "views or opinions of Riot Games or anyone officially involved in producing or " ++
    "managing Riot Games properties. Riot Games, and all associated properties are " ++
    "trademarks or registered trademarks of Riot Games, Inc.";

pub fn esc(s: []const u8) std.fmt.Alt([]const u8, writeEscaped) {
    return .{ .data = s };
}

fn writeEscaped(s: []const u8, w: *Writer) Writer.Error!void {
    var start: usize = 0;
    for (s, 0..) |ch, i| {
        const entity: []const u8 = switch (ch) {
            '&' => "&amp;",
            '<' => "&lt;",
            '>' => "&gt;",
            '"' => "&quot;",
            '\'' => "&#39;",
            else => continue,
        };
        try w.writeAll(s[start..i]);
        try w.writeAll(entity);
        start = i + 1;
    }
    try w.writeAll(s[start..]);
}

/// Riot: a personal key may not serve the public while a production key is in review
const preview_banner =
    \\<div class="preview"><div class="wrap">Preview: this site is in review for a Riot
    \\Games production API key and is not yet open to the public.</div></div>
    \\
;

pub const Nav = enum { matchups, daily, learn, pool, champions, method, none };

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
};

pub fn head(w: *Writer, p: Page) Writer.Error!void {
    const up = if (p.view) |v| v.up() else "";
    try w.print(
        \\<!doctype html>
        \\<html lang="en">
        \\<head>
        \\<meta charset="utf-8">
        \\<meta name="viewport" content="width=device-width, initial-scale=1">
        \\<title>{f}</title>
        \\<meta name="description" content="{f}">
        \\<link rel="stylesheet" href="{s}{s}style.css">
        \\<link rel="icon" href="{s}{s}favicon.svg" type="image/svg+xml">
        \\{s}</head>
        \\<body>
        \\<header class="top"><div class="wrap">
        \\
    , .{
        esc(p.title),
        esc(p.description),
        p.root,
        up,
        p.root,
        up,
        if (p.public) "" else "<meta name=\"robots\" content=\"noindex\">\n",
    });
    try viewLink(w, p, "index.html", " class=\"brand\"");
    try w.print("{s}</a>\n<nav>\n", .{product});
    const items = [_]struct { Nav, []const u8, []const u8, bool }{
        .{ .matchups, "matchup/index.html", "Matchups", true },
        .{ .daily, "daily.html", "Daily Draft", false },
        .{ .learn, "learn.html", "Learn", false },
        .{ .pool, "pool.html", "Champion pool", true },
        .{ .champions, "champions.html", "Champions", true },
        .{ .method, "method.html", "Method", false },
    };
    for (items) |it| {
        const current = if (it[0] == p.nav) " aria-current=\"page\"" else "";
        if (it[3]) {
            try viewLink(w, p, it[1], current);
        } else {
            try w.print("<a href=\"{s}{s}{s}\"{s}>", .{ p.root, up, it[1], current });
        }
        try w.print("{s}</a>\n", .{it[2]});
    }
    try w.writeAll("</nav>\n");
    if (p.counterparts) |paths| {
        const v = p.view orelse View.all[0];
        try w.writeAll("<div class=\"filters\">\n");
        // Labels as two parts: "Patch " ++ p.patch. data-region, data-period: what
        // filters.js sets on a click
        const switches = [_]struct { []const u8, [2]View, [2][2][]const u8 }{
            .{ "Region", .{ .{ .region = .euw, .period = v.period }, .{ .region = .all, .period = v.period } }, .{ .{ "EUW", "" }, .{ "All regions", "" } } },
            .{ "Period", .{ .{ .region = v.region, .period = .days30 }, .{ .region = v.region, .period = .patch } }, .{ .{ "30 days", "" }, .{ "Patch ", p.patch } } },
        };
        for (switches, 0..) |sw, i| {
            try w.print("<nav class=\"switch\" aria-label=\"{s}\">", .{sw[0]});
            for (sw[1], sw[2]) |to, label| {
                const data = if (i == 0) "region" else "period";
                const value = if (i == 0) @tagName(to.region) else @tagName(to.period);
                if (to.index() == v.index()) {
                    try w.print("<a aria-current=\"page\" data-{s}=\"{s}\">{s}{s}</a>", .{ data, value, label[0], label[1] });
                } else {
                    try w.print("<a href=\"{s}{s}{f}\" data-{s}=\"{s}\">{s}{s}</a>", .{ p.root, up, esc(paths[to.index()]), data, value, label[0], label[1] });
                }
            }
            try w.writeAll("</nav>\n");
        }
        try w.writeAll("</div>\n");
    }
    if (p.view) |v| {
        // Remembered so shared pages link back into this view
        try w.print("<script>try{{localStorage.setItem(\"view\",\"{s}\")}}catch(e){{}}</script>\n", .{v.dir()});
    } else {
        // meioView(v) again from the champion page's filters, which move between views
        try w.writeAll(
            \\<script>function meioView(v){try{if(v==null)v=localStorage.getItem("view");else localStorage.setItem("view",v)}catch(e){}
            \\if(!["patch/","all/","all/patch/"].includes(v))v="";for(const a of document.querySelectorAll("a[data-view]")){
            \\const h=a.dataset.base??=a.getAttribute("href"),up=h.match(/^(\.\.\/)*/)[0];a.href=up+v+h.slice(up.length)}}meioView()</script>
            \\
        );
    }
    try w.writeAll("</div></header>\n");
    if (!p.public) try w.writeAll(preview_banner);
    try w.writeAll("<main class=\"wrap\">\n");
}

/// Opens a link to `path` in the page's view; from a shared page (all at the site
/// root), to the default view's, moved by the header script into the last one visited
fn viewLink(w: *Writer, p: Page, path: []const u8, attrs: []const u8) Writer.Error!void {
    try w.print("<a href=\"{s}{s}\"{s}{s}>", .{ p.root, path, attrs, if (p.view == null) " data-view" else "" });
}

pub fn foot(w: *Writer, p: Page) Writer.Error!void {
    const up = if (p.view) |v| v.up() else "";
    try w.print(
        \\</main>
        \\<footer><div class="wrap">
        \\<p>Ranked solo/duo {s}. Updated daily.</p>
        \\<p><a href="{s}{s}privacy.html">Privacy</a> · <a href="{s}{s}terms.html">Terms</a> ·
        \\<a href="{s}{s}method.html">Method</a> · <a href="{s}{s}download.html">Desktop app</a></p>
        \\<p class="legal">{s}</p>
        \\</div></footer>
        \\</body>
        \\</html>
        \\
    , .{ p.data, p.root, up, p.root, up, p.root, up, p.root, up, boilerplate });
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
