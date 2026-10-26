//! ui-stats.wasm: the champions board (ui.tiers.Tiers) from its view's data file. zjb's
//! generated loader (ui-stats.js, `<script src data-wasm>`) calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const tiers = ui.tiers;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;
const sel = "[data-island=tiers]";

var data: tiers.Data = undefined;
var state: tiers.Tiers = undefined;
var server: tiers.Tiers = undefined;
var page_role: ?tiers.Role = null;
var base: []const u8 = "";
var view_index: u8 = 0;
var path: []const u8 = "";
var src: []const u8 = "";
var want: u32 = 0;

export fn main() void {
    dom.start();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    const role = dom.attrOf(root, "data-role");
    page_role = for (std.enums.values(tiers.Role)) |r| {
        if (std.mem.eql(u8, tiers.Role.slugs[@backingInt(r)], role)) break r;
    } else null;
    base = dom.attrOf(root, "data-base");
    view_index = std.fmt.parseInt(u8, dom.attrOf(root, "data-view"), 10) catch return;
    path = dom.attrOf(root, "data-path");
    src = dom.attrOf(root, "data-src");
    want = std.fmt.parseInt(u32, dom.attrOf(root, "data-stamp"), 10) catch return;
    dom.fetch(src, 0, loaded);
}

fn loaded(_: i32, bytes: ?[]u8) void {
    const b = bytes orelse return dom.dom.warn("tiers: no data");
    // A page cached from an older build than its data: leave it as rendered
    if (tiers.stamp(b) != want) return dom.dom.warn("tiers: the page and its data differ");
    data = ui.data.decode(gpa, tiers.Data, b) catch return dom.dom.warn("tiers: bad data");
    const lines = tiers.prepare(gpa, &data, base) catch return dom.dom.warn("tiers: out of memory");
    server = .init(&data, lines, page_role);
    server.base = base;
    server.view_index = view_index;
    server.path = path;
    server.src = src;
    server.stamp = want;
    state = server;
    _ = dom.rt.add(tiers.Tiers, &state, &server, sel) catch return dom.dom.warn("tiers: out of memory");
}
