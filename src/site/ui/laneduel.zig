//! LaneDuel: your lane against your opponent's (game-detail.md "Lane"). LaneChart of you
//! minus them by minute over the matchup's typical band; your biggest fall and rise
//! against typical as brackets under the time axis, pressed to select those minutes on
//! the game graph. Beside it the races to level 6 and the first item, gold lead at 14
//! and CS lead at 10 on typical bands, your CS at 10 and kills and deaths before 14.
//! Under 200 typical games the band and its chip are dashed: that is the whole "few
//! games" message
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const lane = @import("lane.zig");
const chart = @import("chart.zig");
const champ = @import("champ.zig");
const versus = @import("versus.zig");
const toggletip = @import("toggletip.zig");
const gamedata = @import("gamedata.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "LaneDuel";
pub const scope = .{ ".c-duel", ".c-duelwho", ".c-dueltyp" };

/// Under this many typical games the band is dashed
pub const thin_games = 200;

const W = struct {
    pub const gold = plain("Gold");
    pub const xp = plain("XP");
    pub const cs = plain("CS");
    pub const vs = plain("vs");
    pub const typical = phrase.Phrase("Typical: {n:count}");
    pub const typ_title = plain("Typical");
    pub const typ_note = phrase.Phrase("{a:text} vs {b:text}, {r:text}: middle half and median of {n:count} games; dashed under 200");
    pub const level6 = plain("Level 6");
    pub const first_item = plain("First item");
    pub const gold14 = plain("Gold lead at 14");
    pub const cs10 = plain("CS lead at 10");
    pub const stretch = phrase.Phrase("{a:int}–{b:int} {v:signed}");
    pub const cs_at10 = plain("CS at 10");
    pub const kills = plain("kills <14");
    pub const deaths = plain("deaths <14");
};

pub const Duel = struct {
    l: lane.Lane = .{ .a = "", .b = "", .metrics = &.{} },
    m: [3]lane.Metric = undefined,
    of: ?*const gamedata.Game = null,

    const D = @This();

    /// The chart on `g`'s lane, its series allocated once per game shown
    fn set(d: *D, a: std.mem.Allocator, g: *const gamedata.Game, champs: []const champ.Champ) !void {
        if (d.of == g) return;
        const l = g.lane.?;
        const t = l.typical;
        const ms = [_]struct { tree.Text, []const i16, ?[]const [3]i16 }{
            .{ W.gold, l.gold, if (t) |x| x.gold else null },
            .{ W.xp, l.xp, if (t) |x| x.xp else null },
            .{ W.cs, l.cs, if (t) |x| x.cs else null },
        };
        for (ms, &d.m) |x, *m| {
            // Minute 0 first: even
            const you = try a.alloc(f32, x[1].len + 1);
            you[0] = 0;
            for (x[1], you[1..]) |v, *o| o.* = @floatFromInt(v);
            const q = x[2] orelse &.{};
            const band = try a.alloc([2]f32, if (q.len > 0) q.len + 1 else 0);
            const line = try a.alloc(f32, band.len);
            if (q.len > 0) {
                band[0] = .{ 0, 0 };
                line[0] = 0;
                for (q, band[1..], line[1..]) |v, *b, *ln| {
                    b.* = .{ @floatFromInt(v[0]), @floatFromInt(v[2]) };
                    ln.* = @floatFromInt(v[1]);
                }
            }
            m.* = .{ .label = x[0], .s = .{ .you = you, .band = band, .line = line } };
        }
        const opp = g.opponent().?;
        d.l = .{ .a = champs[g.me().champ].name, .b = champs[g.seats[opp].champ].name, .metrics = &d.m, .k = d.l.k };
        d.of = g;
    }

    /// The card head's controls: your portrait vs theirs, the switch, the typical chip
    pub fn head(d: *D, h: *H, g: *const gamedata.Game, champs: []const champ.Champ) []const N {
        if (!has(g)) return &.{};
        const l = g.lane.?;
        var out = h.list();
        out.add(h.span(.{ .class = "c-duelwho" }, .{
            champ.view(h, champs[g.me().champ], .{ .px = .@"24", .you = true, .named = false }),
            W.vs,
            champ.view(h, champs[g.seats[g.opponent().?].champ], .{ .px = .@"24", .named = false }),
        }));
        out.add(d.l.switcher(h));
        if (l.typical) |t| {
            const tt = toggletip.view(h, "duel-typ", .{W.typical.with(h, .{ .n = t.games })}, W.typ_title, W.typ_note.with(h, .{
                .a = d.l.a,
                .b = d.l.b,
                .r = t.bracket,
                .n = t.games,
            }));
            out.add(h.span(.{ .class = "c-dueltyp", .data_state = if (t.games < thin_games) "thin" else null }, .{ tt[0], tt[1] }));
        }
        return out.done();
    }

    /// `sel`: a stretch's handler, selecting its minutes on the game graph
    pub fn view(d: *D, h: *H, a: std.mem.Allocator, g: *const gamedata.Game, champs: []const champ.Champ, sel: anytype) N {
        if (!has(g)) return .none;
        d.set(a, g, champs) catch {
            h.oom = true;
            return .none;
        };
        const l = g.lane.?;
        const t = l.typical;
        const me = champs[g.me().champ];
        const them = champs[g.seats[g.opponent().?].champ];

        var brk = h.list();
        // Overlapping stretches take a row each
        const two = if (l.fall) |f| if (l.rise) |r| f.from < r.to and r.from < f.to else false else false;
        for ([_]struct { ?gamedata.Lane.Stretch, []const u8, u8 }{ .{ l.fall, "them", 0 }, .{ l.rise, "us", @intFromBool(two) } }) |x| if (x[0]) |s| {
            if (s.to <= s.from or s.to >= d.m[d.l.k].s.you.len) continue;
            const pa = d.l.px(s.from);
            brk.add(h.button(.{
                .type = "button",
                .data_side = x[1],
                .style = h.vars(.{ .a = pa, .w = d.l.px(s.to) - pa, .r = x[2] }),
                .on_click = sel.on(h, s.from, s.to),
            }, .{W.stretch.with(h, .{ .a = s.from, .b = s.to, .v = s.change })}));
        };

        var side = h.list();
        side.add(versus.race(h, .{ .label = W.level6, .you = l.level6[0], .them = l.level6[1], .typ = if (t) |x| x.level6 else null, .a = me, .b = them }));
        side.add(versus.race(h, .{ .label = W.first_item, .you = l.first_item[0], .them = l.first_item[1], .typ = if (t) |x| x.first_item else null, .a = me, .b = them }));
        if (l.gold.len >= 14) side.add(versus.band(h, .{
            .label = W.gold14,
            .you = l.gold[13],
            .typ = if (t) |x| if (x.gold.len >= 14) widen(x.gold[13]) else null else null,
            .dom = 2500,
        }));
        if (l.cs.len >= 10) side.add(versus.band(h, .{
            .label = W.cs10,
            .you = l.cs[9],
            .typ = if (t) |x| if (x.cs.len >= 10) widen(x.cs[9]) else null else null,
            .dom = 30,
        }));
        return h.div(.{ .class = "c-duel", .data_state = if (t == null or t.?.games < thin_games) "thin" else null }, .{
            d.l.viewWith(h, if (brk.items.items.len > 0) h.div(.{ .class = "brk", .data_two = two }, .{brk.done()}) else .none),
            h.div(.{ .class = "side" }, .{
                h.div(.{ .class = "c-vs" }, .{side.done()}),
                h.div(.{ .class = "counts" }, .{
                    if (l.cs10) |c| h.span(.{}, .{ h.b(.{}, .{c}), W.cs_at10 }) else null,
                    h.span(.{}, .{ h.b(.{}, .{l.kills}), W.kills }),
                    h.span(.{}, .{ h.b(.{}, .{l.deaths}), W.deaths }),
                }),
            }),
        });
    }
};

/// A lane with an opponent
pub fn has(g: *const gamedata.Game) bool {
    const l = g.lane orelse return false;
    return g.opponent() != null and l.gold.len >= 2;
}

fn widen(q: [3]i16) [3]i32 {
    return .{ q[0], q[1], q[2] };
}

pub const css =
    \\@layer components {
    \\  .c-duel { display: grid; grid-template-columns: minmax(0, 7fr) minmax(0, 5fr); gap: var(--sp-5); align-items: start; container-type: inline-size; }
    \\  .c-duel > .side { display: flex; flex-direction: column; gap: var(--sp-4); min-width: 0; }
    \\  .c-duel .c-vs { grid-template-columns: minmax(0, 1fr); gap: var(--sp-4); }
    \\  .c-duel .brk { position: relative; height: 32px; }
    \\  .c-duel .brk[data-two] { height: 54px; }
    \\  .c-duel .brk > button { all: unset; position: absolute; top: calc(var(--r) * 28px + 6px); left: calc(var(--a) * 1%); width: calc(var(--w) * 1%); min-width: 24px;
    \\    padding-top: 8px; border-top: 2px solid var(--c); text-align: center; cursor: pointer; white-space: nowrap;
    \\    font-size: var(--fs-xs); font-weight: var(--w-m); color: var(--c); font-variant-numeric: tabular-nums; --c: var(--t2); }
    \\  .c-duel .brk > button::before, .c-duel .brk > button::after { content: ""; position: absolute; top: -6px; height: 6px; width: 2px; background: var(--c); }
    \\  .c-duel .brk > button::before { left: 0; }
    \\  .c-duel .brk > button::after { right: 0; }
    \\  .c-duel .brk > button[data-side="us"] { --c: var(--us-hot); }
    \\  .c-duel .brk > button[data-side="them"] { --c: var(--them-hot); }
    \\  .c-duel .brk > button:hover { background: var(--wash); }
    \\  .c-duel .brk > button:focus-visible { outline: 2px solid var(--focus); }
    \\  .c-duel[data-state="thin"] .band { stroke: var(--t2); stroke-dasharray: 3 3; stroke-width: 1; }
    \\  .c-duel .counts { display: flex; flex-wrap: wrap; gap: var(--sp-1) var(--sp-4); font-size: var(--fs-s); color: var(--t2); }
    \\  .c-duel .counts b { color: var(--text); margin-right: 4px; font-variant-numeric: tabular-nums; }
    \\  .c-duelwho { display: inline-flex; align-items: center; gap: 4px; font-size: var(--fs-xs); color: var(--faint); }
    \\  .c-dueltyp { margin-left: auto; }
    \\  .c-dueltyp[data-state="thin"] > .c-tt { outline: 1px dashed var(--line-2); outline-offset: 2px; }
    \\  @container (max-width: 720px) {
    \\    .c-duel { grid-template-columns: minmax(0, 1fr); }
    \\  }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const d = &@import("game_demo.zig").data;
    const Sel = struct {
        fn on(_: @This(), _: *H, _: u8, _: u8) ?tree.Handler {
            return null;
        }
    };
    for (d.games, 0..) |*x, i| {
        if (!has(x)) continue;
        const duel = h.mem.create(Duel) catch {
            h.oom = true;
            return;
        };
        duel.* = .{};
        const v = duel.view(h, h.mem, x, d.champs, Sel{});
        g.addFill(if (i == 0) "first game" else "second game", h.div(.{}, .{ h.div(.{ .class = "c-head" }, .{duel.head(h, x, d.champs)}), v }));
    }
}
