//! Fit inputs of the additive draft model (src/additive.zig), shared by `effects` and
//! `draft --export --model additive` so the shipped model is the one evaluated: outcomes,
//! a game's rows, and win-comp's damage mix

const std = @import("std");
const api = @import("api");
const rows = @import("rows.zig");
const seatstats = @import("seatstats.zig");
const A = @import("../additive.zig");

/// win-comp's mix term (cand/win-comp teamForms): per champion-role, magic share of
/// champion damage and damage per minute, means over won and lost rows separately, each
/// shrunk to the role mean by `pseudo` rows, profile = the halves' average; a team's
/// damage-weighted magic share frac, mix = (frac - 0.5)^2. Fit games see their own rows
/// left out
pub const Mix = struct {
    const pseudo = 20;
    /// key -> [half][feature][sum, n]
    acc: std.AutoHashMapUnmanaged(u64, [2][2][2]f64) = .empty,
    role_mean: [A.n_role][2]f64 = @splat(@splat(0)),
    /// Blue won, per game (Inputs.win: shuffled under --shuffle)
    win: []const f32 = &.{},

    fn rowWon(m: *const Mix, r: *const rows.Row) bool {
        return (m.win[r.game] > 0.5) == (r.side == 0);
    }

    fn key(champion: u32, role: usize) u64 {
        return @as(u64, champion) << 3 | role;
    }

    /// Magic share and damage per minute of one row, NaN when unknown
    fn values(s: *const seatstats.Stats) [2]f32 {
        const at = struct {
            fn f(st: *const seatstats.Stats, x: seatstats.SeatStat) f32 {
                return st[@backingInt(x)];
            }
        }.f;
        const dealt = at(s, .dmg_phys) + at(s, .dmg_magic) + at(s, .dmg_true);
        const mins = at(s, .minutes);
        const nan = std.math.nan(f32);
        return .{
            if (dealt > 0) at(s, .dmg_magic) / dealt else nan,
            if (mins > 0) dealt / mins else nan,
        };
    }

    pub fn init(gpa: std.mem.Allocator, d: *const rows.Data, fit: []const bool, win: []const f32) !Mix {
        var m: Mix = .{ .win = win };
        var role_acc: [A.n_role][2][2]f64 = @splat(@splat(@splat(0)));
        for (d.rows) |*r| {
            if (!fit[r.game]) continue;
            const v = values(&r.stats);
            const role: usize = @backingInt(r.role);
            const e = try m.acc.getOrPutValue(gpa, key(r.champion, role), @splat(@splat(@splat(0))));
            const half: usize = @intFromBool(m.rowWon(r));
            for (0..2) |f| {
                if (std.math.isNan(v[f]) or std.math.isInf(v[f])) continue;
                e.value_ptr[half][f][0] += v[f];
                e.value_ptr[half][f][1] += 1;
                role_acc[role][f][0] += v[f];
                role_acc[role][f][1] += 1;
            }
        }
        for (&m.role_mean, role_acc) |*rm, ra| for (rm, ra) |*x, a| {
            x.* = if (a[1] > 0) a[0] / a[1] else 0;
        };
        return m;
    }

    pub fn deinit(m: *Mix, gpa: std.mem.Allocator) void {
        m.acc.deinit(gpa);
    }

    /// Profile of a champion-role; own: the row to leave out (a fit game's), else null
    pub fn profile(m: *const Mix, champion: u32, role: usize, own: ?*const rows.Row) [2]f64 {
        const rm = m.role_mean[role];
        const a = m.acc.get(key(champion, role)) orelse return rm;
        var drop: [2][2]f64 = @splat(@splat(0));
        var drop_n: [2][2]f64 = @splat(@splat(0));
        if (own) |r| {
            const v = values(&r.stats);
            const half: usize = @intFromBool(m.rowWon(r));
            for (0..2) |f| if (!std.math.isNan(v[f]) and !std.math.isInf(v[f])) {
                drop[half][f] = v[f];
                drop_n[half][f] = 1;
            };
        }
        var out: [2]f64 = undefined;
        for (0..2) |f| {
            var v: f64 = 0;
            for (0..2) |h| v += 0.5 * (a[h][f][0] - drop[h][f] + pseudo * rm[f]) / (a[h][f][1] - drop_n[h][f] + pseudo);
            out[f] = v;
        }
        return out;
    }

    /// Blue's mix minus red's for game gi; leave_out: the game is a fit game
    pub fn diff(m: *const Mix, d: *const rows.Data, in: Inputs, gi: usize, leave_out: bool) f32 {
        var num: [2]f64 = @splat(0);
        var den: [2]f64 = @splat(0);
        for (in.by_game[in.first_row[gi]..in.first_row[gi + 1]]) |ri| {
            const r = &d.rows[ri];
            const p = m.profile(r.champion, @backingInt(r.role), if (leave_out) r else null);
            num[r.side] += p[1] * p[0];
            den[r.side] += p[1];
        }
        var mix: [2]f64 = undefined;
        for (0..2) |s| {
            const frac = if (den[s] > 0) num[s] / den[s] else 0.5;
            mix[s] = (frac - 0.5) * (frac - 0.5);
        }
        return @floatCast(mix[0] - mix[1]);
    }
};

pub const Inputs = struct {
    win: []f32,
    /// Blue minus red team gold at 14, thousands; NaN unless all ten are known
    gold: []f32,
    /// Rows of game g: d.rows[by_game[first_row[g]..first_row[g + 1]]]
    first_row: []u32,
    by_game: []u32,
};

pub fn inputs(gpa: std.mem.Allocator, d: *const rows.Data) !Inputs {
    const win = try gpa.alloc(f32, d.games.len);
    const gold = try gpa.alloc(f32, d.games.len);
    const first_row = try gpa.alloc(u32, d.games.len + 1);
    @memset(gold, 0);
    for (d.games, win) |g, *w| w.* = if (g.winner == 0) 1 else 0;
    var seen = try gpa.alloc(u8, d.games.len);
    defer gpa.free(seen);
    @memset(seen, 0);
    for (d.rows) |r| {
        const y = r.y[api.outcomeIndex(.gold14)];
        gold[r.game] += if (r.side == 0) y / 1000 else -y / 1000;
        seen[r.game] += 1;
    }
    for (gold, seen) |*g, n| if (n != 10) {
        g.* = std.math.nan(f32);
    };
    // A game's rows by index, whatever order d.rows is in (counting sort)
    first_row[0] = 0;
    for (seen, 0..) |n, gi| first_row[gi + 1] = first_row[gi] + n;
    const by_game = try gpa.alloc(u32, d.rows.len);
    const next = try gpa.dupe(u32, first_row[0..d.games.len]);
    defer gpa.free(next);
    for (d.rows, 0..) |r, i| {
        by_game[next[r.game]] = @intCast(i);
        next[r.game] += 1;
    }
    return .{ .win = win, .gold = gold, .first_row = first_row, .by_game = by_game };
}

pub fn gameIn(d: *const rows.Data, gi: usize, y: f32, mix: f32) A.GameIn {
    const g = d.games[gi];
    return .{ .teams = g.teams, .platform = g.platform, .y = y, .cont = .{ mix, 0, 0, 0 } };
}

/// The full model's groups: champion strength, every ally block and the matchups (v2: the
/// 15 identified blocks, the shipped model; v1: the 25 enemy blocks); comp features from
/// `cont` (bit 0: the damage mix)
pub fn fullVariant(v2: bool, cont: u8) A.Variant {
    var v: A.Variant = .{ .cont = cont };
    for (A.g_main..A.g_ally) |g| v = v.with(g);
    if (v2) return v.matchupGroups();
    var all = A.Variant.all();
    all.cont = cont;
    return all;
}
