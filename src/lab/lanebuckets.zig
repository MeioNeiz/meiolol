//! Where does a lane model's gain come from? Paired gain of one prediction file over
//! another on the test rows, bucketed by how many train games the row's lane pair has
//! (my champion and role against the enemy champion in my role). Decides whether thin
//! matchups on the site should use a model that borrows across champions

const std = @import("std");
const rows = @import("rows.zig");

const edges = [_]u32{ 25, 100, 400 };
const bucket_names = [_][]const u8{ "<25", "25-99", "100-399", "400+" };

const Key = struct { match: u64, slot: i8, outcome: u8 };
const Entry = struct { y: f32, pred: f32 };

fn load(gpa: std.mem.Allocator, io: std.Io, path: []const u8) !std.AutoHashMapUnmanaged(Key, Entry) {
    const text = try std.Io.Dir.cwd().readFileAlloc(io, path, gpa, .unlimited);
    defer gpa.free(text);
    var map: std.AutoHashMapUnmanaged(Key, Entry) = .empty;
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

fn pairKey(me: u32, role: u3, them: u32) u64 {
    return (@as(u64, me) << 24) | (@as(u64, role) << 21) | them;
}

/// base, a, b: prediction files; reports a's gain over b (b's error minus a's) as % of
/// base's MSE within each bucket
pub fn run(gpa: std.mem.Allocator, io: std.Io, d: *const rows.Data, base: []const u8, a: []const u8, b: []const u8, w: *std.Io.Writer) !void {
    // Lane opponent of each row, and train counts per pair (rows of train games)
    const opponent = try gpa.alloc(u32, d.rows.len);
    defer gpa.free(opponent);
    {
        var by_game: std.AutoHashMapUnmanaged(u64, u32) = .empty;
        defer by_game.deinit(gpa);
        for (d.rows, 0..) |r, i| try by_game.put(gpa, (@as(u64, r.game) << 4) | (@as(u64, r.side) << 3) | @backingInt(r.role), @intCast(i));
        for (d.rows, opponent) |r, *o| {
            const k = (@as(u64, r.game) << 4) | (@as(u64, 1 - r.side) << 3) | @backingInt(r.role);
            o.* = if (by_game.get(k)) |oi| d.rows[oi].champion else 0;
        }
    }
    var counts: std.AutoHashMapUnmanaged(u64, u32) = .empty;
    defer counts.deinit(gpa);
    for (d.rows, opponent) |r, o| {
        if (d.games[r.game].is_test or !d.games[r.game].timeline15) continue;
        const e = try counts.getOrPutValue(gpa, pairKey(r.champion, @backingInt(r.role), o), 0);
        e.value_ptr.* += 1;
    }

    var fb = try load(gpa, io, base);
    defer fb.deinit(gpa);
    var fa = try load(gpa, io, a);
    defer fa.deinit(gpa);
    var fbb = try load(gpa, io, b);
    defer fbb.deinit(gpa);

    try w.print("{s} over {s}, % of {s} MSE, by lane pair train games\n\n", .{
        std.fs.path.basename(a), std.fs.path.basename(b), std.fs.path.basename(base),
    });
    try w.writeAll("| outcome | pair train games | rows | gain, % |\n| --- | --- | --- | --- |\n");
    for ([_]rows.Outcome{ .gold14, .lanediff14, .cs10, .deaths15, .first_item }) |k| {
        // Per bucket and game: summed paired difference, row count, base squared error
        var sum: [4]f64 = @splat(0);
        var base_se: [4]f64 = @splat(0);
        var n: [4]f64 = @splat(0);
        var games: [4]std.AutoHashMapUnmanaged(u32, [2]f64) = @splat(.empty);
        defer for (&games) |*g| g.deinit(gpa);
        for (d.rows, opponent) |r, o| {
            const g = d.games[r.game];
            if (!g.is_test) continue;
            const key: Key = .{ .match = std.hash.Wyhash.hash(0, g.match_id), .slot = @intCast(r.slot), .outcome = @backingInt(k) };
            const eb = fb.get(key) orelse continue;
            const ea = fa.get(key) orelse continue;
            const ec = fbb.get(key) orelse continue;
            const c = counts.get(pairKey(r.champion, @backingInt(r.role), o)) orelse 0;
            var bi: usize = 0;
            while (bi < edges.len and c >= edges[bi]) bi += 1;
            const diff = (ec.pred - ec.y) * (ec.pred - ec.y) - (ea.pred - ea.y) * (ea.pred - ea.y);
            sum[bi] += diff;
            base_se[bi] += (eb.pred - eb.y) * (eb.pred - eb.y);
            n[bi] += 1;
            const e = try games[bi].getOrPutValue(gpa, r.game, .{ 0, 0 });
            e.value_ptr[0] += diff;
            e.value_ptr[1] += 1;
        }
        for (0..4) |bi| {
            if (n[bi] < 2) continue;
            const mean_row = sum[bi] / n[bi];
            var ss: f64 = 0;
            var it = games[bi].valueIterator();
            while (it.next()) |v| ss += (v[0] - mean_row * v[1]) * (v[0] - mean_row * v[1]);
            const g: f64 = @floatFromInt(games[bi].count());
            const half = 1.96 * @sqrt(g / (g - 1) * ss) / base_se[bi];
            try w.print("| {s} | {s} | {d} | {d:.2} ± {d:.2} |\n", .{
                @tagName(k), bucket_names[bi], @as(u64, @intFromFloat(n[bi])), sum[bi] / base_se[bi] * 100, half * 100,
            });
        }
    }
}
