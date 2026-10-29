//! ui-champbuild.wasm: the champion page's build (ui.champpage.Build), and the matchup
//! page's from its data-bin. ui-champion.wasm (ui-matchup.wasm) adds its loader
//! (ui-champbuild.js) to the page, which calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const cp = ui.champpage;

pub const panic = zjb.panic;
pub const url_map: dom.UrlMap = .follow;

const gpa = std.heap.wasm_allocator;
const sel = "[data-island=champbuild]";

var data: cp.BuildData = undefined;
var state: cp.Build = undefined;
var server: cp.Build = undefined;
var src: []const u8 = "";
var root_path: []const u8 = "";
var js: []const u8 = "";
var wasm: []const u8 = "";
var want: u32 = 0;

export fn main() void {
    dom.start();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    js = dom.attrOf(root, "data-js");
    wasm = dom.attrOf(root, "data-wasm");
    if (dom.binOf(root, "data-bin")) |b| return inline_(b);
    src = dom.attrOf(root, "data-src");
    root_path = dom.attrOf(root, "data-root");
    const stamp = dom.attrOf(root, "data-stamp");
    want = std.fmt.parseInt(u32, stamp, 10) catch return;
    dom.fetchStamped(src, stamp, 0, loaded);
}

fn loaded(_: i32, bytes: ?[]u8) void {
    const b = bytes orelse return dom.dom.warn("champbuild: no data");
    if (cp.stamp(b) != want) return dom.dom.warn("champbuild: the page and its data differ");
    const i = adopt(b) orelse return;
    dom.Loader(cp.Build, cp.BuildData, ui.champrank.Build).start(&state, i);
}

/// The matchup page's: one view, so no loader
fn inline_(b: []u8) void {
    _ = adopt(b);
}

fn adopt(b: []u8) ?*ui.island.Island(cp.Build, dom.Dom) {
    data = ui.data.decode(gpa, cp.BuildData, b) catch {
        dom.dom.warn("champbuild: bad data");
        return null;
    };
    // Each its own panels: the server's stay as rendered for hydration
    const sp = cp.panels(gpa, data.roles) catch return oom();
    const pp = cp.panels(gpa, data.roles) catch return oom();
    server = .{ .data = &data, .panels = sp, .root = root_path, .src = src, .stamp = want, .js = js, .wasm = wasm };
    server.files.base[0] = &data;
    server.fromUrl(.{ .role = dom.pageRole() });
    state = server;
    state.panels = pp;
    return dom.rt.add(cp.Build, &state, &server, sel) catch oom();
}

fn oom() ?*ui.island.Island(cp.Build, dom.Dom) {
    dom.dom.warn("champbuild: out of memory");
    return null;
}
