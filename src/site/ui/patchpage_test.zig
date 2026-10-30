//! The patch page on the fake DOM: the server's render, hydration with a URL's state,
//! the chips, the counts, the role and a row's detail, each patch equal to a fresh render
const std = @import("std");
const tree = @import("tree.zig");
const diff = @import("diff.zig");
const html = @import("html.zig");
const check = @import("check.zig");
const island = @import("island.zig");
const pp = @import("patchpage.zig");
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
        p.server = .init(&pp.demo, try pp.prepare(a, &pp.demo, "/"));
        p.state = p.server;
        try p.state.own(a);
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

    /// The champion table's names in row order
    fn names(p: *Page) ![]const u8 {
        const page = try p.shown();
        const a = p.arena.allocator();
        const start = std.mem.find(u8, page, "<tbody>") orelse return "";
        const body = page[start .. std.mem.find(u8, page[start..], "</tbody>").? + start];
        var out: std.ArrayList(u8) = .empty;
        var it = std.mem.splitSequence(u8, body, "<a class=\"who\"");
        _ = it.next();
        while (it.next()) |rest| {
            const nm = rest[std.mem.find(u8, rest, "class=\"nm\">").? + "class=\"nm\">".len ..];
            if (out.items.len > 0) try out.append(a, ',');
            try out.appendSlice(a, nm[0..std.mem.findScalar(u8, nm, '<').?]);
        }
        return out.items;
    }

    fn id(p: *Page, name: []const u8, value: ?[]const u8) u32 {
        const t = p.i.current();
        return t.node(t.find(t.root, name, value).?).dom;
    }

    /// The first `tag` with the text `label` somewhere inside
    fn by(p: *Page, tag: tree.Tag, label: []const u8) u32 {
        const t = p.i.current();
        for (t.nodes.items, 0..) |n, k| if (n.tag == tag and has(t, @fromBackingInt(@intCast(k)), label)) return n.dom;
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

test "the server renders every listed row by change, the chips' counts and Riot's lines" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var s: pp.Page = .init(&pp.demo, try pp.prepare(a, &pp.demo, "/"));
    var t: tree.Tree = .{};
    var h: tree.H = .init(a, &t);
    t.root = s.view(&h);
    var w: std.Io.Writer.Allocating = .init(a);
    try html.write(&t, t.root, &w.writer);
    const page = w.written();
    try testing.expect(std.mem.find(u8, page, "<h1>Patch 16.21 vs 16.20</h1>") != null);
    try testing.expect(std.mem.find(u8, page, "href=\"/champions/darius/top?period=patch\"") != null);
    // The kit chips' labels are item and rune names ("Press the Attack"), not wording
    const report = try check.run(a, &t, .{ .words = .off, .answer = .off, .label = .off });
    for (report.findings.items) |f| std.debug.print("{s}\n", .{f.msg});
    try testing.expectEqual(@as(usize, 0), report.findings.items.len);
}

test "items and runes over the table: a chip opens its lines and who uses it most" {
    var p: Page = undefined;
    try p.init("");
    defer p.deinit();
    var page = try p.shown();
    try testing.expect(std.mem.find(u8, page, "PressTheAttack.png") != null);
    try testing.expect(std.mem.find(u8, page, "Bought most by") == null);
    // Before the table: never under a long one
    try testing.expect(std.mem.find(u8, page, "Bastionbreaker").? < std.mem.find(u8, page, "<table").?);
    p.click(p.by(.button, "Bastionbreaker"));
    page = try p.shown();
    try testing.expect(std.mem.find(u8, page, "Bought most by") != null);
    try testing.expect(std.mem.find(u8, page, "href=\"/champions/missfortune/bot?period=patch\"") != null);
    // The URL keeps the filters only
    try testing.expectEqualStrings("", p.fake.fragment.items);
    p.click(p.by(.button, "Bastionbreaker"));
    try testing.expect(std.mem.find(u8, try p.shown(), "Bought most by") == null);
}

test "matchups that moved: a column, the row's links" {
    var p: Page = undefined;
    try p.init("");
    defer p.deinit();
    p.click(p.by(.tr, "Miss Fortune"));
    const page = try p.shown();
    try testing.expect(std.mem.find(u8, page, "href=\"/matchups/bot/missfortune-vs-tristana?period=patch\"") != null);
    try testing.expect(std.mem.find(u8, page, "gold +40 → +209") != null);
    try testing.expect(std.mem.find(u8, page, "Jinx") != null);
}

test "chips: moved and Riot's by default; each toggles; All shows every row" {
    var p: Page = undefined;
    try p.init("");
    defer p.deinit();
    try testing.expectEqual(@as(u32, 0), p.fake.warnings);
    try testing.expectEqualStrings("Darius,Miss Fortune,Orianna,Jinx,Tristana,Viktor", try p.names());
    p.click(p.by(.button, "Riot changed"));
    try testing.expectEqualStrings("#riot=0", p.fake.fragment.items);
    // Orianna: changed by Riot, nothing moved clearly
    try testing.expectEqualStrings("Darius,Miss Fortune,Jinx,Tristana,Viktor", try p.names());
    p.click(p.by(.button, "Moved clearly"));
    p.click(p.by(.button, "Riot changed"));
    try testing.expectEqualStrings("Darius,Orianna,Jinx,Viktor", try p.names());
    p.click(p.by(.button, "All"));
    try testing.expectEqualStrings("#moved=0&riot=0", p.fake.fragment.items);
    try testing.expectEqualStrings("Darius,Miss Fortune,Orianna,Jinx,Tristana,Viktor", try p.names());
    p.fake.fragment.clearRetainingCapacity();
    p.rt.popstate();
    try testing.expectEqualStrings("Darius,Miss Fortune,Orianna,Jinx,Tristana,Viktor", try p.names());
}

test "the chips count the role's rows; the role in place; the URL restores both" {
    var p: Page = undefined;
    try p.init("");
    defer p.deinit();
    try testing.expectEqual(@as(u32, 0), p.fake.warnings);
    // Moved clearly shows 5 rows: 2 up, 2 down, 1 by its lane or matchups only
    try testing.expect(std.mem.find(u8, try p.shown(), "▲2") != null);
    try testing.expect(std.mem.find(u8, try p.shown(), "▼2") != null);
    try testing.expect(std.mem.find(u8, try p.shown(), " +1</span>") != null);
    try testing.expect(std.mem.find(u8, try p.shown(), "aria-label=\"Moved clearly: win rate 2 up, 2 down; 1 more in lane or matchups\"") != null);
    // Riot changed counts rows, as it filters them
    try testing.expect(std.mem.find(u8, try p.shown(), "Riot changed<span class=\"n\">4</span>") != null);
    p.click(p.id("aria-label", "Bot"));
    try testing.expectEqualStrings("#role=bot", p.fake.fragment.items);
    try testing.expect(std.mem.find(u8, try p.shown(), "▼1") != null);
    p.click(p.by(.button, "Moved clearly"));
    try testing.expectEqualStrings("#role=bot&moved=0", p.fake.fragment.items);
    try testing.expectEqualStrings("Jinx", try p.names());
}

test "a row opens Riot's lines and its matchup moves" {
    var p: Page = undefined;
    try p.init("");
    defer p.deinit();
    p.click(p.by(.tr, "Darius"));
    const page = try p.shown();
    try testing.expect(std.mem.find(u8, page, "Decimate cooldown") != null);
    try testing.expect(std.mem.find(u8, page, "Won 48.7% of 23,166 → 51.3% of 6,678") != null);
    try testing.expect(std.mem.find(u8, page, "Darius on 16.21 ›") != null);
}

test "an older pair's data: ‹ › and finished through the data file, games without so far" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var d = pp.demo;
    d.older = .{ .cur = "16.20", .prev = "16.19", .href = "/patch/16-20" };
    d.newer = .{ .cur = "16.22", .prev = "16.21", .href = "/patch" };
    d.finished = true;
    var bytes: std.ArrayList(u8) = .empty;
    try @import("data.zig").encode(a, pp.Data, d, &bytes);
    const got = try @import("data.zig").decode(a, pp.Data, bytes.items);
    try testing.expectEqualDeep(d.older, got.older);
    try testing.expectEqualDeep(d.newer, got.newer);
    try testing.expect(got.finished);
    var p: pp.Page = .init(&got, try pp.prepare(a, &got, ""));
    // The first row's Change tip open
    p.table.tip = 4;
    var t: tree.Tree = .{};
    var h: tree.H = .init(a, &t);
    t.root = p.view(&h);
    var out: std.Io.Writer.Allocating = .init(a);
    try html.write(&t, t.root, &out.writer);
    const s = out.written();
    try testing.expect(std.mem.find(u8, s, "href=\"/patch/16-20\"") != null);
    try testing.expect(std.mem.find(u8, s, "href=\"/patch\"") != null);
    try testing.expect(std.mem.find(u8, s, "so far") == null);
    try testing.expect(std.mem.find(u8, s, "games on 16.21.") != null);
}
