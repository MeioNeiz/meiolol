//! The home page's islands on the fake DOM: the server's render, hydration as the island
//! (live), the lookup's typing and Enter, the review's role switch, the champions' role,
//! the Daily Draft's marks; each patch equal to a fresh render
const std = @import("std");
const tree = @import("tree.zig");
const diff = @import("diff.zig");
const html = @import("html.zig");
const check = @import("check.zig");
const island = @import("island.zig");
const hp = @import("homepage.zig");
const idlookup = @import("idlookup.zig");
const today = @import("today.zig");
const Fake = @import("fakedom.zig").Fake;
const testing = std.testing;

fn Page(comptime T: type) type {
    return struct {
        arena: std.heap.ArenaAllocator,
        fake: Fake = undefined,
        rt: island.Runtime(Fake) = undefined,
        state: T = undefined,
        server: T = undefined,
        i: *island.Island(T, Fake) = undefined,

        const P = @This();

        /// `server` as rendered, then the island's `state`
        fn init(p: *P, server: T, state: T) !void {
            p.* = .{ .arena = .init(testing.allocator) };
            const a = p.arena.allocator();
            p.fake = .{ .a = a };
            p.rt = .init(a, &p.fake);
            p.server = server;
            p.state = state;
            const t = try a.create(tree.Tree);
            t.* = .{};
            var h: tree.H = .init(a, t);
            t.root = p.server.view(&h);
            p.fake.server = t;
            p.i = try p.rt.add(T, &p.state, &p.server, "x");
            try testing.expectEqual(@as(u32, 0), p.fake.warnings);
        }

        /// The island as a reader sees it, checked equal to a fresh render
        fn shown(p: *P) ![]const u8 {
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

        fn id(p: *P, name: []const u8, value: ?[]const u8) u32 {
            const t = p.i.current();
            return t.node(t.find(t.root, name, value).?).dom;
        }

        fn ev(p: *P, kind: tree.Ev, target: u32, text: []const u8) bool {
            return p.rt.event(0, .{ .kind = kind, .target = target, .text = text });
        }

        fn deinit(p: *P) void {
            p.arena.deinit();
        }
    };
}

fn count(s: []const u8, part: []const u8) usize {
    return std.mem.count(u8, s, part);
}

test "the server's home passes the page checks" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var t: tree.Tree = .{};
    var h: tree.H = .init(a, &t);
    var x = hp.demo(&h).?;
    var look: idlookup.IdLookup = .{ .to = "your.html" };
    const d: hp.Daily = .{ .n = 14, .href = "daily.html" };
    var daily: hp.HomeDaily = .{ .data = &d };
    t.root = hp.page(&h, look.view(&h), x[0].view(&h), &.{daily.view(&h)}, x[1].view(&h));
    try testing.expect(!h.oom);
    var w: std.Io.Writer.Allocating = .init(a);
    try html.write(&t, t.root, &w.writer);
    // Before the island: Review submits the form
    try testing.expect(std.mem.find(u8, w.written(), "<form class=\"box\" method=\"get\" role=\"search\" action=\"your.html\">") != null);
    try testing.expect(std.mem.find(u8, w.written(), "<button class=\"c-btn\" type=\"submit\" data-v=\"primary\" data-ref=\"go\">Review</button>") != null);
    const report = try check.run(a, &t, .{ .words = .off, .answer = .off });
    for (report.findings.items) |f| std.debug.print("{s}\n", .{f.msg});
    try testing.expectEqual(@as(usize, 0), report.findings.items.len);
}

test "the lookup: Review a link once live, its href follows what is typed, Enter follows it" {
    var p: Page(idlookup.IdLookup) = undefined;
    const server: idlookup.IdLookup = .{ .to = "your.html" };
    var live = server;
    live.live = true;
    try p.init(server, live);
    defer p.deinit();
    var page = try p.shown();
    try testing.expect(std.mem.find(u8, page, "type=\"submit\"") == null);
    try testing.expect(std.mem.find(u8, page, "href=\"your.html\"") != null);
    const input = p.id("name", "id");
    // Enter with nothing typed: the form's own, no click
    _ = p.ev(.input, input, "  ");
    try testing.expect(!p.ev(.keydown, input, "Enter"));
    try testing.expectEqual(@as(u32, 0), p.fake.clicked);
    _ = p.ev(.input, input, "Hide on bush#KR1");
    page = try p.shown();
    try testing.expect(std.mem.find(u8, page, "href=\"your.html#id=Hide%20on%20bush%23KR1\"") != null);
    _ = p.ev(.keydown, input, "a");
    try testing.expectEqual(@as(u32, 0), p.fake.clicked);
    try testing.expect(p.ev(.keydown, input, "Enter"));
    try testing.expectEqual(@as(u32, 1), p.fake.clicked);
}

test "the lookup: this device's IDs as chips" {
    var p: Page(idlookup.IdLookup) = undefined;
    var recent: [5]idlookup.Id = undefined;
    var live: idlookup.IdLookup = .{ .to = "../your.html", .live = true };
    live.recent = hp.recentIds("[{\"id\":\"Faker#KR1\"},{\"id\":\"Agurin#EUW\"}]", &recent);
    try p.init(.{ .to = "../your.html" }, live);
    defer p.deinit();
    const page = try p.shown();
    try testing.expect(std.mem.find(u8, page, "href=\"../your.html#id=Faker%23KR1\"") != null);
    try testing.expect(std.mem.find(u8, page, "href=\"../your.html#id=Agurin%23EUW\"") != null);
}

test "the review: roles off until live, then a pick waits for its file; Open on the default only" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: tree.H = .init(arena.allocator(), &t);
    const x = hp.demo(&h).?;
    var p: Page(hp.HomeReview) = undefined;
    var live = x[0];
    live.live = true;
    try p.init(x[0], live);
    defer p.deinit();
    var w: std.Io.Writer.Allocating = .init(arena.allocator());
    t.root = p.server.view(&h);
    try html.write(&t, t.root, &w.writer);
    var page = try p.shown();
    // Five roles off on the server's, only bot (no file) once live
    try testing.expectEqual(count(w.written(), "disabled") - 4, count(page, "disabled"));
    try testing.expect(std.mem.find(u8, page, ">Open</a>") != null);
    _ = p.ev(.click, p.id("aria-label", "Bot"), "");
    try testing.expectEqual(.mid, p.state.want);
    _ = p.ev(.click, p.id("aria-label", "Top"), "");
    try testing.expectEqual(.top, p.state.want);
    try testing.expectEqual(.mid, p.state.shown);
    page = try p.shown();
    try testing.expect(std.mem.find(u8, page, ">Open</a>") != null);
    // Top's file in: game.html opens the default role's games only
    p.state.shown = .top;
    p.i.render();
    page = try p.shown();
    try testing.expect(std.mem.find(u8, page, ">Open</a>") == null);
}

test "the review for a returning visitor: their record and form, Open on their game, no roles" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: tree.H = .init(arena.allocator(), &t);
    var x = hp.demo(&h).?;
    x[0].you = .{ .id = "Agurin#EUW", .open = "game.html#id=Agurin%23EUW&game=5", .wins = 12, .losses = 8, .form = &.{ true, false } };
    x[0].live = true;
    t.root = x[0].view(&h);
    var w: std.Io.Writer.Allocating = .init(arena.allocator());
    try html.write(&t, t.root, &w.writer);
    const page = w.written();
    try testing.expect(std.mem.find(u8, page, "<b>Agurin#EUW</b>") != null);
    try testing.expect(std.mem.find(u8, page, "12W 8L") != null);
    try testing.expect(std.mem.find(u8, page, "href=\"game.html#id=Agurin%23EUW&amp;game=5\"") != null);
    try testing.expect(std.mem.find(u8, page, "aria-label=\"Bot\"") == null);
}

test "data-roles round trip" {
    const all = [_][5]bool{ @splat(false), @splat(true), .{ true, true, true, false, true }, .{ false, false, false, false, true } };
    for (all) |r| try testing.expectEqual(r, hp.rolesOf(hp.rolesMask(r)));
    try testing.expectEqual(@as(u8, 0b10111), hp.rolesMask(all[2]));
}

test "the champions: one role at a time when narrow, a bad index skipped" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: tree.H = .init(arena.allocator(), &t);
    const x = hp.demo(&h).?;
    var d = x[1].data.*;
    var roles = d.roles;
    roles[3] = &.{ d.roles[3][0], .{ .champ = 99, .href = "#", .games = 1, .wins = 1, .share = 1 } };
    d.roles = roles;
    var p: Page(hp.HomeChamps) = undefined;
    try p.init(.{ .data = &d }, .{ .data = &d });
    defer p.deinit();
    var page = try p.shown();
    try testing.expectEqual(@as(usize, 1), count(page, "class=\"col\" data-on"));
    try testing.expectEqual(@as(usize, 7), count(page, "<li"));
    _ = p.ev(.click, p.id("aria-label", "Bot"), "");
    try testing.expectEqual(.bot, p.state.on);
    page = try p.shown();
    try testing.expectEqual(@as(usize, 1), count(page, "class=\"col\" data-on"));
}

test "the champions: Most played, Win rate, Rising once there are risers; links sort the table so" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: tree.H = .init(arena.allocator(), &t);
    var d = hp.demo(&h).?[1].data.*;
    d.index = "champions.html";
    var p: Page(hp.HomeChamps) = undefined;
    try p.init(.{ .data = &d }, .{ .data = &d });
    defer p.deinit();
    var page = try p.shown();
    try testing.expect(std.mem.find(u8, page, ">Rising</button>") == null);
    try testing.expect(std.mem.find(u8, page, "href=\"champions.html#sort=6\"") != null);
    _ = p.ev(.click, p.id("aria-pressed", "false"), "");
    try testing.expectEqual(.best, p.state.list);
    page = try p.shown();
    try testing.expect(std.mem.find(u8, page, "href=\"champions.html\"") != null);
    var rising = d.rising;
    rising[0] = d.roles[0][0..1];
    d.rising = rising;
    p.state.list = .rising;
    p.i.render();
    page = try p.shown();
    try testing.expect(std.mem.find(u8, page, "href=\"champions.html#sort=2\"") != null);
    try testing.expectEqual(@as(usize, 4), count(page, ">None clear yet<"));
}

test "the Daily Draft card: Guess, then Open with the marks once played" {
    const d: hp.Daily = .{ .n = 14, .href = "daily.html" };
    var p: Page(hp.HomeDaily) = undefined;
    try p.init(.{ .data = &d }, .{ .data = &d });
    defer p.deinit();
    var page = try p.shown();
    try testing.expect(std.mem.find(u8, page, ">Guess</a>") != null);
    p.state.marks = hp.dailyMarks("{\"14\":{\"opt\":1,\"side\":0,\"marks\":\"10\",\"on\":\"2026-10-27\"}}", 14);
    try testing.expectEqual(today.Marks{ .pick = true, .side = false }, p.state.marks.?);
    p.i.render();
    page = try p.shown();
    try testing.expect(std.mem.find(u8, page, ">Open</a>") != null);
    try testing.expect(std.mem.find(u8, page, "aria-label=\"Pick right, winner wrong\"") != null);
}
