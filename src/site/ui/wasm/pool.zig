//! ui-pool.wasm: the pool page (ui.poolpage.Page) from its data-bin; the main's file
//! (data/pool/<slug>.bin) fetched when the main changes; the pool from localStorage
//! (meiolol.pool.v1) when the URL has none, and to it when the visitor changes it (a
//! shared link or Back never overwrites it). zjb's generated loader
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
/// The page's file: decoded into the arena, its strings in the fetched bytes
var held: ?struct { arena: std.heap.ArenaAllocator, bytes: []u8 } = null;

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
        island.render();
        dom.rt.syncHash(false) catch {};
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
    var arena: std.heap.ArenaAllocator = .init(gpa);
    const f = if (bytes) |b| decoded(arena.allocator(), b) else null;
    state.loaded(id, f);
    // One file kept: the page's new one replaces the last, or a refused one goes
    if (f != null and state.file == f) {
        if (held) |*x| {
            x.arena.deinit();
            gpa.free(x.bytes);
        }
        held = .{ .arena = arena, .bytes = bytes.? };
    } else {
        arena.deinit();
        if (bytes) |b| gpa.free(b);
    }
    island.render();
    // The main may have changed while this was out
    fetchMain();
}

fn decoded(a: std.mem.Allocator, b: []const u8) ?*const ui.pooldata.File {
    const f = a.create(ui.pooldata.File) catch return null;
    f.* = ui.data.decode(a, ui.pooldata.File, b) catch {
        dom.dom.warn("pool: bad file");
        return null;
    };
    return f;
}

fn save() void {
    if (!state.dirty) return;
    state.dirty = false;
    var buf: [32]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    state.write(&w) catch return;
    dom.store(key, w.buffered());
}
