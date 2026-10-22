---
title: Push Ifs Up And Fors Down (matklad, 2023-11-15)
url: https://matklad.github.io/2023/11/15/push-ifs-up-and-fors-down.html
kind: article
commit: 
for: [zig-perf, zig-style, zig-api-design]
looked: 2026-10-22
depth: docs (whole post)
relevance: high
grade: B/strong
description: Two rules of thumb: move conditions to callers (centralise control flow, enforce preconditions by type or assert) and make batch operations the base case
---
# Push Ifs Up And Fors Down (matklad, 2023-11-15)

Why: function shape and batching. Examples in Rust-like pseudo-code, language neutral;
he names TigerBeetle's data plane as the macro example.

## Assessment

- Evidence: B. Expert rules of thumb; TigerBeetle architecture as one data point.
- Reasoning: strong. Several motivations per rule, composition of the two, examples.
- Interests: none.
- Weigh: rules of thumb, he says so ("consider").

## Findings

- [zig/api] Push ifs up: move a precondition check to the caller and take the non-optional
  type, enforcing it by type or assert; it goes viral and leaves fewer checks. ^f1
  > a function might check precondition inside and “do nothing” if it doesn’t hold, or it could push the task of precondition checking to its caller, and enforce via types (or an assert) that the precondition holds.
- [zig/style] Centralise complex control flow in one function, delegating work to
  straight line subroutines; dead branches become visible. ^f2
  > By pushing `if`s up, you often end up centralizing control flow in a single function, which has a complex branching logic, but all the actual work is delegated to straight line subroutines.
- [zig/style] "Dissolving enum" refactor: an enum built by one branch and matched by
  another is the same condition triplicated; pull the branch up. ^f3
  > it becomes apparent that it is the exact same condition, triplicated (the third time reified as a data structure)
- [zig/perf] Push fors down: make batch operations the base case, the scalar version a
  special case. ^f4
  > So it often is prudent to introduce a concept of a “batch” of objects, and make operations on batches the base case, with a scalar version being a special case of a batched ones
- [zig/perf] Batches amortise startup cost and free the processing order (struct-of-arrays
  tricks, one field at a time). ^f5
  > you can do vectorized/struct-of-array tricks to process one field of all entities first, before continuing with other fields.
- [zig/perf] Composed: branch outside, loop inside; avoids re-evaluating the condition,
  removes a branch from the hot loop, may unlock vectorization. ^f6
  > it avoids repeatedly re-evaluating `condition`, removes a branch from the hot loop, and potentially unlocks vectorization.
- [zig/perf] TigerBeetle's architecture: the data plane works on batches to amortise
  control-plane decisions. ^f7
  > the good version is the architecture of TigerBeetle, where in the data plane we operate on batches of objects at the same time, to amortize the cost of decision making in the control plane.

## Read

- Whole post.

## Not read

- Graydon Hoare vectorised interpreters talk (linked PDF): other author.
