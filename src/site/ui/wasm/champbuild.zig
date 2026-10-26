//! ui-champbuild.wasm: the champion page's build (ui.champpage.Build). ui-champion.wasm
//! adds its loader (ui-champbuild.js) to the page, which calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const cp = ui.champpage;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;
const sel = "[data-island=champbuild]";

var data: cp.BuildData = undefined;
var state: cp.Build = undefined;
var server: cp.Build = undefined;
var src: []const u8 = "";
var js: []const u8 = "";
var wasm: []const u8 = "";
var want: u32 = 0;

export fn main() void {
    dom.start();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    src = dom.attrOf(root, "data-src");
    js = dom.attrOf(root, "data-js");
    wasm = dom.attrOf(root, "data-wasm");
    want = std.fmt.parseInt(u32, dom.attrOf(root, "data-stamp"), 10) catch return;
    dom.fetch(src, 0, loaded);
}

fn loaded(_: i32, bytes: ?[]u8) void {
    const b = bytes orelse return dom.dom.warn("champbuild: no data");
    if (cp.stamp(b) != want) return dom.dom.warn("champbuild: the page and its data differ");
    data = ui.data.decode(gpa, cp.BuildData, b) catch return dom.dom.warn("champbuild: bad data");
    // Each its own panels: the server's stay as rendered for hydration
    const sp = cp.panels(gpa, &data) catch return dom.dom.warn("champbuild: out of memory");
    const pp = cp.panels(gpa, &data) catch return dom.dom.warn("champbuild: out of memory");
    server = .{ .data = &data, .panels = sp, .src = src, .stamp = want, .js = js, .wasm = wasm };
    state = server;
    state.panels = pp;
    _ = dom.rt.add(cp.Build, &state, &server, sel) catch return dom.dom.warn("champbuild: out of memory");
}
