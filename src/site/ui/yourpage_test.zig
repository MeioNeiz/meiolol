//! The Your games list on the fake DOM: hydration with a URL's filter and the visitor's
//! clock, the summary's presses into the URL, Show older, Back; each patch equal to a
//! fresh render. With YourViews beside it: yourviews_test.zig
const std = @import("std");
const tree = @import("tree.zig");
const diff = @import("diff.zig");
const html = @import("html.zig");
const check = @import("check.zig");
const island = @import("island.zig");
const yp = @import("yourpage.zig");
const Fake = @import("fakedom.zig").Fake;
const testing = std.testing;

const utc: [yp.demo.games.len]i32 = @splat(0);

const Page = struct {
    arena: std.heap.ArenaAllocator,
    fake: Fake = undefined,
    rt: island.Runtime(Fake) = undefined,
    state: yp.YourList = undefined,
    server: yp.YourList = undefined,
    i: *island.Island(yp.YourList, Fake) = undefined,

    /// As wasm/your.zig: the server's tree, then the clock and each game's zone
    fn init(p: *Page, fragment: []const u8) !void {
        p.* = .{ .arena = .init(testing.allocator) };
        const a = p.arena.allocator();
        p.fake = .{ .a = a };
        try p.fake.fragment.appendSlice(a, fragment);
        p.rt = .init(a, &p.fake);
        p.server = .{ .l = &yp.demo.list };
        p.state = p.server;
        const t = try a.create(tree.Tree);
        t.* = .{};
        var h: tree.H = .init(a, t);
        t.root = p.server.view(&h);
        p.fake.server = t;
        p.i = try p.rt.add(yp.YourList, &p.state, &p.server, yp.sel);
        try testing.expectEqual(@as(u32, 0), p.fake.warnings);
        p.state.now_ms = yp.demo.now;
        p.state.tz = &utc;
        p.i.render();
    }

    /// The page as a reader sees it, checked equal to a fresh render
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

    fn rows(p: *Page) !usize {
        return std.mem.count(u8, try p.shown(), "class=\"c-grow\"");
    }

    fn id(p: *Page, name: []const u8, value: ?[]const u8) u32 {
        const t = p.i.current();
        return t.node(t.find(t.root, name, value).?).dom;
    }

    /// The first `tag` with `label` as its own or a descendant's text
    fn by(p: *Page, tag: tree.Tag, label: []const u8) u32 {
        const t = p.i.current();
        for (t.nodes.items, 0..) |n, k| if (n.tag == tag and has(t, @fromBackingInt(@intCast(k)), label)) return n.dom;
        unreachable;
    }

    /// The first element whose title starts with `prefix`
    fn titled(p: *Page, prefix: []const u8) u32 {
        const t = p.i.current();
        for (t.nodes.items, 0..) |n, k| {
            const title = t.attr(@fromBackingInt(@intCast(k)), "title") orelse continue;
            if (std.mem.startsWith(u8, title, prefix)) return n.dom;
        }
        unreachable;
    }

    fn has(t: *const tree.Tree, n: tree.N, label: []const u8) bool {
        if (std.mem.eql(u8, t.node(n).text, label)) return true;
        for (t.kidsOf(n)) |k| if (has(t, k, label)) return true;
        return false;
    }

    fn click(p: *Page, target: u32) void {
        _ = p.rt.event(0, .{ .kind = .click, .target = target });
    }

    fn deinit(p: *Page) void {
        p.arena.deinit();
    }
};

test "the server renders the list, clean" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var s: yp.YourList = .{ .l = &yp.demo.list };
    var t: tree.Tree = .{};
    var h: tree.H = .init(a, &t);
    t.root = s.view(&h);
    try testing.expect(!h.oom);
    var w: std.Io.Writer.Allocating = .init(a);
    try html.write(&t, t.root, &w.writer);
    try testing.expect(std.mem.find(u8, w.written(), "Show older") == null);
    const report = try check.run(a, &t, .{ .words = .off, .answer = .off });
    for (report.findings.items) |f| std.debug.print("{s}\n", .{f.msg});
    try testing.expectEqual(@as(usize, 0), report.findings.items.len);
}

test "a URL's filter hydrates; the clock adds Today; presses write the URL; Back restores" {
    var p: Page = undefined;
    try p.init("#q=solo&role=jungle");
    defer p.deinit();
    // Jungle in solo: games 1, 5 and 9 (3 and 7 are flex)
    try testing.expectEqual(3, try p.rows());
    try testing.expect(std.mem.find(u8, try p.shown(), "Today") != null);

    // The summary's role press again: All roles
    p.click(p.titled("Jungle:"));
    try testing.expectEqualStrings("#q=solo", p.fake.fragment.items);
    try testing.expectEqual(8, try p.rows());
    p.fake.fragment.clearRetainingCapacity();
    p.rt.popstate();
    try testing.expectEqual(10, try p.rows());

    // The summary's champion press: the URL names it
    p.click(p.titled("Aurelion Sol:"));
    try testing.expectEqualStrings("#champ=Aurelion%20Sol", p.fake.fragment.items);
    try testing.expectEqual(5, try p.rows());
    const pushes = p.fake.pushes;

    p.fake.fragment.clearRetainingCapacity();
    try p.fake.fragment.appendSlice(p.arena.allocator(), "#q=flex");
    p.rt.popstate();
    try testing.expectEqual(2, try p.rows());
    try testing.expectEqual(pushes, p.fake.pushes);
}

test "Show older adds days; a filter press starts again from the newest" {
    var p: Page = undefined;
    try p.init("");
    defer p.deinit();
    p.state.shown = 2;
    p.i.render();
    try testing.expectEqual(6, try p.rows());
    p.click(p.by(.button, "Show older"));
    try testing.expectEqual(10, try p.rows());
    try testing.expect(std.mem.find(u8, try p.shown(), "Show older") == null);
    p.click(p.titled("Karthus:"));
    try testing.expectEqualStrings("#champ=Karthus", p.fake.fragment.items);
    try testing.expectEqual(5, try p.rows());
}

test "a URL nothing could clear is dropped: an unchipped queue, an unplayed champion" {
    var p: Page = undefined;
    try p.init("#q=other&champ=Ahri");
    defer p.deinit();
    try testing.expectEqual(null, p.state.toUrl().q);
    try testing.expectEqual(0, p.state.toUrl().champ.len);
    try testing.expectEqual(10, try p.rows());
    var q: Page = undefined;
    // Karthus plays jungle only
    try q.init("#role=mid&champ=Karthus");
    defer q.deinit();
    try testing.expectEqual(null, q.state.sum.filter.champ);
    try testing.expectEqual(5, try q.rows());
}
