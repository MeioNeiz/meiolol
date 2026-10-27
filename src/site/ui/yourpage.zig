//! The Your games list (games.html, docs/plan/ui/your-games.md "Games"), under
//! YourViews' PlayerBar: ProfileSummary beside the games as day groups of GameRow, "Show
//! older" at the foot. Island YourList (ui-your.wasm); the filter is in the URL, which
//! YourViews' filter row writes too. The server renders without a clock (dates, no
//! "Today" or "2h ago": the page stays the same all day); the island adds them in the
//! visitor's zone
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const yl = @import("yourlist.zig");
const profilesum = @import("profilesum.zig");
const dayhead = @import("dayhead.zig");
const gamerow = @import("gamerow.zig");
const button = @import("button.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const url = @import("url.zig");
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
    pub const older = plain("Show older");
    pub const none = plain("No games match");
    pub const example = plain("An example player's games. Look yourself up on the home page for yours.");
};

/// The filter row's chips; `.other` games show under All only
pub const queues = [_]?yl.Queue{ null, .solo, .flex, .draft, .swift };
comptime {
    std.debug.assert(queues.len == @typeInfo(yl.Queue).@"enum".field_names.len);
}

/// The filter in the URL, YourList's and YourViews' alike. The champion by name:
/// `List.champs` order changes with the list
pub const FilterUrl = struct { q: ?yl.Queue = null, role: ?Role = null, champ: url.Str(24) = .{} };

pub fn urlOf(l: *const yl.List, f: yl.Filter) FilterUrl {
    var u: FilterUrl = .{ .q = f.queue, .role = f.role };
    if (f.champ) |c| u.champ.set(l.champs[c].name);
    return u;
}

/// A queue without its chip or a champion without games under the filter is dropped:
/// nothing on the page could clear it
pub fn filterOf(l: *const yl.List, u: FilterUrl) yl.Filter {
    var f: yl.Filter = .{ .role = u.role };
    if (std.mem.findScalar(?yl.Queue, &queues, u.q) != null) f.queue = u.q;
    for (l.champs, 0..) |c, i| if (std.mem.eql(u8, c.name, u.champ.slice())) {
        f.champ = @intCast(i);
    };
    if (f.champ != null and !any(l.games, f)) f.champ = null;
    return f;
}

/// A game on `page` (game.html): a lookup's (`id`) by start, the example's by page; at
/// second `m` when not 0
pub fn gameHref(h: *H, page: []const u8, id: []const u8, g: yl.Game, m: u16) ?[]const u8 {
    const at = if (m > 0) h.fmt("&m={d}", .{m}) else "";
    if (id.len > 0) return h.fmt("{s}#id={s}&game={d}{s}", .{ page, id, g.start_ms, at });
    const i = g.page orelse return null;
    return h.fmt("{s}#g={d}{s}", .{ page, i, at });
}

pub fn any(games: []const yl.Game, f: yl.Filter) bool {
    for (games) |g| if (f.keeps(g)) return true;
    return false;
}

pub const YourList = struct {
    l: *const yl.List,
    /// ui.data of `l`: the island's copy
    bin: []const u8 = "",
    /// Holds the filter: its presses, and YourViews' filter row through the URL
    sum: profilesum.ProfileSummary = .{},
    /// Day groups shown
    shown: u16 = step,
    /// The visitor's clock; none on the server
    now_ms: ?i64 = null,
    /// Minutes east of UTC, now
    tz_min: i32 = 0,
    /// Each game's offset (a DST change moves it); empty on the server: UTC
    tz: []const i32 = &.{},
    /// game.html, relative to the page
    game: []const u8 = "game.html",
    /// A looked-up player's Riot ID, percent-encoded; "" the example
    id: []const u8 = "",

    const P = @This();

    pub const Url = FilterUrl;

    pub const Msg = union(enum) { older, filtered };

    pub fn toUrl(p: *const P) Url {
        return urlOf(p.l, p.sum.filter);
    }

    pub fn fromUrl(p: *P, u: Url) void {
        p.sum.filter = filterOf(p.l, u);
        p.shown = step;
    }

    /// `.filtered`: ProfileSummary's press, which asked for the history entry
    pub fn update(p: *P, m: Msg, _: *tree.Event) void {
        p.shown = switch (m) {
            .older => p.shown +| step,
            .filtered => step,
        };
    }

    pub fn view(p: *P, h: *H) N {
        const l = p.l;
        const f = p.sum.filter;
        p.sum.on_change = h.on(p, .filtered);
        const days = yl.days(h.mem, l.games, f, p.tz) catch return oom(h);
        const today = if (p.now_ms) |ms| yl.dayOf(ms, p.tz_min) else std.math.maxInt(i32);

        var groups = h.list();
        for (days[0..@min(days.len, p.shown)]) |d| {
            var rows = h.list();
            for (d.games) |i| {
                const g = l.games[i];
                rows.add(gamerow.view(h, l, g, .{ .key = @as(u32, i) + 1, .href = gameHref(h, p.game, p.id, g, 0), .now_ms = p.now_ms }));
            }
            groups.add(h.el(.section, .{ .key = @as(u32, @bitCast(d.day)), .class = "day", .data_day = d.day }, .{ dayhead.view(h, d, today), rows.done() }));
        }
        return h.div(.{
            .class = "c-your",
            .data_island = "your",
            .data_bin = if (p.bin.len > 0) p.bin else null,
        }, .{
            p.sum.view(h, l, l.games),
            h.div(.{ .class = "list" }, .{
                if (p.id.len == 0) h.p(.{ .class = "note" }, .{W.example}) else null,
                if (days.len == 0) h.p(.{ .class = "none" }, .{W.none}) else null,
                groups.done(),
                if (days.len > p.shown) button.view(h, .{ .on = h.on(p, .older) }, .{W.older}) else null,
            }),
        });
    }
};

fn oom(h: *H) N {
    h.oom = true;
    return .none;
}

pub const css =
    \\@layer components {
    \\  .c-your { display: grid; grid-template-columns: 288px minmax(0, 1fr); gap: var(--sp-3); align-items: start; }
    \\  .c-your .list { display: grid; grid-template-columns: minmax(0, 1fr); gap: var(--sp-3); min-width: 0; }
    \\  /* GameRow's layouts follow its container's width */
    \\  .c-your .day { container-type: inline-size; display: grid; grid-template-columns: minmax(0, 1fr); gap: var(--sp-1); }
    \\  .c-your .none { margin: 0; padding: var(--sp-4); color: var(--faint); }
    \\  .c-your .note { margin: 0; color: var(--muted); font-size: var(--fs-s); }
    \\  .c-your .list > .c-btn { justify-self: center; }
    \\  @media (max-width: 1000px) {
    \\    .c-your { grid-template-columns: minmax(0, 1fr); }
    \\  }
    \\}
    \\
;

pub const demo = struct {
    const champs = [_]champ.Champ{ .{ .name = "Aurelion Sol", .src = "" }, .{ .name = "Karthus", .src = "" } };
    const day_ms = std.time.ms_per_day;
    pub const now: i64 = 20_000 * day_ms + 20 * std.time.ms_per_hour;
    pub const games = blk: {
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
    pub const list: yl.List = .{ .player = .{ .name = "MeioNeiz", .tag = "EUW", .tier = "PLATINUM", .division = "II", .lp = 2 }, .champs = &champs, .games = &games };
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

test "the URL's filter, day groups and Show older" {
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

    // Flex, from the URL: games 3 and 7, on two days
    p.fromUrl(.{ .q = .flex });
    n = p.view(&h);
    try testing.expectEqual(2, rowCount(&t, n));
    try testing.expectEqual(.flex, p.toUrl().q);
    p.fromUrl(.{ .role = .jungle });
    n = p.view(&h);
    try testing.expectEqual(5, rowCount(&t, n));

    // A filter with no games says so; Show older only when more days are left
    var u: YourList.Url = .{ .q = .draft };
    u.champ.set("Karthus");
    p.fromUrl(u);
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

test "a looked-up list: rows open game.html by id and start, no example note" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    var p: YourList = .{ .l = &demo.list };
    try testing.expect(t.find(p.view(&h), "class", "note") != null);
    p.id = "MeioNeiz%23EUW";
    const n = p.view(&h);
    try testing.expect(t.find(n, "class", "note") == null);
    const want = try std.fmt.allocPrint(a, "game.html#id=MeioNeiz%23EUW&game={d}", .{demo.games[0].start_ms});
    try testing.expectEqualStrings(want, t.attr(t.find(n, "class", "c-grow").?, "href").?);
}
