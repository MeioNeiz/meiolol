//! Comeback odds on matchup pages: how often each side won from each lane gold position
//! at 10 and 15 minutes (core/curvesfile.zig View.comeback), beside every lane in the
//! role (Curves.baseline). Facts with n, greyed when thin; never advice.

const std = @import("std");
const core = @import("core");
const root = @import("root.zig");
const html = @import("html.zig");
const matchup = @import("matchup.zig");

const Writer = std.Io.Writer;
const Role = core.Role;
const curvesfile = core.curvesfile;
const Curves = curvesfile.Curves;
const View = curvesfile.View;
const Champ = root.Champ;
const esc = html.esc;

const minutes = [_]curvesfile.Comeback{ .ten, .fifteen };

/// From x's side, bucket 0 (1500+ behind) to 4 (1500+ ahead); curvesfile.comeback_edges
const labels = [curvesfile.buckets][]const u8{
    "1,500+ behind",
    "500 to 1,500 behind",
    "within 500",
    "500 to 1,500 ahead",
    "1,500+ ahead",
};

/// The row the opening sentence is about: behind, but not out of it
const headline_bucket = 1;

pub fn section(w: *Writer, curves: *const Curves, r: Role, x: Champ, y: Champ) !void {
    const v = curves.get(r, .all, x.id, y.id) orelse return;
    const base = curves.baseline(r, .all);
    const lane = root.roleName(r);
    try w.writeAll("<h2>Comeback odds</h2>\n");

    const head = v.comeback(.ten, headline_bucket);
    if (head.games >= matchup.thin_games) {
        try w.print("<p>Between 500 and 1,500 gold behind {f} at 10 minutes, {f} still won ", .{ esc(y.name), esc(x.name) });
        try percent(w, head.wins, head.games);
        try w.print(" of {d} games", .{head.games});
        if (base) |b| {
            const bh = b.comeback(.ten, headline_bucket);
            try w.print(" (all {s} lanes: ", .{lane});
            try percent(w, bh.wins, bh.games);
            try w.writeAll(")");
        }
        try w.writeAll(".</p>\n");
    } else {
        try w.print(
            "<p class=\"note\">More data needed: cells under {d} games are greyed out. The all-{s}-lanes columns fill sooner.</p>\n",
            .{ matchup.thin_games, lane },
        );
    }

    try w.print(
        \\<div class="table-scroll"><table>
        \\<thead><tr><th>{f}'s lane gold vs {f}</th><th class="num">{f} won, at 10 min</th><th class="num">at 15 min</th><th class="num">All {s} lanes, 10 min</th><th class="num">15 min</th></tr></thead>
        \\<tbody>
        \\
    , .{ esc(x.name), esc(y.name), esc(x.name), lane });
    for (labels, 0..) |label, i| {
        try w.print("<tr><td>{s}</td>", .{label});
        for (minutes) |m| try cell(w, v.comeback(m, i));
        for (minutes) |m| {
            if (base) |b| try cell(w, b.comeback(m, i)) else try w.writeAll("<td class=\"num\">-</td>");
        }
        try w.writeAll("</tr>\n");
    }
    try w.print(
        \\</tbody></table></div>
        \\<p class="muted">Gold is {f}'s total minus {f}'s at that minute. Games that ended
        \\before it are left out. All {s} lanes counts every lane from both sides. Cells under
        \\{d} games are greyed out.</p>
        \\
    , .{ esc(x.name), esc(y.name), lane, matchup.thin_games });
}

fn cell(w: *Writer, c: curvesfile.Counts) !void {
    try w.print("<td class=\"num{s}\" title=\"{d} games\">", .{
        if (c.games < matchup.thin_games) " thin" else "", c.games,
    });
    if (c.games == 0) {
        try w.writeAll("-");
    } else {
        try percent(w, c.wins, c.games);
        try w.print(" <span class=\"muted\">{d}</span>", .{c.games});
    }
    try w.writeAll("</td>");
}

test "comeback section from both sides" {
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
    try section(&out.writer, &c, .top, champ(10, "Garen"), champ(60, "Darius"));
    try std.testing.expect(std.mem.indexOf(u8, out.written(), "behind Darius at 10 minutes, Garen still won 33% of 300 games") != null);
    out.clearRetainingCapacity();
    try section(&out.writer, &c, .top, champ(60, "Darius"), champ(10, "Garen"));
    // Darius is 500 to 1,500 ahead: its row 3 shows 67%; the headline row is empty
    try std.testing.expect(std.mem.indexOf(u8, out.written(), "More data needed") != null);
    try std.testing.expect(std.mem.indexOf(u8, out.written(), "67%") != null);
}

fn percent(w: *Writer, part: u64, whole: u64) !void {
    if (whole == 0) return w.writeAll("-");
    try w.print("{d:.0}%", .{100 * @as(f64, @floatFromInt(part)) / @as(f64, @floatFromInt(whole))});
}
