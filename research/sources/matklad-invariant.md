---
title: What is an Invariant? (matklad, 2023-10-06)
url: https://matklad.github.io/2023/10/06/what-is-an-invariant.html
kind: article
commit: 
for: [zig-errors-safety, zig-testing]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/strong
description: Invariants in the small (loop invariant fixes a binary search) and in the large (Cargo, rust-analyzer, TigerBeetle system invariants)
---
# What is an Invariant? (matklad, 2023-10-06)

Why: the thinking behind assertion-heavy code. Rust examples; TigerBeetle invariants
apply to Zig. Version neutral.

## Assessment

- Evidence: B. Expert, from three large projects he worked on; admits one invariant
  (rust-analyzer identity-less trees) may have been a mistake.
- Reasoning: strong.
- Interests: none.
- Weigh: conceptual; supports asserting loop and state invariants.

## Findings

- [zig/safety] In the small: state precisely what the code must do as a loop invariant
  (`lo <= insertion_point <= hi`), then make branches match it; fixes code that rules
  of thumb got wrong. ^f1
  > To get the details right for the right reason, you need to understand _precisely_ what the result should be, and formulating this as a (loop or recursion) invariant helps.
- [zig/safety] Invariants are compressed descriptions that collapse the time dimension,
  covering all execution paths. ^f2
  > Invariants are powerful, because they are _compressed_ descriptions of the system, they collapse away the time dimension
- [zig/test] He tests insertion_point exhaustively over small arrays (N=5, M=5) with
  exhaustigen. ^f3
  > Here’s an exhaustive test for this functionality, using exhaustigen crate
- [zig/memory] TigerBeetle invariant: no allocation after startup, so everything has a
  numeric limit and you can't memcpy to ambient space. ^f4
  > TigerBeetle doesn’t allocate memory after startup. This simple invariant affects every bit of code
- [zig/perf] Transaction logic can't read from disk: objects are prefetched per batch, so
  IO parallelises and execution is a tight serial CPU loop without locks. ^f5
  > Every object which could be touched by a transaction needs to be explicitly prefetched into memory before transaction begins.
- [zig/errors] Reading from disk can't fail at the API: failed local reads are repaired
  from other replicas, so code above needn't handle errors. ^f6
  > Everything built on top doesn’t need to worry about error handling.

## Read

- Whole post.
