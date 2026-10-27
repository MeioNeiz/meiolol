//! The Your games page's head (games.html, docs/plan/ui/your-games.md "Structure"):
//! PlayerBar with the views' tabs and the filter row as its bands, then the chosen view.
//! The Games view is YourList, the next island on the page, hidden in the others (CSS:
//! the DOM order is the reading order). Island YourViews (ui-yourviews.wasm). It and
//! YourList both hold the filter, each writing q/role/champ and reading the other's
//! presses from the URL
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const yl = @import("yourlist.zig");
const yp = @import("yourpage.zig");
const playerbar = @import("playerbar.zig");
const tabs = @import("tabs.zig");
const segmented = @import("segmented.zig");
const rolepicker = @import("rolepicker.zig");
const gamerow = @import("gamerow.zig");
const role = @import("role.zig");
const url = @import("url.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;
const Role = role.Role;

pub const name = "YourViews";
pub const scope = .{".c-yviews"};
pub const sel = "[data-island=yourviews]";

pub const View = enum { games, highlights, time };

const W = struct {
    pub const views = plain("Views");
    pub const games = plain("Games");
    pub const highlights = plain("Highlights");
    pub const time = plain("Over time");
    pub const soon = plain("Coming soon.");
    pub const queue = plain("Queue");
    pub const role = plain("Role");
    pub const all = plain("All");
};

pub const YourViews = struct {
    l: *const yl.List,
    filter: yl.Filter = .{},
    tab: View = .games,

    const P = @This();

    pub const Url = struct { view: View = .games, q: ?yl.Queue = null, role: ?Role = null, champ: url.Str(24) = .{} };

    pub const Msg = union(enum) { view: View, queue: u8, role: ?Role };

    pub fn toUrl(p: *const P) Url {
        const f = yp.urlOf(p.l, p.filter);
        return .{ .view = p.tab, .q = f.q, .role = f.role, .champ = f.champ };
    }

    pub fn fromUrl(p: *P, u: Url) void {
        p.tab = u.view;
        p.filter = yp.filterOf(p.l, .{ .q = u.q, .role = u.role, .champ = u.champ });
    }

    pub fn update(p: *P, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .view => |v| p.tab = v,
            .queue => |i| {
                if (i >= yp.queues.len) return;
                p.filter.queue = yp.queues[i];
            },
            .role => |r| p.filter.role = r,
        }
        ev.push = true;
    }

    pub fn view(p: *P, h: *H) N {
        var kept: std.ArrayList(yl.Game) = .empty;
        for (p.l.games) |g| if (p.filter.keeps(g)) kept.append(h.mem, g) catch {
            h.oom = true;
            return .none;
        };
        return h.div(.{ .class = "c-yviews", .data_island = "yourviews", .data_view = @tagName(p.tab) }, .{
            playerbar.view(h, p.l, .{ .games = kept.items, .bands = &.{ p.tabBand(h), p.filters(h) } }),
            if (p.tab != .games) h.div(.{ .class = "panel", .role = "tabpanel" }, .{h.p(.{ .class = "note" }, .{W.soon})}) else null,
        });
    }

    fn tabBand(p: *P, h: *H) N {
        var items: [3]tabs.Item = undefined;
        for (&items, [_]View{ .games, .highlights, .time }, [_]tree.Text{ W.games, W.highlights, W.time }) |*it, v, label| {
            it.* = .{ .label = label, .selected = p.tab == v, .on = h.on(p, .{ .view = v }) };
        }
        return tabs.view(h, W.views, &items, &.{});
    }

    /// Queue chips and role icons; a choice without games is shown but not choosable
    fn filters(p: *P, h: *H) N {
        const f = p.filter;
        var qs: [yp.queues.len]segmented.Item = undefined;
        for (&qs, yp.queues, 0..) |*it, q, i| {
            var x = f;
            x.queue = q;
            it.* = .{
                .label = if (q) |v| gamerow.queueName(v) else W.all,
                .on = h.on(p, .{ .queue = @intCast(i) }),
                .selected = f.queue == q,
                .disabled = !yp.any(p.l.games, x),
            };
        }
        var rs: [Role.all.len + 1]rolepicker.Item = undefined;
        rs[0] = .{ .role = null, .current = f.role == null, .on = h.on(p, .{ .role = null }) };
        for (rs[1..], Role.all) |*it, r| {
            var x = f;
            x.role = r;
            it.* = .{ .role = r, .current = f.role == r, .disabled = !yp.any(p.l.games, x), .on = h.on(p, .{ .role = r }) };
        }
        return h.div(.{ .class = "filters" }, .{
            segmented.view(h, .{ .s = .s, .label = W.queue }, &qs),
            rolepicker.view(h, .{ .v = .compact, .label = W.role }, &rs),
        });
    }
};

pub const css =
    \\@layer components {
    \\  .c-yviews { display: grid; gap: var(--sp-3); }
    \\  .c-yviews .filters { display: flex; flex-wrap: wrap; align-items: center; gap: var(--sp-3); padding: var(--sp-2) var(--sp-4); }
    \\  .c-yviews .note { margin: 0; color: var(--muted); font-size: var(--fs-s); }
    \\  .c-yviews:not([data-view="games"]) ~ [data-island="your"] { display: none; }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const demo = struct {
        var games: YourViews = .{ .l = &yp.demo.list };
        var flex: YourViews = .{ .l = &yp.demo.list, .filter = .{ .queue = .flex } };
        var highlights: YourViews = .{ .l = &yp.demo.list, .tab = .highlights };
    };
    g.addFill("Games, all queues", demo.games.view(h));
    g.addFill("Flex only", demo.flex.view(h));
    g.addFill("Highlights", demo.highlights.view(h));
}

const testing = std.testing;

test "tabs and filter row: the bar's figures follow the filter, the URL carries both" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    var p: YourViews = .{ .l = &yp.demo.list };
    var ev: tree.Event = .{ .kind = .click };

    var n = p.view(&h);
    try testing.expectEqualStrings("games", t.attr(n, "data-view").?);
    try testing.expectEqual(null, t.find(n, "role", "tabpanel"));
    // All 10 games in the form strip, then flex's 2
    try testing.expectEqual(10, t.count(t.find(n, "class", "c-form").?, "data-r"));
    p.update(.{ .queue = 2 }, &ev);
    try testing.expect(ev.push);
    n = p.view(&h);
    try testing.expectEqual(2, t.count(t.find(n, "class", "c-form").?, "data-r"));
    try testing.expectEqual(.flex, p.toUrl().q);

    p.update(.{ .view = .highlights }, &ev);
    n = p.view(&h);
    try testing.expectEqualStrings("highlights", t.attr(n, "data-view").?);
    try testing.expect(t.find(n, "role", "tabpanel") != null);
    try testing.expectEqual(.highlights, p.toUrl().view);

    // Back to a URL: the view and the filter, an unplayed champion dropped
    var u: YourViews.Url = .{ .view = .time, .role = .mid };
    u.champ.set("Karthus");
    p.fromUrl(u);
    try testing.expectEqual(.time, p.tab);
    try testing.expectEqual(null, p.filter.champ);
    try testing.expectEqual(.mid, p.filter.role);
    try testing.expect(!h.oom);
}
