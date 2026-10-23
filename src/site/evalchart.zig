//! "Model accuracy vs data" on the method page: AUC on held-out games against the games
//! the models learnt from, from the box's daily eval (data/eval-history.tsv, docs/model.md).
//! Shows honestly how close to a coin flip draft prediction still is.

const std = @import("std");
const tpl = @import("tpl");

const Writer = std.Io.Writer;

pub const Point = struct {
    games: u32,
    /// AUC per series, in `series` order
    auc: [series.len]f64,
};

const Series = struct { column: []const u8, label: []const u8, class: []const u8 };

pub const series = [_]Series{
    .{ .column = "auc_base", .label = "Champion win rates alone", .class = "s1" },
    .{ .column = "auc_current", .label = "The draft model in use", .class = "s2" },
    .{ .column = "auc_joint", .label = "Joint ratings (on trial)", .class = "s3" },
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

const width = 640;
const height = 260;
const left = 56;
const right = 28;
const top = 16;
const bottom = 36;

/// The chart with its heading and caption; nothing under two points
pub fn section(w: *Writer, points: []const Point) !void {
    if (points.len < 2) return;
    var lo: f64 = 0.5;
    var hi: f64 = 0.5;
    for (points) |p| for (p.auc) |v| {
        lo = @min(lo, v);
        hi = @max(hi, v);
    };
    // Room around the coin-flip line, in steps of 0.01
    lo = @floor(lo * 100 - 1) / 100;
    hi = @max(@ceil(hi * 100 + 1) / 100, 0.53);
    const g: Geo = .{ .x0 = @floatFromInt(points[0].games), .x1 = @floatFromInt(points[points.len - 1].games), .lo = lo, .hi = hi };
    const last = points[points.len - 1];
    try tpl.renderPart(w,
        \\<h2 id="accuracy">Model accuracy vs data</h2>
        \\<p>How well each model tells winners from losers on ranked games it never saw, as
        \\more games come in. 0.5 is a coin flip, 1 would be always right. A draft decides
        \\little of a game, so expect small numbers: at {games} games the best is {best:.3}.</p>
        \\<figure class="chart evalchart">{legend}<svg viewBox="0 0 {width} {height}" role="img" aria-label="AUC by games learnt from, three models">
        \\
    , .{
        .games = last.games,
        .best = @max(last.auc[0], last.auc[1], last.auc[2]),
        .width = width,
        .height = height,
        .legend = Legend{},
    });
    var tick = lo;
    while (tick <= hi + 1e-9) : (tick += 0.01) {
        try tpl.render(w,
            \\<line class="{class}" x1="{l}" x2="{r}" y1="{y:.1}" y2="{y:.1}"/><text x="{tx}" y="{ty:.1}" text-anchor="end">{v:.2}</text>
            \\
        , .{
            .class = if (@abs(tick - 0.5) < 1e-9) "zero" else "grid",
            .l = left,
            .r = width - right,
            .y = g.py(tick),
            .tx = left - 6,
            .ty = g.py(tick) + 4,
            .v = tick,
        });
    }
    try tpl.render(w,
        \\<text x="{x0}" y="{y}" text-anchor="start">{g0} games</text><text x="{x1}" y="{y}" text-anchor="end">{g1} games</text>
        \\
    , .{ .x0 = left, .x1 = width - right, .y = height - 12, .g0 = points[0].games, .g1 = last.games });
    for (series, 0..) |s, k| {
        try tpl.render(w,
            \\<polyline class="line {class}" points="{points}"><title>{label}</title></polyline><circle class="end {class}" cx="{cx:.1}" cy="{cy:.1}" r="4"/>
            \\
        , .{
            .class = s.class,
            .points = Line{ .g = g, .points = points, .k = k },
            .cx = g.px(last.games),
            .cy = g.py(last.auc[k]),
            .label = s.label,
        });
    }
    try tpl.renderPart(w,
        \\</svg>
        \\<figcaption>AUC on held-out games (every platform, from one time cut) against the games the models learnt from; one point per daily run. Latest: {l0} {v0:.3}, {l1} {v1:.3}, {l2} {v2:.3}. The draft model in use stays until another beats it beyond noise.</figcaption></figure>
        \\
    , .{
        .l0 = series[0].label,
        .v0 = last.auc[0],
        .l1 = series[1].label,
        .v1 = last.auc[1],
        .l2 = series[2].label,
        .v2 = last.auc[2],
    });
}

const Legend = struct {
    pub fn render(_: Legend, w: *Writer) Writer.Error!void {
        try w.writeAll("<ul class=\"legend\">");
        for (series) |s| try tpl.render(w, "<li><i class=\"{class}\"></i>{label}</li>", .{ .class = s.class, .label = s.label });
        try w.writeAll("</ul>\n");
    }
};

const Geo = struct {
    x0: f64,
    x1: f64,
    lo: f64,
    hi: f64,

    fn px(g: Geo, games: u32) f64 {
        const span = @max(g.x1 - g.x0, 1);
        return left + (@as(f64, @floatFromInt(games)) - g.x0) / span * (width - left - right);
    }

    fn py(g: Geo, v: f64) f64 {
        return top + (g.hi - v) / (g.hi - g.lo) * (height - top - bottom);
    }
};

const Line = struct {
    g: Geo,
    points: []const Point,
    k: usize,

    pub fn render(l: Line, w: *Writer) Writer.Error!void {
        for (l.points) |p| try w.print("{d:.1},{d:.1} ", .{ l.g.px(p.games), l.g.py(p.auc[l.k]) });
    }
};

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
    var buf: [8192]u8 = undefined;
    var w: Writer = .fixed(&buf);
    try section(&w, points);
    try std.testing.expect(std.mem.find(u8, w.buffered(), "class=\"line s3\"") != null);

    const regions =
        "date\ttest_platform\tgames\tauc_base\tauc_current\tauc_joint\n" ++
        "d\tEUW1\t8000\t0.50\t0.51\t0.52\n" ++
        "d\t\t9000\t0.54\t0.55\t0.56\n";
    const global = try parse(arena.allocator(), regions);
    try std.testing.expectEqual(1, global.len);
    try std.testing.expectEqual(9000, global[0].games);
}
