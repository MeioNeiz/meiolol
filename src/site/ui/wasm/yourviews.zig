//! ui-yourviews.wasm: the Your games page's head (ui.yourviews.YourViews). Its list is
//! ui-your's: YourList's root data-bin, read again on each yk.event; the example from
//! data-example once the lookup has handed a list over, as that can happen before this
//! file loads. zjb's generated loader (ui-yourviews.js, `<script src data-wasm>`) calls
//! `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const yv = ui.yourviews;
const yk = ui.yourlookup;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;

var list: ui.yourlist.List = undefined;
var example: ui.yourlist.List = undefined;
var page: yv.YourViews = undefined;
var page0: yv.YourViews = undefined;
var island: ?*ui.island.Island(yv.YourViews, dom.Dom) = null;
/// A looked-up list's, with its bytes; the one before stays until the next, as the last
/// render's tree still points into it
var arenas: [2]std.heap.ArenaAllocator = @splat(.init(gpa));
var cur: u1 = 0;

export fn main() void {
    dom.start();
    const handed = load(gpa, "data-example");
    example = handed orelse load(gpa, "data-bin") orelse return dom.dom.warn("yourviews: no data");
    list = example;
    page0 = .{ .l = &list };
    page = page0;
    island = dom.rt.add(yv.YourViews, &page, &page0, yv.sel) catch return dom.dom.warn("yourviews: out of memory");
    const d = zjb.global("Date").new(.{});
    defer d.release();
    page.tz_min = -d.call("getTimezoneOffset", .{}, i32);
    island.?.render();
    zjb.global("window").call("addEventListener", .{ zjb.constString(yk.event), zjb.fnHandle("yourViewsList", &onList) }, void);
    if (handed != null) swap();
}

/// A list on YourList's root; null when missing or unreadable (ui-your says which)
fn load(a: std.mem.Allocator, attr: []const u8) ?ui.yourlist.List {
    const el = zjb.global("document").call("querySelector", .{zjb.constString(ui.yourpage.sel)}, zjb.Handle);
    defer el.release();
    const b = dom.binOf(el, attr) orelse return null;
    defer gpa.free(b);
    // Decoded strings point into the bytes
    const kept = a.dupe(u8, b) catch return null;
    return ui.data.decode(a, ui.yourlist.List, kept) catch null;
}

fn onList(e: zjb.Handle) callconv(.c) void {
    e.release();
    swap();
}

/// The lookup's list, or the example again without one
fn swap() void {
    cur +%= 1;
    _ = arenas[cur].reset(.free_all);
    const a = arenas[cur].allocator();
    list = load(a, "data-bin") orelse example;
    // The example has no tag; a lookup's records open game.html by the URL's id
    var buf: [1024]u8 = undefined;
    page.id = if (list.player.tag.len > 0) a.dupe(u8, yk.idOf(dom.dom.hash(&buf)) orelse "") catch "" else "";
    // The URL's filter again, against this list's champions
    dom.rt.popstate();
}
