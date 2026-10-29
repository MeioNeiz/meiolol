---
title: 'web.dev: Extract critical CSS'
url: https://web.dev/articles/extract-critical-css
kind: article
commit: 
for: [css-per-page]
looked: 2026-10-29
depth: docs (all)
relevance: high
grade: A/fair
description: web.dev guide (Milica Mihajlija, 2019) to inlining above-the-fold CSS, with its costs and the 14 KB first-round-trip target; lists Critical, criticalCSS, Penthouse
---
# web.dev: Extract critical CSS

Why: Chrome's own statement of what critical CSS gains and costs.

## Assessment

- Evidence: A. Chrome team's canonical guide; 2019, no measured numbers of its own.
- Reasoning: fair. Names the costs (caching, HTML delay, bugs) but doesn't size them.
- Interests: none.
- Weigh: costs and the warning; the 14 KB rule is a TCP rule of thumb (see [[tunetheweb-14kb]]).

## Findings

- [seo] [web] Opens with a warning: advanced, can cause bugs, most sites meet the targets without it. ^f1
  > This guide describes an advanced performance technique that can improve performance, but can also lead to bugs if not implemented properly.
- [seo] [web] Cost 1: a lot of inlined CSS delays the rest of the HTML. ^f2
  > if you inline a large amount of CSS, it delays the transmission of the rest of the HTML document
- [seo] [web] Cost 2: inlined CSS is not cached for later page loads, so use it sparingly. ^f3
  > it prevents the browser from caching the CSS for reuse on subsequent page loads, so it's best to use it sparingly
- [seo] [web] Target: above-the-fold content under 14 KB compressed, the first round trip of TCP slow start (about 10 packets). ^f4
  > aim to keep above-the-fold content under **14 KB** (compressed)
- [seo] [web] Gain is biggest with lots of CSS and on high-latency mobile networks. ^f5
  > Generally speaking, the more CSS a site has, the greater the possible impact of inlined CSS.
- [seo] [web] Above the fold has no fixed height, so extraction tools render the page (often at several resolutions) to decide what is critical. ^f6
  > There is no universally defined pixel height of what is considered above the fold content
- [web] (inferred) The tools (Critical, Penthouse) run a headless browser over each page; meiolol renders pages per request in Zig, so the equivalent is a build-time list of which CSS a page kind uses, not viewport analysis. ^f7

## Read

- Whole page

## Not read

- The linked codelab
