//! ui-dailydays.wasm: Daily Draft's days strip and streak (ui.dailydays.Page) from its
//! data-bin and localStorage meiolol.daily.v1, again on ui-daily.wasm's "ui-daily" event
//! (a puzzle finished). On daily.html it also opens the viewer's own day's puzzle (their
//! date, not UTC's) or ?n='s. zjb's generated loader (ui-dailydays.js) calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const ds = ui.dailydays;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;
const key = "meiolol.daily.v1";

var data: ds.Data = undefined;
var state: ds.Page = undefined;
var server: ds.Page = undefined;
var island: *ui.island.Island(ds.Page, dom.Dom) = undefined;
var date: [10]u8 = undefined;

export fn main() void {
    dom.start();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(ds.sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    const b = dom.binOf(root, "data-bin") orelse return dom.dom.warn("days: no data");
    data = ui.data.decode(gpa, ds.Data, b) catch return dom.dom.warn("days: bad data");
    date = today();
    if (data.redirects) if (ds.target(data.days, &date, wanted())) |n| if (n != data.n) return open(n);
    server = .init(gpa, &data);
    state = .init(gpa, &data);
    island = dom.rt.add(ds.Page, &state, &server, ds.sel) catch return dom.dom.warn("days: out of memory");
    state.date = &date;
    island.render();
    zjb.global("window").call("addEventListener", .{ zjb.constString("ui-daily"), zjb.fnHandle("daysSaved", &onSaved) }, void);
    // Last: blocked storage throws, ending this call with the page already live
    read();
}

fn onSaved(e: zjb.Handle) callconv(.c) void {
    e.release();
    read();
}

fn read() void {
    const s = dom.stored(key) orelse return;
    if (state.saved.len > 0) gpa.free(state.saved);
    state.saved = s;
    island.render();
}

/// ?n= (an old link to a puzzle)
fn wanted() ?u32 {
    const s = zjb.global("location").get("search", zjb.Handle);
    defer s.release();
    var buf: [64]u8 = undefined;
    return ds.wantedOf(s.readString(&buf) catch return null);
}

fn open(n: u32) void {
    var buf: [64]u8 = undefined;
    const url = std.fmt.bufPrint(&buf, "{s}daily/{d}.html", .{ data.root, n }) catch return;
    const u = zjb.string(url);
    defer u.release();
    zjb.global("location").call("replace", .{u}, void);
}

/// The viewer's own date, "2026-10-27"
fn today() [10]u8 {
    const d = zjb.global("Date").new(.{});
    defer d.release();
    var out: [10]u8 = undefined;
    _ = std.fmt.bufPrint(&out, "{d:0>4}-{d:0>2}-{d:0>2}", .{
        @as(u32, @intCast(std.math.clamp(d.call("getFullYear", .{}, i32), 0, 9999))),
        @as(u32, @intCast(@max(d.call("getMonth", .{}, i32) + 1, 0))),
        @as(u32, @intCast(@max(d.call("getDate", .{}, i32), 0))),
    }) catch return "0000-00-00".*;
    return out;
}
