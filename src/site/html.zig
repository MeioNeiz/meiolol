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

pub const Nav = enum { matchups, daily, pool, champions, method, none };

pub const Page = struct {
    title: []const u8,
    description: []const u8,
    /// "" for pages at the root, "../" one directory down; links are relative so the
    /// site also works from disk
    root: []const u8 = "",
    nav: Nav = .none,
    /// Shown in the footer
    patch: []const u8,
    games: u32,
    /// Preview: unlisted for search engines, with a banner saying so
    public: bool,
};

pub fn head(w: *Writer, p: Page) Writer.Error!void {
    try w.print(
        \\<!doctype html>
        \\<html lang="en">
        \\<head>
        \\<meta charset="utf-8">
        \\<meta name="viewport" content="width=device-width, initial-scale=1">
        \\<title>{f}</title>
        \\<meta name="description" content="{f}">
        \\<link rel="stylesheet" href="{s}style.css">
        \\<link rel="icon" href="{s}favicon.svg" type="image/svg+xml">
        \\{s}</head>
        \\<body>
        \\<header class="top"><div class="wrap">
        \\<a class="brand" href="{s}index.html">{s}</a>
        \\<nav>
        \\
    , .{
        esc(p.title),
        esc(p.description),
        p.root,
        p.root,
        if (p.public) "" else "<meta name=\"robots\" content=\"noindex\">\n",
        p.root,
        product,
    });
    const items = [_]struct { Nav, []const u8, []const u8 }{
        .{ .matchups, "matchup/index.html", "Matchups" },
        .{ .daily, "daily.html", "Daily Draft" },
        .{ .pool, "pool.html", "Champion pool" },
        .{ .champions, "role/top.html", "Champions" },
        .{ .method, "method.html", "Method" },
    };
    for (items) |it| {
        try w.print("<a href=\"{s}{s}\"{s}>{s}</a>\n", .{
            p.root, it[1], if (it[0] == p.nav) " aria-current=\"page\"" else "", it[2],
        });
    }
    try w.writeAll("</nav>\n</div></header>\n");
    if (!p.public) try w.writeAll(preview_banner);
    try w.writeAll("<main class=\"wrap\">\n");
}

pub fn foot(w: *Writer, p: Page) Writer.Error!void {
    try w.print(
        \\</main>
        \\<footer><div class="wrap">
        \\<p>EUW ranked solo/duo, patch {s}, {d} games. Updated daily.</p>
        \\<p><a href="{s}privacy.html">Privacy</a> · <a href="{s}terms.html">Terms</a> ·
        \\<a href="{s}method.html">Method</a> · <a href="{s}download.html">Desktop app</a></p>
        \\<p class="legal">{s}</p>
        \\</div></footer>
        \\</body>
        \\</html>
        \\
    , .{ p.patch, p.games, p.root, p.root, p.root, p.root, boilerplate });
}

test "escape" {
    var buf: [64]u8 = undefined;
    var w: Writer = .fixed(&buf);
    try w.print("{f}", .{esc("Nunu & Willump <Kai'Sa>")});
    try std.testing.expectEqualStrings("Nunu &amp; Willump &lt;Kai&#39;Sa&gt;", w.buffered());
}
