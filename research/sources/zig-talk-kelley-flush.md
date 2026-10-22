---
title: Don't Forget To Flush by Andrew Kelley (Systems Distributed 2025)
url: https://www.youtube.com/watch?v=f30PceqQWko
kind: talk
commit:
for: [zig-api-design, zig-perf, zig-memory]
looked: 2026-10-22
depth: docs (whole transcript)
relevance: high
grade: A/strong
description: Kelley's design rationale for std.Io as a passed interface (like Allocator) and for the 0.15 Writer/Reader with the buffer above the vtable; survey of C, Go, Rust, C++ streams; stack buffer sizing
---
# Don't Forget To Flush by Andrew Kelley

Why: the core team's reasoning behind passing `io: Io` and behind Writergate's
buffer-in-interface design, which every Zig 0.15+ I/O call follows.

## Assessment

- Evidence: A. Language creator explaining the std design he wrote (0.15 Writer/Reader,
  0.16 std.Io); shows generated machine code per language.
- Reasoning: strong. States the trade-off (more logic in the interface means less
  flexibility), the alternatives (other languages' streams), and when not to use an
  interface at all.
- Interests: promoting Zig against Go, Rust, C++; the comparisons pick the runtime-known
  implementation case on purpose (he says so for Rust).
- Weigh: given at Systems Distributed Aug 2025 while the work was in progress (the
  stream API had not landed then); names in the talk (source/sink) differ from shipped
  std (Reader/Writer). Auto captions ("vable" = vtable, "sync" = sink).

## Findings

- [zig/memory] Thread stacks are heap memory too, so large stack buffers are not free
  once code runs concurrently. @2:06 ^f1
  > It forces us to re-evaluate things like buffer sizes on the stack.
- [zig/api] Every concurrency model makes scheduling decisions; even single-threaded
  blocking code is a static schedule. @7:19 ^f2
  > We cannot escape scheduling decisions when we write applications.
- [zig/api] Goal: write logic agnostic to the concurrency model; only the Io
  implementation changes. Logic that needs concurrency (a multi-client server) is
  fundamentally not portable to blocking Io. @9:14 ^f3
  > Wouldn't it be nice if we could write this logic in a way that's agnostic to what concurrency model it's running in?
  > It is a fundamental property of the logic itself.
- [zig/api] Io is passed like an Allocator: anything that can block takes an Io
  parameter. @11:27 ^f4
  > the Zigg programming language already makes you pass an allocator to every function that wants to dynamically allocate memory. Compared to that, this is a piece of cake.
- [zig/api] Benefit: a function without an Io parameter does no I/O, so purity is visible
  in the signature; the caller controls effects. @12:22 ^f5
  > One, if it does not have an IO parameter, it does not do IO.
- [zig/api] [zig/test] Further benefits listed: freestanding reuse, leak checking for
  file descriptors and sockets, race testing at the Io layer, faking Io for unit tests,
  custom scheduling, cancellation in userland. @14:26 ^f6
  > the point here is that when you code against an IO interface, you can fake that interface in order to more easily unit test
- [zig/errors] Cancellation fits Zig errors: `defer` cancels in-flight work on error,
  and `error.Canceled` propagates up, cancelling towers of operations. @16:55 ^f7
  > as an unhandled canceled error is returned up the stack, it will propagate the cancellation to any more in-flight operations along the way
- [zig/perf] Buffering matters about a thousand-fold: 14 one-byte write syscalls vs one
  buffered write. @20:06 ^f8
  > it's about a thousand times slower, assuming that your buffer fits into the CPU's L1 cache
- [zig/api] [zig/perf] Keep hot paths above the vtable: fields and methods of the
  interface struct can be inlined; vtable function pointers are opaque to the
  optimiser. @21:42 ^f9
  > You really want to keep your hot paths north of the vtable boundary.
- [zig/api] [zig/perf] Putting the buffer in the interface (not the implementation)
  turned per-byte indirect calls into a register op plus a store, while the same machine
  code still serves any sink. @24:07 ^f10
  > We have traded an indirect function call for dramatically cheaper operations without giving up the property that the same machine code supports any sync instance
- [zig/api] The trade-off: more logic in the interface means less flexibility; don't use
  interfaces or function pointers unless you gain reuse. @25:00 ^f11
  > Don't relinquish your code's performance and ease of static analysis unless you're gaining code reusability in return.
  > Too many times I see less experienced programmers use interfaces or function pointers when they could be simply calling functions directly and they don't gain anything for it.
- [zig/api] Survey: C, Go, Rust and C++ all buffer below the vtable; Kelley calls the
  Stack Overflow advice to accept Go's io.Writer in reusable functions the worst code. @30:06 ^f12
  > none of these mainstream languages managed to get buffering into their interfaces
- [zig/api] Interface features he landed on: vectored writes and splats, file-to-file
  transfer (sendfile), discarding input, reader streaming straight into a writer. @31:54 ^f13
  > Sync supports sending data from open files which can result in direct FD to FD transfers in the kernel under the right conditions.
- [zig/api] Giving vtable functions access to all state including the buffer handles
  compression without an internal ring buffer. @31:08 ^f14
  > If we give the vable functions access to all the state, including the buffer, then more advanced use cases are handled, such as compression and decompression without an internal ring buffer.
- [zig/api] Implementing a stream: use short reads and writes (even returning 0) to keep
  implementations simple; pick buffer sizes from the protocol (TLS: max frame) and at the
  endpoint trade a few cache lines for fewer syscalls. @35:10 ^f15
  > So just return zero if you have to.
  > sacrifice a few cache lines in order to avoid SIS call overhead
- [zig/api] Naming: he finds reader/writer ambiguous (a writer reads your buffer) and
  prefers source/sink; the shipped std kept Reader and Writer. @19:20 ^f16
  > You get buffers from a source and you give buffers to a sync.

## Read

- Whole transcript.

## Not read

- Slides; comments.
