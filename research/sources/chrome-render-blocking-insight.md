---
title: 'Chrome docs: Render-blocking requests insight'
url: https://developer.chrome.com/docs/performance/insights/render-blocking
kind: docs
commit: 
for: [css-per-page]
looked: 2026-10-29
depth: docs (all)
relevance: medium
grade: A/fair
description: Chrome's doc (Oct 2025, Connor Clark) for the Lighthouse 13 / DevTools insight that replaced the render-blocking audit; pass rule and fixes
---
# Chrome docs: Render-blocking requests insight

Why: the current wording of the check PageSpeed runs.

## Assessment

- Evidence: A. Official, written by a Lighthouse maintainer, Oct 2025.
- Reasoning: fair; warns that inlining is risky.
- Interests: none.
- Weigh: pass rule is absolute (zero blocking requests); the code ([[devtools-renderblocking-insight]]) shows how the estimate is made.

## Findings

- [seo] [web] Passing needs no render-blocking requests at all for first paint. How to pass ^f1
  > To pass this insight, remove all such render-blocking requests.
- [seo] [web] Fixes: defer what first paint doesn't need, inline what it needs if small, cut CSS to what first paint uses. ^f2
  > Inline requests that are critical for first-paint, but small.
- [seo] [web] Chrome itself calls inlining CSS an advanced technique most sites don't need to reach their targets. ^f3
  > Most sites should be able to achieve all of our recommended performance targets without implementing this technique.

## Read

- Whole page
