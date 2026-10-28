//! ui-poolgrid.wasm: the pool page's sections per role (ui.poolgrid.Page), from the pool
//! island's data-bin. The pool comes from ui-pool.wasm (the wrapper's data-pool, again on
//! each "ui-pool" event); each champion's lanes file (data/pool/lanes/<slug>.bin) and
//! each role main's file (data/pool/<slug>.bin) fetched one at a time as the pool needs
//! them. What to add's rows go back as the wrapper's data-add and "ui-pool-add". zjb's
//! generated loader (ui-poolgrid.js, `<script src data-wasm>`) calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const pg = ui.poolgrid;
const pp = ui.poolpage;
const pd = ui.pooldata;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;
const wrap_sel = ".c-poolwrap";

var data: pp.Data = undefined;
var state: pg.Page = undefined;
var server: pg.Page = undefined;
var island: *ui.island.Island(pg.Page, dom.Dom) = undefined;
var asked = false;

export fn main() void {
    dom.start();
    const pool = zjb.global("document").call("querySelector", .{zjb.constString(pp.sel)}, zjb.Handle);
    if (pool == .null) return;
    defer pool.release();
    const b = dom.binOf(pool, "data-bin") orelse return dom.dom.warn("poolgrid: no data");
    data = ui.data.decode(gpa, pp.Data, b) catch return dom.dom.warn("poolgrid: bad data");
    server = .{ .d = &data };
    state = server;
    island = dom.rt.add(pg.Page, &state, &server, pg.sel) catch return dom.dom.warn("poolgrid: out of memory");
    dom.rt.changed = changed;
    zjb.global("window").call("addEventListener", .{ zjb.constString("ui-pool"), zjb.fnHandle("gridPool", &onPool) }, void);
    read();
}

fn onPool(e: zjb.Handle) callconv(.c) void {
    e.release();
    read();
}

/// The pool ui-pool.wasm left on the wrapper
fn read() void {
    const wrap = zjb.global("document").call("querySelector", .{zjb.constString(wrap_sel)}, zjb.Handle);
    if (wrap == .null) return;
    defer wrap.release();
    const s = dom.attrOf(wrap, "data-pool");
    defer gpa.free(s);
    state.setPool(s);
    island.render();
    fetch();
}

fn changed() void {
    if (state.adding) |x| {
        state.adding = null;
        ask(x);
    }
}

/// ui-pool.wasm adds it, then hands the pool back
fn ask(x: pp.Pick) void {
    var buf: [8]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    pp.write(&.{x}, &w) catch return;
    const wrap = zjb.global("document").call("querySelector", .{zjb.constString(wrap_sel)}, zjb.Handle);
    if (wrap == .null) return;
    defer wrap.release();
    const v = zjb.string(w.buffered());
    defer v.release();
    wrap.call("setAttribute", .{ zjb.constString("data-add"), v }, void);
    const e = zjb.global("Event").new(.{zjb.constString("ui-pool-add")});
    defer e.release();
    zjb.global("window").call("dispatchEvent", .{e}, void);
}

/// The next file the page needs; ctx: the id, plus 1 << 16 for a main's
fn fetch() void {
    if (asked) return;
    const n = state.need() orelse return;
    const c = pp.indexOf(&data, n.id) orelse return;
    const slug = data.champs[c].slug;
    const path = (if (n.main) gpa.print("data/pool/{s}.bin", .{slug}) else gpa.print("data/pool/lanes/{s}.bin", .{slug})) catch return;
    defer gpa.free(path);
    asked = true;
    dom.fetch(path, @as(i32, n.id) | (@as(i32, @intFromBool(n.main)) << 16), loaded);
}

/// Decoded into gpa with its bytes kept (slices may point into them): files stay for
/// the page's life
fn loaded(ctx: i32, bytes: ?[]u8) void {
    asked = false;
    const id: u16 = @intCast(ctx & 0xffff);
    if (ctx >> 16 != 0) state.loadedMain(id, decoded(pd.File, bytes)) else state.loadedLanes(id, decoded(pd.Lanes, bytes));
    island.render();
    fetch();
}

fn decoded(comptime T: type, bytes: ?[]u8) ?*const T {
    const b = bytes orelse return null;
    const f = gpa.create(T) catch return null;
    f.* = ui.data.decode(gpa, T, b) catch {
        dom.dom.warn("poolgrid: bad file");
        gpa.destroy(f);
        gpa.free(b);
        return null;
    };
    return f;
}
