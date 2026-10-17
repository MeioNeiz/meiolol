//! HTTPS client for *.api.riotgames.com with rate limiting and retries, or for the same
//! calls through the crawler's proxy (proxy.zig). One per thread: each owns its
//! connection pool; the limiter is shared per route.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Limiter = @import("ratelimit.zig").Limiter;
const Fake = @import("fake.zig").Fake;

const log = std.log.scoped(.riot);

pub const Client = struct {
    gpa: Allocator,
    io: std.Io,
    http: std.http.Client,
    /// Null through a proxy, which limits
    limiter: ?*Limiter,
    key: []const u8,
    /// Takes the limiter's next free slot ahead of callers without priority
    priority: bool = false,
    /// Base URL of a crawler's proxy ("http://10.0.0.3:8092"), instead of Riot
    proxy: ?[]const u8 = null,
    requests: std.atomic.Value(u64) = .init(0),
    /// Benchmarks only: answers instead of Riot, no rate limits
    fake: ?*const Fake = null,

    pub fn init(gpa: Allocator, io: std.Io, key: []const u8, limiter: *Limiter) Client {
        return .{ .gpa = gpa, .io = io, .http = .{ .allocator = gpa, .io = io }, .limiter = limiter, .key = key };
    }

    pub fn initProxy(gpa: Allocator, io: std.Io, base_url: []const u8) Client {
        return .{ .gpa = gpa, .io = io, .http = .{ .allocator = gpa, .io = io }, .limiter = null, .key = "", .proxy = base_url };
    }

    pub fn deinit(c: *Client) void {
        c.http.deinit();
    }

    /// Response body (caller frees) on 200, null on 404. `method` names the
    /// per-endpoint rate limit bucket. error.RateLimited when every try got a 429: the
    /// key or Riot's service was saturated, nothing wrong with the request itself
    pub fn get(c: *Client, route: []const u8, path: []const u8, method: []const u8) !?[]u8 {
        if (c.proxy) |base| return c.viaProxy(base, route, path, method);
        const limiter = c.limiter.?;
        var url_buf: [1024]u8 = undefined;
        const url = try std.mem.print(&url_buf, "https://{s}.api.riotgames.com{s}", .{
            route, path,
        });
        const uri = try std.Uri.parse(url);
        if (c.fake) |f| {
            _ = c.requests.fetchAdd(1, .monotonic);
            return f.get(c.gpa, route, path);
        }
        const shown = logged(path, method);
        var limited: usize = 0;
        for (0..tries) |attempt| {
            const backoff: i64 = @as(i64, 1) << @intCast(attempt);
            try limiter.acquire(method, c.priority);
            const res = c.once(limiter, uri, method, backoff) catch |err| switch (err) {
                error.OutOfMemory => return err,
                else => {
                    log.warn("{s} on {s}, retrying", .{ @errorName(err), shown });
                    try c.io.sleep(.fromSeconds(backoff), .awake);
                    continue;
                },
            };
            _ = c.requests.fetchAdd(1, .monotonic);
            switch (res.status) {
                200 => return res.body,
                404 => {
                    c.gpa.free(res.body);
                    return null;
                },
                401, 403 => {
                    defer c.gpa.free(res.body);
                    if (res.status == 403 and !fromRiot(res.body)) {
                        log.warn("403 on {s}: an HTML page, Riot's edge refusing this request, not the key", .{shown});
                        return error.Blocked;
                    }
                    log.err("{d} on {s}: key missing or expired", .{ res.status, shown });
                    return error.KeyRejected;
                },
                429 => {
                    c.gpa.free(res.body);
                    limited += 1;
                    continue;
                },
                else => {
                    c.gpa.free(res.body);
                    if (res.status < 500) {
                        log.warn("{d} on {s}", .{ res.status, shown });
                        return error.UnexpectedStatus;
                    }
                    log.warn("{d} on {s}, retrying", .{ res.status, shown });
                    try c.io.sleep(.fromSeconds(backoff), .awake);
                },
            }
        }
        return if (limited == tries) error.RateLimited else error.GaveUp;
    }

    const tries = 6;

    /// Riot's own error body, `{"status": {"message": ..., "status_code": ...}}`. Its
    /// Cloudflare edge answers some URLs with an HTML block page instead (16 Oct: one TW2
    /// PUUID, a 403 on every host, which stopped the crawler for hours as a rejected key)
    fn fromRiot(body: []const u8) bool {
        const t = std.mem.trimStart(u8, body, " \t\r\n");
        return t.len > 0 and t[0] == '{' and std.mem.indexOf(u8, t, "\"status_code\"") != null;
    }

    /// The proxy answers as Riot would, except: 503 when the crawler's tries ran out,
    /// 502 on an unexpected status. Unreachable (the crawler restarting) is retried for
    /// about two minutes. A key Riot rejects there is the box's to fix, so here it fails
    /// the job instead of stopping the caller
    fn viaProxy(c: *Client, base: []const u8, route: []const u8, path: []const u8, method: []const u8) !?[]u8 {
        var url_buf: [1024]u8 = undefined;
        const uri = try std.Uri.parse(try std.mem.print(&url_buf, "{s}/riot/{s}{s}", .{ base, route, path }));
        const shown = logged(path, method);
        for (0..proxy_tries) |attempt| {
            const res = c.proxied(uri, method) catch |err| switch (err) {
                error.OutOfMemory, error.Canceled => return err,
                else => {
                    const backoff = @min(@as(i64, 1) << @intCast(attempt), 30);
                    log.warn("proxy: {s} on {s}, retrying in {d}s", .{ @errorName(err), shown, backoff });
                    try c.io.sleep(.fromSeconds(backoff), .awake);
                    continue;
                },
            };
            _ = c.requests.fetchAdd(1, .monotonic);
            switch (res.status) {
                200 => return res.body,
                404 => {
                    c.gpa.free(res.body);
                    return null;
                },
                else => {
                    c.gpa.free(res.body);
                    log.warn("proxy: {d} on {s}", .{ res.status, shown });
                    return switch (res.status) {
                        401, 403 => error.ProxyKeyRejected,
                        503 => error.GaveUp,
                        else => error.UnexpectedStatus,
                    };
                },
            }
        }
        return error.ProxyUnreachable;
    }

    const proxy_tries = 9;
    pub const method_header = "x-meiolol-method";

    fn proxied(c: *Client, uri: std.Uri, method: []const u8) !Response {
        var req = try c.http.request(.GET, uri, .{
            .extra_headers = &.{.{ .name = method_header, .value = method }},
            .redirect_behavior = .not_allowed,
        });
        defer req.deinit();
        errdefer dropConnection(&req);
        try req.sendBodiless();
        var response = try req.receiveHead(&.{});
        const want = response.head.content_length;
        var transfer: [64]u8 = undefined;
        const body = try readBody(c.gpa, response.reader(&transfer), want);
        return .{ .status = @backingInt(response.head.status), .body = body };
    }

    /// The whole body, or error.ShortBody. std.http passes the connection's end of
    /// stream through when it comes before Content-Length, and allocRemaining takes that
    /// for the body's end, so a dropped connection gave a cut body as a 200 (11 to 17
    /// Oct: 11 timelines and a summary, some cut at exactly 96 or 144 KiB). A chunked
    /// body cut short is already an error there (HttpChunkTruncated)
    fn readBody(gpa: Allocator, r: *std.Io.Reader, content_length: ?u64) ![]u8 {
        const body = try r.allocRemaining(gpa, .limited(16 << 20));
        if (content_length) |n| if (body.len != n) {
            gpa.free(body);
            return error.ShortBody;
        };
        return body;
    }

    const Response = struct { status: u16, body: []u8 };

    /// Request.deinit pools a connection whose send failed (no head read, so it looks
    /// idle): every retry to that host would reuse the dead socket and fail the same way
    fn dropConnection(req: *std.http.Client.Request) void {
        if (req.connection) |conn| conn.closing = true;
    }

    /// The path for logs, except where it holds a Riot ID: then the endpoint's name
    fn logged(path: []const u8, method: []const u8) []const u8 {
        return if (std.mem.indexOf(u8, path, "/by-riot-id/") != null) method else path;
    }

    fn once(c: *Client, limiter: *Limiter, uri: std.Uri, method: []const u8, backoff: i64) !Response {
        var req = try c.http.request(.GET, uri, .{
            .extra_headers = &.{.{ .name = "X-Riot-Token", .value = c.key }},
            .headers = .{ .accept_encoding = .omit },
            .redirect_behavior = .not_allowed,
        });
        defer req.deinit();
        errdefer dropConnection(&req);
        try req.sendBodiless();
        var response = try req.receiveHead(&.{});
        const status: u16 = @backingInt(response.head.status);

        // Header slices die once the body reader starts, so use them now
        var h: Limiter.Headers = .{};
        var retry_after: ?u32 = null;
        var limit_type: []const u8 = "service";
        var it = response.head.iterateHeaders();
        while (it.next()) |header| {
            const eql = std.ascii.eqlIgnoreCase;
            if (eql(header.name, "x-app-rate-limit")) h.app_limit = header.value;
            if (eql(header.name, "x-app-rate-limit-count")) h.app_count = header.value;
            if (eql(header.name, "x-method-rate-limit")) h.method_limit = header.value;
            if (eql(header.name, "x-method-rate-limit-count")) h.method_count = header.value;
            if (eql(header.name, "x-rate-limit-type")) limit_type = header.value;
            if (eql(header.name, "retry-after")) {
                retry_after = std.fmt.parseInt(u32, header.value, 10) catch null;
            }
        }
        try limiter.update(method, h);
        if (status == 429) {
            const wait: u32 = retry_after orelse @intCast(backoff);
            log.warn("429 ({s}) on {s}, waiting {d}s", .{ limit_type, logged(uri.path.percent_encoded, method), wait });
            const scope: Limiter.Scope = if (std.mem.eql(u8, limit_type, "method")) .method else .app;
            try limiter.block(scope, method, wait);
        }

        const want = response.head.content_length;
        var transfer: [64]u8 = undefined;
        const body = try readBody(c.gpa, response.reader(&transfer), want);
        return .{ .status = status, .body = body };
    }
};

/// A response's body as once() and proxied() read it, from raw bytes
fn testBody(gpa: Allocator, bytes: []const u8) ![]u8 {
    var in: std.Io.Reader = .fixed(bytes);
    var r: std.http.Reader = .{ .in = &in, .interface = undefined, .state = .ready, .max_head_len = 4096 };
    const head = try std.http.Client.Response.Head.parse(try r.receiveHead());
    var transfer: [64]u8 = undefined;
    return Client.readBody(gpa, r.bodyReader(&transfer, head.transfer_encoding, head.content_length), head.content_length);
}

test "a body cut short is an error, not a shorter 200" {
    const gpa = std.testing.allocator;
    const doc = "{\"metadata\":{\"matchId\":\"OC1_1\"}}";
    const head = std.fmt.comptimePrint("HTTP/1.1 200 OK\r\nContent-Length: {d}\r\n\r\n", .{doc.len});
    const whole = try testBody(gpa, head ++ doc);
    defer gpa.free(whole);
    try std.testing.expectEqualStrings(doc, whole);
    try std.testing.expectError(error.ShortBody, testBody(gpa, head ++ doc[0..20]));
    try std.testing.expectError(error.ShortBody, testBody(gpa, head));
    const chunked = std.fmt.comptimePrint("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n{x}\r\n", .{doc.len}) ++ doc;
    const all = try testBody(gpa, chunked ++ "\r\n0\r\n\r\n");
    defer gpa.free(all);
    try std.testing.expectEqualStrings(doc, all);
    try std.testing.expectError(error.ReadFailed, testBody(gpa, chunked[0 .. chunked.len - 10]));
}

test "a 403 is the key's only when Riot says so" {
    try std.testing.expect(Client.fromRiot("{\"status\":{\"message\":\"Forbidden\",\"status_code\":403}}"));
    try std.testing.expect(!Client.fromRiot("<!DOCTYPE html>\n<html><head><title>Attention Required! | Cloudflare</title>"));
    try std.testing.expect(!Client.fromRiot(""));
}
