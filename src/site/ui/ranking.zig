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
        .ahead => .{ .title = "Wins from ahead", .short = "From ahead", .lead = "Win rate in games where the champion was 1,500+ gold ahead of its lane opponent at 15 minutes.", .about = "Win rate when 1,500+ gold ahead of the lane opponent at 15 minutes: who turns a lead into a win." },
        .behind => .{ .title = "Wins from behind", .short = "From behind", .lead = "Win rate in games where the champion was 1,500+ gold behind its lane opponent at 15 minutes.", .about = "Win rate when 1,500+ gold behind the lane opponent at 15 minutes: who still wins from a bad lane." },
        .long_games => .{ .title = "Wins in long games", .short = "Long games", .lead = "Win rate in games of 35+ minutes minus in games under 25, in points: who wins more of its long games. Stomps end early, so this is how its games go, not a power curve.", .about = "Win rate in 35+ minute games minus under 25: who wins more of its long games." },
    };
}

/// What a stat's figure is: a win rate in one spot, or a gap between two win rates
pub const Kind = enum { rate, gap };

pub fn kindOf(s: Stat) Kind {
    return switch (s) {
        .ahead, .behind => .rate,
        .long_games => .gap,
    };
}

/// lean.tsv's (champfacts.Lean)
pub const Lean = enum { early, late, none };

/// Stats shown as one page with a switch, in its order
pub const siblings = [_][]const Stat{ &.{ .ahead, .behind }, &.{.long_games} };

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
    href: []const u8,
    role: Role,
    /// The figure (a win rate, %; a gap, points) and the role's
    value: f32,
    usual: f32,
    /// value - usual pulled toward 0 by how few games it has: the sort
    pulled: f32,
    /// Games behind the figure (a gap: its thinner side's)
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
    pub const lean_note = plain("Early or late from gold at 14 and wins from an even game at 20, every region. Blank: neither is clear.");
    pub const early = plain("Early");
    pub const late = plain("Late");
    pub const none = plain("More data needed: no champion has games in this spot yet.");
    pub const full = plain("Every champion ›");
    pub const index_lead = plain("Every champion ranked by one stat, per role. Each card's top three come from all roles, each champion in its main role, with 100+ games behind the figure.");
};

/// A stat's card in the index (/rankings): its top champions over every role, each in
/// its main role, solid rows only
pub const Card = struct {
    stat: Stat,
    href: []const u8,
    top: []const Top,

    pub const Top = struct {
        name: []const u8,
        src: []const u8,
        href: []const u8,
        role: Role,
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
        const sp = spec(c.stat);
        var rows = h.list();
        for (c.top, 0..) |t, k| rows.add(h.li(.{ .key = k }, .{
            h.a(.{ .class = "who", .href = t.href }, .{
                champ.view(h, .{ .name = t.name, .src = t.src }, .{ .px = .@"32", .named = false, .eager = true }),
                h.span(.{}, .{t.name}),
                role.view(h, t.role, .{}),
            }),
            stat.view(h, .{ .value = t.value, .kind = if (kindOf(c.stat) == .gap) .points else .rate, .scale = .aggregate, .ref = t.usual, .games = t.n }),
        }));
        kids.add(h.div(.{ .key = i }, .{card.view(h, .{}, &.{
            h.h2(.{}, .{h.a(.{ .href = c.href }, .{sp.title})}),
            h.p(.{}, .{sp.about}),
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

fn who(h: *H, l: *const Line) N {
    return h.a(.{ .class = "who", .href = l.r.href }, .{
        champ.view(h, .{ .name = l.r.name, .src = l.icon }, .{ .named = false }),
        h.span(.{}, .{l.r.name}),
        if (l.all) role.view(h, l.r.role, .{}) else null,
    });
}

fn winCell(h: *H, l: *const Line) N {
    return stat.view(h, .{ .value = l.r.value, .scale = .aggregate, .ref = l.r.usual, .games = l.r.n });
}

fn vsCell(h: *H, l: *const Line) N {
    return delta.view(h, .{ .d = l.r.value - l.r.usual });
}

fn gamesCell(h: *H, l: *const Line) N {
    return h.span(.{}, .{phrase.num(h, .count, l.r.n)});
}

fn overallCell(h: *H, l: *const Line) N {
    return stat.view(h, .{ .value = l.r.overall, .games = l.r.games });
}

fn gapCell(h: *H, l: *const Line) N {
    return stat.view(h, .{ .value = l.r.value, .kind = .points, .scale = .aggregate, .ref = l.r.usual, .games = l.r.n });
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

pub const Table = union(Kind) { rate: RateTable, gap: GapTable };

pub const Ranking = struct {
    data: *const Data,
    table: Table,
    /// The root's data-bin (server side)
    bin: []const u8 = "",

    const P = @This();

    /// The table's lines, allocated: the server's and the island's copies share them
    pub fn init(a: std.mem.Allocator, d: *const Data) !P {
        const lines = try a.alloc(Line, d.rows.len);
        for (lines, d.rows) |*l, *r| l.* = .{
            .r = r,
            .icon = try std.fmt.allocPrint(a, champ.icon_fmt, .{ d.ddragon, r.key }),
            .all = d.role == null,
        };
        return .{ .data = d, .table = switch (kindOf(d.stat)) {
            .rate => .{ .rate = .{ .rows = lines, .id = "rk" } },
            .gap => .{ .gap = .{ .rows = lines, .id = "rk" } },
        } };
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
    \\  .c-rank .who { display: inline-flex; align-items: center; gap: var(--sp-2); color: inherit;
    \\    text-decoration: none; font-weight: var(--w-b); }
    \\  .c-rank .who:hover > span:not(.c-role) { text-decoration: underline; }
    \\  .c-rank > .none { color: var(--muted); }
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
    \\  .c-rankidx .who { display: inline-flex; align-items: center; gap: var(--sp-2); color: inherit;
    \\    text-decoration: none; font-weight: var(--w-b); }
    \\  .c-rankidx .who:hover > span:not(.c-role) { text-decoration: underline; }
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

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const states = [_]struct { []const u8, ?Role, bool }{
        .{ "All: role icons, a thin row behind the chip", null, false },
        .{ "a role, the thin row shown and faded", .top, true },
    };
    for (states, 0..) |s, k| {
        const d = h.mem.create(Data) catch {
            h.oom = true;
            return;
        };
        d.* = demo(.ahead, s[1]);
        const p = h.mem.create(Ranking) catch {
            h.oom = true;
            return;
        };
        p.* = Ranking.init(h.mem, d) catch {
            h.oom = true;
            return;
        };
        p.table.rate.rare = s[2];
        p.table.rate.id = h.fmt("rk{d}-{d}", .{ k, g.width }); // fmt-ok: gallery only
        g.addFill(s[0], p.view(h));
    }
    const empty = h.mem.create(Data) catch {
        h.oom = true;
        return;
    };
    empty.* = .{ .stat = .behind, .role = .jungle, .ddragon = "", .rows = &.{} };
    const p = h.mem.create(Ranking) catch {
        h.oom = true;
        return;
    };
    p.* = Ranking.init(h.mem, empty) catch {
        h.oom = true;
        return;
    };
    g.add("no rows", p.view(h));
    const gd = h.mem.create(Data) catch {
        h.oom = true;
        return;
    };
    gd.* = demoGap();
    const gp = h.mem.create(Ranking) catch {
        h.oom = true;
        return;
    };
    gp.* = Ranking.init(h.mem, gd) catch {
        h.oom = true;
        return;
    };
    gp.table.gap.id = h.fmt("rkg-{d}", .{g.width}); // fmt-ok: gallery only
    g.addFill("a gap: long minus short games, the lean beside it", gp.view(h));
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
    };
    g.addFill("index: a card per stat, its top three", index(h, &.{
        .{ .stat = .ahead, .href = "#", .top = &tops.rate },
        .{ .stat = .behind, .href = "#", .top = &.{} },
        .{ .stat = .long_games, .href = "#", .top = &tops.gap },
    }));
}
