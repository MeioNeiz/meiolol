//! ui-yourlookup.wasm: the Your games lookup (ui.yourlookup.YourLookup). Asks /api/list
//! for the URL's id, again while queued or fetching, and hands each new list to ui-your:
//! the list's root data-bin, then yk.event. Check for new games asks with &refresh=1; a
//! ready answer goes into your-recent and your-last. Loaded by ui-your.wasm (dom.script)
//! once the URL has an id; zjb's generated loader (ui-yourlookup.js) calls `main`
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
/// Check for new games: the handed list's hash at the press
var from: u64 = 0;

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

/// Another id in the URL (or none): the example until its list comes, and ask. After
/// Check for new games or Not you?, what they need
fn changed() void {
    if (look.want == .check) {
        look.started(now());
        from = std.hash.Wyhash.hash(0, handed);
        return askFor(true);
    }
    if (look.gen != asked) {
        asked = look.gen;
        hand(null);
        if (look.id.len > 0) ask();
    }
    if (look.want == .forget) {
        look.want = .none;
        // Throws with storage blocked: last
        dom.store(yk.last_key, "");
    }
}

fn now() i64 {
    return @intFromFloat(zjb.global("Date").call("now", .{}, f64));
}

fn ask() void {
    askFor(false);
}

fn askFor(refresh: bool) void {
    const q = ui.homepage.idQuery(gpa, look.id.slice()) catch return;
    defer gpa.free(q);
    const path = std.fmt.allocPrint(gpa, "/api/list?{s}{s}", .{ q, if (refresh) "&refresh=1" else "" }) catch return;
    defer gpa.free(path);
    dom.fetch(path, @bitCast(look.gen), answered);
}

fn answered(gen: i32, bytes: ?[]u8) void {
    // An older id's: its ask is over
    if (@as(u32, @bitCast(gen)) != look.gen) {
        if (bytes) |b| gpa.free(b);
        return;
    }
    const l = look.answer(gpa, bytes) catch {
        if (bytes) |b| gpa.free(b);
        if (look.at == .down) hand(null);
        return after(gen);
    };
    gpa.free(last);
    last = bytes.?;
    if (l != null) hand(l);
    const ready = look.head.state == .ready;
    if (ready and look.watching()) {
        look.now_ms = now();
        if (look.checked(std.hash.Wyhash.hash(0, handed) != from)) |ms| {
            const f = zjb.fnHandle("yourCheck", &onCheck).bind(.{gen});
            defer f.release();
            zjb.global("window").call("setTimeout", .{ f, @as(i32, @intCast(ms)) }, void);
        }
    }
    after(gen);
    if (ready) remember();
}

/// A check found nothing new a minute ago: again, unless stopped or another id since
fn onCheck(gen: i32) callconv(.c) void {
    if (@as(u32, @bitCast(gen)) != look.gen or look.check != .waiting) return;
    askFor(true);
}

/// The id first in your-recent, and as your-last. Throws with storage blocked: last
fn remember() void {
    const id = look.id.slice();
    const old = dom.stored(yk.recent_key);
    defer if (old) |o| gpa.free(o);
    const j = yk.recentJson(gpa, old, id) catch return;
    defer gpa.free(j);
    dom.store(yk.recent_key, j);
    const l = (yk.lastJson(gpa, id) catch return) orelse return;
    defer gpa.free(l);
    dom.store(yk.last_key, l);
}

/// The status line, and the next ask's timer
fn after(gen: i32) void {
    // Before the render: at the cap it says so
    const ms = look.next();
    if (island) |i| i.render();
    const wait = ms orelse return;
    const f = zjb.fnHandle("yourAsk", &onDue).bind(.{gen});
    defer f.release();
    zjb.global("window").call("setTimeout", .{ f, @as(i32, @intCast(wait)) }, void);
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
        // The server's example, for ui-yourviews if it loads after this
        if (!el.call("hasAttribute", .{zjb.constString("data-example")}, bool)) {
            const ex = el.call("getAttribute", .{zjb.constString("data-bin")}, zjb.Handle);
            defer ex.release();
            if (ex != .null) el.call("setAttribute", .{ zjb.constString("data-example"), ex }, void);
        }
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
    // ui-your's listener has run: it removes a list it can't read (a stale cached file)
    if (l != null and !el.call("hasAttribute", .{zjb.constString("data-bin")}, bool)) look.at = .down;
}
