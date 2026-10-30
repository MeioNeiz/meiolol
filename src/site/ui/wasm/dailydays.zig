//! ui-dailydays.wasm: Daily Draft's days strip and streak (ui.dailydays.Page) from its
//! data-bin and localStorage meiolol.daily.v1, again on ui-daily.wasm's "ui-daily" event
//! (a puzzle finished). On /daily it also opens the viewer's own day's puzzle (their
//! date, not UTC's) or ?n='s. Once the page's puzzle is finished, /api/daily's counts:
//! POSTed with the answers the first time (meiolol.daily.sent.v1; a failed POST unmarked
//! and sent again next load), else a GET. Share: the share sheet on phones, else the
//! clipboard. zjb's generated loader (ui-dailydays.js) calls `main`
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
    // Last: blocked storage throws (here or in a later store), ending that call with the
    // page already live
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

/// Once per page load, the first time the puzzle reads as finished: a POST the first time
/// (its answers counted), else a GET
fn crowd() void {
    if (asked) return;
    const got = dom.stored(sent_key);
    defer if (got) |g| gpa.free(g);
    const list = got orelse "";
    var buf: [96]u8 = undefined;
    var next: [4096]u8 = undefined;
    if (!ds.sent(list, data.n)) if (ds.crowdPath(&buf, state.saved, data.n, true)) |path| {
        // Before the request: a reload while it is out must not count it twice. Unmarked,
        // it would count on every load: then only a GET
        if (ds.withSent(&next, list, data.n)) |marked| {
            asked = true;
            dom.store(sent_key, marked);
            return dom.post(path, 1, onCrowd);
        }
    };
    // Sent, or finished without the answers to send
    const path = ds.crowdPath(&buf, state.saved, data.n, false) orelse return;
    asked = true;
    dom.fetch(path, 0, onCrowd);
}

fn onCrowd(post: i32, bytes: ?[]u8) void {
    const b = bytes orelse {
        // Not counted (429, 5xx, offline): sent again next load, the line from a GET now.
        // A reply lost after the server counted it reads the same, so that one answer
        // counts twice: rare, and the server can't tell
        if (post == 1) {
            const got = dom.stored(sent_key);
            defer if (got) |g| gpa.free(g);
            var next: [4096]u8 = undefined;
            dom.store(sent_key, ds.unsent(&next, got orelse "", data.n));
            var buf: [96]u8 = undefined;
            dom.fetch(ds.crowdPath(&buf, state.saved, data.n, false) orelse return, 0, onCrowd);
        }
        return;
    };
    defer gpa.free(b);
    state.crowd = ds.crowdOf(b, &data) orelse return;
    island.render();
}

fn changed() void {
    if (!state.sharing) return;
    state.sharing = false;
    var buf: [512]u8 = undefined;
    const text = zjb.string(ds.shareText(&buf, &state) orelse return);
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
        p.call("catch", .{zjb.fnHandle("daysShared", &onShared)}, zjb.Handle).release();
        return;
    }
    copy(text);
}

/// To the clipboard; without one (not https, some webviews) or its access, a box to copy
/// from
fn copy(text: zjb.Handle) void {
    const clip = zjb.global("navigator").get("clipboard", zjb.Handle);
    defer clip.release();
    if (!zjb.global("window").call("Boolean", .{clip}, bool)) return ask(text);
    const p = clip.call("writeText", .{text}, zjb.Handle);
    defer p.release();
    p.call("then", .{ zjb.fnHandle("daysCopied", &onCopied), zjb.fnHandle("daysNoCopy", &onNoCopy) }, zjb.Handle).release();
}

fn ask(text: zjb.Handle) void {
    zjb.global("window").call("prompt", .{ zjb.constString("Your result:"), text }, void);
}

/// The sheet refused: closed by the viewer (AbortError) is the end of it, anything else
/// (no activation left, a share it can't make) goes to the clipboard
fn onShared(e: zjb.Handle) callconv(.c) void {
    defer e.release();
    const name = e.get("name", zjb.Handle);
    defer name.release();
    var nb: [32]u8 = undefined;
    if (std.mem.eql(u8, name.readString(&nb) catch "", "AbortError")) return;
    var buf: [512]u8 = undefined;
    const text = zjb.string(ds.shareText(&buf, &state) orelse return);
    defer text.release();
    copy(text);
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
    var buf: [512]u8 = undefined;
    const text = zjb.string(ds.shareText(&buf, &state) orelse return);
    defer text.release();
    ask(text);
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
    const url = std.fmt.bufPrint(&buf, "{s}daily/{d}", .{ data.root, n }) catch return;
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
