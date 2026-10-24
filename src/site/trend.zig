//! Champion page charts (stats.Trend): win and pick rate on the last patches with the
//! rank in the role, and win rate by game length. Facts with their games, hollow when
//! thin; the matchup page can draw a pair's lengths with lengthChart

const std = @import("std");
const core = @import("core");
const root = @import("root.zig");
const html = @import("html.zig");
const stats = @import("../stats.zig");
const tierlist = @import("tierlist.zig");
const scope = @import("scope.zig");
const ordinal = @import("text.zig").ordinal;

const Writer = std.Io.Writer;
const Role = core.Role;
const Counts = core.statsfile.Counts;
const Trend = stats.Trend;
const Champ = root.Champ;
const Site = root.Site;
const tpl = html.tpl;
const ratio = root.ratio;

/// A dot on fewer games is hollow
pub const thin_games = core.curvesfile.full_games;

/// Under each length bucket (stats.length_edges)
pub const length_labels = [stats.length_buckets][]const u8{ "<20", "20-25", "25-30", "30-35", "35+" };
const length_names = [stats.length_buckets][]const u8{ "under 20 min", "20 to 25 min", "25 to 30 min", "30 to 35 min", "35 min and over" };

/// Chart area in SVG units, drawn about this size so its text stays near 11px
const width = 300;
const left = 34;
const right = 8;

fn px(i: usize, n: usize) f64 {
    return left + (@as(f64, @floatFromInt(i)) + 0.5) * (width - left - right) / @as(f64, @floatFromInt(n));
}

/// Win rates from 50% - span to 50% + span between y top and bottom
const Scale = struct {
    top: f64,
    bottom: f64,
    span: f64,

    /// Wide enough for every rate with games, at least 5 points each way
    fn of(top: f64, bottom: f64, rates: []const Counts) Scale {
        var dev: f64 = 0.05;
        for (rates) |c| {
            if (c.games > 0) dev = @max(dev, @abs(ratio(c.wins, c.games) - 0.5) + 0.01);
        }
        return .{ .top = top, .bottom = bottom, .span = @min(0.5, @ceil(dev * 100) / 100) };
    }

    fn y(s: Scale, rate: f64) f64 {
        const t = (rate - 0.5 + s.span) / (2 * s.span);
        return s.bottom - std.math.clamp(t, 0, 1) * (s.bottom - s.top);
    }

    /// Lines at 50% and both ends, labelled in the left gutter
    fn grid(s: Scale, w: *Writer) !void {
        for ([_]f64{ 0.5 - s.span, 0.5, 0.5 + s.span }) |rate| try tpl.render(w,
            \\<line class="{class}" x1="{l}" x2="{r}" y1="{y:.1}" y2="{y:.1}"/><text x="{tx}" y="{ty:.1}" text-anchor="end">{p}%</text>
            \\
        , .{
            .class = if (rate == 0.5) "zero" else "grid",
            .l = left,
            .r = width - right,
            .y = s.y(rate),
            .tx = left - 5,
            .ty = s.y(rate) + 3.5,
            .p = @as(u32, @intFromFloat(@round(100 * rate))),
        });
    }
};

/// The line through the dots with games
fn line(w: *Writer, s: Scale, rates: []const Counts) !void {
    try w.writeAll("<polyline points=\"");
    for (rates, 0..) |c, i| {
        if (c.games == 0) continue;
        try w.print("{d:.1},{d:.1} ", .{ px(i, rates.len), s.y(ratio(c.wins, c.games)) });
    }
    try w.writeAll("\"/>\n");
}

/// A dot in the win rate's colour with its rate above; `title` written inside <title>
fn dot(w: *Writer, s: Scale, c: Counts, i: usize, n: usize, title: anytype) !void {
    const rate = ratio(c.wins, c.games);
    try tpl.render(w,
        \\<circle class="dot{thin}" style="--c:{colour}" cx="{cx:.1}" cy="{cy:.1}" r="4"><title>{title}</title></circle><text class="v" x="{cx:.1}" y="{ty:.1}" text-anchor="middle">{rate}</text>
        \\
    , .{
        .thin = tpl.when(c.games < thin_games, " thin"),
        .colour = tierlist.wrColour(rate, tierlist.table_span),
        .cx = px(i, n),
        .cy = s.y(rate),
        .ty = s.y(rate) - 8,
        .title = title,
        .rate = tpl.call(root.pct, .{ c.wins, c.games }),
    });
}

/// Win rate by game length: `by` from `name`'s side, `what` its aria label ("Darius's
/// win rate in Top")
pub fn lengthChart(w: *Writer, by: [stats.length_buckets]Counts, name: []const u8, what: []const u8) !void {
    const height = 170;
    const s: Scale = .of(18, height - 38, &by);
    try tpl.renderPart(w,
        \\<svg viewBox="0 0 {width} {height}" role="img" aria-label="{what} by game length">
        \\
    , .{ .width = width, .height = height, .what = what });
    try s.grid(w);
    try tpl.render(w,
        \\<text x="{x}" y="{y1}" text-anchor="end">Min</text><text class="n" x="{x}" y="{y2}" text-anchor="end">Games</text>
        \\
    , .{ .x = left - 5, .y1 = height - 20, .y2 = height - 6 });
    try line(w, s, &by);
    for (by, 0..) |c, i| {
        try tpl.render(w,
            \\<text x="{x:.1}" y="{y}" text-anchor="middle">{label}</text><text class="n" x="{x:.1}" y="{y2}" text-anchor="middle">{games}</text>
            \\
        , .{ .x = px(i, by.len), .y = height - 20, .y2 = height - 6, .label = length_labels[i], .games = root.Thousands{ .n = c.games } });
        if (c.games == 0) continue;
        try dot(w, s, c, i, by.len, tpl.t("Games {length}: {name} won {rate} of {games}", .{
            .length = length_names[i],
            .name = name,
            .rate = tpl.call(root.pct, .{ c.wins, c.games }),
            .games = root.Thousands{ .n = c.games },
        }));
    }
    try w.writeAll("</svg>\n");
}

/// The champion's place in role r's champions table on patch `p` of the trend, ranked
/// as tierlist.roleRank ranks the view's; null when a rare pick there
fn patchRank(a: std.mem.Allocator, t: *const Trend, p: usize, r: Role, c: usize) !?tierlist.Rank {
    const cells = try a.alloc(Counts, t.n);
    for (cells, 0..) |*x, o| x.* = t.onPatch(p, r, o);
    const prior: core.banimpact.Prior = .ofCounts(cells);
    const rare = struct {
        fn f(tr: *const Trend, pi: usize, cr: Counts, ci: usize) bool {
            var all: u64 = 0;
            for (Role.all) |r2| all += tr.onPatch(pi, r2, ci).games;
            return ratio(cr.games, tr.patch_games[pi]) < tierlist.min_pick_rate or ratio(cr.games, all) < tierlist.min_role_share;
        }
    }.f;
    if (cells[c].games == 0 or rare(t, p, cells[c], c)) return null;
    const mine = prior.edge(cells[c].wins, cells[c].games);
    var rank: usize = 1;
    var of: usize = 0;
    for (cells, 0..) |x, o| {
        if (x.games == 0 or rare(t, p, x, o)) continue;
        of += 1;
        if (o != c and prior.edge(x.wins, x.games) > mine) rank += 1;
    }
    return .{ .rank = rank, .of = of };
}

/// Win rate, pick rate and rank in role r on each of the trend's patches, oldest first
fn patchChart(site: *const Site, w: *Writer, t: *const Trend, ch: Champ, r: Role) !void {
    const a = site.arena;
    const n = t.patches.len;
    const rates = try a.alloc(Counts, n);
    for (rates, 0..) |*x, i| x.* = t.onPatch(n - 1 - i, r, ch.c);
    var top_pick: f64 = 0;
    for (rates, 0..) |x, i| top_pick = @max(top_pick, ratio(x.games, t.patch_games[n - 1 - i]));
    const height = 196;
    const bars_top = 120;
    const bars_bottom = 144;
    const s: Scale = .of(18, 104, rates);
    try tpl.renderPart(w,
        \\<svg viewBox="0 0 {width} {height}" role="img" aria-label="{name}'s win and pick rate in {role} by patch">
        \\
    , .{ .width = width, .height = height, .name = ch.name, .role = root.roleName(r) });
    try s.grid(w);
    try tpl.render(w,
        \\<text x="{x}" y="{y1}" text-anchor="end">Pick</text><text x="{x}" y="{y2}" text-anchor="end">Rank</text>
        \\
    , .{ .x = left - 5, .y1 = bars_bottom, .y2 = height - 6 });
    try line(w, s, rates);
    for (rates, 0..) |c, i| {
        const p = n - 1 - i;
        const pick = ratio(c.games, t.patch_games[p]);
        const h = if (top_pick > 0) pick / top_pick * (bars_bottom - bars_top) else 0;
        const rank = try patchRank(a, t, p, r, ch.c);
        try tpl.render(w,
            \\<rect class="bar" x="{x:.1}" y="{y:.1}" width="16" height="{h:.1}"/><text class="n" x="{cx:.1}" y="{py}" text-anchor="middle">{pick}</text><text x="{cx:.1}" y="{ly}" text-anchor="middle">{patch}</text><text class="n" x="{cx:.1}" y="{ry}" text-anchor="middle">{rank}{none}</text>
            \\
        , .{
            .x = px(i, n) - 8,
            .y = bars_bottom - h,
            .h = h,
            .cx = px(i, n),
            .py = bars_bottom + 13,
            .pick = tpl.call(root.pct, .{ c.games, t.patch_games[p] }),
            .ly = height - 20,
            .patch = t.patches[p],
            .ry = height - 6,
            .rank = if (rank) |k| tpl.t("{n}{th} of {of}", .{ .n = k.rank, .th = ordinal(k.rank), .of = k.of }) else null,
            .none = tpl.when(rank == null, "-"),
        });
        if (c.games == 0) continue;
        try dot(w, s, c, i, n, tpl.t("Patch {patch}: {name} won {rate} of {games} games in {role}, played in {pick} of games", .{
            .patch = t.patches[p],
            .name = ch.name,
            .rate = tpl.call(root.pct, .{ c.wins, c.games }),
            .games = root.Thousands{ .n = c.games },
            .role = root.roleName(r),
            .pick = tpl.call(root.pct, .{ c.games, t.patch_games[p] }),
        }));
    }
    try w.writeAll("</svg>\n");
}

/// Both charts side by side for ch in r, each with its scope chip and the line under it
/// (`under_patch`, `under_length`: the patch and early lean lines)
pub fn cards(site: *const Site, w: *Writer, ch: Champ, r: Role, under_patch: anytype, under_length: anytype) !void {
    const t = &(site.trend orelse {
        try under_patch.render(w);
        return under_length.render(w);
    });
    const a = site.arena;
    const region = site.regionDim(site.view.region);
    const oldest = t.patches[t.patches.len - 1];
    const patches: scope.Dim = .{
        .key = "patches",
        .text = if (t.patches.len == 1)
            try a.print("Patch {s}", .{oldest})
        else
            try a.print("Patches {s} to {s}", .{ oldest, t.patches[0] }),
    };
    var by: [stats.length_buckets]Counts = undefined;
    for (&by, 0..) |*x, b| x.* = t.length(r, ch.c, b);
    try tpl.renderPart(w,
        \\<div class="trends">
        \\<div class="trend"><h3>By patch {patch_chip}</h3>
        \\
    , .{ .patch_chip = site.chip(region, patches, .plat) });
    try patchChart(site, w, t, ch, r);
    try under_patch.render(w);
    try tpl.renderPart(w,
        \\</div>
        \\<div class="trend"><h3>By game length {length_chip}</h3>
        \\
    , .{ .length_chip = site.chip(region, site.periodDim(site.view.period), .plat) });
    try lengthChart(w, by, ch.name, try a.print("{s}'s win rate in {s}", .{ ch.name, root.roleName(r) }));
    try under_length.render(w);
    try w.writeAll("</div>\n</div>\n");
}
