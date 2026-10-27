//! ui-gamemore.wasm: the game page's inspector and objectives row (ui.gamepage.GameMore).
//! ui-games.wasm adds its loader (ui-gamemore.js) to the page, which calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const gamesrc = @import("gamesrc.zig");
const gp = ui.gamepage;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;
const sel = "[data-island=gamemore]";

var state: gp.GameMore = undefined;
var server: gp.GameMore = undefined;
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
    gamesrc.load("gamemore", sel, src, want, loaded);
}

fn loaded(ok: bool) void {
    if (!ok) return;
    // Each its own prepared games: the server's stays as rendered for hydration
    server = init(&gamesrc.server) catch return dom.dom.warn("gamemore: out of memory");
    state = init(gamesrc.shown) catch return dom.dom.warn("gamemore: out of memory");
    _ = dom.rt.add(gp.GameMore, &state, &server, sel) catch return dom.dom.warn("gamemore: out of memory");
    gamesrc.ready();
}

fn init(data: *const ui.gamedata.Data) !gp.GameMore {
    var s: gp.GamePage = try .init(gpa, data);
    s.src = src;
    s.stamp = want;
    return .{ .s = s, .js = js, .wasm = wasm };
}
