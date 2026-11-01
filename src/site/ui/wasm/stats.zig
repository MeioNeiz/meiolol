//! ui-stats.wasm: the champions board (ui.tiers.Tiers) from its view's data file, then
//! another view's data file and a view's rank file as they are picked. zjb's generated
//! loader (ui-stats.js, `<script src data-wasm>`) calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const tiers = ui.tiers;

pub const panic = zjb.panic;
pub const url_map: dom.UrlMap = .views;

const gpa = std.heap.wasm_allocator;
const sel = "[data-island=tiers]";

var data: tiers.Data = undefined;
var state: tiers.Tiers = undefined;
var server: tiers.Tiers = undefined;
var page_role: ?tiers.Role = null;
var base: []const u8 = "";
var view_index: u8 = 0;
var path: []const u8 = "";
var src: []const u8 = "";
var want: u32 = 0;
var stamp: []const u8 = "";
var island: *ui.island.Island(tiers.Tiers, dom.Dom) = undefined;
/// A file is out: view asked_view's data, or its rank file
var asked = false;
var asked_view: u8 = 0;

export fn main() void {
    dom.start();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    const role = dom.attrOf(root, "data-role");
    page_role = for (std.enums.values(tiers.Role)) |r| {
        if (std.mem.eql(u8, tiers.Role.slugs[@backingInt(r)], role)) break r;
    } else null;
    base = dom.attrOf(root, "data-base");
    view_index = std.fmt.parseInt(u8, dom.attrOf(root, "data-view"), 10) catch return;
    if (view_index >= tiers.rank_paths.len) return dom.dom.warn("tiers: bad data-view");
    path = dom.attrOf(root, "data-path");
    src = dom.attrOf(root, "data-src");
    stamp = dom.attrOf(root, "data-stamp");
    want = std.fmt.parseInt(u32, stamp, 10) catch return;
    dom.fetchStamped(src, stamp, 0, loaded);
}

fn loaded(_: i32, bytes: ?[]u8) void {
    const b = bytes orelse return dom.dom.warn("tiers: no data");
    // A page cached from an older build than its data: leave it as rendered
    if (tiers.stamp(b) != want) return dom.dom.warn("tiers: the page and its data differ");
    data = ui.data.decode(gpa, tiers.Data, b) catch return dom.dom.warn("tiers: bad data");
    const lines = tiers.prepare(gpa, &data, base) catch return dom.dom.warn("tiers: out of memory");
    server = .init(&data, lines, page_role);
    server.base = base;
    server.view_index = view_index;
    server.path = path;
    server.src = src;
    server.stamp = want;
    state = server;
    stored = view_index;
    island = dom.rt.add(tiers.Tiers, &state, &server, sel) catch return dom.dom.warn("tiers: out of memory");
    dom.rt.changed = check;
    check();
}

/// A view or rank picked (or in the URL): its file once, then the board
fn check() void {
    if (state.need()) |n| {
        if (asked) return;
        asked = true;
        const v = state.wantView();
        asked_view = v;
        const p = switch (n) {
            .view => std.mem.concat(gpa, u8, &.{ base, ui.urls.view_dirs[v], tiers.data_file }),
            .rank => std.mem.concat(gpa, u8, &.{ base, tiers.rank_paths[state.view_index] }),
        } catch return;
        return dom.fetch(p, 0, if (n == .view) viewLoaded else rankLoaded);
    }
    if (!state.busy()) return;
    state.show(gpa) catch return dom.dom.warn("tiers: out of memory");
    island.render();
    remember();
    // A new view's rank file, if a rank is picked
    check();
}

/// The view shown, for the site's other pages' links (shell.zig meio_view)
var stored: u8 = 0;

fn remember() void {
    const v = state.view_index;
    if (v == stored) return;
    stored = v;
    const window = zjb.global("window");
    if (!window.call("hasOwnProperty", .{zjb.constString("meioView")}, bool)) return;
    const d = zjb.string(ui.urls.view_queries[v]);
    defer d.release();
    window.call("meioView", .{d}, void);
}

fn viewLoaded(_: i32, bytes: ?[]u8) void {
    asked = false;
    const v = asked_view;
    const d = if (bytes) |b| ui.data.decode(gpa, tiers.Data, b) catch null else null;
    if (d) |x| {
        const p = gpa.create(tiers.Data) catch return;
        p.* = x;
        state.views[v] = p;
    } else {
        dom.dom.warn("tiers: no data for the view");
        if (state.want_view == v) {
            state.noView();
            island.render();
        }
    }
    check();
}

fn rankLoaded(_: i32, bytes: ?[]u8) void {
    asked = false;
    // Another view since: its own rank file next
    if (asked_view != state.view_index) return check();
    state.none = true;
    if (bytes) |b| if (ui.data.decode(gpa, tiers.RankData, b)) |v| {
        const p = gpa.create(tiers.RankData) catch return;
        p.* = v;
        state.ranks = p;
        state.none = false;
    } else |_| dom.dom.warn("tiers: bad rank data");
    check();
}
