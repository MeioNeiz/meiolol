//! CompView: the desktop app's comp view once all ten champions are locked (docs/plan/
//! app.md APP6), under the board. Each team's damage split as a bar and its mix in
//! words, a warning when teams this one-sided win less often, its champions with a clear
//! early or late lean; then the five lanes as TeamRows. Champion facts only, never
//! players. The public edition gets words: every number here is null there
//! (src/shell/screens.zig, docs/production-key.md)
const tree = @import("tree.zig");
const champ = @import("champ.zig");
const teamrows = @import("teamrows.zig");
const phrase = @import("phrase.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "CompView";
pub const scope = .{".c-comp"};

pub const Mix = enum { physical, mixed, magic };

pub const Damage = struct {
    /// The team's average magic share of damage to champions, 0 to 1: the bar
    magic: f32,
    mix: Mix,
    /// Teams with this mix win under even by 2 SE (Learn's tally)
    wins_less: bool = false,
    /// Private edition: show the share in %
    share: bool = false,
    /// Private edition: those teams' win rate in % and how many there were
    rate: ?f32 = null,
    teams: u32 = 0,
};

pub const Timing = struct {
    champ: champ.Champ,
    late: bool,
    /// Private edition: team gold at the gold minute and win points at the win minute
    gold: ?i32 = null,
    win: ?f32 = null,
};

pub const Team = struct {
    /// Null unless every champion's damage split is known
    damage: ?Damage = null,
    /// Early first
    timing: []const Timing = &.{},
};

pub const Comp = struct {
    us: Team,
    them: Team,
    /// Five rows, a line of words per seat ("ahead in lane, level 6 sooner"); the gap
    /// is the lane's gold at `lane_minute`, private edition only
    lanes: []const teamrows.Row,
    /// The damage facts' patch; "" without them
    patch: []const u8 = "",
    gold_minute: u8,
    win_minute: u8,
    lane_minute: u8,
};

const Side = enum { us, them };

pub fn view(h: *H, c: Comp) N {
    return h.section(.{ .class = "c-comp" }, .{
        h.h3(.{}, .{W.comps}),
        h.div(.{ .class = "teams" }, .{ team(h, c.us, .us, c), team(h, c.them, .them, c) }),
        h.h3(.{}, .{W.lanes}),
        teamrows.view(h, c.lanes),
        h.p(.{ .class = "note" }, .{W.lean_note.with(h, .{ .g = @as(u32, c.gold_minute), .w = @as(u32, c.win_minute) })}),
        h.p(.{ .class = "note" }, .{W.scope.with(h, .{ .p = if (c.patch.len > 0) c.patch else "?", .l = @as(u32, c.lane_minute) })}),
    });
}

fn team(h: *H, t: Team, side: Side, c: Comp) N {
    var rows = h.list();
    for (t.timing, 0..) |x, i| rows.add(h.li(.{ .key = i }, .{
        champ.view(h, x.champ, .{ .px = .@"24", .named = false }),
        h.span(.{ .class = "who" }, .{
            if (x.late) W.late.with(h, .{ .n = x.champ.name }) else W.early.with(h, .{ .n = x.champ.name }),
            if (x.gold != null and x.win != null)
                h.small(.{}, .{W.lean_numbers.with(h, .{ .g = @as(i32, @intFromFloat(@round(@as(f32, @floatFromInt(x.gold.?)) / 10) * 10)), .gm = @as(u32, c.gold_minute), .w = x.win.?, .wm = @as(u32, c.win_minute) })})
            else
                null,
        }),
    }));
    return h.div(.{ .class = "team", .data_side = side }, .{
        h.el(.h4, .{}, .{if (side == .us) W.us else W.them}),
        if (t.damage) |d| damage(h, d) else h.p(.{ .class = "none" }, .{W.no_split}),
        if (t.timing.len > 0) h.ul(.{}, .{rows.done()}) else h.p(.{ .class = "none" }, .{W.no_lean}),
    });
}

/// Magic from the left, physical the rest; then the mix in words
fn damage(h: *H, d: Damage) N {
    const pct = 100 * @max(0, @min(1, d.magic));
    const words = switch (d.mix) {
        .physical => W.physical,
        .mixed => W.mixed,
        .magic => W.magic,
    };
    return h.div(.{ .class = "dmg" }, .{
        h.span(.{ .class = "bar", .aria_hidden = true }, .{h.el(.i, .{ .style = h.vars(.{ .w = pct }) }, .{})}),
        h.span(.{ .class = "ends", .aria_hidden = true }, .{ h.span(.{}, .{W.magic_end}), h.span(.{}, .{W.physical_end}) }),
        h.p(.{}, .{ words, if (d.share) W.share.with(h, .{ .p = pct }) else null }),
        if (d.rate) |r| h.p(.{ .class = "rec" }, .{W.record.with(h, .{ .r = r, .n = d.teams })}) else null,
        if (d.wins_less) h.p(.{ .class = "less" }, .{W.wins_less}) else null,
    });
}

const W = struct {
    const comps = plain("Team comps");
    const lanes = plain("Lanes");
    const us = plain("Your team");
    const them = plain("Enemy team");
    const no_split = plain("Damage split not known for every champion yet.");
    const no_lean = plain("No champion with a clear early or late lean.");
    const physical = plain("Mostly physical damage");
    const mixed = plain("Mixed damage");
    const magic = plain("Mostly magic damage");
    const magic_end = plain("magic");
    const physical_end = plain("physical");
    const share = phrase.Phrase(": {p:rate} magic");
    const record = phrase.Phrase("Teams like it won {r:rate} ({n:kilo} teams)");
    const wins_less = plain("Teams this one-sided win less often: one kind of defence blocks most of their damage.");
    const early = phrase.Phrase("{n:text} leans early");
    const late = phrase.Phrase("{n:text} leans late");
    const lean_numbers = phrase.Phrase("{g:signed} gold at {gm:int} min, {w:points} pts at {wm:int}");
    const lean_note = phrase.Phrase("Early: its team is usually ahead at {g:int} min but wins less from an even game at {w:int}; late, the other way round.");
    const scope = phrase.Phrase("Champion averages: damage from patch {p:text} in EUW, leans from 30 days, lanes at {l:int} min.");
};

pub const css =
    \\@layer components {
    \\  .c-comp { container-type: inline-size; display: flex; flex-direction: column; gap: var(--sp-2); min-width: 0; }
    \\  .c-comp h3 { margin: var(--sp-2) 0 0; font-size: var(--fs-s); font-weight: var(--w-m); color: var(--t2); }
    \\  .c-comp .teams { display: grid; grid-template-columns: minmax(0, 1fr); gap: var(--sp-2); }
    \\  @container (min-width: 440px) {
    \\    .c-comp .teams { grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); }
    \\  }
    \\  .c-comp .team { display: flex; flex-direction: column; gap: var(--sp-2); padding: var(--sp-2) var(--sp-3);
    \\    border-radius: var(--r-s); background: var(--panel-2); min-width: 0; }
    \\  .c-comp h4 { margin: 0; font-size: var(--fs-s); font-weight: var(--w-b); }
    \\  .c-comp [data-side="us"] h4 { color: var(--us); }
    \\  .c-comp [data-side="them"] h4 { color: var(--them); }
    \\  .c-comp p { margin: 0; }
    \\  .c-comp .none { font-size: var(--fs-xs); color: var(--muted); }
    \\  .c-comp .dmg { display: flex; flex-direction: column; gap: 3px; }
    \\  .c-comp .bar { position: relative; height: 8px; border-radius: 4px; background: var(--bar-lo); overflow: hidden; }
    \\  .c-comp .bar > i { position: absolute; inset: 0 auto 0 0; width: calc(var(--w) * 1%); background: var(--bar-hi); }
    \\  .c-comp .ends { display: flex; justify-content: space-between; font-size: var(--fs-xs); color: var(--muted); }
    \\  .c-comp .dmg > p { font-size: var(--fs-s); }
    \\  .c-comp .rec { color: var(--t2); }
    \\  .c-comp .less { color: var(--lo2); }
    \\  .c-comp ul { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 4px; }
    \\  .c-comp li { display: flex; align-items: center; gap: var(--sp-2); min-width: 0; }
    \\  .c-comp .who { display: flex; flex-direction: column; min-width: 0; font-size: var(--fs-s); }
    \\  .c-comp .who > small { font-size: var(--fs-xs); color: var(--t2); font-variant-numeric: tabular-nums; }
    \\  .c-comp .note { font-size: var(--fs-xs); color: var(--faint); }
    \\}
    \\
;

const demo = champ.demo;

const lanes_public = [_]teamrows.Row{
    .{ .role = .top, .us = .{ .champ = demo("Darius", "Darius"), .line = "behind in lane, level 6 later" }, .them = .{ .champ = demo("Malphite", "Malphite"), .line = "ahead in lane, level 6 sooner" } },
    .{ .role = .jungle, .us = .{ .champ = demo("Vi", "Vi"), .line = "even early" }, .them = .{ .champ = demo("LeeSin", "Lee Sin"), .line = "even early" } },
    .{ .role = .mid, .us = .{ .champ = demo("Ahri", "Ahri"), .you = true, .line = "behind in lane" }, .them = .{ .champ = demo("Syndra", "Syndra"), .line = "ahead in lane" } },
    .{ .role = .bot, .us = .{ .champ = demo("Jinx", "Jinx"), .line = "few games of this lane" }, .them = .{ .champ = demo("Caitlyn", "Caitlyn") } },
    .{ .role = .support, .us = .{ .champ = demo("Thresh", "Thresh"), .line = "even in lane" }, .them = .{ .champ = demo("Leona", "Leona"), .line = "even in lane" } },
};

pub const sample: Comp = .{
    .us = .{
        .damage = .{ .magic = 0.38, .mix = .mixed },
        .timing = &.{
            .{ .champ = demo("Darius", "Darius"), .late = false },
            .{ .champ = demo("Jinx", "Jinx"), .late = true },
        },
    },
    .them = .{
        .damage = .{ .magic = 0.81, .mix = .magic, .wins_less = true },
        .timing = &.{},
    },
    .lanes = &lanes_public,
    .patch = "15.21",
    .gold_minute = 14,
    .win_minute = 20,
    .lane_minute = 14,
};

/// The tester's numbers beside the public words
fn private(h: *H) Comp {
    var c = sample;
    c.us.damage.?.share = true;
    c.us.damage.?.rate = 50.4;
    c.us.damage.?.teams = 41_200;
    c.them.damage.?.share = true;
    c.them.damage.?.rate = 47.9;
    c.them.damage.?.teams = 6_300;
    const timing = h.mem.dupe(Timing, sample.us.timing) catch {
        h.oom = true;
        return sample;
    };
    timing[0].gold = 480;
    timing[0].win = -2.6;
    timing[1].gold = -390;
    timing[1].win = 3.1;
    c.us.timing = timing;
    const rows = h.mem.dupe(teamrows.Row, &lanes_public) catch {
        h.oom = true;
        return sample;
    };
    for (rows, [_][]const u8{ "−420", "+40", "−230", "", "+10" }, [_]teamrows.Lean{ .bad, .none, .bad, .none, .none }) |*r, gap, lean| {
        r.gap = gap;
        r.lean = lean;
    }
    c.lanes = rows;
    return c;
}

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.addFill("all locked, public", view(h, sample));
    g.addFill("all locked, private", view(h, private(h)));
    g.addFill("a split unknown", view(h, .{
        .us = .{ .timing = sample.us.timing },
        .them = sample.them,
        .lanes = &lanes_public,
        .gold_minute = 14,
        .win_minute = 20,
        .lane_minute = 14,
    }));
}
