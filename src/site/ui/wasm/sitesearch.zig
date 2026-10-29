//! ui-sitesearch.wasm: the header search (ui.sitesearch.SiteSearch). html.zig's inline
//! script adds its loader on the form's first focus or pointerdown, or "/", which calls
//! `main`; the view's search.bin is asked for at once, as the box is in use. A submit
//! that came first (meioSearchGo) follows the first option once the index is in
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const ss = ui.sitesearch;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;

var page: ss.SiteSearch = undefined;
var page0: ss.SiteSearch = undefined;
var island: ?*ui.island.Island(ss.SiteSearch, dom.Dom) = null;
var index: ss.Index = undefined;
var asked = false;
/// dom.stored throws with storage blocked, ending the export: once tried, go without
var view_tried = false;
var recent: [8]ui.idlookup.Id = undefined;

export fn main() void {
    dom.start();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(ss.sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    const has_view = root.call("hasAttribute", .{zjb.constString("data-view")}, bool);
    page0 = .{ .js = dom.attrOf(root, "data-js"), .wasm = dom.attrOf(root, "data-wasm"), .view_q = if (has_view) dom.attrOf(root, "data-view") else null };
    page = page0;
    island = dom.rt.add(ss.SiteSearch, &page, &page0, ss.sel) catch return dom.dom.warn("search: out of memory");
    dom.rt.changed = changed;
    const input = root.call("querySelector", .{zjb.constString("input")}, zjb.Handle);
    defer input.release();
    var buf: [256]u8 = undefined;
    const value = input.get("value", zjb.Handle);
    defer value.release();
    const focused = input.call("matches", .{zjb.constString(":focus")}, bool);
    page.adopted(value.readString(&buf) catch "", focused);
    const w = zjb.global("window");
    w.set("meioSearch", true);
    page.go = w.get("meioSearchGo", bool);
    if (island) |i| i.render();
    if (page.view_q) |v| page.query = v;
    ask();
    if (dom.stored(ui.yourlookup.recent_key)) |s| {
        page.recent = ui.homepage.recentIds(s, &recent);
        if (island) |i| i.render();
    }
}

fn changed() void {
    if (page.want) ask();
}

/// The view's index, once; a page in no view takes the last one visited (meioView's)
fn ask() void {
    page.want = false;
    if (asked) return;
    if (page.view_q == null) {
        const v = if (view_tried) "" else v: {
            view_tried = true;
            break :v dom.stored("view") orelse "";
        };
        page.query = for (ui.urls.view_queries) |q| {
            if (std.mem.eql(u8, q, v)) break q;
        } else "";
    }
    asked = true;
    const at = for (ui.urls.view_queries, 0..) |q, i| {
        if (std.mem.eql(u8, q, page.query)) break i;
    } else 0;
    const path = std.mem.concat(gpa, u8, &.{ "/", ui.urls.view_dirs[at], ss.data_path }) catch return;
    defer gpa.free(path);
    dom.fetch(path, 0, answered);
}

/// The bytes stay: decoded strings point into them
fn answered(_: i32, bytes: ?[]u8) void {
    const b = bytes orelse {
        asked = false;
        return;
    };
    const d = ui.data.decode(gpa, ss.Data, b) catch return dom.dom.warn("search: bad data");
    index = ss.Index.init(gpa, d) catch return dom.dom.warn("search: out of memory");
    page.index = &index;
    if (island) |i| i.render();
    if (page.go) follow();
}

/// Enter came before the index: the first option, as the submit would have
fn follow() void {
    page.go = false;
    var opts: [ss.max_opts]ss.Opt = undefined;
    const shown = page.options(&opts);
    if (shown.len == 0) return;
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    var t: ui.Tree = .{};
    var h: ui.H = .init(arena.allocator(), &t);
    const href = page.href(&h, shown[@min(page.active orelse 0, shown.len - 1)]);
    if (h.oom) return;
    const s = zjb.string(href);
    defer s.release();
    zjb.global("location").set("href", s);
}
