//! Shared by the held-out analyses (eval, objectives, playstyle; docs/model.md "Shared
//! protocol"): the train/test split of the scanned games, games with a timeline and
//! their players by role, paired gains, shrinkage priors, prediction files.

const std = @import("std");
const store = @import("store");
const core = @import("core");
const timeline = @import("riot/timeline.zig");
const digest = @import("riot/digest.zig");
const stats = @import("stats.zig");
const eval = @import("eval.zig");
const endpoints = @import("riot/endpoints.zig");
const Role = core.Role;
const Io = std.Io;

/// stats.scan's sink: every game, in a list
pub const GameList = struct {
    gpa: std.mem.Allocator,
    items: std.ArrayList(stats.Row) = .empty,

    pub fn add(l: *GameList, g: stats.Row) !void {
        try l.items.append(l.gpa, g);
    }
};

/// The scanned games and eval's split of them
pub const HeldOut = struct {
    list: GameList,
    split: eval.Split,
    /// The test cut: test games start at or after it
    cutoff: i64,

    pub fn deinit(h: *HeldOut) void {
        h.split.deinit(h.list.gpa);
        h.list.items.deinit(h.list.gpa);
    }

    /// Train then test, for loops that treat both alike
    pub fn parts(h: *const HeldOut) [2][]const stats.Row {
        return .{ h.split.train, h.split.tests };
    }
};

/// The protocol's cuts (eval.cutsOf) over every platform's and patch's games, as the lab
/// and `meiolol eval --platform all` set them, whatever subset a tool scans
pub fn protocolCuts(gpa: std.mem.Allocator, db: store.Db) !eval.Cuts {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    var ids: [endpoints.platforms.len][]const u8 = undefined;
    for (endpoints.platforms, &ids) |p, *id| id.* = p.id;
    const patches = try stats.patches(arena.allocator(), db, &ids);
    var list: GameList = .{ .gpa = gpa };
    defer list.items.deinit(gpa);
    _ = try stats.scan(gpa, db, patches, &ids, 0, &list);
    var starts: std.ArrayList(i64) = .empty;
    defer starts.deinit(gpa);
    for (list.items.items) |g| if (g.duration_s >= eval.min_duration_s) try starts.append(gpa, g.start);
    std.mem.sort(i64, starts.items, {}, std.sort.asc(i64));
    return eval.cutsOf(starts.items, .{});
}

/// Scans the games on `patches` and `platforms` and splits them at the protocol's test
/// cut (protocolCuts): test on every game from it on, train on older ones. test_share
/// other than eval.test_share sets a cut of its own over the scanned games instead.
/// test_platform: region model only; the global model is never scored on a region
pub fn heldOut(
    gpa: std.mem.Allocator,
    db: store.Db,
    patches: []const []const u8,
    platforms: []const []const u8,
    test_share: f64,
    test_platform: ?[]const u8,
) !HeldOut {
    var list: GameList = .{ .gpa = gpa };
    errdefer list.items.deinit(gpa);
    _ = try stats.scan(gpa, db, patches, platforms, 0, &list);
    const split = try eval.split(gpa, list.items.items, platforms, .{
        .test_share = test_share,
        .test_platform = test_platform,
        .cuts = if (test_share == eval.test_share) try protocolCuts(gpa, db) else null,
    });
    return .{ .list = list, .split = split, .cutoff = split.cuts.test_ };
}

/// Participant ids (slot + 1) by side (blue, red) and role
pub const Pids = [2][Role.count]u8;

/// Ranked solo games on some patches and platforms with a timeline (no remakes, a
/// winner), decoded one at a time; ones that fail to decode are skipped
pub const TimelineGames = struct {
    gpa: std.mem.Allocator,
    patch_json: []u8,
    platform_json: []u8,
    q: store.Stmt,
    players: store.Stmt,
    scratch: std.heap.ArenaAllocator,
    /// Digests, for passes that read only what they keep (riot/digest.zig)
    source: ?digest.Source = null,
    /// With digests: their reads and the participants', ahead of next
    ahead: ?*store.Ahead = null,

    /// Valid until the next call to next
    pub const Game = struct { match_id: []const u8, patch: []const u8, t: timeline.Timeline };

    pub fn init(
        gpa: std.mem.Allocator,
        db: store.Db,
        patches: []const []const u8,
        platforms: []const []const u8,
    ) !TimelineGames {
        return initWith(gpa, null, db, patches, platforms, 0);
    }

    /// As init, games started from `since_ms` on (Riot ms timestamp), each game's timeline
    /// as its digest gives it (riot/digest.zig cut): for a pass that reads nothing a
    /// digest leaves out
    pub fn initDigests(
        gpa: std.mem.Allocator,
        io: std.Io,
        db: store.Db,
        patches: []const []const u8,
        platforms: []const []const u8,
        since_ms: i64,
    ) !TimelineGames {
        return initWith(gpa, io, db, patches, platforms, since_ms);
    }

    /// Digests when `io` is given
    fn initWith(
        gpa: std.mem.Allocator,
        io: ?std.Io,
        db: store.Db,
        patches: []const []const u8,
        platforms: []const []const u8,
        since_ms: i64,
    ) !TimelineGames {
        const digests = io != null;
        const patch_json = try std.json.Stringify.valueAlloc(gpa, patches, .{});
        errdefer gpa.free(patch_json);
        const platform_json = try std.json.Stringify.valueAlloc(gpa, platforms, .{});
        errdefer gpa.free(platform_json);
        const where =
            \\WHERE m.patch IN (SELECT value FROM json_each(?)) AND m.queue_id = ?
            \\  AND m.platform IN (SELECT value FROM json_each(?))
            \\  AND m.remake = 0 AND m.winning_team IS NOT NULL AND m.game_start >= ?
        ;
        var q = try db.prepare(if (digests)
            \\SELECT m.match_id, t.rowid, m.patch, d.data
            \\FROM matches m JOIN timeline.timelines t USING (match_id)
            \\LEFT JOIN timeline.digests d ON d.source = t.rowid AND d.match_id = m.match_id
            \\
        ++ where
        else
            \\SELECT m.match_id, t.data, m.patch
            \\FROM matches m JOIN timeline.timelines t USING (match_id)
            \\
        ++ where);
        errdefer q.deinit();
        try q.bind(.{ patch_json, stats.ranked_solo, platform_json, since_ms });
        var players = try db.prepare("SELECT slot, team_id, position FROM participants WHERE match_id = ?");
        errdefer players.deinit();
        var source: ?digest.Source = if (digests) try .init(db) else null;
        errdefer if (source) |*src| src.deinit();
        return .{
            .gpa = gpa,
            .patch_json = patch_json,
            .platform_json = platform_json,
            .q = q,
            .players = players,
            .scratch = .init(gpa),
            .source = source,
            .ahead = if (io) |i| try .start(gpa, i, db, .{
                .list = "SELECT m.match_id, t.rowid FROM matches m JOIN timeline.timelines t USING (match_id)\n" ++ where,
                .reads = &.{ digest.read_ahead, "SELECT slot FROM participants WHERE match_id = ?1" },
            }, .{ patch_json, stats.ranked_solo, platform_json, since_ms }) else null,
        };
    }

    pub fn deinit(s: *TimelineGames) void {
        if (s.ahead) |a| a.stop();
        s.q.deinit();
        s.players.deinit();
        if (s.source) |*src| src.deinit();
        s.scratch.deinit();
        s.gpa.free(s.patch_json);
        s.gpa.free(s.platform_json);
    }

    pub fn next(s: *TimelineGames) !?Game {
        while (try s.q.step()) {
            if (s.ahead) |a| a.next();
            _ = s.scratch.reset(.retain_capacity);
            const scratch = s.scratch.allocator();
            const t = if (s.source) |*src|
                src.get(scratch, s.q.int(1), if (s.q.isNull(3)) null else s.q.bytes(3)) catch continue
            else
                timeline.decode(scratch, store.raw.decompress(scratch, s.q.bytes(1)) catch continue) catch continue;
            return .{ .match_id = s.q.bytes(0), .patch = s.q.bytes(2), .t = t };
        }
        return null;
    }

    /// A game's participant ids by side and role; null unless both teams fill every
    /// role and ids 1-5 are blue, as match-v5 numbers them and timeline sums assume
    pub fn pids(s: *TimelineGames, g: Game) !?Pids {
        try s.players.bind(.{g.match_id});
        var pid: Pids = @splat(@splat(0));
        while (try s.players.step()) {
            const side: usize = switch (s.players.int(1)) {
                100 => 0,
                200 => 1,
                else => continue,
            };
            const r = Role.fromLcu(if (s.players.isNull(2)) "" else s.players.bytes(2)) orelse continue;
            const slot = s.players.int(0);
            if (slot < 0 or slot >= g.t.participants) continue;
            pid[side][@backingInt(r)] = @intCast(slot + 1);
        }
        if (std.mem.findScalar(u8, std.mem.asBytes(&pid), 0) != null) return null;
        for (pid, 0..) |team, side| for (team) |p| {
            if ((p <= 5) != (side == 0)) return null;
        };
        return pid;
    }
};

/// Dense indexes for ids (champions, items) in the order first seen
pub const DenseIndex = struct {
    map: std.AutoHashMapUnmanaged(u32, u16) = .empty,
    ids: std.ArrayList(u32) = .empty,

    pub fn deinit(d: *DenseIndex, gpa: std.mem.Allocator) void {
        d.map.deinit(gpa);
        d.ids.deinit(gpa);
    }

    pub fn get(d: *DenseIndex, gpa: std.mem.Allocator, id: u32) !u16 {
        const e = try d.map.getOrPut(gpa, id);
        if (!e.found_existing) {
            e.value_ptr.* = @intCast(d.ids.items.len);
            try d.ids.append(gpa, id);
        }
        return e.value_ptr.*;
    }

    pub fn count(d: *const DenseIndex) u32 {
        return @intCast(d.ids.items.len);
    }
};

pub const Gain = struct { mean: f64, half_width: f64 };

/// Mean of before - after per row, ± 95% with rows clustered by `rows[i].game` (rows
/// sorted by game). Rows whose `before` is NaN (no outcome) are left out
pub fn pairedGain(rows: anytype, before: []const f64, after: []const f64) Gain {
    var sums: PairedSums = .{};
    var i: usize = 0;
    while (i < rows.len) {
        var d: f64 = 0;
        var n: f64 = 0;
        const g = rows[i].game;
        while (i < rows.len and rows[i].game == g) : (i += 1) {
            if (std.math.isNan(before[i])) continue;
            d += before[i] - after[i];
            n += 1;
        }
        sums.add(d, n);
    }
    return sums.gain();
}

/// pairedGain for one row per game
pub fn pairedGainGames(before: []const f64, after: []const f64) Gain {
    var sums: PairedSums = .{};
    for (before, after) |b, a| sums.add(b - a, 1);
    return sums.gain();
}

/// Per-game sums of paired differences
pub const PairedSums = struct {
    total: f64 = 0,
    sum_sq: f64 = 0,
    games: f64 = 0,
    rows: f64 = 0,

    /// One game's summed difference over its `rows` rows
    pub fn add(s: *PairedSums, d: f64, rows: f64) void {
        s.total += d;
        s.sum_sq += d * d;
        s.games += 1;
        s.rows += rows;
    }

    pub fn gain(s: PairedSums) Gain {
        const mean_d = s.total / s.games;
        const var_d = @max(s.sum_sq / s.games - mean_d * mean_d, 0);
        return .{ .mean = s.total / s.rows, .half_width = 1.96 * @sqrt(s.games * var_d) / s.rows };
    }
};

/// Log loss of chance p for outcome y in nats. The clamp only keeps log(0) out: one
/// tighter than a model's most confident chance would hide its confident misses
pub fn logLoss(p: f64, y: f64) f64 {
    const q = std.math.clamp(p, 1e-9, 1 - 1e-9);
    return -(y * @log(q) + (1 - y) * @log(1 - q));
}

pub fn mean(xs: []const f64) f64 {
    var sum: f64 = 0;
    for (xs) |x| sum += x;
    return sum / @as(f64, @floatFromInt(xs.len));
}

/// Cells with fewer rows are left out of the spread estimates
pub const prior_min_rows = 10;
/// Fewer such cells in a role and the group is off for it
pub const prior_min_cells = 20;

/// Shrinkage prior for one role's cells of an additive effect, from the method of
/// moments (as lanegold.zig): the spread of the cells' raw estimates beyond their noise
pub const Prior = struct {
    /// Prior strength in units of the cells' information (inf: off, effects 0)
    k: f64,
    /// Variance of true effects (0: off)
    tau2: f64,

    pub const off: Prior = .{ .k = std.math.inf(f64), .tau2 = 0 };

    /// sxr, info: a cell's sum of x times the working response and of x squared (both
    /// weighted, for IRLS); n: rows behind it (null: info); sigma2: residual variance
    pub fn estimate(sxr: []const f64, info: []const f64, n: ?[]const f64, sigma2: f64) Prior {
        var cells: f64 = 0;
        var excess: f64 = 0;
        for (sxr, info, 0..) |xr, xx, i| {
            const rows = if (n) |ns| ns[i] else xx;
            if (rows < prior_min_rows or xx == 0) continue;
            const est = xr / xx;
            cells += 1;
            excess += est * est - sigma2 / xx;
        }
        if (cells < prior_min_cells) return .off;
        const tau2 = excess / cells;
        if (tau2 <= 0) return .off;
        return .{ .k = sigma2 / tau2, .tau2 = tau2 };
    }

    /// A cell's shrunk effect
    pub fn effect(p: Prior, sxr: f64, info: f64) f64 {
        return if (std.math.isInf(p.k) or info == 0) 0 else sxr / (info + p.k);
    }
};

/// One TSV of test predictions per model in a directory (docs/model.md protocol), or
/// none without one
pub const Preds = struct {
    files: []Io.File = &.{},
    writers: []Io.File.Writer = &.{},

    /// Creates `dir`/`name`.tsv for each name, starting with `header`
    pub fn init(
        arena: std.mem.Allocator,
        io: Io,
        dir: ?[]const u8,
        names: []const []const u8,
        header: []const u8,
    ) !Preds {
        const d = dir orelse return .{};
        const cwd = Io.Dir.cwd();
        try cwd.createDirPath(io, d);
        const files = try arena.alloc(Io.File, names.len);
        const writers = try arena.alloc(Io.File.Writer, names.len);
        for (names, 0..) |name, i| {
            const path = try arena.print("{s}/{s}.tsv", .{ d, name });
            files[i] = cwd.createFile(io, path, .{}) catch |err| {
                for (files[0..i]) |f| f.close(io);
                return err;
            };
            writers[i] = files[i].writer(io, try arena.alloc(u8, 16 * 1024));
        }
        var p: Preds = .{ .files = files, .writers = writers };
        for (0..names.len) |i| p.at(i).writeAll(header) catch |err| {
            p.close(io);
            return err;
        };
        return p;
    }

    pub fn on(p: Preds) bool {
        return p.writers.len > 0;
    }

    pub fn at(p: Preds, i: usize) *Io.Writer {
        return &p.writers[i].interface;
    }

    pub fn flush(p: Preds) !void {
        for (p.writers) |*w| try w.interface.flush();
    }

    pub fn close(p: Preds, io: Io) void {
        for (p.files) |f| f.close(io);
    }
};

const testing = std.testing;

test "paired gain clusters rows by game and skips missing rows" {
    const Row = struct { game: u32 };
    const rows = [_]Row{ .{ .game = 0 }, .{ .game = 0 }, .{ .game = 1 }, .{ .game = 2 } };
    const before = [_]f64{ 2, 1, std.math.nan(f64), 3 };
    const after = [_]f64{ 1, 1, 0, 1 };
    const g = pairedGain(&rows, &before, &after);
    // Game sums 1, 0 (no rows), 2 over 3 rows
    try testing.expectApproxEqAbs(1.0, g.mean, 1e-12);
    const one = pairedGainGames(&.{ 1, 2, 3 }, &.{ 0, 0, 0 });
    try testing.expectApproxEqAbs(2.0, one.mean, 1e-12);
    try testing.expectApproxEqAbs(1.96 * @sqrt(2.0 / 3.0 / 3.0), one.half_width, 1e-12);
}

test "prior: off with too few cells, shrinks noisy cells" {
    var sxr: [30]f64 = undefined;
    var info: [30]f64 = undefined;
    for (&sxr, &info, 0..) |*xr, *xx, i| {
        xx.* = 100;
        xr.* = 100 * @as(f64, if (i % 2 == 0) 0.5 else -0.5);
    }
    const p: Prior = .estimate(&sxr, &info, null, 1);
    // Raw estimates ±0.5, noise variance 0.01: true variance 0.24
    try testing.expectApproxEqAbs(0.24, p.tau2, 1e-12);
    try testing.expectApproxEqAbs(50.0 / (100.0 + 1.0 / 0.24), p.effect(sxr[0], 100), 1e-9);
    try testing.expectEqual(Prior.off, Prior.estimate(sxr[0..10], info[0..10], null, 1));
}
