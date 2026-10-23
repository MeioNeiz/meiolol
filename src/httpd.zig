//! The accept and request loops the HTTP servers share: serve.zig (local and preview
//! site), api/root.zig (Your games) and riot/proxy.zig (the crawler's proxy for it)

const std = @import("std");
const Io = std.Io;
const Request = std.http.Server.Request;

/// What a failed request logs beside the error
pub const Logged = enum {
    /// The target without its query
    path,
    /// The error alone: the path may hold a Riot ID or PUUID
    error_only,
};

/// Each connection on its own thread until cancelled: async may run it on the accepting
/// thread when the pool is busy, and a browser's idle keep-alive connection then blocks
/// every later one. A failed accept (out of file descriptors) waits a second and retries
pub fn accept(
    comptime scope: @EnumLiteral(),
    io: Io,
    server: *Io.net.Server,
    ctx: anytype,
    comptime connection: fn (@TypeOf(ctx), Io.net.Stream) void,
) void {
    const log = std.log.scoped(scope);
    var group: Io.Group = .init;
    defer group.cancel(io);
    while (true) {
        const stream = server.accept(io) catch |err| switch (err) {
            error.Canceled => return,
            else => {
                log.warn("accept: {t}", .{err});
                io.sleep(.fromSeconds(1), .awake) catch return;
                continue;
            },
        };
        group.concurrent(io, connection, .{ ctx, stream }) catch |err| {
            log.warn("connection: {t}", .{err});
            stream.close(io);
        };
    }
}

/// Answers requests on `stream` with handle(ctx, *Request) until the client closes it,
/// then closes it
pub fn requests(
    comptime scope: @EnumLiteral(),
    io: Io,
    stream: Io.net.Stream,
    ctx: anytype,
    comptime handle: anytype,
    comptime logged: Logged,
) void {
    const log = std.log.scoped(scope);
    defer stream.close(io);
    // Holds the whole request head: browsers send every localhost port's cookies, often
    // over 8 KB from other dev servers, and a head that overflows is dropped unanswered
    var recv_buffer: [64 * 1024]u8 = undefined;
    var send_buffer: [16 * 1024]u8 = undefined;
    var conn_reader = stream.reader(io, &recv_buffer);
    var conn_writer = stream.writer(io, &send_buffer);
    var server = std.http.Server.init(&conn_reader.interface, &conn_writer.interface);
    while (server.reader.state == .ready) {
        var request = server.receiveHead() catch |err| switch (err) {
            error.HttpConnectionClosing => return,
            else => return log.debug("closing connection: {t}", .{err}),
        };
        // std's respond() asserts a POST states its body length; a bare `curl -X POST`
        // states none, which would crash the server. No length and no chunking means no
        // body (RFC 9112 6.3)
        if (request.head.transfer_encoding == .none and request.head.content_length == null) {
            request.head.content_length = 0;
        }
        handle(ctx, &request) catch |err| {
            switch (logged) {
                .path => {
                    const target = request.head.target;
                    const path = target[0 .. std.mem.findScalar(u8, target, '?') orelse target.len];
                    log.warn("{s}: {t}", .{ path, err });
                },
                .error_only => log.warn("request: {t}", .{err}),
            }
            return;
        };
    }
}

test "a bodyless POST and a 20 KB head are answered" {
    const io = std.testing.io;
    const T = struct {
        fn serve(s: *Io.net.Server) void {
            accept(.httpd, io, s, {}, connection);
        }
        fn connection(_: void, stream: Io.net.Stream) void {
            requests(.httpd, io, stream, {}, handle, .path);
        }
        fn handle(_: void, r: *Request) !void {
            try r.respond("ok", .{});
        }
        fn ask(s: *Io.net.Server, head: []const u8) !void {
            const c = try s.socket.address.connect(io, .{ .mode = .stream });
            defer c.close(io);
            var buf: [256]u8 = undefined;
            var w = c.writer(io, &buf);
            try w.interface.writeAll(head);
            try w.interface.flush();
            var got: [256]u8 = undefined;
            const msg = try c.socket.receiveTimeout(io, &got, .{ .duration = .{ .raw = .fromSeconds(5), .clock = .awake } });
            try std.testing.expectStringStartsWith(msg.data, "HTTP/1.1 200");
        }
    };
    const address = try Io.net.IpAddress.parse("127.0.0.1", 0);
    var server = try address.listen(io, .{ .reuse_address = true });
    defer server.deinit(io);
    var serving = try io.concurrent(T.serve, .{&server});
    defer serving.cancel(io);

    try T.ask(&server, "POST /x HTTP/1.1\r\nHost: x\r\n\r\n");
    const cookie: [20 * 1024]u8 = @splat('a');
    try T.ask(&server, "GET / HTTP/1.1\r\nHost: x\r\nCookie: " ++ cookie ++ "\r\n\r\n");
}
