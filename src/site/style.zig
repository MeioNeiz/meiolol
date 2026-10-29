//! The site's one stylesheet: the ui layers (tokens, base), today's style.css whole in
//! `legacy`, then the components (docs/plan/ui/README.md CSS). Linked by its hashed name
//! (assets.zig), and its font by the font's
const std = @import("std");
const ui = @import("ui");
const assets = @import("assets.zig");

pub const legacy = @embedFile("static/style.css");

pub const font = assets.built("inter.woff2", @embedFile("static/inter.woff2"));

const font_url = "url(\"inter.woff2\")";
const font_hashed = "url(\"" ++ font.path ++ "\")";

/// Minified by src/tools/cssmin.zig in the build; the dev server serves rebuild()'s,
/// readable
pub const bundle = @embedFile("style.min.css");

pub const file = assets.built("style.css", bundle);

/// The bundle around a legacy file read from disk (Options.static_dir, the dev server)
pub fn rebuild(a: std.mem.Allocator, old: []const u8) ![]const u8 {
    const fixed = try std.mem.replaceOwned(u8, a, old, font_url, font_hashed);
    return std.mem.concat(a, u8, &.{ ui.css.head, "@layer legacy {\n", fixed, "\n}\n", ui.css.join(ui.components) });
}

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

test "style.css is the bundle, in layers" {
    var layers: [ui.css.layers.len]u8 = undefined;
    try std.testing.expect(std.mem.startsWith(u8, bundle, minify(&layers, ui.css.layers)));
    try std.testing.expect(std.mem.find(u8, bundle, "@layer legacy{@font-face") != null);
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const readable = try rebuild(arena.allocator(), legacy);
    try std.testing.expectEqualStrings(bundle, minify(try arena.allocator().alloc(u8, readable.len), readable));
}
