//! ChampSearch on the fake DOM: typing opens the list, arrows and Enter, Escape, focus
//! leaving the box or moving to an option, a pick and its clear; each patch equal to a
//! fresh render
const std = @import("std");
const tree = @import("tree.zig");
const diff = @import("diff.zig");
const island = @import("island.zig");
const cs = @import("champsearch.zig");
const Fake = @import("fakedom.zig").Fake;
const testing = std.testing;

const S = cs.ChampSearch;

const Page = struct {
    arena: std.heap.ArenaAllocator,
    fake: Fake = undefined,
    rt: island.Runtime(Fake) = undefined,
    ix: cs.Index = undefined,
    state: S = undefined,
    server: S = undefined,
    i: *island.Island(S, Fake) = undefined,

    fn init(p: *Page, mode: @FieldType(S, "mode")) !void {
        p.* = .{ .arena = .init(testing.allocator) };
        const a = p.arena.allocator();
        p.fake = .{ .a = a };
        p.rt = .init(a, &p.fake);
        p.ix = try .init(a, &cs.Demo.entries);
        p.server = .{ .index = &p.ix, .id = "cs", .mode = mode };
        p.state = p.server;
        const t = try a.create(tree.Tree);
        t.* = .{};
        var h: tree.H = .init(a, t);
        t.root = p.server.view(&h);
        p.fake.server = t;
        p.i = try p.rt.add(S, &p.state, &p.server, "#search");
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

    fn id(p: *Page, name: []const u8, value: ?[]const u8) u32 {
        const t = p.i.current();
        return t.node(t.find(t.root, name, value).?).dom;
    }

    fn has(p: *Page, needle: []const u8) !bool {
        return std.mem.find(u8, try p.shown(), needle) != null;
    }

    fn typeText(p: *Page, s: []const u8) void {
        _ = p.rt.event(0, .{ .kind = .input, .target = p.id("data-ref", "input"), .text = s });
    }

    fn key(p: *Page, k: []const u8) bool {
        return p.rt.event(0, .{ .kind = .keydown, .target = p.id("data-ref", "input"), .text = k });
    }
};

test "typing opens the list; arrows move, Enter follows the link; Escape closes, then clears" {
    var p: Page = undefined;
    try p.init(.link);
    defer p.deinit();
    try testing.expectEqual(@as(u32, 0), p.fake.warnings);
    try testing.expect(try p.has("aria-expanded=\"false\""));
    try testing.expect(try p.has("hidden=\"\""));

    p.typeText("ka");
    try testing.expect(try p.has("aria-expanded=\"true\""));
    try testing.expect(try p.has("aria-activedescendant=\"cs-13\""));
    try testing.expect(try p.has("<li aria-selected=\"true\" id=\"cs-13\" role=\"option\"><a data-ref=\"active\" href=\"#\" tabindex=\"-1\">"));
    try testing.expect(try p.has("<mark>Ka</mark>yn"));
    try testing.expect(p.key("ArrowDown"));
    try testing.expect(try p.has("aria-activedescendant=\"cs-8\""));
    try testing.expectEqual(@as(u32, 1), p.fake.scrolled);
    try testing.expect(p.key("ArrowUp"));
    try testing.expect(p.key("ArrowUp"));
    // Wraps to the last of eight
    try testing.expect(try p.has("aria-activedescendant=\"cs-11\""));
    // Typing is never prevented
    try testing.expect(!p.key("a"));
    try testing.expect(p.key("Enter"));
    try testing.expectEqual(@as(u32, 1), p.fake.clicked);

    try testing.expect(p.key("Escape"));
    try testing.expect(try p.has("aria-expanded=\"false\""));
    try testing.expect(try p.has("value=\"ka\""));
    try testing.expect(p.key("Escape"));
    try testing.expect(try p.has("value=\"\""));
    try testing.expect(!p.key("Escape"));
    // Nothing matches: said so
    p.typeText("zzz");
    try testing.expect(try p.has("No champion by that name"));
    try testing.expect(!try p.has("aria-activedescendant"));
    try testing.expect(!p.key("Enter"));
}

test "focus moving to an option keeps the list; leaving the box closes it, coming back opens it" {
    var p: Page = undefined;
    try p.init(.link);
    defer p.deinit();
    p.typeText("mundo");
    const opt = p.id("data-ref", "active");
    _ = p.rt.event(0, .{ .kind = .focusout, .target = p.id("data-ref", "input"), .related = opt });
    try testing.expect(try p.has("aria-expanded=\"true\""));
    try testing.expect(try p.has("Dr. <mark>Mundo</mark>"));
    _ = p.rt.event(0, .{ .kind = .focusout, .target = opt });
    try testing.expect(try p.has("aria-expanded=\"false\""));
    _ = p.rt.event(0, .{ .kind = .focusin, .target = p.id("data-ref", "input") });
    try testing.expect(try p.has("aria-expanded=\"true\""));
}

test "pick mode: a tap or Enter takes the champion as a chip; clear brings the box back" {
    var p: Page = undefined;
    try p.init(.pick);
    defer p.deinit();
    p.typeText("mf");
    _ = p.rt.event(0, .{ .kind = .click, .target = p.id("data-ref", "active") });
    try testing.expectEqual(@as(?u16, 15), p.state.chosen);
    try testing.expect(try p.has("<span class=\"c-chosen\">"));
    try testing.expect(!try p.has("<input"));
    try testing.expectEqual(p.id("data-ref", "clear"), p.fake.focused);

    _ = p.rt.event(0, .{ .kind = .click, .target = p.id("data-ref", "clear") });
    try testing.expectEqual(@as(?u16, null), p.state.chosen);
    try testing.expectEqual(p.id("data-ref", "input"), p.fake.focused);
    try testing.expect(try p.has("value=\"\""));

    p.typeText("j4");
    try testing.expect(p.key("Enter"));
    try testing.expectEqual(@as(?u16, 4), p.state.chosen);
    try testing.expectEqual(@as(u32, 0), p.fake.clicked);
}

test "filter mode: no list, the host reads q" {
    var p: Page = undefined;
    try p.init(.filter);
    defer p.deinit();
    p.typeText("ahri");
    try testing.expectEqualStrings("ahri", p.state.q.slice());
    try testing.expect(!try p.has("<ul"));
    try testing.expect(!try p.has("combobox"));
    try testing.expect(p.key("Escape"));
    try testing.expectEqualStrings("", p.state.q.slice());
}
