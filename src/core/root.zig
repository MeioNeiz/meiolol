//! Pure draft logic shared by backend and app. std only.

pub const roles = @import("roles.zig");
pub const statsfile = @import("statsfile.zig");
pub const score = @import("score.zig");

pub const Role = roles.Role;
pub const Stats = statsfile.Stats;
pub const Draft = score.Draft;
pub const Pick = score.Pick;
pub const Options = score.Options;
pub const Suggestion = score.Suggestion;
pub const Reason = score.Reason;
pub const recommend = score.recommend;

test {
    @import("std").testing.refAllDecls(@This());
}
