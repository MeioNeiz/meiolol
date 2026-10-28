//! ui-learn.wasm: the Learn page (ui.learnpage.Page) from its data-bin, progress from
//! and to localStorage (meiolol.learn.v2). zjb's generated loader (ui-learn.js,
//! `<script src data-wasm>`) calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const lp = ui.learnpage;

pub const panic = zjb.panic;
pub const url_map: dom.UrlMap = .learn;

const gpa = std.heap.wasm_allocator;
const key = "meiolol.learn.v2";

var data: ui.learndata.Data = undefined;
var state: lp.Page = undefined;
var server: lp.Page = undefined;

export fn main() void {
    dom.start();
    dom.normalise();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(lp.sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    const b = dom.binOf(root, "data-bin") orelse return dom.dom.warn("learn: no data");
    data = ui.data.decode(gpa, ui.learndata.Data, b) catch return dom.dom.warn("learn: bad data");
    server = .init(gpa, &data);
    state = .init(gpa, &data);
    _ = dom.rt.add(lp.Page, &state, &server, lp.sel) catch return dom.dom.warn("learn: out of memory");
    dom.rt.changed = save;
    // Last: blocked storage throws, ending this call with the page already live
    if (dom.stored(key)) |s| {
        state.progress = ui.learndata.Progress.parse(gpa, s) catch return;
        dom.rt.popstate();
    }
}

fn save() void {
    if (!state.dirty) return;
    state.dirty = false;
    var out: std.Io.Writer.Allocating = .init(gpa);
    defer out.deinit();
    state.progress.write(&out.writer) catch return;
    dom.store(key, out.written());
}
