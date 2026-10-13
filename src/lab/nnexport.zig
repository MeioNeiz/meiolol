//! Tensors for the draft nets (`meiolol-lab nn-export SNAP`): rows.Data as SNAP/nn/, one
//! game per index, one little-endian file per column, so a GPU loader reads each with one
//! copy. Agreed with meiolol-f1 (docs/model.md "Neural draft models"):
//!   champ.u8 [n][10]   dense champion index (meta champions), slot = side * 5 + role
//!   platform.u8, patch.u8 (index into meta patches), start.i64 (unix ms),
//!   duration.u16 (s), blue_win.u8, split.u8 (Split), flags.u8 (bit0 played: 15:00+, the
//!   harness neither fits nor scores shorter games; bit1 timeline reaches 15:00)
//!   aux.f32 [n][10][k]  targets only, never inputs: the early outcomes, then
//!                      SeatStat (rows.Row.stats); NaN unknown, raw game values
//!   meta.json          counts, names, cut times, fold bounds, and per fit set and role
//!                      the aux mean, sd and count over its played games only
//! Written to nn.tmp, then renamed over nn/

const std = @import("std");
const rows = @import("rows.zig");
const harness = @import("harness.zig");
const protocol = @import("protocol.zig");
const seatstats = @import("seatstats.zig");
const Io = std.Io;
const Allocator = std.mem.Allocator;

pub const dir_name = "nn";

/// What a game is for. Fold f (1..5) fits on splits below f and scores split f; dev-val
/// fits on 0..5; selection on 0..7; final on 0..9
pub const Split = enum(u8) {
    /// Dev-visible, older than the folds' blocks: fit in every fold
    dev_old = 0,
    fold1 = 1,
    fold2 = 2,
    fold3 = 3,
    fold4 = 4,
    fold5 = 5,
    /// EUW1 between the dev and selection cuts: the harness's dev scored games
    dev_val = 6,
    /// Other platforms in dev-val's period: fit from selection on
    dev_val_other = 7,
    selection = 8,
    selection_other = 9,
    test_ = 10,
};
pub const folds = 5;

/// Fit sets for meta.json's norm: name, then the highest split fitted on
const fit_sets = [_]struct { []const u8, u8 }{
    .{ "fold1", 0 }, .{ "fold2", 1 },   .{ "fold3", 2 },     .{ "fold4", 3 },
    .{ "fold5", 4 }, .{ "dev_val", 5 }, .{ "selection", 7 }, .{ "final", 9 },
};

const early = [_]rows.Outcome{ .gold14, .lanediff14, .cs10, .deaths15, .first_item };
pub const k = early.len + seatstats.count;

pub const flag_played: u8 = 1;
pub const flag_timeline15: u8 = 2;

pub const Export = struct {
    arena: std.heap.ArenaAllocator,
    champ: [][10]u8,
    platform: []u8,
    patch: []u8,
    start: []i64,
    duration: []u16,
    blue_win: []u8,
    split: []u8,
    flags: []u8,
    /// [n][10][k]
    aux: []f32,
    /// Index -> champion id
    champions: []u32,
    /// Index -> stats.patchKey
    patches: []u32,
    cut_dev: i64 = 0,
    cut_select: i64 = 0,
    /// Fold f's block is [bounds[f - 1], bounds[f]); dev_old is below bounds[0]
    bounds: [folds + 1]i64 = @splat(0),

    pub fn deinit(e: *Export) void {
        e.arena.deinit();
    }

    pub fn len(e: *const Export) usize {
        return e.platform.len;
    }
};

/// win-comp's foldAblation blocks: the newest half of the dev-visible games in `folds`
/// blocks by start, s[floor(len * q)] at q = 0.5 + 0.5 * f / folds
pub fn foldBounds(gpa: Allocator, d: *const rows.Data, c: harness.Cuts) ![folds + 1]i64 {
    var starts: std.ArrayList(i64) = .empty;
    defer starts.deinit(gpa);
    for (d.games) |g| if (harness.visible(.dev, c, g)) try starts.append(gpa, g.start);
    std.mem.sort(i64, starts.items, {}, std.sort.asc(i64));
    if (starts.items.len == 0) return error.TooFewGames;
    var out: [folds + 1]i64 = undefined;
    for (&out, 0..) |*b, f| {
        const q = 0.5 + 0.5 * @as(f64, @floatFromInt(f)) / folds;
        b.* = if (q >= 1) std.math.maxInt(i64) else starts.items[@intFromFloat(@as(f64, @floatFromInt(starts.items.len)) * q)];
    }
    return out;
}

pub fn splitOf(g: rows.Game, c: harness.Cuts, bounds: [folds + 1]i64) Split {
    if (g.is_test) return .test_;
    const eu = g.platform == c.eu;
    if (g.start >= c.select) return if (eu) .selection else .selection_other;
    if (g.start >= c.dev) return if (eu) .dev_val else .dev_val_other;
    if (g.start < bounds[0]) return .dev_old;
    var f: u8 = 1;
    while (f < folds and g.start >= bounds[f]) f += 1;
    return @fromBackingInt(f);
}

pub fn build(gpa: Allocator, d: *const rows.Data, c: harness.Cuts) !Export {
    var e: Export = undefined;
    e.arena = .init(gpa);
    errdefer e.arena.deinit();
    const a = e.arena.allocator();
    const n = d.games.len;
    e.champ = try a.alloc([10]u8, n);
    e.platform = try a.alloc(u8, n);
    e.patch = try a.alloc(u8, n);
    e.start = try a.alloc(i64, n);
    e.duration = try a.alloc(u16, n);
    e.blue_win = try a.alloc(u8, n);
    e.split = try a.alloc(u8, n);
    e.flags = try a.alloc(u8, n);
    e.aux = try a.alloc(f32, n * 10 * k);
    @memset(e.aux, std.math.nan(f32));
    e.cut_dev = c.dev;
    e.cut_select = c.select;
    e.bounds = try foldBounds(gpa, d, c);

    var champs: std.AutoArrayHashMapUnmanaged(u32, void) = .empty;
    defer champs.deinit(gpa);
    var patches: std.AutoArrayHashMapUnmanaged(u32, void) = .empty;
    defer patches.deinit(gpa);
    for (d.games) |g| {
        for (g.teams) |t| for (t) |ch| try champs.put(gpa, ch, {});
        try patches.put(gpa, g.patch, {});
    }
    if (champs.count() > 256 or patches.count() > 256) return error.TooManyIds;
    const sortKeys = struct {
        fn of(arena: Allocator, m: *std.AutoArrayHashMapUnmanaged(u32, void)) ![]u32 {
            const ks = try arena.dupe(u32, m.keys());
            std.mem.sort(u32, ks, {}, std.sort.asc(u32));
            return ks;
        }
    }.of;
    e.champions = try sortKeys(a, &champs);
    e.patches = try sortKeys(a, &patches);

    for (d.games, 0..) |g, gi| {
        for (g.teams, 0..) |t, side| for (t, 0..) |ch, role| {
            e.champ[gi][side * 5 + role] = @intCast(indexOf(e.champions, ch));
        };
        e.platform[gi] = g.platform;
        e.patch[gi] = @intCast(indexOf(e.patches, g.patch));
        e.start[gi] = g.start;
        e.duration[gi] = std.math.cast(u16, g.duration_s) orelse std.math.maxInt(u16);
        e.blue_win[gi] = @intFromBool(g.winner == 0);
        e.split[gi] = @backingInt(splitOf(g, c, e.bounds));
        e.flags[gi] = (if (g.duration_s >= harness.min_duration_s) flag_played else 0) |
            (if (g.timeline15) flag_timeline15 else 0);
    }
    for (d.rows) |r| {
        const at = (@as(usize, r.game) * 10 + @as(usize, r.side) * 5 + @backingInt(r.role)) * k;
        const dst = e.aux[at..][0..k];
        for (early, dst[0..early.len]) |o, *x| x.* = r.y[@backingInt(o)];
        dst[early.len..].* = r.stats;
    }
    return e;
}

fn indexOf(sorted: []const u32, x: u32) usize {
    return std.sort.binarySearch(u32, sorted, x, struct {
        fn order(a: u32, b: u32) std.math.Order {
            return std.math.order(a, b);
        }
    }.order).?;
}

const files = .{
    .{ "champ", "champ.u8" },  .{ "platform", "platform.u8" },  .{ "patch", "patch.u8" },
    .{ "start", "start.i64" }, .{ "duration", "duration.u16" }, .{ "blue_win", "blue_win.u8" },
    .{ "split", "split.u8" },  .{ "flags", "flags.u8" },        .{ "aux", "aux.f32" },
};

fn bytesOf(slice: anytype) []const u8 {
    return std.mem.sliceAsBytes(slice);
}

pub fn write(gpa: Allocator, io: Io, snap: []const u8, e: *const Export) !void {
    comptime std.debug.assert(@import("builtin").cpu.arch.endian() == .little);
    const cwd = Io.Dir.cwd();
    const tmp_path = try std.fmt.allocPrint(gpa, "{s}/{s}.tmp", .{ snap, dir_name });
    defer gpa.free(tmp_path);
    cwd.deleteTree(io, tmp_path) catch {};
    try cwd.createDirPath(io, tmp_path);
    errdefer cwd.deleteTree(io, tmp_path) catch {};
    {
        var dir = try cwd.openDir(io, tmp_path, .{});
        defer dir.close(io);
        inline for (files) |f| try dir.writeFile(io, .{ .sub_path = f[1], .data = bytesOf(@field(e, f[0])) });
        var out: Io.Writer.Allocating = .init(gpa);
        defer out.deinit();
        try meta(gpa, e, &out.writer);
        try dir.writeFile(io, .{ .sub_path = "meta.json", .data = out.written() });
    }
    const path = try std.fs.path.join(gpa, &.{ snap, dir_name });
    defer gpa.free(path);
    cwd.deleteTree(io, path) catch {};
    try cwd.rename(tmp_path, cwd, path, io);
}

fn meta(gpa: Allocator, e: *const Export, w: *Io.Writer) !void {
    try w.print("{{\"format\":\"meiolol-nn\",\"version\":1,\"n\":{d},\"k\":{d},\n", .{ e.len(), k });
    try w.writeAll("\"columns\":{\"champ.u8\":[\"n\",10],\"platform.u8\":[\"n\"],\"patch.u8\":[\"n\"]," ++
        "\"start.i64\":[\"n\"],\"duration.u16\":[\"n\"],\"blue_win.u8\":[\"n\"],\"split.u8\":[\"n\"]," ++
        "\"flags.u8\":[\"n\"],\"aux.f32\":[\"n\",10,\"k\"]},\n");
    try w.writeAll("\"slots\":\"side * 5 + role; side 0 blue; roles top, jungle, middle, bottom, utility\",\n");
    try w.writeAll("\"flags\":{\"played\":1,\"timeline15\":2},\n\"splits\":[");
    inline for (@typeInfo(Split).@"enum".field_names, 0..) |name, i| {
        try w.print("{s}\"{s}\"", .{ if (i == 0) "" else ",", std.mem.trimEnd(u8, name, "_") });
    }
    try w.writeAll("],\n\"aux\":[");
    for (early, 0..) |o, i| try w.print("{s}\"{t}\"", .{ if (i == 0) "" else ",", o });
    inline for (@typeInfo(seatstats.SeatStat).@"enum".field_names) |name| try w.print(",\"{s}\"", .{name});
    try w.writeAll("],\n\"champions\":[");
    for (e.champions, 0..) |c, i| try w.print("{s}{d}", .{ if (i == 0) "" else ",", c });
    try w.writeAll("],\n\"patches\":[");
    for (e.patches, 0..) |p, i| try w.print("{s}\"{d}.{d}\"", .{ if (i == 0) "" else ",", p / 1000, p % 1000 });
    try w.writeAll("],\n\"platforms\":[");
    for (protocol.platformIds(), 0..) |p, i| try w.print("{s}\"{s}\"", .{ if (i == 0) "" else ",", p });
    try w.print("],\n\"cuts\":{{\"dev\":{d},\"select\":{d}}},\n\"fold_bounds\":[", .{ e.cut_dev, e.cut_select });
    for (e.bounds, 0..) |b, i| try w.print("{s}{d}", .{ if (i == 0) "" else ",", b });
    try w.writeAll("],\n\"norm\":{");
    const Acc = struct { n: [k]f64 = @splat(0), sum: [k]f64 = @splat(0), sumsq: [k]f64 = @splat(0) };
    const acc = try gpa.alloc([5]Acc, fit_sets.len);
    defer gpa.free(acc);
    @memset(acc, @splat(.{}));
    for (0..e.len()) |gi| {
        if (e.flags[gi] & flag_played == 0) continue;
        for (fit_sets, acc) |fs, *ac| {
            if (e.split[gi] > fs[1]) continue;
            for (0..10) |slot| {
                const r = &ac[slot % 5];
                for (e.aux[(gi * 10 + slot) * k ..][0..k], 0..) |x, j| if (!std.math.isNan(x)) {
                    r.n[j] += 1;
                    r.sum[j] += x;
                    r.sumsq[j] += @as(f64, x) * x;
                };
            }
        }
    }
    for (fit_sets, acc, 0..) |fs, ac, i| {
        try w.print("{s}\n\"{s}\":{{\"fit_splits_to\":{d},\"roles\":[", .{ if (i == 0) "" else ",", fs[0], fs[1] });
        for (ac, 0..) |r, role| {
            try w.writeAll(if (role == 0) "{" else ",{");
            inline for (.{ "mean", "sd", "n" }, 0..) |what, wi| {
                try w.print("{s}\"{s}\":[", .{ if (wi == 0) "" else ",", what });
                for (0..k) |j| {
                    const m = if (r.n[j] > 0) r.sum[j] / r.n[j] else std.math.nan(f64);
                    const v = if (r.n[j] > 1) (r.sumsq[j] - r.n[j] * m * m) / (r.n[j] - 1) else std.math.nan(f64);
                    const x = switch (wi) {
                        0 => m,
                        1 => if (v > 0) @sqrt(v) else v,
                        else => r.n[j],
                    };
                    try w.writeAll(if (j == 0) "" else ",");
                    if (std.math.isNan(x)) try w.writeAll("null") else try w.print("{d}", .{x});
                }
                try w.writeAll("]");
            }
            try w.writeAll("}");
        }
        try w.writeAll("]}");
    }
    try w.writeAll("\n}}\n");
}

/// SNAP/nn/ back as written
pub fn read(gpa: Allocator, io: Io, snap: []const u8) !Export {
    var e: Export = undefined;
    e.arena = .init(gpa);
    errdefer e.arena.deinit();
    const a = e.arena.allocator();
    const path = try std.fs.path.join(a, &.{ snap, dir_name });
    var dir = try Io.Dir.cwd().openDir(io, path, .{});
    defer dir.close(io);
    const text = try dir.readFileAlloc(io, "meta.json", a, .limited(64 << 20));
    const M = struct {
        format: []const u8,
        version: u32,
        n: usize,
        k: usize,
        champions: []u32,
        patches: [][]const u8,
        cuts: struct { dev: i64, select: i64 },
        fold_bounds: [folds + 1]i64,
    };
    const m = try std.json.parseFromSliceLeaky(M, a, text, .{ .ignore_unknown_fields = true });
    if (!std.mem.eql(u8, m.format, "meiolol-nn") or m.version != 1 or m.k != k) return error.NnExportFormat;
    e.champions = m.champions;
    e.patches = try a.alloc(u32, m.patches.len);
    for (e.patches, m.patches) |*p, s| p.* = @import("../stats.zig").patchKey(s);
    e.cut_dev = m.cuts.dev;
    e.cut_select = m.cuts.select;
    e.bounds = m.fold_bounds;
    inline for (files) |f| {
        const T = @typeInfo(@TypeOf(@field(e, f[0]))).pointer.child;
        const count = if (comptime std.mem.eql(u8, f[0], "aux")) m.n * 10 * k else m.n;
        const want = count * @sizeOf(T);
        const bytes = try dir.readFileAllocOptions(io, f[1], a, .limited(want + 1), .of(T), null);
        if (bytes.len != want) return error.NnExportSize;
        @field(e, f[0]) = @as([*]T, @ptrCast(bytes.ptr))[0..count];
    }
    return e;
}

const testing = std.testing;

test "split codes match the harness's phases and win-comp's fold blocks; files read back" {
    const gpa = testing.allocator;
    const io = testing.io;
    var f = try harness.Fixture.init(gpa, 3000, 11);
    defer f.data.deinit();
    for (f.data.games, 0..) |*g, gi| if (gi % 7 == 0) {
        g.duration_s = 700;
    };
    for (f.data.rows, 0..) |*r, i| r.stats[@backingInt(seatstats.SeatStat.dmg_magic)] = @floatFromInt(i);
    const c = try harness.cuts(gpa, &f.data, 0);
    var e = try build(gpa, &f.data, c);
    defer e.deinit();

    var seen: [11]usize = @splat(0);
    for (f.data.games, 0..) |g, gi| {
        const s = e.split[gi];
        seen[s] += 1;
        const played = e.flags[gi] & flag_played != 0;
        try testing.expectEqual(g.duration_s >= harness.min_duration_s, played);
        if (!played) continue;
        try testing.expectEqual(harness.visible(.dev, c, g), s <= 5);
        try testing.expectEqual(harness.scored(.dev, c, g), s == 6);
        try testing.expectEqual(harness.visible(.select, c, g), s <= 7);
        try testing.expectEqual(harness.scored(.select, c, g), s == 8);
        try testing.expectEqual(harness.visible(.final, c, g), s <= 9);
        try testing.expectEqual(harness.scored(.final, c, g), s == 10);
        // win-comp: fold f scores lo <= start < hi among dev-visible games, fits on start < lo
        for (1..folds + 1) |fold| {
            const lo = e.bounds[fold - 1];
            const hi = e.bounds[fold];
            if (s > 5) continue;
            try testing.expectEqual(g.start >= lo and g.start < hi, s == fold);
            try testing.expectEqual(g.start < lo, s < fold);
        }
    }
    for (seen) |n| try testing.expect(n > 0);

    const players = try harness.gamePlayers(gpa, &f.data);
    defer gpa.free(players);
    var v = try harness.buildTrain(gpa, &f.data, players, .dev, c, 1, false);
    defer v.deinit();
    var starts: std.ArrayList(i64) = .empty;
    defer starts.deinit(gpa);
    for (v.train.games) |g| try starts.append(gpa, g.start);
    std.mem.sort(i64, starts.items, {}, std.sort.asc(i64));
    try testing.expectEqual(starts.items[starts.items.len / 2], e.bounds[0]);

    for (f.data.rows, 0..) |r, i| {
        const at = (@as(usize, r.game) * 10 + @as(usize, r.side) * 5 + @backingInt(r.role)) * k;
        try testing.expectEqual(r.y[@backingInt(rows.Outcome.gold14)], e.aux[at]);
        try testing.expectEqual(@as(f32, @floatFromInt(i)), e.aux[at + early.len + @backingInt(seatstats.SeatStat.dmg_magic)]);
        try testing.expectEqual(r.champion, e.champions[e.champ[r.game][@as(usize, r.side) * 5 + @backingInt(r.role)]]);
    }

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const snap = try std.fmt.allocPrint(gpa, ".zig-cache/tmp/{s}", .{&tmp.sub_path});
    defer gpa.free(snap);
    try write(gpa, io, snap, &e);
    var back = try read(gpa, io, snap);
    defer back.deinit();
    inline for (files) |fl| {
        try testing.expectEqualSlices(u8, bytesOf(@field(e, fl[0])), bytesOf(@field(back, fl[0])));
    }
    try testing.expectEqualSlices(u32, e.champions, back.champions);
    try testing.expectEqualSlices(u32, e.patches, back.patches);
    try testing.expectEqual(e.bounds, back.bounds);
}
