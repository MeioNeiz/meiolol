//! Comeback odds on matchup pages: how often each side won from each lane gold position
//! at 10 and 15 minutes (core/curvesfile.zig View.comeback), beside every lane in the
//! role (Curves.baseline). Facts with n, greyed when thin; never advice.

const std = @import("std");
const core = @import("core");
const root = @import("root.zig");
const html = @import("html.zig");
const tpl = html.tpl;
const matchup = @import("matchup.zig");
const text = @import("text.zig");
const percent = text.percent;

const Writer = std.Io.Writer;
const Role = core.Role;
const curvesfile = core.curvesfile;
const Curves = curvesfile.Curves;
const View = curvesfile.View;
const Champ = root.Champ;

/// From x's side, bucket 0 (1500+ behind) to 4 (1500+ ahead); curvesfile.comeback_edges
const labels = [curvesfile.buckets][]const u8{
    "1,500+ behind",
    "500 to 1,500 behind",
    "within 500",
    "500 to 1,500 ahead",
    "1,500+ ahead",
};

/// Bucket names under the comeback chart, x's lead at the minute
const short_labels = [curvesfile.buckets][]const u8{ "-1.5k", "-1k", "0", "+1k", "+1.5k" };

/// Chart area in SVG units, about the size it is drawn so its text stays near 11px
const G = struct {
    const width = 300;
    const height = 200;
    const left = 34;
    const right = 10;
    const top = 10;
    const bottom = 34;

    fn px(i: usize) f64 {
        return left + (@as(f64, @floatFromInt(i)) + 0.5) * (width - left - right) / curvesfile.buckets;
    }

    fn py(rate: f64) f64 {
        return top + (1 - rate) * (height - top - bottom);
    }
};

/// Matchup page card: x's win rate by lane gold at 10 minutes, the matchup's line over
/// every lane in the role; a hollow dot under thin_games. Each dot titled with both
/// minutes' counts
pub fn card(w: *Writer, curves: *const Curves, r: Role, x: Champ, y: Champ) !void {
    const v = curves.get(r, .all, x.id, y.id) orelse return;
    const base = curves.baseline(r, .all);
    const lane = root.roleName(r);
    try tpl.renderPart(w,
        \\<section class="mu-card mu-comeback"><h2>Win rate by gold at 10 min</h2>
        \\<p class="mu-key"><span class="k x"></span>{x} vs {y} <span class="k all"></span>All {lane} lanes</p>
        \\<svg viewBox="0 0 {width} {height}" role="img" aria-label="{x}'s win rate against {y} by lane gold at 10 minutes">
        \\
    , .{ .x = x.name, .y = y.name, .lane = lane, .width = G.width, .height = G.height });
    for ([_]f64{ 0.25, 0.5, 0.75 }) |t| try tpl.render(w,
        \\<line class="{class}" x1="{l}" x2="{r}" y1="{y:.1}" y2="{y:.1}"/><text x="{tx}" y="{ty:.1}" text-anchor="end">{p}%</text>
        \\
    , .{
        .class = if (t == 0.5) "zero" else "grid",
        .l = G.left,
        .r = G.width - G.right,
        .y = G.py(t),
        .tx = G.left - 5,
        .ty = G.py(t) + 4,
        .p = @as(u32, @intFromFloat(100 * t)),
    });
    for (short_labels, 0..) |label, i| try tpl.render(w,
        \\<text x="{x:.1}" y="{y}" text-anchor="middle">{label}</text>
        \\
    , .{ .x = G.px(i), .y = G.height - 18, .label = label });
    try tpl.render(w,
        \\<text x="{x:.1}" y="{y}" text-anchor="start" class="side">{name} behind in gold</text><text x="{x2:.1}" y="{y}" text-anchor="end" class="side">ahead</text>
        \\
    , .{ .x = G.left, .x2 = G.width - G.right, .y = G.height - 3, .name = x.name });
    if (base) |bl| try line(w, bl, "all");
    try line(w, v, "x");
    for (0..curvesfile.buckets) |i| {
        const c = v.comeback(.ten, i);
        if (c.games == 0) continue;
        const later = v.comeback(.fifteen, i);
        const all = if (base) |bl| bl.comeback(.ten, i) else curvesfile.Counts{};
        try tpl.render(w,
            \\<circle class="dot{thin}" cx="{cx:.1}" cy="{cy:.1}" r="4.5"><title>{label} at 10 min: {x} won {rate} of {games} games (all {lane} lanes {all}); at 15 min {later} of {later_games}</title></circle>
            \\
        , .{
            .thin = tpl.when(c.games < matchup.thin_games, " thin"),
            .cx = G.px(i),
            .cy = G.py(ratio(c)),
            .label = labels[i],
            .x = x.name,
            .rate = tpl.call(percent, .{ c.wins, c.games }),
            .games = c.games,
            .lane = lane,
            .all = tpl.call(percent, .{ all.wins, all.games }),
            .later = tpl.call(percent, .{ later.wins, later.games }),
            .later_games = later.games,
        });
    }
    try tpl.renderPart(w, "</svg></section>\n", .{});
}

fn ratio(c: curvesfile.Counts) f64 {
    return @as(f64, @floatFromInt(c.wins)) / @as(f64, @floatFromInt(@max(c.games, 1)));
}

fn line(w: *Writer, v: View, class: []const u8) !void {
    var buf: [curvesfile.buckets * 24]u8 = undefined;
    var pw: Writer = .fixed(&buf);
    for (0..curvesfile.buckets) |i| {
        const c = v.comeback(.ten, i);
        if (c.games == 0) continue;
        try pw.print("{d:.1},{d:.1} ", .{ G.px(i), G.py(ratio(c)) });
    }
    try tpl.render(w, "<polyline class=\"{class}\" points=\"{p}\"/>\n", .{ .class = class, .p = pw.buffered() });
}

test "comeback card from both sides" {
    const gpa = std.testing.allocator;
    var b: curvesfile.Builder = .{ .gpa = gpa };
    defer b.deinit();
    // 300 games, champion 10 a thousand gold behind 60 at 10 and 15 min, wins a third
    for (0..300) |i| {
        var l: curvesfile.Lane = .{ .role = .top, .bracket = .mid, .a = 10, .b = 60, .a_won = i % 3 == 0, .minutes = 20 };
        l.gold[9] = -1000;
        l.gold[14] = -1000;
        try b.addLane(l);
        b.addGame();
    }
    var aw: Writer.Allocating = .init(gpa);
    defer aw.deinit();
    try b.write(&aw.writer, "16.20", 1);
    var c: Curves = try .parse(gpa, aw.written());
    defer c.deinit(gpa);

    const champ = struct {
        fn f(id: u32, name: []const u8) Champ {
            return .{ .c = 0, .id = id, .key = name, .name = name, .slug = name, .banned = 0, .games = 0 };
        }
    }.f;
    var out: Writer.Allocating = .init(gpa);
    defer out.deinit();
    try card(&out.writer, &c, .top, champ(10, "Garen"), champ(60, "Darius"));
    try std.testing.expect(std.mem.indexOf(u8, out.written(), "<circle class=\"dot\" cx=\"110.8\" cy=\"114.0\" r=\"4.5\"><title>500 to 1,500 behind at 10 min: Garen won 33% of 300 games") != null);
    try std.testing.expectEqual(1, std.mem.count(u8, out.written(), "<circle"));
    out.clearRetainingCapacity();
    try card(&out.writer, &c, .top, champ(60, "Darius"), champ(10, "Garen"));
    try std.testing.expect(std.mem.indexOf(u8, out.written(), "<title>500 to 1,500 ahead at 10 min: Darius won 67% of 300 games") != null);
}
