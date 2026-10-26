//! ui-champion.wasm: the champion page's head (ui.champpage.Top), and the loader of
//! ui-champbuild.wasm and ui-champmore.wasm for the rest. zjb's generated loader
//! (ui-champion.js, `<script src data-wasm>`) calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const cp = ui.champpage;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;
const sel = "[data-island=champion]";
/// The islands of the page's other files: their roots carry data-js and data-wasm
const lazy = [_][]const u8{ "[data-island=champbuild]", "[data-island=champmore]" };

var data: cp.TopData = undefined;
var state: cp.Top = undefined;
var server: cp.Top = undefined;
var src: []const u8 = "";
var root_path: []const u8 = "";
var want: u32 = 0;

export fn main() void {
    dom.start();
    for (0..lazy.len) |i| watch(@intCast(i));
    const root = zjb.global("document").call("querySelector", .{zjb.constString(sel)}, zjb.Handle);
    if (root == .null) return later();
    defer root.release();
    src = dom.attrOf(root, "data-src");
    root_path = dom.attrOf(root, "data-root");
    want = std.fmt.parseInt(u32, dom.attrOf(root, "data-stamp"), 10) catch return later();
    dom.fetch(src, 0, loaded);
}

fn loaded(_: i32, bytes: ?[]u8) void {
    defer later();
    const b = bytes orelse return dom.dom.warn("champion: no data");
    // A page cached from an older build than its data: leave it as rendered
    if (cp.stamp(b) != want) return dom.dom.warn("champion: the page and its data differ");
    data = ui.data.decode(gpa, cp.TopData, b) catch return dom.dom.warn("champion: bad data");
    // Each its own prepared panels: the server's stays as rendered for hydration
    const pp = cp.prepare(gpa, &data, root_path) catch return dom.dom.warn("champion: out of memory");
    server = .init(&data, pp, root_path);
    server.src = src;
    server.stamp = want;
    state = .init(&data, pp, root_path);
    state.src = src;
    state.stamp = want;
    _ = dom.rt.add(cp.Top, &state, &server, sel) catch return dom.dom.warn("champion: out of memory");
}

// The other files: each once its island nears the viewport, or once this file is done,
// whichever is first (a #matchups link or a quick scroll doesn't wait for the head)

var started: [lazy.len]bool = @splat(false);

fn watch(i: i32) void {
    const q = zjb.string(lazy[@intCast(i)]);
    defer q.release();
    const el = zjb.global("document").call("querySelector", .{q}, zjb.Handle);
    if (el == .null) return;
    defer el.release();
    const opts = zjb.global("Object").new(.{});
    defer opts.release();
    opts.set("rootMargin", zjb.constString("600px"));
    const cb = zjb.fnHandle("uiNear", &onNear).bind(.{i});
    defer cb.release();
    const io = zjb.global("IntersectionObserver").new(.{ cb, opts });
    defer io.release();
    io.call("observe", .{el}, void);
}

fn onNear(i: i32, entries: zjb.Handle, io: zjb.Handle) callconv(.c) void {
    defer entries.release();
    defer io.release();
    // Not get("0"): zjb writes the name as a property (`.0`), not valid JS
    const first = entries.call("at", .{@as(i32, 0)}, zjb.Handle);
    defer first.release();
    if (first == .null or !first.get("isIntersecting", bool)) return;
    io.call("disconnect", .{}, void);
    load(@intCast(i));
}

/// After this file's work: on the next task, so the patch paints first
fn later() void {
    zjb.global("window").call("setTimeout", .{ zjb.fnHandle("uiLater", &onLater), @as(i32, 0) }, void);
}

fn onLater() callconv(.c) void {
    for (0..lazy.len) |i| load(i);
}

/// The island's file: a <script> as the page's own, src and data-wasm from its root
fn load(i: usize) void {
    if (started[i]) return;
    started[i] = true;
    const doc = zjb.global("document");
    const q = zjb.string(lazy[i]);
    defer q.release();
    const el = doc.call("querySelector", .{q}, zjb.Handle);
    if (el == .null) return;
    defer el.release();
    const js = el.call("getAttribute", .{zjb.constString("data-js")}, zjb.Handle);
    defer js.release();
    const wasm = el.call("getAttribute", .{zjb.constString("data-wasm")}, zjb.Handle);
    defer wasm.release();
    if (js == .null or wasm == .null) return;
    const s = doc.call("createElement", .{zjb.constString("script")}, zjb.Handle);
    defer s.release();
    s.call("setAttribute", .{ zjb.constString("data-wasm"), wasm }, void);
    s.set("src", js);
    const head = doc.get("head", zjb.Handle);
    defer head.release();
    head.call("appendChild", .{s}, void);
}
