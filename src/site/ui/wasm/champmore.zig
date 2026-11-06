//! ui-champmore.wasm: the champion page's matchups and the cards under them
//! (ui.champpage.More). ui-champion.wasm adds its loader (ui-champmore.js) to the page,
//! which calls `main`. Under locks (`lk`) it fetches the renderer's answer as
//! ui-champbuild.wasm does; in Meio, Meio's answer as ui-champion.wasm does
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const cp = ui.champpage;

pub const panic = zjb.panic;
pub const url_map: dom.UrlMap = .follow;

const gpa = std.heap.wasm_allocator;
const sel = "[data-island=champmore]";

var data: cp.MoreData = undefined;
var state: cp.More = undefined;
var server: cp.More = undefined;
var src: []const u8 = "";
var root_path: []const u8 = "";
var js: []const u8 = "";
var wasm: []const u8 = "";
var want: u32 = 0;
var island: ?*ui.island.Island(cp.More, dom.Dom) = null;
var answers: std.ArrayList(Answer) = .empty;
/// A lock answer (`d`) or Meio's (`meio`, null for none)
const Answer = struct { path: []const u8, d: *const cp.MoreData = &empty, meio: ?ui.matchgrid.Meio = null };
const empty: cp.MoreData = .{ .name = "", .slug = "", .ddragon = "", .champs = &.{}, .roles = &.{} };
var asked: ?[]const u8 = null;
var server_lk: []const u8 = "";
var server_ans: ?[]u8 = null;

const L = dom.Loader(cp.More, cp.MoreData, ui.champrank.More);

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
    const b = bytes orelse return dom.dom.warn("champmore: no data");
    if (cp.stamp(b) != want) return dom.dom.warn("champmore: the page and its data differ");
    data = ui.data.decode(gpa, cp.MoreData, b) catch return dom.dom.warn("champmore: bad data");
    server = .{ .data = &data, .root = root_path, .src = src, .stamp = want, .js = js, .wasm = wasm };
    server.files.base[0] = &data;
    var u: cp.More.Url = .{ .role = dom.pageRole() };
    u.lk.set(server_lk);
    server.fromUrl(u);
    if (server_ans) |sb| if (server.lockWant(gpa)) |path| {
        const d = gpa.create(cp.MoreData) catch return;
        d.* = ui.data.decode(gpa, cp.MoreData, sb) catch return;
        answers.append(gpa, .{ .path = path, .d = d }) catch return;
        server.setAnswer(gpa, path, d);
    };
    state = server;
    const i = dom.rt.add(cp.More, &state, &server, sel) catch return dom.dom.warn("champmore: out of memory");
    island = i;
    L.start(&state, i);
    dom.rt.changed = changed;
    locks();
}

fn changed() void {
    L.check();
    locks();
}

/// The answers the lock set and Meio want, Meio's first, each shown once in; one fetch at
/// a time for both, kept by path (a Meio path never matches a lock's)
fn locks() void {
    if (state.meioWant(gpa)) |path| if (show(.meio, path)) return;
    if (state.lockWant(gpa)) |path| _ = show(.lock, path);
}

const Kind = enum(i32) { lock, meio };

/// Shows the answer at `path`, kept or fetched; false when it's already in
fn show(k: Kind, path: []const u8) bool {
    const i = island orelse return true;
    if (ui.tree.eql(path, if (k == .meio) state.meio_path else state.answer_path)) {
        gpa.free(path);
        return false;
    }
    for (answers.items) |x| if (ui.tree.eql(x.path, path)) {
        gpa.free(path);
        if (k == .meio) state.setMeio(x.path, x.meio) else state.setAnswer(gpa, x.path, x.d);
        i.render();
        return true;
    };
    if (asked != null) {
        gpa.free(path);
        return true;
    }
    asked = path;
    dom.fetch(path, @backingInt(k), answered);
    return true;
}

fn answered(k: i32, bytes: ?[]u8) void {
    var x: Answer = .{ .path = asked.? };
    asked = null;
    const b = bytes orelse "";
    if (bytes == null) dom.dom.warn("champmore: no answer");
    if (k == @backingInt(Kind.meio)) {
        if (ui.data.decodeHead(gpa, ui.pvdata.Meio, ui.matchgrid.Meio, b)) |m| x.meio = m.head else |_| {}
    } else {
        const d = gpa.create(cp.MoreData) catch return;
        d.* = ui.data.decode(gpa, cp.MoreData, b) catch empty;
        x.d = d;
    }
    answers.append(gpa, x) catch return;
    locks();
}
