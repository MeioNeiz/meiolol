//! ui-champmore.wasm: the champion page's matchups and the cards under them
//! (ui.champpage.More). ui-champion.wasm adds its loader (ui-champmore.js) to the page,
//! which calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const cp = ui.champpage;

pub const panic = zjb.panic;
pub const url_map: dom.UrlMap = .follow;

const gpa = std.heap.wasm_allocator;
const sel = "[data-island=champmore]";

var data: cp.MoreData = undefined;
var state: cp.More = undefined;
var server: cp.More = undefined;
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
    const b = bytes orelse return dom.dom.warn("champmore: no data");
    if (cp.stamp(b) != want) return dom.dom.warn("champmore: the page and its data differ");
    data = ui.data.decode(gpa, cp.MoreData, b) catch return dom.dom.warn("champmore: bad data");
    server = .{ .data = &data, .root = root_path, .src = src, .stamp = want, .js = js, .wasm = wasm };
    server.files.base[0] = &data;
    server.fromUrl(.{ .role = dom.pageRole() });
    state = server;
    const i = dom.rt.add(cp.More, &state, &server, sel) catch return dom.dom.warn("champmore: out of memory");
    dom.Loader(cp.More, cp.MoreData, ui.champrank.More).start(&state, i);
}
