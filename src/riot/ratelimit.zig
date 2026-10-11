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
    /// Riot counts in fixed windows (its count falls back to 1 when one starts), so
    /// another process shows as Riot's count over how many of that window's were ours
    riot_count: u32 = 0,
    ours: u32 = 0,
    /// Seen Riot's window restart: until then its count holds a previous run's requests
    synced: bool = false,

    fn span(w: Window) i96 {
        return @as(i96, w.seconds) * std.time.ns_per_s + margin_ns;
    }

    fn prune(w: *Window, now: i96) void {
        while (w.hits.front()) |t| {
            if (now - t < w.span()) break;
            _ = w.hits.popFront();
        }
    }

    /// ns until another request fits under the limit less `reserve_pct`, 0 if one fits
    /// now. Paced: also one per span / limit at most, so the window fills evenly instead
    /// of in a burst that leaves no room for another process until it slides
    fn waitNs(w: *Window, now: i96, reserve_pct: u8, paced: bool) i96 {
        w.prune(now);
        const limit = @max(1, w.limit * (100 - @min(reserve_pct, 99)) / 100);
        var wait: i96 = 0;
        if (w.hits.len >= limit) wait = w.hits.at(w.hits.len - limit) + w.span() - now;
        if (paced) {
            if (w.hits.back()) |last| wait = @max(wait, last + @divTrunc(w.span(), limit) - now);
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

    fn waitNs(b: *Bucket, now: i96, reserve_pct: u8, paced: bool) i96 {
        var wait = @max(b.blocked_until - now, 0);
        for (b.windows.items) |*w| wait = @max(wait, w.waitNs(now, reserve_pct, paced));
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
    /// when Riot has seen more requests than we sent (a restart, another process), pad
    /// our windows at `now`. Returns the most requests someone else sent in any of
    /// Riot's current windows, 0 until one has restarted
    fn syncCounts(b: *Bucket, gpa: Allocator, counts: []const u8, now: i96) !u32 {
        var foreign: u32 = 0;
        var parts = std.mem.tokenizeScalar(u8, counts, ',');
        while (parts.next()) |part| {
            const colon = std.mem.indexOfScalar(u8, part, ':') orelse continue;
            const seen = std.fmt.parseInt(u32, std.mem.trim(u8, part[0..colon], " "), 10) catch continue;
            const secs = std.fmt.parseInt(u32, std.mem.trim(u8, part[colon + 1 ..], " "), 10) catch continue;
            for (b.windows.items) |*w| {
                if (w.seconds != secs) continue;
                if (seen <= w.riot_count) {
                    w.synced = true;
                    w.ours = 0;
                }
                w.ours += 1;
                w.riot_count = seen;
                if (w.synced) foreign = @max(foreign, seen -| w.ours);
                while (w.hits.len < seen) try w.hits.pushBack(gpa, now);
            }
        }
        return foreign;
    }
};

pub const Limiter = struct {
    gpa: Allocator,
    io: std.Io,
    app: Bucket = .{},
    methods: std.StringHashMapUnmanaged(Bucket) = .empty,
    /// Share of the app limit left to other processes on the same key while one is
    /// using it: Riot's counts showed requests we did not send in the last `shared_hold_s`
    reserve_pct: u8 = 0,
    shared_until: i96 = 0,
    /// Even spacing in every window (Window.waitNs)
    paced: bool = false,

    pub const app_default = "20:1,100:120";
    /// A Your games lookup is ~23 calls over a few minutes, and the page refreshes
    pub const shared_hold_s = 600;

    pub fn init(gpa: Allocator, io: std.Io) !Limiter {
        var l: Limiter = .{ .gpa = gpa, .io = io };
        try l.app.setSpec(gpa, app_default);
        return l;
    }

    /// Leave `pct` of every app window to other processes on the same key while one is
    /// using it. Riot's -Count headers already include their requests, so this only
    /// caps our share
    pub fn setReserve(l: *Limiter, pct: u8) void {
        l.reserve_pct = pct;
    }

    /// A request Riot may have counted without telling us (no count header, no answer):
    /// our share of its window is unknown until the next one starts
    pub fn unsync(l: *Limiter) void {
        for (l.app.windows.items) |*w| w.synced = false;
    }

    /// Another process used the key lately, so the reserve applies
    pub fn sharing(l: *Limiter) bool {
        return l.now() < l.shared_until;
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
            const reserve = if (t < l.shared_until) l.reserve_pct else 0;
            const wait = @max(l.app.waitNs(t, reserve, l.paced), m.waitNs(t, 0, l.paced));
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
        if (h.app_count) |counts| {
            const foreign = try l.app.syncCounts(l.gpa, counts, t);
            if (foreign > 0) l.shared_until = t + shared_hold_s * std.time.ns_per_s;
        } else l.unsync();
        if (h.method_limit) |spec| try m.setSpec(l.gpa, spec);
        if (h.method_count) |counts| _ = try m.syncCounts(l.gpa, counts, t);
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

test "reserve applies once Riot's counts show another process, not after a start" {
    var l = try Limiter.init(testing.allocator, testing.io);
    defer l.deinit();
    l.setReserve(20);
    // A previous run's requests in Riot's window: not another process
    try l.update("m", .{ .app_count = "1:1,90:120" });
    try l.update("m", .{ .app_count = "1:1,91:120" });
    try testing.expect(!l.sharing());
    // Riot's window restarts; ours, ours, then one we did not send
    try l.update("m", .{ .app_count = "1:1,1:120" });
    try l.update("m", .{ .app_count = "1:1,2:120" });
    try testing.expect(!l.sharing());
    try l.update("m", .{ .app_count = "2:1,4:120" });
    try testing.expect(l.sharing());
    // 91 padded hits against 80 of 100
    try testing.expect(l.app.waitNs(l.now(), l.reserve_pct, false) > 100 * std.time.ns_per_s);
}

test "an answer without counts leaves the window unjudged until Riot's next one" {
    var l = try Limiter.init(testing.allocator, testing.io);
    defer l.deinit();
    l.setReserve(20);
    try l.update("m", .{ .app_count = "1:1,5:120" });
    try l.update("m", .{ .app_count = "1:1,1:120" });
    try l.update("m", .{});
    try l.update("m", .{ .app_count = "1:1,3:120" });
    try testing.expect(!l.sharing());
}

test "paced windows space requests evenly" {
    var w: Window = .{ .limit = 100, .seconds = 120 };
    defer w.hits.deinit(testing.allocator);
    try w.hits.pushBack(testing.allocator, 0);
    try testing.expectEqual(@as(i96, 0), w.waitNs(0, 0, false));
    try testing.expectEqual(@divTrunc(w.span(), 100), w.waitNs(0, 0, true));
    try testing.expectEqual(@divTrunc(w.span(), 80), w.waitNs(0, 20, true));
}
