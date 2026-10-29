//! ui-champcharts.wasm: the champion page's charts under the trends
//! (ui.champpage.Charts). ui-champion.wasm adds its loader (ui-champcharts.js) to the
//! page, which calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const cp = ui.champpage;

pub const panic = zjb.panic;
pub const url_map: dom.UrlMap = .follow;

const gpa = std.heap.wasm_allocator;
const sel = "[data-island=champcharts]";

var data: cp.ChartsData = undefined;
var state: cp.Charts = undefined;
var server: cp.Charts = undefined;
var src: []const u8 = "";
var root_path: []const u8 = "";
var js: []const u8 = "";
var wasm: []const u8 = "";
var want: u32 = 0;

export fn main() void {
    dom.start();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    src = dom.attrOf(root, "data-src");
    root_path = dom.attrOf(root, "data-root");
    js = dom.attrOf(root, "data-js");
    wasm = dom.attrOf(root, "data-wasm");
    want = std.fmt.parseInt(u32, dom.attrOf(root, "data-stamp"), 10) catch return;
    dom.fetch(src, 0, loaded);
}

fn loaded(_: i32, bytes: ?[]u8) void {
    const b = bytes orelse return dom.dom.warn("champcharts: no data");
    if (cp.stamp(b) != want) return dom.dom.warn("champcharts: the page and its data differ");
    data = ui.data.decode(gpa, cp.ChartsData, b) catch return dom.dom.warn("champcharts: bad data");
    server = .{ .data = &data, .root = root_path, .src = src, .stamp = want, .js = js, .wasm = wasm };
    server.files.base[0] = &data;
    server.fromUrl(.{ .role = dom.pageRole() });
    state = server;
    const i = dom.rt.add(cp.Charts, &state, &server, sel) catch return dom.dom.warn("champcharts: out of memory");
    dom.Loader(cp.Charts, cp.ChartsData, cp.NoRank).start(&state, i);
}
