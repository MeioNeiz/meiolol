//! `meiolol-lab coverage SNAP`: docs/plan/lab-frontier.md P1, a pin's inputs per protocol
//! window (harness.Cuts: old below fold 1, folds 1-5, dev-val, test) and platform. Counts
//! only, no outcomes, so the test window may be counted: games, played, played games by
//! patch, and shares of played seats and of played games (all ten seats) with seat stats
//! (SNAP/seat_stats.tsv through rows), a pre-game mastery fetch (SNAP/mastery_pre.tsv)
//! and rank_start. Then each dev block's fit games. TSV on stdout

const std = @import("std");
const rows = @import("rows.zig");
const harness = @import("harness.zig");
const protocol = @import("protocol.zig");
const seatstats = @import("seatstats.zig");
const mastery_pre = @import("mastery_pre.zig");

const Io = std.Io;

pub const usage =
    \\  coverage SNAP                   a pin's inputs per protocol window and platform:
    \\                                  games, played, patches, seat stats, mastery_pre
    \\                                  and rank_start, per seat and for all ten
    \\                                  (lab/coverage.zig; counts only, no outcomes)
    \\
;

pub const Window = enum { old, f1, f2, f3, f4, f5, dev_val, test_ };
const n_windows = std.enums.values(Window).len;
const n_platforms = protocol.platformIds().len;
/// Played games' patch columns, then any other
const patches = [_]u32{ 16019, 16020, 16021 };
pub const Input = enum { stats, mastery, rank };
const n_inputs = std.enums.values(Input).len;
const all_ten: u16 = (1 << 10) - 1;

pub const Counts = struct {
    games: u32 = 0,
    played: u32 = 0,
    patch: [patches.len + 1]u32 = @splat(0),
    /// Played games' seats with the input, and played games with it for all ten
    seats: [n_inputs]u32 = @splat(0),
    full: [n_inputs]u32 = @splat(0),
};

/// [window][0 every platform, 1 + platform index]
pub const Table = [n_windows][n_platforms + 1]Counts;

pub fn windowOf(c: harness.Cuts, start: i64) Window {
    if (start >= c.test_) return .test_;
    if (start >= c.dev) return .dev_val;
    if (start < c.bounds[0]) return .old;
    for (1..harness.folds + 1) |k| if (start < c.bounds[k]) return @fromBackingInt(@as(u3, @intCast(k)));
    unreachable;
}

/// masks[input][game]: bit `slot` set when that seat has the input
pub fn count(d: *const rows.Data, c: harness.Cuts, masks: *const [n_inputs][]const u16) Table {
    var t: Table = @splat(@splat(.{}));
    for (d.games, 0..) |g, gi| {
        const w = @backingInt(windowOf(c, g.start));
        for ([_]usize{ 0, 1 + @as(usize, g.platform) }) |p| {
            const x = &t[w][p];
            x.games += 1;
            if (!harness.played(g)) continue;
            x.played += 1;
            x.patch[std.mem.findScalar(u32, &patches, g.patch) orelse patches.len] += 1;
            for (masks, &x.seats, &x.full) |m, *s, *f| {
                s.* += @popCount(m[gi]);
                if (m[gi] == all_ten) f.* += 1;
            }
        }
    }
    return t;
}

pub fn main(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: Io, argv: []const []const u8) !u8 {
    if (argv.len != 1) {
        std.debug.print("usage:\n{s}", .{usage});
        return 2;
    }
    const snap = argv[0];
    var data = try rows.loadSnap(gpa, io, snap);
    defer data.deinit();
    const c = try harness.cuts(gpa, &data);

    var masks: [n_inputs][]u16 = undefined;
    for (&masks) |*m| m.* = try arena.alloc(u16, data.games.len);
    for (&masks) |m| @memset(m, 0);
    for (data.rows) |r| {
        const bit = @as(u16, 1) << @intCast(r.slot);
        if (!std.math.isNan(r.stats[@backingInt(seatstats.SeatStat.minutes)])) masks[@backingInt(Input.stats)][r.game] |= bit;
        if (r.rank_start != null) masks[@backingInt(Input.rank)][r.game] |= bit;
    }
    try markMastery(gpa, io, snap, &data, masks[@backingInt(Input.mastery)]);

    const t = count(&data, c, &masks);
    var out_buf: [4096]u8 = undefined;
    var stdout = Io.File.stdout().writer(io, &out_buf);
    try write(&stdout.interface, &data, c, &t);
    try stdout.interface.flush();
    return 0;
}

/// Sets each mastery_pre.tsv seat's bit; a match not in the rows is skipped
fn markMastery(gpa: std.mem.Allocator, io: Io, snap: []const u8, d: *const rows.Data, mask: []u16) !void {
    var index: std.StringHashMapUnmanaged(u32) = .empty;
    defer index.deinit(gpa);
    try index.ensureTotalCapacity(gpa, @intCast(d.games.len));
    for (d.games, 0..) |g, gi| index.putAssumeCapacity(g.match_id, @intCast(gi));
    const path = try std.fs.path.join(gpa, &.{ snap, mastery_pre.file_name });
    defer gpa.free(path);
    const text = try Io.Dir.cwd().readFileAlloc(io, path, gpa, .limited(4 << 30));
    defer gpa.free(text);
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    _ = lines.next();
    while (lines.next()) |line| {
        var it = std.mem.splitScalar(u8, line, '\t');
        const gi = index.get(it.next() orelse return error.MasteryFormat) orelse continue;
        const slot = try std.fmt.parseInt(u4, it.next() orelse return error.MasteryFormat, 10);
        mask[gi] |= @as(u16, 1) << slot;
    }
}

fn write(w: *Io.Writer, d: *const rows.Data, c: harness.Cuts, t: *const Table) !void {
    const ids = protocol.platformIds();
    try w.print("# test_cut_ms {d} dev_cut_ms {d} fold_starts_ms", .{ c.test_, c.dev });
    for (c.bounds[0..harness.folds]) |b| try w.print(" {d}", .{b});
    var first: i64 = std.math.maxInt(i64);
    for (d.games) |g| first = @min(first, g.start);
    try w.print(" first_ms {d}\n", .{first});
    try w.writeAll("window\tplatform\tgames\tplayed\tp16.19\tp16.20\tp16.21\tp_other");
    for (std.enums.values(Input)) |in| try w.print("\t{t}_seats\t{t}_all10", .{ in, in });
    try w.writeAll("\n");
    for (t, 0..) |per, wi| for (per, 0..) |x, p| {
        if (x.games == 0) continue;
        const name = if (p == 0) "all" else ids[p - 1];
        try w.print("{t}\t{s}\t{d}\t{d}", .{ @as(Window, @fromBackingInt(@as(u3, @intCast(wi)))), name, x.games, x.played });
        for (x.patch) |n| try w.print("\t{d}", .{n});
        const played: f64 = @floatFromInt(@max(x.played, 1));
        for (x.seats, x.full) |s, f| try w.print("\t{d:.4}\t{d:.4}", .{ @as(f64, @floatFromInt(s)) / (10 * played), @as(f64, @floatFromInt(f)) / played });
        try w.writeAll("\n");
    };
    // What each dev block fits on (netcheck's Spec.before): played games before it
    try w.writeAll("\nblock\tfit_games\tscored_games\n");
    const before = [_]i64{ c.dev, c.bounds[0], c.bounds[1], c.bounds[2], c.bounds[3], c.bounds[4] };
    for (before, 0..) |cut, b| {
        var fit: u32 = 0;
        var scored: u32 = 0;
        const hi = if (b == 0) c.test_ else c.fold(b).hi;
        for (d.games) |g| if (harness.played(g)) {
            if (g.start < cut) fit += 1 else if (g.start < hi) scored += 1;
        };
        try w.print("{s}\t{d}\t{d}\n", .{ if (b == 0) "dev" else &.{'0' + @as(u8, @intCast(b))}, fit, scored });
    }
}

test "coverage: windows by start, inputs per seat and for all ten, played only" {
    const testing = std.testing;
    const c: harness.Cuts = .{ .test_ = 100, .dev = 90, .bounds = .{ 10, 20, 30, 40, 50, std.math.maxInt(i64) } };
    try testing.expectEqual(Window.old, windowOf(c, 9));
    try testing.expectEqual(Window.f1, windowOf(c, 10));
    try testing.expectEqual(Window.f5, windowOf(c, 89));
    try testing.expectEqual(Window.dev_val, windowOf(c, 90));
    try testing.expectEqual(Window.test_, windowOf(c, 100));

    const game: rows.Game = .{ .match_id = "", .start = 15, .patch = 16021, .platform = 2, .is_test = false, .teams = @splat(@splat(0)), .winner = 0, .duration_s = harness.min_duration_s };
    var games = [_]rows.Game{ game, game, game };
    games[1].patch = 16018;
    games[2].duration_s = 60;
    const d: rows.Data = .{ .arena = .init(testing.allocator), .games = &games, .rows = &.{} };
    const stats_m = [_]u16{ all_ten, 0b11, all_ten };
    const none = [_]u16{ 0, 0, 0 };
    const t = count(&d, c, &.{ &stats_m, &none, &none });
    for ([_]usize{ 0, 3 }) |p| {
        const x = t[@backingInt(Window.f1)][p];
        try testing.expectEqual(3, x.games);
        try testing.expectEqual(2, x.played);
        try testing.expectEqualSlices(u32, &.{ 0, 0, 1, 1 }, &x.patch);
        try testing.expectEqual(12, x.seats[0]);
        try testing.expectEqual(1, x.full[0]);
    }
    try testing.expectEqual(0, t[@backingInt(Window.f1)][1].games);
}
