//! Champion pages (champion/<slug>.html): ui.champpage's three islands, rendered from
//! the root view, and their data files (data/champion/<slug>.bin, -build.bin, -more.bin,
//! -charts.bin) for the other roles

const std = @import("std");
const core = @import("core");
const ui = @import("ui");
const html = @import("html.zig");
const shell = @import("shell.zig");
const assets = @import("assets.zig");
const trend = @import("trend.zig");
const tierlist = @import("tierlist.zig");
const builds_page = @import("builds.zig");
const buildblock = @import("buildblock.zig");
const stats = @import("../stats.zig");
const builds = @import("../builds.zig");
const learning = @import("../learning.zig");
const ddragon = @import("../ddragon.zig");
const Date = @import("../date.zig").Date;
const curvesfile = core.curvesfile;

const Writer = std.Io.Writer;
const Stats = core.Stats;
const Counts = core.statsfile.Counts;
const Role = core.Role;
const tpl = html.tpl;
const cp = ui.champpage;

const root = @import("root.zig");
const Champ = root.Champ;
const Site = root.Site;
const ratio = root.ratio;

/// Opponents and allies under this share of the champion's games in the role are left
/// out: a dot each would crowd the plot with noise
const min_opponent_share = 0.01;

/// The page's data files, under the view's directory, by island
pub fn dataPath(a: std.mem.Allocator, ch: Champ, part: Part) ![]const u8 {
    return a.print("data/champion/{s}{s}.bin", .{ ch.slug, switch (part) {
        .top => "",
        .build => "-build",
        .more => "-more",
        .charts => "-charts",
    } });
}

pub const Part = enum { top, build, more, charts };

/// `ch` in role `r`, from the root view (EUW, 30 days); its toolbar fetches the other
/// views' files and the rank files (champrank.zig). `in_url`: the address names `r`
/// (/champions/<slug>/<r>), else it is the bare /champions/<slug>. `own_canonical`: that
/// address is canonical, else the bare one is (main role, thin role)
pub fn writeChampion(site: *const Site, w: *Writer, ch: Champ, r: Role, in_url: bool, own_canonical: bool) !void {
    const a = site.arena;
    const title = try a.print("{s} build, matchups and win rate | meiolol", .{ch.name});
    const desc = try a.print("{s} in ranked solo queue: runes, items and skills with their win rates, every lane opponent, by patch and game length.", .{ch.name});
    var p = try site.sharedPage(title, desc, .champions);
    p.canonical = try site.canonical(.{ .champion = .{ .slug = ch.slug, .role = if (own_canonical) uiRole(r) else null } });
    try shell.open(w, p);
    const shown: cp.Top.Url = .{ .role = if (in_url) uiRole(r) else null };

    const d = try a.create(cp.Data);
    d.* = try pageData(site, ch);
    const parts = try a.create(cp.Split);
    parts.* = try cp.split(a, d);
    const bytes = try encode(site, parts);
    var top: cp.Top = .init(&parts.top, try cp.prepare(a, &parts.top, "/"), "/");
    top.fromUrl(shown);
    top.src = try std.mem.concat(a, u8, &.{ "/", try dataPath(a, ch, .top) });
    top.stamp = cp.stamp(bytes[0]);
    var build: cp.Build = .{
        .data = &parts.build,
        .panels = try cp.panels(a, parts.build.roles),
        .root = "/",
        .src = try std.mem.concat(a, u8, &.{ "/", try dataPath(a, ch, .build) }),
        .stamp = cp.stamp(bytes[1]),
        .js = "/" ++ assets.champbuild_js.path,
        .wasm = assets.champbuild_wasm.path,
    };
    var more: cp.More = .{
        .data = &parts.more,
        .root = "/",
        .src = try std.mem.concat(a, u8, &.{ "/", try dataPath(a, ch, .more) }),
        .stamp = cp.stamp(bytes[2]),
        .js = "/" ++ assets.champmore_js.path,
        .wasm = assets.champmore_wasm.path,
    };
    var charts: cp.Charts = .{
        .data = &parts.charts,
        .root = "/",
        .src = try std.mem.concat(a, u8, &.{ "/", try dataPath(a, ch, .charts) }),
        .stamp = cp.stamp(bytes[3]),
        .js = "/" ++ assets.champcharts_js.path,
        .wasm = assets.champcharts_wasm.path,
    };
    // The champion and its roles, most played first, for /private/pv.js (no island's root, so
    // no wasm reads or writes them)
    var roles: std.ArrayList(u8) = .empty;
    for (d.roles, 0..) |x, i| try roles.print(a, "{s}{s}", .{ if (i > 0) " " else "", @tagName(x.role) });
    build.fromUrl(.{ .role = shown.role });
    more.fromUrl(.{ .role = shown.role });
    charts.fromUrl(.{ .role = shown.role });
    var t: ui.Tree = .{};
    var h: ui.H = .init(a, &t);
    // The role rendered for, when the path names it: the wasms' server state (dom.pageRole)
    t.root = h.div(.{ .class = "c-cpage", .data_id = ch.id, .data_roles = roles.items, .data_role = shown.role }, .{ top.view(&h), build.view(&h), more.view(&h), charts.view(&h) });
    if (h.oom) return error.OutOfMemory;
    try ui.html.write(&t, t.root, w);
    // Only Top's: it loads the others' (ui/wasm/champion.zig)
    try tpl.render(w,
        \\<p class="muted small"><a href="/method">Method</a></p>
        \\<script src="{js}" data-wasm="{wasm}" defer></script>
        \\
    , .{
        .js = html.Link{ .path = assets.champion_js.path },
        .wasm = assets.champion_wasm.path,
    });
    try shell.close(w, p);
}

/// Each island's data file, in Part order: what the page renders from
fn encode(site: *const Site, parts: *const cp.Split) ![4][]const u8 {
    var out: [4]std.ArrayList(u8) = @splat(.empty);
    try ui.data.encode(site.arena, cp.TopData, parts.top, &out[0]);
    try ui.data.encode(site.arena, cp.BuildData, parts.build, &out[1]);
    try ui.data.encode(site.arena, cp.MoreData, parts.more, &out[2]);
    try ui.data.encode(site.arena, cp.ChartsData, parts.charts, &out[3]);
    return .{ out[0].items, out[1].items, out[2].items, out[3].items };
}

/// Every champion's data files, under the view's directory
pub fn dataFiles(site: *const Site, files: anytype) !void {
    for (site.champs) |ch| {
        const d = try pageData(site, ch);
        const bytes = try encode(site, &try cp.split(site.arena, &d));
        for (std.enums.values(Part), bytes) |part, b| try files.append(site.arena, .{ .path = try dataPath(site.arena, ch, part), .data = b });
    }
}

pub fn uiRole(r: Role) ui.role.Role {
    return switch (r) {
        .top => .top,
        .jungle => .jungle,
        .middle => .mid,
        .bottom => .bot,
        .utility => .support,
    };
}

fn pct(n: u64, of: u64) f32 {
    return @floatCast(100 * ratio(n, of));
}

pub fn pageData(site: *const Site, ch: Champ) !cp.Data {
    const a = site.arena;
    const st = &site.stats;
    const champs = try a.alloc(cp.Other, site.champs.len);
    for (champs, site.champs) |*o, x| o.* = .{ .name = x.name, .key = x.key, .slug = x.slug };

    var roles: std.ArrayList(Role) = .empty;
    for (Role.all) |r| {
        const g = st.champRole(r, ch.c).games;
        if (g > 0) try roles.append(a, r);
    }
    std.mem.sort(Role, roles.items, RoleGames{ .st = st, .c = ch.c }, RoleGames.more);
    const out = try a.alloc(cp.Role, roles.items.len);
    for (out, roles.items) |*o, r| o.* = try roleData(site, ch, r);

    return .{
        .name = ch.name,
        .slug = ch.slug,
        .id = std.math.cast(u16, ch.id) orelse 0,
        .icon = try site.icon(ch),
        .patch = site.patch,
        .ddragon = site.ddragon_version,
        .champs = champs,
        .roles = out,
        .lengths = &trend.length_labels,
        .spread = spreadOf(site, ch),
        .pickup = pickupOf(site, ch),
        .also = try alsoOf(site, ch),
    };
}

fn roleData(site: *const Site, ch: Champ, r: Role) !cp.Role {
    const a = site.arena;
    const st = &site.stats;
    const cr = st.champRole(r, ch.c);
    const rank = try tierlist.roleRank(site, r, ch.id);
    const move: ?[2]f32 = if (site.patchday) |*pd| if (pd.champion(ch.id, r)) |m| blk: {
        if (m.win.prev.games == 0 or m.win.cur.games == 0) break :blk null;
        const range = m.win.range(1.96);
        break :blk .{ @floatCast(m.win.delta()), @floatCast((range[1] - range[0]) / 2) };
    } else null else null;
    const picked = builds_page.forChampion(site, site.view, ch, r);
    const lean: ?i16 = if (site.lean) |l| if (l.get(ch.id, r)) |row| (if (row.enough()) @intFromFloat(@round(row.gold / 10) * 10) else null) else null else null;

    var by_patch: []cp.Patch = &.{};
    var by_day: []cp.Day = &.{};
    var by_length: []cp.Counts = &.{};
    if (site.trend) |*t| {
        by_patch = try a.alloc(cp.Patch, t.patches.len);
        for (by_patch, 0..) |*x, i| {
            const pi = t.patches.len - 1 - i;
            const c = t.onPatch(pi, r, ch.c);
            const k = try trend.patchRank(a, t, pi, r, ch.c);
            x.* = .{ .patch = t.patches[pi], .games = c.games, .wins = c.wins, .rank = if (k) |x2| @intCast(x2.rank) else 0 };
        }
        by_day = try a.alloc(cp.Day, t.days.len);
        for (by_day, t.days, 0..) |*x, day, i| {
            const c = t.onDay(i, r, ch.c);
            const d: Date = .fromDay(@max(day, 0));
            x.* = .{
                .label = try std.fmt.allocPrint(a, "{d}", .{d.day}),
                .tip = try std.fmt.allocPrint(a, "{f}", .{d.short()}),
                .games = c.games,
                .wins = c.wins,
            };
        }
        by_length = try a.alloc(cp.Counts, stats.length_buckets);
        for (by_length, 0..) |*x, b| {
            const c = t.length(r, ch.c, b);
            x.* = .{ .games = c.games, .wins = c.wins };
        }
    }

    var rels: std.ArrayList(cp.Rel) = .empty;
    try rels.append(a, try relOf(site, ch, cr, .{ .st = st, .r = r, .r2 = r }));
    for (Role.all) |r2| if (r2 != r) try rels.append(a, try relOf(site, ch, cr, .{ .st = st, .r = r, .r2 = r2 }));
    for (Role.all) |r2| if (r2 != r) try rels.append(a, try relOf(site, ch, cr, .{ .st = st, .r = r, .r2 = r2, .ally = true }));

    return .{
        .role = uiRole(r),
        .games = cr.games,
        .wins = cr.wins,
        .share = pct(cr.games, ch.games),
        .thin = ratio(cr.games, ch.games) < tierlist.min_role_share,
        .rank = if (rank) |k| @intCast(k.rank) else 0,
        .of = if (rank) |k| @intCast(k.of) else 0,
        .pick = pct(cr.games, site.games),
        .ban = pct(ch.banned, site.games),
        .patch_move = move,
        .lean = lean,
        .lane = try laneOf(site, ch, r),
        .comeback = try comebackOf(site, ch, r),
        .kills = try killsOf(site, ch, r),
        .objectives = objectivesOf(site, ch, r),
        .ranks = try ranksOf(site, ch, r),
        // The card has no period label: this view's games only, as the head's
        .timing = if (builds_page.forChampionHere(site, site.view, ch, r)) |b| try timingOf(a, b.first_item, cp.min_games) else &.{},
        .build = if (picked) |b| try buildblock.data(a, b.f, b.b, ch.name) else null,
        .rels = rels.items,
        .by_patch = by_patch,
        .by_day = by_day,
        .by_length = by_length,
    };
}

/// `ch`'s lane opponents in `r` as the matchups table has them; null when `r` is thin for
/// it (the pool grid's lanes file)
pub fn laneRel(site: *const Site, ch: Champ, r: Role) !?cp.Rel {
    if (!plays(site, ch, r)) return null;
    return try relOf(site, ch, site.stats.champRole(r, ch.c), .{ .st = &site.stats, .r = r, .r2 = r });
}

/// Games in `r` and not thin there
pub fn plays(site: *const Site, ch: Champ, r: Role) bool {
    const g = site.stats.champRole(r, ch.c).games;
    return g > 0 and ratio(g, ch.games) >= tierlist.min_role_share;
}

/// Those against (or with) ch in 1%+ of its games in the role, most played first
fn relOf(site: *const Site, ch: Champ, cr: Counts, pairs: Pairs) !cp.Rel {
    const a = site.arena;
    const st = pairs.st;
    const floor = @max(1, min_opponent_share * @as(f64, @floatFromInt(cr.games)));
    const base = ratio(cr.wins, cr.games);
    const k = pairsUsualK(pairs);
    const lane = !pairs.ally and pairs.r == pairs.r2;
    var opps: std.ArrayList(cp.Opp) = .empty;
    var rare: u16 = 0;
    for (site.champs, 0..) |other, i| {
        if (other.c == ch.c) continue;
        const e = pairs.get(ch.c, other.c);
        if (@as(f64, @floatFromInt(e.games)) < floor) {
            if (e.games > 0) rare += 1;
            continue;
        }
        const oc = st.champRole(pairs.r2, other.c);
        const u = VsUsual.of(e.wins, e.games, pairs.usualOf(base, ratio(oc.wins, oc.games)), k);
        const curve = if (lane) if (site.curves) |*c| c.get(pairs.r, .all, ch.id, other.id) else null else null;
        try opps.append(a, .{
            .champ = @intCast(i),
            .games = e.games,
            .wins = e.wins,
            .usual = @floatCast(100 * u.mean),
            .gold = if (curve) |v| v.estimate(.gold, core.curvesfile.lane_minute - 1).mean else null,
            .page = curve != null,
        });
    }
    std.mem.sort(cp.Opp, opps.items, {}, struct {
        fn f(_: void, x: cp.Opp, y: cp.Opp) bool {
            return x.games > y.games;
        }
    }.f);
    return .{ .ally = pairs.ally, .role = uiRole(pairs.r2), .opps = opps.items, .rare = rare };
}

/// ch's lane against the average opponent in r, by minute: its pairs' estimates from its
/// side, weighted by their lanes still going; the band is the role's middle half of
/// lanes around that line, as a thin matchup page's. Null under cp.min_games lanes
fn laneOf(site: *const Site, ch: Champ, r: Role) !?cp.LaneCurves {
    const a = site.arena;
    const c = if (site.curves) |*c| c else return null;
    const base = c.baseline(r, .all) orelse return null;
    const pairs = try lanePairs(site, c, ch, r, .all);
    var games: std.ArrayList(u32) = .empty;
    for (0..base.minutes()) |i| {
        var n: u32 = 0;
        for (pairs.items) |v| if (i < v.minutes()) {
            n += v.minute(i).n;
        };
        if (n < lane_min_games) break;
        try games.append(a, n);
    }
    if (games.items.len < 2 or games.items[0] < cp.min_games) return null;
    var out: cp.LaneCurves = .{ .games = games.items, .metrics = undefined };
    for (&out.metrics, [_]curvesfile.Metric{ .gold, .xp, .cs }) |*o, m| {
        const line = try a.alloc(f32, games.items.len);
        const band = try a.alloc([2]f32, games.items.len);
        for (line, band, games.items, 0..) |*l, *b, n, i| {
            var sum: f64 = 0;
            for (pairs.items) |v| if (i < v.minutes()) {
                const x = v.minute(i);
                sum += @as(f64, @floatFromInt(x.n)) * @as(f64, @floatFromInt(x.est[@backingInt(m)].mean));
            };
            l.* = @round(@as(f32, @floatCast(sum / @as(f64, @floatFromInt(n)))));
            const q = switch (m) {
                .gold => base.minute(i).gold,
                .xp => base.minute(i).xp,
                .cs => base.minute(i).cs,
            };
            b.* = .{ l.* + @as(f32, @floatFromInt(q.p25)), l.* + @as(f32, @floatFromInt(q.p75)) };
        }
        o.* = .{ .line = line, .band = band };
    }
    return out;
}

/// ch's lane opponents in r with curves in bracket b, from ch's side
fn lanePairs(site: *const Site, c: *const curvesfile.Curves, ch: Champ, r: Role, b: curvesfile.Bracket) !std.ArrayList(curvesfile.View) {
    var pairs: std.ArrayList(curvesfile.View) = .empty;
    for (site.champs) |o| if (o.id != ch.id) if (c.get(r, b, ch.id, o.id)) |v| try pairs.append(site.arena, v);
    return pairs;
}

/// ch's lanes in r by its gold lead at 10 and 15 minutes, summed over its pairs as
/// laneOf, beside every lane in the role; null under cp.min_games lanes at 10
fn comebackOf(site: *const Site, ch: Champ, r: Role) !?cp.Comeback {
    const c = if (site.curves) |*c| c else return null;
    const base = c.baseline(r, .all) orelse return null;
    const pairs = try lanePairs(site, c, ch, r, .all);
    var out: cp.Comeback = .{ .at = @splat(@splat(.{ .games = 0, .wins = 0 })), .all = undefined };
    for (&out.at, &out.all, std.enums.values(curvesfile.Comeback)) |*row, *all, at| for (row, all, 0..) |*o, *x, b| {
        for (pairs.items) |v| {
            const k = v.comeback(at, b);
            o.games += k.games;
            o.wins += k.wins;
        }
        const k = base.comeback(at, b);
        x.* = .{ .games = k.games, .wins = k.wins };
    };
    var lanes: u32 = 0;
    for (out.at[0]) |x| lanes += x.games;
    return if (lanes < cp.min_games) null else out;
}

/// ch's lanes in r with kills on and by its lane opponent, summed over its pairs as
/// laneOf; null under cp.min_games lanes
fn killsOf(site: *const Site, ch: Champ, r: Role) !?cp.Kills {
    const c = if (site.curves) |*c| c else return null;
    const pairs = try lanePairs(site, c, ch, r, .all);
    var out: cp.Kills = .{ .games = 0, .first_blood = @splat(0), .kills = @splat(0), .deaths = @splat(0) };
    for (pairs.items) |v| {
        out.games += v.games();
        for (&out.first_blood, v.firstBlood()) |*o, x| o.* += x;
        for (&out.kills, &out.deaths, 0..) |*k, *d, i| {
            k.* += v.kills(i);
            d.* += v.deaths(i);
        }
    }
    return if (out.games < cp.min_games) null else out;
}

/// ch's games in r by the game's rank bracket (stats.Trend.brackets: the view's games, as
/// the head's), with its gold lead at 14 minutes from the bracket's pair curves; the card
/// leaves out thin brackets
fn ranksOf(site: *const Site, ch: Champ, r: Role) !?cp.Ranks {
    const t = if (site.trend) |*t| t else return null;
    const all = site.stats.champRole(r, ch.c);
    var out: cp.Ranks = .{ .by = undefined, .all = .{ .games = all.games, .wins = all.wins } };
    for (&out.by, [_]curvesfile.Bracket{ .low, .mid, .high }) |*o, b| {
        const n = t.bracket(r, ch.c, b);
        o.* = .{ .games = n.games, .wins = n.wins, .gold = try goldAt14(site, ch, r, b) };
    }
    return out;
}

/// ch's gold lead at 14 minutes in r over its pairs' curves in bracket b, weighted by lanes
/// still going then; null under cp.min_games such lanes
fn goldAt14(site: *const Site, ch: Champ, r: Role, b: curvesfile.Bracket) !?i16 {
    const c = if (site.curves) |*c| c else return null;
    const at = curvesfile.lane_minute - 1;
    var lanes: u32 = 0;
    var sum: f64 = 0;
    for ((try lanePairs(site, c, ch, r, b)).items) |v| {
        if (at >= v.minutes()) continue;
        const n = v.minute(at).n;
        lanes += n;
        sum += @as(f64, @floatFromInt(n)) * @as(f64, @floatFromInt(v.estimate(.gold, at).mean));
    }
    if (lanes < cp.min_games) return null;
    return @intFromFloat(@round(sum / @as(f64, @floatFromInt(lanes))));
}

/// ch's objectives taken first in r (builds.File.Build.firsts) beside the role's over
/// every champion, from the view's builds file; null under min_games or a file without
pub fn objectivesOf(site: *const Site, ch: Champ, r: Role) ?cp.Objectives {
    const f = if (site.view_builds[site.view.index()]) |*f| f else return null;
    const b = builds_page.forChampionHere(site, site.view, ch, r) orelse return null;
    return objectivesIn(f.builds, b, r);
}

fn objectivesIn(all: []const builds.File.Build, b: builds.File.Build, r: Role) ?cp.Objectives {
    comptime std.debug.assert(cp.W.firsts.len == builds.firsts_len);
    const n = 1 + builds.firsts_len;
    if (b.firsts.len != n or b.firsts[0].games < cp.min_games) return null;
    var out: cp.Objectives = .{ .mine = undefined, .role = @splat(.{ .games = 0, .wins = 0 }) };
    for (&out.mine, b.firsts) |*o, x| o.* = .{ .games = x.games, .wins = x.wins };
    for (all) |x| if (x.role == r and x.firsts.len == n) for (&out.role, x.firsts) |*o, y| {
        o.games += y.games;
        o.wins += y.wins;
    };
    return out;
}

/// Games by the minute the first item was finished (builds.File.Build.first_item) in
/// buckets: the minutes between two tails in steps of 2 or wider, at most 7 buckets, the
/// steps' remainder split between the tails. Each tail holds at least a twentieth of the
/// games and `thin`, but the late one less when they meet (most games in a minute or
/// two). Empty under two tails' worth
pub fn timingOf(a: std.mem.Allocator, hist: []const builds.Count, thin: u32) ![]const cp.Timed {
    var total: u32 = 0;
    for (hist) |x| total += x.games;
    const tail = @max(thin, total / 20);
    if (tail == 0 or total < 2 * tail) return &.{};
    var lo: usize = 0;
    var below: u32 = 0;
    while (below < tail) : (lo += 1) below += hist[lo].games;
    var hi: usize = hist.len;
    var above: u32 = 0;
    while (above < tail) {
        hi -= 1;
        above += hist[hi].games;
    }
    hi = @max(hi, lo);
    var step: usize = 2;
    while ((hi - lo + step - 1) / step > 5) step += 1;
    const steps = (hi - lo) / step;
    lo += (hi - lo - steps * step) / 2;
    hi = lo + steps * step;

    var out: std.ArrayList(cp.Timed) = .empty;
    const sum = struct {
        fn f(xs: []const builds.Count) builds.Count {
            var c: builds.Count = .{};
            for (xs) |x| {
                c.games += x.games;
                c.wins += x.wins;
            }
            return c;
        }
    }.f;
    const first = sum(hist[0..lo]);
    try out.append(a, .{ .label = try a.print("<{d}", .{lo}), .games = first.games, .wins = first.wins });
    var m = lo;
    while (m < hi) : (m += step) {
        const c = sum(hist[m .. m + step]);
        try out.append(a, .{ .label = try a.print("{d}-{d}", .{ m, m + step }), .games = c.games, .wins = c.wins });
    }
    const last = sum(hist[hi..]);
    try out.append(a, .{ .label = try a.print("{d}+", .{hi}), .games = last.games, .wins = last.wins });
    return out.items;
}

test "first item timing: tails of a twentieth, two-minute steps between" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    // 2,000 games: 100 by minute 8, 1,800 over minutes 8-15, 100 at 16 and later
    var hist: [20]builds.Count = @splat(.{});
    hist[6] = .{ .games = 100, .wins = 40 };
    for (8..16) |m| hist[m] = .{ .games = 225, .wins = 120 };
    hist[17] = .{ .games = 100, .wins = 60 };
    const t = try timingOf(a, &hist, 100);
    try std.testing.expectEqual(7, t.len);
    try std.testing.expectEqualStrings("<7", t[0].label);
    try std.testing.expectEqual(100, t[0].games);
    try std.testing.expectEqualStrings("7-9", t[1].label);
    try std.testing.expectEqual(225, t[1].games);
    try std.testing.expectEqualStrings("15-17", t[5].label);
    try std.testing.expectEqualStrings("17+", t[6].label);
    try std.testing.expectEqual(100, t[6].games);
    var games: u32 = 0;
    for (t) |x| games += x.games;
    try std.testing.expectEqual(2000, games);
    // Under two tails: nothing
    try std.testing.expectEqual(0, (try timingOf(a, hist[0..8], 100)).len);
    // Spread over 20 minutes: steps of 4 from 1 to 19, the 2 left over one to each tail
    for (&hist) |*x| x.* = .{ .games = 100, .wins = 50 };
    const wide = try timingOf(a, &hist, 100);
    try std.testing.expectEqual(6, wide.len);
    try std.testing.expectEqual(200, wide[0].games);
    try std.testing.expectEqualStrings("2-6", wide[1].label);
    try std.testing.expectEqualStrings("18+", wide[5].label);
    try std.testing.expectEqual(200, wide[5].games);
    // Every game in minute 10: the tails meet, the late one empty, every game kept
    var one: [11]builds.Count = @splat(.{});
    one[10] = .{ .games = 2000, .wins = 1000 };
    const met = try timingOf(a, &one, 100);
    try std.testing.expectEqual(2, met.len);
    try std.testing.expectEqualStrings("<11", met[0].label);
    try std.testing.expectEqual(2000, met[0].games);
    try std.testing.expectEqual(0, met[1].games);
}

test "first item done: players counted by the builder to a drawn card" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const d: ddragon.BuildData = .{ .version = "16.21.1", .legendary = &.{ 3078, 6631 }, .trinkets = &.{}, .boots = &.{}, .items = &.{}, .runes = &.{}, .spells = &.{} };
    var b: builds.Builder = .{ .gpa = std.testing.allocator, .max_keys = 64 };
    defer b.deinit();
    // 1,200 Darius players, first item at minutes 6 to 17 (100 each), the earlier the
    // more won; 100 more who never finished one
    for (0..1300) |i| {
        var k: builds.Picks = .{};
        const m: i64 = @intCast(6 + i % 12);
        if (i < 1200) {
            k.core = .{ 3078, 6631, 0, 0, 0, 0 };
            k.core_ms = .{ m * std.time.ms_per_min + 30_000, m * std.time.ms_per_min + 400_000, 0, 0, 0, 0 };
            k.core_len = 2;
        }
        try b.addPlayer(.{ .champion = 122, .role = .top, .won = i % 20 < 22 - m }, k, &d);
    }
    const f = try b.file(a, &d, "16.21", "PLATINUM", 3);
    const timing = try timingOf(a, f.get(122, .top).?.first_item, cp.min_games);
    // Tails of 100 (minutes 6 and 17), 2-minute steps between
    try std.testing.expectEqual(7, timing.len);
    try std.testing.expectEqualStrings("<7", timing[0].label);
    try std.testing.expectEqual(100, timing[0].games);
    try std.testing.expectEqualStrings("7-9", timing[1].label);
    try std.testing.expectEqual(200, timing[1].games);
    try std.testing.expectEqualStrings("17+", timing[6].label);

    var roles = [_]cp.ChartsRole{.{ .role = .top, .timing = timing }};
    const data: cp.ChartsData = .{ .name = "Darius", .ddragon = "", .champs = &.{}, .roles = &roles };
    var p: cp.Charts = .{ .data = &data, .root = "/" };
    var t: ui.Tree = .{};
    var h: ui.H = .init(a, &t);
    var w: std.Io.Writer.Allocating = .init(a);
    try ui.html.write(&t, p.view(&h), &w.writer);
    for ([_][]const u8{ "First item done", "&lt;7", "7-9", "15-17", "17+", "dashed: games with an item" }) |s|
        try std.testing.expect(std.mem.indexOf(u8, w.written(), s) != null);
    // Dashed at the 1,200 players' rate, the 100 without an item out
    var wins: u32 = 0;
    for (timing) |x| wins += x.wins;
    try std.testing.expectApproxEqAbs(@as(f32, @floatFromInt(wins)) * 100 / 1200, p.timing.ref, 0.01);
}

test "objectives: firsts counted by the builder, against the role, to a drawn card" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const d: ddragon.BuildData = .{ .version = "16.21.1", .legendary = &.{ 3078, 6631 }, .trinkets = &.{}, .boots = &.{}, .items = &.{}, .runes = &.{}, .spells = &.{} };
    var b: builds.Builder = .{ .gpa = std.testing.allocator, .max_keys = 64 };
    defer b.deinit();
    // A build is written for an option: everyone finishes the same two items
    var k: builds.Picks = .{ .core = .{ 3078, 6631, 0, 0, 0, 0 }, .core_ms = .{ 600_000, 900_000, 0, 0, 0, 0 }, .core_len = 2 };
    // 200 Darius and 200 Garen tops: Darius's team takes first dragon in 150 and wins 100
    // of those, Garen's in 50; a Darius jungle stays out of the top role
    for (0..400) |i| {
        const darius = i < 200;
        k.firsts[@backingInt(builds.First.dragon)] = if (darius) i < 150 else i < 250;
        try b.addPlayer(.{ .champion = if (darius) 122 else 86, .role = .top, .won = i < 100 }, k, &d);
    }
    k.firsts = @splat(true);
    try b.addPlayer(.{ .champion = 122, .role = .jungle, .won = true }, k, &d);
    const f = try b.file(a, &d, "16.21", "PLATINUM", 3);
    const o = objectivesIn(f.builds, f.get(122, .top).?, .top).?;
    try std.testing.expectEqual(200, o.mine[0].games);
    try std.testing.expectEqual(150, o.mine[1 + @backingInt(builds.First.dragon)].games);
    try std.testing.expectEqual(100, o.mine[1 + @backingInt(builds.First.dragon)].wins);
    try std.testing.expectEqual(400, o.role[0].games);
    try std.testing.expectEqual(200, o.role[1 + @backingInt(builds.First.dragon)].games);
    try std.testing.expectEqual(0, o.role[1 + @backingInt(builds.First.tower)].games);
    // Under min_games of timelines: none
    try std.testing.expectEqual(null, objectivesIn(f.builds, f.get(122, .jungle).?, .jungle));

    var roles = [_]cp.ChartsRole{.{ .role = .top, .objectives = o }};
    const data: cp.ChartsData = .{ .name = "Darius", .ddragon = "", .champs = &.{}, .roles = &roles };
    var p: cp.Charts = .{ .data = &data, .root = "/" };
    var t: ui.Tree = .{};
    var h: ui.H = .init(a, &t);
    var w: std.Io.Writer.Allocating = .init(a);
    try ui.html.write(&t, p.view(&h), &w.writer);
    // Took first dragon 75% against 50%; won after it 67% against 50%. Only dragon has
    // 100+ takes for a win rate
    for ([_][]const u8{ "Objectives", "Role average", "First Rift Herald", "75%", "Win rate after taking it first", "67%" }) |x|
        try std.testing.expect(std.mem.indexOf(u8, w.written(), x) != null);
}

/// Minutes drawn while this many lanes are still going, as a matchup page's
const lane_min_games = 10;

fn spreadOf(site: *const Site, ch: Champ) ?cp.Spread {
    const s = &site.spread;
    const c = s.get(ch.id) orelse return null;
    if (c.players < s.min_players) return null;
    return .{ .players = c.players, .bins = c.bins, .p25 = c.p25, .p75 = c.p75, .luck_p25 = c.luck_p25, .luck_p75 = c.luck_p75 };
}

fn pickupOf(site: *const Site, ch: Champ) ?cp.Pickup {
    const l = &site.learning;
    const c = l.get(ch.id) orelse return null;
    var bins: [learning.bin_count]cp.Counts = undefined;
    for (&bins, c.bins) |*o, b| o.* = .{ .games = b.games, .wins = b.wins };
    const g = c.gap;
    return .{
        .bins = bins,
        .thin = l.thin_games,
        .gap = if (g) |x| @floatCast(x.pp) else null,
        .usual_gap = @floatCast(l.mean_pp),
        .kind = if (g) |x| switch (x.kind) {
            .harder => .harder,
            .usual => .usual,
            .easier => .easier,
        } else .usual,
        .new = if (g) |x| @floatCast(100 * x.new.winRate()) else null,
        .practised = if (g) |x| @floatCast(100 * x.practised.winRate()) else null,
    };
}

/// What players who main ch also play, as the pool page lists it
fn alsoOf(site: *const Site, ch: Champ) ![]const cp.Also {
    const p = &site.pool;
    const m = for (p.mains) |m| {
        if (m.id == ch.id) break m;
    } else return &.{};
    if (m.players < p.min_players) return &.{};
    var out: std.ArrayList(cp.Also) = .empty;
    for (m.also) |x| {
        if (out.items.len == 6) break;
        const i = for (site.champs, 0..) |c, i| {
            if (c.id == x.id) break i;
        } else continue;
        const harder = if (site.learning.get(x.id)) |lc| if (lc.gap) |g| g.kind == .harder else false else false;
        try out.append(site.arena, .{
            .champ = @intCast(i),
            .lift = @floatCast(x.lift),
            .share = pct(x.together, m.players),
            .harder = harder,
        });
    }
    return out.items;
}

/// What one relation of the matchups counts: ch in r against champions in r2, or with
/// them (ally: duos)
pub const Pairs = struct {
    st: *const Stats,
    r: Role,
    r2: Role,
    ally: bool = false,

    pub fn get(p: Pairs, c: usize, o: usize) Counts {
        return if (p.ally) p.st.ally(p.r, p.r2, c, o) else p.st.enemy(p.r, p.r2, c, o);
    }

    /// usual() of a champion winning `base` in r with or against one winning `strength`
    /// in r2: an ally adds on the log-odds scale what an opponent takes away
    pub fn usualOf(p: Pairs, base: f64, strength: f64) f64 {
        return usual(base, if (p.ally) 1 - strength else strength);
    }
};

/// What ch usually wins against an opponent: ch's own win rate in the role (`base`)
/// moved by the opponent's own there (`strength`), on the log-odds scale. Two 50%
/// champions: 50%; a 53% champion against a 47% one: 55.9%
pub fn usual(base: f64, strength: f64) f64 {
    const logit = struct {
        fn f(x: f64) f64 {
            const c = std.math.clamp(x, 0.01, 0.99);
            return @log(c / (1 - c));
        }
    }.f;
    return 1 / (1 + @exp(logit(strength) - logit(base)));
}

/// A matchup's win rate against usual(), as a share: the matchup's rate pulled toward
/// usual by k games (usualK) minus usual, so (wins - games * usual) / (games + k) and a
/// thin matchup reads near 0. sd: its spread, sqrt(usual (1 - usual) / (games + k))
pub const VsUsual = struct {
    mean: f64,
    sd: f64,

    pub fn of(wins: u32, games: u32, e: f64, k: f64) VsUsual {
        const n: f64 = @floatFromInt(games);
        return .{
            .mean = (@as(f64, @floatFromInt(wins)) - n * e) / (n + k),
            .sd = @sqrt(e * (1 - e) / (n + k)),
        };
    }
};

/// Games to stabilise (k) for a matchup's win rate against usual() in role r: as
/// opponentK, but how much true rates differ from usual(), the opponent's strength
/// allowed for, so less than opponentK's spread and a larger k
pub fn usualK(st: *const Stats, r: Role) f64 {
    return pairsUsualK(.{ .st = st, .r = r, .r2 = r });
}

pub fn pairsUsualK(p: Pairs) f64 {
    var q: f64 = 0;
    var noise: f64 = 0;
    var scale: f64 = 0;
    for (0..p.st.n) |c| {
        const cc = p.st.champRole(p.r, c);
        if (cc.games == 0) continue;
        for (0..p.st.n) |o| {
            const e = p.get(c, o);
            if (o == c or e.games == 0) continue;
            const oc = p.st.champRole(p.r2, o);
            const u = p.usualOf(ratio(cc.wins, cc.games), ratio(oc.wins, oc.games));
            const g: f64 = @floatFromInt(e.games);
            const d = @as(f64, @floatFromInt(e.wins)) - g * u;
            q += d * d / g;
            noise += u * (1 - u);
            scale += g;
        }
    }
    const tau2 = std.math.clamp((q - noise) / @max(scale, 1), 0.0001, 0.01);
    return 0.25 / tau2;
}

/// A share as signed points to one decimal: 0.021 -> "+2.1", -0.0004 -> "0.0"
pub const Points = struct {
    v: f64,

    pub fn format(p: Points, w: *Writer) Writer.Error!void {
        const x = 100 * p.v;
        if (@abs(x) < 0.05) return w.writeAll("0.0");
        if (x > 0) try w.writeByte('+');
        try w.print("{d:.1}", .{x});
    }
};

test "usual and vs usual" {
    try std.testing.expectApproxEqAbs(0.5, usual(0.5, 0.5), 1e-9);
    try std.testing.expectApproxEqAbs(0.5598, usual(0.53, 0.47), 1e-4);
    try std.testing.expectApproxEqAbs(0.53, usual(0.53, 0.5), 1e-9);
    // No games: nothing to say; many: close to the raw difference
    try std.testing.expectEqual(0, VsUsual.of(0, 0, 0.5, 400).mean);
    const d = VsUsual.of(5500, 10000, 0.5, 400);
    try std.testing.expectApproxEqAbs(0.0481, d.mean, 1e-4);
    var buf: [16]u8 = undefined;
    try std.testing.expectEqualStrings("+2.1", try std.mem.print(&buf, "{f}", .{Points{ .v = 0.021 }}));
    try std.testing.expectEqualStrings("-2.1", try std.mem.print(&buf, "{f}", .{Points{ .v = -0.021 }}));
    try std.testing.expectEqualStrings("0.0", try std.mem.print(&buf, "{f}", .{Points{ .v = -0.0004 }}));
}

const RoleGames = struct {
    st: *const Stats,
    c: usize,
    fn more(ctx: RoleGames, a: Role, b: Role) bool {
        return ctx.st.champRole(a, ctx.c).games > ctx.st.champRole(b, ctx.c).games;
    }
};
