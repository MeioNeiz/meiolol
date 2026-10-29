//! ui-adminmodels.wasm: the admin page's Models tab (ui.adminmodels.Models). ui-admin.wasm
//! adds its loader (ui-adminmodels.js), which calls `main`. Fetches models.bin and
//! training/training.bin once the tab shows: both change at most each web round or lab push,
//! so Refresh fetches them again
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const Held = @import("held.zig").Held;
const am = ui.adminmodels;
const md = ui.modelsdata;

pub const panic = zjb.panic;

var state: am.Models = .{};
var server: am.Models = .{};
var island: ?*ui.island.Island(am.Models, dom.Dom) = null;

var models: Held(md.Models) = .{};
var training: Held(md.Training) = .{};
var asked = false;

const Call = enum(i32) { models, training };

export fn main() void {
    dom.start();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(am.sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    // As the server rendered them, so hydration matches
    server.js = dom.attrOf(root, "data-js");
    server.wasm = dom.attrOf(root, "data-wasm");
    state.js = server.js;
    state.wasm = server.wasm;
    island = dom.rt.add(am.Models, &state, &server, am.sel) catch return dom.dom.warn("adminmodels: out of memory");
    dom.rt.changed = changed;
    changed();
}

/// The tab came up (the URL): its data, once
fn changed() void {
    if (!state.shows() or asked) return;
    asked = true;
    dom.fetch("models.bin", @backingInt(Call.models), done);
    dom.fetch("training/training.bin", @backingInt(Call.training), done);
}

fn done(ctx: i32, bytes: ?[]u8) void {
    defer if (island) |i| i.render();
    switch (std.enums.fromInt(Call, ctx) orelse return) {
        .models => {
            state.models = if (bytes) |b| models.set(b) else null;
            state.models_failed = state.models == null;
        },
        .training => {
            state.training = if (bytes) |b| training.set(b) else null;
            state.training_failed = state.training == null;
        },
    }
}
