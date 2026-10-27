//! The Your games page (games.html, docs/plan/ui/your-games.md "Games"): PlayerBar with
//! the filter row under it, ProfileSummary beside the list, the games as day groups of
//! GameRow, "Show older" at the foot. Island YourList (ui-your.wasm); the filter is in
//! the URL. The server renders without a clock (dates, no "Today" or "2h ago": the page
//! stays the same all day); the island adds them in the visitor's zone
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const yl = @import("yourlist.zig");
const playerbar = @import("playerbar.zig");
const profilesum = @import("profilesum.zig");
const dayhead = @import("dayhead.zig");
const gamerow = @import("gamerow.zig");
const segmented = @import("segmented.zig");
const rolepicker = @import("rolepicker.zig");
const button = @import("button.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;
const Role = role.Role;

pub const name = "YourList";
pub const scope = .{".c-your"};
pub const sel = "[data-island=your]";

/// Day groups a "Show older" press adds
const step = 7;

const W = struct {
    pub const queue = plain("Queue");
    pub const role = plain("Role");
    pub const all = plain("All");
    pub const older = plain("Show older");
    pub const none = plain("No games match");
};

const queues = [_]?yl.Queue{ null, .solo, .flex, .draft, .swift };

pub const YourList = struct {
    l: *const yl.List,
    /// ui.data of `l`: the island's copy
    bin: []const u8 = "",
    /// Holds the filter: its presses and the filter row's set the same state
    sum: profilesum.ProfileSummary = .{},
    /// Day groups shown
    shown: u16 = step,
    /// The visitor's clock; none on the server
    now_ms: ?i64 = null,
    /// Minutes east of UTC
    tz_min: i32 = 0,
    /// game.html, relative to the page
    game: []const u8 = "game.html",

    const P = @This();

    pub const Url = struct { q: ?yl.Queue = null, role: ?Role = null, champ: ?u16 = null };

    pub const Msg = union(enum) { queue: u8, role: ?Role, older, filtered };

    pub fn toUrl(p: *const P) Url {
        const f = p.sum.filter;
        return .{ .q = f.queue, .role = f.role, .champ = f.champ };
    }

    pub fn fromUrl(p: *P, u: Url) void {
        const c = if (u.champ) |c| (if (c < p.l.champs.len) c else null) else null;
        p.sum.filter = .{ .queue = u.q, .role = u.role, .champ = c };
    }

    pub fn update(p: *P, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .queue => |i| if (i < queues.len) {
                p.sum.filter.queue = queues[i];
            },
            .role => |r| p.sum.filter.role = r,
            .older => {
                p.shown +|= step;
                return;
            },
            .filtered => {},
        }
        p.shown = step;
        ev.push = true;
    }

    /// The row's game: its page on game.html; none without one
    fn href(p: *const P, h: *H, g: yl.Game) ?[]const u8 {
        const i = g.page orelse return null;
        return h.fmt("{s}#g={d}", .{ p.game, i });
    }

    pub fn view(p: *P, h: *H) N {
        const l = p.l;
        const f = p.sum.filter;
        p.sum.on_change = h.on(p, .filtered);
        const days = yl.days(h.mem, l.games, f, p.tz_min) catch return oom(h);
        var kept: std.ArrayList(yl.Game) = .empty;
        for (l.games) |g| if (f.keeps(g)) kept.append(h.mem, g) catch return oom(h);
        const today = if (p.now_ms) |ms| yl.dayOf(ms, p.tz_min) else std.math.maxInt(i32);

        var groups = h.list();
        for (days[0..@min(days.len, p.shown)]) |d| {
            var rows = h.list();
            for (d.games) |i| {
                const g = l.games[i];
                rows.add(gamerow.view(h, l, g, .{ .href = p.href(h, g), .now_ms = p.now_ms }));
            }
            groups.add(h.el(.section, .{ .key = @as(u32, @bitCast(d.day)), .class = "day", .data_day = d.day }, .{ dayhead.view(h, d, today), rows.done() }));
        }
        return h.div(.{
            .class = "c-your",
            .data_island = "your",
            .data_bin = if (p.bin.len > 0) p.bin else null,
        }, .{
            playerbar.view(h, l, .{ .games = kept.items, .bands = &.{p.filters(h)} }),
            h.div(.{ .class = "cols" }, .{
                p.sum.view(h, l, l.games),
                h.div(.{ .class = "list" }, .{
                    if (days.len == 0) h.p(.{ .class = "none" }, .{W.none}) else null,
                    groups.done(),
                    if (days.len > p.shown) button.view(h, .{ .on = h.on(p, .older) }, .{W.older}) else null,
                }),
            }),
        });
    }

    /// Queue chips and role icons; a choice without games is shown but not choosable
    fn filters(p: *P, h: *H) N {
        const f = p.sum.filter;
        var qs: [queues.len]segmented.Item = undefined;
        for (&qs, queues, 0..) |*it, q, i| {
            var x = f;
            x.queue = q;
            it.* = .{
                .label = if (q) |v| gamerow.queueName(v) else W.all,
                .on = h.on(p, .{ .queue = @intCast(i) }),
                .selected = f.queue == q,
                .disabled = !any(p.l.games, x),
            };
        }
        var rs: [Role.all.len + 1]rolepicker.Item = undefined;
        rs[0] = .{ .role = null, .current = f.role == null, .on = h.on(p, .{ .role = null }) };
        for (rs[1..], Role.all) |*it, r| {
            var x = f;
            x.role = r;
            it.* = .{ .role = r, .current = f.role == r, .disabled = !any(p.l.games, x), .on = h.on(p, .{ .role = r }) };
        }
        return h.div(.{ .class = "filters" }, .{
            segmented.view(h, .{ .s = .s, .label = W.queue }, &qs),
            rolepicker.view(h, .{ .v = .compact, .label = W.role }, &rs),
        });
    }
};

fn any(games: []const yl.Game, f: yl.Filter) bool {
    for (games) |g| if (f.keeps(g)) return true;
    return false;
}

fn oom(h: *H) N {
    h.oom = true;
    return .none;
}

pub const css =
    \\@layer components {
    \\  .c-your { display: grid; gap: var(--sp-3); }
    \\  .c-your > .cols { display: grid; grid-template-columns: 288px minmax(0, 1fr); gap: var(--sp-3); align-items: start; }
    \\  .c-your .filters { display: flex; flex-wrap: wrap; align-items: center; gap: var(--sp-3); padding: var(--sp-2) var(--sp-4); }
    \\  .c-your .list { display: grid; grid-template-columns: minmax(0, 1fr); gap: var(--sp-3); min-width: 0; }
    \\  /* GameRow's layouts follow its container's width */
    \\  .c-your .day { container-type: inline-size; display: grid; grid-template-columns: minmax(0, 1fr); gap: var(--sp-1); }
    \\  .c-your .none { margin: 0; padding: var(--sp-4); color: var(--faint); }
    \\  .c-your .list > .c-btn { justify-self: center; }
    \\  @media (max-width: 1000px) {
    \\    .c-your > .cols { grid-template-columns: minmax(0, 1fr); }
    \\  }
    \\}
    \\
;

const demo = struct {
    const champs = [_]champ.Champ{ .{ .name = "Aurelion Sol", .src = "" }, .{ .name = "Karthus", .src = "" } };
    const day_ms = std.time.ms_per_day;
    const now: i64 = 20_000 * day_ms + 20 * std.time.ms_per_hour;
    const games = blk: {
        const results = "wwlwlwwlwl";
        var gs: [results.len]yl.Game = undefined;
        for (&gs, results, 0..) |*x, r, i| x.* = .{
            .start_ms = now - @as(i64, i / 3) * day_ms - @as(i64, i % 3 + 1) * std.time.ms_per_hour,
            .dur = 1800,
            .patch = "16.21",
            .queue = if (i % 4 == 3) .flex else .solo,
            .role = if (i % 2 == 0) .mid else .jungle,
            .champ = i % 2,
            .win = r == 'w',
            .k = 7,
            .d = 4,
            .a = 9,
            .page = i,
        };
        break :blk gs;
    };
    const list: yl.List = .{ .player = .{ .name = "MeioNeiz", .tag = "EUW", .tier = "PLATINUM", .division = "II", .lp = 2 }, .champs = &champs, .games = &games };
    var all: YourList = .{ .l = &list, .now_ms = now };
    var flex: YourList = .{ .l = &list, .now_ms = now, .sum = .{ .filter = .{ .queue = .flex } } };
    var none: YourList = .{ .l = &list, .now_ms = now, .sum = .{ .filter = .{ .queue = .draft } } };
    var older: YourList = .{ .l = &list, .now_ms = now, .shown = 2 };
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.addFill("10 games over 4 days", demo.all.view(h));
    g.addFill("Flex only", demo.flex.view(h));
    g.addFill("a filter with no games", demo.none.view(h));
    g.addFill("2 of 4 days shown", demo.older.view(h));
}

const testing = std.testing;

fn rowCount(t: *const tree.Tree, n: N) usize {
    var c: usize = @intFromBool(std.mem.eql(u8, t.attr(n, "class") orelse "", "c-grow"));
    for (t.kidsOf(n)) |k| c += rowCount(t, k);
    return c;
}

test "filter row, day groups and Show older" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    var p: YourList = .{ .l = &demo.list, .now_ms = demo.now };
    var ev: tree.Event = .{ .kind = .click };

    var n = p.view(&h);
    try testing.expectEqual(4, t.count(n, "data-day"));
    try testing.expectEqual(10, rowCount(&t, n));
    try testing.expectEqualStrings("game.html#g=0", t.attr(t.find(n, "class", "c-grow").?, "href").?);
    var text: std.Io.Writer.Allocating = .init(a);
    try t.textOf(n, &text.writer);
    try testing.expect(std.mem.find(u8, text.written(), "Today") != null);
    // The server's: no clock, so dates only
    var server: YourList = .{ .l = &demo.list };
    text.clearRetainingCapacity();
    try t.textOf(server.view(&h), &text.writer);
    try testing.expect(std.mem.find(u8, text.written(), "Today") == null);

    // Flex: games 3 and 7, on two days; the URL carries it
    p.update(.{ .queue = 2 }, &ev);
    try testing.expect(ev.push);
    n = p.view(&h);
    try testing.expectEqual(2, rowCount(&t, n));
    try testing.expectEqual(YourList.Url{ .q = .flex }, p.toUrl());
    p.update(.{ .queue = 0 }, &ev);
    p.update(.{ .role = .jungle }, &ev);
    n = p.view(&h);
    try testing.expectEqual(5, rowCount(&t, n));

    // A filter with no games says so; Show older only when more days are left
    p.fromUrl(.{ .q = .draft, .champ = 99 });
    try testing.expectEqual(null, p.sum.filter.champ);
    n = p.view(&h);
    try testing.expect(t.find(n, "class", "none") != null);
    p.fromUrl(.{});
    p.shown = 2;
    n = p.view(&h);
    try testing.expectEqual(6, rowCount(&t, n));
    p.update(.older, &ev);
    n = p.view(&h);
    try testing.expectEqual(10, rowCount(&t, n));
    try testing.expect(!h.oom);
}
