//! ui-dailyseat.wasm: Daily Draft's seat review and On paper (ui.dailyseat.Seat), from the
//! page island's data-bin, its answers and selected seat from that root's attributes,
//! again on ui-daily.wasm's "ui-daily-seat" event. ui-daily.wasm adds its loader
//! (ui-dailyseat.js) once the puzzle is answered, which calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const dsx = ui.dailyseat;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;

var data: ui.dailydata.Puzzle = undefined;
var state: dsx.Seat = undefined;
var server: dsx.Seat = undefined;
var island: *ui.island.Island(dsx.Seat, dom.Dom) = undefined;

export fn main() void {
    dom.start();
    const doc = zjb.global("document");
    const root = doc.call("querySelector", .{zjb.constString(dsx.sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    const page = doc.call("querySelector", .{zjb.constString(ui.dailypage.sel)}, zjb.Handle);
    if (page == .null) return;
    defer page.release();
    const b = dom.binOf(page, "data-bin") orelse return dom.dom.warn("seat: no data");
    data = ui.dailydata.decode(gpa, b) catch return dom.dom.warn("seat: bad data");
    if (!data.valid()) return dom.dom.warn("seat: bad data");
    server = .init(gpa, &data);
    server.js = dom.attrOf(root, "data-js");
    server.wasm = dom.attrOf(root, "data-wasm");
    state = server;
    island = dom.rt.add(dsx.Seat, &state, &server, dsx.sel) catch return dom.dom.warn("seat: out of memory");
    zjb.global("window").call("addEventListener", .{ zjb.constString("ui-daily-seat"), zjb.fnHandle("seatMoved", &onMoved) }, void);
    read(page);
}

fn onMoved(e: zjb.Handle) callconv(.c) void {
    e.release();
    const page = zjb.global("document").call("querySelector", .{zjb.constString(ui.dailypage.sel)}, zjb.Handle);
    if (page == .null) return;
    defer page.release();
    read(page);
}

fn read(page: zjb.Handle) void {
    const attrs = [3][]const u8{ dom.attrOf(page, "data-phase"), dom.attrOf(page, "data-seat"), dom.attrOf(page, "data-guess") };
    defer for (attrs) |a| if (a.len > 0) gpa.free(a);
    state.read(attrs[0], attrs[1], attrs[2]);
    island.render();
}
