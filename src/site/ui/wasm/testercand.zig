//! ui-testercand.wasm: the Draft tester's candidate panel (ui.testercand.Panel). The
//! champions come from the tester island's data-bin, the board from the URL fragment it
//! shares with ui-tester.wasm, the seat's options from ui-tester.wasm, which holds the
//! model: a Feed (ui.data, base64) on this island's data-feed, then a tester-feed event.
//! ui-tester.wasm adds its loader (ui-testercand.js), which calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const tp = ui.testerpage;
const tc = ui.testercand;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;

var head: tp.Head = undefined;
var state: tc.Panel = undefined;
var server: tc.Panel = undefined;
var island: ?*ui.island.Island(tc.Panel, dom.Dom) = null;
var feed: tc.Feed = undefined;
/// The feed's: decoded slices point into its bytes
var arena: ?std.heap.ArenaAllocator = null;

export fn main() void {
    dom.start();
    const doc = zjb.global("document");
    const t = doc.call("querySelector", .{zjb.constString(tp.sel)}, zjb.Handle);
    if (t == .null) return;
    defer t.release();
    const b = dom.binOf(t, "data-bin") orelse return dom.dom.warn("testercand: no data");
    head = ui.data.decode(gpa, tp.Head, b) catch return dom.dom.warn("testercand: bad data");
    const root = doc.call("querySelector", .{zjb.constString(tc.sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    server = .init(&head);
    server.js = dom.attrOf(root, "data-js");
    server.wasm = dom.attrOf(root, "data-wasm");
    state = server;
    island = dom.rt.add(tc.Panel, &state, &server, tc.sel) catch return dom.dom.warn("testercand: out of memory");
    zjb.global("window").call("addEventListener", .{ zjb.constString("tester-feed"), zjb.fnHandle("testerFeed", &onFeed) }, void);
    read();
}

fn onFeed(e: zjb.Handle) callconv(.c) void {
    e.release();
    read();
}

/// The latest feed, if any; a bad one leaves the last
fn read() void {
    const root = zjb.global("document").call("querySelector", .{zjb.constString(tc.sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    const b = dom.binOf(root, "data-feed") orelse return;
    var next: std.heap.ArenaAllocator = .init(gpa);
    // The bytes stay with the arena: decoded slices point into them
    const owned = next.allocator().dupe(u8, b) catch {
        gpa.free(b);
        return next.deinit();
    };
    gpa.free(b);
    feed = ui.data.decode(next.allocator(), tc.Feed, owned) catch {
        dom.dom.warn("testercand: bad feed");
        return next.deinit();
    };
    if (arena) |*old| old.deinit();
    arena = next;
    state.feed = &feed;
    if (island) |i| i.render();
}
