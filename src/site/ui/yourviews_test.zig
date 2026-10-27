//! YourViews and YourList on the fake DOM, each its own runtime as on games.html: a
//! press in either writes the fragment, which the other reads as it would on ui-hash.
//! Both write q/role/champ, so each must keep the keys it doesn't own (view) and agree
//! on the filter after every press
const std = @import("std");
const tree = @import("tree.zig");
const island = @import("island.zig");
const yp = @import("yourpage.zig");
const yv = @import("yourviews.zig");
const Fake = @import("fakedom.zig").Fake;
const testing = std.testing;

fn Side(comptime Root: type) type {
    return struct {
        fake: Fake,
        rt: island.Runtime(Fake) = undefined,
        state: Root,
        server: Root,
        i: *island.Island(Root, Fake) = undefined,

        const S = @This();

        fn init(s: *S, a: std.mem.Allocator, fragment: []const u8, sel: []const u8) !void {
            s.server = .{ .l = &yp.demo.list };
            s.state = s.server;
            s.fake = .{ .a = a };
            try s.fake.fragment.appendSlice(a, fragment);
            s.rt = .init(a, &s.fake);
            const t = try a.create(tree.Tree);
            t.* = .{};
            var h: tree.H = .init(a, t);
            t.root = s.server.view(&h);
            s.fake.server = t;
            s.i = try s.rt.add(Root, &s.state, &s.server, sel);
            try testing.expectEqual(@as(u32, 0), s.fake.warnings);
        }

        /// The first element whose own or a descendant's text is `label`, or whose
        /// title starts with it
        fn find(s: *S, label: []const u8) u32 {
            const t = s.i.current();
            for (t.nodes.items, 0..) |n, k| {
                const at: tree.N = @fromBackingInt(@intCast(k));
                if (n.tag == .button and has(t, at, label)) return n.dom;
                if (std.mem.startsWith(u8, t.attr(at, "title") orelse continue, label)) return n.dom;
            }
            unreachable;
        }

        fn has(t: *const tree.Tree, n: tree.N, label: []const u8) bool {
            if (std.mem.eql(u8, t.node(n).text, label)) return true;
            for (t.kidsOf(n)) |k| if (has(t, k, label)) return true;
            return false;
        }

        /// Games in the bar's form strip
        fn form(s: *S) usize {
            const t = s.i.current();
            return t.count(t.find(t.root, "class", "c-form").?, "data-r");
        }
    };
}

const Page = struct {
    arena: std.heap.ArenaAllocator,
    views: Side(yv.YourViews) = undefined,
    list: Side(yp.YourList) = undefined,

    fn init(p: *Page, fragment: []const u8) !void {
        p.* = .{ .arena = .init(testing.allocator) };
        const a = p.arena.allocator();
        try p.views.init(a, fragment, yv.sel);
        try p.list.init(a, fragment, yp.sel);
    }

    /// A press in one; its fragment reaches the other as ui-hash does
    fn press(p: *Page, comptime in_views: bool, label: []const u8) !void {
        const a = p.arena.allocator();
        if (in_views) {
            _ = p.views.rt.event(0, .{ .kind = .click, .target = p.views.find(label) });
            p.list.fake.fragment.clearRetainingCapacity();
            try p.list.fake.fragment.appendSlice(a, p.views.fake.fragment.items);
            p.list.rt.popstate();
        } else {
            _ = p.list.rt.event(0, .{ .kind = .click, .target = p.list.find(label) });
            p.views.fake.fragment.clearRetainingCapacity();
            try p.views.fake.fragment.appendSlice(a, p.list.fake.fragment.items);
            p.views.rt.popstate();
        }
        try testing.expectEqualDeep(p.views.state.filter, p.list.state.sum.filter);
    }

    fn hash(p: *Page) []const u8 {
        return p.views.fake.fragment.items;
    }

    fn deinit(p: *Page) void {
        p.arena.deinit();
    }
};

test "presses in both, in turn: one filter, no key lost" {
    var p: Page = undefined;
    try p.init("#view=highlights&q=flex");
    defer p.deinit();
    try testing.expectEqual(.highlights, p.views.state.tab);
    try testing.expectEqual(.flex, p.list.state.sum.filter.queue);
    // The bar's form: flex's 2 games
    try testing.expectEqual(2, p.views.form());

    // The list's champion press keeps the views' tab
    try p.press(false, "Karthus:");
    try testing.expectEqualStrings("#view=highlights&q=flex&champ=Karthus", p.hash());
    // The bar's queue: All, the champion kept
    try p.press(true, "All");
    try testing.expectEqualStrings("#view=highlights&champ=Karthus", p.hash());
    try testing.expectEqual(5, p.views.form());
    // The list's role press, then the bar's tab
    try p.press(false, "Jungle:");
    try testing.expectEqualStrings("#view=highlights&role=jungle&champ=Karthus", p.hash());
    try p.press(true, "Games");
    try testing.expectEqualStrings("#role=jungle&champ=Karthus", p.hash());
    try testing.expectEqual(.games, p.views.state.tab);
    // The list's champion press again: All champions
    try p.press(false, "Karthus:");
    try testing.expectEqualStrings("#role=jungle", p.hash());
    try testing.expectEqual(5, p.views.form());
}
