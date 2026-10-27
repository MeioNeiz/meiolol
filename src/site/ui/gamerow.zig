//! GameRow: one of your games in the Your games list (your-games.md "Games"), tinted by
//! result. Your champion with its level, "vs" your lane opponent; K/D/A and the meta line
//! (matchup, role, queue, length, how long ago); final items; CS; lane gold at 14 against
//! the typical middle half; the win chance with the turn starred. Slots a game lacks
//! (older history has no timeline) stay empty at the same width. The whole row links to
//! the game when it has a page. Two lines in a narrow list
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const art = @import("art.zig");
const kda = @import("kda.zig");
const badge = @import("badge.zig");
const spark = @import("spark.zig");
const versus = @import("versus.zig");
const yl = @import("yourlist.zig");
const gd = @import("gamedata.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "GameRow";
pub const scope = .{".c-grow"};

pub const Opts = struct {
    /// Among the list's rows: the game's, so a filter change keeps focus on it
    key: u32 = 0,
    /// The game's page; none: a plain row
    href: ?[]const u8 = null,
    /// For "12h" ago; none: left out
    now_ms: ?i64 = null,
    /// Arrived since the last visit
    new: bool = false,
};

const W = struct {
    pub const vs = plain("vs");
    pub const matchup = phrase.Phrase("{a:text} vs {b:text}");
    pub const per_min = phrase.Phrase("{v:dec}/m");
    pub const cs = phrase.Phrase("{n:count} cs");
    pub const lane = plain("Gold lead at 14 against the typical middle half");
    pub const lane_at = phrase.Phrase("{v:signed} at 14");
    pub const items = plain("Final items");
    pub const new = plain("New");
    pub const remake = plain("Remake");
    pub const mins = phrase.Phrase("{n:int}m");
    pub const hours = phrase.Phrase("{n:int}h");
    pub const days = phrase.Phrase("{n:int}d");
    pub const solo = plain("Solo");
    pub const flex = plain("Flex");
    pub const draft = plain("Draft");
    pub const swift = plain("Swift");
    pub const other = plain("Normal");
};

pub fn queueName(q: yl.Queue) tree.Text {
    return switch (q) {
        inline else => |t| @field(W, @tagName(t)),
    };
}

/// Lane gold at 14 runs -dom to +dom on every row, so rows compare
const lane_dom = 3000;

pub fn view(h: *H, l: *const yl.List, g: yl.Game, o: Opts) N {
    const me = l.champs[g.champ];
    const opp: ?champ.Champ = if (g.opp) |i| l.champs[i] else null;
    const attrs = .{ .key = o.key, .class = "c-grow", .href = o.href, .data_win = g.win and !g.remake, .data_remake = g.remake };
    const kids = .{
        h.span(.{ .class = "mu" }, .{
            champ.view(h, me, .{ .px = .@"40", .level = g.level }),
            if (opp != null) h.span(.{ .class = "vs" }, .{W.vs}) else null,
            if (opp) |c| champ.view(h, c, .{}) else null,
        }),
        h.span(.{ .class = "res" }, .{
            h.span(.{ .class = "top" }, .{
                kda.view(h, .{ .k = g.k, .d = g.d, .a = g.a }, .{}),
                if (g.remake) badge.view(h, .neutral, .{W.remake}) else null,
                if (o.new) badge.view(h, .accent, .{W.new}) else null,
            }),
            h.span(.{ .class = "meta" }, .{
                h.span(.{ .class = "nm" }, .{if (opp) |c| W.matchup.with(h, .{ .a = me.name, .b = c.name }) else tree.Text{ .s = me.name }}),
                if (g.role) |r| role.view(h, r, .{ .s = .s }) else null,
                h.span(.{}, .{queueName(g.queue)}),
                h.span(.{}, .{phrase.num(h, .time, g.dur)}),
                if (o.now_ms) |now| h.span(.{}, .{ago(h, now - g.ends())}) else null,
            }),
        }),
        items(h, l, g),
        h.span(.{ .class = "figs" }, .{
            if (g.cs) |cs| h.span(.{ .class = "cs" }, .{
                W.cs.with(h, .{ .n = cs }),
                h.small(.{}, .{W.per_min.with(h, .{ .v = @as(f32, @floatFromInt(cs)) * 60 / @as(f32, @floatFromInt(@max(g.dur, 60))) })}),
            }) else null,
            if (g.lane14) |x| versus.cell(h, .{
                .label = W.lane,
                .you = x.you,
                .typ = if (x.typ) |t| .{ t[0], t[1], t[2] } else null,
                .dom = lane_dom,
            }, W.lane_at.with(h, .{ .v = x.you })) else null,
        }),
        winChance(h, g.wc),
    };
    return if (o.href != null) h.a(attrs, kids) else h.div(attrs, kids);
}

fn ago(h: *H, ms: i64) tree.Text {
    const m = @divFloor(@max(ms, 0), std.time.ms_per_min);
    if (m < 60) return W.mins.with(h, .{ .n = m });
    if (m < 48 * 60) return W.hours.with(h, .{ .n = @divFloor(m, 60) });
    return W.days.with(h, .{ .n = @divFloor(m, 24 * 60) });
}

/// Six items and the trinket; none before summaries had them
fn items(h: *H, l: *const yl.List, g: yl.Game) ?N {
    for (g.items) |i| {
        if (l.artAt(i) != null) break;
    } else return null;
    var its = h.list();
    for (g.items) |i| its.add(art.view(h, l.artAt(i) orelse .{ .name = "", .src = "" }, .{}));
    return h.span(.{ .class = "its", .role = "group", .aria_label = W.items }, .{its.done()});
}

fn winChance(h: *H, wc: []const u8) ?N {
    if (wc.len < 2) return null;
    const vs = h.mem.alloc(f32, wc.len) catch {
        h.oom = true;
        return null;
    };
    for (wc, vs) |x, *v| v.* = @floatFromInt(x);
    const turn, _ = gd.turns(wc);
    return spark.view(h, .{ .vs = vs, .y = .{ .lo = 0, .hi = 100 }, .mid = 50, .star = if (turn) |t| t.minute else null, .w = 120, .h = 32 });
}

pub const css =
    \\@layer components {
    \\  .c-grow { display: grid; grid-template-columns: auto minmax(0, 1fr) 166px 160px 120px; grid-template-areas: "mu res its figs wc";
    \\    align-items: center; gap: var(--sp-1) var(--sp-3); min-height: 60px; padding: 6px var(--sp-3);
    \\    border-bottom: 1px solid var(--line); color: inherit; text-decoration: none;
    \\    background: linear-gradient(90deg, var(--them-bg), transparent 40%); box-shadow: inset 3px 0 0 var(--them); }
    \\  .c-grow[data-win] { background: linear-gradient(90deg, var(--us-bg), transparent 40%); box-shadow: inset 3px 0 0 var(--us); }
    \\  .c-grow[data-remake] { background: none; box-shadow: inset 3px 0 0 var(--line-2); }
    \\  .c-grow[href]:hover { background-color: var(--panel-2); text-decoration: none; }
    \\  .c-grow > .mu { grid-area: mu; display: flex; align-items: center; gap: 6px; }
    \\  .c-grow .vs { color: var(--faint); font-size: var(--fs-xs); }
    \\  .c-grow > .res { grid-area: res; display: flex; flex-direction: column; gap: 2px; min-width: 0; font-size: var(--fs-l); }
    \\  .c-grow .top { display: flex; align-items: center; gap: var(--sp-2); }
    \\  .c-grow .meta { display: flex; align-items: center; flex-wrap: wrap; gap: 2px var(--sp-2); font-size: var(--fs-s);
    \\    color: var(--muted); white-space: nowrap; }
    \\  .c-grow .nm { overflow: hidden; text-overflow: ellipsis; }
    \\  .c-grow > .its { grid-area: its; display: flex; gap: 2px; }
    \\  .c-grow .its > :last-child { margin-left: 4px; }
    \\  .c-grow > .figs { grid-area: figs; display: flex; align-items: center; justify-content: flex-end; gap: var(--sp-3);
    \\    font-size: var(--fs-s); color: var(--t2); font-variant-numeric: tabular-nums; }
    \\  .c-grow .cs { white-space: nowrap; text-align: right; }
    \\  .c-grow .cs > small { display: block; font-size: var(--fs-xs); color: var(--faint); }
    \\  .c-grow > .c-spark { grid-area: wc; }
    \\  @container (max-width: 760px) {
    \\    .c-grow { grid-template-columns: auto minmax(0, 1fr) auto; grid-template-areas: "mu res figs" "mu its wc"; }
    \\    .c-grow > .c-spark { justify-self: end; }
    \\  }
    \\  @container (max-width: 440px) {
    \\    .c-grow { grid-template-columns: auto minmax(0, 1fr) auto auto; grid-template-areas: "mu res res figs" "its its wc wc";
    \\      padding: 6px var(--sp-2); }
    \\    .c-grow .meta { flex-wrap: nowrap; overflow: hidden; }
    \\    .c-grow .nm, .c-grow .meta > .c-role, .c-grow .figs > .c-vs { display: none; }
    \\  }
    \\  @container (max-width: 360px) { .c-grow .its > :last-child, .c-grow > .figs { display: none; } }
    \\}
    \\
;

const demo = struct {
    const champs = [_]champ.Champ{ champ.demo("AurelionSol", "Aurelion Sol"), champ.demo("Aurora", "Aurora"), champ.demo("Pyke", "Pyke"), champ.demo("Sona", "Sona") };
    const arts = [_]art.Art{
        art.item("6655", "Luden's Companion"),
        art.item("3020", "Sorcerer's Shoes"),
        art.item("3089", "Rabadon's Deathcap"),
        art.item("3135", "Void Staff"),
        art.item("3340", "Stealth Ward"),
        art.item("3142", "Youmuu's Ghostblade"),
        art.item("3364", "Oracle Lens"),
    };
    const wc = [_]u8{ 50, 51, 49, 47, 52, 55, 53, 48, 44, 41, 46, 52, 58, 61, 57, 66, 72, 70, 78, 84, 88 };
    const start: i64 = 20748 * std.time.ms_per_day;
    const win: yl.Game = .{
        .start_ms = start,
        .dur = 2498,
        .patch = "16.21",
        .queue = .draft,
        .role = .mid,
        .champ = 0,
        .opp = 1,
        .win = true,
        .k = 14,
        .d = 8,
        .a = 14,
        .level = 18,
        .cs = 313,
        .items = .{ 0, 1, 2, 3, gd.no_art, gd.no_art, 4 },
        .wc = &wc,
        .lane14 = .{ .you = -768, .typ = .{ -1677, -63, 511 } },
        .page = 0,
    };
    const list: yl.List = .{ .player = .{ .name = "Example player" }, .champs = &champs, .arts = &arts, .games = &.{win} };
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const l = &demo.list;
    const now = demo.start + 12 * std.time.ms_per_hour;
    var loss = demo.win;
    loss.win = false;
    loss.champ = 2;
    loss.opp = 3;
    loss.role = .support;
    loss.dur = 1057;
    loss.k = 4;
    loss.d = 1;
    loss.a = 6;
    loss.level = 11;
    loss.cs = 23;
    loss.items = .{ 5, gd.no_art, gd.no_art, gd.no_art, gd.no_art, gd.no_art, 6 };
    loss.lane14 = .{ .you = 1084, .typ = .{ -200, 300, 900 } };
    var remake = loss;
    remake.remake = true;
    remake.dur = 190;
    remake.k = 0;
    remake.d = 0;
    remake.a = 0;
    remake.wc = &.{};
    remake.lane14 = null;
    var old = demo.win;
    old.queue = .solo;
    old.level = null;
    old.cs = null;
    old.items = @splat(gd.no_art);
    old.wc = &.{};
    old.lane14 = .{ .you = -3408 };
    old.page = null;
    g.addFill("a win, new", view(h, l, demo.win, .{ .href = "game.html#g=0", .now_ms = now, .new = true }));
    g.addFill("a loss", view(h, l, loss, .{ .href = "game.html#g=1", .now_ms = now }));
    g.addFill("a remake", view(h, l, remake, .{ .now_ms = now }));
    g.addFill("no timeline: no items, CS or win chance; lane without a typical", view(h, l, old, .{ .now_ms = now + 9 * std.time.ms_per_day }));
}

const testing = std.testing;

test "a row links to its game, carries its result and leaves out what the game lacks" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    const n = view(&h, &demo.list, demo.win, .{ .href = "game.html#g=0", .now_ms = demo.win.ends() + 3 * std.time.ms_per_hour });
    try testing.expectEqualStrings("game.html#g=0", t.attr(n, "href").?);
    try testing.expect(t.attr(n, "data-win") != null);
    try testing.expect(t.find(n, "class", "c-spark") != null);
    try testing.expect(t.find(n, "class", "its") != null);
    var bare = demo.win;
    bare.items = @splat(gd.no_art);
    bare.wc = &.{};
    bare.cs = null;
    bare.lane14 = null;
    bare.win = false;
    const b = view(&h, &demo.list, bare, .{});
    try testing.expectEqual(null, t.attr(b, "href"));
    try testing.expectEqual(null, t.attr(b, "data-win"));
    try testing.expectEqual(null, t.find(b, "class", "c-spark"));
    try testing.expectEqual(null, t.find(b, "class", "its"));
    try testing.expectEqual(null, t.find(b, "class", "cs"));
    try testing.expectEqualStrings("3h", ago(&h, 3 * std.time.ms_per_hour + 59 * std.time.ms_per_min).s);
    try testing.expectEqualStrings("2d", ago(&h, 50 * std.time.ms_per_hour).s);
}
