---
title: State of the (Tagged) Union Address by Andrew Kelley (Systems Distributed 2026)
url: https://www.youtube.com/watch?v=zwi5b5xSsKA
kind: talk
commit:
for: [zig-good-practice, zig-testing]
looked: 2026-10-22
depth: docs (whole transcript)
relevance: low
grade: A/fair
description: Kelley's 2026 state-of-Zig talk: "doing more with less" philosophy, core team roles, a five-step bug-elimination ladder (dev hits, user reports, branch coverage, fuzzing, LLMs), open moonshots (bounded stack, ranged integers), 1.0 plan
---
# State of the (Tagged) Union Address (Systems Distributed 2026)

Why: the lead's current statement of values that shape what "good Zig" means.

## Assessment

- Evidence: A for the project's stated values (the lead, Sep 2026).
- Reasoning: fair. Mostly organisational; the testing ladder is reasoned with SQLite as
  the example.
- Interests: project promotion, a stance against AI companies.
- Weigh: little direct coding guidance; use for philosophy and the testing ladder.

## Findings

- [zig] Core principle "doing more with less": a small language with powerful
  constructs (comptime), lean programs, low resource use. @1:55 ^f1
  > main uh the main thing that we care about in in the Zigg project is uh doing more with less.
- [zig] Rejected quadrant: "less with more", adding cost or complexity that loses
  something (his example: an ORM over a database). @2:40 ^f2
  > but what you what you really don't want to do is do less with more where you're taking on like some cost or some complexity, but you actually lose something for it.
- [zig/test] Bug-elimination ladder: what developers hit, what users report, full
  machine-code branch coverage, fuzzing, then LLM-found bugs. @30:16 ^f3
  > Uh so first one is just like this is like uh alpha software. Whatever the developers happen to hit.
  > um number four would be fuzzing. So we're going to use a genetic algorithm to create inputs
- [zig/test] With full coverage and fuzzing done well you skip waiting for user reports;
  non-trivial enhancements send you back to the start. @32:48 ^f4
  > So if you do uh full test coverage and fuzzing uh and you do it well, you're going to stop getting like bug reports because you've tested everything
  > non-trivial enhancements to a project, it kind of sends you back to the beginning of the list
- [zig/safety] Open moonshots: eliminate recursion and guarantee bounded stack usage,
  ranged integer types against overflow, removing all unchecked illegal behaviour. @44:59 ^f5
  > eliminate recursion. Guarantee bounded stack usage.
  > eliminate overflows with ranged integer types
- [zig/build] Shipped: self-hosted x86 backend default, own linker, incremental
  compilation, cross-compilation including arbitrary glibc versions. @44:05 ^f6
  > We have cross compilation to any OS that just works including dynamically linking arbitrary GIC versions.

## Read

- Whole transcript.
