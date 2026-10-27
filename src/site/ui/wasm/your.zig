//! ui-your.wasm: the Your games list (ui.yourpage.YourList) from the list on the page,
//! then with the visitor's clock and zone; a looked-up player's list in its place once
//! ui-yourlookup.wasm (loaded when the URL has an id) puts it on the root. zjb's
//! generated loader (ui-your.js, `<script src data-wasm>`) calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const yp = ui.yourpage;
const yk = ui.yourlookup;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;

var list: ui.yourlist.List = undefined;
var example: ui.yourlist.List = undefined;
var page: yp.YourList = undefined;
var page0: yp.YourList = undefined;
var island: ?*ui.island.Island(yp.YourList, dom.Dom) = null;
var lookup = false;
/// A looked-up list's, with its bytes; the one before stays until the next, as the last
/// render's tree still points into it
var arenas: [2]std.heap.ArenaAllocator = @splat(.init(gpa));
var cur: u1 = 0;

export fn main() void {
    dom.start();
    example = load(gpa) orelse return dom.dom.warn("your: no data");
    list = example;
    page0 = .{ .l = &list };
    page = page0;
    island = dom.rt.add(yp.YourList, &page, &page0, yp.sel) catch return dom.dom.warn("your: out of memory");
    zones(gpa);
    // Before the lookup's file can load, so its first list finds this listening
    zjb.global("window").call("addEventListener", .{ zjb.constString(yk.event), zjb.fnHandle("yourList", &onList) }, void);
    dom.rt.changed = changed;
    changed();
    tick();
    // "Today" and "2h ago" move on while the tab stays open
    zjb.global("window").call("setInterval", .{ zjb.fnHandle("yourTick", &tick), @as(i32, std.time.ms_per_min) }, void);
}

/// The list on the root (data-bin): the server's example, or a lookup's once handed over.
/// One that doesn't decode is removed, which tells the lookup (yk.event) to say so
fn load(a: std.mem.Allocator) ?ui.yourlist.List {
    const el = zjb.global("document").call("querySelector", .{zjb.constString(yp.sel)}, zjb.Handle);
    defer el.release();
    const b = dom.binOf(el, "data-bin") orelse return null;
    defer gpa.free(b);
    // Decoded strings point into the bytes
    const kept = a.dupe(u8, b) catch return null;
    return ui.data.decode(a, ui.yourlist.List, kept) catch {
        el.call("removeAttribute", .{zjb.constString("data-bin")}, void);
        dom.dom.warn("your: bad list");
        return null;
    };
}

/// Each game's minutes east of UTC here: a DST change between games moves it
fn zones(a: std.mem.Allocator) void {
    const tz = a.alloc(i32, list.games.len) catch return;
    for (list.games, tz) |g, *o| {
        const d = zjb.global("Date").new(.{@as(f64, @floatFromInt(g.start_ms))});
        defer d.release();
        o.* = -d.call("getTimezoneOffset", .{}, i32);
    }
    page.tz = tz;
}

/// An id in the URL, now or after Back or an edited link: the lookup's file, once
fn changed() void {
    if (lookup) return;
    var buf: [1024]u8 = undefined;
    if (yk.idOf(dom.dom.hash(&buf)) == null) return;
    lookup = true;
    dom.script(yk.sel);
}

/// The lookup's list on the root, or the example again without one
fn onList(e: zjb.Handle) callconv(.c) void {
    e.release();
    cur +%= 1;
    _ = arenas[cur].reset(.free_all);
    const a = arenas[cur].allocator();
    list = load(a) orelse example;
    // The example has no tag; a lookup's rows open game.html by the URL's id
    var buf: [1024]u8 = undefined;
    page.id = if (list.player.tag.len > 0) a.dupe(u8, yk.idOf(dom.dom.hash(&buf)) orelse "") catch "" else "";
    zones(a);
    // The URL's filter again, against this list's champions
    dom.rt.popstate();
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
