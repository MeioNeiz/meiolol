//! ui-yourtime.wasm: the Your games page's Over time view (ui.yourtime.YourTime), with
//! its list from yoursrc.zig. ui-yourviews.wasm adds its loader (ui-yourtime.js) to the
//! page once the view shows, which calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const src = @import("yoursrc.zig");
const yt = ui.yourtime;

pub const panic = zjb.panic;

var page: yt.YourTime = undefined;
var page0: yt.YourTime = undefined;
var island: ?*ui.island.Island(yt.YourTime, dom.Dom) = null;

export fn main() void {
    dom.start();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(yt.sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    const handed = src.start(swapped) catch return dom.dom.warn("yourtime: no data");
    page0 = .{ .l = &src.list, .js = dom.attrOf(root, "data-js"), .wasm = dom.attrOf(root, "data-wasm") };
    page = page0;
    island = dom.rt.add(yt.YourTime, &page, &page0, yt.sel) catch return dom.dom.warn("yourtime: out of memory");
    page.tz_min = src.tzMin();
    island.?.render();
    if (handed) src.swap();
    // ui-yourviews' markTime
    root.call("setAttribute", .{ zjb.constString("data-live"), zjb.constString("") }, void);
    root.call("removeAttribute", .{zjb.constString("aria-busy")}, void);
}

fn swapped() void {
    page.id = src.id();
}
