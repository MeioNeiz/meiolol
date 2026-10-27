//! ui-your.wasm: the Your games list (ui.yourpage.YourList) from the list on the page,
//! then with the visitor's clock and zone. zjb's generated loader (ui-your.js, `<script
//! src data-wasm>`) calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const yp = ui.yourpage;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;

var list: ui.yourlist.List = undefined;
var page: yp.YourList = undefined;
var page0: yp.YourList = undefined;

export fn main() void {
    dom.start();
    const el = zjb.global("document").call("querySelector", .{zjb.constString(yp.sel)}, zjb.Handle);
    if (el == .null) return;
    defer el.release();
    const b = dom.binOf(el, "data-bin") orelse return dom.dom.warn("your: no data");
    list = ui.data.decode(gpa, ui.yourlist.List, b) catch return dom.dom.warn("your: bad data");
    page0 = .{ .l = &list };
    page = page0;
    const i = dom.rt.add(yp.YourList, &page, &page0, yp.sel) catch return dom.dom.warn("your: out of memory");
    const d = zjb.global("Date").new(.{});
    defer d.release();
    page.tz_min = -d.call("getTimezoneOffset", .{}, i32);
    page.now_ms = @intFromFloat(d.call("getTime", .{}, f64));
    i.render();
}
