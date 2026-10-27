//! The Draft tester's candidate panel on the fake DOM, fed as ui-tester.wasm feeds it: the
//! server's render, the seat from the URL, a stale feed, Pick and Enter into it, the sort,
//! a row's breakdown; each patch equal to a fresh render. Then the feed itself: options,
//! order, its bytes, and what the URL may not set
const std = @import("std");
const tree = @import("tree.zig");
const diff = @import("diff.zig");
const html = @import("html.zig");
const check = @import("check.zig");
const island = @import("island.zig");
const url = @import("url.zig");
const tp = @import("testerpage.zig");
const tc = @import("testercand.zig");
const data = @import("data.zig");
const Fake = @import("fakedom.zig").Fake;
const testing = std.testing;

const n_role = 5;

const Panel = struct {
    arena: std.heap.ArenaAllocator,
    fake: Fake = undefined,
    rt: island.Runtime(Fake) = undefined,
    l: tp.Loaded = undefined,
    feed: tc.Feed = undefined,
    state: tc.Panel = undefined,
    server: tc.Panel = undefined,
    i: *island.Island(tc.Panel, Fake) = undefined,

    fn init(p: *Panel, fragment: []const u8) !void {
        p.* = .{ .arena = .init(testing.allocator) };
        const a = p.arena.allocator();
        p.fake = .{ .a = a };
        try p.fake.fragment.appendSlice(a, fragment);
        p.rt = .init(a, &p.fake);
        p.l = .{ .m = tp.Demo.model(), .sc = undefined, .check = .{ .drafts = 0, .worst = 0 } };
        p.l.sc = try p.l.m.scorer(a);
        p.server = .init(&tp.Demo.head);
        p.server.js = "ui-testercand.js";
        p.server.wasm = "ui-testercand.wasm";
        p.state = p.server;
        const t = try a.create(tree.Tree);
        t.* = .{};
        var h: tree.H = .init(a, t);
        t.root = p.server.view(&h);
        p.fake.server = t;
        p.i = try p.rt.add(tc.Panel, &p.state, &p.server, tc.sel);
        try p.fed();
    }

    /// ui-tester.wasm's answer to the panel's board
    fn fed(p: *Panel) !void {
        const seat = tp.shownSeat(p.state.teams, p.state.seat) orelse 0;
        p.feed = try tc.feed(p.arena.allocator(), &tp.Demo.head, .{ .ready = &p.l }, p.state.which, p.state.teams, seat);
        p.state.feed = &p.feed;
        p.i.render();
    }

    /// The panel as a reader sees it, checked equal to a fresh render
    fn shown(p: *Panel) ![]const u8 {
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

    /// The DOM id of the first node whose `name` is `value`
    fn find(p: *Panel, name: []const u8, value: []const u8) u32 {
        const t = p.i.current();
        const n = walk(t, t.root, name, value) orelse @panic("no such node");
        return t.node(n).dom;
    }

    fn walk(t: *const tree.Tree, n: tree.N, name: []const u8, value: []const u8) ?tree.N {
        if (t.attr(n, name)) |v| if (std.mem.eql(u8, v, value)) return n;
        for (t.kidsOf(n)) |c| if (walk(t, c, name, value)) |x| return x;
        return null;
    }

    fn click(p: *Panel, name: []const u8, value: []const u8) void {
        _ = p.rt.event(0, .{ .kind = .click, .target = p.find(name, value) });
    }

    fn hashed(p: *Panel, s: []const u8) !void {
        p.fake.fragment.clearRetainingCapacity();
        try p.fake.fragment.appendSlice(p.arena.allocator(), s);
        p.rt.popstate();
        try p.fed();
    }

    fn deinit(p: *Panel) void {
        p.arena.deinit();
    }
};

fn has(s: []const u8, want: []const u8) !void {
    if (std.mem.find(u8, s, want) == null) {
        std.debug.print("missing {s}\n", .{want});
        return error.TestExpectedEqual;
    }
}

test "the server renders the panel, clean, the model loading, its code's paths on it" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var s: tc.Panel = .init(&tp.Demo.head);
    s.js = "ui-testercand.js";
    s.wasm = "ui-testercand.wasm";
    var t: tree.Tree = .{};
    var h: tree.H = .init(a, &t);
    t.root = s.view(&h);
    var w: std.Io.Writer.Allocating = .init(a);
    try html.write(&t, t.root, &w.writer);
    try has(w.written(), "data-island=\"testercand\"");
    try has(w.written(), "data-js=\"ui-testercand.js\"");
    try has(w.written(), "data-wasm=\"ui-testercand.wasm\"");
    try has(w.written(), "Blue Top");
    try has(w.written(), "Loading the model");
    const report = try check.run(a, &t, .{ .words = .off, .answer = .off });
    for (report.findings.items) |f| std.debug.print("{s}\n", .{f.msg});
    try testing.expectEqual(@as(usize, 0), report.findings.items.len);
}

test "the first empty seat, Pick into it, the next seat from the URL, Enter picks the search's first" {
    var p: Panel = undefined;
    try p.init("");
    defer p.deinit();
    var s = try p.shown();
    try has(s, "Blue Top");
    try has(s, "2 picks");
    try has(s, "Average top");
    // Aatrox's 0.2 over Darius's -0.1: first, starred
    try testing.expect(std.mem.find(u8, s, "Aatrox").? < std.mem.find(u8, s, "Darius").?);

    p.click("aria-label", "Pick Darius");
    try testing.expectEqual(122, p.state.teams[0][0]);
    try testing.expectEqualStrings("#b=122-0-0-0-0", p.fake.fragment.items);
    // The old seat's feed is stale: nothing to pick from until the new one
    try has(try p.shown(), "Loading the model");
    try p.fed();
    // Blue jungle next: the demo has no junglers
    s = try p.shown();
    try has(s, "Blue Jungle");
    try has(s, "No pick matches");

    // The tester's seat click: red top, Darius taken, Aatrox the one left
    try p.hashed("#b=122-0-0-0-0&s=5");
    s = try p.shown();
    try has(s, "Red Top");
    try has(s, "1 picks");
    _ = p.rt.event(0, .{ .kind = .input, .target = p.find("data-ref", "input"), .text = "aat" });
    _ = p.rt.event(0, .{ .kind = .keydown, .target = p.find("data-ref", "input"), .text = "Enter" });
    try testing.expectEqual(266, p.state.teams[1][0]);
    try testing.expect(p.state.seat == null);
    try testing.expectEqual(0, p.state.q.len);
    try testing.expectEqualStrings("#b=122-0-0-0-0&r=266-0-0-0-0", p.fake.fragment.items);
    try p.fed();
    _ = try p.shown();

    // Enter with no hit the seat can take does nothing
    try p.hashed("#b=122-0-0-0-0&r=266-0-0-0-0&s=0");
    _ = p.rt.event(0, .{ .kind = .input, .target = p.find("data-ref", "input"), .text = "aat" });
    _ = p.rt.event(0, .{ .kind = .keydown, .target = p.find("data-ref", "input"), .text = "Enter" });
    try testing.expectEqual(122, p.state.teams[0][0]);
    try has(try p.shown(), "No pick matches");
    _ = p.rt.event(0, .{ .kind = .keydown, .target = p.find("data-ref", "input"), .text = "Escape" });
    try testing.expectEqual(0, p.state.q.len);
    _ = try p.shown();
}

test "sort and a row's breakdown; other tabs hide the panel; a full board says so" {
    var p: Panel = undefined;
    try p.init("#r=122-0-0-0-0");
    defer p.deinit();
    try testing.expectEqual(122, p.state.teams[1][0]);
    p.click("aria-label", "Why Aatrox");
    try testing.expectEqual(266, p.state.open);
    var s = try p.shown();
    try has(s, "c-wf");
    try has(s, "Top strength");
    try has(s, "Blue with Aatrox");
    try has(s, "vs average");
    p.click("aria-label", "Why Aatrox");
    try testing.expectEqual(0, p.state.open);

    const pushes = p.fake.pushes;
    p.click("aria-pressed", "false");
    try testing.expectEqual(tc.Sort.fit, p.state.sort);
    try testing.expectEqual(pushes + 1, p.fake.pushes);
    try testing.expectEqualStrings("#r=122-0-0-0-0&o=fit", p.fake.fragment.items);
    s = try p.shown();
    try has(s, ">fit<");

    try p.hashed("#r=122-0-0-0-0&t=terms");
    try has(try p.shown(), "hidden");
    var full: tc.Panel.Url = .{ .b = .{ 266, 1, 2, 3, 4 }, .r = .{ 122, 5, 6, 7, 8 } };
    p.state.fromUrl(full);
    // Champions the head lacks leave their seats empty: blue jungle is first
    try testing.expectEqual(1, tp.shownSeat(p.state.teams, p.state.seat).?);
    full.s = 99;
    p.state.fromUrl(full);
    try testing.expect(p.state.seat == null);
    p.state.teams = @splat(@splat(266));
    p.i.render();
    try has(try p.shown(), "Every seat is filled");
}

test "the feed: the seat's options, sorted by the low end or by fit, another seat's left out; its bytes" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var l: tp.Loaded = .{ .m = tp.Demo.model(), .sc = undefined, .check = undefined };
    l.sc = try l.m.scorer(a);
    const head = &tp.Demo.head;
    const empty: [2][n_role]u32 = @splat(@splat(0));
    var f = try tc.feed(a, head, .{ .ready = &l }, .live, empty, 0);
    try testing.expectEqual(tc.Status.ready, f.load);
    try testing.expectEqual(2, f.opts.len);
    var c = try tc.sorted(a, &f, .win);
    try testing.expectEqual(266, c[0].id);
    try testing.expect(c[0].lo >= c[1].lo);
    // Parts and rest add up to the change over the average pick
    for (f.opts) |o| {
        var sum = o.rest;
        for (o.parts) |x| sum += x.pp;
        try testing.expectApproxEqAbs(o.p - f.empty, sum, 1e-3);
        try testing.expectEqual(.base, o.parts[0].kind);
    }
    c = try tc.sorted(a, &f, .fit);
    try testing.expectEqual(2, c.len);
    f = try tc.feed(a, head, .{ .ready = &l }, .live, .{ @splat(0), .{ 266, 0, 0, 0, 0 } }, 0);
    try testing.expectEqual(1, f.opts.len);
    try testing.expectEqual(122, f.opts[0].id);
    // Its own seat's champion stays an option
    f = try tc.feed(a, head, .{ .ready = &l }, .live, .{ @splat(0), .{ 266, 0, 0, 0, 0 } }, n_role);
    try testing.expectEqual(2, f.opts.len);
    try testing.expectEqual(0, (try tc.feed(a, head, .{ .ready = &l }, .live, empty, 2 * n_role)).opts.len);
    try testing.expectEqual(tc.Status.loading, (try tc.feed(a, head, .loading, .comp, empty, 0)).load);
    try testing.expectEqual(tc.Status.failed, (try tc.feed(a, head, .failed, .comp, empty, 0)).load);
    try testing.expectEqual(tc.Status.bad, (try tc.feed(a, head, .bad, .comp, empty, 0)).load);

    // Through ui.data, as it crosses between the two wasm files
    f = try tc.feed(a, head, .{ .ready = &l }, .live, empty, 0);
    var raw: std.ArrayList(u8) = .empty;
    try data.encode(a, tc.Feed, f, &raw);
    const back = try data.decode(a, tc.Feed, raw.items);
    try testing.expect(back.of(.live, empty, 0));
    try testing.expect(!back.of(.comp, empty, 0));
    try testing.expectEqual(f.opts[1].parts[0].pp, back.opts[1].parts[0].pp);
    try testing.expectError(error.Truncated, data.decode(a, tc.Feed, raw.items[0 .. raw.items.len - 1]));

    try testing.expect(tc.matches("K'Sante", "ksa"));
    try testing.expect(tc.matches("Kai'Sa", "AI'S"));
    try testing.expect(tc.matches("Nunu & Willump", "nunuwil"));
    try testing.expect(tc.matches("Aatrox", ""));
    try testing.expect(!tc.matches("Aatrox", "zz"));
    const u = url.read(tc.Panel.Url, "#o=sideways&m=nope&t=7");
    try testing.expectEqual(tc.Sort.win, u.o);
    try testing.expectEqual(tp.Which.live, u.m);
}
