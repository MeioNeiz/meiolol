//! ui-champtrends.wasm: the champion page's by patch, by game length, players, by rank and
//! first item done (ui.champpage.Trends). ui-champion.wasm adds its loader
//! (ui-champtrends.js) to the page, which calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const cp = ui.champpage;

pub const panic = zjb.panic;
pub const url_map: dom.UrlMap = .follow;

const gpa = std.heap.wasm_allocator;
const sel = "[data-island=champtrends]";

var data: cp.TrendsData = undefined;
var state: cp.Trends = undefined;
var server: cp.Trends = undefined;
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
    const stamp = dom.attrOf(root, "data-stamp");
    want = std.fmt.parseInt(u32, stamp, 10) catch return;
    dom.fetchStamped(src, stamp, 0, loaded);
}

fn loaded(_: i32, bytes: ?[]u8) void {
    const b = bytes orelse return dom.dom.warn("champtrends: no data");
    if (cp.stamp(b) != want) return dom.dom.warn("champtrends: the page and its data differ");
    data = ui.data.decode(gpa, cp.TrendsData, b) catch return dom.dom.warn("champtrends: bad data");
    server = .{ .data = &data, .root = root_path, .src = src, .stamp = want, .js = js, .wasm = wasm };
    server.files.base[0] = &data;
    server.fromUrl(.{ .role = dom.pageRole() });
    state = server;
    const i = dom.rt.add(cp.Trends, &state, &server, sel) catch return dom.dom.warn("champtrends: out of memory");
    dom.Loader(cp.Trends, cp.TrendsData, ui.champrank.More).start(&state, i);
}
