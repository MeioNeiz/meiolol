//! Shots: pictures side by side, each at most its own size with its caption under it,
//! one a row on a phone (download's desktop app screenshots, in TextPage). The caption says
//! what the picture is, mock-up or real
const std = @import("std");
const tree = @import("tree.zig");
const Gallery = @import("gallery.zig").Gallery;
const H = tree.H;
const N = tree.N;

pub const name = "Shots";
pub const scope = .{".c-shots"};

pub const Shot = struct {
    src: []const u8,
    alt: []const u8,
    caption: []const u8,
    width: u16,
    height: u16,
};

pub fn view(h: *H, shots: []const Shot) N {
    var l = h.list();
    for (shots) |s| l.add(h.el(.figure, .{}, .{
        h.img(.{ .src = s.src, .alt = s.alt, .width = s.width, .height = s.height, .loading = "lazy" }),
        h.p(.{}, .{s.caption}),
    }));
    return h.div(.{ .class = "c-shots" }, .{l.done()});
}

pub const css =
    \\@layer components {
    \\  .c-shots { display: flex; flex-wrap: wrap; align-items: flex-start; gap: var(--sp-4); }
    \\  .c-shots > figure { margin: 0; flex: 1 1 14rem; max-width: 20rem; }
    \\  .c-shots img { display: block; width: 100%; height: auto; border: 1px solid var(--line); border-radius: var(--r-m); }
    \\  .c-shots p { margin: var(--sp-2) 0 0; color: var(--muted); font-size: var(--fs-s); }
    \\}
    \\
;

const pic = "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 3 4'%3E%3Crect width='3' height='4' fill='%23777'/%3E%3C/svg%3E";

pub fn gallery(g: *Gallery) void {
    const two = [_]Shot{
        .{ .src = pic, .alt = "The app at pick", .caption = "Mock-up: before your lane opponent picks, several options from your pool.", .width = 300, .height = 400 },
        .{ .src = pic, .alt = "The app after locks", .caption = "Mock-up: once you have picked, how your lane usually goes.", .width = 300, .height = 400 },
    };
    g.add("two, captions of different lengths", view(g.h, &two));
    g.add("one", view(g.h, two[0..1]));
}

test "a figure per shot, its picture sized and lazy, the caption under it" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    const shots = [_]Shot{.{ .src = "/x.webp", .alt = "Alt", .caption = "Mock-up: cap", .width = 3, .height = 4 }};
    var out: std.Io.Writer.Allocating = .init(a);
    try @import("html.zig").write(&t, view(&h, &shots), &out.writer);
    try std.testing.expect(!h.oom);
    try std.testing.expectEqualStrings("<div class=\"c-shots\"><figure><img loading=\"lazy\" src=\"/x.webp\" alt=\"Alt\" width=\"3\" height=\"4\"><p>Mock-up: cap</p></figure></div>", out.written());
}
