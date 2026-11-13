//! `effects --a10 1` (docs/plan/lab-frontier.md A10 (a) and D1, rules in docs/model.md
//! "A10 (a): strength shrinks to a line in log share"): the additive model's free
//! continuous slots, per block from its fit games only.
//!   1: x = ln(champion-role's fit games / its role's), blue minus red summed over roles,
//!      so each champion-role's strength shrinks to a line in x, not 0 (Meio's lesson:
//!      rare off-role picks lose)
//!   2: the line's hinge min(0, x - knot) (Meio's pop_knot): the rarest lose more
//!   3: seat log mastery (lanecard.Expertise.feature), unknown seats at their
//!      champion-role's mean among fetched fit seats, so strength is at m = 0
//! Also the per-game slice file and the pick metric for additive fits

const std = @import("std");
const api = @import("api");
const rows = @import("rows.zig");
const A = @import("../additive.zig");
const addinputs = @import("addinputs.zig");
const mastery_pre = @import("mastery_pre.zig");
const lanecard = @import("../lanecard.zig");

const Io = std.Io;

pub const slot_line = 1;
pub const slot_hinge = 2;
pub const slot_mastery = 3;
/// Meio's pop_knot (src/meio.zig)
pub const knot = -10.0;
/// A champion-role the fit never saw counts this many games
const unseen_games = 0.5;
/// Champion-role mean mastery shrunk to the role's by this many fetched seats (D1)
const mastery_shrink = 50.0;
/// Pick metric candidates: the role's champions with this many fit games (eval's)
pub const candidate_games = 10;
/// Pick metric on 1 scored game in this many
pub const pick_every = 8;

const key = api.cellKey;

/// Seat log mastery per row from SNAP/mastery_pre.tsv (pre-game fetches), NaN unknown
pub fn loadMastery(gpa: std.mem.Allocator, io: Io, snap: []const u8, d: *const rows.Data) ![]f32 {
    var game_of: std.StringHashMapUnmanaged(u32) = .empty;
    defer game_of.deinit(gpa);
    try game_of.ensureTotalCapacity(gpa, @intCast(d.games.len));
    for (d.games, 0..) |g, i| game_of.putAssumeCapacity(g.match_id, @intCast(i));
    // game << 4 | slot -> row
    var row_of: std.AutoHashMapUnmanaged(u64, u32) = .empty;
    defer row_of.deinit(gpa);
    try row_of.ensureTotalCapacity(gpa, @intCast(d.rows.len));
    for (d.rows, 0..) |r, i| row_of.putAssumeCapacity(@as(u64, r.game) << 4 | r.slot, @intCast(i));
    const out = try gpa.alloc(f32, d.rows.len);
    @memset(out, std.math.nan(f32));
    const path = try std.fs.path.join(gpa, &.{ snap, mastery_pre.file_name });
    defer gpa.free(path);
    const text = try Io.Dir.cwd().readFileAlloc(io, path, gpa, .limited(4 << 30));
    defer gpa.free(text);
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    _ = lines.next();
    while (lines.next()) |line| {
        var it = std.mem.splitScalar(u8, line, '\t');
        const match_id = it.next() orelse return error.MasteryFormat;
        const slot = try std.fmt.parseInt(u8, it.next() orelse return error.MasteryFormat, 10);
        _ = it.next() orelse return error.MasteryFormat;
        _ = it.next() orelse return error.MasteryFormat;
        const points = try std.fmt.parseInt(u32, it.next() orelse return error.MasteryFormat, 10);
        const gi = game_of.get(match_id) orelse continue;
        const ri = row_of.get(@as(u64, gi) << 4 | slot) orelse continue;
        out[ri] = @floatCast(lanecard.Expertise.feature(points));
    }
    return out;
}

/// One block's line and mastery inputs, from its fit games
pub const Block = struct {
    games: std.AutoHashMapUnmanaged(u64, f64) = .empty,
    role_games: [A.n_role]f64 = @splat(0),
    /// Champion-role mean m, shrunk to the role's
    m_mean: std.AutoHashMapUnmanaged(u64, f64) = .empty,
    role_m: [A.n_role]f64 = @splat(0),

    pub fn init(gpa: std.mem.Allocator, d: *const rows.Data, is_fit: []const bool, m: []const f32) !Block {
        var b: Block = .{};
        errdefer b.deinit(gpa);
        var acc: std.AutoHashMapUnmanaged(u64, [2]f64) = .empty;
        defer acc.deinit(gpa);
        var role_acc: [A.n_role][2]f64 = @splat(@splat(0));
        for (d.rows, m) |r, mv| {
            if (!is_fit[r.game]) continue;
            const role: usize = @backingInt(r.role);
            const k = key(r.champion, role);
            (try b.games.getOrPutValue(gpa, k, 0)).value_ptr.* += 1;
            b.role_games[role] += 1;
            if (std.math.isNan(mv)) continue;
            const e = try acc.getOrPutValue(gpa, k, .{ 0, 0 });
            e.value_ptr[0] += mv;
            e.value_ptr[1] += 1;
            role_acc[role][0] += mv;
            role_acc[role][1] += 1;
        }
        for (&b.role_m, role_acc) |*x, a| x.* = if (a[1] > 0) a[0] / a[1] else 0;
        var it = acc.iterator();
        while (it.next()) |e| {
            const rm = b.role_m[@intCast(e.key_ptr.* & 7)];
            try b.m_mean.put(gpa, e.key_ptr.*, (e.value_ptr[0] + mastery_shrink * rm) / (e.value_ptr[1] + mastery_shrink));
        }
        return b;
    }

    pub fn deinit(b: *Block, gpa: std.mem.Allocator) void {
        b.games.deinit(gpa);
        b.m_mean.deinit(gpa);
    }

    pub fn fitGames(b: *const Block, champion: u32, role: usize) f64 {
        return b.games.get(key(champion, role)) orelse 0;
    }

    pub fn logShare(b: *const Block, champion: u32, role: usize) f64 {
        const n = b.games.get(key(champion, role)) orelse unseen_games;
        return @log(n / @max(b.role_games[role], 1));
    }

    /// Slots 1 and 2 from the teams alone
    pub fn fillLine(b: *const Block, g: *A.GameIn) void {
        var line: f64 = 0;
        var hinge: f64 = 0;
        for (0..2) |s| for (0..A.n_role) |r| {
            const x = b.logShare(g.teams[s][r], r);
            const sign: f64 = if (s == 0) 1 else -1;
            line += sign * x;
            hinge += sign * @min(0, x - knot);
        };
        g.cont[slot_line] = @floatCast(line);
        g.cont[slot_hinge] = @floatCast(hinge);
    }

    /// Slots 1-3 for game gi (its rows give the seats' mastery)
    pub fn fill(b: *const Block, d: *const rows.Data, in: addinputs.Inputs, m: []const f32, gi: usize, g: *A.GameIn) void {
        b.fillLine(g);
        var sum: f64 = 0;
        for (in.by_game[in.first_row[gi]..in.first_row[gi + 1]]) |ri| {
            const r = &d.rows[ri];
            const role: usize = @backingInt(r.role);
            const mv: f64 = if (std.math.isNan(m[ri])) b.m_mean.get(key(r.champion, role)) orelse b.role_m[role] else m[ri];
            sum += if (r.side == 0) mv else -mv;
        }
        g.cont[slot_mastery] = @floatCast(sum);
    }

    /// Per role, the champions with candidate_games+ fit games, ascending
    pub fn candidates(b: *const Block, gpa: std.mem.Allocator) ![A.n_role][]u32 {
        var lists: [A.n_role]std.ArrayList(u32) = @splat(.empty);
        var it = b.games.iterator();
        while (it.next()) |e| if (e.value_ptr.* >= candidate_games) {
            const role: usize = @intCast(e.key_ptr.* & 7);
            try lists[role].append(gpa, @intCast(e.key_ptr.* >> 3));
        };
        var out: [A.n_role][]u32 = undefined;
        for (&out, &lists) |*o, *l| {
            std.mem.sortUnstable(u32, l.items, {}, std.sort.asc(u32));
            o.* = try l.toOwnedSlice(gpa);
        }
        return out;
    }
};

/// The rank bracket of a game from its seats' rank_start (lab's fillRankStart: the ladder
/// rank before the game's day, never the stored tier): the median of the known, with 6+
/// known. 0 Iron-Silver, 1 Gold-Emerald, 2 Diamond+, 3 unknown
pub fn bracket(d: *const rows.Data, in: addinputs.Inputs, gi: usize) u8 {
    var ranks: [10]u8 = undefined;
    var n: usize = 0;
    for (in.by_game[in.first_row[gi]..in.first_row[gi + 1]]) |ri| if (d.rows[ri].rank_start) |rk| {
        ranks[n] = rk;
        n += 1;
    };
    if (n < 6) return 3;
    std.mem.sortUnstable(u8, ranks[0..n], {}, std.sort.asc(u8));
    const med = if (n % 2 == 1) @as(f64, @floatFromInt(ranks[n / 2])) else (@as(f64, @floatFromInt(ranks[n / 2 - 1])) + @as(f64, @floatFromInt(ranks[n / 2]))) / 2;
    return if (med < 12) 0 else if (med < 24) 1 else 2;
}

pub const bracket_names = [_][]const u8{ "iron-silver", "gold-emerald", "diamond+", "unknown" };

/// Fewest fit games among the game's ten champion-roles
pub fn minFitGames(b: *const Block, g: *const A.GameIn) f64 {
    var lo: f64 = std.math.inf(f64);
    for (0..2) |s| for (0..A.n_role) |r| {
        lo = @min(lo, b.fitGames(g.teams[s][r], r));
    };
    return lo;
}

/// Blue's damage mix minus red's from the teams alone (scored games' form: no row left
/// out), for a swapped pick
pub fn mixOfTeams(mix: *const addinputs.Mix, teams: *const [2][A.n_role]u32) f32 {
    var out: [2]f64 = undefined;
    for (0..2) |s| {
        var num: f64 = 0;
        var den: f64 = 0;
        for (0..A.n_role) |r| {
            const p = mix.profile(teams[s][r], r, null);
            num += p[1] * p[0];
            den += p[1];
        }
        const frac = if (den > 0) num / den else 0.5;
        out[s] = (frac - 0.5) * (frac - 0.5);
    }
    return @floatCast(out[0] - out[1]);
}

/// Pick metric for one additive fit: per scored game, side and role (game-major), the
/// percentile of the real pick among the role's candidates by the model's logit for that
/// side (1 the model's top), the other nine kept; NaN when the real pick isn't a
/// candidate. Candidates already in the game are skipped
pub fn pickPercentiles(
    p: *const A.Problem,
    f: *const A.Fit,
    b: *const Block,
    mix: *const addinputs.Mix,
    cands: *const [A.n_role][]u32,
    games: []const A.GameIn,
    out: []f32,
) void {
    std.debug.assert(out.len == games.len * 2 * A.n_role);
    for (games, 0..) |g0, gi| for (0..2) |s| for (0..A.n_role) |r| {
        const real = g0.teams[s][r];
        var real_score: ?f64 = null;
        var above: f64 = 0;
        var ties: f64 = 0;
        var n: f64 = 0;
        const sign: f64 = if (s == 0) 1 else -1;
        // Two passes: the real pick's score first, then rank against it
        for (0..2) |pass| for (cands[r]) |c| {
            if (c != real and inGame(&g0.teams, c)) continue;
            if (pass == 0 and c != real) continue;
            var g = g0;
            g.teams[s][r] = c;
            g.cont[0] = mixOfTeams(mix, &g.teams);
            b.fillLine(&g);
            const v = sign * A.predict(p, f, &g);
            if (pass == 0) {
                real_score = v;
                continue;
            }
            n += 1;
            if (c == real) continue;
            if (v > real_score.?) above += 1 else if (v == real_score.?) ties += 1;
        };
        const at = (gi * 2 + s) * A.n_role + r;
        out[at] = if (real_score == null or n < 2) std.math.nan(f32) else @floatCast(1 - (above + ties / 2) / (n - 1));
    };
}

fn inGame(teams: *const [2][A.n_role]u32, c: u32) bool {
    for (teams) |t| for (t) |x| if (x == c) return true;
    return false;
}

test "a10 line: blue minus red log shares, hinge below the knot" {
    const gpa = std.testing.allocator;
    var b: Block = .{};
    defer b.deinit(gpa);
    b.role_games = @splat(1000);
    try b.games.put(gpa, key(1, 0), 500);
    try b.games.put(gpa, key(2, 0), 1);
    var g: A.GameIn = .{ .teams = .{ .{ 1, 3, 3, 3, 3 }, .{ 2, 3, 3, 3, 3 } }, .platform = 0, .y = 1 };
    b.fillLine(&g);
    try std.testing.expectApproxEqAbs(@log(500.0), g.cont[slot_line], 1e-4);
    // ln(1/1000) = -6.9, above the knot: no hinge on either side
    try std.testing.expectApproxEqAbs(0, g.cont[slot_hinge], 1e-6);
    b.role_games[0] = 1e6;
    b.fillLine(&g);
    // red's ln(1e-6) = -13.8: hinge -3.8, blue's ln(5e-4) none; blue minus red +3.8
    try std.testing.expectApproxEqAbs(-(@log(1e-6) - knot), g.cont[slot_hinge], 1e-3);
}
