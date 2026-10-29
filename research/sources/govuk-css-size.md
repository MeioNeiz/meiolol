---
title: 'GDS blog: How we reduced CSS size and improved performance across GOV.UK'
url: https://gds.blog.gov.uk/2023/12/15/how-we-reduced-css-size-and-improved-performance-across-gov-uk/
kind: article
commit: 
for: [css-per-page]
looked: 2026-10-29
depth: docs (all)
relevance: high
grade: B/fair
description: GOV.UK (Dec 2023) moved from one app stylesheet to per-component sheets listed per page (Rails asset helper); SpeedCurve before and after on Mobile 3G, cache gains, and pages where many sheets got slower
---
# GDS blog: How we reduced CSS size and improved performance across GOV.UK

Why: a large server-rendered site that split CSS per page and measured before and after.

## Assessment

- Evidence: B. Production change on a very high-traffic site, SpeedCurve synthetic before/after; two pages reported, no field (RUM) data, no variance.
- Reasoning: fair; reports its own negatives.
- Interests: none.
- Weigh: the per-page numbers are small and synthetic; the negatives (many sheets, small-file compression) are the useful counterweight. Overlaps the server-stack reader's angle (Rails helper).

## Findings

- [web] Before: each app served one bundle of up to 30 style imports plus a shared static sheet; the home page loaded CSS for 24 components but used 5, 17 KB unused. Problems ^f1
  > the homepage previously loaded CSS for 24 components yet, aside from commonly used styles (included in the static stylesheet), only required styles for 5 components
- [render] [web] Any small component change re-downloaded the whole app sheet (27.7 kB gz); after, the same change re-downloads only that component's CSS (1.1 K gz). ^f2
  > Now the same change means the client only downloads the updated component CSS (1.1 K gzipped). All other stylesheets are loaded from cache.
- [seo] [web] Home page CSS fell 40% (42 kB to 25 kB); on emulated Mobile 3G, Start Render 2.3 s to 2.2 s and LCP 2.53 s to 2.35 s (7%). Performance gains ^f3
  > Largest Contentful Paint - 7% improvement from 2.53s to 2.35s
- [web] They call the caching gain the main advantage, more than the size cut. ^f4
  > arguably the main advantage is in caching improvements
- [seo] [web] Pages with many components loaded about 16 stylesheets and got slightly slower, though CSS size fell. Negatives ^f5
  > users can download approximately 16 different stylesheets. Whilst CSS size is still lower than previously, performance indicators are adversely affected with time metrics slightly worse than previously.
- [seo] [web] Small files compress poorly, sometimes ending larger. ^f6
  > compressing files with small amounts of text doesn’t always produce smaller file sizes (or leads to hardly any size reduction)
- [web] Next: group components often served together into small bundles for better compression. What's next ^f7
  > We might look to group together some component styles, commonly served to the same pages, into smaller bundles to achieve better compression savings and reduce their size.
- [seo] [web] (inferred) A 40% CSS cut bought about 0.1-0.2 s on Mobile 3G: per-page CSS helps but is no large LCP lever on its own once the sheet is tens of KB gz. ^f8

## Read

- Whole post

## Not read

- RFC 149 (per-page asset loading) and the gem's setup docs
