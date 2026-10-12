---
title: 'Google: Crawl budget management (docs, 2026)'
url: https://developers.google.com/crawling/docs/crawl-budget
kind: docs
commit: 
for: [hybrid-rendering-seo]
looked: 2026-10-12
depth: docs (who it is for, capacity limit, best practices)
relevance: high
grade: A/fair
description: Google's guide to crawl budget: who needs it (1M+ pages, or 10k+ changing daily), what raises or lowers crawl capacity, how to spend it well
---
# Google: Crawl budget management (docs, 2026)

Why: does a site with ~50k-100k matchup URLs whose numbers change daily hit crawl budget
limits, and does serving pages on demand (slower first byte) hurt crawling?

## Assessment

- Evidence: A. Google's own crawling documentation.
- Reasoning: fair. States the mechanism (capacity limit plus demand), no numbers.
- Interests: none beyond Google's own load.
- Weigh: authoritative on what Google does; gives no thresholds for "slow".

## Findings

- [seo] The guide is for 1M+ page sites changing weekly, or 10k+ page sites changing daily; meiolol's matchup pages (10k+, numbers updated daily) fall in the second group. ^f1
  > Medium or larger sites (10,000+ unique pages) with very rapidly changing content (daily)
- [seo] [render] Crawl capacity rises when response times (including time to first byte) are stable or improve, and falls when the site slows or returns 5xx or 429. ^f2
  > If the site slows down (latency increases or response times become longer), or responds with server errors (`5xx HTTP` status codes) or rate-limiting signals (such as `HTTP 429`), the limit goes down and Google crawls less.
- [seo] Google tries to crawl every URL it knows about; duplicate or unimportant URLs waste crawl time, and this is the factor a site controls most. ^f3
  > Without guidance from you, Google tries to crawl all or most of the URLs that it knows about on your site.
- [seo] noindex does not save crawl budget: Google still fetches the page, then drops it. ^f4
  > **Don't use `noindex`**, as Google will still request, but then drop the page
- [seo] [render] Supporting 304 Not Modified lets Google reuse its cached copy of unchanged pages. ^f5
  > If a page hasn't changed since Google last crawled it, returning a `304` code tells Google to reuse the cached version
- [seo] Keep sitemaps current with lastmod for updated content. ^f6
  > If your site includes updated content, we recommend including the `<lastmod>` tag.

## Read

- whole page: who it's for, crawl capacity limit and demand, best practices

## Not read

- linked troubleshooting and Crawl Stats report pages
