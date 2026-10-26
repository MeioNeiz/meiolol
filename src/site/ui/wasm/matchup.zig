//! ui-matchup.wasm: the matchup page's head (ui.matchpage.Head) from its data-bin, and the
//! loader of ui-champbuild.wasm and ui-matchmore.wasm for the rest. zjb's generated loader
//! (ui-matchup.js, `<script src data-wasm>`) calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const mp = ui.matchpage;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;
const sel = "[data-island=matchup]";
/// The islands of the page's other files (dom.lazyLoad)
const lazy = [_][]const u8{ "[data-island=champbuild]", "[data-island=matchmore]" };

var data: mp.HeadData = undefined;
var state: mp.Head = undefined;
var server: mp.Head = undefined;

export fn main() void {
    dom.start();
    dom.lazyLoad(&lazy);
    defer dom.lazyLater();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    const b = dom.binOf(root, "data-bin") orelse return dom.dom.warn("matchup: no data");
    data = ui.data.decode(gpa, mp.HeadData, b) catch return dom.dom.warn("matchup: bad data");
    // Each its own strip: the server's stays as rendered for hydration
    server = mp.Head.init(gpa, &data) catch return dom.dom.warn("matchup: out of memory");
    state = mp.Head.init(gpa, &data) catch return dom.dom.warn("matchup: out of memory");
    const i = dom.rt.add(mp.Head, &state, &server, sel) catch return dom.dom.warn("matchup: out of memory");
    // The page's opponent in view, the strip scrolled sideways to it
    const cur = i.current();
    if (cur.find(cur.root, "aria-current", "page")) |n| dom.dom.scroll(cur.node(n).dom);
}
