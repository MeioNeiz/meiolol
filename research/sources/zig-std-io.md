---
title: Zig 0.17 std.Io interface, Io.Writer and Io.Reader
url: https://codeberg.org/ziglang/zig/src/tag/0.17.0/lib/std/Io.zig
kind: project
commit: 0.17.0
for: [zig-api-design, zig-errors-safety, zig-perf]
looked: 2026-10-22
depth: code (std/Io.zig header, VTable head, errors, Future, Group, async; Io/Writer.zig VTable, errors, fixed, write, print docs, Discarding, Allocating; Io/Reader.zig VTable, errors, peek/take/toss, takeDelimiter; Io/File/Writer.zig)
relevance: high
grade: A/strong
description: Zig 0.17.0 std.Io (I/O and concurrency interface) and the buffer-in-interface Writer and Reader, read for interface and error idioms
---
# Zig 0.17 std.Io, Io.Writer, Io.Reader

Why: the 0.15 "Writergate" and 0.16 std.Io redesign set how 0.17 code passes I/O
around; what the std's own interfaces look like and how implementations attach.

## Assessment

- Evidence: A. The std itself (signals in [[zig-std-containers]]); every 0.17 program
  that prints or touches a file goes through these.
- Reasoning: strong. VTable fields carry long contracts (aliasing, zero-length returns,
  when each is called); error sets explain where the diagnostics live.
- Interests: none.
- Weigh: young API (0.15 Writer, 0.16 Io), still changing release to release; patterns
  (buffer in the interface, `@fieldParentPtr`, diagnostic field on the implementation)
  look settled.

## Findings

- [zig/api] `std.Io` is one interface for all I/O and concurrency (files, net,
  processes, time, randomness, async/concurrent/cancel, sync primitives), passed as a
  value like an Allocator. `std/Io.zig:1` ^f1
  > //! A cross-platform interface that abstracts all I/O operations and
  > //! * async, await, concurrent, and cancel
  > //! This interface allows programmers to write optimal, reusable code while
- [zig/api] Io has the same shape as Allocator: `userdata: ?*anyopaque` plus
  `vtable: *const VTable`; implementations are Threaded and per-OS Evented backends. `std/Io.zig:15` ^f2
  > const Io = @This();
  > userdata: ?*anyopaque,
  > vtable: *const VTable,
  > pub const Threaded = @import("Io/Threaded.zig");
- [zig/errors] Cancellation is an error, `error.Canceled` in `Io.Cancelable`, which most Io
  functions add to their error set; ignoring it is called a bug. `std/Io.zig:815` ^f3
  > pub const Cancelable = error{
  > /// Caller has requested the async operation to stop.
  > it is usually a bug to ignore `error.Canceled`. However, to defer handling cancelation
- [zig/errors] `error.Unexpected` is documented as a std gap to be patched, not a normal
  outcome. `std/Io.zig:820` ^f4
  > /// The Operating System returned an undocumented error code.
  > /// Library needs a small patch to add the error code to the error set for
- [zig/comptime] `io.async(function, args)` type-erases a call: args typed as
  `std.meta.ArgsTuple(@TypeOf(function))`, a local struct with a `start` fn casts back
  and `@call`s; the result type comes from @typeInfo. `std/Io.zig:2526` ^f5
  > args: std.meta.ArgsTuple(@TypeOf(function)),
  > const TypeErased = struct {
  > result_casted.* = @call(.auto, function, args_casted.*);
- [zig/api] `async` allows a blocking single-threaded Io; `concurrent` demands real
  concurrency and can fail with error.ConcurrencyUnavailable. Pick the weaker one unless
  you need concurrency. `std/Io.zig:2561` ^f6
  > /// This has stronger guarantee than `async`, placing restrictions on what kind
  > /// of `Io` implementations are supported. By calling `async` instead, one
  > ConcurrencyUnavailable,
- [zig/api] `Io.Group` runs an unordered task set awaited or cancelled as a whole;
  `Group.init` is a decl literal, await and cancel are idempotent. `std/Io.zig:1327` ^f7
  > /// An unordered set of tasks which can only be awaited or canceled as a whole.
  > pub const init: Group = .{ .token = .init(null), .state = 0 };
  > /// Idempotent. Not threadsafe.
- [zig/api] Io.Writer is a concrete struct holding the buffer (`buffer`, `end`) plus a
  vtable; the vtable is only reached when the buffer cannot take the data. `std/Io/Writer.zig:14` ^f8
  > vtable: *const VTable,
  > /// If this has length zero, the writer is unbuffered, and `flush` is a no-op.
  > /// Sends bytes to the logical sink. A write will only be sent here if it
  > /// could not fit into `buffer`, or during a `flush` operation.
- [zig/perf] The buffered fast path is a plain memcpy marked `@branchHint(.likely)`,
  inlined at the caller with no indirect call. `std/Io/Writer.zig:608` ^f9
  > if (w.end + bytes.len <= w.buffer.len) {
  > @branchHint(.likely);
  > return w.vtable.drain(w, &.{bytes}, 1);
- [zig/api] VTable entries have defaults (`sendFile = unimplementedSendFile`,
  `flush = defaultFlush`), so an implementation fills only `drain`. `std/Io/Writer.zig:71` ^f10
  > ) FileError!usize = unimplementedSendFile,
  > flush: *const fn (w: *Writer) Error!void = defaultFlush,
- [zig/errors] Writer errors are one opaque `error.WriteFailed`; the detail lives on the
  implementation, not in the error set. `std/Io/Writer.zig:91` ^f11
  > pub const Error = error{
  > /// See the `Writer` implementation for detailed diagnostics.
- [zig/errors] The file writer stores the real OS error in an `err: ?Error` field and
  returns WriteFailed, so callers inspect `fw.err` after a failure. `std/Io/File/Writer.zig:12` ^f12
  > err: ?Error = null,
  > return error.WriteFailed;
- [zig/api] Implementations embed the interface as a field named `interface` (or
  `writer`) and recover themselves with `@alignCast(@fieldParentPtr("interface", io_w))`. `std/Io/File/Writer.zig:88` ^f13
  > interface: Io.Writer,
  > const w: *Writer = @alignCast(@fieldParentPtr("interface", io_w));
- [zig/memory] (inferred) Because the vtable fn uses @fieldParentPtr, the interface must
  be used through `&impl.interface` and never copied out: a copied Writer points its
  parent computation at the wrong memory. ^f14
- [zig/api] `Writer.fixed(buf)` writes into a caller buffer and returns WriteFailed when
  full: the no-allocation formatting sink. `std/Io/Writer.zig:124` ^f15
  > /// Writes to `buffer` and returns `error.WriteFailed` when it is full.
  > pub fn fixed(buffer: []u8) Writer {
- [zig/memory] `Writer.Allocating` grows an allocator-backed buffer and converts to and
  from `ArrayList(u8)` without copying, taking ownership. `std/Io/Writer.zig:2695` ^f16
  > /// Replaces `array_list` with empty, taking ownership of the memory.
  > pub fn fromArrayList(allocator: Allocator, array_list: *ArrayList(u8)) Allocating {
  > /// Returns an array list that takes ownership of the allocated memory.
- [zig/test] `Writer.Discarding` counts bytes and drops them: measure output size or
  test that formatting succeeds without storing it. `std/Io/Writer.zig:2346` ^f17
  > pub const Discarding = struct {
  > const d: *Discarding = @alignCast(@fieldParentPtr("writer", w));
- [zig/api] [toolchain] Custom formatting in 0.17 is `pub fn format(self, w: *Writer)
  Writer.Error!void` chosen with `{f}`; `{t}` prints enum and error tag names;
  `{any}` the default format. `std/Io/Writer.zig:688` ^f18
  > /// - "f": delegates to the `format` method of the type, passing `*Writer` and
  > ///   - for enums and tagged unions: prints the tag name
  > pub fn format(self: SelfType, w: *Writer) Error!void {
- [zig/api] Io.Reader also holds its buffer (`buffer`, `seek`, `end`); `peek` returns a
  view into it, `toss` advances, `take` is both; returned slices die on the next peek. `std/Io/Reader.zig:16` ^f19
  > /// Number of bytes which have been consumed from `buffer`.
  > /// Invalidates previously returned values from `peek`.
  > /// Equivalent to `peek` followed by `toss`.
- [zig/safety] Reader functions that need contiguous bytes assert the buffer is big
  enough rather than allocate, so the caller sizes the buffer. `std/Io/Reader.zig:512` ^f20
  > /// Asserts that the `Reader` was initialized with a buffer capacity at
  > /// least as big as `n`.
- [zig/errors] Reader errors: ReadFailed (details on the implementation), EndOfStream,
  and for delimiters StreamTooLong, with state unchanged on that error. `std/Io/Reader.zig:105` ^f21
  > /// End of stream indicated from the `Reader`. This error cannot originate
  > /// capacity of this `Reader`, `error.StreamTooLong` is returned. In
  > /// such case, the stream state is unmodified as if this function was never
- [zig/api] `takeDelimiter` returns `?[]u8`, null at end: the line-iteration idiom
  `while (try r.takeDelimiter('\n')) |line|`. `std/Io/Reader.zig:917` ^f22
  > pub fn takeDelimiter(r: *Reader, delimiter: u8) error{ ReadFailed, StreamTooLong }!?[]u8 {
- [zig/memory] `allocRemaining` takes a `Limit`, so reading a whole stream always names
  a maximum and fails with StreamTooLong past it. `std/Io/Reader.zig:286` ^f23
  > /// If `limit` is exceeded, `error.StreamTooLong` is returned instead.
  > pub fn allocRemaining(r: *Reader, gpa: Allocator, limit: Limit) LimitedAllocError![]u8 {
- [zig/api] `Io.Limit` is a non-exhaustive `enum(usize)` with named `nothing` and
  `unlimited` values: a typed integer instead of a bare usize with magic values. `std/Io.zig:730` ^f24
  > pub const Limit = enum(usize) {
  > unlimited = math.maxInt(usize),
- [zig/api] Files give their stream through `file.writer(io, &buffer)`; the caller owns
  the buffer, positional mode is preferred for thread safety. `std/Io/File.zig:593` ^f25
  > pub fn writer(file: File, io: Io, buffer: []u8) Writer {
  > /// Positional is more threadsafe, since the global seek position is not
- [zig/api] Fixed-buffer and failing implementations are exported constants
  (`Writer.failing`, `Io.failing`, `Reader.fixed`), giving test doubles for free. `std/Io/Writer.zig:140` ^f26
  > pub const failing: Writer = .{
  > .drain = failingDrain,
- [zig/api] [toolchain] Checked, not there in 0.17 lib/std (grep): `std.io` (lowercase),
  `getStdOut`, `AnyWriter`, `GenericWriter`, `usingnamespace`; stdout is
  `File.stdout().writer(io, &buf)` and the interface is `*Io.Writer`. ^f27

## Read

- `std/Io.zig`: header, VTable start, Limit, error sets, Future, Group, async, concurrent
- `std/Io/Writer.zig`: lines 1-160, write/writeAll/print docs, Discarding, Allocating
- `std/Io/Reader.zig`: lines 1-170, peek/take/toss, takeDelimiter, peekByte/takeByte
- `std/Io/File/Writer.zig`: lines 1-160; `std/Io/File.zig`: writer/reader constructors

## Not read

- `std/Io/Threaded.zig`, Evented backends (Uring, Kqueue, Dispatch): implementation side
- `Io.Select`, `Io.Queue`, Mutex and Condition; `Io/net.zig`
- Writer.printValue internals (how `{any}` walks types with comptime reflection)
