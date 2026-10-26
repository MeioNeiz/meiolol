//! BuildPanel on the fake DOM (build_demo.zig's Darius): a cell opens from the URL or its
//! "all", closes by "fewer", Escape or Back; RuneTree's pages, runes and Every tree.
//! Each patch equal to a fresh render
const std = @import("std");
const tree = @import("tree.zig");
const diff = @import("diff.zig");
const island = @import("island.zig");
const bp = @import("buildpanel.zig");
const demo = @import("build_demo.zig");
const Fake = @import("fakedom.zig").Fake;
const testing = std.testing;

const P = bp.BuildPanel;

const Page = struct {
    arena: std.heap.ArenaAllocator,
    fake: Fake = undefined,
    rt: island.Runtime(Fake) = undefined,
    state: P = undefined,
    server: P = undefined,
    i: *island.Island(P, Fake) = undefined,

    fn init(p: *Page, fragment: []const u8) !void {
        p.* = .{ .arena = .init(testing.allocator) };
        const a = p.arena.allocator();
        p.fake = .{ .a = a };
        try p.fake.fragment.appendSlice(a, fragment);
        p.rt = .init(a, &p.fake);
        try p.server.init(a, &demo.darius);
        try p.state.init(a, &demo.darius);
        const t = try a.create(tree.Tree);
        t.* = .{};
        var h: tree.H = .init(a, t);
        t.root = p.server.view(&h);
        p.fake.server = t;
        p.i = try p.rt.add(P, &p.state, &p.server, "#build");
    }

    fn deinit(p: *Page) void {
        p.arena.deinit();
    }

    /// The DOM as markup, checked equal to a fresh render of the current tree
    fn shown(p: *Page) ![]const u8 {
        const a = p.arena.allocator();
        var got: std.Io.Writer.Allocating = .init(a);
        try p.fake.html(p.fake.roots.items[0], &got.writer);
        var fresh: Fake = .{ .a = a };
        var t = p.i.current().*;
        t.nodes = try t.nodes.clone(a);
        var ids: diff.Ids = .{};
        number(&t, t.root, &ids);
        var want: std.Io.Writer.Allocating = .init(a);
        try fresh.html(fresh.mirror(&t, t.root), &want.writer);
        try testing.expectEqualStrings(want.written(), got.written());
        return got.written();
    }

    fn number(t: *tree.Tree, n: tree.N, ids: *diff.Ids) void {
        t.node(n).dom = ids.take();
        for (t.kidsOf(n)) |k| number(t, k, ids);
    }

    fn has(p: *Page, s: []const u8) !bool {
        return std.mem.find(u8, try p.shown(), s) != null;
    }

    /// DOM id of the `nth` node whose attribute `name` is `value`
    fn nth(p: *Page, name: []const u8, value: []const u8, n: usize) u32 {
        const t = p.i.current();
        var seen: usize = 0;
        for (t.nodes.items, 0..) |x, k| {
            const v = t.attr(@fromBackingInt(@as(u32, @intCast(k))), name) orelse continue;
            if (!std.mem.eql(u8, v, value)) continue;
            if (seen == n) return x.dom;
            seen += 1;
        }
        std.debug.panic("no {s}={s} #{d}", .{ name, value, n });
    }

    /// The first button whose text is `label`
    fn button(p: *Page, label: []const u8) u32 {
        const t = p.i.current();
        for (t.nodes.items, 0..) |n, k| if (n.tag == .button) {
            var w: std.Io.Writer.Allocating = .init(p.arena.allocator());
            t.textOf(@fromBackingInt(@as(u32, @intCast(k))), &w.writer) catch unreachable;
            if (std.mem.eql(u8, w.written(), label)) return n.dom;
        };
        std.debug.panic("no button {s}", .{label});
    }

    /// The open cell's first option name
    fn firstName(p: *Page) ![]const u8 {
        const page = try p.shown();
        const at = (std.mem.find(u8, page, "class=\"nm\">") orelse return "") + "class=\"nm\">".len;
        return page[at..];
    }

    fn click(p: *Page, target: u32) void {
        _ = p.rt.event(0, .{ .kind = .click, .target = target });
    }

    fn key(p: *Page, target: u32, k: []const u8) bool {
        return p.rt.event(0, .{ .kind = .keydown, .target = target, .text = k });
    }
};

const item4_open = "data-k=\"item4\" data-open";
const thornmail_named = "Thornmail</span>";

test "a cell opens from the URL or its all; fewer, Escape and Back close it" {
    var p: Page = undefined;
    try p.init("");
    defer p.deinit();
    try testing.expectEqual(@as(u32, 0), p.fake.warnings);
    try testing.expect(!try p.has("data-open"));
    p.click(p.nth("data-ref", "all-item4", 0));
    try testing.expect(try p.has(item4_open));
    try testing.expect(try p.has(thornmail_named));
    try testing.expectEqualStrings("#slot=item4", p.fake.fragment.items);
    try testing.expectEqual(@as(u32, 1), p.fake.pushes);
    // One open at a time
    p.click(p.nth("data-ref", "all-item5", 0));
    try testing.expect(!try p.has(item4_open));
    try testing.expectEqualStrings("#slot=item5", p.fake.fragment.items);
    p.click(p.nth("data-ref", "all-item5", 0));
    try testing.expect(!try p.has("data-open"));
    try testing.expectEqualStrings("#", p.fake.fragment.items);

    p.fake.fragment.clearRetainingCapacity();
    try p.fake.fragment.appendSlice(p.arena.allocator(), "#slot=item4");
    p.rt.popstate();
    try testing.expect(try p.has(item4_open));
    // Escape from inside the open cell (its sort heads): closed, focus on its all
    const pushes = p.fake.pushes;
    try testing.expect(!p.key(p.nth("data-ref", "all-item4", 0), "a"));
    try testing.expect(try p.has(item4_open));
    try testing.expect(p.key(p.nth("aria-sort", "descending", 0), "Escape"));
    try testing.expect(!try p.has("data-open"));
    try testing.expectEqual(p.nth("data-ref", "all-item4", 0), p.fake.focused);
    try testing.expectEqualStrings("#", p.fake.fragment.items);
    try testing.expectEqual(pushes + 1, p.fake.pushes);
    // A closed cell takes no keys
    try testing.expect(!p.key(p.nth("data-ref", "all-item4", 0), "Escape"));
}

test "hydration takes the URL's cell; one with no cell is dropped" {
    var p: Page = undefined;
    try p.init("#slot=item4");
    try testing.expectEqual(@as(u32, 0), p.fake.warnings);
    try testing.expect(try p.has(item4_open));
    // The open cell sorts, and stays open: most played first, then by Won
    try testing.expect(std.mem.startsWith(u8, try p.firstName(), "Force of Nature"));
    p.click(p.button("Won"));
    try testing.expect(try p.has(item4_open));
    try testing.expect(std.mem.startsWith(u8, try p.firstName(), "Sterak"));
    p.deinit();

    try p.init("#slot=skill_path");
    defer p.deinit();
    try testing.expect(!try p.has("data-open"));
    try testing.expectEqual(@as(?bp.Kind, null), p.state.open);
}

test "skills open with every level path" {
    var p: Page = undefined;
    try p.init("#slot=skills");
    defer p.deinit();
    try testing.expect(try p.has("data-k=\"skills\" data-open"));
    // The least played path (R bold) shows only open
    try testing.expect(try p.has("QWEQQ<b>R</b>QWQW<b>R</b>"));
    p.click(p.nth("data-ref", "all-skills", 0));
    try testing.expect(!try p.has("QWEQQ<b>R</b>QWQW<b>R</b>"));
}

test "rune pages light their runes; a tapped rune fills the readout; Every tree unfolds" {
    var p: Page = undefined;
    try p.init("");
    defer p.deinit();
    try testing.expect(try p.has("<div class=\"c-runes\" data-fold"));
    const lit = std.mem.count(u8, try p.shown(), "data-state=\"lit\"");
    try testing.expect(lit >= 6);
    // The second page
    p.click(p.nth("class", "ks", 1));
    try testing.expectEqualStrings("true", p.i.current().attr(@fromBackingInt(p.i.by_dom.items[p.nth("class", "ks", 1)]), "aria-pressed").?);
    // The chosen page again: none chosen, every tree, nothing lit
    p.click(p.nth("class", "ks", 1));
    try testing.expect(!try p.has("data-fold"));
    try testing.expect(!try p.has("data-state=\"lit\""));
    p.click(p.nth("class", "ks", 0));

    try testing.expect(!try p.has("data-v=\"rune\""));
    p.click(p.nth("class", "rune", 0));
    try testing.expect(try p.has("data-v=\"rune\""));
    try testing.expect(try p.has("data-state=\"sel\""));
    p.click(p.nth("class", "rune", 0));
    try testing.expect(!try p.has("data-v=\"rune\""));

    const every = p.nth("class", "c-btn", std.mem.count(u8, try p.shown(), "class=\"c-btn\"") - 1);
    p.click(every);
    try testing.expect(!try p.has("data-fold"));
    try testing.expect(try p.has(">Chosen page</button>"));
    // Rune taps leave the URL alone
    try testing.expectEqualStrings("", p.fake.fragment.items);
}
