//! ui-squad.wasm: a squad (ui.squad.Squad) from /api/squad?s=TOKEN, the token from the
//! fragment (#s=TOKEN, never sent as a page request); asks again while members' games
//! come. Start, join and leave POST /api/squad/check and follow it as ui-forget does;
//! a finished start opens the new squad
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const sq = ui.squad;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;

var page: sq.Squad = undefined;
var page0: sq.Squad = undefined;
var island: ?*ui.island.Island(sq.Squad, dom.Dom) = null;
var origin_buf: [128]u8 = undefined;
/// Each load's: a late answer for an older squad is dropped
var load_gen: i32 = 0;

export fn main() void {
    dom.start();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(sq.sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    page0 = .{ .action = .create, .js = dom.attrOf(root, "data-js"), .wasm = dom.attrOf(root, "data-wasm"), .ddragon = dom.attrOf(root, "data-ddragon") };
    page = page0;
    const o = zjb.global("location").get("origin", zjb.Handle);
    defer o.release();
    page.origin = o.readString(&origin_buf) catch "";
    const d = zjb.global("Date").new(.{});
    defer d.release();
    page.tz_min = -d.call("getTimezoneOffset", .{}, i32);
    page.now_ms = @intFromFloat(zjb.global("Date").call("now", .{}, f64));
    var buf: [256]u8 = undefined;
    const f = ui.url.read(sq.Frag, dom.dom.hash(&buf));
    page.token = f.s;
    if (page.token.len > 0) page.action = .none;
    island = dom.rt.add(sq.Squad, &page, &page0, sq.sel) catch return dom.dom.warn("squad: out of memory");
    dom.rt.changed = changed;
    if (page.token.len > 0) load();
}

fn changed() void {
    const w = page.want;
    if (w == .none) return;
    page.want = .none;
    switch (w) {
        .copy => copy(),
        .start, .check => ask(w),
        .none => {},
    }
}

fn load() void {
    page.load = .loading;
    load_gen +%= 1;
    const path = std.fmt.allocPrint(gpa, "/api/squad?s={s}", .{page.token.slice()}) catch return;
    defer gpa.free(path);
    dom.fetchFresh(path, load_gen, loaded);
}

fn loaded(gen: i32, bytes: ?[]u8) void {
    defer if (bytes) |b| gpa.free(b);
    if (gen != load_gen) return;
    const data: ?*sq.Data = if (bytes) |b| blk: {
        const v = ui.data.decode(gpa, sq.Data, b) catch break :blk null;
        const p = gpa.create(sq.Data) catch break :blk null;
        p.* = v;
        break :blk p;
    } else null;
    // A failed refresh keeps the squad shown
    const again = if (data == null and page.data != null) false else page.loaded(data);
    if (island) |i| i.render();
    if (again) later("squadLoadDue", &onLoadDue, gen);
}

fn onLoadDue(gen: i32) callconv(.c) void {
    if (gen == load_gen) load();
}

fn later(comptime name: []const u8, comptime f: *const fn (i32) callconv(.c) void, gen: i32) void {
    const h = zjb.fnHandle(name, f).bind(.{gen});
    defer h.release();
    zjb.global("window").call("setTimeout", .{ h, @as(i32, sq.poll_ms) }, void);
}

fn ask(w: sq.Squad.Want) void {
    const path = page.checkPath(gpa, w) catch return;
    defer gpa.free(path);
    const gen: i32 = @bitCast(page.gen);
    if (w == .none) dom.fetchFresh(path, gen, answered) else dom.post(path, gen, answered);
}

fn answered(gen: i32, bytes: ?[]u8) void {
    defer if (bytes) |b| gpa.free(b);
    if (@as(u32, @bitCast(gen)) != page.gen) return;
    const again = page.answered(if (bytes) |b| sq.answer(b) else null);
    if (page.at == .done) settled();
    if (island) |i| i.render();
    if (again) later("squadCheckDue", &onCheckDue, gen);
}

fn onCheckDue(gen: i32) callconv(.c) void {
    if (@as(u32, @bitCast(gen)) == page.gen) ask(.none);
}

/// A start opens its squad; a join or leave shows the squad again with it
fn settled() void {
    if (page.action == .create and page.started.len > 0) {
        var buf: [64]u8 = undefined;
        const h = std.fmt.bufPrint(&buf, "#s={s}", .{page.started.slice()}) catch return;
        dom.dom.setHash(h, true);
        page.token = page.started;
        page.action = .none;
        page.at = .idle;
    }
    load();
}

fn copy() void {
    var buf: [192]u8 = undefined;
    const link = std.fmt.bufPrint(&buf, "{s}/squad#s={s}", .{ page.origin, page.token.slice() }) catch return;
    const clip = zjb.global("navigator").get("clipboard", zjb.Handle);
    defer clip.release();
    if (!zjb.global("window").call("Boolean", .{clip}, bool)) return;
    const s = zjb.string(link);
    defer s.release();
    const p = clip.call("writeText", .{s}, zjb.Handle);
    defer p.release();
    p.call("catch", .{zjb.fnHandle("squadNoCopy", &onNoCopy)}, zjb.Handle).release();
}

/// No clipboard access: the link stays in its box to copy by hand
fn onNoCopy(e: zjb.Handle) callconv(.c) void {
    e.release();
    page.copied = false;
    if (island) |i| i.render();
}
