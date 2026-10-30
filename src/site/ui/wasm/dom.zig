//! ui.wasm's only door to the page: the island runtime's Dom (island.zig) as zjb calls.
//! No JS of ours beyond zjb's generated loader (Jacob 22 and 25 Oct). Each DOM node we
//! made or adopted is a zjb handle in `nodes`, by DOM id, and carries its id as `__n` so
//! an event's target finds its node; a removed node's handle is released.
//!
//! Every callback from the page here runs in a zjb scope: the handles it makes are
//! released when it returns. Rule, here and in the entries: a handle that outlives the
//! callback it was made in is kept (`kept()`), or the scope releases it under you.
//! -Dwasm-dev reports any handle neither kept nor released
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const options = @import("wasm_options");
const tree = ui.tree;

const gpa = std.heap.wasm_allocator;

pub const Dom = struct {
    nodes: std.ArrayList(zjb.Handle) = .empty,
    /// Each island's root element, by slot
    roots: std.ArrayList(zjb.Handle) = .empty,
    listening: std.ArrayList(u16) = .empty,
    no_scroll: zjb.Handle = .null,

    fn node(d: *Dom, id: u32) zjb.Handle {
        return if (id < d.nodes.items.len) d.nodes.items[id] else .null;
    }

    fn put(d: *Dom, id: u32, h: zjb.Handle) void {
        if (id >= d.nodes.items.len) d.nodes.appendNTimes(gpa, .null, id + 1 - d.nodes.items.len) catch @panic("out of memory");
        d.nodes.items[id] = h.kept();
        h.set("__n", @as(i32, @intCast(id)));
    }

    // The diff's ops

    pub fn el(d: *Dom, id: u32, tag: tree.Tag) void {
        const name = zjb.string(@tagName(tag));
        defer name.release();
        const doc = zjb.global("document");
        d.put(id, if (tag.isSvg())
            doc.call("createElementNS", .{ zjb.constString("http://www.w3.org/2000/svg"), name }, zjb.Handle)
        else
            doc.call("createElement", .{name}, zjb.Handle));
    }

    pub fn text(d: *Dom, id: u32, s: []const u8) void {
        const t = zjb.string(s);
        defer t.release();
        d.put(id, zjb.global("document").call("createTextNode", .{t}, zjb.Handle));
    }

    pub fn attr(d: *Dom, id: u32, name: []const u8, v: []const u8) void {
        const val = zjb.string(v);
        defer val.release();
        // An input's value is its property: the attribute is only the default. Setting
        // the same text leaves the caret alone
        if (std.mem.eql(u8, name, "value")) return d.node(id).set("value", val);
        const k = zjb.string(name);
        defer k.release();
        d.node(id).call("setAttribute", .{ k, val }, void);
    }

    pub fn del(d: *Dom, id: u32, name: []const u8) void {
        const k = zjb.string(name);
        defer k.release();
        d.node(id).call("removeAttribute", .{k}, void);
    }

    pub fn data(d: *Dom, id: u32, s: []const u8) void {
        const t = zjb.string(s);
        defer t.release();
        d.node(id).set("data", t);
    }

    pub fn ins(d: *Dom, parent: u32, id: u32, before: u32) void {
        const b = d.node(before);
        if (b == .null) {
            d.node(parent).call("insertBefore", .{ d.node(id), zjb.ConstHandle.null }, void);
        } else d.node(parent).call("insertBefore", .{ d.node(id), b }, void);
    }

    pub fn rm(d: *Dom, id: u32) void {
        d.node(id).call("remove", .{}, void);
    }

    pub fn forget(d: *Dom, id: u32) void {
        if (id >= d.nodes.items.len) return;
        d.nodes.items[id].release();
        d.nodes.items[id] = .null;
    }

    // What the runtime asks of the page

    /// The server's nodes under `sel` in pre-order, comments skipped (html.zig writes
    /// `<!---->` between text nodes), ids from `first`
    pub fn adopt(d: *Dom, sel: []const u8, first: u32) u32 {
        const s = zjb.string(sel);
        defer s.release();
        const root = zjb.global("document").call("querySelector", .{s}, zjb.Handle);
        if (root == .null) return 0;
        d.roots.append(gpa, root.kept()) catch @panic("out of memory");
        d.listening.append(gpa, 0) catch @panic("out of memory");
        var id = first;
        d.walk(root, &id);
        return id - first;
    }

    fn walk(d: *Dom, h: zjb.Handle, id: *u32) void {
        d.put(id.*, h);
        id.* += 1;
        var c = h.get("firstChild", zjb.Handle);
        while (c != .null) {
            const next = c.get("nextSibling", zjb.Handle);
            if (c.get("nodeType", i32) == 8) c.release() else d.walk(c, id);
            c = next;
        }
    }

    /// One listener per event kind on the island's root, in the capture phase (toggle and
    /// pointerleave don't bubble); pointerleave listens as pointerout with its related
    /// node
    pub fn listen(d: *Dom, slot: u32, _: []const u8, mask: u16) void {
        const root = d.roots.items[slot];
        const was = d.listening.items[slot];
        inline for (@typeInfo(tree.Ev).@"enum".field_names, 0..) |name, bit| {
            const b: u16 = 1 << bit;
            if (mask & b != 0 and was & b == 0) {
                const kind = comptime if (std.mem.eql(u8, name, "pointerleave")) "pointerout" else name;
                const f = zjb.fnHandle("uiEvent", &onEvent).bind(.{ @as(i32, @intCast(slot)), @as(i32, bit) });
                root.call("addEventListener", .{ zjb.constString(kind), f, @as(i32, 1) }, void);
                f.release();
            }
        }
        d.listening.items[slot] = was | mask;
    }

    pub fn rect(d: *Dom, id: u32) [3]f32 {
        const r = d.node(id).call("getBoundingClientRect", .{}, zjb.Handle);
        defer r.release();
        return .{ @floatCast(r.get("left", f64)), @floatCast(r.get("top", f64)), @floatCast(r.get("width", f64)) };
    }

    pub fn capture(d: *Dom, id: u32, pointer: i32) void {
        d.node(id).call("setPointerCapture", .{pointer}, void);
    }

    pub fn active(_: *Dom) u32 {
        const a = zjb.global("document").get("activeElement", zjb.Handle);
        defer a.release();
        if (a == .null) return 0;
        return @intCast(@max(a.get("__n", i32), 0));
    }

    pub fn focus(d: *Dom, id: u32) void {
        if (d.no_scroll == .null) {
            d.no_scroll = zjb.global("Object").new(.{}).kept();
            d.no_scroll.set("preventScroll", @as(i32, 1));
        }
        d.node(id).call("focus", .{d.no_scroll}, void);
    }

    pub fn click(d: *Dom, id: u32) void {
        d.node(id).call("click", .{}, void);
    }

    pub fn scroll(d: *Dom, id: u32) void {
        const o = zjb.global("Object").new(.{});
        defer o.release();
        o.set("block", zjb.constString("nearest"));
        d.node(id).call("scrollIntoView", .{o}, void);
    }

    /// Scrolls the node's parent sideways to put the node in its middle; unlike
    /// scrollIntoView, the page stays where it is
    pub fn centre(d: *Dom, id: u32) void {
        const n = d.node(id);
        const p = n.get("parentElement", zjb.Handle);
        defer p.release();
        if (p == .null) return;
        const nr = n.call("getBoundingClientRect", .{}, zjb.Handle);
        defer nr.release();
        const pr = p.call("getBoundingClientRect", .{}, zjb.Handle);
        defer pr.release();
        const mid = nr.get("left", f64) + nr.get("width", f64) / 2;
        const pmid = pr.get("left", f64) + pr.get("width", f64) / 2;
        p.set("scrollLeft", p.get("scrollLeft", f64) + mid - pmid);
    }

    pub fn jump(_: *Dom, id: []const u8) void {
        const s = zjb.string(id);
        defer s.release();
        const t = zjb.global("document").call("getElementById", .{s}, zjb.Handle);
        defer t.release();
        if (t != .null) t.call("scrollIntoView", .{}, void);
    }

    pub fn popover(d: *Dom, id: u32, show: bool) void {
        const n = d.node(id);
        const open = n.call("matches", .{zjb.constString(":popover-open")}, bool);
        if (show and !open) n.call("showPopover", .{}, void);
        if (!show and open) n.call("hidePopover", .{}, void);
    }

    /// The islands' fragment: with a url_map, the address bar's mapped parts as keys
    /// ahead of the fragment's own
    pub fn hash(_: *Dom, buf: []u8) []const u8 {
        if (url_map == .follow and leader()) {
            const v = zjb.global("window").get("meioFrag", zjb.Handle);
            defer v.release();
            return v.readString(buf) catch "";
        }
        if (url_map == .none or url_map == .follow) return location("hash", buf);
        var frag: [1024]u8 = undefined;
        const h = location("hash", &frag);
        var w: std.Io.Writer = .fixed(buf);
        virtual(&w, h) catch return "";
        return w.buffered();
    }

    /// `#` alone: the page's own URL without a fragment. With a url_map, its keys go to
    /// the path or query
    pub fn setHash(_: *Dom, s: []const u8, push: bool) void {
        if (url_map == .follow and leader()) {
            const t = zjb.string(s);
            defer t.release();
            sending = true;
            defer sending = false;
            return zjb.global("window").call("meioSetHash", .{ t, push }, void);
        }
        var buf: [2048]u8 = undefined;
        const target = if (url_map == .none or url_map == .follow) if (s.len > 1) s else blk: {
            const p = location("pathname", &buf);
            const q = location("search", buf[p.len..]);
            break :blk buf[0 .. p.len + q.len];
        } else blk: {
            var w: std.Io.Writer = .fixed(&buf);
            address(&w, s) catch return;
            break :blk w.buffered();
        };
        const t = zjb.string(target);
        defer t.release();
        const args = .{ zjb.ConstHandle.null, zjb.ConstHandle.empty_string, t };
        if (push) zjb.global("history").call("pushState", args, void) else zjb.global("history").call("replaceState", args, void);
        share();
        // The page's other ui.wasm files (each its own runtime) read the fragment again
        sending = true;
        defer sending = false;
        const e = zjb.global("Event").new(.{zjb.constString("ui-hash")});
        defer e.release();
        zjb.global("window").call("dispatchEvent", .{e}, void);
    }

    pub fn warn(_: *Dom, msg: []const u8) void {
        const m = zjb.string(msg);
        defer m.release();
        zjb.global("console").call("error", .{m}, void);
    }
};

pub var dom: Dom = .{};
pub var rt: ui.island.Runtime(Dom) = .{ .gpa = gpa, .dom = &dom };

fn enter() zjb.Scope {
    return zjb.scope();
}

fn leave(s: zjb.Scope) void {
    s.end();
    if (options.dev) checkLater();
}

// -Dwasm-dev: on the next task nothing of ours is on the stack, so every live handle is
// kept or leaked. Not at the scope's end: an event can fire inside another callback (a
// patch removing the focused node fires focusout) while that one holds handles

var check_due = false;
var leaks_told: u32 = 0;

fn checkLater() void {
    if (check_due) return;
    check_due = true;
    zjb.global("window").call("setTimeout", .{ zjb.fnHandle("uiLeaks", &onLeakCheck), @as(i32, 0) }, void);
}

fn onLeakCheck() callconv(.c) void {
    check_due = false;
    const n = zjb.unkeptHandleCount();
    if (n <= leaks_told) return;
    leaks_told = n;
    var buf: [80]u8 = undefined;
    dom.warn(std.fmt.bufPrint(&buf, "zjb: {d} handles neither released nor kept", .{n}) catch "zjb: leaked handles");
}

/// The id of the nearest node we know at or above `h` (0: none). In a scope
fn nearest(h: zjb.Handle) u32 {
    var k = h;
    while (k != .null) : (k = k.get("parentNode", zjb.Handle)) {
        const id = k.get("__n", i32);
        if (id > 0) return @intCast(id);
    }
    return 0;
}

fn onEvent(slot: i32, bit: i32, e: zjb.Handle) callconv(.c) void {
    const s = enter();
    defer leave(s);
    defer e.release();
    const kind: tree.Ev = @fromBackingInt(@intCast(bit));
    var in: ui.island.Input = .{ .kind = kind, .target = nearest(e.get("target", zjb.Handle)) };
    if (in.target == 0) return;
    var buf: [256]u8 = undefined;
    switch (kind) {
        .input, .change => in.text = e.get("target", zjb.Handle).get("value", zjb.Handle).readString(&buf) catch buf[0..0],
        .keydown => {
            // Keys that pick from an IME (Korean, Japanese names) aren't the page's, nor
            // modified ones: Ctrl/Cmd + or - zooms, Alt+Arrow goes back
            if (e.get("isComposing", bool) or e.get("ctrlKey", bool) or e.get("metaKey", bool) or e.get("altKey", bool)) return;
            in.text = e.get("key", zjb.Handle).readString(&buf) catch buf[0..0];
        },
        .pointerdown, .pointermove, .pointerup, .pointerleave, .pointercancel => {
            in.x = @floatCast(e.get("clientX", f64));
            in.y = @floatCast(e.get("clientY", f64));
            in.pointer = e.get("pointerId", i32);
            if (kind == .pointerleave) in.related = nearest(e.get("relatedTarget", zjb.Handle));
        },
        .focusout => in.related = nearest(e.get("relatedTarget", zjb.Handle)),
        .toggle => in.text = if (e.get("target", zjb.Handle).get("open", bool)) "open" else "",
        else => {},
    }
    if (rt.event(@intCast(slot), in)) e.call("preventDefault", .{}, void);
}

/// Which island keys a page's address bar keeps outside the fragment (docs/plan/urls.md);
/// the islands still see one fragment (Dom.hash, setHash). A wasm opts in with `pub const
/// url_map` in its root file, so the others don't grow. champion: role as the path's last
/// segment (/champions/<c>/<r>), region and period in the query; pool: pool as ?champs=;
/// learn: p as the bare fragment (#<id>). follow: the page's champion wasm keeps the
/// address (window.meioFrag, meioSetHash), so the champion page's other wasms don't carry
/// the mapping; the plain fragment without one (the matchup page's build)
pub const UrlMap = enum { none, champion, pool, learn, follow };
const url_map: UrlMap = if (@hasDecl(@import("root"), "url_map")) @import("root").url_map else .none;

/// A mapped key: where it lives in the address bar, and its name there
const Out = struct { key: []const u8, to: enum { path, query, bare }, as: []const u8 = "" };

const outs: []const Out = switch (url_map) {
    .none, .follow => &.{},
    .champion => &.{ .{ .key = "role", .to = .path }, .{ .key = "region", .to = .query, .as = "region" }, .{ .key = "period", .to = .query, .as = "period" } },
    .pool => &.{.{ .key = "pool", .to = .query, .as = "champs" }},
    .learn => &.{.{ .key = "p", .to = .bare }},
};

fn location(comptime part: []const u8, buf: []u8) []const u8 {
    const v = zjb.global("location").get(part, zjb.Handle);
    defer v.release();
    return v.readString(buf) catch "";
}

fn mapped(key: []const u8) ?Out {
    for (outs) |o| if (std.mem.eql(u8, o.key, key)) return o;
    return null;
}

/// "a=1&b=2"'s value of `key`
fn param(list: []const u8, key: []const u8) ?[]const u8 {
    var it = std.mem.tokenizeScalar(u8, list, '&');
    while (it.next()) |kv| {
        const eq = std.mem.findScalar(u8, kv, '=') orelse continue;
        if (std.mem.eql(u8, kv[0..eq], key)) return kv[eq + 1 ..];
    }
    return null;
}

/// /champions/<c>/<r>: the path's role segment, after the champion's
fn pathRole(path: []const u8) ?[]const u8 {
    var it = std.mem.tokenizeScalar(u8, path, '/');
    _ = it.next() orelse return null;
    _ = it.next() orelse return null;
    return it.next();
}

/// The role the server rendered the champion page for (its path's, /champions/<c>/<r>),
/// for an island's server state before hydration. From the page, not the address:
/// normalise() may have moved a legacy #role= into the path since
pub fn pageRole() ?ui.role.Role {
    const el = zjb.global("document").call("querySelector", .{zjb.constString(".c-cpage")}, zjb.Handle);
    if (el == .null) return null;
    defer el.release();
    return std.meta.stringToEnum(ui.role.Role, attrOf(el, "data-role"));
}

/// The fragment the islands read: `h` (location.hash) with the address bar's mapped keys
fn virtual(w: *std.Io.Writer, h: []const u8) !void {
    var pbuf: [512]u8 = undefined;
    var qbuf: [512]u8 = undefined;
    const path = location("pathname", &pbuf);
    const search = location("search", &qbuf);
    const query = if (search.len > 0) search[1..] else "";
    const own = if (h.len > 0) h[1..] else "";
    try w.writeByte('#');
    var n: usize = 0;
    for (outs) |o| {
        const v = switch (o.to) {
            .path => pathRole(path),
            .query => param(query, o.as),
            .bare => if (own.len > 0 and std.mem.findScalar(u8, own, '=') == null) own else null,
        } orelse continue;
        if (n > 0) try w.writeByte('&');
        try w.print("{s}={s}", .{ o.key, v });
        n += 1;
    }
    if (own.len == 0 or std.mem.findScalar(u8, own, '=') == null) return;
    if (n > 0) try w.writeByte('&');
    try w.writeAll(own);
}

/// The address for fragment `s`: its mapped keys into the path and query (keeping the
/// query's other keys), the rest as the fragment
fn address(w: *std.Io.Writer, s: []const u8) !void {
    var pbuf: [512]u8 = undefined;
    var qbuf: [512]u8 = undefined;
    const path = location("pathname", &pbuf);
    const search = location("search", &qbuf);
    const keys = if (s.len > 0 and s[0] == '#') s[1..] else s;
    // The path without its role segment: /champions/<c>
    const base = if (pathRole(path)) |r| path[0 .. path.len - r.len - 1] else path;
    try w.writeAll(base);
    if (param(keys, "role")) |r| if (mapped("role") != null and r.len > 0) try w.print("/{s}", .{r});
    var n: usize = 0;
    var qs = std.mem.tokenizeScalar(u8, if (search.len > 0) search[1..] else "", '&');
    while (qs.next()) |kv| {
        const k = kv[0 .. std.mem.findScalar(u8, kv, '=') orelse kv.len];
        if (for (outs) |o| {
            if (o.to == .query and std.mem.eql(u8, o.as, k)) break true;
        } else false) continue;
        try w.print("{c}{s}", .{ @as(u8, if (n == 0) '?' else '&'), kv });
        n += 1;
    }
    for (outs) |o| if (o.to == .query) if (param(keys, o.key)) |v| if (v.len > 0) {
        try w.print("{c}{s}={s}", .{ @as(u8, if (n == 0) '?' else '&'), o.as, v });
        n += 1;
    };
    var rest: usize = 0;
    var bare: ?[]const u8 = null;
    var it = std.mem.tokenizeScalar(u8, keys, '&');
    while (it.next()) |kv| {
        const k = kv[0 .. std.mem.findScalar(u8, kv, '=') orelse kv.len];
        if (mapped(k)) |o| {
            if (o.to == .bare) bare = kv[k.len + 1 ..];
            continue;
        }
        try w.print("{c}{s}", .{ @as(u8, if (rest == 0) '#' else '&'), kv });
        rest += 1;
    }
    if (bare) |b| if (b.len > 0) {
        // The bare form only alone: beside other keys, p= stays a key
        if (rest == 0) try w.print("#{s}", .{b}) else try w.print("&p={s}", .{b});
    };
}

/// A legacy fragment's mapped keys (an old link's #role=, #pool=, #p=) into the address
/// bar, once at start, before any island reads it
pub fn normalise() void {
    var frag: [1024]u8 = undefined;
    const h = location("hash", &frag);
    var it = std.mem.tokenizeScalar(u8, if (h.len > 0) h[1..] else "", '&');
    while (it.next()) |kv| {
        const eq = std.mem.findScalar(u8, kv, '=') orelse continue;
        if (mapped(kv[0..eq]) == null) continue;
        var buf: [1024]u8 = undefined;
        dom.setHash(dom.hash(&buf), false);
        return;
    }
}

/// In this runtime's own setHash: its ui-hash is for the others
var sending = false;

/// A follower's: the page's champion wasm keeps the address
fn leader() bool {
    return zjb.global("window").call("hasOwnProperty", .{zjb.constString("meioSetHash")}, bool);
}

/// The champion wasm's: the islands' fragment for the page's followers (before they read
/// it on ui-hash or popstate)
fn share() void {
    if (url_map != .champion) return;
    var buf: [1024]u8 = undefined;
    const v = zjb.string(dom.hash(&buf));
    defer v.release();
    zjb.global("window").set("meioFrag", v);
}

/// A follower's setHash: the address, then this runtime's islands (setHash's ui-hash
/// skips its own)
fn onSetHash(v: zjb.Handle, push: bool) callconv(.c) void {
    const s = enter();
    defer leave(s);
    defer v.release();
    var buf: [1024]u8 = undefined;
    dom.setHash(v.readString(&buf) catch return, push);
    rt.popstate();
}

fn onPopstate(e: zjb.Handle) callconv(.c) void {
    const s = enter();
    defer leave(s);
    e.release();
    share();
    if (!sending) rt.popstate();
}

/// Back and Forward, and another runtime's fragment, reach every island
pub fn start() void {
    const w = zjb.global("window");
    const f = zjb.fnHandle("uiPopstate", &onPopstate);
    w.call("addEventListener", .{ zjb.constString("popstate"), f }, void);
    w.call("addEventListener", .{ zjb.constString("ui-hash"), f }, void);
    if (url_map == .champion) {
        w.set("meioSetHash", zjb.fnHandle("uiSetHash", &onSetHash));
        share();
    }
    if (options.dev) checkLater();
}

// The page's other ui.wasm files (lazyLoad's selectors: island roots with data-js and
// data-wasm): each once its island nears the viewport, or once this file is done
// (lazyLater), whichever is first; a deep link or a quick scroll doesn't wait

var lazy: []const []const u8 = &.{};
var started: u32 = 0;

pub fn lazyLoad(sels: []const []const u8) void {
    lazy = sels;
    for (0..sels.len) |i| watch(@intCast(i));
}

fn watch(i: i32) void {
    const q = zjb.string(lazy[@intCast(i)]);
    defer q.release();
    const el = zjb.global("document").call("querySelector", .{q}, zjb.Handle);
    if (el == .null) return;
    defer el.release();
    const opts = zjb.global("Object").new(.{});
    defer opts.release();
    opts.set("rootMargin", zjb.constString("600px"));
    const cb = zjb.fnHandle("uiNear", &onNear).bind(.{i});
    defer cb.release();
    const io = zjb.global("IntersectionObserver").new(.{ cb, opts });
    defer io.release();
    io.call("observe", .{el}, void);
}

fn onNear(i: i32, entries: zjb.Handle, io: zjb.Handle) callconv(.c) void {
    const s = enter();
    defer leave(s);
    defer entries.release();
    defer io.release();
    // Not get("0"): zjb writes the name as a property (`.0`), not valid JS
    const first = entries.call("at", .{@as(i32, 0)}, zjb.Handle);
    if (first == .null or !first.get("isIntersecting", bool)) return;
    io.call("disconnect", .{}, void);
    load(@intCast(i));
}

/// After this file's work: on the next task, so the patch paints first
pub fn lazyLater() void {
    zjb.global("window").call("setTimeout", .{ zjb.fnHandle("uiLater", &onLater), @as(i32, 0) }, void);
}

fn onLater() callconv(.c) void {
    const s = enter();
    defer leave(s);
    for (0..lazy.len) |i| load(i);
}

fn load(i: usize) void {
    const bit = @as(u32, 1) << @intCast(i);
    if (started & bit != 0) return;
    started |= bit;
    script(lazy[i]);
}

/// The file of the island under `sel`: a <script> as the page's own, src and data-wasm
/// from its root. Once per island: the caller keeps track
pub fn script(sel: []const u8) void {
    const doc = zjb.global("document");
    const q = zjb.string(sel);
    defer q.release();
    const el = doc.call("querySelector", .{q}, zjb.Handle);
    if (el == .null) return;
    defer el.release();
    const js = el.call("getAttribute", .{zjb.constString("data-js")}, zjb.Handle);
    defer js.release();
    const wasm = el.call("getAttribute", .{zjb.constString("data-wasm")}, zjb.Handle);
    defer wasm.release();
    if (js == .null or wasm == .null) return;
    const s = doc.call("createElement", .{zjb.constString("script")}, zjb.Handle);
    defer s.release();
    s.call("setAttribute", .{ zjb.constString("data-wasm"), wasm }, void);
    s.call("setAttribute", .{ zjb.constString("data-for"), q }, void);
    s.call("addEventListener", .{ zjb.constString("error"), zjb.fnHandle("uiScriptError", &onScriptError) }, void);
    s.set("src", js);
    const head = doc.get("head", zjb.Handle);
    defer head.release();
    head.call("appendChild", .{s}, void);
}

/// An island whose file failed (a 404 mid-deploy, the network): its root gets
/// data-failed, "show" if it was busy so its CSS can say so, as no file will clear it.
/// A failed .wasm fetch rejects inside zjb's loader and isn't caught here
fn onScriptError(e: zjb.Handle) callconv(.c) void {
    const s = enter();
    defer leave(s);
    defer e.release();
    const q = e.get("target", zjb.Handle).call("getAttribute", .{zjb.constString("data-for")}, zjb.Handle);
    const el = zjb.global("document").call("querySelector", .{q}, zjb.Handle);
    if (el == .null) return;
    const busy = el.call("hasAttribute", .{zjb.constString("aria-busy")}, bool);
    const v = if (busy) zjb.constString("show") else zjb.constString("");
    el.call("setAttribute", .{ zjb.constString("data-failed"), v }, void);
    el.call("removeAttribute", .{zjb.constString("aria-busy")}, void);
}

/// An element's attribute, kept ("" when missing). The name is a runtime string: one
/// copy of this however many attributes a family reads
pub fn attrOf(el: zjb.Handle, name: []const u8) []const u8 {
    const n = zjb.string(name);
    defer n.release();
    const v = el.call("getAttribute", .{n}, zjb.Handle);
    defer v.release();
    if (v == .null) return "";
    return v.allocString(gpa) catch "";
}

/// localStorage's `key`, gpa's; null when missing. Blocked storage throws, ending the
/// calling export there: call it last
pub fn stored(key: []const u8) ?[]const u8 {
    const k = zjb.string(key);
    defer k.release();
    const v = zjb.global("localStorage").call("getItem", .{k}, zjb.Handle);
    defer v.release();
    if (v == .null) return null;
    return v.allocString(gpa) catch null;
}

/// Sets localStorage's `key`; throws as `stored`
pub fn store(key: []const u8, value: []const u8) void {
    const k = zjb.string(key);
    defer k.release();
    const v = zjb.string(value);
    defer v.release();
    zjb.global("localStorage").call("setItem", .{ k, v }, void);
}

/// An attribute's base64 decoded (an island's data-bin), gpa's; null when missing or bad
pub fn binOf(el: zjb.Handle, name: []const u8) ?[]u8 {
    const s = attrOf(el, name);
    if (s.len == 0) return null;
    defer gpa.free(s);
    const d = std.base64.standard.Decoder;
    const out = gpa.alloc(u8, d.calcSizeForSlice(s) catch return null) catch return null;
    d.decode(out, s) catch {
        gpa.free(out);
        return null;
    };
    return out;
}

/// GET `path` (relative to the page), then `done(ctx, bytes)`; bytes are gpa's, the
/// callee's to keep. A failed fetch calls `done` with null
pub fn fetch(path: []const u8, ctx: i32, done: *const fn (i32, ?[]u8) void) void {
    const u = zjb.string(path);
    defer u.release();
    request(zjb.ConstHandle.global.call("fetch", .{u}, zjb.Handle), ctx, done);
}

/// `fetch` with the page's data stamp in the URL (ui.urls.stamped): an island refuses a
/// copy older than its page, leaving the page static
pub fn fetchStamped(path: []const u8, stamp: []const u8, ctx: i32, done: *const fn (i32, ?[]u8) void) void {
    var buf: [512]u8 = undefined;
    fetch(ui.urls.stamped(&buf, path, stamp) orelse return done(ctx, null), ctx, done);
}

/// POST `path` with no body, then as `fetch`
pub fn post(path: []const u8, ctx: i32, done: *const fn (i32, ?[]u8) void) void {
    const u = zjb.string(path);
    defer u.release();
    const init = zjb.global("Object").new(.{});
    defer init.release();
    init.set("method", zjb.constString("POST"));
    request(zjb.ConstHandle.global.call("fetch", .{ u, init }, zjb.Handle), ctx, done);
}

/// `method` `path` with a ui.data `body` and X-Meiolol-Action (the API's writes), then as
/// `fetch`
pub fn send(comptime method: []const u8, path: []const u8, body: []const u8, ctx: i32, done: *const fn (i32, ?[]u8) void) void {
    const u = zjb.string(path);
    defer u.release();
    const headers = zjb.global("Headers").new(.{});
    defer headers.release();
    headers.call("set", .{ zjb.constString("X-Meiolol-Action"), zjb.constString("1") }, void);
    // fetch copies the bytes before returning, so a view of wasm memory is enough
    const view = zjb.u8ArrayView(body);
    defer view.release();
    const init = zjb.global("Object").new(.{});
    defer init.release();
    init.set("method", zjb.constString(method));
    init.set("headers", headers);
    init.set("body", view);
    request(zjb.ConstHandle.global.call("fetch", .{ u, init }, zjb.Handle), ctx, done);
}

/// As `send` (no body for null), then `done(ctx, status, bytes)` with any answer's body,
/// an error's too; status 0 and null when the fetch failed
pub fn ask(comptime method: []const u8, path: []const u8, body: ?[]const u8, ctx: i32, done: *const fn (i32, u16, ?[]u8) void) void {
    const u = zjb.string(path);
    defer u.release();
    const init = zjb.global("Object").new(.{});
    defer init.release();
    init.set("method", zjb.constString(method));
    if (body) |b| {
        const headers = zjb.global("Headers").new(.{});
        defer headers.release();
        headers.call("set", .{ zjb.constString("X-Meiolol-Action"), zjb.constString("1") }, void);
        const view = zjb.u8ArrayView(b);
        defer view.release();
        init.set("headers", headers);
        init.set("body", view);
    }
    on_answer = done;
    const p = zjb.ConstHandle.global.call("fetch", .{ u, init }, zjb.Handle);
    defer p.release();
    const ok = zjb.fnHandle("uiAnswer", &onAnswer).bind(.{ctx});
    defer ok.release();
    const bad = zjb.fnHandle("uiNoAnswer", &onNoAnswer).bind(.{ctx});
    defer bad.release();
    p.call("then", .{ ok, bad }, zjb.Handle).release();
}

var on_answer: *const fn (i32, u16, ?[]u8) void = undefined;

fn onAnswer(ctx: i32, resp: zjb.Handle) callconv(.c) void {
    const s = enter();
    defer leave(s);
    defer resp.release();
    const step = zjb.fnHandle("uiAnswerBytes", &onAnswerBytes).bind(.{ ctx, resp.get("status", i32) });
    const bad = zjb.fnHandle("uiNoAnswer", &onNoAnswer).bind(.{ctx});
    _ = resp.call("arrayBuffer", .{}, zjb.Handle).call("then", .{ step, bad }, zjb.Handle);
}

fn onNoAnswer(ctx: i32, err: zjb.Handle) callconv(.c) void {
    const s = enter();
    defer leave(s);
    err.release();
    on_answer(ctx, 0, null);
}

fn onAnswerBytes(ctx: i32, status: i32, buf: zjb.Handle) callconv(.c) void {
    const s = enter();
    defer leave(s);
    defer buf.release();
    on_answer(ctx, @intCast(std.math.clamp(status, 0, 999)), zjb.global("Uint8Array").new(.{buf}).allocBytes(gpa) catch null);
}

fn request(p: zjb.Handle, ctx: i32, done: *const fn (i32, ?[]u8) void) void {
    on_bytes = done;
    defer p.release();
    const ok = zjb.fnHandle("uiResponse", &onResponse).bind(.{ctx});
    defer ok.release();
    const bad = zjb.fnHandle("uiFailed", &onFailed).bind(.{ctx});
    defer bad.release();
    p.call("then", .{ ok, bad }, zjb.Handle).release();
}

var on_bytes: *const fn (i32, ?[]u8) void = undefined;

fn onResponse(ctx: i32, resp: zjb.Handle) callconv(.c) void {
    const s = enter();
    defer leave(s);
    defer resp.release();
    if (!resp.get("ok", bool)) return on_bytes(ctx, null);
    const step = zjb.fnHandle("uiBytes", &onBytes).bind(.{ctx});
    const bad = zjb.fnHandle("uiFailed", &onFailed).bind(.{ctx});
    _ = resp.call("arrayBuffer", .{}, zjb.Handle).call("then", .{ step, bad }, zjb.Handle);
}

fn onFailed(ctx: i32, err: zjb.Handle) callconv(.c) void {
    const s = enter();
    defer leave(s);
    err.release();
    on_bytes(ctx, null);
}

fn onBytes(ctx: i32, buf: zjb.Handle) callconv(.c) void {
    const s = enter();
    defer leave(s);
    defer buf.release();
    on_bytes(ctx, zjb.global("Uint8Array").new(.{buf}).allocBytes(gpa) catch null);
}

/// Fetches what an island's toolbar pick needs (ui.champpage.Files: `files`, with the
/// island's `src` and `root`), one file at a time, then has it show them and redraws.
/// A missing rank file is a view without games at Emerald+; a failed base file drops the
/// pick, if still wanted, back to what is shown
pub fn Loader(comptime Root: type, comptime D: type, comptime R: type) type {
    return struct {
        var st: *Root = undefined;
        var island: *ui.island.Island(Root, Dom) = undefined;
        var asked: ?@FieldType(Root, "files").Need = null;

        pub fn start(s: *Root, i: *ui.island.Island(Root, Dom)) void {
            st = s;
            island = i;
            rt.changed = check;
            check();
        }

        /// A pick already in shows at once, though a fetch for an older one is out
        pub fn check() void {
            const f = &st.files;
            if (f.need()) |n| {
                if (asked != null) return;
                const path = ui.champpage.viewPath(gpa, st.src, st.root, n.view, n.rank) catch return;
                asked = n;
                return fetch(path, 0, loaded);
            }
            if (!f.busy()) return;
            st.show(gpa);
            island.render();
        }

        fn loaded(_: i32, bytes: ?[]u8) void {
            const n = asked.?;
            asked = null;
            const f = &st.files;
            if (n.rank) {
                f.none[n.view] = true;
                if (bytes) |b| if (ui.data.decode(gpa, R, b)) |v| {
                    const p = gpa.create(R) catch return;
                    p.* = v;
                    f.rank[n.view] = p;
                    f.none[n.view] = false;
                } else |_| dom.warn("champion: bad rank data");
            } else {
                const v = if (bytes) |b| ui.data.decode(gpa, D, b) catch null else null;
                if (v) |x| {
                    const p = gpa.create(D) catch return;
                    p.* = x;
                    f.base[n.view] = p;
                } else {
                    dom.warn("champion: no data for the view");
                    if (f.want.view == n.view) {
                        f.want = f.shown;
                        island.render();
                    }
                }
            }
            check();
        }
    };
}
