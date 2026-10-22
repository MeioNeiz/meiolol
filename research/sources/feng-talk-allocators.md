---
title: What's a Memory Allocator Anyway? (Benjamin Feng, Zig SHOWTIME 2020)
url: https://www.youtube.com/watch?v=vHWiDx_l4V0
kind: talk
commit:
for: [zig-memory, zig-perf]
looked: 2026-10-22
depth: skimmed (transcript, allocator sections)
relevance: low
grade: B/fair
description: Conceptual tour by a former std contributor: stack, bump/FixedBuffer, arena, free lists, size buckets, slabs; no default allocator by design
---
# What's a Memory Allocator Anyway? (Benjamin Feng, Zig SHOWTIME 2020)

Why: allocator concepts behind the std choices.

## Assessment

- Evidence: B. Benjamin Feng worked on Zig's allocator interface; 88k views. Jun 2020,
  Zig 0.6: API details are all stale; the concepts are not. Auto captions.
- Reasoning: fair; builds each allocator from the last one's limits.
- Interests: none.
- Weigh: use for concepts only; "no general-purpose allocator yet" is obsolete
  (`smp_allocator` since 0.14).

## Findings

- [zig/memory] A bump (FixedBuffer) allocator only advances an end index; freeing the last allocation is an optimisation you can't depend on, but resetting the whole buffer is reliable. ^f1
  > memory that you actually get is sort of an optimization and not not an actual like something that you can depend on so yeah we can free the last allocation but the other thing that we can do is we can reset the entire buffer
  @12:40
- [zig/memory] An arena fits work with a known lifetime, e.g. create at request start and free at request end. ^f2
  > for instance a web request you can structure your arena in a way where you create the arena at the beginning of a request and you you free the memory at the at the end of the request
  @17:11
- [zig/perf] Prefer arrays to linked structures for cache friendliness (slab allocators). ^f3
  > instead of using a linked list we should be using arrays or Rea's are much faster and much friendlier to the cpu nowadays
  @26:12
- [zig/memory] No default allocator is deliberate: different parts of a program want different trade-offs. ^f4
  > so there is no default alligator we have to make decisions around all of these things and that I believe that that's a good thing
  @32:14

## Read

- Transcript sections on stack, bump, arena, general purpose, Q&A.
