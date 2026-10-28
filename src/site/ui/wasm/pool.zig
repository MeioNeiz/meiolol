//! ui-pool.wasm: the pool page's pool and picker (ui.poolpage.Page) from its data-bin; the
//! pool from localStorage (meiolol.pool.v1) when the URL has none, and to it when the
//! visitor changes it (a shared link or Back never overwrites it). Each change goes to
//! the grid island (ui-poolgrid.wasm): the wrapper's data-pool, then a "ui-pool" event;
//! the grid asks for a champion with the wrapper's data-add and "ui-pool-add". zjb's
//! generated loader (ui-pool.js, `<script src data-wasm>`) calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const pp = ui.poolpage;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;
const key = "meiolol.pool.v1";
const wrap_sel = ".c-poolwrap";

var data: pp.Data = undefined;
var state: pp.Page = undefined;
var server: pp.Page = undefined;
var island: *ui.island.Island(pp.Page, dom.Dom) = undefined;

export fn main() void {
    dom.start();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(pp.sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    const b = dom.binOf(root, "data-bin") orelse return dom.dom.warn("pool: no data");
    data = ui.data.decode(gpa, pp.Data, b) catch return dom.dom.warn("pool: bad data");
    server = pp.Page.init(gpa, &data) catch return dom.dom.warn("pool: out of memory");
    state = server;
    island = dom.rt.add(pp.Page, &state, &server, pp.sel) catch return dom.dom.warn("pool: out of memory");
    dom.rt.changed = changed;
    zjb.global("window").call("addEventListener", .{ zjb.constString("ui-pool-add"), zjb.fnHandle("poolAdd", &onAdd) }, void);
    tell();
    if (state.n > 0) return;
    // Last: blocked storage throws, ending this call with the page already live
    if (dom.stored(key)) |s| {
        state.n = pp.read(&data, s, &state.pool);
        island.render();
        dom.rt.syncHash(false) catch {};
        tell();
    }
}

fn changed() void {
    save();
    tell();
}

/// The grid's champion to add: "3t"
fn onAdd(e: zjb.Handle) callconv(.c) void {
    e.release();
    const wrap = zjb.global("document").call("querySelector", .{zjb.constString(wrap_sel)}, zjb.Handle);
    if (wrap == .null) return;
    defer wrap.release();
    const s = dom.attrOf(wrap, "data-add");
    defer gpa.free(s);
    var one: [pp.max]ui.poolpage.Pick = undefined;
    if (pp.read(&data, s, &one) != 1) return;
    state.add(one[0]);
    state.dirty = true;
    island.render();
    dom.rt.syncHash(true) catch {};
    changed();
}

fn tell() void {
    var buf: [64]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    pp.write(state.picks(), &w) catch return;
    const wrap = zjb.global("document").call("querySelector", .{zjb.constString(wrap_sel)}, zjb.Handle);
    if (wrap == .null) return;
    defer wrap.release();
    const v = zjb.string(w.buffered());
    defer v.release();
    wrap.call("setAttribute", .{ zjb.constString("data-pool"), v }, void);
    const e = zjb.global("Event").new(.{zjb.constString("ui-pool")});
    defer e.release();
    zjb.global("window").call("dispatchEvent", .{e}, void);
}

fn save() void {
    if (!state.dirty) return;
    state.dirty = false;
    var buf: [64]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    pp.write(state.picks(), &w) catch return;
    dom.store(key, w.buffered());
}
