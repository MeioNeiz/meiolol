---
title: 'StyleX docs: Thinking in StyleX, intro and launch post'
url: https://stylexjs.com/docs/learn/thinking-in-stylex/
kind: docs
commit: 77013d511080d341269336d04a35e84b01138dc8
for: [css-per-page]
looked: 2026-10-29
depth: docs (learn/thinking-in-stylex.mdx, learn/index.mdx, blog 2023-12-05 introducing StyleX)
relevance: high
grade: A/strong
description: Meta's atomic CSS compiler; its design principles argue for one small upfront stylesheet over lazy-loaded or split CSS
---
# StyleX docs: Thinking in StyleX, intro and launch post

Why: the strongest maintained argument for "make the whole sheet small" over splitting.

## Assessment

- Evidence: A. Meta's styling system for Facebook, Instagram, WhatsApp, Threads (per
  [[fb-stylex-2025]]); repo created 2022-12, 10.4k stars, v0.19.1 (2026-09).
- Reasoning: strong. States the trade-off (initial load vs INP) and what it gives up.
- Interests: Meta's own tool; the INP claim is asserted, no measurement in these pages.
- Weigh: trust the design intent; verify the restyle cost claim (other readers cover
  Chrome guidance).

## Findings

- [web] Design principle: one small CSS file loaded upfront, not many small ones. `packages/docs/content/docs/learn/thinking-in-stylex.mdx` ^f1
  > ### One small file over many smaller files
  > StyleX is optimized for generating a single, highly optimized, CSS bundle that
  > is loaded upfront.
- [web] Why: lazy-loading CSS helps the first load but makes later updates slower (INP), because any CSS arriving later restyles the whole page. `packages/docs/content/docs/learn/thinking-in-stylex.mdx` ^f2
  > However, it comes at the cost of slower update
  > times, or the _Interaction to Next Paint (INP)_ metric. Lazy-loading any CSS on
  > a page triggers a recalculation of styles for the entire page.
- [web] The goal is total CSS small enough to load all of it upfront; critical CSS is compatible but should be unnecessary. `packages/docs/content/docs/learn/thinking-in-stylex.mdx` ^f3
  > Our goal is to create a system where the total amount of CSS
  > is small enough that all the CSS can be loaded upfront without a noticeable
  > performance impact.
  > are compatible with StyleX, but should normally be unnecessary.
- [web] Atomic class names make the bundle plateau as components grow, so nobody has to hand-optimise or lazy-load CSS. `packages/docs/content/blog/2023-12-05-introducing-stylex.md` ^f4
  > bundle. As the number of components in an application grows, the size of the CSS
  > bundle starts to plateau. This frees developers from having to manually optimize
  > or lazy-load CSS files.
- [web] Ordering: StyleX promises deterministic results across files, including shorthand vs longhand, whatever order styles are applied. `packages/docs/content/docs/learn/thinking-in-stylex.mdx` ^f5
  > StyleX provides a completely predictable and deterministic styling system that
  > works across files.
- [web] It bans descendant and other at-a-distance selectors as fragile; an element is styled only by its own classes. `packages/docs/content/docs/learn/thinking-in-stylex.mdx` ^f6
  > All of these patterns, while powerful, make styles fragile, less predictable and
  > harder to debug. An element could be styled without having any classes applied
- [web] It trades build-time work for zero runtime cost in the common case. `packages/docs/content/docs/learn/thinking-in-stylex.mdx` ^f7
  > We make the trade-off of doing more work at build-time to improve
  > runtime performance.
- [web] Checked, not there: no sheet sizes or measured INP numbers in these docs; numbers are in [[fb-redesign-2020]]. ^f8
- [web] (inferred) For meiolol the plateau needs atomic output (one class per declaration); our scoped component rules (.c-name descendant rules) grow linearly with components, so the StyleX argument for one sheet holds only once the sheet is small. ^f9

## Read

- The three files in depth: all

## Not read

- `@stylexjs/babel-plugin` source: rule priority ordering
- Docs on the dev-mode runtime injection
