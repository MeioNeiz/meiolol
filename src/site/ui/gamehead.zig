//! GameHeader: one game at a glance, no sentence (game-detail.md "First screen"). Who:
//! your champion with its level, "vs" your lane opponent. Result and score: WIN or LOSS,
//! K/D/A large, KDA and kill share under it. How: CS, gold, damage and lane gold at 14
//! and vision as figures, then your final items, spells and runes; the game's meta beside
//! the names; the two teams as icon rows, you ringed
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const fmt = @import("fmt.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const badge = @import("badge.zig");
const kda = @import("kda.zig");
const art = @import("art.zig");
const strip = @import("strip.zig");
const gamedata = @import("gamedata.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "GameHeader";
pub const scope = .{".c-ghead"};

const W = struct {
    pub const label = plain("This game");
    pub const vs = plain("vs");
    pub const win = plain("WIN");
    pub const loss = plain("LOSS");
    pub const ratio = phrase.Phrase("{r:dec} KDA · {kp:pct} KP");
    pub const perfect = phrase.Phrase("Perfect KDA · {kp:pct} KP");
    pub const cs = plain("CS");
    pub const per_min = phrase.Phrase("{v:dec}/m");
    pub const gold = plain("Gold");
    pub const damage = plain("Damage");
    pub const lane = plain("Lane at 14");
    pub const vision = plain("Vision");
    pub const kit = plain("Your build");
    pub const matchup = phrase.Phrase("{a:text} vs {b:text}");
    pub const teams = plain("Both teams");
    pub const ours = plain("Your team");
    pub const theirs = plain("Their team");
};

pub fn view(h: *H, g: *const gamedata.Game, champs: []const champ.Champ, arts: []const art.Art) N {
    const me = g.me();
    const opp: ?gamedata.Seat = if (g.opponent()) |o| g.seats[o] else null;
    var team_kills: u32 = 0;
    for (g.seats) |s| if (s.us) {
        team_kills += s.k;
    };
    const kp: u32 = if (team_kills == 0) 0 else (@as(u32, me.k) + me.a) * 100 / team_kills;
    const ratio: f32 = @as(f32, @floatFromInt(@as(u32, me.k) + me.a)) / @as(f32, @floatFromInt(@max(me.d, 1)));
    const mins: f32 = @as(f32, @floatFromInt(@max(g.dur, 60))) / 60;
    const cs_m: f32 = @as(f32, @floatFromInt(me.cs)) / mins;

    var cells: [5]strip.Item = undefined;
    var n: usize = 0;
    cells[n] = .{ .label = W.cs, .value = phrase.num(h, .count, me.cs), .ctx = W.per_min.with(h, .{ .v = cs_m }) };
    n += 1;
    cells[n] = .{ .label = W.gold, .value = phrase.num(h, .kilo, me.gold) };
    n += 1;
    cells[n] = .{ .label = W.damage, .value = phrase.num(h, .kilo, me.damage) };
    n += 1;
    if (me.lane14) |l| {
        cells[n] = .{ .label = W.lane, .value = phrase.num(h, .signed, l), .step = .of(@as(f32, @floatFromInt(l)) / 100, fmt.game_cuts) };
        n += 1;
    }
    if (me.vision) |v| {
        cells[n] = .{ .label = W.vision, .value = phrase.num(h, .count, v) };
        n += 1;
    }

    var rows: [2]tree.List = .{ h.list(), h.list() };
    for (g.seats, 0..) |s, i| rows[@intFromBool(!s.us)].add(champ.view(h, champs[s.champ], .{ .you = i == g.you }));
    const opp_name = if (opp) |o| champs[o.champ].name else "";

    return h.el(.section, .{ .class = "c-ghead", .data_win = g.win, .aria_label = W.label }, .{
        h.div(.{ .class = "who" }, .{
            champ.view(h, champs[me.champ], .{ .px = .@"56", .level = if (me.level > 0) me.level else null, .eager = true }),
            if (opp != null) h.span(.{ .class = "vs" }, .{W.vs}) else null,
            if (opp) |o| champ.view(h, champs[o.champ], .{ .px = .@"32", .eager = true }) else null,
        }),
        h.div(.{ .class = "res" }, .{
            h.div(.{ .class = "top" }, .{
                badge.view(h, if (g.win) .us else .them, .{if (g.win) W.win else W.loss}),
                kda.view(h, .{ .k = me.k, .d = me.d, .a = me.a }, .{ .s = .l }),
                h.span(.{ .class = "ratio" }, .{if (me.d == 0) W.perfect.with(h, .{ .kp = kp }) else W.ratio.with(h, .{ .r = ratio, .kp = kp })}),
            }),
            h.div(.{ .class = "meta" }, .{
                if (me.role) |r| role.view(h, r, .{}) else null,
                h.span(.{}, .{if (opp != null) W.matchup.with(h, .{ .a = champs[me.champ].name, .b = opp_name }) else tree.Text{ .s = champs[me.champ].name }}),
                h.span(.{}, .{g.queue}),
                h.span(.{}, .{phrase.num(h, .time, g.dur)}),
                h.span(.{}, .{g.day}),
                h.span(.{}, .{g.patch}),
            }),
        }),
        h.div(.{ .class = "how" }, .{ strip.view(h, cells[0..n]), kit(h, me, arts) }),
        h.div(.{ .class = "teams", .role = "group", .aria_label = W.teams }, .{
            h.div(.{ .aria_label = W.ours, .role = "group" }, .{rows[0].done()}),
            h.div(.{ .aria_label = W.theirs, .role = "group" }, .{rows[1].done()}),
        }),
    });
}

/// Six items and the trinket, then spells and keystone; none before Summary had them
fn kit(h: *H, me: gamedata.Seat, arts: []const art.Art) ?N {
    const at = struct {
        fn f(list: []const art.Art, i: u16) ?art.Art {
            return if (i < list.len) list[i] else null;
        }
    }.f;
    var items = h.list();
    var any = false;
    for (me.items) |i| {
        const a = at(arts, i);
        any = any or a != null;
        items.add(art.view(h, a orelse .{ .name = "", .src = "" }, .{ .px = .@"28" }));
    }
    var runes = h.list();
    for ([_]struct { u16, art.Kind }{ .{ me.spells[0], .spell }, .{ me.spells[1], .spell }, .{ me.keystone, .rune } }) |x| {
        if (at(arts, x[0])) |a| {
            any = true;
            runes.add(art.view(h, a, .{ .k = x[1], .px = .@"20" }));
        }
    }
    if (!any) return null;
    return h.div(.{ .class = "kit", .role = "group", .aria_label = W.kit }, .{
        h.span(.{ .class = "its" }, .{items.done()}),
        h.span(.{ .class = "sr" }, .{runes.done()}),
    });
}

pub const css =
    \\@layer components {
    \\  .c-ghead { display: grid; grid-template-columns: auto 1fr auto; grid-template-areas: "who res teams" "how how teams";
    \\    gap: var(--sp-3) var(--sp-5); align-items: center; padding: var(--card-pad); border-radius: var(--r-m);
    \\    background: linear-gradient(90deg, var(--them-bg), transparent 45%), var(--panel);
    \\    box-shadow: inset 3px 0 0 var(--them), inset 0 0 0 1px var(--line); }
    \\  .c-ghead[data-win] { background: linear-gradient(90deg, var(--us-bg), transparent 45%), var(--panel);
    \\    box-shadow: inset 3px 0 0 var(--us), inset 0 0 0 1px var(--line); }
    \\  .c-ghead > .who { grid-area: who; display: flex; align-items: center; gap: var(--sp-2); }
    \\  .c-ghead .vs { font-size: var(--fs-xs); color: var(--faint); }
    \\  .c-ghead > .res { grid-area: res; display: flex; flex-direction: column; gap: 4px; min-width: 0; }
    \\  .c-ghead .top { display: flex; align-items: center; flex-wrap: wrap; gap: var(--sp-2) var(--sp-3); }
    \\  .c-ghead .ratio { font-size: var(--fs-s); color: var(--t2); white-space: nowrap; font-variant-numeric: tabular-nums; }
    \\  .c-ghead .meta { display: flex; align-items: center; flex-wrap: wrap; gap: 2px var(--sp-3); font-size: var(--fs-s);
    \\    color: var(--muted); white-space: nowrap; }
    \\  .c-ghead > .how { grid-area: how; min-width: 0; display: flex; flex-wrap: wrap; align-items: center;
    \\    gap: var(--sp-3) var(--sp-5); }
    \\  .c-ghead .kit { display: flex; align-items: center; flex-wrap: wrap; gap: var(--sp-2) var(--sp-3); }
    \\  .c-ghead .kit > span { display: flex; align-items: center; gap: 3px; }
    \\  .c-ghead > .teams { grid-area: teams; display: flex; flex-direction: column; gap: 6px; align-self: start; }
    \\  .c-ghead > .teams > div { display: flex; gap: 4px; }
    \\  @container (max-width: 640px) {
    \\    .c-ghead { grid-template-columns: auto 1fr; grid-template-areas: "who res" "how how" "teams teams"; }
    \\    .c-ghead > .teams { flex-direction: row; justify-content: space-between; }
    \\  }
    \\  @container (max-width: 440px) {
    \\    .c-ghead { grid-template-areas: "who who" "res res" "how how" "teams teams"; }
    \\    .c-ghead > .teams { flex-direction: column; }
    \\  }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const d = @import("game_demo.zig").data;
    g.addFill("a win", view(h, &d.games[0], d.champs, d.arts));
    g.addFill("a loss", view(h, &d.games[1], d.champs, d.arts));
}
