//! ui-stats.wasm: the islands of the stats pages (the champions table first). zjb's
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

/// The island root's attribute `name`, kept ("" when missing)
fn attr(root: zjb.Handle, comptime name: []const u8) []const u8 {
    const v = root.call("getAttribute", .{zjb.constString(name)}, zjb.Handle);
    defer v.release();
    if (v == .null) return "";
    return v.allocString(gpa) catch "";
}

export fn main() void {
    dom.start();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    const role = attr(root, "data-role");
    server = .{
        .data = &data,
        .cells = &.{},
        .role = for (std.enums.values(tiers.Role)) |r| {
            if (std.mem.eql(u8, tiers.Role.slugs[@backingInt(r)], role)) break r;
        } else null,
        .root = attr(root, "data-root"),
        .base = attr(root, "data-base"),
        .src = attr(root, "data-src"),
        .stamp = std.fmt.parseInt(u32, attr(root, "data-stamp"), 10) catch return,
    };
    dom.fetch(server.src, 0, loaded);
}

fn loaded(_: i32, bytes: ?[]u8) void {
    const b = bytes orelse return dom.dom.warn("tiers: no data");
    // A page cached from an older build than its data: leave it as rendered
    if (tiers.stamp(b) != server.stamp) return dom.dom.warn("tiers: the page and its data differ");
    data = ui.data.decode(gpa, tiers.Data, b) catch return dom.dom.warn("tiers: bad data");
    server.cells = tiers.prepare(gpa, &data, server.role, server.base) catch return dom.dom.warn("tiers: out of memory");
    state = server;
    state.live = true;
    _ = dom.rt.add(tiers.Tiers, &state, &server, sel) catch return dom.dom.warn("tiers: out of memory");
}
