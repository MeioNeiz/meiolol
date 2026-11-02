//! ui-rankings.wasm: a stat's ranking (ui.ranking.Ranking) from its data-bin. zjb's
//! generated loader (ui-rankings.js, `<script src data-wasm>`) calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const rk = ui.ranking;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;

var data: rk.Data = undefined;
var state: rk.Ranking = undefined;
var server: rk.Ranking = undefined;

export fn main() void {
    dom.start();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(rk.sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    const b = dom.binOf(root, "data-bin") orelse return dom.dom.warn("ranking: no data");
    data = ui.data.decode(gpa, rk.Data, b) catch return dom.dom.warn("ranking: bad data");
    server = rk.Ranking.init(gpa, &data) catch return dom.dom.warn("ranking: out of memory");
    state = server;
    _ = dom.rt.add(rk.Ranking, &state, &server, rk.sel) catch return dom.dom.warn("ranking: out of memory");
}
