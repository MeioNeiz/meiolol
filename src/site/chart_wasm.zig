//! The lane chart (lanechart.zig) in the browser, so Your games (static/your.js) draws
//! with the same code as the matchup pages. JS writes a chart to `input()` and calls
//! `render(len)`; the SVG is at `output()`, as long as `render` returns. Names in it are
//! escaped by tpl, so the page may set it as markup.
//!
//! Input, little-endian: six u32 lengths (aria, a, b in bytes; band, line, you in
//! minutes), then band as low, high i32 pairs, line and you as i32, then the UTF-8 of
//! aria, a and b. No JSON: std.json was most of the module's size.

const std = @import("std");
const lanechart = @import("lanechart.zig");

const max_minutes = 120;

var in_buf: [6 * 4 + 4 * 4 * max_minutes + 1024]u8 align(4) = undefined;
var out_buf: [64 * 1024]u8 = undefined;

export fn input() [*]u8 {
    return &in_buf;
}

export fn output() [*]const u8 {
    return &out_buf;
}

/// SVG length; 0 when the input is malformed, there are under 2 minutes, or the SVG
/// doesn't fit
export fn render(len: usize) usize {
    const c = parse(in_buf[0..@min(len, in_buf.len)]) orelse return 0;
    var w: std.Io.Writer = .fixed(&out_buf);
    lanechart.render(&w, c) catch return 0;
    return w.end;
}

var band: [max_minutes][2]i32 = undefined;
var line: [max_minutes]i32 = undefined;
var you: [max_minutes]i32 = undefined;

fn parse(in: []const u8) ?lanechart.Chart {
    if (in.len < 24) return null;
    var lens: [6]u32 = undefined;
    for (&lens, 0..) |*l, i| l.* = std.mem.readInt(u32, in[4 * i ..][0..4], .little);
    if (lens[3] > max_minutes or lens[4] > max_minutes or lens[5] > max_minutes) return null;
    var at: usize = 24;
    const words = 2 * lens[3] + lens[4] + lens[5];
    const text = lens[0] + lens[1] + lens[2];
    if (in.len != at + 4 * words + text) return null;
    const int = struct {
        fn f(bytes: []const u8, i: *usize) i32 {
            defer i.* += 4;
            return std.mem.readInt(i32, bytes[i.*..][0..4], .little);
        }
    }.f;
    for (band[0..lens[3]]) |*b| b.* = .{ int(in, &at), int(in, &at) };
    for (line[0..lens[4]]) |*v| v.* = int(in, &at);
    for (you[0..lens[5]]) |*v| v.* = int(in, &at);
    const aria = in[at..][0..lens[0]];
    const a = in[at + lens[0] ..][0..lens[1]];
    const b = in[at + lens[0] + lens[1] ..][0..lens[2]];
    return .{ .aria = aria, .a = a, .b = b, .band = band[0..lens[3]], .line = line[0..lens[4]], .you = you[0..lens[5]] };
}
