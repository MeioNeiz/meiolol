//! StatRanking (docs/plan/ui/rankings.md): every champion in a role ranked by one stat, a
//! DataTable island (ui-rankings.wasm) from its data-bin. A stat is a spec (`spec`, by
//! urls.Stat): its name and what its figure counts; the server picks the rows. Sorted by
//! the figure's edge over the role pulled toward 0 when its games are few, shown raw, so
//! a thin row can't top the list; rows under the floor wait behind a chip, faded
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const table = @import("table.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const stat = @import("stat.zig");
const delta = @import("delta.zig");
const fmt = @import("fmt.zig");
const urls = @import("urls.zig");
const segmented = @import("segmented.zig");
const card = @import("card.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "StatRanking";
pub const scope = .{ ".c-rank", ".c-rankhead", ".c-rankidx" };

pub const Stat = urls.Stat;
pub const Role = role.Role;
pub const sel = "[data-island=ranking]";

pub const Spec = struct {
    /// The page's heading
    title: []const u8,
    /// Its label in the switch between sibling stats
    short: []const u8,
    /// What the figure counts, one line under the heading
    lead: []const u8,
    /// Shorter, on its card in the index
    about: []const u8,
};

pub fn spec(s: Stat) Spec {
    return switch (s) {
        .ahead => .{ .title = "Wins from ahead", .short = "From ahead", .lead = "Win rate in games where the champion was 1,500+ gold ahead of its lane opponent at 15 minutes. Compare within a role. No champion was found to turn its own lead into wins better than others in its role.", .about = "Win rate when 1,500+ gold ahead of the lane opponent at 15 minutes." },
        .behind => .{ .title = "Wins from behind", .short = "From behind", .lead = "Win rate in games where the champion was 1,500+ gold behind its lane opponent at 15 minutes. Compare within a role; late-game champions hold up better from behind. No champion was found to come back better than its strength and scaling predict.", .about = "Win rate when 1,500+ gold behind the lane opponent at 15 minutes." },
        .long_games => .{ .title = "Wins in long games", .short = "Long games", .lead = "Win rate in games of 35+ minutes minus in games under 25, in points: who wins more of its long games. Stomps end early: this is how its games go, not a power curve.", .about = "Win rate in 35+ minute games minus under 25: who wins more of its long games." },
        .lane_gold => .{ .title = "Lane gold at 14", .short = "Lane gold", .lead = "Gold ahead of or behind its lane opponent at 14 minutes, averaged over its lanes: who wins its lane.", .about = "Gold lead over the lane opponent at 14 minutes: who wins its lane." },
    };
}

/// What a stat's figure is: a win rate in one spot, a gap between two win rates, or a
/// gold lead
pub const Kind = enum { rate, gap, gold };

pub fn kindOf(s: Stat) Kind {
    return switch (s) {
        .ahead, .behind => .rate,
        .long_games => .gap,
        .lane_gold => .gold,
    };
}

/// lean.tsv's (champfacts.Lean)
pub const Lean = enum { early, late, none };

/// Stats shown as one page with a switch, in its order
pub const siblings = [_][]const Stat{ &.{ .ahead, .behind }, &.{.long_games}, &.{.lane_gold} };

pub fn siblingsOf(s: Stat) []const Stat {
    for (siblings) |g| for (g) |x| if (x == s) return g;
    unreachable;
}

pub const Data = struct {
    stat: Stat,
    /// Null: All, each champion in its main role
    role: ?Role,
    ddragon: []const u8,
    rows: []const Row,
};

pub const Row = struct {
    name: []const u8,
    key: []const u8,
    /// The fragment that marks it (a champion page's place link)
    slug: []const u8 = "",
    href: []const u8,
    role: Role,
    /// The figure (a win rate, %; a gap, points; gold) and the role's (a gap, gold: 0)
    value: f32,
    usual: f32,
    /// value - usual pulled toward 0 by how few games it has: the sort
    pulled: f32,
    /// Games behind the figure (a gap: its thinner side's; gold: lanes at 14)
    n: u32,
    /// The champion's win rate over all its games in the role, and those games
    overall: f32,
    games: u32 = 0,
    /// A gap's two win rates, short games' then long games'
    sides: [2]f32 = .{ 0, 0 },
    lean: Lean = .none,
};

/// Under this many games behind the figure a row waits behind the chip
pub const thin_games = fmt.thin_games;

const W = struct {
    pub const title = plain("Champions");
    pub const champion = plain("Champion");
    pub const win = plain("Win rate");
    pub const win_note = plain("Sorted by its edge over the role, pulled toward the role when games are few.");
    pub const vs = plain("Vs role");
    pub const vs_note = plain("Its win rate here minus the role's, in points.");
    pub const games = plain("Games");
    pub const games_note = plain("Games behind the win rate.");
    pub const overall = plain("Overall");
    pub const overall_note = plain("Its win rate over all its games in the role.");
    pub const few = plain("unsure");
    pub const stat = plain("Stat");
    pub const role = plain("Role");
    pub const gap = plain("Gap");
    pub const gap_note = plain("Win rate in long games minus in short ones, in points; sorted pulled toward the role when games are few.");
    pub const short = plain("Under 25");
    pub const long = plain("35+ min");
    pub const lean = plain("Lean");
    pub const lean_note = plain("Its strength by phase, from team gold at 14 and wins from an even game at 20, every region. Blank: neither is clear.");
    pub const lead = plain("Gold lead");
    pub const lead_note = plain("Gold ahead of the lane opponent at 14 minutes, averaged over its lanes; sorted pulled toward 0 when lanes are few.");
    pub const lanes = plain("Lanes");
    pub const lanes_note = plain("Lanes still going at 14 minutes.");
    pub const early = plain("Early");
    pub const late = plain("Late");
    pub const none = plain("More data needed: no champion has games in this spot yet.");
    pub const full = plain("Every champion ›");
    pub const pickup = "How hard to pick up";
    pub const pickup_about = "Practised players' win rate on the champion minus new players', every region: which take longest to learn.";
    pub const index_lead = plain("Each card's top three over all roles, each champion in its main role, with 100+ games behind the figure.");
};

/// A stat's card in the index (/rankings): its top champions over every role, each in
/// its main role, solid rows only
pub const Card = struct {
    /// Null: how hard to pick up (/pickup, its own page: per champion, every region)
    stat: ?Stat,
    href: []const u8,
    top: []const Top,

    /// Pick-up's figure is a gap: practised minus new players' win rate
    pub fn kind(c: Card) Kind {
        return if (c.stat) |s| kindOf(s) else .gap;
    }

    pub const Top = struct {
        name: []const u8,
        src: []const u8,
        href: []const u8,
        /// Null: a figure over all its roles
        role: ?Role,
        value: f32,
        usual: f32,
        n: u32,
    };
};

/// How many champions a card names
pub const card_top = 3;

/// The index's cards, one per stat
pub fn index(h: *H, cards: []const Card) N {
    var kids = h.list();
    for (cards, 0..) |c, i| {
        const title, const about = if (c.stat) |s| .{ spec(s).title, spec(s).about } else .{ W.pickup, W.pickup_about };
        var rows = h.list();
        for (c.top, 0..) |t, k| rows.add(h.li(.{ .key = k }, .{
            whoView(h, .{ .name = t.name, .src = t.src }, t.href, t.role, .{ .px = .@"32", .eager = true }),
            switch (c.kind()) {
                .gold => goldView(h, t.value, t.n),
                else => |kd| stat.view(h, .{ .value = t.value, .kind = if (kd == .gap) .points else .rate, .scale = .aggregate, .ref = t.usual, .range = rangeOf(kd, t.value, t.n) }),
            },
        }));
        kids.add(h.div(.{ .key = i }, .{card.view(h, .{}, &.{
            h.h2(.{}, .{h.a(.{ .href = c.href }, .{title})}),
            h.p(.{}, .{about}),
            if (c.top.len == 0) h.p(.{ .class = "none" }, .{W.none}) else h.ul(.{}, .{rows.done()}),
            h.a(.{ .class = "full", .href = c.href }, .{W.full}),
        })}));
    }
    return h.div(.{ .class = "c-rankidx" }, .{ h.p(.{ .class = "lead" }, .{W.index_lead}), h.div(.{ .class = "cards" }, .{kids.done()}) });
}

pub const Line = struct {
    r: *const Row,
    icon: []const u8,
    all: bool,
    /// Named by the URL's fragment: lit
    here: bool = false,
};

fn nameOf(l: *const Line) []const u8 {
    return l.r.name;
}
fn nOf(l: *const Line) u32 {
    return l.r.n;
}
fn nF(l: *const Line) f64 {
    return @floatFromInt(l.r.n);
}
fn pulledOf(l: *const Line) f64 {
    return l.r.pulled;
}
fn vsOf(l: *const Line) f64 {
    return l.r.value - l.r.usual;
}
fn overallOf(l: *const Line) f64 {
    return l.r.overall;
}
fn thin(l: *const Line) bool {
    return l.r.n < thin_games;
}

const WhoOpts = struct { px: champ.Px = .@"24", eager: bool = false, here: bool = false };

/// A champion's link: icon, name, and its role's icon where the list mixes roles
fn whoView(h: *H, c: champ.Champ, href: []const u8, r: ?Role, o: WhoOpts) N {
    return h.a(.{ .class = "who", .href = href, .aria_current = if (o.here) "true" else null }, .{
        champ.view(h, c, .{ .px = o.px, .named = false, .eager = o.eager }),
        h.span(.{}, .{c.name}),
        if (r) |x| role.view(h, x, .{}) else null,
    });
}

fn who(h: *H, l: *const Line) N {
    return whoView(h, .{ .name = l.r.name, .src = l.icon }, l.r.href, if (l.all) l.r.role else null, .{ .here = l.here });
}

/// A figure's 80% range: a rate's from its games; a gap's from its thinner side's games
/// (Row.n) as if both had that many, so at most this wide
fn rangeOf(k: Kind, v: f32, n: u32) f64 {
    return switch (k) {
        .rate => fmt.rangeAt(n, v),
        .gap => std.math.sqrt2 * fmt.rangeAt(n, 50),
        .gold => unreachable,
    };
}

fn winCell(h: *H, l: *const Line) N {
    return stat.view(h, .{ .value = l.r.value, .scale = .aggregate, .ref = l.r.usual, .range = rangeOf(.rate, l.r.value, l.r.n) });
}

fn vsCell(h: *H, l: *const Line) N {
    return delta.view(h, .{ .d = l.r.value - l.r.usual });
}

fn gamesCell(h: *H, l: *const Line) N {
    return h.span(.{}, .{phrase.num(h, .count, l.r.n)});
}

fn overallCell(h: *H, l: *const Line) N {
    return stat.view(h, .{ .value = l.r.overall, .range = fmt.rangeAt(l.r.games, l.r.overall) });
}

fn gapCell(h: *H, l: *const Line) N {
    return stat.view(h, .{ .value = l.r.value, .kind = .points, .scale = .aggregate, .ref = l.r.usual, .range = rangeOf(.gap, l.r.value, l.r.n) });
}
/// A champion's lead over many lanes: steps out from 0
const gold_cuts: [4]f32 = .{ 50, 150, 300, 500 };

fn goldView(h: *H, v: f32, n: u32) N {
    return h.span(.{ .class = "c-stat", .data_state = if (n < thin_games) "thin" else null, .style = h.vars(.{ .c = fmt.Step.of(v, gold_cuts) }) }, .{
        h.span(.{ .class = "v" }, .{stat.figure(h, .gold, v)}),
    });
}
fn goldCell(h: *H, l: *const Line) N {
    return goldView(h, l.r.value, l.r.n);
}

fn shortOf(l: *const Line) f64 {
    return l.r.sides[0];
}
fn longOf(l: *const Line) f64 {
    return l.r.sides[1];
}
fn shortCell(h: *H, l: *const Line) N {
    return h.span(.{}, .{phrase.num(h, .rate, l.r.sides[0])});
}
fn longCell(h: *H, l: *const Line) N {
    return h.span(.{}, .{phrase.num(h, .rate, l.r.sides[1])});
}
fn leanOf(l: *const Line) f64 {
    return switch (l.r.lean) {
        .early => -1,
        .none => 0,
        .late => 1,
    };
}
fn leanCell(h: *H, l: *const Line) N {
    return h.span(.{}, .{switch (l.r.lean) {
        .early => W.early,
        .late => W.late,
        .none => plain(""),
    }});
}

pub const RateTable = table.DataTable(Line, .{
    .title = W.title,
    .columns = &.{
        .{ .label = W.champion, .cell = who, .name = nameOf, .num = false },
        .{ .label = W.win, .cell = winCell, .sort = pulledOf, .answer = true, .tip = W.win_note },
        .{ .label = W.vs, .cell = vsCell, .sort = vsOf, .tip = W.vs_note },
        .{ .label = W.games, .cell = gamesCell, .sort = nF, .priority = 2, .tip = W.games_note },
        .{ .label = W.overall, .cell = overallCell, .sort = overallOf, .priority = 3, .tip = W.overall_note },
    },
    .default_sort = 1,
    .search = nameOf,
    .games = nOf,
    .numbered = true,
    .rare = thin,
    .rare_name = W.few,
});

pub const GapTable = table.DataTable(Line, .{
    .title = W.title,
    .columns = &.{
        .{ .label = W.champion, .cell = who, .name = nameOf, .num = false },
        .{ .label = W.gap, .cell = gapCell, .sort = pulledOf, .answer = true, .tip = W.gap_note },
        .{ .label = W.short, .cell = shortCell, .sort = shortOf, .priority = 2 },
        .{ .label = W.long, .cell = longCell, .sort = longOf, .priority = 2 },
        .{ .label = W.lean, .cell = leanCell, .sort = leanOf, .num = false, .tip = W.lean_note },
        .{ .label = W.games, .cell = gamesCell, .sort = nF, .priority = 3, .tip = W.games_note },
    },
    .default_sort = 1,
    .search = nameOf,
    .games = nOf,
    .numbered = true,
    .rare = thin,
    .rare_name = W.few,
});

pub const GoldTable = table.DataTable(Line, .{
    .title = W.title,
    .columns = &.{
        .{ .label = W.champion, .cell = who, .name = nameOf, .num = false },
        .{ .label = W.lead, .cell = goldCell, .sort = pulledOf, .answer = true, .tip = W.lead_note },
        .{ .label = W.lanes, .cell = gamesCell, .sort = nF, .priority = 2, .tip = W.lanes_note },
        .{ .label = W.overall, .cell = overallCell, .sort = overallOf, .priority = 3, .tip = W.overall_note },
    },
    .default_sort = 1,
    .search = nameOf,
    .games = nOf,
    .numbered = true,
    .rare = thin,
    .rare_name = W.few,
});

pub const Table = union(Kind) { rate: RateTable, gap: GapTable, gold: GoldTable };

pub const Ranking = struct {
    data: *const Data,
    table: Table,
    /// table's rows, writable
    lines: []Line = &.{},
    /// The root's data-bin (server side)
    bin: []const u8 = "",

    const P = @This();

    /// The table's lines, allocated: a copy marked (mark) needs its own
    pub fn init(a: std.mem.Allocator, d: *const Data) !P {
        const lines = try a.alloc(Line, d.rows.len);
        for (lines, d.rows) |*l, *r| l.* = .{
            .r = r,
            .icon = try std.fmt.allocPrint(a, champ.icon_fmt, .{ d.ddragon, r.key }),
            .all = d.role == null,
        };
        return .{ .data = d, .lines = lines, .table = switch (kindOf(d.stat)) {
            .rate => .{ .rate = .{ .rows = lines, .id = "rk" } },
            .gap => .{ .gap = .{ .rows = lines, .id = "rk" } },
            .gold => .{ .gold = .{ .rows = lines, .id = "rk" } },
        } };
    }

    /// Lights the row whose slug is `frag` (location.hash, "#" dropped) and opens the
    /// unsure rows when it is one of them; false when no row has it
    pub fn mark(p: *P, frag: []const u8) bool {
        for (p.lines) |*l| {
            if (frag.len == 0 or !std.mem.eql(u8, l.r.slug, frag)) continue;
            l.here = true;
            if (thin(l)) switch (p.table) {
                inline else => |*t| t.rare = true,
            };
            return true;
        }
        return false;
    }

    pub fn view(p: *P, h: *H) N {
        return h.div(.{ .class = "c-rank", .data_island = "ranking", .data_bin = if (p.bin.len > 0) p.bin else null }, .{
            if (p.data.rows.len == 0) h.p(.{ .class = "none" }, .{W.none}) else switch (p.table) {
                inline else => |*t| t.view(h),
            },
        });
    }
};

/// Under the page's heading: the sibling stats' switch (when there are several), the
/// roles', and what the figure counts
pub fn head(h: *H, stats: []const segmented.Item, roles: []const segmented.Item, lead: tree.Text) N {
    return h.div(.{ .class = "c-rankhead" }, .{
        h.div(.{ .class = "pick" }, .{
            if (stats.len > 1) segmented.view(h, .{ .s = .s, .label = W.stat }, stats) else null,
            segmented.view(h, .{ .s = .s, .label = W.role }, roles),
        }),
        h.p(.{}, .{lead}),
    });
}

pub const css =
    \\@layer components {
    \\  .c-rankhead { display: grid; gap: var(--sp-2); margin-bottom: var(--sp-3); }
    \\  .c-rankhead > .pick { display: flex; flex-wrap: wrap; gap: var(--sp-2) var(--sp-4); }
    \\  .c-rankhead > p { margin: 0; color: var(--muted); font-size: var(--fs-s); }
    \\  .c-rank .who, .c-rankidx .who { display: inline-flex; align-items: center; gap: var(--sp-2);
    \\    color: inherit; text-decoration: none; font-weight: var(--w-b); }
    \\  .c-rank .who:hover > span:not(.c-role), .c-rankidx .who:hover > span:not(.c-role) {
    \\    text-decoration: underline; }
    \\  .c-rank > .none { color: var(--muted); }
    \\  .c-rank tr:has(.who[aria-current]) > td { background: var(--accent-bg); }
    \\  .c-rankidx { display: grid; gap: var(--sp-3); }
    \\  .c-rankidx > .cards { display: grid; gap: var(--sp-3);
    \\    grid-template-columns: repeat(auto-fill, minmax(min(100%, 20rem), 1fr)); }
    \\  .c-rankidx > .cards > div { display: grid; }
    \\  .c-rankidx .c-card { display: flex; flex-direction: column; gap: var(--sp-2); }
    \\  .c-rankidx h2 { margin: 0; font-size: var(--fs-l); }
    \\  .c-rankidx h2 > a { color: inherit; }
    \\  .c-rankidx p { margin: 0; color: var(--muted); font-size: var(--fs-s); }
    \\  .c-rankidx ul { margin: 0; padding: 0; list-style: none; display: grid; gap: var(--sp-1); }
    \\  .c-rankidx li { display: flex; align-items: center; justify-content: space-between; gap: var(--sp-2); }
    \\  .c-rankidx .full { margin-top: auto; font-size: var(--fs-s); }
    \\}
    \\
;

pub fn demo(stat_: Stat, r: ?Role) Data {
    const rows = struct {
        const all = [_]Row{
            .{ .name = "Darius", .key = "Darius", .href = "#", .role = .top, .value = 78.1, .usual = 71.9, .pulled = 5.2, .n = 1240, .overall = 51.8 },
            .{ .name = "Garen", .key = "Garen", .href = "#", .role = .top, .value = 74.0, .usual = 71.9, .pulled = 1.6, .n = 860, .overall = 52.4 },
            .{ .name = "Ahri", .key = "Ahri", .href = "#", .role = .mid, .value = 70.2, .usual = 70.9, .pulled = -0.5, .n = 2210, .overall = 50.9 },
            .{ .name = "Kayle", .key = "Kayle", .href = "#", .role = .top, .value = 64.3, .usual = 71.9, .pulled = -5.9, .n = 410, .overall = 50.2 },
            .{ .name = "Zilean", .key = "Zilean", .href = "#", .role = .support, .value = 90.0, .usual = 70.1, .pulled = 1.1, .n = 20, .overall = 49.5 },
        };
    };
    return .{ .stat = stat_, .role = r, .ddragon = "16.21.1", .rows = &rows.all };
}

pub fn demoGap() Data {
    const rows = struct {
        const all = [_]Row{
            .{ .name = "Kayle", .key = "Kayle", .href = "#", .role = .top, .value = 9.1, .usual = 0.4, .pulled = 7.5, .n = 1310, .overall = 51.2, .sides = .{ 46.0, 55.1 }, .lean = .late },
            .{ .name = "Darius", .key = "Darius", .href = "#", .role = .top, .value = -4.2, .usual = 0.4, .pulled = -4.0, .n = 2950, .overall = 50.1, .sides = .{ 52.3, 48.1 }, .lean = .early },
            .{ .name = "Garen", .key = "Garen", .href = "#", .role = .top, .value = 0.8, .usual = 0.4, .pulled = 0.3, .n = 2400, .overall = 52.4, .sides = .{ 52.0, 52.8 } },
        };
    };
    return .{ .stat = .long_games, .role = .top, .ddragon = "16.21.1", .rows = &rows.all };
}

pub fn demoGold() Data {
    const rows = struct {
        const all = [_]Row{
            .{ .name = "Renekton", .key = "Renekton", .href = "#", .role = .top, .value = 412, .usual = 0, .pulled = 380, .n = 2210, .overall = 49.8 },
            .{ .name = "Garen", .key = "Garen", .href = "#", .role = .top, .value = 35, .usual = 0, .pulled = 30, .n = 2400, .overall = 52.4 },
            .{ .name = "Kayle", .key = "Kayle", .href = "#", .role = .top, .value = -455, .usual = 0, .pulled = -410, .n = 1310, .overall = 51.2 },
        };
    };
    return .{ .stat = .lane_gold, .role = .top, .ddragon = "16.21.1", .rows = &rows.all };
}

/// A gallery state: `d`'s table, its id unique per state and width
fn addTable(g: *Gallery, label: []const u8, d: Data, id: []const u8, rare: bool, fill: bool) void {
    const h = g.h;
    const dd = h.mem.create(Data) catch {
        h.oom = true;
        return;
    };
    dd.* = d;
    const p = h.mem.create(Ranking) catch {
        h.oom = true;
        return;
    };
    p.* = Ranking.init(h.mem, dd) catch {
        h.oom = true;
        return;
    };
    switch (p.table) {
        inline else => |*t| {
            t.rare = rare;
            t.id = h.fmt("{s}-{d}", .{ id, g.width }); // fmt-ok: gallery only
        },
    }
    if (fill) g.addFill(label, p.view(h)) else g.add(label, p.view(h));
}

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    addTable(g, "All: role icons, a thin row behind the chip", demo(.ahead, null), "rk0", false, true);
    addTable(g, "a role, the thin row shown and faded", demo(.ahead, .top), "rk1", true, true);
    addTable(g, "no rows", .{ .stat = .behind, .role = .jungle, .ddragon = "", .rows = &.{} }, "rke", false, false);
    addTable(g, "a gap: long minus short games, the lean beside it", demoGap(), "rkg", false, true);
    addTable(g, "gold: lane lead at 14", demoGold(), "rko", false, true);
    const stats = [_]segmented.Item{ .{ .label = plain("From ahead"), .selected = true, .href = "#" }, .{ .label = plain("From behind"), .href = "#" } };
    var roles: [1 + Role.all.len]segmented.Item = undefined;
    roles[0] = .{ .label = plain("All"), .href = "#" };
    for (Role.all, roles[1..]) |r, *x| x.* = .{ .label = r.label(), .selected = r == .top, .href = "#" };
    g.add("head", head(h, &stats, &roles, plain(spec(.ahead).lead)));
    const tops = struct {
        const rate = [_]Card.Top{
            .{ .name = "Darius", .src = "", .href = "#", .role = .top, .value = 78.1, .usual = 71.9, .n = 1240 },
            .{ .name = "Ahri", .src = "", .href = "#", .role = .mid, .value = 74.0, .usual = 70.9, .n = 2210 },
            .{ .name = "Garen", .src = "", .href = "#", .role = .top, .value = 74.0, .usual = 71.9, .n = 860 },
        };
        const gap = [_]Card.Top{
            .{ .name = "Kayle", .src = "", .href = "#", .role = .top, .value = 9.1, .usual = 0.4, .n = 1310 },
        };
        const pick = [_]Card.Top{
            .{ .name = "Azir", .src = "", .href = "#", .role = null, .value = 14.2, .usual = 6.1, .n = 820 },
        };
        const gold = [_]Card.Top{
            .{ .name = "Renekton", .src = "", .href = "#", .role = .top, .value = 412, .usual = 0, .n = 2210 },
        };
    };
    g.addFill("index: a card per stat, its top three", index(h, &.{
        .{ .stat = .ahead, .href = "#", .top = &tops.rate },
        .{ .stat = .behind, .href = "#", .top = &.{} },
        .{ .stat = .long_games, .href = "#", .top = &tops.gap },
        .{ .stat = .lane_gold, .href = "#", .top = &tops.gold },
        .{ .stat = null, .href = "#", .top = &tops.pick },
    }));
}
