//! ui-daily.wasm: the Daily Draft page (ui.dailypage.Page) from its data-bin, answers from
//! and to localStorage (meiolol.daily.v1, Home and the days strip read it too). Once
//! answered it loads ui-dailyseat.wasm (the seat review) and tells it of each seat picked
//! on the board. zjb's generated loader (ui-daily.js, `<script src data-wasm>`) calls
//! `main`
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
    dom.rt.changed = changed;
    // Last: blocked storage throws, ending this call with the page already live
    if (dom.stored(key)) |s| {
        state.restore(s);
        i.render();
        seat();
    }
}

fn changed() void {
    // First: save's storage may throw
    seat();
    save();
}

var told: ?u8 = null;
var loaded = false;

/// Once answered, the seat review's island: loaded, then told of each new seat (it reads
/// the root's data-seat)
fn seat() void {
    if (state.phase() != .done or told == state.seat) return;
    if (!loaded) {
        loaded = true;
        dom.script(ui.dailyseat.sel);
    }
    told = state.seat;
    const e = zjb.global("Event").new(.{zjb.constString("ui-daily-seat")});
    defer e.release();
    zjb.global("window").call("dispatchEvent", .{e}, void);
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
    var out = "0000-00-00".*;
    digits(out[0..4], d.call("getFullYear", .{}, i32));
    digits(out[5..7], d.call("getMonth", .{}, i32) + 1);
    digits(out[8..10], d.call("getDate", .{}, i32));
    return out;
}

fn digits(out: []u8, v: i32) void {
    var x: u32 = @intCast(std.math.clamp(v, 0, 9999));
    var i = out.len;
    while (i > 0) : (x /= 10) {
        i -= 1;
        out[i] = '0' + @as(u8, @intCast(x % 10));
    }
}
