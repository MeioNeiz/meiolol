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
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "StatRanking";
pub const scope = .{ ".c-rank", ".c-rankhead" };

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
};

pub fn spec(s: Stat) Spec {
    return switch (s) {
        .ahead => .{ .title = "Wins from ahead", .short = "From ahead", .lead = "Win rate in games where the champion was 1,500+ gold ahead of its lane opponent at 15 minutes." },
        .behind => .{ .title = "Wins from behind", .short = "From behind", .lead = "Win rate in games where the champion was 1,500+ gold behind its lane opponent at 15 minutes." },
    };
}

/// Stats shown as one page with a switch, in its order
pub const siblings = [_][]const Stat{&.{ .ahead, .behind }};

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
    /// The figure (a win rate, %) and the role's in the same spot
    value: f32,
    usual: f32,
    /// value - usual pulled toward 0 by how few games it has: the sort
    pulled: f32,
    /// Games behind the figure
    n: u32,
    /// The champion's win rate over all its games in the role
    overall: f32,
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
    pub const none = plain("More data needed: no champion has games in this spot yet.");
};

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
    return h.span(.{}, .{phrase.num(h, .rate, l.r.overall)});
}

pub const Table = table.DataTable(Line, .{
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
        return .{ .data = d, .table = .{ .rows = lines, .id = "rk" } };
    }

    pub fn view(p: *P, h: *H) N {
        return h.div(.{ .class = "c-rank", .data_island = "ranking", .data_bin = if (p.bin.len > 0) p.bin else null }, .{
            if (p.data.rows.len == 0) h.p(.{ .class = "none" }, .{W.none}) else p.table.view(h),
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
        p.table.rare = s[2];
        p.table.id = h.fmt("rk{d}-{d}", .{ k, g.width }); // fmt-ok: gallery only
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
    const stats = [_]segmented.Item{ .{ .label = plain("From ahead"), .selected = true, .href = "#" }, .{ .label = plain("From behind"), .href = "#" } };
    var roles: [1 + Role.all.len]segmented.Item = undefined;
    roles[0] = .{ .label = plain("All"), .href = "#" };
    for (Role.all, roles[1..]) |r, *x| x.* = .{ .label = r.label(), .selected = r == .top, .href = "#" };
    g.add("head", head(h, &stats, &roles, plain(spec(.ahead).lead)));
}
