---
title: 'Web Almanac 2024: Performance chapter'
url: https://almanac.httparchive.org/en/2024/performance
kind: dataset
commit: 
for: [css-per-page]
looked: 2026-10-29
depth: skimmed (LCP sections)
relevance: low
grade: A/fair
description: HTTP Archive's 2024 performance chapter from CrUX field data: LCP pass rates by device and page type, LCP content types, LCP sub-parts (TTFB dominates)
---
# Web Almanac 2024: Performance chapter

Why: field evidence on how much render-blocking CSS and cache reuse matter for LCP at web scale.

## Assessment

- Evidence: A. CrUX over millions of origins, plus RUMvision.
- Reasoning: fair; some explanations are guesses ("likely").
- Interests: none.
- Weigh: population numbers, not causes for one site.

## Findings

- [seo] 72% of secondary pages have good LCP, 20 points above home pages; the authors put it down partly to resources cached from the first page. LCP ^f1
  > After they navigate to secondary pages, many of the resources are already loaded and cached, speeding up the LCP element to render.
- [seo] 59% of mobile pages had good LCP in 2024 vs 74% on desktop. ^f2
  > In 2024, 59% of mobile pages achieved a good LCP score.
- [seo] Mobile pages use text as LCP about 10 points more often than desktop; 73% of mobile LCP elements are images. LCP content types ^f3
  > Compared to desktop, 10% more mobile webpages use text as their LCP element.
- [seo] TTFB is the largest LCP sub-part; sites with poor LCP spend 2.27 s on TTFB alone. LCP sub-parts ^f4
  > Websites with poor LCP spend 2.27 seconds on TTFB alone
- [seo] [web] Render-blocking stylesheets in the head are named as one cause of element render delay (RUMvision p75 render delay 443 ms), without a share attributed to them. ^f5
  > render-blocking resources like stylesheets or synchronous scripts in the `<head>` can delay rendering
- [seo] Checked, not there: no figure for render-blocking CSS's share of LCP or for inlined vs linked CSS. ^f6

## Read

- LCP sections

## Not read

- CLS, INP, TTFB sections; the 2022 and 2024 CSS chapters
