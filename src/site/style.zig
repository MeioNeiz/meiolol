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

/// Minified; the dev server serves rebuild()'s, readable
pub const bundle = blk: {
    const readable = join(legacy);
    @setEvalBranchQuota(readable.len * 40);
    var buf: [readable.len]u8 = undefined;
    const len = minify(&buf, readable).len;
    const out: [len]u8 = buf[0..len].*;
    break :blk &out;
};

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

/// Comments out, whitespace collapsed to one space and none around { } ; , or after a
/// colon, no ; before }. Strings as written. Other spaces stay: selectors and calc() need
/// them. `out` at least as long as `in`
pub fn minify(out: []u8, in: []const u8) []u8 {
    var n: usize = 0;
    var i: usize = 0;
    var space = false;
    while (i < in.len) {
        const c = in[i];
        if (c == '/' and i + 1 < in.len and in[i + 1] == '*') {
            i = if (std.mem.findPos(u8, in, i + 2, "*/")) |end| end + 2 else in.len;
            continue;
        }
        if (std.ascii.isWhitespace(c)) {
            space = true;
            i += 1;
            continue;
        }
        if (space and n > 0 and !tight(out[n - 1]) and out[n - 1] != ':' and !tight(c)) {
            out[n] = ' ';
            n += 1;
        }
        space = false;
        if (c == '}' and n > 0 and out[n - 1] == ';') n -= 1;
        out[n] = c;
        n += 1;
        i += 1;
        if (c == '"' or c == '\'') {
            while (i < in.len) {
                out[n] = in[i];
                n += 1;
                i += 1;
                if (in[i - 1] == '\\' and i < in.len) {
                    out[n] = in[i];
                    n += 1;
                    i += 1;
                } else if (in[i - 1] == c) break;
            }
        }
    }
    return out[0..n];
}

fn tight(c: u8) bool {
    return c == '{' or c == '}' or c == ';' or c == ',';
}

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
