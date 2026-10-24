//! HTTPS GET to a server whose certificate chain must lead to one given root and
//! nothing else, with no host name check: for a local service with its own CA and a
//! certificate that doesn't name 127.0.0.1 (std.http.Client always checks the name).
//! What rustls with a custom verifier gives, or reqwest's add_root_certificate with
//! danger_accept_invalid_hostnames, but pinned to that root alone.
//!
//!     const res = try pinned.get(gpa, io, root_pem, .{
//!         .address = .{ .ip4 = .loopback(port) },
//!         .host = "127.0.0.1",
//!         .path = "/status",
//!         .headers = &.{.{ .name = "authorization", .value = auth }},
//!     });
//!     defer gpa.free(res.body);
//!
//! One request per connection (Connection: close). The answer's body is read by its
//! Content-Length, chunks or to the close, up to `Request.max_body`. `getPlain` sends the
//! same request without TLS, for a mock of the service.

const std = @import("std");
const builtin = @import("builtin");
const Io = std.Io;
const tls = std.crypto.tls;

pub const Response = struct {
    status: u16,
    /// Owned by the caller
    body: []u8,
};

pub const Header = struct {
    name: []const u8,
    value: []const u8,
};

pub const Request = struct {
    address: Io.net.IpAddress,
    /// The Host header
    host: []const u8,
    path: []const u8,
    /// Sent after Host, in order
    headers: []const Header = &.{},
    /// A longer body is error.ResponseTooLarge
    max_body: usize = 32 * 1024 * 1024,
};

/// `req` over TLS, trusting only the first certificate in `root_pem`.
/// error.ConnectionRefused when nothing listens
pub fn get(gpa: std.mem.Allocator, io: Io, root_pem: []const u8, req: Request) !Response {
    const stream = try connect(io, req.address);
    defer stream.close(io);

    var bundle = try rootBundle(gpa, io, root_pem);
    defer bundle.deinit(gpa);
    var bundle_lock: Io.RwLock = .init;

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
        .realtime_now = Io.Clock.real.now(io),
        // Content-Length or chunked framing detects truncation
        .allow_truncation_attacks = true,
    }) catch |err| switch (err) {
        error.WriteFailed => return stream_writer.err orelse err,
        error.ReadFailed => return stream_reader.err orelse err,
        else => return err,
    };

    try writeRequest(&client.writer, req);
    try client.writer.flush();
    try stream_writer.interface.flush();

    return readResponse(gpa, &client.reader, req.max_body) catch |err| switch (err) {
        error.ReadFailed => {
            if (client.read_err) |e| return e;
            if (stream_reader.err) |e| return e;
            return err;
        },
        else => return err,
    };
}

/// `get` without TLS, for a mock of the service
pub fn getPlain(gpa: std.mem.Allocator, io: Io, req: Request) !Response {
    const stream = try connect(io, req.address);
    defer stream.close(io);
    var read_buf: [16 * 1024]u8 = undefined;
    var write_buf: [4096]u8 = undefined;
    var reader = stream.reader(io, &read_buf);
    var writer = stream.writer(io, &write_buf);
    try writeRequest(&writer.interface, req);
    try writer.interface.flush();
    return readResponse(gpa, &reader.interface, req.max_body) catch |err| switch (err) {
        error.ReadFailed => return reader.err orelse err,
        else => return err,
    };
}

fn connect(io: Io, address: Io.net.IpAddress) !Io.net.Stream {
    return address.connect(io, .{ .mode = .stream }) catch |err| switch (err) {
        // Zig 0.16 reports a refused connect on Windows as Unexpected
        error.Unexpected => {
            if (builtin.target.os.tag == .windows) return error.ConnectionRefused;
            return err;
        },
        else => return err,
    };
}

fn writeRequest(w: *Io.Writer, req: Request) !void {
    try w.print("GET {s} HTTP/1.1\r\nHost: {s}\r\n", .{ req.path, req.host });
    for (req.headers) |h| try w.print("{s}: {s}\r\n", .{ h.name, h.value });
    try w.writeAll("Connection: close\r\n\r\n");
}

const Buffers = struct {
    socket_read: [tls.Client.min_buffer_len]u8,
    socket_write: [tls.Client.min_buffer_len]u8,
    /// Decrypted bytes; also holds the longest header line
    tls_read: [tls.Client.min_buffer_len + 16 * 1024]u8,
    tls_write: [4096]u8,
};

/// A bundle holding only the first certificate in `pem`; error.BadPem if there is none
/// or it doesn't parse
pub fn rootBundle(gpa: std.mem.Allocator, io: Io, pem: []const u8) !std.crypto.Certificate.Bundle {
    const begin = "-----BEGIN CERTIFICATE-----";
    const end = "-----END CERTIFICATE-----";
    const begin_at = std.mem.find(u8, pem, begin) orelse return error.BadPem;
    const start = begin_at + begin.len;
    const stop = std.mem.findPos(u8, pem, start, end) orelse return error.BadPem;
    const decoder = std.base64.standard.decoderWithIgnore(" \t\r\n");

    var bundle: std.crypto.Certificate.Bundle = .empty;
    errdefer bundle.deinit(gpa);
    const b64 = pem[start..stop];
    try bundle.bytes.ensureTotalCapacity(gpa, decoder.calcSizeUpperBound(b64.len));
    const len = try decoder.decode(bundle.bytes.allocatedSlice(), b64);
    bundle.bytes.items.len = len;
    const now = Io.Clock.real.now(io).toSeconds();
    try bundle.parseCert(gpa, 0, now);
    if (bundle.map.count() != 1) return error.BadPem;
    return bundle;
}

/// Status line, headers, then a Content-Length, chunked or read-to-close body of at most
/// `max_body` bytes. error.BadResponse for anything that isn't HTTP/1.x
pub fn readResponse(gpa: std.mem.Allocator, r: *Io.Reader, max_body: usize) !Response {
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
        const colon = std.mem.findScalar(u8, line, ':') orelse
            return error.BadResponse;
        const name = std.mem.trim(u8, line[0..colon], " \t");
        const value = std.mem.trim(u8, line[colon + 1 ..], " \t");
        if (std.ascii.eqlIgnoreCase(name, "content-length")) {
            content_length = std.fmt.parseInt(usize, value, 10) catch
                return error.BadResponse;
        } else if (std.ascii.eqlIgnoreCase(name, "transfer-encoding")) {
            chunked = std.ascii.findIgnoreCase(value, "chunked") != null;
        }
    }

    var body: std.ArrayList(u8) = .empty;
    errdefer body.deinit(gpa);
    if (chunked) {
        while (true) {
            const size_line = try takeLine(r);
            const hex = size_line[0 .. std.mem.findScalar(u8, size_line, ';') orelse
                size_line.len];
            const size = std.fmt.parseInt(usize, std.mem.trim(u8, hex, " \t"), 16) catch
                return error.BadResponse;
            if (size == 0) break;
            if (size > max_body -| body.items.len) return error.ResponseTooLarge;
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

fn takeLine(r: *Io.Reader) ![]const u8 {
    const line = r.takeDelimiterInclusive('\n') catch |err| switch (err) {
        error.StreamTooLong => return error.BadResponse,
        else => return err,
    };
    return std.mem.trimEnd(u8, line, "\r\n");
}

const testing = std.testing;

fn expectBody(raw: []const u8, status: u16, body: []const u8) !void {
    var r: Io.Reader = .fixed(raw);
    const resp = try readResponse(testing.allocator, &r, 1024);
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
    var r: Io.Reader = .fixed("SSH-2.0-OpenSSH\r\n\r\n");
    try testing.expectError(error.BadResponse, readResponse(testing.allocator, &r, 1024));
    var short: Io.Reader = .fixed("HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\nabc");
    try testing.expectError(error.EndOfStream, readResponse(testing.allocator, &short, 1024));
}

test "a body past max_body is refused by every framing" {
    const big: [100]u8 = @splat('x');
    var len: Io.Reader = .fixed("HTTP/1.1 200 OK\r\nContent-Length: 100\r\n\r\n" ++ big);
    try testing.expectError(error.ResponseTooLarge, readResponse(testing.allocator, &len, 64));
    var chunks: Io.Reader = .fixed("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n" ++
        "30\r\n" ++ big[0..48] ++ "\r\n30\r\n" ++ big[0..48] ++ "\r\n0\r\n\r\n");
    try testing.expectError(error.ResponseTooLarge, readResponse(testing.allocator, &chunks, 64));
    var huge: Io.Reader = .fixed("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n1\r\nx\r\nffffffffffffffff\r\n");
    try testing.expectError(error.ResponseTooLarge, readResponse(testing.allocator, &huge, 64));
    var close: Io.Reader = .fixed("HTTP/1.1 200 OK\r\n\r\n" ++ big);
    try testing.expectError(error.ResponseTooLarge, readResponse(testing.allocator, &close, 64));
}

test "a PEM without a certificate is BadPem" {
    try testing.expectError(error.BadPem, rootBundle(testing.allocator, testing.io, "no cert here"));
    try testing.expectError(error.BadPem, rootBundle(testing.allocator, testing.io, "-----BEGIN CERTIFICATE-----\nAAAA"));
}

test "getPlain sends the request and reads the answer; refused is ConnectionRefused" {
    const io = testing.io;
    var listener = try (try Io.net.IpAddress.parse("127.0.0.1", 0)).listen(io, .{ .reuse_address = true });
    const Serve = struct {
        fn one(l: *Io.net.Server, got: *[256]u8, n: *usize) !void {
            const s = try l.accept(io);
            defer s.close(io);
            var rb: [512]u8 = undefined;
            var r = s.reader(io, &rb);
            const head = try r.interface.takeDelimiterInclusive('\n');
            n.* = head.len;
            @memcpy(got[0..head.len], head);
            while ((try r.interface.takeDelimiterInclusive('\n')).len > 2) {}
            var wb: [128]u8 = undefined;
            var w = s.writer(io, &wb);
            try w.interface.writeAll("HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok");
            try w.interface.flush();
        }
    };
    var got: [256]u8 = undefined;
    var n: usize = 0;
    var serving = try io.concurrent(Serve.one, .{ &listener, &got, &n });
    const req: Request = .{ .address = listener.socket.address, .host = "x", .path = "/a?b=1" };
    const res = try getPlain(testing.allocator, io, req);
    defer testing.allocator.free(res.body);
    try serving.await(io);
    try testing.expectEqualStrings("GET /a?b=1 HTTP/1.1\r\n", got[0..n]);
    try testing.expectEqual(@as(u16, 200), res.status);
    try testing.expectEqualStrings("ok", res.body);

    // Nothing listens once it closes
    const port = listener.socket.address.getPort();
    listener.deinit(io);
    try testing.expectError(error.ConnectionRefused, getPlain(testing.allocator, io, .{
        .address = .{ .ip4 = .loopback(port) },
        .host = "x",
        .path = "/",
    }));
}

fn fuzzResponse(_: void, s: *testing.Smith) !void {
    var buf: [1024]u8 = undefined;
    var r: Io.Reader = .fixed(buf[0..s.slice(&buf)]);
    const res = readResponse(testing.allocator, &r, 256) catch return;
    defer testing.allocator.free(res.body);
    try testing.expect(res.body.len <= 256);
}

test "fuzz: responses" {
    try testing.fuzz({}, fuzzResponse, .{});
}
