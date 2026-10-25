//! The site's one stylesheet: the ui layers (tokens, base), today's style.css whole in
//! `legacy`, then the components (docs/plan/ui/README.md CSS). Linked by its hashed name
//! (assets.zig), and its font by the font's
const std = @import("std");
const ui = @import("ui");
const assets = @import("assets.zig");

pub const legacy = @embedFile("static/style.css");

pub const font = assets.hashed("inter.woff2", @embedFile("static/inter.woff2"));

const font_url = "url(\"inter.woff2\")";
const font_hashed = "url(\"" ++ font.path ++ "\")";

pub const bundle = join(legacy);

pub const file = assets.hashed("style.css", bundle);

fn join(comptime old: []const u8) []const u8 {
    const i = comptime std.mem.find(u8, old, font_url) orelse @compileError("style.css: no " ++ font_url);
    return ui.css.head ++ "@layer legacy {\n" ++ old[0..i] ++ font_hashed ++ old[i + font_url.len ..] ++
        "\n}\n" ++ ui.css.join(ui.components);
}

/// The bundle around a legacy file read from disk (Options.static_dir, the dev server)
pub fn rebuild(a: std.mem.Allocator, old: []const u8) ![]const u8 {
    const fixed = try std.mem.replaceOwned(u8, a, old, font_url, font_hashed);
    return std.mem.concat(a, u8, &.{ ui.css.head, "@layer legacy {\n", fixed, "\n}\n", ui.css.join(ui.components) });
}

test "style.css is the bundle, in layers" {
    try std.testing.expect(std.mem.startsWith(u8, bundle, ui.css.layers));
    try std.testing.expect(std.mem.find(u8, bundle, "@layer legacy {\n@font-face") != null);
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    try std.testing.expectEqualStrings(bundle, try rebuild(arena.allocator(), legacy));
}
