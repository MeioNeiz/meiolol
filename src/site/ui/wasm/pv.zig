//! ui-pv.wasm: the private numbers (ui.pv) on public champion and matchup pages, loaded
//! from /private/ only by browsers that opened /admin or /private (site/shell.zig
//! admin_link); nginx's login gate covers it and its data. Its box goes after the page's
//! head island, outside every island so no diff meets it. Not an island: nothing in it
//! takes input. A champion page's box follows the shown role and the matchup brief,
//! which the islands patch in place with no event of their own: a MutationObserver
//! redraws, and only a change of what's shown draws
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const pv = ui.pv;
const pd = ui.pvdata;
const Role = ui.role.Role;

pub const panic = zjb.panic;
/// The fragment with the path's role: dom.hash
pub const url_map: dom.UrlMap = .champion;

const gpa = std.heap.wasm_allocator;

var page: zjb.Handle = .null;
var box: zjb.Handle = .null;
/// Decoded slices point into their bytes: both kept for the page's life
var slices: [2]?pd.Slice = .{ null, null };
var arena: std.heap.ArenaAllocator = .init(gpa);
var matchup: ?struct { role: Role, vs: u32 } = null;
var pending: u8 = 0;
/// What's drawn: role, brief champion and its relation
var drawn: [272]u8 = undefined;
var drawn_len: usize = 0;

export fn main() void {
    const doc = zjb.global("document");
    // Its script is added by another, so it runs as soon as it loads, maybe mid-parse
    const state = doc.get("readyState", zjb.Handle);
    defer state.release();
    var buf: [16]u8 = undefined;
    if (std.mem.eql(u8, state.readString(&buf) catch "", "loading")) {
        doc.call("addEventListener", .{ zjb.constString("DOMContentLoaded"), zjb.fnHandle("pvStart", &onReady) }, void);
        return;
    }
    start();
}

fn onReady(e: zjb.Handle) callconv(.c) void {
    e.release();
    start();
}

fn start() void {
    const doc = zjb.global("document");
    page = doc.call("querySelector", .{zjb.constString(".c-cpage[data-id]")}, zjb.Handle).kept();
    if (page == .null) return;
    const id = std.fmt.parseInt(u32, dom.attrOf(page, "data-id"), 10) catch return;
    const vs = dom.attrOf(page, "data-vs");
    if (vs.len > 0) {
        const r = std.meta.stringToEnum(Role, dom.attrOf(page, "data-role")) orelse return;
        matchup = .{ .role = r, .vs = std.fmt.parseInt(u32, vs, 10) catch return };
        pending = 2;
        fetchSlice(id, 0);
        fetchSlice(matchup.?.vs, 1);
    } else {
        pending = 1;
        fetchSlice(id, 0);
    }
}

fn fetchSlice(id: u32, i: i32) void {
    var buf: [48]u8 = undefined;
    dom.fetch(pd.path(&buf, id), i, loaded);
}

fn loaded(i: i32, bytes: ?[]u8) void {
    if (bytes) |b| slices[@intCast(i)] = ui.data.decode(arena.allocator(), pd.Slice, b) catch null;
    pending -= 1;
    if (pending > 0) return;
    if (slices[0] == null) return;
    const anchor = page.call("querySelector", .{zjb.constString("[data-island=champion],[data-island=matchup]")}, zjb.Handle);
    defer anchor.release();
    if (anchor == .null) return;
    box = zjb.global("document").call("createElement", .{zjb.constString("div")}, zjb.Handle).kept();
    anchor.call("after", .{box}, void);
    draw();
    if (matchup != null) return;
    const o = zjb.global("MutationObserver").new(.{zjb.fnHandle("pvChanged", &onChanged)});
    defer o.release();
    const opts = zjb.global("Object").new(.{});
    defer opts.release();
    opts.set("childList", true);
    opts.set("subtree", true);
    opts.set("characterData", true);
    o.call("observe", .{ page, opts }, void);
}

fn onChanged(records: zjb.Handle, observer: zjb.Handle) callconv(.c) void {
    records.release();
    observer.release();
    draw();
}

fn draw() void {
    var lines: [2]pv.Line = undefined;
    var shown: []const pv.Line = &.{};
    var key: [272]u8 = undefined;
    var kw: std.Io.Writer = .fixed(&key);
    const s = &slices[0].?;
    if (matchup) |m| {
        if (pv.matchup(s, if (slices[1]) |*b| b else null, m.role, m.vs)) |l| {
            lines[0] = l;
            shown = lines[0..1];
        }
    } else {
        const r = shownRole();
        var nb: [128]u8 = undefined;
        var rb: [128]u8 = undefined;
        const who = text(".c-mpick .t b", &nb);
        const rel = text(".c-mpick .t small", &rb);
        for ([_][]const u8{ @tagName(r), "|", who, "|", rel }) |part| kw.writeAll(part) catch {};
        // Our own redraw is a mutation too
        if (std.mem.eql(u8, kw.buffered(), drawn[0..drawn_len])) return;
        shown = pv.champion(s, r, pv.brief(who, rel), &lines);
    }
    drawn_len = kw.buffered().len;
    @memcpy(drawn[0..drawn_len], kw.buffered());
    var a: std.heap.ArenaAllocator = .init(gpa);
    defer a.deinit();
    var t: ui.Tree = .{};
    var h: ui.H = .init(a.allocator(), &t);
    const n = pv.view(&h, shown);
    if (h.oom) return;
    const el = dom.nodes(&t, n);
    box.call("replaceWith", .{el}, void);
    box.release();
    box = el.kept();
}

/// The fragment's role (the path's, mapped in), else the one the page was rendered for, else
/// its most played
fn shownRole() Role {
    var buf: [512]u8 = undefined;
    const frag = dom.dom.hash(&buf);
    var it = std.mem.tokenizeAny(u8, frag, "#&");
    while (it.next()) |kv| {
        if (std.mem.startsWith(u8, kv, "role=")) if (std.meta.stringToEnum(Role, kv["role=".len..])) |r| return r;
    }
    if (dom.pageRole()) |r| return r;
    const roles = dom.attrOf(page, "data-roles");
    defer gpa.free(roles);
    var words = std.mem.tokenizeScalar(u8, roles, ' ');
    return std.meta.stringToEnum(Role, words.next() orelse "") orelse .top;
}

/// The first `sel` in the page's text, cut to `buf`
fn text(comptime sel: []const u8, buf: []u8) []const u8 {
    const el = page.call("querySelector", .{zjb.constString(sel)}, zjb.Handle);
    defer el.release();
    if (el == .null) return "";
    const v = el.get("textContent", zjb.Handle);
    defer v.release();
    return v.readString(buf) catch "";
}
