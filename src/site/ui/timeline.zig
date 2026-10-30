//! TimelineChart: a game by minute, win chance (or your team's gold lead) as an area split
//! at even, with what happened kept off the line (game-detail.md): FightStrip above the
//! plot (a mark per moment, coloured by who came out ahead; objectives off its line,
//! yours above), EdgeMarks (deaths as portraits on the plot's edges, the enemy's on top,
//! yours under, one stack a minute) and TurnBand (the turning minute). Drag selects a
//! range (RangeSelect), a tap near a moment or a mark picks it, ← → step through the
//! moments, Escape clears. The page's inspector reads `range` and `cur`; both live in the
//! URL. Under 480 px of container: epic objectives only, deaths as ticks
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const chart = @import("chart.zig");
const champ = @import("champ.zig");
const segmented = @import("segmented.zig");
const card = @import("card.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "TimelineChart";
pub const scope = .{".c-tl"};

pub const Moment = struct {
    t: u16,
    /// Kills by each side
    us: u8 = 0,
    them: u8 = 0,
    /// An objective with no fight (an uncontested Baron)
    objective: bool = false,
};

pub const ObjKind = enum {
    dragon,
    grubs,
    herald,
    baron,
    tower,
    inhib,

    fn epic(k: ObjKind) bool {
        return k == .dragon or k == .herald or k == .baron;
    }
};

pub const Objective = struct { t: u16, ours: bool, kind: ObjKind, name: []const u8 };

pub const Death = struct {
    t: u16,
    /// One of yours died
    ours: bool,
    champ: champ.Champ,
    you: bool = false,
};

pub const Game = struct {
    /// Seconds
    dur: u16,
    /// Your team's win chance in % at each minute from 0
    wc: []const f32,
    /// Your team's gold lead at each minute
    gold: []const f32 = &.{},
    /// The turning minute: the band covers the minute before it
    turn: ?u8 = null,
    moments: []const Moment = &.{},
    objectives: []const Objective = &.{},
    deaths: []const Death = &.{},
};

pub const Mode = enum { wc, gold };

const W = struct {
    pub const label = plain("The game by minute");
    pub const game = plain("Timeline");
    pub const wc = plain("Win chance");
    pub const gold = plain("Gold");
    pub const view = plain("Graph");
    pub const mark = phrase.Phrase("{t:time}, {a:int}–{b:int}");
    pub const fights = plain("Fights");
    pub const tip_wc = phrase.Phrase(" · {v:pct}");
    pub const tip_gold = phrase.Phrase(" · {v:signed} gold");
    pub const star = plain("★");
};

pub const Timeline = struct {
    game: *const Game,
    mode: Mode = .wc,
    /// Seconds a..b
    range: ?[2]u16 = null,
    /// A moment's index
    cur: ?u8 = null,
    /// ChartTip at this second
    tip: ?u16 = null,
    press: chart.Press = .{},
    /// Compact's pointer
    read: chart.Reading = .{},
    /// Home's small game: a reading tip only (no range, no moment), deaths as ticks,
    /// epic objectives only, no fight marks
    compact: bool = false,

    const T = @This();

    pub const Msg = union(enum) { plot, mark: u8, key, mode: Mode };

    pub const Url = struct {
        /// The moment's second (0: none)
        m: u16 = 0,
        r: [2]u16 = .{ 0, 0 },
        gold: bool = false,
    };

    pub fn toUrl(t: *const T) Url {
        return .{
            .m = if (t.cur) |i| t.game.moments[i].t else 0,
            .r = t.range orelse .{ 0, 0 },
            .gold = t.mode == .gold,
        };
    }

    pub fn fromUrl(t: *T, u: Url) void {
        t.cur = null;
        for (t.game.moments, 0..) |m, i| if (u.m != 0 and m.t == u.m) {
            t.cur = @intCast(i);
        };
        t.range = if (u.r[0] < u.r[1] and u.r[1] <= t.game.dur) u.r else null;
        t.mode = if (u.gold and t.game.gold.len >= 2) .gold else .wc;
    }

    fn dur(t: *const T) f32 {
        return @floatFromInt(t.game.dur);
    }

    fn series(t: *const T) []const f32 {
        return if (t.mode == .gold) t.game.gold else t.game.wc;
    }

    /// The series between minutes, at second s
    pub fn valAt(t: *const T, s: f32) f32 {
        const v = t.series();
        if (v.len == 0) return 0;
        const m = s / 60;
        const i: usize = @min(v.len - 1, @as(usize, @intFromFloat(@max(0, m))));
        const j = @min(v.len - 1, i + 1);
        return v[i] + (v[j] - v[i]) * (m - @as(f32, @floatFromInt(i)));
    }

    fn inRange(t: *const T, s: u16) bool {
        const r = t.range orelse return true;
        // A second's slack: a fight at the range's edge still belongs to it
        return s + 1 >= r[0] and s <= r[1] + 1;
    }

    /// Select seconds a..b (a stat cell pressed); the whole game clears it
    pub fn select(t: *T, a: u16, b: u16) void {
        t.range = if (a == 0 and b >= t.game.dur) null else .{ a, @min(b, t.game.dur) };
        t.cur = null;
    }

    /// The next (d 1) or previous (d -1) moment in the range
    pub fn step(t: *T, d: i32) void {
        var at: ?usize = null;
        var first: ?u8 = null;
        var last: ?u8 = null;
        var vis: [256]u8 = undefined;
        var n: usize = 0;
        for (t.game.moments, 0..) |m, i| if (t.inRange(m.t) and n < vis.len) {
            if (is(t.cur, i)) at = n;
            vis[n] = @intCast(i);
            n += 1;
        };
        if (n == 0) return;
        first = vis[0];
        last = vis[n - 1];
        if (at) |k| {
            const next = std.math.clamp(@as(i32, @intCast(k)) + d, 0, @as(i32, @intCast(n - 1)));
            t.cur = vis[@intCast(next)];
        } else t.cur = if (d > 0) first else last;
    }

    pub fn update(t: *T, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .mode => |md| t.mode = md,
            .mark => |i| {
                t.cur = i;
                if (!t.inRange(t.game.moments[i].t)) t.range = null;
                ev.push = true;
            },
            .key => {
                const k = ev.text;
                if (std.mem.eql(u8, k, "ArrowRight")) t.step(1) else if (std.mem.eql(u8, k, "ArrowLeft")) t.step(-1) else if (std.mem.eql(u8, k, "Escape")) {
                    if (t.cur != null) t.cur = null else if (t.range != null) t.range = null else return;
                } else return;
                ev.handled = true;
                if (t.cur != null) ev.after = .{ .op = .focus, .ref = "tl-cur" };
            },
            .plot => if (t.compact) switch (t.read.pointer(ev)) {
                // The reading under the pointer, never a range or a moment
                .none => {},
                .at => |f| t.tip = t.sec(f),
                .tap => |x| if (x.was != null and @abs(x.f - x.was.?) * ev.w < 12) {
                    t.tip = null;
                    t.read.drop();
                } else {
                    t.tip = t.sec(x.f);
                },
                .clear => t.tip = null,
            } else switch (t.press.pointer(ev)) {
                .none => {},
                .hover => |f| t.tip = t.sec(f),
                .leave => t.tip = null,
                .range => |r| {
                    t.range = .{ t.sec(r[0]), t.sec(r[1]) };
                    t.cur = null;
                    t.tip = t.sec(if (ev.x / @max(1, ev.w) <= r[0]) r[0] else r[1]);
                },
                .tap => |f| {
                    const s = f * t.dur();
                    var best: ?u8 = null;
                    var bd: f32 = t.dur() / 30;
                    for (t.game.moments, 0..) |mo, i| {
                        const d = @abs(@as(f32, @floatFromInt(mo.t)) - s);
                        if (d < bd) {
                            bd = d;
                            best = @intCast(i);
                        }
                    }
                    if (best) |b| {
                        t.cur = b;
                        if (!t.inRange(t.game.moments[b].t)) t.range = null;
                        ev.push = true;
                    }
                },
            },
        }
    }

    fn sec(t: *const T, f: f32) u16 {
        return @intFromFloat(@round(f * t.dur()));
    }

    fn plane(t: *const T) chart.Plane {
        const x: chart.Scale = .{ .lo = 0, .hi = t.dur() };
        if (t.mode == .wc) return .{ .x = x, .y = .{ .lo = 0, .hi = 100 }, .dx = 60, .x_end = t.dur() };
        var m: f32 = 0;
        for (t.game.gold) |v| m = @max(m, @abs(v));
        const top = chart.niceCeil(m * 1.05);
        return .{ .x = x, .y = .{ .lo = -top, .hi = top }, .dx = 60, .x_end = t.dur() };
    }

    /// The Win chance | Gold switch, for the page's chart head
    pub fn modes(t: *T, h: *H) N {
        return segmented.view(h, .{ .s = .s, .label = W.view }, &.{
            .{ .label = W.wc, .selected = t.mode == .wc, .on = h.on(t, .{ .mode = .wc }) },
            .{ .label = W.gold, .selected = t.mode == .gold, .disabled = t.game.gold.len < 2, .on = h.on(t, .{ .mode = .gold }) },
        });
    }

    pub fn view(t: *T, h: *H) N {
        const p = t.plane();
        const v = t.series();
        const base: f32 = if (t.mode == .wc) 50 else 0;
        const ar = chart.area(h, p, v, base);
        var over = h.list();
        if (t.range) |r| over.add(chart.range(h, p.x.at(@floatFromInt(r[0])), p.x.at(@floatFromInt(r[1]))));
        if (t.game.turn) |m| if (m >= 1) {
            over.add(h.span(.{ .class = "star", .aria_hidden = true, .style = h.vars(.{ .x = p.x.at((@as(f32, @floatFromInt(m)) - 0.5) * 60) }) }, .{W.star}));
        };
        if (t.cur) |i| {
            const s: f32 = @floatFromInt(t.game.moments[i].t);
            for (chart.cursor(h, p.x.at(s), p.py(t.valAt(s)))) |n| over.add(n);
        }
        if (t.tip) |s| {
            const sf: f32 = @floatFromInt(s);
            const val = t.valAt(sf);
            const figure = if (t.mode == .wc)
                W.tip_wc.with(h, .{ .v = @as(i32, @intFromFloat(@round(val))) })
            else
                W.tip_gold.with(h, .{ .v = @as(i32, @intFromFloat(@round(val))) });
            for (chart.tip(h, p.x.at(sf), .{ h.b(.{}, .{phrase.num(h, .time, s)}), figure })) |n| over.add(n);
        }
        const live = !t.compact;
        return chart.frame(h, .{
            .label = W.label,
            .class = "c-chart c-tl",
            .height = if (t.compact) 110 else 190,
            .y = t.yTicks(h, p),
            .x = chart.minuteTicks(h, p.x, t.dur()),
            .above = &.{ t.strip(h, p), t.edge(h, p, false) },
            .below = &.{t.edge(h, p, true)},
            .marks = &.{
                if (t.game.turn) |m| (if (m >= 1) chart.span(h, p, @as(f32, @floatFromInt(m - 1)) * 60, @as(f32, @floatFromInt(m)) * 60, "turn") else N.none) else N.none,
                ar[0],
                ar[1],
                chart.line(h, p, v, .main),
            },
            .over = over.done(),
            .press = true,
            .on = .{
                .down = h.on(t, .plot),
                .move = h.on(t, .plot),
                .up = h.on(t, .plot),
                .leave = h.on(t, .plot),
                .cancel = h.on(t, .plot),
            },
            .on_key = if (live) h.on(t, .key) else null,
        });
    }

    fn yTicks(t: *const T, h: *H, p: chart.Plane) []const chart.Tick {
        if (t.mode == .wc) {
            const all = chart.chanceTicks(h, p);
            // 0, 50 and 100% only: five labels crowd the compact plot
            if (!t.compact or all.len != 5) return all;
            return h.mem.dupe(chart.Tick, &.{ all[0], all[2], all[4] }) catch {
                h.oom = true;
                return all;
            };
        }
        var l: std.ArrayList(chart.Tick) = .empty;
        for ([_]f32{ 1, 0.5, 0, -0.5, -1 }) |k| {
            const v = k * p.y.hi;
            l.append(h.mem, .{ .at = p.py(v), .label = phrase.num(h, .signed, @as(i32, @intFromFloat(v))), .zero = k == 0 }) catch {
                h.oom = true;
            };
        }
        return l.items;
    }

    /// FightStrip: one line, a mark per moment, objectives off it (yours above, a second
    /// row when two would touch)
    fn strip(t: *T, h: *H, p: chart.Plane) N {
        var l = h.list();
        var last: [2][2]f32 = .{ .{ -100, -100 }, .{ -100, -100 } };
        for (t.game.objectives) |o| {
            if (t.compact and !o.kind.epic()) continue;
            const x = p.x.at(@floatFromInt(o.t));
            const side = &last[@intFromBool(!o.ours)];
            const row: u8 = if (x - side[0] >= 1.6) 0 else if (x - side[1] >= 1.6) 1 else 0;
            side[row] = x;
            l.add(h.el(.i, .{
                .class = "ob",
                .data_k = o.kind,
                .data_side = if (o.ours) "us" else "them",
                .data_minor = !o.kind.epic(),
                .data_dim = !t.inRange(o.t),
                .title = o.name,
                .style = h.vars(.{ .x = x, .r = row }),
            }, .{}));
        }
        // A roving tab stop: the chosen mark, else the first in the range
        var stop: ?usize = if (t.cur) |c| c else null;
        if (stop == null) for (t.game.moments, 0..) |m, i| if (t.inRange(m.t)) {
            stop = i;
            break;
        };
        if (!t.compact) for (t.game.moments, 0..) |m, i| {
            const on = is(t.cur, i);
            l.add(h.button(.{
                .key = i,
                .class = "fm",
                .type = "button",
                .tabindex = if (is(stop, i)) @as(i8, 0) else -1,
                .data_won = if (m.us > m.them) "us" else if (m.them > m.us) "them" else "even",
                .data_dim = !t.inRange(m.t),
                .data_ref = if (on) "tl-cur" else null,
                .aria_current = on,
                .aria_label = W.mark.with(h, .{ .t = m.t, .a = m.us, .b = m.them }),
                .style = h.vars(.{ .x = p.x.at(@floatFromInt(m.t)) }),
                .on_click = h.on(t, .{ .mark = @as(u8, @intCast(i)) }),
            }, .{}));
        };
        return h.div(.{ .class = "fs", .role = "group", .aria_label = W.fights }, .{l.done()});
    }

    /// EdgeMarks: the enemy's deaths stacked up from the plot's top edge (`under`
    /// false), yours down from its bottom, one stack a minute, every death a portrait
    /// (overlapping past two); the band as tall as the tallest stack
    fn edge(t: *T, h: *H, p: chart.Plane, under: bool) N {
        var stacks = h.list();
        var tallest: usize = 0;
        const ds = t.game.deaths;
        var i: usize = 0;
        while (i < ds.len) {
            if (ds[i].ours != under) {
                i += 1;
                continue;
            }
            const minute = ds[i].t / 60;
            var group: [16]usize = undefined;
            var n: usize = 0;
            var j = i;
            while (j < ds.len and ds[j].t / 60 == minute) : (j += 1) {
                if (ds[j].ours == under and n < group.len) {
                    group[n] = j;
                    n += 1;
                }
            }
            var kids = h.list();
            for (group[0..n]) |k| {
                const d = ds[k];
                kids.add(h.span(.{ .class = "pt", .data_you = d.you }, .{h.img(.{ .src = d.champ.src, .alt = d.champ.name })}));
            }
            tallest = @max(tallest, n);
            stacks.add(h.span(.{
                .class = "st",
                .data_dim = !t.inRange(ds[i].t),
                .style = h.vars(.{ .x = p.x.at((@as(f32, @floatFromInt(minute)) + 0.5) * 60), .n = @min(n, 4) }),
            }, .{ kids.done(), h.el(.i, .{ .class = "tk" }, .{}) }));
            i = j;
        }
        return h.div(.{
            .class = "em",
            .data_at = if (under) "bottom" else "top",
            .data_compact = t.compact,
            .style = h.vars(.{ .n = @max(tallest, 2) }),
        }, .{stacks.done()});
    }
};

fn is(x: anytype, i: usize) bool {
    return if (x) |v| v == i else false;
}

pub const css =
    \\@layer components {
    \\  .c-tl > .fs { position: relative; height: 46px; }
    \\  .c-tl > .fs::before { content: ""; position: absolute; left: 0; right: 0; top: 22px; height: 2px; background: var(--line-2); }
    \\  .c-tl .fm { all: unset; position: absolute; left: calc(var(--x) * 1%); top: 23px; width: 10px; height: 10px;
    \\    margin: -5px 0 0 -5px; border-radius: 50%; color: var(--t2); opacity: 0.7; cursor: pointer; }
    \\  .c-tl .fm::before { content: ""; position: absolute; inset: 1px;
    \\    background: linear-gradient(45deg, transparent 39%, currentColor 39% 61%, transparent 61%),
    \\      linear-gradient(-45deg, transparent 39%, currentColor 39% 61%, transparent 61%); }
    \\  .c-tl .fm::after { content: ""; position: absolute; inset: -8px -2px; }
    \\  .c-tl .fm[data-won="us"] { color: var(--us-hot); }
    \\  .c-tl .fm[data-won="them"] { color: var(--them-hot); }
    \\  .c-tl .fm:hover { opacity: 1; }
    \\  .c-tl .fm[aria-current="true"] { z-index: 1; opacity: 1; background: var(--panel); box-shadow: 0 0 0 1.5px var(--accent); }
    \\  .c-tl .fm:focus-visible { outline: 2px solid var(--focus); outline-offset: 3px; }
    \\  .c-tl .ob { position: absolute; left: calc(var(--x) * 1%); width: 7px; height: 7px; margin-left: -3.5px;
    \\    top: calc(8px - var(--r) * 9px); transform: rotate(45deg); background: var(--us-hot); }
    \\  .c-tl .ob[data-side="them"] { top: calc(32px + var(--r) * 9px); background: var(--them-hot); }
    \\  .c-tl .ob[data-k="baron"], .c-tl .ob[data-k="herald"] { width: 9px; height: 9px; margin-left: -4.5px; }
    \\  .c-tl .ob[data-k="tower"] { transform: none; border-radius: 1px; width: 6px; height: 6px; margin-left: -3px; }
    \\  .c-tl .ob[data-k="inhib"] { transform: none; border-radius: 50%; }
    \\  .c-tl .ob[data-k="grubs"] { transform: none; border-radius: 50%; width: 5px; height: 5px; margin-left: -2.5px; }
    \\  .c-tl [data-dim] { opacity: 0.3; }
    \\  .c-tl > .em { position: relative; height: calc(15px + (var(--n) - 1) * 11px + 6px); }
    \\  .c-tl .st { position: absolute; left: calc(var(--x) * 1%); bottom: 3px; display: flex; flex-direction: column-reverse;
    \\    align-items: center; transform: translateX(-50%); }
    \\  .c-tl .st > .pt + .pt { margin-bottom: -4px; }
    \\  .c-tl > .em[data-at="bottom"] .st > .pt + .pt { margin: -4px 0 0; }
    \\  .c-tl .st > .pt:hover { position: relative; z-index: 1; transform: scale(1.6); }
    \\  .c-tl > .em[data-at="bottom"] .st { top: 3px; bottom: auto; flex-direction: column; }
    \\  .c-tl .pt { display: block; width: 15px; height: 15px; border-radius: 50%; overflow: hidden;
    \\    box-shadow: 0 0 0 1.2px var(--them); }
    \\  .c-tl > .em[data-at="bottom"] .pt { box-shadow: 0 0 0 1.2px var(--us); }
    \\  .c-tl > .em .pt[data-you] { box-shadow: 0 0 0 2px var(--accent); }
    \\  .c-tl .pt img { display: block; width: 100%; height: 100%; }
    \\  .c-tl .tk { display: none; width: 3px; height: calc(var(--n) * 2px + 4px); border-radius: 1px; background: var(--them); }
    \\  .c-tl > .em[data-at="bottom"] .tk { background: var(--us); }
    \\  .c-tl > .em[data-compact] { height: 14px; }
    \\  .c-tl > .em[data-compact] .pt { display: none; }
    \\  .c-tl > .em[data-compact] .tk { display: block; }
    \\  .c-tl .star { position: absolute; top: 2px; left: calc(var(--x) * 1%); transform: translateX(-50%);
    \\    color: var(--turn); line-height: 1; pointer-events: none; }
    \\  .c-tl .turn { fill: var(--turn); opacity: 0.13; }
    \\  @container (max-width: 480px) {
    \\    .c-tl .ob[data-minor] { display: none; }
    \\    .c-tl > .em { height: 14px; }
    \\    .c-tl .pt { display: none; }
    \\    .c-tl .tk { display: block; }
    \\  }
    \\}
    \\
;

pub const demo_game: Game = blk: {
    const d = @import("chart_demo.zig");
    break :blk .{
        .dur = d.dur,
        .wc = &d.wc,
        .gold = &d.gold,
        .turn = d.turn,
        .moments = &d.moments,
        .objectives = &d.objectives,
        .deaths = &d.deaths,
    };
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const states = [_]struct { []const u8, Timeline }{
        .{ "the turning moment picked", .{ .game = &demo_game, .cur = 17 } },
        .{ "gold, a range dragged, the tip", .{ .game = &demo_game, .mode = .gold, .range = .{ 1500, 1800 }, .tip = 1800 } },
        .{ "compact, the reading tip only", .{ .game = &demo_game, .compact = true } },
    };
    for (states) |s| {
        const t = h.mem.create(Timeline) catch {
            h.oom = true;
            return;
        };
        t.* = s[1];
        const switch_ = if (t.compact) N.none else t.modes(h);
        g.addFill(s[0], card.view(h, .{}, &.{ card.head(h, W.game, null, &.{switch_}), t.view(h) }));
    }
}

const testing = std.testing;

test "on the fake DOM: a linked moment, a dragged range, arrows within it, Escape, a tap" {
    const island = @import("island.zig");
    const Fake = @import("fakedom.zig").Fake;
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var fake: Fake = .{ .a = a, .width = 760 };
    try fake.fragment.appendSlice(a, "#m=2107");
    var rt: island.Runtime(Fake) = .init(a, &fake);
    var server: Timeline = .{ .game = &demo_game };
    var state = server;
    const t = try a.create(tree.Tree);
    t.* = .{};
    var h: H = .init(a, t);
    t.root = server.view(&h);
    fake.server = t;
    const i = try rt.add(Timeline, &state, &server, "#tl");
    try testing.expectEqual(@as(?u8, 17), state.cur);
    const cur = i.current();
    const plot = cur.node(cur.find(cur.root, "class", "plot").?).dom;
    // 2498 s over 760 px: 456 px is 1499 s, 548 px 1801 s
    _ = rt.event(0, .{ .kind = .pointerdown, .target = plot, .x = 456 });
    _ = rt.event(0, .{ .kind = .pointermove, .target = plot, .x = 548 });
    _ = rt.event(0, .{ .kind = .pointerup, .target = plot, .x = 548 });
    try testing.expectEqual(@as(?[2]u16, .{ 1499, 1801 }), state.range);
    try testing.expectEqual(@as(?u8, null), state.cur);
    // The range's moments are 10 (1531) to 14 (1766)
    for ([_][]const u8{ "ArrowRight", "ArrowRight" }) |k| _ = rt.event(0, .{ .kind = .keydown, .target = plot, .text = k });
    try testing.expectEqual(@as(?u8, 11), state.cur);
    try testing.expect(fake.active() != 0);
    for (0..3) |_| _ = rt.event(0, .{ .kind = .keydown, .target = plot, .text = "ArrowLeft" });
    try testing.expectEqual(@as(?u8, 10), state.cur);
    _ = rt.event(0, .{ .kind = .keydown, .target = plot, .text = "Escape" });
    try testing.expectEqual(@as(?u8, null), state.cur);
    try testing.expect(state.range != null);
    _ = rt.event(0, .{ .kind = .keydown, .target = plot, .text = "Escape" });
    try testing.expectEqual(@as(?[2]u16, null), state.range);
    // A tap 3 s after the fight at 2107 picks it
    const pushes = fake.pushes;
    _ = rt.event(0, .{ .kind = .pointerdown, .target = plot, .x = 642 });
    _ = rt.event(0, .{ .kind = .pointerup, .target = plot, .x = 642 });
    try testing.expectEqual(@as(?u8, 17), state.cur);
    try testing.expectEqual(pushes + 1, fake.pushes);
    try testing.expectEqualStrings("#m=2107", fake.fragment.items);
    try testing.expectEqual(@as(u32, 0), fake.warnings);
}

test "compact: the pointer shows the reading, never a range; a tap keeps it" {
    const island = @import("island.zig");
    const Fake = @import("fakedom.zig").Fake;
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var fake: Fake = .{ .a = a, .width = 760 };
    var rt: island.Runtime(Fake) = .init(a, &fake);
    var server: Timeline = .{ .game = &demo_game, .compact = true };
    var state = server;
    const t = try a.create(tree.Tree);
    t.* = .{};
    var h: H = .init(a, t);
    t.root = server.view(&h);
    fake.server = t;
    const i = try rt.add(Timeline, &state, &server, "#tl");
    const cur = i.current();
    const plot = cur.node(cur.find(cur.root, "class", "plot").?).dom;
    _ = rt.event(0, .{ .kind = .pointermove, .target = plot, .x = 456 });
    try testing.expectEqual(@as(?u16, 1499), state.tip);
    _ = rt.event(0, .{ .kind = .pointerleave, .target = plot });
    try testing.expectEqual(@as(?u16, null), state.tip);
    _ = rt.event(0, .{ .kind = .pointerdown, .target = plot, .x = 456 });
    _ = rt.event(0, .{ .kind = .pointermove, .target = plot, .x = 548 });
    _ = rt.event(0, .{ .kind = .pointerup, .target = plot, .x = 548 });
    try testing.expectEqual(@as(?[2]u16, null), state.range);
    try testing.expectEqual(@as(?u16, 1801), state.tip);
    _ = rt.event(0, .{ .kind = .pointerdown, .target = plot, .x = 456 });
    _ = rt.event(0, .{ .kind = .pointerup, .target = plot, .x = 456 });
    _ = rt.event(0, .{ .kind = .pointerleave, .target = plot });
    try testing.expectEqual(@as(?u16, 1499), state.tip);
    try testing.expectEqual(@as(?u8, null), state.cur);
    // A second tap on the kept reading drops it (a phone has no hover to leave)
    for ([_]tree.Ev{ .pointerdown, .pointerup, .pointerleave }) |k| _ = rt.event(0, .{ .kind = k, .target = plot, .x = 462 });
    try testing.expectEqual(@as(?u16, null), state.tip);
    // A touch drag reads, and the tip goes with the finger
    _ = rt.event(0, .{ .kind = .pointerdown, .target = plot, .x = 456 });
    _ = rt.event(0, .{ .kind = .pointermove, .target = plot, .x = 548 });
    try testing.expectEqual(@as(?u16, 1801), state.tip);
    _ = rt.event(0, .{ .kind = .pointerup, .target = plot, .x = 548 });
    _ = rt.event(0, .{ .kind = .pointerleave, .target = plot });
    try testing.expectEqual(@as(?u16, null), state.tip);
    // A kept tip, then a scroll that starts on the plot (pointercancel): it goes
    for ([_]tree.Ev{ .pointerdown, .pointerup, .pointerleave }) |k| _ = rt.event(0, .{ .kind = k, .target = plot, .x = 456 });
    try testing.expectEqual(@as(?u16, 1499), state.tip);
    _ = rt.event(0, .{ .kind = .pointerdown, .target = plot, .x = 300 });
    _ = rt.event(0, .{ .kind = .pointercancel, .target = plot });
    try testing.expectEqual(@as(?u16, null), state.tip);
    try testing.expectEqual(@as(u32, 0), fake.warnings);
}
