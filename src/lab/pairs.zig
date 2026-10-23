//! Paired comparison of prediction files (docs/model.md "Shared protocol"): TSVs of
//! match_id, slot, outcome, y, pred, from any session. Per outcome, on the rows every
//! file has: each file's MSE, and its gain over the reference as a share of the base
//! file's MSE, 95% interval clustered by game (meiolol-3c computes the same)

const std = @import("std");
const rows = @import("rows.zig");

const Key = struct { match: u64, slot: i8, outcome: u8 };

const Entry = struct { y: f32, pred: f32 };
const File = std.AutoHashMapUnmanaged(Key, Entry);

fn load(gpa: std.mem.Allocator, io: std.Io, path: []const u8) !File {
    const text = try std.Io.Dir.cwd().readFileAlloc(io, path, gpa, .unlimited);
    defer gpa.free(text);
    var map: File = .empty;
    errdefer map.deinit(gpa);
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    _ = lines.next();
    while (lines.next()) |line| {
        var cols = std.mem.tokenizeScalar(u8, line, '\t');
        const match = cols.next() orelse continue;
        const slot = std.fmt.parseInt(i8, cols.next() orelse continue, 10) catch continue;
        const outcome = std.meta.stringToEnum(rows.Outcome, cols.next() orelse continue) orelse continue;
        const y = std.fmt.parseFloat(f32, cols.next() orelse continue) catch continue;
        const pred = std.fmt.parseFloat(f32, cols.next() orelse continue) catch continue;
        try map.put(gpa, .{ .match = std.hash.Wyhash.hash(0, match), .slot = slot, .outcome = @backingInt(outcome) }, .{ .y = y, .pred = pred });
    }
    return map;
}

/// files[0] is the base (shares are of its MSE), files[1] the reference for intervals
pub fn run(gpa: std.mem.Allocator, io: std.Io, paths: []const []const u8, w: *std.Io.Writer) !void {
    if (paths.len < 2) return error.NeedTwoFiles;
    const files = try gpa.alloc(File, paths.len);
    defer gpa.free(files);
    @memset(files, .empty);
    defer for (files) |*f| f.deinit(gpa);
    for (files, paths) |*f, p| f.* = try load(gpa, io, p);

    try w.print("base {s}, reference {s}\n\n", .{ std.fs.path.basename(paths[0]), std.fs.path.basename(paths[1]) });
    try w.writeAll("| outcome | file | rows | MSE | gain vs base, % | vs reference, % |\n| --- | --- | --- | --- | --- | --- |\n");
    for (std.enums.values(rows.Outcome)) |o| {
        const oi = @backingInt(o);
        // Rows every file has, grouped by game
        var keys: std.ArrayList(Key) = .empty;
        defer keys.deinit(gpa);
        var it = files[0].keyIterator();
        while (it.next()) |k| {
            if (k.outcome != oi) continue;
            const all = for (files[1..]) |f| {
                if (!f.contains(k.*)) break false;
            } else true;
            if (all) try keys.append(gpa, k.*);
        }
        if (keys.items.len == 0) continue;
        std.mem.sort(Key, keys.items, {}, struct {
            fn lt(_: void, a: Key, b: Key) bool {
                return a.match < b.match or (a.match == b.match and a.slot < b.slot);
            }
        }.lt);
        const n: f64 = @floatFromInt(keys.items.len);
        var base_se: f64 = 0;
        for (keys.items) |k| {
            const e = files[0].get(k).?;
            base_se += (e.pred - e.y) * (e.pred - e.y);
        }
        for (files, paths, 0..) |f, p, fi| {
            var se: f64 = 0;
            for (keys.items) |k| {
                const e = f.get(k).?;
                se += (e.pred - e.y) * (e.pred - e.y);
            }
            try w.print("| {s} | {s} | {d} | {d:.4} | {d:.2} |", .{
                @tagName(o), std.fs.path.basename(p), keys.items.len, se / n, (1 - se / base_se) * 100,
            });
            if (fi < 2) {
                try w.writeAll(" - |\n");
                continue;
            }
            const d = clustered(keys.items, f, files[1], base_se);
            try w.print(" {d:.2} ± {d:.2} |\n", .{ d.mean * 100, d.half * 100 });
        }
    }
}

/// Gain of a over b (b's squared error minus a's) as a share of base_se, clustered by game
fn clustered(keys: []const Key, a: File, b: File, base_se: f64) struct { mean: f64, half: f64 } {
    var total: f64 = 0;
    for (keys) |k| total += sqDiff(a.get(k).?, b.get(k).?);
    var ss: f64 = 0;
    var groups: f64 = 0;
    const n: f64 = @floatFromInt(keys.len);
    const mean_row = total / n;
    var i: usize = 0;
    while (i < keys.len) {
        const m = keys[i].match;
        var sum: f64 = 0;
        var cnt: f64 = 0;
        while (i < keys.len and keys[i].match == m) : (i += 1) {
            sum += sqDiff(a.get(keys[i]).?, b.get(keys[i]).?);
            cnt += 1;
        }
        ss += (sum - mean_row * cnt) * (sum - mean_row * cnt);
        groups += 1;
    }
    const se = @sqrt(groups / (groups - 1) * ss);
    return .{ .mean = total / base_se, .half = 1.96 * se / base_se };
}

fn sqDiff(a: Entry, b: Entry) f64 {
    const ea = a.pred - a.y;
    const eb = b.pred - b.y;
    return eb * eb - ea * ea;
}
