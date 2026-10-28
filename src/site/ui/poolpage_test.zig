//! The pool page's islands on the fake DOM: the pool's empty render, hydration with a
//! URL's pool, adding from By role, removing; the grid's sections as the pool and its
//! files arrive; each patch equal to a fresh render
const std = @import("std");
const tree = @import("tree.zig");
const diff = @import("diff.zig");
const html = @import("html.zig");
const check = @import("check.zig");
const island = @import("island.zig");
const pp = @import("poolpage.zig");
const pd = @import("pooldata.zig");
const pg = @import("poolgrid.zig");
const Fake = @import("fakedom.zig").Fake;
const testing = std.testing;

fn Harness(comptime T: type, comptime sel: []const u8) type {
    return struct {
        arena: std.heap.ArenaAllocator,
        fake: Fake = undefined,
        rt: island.Runtime(Fake) = undefined,
        state: T = undefined,
        server: T = undefined,
        i: *island.Island(T, Fake) = undefined,

        const Self = @This();

        fn init(p: *Self, fragment: []const u8, comptime make: fn (std.mem.Allocator) anyerror!T) !void {
            p.* = .{ .arena = .init(testing.allocator) };
            const a = p.arena.allocator();
            p.fake = .{ .a = a };
            try p.fake.fragment.appendSlice(a, fragment);
            p.rt = .init(a, &p.fake);
            p.server = try make(a);
            p.state = p.server;
            const t = try a.create(tree.Tree);
            t.* = .{};
            var h: tree.H = .init(a, t);
            t.root = p.server.view(&h);
            p.fake.server = t;
            p.i = try p.rt.add(T, &p.state, &p.server, sel);
        }

        /// The page as a reader sees it, checked equal to a fresh render
        fn shown(p: *Self) ![]const u8 {
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

        fn id(p: *Self, name: []const u8, value: ?[]const u8) u32 {
            const t = p.i.current();
            return t.node(t.find(t.root, name, value).?).dom;
        }

        fn click(p: *Self, target: u32) void {
            _ = p.rt.event(0, .{ .kind = .click, .target = target });
        }

        fn deinit(p: *Self) void {
            p.arena.deinit();
        }
    };
}

const Page = Harness(pp.Page, pp.sel);
const Grid = Harness(pg.Page, pg.sel);

fn pool(a: std.mem.Allocator) !pp.Page {
    return .init(a, &pp.Demo.data);
}

fn grid(_: std.mem.Allocator) !pg.Page {
    return .{ .d = &pp.Demo.data };
}

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

test "By role adds in its tab's role, the URL keeps the pool, × removes; older links hydrate" {
    var p: Page = undefined;
    try p.init("", pool);
    defer p.deinit();
    try testing.expectEqual(@as(u32, 0), p.fake.warnings);
    p.click(p.id("aria-label", "Add Darius"));
    try testing.expectEqualStrings("#pool=1t", p.fake.fragment.items);
    p.click(p.id("aria-label", "Jungle"));
    p.click(p.id("aria-label", "Add Vi"));
    p.click(p.id("aria-label", "Add Jax"));
    try testing.expectEqualStrings("#pool=1t-40j-3j", p.fake.fragment.items);
    try testing.expect(std.mem.find(u8, try p.shown(), "3 of 10") != null);
    p.click(p.id("aria-label", "Remove Darius"));
    try testing.expectEqualStrings("#pool=40j-3j", p.fake.fragment.items);
    _ = try p.shown();

    var q: Page = undefined;
    try q.init("#pool=1-2&why=banned", pool);
    defer q.deinit();
    try testing.expectEqual(2, q.state.n);
    try testing.expectEqual(pp.Pick{ .id = 2, .role = .top }, q.state.pool[1]);
    _ = try q.shown();
}

test "the grid: empty from the server, the pool handed over, files in, cells and sort patched" {
    var p: Grid = undefined;
    try p.init("", grid);
    defer p.deinit();
    try testing.expectEqual(@as(u32, 0), p.fake.warnings);
    p.state.setPool("1t-2t-40j");
    p.state.loadedLanes(1, &pg.Demo.darius);
    p.state.loadedLanes(2, &pg.Demo.garen);
    p.state.loadedLanes(40, &pg.Demo.vi);
    p.state.loadedMain(1, &pd.demo);
    p.i.render();
    try testing.expect(std.mem.find(u8, try p.shown(), "2 of 5 lanes covered") != null);
    p.click(p.id("aria-label", "Darius into Fiora −2.6, 900 games"));
    try testing.expect(std.mem.find(u8, try p.shown(), "darius-vs-fiora.html") != null);
    // The top section's Sort: Most met, the first not pressed
    p.click(p.id("aria-pressed", "false"));
    try testing.expectEqual(.met, p.state.sort);
    _ = try p.shown();
    p.click(p.id("aria-label", "Add Jax"));
    try testing.expectEqual(pp.Pick{ .id = 3, .role = .top }, p.state.adding.?);
    // The pool shrinks: Vi's section goes
    p.state.setPool("1t-2t");
    p.i.render();
    try testing.expectEqual(1, std.mem.count(u8, try p.shown(), "class=\"c-card\""));
}
