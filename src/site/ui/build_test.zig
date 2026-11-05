//! BuildPanel on the fake DOM (build_demo.zig's Darius): a cell opens from the URL or its
//! "N more", closes by "fewer", Escape or Back; the best row and Highest WR; RuneTree's
//! pages, runes and Every tree. Each patch equal to a fresh render
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
        try p.initData(fragment, &demo.darius);
    }

    fn initData(p: *Page, fragment: []const u8, data: *const bp.Data) !void {
        p.* = .{ .arena = .init(testing.allocator) };
        const a = p.arena.allocator();
        p.fake = .{ .a = a };
        try p.fake.fragment.appendSlice(a, fragment);
        p.rt = .init(a, &p.fake);
        try p.server.init(a, data);
        try p.state.init(a, data);
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

/// The markup of cell `k` (up to the next cell)
fn cellOf(page: []const u8, k: []const u8) []const u8 {
    var buf: [64]u8 = undefined;
    const tag = std.fmt.bufPrint(&buf, "data-k=\"{s}\"", .{k}) catch unreachable;
    const at = std.mem.find(u8, page, tag) orelse return "";
    const rest = page[at + tag.len ..];
    return rest[0 .. std.mem.find(u8, rest, "class=\"slot\"") orelse rest.len];
}

/// Where each of `names` first shows in `s`, in order
fn inOrder(s: []const u8, names: []const []const u8) bool {
    var last: usize = 0;
    for (names) |n| {
        const at = std.mem.find(u8, s, n) orelse return false;
        if (at < last) return false;
        last = at;
    }
    return true;
}
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
    try testing.expect(std.mem.startsWith(u8, try p.firstName(), "Dead Man"));
    p.deinit();

    try p.init("#slot=skill_path");
    defer p.deinit();
    try testing.expect(!try p.has("data-open"));
    try testing.expectEqual(@as(?bp.Kind, null), p.state.open);
}

test "the best win rate on 400+ games is marked, a 4th row when not in the top 3" {
    var p: Page = undefined;
    try p.init("");
    defer p.deinit();
    const item4 = cellOf(try p.shown(), "item4");
    try testing.expectEqual(4, std.mem.count(u8, item4, "<tr"));
    try testing.expect(inOrder(item4, &.{ "Force of Nature", "Sterak", "Death's Dance", "Dead Man", ">best<" }));
    // Exhaust Flash, in the top 3: no 4th row
    const spells = cellOf(try p.shown(), "spells");
    try testing.expectEqual(3, std.mem.count(u8, spells, "<tr"));
    try testing.expect(inOrder(spells, &.{ "Exhaust", ">best<" }));
    // Item 6: none on 400 games, no mark
    try testing.expect(std.mem.find(u8, cellOf(try p.shown(), "item6"), ">best<") == null);
}

test "Highest WR sorts every cell by win rate, under 400 games after; in the URL" {
    var p: Page = undefined;
    try p.init("");
    defer p.deinit();
    p.click(p.button("Highest WR"));
    try testing.expectEqualStrings("#order=win", p.fake.fragment.items);
    const item4 = cellOf(try p.shown(), "item4");
    try testing.expectEqual(3, std.mem.count(u8, item4, "<tr"));
    try testing.expect(inOrder(item4, &.{ "Dead Man", "Sterak", "Death's Dance" }));
    // Item 5: Sterak's 401 games first; Fort of Nature's 59.1 on 252 out of the order
    try testing.expect(inOrder(cellOf(try p.shown(), "item5"), &.{ "Sterak", "Randuin", "Death's Dance" }));
    // The open cell sorts by Won too
    p.click(p.nth("data-ref", "all-item4", 0));
    try testing.expect(std.mem.startsWith(u8, try p.firstName(), "Dead Man"));
    try testing.expectEqualStrings("#slot=item4&order=win", p.fake.fragment.items);
    p.click(p.button("Most picked"));
    try testing.expect(std.mem.startsWith(u8, try p.firstName(), "Force of Nature"));
    p.deinit();

    try p.init("#order=win");
    try testing.expectEqual(@as(u32, 0), p.fake.warnings);
    try testing.expect(inOrder(cellOf(try p.shown(), "item4"), &.{ "Dead Man", "Sterak" }));
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

test "a page whose keystone has a build locks on tap: every cell its players', a chip unlocks" {
    var p: Page = undefined;
    try p.initData("", &demo.darius_locked);
    defer p.deinit();
    // Arcane Comet's page has no build of its own: it only lights
    p.click(p.nth("class", "ks", 0));
    try testing.expect(!try p.has("data-lock"));
    try testing.expectEqualStrings("", p.fake.fragment.items);
    // Conqueror's locks: Treads lead Boots, no boots named, the chip with its players
    p.click(p.nth("class", "ks", 1));
    try testing.expect(try p.has("data-lock"));
    try testing.expectEqualStrings("#k=8010", p.fake.fragment.items);
    const boots = cellOf(try p.shown(), "boots");
    try testing.expect(inOrder(boots, &.{ "Mercury", "Plated", "No boots</span>" }));
    try testing.expect(try p.has("11,053 games"));
    try testing.expect(!try p.has("data-k=\"core\""));
    // The × unlocks: every player's again
    p.click(p.nth("class", "c-chip", 0));
    try testing.expect(!try p.has("data-lock"));
    try testing.expect(inOrder(cellOf(try p.shown(), "boots"), &.{ "Plated", "Mercury" }));
    try testing.expectEqualStrings("#", p.fake.fragment.items);
    // A second tap on the locked page unlocks it too
    p.click(p.nth("class", "ks", 2));
    try testing.expect(try p.has("data-lock"));
    p.click(p.nth("class", "ks", 2));
    try testing.expect(!try p.has("data-lock"));
    p.deinit();

    try p.initData("#k=8010", &demo.darius_locked);
    try testing.expectEqual(@as(u32, 0), p.fake.warnings);
    try testing.expect(try p.has("data-lock"));
    try testing.expect(inOrder(cellOf(try p.shown(), "boots"), &.{ "Mercury", "Plated" }));
}

test "a lock's answer keeps the page, the tapped rune, Every tree and the open cell; the base build's cells stay" {
    var p: Page = undefined;
    try p.init("#slot=item4");
    defer p.deinit();
    // Sorcery's page first: its trees draw primary then secondary, not in data order
    const html = try p.shown();
    try testing.expect(std.mem.find(u8, html, "Sorcery</h4>").? < std.mem.find(u8, html, "Precision</h4>").?);
    p.click(p.nth("class", "ks", 2));
    p.click(p.nth("class", "rune", 3));
    p.click(p.button("Every tree"));

    const a = p.arena.allocator();
    var d = demo.darius;
    var slots: std.ArrayList(bp.Slot) = .empty;
    for (d.slots) |s| if (s.kind != .boots) try slots.append(a, s);
    d.slots = slots.items;
    var ans: P = undefined;
    try ans.init(a, &d);
    ans.frame = p.state.kinds();
    ans.keep(&p.state);
    try testing.expectEqual(p.state.runes.page, ans.runes.page);
    try testing.expectEqual(p.state.runes.rune, ans.runes.rune);
    try testing.expect(ans.runes.all);
    try testing.expectEqual(bp.Kind.item4, ans.open.?);

    const t = try a.create(tree.Tree);
    t.* = .{};
    var h: tree.H = .init(a, t);
    t.root = ans.view(&h);
    var fake: Fake = .{ .a = a };
    var w: std.Io.Writer.Allocating = .init(a);
    try fake.html(fake.mirror(t, t.root), &w.writer);
    const boots = cellOf(w.written(), "boots");
    try testing.expect(std.mem.find(u8, boots, "<p class=\"nil\">—</p>") != null);
    try testing.expect(std.mem.find(u8, boots, "<table") == null);
}
