//! The game page's data for each of its wasm files: the example's file (the island's
//! data-src), which the server rendered, and for a looked-up player's game
//! (gamedata.Lookup) that game from the API too, shown in place of the example. The
//! island stays hidden until its game is in, so the example never shows under a lookup
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const gd = ui.gamedata;

const gpa = std.heap.wasm_allocator;

/// What the server rendered
pub var server: gd.Data = undefined;
/// The game to show: `server` itself unless a lookup
pub var shown: *const gd.Data = &server;
var looked_up: gd.Data = undefined;

var name: []const u8 = "";
var sel: []const u8 = "";
var want: u32 = 0;
var then: *const fn (bool) void = undefined;

pub fn lookup() ?gd.Lookup {
    var buf: [1024]u8 = undefined;
    return gd.Lookup.ofHash(dom.dom.hash(&buf));
}

/// Hide the island under `selector` while a lookup's game loads; shown again by `ready`
pub fn hide(selector: []const u8) void {
    style(selector, "hidden");
}

fn style(selector: []const u8, v: []const u8) void {
    const q = zjb.string(selector);
    defer q.release();
    const el = zjb.global("document").call("querySelector", .{q}, zjb.Handle);
    if (el == .null) return;
    defer el.release();
    const st = el.get("style", zjb.Handle);
    defer st.release();
    const s = zjb.string(v);
    defer s.release();
    st.set("visibility", s);
}

/// Fetch the island's data, then call `done(true)` with `server` and `shown` set (it
/// calls `ready` once its runtime holds them), or `done(false)` after a warning. `label`
/// names the file in warnings
pub fn load(label: []const u8, selector: []const u8, src: []const u8, stamp: u32, done: *const fn (bool) void) void {
    name = label;
    sel = selector;
    want = stamp;
    then = done;
    if (lookup() != null) hide(sel);
    dom.fetch(src, 0, loaded);
}

pub fn ready() void {
    style(sel, "");
}

/// Under a lookup, to the player's Your games page: the game is gone from the cache (30
/// days not looked up), they opted out or the API is down, and that page says which (a
/// visit fetches their games again)
fn fail(comptime what: []const u8) void {
    var buf: [1024]u8 = undefined;
    dom.dom.warn(std.fmt.bufPrint(&buf, "{s}: " ++ what, .{name}) catch what);
    if (lookup()) |l| if (std.fmt.bufPrint(&buf, "{s}#id={s}&game={d}", .{ ui.gamepage.all_games, l.id, l.start })) |to| {
        const s = zjb.string(to);
        defer s.release();
        zjb.global("location").call("replace", .{s}, void);
    } else |_| {};
    then(false);
}

fn loaded(_: i32, bytes: ?[]u8) void {
    const b = bytes orelse return fail("no data");
    // A page cached from an older build than its data: leave it as rendered
    if (gd.stamp(b) != want) return fail("the page and its data differ");
    server = ui.data.decode(gpa, gd.Data, b) catch return fail("bad data");
    const l = lookup() orelse return then(true);
    var buf: [1024]u8 = undefined;
    const url = l.api(&buf) orelse return fail("no looked-up game");
    dom.fetch(url, 1, lookedUp);
}

fn lookedUp(_: i32, bytes: ?[]u8) void {
    const b = bytes orelse return fail("no looked-up game");
    looked_up = ui.data.decode(gpa, gd.Data, b) catch return fail("no looked-up game");
    if (looked_up.games.len == 0) return fail("no looked-up game");
    shown = &looked_up;
    then(true);
}
