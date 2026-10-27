//! The pool page on the fake DOM: the server's empty render, hydration with a URL's
//! pool, adding from By role and the grid, removing; each patch equal to a fresh render
const std = @import("std");
const tree = @import("tree.zig");
const diff = @import("diff.zig");
const html = @import("html.zig");
const check = @import("check.zig");
const island = @import("island.zig");
const pp = @import("poolpage.zig");
const pd = @import("pooldata.zig");
const Fake = @import("fakedom.zig").Fake;
const testing = std.testing;

const Page = struct {
    arena: std.heap.ArenaAllocator,
    fake: Fake = undefined,
    rt: island.Runtime(Fake) = undefined,
    state: pp.Page = undefined,
    server: pp.Page = undefined,
    i: *island.Island(pp.Page, Fake) = undefined,

    fn init(p: *Page, fragment: []const u8) !void {
        p.* = .{ .arena = .init(testing.allocator) };
        const a = p.arena.allocator();
        p.fake = .{ .a = a };
        try p.fake.fragment.appendSlice(a, fragment);
        p.rt = .init(a, &p.fake);
        p.server = try .init(a, &pp.Demo.data);
        p.state = p.server;
        const t = try a.create(tree.Tree);
        t.* = .{};
        var h: tree.H = .init(a, t);
        t.root = p.server.view(&h);
        p.fake.server = t;
        p.i = try p.rt.add(pp.Page, &p.state, &p.server, pp.sel);
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

    fn id(p: *Page, name: []const u8, value: ?[]const u8) u32 {
        const t = p.i.current();
        return t.node(t.find(t.root, name, value).?).dom;
    }

    fn click(p: *Page, target: u32) void {
        _ = p.rt.event(0, .{ .kind = .click, .target = target });
    }

    fn deinit(p: *Page) void {
        p.arena.deinit();
    }
};

test "the server renders the picker, clean" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var s: pp.Page = try .init(a, &pp.Demo.data);
    var t: tree.Tree = .{};
    var h: tree.H = .init(a, &t);
    t.root = s.view(&h);
    var w: std.Io.Writer.Allocating = .init(a);
    try html.write(&t, t.root, &w.writer);
    try testing.expect(std.mem.find(u8, w.written(), "<h2>Choose your pool</h2>") != null);
    const report = try check.run(a, &t, .{ .words = .off, .answer = .off });
    for (report.findings.items) |f| std.debug.print("{s}\n", .{f.msg});
    try testing.expectEqual(@as(usize, 0), report.findings.items.len);
}

test "By role adds, the URL keeps the pool, × removes; a URL's pool hydrates" {
    var p: Page = undefined;
    try p.init("");
    defer p.deinit();
    try testing.expectEqual(@as(u32, 0), p.fake.warnings);
    p.click(p.id("aria-label", "Add Darius"));
    try testing.expectEqualStrings("#pool=1", p.fake.fragment.items);
    try testing.expectEqual(1, p.state.need());
    try testing.expect(std.mem.find(u8, try p.shown(), "Loading lanes") != null);
    p.click(p.id("aria-label", "Add Garen"));
    try testing.expectEqualStrings("#pool=1-2", p.fake.fragment.items);

    p.state.loaded(1, &pd.demo);
    p.i.render();
    const grid = try p.shown();
    try testing.expect(std.mem.find(u8, grid, "1 of 2 covered") != null);
    // Jax covers Garen's open lane: Add under its column and as the best answer
    p.click(p.id("aria-label", "Add Jax"));
    try testing.expectEqualStrings("#pool=1-2-3", p.fake.fragment.items);
    try testing.expect(std.mem.find(u8, try p.shown(), "2 of 2 covered") != null);

    p.click(p.id("aria-label", "Remove Darius"));
    try testing.expectEqualStrings("#pool=2-3", p.fake.fragment.items);
    // Garen is the main now: its own file, not Darius's
    try testing.expectEqual(2, p.state.need());
    _ = try p.shown();

    var q: Page = undefined;
    try q.init("#pool=1-2&why=banned");
    defer q.deinit();
    try testing.expectEqualSlices(u16, &.{ 1, 2 }, q.state.ids());
    try testing.expectEqual(.banned, q.state.why);
    q.state.loaded(1, &pd.demo);
    q.i.render();
    // When banned: Mundo is good into Teemo, the main's good lane (Garen is in the pool)
    const banned = try q.shown();
    const list = std.mem.find(u8, banned, "class=\"c-cand\"").?;
    try testing.expect(std.mem.find(u8, banned[list..], "<b>Dr. Mundo</b>") != null);
}
