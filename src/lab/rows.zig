//! Loading lab rows: SNAP/pack/ when it matches, else SQLite, plus hooks (plant:). The
//! rows themselves (layout and production from SQLite) are rowsql.zig's, re-exported
//! here; edits to this file don't make packs stale

const std = @import("std");
const stats = @import("../stats.zig");
const rowsql = @import("rowsql.zig");
const pack = @import("pack.zig");
const synth = @import("synth.zig");

pub const Outcome = rowsql.Outcome;
pub const outcome_count = rowsql.outcome_count;
pub const Game = rowsql.Game;
pub const Row = rowsql.Row;
pub const Data = rowsql.Data;
pub const loadSql = rowsql.loadSql;
pub const no_player = rowsql.no_player;
pub const fillExperience = rowsql.fillExperience;
pub const Extra = rowsql.Extra;
pub const legendaryKey = rowsql.legendaryKey;

/// From SNAP/pack/ when it matches the snapshot (lab/pack.zig), else from SQLite.
/// legendaries: (patch key, item id) of completed items, for first_item; may be empty.
/// SNAP `plant:SPEC:PATH` loads PATH with winners re-drawn from planted effects
/// (lab/synth.zig)
pub fn load(
    gpa: std.mem.Allocator,
    snap: []const u8,
    legendaries: *const std.AutoHashMapUnmanaged(u64, void),
) !Data {
    // Plain blocking reads, on the global Io so every caller gets the pack unchanged
    const io = std.Io.Threaded.global_single_threaded.io();
    if (try synth.parseArg(snap)) |arg| {
        // The caller looked for legendaries.tsv under "plant:..."; the pack's manifest wants PATH's
        var own = try loadLegendaries(gpa, io, arg.path);
        defer own.deinit(gpa);
        var d = try loadPlain(gpa, io, arg.path, &own);
        errdefer d.deinit();
        try synth.plant(gpa, &d, arg.spec);
        return d;
    }
    return loadPlain(gpa, io, snap, legendaries);
}

fn loadPlain(
    gpa: std.mem.Allocator,
    io: std.Io,
    snap: []const u8,
    legendaries: *const std.AutoHashMapUnmanaged(u64, void),
) !Data {
    if (try pack.read(gpa, io, snap, legendaries)) |d| return d;
    return loadSql(gpa, snap, legendaries);
}

/// SNAP/legendaries.tsv (patch, item id; meiolol-3c writes it), empty when missing
pub fn loadLegendaries(gpa: std.mem.Allocator, io: std.Io, snap: []const u8) !std.AutoHashMapUnmanaged(u64, void) {
    var set: std.AutoHashMapUnmanaged(u64, void) = .empty;
    errdefer set.deinit(gpa);
    const path = try std.fs.path.join(gpa, &.{ snap, "legendaries.tsv" });
    defer gpa.free(path);
    const text = std.Io.Dir.cwd().readFileAlloc(io, path, gpa, .limited(16 << 20)) catch |err| switch (err) {
        error.FileNotFound => return set,
        else => return err,
    };
    defer gpa.free(text);
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    while (lines.next()) |line| {
        var cols = std.mem.tokenizeScalar(u8, line, '\t');
        const patch = cols.next() orelse continue;
        const item = std.fmt.parseInt(u32, cols.next() orelse continue, 10) catch continue;
        try set.put(gpa, legendaryKey(stats.patchKey(patch), item), {});
    }
    return set;
}

/// Counts and means per outcome, train and test, as a check on a snapshot
pub fn summary(d: *const Data, w: *std.Io.Writer) !void {
    var tests: usize = 0;
    var tl: usize = 0;
    for (d.games) |g| {
        tests += @intFromBool(g.is_test);
        tl += @intFromBool(g.timeline15);
    }
    try w.print("{d} games ({d} test), {d} with a timeline reaching 15:00; {d} rows\n", .{
        d.games.len, tests, tl, d.rows.len,
    });
    try w.print("{s: <12} {s: >9} {s: >10} {s: >9} {s: >10}\n", .{ "outcome", "train n", "mean", "test n", "mean" });
    for (0..outcome_count) |k| {
        var n: [2]usize = @splat(0);
        var sum: [2]f64 = @splat(0);
        for (d.rows) |r| {
            const v = r.y[k];
            if (std.math.isNan(v)) continue;
            const t = @intFromBool(d.games[r.game].is_test);
            n[t] += 1;
            sum[t] += v;
        }
        try w.print("{s: <12} {d: >9} {d: >10.3} {d: >9} {d: >10.3}\n", .{
            @tagName(@as(Outcome, @fromBackingInt(@intCast(k)))),
            n[0],
            sum[0] / @as(f64, @floatFromInt(@max(n[0], 1))),
            n[1],
            sum[1] / @as(f64, @floatFromInt(@max(n[1], 1))),
        });
    }
}

test {
    _ = rowsql;
    _ = synth;
}
