//! ui-adminlab.wasm: the Models tab's Neural nets and Lab campaigns (ui.adminlab.Lab).
//! ui-admin.wasm adds its loader (ui-adminlab.js), which calls `main`. Fetches
//! training/training.bin once the island shows, again after a failure when it shows next
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const Held = @import("held.zig").Held;
const al = ui.adminlab;
const md = ui.modelsdata;

pub const panic = zjb.panic;

var state: al.Lab = .{};
var server: al.Lab = .{};
var island: ?*ui.island.Island(al.Lab, dom.Dom) = null;

var training: Held(md.Training) = .{};
var asked = false;

export fn main() void {
    dom.start();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(al.sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    // As the server rendered them, so hydration matches
    server.js = dom.attrOf(root, "data-js");
    server.wasm = dom.attrOf(root, "data-wasm");
    state.js = server.js;
    state.wasm = server.wasm;
    island = dom.rt.add(al.Lab, &state, &server, al.sel) catch return dom.dom.warn("adminlab: out of memory");
    dom.rt.changed = changed;
    changed();
}

fn changed() void {
    if (!state.shows() or asked) return;
    asked = true;
    dom.fetch("/admin/training/training.bin", 0, done);
}

fn done(_: i32, bytes: ?[]u8) void {
    defer if (island) |i| i.render();
    state.training = if (bytes) |b| training.set(b) else null;
    state.failed = state.training == null;
    if (state.failed) asked = false;
}
