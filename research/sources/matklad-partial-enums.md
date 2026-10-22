---
title: Partially Matching Zig Enums (matklad, 2025-08-08)
url: https://matklad.github.io/2025/08/08/partially-matching-zig-enums.html
kind: article
commit: 
for: [zig-comptime, zig-errors-safety]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/strong
description: inline switch prongs plus else => comptime unreachable to share code between some union variants with a compile-time exhaustiveness check
---
# Partially Matching Zig Enums (matklad, 2025-08-08)

Why: compile-time checked sub-matching. Zig 0.14+ (`|_, ab|` tag capture on inline
prongs), current for 0.17.

## Assessment

- Evidence: B. Expert idiom, short, with a compile error shown.
- Reasoning: strong. Shows the Rust and runtime-panic alternatives and why this is
  better.
- Interests: none.
- Weigh: trust; costs a bit of code duplication per inline prong (compiled once per
  variant).

## Findings

- [zig/comptime] Problem: common code for some variants; runtime `else => unreachable`
  works but is theoretically brittle. ^f1
  > This is the awkward runtime-panicky and theoretically brittle version:
- [zig/comptime] [zig/safety] Fix: `inline .a, .b => |_, ab| { handle_ab(); switch (ab)
  { .a => ..., .b => ..., else => comptime unreachable } }`. ^f2
  > else => comptime unreachable,
- [zig/comptime] `inline` generates the prong once per variant with `ab` comptime-known;
  `comptime unreachable` fails compilation if reached. ^f3
  > `inline .a, .b` forces the compiler to generate the program twice, where `ab` is bound to _comptime_ value.
- [zig/comptime] [zig/safety] Adding `.c` to the inline prong fails with "reached
  unreachable code", so a later refactor bug is a compile error. ^f4
  > partial-match.zig:14:34: error: reached unreachable code

## Read

- Whole post.
