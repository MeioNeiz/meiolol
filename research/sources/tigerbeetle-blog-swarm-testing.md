---
title: Swarm Testing Data Structures (TigerBeetle blog, matklad, 2025)
url: https://tigerbeetle.com/blog/2025-04-23-swarm-testing-data-structures
kind: article
commit:
for: [zig-testing, zig-comptime]
looked: 2026-10-22
depth: docs (whole post)
relevance: high
grade: A/strong
description: property-test a data structure against a model, with actions taken from std.meta.DeclEnum of its public API and swarm-sampled weights
---
# Swarm Testing Data Structures (TigerBeetle blog, matklad, 2025)

Why: a concrete Zig comptime pattern for testing containers and modules.

## Assessment

- Evidence: A. From a real TigerBeetle refactor (intrusive queue PR 2888); helpers
  exist in `testing/fuzz.zig` ([[tigerbeetle-code#^f38]]).
- Reasoning: strong: explains why uniform randomness misses bugs.
- Interests: none.
- Weigh: snippet uses `@typeInfo(Enum).Enum` (pre-0.14 field casing), now `.@"enum"`.

## Findings

- [zig/test] For data structures, property tests against a model (e.g. ring buffer as
  model of an intrusive queue) give the best power-to-weight. ^f1
  > For data structures, by far the best power-to-weight ratio testing strategy is [property based testing]
- [zig/test] [zig/comptime] `std.meta.DeclEnum(Queue)` turns the public API into an
  enum; switching on it makes the compiler demand a test arm for every new public
  method. ^f2
  > the magic spell of `std.meta.DeclEnum(QueueType(Item))` returns an enum
  > if a new public method is added to the Queue in future, then the compiler will emit an error because of the non-exhaustive switch
- [zig/test] Swarm testing: sample the action probabilities per run (some zero),
  since uniform choice keeps e.g. the queue always short. ^f3
  > The idea of swarm testing is that you should sample the probabilities themselves!
  > As a result, our queue is very short on average. We never exercise large queues!
- [zig/test] [zig/comptime] Weights struct from an enum via
  `std.enums.EnumFieldStruct(E, u64, null)`. ^f4
  > return std.enums.EnumFieldStruct(E, u64, null);
- [zig/test] Seeds come from `std.testing.random_seed`. ^f5
  > var prng = PRNG.from_seed(std.testing.random_seed);

## Read

- Whole post.
