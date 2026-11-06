//! ui-teams.wasm: champ select's Teams card (ui/compview.zig Teams) under the board.
//! Adopts the shell's render with the teams.bin it was made from and refetches the file
//! on each `{"app": seq}` as ui-app.wasm does, so a lock never reloads the page
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const cv = ui.compview;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;

var state: cv.Teams = undefined;
var server: cv.Teams = undefined;
var island: ?*ui.island.Island(cv.Teams, dom.Dom) = null;
var held: ?Held = null;
var page_seq: u32 = 0;
var wanted: u32 = 0;

const Held = struct { arena: std.heap.ArenaAllocator, bytes: []u8 };

export fn main() void {
    dom.start();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(cv.sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    page_seq = std.fmt.parseInt(u32, dom.attrOf(root, "data-seq"), 10) catch return;
    wanted = page_seq;
    zjb.global("window").call("addEventListener", .{ zjb.constString("meiolol"), zjb.fnHandle("teamsMessage", &onMessage) }, void);
    get();
}

fn get() void {
    var buf: [26]u8 = undefined;
    const n = ui.fmt.decimal(&buf, wanted, false);
    var url: [36]u8 = undefined;
    @memcpy(url[0..10], "teams.bin?");
    @memcpy(url[10..][0..n.len], n);
    dom.fetch(url[0 .. 10 + n.len], 0, loaded);
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
    const b = got orelse return dom.dom.warn("teams: no data");
    var arena: std.heap.ArenaAllocator = .init(gpa);
    const d = ui.data.decode(arena.allocator(), cv.Data, b) catch {
        arena.deinit();
        gpa.free(b);
        return dom.dom.warn("teams: bad data");
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
        island = dom.rt.add(cv.Teams, &state, &server, cv.sel) catch return dom.dom.warn("teams: out of memory");
    }
    if (old) |o| {
        var x = o;
        x.arena.deinit();
        gpa.free(x.bytes);
    }
}
