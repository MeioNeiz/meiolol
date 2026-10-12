//! Comeback odds on matchup pages: how often each side won from each lane gold position
//! at 10 and 15 minutes (core/curvesfile.zig View.comeback), beside every lane in the
//! role (Curves.baseline). Facts with n, greyed when thin; never advice.

const std = @import("std");
const core = @import("core");
const root = @import("root.zig");
const html = @import("html.zig");
const tpl = html.tpl;
const matchup = @import("matchup.zig");

const Writer = std.Io.Writer;
const Role = core.Role;
const curvesfile = core.curvesfile;
const Curves = curvesfile.Curves;
const View = curvesfile.View;
const Champ = root.Champ;

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
        const all = if (base) |bl| blk: {
            const bh = bl.comeback(.ten, headline_bucket);
            break :blk tpl.t(" (all {lane} lanes: {rate})", .{ .lane = lane, .rate = tpl.call(percent, .{ bh.wins, bh.games }) });
        } else null;
        try tpl.render(w,
            \\<p>Between 500 and 1,500 gold behind {y} at 10 minutes, {x} still won {rate} of {games} game{s}{all}.</p>
            \\
        , .{
            .y = y.name,
            .x = x.name,
            .rate = tpl.call(percent, .{ head.wins, head.games }),
            .games = head.games,
            .s = matchup.plural(head.games),
            .all = all,
        });
    } else {
        try tpl.render(w,
            \\<p class="note">More data needed: cells under {thin} games are greyed out. The all-{lane}-lanes columns fill sooner.</p>
            \\
        , .{ .thin = matchup.thin_games, .lane = lane });
    }

    try tpl.renderPart(w,
        \\<div class="table-scroll"><table class="comeback">
        \\<thead><tr><th>{x}'s lane gold vs {y}</th><th class="num">{x} won, at 10 min</th><th class="num">at 15 min</th><th class="num">All {lane} lanes, 10 min</th><th class="num">15 min</th></tr></thead>
        \\<tbody>
        \\
    , .{ .x = x.name, .y = y.name, .lane = lane });
    for (labels, 0..) |label, i| {
        try tpl.renderPart(w, "<tr><td>{label}</td>", .{ .label = label });
        for (minutes) |m| try cell(w, v.comeback(m, i));
        for (minutes) |m| {
            if (base) |bl| try cell(w, bl.comeback(m, i)) else try w.writeAll("<td class=\"num\">-</td>");
        }
        try w.writeAll("</tr>\n");
    }
    try tpl.renderPart(w,
        \\</tbody></table></div>
        \\<p class="muted">Gold is {x}'s total minus {y}'s at that minute. Games that ended
        \\before it are left out. All {lane} lanes counts every lane from both sides. Cells under
        \\{thin} games are greyed out.</p>
        \\
    , .{ .x = x.name, .y = y.name, .lane = lane, .thin = matchup.thin_games });
}

fn cell(w: *Writer, c: curvesfile.Counts) !void {
    const value = if (c.games == 0) null else tpl.t("{rate} <span class=\"muted\">{games}</span>", .{
        .rate = tpl.call(percent, .{ c.wins, c.games }),
        .games = c.games,
    });
    try tpl.render(w, "<td class=\"num{thin}\" title=\"{games} games\">{dash}{value}</td>", .{
        .thin = tpl.when(c.games < matchup.thin_games, " thin"),
        .games = c.games,
        .dash = tpl.when(c.games == 0, "-"),
        .value = value,
    });
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
