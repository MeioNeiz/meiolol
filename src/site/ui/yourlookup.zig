//! The Your games lookup (games.html#id=Name%23TAG): the status line above the list, its
//! Check for new games and Not you?, and when to ask /api/list again. Island YourLookup
//! (ui-yourlookup.wasm, which ui-your loads once the URL has an id). A list goes to
//! YourList as its root's data-bin (a List's file, base64; removed for the example
//! again), then `event` on the window
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const yl = @import("yourlist.zig");
const idlookup = @import("idlookup.zig");
const homepage = @import("homepage.zig");
const button = @import("button.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "YourLookup";
pub const scope = .{".c-ylook"};
pub const sel = "[data-island=yourlookup]";
pub const event = "your:list";
/// localStorage: Riot IDs looked up on this device, newest first (Home's recent chips;
/// homepage.recentIds reads it), and the last one, which a visit without an id opens
pub const recent_key = "your-recent";
pub const last_key = "your-last";
const max_recent = 5;

/// While queued or fetching: the first ask again after 2 s, each wait half as long
/// again up to 30 s, at most `max_asks` (about a quarter of an hour)
const first_ms = 2000;
const max_ms = 30_000;
const max_asks = 40;
/// Check for new games: Riot lists a game a few minutes after it ends, so a check that
/// finds nothing asks again each minute (the API refuses closer than check_at) this long
const watch_ms = 10 * std.time.ms_per_min;
const watch_step_ms = std.time.ms_per_min;

const W = struct {
    pub const looking = phrase.Phrase("Looking up {id:text}…");
    pub const queued = plain("Queued…");
    pub const behind = phrase.Phrase("Queued behind {n:count} other lookups…");
    pub const fetching = phrase.Phrase("Fetching games from Riot: {done:count} of {total:count}…");
    pub const failed = plain("Last update failed; showing what is stored.");
    pub const not_found = plain("No Riot account with that name and tag. Check the spelling and the part after #.");
    pub const opted_out = plain("This player has asked us not to show their games.");
    pub const busy = plain("Lots of lookups right now. Try again in a few minutes.");
    pub const down = phrase.Phrase("Couldn't load {id:text}; showing an example.");
    pub const slow = plain("Still working on it. Reload the page to check again.");
    pub const checking = plain("Checking Riot for new games…");
    pub const added = plain("New games added.");
    pub const waiting = plain("No new game yet: Riot lists a game a few minutes after it ends. Checking every minute.");
    pub const gave_up = plain("No new games. Riot can take a few minutes to list one: check again shortly.");
    pub const check = plain("Refresh");
    pub const stop = plain("Stop checking");
    pub const not_you = plain("Not you?");
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
    /// Check for new games: off, the press's answer awaited, nothing new yet (asking
    /// again each minute until `watch_until`), then what it found
    check: Check = .off,
    watch_until: i64 = 0,
    /// For the wasm after an event: ask with &refresh=1, or drop the stored last player
    want: Want = .none,
    /// The wasm's clock (ms), set before an event
    now_ms: i64 = 0,
    /// ui-yourlookup's loader and wasm, for ui-your's dom.load
    js: []const u8 = "",
    wasm: []const u8 = "",

    const P = @This();

    pub const At = enum { idle, asking, answered, down, slow };
    pub const Check = enum { off, asking, waiting, added, gave_up };
    pub const Want = enum { none, check, forget };

    pub const Msg = union(enum) { check, not_you };

    pub fn update(p: *P, m: Msg, _: *tree.Event) void {
        switch (m) {
            .check => if (p.watching()) {
                p.check = .off;
                p.watch_until = 0;
            } else {
                p.check = .asking;
                p.want = .check;
            },
            // Back to the example; later visits open nobody until the next lookup
            .not_you => p.* = .{ .gen = p.gen +% 1, .want = .forget, .js = p.js, .wasm = p.wasm },
        }
    }

    /// The wasm has asked with &refresh=1 for the press
    pub fn started(p: *P, now_ms: i64) void {
        p.want = .none;
        p.now_ms = now_ms;
        p.watch_until = now_ms + watch_ms;
    }

    pub fn watching(p: *const P) bool {
        return p.check == .asking or p.check == .waiting;
    }

    /// A ready answer while checking: `changed`, the list differs from the one at the
    /// press. The wait before the next check, null when done
    pub fn checked(p: *P, changed: bool) ?u32 {
        if (changed) return p.endCheck(.added);
        if (p.now_ms >= p.watch_until) return p.endCheck(.gave_up);
        p.check = .waiting;
        const at_ms = (p.head.check_at orelse 0) * std.time.ms_per_s + std.time.ms_per_s;
        return @intCast(@max(watch_step_ms, @min(at_ms - p.now_ms, watch_ms)));
    }

    fn endCheck(p: *P, c: Check) ?u32 {
        p.check = c;
        p.watch_until = 0;
        return null;
    }

    pub const Url = struct { id: idlookup.Id = .{} };

    pub fn toUrl(p: *const P) Url {
        return .{ .id = p.id };
    }

    pub fn fromUrl(p: *P, u: Url) void {
        if (u.id.eql(&p.id)) return;
        p.* = .{ .id = u.id, .gen = p.gen +% 1, .at = if (u.id.len > 0) .asking else .idle, .js = p.js, .wasm = p.wasm };
    }

    /// /api/list's answer for this id, null when the fetch failed (not 200, offline): the
    /// list's file for YourList, if it has one. Failed: the answer isn't kept (the status
    /// line's strings still point into the last); while waiting the shown list stays and
    /// the next ask is a retry, else `.down`
    pub fn answer(p: *P, a: std.mem.Allocator, bytes: ?[]const u8) error{Failed}!?[]u8 {
        const s = (if (bytes) |b| yl.split(a, b) catch null else null) orelse return p.failed();
        // none: the cache-only answer, which this page never asks for
        if (s.head.state == .none) {
            if (s.list) |l| a.free(l);
            return p.failed();
        }
        p.head = s.head;
        p.at = .answered;
        switch (s.head.state) {
            .queued, .fetching, .ready => {},
            else => p.check = .off,
        }
        return s.list;
    }

    fn failed(p: *P) error{Failed} {
        if (!p.waiting()) p.at = .down;
        return error.Failed;
    }

    fn waiting(p: *const P) bool {
        return p.at == .answered and (p.head.state == .queued or p.head.state == .fetching);
    }

    /// The wait before asking again; null: no more asks. Before rendering: at the cap it
    /// sets `.slow`
    pub fn next(p: *P) ?u32 {
        if (!p.waiting()) return null;
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
        const ready = p.at == .answered and p.head.state == .ready;
        return h.div(.{
            .class = "c-ylook",
            .data_island = "yourlookup",
            .data_js = if (p.js.len > 0) p.js else null,
            .data_wasm = if (p.wasm.len > 0) p.wasm else null,
        }, .{
            h.p(.{ .role = "status" }, .{p.line(h)}),
            if (p.id.len > 0) h.div(.{ .class = "acts" }, .{
                if (ready or p.watching()) button.view(h, .{ .v = .quiet, .s = .s, .on = h.on(p, .check) }, .{if (p.watching()) W.stop else W.check}) else null,
                button.view(h, .{ .v = .quiet, .s = .s, .on = h.on(p, .not_you) }, .{W.not_you}),
            }) else null,
        });
    }

    fn line(p: *const P, h: *H) ?tree.Text {
        const id = p.id.slice();
        const hd = p.head;
        if (p.at == .answered and hd.state == .ready) switch (p.check) {
            .off => {},
            .asking => return W.checking,
            .waiting => return W.waiting,
            .added => return W.added,
            .gave_up => return W.gave_up,
        };
        return switch (p.at) {
            .idle => null,
            .asking => W.looking.with(h, .{ .id = id }),
            .down => W.down.with(h, .{ .id = id }),
            .slow => W.slow,
            .answered => switch (hd.state) {
                .queued => if (hd.ahead) |n| (if (n > 0) W.behind.with(h, .{ .n = n }) else W.queued) else W.queued,
                .fetching => W.fetching.with(h, .{ .done = (hd.total orelse 0) -| (hd.pending orelse 0), .total = hd.total orelse 0 }),
                .ready => if (hd.failed != null) W.failed else null,
                .not_found => W.not_found,
                .opted_out => W.opted_out,
                .busy => W.busy,
                .none => null,
            },
        };
    }
};

/// `stored` (your-recent, or nothing) with `id` first, as a case-insensitive repeat
/// moves up; at most `max_recent`. An id JSON would need to escape is left out
pub fn recentJson(a: std.mem.Allocator, stored: ?[]const u8, id: []const u8) ![]const u8 {
    var ids: [max_recent]idlookup.Id = undefined;
    const old = homepage.recentIds(stored orelse "", &ids);
    var w: std.Io.Writer.Allocating = .init(a);
    try w.writer.writeByte('[');
    var n: usize = 0;
    if (plainId(id)) {
        try w.writer.print("{{\"id\":\"{s}\"}}", .{id});
        n = 1;
    }
    for (old) |*o| {
        if (n == max_recent) break;
        if (std.ascii.eqlIgnoreCase(o.slice(), id)) continue;
        try w.writer.print("{s}{{\"id\":\"{s}\"}}", .{ if (n > 0) "," else "", o.slice() });
        n += 1;
    }
    try w.writer.writeByte(']');
    return w.toOwnedSlice();
}

/// your-last's value for `id`
pub fn lastJson(a: std.mem.Allocator, id: []const u8) !?[]const u8 {
    return if (plainId(id)) try a.print("{{\"id\":\"{s}\"}}", .{id}) else null;
}

fn plainId(id: []const u8) bool {
    for (id) |c| if (c < 0x20 or c == '"' or c == '\\') return false;
    return id.len > 0;
}

/// The URL's lookup id, percent-encoded as there (game.html's links take it so); null
/// without one. The last id= wins, as in url.read
pub fn idOf(hash: []const u8) ?[]const u8 {
    var id: []const u8 = "";
    var it = std.mem.tokenizeScalar(u8, if (hash.len > 0 and (hash[0] == '#' or hash[0] == '?')) hash[1..] else hash, '&');
    while (it.next()) |kv| {
        if (std.mem.startsWith(u8, kv, "id=")) id = kv[3..];
    }
    return if (id.len > 0) id else null;
}

pub const css =
    \\@layer components {
    \\  .c-ylook { display: flex; flex-wrap: wrap; align-items: center; gap: var(--sp-1) var(--sp-3);
    \\    padding: 0 var(--sp-4); }
    \\  .c-ylook > p { flex: 1 1 16rem; margin: 0; padding: var(--sp-2) 0; color: var(--muted); }
    \\  .c-ylook > p:empty { padding: 0; }
    \\  .c-ylook .acts { display: flex; gap: var(--sp-1); margin-left: auto; }
    \\}
    \\
;

fn demo(at: YourLookup.At, head: yl.Head) YourLookup {
    var p: YourLookup = .{ .at = at, .head = head };
    p.id.set("MeioNeiz#EUW");
    return p;
}

fn checking(c: YourLookup.Check) YourLookup {
    var p = demo(.answered, .{ .state = .ready });
    p.check = c;
    return p;
}

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const states = .{
        .{ "looking up", demo(.asking, .{ .state = .none }) },
        .{ "queued behind others", demo(.answered, .{ .state = .queued, .ahead = 3 }) },
        .{ "fetching", demo(.answered, .{ .state = .fetching, .pending = 12, .total = 40 }) },
        .{ "ready after a failed refresh", demo(.answered, .{ .state = .ready, .failed = "RateLimited" }) },
        .{ "queued", demo(.answered, .{ .state = .queued }) },
        .{ "not found", demo(.answered, .{ .state = .not_found }) },
        .{ "opted out", demo(.answered, .{ .state = .opted_out }) },
        .{ "busy", demo(.answered, .{ .state = .busy }) },
        .{ "still working at the cap", demo(.slow, .{ .state = .fetching }) },
        .{ "ready: check and Not you?", demo(.answered, .{ .state = .ready }) },
        .{ "checking, nothing new yet", checking(.waiting) },
        .{ "checked, new games", checking(.added) },
        .{ "the API down: the example below", demo(.down, .{ .state = .none }) },
    };
    inline for (states) |s| {
        var p = s[1];
        g.add(s[0], p.view(h));
    }
}

const testing = std.testing;
const data = @import("data.zig");
const url = @import("url.zig");

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
    try testing.expectEqual(null, try p.answer(a, try reply(a, .{ .state = .queued, .ahead = 2 })));
    try testing.expectEqual(2000, p.next().?);
    try testing.expectEqual(3000, p.next().?);
    try testing.expectEqual(null, try p.answer(a, try reply(a, .{ .state = .fetching, .pending = 1, .total = 4 })));
    try testing.expectEqual(4500, p.next().?);
    // Ready: no more asks
    const l: yl.List = .{ .player = .{ .name = "A", .tag = "1" }, .champs = &.{}, .games = &.{} };
    const file = (try p.answer(a, try reply(a, .{ .state = .ready, .list = l }))).?;
    try testing.expectEqualStrings("1", (try data.decode(a, yl.List, file)).player.tag);
    try testing.expectEqual(null, p.next());
}

test "stops at the cap, saying so" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    var p = demo(.asking, .{ .state = .none });
    _ = try p.answer(a, try reply(a, .{ .state = .fetching }));
    var waited: u64 = 0;
    while (p.next()) |ms| waited += ms;
    try testing.expectEqual(.slow, p.at);
    try testing.expectEqual(max_asks, p.asks);
    try testing.expect(waited > 10 * std.time.ms_per_min);
    try expectLine(a, &t, h.p(.{}, .{p.line(&h)}), "Still working on it. Reload the page to check again.");
}

test "a failed ask while waiting keeps the list and asks again, within the cap" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var p = demo(.asking, .{ .state = .none });
    _ = try p.answer(a, try reply(a, .{ .state = .fetching, .pending = 1, .total = 4 }));
    try testing.expectEqual(2000, p.next().?);
    try testing.expectError(error.Failed, p.answer(a, null));
    try testing.expectError(error.Failed, p.answer(a, "garbage"));
    try testing.expectEqual(.answered, p.at);
    try testing.expectEqual(4, p.head.total.?);
    try testing.expectEqual(3000, p.next().?);
    try testing.expectEqual(2, p.asks);
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

test "a failed first ask or a bad answer: the example, said so" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    var p = demo(.asking, .{ .state = .none });
    try testing.expectError(error.Failed, p.answer(a, null));
    try testing.expectEqual(.down, p.at);
    try testing.expectEqual(null, p.next());
    p.at = .asking;
    try testing.expectError(error.Failed, p.answer(a, "garbage"));
    try testing.expectEqual(.down, p.at);
    try expectLine(a, &t, h.p(.{}, .{p.line(&h)}), "Couldn't load MeioNeiz#EUW; showing an example.");
}

fn expectLine(a: std.mem.Allocator, t: *tree.Tree, n: N, want: []const u8) !void {
    var w: std.Io.Writer.Allocating = .init(a);
    try t.textOf(n, &w.writer);
    try testing.expectEqualStrings(want, w.written());
}

test "each answer's status line; none once ready" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    const cases = .{
        .{ yl.Head{ .state = .queued }, "Queued…" },
        .{ yl.Head{ .state = .queued, .ahead = 0 }, "Queued…" },
        .{ yl.Head{ .state = .queued, .ahead = 3 }, "Queued behind 3 other lookups…" },
        .{ yl.Head{ .state = .fetching, .pending = 12, .total = 40 }, "Fetching games from Riot: 28 of 40…" },
        .{ yl.Head{ .state = .not_found }, "No Riot account with that name and tag. Check the spelling and the part after #." },
        .{ yl.Head{ .state = .opted_out }, "This player has asked us not to show their games." },
        .{ yl.Head{ .state = .busy }, "Lots of lookups right now. Try again in a few minutes." },
        .{ yl.Head{ .state = .ready }, "" },
        .{ yl.Head{ .state = .ready, .failed = "RateLimited" }, "Last update failed; showing what is stored." },
    };
    inline for (cases) |c| {
        var p = demo(.answered, c[0]);
        try expectLine(a, &t, h.p(.{}, .{p.line(&h)}), c[1]);
    }
}

test "a none answer is a failed one, its list freed" {
    var p = demo(.asking, .{ .state = .none });
    const l: yl.List = .{ .player = .{ .name = "A", .tag = "1" }, .champs = &.{}, .games = &.{} };
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const bytes = try reply(arena.allocator(), .{ .state = .none, .list = l });
    // testing.allocator fails the test on a leak
    try testing.expectError(error.Failed, p.answer(testing.allocator, bytes));
    try testing.expectEqual(.down, p.at);
}

test idOf {
    try testing.expectEqualStrings("A%231", idOf("#q=solo&id=A%231&role=mid").?);
    try testing.expectEqualStrings("A%231", idOf("#id=A%231").?);
    try testing.expectEqual(null, idOf("#q=solo&id="));
    try testing.expectEqual(null, idOf("#champ=Kid=1"));
    // As url.read: the last
    try testing.expectEqualStrings("B%232", idOf("#id=A%231&id=B%232").?);
    try testing.expectEqual(null, idOf("#id=A%231&id="));
    var u: YourLookup.Url = url.read(YourLookup.Url, "#id=A%231&id=B%232");
    try testing.expectEqualStrings("B#2", u.id.slice());
    u = url.read(YourLookup.Url, "#id=A%231&id=");
    try testing.expectEqual(0, u.id.len);
}

test "check: asks with refresh, again each minute while nothing is new, until found or 10 min" {
    var p = demo(.answered, .{ .state = .ready, .check_at = 100 });
    var ev: tree.Event = .{ .kind = .click };
    p.now_ms = 50_000;
    p.update(.check, &ev);
    try testing.expectEqual(.check, p.want);
    try testing.expect(p.watching());
    p.started(50_000);
    try testing.expectEqual(.none, p.want);
    // check_at 100 s is 51 s on: a minute
    try testing.expectEqual(std.time.ms_per_min, p.checked(false).?);
    try testing.expectEqual(.waiting, p.check);
    p.head.check_at = 200;
    try testing.expectEqual(151_000, p.checked(false).?);
    p.now_ms += watch_ms;
    try testing.expectEqual(null, p.checked(false));
    try testing.expectEqual(.gave_up, p.check);
    p.update(.check, &ev);
    try testing.expectEqual(null, p.checked(true));
    try testing.expectEqual(.added, p.check);
    // Stop
    p.update(.check, &ev);
    p.update(.check, &ev);
    try testing.expectEqual(.off, p.check);
}

test "Not you? drops the id and asks the wasm to forget the stored player" {
    var p = demo(.answered, .{ .state = .ready });
    p.js = "j.js";
    var ev: tree.Event = .{ .kind = .click };
    const gen = p.gen;
    p.update(.not_you, &ev);
    try testing.expectEqual(0, p.id.len);
    try testing.expectEqual(.forget, p.want);
    try testing.expect(p.gen != gen);
    try testing.expectEqualStrings("j.js", p.js);
}

test recentJson {
    const a = testing.allocator;
    const one = try recentJson(a, null, "A#1");
    defer a.free(one);
    try testing.expectEqualStrings("[{\"id\":\"A#1\"}]", one);
    // your.js's shape, a repeat in other case moved up, at most 5
    const old = "[{\"id\":\"B#2\",\"newest\":5},{\"id\":\"a#1\",\"newest\":3},{\"id\":\"C#3\"},{\"id\":\"D#4\"},{\"id\":\"E#5\"},{\"id\":\"F#6\"}]";
    const two = try recentJson(a, old, "A#1");
    defer a.free(two);
    try testing.expectEqualStrings("[{\"id\":\"A#1\"},{\"id\":\"B#2\"},{\"id\":\"C#3\"},{\"id\":\"D#4\"},{\"id\":\"E#5\"}]", two);
    var ids: [5]idlookup.Id = undefined;
    try testing.expectEqual(5, homepage.recentIds(two, &ids).len);
    const bad = try recentJson(a, "[{\"id\":\"B#2\"}]", "x\"y#1");
    defer a.free(bad);
    try testing.expectEqualStrings("[{\"id\":\"B#2\"}]", bad);
}
