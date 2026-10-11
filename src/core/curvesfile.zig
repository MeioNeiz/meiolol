//! Curves file: how each lane matchup unfolds, minute by minute, for one patch (or
//! patch range). Written beside the model file by `meiolol curves`.
//!
//! Format v4, little-endian:
//!   magic "MEIOCURV", version u32, minutes u32 (m), games u32, curves u32 (k),
//!   patch [16]u8 zero padded
//!   Fit: per role the estimation's variance parameters and smoothing (curvefit.zig)
//!   k x (Header, then m x Minute), the extern structs below
//! Curves are sorted by (role, a, b, bracket, experience) with a <= b by champion id;
//! a == b is a mirror, seen from blue's side. Everything is from a's side: diffs are a
//! minus b. a == b == 0 is the role baseline: every lane of the role counted from both
//! sides, comeback counts only.
//! Minute i (0-based) is the frame at i + 1 minutes.

const std = @import("std");
const Role = @import("roles.zig").Role;
pub const curvefit = @import("curvefit.zig");

const log = std.log.scoped(.curves);

pub const magic = "MEIOCURV";
pub const version: u32 = 4;
pub const patch_len = 16;
/// Lane phase and the early mid game; later minutes mostly measure who is still playing
pub const max_minutes = 25;
/// "Wins lane" means ahead in gold at this minute (the usual GD@14/15 convention)
pub const lane_minute = 14;
/// Phases: before level 6 timing (0-6 min), lane (6-14), after lane (14+)
pub const phase_ends = [_]u8{ 6, lane_minute };
pub const phases = phase_ends.len + 1;
const header_len = magic.len + 4 * 4 + patch_len;
/// Bounds allocations from a corrupt header
const max_curves = 1 << 24;

/// Mastery points that make a laner "experienced" on their champion: the top bucket of
/// research/raw/lol-mastery-analysis.md (win rates level off from 10k; 100k+ is high)
pub const experienced_points = 100_000;

/// Which games a curve counts: all, or only those where a (or b) is experienced on
/// their champion (mastery is a snapshot from when the crawler fetched it, not match time)
pub const Experience = enum(u8) { any, a, b };

/// Visible rank tiers, never inferred MMR (docs/concept.md)
/// Comeback odds: games and wins by lane gold difference at these minutes, in buckets
/// split at these edges (behind 1500+, 500 to 1500, within 500, ahead 500 to 1500, 1500+)
pub const comeback_minutes = [_]u8{ 10, 15 };
pub const comeback_edges = [_]i16{ -1500, -500, 500, 1500 };
pub const buckets = comeback_edges.len + 1;
pub const Comeback = enum { ten, fifteen };

/// Games, and of them won by the side the curve is seen from
pub const Counts = extern struct { games: u32 = 0, wins: u32 = 0 };

pub fn bucket(gold: i16) usize {
    if (gold < comeback_edges[0]) return 0;
    if (gold < comeback_edges[1]) return 1;
    if (gold <= comeback_edges[2]) return 2;
    if (gold <= comeback_edges[3]) return 3;
    return 4;
}

pub const Bracket = enum(u8) {
    all,
    /// Iron to Silver
    low,
    /// Gold to Emerald
    mid,
    /// Diamond and above
    high,

    pub const count = 4;

    pub fn label(b: Bracket) []const u8 {
        return switch (b) {
            .all => "All ranks",
            .low => "Iron to Silver",
            .mid => "Gold to Emerald",
            .high => "Diamond+",
        };
    }

    /// From an index into `tiers`
    pub fn ofRank(rank: usize) Bracket {
        return if (rank < 3) .low else if (rank < 6) .mid else .high;
    }
};

/// Riot's ranked tiers, lowest first
pub const tiers = [_][]const u8{
    "IRON",
    "BRONZE",
    "SILVER",
    "GOLD",
    "PLATINUM",
    "EMERALD",
    "DIAMOND",
    "MASTER",
    "GRANDMASTER",
    "CHALLENGER",
};

pub fn tierRank(tier: []const u8) ?usize {
    for (tiers, 0..) |t, i| if (std.mem.eql(u8, tier, t)) return i;
    return null;
}

/// A game's tier: the median rank of its players with a known one (sorts `ranks`);
/// null when fewer than half of ten players are known
pub fn medianRank(ranks: []usize) ?usize {
    if (ranks.len < 5) return null;
    std.mem.sort(usize, ranks, {}, std.sort.asc(usize));
    return ranks[ranks.len / 2];
}

pub const Quartiles = extern struct { p25: i16 = 0, p50: i16 = 0, p75: i16 = 0 };

/// Gold, XP, CS: the order of Minute.est and the fit's metric index
pub const Metric = enum(u2) { gold, xp, cs };
pub const metrics = 3;

/// The estimated mean difference (curvefit.zig: shrunk toward the champions'
/// baseline, smoothed across minutes) and its standard error
pub const Estimate = extern struct { mean: i16 = 0, se: u16 = 0 };

pub const Minute = extern struct {
    /// Games still going at this minute
    n: u32,
    /// Raw quartiles of the games' differences: the spread band
    gold: Quartiles,
    xp: Quartiles,
    /// Lane minions plus jungle monsters
    cs: Quartiles,
    est: [metrics]Estimate = @splat(.{}),
    _pad: u16 = 0,
};

/// The file's estimation parameters: per role, curvefit.Params and the smoothing
/// strength per metric
pub const Fit = extern struct {
    params: [Role.count]curvefit.Params,
    lambda: [Role.count][metrics]f32,
};

pub const Header = extern struct {
    role: u8,
    bracket: u8,
    experience: u8,
    _pad: u8 = 0,
    a: u32,
    b: u32,
    games: u32,
    a_wins: u32,
    /// Games that reached lane_minute, and how many each side led in gold then
    lane_games: u32,
    lane_a: u32,
    lane_b: u32,
    /// Games won by the side that led at lane_minute
    a_wins_lane_a: u32,
    b_wins_lane_b: u32,
    /// Games where a took part in killing b (as killer or assist) in each phase
    a_kills_b: [phases]u32,
    b_kills_a: [phases]u32,
    /// Median seconds to level 6; 0 when too few reached it
    level6_a: u16,
    level6_b: u16,
    /// Median seconds to the first finished item (Data Dragon legendaries); 0 when too
    /// few finished one
    first_item_a: u16,
    first_item_b: u16,
    /// Share of the gold estimate at lane_minute that comes from this curve's own
    /// games rather than what it was shrunk toward, per mille: n / (n + k)
    own: u16,
    _pad2: u16 = 0,
    /// [comeback minute][bucket of a's gold lead], wins = a's
    comeback: [comeback_minutes.len][buckets]Counts,
};

/// One lane in one game, for Builder
pub const Lane = struct {
    role: Role,
    bracket: ?Bracket,
    a: u32,
    b: u32,
    a_won: bool,
    /// Minutes with a frame, at most max_minutes
    minutes: u8,
    gold: [max_minutes]i16 = @splat(0),
    xp: [max_minutes]i16 = @splat(0),
    cs: [max_minutes]i16 = @splat(0),
    a_kills_b: [phases]bool = @splat(false),
    b_kills_a: [phases]bool = @splat(false),
    level6_a: u16 = 0,
    level6_b: u16 = 0,
    first_item_a: u16 = 0,
    first_item_b: u16 = 0,
    /// Mastery of at least experienced_points on their champion
    experienced_a: bool = false,
    experienced_b: bool = false,
    /// The game's number in the builder (set by addLane), for split-half tests
    game: u32 = 0,

    /// The same lane from b's side
    fn swapped(l: Lane) Lane {
        var s = l;
        s.a = l.b;
        s.b = l.a;
        s.a_won = !l.a_won;
        for (&s.gold, &s.xp, &s.cs) |*g, *x, *c| {
            g.* = -g.*;
            x.* = -x.*;
            c.* = -c.*;
        }
        s.a_kills_b = l.b_kills_a;
        s.b_kills_a = l.a_kills_b;
        s.level6_a = l.level6_b;
        s.level6_b = l.level6_a;
        s.first_item_a = l.first_item_b;
        s.first_item_b = l.first_item_a;
        s.experienced_a = l.experienced_b;
        s.experienced_b = l.experienced_a;
        return s;
    }
};

pub const Builder = struct {
    gpa: std.mem.Allocator,
    lanes: std.ArrayList(Lane) = .empty,
    games: u32 = 0,

    pub fn deinit(b: *Builder) void {
        b.lanes.deinit(b.gpa);
    }

    /// Call once per game, after its lanes
    pub fn addGame(b: *Builder) void {
        b.games += 1;
    }

    pub fn addLane(b: *Builder, lane: Lane) !void {
        var l = if (lane.a > lane.b) lane.swapped() else lane;
        l.game = b.games;
        try b.lanes.append(b.gpa, l);
    }

    /// Curves with at least `min_games` games, for every bracket that has them. Logs
    /// the fit per role (k, smoothing, split-half test; curvefit.zig)
    pub fn write(b: *Builder, w: *std.Io.Writer, patch: []const u8, min_games: u32) !void {
        if (patch.len > patch_len) return error.PatchTooLong;
        const lanes = b.lanes.items;
        std.mem.sort(Lane, lanes, {}, laneOrder);
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(b.gpa);
        const fit = try b.gpa.create(Fit);
        defer b.gpa.destroy(fit);
        fit.* = std.mem.zeroes(Fit);

        var curves: u32 = 0;
        var start: usize = 0;
        while (start < lanes.len) {
            const role = lanes[start].role;
            var end = start;
            while (end < lanes.len and lanes[end].role == role) end += 1;
            curves += try writeRole(b.gpa, &out, lanes[start..end], min_games, fit);
            start = end;
        }

        try w.writeAll(magic);
        try w.writeInt(u32, version, .little);
        try w.writeInt(u32, max_minutes, .little);
        try w.writeInt(u32, b.games, .little);
        try w.writeInt(u32, curves, .little);
        try w.writeAll(patch);
        try w.splatByteAll(0, patch_len - patch.len);
        try w.writeAll(std.mem.asBytes(fit));
        try w.writeAll(out.items);
    }

    fn laneOrder(_: void, x: Lane, y: Lane) bool {
        if (x.role != y.role) return @intFromEnum(x.role) < @intFromEnum(y.role);
        if (x.a != y.a) return x.a < y.a;
        return x.b < y.b;
    }

    fn sameMatchup(x: Lane, y: Lane) bool {
        return x.role == y.role and x.a == y.a and x.b == y.b;
    }
};

/// One role's curves, lanes sorted by matchup: the baselines, then each matchup by
/// bracket and experience
fn writeRole(
    gpa: std.mem.Allocator,
    out: *std.ArrayList(u8),
    lanes: []Lane,
    min_games: u32,
    fit: *Fit,
) !u32 {
    const role = lanes[0].role;
    var groups: std.ArrayList(curvefit.Group) = .empty;
    defer groups.deinit(gpa);
    var dense: std.AutoHashMapUnmanaged(u32, u32) = .empty;
    defer dense.deinit(gpa);
    var start: usize = 0;
    while (start < lanes.len) {
        var end = start + 1;
        while (end < lanes.len and Builder.sameMatchup(lanes[start], lanes[end])) end += 1;
        var ids: [2]u32 = undefined;
        for ([2]u32{ lanes[start].a, lanes[start].b }, &ids) |champion, *id| {
            const e = try dense.getOrPut(gpa, champion);
            if (!e.found_existing) e.value_ptr.* = dense.count() - 1;
            id.* = e.value_ptr.*;
        }
        try groups.append(gpa, .{ .start = @intCast(start), .end = @intCast(end), .a = ids[0], .b = ids[1] });
        start = end;
    }
    var rf = try curvefit.fitRole(gpa, lanes, groups.items, dense.count());
    defer rf.deinit(gpa);
    const ri = @intFromEnum(role);
    fit.params[ri] = rf.params;
    for (&fit.lambda[ri], rf.lambda) |*to, from| to.* = @floatCast(from);
    logFit(role, &rf);

    var curves = try baselines(gpa, out, lanes, min_games);
    var scratch: std.ArrayList(i16) = .empty;
    defer scratch.deinit(gpa);
    var subset: std.ArrayList(Lane) = .empty;
    defer subset.deinit(gpa);
    for (groups.items, 0..) |g, gi| {
        const group = lanes[g.start..g.end];
        for (std.enums.values(Bracket)) |bracket| {
            for (std.enums.values(Experience)) |experience| {
                subset.clearRetainingCapacity();
                const filter: curvefit.Filter = .{ .bracket = bracket, .experience = experience };
                for (group) |l| if (curvefit.keeps(filter, l)) try subset.append(gpa, l);
                if (subset.items.len < @max(min_games, 1)) continue;
                const est = rf.get(gi, bracket, experience).?;
                const level = @intFromBool(experience != .any);
                const sigma2 = rf.params[@intFromEnum(bracket)][level][0][lane_minute - 1].sigma2;
                try curve(gpa, out, &scratch, subset.items, bracket, experience, est, sigma2);
                curves += 1;
            }
        }
    }
    return curves;
}

/// k (games to stabilise) at a few minutes and the split-half test, per metric
fn logFit(role: Role, rf: *const curvefit.RoleFit) void {
    const r = rf.report;
    for (std.enums.values(Metric), 0..) |m, mi| {
        const p = rf.params[0][0][mi];
        log.info("{t} {t}: sd/tau/k at 5 min {d:.0}/{d:.0}/{d:.0}, 10 min {d:.0}/{d:.0}/{d:.0}, 14 min {d:.0}/{d:.0}/{d:.0}, 20 min {d:.0}/{d:.0}/{d:.0}; lambda {d}", .{
            role,                m,
            @sqrt(p[4].sigma2),  @sqrt(p[4].tau2),
            p[4].k(),            @sqrt(p[9].sigma2),
            @sqrt(p[9].tau2),    p[9].k(),
            @sqrt(p[13].sigma2), @sqrt(p[13].tau2),
            p[13].k(),           @sqrt(p[19].sigma2),
            @sqrt(p[19].tau2),   p[19].k(),
            r.lambda[mi],
        });
        const t14 = lane_minute - 1;
        const nest = rf.params;
        log.info("{t} {t}: nested k at {d} min: Iron-Silver {d:.0}, Gold-Emerald {d:.0}, Diamond+ {d:.0}; experienced {d:.0} (tau {d:.0} {d:.0} {d:.0}; {d:.0})", .{
            role,                            m,                               lane_minute,
            nest[1][0][mi][t14].k(),         nest[2][0][mi][t14].k(),         nest[3][0][mi][t14].k(),
            nest[0][1][mi][t14].k(),         @sqrt(nest[1][0][mi][t14].tau2), @sqrt(nest[2][0][mi][t14].tau2),
            @sqrt(nest[3][0][mi][t14].tau2), @sqrt(nest[0][1][mi][t14].tau2),
        });
        const e = r.mse[mi];
        const t = r.mse_thick[mi];
        log.info("{t} {t}: split-half rms error at {d} min, {d} pairs: zero {d:.0} baseline {d:.0} raw {d:.0} shrunk {d:.0} smoothed {d:.0} (noise of the other half {d:.0}); {d} pairs with {d}+ games: zero {d:.0} baseline {d:.0} raw {d:.0} shrunk {d:.0} smoothed {d:.0} (noise {d:.0})", .{
            role,        m,                        curvefit.report_minute, r.scored[mi],
            @sqrt(e[0]), @sqrt(e[1]),              @sqrt(e[2]),            @sqrt(e[3]),
            @sqrt(e[4]), @sqrt(r.noise[mi]),       r.scored_thick[mi],     curvefit.thick_games,
            @sqrt(t[0]), @sqrt(t[1]),              @sqrt(t[2]),            @sqrt(t[3]),
            @sqrt(t[4]), @sqrt(r.noise_thick[mi]),
        });
    }
}

/// The role's baseline per bracket: each lane from both sides, so the buckets are
/// symmetric and games count every laner. Minutes hold the role's spread: n lanes
/// times two and quartiles of the differences from both sides (median 0)
fn baselines(
    gpa: std.mem.Allocator,
    out: *std.ArrayList(u8),
    lanes: []const Lane,
    min_games: u32,
) !u32 {
    // Counts of |difference| per metric and minute
    const hist = try gpa.alloc([1 << 15]u32, metrics * max_minutes);
    defer gpa.free(hist);
    var n: u32 = 0;
    for (std.enums.values(Bracket)) |bracket| {
        var h = emptyHeader(lanes[0].role, bracket, .any, 0, 0);
        for (hist) |*x| @memset(x, 0);
        var going: [max_minutes]u32 = @splat(0);
        for (lanes) |l| {
            if (bracket != .all and l.bracket != bracket) continue;
            h.games += 2;
            h.a_wins += 1;
            for (comeback_minutes, 0..) |m, mi| {
                if (l.minutes < m) continue;
                const gold = l.gold[m - 1];
                const won: u32 = @intFromBool(l.a_won);
                h.comeback[mi][bucket(gold)].games += 1;
                h.comeback[mi][bucket(gold)].wins += won;
                h.comeback[mi][bucket(-gold)].games += 1;
                h.comeback[mi][bucket(-gold)].wins += 1 - won;
            }
            for (0..l.minutes) |i| {
                going[i] += 1;
                hist[0 * max_minutes + i][@min(@abs(l.gold[i]), (1 << 15) - 1)] += 1;
                hist[1 * max_minutes + i][@min(@abs(l.xp[i]), (1 << 15) - 1)] += 1;
                hist[2 * max_minutes + i][@min(@abs(l.cs[i]), (1 << 15) - 1)] += 1;
            }
        }
        if (h.games / 2 < @max(min_games, 1)) continue;
        try out.appendSlice(gpa, std.mem.asBytes(&h));
        for (0..max_minutes) |i| {
            var m: Minute = .{ .n = 2 * going[i], .gold = .{}, .xp = .{}, .cs = .{} };
            inline for (.{ "gold", "xp", "cs" }, 0..) |field, mi| {
                // Both sides: the 75th percentile is the median of |difference|
                const p75 = medianOfCounts(&hist[mi * max_minutes + i], going[i]);
                @field(m, field) = .{ .p25 = -p75, .p50 = 0, .p75 = p75 };
            }
            try out.appendSlice(gpa, std.mem.asBytes(&m));
        }
        n += 1;
    }
    return n;
}

/// Nearest-rank median of `total` values counted by value
fn medianOfCounts(counts: *const [1 << 15]u32, total: u32) i16 {
    if (total == 0) return 0;
    const rank = (total + 1) / 2;
    var seen: u32 = 0;
    for (counts, 0..) |c, v| {
        seen += c;
        if (seen >= rank) return @intCast(v);
    }
    unreachable;
}

fn emptyHeader(role: Role, bracket: Bracket, experience: Experience, a: u32, b: u32) Header {
    return .{
        .role = @intFromEnum(role),
        .bracket = @intFromEnum(bracket),
        .experience = @intFromEnum(experience),
        .a = a,
        .b = b,
        .games = 0,
        .a_wins = 0,
        .lane_games = 0,
        .lane_a = 0,
        .lane_b = 0,
        .a_wins_lane_a = 0,
        .b_wins_lane_b = 0,
        .a_kills_b = @splat(0),
        .b_kills_a = @splat(0),
        .level6_a = 0,
        .level6_b = 0,
        .first_item_a = 0,
        .first_item_b = 0,
        .own = 0,
        .comeback = @splat(@splat(.{})),
    };
}

/// `est` from curvefit; `sigma2` the game-to-game variance of gold at lane_minute at
/// this curve's level, for its own share
fn curve(
    gpa: std.mem.Allocator,
    out: *std.ArrayList(u8),
    scratch: *std.ArrayList(i16),
    lanes: []const Lane,
    bracket: Bracket,
    experience: Experience,
    est: *const curvefit.Est,
    sigma2: f32,
) !void {
    var h = emptyHeader(lanes[0].role, bracket, experience, lanes[0].a, lanes[0].b);
    h.games = @intCast(lanes.len);
    for (lanes) |l| {
        h.a_wins += @intFromBool(l.a_won);
        for (comeback_minutes, 0..) |m, mi| {
            if (l.minutes < m) continue;
            const c = &h.comeback[mi][bucket(l.gold[m - 1])];
            c.games += 1;
            c.wins += @intFromBool(l.a_won);
        }
        for (0..phases) |p| {
            h.a_kills_b[p] += @intFromBool(l.a_kills_b[p]);
            h.b_kills_a[p] += @intFromBool(l.b_kills_a[p]);
        }
        if (l.minutes < lane_minute) continue;
        h.lane_games += 1;
        const gold = l.gold[lane_minute - 1];
        if (gold > 0) {
            h.lane_a += 1;
            h.a_wins_lane_a += @intFromBool(l.a_won);
        } else if (gold < 0) {
            h.lane_b += 1;
            h.b_wins_lane_b += @intFromBool(!l.a_won);
        }
    }
    h.level6_a = try medianSeconds(gpa, lanes, "level6_a");
    h.level6_b = try medianSeconds(gpa, lanes, "level6_b");
    h.first_item_a = try medianSeconds(gpa, lanes, "first_item_a");
    h.first_item_b = try medianSeconds(gpa, lanes, "first_item_b");
    const at = est[0][lane_minute - 1];
    // n / (n + k) = n var / sigma^2 for the posterior variance var = sigma^2 / (n + k)
    h.own = if (sigma2 > 0)
        @intFromFloat(std.math.clamp(@round(1000 * at.n * at.@"var" / sigma2), 0, 1000))
    else if (at.n > 0) 1000 else 0;
    try out.appendSlice(gpa, std.mem.asBytes(&h));

    for (0..max_minutes) |i| {
        var m: Minute = .{ .n = 0, .gold = undefined, .xp = undefined, .cs = undefined };
        inline for (.{ "gold", "xp", "cs" }) |field| {
            scratch.clearRetainingCapacity();
            for (lanes) |l| if (l.minutes > i) try scratch.append(gpa, @field(l, field)[i]);
            @field(m, field) = quartiles(scratch.items);
        }
        m.n = @intCast(scratch.items.len);
        if (m.n > 0) for (&m.est, est) |*e, points| {
            const p = points[i];
            e.* = .{ .mean = clampI16(p.mean), .se = @intFromFloat(std.math.clamp(@round(@sqrt(p.@"var")), 0, 65535)) };
        };
        try out.appendSlice(gpa, std.mem.asBytes(&m));
    }
}

fn clampI16(x: f32) i16 {
    return @intFromFloat(std.math.clamp(@round(x), std.math.minInt(i16), std.math.maxInt(i16)));
}

/// Median of a seconds field over the lanes that reached it (0 = never)
fn medianSeconds(gpa: std.mem.Allocator, lanes: []const Lane, comptime field: []const u8) !u16 {
    var times: std.ArrayList(u16) = .empty;
    defer times.deinit(gpa);
    for (lanes) |l| if (@field(l, field) > 0) try times.append(gpa, @field(l, field));
    // When most never got there, a median of the rest says little
    if (times.items.len * 2 < lanes.len) return 0;
    std.mem.sort(u16, times.items, {}, std.sort.asc(u16));
    return times.items[times.items.len / 2];
}

/// Nearest rank (the value at rank ceil(q n)); sorts `values`. Zeros when empty
fn quartiles(values: []i16) Quartiles {
    const n = values.len;
    if (n == 0) return .{ .p25 = 0, .p50 = 0, .p75 = 0 };
    std.mem.sort(i16, values, {}, std.sort.asc(i16));
    return .{
        .p25 = values[(n + 3) / 4 - 1],
        .p50 = values[(n + 1) / 2 - 1],
        .p75 = values[(3 * n + 3) / 4 - 1],
    };
}

pub const Curve = struct {
    header: Header,
    minutes: []const Minute,
};

/// A parsed curves file. Owns its arrays; does not borrow the bytes.
pub const Curves = struct {
    patch_buf: [patch_len]u8,
    patch_len: usize,
    games: u32,
    fit: *Fit,
    curves: []Curve,
    minutes: []Minute,

    pub const ParseError = error{
        BadMagic,
        UnsupportedVersion,
        Truncated,
        SizeMismatch,
        TooManyCurves,
        OutOfMemory,
    };

    pub fn parse(gpa: std.mem.Allocator, bytes: []const u8) ParseError!Curves {
        if (bytes.len < header_len) return error.Truncated;
        if (!std.mem.eql(u8, bytes[0..magic.len], magic)) return error.BadMagic;
        var r: std.Io.Reader = .fixed(bytes[magic.len..]);
        const ver = r.takeInt(u32, .little) catch unreachable;
        if (ver != version) return error.UnsupportedVersion;
        const m = r.takeInt(u32, .little) catch unreachable;
        if (m != max_minutes) return error.UnsupportedVersion;
        const games = r.takeInt(u32, .little) catch unreachable;
        const k = r.takeInt(u32, .little) catch unreachable;
        if (k > max_curves) return error.TooManyCurves;
        if (bytes.len < header_len + @sizeOf(Fit)) return error.Truncated;
        const fit = try gpa.create(Fit);
        errdefer gpa.destroy(fit);
        fit.* = std.mem.bytesToValue(Fit, bytes[header_len..][0..@sizeOf(Fit)]);
        var c: Curves = .{
            .patch_buf = undefined,
            .patch_len = 0,
            .games = games,
            .fit = fit,
            .curves = &.{},
            .minutes = &.{},
        };
        @memcpy(&c.patch_buf, bytes[header_len - patch_len ..][0..patch_len]);
        c.patch_len = std.mem.indexOfScalar(u8, &c.patch_buf, 0) orelse patch_len;

        const per_curve = @sizeOf(Header) + m * @sizeOf(Minute);
        const body = bytes[header_len + @sizeOf(Fit) ..];
        if (body.len < k * per_curve) return error.Truncated;
        if (body.len > k * per_curve) return error.SizeMismatch;
        c.curves = try gpa.alloc(Curve, k);
        errdefer gpa.free(c.curves);
        c.minutes = try gpa.alloc(Minute, k * m);
        for (c.curves, 0..) |*cv, i| {
            const at = body[i * per_curve ..];
            cv.header = std.mem.bytesToValue(Header, at[0..@sizeOf(Header)]);
            const mins = c.minutes[i * m ..][0..m];
            @memcpy(std.mem.sliceAsBytes(mins), at[@sizeOf(Header)..][0 .. m * @sizeOf(Minute)]);
            cv.minutes = mins;
        }
        return c;
    }

    pub fn deinit(c: *Curves, gpa: std.mem.Allocator) void {
        gpa.destroy(c.fit);
        gpa.free(c.curves);
        gpa.free(c.minutes);
        c.* = undefined;
    }

    pub fn patch(c: *const Curves) []const u8 {
        return c.patch_buf[0..c.patch_len];
    }

    /// The estimation's variance parameters for `role`'s curves in `bracket`, all
    /// games or experienced only, at minute index `i`
    pub fn param(c: *const Curves, role: Role, bracket: Bracket, experienced: bool, metric: Metric, i: usize) curvefit.Param {
        return c.fit.params[@intFromEnum(role)][@intFromEnum(bracket)][@intFromBool(experienced)][@intFromEnum(metric)][i];
    }

    /// `me` against `them` in `role`, seen from `me`'s side, all games; null when the
    /// file has too few games for it
    pub fn get(c: *const Curves, role: Role, bracket: Bracket, me: u32, them: u32) ?View {
        return c.find(role, bracket, .any, me, them);
    }

    /// As get, counting only games where `me` is experienced on their champion
    pub fn getExperienced(c: *const Curves, role: Role, bracket: Bracket, me: u32, them: u32) ?View {
        return c.find(role, bracket, if (me <= them) .a else .b, me, them);
    }

    /// Every lane of `role` from both sides (comeback counts only); null when too few
    pub fn baseline(c: *const Curves, role: Role, bracket: Bracket) ?View {
        return c.find(role, bracket, .any, 0, 0);
    }

    fn find(c: *const Curves, role: Role, bracket: Bracket, experience: Experience, me: u32, them: u32) ?View {
        const Key = struct { role: u8, a: u32, b: u32, bracket: u8, experience: u8 };
        const a = @min(me, them);
        const key: Key = .{
            .role = @intFromEnum(role),
            .a = a,
            .b = @max(me, them),
            .bracket = @intFromEnum(bracket),
            .experience = @intFromEnum(experience),
        };
        const i = std.sort.binarySearch(Curve, c.curves, key, struct {
            fn order(k: Key, cv: Curve) std.math.Order {
                const h = cv.header;
                if (k.role != h.role) return std.math.order(k.role, h.role);
                if (k.a != h.a) return std.math.order(k.a, h.a);
                if (k.b != h.b) return std.math.order(k.b, h.b);
                if (k.bracket != h.bracket) return std.math.order(k.bracket, h.bracket);
                return std.math.order(k.experience, h.experience);
            }
        }.order) orelse return null;
        return .{ .curve = &c.curves[i], .flipped = me != a };
    }
};

/// A curve from one champion's side ("me")
pub const View = struct {
    curve: *const Curve,
    flipped: bool,

    pub fn games(v: View) u32 {
        return v.curve.header.games;
    }

    pub fn wins(v: View) u32 {
        const h = v.curve.header;
        return if (v.flipped) h.games - h.a_wins else h.a_wins;
    }

    pub const Lane = struct {
        games: u32,
        ahead: u32,
        behind: u32,
        wins_ahead: u32,
        wins_behind: u32,
    };

    pub fn lane(v: View) View.Lane {
        const h = v.curve.header;
        const lane_a: View.Lane = .{
            .games = h.lane_games,
            .ahead = h.lane_a,
            .behind = h.lane_b,
            .wins_ahead = h.a_wins_lane_a,
            .wins_behind = h.lane_b - h.b_wins_lane_b,
        };
        if (!v.flipped) return lane_a;
        return .{
            .games = h.lane_games,
            .ahead = h.lane_b,
            .behind = h.lane_a,
            .wins_ahead = h.b_wins_lane_b,
            .wins_behind = h.lane_a - h.a_wins_lane_a,
        };
    }

    /// Games where I took part in killing them in `phase`
    pub fn kills(v: View, phase: usize) u32 {
        const h = v.curve.header;
        return if (v.flipped) h.b_kills_a[phase] else h.a_kills_b[phase];
    }

    pub fn deaths(v: View, phase: usize) u32 {
        const h = v.curve.header;
        return if (v.flipped) h.a_kills_b[phase] else h.b_kills_a[phase];
    }

    /// Median seconds to level 6 for me and them; 0 when unknown
    pub fn level6(v: View) [2]u16 {
        const h = v.curve.header;
        return if (v.flipped) .{ h.level6_b, h.level6_a } else .{ h.level6_a, h.level6_b };
    }

    /// Games and my wins when my lane gold lead at `at` fell in `b` (0 = behind
    /// 1500+ ... 4 = ahead 1500+)
    pub fn comeback(v: View, at: Comeback, b: usize) Counts {
        const row = v.curve.header.comeback[@intFromEnum(at)];
        if (!v.flipped) return row[b];
        const c = row[buckets - 1 - b];
        return .{ .games = c.games, .wins = c.games - c.wins };
    }

    /// Median seconds to the first finished item for me and them; 0 when unknown
    pub fn firstItem(v: View) [2]u16 {
        const h = v.curve.header;
        const both: [2]u16 = .{ h.first_item_a, h.first_item_b };
        return if (v.flipped) .{ both[1], both[0] } else both;
    }

    pub fn minutes(v: View) usize {
        return v.curve.minutes.len;
    }

    /// Minute i (frame at i + 1 minutes), diffs as me minus them
    pub fn minute(v: View, i: usize) Minute {
        const m = v.curve.minutes[i];
        if (!v.flipped) return m;
        var est = m.est;
        for (&est) |*e| e.mean = -e.mean;
        return .{ .n = m.n, .gold = neg(m.gold), .xp = neg(m.xp), .cs = neg(m.cs), .est = est };
    }

    /// Estimated mean of `metric` at minute i, me minus them, and its standard error
    pub fn estimate(v: View, metric: Metric, i: usize) Estimate {
        return v.minute(i).est[@intFromEnum(metric)];
    }

    /// Share of the gold estimate at lane_minute from this matchup's own games, 0..1;
    /// under a half it is mostly the champions' baseline
    pub fn own(v: View) f64 {
        return @as(f64, @floatFromInt(v.curve.header.own)) / 1000;
    }

    fn neg(q: Quartiles) Quartiles {
        return .{ .p25 = -q.p75, .p50 = -q.p50, .p75 = -q.p25 };
    }
};

const testing = std.testing;

fn testLane(a: u32, b: u32, a_won: bool, gold_at: i16, bracket: ?Bracket) Lane {
    var l: Lane = .{
        .role = .top,
        .bracket = bracket,
        .a = a,
        .b = b,
        .a_won = a_won,
        .minutes = 20,
    };
    for (0..20) |i| {
        const t: i16 = @intCast(i + 1);
        l.gold[i] = @divTrunc(gold_at * t, lane_minute);
        l.xp[i] = t * 10;
        l.cs[i] = 1;
    }
    l.a_kills_b[0] = gold_at > 0;
    l.level6_a = 360;
    l.level6_b = 420;
    l.first_item_a = 900;
    l.experienced_a = gold_at > 0;
    return l;
}

test "round trip, sides and brackets" {
    const gpa = testing.allocator;
    var b: Builder = .{ .gpa = gpa };
    defer b.deinit();
    // Darius (122) vs Garen (86) seen from Darius: Darius leads at 14 in 3 of 4
    try b.addLane(testLane(122, 86, true, 700, .low));
    try b.addLane(testLane(122, 86, true, 300, .low));
    try b.addLane(testLane(122, 86, false, 100, .high));
    try b.addLane(testLane(122, 86, true, -500, null));
    // Too few games for a curve
    try b.addLane(testLane(1, 2, true, 0, .mid));
    for (0..5) |_| b.addGame();

    var aw: std.Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();
    try b.write(&aw.writer, "16.20", 2);
    var c: Curves = try .parse(gpa, aw.written());
    defer c.deinit(gpa);
    try testing.expectEqualStrings("16.20", c.patch());
    try testing.expectEqual(5, c.games);
    // all + low, each also with Darius experienced; role baselines for all and low
    try testing.expectEqual(6, c.curves.len);
    try testing.expect(c.get(.top, .all, 1, 2) == null);
    try testing.expect(c.get(.top, .high, 122, 86) == null);
    try testing.expect(c.get(.jungle, .all, 122, 86) == null);

    const darius = c.get(.top, .all, 122, 86).?;
    try testing.expect(darius.flipped);
    try testing.expectEqual(4, darius.games());
    try testing.expectEqual(3, darius.wins());
    const lane = darius.lane();
    const want: View.Lane = .{ .games = 4, .ahead = 3, .behind = 1, .wins_ahead = 2, .wins_behind = 1 };
    try testing.expectEqual(want, lane);
    try testing.expectEqual(3, darius.kills(0));
    try testing.expectEqual(0, darius.deaths(0));
    try testing.expectEqual([2]u16{ 360, 420 }, darius.level6());
    const m14 = darius.minute(lane_minute - 1);
    try testing.expectEqual(4, m14.n);
    try testing.expectEqual(Quartiles{ .p25 = 100, .p50 = 300, .p75 = 700 }, m14.gold);
    try testing.expectEqual(0, darius.minute(20).n);

    const garen = c.get(.top, .all, 86, 122).?;
    try testing.expect(!garen.flipped);
    try testing.expectEqual(1, garen.wins());
    const garen_gold: Quartiles = .{ .p25 = -700, .p50 = -300, .p75 = -100 };
    try testing.expectEqual(garen_gold, garen.minute(lane_minute - 1).gold);
    try testing.expectEqual(1, garen.lane().ahead);
    try testing.expectEqual([2]u16{ 420, 360 }, garen.level6());

    // At 15 min Darius leads by 750, 321, 107 and trails by 535; won all but the 107
    try testing.expectEqual(Counts{ .games = 1, .wins = 1 }, darius.comeback(.fifteen, 3));
    try testing.expectEqual(Counts{ .games = 2, .wins = 1 }, darius.comeback(.fifteen, 2));
    try testing.expectEqual(Counts{ .games = 1, .wins = 1 }, darius.comeback(.fifteen, 1));
    try testing.expectEqual(Counts{ .games = 4, .wins = 3 }, darius.comeback(.ten, 2));
    const base = c.baseline(.top, .all).?;
    try testing.expectEqual(10, base.games());
    try testing.expectEqual(Counts{ .games = 6, .wins = 3 }, base.comeback(.fifteen, 2));
    try testing.expectEqual(Counts{ .games = 2, .wins = 1 }, base.comeback(.fifteen, 1));
    try testing.expect(c.baseline(.jungle, .all) == null);
    // Baseline minutes: every lane from both sides, quartiles symmetric
    const bm = base.minute(lane_minute - 1);
    try testing.expectEqual(10, bm.n);
    try testing.expectEqual(0, bm.gold.p50);
    try testing.expectEqual(-bm.gold.p25, bm.gold.p75);

    // Estimates flip with the side; the fit is in the file
    const de = darius.estimate(.gold, lane_minute - 1);
    try testing.expectEqual(-de.mean, garen.estimate(.gold, lane_minute - 1).mean);
    try testing.expect(de.se > 0);
    try testing.expect(darius.own() > 0 and darius.own() <= 1);
    try testing.expect(c.param(.top, .all, false, .gold, lane_minute - 1).sigma2 > 0);

    const low = c.get(.top, .low, 122, 86).?;
    try testing.expectEqual(2, low.games());

    const experienced = c.getExperienced(.top, .all, 122, 86).?;
    try testing.expectEqual(3, experienced.games());
    try testing.expect(experienced.flipped);
    try testing.expectEqual([2]u16{ 900, 0 }, experienced.firstItem());
    try testing.expect(c.getExperienced(.top, .all, 86, 122) == null);
    try testing.expectEqual([2]u16{ 0, 900 }, garen.firstItem());

    const bytes = aw.written();
    try testing.expectError(error.Truncated, Curves.parse(gpa, bytes[0 .. bytes.len - 1]));
}
