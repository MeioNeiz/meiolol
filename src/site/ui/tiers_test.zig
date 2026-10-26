//! The champions table island on the fake DOM: the server's render, hydration with a
//! URL's state, sorting, search and minimums, each patch equal to a fresh render
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

fn row(champ: u16, role: tiers.Role, games: u32, wins: u32, share: f32) tiers.Row {
    const edge = @as(f32, @floatFromInt(wins)) / @as(f32, @floatFromInt(games)) - 0.5;
    return .{ .champ = champ, .role = role, .games = games, .wins = wins, .share = share, .impact = edge, .edge = edge, .fade = 1, .spread = null, .patch = null };
}

// By win rate, as the server orders them. Lux top: rare by games; Zed top: by share
const rows = [_]tiers.Row{
    row(1, .bottom, 900, 480, 0.95),
    row(0, .middle, 1200, 620, 0.9),
    row(2, .middle, 800, 400, 0.8),
    row(3, .utility, 600, 290, 0.9),
    row(3, .top, 40, 19, 0.1),
    row(2, .top, 200, 90, 0.08),
};

const data: tiers.Data = .{
    .games = 10_000,
    .min_games = 50,
    .min_share = 10,
    .spread_min_games = 10,
    .cur_patch = "",
    .prev_patch = "",
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
        p.server = .{ .data = &data, .cells = try tiers.prepare(a, &data, role, ""), .role = role };
        p.state = p.server;
        p.state.live = true;
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
        var out: std.ArrayList(u8) = .empty;
        var it = std.mem.splitSequence(u8, page, "</img>");
        _ = it.next();
        while (it.next()) |rest| {
            if (out.items.len > 0) try out.append(p.arena.allocator(), ',');
            try out.appendSlice(p.arena.allocator(), rest[0..std.mem.findScalar(u8, rest, '<').?]);
        }
        return out.items;
    }

    fn id(p: *Page, name: []const u8, value: ?[]const u8) u32 {
        const t = p.i.current();
        return t.node(t.find(t.root, name, value).?).dom;
    }

    /// The column header whose text is `label`
    fn th(p: *Page, label: []const u8) u32 {
        const t = p.i.current();
        for (t.nodes.items) |n| if (n.tag == .th and n.n_kids == 1) {
            const k = t.node(t.kids.items[n.kids]);
            if (std.mem.eql(u8, k.text, label)) return n.dom;
        };
        unreachable;
    }

    fn deinit(p: *Page) void {
        p.arena.deinit();
    }
};

test "the server renders the default rows; rare ones come with the data" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var s: tiers.Tiers = .{ .data = &data, .cells = try tiers.prepare(a, &data, null, "../"), .root = "../" };
    var t: tree.Tree = .{};
    var h: tree.H = .init(a, &t);
    t.root = s.view(&h);
    var w: std.Io.Writer.Allocating = .init(a);
    try html.write(&t, t.root, &w.writer);
    const page = w.written();
    try testing.expectEqual(@as(usize, 4), std.mem.count(u8, page, "<tr class=\"bx\">"));
    try testing.expect(std.mem.find(u8, page, ">Lux</a></td><td class=\"role\"><svg class=\"ri\" role=\"img\" aria-label=\"Support\">") != null);
    try testing.expect(std.mem.find(u8, page, "<a class=\"champ box\" href=\"../champion/kaisa.html#role=bot\"><img alt=\"\" loading=\"lazy\" width=\"32\" height=\"32\" src=\"https://ddragon.leagueoflegends.com/cdn/15.13.1/img/champion/Kaisa.png\">") != null);
    try testing.expect(std.mem.find(u8, page, "<td class=\"rank\">4</td>") != null);
    try testing.expect(std.mem.find(u8, page, "<details class=\"tl-knobs\" hidden=\"\">") != null);
    try testing.expect(std.mem.find(u8, page, "<p class=\"tl-more\"><span>2</span> rare picks") != null);
    try testing.expect(std.mem.find(u8, page, "<a href=\"../role/mid.html\"><svg class=\"ri\" aria-hidden=\"true\"><use href=\"#ri-mid\"></use></svg>Mid</a>") != null);
    // Kai'Sa: 53.3% of 900, a dot at 56.7 on the 25 to 75 track
    try testing.expect(std.mem.find(u8, page, "<i class=\"d\" style=\"--x:56.7\"></i></span><b style=\"--f:1\">53.3%</b>") != null);
    try testing.expect(std.mem.find(u8, page, "<td class=\"opt\">9.0%</td><td class=\"opt\">9.0%</td>") != null);
    const report = try check.run(a, &t, .{ .words = .off, .answer = .off });
    for (report.findings.items) |f| std.debug.print("{s}\n", .{f.msg});
    try testing.expectEqual(@as(usize, 0), report.findings.items.len);
}

test "hydration takes the URL's sort; sorting moves rows and pushes history" {
    var p: Page = undefined;
    try p.init("#sort=name&desc=0", null);
    defer p.deinit();
    try testing.expectEqual(@as(u32, 0), p.fake.warnings);
    try testing.expectEqualStrings("Ahri,Kai'Sa,Lux,Zed", try p.names());
    // The minimums show once live
    try testing.expect(std.mem.find(u8, try p.shown(), "<details class=\"tl-knobs\">") != null);
    const creates = p.fake.creates;
    _ = p.rt.event(0, .{ .kind = .click, .target = p.th("Games") });
    try testing.expectEqualStrings("Ahri,Kai'Sa,Zed,Lux", try p.names());
    try testing.expectEqualStrings("#sort=games", p.fake.fragment.items);
    try testing.expectEqual(@as(u32, 1), p.fake.pushes);
    // Moved, not made again
    try testing.expectEqual(creates, p.fake.creates);
    _ = p.rt.event(0, .{ .kind = .click, .target = p.th("Games") });
    try testing.expectEqualStrings("Lux,Zed,Kai'Sa,Ahri", try p.names());
    try testing.expectEqualStrings("#sort=games&desc=0", p.fake.fragment.items);
    // Back to the page's own order
    p.fake.fragment.clearRetainingCapacity();
    p.rt.popstate();
    try testing.expectEqualStrings("Kai'Sa,Ahri,Zed,Lux", try p.names());
}

test "keys on a header: Enter sorts, others don't" {
    var p: Page = undefined;
    try p.init("", null);
    defer p.deinit();
    const champion = p.th("Champion");
    try testing.expect(!p.rt.event(0, .{ .kind = .keydown, .target = champion, .text = "a" }));
    try testing.expectEqualStrings("Kai'Sa,Ahri,Zed,Lux", try p.names());
    try testing.expect(p.rt.event(0, .{ .kind = .keydown, .target = champion, .text = "Enter" }));
    try testing.expectEqualStrings("Ahri,Kai'Sa,Lux,Zed", try p.names());
}

test "a search finds rare rows; minimums and Show them" {
    var p: Page = undefined;
    try p.init("", .top);
    defer p.deinit();
    try testing.expectEqualStrings("", try p.names());
    try testing.expect(std.mem.find(u8, try p.shown(), "<p class=\"tl-more\"><span>2</span>") != null);
    _ = p.rt.event(0, .{ .kind = .input, .target = p.id("type", "search"), .text = "lu" });
    try testing.expectEqualStrings("Lux", try p.names());
    try testing.expectEqualStrings("#q=lu", p.fake.fragment.items);
    try testing.expectEqual(@as(u32, 1), p.fake.replaces);
    _ = p.rt.event(0, .{ .kind = .input, .target = p.id("type", "search"), .text = "" });
    // Min lane % cleared: no minimum share, Zed's 8% shows; the field keeps its text
    _ = p.rt.event(0, .{ .kind = .input, .target = p.id("max", "100"), .text = "" });
    try testing.expectEqualStrings("Zed", try p.names());
    try testing.expectEqualStrings("#share=", p.fake.fragment.items);
    _ = p.rt.event(0, .{ .kind = .click, .target = p.id("class", "link") });
    try testing.expectEqualStrings("Lux,Zed", try p.names());
    try testing.expectEqualStrings("#min=0&share=0", p.fake.fragment.items);
    const page = try p.shown();
    try testing.expect(std.mem.find(u8, page, "<p class=\"tl-more\" hidden=\"\">") != null);
    try testing.expect(std.mem.find(u8, page, "<td class=\"rank\">2</td>") != null);
}
