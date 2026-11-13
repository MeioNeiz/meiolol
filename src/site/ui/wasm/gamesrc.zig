//! The game page's data for each of its wasm files: the example's file (the island's
//! data-src), which the server rendered, and for a looked-up player's game
//! (gamedata.Lookup) that game from the API too, shown in place of the example. The
//! island stays hidden until its game is in, so the example never shows under a lookup.
//! #example=<role> loads that role's example file the same way, in place of the
//! default's. Another lookup or role in the fragment (a scoreboard seat's link, Back)
//! loads the page again: ui-gamemore.wasm listens, which holds the links
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
var role_buf: [128]u8 = undefined;
/// The example's role file to show in place of data-src's (`load`)
var role_src: ?[]const u8 = null;
var stamp_s: []const u8 = "";
var want: u32 = 0;
var then: *const fn (bool) void = undefined;

var at_buf: [1024]u8 = undefined;
var at_read = false;
var at: gd.Ask = .{};

/// The fragment's lookup or example role as the page loaded: another reloads it
/// (`follow`), so it holds for the page's life
pub fn ask() gd.Ask {
    if (!at_read) at = gd.Ask.of(dom.dom.hash(&at_buf));
    at_read = true;
    return at;
}

/// The example's role file beside `src`, unless it is `src`
fn roleOf(src: []const u8, r: []const u8) ?[]const u8 {
    const dir = src[0 .. (std.mem.findScalarLast(u8, src, '/') orelse return null) + 1];
    const n = dir.len + r.len + ".bin".len;
    if (n > role_buf.len) return null;
    @memcpy(role_buf[0..dir.len], dir);
    @memcpy(role_buf[dir.len..][0..r.len], r);
    @memcpy(role_buf[dir.len + r.len ..][0..4], ".bin");
    return if (ui.tree.eql(role_buf[0..n], src)) null else role_buf[0..n];
}

/// Load the page again on another lookup or example role in the fragment
pub fn follow() void {
    _ = ask();
    const f = zjb.fnHandle("gameHash", &onHash);
    const w = zjb.global("window");
    w.call("addEventListener", .{ zjb.constString("popstate"), f }, void);
    w.call("addEventListener", .{ zjb.constString("hashchange"), f }, void);
}

fn onHash(e: zjb.Handle) callconv(.c) void {
    const s = zjb.scope();
    defer s.end();
    e.release();
    var buf: [1024]u8 = undefined;
    const same = gd.Ask.of(dom.dom.hash(&buf)).eql(ask());
    if (!same) zjb.global("location").call("reload", .{}, void);
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
/// names the file in warnings; `stamp_n`: `stamp` parsed
pub fn load(label: []const u8, selector: []const u8, src: []const u8, stamp: []const u8, stamp_n: u32, done: *const fn (bool) void) void {
    name = label;
    sel = selector;
    want = stamp_n;
    then = done;
    stamp_s = stamp;
    const q = ask();
    role_src = if (q.example) |r| roleOf(src, r) else null;
    if (q.look != null or role_src != null) hide(sel);
    dom.fetchStamped(src, stamp, 0, loaded);
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
    if (ask().look) |l| if (l.frag(&buf, ui.gamepage.all_games)) |to| {
        const s = zjb.string(to);
        defer s.release();
        zjb.global("location").call("replace", .{s}, void);
    };
    then(false);
}

fn loaded(_: i32, bytes: ?[]u8) void {
    const b = bytes orelse return fail("no data");
    // A page cached from an older build than its data: leave it as rendered
    if (gd.stamp(b) != want) return fail("the page and its data differ");
    server = ui.data.decode(gpa, gd.Data, b) catch return fail("bad data");
    var buf: [1024]u8 = undefined;
    const l = ask().look orelse {
        const p = role_src orelse return then(true);
        return dom.fetchStamped(p, stamp_s, 2, lookedUp);
    };
    const url = l.api(&buf) orelse return fail("no looked-up game");
    dom.fetch(url, 1, lookedUp);
}

/// ctx 2: the example's role file, which on failure leaves the default role's as rendered
fn lookedUp(ctx: i32, bytes: ?[]u8) void {
    if (decoded(bytes)) {
        shown = &looked_up;
        then(true);
    } else if (ctx == 2) {
        dom.dom.warn("no example for that role");
        then(true);
    } else fail("no looked-up game");
}

fn decoded(bytes: ?[]u8) bool {
    looked_up = ui.data.decode(gpa, gd.Data, bytes orelse return false) catch return false;
    return looked_up.games.len > 0;
}
