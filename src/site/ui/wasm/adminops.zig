//! ui-adminops.wasm: the admin page's Deploys and Logs tabs (ui.adminops.Ops).
//! ui-admin.wasm adds its loader (ui-adminops.js), which calls `main`. Deploys: api/live.bin
//! once the tab shows, then each minute while it shows and the browser tab is in view;
//! admin.bin's events when live.bin fails. Logs: every log's tail once the tab shows, the
//! shown one again on Reload and each 10 s with Follow
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const Held = @import("held.zig").Held;
const ao = ui.adminops;
const ad = ui.admindata;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;

var state: ao.Ops = .{};
var server: ao.Ops = .{};
var island: ?*ui.island.Island(ao.Ops, dom.Dom) = null;

var live: Held(ad.Live) = .{};
var snap: Held(ad.Snapshot) = .{};
var live_flight = false;
var live_at: i64 = 0;
/// Each log's tail, state.tails' memory
var log_mem: [ao.log_files.len]?std.heap.ArenaAllocator = @splat(null);
var log_flight: [ao.log_files.len]bool = @splat(false);

const Call = enum(i32) { live, snap };
/// A log's request answers with this plus its index
const log_ctx = 64;

const tick_ms = 10_000;
const live_s = 60;

export fn main() void {
    dom.start();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(ao.sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    // As the server rendered them, so hydration matches
    server.js = dom.attrOf(root, "data-js");
    server.wasm = dom.attrOf(root, "data-wasm");
    state.js = server.js;
    state.wasm = server.wasm;
    state.opened = now();
    island = dom.rt.add(ao.Ops, &state, &server, ao.sel) catch return dom.dom.warn("adminops: out of memory");
    dom.rt.changed = changed;
    changed();
    zjb.global("window").call("setInterval", .{ zjb.fnHandle("opsTick", &onTick), @as(i32, tick_ms) }, void);
    zjb.global("document").call("addEventListener", .{ zjb.constString("visibilitychange"), zjb.fnHandle("opsShown", &onShown), @as(i32, 0) }, void);
}

fn now() i64 {
    return @intFromFloat(@divFloor(zjb.global("Date").call("now", .{}, f64), 1000));
}

fn render() void {
    state.now = now();
    if (island) |i| i.render();
}

fn getLive() void {
    if (live_flight) return;
    live_flight = true;
    dom.fetch("api/live.bin", @backingInt(Call.live), done);
}

fn getLog(i: usize) void {
    if (i >= ao.log_files.len or log_flight[i]) return;
    log_flight[i] = true;
    var buf: [64]u8 = undefined;
    const path = std.fmt.bufPrint(&buf, "api/log?file={s}&lines={d}", .{ ao.log_files[i], ao.log_lines }) catch return;
    dom.fetch(path, log_ctx + @as(i32, @intCast(i)), done);
}

/// A tab came up (the URL), or an update asked for a log
fn changed() void {
    if (state.want) |i| getLog(i);
    state.want = null;
    switch (state.tab) {
        .deploys => if (state.events == null and !state.failed) getLive(),
        .logs => {
            for (state.tails, state.log_failed) |t, f| if (t != null or f) return;
            for (0..ao.log_files.len) |i| getLog(i);
        },
        else => {},
    }
}

fn onTick() callconv(.c) void {
    if (!state.shows() or zjb.global("document").get("hidden", bool)) return;
    if (state.tab == .logs) {
        if (state.follow) getLog(state.shown);
        return;
    }
    if (now() - live_at >= live_s) getLive() else render();
}

fn onShown(e: zjb.Handle) callconv(.c) void {
    e.release();
    onTick();
}

fn done(ctx: i32, bytes: ?[]u8) void {
    defer render();
    if (ctx >= log_ctx) return logDone(@intCast(ctx - log_ctx), bytes);
    switch (std.enums.fromInt(Call, ctx) orelse return) {
        .live => {
            live_flight = false;
            live_at = now();
            const l = if (bytes) |b| live.set(b) else null;
            if (l) |x| {
                state.events = x.deploys;
                state.snap = false;
                state.failed = false;
            } else dom.fetch("admin.bin", @backingInt(Call.snap), done);
        },
        .snap => {
            const s = (if (bytes) |b| snap.set(b) else null) orelse {
                state.failed = state.events == null;
                return;
            };
            state.events = s.deploy_events;
            state.snap = true;
        },
    }
}

fn logDone(i: usize, bytes: ?[]u8) void {
    log_flight[i] = false;
    const b = bytes orelse {
        state.log_failed[i] = true;
        return;
    };
    defer gpa.free(b);
    var next: std.heap.ArenaAllocator = .init(gpa);
    const t = ao.logTail(next.allocator(), b, now()) catch {
        next.deinit();
        state.log_failed[i] = true;
        return;
    };
    if (log_mem[i]) |*m| m.deinit();
    log_mem[i] = next;
    state.tails[i] = t;
    state.log_failed[i] = false;
}
