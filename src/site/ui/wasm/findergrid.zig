//! ui-findergrid.wasm: the matchup finder's first pick's matchups (ui.finder.Grid), the
//! champion page's -more.bin fetched once per champion. ui-finder.wasm adds its loader
//! (ui-findergrid.js) to the page, which calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const fd = ui.finder;
const MoreData = ui.champpage.MoreData;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;
const sel = "[data-island=findergrid]";

var state: fd.Grid = undefined;
var server: fd.Grid = undefined;
var island: *ui.island.Island(fd.Grid, dom.Dom) = undefined;
/// Each fetched champion's matchups by slug (null: its file failed)
var cache: std.StringHashMapUnmanaged(?*const MoreData) = .empty;
/// The slug being fetched
var asked: ?[]const u8 = null;

export fn main() void {
    // Before dom.start's: popstate listeners run in order, and Grid.fromUrl reads `back`
    zjb.global("window").call("addEventListener", .{ zjb.constString("popstate"), zjb.fnHandle("fgBack", &onBack) }, void);
    dom.start();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    const js = dom.attrOf(root, "data-js");
    const wasm = dom.attrOf(root, "data-wasm");
    server = .{
        .root = dom.attrOf(root, "data-root"),
        .js = if (js.len > 0) js else null,
        .wasm = if (wasm.len > 0) wasm else null,
    };
    state = server;
    island = dom.rt.add(fd.Grid, &state, &server, sel) catch return dom.dom.warn("findergrid: out of memory");
    state.live = true;
    dom.rt.changed = check;
    check();
}

fn onBack(e: zjb.Handle) callconv(.c) void {
    e.release();
    state.back = true;
}

/// The first pick's matchups: from the cache, else fetched (one at a time; a pick made
/// meanwhile is fetched after); then a fresh second pick with a page goes there
fn check() void {
    state.back = false;
    const slug = state.want() orelse return;
    if (!state.more_of.eql(&state.u.c)) {
        if (cache.get(slug)) |d| {
            state.got(slug, d);
            island.render();
        } else {
            if (asked != null) return;
            const s = gpa.dupe(u8, slug) catch return;
            const path = std.mem.concat(gpa, u8, &.{ state.root, "data/champion/", s, "-more.bin" }) catch return gpa.free(s);
            defer gpa.free(path);
            asked = s;
            return dom.fetch(path, 0, loaded);
        }
    }
    const href = state.goTo(gpa) orelse return;
    defer gpa.free(href);
    const u = zjb.string(href);
    defer u.release();
    zjb.global("location").call("assign", .{u}, void);
}

/// A file that came but doesn't decode is cached as none; a failed fetch (offline, a
/// server error) only for this pick, so picking the champion again fetches again. A
/// decoded file keeps its bytes: its names point into them
fn loaded(_: i32, bytes: ?[]u8) void {
    const slug = asked orelse return;
    asked = null;
    var d: ?*const MoreData = null;
    if (bytes) |b| {
        if (ui.data.decode(gpa, MoreData, b)) |v| {
            const p = gpa.create(MoreData) catch {
                gpa.free(b);
                return gpa.free(slug);
            };
            p.* = v;
            d = p;
        } else |_| gpa.free(b);
    }
    if (d == null) dom.dom.warn("findergrid: no matchups for the pick");
    const kept = bytes != null and if (cache.put(gpa, slug, d)) true else |_| false;
    defer if (!kept) gpa.free(slug);
    if (std.mem.eql(u8, state.want() orelse "", slug)) {
        state.got(slug, d);
        island.render();
    }
    check();
}
