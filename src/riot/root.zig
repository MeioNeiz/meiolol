//! Riot API: rate limited client, endpoints, match parsing, crawler.

pub const ratelimit = @import("ratelimit.zig");
pub const client = @import("client.zig");
pub const endpoints = @import("endpoints.zig");
pub const match = @import("match.zig");
pub const crawl = @import("crawl.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
