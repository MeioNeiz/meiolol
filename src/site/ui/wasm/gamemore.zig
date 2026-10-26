//! ui-gamemore.wasm: the game page's inspector and objectives row (ui.gamepage.GameMore).
//! ui-games.wasm adds its loader (ui-gamemore.js) to the page, which calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const gp = ui.gamepage;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;
const sel = "[data-island=gamemore]";

var data: ui.gamedata.Data = undefined;
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
    dom.fetch(src, 0, loaded);
}

fn loaded(_: i32, bytes: ?[]u8) void {
    const b = bytes orelse return dom.dom.warn("gamemore: no data");
    if (ui.gamedata.stamp(b) != want) return dom.dom.warn("gamemore: the page and its data differ");
    data = ui.data.decode(gpa, ui.gamedata.Data, b) catch return dom.dom.warn("gamemore: bad data");
    // Each its own prepared games: the server's stays as rendered for hydration
    server = init() catch return dom.dom.warn("gamemore: out of memory");
    state = init() catch return dom.dom.warn("gamemore: out of memory");
    _ = dom.rt.add(gp.GameMore, &state, &server, sel) catch return dom.dom.warn("gamemore: out of memory");
}

fn init() !gp.GameMore {
    var s: gp.GamePage = try .init(gpa, &data);
    s.src = src;
    s.stamp = want;
    return .{ .s = s, .js = js, .wasm = wasm };
}
