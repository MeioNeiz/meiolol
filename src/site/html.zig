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

/// The site's region views: EUW at the site root, every region under all/. Stats pages
/// exist in both; shared pages (Daily Draft, Learn, legal) only at the site root
pub const Region = enum {
    euw,
    all,

    pub fn dir(r: Region) []const u8 {
        return switch (r) {
            .euw => "",
            .all => "all/",
        };
    }

    /// From this view's root to the site root
    pub fn up(r: Region) []const u8 {
        return switch (r) {
            .euw => "",
            .all => "../",
        };
    }

    /// "ranked solo/duo {in}"
    pub fn in(r: Region) []const u8 {
        return switch (r) {
            .euw => "in EUW",
            .all => "across all regions",
        };
    }
};

pub const Page = struct {
    title: []const u8,
    description: []const u8,
    /// "" for pages at their view's root, "../" one directory down; links are relative
    /// so the site also works from disk
    root: []const u8 = "",
    /// Region view the page belongs to; null for shared pages
    region: ?Region = null,
    /// The other view's page for the region switch, usually the same path; null for none
    switch_path: ?[]const u8 = null,
    nav: Nav = .none,
    /// Shown in the footer
    patch: []const u8,
    games: u32,
    /// Preview: unlisted for search engines, with a banner saying so
    public: bool,
};

pub fn head(w: *Writer, p: Page) Writer.Error!void {
    const up = if (p.region) |r| r.up() else "";
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
        .{ .champions, "role/top.html", "Champions", true },
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
    if (p.region) |r| {
        if (p.switch_path) |other| {
            try w.writeAll("<nav class=\"region\" aria-label=\"Region\">");
            for ([_]Region{ .euw, .all }, [_][]const u8{ "EUW", "All regions" }) |to, label| {
                if (to == r) {
                    try w.print("<a aria-current=\"page\">{s}</a>", .{label});
                } else {
                    try w.print("<a href=\"{s}{s}{s}{s}\">{s}</a>", .{ p.root, up, to.dir(), other, label });
                }
            }
            try w.writeAll("</nav>\n");
        }
        // Remembered so shared pages link back into this view
        try w.print("<script>try{{localStorage.setItem(\"region\",\"{t}\")}}catch(e){{}}</script>\n", .{r});
    } else {
        try w.writeAll(
            \\<script>try{if(localStorage.getItem("region")==="all")for(const a of
            \\document.querySelectorAll("a[data-all]"))a.href=a.dataset.all}catch(e){}</script>
            \\
        );
    }
    try w.writeAll("</div></header>\n");
    if (!p.public) try w.writeAll(preview_banner);
    try w.writeAll("<main class=\"wrap\">\n");
}

/// Opens a link to `path` in the page's view; from a shared page, to EUW's, switched
/// to all/ by the header script when that view was the last one visited
fn viewLink(w: *Writer, p: Page, path: []const u8, attrs: []const u8) Writer.Error!void {
    try w.print("<a href=\"{s}{s}\"{s}", .{ p.root, path, attrs });
    if (p.region == null) try w.print(" data-all=\"{s}all/{s}\"", .{ p.root, path });
    try w.writeAll(">");
}

pub fn foot(w: *Writer, p: Page) Writer.Error!void {
    const up = if (p.region) |r| r.up() else "";
    try w.print(
        \\</main>
        \\<footer><div class="wrap">
        \\<p>Ranked solo/duo {s}, patch {s}, {d} games. Updated daily.</p>
        \\<p><a href="{s}{s}privacy.html">Privacy</a> · <a href="{s}{s}terms.html">Terms</a> ·
        \\<a href="{s}{s}method.html">Method</a> · <a href="{s}{s}download.html">Desktop app</a></p>
        \\<p class="legal">{s}</p>
        \\</div></footer>
        \\</body>
        \\</html>
        \\
    , .{
        (p.region orelse Region.euw).in(), p.patch, p.games, p.root, up, p.root, up, p.root, up, p.root, up,
        boilerplate,
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
