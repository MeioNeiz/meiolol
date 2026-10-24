//! The desktop app's sign in to meio.lol (docs/plan/accounts.md AC4): a username and
//! password once, POST /auth/device, and the token it answers kept in device.token beside
//! the exe. Update checks send it as Authorization: Bearer (update.zig). The server keeps
//! only its hash; removing the app on the account page, logging out everywhere or a new
//! password ends it, and the next check's 401 brings the sign-in form back.

const std = @import("std");
const Io = std.Io;
const client = @import("net").client;

pub const token_file = "device.token";
pub const default_url = "https://meio.lol/auth/device";
/// What the account page lists it as: no computer name, which would be personal data
pub const name = "Windows app";

/// The token in device.token in `dir`, trimmed; null when there is none
pub fn read(arena: std.mem.Allocator, io: Io, dir: Io.Dir) ?[]const u8 {
    const raw = dir.readFileAlloc(io, token_file, arena, .limited(4096)) catch return null;
    const t = std.mem.trim(u8, raw, " \t\r\n");
    return if (t.len > 0) t else null;
}

pub fn forget(io: Io, dir: Io.Dir) void {
    dir.deleteFile(io, token_file) catch {};
}

pub const Answer = union(enum) {
    /// Saved in device.token; in `arena`
    token: []const u8,
    /// The server's reason (wrong password, too many tries, ...), for the form; in `arena`
    refused: []const u8,
};

/// A server that doesn't answer in this long is error.Timeout
pub const timeout: Io.Duration = .fromSeconds(20);

/// One sign in. A refusal is an answer, not an error; errors are the network's
pub fn signIn(arena: std.mem.Allocator, gpa: std.mem.Allocator, io: Io, dir: Io.Dir, url: []const u8, username: []const u8, password: []const u8) !Answer {
    var http: std.http.Client = .{ .allocator = gpa, .io = io };
    defer http.deinit();
    const payload = try std.json.Stringify.valueAlloc(arena, .{ .username = username, .password = password, .name = name }, .{});
    // Never redirected, so the password goes to this host only
    const res = try client.get(&http, arena, .{
        .url = url,
        .method = .POST,
        .payload = payload,
        .content_type = "application/json",
        .headers = &.{.{ .name = "x-meiolol-action", .value = "1" }},
        .max_body = 64 * 1024,
        // The form shows "Signing in..." until this returns
        .timeout = timeout,
    });
    const Reply = struct { token: []const u8 = "", @"error": []const u8 = "", retry_s: i64 = 0 };
    const reply = std.json.parseFromSliceLeaky(Reply, arena, res.body, .{ .ignore_unknown_fields = true }) catch Reply{};
    if (res.status == .ok and reply.token.len > 0) {
        try dir.writeFile(io, .{ .sub_path = token_file, .data = reply.token });
        return .{ .token = reply.token };
    }
    return .{ .refused = switch (res.status) {
        .too_many_requests => try arena.print("Too many tries: wait {d} min.", .{@max(1, @divFloor(reply.retry_s + 59, 60))}),
        .unauthorized, .forbidden, .conflict => if (reply.@"error".len > 0) try sentence(arena, reply.@"error") else "Wrong username or password.",
        else => try arena.print("meio.lol answered {d}; try again in a moment.", .{@backingInt(res.status)}),
    } };
}

/// "wrong username or password" as the form shows it
fn sentence(arena: std.mem.Allocator, text: []const u8) ![]const u8 {
    const s = try arena.print("{s}.", .{text});
    s[0] = std.ascii.toUpper(s[0]);
    return s;
}

const httpd = @import("net").server;

/// Answers POST /auth/device as accounts.zig does, for "friend" with "right"
const TestServer = struct {
    fn serve(t: *TestServer, s: *Io.net.Server) void {
        httpd.accept(.device_test, std.testing.io, s, .local, t, connection);
    }
    fn connection(t: *TestServer, conn: httpd.Connection) void {
        httpd.requests(.device_test, std.testing.io, conn, t, handle, .path);
    }
    fn handle(_: *TestServer, r: *std.http.Server.Request) !void {
        var action = false;
        var it = r.iterateHeaders();
        while (it.next()) |h| {
            if (std.ascii.eqlIgnoreCase(h.name, "x-meiolol-action")) action = std.mem.eql(u8, h.value, "1");
        }
        var buf: [1024]u8 = undefined;
        var body_buf: [256]u8 = undefined;
        const reader = try r.readerExpectContinue(&body_buf);
        const n = try reader.readSliceShort(&buf);
        const body = buf[0..n];
        if (!action) return r.respond("{\"error\":\"missing X-Meiolol-Action\"}", .{ .status = .forbidden });
        if (std.mem.find(u8, body, "\"name\":\"" ++ name ++ "\"") == null) return r.respond("", .{ .status = .bad_request });
        if (std.mem.find(u8, body, "\"password\":\"slow\"") != null) return r.respond("{\"error\":\"too many tries\",\"retry_s\":61}", .{ .status = .too_many_requests });
        if (std.mem.find(u8, body, "{\"username\":\"friend\",\"password\":\"right\"") == null) return r.respond("{\"error\":\"wrong username or password\"}", .{ .status = .unauthorized });
        try r.respond("{\"token\":\"T0KEN\",\"username\":\"friend\",\"role\":\"private\"}", .{});
    }
};

test "signIn keeps the token, or says why not" {
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const address = try Io.net.IpAddress.parse("127.0.0.1", 0);
    var server = try address.listen(io, .{ .reuse_address = true });
    defer server.deinit(io);
    var ts: TestServer = .{};
    var serving = try io.concurrent(TestServer.serve, .{ &ts, &server });
    defer serving.cancel(io);
    const url = try arena.print("http://127.0.0.1:{d}/auth/device", .{server.socket.address.getPort()});
    const gpa = std.testing.allocator;

    const wrong = try signIn(arena, gpa, io, tmp.dir, url, "friend", "guess");
    try std.testing.expectEqualStrings("Wrong username or password.", wrong.refused);
    try std.testing.expectEqual(null, read(arena, io, tmp.dir));
    const slow = try signIn(arena, gpa, io, tmp.dir, url, "friend", "slow");
    try std.testing.expectEqualStrings("Too many tries: wait 2 min.", slow.refused);

    const ok = try signIn(arena, gpa, io, tmp.dir, url, "friend", "right");
    try std.testing.expectEqualStrings("T0KEN", ok.token);
    try std.testing.expectEqualStrings("T0KEN", read(arena, io, tmp.dir).?);
    forget(io, tmp.dir);
    try std.testing.expectEqual(null, read(arena, io, tmp.dir));
}
