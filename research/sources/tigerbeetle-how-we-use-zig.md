---
title: TigerBeetle - How We Use Zig, King Protty (2023 talk at DuckDB)
url: https://www.youtube.com/watch?v=8k33ZvWYQ20
kind: talk
commit:
for: [zig-good-practice]
looked: 2026-10-22
depth: docs (whole transcript, auto captions)
relevance: low
grade: C/weak
description: informal 23-minute pitch of Zig features TigerBeetle relies on (checked arithmetic, slices, explicit casts, defer, comptime, build system) to DuckDB developers
---
# TigerBeetle - How We Use Zig, King Protty (2023 talk at DuckDB)

Why: whether a TigerBeetle engineer adds Zig-specific practice beyond Tiger Style.

## Assessment

- Evidence: C. Informal talk with Q&A, 6.5k views, 2023 (Zig 0.11); speaker is on
  the Zig core team.
- Reasoning: weak: feature tour, little on how they use them.
- Interests: pitching Zig to DuckDB.
- Weigh: little beyond the langref; one useful note on build step memory limits.

## Findings

- [zig/safety] Integer overflow is illegal behaviour, checked (panics) by default;
  downcasts need an explicit truncate or checked cast. @3:58 ^f1
  > integer overflow is defined to be um to be something called illegal Behavior
  > you can't downcast without a explicit like call
- [zig/style] No operator overloading, destructors or move semantics; `defer` is
  lexically scoped: all to make code review easier. @5:32 @7:02 ^f2
  > Zig doesn't have operator overloading it also doesn't have destructors
  > all of this is just really to simplify code review
- [zig/build] Build steps can declare an expected memory ceiling so the build runner
  limits parallelism. @21:30 ^f3
  > you can configure for each step how much memory it should take
- [zig] (inferred) Checked, not there: nothing on TigerBeetle conventions
  beyond Tiger Style; skip for the guide except as colour. ^f4

## Read

- Whole transcript.
