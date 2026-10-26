//! The champion page's trend helpers (stats.Trend): a champion's rank in its role on
//! each patch, and the length buckets' names

const std = @import("std");
const core = @import("core");
const root = @import("root.zig");
const stats = @import("../stats.zig");
const tierlist = @import("tierlist.zig");

const Role = core.Role;
const Counts = core.statsfile.Counts;
const Trend = stats.Trend;
const ratio = root.ratio;

/// Under each length bucket (stats.length_edges)
pub const length_labels = [stats.length_buckets][]const u8{ "<20", "20-25", "25-30", "30-35", "35+" };

/// The champion's place in role r's champions table on patch `p` of the trend, ranked
/// as tierlist.roleRank ranks the view's; null when a rare pick there
pub fn patchRank(a: std.mem.Allocator, t: *const Trend, p: usize, r: Role, c: usize) !?tierlist.Rank {
    const cells = try a.alloc(Counts, t.n);
    for (cells, 0..) |*x, o| x.* = t.onPatch(p, r, o);
    const prior: core.banimpact.Prior = .ofCounts(cells);
    const rare = struct {
        fn f(tr: *const Trend, pi: usize, cr: Counts, ci: usize) bool {
            var all: u64 = 0;
            for (Role.all) |r2| all += tr.onPatch(pi, r2, ci).games;
            return ratio(cr.games, tr.patch_games[pi]) < tierlist.min_pick_rate or ratio(cr.games, all) < tierlist.min_role_share;
        }
    }.f;
    if (cells[c].games == 0 or rare(t, p, cells[c], c)) return null;
    const mine = prior.edge(cells[c].wins, cells[c].games);
    var rank: usize = 1;
    var of: usize = 0;
    for (cells, 0..) |x, o| {
        if (x.games == 0 or rare(t, p, x, o)) continue;
        of += 1;
        if (o != c and prior.edge(x.wins, x.games) > mine) rank += 1;
    }
    return .{ .rank = rank, .of = of };
}
