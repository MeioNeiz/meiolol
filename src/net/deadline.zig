//! A time limit on any call that can be cancelled, as tokio's `timeout`: the call runs on
//! its own unit of concurrency beside a timer, and whichever ends first wins. A call
//! that outlasts the limit is cancelled and waited for, so it never outlives `within`.
//!
//!     const res = deadline.within(io, .fromSeconds(20), signIn, .{ gpa, io, form }) catch |err| switch (err) {
//!         error.Timeout => return .no_answer,
//!         else => return err,
//!     };
//!
//! Cancelling reaches the call at its next `Io` cancelation point (a read, a connect,
//! a sleep); a call stuck outside one (a busy loop, a blocking DNS lookup) holds
//! `within` until it gets there. Needs an `Io` with concurrency (`Io.Threaded`), else
//! error.ConcurrencyUnavailable.

const std = @import("std");
const Io = std.Io;

fn Result(comptime Func: type) type {
    return @typeInfo(Func).@"fn".return_type.?;
}

/// `func`'s errors, error.Timeout and what starting it can fail with
pub fn Error(comptime Func: type) type {
    return @typeInfo(Result(Func)).error_union.error_set || Io.ConcurrentError || Io.Cancelable || error{Timeout};
}

/// `func(args)`, or error.Timeout once `limit` passes. A success that lands while it is
/// being cancelled is returned, never dropped, so a result that owns memory doesn't
/// leak. When the caller is cancelled meanwhile: error.Canceled, or that same late
/// success with the cancel request kept for the caller's next cancelation point
pub fn within(
    io: Io,
    limit: Io.Duration,
    func: anytype,
    args: std.meta.ArgsTuple(@TypeOf(func)),
) Error(@TypeOf(func))!@typeInfo(Result(@TypeOf(func))).error_union.payload {
    const U = union(enum) { done: Result(@TypeOf(func)), timer: Io.Cancelable!void };
    var buf: [2]U = undefined;
    var select: Io.Select(U) = .init(io, &buf);
    try select.concurrent(.timer, Io.sleep, .{ io, limit, .awake });
    select.concurrent(.done, func, args) catch |err| {
        select.cancelDiscard();
        return err;
    };
    const first = select.await() catch |err| {
        const late = lateResult(&select) orelse return err;
        io.recancel();
        return late;
    };
    switch (first) {
        .done => |r| {
            select.cancelDiscard();
            return r;
        },
        .timer => return lateResult(&select) orelse error.Timeout,
    }
}

/// Cancels what is still running; `func`'s success if it got one anyway
fn lateResult(select: anytype) ?@FieldType(@TypeOf(select.*).Union, "done") {
    while (select.cancel()) |u| switch (u) {
        .done => |r| {
            _ = r catch return null;
            return r;
        },
        .timer => {},
    };
    return null;
}

const testing = std.testing;

fn sleepFor(io: Io, ms: i64) Io.Cancelable!u32 {
    try io.sleep(.fromMilliseconds(ms), .awake);
    return 7;
}

fn elapsedMs(io: Io, since: Io.Timestamp) i64 {
    return since.durationTo(Io.Clock.awake.now(io)).toMilliseconds();
}

test "a call inside the limit returns its result at once" {
    const io = testing.io;
    const t0 = Io.Clock.awake.now(io);
    try testing.expectEqual(@as(u32, 7), try within(io, .fromSeconds(10), sleepFor, .{ io, 10 }));
    try testing.expect(elapsedMs(io, t0) < 2000);
}

test "a call past the limit is cancelled near the limit" {
    const io = testing.io;
    const t0 = Io.Clock.awake.now(io);
    try testing.expectError(error.Timeout, within(io, .fromMilliseconds(100), sleepFor, .{ io, 10_000 }));
    const ms = elapsedMs(io, t0);
    try testing.expect(ms >= 100 and ms < 2000);
}

fn failing() error{Broken}!u32 {
    return error.Broken;
}

test "the call's own error comes back as it is" {
    try testing.expectError(error.Broken, within(testing.io, .fromSeconds(10), failing, .{}));
}

/// Ignores the first cancel request and succeeds, as a call that finishes just as its
/// cancel arrives
fn finishesAnyway(io: Io, buf: *[8]u8) Io.Cancelable![]u8 {
    io.sleep(.fromSeconds(10), .awake) catch {};
    @memcpy(buf, "finished");
    return buf;
}

test "a success during the cancel is returned, not lost" {
    const io = testing.io;
    var buf: [8]u8 = undefined;
    try testing.expectEqualStrings("finished", try within(io, .fromMilliseconds(50), finishesAnyway, .{ io, &buf }));
}

fn limited(io: Io) Error(@TypeOf(sleepFor))!u32 {
    return within(io, .fromSeconds(10), sleepFor, .{ io, 10_000 });
}

test "cancelling the caller cancels the call" {
    const io = testing.io;
    const t0 = Io.Clock.awake.now(io);
    var f = try io.concurrent(limited, .{io});
    try io.sleep(.fromMilliseconds(50), .awake);
    try testing.expectError(error.Canceled, f.cancel(io));
    try testing.expect(elapsedMs(io, t0) < 2000);
}
