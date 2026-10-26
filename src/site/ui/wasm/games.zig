//! ui-games.wasm: the game page's first screen (ui.gamepage.GamePage), and the loader of
//! ui-gamemore.wasm and ui-gamelane.wasm for the rest. zjb's generated loader (ui-games.js, `<script src
//! data-wasm>`) calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const gp = ui.gamepage;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;
const sel = "[data-island=games]";
const lazy = [_][]const u8{ "[data-island=gamemore]", "[data-island=gamelane]" };

var data: ui.gamedata.Data = undefined;
var state: gp.GamePage = undefined;
var server: gp.GamePage = undefined;
var src: []const u8 = "";
var want: u32 = 0;

export fn main() void {
    dom.start();
    dom.lazyLoad(&lazy);
    const root = zjb.global("document").call("querySelector", .{zjb.constString(sel)}, zjb.Handle);
    if (root == .null) return dom.lazyLater();
    defer root.release();
    src = dom.attrOf(root, "data-src");
    want = std.fmt.parseInt(u32, dom.attrOf(root, "data-stamp"), 10) catch return dom.lazyLater();
    dom.fetch(src, 0, loaded);
}

fn loaded(_: i32, bytes: ?[]u8) void {
    defer dom.lazyLater();
    const b = bytes orelse return dom.dom.warn("games: no data");
    // A page cached from an older build than its data: leave it as rendered
    if (ui.gamedata.stamp(b) != want) return dom.dom.warn("games: the page and its data differ");
    data = ui.data.decode(gpa, ui.gamedata.Data, b) catch return dom.dom.warn("games: bad data");
    // Each its own prepared games: the server's stays as rendered for hydration
    server = init() catch return dom.dom.warn("games: out of memory");
    state = init() catch return dom.dom.warn("games: out of memory");
    _ = dom.rt.add(gp.GamePage, &state, &server, sel) catch return dom.dom.warn("games: out of memory");
}

fn init() !gp.GamePage {
    var p: gp.GamePage = try .init(gpa, &data);
    p.all = gp.all_games;
    p.src = src;
    p.stamp = want;
    return p;
}
