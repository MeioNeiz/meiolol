//! The island runtime on the fake DOM: hydration, keyed patches equal to a fresh render,
//! focus through moves, URL state shared by two islands, Back
const std = @import("std");
const tree = @import("tree.zig");
const diff = @import("diff.zig");
const url = @import("url.zig");
const island = @import("island.zig");
const Fake = @import("fakedom.zig").Fake;
const testing = std.testing;

const Item = struct { name: []const u8, score: u32 };

const items = [_]Item{
    .{ .name = "Ahri", .score = 52 },   .{ .name = "Zed", .score = 49 },  .{ .name = "Lux", .score = 51 },
    .{ .name = "Kai'Sa", .score = 50 }, .{ .name = "Jinx", .score = 53 }, .{ .name = "Thresh", .score = 48 },
};

const List = struct {
    sort: Key = .score,
    q: url.Str(16) = .{},
    open: ?u8 = null,

    const Key = enum { score, name };
    pub const Msg = union(enum) { sort: Key, search, open: u8 };
    pub const Url = struct { sort: Key = .score, q: url.Str(16) = .{} };

    pub fn toUrl(l: *const List) Url {
        return .{ .sort = l.sort, .q = l.q };
    }
    pub fn fromUrl(l: *List, u: Url) void {
        l.sort = u.sort;
        l.q = u.q;
    }

    pub fn update(l: *List, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .sort => |k| {
                l.sort = k;
                ev.push = true;
            },
            .search => l.q.set(ev.text),
            .open => |i| {
                l.open = if (l.open == i) null else i;
                ev.after = .{ .op = .focus, .ref = "detail" };
            },
        }
    }

    fn order(l: *const List, out: *[items.len]u8) []u8 {
        var n: usize = 0;
        for (items, 0..) |x, i| {
            if (std.ascii.findIgnoreCase(x.name, l.q.slice()) == null) continue;
            out[n] = @intCast(i);
            n += 1;
        }
        const ctx: struct {
            k: Key,
            fn lt(c: @This(), a: u8, b: u8) bool {
                return switch (c.k) {
                    .score => items[a].score > items[b].score,
                    .name => std.mem.lessThan(u8, items[a].name, items[b].name),
                };
            }
        } = .{ .k = l.sort };
        std.sort.heap(u8, out[0..n], ctx, @TypeOf(ctx).lt);
        return out[0..n];
    }

    pub fn view(l: *List, h: *tree.H) tree.N {
        var buf: [items.len]u8 = undefined;
        var rows = h.list();
        for (l.order(&buf)) |i| {
            rows.add(h.li(.{ .key = i, .on_click = h.on(l, .{ .open = i }) }, .{
                h.button(.{ .data_row = items[i].name }, .{items[i].name}),
                " ",
                items[i].score,
            }));
            if (l.open == i) rows.add(h.li(.{ .key = @as(u32, i) + 1000, .data_ref = "detail", .tabindex = -1 }, .{"more"}));
        }
        return h.div(.{ .class = "ui" }, .{
            h.button(.{ .on_click = h.on(l, .{ .sort = .name }), .aria_pressed = l.sort == .name }, .{"Name"}),
            h.input(.{ .value = l.q.slice(), .on_input = h.on(l, .search) }),
            h.ul(.{}, .{rows.done()}),
        });
    }
};

const Page = struct {
    arena: std.heap.ArenaAllocator,
    fake: Fake = undefined,
    rt: island.Runtime(Fake) = undefined,

    fn init(p: *Page, fragment: []const u8) void {
        p.* = .{ .arena = .init(testing.allocator) };
        const a = p.arena.allocator();
        p.fake = .{ .a = a };
        p.fake.fragment.appendSlice(a, fragment) catch unreachable;
        p.rt = .init(a, &p.fake);
    }

    /// The server's HTML for `server`, then the island adopting it
    fn add(p: *Page, comptime T: type, state: *T, server: *T) *island.Island(T, Fake) {
        const t = p.arena.allocator().create(tree.Tree) catch unreachable;
        t.* = .{};
        var h: tree.H = .init(p.arena.allocator(), t);
        t.root = server.view(&h);
        p.fake.server = t;
        return p.rt.add(T, state, server, "[data-island]") catch unreachable;
    }

    /// The fake DOM equals a fresh render of the island's current tree
    fn matches(p: *Page, i: anytype) !void {
        const a = p.arena.allocator();
        var got: std.Io.Writer.Allocating = .init(a);
        try p.fake.html(p.fake.roots.items[i.slot], &got.writer);
        var fresh: Fake = .{ .a = a };
        var t = i.current().*;
        t.nodes = try t.nodes.clone(a);
        var ids: diff.Ids = .{};
        number(&t, t.root, &ids);
        var want: std.Io.Writer.Allocating = .init(a);
        try fresh.html(fresh.mirror(&t, t.root), &want.writer);
        try testing.expectEqualStrings(want.written(), got.written());
    }

    fn number(t: *tree.Tree, n: tree.N, ids: *diff.Ids) void {
        t.node(n).dom = ids.take();
        for (t.kidsOf(n)) |k| number(t, k, ids);
    }

    /// The DOM id of the first node whose `name` attribute is `value`
    fn id(i: anytype, name: []const u8, value: ?[]const u8) u32 {
        const t = i.current();
        return t.node(t.find(t.root, name, value).?).dom;
    }
};

test "hydration adopts the server's nodes, then the URL's state is patched in" {
    var p: Page = undefined;
    p.init("#sort=name&q=a");
    defer p.arena.deinit();
    var state: List = .{};
    var server: List = .{};
    const i = p.add(List, &state, &server);
    try testing.expectEqual(@as(u32, 0), p.fake.warnings);
    try testing.expectEqual(List.Key.name, state.sort);
    try testing.expectEqualStrings("a", state.q.slice());
    // Rows were moved and removed, none made: the server's nodes are kept
    try testing.expectEqual(@as(u32, 0), p.fake.creates - countNodes(p.fake.server.?));
    try p.matches(i);
    // Listening for exactly the kinds the tree handles
    try testing.expectEqual(@as(u16, 1 << @backingInt(tree.Ev.click) | 1 << @backingInt(tree.Ev.input)), p.fake.listened);
}

fn countNodes(t: *const tree.Tree) u32 {
    return @intCast(t.nodes.items.len);
}

test "events patch the DOM to what a fresh render gives; sort pushes, typing replaces" {
    var p: Page = undefined;
    p.init("");
    defer p.arena.deinit();
    var state: List = .{};
    var server: List = .{};
    const i = p.add(List, &state, &server);
    const creates = p.fake.creates;
    // A click on a row's button bubbles to the row
    _ = p.rt.event(0, .{ .kind = .click, .target = Page.id(i, "data-row", "Lux") });
    try testing.expectEqual(@as(?u8, 2), state.open);
    try p.matches(i);
    // The detail row was focused after the patch (ev.after)
    try testing.expectEqual(Page.id(i, "data-ref", "detail"), p.fake.focused);
    _ = p.rt.event(0, .{ .kind = .click, .target = Page.id(i, "aria-pressed", null) });
    try p.matches(i);
    try testing.expectEqual(@as(u32, 1), p.fake.pushes);
    try testing.expectEqualStrings("#sort=name", p.fake.fragment.items);
    // The sort moved rows; only the detail row was ever made
    try testing.expectEqual(creates + 2, p.fake.creates);
    try testing.expect(p.fake.moves > 0);
    _ = p.rt.event(0, .{ .kind = .input, .target = Page.id(i, "value", ""), .text = "i" });
    try p.matches(i);
    try testing.expectEqual(@as(u32, 1), p.fake.replaces);
    try testing.expectEqualStrings("#sort=name&q=i", p.fake.fragment.items);
    // A removed row's nodes are released
    try testing.expect(p.fake.forgotten > 0);
}

test "focus inside a moved row survives the move" {
    var p: Page = undefined;
    p.init("");
    defer p.arena.deinit();
    var state: List = .{};
    var server: List = .{};
    const i = p.add(List, &state, &server);
    const zed = Page.id(i, "data-row", "Zed");
    p.fake.focus(zed);
    _ = p.rt.event(0, .{ .kind = .click, .target = Page.id(i, "aria-pressed", null) });
    try testing.expect(p.fake.moves > 0);
    try testing.expectEqual(zed, p.fake.focused);
}

const Toggle = struct {
    on: bool = false,
    pub const Msg = union(enum) { flip };
    pub const Url = struct { on: bool = false };
    pub fn toUrl(t: *const Toggle) Url {
        return .{ .on = t.on };
    }
    pub fn fromUrl(t: *Toggle, u: Url) void {
        t.on = u.on;
    }
    pub fn update(t: *Toggle, _: Msg, ev: *tree.Event) void {
        t.on = !t.on;
        ev.push = true;
    }
    pub fn view(t: *Toggle, h: *tree.H) tree.N {
        return h.button(.{ .aria_pressed = t.on, .on_click = h.on(t, .flip) }, .{"On"});
    }
};

test "two islands share the fragment; Back restores both" {
    var p: Page = undefined;
    p.init("#q=a&on=1");
    defer p.arena.deinit();
    var list: List = .{};
    var list_server: List = .{};
    const li = p.add(List, &list, &list_server);
    var toggle: Toggle = .{};
    var toggle_server: Toggle = .{};
    const ti = p.add(Toggle, &toggle, &toggle_server);
    try testing.expect(toggle.on);
    try testing.expectEqualStrings("a", list.q.slice());
    // Island ids don't collide
    try testing.expect(Page.id(ti, "aria-pressed", null) >= li.by_dom.items.len - 1);
    _ = p.rt.event(1, .{ .kind = .click, .target = Page.id(ti, "aria-pressed", null) });
    try testing.expectEqualStrings("#q=a", p.fake.fragment.items);
    _ = p.rt.event(0, .{ .kind = .click, .target = Page.id(li, "aria-pressed", null) });
    try testing.expectEqualStrings("#sort=name&q=a", p.fake.fragment.items);
    // Back: the browser shows the earlier fragment, both islands follow
    p.fake.fragment.clearRetainingCapacity();
    try p.fake.fragment.appendSlice(p.arena.allocator(), "#q=a&on=1");
    p.rt.popstate();
    try testing.expect(toggle.on);
    try testing.expectEqual(List.Key.score, list.sort);
    try p.matches(li);
}

test "another runtime's keys in the fragment are kept as they are" {
    var p: Page = undefined;
    p.init("#by=gold&q=a&x=%41");
    defer p.arena.deinit();
    var state: List = .{};
    var server: List = .{};
    const i = p.add(List, &state, &server);
    _ = p.rt.event(0, .{ .kind = .click, .target = Page.id(i, "aria-pressed", null) });
    try testing.expectEqualStrings("#by=gold&x=%41&sort=name&q=a", p.fake.fragment.items);
}

test "a server render that differs from the tree is reported" {
    var p: Page = undefined;
    p.init("");
    defer p.arena.deinit();
    var state: List = .{};
    var server: List = .{};
    var other: List = .{ .open = 1 };
    const t = p.arena.allocator().create(tree.Tree) catch unreachable;
    t.* = .{};
    var h: tree.H = .init(p.arena.allocator(), t);
    t.root = other.view(&h);
    p.fake.server = t;
    _ = try p.rt.add(List, &state, &server, "[data-island]");
    try testing.expectEqual(@as(u32, 1), p.fake.warnings);
}

const Links = struct {
    jumps: u8 = 0,

    pub const Msg = union(enum) { jump, row };
    pub const Url = struct {};

    pub fn toUrl(_: *const Links) Url {
        return .{};
    }
    pub fn fromUrl(_: *Links, _: Url) void {}

    pub fn update(l: *Links, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .jump => {
                l.jumps += 1;
                ev.handled = true;
                ev.after = .{ .op = .jump, .ref = "matchups" };
            },
            .row => l.jumps += 100,
        }
    }

    pub fn view(l: *Links, h: *tree.H) tree.N {
        return h.div(.{ .class = "ui", .on_click = h.on(l, .row) }, .{
            h.a(.{ .href = "#matchups", .data_k = "own", .on_click = h.on(l, .jump) }, .{"Matchups"}),
            h.a(.{ .href = "other.html", .data_k = "plain" }, .{"Other"}),
        });
    }
};

test "a link's click is the browser's unless the link handles it" {
    var p: Page = undefined;
    p.init("");
    defer p.arena.deinit();
    var state: Links = .{};
    var server: Links = .{};
    const i = p.add(Links, &state, &server);
    try testing.expect(p.rt.event(0, .{ .kind = .click, .target = Page.id(i, "data-k", "own") }));
    try testing.expectEqual(@as(u8, 1), state.jumps);
    try testing.expectEqual(@as(u32, 1), p.fake.scrolled);
    try testing.expect(!p.rt.event(0, .{ .kind = .click, .target = Page.id(i, "data-k", "plain") }));
    try testing.expectEqual(@as(u8, 1), state.jumps);
}

const Answer = struct {
    done: bool = false,
    pub const Msg = union(enum) { answer };
    pub fn update(a: *Answer, _: Msg, _: *tree.Event) void {
        a.done = true;
    }
    pub fn view(a: *Answer, h: *tree.H) tree.N {
        return h.div(.{ .data_island = "a" }, .{if (a.done) h.p(.{}, .{"Done"}) else h.button(.{ .on_click = h.on(a, .answer) }, .{"Blue"})});
    }
};

test "a focused node removed: its id may go to a text node, which focus would throw on" {
    var p: Page = undefined;
    p.init("");
    defer p.arena.deinit();
    var state: Answer = .{};
    var server: Answer = .{};
    const i = p.add(Answer, &state, &server);
    const blue = Page.id(i, "data-island", null) + 1;
    p.fake.focus(blue);
    _ = p.rt.event(0, .{ .kind = .click, .target = blue });
    try testing.expect(state.done);
    if (p.fake.nodes.get(p.fake.focused)) |n| try testing.expect(!std.mem.eql(u8, n.tag, "#text"));
}
