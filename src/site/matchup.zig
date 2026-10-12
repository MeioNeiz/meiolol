//! Lane matchup pages: how a lane unfolds minute by minute (core/curvesfile.zig). Every
//! chart carries tier, patch, n and spread; under thin_games it is greyed out as "more
//! data needed" (docs/concept.md). Facts and numbers only, no advice.

const std = @import("std");
const core = @import("core");
const root = @import("root.zig");
const html = @import("html.zig");
const comeback = @import("comeback.zig");

const Writer = std.Io.Writer;
const Role = core.Role;
const curvesfile = core.curvesfile;
const Curves = curvesfile.Curves;
const View = curvesfile.View;
const Bracket = curvesfile.Bracket;
const Site = root.Site;
const Champ = root.Champ;
const esc = html.esc;

/// Below this many games a curve is greyed out as "more data needed"
pub const thin_games = 200;
/// Minutes with fewer games still going are not drawn
const min_minute_games = 10;
/// Experienced-only curves with fewer games are not offered
const min_experienced = 10;
/// Matchup links on a champion page, per role
/// Minimum games choices on the matchup index; shows everything by default
const index_floors = [_]u32{ 1, 5, 10, 20, 50, 100, thin_games };

/// A thinner matchup (greyed out anyway) draws minutes while all its games are going
fn minuteFloor(v: View) u32 {
    return @max(1, @min(min_minute_games, v.games()));
}

/// The curves' games for running text: "last 30 days" or "patch 16.19"
fn period(a: std.mem.Allocator, curves: *const Curves) ![]const u8 {
    const label = curves.patch();
    if (label.len > 0 and std.ascii.isDigit(label[0])) return std.fmt.allocPrint(a, "patch {s}", .{label});
    return label;
}

pub fn plural(n: u64) []const u8 {
    return if (n == 1) "" else "s";
}

pub fn path(a: std.mem.Allocator, r: Role, x: Champ, y: Champ) ![]const u8 {
    return std.fmt.allocPrint(a, "matchup/{s}/{s}-vs-{s}.html", .{ root.roleSlug(r), x.slug, y.slug });
}

/// A page per lane matchup with an all-ranks curve, from the lower champion id's side
pub fn paths(site: *const Site, curves: *const Curves, list: *std.ArrayList([]const u8)) !void {
    for (curves.curves) |c| {
        const h = c.header;
        if (h.bracket != @intFromEnum(Bracket.all)) continue;
        const x = champ(site, h.a) orelse continue;
        const y = champ(site, h.b) orelse continue;
        const r: Role = @enumFromInt(h.role);
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
        if (curves) |c| try std.fmt.allocPrint(a, "Lane matchup curves, {s} | meiolol", .{try period(a, c)}) else "Lane matchup curves | meiolol",
        "How every lane matchup unfolds minute by minute: gold, experience and CS difference, kills and level 6 timing, by rank.",
        "matchup/index.html",
        .matchups,
    );
    try html.head(w, p);
    try w.writeAll(
        \\<h1>Lane matchup curves</h1>
        \\<p class="lead">How each lane matchup unfolds, minute by minute: the typical gold,
        \\experience and CS difference with its spread, who tends to lead at 14 minutes and
        \\whether that side then wins the game.</p>
        \\
    );
    const c = curves orelse {
        try w.writeAll("<p class=\"note\">Curves need match timelines, which are being collected now. Every matchup gets a page; under 200 games it is shown greyed out as \"more data needed\".</p>\n");
        return html.foot(w, p);
    };
    try html.minGames(w, "../", "matchups", &index_floors, index_floors[0], 0);
    const Entry = struct { x: Champ, y: Champ, games: u32, thin: bool };
    for (Role.all) |r| {
        var list: std.ArrayList(Entry) = .empty;
        for (c.curves) |cv| {
            const h = cv.header;
            if (h.role != @intFromEnum(r) or h.bracket != 0 or h.experience != 0) continue;
            const x = champ(site, h.a) orelse continue;
            const y = champ(site, h.b) orelse continue;
            try list.append(a, .{ .x = x, .y = y, .games = h.games, .thin = thin(.{ .curve = &cv, .flipped = false }) });
        }
        std.mem.sort(Entry, list.items, {}, struct {
            fn f(_: void, p_: Entry, q: Entry) bool {
                return p_.games > q.games;
            }
        }.f);
        const slug = root.roleSlug(r);
        try w.print("<h2>{s} <span class=\"muted\"><span id=\"n-{s}\">{d}</span> matchups</span></h2>\n", .{
            root.roleName(r), slug, list.items.len,
        });
        if (list.items.len == 0) {
            try w.writeAll("<p class=\"muted\">More data needed.</p>\n");
            continue;
        }
        try w.print("<ul class=\"matchup-list\" data-min-list data-count=\"n-{s}\">\n", .{slug});
        for (list.items) |e| {
            try w.print("<li data-games=\"{d}\"{s}><a href=\"{s}\">{f} vs {f}</a> <span class=\"muted\">{d} game{s}</span></li>\n", .{
                e.games,
                if (e.thin) " class=\"thin\"" else "",
                (try path(a, r, e.x, e.y))["matchup/".len..],
                esc(e.x.name),
                esc(e.y.name),
                e.games,
                plural(e.games),
            });
        }
        try w.writeAll("</ul>\n");
    }
    try html.foot(w, p);
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
            .label = try std.fmt.allocPrint(a, "{s} players with {d}k+ mastery", .{ s[0].name, curvesfile.experienced_points / 1000 }),
        });
    }
    return list.items;
}

fn writePage(site: *const Site, w: *Writer, curves: *const Curves, r: Role, x: Champ, y: Champ) !void {
    const a = site.arena;
    const v = curves.get(r, .all, x.id, y.id).?;
    const lane = root.roleName(r);
    const when = try period(a, curves);
    const title = try std.fmt.allocPrint(a, "{s} vs {s}, {s} lane curves, {s} | meiolol", .{
        x.name, y.name, lane, when,
    });
    const desc = try std.fmt.allocPrint(a, "How {s} against {s} in {s} lane unfolds minute by minute: gold, experience and CS difference, kills, level 6 and first item timing.", .{
        x.name, y.name, lane,
    });
    const page_path = try path(a, r, x, y);
    var p = site.page(title, desc, page_path, .matchups);
    for (html.View.all, site.view_curves, &p.counterparts.?) |view, *other, *there| {
        const has = if (other.*) |*o| o.get(r, .all, x.id, y.id) != null else false;
        if (!has) there.* = try std.mem.concat(a, u8, &.{ view.dir(), "matchup/index.html" });
    }
    try html.head(w, p);
    try w.print(
        "<div class=\"hero\"><img src=\"{s}\" alt=\"\" width=\"72\" height=\"72\"><img src=\"{s}\" alt=\"\" width=\"72\" height=\"72\"><div><h1>{f} vs {f}</h1>\n",
        .{ site.icon(x), site.icon(y), esc(x.name), esc(y.name) },
    );
    try w.print("<p class=\"muted\">{s} lane, ranked solo/duo {s}, {s}, all ranks, {d} game{s}.</p></div></div>\n", .{
        lane, site.view.region.in(), when, v.games(), plural(v.games()),
    });
    if (v.games() < thin_games) {
        try w.print(
            "<p class=\"note\">More data needed: {d} game{s} so far. Until {d}, the line leans on how these two champions do against everyone (see the method), and the chart is greyed out.</p>\n",
            .{ v.games(), plural(v.games()), thin_games },
        );
    } else if (thin(v)) {
        try w.writeAll("<p class=\"note\">Mostly the champions' baseline: the line still leans more on how these two champions do against everyone than on their games against each other (see the method).</p>\n");
    }
    try summary(w, v, x, y);

    const vs = try variants(a, curves, r, x, y);
    if (vs.len > 1) {
        try w.writeAll("<fieldset class=\"exp-toggle\"><legend>Games counted</legend>");
        for (vs, 0..) |s, i| {
            try w.print(
                "<label><input type=\"radio\" name=\"exp\" value=\"{s}\" id=\"exp-{s}\"{s}> {f} <span class=\"muted\">({d})</span></label> ",
                .{ s.key, s.key, if (i == 0) " checked" else "", esc(s.label), s.v.games() },
            );
        }
        try w.writeAll("</fieldset>\n");
    }

    const base = curves.baseline(r, .all);
    const Chart = struct { title: []const u8, metric: curvesfile.Metric, unit: []const u8 };
    const charts = [_]Chart{
        .{ .title = "Gold difference", .metric = .gold, .unit = "gold" },
        .{ .title = "Experience difference", .metric = .xp, .unit = "XP" },
        .{ .title = "CS difference", .metric = .cs, .unit = "CS" },
    };
    for (charts) |c| {
        try w.print("<h2>{s}</h2>\n", .{c.title});
        try chart(w, vs, base, c.metric, c.unit, x, y, when, lane);
    }

    try w.writeAll("<h2>Lane and game</h2>\n");
    for (vs) |s| {
        if (vs.len > 1) try w.print("<div class=\"exp exp-{s}\">\n", .{s.key});
        try sides(w, s.v, x, y);
        if (vs.len > 1) try w.writeAll("</div>\n");
    }
    try comeback.section(w, curves, r, x, y);
    try w.writeAll("<h2>By rank</h2>\n");
    try brackets(w, curves, r, x, y);
    const to_site = site.toShared(page_path);
    try w.print(
        "<p class=\"muted\"><a href=\"{f}\">{f}</a> · <a href=\"{f}\">{f}</a> · <a href=\"{s}method.html\">Method</a></p>\n",
        .{ esc(site.champHref(x, to_site)), esc(x.name), esc(site.champHref(y, to_site)), esc(y.name), to_site },
    );
    try html.foot(w, p);
}

fn summary(w: *Writer, v: View, x: Champ, y: Champ) !void {
    const lane = v.lane();
    try w.writeAll("<p class=\"lead\">");
    const i = curvesfile.lane_minute - 1;
    const m = v.minute(i);
    if (m.n >= minuteFloor(v)) {
        const e = v.estimate(.gold, i);
        try w.print("At {d} minutes {f} is on average ", .{ curvesfile.lane_minute, esc(x.name) });
        try amount(w, e.mean, "gold");
        try w.print(" against {f} (±{d}", .{ esc(y.name), 2 * @as(u32, e.se) });
        if (thin(v)) {
            // The share below is raw and can disagree with a line that leans on the baseline
            try w.print("), mostly from how both champions do against everyone. In these {d} game{s} {f} led in gold at {d} minutes in ", .{
                v.games(), plural(v.games()), esc(x.name), curvesfile.lane_minute,
            });
            try percent(w, lane.ahead, lane.games);
            try w.writeAll(". ");
        } else {
            try w.print("; middle half of games: {d} to {d}), and leads in gold in ", .{ m.gold.p25, m.gold.p75 });
            try percent(w, lane.ahead, lane.games);
            try w.writeAll(" of games. ");
        }
    }
    try w.print("{f} wins ", .{esc(x.name)});
    try percent(w, v.wins(), v.games());
    try w.writeAll(" of these games");
    if (lane.ahead >= min_minute_games and lane.behind >= min_minute_games) {
        try w.writeAll(": ");
        try percent(w, lane.wins_ahead, lane.ahead);
        try w.print(" when ahead at {d} minutes, ", .{curvesfile.lane_minute});
        try percent(w, lane.wins_behind, lane.behind);
        try w.writeAll(" when behind");
    }
    try w.writeAll(".</p>\n");
}

fn amount(w: *Writer, value: i16, unit: []const u8) !void {
    if (value == 0) return w.print("even in {s}", .{unit});
    try w.print("{d} {s} {s}", .{ @abs(value), unit, if (value > 0) "ahead" else "behind" });
}

fn percent(w: *Writer, part: u64, whole: u64) !void {
    if (whole == 0) return w.writeAll("-");
    try w.print("{d:.0}%", .{100 * @as(f64, @floatFromInt(part)) / @as(f64, @floatFromInt(whole))});
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
    const m = v.minute(i);
    if (v.games() >= thin_games or base == null) {
        const q = quartile(m, metric);
        return .{ q.p25, q.p75 };
    }
    const e: i32 = m.est[@intFromEnum(metric)].mean;
    const q = quartile(base.?.minute(i), metric);
    return .{ e + q.p25, e + q.p75 };
}

fn quartile(m: curvesfile.Minute, metric: curvesfile.Metric) curvesfile.Quartiles {
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
    const vs: []const Variant = &.{one};
    var max_abs: u32 = 0;
    var longest: usize = 0;
    for (vs) |s| {
        const last = reach(s.v);
        longest = @max(longest, last);
        for (0..last) |i| {
            const b = band(s.v, base, metric, i);
            max_abs = @max(max_abs, @abs(b[0]), @abs(b[1]), @abs(@as(i32, s.v.estimate(metric, i).mean)));
        }
    }
    try w.print("<figure class=\"chart{s}", .{if (thin(one.v)) " thin" else ""});
    if (toggle) try w.print(" exp exp-{s}", .{one.key});
    try w.writeAll("\">\n");
    if (longest < 2) {
        try w.writeAll("<p class=\"muted\">Not enough games yet.</p></figure>\n");
        return;
    }
    const scale = niceCeil(@intCast(max_abs));
    const width = 640;
    const height = 240;
    const left = 56;
    const right = 28;
    const top = 16;
    const bottom = 28;
    const mid: f64 = top + (height - top - bottom) / 2.0;
    const half: f64 = (height - top - bottom) / 2.0;
    const px = struct {
        fn f(i: usize, n: usize) f64 {
            return left + @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(n - 1)) * (width - left - right);
        }
    }.f;
    const py = struct {
        fn f(value: i32, s: i32, mid_: f64, half_: f64) f64 {
            return mid_ - @as(f64, @floatFromInt(value)) / @as(f64, @floatFromInt(s)) * half_;
        }
    }.f;

    try w.print(
        "<svg viewBox=\"0 0 {d} {d}\" role=\"img\" aria-label=\"{s} of {f} minus {f} by minute\">\n",
        .{ width, height, unit, esc(x.name), esc(y.name) },
    );
    for ([_]i32{ scale, 0, -scale }) |tick| {
        const ty = py(tick, scale, mid, half);
        try w.print("<line class=\"{s}\" x1=\"{d}\" x2=\"{d}\" y1=\"{d:.1}\" y2=\"{d:.1}\"/>", .{
            if (tick == 0) "zero" else "grid", left, width - right, ty, ty,
        });
        try w.print("<text x=\"{d}\" y=\"{d:.1}\" text-anchor=\"end\">{s}{d}</text>\n", .{
            left - 6, ty + 4, if (tick > 0) "+" else "", tick,
        });
    }
    var minute: usize = 5;
    while (minute <= longest) : (minute += 5) {
        try w.print("<text x=\"{d:.1}\" y=\"{d}\" text-anchor=\"middle\">{d} min</text>", .{
            px(minute - 1, longest), height - 8, minute,
        });
    }
    // Before this minute nearly every game is still running (no surrender vote yet)
    if (longest > surrender_minute) {
        const sx = px(surrender_minute - 1, longest);
        try w.print("<line class=\"ending\" x1=\"{d:.1}\" x2=\"{d:.1}\" y1=\"{d}\" y2=\"{d}\"/>", .{ sx, sx, top, height - bottom });
    }
    try w.print("<text x=\"{d}\" y=\"{d}\" class=\"side\">{f} ahead</text>", .{ left + 6, top + 12, esc(x.name) });
    try w.print("<text x=\"{d}\" y=\"{d}\" class=\"side\">{f} ahead</text>\n", .{
        left + 6, height - bottom - 6, esc(y.name),
    });

    for (vs) |s| {
        const last = reach(s.v);
        if (last < 2) continue;
        try w.writeAll("<polygon class=\"band\" points=\"");
        for (0..last) |i| try w.print("{d:.1},{d:.1} ", .{ px(i, longest), py(band(s.v, base, metric, i)[1], scale, mid, half) });
        var i = last;
        while (i > 0) {
            i -= 1;
            try w.print("{d:.1},{d:.1} ", .{ px(i, longest), py(band(s.v, base, metric, i)[0], scale, mid, half) });
        }
        try w.writeAll("\"/>\n<polyline class=\"median\" points=\"");
        for (0..last) |j| {
            try w.print("{d:.1},{d:.1} ", .{ px(j, longest), py(s.v.estimate(metric, j).mean, scale, mid, half) });
        }
        try w.writeAll("\"/>\n");
    }
    try w.writeAll("</svg>\n");
    for (vs) |s| {
        const last = reach(s.v);
        try w.writeAll("<figcaption>");
        if (last < 2) {
            try w.writeAll("Not enough games yet.</figcaption>\n");
            continue;
        }
        const games = s.v.games();
        try w.print("{f} minus {f}: line = estimated average; band = ", .{ esc(x.name), esc(y.name) });
        if (games >= thin_games or base == null) {
            try w.writeAll("middle half of games");
        } else try w.print("middle half of all {s} lanes, around the line (too few games for this matchup's own)", .{lane});
        try w.print("; {s}, all ranks, n = {d} game{s} ({d} still going at {d} min)", .{
            when, games, plural(games), s.v.minute(last - 1).n, last,
        });
        if (last >= curvesfile.lane_minute) {
            const e = s.v.estimate(metric, curvesfile.lane_minute - 1);
            try w.print(". At {d} min: {s}{d} ±{d} (2 standard errors of the average)", .{
                curvesfile.lane_minute, if (e.mean > 0) "+" else "", e.mean, 2 * @as(u32, e.se),
            });
        }
        try ended(w, if (games >= thin_games or base == null) s.v else base.?, last);
        try w.writeAll(".</figcaption>\n");
    }
    try w.writeAll("</figure>\n");
}

/// Surrender opens at 15 minutes: before it nearly all games are still running
const surrender_minute = 15;

/// "From 15 min only games still running count": the share ended by 20 and 25 min
fn ended(w: *Writer, v: View, last: usize) !void {
    if (last <= surrender_minute) return;
    const total = v.games();
    if (total == 0) return;
    try w.print(". Right of the dotted line ({d} min), only games still running count: ", .{surrender_minute});
    var first = true;
    for ([_]usize{ 20, 25 }) |m| {
        if (m > last) continue;
        if (!first) try w.writeAll(", ");
        first = false;
        const going = v.minute(m - 1).n;
        try percent(w, total -| going, total);
        try w.print(" had ended by {d} min", .{m});
    }
}

/// A round number (1, 2, 3, 4, 5, 6 or 8 times a power of ten) at least `value`, and
/// at least 1, so the chart fills most of its height
fn niceCeil(value: i32) i32 {
    var step: i32 = 1;
    while (true) : (step *= 10) {
        for ([_]i32{ 1, 2, 3, 4, 5, 6, 8 }) |k| if (k * step >= value) return k * step;
    }
}

fn sides(w: *Writer, v: View, x: Champ, y: Champ) !void {
    const lane = v.lane();
    try w.print(
        "<div class=\"table-scroll\"><table>\n<thead><tr><th></th><th class=\"num\">{f}</th><th class=\"num\">{f}</th></tr></thead>\n<tbody>\n",
        .{ esc(x.name), esc(y.name) },
    );
    try w.print("<tr><td>Ahead in gold at {d} min</td><td class=\"num\">", .{curvesfile.lane_minute});
    try percent(w, lane.ahead, lane.games);
    try w.writeAll("</td><td class=\"num\">");
    try percent(w, lane.behind, lane.games);
    try w.writeAll("</td></tr>\n<tr><td>Wins the game</td><td class=\"num\">");
    try percent(w, v.wins(), v.games());
    try w.writeAll("</td><td class=\"num\">");
    try percent(w, v.games() - v.wins(), v.games());
    try w.print("</td></tr>\n<tr><td>Wins when ahead at {d} min</td><td class=\"num\">", .{curvesfile.lane_minute});
    try percent(w, lane.wins_ahead, lane.ahead);
    try w.writeAll("</td><td class=\"num\">");
    try percent(w, lane.behind - lane.wins_behind, lane.behind);
    try w.writeAll("</td></tr>\n");
    const phase_names = [_][]const u8{ "before 6 min", "6 to 14 min", "after 14 min" };
    for (phase_names, 0..) |name, ph| {
        try w.print("<tr><td>Takes part in killing the other, {s}</td><td class=\"num\">", .{name});
        try percent(w, v.kills(ph), v.games());
        try w.writeAll("</td><td class=\"num\">");
        try percent(w, v.deaths(ph), v.games());
        try w.writeAll("</td></tr>\n");
    }
    try timing(w, "Level 6 (median)", v.level6());
    try timing(w, "First finished item (median)", v.firstItem());
    try w.print("</tbody></table></div>\n<p class=\"muted\">Share of {d} game{s}. A finished item costs 2,200 gold or more and builds into nothing; a dash means fewer than half of the games got there.</p>\n", .{ v.games(), plural(v.games()) });
}

fn timing(w: *Writer, label: []const u8, both: [2]u16) !void {
    try w.print("<tr><td>{s}</td>", .{label});
    for (both) |secs| {
        if (secs == 0) {
            try w.writeAll("<td class=\"num\">-</td>");
        } else {
            try w.print("<td class=\"num\">{d}:{d:0>2}</td>", .{ secs / 60, secs % 60 });
        }
    }
    try w.writeAll("</tr>\n");
}

fn brackets(w: *Writer, curves: *const Curves, r: Role, x: Champ, y: Champ) !void {
    try w.print(
        "<div class=\"table-scroll\"><table>\n<thead><tr><th>Rank</th><th class=\"num\">Games</th><th class=\"num\">Gold at {d} min</th><th class=\"num\">{f} ahead at {d} min</th><th class=\"num\">{f} wins</th></tr></thead>\n<tbody>\n",
        .{ curvesfile.lane_minute, esc(x.name), curvesfile.lane_minute, esc(x.name) },
    );
    for (std.enums.values(Bracket)) |b| {
        const v = curves.get(r, b, x.id, y.id) orelse {
            try w.print("<tr class=\"thin\"><td>{s}</td><td class=\"num\" colspan=\"4\">more data needed</td></tr>\n", .{b.label()});
            continue;
        };
        const i = curvesfile.lane_minute - 1;
        try w.print("<tr{s}><td>{s}</td><td class=\"num\">{d}</td><td class=\"num\">", .{
            if (thin(v)) " class=\"thin\"" else "", b.label(), v.games(),
        });
        if (v.minute(i).n >= minuteFloor(v)) {
            const e = v.estimate(.gold, i);
            try w.print("{s}{d} ±{d}", .{ if (e.mean > 0) "+" else "", e.mean, 2 * @as(u32, e.se) });
        } else try w.writeAll("-");
        try w.writeAll("</td><td class=\"num\">");
        try percent(w, v.lane().ahead, v.lane().games);
        try w.writeAll("</td><td class=\"num\">");
        try percent(w, v.wins(), v.games());
        try w.writeAll("</td></tr>\n");
    }
    try w.print(
        "</tbody></table></div>\n<p class=\"muted\">Rank is the median visible tier of the players in each game. Gold is the estimated average ±2 standard errors; a rank's estimate leans on the all-ranks one until it has games of its own. Rows under {d} games, or mostly baseline, are greyed out.</p>\n",
        .{thin_games},
    );
}

test "nice scale" {
    try std.testing.expectEqual(1, niceCeil(0));
    try std.testing.expectEqual(500, niceCeil(420));
    try std.testing.expectEqual(600, niceCeil(501));
    try std.testing.expectEqual(2000, niceCeil(1001));
    try std.testing.expectEqual(3000, niceCeil(2120));
}
