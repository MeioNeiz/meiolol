//! PatchHead: the patch page's title, the pair it compares, with ‹ › to the older and
//! newer pair (disabled at either end), and a small line under it: how many games (so
//! far, on the newest pair) and a link to Riot's own notes
const std = @import("std");
const tree = @import("tree.zig");
const button = @import("button.zig");
const Gallery = @import("gallery.zig").Gallery;
const phrase = @import("phrase.zig");
const H = tree.H;
const N = tree.N;

pub const name = "PatchHead";
pub const scope = .{".c-phead"};

pub const Pair = struct {
    /// "16.21"
    cur: []const u8,
    prev: []const u8,
    href: ?[]const u8 = null,
};

pub const Opts = struct {
    pair: Pair,
    older: ?Pair = null,
    newer: ?Pair = null,
    games: u64,
    /// `pair.cur` is over: its games all in
    finished: bool = false,
    /// Riot's notes for `pair.cur`
    notes: ?[]const u8 = null,
};

const W = struct {
    const title = phrase.Phrase("Patch {c:text} vs {p:text}");
    const games = phrase.Phrase("{n:count} games so far");
    const games_done = phrase.Phrase("{n:count} games");
    const notes = phrase.plain("official notes ↗");
    const no_older = phrase.plain("no older patch");
    const no_newer = phrase.plain("no newer patch");
};

pub fn view(h: *H, o: Opts) N {
    return h.el(.header, .{ .class = "c-phead" }, .{
        h.div(.{ .class = "t" }, .{
            nav(h, o.older, "‹", W.no_older),
            h.el(.h1, .{}, .{W.title.with(h, .{ .c = o.pair.cur, .p = o.pair.prev })}),
            nav(h, o.newer, "›", W.no_newer),
        }),
        h.p(.{ .class = "m" }, .{
            if (o.finished) W.games_done.with(h, .{ .n = o.games }) else W.games.with(h, .{ .n = o.games }),
            if (o.notes != null) h.span(.{ .class = "sep", .aria_hidden = true }, .{"·"}) else null,
            if (o.notes) |href| h.a(.{ .href = href, .rel = "noopener", .target = "_blank" }, .{W.notes}) else null,
        }),
    });
}

/// No pair, or one without a page: disabled
fn nav(h: *H, p: ?Pair, glyph: []const u8, none: tree.Text) N {
    if (p) |to| if (to.href) |href| return button.view(h, .{ .v = .icon, .s = .s, .href = href, .label = W.title.with(h, .{ .c = to.cur, .p = to.prev }) }, .{glyph});
    return button.view(h, .{ .v = .icon, .s = .s, .disabled = true, .label = none }, .{glyph});
}

pub const css =
    \\@layer components {
    \\  .c-phead { display: grid; gap: 4px; min-width: 0; }
    \\  .c-phead .t { display: flex; align-items: center; gap: 8px; min-width: 0; }
    \\  .c-phead h1 { margin: 0; font-size: var(--fs-xl); font-weight: var(--w-b); min-width: 0; }
    \\  .c-phead .m { margin: 0; font-size: var(--fs-s); color: var(--faint); }
    \\  .c-phead .sep { margin: 0 6px; }
    \\  .c-phead a { color: var(--t2); }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.add("newest pair", view(h, .{
        .pair = .{ .cur = "16.21", .prev = "16.20" },
        .older = .{ .cur = "16.20", .prev = "16.19", .href = "patches/16.20-16.19.html" },
        .games = 79549,
        .notes = "https://www.leagueoflegends.com/en-gb/news/game-updates/",
    }));
    g.add("oldest pair", view(h, .{
        .pair = .{ .cur = "16.19", .prev = "16.18" },
        .newer = .{ .cur = "16.20", .prev = "16.19", .href = "patches/16.20-16.19.html" },
        .games = 412003,
        .finished = true,
    }));
}

test "ends without a page are disabled" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    const n = view(&h, .{ .pair = .{ .cur = "16.21", .prev = "16.20" }, .older = .{ .cur = "16.20", .prev = "16.19" }, .games = 5 });
    var out: std.Io.Writer.Allocating = .init(arena.allocator());
    try @import("html.zig").write(&t, n, &out.writer);
    const s = out.written();
    try std.testing.expectEqual(@as(usize, 2), std.mem.count(u8, s, "disabled"));
    try std.testing.expect(std.mem.find(u8, s, "href") == null);
}

test "a finished pair's games without so far" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    const n = view(&h, .{ .pair = .{ .cur = "16.20", .prev = "16.19" }, .games = 5, .finished = true });
    var out: std.Io.Writer.Allocating = .init(arena.allocator());
    try @import("html.zig").write(&t, n, &out.writer);
    try std.testing.expect(std.mem.find(u8, out.written(), "5 games") != null);
    try std.testing.expect(std.mem.find(u8, out.written(), "so far") == null);
}
