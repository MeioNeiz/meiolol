//! The Your games list for the files beside ui-your (ui-yourviews, ui-yourtime): YourList's
//! root data-bin, read again on each yk.event; the example from data-example once the
//! lookup has handed a list over, as that can happen before such a file loads
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const yk = ui.yourlookup;

const gpa = std.heap.wasm_allocator;

pub var list: ui.yourlist.List = undefined;
var example: ui.yourlist.List = undefined;
/// A looked-up list's, with its bytes; the one before stays until the next, as the last
/// render's tree still points into it
var arenas: [2]std.heap.ArenaAllocator = @splat(.init(gpa));
var cur: u1 = 0;
var swapped: *const fn () void = undefined;

/// The example, as the server rendered it, in `list`; true when the lookup has handed
/// its list over already (call `swap`)
pub fn start(on_swap: *const fn () void) !bool {
    const handed = load(gpa, "data-example");
    example = handed orelse load(gpa, "data-bin") orelse return error.NoData;
    list = example;
    swapped = on_swap;
    zjb.global("window").call("addEventListener", .{ zjb.constString(yk.event), zjb.fnHandle("yourSrcList", &onList) }, void);
    return handed != null;
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

/// The lookup's list, or the example again without one; the caller's island then takes
/// the URL's filter again, against this list's champions
pub fn swap() void {
    cur +%= 1;
    _ = arenas[cur].reset(.free_all);
    list = load(arenas[cur].allocator(), "data-bin") orelse example;
    swapped();
    dom.rt.popstate();
}

/// The looked-up player's id from the URL, kept until the next swap; "" the example (no
/// tag), whose games open by index
pub fn id() []const u8 {
    if (list.player.tag.len == 0) return "";
    var buf: [1024]u8 = undefined;
    return arenas[cur].allocator().dupe(u8, yk.idOf(dom.dom.hash(&buf)) orelse "") catch "";
}

/// Minutes east of UTC
pub fn tzMin() i32 {
    const d = zjb.global("Date").new(.{});
    defer d.release();
    return -d.call("getTimezoneOffset", .{}, i32);
}
