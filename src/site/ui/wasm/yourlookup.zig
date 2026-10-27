//! ui-yourlookup.wasm: the Your games lookup (ui.yourlookup.YourLookup). Asks /api/list
//! for the URL's id, again while queued or fetching, and hands each new list to ui-your:
//! the list's root data-bin, then yk.event. Loaded by ui-your.wasm (dom.script) once the
//! URL has an id; zjb's generated loader (ui-yourlookup.js) calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const yk = ui.yourlookup;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;

var look: yk.YourLookup = undefined;
var look0: yk.YourLookup = undefined;
var island: ?*ui.island.Island(yk.YourLookup, dom.Dom) = null;
/// The id (YourLookup.gen) last asked for
var asked: u32 = 0;
/// The last answer: the status line's strings point into it
var last: []u8 = &.{};
/// The list last handed over: the same again is not
var handed: []u8 = &.{};

export fn main() void {
    dom.start();
    const el = zjb.global("document").call("querySelector", .{zjb.constString(yk.sel)}, zjb.Handle);
    if (el == .null) return;
    defer el.release();
    look0 = .{ .js = dom.attrOf(el, "data-js"), .wasm = dom.attrOf(el, "data-wasm") };
    look = look0;
    island = dom.rt.add(yk.YourLookup, &look, &look0, yk.sel) catch return dom.dom.warn("lookup: out of memory");
    dom.rt.changed = changed;
    zjb.global("document").call("addEventListener", .{ zjb.constString("visibilitychange"), zjb.fnHandle("yourShown", &onShown) }, void);
    changed();
}

/// Another id in the URL (or none): the example until its list comes, and ask
fn changed() void {
    if (look.gen == asked) return;
    asked = look.gen;
    hand(null);
    if (look.id.len > 0) ask();
}

fn ask() void {
    const q = ui.homepage.idQuery(gpa, look.id.slice()) catch return;
    defer gpa.free(q);
    const path = std.fmt.allocPrint(gpa, "/api/list?{s}", .{q}) catch return;
    defer gpa.free(path);
    dom.fetch(path, @bitCast(look.gen), answered);
}

fn answered(gen: i32, bytes: ?[]u8) void {
    // An older id's: its ask is over
    if (@as(u32, @bitCast(gen)) != look.gen) {
        if (bytes) |b| gpa.free(b);
        return;
    }
    gpa.free(last);
    last = bytes orelse &.{};
    const l = look.answer(gpa, bytes);
    if (l != null or look.at == .down) hand(l);
    if (island) |i| i.render();
    const ms = look.next() orelse return;
    const f = zjb.fnHandle("yourAsk", &onDue).bind(.{gen});
    defer f.release();
    zjb.global("window").call("setTimeout", .{ f, @as(i32, @intCast(ms)) }, void);
}

/// A wait ended; a new id since stops this one's asks
fn onDue(gen: i32) callconv(.c) void {
    if (@as(u32, @bitCast(gen)) != look.gen) return;
    if (look.due(zjb.global("document").get("hidden", bool))) ask();
}

fn onShown(e: zjb.Handle) callconv(.c) void {
    e.release();
    if (!look.paused or zjb.global("document").get("hidden", bool)) return;
    look.paused = false;
    ask();
}

/// A List's file onto the list's root, or the example again (null), then the event
fn hand(l: ?[]u8) void {
    if (l) |b| {
        if (std.mem.eql(u8, b, handed)) return gpa.free(b);
    } else if (handed.len == 0) return;
    gpa.free(handed);
    handed = l orelse &.{};
    const el = zjb.global("document").call("querySelector", .{zjb.constString(ui.yourpage.sel)}, zjb.Handle);
    if (el == .null) return;
    defer el.release();
    if (l) |b| {
        const enc = std.base64.standard.Encoder;
        const s = gpa.alloc(u8, enc.calcSize(b.len)) catch return;
        defer gpa.free(s);
        const v = zjb.string(enc.encode(s, b));
        defer v.release();
        el.call("setAttribute", .{ zjb.constString("data-bin"), v }, void);
    } else el.call("removeAttribute", .{zjb.constString("data-bin")}, void);
    const e = zjb.global("Event").new(.{zjb.constString(yk.event)});
    defer e.release();
    zjb.global("window").call("dispatchEvent", .{e}, void);
}
