---
title: 'web.dev: Rendering on the Web (2026)'
url: https://web.dev/articles/rendering-on-the-web
kind: article
commit: 
for: [hybrid-rendering-seo]
looked: 2026-10-12
depth: docs (server-side, static, client-side, rehydration sections)
relevance: high
grade: A/strong
description: Google's web.dev comparison of server-side, static, client-side rendering and rehydration, with their costs in TTFB, FCP and INP
---
# web.dev: Rendering on the Web (2026)

Why: the trade-offs between static and on-demand rendering, from the reference Google's
search docs link to.

## Assessment

- Evidence: A. Google Chrome team article, the reference Search Central links to.
- Reasoning: strong. Names each approach's costs.
- Interests: none.
- Weigh: general web advice; the TTFB point is what matters for crawling.

## Findings

- [render] Static rendering gives a consistently fast TTFB because nothing is generated per request. ^f1
  > Unlike server-side rendering, it also achieves a consistently fast TTFB, because the HTML for a page doesn't have to be dynamically generated on the serv
- [render] Its downside is one file per possible URL, which can be infeasible for sites with very many pages. ^f2
  > One of the downsides to static rendering is that it must generate individual HTML files for every possible URL. This can be challenging or even infeasible when you need to predict those URLs ahead of time and for sites with a large number of unique pages.
- [render] Server-side rendering costs compute per request and can delay TTFB; caching highly cacheable content brings it close to prerendering. ^f3
  > Server-side rendering isn't the best solution for everything, because its dynamic nature can have significant compute overhead costs.
  > In the short term, only using server-side rendering for highly cacheable content can reduce TTFB, producing similar results to prerendering.

## Read

- server-side, static, client-side and rehydration sections

## Not read

- streaming and trisomorphic sections
