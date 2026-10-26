//! ui-practice.wasm: practice's bar and picker (ui/practice.zig), on the app's page only
//! while practice is on. Adopts the shell's render with the practice.bin it was made
//! from, refetches the file on each `{"app": seq}` as ui-app.wasm does, and takes clicks
//! on the board's data-act elements (ui-app.wasm's DOM) from a listener on the document
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const pr = ui.practice;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;

var state: pr.Practice = undefined;
var server: pr.Practice = undefined;
var island: ?*ui.island.Island(pr.Practice, dom.Dom) = null;
var held: ?Held = null;
var page_seq: u32 = 0;
var wanted: u32 = 0;

const Held = struct { arena: std.heap.ArenaAllocator, bytes: []u8 };

export fn main() void {
    dom.start();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(pr.sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    page_seq = std.fmt.parseInt(u32, dom.attrOf(root, "data-seq"), 10) catch return;
    wanted = page_seq;
    const window = zjb.global("window");
    window.call("addEventListener", .{ zjb.constString("meiolol"), zjb.fnHandle("practiceMessage", &onMessage) }, void);
    // Capture: before ui-app.wasm's own listeners on its root
    zjb.global("document").call("addEventListener", .{ zjb.constString("click"), zjb.fnHandle("practiceAct", &onClick), true }, void);
    ui.toshell.out = toShell;
    get();
}

/// As ui-app.wasm's: a page outside the shell has no bridge
fn toShell(json: []const u8) void {
    const window = zjb.global("window");
    if (!window.call("hasOwnProperty", .{zjb.constString("meiolol")}, bool)) return;
    const text = zjb.string(json);
    defer text.release();
    const m = zjb.global("JSON").call("parse", .{text}, zjb.Handle);
    defer m.release();
    const bridge = window.get("meiolol", zjb.Handle);
    defer bridge.release();
    bridge.call("send", .{m}, void);
}

fn onClick(e: zjb.Handle) callconv(.c) void {
    defer e.release();
    const i = island orelse return;
    const target = e.get("target", zjb.Handle);
    defer target.release();
    if (target == .null) return;
    const el = target.call("closest", .{zjb.constString("[data-act]")}, zjb.Handle);
    if (el == .null) return;
    defer el.release();
    const act = pr.Act.parse(dom.attrOf(el, "data-act")) orelse return;
    state.act(act);
    i.render();
    if (act == .seat) focusSearch();
}

/// The picker opened from the board: no island event to set ev.after
fn focusSearch() void {
    const input = zjb.global("document").call("querySelector", .{zjb.constString(pr.sel ++ " [data-ref=search]")}, zjb.Handle);
    if (input == .null) return;
    defer input.release();
    input.call("focus", .{}, void);
}

fn get() void {
    var buf: [40]u8 = undefined;
    dom.fetch(std.fmt.bufPrint(&buf, "practice.bin?{d}", .{wanted}) catch return, 0, loaded);
}

fn onMessage(e: zjb.Handle) callconv(.c) void {
    defer e.release();
    const detail = e.get("detail", zjb.Handle);
    defer detail.release();
    if (detail == .null) return;
    const n = detail.get("app", f64);
    if (!(n > @as(f64, @floatFromInt(wanted)) and n < 4e9)) return;
    wanted = @intFromFloat(n);
    get();
}

fn loaded(_: i32, got: ?[]u8) void {
    const b = got orelse return dom.dom.warn("practice: no data");
    var arena: std.heap.ArenaAllocator = .init(gpa);
    const d = ui.data.decode(arena.allocator(), pr.Data, b) catch {
        arena.deinit();
        gpa.free(b);
        return dom.dom.warn("practice: bad data");
    };
    // Stale, or the page is older than the file: ui-app.wasm reloads it
    if (d.seq < wanted or island == null and d.seq != page_seq) {
        arena.deinit();
        return gpa.free(b);
    }
    const old = held;
    held = .{ .arena = arena, .bytes = b };
    if (island) |i| {
        state.data = d;
        i.render();
    } else {
        server = .{ .data = d };
        state = server;
        island = dom.rt.add(pr.Practice, &state, &server, pr.sel) catch return dom.dom.warn("practice: out of memory");
    }
    if (old) |o| {
        var x = o;
        x.arena.deinit();
        gpa.free(x.bytes);
    }
}
