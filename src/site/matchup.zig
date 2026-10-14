//! Lane matchup pages: how a lane unfolds minute by minute (core/curvesfile.zig). Every
//! chart carries tier, patch, n and spread; under thin_games it is greyed out as "more
//! data needed" (docs/concept.md). Facts and numbers only, no advice.

const std = @import("std");
const core = @import("core");
const root = @import("root.zig");
const html = @import("html.zig");
const comeback = @import("comeback.zig");
const lanechart = @import("lanechart.zig");
const text = @import("text.zig");

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
/// Minimum games choices on the matchup index; shows everything by default
const index_floors = [_]u32{ 1, 5, 10, 20, 50, 100, thin_games };

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

pub fn path(a: std.mem.Allocator, r: Role, x: Champ, y: Champ) ![]const u8 {
    return a.print("matchup/{s}/{s}-vs-{s}.html", .{ root.roleSlug(r), x.slug, y.slug });
}

/// A matchup's page curve: all ranks, all games. The file has one per bracket and
/// experience (and role baselines, champion 0) for each pair
fn isPage(h: curvesfile.Header) bool {
    return h.bracket == @backingInt(Bracket.all) and h.experience == @backingInt(curvesfile.Experience.any);
}

/// A page per lane matchup with an all-ranks curve of `min_games` or more, from the lower
/// champion id's side
pub fn paths(site: *const Site, curves: *const Curves, list: *std.ArrayList([]const u8), min_games: u32) !void {
    for (curves.curves) |c| {
        const h = c.header;
        if (!isPage(h) or h.games < min_games) continue;
        const x = champ(site, h.a) orelse continue;
        const y = champ(site, h.b) orelse continue;
        const r: Role = @fromBackingInt(@intCast(h.role));
        try list.append(site.arena, try path(site.arena, r, x, y));
    }
}

/// `rest`: "<role>/<a>-vs-<b>" from matchup/<rest>.html; false for no such page
pub fn route(site: *const Site, w: *Writer, curves: *const Curves, rest: []const u8) !bool {
    const slash = std.mem.indexOfScalar(u8, rest, '/') orelse return false;
    const r = root.roleFromSlug(rest[0..slash]) orelse return false;
    var it = std.mem.splitSequence(u8, rest[slash + 1 ..], "-vs-");
    const x = site.champBySlug(it.next().?) orelse return false;
    const y = site.champBySlug(it.next() orelse return false) orelse return false;
    if (it.next() != null or x.id >= y.id) return false;
    if (curves.get(r, .all, x.id, y.id) == null) return false;
    try writePage(site, w, curves, r, x, y);
    return true;
}

/// matchup/index.html: every matchup page by role, most games first
pub fn writeIndex(site: *const Site, w: *Writer, curves: ?*const Curves) !void {
    const a = site.arena;
    const p = site.page(
        if (curves) |c| try a.print("Lane matchup curves, {s} | meiolol", .{try period(a, c)}) else "Lane matchup curves | meiolol",
        "How every lane matchup unfolds minute by minute: gold, experience and CS difference, kills and level 6 timing, by rank.",
        "matchup/index.html",
        .matchups,
    );
    try html.head(w, p);
    try tpl.render(w,
        \\<h1>Lane matchup curves</h1>
        \\<p class="lead">How each lane matchup unfolds, minute by minute: the typical gold,
        \\experience and CS difference with its spread, who tends to lead at 14 minutes and
        \\whether that side then wins the game.</p>
        \\
    , .{});
    const c = curves orelse {
        try tpl.render(w,
            \\<p class="note">Curves need match timelines, which are being collected now. Every matchup gets a page; under 200 games it is shown greyed out as "more data needed".</p>
            \\
        , .{});
        return html.foot(w, p);
    };
    try html.minGames(w, "../", "matchups", &index_floors, index_floors[0], 0);
    for (Role.all) |r| {
        var list: std.ArrayList(IndexEntry) = .empty;
        for (c.curves) |cv| {
            const h = cv.header;
            if (h.role != @backingInt(r) or !isPage(h)) continue;
            const x = champ(site, h.a) orelse continue;
            const y = champ(site, h.b) orelse continue;
            try list.append(a, .{ .x = x, .y = y, .games = h.games, .thin = thin(.{ .curve = &cv, .flipped = false }) });
        }
        std.mem.sort(IndexEntry, list.items, {}, struct {
            fn f(_: void, p_: IndexEntry, q: IndexEntry) bool {
                return p_.games > q.games;
            }
        }.f);
        const slug = root.roleSlug(r);
        try tpl.render(w,
            \\<h2>{role} <span class="muted"><span id="n-{slug}">{n}</span> matchups</span></h2>
            \\
        , .{ .role = root.roleName(r), .slug = slug, .n = list.items.len });
        if (list.items.len == 0) {
            try tpl.render(w, "<p class=\"muted\">More data needed.</p>\n", .{});
            continue;
        }
        try tpl.render(w,
            \\<ul class="matchup-list" data-min-list data-count="n-{slug}">
            \\{items}</ul>
            \\
        , .{ .slug = slug, .items = tpl.each(list.items, .{ a, r }, indexItem) });
    }
    try html.foot(w, p);
}

const IndexEntry = struct { x: Champ, y: Champ, games: u32, thin: bool };

fn indexItem(ctx: struct { std.mem.Allocator, Role }, w: *Writer, e: IndexEntry) !void {
    try tpl.render(w,
        \\<li data-games="{games}"{thin}><a href="{href}">{x} vs {y}</a> <span class="muted">{games} game{s}</span></li>
        \\
    , .{
        .games = e.games,
        .thin = tpl.flag(e.thin, "class=\"thin\""),
        .href = (try path(ctx[0], ctx[1], e.x, e.y))["matchup/".len..],
        .x = e.x.name,
        .y = e.y.name,
        .s = plural(e.games),
    });
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
            .label = try a.print("{s} players with {d}k+ mastery", .{ s[0].name, curvesfile.experienced_points / 1000 }),
        });
    }
    return list.items;
}

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
    const page_path = try path(a, r, x, y);
    var p = site.page(title, desc, page_path, .matchups);
    p.index = v.games() >= site.opts.index_min_games;
    for (html.View.all, site.view_curves, &p.counterparts.?) |view, *other, *there| {
        const has = if (other.*) |*o| o.get(r, .all, x.id, y.id) != null else false;
        if (!has) there.* = try std.mem.concat(a, u8, &.{ view.dir(), "matchup/index.html" });
    }
    try html.head(w, p);
    try tpl.render(w,
        \\<div class="hero"><img src="{x_icon}" alt="" width="72" height="72"><img src="{y_icon}" alt="" width="72" height="72"><div><h1>{x} vs {y}</h1>
        \\<p class="muted">{lane} lane, ranked solo/duo {region}, {when}, all ranks, {games} game{s}.</p></div></div>
        \\
    , .{
        .x_icon = site.icon(x),
        .y_icon = site.icon(y),
        .x = x.name,
        .y = y.name,
        .lane = lane,
        .region = site.view.region.in(),
        .when = when,
        .games = v.games(),
        .s = plural(v.games()),
    });
    if (v.games() < thin_games) {
        try tpl.render(w,
            \\<p class="note">More data needed: {games} game{s} so far. Until {thin}, the line leans on how these two champions do against everyone (see the method), and the chart is greyed out.</p>
            \\
        , .{ .games = v.games(), .s = plural(v.games()), .thin = thin_games });
    } else if (thin(v)) {
        try tpl.render(w,
            \\<p class="note">Mostly the champions' baseline: the line still leans more on how these two champions do against everyone than on their games against each other (see the method).</p>
            \\
        , .{});
    }
    try summary(w, v, x, y);

    const vs = try variants(a, curves, r, x, y);
    if (vs.len > 1) {
        try tpl.renderPart(w, "<fieldset class=\"exp-toggle\"><legend>Games counted</legend>", .{});
        for (vs, 0..) |s, i| {
            try tpl.render(w, "<label><input type=\"radio\" name=\"exp\" value=\"{key}\" id=\"exp-{key}\"{checked}> {label} <span class=\"muted\">({games})</span></label> ", .{
                .key = s.key,
                .checked = tpl.flag(i == 0, "checked"),
                .label = s.label,
                .games = s.v.games(),
            });
        }
        try tpl.renderPart(w, "</fieldset>\n", .{});
    }

    const base = curves.baseline(r, .all);
    const Chart = struct { title: []const u8, metric: curvesfile.Metric, unit: []const u8 };
    const charts = [_]Chart{
        .{ .title = "Gold difference", .metric = .gold, .unit = "gold" },
        .{ .title = "Experience difference", .metric = .xp, .unit = "XP" },
        .{ .title = "CS difference", .metric = .cs, .unit = "CS" },
    };
    for (charts) |c| {
        try tpl.render(w, "<h2>{title}</h2>\n", .{ .title = c.title });
        try chart(w, vs, base, c.metric, c.unit, x, y, when, lane);
    }

    try tpl.render(w, "<h2>Lane and game</h2>\n", .{});
    for (vs) |s| {
        if (vs.len == 1) try sides(w, s.v, x, y) else try tpl.render(w,
            \\<div class="exp exp-{key}">
            \\{sides}</div>
            \\
        , .{ .key = s.key, .sides = tpl.call(sides, .{ s.v, x, y }) });
    }
    try comeback.section(w, curves, r, x, y);
    try tpl.render(w, "<h2>By rank</h2>\n", .{});
    try brackets(w, curves, r, x, y);
    const to_site = site.toShared(page_path);
    try tpl.render(w,
        \\<p class="muted"><a href="{x_href}">{x}</a> · <a href="{y_href}">{y}</a> · <a href="{up}method.html">Method</a></p>
        \\
    , .{
        .x_href = site.champHref(x, to_site),
        .x = x.name,
        .y_href = site.champHref(y, to_site),
        .y = y.name,
        .up = to_site,
    });
    try html.foot(w, p);
}

/// The landing page's lead: one matchup's gold curve, the clearest lane among those
/// out of "more data needed" (the most games while none is)
pub fn featured(site: *const Site, w: *Writer, curves: *const Curves, matchups: usize) !void {
    var best: ?struct { r: Role, x: Champ, y: Champ, v: View, score: f64 } = null;
    for (curves.curves) |c| {
        const h = c.header;
        if (!isPage(h)) continue;
        const x = champ(site, h.a) orelse continue;
        const y = champ(site, h.b) orelse continue;
        const r: Role = @fromBackingInt(@intCast(h.role));
        const v = curves.get(r, .all, x.id, y.id) orelse continue;
        const e = v.estimate(.gold, curvesfile.lane_minute - 1);
        const games: f64 = @floatFromInt(v.games());
        const score = if (thin(v)) games else 1e9 + @as(f64, @floatFromInt(@abs(e.mean)));
        if (best == null or score > best.?.score) best = .{ .r = r, .x = x, .y = y, .v = v, .score = score };
    }
    const b = best orelse return;
    // From x's side, the side ahead at 14 minutes, so the line reads upwards
    const flip = b.v.estimate(.gold, curvesfile.lane_minute - 1).mean < 0;
    const x = if (flip) b.y else b.x;
    const y = if (flip) b.x else b.y;
    const v = curves.get(b.r, .all, x.id, y.id).?;
    const lane = root.roleName(b.r);
    const when = try period(site.arena, curves);
    const page_path = try path(site.arena, b.r, b.x, b.y);
    try tpl.renderPart(w,
        \\<section class="featured"><h2>{x} vs {y}, {lane} lane: gold difference by minute</h2>
        \\
    , .{ .x = x.name, .y = y.name, .lane = lane });
    try summary(w, v, x, y);
    const one = [_]Variant{.{ .v = v, .key = "any", .label = "All games" }};
    try chart(w, &one, curves.baseline(b.r, .all), .gold, "gold", x, y, when, lane);
    try tpl.renderPart(w,
        \\<p><a href="{href}">Experience, CS, kills, item timings and ranks for this matchup</a> · <a href="{all}">All {n} matchups</a></p></section>
        \\
    , .{
        .href = page_path,
        .all = @as([]const u8, "matchup/index.html"),
        .n = matchups,
    });
}

fn summary(w: *Writer, v: View, x: Champ, y: Champ) !void {
    const lane = v.lane();
    const i = curvesfile.lane_minute - 1;
    const m = v.minute(i);
    const ahead = tpl.call(percent, .{ lane.ahead, lane.games });
    const gold = if (m.n >= minuteFloor(v)) blk: {
        const e = v.estimate(.gold, i);
        // The share in the thin case is raw and can disagree with a line that leans on the
        // baseline
        break :blk tpl.t("At {minute} minutes {x} is on average {amount} against {y}{thin}{own}", .{
            .minute = curvesfile.lane_minute,
            .x = x.name,
            .amount = tpl.call(amount, .{ e.mean, "gold" }),
            .y = y.name,
            .thin = tpl.when(thin(v), tpl.t(", mostly from how both champions do against everyone. In these {games} game{s} {x} led in gold at {minute} minutes in {ahead}. ", .{
                .games = v.games(),
                .s = plural(v.games()),
                .x = x.name,
                .minute = curvesfile.lane_minute,
                .ahead = ahead,
            })),
            .own = tpl.when(!thin(v), tpl.t(" (8 games in 10 between {p10} and {p90}), and leads in gold in {ahead} of games. ", .{
                .p10 = tpl.call(signed, .{m.gold.p10}),
                .p90 = tpl.call(signed, .{m.gold.p90}),
                .ahead = ahead,
            })),
        });
    } else null;
    try tpl.render(w,
        \\<p class="lead">{gold}{x} wins {wins} of these games{split}.</p>
        \\
    , .{
        .gold = gold,
        .x = x.name,
        .wins = tpl.call(percent, .{ v.wins(), v.games() }),
        .split = tpl.when(lane.ahead >= min_minute_games and lane.behind >= min_minute_games, tpl.t(": {ahead} when ahead at {minute} minutes, {behind} when behind", .{
            .ahead = tpl.call(percent, .{ lane.wins_ahead, lane.ahead }),
            .minute = curvesfile.lane_minute,
            .behind = tpl.call(percent, .{ lane.wins_behind, lane.behind }),
        })),
    });
}

fn amount(w: *Writer, value: i16, unit: []const u8) !void {
    if (value == 0) return tpl.render(w, "even in {unit}", .{ .unit = unit });
    try tpl.render(w, "{gold} {unit} {side}", .{
        .gold = @abs(value),
        .unit = unit,
        .side = if (value > 0) "ahead" else "behind",
    });
}

fn signed(w: *Writer, value: i32) !void {
    try tpl.render(w, "{sign}{value}", .{ .sign = if (value > 0) "+" else "", .value = value });
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

/// Where 8 games in 10 end at minute i, from the same games as band
pub fn range(v: View, base: ?View, metric: curvesfile.Metric, i: usize) [2]i32 {
    const q = spreadAt(v, base, metric, i);
    return .{ q.p10, q.p90 };
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

/// Estimated average line and middle-half band of `metric` by minute, an SVG per
/// variant, each on its own scale (the experienced toggle shows one)
fn chart(
    w: *Writer,
    vs: []const Variant,
    base: ?View,
    metric: curvesfile.Metric,
    unit: []const u8,
    x: Champ,
    y: Champ,
    when: []const u8,
    lane: []const u8,
) !void {
    for (vs) |s| try chartOne(w, s, vs.len > 1, base, metric, unit, x, y, when, lane);
}

fn chartOne(
    w: *Writer,
    one: Variant,
    toggle: bool,
    base: ?View,
    metric: curvesfile.Metric,
    unit: []const u8,
    x: Champ,
    y: Champ,
    when: []const u8,
    lane: []const u8,
) !void {
    const last = reach(one.v);
    const figure = .{
        .thin = if (thin(one.v)) " thin" else "",
        .exp = tpl.when(toggle, " exp exp-"),
        .key = tpl.when(toggle, one.key),
    };
    if (last < 2) {
        return tpl.render(w,
            \\<figure class="chart{thin}{exp}{key}">
            \\<p class="muted">Not enough games yet.</p></figure>
            \\
        , figure);
    }
    var bands: [curvesfile.max_minutes][2]i32 = undefined;
    var line: [curvesfile.max_minutes]i32 = undefined;
    for (0..last) |i| {
        bands[i] = band(one.v, base, metric, i);
        line[i] = one.v.estimate(metric, i).mean;
    }
    var aria_buf: [160]u8 = undefined;
    const aria = std.fmt.bufPrint(&aria_buf, "{s} of {s} minus {s} by minute", .{ unit, x.name, y.name }) catch unit;
    try tpl.renderPart(w, "<figure class=\"chart{thin}{exp}{key}\">\n", figure);
    try lanechart.render(w, .{
        .aria = aria,
        .a = x.name,
        .b = y.name,
        .band = bands[0..last],
        .line = line[0..last],
    });
    try caption(w, one.v, base, metric, x, y, when, lane);
    try tpl.renderPart(w, "</figure>\n", .{});
}

fn caption(w: *Writer, v: View, base: ?View, metric: curvesfile.Metric, x: Champ, y: Champ, when: []const u8, lane: []const u8) !void {
    const last = reach(v);
    if (last < 2) return tpl.render(w, "<figcaption>Not enough games yet.</figcaption>\n", .{});
    const games = v.games();
    const own = games >= thin_games or base == null;
    try tpl.renderPart(w,
        \\<figcaption>{x} minus {y}: line = estimated average; band = {own}{baseline}; {when}, all ranks, n = {games} game{s} ({going} still going at {last} min)
    , .{
        .x = x.name,
        .y = y.name,
        .own = tpl.when(own, "middle half of games"),
        .baseline = tpl.when(!own, tpl.t("middle half of all {lane} lanes, around the line (too few games for this matchup's own)", .{ .lane = lane })),
        .when = when,
        .games = games,
        .s = plural(games),
        .going = v.minute(last - 1).n,
        .last = last,
    });
    if (last >= curvesfile.lane_minute) {
        const e = v.estimate(metric, curvesfile.lane_minute - 1);
        const r = range(v, base, metric, curvesfile.lane_minute - 1);
        try tpl.renderPart(w, ". At {minute} min: average {mean}, 8 games in 10 between {p10} and {p90}", .{
            .minute = curvesfile.lane_minute,
            .mean = tpl.call(signed, .{e.mean}),
            .p10 = tpl.call(signed, .{r[0]}),
            .p90 = tpl.call(signed, .{r[1]}),
        });
    }
    try ended(w, if (own) v else base.?, last);
    try tpl.renderPart(w, ".</figcaption>\n", .{});
}

/// Surrender opens at 15 minutes: before it nearly all games are still running
const surrender_minute = lanechart.surrender_minute;

/// "From 15 min only games still running count": the share ended by 20 and 25 min
fn ended(w: *Writer, v: View, last: usize) !void {
    if (last <= surrender_minute) return;
    const total = v.games();
    if (total == 0) return;
    try tpl.render(w, ". Right of the dotted line ({minute} min), only games still running count: ", .{ .minute = surrender_minute });
    for ([_]usize{ 20, 25 }, 0..) |m, k| {
        if (m > last) continue;
        try tpl.render(w, "{sep}{share} had ended by {minute} min", .{
            .sep = tpl.when(k > 0, ", "),
            .share = tpl.call(percent, .{ total -| v.minute(m - 1).n, total }),
            .minute = m,
        });
    }
}

fn sides(w: *Writer, v: View, x: Champ, y: Champ) !void {
    const lane = v.lane();
    try tpl.renderPart(w,
        \\<div class="table-scroll"><table>
        \\<thead><tr><th></th><th class="num">{x}</th><th class="num">{y}</th></tr></thead>
        \\<tbody>
        \\<tr><td>Ahead in gold at {minute} min</td><td class="num">{ahead}</td><td class="num">{behind}</td></tr>
        \\<tr><td>Wins the game</td><td class="num">{wins}</td><td class="num">{losses}</td></tr>
        \\<tr><td>Wins when ahead at {minute} min</td><td class="num">{wins_ahead}</td><td class="num">{wins_behind}</td></tr>
        \\
    , .{
        .x = x.name,
        .y = y.name,
        .minute = curvesfile.lane_minute,
        .ahead = tpl.call(percent, .{ lane.ahead, lane.games }),
        .behind = tpl.call(percent, .{ lane.behind, lane.games }),
        .wins = tpl.call(percent, .{ v.wins(), v.games() }),
        .losses = tpl.call(percent, .{ v.games() - v.wins(), v.games() }),
        .wins_ahead = tpl.call(percent, .{ lane.wins_ahead, lane.ahead }),
        .wins_behind = tpl.call(percent, .{ lane.behind - lane.wins_behind, lane.behind }),
    });
    const phase_names = [_][]const u8{ "before 6 min", "6 to 14 min", "after 14 min" };
    for (phase_names, 0..) |name, ph| {
        try tpl.render(w,
            \\<tr><td>Takes part in killing the other, {phase}</td><td class="num">{kills}</td><td class="num">{deaths}</td></tr>
            \\
        , .{
            .phase = name,
            .kills = tpl.call(percent, .{ v.kills(ph), v.games() }),
            .deaths = tpl.call(percent, .{ v.deaths(ph), v.games() }),
        });
    }
    try timing(w, "Level 6 (median)", v.level6());
    try timing(w, "First finished item (median)", v.firstItem());
    try tpl.renderPart(w,
        \\</tbody></table></div>
        \\<p class="muted">Share of {games} game{s}. A finished item costs 2,200 gold or more and builds into nothing; a dash means fewer than half of the games got there.</p>
        \\
    , .{ .games = v.games(), .s = plural(v.games()) });
}

fn timing(w: *Writer, label: []const u8, both: [2]u16) !void {
    try tpl.render(w, "<tr><td>{label}</td>{x}{y}</tr>\n", .{
        .label = label,
        .x = tpl.call(time, .{both[0]}),
        .y = tpl.call(time, .{both[1]}),
    });
}

fn time(w: *Writer, secs: u16) !void {
    if (secs == 0) return tpl.render(w, "<td class=\"num\">-</td>", .{});
    try tpl.render(w, "<td class=\"num\">{min}:{sec:0>2}</td>", .{ .min = secs / 60, .sec = secs % 60 });
}

fn brackets(w: *Writer, curves: *const Curves, r: Role, x: Champ, y: Champ) !void {
    try tpl.renderPart(w,
        \\<div class="table-scroll"><table>
        \\<thead><tr><th>Rank</th><th class="num">Games</th><th class="num">Gold at {minute} min</th><th class="num">{x} ahead at {minute} min</th><th class="num">{x} wins</th></tr></thead>
        \\<tbody>
        \\
    , .{ .minute = curvesfile.lane_minute, .x = x.name });
    for (std.enums.values(Bracket)) |b| {
        const v = curves.get(r, b, x.id, y.id) orelse {
            try tpl.render(w,
                \\<tr class="thin"><td>{rank}</td><td class="num" colspan="4">more data needed</td></tr>
                \\
            , .{ .rank = b.label() });
            continue;
        };
        const i = curvesfile.lane_minute - 1;
        const has_gold = v.minute(i).n >= minuteFloor(v);
        const gold = if (has_gold) blk: {
            const e = v.estimate(.gold, i);
            const g = range(v, curves.baseline(r, b), .gold, i);
            break :blk tpl.t("{mean} <small>{p10} to {p90}</small>", .{
                .mean = tpl.call(signed, .{e.mean}),
                .p10 = tpl.call(signed, .{g[0]}),
                .p90 = tpl.call(signed, .{g[1]}),
            });
        } else null;
        try tpl.render(w,
            \\<tr{thin}><td>{rank}</td><td class="num">{games}</td><td class="num">{gold}{dash}</td><td class="num">{ahead}</td><td class="num">{wins}</td></tr>
            \\
        , .{
            .thin = tpl.flag(thin(v), "class=\"thin\""),
            .rank = b.label(),
            .games = v.games(),
            .gold = gold,
            .dash = tpl.when(!has_gold, "-"),
            .ahead = tpl.call(percent, .{ v.lane().ahead, v.lane().games }),
            .wins = tpl.call(percent, .{ v.wins(), v.games() }),
        });
    }
    try tpl.renderPart(w,
        \\</tbody></table></div>
        \\<p class="muted">Rank is the median visible tier of the players in each game. Gold is the estimated average, then where 8 games in 10 end (the 10th to 90th percentile); a rank's estimate leans on the all-ranks one until it has games of its own. Rows under {thin} games, or mostly baseline, are greyed out.</p>
        \\
    , .{ .thin = thin_games });
}

test "nice scale" {
    try std.testing.expectEqual(1, lanechart.niceCeil(0));
    try std.testing.expectEqual(500, lanechart.niceCeil(420));
    try std.testing.expectEqual(600, lanechart.niceCeil(501));
    try std.testing.expectEqual(2000, lanechart.niceCeil(1001));
    try std.testing.expectEqual(3000, lanechart.niceCeil(2120));
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
