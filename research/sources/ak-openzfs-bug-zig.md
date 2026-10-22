---
title: OpenZFS Bug Ported to Zig - Andrew Kelley (2025-07-14)
url: https://andrewkelley.me/post/openzfs-bug-ported-zig.html
kind: article
commit:
for: [zig-errors-safety, zig-style]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: A/fair
description: Kelley ports a C OpenZFS bug (returns the input instead of the computed value) to Zig; zig fmt --ast-check alone flags a shadowed const and the unused result
---
# OpenZFS Bug Ported to Zig

Why: a concrete case for const-by-default and unused-local errors as bug finders.

## Assessment

- Evidence: A for what the compiler does (shown output); one example.
- Reasoning: fair; short, shows the mechanism, no generalisation claims.
- Interests: promoting Zig.
- Weigh: the example is a port written to make the point; the mechanism (compile errors
  on unused locals and redeclaration) is real.

## Findings

- [zig/style] [zig/safety] `zig fmt --ast-check` (no type checking) rejects redeclaring a
  local const, which exposed dead initialisation code in the C original. ^f1
  > bug.zig:18:11: error: redeclaration of local constant 'cols'
- [zig/style] [zig/safety] An unused local constant is a compile error, which caught the
  real bug (the function returned its input, not the computed psize). ^f2
  > bug.zig:23:11: error: unused local constant
  > Bingo. We didn't even have to use the type checker.
- [zig/style] (inferred) Naming each intermediate as a new const (asize_shifted,
  parity_adjusted, psize) instead of mutating one var is what lets the unused check fire. ^f3
  > const parity_adjusted = asize_shifted - nparity * (divCeil(asize_shifted, cols) catch unreachable);

## Read

- Whole post.
