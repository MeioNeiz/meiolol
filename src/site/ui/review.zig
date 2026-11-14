//! ReviewWalk: a game read as a walk (site.md RV1), Next alone from start to end: the
//! whole game, then the moments that moved win chance most in time order, each named
//! Good or Costly for your team by how far it moved, then one thing to try next game.
//! No grade and no per-player score: what moved, against what, is the inspector's.
//! `Walk` sets the page's Timeline (range, moment); the Try card is facts of this game
//! only, from fixed rules (`tryNext`), no model claim
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const champ = @import("champ.zig");
const badge = @import("badge.zig");
const objicon = @import("objicon.zig");
const timeline = @import("timeline.zig");
const gamedata = @import("gamedata.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "ReviewWalk";
pub const scope = .{ ".c-walk", ".c-try" };

/// Win chance points a moment must move to be a step
pub const key_move = 5;
/// Steps at most: the biggest moves
pub const key_max = 8;

const W = struct {
    pub const review = plain("Review");
    pub const start = plain("Review");
    pub const prev = plain("Previous step");
    pub const next = plain("Next step");
    pub const leave = plain("Leave the review");
    pub const of = phrase.Phrase("{i:int} / {n:int}");
    pub const game = plain("Whole game");
    pub const good = phrase.Phrase("Good {d:signed}");
    pub const costly = phrase.Phrase("Costly {d:signed}");
    pub const next_game = plain("Next game");
    pub const before_objs = plain("deaths just before their objectives");
    pub const try_objs = plain("Try: stay alive before objectives");
    pub const lane_deaths = plain("deaths before 14 min");
    pub const try_lane = plain("Try: a safer lane to 14");
    pub const best = phrase.Phrase("Your best moment, {t:time}");
    pub const go = plain("Go to it");
};

/// Win chance points `m` moved for your team: the minute before it to the minute after
pub fn moved(g: *const gamedata.Game, m: gamedata.Moment) i16 {
    const s = gamedata.summary(g, gamedata.momentSpan(m));
    return @as(i16, s.wc[1]) - s.wc[0];
}

/// Indexes into `ms` of the key_max biggest moves of key_move or more, in time order.
/// One step a move: of the moments between the same two win chance frames (a fight and
/// the kills around it), the first
pub fn keys(a: std.mem.Allocator, g: *const gamedata.Game, ms: []const gamedata.Moment) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    var last: ?[2]usize = null;
    for (ms, 0..) |m, i| {
        if (i > std.math.maxInt(u8)) break;
        const d = @abs(moved(g, m));
        if (d < key_move) continue;
        const f = gamedata.frames(g.wc.len, gamedata.momentSpan(m));
        if (last) |l| if (l[0] == f[0] and l[1] == f[1]) continue;
        last = f;
        if (out.items.len == key_max) {
            // Replace the smallest when this one is bigger; ties keep the earlier
            var lo: usize = 0;
            for (out.items, 0..) |k, j| if (@abs(moved(g, ms[k])) < @abs(moved(g, ms[out.items[lo]]))) {
                lo = j;
            };
            if (d <= @abs(moved(g, ms[out.items[lo]]))) continue;
            _ = out.orderedRemove(lo);
        }
        try out.append(a, @intCast(i));
    }
    return out.toOwnedSlice(a);
}

pub const Try = union(enum) {
    /// Your deaths in the minute before an enemy epic objective; their objectives
    objectives: struct { deaths: u8, objs: [4]u16 = undefined, n: u8 = 0 },
    /// Your deaths before 14 min
    lane: u8,
    /// No fault found: your best moment (`ms` index), how far it moved
    best: struct { moment: u8, d: i16 },
};

/// Your deaths this close before their objective count against it
pub const before_s = 60;
/// Fewest deaths for a rule to fire: one is bad luck, not a pattern
pub const min_deaths = 2;
pub const min_lane_deaths = 3;

fn epic(k: gamedata.ObjKind) bool {
    return switch (k) {
        .tower, .inhibitor => false,
        else => true,
    };
}

/// One thing to try: the first rule that fires; null with nothing to say
pub fn tryNext(g: *const gamedata.Game, ms: []const gamedata.Moment) ?Try {
    var objs: @FieldType(Try, "objectives") = .{ .deaths = 0 };
    var lane: u8 = 0;
    for (g.kills) |k| {
        if (k.victim != g.you) continue;
        if (k.t < 14 * 60) lane +|= 1;
        const taken = for (g.objs, 0..) |o, i| {
            if (!o.ours and epic(o.kind) and o.t > k.t and o.t <= k.t + before_s) break i;
        } else null;
        const i = taken orelse continue;
        objs.deaths +|= 1;
        if (objs.n < objs.objs.len and std.mem.findScalar(u16, objs.objs[0..objs.n], @intCast(i)) == null) {
            objs.objs[objs.n] = @intCast(i);
            objs.n += 1;
        }
    }
    if (objs.deaths >= min_deaths) return .{ .objectives = objs };
    if (lane >= min_lane_deaths) return .{ .lane = lane };
    var best: ?@FieldType(Try, "best") = null;
    for (ms, 0..) |m, i| {
        if (!m.you or i > std.math.maxInt(u8)) continue;
        const d = moved(g, m);
        if (d >= key_move and (best == null or d > best.?.d)) best = .{ .moment = @intCast(i), .d = d };
    }
    return if (best) |b| .{ .best = b } else null;
}

/// The walk over one game: step 0 is off; 1 the whole game; 2.. the key moments; the
/// last the Try card when there is one
pub const Walk = struct {
    tl: *timeline.Timeline,
    game: *const gamedata.Game,
    champs: []const champ.Champ,
    moments: []const gamedata.Moment,
    keys: []const u8,
    try_: ?Try,
    step: u8 = 0,

    const S = @This();

    pub const Msg = union(enum) { go: u8, by: i8, leave };

    pub fn steps(s: *const S) u8 {
        return @intCast(1 + s.keys.len + @intFromBool(s.try_ != null));
    }

    /// The key moment shown, if the step is one
    pub fn moment(s: *const S) ?u8 {
        if (s.step < 2 or s.step - 2 >= s.keys.len) return null;
        return s.keys[s.step - 2];
    }

    pub fn onTry(s: *const S) bool {
        return s.try_ != null and s.step == s.steps();
    }

    /// The step the Timeline shows: 0 when the graph moved off the walk
    pub fn follow(s: *S) void {
        if (s.step == 0 or s.step > s.steps()) {
            s.step = 0;
            return;
        }
        const want: ?u8 = s.moment();
        const whole = s.tl.range == null;
        const at = if (want) |k| whole and s.tl.cur == k else whole and s.tl.cur == null;
        if (!at) s.step = 0;
    }

    pub fn update(s: *S, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .go => |k| s.step = @min(k, s.steps()),
            .by => |d| {
                const n: i16 = s.steps();
                s.step = @intCast(std.math.clamp(@as(i16, s.step) + d, 1, n));
            },
            .leave => s.step = 0,
        }
        s.tl.range = null;
        s.tl.cur = s.moment();
        ev.push = true;
    }

    pub fn view(s: *S, h: *H) N {
        if (s.step == 0) return h.div(.{ .class = "c-walk" }, .{
            h.button(.{ .class = "go", .type = "button", .on_click = h.on(s, .{ .go = 1 }) }, .{W.start}),
        });
        const n = s.steps();
        const tag: N = if (s.moment()) |k| blk: {
            const d = moved(s.game, s.moments[k]);
            break :blk if (d > 0) badge.view(h, .us, .{W.good.with(h, .{ .d = d })}) else badge.view(h, .them, .{W.costly.with(h, .{ .d = d })});
        } else badge.view(h, .neutral, .{if (s.onTry()) W.next_game else W.game});
        return h.div(.{ .class = "c-walk", .data_on = true }, .{
            h.b(.{ .class = "lb" }, .{W.review}),
            h.button(.{ .type = "button", .aria_label = W.prev, .disabled = s.step <= 1, .on_click = h.on(s, .{ .by = -1 }) }, .{"‹"}),
            h.span(.{ .class = "n" }, .{W.of.with(h, .{ .i = s.step, .n = n })}),
            h.button(.{ .type = "button", .aria_label = W.next, .disabled = s.step >= n, .on_click = h.on(s, .{ .by = 1 }) }, .{"›"}),
            tag,
            h.button(.{ .class = "esc", .type = "button", .aria_label = W.leave, .on_click = h.on(s, .leave) }, .{"×"}),
        });
    }

    /// The Try card, on the last step
    pub fn tryView(s: *S, h: *H) N {
        const t = s.try_ orelse return .none;
        const g = s.game;
        const me = s.champs[g.me().champ];
        return switch (t) {
            .objectives => |o| blk: {
                var icons = h.list();
                for (0..o.deaths) |k| icons.add(h.span(.{ .key = k }, .{champ.view(h, me, .{ .px = .@"20", .state = .dead, .you = true, .named = false })}));
                icons.add(h.span(.{ .class = "ar", .aria_hidden = true }, .{"→"}));
                for (o.objs[0..o.n], 0..) |x, k| icons.add(h.span(.{ .key = 100 + k }, .{objicon.view(h, g.objs[x].kind, .{ .ours = false, .named = false })}));
                break :blk card(h, o.deaths, W.before_objs, icons.done(), W.try_objs);
            },
            .lane => |d| blk: {
                var icons = h.list();
                for (0..d) |k| icons.add(h.span(.{ .key = k }, .{champ.view(h, me, .{ .px = .@"20", .state = .dead, .you = true, .named = false })}));
                break :blk card(h, d, W.lane_deaths, icons.done(), W.try_lane);
            },
            .best => |b| h.div(.{ .class = "c-try", .data_k = "best" }, .{
                h.div(.{ .class = "fig" }, .{
                    h.b(.{ .class = "big" }, .{phrase.num(h, .signed, b.d)}),
                    h.span(.{ .class = "lb" }, .{W.best.with(h, .{ .t = s.moments[b.moment].t })}),
                }),
                h.button(.{ .class = "go", .type = "button", .on_click = h.on(s, .{ .go = s.stepOf(b.moment) }) }, .{W.go}),
            }),
        };
    }

    /// The step of `ms` index k: its key step, else the whole game's
    fn stepOf(s: *const S, k: u8) u8 {
        return if (std.mem.findScalar(u8, s.keys, k)) |i| @intCast(i + 2) else 1;
    }
};

fn card(h: *H, n: u8, label: tree.Text, icons: anytype, try_line: tree.Text) N {
    return h.div(.{ .class = "c-try" }, .{
        h.div(.{ .class = "fig" }, .{
            h.b(.{ .class = "big" }, .{n}),
            h.span(.{ .class = "lb" }, .{label}),
        }),
        h.div(.{ .class = "ic", .aria_hidden = true }, .{icons}),
        h.p(.{ .class = "do" }, .{try_line}),
    });
}

pub const css =
    \\@layer components {
    \\  .c-walk { display: flex; align-items: center; gap: var(--sp-2); min-height: 28px; font-size: var(--fs-s); }
    \\  .c-walk .lb { font-weight: var(--w-m); }
    \\  .c-walk .n { font-variant-numeric: tabular-nums; color: var(--muted); min-width: 3.5em; text-align: center; }
    \\  .c-walk button { all: unset; display: inline-flex; align-items: center; justify-content: center; min-width: 28px;
    \\    min-height: 28px; border-radius: var(--r-s); cursor: pointer; color: var(--text); box-shadow: inset 0 0 0 1px var(--line-2); }
    \\  .c-walk button:hover { background: var(--wash); }
    \\  .c-walk button:focus-visible { outline: 2px solid var(--focus); outline-offset: 1px; }
    \\  .c-walk button:disabled { cursor: default; color: var(--faint); background: none; }
    \\  .c-walk .go { padding: 0 var(--sp-3); color: var(--accent); box-shadow: inset 0 0 0 1px var(--accent); }
    \\  .c-walk .go::after { content: "\203A"; margin-left: 6px; }
    \\  .c-walk .esc { margin-left: auto; padding: 0 6px; font-size: var(--fs-xs); color: var(--muted); }
    \\  .c-try { display: grid; gap: var(--sp-2); }
    \\  .c-try .fig { display: flex; align-items: baseline; gap: var(--sp-2); }
    \\  .c-try .big { font-size: var(--fs-xl); font-variant-numeric: tabular-nums; }
    \\  .c-try .lb { color: var(--muted); font-size: var(--fs-s); }
    \\  .c-try[data-k="best"] .big { color: var(--us-hot); }
    \\  .c-try .ic { display: flex; flex-wrap: wrap; align-items: center; gap: 4px; }
    \\  .c-try .ar { color: var(--faint); margin: 0 4px; }
    \\  .c-try .do { margin: 0; font-weight: var(--w-m); }
    \\  .c-try .go { all: unset; justify-self: start; padding: 2px var(--sp-3); border-radius: var(--r-s); cursor: pointer;
    \\    color: var(--accent); box-shadow: inset 0 0 0 1px var(--accent); font-size: var(--fs-s); }
    \\  .c-try .go:focus-visible { outline: 2px solid var(--focus); outline-offset: 1px; }
    \\}
    \\
;

const demo = @import("game_demo.zig").data;

fn demoWalk(h: *H, step: u8) ?*Walk {
    const g = &demo.games[0];
    const ms = gamedata.moments(h.mem, g) catch return null;
    const tg = h.mem.create(timeline.Game) catch return null;
    tg.* = gamedata.chart(h.mem, g, demo.champs, ms) catch return null;
    const tl = h.mem.create(timeline.Timeline) catch return null;
    tl.* = .{ .game = tg };
    const w = h.mem.create(Walk) catch return null;
    w.* = .{ .tl = tl, .game = g, .champs = demo.champs, .moments = ms, .keys = keys(h.mem, g, ms) catch return null, .try_ = tryNext(g, ms) };
    w.step = @min(step, w.steps());
    tl.cur = w.moment();
    return w;
}

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const states = [_]struct { []const u8, u8 }{ .{ "off: the start button", 0 }, .{ "the whole game", 1 }, .{ "a key moment", 2 }, .{ "the last step", 255 } };
    for (states) |st| {
        const w = demoWalk(h, st[1]) orelse {
            h.oom = true;
            return;
        };
        g.addFill(st[0], h.div(.{}, .{ w.view(h), if (w.onTry()) w.tryView(h) else null }));
    }
    // Each Try rule on a planted game
    const tries = [_]struct { []const u8, Try }{
        .{ "try: deaths before their objectives", .{ .objectives = .{ .deaths = 3, .objs = .{ 0, 0, 0, 0 }, .n = 1 } } },
        .{ "try: deaths in lane", .{ .lane = 4 } },
    };
    for (tries) |t| {
        const w = demoWalk(h, 1) orelse {
            h.oom = true;
            return;
        };
        w.try_ = t[1];
        w.step = w.steps();
        g.addFill(t[0], w.tryView(h));
    }
}

const testing = std.testing;

fn testGame(kills: []const gamedata.Kill, objs: []const gamedata.Obj, wc: []const u8) gamedata.Game {
    const seats = comptime blk: {
        var s: [10]gamedata.Seat = undefined;
        for (&s, 0..) |*x, i| x.* = .{ .champ = 0, .us = i < 5, .k = 0, .d = 0, .a = 0 };
        break :blk s;
    };
    return .{ .day = "", .patch = "", .queue = "", .dur = @intCast(wc.len * 60), .win = true, .you = 0, .seats = &seats, .wc = wc, .kills = kills, .objs = objs };
}

test "keys: moves of key_move or more, the key_max biggest, in time order" {
    var wc: [30]u8 = undefined;
    @memset(&wc, 40);
    // Minute frames 10->11 +6, 14->15 -9, 20->21 +4 (under key_move)
    for (11..30) |i| wc[i] += 6;
    for (15..30) |i| wc[i] -= 9;
    for (21..30) |i| wc[i] += 4;
    const kills = [_]gamedata.Kill{
        .{ .t = 10 * 60 + 30, .killer = 0, .victim = 5, .fight = 0 },
        .{ .t = 14 * 60 + 30, .killer = 5, .victim = 0, .fight = 1 },
        .{ .t = 20 * 60 + 30, .killer = 1, .victim = 6, .fight = 2 },
    };
    const g = testGame(&kills, &.{}, &wc);
    const ms = try gamedata.moments(testing.allocator, &g);
    defer testing.allocator.free(ms);
    const ks = try keys(testing.allocator, &g, ms);
    defer testing.allocator.free(ks);
    try testing.expectEqualSlices(u8, &.{ 0, 1 }, ks);
    try testing.expect(moved(&g, ms[0]) > 0 and moved(&g, ms[1]) < 0);

    // More than key_max big moves: the smallest go, the rest stay in time order
    var many: [2 * key_max + 4]u8 = undefined;
    var mk: [key_max + 2]gamedata.Kill = undefined;
    many[0] = 50;
    for (1..many.len) |i| many[i] = if (i % 2 == 1) @intCast(50 + 5 + i) else 50;
    for (&mk, 0..) |*k, i| k.* = .{ .t = @intCast((2 * i + 1) * 60 - 30), .killer = 0, .victim = 5, .fight = @intCast(i) };
    const g2 = testGame(&mk, &.{}, &many);
    const ms2 = try gamedata.moments(testing.allocator, &g2);
    defer testing.allocator.free(ms2);
    const ks2 = try keys(testing.allocator, &g2, ms2);
    defer testing.allocator.free(ks2);
    try testing.expectEqual(key_max, ks2.len);
    try testing.expectEqual(@as(u8, 2), ks2[0]);
    for (1..ks2.len) |i| try testing.expect(ks2[i] > ks2[i - 1]);
}

test "tryNext: deaths before their objectives first, then lane deaths, else your best moment" {
    const wc = @as([30]u8, @splat(50));
    const dragon = [_]gamedata.Obj{
        .{ .t = 8 * 60, .ours = false, .kind = .dragon, .name = "" },
        .{ .t = 20 * 60, .ours = false, .kind = .baron, .name = "" },
        .{ .t = 25 * 60, .ours = true, .kind = .dragon, .name = "" },
    };
    const before = [_]gamedata.Kill{
        .{ .t = 8 * 60 - 20, .killer = 5, .victim = 0, .fight = 0 },
        .{ .t = 20 * 60 - 50, .killer = 5, .victim = 0, .fight = 1 },
        // Before their own dragon: not counted; nor a death after theirs
        .{ .t = 25 * 60 - 10, .killer = 5, .victim = 0, .fight = 2 },
        .{ .t = 8 * 60 + 5, .killer = 5, .victim = 0, .fight = 3 },
    };
    const g = testGame(&before, &dragon, &wc);
    const t = tryNext(&g, &.{}).?.objectives;
    try testing.expectEqual(2, t.deaths);
    try testing.expectEqualSlices(u16, &.{ 0, 1 }, t.objs[0..t.n]);

    const lane = [_]gamedata.Kill{
        .{ .t = 3 * 60, .killer = 5, .victim = 0, .fight = 0 },
        .{ .t = 6 * 60, .killer = 5, .victim = 0, .fight = 1 },
        .{ .t = 13 * 60, .killer = 5, .victim = 0, .fight = 2 },
    };
    try testing.expectEqual(Try{ .lane = 3 }, tryNext(&testGame(&lane, &.{}, &wc), &.{}).?);

    var up = wc;
    for (11..30) |i| up[i] = 62;
    const won = [_]gamedata.Kill{.{ .t = 10 * 60 + 30, .killer = 0, .victim = 5, .fight = 0 }};
    const gb = testGame(&won, &.{}, &up);
    const ms = try gamedata.moments(testing.allocator, &gb);
    defer testing.allocator.free(ms);
    try testing.expectEqual(Try{ .best = .{ .moment = 0, .d = 12 } }, tryNext(&gb, ms).?);
    try testing.expectEqual(@as(?Try, null), tryNext(&testGame(&.{}, &.{}, &wc), &.{}));
}

test "Next alone walks the whole game, the key moments, then Try; the graph moving off ends it" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    const w = demoWalk(&h, 0).?;
    try testing.expect(w.keys.len > 0);
    var ev: tree.Event = .{ .kind = .click };
    w.update(.{ .go = 1 }, &ev);
    try testing.expect(ev.push and w.tl.range == null and w.tl.cur == null);
    for (w.keys) |k| {
        w.update(.{ .by = 1 }, &ev);
        try testing.expectEqual(@as(?u8, k), w.tl.cur);
        w.follow();
        try testing.expect(w.step > 0);
    }
    w.update(.{ .by = 1 }, &ev);
    try testing.expectEqual(w.try_ != null, w.onTry());
    w.update(.{ .by = 1 }, &ev);
    try testing.expectEqual(w.steps(), w.step);
    // The graph picks another range: off the walk
    w.update(.{ .go = 2 }, &ev);
    w.tl.range = .{ 0, 60 };
    w.follow();
    try testing.expectEqual(@as(u8, 0), w.step);
}

test "keys: moments between the same two frames are one step, the first" {
    var wc: [20]u8 = @splat(40);
    for (11..20) |i| wc[i] = 52;
    const kills = [_]gamedata.Kill{
        .{ .t = 10 * 60 + 5, .killer = 0, .victim = 5, .fight = 0 },
        .{ .t = 10 * 60 + 50, .killer = 1, .victim = 6, .fight = 1 },
    };
    const g = testGame(&kills, &.{}, &wc);
    const ms = try gamedata.moments(testing.allocator, &g);
    defer testing.allocator.free(ms);
    try testing.expectEqual(2, ms.len);
    const ks = try keys(testing.allocator, &g, ms);
    defer testing.allocator.free(ks);
    try testing.expectEqualSlices(u8, &.{0}, ks);
}
