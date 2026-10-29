---
title: 'web.dev: Best practices for fonts'
url: https://web.dev/articles/font-best-practices
kind: article
commit: 
for: [css-per-page]
looked: 2026-10-29
depth: docs (font loading, preload, font-display sections)
relevance: high
grade: A/fair
description: web.dev (Katie Hempenius, Barry Pollard; 2022) on font loading: fonts are found only after the CSS, inline @font-face, cautious preload, font-display trade-offs for FCP, LCP and CLS
---
# web.dev: Best practices for fonts

Why: should inter.woff2 (48 KB, swap, requested from the sheet) be preloaded or declared inline?

## Assessment

- Evidence: A. Chrome DevRel guide, updated 2022; no numbers of its own.
- Reasoning: fair; states the preload trade-off but doesn't size it.
- Interests: none.
- Weigh: direction of advice. Says nothing about whether a swap re-reports LCP.

## Findings

- [seo] [web] Inlining `@font-face` and critical styles in the head lets the browser find fonts without waiting for the external sheet. Inline font declarations ^f1
  > This allows the browser to discover the font declarations sooner as the browser doesn't need to wait for the external stylesheet to download.
- [seo] [web] But the browser still waits for all CSS before deciding a font is needed, even if some CSS is inlined. ^f2
  > Even if only some of the CSS is inlined, the browser still must wait for all the CSS to be loaded, before it can discover if fonts are needed.
- [seo] [web] Preload makes fonts discoverable early but takes bandwidth from other resources; fixing declaration placement addresses the root cause. Be cautious when using preload ^f3
  > this comes at the cost of taking away browser resources from the loading of other resources
- [seo] [web] With an external stylesheet, preloading the most important font can be very effective, since it is otherwise found late. ^f4
  > when using external stylesheets, preloading the most important fonts can be very effective since the browser won't otherwise discover whether the font is needed until much later
- [web] Preload ignores `unicode-range`; preload a single format only. ^f5
  > `preload` ignores `unicode-range` declarations
- [seo] [web] `swap` delays text render the least of the swapping values but can shift layout when the font arrives; `optional` caps the delay at 100 ms with no swap shift, at the price of skipping a late font. font-display ^f6
  > Use `font-display: optional`. This is the most "performant" approach: text render is delayed for no longer than 100ms
- [web] Splitting stylesheets and removing unused CSS can reduce the fonts a page loads. ^f7
  > removing unused CSS and splitting stylesheets can reduce the number of fonts loaded by a page
- [seo] Checked, not there: whether a fallback-to-web-font swap creates a new LCP entry. ^f8

## Read

- Font loading, inline declarations, preconnect, preload, font-display sections

## Not read

- Font delivery (self-hosting, subsetting, compression) sections
