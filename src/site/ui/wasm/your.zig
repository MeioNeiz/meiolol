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
var island: ?*ui.island.Island(yp.YourList, dom.Dom) = null;

export fn main() void {
    dom.start();
    const el = zjb.global("document").call("querySelector", .{zjb.constString(yp.sel)}, zjb.Handle);
    if (el == .null) return;
    defer el.release();
    const b = dom.binOf(el, "data-bin") orelse return dom.dom.warn("your: no data");
    list = ui.data.decode(gpa, ui.yourlist.List, b) catch return dom.dom.warn("your: bad data");
    page0 = .{ .l = &list };
    page = page0;
    island = dom.rt.add(yp.YourList, &page, &page0, yp.sel) catch return dom.dom.warn("your: out of memory");
    const tz = gpa.alloc(i32, list.games.len) catch return dom.dom.warn("your: out of memory");
    for (list.games, tz) |g, *o| {
        const d = zjb.global("Date").new(.{@as(f64, @floatFromInt(g.start_ms))});
        defer d.release();
        o.* = -d.call("getTimezoneOffset", .{}, i32);
    }
    page.tz = tz;
    tick();
    // "Today" and "2h ago" move on while the tab stays open
    zjb.global("window").call("setInterval", .{ zjb.fnHandle("yourTick", &tick), @as(i32, std.time.ms_per_min) }, void);
}

fn tick() callconv(.c) void {
    const d = zjb.global("Date").new(.{});
    defer d.release();
    const ms = d.call("getTime", .{}, f64);
    if (!std.math.isFinite(ms)) return;
    page.now_ms = @intFromFloat(ms);
    page.tz_min = -d.call("getTimezoneOffset", .{}, i32);
    if (island) |i| i.render();
}
