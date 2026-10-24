//! HTTP requests on std.http.Client with what reqwest adds: a time limit on the whole
//! request and a cap on the answer's body. std's fetch() has neither, and panics when a
//! body read by Content-Length fails (a connection reset mid-body, a cancel), as it
//! unwraps an error std only records for chunked bodies; this reads the body itself.
//!
//!     var http: std.http.Client = .{ .allocator = gpa, .io = io };
//!     defer http.deinit();
//!     const res = try client.get(&http, gpa, .{
//!         .url = "https://example.com/data.json",
//!         .headers = &.{.{ .name = "authorization", .value = auth }},
//!         .timeout = .fromSeconds(20),
//!     });
//!     defer gpa.free(res.body);
//!
//! Redirects are answers (status 3xx), never followed, so headers go to the one host. A
//! gzip, deflate or zstd body is decompressed. A request that fails or times out drops
//! its connection rather than pooling it.

const std = @import("std");
const Io = std.Io;
const http = std.http;
const deadline = @import("deadline.zig");

pub const Request = struct {
    url: []const u8,
    method: http.Method = .GET,
    /// Sent with its Content-Length
    payload: ?[]const u8 = null,
    content_type: ?[]const u8 = null,
    /// Sent after the standard ones, in order
    headers: []const http.Header = &.{},
    /// A longer body is error.ResponseTooLarge, after `max_body` bytes went to the writer
    max_body: u64 = 64 * 1024 * 1024,
    /// From connecting to the body's last byte: error.Timeout past it. Null waits as long
    /// as the server takes
    timeout: ?Io.Duration = .fromSeconds(30),
};

pub const Response = struct {
    status: http.Status,
    /// In the allocator `get` was given
    body: []u8,
};

/// `req`, its body in memory
pub fn get(client: *http.Client, gpa: std.mem.Allocator, req: Request) !Response {
    var body: Io.Writer.Allocating = .init(gpa);
    defer body.deinit();
    const status = send(client, req, &body.writer) catch |err| switch (err) {
        error.WriteFailed => return error.OutOfMemory,
        else => return err,
    };
    return .{ .status = status, .body = try body.toOwnedSlice() };
}

/// `req`, its body streamed into `w` (not flushed). On an error `w` may hold part of it
pub fn send(client: *http.Client, req: Request, w: *Io.Writer) !http.Status {
    const t = req.timeout orelse return sendNow(client, req, w);
    return deadline.within(client.io, t, sendNow, .{ client, req, w });
}

fn sendNow(client: *http.Client, req: Request, w: *Io.Writer) !http.Status {
    const uri = try std.Uri.parse(req.url);
    var r = try client.request(req.method, uri, .{
        .redirect_behavior = .unhandled,
        .headers = .{ .content_type = if (req.content_type) |c| .{ .override = c } else .default },
        .extra_headers = req.headers,
    });
    defer r.deinit();
    // Else deinit pools a connection a failed send left looking idle, or drains the rest
    // of a body it stopped reading, which can block as long as the server likes
    errdefer if (r.connection) |c| {
        c.closing = true;
    };

    if (req.payload) |payload| {
        r.transfer_encoding = .{ .content_length = payload.len };
        var body = try r.sendBodyUnflushed(&.{});
        try body.writer.writeAll(payload);
        try body.end();
        try r.connection.?.flush();
    } else try r.sendBodiless();

    var response = try r.receiveHead(&.{});
    const decompress_buffer: []u8 = switch (response.head.content_encoding) {
        .identity => &.{},
        .zstd => try client.allocator.alloc(u8, std.compress.zstd.default_window_len),
        .deflate, .gzip => try client.allocator.alloc(u8, std.compress.flate.max_window_len),
        .compress => return error.UnsupportedCompressionMethod,
    };
    defer client.allocator.free(decompress_buffer);
    var transfer: [64]u8 = undefined;
    var decompress: http.Decompress = undefined;
    const status = response.head.status;
    const want = response.head.content_length;
    const body = response.readerDecompressing(&transfer, &decompress, decompress_buffer);
    const got = streamBody(body, w, req.max_body) catch |err| switch (err) {
        error.ReadFailed => {
            if (response.bodyErr()) |e| return e;
            return r.connection.?.stream_reader.err orelse err;
        },
        else => return err,
    };
    // std passes a connection's end through as the body's end when it comes before
    // Content-Length (a cut chunked body is already an error)
    if (want) |n| if (response.head.content_encoding == .identity and got != n) return error.ShortBody;
    return status;
}

fn streamBody(r: *Io.Reader, w: *Io.Writer, max: u64) !u64 {
    var total: u64 = 0;
    while (true) {
        const n = r.stream(w, .limited64(max - total +| 1)) catch |err| switch (err) {
            error.EndOfStream => return total,
            else => return err,
        };
        total += n;
        if (total > max) return error.ResponseTooLarge;
    }
}

const testing = std.testing;
const test_io = testing.io;

/// One connection: reads the request's head, writes `answer`, then holds the connection
/// for `hold_ms` or resets it
const Peer = struct {
    answer: []const u8,
    hold_ms: i64 = 0,
    reset: bool = false,

    fn serve(p: *const Peer, l: *Io.net.Server) void {
        const s = l.accept(test_io) catch return;
        var rb: [1024]u8 = undefined;
        var r = s.reader(test_io, &rb);
        while ((r.interface.takeDelimiterInclusive('\n') catch return s.close(test_io)).len > 2) {}
        var wb: [256]u8 = undefined;
        var w = s.writer(test_io, &wb);
        w.interface.writeAll(p.answer) catch {};
        w.interface.flush() catch {};
        test_io.sleep(.fromMilliseconds(p.hold_ms), .awake) catch {};
        if (p.reset) {
            // Linger 0: close sends RST, so the client's next read fails rather than ends
            const linger: extern struct { onoff: c_int, secs: c_int } = .{ .onoff = 1, .secs = 0 };
            std.posix.setsockopt(s.socket.handle, std.posix.SOL.SOCKET, std.posix.SO.LINGER, std.mem.asBytes(&linger)) catch {};
        }
        s.close(test_io);
    }

    /// `req` against this peer, its url pointed at it
    fn run(p: *const Peer, req: Request) !Response {
        var l = try (try Io.net.IpAddress.parse("127.0.0.1", 0)).listen(test_io, .{ .reuse_address = true });
        defer l.deinit(test_io);
        var serving = try test_io.concurrent(serve, .{ p, &l });
        defer serving.cancel(test_io);
        var buf: [64]u8 = undefined;
        var r = req;
        r.url = try std.mem.print(&buf, "http://127.0.0.1:{d}{s}", .{ l.socket.address.getPort(), req.url });
        var c: http.Client = .{ .allocator = testing.allocator, .io = test_io };
        defer c.deinit();
        return get(&c, testing.allocator, r);
    }
};

test "an answer by Content-Length or chunks" {
    const peer: Peer = .{ .answer = "HTTP/1.1 201 Created\r\nContent-Length: 2\r\n\r\nok" };
    const res = try peer.run(.{ .url = "/", .method = .POST, .payload = "{}", .content_type = "application/json" });
    defer testing.allocator.free(res.body);
    try testing.expectEqual(http.Status.created, res.status);
    try testing.expectEqualStrings("ok", res.body);

    const chunks: Peer = .{ .answer = "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n2\r\nab\r\n1\r\nc\r\n0\r\n\r\n" };
    const all = try chunks.run(.{ .url = "/" });
    defer testing.allocator.free(all.body);
    try testing.expectEqualStrings("abc", all.body);
}

test "a redirect is the answer" {
    const peer: Peer = .{ .answer = "HTTP/1.1 302 Found\r\nLocation: http://elsewhere/\r\nContent-Length: 0\r\n\r\n" };
    const res = try peer.run(.{ .url = "/" });
    defer testing.allocator.free(res.body);
    try testing.expectEqual(http.Status.found, res.status);
}

test "a reset mid-body is an error, not a panic" {
    const peer: Peer = .{ .answer = "HTTP/1.1 200 OK\r\nContent-Length: 100\r\n\r\nabc", .hold_ms = 100, .reset = true };
    try testing.expectError(error.ConnectionResetByPeer, peer.run(.{ .url = "/" }));
}

test "a body closed short of its Content-Length is ShortBody" {
    const peer: Peer = .{ .answer = "HTTP/1.1 200 OK\r\nContent-Length: 100\r\n\r\nabc" };
    try testing.expectError(error.ShortBody, peer.run(.{ .url = "/" }));
}

test "a body past max_body is ResponseTooLarge" {
    const peer: Peer = .{ .answer = "HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\n0123456789" };
    try testing.expectError(error.ResponseTooLarge, peer.run(.{ .url = "/", .max_body = 4 }));
    const fits = try peer.run(.{ .url = "/", .max_body = 10 });
    testing.allocator.free(fits.body);
}

test "a stall before the head or mid-body times out near the limit" {
    for ([_][]const u8{ "", "HTTP/1.1 200 OK\r\nContent-Length: 100\r\n\r\nabc" }) |answer| {
        const peer: Peer = .{ .answer = answer, .hold_ms = 10_000 };
        const t0 = Io.Clock.awake.now(test_io);
        try testing.expectError(error.Timeout, peer.run(.{ .url = "/", .timeout = .fromMilliseconds(200) }));
        const ms = t0.durationTo(Io.Clock.awake.now(test_io)).toMilliseconds();
        try testing.expect(ms >= 200 and ms < 3000);
    }
}
