---
title: Parsing Advances (matklad, 2025-12-28)
url: https://matklad.github.io/2025/12/28/parsing-advances.html
kind: article
commit: 
for: [zig-errors-safety]
looked: 2026-10-22
depth: docs (whole post)
relevance: low
grade: B/fair
description: Resilient parsers loop forever when a function consumes nothing; assert progress with advance_push/pop/drop instead of a mental map or fuel
---
# Parsing Advances (matklad, 2025-12-28)

Why: assertion technique for progress in loops. Code in TypeScript; idea language
neutral.

## Assessment

- Evidence: B. Expert, real bug in his toy parser with before and after.
- Reasoning: fair.
- Interests: none.
- Weigh: applies to any Zig loop that must make progress (parsers, crawl loops).

## Findings

- [zig/safety] Earlier techniques: fuel (decremented even by lookahead, topped up on
  consume) and a mental map of which functions always consume a token. ^f1
  > _Fuel:_ parser has a `fuel: Cell<u32>` field, which is decremented even by “readonly” lookahead methods
- [zig/safety] Better: assert the parser advanced where you expect it; the asserts
  materialise the mental map in the source. ^f2
  > The _bigger_ benefit is that these asserts materialize the mental map of advancing functions in the source code, so it doesn’t have to be mental anymore!
- [zig/safety] API: `advance_push()` saves the index, `advance_pop()` asserts it grew,
  `advance_drop()` for exits that needn't advance. ^f3
  > assert(advance < this.index);

## Read

- Whole post.
