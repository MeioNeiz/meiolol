//! Ban impact (J20): lolalytics' PBI with the win rate pulled toward the role's average,
//! so a thin champion's lucky edge can't count in full (research/questions/
//! ban-impact-score.md). Win rate edge over the role's average, times how often it is
//! picked in games where it was not banned. Per champion and role; the site's champions
//! table and, later, the picker's ban options (B3) use it

const std = @import("std");
const roles = @import("roles.zig");
const statsfile = @import("statsfile.zig");

const Role = roles.Role;
const Stats = statsfile.Stats;

/// The role's average win rate and k, the games that pull a champion's rate halfway to
/// it, from how much true champion win rates in the role differ (method of moments over
/// every champion, as the site's usualK). Once per role
pub const Prior = struct {
    base: f64,
    k: f64,

    pub fn of(st: *const Stats, r: Role) Prior {
        var wins: f64 = 0;
        var games: f64 = 0;
        for (0..st.n) |c| {
            const cr = st.champRole(r, c);
            wins += @floatFromInt(cr.wins);
            games += @floatFromInt(cr.games);
        }
        const base = if (games > 0) wins / games else 0.5;
        var q: f64 = 0;
        var noise: f64 = 0;
        for (0..st.n) |c| {
            const cr = st.champRole(r, c);
            if (cr.games == 0) continue;
            const g: f64 = @floatFromInt(cr.games);
            const d = @as(f64, @floatFromInt(cr.wins)) - g * base;
            q += d * d / g;
            noise += base * (1 - base);
        }
        const tau2 = std.math.clamp((q - noise) / @max(games, 1), 0.0001, 0.01);
        return .{ .base = base, .k = base * (1 - base) / tau2 };
    }

    /// The champion's win rate edge over base, pulled toward 0 by k games
    pub fn edge(p: Prior, wins: u32, games: u32) f64 {
        const n: f64 = @floatFromInt(games);
        return (@as(f64, @floatFromInt(wins)) - n * p.base) / (n + p.k);
    }

    /// Edge in points times pick rate in % of games it was available, as lolalytics'
    /// PBI's scale: (win - average) x 100 x pick / (100 - ban), rates in %. `picked`:
    /// games it was played in the role; `banned` and `total`: games it was banned in
    /// and all games, so picked / (total - banned) is its pick rate when available
    pub fn score(p: Prior, wins: u32, picked: u32, banned: u64, total: u64) f64 {
        if (banned >= total) return 0;
        const available: f64 = @floatFromInt(total - banned);
        return 1e4 * p.edge(wins, picked) * @as(f64, @floatFromInt(picked)) / available;
    }
};

test "score: lolalytics' scale, thin champions pulled in" {
    const p: Prior = .{ .base = 0.5, .k = 0 };
    // Cho'Gath on lolalytics 16.20: 53.48% won, 6.29% picked, 7.98% banned; their own
    // average put it at +1.97, PBI 12: 1.97 x 6.29 / 92.02 x 100 = 13.5 with ours
    const s = p.score(3269, 6290, 7980, 100_000);
    try std.testing.expectApproxEqAbs(13.47, s, 0.01);
    const shrunk: Prior = .{ .base = 0.5, .k = 600 };
    // 60% in 200 games: 10 points raw, 2.5 after shrinkage
    try std.testing.expectApproxEqAbs(0.025, shrunk.edge(120, 200), 1e-9);
    try std.testing.expectEqual(@as(f64, 0), shrunk.score(1, 2, 10, 10));
}
