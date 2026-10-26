//! ui.wasm's only door to the page: the island runtime's Dom (island.zig) as zjb calls.
//! No JS of ours beyond zjb's generated loader (Jacob 22 and 25 Oct). Each DOM node we
//! made or adopted is a zjb handle in `nodes`, by DOM id, and carries its id as `__n` so
//! an event's target finds its node; a removed node's handle is released
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
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
        d.nodes.items[id] = h;
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
        d.roots.append(gpa, root) catch @panic("out of memory");
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
            d.no_scroll = zjb.global("Object").new(.{});
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

    pub fn popover(d: *Dom, id: u32, show: bool) void {
        const n = d.node(id);
        const open = n.call("matches", .{zjb.constString(":popover-open")}, bool);
        if (show and !open) n.call("showPopover", .{}, void);
        if (!show and open) n.call("hidePopover", .{}, void);
    }

    pub fn hash(_: *Dom, buf: []u8) []const u8 {
        const h = zjb.global("location").get("hash", zjb.Handle);
        defer h.release();
        return h.readString(buf) catch "";
    }

    /// `#` alone: the page's own URL without a fragment
    pub fn setHash(_: *Dom, s: []const u8, push: bool) void {
        var buf: [1024]u8 = undefined;
        const target = if (s.len > 1) s else blk: {
            const loc = zjb.global("location");
            const path = loc.get("pathname", zjb.Handle);
            defer path.release();
            const p = path.readString(&buf) catch return;
            const search = loc.get("search", zjb.Handle);
            defer search.release();
            const q = search.readString(buf[p.len..]) catch return;
            break :blk buf[0 .. p.len + q.len];
        };
        const t = zjb.string(target);
        defer t.release();
        const args = .{ zjb.ConstHandle.null, zjb.ConstHandle.empty_string, t };
        if (push) zjb.global("history").call("pushState", args, void) else zjb.global("history").call("replaceState", args, void);
    }

    pub fn warn(_: *Dom, msg: []const u8) void {
        const m = zjb.string(msg);
        defer m.release();
        zjb.global("console").call("error", .{m}, void);
    }
};

pub var dom: Dom = .{};
pub var rt: ui.island.Runtime(Dom) = .{ .gpa = gpa, .dom = &dom };

/// The id of the nearest node we know at or above `h` (0: none); releases `h`
fn nearest(h: zjb.Handle) u32 {
    var k = h;
    while (k != .null) {
        const id = k.get("__n", i32);
        if (id > 0) {
            k.release();
            return @intCast(id);
        }
        const up = k.get("parentNode", zjb.Handle);
        k.release();
        k = up;
    }
    return 0;
}

fn onEvent(slot: i32, bit: i32, e: zjb.Handle) callconv(.c) void {
    defer e.release();
    const kind: tree.Ev = @fromBackingInt(@intCast(bit));
    var in: ui.island.Input = .{ .kind = kind, .target = nearest(e.get("target", zjb.Handle)) };
    if (in.target == 0) return;
    var buf: [256]u8 = undefined;
    switch (kind) {
        .input, .change => {
            const t = e.get("target", zjb.Handle);
            defer t.release();
            const v = t.get("value", zjb.Handle);
            defer v.release();
            in.text = v.readString(&buf) catch buf[0..0];
        },
        .keydown => {
            const k = e.get("key", zjb.Handle);
            defer k.release();
            in.text = k.readString(&buf) catch buf[0..0];
        },
        .pointerdown, .pointermove, .pointerup, .pointerleave, .pointercancel => {
            in.x = @floatCast(e.get("clientX", f64));
            in.y = @floatCast(e.get("clientY", f64));
            in.pointer = e.get("pointerId", i32);
            if (kind == .pointerleave) in.related = nearest(e.get("relatedTarget", zjb.Handle));
        },
        .focusout => in.related = nearest(e.get("relatedTarget", zjb.Handle)),
        else => {},
    }
    if (rt.event(@intCast(slot), in)) e.call("preventDefault", .{}, void);
}

fn onPopstate(e: zjb.Handle) callconv(.c) void {
    e.release();
    rt.popstate();
}

/// Back and Forward reach every island
pub fn start() void {
    zjb.global("window").call("addEventListener", .{ zjb.constString("popstate"), zjb.fnHandle("uiPopstate", &onPopstate) }, void);
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

/// GET `path` (relative to the page), then `done(ctx, bytes)`; bytes are gpa's, the
/// callee's to keep. A failed fetch calls `done` with null
pub fn fetch(path: []const u8, ctx: i32, done: *const fn (i32, ?[]u8) void) void {
    on_bytes = done;
    const u = zjb.string(path);
    defer u.release();
    const p = zjb.ConstHandle.global.call("fetch", .{u}, zjb.Handle);
    defer p.release();
    const ok = zjb.fnHandle("uiResponse", &onResponse).bind(.{ctx});
    defer ok.release();
    const bad = zjb.fnHandle("uiFailed", &onFailed).bind(.{ctx});
    defer bad.release();
    p.call("then", .{ ok, bad }, zjb.Handle).release();
}

var on_bytes: *const fn (i32, ?[]u8) void = undefined;

fn onResponse(ctx: i32, resp: zjb.Handle) callconv(.c) void {
    defer resp.release();
    if (!resp.get("ok", bool)) return on_bytes(ctx, null);
    const p = resp.call("arrayBuffer", .{}, zjb.Handle);
    defer p.release();
    const step = zjb.fnHandle("uiBytes", &onBytes).bind(.{ctx});
    defer step.release();
    p.call("then", .{step}, zjb.Handle).release();
}

fn onFailed(ctx: i32, err: zjb.Handle) callconv(.c) void {
    err.release();
    on_bytes(ctx, null);
}

fn onBytes(ctx: i32, buf: zjb.Handle) callconv(.c) void {
    defer buf.release();
    const view = zjb.global("Uint8Array").new(.{buf});
    defer view.release();
    on_bytes(ctx, view.allocBytes(gpa) catch null);
}
