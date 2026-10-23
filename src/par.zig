//! Parallel loops for CPU-heavy model work (eval, outcomes, lab), and `each` for work
//! that waits on reads (the site's database loads). Each index writes only its own output
//! slot and the caller combines slots in index order, so results match a serial loop bit
//! for bit whatever the thread count.

const std = @import("std");

/// What a call of `body` can fail with, and what waiting can
fn Error(comptime body: anytype) type {
    const Return = @typeInfo(@TypeOf(body)).@"fn".return_type.?;
    return @typeInfo(Return).error_union.error_set || std.Io.Cancelable;
}

/// Each index's error, kept by `fail` and returned by `result`: the lowest index wins
const Failed = struct {
    /// index << 16 | error code; maxInt when none failed
    v: std.atomic.Value(u64) = .init(std.math.maxInt(u64)),

    fn fail(f: *Failed, i: usize, e: anyerror) void {
        _ = f.v.fetchMin(@as(u64, i) << 16 | @intFromError(e), .monotonic);
    }

    fn result(f: *const Failed, comptime E: type) E!void {
        const v = f.v.load(.monotonic);
        if (v == std.math.maxInt(u64)) return;
        return @errorCast(@errorFromInt(@as(@Int(.unsigned, @bitSizeOf(anyerror)), @truncate(v))));
    }
};

/// Calls `body(ctx, i)` for every i in 0..n on io's thread pool (Threaded: one worker per
/// CPU) and waits for all. After every call has finished, returns the error of the
/// lowest failing index, if any
pub fn forEach(io: std.Io, n: usize, ctx: anytype, comptime body: anytype) Error(body)!void {
    return forEachUpTo(io, n, std.math.maxInt(usize), ctx, body);
}

/// As forEach, with at most `max` calls at once: for bodies that each need more memory
/// than the machine has for one per CPU
pub fn forEachUpTo(io: std.Io, n: usize, max: usize, ctx: anytype, comptime body: anytype) Error(body)!void {
    const Shared = struct {
        ctx: @TypeOf(ctx),
        n: usize,
        next: std.atomic.Value(usize) = .init(0),
        failed: Failed = .{},

        fn work(s: *@This()) void {
            while (true) {
                const i = s.next.fetchAdd(1, .monotonic);
                if (i >= s.n) return;
                body(s.ctx, i) catch |e| s.failed.fail(i, e);
            }
        }
    };
    var s: Shared = .{ .ctx = ctx, .n = n };
    const workers = @min(n, max, std.Thread.getCpuCount() catch 1);
    var group: std.Io.Group = .init;
    for (0..workers) |_| group.async(io, Shared.work, .{&s});
    try group.await(io);
    return s.failed.result(Error(body));
}

/// Calls `body(ctx, i)` for every i in 0..n, each on its own thread, for work that waits
/// on the disk: n reads in flight whatever the CPU count (the box has 2 CPUs and a volume
/// that serves ~6x more reads at once than one reader issues). Where no thread is to be
/// had, the call runs on this one. Returns as forEach
pub fn each(io: std.Io, n: usize, ctx: anytype, comptime body: anytype) Error(body)!void {
    const Shared = struct {
        ctx: @TypeOf(ctx),
        failed: Failed = .{},

        fn run(s: *@This(), i: usize) void {
            body(s.ctx, i) catch |e| s.failed.fail(i, e);
        }
    };
    var s: Shared = .{ .ctx = ctx };
    var group: std.Io.Group = .init;
    for (0..n) |i| group.concurrent(io, Shared.run, .{ &s, i }) catch s.run(i);
    try group.await(io);
    return s.failed.result(Error(body));
}

const testing = std.testing;

test "every index once, lowest failing index wins" {
    var hits: [1000]std.atomic.Value(u32) = @splat(.init(0));
    const Ctx = struct {
        hits: []std.atomic.Value(u32),
        fn body(c: @This(), i: usize) !void {
            _ = c.hits[i].fetchAdd(1, .monotonic);
            if (i == 700) return error.Late;
            if (i == 300) return error.Early;
        }
    };
    try testing.expectError(error.Early, forEach(testing.io, hits.len, Ctx{ .hits = &hits }, Ctx.body));
    for (&hits) |*h| try testing.expectEqual(1, h.load(.monotonic));
    try forEach(testing.io, 0, Ctx{ .hits = &hits }, Ctx.body);
}

test "each: every index once, lowest failing index wins" {
    var hits: [8]std.atomic.Value(u32) = @splat(.init(0));
    const Ctx = struct {
        hits: []std.atomic.Value(u32),
        fn body(c: @This(), i: usize) !void {
            _ = c.hits[i].fetchAdd(1, .monotonic);
            if (i == 6) return error.Late;
            if (i == 2) return error.Early;
        }
    };
    try testing.expectError(error.Early, each(testing.io, hits.len, Ctx{ .hits = &hits }, Ctx.body));
    for (&hits) |*h| try testing.expectEqual(1, h.load(.monotonic));
}
