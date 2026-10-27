//! ui-yourviews.wasm: the Your games page's head (ui.yourviews.YourViews), with its list
//! from yoursrc.zig, and the loader of ui-yourtime.wasm once Over time shows. zjb's
//! generated loader (ui-yourviews.js, `<script src data-wasm>`) calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const src = @import("yoursrc.zig");
const yv = ui.yourviews;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;
/// Hidden by CSS until its tab is chosen, so it nears the viewport only then
const lazy = [_][]const u8{ui.yourtime.sel};

var page: yv.YourViews = undefined;
var page0: yv.YourViews = undefined;
var island: ?*ui.island.Island(yv.YourViews, dom.Dom) = null;

export fn main() void {
    dom.start();
    dom.lazyLoad(&lazy);
    const handed = src.start(swapped) catch return dom.dom.warn("yourviews: no data");
    page0 = .{ .l = &src.list };
    page = page0;
    island = dom.rt.add(yv.YourViews, &page, &page0, yv.sel) catch return dom.dom.warn("yourviews: out of memory");
    page.tz_min = src.tzMin();
    island.?.render();
    if (handed) src.swap();
}

fn swapped() void {
    page.id = src.id();
}
