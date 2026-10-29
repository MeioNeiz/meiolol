//! Daily Draft's page on the fake DOM: the server's render, keys and clicks through the
//! three phases with focus moved to each new panel, a seat after the reveal, answers
//! restored; each patch equal to a fresh render. Then the branches by hand, the seat
//! review (ui.dailyseat) with them
const std = @import("std");
const tree = @import("tree.zig");
const diff = @import("diff.zig");
const html = @import("html.zig");
const check = @import("check.zig");
const island = @import("island.zig");
const dp = @import("dailypage.zig");
const dd = @import("dailydata.zig");
const dailyseat = @import("dailyseat.zig");
const Fake = @import("fakedom.zig").Fake;
const testing = std.testing;

const Page = On(dp.Page, dp.sel, "daily");
const SeatIsland = On(dailyseat.Seat, dailyseat.sel, "dailyseat");

/// Component C's island under `sel` on the fake DOM
fn On(comptime C: type, comptime sel: []const u8, comptime island_name: []const u8) type {
    return struct {
        arena: std.heap.ArenaAllocator,
        fake: Fake = undefined,
        rt: island.Runtime(Fake) = undefined,
        state: C = undefined,
        server: C = undefined,
        i: *island.Island(C, Fake) = undefined,

        const Self = @This();

        fn init(p: *Self, puzzle: *const dd.Puzzle) !void {
            p.* = .{ .arena = .init(testing.allocator) };
            const a = p.arena.allocator();
            p.fake = .{ .a = a };
            p.rt = .init(a, &p.fake);
            p.server = .init(a, puzzle);
            p.state = p.server;
            const t = try a.create(tree.Tree);
            t.* = .{};
            var h: tree.H = .init(a, t);
            t.root = p.server.view(&h);
            p.fake.server = t;
            p.i = try p.rt.add(C, &p.state, &p.server, sel);
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

        /// The node whose `name` attribute starts with `prefix`
        fn idStarting(p: *Self, name: []const u8, prefix: []const u8) u32 {
            const t = p.i.current();
            return t.node(starting(t, t.root, name, prefix).?).dom;
        }

        fn starting(t: *const tree.Tree, n: tree.N, name: []const u8, prefix: []const u8) ?tree.N {
            if (t.attr(n, name)) |v| if (std.mem.startsWith(u8, v, prefix)) return n;
            for (t.kidsOf(n)) |k| if (starting(t, k, name, prefix)) |f| return f;
            return null;
        }

        fn click(p: *Self, target: u32) void {
            _ = p.rt.event(0, .{ .kind = .click, .target = target });
        }

        /// A key on the island, as if pressed with focus on `target`
        fn key(p: *Self, target: u32, k: []const u8) bool {
            return p.rt.event(0, .{ .kind = .keydown, .target = target, .text = k });
        }

        fn root(p: *Self) u32 {
            return p.id("data-island", island_name);
        }

        fn deinit(p: *Self) void {
            p.arena.deinit();
        }
    };
}

test "the server renders the pick panel, clean" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var s: dp.Page = .init(a, &dp.pro);
    var t: tree.Tree = .{};
    var h: tree.H = .init(a, &t);
    t.root = s.view(&h);
    try testing.expect(!h.oom);
    const report = try check.run(a, &t, .{ .words = .off, .answer = .off });
    for (report.findings.items) |f| std.debug.print("{s}\n", .{f.msg});
    try testing.expectEqual(@as(usize, 0), report.findings.items.len);
}

test "keys and clicks through pick, who won and the reveal; focus follows the panels" {
    var p: Page = undefined;
    try p.init(&dp.pro);
    defer p.deinit();
    try testing.expectEqual(@as(u32, 0), p.fake.warnings);
    _ = try p.shown();

    // A digit chooses and focuses Lock in; one past the options, 0 and 9 do nothing
    try testing.expect(p.key(p.root(), "2"));
    try testing.expectEqual(@as(?u8, 1), p.state.choice);
    try testing.expectEqual(p.id("data-ref", "lock"), p.fake.focused);
    try testing.expect(!p.key(p.root(), "7"));
    try testing.expect(!p.key(p.root(), "0"));
    try testing.expectEqual(@as(?u8, 1), p.state.choice);
    _ = try p.shown();

    // Enter is the focused button's own: on card 4 it chooses card 4, not lock card 2
    const card4 = p.id("aria-keyshortcuts", "4");
    try testing.expect(!p.key(card4, "Enter"));
    p.click(card4);
    try testing.expectEqual(dp.Phase.pick, p.state.phase());
    try testing.expectEqual(@as(?u8, 3), p.state.choice);
    try testing.expect(std.mem.find(u8, try p.shown(), "aria-pressed=\"true\"") != null);

    p.click(p.id("data-ref", "lock"));
    try testing.expectEqual(dp.Phase.winner, p.state.phase());
    try testing.expectEqual(@as(?u8, 3), p.state.guess);
    try testing.expect(p.state.dirty);
    try testing.expectEqual(p.id("data-ref", "q"), p.fake.focused);
    try testing.expect(std.mem.find(u8, try p.shown(), "Who won?") != null);

    // Who won: 3 is not a side; 1 is blue
    try testing.expect(!p.key(p.root(), "3"));
    try testing.expect(p.key(p.root(), "1"));
    try testing.expectEqual(dp.Phase.done, p.state.phase());
    try testing.expectEqual([2]bool{ false, true }, p.state.marks.?);
    try testing.expectEqual(p.id("data-ref", "res"), p.fake.focused);
    // Keys do nothing once done
    try testing.expect(!p.key(p.root(), "2"));
    const done = try p.shown();
    try testing.expect(std.mem.find(u8, done, "Blue won") != null);

    // The answers and seat for ui-dailyseat.wasm on the root; another seat moves it
    for ([_][]const u8{ "data-phase=\"done\"", "data-seat=\"5\"", "data-guess=\"3\"" }) |want| try testing.expect(std.mem.find(u8, done, want) != null);
    p.click(p.idStarting("aria-label", "Blue Top, K'Sante"));
    try testing.expectEqual(@as(u8, 0), p.state.seat);
    try testing.expect(std.mem.find(u8, try p.shown(), "data-seat=\"0\"") != null);
    p.click(p.idStarting("aria-label", "Red Top, Jayce"));
    try testing.expectEqual(@as(u8, 5), p.state.seat);
    _ = try p.shown();
}

test "answers restored after the server's render patch to the same page" {
    for ([_][]const u8{
        "{\"11\":{\"opt\":1}}",
        "{\"11\":{\"opt\":0,\"side\":1,\"hint\":1,\"marks\":\"01\",\"on\":\"2026-10-27\"}}",
    }, [_]dp.Phase{ .winner, .done }) |json, want| {
        var p: Page = undefined;
        try p.init(&dp.pro);
        defer p.deinit();
        p.state.restore(json);
        p.i.render();
        try testing.expectEqual(want, p.state.phase());
        _ = try p.shown();
    }
}

test "the seat review: empty from the server, then the seat read off the page; rows open" {
    var p: SeatIsland = undefined;
    try p.init(&dp.pro);
    defer p.deinit();
    try testing.expectEqualStrings("<div class=\"c-dseat\" data-island=\"dailyseat\"></div>", try p.shown());
    p.state.read("done", "5", "1");
    p.i.render();
    const out = try p.shown();
    try testing.expect(std.mem.find(u8, out, "On paper") != null);
    try testing.expect(std.mem.find(u8, out, "Red Top") != null);
    p.click(p.id("aria-label", "Why Jayce"));
    try testing.expectEqual([2]?u16{ 5, null }, p.state.open);
    try testing.expect(std.mem.find(u8, try p.shown(), "aria-expanded=\"true\"") != null);
    p.state.read("done", "0", "1");
    p.i.render();
    try testing.expectEqual([2]?u16{ null, null }, p.state.open);
    try testing.expect(std.mem.find(u8, try p.shown(), "Blue Top") != null);
}

test "cand: two rows open at most, a third drops the oldest; a new seat closes them" {
    var s: dailyseat.Seat = .init(testing.allocator, &dd.sample);
    s.read("done", "5", "1");
    try testing.expect(s.done);
    try testing.expectEqual(@as(?u8, 1), s.guess);
    var ev: tree.Event = .{ .kind = .click };
    s.update(.{ .cand = 1 }, &ev);
    s.update(.{ .cand = 2 }, &ev);
    try testing.expectEqual([2]?u16{ 2, 1 }, s.open);
    s.update(.{ .cand = 3 }, &ev);
    try testing.expectEqual([2]?u16{ 3, 2 }, s.open);
    s.update(.{ .cand = 3 }, &ev);
    try testing.expectEqual([2]?u16{ 2, null }, s.open);
    s.read("done", "5", "1");
    try testing.expectEqual([2]?u16{ 2, null }, s.open);
    s.read("done", "2", "1");
    try testing.expectEqual(@as(u8, 2), s.seat);
    try testing.expectEqual([2]?u16{ null, null }, s.open);
    // Before the reveal, or attributes it never writes: nothing, the hidden seat
    s.read("winner", "", "");
    try testing.expect(!s.done);
    try testing.expectEqual(@as(?u8, null), s.guess);
    try testing.expectEqual(@as(u8, 5), s.seat);
    s.read("done", "12", "9");
    try testing.expectEqual(@as(u8, 5), s.seat);
    try testing.expectEqual(@as(?u8, null), s.guess);

    // Page seats only after the reveal, and only the ten
    var t: dp.Page = .init(testing.allocator, &dd.sample);
    t.update(.{ .seat = 2 }, &ev);
    try testing.expectEqual(@as(u8, 5), t.seat);
    t.marks = .{ true, true };
    t.update(.{ .seat = 10 }, &ev);
    try testing.expectEqual(@as(u8, 5), t.seat);
    t.update(.{ .seat = 2 }, &ev);
    try testing.expectEqual(@as(u8, 2), t.seat);
}

test "the hint: only while picking, saved, and it costs the clean tick" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var s: dp.Page = .init(a, &dp.pro);
    var ev: tree.Event = .{ .kind = .click };
    s.update(.hint, &ev);
    try testing.expect(s.hint and s.dirty);
    s.update(.{ .choose = 0 }, &ev);
    s.update(.lock, &ev);
    s.update(.{ .winner = .blue }, &ev);
    try testing.expectEqual([2]bool{ true, true }, s.marks.?);
    const out = try render(a, &s);
    try testing.expect(std.mem.find(u8, out, "Pick, with a hint") != null);
    try testing.expect(std.mem.find(u8, out, "<span class=\"c-badge\">✓ Pick, with a hint") != null);
    try testing.expect(std.mem.find(u8, out, "<span class=\"c-badge\" data-k=\"buff\">✓ Winner") != null);
    const json = try dp.write(a, "", 11, s.saved(), "2026-10-27");
    try testing.expectEqualStrings("{\"11\":{\"opt\":0,\"side\":0,\"hint\":1,\"marks\":\"11\",\"on\":\"2026-10-27\"}}", json);
    var back: dp.Page = .init(a, &dp.pro);
    back.restore(json);
    try testing.expect(back.hint);
    // No hint once locked in
    var late: dp.Page = .init(a, &dp.pro);
    late.update(.{ .choose = 0 }, &ev);
    late.update(.lock, &ev);
    late.update(.hint, &ev);
    try testing.expect(!late.hint);
}

test "read: malformed or foreign entries give nothing wrong" {
    const Case = struct { json: []const u8, want: ?dp.Saved };
    const cases = [_]Case{
        .{ .json = "", .want = null },
        .{ .json = "{\"11\":{\"opt\":", .want = null },
        .{ .json = "{\"12\":{\"opt\":1}}", .want = null },
        .{ .json = "{\"11\":{\"opt\":\"2\"}}", .want = .{} },
        .{ .json = "{\"11\":{\"side\":2}}", .want = .{} },
        .{ .json = "{\"11\":{\"marks\":\"1\"}}", .want = .{} },
        .{ .json = "{\"11\":{\"marks\":\"1x\"}}", .want = .{} },
        .{ .json = "{\"11\":{\"marks\":\"10x}}", .want = .{} },
        .{ .json = "{\"11\":{\"hint\":true}}", .want = .{} },
        .{ .json = "{\"11\":{\"opt\":2,\"side\":1,\"marks\":\"01\"}}", .want = .{ .opt = 2, .side = .red, .marks = .{ false, true } } },
        // Another entry first: its own fields don't leak into 11's
        .{ .json = "{\"7\":{\"opt\":3,\"marks\":\"11\"},\"11\":{\"side\":0}}", .want = .{ .side = .blue } },
    };
    for (cases) |c| {
        const got = dp.read(c.json, 11);
        if (c.want) |w| {
            const g = got orelse return error.TestExpectedEqual;
            try testing.expectEqual(w.opt, g.opt);
            try testing.expectEqual(w.side, g.side);
            try testing.expectEqual(w.marks, g.marks);
            try testing.expectEqual(w.hint, g.hint);
        } else try testing.expectEqual(null, got);
    }
}

test "finishedOn: only a quoted 10-character date, from the entry's own fields" {
    const Case = struct { json: []const u8, want: ?[]const u8 };
    const cases = [_]Case{
        .{ .json = "{\"11\":{\"marks\":\"10\",\"on\":\"2026-10-27\"}}", .want = "2026-10-27" },
        .{ .json = "{\"11\":{\"marks\":\"10\",\"on\":\"2026-10-2\"}}", .want = null },
        .{ .json = "{\"11\":{\"marks\":\"10\",\"on\": \"2026-10-27\"}}", .want = null },
        .{ .json = "{\"11\":{\"marks\":\"10\",\"on\":null}}", .want = null },
        // Saved before `on` existed
        .{ .json = "{\"11\":{\"marks\":\"10\"}}", .want = null },
        .{ .json = "{\"11\":{\"hint\":1,\"on\":\"2026-10-27\"}}", .want = "2026-10-27" },
        .{ .json = "{\"7\":{\"on\":\"2026-10-17\"},\"11\":{\"opt\":1}}", .want = null },
    };
    for (cases) |c| {
        const got = dp.finishedOn(c.json, 11);
        if (c.want) |w| try testing.expectEqualStrings(w, got orelse return error.TestExpectedEqual) else try testing.expectEqual(null, got);
    }
}

test "write then finishedOn: the date only with marks, other entries kept" {
    const a = testing.allocator;
    const one = try dp.write(a, "", 11, .{ .opt = 2 }, "2026-10-27");
    defer a.free(one);
    try testing.expectEqual(null, dp.finishedOn(one, 11));
    const two = try dp.write(a, one, 11, .{ .opt = 2, .side = .red, .marks = .{ true, false } }, "2026-10-27");
    defer a.free(two);
    try testing.expectEqualStrings("2026-10-27", dp.finishedOn(two, 11).?);
    const three = try dp.write(a, two, 12, .{ .opt = 1, .marks = .{ false, false } }, "2026-10-29");
    defer a.free(three);
    try testing.expectEqualStrings("2026-10-27", dp.finishedOn(three, 11).?);
    try testing.expectEqualStrings("2026-10-29", dp.finishedOn(three, 12).?);
    try testing.expectEqual(.red, dp.read(three, 11).?.side);
}

test "the reveal's views: result line, seat panel parts, On paper and the mix" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    // Wrong pick (Gnar), the hidden seat: "Your pick" with its chance and the gap
    var s = answered(a, &dd.sample, 2, .blue);
    var out = try render(a, &s);
    try testing.expect(std.mem.find(u8, out, "class=\"res\"") != null);
    try testing.expect(std.mem.find(u8, out, "Your pick Gnar: 49.9%") != null);
    try testing.expect(std.mem.find(u8, out, "On paper") != null);
    try testing.expect(std.mem.count(u8, out, "</b> v <b") >= 3);
    // The played pick's chips: its three largest terms, by size
    const into = std.mem.find(u8, out, "into K&#39;Sante") orelse std.mem.find(u8, out, "into K'Sante").?;
    const strength = std.mem.find(u8, out, "Top strength").?;
    try testing.expect(into < strength);
    // A seat without candidates: unrated; no "Your pick" off the hidden seat
    s.seat = 1;
    out = try render(a, &s);
    try testing.expect(std.mem.find(u8, out, "can&#39;t rate") != null or std.mem.find(u8, out, "can't rate") != null);
    try testing.expect(std.mem.find(u8, out, "Your pick") == null);

    // No paper, no damage kinds: neither part drawn
    var bare = dd.sample;
    bare.paper = null;
    var seats = bare.seats;
    for (&seats) |*side| for (side) |*x| {
        x.dmg = null;
    };
    bare.seats = seats;
    var b = answered(a, &bare, 0, .red);
    out = try render(a, &b);
    try testing.expect(std.mem.find(u8, out, "On paper") == null);
    try testing.expect(std.mem.find(u8, out, "class=\"mix\"") == null);
    try testing.expect(std.mem.find(u8, out, "Your pick") == null);
}

test "a rank gap in the list, without overflow at the top of u16" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var p = dd.sample;
    var seats = p.seats;
    seats[1][0].cands = &.{
        .{ .champ = 10, .rank = 1, .win = 49.9, .low = 48.5, .high = 51.3, .terms = &.{}, .rest = 0 },
        .{ .champ = 5, .rank = 65535, .win = 48.9, .low = 47.6, .high = 50.2, .terms = &.{}, .rest = 0 },
    };
    p.seats = seats;
    var s = answered(a, &p, 0, .blue);
    const out = try render(a, &s);
    try testing.expectEqual(1, std.mem.count(u8, out, "class=\"gap\""));
}

test "out of memory in the view sets oom, never a partial page" {
    var buf: [2048]u8 = undefined;
    var fba: std.heap.FixedBufferAllocator = .init(&buf);
    var s: dp.Page = .init(fba.allocator(), &dp.pro);
    s.marks = .{ true, true };
    s.guess = 0;
    var t: tree.Tree = .{};
    var h: tree.H = .init(fba.allocator(), &t);
    _ = s.view(&h);
    try testing.expect(h.oom);
}

/// A page on `p` with option `opt` locked in and `w` answered
fn answered(a: std.mem.Allocator, p: *const dd.Puzzle, opt: u8, w: dd.Side) dp.Page {
    var s: dp.Page = .init(a, p);
    var ev: tree.Event = .{ .kind = .click };
    s.update(.{ .choose = opt }, &ev);
    s.update(.lock, &ev);
    s.update(.{ .winner = w }, &ev);
    return s;
}

/// The page and its seat review, as daily.zig lays them out
fn render(a: std.mem.Allocator, s: *dp.Page) ![]const u8 {
    var t: tree.Tree = .{};
    var h: tree.H = .init(a, &t);
    t.root = dp.both(&h, s, .{ null, null });
    try testing.expect(!h.oom);
    var w: std.Io.Writer.Allocating = .init(a);
    try html.write(&t, t.root, &w.writer);
    return w.written();
}

test "Home reads the marks this page writes" {
    const hp = @import("homepage.zig");
    const a = testing.allocator;
    const json = try dp.write(a, "{\"7\":{\"pick\":266,\"marks\":\"11\"}}", 11, .{ .opt = 2, .side = .red, .hint = true, .marks = .{ true, false } }, "2026-10-27");
    defer a.free(json);
    const m = hp.dailyMarks(json, 11).?;
    try testing.expect(m.pick and !m.side);
    // Before the winner: no marks for Home
    const half = try dp.write(a, "", 11, .{ .opt = 2, .hint = true }, "");
    defer a.free(half);
    try testing.expectEqual(null, hp.dailyMarks(half, 11));
}
