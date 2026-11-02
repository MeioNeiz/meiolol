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
const pickup = @import("pickup.zig");
const matchup = @import("matchup.zig");
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
        .rate, .gold => site.curves != null,
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
        "Every champion ranked by one stat at a time: wins from ahead, from behind, in long games, lane gold at 14, how hard to pick up.",
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
    try cards.append(a, try pickupCard(site));
    var tree: ui.Tree = .{};
    var h: ui.H = .init(a, &tree);
    tree.root = rk.index(&h, cards.items);
    if (h.oom) return error.OutOfMemory;
    try ui.html.write(&tree, tree.root, w);
    try shell.close(w, pg);
    return true;
}

/// /pickup's top: practised minus new players' win rate per champion, sorted pulled
/// toward the average gap, shown raw against it
fn pickupCard(site: *const Site) !rk.Card {
    const a = site.arena;
    const l = &site.learning;
    var top: std.ArrayList(rk.Card.Top) = .empty;
    for (try pickup.order(a, l, &site.stats, null)) |c| {
        const ch = matchup.champ(site, c.id) orelse continue;
        const g = c.gap.?;
        try top.append(a, .{ .name = ch.name, .src = try site.icon(ch), .href = try site.champHref(ch), .role = null, .value = @floatCast(g.pp), .usual = @floatCast(l.mean_pp), .n = @min(g.new.games, g.practised.games) });
        if (top.items.len == rk.card_top) break;
    }
    return .{ .stat = null, .href = try site.href(.{ .pickup = null }), .top = top.items };
}

const n_stats = std.enums.values(rk.Stat).len;
const unranked = std.math.maxInt(u16);

/// Each champion's place in each stat's ranking of each role, as the page numbers its
/// rows with the unsure ones hidden: by stats-file index, 0 under the games floor
pub const Places = struct {
    at: [n_stats][Role.all.len][]u16,
    of: [n_stats][Role.all.len]u16,
};

pub fn places(site: *const Site) !Places {
    const a = site.arena;
    var by_key: std.StringHashMapUnmanaged(usize) = .empty;
    var len: usize = 0;
    for (site.champs) |ch| {
        try by_key.put(a, ch.key, ch.c);
        len = @max(len, ch.c + 1);
    }
    var out: Places = undefined;
    for (std.enums.values(rk.Stat), &out.at, &out.of) |s, *at_s, *of_s| for (Role.all, at_s, of_s) |r, *at, *of| {
        at.* = try a.alloc(u16, len);
        @memset(at.*, unranked);
        of.* = 0;
        if (!has(site, s)) continue;
        for ((try data(site, s, r)).rows) |row| {
            const c = by_key.get(row.key) orelse continue;
            if (row.n < rk.thin_games) {
                at.*[c] = 0;
                continue;
            }
            of.* += 1;
            at.*[c] = of.*;
        }
    };
    return out;
}

/// ch's places in r for its page, each linking its ranking with ch in the fragment
pub fn placesOf(site: *const Site, ch: Champ, r: Role) !ui.champpage.Places {
    const p = &(site.places orelse return .{});
    var out: ui.champpage.Places = .{};
    inline for (comptime std.enums.values(rk.Stat), 0..) |s, si| if (comptime @hasField(ui.champpage.Places, @tagName(s))) {
        const ri = std.mem.findScalar(Role, &Role.all, r).?;
        const at = p.at[si][ri];
        if (ch.c < at.len and at[ch.c] != unranked) @field(out, @tagName(s)) = .{
            .n = at[ch.c],
            .of = p.of[si][ri],
            .href = try site.arena.print("{s}#{s}", .{ try site.href(.{ .ranking = .{ .stat = s, .role = champion.uiRole(r) } }), ch.slug }),
        };
    };
    return out;
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
        .long_games, .lane_gold => unreachable,
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
        .gold => unreachable,
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
        .gold => unreachable,
    }
}

/// The figure from a pair: a rate (%) or a gap (points); null without games
fn figure(s: rk.Stat, p: Pair) ?f32 {
    return switch (rk.kindOf(s)) {
        .rate => if (p[0].games == 0) null else rate(p[0].wins, p[0].games),
        .gap => if (p[0].games == 0 or p[1].games == 0) null else rate(p[1].wins, p[1].games) - rate(p[0].wins, p[0].games),
        .gold => unreachable,
    };
}

fn usualOf(site: *const Site, s: rk.Stat, r: Role) ?f32 {
    return figure(s, roleCounts(site, s, r) orelse return null);
}

/// The role's figure in the lead line; none for a gap or gold, ~0 by construction (each
/// game has a winner in the role, long or short; each lane a lead and a deficit)
fn usualText(site: *const Site, s: rk.Stat, r: Role) ![]const u8 {
    if (rk.kindOf(s) != .rate) return "";
    const u = usualOf(site, s, r) orelse return "";
    return site.arena.print(" {s}: {d:.1}%.", .{ root.roleName(r), u });
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
        if (rk.kindOf(s) == .gold) {
            try goldRows(site, r, only != null, &rows);
            continue;
        }
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
                .slug = ch.slug,
                .href = try site.href(.{ .champion = .{ .slug = ch.slug, .role = champion.uiRole(r) } }),
                .role = champion.uiRole(r),
                .value = figure(s, .{ k0, k1 }).?,
                .usual = if (gap) 0 else usual,
                .pulled = @floatCast(100 * if (gap) priors[1].edge(k1.wins, k1.games) - e0 else e0),
                .n = if (gap) @min(k0.games, k1.games) else k0.games,
                .overall = if (cr.games == 0) 0 else rate(cr.wins, cr.games),
                .games = cr.games,
                .sides = if (gap) .{ rate(k0.wins, k0.games), rate(k1.wins, k1.games) } else .{ 0, 0 },
                .lean = lean_,
            });
        }
    }
    sortPulled(rows.items);
    return .{ .stat = s, .role = if (only) |x| champion.uiRole(x) else null, .ddragon = site.ddragon_version, .rows = rows.items };
}

fn sortPulled(rows: []rk.Row) void {
    std.mem.sort(rk.Row, rows, {}, struct {
        fn f(_: void, x: rk.Row, y: rk.Row) bool {
            return x.pulled > y.pulled;
        }
    }.f);
}

/// Lane gold at 14 in r, every champion that plays it (on All: its main role), the lead
/// pulled toward 0 by its standard error against how much the role's champions differ
/// (tau2/(tau2 + se2)); se from the role's spread of leads at 14 over the lanes behind it
fn goldRows(site: *const Site, r: Role, plays: bool, rows: *std.ArrayList(rk.Row)) !void {
    const a = site.arena;
    const c = &(site.curves orelse return);
    const base = c.baseline(r, .all) orelse return;
    const at = core.curvesfile.lane_minute - 1;
    if (at >= base.minutes()) return;
    const q = base.minute(at).gold;
    // A normal's interquartile range is 1.349 sd
    const sd = @as(f64, @floatFromInt(@as(i32, q.p75) - q.p25)) / 1.349;
    var leads: std.ArrayList(struct { Champ, champion.LaneGold }) = .empty;
    for (site.champs) |ch| {
        const in = if (plays) champion.plays(site, ch, r) else root.mainRole(site, ch) == r;
        if (!in) continue;
        const g = try champion.laneGold(site, ch, r, .all) orelse continue;
        try leads.append(a, .{ ch, g });
    }
    if (leads.items.len == 0) return;
    var mean: f64 = 0;
    var se2: f64 = 0;
    for (leads.items) |x| {
        mean += x[1].mean;
        se2 += sd * sd / @as(f64, @floatFromInt(x[1].lanes));
    }
    const k: f64 = @floatFromInt(leads.items.len);
    mean /= k;
    se2 /= k;
    var spread: f64 = 0;
    for (leads.items) |x| spread += (x[1].mean - mean) * (x[1].mean - mean);
    // Floored: with few champions the spread can read under the noise
    const tau2 = @max(spread / k - se2, 25 * 25);
    for (leads.items) |x| {
        const ch, const g = x;
        const se_2 = sd * sd / @as(f64, @floatFromInt(g.lanes));
        const cr = site.stats.champRole(r, ch.c);
        try rows.append(a, .{
            .name = ch.name,
            .key = ch.key,
            .slug = ch.slug,
            .href = try site.href(.{ .champion = .{ .slug = ch.slug, .role = champion.uiRole(r) } }),
            .role = champion.uiRole(r),
            .value = @floatCast(g.mean),
            .usual = 0,
            .pulled = @floatCast(g.mean * tau2 / (tau2 + se_2)),
            .n = g.lanes,
            .overall = if (cr.games == 0) 0 else rate(cr.wins, cr.games),
            .games = cr.games,
        });
    }
}

/// `v` as ui.data, base64: the island root's data-bin
fn bin(a: std.mem.Allocator, v: rk.Data) ![]const u8 {
    var raw: std.ArrayList(u8) = .empty;
    try ui.data.encode(a, rk.Data, v, &raw);
    const e = std.base64.standard.Encoder;
    const out = try a.alloc(u8, e.calcSize(raw.items.len));
    return e.encode(out, raw.items);
}
