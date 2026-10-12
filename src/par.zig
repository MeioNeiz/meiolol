//! Parallel loops for CPU-heavy model work (eval, outcomes, lab). Each index writes only
//! its own output slot and the caller combines slots in index order, so results match a
//! serial loop bit for bit whatever the thread count.

const std = @import("std");

/// Calls `body(ctx, i)` for every i in 0..n on io's thread pool (Threaded: one worker per
/// CPU) and waits for all. After every call has finished, returns the error of the
/// lowest failing index, if any
pub fn forEach(io: std.Io, n: usize, ctx: anytype, comptime body: anytype) anyerror!void {
    const Shared = struct {
        ctx: @TypeOf(ctx),
        n: usize,
        next: std.atomic.Value(usize) = .init(0),
        /// index << 16 | error code, lowest wins; maxInt when none failed
        failed: std.atomic.Value(u64) = .init(std.math.maxInt(u64)),

        fn work(s: *@This()) void {
            while (true) {
                const i = s.next.fetchAdd(1, .monotonic);
                if (i >= s.n) return;
                body(s.ctx, i) catch |e| {
                    _ = s.failed.fetchMin(@as(u64, i) << 16 | @intFromError(e), .monotonic);
                };
            }
        }
    };
    var s: Shared = .{ .ctx = ctx, .n = n };
    const workers = @min(n, std.Thread.getCpuCount() catch 1);
    var group: std.Io.Group = .init;
    for (0..workers) |_| group.async(io, Shared.work, .{&s});
    try group.await(io);
    const f = s.failed.load(.monotonic);
    if (f != std.math.maxInt(u64)) return @errorFromInt(@as(@Int(.unsigned, @bitSizeOf(anyerror)), @truncate(f)));
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
