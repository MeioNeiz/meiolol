//! Build tool: `cssmin OUT FONT` writes the site's one stylesheet, minified (site/style.zig
//! bundle): minifying it at comptime cost a minute per compile
const std = @import("std");
const ui = @import("ui");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const a = init.arena.allocator();
    const args = try init.minimal.args.toSlice(a);
    if (args.len != 3) return error.Usage;
    const cwd = std.Io.Dir.cwd();
    const font = try cwd.readFileAlloc(io, args[2], a, .unlimited);
    // Root-relative, as style.font.path: the same text wherever the CSS is used
    const font_url = try a.print("/inter.{x:0>8}.woff2", .{std.hash.Fnv1a_32.hash(font)});
    const readable = try std.mem.concat(a, u8, &.{ ui.css.head, ui.css.font_face[0], font_url, ui.css.font_face[1], ui.css.join(ui.components) });
    try cwd.writeFile(io, .{ .sub_path = args[1], .data = ui.css.minify(try a.alloc(u8, readable.len), readable) });
}
