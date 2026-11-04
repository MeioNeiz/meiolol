//! /private/truth: the truth test's daily scores (E2, docs/plan/estimates.md), each mode
//! against the next 7 days' games on the newest patch, read from the box's daily
//! data/truth-<patch>.tsv (src/truth.zig writeTsv, deploy/web-loop.sh). Written as a
//! method page section; private until Meio is a mode on the public pages (E9)
const std = @import("std");
const ui = @import("ui");
const html = @import("html.zig");
const shell = @import("shell.zig");
const sheets = @import("sheets.zig");
const truth = @import("../truth.zig");
const Date = @import("../date.zig").Date;

const Io = std.Io;
const Allocator = std.mem.Allocator;
const Writer = Io.Writer;
const Kind = truth.Kind;

const days = truth.buckets;
const regions = [_]struct { tsv: []const u8, name: []const u8 }{
    .{ .tsv = "EUW1", .name = "EUW" },
    .{ .tsv = "every region", .name = "Every region" },
};
/// Comparisons shown, by writeTsv's column prefix: Meio against each raw mode, and on
/// cells the 30 days has too few games for, against the champion-role's 30-day rate
const versus = [_][]const u8{ "meio_30", "meio_patch", "unseen" };
const modes = [_][]const u8{ "30d", "patch", "meio" };
/// An honest 80% range holds this share of targets; outside `honest` it is too narrow or
/// too wide
const honest = [2]f64{ 0.77, 0.83 };

/// One comparison's sums: loss sums as writeTsv prints them (rates: nats; gold at 14:
/// noise-corrected squared error times games) and the clustered se's variance times obs^2
const Versus = struct {
    cells: f64 = 0,
    obs: f64 = 0,
    a: f64 = 0,
    b: f64 = 0,
    var_obs2: f64 = 0,

    fn add(v: *Versus, o: Versus) void {
        inline for (@typeInfo(Versus).@"struct".field_names) |f| @field(v, f) += @field(o, f);
    }

    /// Challenger minus reference per observation, and its se. Pooling buckets keeps
    /// each one's own mean in its variance: slightly wider than one pass over all cells
    fn diff(v: Versus) struct { mean: f64, se: f64 } {
        if (v.obs == 0) return .{ .mean = 0, .se = 0 };
        return .{ .mean = (v.a - v.b) / v.obs, .se = @sqrt(v.var_obs2) / v.obs };
    }
};

/// One mode's 80% ranges: cells, PIT inside summed; on cells Meio ranges too, half-widths
const Ranges = struct {
    cells: f64 = 0,
    pit: f64 = 0,
    /// The raw mode's and Meio's half-widths summed over `paired` cells
    paired: f64 = 0,
    half: f64 = 0,
    half_meio: f64 = 0,

    fn add(r: *Ranges, o: Ranges) void {
        inline for (@typeInfo(Ranges).@"struct".field_names) |f| @field(r, f) += @field(o, f);
    }
};

/// One (region, kind, day bucket), all ranks
const Cell = struct {
    vs: [versus.len]Versus = @splat(.{}),
    ranges: [modes.len]Ranges = @splat(.{}),

    fn add(c: *Cell, o: Cell) void {
        for (&c.vs, o.vs) |*a, b| a.add(b);
        for (&c.ranges, o.ranges) |*a, b| a.add(b);
    }
};

pub const Scores = struct {
    patch: []const u8 = "",
    t0_ms: i64 = 0,
    cells: [regions.len][Kind.count][days.len]Cell = @splat(@splat(@splat(.{}))),

    fn all(s: *const Scores, r: usize, k: Kind) Cell {
        var c: Cell = .{};
        for (s.cells[r][@backingInt(k)]) |d| c.add(d);
        return c;
    }
};

/// The TSV's all-ranks rows by column name; rows of unknown regions, kinds or days, and
/// short ones, skipped. Null when a column it needs is missing (an older truth binary)
pub fn parse(tsv: []const u8) ?Scores {
    var lines = std.mem.tokenizeScalar(u8, tsv, '\n');
    const header = lines.next() orelse return null;
    const Col = enum { patch, t0_ms, region, kind, bracket, day };
    const per_vs = [_][]const u8{ "cells", "obs", "loss_a", "loss_b", "se" };
    const per_mode = [_][]const u8{ "solid_cells", "solid_pit", "faded_cells", "faded_pit" };
    const per_width = [_][]const u8{ "cells", "half", "half_meio" };
    var at: struct {
        col: [6]?usize = @splat(null),
        vs: [versus.len][per_vs.len]?usize = @splat(@splat(null)),
        mode: [modes.len][per_mode.len]?usize = @splat(@splat(null)),
        width: [2][per_width.len]?usize = @splat(@splat(null)),
    } = .{};
    var names = std.mem.splitScalar(u8, std.mem.trimEnd(u8, header, "\r"), '\t');
    var i: usize = 0;
    var buf: [64]u8 = undefined;
    while (names.next()) |name| : (i += 1) {
        if (std.meta.stringToEnum(Col, name)) |c| at.col[@backingInt(c)] = i;
        for (versus, &at.vs) |v, *slots| for (per_vs, slots) |f, *slot| {
            if (std.mem.eql(u8, name, std.fmt.bufPrint(&buf, "{s}_{s}", .{ v, f }) catch unreachable)) slot.* = i;
        };
        for (modes, &at.mode) |m, *slots| for (per_mode, slots) |f, *slot| {
            if (std.mem.eql(u8, name, std.fmt.bufPrint(&buf, "cal_{s}_{s}", .{ m, f }) catch unreachable)) slot.* = i;
        };
        for (modes[0..2], &at.width) |m, *slots| for (per_width, slots) |f, *slot| {
            if (std.mem.eql(u8, name, std.fmt.bufPrint(&buf, "width_{s}_{s}", .{ m, f }) catch unreachable)) slot.* = i;
        };
    }
    var max: usize = 0;
    for (at.col) |c| max = @max(max, c orelse return null);
    for (at.vs) |s| for (s) |c| {
        max = @max(max, c orelse return null);
    };
    for (at.mode) |s| for (s) |c| {
        max = @max(max, c orelse return null);
    };
    for (at.width) |s| for (s) |c| {
        max = @max(max, c orelse return null);
    };

    var out: Scores = .{};
    lines: while (lines.next()) |line| {
        var f: [256][]const u8 = undefined;
        var n: usize = 0;
        var it = std.mem.splitScalar(u8, std.mem.trimEnd(u8, line, "\r"), '\t');
        while (it.next()) |x| : (n += 1) {
            if (n == f.len) continue :lines;
            f[n] = x;
        }
        if (n <= max) continue;
        const col = struct {
            fn get(fs: []const []const u8, a: [6]?usize, c: Col) []const u8 {
                return fs[a[@backingInt(c)].?];
            }
        }.get;
        if (!std.mem.eql(u8, col(&f, at.col, .bracket), "all ranks")) continue;
        const r = for (regions, 0..) |x, j| {
            if (std.mem.eql(u8, x.tsv, col(&f, at.col, .region))) break j;
        } else continue;
        const k = std.meta.stringToEnum(Kind, col(&f, at.col, .kind)) orelse continue;
        const d = for (days, 0..) |x, j| {
            if (std.mem.eql(u8, x, col(&f, at.col, .day))) break j;
        } else continue;
        const num = struct {
            fn get(fs: []const []const u8, j: ?usize) f64 {
                const v = std.fmt.parseFloat(f64, fs[j.?]) catch return 0;
                return if (std.math.isFinite(v)) v else 0;
            }
        }.get;
        var c: Cell = .{};
        for (&c.vs, at.vs) |*v, s| v.* = .{
            .cells = num(&f, s[0]),
            .obs = num(&f, s[1]),
            .a = num(&f, s[2]),
            .b = num(&f, s[3]),
            .var_obs2 = std.math.pow(f64, num(&f, s[4]) * num(&f, s[1]), 2),
        };
        for (&c.ranges, at.mode) |*m, s| m.* = .{
            .cells = num(&f, s[0]) + num(&f, s[2]),
            .pit = num(&f, s[1]) + num(&f, s[3]),
        };
        for (c.ranges[0..2], at.width) |*m, s| {
            m.paired = num(&f, s[0]);
            m.half = num(&f, s[1]);
            m.half_meio = num(&f, s[2]);
        }
        out.cells[r][@backingInt(k)][d].add(c);
        if (out.patch.len == 0) {
            out.patch = col(&f, at.col, .patch);
            out.t0_ms = std.fmt.parseInt(i64, col(&f, at.col, .t0_ms), 10) catch 0;
        }
    }
    return out;
}

/// Meio against a raw mode in words: ahead or behind by more than 2 se, else level.
/// Rates in milli-nats of log loss per game; gold at 14 in gold of error (root mean
/// square, noise-corrected)
fn vsCell(w: *Writer, k: Kind, v: Versus) !void {
    if (v.obs == 0) return w.writeAll(" |");
    var d = v.diff();
    if (k == .gold14) {
        const ra = @sqrt(@max(0, v.a / v.obs));
        const rb = @sqrt(@max(0, v.b / v.obs));
        d = .{ .mean = ra - rb, .se = if (rb > 0) d.se / (2 * rb) else 0 };
    } else {
        d = .{ .mean = 1000 * d.mean, .se = 1000 * d.se };
    }
    const prec: usize = if (k == .gold14) 0 else 2;
    if (@abs(d.mean) <= 2 * d.se) return w.print(" level, {d:.[2]} ±{d:.[2]} |", .{ d.mean, 2 * d.se, prec });
    try w.print(" {s} {d:.[3]} ±{d:.[3]} |", .{ if (d.mean < 0) "ahead" else "behind", @abs(d.mean), 2 * d.se, prec });
}

/// The day buckets where Meio is not clearly ahead of both raw modes (E2's gate: ahead in
/// every one)
fn gateCell(w: *Writer, s: *const Scores, r: usize, k: Kind) !void {
    var behind: [days.len]bool = @splat(false);
    var level: [days.len]bool = @splat(false);
    for (s.cells[r][@backingInt(k)], 0..) |c, d| for (c.vs[0..2]) |v| {
        if (v.obs == 0) continue;
        const x = v.diff();
        if (x.mean > 2 * x.se) behind[d] = true else if (x.mean >= -2 * x.se) level[d] = true;
    };
    if (std.mem.findScalar(bool, &behind, true) == null and std.mem.findScalar(bool, &level, true) == null)
        return w.writeAll(" every day |");
    try w.writeByte(' ');
    var first = true;
    for ([_]*const [days.len]bool{ &behind, &level }, [_][]const u8{ "behind", "level" }) |set, word| {
        if (std.mem.findScalar(bool, set, true) == null) continue;
        if (!first) try w.writeAll("; ");
        first = false;
        try w.print("{s} day ", .{word});
        var sep = false;
        for (set, days) |on, name| if (on) {
            if (sep) try w.writeAll(", ");
            sep = true;
            try w.writeAll(name);
        };
    }
    try w.writeAll(" |");
}

fn pitOf(r: Ranges) ?f64 {
    return if (r.cells > 0) r.pit / r.cells else null;
}

fn pct(w: *Writer, x: ?f64) !void {
    if (x) |v| try w.print("{d:.0}%", .{100 * v}) else try w.writeAll("-");
}

/// The section's markdown: one table per region, a kind a row, every day bucket pooled
pub fn section(a: Allocator, s: *const Scores) ![]const u8 {
    var out: Writer.Allocating = .init(a);
    const w = &out.writer;
    try w.print(
        \\Each day of patch {s} (from {f}), every mode is built from the games before that
        \\day and scored against the next 7 days' games on the patch: 30 days and patch
        \\are the raw windows, Meio our estimate. **Ahead** and **behind** are Meio's
        \\log loss per game against the raw mode's, in thousandths (gold at 14: gold of
        \\error), ± two standard errors; level when within them. **Every day**: the days
        \\since the patch where Meio isn't yet ahead of both raw windows. **New**: cells
        \\the 30 days has too few games for, Meio against the champion's own rate. **In
        \\range**: how often the next week landed inside each mode's 80% range (80% is
        \\honest); **±** its mean half-width in points, on cells Meio ranges too.
        \\
    , .{ s.patch, Date.fromMs(s.t0_ms).long() });
    var narrow: std.ArrayList([]const u8) = .empty;
    var narrow_pit: std.ArrayList(f64) = .empty;
    for (regions, 0..) |region, r| {
        for (std.enums.values(Kind)) |k| {
            if (s.all(r, k).vs[0].cells > 0) break;
        } else continue;
        try w.print(
            \\
            \\### {s}
            \\
            \\| Number | Meio vs 30 days | Meio vs patch | New | Every day |
            \\|---|---|---|---|---|
            \\
        , .{region.name});
        for (std.enums.values(Kind)) |k| {
            const c = s.all(r, k);
            if (c.vs[0].cells == 0 and c.vs[1].cells == 0) continue;
            try w.print("| {s} |", .{truth.label(k)});
            for (c.vs) |v| try vsCell(w, k, v);
            try gateCell(w, s, r, k);
            try w.writeByte('\n');
        }
        try w.writeAll(
            \\
            \\| Number | In range 30d / patch / Meio | ± 30d / patch / Meio |
            \\|---|---|---|
            \\
        );
        for (std.enums.values(Kind)) |k| {
            const c = s.all(r, k);
            if (k == .gold14 or c.ranges[2].cells == 0) continue;
            try w.print("| {s} | ", .{truth.label(k)});
            for (c.ranges, 0..) |m, i| {
                if (i > 0) try w.writeAll(" / ");
                try pct(w, pitOf(m));
            }
            const p = c.ranges[1];
            if (p.paired > 0) {
                try w.print(" | ±{d:.1} / ±{d:.1} / ±{d:.1} |\n", .{
                    100 * c.ranges[0].half / @max(1, c.ranges[0].paired), 100 * p.half / p.paired, 100 * p.half_meio / p.paired,
                });
            } else try w.writeAll(" | |\n");
            if (r == 0) if (pitOf(c.ranges[2])) |v| if (v < honest[0]) {
                try narrow.append(a, truth.label(k));
                try narrow_pit.append(a, v);
            };
        }
    }
    if (narrow.items.len > 0) {
        try w.writeAll("\nToo sure for now: Meio's ranges for ");
        for (narrow.items, narrow_pit.items, 0..) |name, v, i| {
            if (i > 0) try w.writeAll(if (i + 1 == narrow.items.len) " and " else ", ");
            try w.print("{s} ({d:.0}%)", .{ name, 100 * v });
        }
        try w.writeAll(" hold fewer than 8 in 10 of the next week's games in EUW: read them as narrower than they are.\n");
    }
    return out.written();
}

/// The newest patch's truth-<patch>.tsv in `data_dir`; null without one
pub fn newest(a: Allocator, io: Io, data_dir: []const u8) !?[]const u8 {
    var dir = Io.Dir.cwd().openDir(io, data_dir, .{ .iterate = true }) catch |e| switch (e) {
        error.FileNotFound => return null,
        else => return e,
    };
    defer dir.close(io);
    var best: ?[]const u8 = null;
    var best_v: [2]u32 = .{ 0, 0 };
    var it = dir.iterate();
    while (try it.next(io)) |e| {
        if (e.kind != .file or !std.mem.startsWith(u8, e.name, "truth-") or !std.mem.endsWith(u8, e.name, ".tsv")) continue;
        const v = patchOf(e.name["truth-".len .. e.name.len - ".tsv".len]) orelse continue;
        if (best == null or v[0] > best_v[0] or (v[0] == best_v[0] and v[1] > best_v[1])) {
            best = try a.dupe(u8, e.name);
            best_v = v;
        }
    }
    const name = best orelse return null;
    return try dir.readFileAlloc(io, name, a, .limited(16 << 20));
}

fn patchOf(s: []const u8) ?[2]u32 {
    const dot = std.mem.findScalar(u8, s, '.') orelse return null;
    return .{
        std.fmt.parseInt(u32, s[0..dot], 10) catch return null,
        std.fmt.parseInt(u32, s[dot + 1 ..], 10) catch return null,
    };
}

/// The page's HTML, in the site shell with its CSS inline
pub fn page(a: Allocator, tsv: ?[]const u8) ![]const u8 {
    const s = if (tsv) |t| parse(t) else null;
    var t: ui.Tree = .{};
    var h: ui.H = .init(a, &t);
    const body = if (s) |x| try section(a, &x) else "No truth test yet: the box writes it once a day for the newest patch.";
    const p: ui.textpage.TextPage = .{
        .title = "Truth test",
        .lead = "How well each mode predicted the next week's games on the newest patch, scored daily.",
        .body = try ui.prose.parse(a, body),
    };
    const n = p.view(&h);
    if (h.oom) return error.OutOfMemory;
    var out: Writer.Allocating = .init(a);
    const w = &out.writer;
    const pg: html.Page = .{ .title = "Truth test | meiolol", .description = "Each mode scored against the next week's games", .patch = "", .data = "", .public = false, .private = .index };
    try shell.open(w, pg);
    try ui.html.write(&t, n, w);
    try shell.close(w, pg);
    return sheets.deliver(a, out.written());
}

/// truth.html and its .gz into the private site's dir, from data_dir's newest truth TSV
pub fn write(gpa: Allocator, io: Io, out_dir: []const u8, data_dir: []const u8) !void {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    const a = arena.allocator();
    const data = try page(a, try newest(a, io, data_dir));
    var dir = try Io.Dir.cwd().openDir(io, out_dir, .{});
    defer dir.close(io);
    try dir.writeFile(io, .{ .sub_path = "truth.html", .data = data });
    try dir.writeFile(io, .{ .sub_path = "truth.html.gz", .data = try @import("store").raw.compress(a, data) });
}

/// writeTsv's TSV of one EUW day-0 cell set per kind given, every other cell empty
fn testTsv(a: Allocator, res: *truth.Results) ![]const u8 {
    var w: Writer.Allocating = .init(a);
    try truth.writeTsv(res, "16.21", 1792559571121, &w.writer);
    return w.written();
}

test "pooled scores per kind from writeTsv's columns, all ranks only" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const res = try a.create(truth.Results);
    res.* = @splat(@splat(@splat(@splat(.{}))));
    const euw = 1;
    try std.testing.expectEqualStrings("EUW1", truth.regions[euw]);
    const champ = &res[euw][@backingInt(Kind.champion)];
    // Day 0: Meio 2 milli-nats a game better than 30 days, 3 worse than patch
    champ[0][0].target = 1000;
    champ[0][0].pairs[@backingInt(truth.Comparison.meio_30)] = .{ .obs = 1000, .cells = 10, .challenger = 690, .reference = 692, .d = -2 };
    champ[0][0].pairs[@backingInt(truth.Comparison.meio_patch)] = .{ .obs = 1000, .cells = 10, .challenger = 695, .reference = 692, .d = 3 };
    champ[0][0].cal[0][0] = .{ .cells = 10, .pit = 8 };
    champ[0][0].cal[1][1] = .{ .cells = 10, .pit = 8 };
    champ[0][0].cal[2][0] = .{ .cells = 10, .pit = 7 };
    champ[0][0].widths = .{
        .{ .cells = 10, .half = .{ 0.6, 0.2 } },
        .{ .cells = 10, .half = .{ 0.5, 0.2 } },
    };
    // Day 1, ahead of both: pooled with day 0
    champ[0][1].target = 1000;
    champ[0][1].pairs[@backingInt(truth.Comparison.meio_30)] = .{ .obs = 1000, .cells = 10, .challenger = 690, .reference = 692, .d = -2 };
    champ[0][1].pairs[@backingInt(truth.Comparison.meio_patch)] = .{ .obs = 1000, .cells = 10, .challenger = 690, .reference = 692, .d = -2, .dd = 1, .dn = -200, .nn = 1e5 };
    // A bracket's row: not on the page
    champ[1][0] = champ[0][0];
    champ[1][0].pairs[@backingInt(truth.Comparison.meio_30)].challenger = 9999;
    // Gold at 14: root mean square error 20 against 30
    const gold = &res[euw][@backingInt(Kind.gold14)][0][0];
    gold.target = 100;
    gold.pairs[@backingInt(truth.Comparison.meio_30)] = .{ .obs = 100, .cells = 10, .challenger = 100 * 400, .reference = 100 * 900, .d = -50000 };

    const s = parse(try testTsv(a, res)).?;
    try std.testing.expectEqualStrings("16.21", s.patch);
    const md = try section(a, &s);
    for ([_][]const u8{
        "| champion-role | ahead 2.00 ±0.00 | level, 0.50 ±0.77 | | behind day 0 |",
        "| champion-role | 80% / 80% / 70% | ±6.0 / ±5.0 / ±2.0 |",
        "| gold at 14 (matchup) | ahead 10 ±0 | | | every day |",
        "Meio's ranges for champion-role (70%) hold fewer than 8 in 10",
        "### EUW\n",
    }) |want| {
        std.testing.expect(std.mem.find(u8, md, want) != null) catch |e| {
            std.debug.print("missing {s} in\n{s}\n", .{ want, md });
            return e;
        };
    }
    // No every-region rows, no table for it
    try std.testing.expect(std.mem.find(u8, md, "Every region") == null);
    _ = try ui.prose.parse(a, md);
}

test "a TSV without the newer columns: none; the newest patch's file" {
    try std.testing.expectEqual(null, parse("patch\tt0_ms\tregion\tkind\tbracket\tday\ttarget\n"));
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    const io = std.testing.io;
    for ([_][2][]const u8{ .{ "truth-16.9.tsv", "9" }, .{ "truth-16.21.tsv", "21" }, .{ "truth-16.21.md", "md" }, .{ "truth-x.tsv", "x" } }) |f|
        try tmp.dir.writeFile(io, .{ .sub_path = f[0], .data = f[1] });
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const dir = try std.fs.path.join(a, &.{ ".zig-cache", "tmp", &tmp.sub_path });
    try std.testing.expectEqualStrings("21", (try newest(a, io, dir)).?);
    try std.testing.expectEqual(null, try newest(a, io, try std.fs.path.join(a, &.{ dir, "none" })));
}
