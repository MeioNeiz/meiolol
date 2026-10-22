---
title: Printing Lists (matklad, 2026-08-14)
url: https://matklad.github.io/2026/08/14/printing-lists.html
kind: article
commit: 
for: [zig-style]
looked: 2026-10-22
depth: docs (whole post)
relevance: low
grade: C/weak
description: One-snippet post: print the separator before every element but the first
---
# Printing Lists (matklad, 2026-08-14)

Why: a small idiom. Zig, current.

## Assessment

- Evidence: C. A single snippet.
- Reasoning: weak. Asserted as concise, no argument.
- Interests: none.
- Weigh: a habit, not a rule.

## Findings

- [zig/style] Comma-separated list: `for (items, 0..) |item, item_index| { if
  (item_index > 0) print(", "); print(...) }`; note the `item_index` naming. ^f1
  > To print a comma-separated list, a concise idiom is to optionally print the comma first, before the element:
  > for (items, 0..) |item, item_index| {

## Read

- Whole post (one snippet).
