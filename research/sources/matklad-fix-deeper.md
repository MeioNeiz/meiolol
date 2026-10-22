---
title: Try to Fix It One Level Deeper (matklad, 2024-09-06)
url: https://matklad.github.io/2024/09/06/fix-one-level-deeper.html
kind: article
commit: 
for: [zig-errors-safety]
looked: 2026-10-22
depth: docs (whole post)
relevance: low
grade: B/fair
description: A day of TigerBeetle fixes: treat a bug as a pointer to a class of bugs (fatal error infrastructure, CI gofmt, removing a compile-time parameter); defer assert(postcondition) caught reentrancy
---
# Try to Fix It One Level Deeper (matklad, 2024-09-06)

Why: habits behind error handling and asserts. TigerBeetle, Zig 0.13 era.

## Assessment

- Evidence: B. Real PRs (#2289, #2287, #2292).
- Reasoning: fair. Anecdotal.
- Interests: none.
- Weigh: illustrates defer assert in practice.

## Findings

- [zig/errors] A poor out-of-disk message showed a missing fatal-error infrastructure;
  `NoSpaceLeft` was one of a kind (TigerBeetle #2289). ^f1
  > we are missing an infrastructure for fatal errors, and `NoSpaceLeft` is just one of a kind.
- [zig/safety] `defer assert(postcondition);` is a favourite Zig pattern; it failed in the
  simulator and revealed unintended reentrancy. ^f2
  > While fixing that, I used one of my favorite Zig patterns: `defer assert(postcondition);`
  > It of course failed in the simulator in a way postcondition checks tend to fail — there was an unintended reentrancy in the code.

## Read

- Whole post.
