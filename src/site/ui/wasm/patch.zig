//! ui-patch.wasm: the patch page (ui.patchpage.Page) from its view's data file. zjb's
//! generated loader (ui-patch.js, `<script src data-wasm>`) calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const pp = ui.patchpage;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;

var data: pp.Data = undefined;
var state: pp.Page = undefined;
var server: pp.Page = undefined;
var base: []const u8 = "";
var src: []const u8 = "";
var want: u32 = 0;

export fn main() void {
    dom.start();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(pp.sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    base = dom.attrOf(root, "data-base");
    const stamp = dom.attrOf(root, "data-stamp");
    want = std.fmt.parseInt(u32, stamp, 10) catch return;
    src = dom.attrOf(root, "data-src");
    dom.fetchStamped(src, stamp, 0, loaded);
}

fn loaded(_: i32, bytes: ?[]u8) void {
    const b = bytes orelse return dom.dom.warn("patch: no data");
    // A page cached from an older build than its data: leave it as rendered
    if (pp.stamp(b) != want) return dom.dom.warn("patch: the page and its data differ");
    data = ui.data.decode(gpa, pp.Data, b) catch return dom.dom.warn("patch: bad data");
    const lines = pp.prepare(gpa, &data, base) catch return dom.dom.warn("patch: out of memory");
    server = .init(&data, lines);
    server.base = base;
    server.src = src;
    server.stamp = want;
    state = server;
    state.own(gpa) catch return dom.dom.warn("patch: out of memory");
    _ = dom.rt.add(pp.Page, &state, &server, pp.sel) catch return dom.dom.warn("patch: out of memory");
}
