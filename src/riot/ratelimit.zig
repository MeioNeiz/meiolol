//! Riot rate limits: sliding windows per bucket, seeded with the personal key's
//! limits and corrected from X-*-Rate-Limit headers. One limiter per routing value in
//! a process, shared by everything calling that route (the crawl thread and proxied
//! Your games requests), so they queue for one budget and priority callers go first.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Riot counts a request on arrival in fixed windows; a slightly longer sliding
/// window here stays under either.
const margin_ns: i96 = 750 * std.time.ns_per_ms;
const max_windows = 4;
/// Paced callers may run this many requests ahead of one per span / limit, making up
/// the slots a slow answer or a busy database cost them (a thread sends one request at
/// a time). The window's limit still holds
const catch_up = 16;

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

    /// ns until another request fits, 0 if one fits now. Paced: also one per span / limit
    /// on average, at most `catch_up` ahead, so the window fills evenly instead of in a
    /// burst, and a slot frees every span / limit for a priority caller instead of once
    /// the burst slides out
    fn waitNs(w: *Window, now: i96, paced: bool) i96 {
        w.prune(now);
        const limit = @max(1, w.limit);
        var wait: i96 = 0;
        if (w.hits.len >= limit) wait = w.hits.at(w.hits.len - limit) + w.span() - now;
        if (paced and w.hits.len > 0) {
            const k = @min(w.hits.len, catch_up);
            wait = @max(wait, w.hits.at(w.hits.len - k) + @divTrunc(w.span() * k, limit) - now);
        }
        return @max(wait, 0);
    }
};

pub const Bucket = struct {
    windows: std.ArrayList(Window) = .empty,
    blocked_until: i96 = 0,

    fn deinit(b: *Bucket, gpa: Allocator) void {
        for (b.windows.items) |*w| w.hits.deinit(gpa);
        b.windows.deinit(gpa);
    }

    fn waitNs(b: *Bucket, now: i96, paced: bool) i96 {
        var wait = @max(b.blocked_until - now, 0);
        for (b.windows.items) |*w| wait = @max(wait, w.waitNs(now, paced));
        return wait;
    }

    /// Replace limits from a spec like "20:1,100:120", keeping hits of windows whose
    /// length is unchanged
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

    /// Riot's X-*-Rate-Limit-Count ("3:1,57:120") on the answer to one of our requests:
    /// when Riot has seen more requests than we sent (a restart, a dev run on the same
    /// key), pad our windows at `now`
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
    /// Only under `mutex`: a rehash moves the buckets
    methods: std.StringHashMapUnmanaged(Bucket) = .empty,
    /// Even spacing in every window for callers without priority (Window.waitNs)
    paced: bool = false,
    /// Priority callers waiting for a slot; the others hold back while there are any
    priority_waiting: u32 = 0,
    mutex: std.Io.Mutex = .init,

    pub const app_default = "20:1,100:120";
    /// How often a caller without priority looks again while a priority one waits
    const yield_ns = 20 * std.time.ns_per_ms;

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
            gop.key_ptr.* = l.gpa.dupe(u8, name) catch |err| {
                l.methods.removeByPtr(gop.key_ptr);
                return err;
            };
            gop.value_ptr.* = .{};
        }
        return gop.value_ptr;
    }

    pub fn now(l: *Limiter) i96 {
        return std.Io.Clock.awake.now(l.io).nanoseconds;
    }

    /// Block until a request on `method_name` fits every window, then record it.
    /// Priority: the next free slot, unpaced, ahead of every caller without priority
    pub fn acquire(l: *Limiter, method_name: []const u8, priority: bool) !void {
        if (priority) l.countPriority(1);
        defer if (priority) l.countPriority(-1);
        while (true) {
            const wait = try l.take(method_name, priority);
            if (wait <= 0) return;
            try l.io.sleep(.fromNanoseconds(wait), .awake);
        }
    }

    fn countPriority(l: *Limiter, delta: i2) void {
        l.mutex.lockUncancelable(l.io);
        defer l.mutex.unlock(l.io);
        if (delta > 0) l.priority_waiting += 1 else l.priority_waiting -= 1;
    }

    /// Records the request and returns 0 when it fits now, else ns until it may
    fn take(l: *Limiter, method_name: []const u8, priority: bool) !i96 {
        l.mutex.lockUncancelable(l.io);
        defer l.mutex.unlock(l.io);
        const m = try l.method(method_name);
        const t = l.now();
        const paced = l.paced and !priority;
        var wait = @max(l.app.waitNs(t, paced), m.waitNs(t, paced));
        if (!priority and l.priority_waiting > 0) wait = @max(wait, yield_ns);
        if (wait > 0) return wait;
        for (l.app.windows.items) |*w| try w.hits.pushBack(l.gpa, t);
        for (m.windows.items) |*w| try w.hits.pushBack(l.gpa, t);
        return 0;
    }

    pub const Headers = struct {
        app_limit: ?[]const u8 = null,
        app_count: ?[]const u8 = null,
        method_limit: ?[]const u8 = null,
        method_count: ?[]const u8 = null,
    };

    pub fn update(l: *Limiter, method_name: []const u8, h: Headers) !void {
        l.mutex.lockUncancelable(l.io);
        defer l.mutex.unlock(l.io);
        const t = l.now();
        const m = try l.method(method_name);
        if (h.app_limit) |spec| try l.app.setSpec(l.gpa, spec);
        if (h.app_count) |counts| try l.app.syncCounts(l.gpa, counts, t);
        if (h.method_limit) |spec| try m.setSpec(l.gpa, spec);
        if (h.method_count) |counts| try m.syncCounts(l.gpa, counts, t);
    }

    pub const Scope = enum { app, method };

    pub fn block(l: *Limiter, scope: Scope, method_name: []const u8, seconds: u32) !void {
        l.mutex.lockUncancelable(l.io);
        defer l.mutex.unlock(l.io);
        const until = l.now() + @as(i96, seconds) * std.time.ns_per_s;
        const b = if (scope == .app) &l.app else try l.method(method_name);
        b.blocked_until = @max(b.blocked_until, until);
    }
};

/// One limiter per routing value (Riot counts per key and route): regions, then
/// platforms
pub const Limiters = struct {
    all: [regions.len + ep.platforms.len]Limiter,

    const ep = @import("endpoints.zig");
    const regions = std.enums.values(ep.Region);

    pub fn init(gpa: Allocator, io: std.Io) !Limiters {
        var l: Limiters = undefined;
        for (&l.all, 0..) |*limiter, i| {
            limiter.* = Limiter.init(gpa, io) catch |err| {
                for (l.all[0..i]) |*done| done.deinit();
                return err;
            };
        }
        return l;
    }

    pub fn deinit(l: *Limiters) void {
        for (&l.all) |*limiter| limiter.deinit();
    }

    /// "europe", "euw1": index into `all`
    pub fn index(route: []const u8) ?usize {
        for (regions, 0..) |r, i| if (std.mem.eql(u8, @tagName(r), route)) return i;
        for (ep.platforms, 0..) |p, i| if (std.mem.eql(u8, p.host, route)) return regions.len + i;
        return null;
    }

    pub fn get(l: *Limiters, route: []const u8) ?*Limiter {
        return &l.all[index(route) orelse return null];
    }

    fn routeName(i: usize) []const u8 {
        return if (i < regions.len) @tagName(regions[i]) else ep.platforms[i - regions.len].host;
    }

    /// Each route's app windows, a line "route seconds ms ms ..." of send times in real
    /// ms, for the next process (a deploy's restart) to load. Without them it padded
    /// Riot's counts at its start (syncCounts), held back a whole window
    pub fn save(l: *Limiters, w: *std.Io.Writer, real_ms: i64) !void {
        for (&l.all, 0..) |*limiter, i| {
            limiter.mutex.lockUncancelable(limiter.io);
            defer limiter.mutex.unlock(limiter.io);
            const now = limiter.now();
            for (limiter.app.windows.items) |*win| {
                win.prune(now);
                if (win.hits.len == 0) continue;
                try w.print("{s} {d}", .{ routeName(i), win.seconds });
                for (0..win.hits.len) |j| {
                    try w.print(" {d}", .{real_ms - @as(i64, @intCast(@divTrunc(now - win.hits.at(j), std.time.ns_per_ms)))});
                }
                try w.writeByte('\n');
            }
        }
    }

    /// What save wrote, into windows of the same length; how many send times were
    /// still in their window
    pub fn load(l: *Limiters, text: []const u8, real_ms: i64) !usize {
        var loaded: usize = 0;
        var lines = std.mem.tokenizeScalar(u8, text, '\n');
        while (lines.next()) |line| {
            var fields = std.mem.tokenizeScalar(u8, line, ' ');
            const limiter = l.get(fields.next() orelse continue) orelse continue;
            const seconds = std.fmt.parseInt(u32, fields.next() orelse continue, 10) catch continue;
            limiter.mutex.lockUncancelable(limiter.io);
            defer limiter.mutex.unlock(limiter.io);
            const now = limiter.now();
            for (limiter.app.windows.items) |*win| {
                if (win.seconds != seconds or win.hits.len > 0) continue;
                while (fields.next()) |field| {
                    const ms = std.fmt.parseInt(i64, field, 10) catch continue;
                    const t = now - @as(i96, @max(real_ms - ms, 0)) * std.time.ns_per_ms;
                    if (now - t >= win.span()) continue;
                    try win.hits.pushBack(limiter.gpa, t);
                    loaded += 1;
                }
            }
        }
        return loaded;
    }
};

const testing = std.testing;

test "spec parsing keeps hits of unchanged windows" {
    var l = try Limiter.init(testing.allocator, testing.io);
    defer l.deinit();
    try l.acquire("m", false);
    try l.update("m", .{ .app_limit = "20:1,100:120,1000:600" });
    try testing.expectEqual(@as(usize, 3), l.app.windows.items.len);
    try testing.expectEqual(@as(usize, 1), l.app.windows.items[1].hits.len);
    try testing.expectEqual(@as(usize, 0), l.app.windows.items[2].hits.len);
}

test "riot counts pad our windows" {
    var l = try Limiter.init(testing.allocator, testing.io);
    defer l.deinit();
    try l.acquire("m", false);
    try l.update("m", .{ .app_count = "1:1,57:120", .method_limit = "50:10", .method_count = "3:10" });
    try testing.expectEqual(@as(usize, 1), l.app.windows.items[0].hits.len);
    try testing.expectEqual(@as(usize, 57), l.app.windows.items[1].hits.len);
    try testing.expectEqual(@as(usize, 3), l.methods.getPtr("m").?.windows.items[0].hits.len);
}

test "acquire waits once a window is full" {
    var l = try Limiter.init(testing.allocator, testing.io);
    defer l.deinit();
    try l.update("m", .{ .app_limit = "3:1" });
    for (0..3) |_| try l.acquire("m", false);
    // Back-dated so the window frees in 100 ms, not a real 1.75 s
    const w = &l.app.windows.items[0];
    const start = l.now();
    for (0..3) |i| w.hits.atPtr(i).* = start - w.span() + 100 * std.time.ns_per_ms;
    try l.acquire("m", false);
    const elapsed_ms = @divTrunc(l.now() - start, std.time.ns_per_ms);
    try testing.expect(elapsed_ms >= 100 and elapsed_ms < 1000);
}

test "a priority caller takes the next slot, ahead of paced callers" {
    var l = try Limiter.init(testing.allocator, testing.io);
    defer l.deinit();
    l.paced = true;
    try l.update("m", .{ .app_limit = "100:120" });
    try l.acquire("m", false);
    // Paced, the next is due in 1.2 s; priority goes now
    try testing.expect(try l.take("m", false) > std.time.ns_per_s);
    try testing.expectEqual(@as(i96, 0), try l.take("m", true));
    l.priority_waiting = 1;
    try l.update("m", .{ .app_limit = "100:1" });
    try testing.expect(try l.take("m", false) >= Limiter.yield_ns);
}

test Limiters {
    var l = try Limiters.init(testing.allocator, testing.io);
    defer l.deinit();
    try testing.expect(l.get("europe") != l.get("euw1"));
    try testing.expect(l.get("euw1") != null and l.get("nope") == null);
}

test "saved windows load into the next process's limiters" {
    var a = try Limiters.init(testing.allocator, testing.io);
    defer a.deinit();
    const eu = a.get("europe").?;
    try eu.acquire("m", false);
    try eu.acquire("m", true);
    var buf: [256]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    try a.save(&w, 1_000_000);
    try testing.expect(std.mem.startsWith(u8, w.buffered(), "europe 1 "));

    var b = try Limiters.init(testing.allocator, testing.io);
    defer b.deinit();
    // The same moment, then 2 s later: the 1 s window's hits have expired
    try testing.expectEqual(@as(usize, 4), try b.load(w.buffered(), 1_000_000));
    try testing.expectEqual(@as(usize, 2), b.get("europe").?.app.windows.items[1].hits.len);
    try testing.expectEqual(@as(usize, 0), b.get("americas").?.app.windows.items[1].hits.len);
    var c = try Limiters.init(testing.allocator, testing.io);
    defer c.deinit();
    try testing.expectEqual(@as(usize, 2), try c.load(w.buffered(), 1_002_000));
    try testing.expectEqual(@as(usize, 0), c.get("europe").?.app.windows.items[0].hits.len);
}

test "paced callers catch up on slots a slow answer cost them" {
    var w: Window = .{ .limit = 100, .seconds = 120 };
    defer w.hits.deinit(testing.allocator);
    const step = @divTrunc(w.span(), 100);
    for (0..20) |i| try w.hits.pushBack(testing.allocator, @as(i96, @intCast(i)) * step);
    const last = 19 * step;
    try testing.expectEqual(step, w.waitNs(last, true));
    // Held up 5 slots: the next 5 go at once, the one after waits its turn
    var now = last + 5 * step;
    for (0..5) |_| {
        try testing.expectEqual(@as(i96, 0), w.waitNs(now, true));
        try w.hits.pushBack(testing.allocator, now);
        now += 1;
    }
    try testing.expect(w.waitNs(now, true) > 0);
}

test "paced windows space requests evenly" {
    var w: Window = .{ .limit = 100, .seconds = 120 };
    defer w.hits.deinit(testing.allocator);
    try w.hits.pushBack(testing.allocator, 0);
    try testing.expectEqual(@as(i96, 0), w.waitNs(0, false));
    try testing.expectEqual(@divTrunc(w.span(), 100), w.waitNs(0, true));
}
