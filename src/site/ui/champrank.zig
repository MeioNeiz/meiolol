//! The champion page's rank filter: one file per view and champion, at the site root
//! (site/champrank.zig dataPath: data/champion/<slug>-rank.bin, -rank-patch.bin,
//! -rank-all.bin, -rank-all-patch.bin), fetched on the first pick
//! above Platinum+, holding what a rank changes: the strip, lane opponents, the build and
//! by patch. By game length, players, pick-up, also play and allies stay Platinum+ (the
//! page's base data) and say so: per-player figures are thin at high ranks, and the
//! tally behind this file counts lane opponents only

const role = @import("role.zig");
const buildpanel = @import("buildpanel.zig");
const cp = @import("champpage.zig");

/// Emerald+, Diamond+, Master+, in that order (builds.rank_tiers): each counts
/// every tier from its lowest up, as the subbar
pub const Data = struct {
    groups: []const Group,
};

pub const Group = struct {
    /// "Emerald+"
    label: []const u8,
    /// The roles with 5%+ of the champion's games at this rank; a base role missing here
    /// has too few games to show
    roles: []const Role,
};

/// As champpage.Role, at the group's rank. Games under 400: show the figures faded;
/// under 100: games only (builds.md's rule for the build rows, kept for the whole block)
pub const Role = struct {
    role: role.Role,
    /// Games with a lane opponent
    games: u32,
    wins: u32,
    /// Its place in the role at this rank (champions table's rule); 0: a rare pick here
    rank: u16 = 0,
    of: u16 = 0,
    /// Pick and ban rates, %
    pick: f32,
    ban: f32,
    /// This rank's build, or the next wider group's while this one has under 400 games
    build: ?buildpanel.Data = null,
    /// Which group the build is from: 0 Platinum+, 1 Emerald+, 2 Diamond+, 3 Master+
    build_group: u8 = 0,
    /// Lane opponents in 1%+ of its games here, most played first. usual: against this
    /// rank's rates, shrunk as the base page's; gold: the curves' Diamond+ bracket from
    /// Diamond+ up, all ranks below
    opps: []const cp.Opp,
    /// Oldest first, as champpage.Role.by_patch
    by_patch: []const cp.Patch,
};
