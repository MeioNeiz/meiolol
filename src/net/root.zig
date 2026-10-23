//! net: the HTTP pieces std leaves to the application, std only.
//!
//! - `ratelimit`: client-side sliding-window limits corrected from the server's own
//!   headers, shared by threads, with priority callers and even pacing

const std = @import("std");

pub const ratelimit = @import("ratelimit.zig");

test {
    std.testing.refAllDecls(@This());
}
