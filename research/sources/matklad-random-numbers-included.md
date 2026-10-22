---
title: Random Numbers Included (matklad, 2025-03-31)
url: https://matklad.github.io/2025/03/31/random-numbers-included.html
kind: article
commit: 
for: [zig-api-design, zig-testing]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/fair
description: PRNG APIs work best with closed (inclusive) ranges: can hit the max, can't underflow, and make the non-zero precondition visible at the call site
---
# Random Numbers Included (matklad, 2025-03-31)

Why: API design detail for random generation in tests. From his TigerBeetle PRNG API
work (PR 2798). Version neutral.

## Assessment

- Evidence: B. First-hand API design in TigerBeetle.
- Reasoning: fair. Three concrete reasons, short.
- Interests: none.
- Weigh: applies to meiolol's own PRNG helpers in tests and sampling.

## Findings

- [zig/api] [zig/test] Random number APIs work best with closed intervals, unlike most
  APIs which prefer half-open. ^f1
  > it seems that random numbers really work best with closed intervals, `≤n`.
- [zig/api] Closed range can produce the maximum value, e.g. one of the ten largest u32s,
  without widening. ^f2
  > closed interval means that you can actually generate the highest-possible number
- [zig/api] [zig/safety] Exclusive ranges are panicky (an empty range below zero crashes);
  inclusive pushes `- 1` to the caller, making the non-zero precondition visible:
  `prng.int_inclusive(u8, replica_count - 1)`. ^f3
  > by pushing the `-1` to the call-site, you make it immediately obvious that there’s non-zero pre-condition
  > const replica = prng.int_inclusive(u8, replica_count - 1);

## Read

- Whole post.

## Not read

- TigerBeetle PR 2798: reader "tigerbeetle".
