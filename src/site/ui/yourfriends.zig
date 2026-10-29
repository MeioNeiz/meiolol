//! The Your games page's Friends view (your-games.md "Friends"): who a looked-up player
//! queues with, from /api/friends.bin (api friends.zig): the record with friends and
//! alone, then a DataTable of friends, a row opening the champion and role pairs. Facts
//! with a range, never verdicts. Lookups only: the example has no friends. Island
//! YourFriends (ui-yourfriends.wasm), after YourTime on the page, shown by YourViews'
//! Friends tab; its file loads when it shows. The filter row doesn't apply to it
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const table = @import("table.zig");
const delta = @import("delta.zig");
const bar = @import("bar.zig");
const button = @import("button.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const gamerow = @import("gamerow.zig");
const homepage = @import("homepage.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const Phrase = phrase.Phrase;
const H = tree.H;
const N = tree.N;
const Role = role.Role;

pub const name = "YourFriends";
pub const scope = .{".c-yfriends"};
pub const sel = "[data-island=yourfriends]";

/// While older games or a friend's games are still coming: ask again this often
pub const poll_ms = 15_000;
/// api friends.max_friends
pub const max_friends = 20;

pub const Record = struct { games: u32 = 0, wins: u32 = 0 };

/// A win rate together against apart in the queues both play, in points; `ci` the 95%
/// half-width
pub const Effect = struct { together: Record, apart: Record, apart_rate: f32, diff: f32, ci: f32 };

/// `Friends.champs` indices
pub const Pair = struct { mine: u16, theirs: u16, games: u32, wins: u32 };
pub const Roles = struct { mine: Role, theirs: Role, games: u32, wins: u32 };

pub const Friend = struct {
    riot_id: []const u8,
    together: Record,
    against: Record = .{},
    last_ms: i64,
    /// Yours with them against apart; null when no shared queue has games apart
    you: ?Effect = null,
    /// Theirs with you, from their own games; null until those are cached
    them: ?Effect = null,
    their_games: u32 = 0,
    pairs: []const Pair = &.{},
    roles: []const Roles = &.{},
};

/// /api/friends.bin's answer
pub const Friends = struct {
    pub const State = enum { none, opted_out, ready };
    state: State,
    /// Games counted
    games: u32 = 0,
    /// Older games still to fetch
    waiting: u32 = 0,
    with_friends: Record = .{},
    alone: Record = .{},
    champs: []const champ.Champ = &.{},
    friends: []const Friend = &.{},
};

const W = struct {
    pub const title = plain("Friends");
    pub const friend = plain("Friend");
    pub const together = plain("Together");
    pub const yours = plain("Your rate");
    pub const theirs = plain("Their rate");
    pub const pair = plain("Usual pair");
    pub const with = plain("With friends");
    pub const alone = plain("Alone");
    pub const wl = Phrase("{w:int}–{l:int}");
    pub const from = Phrase("{n:count} games, last 60 days");
    pub const coming = Phrase("{n:count} games so far, {m:count} older on the way");
    pub const yours_tip = plain("Your win rate with them minus apart, in the queues you both play. The line is a 95% range.");
    pub const theirs_tip = plain("Their win rate with you minus apart, from their own games. Fetch looks them up.");
    pub const rates = Phrase("{a:pct} together, {b:pct} apart; {n:count} and {m:count} games");
    pub const fetch = plain("Fetch");
    pub const fetching = plain("Fetching…");
    pub const dash = plain("–");
    pub const against = Phrase("Against them {w:int}–{l:int}");
    pub const pairs = plain("Champions together");
    pub const role_pairs = plain("Roles together");
    pub const loading = plain("Loading friends…");
    pub const failed = plain("Couldn't load friends. Try again later.");
    pub const none = plain("Not looked up yet.");
    pub const opted_out = plain("This player opted out.");
    pub const nobody = plain("Nobody on your team in 3 or more games yet.");
};

pub const Row = struct { f: *const Friend, p: *YourFriends, i: u8 };

pub const Table = table.DataTable(Row, .{
    .title = W.title,
    .columns = &.{
        .{ .label = W.friend, .cell = who, .name = idOf, .num = false },
        .{ .label = W.together, .cell = together, .sort = gamesOf },
        .{ .label = W.yours, .cell = yours, .sort = yourDiff, .answer = true, .tip = W.yours_tip, .row_tip = yourTip },
        .{ .label = W.theirs, .cell = theirs, .sort = theirDiff, .priority = 2, .tip = W.theirs_tip },
        .{ .label = W.pair, .cell = pair, .num = false, .priority = 3 },
    },
    .default_sort = 1,
    .detail = detail,
    .key = "fr",
    .bare = true,
});

pub const YourFriends = struct {
    /// The answer; null before it
    f: ?*const Friends = null,
    at: At = .idle,
    table: Table = .{ .rows = &.{} },
    /// Friends whose games this tab asked for (Fetch): until their games are in, the
    /// cell says so and the page asks again
    asked: [max_friends]u64 = undefined,
    n_asked: u8 = 0,
    /// For the wasm after a Fetch: the friend's Riot ID to look up
    want: ?[]const u8 = null,
    now_ms: i64 = 0,
    /// ui-yourfriends' loader and wasm, for dom.lazyLoad
    js: []const u8 = "",
    wasm: []const u8 = "",

    const P = @This();

    pub const At = enum { idle, loading, ready, failed };

    pub const Msg = union(enum) { fetch: u8 };

    pub fn update(p: *P, m: Msg, _: *tree.Event) void {
        switch (m) {
            .fetch => |i| {
                const f = p.f orelse return;
                if (i >= f.friends.len or p.n_asked == max_friends) return;
                const id = f.friends[i].riot_id;
                if (p.wasAsked(id)) return;
                p.asked[p.n_asked] = hashOf(id);
                p.n_asked += 1;
                p.want = id;
            },
        }
    }

    /// A new player (or none): forget the last one's answer and asks
    pub fn reset(p: *P, loading: bool) void {
        p.f = null;
        p.at = if (loading) .loading else .idle;
        p.n_asked = 0;
        p.want = null;
        p.table.open = null;
    }

    /// An answer (null: the fetch failed or wasn't one); true while it should ask again
    pub fn answered(p: *P, f: ?*const Friends) bool {
        const x = f orelse {
            if (p.f == null) p.at = .failed;
            return false;
        };
        p.f = x;
        p.at = .ready;
        p.table.open = null;
        if (x.state != .ready) return false;
        if (x.waiting > 0) return true;
        for (x.friends) |fr| if (fr.their_games == 0 and p.wasAsked(fr.riot_id)) return true;
        return false;
    }

    fn wasAsked(p: *const P, id: []const u8) bool {
        return std.mem.findScalar(u64, p.asked[0..p.n_asked], hashOf(id)) != null;
    }

    pub fn view(p: *P, h: *H) N {
        return h.div(.{
            .class = "c-yfriends",
            .data_island = "yourfriends",
            .role = "tabpanel",
            .aria_busy = p.at == .loading,
            .data_js = if (p.js.len > 0) p.js else null,
            .data_wasm = if (p.wasm.len > 0) p.wasm else null,
        }, .{p.body(h)});
    }

    fn body(p: *P, h: *H) ?N {
        const f = p.f orelse return switch (p.at) {
            .idle, .ready => null,
            .loading => h.p(.{ .class = "msg" }, .{W.loading}),
            .failed => h.p(.{ .class = "msg" }, .{W.failed}),
        };
        switch (f.state) {
            .none => return h.p(.{ .class = "msg" }, .{W.none}),
            .opted_out => return h.p(.{ .class = "msg" }, .{W.opted_out}),
            .ready => {},
        }
        const rows = h.mem.alloc(Row, f.friends.len) catch {
            h.oom = true;
            return null;
        };
        for (rows, f.friends, 0..) |*r, *fr, i| r.* = .{ .f = fr, .p = p, .i = @intCast(i) };
        p.table.rows = rows;
        return h.div(.{ .class = "body" }, .{
            h.div(.{ .class = "band" }, .{
                record(h, W.with, f.with_friends),
                record(h, W.alone, f.alone),
                h.p(.{ .class = "msg" }, .{if (f.waiting > 0)
                    W.coming.with(h, .{ .n = f.games, .m = f.waiting })
                else
                    W.from.with(h, .{ .n = f.games })}),
            }),
            if (f.friends.len == 0) h.p(.{ .class = "msg" }, .{W.nobody}) else p.table.view(h),
        });
    }

    fn champAt(p: *const P, i: u16) ?champ.Champ {
        const f = p.f orelse return null;
        return if (i < f.champs.len) f.champs[i] else null;
    }
};

fn hashOf(id: []const u8) u64 {
    return std.hash.Wyhash.hash(0, id);
}

fn record(h: *H, label: tree.Text, r: Record) ?N {
    if (r.games == 0) return null;
    return h.div(.{ .class = "rec" }, .{
        h.b(.{}, .{phrase.num(h, .pct, @divFloor(100 * r.wins + r.games / 2, r.games))}),
        h.span(.{}, .{label}),
        h.span(.{ .class = "wl" }, .{W.wl.with(h, .{ .w = r.wins, .l = r.games - r.wins })}),
    });
}

fn idOf(r: *const Row) []const u8 {
    return r.f.riot_id;
}

fn gamesOf(r: *const Row) f64 {
    return @floatFromInt(r.f.together.games);
}

fn diffOf(e: ?Effect) f64 {
    return if (e) |x| x.diff else -std.math.inf(f64);
}

fn yourDiff(r: *const Row) f64 {
    return diffOf(r.f.you);
}

fn theirDiff(r: *const Row) f64 {
    return diffOf(r.f.them);
}

fn who(h: *H, r: *const Row) N {
    const q = homepage.idQuery(h.mem, r.f.riot_id) catch {
        h.oom = true;
        return .none;
    };
    return h.span(.{ .class = "who" }, .{
        h.a(.{ .href = h.fmt("#{s}", .{q}) }, .{r.f.riot_id}),
        if (r.p.now_ms > 0) h.small(.{}, .{gamerow.ago(h, r.p.now_ms - r.f.last_ms)}) else null,
    });
}

fn together(h: *H, r: *const Row) N {
    const t = r.f.together;
    return bar.view(h, @floatFromInt(t.wins), @floatFromInt(t.games), W.wl.with(h, .{ .w = t.wins, .l = t.games - t.wins }));
}

fn effect(h: *H, e: ?Effect) N {
    const x = e orelse return h.span(.{ .class = "muted" }, .{W.dash});
    return h.span(.{ .class = "eff" }, .{
        delta.bar(h, .{ .d = x.diff, .ci = x.ci, .span = 50, .scale = .game, .dot = true }),
        delta.view(h, .{ .d = x.diff, .ci = x.ci, .scale = .game }),
    });
}

fn yours(h: *H, r: *const Row) N {
    return effect(h, r.f.you);
}

fn yourTip(h: *H, r: *const Row) table.Tip {
    const x = r.f.you orelse return .{ .title = W.yours, .note = W.dash };
    return .{ .title = W.yours, .note = W.rates.with(h, .{
        .a = rateOf(x.together),
        .b = @as(u32, @intFromFloat(@round(@max(0, x.apart_rate)))),
        .n = x.together.games,
        .m = x.apart.games,
    }) };
}

fn rateOf(r: Record) u32 {
    return if (r.games == 0) 0 else @divFloor(100 * r.wins + r.games / 2, r.games);
}

fn theirs(h: *H, r: *const Row) N {
    if (r.f.their_games > 0) return effect(h, r.f.them);
    if (r.p.wasAsked(r.f.riot_id)) return h.span(.{ .class = "muted" }, .{W.fetching});
    return button.view(h, .{ .v = .quiet, .s = .s, .on = h.on(r.p, .{ .fetch = r.i }) }, .{W.fetch});
}

fn pairOf(h: *H, p: *const YourFriends, x: Pair) N {
    return h.span(.{ .class = "pair" }, .{
        champ.view(h, p.champAt(x.mine), .{ .px = .@"20" }),
        champ.view(h, p.champAt(x.theirs), .{ .px = .@"20" }),
        W.wl.with(h, .{ .w = x.wins, .l = x.games - x.wins }),
    });
}

fn pair(h: *H, r: *const Row) N {
    if (r.f.pairs.len == 0) return h.span(.{ .class = "muted" }, .{W.dash});
    return pairOf(h, r.p, r.f.pairs[0]);
}

fn detail(h: *H, r: *const Row) N {
    const f = r.f;
    var ps = h.list();
    for (f.pairs) |x| ps.add(h.li(.{}, .{pairOf(h, r.p, x)}));
    var rs = h.list();
    for (f.roles) |x| rs.add(h.li(.{}, .{h.span(.{ .class = "pair" }, .{
        role.view(h, x.mine, .{ .s = .s }),
        role.view(h, x.theirs, .{ .s = .s }),
        W.wl.with(h, .{ .w = x.wins, .l = x.games - x.wins }),
    })}));
    return h.div(.{ .class = "more" }, .{
        if (f.against.games > 0) h.p(.{}, .{W.against.with(h, .{ .w = f.against.wins, .l = f.against.games - f.against.wins })}) else null,
        if (f.pairs.len > 0) h.div(.{}, .{ h.h3(.{}, .{W.pairs}), h.ul(.{}, .{ps.done()}) }) else null,
        if (f.roles.len > 0) h.div(.{}, .{ h.h3(.{}, .{W.role_pairs}), h.ul(.{}, .{rs.done()}) }) else null,
    });
}

pub const css =
    \\@layer components {
    \\  .c-yfriends .body { display: grid; gap: var(--sp-3); }
    \\  .c-yfriends .band { display: flex; flex-wrap: wrap; align-items: baseline; gap: var(--sp-2) var(--sp-5); padding: 0 var(--sp-4); }
    \\  .c-yfriends .rec { display: flex; align-items: baseline; gap: var(--sp-2); }
    \\  .c-yfriends .rec b { font-size: var(--fs-l); font-variant-numeric: tabular-nums; }
    \\  .c-yfriends .rec .wl, .c-yfriends .who small { color: var(--muted); font-variant-numeric: tabular-nums; }
    \\  .c-yfriends .msg { margin: 0; color: var(--muted); font-size: var(--fs-s); }
    \\  .c-yfriends .who { display: grid; }
    \\  .c-yfriends .eff { display: inline-flex; align-items: center; gap: var(--sp-2); }
    \\  .c-yfriends .eff .c-dbar { width: 96px; }
    \\  .c-yfriends .pair { display: inline-flex; align-items: center; gap: var(--sp-1); font-variant-numeric: tabular-nums; }
    \\  .c-yfriends .more { display: flex; flex-wrap: wrap; gap: var(--sp-3) var(--sp-6); }
    \\  .c-yfriends .more p { margin: 0; flex-basis: 100%; }
    \\  .c-yfriends .more h3 { margin: 0 0 var(--sp-1); font-size: var(--fs-s); color: var(--muted); font-weight: var(--w-m); }
    \\  .c-yfriends .more ul { display: grid; gap: var(--sp-1); margin: 0; padding: 0; list-style: none; }
    \\}
    \\
;

pub const demo = struct {
    pub const now_ms: i64 = 1_793_050_439_000;
    const day = std.time.ms_per_day;
    pub const friends: Friends = .{
        .state = .ready,
        .games = 64,
        .with_friends = .{ .games = 23, .wins = 15 },
        .alone = .{ .games = 41, .wins = 20 },
        .champs = &.{ champ.demo("Jinx", "Jinx"), champ.demo("Thresh", "Thresh"), champ.demo("Lulu", "Lulu"), champ.demo("Ahri", "Ahri") },
        .friends = &.{
            .{
                .riot_id = "Duo Partner#EUW",
                .together = .{ .games = 14, .wins = 10 },
                .last_ms = now_ms - day,
                .you = .{ .together = .{ .games = 14, .wins = 10 }, .apart = .{ .games = 30, .wins = 15 }, .apart_rate = 50, .diff = 21.4, .ci = 19 },
                .them = .{ .together = .{ .games = 14, .wins = 10 }, .apart = .{ .games = 22, .wins = 12 }, .apart_rate = 54.5, .diff = 16.9, .ci = 21 },
                .their_games = 36,
                .pairs = &.{ .{ .mine = 0, .theirs = 1, .games = 6, .wins = 5 }, .{ .mine = 0, .theirs = 2, .games = 4, .wins = 2 } },
                .roles = &.{.{ .mine = .bot, .theirs = .support, .games = 12, .wins = 9 }},
            },
            .{
                .riot_id = "Flex Mid#EUW",
                .together = .{ .games = 6, .wins = 3 },
                .against = .{ .games = 2, .wins = 1 },
                .last_ms = now_ms - 5 * day,
                .you = .{ .together = .{ .games = 6, .wins = 3 }, .apart = .{ .games = 9, .wins = 5 }, .apart_rate = 55.6, .diff = -5.6, .ci = 30 },
                .pairs = &.{.{ .mine = 0, .theirs = 3, .games = 3, .wins = 2 }},
                .roles = &.{.{ .mine = .bot, .theirs = .mid, .games = 6, .wins = 3 }},
            },
            .{
                .riot_id = "Third One#EUW",
                .together = .{ .games = 3, .wins = 2 },
                .last_ms = now_ms - 20 * day,
            },
        },
    };
};

fn shown(h: *H, f: ?*const Friends, at: YourFriends.At, asked: ?[]const u8, open: ?u32) N {
    const p = h.mem.create(YourFriends) catch {
        h.oom = true;
        return .none;
    };
    p.* = .{ .f = f, .at = at, .now_ms = demo.now_ms };
    p.table.open = open;
    if (asked) |id| {
        p.asked[0] = hashOf(id);
        p.n_asked = 1;
    }
    return p.view(h);
}

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const d = struct {
        const waiting: Friends = blk: {
            var f = demo.friends;
            f.waiting = 40;
            break :blk f;
        };
        const nobody: Friends = .{ .state = .ready, .games = 12, .alone = .{ .games = 12, .wins = 7 } };
        const opted: Friends = .{ .state = .opted_out };
    };
    g.addFill("three friends", shown(h, &demo.friends, .ready, null, null));
    g.addFill("a row open", shown(h, &demo.friends, .ready, null, 0));
    g.addFill("older games coming, one friend fetching", shown(h, &d.waiting, .ready, "Flex Mid#EUW", null));
    g.addFill("nobody yet", shown(h, &d.nobody, .ready, null, null));
    g.add("loading", shown(h, null, .loading, null, null));
    g.add("failed", shown(h, null, .failed, null, null));
    g.add("opted out", shown(h, &d.opted, .ready, null, null));
}

const testing = std.testing;
const data = @import("data.zig");

test "the answer round-trips through ui.data" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var bytes: std.ArrayList(u8) = .empty;
    try data.encode(a, Friends, demo.friends, &bytes);
    const back = try data.decode(a, Friends, bytes.items);
    try testing.expectEqual(3, back.friends.len);
    try testing.expectEqualStrings("Duo Partner#EUW", back.friends[0].riot_id);
    try testing.expectEqual(.support, back.friends[0].roles[0].theirs);
    try testing.expectEqual(null, back.friends[2].you);
    try testing.expectEqualStrings("Lulu", back.champs[2].name);
}

test "Fetch asks once, the cell waits and the page asks again until their games are in" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    var p: YourFriends = .{ .now_ms = demo.now_ms };
    try testing.expect(!p.answered(&demo.friends));
    var ev: tree.Event = .{ .kind = .click };
    p.update(.{ .fetch = 1 }, &ev);
    try testing.expectEqualStrings("Flex Mid#EUW", p.want.?);
    p.want = null;
    p.update(.{ .fetch = 1 }, &ev);
    try testing.expectEqual(null, p.want);
    try testing.expect(p.answered(&demo.friends));
    _ = p.view(&h);
    try testing.expect(!h.oom);
    p.reset(true);
    try testing.expectEqual(0, p.n_asked);
    try testing.expectEqual(.loading, p.at);
    try testing.expect(!p.answered(null));
    try testing.expectEqual(.failed, p.at);
}

test "older games coming: ask again" {
    var p: YourFriends = .{};
    var f = demo.friends;
    f.waiting = 3;
    try testing.expect(p.answered(&f));
    try testing.expect(!p.answered(&.{ .state = .opted_out }));
}
