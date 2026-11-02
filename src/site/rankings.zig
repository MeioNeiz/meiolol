//! Rankings (docs/plan/ui/rankings.md): /rankings/<stat>[/<role>], every champion ranked
//! by one stat (ui.ranking), each view. All: each champion in its main role. /rankings:
//! a card per stat with its top three

const std = @import("std");
const core = @import("core");
const ui = @import("ui");
const root = @import("root.zig");
const html = @import("html.zig");
const shell = @import("shell.zig");
const assets = @import("assets.zig");
const champion = @import("champion.zig");
const stats_ = @import("../stats.zig");
const tpl = html.tpl;

const Writer = std.Io.Writer;
const Site = root.Site;
const Champ = root.Champ;
const Role = core.Role;
const rk = ui.ranking;
const Counts = core.statsfile.Counts;

/// Every stat, All then each role, when the view has its data
pub fn paths(site: *const Site, list: *std.ArrayList(ui.urls.Page)) !void {
    if (any(site)) try list.append(site.arena, .rankings);
    for (std.enums.values(rk.Stat)) |s| {
        if (!has(site, s)) continue;
        try list.append(site.arena, .{ .ranking = .{ .stat = s } });
        for (Role.all) |r| try list.append(site.arena, .{ .ranking = .{ .stat = s, .role = champion.uiRole(r) } });
    }
}

pub fn any(site: *const Site) bool {
    for (std.enums.values(rk.Stat)) |s| if (has(site, s)) return true;
    return false;
}

fn has(site: *const Site, s: rk.Stat) bool {
    return switch (rk.kindOf(s)) {
        .rate => site.curves != null,
        .gap => site.trend != null,
    };
}

pub fn writePage(site: *const Site, w: *Writer, at: ui.urls.Ranking) !bool {
    if (!has(site, at.stat)) return false;
    const a = site.arena;
    const sp = rk.spec(at.stat);
    const r: ?Role = if (at.role) |x| root.coreRole(x) else null;
    const pg = try site.page(
        try a.print("{s}, {s} | meiolol", .{ sp.title, if (r) |x| root.roleName(x) else "all roles" }),
        try a.print("Every champion ranked: {s}", .{sp.lead}),
        .{ .ranking = at },
        .rankings,
    );
    try shell.open(w, pg);
    try tpl.renderPart(w, "<h1>{title} ", .{ .title = sp.title });
    try site.writeChip(w, site.regionDim(site.view.region), site.periodDim(site.view.period), .plat);
    try w.writeAll("</h1>\n");

    const d = try a.create(rk.Data);
    d.* = try data(site, at.stat, r);
    var p: rk.Ranking = try .init(a, d);
    p.bin = try bin(a, d.*);
    var tree: ui.Tree = .{};
    var h: ui.H = .init(a, &tree);
    const lead: ui.Text = .{ .s = if (r) |x| try std.mem.concat(a, u8, &.{ sp.lead, try usualText(site, at.stat, x) }) else sp.lead };
    tree.root = h.div(.{}, .{ try head(site, &h, at, r, lead), p.view(&h) });
    if (h.oom) return error.OutOfMemory;
    try ui.html.write(&tree, tree.root, w);
    try tpl.render(w, "\n<script src=\"{js}\" data-wasm=\"{wasm}\" defer></script>\n", .{
        .js = html.Link{ .path = assets.rankings_js.path },
        .wasm = assets.rankings_wasm.path,
    });
    try shell.close(w, pg);
    return true;
}

/// /rankings: each stat with data, its card's top from the All ranking
pub fn writeIndex(site: *const Site, w: *Writer) !bool {
    if (!any(site)) return false;
    const a = site.arena;
    const pg = try site.page(
        "Champion rankings | meiolol",
        "Every champion ranked by one stat at a time: wins from ahead, from behind, in long games.",
        .rankings,
        .rankings,
    );
    try shell.open(w, pg);
    try w.writeAll("<h1>Rankings ");
    try site.writeChip(w, site.regionDim(site.view.region), site.periodDim(site.view.period), .plat);
    try w.writeAll("</h1>\n");
    var cards: std.ArrayList(rk.Card) = .empty;
    for (std.enums.values(rk.Stat)) |s| {
        if (!has(site, s)) continue;
        const d = try data(site, s, null);
        var top: std.ArrayList(rk.Card.Top) = .empty;
        for (d.rows) |row| {
            if (row.n < rk.thin_games) continue;
            try top.append(a, .{ .name = row.name, .src = try a.print(ui.champ.icon_fmt, .{ site.ddragon_version, row.key }), .href = row.href, .role = row.role, .value = row.value, .usual = row.usual, .n = row.n });
            if (top.items.len == rk.card_top) break;
        }
        try cards.append(a, .{ .stat = s, .href = try site.href(.{ .ranking = .{ .stat = s } }), .top = top.items });
    }
    var tree: ui.Tree = .{};
    var h: ui.H = .init(a, &tree);
    tree.root = rk.index(&h, cards.items);
    if (h.oom) return error.OutOfMemory;
    try ui.html.write(&tree, tree.root, w);
    try shell.close(w, pg);
    return true;
}

/// ui.ranking.head: the sibling stats' switch and the roles'
fn head(site: *const Site, h: *ui.H, at: ui.urls.Ranking, r: ?Role, lead: ui.Text) !ui.N {
    const a = site.arena;
    const sibs = rk.siblingsOf(at.stat);
    const stats = try a.alloc(ui.segmented.Item, sibs.len);
    for (stats, sibs) |*s, x| s.* = .{
        .label = .{ .s = rk.spec(x).short },
        .selected = x == at.stat,
        .href = try site.href(.{ .ranking = .{ .stat = x, .role = at.role } }),
    };
    const roles = try a.alloc(ui.segmented.Item, 1 + Role.all.len);
    roles[0] = .{ .label = ui.plain("All"), .selected = r == null, .href = try site.href(.{ .ranking = .{ .stat = at.stat } }) };
    for (Role.all, roles[1..]) |x, *s| s.* = .{
        .label = champion.uiRole(x).label(),
        .selected = r == x,
        .href = try site.href(.{ .ranking = .{ .stat = at.stat, .role = champion.uiRole(x) } }),
    };
    return rk.head(h, stats, roles, lead);
}

/// Which of the comeback counts a rate stat reads: [minute][bucket]
fn cell(s: rk.Stat) struct { usize, usize } {
    return switch (s) {
        .ahead => .{ 1, 4 },
        .behind => .{ 1, 0 },
        .long_games => unreachable,
    };
}

/// A stat's counts: a rate's one spot (second empty), or a gap's short then long games
const Pair = [2]Counts;

fn add(x: *Counts, games: u32, wins: u32) void {
    x.games += games;
    x.wins += wins;
}

/// Short games: under 25 minutes (stats.length_edges' first two buckets); long: 35+
fn lengthPair(t: *const stats_.Trend, r: Role, c: usize) Pair {
    var out: Pair = @splat(.{ .games = 0, .wins = 0 });
    for (0..stats_.length_buckets) |b| {
        const k = t.length(r, c, b);
        if (b < 2) add(&out[0], k.games, k.wins);
        if (b == stats_.length_buckets - 1) add(&out[1], k.games, k.wins);
    }
    return out;
}

fn countsOf(site: *const Site, s: rk.Stat, ch: Champ, r: Role) !?Pair {
    switch (rk.kindOf(s)) {
        .rate => {
            const cb = try champion.comebackSums(site, ch, r) orelse return null;
            const at = cell(s);
            const k = cb.at[at[0]][at[1]];
            return .{ .{ .games = k.games, .wins = k.wins }, .{ .games = 0, .wins = 0 } };
        },
        .gap => return lengthPair(&(site.trend orelse return null), r, ch.c),
    }
}

/// Every lane or game in the role, as countsOf
fn roleCounts(site: *const Site, s: rk.Stat, r: Role) ?Pair {
    switch (rk.kindOf(s)) {
        .rate => {
            const c = &(site.curves orelse return null);
            const base = c.baseline(r, .all) orelse return null;
            const at = cell(s);
            const k = base.comeback(std.enums.values(core.curvesfile.Comeback)[at[0]], at[1]);
            return .{ .{ .games = k.games, .wins = k.wins }, .{ .games = 0, .wins = 0 } };
        },
        .gap => {
            const t = &(site.trend orelse return null);
            var out: Pair = @splat(.{ .games = 0, .wins = 0 });
            for (site.champs) |ch| {
                const p = lengthPair(t, r, ch.c);
                for (&out, p) |*o, x| add(o, x.games, x.wins);
            }
            return out;
        },
    }
}

/// The figure from a pair: a rate (%) or a gap (points); null without games
fn figure(s: rk.Stat, p: Pair) ?f32 {
    return switch (rk.kindOf(s)) {
        .rate => if (p[0].games == 0) null else rate(p[0].wins, p[0].games),
        .gap => if (p[0].games == 0 or p[1].games == 0) null else rate(p[1].wins, p[1].games) - rate(p[0].wins, p[0].games),
    };
}

fn usualOf(site: *const Site, s: rk.Stat, r: Role) ?f32 {
    return figure(s, roleCounts(site, s, r) orelse return null);
}

/// The role's figure in the lead line
fn usualText(site: *const Site, s: rk.Stat, r: Role) ![]const u8 {
    const u = usualOf(site, s, r) orelse return "";
    return switch (rk.kindOf(s)) {
        .rate => site.arena.print(" {s}: {d:.1}%.", .{ root.roleName(r), u }),
        .gap => site.arena.print(" {s}: {s}{d:.1} points.", .{ root.roleName(r), if (u >= 0) "+" else "\u{2212}", @abs(u) }),
    };
}

fn rate(wins: u32, games: u32) f32 {
    return @floatCast(100 * @as(f64, @floatFromInt(wins)) / @as(f64, @floatFromInt(games)));
}

/// Per role, every champion that plays it (on All: its main role) with games for the
/// stat; pulled toward the role by k from how much champions differ there
pub fn data(site: *const Site, s: rk.Stat, only: ?Role) !rk.Data {
    const a = site.arena;
    const gap = rk.kindOf(s) == .gap;
    var rows: std.ArrayList(rk.Row) = .empty;
    for (Role.all) |r| {
        if (only) |x| if (x != r) continue;
        const usual = usualOf(site, s, r) orelse continue;
        var cells: [2]std.ArrayList(Counts) = .{ .empty, .empty };
        var chs: std.ArrayList(Champ) = .empty;
        for (site.champs) |ch| {
            const in = if (only != null) champion.plays(site, ch, r) else root.mainRole(site, ch) == r;
            if (!in) continue;
            const p = try countsOf(site, s, ch, r) orelse continue;
            if (figure(s, p) == null) continue;
            for (&cells, p) |*c, k| try c.append(a, k);
            try chs.append(a, ch);
        }
        const priors: [2]core.banimpact.Prior = .{ .ofCounts(cells[0].items), .ofCounts(cells[1].items) };
        for (cells[0].items, cells[1].items, chs.items) |k0, k1, ch| {
            const cr = site.stats.champRole(r, ch.c);
            const e0 = priors[0].edge(k0.wins, k0.games);
            const lean_: rk.Lean = if (!gap) .none else if (site.lean) |l| if (l.get(ch.id, r)) |x| switch (x.lean()) {
                .early => .early,
                .late => .late,
                .none => .none,
            } else .none else .none;
            try rows.append(a, .{
                .name = ch.name,
                .key = ch.key,
                .href = try site.href(.{ .champion = .{ .slug = ch.slug, .role = champion.uiRole(r) } }),
                .role = champion.uiRole(r),
                .value = figure(s, .{ k0, k1 }).?,
                .usual = usual,
                .pulled = @floatCast(100 * if (gap) priors[1].edge(k1.wins, k1.games) - e0 else e0),
                .n = if (gap) @min(k0.games, k1.games) else k0.games,
                .overall = if (cr.games == 0) 0 else rate(cr.wins, cr.games),
                .games = cr.games,
                .sides = if (gap) .{ rate(k0.wins, k0.games), rate(k1.wins, k1.games) } else .{ 0, 0 },
                .lean = lean_,
            });
        }
    }
    std.mem.sort(rk.Row, rows.items, {}, struct {
        fn f(_: void, x: rk.Row, y: rk.Row) bool {
            return x.pulled > y.pulled;
        }
    }.f);
    return .{ .stat = s, .role = if (only) |x| champion.uiRole(x) else null, .ddragon = site.ddragon_version, .rows = rows.items };
}

/// `v` as ui.data, base64: the island root's data-bin
fn bin(a: std.mem.Allocator, v: rk.Data) ![]const u8 {
    var raw: std.ArrayList(u8) = .empty;
    try ui.data.encode(a, rk.Data, v, &raw);
    const e = std.base64.standard.Encoder;
    const out = try a.alloc(u8, e.calcSize(raw.items.len));
    return e.encode(out, raw.items);
}
