---
title: Size Matters (matklad, 2025-11-28)
url: https://matklad.github.io/2025/11/28/size-matters.html
kind: article
commit: 
for: [zig-style]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/strong
description: TigerStyle's 70-line function and 100-column limits explained: minimise interface relative to body, fit two copies side by side; files may be large
---
# Size Matters (matklad, 2025-11-28)

Why: function and file size rules. Language neutral, from TigerBeetle's Zig practice.

## Assessment

- Evidence: B. First-hand TigerStyle rationale.
- Reasoning: strong. Two principles in tension, with the reason for each number.
- Interests: works at TigerBeetle.
- Weigh: the 70-line and 100-column limits are Schelling points, he says so.

## Findings

- [zig/style] TigerStyle: hard limit of 70 lines per function, 100 columns per line, yet
  TigerBeetle has some very large files. ^f1
  > hard limit of 70 lines per function
  > hard limit all line lengths, without exception, to at most 100 columns
- [zig/style] Size itself is irrelevant: optimise the ratio of module size to its
  interface; keep related things together. ^f2
  > Instead, you want to optimize the _ratio_ of module size to its interface.
- [zig/style] Move a data structure to its own file when it is self contained, whether ten
  or ten thousand lines (replica.zig vs timestamp_range.zig). ^f3
  > You should move a data structure to a separate file when it is self contained.
- [zig/style] Functions should have bodies large relative to their interface; hourglass
  functions or modules are a smell. ^f4
  > The converse is more helpful: hourglass functions/modules are a smell.
- [zig/style] 100 columns lets two copies sit side by side, to compare versions and see
  caller and callee. ^f5
  > the 100 columns limit, as that allows you to comfortably fit two copies of code side by side
- [zig/style] Function length bound is "fit on a screen", about 60-70 lines. ^f6
  > Hence, the Schelling point for the upper bound on function length: it’d be better to fit on a screen. Which is about 60-70 lines.
- [zig/style] No inherent limit on file size or count; rely on fuzzy file and symbol
  search. ^f7
  > But there’s no inherent limit on the file size or number of files.

## Read

- Whole post.

## Not read

- tigerbeetle.com "tale of four fuzzers" (linked): reader "tigerbeetle".
