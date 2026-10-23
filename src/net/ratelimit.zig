//! Client-side rate limits for an API that states its own: sliding windows ("20 per
//! second and 100 per 2 minutes") for the whole client and per key (an endpoint), shared
//! by every thread calling it, corrected from the limits and counts the server reports.
//! What governor gives in Rust, plus the server-reported corrections, priority callers
//! and even pacing a long crawl needs.
//!
//!     var l: ratelimit.Limiter = try .init(gpa, io, "20:1,100:120");
//!     defer l.deinit();
//!     try l.acquire("match-v5.getMatch", false); // waits for a slot, then counts it
//!     const res = try send(...);
//!     // The answer's own view of the limits and how many requests it has counted
//!     try l.update("match-v5.getMatch", .{
//!         .global_limit = res.header("x-app-rate-limit"),
//!         .global_count = res.header("x-app-rate-limit-count"),
//!         .key_limit = res.header("x-method-rate-limit"),
//!         .key_count = res.header("x-method-rate-limit-count"),
//!     });
//!     if (res.status == 429) try l.block(.global, "match-v5.getMatch", retry_after);
//!
//! A spec is "limit:seconds" pairs joined by commas, as Riot's X-*-Rate-Limit headers
//! write them; a count header has the same shape with requests seen for the limit.
//! Windows here run 750 ms longer than stated, so a server counting in fixed windows
//! from a request's arrival never sees one too many.
//!
//! One Limiter per budget the server counts (an API key on one host). It is thread
//! safe; `acquire` sleeps on the Io it was made with and so can be cancelled.

const std = @import("std");
const Allocator = std.mem.Allocator;

const margin_ns: i96 = 750 * std.time.ns_per_ms;
/// Windows past this many in one spec are ignored
const max_windows = 4;
/// Paced callers may run this many requests ahead of one per span / limit, making up
/// the slots a slow answer or a busy database cost them (a thread sends one request at
/// a time). The window's limit still holds
const catch_up = 16;
/// Padding from reported counts stops here, far above any real window, so a bogus count
/// header can't take gigabytes
const pad_max = 1 << 20;

const Window = struct {
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

const Bucket = struct {
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
            const colon = std.mem.findScalar(u8, part, ':') orelse return error.BadSpec;
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

    /// A count header ("3:1,57:120"): when the server has seen more requests than we
    /// sent (a restart, another process on the same key), pad our windows at `now`
    fn syncCounts(b: *Bucket, gpa: Allocator, counts: []const u8, now: i96) !void {
        var parts = std.mem.tokenizeScalar(u8, counts, ',');
        while (parts.next()) |part| {
            const colon = std.mem.findScalar(u8, part, ':') orelse continue;
            const seen = std.fmt.parseInt(u32, std.mem.trim(u8, part[0..colon], " "), 10) catch continue;
            const secs = std.fmt.parseInt(u32, std.mem.trim(u8, part[colon + 1 ..], " "), 10) catch continue;
            for (b.windows.items) |*w| {
                if (w.seconds != secs) continue;
                while (w.hits.len < @min(seen, pad_max)) try w.hits.pushBack(gpa, now);
            }
        }
    }
};

/// The global windows every request counts against, and one set per key, learnt from
/// `update` (a key starts with none)
pub const Limiter = struct {
    gpa: Allocator,
    io: std.Io,
    global: Bucket = .{},
    /// Only under `mutex`: a rehash moves the buckets
    keys: std.StringHashMapUnmanaged(Bucket) = .empty,
    /// Even spacing in every window for callers without priority (Window.waitNs), for a
    /// client that sends all day and wants a slot free for a priority caller at any
    /// moment. Set before the first acquire
    paced: bool = false,
    /// Priority callers waiting for a slot; the others hold back while there are any
    priority_waiting: u32 = 0,
    mutex: std.Io.Mutex = .init,

    /// How often a caller without priority looks again while a priority one waits
    const yield_ns = 20 * std.time.ns_per_ms;

    /// `global` is a spec ("20:1,100:120"), used until the server reports another
    pub fn init(gpa: Allocator, io: std.Io, global: []const u8) !Limiter {
        var l: Limiter = .{ .gpa = gpa, .io = io };
        errdefer l.global.deinit(gpa);
        try l.global.setSpec(gpa, global);
        return l;
    }

    pub fn deinit(l: *Limiter) void {
        l.global.deinit(l.gpa);
        var it = l.keys.iterator();
        while (it.next()) |e| {
            e.value_ptr.deinit(l.gpa);
            l.gpa.free(e.key_ptr.*);
        }
        l.keys.deinit(l.gpa);
    }

    fn bucket(l: *Limiter, key: []const u8) !*Bucket {
        const gop = try l.keys.getOrPut(l.gpa, key);
        if (!gop.found_existing) {
            gop.key_ptr.* = l.gpa.dupe(u8, key) catch |err| {
                l.keys.removeByPtr(gop.key_ptr);
                return err;
            };
            gop.value_ptr.* = .{};
        }
        return gop.value_ptr;
    }

    /// The limiter's clock: awake-time ns
    pub fn now(l: *Limiter) i96 {
        return std.Io.Clock.awake.now(l.io).nanoseconds;
    }

    /// Block until a request on `key` fits every window, then record it. Priority: the
    /// next free slot, unpaced, ahead of every caller without priority
    pub fn acquire(l: *Limiter, key: []const u8, priority: bool) !void {
        if (priority) l.countPriority(1);
        defer if (priority) l.countPriority(-1);
        while (true) {
            const wait = try l.take(key, priority);
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
    fn take(l: *Limiter, key: []const u8, priority: bool) !i96 {
        l.mutex.lockUncancelable(l.io);
        defer l.mutex.unlock(l.io);
        const k = try l.bucket(key);
        const t = l.now();
        const paced = l.paced and !priority;
        var wait = @max(l.global.waitNs(t, paced), k.waitNs(t, paced));
        if (!priority and l.priority_waiting > 0) wait = @max(wait, yield_ns);
        if (wait > 0) return wait;
        for (l.global.windows.items) |*w| try w.hits.pushBack(l.gpa, t);
        for (k.windows.items) |*w| try w.hits.pushBack(l.gpa, t);
        return 0;
    }

    /// What an answer said about the limits: specs and counts as "n:seconds,...", null
    /// for a header it didn't carry
    pub const Reported = struct {
        global_limit: ?[]const u8 = null,
        global_count: ?[]const u8 = null,
        key_limit: ?[]const u8 = null,
        key_count: ?[]const u8 = null,
    };

    /// A changed limit replaces that bucket's windows (a window of the same length keeps
    /// its send times); a count above ours pads our window. error.BadSpec, or a parse
    /// error, for a limit spec that doesn't parse; counts that don't are skipped
    pub fn update(l: *Limiter, key: []const u8, r: Reported) !void {
        l.mutex.lockUncancelable(l.io);
        defer l.mutex.unlock(l.io);
        const t = l.now();
        const k = try l.bucket(key);
        if (r.global_limit) |spec| try l.global.setSpec(l.gpa, spec);
        if (r.global_count) |counts| try l.global.syncCounts(l.gpa, counts, t);
        if (r.key_limit) |spec| try k.setSpec(l.gpa, spec);
        if (r.key_count) |counts| try k.syncCounts(l.gpa, counts, t);
    }

    pub const Scope = enum { global, key };

    /// No request on the scope's bucket for `seconds` (a 429's Retry-After), on top of
    /// any block already running longer
    pub fn block(l: *Limiter, scope: Scope, key: []const u8, seconds: u32) !void {
        l.mutex.lockUncancelable(l.io);
        defer l.mutex.unlock(l.io);
        const until = l.now() + @as(i96, seconds) * std.time.ns_per_s;
        const b = if (scope == .global) &l.global else try l.bucket(key);
        b.blocked_until = @max(b.blocked_until, until);
    }

    /// The global windows' send times, one line "`name` seconds ms ms ..." per window in
    /// real-clock ms (`real_ms` is now), for the next process to `load`: without them a
    /// restart learns the server's counts from its first answers and pads them at that
    /// moment, holding back a whole window
    pub fn save(l: *Limiter, w: *std.Io.Writer, name: []const u8, real_ms: i64) !void {
        l.mutex.lockUncancelable(l.io);
        defer l.mutex.unlock(l.io);
        const t = l.now();
        for (l.global.windows.items) |*win| {
            win.prune(t);
            if (win.hits.len == 0) continue;
            try w.print("{s} {d}", .{ name, win.seconds });
            for (0..win.hits.len) |j| {
                try w.print(" {d}", .{real_ms - @as(i64, @intCast(@divTrunc(t - win.hits.at(j), std.time.ns_per_ms)))});
            }
            try w.writeByte('\n');
        }
    }

    /// One line `save` wrote, its name taken off ("seconds ms ms ..."), into an empty
    /// global window of the same length; how many send times were still in it
    pub fn load(l: *Limiter, line: []const u8, real_ms: i64) !usize {
        var fields = std.mem.tokenizeScalar(u8, line, ' ');
        const seconds = std.fmt.parseInt(u32, fields.next() orelse return 0, 10) catch return 0;
        l.mutex.lockUncancelable(l.io);
        defer l.mutex.unlock(l.io);
        const t = l.now();
        var loaded: usize = 0;
        for (l.global.windows.items) |*win| {
            if (win.seconds != seconds or win.hits.len > 0) continue;
            while (fields.next()) |field| {
                const ms = std.fmt.parseInt(i64, field, 10) catch continue;
                const at = t - @as(i96, @max(real_ms - ms, 0)) * std.time.ns_per_ms;
                if (t - at >= win.span()) continue;
                try win.hits.pushBack(l.gpa, at);
                loaded += 1;
            }
        }
        return loaded;
    }
};

const testing = std.testing;

test "spec parsing keeps hits of unchanged windows" {
    var l = try Limiter.init(testing.allocator, testing.io, "20:1,100:120");
    defer l.deinit();
    try l.acquire("m", false);
    try l.update("m", .{ .global_limit = "20:1,100:120,1000:600" });
    try testing.expectEqual(@as(usize, 3), l.global.windows.items.len);
    try testing.expectEqual(@as(usize, 1), l.global.windows.items[1].hits.len);
    try testing.expectEqual(@as(usize, 0), l.global.windows.items[2].hits.len);
}

test "reported counts pad our windows" {
    var l = try Limiter.init(testing.allocator, testing.io, "20:1,100:120");
    defer l.deinit();
    try l.acquire("m", false);
    try l.update("m", .{ .global_count = "1:1,57:120", .key_limit = "50:10", .key_count = "3:10" });
    try testing.expectEqual(@as(usize, 1), l.global.windows.items[0].hits.len);
    try testing.expectEqual(@as(usize, 57), l.global.windows.items[1].hits.len);
    try testing.expectEqual(@as(usize, 3), l.keys.getPtr("m").?.windows.items[0].hits.len);
}

test "a bogus count pads no further than pad_max" {
    var l = try Limiter.init(testing.allocator, testing.io, "20:1,100:120");
    defer l.deinit();
    try l.update("m", .{ .global_count = "4000000:1" });
    try testing.expectEqual(@as(usize, pad_max), l.global.windows.items[0].hits.len);
}

test "a limit spec that doesn't parse is an error and leaves the windows" {
    var l = try Limiter.init(testing.allocator, testing.io, "20:1,100:120");
    defer l.deinit();
    try testing.expectError(error.BadSpec, l.update("m", .{ .global_limit = "20" }));
    try testing.expectError(error.InvalidCharacter, l.update("m", .{ .key_limit = "x:1" }));
    try testing.expectEqual(@as(usize, 2), l.global.windows.items.len);
    try testing.expectError(error.BadSpec, Limiter.init(testing.allocator, testing.io, "20/1"));
}

test "acquire waits once a window is full" {
    var l = try Limiter.init(testing.allocator, testing.io, "20:1,100:120");
    defer l.deinit();
    try l.update("m", .{ .global_limit = "3:1" });
    for (0..3) |_| try l.acquire("m", false);
    // Back-dated so the window frees in 100 ms, not a real 1.75 s
    const w = &l.global.windows.items[0];
    const start = l.now();
    for (0..3) |i| w.hits.atPtr(i).* = start - w.span() + 100 * std.time.ns_per_ms;
    try l.acquire("m", false);
    const elapsed_ms = @divTrunc(l.now() - start, std.time.ns_per_ms);
    try testing.expect(elapsed_ms >= 100 and elapsed_ms < 1000);
}

test "a key's windows hold only that key back" {
    var l = try Limiter.init(testing.allocator, testing.io, "100:1");
    defer l.deinit();
    try l.update("a", .{ .key_limit = "1:10" });
    try l.acquire("a", false);
    try testing.expect(try l.take("a", false) > 9 * std.time.ns_per_s);
    try testing.expectEqual(@as(i96, 0), try l.take("b", false));
}

test "block holds a bucket back for its seconds, the longer of two" {
    var l = try Limiter.init(testing.allocator, testing.io, "100:1");
    defer l.deinit();
    try l.block(.key, "a", 30);
    try l.block(.key, "a", 5);
    const wait = try l.take("a", true);
    try testing.expect(wait > 29 * std.time.ns_per_s and wait <= 30 * std.time.ns_per_s);
    try testing.expectEqual(@as(i96, 0), try l.take("b", true));
    try l.block(.global, "", 2);
    try testing.expect(try l.take("b", true) > std.time.ns_per_s);
}

test "a priority caller takes the next slot, ahead of paced callers" {
    var l = try Limiter.init(testing.allocator, testing.io, "20:1,100:120");
    defer l.deinit();
    l.paced = true;
    try l.update("m", .{ .global_limit = "100:120" });
    try l.acquire("m", false);
    // Paced, the next is due in 1.2 s; priority goes now
    try testing.expect(try l.take("m", false) > std.time.ns_per_s);
    try testing.expectEqual(@as(i96, 0), try l.take("m", true));
    l.priority_waiting = 1;
    try l.update("m", .{ .global_limit = "100:1" });
    try testing.expect(try l.take("m", false) >= Limiter.yield_ns);
}

test "threads sharing a limiter never pass its window" {
    var l = try Limiter.init(testing.allocator, testing.io, "40:60");
    defer l.deinit();
    const Run = struct {
        fn run(lim: *Limiter) void {
            for (0..10) |_| _ = lim.take("m", false) catch return;
        }
    };
    var threads: [8]std.Thread = undefined;
    for (&threads) |*t| t.* = try std.Thread.spawn(.{}, Run.run, .{&l});
    for (threads) |t| t.join();
    try testing.expectEqual(@as(usize, 40), l.global.windows.items[0].hits.len);
}

test "saved windows load into the next process's limiter" {
    var a = try Limiter.init(testing.allocator, testing.io, "20:1,100:120");
    defer a.deinit();
    try a.acquire("m", false);
    try a.acquire("m", true);
    var buf: [256]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    try a.save(&w, "europe", 1_000_000);
    try testing.expect(std.mem.startsWith(u8, w.buffered(), "europe 1 "));

    var lines = std.mem.tokenizeScalar(u8, w.buffered(), '\n');
    var b = try Limiter.init(testing.allocator, testing.io, "20:1,100:120");
    defer b.deinit();
    var c = try Limiter.init(testing.allocator, testing.io, "20:1,100:120");
    defer c.deinit();
    var at_once: usize = 0;
    var later: usize = 0;
    while (lines.next()) |line| {
        const rest = line["europe ".len..];
        at_once += try b.load(rest, 1_000_000);
        // 2 s later: the 1 s window's hits have expired
        later += try c.load(rest, 1_002_000);
    }
    try testing.expectEqual(@as(usize, 4), at_once);
    try testing.expectEqual(@as(usize, 2), b.global.windows.items[1].hits.len);
    try testing.expectEqual(@as(usize, 2), later);
    try testing.expectEqual(@as(usize, 0), c.global.windows.items[0].hits.len);
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

fn fuzzReported(_: void, s: *testing.Smith) !void {
    var l = try Limiter.init(testing.allocator, testing.io, "20:1,100:120");
    defer l.deinit();
    var bufs: [4][64]u8 = undefined;
    var r: Limiter.Reported = .{};
    inline for (.{ "global_limit", "global_count", "key_limit", "key_count" }, 0..) |f, i| {
        @field(r, f) = bufs[i][0..s.slice(&bufs[i])];
    }
    l.update("m", r) catch return;
    for (l.global.windows.items) |w| try testing.expect(w.hits.len <= pad_max);
}

test "fuzz: reported limits and counts" {
    try testing.fuzz({}, fuzzReported, .{});
}
