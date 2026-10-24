//! net: the HTTP pieces std leaves to the application, std only.
//!
//! - `ratelimit`: client-side sliding-window limits corrected from the server's own
//!   headers, shared by threads, with priority callers and even pacing
//! - `server`: HTTP/1.1 server loops with hyper's limits (connections, head and body
//!   sizes, idle, head and handler timeouts)
//! - `pinned`: HTTPS GET trusting one root certificate and no host name, for a local
//!   service with its own CA
//! - `client`: HTTP requests with a time limit and a capped body, on std.http.Client,
//!   which has neither
//! - `deadline`: a time limit on any call that can be cancelled
//! - `sign`: Ed25519 signatures in text, each bound to a context string, for what a
//!   program downloads

const std = @import("std");

pub const ratelimit = @import("ratelimit.zig");
pub const pinned = @import("pinned.zig");
pub const server = @import("server.zig");
pub const sign = @import("sign.zig");
pub const client = @import("client.zig");
pub const deadline = @import("deadline.zig");

test {
    std.testing.refAllDecls(@This());
}
