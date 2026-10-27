//! ui-daily.wasm: the Daily Draft page (ui.dailypage.Page) from its data-bin, answers from
//! and to localStorage (meiolol.daily.v1, Home and the days strip read it too). zjb's
//! generated loader (ui-daily.js, `<script src data-wasm>`) calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const dp = ui.dailypage;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;
const key = "meiolol.daily.v1";

var data: ui.dailydata.Puzzle = undefined;
var state: dp.Page = undefined;
var server: dp.Page = undefined;

export fn main() void {
    dom.start();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(dp.sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    const b = dom.binOf(root, "data-bin") orelse return dom.dom.warn("daily: no data");
    data = ui.dailydata.decode(gpa, b) catch return dom.dom.warn("daily: bad data");
    if (!data.valid()) return dom.dom.warn("daily: bad data");
    server = .init(gpa, &data);
    state = .init(gpa, &data);
    const i = dom.rt.add(dp.Page, &state, &server, dp.sel) catch return dom.dom.warn("daily: out of memory");
    dom.rt.changed = save;
    // Last: blocked storage throws, ending this call with the page already live
    if (dom.stored(key)) |s| {
        state.restore(s);
        i.render();
    }
}

fn save() void {
    if (!state.dirty) return;
    state.dirty = false;
    const old = dom.stored(key) orelse "";
    const s = dp.write(gpa, old, data.n, state.saved(), &today()) catch return;
    defer gpa.free(s);
    dom.store(key, s);
    // The head's days strip (ui-dailydays.wasm) reads them again
    const e = zjb.global("Event").new(.{zjb.constString("ui-daily")});
    defer e.release();
    zjb.global("window").call("dispatchEvent", .{e}, void);
}

/// The viewer's own date, "2026-10-27": days in a row count puzzles finished on theirs
fn today() [10]u8 {
    const d = zjb.global("Date").new(.{});
    defer d.release();
    var out: [10]u8 = undefined;
    _ = std.fmt.bufPrint(&out, "{d:0>4}-{d:0>2}-{d:0>2}", .{
        @as(u32, @intCast(std.math.clamp(d.call("getFullYear", .{}, i32), 0, 9999))),
        @as(u32, @intCast(@max(d.call("getMonth", .{}, i32) + 1, 0))),
        @as(u32, @intCast(@max(d.call("getDate", .{}, i32), 0))),
    }) catch return "0000-00-00".*;
    return out;
}
