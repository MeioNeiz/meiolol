//! ui-yourviews.wasm: the Your games page's head (ui.yourviews.YourViews), with its list
//! from yoursrc.zig, and the loaders of ui-yourtime.wasm and ui-yourfriends.wasm once
//! their view shows. zjb's generated loader (ui-yourviews.js, `<script src data-wasm>`)
//! calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const src = @import("yoursrc.zig");
const yv = ui.yourviews;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;
/// Over time and Friends are hidden by CSS until their tab is chosen, so each nears the
/// viewport only then; Remove my data at the page's foot
const lazy = [_][]const u8{ ui.yourtime.sel, ui.yourfriends.sel, ui.forget.sel };

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
    page.views = if (page.id.len > 0) &yv.looked_up else &yv.shipped;
    markTime();
}

/// Until ui-yourtime runs (it marks its root data-live), the Over time view holds the
/// server's example: busy for a looked-up list, or "Couldn't load" once its file failed
/// (dom's data-failed)
fn markTime() void {
    const el = zjb.global("document").call("querySelector", .{zjb.constString(ui.yourtime.sel)}, zjb.Handle);
    if (el == .null) return;
    defer el.release();
    if (el.call("hasAttribute", .{zjb.constString("data-live")}, bool)) return;
    if (el.call("hasAttribute", .{zjb.constString("data-failed")}, bool)) {
        const v = if (page.id.len > 0) zjb.constString("show") else zjb.constString("");
        el.call("setAttribute", .{ zjb.constString("data-failed"), v }, void);
    } else if (page.id.len > 0) {
        el.call("setAttribute", .{ zjb.constString("aria-busy"), zjb.constString("true") }, void);
    } else el.call("removeAttribute", .{zjb.constString("aria-busy")}, void);
}
