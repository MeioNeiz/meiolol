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
var index: ui.champsearch.Index = undefined;
var state: tp.Page = undefined;
var server: tp.Page = undefined;
var island: ?*ui.island.Island(tp.Page, dom.Dom) = null;
var loaded: std.enums.EnumArray(tp.Which, tp.Loaded) = undefined;
var lane: ui.testerlane.Loaded = undefined;
var feed_arena: std.heap.ArenaAllocator = .init(gpa);
/// What the last feed was for: the panel needs a new one when any of it changes
const Sent = struct { which: tp.Which, teams: @FieldType(tp.Page, "teams"), bans: [tp.n_ban]u32, seat: u8, load: std.meta.Tag(tp.Load), lane: std.meta.Tag(ui.testerlane.Load) };
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
    state.rng = .init(@bitCast(zjb.global("Math").call("random", .{}, f64)));
    index = tp.searchIndex(gpa, &head) catch return dom.dom.warn("tester: out of memory");
    server.useIndex(&index);
    state.useIndex(&index);
    island = dom.rt.add(tp.Page, &state, &server, tp.sel) catch return dom.dom.warn("tester: out of memory");
    dom.rt.changed = changed;
    // The first fetch and the panel wait a task, so they see the saved board and still
    // run when blocked storage throws below
    zjb.global("window").call("setTimeout", .{ zjb.fnHandle("testerStart", &start), @as(i32, 0) }, void);
    // Last: blocked storage throws, ending this call with the page already live
    var buf: [256]u8 = undefined;
    const fragment = dom.dom.hash(&buf);
    if (dom.stored(key)) |s| {
        defer gpa.free(s);
        if (!tp.restoreSaved(&state, &server, fragment, s)) return;
        if (island) |i| i.render();
        dom.rt.syncHash(false) catch {};
    }
}

fn start() callconv(.c) void {
    fetchShown();
    state.lane = .loading;
    dom.fetch(ui.testerlane.file, lane_ctx, done);
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

/// dom.fetch has one callback for every request in flight: ctx tells them apart
const lane_ctx = -1;

fn done(ctx: i32, bytes: ?[]u8) void {
    if (ctx == lane_ctx) return laneDone(bytes);
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

fn laneDone(bytes: ?[]u8) void {
    defer schedule();
    defer if (island) |i| i.render();
    const b = bytes orelse return {
        state.lane = .failed;
    };
    var arena: std.heap.ArenaAllocator = .init(gpa);
    lane.init(arena.allocator(), b) catch {
        dom.dom.warn("tester: bad lane model file");
        arena.deinit();
        gpa.free(b);
        state.lane = .bad;
        return;
    };
    state.lane = .{ .ready = &lane };
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
    const now: Sent = .{ .which = state.which, .teams = state.teams, .bans = state.bans, .seat = seat, .load = std.meta.activeTag(load), .lane = std.meta.activeTag(state.lane) };
    if (sent) |s| if (std.meta.eql(s, now)) return;
    _ = feed_arena.reset(.retain_capacity);
    const a = feed_arena.allocator();
    var f = ui.testercand.feed(a, &head, load, state.which, state.teams, state.bans, seat) catch return dom.dom.warn("tester: out of memory");
    switch (state.lane) {
        .ready => |l| ui.testercand.addLane(a, &f, load, &l.sc) catch return dom.dom.warn("tester: out of memory"),
        else => {},
    }
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
