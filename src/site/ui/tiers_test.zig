//! The champions board on the fake DOM: the server's render, hydration with a URL's
//! state, sorting, roles, search, the Games floor, off-role rows and the movers, each
//! patch equal to a fresh render
const std = @import("std");
const tree = @import("tree.zig");
const diff = @import("diff.zig");
const html = @import("html.zig");
const check = @import("check.zig");
const island = @import("island.zig");
const tiers = @import("tiers.zig");
const Fake = @import("fakedom.zig").Fake;
const testing = std.testing;

const champs = [_]tiers.Champ{
    .{ .name = "Ahri", .key = "Ahri", .slug = "ahri", .banned = 300 },
    .{ .name = "Kai'Sa", .key = "Kaisa", .slug = "kaisa", .banned = 900 },
    .{ .name = "Zed", .key = "Zed", .slug = "zed", .banned = 2000 },
    .{ .name = "Lux", .key = "Lux", .slug = "lux", .banned = 50 },
};

fn row(champ: u16, role: tiers.Role, games: u32, wins: u32, share: f32, patch: ?tiers.Patch) tiers.Row {
    return .{ .champ = champ, .role = role, .games = games, .wins = wins, .share = share, .spread = null, .patch = patch };
}

// By win rate, as the server orders them. Lux top: under 500 games; Zed top: off-role
const rows = [_]tiers.Row{
    row(1, .bottom, 900, 480, 0.95, .{ .prev = .{ 2000, 960 }, .cur = .{ 900, 480 }, .clear = true }),
    row(0, .middle, 1600, 830, 0.9, .{ .prev = .{ 3000, 1530 }, .cur = .{ 1600, 830 }, .clear = false }),
    row(2, .middle, 1800, 900, 0.8, .{ .prev = .{ 3000, 1590 }, .cur = .{ 1800, 900 }, .clear = true }),
    row(3, .utility, 2000, 980, 0.9, null),
    row(3, .top, 40, 19, 0.1, null),
    row(2, .top, 700, 320, 0.08, null),
};

const data: tiers.Data = .{
    .games = 400_000,
    .min = 1,
    .spread_min_games = 10,
    .cur_patch = "16.21",
    .prev_patch = "16.20",
    .region_in = "in EUW",
    .ddragon = "15.13.1",
    .query = "",
    .champs = &champs,
    .rows = &rows,
};

const Page = struct {
    arena: std.heap.ArenaAllocator,
    fake: Fake = undefined,
    rt: island.Runtime(Fake) = undefined,
    state: tiers.Tiers = undefined,
    server: tiers.Tiers = undefined,
    i: *island.Island(tiers.Tiers, Fake) = undefined,

    fn init(p: *Page, fragment: []const u8, role: ?tiers.Role) !void {
        p.* = .{ .arena = .init(testing.allocator) };
        const a = p.arena.allocator();
        p.fake = .{ .a = a };
        try p.fake.fragment.appendSlice(a, fragment);
        p.rt = .init(a, &p.fake);
        p.server = .init(&data, try tiers.prepare(a, &data, ""), role);
        p.state = p.server;
        const t = try a.create(tree.Tree);
        t.* = .{};
        var h: tree.H = .init(a, t);
        t.root = p.server.view(&h);
        p.fake.server = t;
        p.i = try p.rt.add(tiers.Tiers, &p.state, &p.server, "[data-island=tiers]");
    }

    /// The page's text as a reader sees it, and a check the DOM equals a fresh render
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
        const a = p.arena.allocator();
        var out: std.ArrayList(u8) = .empty;
        var it = std.mem.splitSequence(u8, page[std.mem.find(u8, page, "<tbody>").?..], "class=\"nm\">");
        _ = it.next();
        while (it.next()) |rest| {
            if (out.items.len > 0) try out.append(a, ',');
            try out.appendSlice(a, rest[0..std.mem.findScalar(u8, rest, '<').?]);
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

    fn deinit(p: *Page) void {
        p.arena.deinit();
    }
};

test "the server renders All over 1.5k games, off-role behind the chip" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var s: tiers.Tiers = .init(&data, try tiers.prepare(a, &data, "../"), null);
    var t: tree.Tree = .{};
    var h: tree.H = .init(a, &t);
    t.root = s.view(&h);
    var w: std.Io.Writer.Allocating = .init(a);
    try html.write(&t, t.root, &w.writer);
    const page = w.written();
    // Kai'Sa under 1.5k games
    try testing.expectEqual(@as(usize, 3), std.mem.count(u8, page, "class=\"nm\""));
    try testing.expect(std.mem.find(u8, page, "<p class=\"sub\">400,000 games in EUW · 16.21 vs 16.20</p>") != null);
    try testing.expect(std.mem.find(u8, page, "href=\"../champion/ahri.html#role=mid\"") != null);
    try testing.expect(std.mem.find(u8, page, "Moved in 16.21") != null);
    try testing.expect(std.mem.find(u8, page, "<linearGradient id=\"c-violin-g\"") != null);
    const report = try check.run(a, &t, .{ .words = .off, .answer = .off });
    for (report.findings.items) |f| std.debug.print("{s}\n", .{f.msg});
    try testing.expectEqual(@as(usize, 0), report.findings.items.len);
}

test "hydration takes the URL's state; sorting pushes history; back restores" {
    var p: Page = undefined;
    try p.init("#sort=0&desc=0&min=0", null);
    defer p.deinit();
    try testing.expectEqual(@as(u32, 0), p.fake.warnings);
    try testing.expectEqualStrings("Ahri,Kai'Sa,Lux,Zed", try p.names());
    _ = p.rt.event(0, .{ .kind = .click, .target = p.by(.th, "Games") });
    try testing.expectEqualStrings("#sort=6&min=0", p.fake.fragment.items);
    try testing.expectEqualStrings("Lux,Zed,Ahri,Kai'Sa", try p.names());
    p.fake.fragment.clearRetainingCapacity();
    p.rt.popstate();
    try testing.expectEqualStrings("Ahri,Zed,Lux", try p.names());
}

test "a role in place; the role page's own role keeps the URL clean" {
    var p: Page = undefined;
    try p.init("", .top);
    defer p.deinit();
    try testing.expectEqualStrings("", try p.names());
    _ = p.rt.event(0, .{ .kind = .click, .target = p.by(.button, "All") });
    try testing.expectEqualStrings("#role=all", p.fake.fragment.items);
    try testing.expectEqualStrings("Ahri,Zed,Lux", try p.names());
    _ = p.rt.event(0, .{ .kind = .click, .target = p.id("aria-label", "Mid") });
    try testing.expectEqualStrings("#role=mid", p.fake.fragment.items);
    try testing.expectEqualStrings("Ahri,Zed", try p.names());
}

test "the floor, the off-role chip, search and a mover" {
    var p: Page = undefined;
    try p.init("#role=top&min=0", null);
    defer p.deinit();
    // Lux top: under 500 games; Zed top: off-role, behind the chip
    try testing.expectEqualStrings("", try p.names());
    _ = p.rt.event(0, .{ .kind = .click, .target = p.by(.button, "+1 off-role") });
    try testing.expectEqualStrings("Zed", try p.names());
    _ = p.rt.event(0, .{ .kind = .input, .target = p.id("type", "search"), .text = "kai sa" });
    try testing.expectEqualStrings("", try p.names());
    _ = p.rt.event(0, .{ .kind = .click, .target = p.by(.button, "All") });
    try testing.expectEqualStrings("Kai'Sa", try p.names());
    _ = p.rt.event(0, .{ .kind = .input, .target = p.id("type", "search"), .text = "" });
    // Zed mid fell clearly: its chip searches for it
    _ = p.rt.event(0, .{ .kind = .click, .target = p.id("aria-label", "Zed") });
    try testing.expectEqualStrings("Zed,Zed", try p.names());
}
