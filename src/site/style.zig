//! The site's one stylesheet: the ui layers (tokens, base), the font, then the components
//! (docs/plan/ui/README.md CSS). Linked by its hashed name (assets.zig), and its font by
//! the font's
const std = @import("std");
const ui = @import("ui");
const assets = @import("assets.zig");

pub const font = assets.built("inter.woff2", @embedFile("static/inter.woff2"));

/// Minified by src/tools/cssmin.zig in the build
pub const bundle = @embedFile("style.min.css");

pub const file = assets.built("style.css", bundle);

pub const minify = ui.css.minify;

test minify {
    const in =
        \\/* head */
        \\@layer a, b;
        \\.x > .y:hover , .z :is(.w) {
        \\  width: calc(100% - 2px); /* gap */
        \\  content: "a  ;  b";
        \\  font: 12px "x\" y";
        \\}
        \\
    ;
    var buf: [in.len]u8 = undefined;
    try std.testing.expectEqualStrings("@layer a,b;.x > .y:hover,.z :is(.w){width:calc(100% - 2px);content:\"a  ;  b\";font:12px \"x\\\" y\"}", minify(&buf, in));
}

test "style.css is the bundle, in layers, its font root-relative" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const readable = try std.mem.concat(a, u8, &.{ ui.css.head, ui.css.font_face[0], "/" ++ font.path, ui.css.font_face[1], ui.css.join(ui.components) });
    try std.testing.expectEqualStrings(minify(try a.alloc(u8, readable.len), readable), bundle);
}
