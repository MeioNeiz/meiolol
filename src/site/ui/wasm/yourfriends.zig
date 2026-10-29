//! ui-yourfriends.wasm: the Your games page's Friends view (ui.yourfriends.YourFriends)
//! for the URL's Riot ID, from /api/friends.bin; asked again while older games or a
//! fetched friend's games are still coming, and on each new list (yk.event). Fetch asks
//! /api/list for the friend, as a lookup would. ui-yourviews.wasm adds its loader
//! (ui-yourfriends.js) once the view shows, which calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const yf = ui.yourfriends;
const yk = ui.yourlookup;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;

var page: yf.YourFriends = undefined;
var page0: yf.YourFriends = undefined;
var island: ?*ui.island.Island(yf.YourFriends, dom.Dom) = null;
/// Each player's: a late answer for an older one is dropped
var gen: u32 = 0;
var id_buf: [256]u8 = undefined;
var id: []const u8 = "";
/// An answer's, with its bytes; the one before stays until the next, as the last
/// render's tree still points into it
var arenas: [2]std.heap.ArenaAllocator = @splat(.init(gpa));
var cur: u1 = 0;

export fn main() void {
    dom.start();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(yf.sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    page0 = .{ .js = dom.attrOf(root, "data-js"), .wasm = dom.attrOf(root, "data-wasm") };
    page = page0;
    island = dom.rt.add(yf.YourFriends, &page, &page0, yf.sel) catch return dom.dom.warn("yourfriends: out of memory");
    dom.rt.changed = changed;
    zjb.global("window").call("addEventListener", .{ zjb.constString(yk.event), zjb.fnHandle("yourFriendsList", &onList) }, void);
    begin();
}

fn onList(e: zjb.Handle) callconv(.c) void {
    e.release();
    begin();
}

/// The URL's player, from the start
fn begin() void {
    var buf: [1024]u8 = undefined;
    const got = yk.idOf(dom.dom.hash(&buf)) orelse "";
    if (got.len > id_buf.len) return;
    @memcpy(id_buf[0..got.len], got);
    id = id_buf[0..got.len];
    gen +%= 1;
    page.reset(id.len > 0);
    page.now_ms = now();
    if (island) |i| i.render();
    if (id.len > 0) ask();
}

fn now() i64 {
    return @intFromFloat(zjb.global("Date").call("now", .{}, f64));
}

/// `id` is percent-encoded as the URL has it
fn ask() void {
    const path = std.fmt.allocPrint(gpa, "/api/friends.bin?id={s}", .{id}) catch return;
    defer gpa.free(path);
    dom.fetch(path, @bitCast(gen), answered);
}

/// Fetch's ctx: dom keeps one callback for every request in flight, so both come here
const fetched: i32 = -1;

fn answered(g: i32, bytes: ?[]u8) void {
    defer if (bytes) |b| gpa.free(b);
    if (g == fetched or @as(u32, @bitCast(g)) != gen) return;
    const f = if (bytes) |b| decode(b) else null;
    const again = page.answered(f);
    page.now_ms = now();
    if (island) |i| i.render();
    if (again) {
        const t = zjb.fnHandle("yourFriendsDue", &onDue).bind(.{g});
        defer t.release();
        zjb.global("window").call("setTimeout", .{ t, @as(i32, yf.poll_ms) }, void);
    }
}

fn decode(b: []const u8) ?*const yf.Friends {
    const next = cur +% 1;
    _ = arenas[next].reset(.free_all);
    const a = arenas[next].allocator();
    // Decoded strings point into the bytes
    const kept = a.dupe(u8, b) catch return null;
    const f = a.create(yf.Friends) catch return null;
    f.* = ui.data.decode(a, yf.Friends, kept) catch return null;
    cur = next;
    return f;
}

fn onDue(g: i32) callconv(.c) void {
    if (@as(u32, @bitCast(g)) == gen) ask();
}

/// Fetch: the friend's games, as a lookup of their Riot ID asks for them; the next
/// answer (asked again in poll_ms) shows them once cached
fn changed() void {
    const want = page.want orelse return;
    page.want = null;
    const q = ui.homepage.idQuery(gpa, want) catch return;
    defer gpa.free(q);
    const path = std.fmt.allocPrint(gpa, "/api/list?{s}&n=1", .{q}) catch return;
    defer gpa.free(path);
    dom.fetch(path, fetched, answered);
    const t = zjb.fnHandle("yourFriendsDue", &onDue).bind(.{@as(i32, @bitCast(gen))});
    defer t.release();
    zjb.global("window").call("setTimeout", .{ t, @as(i32, yf.poll_ms) }, void);
}
