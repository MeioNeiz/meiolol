//! Highlights: the records in a player's games (your-games.md "Highlights"), from the
//! List alone, as RecordTiles in labelled groups: Streaks, Lane, Fights, Games. Each
//! only when there is something to say, so a short history shows fewer rather than empty
//! ones. `top` is the Games view's row of three. A game under 5 minutes (an early
//! surrender) counts for the record and streaks, never for a length, KDA or lane record
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const fmt = @import("fmt.zig");
const gd = @import("gamedata.zig");
const yl = @import("yourlist.zig");
const yp = @import("yourpage.zig");
const recordtile = @import("recordtile.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;
const Tile = recordtile.Tile;

pub const name = "Highlights";
pub const scope = .{".c-hl"};

/// Lane gold's colour steps
const gold_cuts: [4]f32 = .{ 250, 750, 1500, 2500 };
const short_s = 300;
const lane_s = 14 * 60;

const W = struct {
    pub const streaks = plain("Streaks");
    pub const lane = plain("Lane");
    pub const fights = plain("Fights");
    pub const games = plain("Games");
    pub const streak = plain("Current streak");
    pub const longest = plain("Longest win streak");
    pub const record = plain("Record");
    pub const lead = plain("Biggest lead at 14");
    pub const above = plain("Furthest above typical at 14");
    pub const kda = plain("Best KDA");
    pub const behind = plain("Won from furthest behind");
    pub const ahead = plain("Lost from furthest ahead");
    pub const swing = plain("Biggest one-minute swing");
    pub const long = plain("Longest game");
    pub const fast = plain("Fastest win");
    pub const most = phrase.Phrase("Most played, {n:count} games");
    pub const wins = phrase.Phrase("{n:count} wins");
    pub const losses = phrase.Phrase("{n:count} losses");
    pub const wl = phrase.Phrase("{w:int}–{l:int}");
    pub const ratio = phrase.Phrase("{r:dec}");
    pub const moved = phrase.Phrase("{a:int}% → {b:int}%");
    pub const all = plain("Highlights");
};

/// Indices into the games given to `of`
pub const Records = struct {
    wins: u16 = 0,
    losses: u16 = 0,
    streak: ?yl.Streak = null,
    longest: u16 = 0,
    lead: ?usize = null,
    above: ?struct { i: usize, d: i32 } = null,
    kda: ?usize = null,
    behind: ?usize = null,
    ahead: ?usize = null,
    swing: ?struct { i: usize, m: gd.Move } = null,
    long: ?usize = null,
    fast: ?usize = null,
    most: ?struct { champ: u16, n: u16 } = null,
};

fn kdaOf(g: yl.Game) f32 {
    return @as(f32, @floatFromInt(g.k + g.a)) / @as(f32, @floatFromInt(@max(g.d, 1)));
}

/// `games` newest first
pub fn of(a: std.mem.Allocator, games: []const yl.Game) !Records {
    var r: Records = .{ .streak = yl.streak(games) };
    var run: u16 = 0;
    for (games, 0..) |g, i| {
        if (g.remake) continue;
        if (g.win) r.wins += 1 else r.losses += 1;
        run = if (g.win) run + 1 else 0;
        r.longest = @max(r.longest, run);
        if (g.dur < short_s) continue;
        if (g.lane14) |x| {
            if (g.win and x.you > 0 and (r.lead == null or x.you > games[r.lead.?].lane14.?.you)) r.lead = i;
            if (g.win and x.you < 0 and (r.behind == null or x.you < games[r.behind.?].lane14.?.you)) r.behind = i;
            if (!g.win and x.you > 0 and (r.ahead == null or x.you > games[r.ahead.?].lane14.?.you)) r.ahead = i;
            if (x.typ) |t| {
                const d = x.you - t[1];
                if (d > 0 and (r.above == null or d > r.above.?.d)) r.above = .{ .i = i, .d = d };
            }
        }
        if (r.kda == null or kdaOf(g) > kdaOf(games[r.kda.?])) r.kda = i;
        const turn = if (g.wc.len >= 2) gd.turns(g.wc)[0] else null;
        if (turn) |m| {
            if (r.swing == null or @abs(gd.signed(m)) > @abs(gd.signed(r.swing.?.m))) r.swing = .{ .i = i, .m = m };
        }
        if (r.long == null or g.dur > games[r.long.?].dur) r.long = i;
        if (g.win and (r.fast == null or g.dur < games[r.fast.?].dur)) r.fast = i;
    }
    // The newest of equals: a run counted oldest first would favour the oldest
    const counts = try a.alloc(u16, champsIn(games));
    defer a.free(counts);
    @memset(counts, 0);
    for (games) |g| if (!g.remake and g.dur >= short_s) {
        counts[g.champ] += 1;
    };
    for (games) |g| if (counts[g.champ] >= 2 and (r.most == null or counts[g.champ] > r.most.?.n)) {
        r.most = .{ .champ = g.champ, .n = counts[g.champ] };
    };
    return r;
}

fn champsIn(games: []const yl.Game) usize {
    var n: usize = 0;
    for (games) |g| n = @max(n, @as(usize, g.champ) + 1);
    return n;
}

/// Where the tiles' games link: game.html, a lookup's id ("" the example), the zone
pub const Links = struct { page: []const u8 = "/game", id: []const u8 = "", tz_min: i32 = 0 };

const Tiles = struct {
    h: *H,
    l: *const yl.List,
    games: []const yl.Game,
    r: Records,
    to: Links,

    fn chip(t: Tiles, i: usize, m: u16) recordtile.Chip {
        const g = t.games[i];
        return .{
            .me = t.l.champs[g.champ],
            .opp = if (g.opp) |o| t.l.champs[o] else null,
            .win = g.win,
            .date = yp.dayText(t.h, yl.dayOf(g.start_ms, t.to.tz_min)),
            .href = yp.gameHref(t.h, t.to.page, t.to.id, g, m),
        };
    }

    fn gold(t: Tiles, label: tree.Text, i: ?usize) ?Tile {
        const x = i orelse return null;
        const v = t.games[x].lane14.?.you;
        return .{ .label = label, .value = phrase.num(t.h, .signed, v), .step = .of(@floatFromInt(v), gold_cuts), .game = t.chip(x, lane_s) };
    }

    fn streak(t: Tiles) ?Tile {
        const s = t.r.streak orelse return null;
        if (s.n < 2) return null;
        return .{ .label = W.streak, .value = if (s.win) W.wins.with(t.h, .{ .n = s.n }) else W.losses.with(t.h, .{ .n = s.n }) };
    }

    fn longest(t: Tiles) ?Tile {
        // The current run already says it
        if (t.r.longest < 2) return null;
        if (t.r.streak) |s| if (s.win and s.n == t.r.longest) return null;
        return .{ .label = W.longest, .value = W.wins.with(t.h, .{ .n = t.r.longest }) };
    }

    fn record(t: Tiles) ?Tile {
        if (t.r.wins + t.r.losses == 0) return null;
        return .{ .label = W.record, .value = W.wl.with(t.h, .{ .w = t.r.wins, .l = t.r.losses }) };
    }

    fn above(t: Tiles) ?Tile {
        const x = t.r.above orelse return null;
        return .{ .label = W.above, .value = phrase.num(t.h, .signed, x.d), .step = .of(@floatFromInt(x.d), gold_cuts), .game = t.chip(x.i, lane_s) };
    }

    fn kda(t: Tiles) ?Tile {
        const i = t.r.kda orelse return null;
        return .{ .label = W.kda, .value = W.ratio.with(t.h, .{ .r = kdaOf(t.games[i]) }), .game = t.chip(i, 0) };
    }

    fn swing(t: Tiles) ?Tile {
        const s = t.r.swing orelse return null;
        return .{
            .label = W.swing,
            .value = W.moved.with(t.h, .{ .a = s.m.from, .b = s.m.to }),
            .step = .of(@floatFromInt(gd.signed(s.m)), fmt.game_cuts),
            .game = t.chip(s.i, @as(u16, s.m.minute) * 60),
        };
    }

    fn time(t: Tiles, label: tree.Text, i: ?usize) ?Tile {
        const x = i orelse return null;
        return .{ .label = label, .value = phrase.num(t.h, .time, t.games[x].dur), .game = t.chip(x, 0) };
    }

    fn most(t: Tiles) ?Tile {
        const m = t.r.most orelse return null;
        return .{ .label = W.most.with(t.h, .{ .n = m.n }), .value = .{ .s = t.l.champs[m.champ].name } };
    }
};

fn tilesOf(h: *H, l: *const yl.List, games: []const yl.Game, to: Links) ?Tiles {
    const r = of(h.mem, games) catch {
        h.oom = true;
        return null;
    };
    return .{ .h = h, .l = l, .games = games, .r = r, .to = to };
}

fn group(h: *H, title: tree.Text, tiles: []const ?Tile) ?N {
    var row = h.list();
    for (tiles) |t| if (t) |x| row.add(recordtile.view(h, x));
    const n = row.items.items.len;
    if (n == 0) return null;
    return h.section(.{ .class = "grp", .style = h.vars(.{ .n = n }) }, .{ h.el(.h3, .{}, .{title}), h.div(.{ .class = "tiles" }, .{row.done()}) });
}

/// The Highlights view: `games` the filtered list, newest first
pub fn view(h: *H, l: *const yl.List, games: []const yl.Game, to: Links) N {
    const t = tilesOf(h, l, games, to) orelse return .none;
    if (t.r.wins + t.r.losses == 0) return .none;
    return h.div(.{ .class = "c-hl" }, .{
        group(h, W.streaks, &.{ t.streak(), t.longest(), t.record() }),
        group(h, W.lane, &.{ t.gold(W.lead, t.r.lead), t.above() }),
        group(h, W.fights, &.{t.kda()}),
        group(h, W.games, &.{ t.gold(W.behind, t.r.behind), t.gold(W.ahead, t.r.ahead), t.swing(), t.time(W.long, t.r.long), t.time(W.fast, t.r.fast), t.most() }),
    });
}

/// The Games view's three: the first there are of a run, the lane, the fights, a swing;
/// `more` the press that opens Highlights
pub fn top(h: *H, l: *const yl.List, games: []const yl.Game, to: Links, more: ?tree.Handler) N {
    const t = tilesOf(h, l, games, to) orelse return .none;
    const first = [_]?Tile{ t.streak(), t.gold(W.lead, t.r.lead), t.gold(W.behind, t.r.behind), t.kda(), t.swing() };
    var row = h.list();
    var n: usize = 0;
    for (first) |x| if (x) |tile| if (n < 3) {
        row.add(recordtile.view(h, tile));
        n += 1;
    };
    if (n == 0) return .none;
    return h.div(.{ .class = "c-hl", .data_top = true }, .{
        if (more) |m| h.button(.{ .type = "button", .class = "more", .on_click = m }, .{W.all}) else null,
        h.div(.{ .class = "tiles" }, .{row.done()}),
    });
}

pub const css =
    \\@layer components {
    \\  /* Each group one card, wide as its records (--n), filling the row; records split by 1 px lines, from
    \\     each tile's shadow so a short last row leaves no line-coloured hole */
    \\  .c-hl { display: flex; flex-wrap: wrap; gap: var(--sp-3); }
    \\  .c-hl > .grp { flex: var(--n) 1 calc(var(--n) * 190px); min-width: 0; display: flex; flex-direction: column;
    \\    background: var(--panel); border: 1px solid var(--line); border-radius: var(--r-l); overflow: hidden; }
    \\  .c-hl h3 { margin: 0; padding: var(--sp-2) var(--sp-4); background: var(--panel-2); border-bottom: 1px solid var(--line);
    \\    font-size: var(--fs-s); font-weight: var(--w-b); color: var(--t2); }
    \\  .c-hl .tiles { flex: 1; display: grid; grid-template-columns: repeat(auto-fit, minmax(170px, 1fr)); gap: 1px; }
    \\  .c-hl .tiles > .c-rtile { border: 0; border-radius: 0; padding: var(--sp-4); background: none;
    \\    box-shadow: 1px 0 0 var(--line), 0 1px 0 var(--line), 1px 1px 0 var(--line); }
    \\  /* One card: its label opens Highlights, the records cells split by lines */
    \\  .c-hl[data-top] { display: flex; flex-direction: column; gap: var(--sp-1); padding-top: var(--sp-3);
    \\    background: var(--panel); border: 1px solid var(--line); border-radius: var(--r-l); overflow: hidden; }
    \\  .c-hl[data-top] .tiles { grid-template-columns: repeat(3, minmax(0, 1fr)); }
    \\  .c-hl[data-top] .c-rtile { padding: var(--sp-1) var(--sp-4) var(--sp-3); box-shadow: none; border-left: 1px solid var(--line); }
    \\  .c-hl[data-top] .c-rtile:first-child { border-left: 0; }
    \\  .c-hl > .more { all: unset; align-self: start; margin-inline: var(--sp-4); cursor: pointer; color: var(--accent); font-size: var(--fs-s); }
    \\  .c-hl > .more:hover { text-decoration: underline; }
    \\  .c-hl > .more:focus-visible { outline: 2px solid var(--focus); outline-offset: 2px; border-radius: var(--r-ctl); }
    \\  @media (max-width: 760px) {
    \\    .c-hl .tiles, .c-hl[data-top] .tiles { grid-template-columns: repeat(2, minmax(0, 1fr)); }
    \\    .c-hl > .grp { flex-basis: 100%; }
    \\  }
    \\}
    \\
;

/// The gallery's "Highlights" press, which goes nowhere
const Tap = struct {
    pub const Msg = union(enum) { more };
    pub fn update(_: *Tap, _: Msg, _: *tree.Event) void {}
};
var gallery_tap: Tap = .{};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.addFill("every group", view(h, &yp.demo.list, &yp.demo.games, .{}));
    g.addFill("the Games view's three", top(h, &yp.demo.list, &yp.demo.games, .{}, h.on(&gallery_tap, .more)));
}

const testing = std.testing;

test "records: runs, the lane, the fights, the games" {
    const G = yl.Game;
    const base: G = .{ .start_ms = 0, .dur = 1800, .patch = "", .queue = .solo, .champ = 0, .win = true, .k = 1, .d = 1, .a = 1 };
    var gs: [7]G = @splat(base);
    // Newest first: W W L W W W, then a 4-minute loss
    gs[2].win = false;
    gs[6].win = false;
    gs[6].dur = 240;
    gs[6].k = 30;
    gs[0].lane14 = .{ .you = 900, .typ = .{ -500, 100, 600 } };
    gs[1].lane14 = .{ .you = -1200 };
    gs[2].lane14 = .{ .you = 400 };
    gs[3].lane14 = .{ .you = 300, .typ = .{ -800, -700, 0 } };
    gs[4].k = 9;
    gs[4].champ = 1;
    gs[5].champ = 1;
    gs[5].dur = 1500;
    gs[3].dur = 2400;
    gs[1].wc = &.{ 50, 52, 30, 45 };
    const r = try of(testing.allocator, &gs);
    try testing.expectEqual(5, r.wins);
    try testing.expectEqual(2, r.losses);
    try testing.expectEqual(yl.Streak{ .win = true, .n = 2 }, r.streak.?);
    try testing.expectEqual(3, r.longest);
    try testing.expectEqual(0, r.lead.?);
    try testing.expectEqual(1, r.behind.?);
    try testing.expectEqual(2, r.ahead.?);
    // Game 3: 300 against a typical -700
    try testing.expectEqual(3, r.above.?.i);
    try testing.expectEqual(1000, r.above.?.d);
    // The 4-minute 30/1/1 doesn't count
    try testing.expectEqual(4, r.kda.?);
    try testing.expectEqual(1, r.swing.?.i);
    try testing.expectEqual(2, r.swing.?.m.minute);
    try testing.expectEqual(3, r.long.?);
    try testing.expectEqual(5, r.fast.?);
    // Champion 0: games 0-3 (6 is too short)
    try testing.expectEqual(0, r.most.?.champ);
    try testing.expectEqual(4, r.most.?.n);
}

fn count(t: *const tree.Tree, n: N, class: []const u8) usize {
    var c: usize = @intFromBool(std.mem.eql(u8, t.attr(n, "class") orelse "", class));
    for (t.kidsOf(n)) |k| c += count(t, k, class);
    return c;
}

test "the view: groups with something to say; the top three link to their moment" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    const n = view(&h, &yp.demo.list, &yp.demo.games, .{});
    // The demo has no lane figures: Streaks, Fights, Games
    try testing.expectEqual(3, count(&t, n, "grp"));
    const tp = top(&h, &yp.demo.list, &yp.demo.games, .{}, null);
    try testing.expectEqual(2, count(&t, tp, "c-rtile"));
    try testing.expectEqualStrings("/game#g=0", t.attr(t.find(tp, "class", "chip").?, "href").?);
    try testing.expect(!h.oom);
    // None at all: nothing
    try testing.expectEqual(N.none, view(&h, &yp.demo.list, &.{}, .{}));
}
