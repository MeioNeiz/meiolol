//! Minimal HTTPS GET to the League Client on 127.0.0.1.
//!
//! std.http.Client always checks the host name, which the client's certificate does
//! not carry for 127.0.0.1, so this does its own TLS: the certificate chain must lead
//! to Riot's root (riotgames.pem) and nothing else, with no host check.

const std = @import("std");
const builtin = @import("builtin");
const tls = std.crypto.tls;

pub const riot_root_pem = @embedFile("riotgames.pem");

pub const Response = struct {
    status: u16,
    body: []u8,
};

/// Bodies above this are refused; the largest LCU replies used here are ~100 KB
const max_body = 32 * 1024 * 1024;

pub fn get(
    gpa: std.mem.Allocator,
    io: std.Io,
    port: u16,
    password: []const u8,
    path: []const u8,
) !Response {
    return getTrusting(gpa, io, port, password, path, riot_root_pem);
}

/// `get` with another root certificate, for testing against a local server
pub fn getTrusting(
    gpa: std.mem.Allocator,
    io: std.Io,
    port: u16,
    password: []const u8,
    path: []const u8,
    root_pem: []const u8,
) !Response {
    const address: std.Io.net.IpAddress = .{ .ip4 = .loopback(port) };
    const stream = address.connect(io, .{ .mode = .stream }) catch |err| switch (err) {
        error.ConnectionRefused => return error.ClientNotRunning,
        // Zig 0.16 reports a refused connect on Windows as Unexpected
        error.Unexpected => {
            if (builtin.os.tag == .windows) return error.ClientNotRunning;
            return err;
        },
        else => return err,
    };
    defer stream.close(io);

    var bundle = try rootBundle(gpa, io, root_pem);
    defer bundle.deinit(gpa);
    var bundle_lock: std.Io.RwLock = .init;

    const bufs = try gpa.create(Buffers);
    defer gpa.destroy(bufs);
    var stream_reader = stream.reader(io, &bufs.socket_read);
    var stream_writer = stream.writer(io, &bufs.socket_write);
    var entropy: [tls.Client.Options.entropy_len]u8 = undefined;
    io.random(&entropy);
    var client = tls.Client.init(&stream_reader.interface, &stream_writer.interface, .{
        .host = .no_verification,
        .ca = .{ .bundle = .{
            .gpa = gpa,
            .io = io,
            .lock = &bundle_lock,
            .bundle = &bundle,
        } },
        .read_buffer = &bufs.tls_read,
        .write_buffer = &bufs.tls_write,
        .entropy = &entropy,
        .realtime_now = std.Io.Clock.real.now(io),
        // Content-Length or chunked framing detects truncation
        .allow_truncation_attacks = true,
    }) catch |err| switch (err) {
        error.WriteFailed => return stream_writer.err orelse err,
        error.ReadFailed => return stream_reader.err orelse err,
        else => return err,
    };

    var auth_buf: [512]u8 = undefined;
    const auth = try basicAuth(&auth_buf, password);
    const w = &client.writer;
    try w.print(
        "GET {s} HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nAuthorization: Basic {s}\r\n" ++
            "Accept: application/json\r\nConnection: close\r\n\r\n",
        .{ path, port, auth },
    );
    try w.flush();
    try stream_writer.interface.flush();

    return readResponse(gpa, &client.reader) catch |err| switch (err) {
        error.ReadFailed => {
            if (client.read_err) |e| return e;
            if (stream_reader.err) |e| return e;
            return err;
        },
        else => return err,
    };
}

const Buffers = struct {
    socket_read: [tls.Client.min_buffer_len]u8,
    socket_write: [tls.Client.min_buffer_len]u8,
    /// Decrypted bytes; also holds the longest header line
    tls_read: [tls.Client.min_buffer_len + 16 * 1024]u8,
    tls_write: [4096]u8,
};

fn basicAuth(buf: []u8, password: []const u8) ![]const u8 {
    var plain_buf: [384]u8 = undefined;
    const plain = std.fmt.bufPrint(&plain_buf, "riot:{s}", .{password}) catch
        return error.PasswordTooLong;
    const enc = std.base64.standard.Encoder;
    if (enc.calcSize(plain.len) > buf.len) return error.PasswordTooLong;
    return enc.encode(buf, plain);
}

/// A bundle holding only the first certificate in `pem`
pub fn rootBundle(
    gpa: std.mem.Allocator,
    io: std.Io,
    pem: []const u8,
) !std.crypto.Certificate.Bundle {
    const begin = "-----BEGIN CERTIFICATE-----";
    const end = "-----END CERTIFICATE-----";
    const begin_at = std.mem.indexOf(u8, pem, begin) orelse return error.BadPem;
    const start = begin_at + begin.len;
    const stop = std.mem.indexOfPos(u8, pem, start, end) orelse return error.BadPem;
    const decoder = std.base64.standard.decoderWithIgnore(" \t\r\n");

    var bundle: std.crypto.Certificate.Bundle = .empty;
    errdefer bundle.deinit(gpa);
    const b64 = pem[start..stop];
    try bundle.bytes.ensureTotalCapacity(gpa, decoder.calcSizeUpperBound(b64.len));
    const len = try decoder.decode(bundle.bytes.allocatedSlice(), b64);
    bundle.bytes.items.len = len;
    const now = std.Io.Clock.real.now(io).toSeconds();
    try bundle.parseCert(gpa, 0, now);
    if (bundle.map.count() != 1) return error.BadPem;
    return bundle;
}

/// Status line, headers, then a Content-Length, chunked or read-to-close body
pub fn readResponse(gpa: std.mem.Allocator, r: *std.Io.Reader) !Response {
    const status_line = try takeLine(r);
    // "HTTP/1.1 200 OK"
    var parts = std.mem.splitScalar(u8, status_line, ' ');
    const proto = parts.next() orelse return error.BadResponse;
    if (!std.mem.startsWith(u8, proto, "HTTP/1.")) return error.BadResponse;
    const status = std.fmt.parseInt(u16, parts.next() orelse "", 10) catch
        return error.BadResponse;

    var content_length: ?usize = null;
    var chunked = false;
    while (true) {
        const line = try takeLine(r);
        if (line.len == 0) break;
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse
            return error.BadResponse;
        const name = std.mem.trim(u8, line[0..colon], " \t");
        const value = std.mem.trim(u8, line[colon + 1 ..], " \t");
        if (std.ascii.eqlIgnoreCase(name, "content-length")) {
            content_length = std.fmt.parseInt(usize, value, 10) catch
                return error.BadResponse;
        } else if (std.ascii.eqlIgnoreCase(name, "transfer-encoding")) {
            chunked = std.ascii.indexOfIgnoreCase(value, "chunked") != null;
        }
    }

    var body: std.ArrayList(u8) = .empty;
    errdefer body.deinit(gpa);
    if (chunked) {
        while (true) {
            const size_line = try takeLine(r);
            const hex = size_line[0 .. std.mem.indexOfScalar(u8, size_line, ';') orelse
                size_line.len];
            const size = std.fmt.parseInt(usize, std.mem.trim(u8, hex, " \t"), 16) catch
                return error.BadResponse;
            if (size == 0) break;
            if (body.items.len + size > max_body) return error.ResponseTooLarge;
            try r.appendExact(gpa, &body, size);
            if ((try takeLine(r)).len != 0) return error.BadResponse;
        }
        // Trailers until the blank line; a server closing early is fine
        while (true) {
            const line = takeLine(r) catch |err| switch (err) {
                error.EndOfStream => break,
                else => return err,
            };
            if (line.len == 0) break;
        }
    } else if (content_length) |len| {
        if (len > max_body) return error.ResponseTooLarge;
        try r.appendExact(gpa, &body, len);
    } else if (status != 204 and status != 304) {
        r.appendRemaining(gpa, &body, .limited(max_body)) catch |err| switch (err) {
            error.StreamTooLong => return error.ResponseTooLarge,
            else => return err,
        };
    }
    return .{ .status = status, .body = try body.toOwnedSlice(gpa) };
}

fn takeLine(r: *std.Io.Reader) ![]const u8 {
    const line = r.takeDelimiterInclusive('\n') catch |err| switch (err) {
        error.StreamTooLong => return error.BadResponse,
        else => return err,
    };
    return std.mem.trimEnd(u8, line, "\r\n");
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
    try testing.expectEqualStrings("cmlvdDpwdw==", try basicAuth(&buf, "pw"));
}

fn expectBody(raw: []const u8, status: u16, body: []const u8) !void {
    var r: std.Io.Reader = .fixed(raw);
    const resp = try readResponse(testing.allocator, &r);
    defer testing.allocator.free(resp.body);
    try testing.expectEqual(status, resp.status);
    try testing.expectEqualStrings(body, resp.body);
}

test "content length" {
    try expectBody("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n" ++
        "Content-Length: 13\r\n\r\n\"ChampSelect\"", 200, "\"ChampSelect\"");
}

test "chunked" {
    try expectBody(
        "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n" ++
            "4\r\n[1,2\r\nA;ext=1\r\n,3,4,5,6,7\r\n1\r\n]\r\n0\r\n\r\n",
        200,
        "[1,2,3,4,5,6,7]",
    );
}

test "no length reads to close" {
    const msg = "{\"message\":\"x\"}";
    try expectBody("HTTP/1.1 404 Not Found\r\n\r\n" ++ msg, 404, msg);
    try expectBody("HTTP/1.1 204 No Content\r\n\r\n", 204, "");
}

test "bad responses" {
    var r: std.Io.Reader = .fixed("SSH-2.0-OpenSSH\r\n\r\n");
    try testing.expectError(error.BadResponse, readResponse(testing.allocator, &r));
    var short: std.Io.Reader = .fixed("HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\nabc");
    try testing.expectError(error.EndOfStream, readResponse(testing.allocator, &short));
}
