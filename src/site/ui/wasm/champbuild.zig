//! ui-champbuild.wasm: the champion page's build (ui.champpage.Build), and the matchup
//! page's from its data-bin. ui-champion.wasm (ui-matchup.wasm) adds its loader
//! (ui-champbuild.js) to the page, which calls `main`. Under locks (`lk`) it fetches the
//! renderer's answer for the lock set (cp.Build.lockWant), one at a time, kept by path;
//! the one the server rendered comes inline (data-lk, data-ans)
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
var want: u32 = 0;
var island: ?*ui.island.Island(cp.Build, dom.Dom) = null;
/// The island root: cp.Build.served reads it
var root_el: zjb.Handle = .null;
/// Lock answers by path, a handful a visit: a list, as a hash map's code costs more than
/// its search saves. A path with no answer holds an empty BuildData
var answers: std.ArrayList(Answer) = .empty;
const Answer = struct { path: []const u8, d: *const cp.BuildData };
var asked: ?[]const u8 = null;
/// The server's answer under its lock set (data-lk), when it rendered one
var server_ans: ?[]u8 = null;

const L = dom.Loader(cp.Build, cp.BuildData, ui.champrank.Build);

export fn main() void {
    dom.start();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(sel)}, zjb.Handle);
    if (root == .null) return;
    root_el = root;
    if (dom.binOf(root, "data-bin")) |b| return inline_(b);
    src = dom.attrOf(root, "data-src");
    server_ans = dom.binOf(root, "data-ans");
    const stamp = dom.attrOf(root, "data-stamp");
    if (stamp.len == 0) return;
    // By hand: std's parseInt is ~150 B gz here
    for (stamp) |c| {
        if (c < '0' or c > '9') return;
        want = want *% 10 +% (c - '0');
    }
    dom.fetchStamped(src, stamp, 0, loaded);
}

fn loaded(_: i32, bytes: ?[]u8) void {
    const b = bytes orelse return dom.dom.warn("champbuild: no data");
    if (cp.stamp(b) != want) return dom.dom.warn("champbuild: the page and its data differ");
    const i = adopt(b) orelse return;
    island = i;
    L.start(&state, i);
    dom.rt.changed = changed;
    locks();
}

fn changed() void {
    L.check();
    locks();
}

/// The answer the lock set wants, shown once in
fn locks() void {
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
    const d = gpa.create(cp.BuildData) catch return;
    d.* = .{ .roles = &.{} };
    if (bytes) |b| {
        d.* = ui.data.decode(gpa, cp.BuildData, b) catch .{ .roles = &.{} };
    } else dom.dom.warn("champbuild: no lock answer");
    answers.append(gpa, .{ .path = path, .d = d }) catch return;
    locks();
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
    server = .served(&data, sp, want, dom.pageRole(), Attrs{});
    const ans = serverAnswer();
    state = server;
    state.panels = pp;
    if (ans) |x| state.setAnswer(gpa, x.path, x.d);
    return dom.rt.add(cp.Build, &state, &server, sel) catch oom();
}

/// The server's answer shown on `server` (and kept by path), so hydration matches its HTML
fn serverAnswer() ?Answer {
    const b = server_ans orelse return null;
    const path = server.lockWant(gpa) orelse return null;
    const d = gpa.create(cp.BuildData) catch return null;
    d.* = ui.data.decode(gpa, cp.BuildData, b) catch return null;
    answers.append(gpa, .{ .path = path, .d = d }) catch return null;
    server.setAnswer(gpa, path, d);
    return answers.items[answers.items.len - 1];
}

fn oom() ?*ui.island.Island(cp.Build, dom.Dom) {
    dom.dom.warn("champbuild: out of memory");
    return null;
}

const Attrs = struct {
    pub fn get(_: Attrs, attr: []const u8) []const u8 {
        return dom.attrOf(root_el, attr);
    }
};
