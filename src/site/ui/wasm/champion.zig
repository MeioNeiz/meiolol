//! ui-champion.wasm: the champion page's head (ui.champpage.Top), and the loader of
//! ui-champbuild.wasm, ui-champmore.wasm and ui-champcharts.wasm for the rest. zjb's
//! generated loader (ui-champion.js, `<script src data-wasm>`) calls `main`. Under locks
//! (`lk`) it fetches the renderer's answer as ui-champmore.wasm does; in Meio, Meio's
//! answer for the pick and the locks too
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
        keep(.{ .path = path, .d = d });
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
    answers();
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

/// Top's answers by kind: 0 the lock set's (lockWant), 1 Meio's (meioWant). Each shown
/// once in and kept by path; one fetch at a time for both. A failed fetch keeps an empty
/// answer for its path
fn answers() void {
    const i = island orelse return;
    var shown = false;
    for (0..2) |k| {
        const path = state.answerWant(gpa, k == 1) orelse continue;
        if (ui.tree.eql(path, if (k == 0) state.answer_path else state.meio_path)) {
            gpa.free(path);
            continue;
        }
        const x = keptAt(path) orelse {
            if (asked == null) {
                asked = path;
                dom.fetch(path, @intCast(k), answered);
            } else gpa.free(path);
            continue;
        };
        gpa.free(path);
        if (k == 0) state.setAnswer(x.path, @ptrCast(@alignCast(x.d))) else state.setMeio(x.path, @as(*const ?ui.pvdata.Est, @ptrCast(@alignCast(x.d))).*);
        shown = true;
    }
    if (shown) i.render();
}

/// A lock answer (cp.TopData), or Meio's estimate (?ui.pvdata.Est, null where it has none)
const Kept = struct { path: []const u8, d: *const anyopaque };

fn keptAt(path: []const u8) ?*const Kept {
    for (kept[0..@min(kept_n, kept.len)]) |*x| if (ui.tree.eql(x.path, path)) return x;
    return null;
}

/// The last answers fetched, the oldest replaced: a fixed ring, not an ArrayList, as each
/// ArrayList element type is its own append in the island
var kept: [32]Kept = undefined;
var kept_n: usize = 0;
var asked: ?[]const u8 = null;

fn keep(x: Kept) void {
    kept[kept_n % kept.len] = x;
    kept_n += 1;
}

fn answered(k: i32, bytes: ?[]u8) void {
    const path = asked.?;
    asked = null;
    if (bytes == null) dom.dom.warn("champion: no answer");
    const d: *const anyopaque = if (k == 0) top: {
        const t = gpa.create(cp.TopData) catch return;
        t.* = .{ .name = "", .slug = "", .icon = "", .patch = "", .ddragon = "", .champs = &.{}, .roles = &.{} };
        if (bytes) |b| t.* = ui.data.decode(gpa, cp.TopData, b) catch t.*;
        break :top t;
    } else meio: {
        const e = gpa.create(?ui.pvdata.Est) catch return;
        e.* = if (bytes) |b| ui.data.decodeField(ui.pvdata.Meio, "stack", b) catch null else null;
        break :meio e;
    };
    keep(.{ .path = path, .d = d });
    answers();
}
