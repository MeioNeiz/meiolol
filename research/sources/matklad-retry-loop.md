---
title: Retry Loop (matklad, 2023-12-21)
url: https://matklad.github.io/2023/12/21/retry-loop.html
kind: article
commit: 
for: [zig-errors-safety, zig-style]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/fair
description: A bounded Zig retry loop with for/else and an action returning ok | retry(err) | fatal error; four goals, three met
---
# Retry Loop (matklad, 2023-12-21)

Why: bounded loops and error propagation. Zig 0.11 pseudo-code (`for (0..5)` without
capture would not compile as written). Superseded by [[matklad-retry-loop-retry]].

## Assessment

- Evidence: B. Expert, small example.
- Reasoning: fair. States four goals, admits failing one.
- Interests: none.
- Weigh: read with the 2025 follow-up.

## Findings

- [zig/safety] Wants an obvious upper bound: `for (0..5)` rather than `while (true)` with a
  break in the middle (links TigerBeetle PR 1367). ^f1
  > Obvious upper bound: I don’t want to write a `while (true)` loop with a break in the middle.
- [zig/errors] On final failure report the underlying error from the last attempt, not
  just "all attempts failed". ^f2
  > In the event of a retry failure, the underlying error is reported.
- [zig/errors] The action returns `!enum { ok, retry: anyerror }`: success, fatal error
  (propagated by try), or transient error carrying the error itself. ^f3
  > For the transient failure case, it is important to return an error object itself, so that the real error can be propagated if a retry fails.

## Read

- Whole post.
