//! ui-yourviews.wasm: the Your games page's head (ui.yourviews.YourViews), with its list
//! from yoursrc.zig; the example's role switch, which fetches that role's list and hands
//! it over as a lookup does; and the loaders of ui-yourtime.wasm and ui-yourfriends.wasm
//! once their view shows. zjb's generated loader (ui-yourviews.js, `<script src data-wasm>`)
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
/// The example's role whose list is being fetched
var asked: ?ui.role.Role = null;
/// The server's example's role: a URL without one (Back) shows it again
var default: ?ui.role.Role = null;

export fn main() void {
    dom.start();
    dom.lazyLoad(&lazy);
    const handed = src.start(swapped) catch return dom.dom.warn("yourviews: no data");
    page0 = .{ .l = &src.list, .roles = roles() };
    default = page0.shown();
    page = page0;
    island = dom.rt.add(yv.YourViews, &page, &page0, yv.sel) catch return dom.dom.warn("yourviews: out of memory");
    page.tz_min = src.tzMin();
    page.live = true;
    dom.rt.changed = check;
    island.?.render();
    if (handed) src.swap();
    check();
}

fn roles() [5]bool {
    const el = zjb.global("document").call("querySelector", .{zjb.constString(yv.sel)}, zjb.Handle);
    defer el.release();
    const a = dom.attrOf(el, "data-roles");
    defer gpa.free(a);
    return ui.homepage.rolesOf(std.fmt.parseInt(u8, a, 10) catch 0);
}

/// The URL's example role, when another is shown: its list
fn check() void {
    const r = page.want orelse default orelse return;
    if (page.id.len > 0 or !page.roles[@backingInt(r)] or page.shown() == r or asked == r) return;
    asked = r;
    var buf: [64]u8 = undefined;
    const path = std.fmt.bufPrint(&buf, "/" ++ ui.homepage.your_list_dir ++ "{t}.bin", .{r}) catch return;
    // No data stamp on the page: a cached list from an older build would open other games
    dom.fetchFresh(path, @backingInt(r), got);
}

fn got(ctx: i32, bytes: ?[]u8) void {
    asked = null;
    const b = bytes orelse return dom.dom.warn("yourviews: no list");
    defer gpa.free(b);
    // Another role asked for since: that one's
    const want = page.want orelse default;
    if (want == null or @backingInt(want.?) != ctx) return check();
    src.put(b);
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
