//! /gallery in `meiolol dev`: ui.gallery's page, styled by every component's CSS (the
//! site's bundle ships only the components a page uses)
const std = @import("std");
const ui = @import("ui");
const style = @import("style.zig");

const font = ui.css.font_face[0] ++ style.font.path ++ ui.css.font_face[1];

pub const css = ui.css.head ++ font ++ ui.css.join(ui.all) ++ ui.gallery.css;

pub fn page(arena: std.mem.Allocator) ![]const u8 {
    var t: ui.Tree = .{};
    var h: ui.H = .init(arena, &t);
    const body = ui.gallery.page(&h, ui.all);
    if (h.oom) return error.OutOfMemory;
    var out: std.Io.Writer.Allocating = .init(arena);
    try out.writer.writeAll(
        \\<!doctype html><html lang="en"><head><meta charset="utf-8">
        \\<meta name="viewport" content="width=device-width, initial-scale=1">
        \\<title>Components | meiolol</title><link rel="stylesheet" href="gallery.css"></head>
        \\<body class="ui">
    );
    try ui.html.write(&t, body, &out.writer);
    try out.writer.writeAll("</body></html>\n");
    return out.written();
}

test page {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const p = try page(arena.allocator());
    try std.testing.expect(std.mem.find(u8, p, "id=\"c-btn\"") != null);
    try std.testing.expect(std.mem.find(u8, css, ".c-tip") != null);
}
