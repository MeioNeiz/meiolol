//! "Model accuracy vs data" on the method page: AUC on held-out games against the games
//! the models learnt from, from the box's daily eval (data/eval-history.tsv, docs/model.md),
//! drawn by ui.aucchart. Shows honestly how close to a coin flip draft prediction still is.

const std = @import("std");
const ui = @import("ui");

const Writer = std.Io.Writer;

pub const Point = struct {
    games: u32,
    /// AUC per series, in `series` order
    auc: [series.len]f64,
};

const Series = struct { column: []const u8, label: []const u8 };

pub const series = [_]Series{
    .{ .column = "auc_base", .label = "Champion win rates alone" },
    .{ .column = "auc_current", .label = "The draft model in use" },
    .{ .column = "auc_joint", .label = "Joint ratings (on trial)" },
};

/// The TSV's lines by its header's column names, sorted by games, one point per games
/// count (the newest); lines with missing columns or values that aren't numbers (nan
/// and inf parse) skipped. Lines scored on one region (test_platform set, the runs
/// before the all-platform cut of 14 Oct) are skipped: a different test set
pub fn parse(arena: std.mem.Allocator, tsv: []const u8) ![]Point {
    var lines = std.mem.tokenizeScalar(u8, tsv, '\n');
    const header = lines.next() orelse return &.{};
    var at: [series.len + 1]?usize = @splat(null);
    var region_at: ?usize = null;
    var cols = std.mem.splitScalar(u8, header, '\t');
    var i: usize = 0;
    while (cols.next()) |name| : (i += 1) {
        if (std.mem.eql(u8, name, "games")) at[0] = i;
        if (std.mem.eql(u8, name, "test_platform")) region_at = i;
        for (series, 1..) |s, k| if (std.mem.eql(u8, name, s.column)) {
            at[k] = i;
        };
    }
    for (at) |a| if (a == null) return &.{};
    var out: std.ArrayList(Point) = .empty;
    lines: while (lines.next()) |line| {
        var fields: [64][]const u8 = undefined;
        var n: usize = 0;
        var it = std.mem.splitScalar(u8, line, '\t');
        while (it.next()) |f| : (n += 1) {
            if (n == fields.len) continue :lines;
            fields[n] = f;
        }
        for (at) |a| if (a.? >= n) continue :lines;
        if (region_at) |r| if (r < n and fields[r].len > 0) continue :lines;
        var p: Point = .{ .games = std.fmt.parseInt(u32, fields[at[0].?], 10) catch continue, .auc = undefined };
        for (&p.auc, 1..) |*v, k| {
            v.* = std.fmt.parseFloat(f64, fields[at[k].?]) catch continue :lines;
            if (!std.math.isFinite(v.*)) continue :lines;
        }
        for (out.items) |*q| if (q.games == p.games) {
            q.* = p;
            continue :lines;
        };
        try out.append(arena, p);
    }
    std.mem.sort(Point, out.items, {}, struct {
        fn f(_: void, a: Point, b: Point) bool {
            return a.games < b.games;
        }
    }.f);
    return out.items;
}

/// Under the method page's text: its heading and lead in, as markdown (ui.prose); "" under
/// two points, as `chart`
pub fn intro(a: std.mem.Allocator, points: []const Point) ![]const u8 {
    if (points.len < 2) return "";
    const last = points[points.len - 1];
    return std.fmt.allocPrint(a,
        \\## Model accuracy vs data {{#accuracy}}
        \\
        \\How well each model tells winners from losers on ranked games it never saw, as
        \\more games come in. 0.5 is a coin flip, 1 would be always right. A draft decides
        \\little of a game, so expect small numbers: at {d} games the best is {d:.3}.
        \\
    , .{ last.games, @max(last.auc[0], last.auc[1], last.auc[2]) });
}

/// The model in use first: the chart's answer
const order = [_]struct { usize, ui.chart.Line }{ .{ 1, .main }, .{ 0, .prev }, .{ 2, .typ } };

pub fn chart(h: *ui.H, points: []const Point) ui.N {
    if (points.len < 2) return .none;
    const games = h.mem.alloc(u32, points.len) catch return oom(h);
    for (games, points) |*g, p| g.* = p.games;
    var ss: [series.len]ui.aucchart.Series = undefined;
    for (&ss, order) |*s, o| {
        const auc = h.mem.alloc(f32, points.len) catch return oom(h);
        for (auc, points) |*v, p| v.* = @floatCast(p.auc[o[0]]);
        s.* = .{ .label = series[o[0]].label, .auc = auc, .kind = o[1] };
    }
    const last = points[points.len - 1];
    const c: ui.aucchart.AucChart = .{
        .games = games,
        .series = h.mem.dupe(ui.aucchart.Series, &ss) catch return oom(h),
        .caption = h.fmt("AUC on held-out games (every platform, from one time cut) against the games the models learnt from; one point per daily run. Latest: {s} {d:.3}, {s} {d:.3}, {s} {d:.3}. The draft model in use stays until another beats it beyond noise.", .{
            series[0].label, last.auc[0],
            series[1].label, last.auc[1],
            series[2].label, last.auc[2],
        }),
    };
    return c.view(h);
}

fn oom(h: *ui.H) ui.N {
    h.oom = true;
    return .none;
}

test "parse keeps the newest line per games count, sorted" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const tsv =
        "date\tgames\tauc_base\tauc_current\tauc_joint\n" ++
        "d\t9000\t0.51\t0.52\t0.53\n" ++
        "d\t8000\t0.50\t0.51\t0.52\n" ++
        "d\t9000\t0.54\t0.55\t0.56\n" ++
        "d\tbad\n" ++
        "d\t7000\tnan\t0.5\t0.5\n" ++
        "d\t9000\t0.5\tinf\t0.5\n";
    const points = try parse(arena.allocator(), tsv);
    try std.testing.expectEqual(2, points.len);
    try std.testing.expectEqual(8000, points[0].games);
    try std.testing.expectEqual(0.56, points[1].auc[2]);
    var t: ui.Tree = .{};
    var h: ui.H = .init(arena.allocator(), &t);
    var out: Writer.Allocating = .init(arena.allocator());
    try ui.html.write(&t, chart(&h, points), &out.writer);
    try std.testing.expect(std.mem.find(u8, out.written(), "Joint ratings (on trial) 0.560") != null);
    try std.testing.expect(std.mem.find(u8, try intro(arena.allocator(), points), "the best is 0.560.") != null);
    try std.testing.expectEqualStrings("", try intro(arena.allocator(), points[0..1]));

    const regions =
        "date\ttest_platform\tgames\tauc_base\tauc_current\tauc_joint\n" ++
        "d\tEUW1\t8000\t0.50\t0.51\t0.52\n" ++
        "d\t\t9000\t0.54\t0.55\t0.56\n";
    const global = try parse(arena.allocator(), regions);
    try std.testing.expectEqual(1, global.len);
    try std.testing.expectEqual(9000, global[0].games);
}
