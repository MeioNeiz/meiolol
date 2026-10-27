//! ui-gamelane.wasm: the game page's Lane and Build cards (ui.gamepage.GameLane).
//! ui-games.wasm adds its loader (ui-gamelane.js) to the page, which calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const gamesrc = @import("gamesrc.zig");
const gp = ui.gamepage;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;
const sel = "[data-island=gamelane]";

var state: gp.GameLane = undefined;
var server: gp.GameLane = undefined;
var src: []const u8 = "";
var js: []const u8 = "";
var wasm: []const u8 = "";
var want: u32 = 0;

export fn main() void {
    dom.start();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    src = dom.attrOf(root, "data-src");
    js = dom.attrOf(root, "data-js");
    wasm = dom.attrOf(root, "data-wasm");
    want = std.fmt.parseInt(u32, dom.attrOf(root, "data-stamp"), 10) catch return;
    gamesrc.load("gamelane", sel, src, want, loaded);
}

fn loaded(ok: bool) void {
    if (!ok) return;
    // Each its own: the server's stays as rendered for hydration
    server = init(&gamesrc.server) catch return dom.dom.warn("gamelane: out of memory");
    state = init(gamesrc.shown) catch return dom.dom.warn("gamelane: out of memory");
    _ = dom.rt.add(gp.GameLane, &state, &server, sel) catch return dom.dom.warn("gamelane: out of memory");
    gamesrc.ready();
}

fn init(data: *const ui.gamedata.Data) !gp.GameLane {
    return .{ .a = gpa, .data = data, .src = src, .stamp = want, .js = js, .wasm = wasm };
}
