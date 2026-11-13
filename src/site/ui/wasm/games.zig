//! ui-games.wasm: the game page's first screen (ui.gamepage.GamePage), and the loader of
//! ui-gamemore.wasm and ui-gamelane.wasm for the rest. zjb's generated loader (ui-games.js, `<script src
//! data-wasm>`) calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const gamesrc = @import("gamesrc.zig");
const gp = ui.gamepage;

/// zjb.panic's throw without its console line: the thrown message says it (40 B of budget)
pub fn panic(msg: []const u8, _: ?*std.lang.StackTrace, _: ?usize) noreturn {
    zjb.throwAndRelease(zjb.string(msg));
}

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
    const q = gamesrc.ask();
    if (q.look != null or q.example != null) for (lazy) |l| gamesrc.hide(l);
    const root = zjb.global("document").call("querySelector", .{zjb.constString(sel)}, zjb.Handle);
    if (root == .null) return dom.lazyLater();
    defer root.release();
    src = dom.attrOf(root, "data-src");
    const stamp = dom.attrOf(root, "data-stamp");
    want = std.fmt.parseInt(u32, stamp, 10) catch return dom.lazyLater();
    gamesrc.load("games", sel, src, stamp, want, loaded);
}

fn loaded(ok: bool) void {
    defer dom.lazyLater();
    if (!ok) return;
    // Each its own prepared games: the server's stays as rendered for hydration
    server = init(&gamesrc.server) catch return dom.dom.warn("games: out of memory");
    state = init(gamesrc.shown) catch return dom.dom.warn("games: out of memory");
    // A lookup's "all games" is that player's, an example role's (its file in) that role's
    const q = gamesrc.ask();
    const kv: ?[2][]const u8 = if (q.look) |l| .{ "#id=", l.id } else if (gamesrc.shown != &gamesrc.server) .{ "#example=", q.example.? } else null;
    if (kv) |x| state.all = std.mem.concat(gpa, u8, &.{ gp.all_games, x[0], x[1] }) catch state.all;
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
