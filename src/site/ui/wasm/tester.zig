//! ui-tester.wasm: the Draft tester (ui.testerpage.Page) from its data-bin, the chosen
//! model's draft-model.bin fetched and scored here, the board from the URL (a link) or
//! else localStorage (meiolol.tester.v1), and to it; then ui-testercand.wasm, the
//! candidate panel, which has no model: each board's seat options go to it as a Feed on
//! its data-feed and a tester-feed event. zjb's generated loader (ui-tester.js, `<script
//! src data-wasm>`) calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const tp = ui.testerpage;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;
const key = "meiolol.tester.v1";
const lazy = [_][]const u8{ui.testercand.sel};

var head: tp.Head = undefined;
var state: tp.Page = undefined;
var server: tp.Page = undefined;
var island: ?*ui.island.Island(tp.Page, dom.Dom) = null;
var loaded: std.enums.EnumArray(tp.Which, tp.Loaded) = undefined;
var feed_arena: std.heap.ArenaAllocator = .init(gpa);
/// What the last feed was for: the panel needs a new one when any of it changes
const Sent = struct { which: tp.Which, teams: @FieldType(tp.Page, "teams"), seat: u8, load: std.meta.Tag(tp.Load) };
var sent: ?Sent = null;
var pending = false;

export fn main() void {
    dom.start();
    dom.lazyLoad(&lazy);
    const root = zjb.global("document").call("querySelector", .{zjb.constString(tp.sel)}, zjb.Handle);
    if (root == .null) return dom.lazyLater();
    defer root.release();
    const b = dom.binOf(root, "data-bin") orelse return dom.dom.warn("tester: no data");
    head = ui.data.decode(gpa, tp.Head, b) catch return dom.dom.warn("tester: bad data");
    server = .init(&head);
    state = .init(&head);
    island = dom.rt.add(tp.Page, &state, &server, tp.sel) catch return dom.dom.warn("tester: out of memory");
    dom.rt.changed = changed;
    // The first fetch and the panel wait a task, so they see the saved board and still
    // run when blocked storage throws below
    zjb.global("window").call("setTimeout", .{ zjb.fnHandle("testerStart", &start), @as(i32, 0) }, void);
    // Last: blocked storage throws, ending this call with the page already live. A link's
    // board wins over the saved one
    if (!std.meta.eql(state.teams, server.teams)) return;
    if (dom.stored(key)) |s| {
        defer gpa.free(s);
        tp.restore(&state, s);
        if (island) |i| i.render();
        dom.rt.syncHash(false) catch {};
    }
}

fn start() callconv(.c) void {
    fetchShown();
    if (island) |i| i.render();
    dom.lazyLater();
    schedule();
}

/// After each update: fetch a newly chosen model, tell the panel, save the board
fn changed() void {
    fetchShown();
    schedule();
    if (!state.dirty) return;
    state.dirty = false;
    var out: std.Io.Writer.Allocating = .init(gpa);
    defer out.deinit();
    tp.saved(&state, &out.writer) catch return;
    dom.store(key, out.written());
}

fn fetchShown() void {
    const w = state.which;
    if (state.loads.get(w) != .none) return;
    state.loads.set(w, .loading);
    dom.fetch(tp.infos.get(w).file, @backingInt(w), done);
}

fn done(ctx: i32, bytes: ?[]u8) void {
    const w = std.enums.fromInt(tp.Which, ctx) orelse return;
    defer schedule();
    defer if (island) |i| i.render();
    const b = bytes orelse return state.loads.set(w, .failed);
    // Decoded slices point into the bytes: both stay while the model does
    var arena: std.heap.ArenaAllocator = .init(gpa);
    const l = loaded.getPtr(w);
    l.* = tp.Loaded.init(arena.allocator(), b) catch {
        dom.dom.warn("tester: bad model file");
        arena.deinit();
        gpa.free(b);
        return state.loads.set(w, .bad);
    };
    state.loads.set(w, .{ .ready = l });
}

/// The panel's feed on the next task: out of this runtime's event, and once for a burst
fn schedule() void {
    if (pending) return;
    pending = true;
    zjb.global("window").call("setTimeout", .{ zjb.fnHandle("testerFeed", &publish), @as(i32, 0) }, void);
}

fn publish() callconv(.c) void {
    pending = false;
    const seat = tp.shownSeat(state.teams, state.seat) orelse return;
    const load = state.loads.get(state.which);
    const now: Sent = .{ .which = state.which, .teams = state.teams, .seat = seat, .load = std.meta.activeTag(load) };
    if (sent) |s| if (std.meta.eql(s, now)) return;
    _ = feed_arena.reset(.retain_capacity);
    const a = feed_arena.allocator();
    const f = ui.testercand.feed(a, &head, load, state.which, state.teams, seat) catch return dom.dom.warn("tester: out of memory");
    var raw: std.ArrayList(u8) = .empty;
    ui.data.encode(a, ui.testercand.Feed, f, &raw) catch return dom.dom.warn("tester: out of memory");
    const e = std.base64.standard.Encoder;
    const b64 = e.encode(a.alloc(u8, e.calcSize(raw.items.len)) catch return, raw.items);
    const el = zjb.global("document").call("querySelector", .{zjb.constString(ui.testercand.sel)}, zjb.Handle);
    if (el == .null) return;
    defer el.release();
    const v = zjb.string(b64);
    defer v.release();
    el.call("setAttribute", .{ zjb.constString("data-feed"), v }, void);
    const ev = zjb.global("Event").new(.{zjb.constString("tester-feed")});
    defer ev.release();
    zjb.global("window").call("dispatchEvent", .{ev}, void);
    sent = now;
}
