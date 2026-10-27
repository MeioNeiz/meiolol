//! ui-dailydays.wasm: Daily Draft's days strip and streak (ui.dailydays.Page) from its
//! data-bin and localStorage meiolol.daily.v1, again on ui-daily.wasm's "ui-daily" event
//! (a puzzle finished). On daily.html it also opens the viewer's own day's puzzle (their
//! date, not UTC's) or ?n='s. Once the page's puzzle is finished, /api/daily's counts:
//! POSTed with the answers the first time (meiolol.daily.sent.v1), else a GET. Share: the
//! share sheet on phones, else the clipboard. zjb's generated loader (ui-dailydays.js)
//! calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const ds = ui.dailydays;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;
const key = "meiolol.daily.v1";
const sent_key = "meiolol.daily.sent.v1";

var data: ds.Data = undefined;
var state: ds.Page = undefined;
var server: ds.Page = undefined;
var island: *ui.island.Island(ds.Page, dom.Dom) = undefined;
var date: [10]u8 = undefined;
var asked = false;

export fn main() void {
    dom.start();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(ds.sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    const b = dom.binOf(root, "data-bin") orelse return dom.dom.warn("days: no data");
    data = ui.data.decode(gpa, ds.Data, b) catch return dom.dom.warn("days: bad data");
    date = today();
    if (data.redirects) if (ds.target(data.days, &date, wanted())) |n| if (n != data.n) return open(n);
    server = .init(gpa, &data);
    state = .init(gpa, &data);
    island = dom.rt.add(ds.Page, &state, &server, ds.sel) catch return dom.dom.warn("days: out of memory");
    state.date = &date;
    island.render();
    dom.rt.changed = changed;
    zjb.global("window").call("addEventListener", .{ zjb.constString("ui-daily"), zjb.fnHandle("daysSaved", &onSaved) }, void);
    // Last: blocked storage throws, ending this call with the page already live
    read();
}

fn onSaved(e: zjb.Handle) callconv(.c) void {
    e.release();
    read();
}

fn read() void {
    const s = dom.stored(key) orelse return;
    if (state.saved.len > 0) gpa.free(state.saved);
    state.saved = s;
    island.render();
    crowd();
}

/// Once per page load, the first time the puzzle reads as finished
fn crowd() void {
    if (asked) return;
    const list = dom.stored(sent_key) orelse "";
    const send = !ds.sent(list, data.n);
    var buf: [96]u8 = undefined;
    const path = ds.crowdPath(&buf, state.saved, data.n, send) orelse return;
    asked = true;
    if (!send) return dom.fetch(path, 0, onCrowd);
    // Before the request: a reload while it is out must not count it twice
    var next: [4096]u8 = undefined;
    dom.store(sent_key, std.fmt.bufPrint(&next, "{s}{s}{d}", .{ list, if (list.len > 0) "," else "", data.n }) catch return);
    dom.post(path, 0, onCrowd);
}

fn onCrowd(_: i32, bytes: ?[]u8) void {
    const b = bytes orelse return;
    defer gpa.free(b);
    state.crowd = ds.crowdOf(gpa, b, &data) orelse return;
    island.render();
}

fn changed() void {
    if (!state.sharing) return;
    state.sharing = false;
    var buf: [256]u8 = undefined;
    const text = zjb.string(ds.shareText(&buf, &data, state.saved) orelse return);
    defer text.release();
    const nav = zjb.global("navigator");
    const w = zjb.global("window");
    // review.js's rule: a desktop share sheet is a detour
    const sheet = nav.get("share", zjb.Handle);
    defer sheet.release();
    const mq = w.call("matchMedia", .{zjb.constString("(pointer: coarse)")}, zjb.Handle);
    defer mq.release();
    if (w.call("Boolean", .{sheet}, bool) and mq.get("matches", bool)) {
        const o = zjb.global("Object").new(.{});
        defer o.release();
        o.set("text", text);
        const p = nav.call("share", .{o}, zjb.Handle);
        defer p.release();
        // Closing the sheet rejects
        p.call("catch", .{zjb.fnHandle("daysShared", &onShared)}, zjb.Handle).release();
        return;
    }
    const clip = nav.get("clipboard", zjb.Handle);
    defer clip.release();
    const p = clip.call("writeText", .{text}, zjb.Handle);
    defer p.release();
    // No clipboard access: a box to copy from
    p.call("then", .{ zjb.fnHandle("daysCopied", &onCopied), zjb.fnHandle("daysNoCopy", &onNoCopy) }, zjb.Handle).release();
}

fn onShared(e: zjb.Handle) callconv(.c) void {
    e.release();
}

fn onCopied(e: zjb.Handle) callconv(.c) void {
    e.release();
    state.copied = true;
    island.render();
    zjb.global("window").call("setTimeout", .{ zjb.fnHandle("daysCopiedEnd", &onCopiedEnd), @as(i32, 2000) }, void);
}

fn onCopiedEnd() callconv(.c) void {
    state.copied = false;
    island.render();
}

fn onNoCopy(e: zjb.Handle) callconv(.c) void {
    e.release();
    var buf: [256]u8 = undefined;
    const text = zjb.string(ds.shareText(&buf, &data, state.saved) orelse return);
    defer text.release();
    zjb.global("window").call("prompt", .{ zjb.constString("Your result:"), text }, void);
}

/// ?n= (an old link to a puzzle)
fn wanted() ?u32 {
    const s = zjb.global("location").get("search", zjb.Handle);
    defer s.release();
    var buf: [64]u8 = undefined;
    return ds.wantedOf(s.readString(&buf) catch return null);
}

fn open(n: u32) void {
    var buf: [64]u8 = undefined;
    const url = std.fmt.bufPrint(&buf, "{s}daily/{d}.html", .{ data.root, n }) catch return;
    const u = zjb.string(url);
    defer u.release();
    zjb.global("location").call("replace", .{u}, void);
}

/// The viewer's own date, "2026-10-27"
fn today() [10]u8 {
    const d = zjb.global("Date").new(.{});
    defer d.release();
    var out: [10]u8 = undefined;
    _ = std.fmt.bufPrint(&out, "{d:0>4}-{d:0>2}-{d:0>2}", .{
        @as(u32, @intCast(std.math.clamp(d.call("getFullYear", .{}, i32), 0, 9999))),
        @as(u32, @intCast(@max(d.call("getMonth", .{}, i32) + 1, 0))),
        @as(u32, @intCast(@max(d.call("getDate", .{}, i32), 0))),
    }) catch return "0000-00-00".*;
    return out;
}
