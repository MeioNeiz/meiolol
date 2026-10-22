---
title: Wrapping Code Comments (matklad, 2026-02-21)
url: https://matklad.github.io/2026/02/21/wrapping-code-comments.html
kind: article
commit: 
for: [zig-style]
looked: 2026-10-22
depth: docs (whole post)
relevance: low
grade: C/fair
description: Wrap code at 100 columns but comment text at ~70 columns relative to the comment's start
---
# Wrapping Code Comments (matklad, 2026-02-21)

Why: comment formatting. Version neutral.

## Assessment

- Evidence: C. A personal preference, freshly realised.
- Reasoning: fair. Explains the prose-width argument; notes tools don't support it.
- Interests: none.
- Weigh: taste.

## Findings

- [zig/style] Code to ~100 columns, comment content to ~70 measured from the comment's
  start, still within 100. ^f1
  > I want lines to be wrapped at 100, and _content_ of comments to be wrapped at 70 (unless that pushes overall line to be longer than 100).
- [zig/style] Hard-wrap comments: soft wrap can't indent wrapped markdown list items
  without understanding the text. ^f2
  > The problem with soft-wrapping is that you can’t soft-wrap text correctly without understanding its meaning.

## Read

- Whole post.
