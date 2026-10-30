//! The Draft tester on the fake DOM: the server's render, hydration, seats chosen, the
//! board from the URL (the candidate panel's picks) and into it, the model Select, the
//! tabs with each load state, bans, Random, Fill empty, Undo, Clear; each patch equal to
//! a fresh render. Then restore's edge cases and the model file's bad bytes
const std = @import("std");
const tree = @import("tree.zig");
const diff = @import("diff.zig");
const html = @import("html.zig");
const check = @import("check.zig");
const island = @import("island.zig");
const tp = @import("testerpage.zig");
const td = @import("testerdata.zig");
const data = @import("data.zig");
const champsearch = @import("champsearch.zig");
const Fake = @import("fakedom.zig").Fake;
const testing = std.testing;

const n_role = 5;

const Page = struct {
    arena: std.heap.ArenaAllocator,
    fake: Fake = undefined,
    rt: island.Runtime(Fake) = undefined,
    l: tp.Loaded = undefined,
    state: tp.Page = undefined,
    server: tp.Page = undefined,
    i: *island.Island(tp.Page, Fake) = undefined,

    fn init(p: *Page) !void {
        p.* = .{ .arena = .init(testing.allocator) };
        const a = p.arena.allocator();
        p.fake = .{ .a = a };
        p.rt = .init(a, &p.fake);
        p.l = .{ .m = tp.Demo.model(), .sc = undefined, .check = .{ .drafts = 3, .worst = 0 } };
        p.l.sc = try p.l.m.scorer(a);
        p.server = .init(&tp.Demo.head);
        const ix = try a.create(champsearch.Index);
        ix.* = try tp.searchIndex(a, &tp.Demo.head);
        p.server.useIndex(ix);
        p.state = p.server;
        const t = try a.create(tree.Tree);
        t.* = .{};
        var h: tree.H = .init(a, t);
        t.root = p.server.view(&h);
        p.fake.server = t;
        p.i = try p.rt.add(tp.Page, &p.state, &p.server, tp.sel);
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

    /// The DOM id of the `k`th node (document order) whose `name` is `value`
    fn nth(p: *Page, name: []const u8, value: []const u8, k: usize) u32 {
        const t = p.i.current();
        var left = k;
        const n = walk(t, t.root, name, value, &left) orelse @panic("no such node");
        return t.node(n).dom;
    }

    fn walk(t: *const tree.Tree, n: tree.N, name: []const u8, value: []const u8, left: *usize) ?tree.N {
        if (t.attr(n, name)) |v| if (std.mem.eql(u8, v, value)) {
            if (left.* == 0) return n;
            left.* -= 1;
        };
        for (t.kidsOf(n)) |c| if (walk(t, c, name, value, left)) |x| return x;
        return null;
    }

    fn click(p: *Page, target: u32) void {
        _ = p.rt.event(0, .{ .kind = .click, .target = target });
    }

    /// The other runtime's change: the fragment set, then its ui-hash
    fn hashed(p: *Page, s: []const u8) !void {
        p.fake.fragment.clearRetainingCapacity();
        try p.fake.fragment.appendSlice(p.arena.allocator(), s);
        p.rt.popstate();
    }

    fn deinit(p: *Page) void {
        p.arena.deinit();
    }
};

fn bansOf(ids: []const u32) [tp.n_ban]u32 {
    var out: [tp.n_ban]u32 = @splat(0);
    @memcpy(out[0..ids.len], ids);
    return out;
}

fn has(s: []const u8, want: []const u8) !void {
    if (std.mem.find(u8, s, want) == null) {
        std.debug.print("missing {s}\n", .{want});
        return error.TestExpectedEqual;
    }
}

test "the server renders the tester, clean, the model loading" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var s: tp.Page = .init(&tp.Demo.head);
    s.bin = "AAAA";
    var t: tree.Tree = .{};
    var h: tree.H = .init(a, &t);
    t.root = s.view(&h);
    var w: std.Io.Writer.Allocating = .init(a);
    try html.write(&t, t.root, &w.writer);
    try has(w.written(), "data-island=\"tester\"");
    try has(w.written(), "data-bin=\"AAAA\"");
    try has(w.written(), "Loading the model");
    const report = try check.run(a, &t, .{ .words = .off, .answer = .off });
    for (report.findings.items) |f| std.debug.print("{s}\n", .{f.msg});
    try testing.expectEqual(@as(usize, 0), report.findings.items.len);
}

test "seats chosen into the URL, a pick from it, moved to the other side, scored; Clear empties" {
    var p: Page = undefined;
    try p.init();
    defer p.deinit();
    try testing.expectEqual(@as(u32, 0), p.fake.warnings);
    _ = try p.shown();
    p.state.loads.set(.live, .{ .ready = &p.l });
    p.i.render();
    try has(try p.shown(), "Blue 50.5%");

    p.click(p.nth("aria-label", "Red Top, Empty seat", 0));
    try testing.expectEqual(@as(?u8, n_role), p.state.seat);
    try testing.expectEqualStrings("#s=5", p.fake.fragment.items);
    _ = try p.shown();
    try p.hashed("#b=266-0-0-0-0&o=fit");
    try testing.expectEqual(266, p.state.teams[0][0]);
    try testing.expect(p.state.seat == null);
    try testing.expect(p.state.dirty);
    const one = try p.shown();
    try has(one, "Aatrox");
    try has(one, "vs average");
    try testing.expect(std.mem.find(u8, one, "Blue 50.5%") == null);

    // A key it doesn't own (the panel's sort) stays as it was
    p.click(p.nth("aria-label", "Blue Jungle, Empty seat", 0));
    try testing.expectEqual(@as(?u8, 1), p.state.seat);
    try testing.expectEqualStrings("#o=fit&b=266-0-0-0-0&s=1", p.fake.fragment.items);
    // A second click on the chosen seat goes back to the first empty
    p.click(p.nth("aria-label", "Blue Jungle, Empty seat", 0));
    try testing.expect(p.state.seat == null);
    _ = try p.shown();

    // Red top takes Aatrox: blue top empties
    try p.hashed("#r=266-0-0-0-0");
    try testing.expectEqual(0, p.state.teams[0][0]);
    try testing.expectEqual(266, p.state.teams[1][0]);
    _ = try p.shown();

    p.click(p.nth("data-v", "quiet", 0));
    try testing.expectEqual(@as([2][n_role]u32, @splat(@splat(0))), p.state.teams);
    try testing.expectEqualStrings("#", p.fake.fragment.items);
    try has(try p.shown(), "Blue 50.5%");
}

test "bans: typed and taken off the board, into the URL and out of the panel's; lifted; Clear" {
    var p: Page = undefined;
    try p.init();
    defer p.deinit();
    p.state.loads.set(.live, .{ .ready = &p.l });
    p.i.render();
    try p.hashed("#b=266-0-0-0-0");
    _ = try p.shown();

    // Aatrox banned: off blue top, the first ban
    _ = p.rt.event(0, .{ .kind = .input, .target = p.nth("data-ref", "input", 0), .text = "aat" });
    _ = p.rt.event(0, .{ .kind = .keydown, .target = p.nth("data-ref", "input", 0), .text = "Enter" });
    try testing.expectEqual(266, p.state.bans[0]);
    try testing.expectEqual(0, p.state.teams[0][0]);
    try testing.expect(p.state.dirty);
    try testing.expectEqualStrings("#n=266-0-0-0-0-0-0-0-0-0", p.fake.fragment.items);
    try has(try p.shown(), "Remove the ban on Aatrox");
    _ = p.rt.event(0, .{ .kind = .input, .target = p.nth("data-ref", "input", 0), .text = "dar" });
    _ = p.rt.event(0, .{ .kind = .keydown, .target = p.nth("data-ref", "input", 0), .text = "Enter" });
    try testing.expectEqual(bansOf(&.{ 266, 122 }), p.state.bans);
    _ = try p.shown();

    // Lifted: the rest move up
    p.click(p.nth("aria-label", "Remove the ban on Aatrox", 0));
    try testing.expectEqual(bansOf(&.{122}), p.state.bans);
    _ = try p.shown();

    // A link's bans: unknown and repeated dropped, a picked one too
    try p.hashed("#b=122-0-0-0-0&n=999-266-266-122-0-0-0-0-0-0");
    try testing.expectEqual(bansOf(&.{266}), p.state.bans);
    _ = try p.shown();

    p.click(p.nth("data-v", "quiet", 0));
    try testing.expectEqual(bansOf(&.{}), p.state.bans);
    _ = try p.shown();
}

test "Random and Fill empty draw by play share, never a ban or a seat twice; Undo" {
    var p: Page = undefined;
    try p.init();
    defer p.deinit();
    var ev: tree.Event = .{ .kind = .click };
    // No model yet: nothing to draw from
    p.state.update(.random, &ev);
    try testing.expect(p.state.undo == null);
    p.state.loads.set(.live, .{ .ready = &p.l });
    p.i.render();

    // Darius banned: Aatrox, the only one left, to blue top; red top stays empty (the demo
    // has top only)
    try p.hashed("#n=122-0-0-0-0-0-0-0-0-0");
    p.state.update(.random, &ev);
    p.i.render();
    try testing.expectEqual([2][n_role]u32{ .{ 266, 0, 0, 0, 0 }, @splat(0) }, p.state.teams);
    try has(try p.shown(), "Undo");
    // Undo, before Clear
    p.click(p.nth("data-v", "quiet", 0));
    try testing.expectEqual([2][n_role]u32{ @splat(0), @splat(0) }, p.state.teams);
    try testing.expect(p.state.undo == null);
    _ = try p.shown();

    // Fill empty keeps red's pick
    try p.hashed("#r=266-0-0-0-0");
    p.state.update(.fill, &ev);
    try testing.expectEqual([2][n_role]u32{ .{ 122, 0, 0, 0, 0 }, .{ 266, 0, 0, 0, 0 } }, p.state.teams);
    // A pick from the panel drops Undo
    try p.hashed("#r=266-0-0-0-0");
    try testing.expect(p.state.undo == null);

    // Random redraws both: blue top Aatrox by its share, 0.6
    var aatrox: u32 = 0;
    for (0..200) |_| {
        p.state.update(.random, &ev);
        const t = p.state.teams;
        try testing.expect(t[0][0] != t[1][0] and t[0][0] != 0 and t[1][0] != 0);
        if (t[0][0] == 266) aatrox += 1;
    }
    try testing.expect(aatrox > 95 and aatrox < 145);
    p.i.render();
    _ = try p.shown();
}

test "the model Select switches, a failed model retries; tabs show terms and files" {
    var p: Page = undefined;
    try p.init();
    defer p.deinit();
    p.state.loads.set(.live, .{ .ready = &p.l });
    p.state.teams[0][0] = 266;
    p.i.render();

    // Comp: its file failed, chosen again it goes back to be fetched
    p.state.loads.set(.comp, .failed);
    p.click(p.nth("role", "option", 1));
    try testing.expectEqual(.comp, p.state.which);
    try testing.expectEqual(.none, std.meta.activeTag(p.state.loads.get(.comp)));
    try has(try p.shown(), "Loading the model");
    p.state.loads.set(.comp, .failed);
    p.i.render();
    try has(try p.shown(), "Could not load the model file");
    p.state.loads.set(.comp, .bad);
    p.i.render();
    try has(try p.shown(), "The model file is damaged");
    p.click(p.nth("role", "option", 0));
    try testing.expectEqual(.live, p.state.which);
    try has(try p.shown(), "Live model");

    // Tabs: the segmented buttons after the Select's
    p.click(p.nth("aria-pressed", "false", 0));
    try testing.expectEqual(.terms, p.state.tab);
    const terms = try p.shown();
    try has(terms, "Aatrox");
    try has(terms, "0.200");
    p.state.loads.set(.comp, .loading);
    p.click(p.nth("aria-pressed", "false", 1));
    try testing.expectEqual(.files, p.state.tab);
    try has(try p.shown(), "models/draft-model.bin: 3 reference drafts match");
    try has(try p.shown(), "lab/draft-model.bin: …");
    for ([_]struct { tp.Load, []const u8 }{
        .{ .none, "lab/draft-model.bin: not loaded" },
        .{ .failed, "lab/draft-model.bin: Could not load" },
        .{ .bad, "lab/draft-model.bin: The model file is damaged" },
    }) |c| {
        p.state.loads.set(.comp, c[0]);
        p.i.render();
        try has(try p.shown(), c[1]);
    }
    var off = p.l;
    off.check = .{ .drafts = 3, .worst = 2e-9 };
    p.state.loads.set(.comp, .{ .ready = &off });
    p.i.render();
    try has(try p.shown(), "lab/draft-model.bin: 3 reference drafts, worst 0.000000002 off");
    off.check = .{ .drafts = 0, .worst = 0 };
    p.i.render();
    try has(try p.shown(), "lab/draft-model.bin: no reference drafts");
}

test "restore: malformed leaves the page, unknown and repeated champions empty" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var p: tp.Page = .init(&tp.Demo.head);
    p.teams[0][1] = 122;
    const before = p.teams;
    for ([_][]const u8{
        "",
        "x",
        "1",
        "2 0,0,0,0,0,0,0,0,0,0",
        "0 0,0,0,0,0,0,0,0,0",
        "0 0,0,0,0,0,0,0,0,0,0,0",
        "0 a,0,0,0,0,0,0,0,0,0",
        "0 -1,0,0,0,0,0,0,0,0,0",
        "0 4294967296,0,0,0,0,0,0,0,0,0",
    }) |s| {
        tp.restore(&p, s);
        try testing.expectEqual(before, p.teams);
        try testing.expectEqual(.live, p.which);
    }
    tp.restore(&p, "1 266,999,0,0,0,266,122,0,0,4294967295");
    try testing.expectEqual(.comp, p.which);
    try testing.expectEqual([_][n_role]u32{ .{ 266, 0, 0, 0, 0 }, .{ 0, 122, 0, 0, 0 } }, p.teams);
    // Bans: short or long refused; a picked one dropped
    tp.restore(&p, "0 0,0,0,0,0,0,0,0,0,0 266");
    try testing.expectEqual(.comp, p.which);
    tp.restore(&p, "0 0,0,0,0,0,0,0,0,0,0 0,0,0,0,0,0,0,0,0,0,0");
    try testing.expectEqual(.comp, p.which);
    tp.restore(&p, "0 0,122,0,0,0,0,0,0,0,0 122,0,266,0,0,0,0,0,0,0");
    try testing.expectEqual(.live, p.which);
    try testing.expectEqual(bansOf(&.{266}), p.bans);
    var w: std.Io.Writer.Allocating = .init(arena.allocator());
    try tp.saved(&p, &w.writer);
    try testing.expectEqualStrings("0 0,122,0,0,0,0,0,0,0,0 266,0,0,0,0,0,0,0,0,0", w.written());
}

test "the saved board: taken on a page opened without one, a linked model kept" {
    const server: tp.Page = .init(&tp.Demo.head);
    const saved = "0 266,0,0,0,0,122,0,0,0,0";
    var p = server;
    p.which = .comp;
    p.tab = .terms;
    try testing.expect(tp.restoreSaved(&p, &server, "#m=comp&t=terms", saved));
    try testing.expectEqual(.comp, p.which);
    try testing.expectEqual(266, p.teams[0][0]);
    p = server;
    try testing.expect(tp.restoreSaved(&p, &server, "", "1 266,0,0,0,0,122,0,0,0,0"));
    try testing.expectEqual(.comp, p.which);
    // The default model linked: kept too
    p = server;
    try testing.expect(tp.restoreSaved(&p, &server, "#t=terms&m=live", "1 266,0,0,0,0,122,0,0,0,0"));
    try testing.expectEqual(.live, p.which);
    p = server;
    p.teams[1][0] = 266;
    try testing.expect(!tp.restoreSaved(&p, &server, "#r=266-0-0-0-0", saved));
    try testing.expectEqual([_][n_role]u32{ @splat(0), .{ 266, 0, 0, 0, 0 } }, p.teams);
}

fn refused(a: std.mem.Allocator, bytes: []const u8) !void {
    if (tp.Loaded.init(a, bytes)) |_| return error.TestUnexpectedResult else |_| {}
}

test "a model file: bad bytes refused, the demo's round trip scores" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try testing.expectError(error.Truncated, tp.Loaded.init(a, ""));
    try refused(a, "<!doctype html><title>Sign in</title>");
    var raw: std.ArrayList(u8) = .empty;
    try data.encode(a, td.Model, tp.Demo.model(), &raw);
    const l = try tp.Loaded.init(a, raw.items);
    try testing.expectEqual(0, l.check.drafts);
    try testing.expectApproxEqAbs(1 / (1 + @exp(@as(f64, -0.02))), l.sc.blue(@splat(@splat(0))).p, 1e-9);
    try refused(a, raw.items[0 .. raw.items.len / 2]);
}
