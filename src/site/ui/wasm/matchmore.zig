//! ui-matchmore.wasm: the matchup page's lane, outcome and partner cards
//! (ui.matchpage.More) from its data-bin. ui-matchup.wasm adds its loader
//! (ui-matchmore.js) to the page, which calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const mp = ui.matchpage;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;
const sel = "[data-island=matchmore]";

var data: mp.MoreData = undefined;
var state: mp.More = undefined;
var server: mp.More = undefined;

export fn main() void {
    dom.start();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    const b = dom.binOf(root, "data-bin") orelse return dom.dom.warn("matchmore: no data");
    data = ui.data.decode(gpa, mp.MoreData, b) catch return dom.dom.warn("matchmore: bad data");
    server = mp.More.init(gpa, &data) catch return dom.dom.warn("matchmore: out of memory");
    state = server;
    _ = dom.rt.add(mp.More, &state, &server, sel) catch return dom.dom.warn("matchmore: out of memory");
}
