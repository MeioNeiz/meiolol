//! Lane matchup pages: how a lane unfolds minute by minute (core/curvesfile.zig). Every
//! chart carries tier, patch, n and spread; under thin_games it is greyed out as "more
//! data needed" (docs/concept.md). Facts and numbers only, no advice.

const std = @import("std");
const core = @import("core");
const root = @import("root.zig");
const html = @import("html.zig");
const text = @import("text.zig");
const champion = @import("champion.zig");
const stats = @import("../stats.zig");
const builds = @import("builds.zig");
const buildblock = @import("buildblock.zig");
const assets = @import("assets.zig");
const ui = @import("ui");
const mp = ui.matchpage;
const cp = ui.champpage;

const Writer = std.Io.Writer;
const Role = core.Role;
const curvesfile = core.curvesfile;
const Curves = curvesfile.Curves;
const View = curvesfile.View;
const Bracket = curvesfile.Bracket;
const Site = root.Site;
const Champ = root.Champ;
const tpl = html.tpl;
const plural = text.plural;
const percent = text.percent;

/// Below this many games a curve is greyed out as "more data needed"
pub const thin_games = 200;
/// Minutes with fewer games still going are not drawn
const min_minute_games = 10;
/// Experienced-only curves with fewer games are not offered
const min_experienced = 10;

/// A thinner matchup (greyed out anyway) draws minutes while all its games are going
fn minuteFloor(v: View) u32 {
    return @max(1, @min(min_minute_games, v.games()));
}

/// The curves' games for running text: "last 30 days" or "patch 16.19"
fn period(a: std.mem.Allocator, curves: *const Curves) ![]const u8 {
    const label = curves.patch();
    if (label.len > 0 and std.ascii.isDigit(label[0])) return a.print("patch {s}", .{label});
    return label;
}

/// period in a page's scope line: a 30-day file's with the patches its view's 30 days
/// span ("last 30 days, patches 16.19 to 16.21"), as the footer
fn scope(site: *const Site, curves: *const Curves) ![]const u8 {
    const label = curves.patch();
    if (label.len > 0 and std.ascii.isDigit(label[0])) return site.arena.print("patch {s}", .{label});
    return if (site.view.period == .days30) site.when else label;
}

/// From x's side: x's gold, wins and timings first
pub fn page(r: Role, x: Champ, y: Champ) ui.urls.Page {
    return .{ .matchup = .{ .role = champion.uiRole(r), .a = x.slug, .b = y.slug } };
}

/// A matchup's page curve: all ranks, all games. The file has one per bracket and
/// experience (and role baselines, champion 0) for each pair
pub fn isPage(h: *const curvesfile.Header) bool {
    return h.bracket == @backingInt(Bracket.all) and h.experience == @backingInt(curvesfile.Experience.any);
}

/// Two pages per lane matchup with an all-ranks curve of `min_games` or more, one from
/// each champion's side
pub fn paths(site: *const Site, curves: *const Curves, list: *std.ArrayList(ui.urls.Page), min_games: u32) !void {
    for (curves.curves) |c| {
        const h = c.header;
        if (!isPage(h) or h.games < min_games) continue;
        const x = champ(site, h.a) orelse continue;
        const y = champ(site, h.b) orelse continue;
        const r: Role = @fromBackingInt(@intCast(h.role));
        try list.append(site.arena, page(r, x, y));
        try list.append(site.arena, page(r, y, x));
    }
}

/// /matchups/<role>/<a>-vs-<b>; false for no such page
pub fn route(site: *const Site, w: *Writer, curves: *const Curves, m: ui.urls.Matchup) !bool {
    const r = root.coreRole(m.role);
    const x = site.champBySlug(m.a) orelse return false;
    const y = site.champBySlug(m.b) orelse return false;
    if (x.id == y.id) return false;
    if (curves.get(r, .all, x.id, y.id) == null) return false;
    try writePage(site, w, curves, r, x, y);
    return true;
}

pub fn champ(site: *const Site, id: u32) ?Champ {
    const c = site.stats.index(id) orelse return null;
    return site.champs[site.by_c[c] orelse return null];
}

/// Under thin_games games, or when most of the estimate is the champions' baseline
/// rather than the matchup's own games (View.own), a curve is greyed out
pub fn thin(v: View) bool {
    return v.games() < thin_games or v.own() < 0.5;
}

/// One way of counting a matchup's games on its page: all games, or only those where
/// one side is experienced on their champion; from x's side either way
const Variant = struct {
    v: View,
    /// CSS class suffix and radio value
    key: []const u8,
    label: []const u8,
};

fn variants(a: std.mem.Allocator, curves: *const Curves, r: Role, x: Champ, y: Champ) ![]const Variant {
    var list: std.ArrayList(Variant) = .empty;
    try list.append(a, .{ .v = curves.get(r, .all, x.id, y.id).?, .key = "any", .label = "All games" });
    const who = [_]struct { Champ, Champ, []const u8 }{ .{ x, y, "x" }, .{ y, x, "y" } };
    for (who) |s| {
        const v = curves.getExperienced(r, .all, s[0].id, s[1].id) orelse continue;
        if (v.games() < min_experienced) continue;
        try list.append(a, .{
            .v = if (s[0].id == x.id) v else .{ .curve = v.curve, .flipped = !v.flipped },
            .key = s[2],
            .label = try a.print("{s} {d}k+ mastery", .{ s[0].name, curvesfile.experienced_points / 1000 }),
        });
    }
    return list.items;
}

/// ui.matchpage's three islands, each with its data inline (data-bin): pages are rendered
/// on request, so there are no data files to fetch
fn writePage(site: *const Site, w: *Writer, curves: *const Curves, r: Role, x: Champ, y: Champ) !void {
    const a = site.arena;
    const v = curves.get(r, .all, x.id, y.id).?;
    const lane = root.roleName(r);
    const when = try period(a, curves);
    const title = try a.print("{s} vs {s}, {s} lane curves, {s} | meiolol", .{
        x.name, y.name, lane, when,
    });
    const desc = try a.print("How {s} against {s} in {s} lane unfolds minute by minute: gold, experience and CS difference, kills, level 6 and first item timing.", .{
        x.name, y.name, lane,
    });
    var p = try site.page(title, desc, page(r, x, y), .matchups);
    p.index = v.games() >= site.opts.index_min_games;
    var views: [html.View.count][]const u8 = undefined;
    for (site.view_curves, &views, p.counterparts.?) |*vc, *href, there| {
        const has = if (vc.*) |*o| o.get(r, .all, x.id, y.id) != null else false;
        href.* = if (has) there else "";
    }
    // The head's view links replace the subbar's switches
    p.counterparts = null;
    try html.head(w, p);

    const head_data = try a.create(mp.HeadData);
    head_data.* = try headData(site, curves, r, x, y, views);
    var head: mp.Head = try .init(a, head_data);
    head.bin = try bin(a, mp.HeadData, head_data.*);

    // A pair too thin for its own build gets x's usual one: the build is what the page is
    // read for, before the lane
    const build_data: ?*cp.BuildData = if (builds.forVs(site, r, x, y)) |b| blk: {
        const d = try a.create(cp.BuildData);
        const roles = try a.alloc(cp.BuildRole, 1);
        roles[0] = .{ .role = champion.uiRole(r), .build = try buildblock.dataVs(a, b.f, b.b, x.name, b.f.get(x.id, r)) };
        d.* = .{ .roles = roles, .against = y.name };
        break :blk d;
    } else if (builds.forChampion(site, site.view, x, r)) |b| blk: {
        const d = try a.create(cp.BuildData);
        const roles = try a.alloc(cp.BuildRole, 1);
        roles[0] = .{ .role = champion.uiRole(r), .build = try buildblock.data(a, b.f, b.b, x.name) };
        d.* = .{ .roles = roles, .against = y.name, .usual_of = x.name };
        break :blk d;
    } else null;
    var build: ?cp.Build = if (build_data) |d| .{
        .data = d,
        .panels = try cp.panels(a, d.roles),
        .bin = try bin(a, cp.BuildData, d.*),
        .js = "/" ++ assets.champbuild_js.path,
        .wasm = assets.champbuild_wasm.path,
    } else null;
    if (build) |*b| b.files.base[0] = b.data;

    const more_data = try a.create(mp.MoreData);
    more_data.* = try moreData(site, curves, r, x, y);
    var more: mp.More = try .init(a, more_data);
    more.bin = try bin(a, mp.MoreData, more_data.*);
    more.js = "/" ++ assets.matchmore_js.path;
    more.wasm = assets.matchmore_wasm.path;

    var t: ui.Tree = .{};
    var h: ui.H = .init(a, &t);
    t.root = h.div(.{ .class = "c-cpage c-mpage" }, .{ head.view(&h), if (build) |*b| b.view(&h) else ui.N.none, more.view(&h) });
    if (h.oom) return error.OutOfMemory;
    try ui.html.write(&t, t.root, w);
    try tpl.render(w,
        \\<p class="muted small"><a href="{x_href}">{x}</a> · <a href="{y_href}">{y}</a> · <a href="/method">Method</a></p>
        \\<script src="{js}" data-wasm="{wasm}" defer></script>
        \\
    , .{
        .x_href = try site.champHref(x),
        .x = x.name,
        .y_href = try site.champHref(y),
        .y = y.name,
        .js = html.Link{ .path = assets.matchup_js.path },
        .wasm = assets.matchup_wasm.path,
    });
    try html.foot(w, p);
}

/// `v` as ui.data, base64: an island root's data-bin
fn bin(a: std.mem.Allocator, comptime T: type, v: T) ![]const u8 {
    var raw: std.ArrayList(u8) = .empty;
    try ui.data.encode(a, T, v, &raw);
    const e = std.base64.standard.Encoder;
    const out = try a.alloc(u8, e.calcSize(raw.items.len));
    return e.encode(out, raw.items);
}

fn other(ch: Champ) mp.Other {
    return .{ .name = ch.name, .key = ch.key, .slug = ch.slug };
}

fn headData(site: *const Site, curves: *const Curves, r: Role, x: Champ, y: Champ, views: [html.View.count][]const u8) !mp.HeadData {
    const a = site.arena;
    const v = curves.get(r, .all, x.id, y.id).?;
    const o = odds(&site.stats, r, x, y, champion.usualK(&site.stats, r));
    const i = curvesfile.lane_minute - 1;
    const has_gold = i < v.minutes() and v.minute(i).n >= minuteFloor(v);
    const lane = v.lane();
    const list = try others(site, curves, r, x);
    const opps = try a.alloc(mp.Opp, list.len);
    for (opps, list) |*op, l| {
        const e = site.stats.enemy(r, r, x.c, l.ch.c);
        op.* = .{ .o = other(l.ch), .games = e.games, .wins = e.wins };
    }
    std.mem.sort(mp.Opp, opps, {}, struct {
        fn f(_: void, p_: mp.Opp, q: mp.Opp) bool {
            return p_.games > q.games;
        }
    }.f);
    return .{
        .x = other(x),
        .y = other(y),
        .role = champion.uiRole(r),
        .patch = site.patch,
        .ddragon = site.ddragon_version,
        .swap = try site.href(page(r, y, x)),
        .clear = try site.href(.{ .champion = .{ .slug = x.slug, .role = champion.uiRole(r) } }),
        .games = o.games,
        .wins = o.wins,
        .usual = @floatCast(100 * o.usual),
        .vs_usual = @floatCast(100 * o.d.mean),
        .gold = if (has_gold) v.estimate(.gold, i).mean else null,
        .cs_gold = if (has_gold and r != .jungle and r != .utility) @intCast(round10(@as(i32, v.estimate(.cs, i).mean) * gold_per_cs)) else null,
        .lane_games = lane.games,
        .ahead = lane.ahead,
        .thin = thin(v),
        .opps = opps,
        .views = views,
        .view = @intCast(site.view.index()),
    };
}

fn moreData(site: *const Site, curves: *const Curves, r: Role, x: Champ, y: Champ) !mp.MoreData {
    const a = site.arena;
    const v = curves.get(r, .all, x.id, y.id).?;
    const base = curves.baseline(r, .all);
    const last = reach(v);
    const games = try a.alloc(u32, last);
    for (games, 0..) |*g, i| g.* = v.minute(i).n;
    var out: [3]mp.Curve = undefined;
    const prev = prevLine(site, r, x, y);
    for (&out, [_]curvesfile.Metric{ .gold, .xp, .cs }) |*c, m| {
        const line = try a.alloc(i16, last);
        const bands = try a.alloc([2]i16, last);
        for (line, bands, 0..) |*l, *b, i| {
            l.* = v.estimate(m, i).mean;
            const q = band(v, base, m, i);
            b.* = .{ clamp16(q[0]), clamp16(q[1]) };
        }
        var pl: []i16 = &.{};
        if (m == .gold) if (prev) |pv| {
            pl = try a.alloc(i16, @min(last, reach(pv.v)));
            for (pl, 0..) |*l, i| l.* = pv.v.estimate(m, i).mean;
        };
        c.* = .{ .line = line, .band = bands, .prev = pl };
    }
    const lane = v.lane();
    var gold10: [curvesfile.buckets]mp.Bucket = undefined;
    for (&gold10, 0..) |*b, i| {
        const c = v.comeback(.ten, i);
        const all = if (base) |bl| bl.comeback(.ten, i) else curvesfile.Counts{};
        b.* = .{ .games = c.games, .wins = c.wins, .all_games = all.games, .all_wins = all.wins };
    }
    var by_length: [3]mp.Bucket = @splat(.{});
    if (site.trend) |*t| if (t.lane(r, x.c, y.c)) |pair| {
        var all: [stats.length_buckets]core.statsfile.Counts = undefined;
        for (&all, 0..) |*c, b| c.* = t.length(r, x.c, b);
        for (&by_length, [_][2]usize{ .{ 0, 2 }, .{ 2, 4 }, .{ 4, 5 } }) |*b, e| {
            const c = stats.Trend.merged(pair, e[0], e[1]);
            const o = stats.Trend.merged(all, e[0], e[1]);
            b.* = .{ .games = c.games, .wins = c.wins, .all_games = o.games, .all_wins = o.wins };
        }
    };
    var ranks: std.ArrayList(mp.RankRow) = .empty;
    for (std.enums.values(Bracket)) |b| {
        const bv = curves.get(r, b, x.id, y.id) orelse continue;
        try ranks.append(a, rankRow(b.label(), bv, @intCast(ranks.items.len)));
    }
    for ((try variants(a, curves, r, x, y))[1..]) |s| try ranks.append(a, rankRow(s.label, s.v, @intCast(ranks.items.len)));
    return .{
        .x = x.name,
        .y = y.name,
        .ddragon = site.ddragon_version,
        .role = champion.uiRole(r),
        .thin = thin(v),
        .games = games,
        .curves = out,
        .h2h = .{
            .games = v.games(),
            .wins = v.wins(),
            .lane_games = lane.games,
            .ahead = lane.ahead,
            .behind = lane.behind,
            .wins_ahead = lane.wins_ahead,
            .wins_behind = lane.wins_behind,
            .first_blood = v.firstBlood(),
            .kills = .{ v.kills(0), v.kills(1), v.kills(2) },
            .deaths = .{ v.deaths(0), v.deaths(1), v.deaths(2) },
            .level2 = v.level2(),
            .level6 = v.level6(),
            .first_item = v.firstItem(),
        },
        .gold10 = gold10,
        .by_length = by_length,
        .ranks = ranks.items,
        .duos = try duos(site, r, x, y),
    };
}

fn rankRow(label: []const u8, v: View, order: u8) mp.RankRow {
    const i = curvesfile.lane_minute - 1;
    const has_gold = i < v.minutes() and v.minute(i).n >= minuteFloor(v);
    return .{ .label = label, .games = v.games(), .wins = v.wins(), .gold = if (has_gold) v.estimate(.gold, i).mean else null, .order = order };
}

fn clamp16(v: i32) i16 {
    return @intCast(std.math.clamp(v, std.math.minInt(i16), std.math.maxInt(i16)));
}

/// Most duo partners listed for each side
const duo_rows = 5;

/// Bot lane: the supports x and y each play with, most games first, vs usual as on the
/// champion page's With view; a support matchup lists their bot laners. From all of each
/// champion's games in the role, not only this matchup's: the stats count pairs, not
/// threes
fn duos(site: *const Site, r: Role, x: Champ, y: Champ) ![]const mp.DuoSide {
    const r2: Role = switch (r) {
        .bottom => .utility,
        .utility => .bottom,
        else => return &.{},
    };
    const a = site.arena;
    const p: champion.Pairs = .{ .st = &site.stats, .r = r, .r2 = r2, .ally = true };
    const k = champion.pairsUsualK(p);
    const st = p.st;
    const out = try a.alloc(mp.DuoSide, 2);
    for (out, [_]Champ{ x, y }) |*side, ch| {
        var list: std.ArrayList(mp.Duo) = .empty;
        const cr = st.champRole(r, ch.c);
        for (0..st.n) |c2| {
            const e = p.get(ch.c, c2);
            if (e.games == 0) continue;
            const d = site.champs[site.by_c[c2] orelse continue];
            const dr = st.champRole(r2, d.c);
            const u = p.usualOf(root.ratio(cr.wins, cr.games), root.ratio(dr.wins, dr.games));
            try list.append(a, .{ .champ = other(d), .games = e.games, .usual = @floatCast(100 * champion.VsUsual.of(e.wins, e.games, u, k).mean) });
        }
        std.mem.sort(mp.Duo, list.items, {}, struct {
            fn f(_: void, p_: mp.Duo, q: mp.Duo) bool {
                return p_.games > q.games;
            }
        }.f);
        side.* = .{ .name = ch.name, .partners = list.items[0..@min(duo_rows, list.items.len)] };
    }
    return out;
}

const Other = struct { ch: Champ, games: u32 };

fn moreGames(_: void, p_: Other, q: Other) bool {
    return p_.games > q.games;
}

/// `fixed`'s lane opponents with a page in r, most games (the curves') first
fn others(site: *const Site, curves: *const Curves, r: Role, fixed: Champ) ![]Other {
    var list: std.ArrayList(Other) = .empty;
    for (curves.curves) |c| {
        const h = c.header;
        if (h.role != @backingInt(r) or !isPage(h)) continue;
        const id = if (h.a == fixed.id) h.b else if (h.b == fixed.id) h.a else continue;
        try list.append(site.arena, .{ .ch = champ(site, id) orelse continue, .games = h.games });
    }
    std.mem.sort(Other, list.items, {}, moreGames);
    return list.items;
}

/// x's win rate against y (the view's stats) and against usual (champion.VsUsual, as
/// the champion page's opponent grid); `ka`: champion.usualK of `r`
/// `base`: x's win rate in the role, the champion page's
const Odds = struct { wins: u32, games: u32, base: f64, usual: f64, d: champion.VsUsual };

fn odds(st: *const core.Stats, r: Role, x: Champ, y: Champ, ka: f64) Odds {
    const e = st.enemy(r, r, x.c, y.c);
    const xr = st.champRole(r, x.c);
    const yr = st.champRole(r, y.c);
    const base = root.ratio(xr.wins, xr.games);
    const u = champion.usual(base, root.ratio(yr.wins, yr.games));
    return .{ .wins = e.wins, .games = e.games, .base = base, .usual = u, .d = champion.VsUsual.of(e.wins, e.games, u, ka) };
}

/// Lane minion gold per CS before 14 minutes: 3 melee (21), 3 casters (14) a wave and a
/// cannon (60 to 70) every third, 381 gold over 19 minions. Jungle camps and support
/// CS differ, so those roles get no split
const gold_per_cs = 20;

fn round10(v: i32) i32 {
    return @divTrunc(v + if (v < 0) @as(i32, -5) else 5, 10) * 10;
}

/// Minutes drawn: while at least minuteFloor games are still going
fn reach(v: View) usize {
    var last: usize = 0;
    while (last < v.minutes() and v.minute(last).n >= minuteFloor(v)) last += 1;
    return last;
}

/// The band at minute i: the curve's own middle half of games once it has thin_games,
/// else the role's middle half (both sides, centred on 0) around the estimate
fn band(v: View, base: ?View, metric: curvesfile.Metric, i: usize) [2]i32 {
    const q = spreadAt(v, base, metric, i);
    return .{ q.p25, q.p75 };
}

const Spread32 = struct { p10: i32, p25: i32, p75: i32, p90: i32 };

fn spreadAt(v: View, base: ?View, metric: curvesfile.Metric, i: usize) Spread32 {
    const m = v.minute(i);
    const own = v.games() >= thin_games or base == null;
    const q = spreadOf(if (own) m else base.?.minute(i), metric);
    const e: i32 = if (own) 0 else m.est[@backingInt(metric)].mean;
    return .{ .p10 = e + q.p10, .p25 = e + q.p25, .p75 = e + q.p75, .p90 = e + q.p90 };
}

fn spreadOf(m: curvesfile.Minute, metric: curvesfile.Metric) curvesfile.Spread {
    return switch (metric) {
        .gold => m.gold,
        .xp => m.xp,
        .cs => m.cs,
    };
}

/// The previous patch's estimated average, dashed on a patch view's charts: from
/// Site.curves_prev, with the matchup's own games there (thin_games)
const Prev = struct { v: View, patch: []const u8 };

fn prevLine(site: *const Site, r: Role, x: Champ, y: Champ) ?Prev {
    const c = if (site.curves_prev) |*c| c else return null;
    const v = c.get(r, .all, x.id, y.id) orelse return null;
    if (v.games() < thin_games) return null;
    return .{ .v = v, .patch = c.patch() };
}

test "one page per matchup, though experienced players' curves share its pair" {
    const gpa = std.testing.allocator;
    var b: curvesfile.Builder = .{ .gpa = gpa };
    defer b.deinit();
    for (0..40) |i| {
        try b.addLane(.{
            .role = .top,
            .bracket = .mid,
            .a = 10,
            .b = 60,
            .a_won = i % 2 == 0,
            .minutes = 20,
            .experienced_a = i % 3 != 0,
            .experienced_b = i % 3 != 1,
        });
        b.addGame();
    }
    var aw: Writer.Allocating = .init(gpa);
    defer aw.deinit();
    try b.write(&aw.writer, "16.20", 1);
    var c: Curves = try .parse(gpa, aw.written());
    defer c.deinit(gpa);
    var all_ranks: usize = 0;
    var pages: usize = 0;
    for (c.curves) |cv| {
        if (cv.header.a != 10 or cv.header.b != 60) continue;
        all_ranks += @intFromBool(cv.header.bracket == @backingInt(Bracket.all));
        pages += @intFromBool(isPage(cv.header));
    }
    try std.testing.expectEqual(3, all_ranks);
    try std.testing.expectEqual(1, pages);
}
