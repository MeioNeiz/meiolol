//! ui-champion.wasm: the champion page's head (ui.champpage.Top), and the loader of
//! ui-champbuild.wasm and ui-champmore.wasm for the rest. zjb's generated loader
//! (ui-champion.js, `<script src data-wasm>`) calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const cp = ui.champpage;

pub const panic = zjb.panic;
pub const url_map: dom.UrlMap = .champion;

const gpa = std.heap.wasm_allocator;
const sel = "[data-island=champion]";
/// The islands of the page's other files (dom.lazyLoad)
const lazy = [_][]const u8{ "[data-island=champbuild]", "[data-island=champmore]" };

var data: cp.TopData = undefined;
var state: cp.Top = undefined;
var server: cp.Top = undefined;
var src: []const u8 = "";
var root_path: []const u8 = "";
var want: u32 = 0;

export fn main() void {
    dom.start();
    dom.normalise();
    dom.lazyLoad(&lazy);
    const root = zjb.global("document").call("querySelector", .{zjb.constString(sel)}, zjb.Handle);
    if (root == .null) return dom.lazyLater();
    defer root.release();
    src = dom.attrOf(root, "data-src");
    root_path = dom.attrOf(root, "data-root");
    want = std.fmt.parseInt(u32, dom.attrOf(root, "data-stamp"), 10) catch return dom.lazyLater();
    dom.fetch(src, 0, loaded);
}

fn loaded(_: i32, bytes: ?[]u8) void {
    defer dom.lazyLater();
    const b = bytes orelse return dom.dom.warn("champion: no data");
    // A page cached from an older build than its data: leave it as rendered
    if (cp.stamp(b) != want) return dom.dom.warn("champion: the page and its data differ");
    data = ui.data.decode(gpa, cp.TopData, b) catch return dom.dom.warn("champion: bad data");
    // Each its own prepared panels: the server's stays as rendered for hydration
    const pp = cp.prepare(gpa, &data, root_path) catch return dom.dom.warn("champion: out of memory");
    server = .init(&data, pp, root_path);
    server.src = src;
    server.stamp = want;
    server.fromUrl(.{ .role = dom.pageRole() });
    state = .init(&data, pp, root_path);
    state.src = src;
    state.stamp = want;
    const i = dom.rt.add(cp.Top, &state, &server, sel) catch return dom.dom.warn("champion: out of memory");
    loader.start(&state, i);
    dom.rt.changed = changed;
    changed();
}

/// The view picked last, for the site's other pages' links (html.zig meio_view)
var stored: u8 = 0;

fn changed() void {
    loader.check();
    const v = state.files.want.view;
    if (v == stored) return;
    stored = v;
    const window = zjb.global("window");
    if (!window.call("hasOwnProperty", .{zjb.constString("meioView")}, bool)) return;
    const d = zjb.string(ui.urls.view_queries[v]);
    defer d.release();
    window.call("meioView", .{d}, void);
}

const loader = dom.Loader(cp.Top, cp.TopData, ui.champrank.Top);
