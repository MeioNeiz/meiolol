//! AlertBand: a service's state in one line at the top of a page: ok, warn or down, a
//! glyph as the second cue beside the colour, the first problem as the text, "+n more"
//! when there are others, and a link to where it shows (a tab, a log)
const std = @import("std");
const tree = @import("tree.zig");
const Gallery = @import("gallery.zig").Gallery;
const phrase = @import("phrase.zig");
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "AlertBand";
pub const scope = .{".c-alert"};

pub const State = enum { ok, warn, down };

pub const Alert = struct {
    state: State,
    text: tree.Text,
    /// Problems beyond the one shown
    more: u32 = 0,
    link: ?struct { href: []const u8, label: tree.Text } = null,
};

const W = struct {
    pub const more = phrase.Phrase("+{n:count} more");
};

pub fn view(h: *H, a: Alert) N {
    return h.div(.{ .class = "c-alert", .data_state = a.state, .role = if (a.state == .ok) "status" else "alert" }, .{
        h.span(.{ .class = "g", .aria_hidden = true }, .{switch (a.state) {
            .ok => "✓",
            .warn => "!",
            .down => "✕",
        }}),
        h.span(.{ .class = "t" }, .{a.text}),
        if (a.more > 0) h.span(.{ .class = "more" }, .{W.more.with(h, .{ .n = a.more })}) else null,
        if (a.link) |l| h.a(.{ .href = l.href }, .{l.label}) else null,
    });
}

pub const css =
    \\@layer components {
    \\  .c-alert { display: flex; align-items: center; gap: var(--sp-2); min-height: var(--ctl);
    \\    padding: 0 var(--sp-3); border: 1px solid var(--good-line); border-radius: var(--r-l);
    \\    color: var(--text); font-size: var(--fs-s); }
    \\  .c-alert .g { flex: none; width: 1.2em; text-align: center; font-weight: var(--w-b); color: var(--good); }
    \\  .c-alert .t { flex: 1 1 auto; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    \\  .c-alert .more { flex: none; color: var(--muted); }
    \\  .c-alert a { flex: none; color: var(--accent); }
    \\  .c-alert[data-state="warn"] { border-color: var(--turn-line); }
    \\  .c-alert[data-state="warn"] .g { color: var(--turn); }
    \\  .c-alert[data-state="down"] { border-color: var(--bad-line); background: var(--them-bg); }
    \\  .c-alert[data-state="down"] .g { color: var(--lo3); }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.add("ok", view(h, .{ .state = .ok, .text = plain("All running") }));
    g.add("warn, more, link", view(h, .{
        .state = .warn,
        .text = plain("box disk: 12 days left at this rate"),
        .more = 2,
        .link = .{ .href = "#storage", .label = plain("Storage") },
    }));
    g.add("down", view(h, .{
        .state = .down,
        .text = plain("crawler silent for 25 min"),
        .link = .{ .href = "#crawler", .label = plain("Crawler") },
    }));
    g.add("long text", view(h, .{
        .state = .warn,
        .text = plain("render@b failed its health check three times; serving from render@a since the last deploy"),
        .more = 12,
    }));
}

test "glyph and role follow the state; more only when there are others" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    var out: std.Io.Writer.Allocating = .init(arena.allocator());
    try @import("html.zig").write(&t, view(&h, .{ .state = .ok, .text = plain("All running") }), &out.writer);
    try std.testing.expect(std.mem.find(u8, out.written(), "role=\"status\"") != null);
    try std.testing.expect(std.mem.find(u8, out.written(), "more") == null);
    out.clearRetainingCapacity();
    try @import("html.zig").write(&t, view(&h, .{ .state = .down, .text = plain("x"), .more = 3 }), &out.writer);
    const s = out.written();
    try std.testing.expect(std.mem.find(u8, s, "role=\"alert\"") != null);
    try std.testing.expect(std.mem.find(u8, s, "data-state=\"down\"") != null);
    try std.testing.expect(std.mem.find(u8, s, "+3 more") != null);
}
