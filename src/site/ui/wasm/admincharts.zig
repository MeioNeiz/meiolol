//! ui-admincharts.wasm: the admin page's chart tabs (ui.admincharts.Charts). ui-admin.wasm
//! adds its loader (ui-admincharts.js), which calls `main`. Fetches admin.bin and
//! api/live.bin once a chart tab shows, then live.bin each minute and admin.bin each 5 min
//! while one shows and the browser tab is in view
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const Held = @import("held.zig").Held;
const ac = ui.admincharts;
const ad = ui.admindata;

pub const panic = zjb.panic;

const Call = enum(i32) { snap, live };

var state: ac.Charts = .{};
var server: ac.Charts = .{};
var island: ?*ui.island.Island(ac.Charts, dom.Dom) = null;

var snap: Held(ad.Snapshot) = .{};
var live: Held(ad.Live) = .{};
var in_flight: std.enums.EnumSet(Call) = .empty;
var snap_at: i64 = 0;

const live_ms = 60_000;
const snap_s = 300;

export fn main() void {
    dom.start();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(ac.sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    // As the server rendered them, so hydration matches
    server.js = dom.attrOf(root, "data-js");
    server.wasm = dom.attrOf(root, "data-wasm");
    state.js = server.js;
    state.wasm = server.wasm;
    island = dom.rt.add(ac.Charts, &state, &server, ac.sel) catch return dom.dom.warn("admincharts: out of memory");
    dom.rt.changed = changed;
    changed();
    zjb.global("window").call("setInterval", .{ zjb.fnHandle("chartsTick", &onTick), @as(i32, live_ms) }, void);
    zjb.global("document").call("addEventListener", .{ zjb.constString("visibilitychange"), zjb.fnHandle("chartsShown", &onShown), @as(i32, 0) }, void);
}

fn now() i64 {
    return @intFromFloat(@divFloor(zjb.global("Date").call("now", .{}, f64), 1000));
}

fn render() void {
    state.now = now();
    if (island) |i| i.render();
}

fn get(c: Call, path: []const u8) void {
    if (in_flight.contains(c)) return;
    in_flight.insert(c);
    // The snapshot is a file; the APIs answer no-store
    if (c == .snap) dom.fetchFresh(path, @backingInt(c), done) else dom.fetch(path, @backingInt(c), done);
}

/// A chart tab came up (the URL): its first data
fn changed() void {
    if (!state.shows()) return;
    if (state.snap == null and !state.snap_failed) get(.snap, "/admin/admin.bin");
    if (state.live == null) get(.live, "/admin/api/live.bin");
}

fn onTick() callconv(.c) void {
    if (!state.shows() or zjb.global("document").get("hidden", bool)) return;
    get(.live, "/admin/api/live.bin");
    if (now() - snap_at >= snap_s) get(.snap, "/admin/admin.bin");
}

fn onShown(e: zjb.Handle) callconv(.c) void {
    e.release();
    onTick();
}

fn done(ctx: i32, bytes: ?[]u8) void {
    const c = std.enums.fromInt(Call, ctx) orelse return;
    in_flight.remove(c);
    defer render();
    const b = bytes orelse {
        if (c == .snap) state.snap_failed = state.snap == null;
        return;
    };
    switch (c) {
        .snap => {
            state.snap = snap.set(b) orelse state.snap;
            state.snap_failed = state.snap == null;
            snap_at = now();
        },
        .live => state.live = live.set(b) orelse state.live,
    }
}
