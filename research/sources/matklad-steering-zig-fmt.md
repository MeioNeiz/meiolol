---
title: Steering Zig Fmt (matklad, 2026-05-08)
url: https://matklad.github.io/2026/05/08/steering-zig-fmt.html
kind: article
commit: 
for: [zig-style]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/fair
description: zig fmt picks layout from trailing commas and the first line break in arrays; steer it rather than fight it
---
# Steering Zig Fmt (matklad, 2026-05-08)

Why: formatting habits. Zig 0.16 (links 0.16.0 langref), current; `++` still exists in
0.17 (only `**` was removed).

## Assessment

- Evidence: B. Expert daily use.
- Reasoning: fair. Shows behaviour, light argument.
- Interests: none.
- Weigh: trust; easy to verify with zig fmt.

## Findings

- [zig/style] zig fmt is steerable: the layout variant is chosen from what's in the file;
  a trailing comma puts one argument per line, none puts the call on one line. ^f1
  > Depending on the trailing comma, function call is formatted on a single line, or with one argument per line.
- [zig/style] Decide the layout, add commas, reformat; 90% of good formatting is blank
  lines between logical blocks and well-chosen intermediate variables. ^f2
  > 90% of great formatting are blank lines between logical blocks and tasteful choice of intermediate variables
- [zig/style] Arrays: zig fmt also uses the first line break, giving aligned columns of
  that many items per line. ^f3
  > for arrays, `zig fmt` also takes note of the first line break.
- [zig/style] `++` concatenation varies items per line, e.g. `--key value` pairs for a
  subprocess. ^f4
  > When I need to pass `--key` `value` pairs to subprocess, I often go for formatting like this:

## Read

- Whole post.
