//! RangeInspector: what the game graph's selection holds (game-detail.md). The picked
//! moment, else the dragged range, else the whole game: where the kills were, win chance
//! and gold lead before → after, kills and objectives, each seat's part (FightTable);
//! then the range's moments as rows (MomentList: who died either side of the score),
//! filtered by chips. Shares the page's Timeline, so a row pressed here is the graph's
//! moment too
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const champ = @import("champ.zig");
const chip = @import("chip.zig");
const badge = @import("badge.zig");
const minimap = @import("minimap.zig");
const objicon = @import("objicon.zig");
const timeline = @import("timeline.zig");
const gamedata = @import("gamedata.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "RangeInspector";
pub const scope = .{".c-insp"};

/// Rows the stacked page shows before "All N" (gamepage's css)
pub const list_cap = 5;

pub const Filter = enum { all, yours, fights, objectives, deaths };

const W = struct {
    pub const label = plain("Selection");
    pub const span = phrase.Phrase("{a:time}–{b:time}");
    pub const turn = plain("★ Turn");
    pub const esc = plain("Esc");
    pub const clear = plain("Clear the selection");
    pub const wc = plain("Win chance");
    pub const kills = plain("Kills");
    pub const gold = plain("Gold lead");
    pub const objs = plain("Objectives");
    pub const from_to_pct = phrase.Phrase("{a:int} → {b:pct}");
    pub const from_to = phrase.Phrase("{a:signed} → {b:signed}");
    pub const score = phrase.Phrase("{a:int}–{b:int}");
    pub const seats = plain("Who did what");
    pub const filters = plain("Show moments");
    pub const all = plain("All");
    pub const yours = plain("Yours");
    pub const fights = plain("Fights");
    pub const objectives = plain("Objectives");
    pub const deaths = plain("Deaths");
    pub const moments = plain("Moments");
    pub const row = phrase.Phrase("{t:time}, win chance {d:signed}, kills {a:int}–{b:int}");
    pub const none = plain("No moments here");
    pub const more = phrase.Phrase("All {n:int}");
};

pub const Inspector = struct {
    tl: *timeline.Timeline,
    game: *const gamedata.Game,
    champs: []const champ.Champ,
    /// Parallel to tl.game.moments
    moments: []const gamedata.Moment,
    filter: Filter = .all,
    /// Every row, where the page caps the list (stacked under the graph: list_cap)
    all: bool = false,

    const I = @This();

    pub const Msg = union(enum) { filter: Filter, pick: u8, clear, more };

    pub fn update(i: *I, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .filter => |f| {
                i.filter = f;
                i.all = false;
            },
            .more => i.all = true,
            .pick => |k| {
                i.tl.cur = k;
                ev.push = true;
            },
            .clear => {
                if (i.tl.cur != null) i.tl.cur = null else i.tl.range = null;
                ev.push = true;
            },
        }
    }

    /// The moments' span: the range, else the whole game
    fn listSpan(i: *const I) gamedata.Span {
        const r = i.tl.range orelse return .{ .a = 0, .b = i.game.dur };
        return .{ .a = r[0], .b = r[1] };
    }

    /// What the summary reads: the picked moment, else the list's span
    pub fn span(i: *const I) gamedata.Span {
        if (i.tl.cur) |c| return gamedata.momentSpan(i.moments[c]);
        return i.listSpan();
    }

    fn shown(i: *const I, m: gamedata.Moment) bool {
        const s = i.listSpan();
        // A second's slack, as the graph's own range test
        if (m.t + 1 < s.a or m.t > s.b + 1) return false;
        return switch (i.filter) {
            .all => true,
            .yours => m.you,
            .fights => m.fight != null,
            .objectives => m.objs,
            .deaths => m.died,
        };
    }

    fn atTurn(i: *const I, s: gamedata.Span) bool {
        const t = i.tl.game.turn orelse return false;
        const ts = gamedata.minuteSpan(t);
        return s.a >= ts.a and s.b <= ts.b;
    }

    pub fn view(i: *I, h: *H) N {
        const s = i.span();
        const sum = gamedata.summary(i.game, s);
        const picked = i.tl.cur != null or i.tl.range != null;
        const head = h.div(.{ .class = "head" }, .{
            h.b(.{ .class = "sp" }, .{if (s.a == s.b) phrase.num(h, .time, s.a) else W.span.with(h, .{ .a = s.a, .b = s.b })}),
            if (i.atTurn(s)) badge.view(h, .turn, .{W.turn}) else null,
            if (picked) h.button(.{ .class = "esc", .type = "button", .aria_label = W.clear, .on_click = h.on(i, .clear) }, .{W.esc}) else null,
        });
        return h.el(.section, .{ .class = "c-insp", .aria_label = W.label }, .{
            head,
            h.div(.{ .class = "sum" }, .{ minimap.view(h, i.points(h, s), .{}), i.rows(h, sum) }),
            i.seats(h, sum),
            i.chips(h),
            i.list(h),
            i.more(h),
        });
    }

    fn points(i: *const I, h: *H, s: gamedata.Span) []const minimap.Point {
        var l: std.ArrayList(minimap.Point) = .empty;
        for (i.game.kills) |k| if (k.t >= s.a and k.t <= s.b) {
            l.append(h.mem, .{ .x = k.x, .y = k.y, .ours = i.game.seats[k.victim].us, .you = k.victim == i.game.you or k.killer == i.game.you }) catch {
                h.oom = true;
            };
        };
        return l.items;
    }

    fn rows(i: *const I, h: *H, sum: gamedata.Summary) N {
        const d: i16 = @as(i16, sum.wc[1]) - sum.wc[0];
        const lo = @min(sum.wc[0], sum.wc[1]);
        const hi = @max(sum.wc[0], sum.wc[1]);
        var objs = h.list();
        for (sum.objs[0..sum.n_objs], 0..) |k, n| {
            const o = i.game.objs[k];
            objs.add(h.span(.{ .key = n, .title = o.name }, .{objicon.view(h, o.kind, .{ .ours = o.ours, .named = false })}));
        }
        return h.div(.{ .class = "rows" }, .{
            h.span(.{ .class = "k" }, .{W.wc}),
            h.span(.{ .class = "v" }, .{
                h.span(.{ .class = "wb", .aria_hidden = true, .data_d = if (d > 0) "gain" else if (d < 0) "drop" else null, .style = h.vars(.{ .a = lo, .b = hi, .f = sum.wc[0] }) }, .{}),
                h.b(.{}, .{W.from_to_pct.with(h, .{ .a = sum.wc[0], .b = sum.wc[1] })}),
            }),
            h.span(.{ .class = "k" }, .{W.kills}),
            h.span(.{ .class = "v" }, .{h.b(.{}, .{
                h.span(.{ .class = "us" }, .{sum.us}),
                "–",
                h.span(.{ .class = "them" }, .{sum.them}),
            })}),
            if (sum.gold != null) h.span(.{ .class = "k" }, .{W.gold}) else null,
            if (sum.gold) |g| h.span(.{ .class = "v" }, .{
                h.span(.{ .class = "ft" }, .{W.from_to.with(h, .{ .a = g[0], .b = g[1] })}),
                h.b(.{ .class = if (g[1] >= g[0]) "us" else "them" }, .{phrase.num(h, .signed, g[1] - g[0])}),
            }) else null,
            if (sum.n_objs > 0) h.span(.{ .class = "k" }, .{W.objs}) else null,
            if (sum.n_objs > 0) h.span(.{ .class = "v" }, .{objs.done()}) else null,
        });
    }

    /// FightTable: your team left, theirs right, each seat's K/D/A and kill gold in the
    /// span; a seat that died is greyed, one that did nothing faint
    fn seats(i: *const I, h: *H, sum: gamedata.Summary) N {
        var cols: [2]tree.List = .{ h.list(), h.list() };
        for (i.game.seats, 0..) |st, k| {
            if (k >= sum.seats.len) break;
            const x = sum.seats[k];
            const idle = x.k == 0 and x.d == 0 and x.a == 0;
            cols[@intFromBool(!st.us)].add(h.li(.{ .key = k, .data_idle = idle }, .{
                champ.view(h, i.champs[st.champ], .{ .state = if (x.d > 0) .dead else .normal, .you = k == i.game.you }),
                h.span(.{ .class = "kda" }, .{ x.k, h.el(.i, .{}, .{"/"}), x.d, h.el(.i, .{}, .{"/"}), x.a }),
                if (x.gold > 0) h.span(.{ .class = "g" }, .{ "+", x.gold }) else null,
            }));
        }
        return h.div(.{ .class = "ft", .role = "group", .aria_label = W.seats }, .{
            h.ul(.{ .class = "us" }, .{cols[0].done()}),
            h.ul(.{ .class = "them" }, .{cols[1].done()}),
        });
    }

    fn chips(i: *I, h: *H) N {
        const fs = [_]struct { Filter, tree.Text }{
            .{ .all, W.all },
            .{ .yours, W.yours },
            .{ .fights, W.fights },
            .{ .objectives, W.objectives },
            .{ .deaths, W.deaths },
        };
        var l = h.list();
        for (fs) |f| l.add(chip.view(h, .{ .pressed = i.filter == f[0], .on = h.on(i, .{ .filter = f[0] }) }, .{f[1]}));
        return h.div(.{ .class = "fl", .role = "group", .aria_label = W.filters }, .{l.done()});
    }

    /// MomentList: one row a moment; the time is the row's button
    fn list(i: *I, h: *H) N {
        var l = h.list();
        for (i.moments, 0..) |m, k| if (i.shown(m)) l.add(i.row(h, m, k));
        const rs = l.done();
        if (rs.len == 0) return h.p(.{ .class = "none" }, .{W.none});
        return h.el(.ol, .{ .class = "ml", .aria_label = W.moments, .data_all = i.all or rs.len <= list_cap }, .{rs});
    }

    fn more(i: *I, h: *H) ?N {
        var n: usize = 0;
        for (i.moments) |m| n += @intFromBool(i.shown(m));
        if (i.all or n <= list_cap) return null;
        return h.button(.{ .class = "more", .type = "button", .on_click = h.on(i, .more) }, .{W.more.with(h, .{ .n = n })});
    }

    fn row(i: *I, h: *H, m: gamedata.Moment, k: usize) N {
        const g = i.game;
        const sum = gamedata.summary(g, gamedata.momentSpan(m));
        const d: i16 = @as(i16, sum.wc[1]) - sum.wc[0];
        // Who died: enemies left of the score (your kills), yours right of it
        var sides: [2]tree.List = .{ h.list(), h.list() };
        var pts: [10]minimap.Point = undefined;
        var np: usize = 0;
        if (m.fight) |f| for (g.kills) |x| if (x.fight == f) {
            const st = g.seats[x.victim];
            sides[@intFromBool(st.us)].add(champ.view(h, i.champs[st.champ], .{ .px = .@"20", .state = .dead, .you = x.victim == g.you, .named = false }));
            if (np < pts.len) {
                pts[np] = .{ .x = x.x, .y = x.y, .ours = st.us, .you = x.victim == g.you };
                np += 1;
            }
        };
        var objs = h.list();
        for (sum.objs[0..sum.n_objs]) |x| objs.add(objicon.view(h, g.objs[x].kind, .{ .ours = g.objs[x].ours, .s = .s, .named = false }));
        const on = if (i.tl.cur) |c| c == k else false;
        return h.li(.{ .key = k, .data_cur = on }, .{
            h.button(.{
                .class = "t",
                .type = "button",
                .aria_current = on,
                .aria_label = W.row.with(h, .{ .t = m.t, .d = d, .a = m.us, .b = m.them }),
                .on_click = h.on(i, .{ .pick = @as(u8, @intCast(k)) }),
            }, .{phrase.num(h, .time, m.t)}),
            if (np > 0) minimap.view(h, pts[0..np], .{ .s = .s }) else h.span(.{ .class = "nm" }, .{}),
            h.span(.{ .class = "db", .data_d = if (d > 0) "gain" else if (d < 0) "drop" else null, .style = h.vars(.{ .d = @min(@abs(d), 40) }) }, .{}),
            h.span(.{ .class = "who" }, .{
                sides[0].done(),
                if (m.fight != null) h.b(.{}, .{W.score.with(h, .{ .a = m.us, .b = m.them })}) else null,
                sides[1].done(),
            }),
            h.span(.{ .class = "ob" }, .{objs.done()}),
            if (m.gold != 0) h.span(.{ .class = if (m.gold > 0) "g us" else "g them" }, .{phrase.num(h, .signed, m.gold)}) else null,
        });
    }
};

pub const css =
    \\@layer components {
    \\  .c-insp { display: flex; flex-direction: column; gap: var(--sp-3); min-width: 0; container-type: inline-size; }
    \\  .c-insp > .head { display: flex; align-items: center; gap: var(--sp-2); }
    \\  .c-insp .sp { font-size: var(--fs-l); font-variant-numeric: tabular-nums; }
    \\  .c-insp .esc, .c-insp > .more { all: unset; margin-left: auto; padding: 2px 6px; border-radius: var(--r-s); cursor: pointer;
    \\    font-size: var(--fs-xs); color: var(--muted); box-shadow: inset 0 0 0 1px var(--line-2); }
    \\  .c-insp .esc:hover, .c-insp > .more:hover { color: var(--text); }
    \\  .c-insp .esc:focus-visible, .c-insp > .more:focus-visible { outline: 2px solid var(--focus); outline-offset: 1px; }
    \\  .c-insp > .more { display: none; }
    \\  .c-insp > .sum { display: flex; gap: var(--sp-3); align-items: flex-start; }
    \\  .c-insp > .sum > .c-map { width: 112px; }
    \\  .c-insp .rows { flex: 1; min-width: 0; display: grid; grid-template-columns: auto 1fr; gap: 6px var(--sp-3);
    \\    align-items: center; font-size: var(--fs-s); }
    \\  .c-insp .rows > .k { color: var(--muted); white-space: nowrap; }
    \\  .c-insp .rows > .v { display: flex; flex-wrap: wrap; align-items: center; justify-content: flex-end; gap: 2px var(--sp-2);
    \\    font-variant-numeric: tabular-nums; white-space: nowrap; }
    \\  .c-insp .us { color: var(--us-hot); }
    \\  .c-insp .them { color: var(--them-hot); }
    \\  .c-insp .ft { color: var(--faint); font-size: var(--fs-xs); }
    \\  .c-insp .wb { position: relative; flex: 1; min-width: 40px; max-width: 96px; height: 6px; border-radius: 3px;
    \\    background: var(--bar-track); }
    \\  .c-insp .wb::before { content: ""; position: absolute; top: 0; bottom: 0; border-radius: 3px; background: var(--muted);
    \\    left: calc(var(--a) * 1%); width: max(2px, calc((var(--b) - var(--a)) * 1%)); }
    \\  .c-insp .wb[data-d="gain"]::before { background: var(--gain); }
    \\  .c-insp .wb[data-d="drop"]::before { background: var(--drop); }
    \\  .c-insp .wb::after { content: ""; position: absolute; top: -2px; bottom: -2px; width: 2px; margin-left: -1px;
    \\    left: calc(var(--f) * 1%); background: var(--text); }
    \\  .c-insp > .ft { display: grid; grid-template-columns: 1fr 1fr; gap: var(--sp-3); }
    \\  .c-insp > .ft ul { list-style: none; margin: 0; padding: 0 0 0 var(--sp-2); display: flex; flex-direction: column; gap: 4px;
    \\    border-left: 2px solid var(--us); color: var(--text); }
    \\  .c-insp > .ft ul.them { border-left: none; border-right: 2px solid var(--them); padding: 0 var(--sp-2) 0 0; }
    \\  .c-insp > .ft li { display: flex; align-items: center; gap: var(--sp-2); font-size: var(--fs-s);
    \\    font-variant-numeric: tabular-nums; }
    \\  .c-insp > .ft .them li { flex-direction: row-reverse; }
    \\  .c-insp > .ft li[data-idle] { opacity: .45; }
    \\  .c-insp .kda { font-weight: var(--w-m); white-space: nowrap; }
    \\  .c-insp .kda > i { font-style: normal; color: var(--faint); margin: 0 1px; }
    \\  .c-insp .g { font-size: var(--fs-xs); color: var(--muted); font-variant-numeric: tabular-nums; }
    \\  .c-insp > .fl { display: flex; flex-wrap: wrap; gap: 6px; }
    \\  .c-insp .ml { list-style: none; margin: 0; padding: 0; max-height: 280px; overflow-y: auto; }
    \\  .c-insp .ml > li { position: relative; display: flex; align-items: center; gap: var(--sp-2); min-height: 32px;
    \\    padding: 2px var(--sp-2); border-radius: var(--r-s); font-size: var(--fs-s); }
    \\  .c-insp .ml > li:hover { background: var(--panel-2); }
    \\  .c-insp .ml > li[data-cur] { background: var(--sel-bg); box-shadow: inset 0 0 0 1px var(--sel-line); }
    \\  .c-insp .ml .t { all: unset; flex: none; width: 38px; font-variant-numeric: tabular-nums; color: var(--t2); cursor: pointer; }
    \\  .c-insp .ml .t::after { content: ""; position: absolute; inset: 0; border-radius: inherit; }
    \\  .c-insp .ml .t:focus-visible::after { outline: 2px solid var(--focus); outline-offset: -2px; }
    \\  .c-insp .nm { flex: none; width: 16px; }
    \\  .c-insp .db { flex: none; position: relative; width: 44px; height: 4px; border-radius: 2px; background: var(--bar-track); }
    \\  .c-insp .db::before { content: ""; position: absolute; top: 0; bottom: 0; left: 50%; border-radius: 2px;
    \\    width: calc(var(--d) * 1.25%); background: var(--gain); }
    \\  .c-insp .db[data-d="drop"]::before { left: auto; right: 50%; background: var(--drop); }
    \\  .c-insp .who { display: flex; align-items: center; gap: 3px; min-width: 0; flex: 1; overflow-x: clip; }
    \\  .c-insp .who > .c-champ + .c-champ { margin-left: -7px; }
    \\  .c-insp .who > b { margin: 0 4px; font-variant-numeric: tabular-nums; white-space: nowrap; }
    \\  .c-insp .ob { display: flex; gap: 2px; }
    \\  .c-insp .ml .g { margin-left: auto; font-weight: var(--w-m); }
    \\  .c-insp .none { margin: 0; font-size: var(--fs-s); color: var(--faint); }
    \\  @container (max-width: 330px) {
    \\    .c-insp > .sum { flex-direction: column; }
    \\    .c-insp > .sum > .rows { align-self: stretch; }
    \\    .c-insp .ml .c-map, .c-insp .ml .nm, .c-insp .ml .db { display: none; }
    \\  }
    \\}
    \\
;

const demo = @import("game_demo.zig").data;

fn demoInspector(h: *H, tl_init: timeline.Timeline, filter: Filter) ?*Inspector {
    const g = &demo.games[0];
    const ms = gamedata.moments(h.mem, g) catch return null;
    const tg = h.mem.create(timeline.Game) catch return null;
    tg.* = gamedata.chart(h.mem, g, demo.champs, ms) catch return null;
    const tl = h.mem.create(timeline.Timeline) catch return null;
    tl.* = tl_init;
    tl.game = tg;
    const i = h.mem.create(Inspector) catch return null;
    i.* = .{ .tl = tl, .game = g, .champs = demo.champs, .moments = ms, .filter = filter };
    return i;
}

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const dummy: timeline.Game = .{ .dur = 0, .wc = &.{} };
    const states = [_]struct { []const u8, timeline.Timeline, Filter }{
        .{ "the turning minute", .{ .game = &dummy, .range = .{ 1920, 1980 } }, .all },
        .{ "a moment picked in 25-33", .{ .game = &dummy, .range = .{ 1500, 1988 }, .cur = 0 }, .all },
        .{ "the whole game", .{ .game = &dummy }, .all },
        .{ "your deaths, none in the range", .{ .game = &dummy, .range = .{ 0, 60 } }, .deaths },
    };
    for (states) |s| {
        const i = demoInspector(h, s[1], s[2]) orelse {
            h.oom = true;
            return;
        };
        if (s[1].cur != null) {
            // The range's last moment
            for (i.moments, 0..) |m, k| if (m.t >= 1500) {
                i.tl.cur = @intCast(k);
            };
        }
        g.addFill(s[0], i.view(h));
    }
}

const testing = std.testing;

test "the summary follows the pick, the list the range; filters, a row press, Esc" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    const i = demoInspector(&h, .{ .game = undefined, .range = .{ 1500, 1988 } }, .all).?;
    try testing.expectEqual(gamedata.Span{ .a = 1500, .b = 1988 }, i.span());
    var ev: tree.Event = .{ .kind = .click };
    var first: ?u8 = null;
    for (i.moments, 0..) |m, k| if (first == null and i.shown(m)) {
        first = @intCast(k);
    };
    i.update(.{ .pick = first.? }, &ev);
    try testing.expect(ev.push);
    try testing.expectEqual(gamedata.momentSpan(i.moments[first.?]), i.span());
    i.update(.{ .filter = .deaths }, &ev);
    for (i.moments) |m| if (i.shown(m)) try testing.expect(m.died);
    i.update(.clear, &ev);
    try testing.expectEqual(@as(?u8, null), i.tl.cur);
    try testing.expect(i.tl.range != null);
    i.update(.clear, &ev);
    try testing.expectEqual(gamedata.Span{ .a = 0, .b = demo.games[0].dur }, i.span());
}
