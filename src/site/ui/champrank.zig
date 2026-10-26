//! The champion page's rank filter: per view and champion, one file for each island
//! (site/champrank.zig dataPath: data/champion/<slug>{,-build,-more}-rank<view>.bin, at
//! the site root), fetched on the first pick above Platinum+, holding what a rank
//! changes: the strip, the build, lane opponents and by patch. By game length, players,
//! pick-up, also play and allies stay Platinum+ (the page's base data) and say so:
//! per-player figures are thin at high ranks, and the tally behind these files counts
//! lane opponents only.
//!
//! Each holds the base file's role type, so a rank swaps in what it has. Groups:
//! Emerald+, Diamond+, Master+ (builds.rank_tiers), each counting every tier from its
//! lowest up, as the subbar; a base role missing from a group has under 5% of the
//! champion's games there. Games under 400: figures faded; under 100: games only
//! (builds.md's rule for the build rows, kept for the whole block)

const cp = @import("champpage.zig");

pub const n_groups = 3;

/// TopRole without the search's lane and the patch move
pub const Top = struct { groups: [n_groups][]const cp.TopRole };

/// BuildRole.from: the next wider group's build while this one has under 400 games
pub const Build = struct { groups: [n_groups][]const cp.BuildRole };

/// MoreRole with the lane opponents alone as rels; no lean or by_length. Opp.usual
/// against this rank's rates, shrunk as the base page's; gold: the curves' Diamond+
/// bracket from Diamond+ up, all ranks below
pub const More = struct { groups: [n_groups][]const cp.MoreRole };
