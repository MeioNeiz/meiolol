---
status: answered
priority: now
area: ops
tags: [seo, render, ops, web]
description: Can meiolol prerender some matchup pages statically and render the rest on demand, and what does that need for search engines?
---
# Can meiolol prerender some matchup pages statically and render the rest on demand, and what does that need for search engines?

Feeds: how the site is built and deployed (deploy/web-loop.sh, src/site); whether
matchup pages (about half of 103k files, 1.2 GB, rebuilt every 15 min) stay static

## Answer

Mixing prerendered and on-demand pages is a standard pattern: Next.js ISR prerenders a
listed set and renders the rest on first request, then caches it (C1); Astro does it
per route (C2). It needs a running server (C3). We would need no framework: nginx's
try_files serves a built file or hands the request to a renderer, and its proxy cache
gives serve-stale-while-refreshing and one render per page under a burst (C4, C5).

For search, server rendering is as good as static if the HTML is complete and fast:
Google names both side by side (C7) and crawls less when responses slow (C8). Filling
pages in with JavaScript is weaker: Google renders it later in a queue, and link
previews and other bots may not run it (C9). That only matters for pages we want found.

Which pages get indexed matters more than how they are rendered. ~50,000 matchup pages
are 80% of the site, but only ~190 have 200+ games (C10), and each matchup exists at
four near-identical URLs (C11). Google wastes crawling on low-value and duplicate URLs
(C12) and its doorway and scaled content policies target many thin, similar pages
(C13). Competitors rank with matchup pages of 240 to 1,800 games (C14); lolalytics
hides matchups under 100 games (C15). So: one indexable URL per matchup above a game
floor, in sitemaps with lastmod (C16).

Our own filter prototype changes the build side (C19): the browser sums per-champion
slices, so the four view copies collapse to one page plus a small data file, and filter
URLs work without a server. It covers counts only; model estimates do not sum (C20).
Combined: static HTML for champion pages and thick, indexable matchups; the browser
for filters and for thin matchups nobody should find by search (C21). A renderer behind
nginx stays the escape hatch if the static set grows too big (C6, C17). Data churn is
also temporary: early in a patch the site rebuilds every 15 minutes, later hourly.

## Claims

- C1: ISR prerenders a listed subset at build and renders other existing pages on first request, then caches them; stale pages are served while a fresh one renders in the background. for: [[nextjs-isr#^f1]], [[nextjs-isr#^f2]]
- C2: Astro is static by default and renders chosen routes on demand. for: [[astro-on-demand#^f1]], [[astro-on-demand#^f2]]
- C3: On-demand rendering needs a running server; a static export cannot do it. for: [[nextjs-isr#^f3]]
- C4: nginx try_files serves a prebuilt file when it exists and otherwise passes the request to a fallback such as a render server. for: [[nginx-try-files#^f1]]
- C5: nginx's proxy cache can serve stale pages while refreshing in the background, and render a new page once under concurrent requests. for: [[nginx-proxy-module#^f1]], [[nginx-proxy-module#^f2]], [[nginx-proxy-module#^f3]]
- C6 (inferred): A render service on the jomify box, next to the Your games service that already reads the curves files, could render matchup pages on request. from: C4, C5
- C7: Google recommends server-side rendering or static rendering equally; dynamic rendering for bots is a workaround. for: [[google-dynamic-rendering#^f1]], [[webdev-rendering#^f3]]
- C8: Google's crawl capacity falls when response times rise or the server errors, and rises when they are stable; caching on-demand pages gets TTFB close to static. for: [[google-crawl-budget#^f2]], [[webdev-rendering#^f1]], [[webdev-rendering#^f3]]
- C9: Pages filled in client-side are rendered by Google later in a queue, and Google still advises server-side or prerendered HTML. for: [[google-js-seo-basics#^f1]], [[google-js-seo-basics#^f2]]
- C10: Matchup pages are ~80% of the site, and few are thick: all regions over 30 days, 165 of ~12,900 have 200+ games and 2,576 have 30+. for: [[meiolol-matchup-counts#^f1]], [[meiolol-matchup-counts#^f2]], [[meiolol-matchup-counts#^f3]]
- C11 (inferred): Each matchup is published at four near-duplicate URLs (region by period). for: [[meiolol-matchup-counts#^f5]]
- C12: Google tries to crawl every URL it knows; duplicates and low-value URLs waste crawling, and noindex pages are still fetched. A 10k+ page site that changes daily is the case Google's crawl budget guide is for. for: [[google-crawl-budget#^f1]], [[google-crawl-budget#^f3]], [[google-crawl-budget#^f4]]
- C13: Google's spam policies target many substantially similar or low-value generated pages by purpose and value, with no page-count threshold. for: [[google-spam-policies#^f1]], [[google-spam-policies#^f3]], [[google-spam-policies#^f4]]
- C14: Per-matchup "X vs Y" pages are what rank for matchup searches: Mobalytics (1,246 games), MetaBot (242 games) and lolalytics. for: [[mobalytics-darius-vs-garen#^f1]], [[mobalytics-darius-vs-garen#^f2]], [[metabot-garen-vs-darius#^f1]], [[lolalytics-darius-vs-garen#^f2]]
- C15: LoLalytics hides matchups below 100 games. for: [[lolalytics-counters-threshold#^f1]]
- C16 (inferred): Index one canonical URL per matchup, only above a game floor, listed in sitemaps (50,000 URLs each) with accurate lastmod; keep thin and duplicate views out of the sitemap and canonical to the indexed one. from: C11, C12, C13, C15, C18
- C17 (inferred): Prerender the indexable set (hundreds to a few thousand pages) and render the long tail on demand behind a cache; static stays the source for everything search sees first. from: C1, C5, C8, C10
- C18: Sitemaps hold 50,000 URLs or 50 MB each; Google ignores priority and changefreq and uses lastmod only when accurate. for: [[google-sitemaps#^f1]], [[google-sitemaps#^f2]]

- C19: The browser can filter a champion page by region, rank, period and role from one small summable data file per champion (35 KB gzipped), with no server and no page per combination. for: [[meiolol-filters-prototype#^f1]], [[meiolol-filters-prototype#^f2]]
- C20: Only summable numbers filter in the browser; model estimates such as lane-curve gold at 14 and rates with other denominators do not. for: [[meiolol-filters-prototype#^f3]]
- C21 (inferred): Stay static: HTML for champion pages and indexable matchups, browser filters and browser-drawn thin matchups from per-champion data; a server only if the static set outgrows quick builds. from: C9, C16, C19, C20

## Disagreements

None between sources. Open judgement: the game floor for indexing. Competitors rank at
242 games (MetaBot) and hide below 100 (lolalytics); our own curves grey out below 200.

## Options

| Option | Claims for | Claims against | Would change if |
| --- | --- | --- | --- |
| A: all static (today) | C7, C8 (fastest TTFB) | C10, C12 (50k files rebuilt every 15 min, mostly thin) | page count stayed in the low thousands |
| B: static for indexable matchups, on demand for the rest (try_files to a renderer, nginx cache) | C1, C4, C5, C6, C17 | C3 (a service to run on a 1 GB box) | the renderer proved too slow or memory-hungry there |
| C: every matchup page on demand, cached | C5, C7 | C8 (cold-cache TTFB for crawlers) | warm-up after each data update were cheap |
| D: matchup pages filled in client-side from JSON | fewest files | C9 (Google renders later; other bots may not run JS) | SEO did not matter for matchups |
| E: static for champion pages and thick matchups, browser filters and thin matchups (chosen direction) | C9 (only for unindexed pages), C16, C19, C21 | C20 (estimates do not filter) | thick matchups grew past quick builds: add B's renderer |

## Open

- How fast the renderer is per page on the jomify box (E2.1.Micro, 1 GB), and the cache
  size for ~50k pages (~1 GB uncompressed, much less gzipped).
- Which view is canonical: all regions (more games) or EUW (the product's focus)? By
  30 days or by patch? The patch views are thinnest.
- Game floor for indexing (100? 200?) and whether thin pages are linked at all.
- First-hand indexing rates for programmatic pages (leads logged): how many of a few
  thousand matchup pages Google would index.
- Can be revisited once the production key lifts the noindex (preview mode).
- Whether matchup curve data for a champion's thin matchups fits a per-champion file
  the browser can draw from (curves are estimates, so precomputed per view).
- Estimates under any filter: compile the estimation to wasm (as the recommender is)?
