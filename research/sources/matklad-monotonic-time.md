---
title: Considering Strictly Monotonic Time (matklad, 2026-01-23)
url: https://matklad.github.io/2026/01/23/strictly-monotonic-time.html
kind: article
commit: 
for: [zig-errors-safety]
looked: 2026-10-22
depth: docs (whole post)
relevance: low
grade: B/fair
description: Clamp OS monotonic time with an in-process guard, and make it strictly monotonic (+1ns) so asserts can tighten from <= to <
---
# Considering Strictly Monotonic Time (matklad, 2026-01-23)

Why: assertion design. Zig code, version neutral.

## Assessment

- Evidence: B. Expert, cites the Rust PR documenting non-monotonic OS clocks.
- Reasoning: fair. Benefit and the precision constraint stated.
- Interests: none.
- Weigh: small idea; the general point (design values so asserts can be tighter) is the
  useful part.

## Findings

- [zig/safety] Don't fully trust the OS monotonic clock; clamp with an in-process guard
  and assert `t >= clock.guard` and `t >= t_raw`. ^f1
  > ask the OS about the current monotonic time, but don’t trust the result too much and clamp it using an in-process guard.
- [zig/safety] Strictly monotonic (`@max(t_raw, clock.guard + 1ns)`) lets `assert(past <=
  present)` become `assert(past < present)`, also catching reuse of the same instant. ^f2
  > The benefit of strict monotonicity is that you can tighten asserts
- [zig/safety] Constraint: value resolution must be high enough that repeated +1 doesn't
  drift; nanoseconds suffice. ^f3
  > nanosecond precision seems fine for that.

## Read

- Whole post.
