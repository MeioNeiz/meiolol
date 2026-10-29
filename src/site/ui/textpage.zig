//! A page of running text: method, download, privacy, terms, the 404. Server side only, no
//! island; the body is a prose Doc parsed from the page's markdown. Its words are the
//! site's own policy and help text: held to no label or word budget, as Prose
const std = @import("std");
const tree = @import("tree.zig");
const prose = @import("prose.zig");
const Gallery = @import("gallery.zig").Gallery;
const H = tree.H;
const N = tree.N;

pub const name = "TextPage";
pub const scope = .{".c-textpage"};

pub const TextPage = struct {
    title: []const u8,
    /// Under the title, muted: "Last updated 12 October 2026."
    sub: []const u8 = "",
    /// The page's point in a sentence, bigger than the body
    lead: []const u8 = "",
    body: prose.Doc = .{ .blocks = &.{} },
    /// After the body: what the page writer builds in code (the method page's table)
    extra: N = .none,

    pub fn view(p: TextPage, h: *H) N {
        return h.div(.{ .class = "c-textpage", .data_prose = {} }, .{
            h.el(.h1, .{}, .{p.title}),
            if (p.sub.len > 0) h.p(.{ .class = "sub" }, .{p.sub}) else null,
            if (p.lead.len > 0) h.p(.{ .class = "lead" }, .{p.lead}) else null,
            if (p.body.blocks.len > 0) prose.view(h, p.body, .{ .id_prefix = "" }) else null,
            p.extra,
        });
    }
};

pub const css =
    \\@layer components {
    \\  .c-textpage { display: grid; gap: var(--sp-3); max-width: 72ch; }
    \\  .c-textpage > h1 { margin: 0; font-size: var(--fs-l); line-height: var(--lh-tight); }
    \\  .c-textpage > .sub { margin: calc(-1 * var(--sp-2)) 0 0; color: var(--muted); font-size: var(--fs-xs); }
    \\  .c-textpage > .lead { margin: 0; color: var(--text); font-size: var(--fs-m); line-height: var(--lh); }
    \\}
    \\
;

const demo_terms =
    \\- meiolol is free to use. Its statistics are estimates from past games.
    \\- Do not scrape the site at a rate that disrupts it.
    \\
    \\Contact: [privacy@meio.lol](mailto:privacy@meio.lol). See the [privacy policy](/privacy#accounts).
;

fn demo(g: *Gallery, caption: []const u8, p: TextPage, src: []const u8) void {
    var q = p;
    q.body = prose.parse(g.h.mem, src) catch {
        g.h.oom = true;
        return;
    };
    g.add(caption, q.view(g.h));
}

pub fn gallery(g: *Gallery) void {
    demo(g, "terms: date line, bullets, links", .{ .title = "Terms of use", .sub = "Last updated 12 October 2026." }, demo_terms);
    demo(g, "404: lead and links", .{ .title = "Page not found", .lead = "There's no page at this address: it may have moved, or the link has a typo." }, "[Home](/) · [Champions](/champions) · [Matchups](/matchups)");
    demo(g, "title only", .{ .title = "Champ select helper" }, "");
}

const testing = std.testing;

test "title, date line, lead and body in order; nothing for what is empty" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    const p: TextPage = .{ .title = "Terms of use", .sub = "Last updated 1 May.", .lead = "Lead.", .body = try prose.parse(a, "Body [x](/y).") };
    var out: std.Io.Writer.Allocating = .init(a);
    try @import("html.zig").write(&t, p.view(&h), &out.writer);
    try testing.expect(!h.oom);
    const s = out.written();
    const order = [_][]const u8{ "<h1>Terms of use</h1>", "<p class=\"sub\">Last updated 1 May.</p>", "<p class=\"lead\">Lead.</p>", "<a href=\"/y\">x</a>" };
    var at: usize = 0;
    for (order) |w| at = (std.mem.findPos(u8, s, at, w) orelse return error.TestUnexpectedResult) + w.len;
    var t2: tree.Tree = .{};
    var h2: H = .init(a, &t2);
    out.clearRetainingCapacity();
    try @import("html.zig").write(&t2, (TextPage{ .title = "T" }).view(&h2), &out.writer);
    try testing.expect(std.mem.find(u8, out.written(), "class=\"sub\"") == null);
    try testing.expect(std.mem.find(u8, out.written(), "c-prose") == null);
}
