---
title: Retry Loop Retry (matklad, 2025-08-23)
url: https://matklad.github.io/2025/08/23/retry-loop-retry.html
kind: article
commit: 
for: [zig-errors-safety, zig-style]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/fair
description: Better Zig retry loop: loop while the action errors, retries as an early exit, with a for (0..n + 1) upper bound and else @panic("runaway loop")
---
# Retry Loop Retry (matklad, 2025-08-23)

Why: the bounded-loop idiom applied to retries. Zig 0.14/0.15 syntax, current.

## Assessment

- Evidence: B. Expert, after reader suggestions.
- Reasoning: fair. Explains why the first framing misled him; still doesn't like the
  result (forgetting the +1 panics).
- Interests: none.
- Weigh: a usable shape for meiolol's Riot API retries.

## Findings

- [zig/errors] Reframe: loop while the action returns an error; retries left is an extra
  early exit; a loop body may run zero times, the condition always runs. ^f1
  > it’s not that we are looping until we are out of attempts, but, rather, we are looping while the underlying action returns an error
- [zig/errors] Idiom: `const err = if (action()) |ok| break ok else |err| err; if
  (!is_transient_error(err)) break err;` then the loop value goes through `try`. ^f2
  > const err = if (action()) |ok| break ok else |err| err;
- [zig/safety] Bounded version: `for (0..retry_count + 1) { ... } else @panic("runaway
  loop");` restores the syntactic bound. ^f3
  > } else @panic("runaway loop");
- [zig/safety] Weakness: forgetting the `+1` panics. ^f4
  > I still don’t like it (if you forget that `+1`, you’ll get a panic!)

## Read

- Whole post.
