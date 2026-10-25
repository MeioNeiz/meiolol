//! HTTPS GET to the League Client on 127.0.0.1 (net.pinned): the certificate chain must
//! lead to Riot's root (riotgames.pem) and nothing else, as the client's certificate
//! doesn't name 127.0.0.1.

const std = @import("std");
const pinned = @import("net").pinned;

pub const riot_root_pem = @embedFile("riotgames.pem");

pub const Response = pinned.Response;
pub const rootBundle = pinned.rootBundle;

pub fn get(
    gpa: std.mem.Allocator,
    io: std.Io,
    port: u16,
    password: []const u8,
    path: []const u8,
) !Response {
    var parts: RequestParts = undefined;
    const req = try parts.request(port, password, path);
    return pinned.get(gpa, io, riot_root_pem, req) catch |err| switch (err) {
        error.ConnectionRefused => error.ClientNotRunning,
        else => err,
    };
}

/// `get` without TLS, for the mock client (lcu/mock.zig) only: lockfile.Credentials.plain
pub fn getPlain(
    gpa: std.mem.Allocator,
    io: std.Io,
    port: u16,
    password: []const u8,
    path: []const u8,
) !Response {
    var parts: RequestParts = undefined;
    const req = try parts.request(port, password, path);
    return pinned.getPlain(gpa, io, req) catch |err| switch (err) {
        error.ConnectionRefused => error.ClientNotRunning,
        else => err,
    };
}

/// What the Request points into. A `&.{...}` header list in the returned literal would
/// live in request's own frame and dangle once it returns (garbage headers and a
/// segfault in the TLS writer on Windows)
const RequestParts = struct {
    host: [32]u8,
    auth: [512]u8,
    headers: [2]pinned.Header,

    fn request(p: *RequestParts, port: u16, password: []const u8, path: []const u8) !pinned.Request {
        p.headers = .{
            .{ .name = "Authorization", .value = try basicAuth(&p.auth, password) },
            .{ .name = "Accept", .value = "application/json" },
        };
        return .{
            .address = .{ .ip4 = .loopback(port) },
            .host = try std.mem.print(&p.host, "127.0.0.1:{d}", .{port}),
            .path = path,
            .headers = &p.headers,
        };
    }
};

/// "Basic " and base64 of riot:password
fn basicAuth(buf: []u8, password: []const u8) ![]const u8 {
    var plain_buf: [384]u8 = undefined;
    const plain = std.mem.print(&plain_buf, "riot:{s}", .{password}) catch
        return error.PasswordTooLong;
    const enc = std.base64.standard.Encoder;
    if (6 + enc.calcSize(plain.len) > buf.len) return error.PasswordTooLong;
    @memcpy(buf[0..6], "Basic ");
    return buf[0 .. 6 + enc.encode(buf[6..], plain).len];
}

const testing = std.testing;

test "riot root parses" {
    var bundle = try rootBundle(testing.allocator, testing.io, riot_root_pem);
    defer bundle.deinit(testing.allocator);
    try testing.expectEqual(1, bundle.map.count());
}

test "basic auth" {
    var buf: [128]u8 = undefined;
    // base64("riot:pw")
    try testing.expectEqualStrings("Basic cmlvdDpwdw==", try basicAuth(&buf, "pw"));
}

test "getPlain sends Host, the basic auth and Accept" {
    const io = testing.io;
    var listener = try (try std.Io.net.IpAddress.parse("127.0.0.1", 0)).listen(io, .{ .reuse_address = true });
    defer listener.deinit(io);
    const Serve = struct {
        fn one(l: *std.Io.net.Server, got: *[512]u8, n: *usize) !void {
            const s = try l.accept(io);
            defer s.close(io);
            var rb: [1024]u8 = undefined;
            var r = s.reader(io, &rb);
            while (true) {
                const line = try r.interface.takeDelimiterInclusive('\n');
                @memcpy(got[n.*..][0..line.len], line);
                n.* += line.len;
                if (line.len == 2) break;
            }
            var wb: [128]u8 = undefined;
            var w = s.writer(io, &wb);
            try w.interface.writeAll("HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok");
            try w.interface.flush();
        }
    };
    var got: [512]u8 = undefined;
    var n: usize = 0;
    var serving = try io.concurrent(Serve.one, .{ &listener, &got, &n });
    const port = listener.socket.address.getPort();
    const res = try getPlain(testing.allocator, io, port, "pw", "/x");
    defer testing.allocator.free(res.body);
    try serving.await(io);
    var want_buf: [256]u8 = undefined;
    const want = try std.mem.print(&want_buf, "GET /x HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\n" ++
        "Authorization: Basic cmlvdDpwdw==\r\nAccept: application/json\r\n" ++
        "Connection: close\r\n\r\n", .{port});
    try testing.expectEqualStrings(want, got[0..n]);
}
