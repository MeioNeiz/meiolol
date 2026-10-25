//! The site's one stylesheet: the ui layers (tokens, base), today's style.css whole in
//! `legacy`, then the components (docs/plan/ui/README.md CSS). Served at /style.css and
//! linked as `style.css?v=<version>`: deploy/traffic.sh counts a /style.css fetch as a
//! person's page view, and the web loop's upload deletes what a build no longer writes
//! (an old hashed name would vanish while the old renderer still links it)
const std = @import("std");
const ui = @import("ui");

pub const legacy = @embedFile("static/style.css");

pub const bundle = join(legacy);

pub const version = ui.css.version(bundle);

pub const link = "style.css?v=" ++ version;

fn join(comptime old: []const u8) []const u8 {
    return ui.css.head ++ "@layer legacy {\n" ++ old ++ "\n}\n" ++ ui.css.join(ui.components);
}

/// The bundle around a legacy file read from disk (Options.static_dir, the dev server)
pub fn rebuild(a: std.mem.Allocator, old: []const u8) ![]const u8 {
    return std.mem.concat(a, u8, &.{ ui.css.head, "@layer legacy {\n", old, "\n}\n", ui.css.join(ui.components) });
}

test "style.css is the bundle, in layers" {
    try std.testing.expect(std.mem.startsWith(u8, bundle, ui.css.layers));
    try std.testing.expect(std.mem.find(u8, bundle, "@layer legacy {\n@font-face") != null);
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    try std.testing.expectEqualStrings(bundle, try rebuild(arena.allocator(), legacy));
}
