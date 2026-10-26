//! GamePage: the game page's first screen as one island (game-detail.md): GameStrip,
//! GameHeader, the game graph with its control row beside RangeInspector, the stat cells
//! and the objectives row. A game picked in the strip is prepared once (its moments and
//! graph) and kept. Opens on the turning minute; the URL keeps the game and the selection
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const fmt = @import("fmt.zig");
const card = @import("card.zig");
const chip = @import("chip.zig");
const strip = @import("strip.zig");
const versus = @import("versus.zig");
const objicon = @import("objicon.zig");
const gamestrip = @import("gamestrip.zig");
const gamehead = @import("gamehead.zig");
const timeline = @import("timeline.zig");
const inspector = @import("inspector.zig");
const gamedata = @import("gamedata.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "GamePage";
pub const scope = .{".c-gpage"};

pub const stamp = gamedata.stamp;

/// The range chips; `turn` is the default selection
pub const Span = enum { game, early, mid, late, turn };

const W = struct {
    pub const graph = plain("Game graph");
    pub const ranges = plain("Range");
    pub const game = plain("Game");
    pub const early = plain("0–14");
    pub const mid = plain("14–25");
    pub const late = plain("25+");
    pub const turn = plain("Turn");
    pub const prev = plain("Previous moment");
    pub const next = plain("Next moment");
    pub const of = phrase.Phrase("{i:int} of {n:int}");
    pub const count = phrase.Phrase("{n:count} moments");
    pub const one = plain("1 moment");
    pub const minutes = phrase.Phrase("{a:int}–{b:int}");
    pub const drop = plain("Biggest drop");
    pub const rise = plain("Biggest rise");
    pub const best = plain("Best minute");
    pub const peak = plain("Peak");
    pub const low = plain("Low");
    pub const at = phrase.Phrase("at {t:time}");
    pub const ahead = plain("Ahead");
    pub const ahead_ctx = phrase.Phrase("of {n:int} min");
    pub const kills = plain("Kills");
    pub const gold = plain("Gold");
    pub const towers = plain("Towers");
    pub const dragons = plain("Dragons");
    pub const grubs = plain("Grubs");
    pub const herald = plain("Herald");
    pub const baron = plain("Baron");
    pub const inhibs = plain("Inhibitors");
};

const Prep = struct {
    ms: []gamedata.Moment,
    tg: timeline.Game,
};

pub const GamePage = struct {
    a: std.mem.Allocator,
    data: *const gamedata.Data,
    /// The games list, for "All games"
    all: ?[]const u8 = null,
    /// Data.games' index
    cur: u8 = 0,
    /// Each game's, once opened
    preps: []?Prep,
    tl: timeline.Timeline,
    insp: inspector.Inspector,

    const P = @This();

    pub const Msg = union(enum) { game: u8, span: Span, step: i8, sel: [2]u16 };

    pub const Url = struct {
        g: u8 = 0,
        /// The moment's second (0: none)
        m: u16 = 0,
        /// 0-0: the turning minute; 0 to the game's end: the whole game
        r: [2]u16 = .{ 0, 0 },
        gold: bool = false,
    };

    /// Opened on the newest game
    pub fn init(a: std.mem.Allocator, data: *const gamedata.Data) !P {
        const preps = try a.alloc(?Prep, data.games.len);
        @memset(preps, null);
        var p: P = .{ .a = a, .data = data, .preps = preps, .tl = undefined, .insp = undefined };
        try p.open(0, .wc);
        return p;
    }

    fn game(p: *const P) *const gamedata.Game {
        return &p.data.games[p.cur];
    }

    fn prepare(p: *P, i: u8) !*Prep {
        if (p.preps[i]) |*x| return x;
        const g = &p.data.games[i];
        const ms = try gamedata.moments(p.a, g);
        p.preps[i] = .{ .ms = ms, .tg = try gamedata.chart(p.a, g, p.data.champs, ms) };
        return &p.preps[i].?;
    }

    /// Game i, on its turning minute, in the graph's mode
    fn open(p: *P, i: u8, mode: timeline.Mode) !void {
        const x = try p.prepare(i);
        p.cur = i;
        p.tl = .{ .game = &x.tg, .mode = if (mode == .gold and x.tg.gold.len >= 2) .gold else .wc };
        p.insp = .{ .tl = &p.tl, .game = p.game(), .champs = p.data.champs, .moments = x.ms };
        p.pick(.turn);
    }

    /// The pointers into this struct, again after a copy
    fn bind(p: *P) void {
        p.insp.tl = &p.tl;
    }

    fn spanOf(p: *const P, s: Span) ?[2]u16 {
        const dur = p.game().dur;
        return switch (s) {
            .game => .{ 0, dur },
            .early => if (dur > 14 * 60) .{ 0, 14 * 60 } else null,
            .mid => if (dur > 25 * 60) .{ 14 * 60, 25 * 60 } else null,
            .late => if (dur > 25 * 60) .{ 25 * 60, dur } else null,
            .turn => if (p.tl.game.turn) |t| blk: {
                const ms = gamedata.minuteSpan(t);
                break :blk .{ ms.a, ms.b };
            } else null,
        };
    }

    fn pick(p: *P, s: Span) void {
        const r = p.spanOf(s) orelse return;
        p.tl.select(r[0], r[1]);
    }

    fn isSpan(p: *const P, s: Span) bool {
        const r = p.spanOf(s) orelse return false;
        if (s == .game) return p.tl.range == null;
        const x = p.tl.range orelse return false;
        return x[0] == r[0] and x[1] == r[1];
    }

    pub fn toUrl(p: *const P) Url {
        const t = p.tl.toUrl();
        const r: [2]u16 = if (p.tl.range == null) .{ 0, p.game().dur } else if (p.isSpan(.turn)) .{ 0, 0 } else t.r;
        return .{ .g = p.cur, .m = t.m, .r = r, .gold = t.gold };
    }

    pub fn fromUrl(p: *P, u: Url) void {
        p.bind();
        if (u.g < p.data.games.len and u.g != p.cur) p.open(u.g, p.tl.mode) catch {};
        p.tl.fromUrl(.{ .m = u.m, .r = u.r, .gold = u.gold });
        if (u.r[0] == 0 and u.r[1] == 0) p.pick(.turn);
        if (u.r[0] == 0 and u.r[1] == p.game().dur) p.tl.range = null;
        // fromUrl keeps the moment; select() would clear it
        if (u.m != 0) for (p.tl.game.moments, 0..) |m, i| if (m.t == u.m) {
            p.tl.cur = @intCast(i);
        };
    }

    pub fn update(p: *P, m: Msg, ev: *tree.Event) void {
        p.bind();
        switch (m) {
            .game => |i| {
                if (i == p.cur or i >= p.data.games.len) return;
                p.open(i, p.tl.mode) catch return;
                ev.after = .{ .op = .scroll, .ref = "gs-cur" };
            },
            .span => |s| p.pick(s),
            .step => |d| p.tl.step(d),
            .sel => |r| p.tl.select(r[0], r[1]),
        }
        ev.push = true;
    }

    pub fn view(p: *P, h: *H) N {
        p.bind();
        const g = p.game();
        var games: std.ArrayList(gamestrip.Item) = .empty;
        for (p.data.games, 0..) |x, i| games.append(h.mem, .{
            .champ = p.data.champs[x.me().champ],
            .win = x.win,
            .dur = x.dur,
            .day = x.day,
            .selected = i == p.cur,
            .on = h.on(p, .{ .game = @as(u8, @intCast(i)) }),
        }) catch {
            h.oom = true;
        };
        return h.div(.{ .class = "c-gpage", .data_island = "games" }, .{
            gamestrip.view(h, games.items, .{ .all = p.all }),
            gamehead.view(h, g, p.data.champs),
            h.div(.{ .class = "main" }, .{
                card.view(h, .{}, &.{
                    h.div(.{ .class = "ctl" }, .{ p.tl.modes(h), p.chips(h), p.stepper(h) }),
                    p.tl.view(h),
                    p.cells(h),
                }),
                card.view(h, .{}, &.{p.insp.view(h)}),
            }),
            card.view(h, .{}, &.{versus.split(h, p.objectives(h))}),
        });
    }

    fn chips(p: *P, h: *H) N {
        const all = [_]struct { Span, tree.Text }{
            .{ .game, W.game },
            .{ .early, W.early },
            .{ .mid, W.mid },
            .{ .late, W.late },
            .{ .turn, W.turn },
        };
        var l = h.list();
        for (all) |c| if (p.spanOf(c[0]) != null) {
            l.add(chip.view(h, .{ .pressed = p.isSpan(c[0]), .on = h.on(p, .{ .span = c[0] }) }, .{c[1]}));
        };
        return h.div(.{ .class = "rg", .role = "group", .aria_label = W.ranges }, .{l.done()});
    }

    /// ‹ i of n ›: the moments in the range
    fn stepper(p: *P, h: *H) N {
        var n: u32 = 0;
        var at: u32 = 0;
        for (p.insp.moments, 0..) |m, i| if (p.inRange(m.t)) {
            n += 1;
            if (p.tl.cur != null and p.tl.cur.? == i) at = n;
        };
        if (n == 0) return .none;
        return h.div(.{ .class = "st" }, .{
            h.button(.{ .type = "button", .aria_label = W.prev, .on_click = h.on(p, .{ .step = -1 }) }, .{"‹"}),
            h.span(.{ .class = "n" }, .{if (at > 0) W.of.with(h, .{ .i = at, .n = n }) else if (n == 1) W.one else W.count.with(h, .{ .n = n })}),
            h.button(.{ .type = "button", .aria_label = W.next, .on_click = h.on(p, .{ .step = 1 }) }, .{"›"}),
        });
    }

    fn inRange(p: *const P, t: u16) bool {
        const r = p.tl.range orelse return true;
        return t + 1 >= r[0] and t <= r[1] + 1;
    }

    /// The stat cells: each selects its minute on the graph
    fn cells(p: *P, h: *H) N {
        const g = p.game();
        const sw = gamedata.swings(g);
        var items: [6]strip.Item = undefined;
        var n: usize = 0;
        const Move = struct {
            fn item(pp: *P, hh: *H, label: tree.Text, mv: gamedata.Move) strip.Item {
                const d = gamedata.signed(mv);
                const ms = gamedata.minuteSpan(mv.minute);
                return .{
                    .label = label,
                    .value = phrase.num(hh, .signed, d),
                    .ctx = W.minutes.with(hh, .{ .a = mv.minute - 1, .b = mv.minute }),
                    .step = .of(@floatFromInt(d), fmt.game_cuts),
                    .on = hh.on(pp, .{ .sel = .{ ms.a, ms.b } }),
                    .pressed = pp.selected(ms),
                };
            }
        };
        if (sw.turn) |t| {
            items[n] = Move.item(p, h, W.turn, t);
            n += 1;
        }
        if (sw.other) |o| {
            items[n] = Move.item(p, h, if (gamedata.signed(o) < 0) W.drop else W.rise, o);
            n += 1;
        }
        if (g.best) |b| if (b.minute >= 1) {
            const ms = gamedata.minuteSpan(b.minute);
            items[n] = .{
                .label = W.best,
                .value = phrase.num(h, .signed, b.gold),
                .ctx = W.minutes.with(h, .{ .a = b.minute - 1, .b = b.minute }),
                .on = h.on(p, .{ .sel = .{ ms.a, ms.b } }),
                .pressed = p.selected(ms),
            };
            n += 1;
        };
        for ([_]struct { tree.Text, ?gamedata.Extreme }{ .{ W.peak, sw.peak }, .{ W.low, sw.low } }) |x| if (x[1]) |e| {
            const ms = gamedata.minuteSpan(@max(e.minute, 1));
            items[n] = .{
                .label = x[0],
                .value = phrase.num(h, .pct, e.v),
                .ctx = W.at.with(h, .{ .t = @as(u32, e.minute) * 60 }),
                .on = h.on(p, .{ .sel = .{ ms.a, ms.b } }),
                .pressed = p.selected(ms),
            };
            n += 1;
        };
        items[n] = .{ .label = W.ahead, .value = phrase.num(h, .count, sw.ahead), .ctx = W.ahead_ctx.with(h, .{ .n = sw.minutes }) };
        n += 1;
        return h.div(.{ .class = "cells" }, .{strip.view(h, items[0..n])});
    }

    fn selected(p: *const P, s: gamedata.Span) bool {
        const r = p.tl.range orelse return false;
        return p.tl.cur == null and r[0] == s.a and r[1] == s.b;
    }

    fn objectives(p: *const P, h: *H) []const versus.Item {
        const t = gamedata.teams(p.game());
        const row = struct {
            fn f(hh: *H, label: tree.Text, icon: ?objicon.Kind, x: gamedata.Tally) versus.Item {
                const sum = x.us + x.them;
                return .{
                    .label = label,
                    .icon = icon,
                    .us = phrase.num(hh, .count, x.us),
                    .them = phrase.num(hh, .count, x.them),
                    .share = if (sum == 0) null else @as(f32, @floatFromInt(x.us)) / @as(f32, @floatFromInt(sum)),
                    .first = if (x.first) |fi| .{ .ours = fi.ours, .t = fi.t } else null,
                };
            }
        }.f;
        const gold_sum = t.gold[0] + t.gold[1];
        const items = h.mem.dupe(versus.Item, &.{
            row(h, W.kills, null, t.kills),
            .{
                .label = W.gold,
                .us = phrase.num(h, .kilo, t.gold[0]),
                .them = phrase.num(h, .kilo, t.gold[1]),
                .share = if (gold_sum == 0) null else @as(f32, @floatFromInt(t.gold[0])) / @as(f32, @floatFromInt(gold_sum)),
            },
            row(h, W.towers, .tower, t.towers),
            row(h, W.dragons, .dragon, t.dragons),
            row(h, W.grubs, .grubs, t.grubs),
            row(h, W.herald, .herald, t.herald),
            row(h, W.baron, .baron, t.baron),
            row(h, W.inhibs, .inhibitor, t.inhibitors),
        }) catch {
            h.oom = true;
            return &.{};
        };
        return items;
    }
};

pub const css =
    \\@layer components {
    \\  .c-gpage { display: flex; flex-direction: column; gap: var(--sp-4); min-width: 0; container-type: inline-size; }
    \\  .c-gpage > .main { display: grid; grid-template-columns: minmax(0, 2fr) minmax(0, 1fr); gap: var(--sp-4); align-items: start; }
    \\  .c-gpage .ctl { display: flex; align-items: center; flex-wrap: wrap; gap: var(--sp-2) var(--sp-3); margin-bottom: var(--sp-2); }
    \\  .c-gpage .rg { display: flex; gap: 4px; flex-wrap: wrap; }
    \\  .c-gpage .st { display: inline-flex; align-items: center; gap: 2px; margin-left: auto; }
    \\  .c-gpage .st > button { all: unset; width: 24px; height: 24px; text-align: center; border-radius: var(--r-s);
    \\    cursor: pointer; color: var(--t2); }
    \\  .c-gpage .st > button:hover { background: var(--panel-3); color: var(--text); }
    \\  .c-gpage .st > button:focus-visible { outline: 2px solid var(--focus); }
    \\  .c-gpage .st > .n { font-size: var(--fs-s); color: var(--t2); font-variant-numeric: tabular-nums; min-width: 48px; text-align: center; }
    \\  .c-gpage .cells { margin-top: var(--sp-3); padding-top: var(--sp-3); border-top: 1px solid var(--line); }
    \\  .c-gpage .cells > .c-strip { justify-content: space-between; }
    \\  @container (max-width: 820px) {
    \\    .c-gpage > .main { grid-template-columns: minmax(0, 1fr); }
    \\    .c-gpage .rg { order: 1; flex-basis: 100%; }
    \\  }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const p = h.mem.create(GamePage) catch {
        h.oom = true;
        return;
    };
    p.* = GamePage.init(h.mem, &@import("game_demo.zig").data) catch {
        h.oom = true;
        return;
    };
    p.all = "#games";
    g.addFill("a win, on its turn", p.view(h));
}

const testing = std.testing;

test "opens on the turn, a strip press switches game, the URL round trips" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const d = &@import("game_demo.zig").data;
    var p = try GamePage.init(a, d);
    const turn = gamedata.minuteSpan(p.tl.game.turn.?);
    try testing.expectEqual(@as(?[2]u16, .{ turn.a, turn.b }), p.tl.range);
    try testing.expectEqual(GamePage.Url{}, p.toUrl());
    var ev: tree.Event = .{ .kind = .click };
    p.update(.{ .span = .game }, &ev);
    try testing.expectEqual(@as(?[2]u16, null), p.tl.range);
    try testing.expectEqual([2]u16{ 0, d.games[0].dur }, p.toUrl().r);
    p.update(.{ .step = 1 }, &ev);
    try testing.expectEqual(@as(?u8, 0), p.tl.cur);
    const u = p.toUrl();
    p.update(.{ .game = 1 }, &ev);
    try testing.expectEqual(@as(u8, 1), p.cur);
    try testing.expect(p.insp.game == &d.games[1]);
    var q = try GamePage.init(a, d);
    q.fromUrl(u);
    try testing.expectEqual(@as(?u8, 0), q.tl.cur);
    try testing.expectEqual(@as(?[2]u16, null), q.tl.range);
    // A copy re-points its inspector at its own timeline
    var c = q;
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    t.root = c.view(&h);
    try testing.expect(!h.oom);
    try testing.expect(c.insp.tl == &c.tl);
}
