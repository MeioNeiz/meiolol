//! DataTable on the fake DOM (table.zig's Demo fixture): hydration with a URL's state,
//! sorting, search, minimums and a row's detail, each patch equal to a fresh render
const std = @import("std");
const tree = @import("tree.zig");
const diff = @import("diff.zig");
const island = @import("island.zig");
const table = @import("table.zig");
const Fake = @import("fakedom.zig").Fake;
const testing = std.testing;

const T = table.Demo.Table;

const Page = struct {
    arena: std.heap.ArenaAllocator,
    fake: Fake = undefined,
    rt: island.Runtime(Fake) = undefined,
    state: T = undefined,
    server: T = undefined,
    i: *island.Island(T, Fake) = undefined,

    fn init(p: *Page, fragment: []const u8) !void {
        p.* = .{ .arena = .init(testing.allocator) };
        const a = p.arena.allocator();
        p.fake = .{ .a = a };
        try p.fake.fragment.appendSlice(a, fragment);
        p.rt = .init(a, &p.fake);
        p.server = .{ .rows = &table.Demo.rows };
        p.state = p.server;
        const t = try a.create(tree.Tree);
        t.* = .{};
        var h: tree.H = .init(a, t);
        t.root = p.server.view(&h);
        p.fake.server = t;
        p.i = try p.rt.add(T, &p.state, &p.server, "#champions");
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

    /// Champion names in row order
    fn names(p: *Page) ![]const u8 {
        const page = try p.shown();
        var out: std.ArrayList(u8) = .empty;
        var it = std.mem.splitSequence(u8, page[std.mem.find(u8, page, "<tbody>").?..], "<b>");
        _ = it.next();
        while (it.next()) |rest| {
            if (out.items.len > 0) try out.append(p.arena.allocator(), ',');
            try out.appendSlice(p.arena.allocator(), rest[0..std.mem.findScalar(u8, rest, '<').?]);
        }
        return out.items;
    }

    /// The first `tag` node whose text is `label`
    fn byText(p: *Page, tag: tree.Tag, label: []const u8) u32 {
        const t = p.i.current();
        for (t.nodes.items, 0..) |n, k| if (n.tag == tag) {
            var w: std.Io.Writer.Allocating = .init(p.arena.allocator());
            t.textOf(@fromBackingInt(@as(u32, @intCast(k))), &w.writer) catch unreachable;
            if (std.mem.eql(u8, w.written(), label)) return n.dom;
        };
        std.debug.panic("no {t} {s}", .{ tag, label });
    }

    fn id(p: *Page, name: []const u8, value: ?[]const u8) u32 {
        const t = p.i.current();
        return t.node(t.find(t.root, name, value).?).dom;
    }
};

const by_rate = "Aurelion Sol,Kha'Zix,Miss Fortune,Darius,Ahri,Zilean,Tristana,Viktor,Renata Glasc,Qiyana";

test "the server's order; hydration takes the URL's sort; a sort moves rows and pushes" {
    var p: Page = undefined;
    try p.init("");
    defer p.deinit();
    try testing.expectEqual(@as(u32, 0), p.fake.warnings);
    // Ties (Kha'Zix and Miss Fortune at 51.4) keep the data's order
    try testing.expectEqualStrings(by_rate, try p.names());
    p.deinit();

    try p.init("#sort=0&desc=0");
    try testing.expectEqual(@as(u32, 0), p.fake.warnings);
    try testing.expectEqualStrings("Ahri,Aurelion Sol,Darius,Kha'Zix,Miss Fortune,Qiyana,Renata Glasc,Tristana,Viktor,Zilean", try p.names());
    const creates = p.fake.creates;
    _ = p.rt.event(0, .{ .kind = .click, .target = p.byText(.button, "Games") });
    try testing.expectEqualStrings("Ahri,Tristana,Viktor,Miss Fortune,Darius,Kha'Zix,Renata Glasc,Qiyana,Aurelion Sol,Zilean", try p.names());
    try testing.expectEqualStrings("#sort=5", p.fake.fragment.items);
    try testing.expectEqual(@as(u32, 1), p.fake.pushes);
    try testing.expectEqual(creates, p.fake.creates);
    _ = p.rt.event(0, .{ .kind = .click, .target = p.byText(.button, "Games") });
    try testing.expectEqualStrings("#sort=5&desc=0", p.fake.fragment.items);
    try testing.expect(std.mem.startsWith(u8, try p.names(), "Zilean,Aurelion Sol,"));
    p.fake.fragment.clearRetainingCapacity();
    p.rt.popstate();
    try testing.expectEqualStrings(by_rate, try p.names());
}

test "search, minimums and a row's detail" {
    var p: Page = undefined;
    try p.init("");
    defer p.deinit();
    _ = p.rt.event(0, .{ .kind = .input, .target = p.id("type", "search"), .text = "ri" });
    try testing.expectEqualStrings("Darius,Ahri,Tristana", try p.names());
    try testing.expectEqualStrings("#q=ri", p.fake.fragment.items);
    try testing.expectEqual(@as(u32, 1), p.fake.replaces);
    try testing.expect(std.mem.find(u8, try p.shown(), "<span class=\"count\">3</span>") != null);
    _ = p.rt.event(0, .{ .kind = .input, .target = p.id("type", "search"), .text = "" });
    // Any: Zilean's 61 games show, faded
    try testing.expect(std.mem.find(u8, try p.shown(), "<tr aria-expanded=\"false\" data-state=\"thin\"><td><b>Zilean") != null);
    _ = p.rt.event(0, .{ .kind = .click, .target = p.byText(.button, "1k") });
    try testing.expectEqualStrings("Kha'Zix,Miss Fortune,Darius,Ahri,Tristana,Viktor,Renata Glasc,Qiyana", try p.names());
    try testing.expectEqualStrings("#min=2", p.fake.fragment.items);
    _ = p.rt.event(0, .{ .kind = .click, .target = p.byText(.b, "Ahri") });
    const page = try p.shown();
    try testing.expect(std.mem.find(u8, page, "<tr aria-expanded=\"true\"><td><b>Ahri") != null);
    try testing.expect(std.mem.find(u8, page, "<tr class=\"detail\"><td colspan=\"6\"><p class=\"muted\">Ahri in Mid") != null);
    _ = p.rt.event(0, .{ .kind = .click, .target = p.byText(.b, "Ahri") });
    try testing.expect(std.mem.find(u8, try p.shown(), "class=\"detail\"") == null);
}

test "a column head's note opens without sorting; the rest of the head and its arrow sort" {
    var p: Page = undefined;
    try p.init("");
    defer p.deinit();
    try testing.expect(std.mem.find(u8, try p.shown(), "<button class=\"c-tt\" popovertarget=\"dt-tip-3\" type=\"button\">Patch</button>") != null);
    _ = p.rt.event(0, .{ .kind = .click, .target = p.id("popovertarget", "dt-tip-3") });
    _ = p.rt.event(0, .{ .kind = .click, .target = p.id("id", "dt-tip-3") });
    try testing.expectEqualStrings(by_rate, try p.names());
    try testing.expectEqualStrings("", p.fake.fragment.items);
    // Win rate's arrow: sorted already, so the order turns
    _ = p.rt.event(0, .{ .kind = .click, .target = p.id("aria-label", "Sort") });
    try testing.expectEqualStrings("#desc=0", p.fake.fragment.items);
    // Patch's head itself, around the term
    const t = p.i.current();
    const th = t.node(@fromBackingInt(@intCast(t.node(t.find(t.root, "popovertarget", "dt-tip-3").?).parent))).dom;
    _ = p.rt.event(0, .{ .kind = .click, .target = th });
    try testing.expectEqualStrings("#sort=3", p.fake.fragment.items);
    _ = p.rt.event(0, .{ .kind = .click, .target = p.byText(.th, "Games") });
    try testing.expectEqualStrings("#sort=5", p.fake.fragment.items);
}

test "a keyed table's URL fields carry its prefix" {
    const Opp = table.DataTable(table.Demo, blk: {
        var s = table.Demo.spec;
        s.key = "opp";
        break :blk s;
    });
    const u: Opp = .{ .rows = &table.Demo.rows, .sort = 5 };
    var buf: [64]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    try @import("url.zig").write(Opp.Url, u.toUrl(), &w);
    try testing.expectEqualStrings("opp-sort=5", w.buffered());
    try testing.expectEqualStrings("opp", u.id);
}
