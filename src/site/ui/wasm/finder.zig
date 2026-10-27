//! ui-finder.wasm: the matchup finder (ui.finder.Finder) from its data-bin; it loads
//! ui-findergrid.wasm for the first pick's matchups. zjb's generated loader (ui-finder.js,
//! `<script src data-wasm>`) calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const fd = ui.finder;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;
const sel = "[data-island=finder]";
/// The islands of the page's other files (dom.lazyLoad)
const lazy = [_][]const u8{"[data-island=findergrid]"};

var data: fd.Data = undefined;
var state: fd.Finder = undefined;
var server: fd.Finder = undefined;

export fn main() void {
    dom.start();
    dom.lazyLoad(&lazy);
    defer dom.lazyLater();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    const b = dom.binOf(root, "data-bin") orelse return dom.dom.warn("finder: no data");
    data = ui.data.decode(gpa, fd.Data, b) catch return dom.dom.warn("finder: bad data");
    server = fd.Finder.init(gpa, &data, dom.attrOf(root, "data-root")) catch return dom.dom.warn("finder: out of memory");
    state = server;
    _ = dom.rt.add(fd.Finder, &state, &server, sel) catch return dom.dom.warn("finder: out of memory");
}
