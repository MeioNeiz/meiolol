//! The Your games lookup (games.html#id=Name%23TAG): the status line above the list, and
//! when to ask /api/list again. Island YourLookup (ui-yourlookup.wasm, which ui-your
//! loads once the URL has an id). A list goes to YourList as its root's data-bin (a
//! List's file, base64; removed for the example again), then `event` on the window
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const yl = @import("yourlist.zig");
const idlookup = @import("idlookup.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "YourLookup";
pub const scope = .{".c-ylook"};
pub const sel = "[data-island=yourlookup]";
pub const event = "your:list";

/// While queued or fetching: the first ask again after 2 s, each wait half as long
/// again up to 30 s, at most `max_asks` (about a quarter of an hour)
const first_ms = 2000;
const max_ms = 30_000;
const max_asks = 40;

const W = struct {
    pub const looking = phrase.Phrase("Looking up {id:text}…");
    pub const queued = plain("Queued…");
    pub const behind = phrase.Phrase("Queued behind {n:count} other lookups…");
    pub const fetching = phrase.Phrase("Fetching games from Riot: {done:count} of {total:count}…");
    pub const failed = phrase.Phrase("Last update failed ({e:text}); showing what is stored.");
    pub const not_found = plain("No Riot account with that name and tag. Check the spelling and the part after #.");
    pub const opted_out = plain("This player has asked us not to show their games.");
    pub const busy = plain("Lots of lookups right now. Try again in a few minutes.");
    pub const down = phrase.Phrase("Couldn't load {id:text}; showing an example.");
    pub const slow = plain("Still working on it. Reload the page to check again.");
};

pub const YourLookup = struct {
    id: idlookup.Id = .{},
    /// Each new id's: a late answer or timer for an older one is dropped
    gen: u32 = 0,
    at: At = .idle,
    head: yl.Head = .{ .state = .none },
    /// Asks since the first answer
    asks: u16 = 0,
    /// An ask fell due with the tab hidden: the next waits for it to show
    paused: bool = false,
    /// ui-yourlookup's loader and wasm, for ui-your's dom.load
    js: []const u8 = "",
    wasm: []const u8 = "",

    const P = @This();

    pub const At = enum { idle, asking, answered, down, slow };

    pub const Url = struct { id: idlookup.Id = .{} };

    pub fn toUrl(p: *const P) Url {
        return .{ .id = p.id };
    }

    pub fn fromUrl(p: *P, u: Url) void {
        if (u.id.eql(&p.id)) return;
        p.* = .{ .id = u.id, .gen = p.gen +% 1, .at = if (u.id.len > 0) .asking else .idle, .js = p.js, .wasm = p.wasm };
    }

    /// /api/list's answer for this id, null when the fetch failed (not 200, offline): the
    /// list's file for YourList, if it has one
    pub fn answer(p: *P, a: std.mem.Allocator, bytes: ?[]const u8) ?[]u8 {
        p.at = .down;
        const s = yl.split(a, bytes orelse return null) catch return null;
        // none: the cache-only answer, which this page never asks for
        if (s.head.state == .none) return null;
        p.head = s.head;
        p.at = .answered;
        return s.list;
    }

    /// The wait before asking again; null: no more asks
    pub fn next(p: *P) ?u32 {
        if (p.at != .answered or (p.head.state != .queued and p.head.state != .fetching)) return null;
        if (p.asks >= max_asks) {
            p.at = .slow;
            return null;
        }
        var ms: u32 = first_ms;
        for (0..p.asks) |_| ms = @min(ms * 3 / 2, max_ms);
        p.asks += 1;
        return ms;
    }

    /// A wait ended: ask now, or not while the tab is hidden (`paused` until it shows)
    pub fn due(p: *P, hidden: bool) bool {
        p.paused = hidden;
        return !hidden;
    }

    pub fn view(p: *P, h: *H) N {
        return h.div(.{
            .class = "c-ylook",
            .data_island = "yourlookup",
            .data_js = if (p.js.len > 0) p.js else null,
            .data_wasm = if (p.wasm.len > 0) p.wasm else null,
            .role = "status",
        }, .{if (p.line(h)) |t| h.p(.{}, .{t}) else null});
    }

    fn line(p: *const P, h: *H) ?tree.Text {
        const id = p.id.slice();
        const hd = p.head;
        return switch (p.at) {
            .idle => null,
            .asking => W.looking.with(h, .{ .id = id }),
            .down => W.down.with(h, .{ .id = id }),
            .slow => W.slow,
            .answered => switch (hd.state) {
                .queued => if (hd.ahead) |n| (if (n > 0) W.behind.with(h, .{ .n = n }) else W.queued) else W.queued,
                .fetching => W.fetching.with(h, .{ .done = (hd.total orelse 0) -| (hd.pending orelse 0), .total = hd.total orelse 0 }),
                .ready => if (hd.failed) |e| W.failed.with(h, .{ .e = e }) else null,
                .not_found => W.not_found,
                .opted_out => W.opted_out,
                .busy => W.busy,
                .none => null,
            },
        };
    }
};

/// The URL's lookup id, percent-encoded as there (game.html's links take it so); null
/// without one
pub fn idOf(hash: []const u8) ?[]const u8 {
    var i: usize = 0;
    while (std.mem.findPos(u8, hash, i, "id=")) |at| : (i = at + 3) {
        if (at > 0 and hash[at - 1] != '#' and hash[at - 1] != '&') continue;
        const v = hash[at + 3 ..];
        const end = std.mem.findScalar(u8, v, '&') orelse v.len;
        return if (end > 0) v[0..end] else null;
    }
    return null;
}

pub const css =
    \\@layer components {
    \\  .c-ylook:empty { display: none; }
    \\  .c-ylook > p { margin: 0; padding: var(--sp-2) var(--sp-4); color: var(--muted); }
    \\}
    \\
;

fn demo(at: YourLookup.At, head: yl.Head) YourLookup {
    var p: YourLookup = .{ .at = at, .head = head };
    p.id.set("MeioNeiz#EUW");
    return p;
}

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const states = .{
        .{ "looking up", demo(.asking, .{ .state = .none }) },
        .{ "queued behind others", demo(.answered, .{ .state = .queued, .ahead = 3 }) },
        .{ "fetching", demo(.answered, .{ .state = .fetching, .pending = 12, .total = 40 }) },
        .{ "ready after a failed refresh", demo(.answered, .{ .state = .ready, .failed = "RateLimited" }) },
        .{ "not found", demo(.answered, .{ .state = .not_found }) },
        .{ "the API down: the example below", demo(.down, .{ .state = .none }) },
    };
    inline for (states) |s| {
        var p = s[1];
        g.add(s[0], p.view(h));
    }
}

const testing = std.testing;
const data = @import("data.zig");

fn reply(a: std.mem.Allocator, l: yl.Lookup) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    try data.encode(a, yl.Lookup, l, &out);
    return out.items;
}

test "asks again while queued or fetching, backing off; stops once ready" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var p: YourLookup = .{};
    var u: YourLookup.Url = .{};
    u.id.set("A#1");
    p.fromUrl(u);
    try testing.expectEqual(.asking, p.at);
    try testing.expectEqual(null, p.answer(a, try reply(a, .{ .state = .queued, .ahead = 2 })));
    try testing.expectEqual(2000, p.next().?);
    try testing.expectEqual(3000, p.next().?);
    try testing.expectEqual(null, p.answer(a, try reply(a, .{ .state = .fetching, .pending = 1, .total = 4 })));
    try testing.expectEqual(4500, p.next().?);
    // Ready: no more asks
    const l: yl.List = .{ .player = .{ .name = "A", .tag = "1" }, .champs = &.{}, .games = &.{} };
    const file = p.answer(a, try reply(a, .{ .state = .ready, .list = l })).?;
    try testing.expectEqualStrings("1", (try data.decode(a, yl.List, file)).player.tag);
    try testing.expectEqual(null, p.next());
}

test "stops at the cap, saying so" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var p: YourLookup = .{ .at = .asking };
    _ = p.answer(a, try reply(a, .{ .state = .fetching }));
    var waited: u64 = 0;
    while (p.next()) |ms| waited += ms;
    try testing.expectEqual(.slow, p.at);
    try testing.expectEqual(max_asks, p.asks);
    try testing.expect(waited > 10 * std.time.ms_per_min);
}

test "a new id starts again and drops the old one's ask; none clears" {
    var p: YourLookup = .{ .js = "ui-yourlookup.js" };
    var u: YourLookup.Url = .{};
    u.id.set("A#1");
    p.fromUrl(u);
    const first = p.gen;
    p.fromUrl(u);
    try testing.expectEqual(first, p.gen);
    u.id.set("B#2");
    p.fromUrl(u);
    try testing.expect(p.gen != first);
    try testing.expectEqual(.asking, p.at);
    try testing.expectEqualStrings("ui-yourlookup.js", p.js);
    p.fromUrl(.{});
    try testing.expectEqual(.idle, p.at);
}

test "a hidden tab pauses the asks" {
    var p: YourLookup = .{};
    try testing.expect(!p.due(true));
    try testing.expect(p.paused);
    try testing.expect(p.due(false));
    try testing.expect(!p.paused);
}

test "a failed fetch or a bad answer: the example, said so" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    var p = demo(.asking, .{ .state = .none });
    _ = p.answer(a, null);
    try testing.expectEqual(.down, p.at);
    try testing.expectEqual(null, p.next());
    _ = p.answer(a, "garbage");
    var w: std.Io.Writer.Allocating = .init(a);
    try t.textOf(p.view(&h), &w.writer);
    try testing.expectEqualStrings("Couldn't load MeioNeiz#EUW; showing an example.", w.written());
}

test idOf {
    try testing.expectEqualStrings("A%231", idOf("#q=solo&id=A%231&role=mid").?);
    try testing.expectEqualStrings("A%231", idOf("#id=A%231").?);
    try testing.expectEqual(null, idOf("#q=solo&id="));
    try testing.expectEqual(null, idOf("#champ=Kid=1"));
}
