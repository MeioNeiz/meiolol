//! `meiolol-lab gains UNITS A B`: where model A's win gain over model B sits, by draft
//! type (NN verification, docs/model.md "Neural draft models"). UNITS is a compcheck.tsv
//! (compcheck's team units: the games, blue's result and each team's profile features,
//! built from games older than the scored ones); A and B are prediction files of the
//! exp dev.tsv shape (match_id, slot, outcome, y, pred) on those games. Per game, each
//! model's blue chance is the mean over its rows (a red row's pred flipped); the paired
//! log loss difference A - B is split by group, one value per game (games are
//! independent), 95% intervals. Games missing from A or B are left out and counted

const std = @import("std");
const Io = std.Io;

pub const usage =
    \\  gains UNITS A B                 model A's log loss minus B's per game, by draft type
    \\                                  (UNITS: a compcheck.tsv; A, B: dev.tsv-shaped
    \\                                  predictions on its games; lab/gains.zig)
    \\
;

const Team = struct { y: f64, magic: f64, lift_diff: f64, best_mitigated: f64, frontline: f64 };

const Game = struct {
    platform: []const u8,
    team: [2]Team,
    /// Per model: blue's summed chance and rows
    sum: [2]f64 = .{ 0, 0 },
    n: [2]f64 = .{ 0, 0 },
};

pub fn main(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: Io, argv: []const []const u8) !u8 {
    if (argv.len != 3) {
        std.debug.print("usage:\n{s}", .{usage});
        return 2;
    }
    var games: std.StringHashMapUnmanaged(Game) = .empty;
    defer games.deinit(gpa);
    try readUnits(gpa, arena, io, argv[0], &games);
    for (argv[1..3], 0..) |path, m| try readPreds(gpa, io, path, m, &games);

    var buf: [4096]u8 = undefined;
    var stdout = Io.File.stdout().writer(io, &buf);
    const w = &stdout.interface;
    try report(gpa, &games, argv[1], argv[2], w);
    try w.flush();
    return 0;
}

fn column(header: []const u8, name: []const u8) !usize {
    var it = std.mem.splitScalar(u8, header, '\t');
    var i: usize = 0;
    while (it.next()) |h| : (i += 1) if (std.mem.eql(u8, h, name)) return i;
    return error.MissingColumn;
}

fn readUnits(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: Io, path: []const u8, games: *std.StringHashMapUnmanaged(Game)) !void {
    const text = try Io.Dir.cwd().readFileAlloc(io, path, arena, .unlimited);
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    const header = lines.next() orelse return error.Empty;
    const names = [_][]const u8{ "match_id", "platform", "side", "y", "magic_share", "lift_diff", "best_mitigated", "frontline" };
    var at: [names.len]usize = undefined;
    for (&at, names) |*a, n| a.* = try column(header, n);
    var cols: [32][]const u8 = undefined;
    while (lines.next()) |line| {
        var it = std.mem.splitScalar(u8, line, '\t');
        var n: usize = 0;
        while (it.next()) |c| : (n += 1) if (n < cols.len) {
            cols[n] = c;
        };
        const side = try std.fmt.parseInt(u1, cols[at[2]], 10);
        const e = try games.getOrPut(gpa, cols[at[0]]);
        if (!e.found_existing) e.value_ptr.* = .{ .platform = cols[at[1]], .team = undefined };
        e.value_ptr.team[side] = .{
            .y = try std.fmt.parseFloat(f64, cols[at[3]]),
            .magic = try std.fmt.parseFloat(f64, cols[at[4]]),
            .lift_diff = try std.fmt.parseFloat(f64, cols[at[5]]),
            .best_mitigated = try std.fmt.parseFloat(f64, cols[at[6]]),
            .frontline = try std.fmt.parseFloat(f64, cols[at[7]]),
        };
    }
}

/// A row is on blue's side when its y is blue's result (rows of a team share y)
fn readPreds(gpa: std.mem.Allocator, io: Io, path: []const u8, m: usize, games: *std.StringHashMapUnmanaged(Game)) !void {
    const text = try Io.Dir.cwd().readFileAlloc(io, path, gpa, .unlimited);
    defer gpa.free(text);
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    _ = lines.next();
    while (lines.next()) |line| {
        var it = std.mem.splitScalar(u8, line, '\t');
        const match = it.next() orelse continue;
        _ = it.next();
        if (!std.mem.eql(u8, it.next() orelse continue, "win")) continue;
        const y = try std.fmt.parseFloat(f64, it.next() orelse continue);
        const p = try std.fmt.parseFloat(f64, it.next() orelse continue);
        const g = games.getPtr(match) orelse continue;
        g.sum[m] += if (y == g.team[0].y) p else 1 - p;
        g.n[m] += 1;
    }
}

const Group = struct {
    label: []const u8,
    n: f64 = 0,
    s: f64 = 0,
    ss: f64 = 0,
    la: f64 = 0,
    lb: f64 = 0,
};

fn lopsided(magic: f64) bool {
    return magic < 0.2 or magic >= 0.6;
}

fn report(gpa: std.mem.Allocator, games: *const std.StringHashMapUnmanaged(Game), a: []const u8, b: []const u8, w: *Io.Writer) !void {
    // Strength mismatch quartiles from the games themselves (a draft feature)
    var mism: std.ArrayList(f64) = .empty;
    defer mism.deinit(gpa);
    var it = games.valueIterator();
    while (it.next()) |g| if (g.n[0] > 0 and g.n[1] > 0) try mism.append(gpa, @abs(g.team[0].lift_diff));
    if (mism.items.len < 2) return error.NoSharedGames;
    std.mem.sort(f64, mism.items, {}, std.sort.asc(f64));
    const q = [3]f64{ mism.items[mism.items.len / 4], mism.items[mism.items.len / 2], mism.items[mism.items.len * 3 / 4] };

    var groups = [_]Group{
        .{ .label = "all" },
        .{ .label = "a lopsided team (magic <20% or 60%+)" },
        .{ .label = "both balanced" },
        .{ .label = "strength mismatch Q1 (closest)" },
        .{ .label = "strength mismatch Q2" },
        .{ .label = "strength mismatch Q3" },
        .{ .label = "strength mismatch Q4 (widest)" },
        .{ .label = "a team with no frontline-ish pick (best mitigated < 0.51)" },
        .{ .label = "EUW1" },
        .{ .label = "other platforms" },
    };
    var missing: usize = 0;
    it = games.valueIterator();
    while (it.next()) |g| {
        if (g.n[0] == 0 or g.n[1] == 0) {
            missing += 1;
            continue;
        }
        const y = g.team[0].y;
        var l: [2]f64 = undefined;
        for (&l, g.sum, g.n) |*x, s, n| {
            const p = std.math.clamp(s / n, 1e-6, 1 - 1e-6);
            x.* = -(y * @log(p) + (1 - y) * @log(1 - p));
        }
        const lop = lopsided(g.team[0].magic) or lopsided(g.team[1].magic);
        const mm = @abs(g.team[0].lift_diff);
        const sq: usize = if (mm <= q[0]) 3 else if (mm <= q[1]) 4 else if (mm <= q[2]) 5 else 6;
        const in = [_]bool{
            true,                                 lop,                                                             !lop,
            sq == 3,                              sq == 4,                                                         sq == 5,
            sq == 6,                              @min(g.team[0].best_mitigated, g.team[1].best_mitigated) < 0.51, std.mem.eql(u8, g.platform, "EUW1"),
            !std.mem.eql(u8, g.platform, "EUW1"),
        };
        for (&groups, in) |*gr, yes| if (yes) {
            const dlt = l[0] - l[1];
            gr.n += 1;
            gr.s += dlt;
            gr.ss += dlt * dlt;
            gr.la += l[0];
            gr.lb += l[1];
        };
    }
    try w.print("A = {s}\nB = {s}\ngames in UNITS without both models' predictions: {d}\n\n", .{ a, b, missing });
    try w.writeAll("| group | games | A log loss | B log loss | A - B, milli-nats/game |\n| --- | --- | --- | --- | --- |\n");
    for (groups) |gr| {
        if (gr.n < 2) continue;
        const mean = gr.s / gr.n;
        const half = 1.96 * @sqrt((gr.ss / gr.n - mean * mean) / (gr.n - 1));
        try w.print("| {s} | {d:.0} | {d:.5} | {d:.5} | {d:.2} ± {d:.2} |\n", .{ gr.label, gr.n, gr.la / gr.n, gr.lb / gr.n, mean * 1000, half * 1000 });
    }
}
