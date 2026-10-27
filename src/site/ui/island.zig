//! Islands: interactive components on a server-rendered page. Each is a struct with
//! `Msg`, `update(msg, ev)` and `view(h)`; state lives in the struct, every event
//! rebuilds its tree and the keyed diff patches the DOM. Generic over `Dom`: zjb calls in
//! ui.wasm (src/site/ui/wasm/dom.zig), the fake DOM in tests (fakedom.zig).
//!
//! A page may hold several islands; they share one id space and one URL fragment, each
//! writing its own fields. Another ui.wasm on the page (its own runtime) shares the
//! fragment too: keys none of ours owns are kept as they are. A root opts into the URL with `pub const Url = struct {...}`
//! (url.zig: defaults written as nothing), `toUrl(*const Root) Url` and `fromUrl(*Root,
//! Url)`. A handler sets `ev.push` for a history entry (a sort), else the entry is
//! replaced (typing a search).
//!
//! `Dom` provides the diff's ops (el, text, attr, del, data, ins, rm, forget) and:
//! adopt(sel, first) -> count, listen(island, sel, mask), rect(id) -> [3]f32 (left, top,
//! width), capture(id, pointer), active() -> id, focus(id), scroll(id), jump(element
//! id), popover(id, show), hash(buf) -> []const u8, setHash(s, push), warn(msg).
const std = @import("std");
const tree = @import("tree.zig");
const diff = @import("diff.zig");
const url = @import("url.zig");

/// What ui.wasm hands an island for one DOM event
pub const Input = struct {
    kind: tree.Ev,
    /// DOM id of the node the event hit (the nearest one we made or adopted)
    target: u32,
    x: f32 = 0,
    y: f32 = 0,
    pointer: i32 = 0,
    /// pointerleave and focusout: the node the pointer or focus went to (0: outside)
    related: u32 = 0,
    /// An input's value, or keydown's key
    text: []const u8 = "",
};

pub fn Runtime(comptime Dom: type) type {
    return struct {
        gpa: std.mem.Allocator,
        dom: *Dom,
        ids: diff.Ids = .{},
        islands: std.ArrayList(Slot) = .empty,
        /// In a handler or a patch: removing a focused node fires focusout synchronously
        /// in some engines, and that event must not start a second patch
        busy: bool = false,
        /// After every event and Back: the page's code may need more data for the new state
        changed: ?*const fn () void = null,

        const R = @This();

        const Slot = struct {
            ctx: *anyopaque,
            event: *const fn (*anyopaque, Input) bool,
            render: *const fn (*anyopaque) void,
            writeUrl: *const fn (*anyopaque, *std.Io.Writer) std.Io.Writer.Error!void,
            readUrl: *const fn (*anyopaque, []const u8) void,
            owns: *const fn ([]const u8) bool,
        };

        pub fn init(gpa: std.mem.Allocator, dom: *Dom) R {
            return .{ .gpa = gpa, .dom = dom };
        }

        /// Adopt the server's HTML under `sel` as `root`'s island. `server` is the state
        /// the server rendered (its defaults); the URL's state is patched in after
        pub fn add(r: *R, comptime Root: type, root: *Root, server: *Root, sel: []const u8) !*Island(Root, Dom) {
            const i = try r.gpa.create(Island(Root, Dom));
            i.* = .{ .rt = r, .root = root, .sel = sel, .slot = @intCast(r.islands.items.len), .arenas = .{ .init(r.gpa), .init(r.gpa) } };
            try r.islands.append(r.gpa, .{
                .ctx = i,
                .event = Island(Root, Dom).eventErased,
                .render = Island(Root, Dom).renderErased,
                .writeUrl = Island(Root, Dom).writeUrlErased,
                .readUrl = Island(Root, Dom).readUrlErased,
                .owns = Island(Root, Dom).owns,
            });
            var buf: [1024]u8 = undefined;
            i.readUrl(r.dom.hash(&buf));
            i.hydrate(server);
            return i;
        }

        pub fn event(r: *R, island: usize, in: Input) bool {
            if (island >= r.islands.items.len or r.busy) return false;
            r.busy = true;
            defer r.busy = false;
            const s = r.islands.items[island];
            defer if (r.changed) |f| f();
            return s.event(s.ctx, in);
        }

        /// Back or Forward: every island reads the fragment again
        pub fn popstate(r: *R) void {
            r.busy = true;
            defer r.busy = false;
            var buf: [1024]u8 = undefined;
            const h = r.dom.hash(&buf);
            for (r.islands.items) |s| {
                s.readUrl(s.ctx, h);
                s.render(s.ctx);
            }
            if (r.changed) |f| f();
        }

        /// Keys no island of ours owns as they are, then each island's
        pub fn syncHash(r: *R, push: bool) !void {
            var buf: [1024]u8 = undefined;
            const live = r.dom.hash(&buf);
            var w: std.Io.Writer.Allocating = .init(r.gpa);
            defer w.deinit();
            try w.writer.writeByte('#');
            var it = std.mem.tokenizeScalar(u8, if (live.len > 0 and live[0] == '#') live[1..] else live, '&');
            while (it.next()) |kv| {
                const k = kv[0 .. std.mem.findScalar(u8, kv, '=') orelse kv.len];
                for (r.islands.items) |s| {
                    if (s.owns(k)) break;
                } else {
                    if (w.written().len > 1) try w.writer.writeByte('&');
                    try w.writer.writeAll(kv);
                }
            }
            for (r.islands.items) |s| {
                const before = w.written().len;
                if (before > 1) try w.writer.writeByte('&');
                const mark = w.written().len;
                try s.writeUrl(s.ctx, &w.writer);
                // Nothing written: drop the separator
                if (w.written().len == mark and before > 1) w.shrinkRetainingCapacity(before);
            }
            const now = w.written();
            if (std.mem.eql(u8, now, if (live.len == 0) "#" else live)) return;
            // A bare "#" keeps the page from jumping to its top
            r.dom.setHash(now, push);
        }
    };
}

pub fn Island(comptime Root: type, comptime Dom: type) type {
    return struct {
        rt: *Runtime(Dom),
        root: *Root,
        sel: []const u8,
        slot: u32,
        arenas: [2]std.heap.ArenaAllocator,
        trees: [2]tree.Tree = .{ .{}, .{} },
        cur: u1 = 0,
        /// DOM id -> node index in the current tree
        by_dom: std.ArrayList(u32) = .empty,
        listening: u16 = 0,

        const I = @This();
        const none = std.math.maxInt(u32);
        const has_url = @hasDecl(Root, "Url");

        fn build(i: *I, slot: u1, root: *Root) void {
            _ = i.arenas[slot].reset(.retain_capacity);
            i.trees[slot] = .{};
            var h: tree.H = .init(i.arenas[slot].allocator(), &i.trees[slot]);
            i.trees[slot].root = root.view(&h);
            if (h.oom) @panic("out of memory building the tree");
        }

        /// The tree the DOM shows now
        pub fn current(i: *const I) *const tree.Tree {
            return &i.trees[i.cur];
        }

        fn hydrate(i: *I, server: *Root) void {
            i.build(i.cur, server);
            const t = &i.trees[i.cur];
            const start = i.rt.ids.next;
            preorder(t, t.root, &i.rt.ids);
            const n = i.rt.dom.adopt(i.sel, start);
            if (n != i.rt.ids.next - start) i.rt.dom.warn("hydration: the server's nodes don't match the tree");
            i.index();
            i.render();
        }

        fn preorder(t: *tree.Tree, n: tree.N, ids: *diff.Ids) void {
            t.node(n).dom = ids.fresh();
            for (t.kidsOf(n)) |k| preorder(t, k, ids);
        }

        fn index(i: *I) void {
            const t = &i.trees[i.cur];
            i.by_dom.clearRetainingCapacity();
            i.by_dom.appendNTimes(i.rt.gpa, none, i.rt.ids.next) catch return;
            for (t.nodes.items, 0..) |x, k| i.by_dom.items[x.dom] = @intCast(k);
        }

        pub fn render(i: *I) void {
            const next: u1 = 1 - i.cur;
            i.build(next, i.root);
            var scratch: std.heap.ArenaAllocator = .init(i.rt.gpa);
            defer scratch.deinit();
            const focused = i.rt.dom.active();
            var d: diff.Diff(Dom) = .{
                .old = &i.trees[i.cur],
                .new = &i.trees[next],
                .o = i.rt.dom,
                .ids = &i.rt.ids,
                .a = scratch.allocator(),
                .gpa = i.rt.gpa,
                .focused = focused,
            };
            d.run();
            i.cur = next;
            i.index();
            // Moving a node drops focus inside it: put it back, without scrolling. Not a
            // removed one's: its id may be a new node's now, maybe text (focus throws)
            if (focused != 0 and !d.lost and focused < i.by_dom.items.len and i.by_dom.items[focused] != none and i.rt.dom.active() != focused) {
                i.rt.dom.focus(focused);
            }
            const mask = i.trees[i.cur].events;
            if (mask & ~i.listening != 0) {
                i.listening |= mask;
                i.rt.dom.listen(i.slot, i.sel, i.listening);
            }
        }

        fn event(i: *I, in: Input) bool {
            const t = &i.trees[i.cur];
            if (in.target >= i.by_dom.items.len or i.by_dom.items[in.target] == none) return false;
            var n: tree.N = @fromBackingInt(i.by_dom.items[in.target]);
            // Bubble to the first node with a handler for this kind
            const hd = while (true) {
                const node = t.node(n);
                if (t.handler(n, in.kind)) |hd| break hd;
                // A link's click is the browser's, unless the link itself handles it
                if (in.kind == .click and node.tag == .a) return false;
                // So is an unhandled one that opens a popover or falls inside one (a
                // column head's Toggletip must not also sort)
                if (in.kind == .click and (t.attr(n, "popovertarget") != null or t.attr(n, "popover") != null)) return false;
                if (n == t.root) return false;
                n = @fromBackingInt(node.parent);
            };
            const target = t.node(n);
            // Moves inside the node are not leaving it
            if ((in.kind == .pointerleave or in.kind == .focusout) and i.inside(in.related, n)) return false;
            var ev: tree.Event = .{ .kind = in.kind, .x = in.x, .y = in.y, .pointer = in.pointer, .text = in.text, .dom = target.dom };
            switch (in.kind) {
                .pointerdown, .pointermove, .pointerup, .pointerleave, .pointercancel => {
                    const r = i.rt.dom.rect(target.dom);
                    ev.x = in.x - r[0];
                    ev.y = in.y - r[1];
                    ev.w = r[2];
                },
                else => {},
            }
            hd.call(hd.target, &hd.msg, &ev);
            if (ev.capture) i.rt.dom.capture(target.dom, in.pointer);
            i.render();
            if (ev.after) |after| i.apply(after);
            i.rt.syncHash(ev.push) catch {};
            return ev.handled;
        }

        /// The handler's request for after the patch, on the node marked data-ref
        fn apply(i: *I, after: tree.After) void {
            if (after.op == .jump) return i.rt.dom.jump(after.ref);
            const t = &i.trees[i.cur];
            const n = t.find(t.root, "data-ref", after.ref) orelse return;
            const id = t.node(n).dom;
            switch (after.op) {
                .focus => i.rt.dom.focus(id),
                .scroll => i.rt.dom.scroll(id),
                .show => i.rt.dom.popover(id, true),
                .hide => i.rt.dom.popover(id, false),
                .click => i.rt.dom.click(id),
                .jump => unreachable,
            }
        }

        fn inside(i: *I, dom: u32, n: tree.N) bool {
            if (dom == 0 or dom >= i.by_dom.items.len or i.by_dom.items[dom] == none) return false;
            const t = &i.trees[i.cur];
            var k: tree.N = @fromBackingInt(i.by_dom.items[dom]);
            while (true) {
                if (k == n) return true;
                if (k == t.root) return false;
                k = @fromBackingInt(t.node(k).parent);
            }
        }

        fn readUrl(i: *I, hash: []const u8) void {
            if (has_url) i.root.fromUrl(url.read(Root.Url, hash));
        }

        fn eventErased(p: *anyopaque, in: Input) bool {
            return event(@ptrCast(@alignCast(p)), in);
        }
        fn renderErased(p: *anyopaque) void {
            render(@ptrCast(@alignCast(p)));
        }
        fn writeUrlErased(p: *anyopaque, w: *std.Io.Writer) std.Io.Writer.Error!void {
            const i: *I = @ptrCast(@alignCast(p));
            if (has_url) try url.write(Root.Url, i.root.toUrl(), w);
        }
        fn owns(key: []const u8) bool {
            return has_url and url.owns(Root.Url, key);
        }
        fn readUrlErased(p: *anyopaque, hash: []const u8) void {
            readUrl(@ptrCast(@alignCast(p)), hash);
        }
    };
}
