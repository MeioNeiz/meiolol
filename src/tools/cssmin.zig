//! Build tool: `cssmin OUT LEGACY_CSS FONT` writes the site's one stylesheet, minified
//! (site/style.zig bundle): minifying it at comptime cost a minute per compile
const std = @import("std");
const ui = @import("ui");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const a = init.arena.allocator();
    const args = try init.minimal.args.toSlice(a);
    if (args.len != 4) return error.Usage;
    const cwd = std.Io.Dir.cwd();
    const legacy = try cwd.readFileAlloc(io, args[2], a, .unlimited);
    const font = try cwd.readFileAlloc(io, args[3], a, .unlimited);
    const font_url = try a.print("url(\"inter.{x:0>8}.woff2\")", .{std.hash.Fnv1a_32.hash(font)});
    const fixed = try std.mem.replaceOwned(u8, a, legacy, "url(\"inter.woff2\")", font_url);
    const readable = try std.mem.concat(a, u8, &.{ ui.css.head, "@layer legacy {\n", fixed, "\n}\n", ui.css.join(ui.components) });
    try cwd.writeFile(io, .{ .sub_path = args[1], .data = ui.css.minify(try a.alloc(u8, readable.len), readable) });
}
