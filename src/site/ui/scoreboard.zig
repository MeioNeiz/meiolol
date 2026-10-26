//! Scoreboard: a game's players as five lane rows, your team left and theirs right
//! facing each other, so each row compares a lane (game-detail.md "Players"). A seat:
//! portrait with level, name over Riot ID, K/D/A over KDA, CS over per minute, items,
//! then a bar growing towards the middle (damage to champions, taken or gold: the
//! switch is the card head's). Between them the role and that lane's gold lead at 14.
//! A team band on top: result, K/D/A, gold, objectives. Narrow: names and CS go, items
//! move under the seat
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const kda = @import("kda.zig");
const art = @import("art.zig");
const badge = @import("badge.zig");
const objicon = @import("objicon.zig");
const segmented = @import("segmented.zig");
const gamedata = @import("gamedata.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "Scoreboard";
pub const scope = .{".c-board"};

pub const Bar = enum { damage, taken, gold };

const W = struct {
    pub const label = plain("Players by lane");
    pub const bar = plain("Bar");
    pub const damage = plain("Damage");
    pub const taken = plain("Taken");
    pub const gold = plain("Gold");
    pub const win = plain("WIN");
    pub const loss = plain("LOSS");
    pub const at14 = plain("at 14");
    pub const ratio = phrase.Phrase("{r:dec}");
    pub const per_min = phrase.Phrase("{v:dec}");
    pub const towers = plain("Towers");
    pub const dragons = plain("Dragons");
    pub const baron = plain("Baron");
    pub const grubs = plain("Grubs");
    pub const ours = plain("Your team");
    pub const theirs = plain("Their team");
};

const Side = enum { us, them };

const roles = @typeInfo(role.Role).@"enum".field_names.len;

pub const Board = struct {
    bar: Bar = .damage,

    pub const Msg = union(enum) { bar: Bar };

    pub fn update(b: *Board, m: Msg, _: *tree.Event) void {
        b.bar = m.bar;
    }

    /// Damage | Taken | Gold, for the card head
    pub fn switcher(b: *Board, h: *H) N {
        const all = [_]struct { Bar, tree.Text }{ .{ .damage, W.damage }, .{ .taken, W.taken }, .{ .gold, W.gold } };
        var segs: [all.len]segmented.Item = undefined;
        for (all, &segs) |x, *it| it.* = .{ .label = x[1], .selected = b.bar == x[0], .on = h.on(b, .{ .bar = x[0] }) };
        return segmented.view(h, .{ .s = .s, .label = W.bar }, h.mem.dupe(segmented.Item, &segs) catch {
            h.oom = true;
            return .none;
        });
    }

    pub fn view(b: *const Board, h: *H, g: *const gamedata.Game, d: *const gamedata.Data) N {
        const lanes = byLane(g);
        var top: u32 = 1;
        for (g.seats) |s| top = @max(top, b.of(s));
        var rows = h.list();
        for (lanes, 0..) |l, i| {
            const r: role.Role = @fromBackingInt(@intCast(i));
            const lead: ?i32 = if (l[0]) |x| g.seats[x].lane14 else null;
            rows.add(h.div(.{ .key = i, .class = "lr" }, .{
                b.seat(h, g, d, l[0], .us, top),
                h.div(.{ .class = "mid" }, .{
                    role.view(h, r, .{ .s = .s, .named = false }),
                    if (lead) |v| h.span(.{ .class = "ld", .data_side = if (v > 0) Side.us else if (v < 0) Side.them else null }, .{phrase.num(h, .signed, v)}) else null,
                }),
                b.seat(h, g, d, l[1], .them, top),
            }));
        }
        const t = gamedata.teams(g);
        return h.div(.{ .class = "c-board", .role = "group", .aria_label = W.label }, .{
            h.div(.{ .class = "top" }, .{
                team(h, g, t, .us),
                h.span(.{ .class = "mid" }, .{W.at14}),
                team(h, g, t, .them),
            }),
            rows.done(),
        });
    }

    fn of(b: *const Board, s: gamedata.Seat) u32 {
        return switch (b.bar) {
            .damage => s.damage,
            .taken => s.taken,
            .gold => s.gold,
        };
    }

    fn seat(b: *const Board, h: *H, g: *const gamedata.Game, d: *const gamedata.Data, slot: ?u8, side: Side, top: u32) N {
        const i = slot orelse return h.div(.{ .class = "seat", .data_side = side }, .{});
        const s = g.seats[i];
        const mins: f32 = @as(f32, @floatFromInt(@max(g.dur, 60))) / 60;
        const r: f32 = @as(f32, @floatFromInt(@as(u32, s.k) + s.a)) / @as(f32, @floatFromInt(@max(s.d, 1)));
        const v = b.of(s);
        const c = d.champs[s.champ];
        return h.div(.{ .class = "seat", .data_side = side, .data_you = i == g.you }, .{
            champ.view(h, c, .{ .px = .@"32", .level = if (s.level > 0) s.level else null, .you = i == g.you, .named = false }),
            h.span(.{ .class = "nm" }, .{ h.b(.{}, .{c.name}), if (s.riot_id.len > 0) h.small(.{}, .{s.riot_id}) else null }),
            h.span(.{ .class = "kd" }, .{
                kda.view(h, .{ .k = s.k, .d = s.d, .a = s.a }, .{}),
                h.small(.{}, .{W.ratio.with(h, .{ .r = r })}),
            }),
            h.span(.{ .class = "cs" }, .{ h.b(.{}, .{s.cs}), h.small(.{}, .{W.per_min.with(h, .{ .v = @as(f32, @floatFromInt(s.cs)) / mins })}) }),
            items(h, d, s),
            h.span(.{ .class = "bar" }, .{
                h.span(.{}, .{phrase.num(h, .kilo, v)}),
                h.el(.i, .{ .aria_hidden = true, .style = h.vars(.{ .w = @round(@as(f32, @floatFromInt(v)) * 1000 / @as(f32, @floatFromInt(top))) / 10 }) }, .{}),
            }),
        });
    }
};

/// Six items then the trinket; none when the game has no loadouts
fn items(h: *H, d: *const gamedata.Data, s: gamedata.Seat) N {
    var any = false;
    for (s.items) |x| any = any or x != gamedata.no_art;
    if (!any) return .none;
    var l = h.list();
    for (s.items, 0..) |x, i| {
        if (i == 6) l.add(h.span(.{ .class = "gap" }, .{}));
        l.add(art.view(h, d.artAt(x) orelse .{ .name = "", .src = "" }, .{ .px = .@"20" }));
    }
    return h.span(.{ .class = "it" }, .{l.done()});
}

fn team(h: *H, g: *const gamedata.Game, t: gamedata.Teams, side: Side) N {
    const us = side == .us;
    var k: [3]u16 = .{ 0, 0, 0 };
    for (g.seats) |s| if (s.us == us) {
        k[0] += s.k;
        k[1] += s.d;
        k[2] += s.a;
    };
    const won = g.win == us;
    var objs = h.list();
    for ([_]struct { objicon.Kind, gamedata.Tally, tree.Text }{
        .{ .tower, t.towers, W.towers },
        .{ .dragon, t.dragons, W.dragons },
        .{ .baron, t.baron, W.baron },
        .{ .grubs, t.grubs, W.grubs },
    }) |x| objs.add(h.span(.{ .title = x[2] }, .{
        objicon.view(h, x[0], .{ .s = .s, .named = false }),
        h.b(.{}, .{if (us) x[1].us else x[1].them}),
    }));
    return h.div(.{ .class = "tm", .data_side = side, .role = "group", .aria_label = if (us) W.ours else W.theirs }, .{
        badge.view(h, if (won) .us else .them, .{if (won) W.win else W.loss}),
        kda.view(h, .{ .k = k[0], .d = k[1], .a = k[2] }, .{}),
        h.span(.{ .class = "gold" }, .{phrase.num(h, .kilo, t.gold[@intFromBool(!us)])}),
        h.span(.{ .class = "objs" }, .{objs.done()}),
    });
}

/// Each role's seat per side; a seat without a role takes the first free row
fn byLane(g: *const gamedata.Game) [roles][2]?u8 {
    var out: [roles][2]?u8 = @splat(.{ null, null });
    for (g.seats, 0..) |s, i| if (s.role) |r| {
        const c = &out[@backingInt(r)][@intFromBool(!s.us)];
        if (c.* == null) c.* = @intCast(i);
    };
    for (g.seats, 0..) |s, si| {
        const i: u8 = @intCast(si);
        const side = @intFromBool(!s.us);
        var placed = false;
        for (out) |row| placed = placed or row[side] == i;
        if (placed) continue;
        for (&out) |*row| if (row[side] == null) {
            row[side] = i;
            break;
        };
    }
    return out;
}

pub const css =
    \\@layer components {
    \\  .c-board { display: flex; flex-direction: column; min-width: 0; container-type: inline-size; font-variant-numeric: tabular-nums; }
    \\  .c-board .top, .c-board .lr { display: grid; grid-template-columns: minmax(0, 1fr) 64px minmax(0, 1fr); align-items: center; gap: var(--sp-2); }
    \\  .c-board .top { padding: var(--sp-2) var(--sp-3); background: var(--panel-2); font-size: var(--fs-s); }
    \\  .c-board .top > .mid { text-align: center; font-size: var(--fs-xs); color: var(--faint); }
    \\  .c-board .tm { display: flex; align-items: center; gap: var(--sp-3); min-width: 0; white-space: nowrap; }
    \\  .c-board .tm[data-side="them"] { flex-direction: row-reverse; }
    \\  .c-board .tm > .gold { color: var(--t2); }
    \\  .c-board .objs { display: flex; gap: var(--sp-2); margin: 0 var(--sp-2); }
    \\  .c-board .tm[data-side="us"] > .objs { margin-left: auto; }
    \\  .c-board .tm[data-side="them"] > .objs { margin-right: auto; flex-direction: row-reverse; }
    \\  .c-board .objs > span { display: inline-flex; align-items: center; gap: 3px; }
    \\  .c-board .lr { padding: 0 var(--sp-3); border-top: 1px solid var(--line); }
    \\  .c-board .lr > .mid { display: flex; flex-direction: column; align-items: center; gap: 2px; color: var(--muted); }
    \\  .c-board .ld { font-size: var(--fs-s); font-weight: var(--w-b); color: var(--t2); }
    \\  .c-board .ld[data-side="us"] { color: var(--us-hot); }
    \\  .c-board .ld[data-side="them"] { color: var(--them-hot); }
    \\  .c-board .seat { display: grid; grid-template-columns: 32px minmax(0, 1fr) 56px 40px auto 88px;
    \\    grid-template-areas: "c nm kd cs it bar"; align-items: center; gap: var(--sp-3); min-width: 0; padding: 8px 0; }
    \\  .c-board .seat[data-side="them"] { grid-template-columns: 88px auto 40px 56px minmax(0, 1fr) 32px;
    \\    grid-template-areas: "bar it cs kd nm c"; text-align: right; }
    \\  .c-board .seat[data-you] { background: var(--panel-2); box-shadow: -10px 0 0 var(--panel-2), 10px 0 0 var(--panel-2), -12px 0 0 var(--us); }
    \\  .c-board .seat > .c-champ { grid-area: c; }
    \\  .c-board .nm { grid-area: nm; display: flex; flex-direction: column; min-width: 0; }
    \\  .c-board .nm > *, .c-board .nm > small { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    \\  .c-board .nm > b { font-weight: var(--w-m); }
    \\  .c-board small { font-size: var(--fs-xs); color: var(--faint); display: block; }
    \\  .c-board .kd { grid-area: kd; }
    \\  .c-board .cs { grid-area: cs; }
    \\  .c-board .it { grid-area: it; display: flex; gap: 2px; }
    \\  .c-board .seat[data-side="them"] .it { flex-direction: row-reverse; }
    \\  .c-board .it > .gap { width: 4px; }
    \\  .c-board .bar { grid-area: bar; display: flex; flex-direction: column; gap: 3px; font-size: var(--fs-s); color: var(--t2); }
    \\  .c-board .bar > i { height: 4px; border-radius: 2px; background: linear-gradient(90deg, transparent calc(100% - var(--w) * 1%), var(--t2) 0), var(--bar-track); }
    \\  .c-board .seat[data-side="them"] .bar > i { background: linear-gradient(90deg, var(--t2) calc(var(--w) * 1%), transparent 0), var(--bar-track); }
    \\  .c-board .seat[data-side="us"] .bar { align-items: flex-end; }
    \\  .c-board .seat[data-side="us"] .bar > i { align-self: stretch; }
    \\  @container (max-width: 980px) {
    \\    .c-board .nm > small { display: none; }
    \\    .c-board .seat { grid-template-columns: 32px minmax(0, 1fr) 56px 64px; grid-template-areas: "c nm kd bar" "it it it it"; row-gap: 6px; }
    \\    .c-board .seat[data-side="them"] { grid-template-columns: 64px 56px minmax(0, 1fr) 32px; grid-template-areas: "bar kd nm c" "it it it it"; }
    \\    .c-board .seat[data-side="them"] .it { justify-content: flex-end; }
    \\    .c-board .cs { display: none; }
    \\  }
    \\  @container (max-width: 560px) {
    \\    .c-board .top, .c-board .lr { grid-template-columns: minmax(0, 1fr) 44px minmax(0, 1fr); gap: var(--sp-1); padding: 0 var(--sp-2); }
    \\    .c-board .top { padding: var(--sp-2); }
    \\    .c-board .tm { flex-wrap: wrap; gap: 4px var(--sp-2); }
    \\    .c-board .tm > .objs, .c-board .tm > .gold { display: none; }
    \\    .c-board .nm { display: none; }
    \\    .c-board .seat { grid-template-columns: 32px auto minmax(0, 1fr); grid-template-areas: "c kd bar" "it it it"; gap: 4px var(--sp-2); }
    \\    .c-board .seat[data-side="them"] { grid-template-columns: minmax(0, 1fr) auto 32px; grid-template-areas: "bar kd c" "it it it"; }
    \\    .c-board .it .c-art { width: 16px; height: 16px; }
    \\    .c-board .seat[data-you] { box-shadow: -6px 0 0 var(--panel-2), 6px 0 0 var(--panel-2), -8px 0 0 var(--us); }
    \\  }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const d = &@import("game_demo.zig").data;
    var b: Board = .{};
    g.addFill("damage, a win", b.view(h, &d.games[0], d));
    b.bar = .gold;
    g.addFill("gold, a loss", b.view(h, &d.games[1], d));
}

const testing = std.testing;

test "every seat in its lane, one without a role in a free row" {
    const d = &@import("game_demo.zig").data;
    var seats: [10]gamedata.Seat = undefined;
    @memcpy(&seats, d.games[0].seats);
    seats[2].role = null;
    var g = d.games[0];
    g.seats = &seats;
    const l = byLane(&g);
    for (l) |row| for (row) |x| try testing.expect(x != null);
    try testing.expectEqual(@as(?u8, 2), l[@backingInt(role.Role.mid)][1]);
}
