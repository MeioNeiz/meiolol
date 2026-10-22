---
title: A Fun Zig Program (matklad, 2025-04-21)
url: https://matklad.github.io/2025/04/21/fun-zig-program.html
kind: article
commit: 
for: [zig-comptime]
looked: 2026-10-22
depth: docs (whole post)
relevance: low
grade: B/fair
description: Return type computed from a comptime parameter; signatures are computed before and independently of the body
---
# A Fun Zig Program (matklad, 2025-04-21)

Why: how Zig checks generic functions. Version neutral.

## Assessment

- Evidence: B. Expert, tiny example.
- Reasoning: fair. Three observations, no wider argument.
- Interests: none.
- Weigh: background for comptime.

## Findings

- [zig/comptime] Arbitrary expressions in type position, and types can use preceding
  comptime parameters: `fn f(comptime x: bool) if (x) u32 else bool`. ^f1
  > fn f(comptime x: bool) if (x) u32 else bool {
- [zig/comptime] Signatures must be explicit; Zig computes the signature ignoring the body,
  then checks call site against signature and body against signature. ^f2
  > When a generic function is called, Zig first computes the signature. While doing so, it ignores function’s body.

## Read

- Whole post.
