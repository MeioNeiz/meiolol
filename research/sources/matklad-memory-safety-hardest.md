---
title: Memory Safety's Hardest Problem (matklad, 2026-07-20)
url: https://matklad.github.io/2026/07/20/memory-safety-hardest-problem.html
kind: article
commit: 
for: [zig-errors-safety]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/fair
description: A Zig program showing type confusion through a pointer into a tagged union variant that survives reassignment; bounds checks fix the most exploitable class
---
# Memory Safety's Hardest Problem (matklad, 2026-07-20)

Why: which Zig memory bugs safe builds don't catch. Current Zig.

## Assessment

- Evidence: B. Runnable Zig example with output.
- Reasoning: fair. Short; notes impact in practice is unclear.
- Interests: none.
- Weigh: a concrete hazard to name in the guide: don't hold pointers into union payloads
  across writes to the union.

## Findings

- [zig/safety] Taking `|*p|` into a union(enum) variant, then assigning a different
  variant, leaves a typed pointer reading the other variant's bytes: type confusion that
  Zig's safety checks don't catch. ^f1
  > The pointer is still typed as `A`, but the bytes it points to now belong to `B`: a type confusion.
  > const oh_no_pointer: *const []const u8 = switch (e) {
- [zig/safety] The most exploitable error, buffer overflow, is trivially fixed by
  compiler-inserted bounds checks (which Zig slices have). ^f2
  > It is a happy coincidence that by far the most exploitable memory error in practice, the infamous buffer overflow, is also trivial to fix with compiler-inserted bounds checks.

## Read

- Whole post.
