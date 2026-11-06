//! CompView: the desktop app's comp view (docs/plan/app.md APP6). Each team's damage
//! split as a bar, a tag when teams this one-sided win less often, its champions with a
//! clear early or late lean; win chance by game length as a TrendChart; then the five
//! lanes as TeamRows. The band (static HTML under the loading screen, whose cards and
//! strips carry the leans and lanes): each team's damage either side of the chart. The
//! card (Teams, its own island under champ select's board, live from the first lock):
//! the band's row with the leans and tips under each split, then each lane's gold gap;
//! seats not locked yet hatch in the split. Champion facts only, never players. The
//! public edition gets words: every number here is null there (src/shell/screens.zig,
//! docs/production-key.md)
const tree = @import("tree.zig");
const champ = @import("champ.zig");
const teamrows = @import("teamrows.zig");
const phrase = @import("phrase.zig");
const trend = @import("trend.zig");
const toggletip = @import("toggletip.zig");
const badge = @import("badge.zig");
const dmgsplit = @import("dmgsplit.zig");
const role = @import("role.zig");
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
    /// The mix tally's bucket (30/70, not dmgOf's 35/65): the bar says it, so its words
    /// match the tag and the tips; null while seats are unknown (dmgOf of the known share)
    mix: ?Mix,
    /// Of the whole bar, the seats not locked or without a split: hatched
    unknown: f32 = 0,
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
    /// A line each, short and neutral ("Lone AP: Ahri")
    tips: []const []const u8 = &.{},
    /// Its champion with the most damage to champions a minute (learned.md: no carry
    /// label, who deals the damage is what is true)
    top: ?Top = null,
};

pub const Top = struct {
    champ: champ.Champ,
    /// Of the team's damage, %; private edition only
    share: ?f32 = null,
};

/// Win chance by game length from the champions' tallies (src/comp.zig Length)
pub const Length = struct {
    /// My team's, % by bucket (length_labels); private edition only
    win: ?[length_labels.len]f32 = null,
    /// Half each bucket's 80% range, points; private edition only
    range: ?[length_labels.len]f32 = null,
    /// More in long games, short ones; null: neither clearly
    longer: ?bool = null,
};

/// core.champfacts.length_edges as labels
const length_labels = [_][]const u8{ "<20", "20-25", "25-30", "30-35", "35+" };

pub const Comp = struct {
    us: Team,
    them: Team,
    /// Five rows, a line of words per seat ("ahead in lane, level 6 sooner"); the gap
    /// is the lane's gold at `lane_minute`, private edition only. None: no Lanes part
    /// (the loading screen's lane strips show them)
    lanes: []const teamrows.Row,
    length: ?Length = null,
    /// The damage facts' patch; "" without them
    patch: []const u8 = "",
    gold_minute: u8,
    win_minute: u8,
    lane_minute: u8,
    /// The notes' toggletip, unique on the page
    notes_id: []const u8 = "comp-notes",
    look: Look = .full,
};

pub const Look = enum {
    full,
    /// One row under the loading screen: damage, chart, damage; no tips, leans or lanes
    band,
    /// The band's row with the leans and tips, then the lanes' gold gaps (Teams)
    card,
};

pub const sel = "[data-island=teams]";

pub const Data = struct {
    /// The shell's count of changes, as app.Data's
    seq: u32,
    /// Null until a seat locks: the island's root, empty
    comp: ?Comp = null,
};

/// Champ select's Teams card as an island (ui-teams.wasm, teams.bin): a lock changes it
/// without the page reload a change to the shell's static HTML takes
pub const Teams = struct {
    data: Data,

    pub const Msg = enum {};

    pub fn update(_: *Teams, m: Msg, _: *tree.Event) void {
        switch (m) {}
    }

    pub fn view(t: *Teams, h: *H) N {
        var c = t.data.comp orelse return h.section(.{ .class = "c-comp", .data_island = "teams", .data_seq = t.data.seq }, .{});
        c.look = .card;
        return viewIn(h, c, t.data.seq);
    }
};

const Side = enum { us, them };

pub fn view(h: *H, c: Comp) N {
    return viewIn(h, c, null);
}

/// `seq`: the Teams island's root
fn viewIn(h: *H, c: Comp, seq: ?u32) N {
    const island: ?[]const u8 = if (seq != null) "teams" else null;
    const notes = toggletip.view(h, c.notes_id, .{W.comps}, W.comps, W.notes.with(h, .{
        .g = @as(u32, c.gold_minute),
        .w = @as(u32, c.win_minute),
        .p = if (c.patch.len > 0) c.patch else "?",
        .l = @as(u32, c.lane_minute),
    }));
    const len: ?N = if (c.length) |l| length(h, l, if (c.look == .full) 110 else 80) else null;
    // Without the chart the band is the two teams as usual
    if (c.look != .full) return h.section(.{ .class = "c-comp", .data_v = if (len != null) "band" else null, .data_island = island, .data_seq = seq }, .{
        h.h3(.{}, .{notes[0]}),
        notes[1],
        h.div(.{ .class = "teams" }, .{ team(h, c.us, .us, c.look == .band), len, team(h, c.them, .them, c.look == .band) }),
        if (c.look == .card) gaps(h, c.lanes, c.lane_minute) else null,
    });
    return h.section(.{ .class = "c-comp" }, .{
        h.h3(.{}, .{notes[0]}),
        notes[1],
        h.div(.{ .class = "teams" }, .{ team(h, c.us, .us, false), team(h, c.them, .them, false) }),
        len,
        if (c.lanes.len > 0) h.h3(.{}, .{W.lanes}) else null,
        if (c.lanes.len > 0) teamrows.view(h, c.lanes) else null,
    });
}

fn team(h: *H, t: Team, side: Side, band: bool) N {
    var early = h.list();
    var late = h.list();
    for (t.timing, 0..) |x, i| (if (x.late) &late else &early).add(h.li(.{ .key = i, .title = x.champ.name }, .{
        champ.view(h, x.champ, .{ .px = .@"24" }),
        if (x.gold != null and x.win != null)
            h.small(.{}, .{W.lean_numbers.with(h, .{ .g = @as(i32, @intFromFloat(@round(@as(f32, @floatFromInt(x.gold.?)) / 10) * 10)), .w = x.win.? })})
        else
            null,
    }));
    var tips = h.list();
    for (t.tips, 0..) |x, i| tips.add(h.li(.{ .key = i }, .{x}));
    return h.div(.{ .class = "team", .data_side = side }, .{
        h.el(.h4, .{}, .{if (side == .us) W.us else W.them}),
        if (t.tips.len > 0 and !band) h.ul(.{ .class = "tips" }, .{tips.done()}) else null,
        if (t.damage) |d| damage(h, d) else h.p(.{ .class = "none" }, .{W.no_split}),
        if (t.top) |x| h.p(.{ .class = "top" }, .{
            champ.view(h, x.champ, .{ .px = .@"20", .named = false }),
            W.top.with(h, .{ .n = x.champ.name }),
            if (x.share) |p| W.top_share.with(h, .{ .p = whole(p) }) else null,
        }) else null,
        if (early.items.items.len > 0 and !band) h.div(.{ .class = "lean" }, .{ h.span(.{}, .{W.early}), h.ul(.{}, .{early.done()}) }) else null,
        if (late.items.items.len > 0 and !band) h.div(.{ .class = "lean" }, .{ h.span(.{}, .{W.late}), h.ul(.{}, .{late.done()}) }) else null,
    });
}

/// Each lane's gold gap at the lane minute, the private edition's: none without one
fn gaps(h: *H, rows: []const teamrows.Row, minute: u8) ?N {
    var list = h.list();
    for (rows, 0..) |r, i| if (r.gap.len > 0) list.add(h.li(.{ .key = i }, .{
        role.view(h, r.role, .{ .s = .s }),
        h.b(.{ .data_lean = if (r.lean == .none) null else r.lean }, .{r.gap}),
    }));
    if (list.items.items.len == 0) return null;
    return h.div(.{ .class = "gaps" }, .{
        h.h3(.{}, .{W.gold.with(h, .{ .m = @as(u32, minute) })}),
        h.ul(.{}, .{list.done()}),
    });
}

/// Private: the line with its band against a dashed 50%, the band saying how sure;
/// words only when the lean is clear. Public: the words alone, nothing without a lean
fn length(h: *H, l: Length, height: u16) ?N {
    const words: ?tree.Text = if (l.longer) |x| (if (x) W.longer else W.shorter) else null;
    const chart: N = if (l.win) |win| blk: {
        const pts = trend.alloc(h, win.len) orelse break :blk .none;
        const range = l.range orelse @as([win.len]f32, @splat(0));
        for (pts, win, range, length_labels) |*p, w, r, label| p.* = .{ .label = .{ .s = label }, .v = w, .range = r };
        var t: trend.Trend = .{ .label = W.length, .points = pts, .height = height, .live = false };
        break :blk t.view(h);
    } else .none;
    if (words == null and l.win == null) return null;
    return h.div(.{ .class = "len" }, .{
        h.h3(.{}, .{W.length}),
        chart,
        if (words) |x| h.p(.{}, .{x}) else null,
    });
}

/// A share of champion averages isn't known to 0.1
fn whole(p: f32) u32 {
    return @intFromFloat(@round(@max(0, @min(100, p))));
}

/// The shares on its ends in the private edition only
fn damage(h: *H, d: Damage) N {
    const kind: ?dmgsplit.Kind = if (d.mix) |m| switch (m) {
        .physical => .ad,
        .mixed => .mixed,
        .magic => .ap,
    } else null;
    return h.div(.{ .class = "dmg" }, .{
        dmgsplit.view(h, .{ .ap = d.magic, .unknown = d.unknown, .kind = kind, .shares = d.share }),
        if (d.rate) |r| h.p(.{ .class = "rec" }, .{W.record.with(h, .{ .r = r, .n = d.teams })}) else null,
        if (d.wins_less) h.p(.{}, .{badge.view(h, .turn, .{W.one_sided})}) else null,
    });
}

const W = struct {
    const comps = plain("Team comps");
    const lanes = plain("Lanes");
    const gold = phrase.Phrase("Lane gold at {m:int} min");
    const us = plain("Your team");
    const them = plain("Enemy team");
    const no_split = plain("Damage split not known for every champion yet.");
    const record = phrase.Phrase("Teams like it won {r:rate} ({n:kilo} teams)");
    const one_sided = plain("One damage type: wins less");
    const early = plain("Early");
    const late = plain("Late");
    const lean_numbers = phrase.Phrase("{g:signed} g · {w:points} pts");
    const top = phrase.Phrase("Most damage: {n:text}");
    const top_share = phrase.Phrase(" ({p:pct} of the team's)");
    const length = plain("Win chance by game length");
    const longer = plain("Your champions win more in long games.");
    const shorter = plain("Your champions win more in short games.");
    const notes = phrase.Phrase("Champion averages: damage from patch {p:text} in EUW, leans from 30 days, lanes at {l:int} min. Early: its team is usually ahead at {g:int} min (gold) but wins less from an even game at {w:int} (pts); late, the other way round. One damage type: teams with only one kind of damage win less often, as one kind of defence blocks most of it.");
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
    \\  .c-comp .rec { font-size: var(--fs-s); color: var(--t2); }
    \\  .c-comp ul { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 4px; }
    \\  .c-comp li { display: flex; align-items: center; gap: var(--sp-2); min-width: 0; }
    \\  .c-comp .lean { display: flex; align-items: center; gap: var(--sp-2); }
    \\  .c-comp .lean > span { width: 3em; flex: none; font-size: var(--fs-xs); color: var(--muted); }
    \\  .c-comp .lean ul { flex-direction: row; flex-wrap: wrap; gap: var(--sp-1) var(--sp-3); }
    \\  .c-comp .lean li { gap: var(--sp-1); }
    \\  .c-comp .lean small { font-size: var(--fs-xs); color: var(--t2); font-variant-numeric: tabular-nums; white-space: nowrap; }
    \\  .c-comp .tips { gap: 2px; }
    \\  .c-comp .tips li { display: block; font-size: var(--fs-s); }
    \\  .c-comp .tips li::before { content: "› "; color: var(--muted); }
    \\  .c-comp .top { display: flex; align-items: center; gap: var(--sp-2); font-size: var(--fs-s); }
    \\  .c-comp .len { display: flex; flex-direction: column; gap: var(--sp-2); }
    \\  .c-comp .len > p { font-size: var(--fs-s); }
    \\  .c-comp[data-v="band"] .teams { grid-template-areas: "us" "them" "len"; }
    \\  .c-comp[data-v="band"] [data-side="us"] { grid-area: us; }
    \\  .c-comp[data-v="band"] [data-side="them"] { grid-area: them; }
    \\  .c-comp[data-v="band"] .len { grid-area: len; }
    \\  .c-comp[data-v="band"] .len h3 { margin: 0; }
    \\  @container (min-width: 440px) {
    \\    .c-comp[data-v="band"] .teams { grid-template-areas: "us them" "len len"; }
    \\  }
    \\  @container (min-width: 760px) {
    \\    .c-comp[data-v="band"] .teams { grid-template-columns: minmax(0, 1fr) minmax(0, 1.5fr) minmax(0, 1fr); grid-template-areas: "us len them"; }
    \\  }
    \\  /* Teams: a card of its own under the board, nothing before a lock */
    \\  .c-comp[data-island] { background: var(--panel); border: 1px solid var(--line); border-radius: var(--r-m); padding: var(--card-pad); }
    \\  .c-comp[data-island]:empty { display: none; }
    \\  .c-comp[data-island] > h3 { margin: 0; }
    \\  .c-comp .gaps { display: flex; align-items: center; flex-wrap: wrap; gap: var(--sp-1) var(--sp-4); }
    \\  .c-comp .gaps h3 { margin: 0; }
    \\  .c-comp .gaps ul { flex-direction: row; flex-wrap: wrap; gap: var(--sp-1) var(--sp-4); }
    \\  .c-comp .gaps li { gap: var(--sp-1); }
    \\  .c-comp .gaps b { font-size: var(--fs-s); font-variant-numeric: tabular-nums; }
    \\  .c-comp .gaps [data-lean="good"] { color: var(--hi2); }
    \\  .c-comp .gaps [data-lean="bad"] { color: var(--lo2); }
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
        .tips = &.{ "Lone AP: Orianna", "Level 6 first in 3 lanes" },
        .top = .{ .champ = demo("Jinx", "Jinx") },
    },
    .them = .{
        .damage = .{ .magic = 0.81, .mix = .magic, .wins_less = true },
        .timing = &.{},
        .tips = &.{"All in on AP: magic resist goes a long way"},
        .top = .{ .champ = demo("Syndra", "Syndra") },
    },
    .lanes = &lanes_public,
    .length = .{ .longer = true },
    .patch = "15.21",
    .gold_minute = 14,
    .win_minute = 20,
    .lane_minute = 14,
};

/// The tester's numbers beside the public words
pub fn private(h: *H) Comp {
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
    c.us.top.?.share = 31;
    c.them.top.?.share = 34;
    c.length = .{ .win = .{ 44.8, 48.2, 51.0, 53.6, 56.1 }, .range = .{ 2.1, 1.6, 1.5, 1.8, 2.6 }, .longer = true };
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
    var public = sample;
    public.notes_id = g.id("comp-pub");
    g.addFill("all locked, public", view(h, public));
    var priv = private(h);
    priv.notes_id = g.id("comp-priv");
    g.addFill("all locked, private", view(h, priv));
    var unsure = private(h);
    unsure.notes_id = g.id("comp-unsure");
    unsure.length = .{ .win = .{ 53.6, 52.9, 49.7, 48.3, 47.5 }, .range = .{ 4.8, 3.1, 2.9, 3.6, 6.4 } };
    g.addFill("private, length tilts but not sure: the band says so", view(h, unsure));
    // As the shell's lockedComp: picks locked, so no team record or "wins less"
    var band = private(h);
    band.notes_id = g.id("comp-band");
    band.lanes = &.{};
    band.look = .band;
    for ([_]*Team{ &band.us, &band.them }) |t| {
        t.damage.?.rate = null;
        t.damage.?.wins_less = false;
    }
    g.addFill("band under the loading screen, private", view(h, band));
    var band_public = sample;
    band_public.notes_id = g.id("comp-band-pub");
    band_public.lanes = &.{};
    band_public.look = .band;
    band_public.them.damage.?.wins_less = false;
    g.addFill("band, public: words for the length", view(h, band_public));
    // Teams in champ select: three of ours and two of theirs locked, the rest hatched
    var card = private(h);
    card.notes_id = g.id("comp-card");
    card.us.damage = .{ .magic = 0.3, .mix = null, .unknown = 0.4, .share = true };
    card.them.damage = .{ .magic = 0.36, .mix = null, .unknown = 0.6, .share = true };
    card.us.tips = &.{};
    card.them.tips = &.{};
    card.them.top = null;
    var teams: Teams = .{ .data = .{ .seq = 1, .comp = card } };
    g.addFill("Teams card from the first lock, private", teams.view(h));
    var card_public = sample;
    card_public.notes_id = g.id("comp-card-pub");
    card_public.us.damage = .{ .magic = 0.3, .mix = null, .unknown = 0.4 };
    var teams_public: Teams = .{ .data = .{ .seq = 1, .comp = card_public } };
    g.addFill("Teams card, public: no gold gaps", teams_public.view(h));
    g.addFill("a split unknown", view(h, .{
        .us = .{ .timing = sample.us.timing },
        .them = sample.them,
        .lanes = &lanes_public,
        .gold_minute = 14,
        .win_minute = 20,
        .lane_minute = 14,
        .notes_id = g.id("comp-split"),
    }));
}
