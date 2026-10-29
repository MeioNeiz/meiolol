---
title: 'web.dev: Defer non-critical CSS'
url: https://web.dev/articles/defer-non-critical-css
kind: article
commit: 
for: [css-per-page]
looked: 2026-10-29
depth: docs (all)
relevance: medium
grade: A/fair
description: web.dev walkthrough (Demián Renzulli, 2019): coverage tool, inline the used rules, load the rest with preload plus onload; toy demo gains 0.2 s FCP
---
# web.dev: Defer non-critical CSS

Why: the mechanism and measured gain of async-loading the rest of the CSS.

## Assessment

- Evidence: A source, but the one measurement is a toy demo with a tiny sheet.
- Reasoning: fair.
- Interests: none.
- Weigh: the pattern needs JS (onload) or noscript; CSP blocks inline onload.

## Findings

- [seo] [web] Pattern: `link rel=preload as=style` with an onload that flips rel to stylesheet, plus a noscript fallback. Optimize ^f1
  > The `onload` attribute in the `link` lets the browser process the CSS when the style sheet finishes loading.
- [seo] [web] A Content Security Policy may forbid the inline onload; use loadCSS instead. In production ^f2
  > These functions support a [Content Security Policy](https://web.dev/articles/csp), which might not allow inline `onload` JavaScript.
- [seo] [web] Moving the link to the end of the body is not a full fix: the browser still prioritises the sheet. ^f3
  > However, the browser still prioritizes the stylesheet, so it can still block critical content in the browser.
- [seo] On the demo, FCP went from 1 s to 0.8 s, and the audit passed. Monitor ^f4
  > the FCP page has been reduced by **0.2s** (a 20% improvement!)
- [seo] Lighthouse also shows Remove unused CSS when at least 2048 bytes of rules went unused for above-the-fold content. ^f5
  > If Lighthouse detects that a page has at least 2048 bytes of CSS rules that weren't used while rendering the _above the fold_ content

## Read

- Whole page
