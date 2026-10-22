---
title: On Async Mutexes (matklad, 2025-11-04)
url: https://matklad.github.io/2025/11/04/on-async-mutexes.html
kind: article
commit: 
for: [zig-api-design, zig-errors-safety]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/fair
description: TigerBeetle's single-threaded state machine with explicit named callbacks that start by asserting the state, as implicit exclusion instead of async mutexes
---
# On Async Mutexes (matklad, 2025-11-04)

Why: concurrency structure in a Zig system. TigerBeetle 0.16.63 code (Zig 0.14/0.15),
`@fieldParentPtr("grid_read", grid_read)` current form.

## Assessment

- Evidence: B. Real TigerBeetle compaction code.
- Reasoning: fair. Frames a contradiction in his beliefs, resolves it partially.
- Interests: none.
- Weigh: relevant if meiolol uses callbacks or std.Io async; the assert-at-callback-start
  habit is the takeaway.

## Findings

- [zig/api] TigerBeetle relies on implicit exclusion from a single thread; a callback
  mutates shared `*Compaction` state across all outstanding IO. ^f1
  > It’s imperative that no other IO completion mutates compaction concurrently
- [zig/api] Callback pattern: recover the parent with `@fieldParentPtr("grid_read",
  grid_read)`, release the pool slot, assert the stage, advance the stage. ^f2
  > const read: *ResourcePool.BlockRead =
  > assert(block.stage == .read_value_block);
- [zig/api] Explicit locking would collapse to one global lock taken per callback, i.e.
  back to implicit locking at the event loop. ^f3
  > So explicit locking probably gravitates towards having just a single global lock around the entire state
- [zig/safety] Every continuation is an explicit named function that starts with
  assertions pinning the current state, or does exhaustive case analysis from
  scratch. ^f4
  > each continuation (callback) generally starts with a bunch of assertions to pin down the current state and make sure that the ground hasn’t shifted too far since the IO was originally scheduled.

## Read

- Whole post.
