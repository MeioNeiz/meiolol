//! AucChart: the method page's "Model accuracy vs data", AUC on held-out games for a few
//! models, one point per daily eval run (src/site/evalchart.zig reads them). A key names
//! the lines by their dash; the model in use carries its latest figure at the end. The
//! y axis keeps 0.5 (a coin flip) in view: how close to it draft prediction still is
const std = @import("std");
const tree = @import("tree.zig");
const chart = @import("chart.zig");
const phrase = @import("phrase.zig");
const Gallery = @import("gallery.zig").Gallery;
const H = tree.H;
const N = tree.N;

pub const name = "AucChart";
pub const scope = .{".c-auc"};

pub const Series = struct {
    label: []const u8,
    /// One per run, in `games` order
    auc: []const f32,
    kind: chart.Line,
};

pub const AucChart = struct {
    /// Games the models learnt from, one per run, ascending
    games: []const u32,
    /// The first is the answer, its figure at the end
    series: []const Series,
    caption: []const u8 = "",

    pub fn view(c: AucChart, h: *H) N {
        const n = c.games.len;
        if (n < 2 or c.series.len == 0) return .none;
        var lo: f32 = 0.5;
        var hi: f32 = 0.5;
        for (c.series) |s| for (s.auc) |v| {
            lo = @min(lo, v);
            hi = @max(hi, v);
        };
        // Room around the coin-flip line, in steps of 0.01
        lo = @floor(lo * 100 - 1) / 100;
        hi = @max(@ceil(hi * 100 + 1) / 100, 0.53);
        const p: chart.Plane = .{ .x = .{ .lo = 0, .hi = @floatFromInt(n - 1) }, .y = .{ .lo = lo, .hi = hi } };
        var ticks: std.ArrayList(chart.Tick) = .empty;
        var marks = h.list();
        var key = h.list();
        var at = lo;
        while (at <= hi + 1e-4) : (at += 0.01) ticks.append(h.mem, .{ .at = p.py(at), .label = .{ .s = h.fmt("{d:.2}", .{at}) }, .zero = @abs(at - 0.5) < 1e-4 }) catch {
            h.oom = true;
        };
        for (c.series) |s| {
            marks.add(chart.line(h, p, s.auc, s.kind));
            key.add(h.li(.{ .data_k = s.kind }, .{ h.el(.i, .{}, .{}), s.label }));
        }
        const main = c.series[0].auc;
        const xs = h.mem.dupe(chart.Tick, &.{
            .{ .at = 0, .label = .{ .s = h.fmt("{s} games", .{phrase.num(h, .count, c.games[0]).s}) } },
            .{ .at = 100, .label = .{ .s = h.fmt("{s} games", .{phrase.num(h, .count, c.games[n - 1]).s}) } },
        }) catch {
            h.oom = true;
            return .none;
        };
        return chart.frame(h, .{
            .label = .{ .s = "AUC by games learnt from" },
            .class = "c-chart c-auc",
            .height = 200,
            .right = 48,
            .y = ticks.items,
            .x = xs,
            .above = &.{h.ul(.{ .class = "key" }, .{key.done()})},
            .marks = marks.done(),
            .over = &.{chart.endLabel(h, p, main[main.len - 1], .{ .s = h.fmt("{d:.3}", .{main[main.len - 1]}) })},
            .foot = if (c.caption.len > 0) h.p(.{ .class = "cap" }, .{c.caption}) else .none,
        });
    }
};

pub const css =
    \\@layer components {
    \\  .c-auc > .key { display: flex; flex-wrap: wrap; gap: var(--sp-1) var(--sp-3); margin: 0 0 var(--sp-2) -40px;
    \\    padding: 0; list-style: none; color: var(--t2); font-size: var(--fs-xs); }
    \\  .c-auc > .key li { display: flex; align-items: center; gap: var(--sp-1); }
    \\  .c-auc > .key i { width: 18px; border-top: 1.5px solid var(--text); }
    \\  .c-auc > .key [data-k="typ"] i { border-top: 1.5px dashed var(--t2); }
    \\  .c-auc > .key [data-k="prev"] i { border-top: 1.5px dotted var(--faint); }
    \\  .c-auc > .cap { margin: var(--sp-2) 0 0 -40px; color: var(--muted); font-size: var(--fs-xs); line-height: var(--lh); }
    \\}
    \\
;

const demo_games = [_]u32{ 120_000, 180_000, 260_000, 340_000, 410_000, 480_000 };

pub fn gallery(g: *Gallery) void {
    const series = [_]Series{
        .{ .label = "The draft model in use", .auc = &.{ 0.552, 0.556, 0.561, 0.563, 0.566, 0.567 }, .kind = .main },
        .{ .label = "Champion win rates alone", .auc = &.{ 0.538, 0.540, 0.541, 0.541, 0.542, 0.541 }, .kind = .prev },
        .{ .label = "Joint ratings (on trial)", .auc = &.{ 0.549, 0.557, 0.563, 0.568, 0.571, 0.574 }, .kind = .typ },
    };
    g.addFill("six runs, three models", (AucChart{ .games = &demo_games, .series = &series, .caption = "AUC on held-out games against the games the models learnt from; one point per daily run." }).view(g.h));
}

const testing = std.testing;

test "the coin flip stays in view; the model in use ends on its figure; under two runs, nothing" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    const series = [_]Series{
        .{ .label = "In use", .auc = &.{ 0.56, 0.571 }, .kind = .main },
        .{ .label = "Base", .auc = &.{ 0.54, 0.545 }, .kind = .prev },
    };
    var out: std.Io.Writer.Allocating = .init(a);
    try @import("html.zig").write(&t, (AucChart{ .games = &.{ 1000, 2000 }, .series = &series }).view(&h), &out.writer);
    try testing.expect(!h.oom);
    const s = out.written();
    for ([_][]const u8{ ">0.50<", ">0.59<", ">0.571<", ">1,000 games<", ">2,000 games<", "data-k=\"prev\"" }) |w| {
        if (std.mem.find(u8, s, w) == null) {
            std.debug.print("missing {s} in {s}\n", .{ w, s });
            return error.TestUnexpectedResult;
        }
    }
    try testing.expectEqual(N.none, (AucChart{ .games = &.{1000}, .series = series[0..1] }).view(&h));
}
