---
title: It Takes Two to Contract (TigerBeetle blog, matklad, 2023)
url: https://tigerbeetle.com/blog/2023-12-27-it-takes-two-to-contract
kind: article
commit:
for: [zig-errors-safety, zig-style]
looked: 2026-10-22
depth: docs (whole post)
relevance: high
grade: A/strong
description: why assertions come in pairs (call site and definition, sender and receiver, two paths to one state), plus defer postconditions and maybe()
---
# It Takes Two to Contract (TigerBeetle blog, matklad, 2023)

Why: the source Tiger Style links for "pair assertions".

## Assessment

- Evidence: A. A TigerBeetle core engineer (matklad, also rust-analyzer author)
  describing practice in the TigerBeetle codebase, with real code; see
  [[tigerbeetle-code#^f16]] for a pair in the grid.
- Reasoning: strong. Admits the duplication, explains when it is worth it, shows a
  case where the pair caught a missing check.
- Interests: company blog.
- Weigh: general; costs nothing outside databases.

## Findings

- [zig/safety] Design by contract needs no language feature in Zig: `assert` for
  preconditions and `defer assert(...)` for postconditions. ^f1
  > For preconditions, `assert` function works perfectly, and for postconditions, there’s `defer`:
  > defer assert(grid.free_set.opened);
- [zig/safety] A contract is real only with two assertions of the same condition: one
  at the call site, one at the definition. ^f2
  > something is a real contract only when you have at least _two_ assertions checking the relevant condition
- [zig/safety] Call-site asserts also document what the returned value means. ^f3
  > const filled = compaction.fill_immutable_values(target);
  > assert(filled <= target.len);
- [zig/safety] The pair is an airlock: check the two sets of asserts agree, then
  reason about each side separately. ^f4
  > An assertion _pair_ forms an airlock
- [zig/safety] Pairs survive refactors and catch slips: the author found while
  writing the post that the definition site lacked one of the call-site checks. ^f5
  > did you notice in the `fill_immutable_values` example that the `assert(filled <= target.len);` condition _isn’t_ actually checked for at the definition site?
- [zig/safety] The strongest pairs reach one property by different paths (sender vs
  receiver, replayed vs restored state), like property tests that compute a result two
  ways. ^f6
  > The real superpower is unlocked once you get to the same logical assertion through two different code paths.
- [zig/safety] `maybe(condition)` is a no-op assert that marks a condition as
  sometimes true, for readability. ^f7
  > we even have a special `maybe(condition);` assertion, which is a no-op
- [zig/safety] Rule of thumb: when writing an assert, find the distant code that
  relies on it and add an equivalent assert there. ^f8
  > Whenever you assert something, think about which distant part of the code base relies on the assertion you just wrote, and add an equivalent assertion there.

## Read

- Whole post.
