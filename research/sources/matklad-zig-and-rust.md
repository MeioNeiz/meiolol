---
title: Zig And Rust (matklad, 2023-03-26)
url: https://matklad.github.io/2023/03/26/zig-and-rust.html
kind: article
commit: 
for: [zig-good-practice, zig-memory, zig-errors-safety, zig-testing]
looked: 2026-10-22
depth: docs (whole post)
relevance: high
grade: B/strong
description: Why matklad moved to Zig: TigerBeetle's style (static allocation, explicit bounds, externalised IO, simulation), defer vs RAII, allocator passing, and his worries about Zig
---
# Zig And Rust (matklad, 2023-03-26)

Why: the style of software Zig suits, from someone with 7 years of Rust. Zig 0.10/0.11
era, early in his Zig use. Ideas current; the IDE and `zig do` wishes are dated.

## Assessment

- Evidence: B. rust-analyzer lead and TigerBeetle engineer, first-hand on both
  projects; he says it is "emphatically _not_ a balanced and thorough comparison".
- Reasoning: strong. Two styles of reliability, how each project lives one, costs of
  Zig named (not memory safe, defer bugs, aliasing semantics).
- Interests: had just joined TigerBeetle.
- Weigh: the TigerBeetle style list is the useful part; claims about Zig's aliasing
  semantics are his 2023 worry.

## Findings

- [zig] Two reliability styles: Erlang (design for partial faults) vs SQLite (rigorous
  engineering); rust-analyzer is the first, TigerBeetle the second. ^f1
  > rust-analyzer and TigerBeetle are perfect specimens of the two approaches
- [zig/memory] TigerBeetle allocates all memory at startup and none after. ^f2
  > We allocate all the memory at startup, and there’s zero allocation after that.
- [zig/perf] No serialisation format: received bytes are cast to the desired type and
  checksummed, to cut moving parts more than for speed. ^f3
  > Rather, we just cast the bytes we received from the network to a desired type. The motivation here is not so much performance, as reduction of the number of moving parts.
- [zig/safety] Everything has an explicit upper bound, checked at the edges of the
  system. ^f4
  > _Everything_ in TigerBeetle has an explicit upper-bound. There’s not a thing which is _just_ an `u32` — all data is checked to meet specific numeric limits at the edges of the system.
- [zig/memory] The message pool is sized to the upper bound of messages in memory, so
  getting a message can't allocate or fail. ^f5
  > Getting a new message from the message pool can’t allocate and can’t fail.
- [zig/test] All IO including time is externalised, so testing tries permutations of
  environment effects: deterministic randomised simulation. ^f6
  > _All_ inputs are passed in explicitly, there’s no ambient influences from the environment.
  > Deterministic randomized simulation is very effective at uncovering issues in real implementations of distributed systems.
- [zig/memory] (claim) Rewriting Rust in Zig would be more complex; a lot of "replace RAII
  with defer" Zig code has resource-management bugs. ^f7
  > I noticed that a lot of Zig code written in “let’s replace RAII with defer” style has resource-management bugs.
- [zig/memory] The answer is architecture with little resource management to do
  (allocate up front or at compile time). ^f8
  > But it often is possible to architect the software such that there’s little resource management to do
- [zig/comptime] Comptime is one dynamically typed feature subsuming much of Rust's type
  machinery; trade-off: instantiation-time errors are worse in complex cases. ^f9
  > It is definitely a tradeoff, instantiation-time errors are much worse for complex cases.
- [zig/memory] Allocator passed in per method (call site dependency injection); TigerBeetle
  passes the allocator to `init` but not to the event loop, so the loop can't allocate. ^f10
  > So we pass an allocator to `init` method, but we don’t pass it to the event loop.
  > feel confident that there’s no way we can allocate in the actual event loop, because it doesn’t have access to an allocator.
- [zig/memory] Request-scoped bump allocator is natural for servers; Zig's explicit
  allocator makes you choose. ^f11
  > Zig forces you to pass the allocator in, so you might as well think about the most appropriate one!
- [zig/safety] TigerBeetle runs ReleaseSafe (spatial safety), avoids dynamic allocation
  (temporal) and has a fuzzer-driven suite. ^f12
  > TigerBeetle runs in `-DReleaseSafe`, which mostly solves spatial memory safety
- [zig/safety] His biggest worry: fuzzy semantics around aliasing, provenance and structs
  with interior pointers. ^f13
  > Zig’s implementation today is _very_ fuzzy around potentially aliased pointers, copies of structs with interior-pointers and the like.
- [zig/build] Bundle a pinned `./zig` per project and drive automation in Zig rather than
  shell scripts. ^f14
  > The preference, at this time of changes, is to bundle a particular version of `./zig` with a project, instead of using a system-wide `zig`.

## Read

- Whole post.

## Not read

- jamii "Assorted thoughts on Zig and Rust" (linked): other blog, lead.
