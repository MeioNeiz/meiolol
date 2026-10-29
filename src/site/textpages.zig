//! Fixed text pages on ui.textpage, their bodies markdown parsed at build time (ui.prose).
//! Wording follows docs/production-key.md and docs/concept.md ("Application wording")
const std = @import("std");
const ui = @import("ui");
const html = @import("html.zig");
const root = @import("root.zig");
const urls = ui.urls;
const Site = root.Site;

const Writer = std.Io.Writer;

const terms_updated = "12 October 2026";

const terms_md =
    \\- meiolol (this site and the desktop app) is free to use. Its statistics are
    \\  estimates from past games and come with no guarantee.
    \\- You remain bound by Riot Games' Terms of Service when you play. meiolol only
    \\  shows information; it never acts in the game client for you.
    \\- Do not scrape the site at a rate that disrupts it or resell its data.
    \\- The software is provided as is, without warranty of any kind.
    \\- These terms may change; the date above shows the latest version.
    \\
    \\{legal}
    \\
    \\Contact: [{contact}](mailto:{contact}).
;

const not_found_md = "[Home](/) · [Champions](/champions) · [Matchups](/matchups)";

/// `{name}` holes in `md` filled from `fills`, then parsed
fn doc(a: std.mem.Allocator, md: []const u8, fills: []const [2][]const u8) !ui.prose.Doc {
    var s = md;
    for (fills) |f| s = try std.mem.replaceOwned(u8, a, s, try std.fmt.allocPrint(a, "{{{s}}}", .{f[0]}), f[1]);
    return ui.prose.parse(a, s);
}

fn writeBody(h: *ui.H, w: *Writer, p: ui.textpage.TextPage) !void {
    const n = p.view(h);
    if (h.oom) return error.OutOfMemory;
    try ui.html.write(h.t, n, w);
}

/// The body of text page `at`, between html.head and foot; false for one not here
pub fn body(site: *const Site, w: *Writer, at: std.meta.Tag(urls.Page)) !bool {
    const a = site.arena;
    var t: ui.Tree = .{};
    var h: ui.H = .init(a, &t);
    try writeBody(&h, w, switch (at) {
        .terms => .{
            .title = "Terms of use",
            .sub = "Last updated " ++ terms_updated ++ ".",
            .body = try doc(a, terms_md, &.{ .{ "legal", html.boilerplate }, .{ "contact", site.opts.contact } }),
        },
        else => return false,
    });
    return true;
}

/// The site's 404 page, never indexed
pub fn notFound(site: *const Site, w: *Writer) !void {
    var p = try site.sharedPage("Page not found | meiolol", "No page at this address.", .none);
    p.index = false;
    try html.head(w, p);
    var t: ui.Tree = .{};
    var h: ui.H = .init(site.arena, &t);
    try writeBody(&h, w, .{
        .title = "Page not found",
        .lead = "There's no page at this address: it may have moved, or the link has a typo.",
        .body = try ui.prose.parse(site.arena, not_found_md),
    });
    try html.foot(w, p);
}
