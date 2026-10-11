//! Riot rate limits: sliding windows per bucket, seeded with the personal key's
//! limits and corrected from X-*-Rate-Limit headers. One limiter per routing value,
//! owned by one thread, so no locking.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Riot counts a request on arrival in fixed windows; a slightly longer sliding
/// window here stays under either.
const margin_ns: i96 = 750 * std.time.ns_per_ms;
const max_windows = 4;

pub const Window = struct {
    limit: u32,
    seconds: u32,
    /// Send times in ns, oldest first
    hits: std.Deque(i96) = .empty,

    fn span(w: Window) i96 {
        return @as(i96, w.seconds) * std.time.ns_per_s + margin_ns;
    }

    fn prune(w: *Window, now: i96) void {
        while (w.hits.front()) |t| {
            if (now - t < w.span()) break;
            _ = w.hits.popFront();
        }
    }

    /// ns until another request fits, 0 if one fits now
    fn waitNs(w: *Window, now: i96) i96 {
        w.prune(now);
        if (w.hits.len < w.limit) return 0;
        return w.hits.at(w.hits.len - w.limit) + w.span() - now;
    }
};

pub const Bucket = struct {
    windows: std.ArrayList(Window) = .empty,
    blocked_until: i96 = 0,

    fn deinit(b: *Bucket, gpa: Allocator) void {
        for (b.windows.items) |*w| w.hits.deinit(gpa);
        b.windows.deinit(gpa);
    }

    fn waitNs(b: *Bucket, now: i96) i96 {
        var wait = @max(b.blocked_until - now, 0);
        for (b.windows.items) |*w| wait = @max(wait, w.waitNs(now));
        return wait;
    }

    /// Replace limits from a spec like "20:1,100:120", keeping hits of windows
    /// whose length is unchanged
    fn setSpec(b: *Bucket, gpa: Allocator, spec: []const u8) !void {
        var parsed: [max_windows]struct { limit: u32, seconds: u32 } = undefined;
        var n: usize = 0;
        var parts = std.mem.tokenizeScalar(u8, spec, ',');
        while (parts.next()) |part| {
            if (n == max_windows) break;
            const colon = std.mem.indexOfScalar(u8, part, ':') orelse return error.BadSpec;
            const trimmed = std.mem.trim(u8, part[0..colon], " ");
            parsed[n] = .{
                .limit = try std.fmt.parseInt(u32, trimmed, 10),
                .seconds = try std.fmt.parseInt(u32, std.mem.trim(u8, part[colon + 1 ..], " "), 10),
            };
            n += 1;
        }
        var same = n == b.windows.items.len;
        for (parsed[0..n], 0..) |p, i| {
            if (same and (b.windows.items[i].limit != p.limit or
                b.windows.items[i].seconds != p.seconds)) same = false;
        }
        if (same) return;

        var next: std.ArrayList(Window) = .empty;
        errdefer next.deinit(gpa);
        for (parsed[0..n]) |p| {
            var w: Window = .{ .limit = p.limit, .seconds = p.seconds };
            for (b.windows.items) |*old| {
                if (old.seconds == p.seconds) {
                    w.hits = old.hits;
                    old.hits = .empty;
                }
            }
            try next.append(gpa, w);
        }
        b.deinit(gpa);
        b.windows = next;
    }

    /// Riot's X-*-Rate-Limit-Count ("3:1,57:120"): when Riot has seen more requests
    /// than we sent (a restart, a manual call), pad our windows at `now`
    fn syncCounts(b: *Bucket, gpa: Allocator, counts: []const u8, now: i96) !void {
        var parts = std.mem.tokenizeScalar(u8, counts, ',');
        while (parts.next()) |part| {
            const colon = std.mem.indexOfScalar(u8, part, ':') orelse continue;
            const seen = std.fmt.parseInt(u32, std.mem.trim(u8, part[0..colon], " "), 10) catch continue;
            const secs = std.fmt.parseInt(u32, std.mem.trim(u8, part[colon + 1 ..], " "), 10) catch continue;
            for (b.windows.items) |*w| {
                if (w.seconds != secs) continue;
                while (w.hits.len < seen) try w.hits.pushBack(gpa, now);
            }
        }
    }
};

pub const Limiter = struct {
    gpa: Allocator,
    io: std.Io,
    app: Bucket = .{},
    methods: std.StringHashMapUnmanaged(Bucket) = .empty,

    pub const app_default = "20:1,100:120";

    pub fn init(gpa: Allocator, io: std.Io) !Limiter {
        var l: Limiter = .{ .gpa = gpa, .io = io };
        try l.app.setSpec(gpa, app_default);
        return l;
    }

    pub fn deinit(l: *Limiter) void {
        l.app.deinit(l.gpa);
        var it = l.methods.iterator();
        while (it.next()) |e| {
            e.value_ptr.deinit(l.gpa);
            l.gpa.free(e.key_ptr.*);
        }
        l.methods.deinit(l.gpa);
    }

    fn method(l: *Limiter, name: []const u8) !*Bucket {
        const gop = try l.methods.getOrPut(l.gpa, name);
        if (!gop.found_existing) {
            gop.key_ptr.* = try l.gpa.dupe(u8, name);
            gop.value_ptr.* = .{};
        }
        return gop.value_ptr;
    }

    pub fn now(l: *Limiter) i96 {
        return std.Io.Clock.awake.now(l.io).nanoseconds;
    }

    /// Block until a request on `method_name` fits every window, then record it
    pub fn acquire(l: *Limiter, method_name: []const u8) !void {
        const m = try l.method(method_name);
        while (true) {
            const t = l.now();
            const wait = @max(l.app.waitNs(t), m.waitNs(t));
            if (wait <= 0) {
                for (l.app.windows.items) |*w| try w.hits.pushBack(l.gpa, t);
                for (m.windows.items) |*w| try w.hits.pushBack(l.gpa, t);
                return;
            }
            try l.io.sleep(.fromNanoseconds(wait), .awake);
        }
    }

    pub const Headers = struct {
        app_limit: ?[]const u8 = null,
        app_count: ?[]const u8 = null,
        method_limit: ?[]const u8 = null,
        method_count: ?[]const u8 = null,
    };

    pub fn update(l: *Limiter, method_name: []const u8, h: Headers) !void {
        const t = l.now();
        const m = try l.method(method_name);
        if (h.app_limit) |spec| try l.app.setSpec(l.gpa, spec);
        if (h.app_count) |counts| try l.app.syncCounts(l.gpa, counts, t);
        if (h.method_limit) |spec| try m.setSpec(l.gpa, spec);
        if (h.method_count) |counts| try m.syncCounts(l.gpa, counts, t);
    }

    pub const Scope = enum { app, method };

    pub fn block(l: *Limiter, scope: Scope, method_name: []const u8, seconds: u32) !void {
        const until = l.now() + @as(i96, seconds) * std.time.ns_per_s;
        const b = if (scope == .app) &l.app else try l.method(method_name);
        b.blocked_until = @max(b.blocked_until, until);
    }
};

const testing = std.testing;

test "spec parsing keeps hits of unchanged windows" {
    var l = try Limiter.init(testing.allocator, testing.io);
    defer l.deinit();
    try l.acquire("m");
    try l.update("m", .{ .app_limit = "20:1,100:120,1000:600" });
    try testing.expectEqual(@as(usize, 3), l.app.windows.items.len);
    try testing.expectEqual(@as(usize, 1), l.app.windows.items[1].hits.len);
    try testing.expectEqual(@as(usize, 0), l.app.windows.items[2].hits.len);
}

test "riot counts pad our windows" {
    var l = try Limiter.init(testing.allocator, testing.io);
    defer l.deinit();
    try l.acquire("m");
    try l.update("m", .{ .app_count = "1:1,57:120", .method_limit = "50:10", .method_count = "3:10" });
    try testing.expectEqual(@as(usize, 1), l.app.windows.items[0].hits.len);
    try testing.expectEqual(@as(usize, 57), l.app.windows.items[1].hits.len);
    try testing.expectEqual(@as(usize, 3), l.methods.getPtr("m").?.windows.items[0].hits.len);
}

test "acquire waits once a window is full" {
    var l = try Limiter.init(testing.allocator, testing.io);
    defer l.deinit();
    try l.update("m", .{ .app_limit = "3:1" });
    const start = l.now();
    for (0..4) |_| try l.acquire("m");
    const elapsed_ms = @divTrunc(l.now() - start, std.time.ns_per_ms);
    try testing.expect(elapsed_ms >= 1000 and elapsed_ms < 2500);
}
