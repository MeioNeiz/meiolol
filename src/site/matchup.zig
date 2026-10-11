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
/// Matchup links on a champion page, per role
const links_shown = 12;
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
pub fn writeAll(site: *const Site, curves: *const Curves) !void {
    var pages: usize = 0;
    for (curves.curves) |c| {
        const h = c.header;
        if (h.bracket != @intFromEnum(Bracket.all)) continue;
        const x = champ(site, h.a) orelse continue;
        const y = champ(site, h.b) orelse continue;
        const r: Role = @enumFromInt(h.role);
        try writePage(site, curves, r, x, y);
        pages += 1;
    }
    std.log.scoped(.site).info("{d} matchup pages", .{pages});
}

/// matchup/index.html: every matchup page by role, most games first
pub fn writeIndex(site: *const Site, curves: ?*const Curves) !void {
    const a = site.arena;
    var aw: Writer.Allocating = .init(a);
    const w = &aw.writer;
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
        try html.foot(w, p);
        return site.write("matchup/index.html", aw.written());
    };
    try html.minGames(w, "../", "matchups", &index_floors, index_floors[0], 0);
    const Entry = struct { x: Champ, y: Champ, games: u32 };
    for (Role.all) |r| {
        var list: std.ArrayList(Entry) = .empty;
        for (c.curves) |cv| {
            const h = cv.header;
            if (h.role != @intFromEnum(r) or h.bracket != 0 or h.experience != 0) continue;
            const x = champ(site, h.a) orelse continue;
            const y = champ(site, h.b) orelse continue;
            try list.append(a, .{ .x = x, .y = y, .games = h.games });
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
                if (e.games < thin_games) " class=\"thin\"" else "",
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
    try site.write("matchup/index.html", aw.written());
}

pub fn champ(site: *const Site, id: u32) ?Champ {
    const c = site.stats.index(id) orelse return null;
    return site.champs[site.by_c[c] orelse return null];
}

/// Champion page: links to `ch`'s matchup pages in `r`, most games first
pub fn links(site: *const Site, w: *Writer, curves: *const Curves, ch: Champ, r: Role) !void {
    const Link = struct { other: Champ, games: u32 };
    var list: std.ArrayList(Link) = .empty;
    for (curves.curves) |c| {
        const h = c.header;
        if (h.bracket != @intFromEnum(Bracket.all) or h.role != @intFromEnum(r)) continue;
        const other_id = if (h.a == ch.id) h.b else if (h.b == ch.id) h.a else continue;
        const other = champ(site, other_id) orelse continue;
        try list.append(site.arena, .{ .other = other, .games = h.games });
    }
    if (list.items.len == 0) return;
    std.mem.sort(Link, list.items, {}, struct {
        fn f(_: void, p: Link, q: Link) bool {
            return p.games > q.games;
        }
    }.f);
    try w.writeAll("<p class=\"curves-links\"><b>Lane curves:</b> ");
    for (list.items[0..@min(list.items.len, links_shown)], 0..) |l, i| {
        if (i > 0) try w.writeAll(" · ");
        const x, const y = if (ch.id < l.other.id) .{ ch, l.other } else .{ l.other, ch };
        try w.print("<a href=\"../{s}\">vs {f}</a>", .{ try path(site.arena, r, x, y), esc(l.other.name) });
    }
    try w.writeAll("</p>\n");
}

fn writePage(site: *const Site, curves: *const Curves, r: Role, x: Champ, y: Champ) !void {
    const a = site.arena;
    const v = curves.get(r, .all, x.id, y.id).?;
    var aw: Writer.Allocating = .init(a);
    const w = &aw.writer;
    const lane = root.roleName(r);
    const when = try period(a, curves);
    const title = try std.fmt.allocPrint(a, "{s} vs {s}, {s} lane curves, {s} | meiolol", .{
        x.name, y.name, lane, when,
    });
    const desc = try std.fmt.allocPrint(a, "How {s} against {s} in {s} lane unfolds minute by minute: gold, experience and CS difference, kills, level 6 timing.", .{
        x.name, y.name, lane,
    });
    const page_path = try path(a, r, x, y);
    var p = site.page(title, desc, page_path, .matchups);
    for (site.view_curves, &p.counterparts.?) |*other, *there| {
        const has = if (other.*) |*o| o.get(r, .all, x.id, y.id) != null else false;
        if (!has) there.* = "matchup/index.html";
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
            "<p class=\"note\">More data needed: {d} game{s} so far. Curves this thin still move as games come in, so they are greyed out until {d}.</p>\n",
            .{ v.games(), plural(v.games()), thin_games },
        );
    }
    try summary(w, v, x, y);

    const Metric = struct { title: []const u8, field: []const u8, unit: []const u8 };
    const metrics = [_]Metric{
        .{ .title = "Gold difference", .field = "gold", .unit = "gold" },
        .{ .title = "Experience difference", .field = "xp", .unit = "XP" },
        .{ .title = "CS difference", .field = "cs", .unit = "CS" },
    };
    inline for (metrics) |m| {
        try w.print("<h2>{s}</h2>\n", .{m.title});
        try chart(w, v, m.field, m.unit, x, y, when);
    }

    try w.writeAll("<h2>Lane and game</h2>\n");
    try sides(w, v, x, y);
    try comeback.section(w, curves, r, x, y);
    try w.writeAll("<h2>By rank</h2>\n");
    try brackets(w, curves, r, x, y);
    try w.print(
        "<p class=\"muted\"><a href=\"../../champion/{s}.html\">{f}</a> · <a href=\"../../champion/{s}.html\">{f}</a> · <a href=\"{s}method.html\">Method</a></p>\n",
        .{ x.slug, esc(x.name), y.slug, esc(y.name), site.toShared(page_path) },
    );
    try html.foot(w, p);
    try site.write(page_path, aw.written());
}

fn summary(w: *Writer, v: View, x: Champ, y: Champ) !void {
    const lane = v.lane();
    try w.writeAll("<p class=\"lead\">");
    const m = v.minute(curvesfile.lane_minute - 1);
    if (m.n >= minuteFloor(v)) {
        try w.print("At {d} minutes {f} is typically ", .{ curvesfile.lane_minute, esc(x.name) });
        try amount(w, m.gold.p50, "gold");
        try w.print(" against {f} (middle half of games: {d} to {d}), and leads in gold in ", .{
            esc(y.name), m.gold.p25, m.gold.p75,
        });
        try percent(w, lane.ahead, lane.games);
        try w.writeAll(" of games. ");
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

/// Median line and middle-half band of `field` by minute, as inline SVG
fn chart(
    w: *Writer,
    v: View,
    comptime field: []const u8,
    unit: []const u8,
    x: Champ,
    y: Champ,
    when: []const u8,
) !void {
    var last: usize = 0;
    var max_abs: u32 = 0;
    for (0..v.minutes()) |i| {
        const m = v.minute(i);
        if (m.n < minuteFloor(v)) break;
        last = i + 1;
        const q = @field(m, field);
        max_abs = @max(max_abs, @abs(@as(i32, q.p25)), @abs(@as(i32, q.p75)));
    }
    const thin = v.games() < thin_games;
    try w.print("<figure class=\"chart{s}\">\n", .{if (thin) " thin" else ""});
    if (last < 2) {
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
    while (minute <= last) : (minute += 5) {
        try w.print("<text x=\"{d:.1}\" y=\"{d}\" text-anchor=\"middle\">{d} min</text>", .{
            px(minute - 1, last), height - 8, minute,
        });
    }
    try w.print("<text x=\"{d}\" y=\"{d}\" class=\"side\">{f} ahead</text>", .{ left + 6, top + 12, esc(x.name) });
    try w.print("<text x=\"{d}\" y=\"{d}\" class=\"side\">{f} ahead</text>\n", .{
        left + 6, height - bottom - 6, esc(y.name),
    });

    try w.writeAll("<polygon class=\"band\" points=\"");
    for (0..last) |i| {
        try w.print("{d:.1},{d:.1} ", .{ px(i, last), py(@field(v.minute(i), field).p75, scale, mid, half) });
    }
    var i = last;
    while (i > 0) {
        i -= 1;
        try w.print("{d:.1},{d:.1} ", .{ px(i, last), py(@field(v.minute(i), field).p25, scale, mid, half) });
    }
    try w.writeAll("\"/>\n<polyline class=\"median\" points=\"");
    for (0..last) |j| {
        try w.print("{d:.1},{d:.1} ", .{ px(j, last), py(@field(v.minute(j), field).p50, scale, mid, half) });
    }
    try w.writeAll("\"/>\n</svg>\n");
    try w.print(
        "<figcaption>{f} minus {f}: median line, band = middle half of games; {s}, all ranks, n = {d} game{s} ({d} still going at {d} min).</figcaption>\n</figure>\n",
        .{ esc(x.name), esc(y.name), when, v.games(), plural(v.games()), v.minute(last - 1).n, last },
    );
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
    const l6 = v.level6();
    try w.writeAll("<tr><td>Level 6 (median)</td>");
    for (l6) |secs| {
        if (secs == 0) {
            try w.writeAll("<td class=\"num\">-</td>");
        } else {
            try w.print("<td class=\"num\">{d}:{d:0>2}</td>", .{ secs / 60, secs % 60 });
        }
    }
    try w.print("</tr>\n</tbody></table></div>\n<p class=\"muted\">Share of {d} game{s}.</p>\n", .{ v.games(), plural(v.games()) });
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
        const m = v.minute(curvesfile.lane_minute - 1);
        try w.print("<tr{s}><td>{s}</td><td class=\"num\">{d}</td><td class=\"num\">", .{
            if (v.games() < thin_games) " class=\"thin\"" else "", b.label(), v.games(),
        });
        if (m.n >= minuteFloor(v)) {
            try w.print("{s}{d}", .{ if (m.gold.p50 > 0) "+" else "", m.gold.p50 });
        } else try w.writeAll("-");
        try w.writeAll("</td><td class=\"num\">");
        try percent(w, v.lane().ahead, v.lane().games);
        try w.writeAll("</td><td class=\"num\">");
        try percent(w, v.wins(), v.games());
        try w.writeAll("</td></tr>\n");
    }
    try w.print(
        "</tbody></table></div>\n<p class=\"muted\">Rank is the median visible tier of the players in each game. Rows under {d} games are greyed out.</p>\n",
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
