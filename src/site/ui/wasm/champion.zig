//! ui-champion.wasm: the champion page's head (ui.champpage.Top), and the loader of
//! ui-champbuild.wasm and ui-champmore.wasm for the rest. zjb's generated loader
//! (ui-champion.js, `<script src data-wasm>`) calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const cp = ui.champpage;

pub const panic = zjb.panic;

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
    fold();
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
    state = .init(&data, pp, root_path);
    state.src = src;
    state.stamp = want;
    const i = dom.rt.add(cp.Top, &state, &server, sel) catch return dom.dom.warn("champion: out of memory");
    loader.start(&state, i);
    dom.rt.changed = changed;
    changed();
}

/// Links from a view's pages carry its pick as a query (html.View.query): into the
/// fragment, where the islands read it, ahead of the fragment's own keys
fn fold() void {
    var buf: [512]u8 = undefined;
    const loc = zjb.global("location");
    const q = loc.get("search", zjb.Handle);
    defer q.release();
    const s = q.readString(&buf) catch return;
    if (s.len < 2) return;
    var frag: [1024]u8 = undefined;
    const h = dom.dom.hash(&frag);
    const path = loc.get("pathname", zjb.Handle);
    defer path.release();
    var to: [2048]u8 = undefined;
    const p = path.readString(&to) catch return;
    const all = std.fmt.bufPrint(to[p.len..], "#{s}{s}{s}", .{ s[1..], if (h.len > 1) "&" else "", if (h.len > 1) h[1..] else "" }) catch return;
    dom.dom.setHash(to[0 .. p.len + all.len], false);
}

/// The view picked last, for the site's other pages' links (html.zig meio_view)
var stored: u8 = 0;

fn changed() void {
    loader.check();
    const v = state.files.want.view;
    if (v == stored) return;
    stored = v;
    const dirs = [_][]const u8{ "", "patch/", "all/", "all/patch/" };
    const window = zjb.global("window");
    if (!window.call("hasOwnProperty", .{zjb.constString("meioView")}, bool)) return;
    const d = zjb.string(dirs[v]);
    defer d.release();
    window.call("meioView", .{d}, void);
}

const loader = dom.Loader(cp.Top, cp.TopData, ui.champrank.Top);
