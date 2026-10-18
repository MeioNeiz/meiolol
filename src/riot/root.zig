//! Riot API: rate limited client, endpoints, match parsing, crawler.

pub const ratelimit = @import("ratelimit.zig");
pub const client = @import("client.zig");
pub const endpoints = @import("endpoints.zig");
pub const match = @import("match.zig");
pub const timeline = @import("timeline.zig");
pub const mastery = @import("mastery.zig");
pub const crawl = @import("crawl.zig");
pub const proxy = @import("proxy.zig");
pub const writer = @import("writer.zig");
pub const fake = @import("fake.zig");
pub const sparse = @import("sparse.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
