---
title: 'web.dev: Largest Contentful Paint (LCP)'
url: https://web.dev/articles/lcp
kind: docs
commit: 
for: [css-per-page]
looked: 2026-10-29
depth: docs (When is LCP reported, size changes)
relevance: medium
grade: A/fair
description: web.dev's LCP definition (Philip Walton, Barry Pollard; updated Sep 2025): when entries are emitted, web fonts in the block period, size changes not re-reported
---
# web.dev: Largest Contentful Paint (LCP)

Why: does a swap from the fallback font to inter.woff2 change the LCP real users get?

## Assessment

- Evidence: A. Canonical metric definition from Chrome.
- Reasoning: fair.
- Interests: none.
- Weigh: field LCP behaviour; Lighthouse's simulated LCP differs ([[lighthouse-lantern-preload-lcp]]).

## Findings

- [seo] Text is not counted as rendered while its web font is in the block period; once it renders, a new LCP entry is emitted. When is LCP reported? ^f1
  > Neither are text nodes using web fonts during the [font block period](https://developer.mozilla.org/docs/Web/CSS/@font-face/font-display#The_font_display_timeline).
- [seo] Changes to an element's size or position don't create new LCP candidates; only the first size and position count. How are element layout and size changes handled? ^f2
  > changes to an element's size or position don't generate new LCP candidates. Only the element's initial size and position in the viewport is considered.
- [seo] (inferred) With `font-display: swap` (0 ms block) text LCP is the first paint in the fallback font; the later swap to inter.woff2 doesn't move field LCP, so for real users the font is off the LCP path and preloading it only helps CLS and look. A WPT test (largest-contentful-paint/web-font-styled-text-resize-swap.html) suggests a swap that makes text larger can emit a new entry; not checked. ^f3

## Read

- When is LCP reported, size change sections

## Not read

- Measuring LCP in JS, field vs lab sections
