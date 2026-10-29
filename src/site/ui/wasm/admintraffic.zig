//! ui-admintraffic.wasm: the admin page's Traffic tab (ui.admintraffic.Traffic).
//! ui-admin.wasm adds its loader (ui-admintraffic.js), which calls `main`. Fetches
//! api/traffic.bin once the tab shows, then each 5 min (deploy/traffic.sh's pace) while it
//! shows and the browser tab is in view
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const Held = @import("held.zig").Held;
const at = ui.admintraffic;
const ad = ui.admindata;

pub const panic = zjb.panic;

var state: at.Traffic = .{};
var server: at.Traffic = .{};
var island: ?*ui.island.Island(at.Traffic, dom.Dom) = null;

var data: Held(ad.Traffic) = .{};
var in_flight = false;
var got_at: i64 = 0;

const tick_ms = 60_000;
const every_s = 300;

export fn main() void {
    dom.start();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(at.sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    // As the server rendered them, so hydration matches
    server.js = dom.attrOf(root, "data-js");
    server.wasm = dom.attrOf(root, "data-wasm");
    state.js = server.js;
    state.wasm = server.wasm;
    island = dom.rt.add(at.Traffic, &state, &server, at.sel) catch return dom.dom.warn("admintraffic: out of memory");
    dom.rt.changed = changed;
    changed();
    zjb.global("window").call("setInterval", .{ zjb.fnHandle("trafficTick", &onTick), @as(i32, tick_ms) }, void);
    zjb.global("document").call("addEventListener", .{ zjb.constString("visibilitychange"), zjb.fnHandle("trafficShown", &onShown), @as(i32, 0) }, void);
}

fn now() i64 {
    return @intFromFloat(@divFloor(zjb.global("Date").call("now", .{}, f64), 1000));
}

fn render() void {
    state.now = now();
    if (island) |i| i.render();
}

fn get() void {
    if (in_flight) return;
    in_flight = true;
    dom.fetch("api/traffic.bin", 0, done);
}

/// The tab came up (the URL): its first data
fn changed() void {
    if (state.shows() and state.data == null and !state.failed) get();
}

fn onTick() callconv(.c) void {
    if (!state.shows() or zjb.global("document").get("hidden", bool)) return;
    if (now() - got_at >= every_s) get() else render();
}

fn onShown(e: zjb.Handle) callconv(.c) void {
    e.release();
    onTick();
}

fn done(_: i32, bytes: ?[]u8) void {
    in_flight = false;
    defer render();
    const b = bytes orelse {
        state.failed = state.data == null;
        return;
    };
    state.data = data.set(b) orelse state.data;
    state.failed = state.data == null;
    got_at = now();
}
