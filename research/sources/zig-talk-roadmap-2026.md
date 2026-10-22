---
title: Zig Roadmap 2026 (Andrew Kelley, Zig SHOWTIME, July 2025)
url: https://www.youtube.com/watch?v=x3hOiOcbgeA
kind: talk
commit:
for: [zig-api-design, zig-perf, zig-testing, zig-good-practice]
looked: 2026-10-22
depth: docs (labeled switch 19:40-27:00, incremental and translate-c 41:15-51:00, I/O as an interface 1:00:50-1:24:10, fuzzing 1:24:10-1:30:30, Q&A grepped)
relevance: high
grade: A/strong
description: Kelley's 2026 roadmap stream: labeled switch continue for state machines, Io as an interface passed like Allocator, non-generic Writer with buffer in the interface, no interface syntax sugar on purpose, allocator kept out of Io, integrated fuzzing
---
# Zig Roadmap 2026 (Zig SHOWTIME, July 2025)

Why: Kelley's reasons for labeled switch, the Io interface and hand-built interfaces;
complements [[zig-talk-kelley-flush]] with Q&A answers.

## Assessment

- Evidence: A. The language creator, live, with code on screen; 2h18 stream, only the
  coding-relevant sections read.
- Reasoning: strong on Io and interfaces (why non-generic, why no sugar, why allocator
  stays out of Io); fuzzing part is a demo of an experimental, partly broken feature.
- Interests: project promotion and fundraising.
- Weigh: recorded before 0.15 landed Writergate and before 0.16 std.Io; the direction
  shipped. Auto captions.

## Findings

- [zig/perf] [zig/style] Labeled switch with `continue :label value` for state machines:
  a comptime-known continue is a structured goto; branching moves to each prong, which
  helps the branch predictor (tokenizer 13% faster). @22:54 ^f1
  > if if this value is um compile time known, doesn't have to be um but if it is compile time known, that is just a go-to.
  > So it really helps the branch predictor uh to use this pattern.
- [zig/style] He finds labeled switch more readable than a while-switch loop: each
  continue says where control goes. @26:19 ^f2
  > even if I'm in the middle of this big state machine and I see this, I know exactly where this is going.
- [zig/style] Zig had goto and removed it as redundant with labeled break and continue. @22:06 ^f3
  > Uh as you might not know, uh Zigg actually used to have Goto.
- [toolchain] Read the release notes' upgrade guides when moving versions: they give
  the reason, the old and new code. @19:40 ^f4
  > if you read our release notes, this is a great way to upgrade your code in response to language changes
- [zig/api] Io joins Allocator as a parameter you pass everywhere; anything that can block
  the thread, including large CPU tasks, belongs in it. @1:01:39 ^f5
  > you know how in Zigg programs you always have to pass an allocator everywhere? Okay. Well, now you're gonna have to also do that with IO.
  > Anything that can block the current thread of execution, including like large CPU tasks, uh they belong here.
- [zig/api] Library code encodes what can run in parallel; the caller picks the Io
  implementation, as the caller picks the allocator. @1:04:14 ^f6
  > Exactly like how you take an allocator as a function and the caller gets to decide how you allocate your memory.
- [zig/api] Writer and Reader moved from generic (`GenericWriter`) to one non-generic
  struct with a vtable: the same machine code serves every stream. @1:18:02 ^f7
  > so the new writer is not generic.
  > all the code in this file is not generic, which means that the same machine code, you'll notice a lot of it is formatting code, the same machine code will uh be used in all of the writers
- [zig/api] Stream transforms (compression) take a reader and give a writer and need no
  Io at all; only endpoint implementations (files, sockets) take an Io. @1:20:11 ^f8
  > It actually has no actually doesn't need to know about IO at all.
- [zig/api] Allocator stays out of the Io interface: a blocking, eager Io implementation
  needs no allocation, so it would be inappropriate there. @1:58:40 ^f9
  > In such a IO implementation, which is totally a valid implementation of this interface, you actually don't need an allocator.
- [zig/api] No syntax sugar for vtable interfaces, on purpose: hand-built interfaces allow
  fields (the buffer) above the vtable, which traits forbid. @2:08:43 ^f10
  > So what I've done is I've actually pulled these buffers from beneath the vtable to above the vtable.
- [zig/api] Creating an interface should be annoying and rare: the friction is
  appropriate. @2:10:42 ^f11
  > I think that creating an interface should be kind of annoying and you should have to put a lot of thought into it and you should just usually simply not do it.
- [zig/api] Interfaces that need shared state (a mutex) keep the state and fast path in
  the interface, calling the vtable only on contention. @1:53:41 ^f12
  > The state can't be on the other side of the v table.
- [zig/errors] Every function doing Io gains `error.Canceled`; usually just propagate it,
  and errdefer runs on cancellation. @1:42:40 ^f13
  > so your function is going to have to take uh you know do thing you're going to have to take an IO parameter
  > because it's an error, if you have any like air defer blah blah blah, this is going to run in case your IO thing gets cancelled
- [zig/test] Integrated fuzzing: one fuzz test can replace many unit tests; run fuzz tests
  in a release mode for more iterations. Experimental in mid 2025. @1:24:57 ^f14
  > you can write a 100 unit tests and spend like weeks on that or you can just write one fuzz test and then delete 99 unit tests
  > You definely want to run your Oh, there we go. You definely want to run your fuzz tests in um release mode because you want more iterations.
- [zig/build] Incremental compilation front end works; binary emission was blocked on
  linker work in mid 2025 (stale: works with LLVM since 0.16, [[zig-devlog-2026#^f17]]). @42:52 ^f15
  > the thing that's holding us back is um uh the linker
- [zig/build] [toolchain] A pure-Zig translate-c (on Aro) replaces the clang-based one; part
  of removing clang, LLD and LLVM dependencies. @50:08 ^f16
  > suffice to say, we're well underway for eliminating our clang dependency.

## Read

- Sections listed in depth; the rest skimmed by keyword.

## Not read

- 0:00-19:40 (package manager, x86 backend, UBSan), 27:00-41:15 (targets, file watching),
  51:00-1:00:50 (aarch64 backend), community announcements, most of Q&A.
