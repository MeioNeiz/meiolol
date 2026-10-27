//! ui-pool.wasm: the pool page (ui.poolpage.Page) from its data-bin; the main's file
//! (data/pool/<slug>.bin) fetched when the main changes; the pool from and to
//! localStorage (meiolol.pool.v1) when the URL has none. zjb's generated loader
//! (ui-pool.js, `<script src data-wasm>`) calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const pp = ui.poolpage;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;
const key = "meiolol.pool.v1";

var data: pp.Data = undefined;
var state: pp.Page = undefined;
var server: pp.Page = undefined;
var island: *ui.island.Island(pp.Page, dom.Dom) = undefined;
/// The champion whose file is being fetched
var asked: ?u16 = null;
/// The pool as last stored
var saved: [32]u8 = undefined;
var saved_len: usize = 0;

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
    if (state.n > 0) return changed();
    // Last: blocked storage throws, ending this call with the page already live
    if (dom.stored(key)) |s| {
        state.read(s);
        remember(s);
        island.render();
        changed();
    }
}

fn changed() void {
    fetchMain();
    save();
}

fn fetchMain() void {
    const id = state.need() orelse return;
    if (asked != null) return;
    const c = pp.indexOf(&data, id) orelse return;
    const path = gpa.print("data/pool/{s}.bin", .{data.champs[c].slug}) catch return;
    defer gpa.free(path);
    asked = id;
    dom.fetch(path, id, loaded);
}

fn loaded(ctx: i32, bytes: ?[]u8) void {
    const id: u16 = @intCast(ctx);
    asked = null;
    var f: ?*const ui.pooldata.File = null;
    if (bytes) |b| if (ui.data.decode(gpa, ui.pooldata.File, b)) |v| {
        const p = gpa.create(ui.pooldata.File) catch return;
        p.* = v;
        f = p;
    } else |_| dom.dom.warn("pool: bad file");
    state.loaded(id, f);
    island.render();
    // The main may have changed while this was out
    fetchMain();
}

fn save() void {
    var buf: [32]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    state.write(&w) catch return;
    const s = w.buffered();
    if (std.mem.eql(u8, s, saved[0..saved_len])) return;
    remember(s);
    dom.store(key, s);
}

fn remember(s: []const u8) void {
    saved_len = @min(s.len, saved.len);
    @memcpy(saved[0..saved_len], s[0..saved_len]);
}
