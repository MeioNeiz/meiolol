//! The tree and its HTML backend, driven as components use them: build, write, click
const std = @import("std");
const tree = @import("tree.zig");
const html = @import("html.zig");
const testing = std.testing;

const Fixture = struct {
    arena: std.heap.ArenaAllocator,
    t: tree.Tree = .{},
    h: tree.H = undefined,

    fn init(f: *Fixture) void {
        f.* = .{ .arena = .init(testing.allocator) };
        f.h = .init(f.arena.allocator(), &f.t);
    }

    fn out(f: *Fixture, n: tree.N) []const u8 {
        var w: std.Io.Writer.Allocating = .init(f.arena.allocator());
        html.write(&f.t, n, &w.writer) catch unreachable;
        return w.written();
    }
};

/// Send `ev` to node `n`'s handler, as ui.wasm does after bubbling
fn send(t: *const tree.Tree, n: tree.N, ev: tree.Event) void {
    var e = ev;
    const hd = t.handler(n, e.kind).?;
    hd.call(hd.target, &hd.msg, &e);
}

test "escaping and the URL check hold in both backends" {
    var f: Fixture = undefined;
    f.init();
    defer f.arena.deinit();
    const h = &f.h;
    const evil: []const u8 = "javascript:alert(1)";
    f.t.root = h.a(.{ .href = evil, .title = "a\"b" }, .{"<script>&"});
    try testing.expectEqualStrings("<a href=\"about:invalid#tpl\" title=\"a&quot;b\">&lt;script&gt;&amp;</a>", f.out(f.t.root));
    // The DOM backend reads the checked value too: it is what the tree stores
    try testing.expectEqualStrings("about:invalid#tpl", f.t.attr(f.t.root, "href").?);
    // A literal is checked at compile time the same way
    const lit = h.a(.{ .href = "javascript:x" }, .{});
    try testing.expectEqualStrings("about:invalid#tpl", f.t.attr(lit, "href").?);
}

// Values known at compile time come first (one static array per call site), then the rest
test "attribute values: numbers, flags, aria, enums, classes and vars" {
    var f: Fixture = undefined;
    f.init();
    defer f.arena.deinit();
    const h = &f.h;
    const games: u32 = 8068;
    const thin = true;
    const n = h.div(.{
        .class = h.cls("row", .{ .thin = thin, .off = !thin }),
        .data_games = games,
        .hidden = false,
        .open = true,
        .aria_expanded = false,
        .data_role = @as(enum { mid, top }, .mid),
        .style = h.vars(.{ .p0 = 31.5, .w = @as(f32, 2.0 / 3.0) }),
        .colspan = 9,
        .title = @as(?[]const u8, null),
    }, .{});
    try testing.expectEqualStrings(
        "<div data-games=\"8068\" open=\"\" aria-expanded=\"false\" data-role=\"mid\" colspan=\"9\" class=\"row thin\" style=\"--p0:31.5;--w:0.67\"></div>",
        f.out(n),
    );
    try testing.expectEqual(@as(?[]const u8, null), f.t.attr(h.span(.{ .class = h.cls("", .{ .x = false }) }, .{}), "class"));
}

test "neighbouring text merges into one node; text beside text is kept apart for hydration" {
    var f: Fixture = undefined;
    f.init();
    defer f.arena.deinit();
    const h = &f.h;
    const n = h.p(.{}, .{ "Ahri ", 52.25, "% in ", @as(u32, 1200), " games", h.b(.{}, .{"!"}) });
    try testing.expectEqual(@as(usize, 2), f.t.kidsOf(n).len);
    try testing.expectEqualStrings("<p>Ahri 52.25% in 1200 games<b>!</b></p>", f.out(n));
    // Text nodes made apart (two lists joined) get a comment between them
    const a = h.text("a");
    const b = h.text("b");
    const two = h.span(.{}, .{ a, b });
    try testing.expectEqualStrings("<span>a<!---->b</span>", f.out(two));
    const none: ?tree.N = null;
    try testing.expectEqualStrings("<ul><li>x</li></ul>", f.out(h.ul(.{}, .{ none, h.li(.{}, .{"x"}) })));
}

test "void and svg elements" {
    var f: Fixture = undefined;
    f.init();
    defer f.arena.deinit();
    const h = &f.h;
    const n = h.div(.{}, .{
        h.img(.{ .src = "icons/ahri.png", .alt = "" }),
        h.svg(.{ .viewBox = "0 0 10 10" }, .{h.path(.{ .d = "M0 0L10 10" }, .{})}),
    });
    try testing.expectEqualStrings(
        "<div><img src=\"icons/ahri.png\" alt=\"\"><svg viewBox=\"0 0 10 10\"><path d=\"M0 0L10 10\"></path></svg></div>",
        f.out(n),
    );
    try testing.expect(tree.Tag.path.isSvg() and !tree.Tag.div.isSvg());
}

const Counter = struct {
    n: i32 = 0,
    last: u8 = 0,

    pub const Msg = union(enum) { add: i32, key: u8 };

    pub fn update(c: *Counter, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .add => |d| c.n += d,
            .key => |k| c.last = k,
        }
        ev.handled = true;
    }

    pub fn view(c: *Counter, h: *tree.H) tree.N {
        var rows = h.list();
        for (0..3) |i| rows.add(h.li(.{ .key = i, .on_click = h.on(c, .{ .add = @intCast(i + 1) }) }, .{i}));
        return h.div(.{ .on_keydown = h.on(c, .{ .key = 'k' }), .on_click = h.on(c, .{ .add = 100 }) }, .{
            h.ul(.{}, .{rows.done()}),
            c.n,
        });
    }
};

test "handlers carry typed messages, one per event kind, and keys reach the nodes" {
    var f: Fixture = undefined;
    f.init();
    defer f.arena.deinit();
    var c: Counter = .{};
    const root = c.view(&f.h);
    f.t.root = root;
    try testing.expect(!f.h.oom);
    const ul = f.t.kidsOf(root)[0];
    const li = f.t.kidsOf(ul)[2];
    try testing.expectEqual(@as(u32, 3), f.t.node(li).key);
    send(&f.t, li, .{ .kind = .click });
    send(&f.t, root, .{ .kind = .click });
    send(&f.t, root, .{ .kind = .keydown });
    try testing.expectEqual(@as(i32, 103), c.n);
    try testing.expectEqual(@as(u8, 'k'), c.last);
    try testing.expectEqual(@as(?*tree.Handler, null), f.t.handler(li, .keydown));
    try testing.expectEqual(f.t.root, @as(tree.N, @fromBackingInt(f.t.node(ul).parent)));
    try testing.expectEqual(ul, f.t.find(root, "data-x", null) orelse ul);
    try testing.expectEqualStrings("<div><ul><li>0</li><li>1</li><li>2</li></ul>0</div>", f.out(root));
}
