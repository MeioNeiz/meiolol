//! ui-games.wasm: the game page's first screen (ui.gamepage.GamePage), and the loader of
//! ui-gamemore.wasm and ui-gamelane.wasm for the rest. zjb's generated loader (ui-games.js, `<script src
//! data-wasm>`) calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const gamesrc = @import("gamesrc.zig");
const gp = ui.gamepage;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;
const sel = "[data-island=games]";
const lazy = [_][]const u8{ "[data-island=gamemore]", "[data-island=gamelane]" };

var state: gp.GamePage = undefined;
var server: gp.GamePage = undefined;
var src: []const u8 = "";
var want: u32 = 0;

export fn main() void {
    dom.start();
    dom.lazyLoad(&lazy);
    // Theirs load later: hidden from now, not from when they start
    if (gamesrc.lookup() != null) for (lazy) |l| gamesrc.hide(l);
    const root = zjb.global("document").call("querySelector", .{zjb.constString(sel)}, zjb.Handle);
    if (root == .null) return dom.lazyLater();
    defer root.release();
    src = dom.attrOf(root, "data-src");
    want = std.fmt.parseInt(u32, dom.attrOf(root, "data-stamp"), 10) catch return dom.lazyLater();
    gamesrc.load("games", sel, src, want, loaded);
}

fn loaded(ok: bool) void {
    defer dom.lazyLater();
    if (!ok) return;
    // Each its own prepared games: the server's stays as rendered for hydration
    server = init(&gamesrc.server) catch return dom.dom.warn("games: out of memory");
    state = init(gamesrc.shown) catch return dom.dom.warn("games: out of memory");
    // A lookup's "all games" is that player's
    if (gamesrc.lookup()) |l| state.all = std.fmt.allocPrint(gpa, "{s}#id={s}", .{ gp.all_games, l.id }) catch state.all;
    _ = dom.rt.add(gp.GamePage, &state, &server, sel) catch return dom.dom.warn("games: out of memory");
    gamesrc.ready();
}

fn init(data: *const ui.gamedata.Data) !gp.GamePage {
    var p: gp.GamePage = try .init(gpa, data);
    p.all = gp.all_games;
    p.src = src;
    p.stamp = want;
    return p;
}
