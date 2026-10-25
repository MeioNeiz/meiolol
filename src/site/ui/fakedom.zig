//! A DOM model for tests: applies the diff's ops (the same calls ui.wasm makes through
//! zjb) and prints the result as HTML, so diff, hydration and island tests need no
//! browser
const std = @import("std");
const tree = @import("tree.zig");

/// A DOM model: enough to apply ops and print the result as HTML
pub const Fake = struct {
    a: std.mem.Allocator,
    nodes: std.AutoHashMapUnmanaged(u32, *FNode) = .empty,
    moves: u32 = 0,
    creates: u32 = 0,
    forgotten: u32 = 0,

    // What the island runtime asks of a page
    /// The page's HTML before hydration, as a tree (what the server wrote)
    server: ?*tree.Tree = null,
    /// Each island's root once adopted
    roots: std.ArrayList(*FNode) = .empty,
    listened: u16 = 0,
    focused: u32 = 0,
    width: f32 = 760,
    fragment: std.ArrayList(u8) = .empty,
    pushes: u32 = 0,
    replaces: u32 = 0,
    warnings: u32 = 0,
    shown: u32 = 0,
    scrolled: u32 = 0,

    pub const FNode = struct {
        tag: []const u8,
        text: []const u8 = "",
        attrs: std.ArrayList(tree.Attr) = .empty,
        kids: std.ArrayList(*FNode) = .empty,
        parent: ?*FNode = null,
    };

    /// A copy, as the browser keeps: the island's render arenas are reused
    fn own(f: *Fake, s: []const u8) []const u8 {
        return f.a.dupe(u8, s) catch unreachable;
    }

    fn put(f: *Fake, id: u32, n: FNode) void {
        const p = f.a.create(FNode) catch unreachable;
        p.* = n;
        f.nodes.put(f.a, id, p) catch unreachable;
        f.creates += 1;
    }

    /// Mirror an existing tree whose nodes have their ids
    pub fn mirror(f: *Fake, t: *const tree.Tree, n: tree.N) *FNode {
        const x = t.node(n);
        f.put(x.dom, .{ .tag = @tagName(x.tag), .text = f.own(x.text) });
        const me = f.nodes.get(x.dom).?;
        if (x.tag != .@"#text") {
            for (t.attrsOf(n)) |a| me.attrs.append(f.a, .{ .name = a.name, .value = f.own(a.value) }) catch unreachable;
            for (t.kidsOf(n)) |k| {
                const c = f.mirror(t, k);
                c.parent = me;
                me.kids.append(f.a, c) catch unreachable;
            }
        }
        return me;
    }

    pub fn el(f: *Fake, id: u32, tag: tree.Tag) void {
        f.put(id, .{ .tag = @tagName(tag) });
    }
    pub fn text(f: *Fake, id: u32, s: []const u8) void {
        f.put(id, .{ .tag = "#text", .text = f.own(s) });
    }
    pub fn attr(f: *Fake, id: u32, name: []const u8, v: []const u8) void {
        const n = f.nodes.get(id).?;
        for (n.attrs.items) |*a| if (std.mem.eql(u8, a.name, name)) {
            a.value = f.own(v);
            return;
        };
        n.attrs.append(f.a, .{ .name = name, .value = f.own(v) }) catch unreachable;
    }
    pub fn del(f: *Fake, id: u32, name: []const u8) void {
        const n = f.nodes.get(id).?;
        for (n.attrs.items, 0..) |a, i| if (std.mem.eql(u8, a.name, name)) {
            _ = n.attrs.orderedRemove(i);
            return;
        };
    }
    pub fn data(f: *Fake, id: u32, s: []const u8) void {
        f.nodes.get(id).?.text = f.own(s);
    }
    fn detach(n: *FNode) void {
        const p = n.parent orelse return;
        for (p.kids.items, 0..) |k, i| if (k == n) {
            _ = p.kids.orderedRemove(i);
            break;
        };
        n.parent = null;
    }
    pub fn ins(f: *Fake, parent: u32, id: u32, before: u32) void {
        const p = f.nodes.get(parent).?;
        const n = f.nodes.get(id).?;
        if (n.parent != null) {
            f.moves += 1;
            // As browsers do: moving a node blurs what is focused inside it
            if (f.nodes.get(f.focused)) |fx| {
                var k: ?*FNode = fx;
                while (k) |x| : (k = x.parent) if (x == n) {
                    f.focused = 0;
                    break;
                };
            }
        }
        detach(n);
        n.parent = p;
        if (before == 0) {
            p.kids.append(f.a, n) catch unreachable;
            return;
        }
        const b = f.nodes.get(before).?;
        for (p.kids.items, 0..) |k, i| if (k == b) {
            p.kids.insert(f.a, i, n) catch unreachable;
            return;
        };
        unreachable;
    }
    pub fn rm(f: *Fake, id: u32) void {
        detach(f.nodes.get(id).?);
    }
    pub fn forget(f: *Fake, id: u32) void {
        _ = f.nodes.remove(id);
        f.forgotten += 1;
    }

    /// Hydration: the server's nodes get ids from `first` in pre-order
    pub fn adopt(f: *Fake, _: []const u8, first: u32) u32 {
        const t = f.server orelse return 0;
        var id = first;
        number(t, t.root, &id);
        f.roots.append(f.a, f.mirror(t, t.root)) catch unreachable;
        return id - first;
    }

    fn number(t: *tree.Tree, n: tree.N, id: *u32) void {
        t.node(n).dom = id.*;
        id.* += 1;
        for (t.kidsOf(n)) |k| number(t, k, id);
    }

    pub fn listen(f: *Fake, _: u32, _: []const u8, mask: u16) void {
        f.listened = mask;
    }
    pub fn rect(f: *Fake, _: u32) [3]f32 {
        return .{ 0, 0, f.width };
    }
    pub fn capture(_: *Fake, _: u32, _: i32) void {}
    pub fn active(f: *Fake) u32 {
        return if (f.nodes.contains(f.focused)) f.focused else 0;
    }
    pub fn focus(f: *Fake, id: u32) void {
        f.focused = id;
    }
    pub fn scroll(f: *Fake, _: u32) void {
        f.scrolled += 1;
    }
    pub fn popover(f: *Fake, _: u32, show: bool) void {
        if (show) f.shown += 1 else f.shown -|= 1;
    }
    pub fn hash(f: *Fake, _: []u8) []const u8 {
        return f.fragment.items;
    }
    pub fn setHash(f: *Fake, s: []const u8, push: bool) void {
        f.fragment.clearRetainingCapacity();
        f.fragment.appendSlice(f.a, s) catch unreachable;
        if (push) f.pushes += 1 else f.replaces += 1;
    }
    pub fn warn(f: *Fake, _: []const u8) void {
        f.warnings += 1;
    }

    pub fn html(f: *Fake, n: *FNode, w: *std.Io.Writer) !void {
        if (std.mem.eql(u8, n.tag, "#text")) return w.writeAll(n.text);
        try w.print("<{s}", .{n.tag});
        // Attribute order may differ from a fresh render: print sorted
        const sorted = try f.a.dupe(tree.Attr, n.attrs.items);
        std.mem.sort(tree.Attr, sorted, {}, struct {
            fn lt(_: void, x: tree.Attr, y: tree.Attr) bool {
                return std.mem.lessThan(u8, x.name, y.name);
            }
        }.lt);
        for (sorted) |a| try w.print(" {s}=\"{s}\"", .{ a.name, a.value });
        try w.writeByte('>');
        for (n.kids.items) |k| try f.html(k, w);
        try w.print("</{s}>", .{n.tag});
    }
};
