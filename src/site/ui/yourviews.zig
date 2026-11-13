//! The Your games page's head (your.html, docs/plan/ui/your-games.md "Structure"):
//! PlayerBar with the views' tabs and the filter row as its bands, then the chosen view.
//! The Games view is YourList, Over time YourTime and Friends YourFriends, the next
//! islands on the page, each hidden in the other views (CSS: the DOM order is the reading order). Island YourViews
//! (ui-yourviews.wasm). It and YourList both hold the filter, each writing q/role/champ
//! and reading the other's presses from the URL
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const yl = @import("yourlist.zig");
const yp = @import("yourpage.zig");
const playerbar = @import("playerbar.zig");
const highlights = @import("highlights.zig");
const yourtime = @import("yourtime.zig");
const tabs = @import("tabs.zig");
const segmented = @import("segmented.zig");
const rolepicker = @import("rolepicker.zig");
const gamerow = @import("gamerow.zig");
const role = @import("role.zig");
const homepage = @import("homepage.zig");
const url = @import("url.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;
const Role = role.Role;

pub const name = "YourViews";
pub const scope = .{".c-yviews"};
pub const sel = "[data-island=yourviews]";

pub const View = enum { games, highlights, time, friends };

/// The views on the page: each one's tab once it is built; one view shows no tabs.
/// Friends only for a looked-up player: the example has none
pub const shipped = [_]View{ .games, .highlights, .time };
pub const looked_up = [_]View{ .games, .highlights, .time, .friends };
pub const every = looked_up;

const W = struct {
    pub const views = plain("Views");
    pub const games = plain("Games");
    pub const highlights = plain("Highlights");
    pub const time = plain("Over time");
    pub const friends = plain("Friends");
    pub const none = plain("No games match");
    pub const queue = plain("Queue");
    pub const role = plain("Role");
    pub const example_role = plain("Example's role");
    pub const all = plain("All");
};

pub const YourViews = struct {
    l: *const yl.List,
    filter: yl.Filter = .{},
    tab: View = .games,
    views: []const View = &shipped,
    /// game.html, relative to the page
    game: []const u8 = "/game",
    /// A looked-up player's Riot ID, percent-encoded; "" the example
    id: []const u8 = "",
    /// Minutes east of UTC, for the records' dates; the server's: UTC
    tz_min: i32 = 0,
    /// The example's roles with a list (homepage.your_list_dir): the role icons switch
    /// the example's player in place of filtering
    roles: [5]bool = @splat(false),
    /// The example's role asked for (the URL's), shown once its list is in (the island)
    want: ?Role = null,
    /// Set by the island once in: the example's role switch works
    live: bool = false,

    const P = @This();

    pub const Url = struct { view: View = .games, q: ?yl.Queue = null, role: ?Role = null, champ: url.Str(24) = .{}, example: ?Role = null };

    pub const Msg = union(enum) { view: View, queue: u8, role: ?Role, example: Role };

    pub fn toUrl(p: *const P) Url {
        const f = yp.urlOf(p.l, p.filter);
        return .{ .view = p.tab, .q = f.q, .role = f.role, .champ = f.champ, .example = p.want };
    }

    /// A view not on the page is Games
    pub fn fromUrl(p: *P, u: Url) void {
        p.tab = if (p.has(u.view)) u.view else .games;
        p.filter = yp.filterOf(p.l, .{ .q = u.q, .role = u.role, .champ = u.champ });
        p.want = u.example;
    }

    /// The example's role switch in place of the role filter: the example, with roles
    fn switches(p: *const P) bool {
        return p.id.len == 0 and std.mem.findScalar(bool, &p.roles, true) != null;
    }

    /// The example's role shown: its games' (one player, one role)
    pub fn shown(p: *const P) ?Role {
        return if (p.l.games.len > 0) p.l.games[0].role else null;
    }

    pub fn update(p: *P, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .view => |v| if (p.has(v)) {
                p.tab = v;
            },
            .queue => |i| {
                if (i >= yp.queues.len) return;
                p.filter.queue = yp.queues[i];
            },
            .role => |r| p.filter.role = r,
            .example => |r| if (p.roles[@backingInt(r)]) {
                p.want = r;
            },
        }
        ev.push = true;
    }

    fn has(p: *const P, v: View) bool {
        return std.mem.findScalar(View, p.views, v) != null;
    }

    pub fn view(p: *P, h: *H) N {
        var kept: std.ArrayList(yl.Game) = .empty;
        for (p.l.games) |g| if (p.filter.keeps(g)) kept.append(h.mem, g) catch {
            h.oom = true;
            return .none;
        };
        const to: highlights.Links = .{ .page = p.game, .id = p.id, .tz_min = p.tz_min };
        return h.div(.{
            .class = "c-yviews",
            .data_island = "yourviews",
            .data_view = @tagName(p.tab),
            .data_roles = if (p.switches()) homepage.rolesMask(p.roles) else null,
        }, .{
            playerbar.view(h, p.l, .{ .games = kept.items, .bands = &.{ if (p.views.len > 1) p.tabBand(h) else .none, p.filters(h) } }),
            switch (p.tab) {
                .games => h.div(.{ .class = "cards" }, .{
                    highlights.top(h, p.l, kept.items, to, if (p.has(.highlights)) h.on(p, .{ .view = .highlights }) else null),
                    if (p.has(.time)) yourtime.summary(h, kept.items, h.on(p, .{ .view = .time })) else null,
                }),
                .highlights => h.div(.{ .class = "view", .role = "tabpanel" }, .{
                    if (kept.items.len == 0) h.p(.{ .class = "note" }, .{W.none}) else highlights.view(h, p.l, kept.items, to),
                }),
                // YourTime's and YourFriends' islands
                .time, .friends => .none,
            },
        });
    }

    fn tabBand(p: *P, h: *H) N {
        var items: [every.len]tabs.Item = undefined;
        for (items[0..p.views.len], p.views) |*it, v| {
            const label = switch (v) {
                .games => W.games,
                .highlights => W.highlights,
                .time => W.time,
                .friends => W.friends,
            };
            it.* = .{ .label = label, .selected = p.tab == v, .on = h.on(p, .{ .view = v }) };
        }
        return tabs.view(h, W.views, items[0..p.views.len], &.{});
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
        const ex = p.switches();
        rs[0] = .{ .role = null, .current = f.role == null, .on = h.on(p, .{ .role = null }) };
        for (rs[1..], Role.all) |*it, r| {
            var x = f;
            x.role = r;
            it.* = if (ex) .{
                .role = r,
                .current = r == p.want orelse p.shown(),
                .disabled = !p.live or !p.roles[@backingInt(r)],
                .on = h.on(p, .{ .example = r }),
            } else .{ .role = r, .current = f.role == r, .disabled = !yp.any(p.l.games, x), .on = h.on(p, .{ .role = r }) };
        }
        return h.div(.{ .class = "filters" }, .{
            segmented.view(h, .{ .s = .s, .label = W.queue }, &qs),
            rolepicker.view(h, .{ .v = .compact, .label = if (ex) W.example_role else W.role }, if (ex) rs[1..] else &rs),
        });
    }
};

pub const css =
    \\@layer components {
    \\  .c-yviews { display: grid; gap: var(--sp-3); }
    \\  .c-yviews .filters { display: flex; flex-wrap: wrap; align-items: center; gap: var(--sp-3); padding: var(--sp-2) var(--sp-4); }
    \\  .c-yviews .note { margin: 0; color: var(--muted); font-size: var(--fs-s); }
    \\  .c-yviews > .cards { display: grid; grid-template-columns: minmax(0, 3fr) minmax(0, 1fr); gap: var(--sp-2); }
    \\  .c-yviews:not([data-view="games"]) ~ [data-island="your"] { display: none; }
    \\  .c-yviews:not([data-view="time"]) ~ [data-island="yourtime"] { display: none; }
    \\  .c-yviews:not([data-view="friends"]) ~ [data-island="yourfriends"] { display: none; }
    \\  @media (max-width: 760px) {
    \\    .c-yviews > .cards { grid-template-columns: minmax(0, 1fr); }
    \\    /* Two tiles a row: a third would sit alone */
    \\    .c-yviews .c-hl[data-top] .c-rtile:nth-child(3) { display: none; }
    \\  }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const demo = struct {
        var games: YourViews = .{ .l = &yp.demo.list };
        var flex: YourViews = .{ .l = &yp.demo.list, .filter = .{ .queue = .flex } };
        var highlights: YourViews = .{ .l = &yp.demo.list, .tab = .highlights, .views = &every };
        var empty: YourViews = .{ .l = &yp.demo.list, .tab = .highlights, .filter = .{ .queue = .draft } };
    };
    g.addFill("Games, all queues", demo.games.view(h));
    g.addFill("Flex only", demo.flex.view(h));
    g.addFill("every view, Highlights", demo.highlights.view(h));
    g.addFill("Highlights, a filter without games", demo.empty.view(h));
}

const testing = std.testing;

test "tabs and filter row: the bar's figures follow the filter, the URL carries both" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    var p: YourViews = .{ .l = &yp.demo.list, .views = &every };
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

test "the Games view's three records open Highlights; Highlights groups them" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    var p: YourViews = .{ .l = &yp.demo.list, .id = "MeioNeiz%23EUW" };
    var n = p.view(&h);
    const top = t.find(n, "data-top", null).?;
    try testing.expect(t.find(top, "class", "more") != null);
    // A lookup's game by start
    try testing.expect(std.mem.startsWith(u8, t.attr(t.find(top, "class", "chip").?, "href").?, "/game#id=MeioNeiz%23EUW&game="));
    p.tab = .highlights;
    n = p.view(&h);
    try testing.expect(t.find(n, "data-top", null) == null);
    try testing.expect(t.find(n, "class", "grp") != null);
    // A filter without games says so
    p.filter = .{ .queue = .draft };
    n = p.view(&h);
    try testing.expect(t.find(n, "class", "grp") == null);
    try testing.expect(t.find(n, "class", "note") != null);
    try testing.expect(!h.oom);
}

test "only built views: no tabs for one, another's URL shows Games" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    var p: YourViews = .{ .l = &yp.demo.list, .views = &.{.games} };
    var ev: tree.Event = .{ .kind = .click };
    p.fromUrl(.{ .view = .highlights, .q = .flex });
    try testing.expectEqual(.games, p.tab);
    try testing.expectEqual(.flex, p.filter.queue);
    p.update(.{ .view = .time }, &ev);
    try testing.expectEqual(.games, p.tab);
    const n = p.view(&h);
    try testing.expectEqual(null, t.find(n, "role", "tablist"));
    try testing.expectEqualStrings("games", t.attr(n, "data-view").?);
}

test "the example's role icons switch its player: no All, off until live, the URL keeps it" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    var p: YourViews = .{ .l = &yp.demo.list, .roles = .{ true, true, true, false, false } };
    var ev: tree.Event = .{ .kind = .click };
    var n = p.view(&h);
    try testing.expectEqualStrings("7", t.attr(n, "data-roles").?);
    const g = t.find(n, "class", "c-roles").?;
    try testing.expectEqualStrings("Example's role", t.attr(g, "aria-label").?);
    try testing.expectEqual(5, t.count(g, "type"));
    // The server's: every role off, mid (the list's) pressed
    try testing.expectEqual(5, t.count(g, "aria-disabled"));
    try testing.expectEqualStrings("true", t.attr(t.find(g, "aria-label", "Mid").?, "aria-pressed").?);
    p.live = true;
    n = p.view(&h);
    try testing.expectEqual(2, t.count(t.find(n, "class", "c-roles").?, "aria-disabled"));
    // A role without a list stays put; one with asks for it, the URL carries it
    p.update(.{ .example = .bot }, &ev);
    try testing.expectEqual(null, p.want);
    p.update(.{ .example = .top }, &ev);
    try testing.expectEqual(.top, p.want);
    try testing.expectEqual(.top, p.toUrl().example);
    p.want = null;
    p.fromUrl(.{ .example = .jungle });
    try testing.expectEqual(.jungle, p.want);
    // A lookup's list: the role filter as before
    p.id = "MeioNeiz%23EUW";
    n = p.view(&h);
    try testing.expectEqual(null, t.attr(n, "data-roles"));
    try testing.expectEqual(6, t.count(t.find(n, "class", "c-roles").?, "type"));
    try testing.expect(!h.oom);
}
