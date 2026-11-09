//! ui-champtrends.wasm: the champion page's by patch, by game length, players, by rank and
//! first item done (ui.champpage.Trends). ui-champion.wasm adds its loader
//! (ui-champtrends.js) to the page, which calls `main`. Under locks (`lk`) it fetches the
//! renderer's answer as ui-champmore.wasm does
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const cp = ui.champpage;

pub const panic = zjb.panic;
pub const url_map: dom.UrlMap = .follow;

const gpa = std.heap.wasm_allocator;
const sel = "[data-island=champtrends]";

var data: cp.TrendsData = undefined;
var state: cp.Trends = undefined;
var server: cp.Trends = undefined;
var src: []const u8 = "";
var root_path: []const u8 = "";
var js: []const u8 = "";
var wasm: []const u8 = "";
var want: u32 = 0;
var island: ?*ui.island.Island(cp.Trends, dom.Dom) = null;
var answers: std.ArrayList(Answer) = .empty;
const Answer = struct { path: []const u8, d: *const cp.TrendsData };
const empty: cp.TrendsData = .{ .name = "", .ddragon = "", .champs = &.{}, .roles = &.{}, .lengths = &.{} };
var asked: ?[]const u8 = null;
var server_lk: []const u8 = "";
var server_ans: ?[]u8 = null;

const L = dom.Loader(cp.Trends, cp.TrendsData, ui.champrank.More);

export fn main() void {
    dom.start();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    src = dom.attrOf(root, "data-src");
    root_path = dom.attrOf(root, "data-root");
    js = dom.attrOf(root, "data-js");
    wasm = dom.attrOf(root, "data-wasm");
    server_lk = dom.attrOf(root, "data-lk");
    server_ans = dom.binOf(root, "data-ans");
    const stamp = dom.attrOf(root, "data-stamp");
    want = std.fmt.parseInt(u32, stamp, 10) catch return;
    dom.fetchStamped(src, stamp, 0, loaded);
}

fn loaded(_: i32, bytes: ?[]u8) void {
    const b = bytes orelse return dom.dom.warn("champtrends: no data");
    if (cp.stamp(b) != want) return dom.dom.warn("champtrends: the page and its data differ");
    data = ui.data.decode(gpa, cp.TrendsData, b) catch return dom.dom.warn("champtrends: bad data");
    server = .{ .data = &data, .root = root_path, .src = src, .stamp = want, .js = js, .wasm = wasm };
    server.files.base[0] = &data;
    var u: cp.Trends.Url = .{ .role = dom.pageRole() };
    u.lk.set(server_lk);
    server.fromUrl(u);
    if (server_ans) |sb| if (server.lockWant(gpa)) |path| {
        const d = gpa.create(cp.TrendsData) catch return;
        d.* = ui.data.decode(gpa, cp.TrendsData, sb) catch return;
        answers.append(gpa, .{ .path = path, .d = d }) catch return;
        server.setAnswer(gpa, path, d);
    };
    state = server;
    const i = dom.rt.add(cp.Trends, &state, &server, sel) catch return dom.dom.warn("champtrends: out of memory");
    island = i;
    L.start(&state, i);
    dom.rt.changed = changed;
    lock();
}

fn changed() void {
    L.check();
    lock();
}

/// The answer the lock set wants, kept by path; one fetch at a time
fn lock() void {
    const i = island orelse return;
    const path = state.lockWant(gpa) orelse return;
    if (ui.tree.eql(path, state.answer_path)) return gpa.free(path);
    for (answers.items) |x| if (ui.tree.eql(x.path, path)) {
        gpa.free(path);
        state.setAnswer(gpa, x.path, x.d);
        return i.render();
    };
    if (asked != null) return gpa.free(path);
    asked = path;
    dom.fetch(path, 0, answered);
}

fn answered(_: i32, bytes: ?[]u8) void {
    const path = asked.?;
    asked = null;
    if (bytes == null) dom.dom.warn("champtrends: no answer");
    const d = gpa.create(cp.TrendsData) catch return;
    d.* = ui.data.decode(gpa, cp.TrendsData, bytes orelse "") catch empty;
    answers.append(gpa, .{ .path = path, .d = d }) catch return;
    lock();
}
