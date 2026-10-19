//! League Client (LCU) local API: read-only GETs during champ select.

const std = @import("std");

pub const lockfile = @import("lockfile.zig");
pub const https = @import("https.zig");
pub const session = @import("session.zig");
pub const me = @import("me.zig");
pub const Watch = @import("watch.zig").Watch;
pub const mock = @import("mock.zig");

pub const Response = https.Response;

/// A connection target; each request opens its own TLS connection
pub const Client = struct {
    gpa: std.mem.Allocator,
    io: std.Io,
    credentials: lockfile.Credentials,

    /// Body allocated with `gpa`
    pub fn get(c: Client, path: []const u8) !Response {
        const creds = c.credentials;
        if (creds.plain) return https.getPlain(c.gpa, c.io, creds.port, creds.password, path);
        return https.get(c.gpa, c.io, creds.port, creds.password, path);
    }

    /// Body of a 2xx reply, else error.HttpStatus
    pub fn getOk(c: Client, path: []const u8) ![]u8 {
        const resp = try c.get(path);
        if (resp.status / 100 != 2) {
            c.gpa.free(resp.body);
            return error.HttpStatus;
        }
        return resp.body;
    }
};

test {
    std.testing.refAllDecls(@This());
}
