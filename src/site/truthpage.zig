//! /private/truth: the truth test's daily scores (E2, docs/plan/estimates.md), each mode
//! against the next 7 days' games on the newest patch, read from the box's daily
//! data/truth-<patch>.tsv (src/truth.zig writeTsv, deploy/web-loop.sh). The method page's
//! order: track record, changelog, how it works, what it leaves out. Private until Meio
//! is a mode on the public pages (E9)
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
/// Sign test level for ahead or behind on interval scores
const sign_p = 0.05;

/// One comparison's sums: loss sums as writeTsv prints them (rates: nats; gold at 14:
/// noise-corrected squared error times games) and the clustered se's variance times obs^2
const Versus = struct {
    cells: f64 = 0,
    obs: f64 = 0,
    a: f64 = 0,
    b: f64 = 0,
    var_obs2: f64 = 0,

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
};

/// Interval scores of Meio against one raw mode on the cells both range (truth.Wis):
/// side 0 the raw mode, 1 Meio
const Scored = struct {
    cells: f64 = 0,
    /// Width, below, above summed
    parts: [2][3]f64 = @splat(@splat(0)),
    /// Cells whose target fell below, above the range
    miss: [2][2]f64 = @splat(@splat(0)),
    /// Day origins with paired cells, and of them where Meio's sum was lower
    blocks: f64 = 0,
    ahead: f64 = 0,
    /// Per target-games band (truth.sizes): cells, the raw mode's sum, Meio's
    size: [truth.sizes.len][3]f64 = @splat(@splat(0)),

    fn total(x: Scored, side: usize) f64 {
        return x.parts[side][0] + x.parts[side][1] + x.parts[side][2];
    }

    fn skill(x: Scored) ?f64 {
        return skillOf(x.total(0), x.total(1));
    }
};

fn skillOf(ref: f64, meio: f64) ?f64 {
    return if (ref > 0) 1 - meio / ref else null;
}

/// Meio's PIT inside summed over a set of cells
const Cover = struct {
    cells: f64 = 0,
    pit: f64 = 0,
};

/// One (region, kind, day bucket), all ranks
const Cell = struct {
    vs: [versus.len]Versus = @splat(.{}),
    ranges: [modes.len]Ranges = @splat(.{}),
    /// Against 30 days, against patch
    scored: [2]Scored = @splat(.{}),
    /// By Meio's weight on the cell's own games (truth.weight_bands)
    weight: [truth.weight_bands.len]Cover = @splat(.{}),
    /// The cells lists sorted by Meio's estimate show first
    shown: Cover = .{},

    fn add(c: *Cell, o: Cell) void {
        addAll(Cell, c, o);
    }
};

/// Every float in a plain struct of floats, arrays and structs, added
fn addAll(comptime T: type, a: *T, b: T) void {
    switch (@typeInfo(T)) {
        .float => a.* += b,
        .array => |info| for (a, b) |*x, y| addAll(info.child, x, y),
        .@"struct" => inline for (@typeInfo(T).@"struct".field_names) |f| addAll(@FieldType(T, f), &@field(a, f), @field(b, f)),
        else => @compileError("addAll: " ++ @typeName(T)),
    }
}

pub const Scores = struct {
    patch: []const u8 = "",
    t0_ms: i64 = 0,
    cells: [regions.len][Kind.count][days.len]Cell = @splat(@splat(@splat(.{}))),
    /// From the every-day row: median half-widths [vs 30d, vs patch][raw, Meio] (points;
    /// gold at 14: gold); null from an older truth binary
    medians: [regions.len][Kind.count]?[2][2]f64 = @splat(@splat(null)),

    fn all(s: *const Scores, r: usize, k: Kind) Cell {
        var c: Cell = .{};
        for (s.cells[r][@backingInt(k)]) |d| c.add(d);
        return c;
    }

    fn any(s: *const Scores, r: usize) bool {
        for (std.enums.values(Kind)) |k| {
            const c = s.all(r, k);
            if (c.vs[0].cells > 0 or c.vs[1].cells > 0) return true;
        }
        return false;
    }
};

const max_cols = 256;

/// The TSV header's column names
const Header = struct {
    names: [max_cols][]const u8 = undefined,
    len: usize = 0,

    fn at(h: *const Header, comptime fmt: []const u8, args: anytype) ?usize {
        var buf: [64]u8 = undefined;
        const name = std.fmt.bufPrint(&buf, fmt, args) catch return null;
        for (h.names[0..h.len], 0..) |n, i| {
            if (std.mem.eql(u8, n, name)) return i;
        }
        return null;
    }
};

/// Every index in x (an optional or nested arrays of them) present; max raised to the
/// largest
fn need(x: anytype, max: *usize) bool {
    switch (@typeInfo(@TypeOf(x))) {
        .optional => {
            max.* = @max(max.*, x orelse return false);
            return true;
        },
        .array => {
            for (x) |y| if (!need(y, max)) return false;
            return true;
        },
        else => @compileError("need: " ++ @typeName(@TypeOf(x))),
    }
}

/// One TSV row's fields; columns past its end or absent from the header read 0
const Fields = struct {
    f: []const []const u8,

    fn num(r: Fields, j: ?usize) f64 {
        const i = j orelse return 0;
        if (i >= r.f.len) return 0;
        const v = std.fmt.parseFloat(f64, r.f[i]) catch return 0;
        return if (std.math.isFinite(v)) v else 0;
    }
};

/// The TSV's all-ranks rows by column name; rows of unknown regions, kinds or days, and
/// short ones, skipped. Null when a column it needs is missing (an older truth binary);
/// the interval score and coverage columns are optional (0 when absent)
pub fn parse(tsv: []const u8) ?Scores {
    var lines = std.mem.tokenizeScalar(u8, tsv, '\n');
    var h: Header = .{};
    var names = std.mem.splitScalar(u8, std.mem.trimEnd(u8, lines.next() orelse return null, "\r"), '\t');
    while (names.next()) |name| : (h.len += 1) {
        if (h.len == max_cols) return null;
        h.names[h.len] = name;
    }
    const Col = enum { patch, t0_ms, region, kind, bracket, day };
    const per_vs = [_][]const u8{ "cells", "obs", "loss_a", "loss_b", "se" };
    const per_mode = [_][]const u8{ "solid_cells", "solid_pit", "faded_cells", "faded_pit" };
    const per_width = [_][]const u8{ "cells", "half", "half_meio" };
    const per_wis = [_][]const u8{
        "cells",      "width",      "below",           "above",           "width_meio", "below_meio", "above_meio",
        "miss_below", "miss_above", "miss_below_meio", "miss_above_meio", "blocks",     "ahead",
    };
    var at: struct {
        col: [6]?usize = @splat(null),
        vs: [versus.len][per_vs.len]?usize = @splat(@splat(null)),
        mode: [modes.len][per_mode.len]?usize = @splat(@splat(null)),
        width: [2][per_width.len]?usize = @splat(@splat(null)),
        median: [2][2]?usize = @splat(@splat(null)),
        wis: [2][per_wis.len]?usize = @splat(@splat(null)),
        size: [2][truth.sizes.len][3]?usize = @splat(@splat(@splat(null))),
        weight: [truth.weight_bands.len][2]?usize = @splat(@splat(null)),
        shown: [2]?usize = @splat(null),
    } = .{};
    for (&at.col, std.enums.values(Col)) |*x, c| x.* = h.at("{t}", .{c});
    for (&at.vs, versus) |*slots, v| {
        for (slots, per_vs) |*x, f| x.* = h.at("{s}_{s}", .{ v, f });
    }
    for (&at.mode, modes) |*slots, m| {
        for (slots, per_mode) |*x, f| x.* = h.at("cal_{s}_{s}", .{ m, f });
    }
    for (&at.width, &at.median, &at.wis, &at.size, modes[0..2]) |*width, *median, *wis, *size, m| {
        for (width, per_width) |*x, f| x.* = h.at("width_{s}_{s}", .{ m, f });
        median[0] = h.at("width_{s}_median", .{m});
        median[1] = h.at("width_{s}_median_meio", .{m});
        for (wis, per_wis) |*x, f| x.* = h.at("wis_{s}_{s}", .{ m, f });
        for (size, truth.size_tags) |*slots, z| {
            for (slots, [_][]const u8{ "cells", "ref", "meio" }) |*x, f| x.* = h.at("wis_{s}_{s}_{s}", .{ m, z, f });
        }
    }
    for (&at.weight, truth.weight_tags) |*slots, t| {
        slots[0] = h.at("pit_meio_{s}_cells", .{t});
        slots[1] = h.at("pit_meio_{s}_pit", .{t});
    }
    at.shown = .{ h.at("shown_meio_cells", .{}), h.at("shown_meio_pit", .{}) };
    var max: usize = 0;
    if (!need(at.col, &max) or !need(at.vs, &max) or !need(at.mode, &max) or !need(at.width, &max)) return null;
    var no_max: usize = 0;
    const has_median = need(at.median, &no_max);

    var out: Scores = .{};
    lines: while (lines.next()) |line| {
        var f: [max_cols][]const u8 = undefined;
        var n: usize = 0;
        var it = std.mem.splitScalar(u8, std.mem.trimEnd(u8, line, "\r"), '\t');
        while (it.next()) |x| : (n += 1) {
            if (n == f.len) continue :lines;
            f[n] = x;
        }
        if (n <= max) continue;
        const row: Fields = .{ .f = f[0..n] };
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
        if (std.mem.eql(u8, col(&f, at.col, .day), "all")) {
            if (has_median) {
                var m: [2][2]f64 = undefined;
                for (&m, at.median) |*x, j| x.* = .{ row.num(j[0]), row.num(j[1]) };
                out.medians[r][@backingInt(k)] = m;
            }
            continue;
        }
        const d = for (days, 0..) |x, j| {
            if (std.mem.eql(u8, x, col(&f, at.col, .day))) break j;
        } else continue;
        var c: Cell = .{};
        for (&c.vs, at.vs) |*v, s| v.* = .{
            .cells = row.num(s[0]),
            .obs = row.num(s[1]),
            .a = row.num(s[2]),
            .b = row.num(s[3]),
            .var_obs2 = std.math.pow(f64, row.num(s[4]) * row.num(s[1]), 2),
        };
        for (&c.ranges, at.mode) |*m, s| m.* = .{
            .cells = row.num(s[0]) + row.num(s[2]),
            .pit = row.num(s[1]) + row.num(s[3]),
        };
        for (c.ranges[0..2], at.width) |*m, s| {
            m.paired = row.num(s[0]);
            m.half = row.num(s[1]);
            m.half_meio = row.num(s[2]);
        }
        for (&c.scored, at.wis, at.size) |*x, s, z| {
            x.cells = row.num(s[0]);
            for (&x.parts, 0..) |*side, i| {
                for (side, 0..) |*v, j| v.* = row.num(s[1 + 3 * i + j]);
            }
            x.miss = .{ .{ row.num(s[7]), row.num(s[8]) }, .{ row.num(s[9]), row.num(s[10]) } };
            x.blocks = row.num(s[11]);
            x.ahead = row.num(s[12]);
            for (&x.size, z) |*v, cols| v.* = .{ row.num(cols[0]), row.num(cols[1]), row.num(cols[2]) };
        }
        for (&c.weight, at.weight) |*x, s| x.* = .{ .cells = row.num(s[0]), .pit = row.num(s[1]) };
        c.shown = .{ .cells = row.num(at.shown[0]), .pit = row.num(at.shown[1]) };
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

/// Under 100 cells a coverage is noise (±8 points at two standard errors)
fn coverOf(c: Cover) ?f64 {
    return if (c.cells >= 100) c.pit / c.cells else null;
}

fn pct(w: *Writer, x: ?f64) !void {
    if (x) |v| try w.print("{d:.0}%", .{100 * v}) else try w.writeAll("-");
}

/// A skill as "+12%" or "-3%"; "-" when there is none
fn signedPct(w: *Writer, x: ?f64) !void {
    const v = @round(100 * (x orelse return w.writeAll("-")));
    try w.print("{s}{d:.0}%", .{ if (v >= 0) "+" else "-", @abs(v) });
}

/// Interval score skill against a raw mode in words: ahead or behind when the sign test
/// over day origins says so, else level; then the days Meio scored lower
fn scoredCell(w: *Writer, x: Scored) !void {
    const sk = x.skill() orelse return w.writeAll(" - |");
    const p = (truth.Blocks{ .n = x.blocks, .ahead = x.ahead }).p();
    const word = if (x.blocks == 0 or p >= sign_p) "level" else if (2 * x.ahead > x.blocks) "ahead" else "behind";
    try w.print(" {s} ", .{word});
    try signedPct(w, sk);
    try w.print(", {d:.0}/{d:.0} days |", .{ x.ahead, x.blocks });
}

/// Skill per target-games band
fn sizesCell(w: *Writer, x: Scored) !void {
    try w.writeByte(' ');
    for (x.size, 0..) |z, i| {
        if (i > 0) try w.writeAll(" / ");
        try signedPct(w, if (z[0] > 0) skillOf(z[1], z[2]) else null);
    }
    try w.writeAll(" |");
}

/// The score's width, below and above parts per cell, the raw mode's then Meio's, in
/// points (gold at 14: gold)
fn partsCell(w: *Writer, k: Kind, x: Scored) !void {
    if (x.cells == 0) return w.writeAll(" - |");
    const prec: usize = if (k == .gold14) 0 else 2;
    for (x.parts, [_][]const u8{ "patch", "Meio" }, 0..) |side, name, i| {
        try w.print("{s} {s}", .{ if (i == 0) "" else ",", name });
        for (side, 0..) |v, j| try w.print("{s}{d:.[2]}", .{ if (j == 0) " " else " / ", 100 * v / x.cells, prec });
    }
    try w.writeAll(" |");
}

/// Half-widths 30 days, patch, Meio: medians from the every-day row when the TSV has
/// them, else means over the paired cells
fn halves(s: *const Scores, r: usize, k: Kind, c: Cell) ?[3]f64 {
    if (s.medians[r][@backingInt(k)]) |m| {
        const x = [3]f64{ m[0][0], m[1][0], m[1][1] };
        if (x[0] > 0 and x[1] > 0 and x[2] > 0) return x;
    }
    const p = c.ranges[1];
    if (p.paired == 0) return null;
    return .{ 100 * c.ranges[0].half / @max(1, c.ranges[0].paired), 100 * p.half / p.paired, 100 * p.half_meio / p.paired };
}

const intro =
    \\Scores for patch {s}, from {f}. Each day since the patch, every mode is scored
    \\against the next 7 days' games: 30 days and patch are the raw windows the site
    \\shows, Meio our estimate. How the scores work is under the changelog.
    \\
    \\## Track record
    \\
    \\**In range**: how often the next week landed inside each mode's 80% range (80% is
    \\honest; under it the range is too sure). **±**: the median range half-width in points
    \\(gold at 14: gold) on cells Meio ranges too. **Missed low / high**: per 100 of those
    \\cells, the next week under or over Meio's range (about 10 each is honest), counted
    \\like in range: a thin week's share of its chance to land in the bottom or top 10%.
    \\**Interval score**: Meio's against the raw mode's on the same cells; +12% is a 12%
    \\lower (better) sum; 9/10 days, the days Meio's was lower; ahead or behind when a sign
    \\test over those days says so, else level. **Width / below / above**: the score's parts
    \\per cell, patch then Meio: Meio is surer than the patch when its width is smaller and
    \\its misses no bigger. **Log loss** (the gate): Meio's per game against the raw mode's,
    \\in thousandths (gold at 14: gold of error), ± two standard errors. **New**: cells the
    \\30 days has too few games for, against the champion-role's rate. **Every day**: the
    \\days Meio isn't yet ahead of both raw windows. **Weight**: how much Meio's number
    \\rests on the cell's own games (1: all of it); **shown first**: per list, the 5
    \\highest and 5 lowest win rates, the 5 most taken shares; - under 100 cells.
    \\
;

const changelog =
    \\
    \\## Changelog
    \\
    \\- 4 Nov: missed low / high counted from the in-range count's tails: a rare share's
    \\  normal range can't miss low, so shares read as missing high
    \\- 4 Nov: the site's Gold+ rank set (Plat+ and Emerald+ floors) scored; interval
    \\  scores beside the log loss gate; Meio's in range by weight and on the cells shown
    \\  first
    \\- 4 Nov: share targets scored on their games over phi (players repeat picks: items
    \\  1.1, keystones 1.2); gold at 14 ranges
    \\- 4 Nov: Meio shares: ranges add the drift within a patch; a player's repeated picks
    \\  count 1/phi games
    \\- 4 Nov: in range counted by randomised PIT, 80% for an honest range at any target
    \\  size (thin targets landed inside any range)
    \\- 4 Nov: Meio on lock stacks: keystone or item against a lane opponent, keystone with
    \\  item; keystone and item shares; lane gold at 14
    \\- 4 Nov: Meio: all ranks and every region average the champion-role's own; a
    \\  champion-role shrinks to a line in its share of the role's games, a seldom-taken
    \\  keystone or item to a share line
    \\
;

const how =
    \\
    \\## How it works
    \\
    \\Each day d since the patch went live on EUW, every mode is built from the games
    \\before that day and scored against the patch's games in the 7 days after. A cell is
    \\a champion-role, one lock on it (matchup, duo, item, keystone, gold at 14) or two
    \\(keystone or item against a lane opponent, keystone with item).
    \\
    \\- **Log loss**: of the next week's games under each mode's number (gold at 14:
    \\  squared error net of the target's own noise), summed per game. The gate: Meio
    \\  ahead of both raw windows by more than two standard errors, every day
    \\- **In range**: randomised PIT coverage. A next week of 1 game at 50% lands inside
    \\  any range, so it counts the chance the week's result falls in the middle 80% of
    \\  what the mode predicted: 80% for an honest range at any number of games
    \\- **Interval score**: (2/3)(0.5 abs(y - p) + 0.1 (width + 10 below + 10 above)), with y the
    \\  next week's value and the range widened by its noise. Proper: no mode scores better
    \\  by claiming a range narrower or wider than it believes, and a narrow range can
    \\  still lose on misses. Each cell counts once, big or small; thin cells carry most of
    \\  the sum, so it is also split by the week's games (under 20, 20-199, 200+)
    \\- **Days**: the sign test's blocks are day origins per region. Neighbouring days
    \\  share target games, so its p and the standard errors are optimistic
    \\
;

const leaves_out =
    \\
    \\## What it leaves out
    \\
    \\- Master+: the site shows those floors raw, so there is no Meio to score
    \\- The Gold+ set includes Gold: the Plat+ and Emerald+ floors are served from Meio's
    \\  Gold-and-up fit and scored on those games pooled
    \\- In range reads Meio's range as symmetric around its number; the interval score
    \\  takes its ends as they are
    \\- One horizon, the next 7 days, on the newest patch only; two locks deep at most
    \\- Weight is a proxy: Meio's variance over the cell's own games' binomial variance,
    \\  exact for a single normal prior only
    \\- Rank brackets are in the daily TSV, not on this page
    \\
;

/// The page's markdown: the track record per region (a kind a row, every day pooled),
/// then the changelog, how it works and what it leaves out
pub fn section(a: Allocator, s: *const Scores) ![]const u8 {
    var out: Writer.Allocating = .init(a);
    const w = &out.writer;
    try w.print(intro, .{ s.patch, Date.fromMs(s.t0_ms).long() });
    var narrow: std.ArrayList([]const u8) = .empty;
    var narrow_pit: std.ArrayList(f64) = .empty;
    for (regions, 0..) |region, r| {
        if (!s.any(r)) continue;
        try w.print(
            \\
            \\### {s}
            \\
            \\| Number | In range 30d / patch / Meio | ± 30d / patch / Meio | Missed low / high per 100 |
            \\|---|---|---|---|
            \\
        , .{region.name});
        var scored = false;
        var covered = false;
        for (std.enums.values(Kind)) |k| {
            const c = s.all(r, k);
            if (c.scored[1].cells > 0) scored = true;
            if (c.shown.cells > 0) covered = true;
            if (c.ranges[2].cells == 0) continue;
            try w.print("| {s} | ", .{truth.label(k)});
            for (c.ranges, 0..) |m, i| {
                if (i > 0) try w.writeAll(" / ");
                try pct(w, pitOf(m));
            }
            const prec: usize = if (k == .gold14) 0 else if (truth.isShare(k)) 2 else 1;
            if (halves(s, r, k, c)) |x| {
                try w.print(" | ±{d:.[3]} / ±{d:.[3]} / ±{d:.[3]} |", .{ x[0], x[1], x[2], prec });
            } else try w.writeAll(" | |");
            const p = c.scored[1];
            if (p.cells > 0) {
                try w.print(" {d:.0} / {d:.0} |\n", .{ 100 * p.miss[1][0] / p.cells, 100 * p.miss[1][1] / p.cells });
            } else try w.writeAll(" - |\n");
            if (r == 0) if (pitOf(c.ranges[2])) |v| if (v < honest[0]) {
                try narrow.append(a, truth.label(k));
                try narrow_pit.append(a, v);
            };
        }
        if (scored) {
            try w.writeAll(
                \\
                \\| Number | Interval score vs 30 days | vs patch | vs patch by games: under 20 / 20-199 / 200+ | Width / below / above |
                \\|---|---|---|---|---|
                \\
            );
            for (std.enums.values(Kind)) |k| {
                const c = s.all(r, k);
                if (c.scored[0].cells == 0 and c.scored[1].cells == 0) continue;
                try w.print("| {s} |", .{truth.label(k)});
                for (c.scored) |x| try scoredCell(w, x);
                try sizesCell(w, c.scored[1]);
                try partsCell(w, k, c.scored[1]);
                try w.writeByte('\n');
            }
        }
        try w.writeAll(
            \\
            \\| Number | Log loss vs 30 days | vs patch | New | Every day |
            \\|---|---|---|---|---|
            \\
        );
        for (std.enums.values(Kind)) |k| {
            const c = s.all(r, k);
            if (c.vs[0].cells == 0 and c.vs[1].cells == 0) continue;
            try w.print("| {s} |", .{truth.label(k)});
            for (c.vs) |v| try vsCell(w, k, v);
            try gateCell(w, s, r, k);
            try w.writeByte('\n');
        }
        if (covered) {
            comptime std.debug.assert(truth.weight_bands.len == 4);
            try w.writeAll("\n| Number | Meio in range, weight");
            for (truth.weight_bands) |b| try w.print(" {s} |", .{b});
            try w.writeAll(" Shown first |\n|---|---|---|---|---|---|\n");
            for (std.enums.values(Kind)) |k| {
                const c = s.all(r, k);
                if (c.ranges[2].cells == 0) continue;
                try w.print("| {s} |", .{truth.label(k)});
                for (c.weight ++ [1]Cover{c.shown}) |x| {
                    try w.writeByte(' ');
                    try pct(w, coverOf(x));
                    try w.writeAll(" |");
                }
                try w.writeByte('\n');
            }
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
    try w.writeAll(changelog ++ how ++ leaves_out);
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
        .lead = "How well each mode predicts the next week's games on the newest patch, scored daily.",
        .body = try ui.prose.parse(a, body),
        .wide = true,
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
    // Interval scores against patch: Meio's sum 0.034 against 0.04 (+15%), one day ahead
    // (too few days for the sign test); misses 1 low, 2 high of 10
    champ[0][0].wis[1][2] = .{
        .cells = 10,
        .parts = .{ .{ 0.01, 0.02, 0.01 }, .{ 0.004, 0.02, 0.01 } },
        .miss = .{ .{ 1, 1 }, .{ 1, 2 } },
    };
    champ[0][0].blocks[1] = .{ .n = 1, .ahead = 1 };
    champ[0][0].by_weight[0] = .{ .cells = 400, .pit = 200 };
    // Too few cells to read: "-"
    champ[0][0].by_weight[1] = .{ .cells = 99, .pit = 99 };
    champ[0][0].shown = .{ .cells = 200, .pit = 200 };
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
        // No medians (empty histograms): means over the paired cells
        "| champion-role | 80% / 80% / 70% | ±6.0 / ±5.0 / ±2.0 | 10 / 20 |",
        "| champion-role | - | level +15%, 1/1 days | - / - / +15% | patch 0.10 / 0.20 / 0.10, Meio 0.04 / 0.20 / 0.10 |",
        "| champion-role | 50% | - | - | - | 100% |",
        "| Number | Meio in range, weight under 0.25 | 0.25-0.5 | 0.5-0.75 | 0.75+ | Shown first |",
        "| gold at 14 (matchup) | ahead 10 ±0 | | | every day |",
        "Meio's ranges for champion-role (70%) hold fewer than 8 in 10",
        "### EUW\n",
        "## Track record\n",
        "\n## Changelog\n",
        "\n## What it leaves out\n",
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
