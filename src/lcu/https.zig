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
    var host_buf: [32]u8 = undefined;
    var auth_buf: [512]u8 = undefined;
    const req = try request(&host_buf, &auth_buf, port, password, path);
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
    var host_buf: [32]u8 = undefined;
    var auth_buf: [512]u8 = undefined;
    const req = try request(&host_buf, &auth_buf, port, password, path);
    return pinned.getPlain(gpa, io, req) catch |err| switch (err) {
        error.ConnectionRefused => error.ClientNotRunning,
        else => err,
    };
}

fn request(host_buf: []u8, auth_buf: []u8, port: u16, password: []const u8, path: []const u8) !pinned.Request {
    return .{
        .address = .{ .ip4 = .loopback(port) },
        .host = try std.mem.print(host_buf, "127.0.0.1:{d}", .{port}),
        .path = path,
        .headers = &.{
            .{ .name = "Authorization", .value = try basicAuth(auth_buf, password) },
            .{ .name = "Accept", .value = "application/json" },
        },
    };
}

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
