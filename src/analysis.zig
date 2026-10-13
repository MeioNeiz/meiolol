//! Shared by the held-out analyses (eval, outcomes, items, objectives, playstyle,
//! scaling; docs/model.md "Shared protocol"): the train/test split of the scanned games,
//! games with a timeline and their players by role, paired gains, shrinkage priors and
//! additive backfitting, prediction files.

const std = @import("std");
const store = @import("store");
const core = @import("core");
const timeline = @import("riot/timeline.zig");
const stats = @import("stats.zig");
const eval = @import("eval.zig");
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
    /// Start of the first test game
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

/// Scans the games on `patches` and `platforms` and splits them as the protocol does:
/// test on the newest `test_share` of `test_platform`'s games, train on older ones
pub fn heldOut(
    gpa: std.mem.Allocator,
    db: store.Db,
    patches: []const []const u8,
    platforms: []const []const u8,
    test_share: f64,
    test_platform: []const u8,
) !HeldOut {
    var list: GameList = .{ .gpa = gpa };
    errdefer list.items.deinit(gpa);
    _ = try stats.scan(gpa, db, patches, platforms, 0, &list);
    const split = try eval.split(gpa, list.items.items, platforms, .{
        .test_share = test_share,
        .test_platform = test_platform,
    });
    return .{ .list = list, .split = split, .cutoff = split.tests[0].start };
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

    /// Valid until the next call to next
    pub const Game = struct { match_id: []const u8, patch: []const u8, t: timeline.Timeline };

    pub fn init(
        gpa: std.mem.Allocator,
        db: store.Db,
        patches: []const []const u8,
        platforms: []const []const u8,
    ) !TimelineGames {
        const patch_json = try std.json.Stringify.valueAlloc(gpa, patches, .{});
        errdefer gpa.free(patch_json);
        const platform_json = try std.json.Stringify.valueAlloc(gpa, platforms, .{});
        errdefer gpa.free(platform_json);
        var q = try db.prepare(
            \\SELECT m.match_id, t.data, m.patch
            \\FROM matches m JOIN timeline.timelines t USING (match_id)
            \\WHERE m.patch IN (SELECT value FROM json_each(?)) AND m.queue_id = ?
            \\  AND m.platform IN (SELECT value FROM json_each(?))
            \\  AND m.remake = 0 AND m.winning_team IS NOT NULL
        );
        errdefer q.deinit();
        try q.bind(.{ patch_json, stats.ranked_solo, platform_json });
        const players = try db.prepare("SELECT slot, team_id, position FROM participants WHERE match_id = ?");
        return .{
            .gpa = gpa,
            .patch_json = patch_json,
            .platform_json = platform_json,
            .q = q,
            .players = players,
            .scratch = .init(gpa),
        };
    }

    pub fn deinit(s: *TimelineGames) void {
        s.q.deinit();
        s.players.deinit();
        s.scratch.deinit();
        s.gpa.free(s.patch_json);
        s.gpa.free(s.platform_json);
    }

    pub fn next(s: *TimelineGames) !?Game {
        while (try s.q.step()) {
            _ = s.scratch.reset(.retain_capacity);
            const scratch = s.scratch.allocator();
            const raw = store.raw.decompress(scratch, s.q.bytes(1)) catch continue;
            const t = timeline.decode(scratch, raw) catch continue;
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
        if (std.mem.indexOfScalar(u8, std.mem.asBytes(&pid), 0) != null) return null;
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

/// Mean of the values that are not NaN (0 when none are)
pub fn nanMean(xs: []const f64) f64 {
    var sum: f64 = 0;
    var n: f64 = 0;
    for (xs) |x| if (!std.math.isNan(x)) {
        sum += x;
        n += 1;
    };
    return sum / @max(n, 1);
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
        if (cells < prior_min_cells or excess <= 0) return .off;
        return .{ .k = sigma2 / (excess / cells), .tau2 = excess / cells };
    }

    /// A cell's shrunk effect
    pub fn effect(p: Prior, sxr: f64, info: f64) f64 {
        return if (std.math.isInf(p.k) or info == 0) 0 else sxr / (info + p.k);
    }
};

/// A row's covariate for one cell of an effect group
pub const Term = struct { cell: u32, x: f32 };

/// Shrunk effects of some groups (an enum) for one Gaussian outcome, from backfit
pub fn Fit(comptime Group: type) type {
    const n_group = @typeInfo(Group).@"enum".field_names.len;
    return struct {
        effects: [n_group]?[]f32 = @splat(null),
        /// [group]: sum of x squared per cell (rows behind it when x is 1)
        info: [n_group]?[]f64 = @splat(null),
        /// [group][role]: prior strength in rows (inf: off) and spread of true effects
        k: [n_group][Role.count]f64 = @splat(@splat(0)),
        tau: [n_group][Role.count]f64 = @splat(@splat(0)),

        const F = @This();

        pub fn deinit(f: *F, gpa: std.mem.Allocator) void {
            for (f.effects) |e| if (e) |x| gpa.free(x);
            for (f.info) |e| if (e) |x| gpa.free(x);
        }

        /// space: as for backfit
        pub fn predict(f: *const F, space: anytype, r: anytype) f32 {
            var sum: f32 = 0;
            var buf: [@TypeOf(space).max_terms]Term = undefined;
            for (f.effects, 0..) |e, gi| if (e) |b| {
                const n = space.terms(@as(Group, @fromBackingInt(@intCast(gi))), r, &buf);
                for (buf[0..n]) |t| sum += t.x * b[t.cell];
            };
            return sum;
        }
    };
}

/// Additive effects in `groups`, each fitted in turn on the residual of the others
/// (backfitting) and shrunk toward 0 with a Prior per group and role. Rows whose `z` is
/// NaN are left out. `space` lays out the cells, role first so a cell's role is cell /
/// perRole: `perRole(g)`, `terms(g, row, *[max_terms]Term)` (count written) and
/// `shrunk(g)` (false: left unshrunk, for groups of few cells with many rows each)
pub fn backfit(
    comptime Group: type,
    gpa: std.mem.Allocator,
    space: anytype,
    rows: anytype,
    z: []const f32,
    groups: []const Group,
    passes: u32,
) !Fit(Group) {
    var f: Fit(Group) = .{};
    errdefer f.deinit(gpa);
    const res = try gpa.alloc(f32, rows.len);
    defer gpa.free(res);
    @memcpy(res, z);
    for (groups) |g| {
        const len = Role.count * space.perRole(g);
        const b = try gpa.alloc(f32, len);
        @memset(b, 0);
        f.effects[@backingInt(g)] = b;
        const info = try gpa.alloc(f64, len);
        @memset(info, 0);
        f.info[@backingInt(g)] = info;
    }
    var sxr: std.ArrayList(f64) = .empty;
    defer sxr.deinit(gpa);
    var old: std.ArrayList(f32) = .empty;
    defer old.deinit(gpa);
    var buf: [@TypeOf(space).max_terms]Term = undefined;

    for (0..passes) |_| for (groups) |g| {
        const gi = @backingInt(g);
        const b = f.effects[gi].?;
        const sxx = f.info[gi].?;
        const per_role = space.perRole(g);
        try sxr.resize(gpa, b.len);
        @memset(sxr.items, 0);
        @memset(sxx, 0);
        var sum_sq: f64 = 0;
        var n_rows: f64 = 0;
        for (rows, res) |r, e| {
            if (std.math.isNan(e)) continue;
            sum_sq += e * e;
            n_rows += 1;
            const n = space.terms(g, r, &buf);
            for (buf[0..n]) |t| {
                sxr.items[t.cell] += t.x * (e + t.x * b[t.cell]);
                sxx[t.cell] += t.x * t.x;
            }
        }
        const sigma2 = sum_sq / @max(n_rows, 1);
        try old.resize(gpa, b.len);
        @memcpy(old.items, b);
        for (0..Role.count) |ri| {
            const lo = ri * per_role;
            const cell_xr = sxr.items[lo..][0..per_role];
            const cell_xx = sxx[lo..][0..per_role];
            const prior: Prior = if (space.shrunk(g)) .estimate(cell_xr, cell_xx, null, sigma2) else .{ .k = 1, .tau2 = sigma2 };
            f.k[gi][ri] = prior.k;
            f.tau[gi][ri] = if (std.math.isInf(prior.k)) 0 else @sqrt(sigma2 / prior.k);
            for (b[lo..][0..per_role], cell_xr, cell_xx) |*x, xr, xx| x.* = @floatCast(prior.effect(xr, xx));
        }
        for (rows, res) |r, *e| {
            if (std.math.isNan(e.*)) continue;
            const n = space.terms(g, r, &buf);
            for (buf[0..n]) |t| e.* -= t.x * (b[t.cell] - old.items[t.cell]);
        }
    };
    return f;
}

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
            const path = try std.fmt.allocPrint(arena, "{s}/{s}.tsv", .{ d, name });
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
