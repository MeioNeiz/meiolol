//! ui-notes.wasm: the notes tool (ui.notes.Tool) on any page, loaded only for the admin
//! login (nginx, or the dev server, adds its script for a request with the marker
//! cookie). Its root goes at the end of <body>; the page's open notes come from
//! /api/notes as pins; picking listens on window in the capture phase, so the page's own
//! handlers never see the pointer until it ends; Save POSTs a ui.notesdata.New. On
//! /admin/notes.html (its server-rendered ui.noteslist) the list instead, fetched again
//! every 20 s while the tab shows and when it comes back
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const nd = ui.notesdata;
const Tool = ui.notes.Tool;
const Pin = ui.notes.Pin;
const Rect = ui.notes.Rect;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;

var tool: Tool = .{};
var server: Tool = .{};
var island: ?*ui.island.Island(Tool, dom.Dom) = null;
var root: zjb.Handle = .null;
/// Notes from /api/notes and Save; strings point into the answers' bytes, kept
var notes: std.ArrayList(nd.Note) = .empty;
var pins: std.ArrayList(Pin) = .empty;
/// Each pin's element; .null for a page-level or moved one
var pin_els: std.ArrayList(zjb.Handle) = .empty;
/// The picked element (.null: the whole page) and the ones Wider climbed from
var picked: zjb.Handle = .null;
var below: std.ArrayList(zjb.Handle) = .empty;
var hover: zjb.Handle = .null;
var picking = false;
var what_buf: [160]u8 = undefined;

const Call = enum(i32) { list, save, all, patch, tool_on, tool_off };

/// What picking blocks outside the tool: the page's own presses never fire
const blocked = [_][]const u8{ "pointerdown", "pointerup", "mousedown", "mouseup", "dblclick", "auxclick", "contextmenu", "submit" };

export fn main() void {
    dom.start();
    const doc = zjb.global("document");
    const page = doc.call("querySelector", .{zjb.constString(ui.noteslist.sel)}, zjb.Handle);
    if (page != .null) {
        page.release();
        return listMain();
    }
    const existing = doc.call("querySelector", .{zjb.constString(ui.notes.sel)}, zjb.Handle);
    if (existing != .null) return existing.release();
    if (!mount()) return dom.dom.warn("notes: no root");
    island = dom.rt.add(Tool, &tool, &server, ui.notes.sel) catch return dom.dom.warn("notes: out of memory");
    dom.rt.changed = changed;
    root = doc.call("querySelector", .{zjb.constString(ui.notes.sel)}, zjb.Handle).kept();
    const w = zjb.global("window");
    w.call("addEventListener", .{ zjb.constString("keydown"), zjb.fnHandle("notesKey", &onKey), @as(i32, 1) }, void);
    w.call("addEventListener", .{ zjb.constString("resize"), zjb.fnHandle("notesResize", &onPlace), @as(i32, 0) }, void);
    // The page's islands redraw after a press (a tab, a filter): pins follow a beat later
    w.call("addEventListener", .{ zjb.constString("click"), zjb.fnHandle("notesClick", &onClick), @as(i32, 0) }, void);
    const ro = zjb.global("ResizeObserver").new(.{zjb.fnHandle("notesGrew", &onGrew)});
    defer ro.release();
    const body = doc.get("body", zjb.Handle);
    defer body.release();
    ro.call("observe", .{body}, void);
    load();
}

/// The closed tool's HTML at the end of <body>, for the runtime to adopt
fn mount() bool {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    const a = arena.allocator();
    var t: ui.Tree = .{};
    var h: ui.H = .init(a, &t);
    const n = server.view(&h);
    if (h.oom) return false;
    var out: std.Io.Writer.Allocating = .init(a);
    ui.html.write(&t, n, &out.writer) catch return false;
    const s = zjb.string(out.written());
    defer s.release();
    const body = zjb.global("document").get("body", zjb.Handle);
    defer body.release();
    if (body == .null) return false;
    body.call("insertAdjacentHTML", .{ zjb.constString("beforeend"), s }, void);
    return true;
}

fn render() void {
    if (island) |i| i.render();
}

fn changed() void {
    const w = tool.want;
    tool.want = .none;
    switch (w) {
        // Back, Forward or another island's hash: the page may have moved
        .none => return place(),
        .pick => startPick(),
        .stop => {
            stopPick();
            dropPick();
        },
        .wider => wider(),
        .narrower => narrower(),
        .save => save(),
        .outline => tool.hl = if (tool.open) |i| rectOf(pin_els.items[i]) else null,
    }
    render();
}

// Picking

fn startPick() void {
    if (picking) return;
    picking = true;
    const w = zjb.global("window");
    w.call("addEventListener", .{ zjb.constString("pointermove"), zjb.fnHandle("notesMove", &onMove), @as(i32, 1) }, void);
    w.call("addEventListener", .{ zjb.constString("click"), zjb.fnHandle("notesPick", &onPick), @as(i32, 1) }, void);
    for (blocked) |kind| {
        const k = zjb.string(kind);
        defer k.release();
        w.call("addEventListener", .{ k, zjb.fnHandle("notesBlock", &onBlock), @as(i32, 1) }, void);
    }
}

/// Every listener startPick added, as it was added
fn stopPick() void {
    if (!picking) return;
    picking = false;
    const w = zjb.global("window");
    w.call("removeEventListener", .{ zjb.constString("pointermove"), zjb.fnHandle("notesMove", &onMove), @as(i32, 1) }, void);
    w.call("removeEventListener", .{ zjb.constString("click"), zjb.fnHandle("notesPick", &onPick), @as(i32, 1) }, void);
    for (blocked) |kind| {
        const k = zjb.string(kind);
        defer k.release();
        w.call("removeEventListener", .{ k, zjb.fnHandle("notesBlock", &onBlock), @as(i32, 1) }, void);
    }
    swap(&hover, .null);
}

fn dropPick() void {
    swap(&picked, .null);
    for (below.items) |b| b.release();
    below.clearRetainingCapacity();
}

/// Sets `slot` to `h`, kept, releasing what it held
fn swap(slot: *zjb.Handle, h: zjb.Handle) void {
    if (slot.* != .null) slot.release();
    slot.* = h.kept();
}

fn inTool(el: zjb.Handle) bool {
    return el == .null or root == .null or root.call("contains", .{el}, bool);
}

/// Stops the event reaching the page
fn swallow(e: zjb.Handle) void {
    e.call("preventDefault", .{}, void);
    e.call("stopImmediatePropagation", .{}, void);
}

fn onMove(e: zjb.Handle) callconv(.c) void {
    defer e.release();
    const t = e.get("target", zjb.Handle);
    if (inTool(t)) {
        if (t != .null) t.release();
        swap(&hover, .null);
        if (tool.hl == null) return;
        tool.hl = null;
        return render();
    }
    if (hover != .null and hover.eql(t)) return t.release();
    swap(&hover, t);
    tool.hl = rectOf(t);
    render();
}

fn onBlock(e: zjb.Handle) callconv(.c) void {
    defer e.release();
    const t = e.get("target", zjb.Handle);
    defer if (t != .null) t.release();
    if (!inTool(t)) swallow(e);
}

fn onPick(e: zjb.Handle) callconv(.c) void {
    defer e.release();
    const t = e.get("target", zjb.Handle);
    if (inTool(t)) {
        if (t != .null) t.release();
        return;
    }
    swallow(e);
    stopPick();
    dropPick();
    picked = t.kept();
    tool.mode = .form;
    tool.scope = .page;
    describe();
    render();
    focusText();
}

/// Escape closes whatever is open; n, with nothing open, starts a note as the Note button
fn onKey(e: zjb.Handle) callconv(.c) void {
    defer e.release();
    const k = e.get("key", zjb.Handle);
    defer k.release();
    var buf: [16]u8 = undefined;
    const key = k.readString(&buf) catch return;
    if (tool.mode == .idle and tool.open == null) {
        if (!std.mem.eql(u8, key, "n") or !plainKey(e)) return;
        swallow(e);
        tool.open = null;
        tool.mode = .picking;
        tool.want = .pick;
        return changed();
    }
    if (!std.mem.eql(u8, key, "Escape")) return;
    swallow(e);
    tool.reset();
    changed();
}

/// No modifier, not held down, and not typed into a field (the site's search, a form)
fn plainKey(e: zjb.Handle) bool {
    inline for (.{ "ctrlKey", "metaKey", "altKey", "repeat" }) |m| if (e.get(m, bool)) return false;
    const t = e.get("target", zjb.Handle);
    defer t.release();
    if (t == .null) return true;
    if (t.get("isContentEditable", bool)) return false;
    const name = t.get("localName", zjb.Handle);
    defer name.release();
    var buf: [8]u8 = undefined;
    const tag = name.readString(&buf) catch return true;
    inline for (.{ "input", "textarea", "select" }) |f| if (std.mem.eql(u8, tag, f)) return false;
    return true;
}

fn wider() void {
    if (picked == .null) return;
    const p = picked.get("parentElement", zjb.Handle);
    if (p == .null) return;
    const name = p.get("localName", zjb.Handle);
    defer name.release();
    var buf: [8]u8 = undefined;
    const tag = name.readString(&buf) catch "";
    if (std.mem.eql(u8, tag, "body") or std.mem.eql(u8, tag, "html")) return p.release();
    below.append(gpa, picked) catch return p.release();
    picked = p.kept();
    describe();
}

fn narrower() void {
    const b = below.pop() orelse return;
    swap(&picked, b);
    describe();
}

fn focusText() void {
    if (root == .null) return;
    const t = root.call("querySelector", .{zjb.constString("textarea")}, zjb.Handle);
    if (t == .null) return;
    defer t.release();
    t.call("focus", .{}, void);
}

/// The picked element's words and outline, and whether "everywhere" can apply
fn describe() void {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    const t = targetOf(arena.allocator(), picked) catch nd.Target{ .kind = .page };
    tool.component = t.kind == .component;
    if (!tool.component) tool.scope = .page;
    tool.hl = rectOf(picked);
    const last = if (std.mem.findScalarLast(u8, t.steps, '>')) |i| t.steps[i + 1 ..] else t.steps;
    const tag = last[0 .. std.mem.findScalar(u8, last, ':') orelse last.len];
    tool.what = std.fmt.bufPrint(&what_buf, "{s}{s}{s}{s}{s}", .{
        if (t.kind == .page) "page" else t.name,
        if (tag.len > 0) " > " else "",
        tag,
        if (t.snippet.len > 0) ": " else "",
        t.snippet,
    }) catch "";
}

// Where an element is, and finding it again

/// The element's box in document coordinates; null for .null
fn rectOf(el: zjb.Handle) ?Rect {
    if (el == .null) return null;
    const r = el.call("getBoundingClientRect", .{}, zjb.Handle);
    defer r.release();
    const w = zjb.global("window");
    const sx: f32 = @floatCast(w.get("scrollX", f64));
    const sy: f32 = @floatCast(w.get("scrollY", f64));
    return .{
        .x = @as(f32, @floatCast(r.get("left", f64))) + sx,
        .y = @as(f32, @floatCast(r.get("top", f64))) + sy,
        .w = @floatCast(r.get("width", f64)),
        .h = @floatCast(r.get("height", f64)),
    };
}

const Anchor = struct { kind: nd.Target.Kind, name: []const u8 };

/// `el`'s first c-* class, else its data-island; null when neither is a valid name
fn anchorOf(a: std.mem.Allocator, el: zjb.Handle) ?Anchor {
    const class = dom.attrOf(el, "class");
    defer if (class.len > 0) gpa.free(class);
    var it = std.mem.tokenizeAny(u8, class, " \t\n");
    while (it.next()) |c| if (std.mem.startsWith(u8, c, "c-") and validName(c))
        return .{ .kind = .component, .name = a.dupe(u8, c) catch return null };
    const island_name = dom.attrOf(el, "data-island");
    defer if (island_name.len > 0) gpa.free(island_name);
    if (island_name.len > 0 and validName(island_name)) return .{ .kind = .island, .name = a.dupe(u8, island_name) catch return null };
    return null;
}

fn validName(s: []const u8) bool {
    if (s.len == 0 or s.len > nd.max_name) return false;
    for (s) |ch| if (!std.ascii.isAlphanumeric(ch) and ch != '-' and ch != '_') return false;
    return true;
}

/// The selector matching every element with this anchor
fn selectorOf(a: std.mem.Allocator, kind: nd.Target.Kind, name: []const u8) ![]const u8 {
    const parts: []const []const u8 = switch (kind) {
        .page => &.{"body"},
        .component => &.{ ".", name },
        .island => &.{ "[data-island=\"", name, "\"]" },
    };
    return std.mem.concat(a, u8, parts);
}

/// `el`'s lower case tag, in `buf`; "" when not one a step can hold
fn tagOf(buf: []u8, el: zjb.Handle) []const u8 {
    const n = el.get("localName", zjb.Handle);
    defer n.release();
    const s = n.readString(buf) catch return "";
    for (s) |*ch| ch.* = std.ascii.toLower(ch.*);
    if (s.len == 0 or !std.ascii.isLower(s[0])) return "";
    for (s) |ch| if (!std.ascii.isLower(ch) and !std.ascii.isDigit(ch) and ch != '-') return "";
    return s;
}

const Step = struct { tag: [16]u8, len: u8, i: u16 };

/// How to find `el` again: its anchor, the anchor's index on the page, the steps down to
/// `el` (at most max_steps, from the anchor) and its text. The whole page for .null
fn targetOf(a: std.mem.Allocator, el: zjb.Handle) !nd.Target {
    if (el == .null) return .{ .kind = .page };
    var steps: std.ArrayList(Step) = .empty;
    var anchor: ?Anchor = null;
    // `cur` is ours to release once it isn't `el`
    var cur = el;
    defer if (cur != el and cur != .null) cur.release();
    while (true) {
        if (anchorOf(a, cur)) |an| {
            anchor = an;
            break;
        }
        var tbuf: [16]u8 = undefined;
        const tag = tagOf(&tbuf, cur);
        if (std.mem.eql(u8, tag, "body") or std.mem.eql(u8, tag, "html")) break;
        const parent = cur.get("parentElement", zjb.Handle);
        if (tag.len == 0 or parent == .null) {
            if (parent != .null) parent.release();
            return .{ .kind = .page };
        }
        var s: Step = .{ .tag = undefined, .len = @intCast(tag.len), .i = 0 };
        @memcpy(s.tag[0..tag.len], tag);
        s.i = sameTagBefore(cur, tag);
        try steps.append(a, s);
        if (cur != el) cur.release();
        cur = parent;
    }
    const an = anchor orelse Anchor{ .kind = .page, .name = "" };
    var nth: u16 = 0;
    if (an.kind != .page) {
        const all = try matches(a, an.kind, an.name);
        defer all.release();
        const len = all.get("length", i32);
        var i: i32 = 0;
        while (i < len) : (i += 1) {
            const x = all.call("item", .{i}, zjb.Handle);
            defer x.release();
            if (x.eql(cur)) break;
        }
        nth = std.math.cast(u16, i) orelse 0;
    }
    // From the anchor down, the deepest ones dropped past max_steps
    std.mem.reverse(Step, steps.items);
    const kept = steps.items[0..@min(steps.items.len, nd.max_steps)];
    var out: std.Io.Writer.Allocating = .init(a);
    for (kept, 0..) |s, k| try out.writer.print("{s}{s}:{d}", .{ if (k > 0) ">" else "", s.tag[0..s.len], @min(s.i, 999) });
    return .{ .kind = an.kind, .name = an.name, .nth = nth, .steps = out.written(), .snippet = try snippetOf(a, el) };
}

fn matches(a: std.mem.Allocator, kind: nd.Target.Kind, name: []const u8) !zjb.Handle {
    const s = zjb.string(try selectorOf(a, kind, name));
    defer s.release();
    return zjb.global("document").call("querySelectorAll", .{s}, zjb.Handle);
}

/// Earlier element siblings with `el`'s tag
fn sameTagBefore(el: zjb.Handle, tag: []const u8) u16 {
    var n: u16 = 0;
    var s = el.get("previousElementSibling", zjb.Handle);
    while (s != .null) {
        var buf: [16]u8 = undefined;
        if (std.mem.eql(u8, tagOf(&buf, s), tag)) n +|= 1;
        const prev = s.get("previousElementSibling", zjb.Handle);
        s.release();
        s = prev;
    }
    return n;
}

/// The start of `el`'s text, whitespace collapsed, cut on a character at max_snippet
fn snippetOf(a: std.mem.Allocator, el: zjb.Handle) ![]const u8 {
    const tc = el.get("textContent", zjb.Handle);
    defer tc.release();
    if (tc == .null) return "";
    const head = tc.call("slice", .{ @as(i32, 0), @as(i32, 400) }, zjb.Handle);
    defer head.release();
    return nd.snippet(try a.alloc(u8, nd.max_snippet), try head.allocString(a));
}

/// The element `t` names now: its anchor's nth match (the first when there are fewer),
/// down its steps; another match whose element has the same text wins over a changed
/// one. Null when no anchor is on the page or kind page without steps
fn resolve(a: std.mem.Allocator, t: nd.Target) ?zjb.Handle {
    if (t.kind == .page) {
        if (t.steps.len == 0) return null;
        const body = zjb.global("document").get("body", zjb.Handle);
        defer body.release();
        return walk(body, t.steps);
    }
    const all = matches(a, t.kind, t.name) catch return null;
    defer all.release();
    const len = all.get("length", i32);
    if (len == 0) return null;
    const first = all.call("item", .{if (t.nth < len) @as(i32, t.nth) else 0}, zjb.Handle);
    defer first.release();
    const el = walk(first, t.steps) orelse return null;
    if (t.snippet.len == 0 or sameText(a, el, t.snippet)) return el;
    var i: i32 = 0;
    while (i < len) : (i += 1) {
        const x = all.call("item", .{i}, zjb.Handle);
        defer x.release();
        const y = walk(x, t.steps) orelse continue;
        if (sameText(a, y, t.snippet)) {
            el.release();
            return y;
        }
        y.release();
    }
    return el;
}

fn sameText(a: std.mem.Allocator, el: zjb.Handle, snippet: []const u8) bool {
    return std.mem.eql(u8, snippetOf(a, el) catch return false, snippet);
}

/// `from` down "tag:i>..." (a new handle); as far as it gets when a step is missing
fn walk(from: zjb.Handle, steps: []const u8) ?zjb.Handle {
    // A handle of our own on `from`
    var cur = from.call("closest", .{zjb.constString("*")}, zjb.Handle);
    if (cur == .null) return null;
    var it = std.mem.tokenizeScalar(u8, steps, '>');
    while (it.next()) |step| {
        const colon = std.mem.findScalar(u8, step, ':') orelse break;
        const want = std.fmt.parseInt(u16, step[colon + 1 ..], 10) catch break;
        const next = child(cur, step[0..colon], want) orelse break;
        cur.release();
        cur = next;
    }
    return cur;
}

/// `el`'s `want`-th element child with `tag`
fn child(el: zjb.Handle, tag: []const u8, want: u16) ?zjb.Handle {
    var seen: u16 = 0;
    var c = el.get("firstElementChild", zjb.Handle);
    while (c != .null) {
        var buf: [16]u8 = undefined;
        if (std.mem.eql(u8, tagOf(&buf, c), tag)) {
            if (seen == want) return c;
            seen += 1;
        }
        const next = c.get("nextElementSibling", zjb.Handle);
        c.release();
        c = next;
    }
    return null;
}

// Notes and pins

fn location(comptime field: []const u8) []const u8 {
    const v = zjb.global("location").get(field, zjb.Handle);
    defer v.release();
    return v.allocString(gpa) catch "";
}

fn load() void {
    const path = location("pathname");
    defer gpa.free(path);
    const s = zjb.string(path);
    defer s.release();
    const enc = zjb.global("window").call("encodeURIComponent", .{s}, zjb.Handle);
    defer enc.release();
    const q = enc.allocString(gpa) catch return;
    defer gpa.free(q);
    const url = std.mem.concat(gpa, u8, &.{ "/api/notes?path=", q }) catch return;
    defer gpa.free(url);
    dom.fetch(url, @backingInt(Call.list), done);
}

fn done(ctx: i32, bytes: ?[]u8) void {
    switch (std.enums.fromInt(Call, ctx) orelse return) {
        .all => {
            fetching = false;
            list.loading = false;
            // An answer from before a change saved since would undo it on screen
            if (patching > 0) return;
            const b = bytes orelse return listFailed();
            var next: std.heap.ArenaAllocator = .init(gpa);
            const l = ui.data.decode(next.allocator(), nd.List, b) catch {
                next.deinit();
                return listFailed();
            };
            notes.clearRetainingCapacity();
            notes.appendSlice(gpa, l.notes) catch {
                next.deinit();
                return listFailed();
            };
            if (list_mem) |*m| m.deinit();
            list_mem = next;
            list.notes = notes.items;
            list.failed = false;
            listRender();
        },
        .patch => {
            patching -|= 1;
            const b = bytes orelse return listFailed();
            const n = ui.data.decode(gpa, nd.Note, b) catch return listFailed();
            for (notes.items) |*x| {
                if (x.id == n.id) x.* = n;
            }
            list.replying = null;
            listRender();
        },
        .tool_on, .tool_off => {
            if (bytes == null) return listFailed();
            list.tool = ctx == @backingInt(Call.tool_on);
            listRender();
        },
        .list => {
            const b = bytes orelse return dom.dom.warn("notes: no list");
            const l = ui.data.decode(gpa, nd.List, b) catch return dom.dom.warn("notes: bad list");
            notes.appendSlice(gpa, l.notes) catch return;
            place();
        },
        .save => {
            const n = if (bytes) |b| ui.data.decode(gpa, nd.Note, b) catch null else null;
            const note = n orelse {
                tool.mode = .form;
                tool.failed = true;
                return render();
            };
            notes.append(gpa, note) catch {};
            clearText();
            tool.reset();
            changed();
            place();
        },
    }
}

fn clearText() void {
    if (root == .null) return;
    const t = root.call("querySelector", .{zjb.constString("textarea")}, zjb.Handle);
    if (t == .null) return;
    defer t.release();
    t.set("value", zjb.constString(""));
}

fn save() void {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    const a = arena.allocator();
    const text = textValue(a);
    if (std.mem.trim(u8, text, " \t\r\n").len == 0) {
        tool.mode = .form;
        tool.empty = true;
        return focusText();
    }
    const path = location("pathname");
    defer gpa.free(path);
    const search = location("search");
    defer gpa.free(search);
    const hash = location("hash");
    defer gpa.free(hash);
    const state = std.mem.concat(a, u8, &.{ search, hash }) catch "";
    const w = zjb.global("window");
    const dark = w.call("matchMedia", .{zjb.constString("(prefers-color-scheme: dark)")}, zjb.Handle);
    defer dark.release();
    const new: nd.New = .{
        .path = path,
        .hash = state[0..@min(state.len, nd.max_hash)],
        .scope = tool.scope,
        .target = targetOf(a, picked) catch .{ .kind = .page },
        .vw = std.math.lossyCast(u16, w.get("innerWidth", f64)),
        .vh = std.math.lossyCast(u16, w.get("innerHeight", f64)),
        .theme = if (dark.get("matches", bool)) .dark else .light,
        .text = text,
    };
    if (nd.check(new)) |why| {
        dom.dom.warn(why);
        tool.mode = .form;
        tool.failed = true;
        return;
    }
    var body: std.ArrayList(u8) = .empty;
    ui.data.encode(a, nd.New, new, &body) catch return;
    dom.send("POST", "/api/notes", body.items, @backingInt(Call.save), done);
}

fn textValue(a: std.mem.Allocator) []const u8 {
    if (root == .null) return "";
    const t = root.call("querySelector", .{zjb.constString("textarea")}, zjb.Handle);
    if (t == .null) return "";
    defer t.release();
    const v = t.get("value", zjb.Handle);
    defer v.release();
    // maxlength keeps it within max_text: no cut
    return v.allocString(a) catch "";
}

/// Is a `.c-name` on the page: an "everywhere" note shows where its component does
fn onPage(a: std.mem.Allocator, component: []const u8) bool {
    const all = matches(a, .component, component) catch return false;
    defer all.release();
    return all.get("length", i32) > 0;
}

/// A pin per open note for this page at its element's top right; page-level and lost
/// ones in a row at the page's top
fn place() void {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    const a = arena.allocator();
    const path = location("pathname");
    defer gpa.free(path);
    for (pin_els.items) |el| if (el != .null) el.release();
    pin_els.clearRetainingCapacity();
    pins.clearRetainingCapacity();
    const doc_el = zjb.global("document").get("documentElement", zjb.Handle);
    defer doc_el.release();
    const right: f32 = @floatCast(doc_el.get("clientWidth", f64) - 12);
    var top_row: f32 = 0;
    for (notes.items) |n| {
        if (n.status != .open) continue;
        const here = switch (n.scope) {
            .page => std.mem.eql(u8, n.path, nd.stripIndex(path)),
            .everywhere => onPage(a, n.target.component()),
        };
        if (!here) continue;
        const el = resolve(a, n.target);
        var p: Pin = .{ .note = n, .x = 0, .y = 0 };
        if (rectOf(el orelse .null)) |r| {
            p.x = @max(12, @min(r.x + r.w, right));
            p.y = @max(12, r.y);
        } else {
            p.moved = n.target.kind != .page or n.target.steps.len > 0;
            p.x = @min(24 + top_row * 28, right);
            p.y = 72;
            top_row += 1;
        }
        // Pins on one spot stack downwards: sideways they would leave the page
        for (pins.items) |q| {
            if (q.x == p.x and q.y == p.y) p.y += 26;
        }
        pins.append(gpa, p) catch break;
        pin_els.append(gpa, (el orelse zjb.Handle.null).kept()) catch break;
    }
    tool.pins = pins.items;
    if (tool.open) |i| {
        if (i >= pins.items.len) tool.open = null;
    }
    if (tool.open) |i| {
        tool.hl = rectOf(pin_els.items[i]);
    } else switch (tool.mode) {
        .form, .saving => tool.hl = rectOf(picked),
        .idle => tool.hl = null,
        .picking => {},
    }
    render();
}

fn onPlace() callconv(.c) void {
    place();
}

fn onClick(e: zjb.Handle) callconv(.c) void {
    e.release();
    zjb.global("window").call("setTimeout", .{ zjb.fnHandle("notesLater", &onPlace), @as(i32, 80) }, void);
}

fn onGrew(entries: zjb.Handle, observer: zjb.Handle) callconv(.c) void {
    entries.release();
    observer.release();
    place();
}

// The list (/admin/notes.html)

var list: ui.noteslist.List = .{};
var list_server: ui.noteslist.List = .{};
var list_island: ?*ui.island.Island(ui.noteslist.List, dom.Dom) = null;
/// The latest list answer's notes live here, freed when the next one lands
var list_mem: ?std.heap.ArenaAllocator = null;
var fetching = false;
/// PATCHes sent and not answered
var patching: u32 = 0;

fn listMain() void {
    list_island = dom.rt.add(ui.noteslist.List, &list, &list_server, ui.noteslist.sel) catch return dom.dom.warn("notes: out of memory");
    dom.rt.changed = listChanged;
    fetchAll();
    zjb.global("window").call("setInterval", .{ zjb.fnHandle("notesPoll", &onPoll), @as(i32, 20_000) }, void);
    zjb.global("document").call("addEventListener", .{ zjb.constString("visibilitychange"), zjb.fnHandle("notesShown", &onShown), @as(i32, 0) }, void);
}

fn fetchAll() void {
    if (fetching) return;
    fetching = true;
    dom.fetch("/api/notes?all=1&status=any", @backingInt(Call.all), done);
}

/// Only while the tab shows: a hidden one catches up when it comes back
fn onPoll() callconv(.c) void {
    if (!zjb.global("document").get("hidden", bool)) fetchAll();
}

fn onShown(e: zjb.Handle) callconv(.c) void {
    e.release();
    onPoll();
}

fn listRender() void {
    if (list_island) |i| i.render();
}

fn listFailed() void {
    list.loading = false;
    list.failed = true;
    listRender();
}

fn listChanged() void {
    const w = list.want;
    list.want = .none;
    switch (w) {
        .none => {},
        .status => |s| patch(s.id, .{ .status = s.status }),
        .reply => |id| {
            var arena: std.heap.ArenaAllocator = .init(gpa);
            defer arena.deinit();
            patch(id, .{ .reply = replyValue(arena.allocator()) });
        },
        .reopen => |id| {
            var arena: std.heap.ArenaAllocator = .init(gpa);
            defer arena.deinit();
            const words = replyValue(arena.allocator());
            patch(id, .{ .status = .open, .reply = if (words.len > 0) words else null });
        },
        .tool => |on| if (on)
            dom.send("POST", "/api/notes/tool?on=1", "", @backingInt(Call.tool_on), done)
        else
            dom.send("POST", "/api/notes/tool?on=0", "", @backingInt(Call.tool_off), done),
    }
}

fn patch(id: u32, c: nd.Change) void {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    const a = arena.allocator();
    var body: std.ArrayList(u8) = .empty;
    ui.data.encode(a, nd.Change, c, &body) catch return;
    var buf: [32]u8 = undefined;
    const path = std.fmt.bufPrint(&buf, "/api/notes?id={d}", .{id}) catch return;
    patching += 1;
    dom.send("PATCH", path, body.items, @backingInt(Call.patch), done);
}

/// The open reply's input, cut on a whole character at max_reply
fn replyValue(a: std.mem.Allocator) []const u8 {
    const doc = zjb.global("document");
    const el = doc.call("querySelector", .{zjb.constString("[data-ref=reply]")}, zjb.Handle);
    if (el == .null) return "";
    defer el.release();
    const v = el.get("value", zjb.Handle);
    defer v.release();
    const s = v.allocString(a) catch return "";
    return nd.cut(s, nd.max_reply);
}
