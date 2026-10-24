//! Pure draft logic shared by backend and app. std only.

pub const roles = @import("roles.zig");
pub const statsfile = @import("statsfile.zig");
pub const score = @import("score.zig");
pub const curvesfile = @import("curvesfile.zig");
pub const banimpact = @import("banimpact.zig");
pub const champfacts = @import("champfacts.zig");
pub const fuzz = @import("fuzz.zig");

pub const Role = roles.Role;
pub const Stats = statsfile.Stats;
pub const Draft = score.Draft;
pub const Pick = score.Pick;
pub const Options = score.Options;
pub const Suggestion = score.Suggestion;
pub const Reason = score.Reason;
pub const recommend = score.recommend;

/// Riot requires this visible to players: every site page (docs/production-key.md)
pub const boilerplate = "meiolol isn't endorsed by Riot Games and doesn't reflect the " ++
    "views or opinions of Riot Games or anyone officially involved in producing or " ++
    "managing Riot Games properties. Riot Games, and all associated properties are " ++
    "trademarks or registered trademarks of Riot Games, Inc.";

test {
    @import("std").testing.refAllDecls(@This());
}
