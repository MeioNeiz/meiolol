//! net: the HTTP pieces std leaves to the application, std only.
//!
//! - `ratelimit`: client-side sliding-window limits corrected from the server's own
//!   headers, shared by threads, with priority callers and even pacing
//! - `sign`: Ed25519 signatures in text, each bound to a context string, for what a
//!   program downloads

const std = @import("std");

pub const ratelimit = @import("ratelimit.zig");
pub const sign = @import("sign.zig");

test {
    std.testing.refAllDecls(@This());
}
