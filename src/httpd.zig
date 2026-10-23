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

/// What hyper and axum bound, per server. nginx in front has lower caps of its own
/// (/etc/nginx/conf.d/meiolol.conf on jomify); these sit behind them and guard what reaches
/// a port directly. A head over 64 KB is answered 431 (the receive buffer, see `requests`)
pub const Limits = struct {
    /// Open connections; one more is answered 503 and closed
    connections: u16 = 128,
    /// Request body bytes by Content-Length, else 413. A chunked body is refused (411):
    /// nginx and our own clients state a length, and std discards an unread body whole
    body: u32 = 16 * 1024,
    /// Waiting for the next request's first byte
    idle: ?Io.Duration = .fromSeconds(60),
    /// From a request's first byte to the end of its head (hyper's header_read_timeout)
    head: Io.Duration = .fromSeconds(30),
    /// Reading the body and answering
    handle: ?Io.Duration = .fromSeconds(60),

    /// Loopback mocks and tests: the client is ours and may keep a connection or a
    /// request open as long as it likes
    pub const local: Limits = .{ .idle = null, .handle = null };

    /// How often the watchdog looks: a quarter of the shortest timeout, at most a second
    fn tick(l: Limits) Io.Duration {
        var ns: i96 = std.time.ns_per_s;
        for ([_]?Io.Duration{ l.idle, l.head, l.handle }) |d| {
            if (d) |t| ns = @min(ns, @divTrunc(t.nanoseconds, 4));
        }
        return .fromNanoseconds(ns);
    }
};

const Slot = struct {
    stream: Io.net.Stream = undefined,
    used: bool = false,
    /// Awake-clock nanoseconds after which the watchdog shuts the socket down; 0 none
    deadline: std.atomic.Value(i64) = .init(0),
};

/// The open connections. A slot is freed and its stream closed under the mutex, so the
/// watchdog never shuts down a reused descriptor
const Table = struct {
    mutex: Io.Mutex = .init,
    slots: []Slot,

    fn take(t: *Table, io: Io, stream: Io.net.Stream) ?*Slot {
        t.mutex.lockUncancelable(io);
        defer t.mutex.unlock(io);
        for (t.slots) |*s| if (!s.used) {
            s.* = .{ .stream = stream, .used = true };
            return s;
        };
        return null;
    }

    fn close(t: *Table, io: Io, slot: *Slot) void {
        t.mutex.lockUncancelable(io);
        defer t.mutex.unlock(io);
        slot.stream.close(io);
        slot.used = false;
    }

    /// Shutting a socket down wakes its blocked read or write with an error, which ends
    /// the connection's loop
    fn watch(t: *Table, io: Io, tick: Io.Duration) void {
        while (true) {
            io.sleep(tick, .awake) catch return;
            const now = awakeNs(io);
            t.mutex.lock(io) catch return;
            defer t.mutex.unlock(io);
            for (t.slots) |*s| {
                if (!s.used) continue;
                const d = s.deadline.load(.monotonic);
                if (d == 0 or now < d) continue;
                s.deadline.store(0, .monotonic);
                s.stream.shutdown(io, .both) catch {};
            }
        }
    }
};

fn awakeNs(io: Io) i64 {
    return @intCast(Io.Clock.awake.now(io).toNanoseconds());
}

/// One accepted connection, for `requests`
pub const Connection = struct {
    stream: Io.net.Stream,
    slot: *Slot,
    limits: *const Limits,

    /// The watchdog ends the connection `after` from now; null never
    fn expire(c: Connection, io: Io, after: ?Io.Duration) void {
        const at: i64 = if (after) |d| awakeNs(io) +| @as(i64, @intCast(d.nanoseconds)) else 0;
        c.slot.deadline.store(at, .monotonic);
    }
};

/// Each connection on its own thread until cancelled: async may run it on the accepting
/// thread when the pool is busy, and a browser's idle keep-alive connection then blocks
/// every later one. A failed accept (out of file descriptors) waits a second and retries.
/// `connection` hands its Connection to `requests`; the stream is closed after it returns
pub fn accept(
    comptime scope: @EnumLiteral(),
    io: Io,
    server: *Io.net.Server,
    comptime limits: Limits,
    ctx: anytype,
    comptime connection: fn (@TypeOf(ctx), Connection) void,
) void {
    const log = std.log.scoped(scope);
    const Run = struct {
        fn run(c: @TypeOf(ctx), i: Io, table: *Table, conn: Connection) void {
            defer table.close(i, conn.slot);
            connection(c, conn);
        }
    };
    var slots: [limits.connections]Slot = @splat(.{});
    var table: Table = .{ .slots = &slots };
    var group: Io.Group = .init;
    defer group.cancel(io);
    group.concurrent(io, Table.watch, .{ &table, io, comptime limits.tick() }) catch |err| {
        return log.warn("watchdog: {t}", .{err});
    };
    while (true) {
        const stream = server.accept(io) catch |err| switch (err) {
            error.Canceled => return,
            else => {
                log.warn("accept: {t}", .{err});
                io.sleep(.fromSeconds(1), .awake) catch return;
                continue;
            },
        };
        const slot = table.take(io, stream) orelse {
            log.debug("{d} connections open: refused one", .{limits.connections});
            var buf: [128]u8 = undefined;
            var w = stream.writer(io, &buf);
            answer(&w.interface, "503 Service Unavailable");
            stream.close(io);
            continue;
        };
        const conn: Connection = .{ .stream = stream, .slot = slot, .limits = &limits };
        group.concurrent(io, Run.run, .{ ctx, io, &table, conn }) catch |err| {
            log.warn("connection: {t}", .{err});
            table.close(io, slot);
        };
    }
}

/// An answer with no body that ends the connection
fn answer(w: *Io.Writer, comptime status: []const u8) void {
    w.writeAll("HTTP/1.1 " ++ status ++ "\r\nconnection: close\r\ncontent-length: 0\r\n\r\n") catch return;
    w.flush() catch {};
}

/// Answers requests on `conn` with handle(ctx, *Request) until the client closes it, a
/// limit is passed or a timeout ends it
pub fn requests(
    comptime scope: @EnumLiteral(),
    io: Io,
    conn: Connection,
    ctx: anytype,
    comptime handle: anytype,
    comptime logged: Logged,
) void {
    const log = std.log.scoped(scope);
    const limits = conn.limits;
    // Holds the whole request head: browsers send every localhost port's cookies, often
    // over 8 KB from other dev servers
    var recv_buffer: [64 * 1024]u8 = undefined;
    var send_buffer: [16 * 1024]u8 = undefined;
    var conn_reader = conn.stream.reader(io, &recv_buffer);
    var conn_writer = conn.stream.writer(io, &send_buffer);
    var server = std.http.Server.init(&conn_reader.interface, &conn_writer.interface);
    while (server.reader.state == .ready) {
        conn.expire(io, limits.idle);
        _ = server.reader.in.peek(1) catch return;
        conn.expire(io, limits.head);
        var request = server.receiveHead() catch |err| switch (err) {
            error.HttpConnectionClosing => return,
            error.HttpHeadersOversize => {
                answer(&conn_writer.interface, "431 Request Header Fields Too Large");
                return linger(io, conn, &conn_reader.interface);
            },
            error.HttpHeadersInvalid => {
                answer(&conn_writer.interface, "400 Bad Request");
                return linger(io, conn, &conn_reader.interface);
            },
            else => return log.debug("closing connection: {t}", .{err}),
        };
        conn.expire(io, limits.handle);
        // std's respond() asserts a POST states its body length; a bare `curl -X POST`
        // states none, which would crash the server. No length and no chunking means no
        // body (RFC 9112 6.3)
        if (request.head.transfer_encoding == .none and request.head.content_length == null) {
            request.head.content_length = 0;
        }
        const refused: ?std.http.Status = if (request.head.transfer_encoding != .none)
            .length_required
        else if (request.head.content_length.? > limits.body)
            .payload_too_large
        else
            null;
        if (refused) |status| {
            request.respond("", .{ .status = status, .keep_alive = false }) catch return;
            return linger(io, conn, &conn_reader.interface);
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

/// After an answer to a request we didn't read: closing with unread bytes would reset
/// the connection, and the client could lose the answer before reading it. So read to
/// the client's close, for two seconds at most
fn linger(io: Io, conn: Connection, in: *Io.Reader) void {
    conn.expire(io, .fromSeconds(2));
    conn.stream.shutdown(io, .send) catch return;
    _ = in.discardRemaining() catch {};
}

const Test = struct {
    const io = std.testing.io;
    const limits: Limits = .{
        .connections = 3,
        .body = 16,
        .idle = .fromMilliseconds(300),
        .head = .fromMilliseconds(300),
        .handle = .fromSeconds(5),
    };

    server: Io.net.Server,
    serving: Io.Future(void),

    fn start(t: *Test) !void {
        const address = try Io.net.IpAddress.parse("127.0.0.1", 0);
        t.server = try address.listen(io, .{ .reuse_address = true });
        t.serving = try io.concurrent(serve, .{&t.server});
    }
    fn stop(t: *Test) void {
        t.serving.cancel(io);
        t.server.deinit(io);
    }
    fn serve(s: *Io.net.Server) void {
        accept(.httpd, io, s, limits, {}, connection);
    }
    fn connection(_: void, conn: Connection) void {
        requests(.httpd, io, conn, {}, handle, .path);
    }
    fn handle(_: void, r: *Request) !void {
        try r.respond("ok", .{});
    }

    fn connect(t: *Test) !Io.net.Stream {
        return t.server.socket.address.connect(io, .{ .mode = .stream });
    }
    fn send(c: Io.net.Stream, bytes: []const u8) !void {
        var buf: [256]u8 = undefined;
        var w = c.writer(io, &buf);
        try w.interface.writeAll(bytes);
        try w.interface.flush();
    }
    /// The first bytes back, empty when the server closed the connection; within 5 s
    fn reply(c: Io.net.Stream, got: []u8) ![]const u8 {
        const timeout: Io.Timeout = .{ .duration = .{ .raw = .fromSeconds(5), .clock = .awake } };
        const msg = c.socket.receiveTimeout(io, got, timeout) catch |err| switch (err) {
            error.ConnectionResetByPeer => return "",
            else => return err,
        };
        return msg.data;
    }
    fn ask(t: *Test, head: []const u8, comptime status: []const u8) !void {
        const c = try t.connect();
        defer c.close(io);
        try send(c, head);
        var got: [256]u8 = undefined;
        try std.testing.expectStringStartsWith(try reply(c, &got), "HTTP/1.1 " ++ status);
    }
    fn ok(t: *Test) !void {
        try t.ask("GET / HTTP/1.1\r\nHost: x\r\n\r\n", "200");
    }
};

test "a bodyless POST and a 20 KB head are answered" {
    var t: Test = undefined;
    try t.start();
    defer t.stop();
    try t.ask("POST /x HTTP/1.1\r\nHost: x\r\n\r\n", "200");
    const cookie: [20 * 1024]u8 = @splat('a');
    try t.ask("GET / HTTP/1.1\r\nHost: x\r\nCookie: " ++ cookie ++ "\r\n\r\n", "200");
}

test "an oversize head or body is refused and the server stays up" {
    var t: Test = undefined;
    try t.start();
    defer t.stop();
    const cookie: [70 * 1024]u8 = @splat('a');
    try t.ask("GET / HTTP/1.1\r\nHost: x\r\nCookie: " ++ cookie ++ "\r\n\r\n", "431");
    try t.ok();
    try t.ask("POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 1000000\r\n\r\n" ++ cookie, "413");
    try t.ok();
    try t.ask("POST / HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n0\r\n\r\n", "411");
    try t.ask("GET / HTTP/9.9\r\nHost: x\r\n\r\n", "400");
    try t.ask("POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 16\r\n\r\n0123456789abcdef", "200");
}

test "a slow or idle client is cut off and the server stays up" {
    const io = Test.io;
    var t: Test = undefined;
    try t.start();
    defer t.stop();
    var got: [256]u8 = undefined;
    // Half a head, then nothing
    const slow = try t.connect();
    defer slow.close(io);
    try Test.send(slow, "GET / HTTP/1.1\r\nHo");
    // Nothing at all
    const idle = try t.connect();
    defer idle.close(io);
    try t.ok();
    try std.testing.expectEqualStrings("", try Test.reply(slow, &got));
    try std.testing.expectEqualStrings("", try Test.reply(idle, &got));
    try t.ok();
}

test "past the connection cap a client gets 503 and the server stays up" {
    const io = Test.io;
    var t: Test = undefined;
    try t.start();
    defer t.stop();
    var got: [256]u8 = undefined;
    var held: [Test.limits.connections]Io.net.Stream = undefined;
    for (&held) |*c| c.* = try t.connect();
    const extra = try t.connect();
    defer extra.close(io);
    try std.testing.expectStringStartsWith(try Test.reply(extra, &got), "HTTP/1.1 503");
    for (held) |c| c.close(io);
    // The server frees a slot when it reads the close
    for (0..50) |_| {
        t.ok() catch {
            try io.sleep(.fromMilliseconds(20), .awake);
            continue;
        };
        break;
    } else return error.NoSlotFreed;
}
