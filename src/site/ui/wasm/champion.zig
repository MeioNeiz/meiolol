//! ui-champion.wasm: the champion page's head (ui.champpage.Top), and the loader of
//! ui-champbuild.wasm, ui-champmore.wasm and ui-champcharts.wasm for the rest. zjb's
//! generated loader (ui-champion.js, `<script src data-wasm>`) calls `main`. Under locks
//! (`lk`) it fetches the renderer's answer as ui-champmore.wasm does
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
const lazy = [_][]const u8{ "[data-island=champbuild]", "[data-island=champmore]", "[data-island=champtrends]", "[data-island=champcharts]" };

var data: cp.TopData = undefined;
var state: cp.Top = undefined;
var server: cp.Top = undefined;
var src: []const u8 = "";
var root_path: []const u8 = "";
var want: u32 = 0;
var island: ?*ui.island.Island(cp.Top, dom.Dom) = null;
var answers: std.ArrayList(Answer) = .empty;
const Answer = struct { path: []const u8, d: *const cp.TopData };
var asked: ?[]const u8 = null;
var server_lk: []const u8 = "";
var server_ans: ?[]u8 = null;

export fn main() void {
    dom.start();
    dom.normalise();
    dom.lazyLoad(&lazy);
    const root = zjb.global("document").call("querySelector", .{zjb.constString(sel)}, zjb.Handle);
    if (root == .null) return dom.lazyLater();
    defer root.release();
    src = dom.attrOf(root, "data-src");
    root_path = dom.attrOf(root, "data-root");
    server_lk = dom.attrOf(root, "data-lk");
    server_ans = dom.binOf(root, "data-ans");
    const stamp = dom.attrOf(root, "data-stamp");
    want = std.fmt.parseInt(u32, stamp, 10) catch return dom.lazyLater();
    dom.fetchStamped(src, stamp, 0, loaded);
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
    var u: cp.Top.Url = .{ .role = dom.pageRole() };
    u.lk.set(server_lk);
    server.fromUrl(u);
    if (server_ans) |sb| if (server.lockWant(gpa)) |path| {
        const d = gpa.create(cp.TopData) catch return;
        d.* = ui.data.decode(gpa, cp.TopData, sb) catch return;
        answers.append(gpa, .{ .path = path, .d = d }) catch return;
        server.setAnswer(path, d);
    };
    state = .init(&data, pp, root_path);
    state.src = src;
    state.stamp = want;
    const i = dom.rt.add(cp.Top, &state, &server, sel) catch return dom.dom.warn("champion: out of memory");
    island = i;
    loader.start(&state, i);
    dom.rt.changed = changed;
    changed();
}

/// The view picked last, for the site's other pages' links (html.zig meio_view)
var stored: u8 = 0;

fn changed() void {
    loader.check();
    locks();
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

/// The answer the lock set wants, shown once in; one fetch at a time, kept by path
fn locks() void {
    const i = island orelse return;
    const path = state.lockWant(gpa) orelse return;
    if (ui.tree.eql(path, state.answer_path)) return gpa.free(path);
    for (answers.items) |x| if (ui.tree.eql(x.path, path)) {
        gpa.free(path);
        state.setAnswer(x.path, x.d);
        return i.render();
    };
    if (asked != null) return gpa.free(path);
    asked = path;
    dom.fetch(path, 0, answered);
}

fn answered(_: i32, bytes: ?[]u8) void {
    const path = asked.?;
    asked = null;
    const d = gpa.create(cp.TopData) catch return;
    d.* = .{ .name = "", .slug = "", .icon = "", .patch = "", .ddragon = "", .champs = &.{}, .roles = &.{} };
    if (bytes) |b| {
        d.* = ui.data.decode(gpa, cp.TopData, b) catch d.*;
    } else dom.dom.warn("champion: no lock answer");
    answers.append(gpa, .{ .path = path, .d = d }) catch return;
    locks();
}
