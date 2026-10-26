//! ui-app.wasm: the desktop app's page (ui/app.zig). Adopts the shell's render with the
//! app.bin it was made from, then on each `{"app": seq}` from the shell (bridge.js's
//! `meiolol` event) fetches the newer file and patches. What the page asks of the shell
//! (ui/toshell.zig) goes out through bridge.js's meiolol.send
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const app = ui.app;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;

var state: app.App = undefined;
var server: app.App = undefined;
var island: ?*ui.island.Island(app.App, dom.Dom) = null;
/// The decoded data and the file bytes its strings point into
var held: ?Held = null;
/// The page's own render, then the newest seq asked for: a stale answer is dropped
var page_seq: u32 = 0;
var wanted: u32 = 0;

const Held = struct { arena: std.heap.ArenaAllocator, bytes: []u8 };

export fn main() void {
    dom.start();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(app.sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    const seq = root.call("getAttribute", .{zjb.constString("data-seq")}, zjb.Handle);
    defer seq.release();
    var buf: [16]u8 = undefined;
    page_seq = std.fmt.parseInt(u32, seq.readString(&buf) catch return, 10) catch return;
    wanted = page_seq;
    zjb.global("window").call("addEventListener", .{ zjb.constString("meiolol"), zjb.fnHandle("appMessage", &onMessage) }, void);
    ui.toshell.send = toShell;
    get();
}

/// A page outside the shell (a dump in a browser) has no bridge
fn toShell(o: ui.toshell.Out) void {
    const window = zjb.global("window");
    if (!window.call("hasOwnProperty", .{zjb.constString("meiolol")}, bool)) return;
    var buf: [1024]u8 = undefined;
    defer std.crypto.secureZero(u8, &buf);
    var w: std.Io.Writer = .fixed(&buf);
    ui.toshell.json(o, &w) catch return;
    const text = zjb.string(w.buffered());
    defer text.release();
    const m = zjb.global("JSON").call("parse", .{text}, zjb.Handle);
    defer m.release();
    const bridge = window.get("meiolol", zjb.Handle);
    defer bridge.release();
    bridge.call("send", .{m}, void);
}

fn get() void {
    var buf: [32]u8 = undefined;
    dom.fetch(std.fmt.bufPrint(&buf, "app.bin?{d}", .{wanted}) catch return, 0, loaded);
}

/// Other messages (status) carry no `app`: NaN, never newer
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
    const b = got orelse return dom.dom.warn("app: no data");
    var arena: std.heap.ArenaAllocator = .init(gpa);
    const d = ui.data.decode(arena.allocator(), app.Data, b) catch {
        arena.deinit();
        gpa.free(b);
        return dom.dom.warn("app: bad data");
    };
    if (d.seq < wanted) {
        arena.deinit();
        return gpa.free(b);
    }
    const old = held;
    held = .{ .arena = arena, .bytes = b };
    if (island) |i| {
        state.data = d;
        i.render();
    } else {
        // The page was rendered from another state than the file's: render it afresh
        if (d.seq != page_seq) return zjb.global("location").call("reload", .{}, void);
        server = .{ .data = d };
        state = server;
        island = dom.rt.add(app.App, &state, &server, app.sel) catch return dom.dom.warn("app: out of memory");
    }
    if (old) |o| {
        var x = o;
        x.arena.deinit();
        gpa.free(x.bytes);
    }
}
