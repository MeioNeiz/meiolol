//! ui-tester.wasm: the Draft tester (ui.testerpage.Page) from its data-bin, the chosen
//! model's draft-model.bin fetched and scored here, the board from and to localStorage
//! (meiolol.tester.v1). zjb's generated loader (ui-tester.js, `<script src data-wasm>`)
//! calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const tp = ui.testerpage;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;
const key = "meiolol.tester.v1";

var head: tp.Head = undefined;
var index: ui.champsearch.Index = undefined;
var state: tp.Page = undefined;
var server: tp.Page = undefined;
var island: ?*ui.island.Island(tp.Page, dom.Dom) = null;
var loaded: std.enums.EnumArray(tp.Which, tp.Loaded) = undefined;

export fn main() void {
    dom.start();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(tp.sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    const b = dom.binOf(root, "data-bin") orelse return dom.dom.warn("tester: no data");
    head = ui.data.decode(gpa, tp.Head, b) catch return dom.dom.warn("tester: bad data");
    index = tp.index(gpa, &head) catch return dom.dom.warn("tester: out of memory");
    server = .init(&head, &index);
    state = .init(&head, &index);
    island = dom.rt.add(tp.Page, &state, &server, tp.sel) catch return dom.dom.warn("tester: out of memory");
    dom.rt.changed = changed;
    fetchShown();
    // Last: blocked storage throws, ending this call with the page already live
    if (dom.stored(key)) |s| {
        tp.restore(&state, s);
        fetchShown();
        if (island) |i| i.render();
    }
}

/// After each update: fetch a newly chosen model, save the board
fn changed() void {
    fetchShown();
    if (!state.dirty) return;
    state.dirty = false;
    var out: std.Io.Writer.Allocating = .init(gpa);
    defer out.deinit();
    tp.saved(&state, &out.writer) catch return;
    dom.store(key, out.written());
}

fn fetchShown() void {
    const w = state.which;
    if (state.loads.get(w) != .none) return;
    state.loads.set(w, .loading);
    dom.fetch(tp.infos.get(w).file, @backingInt(w), done);
}

fn done(ctx: i32, bytes: ?[]u8) void {
    const w = std.enums.fromInt(tp.Which, ctx) orelse return;
    const b = bytes orelse {
        state.loads.set(w, .missing);
        if (island) |i| i.render();
        return;
    };
    const l = loaded.getPtr(w);
    l.* = tp.Loaded.init(gpa, b) catch {
        dom.dom.warn("tester: bad model file");
        state.loads.set(w, .missing);
        if (island) |i| i.render();
        return;
    };
    // The file stays decoded: the model's slices point into it
    state.loads.set(w, .{ .ready = l });
    if (island) |i| i.render();
}
