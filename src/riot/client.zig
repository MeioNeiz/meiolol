//! HTTPS client for *.api.riotgames.com with rate limiting and retries.
//! One per thread: each owns its connection pool and limiter.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Limiter = @import("ratelimit.zig").Limiter;
const Fake = @import("fake.zig").Fake;

const log = std.log.scoped(.riot);

pub const Client = struct {
    gpa: Allocator,
    io: std.Io,
    http: std.http.Client,
    limiter: Limiter,
    key: []const u8,
    requests: std.atomic.Value(u64) = .init(0),
    /// Benchmarks only: answers instead of Riot, no rate limits
    fake: ?*const Fake = null,

    pub fn init(gpa: Allocator, io: std.Io, key: []const u8) !Client {
        return .{
            .gpa = gpa,
            .io = io,
            .http = .{ .allocator = gpa, .io = io },
            .limiter = try .init(gpa, io),
            .key = key,
        };
    }

    pub fn deinit(c: *Client) void {
        c.http.deinit();
        c.limiter.deinit();
    }

    /// Response body (caller frees) on 200, null on 404. `method` names the
    /// per-endpoint rate limit bucket.
    pub fn get(c: *Client, route: []const u8, path: []const u8, method: []const u8) !?[]u8 {
        var url_buf: [1024]u8 = undefined;
        const url = try std.fmt.bufPrint(&url_buf, "https://{s}.api.riotgames.com{s}", .{
            route, path,
        });
        const uri = try std.Uri.parse(url);
        if (c.fake) |f| {
            _ = c.requests.fetchAdd(1, .monotonic);
            return f.get(c.gpa, route, path);
        }
        const shown = logged(path, method);
        for (0..6) |attempt| {
            const backoff: i64 = @as(i64, 1) << @intCast(attempt);
            try c.limiter.acquire(method);
            const shared = c.limiter.sharing();
            const res = c.once(uri, method, backoff) catch |err| switch (err) {
                error.OutOfMemory => return err,
                else => {
                    log.warn("{s} on {s}, retrying", .{ @errorName(err), shown });
                    try c.io.sleep(.fromSeconds(backoff), .awake);
                    continue;
                },
            };
            if (!shared and c.limiter.sharing()) {
                log.info("{s}: another process is using the key, leaving it {d}% for {d} min", .{
                    route, c.limiter.reserve_pct, Limiter.shared_hold_s / 60,
                });
            }
            _ = c.requests.fetchAdd(1, .monotonic);
            switch (res.status) {
                200 => return res.body,
                404 => {
                    c.gpa.free(res.body);
                    return null;
                },
                401, 403 => {
                    c.gpa.free(res.body);
                    log.err("{d} on {s}: key missing or expired", .{ res.status, shown });
                    return error.KeyRejected;
                },
                429 => {
                    c.gpa.free(res.body);
                    continue;
                },
                else => {
                    c.gpa.free(res.body);
                    log.warn("{d} on {s}, retrying", .{ res.status, shown });
                    if (res.status < 500) return error.UnexpectedStatus;
                    try c.io.sleep(.fromSeconds(backoff), .awake);
                },
            }
        }
        return error.GaveUp;
    }

    const Response = struct { status: u16, body: []u8 };

    /// The path for logs, except where it holds a Riot ID: then the endpoint's name
    fn logged(path: []const u8, method: []const u8) []const u8 {
        return if (std.mem.indexOf(u8, path, "/by-riot-id/") != null) method else path;
    }

    fn once(c: *Client, uri: std.Uri, method: []const u8, backoff: i64) !Response {
        var req = try c.http.request(.GET, uri, .{
            .extra_headers = &.{.{ .name = "X-Riot-Token", .value = c.key }},
            .headers = .{ .accept_encoding = .omit },
            .redirect_behavior = .not_allowed,
        });
        defer req.deinit();
        try req.sendBodiless();
        var response = try req.receiveHead(&.{});
        const status: u16 = @intFromEnum(response.head.status);

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
        try c.limiter.update(method, h);
        if (status == 429) {
            const wait: u32 = retry_after orelse @intCast(backoff);
            log.warn("429 ({s}) on {s}, waiting {d}s", .{ limit_type, logged(uri.path.percent_encoded, method), wait });
            const scope: Limiter.Scope = if (std.mem.eql(u8, limit_type, "method")) .method else .app;
            try c.limiter.block(scope, method, wait);
        }

        var transfer: [64]u8 = undefined;
        const body = try response.reader(&transfer).allocRemaining(c.gpa, .limited(16 << 20));
        return .{ .status = status, .body = body };
    }
};
