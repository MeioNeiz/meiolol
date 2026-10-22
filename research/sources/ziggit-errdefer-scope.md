---
title: Errdefer scoped to the parent block (Ziggit thread, 2025)
url: https://ziggit.dev/t/errdefer-scoped-to-the-parent-block/8346
kind: thread
commit:
for: [zig-errors-safety, zig-memory]
looked: 2026-10-22
depth: docs (whole thread)
relevance: medium
grade: C/fair
description: getOrPut cleanup with errdefer is noisy; fixes: early return, errdefer inside the branch, helper; proposal closed not planned
---
# Errdefer scoped to the parent block (Ziggit thread, 2025)

Why: errdefer around `getOrPut`, a pattern meiolol hits.

## Assessment

- Evidence: C. Community (IntegratedQuantum of Cubyz, chadwain), Feb 2025; links the
  langref's errdefer slip-ups section and a closed proposal.
- Reasoning: fair.
- Interests: none.
- Weigh: trust the early-return shape.

## Findings

- [zig/errors] `errdefer` is block-scoped like `defer`; an errdefer inside an `if` stops at the `if`. ^f1
  > Like `defer`, `errdefer` is scoped to the block it is defined.
- [zig/errors] Clean `getOrPut` shape: return early when found, then `errdefer` the removal and the value's deinit at function scope. ^f2
  > if (gop.found_existing) return;
  > errdefer _ = map.swapRemove(key);
- [zig/memory] Reserve capacity first and the function may need no `try` and no errdefer. ^f3
  > Can you maybe preallocate/reserve all the memory you need instead of allocating. If you have no `try`s in the function then you don't need any errdefers.
- [zig/errors] A proposal for parent-scoped errdefer (`errdefer :label`) was closed as not planned. ^f4
  > I proposed this awhile back and it was closed as "not planned":

## Read

- Whole thread.
