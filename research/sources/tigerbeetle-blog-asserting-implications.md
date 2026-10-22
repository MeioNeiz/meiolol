---
title: Asserting Implications (TigerBeetle blog, matklad, 2025)
url: https://tigerbeetle.com/blog/2025-05-26-asserting-implications
kind: article
commit:
for: [zig-errors-safety, zig-style]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/fair
description: write `if (a) assert(b)` instead of `assert(!a or b)`
---
# Asserting Implications (TigerBeetle blog, matklad, 2025)

Why: the origin of Tiger Style's "single-line if to assert an implication".

## Assessment

- Evidence: B. Short post, one real diff from TigerBeetle; the pattern occurs 58 times
  as a one-line `if (...) assert(` in src/ at 0450c32 (our grep).
- Reasoning: fair: readability argument only.
- Interests: none.
- Weigh: cheap and general.

## Findings

- [zig/safety] [zig/style] Implications are asserted often; `assert(!a or b)` is hard
  to read, `if (a) assert(b)` is clearer. ^f1
  > But in my experience, you want to _assert_ implications all the time!
  > if (a) assert(b);
- [zig/safety] Real before and after from TigerBeetle. ^f2
  > if (header_b == null) assert(replica.commit_min == replica.op_checkpoint);

## Read

- Whole post.
